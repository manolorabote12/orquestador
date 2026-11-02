extends Node2D
## Reversi contra la maquina: toca una casilla marcada para poner tu ficha; las fichas del rival
## encerradas se dan la vuelta. Reglas, rival, bot y analizador en reversi_map.gd.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const M = preload("res://kit/reversi/reversi_map.gd")
const BOARD: float = 672.0
const ORIGIN: Vector2 = Vector2(360.0 - BOARD * 0.5, 300.0)
const THINK: float = 0.6

var level: Dictionary = {}
var st: Dictionary = {}
var finished: bool = false
var failed: bool = false
var deaths: int = 0
var time_in_level: float = 0.0
var coins: int = 0
var coins_total: int = 1
var fast: bool = false
var auto_retry: bool = false
var result_panel: ResultPanel

var _world: Node2D
var _camera: Camera2D
var _turn_label: Label
var _hint_btn: Button
var _vs: VersusBar
var _flip_t: float = 1.0
var _think: float = 0.0
var _t: float = 0.0
var _passed: float = 0.0


func _ready() -> void:
	level = Kit.current_level()
	RenderingServer.set_default_clear_color(Color("#13261d"))
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
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "reversi", "rival": int(st["rival"]), "size": int(st["n"])})


func wants_grade() -> bool:
	return false


func bot_script() -> String:
	return "res://qa/reversi_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(4.0, 1.5)


func _reset() -> void:
	Hint.reset(self)
	finished = false
	failed = false
	st = M.new_state(level)
	coins = 0
	time_in_level = 0.0
	_flip_t = 1.0
	_think = THINK
	_passed = 0.0
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
	_turn_label = Label.new()
	_turn_label.name = "Turn"
	_turn_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_turn_label.add_theme_font_size_override("font_size", 34)
	_turn_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_turn_label.add_theme_constant_override("outline_size", 7)
	top.add_child(_turn_label)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)
	## Pista: la jugada que haria el bot (la primera gratis; despues anuncio o monedas).
	if not Kit.versus:
		_hint_btn = Hint.make_button(self, use_hint)
		_hint_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
		top.add_child(_hint_btn)
		top.move_child(_hint_btn, pause_btn.get_index())
	## Tu contra el rival: el heroe del juego, los marcadores y a quien le toca.
	_vs = VersusBar.make()
	col.add_child(_vs)


func _refresh() -> void:
	if _hint_btn != null:
		_hint_btn.text = Hint.label(self)
	if _turn_label == null or st.is_empty():
		return
	var txt: String = Kit.text("rv_you", "Tu turno") if int(st["turn"]) == 1 else Kit.text("rv_ai", "Piensa el rival...")
	if Kit.versus:
		txt = Versus.turn_text(int(st["turn"]))
	if _passed > 0.0:
		txt = Kit.text("rv_pass", "\u00a1Sin jugada: pasa!")
	_turn_label.text = txt
	if _vs != null:
		_vs.set_state(M.count(st["b"], 1), M.count(st["b"], 2), int(st["turn"]) == 1)


# ------------------------------------------------------------------ acciones

func _done() -> bool:
	return bool(st["won"]) or bool(st["lost"]) or bool(st["draw"])


func can_act() -> bool:
	return not finished and is_inside_tree() and not get_tree().paused and _flip_t >= 1.0 and (int(st["turn"]) == 1 or Kit.versus) and not _done()


func _cell() -> float:
	return BOARD / float(int(st["n"]))


func tap_cell(c: Vector2i) -> void:
	var n: int = int(st["n"])
	if not can_act() or c.x < 0 or c.x >= n or c.y < 0 or c.y >= n:
		return
	_do(c.y * n + c.x)


func _do(i: int) -> void:
	var before: int = int(st["turn"])
	if not M.play(st, i):
		return
	_flip_t = 0.0
	_think = THINK
	## El mismo vuelve a jugar: el otro paso.
	_passed = 1.2 if int(st["turn"]) == before and not _done() else 0.0
	_sfx("coin" if (st["flipped"] as Array).size() >= 3 else "click")
	_refresh()


func _sfx(nm: String) -> void:
	if not fast:
		Audio.play(nm, 0.1, -8.0)


## Pista: el siguiente movimiento lo hace el bot por ti (cuenta como tu jugada).
func use_hint() -> void:
	if not can_act():
		return
	if not await Hint.pay(self):
		Hint.say(self, Kit.text("hint_no_coins", "Te faltan monedas para la pista"))
		return
	if is_inside_tree() and can_act():
		bot_step()
	_refresh()


func bot_step() -> void:
	if can_act():
		var i: int = M.bot_move(st)
		if i >= 0:
			_do(i)


# ------------------------------------------------------------------ bucle

func _physics_process(delta: float) -> void:
	_t += delta
	var dt: float = delta * (8.0 if fast else 1.0)
	time_in_level += dt
	if _passed > 0.0:
		_passed = maxf(0.0, _passed - dt)
		if _passed == 0.0:
			_refresh()
	if _flip_t < 1.0:
		_flip_t = minf(1.0, _flip_t + dt * 3.0)
		if _flip_t >= 1.0:
			_check_end()
	elif not finished and not _done() and int(st["turn"]) == 2 and not Kit.versus:
		_think -= dt
		if _think <= 0.0:
			var i: int = M.rival_move(st)
			if i >= 0:
				_do(i)
	elif not finished and _done():
		_check_end()
	if fast and auto_retry and not finished:
		bot_step()
	_world.queue_redraw()


