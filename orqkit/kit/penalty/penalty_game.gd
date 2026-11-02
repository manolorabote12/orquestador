extends Node2D
## Penaltis: desliza desde el balon hacia la porteria. Mas largo = mas alto; de lado = a un lado.
## Reglas, portero, bot y analizador en penalty_map.gd.
## 1 - Antes de cada tiro el portero se inclina hacia un lado: suele tirarse ahi (no siempre).
## 2 - Barrera: tapa los tiros bajos al centro. Diana dorada: marcar dentro vale doble.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const MapRules = preload("res://kit/penalty/penalty_map.gd")
const GOAL_L: float = 120.0
const GOAL_R: float = 600.0
const BAR_Y: float = 330.0
const GROUND_Y: float = 600.0
const BALL: Vector2 = Vector2(360, 1060)
const FLIGHT: float = 0.55
const PAUSE: float = 1.1

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
var _score_label: Label
var _dots: HBoxContainer
var _swipe_a: Vector2 = Vector2.INF
var _swipe_b: Vector2 = Vector2.INF
var _flight: Dictionary = {}
var _msg: String = ""
var _msg_t: float = 0.0
var _t: float = 0.0


func _ready() -> void:
	level = Kit.current_level()
	par = float(level.get("par", 0))
	RenderingServer.set_default_clear_color(Color("#2a6a3a"))
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
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "penalty", "shots": (st["shots"] as Array).size()})


func bot_script() -> String:
	return "res://qa/penalty_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(0.3, 0.3)


func wants_backdrop() -> bool:
	return false


func _reset() -> void:
	finished = false
	failed = false
	st = MapRules.new_state(level)
	coins_total = int(st["need"])
	coins = 0
	time_in_level = 0.0
	_flight = {}
	_msg_t = 0.0
	_swipe_a = Vector2.INF
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
	top.add_child(UiIcon.make("trophy", Color("#ffd23f"), 40.0))
	_score_label = Label.new()
	_score_label.name = "Score"
	_score_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_score_label.add_theme_font_size_override("font_size", 36)
	_score_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_score_label.add_theme_constant_override("outline_size", 7)
	top.add_child(_score_label)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)
	_dots = HBoxContainer.new()
	_dots.name = "Shots"
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	_dots.add_theme_constant_override("separation", 8)
	_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_dots)


func _refresh() -> void:
	if _score_label == null or st.is_empty():
		return
	_score_label.text = "%d / %d" % [int(st["points"]), int(st["need"])]
	coins = mini(int(st["points"]), coins_total)
	var shots: Array = st["shots"]
	if _dots.get_child_count() != shots.size():
		for c: Node in _dots.get_children():
			c.queue_free()
		for i: int in shots.size():
			var r: ColorRect = ColorRect.new()
			r.custom_minimum_size = Vector2(26, 26)
			r.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_dots.add_child(r)
	var res: Array = st["results"]
	for i: int in _dots.get_child_count():
		var r2: ColorRect = _dots.get_child(i)
		if i < res.size():
			r2.color = Color("#56d36a") if str(res[i]) in ["goal", "double"] else Color("#e0404a")
		else:
			r2.color = Color(1, 1, 1, 0.35) if i != res.size() else Color("#fff3c0")


# ------------------------------------------------------------------ acciones

func can_act() -> bool:
	return not finished and is_inside_tree() and not get_tree().paused and _flight.is_empty() and _msg_t <= 0.0


func goal_to_screen(g: Vector2) -> Vector2:
	return Vector2(360.0 + g.x * (GOAL_R - GOAL_L) * 0.5, GROUND_Y - g.y * (GROUND_Y - BAR_Y))


## Del deslizamiento a un punto de la porteria: el lado por la x y la altura por lo largo.
func swipe_to_aim(a: Vector2, b: Vector2) -> Vector2:
	var d: Vector2 = b - a
	return Vector2(d.x / 260.0, clampf((-d.y - 150.0) / 450.0, -0.1, 1.3))


func shoot(aim: Vector2) -> void:
	if not can_act() or bool(st["done"]):
		return
	var dive: int = int(st["dive"])
	var kind: String = MapRules.current(st)
	var target: Vector2 = st["target"]
	var res: String = MapRules.shoot(st, aim)
	_flight = {"aim": aim, "res": res, "t": 0.0, "dive": dive, "kind": kind, "target": target}
	_sfx("click")


func _land() -> void:
	var res: String = str(_flight["res"])
	_msg = {"goal": Kit.text("pen_goal", "\u00a1GOL!"), "double": Kit.text("pen_double", "\u00a1GOLAZO x2!"),
		"saved": Kit.text("pen_saved", "\u00a1Parada!"), "wall": Kit.text("pen_wall", "\u00a1Barrera!"), "out": Kit.text("pen_out", "Fuera")}[res]
	_msg_t = PAUSE
	if res in ["goal", "double"]:
		_sfx("coin")
	elif not fast:
		Audio.play("hurt", 0.05, -8.0)
	_refresh()


func _sfx(n: String) -> void:
	if not fast:
		Audio.play(n, 0.1, -6.0)


