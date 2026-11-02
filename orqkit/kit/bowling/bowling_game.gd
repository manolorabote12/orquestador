extends Node2D
## Bolos: desliza hacia arriba desde la bola. De donde empiezas = por donde sale; la direccion del
## gesto = hacia donde va; si el gesto se curva, la bola tambien. Fisica, bot y analizador en
## bowling_map.gd.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const MapRules = preload("res://kit/bowling/bowling_map.gd")
const NEAR_Y: float = 1150.0
const FAR_Y: float = 250.0
const NEAR_W: float = 560.0
const FAR_W: float = 230.0
const ANIM: float = 1.8

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
var _frames_row: HBoxContainer
var _touch: Array = []
var _shot: Dictionary = {}
var _msg: String = ""
var _msg_t: float = 0.0
var _t: float = 0.0


func _ready() -> void:
	level = Kit.current_level()
	par = float(level.get("par", 30))
	RenderingServer.set_default_clear_color(Color("#1e1a2a"))
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
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "bowling", "frames": (st["frames"] as Array).size()})


func bot_script() -> String:
	return "res://qa/bowling_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(0.9, 0.7)


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
	_info = Label.new()
	_info.name = "Info"
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.add_theme_font_size_override("font_size", 32)
	_info.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_info.add_theme_constant_override("outline_size", 6)
	top.add_child(_info)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)
	_frames_row = HBoxContainer.new()
	_frames_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_frames_row.add_theme_constant_override("separation", 6)
	_frames_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_frames_row)


func _refresh() -> void:
	if _info == null or st.is_empty():
		return
	coins = mini(int(st["score"]), coins_total)
	_info.text = "%s %d / %d" % [Kit.text("bowl_pins", "Bolos"), int(st["score"]), int(st["goal"])]
	for c: Node in _frames_row.get_children():
		c.queue_free()
	var rolls: Array = st["rolls"]
	var k: int = 0
	for f: int in (st["frames"] as Array).size():
		var txt: String = ""
		if k < rolls.size():
			var a: int = int(rolls[k])
			if a == 10:
				txt = "X"
				k += 1
			elif k + 1 < rolls.size():
				var b: int = int(rolls[k + 1])
				txt = "%d %s" % [a, "/" if a + b == 10 else str(b)]
				k += 2
			else:
				txt = "%d" % a
				k += 1
		var l: Label = Label.new()
		l.text = txt if txt != "" else "\u00b7"
		l.custom_minimum_size = Vector2(56, 40)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 22)
		l.add_theme_color_override("font_color", Color("#ffd23f") if f == int(st["f"]) else Color("#e8f0fa"))
		_frames_row.add_child(l)


# ------------------------------------------------------------------ carril en perspectiva

func lane_to_screen(p: Vector2) -> Vector2:
	var t: float = clampf(p.y / MapRules.LANE_L, -0.1, 1.1)
	var w: float = lerpf(FAR_W, NEAR_W, t)
	return Vector2(360.0 + (p.x - MapRules.LANE_W * 0.5) / MapRules.LANE_W * w, lerpf(FAR_Y, NEAR_Y, pow(t, 1.15)))


func lane_scale(p: Vector2) -> float:
	return lerpf(FAR_W, NEAR_W, clampf(p.y / MapRules.LANE_L, 0.0, 1.0)) / MapRules.LANE_W


# ------------------------------------------------------------------ acciones

func can_act() -> bool:
	return not finished and is_inside_tree() and not get_tree().paused and _shot.is_empty() and _msg_t <= 0.0


func throw(x0: float, angle: float, spin: float) -> void:
	if not can_act() or bool(st["done"]):
		return
	var sim: Dictionary = MapRules.copy_state(st)
	var path: Array = []
	MapRules.roll(sim, x0, angle, spin, path)
	var before: Array = []
	for pin: Dictionary in st["pins"]:
		before.append(pin.duplicate())
	var n: int = MapRules.throw_ball(st, x0, angle, spin)
	_shot = {"path": path, "t": 0.0, "before": before, "after": sim["pins"], "n": n}
	_sfx("click")


func _sfx(n: String) -> void:
	if not fast:
		Audio.play(n, 0.1, -6.0)


func bot_step() -> void:
	if can_act():
		var b: Array = MapRules.bot_throw(st)
		throw(float(b[0]), float(b[1]), float(b[2]))


# ------------------------------------------------------------------ bucle

