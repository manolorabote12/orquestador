extends Node2D
## Canasta: desliza hacia arriba para lanzar. Gesto mas largo = tiro mas fuerte.
## Reglas, vuelo, bot y analizador en hoops_map.gd.
## 1 - Aros que se mueven, triples desde la esquina y viento (la bandera dice hacia donde).
## 2 - Tres canastas seguidas dan un punto extra. Gana con las canastas que pide el nivel.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const MapRules = preload("res://kit/hoops/hoops_map.gd")
const PAUSE: float = 0.9

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
var _press: Vector2 = Vector2.INF
var _drag: Vector2 = Vector2.INF
var _shot: Dictionary = {}
var _msg: String = ""
var _msg_t: float = 0.0
var _t: float = 0.0


func _ready() -> void:
	level = Kit.current_level()
	par = float(level.get("par", 0))
	RenderingServer.set_default_clear_color(Color("#c8844a"))
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
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "hoops", "shots": (st["shots"] as Array).size()})


func bot_script() -> String:
	return "res://qa/hoops_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(0.5, 0.35)


func wants_backdrop() -> bool:
	return false


func _reset() -> void:
	finished = false
	failed = false
	st = MapRules.new_state(level)
	coins_total = int(st["goal"])
	coins = 0
	time_in_level = 0.0
	_shot = {}
	_msg_t = 0.0
	_press = Vector2.INF
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
	_score_label.text = "%d / %d" % [int(st["made"]), int(st["goal"])]
	coins = mini(int(st["made"]), coins_total)
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
			r2.color = Color("#56d36a") if str(res[i]) == "in" else Color("#e0404a")
		else:
			r2.color = Color("#fff3c0") if i == res.size() else Color(1, 1, 1, 0.35)


# ------------------------------------------------------------------ acciones

func can_act() -> bool:
	return not finished and is_inside_tree() and not get_tree().paused and _shot.is_empty() and _msg_t <= 0.0


func throw(swipe: Vector2) -> void:
	if not can_act() or bool(st["done"]):
		return
	var v: Vector2 = MapRules.velocity_of(swipe)
	var kind: String = MapRules.current(st)
	var from: Vector2 = MapRules.start_of(st)
	var wind: float = MapRules.wind_of(st)
	var t0: float = float(st["time"])
	var i: int = int(st["i"])
	var r: Dictionary = MapRules.shoot(st, v)
	_shot = {"v": v, "p": from, "vel": v, "wind": wind, "t": 0.0, "cross": float(r.get("t", 9.0)), "res": str(r.get("res", "miss")),
		"rim": bool(r.get("rim", false)), "kind": kind, "t0": t0, "i": i, "x": float(r.get("x", 360.0))}
	_sfx("click")


func _land() -> void:
	var res: String = str(_shot["res"])
	if res == "in":
		_msg = Kit.text("hoops_three", "\u00a1Triple!") if str(_shot["kind"]) == "f" else Kit.text("hoops_in", "\u00a1Canasta!")
		_sfx("coin")
	else:
		_msg = Kit.text("hoops_miss", "Fallo")
		if not fast:
			Audio.play("hurt", 0.05, -10.0)
	_msg_t = PAUSE
	_refresh()


func _sfx(n: String) -> void:
	if not fast:
		Audio.play(n, 0.1, -6.0)


func bot_step() -> void:
	if can_act():
		throw(MapRules.bot_swipe(st, float(st["time"])))


# ------------------------------------------------------------------ bucle

func _physics_process(delta: float) -> void:
	_t += delta
	var mult: float = 6.0 if fast else 1.0
	var dt: float = delta * mult
	time_in_level += dt
	if _shot.is_empty() and _msg_t <= 0.0:
		st["time"] = float(st["time"]) + dt
	if not _shot.is_empty():
		var steps: int = int(ceil(mult))
		for k: int in steps:
			_fly(dt / float(steps))
	if _msg_t > 0.0:
		_msg_t -= dt
		if _msg_t <= 0.0:
			_shot = {}
			if bool(st["done"]):
				if MapRules.won(st):
					_finish()
				else:
					_lose()
	if fast and auto_retry and not finished:
		bot_step()
	_world.queue_redraw()


