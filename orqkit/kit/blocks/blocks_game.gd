extends Node2D
## Genero bloques: puzle de encajar piezas en un tablero de 8x8.
## 1 - Abajo hay 3 piezas. Arrastra cada una al tablero; cuando usas las 3, llegan otras 3.
## 2 - Una fila o columna llena se limpia (varias a la vez dan combo).
## 3 - Objetivo: limpiar todas las gemas del tablero o, si no hay gemas, limpiar N lineas.
## 4 - Si ninguna pieza de la bandeja cabe, se acaba la partida y se repite.
## 5 - Estrellas segun las piezas usadas frente al par del nivel.
## Las piezas salen siempre en el mismo orden (semilla del nivel): lo que el bot supera, la
## persona tambien puede superarlo.
## Mapa (game.json -> levels[i].map): 8 filas de 8: "." libre, "#" bloque, "G" gema.
## Parametros del nivel: seed, lines (objetivo si no hay gemas), par (piezas) y big (0-1:
## cuantas piezas grandes salen).
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const MapRules = preload("res://kit/blocks/blocks_map.gd")
const N: int = 8
const CELL: float = 78.0
const BOARD_POS: Vector2 = Vector2((720.0 - 8.0 * 78.0) * 0.5, 300.0)
const TRAY_Y: float = 1080.0
const DRAG_LIFT: float = 150.0
## Piezas: celdas (x, y). Las grandes son las que cierran partidas.
const PIECES: Array = [
	[[0, 0]],
	[[0, 0], [1, 0]], [[0, 0], [0, 1]],
	[[0, 0], [1, 0], [2, 0]], [[0, 0], [0, 1], [0, 2]],
	[[0, 0], [1, 0], [0, 1], [1, 1]],
	[[0, 0], [1, 0], [0, 1]], [[0, 0], [1, 0], [1, 1]], [[0, 0], [0, 1], [1, 1]], [[1, 0], [0, 1], [1, 1]],
	[[0, 0], [1, 0], [2, 0], [3, 0]], [[0, 0], [0, 1], [0, 2], [0, 3]],
	[[0, 0], [1, 0], [2, 0], [1, 1]], [[0, 0], [0, 1], [0, 2], [1, 2]],
	[[0, 0], [1, 0], [2, 0], [3, 0], [4, 0]], [[0, 0], [0, 1], [0, 2], [0, 3], [0, 4]],
	[[0, 0], [1, 0], [2, 0], [0, 1], [0, 2]], [[0, 0], [1, 0], [2, 0], [2, 1], [2, 2]],
	[[0, 0], [1, 0], [2, 0], [0, 1], [1, 1], [2, 1], [0, 2], [1, 2], [2, 2]],
]
const BIG: Array[int] = [10, 11, 14, 15, 16, 17, 18]

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
## Estado que lee el bot: board[y][x] 0 libre, 1 bloque, 2 gema; tray = indices de PIECES (-1 usada).
var board: Array = []
var tray: Array[int] = [-1, -1, -1]
var used: int = 0
var lines: int = 0
var gems_left: int = 0
var score: int = 0

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _view: Node2D
var _hero: Node2D
var _goal_label: Label
var _score_label: Label
var _drag: int = -1
var _drag_pos: Vector2 = Vector2.ZERO
var _flash: Array[Dictionary] = []


func _ready() -> void:
	level = Kit.current_level()
	for r: Variant in level.get("map", []):
		rows.append(str(r))
	RenderingServer.set_default_clear_color(Kit.color("sky", Color("#1b2a41")))
	_view = Node2D.new()
	_view.name = "Board"
	_view.draw.connect(_draw_view)
	add_child(_view)
	var cam: Camera2D = Camera2D.new()
	cam.position = Vector2(360.0, 640.0)
	add_child(cam)
	cam.make_current()
	Juice.register_camera(cam)
	_build_hero()
	_build_hud()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "blocks", "gems": gems_left})


## Los bots: QaBot juega este genero con el script que devuelve esta funcion.
func bot_script() -> String:
	return "res://qa/blocks_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(4.0, 1.2)


func target_lines() -> int:
	return int(level.get("lines", 8))


func par() -> int:
	return int(level.get("par", 24))


# ------------------------------------------------------------------ montaje

