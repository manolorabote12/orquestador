extends Node2D
## Sopa de letras: arrastra en linea recta sobre las palabras de la lista hasta encontrarlas todas.
## Reglas, cuadricula, bot y analizador en words_map.gd.
## 1 - Arrastra de la primera letra a la ultima (en cualquiera de las direcciones del nivel).
## 2 - Cada palabra encontrada se pinta de un color y se tacha en la lista de abajo.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel al acabar.

const MapRules = preload("res://kit/words/words_map.gd")
const MARKS: Array[Color] = [Color("#ff8a5a"), Color("#5ab8ff"), Color("#7ad95a"), Color("#d98aff"), Color("#ffd23f"),
	Color("#5ae0c8"), Color("#ff6f9a"), Color("#a0a8ff")]
const TOP: float = 196.0

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
var _count_label: Label
var _time_label: Label
var _list: HFlowContainer
var _cell: float = 64.0
var _origin: Vector2 = Vector2.ZERO
var _drag_a: Vector2i = Vector2i(-1, -1)
var _drag_b: Vector2i = Vector2i(-1, -1)
var _flash: Dictionary = {}
var _t: float = 0.0


func _ready() -> void:
	level = Kit.current_level()
	par = float(level.get("par", 0))
	RenderingServer.set_default_clear_color(Color("#24324a"))
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
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "words", "words": (st["words"] as Array).size()})


func bot_script() -> String:
	return "res://qa/words_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(1.3, 0.8)


func wants_grade() -> bool:
	return false


func _reset() -> void:
	finished = false
	failed = false
	st = MapRules.new_state(level)
	coins_total = (st["words"] as Array).size()
	coins = 0
	time_in_level = 0.0
	_drag_a = Vector2i(-1, -1)
	_flash.clear()
	var n: int = maxi(1, int(st["size"]))
	_cell = minf(100.0, 664.0 / float(n))
	_origin = Vector2(360.0 - _cell * float(n) * 0.5, maxf(TOP, 600.0 - _cell * float(n) * 0.5))
	_fill_list()
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
	top.add_theme_constant_override("separation", 10)
	col.add_child(top)
	top.add_child(UiIcon.make("star", Color("#ffd23f"), 40.0))
	_count_label = Label.new()
	_count_label.name = "Count"
	_count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_count_label.add_theme_font_size_override("font_size", 34)
	_count_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_count_label.add_theme_constant_override("outline_size", 7)
	top.add_child(_count_label)
	_time_label = Label.new()
	_time_label.name = "Time"
	_time_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_time_label.add_theme_constant_override("outline_size", 6)
	top.add_child(_time_label)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(spacer)
	var panel: PanelContainer = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.35)
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)
	col.add_child(panel)
	_list = HFlowContainer.new()
	_list.name = "WordList"
	_list.alignment = FlowContainer.ALIGNMENT_CENTER
	_list.add_theme_constant_override("h_separation", 22)
	_list.add_theme_constant_override("v_separation", 6)
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_list)


func _fill_list() -> void:
	for c: Node in _list.get_children():
		c.queue_free()
	for w: Variant in st["words"]:
		var l: Label = Label.new()
		l.name = "W_" + str(w)
		l.text = str(w)
		l.add_theme_font_size_override("font_size", 36)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		l.add_theme_constant_override("outline_size", 5)
		_list.add_child(l)


func _refresh() -> void:
	if _count_label == null or st.is_empty():
		return
	coins = (st["found"] as Dictionary).size()
	_count_label.text = "%d / %d" % [coins, coins_total]
	var s: int = int(time_in_level)
	_time_label.text = "%d:%02d" % [s / 60, s % 60]
	for w: Variant in st["words"]:
		var l: Node = _list.get_node_or_null("W_" + str(w))
		if l != null:
			var found: bool = (st["found"] as Dictionary).has(w)
			(l as Label).modulate = MARKS[int(st["found"].get(w, 0)) % MARKS.size()].lightened(0.3) * Color(1, 1, 1, 0.55) if found else Color.WHITE


# ------------------------------------------------------------------ acciones

func can_act() -> bool:
	return not finished and is_inside_tree() and not get_tree().paused


func cell_at(p: Vector2) -> Vector2i:
	var c: Vector2i = Vector2i(floori((p.x - _origin.x) / _cell), floori((p.y - _origin.y) / _cell))
	var n: int = int(st["size"])
	return Vector2i(clampi(c.x, 0, n - 1), clampi(c.y, 0, n - 1))


func inside(p: Vector2) -> bool:
	var n: float = float(st["size"]) * _cell
	return Rect2(_origin, Vector2(n, n)).grow(_cell * 0.3).has_point(p)


## Lleva el final del arrastre a la recta (de 8) mas cercana.
func snap(a: Vector2i, b: Vector2i) -> Vector2i:
	var d: Vector2 = Vector2(b - a)
	if d.length() < 0.5:
		return a
	var ang: float = snappedf(d.angle(), PI / 4.0)
	var u: Vector2i = Vector2i(roundi(cos(ang)), roundi(sin(ang)))
	var steps: int = maxi(absi(b.x - a.x), absi(b.y - a.y))
	var n: int = int(st["size"])
	var e: Vector2i = a + u * steps
	while steps > 0 and (e.x < 0 or e.y < 0 or e.x >= n or e.y >= n):
		steps -= 1
		e = a + u * steps
	return e


