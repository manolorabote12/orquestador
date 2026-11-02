extends Node2D
## Puzle de cajas (sokoban): empujas cada caja hasta un hueco. Solo se empuja, nunca se tira.
## 1 - Vista desde arriba en una cuadricula. Desliza el dedo (o flechas) para moverte una casilla;
##     si hay una caja delante y detras esta libre, la empujas.
## 2 - Ganas cuando todas las cajas estan en un hueco. Deshacer y reiniciar sin castigo.
## 3 - Si una caja queda donde ya no puede llegar a ningun hueco, te avisa (deshaz o reinicia).
## 4 - Estrellas por empujes frente a la mejor solucion (game.json -> levels[i].par).
## 5 - Giro hielo (level.ice): la caja empujada resbala hasta chocar con un muro u otra caja.
## Mapa: "#" muro, "." suelo, "P" heroe, "B" caja, "O" hueco, "Q" caja en hueco, "R" heroe en hueco.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel al acabar.

const MapRules = preload("res://kit/sokoban/sokoban_map.gd")
const CELL: float = 96.0
const STEP_TIME: float = 0.13

var rows: Array[String] = []
var finished: bool = false
var failed: bool = false
var deaths: int = 0
var time_in_level: float = 0.0
var coins: int = 0
var coins_total: int = 0
var moves: int = 0
var pushes: int = 0
var par: int = 0
var fast: bool = false
var auto_retry: bool = false
var stuck: bool = false
var ice: bool = false
var result_panel: ResultPanel
var cell: Vector2i = Vector2i.ZERO
var walls: Dictionary = {}
var goals: Dictionary = {}
## caja (Vector2i) -> nodo que la dibuja
var boxes: Dictionary = {}

var _start_cell: Vector2i = Vector2i.ZERO
var _start_boxes: Array[Vector2i] = []
var _history: Array = []
var _board: Node2D
var _player: Node2D
var _camera: Camera2D
var _count_label: Label
var _push_label: Label
var _stuck_label: Label
var _undo_btn: Button
var _hint_btn: Button
## Pasos que faltan de la pista (caminar hasta la caja y empujarla).
var _hint_steps: Array[Vector2i] = []
var _moving: float = 0.0
var _swipe_from: Vector2 = Vector2.ZERO
var _swiping: bool = false


func _ready() -> void:
	for r: Variant in Kit.current_level().get("map", []):
		rows.append(str(r))
	par = int(Kit.current_level().get("par", 0))
	ice = bool(Kit.current_level().get("ice", false))
	RenderingServer.set_default_clear_color(Kit.color("sky", Color("#1b2a41")))
	var m: Dictionary = MapRules.parse(rows)
	walls = m["walls"]
	goals = m["goals"]
	_start_cell = m["player"]
	for b: Vector2i in m["boxes"]:
		_start_boxes.append(b)
	coins_total = _start_boxes.size()
	_board = Node2D.new()
	_board.name = "Board"
	_board.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_board.draw.connect(_draw_board)
	add_child(_board)
	_build_player()
	_camera = Camera2D.new()
	add_child(_camera)
	_camera.make_current()
	Juice.register_camera(_camera)
	_fit_camera()
	_build_hud()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "sokoban", "boxes": coins_total, "par": par})


func bot_script() -> String:
	return "res://qa/sokoban_bot.gd"


func _fit_camera() -> void:
	var w: float = float(rows[0].length() if not rows.is_empty() else 1) * CELL
	var h: float = float(rows.size()) * CELL
	var vp: Vector2 = get_viewport_rect().size
	var z: float = minf(vp.x / (w + CELL * 0.5), vp.y * 0.72 / (h + CELL))
	_camera.zoom = Vector2.ONE * minf(z, 1.3)
	_camera.position = Vector2(w, h) * 0.5 + Vector2(0.0, CELL * 0.2)


func _build_player() -> void:
	_player = Node2D.new()
	_player.name = "Player"
	_player.z_index = 6
	add_child(_player)
	var art: Dictionary = Kit.sprite_by_role("jugador")
	if not art.is_empty():
		var spr: AnimatedSprite2D = SpriteKit.animado(art, CELL * 0.9, "idle", false)
		_player.add_child(spr)
		Skins.apply(spr)
	else:
		var body: Polygon2D = Polygon2D.new()
		body.color = Kit.color("accent", Color.ORANGE)
		body.polygon = LevelBuilder._circle(CELL * 0.34, 20)
		_player.add_child(body)


