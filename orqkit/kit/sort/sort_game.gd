extends Node2D
## Genero tubos (ordenar colores): pasa los colores de un tubo a otro hasta que cada tubo tenga
## un solo color. Las reglas estan en sort_map.gd (las mismas que el bot y la fabrica).
## 1 - Toca un tubo (se levanta) y luego otro: se vierte todo el bloque de arriba que quepa.
## 2 - Deshacer gratis y reiniciar. Si no queda ningun movimiento util, te avisa.
## 3 - Estrellas: 3 si lo resuelves en el par (la mejor solucion) o menos, 2 hasta 1,5 veces el
##     par, 1 si no.
## Mapa (game.json -> levels[i].map): un texto por tubo de abajo arriba ("." = tubo vacio).
## Parametros: cap, par.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel al acabar.

const MapRules = preload("res://kit/sort/sort_map.gd")
const TUBE_W: float = 74.0
const UNIT_H: float = 46.0
const GAP: float = 30.0
const POUR_TIME: float = 0.22
## Colores de las porciones (bien distintos entre si, tambien para daltonismo con su forma).
const PALETTE: Array[Color] = [Color("#ff5d5d"), Color("#3fa7ff"), Color("#ffd23f"), Color("#4fd17b"), Color("#b36bff"),
	Color("#ff9a3c"), Color("#38e0d2"), Color("#ff7ac8"), Color("#f2f2f2")]

var level: Dictionary = {}
var tubes: Array[String] = []
var cap: int = 4
## Tubos con pocas capas, mas altos (13 nov: una fila de tubos bajitos en media pantalla vacia).
var unit_h: float = UNIT_H
var par: int = 0
var finished: bool = false
var failed: bool = false
var deaths: int = 0
var time_in_level: float = 0.0
var coins: int = 0
var coins_total: int = 0
var moves: int = 0
var fast: bool = false
var auto_retry: bool = false
var selected: int = -1
var stuck: bool = false
var result_panel: ResultPanel

var _start: Array[String] = []
var _history: Array = []
var _busy: float = 0.0
var _pour_from: int = -1
var _pour_to: int = -1
var _board: Node2D
var _camera: Camera2D
var _count_label: Label
var _moves_label: Label
var _stuck_label: Label
var _hint_btn: Button
var _undo_btn: Button


func _ready() -> void:
	level = Kit.current_level()
	_start = MapRules.parse(level)
	cap = MapRules.cap_of(level)
	unit_h = 66.0 if cap <= 4 else (56.0 if cap == 5 else UNIT_H)
	par = int(level.get("par", 0))
	RenderingServer.set_default_clear_color(Kit.color("sky", Color("#1b2a41")))
	_board = Node2D.new()
	_board.name = "Board"
	_board.draw.connect(_draw_board)
	add_child(_board)
	_camera = Camera2D.new()
	add_child(_camera)
	_camera.make_current()
	Juice.register_camera(_camera)
	_build_hud()
	_reset()
	_fit_camera()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "sort", "tubes": tubes.size(), "par": par})


func bot_script() -> String:
	return "res://qa/sort_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(0.6, 0.4)


## Tubos en una fila (hasta 6) o en dos.
func _per_row() -> int:
	return tubes.size() if tubes.size() <= 6 else int(ceil(float(tubes.size()) / 2.0))


func tube_rect(i: int) -> Rect2:
	var per: int = _per_row()
	var row: int = i / per
	var col: int = i % per
	var in_row: int = mini(per, tubes.size() - row * per)
	var row_w: float = float(in_row) * TUBE_W + float(in_row - 1) * GAP
	var full_w: float = float(per) * TUBE_W + float(per - 1) * GAP
	var h: float = float(cap) * unit_h + 24.0
	var x: float = (full_w - row_w) * 0.5 + float(col) * (TUBE_W + GAP)
	var y: float = float(row) * (h + 90.0)
	return Rect2(Vector2(x, y), Vector2(TUBE_W, h))


