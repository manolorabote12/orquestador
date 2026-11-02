extends Node2D
## Billar: arrastra hacia atras desde cualquier sitio para apuntar (la linea dice adonde va la
## blanca) y suelta para tirar; cuanto mas arrastras, mas fuerte. Mete todas en los tiros dados.
## Fisica, bot y analizador en pool_map.gd.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const REVIVE_N: int = 2
const MapRules = preload("res://kit/pool/pool_map.gd")
const ORIGIN: Vector2 = Vector2(90, 230)
const BALL_COLORS: Array[Color] = [Color("#f4f4f0"), Color("#f2c84b"), Color("#3f6ad8"), Color("#e8343a"), Color("#7a3ab8"), Color("#ff8a2a"),
	Color("#2f9a52"), Color("#8a2a1a"), Color("#222228"), Color("#3fd0d0")]

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
var _shots_label: Label
var _press: Vector2 = Vector2.INF
var _drag: Vector2 = Vector2.INF
var _rolling: bool = false
var _shot_pot: int = 0
var _shot_foul: bool = false
var _msg: String = ""
var _msg_t: float = 0.0
var _t: float = 0.0
var _bot_k: int = 0


func _ready() -> void:
	level = Kit.current_level()
	par = float(level.get("par", 0))
	RenderingServer.set_default_clear_color(Color("#2a1a12"))
	_font = UI.theme.get_font("font", "Label") if UI.theme != null else ThemeDB.fallback_font
	_world = Node2D.new()
	_world.name = "World"
	_world.draw.connect(_draw_world)
	add_child(_world)
	_camera = Camera2D.new()
	add_child(_camera)
	_camera.make_current()
	_camera.position = Vector2(360, 640)
	_build_hud()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "pool", "balls": int(st["total"])})


func bot_script() -> String:
	return "res://qa/pool_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(1.0, 0.6)


func wants_backdrop() -> bool:
	return false


func _reset() -> void:
	finished = false
	failed = false
	st = MapRules.new_state(level)
	coins_total = int(st["total"])
	coins = 0
	time_in_level = 0.0
	_rolling = false
	_msg_t = 0.0
	_bot_k = 0
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
	col.add_child(top)
	_shots_label = Label.new()
	_shots_label.name = "Shots"
	_shots_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shots_label.add_theme_font_size_override("font_size", 32)
	_shots_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_shots_label.add_theme_constant_override("outline_size", 7)
	top.add_child(_shots_label)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)


func _refresh() -> void:
	if _shots_label == null or st.is_empty():
		return
	coins = int(st["potted"])
	_shots_label.text = "%s %d   %s %d/%d" % [Kit.text("pool_shots", "Tiros:"), int(st["shots"]) - int(st["used"]), Kit.text("pool_balls", "Bolas:"),
		int(st["potted"]), int(st["total"])]


# ------------------------------------------------------------------ acciones

func can_act() -> bool:
	return not finished and is_inside_tree() and not get_tree().paused and not _rolling and _msg_t <= 0.0


func shoot(dir: Vector2, power: float) -> void:
	if not can_act() or dir.length() < 0.01:
		return
	var cue: Dictionary = st["balls"][0]
	cue["v"] = dir.normalized() * clampf(power, 0.05, 1.0) * MapRules.MAX_SPEED
	st["used"] = int(st["used"]) + 1
	_rolling = true
	_shot_pot = 0
	_shot_foul = false
	_sfx("click")
	_refresh()


func _aim() -> Array:
	## Arrastre hacia atras: la blanca sale en sentido contrario.
	var d: Vector2 = _press - _drag
	return [d.normalized(), clampf(d.length() / 320.0, 0.0, 1.0)]


func _sfx(n: String) -> void:
	if not fast:
		Audio.play(n, 0.1, -6.0)


func bot_step() -> void:
	if can_act():
		var sh: Array = MapRules.bot_shot(st, 977 + _bot_k * 31)
		_bot_k += 1
		shoot(sh[0], float(sh[1]))


