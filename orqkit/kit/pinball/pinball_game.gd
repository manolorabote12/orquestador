extends Node2D
## Pinball: toca la mitad izquierda de la pantalla para la pala izquierda y la derecha para la
## derecha (mantener levanta la pala). Llega a los puntos del objetivo antes de perder las bolas.
## Fisica, bot y analizador en pinball_map.gd (60 ticks por segundo).
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const M = preload("res://kit/pinball/pinball_map.gd")

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
var hold_left: bool = false
var hold_right: bool = false

var _view: Control
var _info: Label
var _hero_tex: Texture2D = null
var _fingers: Dictionary = {}
var _trail: Array = []
var _fx: Array = []
var _log_seen: int = 0
var _t: float = 0.0
var _shake: float = 0.0


func _ready() -> void:
	level = Kit.current_level()
	RenderingServer.set_default_clear_color(Color("#0d0a1f"))
	var hero: Dictionary = Kit.sprite_by_role("jugador")
	if not hero.is_empty():
		var sf: SpriteFrames = SpriteKit.frames_de(hero)
		for anim: String in sf.get_animation_names():
			if sf.get_frame_count(anim) > 0:
				_hero_tex = sf.get_frame_texture(anim, 0)
				break
	_build_hud()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "pinball", "goal": int(st["goal"])})


func wants_grade() -> bool:
	return false


func bot_script() -> String:
	return "res://qa/pinball_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(3.0, 1.0)


func _reset() -> void:
	finished = false
	failed = false
	st = M.new_state(level)
	time_in_level = 0.0
	_trail = []
	_fx = []
	_log_seen = 0
	hold_left = false
	hold_right = false
	_fingers = {}
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
	_view = Control.new()
	_view.name = "View"
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.draw.connect(_draw_view)
	_view.gui_input.connect(_on_input)
	root.add_child(_view)
	var safe: MarginContainer = UI.safe_root(root, 14.0)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	safe.add_child(top)
	_info = Label.new()
	_info.name = "Info"
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.add_theme_font_size_override("font_size", 28)
	_info.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_info.add_theme_constant_override("outline_size", 6)
	top.add_child(_info)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)


func _refresh() -> void:
	if st.is_empty() or _info == null:
		return
	var balls: String = "\u25cf".repeat(maxi(0, int(st["balls"])))
	_info.text = "%d / %d   x%d   %s" % [int(st["score"]), int(st["goal"]), int(st["mult"]), balls]


func can_act() -> bool:
	return not finished and not failed and is_inside_tree() and not get_tree().paused and not bool(st["won"]) and not bool(st["lost"])


func _k() -> float:
	return minf(_view.size.x / M.W, (_view.size.y - 120.0) / M.H)


func _o() -> Vector2:
	var k: float = _k()
	return Vector2((_view.size.x - M.W * k) * 0.5, 110.0 + (_view.size.y - 120.0 - M.H * k) * 0.5)


func _s(p: Vector2) -> Vector2:
	var shake: Vector2 = Vector2(sin(_t * 67.0), cos(_t * 59.0)) * _shake * 6.0
	return _o() + p * _k() + shake


func _on_input(event: InputEvent) -> void:
	if auto_retry:
		return
	if event is InputEventScreenTouch:
		var t: InputEventScreenTouch = event as InputEventScreenTouch
		if t.pressed:
			_fingers[t.index] = t.position.x < _view.size.x * 0.5
		else:
			_fingers.erase(t.index)
	elif event is InputEventMouseButton and not DisplayServer.is_touchscreen_available():
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed:
			_fingers[-1] = mb.position.x < _view.size.x * 0.5
		else:
			_fingers.erase(-1)
	hold_left = false
	hold_right = false
	for f: Variant in _fingers.values():
		if bool(f):
			hold_left = true
		else:
			hold_right = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()


func _sfx(nm: String, vol: float = -6.0, pitch: float = 1.0) -> void:
	if not fast:
		Audio.play(nm, 0.06, vol, pitch)


func _tick() -> void:
	var l: bool = hold_left or Input.is_action_pressed("ui_left")
	var r: bool = hold_right or Input.is_action_pressed("ui_right")
	if auto_retry:
		var f: Array = M.bot_flips(st)
		l = bool(f[0])
		r = bool(f[1])
	var was: Array = [float(st["flip"][0]), float(st["flip"][1])]
	M.tick(st, l, r)
	if not fast:
		for i: int in 2:
			if was[i] == M.FLIP_REST and float(st["flip"][i]) < M.FLIP_REST:
				_sfx("click", -12.0)
	_collect_log()
	if bool(st["won"]):
		_finish()
	elif bool(st["lost"]):
		_lose()