func _fit_camera() -> void:
	var per: int = _per_row()
	var rows_n: int = 1 if tubes.size() <= 6 else 2
	var w: float = float(per) * TUBE_W + float(per - 1) * GAP
	var h: float = float(rows_n) * (float(cap) * unit_h + 24.0) + float(rows_n - 1) * 90.0
	var vp: Vector2 = get_viewport_rect().size
	var z: float = minf(vp.x * 0.9 / (w + 40.0), vp.y * 0.6 / (h + 120.0))
	_camera.zoom = Vector2.ONE * clampf(z, 0.4, 1.6)
	_camera.position = Vector2(w * 0.5, h * 0.5 + 20.0)


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
	var safe: MarginContainer = UI.safe_root(root, 20.0)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col: VBoxContainer = VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(col)
	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 14)
	col.add_child(top)
	top.add_child(UiIcon.make("star", Kit.color("coin", UI.colors["acento"]), 40.0))
	_count_label = Label.new()
	_count_label.name = "Count"
	top.add_child(_count_label)
	_moves_label = Label.new()
	_moves_label.name = "Moves"
	_moves_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_moves_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_moves_label.add_theme_color_override("font_color", UI.colors["texto_suave"])
	top.add_child(_moves_label)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)
	var grow: Control = Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(grow)
	_stuck_label = Label.new()
	_stuck_label.name = "Stuck"
	_stuck_label.text = Kit.text("sort_stuck", "No quedan movimientos: deshaz o reinicia")
	_stuck_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stuck_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stuck_label.add_theme_color_override("font_color", Kit.color("danger", Color("#ff6b5b")))
	_stuck_label.visible = false
	col.add_child(_stuck_label)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	col.add_child(row)
	_undo_btn = UI.make_button(Kit.text("sokoban_undo", "Deshacer"), false, "back")
	_undo_btn.name = "BtnUndo"
	_undo_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_undo_btn.pressed.connect(undo)
	row.add_child(_undo_btn)
	var restart: Button = UI.make_button(Kit.text("restart", "Reiniciar"), false, "retry")
	restart.name = "BtnRestart"
	restart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	restart.pressed.connect(retry)
	row.add_child(restart)
	_hint_btn = Hint.make_button(self, use_hint)
	row.add_child(_hint_btn)
	var hint: Label = Label.new()
	hint.name = "Hint"
	hint.text = Kit.text("sort_tap_hint", "Toca un tubo y luego otro para pasar el color")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", UI.colors["texto_suave"])
	col.add_child(hint)


func _reset() -> void:
	Hint.reset(self)
	finished = false
	failed = false
	tubes = _start.duplicate()
	moves = 0
	selected = -1
	stuck = false
	_history.clear()
	_busy = 0.0
	var colors: Dictionary = {}
	for t: String in tubes:
		for ch: String in t:
			colors[ch] = true
	coins_total = colors.size()
	_refresh()


func _refresh() -> void:
	coins = 0
	for t: String in tubes:
		if t.length() == cap and MapRules.top_run(t) == cap:
			coins += 1
	_count_label.text = "%d/%d" % [coins, coins_total]
	_moves_label.text = Kit.text("sort_moves", "Movimientos") + ": %d" % moves + (" / %d" % par if par > 0 else "")
	_stuck_label.visible = stuck and not finished
	_undo_btn.disabled = _history.is_empty()
	if _hint_btn != null:
		_hint_btn.text = Hint.label(self)
		_hint_btn.disabled = finished
	_board.queue_redraw()


# ------------------------------------------------------------------ reglas

func can_move() -> bool:
	return not finished and _busy <= 0.0 and not get_tree().paused


## Vierte de a en b (lo usan el toque y el bot). Devuelve false si no se puede.
func pour(a: int, b: int) -> bool:
	if not can_move() or not MapRules.can_pour(tubes, a, b, cap):
		return false
	_history.append(tubes.duplicate())
	if _history.size() > 300:
		_history.pop_front()
	tubes = MapRules.pour(tubes, a, b, cap)
	moves += 1
	selected = -1
	_pour_from = a
	_pour_to = b
	_busy = POUR_TIME * (0.15 if fast else 1.0)
	Audio.play("click", 0.1, -6.0)
	if MapRules.solved(tubes, cap):
		_refresh()
		_finish()
		return true
	var full_before: int = coins
	stuck = not MapRules.has_moves(tubes, cap)
	_refresh()
	if coins > full_before and not fast:
		Audio.play("coin", 0.05, -4.0)
		Juice.vibrate(15)
	return true


## Toque en un tubo: elegir, cambiar de eleccion o verter.
func tap(i: int) -> void:
	if not can_move() or i < 0 or i >= tubes.size():
		return
	if selected < 0:
		if not tubes[i].is_empty():
			selected = i
			Audio.play("click", 0.1, -10.0)
	elif selected == i:
		selected = -1
	elif not pour(selected, i):
		selected = i if not tubes[i].is_empty() else -1
		if not fast:
			Juice.shake(0.08)
	_board.queue_redraw()


## Pista: el siguiente trasvase de la mejor solucion desde como estan ahora los tubos.
func use_hint() -> void:
	if not can_move():
		return
	var plan: Array = MapRules.solve(tubes, cap)
	if plan.is_empty():
		Hint.say(self, Kit.text("hint_none", "Desde aqu\u00ed no hay salida: deshaz o reinicia"))
		return
	if not await Hint.pay(self):
		Hint.say(self, Kit.text("hint_no_coins", "Te faltan monedas para la pista"))
		return
	if is_inside_tree() and not finished:
		var mv: Array = plan[0]
		selected = -1
		pour(int(mv[0]), int(mv[1]))
	_refresh()


