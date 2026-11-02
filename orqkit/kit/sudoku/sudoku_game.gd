extends Node2D
## Sudoku: toca una casilla vacia y luego un numero del teclado de abajo.
## Reglas, resolutor, bot y analizador en sudoku_map.gd.
## 1 - Se iluminan la fila, la columna y la caja de la casilla elegida, y los numeros iguales.
## 2 - Un numero equivocado se marca en rojo y quita una vida. Pista: rellena una casilla.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const MapRules = preload("res://kit/sudoku/sudoku_map.gd")

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
var sel: Vector2i = Vector2i(-1, -1)

var _font: Font
var _world: Node2D
var _camera: Camera2D
var _hearts: HBoxContainer
var _time_label: Label
var _pad: HBoxContainer
var _cell: float = 70.0
var _origin: Vector2 = Vector2.ZERO
var _wrong: Dictionary = {}
var _pop: Dictionary = {}
var _t: float = 0.0


func _ready() -> void:
	level = Kit.current_level()
	par = float(level.get("par", 0))
	RenderingServer.set_default_clear_color(Color("#e9edf5"))
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
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "sudoku", "size": int(st["n"])})


func bot_script() -> String:
	return "res://qa/sudoku_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(2.0, 1.0)


func wants_grade() -> bool:
	return false


func _reset() -> void:
	finished = false
	failed = false
	st = MapRules.new_state(level)
	var n: int = maxi(1, int(st["n"]))
	coins_total = n * n - (st["given"] as Dictionary).size()
	coins = 0
	time_in_level = 0.0
	sel = Vector2i(-1, -1)
	_wrong.clear()
	_pop.clear()
	_cell = minf(104.0, 660.0 / float(n))
	_origin = Vector2(360.0, 600.0) - Vector2(n, n) * _cell * 0.5
	_fill_pad()
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
	_hearts = HBoxContainer.new()
	_hearts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_hearts)
	var gap: Control = Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(gap)
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
	var hint: Button = UI.make_button(Kit.text("sdk_hint", "Pista"))
	hint.name = "BtnHint"
	hint.custom_minimum_size = Vector2(220, UI.MIN_TOUCH)
	hint.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hint.pressed.connect(use_hint)
	col.add_child(hint)
	_pad = HBoxContainer.new()
	_pad.name = "Pad"
	_pad.alignment = BoxContainer.ALIGNMENT_CENTER
	_pad.add_theme_constant_override("separation", 6)
	col.add_child(_pad)


func _fill_pad() -> void:
	for c: Node in _pad.get_children():
		c.queue_free()
	var n: int = int(st["n"])
	for v: int in range(1, n + 1):
		var b: Button = UI.make_button(str(v))
		b.name = "Num_%d" % v
		b.custom_minimum_size = Vector2(minf(120.0, 640.0 / float(n)), 96)
		b.add_theme_font_size_override("font_size", 40)
		b.pressed.connect(press_number.bind(v))
		_pad.add_child(b)


func _refresh() -> void:
	if _time_label == null or st.is_empty():
		return
	var s: int = int(time_in_level)
	_time_label.text = "%d:%02d" % [s / 60, s % 60]
	var lives: int = int(st["lives"])
	if _hearts.get_child_count() != lives:
		for c: Node in _hearts.get_children():
			c.queue_free()
		for i: int in lives:
			_hearts.add_child(UiIcon.make("heart", Color("#ff5a6a"), 40.0))
	for i: int in _hearts.get_child_count():
		(_hearts.get_child(i) as Control).modulate = Color(1, 1, 1, 0.25) if i >= lives - int(st["mistakes"]) else Color.WHITE
	var n: int = int(st["n"])
	var filled: int = 0
	var count: Dictionary = {}
	for y: int in n:
		for x: int in n:
			var v: int = int(st["grid"][y][x])
			if v != 0:
				count[v] = int(count.get(v, 0)) + 1
				if not (st["given"] as Dictionary).has(Vector2i(x, y)):
					filled += 1
	coins = filled
	## Los numeros ya completos se apagan en el teclado.
	for b: Node in _pad.get_children():
		var v2: int = int(str(b.name).trim_prefix("Num_"))
		(b as Button).disabled = int(count.get(v2, 0)) >= n


# ------------------------------------------------------------------ acciones

func can_act() -> bool:
	return not finished and is_inside_tree() and not get_tree().paused


func tap_world(p: Vector2) -> void:
	if not can_act():
		return
	var n: int = int(st["n"])
	var c: Vector2i = Vector2i(floori((p.x - _origin.x) / _cell), floori((p.y - _origin.y) / _cell))
	if c.x >= 0 and c.y >= 0 and c.x < n and c.y < n:
		sel = c
		_sfx("click")


func press_number(v: int) -> void:
	if not can_act() or sel.x < 0 or int(st["grid"][sel.y][sel.x]) != 0:
		return
	if MapRules.put(st, sel.x, sel.y, v):
		_pop[sel] = 0.35
		_sfx("coin")
	else:
		if (st["given"] as Dictionary).has(sel):
			return
		_wrong[sel] = [v, 0.8]
		if not fast:
			Audio.play("hurt", 0.05, -6.0)
	_refresh()
	if MapRules.solved(st):
		_finish()
	elif MapRules.lost(st):
		_lose()


func use_hint() -> void:
	if not can_act():
		return
	var m: Array = MapRules.next_move(st)
	if m.is_empty():
		return
	st["hints"] = int(st["hints"]) + 1
	sel = Vector2i(int(m[0]), int(m[1]))
	press_number(int(m[2]))


