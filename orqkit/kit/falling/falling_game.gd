extends Node2D
## Bloques que caen: desliza a los lados para mover, toca para girar y desliza hacia abajo para
## soltar de golpe (tambien hay botones). Borra las filas que pide el nivel.
## Reglas, bolsa de piezas, bot y analizador en falling_map.gd.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const REVIVE_ROWS: int = 6
const MapRules = preload("res://kit/falling/falling_map.gd")
const Rules = preload("res://kit/rules.gd")
const CELL: float = 46.0
const ORIGIN: Vector2 = Vector2(360.0 - 5.0 * CELL - 70.0, 190.0)
const COLORS: Dictionary = {"I": Color("#3fd0e0"), "O": Color("#f2c84b"), "T": Color("#a46ad9"), "S": Color("#56c46a"),
	"Z": Color("#e8483e"), "J": Color("#3f6ad8"), "L": Color("#ff8a2a"), "G": Color("#6a7080"), "X": Color.WHITE}

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
var par: float = 0.0

var _font: Font
var _world: Node2D
var _camera: Camera2D
var _info: Label
var _touch: Vector2 = Vector2.INF
var _moved: float = 0.0
var _dragged: bool = false
var _flash: Array = []
var _flash_t: float = 0.0
var _bot_cd: float = 0.0
var _target: Array = []
var _last_piece: int = -1
var _t: float = 0.0
var _rule_cols: Dictionary = {}


func _ready() -> void:
	level = Kit.current_level()
	par = float(level.get("par", 60))
	RenderingServer.set_default_clear_color(Color("#141a2a"))
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
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "falling", "lines": int(st["goal"])})


func bot_script() -> String:
	return "res://qa/falling_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(6.0, 2.0)


func wants_backdrop() -> bool:
	return false


func _reset() -> void:
	finished = false
	failed = false
	st = MapRules.new_state(level)
	_rule_cols = Rules.colors(st)
	coins_total = int(st["goal"])
	coins = 0
	time_in_level = 0.0
	_flash = []
	_last_piece = -1
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
	_info = Label.new()
	_info.name = "Info"
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.add_theme_font_size_override("font_size", 32)
	_info.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_info.add_theme_constant_override("outline_size", 6)
	top.add_child(_info)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(spacer)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	for b: Array in [["<", func() -> void: _act(-1, 0)], [Kit.text("fall_rotate", "Girar"), func() -> void: _act(0, 1)], [">", func() -> void: _act(1, 0)],
			[Kit.text("fall_drop", "Soltar"), func() -> void: _drop()]]:
		var btn: Button = UI.make_button(str(b[0]))
		btn.custom_minimum_size = Vector2(150, 92)
		btn.add_theme_font_size_override("font_size", 30)
		btn.pressed.connect(b[1])
		row.add_child(btn)


func _refresh() -> void:
	if _info == null or st.is_empty():
		return
	## Musica: cuanto mas alta la pila, mas tension.
	var top: int = MapRules.H
	for y: int in MapRules.H:
		if (st["grid"][y] as Array).any(func(c: Variant) -> bool: return str(c) != ""):
			top = y
			break
	Audio.set_intensity(lerpf(0.55, 1.0, clampf(1.0 - float(top) / float(MapRules.H), 0.0, 1.0) * 1.6))
	coins = mini(int(st["lines"]), coins_total)
	_info.text = "%s %d/%d   %d" % [Kit.text("fall_lines", "Filas"), int(st["lines"]), int(st["goal"]), int(st["score"])]


# ------------------------------------------------------------------ acciones

func can_act() -> bool:
	return not finished and is_inside_tree() and not get_tree().paused and not (st["piece"] as Dictionary).is_empty()


func _act(dx: int, drot: int) -> void:
	if can_act() and MapRules.try_move(st, dx, drot):
		_sfx("click")


func _drop() -> void:
	if not can_act():
		return
	_cleared(MapRules.hard_drop(st))


func _cleared(n: int) -> void:
	if n > 0:
		_flash_t = 0.25
		_sfx("coin")
	_refresh()
	if bool(st["won"]):
		_finish()
	elif bool(st["over"]):
		_lose()


func _sfx(n: String) -> void:
	if not fast:
		Audio.play(n, 0.1, -12.0)


func bot_step() -> void:
	if not can_act():
		return
	if int(st["pieces"]) != _last_piece:
		_last_piece = int(st["pieces"])
		_target = MapRules.best_place(st)
	var pieces: int = int(st["pieces"])
	var lines: int = int(st["lines"])
	MapRules.bot_act(st, _target)
	if int(st["pieces"]) != pieces:
		_cleared(int(st["lines"]) - lines)


# ------------------------------------------------------------------ bucle

