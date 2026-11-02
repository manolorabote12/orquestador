extends Node2D
## Buscaminas: toca para abrir, mant\u00e9n pulsado (o usa el modo bandera) para marcar minas.
## Reglas, resolutor, bot y analizador en mines_map.gd. Nunca hace falta adivinar.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const MapRules = preload("res://kit/mines/mines_map.gd")
const NUM_COLORS: Array[Color] = [Color.WHITE, Color("#2f62d8"), Color("#2f9a52"), Color("#d8303a"), Color("#6a2fa8"), Color("#a8501a"),
	Color("#1a8a8a"), Color("#222222"), Color("#888888")]
const HOLD: float = 0.35

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
var flag_mode: bool = false

var _font: Font
var _world: Node2D
var _camera: Camera2D
var _hearts: HBoxContainer
var _time_label: Label
var _mines_label: Label
var _mode_btn: Button
var _cell: float = 64.0
var _origin: Vector2 = Vector2.ZERO
var _press: Vector2i = Vector2i(-1, -1)
var _press_t: float = -1.0
var _booms: Array[Dictionary] = []
var _t: float = 0.0


func _ready() -> void:
	level = Kit.current_level()
	par = float(level.get("par", 0))
	RenderingServer.set_default_clear_color(Color("#2a3a4a"))
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
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "mines", "mines": (st["mines"] as Dictionary).size()})


func bot_script() -> String:
	return "res://qa/mines_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(3.0, 1.5)


func wants_grade() -> bool:
	return false


func _reset() -> void:
	finished = false
	failed = false
	st = MapRules.new_state(level)
	coins_total = int(st["safe"])
	coins = 0
	time_in_level = 0.0
	flag_mode = false
	_booms.clear()
	var w: int = maxi(1, int(st["w"]))
	var h: int = maxi(1, int(st["h"]))
	_cell = minf(84.0, minf(680.0 / float(w), 860.0 / float(h)))
	_origin = Vector2(360.0, 610.0) - Vector2(w, h) * _cell * 0.5
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
	_mines_label = Label.new()
	_mines_label.name = "Mines"
	_mines_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mines_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mines_label.add_theme_font_size_override("font_size", 32)
	_mines_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_mines_label.add_theme_constant_override("outline_size", 6)
	top.add_child(_mines_label)
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
	_mode_btn.name = "BtnFlag"
	_mode_btn.custom_minimum_size = Vector2(340, 92)
	_mode_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_mode_btn.pressed.connect(func() -> void:
		flag_mode = not flag_mode
		_refresh())
	col.add_child(_mode_btn)


func _refresh() -> void:
	if _time_label == null or st.is_empty():
		return
	var s: int = int(time_in_level)
	_time_label.text = "%d:%02d" % [s / 60, s % 60]
	_mines_label.text = Kit.text("mines_left", "Minas") + " %d" % maxi(0, (st["mines"] as Dictionary).size() - (st["flags"] as Dictionary).size())
	_mode_btn.text = Kit.text("mines_flag", "Modo: bandera") if flag_mode else Kit.text("mines_dig", "Modo: abrir")
	var lives: int = int(st["lives"])
	if _hearts.get_child_count() != lives:
		for c: Node in _hearts.get_children():
			c.queue_free()
		for i: int in lives:
			_hearts.add_child(UiIcon.make("heart", Color("#ff5a6a"), 40.0))
	for i: int in _hearts.get_child_count():
		(_hearts.get_child(i) as Control).modulate = Color(1, 1, 1, 0.25) if i >= lives - int(st["booms"]) else Color.WHITE
	coins = (st["open"] as Dictionary).size()


# ------------------------------------------------------------------ acciones

func can_act() -> bool:
	return not finished and is_inside_tree() and not get_tree().paused


func cell_at(p: Vector2) -> Vector2i:
	return Vector2i(floori((p.x - _origin.x) / _cell), floori((p.y - _origin.y) / _cell))


func open_cell(c: Vector2i) -> void:
	if not can_act():
		return
	var r: String = MapRules.reveal(st, c)
	if r == "mine":
		_booms.append({"c": c, "t": 0.8})
		if not fast:
			Audio.play("hurt", 0.05, -4.0)
	elif r == "open":
		_sfx("click")
	_refresh()
	if bool(st["won"]):
		_finish()
	elif MapRules.lost(st):
		_lose()


func flag_cell(c: Vector2i) -> void:
	if not can_act():
		return
	MapRules.toggle_flag(st, c)
	_sfx("click")
	_refresh()


func _sfx(n: String) -> void:
	if not fast:
		Audio.play(n, 0.1, -10.0)


func bot_step() -> void:
	if not can_act():
		return
	var m: Array = MapRules.bot_move(st)
	if m.is_empty():
		return
	if str(m[0]) == "open":
		open_cell(m[1])
	else:
		flag_cell(m[1])


# ------------------------------------------------------------------ bucle

