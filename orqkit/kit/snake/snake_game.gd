extends Node2D
## Genero serpiente: el clasico, con el heroe del juego como cabeza.
## 1 - La serpiente avanza sola casilla a casilla. Desliza (o flechas) para girar; no puede
##     darse la vuelta de golpe.
## 2 - Cada fruta la hace crecer. Come las frutas del objetivo para ganar.
## 3 - Chocar con una pared o con tu cola = a repetir el nivel.
## 4 - Monedas "C" opcionales por el tablero. Estrellas por tiempo frente al par del nivel.
## 5 - Giro tuneles (level.wrap): por los huecos del borde sales por el lado contrario.
## Mapa (game.json -> levels[i].map): "#" pared, "." suelo, "S" salida (mira hacia arriba),
## "C" moneda. Parametros: goal (frutas), step (segundos por casilla), par (segundos), seed.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const MapRules = preload("res://kit/snake/snake_map.gd")
const DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

var rows: Array[String] = []
var level: Dictionary = {}
var finished: bool = false
var failed: bool = false
var deaths: int = 0
var time_in_level: float = 0.0
var coins: int = 0
var coins_total: int = 0
var fast: bool = false
var auto_retry: bool = false
var result_panel: ResultPanel
## Estado que lee el bot.
var body: Array[Vector2i] = []
var dir: Vector2i = Vector2i(0, -1)
var next_dir: Vector2i = Vector2i(0, -1)
var fruit: Vector2i = Vector2i(-1, -1)
var eaten: int = 0
var coin_cells: Dictionary = {}
var size: Vector2i = Vector2i.ZERO
var cell: float = 56.0
var origin: Vector2 = Vector2.ZERO
var started: bool = false
var wrap: bool = false

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _view: Node2D
var _head: Node2D
var _goal_label: Label
var _coins_label: Label
var _hint: Label
var _step_timer: float = 0.0
var _swipe_from: Vector2 = Vector2.ZERO
var _swiping: bool = false
var _prev_body: Array[Vector2i] = []


func _ready() -> void:
	level = Kit.current_level()
	wrap = bool(level.get("wrap", false))
	for r: Variant in level.get("map", []):
		rows.append(str(r))
	size = Vector2i(rows[0].length() if not rows.is_empty() else 1, rows.size())
	cell = minf(680.0 / float(size.x), 900.0 / float(size.y))
	origin = Vector2((720.0 - cell * float(size.x)) * 0.5, 250.0)
	RenderingServer.set_default_clear_color(Kit.color("sky", Color("#1b2a41")))
	_view = Node2D.new()
	_view.name = "Board"
	_view.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_view.draw.connect(_draw_view)
	add_child(_view)
	_head = Node2D.new()
	_head.name = "Head"
	_head.z_index = 5
	add_child(_head)
	var art: Dictionary = Kit.sprite_by_role("jugador")
	if not art.is_empty():
		var spr: AnimatedSprite2D = SpriteKit.animado(art, cell * 1.25, "idle", false)
		_head.add_child(spr)
		Skins.apply(spr)
	var cam: Camera2D = Camera2D.new()
	cam.position = Vector2(360.0, 640.0)
	add_child(cam)
	cam.make_current()
	Juice.register_camera(cam)
	_build_hud()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "snake", "goal": goal()})


## Los bots: QaBot juega este genero con el script que devuelve esta funcion.
func bot_script() -> String:
	return "res://qa/snake_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(6.0, 2.0)


func goal() -> int:
	return int(level.get("goal", 12))


func step_time() -> float:
	return float(level.get("step", 0.16))


func par() -> float:
	return float(level.get("par", 60.0))


func wall(c: Vector2i) -> bool:
	return c.x < 0 or c.y < 0 or c.x >= size.x or c.y >= size.y or rows[c.y][c.x] == "#"


## Casilla siguiente (con tuneles, da la vuelta por los bordes). La usa tambien el bot.
func next_cell(c: Vector2i, d: Vector2i) -> Vector2i:
	return MapRules.step(c, d, size.x, size.y, wrap)