## Vuelo del balon en pantalla: la misma fisica que MapRules.fly; al cruzar el aro se anota.
func _fly(dt: float) -> void:
	var vel: Vector2 = _shot["vel"]
	vel.y += MapRules.G * dt
	vel.x += float(_shot["wind"]) * dt
	_shot["t"] = float(_shot["t"]) + dt
	if float(_shot["t"]) >= float(_shot["cross"]) and not _shot.has("landed"):
		_shot["landed"] = true
		var hx: float = MapRules.hoop_x(_temp_state(), float(_shot["t0"]) + float(_shot["t"]))
		if str(_shot["res"]) == "in":
			_shot["p"] = Vector2(hx, MapRules.HOOP_Y)
			vel = Vector2(0, 300)
		elif bool(_shot["rim"]):
			vel = Vector2(signf(float(_shot["x"]) - hx) * 260.0, -500.0)
		_land()
	_shot["vel"] = vel
	_shot["p"] = (_shot["p"] as Vector2) + vel * dt


func _temp_state() -> Dictionary:
	return {"shots": st["shots"], "i": int(_shot.get("i", 0))}


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
			_press = p
			_drag = p
		elif not te.pressed and _press != Vector2.INF:
			if _press.y - p.y > 80.0:
				throw(p - _press)
			_press = Vector2.INF
	elif event is InputEventScreenDrag and _press != Vector2.INF:
		_drag = inv * (event as InputEventScreenDrag).position


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	coins = mini(int(st["made"]), coins_total)
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = int(st["points"]) * 150 + ((st["shots"] as Array).size() - int(st["i"])) * 100
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
	var misses: int = int(st["i"]) - int(st["made"])
	return 3 if misses == 0 else (2 if misses <= 1 else 1)


func _lose() -> void:
	if finished:
		return
	finished = true
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "hoops", "made": int(st["made"]), "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("hoops_lost", "\u00a1Faltaron canastas!"),
		Kit.text("hoops_fail_hint", "Desliza recto y con la misma fuerza; si el aro se mueve, lanza hacia donde va a estar."))
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
	return {"pos": Vector2(float(st.get("made", 0)), float(st.get("i", 0))), "deaths": deaths, "coins": coins, "finished": finished,
		"failed": failed, "stomps": 0, "time": time_in_level, "made": int(st.get("made", 0))}


# ------------------------------------------------------------------ dibujo

func _ball(at: Vector2, r: float, rot: float) -> void:
	_world.draw_circle(at + Vector2(4, 6), r, Color(0, 0, 0, 0.2))
	_world.draw_circle(at, r, Color("#f07a2a"))
	_world.draw_arc(at, r, 0.0, TAU, 24, Color("#5a2a10"), 2.5)
	_world.draw_line(at + Vector2(cos(rot), sin(rot)) * r, at - Vector2(cos(rot), sin(rot)) * r, Color("#5a2a10"), 2.5)
	_world.draw_arc(at + Vector2(cos(rot + PI * 0.5), sin(rot + PI * 0.5)) * r * 1.3, r, rot - PI * 0.85, rot - PI * 0.15, 10, Color("#5a2a10"), 2.5)