func _build_hero() -> void:
	_hero = Node2D.new()
	_hero.name = "Hero"
	_hero.position = Vector2(620.0, 270.0)
	_hero.z_index = 4
	add_child(_hero)
	var art: Dictionary = Kit.sprite_by_role("jugador")
	if not art.is_empty():
		var spr: AnimatedSprite2D = SpriteKit.animado(art, 84.0, "idle", true)
		_hero.add_child(spr)
		Skins.apply(spr)


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
	_goal_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_goal_label)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)
	_score_label = Label.new()
	_score_label.name = "Score"
	_score_label.add_theme_color_override("font_color", UI.colors["texto_suave"])
	col.add_child(_score_label)


func _reset() -> void:
	finished = false
	failed = false
	used = 0
	lines = 0
	score = 0
	coins = 0
	_flash.clear()
	board.clear()
	gems_left = 0
	for y: int in N:
		var r: Array = []
		var src: String = rows[y] if y < rows.size() else ".".repeat(N)
		for x: int in N:
			var ch: String = src[x] if x < src.length() else "."
			r.append(1 if ch == "#" else (2 if ch == "G" else 0))
			if ch == "G":
				gems_left += 1
		board.append(r)
	coins_total = gems_left
	_rng.seed = int(level.get("seed", 1234))
	_deal()
	_update_hud()
	_view.queue_redraw()


func _deal() -> void:
	var big: float = float(level.get("big", 0.3))
	for i: int in 3:
		var p: int = _rng.randi_range(0, PIECES.size() - 1)
		## Las grandes salen menos en niveles faciles.
		if BIG.has(p) and _rng.randf() > big:
			p = _rng.randi_range(0, 9)
		tray[i] = p


func _update_hud() -> void:
	if gems_left > 0 or coins_total > 0:
		_goal_label.text = Kit.text("gems_left", "Gemas: %d") % gems_left
	else:
		_goal_label.text = Kit.text("lines_goal", "L\u00edneas: %d/%d") % [lines, target_lines()]
	_score_label.text = Kit.text("pieces_used", "Piezas: %d \u00b7 par %d") % [used, par()]


# ------------------------------------------------------------------ reglas

func fits(p: int, at: Vector2i) -> bool:
	if p < 0:
		return false
	for c: Array in PIECES[p]:
		var x: int = at.x + int(c[0])
		var y: int = at.y + int(c[1])
		if x < 0 or y < 0 or x >= N or y >= N or int(board[y][x]) != 0:
			return false
	return true


func fits_anywhere(p: int) -> bool:
	for y: int in N:
		for x: int in N:
			if fits(p, Vector2i(x, y)):
				return true
	return false


## Pone la pieza 'slot' de la bandeja en 'at'. Devuelve las lineas limpiadas (-1 si no cabe).
func place(slot: int, at: Vector2i) -> int:
	if finished or failed or slot < 0 or slot > 2 or not fits(tray[slot], at):
		return -1
	var p: int = tray[slot]
	for c: Array in PIECES[p]:
		board[at.y + int(c[1])][at.x + int(c[0])] = 1
	tray[slot] = -1
	used += 1
	score += (PIECES[p] as Array).size()
	var cleared: int = _clear_lines()
	if not fast:
		Audio.play("land" if cleared == 0 else "coin", 0.1, -6.0)
	if tray.all(func(t: int) -> bool: return t < 0):
		_deal()
	_update_hud()
	_view.queue_redraw()
	if (coins_total > 0 and gems_left == 0) or (coins_total == 0 and lines >= target_lines()):
		_finish()
	elif not tray.any(func(t: int) -> bool: return t >= 0 and fits_anywhere(t)):
		_lose()
	return cleared


