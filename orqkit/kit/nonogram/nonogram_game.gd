extends Node2D
## Nonograma: pinta las casillas que dicen las pistas y aparece un dibujo de pixel art.
## Reglas, pistas, resolutor, bot y analizador en nonogram_map.gd.
## 1 - Toca o arrastra para pintar. Con el boton de la cruz, marcas las que sabes que van vacias.
## 2 - Pintar donde no va es un fallo (se queda la cruz). Al completar una fila o columna, el resto
##     se tacha solo. Al acabar se ve el dibujo en color.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const MapRules = preload("res://kit/nonogram/nonogram_map.gd")

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
var mode: int = 1

var _font: Font
var _world: Node2D
var _camera: Camera2D
var _hearts: HBoxContainer
var _time_label: Label
var _mode_btn: Button
var _cell: float = 50.0
var _origin: Vector2 = Vector2.ZERO
var _clue_w: float = 0.0
var _clue_h: float = 0.0
var _dragging: bool = false
var _flash: Dictionary = {}
var _reveal: float = 0.0
var _ink: Color = Color("#2f3a5a")
var _t: float = 0.0


func _ready() -> void:
	level = Kit.current_level()
	par = float(level.get("par", 0))
	RenderingServer.set_default_clear_color(Color("#f1ece2"))
	_font = UI.theme.get_font("font", "Label") if UI.theme != null else ThemeDB.fallback_font
	_ink = Kit.color("primary", Color("#2f3a5a")).darkened(0.2)
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
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "nonogram", "size": int(st["w"])})


func bot_script() -> String:
	return "res://qa/nonogram_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(2.6, 1.0)


func wants_grade() -> bool:
	return false


func _reset() -> void:
	finished = false
	failed = false
	st = MapRules.new_state(level)
	coins_total = int(st["total"])
	coins = 0
	time_in_level = 0.0
	mode = 1
	_flash.clear()
	_reveal = 0.0
	_layout()
	_refresh()


## 1 - Hueco para las pistas (las filas a la izquierda, las columnas arriba) y la rejilla.
func _layout() -> void:
	var w: int = maxi(1, int(st["w"]))
	var h: int = maxi(1, int(st["h"]))
	var max_r: int = 1
	var max_c: int = 1
	for r: Variant in st["clues"]["rows"]:
		max_r = maxi(max_r, (r as Array).size())
	for c: Variant in st["clues"]["cols"]:
		max_c = maxi(max_c, (c as Array).size())
	_cell = minf(84.0, minf(670.0 / (float(w) + float(max_r) * 0.55), 820.0 / (float(h) + float(max_c) * 0.6)))
	_clue_w = float(max_r) * _cell * 0.55
	_clue_h = float(max_c) * _cell * 0.6
	var total: Vector2 = Vector2(_clue_w + float(w) * _cell, _clue_h + float(h) * _cell)
	_origin = Vector2(360.0, 620.0) - total * 0.5 + Vector2(_clue_w, _clue_h)


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
	_mode_btn = UI.make_button("")
	_mode_btn.name = "BtnMode"
	_mode_btn.custom_minimum_size = Vector2(320, 92)
	_mode_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_mode_btn.pressed.connect(toggle_mode)
	col.add_child(_mode_btn)


func toggle_mode() -> void:
	mode = 2 if mode == 1 else 1
	_sfx("click")
	_refresh()


func _refresh() -> void:
	if _time_label == null or st.is_empty():
		return
	var s: int = int(time_in_level)
	_time_label.text = "%d:%02d" % [s / 60, s % 60]
	_mode_btn.text = Kit.text("nono_paint", "Modo: pintar") if mode == 1 else Kit.text("nono_cross", "Modo: cruz")
	var lives: int = int(st["lives"])
	if _hearts.get_child_count() != lives:
		for c: Node in _hearts.get_children():
			c.queue_free()
		for i: int in lives:
			_hearts.add_child(UiIcon.make("heart", Color("#ff5a6a"), 40.0))
	for i: int in _hearts.get_child_count():
		(_hearts.get_child(i) as Control).modulate = Color(1, 1, 1, 0.25) if i >= lives - int(st["mistakes"]) else Color.WHITE
	coins = int(st["painted"])