func _physics_process(delta: float) -> void:
	if st.is_empty() or get_tree().paused:
		return
	_t += delta
	_shake = maxf(0.0, _shake - delta * 4.0)
	if not finished and not failed:
		time_in_level += delta
		var n: int = 30 if fast and auto_retry else 1
		for k: int in n:
			if not can_act():
				break
			_tick()
	if not (st["ball"] as Dictionary).is_empty():
		_trail.append(st["ball"]["p"])
		if _trail.size() > 8:
			_trail.pop_front()
	else:
		_trail = []
	for f: Variant in _fx:
		(f as Dictionary)["t"] = float((f as Dictionary)["t"]) + delta
	_fx = _fx.filter(func(f: Dictionary) -> bool: return float(f["t"]) < 0.7)
	_refresh()
	_view.queue_redraw()


func _collect_log() -> void:
	var lg: Array = st["log"]
	while _log_seen < lg.size():
		var e: Dictionary = lg[_log_seen]
		_log_seen += 1
		match str(e["k"]):
			"score":
				var what: String = str(e["what"])
				_fx.append({"at": e["at"], "txt": "+%d" % int(e["n"]), "t": 0.0, "big": what in ["bank", "lanes"]})
				if what == "bumper":
					_sfx("coin", -8.0, 1.2)
					_shake = maxf(_shake, 0.25)
				elif what in ["bank", "lanes"]:
					_sfx("powerup", -4.0)
				elif what == "target":
					_sfx("stomp", -8.0)
				else:
					_sfx("land", -10.0)
			"drain":
				_sfx("hurt", -4.0)
				_shake = 0.8
				if not fast:
					Juice.vibrate(30)
			"launch":
				_sfx("jump", -8.0)


# ------------------------------------------------------------------ dibujo

func _glow_line(a: Vector2, b: Vector2, col: Color, w: float) -> void:
	_view.draw_line(a, b, Color(col, 0.25), w * 2.6)
	_view.draw_line(a, b, col, w)