func _clear_lines() -> int:
	var full_rows: Array[int] = []
	var full_cols: Array[int] = []
	for y: int in N:
		if (board[y] as Array).all(func(v: int) -> bool: return v != 0):
			full_rows.append(y)
	for x: int in N:
		var ok: bool = true
		for y: int in N:
			if int(board[y][x]) == 0:
				ok = false
				break
		if ok:
			full_cols.append(x)
	var gems_before: int = gems_left
	for y: int in full_rows:
		for x: int in N:
			_take(x, y)
	for x: int in full_cols:
		for y: int in N:
			_take(x, y)
	var n: int = full_rows.size() + full_cols.size()
	if n > 0:
		lines += n
		score += 10 * n * n
		coins += gems_before - gems_left
		QA.log_event("lines", {"n": n, "gems": gems_before - gems_left})
		if not fast:
			Juice.shake(0.12 * float(n))
			Juice.vibrate(20)
			if n >= 2:
				Audio.play("powerup", 0.05, -4.0)
			if _hero.get_child_count() > 0:
				var tw: Tween = _hero.create_tween()
				tw.tween_property(_hero, "position:y", 230.0, 0.12)
				tw.tween_property(_hero, "position:y", 270.0, 0.2)
		for y: int in full_rows:
			_flash.append({"rect": Rect2(BOARD_POS + Vector2(0, float(y) * CELL), Vector2(float(N) * CELL, CELL)), "life": 0.35})
		for x: int in full_cols:
			_flash.append({"rect": Rect2(BOARD_POS + Vector2(float(x) * CELL, 0), Vector2(CELL, float(N) * CELL)), "life": 0.35})
	return n


func _take(x: int, y: int) -> void:
	if int(board[y][x]) == 2:
		gems_left -= 1
	board[y][x] = 0


# ------------------------------------------------------------------ entrada

func _tray_center(i: int) -> Vector2:
	return Vector2(130.0 + float(i) * 230.0, TRAY_Y)


func _cell_at(p: Vector2) -> Vector2i:
	var q: Vector2 = (p - BOARD_POS) / CELL
	return Vector2i(int(floor(q.x)), int(floor(q.y)))


func _to_game(screen: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * screen


func _drop_cell() -> Vector2i:
	## La pieza se dibuja encima del dedo: su celda (0,0) cae aqui.
	var top_left: Vector2 = _drag_pos + Vector2(0.0, -DRAG_LIFT) - _piece_size(tray[_drag]) * CELL * 0.5
	return _cell_at(top_left + Vector2(CELL, CELL) * 0.5)


func _piece_size(p: int) -> Vector2:
	var m: Vector2 = Vector2.ZERO
	for c: Array in PIECES[p]:
		m = Vector2(maxf(m.x, float(c[0]) + 1.0), maxf(m.y, float(c[1]) + 1.0))
	return m


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		var p: Vector2 = _to_game(mb.position)
		if mb.pressed:
			for i: int in 3:
				if tray[i] >= 0 and p.distance_to(_tray_center(i)) < 110.0:
					_drag = i
					_drag_pos = p
					if not fast:
						Audio.play("click", 0.05, -8.0)
					break
		elif _drag >= 0:
			var slot: int = _drag
			var at: Vector2i = _drop_cell()
			_drag = -1
			if place(slot, at) < 0 and not fast:
				Audio.play("hurt", 0.05, -14.0)
		_view.queue_redraw()
	elif event is InputEventMouseMotion and _drag >= 0:
		_drag_pos = _to_game((event as InputEventMouseMotion).position)
		_view.queue_redraw()


func _process(delta: float) -> void:
	if not finished:
		time_in_level += delta
	if not _flash.is_empty():
		for f: Dictionary in _flash:
			f["life"] = float(f["life"]) - delta
		_flash = _flash.filter(func(f: Dictionary) -> bool: return float(f["life"]) > 0.0)
		_view.queue_redraw()


# ------------------------------------------------------------------ final

func _finish() -> void:
	finished = true
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "used": used, "lines": lines, "deaths": deaths, "stars": stars})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


## Estrellas segun las piezas usadas: dentro del par tres, hasta un 30 % mas dos, mas una.
func stars_earned() -> int:
	return 3 if used <= par() else (2 if float(used) <= float(par()) * 1.3 else 1)


func _lose() -> void:
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "no_fit", "deaths": deaths, "used": used})
	if auto_retry:
		retry()
		return
	Audio.play("hurt")
	var p: FailPanel = FailPanel.open(self, Kit.text("blocks_lost", "\u00a1No cabe ninguna pieza!"), Kit.text("blocks_hint", "Deja hueco para las piezas grandes"))
	p.closed.connect(retry)


func retry() -> void:
	_reset()


