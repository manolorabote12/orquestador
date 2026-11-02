extends Node2D
## Hexa sort: arrastra (o toca y toca) una de las 3 pilas de hexagonos a una casilla libre. Las
## vecinas con el mismo color arriba se le juntan en cadena y 10 iguales se limpian. Ganas al
## llegar a la meta; pierdes si se llena el tablero. Ayuda: MARTILLO (rompe una pila).
## Reglas, reparto, bot y analizador en hexa_map.gd (logica pura). Lo que pasa en la cadena se
## ve paso a paso: la vista va un poco por detras del estado y lo alcanza ficha a ficha.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const M = preload("res://kit/hexa/hexa_map.gd")
const AREA: Rect2 = Rect2(30, 200, 660, 700)
const TRAY_Y: float = 1010.0
const STEP: float = 0.14
const SQ3: float = 1.7320508
## Tablero visto en diagonal: los hexagonos se aplastan en vertical y las filas se juntan igual.
const FLAT: float = 0.66
const COLS: Array[Color] = [Color("#e53950"), Color("#1fb6d9"), Color("#f5b301"), Color("#43a047"), Color("#8e5cd9"),
	Color("#ff7a1a"), Color("#ec5fa4"), Color("#2f6fd0")]

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
var helps_used: int = 0

var _world: Node2D
var _camera: Camera2D
var _goal_lbl: Label
var _hammer_btn: Button
var _bar: ProgressBar
var _bot: bool = false
var _bot_t: float = 0.0
var _t: float = 0.0
var _r: float = 48.0
var _origin: Vector2 = Vector2.ZERO
## Lo que se ve (va por detras del estado): pilas, cola de pasos y fichas en el aire.
var _disp: Dictionary = {}
var _queue: Array = []
var _step_t: float = 0.0
var _fly: Array = []
var _pops: Array = []
var _shown_cleared: int = 0
var _sel: int = -1
var _drag: bool = false
var _drag_p: Vector2 = Vector2.ZERO
var _hammer_mode: bool = false


func _ready() -> void:
	level = Kit.current_level()
	par = float(level.get("par", 0))
	RenderingServer.set_default_clear_color(Kit.color("sky", Color("#2b2d52")).darkened(0.25))
	_world = Node2D.new()
	_world.name = "World"
	_world.draw.connect(_draw_world)
	add_child(_world)
	_camera = Camera2D.new()
	add_child(_camera)
	_camera.make_current()
	_camera.position = Vector2(360, 640)
	Juice.register_camera(_camera)
	_build_hud()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "hexa", "cells": (st["cells"] as Dictionary).size()})


func bot_script() -> String:
	return "res://qa/hexa_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(5.0, 4.0)


func wants_grade() -> bool:
	return false


func _reset() -> void:
	finished = false
	failed = false
	var lv: Dictionary = level.duplicate()
	if deaths > 0:
		var rows: Array = []
		for r: Variant in level.get("map", []):
			if not (str(r).begins_with("#") and str(r).substr(1).is_valid_int()):
				rows.append(r)
		rows.append("#%d" % (int(M.parse(level)["seed"]) + deaths * 131))
		lv["map"] = rows
	st = M.new_state(lv)
	(st["events"] as Array).clear()
	coins_total = int(st["goal"]) / M.CLEAR
	coins = 0
	helps_used = 0
	time_in_level = 0.0
	_disp = (st["cells"] as Dictionary).duplicate(true)
	_queue.clear()
	_fly.clear()
	_pops.clear()
	_shown_cleared = 0
	_sel = -1
	_drag = false
	_hammer_mode = false
	_layout()
	_refresh()


func _layout() -> void:
	var w: int = 1
	var h: int = 1
	for c: Vector2i in st["cells"]:
		w = maxi(w, c.x + 1)
		h = maxi(h, c.y + 1)
	for c2: Vector2i in st["stones"]:
		w = maxi(w, c2.x + 1)
		h = maxi(h, c2.y + 1)
	_r = minf(52.0, minf(AREA.size.x / (SQ3 * (float(w) + 0.5)), AREA.size.y / (1.5 * FLAT * float(h - 1) + 2.4)))
	var size: Vector2 = Vector2(SQ3 * _r * (float(w) - 0.5), 1.5 * FLAT * _r * float(h - 1))
	_origin = AREA.get_center() - size * 0.5 + Vector2(0, _r * 0.3)