## Suelta una seleccion de a a b: true si era una palabra.
func select_line(a: Vector2i, b: Vector2i) -> bool:
	var w: String = MapRules.check(st, a, b)
	if w == "":
		st["misses"] = int(st["misses"]) + 1
		return false
	st["found"][w] = (st["found"] as Dictionary).size()
	_flash[w] = 0.5
	_sfx("coin")
	_refresh()
	if (st["found"] as Dictionary).size() >= (st["words"] as Array).size():
		_finish()
	return true


func _sfx(n: String) -> void:
	if not fast:
		Audio.play(n, 0.1, -6.0)


func bot_step() -> void:
	if not can_act():
		return
	for w: Variant in st["place"]:
		if not (st["found"] as Dictionary).has(w):
			var pl: Array = st["place"][w]
			var e: Vector2i = (pl[0] as Vector2i) + (pl[1] as Vector2i) * (str(w).length() - 1)
			select_line(pl[0], e)
			return


# ------------------------------------------------------------------ bucle

func _physics_process(delta: float) -> void:
	_t += delta
	for w: Variant in _flash.keys():
		_flash[w] = float(_flash[w]) - delta
		if float(_flash[w]) <= 0.0:
			_flash.erase(w)
	if finished:
		_world.queue_redraw()
		return
	if fast and auto_retry:
		bot_step()
	time_in_level += delta * (4.0 if fast else 1.0)
	_refresh()
	_world.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()
		return
	if not can_act():
		return
	var inv: Transform2D = get_canvas_transform().affine_inverse()
	if event is InputEventScreenTouch:
		var te: InputEventScreenTouch = event
		var p: Vector2 = inv * te.position
		if te.pressed and inside(p):
			_drag_a = cell_at(p)
			_drag_b = _drag_a
		elif not te.pressed and _drag_a.x >= 0:
			if _drag_b != _drag_a:
				select_line(_drag_a, _drag_b)
			_drag_a = Vector2i(-1, -1)
	elif event is InputEventScreenDrag and _drag_a.x >= 0:
		_drag_b = snap(_drag_a, cell_at(inv * (event as InputEventScreenDrag).position))


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = coins_total * 100 + maxi(0, int(par * 1.4 - time_in_level)) * 20 - int(st["misses"]) * 10
	var record: bool = Save.submit_best(level_id, maxi(0, score))
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "time": snappedf(time_in_level, 0.1), "deaths": deaths})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": maxi(0, score), "record": record})
	await Ads.show_interstitial("level_end")


func stars_earned() -> int:
	if par <= 0.0 or time_in_level <= par * 1.4:
		return 3
	return 2 if time_in_level <= par * 2.5 else 1


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
	return {"pos": Vector2(float(coins), float(st.get("misses", 0))), "deaths": deaths, "coins": coins, "finished": finished,
		"failed": failed, "stomps": 0, "time": time_in_level, "found": coins}


# ------------------------------------------------------------------ dibujo

func _capsule(a: Vector2i, b: Vector2i, col: Color, width: float) -> void:
	var pa: Vector2 = _origin + (Vector2(a) + Vector2(0.5, 0.5)) * _cell
	var pb: Vector2 = _origin + (Vector2(b) + Vector2(0.5, 0.5)) * _cell
	_world.draw_line(pa, pb, col, width)
	_world.draw_circle(pa, width * 0.5, col)
	_world.draw_circle(pb, width * 0.5, col)


func _draw_world() -> void:
	if st.is_empty() or int(st["size"]) == 0:
		return
	var n: int = int(st["size"])
	var board: Rect2 = Rect2(_origin, Vector2(n, n) * _cell)
	_world.draw_rect(board.grow(18.0), Color(0, 0, 0, 0.25))
	_world.draw_rect(board.grow(12.0), Color("#f6efe0"))
	_world.draw_rect(board.grow(12.0), Color("#d8c8a8"), false, 3.0)
	## Palabras encontradas: una capsula de color debajo de las letras.
	for w: Variant in st["found"]:
		var pl: Array = st["place"][w]
		var e: Vector2i = (pl[0] as Vector2i) + (pl[1] as Vector2i) * (str(w).length() - 1)
		var col: Color = MARKS[int(st["found"][w]) % MARKS.size()]
		var grow: float = 1.0 + (float(_flash.get(w, 0.0)) * 0.6)
		_capsule(pl[0], e, Color(col.r, col.g, col.b, 0.55), _cell * 0.72 * grow)
	if _drag_a.x >= 0:
		_capsule(_drag_a, _drag_b, Color(0.3, 0.6, 1.0, 0.45), _cell * 0.78)
	var grid: Array = st["grid"]
	var fs: int = int(_cell * 0.56)
	for y: int in n:
		var row: String = grid[y]
		for x: int in n:
			var ch: String = row[x]
			var wd: Vector2 = _font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
			var c: Vector2 = _origin + (Vector2(x, y) + Vector2(0.5, 0.5)) * _cell
			_world.draw_string(_font, c + Vector2(-wd.x * 0.5, fs * 0.36), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#3a2e24"))
