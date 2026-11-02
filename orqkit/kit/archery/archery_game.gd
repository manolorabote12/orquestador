extends Node2D
## Tiro con arco: arrastra hacia atras para tensar (el angulo es el contrario y la fuerza, lo que
## estiras) y suelta. Mira el viento y las dianas que se mueven; los globos dan una flecha mas.
## Reglas, bot y analizador en archery_map.gd.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const MapRules = preload("res://kit/archery/archery_map.gd")
const S: float = 20.0
const GROUND: float = 0.0

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
var _drag: Vector2 = Vector2.INF
var _now: Vector2 = Vector2.INF
var _aim: Vector2 = Vector2(0.2, 0.0)
var _preview: Array = []
var _flight: Array = []
var _flight_t: float = 0.0
var _last: Dictionary = {}
var _hold: float = 0.0
var _bot: bool = false
var _bot_cd: float = 0.0
var _t: float = 0.0
var _stuck: Array = []
var _fit_zoom: float = 0.6
var _lupa: Control


func _ready() -> void:
	level = Kit.current_level()
	par = float(level.get("par", 30))
	RenderingServer.set_default_clear_color(Color("#9fd8ff"))
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
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "archery", "goal": int(st["goal"])})


func bot_script() -> String:
	return "res://qa/archery_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(1.2, 1.0)


func wants_backdrop() -> bool:
	return true


func _reset() -> void:
	finished = false
	failed = false
	st = MapRules.new_state(level)
	coins_total = int(st["goal"])
	coins = 0
	time_in_level = 0.0
	_flight = []
	_stuck = []
	_preview = []
	_last = {}
	var far: float = 20.0
	for tg: Dictionary in st["targets"]:
		far = maxf(far, (tg["p"] as Vector2).x)
	_fit_zoom = clampf(680.0 / ((far + 10.0) * S), 0.35, 1.2)
	_camera.zoom = Vector2(_fit_zoom, _fit_zoom)
	_camera.position = _home()
	_refresh()


func _home() -> Vector2:
	var view_w: float = 720.0 / _fit_zoom
	return Vector2(-6.0 * S + view_w * 0.5, -view_w * 0.55)


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
	_info.add_theme_font_size_override("font_size", 34)
	_info.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_info.add_theme_constant_override("outline_size", 7)
	top.add_child(_info)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)
	## Lupa: la diana de cerca, con las flechas clavadas (desde lejos se ve pequena).
	_lupa = Control.new()
	_lupa.name = "Lupa"
	_lupa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lupa.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_lupa.position = Vector2(-250, 130)
	_lupa.size = Vector2(230, 230)
	_lupa.draw.connect(_draw_lupa)
	root.add_child(_lupa)


func _refresh() -> void:
	if _info == null or st.is_empty():
		return
	coins = mini(int(st["score"]), coins_total)
	var w: float = float(st["wind"])
	var wind_txt: String = "" if absf(w) < 0.05 else "   %s %s%.1f" % [Kit.text("arc_wind", "Viento"), ">" if w > 0.0 else "<", absf(w)]
	_info.text = "%d / %d   %s %d%s" % [int(st["score"]), int(st["goal"]), Kit.text("arc_arrows", "Flechas"), int(st["arrows"]), wind_txt]


# ------------------------------------------------------------------ acciones

func can_act() -> bool:
	return not finished and is_inside_tree() and not get_tree().paused and _flight.is_empty() and _hold <= 0.0


func bot_step() -> void:
	_bot = true


func fire(angle: float, power: float) -> void:
	if not can_act() or int(st["arrows"]) <= 0:
		return
	var before: int = int(st["arrows"])
	_last = MapRules.shoot(st, angle, power, fast)
	_flight = (_last["path"] as Array).duplicate()
	_flight.append(_last["end"])
	_flight_t = 0.0
	_preview = []
	_sfx("shoot", -8.0)
	if fast:
		_land()
	QA.log_event("shot", {"points": int(_last["points"]), "arrows": before - 1})


