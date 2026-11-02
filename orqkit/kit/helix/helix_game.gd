extends Node2D
## Torre en espiral: arrastra a los lados para girar la torre y que la bola caiga por los huecos.
## Reglas, simulacion, bot y analizador en helix_map.gd.
## 1 - Si la bola cae sobre rojo, se pierde. Tres pisos seguidos sin rebotar: la bola arde y
##     rompe lo que pise.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const MapRules = preload("res://kit/helix/helix_map.gd")
const GAP_Y: float = 170.0
const RX: float = 250.0
const RY: float = 62.0
const POLE: float = 46.0

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
var _bar: ColorRect
var _bar_back: ColorRect
var _score_label: Label
var _touch_x: float = INF
var _cam_y: float = 0.0
var _splats: Array[Dictionary] = []
var _shards: Array[Dictionary] = []
var _base: Color = Color("#3fb0e0")
var _t: float = 0.0
var _react: float = 0.0


func _ready() -> void:
	level = Kit.current_level()
	par = float(level.get("par", 0))
	_base = Kit.color("primary", Color("#3fb0e0"))
	RenderingServer.set_default_clear_color(Color("#1a2a44"))
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
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "helix", "floors": (st["floors"] as Array).size()})


func bot_script() -> String:
	return "res://qa/helix_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(3.0, 1.4)


func _reset() -> void:
	finished = false
	failed = false
	st = MapRules.new_state(level)
	coins_total = (st["floors"] as Array).size()
	coins = 0
	time_in_level = 0.0
	_splats.clear()
	_shards.clear()
	_cam_y = 0.0
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
	var col: VBoxContainer = VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(col)
	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 10)
	col.add_child(top)
	_score_label = Label.new()
	_score_label.name = "Score"
	_score_label.add_theme_font_size_override("font_size", 36)
	_score_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_score_label.add_theme_constant_override("outline_size", 7)
	top.add_child(_score_label)
	var bar: Control = Control.new()
	bar.custom_minimum_size = Vector2(0, 26)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(bar)
	_bar_back = ColorRect.new()
	_bar_back.color = Color(0, 0, 0, 0.45)
	_bar_back.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bar_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(_bar_back)
	_bar = ColorRect.new()
	_bar.color = Color("#ffd23f")
	_bar.position = Vector2(3, 3)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(_bar)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)


func _refresh() -> void:
	if _score_label == null or st.is_empty():
		return
	coins = mini(int(st["floor"]), coins_total)
	_score_label.text = "%d" % int(st["score"])
	_bar.size = Vector2(maxf(0.0, (_bar_back.size.x - 6.0) * clampf(float(coins) / float(maxi(1, coins_total)), 0.0, 1.0)), _bar_back.size.y - 6.0)


# ------------------------------------------------------------------ acciones

func can_act() -> bool:
	return not finished and is_inside_tree() and not get_tree().paused


func spin_by(dx: float) -> void:
	if can_act():
		st["rot"] = float(st["rot"]) - dx * 0.012


func bot_step() -> void:
	pass


# ------------------------------------------------------------------ bucle