func _physics_process(delta: float) -> void:
	_t += delta
	var dt: float = delta * (6.0 if fast else 1.0)
	time_in_level += dt
	if not _shot.is_empty():
		_shot["t"] = float(_shot["t"]) + dt
		if float(_shot["t"]) >= ANIM:
			var n: int = int(_shot["n"])
			_msg = Kit.text("bowl_strike", "\u00a1STRIKE!") if n == 10 else (Kit.text("bowl_spare", "\u00a1Semipleno!") if int(st["ball"]) == 0
				and (st["rolls"] as Array).size() >= 2 and n > 0 and int(st["rolls"][-1]) + int(st["rolls"][-2]) == 10 else "%d" % n)
			_msg_t = 0.9
			_shot = {}
			if n >= 5:
				_sfx("coin")
			_refresh()
	if _msg_t > 0.0:
		_msg_t -= dt
		if _msg_t <= 0.0 and bool(st["done"]):
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
		if te.pressed and p.y > 900.0:
			_touch = [p]
		elif not te.pressed and _touch.size() >= 3:
			_release()
			_touch = []
		else:
			_touch = []
	elif event is InputEventScreenDrag and not _touch.is_empty():
		_touch.append(inv * (event as InputEventScreenDrag).position)


## Del gesto a la tirada: salida (x del primer toque), angulo (del primer al ultimo punto) y
## efecto (cuanto se separa del recto el punto del medio).
func _release() -> void:
	var a: Vector2 = _touch[0]
	var b: Vector2 = _touch[_touch.size() - 1]
	if a.y - b.y < 120.0:
		return
	var mid: Vector2 = _touch[_touch.size() / 2]
	var x0: float = clampf((a.x - 360.0) / NEAR_W * MapRules.LANE_W + MapRules.LANE_W * 0.5, 30.0, MapRules.LANE_W - 30.0)
	var d: Vector2 = b - a
	var angle: float = clampf(atan2(d.x, -d.y) * 0.35, -0.25, 0.25)
	var straight: Vector2 = a.lerp(b, 0.5)
	var spin: float = clampf((straight.x - mid.x) / 120.0, -1.0, 1.0)
	throw(x0, angle, spin)


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	coins = coins_total
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = int(st["score"]) * 100 + int(st["strikes"]) * 300
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
	return 3 if int(st["score"]) >= int(par) else 2


func _lose() -> void:
	if finished:
		return
	finished = true
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "bowling", "score": int(st["score"]), "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("bowl_lost", "\u00a1Faltaron bolos!"),
		Kit.text("bowl_fail_hint", "Apunta un poco al lado del bolo de delante, no al centro, y desliza recto y con decisi\u00f3n."))
	p.closed.connect(retry)


## Segunda oportunidad (FailPanel, con anuncio): 1 intento(s) mas, iguales al ultimo.
const REVIVE_N: int = 1


func revive() -> void:
	var lista: Array = st["frames"]
	for i: int in REVIVE_N:
		lista.append(lista[lista.size() - 1])
	st["pins"] = MapRules.pins_start()
	st["ball"] = 0
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
	return {"pos": Vector2(float(st.get("score", 0)), float(st.get("f", 0))), "deaths": deaths, "coins": coins, "finished": finished,
		"failed": failed, "stomps": 0, "time": time_in_level, "score": int(st.get("score", 0))}


# ------------------------------------------------------------------ dibujo

