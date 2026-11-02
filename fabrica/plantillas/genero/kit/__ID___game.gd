extends Node2D
## Genero __ES__ (esqueleto creado por nuevo_genero.py: cambia estas reglas por las de tu genero).
## La plantilla ya es un juego completo para que la cadena funcione desde el primer minuto:
## 1 - Vista desde arriba en una cuadricula. Desliza el dedo (o flechas) para moverte una casilla.
## 2 - Recoge todas las monedas para ganar. Los pinchos te devuelven a la salida (una muerte).
## 3 - Estrellas: 3 sin morir, 2 con una muerte, 1 con mas.
## Mapa (game.json -> levels[i].map): "#" roca, "." suelo, "P" salida, "C" moneda, "X" pinchos.
## Contrato con el kit (no lo rompas): finished, deaths, time_in_level, fast, auto_retry,
## bot_script(), bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const MapRules = preload("res://kit/__ID__/__ID___map.gd")
const CELL: float = 96.0
const STEP_TIME: float = 0.14

var rows: Array[String] = []
var finished: bool = false
var failed: bool = false
var deaths: int = 0
var time_in_level: float = 0.0
var coins: int = 0
var coins_total: int = 0
var moves: int = 0
var fast: bool = false
var auto_retry: bool = false
var result_panel: ResultPanel
var cell: Vector2i = Vector2i.ZERO
var start: Vector2i = Vector2i.ZERO
var coin_cells: Dictionary = {}

var _board: Node2D
var _player: Node2D
var _camera: Camera2D
var _coins_label: Label
var _moving: float = 0.0
var _swipe_from: Vector2 = Vector2.ZERO
var _swiping: bool = false


func _ready() -> void:
	for r: Variant in Kit.current_level().get("map", []):
		rows.append(str(r))
	RenderingServer.set_default_clear_color(Kit.color("sky", Color("#1b2a41")))
	_board = Node2D.new()
	_board.name = "Board"
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
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "__ID__", "rows": rows.size()})


## Los bots: QaBot juega este genero con el script que devuelve esta funcion.
func bot_script() -> String:
	return "res://qa/__ID___bot.gd"


func _fit_camera() -> void:
	var w: float = float(rows[0].length() if not rows.is_empty() else 1) * CELL
	var h: float = float(rows.size()) * CELL
	var vp: Vector2 = get_viewport_rect().size
	var z: float = minf(vp.x / (w + CELL), vp.y * 0.78 / (h + CELL))
	_camera.zoom = Vector2.ONE * minf(z, 1.2)
	_camera.position = Vector2(w, h) * 0.5 + Vector2(0.0, CELL * 0.4)


func _build_player() -> void:
	_player = Node2D.new()
	_player.name = "Player"
	_player.z_index = 5
	add_child(_player)
	var art: Dictionary = Kit.sprite_by_role("jugador")
	if not art.is_empty():
		var spr: AnimatedSprite2D = SpriteKit.animado(art, CELL * 0.85, "idle", false)
		_player.add_child(spr)
		Skins.apply(spr)
	else:
		var body: Polygon2D = Polygon2D.new()
		body.color = Kit.color("accent", Color.ORANGE)
		body.polygon = LevelBuilder._circle(CELL * 0.36, 20)
		_player.add_child(body)


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
	top.add_child(UiIcon.make("coin", Kit.color("coin", UI.colors["acento"]), 40.0))
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
	var hint: Label = Label.new()
	hint.name = "Hint"
	hint.text = Kit.text("swipe_move_hint", "Desliza para moverte")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", UI.colors["texto_suave"])
	col.add_child(hint)


func _reset() -> void:
	finished = false
	failed = false
	coins = 0
	moves = 0
	coin_cells.clear()
	for y: int in rows.size():
		for x: int in rows[y].length():
			if rows[y][x] == "C":
				coin_cells[Vector2i(x, y)] = true
			elif rows[y][x] == "P":
				start = Vector2i(x, y)
	coins_total = coin_cells.size()
	cell = start
	_player.position = _center(cell)
	_moving = 0.0
	_update_hud()
	_board.queue_redraw()


