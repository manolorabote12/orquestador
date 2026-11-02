extends Node2D
## Simon dice: mira la secuencia de luces y repitela tocando los botones. Cada ronda, una luz mas.
## Reglas, bot y analizador en simon_map.gd. Contrato con el kit: finished, deaths, time_in_level,
## fast, auto_retry, bot_script(), bot_state(), retry(), open_pause() y ResultPanel/FailPanel.

const M = preload("res://kit/simon/simon_map.gd")
const COLS: Array[String] = ["#ef476f", "#ffd166", "#06d6a0", "#118ab2", "#9b5de5", "#f78c6b"]
const NOTES: Array[float] = [1.0, 1.122, 1.26, 1.335, 1.498, 1.682]

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
## Fase: "show" (la maquina ensena la secuencia) o "play" (te toca).
var phase: String = "show"
var _show_i: int = 0
var _show_t: float = 0.0
var _lit: int = -1
var _lit_t: float = 0.0
var _flash: float = 0.0
var _t: float = 0.0


func _ready() -> void:
	level = Kit.current_level()
	RenderingServer.set_default_clear_color(Color("#14141f"))
	_build_hud()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "simon", "goal": coins_total})


func bot_script() -> String:
	return "res://qa/simon_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(2.0, 1.6)


func _reset() -> void:
	finished = false
	failed = false
	st = M.new_state(level)
	coins_total = int(st["goal"])
	coins = 0
	time_in_level = 0.0
	_start_show(0.8)
	_refresh()


func _start_show(delay: float) -> void:
	phase = "show"
	_show_i = -1
	_show_t = -delay
	_lit = -1


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
	_info.add_theme_font_size_override("font_size", 28)
	top.add_child(_info)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)
	_view = Control.new()
	_view.name = "View"
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.draw.connect(_draw_view)
	_view.gui_input.connect(_on_input)
	col.add_child(_view)


func can_act() -> bool:
	return not finished and not failed and is_inside_tree() and not get_tree().paused and phase == "play"


## Centro y radio de cada boton (en circulo alrededor del centro).
func _pad_center(i: int) -> Vector2:
	var n: int = int(st["pads"])
	var c: Vector2 = _view.size * Vector2(0.5, 0.48)
	var r: float = minf(_view.size.x, _view.size.y) * 0.3
	var a: float = -PI * 0.5 + TAU * float(i) / float(n) + (PI / float(n) if n == 4 else 0.0)
	return c + Vector2(cos(a), sin(a)) * r


func _pad_radius() -> float:
	return minf(_view.size.x, _view.size.y) * (0.17 if int(st["pads"]) <= 4 else 0.14)


func press(p: int) -> void:
	if not can_act():
		return
	_light(p)
	var r: String = M.press(st, p)
	match r:
		"round":
			coins = int(st["round"]) - 1
			_sfx("coin", -8.0)
			_start_show(0.7)
		"won":
			coins = coins_total
			_refresh()
			_finish()
			return
		"miss":
			_flash = 0.6
			_sfx("hurt", -8.0)
			_start_show(1.0)
		"lost":
			_flash = 0.6
			_refresh()
			_lose()
			return
	_refresh()


func _light(p: int) -> void:
	_lit = p
	_lit_t = float(st["speed"]) * 0.7
	if not fast:
		Audio.play("click", 0.0, -6.0, NOTES[p % NOTES.size()])


func bot_step() -> void:
	if can_act():
		press(M.bot_press(st))


func _on_input(event: InputEvent) -> void:
	var p: Vector2 = Vector2.INF
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		p = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and not DisplayServer.is_touchscreen_available():
		p = (event as InputEventMouseButton).position
	if p == Vector2.INF:
		return
	for i: int in int(st["pads"]):
		if p.distance_to(_pad_center(i)) <= _pad_radius() * 1.1:
			press(i)
			return


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()


func _sfx(nm: String, vol: float = -6.0) -> void:
	if not fast:
		Audio.play(nm, 0.1, vol)