func _make_box() -> Node2D:
	var n: Node2D = Node2D.new()
	n.z_index = 4
	var wood: Color = Kit.color("accent", Color("#c98a3c")).lerp(Color("#a0662c"), 0.45)
	var half: float = CELL * 0.42
	var body: Polygon2D = Polygon2D.new()
	body.name = "Body"
	body.color = wood
	body.polygon = PackedVector2Array([Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)])
	n.add_child(body)
	var edge: Line2D = Line2D.new()
	edge.name = "Edge"
	edge.width = 6.0
	edge.default_color = wood.darkened(0.45)
	edge.closed = true
	edge.points = body.polygon
	n.add_child(edge)
	for k: int in 2:
		var bar: Line2D = Line2D.new()
		bar.width = 7.0
		bar.default_color = wood.darkened(0.3)
		bar.points = PackedVector2Array([Vector2(-half * 0.8, -half * 0.8), Vector2(half * 0.8, half * 0.8)]) if k == 0 \
			else PackedVector2Array([Vector2(half * 0.8, -half * 0.8), Vector2(-half * 0.8, half * 0.8)])
		n.add_child(bar)
	add_child(n)
	return n


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
	_count_label.name = "Coins"
	top.add_child(_count_label)
	_push_label = Label.new()
	_push_label.name = "Pushes"
	_push_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_push_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_push_label.add_theme_color_override("font_color", UI.colors["texto_suave"])
	top.add_child(_push_label)
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
	_stuck_label.text = Kit.text("sokoban_stuck", "Esa caja ya no sale de ah\u00ed: deshaz o reinicia")
	_stuck_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stuck_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stuck_label.add_theme_color_override("font_color", UI.colors["peligro"])
	_stuck_label.visible = false
	col.add_child(_stuck_label)
	var bottom: HBoxContainer = HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 16)
	col.add_child(bottom)
	_undo_btn = UI.make_button(Kit.text("sokoban_undo", "Deshacer"), false, "back")
	_undo_btn.name = "BtnUndo"
	_undo_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_undo_btn.pressed.connect(undo)
	bottom.add_child(_undo_btn)
	var restart: Button = UI.make_button(Kit.text("sokoban_restart", "Reiniciar"), false, "retry")
	restart.name = "BtnRestart"
	restart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	restart.pressed.connect(retry)
	bottom.add_child(restart)
	_hint_btn = Hint.make_button(self, use_hint)
	bottom.add_child(_hint_btn)
	var hint: Label = Label.new()
	hint.name = "Hint"
	hint.text = Kit.text("sokoban_ice_hint", "\u00a1Hielo! Las cajas resbalan hasta chocar") if ice else Kit.text("swipe_hint", "Desliza para empujar las cajas")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", UI.colors["texto_suave"])
	col.add_child(hint)


func _reset() -> void:
	Hint.reset(self)
	_hint_steps.clear()
	finished = false
	failed = false
	moves = 0
	pushes = 0
	_history.clear()
	for b: Vector2i in boxes:
		(boxes[b] as Node2D).queue_free()
	boxes.clear()
	for b: Vector2i in _start_boxes:
		var n: Node2D = _make_box()
		n.position = _center(b)
		boxes[b] = n
	cell = _start_cell
	_player.position = _center(cell)
	_moving = 0.0
	_refresh()