func _physics_process(delta: float) -> void:
	_t += delta
	for b: Dictionary in _booms:
		b["t"] = float(b["t"]) - delta
	_booms = _booms.filter(func(b: Dictionary) -> bool: return float(b["t"]) > 0.0)
	if finished:
		_world.queue_redraw()
		return
	## Mantener pulsado = bandera.
	if _press_t >= 0.0:
		_press_t += delta
		if _press_t >= HOLD:
			flag_cell(_press)
			_press_t = -1.0
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
	if event is InputEventScreenTouch:
		var te: InputEventScreenTouch = event
		var c: Vector2i = cell_at(get_canvas_transform().affine_inverse() * te.position)
		if te.pressed:
			_press = c
			_press_t = 0.0
		elif _press_t >= 0.0:
			_press_t = -1.0
			if c == _press:
				if flag_mode:
					flag_cell(c)
				else:
					open_cell(c)


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	coins = coins_total
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = coins_total * 20 + maxi(0, int(par * 1.4 - time_in_level)) * 10 - int(st["booms"]) * 200
	var record: bool = Save.submit_best(level_id, maxi(0, score))
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "time": snappedf(time_in_level, 0.1), "deaths": deaths})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": maxi(0, score), "record": record})
	await Ads.show_interstitial("level_end")


func stars_earned() -> int:
	if deaths > 0:
		return 1
	return 3 if int(st["booms"]) == 0 else 2


func _lose() -> void:
	if finished:
		return
	finished = true
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "mine", "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("mines_lost", "\u00a1Boom!"),
		Kit.text("mines_fail_hint", "Nunca hace falta adivinar: si un n\u00famero ya tiene sus minas marcadas, el resto de sus vecinas es seguro."))
	p.closed.connect(retry)


## Segunda oportunidad (FailPanel, con anuncio): una vida mas y se sigue donde ibas.
func revive() -> void:
	st["booms"] = maxi(0, int(st["booms"]) - 1)
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
	return {"pos": Vector2(float(coins), float(st.get("booms", 0))), "deaths": deaths, "coins": coins, "finished": finished,
		"failed": failed, "stomps": 0, "time": time_in_level, "booms": int(st.get("booms", 0))}


# ------------------------------------------------------------------ dibujo

func _draw_world() -> void:
	if st.is_empty() or int(st["w"]) == 0:
		return
	var w: int = int(st["w"])
	var h: int = int(st["h"])
	var board: Rect2 = Rect2(_origin, Vector2(w, h) * _cell)
	_world.draw_rect(board.grow(12.0), Color(0, 0, 0, 0.3))
	var fs: int = int(_cell * 0.55)
	for y: int in h:
		for x: int in w:
			var c: Vector2i = Vector2i(x, y)
			var r: Rect2 = Rect2(_origin + Vector2(x, y) * _cell, Vector2(_cell, _cell))
			if (st["open"] as Dictionary).has(c):
				_world.draw_rect(r, Color("#e8dcc0") if (x + y) % 2 == 0 else Color("#dfd2b4"))
				var n: int = MapRules.count(st, c)
				if n > 0:
					var s: String = str(n)
					var wd: float = _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
					_world.draw_string(_font, r.get_center() + Vector2(-wd * 0.5, fs * 0.36), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, NUM_COLORS[n])
			else:
				_world.draw_rect(r, Color("#7ac05a") if (x + y) % 2 == 0 else Color("#6ab44c"))
				_world.draw_rect(Rect2(r.position, Vector2(r.size.x, 4)), Color(1, 1, 1, 0.18))
				if (st["flags"] as Dictionary).has(c):
					var boom: bool = (st["mines"] as Dictionary).has(c) and _was_boom(c)
					if boom:
						_world.draw_circle(r.get_center(), _cell * 0.28, Color("#222222"))
						_world.draw_circle(r.get_center() + Vector2(-_cell * 0.08, -_cell * 0.08), _cell * 0.07, Color(1, 1, 1, 0.6))
					else:
						var b: Vector2 = r.position + Vector2(_cell * 0.35, _cell * 0.2)
						_world.draw_line(b, b + Vector2(0, _cell * 0.6), Color("#3a2a1a"), 3.0)
						_world.draw_colored_polygon(PackedVector2Array([b, b + Vector2(_cell * 0.38, _cell * 0.13), b + Vector2(0, _cell * 0.26)]), Color("#e8343a"))
			if c == _press and _press_t >= 0.0:
				_world.draw_arc(r.get_center(), _cell * 0.4, -PI * 0.5, -PI * 0.5 + TAU * clampf(_press_t / HOLD, 0.0, 1.0), 20, Color("#ffd23f"), 4.0)
	for bm: Dictionary in _booms:
		var cc: Vector2 = _origin + (Vector2(bm["c"]) + Vector2(0.5, 0.5)) * _cell
		var f: float = 1.0 - float(bm["t"]) / 0.8
		_world.draw_circle(cc, _cell * (0.3 + f * 1.2), Color(1.0, 0.6, 0.2, 0.7 * (1.0 - f)))


func _was_boom(c: Vector2i) -> bool:
	## Una bandera sobre mina que se abrio por error se dibuja como mina (tras el boom).
	return finished and failed or _booms.any(func(b: Dictionary) -> bool: return b["c"] == c)
