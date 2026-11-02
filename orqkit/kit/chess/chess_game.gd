extends Node2D
## Ajedrez contra la maquina: toca una pieza tuya y luego la casilla a la que va (se iluminan).
## Reglas, rival, bot y analizador en chess_map.gd (sin enroque ni captura al paso; el peon corona dama).
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const M = preload("res://kit/chess/chess_map.gd")
const CELL: float = 84.0
const ORIGIN: Vector2 = Vector2(360.0 - 4.0 * CELL, 300.0)
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
var selected: int = -1

var _world: Node2D
var _camera: Camera2D
var _turn_label: Label
var _hint_btn: Button
var _vs: VersusBar
var _anim: Dictionary = {}
var _think: float = 0.0
var _t: float = 0.0
var _taken: Dictionary = {"w": 0, "b": 0}


func _ready() -> void:
	level = Kit.current_level()
	RenderingServer.set_default_clear_color(Color("#1f2a33"))
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
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "chess", "rival": int(st["rival"])})


## Tablero claro: sin el brillo del etalonaje (lo quemaria).
func wants_grade() -> bool:
	return false


func bot_script() -> String:
	return "res://qa/chess_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(4.0, 1.5)


func _reset() -> void:
	Hint.reset(self)
	finished = false
	failed = false
	st = M.new_state(level)
	coins = 0
	time_in_level = 0.0
	selected = -1
	_anim = {}
	_think = THINK
	_taken = {"w": 0, "b": 0}
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
	var txt: String = Kit.text("ch_you", "Tu turno") if bool(st["white"]) else Kit.text("ch_ai", "Piensa el rival...")
	if Kit.versus:
		txt = Versus.turn_text(1 if bool(st["white"]) else 2)
	if M.in_check(st["b"], bool(st["white"])) and not finished:
		txt += "  " + Kit.text("ch_check", "\u00a1Jaque!")
	_turn_label.text = txt
	if _vs != null:
		_vs.set_state(int(_taken["w"]), int(_taken["b"]), bool(st["white"]))


# ------------------------------------------------------------------ acciones

func can_act() -> bool:
	return not finished and is_inside_tree() and not get_tree().paused and _anim.is_empty() and (bool(st["white"]) or Kit.versus) \
		and not bool(st["won"]) and not bool(st["lost"]) and not bool(st["draw"])


func _targets(from: int) -> Array:
	var out: Array = []
	for m: Variant in M.legal_moves(st["b"], bool(st["white"]) or not Kit.versus):
		if int(m[0]) == from:
			out.append(int(m[1]))
	return out


func tap_cell(c: Vector2i) -> void:
	if not can_act() or c.x < 0 or c.x > 7 or c.y < 0 or c.y > 7:
		return
	var i: int = c.y * 8 + c.x
	if selected >= 0 and _targets(selected).has(i):
		_do([selected, i])
		return
	var p: String = st["b"][i]
	if p != "" and M.is_white(p) == (bool(st["white"]) or not Kit.versus) and not _targets(i).is_empty():
		selected = i
		_sfx("click")
		return
	selected = -1


func _do(m: Array) -> void:
	var who: String = st["b"][int(m[0])]
	var cap: String = st["b"][int(m[1])]
	if not M.play(st, m):
		return
	if cap != "":
		_taken["w" if M.is_white(who) else "b"] = int(_taken["w" if M.is_white(who) else "b"]) + 1
	_anim = {"from": int(m[0]), "to": int(m[1]), "who": who, "cap": cap, "t": 0.0}
	selected = -1
	_think = THINK
	_sfx("coin" if cap != "" else "click")
	_refresh()


func _sfx(n: String) -> void:
	if not fast:
		Audio.play(n, 0.1, -8.0)


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
		var m: Array = M.bot_move(st)
		if not m.is_empty():
			_do(m)


# ------------------------------------------------------------------ bucle

func _physics_process(delta: float) -> void:
	_t += delta
	var dt: float = delta * (8.0 if fast else 1.0)
	time_in_level += dt
	if not _anim.is_empty():
		_anim["t"] = float(_anim["t"]) + dt * 4.0
		if float(_anim["t"]) >= 1.0:
			_anim = {}
			_refresh()
			_check_end()
	elif not finished and not bool(st["won"]) and not bool(st["lost"]) and not bool(st["draw"]) and not bool(st["white"]) and not Kit.versus:
		_think -= dt
		if _think <= 0.0:
			var m: Array = M.rival_move(st)
			if not m.is_empty():
				_do(m)
	elif not finished:
		_check_end()
	if fast and auto_retry and not finished:
		bot_step()
	_world.queue_redraw()