func _center(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * CELL


func _refresh() -> void:
	coins = 0
	for b: Vector2i in boxes:
		var on: bool = goals.has(b)
		if on:
			coins += 1
		var body: Polygon2D = (boxes[b] as Node2D).get_node("Body") as Polygon2D
		var wood: Color = Kit.color("accent", Color("#c98a3c")).lerp(Color("#a0662c"), 0.45)
		body.color = Kit.color("coin", Color("#e8b04b")) if on else wood
	_count_label.text = "%d/%d" % [coins, coins_total]
	_push_label.text = Kit.text("sokoban_pushes", "Empujes") + ": %d" % pushes + (" / %d" % par if par > 0 else "")
	stuck = MapRules.dead_box(walls, goals, boxes, ice)
	_stuck_label.visible = stuck and not finished
	_undo_btn.disabled = _history.is_empty()
	if _hint_btn != null:
		_hint_btn.text = Hint.label(self)
		_hint_btn.disabled = finished
	_board.queue_redraw()


# ------------------------------------------------------------------ reglas

func can_move() -> bool:
	return not finished and _moving <= 0.0 and not get_tree().paused


func free_cell(c: Vector2i) -> bool:
	return not walls.has(c) and not boxes.has(c) and c.y >= 0 and c.y < rows.size() and c.x >= 0 and c.x < rows[c.y].length()


## Mueve una casilla (empujando la caja si la hay). Devuelve false si no se puede.
func try_move(dir: Vector2i) -> bool:
	if not can_move():
		return false
	var target: Vector2i = cell + dir
	if walls.has(target):
		return false
	var t: float = STEP_TIME * (0.2 if fast else 1.0)
	var pushed: bool = false
	if boxes.has(target):
		var beyond: Vector2i = target + dir
		if not free_cell(beyond):
			return false
		_history.append([cell, boxes.keys()])
		var node: Node2D = boxes[target]
		boxes.erase(target)
		beyond = MapRules.slide_end(walls, boxes, target, dir, ice)
		boxes[beyond] = node
		var tb: Tween = create_tween()
		tb.tween_property(node, "position", _center(beyond), t * float(maxi(1, absi(beyond.x - target.x) + absi(beyond.y - target.y))))
		pushes += 1
		pushed = true
		Audio.play("stomp" if not goals.has(beyond) else "coin", 0.1, -8.0)
	else:
		_history.append([cell, boxes.keys()])
	if _history.size() > 400:
		_history.pop_front()
	cell = target
	moves += 1
	_moving = t
	var tw: Tween = create_tween()
	tw.tween_property(_player, "position", _center(cell), t)
	_refresh()
	if pushed and coins >= coins_total:
		_finish()
	return true


## Vuelve un paso atras (gratis).
## El tablero de ahora como filas del mapa (para el resolvedor).
func current_rows() -> Array[String]:
	var out: Array[String] = []
	for y: int in rows.size():
		var line: String = ""
		for x: int in rows[y].length():
			var c: Vector2i = Vector2i(x, y)
			var ch: String = rows[y][x]
			if walls.has(c):
				line += "#"
			elif boxes.has(c):
				line += "Q" if goals.has(c) else "B"
			elif c == cell:
				line += "R" if goals.has(c) else "P"
			elif goals.has(c):
				line += "O"
			elif ch in ["B", "Q", "P", "R", "O"]:
				line += "."
			else:
				line += ch
		out.append(line)
	return out


## Pista: camina hasta la caja buena y la empuja (siguiente empuje de la mejor solucion).
func use_hint() -> void:
	if not can_move() or not _hint_steps.is_empty():
		return
	var plan: Array = MapRules.solve(current_rows(), ice)
	if plan.is_empty():
		Hint.say(self, Kit.text("hint_none", "Desde aqu\u00ed no hay salida: deshaz o reinicia"))
		return
	var b: Vector2i = plan[0][0]
	var d: Vector2i = plan[0][1]
	var path: Array[Vector2i] = MapRules.walk(walls, boxes, cell, b - d)
	if path.is_empty() and cell != b - d:
		Hint.say(self, Kit.text("hint_none", "Desde aqu\u00ed no hay salida: deshaz o reinicia"))
		return
	if not await Hint.pay(self):
		Hint.say(self, Kit.text("hint_no_coins", "Te faltan monedas para la pista"))
		return
	if is_inside_tree() and not finished:
		_hint_steps = path.duplicate()
		_hint_steps.append(d)
	_refresh()


func undo() -> void:
	if finished or _history.is_empty() or _moving > 0.0:
		return
	var last: Array = _history.pop_back()
	var olds: Array = last[1]
	var nodes: Array = boxes.values()
	var keys: Array = boxes.keys()
	## Las cajas que no se han movido conservan su nodo; la que se movio vuelve a su sitio.
	var fresh: Dictionary = {}
	var spare: Array[Node2D] = []
	for i: int in keys.size():
		if olds.has(keys[i]):
			fresh[keys[i]] = nodes[i]
		else:
			spare.append(nodes[i])
	for o: Variant in olds:
		var c: Vector2i = o
		if not fresh.has(c):
			var n: Node2D = spare.pop_back()
			n.position = _center(c)
			fresh[c] = n
			pushes = maxi(pushes - 1, 0)
	boxes = fresh
	cell = last[0]
	_player.position = _center(cell)
	moves = maxi(moves - 1, 0)
	_refresh()


func _physics_process(delta: float) -> void:
	if finished:
		return
	time_in_level += delta
	_moving -= delta
	if not _hint_steps.is_empty() and can_move():
		if not try_move(_hint_steps.pop_front()):
			_hint_steps.clear()
	if UI.test_mode:
		return
	if Input.is_action_pressed("move_left"):
		try_move(Vector2i.LEFT)
	elif Input.is_action_pressed("move_right"):
		try_move(Vector2i.RIGHT)
	elif Input.is_action_pressed("move_up"):
		try_move(Vector2i.UP)
	elif Input.is_action_pressed("move_down"):
		try_move(Vector2i.DOWN)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		var pressed: bool = event.pressed
		var pos: Vector2 = event.position
		if pressed:
			_swipe_from = pos
			_swiping = true
		elif _swiping:
			_swiping = false
			var v: Vector2 = pos - _swipe_from
			if v.length() < 36.0:
				return
			if absf(v.x) > absf(v.y):
				try_move(Vector2i.RIGHT if v.x > 0.0 else Vector2i.LEFT)
			else:
				try_move(Vector2i.DOWN if v.y > 0.0 else Vector2i.UP)


# ------------------------------------------------------------------ final

func _finish() -> void:
	finished = true
	_stuck_label.visible = false
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = coins_total * 1000 + maxi(0, 2000 - pushes * 40 - moves * 5)
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "pushes": pushes, "par": par, "moves": moves, "stars": stars})
	Audio.play("win")
	Audio.play_track("victoria", false)
	for b: Vector2i in boxes:
		Juice.burst(self, _center(b), Kit.color("coin", Color.YELLOW), 10, 220.0)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


