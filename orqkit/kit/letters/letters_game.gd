extends Node2D
## Palabras con letras (estilo Wordscapes): une letras de la rueda deslizando el dedo para formar
## palabras y rellenar el crucigrama. Las que existen pero no estan en el crucigrama son extra.
## Reglas, crucigrama, bot y analizador en letters_map.gd; diccionarios en kit/words.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel al acabar.

const M = preload("res://kit/letters/letters_map.gd")
const WHEEL_R: float = 170.0

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
## Letras elegidas en la rueda (indices) mientras se arrastra.
var path: Array[int] = []

var _font: Font
var _board: Control
var _wheel: Control
var _word_lbl: Label
var _bonus_lbl: Label
var _hint_btn: Button
var _dragging: bool = false
var _finger: Vector2 = Vector2.ZERO
var _flash: Dictionary = {}
var _t: float = 0.0


func _ready() -> void:
	level = Kit.current_level()
	RenderingServer.set_default_clear_color(Color("#1d2b3a"))
	_font = UI.theme.get_font("font", "Label") if UI.theme != null else ThemeDB.fallback_font
	_build_hud()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "letters", "words": coins_total, "lang": str(st["lang"])})


func bot_script() -> String:
	return "res://qa/letters_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(2.5, 1.0)


func _reset() -> void:
	finished = false
	failed = false
	st = M.new_state(level, Kit.lang(), deaths)
	coins_total = (st["b"].get("words", []) as Array).size()
	coins = 0
	time_in_level = 0.0
	path.clear()
	_flash.clear()
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
	col.add_theme_constant_override("separation", 8)
	safe.add_child(col)
	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top)
	_bonus_lbl = Label.new()
	_bonus_lbl.name = "Bonus"
	_bonus_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bonus_lbl.add_theme_font_size_override("font_size", 28)
	top.add_child(_bonus_lbl)
	_hint_btn = UI.make_button("", false, "star")
	_hint_btn.name = "BtnHint"
	_hint_btn.pressed.connect(use_hint)
	top.add_child(_hint_btn)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)
	_board = Control.new()
	_board.name = "Board"
	_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.draw.connect(_draw_board)
	col.add_child(_board)
	_word_lbl = Label.new()
	_word_lbl.name = "Word"
	_word_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_word_lbl.add_theme_font_size_override("font_size", 44)
	_word_lbl.custom_minimum_size = Vector2(0.0, 60.0)
	col.add_child(_word_lbl)
	var low: HBoxContainer = HBoxContainer.new()
	low.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(low)
	var shuffle_btn: Button = UI.make_button(Kit.text("lt_shuffle", "Barajar"), false, "")
	shuffle_btn.name = "BtnShuffle"
	shuffle_btn.pressed.connect(shuffle)
	low.add_child(shuffle_btn)
	_wheel = Control.new()
	_wheel.name = "Wheel"
	_wheel.custom_minimum_size = Vector2(0.0, WHEEL_R * 2.0 + 80.0)
	_wheel.mouse_filter = Control.MOUSE_FILTER_STOP
	_wheel.draw.connect(_draw_wheel)
	_wheel.gui_input.connect(_on_wheel_input)
	col.add_child(_wheel)


# ------------------------------------------------------------------ acciones

func can_act() -> bool:
	return not finished and is_inside_tree() and not get_tree().paused and not (st.get("b", {}) as Dictionary).is_empty()


func letters() -> Array:
	return st["b"].get("letters", [])


## Palabra de las letras elegidas.
func current() -> String:
	var w: String = ""
	for i: int in path:
		w += str(letters()[i])
	return w


## Envia una palabra (la rueda o el bot). Devuelve lo que fue: word, bonus, again o "".
func send(w: String) -> String:
	if not can_act():
		return ""
	var r: String = M.submit(st, w)
	match r:
		"word":
			_flash[w] = 0.6
			coins = (st["found"] as Dictionary).size()
			_sfx("coin", -4.0)
		"bonus":
			Save.add_wallet(1)
			_word_lbl.text = "+1  " + w
			_sfx("powerup", -10.0)
		"again":
			_sfx("click", -12.0)
		_:
			_sfx("hurt", -12.0)
	_refresh()
	if bool(st["won"]):
		_finish()
	return r


func shuffle() -> void:
	if not can_act():
		return
	var l: Array = letters()
	for i: int in range(l.size() - 1, 0, -1):
		var j: int = randi() % (i + 1)
		var tmp: Variant = l[i]
		l[i] = l[j]
		l[j] = tmp
	_sfx("click", -10.0)
	_wheel.queue_redraw()


func use_hint() -> void:
	if not can_act():
		return
	var c: Vector2i = M.hint(st)
	if c.x != -999:
		_sfx("powerup", -8.0)
	_refresh()


func bot_step() -> void:
	if not can_act():
		return
	var w: String = M.bot_word(st)
	if w != "":
		send(w)


func _sfx(n: String, vol: float = -6.0) -> void:
	if not fast:
		Audio.play(n, 0.1, vol)


func _refresh() -> void:
	if _board == null or st.is_empty():
		return
	_bonus_lbl.text = Kit.text("lt_bonus", "Extra: {n}").format({"n": (st["bonus"] as Dictionary).size()}) + "   %d/%d" % [coins, coins_total]
	_hint_btn.text = "    " + Kit.text("lt_hint", "Pista") + " %d" % int(st["hints"])
	_hint_btn.disabled = int(st["hints"]) <= 0 or finished
	_board.queue_redraw()
	_wheel.queue_redraw()


# ------------------------------------------------------------------ bucle y entrada