func _check_end() -> void:
	if Kit.versus and (bool(st["won"]) or bool(st["lost"]) or bool(st["draw"])) and not finished:
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
		tap_cell(Vector2i(floori((p.x - ORIGIN.x) / CELL), floori((p.y - ORIGIN.y) / CELL)))


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	coins = 1
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = 1000 + int(_taken["w"]) * 100 + maxi(0, 120 - int(st["plies"])) * 10
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "plies": int(st["plies"]), "time": snappedf(time_in_level, 0.1), "deaths": deaths})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


## Estrellas: a la primera y en pocas jugadas, 3; a la primera, 2; si no, 1.
func stars_earned() -> int:
	if deaths > 0:
		return 1
	return 3 if int(st["plies"]) <= 60 else 2


func _lose() -> void:
	if finished:
		return
	finished = true
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "draw" if bool(st["draw"]) else "mate", "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var title: String = Kit.text("ch_draw", "\u00a1Tablas!") if bool(st["draw"]) else Kit.text("ch_lost", "\u00a1Jaque mate del rival!")
	var p: FailPanel = FailPanel.open(self, title,
		Kit.text("ch_fail_hint", "Saca caballos y alfiles pronto, no dejes piezas sin defender y busca el mate con la dama y una torre."))
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

func _center(i: int) -> Vector2:
	return ORIGIN + (Vector2(i % 8, i / 8) + Vector2(0.5, 0.5)) * CELL


## Piezas dibujadas con figuras (sin fuentes): base comun y cabeza propia de cada una.
func _piece(c: Vector2, ch: String) -> void:
	var white: bool = M.is_white(ch)
	var fill: Color = Color("#f6efe0") if white else Color("#2b2f3a")
	var line: Color = Color("#6b5a3e") if white else Color("#0d0f14")
	var s: float = CELL / 84.0
	var o: Vector2 = c + Vector2(0, 6) * s
	var shadow: PackedVector2Array = PackedVector2Array()
	for k: int in 16:
		var a: float = TAU * float(k) / 16.0
		shadow.append(o + Vector2(2.0 + cos(a) * 26.0, 30.0 + sin(a) * 6.0) * s)
	_world.draw_colored_polygon(shadow, Color(0, 0, 0, 0.22))
	var base: PackedVector2Array = PackedVector2Array([o + Vector2(-24, 30) * s, o + Vector2(24, 30) * s, o + Vector2(20, 20) * s, o + Vector2(-20, 20) * s])
	var body: PackedVector2Array = PackedVector2Array([o + Vector2(-13, 20) * s, o + Vector2(13, 20) * s, o + Vector2(8, -6) * s, o + Vector2(-8, -6) * s])
	var head: PackedVector2Array = PackedVector2Array()
	match ch.to_lower():
		"p":
			body = PackedVector2Array([o + Vector2(-11, 20) * s, o + Vector2(11, 20) * s, o + Vector2(6, 0) * s, o + Vector2(-6, 0) * s])
		"r":
			body = PackedVector2Array([o + Vector2(-15, 20) * s, o + Vector2(15, 20) * s, o + Vector2(13, -12) * s, o + Vector2(-13, -12) * s])
			head = PackedVector2Array([o + Vector2(-18, -12) * s, o + Vector2(18, -12) * s, o + Vector2(18, -28) * s, o + Vector2(11, -28) * s,
				o + Vector2(11, -21) * s, o + Vector2(4, -21) * s, o + Vector2(4, -28) * s, o + Vector2(-4, -28) * s, o + Vector2(-4, -21) * s,
				o + Vector2(-11, -21) * s, o + Vector2(-11, -28) * s, o + Vector2(-18, -28) * s])
		"n":
			head = PackedVector2Array([o + Vector2(-14, 20) * s, o + Vector2(14, 20) * s, o + Vector2(12, -8) * s, o + Vector2(6, -30) * s,
				o + Vector2(-2, -34) * s, o + Vector2(-6, -28) * s, o + Vector2(-20, -16) * s, o + Vector2(-18, -8) * s, o + Vector2(-6, -12) * s,
				o + Vector2(-12, 4) * s])
		"b":
			head = PackedVector2Array([o + Vector2(-10, -6) * s, o + Vector2(10, -6) * s, o + Vector2(12, -18) * s, o + Vector2(0, -34) * s, o + Vector2(-12, -18) * s])
		"q":
			head = PackedVector2Array([o + Vector2(-14, -6) * s, o + Vector2(14, -6) * s, o + Vector2(20, -30) * s, o + Vector2(9, -16) * s,
				o + Vector2(0, -34) * s, o + Vector2(-9, -16) * s, o + Vector2(-20, -30) * s])
		"k":
			head = PackedVector2Array([o + Vector2(-14, -6) * s, o + Vector2(14, -6) * s, o + Vector2(16, -22) * s, o + Vector2(-16, -22) * s])
	for poly: PackedVector2Array in [base, body, head]:
		if poly.size() < 3:
			continue
		_world.draw_colored_polygon(poly, fill)
		var closed: PackedVector2Array = poly.duplicate()
		closed.append(poly[0])
		_world.draw_polyline(closed, line, 2.5 * s)
	match ch.to_lower():
		"p":
			_world.draw_circle(o + Vector2(0, -8) * s, 10.0 * s, line)
			_world.draw_circle(o + Vector2(0, -8) * s, 8.0 * s, fill)
		"b":
			_world.draw_line(o + Vector2(-3, -24) * s, o + Vector2(4, -16) * s, line, 2.5 * s)
			_world.draw_circle(o + Vector2(0, -37) * s, 3.5 * s, line)
		"q":
			for x: float in [-20.0, 0.0, 20.0]:
				_world.draw_circle(o + Vector2(x, -34 if x == 0.0 else -31) * s, 4.0 * s, line)
		"k":
			_world.draw_line(o + Vector2(0, -22) * s, o + Vector2(0, -40) * s, line, 5.0 * s)
			_world.draw_line(o + Vector2(-7, -33) * s, o + Vector2(7, -33) * s, line, 5.0 * s)
		"n":
			_world.draw_circle(o + Vector2(-4, -22) * s, 2.5 * s, line)