func _refresh() -> void:
	if st.is_empty() or _info == null:
		return
	var txt: String = Kit.text("sm_round", "Ronda {a}/{b}").format({"a": int(st["round"]), "b": int(st["goal"])})
	txt += "\n" + (Kit.text("sm_watch", "Mira...") if phase == "show" else Kit.text("sm_play", "\u00a1Tu turno!"))
	if int(st["lives"]) > 0:
		txt += "   " + Kit.text("sm_lives", "Fallos {a}/{b}").format({"a": int(st["mistakes"]), "b": int(st["lives"])})
	_info.text = txt
	_view.queue_redraw()


func _physics_process(delta: float) -> void:
	if st.is_empty() or get_tree().paused:
		return
	_t += delta
	var dt: float = delta * (10.0 if fast else 1.0)
	_lit_t -= dt
	_flash = maxf(0.0, _flash - delta)
	if not finished and not failed:
		time_in_level += delta
		if phase == "show":
			_show_t += dt
			var step: float = float(st["speed"])
			if _show_t >= 0.0:
				var k: int = int(_show_t / step)
				var seq: Array = M.current(st)
				if k >= seq.size():
					phase = "play"
					_lit = -1
					_refresh()
				elif fmod(_show_t, step) < step * 0.7:
					if k != _show_i or _lit < 0:
						_show_i = k
						_light(int(seq[k]))
				else:
					_lit = -1
		elif fast and auto_retry:
			bot_step()
	if _lit_t <= 0.0 and phase == "play":
		_lit = -1
	_view.queue_redraw()


# ------------------------------------------------------------------ dibujo

func _draw_view() -> void:
	if st.is_empty():
		return
	var c: Vector2 = _view.size * Vector2(0.5, 0.48)
	var big: float = minf(_view.size.x, _view.size.y) * 0.5
	_view.draw_circle(c, big, Color("#202033"))
	_view.draw_arc(c, big, 0.0, TAU, 64, Color(1, 0.3, 0.3, _flash) if _flash > 0.0 else Color("#2c2c44"), 8.0)
	var rr: float = _pad_radius()
	for i: int in int(st["pads"]):
		var col: Color = Color(COLS[i])
		var on: bool = _lit == i and _lit_t > 0.0
		var pc: Vector2 = _pad_center(i)
		if on:
			_view.draw_circle(pc, rr * 1.25, Color(col.r, col.g, col.b, 0.35))
		_view.draw_circle(pc + Vector2(0, 6), rr, col.darkened(0.55))
		_view.draw_circle(pc, rr, col.lightened(0.25) if on else col.darkened(0.25))
		_view.draw_circle(pc + Vector2(-rr * 0.3, -rr * 0.3), rr * 0.22, Color(1, 1, 1, 0.35 if on else 0.15))
	## Centro: progreso de la ronda (puntos).
	var seq_n: int = int(st["round"])
	for k: int in seq_n:
		var a: float = -PI * 0.5 + TAU * float(k) / float(maxi(seq_n, 1))
		var done: bool = phase == "play" and k < int(st["pos"])
		_view.draw_circle(c + Vector2(cos(a), sin(a)) * big * 0.18, 7.0, Color("#ffffff") if done else Color("#55557a"))


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = maxi(1, int(st["goal"]) * 100 - int(st["mistakes"]) * 80)
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "coins": coins, "time": snappedf(time_in_level, 0.1)})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


func stars_earned() -> int:
	return 3 if int(st["mistakes"]) == 0 else (2 if int(st["mistakes"]) == 1 else 1)


func _lose() -> void:
	if failed:
		return
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "simon", "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("sm_lost", "\u00a1Te equivocaste!"),
		Kit.text("sm_hint", "Dilo en voz baja mientras miras (rojo, azul, azul, verde...) o fijate en el sonido de cada boton."))
	p.closed.connect(retry)


## Segunda oportunidad (FailPanel, con anuncio): un fallo mas y se repite la ronda.
func revive() -> void:
	st["lost"] = false
	st["mistakes"] = int(st["lives"])
	st["pos"] = 0
	failed = false
	_start_show(1.0)
	_refresh()


func revive_text() -> String:
	return Kit.text("revive_life", "Una vida m\u00e1s")


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
		"round": int(st.get("round", 0))}
