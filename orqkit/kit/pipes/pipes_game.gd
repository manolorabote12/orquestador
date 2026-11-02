extends Node2D
## Tuberias: toca una pieza para girarla; cuando el agua del grifo llega a todas sin fugas, ganas.
## Reglas, bot y analizador en pipes_map.gd.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel al acabar.

const M = preload("res://kit/pipes/pipes_map.gd")

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

var _view: Control
var _info: Label
var _spin: Dictionary = {}
var _anim_t: float = 0.0
var _water: Color = Color("#4fc3f7")


func _ready() -> void:
	level = Kit.current_level()
	RenderingServer.set_default_clear_color(Color("#263238"))
	_water = Color("#29b6f6")
	_build_hud()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "pipes", "tiles": coins_total})


func bot_script() -> String:
	return "res://qa/pipes_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(2.2, 1.6)


func _reset() -> void:
	finished = false
	failed = false
	st = M.new_state(level)
	coins_total = (st["tiles"] as Array).size()
	coins = (st["wet"] as Dictionary).size()
	time_in_level = 0.0
	_spin.clear()
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
	_info = Label.new()
	_info.name = "Info"
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.clip_text = true
	_info.add_theme_font_size_override("font_size", 26)
	top.add_child(_info)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)
	_view = Control.new()
	_view.name = "View"
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.draw.connect(_draw_view)
	_view.gui_input.connect(_on_input)
	col.add_child(_view)


func can_act() -> bool:
	return not finished and not failed and is_inside_tree() and not get_tree().paused and not st.is_empty()


func _board() -> Rect2:
	var sz: Vector2 = _view.size
	var w: int = int(st["w"])
	var h: int = int(st["h"])
	var cs: float = minf((sz.x - 16.0) / float(w), (sz.y - 16.0) / float(h))
	var b: Vector2 = Vector2(w, h) * cs
	return Rect2((sz - b) * 0.5, b)


func tap_cell(c: Vector2i) -> void:
	if not can_act():
		return
	if M.tap(st, c):
		_spin[c] = 1.0
		coins = (st["wet"] as Dictionary).size()
		_sfx("click", -10.0)
		_refresh()
		if bool(st["won"]):
			_finish()
		elif bool(st["lost"]):
			_lose()


func bot_step() -> void:
	if can_act():
		var c: Vector2i = M.bot_move(st, level.get("sol", []))
		if c.x >= 0:
			tap_cell(c)


func _on_input(event: InputEvent) -> void:
	var p: Vector2 = Vector2.INF
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		p = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and not DisplayServer.is_touchscreen_available():
		p = (event as InputEventMouseButton).position
	if p == Vector2.INF:
		return
	var b: Rect2 = _board()
	if not b.has_point(p):
		return
	var cs: float = b.size.x / float(int(st["w"]))
	tap_cell(Vector2i(int((p.x - b.position.x) / cs), int((p.y - b.position.y) / cs)))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()


func _sfx(n: String, vol: float = -6.0) -> void:
	if not fast:
		Audio.play(n, 0.1, vol)


func _refresh() -> void:
	if st.is_empty() or _info == null:
		return
	var txt: String = Kit.text("pp_wet", "Agua {a}/{b}").format({"a": coins, "b": coins_total})
	if int(st["max_taps"]) > 0:
		txt += "\n" + Kit.text("pp_taps", "Giros {a}/{b}").format({"a": int(st["taps"]), "b": int(st["max_taps"])})
	_info.text = txt
	_view.queue_redraw()


func _physics_process(delta: float) -> void:
	if st.is_empty() or get_tree().paused:
		return
	_anim_t += delta
	if not finished and not failed:
		time_in_level += delta
		if fast and auto_retry:
			bot_step()
	for k: Variant in _spin.keys():
		_spin[k] = float(_spin[k]) - delta * 8.0
		if float(_spin[k]) <= 0.0:
			_spin.erase(k)
	_view.queue_redraw()


# ------------------------------------------------------------------ dibujo

func _draw_view() -> void:
	if st.is_empty():
		return
	var b: Rect2 = _board()
	var w: int = int(st["w"])
	var cs: float = b.size.x / float(w)
	_view.draw_rect(b.grow(6.0), Color("#102027"))
	var wet: Dictionary = st["wet"]
	for i: int in (st["tiles"] as Array).size():
		var c: Vector2i = Vector2i(i % w, i / w)
		var r: Rect2 = Rect2(b.position + Vector2(c) * cs, Vector2(cs, cs))
		_view.draw_rect(r.grow(-2.0), Color("#37474f") if (c.x + c.y) % 2 == 0 else Color("#34444c"))
		var m: int = int(st["tiles"][i])
		var ctr: Vector2 = r.get_center()
		var ang: float = -float(_spin.get(c, 0.0)) * PI * 0.5
		var col: Color = _water if wet.has(c) else Color("#90a4ae")
		var thick: float = cs * 0.26
		for bit: int in [M.UP, M.RIGHT, M.DOWN, M.LEFT]:
			if m & bit == 0:
				continue
			var d: Vector2 = Vector2(M._dir(bit)).rotated(ang)
			_view.draw_line(ctr, ctr + d * cs * 0.5, Color("#263238"), thick + 6.0)
			_view.draw_line(ctr, ctr + d * cs * 0.5, col, thick)
		_view.draw_circle(ctr, thick * 0.62, col)
		if c == st["src"]:
			_view.draw_circle(ctr, cs * 0.24, Color("#ffd54f"))
			_view.draw_circle(ctr, cs * 0.12, _water)
		if finished and wet.has(c):
			_view.draw_circle(ctr, thick * 0.3 * (1.0 + 0.3 * sin(_anim_t * 6.0 + float(i))), Color(1, 1, 1, 0.6))


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = maxi(1, coins_total * 50 - int(st["taps"]) * 5)
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "taps": int(st["taps"]), "time": snappedf(time_in_level, 0.1)})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


## Estrellas por los giros: cerca del minimo, 3; con algunos de mas, 2; si no, 1.
func stars_earned() -> int:
	var need: int = maxi(1, M.min_taps(level))
	var extra: float = float(int(st["taps"]) - need) / float(need)
	return 3 if extra <= 0.25 else (2 if extra <= 0.75 else 1)


func _lose() -> void:
	if failed:
		return
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "pipes", "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("pp_lost", "Sin giros"), Kit.text("pp_lost_hint", "Empieza por las esquinas y los bordes: all\u00ed cada pieza solo puede mirar hacia dentro."))
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
	return {"deaths": deaths, "coins": coins, "finished": finished, "failed": failed, "stomps": 0, "time": time_in_level,
		"taps": int(st.get("taps", 0))}