func _draw_view() -> void:
	if st.is_empty():
		return
	var k: float = _k()
	var o: Vector2 = _o()
	var sz: Vector2 = _view.size
	var neon: Color = Kit.color("player", Color("#4cc9f0"))
	if neon.get_luminance() < 0.3:
		neon = Color("#4cc9f0")
	var hot: Color = Color("#ff4d9d")
	_view.draw_rect(Rect2(Vector2.ZERO, sz), Color("#0d0a1f"))
	## Mesa.
	var table: PackedVector2Array = PackedVector2Array()
	for w: Variant in M.WALLS.slice(0, 7):
		table.append(_s(Vector2(float(w[0]), float(w[1]))))
	table.append(_s(Vector2(465, 790)))
	_view.draw_colored_polygon(table, Color("#1b1440"))
	for gy: int in 16:
		_view.draw_line(_s(Vector2(22, 50.0 * float(gy) + 40.0)), _s(Vector2(430, 50.0 * float(gy) + 40.0)), Color(1, 1, 1, 0.03), 1.0)
	## Pasillos de arriba.
	for li: int in 3:
		var lx: float = 180.0 + 60.0 * float(li)
		var lit: bool = bool(st["lanes"][li])
		_view.draw_circle(_s(Vector2(lx, 78)), 7.0 * k, Color("#ffd166") if lit else Color(1, 1, 1, 0.15))
		_glow_line(_s(Vector2(lx - 30.0, 60)), _s(Vector2(lx - 30.0, 96)), Color(neon, 0.6), 2.0)
	_glow_line(_s(Vector2(330, 60)), _s(Vector2(330, 96)), Color(neon, 0.6), 2.0)
	## Paredes.
	for w2: Variant in M.WALLS:
		_glow_line(_s(Vector2(float(w2[0]), float(w2[1]))), _s(Vector2(float(w2[2]), float(w2[3]))), neon, 4.0)
	## Tirachinas.
	for sl: Variant in M.SLINGS:
		_glow_line(_s(Vector2(float(sl[0]), float(sl[1]))), _s(Vector2(float(sl[2]), float(sl[3]))), hot, 6.0)
	## Dianas.
	for tg: Variant in st["targets"]:
		var tp: Vector2 = tg["p"]
		var col: Color = Color(1, 1, 1, 0.15) if bool(tg["down"]) else Color("#ffd166")
		_view.draw_rect(Rect2(_s(tp + Vector2(-14, -5)), Vector2(28, 10) * k), col)
	## Setas.
	for bm: Variant in st["bumpers"]:
		var c: Vector2 = _s(bm["p"])
		var fl: float = float(bm["flash"]) / 8.0
		_view.draw_circle(c, (M.BUMPER_R + 6.0) * k, Color(hot, 0.2 + 0.4 * fl))
		_view.draw_circle(c, M.BUMPER_R * k, hot.lerp(Color.WHITE, fl))
		_view.draw_circle(c, M.BUMPER_R * 0.6 * k, Color("#2a1b5c"))
		_view.draw_circle(c, M.BUMPER_R * 0.3 * k, Color("#ffd166"))
	## Palas.
	for i: int in 2:
		var a: Vector2 = _s(M.PIVOTS[i])
		var b: Vector2 = _s(M.flipper_tip(st, i))
		_view.draw_line(a, b, Color(neon, 0.3), M.FLIP_W * 2.0 * k + 8.0)
		_view.draw_line(a, b, Color("#f1faee"), M.FLIP_W * 2.0 * k)
		_view.draw_circle(a, M.FLIP_W * k, Color("#f1faee"))
		_view.draw_circle(b, M.FLIP_W * 0.7 * k, Color("#f1faee"))
		_view.draw_circle(a, M.FLIP_W * 0.4 * k, hot)
	## Bola (y su estela).
	for j: int in _trail.size():
		_view.draw_circle(_s(_trail[j]), M.R * k * (0.3 + 0.07 * float(j)), Color(1, 1, 1, 0.06 * float(j)))
	var ball: Dictionary = st["ball"]
	if not ball.is_empty():
		var bp: Vector2 = _s(ball["p"])
		_view.draw_circle(bp, M.R * k, Color("#cfd8dc"))
		_view.draw_circle(bp + Vector2(-3, -3) * k * 0.3, M.R * k * 0.45, Color.WHITE)
	## Heroe de mascota en el centro, entre las palas.
	if _hero_tex != null:
		var ts: Vector2 = _hero_tex.get_size()
		var hk: float = 46.0 * k / maxf(ts.x, ts.y)
		_view.draw_texture_rect(_hero_tex, Rect2(_s(Vector2(240, 560)) - ts * hk * 0.5, ts * hk), false, Color(1, 1, 1, 0.5))
	var font: Font = _view.get_theme_font("font", "Label")
	for fx: Variant in _fx:
		var fd: Dictionary = fx
		var p: Vector2 = _s(fd["at"]) - Vector2(20, 20.0 + 40.0 * float(fd["t"]))
		var size: int = 36 if bool(fd["big"]) else 24
		_view.draw_string_outline(font, p, str(fd["txt"]), HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, Color.BLACK)
		_view.draw_string(font, p, str(fd["txt"]), HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color("#ffd166"))
	## Pistas de control (solo al principio).
	if time_in_level < 4.0 and not auto_retry:
		var a2: float = clampf(1.0 - time_in_level / 4.0, 0.0, 1.0)
		_view.draw_string(font, Vector2(20, sz.y - 30), Kit.text("pb_left", "\u25c0 Toca aqu\u00ed"), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 1, 1, a2 * 0.7))
		_view.draw_string(font, Vector2(sz.x - 220, sz.y - 30), Kit.text("pb_right", "Toca aqu\u00ed \u25b6"), HORIZONTAL_ALIGNMENT_RIGHT, 200, 26, Color(1, 1, 1, a2 * 0.7))


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = int(st["score"])
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "coins": coins, "drained": int(st["drained"]), "time": snappedf(time_in_level, 0.1)})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


## Estrellas: sin perder bola, 3; perdiendo una, 2; si no, 1.
func stars_earned() -> int:
	var d: int = int(st["drained"])
	return 3 if d == 0 else (2 if d == 1 else 1)


func _lose() -> void:
	if failed:
		return
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "pinball", "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("pb_lost", "\u00a1Sin bolas!"),
		Kit.text("pb_hint", "Golpea cuando la bola est\u00e9 en la punta de la pala; si viene por el medio, levanta las dos. Enciende los tres pasillos de arriba para multiplicar."))
	p.closed.connect(retry)


func retry() -> void:
	_reset()


func open_pause() -> void:
	if finished or get_tree().paused or get_node_or_null("PauseMenu") != null:
		return
	_fingers = {}
	hold_left = false
	hold_right = false
	PauseMenu.open(self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_inside_tree() and not UI.test_mode:
			open_pause()


func bot_state() -> Dictionary:
	return {"deaths": deaths, "coins": coins, "finished": finished, "failed": failed, "stomps": 0, "time": time_in_level,
		"score": int(st.get("score", 0)), "drained": int(st.get("drained", 0))}
