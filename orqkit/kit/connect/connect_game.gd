extends Node2D
## Conecta 4 contra la maquina: toca una columna para soltar tu ficha roja. Haz 4 en raya.
## Reglas, IA rival, bot y analizador en connect_map.gd.
## 1 - El rival piensa un momento antes de jugar (mas o menos listo segun el nivel).
## 2 - Empate o derrota: se repite el nivel. Ganar rapido da mas estrellas.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const MapRules = preload("res://kit/connect/connect_map.gd")
const CELL: float = 92.0
const ORIGIN: Vector2 = Vector2(360.0 - 3.5 * CELL, 380.0)
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
var par: float = 0.0

var _font: Font
var _world: Node2D
var _camera: Camera2D
var _turn_label: Label
var _hint_btn: Button
var _vs: VersusBar
var _fall: Dictionary = {}
var _think: float = 0.0
var _hover: int = -1
var _t: float = 0.0


func _ready() -> void:
	level = Kit.current_level()
	par = float(level.get("par", 21))
	RenderingServer.set_default_clear_color(Color("#203050"))
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
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "connect", "depth": int(st["depth"])})


func bot_script() -> String:
	return "res://qa/connect_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(4.0, 1.2)


func _reset() -> void:
	Hint.reset(self)
	finished = false
	failed = false
	st = MapRules.new_state(level)
	coins = 0
	time_in_level = 0.0
	_fall = {}
	_think = THINK
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
	_vs = VersusBar.make(false)
	col.add_child(_vs)


func _refresh() -> void:
	if _hint_btn != null:
		_hint_btn.text = Hint.label(self)
	if _turn_label == null or st.is_empty():
		return
	_turn_label.text = Kit.text("c4_you", "Tu turno") if str(st["turn"]) == "R" else Kit.text("c4_ai", "Piensa el rival...")
	if Kit.versus:
		_turn_label.text = Versus.turn_text(1 if str(st["turn"]) == "R" else 2)
	if _vs != null:
		_vs.set_state(0, 0, str(st["turn"]) == "R")


# ------------------------------------------------------------------ acciones

func can_act() -> bool:
	return not finished and is_inside_tree() and not get_tree().paused and _fall.is_empty() and (str(st["turn"]) == "R" or Kit.versus) and str(st["winner"]) == ""


func drop(x: int) -> void:
	if not can_act():
		return
	_play(x)


func _play(x: int) -> void:
	var y: int = MapRules.drop_row(st["g"], x)
	if y < 0:
		return
	var who: String = str(st["turn"])
	MapRules.play(st, x)
	_fall = {"x": x, "y": y, "who": who, "t": 0.0}
	_think = THINK
	_sfx("click")
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
		drop(MapRules.bot_move(st))


# ------------------------------------------------------------------ bucle

func _physics_process(delta: float) -> void:
	_t += delta
	var dt: float = delta * (6.0 if fast else 1.0)
	time_in_level += dt
	if not _fall.is_empty():
		_fall["t"] = float(_fall["t"]) + dt * 3.2
		if float(_fall["t"]) >= 1.0:
			_fall = {}
			_sfx("jump")
			_check_end()
	elif not finished and str(st["winner"]) == "" and str(st["turn"]) == "Y" and not Kit.versus:
		_think -= dt
		if _think <= 0.0:
			_play(MapRules.ai_move(st))
	if fast and auto_retry and not finished:
		bot_step()
	_world.queue_redraw()


func _check_end() -> void:
	var w: String = str(st["winner"])
	if Kit.versus and w != "" and not finished:
		finished = true
		Versus.finish(self, {"R": 1, "Y": 2}.get(w, 0))
		return
	if w == "R":
		_finish()
	elif w == "Y" or w == "draw":
		_lose()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()
		return
	var inv: Transform2D = get_canvas_transform().affine_inverse()
	if event is InputEventScreenTouch:
		var te: InputEventScreenTouch = event
		var p: Vector2 = inv * te.position
		var x: int = floori((p.x - ORIGIN.x) / CELL)
		if te.pressed:
			_hover = x
		else:
			if x == _hover and x >= 0 and x < MapRules.W:
				drop(x)
			_hover = -1
	elif event is InputEventScreenDrag and _hover >= 0:
		_hover = floori(((inv * (event as InputEventScreenDrag).position).x - ORIGIN.x) / CELL)


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	coins = 1
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = 1000 + maxi(0, 42 - int(st["moves"])) * 40
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
	return 3 if int(st["moves"]) <= int(par) + 4 else 2


