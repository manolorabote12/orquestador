extends Node2D
## Fusion de frutas (tipo juego de la sandia): mueve el dedo para colocar la fruta y suelta para
## dejarla caer. Dos iguales que se tocan se juntan en la siguiente. Consigue la fruta objetivo
## sin que el tarro rebose. Fisica, bot y analizador en fruitmerge_map.gd (todo va por ticks).
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const M = preload("res://kit/fruitmerge/fruitmerge_map.gd")
const DT: float = 1.0 / float(M.TPS)
## Cereza, fresa, uva, mandarina, caqui, manzana, pera, melocoton, pina, melon y sandia.
const COLS: Array[String] = ["#e63946", "#ff6b6b", "#9d4edd", "#ffa62b", "#f77f00", "#d62828", "#c5e063", "#ffb4a2", "#ffd60a", "#80b918", "#2d6a4f"]

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
var aim_x: float = 180.0

var _view: Control
var _info: Label
var _acc: float = 0.0
var _prev: Dictionary = {}
var _fx: Array = []
var _log_seen: int = 0
var _t: float = 0.0
var _touching: bool = false


func _ready() -> void:
	level = Kit.current_level()
	RenderingServer.set_default_clear_color(Color("#fdf0d5"))
	_build_hud()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "fruitmerge", "goal": int(st["goal"])})


func wants_grade() -> bool:
	return false


func bot_script() -> String:
	return "res://qa/fruitmerge_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(6.0, 3.0)


func _reset() -> void:
	finished = false
	failed = false
	st = M.new_state(level)
	aim_x = float(st["w"]) * 0.5
	time_in_level = 0.0
	_acc = 0.0
	_fx = []
	_prev = {}
	_log_seen = 0
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
	_info = Label.new()
	_info.name = "Info"
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.add_theme_font_size_override("font_size", 30)
	_info.add_theme_color_override("font_color", Color("#3d2c1e"))
	top.add_child(_info)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)


func _refresh() -> void:
	if st.is_empty() or _info == null:
		return
	_info.text = "%d" % int(st["score"])


func can_act() -> bool:
	return not finished and not failed and is_inside_tree() and not get_tree().paused and not bool(st["won"]) and not bool(st["lost"])


## Tarro en pantalla: escala y origen (arriba a la izquierda del tarro).
func _k() -> float:
	return minf(_view.size.x * 0.9 / float(st["w"]), (_view.size.y - 400.0) / M.H)


func _o() -> Vector2:
	var k: float = _k()
	return Vector2((_view.size.x - float(st["w"]) * k) * 0.5, _view.size.y - 60.0 - M.H * k)


func drop_at(x: float) -> void:
	if can_act() and M.drop(st, x):
		_sfx("click", -10.0)


func _on_input(event: InputEvent) -> void:
	if auto_retry or st.is_empty():
		return
	var pos: Vector2 = Vector2.INF
	var pressed: int = -1
	if event is InputEventScreenTouch:
		pos = (event as InputEventScreenTouch).position
		pressed = 1 if (event as InputEventScreenTouch).pressed else 0
	elif event is InputEventScreenDrag:
		pos = (event as InputEventScreenDrag).position
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and not DisplayServer.is_touchscreen_available():
		pos = (event as InputEventMouseButton).position
		pressed = 1 if (event as InputEventMouseButton).pressed else 0
	elif event is InputEventMouseMotion and not DisplayServer.is_touchscreen_available():
		pos = (event as InputEventMouseMotion).position
	if pos == Vector2.INF:
		return
	aim_x = clampf((pos.x - _o().x) / _k(), 0.0, float(st["w"]))
	if pressed == 1:
		_touching = true
	elif pressed == 0 and _touching:
		_touching = false
		drop_at(aim_x)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()


func _sfx(nm: String, vol: float = -6.0) -> void:
	if not fast:
		Audio.play(nm, 0.1, vol)