func center(c: Vector2i) -> Vector2:
	return origin + (Vector2(c) + Vector2(0.5, 0.5)) * cell


# ------------------------------------------------------------------ montaje

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
	top.add_theme_constant_override("separation", 12)
	col.add_child(top)
	_goal_label = Label.new()
	_goal_label.name = "Goal"
	_goal_label.theme_type_variation = "HeaderLabel"
	top.add_child(_goal_label)
	top.add_child(UiIcon.make("coin", Kit.color("coin", UI.colors["acento"]), 36.0))
	_coins_label = Label.new()
	_coins_label.name = "Coins"
	_coins_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_coins_label)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)
	var grow: Control = Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(grow)
	_hint = Label.new()
	_hint.name = "Hint"
	_hint.text = Kit.text("snake_wrap_hint", "T\u00faneles: sal por un borde y entra por el otro") if wrap else Kit.text("swipe_turn", "Desliza para girar")
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_color_override("font_color", UI.colors["texto_suave"])
	col.add_child(_hint)


func _reset() -> void:
	finished = false
	failed = false
	started = false
	eaten = 0
	coins = 0
	coin_cells.clear()
	body.clear()
	var start: Vector2i = Vector2i(size.x / 2, size.y - 3)
	for y: int in size.y:
		for x: int in size.x:
			if rows[y][x] == "S":
				start = Vector2i(x, y)
			elif rows[y][x] == "C":
				coin_cells[Vector2i(x, y)] = true
	coins_total = coin_cells.size()
	for k: int in 3:
		body.append(start + Vector2i(0, k))
	_prev_body = body.duplicate()
	dir = Vector2i(0, -1)
	next_dir = dir
	_rng.seed = int(level.get("seed", 99))
	_spawn_fruit()
	_step_timer = 0.9 if not fast else 0.0
	_update_hud()
	_place_head(1.0)
	_view.queue_redraw()


func _spawn_fruit() -> void:
	var free: Array[Vector2i] = []
	var occ: Dictionary = {}
	for b: Vector2i in body:
		occ[b] = true
	for y: int in size.y:
		for x: int in size.x:
			var c: Vector2i = Vector2i(x, y)
			if not wall(c) and not occ.has(c) and not coin_cells.has(c) and _open_sides(c) >= 2:
				free.append(c)
	fruit = free[_rng.randi_range(0, free.size() - 1)] if not free.is_empty() else Vector2i(-1, -1)


## Casillas libres alrededor (sin contar paredes): una fruta nunca en un callejon sin salida.
func _open_sides(c: Vector2i) -> int:
	var n: int = 0
	for d: Vector2i in DIRS:
		if not wall(next_cell(c, d)):
			n += 1
	return n


func _update_hud() -> void:
	_goal_label.text = Kit.text("fruits_goal", "Frutas %d/%d") % [eaten, goal()]
	_coins_label.text = "%d/%d" % [coins, coins_total]


# ------------------------------------------------------------------ reglas

func turn(d: Vector2i) -> bool:
	if d == -dir or d == Vector2i.ZERO or finished or failed:
		return false
	next_dir = d
	return true


func _physics_process(delta: float) -> void:
	if finished or failed or get_tree().paused:
		return
	time_in_level += delta
	_step_timer -= delta
	if _step_timer <= 0.0:
		_step_timer += step_time()
		started = true
		_step()
	_place_head(1.0 - clampf(_step_timer / step_time(), 0.0, 1.0))