func _lose() -> void:
	if finished:
		return
	finished = true
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": str(st["winner"]), "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var title: String = Kit.text("c4_draw", "\u00a1Empate!") if str(st["winner"]) == "draw" else Kit.text("c4_lost", "\u00a1Gan\u00f3 el rival!")
	var p: FailPanel = FailPanel.open(self, title,
		Kit.text("c4_fail_hint", "Juega por el centro y mira siempre si el rival tiene tres en raya antes de mover."))
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
	return {"pos": Vector2(float(st.get("moves", 0)), 0.0), "deaths": deaths, "coins": coins, "finished": finished, "failed": failed,
		"stomps": 0, "time": time_in_level, "winner": str(st.get("winner", ""))}


# ------------------------------------------------------------------ dibujo

func _piece(c: Vector2, who: String, glow: bool) -> void:
	var col: Color = Color("#e8343a") if who == "R" else Color("#f2c84b")
	_world.draw_circle(c, CELL * 0.4, col.darkened(0.25))
	_world.draw_circle(c, CELL * 0.34, col)
	_world.draw_arc(c, CELL * 0.24, 0.0, TAU, 24, col.lightened(0.25), 3.0)
	if glow:
		_world.draw_arc(c, CELL * 0.44, 0.0, TAU, 24, Color(1, 1, 1, 0.6 + 0.4 * sin(_t * 8.0)), 5.0)


func _draw_world() -> void:
	if st.is_empty():
		return
	var g: Array = st["g"]
	var board: Rect2 = Rect2(ORIGIN, Vector2(MapRules.W, MapRules.H) * CELL)
	## Columna elegida y ficha que espera arriba.
	if _hover >= 0 and _hover < MapRules.W and can_act():
		_world.draw_rect(Rect2(ORIGIN + Vector2(float(_hover) * CELL, 0), Vector2(CELL, board.size.y)), Color(1, 1, 1, 0.12))
		_piece(ORIGIN + Vector2((float(_hover) + 0.5) * CELL, -CELL * 0.6), "R", false)
	## Fichas puestas (detras del tablero) y la que cae.
	var line: Array = st["line"]
	for y: int in MapRules.H:
		for x: int in MapRules.W:
			var ch: String = str(g[y][x])
			if (ch == "R" or ch == "Y") and not (not _fall.is_empty() and int(_fall["x"]) == x and int(_fall["y"]) == y):
				_piece(ORIGIN + (Vector2(x, y) + Vector2(0.5, 0.5)) * CELL, ch, line.has(Vector2i(x, y)) and _fall.is_empty())
	if not _fall.is_empty():
		var f: float = clampf(float(_fall["t"]), 0.0, 1.0)
		var to: Vector2 = ORIGIN + (Vector2(float(_fall["x"]), float(_fall["y"])) + Vector2(0.5, 0.5)) * CELL
		var from: Vector2 = Vector2(to.x, ORIGIN.y - CELL * 0.6)
		_piece(from.lerp(to, f * f), str(_fall["who"]), false)
	## Tablero azul con agujeros: cada casilla son 4 esquinas que rodean el agujero redondo.
	_world.draw_rect(board.grow(14.0), Color("#1a4ad0"), false, 28.0)
	for y2: int in MapRules.H:
		for x2: int in MapRules.W:
			var c: Vector2 = ORIGIN + (Vector2(x2, y2) + Vector2(0.5, 0.5)) * CELL
			_cell_frame(c)
			if str(g[y2][x2]) == "#":
				_world.draw_circle(c, CELL * 0.41, Color("#1a3aa8"))
	_world.draw_rect(Rect2(board.position + Vector2(-30, board.size.y + 14), Vector2(board.size.x + 60, 40)), Color("#143aa8"))


func _cell_frame(c: Vector2) -> void:
	var h: float = CELL * 0.5
	var r: float = CELL * 0.41
	for q: int in 4:
		var a0: float = float(q) * PI * 0.5
		var pts: PackedVector2Array = PackedVector2Array()
		var corner: Vector2 = Vector2(cos(a0 + PI * 0.25), sin(a0 + PI * 0.25)) * h * sqrt(2.0)
		pts.append(c + Vector2(cos(a0), sin(a0)) * h)
		pts.append(c + corner)
		pts.append(c + Vector2(cos(a0 + PI * 0.5), sin(a0 + PI * 0.5)) * h)
		for k: int in range(6, -1, -1):
			var a: float = a0 + PI * 0.5 * float(k) / 6.0
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		_world.draw_colored_polygon(pts, Color("#2a5ae8"))
	_world.draw_arc(c, r, 0.0, TAU, 28, Color("#1a3aa8"), 3.0)