func _land() -> void:
	var dy: float = 0.0
	if int(_last["target"]) >= 0:
		var tg0: Dictionary = st["targets"][int(_last["target"])]
		dy = ((_last["end"] as Vector2).y - MapRules.target_pos(tg0, float(st["t"])).y) / float(tg0["r"])
	_stuck.append({"p": _last["end"], "target": int(_last["target"]), "t": float(st["t"]), "dy": dy})
	_flight = []
	var pts: int = int(_last["points"])
	if pts > 0:
		_sfx("coin" if pts < 10 else "powerup", -6.0)
		Juice.vibrate(20 if pts < 10 else 45)
		if not fast:
			UI.float_text(_world, (_last["end"] as Vector2) * Vector2(S, -S) + Vector2(0, -50), Kit.text("arc_bull", "\u00a1Diana!") if pts == 10 else "+%d" % pts,
				Color("#ffd54a") if pts >= 9 else Color.WHITE, 40)
	if int(_last["balloon"]) >= 0:
		_sfx("stomp")
		if not fast:
			UI.float_text(_world, Vector2(0, -260), Kit.text("arc_extra", "+1 flecha"), Color("#ff8fa0"), 34)
	_hold = 0.0 if fast else 0.7
	_refresh()
	if MapRules.won(st):
		_finish()
	elif MapRules.lost(st):
		_lose()


func _sfx(n: String, vol: float = -10.0) -> void:
	if not fast:
		Audio.play(n, 0.1, vol)


# ------------------------------------------------------------------ bucle

func _physics_process(delta: float) -> void:
	_t += delta
	time_in_level += delta
	if not finished:
		st["t"] = float(st["t"]) + delta * (1.0 if not fast else 0.0)
	if fast and auto_retry:
		_bot = true
	if not _flight.is_empty():
		_flight_t += delta * 40.0
		if _flight_t >= float(_flight.size() - 1):
			_land()
	elif _hold > 0.0:
		_hold -= delta
	elif _bot and can_act():
		_bot_cd -= delta
		if _bot_cd <= 0.0 or fast:
			_bot_cd = 0.6
			var a: Vector2 = MapRules.bot_aim(st)
			_aim = a
			fire(a.x, a.y)
	## Camara: sigue a la flecha (mas cerca) y vuelve al arquero.
	var want_pos: Vector2 = _home()
	var want_zoom: float = _fit_zoom
	if not _flight.is_empty():
		want_pos = _arrow_px()
		want_zoom = minf(1.0, _fit_zoom * 1.6)
	_camera.position = _camera.position.lerp(want_pos, minf(1.0, delta * 5.0))
	var z: float = lerpf(_camera.zoom.x, want_zoom, minf(1.0, delta * 3.0))
	_camera.zoom = Vector2(z, z)
	_world.queue_redraw()
	if _lupa != null:
		_lupa.queue_redraw()


func _arrow_px() -> Vector2:
	if _flight.is_empty():
		return Vector2.ZERO
	var i: int = mini(int(_flight_t), _flight.size() - 1)
	return (_flight[i] as Vector2) * Vector2(S, -S)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()
		return
	if not can_act():
		return
	if event is InputEventScreenTouch:
		var te: InputEventScreenTouch = event
		if te.pressed:
			_bot = false
			_drag = te.position
			_now = te.position
		elif _drag != Vector2.INF:
			var pull: Vector2 = _drag - _now
			_drag = Vector2.INF
			if pull.length() > 30.0:
				fire(_aim.x, _aim.y)
			_preview = []
	elif event is InputEventScreenDrag and _drag != Vector2.INF:
		_now = (event as InputEventScreenDrag).position
		var pull2: Vector2 = _drag - _now
		## Se apunta hacia el otro lado de donde se tira (pantalla: y hacia abajo).
		_aim = Vector2(atan2(-pull2.y, maxf(1.0, pull2.x)), clampf(pull2.length() / 360.0, 0.0, 1.0))
		var r: Dictionary = MapRules.fly(st, _aim.x, _aim.y, float(st["t"]), true)
		var pts: Array = r["path"]
		_preview = pts.slice(0, maxi(2, pts.size() / 4))


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	coins = coins_total
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = int(st["score"]) * 100 + int(st["arrows"]) * 250
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "time": snappedf(time_in_level, 0.1), "deaths": deaths})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