func _draw_world() -> void:
	if st.is_empty():
		return
	var b: Array = st["b"]
	var board: Rect2 = Rect2(ORIGIN, Vector2(8, 8) * CELL)
	_world.draw_rect(board.grow(20.0), Color("#3b2a1c"))
	_world.draw_rect(board.grow(20.0), Color("#a07a4a"), false, 4.0)
	var targets: Array = _targets(selected) if selected >= 0 and can_act() else []
	var last: Array = st["last"]
	var check_sq: int = M.king_sq(b, bool(st["white"])) if M.in_check(b, bool(st["white"])) else -1
	for i: int in 64:
		var x: int = i % 8
		var y: int = i / 8
		var r: Rect2 = Rect2(ORIGIN + Vector2(x, y) * CELL, Vector2(CELL, CELL))
		_world.draw_rect(r, Color("#b58863") if (x + y) % 2 == 1 else Color("#f0d9b5"))
		if last.has(i):
			_world.draw_rect(r, Color(1.0, 0.9, 0.3, 0.35))
		if i == selected:
			_world.draw_rect(r, Color(0.3, 0.8, 1.0, 0.45))
		if i == check_sq:
			_world.draw_circle(r.get_center(), CELL * 0.48, Color(1.0, 0.2, 0.15, 0.55))
		if targets.has(i):
			if b[i] != "":
				_world.draw_arc(r.get_center(), CELL * 0.44, 0.0, TAU, 28, Color(0.2, 0.75, 0.35, 0.85), 6.0)
			else:
				_world.draw_circle(r.get_center(), CELL * 0.15, Color(0.2, 0.75, 0.35, 0.8))
	var moving: int = int(_anim.get("to", -1))
	for j: int in 64:
		if b[j] != "" and j != moving:
			_piece(_center(j), b[j])
	if not _anim.is_empty():
		var f: float = clampf(float(_anim["t"]), 0.0, 1.0)
		if str(_anim["cap"]) != "" and f < 0.8:
			_piece(_center(moving), str(_anim["cap"]))
		_piece(_center(int(_anim["from"])).lerp(_center(moving), f) + Vector2(0, -sin(f * PI) * 18.0), str(b[moving]))
	## Piezas comidas, abajo: cuantas llevas y cuantas te han quitado.
	var font: Font = ThemeDB.fallback_font
	var yb: float = ORIGIN.y + 8.0 * CELL + 70.0
	_world.draw_string(font, Vector2(ORIGIN.x, yb), Kit.text("ch_taken", "Comidas: {a}   Perdidas: {b}").format({"a": int(_taken["w"]), "b": int(_taken["b"])}),
		HORIZONTAL_ALIGNMENT_LEFT, 8.0 * CELL, 30, Color("#e8dcc4"))