func cell_pos(c: Vector2i) -> Vector2:
	return _origin + Vector2(SQ3 * _r * (float(c.x) + (0.5 if c.y % 2 == 1 else 0.0)), 1.5 * FLAT * _r * float(c.y))


func offer_pos(i: int) -> Vector2:
	return Vector2(180.0 + 180.0 * float(i), TRAY_Y)


func cell_at(p: Vector2) -> Vector2i:
	var best: Vector2i = Vector2i(-1, -1)
	var bd: float = _r * 0.95
	for c: Vector2i in st["cells"]:
		var v: Vector2 = p - cell_pos(c)
		var d: float = Vector2(v.x, v.y / FLAT).length()
		if d < bd:
			bd = d
			best = c
	return best


# ------------------------------------------------------------------ interfaz

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
	var safe: MarginContainer = UI.safe_root(root, 16.0)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col: VBoxContainer = VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 8)
	safe.add_child(col)
	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 12)
	col.add_child(top)
	var title: Label = Label.new()
	title.text = str(level.get("name", Kit.text("level", "Nivel")))
	title.add_theme_font_size_override("font_size", 34)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	top.add_child(title)
	_goal_lbl = Label.new()
	_goal_lbl.name = "Goal"
	_goal_lbl.add_theme_font_size_override("font_size", 30)
	top.add_child(_goal_lbl)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)
	_bar = ProgressBar.new()
	_bar.name = "GoalBar"
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 18)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_bar)
	var grow: Control = Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(grow)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row)
	_hammer_btn = UI.make_button("", false)
	_hammer_btn.name = "BtnHammer"
	_hammer_btn.custom_minimum_size = Vector2(300, 88)
	_hammer_btn.pressed.connect(toggle_hammer)
	row.add_child(_hammer_btn)


func _refresh() -> void:
	var goal: int = int(st["goal"])
	_goal_lbl.text = "%d/%d" % [mini(_shown_cleared, goal), goal]
	_bar.max_value = goal
	_bar.value = mini(_shown_cleared, goal)
	_hammer_btn.text = (Kit.text("hx_cancel", "Cancelar") if _hammer_mode else Kit.text("hx_hammer", "Martillo")) + " (%d)" % int(st["hammer"])
	_hammer_btn.disabled = int(st["hammer"]) <= 0 or finished
	_hammer_btn.visible = not _bot
	_world.queue_redraw()


# ------------------------------------------------------------------ jugar

func can_act() -> bool:
	return not finished and is_inside_tree() and not get_tree().paused and _queue.is_empty() and _fly.is_empty()


func offer_at(p: Vector2) -> int:
	for i: int in (st["offer"] as Array).size():
		if st["offer"][i] != null and offer_pos(i).distance_to(p) < 80.0:
			return i
	return -1


## Toque en el mundo: elige pila, la pone en una casilla o, con el martillo, rompe una pila.
func tap(p: Vector2) -> void:
	if not can_act():
		return
	var o: int = offer_at(p)
	if o >= 0:
		_hammer_mode = false
		_sel = o
		_sfx("click", -12.0, 1.2)
		_refresh()
		return
	var c: Vector2i = cell_at(p)
	if c.x < 0:
		return
	if _hammer_mode:
		use_hammer(c)
		return
	if _sel >= 0:
		drop(_sel, c)


func drop(i: int, c: Vector2i) -> void:
	if not can_act():
		return
	if M.place(st, i, c):
		_sel = -1
		_sfx("click", -8.0, 0.9)
		Juice.vibrate(10)
		_pull_events()
	else:
		_sfx("click", -14.0, 0.5)


func toggle_hammer() -> void:
	if not can_act() or int(st["hammer"]) <= 0:
		return
	_hammer_mode = not _hammer_mode
	_sel = -1
	_refresh()


func use_hammer(c: Vector2i) -> void:
	if M.hammer(st, c):
		helps_used += 1
		_hammer_mode = false
		_sfx("hit", -4.0, 0.8)
		Juice.shake(0.15)
		_pull_events()


## Pasa los eventos del estado a la cola de la vista (se ven de uno en uno).
func _pull_events() -> void:
	for e: Dictionary in st["events"]:
		_queue.append(e)
	(st["events"] as Array).clear()
	if fast:
		while not _queue.is_empty():
			_apply(_queue.pop_front())
		_fly.clear()
	_refresh()