func _physics_process(delta: float) -> void:
	_t += delta
	_flash_t = maxf(0.0, _flash_t - delta)
	if finished:
		_world.queue_redraw()
		return
	var steps: int = 4 if fast else 1
	for k: int in steps:
		if fast and auto_retry:
			bot_step()
		if finished:
			break
		var n: int = MapRules.step(st, delta)
		if n > 0 or bool(st["over"]) or bool(st["won"]):
			_cleared(n)
	time_in_level += delta * float(steps)
	_world.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()
		return
	var inv: Transform2D = get_canvas_transform().affine_inverse()
	if event is InputEventScreenTouch:
		var te: InputEventScreenTouch = event
		var p: Vector2 = inv * te.position
		if te.pressed:
			if p.y > 1150.0:
				return
			_touch = p
			_moved = 0.0
			_dragged = false
		elif _touch != Vector2.INF:
			if not _dragged:
				_act(0, 1)
			_touch = Vector2.INF
	elif event is InputEventScreenDrag and _touch != Vector2.INF:
		var dr: InputEventScreenDrag = event
		var rel: Vector2 = inv.basis_xform(dr.relative)
		if rel.y > 28.0 and absf(rel.y) > absf(rel.x) * 1.5:
			_dragged = true
			_drop()
			_touch = Vector2.INF
			return
		_moved += rel.x
		while absf(_moved) >= CELL * 0.8:
			_dragged = true
			_act(int(signf(_moved)), 0)
			_moved -= signf(_moved) * CELL * 0.8


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	coins = coins_total
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = int(st["score"])
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
	return 3 if par <= 0.0 or time_in_level <= par * 1.6 else 2


func _lose() -> void:
	if finished:
		return
	finished = true
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "top", "lines": int(st["lines"]), "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("fall_lost", "\u00a1Lleg\u00f3 arriba!"),
		Kit.text("fall_fail_hint", "Deja el tablero lo m\u00e1s plano posible y guarda un hueco a un lado para la pieza larga."))
	p.closed.connect(retry)


## Segunda oportunidad (FailPanel, con anuncio): se vacian las filas de arriba y sigue cayendo.
func revive() -> void:
	MapRules.clear_top(st, REVIVE_ROWS)
	st["over"] = false
	MapRules.spawn(st)
	finished = false
	failed = false
	_refresh()


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
	return {"pos": Vector2(float(st.get("lines", 0)), float(st.get("pieces", 0))), "deaths": deaths, "coins": coins, "finished": finished,
		"failed": failed, "stomps": 0, "time": time_in_level, "lines": int(st.get("lines", 0))}


# ------------------------------------------------------------------ dibujo

func _block(r: Rect2, col: Color, alpha: float = 1.0) -> void:
	_world.draw_rect(r.grow(-1.0), col * Color(1, 1, 1, alpha))
	_world.draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(r.size.x - 2.0, 6)), col.lightened(0.35) * Color(1, 1, 1, alpha))
	_world.draw_rect(Rect2(r.position + Vector2(1, r.size.y - 7), Vector2(r.size.x - 2.0, 6)), col.darkened(0.3) * Color(1, 1, 1, alpha))


func _draw_world() -> void:
	if st.is_empty():
		return
	var well: Rect2 = Rect2(ORIGIN, Vector2(MapRules.W, MapRules.H) * CELL)
	_world.draw_rect(well.grow(8.0), Color("#3a4460"))
	_world.draw_rect(well, Color("#0c1020"))
	for x: int in MapRules.W + 1:
		_world.draw_line(ORIGIN + Vector2(float(x) * CELL, 0), ORIGIN + Vector2(float(x) * CELL, well.size.y), Color(1, 1, 1, 0.04), 1.0)
	for y: int in MapRules.H + 1:
		_world.draw_line(ORIGIN + Vector2(0, float(y) * CELL), ORIGIN + Vector2(well.size.x, float(y) * CELL), Color(1, 1, 1, 0.04), 1.0)
	var grid: Array = st["grid"]
	for y2: int in MapRules.H:
		for x2: int in MapRules.W:
			var ch: String = str(grid[y2][x2])
			if ch != "":
				_block(Rect2(ORIGIN + Vector2(x2, y2) * CELL, Vector2(CELL, CELL)), COLORS.get(ch, _rule_cols.get(ch, Color.GRAY)))
	var p: Dictionary = st["piece"]
	if not p.is_empty():
		## Sombra: donde caeria.
		var ghost: Vector2i = p["pos"]
		while MapRules.fits(st, p["kind"], int(p["rot"]), ghost + Vector2i(0, 1)):
			ghost += Vector2i(0, 1)
		for c: Vector2i in MapRules.cells(p["kind"], int(p["rot"])):
			var gq: Vector2i = ghost + c
			if gq.y >= 0:
				_world.draw_rect(Rect2(ORIGIN + Vector2(gq) * CELL, Vector2(CELL, CELL)).grow(-3.0), Color(1, 1, 1, 0.25), false, 2.0)
		for c2: Vector2i in MapRules.cells(p["kind"], int(p["rot"])):
			var q: Vector2i = (p["pos"] as Vector2i) + c2
			if q.y >= 0:
				_block(Rect2(ORIGIN + Vector2(q) * CELL, Vector2(CELL, CELL)), COLORS[p["kind"]])
	if _flash_t > 0.0:
		_world.draw_rect(well, Color(1, 1, 1, _flash_t * 1.2))
	## Siguiente pieza.
	var nx: Vector2 = Vector2(well.end.x + 24.0, ORIGIN.y)
	_world.draw_rect(Rect2(nx, Vector2(120, 120)), Color("#1e2640"))
	_world.draw_string(_font, nx + Vector2(10, -10), Kit.text("fall_next", "Siguiente"), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#9fb4cc"))
	for c3: Vector2i in MapRules.cells(st["next"], 0):
		_block(Rect2(nx + Vector2(14, 30) + Vector2(c3) * 24.0, Vector2(24, 24)), COLORS[st["next"]])