## 3 estrellas con los empujes de la mejor solucion (o casi); 2 si te pasas un poco; 1 si no.
func stars_earned() -> int:
	if par <= 0 or pushes <= par + 1:
		return 3
	if pushes <= int(float(par) * 1.5) + 3:
		return 2
	return 1


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
	return {"pos": Vector2(cell), "deaths": deaths, "coins": coins, "finished": finished, "failed": failed, "stomps": 0,
		"pushes": pushes, "par": par, "stuck": stuck}


# ------------------------------------------------------------------ dibujo

func _draw_board() -> void:
	var sky: Color = Kit.color("sky", Color("#1b2a41"))
	var floor_a: Color = sky.lightened(0.12)
	var floor_b: Color = sky.lightened(0.17)
	var wall: Color = Kit.color("solid", Color("#3e5c84"))
	var goal: Color = Kit.color("coin", Color("#e8b04b"))
	var reach: Dictionary = MapRules.zone(walls, {}, _start_cell)
	for y: int in rows.size():
		for x: int in rows[y].length():
			var c: Vector2i = Vector2i(x, y)
			var r: Rect2 = Rect2(Vector2(x, y) * CELL, Vector2(CELL, CELL))
			if walls.has(c):
				## Solo los muros que tocan el almacen; el resto es oscuridad.
				var near: bool = false
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
					if reach.has(c + d):
						near = true
				if near:
					var tex: Texture2D = Kit.first_tile_texture()
					if tex != null:
						_board.draw_texture_rect(tex, r.grow(-2.0), false, Color.WHITE)
					else:
						_board.draw_rect(r.grow(-2.0), wall)
					_board.draw_rect(Rect2(r.position + Vector2(2.0, 2.0), Vector2(CELL - 4.0, 12.0)), Color(wall.lightened(0.35), 0.7))
					_board.draw_rect(Rect2(r.position + Vector2(2.0, CELL - 14.0), Vector2(CELL - 4.0, 12.0)), Color(wall.darkened(0.45), 0.7))
				continue
			if not reach.has(c):
				continue
			_board.draw_rect(r, floor_a if (x + y) % 2 == 0 else floor_b)
			if ice:
				## Hielo: azul claro con un brillo en diagonal.
				_board.draw_rect(r, Color(0.62, 0.85, 1.0, 0.36 if (x + y) % 2 == 0 else 0.3))
				_board.draw_line(r.position + Vector2(CELL * 0.22, CELL * 0.62), r.position + Vector2(CELL * 0.62, CELL * 0.22), Color(1, 1, 1, 0.35), 4.0)
			if goals.has(c):
				var center: Vector2 = r.get_center()
				_board.draw_arc(center, CELL * 0.3, 0.0, TAU, 28, goal, 6.0)
				_board.draw_circle(center, CELL * 0.08, goal)