func _physics_process(delta: float) -> void:
	_t += delta
	for sp: Dictionary in _splats:
		sp["t"] = float(sp["t"]) - delta
	_splats = _splats.filter(func(sp: Dictionary) -> bool: return float(sp["t"]) > 0.0)
	for sh: Dictionary in _shards:
		sh["v"] = (sh["v"] as Vector2) + Vector2(0, 1800) * delta
		sh["p"] = (sh["p"] as Vector2) + (sh["v"] as Vector2) * delta
		sh["t"] = float(sh["t"]) - delta
	_shards = _shards.filter(func(sh: Dictionary) -> bool: return float(sh["t"]) > 0.0)
	if finished:
		_world.queue_redraw()
		return
	var steps: int = 4 if fast else 1
	for k: int in steps:
		if auto_retry:
			_react -= delta
			if _react <= 0.0:
				MapRules.spin_toward(st, MapRules.bot_target(st, float(level.get("spin", 5.0))), float(level.get("spin", 5.0)), delta)
		var fl: int = int(st["floor"])
		var ev: String = MapRules.step(st, delta)
		if ev == "bounce" or ev == "pass":
			_react = 0.15
		if ev == "bounce":
			_splats.append({"floor": fl, "a": float(st["rot"]), "t": 1.2})
			if not fast:
				Audio.play("jump", 0.1, -14.0)
		elif ev == "pass":
			if (st["smashed"] as Dictionary).has(fl):
				_smash(fl)
			if not fast:
				Audio.play("coin", 0.1, -12.0)
		elif ev == "dead":
			_lose()
			return
		elif ev == "win":
			break
	time_in_level = float(st["time"])
	_cam_y = lerpf(_cam_y, _ball_y() - 520.0, minf(1.0, delta * 6.0))
	_camera.position = Vector2(360, _cam_y + 640.0)
	_refresh()
	if bool(st["won"]):
		_finish()
	_world.queue_redraw()


func _smash(fl: int) -> void:
	for k: int in 10:
		var a: float = float(k) * TAU / 10.0
		_shards.append({"p": Vector2(360 + cos(a) * RX * 0.7, float(fl) * GAP_Y + sin(a) * RY), "v": Vector2(cos(a) * 500.0, -300.0 - float(k % 3) * 150.0),
			"t": 0.9})


func _ball_y() -> float:
	var fl: int = int(st["floor"])
	var y_floor: float = float(fl) * GAP_Y + RY - 18.0
	var nx: float = float(st["next"])
	var bounce: float = float(st["bounce"])
	if nx < MapRules.FALL + 0.001 and int(st["streak"]) > 0 and nx >= 0.0 and fl > 0:
		## Cayendo desde el piso de arriba.
		return y_floor - GAP_Y * (nx / MapRules.FALL)
	var f: float = clampf(1.0 - nx / bounce, 0.0, 1.0)
	return y_floor - sin(f * PI) * 120.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()
		return
	if event is InputEventScreenTouch:
		_touch_x = (event as InputEventScreenTouch).position.x if (event as InputEventScreenTouch).pressed else INF
	elif event is InputEventScreenDrag and _touch_x != INF:
		var x: float = (event as InputEventScreenDrag).position.x
		spin_by(x - _touch_x)
		_touch_x = x


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	coins = coins_total
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = int(st["score"]) * 20
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
	return 3 if par <= 0.0 or time_in_level <= par * 1.4 else 2


func _lose() -> void:
	if finished:
		return
	finished = true
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "red", "floor": int(st["floor"]), "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("helix_lost", "\u00a1La bola cay\u00f3 en rojo!"),
		Kit.text("helix_fail_hint", "Gira la torre mientras la bola sube, no cuando cae, y busca el hueco m\u00e1s cercano."))
	p.closed.connect(retry)


## Segunda oportunidad (FailPanel, con anuncio): la bola rompe el piso rojo y sigue bajando.
func revive() -> void:
	st["dead"] = false
	st["streak"] = 3
	st["next"] = float(st["bounce"])
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
	return {"pos": Vector2(float(st.get("rot", 0.0)), float(st.get("floor", 0))), "deaths": deaths, "coins": coins, "finished": finished,
		"failed": failed, "stomps": 0, "time": time_in_level, "floor": int(st.get("floor", 0))}


# ------------------------------------------------------------------ dibujo

func _wedge(cy: float, a0: float, a1: float, col: Color, drop: float) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	var n: int = 6
	for k: int in n + 1:
		var a: float = lerpf(a0, a1, float(k) / float(n))
		pts.append(Vector2(360.0 + cos(a) * RX, cy + drop + sin(a) * RY))
	for k: int in range(n, -1, -1):
		var a2: float = lerpf(a0, a1, float(k) / float(n))
		pts.append(Vector2(360.0 + cos(a2) * POLE, cy + drop + sin(a2) * POLE * RY / RX))
	_world.draw_colored_polygon(pts, col)