func _check_end() -> void:
	if Kit.versus and _done() and not finished:
		finished = true
		Versus.finish(self, 1 if bool(st["won"]) else (2 if bool(st["lost"]) else 0))
		return
	if bool(st["won"]):
		_finish()
	elif bool(st["lost"]) or bool(st["draw"]):
		_lose()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()
		return
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		var p: Vector2 = get_canvas_transform().affine_inverse() * (event as InputEventScreenTouch).position
		tap_cell(Vector2i(floori((p.x - ORIGIN.x) / _cell()), floori((p.y - ORIGIN.y) / _cell())))


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	coins = 1
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var me: int = M.count(st["b"], 1)
	var score: int = 500 + me * 20 - M.count(st["b"], 2) * 10
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "discs": me, "time": snappedf(time_in_level, 0.1), "deaths": deaths})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


## Estrellas: a la primera y con dos tercios del tablero, 3; a la primera, 2; si no, 1.
func stars_earned() -> int:
	if deaths > 0:
		return 1
	var me: int = M.count(st["b"], 1)
	return 3 if me * 3 >= int(st["n"]) * int(st["n"]) * 2 else 2


func _lose() -> void:
	if finished:
		return
	finished = true
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "draw" if bool(st["draw"]) else "reversi", "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var title: String = Kit.text("rv_draw", "\u00a1Empate!") if bool(st["draw"]) else Kit.text("rv_lost", "\u00a1Gan\u00f3 el rival!")
	var p: FailPanel = FailPanel.open(self, title,
		Kit.text("rv_fail_hint", "Las esquinas no se pueden dar la vuelta nunca: ve a por ellas y no pongas fichas al lado de una esquina libre."))
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
	return {"pos": Vector2(float(st.get("plies", 0)), 0.0), "deaths": deaths, "coins": coins, "finished": finished, "failed": failed,
		"stomps": 0, "time": time_in_level, "won": bool(st.get("won", false))}


# ------------------------------------------------------------------ dibujo

func _disc(c: Vector2, r: float, who: int, squash: float) -> void:
	var top: Color = Color("#1c1c22") if who == 1 else Color("#f3f0e6")
	var rim: Color = Color("#000000") if who == 1 else Color("#b9b2a0")
	var rx: float = r * maxf(0.08, absf(squash))
	var pts: PackedVector2Array = PackedVector2Array()
	var sh: PackedVector2Array = PackedVector2Array()
	for k: int in 24:
		var a: float = TAU * float(k) / 24.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * r))
		sh.append(c + Vector2(3.0 + cos(a) * rx, 5.0 + sin(a) * r))
	_world.draw_colored_polygon(sh, Color(0, 0, 0, 0.3))
	_world.draw_colored_polygon(pts, rim)
	var inner: PackedVector2Array = PackedVector2Array()
	for k2: int in 24:
		var a2: float = TAU * float(k2) / 24.0
		inner.append(c + Vector2(cos(a2) * rx * 0.88, sin(a2) * r * 0.88 - 2.0))
	_world.draw_colored_polygon(inner, top)


func _draw_world() -> void:
	if st.is_empty():
		return
	var n: int = int(st["n"])
	var cs: float = _cell()
	var b: Array = st["b"]
	var board: Rect2 = Rect2(ORIGIN, Vector2(BOARD, BOARD))
	_world.draw_rect(board.grow(18.0), Color("#3e2a17"))
	_world.draw_rect(board, Color("#1f7a4d"))
	for k: int in n + 1:
		var o: float = float(k) * cs
		_world.draw_line(ORIGIN + Vector2(o, 0), ORIGIN + Vector2(o, BOARD), Color("#11492e"), 3.0)
		_world.draw_line(ORIGIN + Vector2(0, o), ORIGIN + Vector2(BOARD, o), Color("#11492e"), 3.0)
	var hints: Array = M.moves(b, n, 1) if can_act() else []
	var flipped: Array = st["flipped"]
	for i: int in n * n:
		var c: Vector2 = ORIGIN + (Vector2(i % n, i / n) + Vector2(0.5, 0.5)) * cs
		if hints.has(i):
			_world.draw_circle(c, cs * 0.14, Color(1, 1, 1, 0.4 + 0.15 * sin(_t * 5.0)))
		var v: int = int(b[i])
		if v == 0:
			continue
		if i == int(st["last"]) and _flip_t < 1.0:
			_disc(c, cs * 0.4 * (0.6 + 0.4 * _flip_t), v, 1.0)
		elif flipped.has(i) and _flip_t < 1.0:
			## Media vuelta: se estrecha con el color viejo y se abre con el nuevo.
			var sq: float = cos(_flip_t * PI)
			_disc(c, cs * 0.4, v if sq < 0.0 else 3 - v, sq)
		else:
			_disc(c, cs * 0.4, v, 1.0)
