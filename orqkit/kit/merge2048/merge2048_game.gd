extends Node2D
## 2048: desliza (o flechas del teclado) y junta fichas iguales hasta la ficha objetivo. Se puede
## deshacer dos veces. Reglas, bot y analizador en merge2048_map.gd.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel al acabar.

const M = preload("res://kit/merge2048/merge2048_map.gd")
const SLIDE_T: float = 0.11

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
var _undo_btn: Button
var _swipe_from: Vector2 = Vector2.INF
var _anim: Array = []
var _anim_t: float = 1.0
var _pop: Dictionary = {}
var _t: float = 0.0


func _ready() -> void:
	level = Kit.current_level()
	RenderingServer.set_default_clear_color(Color("#faf8ef"))
	_font = UI.theme.get_font("font", "Label") if UI.theme != null else ThemeDB.fallback_font
	_build_hud()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "merge2048", "target": int(st["target"])})


func bot_script() -> String:
	return "res://qa/merge2048_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(2.2, 1.6)


func _reset() -> void:
	finished = false
	failed = false
	st = M.new_state(level)
	coins = 0
	coins_total = 0
	time_in_level = 0.0
	_anim.clear()
	_anim_t = 1.0
	_pop.clear()
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
	_info.add_theme_color_override("font_color", Color("#776e65"))
	top.add_child(_info)
	_undo_btn = UI.make_button("", false, "retry")
	_undo_btn.name = "BtnUndo"
	_undo_btn.pressed.connect(use_undo)
	top.add_child(_undo_btn)
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


## Desliza hacia dir ("l", "r", "u", "d"). Lo usan el dedo, el teclado y el bot.
func slide(dir: String) -> bool:
	if not can_act():
		return false
	var r: Dictionary = M.move(st, dir)
	if r.is_empty():
		return false
	_anim = r["anim"]
	_anim_t = 0.0
	_pop.clear()
	for a: Variant in _anim:
		if bool(a["merge"]):
			_pop[int(a["to"])] = 0.25
	if int(r.get("spawn", -1)) >= 0:
		_pop[int(r["spawn"])] = 0.2
	if int(r["gain"]) > 0:
		_sfx("coin", -10.0)
	else:
		_sfx("click", -14.0)
	_refresh()
	if bool(st["won"]):
		_finish()
	elif bool(st["lost"]):
		_lose()
	return true


func use_undo() -> void:
	if can_act() and M.undo(st):
		_anim.clear()
		_anim_t = 1.0
		_sfx("powerup", -8.0)
		_refresh()


func bot_step() -> void:
	if can_act():
		var d: String = M.bot_move(st)
		if d != "":
			slide(d)


func _on_input(event: InputEvent) -> void:
	var touch: bool = DisplayServer.is_touchscreen_available()
	var state: int = 0
	var pos: Vector2 = Vector2.ZERO
	if event is InputEventScreenTouch:
		state = 1 if (event as InputEventScreenTouch).pressed else -1
		pos = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton and not touch and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		state = 1 if (event as InputEventMouseButton).pressed else -1
		pos = (event as InputEventMouseButton).position
	elif event is InputEventScreenDrag:
		state = 2
		pos = (event as InputEventScreenDrag).position
	elif event is InputEventMouseMotion and not touch:
		state = 2
		pos = (event as InputEventMouseMotion).position
	if state == 1:
		_swipe_from = pos
	elif state == -1:
		_swipe_from = Vector2.INF
	elif state == 2 and _swipe_from != Vector2.INF:
		var d: Vector2 = pos - _swipe_from
		if d.length() > 48.0:
			_swipe_from = Vector2.INF
			if absf(d.x) > absf(d.y):
				slide("r" if d.x > 0.0 else "l")
			else:
				slide("d" if d.y > 0.0 else "u")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()
	elif event.is_action_pressed("ui_left"):
		slide("l")
	elif event.is_action_pressed("ui_right"):
		slide("r")
	elif event.is_action_pressed("ui_up"):
		slide("u")
	elif event.is_action_pressed("ui_down"):
		slide("d")


func _sfx(n: String, vol: float = -6.0) -> void:
	if not fast:
		Audio.play(n, 0.1, vol)


func _refresh() -> void:
	if st.is_empty() or _info == null:
		return
	_info.text = Kit.text("n48_goal", "Objetivo {n}").format({"n": int(st["target"])}) + "\n" + Kit.text("n48_score", "Puntos {n}").format({"n": int(st["score"])})
	_undo_btn.text = "     " + Kit.text("n48_undo", "Deshacer") + " %d" % int(st["undo"])
	_undo_btn.disabled = int(st["undo"]) <= 0 or (st["prev"] as Dictionary).is_empty()
	_view.queue_redraw()


