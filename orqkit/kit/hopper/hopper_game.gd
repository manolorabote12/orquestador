extends Node2D
## Cruzar: toca para saltar hacia delante y desliza para saltar a los lados o atras. Cruza
## carreteras, rios (sobre los troncos) y vias de tren hasta la meta. Las monedas de la hierba
## valen para la tienda. Reglas, bot y analizador en hopper_map.gd.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const MapRules = preload("res://kit/hopper/hopper_map.gd")
const C: float = 80.0
const CAR_COLS: Array = [Color("#ff5a5a"), Color("#ffb340"), Color("#4aa8ff"), Color("#b36bff"), Color("#5ad17a"), Color("#f2f2f2")]

var level: Dictionary = {}
var st: Dictionary = {}
var finished: bool = false
var failed: bool = false
var deaths: int = 0
var time_in_level: float = 0.0
var coins: int = 0
var coins_total: int = 0
var fast: bool = false
var auto_retry: bool = false
var result_panel: ResultPanel
var par: float = 0.0

var _font: Font
var _world: Node2D
var _camera: Camera2D
var _info: Label
var _acc: float = 0.0
var _plan: Array = []
var _plan_i: int = 0
var _bot: bool = false
var _touch: Vector2 = Vector2.INF
var _vis: Vector2 = Vector2.ZERO
var _hop_t: float = 1.0
var _from: Vector2 = Vector2.ZERO
var _face: Vector2i = Vector2i(0, 1)
var _squash: float = 0.0
var _parts: Array = []
var _t: float = 0.0


func _ready() -> void:
	level = Kit.current_level()
	par = float(level.get("par", 30))
	RenderingServer.set_default_clear_color(Color("#7ed957"))
	_font = UI.theme.get_font("font", "Label") if UI.theme != null else ThemeDB.fallback_font
	_world = Node2D.new()
	_world.name = "World"
	_world.draw.connect(_draw_world)
	add_child(_world)
	_camera = Camera2D.new()
	add_child(_camera)
	_camera.make_current()
	_build_hud()
	_reset()
	_camera.position = _cam_target()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "hopper", "rows": (st["rows"] as Array).size()})


func bot_script() -> String:
	return "res://qa/hopper_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(1.6, 1.4)


func wants_backdrop() -> bool:
	return false


func _reset() -> void:
	finished = false
	failed = false
	st = MapRules.new_state(level)
	coins_total = int(st["coins_total"])
	coins = 0
	time_in_level = 0.0
	_acc = 0.0
	_plan = []
	_plan_i = 0
	_vis = _cell_pos(st)
	_from = _vis
	_hop_t = 1.0
	_parts = []
	_refresh()


func _build_hud() -> void:
	var hud: CanvasLayer = CanvasLayer.new()
	hud.name = "Hud"
	hud.layer = 20
	add_child(hud)
	var root: Control = Control.new()
	root.theme = UI.theme
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(root)
	var safe: MarginContainer = UI.safe_root(root, 14.0)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	safe.add_child(top)
	_info = Label.new()
	_info.name = "Info"
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.add_theme_font_size_override("font_size", 40)
	_info.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_info.add_theme_constant_override("outline_size", 8)
	top.add_child(_info)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)


func _refresh() -> void:
	if _info == null or st.is_empty():
		return
	coins = int(st["got"])
	_info.text = "%d / %d    %s %d" % [int(st["best"]), (st["rows"] as Array).size() - 1, Kit.text("hop_coins", "Monedas"), int(st["got"])]


func _cell_pos(s: Dictionary) -> Vector2:
	return Vector2((float(s["x"]) + 0.5) * C, -(float(int(s["row"])) + 0.5) * C)


func _cam_target() -> Vector2:
	return Vector2(float(MapRules.W) * C * 0.5, _vis.y - 230.0)


# ------------------------------------------------------------------ acciones

func can_act() -> bool:
	return not finished and is_inside_tree() and not get_tree().paused


func bot_step() -> void:
	_bot = true


func do_hop(d: Vector2i) -> void:
	if not can_act():
		return
	var from: Vector2 = _cell_pos(st)
	if MapRules.hop(st, d):
		_from = from
		_hop_t = 0.0
		_face = d
		_sfx("jump", -16.0)
		if int(st["got"]) != coins:
			_sfx("coin", -10.0)
			if not fast:
				UI.float_text(_world, _cell_pos(st) - Vector2(0, 60), "+1", Color("#ffd54a"), 30)
		_refresh()
		_check_end()