func bot_step() -> void:
	if can_act():
		shoot(MapRules.bot_aim(st))


# ------------------------------------------------------------------ bucle

func _physics_process(delta: float) -> void:
	_t += delta
	var dt: float = delta * (6.0 if fast else 1.0)
	time_in_level += dt
	if not _flight.is_empty():
		_flight["t"] = float(_flight["t"]) + dt
		if float(_flight["t"]) >= FLIGHT and not _flight.has("landed"):
			_flight["landed"] = true
			_land()
	if _msg_t > 0.0:
		_msg_t -= dt
		if _msg_t <= 0.0:
			_flight = {}
			if bool(st["done"]):
				if MapRules.won(st):
					_finish()
				else:
					_lose()
	if fast and auto_retry and not finished:
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
		if te.pressed and p.y > 760.0:
			_swipe_a = p
			_swipe_b = p
		elif not te.pressed and _swipe_a != Vector2.INF:
			if _swipe_a.y - p.y > 80.0:
				shoot(swipe_to_aim(_swipe_a, p))
			_swipe_a = Vector2.INF
	elif event is InputEventScreenDrag and _swipe_a != Vector2.INF:
		_swipe_b = inv * (event as InputEventScreenDrag).position


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	coins = mini(int(st["points"]), coins_total)
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = int(st["points"]) * 300 + ((st["shots"] as Array).size() - int(st["i"])) * 150
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "time": snappedf(time_in_level, 0.1), "deaths": deaths,
		"shots": int(st["i"])})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


func stars_earned() -> int:
	if deaths > 0:
		return 1
	var misses: int = int(st["i"]) - int(st["goals"])
	return 3 if misses == 0 else (2 if misses <= 1 else 1)


func _lose() -> void:
	if finished:
		return
	finished = true
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "penalty", "points": int(st["points"]), "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("pen_lost", "\u00a1Sin goles suficientes!"),
		Kit.text("pen_fail_hint", "F\u00edjate hacia d\u00f3nde se inclina el portero y chuta alto al otro lado."))
	p.closed.connect(retry)


## Segunda oportunidad (FailPanel, con anuncio): 2 intento(s) mas, iguales al ultimo.
const REVIVE_N: int = 2


func revive() -> void:
	var lista: Array = st["shots"]
	for i: int in REVIVE_N:
		lista.append(lista[lista.size() - 1])
	st["done"] = false
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
	return {"pos": Vector2(float(st.get("points", 0)), float(st.get("i", 0))), "deaths": deaths, "coins": coins, "finished": finished,
		"failed": failed, "stomps": 0, "time": time_in_level, "goals": int(st.get("goals", 0))}


# ------------------------------------------------------------------ dibujo

func _player(at: Vector2, k: float, shirt: Color, angle: float = 0.0) -> void:
	_world.draw_set_transform(at, angle, Vector2(k, k))
	_world.draw_rect(Rect2(Vector2(-16, 0), Vector2(12, 60)), Color("#1e2a3a"))
	_world.draw_rect(Rect2(Vector2(4, 0), Vector2(12, 60)), Color("#1e2a3a"))
	_world.draw_rect(Rect2(Vector2(-26, -70), Vector2(52, 74)), shirt)
	_world.draw_rect(Rect2(Vector2(-44, -66), Vector2(18, 50)), shirt)
	_world.draw_rect(Rect2(Vector2(26, -66), Vector2(18, 50)), shirt)
	_world.draw_circle(Vector2(-35, -12), 11.0, Color("#f6f6f0"))
	_world.draw_circle(Vector2(35, -12), 11.0, Color("#f6f6f0"))
	_world.draw_circle(Vector2(0, -92), 22.0, Color("#f1c9a0"))
	_world.draw_arc(Vector2(0, -96), 22.0, PI, TAU, 12, Color("#3a2a1e"), 10.0)
	_world.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _ball(at: Vector2, r: float, rot: float) -> void:
	_world.draw_circle(at + Vector2(r * 0.2, r * 0.3), r, Color(0, 0, 0, 0.25))
	_world.draw_circle(at, r, Color("#f8f8f4"))
	for k: int in 5:
		var a: float = rot + float(k) * TAU / 5.0
		_world.draw_circle(at + Vector2(cos(a), sin(a)) * r * 0.55, r * 0.2, Color("#2a2a2e"))
	_world.draw_circle(at, r * 0.22, Color("#2a2a2e"))