func _draw_world() -> void:
	if st.is_empty():
		return
	## Pabellon: grada, pared, parque de madera y linea de triple.
	_world.draw_rect(Rect2(-100, -100, 920, 320), Color("#2a3448"))
	for i: int in 50:
		_world.draw_circle(Vector2(fmod(float(i * 61), 760.0), 30.0 + float((i * 43) % 160)), 10.0, [Color("#e04a4a"), Color("#f2f2f2"), Color("#3f8cff"), Color("#ffd23f")][i % 4] * Color(1, 1, 1, 0.6))
	_world.draw_rect(Rect2(-100, 220, 920, 420), Color("#3a5a8a"))
	_world.draw_rect(Rect2(-100, 640, 920, 900), Color("#c8844a"))
	for i: int in 10:
		_world.draw_line(Vector2(-100, 660.0 + float(i) * 70.0), Vector2(820, 660.0 + float(i) * 70.0), Color(0, 0, 0, 0.08), 2.0)
	_world.draw_arc(Vector2(360, 1300), 520.0, PI * 1.12, PI * 1.88, 40, Color(1, 1, 1, 0.7), 5.0)
	## Tablero y aro.
	var kind: String = str(_shot.get("kind", MapRules.current(st)))
	var tnow: float = float(_shot["t0"]) + float(_shot["t"]) if not _shot.is_empty() else float(st["time"])
	var hx: float = MapRules.hoop_x({"shots": st["shots"], "i": int(_shot.get("i", int(st["i"])))}, tnow)
	if kind == "m":
		_world.draw_line(Vector2(150, 250), Vector2(570, 250), Color(1, 1, 1, 0.25), 6.0)
	_world.draw_rect(Rect2(hx - 110, 250, 220, 150), Color("#f4f4f0"))
	_world.draw_rect(Rect2(hx - 110, 250, 220, 150), Color("#c83a2a"), false, 6.0)
	_world.draw_rect(Rect2(hx - 40, 300, 80, 60), Color("#c83a2a"), false, 4.0)
	for k: int in 6:
		var x0: float = hx - MapRules.RIM + float(k) * MapRules.RIM * 2.0 / 5.0
		_world.draw_line(Vector2(x0, MapRules.HOOP_Y), Vector2(hx + (x0 - hx) * 0.6, MapRules.HOOP_Y + 80.0), Color(1, 1, 1, 0.8), 2.0)
	## Viento.
	var wind: float = float(_shot.get("wind", MapRules.wind_of(st)))
	if wind != 0.0:
		var fx: float = 640.0 if wind > 0.0 else 80.0
		_world.draw_line(Vector2(fx, 520), Vector2(fx, 640), Color("#dddddd"), 4.0)
		_world.draw_colored_polygon(PackedVector2Array([Vector2(fx, 520), Vector2(fx + signf(wind) * (50.0 + sin(_t * 8.0) * 6.0), 535), Vector2(fx, 550)]), Color("#e04a4a"))
	## Balon: detras del aro cuando baja por dentro.
	var back: bool = not _shot.is_empty() and _shot.has("landed") and str(_shot["res"]) == "in"
	if back:
		_ball(_shot["p"], 30.0 * 0.8, float(_shot["t"]) * 8.0)
	_world.draw_line(Vector2(hx - MapRules.RIM, MapRules.HOOP_Y), Vector2(hx + MapRules.RIM, MapRules.HOOP_Y), Color("#ff5a1a"), 8.0)
	if _shot.is_empty():
		if not bool(st["done"]):
			var from: Vector2 = MapRules.start_of(st)
			_ball(from, 44.0, 0.0)
			if _press != Vector2.INF and _drag.distance_to(_press) > 10.0:
				var v: Vector2 = MapRules.velocity_of(_drag - _press)
				var p: Vector2 = from
				var vel: Vector2 = v
				for k: int in 12:
					vel.y += MapRules.G * 0.05
					p += vel * 0.05
					_world.draw_circle(p, 6.0, Color(1, 1, 1, 0.6 - float(k) * 0.045))
	elif not back:
		var f: float = clampf(float(_shot["t"]) / maxf(0.2, float(_shot["cross"])), 0.0, 1.0)
		_ball(_shot["p"], lerpf(44.0, 30.0, f), float(_shot["t"]) * 8.0)
	if _msg_t > 0.0:
		var fs: int = 80
		var wd: float = _font.get_string_size(_msg, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		for o: Vector2 in [Vector2(-4, 0), Vector2(4, 0), Vector2(0, -4), Vector2(0, 4)]:
			_world.draw_string(_font, Vector2(360 - wd * 0.5, 780) + o, _msg, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.8))
		_world.draw_string(_font, Vector2(360 - wd * 0.5, 780), _msg, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#fff3c0"))