## Estrellas: cuantas flechas sobran.
func stars_earned() -> int:
	if deaths > 0:
		return 1
	return 3 if int(st["arrows"]) >= 2 else 2


func _lose() -> void:
	if finished:
		return
	finished = true
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "arrows", "score": int(st["score"]), "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("arc_lost", "\u00a1Sin flechas!"),
		Kit.text("arc_fail_hint", "Mira la l\u00ednea de tiro, cuenta con el viento y, si la diana se mueve, suelta un poco antes."))
	p.closed.connect(retry)


## Segunda oportunidad (FailPanel, con anuncio): unas flechas mas para llegar a la meta.
const REVIVE_N: int = 3


func revive() -> void:
	st["arrows"] = int(st["arrows"]) + REVIVE_N
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
	return {"pos": Vector2(float(st.get("score", 0)), float(st.get("arrows", 0))), "deaths": deaths, "coins": coins, "finished": finished,
		"failed": failed, "stomps": 0, "time": time_in_level, "score": int(st.get("score", 0))}


# ------------------------------------------------------------------ dibujo

func _draw_world() -> void:
	if st.is_empty():
		return
	var t: float = float(st["t"])
	## Suelo y lineas de distancia cada 10 m.
	_world.draw_rect(Rect2(Vector2(-60.0 * S, 0), Vector2(220.0 * S, 40.0 * S)), Color("#5cb84a"))
	_world.draw_rect(Rect2(Vector2(-60.0 * S, 0), Vector2(220.0 * S, 10)), Color("#4aa03c"))
	for m: int in range(10, 100, 10):
		_world.draw_line(Vector2(float(m) * S, 0), Vector2(float(m) * S, 24), Color(1, 1, 1, 0.5), 3.0)
		_world.draw_string(_font, Vector2(float(m) * S - 20.0, 56), "%dm" % m, HORIZONTAL_ALIGNMENT_CENTER, 40, 24, Color(1, 1, 1, 0.7))
	## Dianas (con poste) y flechas clavadas.
	for ti: int in (st["targets"] as Array).size():
		var tg: Dictionary = st["targets"][ti]
		var c: Vector2 = MapRules.target_pos(tg, t) * Vector2(S, -S)
		var r: float = float(tg["r"]) * S
		_world.draw_line(Vector2(c.x, 0), c, Color("#8b5e34"), 6.0)
		_world.draw_rect(Rect2(c - Vector2(7, r), Vector2(14, r * 2.0)), Color("#e6e9ee"))
		var ring_cols: Array = [Color("#f2f2f2"), Color("#2a2d33"), Color("#3fa7ff"), Color("#ff4d4d"), Color("#ffd54a")]
		for k: int in 5:
			var rr: float = r * (1.0 - float(k) * 0.2)
			_world.draw_rect(Rect2(c - Vector2(8, rr), Vector2(16, rr * 2.0)), ring_cols[k])
	for sk: Dictionary in _stuck:
		var e: Vector2 = (sk["p"] as Vector2) * Vector2(S, -S)
		if int(sk["target"]) >= 0:
			var tg2: Dictionary = st["targets"][int(sk["target"])]
			e += (MapRules.target_pos(tg2, t) - MapRules.target_pos(tg2, float(sk["t"]))) * Vector2(S, -S)
		_world.draw_line(e, e + Vector2(-26, 6), Color("#5a3a20"), 3.0)
		_world.draw_line(e + Vector2(-26, 6), e + Vector2(-34, 2), Color("#ff5a5a"), 4.0)
	## Globos.
	for b: Dictionary in st["balloons"]:
		if not bool(b["popped"]):
			var bp: Vector2 = (b["p"] as Vector2) * Vector2(S, -S) + Vector2(0, sin(_t * 2.0) * 6.0)
			_world.draw_line(bp + Vector2(0, 18), bp + Vector2(0, 60), Color(1, 1, 1, 0.6), 1.5)
			_world.draw_circle(bp, 18.0, Color("#ff6b9a"))
			_world.draw_circle(bp + Vector2(-6, -6), 5.0, Color(1, 1, 1, 0.6))
	## Arquero y arco tensado.
	var bow: Vector2 = MapRules.BOW * Vector2(S, -S)
	_world.draw_rect(Rect2(bow + Vector2(-14, -4), Vector2(18, 25)), Kit.color("player", Color("#3fa7ff")))
	_world.draw_circle(bow + Vector2(-5, -16), 11.0, Color("#f2c49b"))
	var dir: Vector2 = Vector2(cos(_aim.x), -sin(_aim.x))
	_world.draw_arc(bow, 26.0, dir.angle() - 1.1, dir.angle() + 1.1, 12, Color("#8b5e34"), 5.0)
	var pull: float = _aim.y * 22.0 if _drag != Vector2.INF else 0.0
	_world.draw_line(bow + dir.rotated(-1.1) * 26.0, bow - dir * pull, Color(1, 1, 1, 0.8), 2.0)
	_world.draw_line(bow + dir.rotated(1.1) * 26.0, bow - dir * pull, Color(1, 1, 1, 0.8), 2.0)
	## Linea de tiro (solo el principio) y flecha en vuelo.
	for i: int in _preview.size():
		if i % 2 == 0:
			_world.draw_circle((_preview[i] as Vector2) * Vector2(S, -S), 4.0, Color(1, 1, 1, 0.8 - float(i) / float(_preview.size()) * 0.6))
	if not _flight.is_empty():
		var i2: int = mini(int(_flight_t), _flight.size() - 1)
		var p: Vector2 = (_flight[i2] as Vector2) * Vector2(S, -S)
		var q: Vector2 = (_flight[maxi(0, i2 - 1)] as Vector2) * Vector2(S, -S)
		var d2: Vector2 = (p - q).normalized() if p != q else Vector2.RIGHT
		_world.draw_line(p - d2 * 34.0, p, Color("#5a3a20"), 4.0)
		_world.draw_line(p - d2 * 34.0, p - d2 * 42.0, Color("#ff5a5a"), 6.0)
	## Viento: banderin junto al arquero.
	var w: float = float(st["wind"])
	_world.draw_line(Vector2(-3.0 * S, 0), Vector2(-3.0 * S, -90), Color("#c9ced6"), 4.0)
	_world.draw_colored_polygon(PackedVector2Array([Vector2(-3.0 * S, -90), Vector2(-3.0 * S + w * 14.0 + signf(w + 0.001) * 10.0, -80 + sin(_t * 6.0) * 3.0), Vector2(-3.0 * S, -70)]), Color("#ff5a5a"))