func _step() -> void:
	_prev_body = body.duplicate()
	dir = next_dir
	var head: Vector2i = next_cell(body[0], dir)
	var grow: bool = head == fruit
	## La cola se mueve a la vez: se puede entrar en la casilla que deja.
	var hits_body: bool = body.slice(0, body.size() - (0 if grow else 1)).has(head)
	if wall(head) or hits_body:
		_lose()
		return
	body.push_front(head)
	if grow:
		eaten += 1
		if not fast:
			Audio.play("coin", 0.1, -4.0)
			Juice.vibrate(15)
		if eaten >= goal():
			_update_hud()
			_view.queue_redraw()
			_finish()
			return
		_spawn_fruit()
	else:
		body.pop_back()
	if coin_cells.has(head):
		coin_cells.erase(head)
		coins += 1
		if not fast:
			Audio.play("powerup", 0.1, -10.0)
	_update_hud()
	_view.queue_redraw()


func _place_head(t: float) -> void:
	if body.is_empty():
		return
	var from: Vector2i = _prev_body[0] if not _prev_body.is_empty() else body[0]
	var a: Vector2 = center(from)
	var b: Vector2 = center(body[0])
	if absi(from.x - body[0].x) + absi(from.y - body[0].y) > 1:
		## Paso por un tunel: sale por un borde y entra por el otro.
		a = b - Vector2(dir) * cell
	_head.position = a.lerp(b, t)


# ------------------------------------------------------------------ entrada

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()
		return
	if event.is_action_pressed("move_left"):
		turn(Vector2i(-1, 0))
	elif event.is_action_pressed("move_right"):
		turn(Vector2i(1, 0))
	elif event.is_action_pressed("move_up"):
		turn(Vector2i(0, -1))
	elif event.is_action_pressed("move_down"):
		turn(Vector2i(0, 1))
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		var pressed: bool = event.pressed
		var pos: Vector2 = event.position
		if pressed:
			_swipe_from = pos
			_swiping = true
		elif _swiping:
			_swiping = false
			_swipe(pos - _swipe_from)
	elif event is InputEventMouseMotion and _swiping:
		## Girar sin soltar: en cuanto el dedo recorre lo suficiente.
		var v: Vector2 = (event as InputEventMouseMotion).position - _swipe_from
		if v.length() > 40.0:
			_swipe(v)
			_swipe_from = (event as InputEventMouseMotion).position


func _swipe(v: Vector2) -> void:
	if v.length() < 24.0:
		return
	if absf(v.x) > absf(v.y):
		turn(Vector2i(1 if v.x > 0.0 else -1, 0))
	else:
		turn(Vector2i(0, 1 if v.y > 0.0 else -1))


# ------------------------------------------------------------------ final

func _finish() -> void:
	finished = true
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = eaten * 100 + coins * 50 + maxi(0, int(par() - time_in_level) * 10)
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "eaten": eaten, "coins": coins, "deaths": deaths, "stars": stars})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


## Estrellas por tiempo: dentro del par tres, hasta un 40 % mas dos, mas una.
func stars_earned() -> int:
	return 3 if time_in_level <= par() else (2 if time_in_level <= par() * 1.4 else 1)


func _lose() -> void:
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "crash", "deaths": deaths, "len": body.size()})
	if not fast:
		Audio.play("hurt")
		Juice.shake(0.35)
	if auto_retry:
		retry()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("snake_lost", "\u00a1Choque!"), Kit.text("snake_hint", "Gira antes de llegar a la pared y no te cierres el paso"))
	p.closed.connect(retry)


