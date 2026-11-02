extends Node2D
## Encuentra las diferencias: arriba el dibujo, abajo el mismo con cambios; toca donde cambian (en
## cualquiera de los dos). Reglas, bot y analizador en spotdiff_map.gd.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel al acabar.

const M = preload("res://kit/spotdiff/spotdiff_map.gd")
const SceneDraw = preload("res://kit/spotdiff/scene_draw.gd")

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

var _font: Font
var _view: Control
var _info: Label
var _hint_btn: Button
var _miss: Array = []
var _hint_i: int = -1
var _hint_t: float = 0.0
var _anim_t: float = 0.0


func _ready() -> void:
	level = Kit.current_level()
	RenderingServer.set_default_clear_color(Color("#2b2d42"))
	_font = UI.theme.get_font("font", "Label") if UI.theme != null else ThemeDB.fallback_font
	_build_hud()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "spotdiff", "diffs": coins_total})


func bot_script() -> String:
	return "res://qa/spotdiff_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(2.2, 1.6)


func _reset() -> void:
	finished = false
	failed = false
	st = M.new_state(level)
	coins_total = (st["spots"] as Array).size()
	coins = 0
	time_in_level = 0.0
	_miss.clear()
	_hint_i = -1
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
	_info.add_theme_font_size_override("font_size", 26)
	_info.clip_text = true
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
	_view.draw.connect(_draw_view)
	_view.gui_input.connect(_on_input)
	col.add_child(_view)


func can_act() -> bool:
	return not finished and not failed and is_inside_tree() and not get_tree().paused and not st.is_empty()


## Los dos dibujos: [arriba, abajo] (rectangulos cuadrados centrados).
func _panels() -> Array:
	var sz: Vector2 = _view.size
	var side: float = minf(sz.x - 8.0, (sz.y - 16.0) * 0.5)
	var x: float = (sz.x - side) * 0.5
	return [Rect2(Vector2(x, 0), Vector2(side, side)), Rect2(Vector2(x, side + 16.0), Vector2(side, side))]


func tap_at(p01: Vector2) -> void:
	if not can_act():
		return
	var r: int = M.tap(st, p01)
	if r >= 0:
		coins = (st["found"] as Array).size()
		_sfx("coin", -4.0)
		if _hint_i == r:
			_hint_i = -1
	elif r == -1:
		_miss.append({"p": p01, "t": 0.7})
		_sfx("hurt", -8.0)
	_refresh()
	if bool(st["won"]):
		_finish()
	elif bool(st["lost"]):
		_lose()


func use_hint() -> void:
	if can_act():
		_hint_i = M.hint(st)
		_hint_t = 3.0
		_sfx("powerup", -8.0)
		_refresh()


func bot_step() -> void:
	if can_act():
		var p: Vector2 = M.bot_tap(st)
		if p.x >= 0.0:
			tap_at(p)


func _on_input(event: InputEvent) -> void:
	var p: Vector2 = Vector2.INF
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		p = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and not DisplayServer.is_touchscreen_available():
		p = (event as InputEventMouseButton).position
	if p == Vector2.INF:
		return
	for r: Variant in _panels():
		var rr: Rect2 = r
		if rr.has_point(p):
			tap_at((p - rr.position) / rr.size)
			return


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
	_info.text = Kit.text("sd_found", "{a}/{b} diferencias").format({"a": coins, "b": coins_total}) + \
		"\n" + "X ".repeat(int(st["mistakes"])) + "o ".repeat(maxi(0, int(st["max_mistakes"]) - int(st["mistakes"])))
	_hint_btn.text = "     " + Kit.text("sd_hint", "Pista") + " %d" % int(st["hints"])
	_hint_btn.disabled = int(st["hints"]) <= 0
	_view.queue_redraw()


func _physics_process(delta: float) -> void:
	if st.is_empty() or finished or get_tree().paused:
		return
	_anim_t += delta
	if not failed:
		time_in_level += delta
	if fast and auto_retry:
		bot_step()
	_hint_t = maxf(0.0, _hint_t - delta)
	for m: Variant in _miss:
		m["t"] = float(m["t"]) - delta
	_miss = _miss.filter(func(m: Dictionary) -> bool: return float(m["t"]) > 0.0)
	_view.queue_redraw()


# ------------------------------------------------------------------ dibujo

func _draw_view() -> void:
	if st.is_empty():
		return
	var panels: Array = _panels()
	var scene: Array = level.get("scene", [])
	for k: int in 2:
		var r: Rect2 = panels[k]
		var shapes: Array = scene if k == 0 else range(scene.size()).map(func(i: int) -> Dictionary: return M.shape_after(level, i))
		SceneDraw.draw_scene(_view, r, level, shapes)
		_view.draw_rect(r, Color.WHITE, false, 4.0)
		for f: Variant in st["found"]:
			var p: Vector2 = r.position + (st["spots"][int(f)] as Vector2) * r.size
			_view.draw_arc(p, r.size.x * M.HIT_R, 0.0, TAU, 32, Color("#2ecc71"), 6.0)
		if _hint_i >= 0 and _hint_t > 0.0:
			var hp: Vector2 = r.position + (st["spots"][_hint_i] as Vector2) * r.size
			_view.draw_arc(hp, r.size.x * M.HIT_R * (1.6 + 0.3 * sin(_anim_t * 8.0)), 0.0, TAU, 32, Color("#ffd166"), 5.0)
		for m: Variant in _miss:
			var mp: Vector2 = r.position + (m["p"] as Vector2) * r.size
			_view.draw_line(mp + Vector2(-16, -16), mp + Vector2(16, 16), Color("#e74c3c"), 6.0)
			_view.draw_line(mp + Vector2(16, -16), mp + Vector2(-16, 16), Color("#e74c3c"), 6.0)


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = maxi(1, coins_total * 200 - int(st["mistakes"]) * 50 + int(st["hints"]) * 100)
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "mistakes": int(st["mistakes"]), "time": snappedf(time_in_level, 0.1)})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


## Estrellas: sin fallos ni pistas, 3; con uno de los dos, 2; si no, 1.
func stars_earned() -> int:
	var used: int = int(st["mistakes"]) + (2 - int(st["hints"]))
	return 3 if used == 0 else (2 if used <= 2 else 1)


func _lose() -> void:
	if failed:
		return
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "spotdiff", "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("sd_lost", "Demasiados fallos"), Kit.text("sd_lost_hint", "Mira con calma: colores, tama\u00f1os, cosas que faltan o que se han movido."))
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
		"found": coins, "mistakes": int(st.get("mistakes", 0))}