func _sfx(n: String, vol: float = -10.0) -> void:
	if not fast:
		Audio.play(n, 0.1, vol)


func _check_end() -> void:
	if bool(st["won"]):
		_finish()
	elif bool(st["dead"]):
		_lose()


# ------------------------------------------------------------------ bucle

func _physics_process(delta: float) -> void:
	_t += delta
	_hop_t = minf(1.0, _hop_t + delta / MapRules.HOP)
	_squash = maxf(0.0, _squash - delta * 3.0)
	if finished:
		_world.queue_redraw()
		return
	if fast and auto_retry:
		_bot = true
	var reps: int = 4 if fast else 1
	for k: int in reps:
		if finished or get_tree().paused:
			break
		_acc += delta
		## Simulacion a paso fijo (igual que el plan del bot: coches y troncos en los mismos sitios).
		while _acc >= MapRules.SUB and not finished:
			_acc -= MapRules.SUB
			if _bot and _sub_index() % 3 == 0:
				_bot_act()
			MapRules.step(st, MapRules.SUB)
			time_in_level += MapRules.SUB
			_check_end()
	var target: Vector2 = _cell_pos(st)
	var f: float = _hop_t
	_vis = _from.lerp(target, f) if f < 1.0 else target
	var cam: Vector2 = _cam_target()
	_camera.position = _camera.position.lerp(cam, minf(1.0, delta * 6.0)) if not fast else cam
	_world.queue_redraw()


func _sub_index() -> int:
	return int(roundf(float(st["t"]) / MapRules.SUB))


func _bot_act() -> void:
	if _plan.is_empty() or _plan_i >= _plan.size():
		_plan = MapRules.plan_from(st)
		_plan_i = 0
		if _plan.is_empty():
			_plan = [Vector2i(0, 0)]
	if _plan_i < _plan.size():
		var a: Vector2i = _plan[_plan_i]
		_plan_i += 1
		if a != Vector2i.ZERO:
			do_hop(a)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()
		return
	if not can_act():
		return
	if event.is_action_pressed("ui_up"):
		_human(Vector2i(0, 1))
	elif event.is_action_pressed("ui_down"):
		_human(Vector2i(0, -1))
	elif event.is_action_pressed("ui_left"):
		_human(Vector2i(-1, 0))
	elif event.is_action_pressed("ui_right"):
		_human(Vector2i(1, 0))
	if event is InputEventScreenTouch:
		var te: InputEventScreenTouch = event
		if te.pressed:
			_touch = te.position
		elif _touch != Vector2.INF:
			var d: Vector2 = te.position - _touch
			_touch = Vector2.INF
			if d.length() < 40.0:
				_human(Vector2i(0, 1))
			elif absf(d.x) > absf(d.y):
				_human(Vector2i(int(signf(d.x)), 0))
			else:
				_human(Vector2i(0, 1 if d.y < 0.0 else -1))


func _human(d: Vector2i) -> void:
	_bot = false
	do_hop(d)


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	coins = int(st["got"])
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = maxi(1, 5000 - int(time_in_level * 50.0)) + 100 * coins
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "time": snappedf(time_in_level, 0.1), "deaths": deaths})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


func stars_earned() -> int:
	if deaths > 0:
		return 1
	return 3 if par <= 0.0 or time_in_level <= par else 2


func _lose() -> void:
	if finished:
		return
	finished = true
	failed = true
	deaths += 1
	_squash = 1.0
	var cause: String = str(st["cause"])
	QA.log_event("death", {"cause": cause, "row": int(st["row"]), "deaths": deaths})
	Audio.play("hurt")
	Juice.vibrate(40)
	if not fast:
		var col: Color = Color("#4aa8ff") if cause == "water" else Color("#ffffff")
		for n: int in 14:
			_parts.append({"p": _vis, "v": Vector2.from_angle(randf() * TAU) * randf_range(80, 260), "t": 0.6, "c": col})
	if auto_retry:
		retry.call_deferred()
		return
	var msg: String = {"car": Kit.text("hop_car", "\u00a1Atropellado!"), "train": Kit.text("hop_train", "\u00a1El tren!"),
		"water": Kit.text("hop_water", "\u00a1Al agua!"), "edge": Kit.text("hop_edge", "\u00a1El tronco te sac\u00f3!")}.get(cause, "")
	var p: FailPanel = FailPanel.open(self, msg, Kit.text("hop_fail_hint", "Mira el hueco antes de saltar; en el r\u00edo, salta de tronco en tronco y no dejes que te lleven al borde."))
	p.closed.connect(retry)