func undo() -> void:
	if finished or _history.is_empty() or _busy > 0.0:
		return
	tubes = _history.pop_back()
	moves = maxi(moves - 1, 0)
	selected = -1
	stuck = false
	_refresh()


func tube_at(world: Vector2) -> int:
	for i: int in tubes.size():
		if tube_rect(i).grow(18.0).has_point(world):
			return i
	return -1


func _physics_process(delta: float) -> void:
	if not finished:
		time_in_level += delta
	if _busy > 0.0:
		_busy -= delta
		_board.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()
		return
	var pressed: bool = false
	var pos: Vector2 = Vector2.ZERO
	if event is InputEventScreenTouch:
		pressed = (event as InputEventScreenTouch).pressed
		pos = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		pressed = (event as InputEventMouseButton).pressed
		pos = (event as InputEventMouseButton).position
	else:
		return
	if not pressed:
		return
	var world: Vector2 = get_canvas_transform().affine_inverse() * pos
	tap(tube_at(world))


# ------------------------------------------------------------------ final

func _finish() -> void:
	finished = true
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = coins_total * 100 + maxi(0, 2000 - moves * 25)
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "coins": coins, "moves": moves, "par": par, "deaths": deaths, "stars": stars})
	Audio.play("win")
	Audio.play_track("victoria", false)
	Juice.burst(self, _camera.position, Kit.color("coin", Color.YELLOW), 24, 360.0)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": maxi(score, 0), "record": record})
	await Ads.show_interstitial("level_end")


func stars_earned() -> int:
	if par <= 0 or moves <= par:
		return 3
	return 2 if float(moves) <= float(par) * 1.5 else 1


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
	return {"pos": Vector2(float(moves), float(coins)), "deaths": deaths, "coins": coins, "finished": finished, "failed": failed,
		"stomps": 0, "moves": moves, "par": par, "stuck": stuck}


# ------------------------------------------------------------------ dibujo

func _color_of(ch: String) -> Color:
	var i: int = MapRules.COLORS.find(ch)
	return PALETTE[i % PALETTE.size()] if i >= 0 else Color.GRAY


func _draw_board() -> void:
	var glass: Color = Color(1, 1, 1, 0.1)
	var rim: Color = Color(1, 1, 1, 0.55)
	var accent: Color = Kit.color("accent", Color("#e8b04b"))
	for i: int in tubes.size():
		var r: Rect2 = tube_rect(i)
		var lift: float = -26.0 if i == selected else 0.0
		r.position.y += lift
		var full: bool = tubes[i].length() == cap and MapRules.top_run(tubes[i]) == cap
		_board.draw_rect(r, glass)
		## Porciones de color de abajo arriba, con un brillo a la izquierda y una forma por color
		## (puntos) para distinguirlas sin depender solo del color.
		for k: int in tubes[i].length():
			var ch: String = tubes[i][k]
			var c: Color = _color_of(ch)
			var seg: Rect2 = Rect2(Vector2(r.position.x + 6.0, r.end.y - 8.0 - float(k + 1) * unit_h), Vector2(TUBE_W - 12.0, unit_h - 2.0))
			_board.draw_rect(seg, c)
			_board.draw_rect(Rect2(seg.position + Vector2(4.0, 4.0), Vector2(8.0, seg.size.y - 8.0)), c.lightened(0.35))
			var dots: int = MapRules.COLORS.find(ch) % 3 + 1
			for d: int in dots:
				_board.draw_circle(seg.get_center() + Vector2(float(d) * 12.0 - float(dots + 1) * 6.0, 0.0), 3.5, c.darkened(0.45))
		_board.draw_rect(r, accent if (i == selected or full) else rim, false, 4.0)
		## Boca del tubo.
		_board.draw_line(r.position + Vector2(-6.0, 0.0), r.position + Vector2(TUBE_W + 6.0, 0.0), accent if i == selected else rim, 5.0)
	## Chorro mientras se vierte.
	if _busy > 0.0 and _pour_from >= 0 and _pour_to >= 0 and _pour_to < tubes.size():
		var a: Rect2 = tube_rect(_pour_from)
		var b: Rect2 = tube_rect(_pour_to)
		var t: String = tubes[_pour_to]
		var c2: Color = _color_of(t[t.length() - 1]) if not t.is_empty() else Color.WHITE
		_board.draw_line(Vector2(a.get_center().x, a.position.y - 20.0), Vector2(b.get_center().x, b.position.y + 4.0), Color(c2, 0.85), 10.0)
