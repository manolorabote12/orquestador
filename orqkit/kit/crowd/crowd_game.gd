extends Node2D
## Multitud (tipo Count Masters / el anuncio de Last War): desliza a izquierda o derecha para pasar
## por las mejores puertas, esquiva trampas, vence a los grupos enemigos y llega al jefe con mas gente.
## Reglas, bot y analizador en crowd_map.gd.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel al acabar.

const M = preload("res://kit/crowd/crowd_map.gd")
const PX_PER_M: float = 26.0

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
var target_x: float = 0.0

var _font: Font
var _view: Control
var _count_lbl: Label
var _lanes: Array = []
var _bot_on: bool = false
var _pops: Array = []
var _anim_t: float = 0.0


func _ready() -> void:
	level = Kit.current_level()
	RenderingServer.set_default_clear_color(Color("#7cc3f0"))
	_font = UI.theme.get_font("font", "Label") if UI.theme != null else ThemeDB.fallback_font
	_build_hud()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "crowd", "boss": int(M.best(level)["boss"])})


func bot_script() -> String:
	return "res://qa/crowd_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(2.5, 2.0)


func _reset() -> void:
	finished = false
	failed = false
	st = M.new_state(level)
	target_x = 0.0
	time_in_level = 0.0
	_lanes = M.best(level)["lanes"]
	_pops.clear()
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
	_view = Control.new()
	_view.name = "View"
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.draw.connect(_draw_view)
	_view.gui_input.connect(_on_input)
	root.add_child(_view)
	var safe: MarginContainer = UI.safe_root(root, 14.0)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	safe.add_child(top)
	_count_lbl = Label.new()
	_count_lbl.name = "Count"
	_count_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_count_lbl.add_theme_font_size_override("font_size", 44)
	top.add_child(_count_lbl)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)


func can_act() -> bool:
	return not finished and not failed and is_inside_tree() and not get_tree().paused and not st.is_empty()


func bot_step() -> void:
	if can_act():
		target_x = M.bot_lane(st, _lanes)