func open_pause() -> void:
	if finished or get_tree().paused or get_node_or_null("PauseMenu") != null:
		return
	_drag = -1
	PauseMenu.open(self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_inside_tree() and not UI.test_mode:
			open_pause()


func bot_state() -> Dictionary:
	return {"pos": Vector2(float(used), float(lines)), "deaths": deaths, "coins": coins, "finished": finished, "failed": failed,
		"stomps": lines, "used": used, "gems_left": gems_left}


# ------------------------------------------------------------------ dibujo

func _block_color(i: int) -> Color:
	var cols: Array[Color] = [Kit.color("accent", Color("#e8b04b")), Kit.color("enemy", Color("#d9774a")),
		Kit.color("solid", Color("#4f6787")).lightened(0.25), Kit.color("danger", Color("#ff6b5b"))]
	return cols[i % cols.size()]


func _draw_cell(at: Vector2, size: float, col: Color) -> void:
	var r: Rect2 = Rect2(at + Vector2(2, 2), Vector2(size - 4.0, size - 4.0))
	_view.draw_rect(r, col)
	_view.draw_rect(Rect2(r.position, Vector2(r.size.x, size * 0.16)), col.lightened(0.28))
	_view.draw_rect(Rect2(r.position + Vector2(0, r.size.y - size * 0.14), Vector2(r.size.x, size * 0.14)), col.darkened(0.3))


func _draw_view() -> void:
	var sky: Color = Kit.color("sky", Color("#1b2a41"))
	var slot: Color = sky.lightened(0.1)
	_view.draw_rect(Rect2(BOARD_POS - Vector2(10, 10), Vector2(float(N) * CELL + 20.0, float(N) * CELL + 20.0)), sky.darkened(0.25))
	for y: int in N:
		for x: int in N:
			var at: Vector2 = BOARD_POS + Vector2(float(x), float(y)) * CELL
			var v: int = int(board[y][x])
			if v == 0:
				_view.draw_rect(Rect2(at + Vector2(3, 3), Vector2(CELL - 6.0, CELL - 6.0)), slot)
			elif v == 1:
				_draw_cell(at, CELL, _block_color(x * 3 + y * 5))
			else:
				_draw_cell(at, CELL, Kit.color("coin", Color("#e8b04b")))
				var c: Vector2 = at + Vector2(CELL, CELL) * 0.5
				_view.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -20), c + Vector2(18, 0), c + Vector2(0, 20), c + Vector2(-18, 0)]), Color(1, 1, 1, 0.9))
	## Sombra de donde caeria la pieza que se arrastra.
	if _drag >= 0:
		var at2: Vector2i = _drop_cell()
		var ok: bool = fits(tray[_drag], at2)
		for c: Array in PIECES[tray[_drag]]:
			var cell: Vector2i = at2 + Vector2i(int(c[0]), int(c[1]))
			if cell.x >= 0 and cell.y >= 0 and cell.x < N and cell.y < N:
				_view.draw_rect(Rect2(BOARD_POS + Vector2(cell) * CELL + Vector2(3, 3), Vector2(CELL - 6.0, CELL - 6.0)),
					Color(1, 1, 1, 0.28) if ok else Color(1, 0.3, 0.3, 0.22))
	for f: Dictionary in _flash:
		_view.draw_rect(f["rect"], Color(1, 1, 1, float(f["life"]) * 2.0))
	## Bandeja.
	for i: int in 3:
		if tray[i] < 0 or i == _drag:
			continue
		var k: float = 0.55
		var sz: Vector2 = _piece_size(tray[i]) * CELL * k
		var origin: Vector2 = _tray_center(i) - sz * 0.5
		var fits_now: bool = fits_anywhere(tray[i])
		for c: Array in PIECES[tray[i]]:
			_draw_cell(origin + Vector2(float(c[0]), float(c[1])) * CELL * k, CELL * k, _block_color(tray[i]) if fits_now else Color(0.4, 0.42, 0.48))
	if _drag >= 0:
		var sz2: Vector2 = _piece_size(tray[_drag]) * CELL
		var origin2: Vector2 = _drag_pos + Vector2(0.0, -DRAG_LIFT) - sz2 * 0.5
		for c: Array in PIECES[tray[_drag]]:
			_draw_cell(origin2 + Vector2(float(c[0]), float(c[1])) * CELL, CELL, _block_color(tray[_drag]))