## Segunda oportunidad (FailPanel, con anuncio): vuelves a la ultima franja de hierba que pisaste.
func revive() -> void:
	var rows: Array = st["rows"]
	var r: int = clampi(int(st["row"]), 0, rows.size() - 1)
	while r > 0 and str((rows[r] as Dictionary)["kind"]) != "g":
		r -= 1
	st["row"] = r
	st["x"] = 4.0
	st["dead"] = false
	st["cause"] = ""
	_hop_t = 1.0
	_squash = 0.0
	finished = false
	failed = false
	_refresh()


func retry() -> void:
	_reset()


func open_pause() -> void:
	if finished or get_tree().paused or get_node_or_null("PauseMenu") != null:
		return
	PauseMenu.open(self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_inside_tree() and not UI.test_mode:
			open_pause()


func bot_state() -> Dictionary:
	return {"pos": Vector2(float(st.get("x", 0.0)), float(st.get("row", 0))), "deaths": deaths, "coins": coins, "finished": finished,
		"failed": failed, "stomps": 0, "time": time_in_level, "row": int(st.get("row", 0))}


# ------------------------------------------------------------------ dibujo

## Caja con volumen: cara de arriba clara y cara de delante oscura (estilo bloques).
func _box(r: Rect2, col: Color, h: float) -> void:
	_world.draw_rect(Rect2(r.position + Vector2(0, h), r.size), col.darkened(0.35))
	_world.draw_rect(r, col)
	_world.draw_rect(Rect2(r.position, Vector2(r.size.x, 6)), col.lightened(0.25))


func _draw_world() -> void:
	if st.is_empty():
		return
	var rows: Array = st["rows"]
	var t: float = float(st["t"]) + _acc
	var cam: Vector2 = _camera.position
	var r0: int = maxi(0, floori(-(cam.y + 720.0) / C))
	var r1: int = mini(rows.size() - 1, ceili(-(cam.y - 720.0) / C))
	var w: float = float(MapRules.W) * C
	## 1 - Suelo de cada carril (de arriba abajo para que lo de delante tape lo de detras).
	for i: int in range(r1, r0 - 1, -1):
		var row: Dictionary = rows[i]
		var y: float = -float(i + 1) * C
		var band: Rect2 = Rect2(Vector2(-200, y), Vector2(w + 400, C))
		match str(row["kind"]):
			"g":
				_world.draw_rect(band, Color("#7ed957") if i % 2 == 0 else Color("#74cf4e"))
			"r":
				_world.draw_rect(band, Color("#4a4f5c"))
				for k: int in 6:
					_world.draw_rect(Rect2(Vector2(float(k) * 150.0 + 20.0, y + C * 0.48), Vector2(70, 5)), Color(1, 1, 1, 0.5))
			"w":
				_world.draw_rect(band, Color("#3fa7e8"))
				for k2: int in 5:
					var wx: float = fposmod(float(k2) * 170.0 + t * 40.0 * float(row["dir"]), w + 200.0) - 100.0
					_world.draw_line(Vector2(wx, y + 26 + float(k2 % 3) * 14.0), Vector2(wx + 40.0, y + 26 + float(k2 % 3) * 14.0), Color(1, 1, 1, 0.35), 3.0)
			"t":
				_world.draw_rect(band, Color("#8a7d6b"))
				for k3: int in 12:
					_world.draw_rect(Rect2(Vector2(float(k3) * 70.0 - 20.0, y + 12), Vector2(14, C - 24)), Color("#6b4a2b"))
				_world.draw_rect(Rect2(Vector2(-200, y + 22), Vector2(w + 400, 6)), Color("#c9ced6"))
				_world.draw_rect(Rect2(Vector2(-200, y + C - 28), Vector2(w + 400, 6)), Color("#c9ced6"))
			"F":
				_world.draw_rect(band, Color("#ffd54a"))
				for k4: int in 18:
					_world.draw_rect(Rect2(Vector2(float(k4) * 40.0, y + (0.0 if k4 % 2 == 0 else C * 0.5)), Vector2(40, C * 0.5)), Color("#2a2d33"))
	## 2 - Cosas de cada carril.
	for i2: int in range(r1, r0 - 1, -1):
		var row2: Dictionary = rows[i2]
		var y2: float = -float(i2 + 1) * C
		var kind: String = row2["kind"]
		if kind == "g":
			var pat: String = row2["pat"]
			for x: int in MapRules.W:
				if pat[x] == "t":
					_box(Rect2(Vector2(float(x) * C + 26.0, y2 + 40.0), Vector2(28, 30)), Color("#8b5e34"), 8.0)
					_box(Rect2(Vector2(float(x) * C + 8.0, y2 - 10.0), Vector2(64, 54)), Color("#3f9a46"), 12.0)
				elif (st["coins"] as Dictionary).has(Vector2i(x, i2)):
					var sx: float = absf(sin(_t * 3.0 + float(x)))
					_world.draw_rect(Rect2(Vector2(float(x) * C + 40.0 - 14.0 * sx, y2 + 26.0), Vector2(28.0 * sx + 2.0, 28)), Color("#ffd54a"))
		elif kind == "r" or kind == "w" or kind == "t":
			var ints: Array = MapRules.blockers(row2, t)
			if kind == "t" and MapRules.train_warning(row2, t):
				var blink: bool = int(_t * 6.0) % 2 == 0
				_world.draw_circle(Vector2(20, y2 + 14), 10.0, Color("#ff3b3b") if blink else Color("#5a1a1a"))
			for iv: Vector2 in ints:
				var r: Rect2 = Rect2(Vector2(iv.x * C + 4.0, y2 + 12.0), Vector2((iv.y - iv.x) * C - 8.0, C - 26.0))
				if kind == "w":
					_box(Rect2(r.position + Vector2(0, 4), r.size), Color("#9c6c3a"), 6.0)
				elif kind == "t":
					_box(r, Color("#d9483e"), 14.0)
					for wdw: int in int((iv.y - iv.x) * 2.0):
						_world.draw_rect(Rect2(r.position + Vector2(10.0 + float(wdw) * 40.0, 10), Vector2(22, 16)), Color("#bfe6ff"))
				else:
					var col: Color = CAR_COLS[(i2 * 7 + int(iv.x + 50.0) / 13) % CAR_COLS.size()]
					_box(r, col, 14.0)
					_world.draw_rect(Rect2(r.position + Vector2(r.size.x * 0.25, 8), Vector2(r.size.x * 0.5, 16)), Color("#bfe6ff"))
	## 3 - Jugador: un cubo con ojos que salta en arco (y se aplasta si le pillan).
	var p: Vector2 = _vis
	var arc: float = sin(_hop_t * PI) * 26.0 if _hop_t < 1.0 else 0.0
	var body: Color = Kit.color("player", Color("#ffffff"))
	var sq: float = 1.0 - _squash * 0.7
	_world.draw_circle(p + Vector2(0, 26), 22.0, Color(0, 0, 0, 0.18))
	var br: Rect2 = Rect2(p + Vector2(-24, -30.0 * sq - arc + 24.0 * (1.0 - sq)), Vector2(48, 50.0 * sq))
	_box(br, body, 10.0)
	_world.draw_rect(Rect2(br.position + Vector2(18 + float(_face.x) * 8.0, -8), Vector2(12, 10)), Color("#ff5a5a"))
	if sq > 0.5:
		_world.draw_rect(Rect2(br.position + Vector2(10 + float(_face.x) * 6.0, 12), Vector2(7, 9)), Color("#1a1a1a"))
		_world.draw_rect(Rect2(br.position + Vector2(31 + float(_face.x) * 6.0, 12), Vector2(7, 9)), Color("#1a1a1a"))
		_world.draw_rect(Rect2(br.position + Vector2(19 + float(_face.x) * 8.0, 24), Vector2(10, 7)), Color("#ffb340"))
	var dt: float = get_physics_process_delta_time()
	var k5: int = _parts.size() - 1
	while k5 >= 0:
		var pt: Dictionary = _parts[k5]
		pt["v"] = (pt["v"] as Vector2) + Vector2(0, 600.0 * dt)
		pt["p"] = (pt["p"] as Vector2) + (pt["v"] as Vector2) * dt
		pt["t"] = float(pt["t"]) - dt
		var pc: Color = pt["c"]
		pc.a = clampf(float(pt["t"]) * 2.0, 0.0, 1.0)
		_world.draw_rect(Rect2(pt["p"], Vector2(8, 8)), pc)
		if float(pt["t"]) <= 0.0:
			_parts.remove_at(k5)
		k5 -= 1