# ------------------------------------------------------------------ bucle

func _physics_process(delta: float) -> void:
	_t += delta
	var steps: int = 12 if fast else 2
	time_in_level += delta * (6.0 if fast else 1.0)
	if _rolling:
		for k: int in steps:
			for b: Dictionary in MapRules.step(st):
				if int(b["id"]) == 0:
					_shot_foul = true
				else:
					_shot_pot += 1
					_sfx("coin")
			if not MapRules.moving(st):
				_rolling = false
				MapRules.finish_shot(st, _shot_pot, _shot_foul)
				if _shot_foul:
					_msg = Kit.text("pool_foul", "\u00a1Falta! La blanca vuelve")
					_msg_t = 1.0
				elif _shot_pot > 0:
					_msg = Kit.text("pool_in", "\u00a1Dentro!")
					_msg_t = 0.6
				_refresh()
				break
	if _msg_t > 0.0:
		_msg_t -= delta * (6.0 if fast else 1.0)
	if not _rolling and _msg_t <= 0.0 and not finished:
		if bool(st["won"]):
			_finish()
		elif bool(st["lost"]):
			_lose()
		elif fast and auto_retry:
			bot_step()
	_world.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()
		return
	if not can_act():
		return
	var inv: Transform2D = get_canvas_transform().affine_inverse()
	if event is InputEventScreenTouch:
		var te: InputEventScreenTouch = event
		var p: Vector2 = inv * te.position
		if te.pressed:
			_press = p
			_drag = p
		elif _press != Vector2.INF:
			var a: Array = _aim()
			if float(a[1]) > 0.06:
				shoot(a[0], float(a[1]))
			_press = Vector2.INF
	elif event is InputEventScreenDrag and _press != Vector2.INF:
		_drag = inv * (event as InputEventScreenDrag).position


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	coins = coins_total
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = int(st["potted"]) * 200 + (int(st["shots"]) - int(st["used"])) * 150 - int(st["fouls"]) * 100
	var record: bool = Save.submit_best(level_id, maxi(0, score))
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "time": snappedf(time_in_level, 0.1), "deaths": deaths})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": maxi(0, score), "record": record})
	await Ads.show_interstitial("level_end")


func stars_earned() -> int:
	if deaths > 0:
		return 1
	return 3 if int(st["used"]) <= int(par) and int(st["fouls"]) == 0 else 2


func _lose() -> void:
	if finished:
		return
	finished = true
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "shots", "potted": int(st["potted"]), "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("pool_lost", "\u00a1Sin tiros!"),
		Kit.text("pool_fail_hint", "Apunta a la bola por el lado contrario a la tronera y no tires tan fuerte: la blanca puede colarse."))
	p.closed.connect(retry)


## Segunda oportunidad (FailPanel, con anuncio): dos tiros mas.
func revive() -> void:
	st["shots"] = int(st["shots"]) + REVIVE_N
	st["lost"] = false
	finished = false
	failed = false
	_refresh()


func revive_text() -> String:
	return Kit.text("revive_tries", "+{n} intentos").format({"n": REVIVE_N})


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
	return {"pos": Vector2(float(st.get("potted", 0)), float(st.get("used", 0))), "deaths": deaths, "coins": coins, "finished": finished,
		"failed": failed, "stomps": 0, "time": time_in_level, "potted": int(st.get("potted", 0))}


# ------------------------------------------------------------------ dibujo