func _tick() -> void:
	_prev = {}
	for f: Variant in st["fruits"]:
		_prev[int(f["id"])] = f["p"]
	if auto_retry and int(st["cool"]) <= 0:
		aim_x = M.bot_x(st)
		M.drop(st, aim_x)
	M.tick(st)
	_collect_log()
	if bool(st["won"]):
		_finish()
	elif bool(st["lost"]):
		_lose()


func _physics_process(delta: float) -> void:
	if st.is_empty() or get_tree().paused:
		return
	_t += delta
	if not finished and not failed:
		time_in_level += delta
		if fast and auto_retry:
			for k: int in 30:
				if not can_act():
					break
				_tick()
		else:
			_acc += delta
			while _acc >= DT and can_act():
				_acc -= DT
				_tick()
	for f: Variant in _fx:
		(f as Dictionary)["t"] = float((f as Dictionary)["t"]) + delta
	_fx = _fx.filter(func(f: Dictionary) -> bool: return float(f["t"]) < 0.6)
	_refresh()
	_view.queue_redraw()


func _collect_log() -> void:
	var lg: Array = st["log"]
	while _log_seen < lg.size():
		var e: Dictionary = lg[_log_seen]
		_log_seen += 1
		match str(e["k"]):
			"merge":
				_fx.append({"at": e["at"], "t": 0.0, "c": int(e["t"])})
				_sfx("coin", -8.0 + float(int(e["t"])))
				if int(e["t"]) >= 5 and not fast:
					Juice.vibrate(20)
			"mega":
				_fx.append({"at": e["at"], "t": 0.0, "c": 10})
				_sfx("powerup", -2.0)


# ------------------------------------------------------------------ dibujo

func _fruit(c: Vector2, r: float, t: int, mini: bool = false) -> void:
	var col: Color = Color(COLS[t % COLS.size()])
	_view.draw_circle(c + Vector2(0, r * 0.08), r, col.darkened(0.25))
	_view.draw_circle(c, r, col)
	if t == 10:
		for s: int in 5:
			var a: float = -0.9 + 0.45 * float(s)
			_view.draw_arc(c, r * 0.95, a - 0.12 + PI * 0.5, a + 0.12 + PI * 0.5, 6, col.darkened(0.35), r * 0.12)
	_view.draw_circle(c + Vector2(-r * 0.35, -r * 0.38), r * 0.22, Color(1, 1, 1, 0.45))
	## Hojita.
	var top: Vector2 = c + Vector2(0, -r)
	_view.draw_line(top, top + Vector2(r * 0.05, -r * 0.22), Color("#6b4226"), maxf(2.0, r * 0.08))
	_view.draw_colored_polygon(PackedVector2Array([top + Vector2(r * 0.05, -r * 0.15), top + Vector2(r * 0.4, -r * 0.3), top + Vector2(r * 0.15, -r * 0.02)]), Color("#52b788"))
	if mini:
		return
	## Carita.
	var e: float = maxf(2.0, r * 0.1)
	_view.draw_circle(c + Vector2(-r * 0.25, r * 0.0), e, Color("#2b2d42"))
	_view.draw_circle(c + Vector2(r * 0.25, r * 0.0), e, Color("#2b2d42"))
	_view.draw_arc(c + Vector2(0, r * 0.12), r * 0.15, 0.3, PI - 0.3, 8, Color("#2b2d42"), maxf(2.0, r * 0.06))