func _on_input(event: InputEvent) -> void:
	if not can_act():
		return
	var p: Vector2 = Vector2.INF
	if event is InputEventScreenDrag:
		p = (event as InputEventScreenDrag).position
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		p = (event as InputEventScreenTouch).position
	elif event is InputEventMouseMotion and ((event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT) != 0 and not DisplayServer.is_touchscreen_available():
		p = (event as InputEventMouseMotion).position
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and not DisplayServer.is_touchscreen_available():
		p = (event as InputEventMouseButton).position
	if p != Vector2.INF:
		target_x = clampf((p.x / maxf(1.0, _view.size.x)) * 2.0 - 1.0, -0.9, 0.9)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()
	elif event.is_action_pressed("ui_left"):
		target_x = -M.LANE_X
	elif event.is_action_pressed("ui_right"):
		target_x = M.LANE_X


func _sfx(n: String, vol: float = -6.0) -> void:
	if not fast:
		Audio.play(n, 0.1, vol)


func _refresh() -> void:
	if _count_lbl != null and not st.is_empty():
		_count_lbl.text = str(int(st["n"]))
	if _view != null:
		_view.queue_redraw()


func _physics_process(delta: float) -> void:
	if st.is_empty() or finished or failed or get_tree().paused:
		return
	_anim_t += delta
	var reps: int = 6 if fast else 1
	for k: int in reps:
		if fast and auto_retry:
			bot_step()
		st["x"] = move_toward(float(st["x"]), target_x, delta * 3.2)
		var ev: Array = M.step(st, delta)
		for e: Variant in ev:
			var a: int = int(e["after"])
			var b: int = int(e["before"])
			if a != b:
				_pops.append({"t": 0.8, "txt": ("+%d" % (a - b)) if a > b else ("%d" % (a - b)), "good": a > b})
				_sfx("coin" if a > b else "hurt", -8.0)
		time_in_level += delta
		if bool(st["won"]) or bool(st["lost"]):
			break
	for p: Variant in _pops:
		p["t"] = float(p["t"]) - delta
	_pops = _pops.filter(func(p: Dictionary) -> bool: return float(p["t"]) > 0.0)
	_refresh()
	if bool(st["won"]):
		_finish()
	elif bool(st["lost"]):
		_lose()


# ------------------------------------------------------------------ dibujo

func _sx(x: float) -> float:
	return _view.size.x * 0.5 + x * _view.size.x * 0.42


func _draw_view() -> void:
	if st.is_empty():
		return
	var sz: Vector2 = _view.size
	var base_y: float = sz.y * 0.78
	## Carretera con rayas que pasan.
	_view.draw_rect(Rect2(Vector2(sz.x * 0.06, 0), Vector2(sz.x * 0.88, sz.y)), Color("#c9cfd8"))
	var off: float = fmod(float(st["d"]) * PX_PER_M, 80.0)
	for k: int in int(sz.y / 80.0) + 2:
		_view.draw_rect(Rect2(Vector2(sz.x * 0.5 - 4, float(k) * 80.0 + off - 80.0), Vector2(8, 40)), Color(1, 1, 1, 0.7))
	var tr: Array = st["track"]
	for i: int in range(int(st["i"]), tr.size()):
		var e: Dictionary = tr[i]
		var y: float = base_y - (float(e.get("d", 0)) - float(st["d"])) * PX_PER_M
		if y < -200.0:
			break
		match str(e.get("t", "")):
			"gate":
				for side: String in ["l", "r"]:
					var op: String = str(e.get(side, ""))
					var good: bool = op.begins_with("+") or op.begins_with("x")
					var cx: float = _sx(-M.LANE_X if side == "l" else M.LANE_X)
					var r: Rect2 = Rect2(Vector2(cx - sz.x * 0.19, y - 50), Vector2(sz.x * 0.38, 70))
					_view.draw_rect(r, Color(0.25, 0.55, 1.0, 0.55) if good else Color(1.0, 0.3, 0.3, 0.55))
					_view.draw_rect(r, Color.WHITE, false, 4.0)
					var tw: float = _font.get_string_size(op, HORIZONTAL_ALIGNMENT_LEFT, -1, 46).x
					_view.draw_string(_font, Vector2(cx - tw * 0.5, y), op, HORIZONTAL_ALIGNMENT_LEFT, -1, 46, Color.WHITE)
			"enemy":
				_crowd(Vector2(sz.x * 0.5, y), int(e.get("n", 0)), Color("#e05a4f"), sz.x * 0.35)
				var en: String = str(int(e.get("n", 0)))
				var ew: float = _font.get_string_size(en, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
				_view.draw_string(_font, Vector2(sz.x * 0.5 - ew * 0.5, y - 70), en, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color("#ffffff"))
			"trap":
				var tx: float = _sx(-M.LANE_X if str(e.get("lane", "l")) == "l" else M.LANE_X)
				var a: float = _anim_t * 8.0
				_view.draw_circle(Vector2(tx, y), 34.0, Color("#6b7280"))
				for s: int in 8:
					var ang: float = a + TAU * float(s) / 8.0
					_view.draw_colored_polygon(PackedVector2Array([Vector2(tx, y) + Vector2(cos(ang - 0.2), sin(ang - 0.2)) * 30.0,
						Vector2(tx, y) + Vector2(cos(ang), sin(ang)) * 46.0, Vector2(tx, y) + Vector2(cos(ang + 0.2), sin(ang + 0.2)) * 30.0]), Color("#9aa4b5"))
			"boss":
				_view.draw_rect(Rect2(Vector2(sz.x * 0.2, y - 160), Vector2(sz.x * 0.6, 160)), Color("#8c96a8"))
				for k2: int in 5:
					_view.draw_rect(Rect2(Vector2(sz.x * 0.2 + float(k2) * sz.x * 0.13, y - 190), Vector2(sz.x * 0.08, 30)), Color("#8c96a8"))
				var bn: String = str(int(e.get("n", 0)))
				var bw: float = _font.get_string_size(bn, HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x
				_view.draw_string(_font, Vector2(sz.x * 0.5 - bw * 0.5, y - 60), bn, HORIZONTAL_ALIGNMENT_LEFT, -1, 64, Color("#e05a4f"))
	_crowd(Vector2(_sx(float(st["x"])), base_y), int(st["n"]), Color("#4b5bd6"), sz.x * 0.3)
	var nt: String = str(int(st["n"]))
	var nw: float = _font.get_string_size(nt, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
	_view.draw_string(_font, Vector2(_sx(float(st["x"])) - nw * 0.5, base_y + 110), nt, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color.WHITE)
	var py: float = base_y - 120.0
	for p: Variant in _pops:
		var txt: String = str(p["txt"])
		_view.draw_string(_font, Vector2(_sx(float(st["x"])) + 60, py - (0.8 - float(p["t"])) * 80.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 44,
			Color("#5bd17a") if bool(p["good"]) else Color("#ff6b6b"))


## Un grupo: hasta 80 munecos en espiral (y el numero dice cuantos son de verdad).
func _crowd(c: Vector2, n: int, col: Color, max_r: float) -> void:
	var shown: int = mini(n, 80)
	for k: int in shown:
		var r: float = sqrt(float(k)) * 9.0
		if r > max_r:
			break
		var a: float = float(k) * 2.4
		var p: Vector2 = c + Vector2(cos(a), sin(a) * 0.6) * r
		var bob: float = sin(_anim_t * 14.0 + float(k)) * 2.0
		_view.draw_circle(p + Vector2(0, bob), 8.0, col)
		_view.draw_circle(p + Vector2(0, bob - 9.0), 5.0, Color("#f1c27d"))


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = int(st["n"]) * 100
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "left": int(st["n"]), "time": snappedf(time_in_level, 0.1)})
	Audio.play("win")
	Audio.play_track("victoria", false)
	coins = stars
	coins_total = 3
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


## Estrellas por la gente que sobra frente a lo mejor posible.
func stars_earned() -> int:
	var b: Dictionary = M.best(level)
	var best_left: int = maxi(1, int(b["end"]) - int(b["boss"]))
	var ratio: float = float(st["n"]) / float(best_left)
	return 3 if ratio >= 0.8 else (2 if ratio >= 0.4 else 1)


func _lose() -> void:
	if failed:
		return
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "crowd", "d": float(st["d"]), "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("cr_lost", "\u00a1Os han superado!"), Kit.text("cr_lost_hint", "Pasa por las puertas que m\u00e1s suman y esquiva las trampas: el jefe te espera al final."))
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
		"crowd": int(st.get("n", 0)), "d": float(st.get("d", 0.0))}