func _physics_process(delta: float) -> void:
	if st.is_empty() or get_tree().paused:
		return
	_t += delta
	_anim_t = minf(1.0, _anim_t + delta / SLIDE_T)
	for k: Variant in _pop.keys():
		_pop[k] = float(_pop[k]) - delta
		if float(_pop[k]) <= 0.0:
			_pop.erase(k)
	if not finished and not failed:
		time_in_level += delta
		if fast and auto_retry:
			bot_step()
	_view.queue_redraw()


# ------------------------------------------------------------------ dibujo

static func tile_color(v: int) -> Color:
	var cols: Dictionary = {2: "#eee4da", 4: "#ede0c8", 8: "#f2b179", 16: "#f59563", 32: "#f67c5f", 64: "#f65e3b", 128: "#edcf72",
		256: "#edcc61", 512: "#edc850", 1024: "#edc53f", 2048: "#edc22e"}
	return Color(str(cols.get(v, "#3c3a32")))


func _board() -> Rect2:
	var sz: Vector2 = _view.size
	var side: float = minf(sz.x - 16.0, sz.y - 16.0)
	return Rect2(Vector2((sz.x - side) * 0.5, (sz.y - side) * 0.35), Vector2(side, side))


func _cell_rect(b: Rect2, n: int, i: int) -> Rect2:
	var gap: float = b.size.x * 0.025
	var cs: float = (b.size.x - gap * float(n + 1)) / float(n)
	return Rect2(b.position + Vector2(gap + float(i % n) * (cs + gap), gap + float(i / n) * (cs + gap)), Vector2(cs, cs))


func _draw_tile(r: Rect2, v: int) -> void:
	_view.draw_rect(r, tile_color(v))
	var txt: String = str(v)
	var fs: int = int(r.size.x * (0.42 if txt.length() <= 2 else (0.34 if txt.length() == 3 else 0.27)))
	var tc: Color = Color("#776e65") if v <= 4 else Color("#f9f6f2")
	_view.draw_string(ThemeDB.fallback_font, Vector2(r.position.x, r.position.y + r.size.y * 0.5 + float(fs) * 0.36), txt, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, tc)


func _draw_view() -> void:
	if st.is_empty():
		return
	var b: Rect2 = _board()
	var n: int = int(st["n"])
	var board: Array = st["b"]
	_view.draw_rect(b, Color("#bbada0"))
	for i: int in n * n:
		var r: Rect2 = _cell_rect(b, n, i)
		_view.draw_rect(r, Color("#5d5348") if int(board[i]) == M.ROCK else Color("#cdc1b4"))
	if _anim_t < 1.0:
		for a: Variant in _anim:
			var r0: Rect2 = _cell_rect(b, n, int(a["from"]))
			var r1: Rect2 = _cell_rect(b, n, int(a["to"]))
			_draw_tile(Rect2(r0.position.lerp(r1.position, _anim_t), r0.size), int(a["v"]))
		return
	for i2: int in n * n:
		var v: int = int(board[i2])
		if v <= 0:
			continue
		var r2: Rect2 = _cell_rect(b, n, i2)
		if _pop.has(i2):
			r2 = r2.grow(r2.size.x * 0.08 * sin(float(_pop[i2]) / 0.25 * PI))
		_draw_tile(r2, v)
	var hint: Rect2 = Rect2(b.position + Vector2(0, b.size.y + 18.0), Vector2(b.size.x, 40))
	_view.draw_string(_font, hint.position + Vector2(0, 30), Kit.text("n48_swipe", "Desliza para juntar fichas iguales"), HORIZONTAL_ALIGNMENT_CENTER, b.size.x, 26, Color("#a39a90"))


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = maxi(1, int(st["score"]))
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "moves": int(st["moves"]), "time": snappedf(time_in_level, 0.1)})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


## Estrellas: sin deshacer, 3; deshaciendo una vez, 2; si no, 1.
func stars_earned() -> int:
	var used: int = 2 - int(st["undo"])
	return 3 if used <= 0 else (2 if used == 1 else 1)


func _lose() -> void:
	if failed:
		return
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "merge2048", "deaths": deaths, "best": M.max_tile(st)})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("n48_lost", "Tablero lleno"), Kit.text("n48_lost_hint", "Deja la ficha m\u00e1s grande en una esquina y desliza casi siempre hacia los mismos dos lados."))
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
		"moves": int(st.get("moves", 0)), "best": M.max_tile(st) if not st.is_empty() else 0}