func _apply(e: Dictionary) -> void:
	match str(e["kind"]):
		"place":
			_disp[e["cell"]] = (e["stack"] as Array).duplicate()
		"move":
			var src: Array = _disp[e["from"]]
			var dst: Array = _disp[e["to"]]
			for k: int in int(e["n"]):
				dst.append(src.pop_back())
			if not fast:
				_fly.append({"from": cell_pos(e["from"]), "fh": src.size(), "to": e["to"], "n": int(e["n"]), "color": int(e["color"]), "t": 0.0})
			_sfx("click", -12.0, 1.0 + 0.05 * float(int(e["n"])))
		"clear":
			var s: Array = _disp[e["cell"]]
			for k2: int in int(e["n"]):
				s.pop_back()
			_shown_cleared += int(e["n"])
			coins = _shown_cleared / M.CLEAR
			_sfx("coin", -4.0, 1.0 + 0.08 * float(coins % 5))
			if not fast:
				_pops.append({"p": cell_pos(e["cell"]), "color": int(e["color"]), "h": s.size(), "t": 0.0})
				Juice.burst(self, cell_pos(e["cell"]), COLS[int(e["color"]) % COLS.size()], 18)
		"hammer":
			_disp[e["cell"]] = []
			if not fast:
				Juice.burst(self, cell_pos(e["cell"]), Color("#c9b996"), 16)
		"stuck":
			_sfx("click", -8.0, 0.5)
		"end":
			if bool(e["won"]):
				_finish.call_deferred()
			else:
				_lose.call_deferred()
	_refresh()


func _sfx(n: String, vol: float = -10.0, pitch: float = 1.0) -> void:
	if not fast:
		Audio.play(n, 0.05, vol, pitch)


func bot_step() -> void:
	_bot = true


func _physics_process(delta: float) -> void:
	_t += delta
	## La vista alcanza al estado paso a paso.
	if not _queue.is_empty():
		_step_t -= delta
		if _step_t <= 0.0:
			var e: Dictionary = _queue.pop_front()
			_apply(e)
			_step_t = STEP if str(e["kind"]) in ["move", "clear"] else 0.02
	for f: Dictionary in _fly:
		f["t"] = float(f["t"]) + delta / STEP
	_fly = _fly.filter(func(f: Dictionary) -> bool: return float(f["t"]) < 1.0)
	for p: Dictionary in _pops:
		p["t"] = float(p["t"]) + delta
	_pops = _pops.filter(func(p: Dictionary) -> bool: return float(p["t"]) < 0.35)
	if finished:
		_world.queue_redraw()
		return
	time_in_level += delta
	if fast and auto_retry:
		_bot = true
	if _bot and can_act():
		_bot_t -= delta
		if fast or _bot_t <= 0.0:
			_bot_t = 0.45
			var m: Dictionary = M.bot_move(st)
			if m.has("hammer"):
				use_hammer(m["hammer"])
			elif m.has("offer"):
				drop(int(m["offer"]), m["cell"])
	if is_instance_valid(_hammer_btn):
		var pulse: float = 0.75 + 0.25 * sin(_t * 9.0) if bool(st["stuck"]) else 1.0
		_hammer_btn.modulate = Color(1, pulse, pulse)
	_world.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()
		return
	var pos: Vector2 = Vector2.ZERO
	var kind: int = 0
	if event is InputEventScreenTouch:
		kind = 1 if (event as InputEventScreenTouch).pressed else 2
		pos = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		kind = 1 if (event as InputEventMouseButton).pressed else 2
		pos = (event as InputEventMouseButton).position
	elif event is InputEventScreenDrag or event is InputEventMouseMotion:
		if _drag:
			_drag_p = get_canvas_transform().affine_inverse() * (event as InputEvent).get("position")
			_world.queue_redraw()
		return
	if kind == 0:
		return
	_bot = false
	var w: Vector2 = get_canvas_transform().affine_inverse() * pos
	if kind == 1:
		var o: int = offer_at(w) if can_act() else -1
		if o >= 0:
			_drag = true
			_drag_p = w
		tap(w)
	elif kind == 2 and _drag:
		_drag = false
		## Soltar encima de una casilla libre la pone; si no, la pila queda elegida.
		var c: Vector2i = cell_at(w)
		if c.x >= 0 and _sel >= 0 and offer_at(w) < 0:
			drop(_sel, c)
		_world.queue_redraw()


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = maxi(1, int(st["cleared"]) * 10 + maxi(0, int(par - time_in_level)) * 5 - helps_used * 150)
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "time": snappedf(time_in_level, 0.1), "helps": helps_used})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


