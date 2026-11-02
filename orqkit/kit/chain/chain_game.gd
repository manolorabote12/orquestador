extends Node2D
## Cadena de bolas (tipo Zuma): toca donde quieras disparar la bola del lanzador; toca el
## lanzador para cambiarla por la siguiente. Junta tres o mas del mismo color antes de que la
## cadena llegue al agujero. Reglas, bot y analizador en chain_map.gd (todo va por ticks).
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const M = preload("res://kit/chain/chain_map.gd")
const DT: float = 1.0 / float(M.TPS)
const BALL_COL: Array[String] = ["#ef476f", "#ffd166", "#06d6a0", "#4cc9f0", "#9d4edd"]

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

var _view: Control
var _info: Label
var _hero_tex: Texture2D = null
var _acc: float = 0.0
var _aim: Vector2 = Vector2(0, -1)
var _shot: Dictionary = {}
var _fx: Array = []
var _log_seen: int = 0
var _t: float = 0.0
var _bot_wait: int = 0


func _ready() -> void:
	level = Kit.current_level()
	RenderingServer.set_default_clear_color(Color("#1d2b22"))
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
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "chain", "balls": int(st["total"])})


func wants_grade() -> bool:
	return false


func bot_script() -> String:
	return "res://qa/chain_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(5.0, 2.5)


func _reset() -> void:
	finished = false
	failed = false
	st = M.new_state(level)
	coins_total = 0
	coins = 0
	time_in_level = 0.0
	_acc = 0.0
	_fx = []
	_shot = {}
	_log_seen = 0
	_bot_wait = 16
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
	var left: int = M.balls_left(st)
	_info.text = "%d   \u25cf %d" % [int(st["score"]), left]


func can_act() -> bool:
	return not finished and not failed and is_inside_tree() and not get_tree().paused and not bool(st["won"]) and not bool(st["lost"])


## Escala y origen del campo de 600 x 900 en la pantalla.
func _k() -> float:
	return minf(_view.size.x / M.FIELD.x, (_view.size.y - 150.0) / M.FIELD.y)


func _o() -> Vector2:
	var k: float = _k()
	return Vector2((_view.size.x - M.FIELD.x * k) * 0.5, 110.0 + (_view.size.y - 150.0 - M.FIELD.y * k) * 0.5)


func to_screen(p: Vector2) -> Vector2:
	return _o() + p * _k()


func to_field(p: Vector2) -> Vector2:
	return (p - _o()) / _k()


func shoot_at(field_point: Vector2) -> void:
	if not can_act() or int(st["cool"]) > 0:
		return
	var dir: Vector2 = field_point - (st["shooter"] as Vector2)
	if dir.length() < 5.0:
		return
	_aim = dir.normalized()
	var color: int = int(st["cur"])
	var r: Dictionary = M.fire(st, dir)
	if r.is_empty():
		return
	_shot = {"from": st["shooter"], "to": r["end"], "c": color, "t": 0.0}
	_sfx("shoot", -10.0)
	_collect_log()
	_check_end()


func swap_ball() -> void:
	if can_act():
		M.swap(st)
		_sfx("click", -10.0)


func _on_input(event: InputEvent) -> void:
	if auto_retry:
		return
	var pos: Vector2 = Vector2.INF
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		pos = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and not DisplayServer.is_touchscreen_available():
		pos = (event as InputEventMouseButton).position
	if pos == Vector2.INF:
		return
	var fp: Vector2 = to_field(pos)
	if fp.distance_to(st["shooter"]) < M.D * 1.3:
		swap_ball()
	else:
		shoot_at(fp)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()


func _sfx(nm: String, vol: float = -6.0) -> void:
	if not fast:
		Audio.play(nm, 0.1, vol)


