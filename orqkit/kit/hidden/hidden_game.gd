extends Node2D
## Buscar objetos: toca en la escena las figuras de la lista de abajo. Pistas con el boton de la
## lupa; fallos y tiempo contados en los niveles altos. Reglas, bot y analizador en hidden_map.gd.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const M = preload("res://kit/hidden/hidden_map.gd")
const Draw = preload("res://kit/spotdiff/scene_draw.gd")

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
var _marks: Array = []
var _t: float = 0.0


func _ready() -> void:
	level = Kit.current_level()
	RenderingServer.set_default_clear_color(Color("#1d2433"))
	_build_hud()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "hidden", "targets": coins_total})


func bot_script() -> String:
	return "res://qa/hidden_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(2.5, 1.6)


func wants_grade() -> bool:
	return false


func _reset() -> void:
	finished = false
	failed = false
	st = M.new_state(level)
	coins_total = (st["targets"] as Array).size()
	coins = 0
	time_in_level = 0.0
	_marks.clear()
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
	_info.add_theme_font_size_override("font_size", 28)
	top.add_child(_info)
	_hint_btn = UI.make_button("", false, "star")
	_hint_btn.name = "BtnHint"
	_hint_btn.pressed.connect(hint)
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


## Rectangulo de la escena y de la tira de abajo dentro de la vista.
func _scene_rect() -> Rect2:
	var sz: Vector2 = _view.size
	var strip: float = clampf(sz.y * 0.16, 110.0, 170.0)
	var w: float = minf(sz.x - 8.0, (sz.y - strip - 16.0) / 1.15)
	return Rect2(Vector2((sz.x - w) * 0.5, 4.0), Vector2(w, w * 1.15))


func _strip_rect() -> Rect2:
	var s: Rect2 = _scene_rect()
	return Rect2(Vector2(4.0, s.end.y + 12.0), Vector2(_view.size.x - 8.0, _view.size.y - s.end.y - 16.0))


## Toque en coordenadas de la escena (0-1, con y escalada a la altura de la escena).
func tap_at(p: Vector2) -> void:
	if not can_act():
		return
	var r: String = M.tap(st, p)
	var s: Rect2 = _scene_rect()
	_marks.append({"p": p, "ok": r == "found", "t": 0.0})
	if r == "found":
		coins = (st["found"] as Array).size()
		_sfx("coin", -6.0)
		if not fast:
			UI.float_text(self, _view.global_position + s.position + Vector2(p.x * s.size.x, p.y * s.size.y), "+1", UI.colors["exito"], 30)
	elif r == "miss":
		_sfx("hurt", -12.0)
	_refresh()
	if bool(st["won"]):
		_finish()
	elif bool(st["lost"]):
		_lose()


func hint() -> void:
	if can_act() and M.use_hint(st) >= 0:
		_sfx("powerup", -8.0)
		_refresh()


func bot_step() -> void:
	if can_act():
		var p: Vector2 = M.bot_point(st)
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
	var s: Rect2 = _scene_rect()
	if not s.has_point(p):
		return
	tap_at(Vector2((p.x - s.position.x) / s.size.x, (p.y - s.position.y) / s.size.y))


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
	var txt: String = Kit.text("ho_found", "Encontradas {a}/{b}").format({"a": coins, "b": coins_total})
	if float(st["time"]) > 0.0:
		txt += "   " + str(int(ceilf(maxf(0.0, float(st["time"]) - float(st["elapsed"]))))) + " s"
	if int(st["max_misses"]) > 0:
		txt += "\n" + Kit.text("ho_misses", "Fallos {a}/{b}").format({"a": int(st["misses"]), "b": int(st["max_misses"])})
	_info.text = txt
	_hint_btn.text = " " + str(int(st["hints"]))
	_hint_btn.disabled = int(st["hints"]) <= 0
	_view.queue_redraw()


func _physics_process(delta: float) -> void:
	if st.is_empty() or get_tree().paused:
		return
	_t += delta
	if not finished and not failed:
		var dt: float = delta * (8.0 if fast else 1.0)
		time_in_level += dt
		var before: int = int(ceilf(float(st["time"]) - float(st["elapsed"])))
		M.step(st, dt)
		if int(ceilf(float(st["time"]) - float(st["elapsed"]))) != before:
			_refresh()
		if bool(st["lost"]):
			_lose()
		elif fast and auto_retry:
			bot_step()
	for m: Variant in _marks:
		(m as Dictionary)["t"] = float((m as Dictionary)["t"]) + delta
	_marks = _marks.filter(func(m: Dictionary) -> bool: return bool(m["ok"]) or float(m["t"]) < 0.6)
	_view.queue_redraw()