func stars_earned() -> int:
	if deaths > 0 or helps_used >= 2:
		return 1
	return 3 if helps_used == 0 else 2


func _lose() -> void:
	if finished:
		return
	finished = true
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "board_full", "cleared": int(st["cleared"]), "deaths": deaths})
	Audio.play("hurt")
	Juice.shake(0.3)
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("hx_lost", "\u00a1Tablero lleno!"),
		Kit.text("hx_fail_hint", "Pon cada pila junto a las de su color de arriba y deja huecos libres: las pilas revueltas, ap\u00e1rtalas a una esquina."))
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
	if st.is_empty():
		return {}
	return {"deaths": deaths, "coins": coins, "finished": finished, "failed": failed, "time": time_in_level,
		"cleared": int(st["cleared"]), "goal": int(st["goal"]), "empty": M.empty_cells(st).size(), "helps": helps_used}


# ------------------------------------------------------------------ dibujo

func _hex(c: Vector2, r: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for k: int in 6:
		var a: float = PI / 6.0 + float(k) * PI / 3.0
		pts.append(c + Vector2(cos(a), sin(a) * FLAT) * r)
	return pts


## Una pila: fichas planas de abajo arriba (cada una un poco mas alta) y el numero del color de arriba.
func _draw_stack(s: Array, c: Vector2, r: float, hide_top: int = 0, alpha: float = 1.0) -> void:
	var th: float = r * 0.16
	var n: int = s.size() - hide_top
	for j: int in n:
		var col: Color = COLS[int(s[j]) % COLS.size()]
		var p: Vector2 = c - Vector2(0, float(j) * th)
		_world.draw_colored_polygon(_hex(p + Vector2(0, th * 0.9), r * 0.92), Color(col.darkened(0.45), alpha))
		_world.draw_colored_polygon(_hex(p, r * 0.92), Color(col, alpha))
		_world.draw_colored_polygon(_hex(p - Vector2(0, r * 0.06), r * 0.6), Color(col.lightened(0.18), alpha))
	if n > 0 and alpha >= 1.0:
		var run: int = 0
		for j2: int in range(n - 1, -1, -1):
			if int(s[j2]) != int(s[n - 1]):
				break
			run += 1
		var f: Font = UI.font if UI.font != null else ThemeDB.fallback_font
		var at: Vector2 = c - Vector2(0, float(n - 1) * th)
		var txt: String = str(run)
		var fs: int = int(r * 0.5)
		var w: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		_world.draw_string_outline(f, at + Vector2(-w * 0.5, fs * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0, 0, 0, 0.6))
		_world.draw_string(f, at + Vector2(-w * 0.5, fs * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


func _draw_world() -> void:
	if st.is_empty():
		return
	## Casillas del tablero (las libres se iluminan si hay una pila elegida).
	var lit: bool = _sel >= 0
	var cells: Array = (st["cells"] as Dictionary).keys()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	for c: Vector2i in cells:
		var p: Vector2 = cell_pos(c)
		_world.draw_colored_polygon(_hex(p + Vector2(0, _r * 0.12), _r * 0.98), Color(0, 0, 0, 0.35))
		var base: Color = Color("#4b4f86")
		if lit and (_disp.get(c, []) as Array).is_empty():
			base = base.lerp(Color("#8be0ff"), 0.25 + 0.15 * sin(_t * 6.0))
		_world.draw_colored_polygon(_hex(p, _r * 0.98), base)
		_world.draw_colored_polygon(_hex(p, _r * 0.8), base.darkened(0.15))
	for s: Vector2i in st["stones"]:
		var ps: Vector2 = cell_pos(s)
		_world.draw_colored_polygon(_hex(ps + Vector2(0, _r * 0.12), _r * 0.98), Color(0, 0, 0, 0.35))
		_world.draw_colored_polygon(_hex(ps, _r * 0.98), Color("#7a7468"))
		_world.draw_colored_polygon(_hex(ps - Vector2(0, _r * 0.08), _r * 0.7), Color("#958e80"))
	## Pilas (de arriba abajo en pantalla: las de delante tapan a las de detras).
	var hide: Dictionary = {}
	for f: Dictionary in _fly:
		hide[f["to"]] = int(hide.get(f["to"], 0)) + int(f["n"])
	for c2: Vector2i in cells:
		var s2: Array = _disp.get(c2, [])
		if not s2.is_empty():
			_draw_stack(s2, cell_pos(c2), _r, int(hide.get(c2, 0)))
	## Fichas en el aire: saltan en arco de una pila a otra.
	var th: float = _r * 0.16
	for f2: Dictionary in _fly:
		var t: float = clampf(float(f2["t"]), 0.0, 1.0)
		var dst: Array = _disp.get(f2["to"], [])
		for k: int in int(f2["n"]):
			var a: Vector2 = (f2["from"] as Vector2) - Vector2(0, float(int(f2["fh"]) + k) * th)
			var b: Vector2 = cell_pos(f2["to"]) - Vector2(0, float(dst.size() - int(f2["n"]) + k) * th)
			var tt: float = clampf(t * 1.3 - float(k) * 0.06, 0.0, 1.0)
			var q: Vector2 = a.lerp(b, tt) - Vector2(0, sin(tt * PI) * _r * 0.9)
			_world.draw_colored_polygon(_hex(q + Vector2(0, th * 0.9), _r * 0.92), COLS[int(f2["color"]) % COLS.size()].darkened(0.45))
			_world.draw_colored_polygon(_hex(q, _r * 0.92), COLS[int(f2["color"]) % COLS.size()])
	## Torres que se limpian: un hexagono que crece y se apaga.
	for p2: Dictionary in _pops:
		var g: float = float(p2["t"]) / 0.35
		var at: Vector2 = (p2["p"] as Vector2) - Vector2(0, float(int(p2["h"])) * th + g * 40.0)
		_world.draw_colored_polygon(_hex(at, _r * (0.9 + g * 0.8)), Color(COLS[int(p2["color"]) % COLS.size()].lightened(0.3), 1.0 - g))
	## Bandeja con las 3 pilas para elegir.
	var tray: Rect2 = Rect2(Vector2(40, TRAY_Y - 110.0), Vector2(640, 190))
	_round(Rect2(tray.position + Vector2(0, 6), tray.size), 26.0, Color(0, 0, 0, 0.3))
	_round(tray, 26.0, Color("#3a3c6a"))
	var rt: float = minf(_r, 46.0)
	for i: int in (st["offer"] as Array).size():
		var o: Variant = st["offer"][i]
		var at2: Vector2 = offer_pos(i) + Vector2(0, 40)
		_world.draw_colored_polygon(_hex(at2 + Vector2(0, 6), rt * 1.05), Color(0, 0, 0, 0.25))
		if o == null:
			continue
		if i == _sel:
			at2.y -= 16.0 + 4.0 * sin(_t * 8.0)
			if _drag:
				at2 = _drag_p + Vector2(0, -30)
		_draw_stack(o, at2, rt if not (i == _sel and _drag) else _r)
	if _hammer_mode:
		var f3: Font = UI.font if UI.font != null else ThemeDB.fallback_font
		var msg: String = Kit.text("hx_hammer_hint", "Toca la pila que quieres romper")
		var w3: float = f3.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
		_world.draw_string_outline(f3, Vector2(360.0 - w3 * 0.5, AREA.position.y - 6.0), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, 8, Color(0, 0, 0, 0.8))
		_world.draw_string(f3, Vector2(360.0 - w3 * 0.5, AREA.position.y - 6.0), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("#ffd23f"))


func _round(r: Rect2, rad: float, col: Color) -> void:
	rad = minf(rad, minf(r.size.x, r.size.y) * 0.5)
	var pts: PackedVector2Array = PackedVector2Array()
	var corners: Array = [[r.end - Vector2(rad, rad), 0.0], [Vector2(r.position.x + rad, r.end.y - rad), PI * 0.5],
		[r.position + Vector2(rad, rad), PI], [Vector2(r.end.x - rad, r.position.y + rad), PI * 1.5]]
	for c: Array in corners:
		for k: int in 5:
			var a: float = float(c[1]) + float(k) / 4.0 * PI * 0.5
			pts.append((c[0] as Vector2) + Vector2(cos(a), sin(a)) * rad)
	_world.draw_colored_polygon(pts, col)
