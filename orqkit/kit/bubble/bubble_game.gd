extends Node2D
## Genero burbujas (bubble shooter): apunta, dispara y junta 3 o mas del mismo color para que
## exploten; lo que queda suelto cae. Las reglas y la fisica estan en bubble_map.gd (las mismas que
## el bot y el analizador).
## 1 - Arrastra el dedo para apuntar (se ve la trayectoria hasta el primer rebote) y suelta para
##     disparar. Tambien se puede tocar donde quieres apuntar.
## 2 - Ganas al vaciar el tablero. Pierdes si se acaban los disparos o una burbuja llega abajo.
## 3 - Estrellas por los disparos que sobran.
## Mapa y parametros: ver bubble_map.gd.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const MapRules = preload("res://kit/bubble/bubble_map.gd")
const UNIT: float = 80.0
const FLY_SPEED: float = 26.0
const PALETTE: Array[Color] = [Color("#ff5d5d"), Color("#3fa7ff"), Color("#ffd23f"), Color("#4fd17b"), Color("#b36bff"), Color("#ff9a3c")]

var level: Dictionary = {}
var grid: Dictionary = {}
var lose_row: int = 12
var shots_total: int = 30
var shots: int = 0
var seed_v: int = 1
var current: String = "a"
var upcoming: String = "a"
var finished: bool = false
var failed: bool = false
var deaths: int = 0
var time_in_level: float = 0.0
var coins: int = 0
var coins_total: int = 0
var popped: int = 0
var fast: bool = false
var auto_retry: bool = false
var aim: float = 0.0
var result_panel: ResultPanel

var _start: Dictionary = {}
var _flying: bool = false
var _path: PackedVector2Array = PackedVector2Array()
var _path_i: int = 0
var _fly_pos: Vector2 = Vector2.ZERO
var _target: Vector2i = Vector2i(-1, -1)
var _aiming: bool = false
var _board: Node2D
var _camera: Camera2D
var _shots_label: Label
var _count_label: Label


func _ready() -> void:
	level = Kit.current_level()
	lose_row = int(level.get("lose_row", 12))
	shots_total = int(level.get("shots", 30))
	seed_v = int(level.get("seed", 1))
	_start = MapRules.parse(level)
	coins_total = _start.size()
	RenderingServer.set_default_clear_color(Kit.color("sky", Color("#1b2a41")))
	_board = Node2D.new()
	_board.name = "Board"
	_board.draw.connect(_draw_board)
	add_child(_board)
	_camera = Camera2D.new()
	add_child(_camera)
	_camera.make_current()
	Juice.register_camera(_camera)
	_fit_camera()
	_build_hud()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "bubble", "bubbles": coins_total, "shots": shots_total})


func bot_script() -> String:
	return "res://qa/bubble_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(0.8, 0.6)


func _fit_camera() -> void:
	var w: float = float(MapRules.W) * UNIT
	var h: float = (MapRules.launcher(lose_row).y + 1.0) * UNIT
	var vp: Vector2 = get_viewport_rect().size
	var z: float = minf(vp.x * 0.94 / w, vp.y * 0.8 / h)
	_camera.zoom = Vector2.ONE * z
	_camera.position = Vector2(w * 0.5, h * 0.5 - UNIT * 0.2)


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
	_shots_label = Label.new()
	_shots_label.name = "Shots"
	_shots_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shots_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_shots_label)
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
	hint.text = Kit.text("bubble_hint", "Arrastra para apuntar y suelta para disparar")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", UI.colors["texto_suave"])
	col.add_child(hint)


func _reset() -> void:
	finished = false
	failed = false
	grid = _start.duplicate()
	shots = 0
	popped = 0
	_flying = false
	aim = 0.0
	current = MapRules.next_color(grid, seed_v, 0)
	upcoming = MapRules.next_color(grid, seed_v, 1)
	_refresh()


func _refresh() -> void:
	coins = coins_total - grid.size()
	_count_label.text = "%d/%d" % [coins, coins_total]
	_shots_label.text = Kit.text("bubble_shots", "Disparos") + ": %d" % (shots_total - shots)
	_board.queue_redraw()


# ------------------------------------------------------------------ reglas

func can_shoot() -> bool:
	return not finished and not failed and not _flying and not get_tree().paused


## Dispara con el angulo dado (radianes desde la vertical; lo usa el toque y el bot).
func shoot(angle: float) -> bool:
	if not can_shoot():
		return false
	aim = clampf(angle, -MapRules.MAX_ANGLE, MapRules.MAX_ANGLE)
	var t: Array = MapRules.trace(grid, lose_row, aim)
	_path = t[0]
	_target = t[1]
	_path_i = 0
	_fly_pos = _path[0]
	_flying = true
	shots += 1
	Audio.play("jump", 0.1, -8.0)
	if fast:
		_land()
	return true


func _land() -> void:
	_flying = false
	var r: Array = MapRules.place(grid, _target, current)
	grid = r[0]
	var exploded: int = int(r[1])
	var dropped: int = int(r[2])
	popped += exploded + dropped
	if exploded > 0 and not fast:
		Audio.play("stomp", 0.1, 0.0, 1.0 + 0.05 * float(mini(exploded + dropped, 10)))
		Juice.burst(self, MapRules.center(_target.x, _target.y) * UNIT, _color_of(current), 10 + dropped, 260.0)
		if dropped > 0:
			UI.float_text(self, MapRules.center(_target.x, _target.y) * UNIT, "+%d" % dropped, Kit.color("coin", Color.YELLOW), 34)
	current = MapRules.next_color(grid, seed_v, shots)
	upcoming = MapRules.next_color(grid, seed_v, shots + 1)
	_refresh()
	if grid.is_empty():
		_finish()
	elif MapRules.lowest_row(grid) >= lose_row:
		_lose("bottom")
	elif shots >= shots_total:
		_lose("shots")