## Un piso: primero la mitad de atras, luego el palo, luego la de delante (con canto).
func _floor(i: int, row: String, front: bool) -> void:
	var cy: float = float(i) * GAP_Y
	var step: float = TAU / float(MapRules.SLOTS)
	var rot: float = float(st["rot"])
	for k: int in MapRules.SLOTS:
		var ch: String = row[k]
		if ch == "o":
			continue
		var a0: float = rot + float(k) * step
		var mid: float = a0 + step * 0.5
		if (sin(mid) > 0.0) != front:
			continue
		var col: Color = Color("#e0303a") if ch == "x" else _base
		if front:
			_wedge(cy, a0, a0 + step, col.darkened(0.45), 16.0)
		_wedge(cy, a0, a0 + step, col.lightened(0.1 if sin(mid) > 0.0 else -0.15), 0.0)


func _draw_world() -> void:
	if st.is_empty():
		return
	var top: float = _cam_y - 100.0
	_world.draw_rect(Rect2(-100, top, 920, 1500), Color("#1a2a44"))
	for k: int in 30:
		var sy: float = top + fmod(float(k * 97) - _cam_y * 0.3, 1500.0)
		_world.draw_circle(Vector2(fmod(float(k * 173), 720.0), sy), 2.0, Color(1, 1, 1, 0.4))
	var fl: Array = st["floors"]
	var cur: int = int(st["floor"])
	var from: int = maxi(0, cur - 1)
	var to: int = mini(fl.size(), cur + 7)
	for i: int in range(from, to):
		if (st["smashed"] as Dictionary).has(i):
			continue
		_floor(i, fl[i], false)
	_world.draw_rect(Rect2(360 - POLE, top, POLE * 2.0, 1500), Color("#d8dce8"))
	_world.draw_rect(Rect2(360 - POLE, top, POLE * 0.5, 1500), Color(1, 1, 1, 0.5))
	## Meta: un piso dorado al final.
	var goal_y: float = float(fl.size()) * GAP_Y
	if goal_y < top + 1600.0:
		_world.draw_set_transform(Vector2(360, goal_y), 0.0, Vector2(1.0, RY / RX))
		_world.draw_circle(Vector2.ZERO, RX, Color("#ffcf3a"))
		_world.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for i: int in range(from, to):
		if (st["smashed"] as Dictionary).has(i):
			continue
		_floor(i, fl[i], true)
	for sp: Dictionary in _splats:
		var a: float = clampf(float(sp["t"]) / 1.2, 0.0, 1.0)
		var py: float = float(int(sp["floor"])) * GAP_Y + RY - 8.0
		var off: float = (float(st["rot"]) - float(sp["a"])) * RX * 0.9
		if absf(off) < RX * 0.8:
			_world.draw_set_transform(Vector2(360.0 + off, py), 0.0, Vector2(1.0, 0.35))
			_world.draw_circle(Vector2.ZERO, 22.0, Color(1.0, 0.85, 0.3, 0.6 * a))
			_world.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for sh: Dictionary in _shards:
		_world.draw_rect(Rect2((sh["p"] as Vector2) - Vector2(18, 8), Vector2(36, 16)), _base * Color(1, 1, 1, clampf(float(sh["t"]), 0.0, 1.0)))
	## Bola (arde con racha de 3).
	var by: float = _ball_y()
	var fire: bool = int(st["streak"]) >= 3
	_world.draw_circle(Vector2(360, by + 4), 22.0, Color(0, 0, 0, 0.25))
	if fire:
		_world.draw_circle(Vector2(360, by - 14), 30.0, Color(1.0, 0.5, 0.1, 0.5 + 0.2 * sin(_t * 30.0)))
	_world.draw_circle(Vector2(360, by), 22.0, Color("#ff6a3a") if fire else Color("#ff3d8a"))
	_world.draw_circle(Vector2(352, by - 8), 7.0, Color(1, 1, 1, 0.8))