func _sfx(n: String) -> void:
	if not fast:
		Audio.play(n, 0.1, -6.0)


func bot_step() -> void:
	if not can_act():
		return
	var m: Array = MapRules.next_move(st)
	if m.is_empty():
		return
	sel = Vector2i(int(m[0]), int(m[1]))
	press_number(int(m[2]))


# ------------------------------------------------------------------ bucle

func _physics_process(delta: float) -> void:
	_t += delta
	for k: Variant in _wrong.keys():
		_wrong[k][1] = float(_wrong[k][1]) - delta
		if float(_wrong[k][1]) <= 0.0:
			_wrong.erase(k)
	for k: Variant in _pop.keys():
		_pop[k] = float(_pop[k]) - delta
		if float(_pop[k]) <= 0.0:
			_pop.erase(k)
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
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		tap_world(get_canvas_transform().affine_inverse() * (event as InputEventScreenTouch).position)


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = coins_total * 50 + maxi(0, int(par * 1.4 - time_in_level)) * 10 - int(st["mistakes"]) * 100 - int(st["hints"]) * 80
	var record: bool = Save.submit_best(level_id, maxi(0, score))
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "time": snappedf(time_in_level, 0.1), "deaths": deaths,
		"mistakes": int(st["mistakes"]), "hints": int(st["hints"])})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": maxi(0, score), "record": record})
	await Ads.show_interstitial("level_end")


func stars_earned() -> int:
	if deaths > 0:
		return 1
	if int(st["mistakes"]) == 0 and int(st["hints"]) <= 1:
		return 3
	return 2


func _lose() -> void:
	if finished:
		return
	finished = true
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "sudoku", "mistakes": int(st["mistakes"]), "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("sdk_lost", "\u00a1Demasiados fallos!"),
		Kit.text("sdk_fail_hint", "Busca la casilla con menos opciones: mira su fila, su columna y su caja antes de poner un n\u00famero."))
	p.closed.connect(retry)


## Segunda oportunidad (FailPanel, con anuncio): una vida mas y se sigue donde ibas.
func revive() -> void:
	st["mistakes"] = maxi(0, int(st["mistakes"]) - 1)
	finished = false
	failed = false
	_refresh()


func revive_text() -> String:
	return Kit.text("revive_life", "Una vida m\u00e1s")


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
	return {"pos": Vector2(float(coins), float(st.get("mistakes", 0))), "deaths": deaths, "coins": coins, "finished": finished,
		"failed": failed, "stomps": 0, "time": time_in_level, "mistakes": int(st.get("mistakes", 0))}


# ------------------------------------------------------------------ dibujo

func _draw_world() -> void:
	if st.is_empty() or int(st["n"]) == 0:
		return
	var n: int = int(st["n"])
	var b: Vector2i = MapRules.box_of(n)
	var board: Rect2 = Rect2(_origin, Vector2(n, n) * _cell)
	_world.draw_rect(board.grow(14.0), Color(0.2, 0.25, 0.4, 0.18))
	_world.draw_rect(board, Color("#ffffff"))
	var sel_v: int = int(st["grid"][sel.y][sel.x]) if sel.x >= 0 else 0
	for y: int in n:
		for x: int in n:
			var r: Rect2 = Rect2(_origin + Vector2(x, y) * _cell, Vector2(_cell, _cell))
			var c: Vector2i = Vector2i(x, y)
			var v: int = int(st["grid"][y][x])
			if (x / b.x + y / b.y) % 2 == 1:
				_world.draw_rect(r, Color("#f3f5fa"))
			if sel.x >= 0 and (x == sel.x or y == sel.y or (x / b.x == sel.x / b.x and y / b.y == sel.y / b.y)):
				_world.draw_rect(r, Color("#dfe8ff"))
			if sel_v != 0 and v == sel_v:
				_world.draw_rect(r, Color("#c4d6ff"))
			if c == sel:
				_world.draw_rect(r, Color("#a8c2ff"))
			if _pop.has(c):
				_world.draw_rect(r.grow(-_cell * 0.1), Color(0.5, 0.9, 0.6, float(_pop[c]) * 1.6))
			var txt: String = ""
			var col: Color = Color("#22304a")
			if v != 0:
				txt = str(v)
				if not (st["given"] as Dictionary).has(c):
					col = Color("#2f62d8")
			elif _wrong.has(c):
				txt = str(_wrong[c][0])
				col = Color(0.9, 0.2, 0.25, clampf(float(_wrong[c][1]) * 2.0, 0.0, 1.0))
			if txt != "":
				var fs: int = int(_cell * 0.6)
				var wd: float = _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				_world.draw_string(_font, r.get_center() + Vector2(-wd * 0.5, fs * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	for i: int in n + 1:
		var thick: bool = i % b.x == 0
		_world.draw_line(_origin + Vector2(float(i) * _cell, 0), _origin + Vector2(float(i) * _cell, float(n) * _cell),
			Color("#22304a") if thick else Color("#b8c0d0"), 4.0 if thick else 1.5)
	for i: int in n + 1:
		var thick2: bool = i % b.y == 0
		_world.draw_line(_origin + Vector2(0, float(i) * _cell), _origin + Vector2(float(n) * _cell, float(i) * _cell),
			Color("#22304a") if thick2 else Color("#b8c0d0"), 4.0 if thick2 else 1.5)