func _bot_tick() -> void:
	_bot_wait -= 1
	if _bot_wait <= 0 and M.head(st) >= float(st["intro"]) * 0.5 and int(st["cool"]) <= 0:
		_bot_wait = 16
		var b: Dictionary = M.bot_shot(st)
		if (b["dir"] as Vector2) != Vector2.ZERO:
			if bool(b["swap"]):
				M.swap(st)
			shoot_at((st["shooter"] as Vector2) + (b["dir"] as Vector2))


func _tick() -> void:
	M.tick(st)
	_collect_log()
	_check_end()


func _check_end() -> void:
	if bool(st["won"]):
		_finish()
	elif bool(st["lost"]):
		_lose()


func _physics_process(delta: float) -> void:
	if st.is_empty() or get_tree().paused:
		return
	_t += delta
	if not finished and not failed:
		time_in_level += delta
		if fast and auto_retry:
			for k: int in 10:
				if not can_act():
					break
				_bot_tick()
				if can_act():
					_tick()
		else:
			_acc += delta
			while _acc >= DT and can_act():
				_acc -= DT
				if auto_retry:
					_bot_tick()
				if can_act():
					_tick()
	if not _shot.is_empty():
		_shot["t"] = float(_shot["t"]) + delta
		if float(_shot["t"]) > 0.14:
			_shot = {}
	for f: Variant in _fx:
		(f as Dictionary)["t"] = float((f as Dictionary)["t"]) + delta
	_fx = _fx.filter(func(f: Dictionary) -> bool: return float(f["t"]) < 0.8)
	_refresh()
	_view.queue_redraw()


func _collect_log() -> void:
	var lg: Array = st["log"]
	while _log_seen < lg.size():
		var e: Dictionary = lg[_log_seen]
		_log_seen += 1
		if str(e["k"]) == "pop":
			_fx.append({"at": e["at"], "n": int(e["n"]), "combo": int(e["combo"]), "c": int(e["c"]), "t": 0.0})
			_sfx("coin", -6.0 + 2.0 * float(mini(3, int(e["combo"]))))
			if not fast:
				Juice.vibrate(15)


# ------------------------------------------------------------------ dibujo

func _ball(c: Vector2, r: float, col: int) -> void:
	var cc: Color = Color(BALL_COL[col % BALL_COL.size()])
	_view.draw_circle(c + Vector2(0, r * 0.12), r, Color(0, 0, 0, 0.3))
	_view.draw_circle(c, r, cc)
	_view.draw_circle(c + Vector2(r * 0.15, r * 0.2), r * 0.7, cc.darkened(0.12))
	_view.draw_circle(c + Vector2(-r * 0.3, -r * 0.32), r * 0.28, Color(1, 1, 1, 0.6))