func _draw_world() -> void:
	if st.is_empty():
		return
	var table: Rect2 = Rect2(ORIGIN, Vector2(MapRules.TW, MapRules.TH))
	_world.draw_rect(table.grow(46.0), Color("#5a3218"))
	_world.draw_rect(table.grow(46.0), Color("#7a4a26"), false, 8.0)
	_world.draw_rect(table.grow(18.0), Color("#1e6a3a"))
	_world.draw_rect(table, Color("#2a8a4a"))
	for k: int in 3:
		var dy: float = MapRules.TH * (0.25 + 0.25 * float(k))
		_world.draw_circle(ORIGIN + Vector2(-32, dy), 4.0, Color("#f0e0b0"))
		_world.draw_circle(ORIGIN + Vector2(MapRules.TW + 32, dy), 4.0, Color("#f0e0b0"))
	_world.draw_line(ORIGIN + Vector2(0, MapRules.TH * 0.78), ORIGIN + Vector2(MapRules.TW, MapRules.TH * 0.78), Color(1, 1, 1, 0.15), 2.0)
	for pk: Vector2 in MapRules.POCKETS:
		_world.draw_circle(ORIGIN + pk, MapRules.POCKET_R + 4.0, Color("#3a2418"))
		_world.draw_circle(ORIGIN + pk, MapRules.POCKET_R, Color("#0a0a0a"))
	## Linea de apunte con la bola fantasma.
	var cue: Dictionary = st["balls"][0]
	if can_act() and _press != Vector2.INF and _press.distance_to(_drag) > 8.0:
		var a: Array = _aim()
		var dir: Vector2 = a[0]
		var from: Vector2 = ORIGIN + (cue["p"] as Vector2)
		var hit: Vector2 = from + dir * 1200.0
		var best: float = INF
		for b: Dictionary in st["balls"]:
			if int(b["id"]) == 0 or b["in"]:
				continue
			var c: Vector2 = ORIGIN + (b["p"] as Vector2)
			var tproj: float = (c - from).dot(dir)
			if tproj <= 0.0:
				continue
			var perp: float = (c - (from + dir * tproj)).length()
			if perp < MapRules.R * 2.0:
				var back: float = sqrt(maxf(0.0, MapRules.R * MapRules.R * 4.0 - perp * perp))
				if tproj - back < best:
					best = tproj - back
					hit = from + dir * (tproj - back)
		_world.draw_line(from, hit, Color(1, 1, 1, 0.7), 3.0)
		_world.draw_arc(hit, MapRules.R, 0.0, TAU, 20, Color(1, 1, 1, 0.7), 2.0)
		## Taco y fuerza.
		var pw: float = float(a[1])
		var tail: Vector2 = from - dir * (40.0 + pw * 140.0)
		_world.draw_line(tail, tail - dir * 360.0, Color("#c8a060"), 10.0)
		_world.draw_line(tail, tail - dir * 30.0, Color("#3a8ad8"), 10.0)
		_world.draw_rect(Rect2(Vector2(160, 1196), Vector2(400, 22)), Color(0, 0, 0, 0.5))
		_world.draw_rect(Rect2(Vector2(160, 1196), Vector2(400 * pw, 22)), Color("#ffd23f").lerp(Color("#e8343a"), pw))
	for b2: Dictionary in st["balls"]:
		if b2["in"]:
			continue
		var p: Vector2 = ORIGIN + (b2["p"] as Vector2)
		var col: Color = BALL_COLORS[int(b2["id"]) % BALL_COLORS.size()]
		_world.draw_circle(p + Vector2(3, 4), MapRules.R, Color(0, 0, 0, 0.3))
		_world.draw_circle(p, MapRules.R, col)
		if int(b2["id"]) > 0:
			_world.draw_circle(p, MapRules.R * 0.45, Color("#f8f8f4"))
			var s: String = str(int(b2["id"]))
			var wd: float = _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			_world.draw_string(_font, p + Vector2(-wd * 0.5, 4), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#222222"))
		_world.draw_circle(p + Vector2(-5, -5), MapRules.R * 0.25, Color(1, 1, 1, 0.55))
	if _msg_t > 0.0:
		var fs: int = 56
		var wd2: float = _font.get_string_size(_msg, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		for o: Vector2 in [Vector2(-3, 0), Vector2(3, 0), Vector2(0, -3), Vector2(0, 3)]:
			_world.draw_string(_font, Vector2(360 - wd2 * 0.5, 680) + o, _msg, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.8))
		_world.draw_string(_font, Vector2(360 - wd2 * 0.5, 680), _msg, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#fff3c0"))