# ------------------------------------------------------------------ acciones

func can_act() -> bool:
	return not finished and is_inside_tree() and not get_tree().paused


func cell_at(p: Vector2) -> Vector2i:
	return Vector2i(floori((p.x - _origin.x) / _cell), floori((p.y - _origin.y) / _cell))


func tap_cell(c: Vector2i) -> void:
	if not can_act():
		return
	var r: String = MapRules.mark(st, c.x, c.y, mode)
	if r == "":
		return
	if r == "ok":
		_flash[c] = 0.25
		_sfx("click")
	else:
		_flash[c] = 0.6
		if not fast:
			Audio.play("hurt", 0.05, -6.0)
	MapRules.auto_cross(st)
	_refresh()
	if MapRules.won(st):
		_finish()
	elif MapRules.lost(st):
		_lose()


func _sfx(n: String) -> void:
	if not fast:
		Audio.play(n, 0.1, -10.0)


func bot_step() -> void:
	if not can_act():
		return
	var m: Array = MapRules.next_move(st)
	if m.is_empty():
		return
	mode = 1
	tap_cell(Vector2i(int(m[0]), int(m[1])))


# ------------------------------------------------------------------ bucle

func _physics_process(delta: float) -> void:
	_t += delta
	for k: Variant in _flash.keys():
		_flash[k] = float(_flash[k]) - delta
		if float(_flash[k]) <= 0.0:
			_flash.erase(k)
	if finished:
		_reveal = minf(1.0, _reveal + delta * 2.0)
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
	var inv: Transform2D = get_canvas_transform().affine_inverse()
	if event is InputEventScreenTouch:
		var te: InputEventScreenTouch = event
		_dragging = te.pressed
		if te.pressed:
			tap_cell(cell_at(inv * te.position))
	elif event is InputEventScreenDrag and _dragging:
		tap_cell(cell_at(inv * (event as InputEventScreenDrag).position))


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = coins_total * 30 + maxi(0, int(par * 1.4 - time_in_level)) * 10 - int(st["mistakes"]) * 100
	var record: bool = Save.submit_best(level_id, maxi(0, score))
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "time": snappedf(time_in_level, 0.1), "deaths": deaths,
		"mistakes": int(st["mistakes"])})
	Audio.play("win")
	Audio.play_track("victoria", false)
	## Un momento para ver el dibujo terminado antes del panel.
	if not fast:
		await get_tree().create_timer(1.1).timeout
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": maxi(0, score), "record": record})
	await Ads.show_interstitial("level_end")


func stars_earned() -> int:
	if deaths > 0:
		return 1
	return 3 if int(st["mistakes"]) == 0 else 2


func _lose() -> void:
	if finished:
		return
	finished = true
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "nonogram", "mistakes": int(st["mistakes"]), "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("nono_lost", "\u00a1Demasiados fallos!"),
		Kit.text("nono_fail_hint", "Empieza por las pistas grandes: si un tramo ocupa casi toda la fila, el centro seguro que va pintado."))
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