func _draw_view() -> void:
	if st.is_empty():
		return
	var k: float = _k()
	var sz: Vector2 = _view.size
	var bg: Color = Kit.color("ground", Color("#2e4a36")).darkened(0.35)
	_view.draw_rect(Rect2(Vector2.ZERO, sz), bg)
	## Surco del camino.
	var pts: PackedVector2Array = PackedVector2Array()
	for p: Variant in st["pts"]:
		pts.append(to_screen(p))
	_view.draw_polyline(pts, bg.darkened(0.45), M.D * k * 1.15, true)
	_view.draw_polyline(pts, bg.lightened(0.08), M.D * k * 0.9, true)
	## Entrada de la cadena.
	var ent: Vector2 = to_screen(M.at(st, 0.0))
	_view.draw_circle(ent, M.D * k * 0.95, bg.darkened(0.6))
	_view.draw_arc(ent, M.D * k * 0.95, 0.0, TAU, 24, Color(1, 1, 1, 0.25), 4.0)
	## Agujero al final.
	var hole: Vector2 = to_screen(M.at(st, float(st["len"])))
	var danger: float = clampf(M.head(st) / float(st["len"]), 0.0, 1.0)
	_view.draw_circle(hole, M.D * k * 1.1, Color(0.6 + 0.4 * danger * (0.5 + 0.5 * sin(_t * 10.0)), 0.1, 0.1))
	_view.draw_circle(hole, M.D * k * 0.8, Color("#0b0b0b"))
	## Bolas.
	var r: float = M.D * k * 0.5
	for sg: Variant in st["segs"]:
		var b: Array = sg["b"]
		for j: int in b.size():
			var s: float = float(sg["s"]) - float(j) * M.D
			if s < 0.0:
				break
			_ball(to_screen(M.at(st, s)), r, int(b[j]))
	## Explosiones.
	var font: Font = _view.get_theme_font("font", "Label")
	for f: Variant in _fx:
		var fd: Dictionary = f
		var c: Vector2 = to_screen(fd["at"])
		var tt: float = float(fd["t"]) / 0.8
		var col: Color = Color(BALL_COL[int(fd["c"]) % BALL_COL.size()])
		for i: int in 10:
			var a: float = TAU * float(i) / 10.0
			_view.draw_circle(c + Vector2(cos(a), sin(a)) * (20.0 + 90.0 * tt), 8.0 * (1.0 - tt), col)
		var txt: String = "+%d" % (int(fd["n"]) * 10 * int(fd["combo"])) + (" x%d" % int(fd["combo"]) if int(fd["combo"]) > 1 else "")
		_view.draw_string_outline(font, c - Vector2(30, 30 + 40.0 * tt), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, 6, Color.BLACK)
		_view.draw_string(font, c - Vector2(30, 30 + 40.0 * tt), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color.WHITE)
	## Disparo en vuelo.
	if not _shot.is_empty():
		var tt2: float = clampf(float(_shot["t"]) / 0.14, 0.0, 1.0)
		_ball(to_screen((_shot["from"] as Vector2).lerp(_shot["to"], tt2)), r, int(_shot["c"]))
	## Lanzador: el heroe que apunta, con la bola actual delante y la siguiente detras.
	var sc: Vector2 = to_screen(st["shooter"])
	_view.draw_circle(sc, M.D * k * 1.15, Color(0, 0, 0, 0.35))
	_view.draw_circle(sc, M.D * k * 1.05, Color("#f1faee"))
	if _hero_tex != null:
		var ts: Vector2 = _hero_tex.get_size()
		var kk: float = M.D * k * 1.5 / maxf(ts.x, ts.y)
		_view.draw_texture_rect(_hero_tex, Rect2(sc - ts * kk * 0.5, ts * kk), false)
	if can_act():
		_ball(sc + _aim * M.D * k * 1.25, r, int(st["cur"]))
		_ball(sc - _aim * M.D * k * 0.95, r * 0.55, int(st["next"]))
		## Guia de punteria.
		for i2: int in range(2, 9):
			_view.draw_circle(sc + _aim * M.D * k * (1.25 + float(i2) * 0.9), 3.0, Color(1, 1, 1, 0.35 - 0.035 * float(i2)))


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = int(st["score"]) + int((1.0 - M.head(st) / float(st["len"])) * 500.0)
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "coins": coins, "shots": int(st["shots"]), "time": snappedf(time_in_level, 0.1)})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


## Estrellas segun lo lejos que se quedo la cadena del agujero (y lo bien que apuntaste).
func stars_earned() -> int:
	var per: float = float(st["total"]) / maxf(1.0, float(st["shots"]))
	if per >= 1.6:
		return 3
	return 2 if per >= 1.1 else 1


func _lose() -> void:
	if failed:
		return
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "chain", "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("zu_lost", "\u00a1La cadena lleg\u00f3 al agujero!"),
		Kit.text("zu_hint", "Dispara primero cerca del agujero, cambia de bola tocando el lanzador y busca huecos que junten dos colores iguales para hacer combos."))
	p.closed.connect(retry)


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
	return {"deaths": deaths, "coins": coins, "finished": finished, "failed": failed, "stomps": 0, "time": time_in_level,
		"shots": int(st.get("shots", 0)), "left": M.balls_left(st) if not st.is_empty() else 0}