func _draw_world() -> void:
	if st.is_empty():
		return
	## Grada, cesped a rayas, area y punto de penalti.
	_world.draw_rect(Rect2(-100, -100, 920, 360), Color("#2a3448"))
	for i: int in 60:
		var cx: float = fmod(float(i * 53), 760.0)
		var cy: float = 40.0 + float((i * 37) % 200)
		_world.draw_circle(Vector2(cx, cy), 9.0, [Color("#e04a4a"), Color("#f2f2f2"), Color("#3f8cff"), Color("#ffd23f")][i % 4] * Color(1, 1, 1, 0.7))
	_world.draw_rect(Rect2(-100, 255, 920, 12), Color("#c8c8c0"))
	for i: int in 12:
		_world.draw_rect(Rect2(-100, 267.0 + float(i) * 90.0, 920, 90), Color("#3f9a4a") if i % 2 == 0 else Color("#4aa856"))
	_world.draw_line(Vector2(-100, GROUND_Y), Vector2(820, GROUND_Y), Color(1, 1, 1, 0.8), 4.0)
	_world.draw_polyline(PackedVector2Array([Vector2(40, GROUND_Y), Vector2(-60, 900), Vector2(780, 900), Vector2(680, GROUND_Y)]), Color(1, 1, 1, 0.6), 4.0)
	_world.draw_circle(BALL + Vector2(0, 20), 8.0, Color(1, 1, 1, 0.7))
	## Porteria con red.
	_world.draw_rect(Rect2(GOAL_L, BAR_Y, GOAL_R - GOAL_L, GROUND_Y - BAR_Y), Color(1, 1, 1, 0.08))
	for i: int in 17:
		var x: float = GOAL_L + float(i) * (GOAL_R - GOAL_L) / 16.0
		_world.draw_line(Vector2(x, BAR_Y), Vector2(x, GROUND_Y), Color(1, 1, 1, 0.25), 1.5)
	for i: int in 9:
		var y: float = BAR_Y + float(i) * (GROUND_Y - BAR_Y) / 8.0
		_world.draw_line(Vector2(GOAL_L, y), Vector2(GOAL_R, y), Color(1, 1, 1, 0.25), 1.5)
	var kind: String = str(_flight.get("kind", MapRules.current(st)))
	if kind == "T":
		var tg: Vector2 = goal_to_screen(_flight.get("target", st["target"]))
		_world.draw_arc(tg, 0.18 * 240.0, 0.0, TAU, 32, Color("#ffd23f"), 7.0)
		_world.draw_circle(tg, 0.18 * 240.0, Color(1.0, 0.82, 0.25, 0.25))
	## Portero: se inclina antes del tiro y se estira durante el vuelo.
	var kp: Vector2 = Vector2(360, GROUND_Y - 10)
	var ang: float = 0.0
	if not _flight.is_empty():
		var f: float = clampf(float(_flight["t"]) / FLIGHT, 0.0, 1.0)
		var dv: int = int(_flight["dive"])
		kp += Vector2(float(dv) * MapRules.DIVE_X * 240.0 * f, -40.0 * f * absf(float(dv)))
		ang = float(dv) * 1.2 * f
	else:
		ang = float(int(st["lean"])) * (0.16 + 0.04 * sin(_t * 6.0))
		kp.x += float(int(st["lean"])) * 10.0
	_player(kp, 1.15, Color("#ffcf3a"), ang)
	_world.draw_rect(Rect2(GOAL_L - 10, BAR_Y - 10, 10, GROUND_Y - BAR_Y + 10), Color("#ffffff"))
	_world.draw_rect(Rect2(GOAL_R, BAR_Y - 10, 10, GROUND_Y - BAR_Y + 10), Color("#ffffff"))
	_world.draw_rect(Rect2(GOAL_L - 10, BAR_Y - 10, GOAL_R - GOAL_L + 20, 10), Color("#ffffff"))
	## Barrera.
	if kind == "W":
		for i: int in 3:
			_player(Vector2(300.0 + float(i) * 60.0, 840.0), 0.9, Color("#3f6ad8"))
	## Balon: en el punto o volando hacia la porteria.
	if _flight.is_empty():
		_ball(BALL, 34.0, 0.0)
		if _swipe_a != Vector2.INF and _swipe_b.distance_to(_swipe_a) > 10.0:
			var aim: Vector2 = swipe_to_aim(_swipe_a, _swipe_b)
			var to: Vector2 = goal_to_screen(aim)
			for k: int in 8:
				_world.draw_circle(BALL.lerp(to, float(k) / 8.0), 6.0, Color(1, 1, 1, 0.6 - float(k) * 0.06))
	else:
		var f2: float = clampf(float(_flight["t"]) / FLIGHT, 0.0, 1.0)
		var to2: Vector2 = goal_to_screen(_flight["aim"])
		var res: String = str(_flight["res"])
		if res == "saved" and f2 > 0.85:
			to2 = kp + Vector2(0, -60)
		elif res == "wall":
			to2 = Vector2(360, 790)
		var pos: Vector2 = BALL.lerp(to2, f2) + Vector2(0, -sin(f2 * PI) * 120.0)
		_ball(pos, lerpf(34.0, 18.0, f2), f2 * 12.0)
	if _msg_t > 0.0:
		var fs: int = 84
		var wd: float = _font.get_string_size(_msg, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		for o: Vector2 in [Vector2(-4, 0), Vector2(4, 0), Vector2(0, -4), Vector2(0, 4)]:
			_world.draw_string(_font, Vector2(360 - wd * 0.5, 760) + o, _msg, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.8))
		_world.draw_string(_font, Vector2(360 - wd * 0.5, 760), _msg, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#fff3c0"))