func _num(at: Vector2, s: String, size: int, col: Color) -> void:
	var wd: float = _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_world.draw_string(_font, at + Vector2(-wd * 0.5, size * 0.36), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


## Una fila o columna esta completa (todo lo suyo pintado)?
func _line_done(is_row: bool, k: int) -> bool:
	var n: int = int(st["w"]) if is_row else int(st["h"])
	for i: int in n:
		var x: int = i if is_row else k
		var y: int = k if is_row else i
		if bool(st["sol"][y][x]) and int(st["cells"][y][x]) != 1:
			return false
	return true


func _draw_world() -> void:
	if st.is_empty() or int(st["w"]) == 0:
		return
	var w: int = int(st["w"])
	var h: int = int(st["h"])
	var board: Rect2 = Rect2(_origin, Vector2(w, h) * _cell)
	_world.draw_rect(Rect2(_origin - Vector2(_clue_w, _clue_h), board.size + Vector2(_clue_w, _clue_h)).grow(14.0), Color(1, 1, 1, 0.92))
	_world.draw_rect(board, Color("#ffffff"))
	var fs: int = int(_cell * 0.42)
	## Pistas.
	for y: int in h:
		var cl: Array = st["clues"]["rows"][y]
		var done: bool = _line_done(true, y)
		if y % 2 == 0:
			_world.draw_rect(Rect2(_origin + Vector2(-_clue_w, float(y) * _cell), Vector2(_clue_w, _cell)), Color(0.85, 0.88, 0.95, 0.5))
		var shown: Array = cl if not cl.is_empty() else [0]
		for i: int in shown.size():
			var cx: float = _origin.x - _clue_w + (float(i) + 0.5 + float((_clue_w / (_cell * 0.55)) - float(shown.size()))) * _cell * 0.55
			_num(Vector2(cx, _origin.y + (float(y) + 0.5) * _cell), str(shown[i]), fs, Color("#9aa0b0") if done else Color("#22304a"))
	for x: int in w:
		var cl2: Array = st["clues"]["cols"][x]
		var done2: bool = _line_done(false, x)
		if x % 2 == 0:
			_world.draw_rect(Rect2(_origin + Vector2(float(x) * _cell, -_clue_h), Vector2(_cell, _clue_h)), Color(0.85, 0.88, 0.95, 0.5))
		var shown2: Array = cl2 if not cl2.is_empty() else [0]
		for i: int in shown2.size():
			var cy: float = _origin.y - _clue_h + (float(i) + 0.5 + float((_clue_h / (_cell * 0.6)) - float(shown2.size()))) * _cell * 0.6
			_num(Vector2(_origin.x + (float(x) + 0.5) * _cell, cy), str(shown2[i]), fs, Color("#9aa0b0") if done2 else Color("#22304a"))
	## Casillas.
	for y: int in h:
		for x: int in w:
			var r: Rect2 = Rect2(_origin + Vector2(x, y) * _cell, Vector2(_cell, _cell))
			var v: int = int(st["cells"][y][x])
			var c: Vector2i = Vector2i(x, y)
			if v == 1:
				var col: Color = _ink.lerp(Color.from_hsv(fmod(float(x + y) * 0.04 + 0.55, 1.0), 0.55, 0.85), _reveal)
				_world.draw_rect(r.grow(-1.5), col)
			elif v == 2:
				var red: bool = _flash.has(c) and float(_flash[c]) > 0.25
				var xc: Color = Color("#e04a4a") if red else Color("#b8c0d0")
				_world.draw_line(r.position + Vector2(_cell * 0.28, _cell * 0.28), r.end - Vector2(_cell * 0.28, _cell * 0.28), xc, 3.0)
				_world.draw_line(r.position + Vector2(_cell * 0.72, _cell * 0.28), r.position + Vector2(_cell * 0.28, _cell * 0.72), xc, 3.0)
			if _flash.has(c) and v == 1:
				_world.draw_rect(r, Color(1, 1, 1, float(_flash[c]) * 2.0))
	for i: int in w + 1:
		var thick: bool = i % 5 == 0 or i == w
		_world.draw_line(_origin + Vector2(float(i) * _cell, 0), _origin + Vector2(float(i) * _cell, float(h) * _cell),
			Color("#22304a") if thick else Color("#c8cedc"), 3.0 if thick else 1.0)
	for i: int in h + 1:
		var thick2: bool = i % 5 == 0 or i == h
		_world.draw_line(_origin + Vector2(0, float(i) * _cell), _origin + Vector2(float(w) * _cell, float(i) * _cell),
			Color("#22304a") if thick2 else Color("#c8cedc"), 3.0 if thick2 else 1.0)