func _draw_lupa() -> void:
	if st.is_empty() or (st["targets"] as Array).is_empty():
		return
	var c: Vector2 = _lupa.size * 0.5
	var r: float = 100.0
	_lupa.draw_circle(c, r + 8.0, Color(0, 0, 0, 0.45))
	var ring_cols: Array = [Color("#f2f2f2"), Color("#2a2d33"), Color("#3fa7ff"), Color("#ff4d4d"), Color("#ffd54a")]
	for k: int in 5:
		_lupa.draw_circle(c, r * (1.0 - float(k) * 0.2), ring_cols[k])
	_lupa.draw_arc(c, r, 0, TAU, 48, Color("#8b5e34"), 4.0)
	## Las flechas de la ultima diana tocada (o de la primera), a su altura de verdad.
	var ti: int = 0
	for sk: Dictionary in _stuck:
		if int(sk["target"]) >= 0:
			ti = int(sk["target"])
	var n: int = 0
	for sk2: Dictionary in _stuck:
		if int(sk2["target"]) == ti:
			var q: Vector2 = c + Vector2(float(n % 3 - 1) * 14.0, -float(sk2["dy"]) * r)
			_lupa.draw_circle(q, 7.0, Color("#5a3a20"))
			_lupa.draw_circle(q, 3.0, Color("#ff5a5a"))
			n += 1
	if (st["targets"] as Array).size() > 1:
		_lupa.draw_string(_font, c + Vector2(-r, r + 30.0), Kit.text("arc_target", "Diana %d") % (ti + 1), HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 22, Color.WHITE)