func _physics_process(delta: float) -> void:
	_t += delta
	for w: Variant in _flash.keys():
		_flash[w] = float(_flash[w]) - delta
		if float(_flash[w]) <= 0.0:
			_flash.erase(w)
	if not finished:
		time_in_level += delta
	if fast and auto_retry and can_act():
		bot_step()
	if not _flash.is_empty():
		_board.queue_redraw()


func _letter_pos(i: int) -> Vector2:
	var n: int = maxi(1, letters().size())
	var c: Vector2 = _wheel.size * 0.5
	var a: float = -PI * 0.5 + TAU * float(i) / float(n)
	return c + Vector2(cos(a), sin(a)) * WHEEL_R * 0.72


func _letter_at(p: Vector2) -> int:
	for i: int in letters().size():
		if _letter_pos(i).distance_to(p) < 52.0:
			return i
	return -1


func _on_wheel_input(event: InputEvent) -> void:
	if not can_act():
		return
	var p: Vector2 = Vector2.INF
	var down: bool = false
	var up: bool = false
	if event is InputEventScreenTouch:
		p = (event as InputEventScreenTouch).position
		down = (event as InputEventScreenTouch).pressed
		up = not down
	elif event is InputEventScreenDrag:
		p = (event as InputEventScreenDrag).position
	elif event is InputEventMouseButton and not DisplayServer.is_touchscreen_available():
		p = (event as InputEventMouseButton).position
		down = (event as InputEventMouseButton).pressed
		up = not down
	elif event is InputEventMouseMotion and _dragging and not DisplayServer.is_touchscreen_available():
		p = (event as InputEventMouseMotion).position
	if p == Vector2.INF:
		return
	_finger = p
	if down:
		path.clear()
		_dragging = true
	if _dragging:
		var i: int = _letter_at(p)
		if i >= 0:
			if path.size() >= 2 and path[path.size() - 2] == i:
				path.pop_back()
			elif not path.has(i):
				path.append(i)
				_sfx("click", -16.0)
		_word_lbl.text = current()
	if up and _dragging:
		_dragging = false
		if path.size() >= 3:
			send(current())
		elif path.size() > 0:
			_word_lbl.text = ""
		path.clear()
	_wheel.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()


# ------------------------------------------------------------------ dibujo

func _draw_board() -> void:
	var b: Dictionary = st.get("b", {})
	if b.is_empty():
		return
	var grid: Dictionary = b["grid"]
	var lo: Vector2i = Vector2i(9999, 9999)
	var hi: Vector2i = Vector2i(-9999, -9999)
	for c: Vector2i in grid:
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	var cols: int = hi.x - lo.x + 1
	var rows: int = hi.y - lo.y + 1
	var sz: Vector2 = _board.size
	var cell: float = minf(minf((sz.x - 20.0) / float(cols), (sz.y - 20.0) / float(rows)), 86.0)
	var o: Vector2 = (sz - Vector2(cols, rows) * cell) * 0.5
	var vis: Dictionary = M.shown(st)
	var flash_cells: Dictionary = {}
	for w: Variant in _flash:
		var pl: Array = b["place"][w]
		for i: int in str(w).length():
			flash_cells[(pl[0] as Vector2i) + (pl[1] as Vector2i) * i] = float(_flash[w])
	var fs: int = int(cell * 0.6)
	for c2: Vector2i in grid:
		var r: Rect2 = Rect2(o + Vector2(c2 - lo) * cell + Vector2(3, 3), Vector2(cell - 6, cell - 6))
		if flash_cells.has(c2):
			r = r.grow(float(flash_cells[c2]) * 8.0)
		var on: bool = vis.has(c2)
		_board.draw_rect(r, Color("#ff9f43") if on else Color("#f3ead8"))
		if on:
			var ch: String = str(grid[c2])
			var tw: float = _font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			_board.draw_string(_font, r.get_center() + Vector2(-tw * 0.5, fs * 0.36), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


func _draw_wheel() -> void:
	if (st.get("b", {}) as Dictionary).is_empty():
		return
	var c: Vector2 = _wheel.size * 0.5
	_wheel.draw_circle(c, WHEEL_R, Color(1, 1, 1, 0.12))
	## Linea de las letras elegidas (y hasta el dedo).
	for k: int in range(1, path.size()):
		_wheel.draw_line(_letter_pos(path[k - 1]), _letter_pos(path[k]), Color("#ff9f43"), 14.0)
	if _dragging and not path.is_empty():
		_wheel.draw_line(_letter_pos(path[path.size() - 1]), _finger, Color(1.0, 0.62, 0.26, 0.6), 10.0)
	var fs: int = 52
	for i: int in letters().size():
		var p: Vector2 = _letter_pos(i)
		var sel: bool = path.has(i)
		_wheel.draw_circle(p, 46.0, Color("#ff9f43") if sel else Color("#f3ead8"))
		var ch: String = str(letters()[i])
		var tw: float = _font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		_wheel.draw_string(_font, p + Vector2(-tw * 0.5, fs * 0.36), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE if sel else Color("#3a2e24"))


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = coins_total * 100 + (st["bonus"] as Dictionary).size() * 50 + int(st["hints"]) * 100
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "bonus": (st["bonus"] as Dictionary).size(), "time": snappedf(time_in_level, 0.1)})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


## Estrellas por pistas: sin pistas, 3; con una, 2; con mas, 1.
func stars_earned() -> int:
	var used: int = 3 - int(st["hints"])
	return 3 if used == 0 else (2 if used == 1 else 1)


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
	return {"deaths": deaths, "coins": coins, "finished": finished, "failed": failed, "stomps": 0, "time": time_in_level,
		"found": coins, "bonus": (st.get("bonus", {}) as Dictionary).size()}