func _draw_view() -> void:
	if st.is_empty():
		return
	var k: float = _k()
	var o: Vector2 = _o()
	var w: float = float(st["w"])
	var sz: Vector2 = _view.size
	_view.draw_rect(Rect2(Vector2.ZERO, sz), Color("#fdf0d5"))
	for i: int in 14:
		_view.draw_circle(Vector2(fmod(float(i) * 173.0, sz.x), fmod(float(i) * 311.0, sz.y)), 40.0 + float(i % 4) * 18.0, Color(1, 0.85, 0.6, 0.18))
	## Tarro.
	var jar: Rect2 = Rect2(o, Vector2(w, M.H) * k)
	_view.draw_rect(jar.grow(10.0), Color("#c9a66b"))
	_view.draw_rect(jar, Color("#fff8e7"))
	## Linea de rebose.
	var ly: float = o.y + M.LINE * k
	var danger: bool = int(st["over"]) > 0
	var dash: float = 18.0
	var x: float = o.x
	while x < o.x + w * k:
		_view.draw_line(Vector2(x, ly), Vector2(minf(x + dash * 0.6, o.x + w * k), ly), Color("#e63946") if danger and int(_t * 8.0) % 2 == 0 else Color(0.9, 0.3, 0.3, 0.45), 3.0)
		x += dash
	## Frutas (suavizadas entre ticks).
	var alpha: float = clampf(_acc / DT, 0.0, 1.0)
	for f: Variant in st["fruits"]:
		var p: Vector2 = f["p"]
		var pp: Vector2 = _prev.get(int(f["id"]), p)
		_fruit(o + pp.lerp(p, alpha) * k, M.RADII[int(f["t"])] * k, int(f["t"]))
	## Fusiones.
	for fx: Variant in _fx:
		var fd: Dictionary = fx
		var tt: float = float(fd["t"]) / 0.6
		var c: Vector2 = o + (fd["at"] as Vector2) * k
		_view.draw_arc(c, (20.0 + 60.0 * tt) * k, 0.0, TAU, 24, Color(1, 1, 1, 1.0 - tt), 5.0)
	## Fruta en la mano, guia y siguiente.
	if can_act():
		var t: int = int(st["cur"])
		var r: float = M.RADII[t]
		var ax: float = clampf(aim_x, r, w - r)
		var hand: Vector2 = o + Vector2(ax, -r - 14.0) * k
		_view.draw_line(Vector2(hand.x, o.y), Vector2(hand.x, o.y + M.H * k), Color(0.5, 0.4, 0.3, 0.25), 3.0)
		if int(st["cool"]) <= 0:
			_fruit(hand, r * k, t)
	var font: Font = _view.get_theme_font("font", "Label")
	var nx: Vector2 = Vector2(sz.x - 90.0, 205.0)
	_view.draw_string(font, nx + Vector2(-60, -50), Kit.text("fm_next", "Siguiente"), HORIZONTAL_ALIGNMENT_CENTER, 120, 22, Color("#3d2c1e"))
	_fruit(nx, 26.0, int(st["next"]), true)
	var gx: Vector2 = Vector2(90.0, 205.0)
	_view.draw_string(font, gx + Vector2(-60, -50), Kit.text("fm_goal", "Objetivo"), HORIZONTAL_ALIGNMENT_CENTER, 120, 22, Color("#3d2c1e"))
	_fruit(gx, 32.0, int(st["goal"]), true)


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = int(st["score"]) * 10
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "coins": coins, "drops": int(st["drops"]), "time": snappedf(time_in_level, 0.1)})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


## Estrellas segun lo vacio que queda el tarro al conseguirlo.
func stars_earned() -> int:
	var top: float = M.H
	for f: Variant in st["fruits"]:
		top = minf(top, (f["p"] as Vector2).y - M.RADII[int(f["t"])])
	var room: float = (top - M.LINE) / (M.H - M.LINE)
	return 3 if room > 0.45 else (2 if room > 0.2 else 1)


func _lose() -> void:
	if failed:
		return
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "fruitmerge", "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("fm_lost", "\u00a1El tarro ha rebosado!"),
		Kit.text("fm_hint", "Deja las frutas grandes en las esquinas y suelta cada fruta encima de otra igual para que se junten."))
	p.closed.connect(retry)


func retry() -> void:
	_reset()


func open_pause() -> void:
	if finished or get_tree().paused or get_node_or_null("PauseMenu") != null:
		return
	_touching = false
	PauseMenu.open(self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_inside_tree() and not UI.test_mode:
			open_pause()


func bot_state() -> Dictionary:
	return {"deaths": deaths, "coins": coins, "finished": finished, "failed": failed, "stomps": int(st.get("merges", 0)), "time": time_in_level,
		"drops": int(st.get("drops", 0)), "best": int(st.get("best", 0))}