func _pin(at: Vector2, k: float, fallen: bool, ang: float) -> void:
	_world.draw_set_transform(at, ang if fallen else 0.0, Vector2(k, k))
	var col: Color = Color("#fbfaf4")
	_world.draw_circle(Vector2(0, 0), 13.0, col)
	_world.draw_circle(Vector2(0, -20), 8.0, col)
	_world.draw_rect(Rect2(Vector2(-5, -18), Vector2(10, 14)), col)
	_world.draw_rect(Rect2(Vector2(-6, -14), Vector2(12, 3)), Color("#e8343a"))
	_world.draw_rect(Rect2(Vector2(-6, -9), Vector2(12, 3)), Color("#e8343a"))
	_world.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_world() -> void:
	if st.is_empty():
		return
	## Pista de madera en perspectiva con canales y flechas.
	var ln: Array = [Vector2(0, MapRules.LANE_L), Vector2(MapRules.LANE_W, MapRules.LANE_L), Vector2(MapRules.LANE_W, 0), Vector2(0, 0)]
	var pts: PackedVector2Array = PackedVector2Array()
	for q: Vector2 in ln:
		pts.append(lane_to_screen(q))
	_world.draw_rect(Rect2(-100, -100, 920, 1500), Color("#2a2238"))
	_world.draw_colored_polygon(PackedVector2Array([lane_to_screen(Vector2(-60, MapRules.LANE_L)), lane_to_screen(Vector2(MapRules.LANE_W + 60, MapRules.LANE_L)),
		lane_to_screen(Vector2(MapRules.LANE_W + 60, 0)), lane_to_screen(Vector2(-60, 0))]), Color("#3a3448"))
	_world.draw_colored_polygon(pts, Color("#d9a866"))
	for k: int in 12:
		var x: float = MapRules.LANE_W * float(k) / 12.0
		_world.draw_line(lane_to_screen(Vector2(x, MapRules.LANE_L)), lane_to_screen(Vector2(x, 0)), Color(0.6, 0.4, 0.2, 0.25), 1.5)
	if MapRules.current(st) == "o":
		_world.draw_colored_polygon(PackedVector2Array([lane_to_screen(Vector2(40, 1000)), lane_to_screen(Vector2(MapRules.LANE_W - 40, 1000)),
			lane_to_screen(Vector2(MapRules.LANE_W - 40, 500)), lane_to_screen(Vector2(40, 500))]), Color(1.0, 0.95, 0.7, 0.25))
	for k2: int in 5:
		var ax: float = MapRules.LANE_W * (0.2 + 0.15 * float(k2))
		var tip: Vector2 = lane_to_screen(Vector2(ax, 900))
		_world.draw_colored_polygon(PackedVector2Array([tip, lane_to_screen(Vector2(ax - 10, 940)), lane_to_screen(Vector2(ax + 10, 940))]), Color("#8a5a32"))
	if MapRules.current(st) == "b":
		_world.draw_rect(Rect2(lane_to_screen(Vector2(MapRules.LANE_W * 0.5 - 30, 410)) - Vector2(0, 14), Vector2(60.0 * lane_scale(Vector2(0, 410)), 16)), Color("#5a6a8a"))
	## Bolos: antes de que llegue la bola, como estaban; despues, como quedan (los caidos tumbados).
	var showing: Array = st["pins"]
	var ball_y: float = MapRules.LANE_L
	var ball_p: Vector2 = Vector2(MapRules.LANE_W * 0.5, MapRules.LANE_L - 60.0)
	if not _shot.is_empty():
		var path: Array = _shot["path"]
		var f: float = clampf(float(_shot["t"]) / (ANIM * 0.75), 0.0, 1.0)
		if not path.is_empty():
			ball_p = path[mini(path.size() - 1, int(f * float(path.size() - 1)))]
			ball_y = ball_p.y
		showing = _shot["before"]
	var pins_after: Array = _shot.get("after", [])
	for i: int in showing.size():
		var pin: Dictionary = showing[i]
		if pin["out"]:
			continue
		var gone: bool = not pins_after.is_empty() and bool(pins_after[i]["down"]) and ball_y < (pin["p"] as Vector2).y + 40.0
		var pp: Vector2 = pins_after[i]["p"] if gone else pin["p"]
		_pin(lane_to_screen(pp), lane_scale(pp) * 1.6, gone, 1.3 if i % 2 == 0 else -1.3)
	## Bola.
	if bool(st["done"]) and _shot.is_empty():
		return
	var bs: Vector2 = lane_to_screen(ball_p)
	var br: float = MapRules.BALL_R * lane_scale(ball_p) * 1.5
	_world.draw_circle(bs + Vector2(3, 5), br, Color(0, 0, 0, 0.3))
	_world.draw_circle(bs, br, Color("#2f5ad8"))
	_world.draw_circle(bs + Vector2(-br * 0.35, -br * 0.35), br * 0.25, Color(1, 1, 1, 0.4))
	for h: Vector2 in [Vector2(0.2, -0.3), Vector2(0.4, -0.05), Vector2(0.05, 0.05)]:
		_world.draw_circle(bs + h * br, br * 0.1, Color("#122a6a"))
	## Gesto en curso.
	if _touch.size() >= 2:
		for k3: int in range(1, _touch.size()):
			_world.draw_line(_touch[k3 - 1], _touch[k3], Color(1, 1, 1, 0.6), 6.0)
	if _msg_t > 0.0:
		var fs: int = 72
		var wd: float = _font.get_string_size(_msg, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		for o: Vector2 in [Vector2(-4, 0), Vector2(4, 0), Vector2(0, -4), Vector2(0, 4)]:
			_world.draw_string(_font, Vector2(360 - wd * 0.5, 640) + o, _msg, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.8))
		_world.draw_string(_font, Vector2(360 - wd * 0.5, 640), _msg, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#fff3c0"))
