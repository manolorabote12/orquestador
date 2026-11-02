extends Node2D
## Flechas: toca una flecha y sale volando por donde apunta si nadie le corta el paso; si choca,
## pierdes una vida. Vacia el tablero. Reglas, bot y analizador en arrows_map.gd.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel al acabar.

const M = preload("res://kit/arrows/arrows_map.gd")
const COLORS: Array[Color] = [Color("#ff6b6b"), Color("#feca57"), Color("#48dbfb"), Color("#1dd1a1"), Color("#ff9ff3"), Color("#5f27cd"), Color("#ff9f43"), Color("#54a0ff")]

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
var _hint_btn: Button
var _fly: Array = []
var _shake: Dictionary = {}
var _hint_i: int = -1
var _hint_t: float = 0.0
var _hints: int = 2
var _anim_t: float = 0.0


func _ready() -> void:
	level = Kit.current_level()
	RenderingServer.set_default_clear_color(Color("#f1f2f6"))
	_build_hud()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "arrows", "arrows": coins_total})


func bot_script() -> String:
	return "res://qa/arrows_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(2.2, 1.6)


func _reset() -> void:
	finished = false
	failed = false
	st = M.new_state(level)
	coins_total = (st["arrows"] as Array).size()
	coins = 0
	time_in_level = 0.0
	_fly.clear()
	_shake.clear()
	_hint_i = -1
	_hints = 2
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
	_info.add_theme_color_override("font_color", Color("#2f3542"))
	top.add_child(_info)
	_hint_btn = UI.make_button("", false, "star")
	_hint_btn.name = "BtnHint"
	_hint_btn.pressed.connect(use_hint)
	top.add_child(_hint_btn)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)
	_view = Control.new()
	_view.name = "View"
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.clip_contents = true
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


## Tocar la flecha i (lo usan el dedo, la pista y el bot).
func tap_arrow(i: int) -> void:
	if not can_act():
		return
	var r: Dictionary = M.tap(st, i)
	if r.is_empty():
		return
	if bool(r["ok"]):
		coins = coins_total - int(st["left"])
		_fly.append({"i": i, "t": 0.0})
		_sfx("click", -6.0)
		if _hint_i == i:
			_hint_i = -1
	else:
		_shake[i] = 0.35
		_shake[int(r["by"])] = 0.35
		_sfx("hurt", -6.0)
		Juice.vibrate(25)
	_refresh()
	if bool(st["won"]):
		_finish()
	elif bool(st["lost"]):
		_lose()


func use_hint() -> void:
	if not can_act() or _hints <= 0:
		return
	_hint_i = M.bot_move(st)
	if _hint_i >= 0:
		_hints -= 1
		_hint_t = 3.0
		_sfx("powerup", -8.0)
	_refresh()


func bot_step() -> void:
	if can_act():
		var m: int = M.bot_move(st)
		if m >= 0:
			tap_arrow(m)


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
	var c: Vector2i = Vector2i(int((p.x - b.position.x) / cs), int((p.y - b.position.y) / cs))
	var i: int = M.arrow_at(st, c)
	if i >= 0:
		tap_arrow(i)


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
	var lives: int = int(st["lives"]) - int(st["mistakes"])
	_info.text = Kit.text("ar_left", "Quedan {n}").format({"n": int(st["left"])}) + "\n" + Kit.text("ar_lives", "Vidas {n}").format({"n": maxi(0, lives)})
	_hint_btn.text = "     " + Kit.text("ar_hint", "Pista") + " %d" % _hints
	_hint_btn.disabled = _hints <= 0
	_view.queue_redraw()


func _physics_process(delta: float) -> void:
	if st.is_empty() or get_tree().paused:
		return
	_anim_t += delta
	if not finished and not failed:
		time_in_level += delta
		if fast and auto_retry:
			bot_step()
	_hint_t = maxf(0.0, _hint_t - delta)
	for f: Variant in _fly:
		f["t"] = float(f["t"]) + delta
	_fly = _fly.filter(func(f: Dictionary) -> bool: return float(f["t"]) < 0.6)
	for k: Variant in _shake.keys():
		_shake[k] = float(_shake[k]) - delta
		if float(_shake[k]) <= 0.0:
			_shake.erase(k)
	_view.queue_redraw()


# ------------------------------------------------------------------ dibujo

func _draw_arrow(a: Dictionary, color: Color, off: Vector2, cs: float, b: Rect2) -> void:
	var dv: Vector2 = Vector2(M.DIRS[str(a["d"])])
	var tip: Vector2 = b.position + (Vector2(int(a["x"]), int(a["y"])) + Vector2(0.5, 0.5)) * cs + off
	var tail: Vector2 = tip - dv * cs * (float(int(a["n"])) - 1.0) - dv * cs * 0.3
	var head: Vector2 = tip + dv * cs * 0.32
	_view.draw_line(tail, tip, color.darkened(0.25), cs * 0.34 + 4.0)
	_view.draw_line(tail, tip, color, cs * 0.34)
	_view.draw_circle(tail, cs * 0.17, color)
	var side: Vector2 = dv.orthogonal()
	_view.draw_colored_polygon(PackedVector2Array([head, tip - dv * cs * 0.05 + side * cs * 0.34, tip - dv * cs * 0.05 - side * cs * 0.34]), color.darkened(0.15))


func _draw_view() -> void:
	if st.is_empty():
		return
	var b: Rect2 = _board()
	var w: int = int(st["w"])
	var h: int = int(st["h"])
	var cs: float = b.size.x / float(w)
	_view.draw_rect(b.grow(8.0), Color("#dfe4ea"))
	for y: int in h:
		for x: int in w:
			_view.draw_circle(b.position + (Vector2(x, y) + Vector2(0.5, 0.5)) * cs, 3.0, Color("#c8ced6"))
	var arrows: Array = st["arrows"]
	for i: int in arrows.size():
		var a: Dictionary = arrows[i]
		var col: Color = COLORS[i % COLORS.size()]
		if bool(a["out"]):
			continue
		var off: Vector2 = Vector2.ZERO
		if _shake.has(i):
			off = Vector2(sin(_anim_t * 70.0), 0) * 6.0
			col = col.lerp(Color("#ff4757"), 0.5)
		if i == _hint_i and _hint_t > 0.0:
			col = col.lightened(0.3 + 0.2 * sin(_anim_t * 10.0))
		_draw_arrow(a, col, off, cs, b)
	for f: Variant in _fly:
		var a2: Dictionary = arrows[int(f["i"])]
		var dv: Vector2 = Vector2(M.DIRS[str(a2["d"])])
		var t: float = float(f["t"])
		var col2: Color = COLORS[int(f["i"]) % COLORS.size()]
		col2.a = 1.0 - t / 0.6
		_draw_arrow(a2, col2, dv * t * t * cs * 40.0, cs, b)


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = maxi(1, coins_total * 50 - int(st["mistakes"]) * 100 + _hints * 50)
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "mistakes": int(st["mistakes"]), "time": snappedf(time_in_level, 0.1)})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


## Estrellas: sin choques ni pistas, 3; con uno de los dos, 2; si no, 1.
func stars_earned() -> int:
	var used: int = int(st["mistakes"]) + (2 - _hints)
	return 3 if used == 0 else (2 if used <= 1 else 1)


func _lose() -> void:
	if failed:
		return
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "arrows", "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("ar_lost", "\u00a1Sin vidas!"), Kit.text("ar_lost_hint", "Antes de tocar, sigue con la vista el camino de la flecha hasta el borde."))
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
		"mistakes": int(st.get("mistakes", 0)), "left": int(st.get("left", 0))}