## Segunda oportunidad (FailPanel, con anuncio): la serpiente gira hacia un hueco libre y espera
## un momento antes de seguir (si no hay hueco, se queda con la cabeza y dos trozos).
func revive() -> void:
	var dirs: Array[Vector2i] = []
	for d: Vector2i in [dir, Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
		if d == -dir or dirs.has(d):
			continue
		var c: Vector2i = next_cell(body[0], d)
		if not wall(c) and not body.slice(0, body.size() - 1).has(c):
			dirs.append(d)
	if dirs.is_empty():
		while body.size() > 3:
			body.pop_back()
		for d: Vector2i in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
			if not wall(next_cell(body[0], d)) and not body.has(next_cell(body[0], d)):
				dirs.append(d)
				break
	if not dirs.is_empty():
		dir = dirs[0]
		next_dir = dir
	_prev_body = body.duplicate()
	failed = false
	_step_timer = 1.2
	_update_hud()
	_place_head(1.0)


func retry() -> void:
	_reset()


func open_pause() -> void:
	if finished or get_tree().paused or get_node_or_null("PauseMenu") != null:
		return
	_swiping = false
	PauseMenu.open(self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_inside_tree() and not UI.test_mode:
			open_pause()


func bot_state() -> Dictionary:
	return {"pos": Vector2(body[0]) if not body.is_empty() else Vector2.ZERO, "deaths": deaths, "coins": coins,
		"finished": finished, "failed": failed, "stomps": eaten, "eaten": eaten, "len": body.size()}


# ------------------------------------------------------------------ dibujo

func _draw_view() -> void:
	var sky: Color = Kit.color("sky", Color("#1b2a41"))
	var floor_a: Color = sky.lightened(0.1)
	var floor_b: Color = sky.lightened(0.14)
	var wall_c: Color = Kit.color("solid", Color("#4f6787"))
	for y: int in size.y:
		for x: int in size.x:
			var r: Rect2 = Rect2(origin + Vector2(float(x), float(y)) * cell, Vector2(cell, cell))
			if rows[y][x] == "#":
				var wtex: Texture2D = Kit.first_tile_texture()
				if wtex != null:
					_view.draw_texture_rect(wtex, r.grow(-1.0), false, Color.WHITE)
				else:
					_view.draw_rect(r.grow(-1.0), wall_c)
				_view.draw_rect(Rect2(r.position + Vector2(1, cell - cell * 0.18), Vector2(cell - 2.0, cell * 0.17)), wall_c.darkened(0.35))
			else:
				_view.draw_rect(r, floor_a if (x + y) % 2 == 0 else floor_b)
				if wrap and (x == 0 or y == 0 or x == size.x - 1 or y == size.y - 1):
					## Boca de tunel: anillo de color en el borde.
					_view.draw_rect(r.grow(-cell * 0.08), Color(0.45, 0.95, 0.85, 0.35))
					_view.draw_arc(r.get_center(), cell * 0.32, 0.0, TAU, 20, Color(0.45, 0.95, 0.85, 0.9), 4.0)
	var coin: Color = Kit.color("coin", Color("#e8b04b"))
	for c: Vector2i in coin_cells:
		_view.draw_circle(center(c), cell * 0.2, coin)
	## Fruta: el color de peligro con un brillo (late para que se vea).
	if fruit.x >= 0:
		var fc: Color = Kit.color("danger", Color("#ff6b5b"))
		var pulse: float = 1.0 + 0.08 * sin(time_in_level * 8.0)
		_view.draw_circle(center(fruit), cell * 0.34 * pulse, fc)
		_view.draw_circle(center(fruit) + Vector2(-cell * 0.1, -cell * 0.12), cell * 0.09, fc.lightened(0.6))
		_view.draw_line(center(fruit) + Vector2(0, -cell * 0.3), center(fruit) + Vector2(cell * 0.12, -cell * 0.46), Color(0.3, 0.7, 0.3), 4.0)
	## Cuerpo: del color de acento, mas oscuro hacia la cola.
	var acc: Color = Skins.recolor(Kit.color("accent", Color("#e8b04b")))
	for i: int in range(body.size() - 1, 0, -1):
		var t: float = float(i) / float(maxi(body.size(), 2))
		var col: Color = acc.darkened(0.35 * t)
		var a: Vector2 = center(body[i])
		var b: Vector2 = center(body[i - 1])
		if absi(body[i].x - body[i - 1].x) + absi(body[i].y - body[i - 1].y) <= 1:
			_view.draw_line(a, b, col, cell * 0.72)
		_view.draw_circle(a, cell * 0.36, col)
	if _head.get_child_count() == 0 and not body.is_empty():
		_view.draw_circle(_head.position, cell * 0.45, acc.lightened(0.15))