func _center(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * CELL


func _update_hud() -> void:
	_coins_label.text = "%d/%d" % [coins, coins_total]


# ------------------------------------------------------------------ reglas

func can_move() -> bool:
	return not finished and not failed and _moving <= 0.0 and not get_tree().paused


## Mueve una casilla. Devuelve false si no se puede (roca, borde, ya moviendose).
func try_move(dir: Vector2i) -> bool:
	if not can_move():
		return false
	var target: Vector2i = cell + dir
	if target.y < 0 or target.y >= rows.size() or target.x < 0 or target.x >= rows[target.y].length():
		return false
	if rows[target.y][target.x] == "#":
		return false
	cell = target
	moves += 1
	var t: float = STEP_TIME * (0.25 if fast else 1.0)
	_moving = t
	var tw: Tween = create_tween()
	tw.tween_property(_player, "position", _center(cell), t)
	if coin_cells.has(cell):
		coin_cells.erase(cell)
		coins += 1
		Audio.play("coin", 0.1, -6.0)
		_board.queue_redraw()
		_update_hud()
		if coins >= coins_total:
			_finish()
	elif rows[cell.y][cell.x] == "X":
		_lose()
	return true


func _physics_process(delta: float) -> void:
	if finished:
		return
	time_in_level += delta
	_moving -= delta
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
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = coins * 100 + maxi(0, 3000 - moves * 20) - deaths * 300
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "coins": coins, "moves": moves, "deaths": deaths, "stars": stars})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": maxi(score, 0), "record": record})
	await Ads.show_interstitial("level_end")


func stars_earned() -> int:
	return clampi(3 - deaths, 1, 3)


func _lose() -> void:
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "spikes", "deaths": deaths})
	Audio.play("hurt")
	Juice.shake(0.4)
	if auto_retry:
		retry()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("__ID___lost", "\u00a1Pinchazo!"), Kit.text("__ID___hint", "Recoge todas las monedas sin pisar los pinchos"))
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
	return {"pos": Vector2(cell), "deaths": deaths, "coins": coins, "finished": finished, "failed": failed, "stomps": 0}


# ------------------------------------------------------------------ dibujo

func _draw_board() -> void:
	var floor_a: Color = Kit.color("sky", Color("#1b2a41")).lightened(0.10)
	var floor_b: Color = Kit.color("sky", Color("#1b2a41")).lightened(0.16)
	var rock: Color = Kit.color("solid", Color("#3e5c84"))
	var danger: Color = Kit.color("danger", Color("#ff6b5b"))
	var coin: Color = Kit.color("coin", Color("#e8b04b"))
	for y: int in rows.size():
		for x: int in rows[y].length():
			var r: Rect2 = Rect2(Vector2(x, y) * CELL, Vector2(CELL, CELL))
			var ch: String = rows[y][x]
			if ch == "#":
				_board.draw_rect(r.grow(-3.0), rock)
				_board.draw_rect(Rect2(r.position + Vector2(3.0, CELL - 14.0), Vector2(CELL - 6.0, 11.0)), rock.darkened(0.35))
				continue
			_board.draw_rect(r, floor_a if (x + y) % 2 == 0 else floor_b)
			if ch == "X":
				for k: int in 3:
					var bx: float = r.position.x + 14.0 + float(k) * 24.0
					var by: float = r.position.y + CELL - 20.0
					_board.draw_colored_polygon(PackedVector2Array([Vector2(bx, by), Vector2(bx + 22.0, by), Vector2(bx + 11.0, by - 40.0)]), danger)
	for c: Vector2i in coin_cells:
		_board.draw_circle(_center(c), CELL * 0.2, coin)
		_board.draw_circle(_center(c) + Vector2(-5.0, -6.0), CELL * 0.06, coin.lightened(0.5))