func _physics_process(delta: float) -> void:
	if finished:
		return
	time_in_level += delta
	if not _flying:
		return
	var move: float = FLY_SPEED * delta
	while move > 0.0 and _path_i < _path.size() - 1:
		var nxt: Vector2 = _path[_path_i + 1]
		var d: float = _fly_pos.distance_to(nxt)
		if d <= move:
			_fly_pos = nxt
			_path_i += 1
			move -= d
		else:
			_fly_pos = _fly_pos.move_toward(nxt, move)
			move = 0.0
	_board.queue_redraw()
	if _path_i >= _path.size() - 1:
		_land()


func _angle_to(world: Vector2) -> float:
	var v: Vector2 = world / UNIT - MapRules.launcher(lose_row)
	if v.y > -0.2:
		v.y = -0.2
	return clampf(atan2(v.x, -v.y), -MapRules.MAX_ANGLE, MapRules.MAX_ANGLE)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()
		return
	var pos: Vector2
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		pos = event.position
		var world: Vector2 = get_canvas_transform().affine_inverse() * pos
		if event.pressed:
			_aiming = true
			aim = _angle_to(world)
		elif _aiming:
			_aiming = false
			aim = _angle_to(world)
			shoot(aim)
		_board.queue_redraw()
	elif (event is InputEventScreenDrag or event is InputEventMouseMotion) and _aiming:
		aim = _angle_to(get_canvas_transform().affine_inverse() * event.position)
		_board.queue_redraw()


# ------------------------------------------------------------------ final

func _finish() -> void:
	finished = true
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = popped * 20 + (shots_total - shots) * 100
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "coins": coins, "shots": shots, "deaths": deaths, "stars": stars})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": maxi(score, 0), "record": record})
	await Ads.show_interstitial("level_end")


## 3 estrellas si sobra un tercio de los disparos; 2 si sobra alguno.
func stars_earned() -> int:
	var left: int = shots_total - shots
	if left * 3 >= shots_total:
		return 3
	return 2 if left > 0 else 1


func _lose(cause: String) -> void:
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": cause, "deaths": deaths})
	Audio.play("hurt")
	Juice.shake(0.35)
	if auto_retry:
		retry()
		return
	var why: String = Kit.text("bubble_lost_bottom", "\u00a1Han llegado abajo!") if cause == "bottom" else Kit.text("bubble_lost_shots", "Sin disparos")
	var p: FailPanel = FailPanel.open(self, why, Kit.text("bubble_fail_hint", "Apunta a los grupos de arriba: lo que cae da muchos puntos"))
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
	return {"pos": Vector2(float(shots), float(grid.size())), "deaths": deaths, "coins": coins, "finished": finished, "failed": failed,
		"stomps": popped, "shots": shots}


# ------------------------------------------------------------------ dibujo

func _color_of(ch: String) -> Color:
	var i: int = MapRules.COLORS.find(ch)
	return PALETTE[i % PALETTE.size()] if i >= 0 else Color.GRAY


func _bubble(at: Vector2, ch: String, r: float) -> void:
	var c: Color = _color_of(ch)
	_board.draw_circle(at, r, c.darkened(0.25))
	_board.draw_circle(at, r * 0.86, c)
	_board.draw_circle(at + Vector2(-r * 0.3, -r * 0.32), r * 0.24, c.lightened(0.55))
	## Una marca por color (para daltonismo): puntos de 1 a 3 o un aro.
	var k: int = MapRules.COLORS.find(ch)
	if k >= 3:
		_board.draw_arc(at, r * 0.42, 0.0, TAU, 16, c.darkened(0.45), 3.0)
	for d: int in (k % 3) + 1:
		_board.draw_circle(at + Vector2(float(d) * 9.0 - float((k % 3) + 2) * 4.5, r * 0.25), 3.2, c.darkened(0.5))


func _draw_board() -> void:
	var w: float = float(MapRules.W) * UNIT
	var line_y: float = (float(lose_row) * MapRules.ROW_H + 0.1) * UNIT
	_board.draw_rect(Rect2(Vector2(0.0, 0.0), Vector2(w, line_y)), Color(1, 1, 1, 0.04))
	_board.draw_line(Vector2(0.0, line_y), Vector2(w, line_y), Color(Kit.color("danger", Color("#ff6b5b")), 0.6), 4.0)
	for k: Variant in grid:
		var cell: Vector2i = k
		_bubble(MapRules.center(cell.x, cell.y) * UNIT, grid[k], UNIT * 0.48)
	var base: Vector2 = MapRules.launcher(lose_row) * UNIT
	## Trayectoria mientras se apunta (hasta el primer rebote o el choque).
	if _aiming and not _flying:
		var t: Array = MapRules.trace(grid, lose_row, aim)
		var pts: PackedVector2Array = t[0]
		var shown: int = mini(pts.size(), 3)
		for i: int in shown - 1:
			var a: Vector2 = pts[i] * UNIT
			var b: Vector2 = pts[i + 1] * UNIT
			var n: int = int(a.distance_to(b) / 26.0)
			for j: int in n:
				_board.draw_circle(a.lerp(b, float(j) / float(maxi(n, 1))), 4.0, Color(1, 1, 1, 0.55))
	if _flying:
		_bubble(_fly_pos * UNIT, current, UNIT * 0.48)
	else:
		_bubble(base, current, UNIT * 0.48)
	_bubble(base + Vector2(UNIT * 1.4, UNIT * 0.3), upcoming, UNIT * 0.32)