# ------------------------------------------------------------------ dibujo

func _draw_view() -> void:
	if st.is_empty():
		return
	var s: Rect2 = _scene_rect()
	_view.draw_rect(s.grow(6.0), Color("#0d1018"))
	## La escena se dibuja en un cuadro (x e y de 0 a 1 sobre el ancho; la altura extra es suelo).
	Draw.draw_scene(_view, s, level, st["shapes"])
	var found: Array = st["found"]
	for m: Variant in _marks:
		var md: Dictionary = m
		var c: Vector2 = s.position + Vector2(md["p"]) * s.size
		if bool(md["ok"]):
			var k: float = clampf(float(md["t"]) * 4.0, 0.0, 1.0)
			_view.draw_arc(c, 34.0 + 10.0 * (1.0 - k), 0.0, TAU * k, 32, UI.colors["exito"], 6.0)
		else:
			var a: float = 1.0 - float(md["t"]) / 0.6
			_view.draw_line(c + Vector2(-16, -16), c + Vector2(16, 16), Color(1, 0.25, 0.2, a), 6.0)
			_view.draw_line(c + Vector2(16, -16), c + Vector2(-16, 16), Color(1, 0.25, 0.2, a), 6.0)
	if int(st["hinted"]) >= 0:
		var hs: Dictionary = st["shapes"][int(st["hinted"])]
		var hc: Vector2 = s.position + Vector2(float(hs["x"]), float(hs["y"])) * s.size
		var pr: float = M.radius(hs) * s.size.x * (1.6 + 0.3 * sin(_t * 6.0))
		_view.draw_arc(hc, pr, 0.0, TAU, 40, Color(1, 0.9, 0.2, 0.9), 5.0)
	## Tira de abajo: lo que hay que encontrar (tachado al encontrarlo).
	var strip: Rect2 = _strip_rect()
	_view.draw_rect(strip, Color("#2a3245"))
	var targets: Array = st["targets"]
	var n: int = maxi(1, targets.size())
	var cell: float = minf(strip.size.x / float(n), strip.size.y)
	var x0: float = strip.position.x + (strip.size.x - cell * float(n)) * 0.5
	for k2: int in targets.size():
		var i: int = int(targets[k2])
		var box: Rect2 = Rect2(Vector2(x0 + cell * float(k2), strip.position.y + (strip.size.y - cell) * 0.5), Vector2(cell, cell)).grow(-6.0)
		_view.draw_rect(box, Color("#f4f1e8") if not found.has(i) else Color("#9fb49a"))
		var icon: Dictionary = (st["shapes"][i] as Dictionary).duplicate()
		icon["x"] = 0.5
		icon["y"] = 0.5
		icon["s"] = 0.62
		Draw.draw_shape(_view, box, icon, Color("#f4f1e8"))
		if found.has(i):
			_view.draw_line(box.position + Vector2(8, box.size.y * 0.55), box.position + Vector2(box.size.x * 0.4, box.size.y - 10), UI.colors["exito"], 7.0)
			_view.draw_line(box.position + Vector2(box.size.x * 0.4, box.size.y - 10), box.end - Vector2(8, box.size.y - 10), UI.colors["exito"], 7.0)


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var left: float = maxf(0.0, float(st["time"]) - float(st["elapsed"])) if float(st["time"]) > 0.0 else 0.0
	var score: int = maxi(1, coins_total * 100 - int(st["misses"]) * 25 + int(left) * 10)
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "coins": coins, "misses": int(st["misses"]), "time": snappedf(time_in_level, 0.1)})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


## Estrellas: sin fallos ni pistas, 3; con pocos fallos, 2; si no, 1.
func stars_earned() -> int:
	var used: int = int(level.get("hints", 2)) - int(st["hints"])
	if int(st["misses"]) == 0 and used == 0:
		return 3
	return 2 if int(st["misses"]) <= 2 else 1


func _lose() -> void:
	if failed:
		return
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "hidden", "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var title: String = Kit.text("ho_time", "\u00a1Se acab\u00f3 el tiempo!") if float(st["time"]) > 0.0 and float(st["elapsed"]) >= float(st["time"]) else Kit.text("ho_lost", "Demasiados fallos")
	var p: FailPanel = FailPanel.open(self, title, Kit.text("ho_hint", "Mira la forma de cada figura de la lista, no su color, y usa la lupa si te atascas."))
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
		"misses": int(st.get("misses", 0))}
