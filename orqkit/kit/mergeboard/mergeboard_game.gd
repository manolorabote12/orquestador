extends Node2D
## Fusion con pedidos (tipo Gossip Harbor / Merge Mansion): toca los generadores, arrastra objetos
## iguales para fusionarlos y entrega lo que piden los clientes. Reglas, bot y analizador en
## mergeboard_map.gd (catalogo por datos en merge_catalog.json).
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel al acabar.

const M = preload("res://kit/mergeboard/mergeboard_map.gd")
const AD_ENERGY: int = 25
const SAVE_KEY: String = "merge_save"

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
var _top_lbl: Label
var _orders: Control
var _board: Control
var _msg: Label
var _ad_btn: Button
var _drag_from: Vector2i = Vector2i(-1, -1)
var _drag_pos: Vector2 = Vector2.ZERO
var _pop: Dictionary = {}
var _anim_t: float = 0.0
var _think: float = 0.0


func _ready() -> void:
	level = Kit.current_level()
	RenderingServer.set_default_clear_color(Color("#f3e6cf"))
	_font = UI.theme.get_font("font", "Label") if UI.theme != null else ThemeDB.fallback_font
	_build_hud()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "mergeboard", "orders": (st["orders"] as Array).size()})


func bot_script() -> String:
	return "res://qa/mergeboard_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(6.0, 4.0)


func _reset() -> void:
	finished = false
	failed = false
	st = M.new_state(level)
	coins_total = (st["orders"] as Array).size()
	coins = 0
	time_in_level = 0.0
	_drag_from = Vector2i(-1, -1)
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
	_top_lbl = Label.new()
	_top_lbl.name = "Top"
	_top_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top_lbl.add_theme_font_size_override("font_size", 32)
	_top_lbl.add_theme_color_override("font_color", Color("#5a3a20"))
	top.add_child(_top_lbl)
	_ad_btn = UI.make_button("+%d" % AD_ENERGY, false, "play")
	_ad_btn.name = "BtnEnergyAd"
	_ad_btn.pressed.connect(ad_energy)
	top.add_child(_ad_btn)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)
	_orders = Control.new()
	_orders.name = "Orders"
	_orders.custom_minimum_size = Vector2(0.0, 190.0)
	_orders.mouse_filter = Control.MOUSE_FILTER_STOP
	_orders.draw.connect(_draw_orders)
	_orders.gui_input.connect(_on_orders_input)
	col.add_child(_orders)
	_msg = Label.new()
	_msg.name = "Msg"
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg.add_theme_font_size_override("font_size", 26)
	_msg.add_theme_color_override("font_color", Color("#5a3a20"))
	col.add_child(_msg)
	_board = Control.new()
	_board.name = "Board"
	_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board.mouse_filter = Control.MOUSE_FILTER_STOP
	_board.draw.connect(_draw_board)
	_board.gui_input.connect(_on_board_input)
	col.add_child(_board)


# ------------------------------------------------------------------ acciones

func can_act() -> bool:
	return not finished and is_inside_tree() and not get_tree().paused and not st.is_empty()


func tap_cell(c: Vector2i) -> void:
	if not can_act():
		return
	var it: Variant = (st["grid"] as Dictionary).get(c, null)
	if it is Dictionary and (it as Dictionary).has("gen"):
		if int(st["energy"]) <= 0:
			_msg.text = Kit.text("mb_no_energy", "Sin energ\u00eda: espera o mira un anuncio")
			_sfx("hurt", -12.0)
		elif M.tap(st, c).x < 0:
			_msg.text = Kit.text("mb_full", "Tablero lleno: fusiona o tira algo")
		else:
			_sfx("click", -8.0)
	elif it is Dictionary:
		_msg.text = M.item_name(st, str(it["c"]), int(it["l"])) + "  \u00b7  " + Kit.text("mb_level", "Nv {n}").format({"n": int(it["l"])})
	_refresh()


func drop(a: Vector2i, b: Vector2i) -> void:
	if not can_act():
		return
	var r: String = M.drag(st, a, b)
	if r == "merge":
		_pop = {"c": b, "t": 0.5}
		var it: Dictionary = st["grid"][b]
		_msg.text = M.item_name(st, str(it["c"]), int(it["l"]))
		_sfx("powerup", -8.0)
	elif r == "move":
		_sfx("click", -14.0)
	_refresh()


func deliver(i: int) -> void:
	if can_act() and M.deliver(st, i):
		coins = 0
		for o: Variant in st["orders"]:
			coins += 1 if bool(o["done"]) else 0
		_msg.text = Kit.text("mb_thanks", "\u00a1Gracias!") + "  +%d" % int(st["orders"][i]["reward"])
		Save.add_wallet(int(st["orders"][i]["reward"]) / 10)
		_sfx("coin", -2.0)
		_refresh()
		if bool(st["won"]):
			_finish()


func ad_energy() -> void:
	if not can_act():
		return
	var placement: String = "energy"
	var ok: Array[bool] = [false]
	var on_ok: Callable = func(p: String) -> void:
		if p == placement:
			ok[0] = true
	Ads.reward_earned.connect(on_ok)
	await Ads.show_rewarded(placement)
	Ads.reward_earned.disconnect(on_ok)
	if ok[0] and not st.is_empty():
		st["energy"] = int(st["energy"]) + AD_ENERGY
		_refresh()


func bot_step() -> void:
	if not can_act():
		return
	for i: Variant in M.open_orders(st):
		if not M.order_cells(st, int(i)).is_empty():
			deliver(int(i))
			return
	M.bot_act(st)
	_refresh()


func _sfx(n: String, vol: float = -6.0) -> void:
	if not fast:
		Audio.play(n, 0.1, vol)


func _refresh() -> void:
	if st.is_empty() or _top_lbl == null:
		return
	var nxt: String = "" if int(st["energy"]) >= M.MAX_ENERGY else "  (%ds)" % int(ceil(float(st["regen"]) - float(st["regen_t"])))
	_top_lbl.text = Kit.text("mb_energy", "Energ\u00eda {n}").format({"n": int(st["energy"])}) + nxt + "    %d/%d" % [coins, coins_total]
	_ad_btn.visible = Ads.rewarded_available() and int(st["energy"]) < 10
	_orders.queue_redraw()
	_board.queue_redraw()


# ------------------------------------------------------------------ bucle y entrada

func _physics_process(delta: float) -> void:
	if st.is_empty() or finished or get_tree().paused:
		return
	_anim_t += delta
	if fast and auto_retry:
		for k: int in 4:
			bot_step()
			M.tick(st, M.ACT_TIME)
			if finished:
				return
	else:
		M.tick(st, delta)
	time_in_level = float(st["t"])
	if not _pop.is_empty():
		_pop["t"] = float(_pop["t"]) - delta
		if float(_pop["t"]) <= 0.0:
			_pop = {}
	_think -= delta
	if _think <= 0.0:
		_think = 0.25
		_refresh()
	else:
		_board.queue_redraw()


func _cell_size() -> float:
	return minf(_board.size.x / float(M.W), _board.size.y / float(M.H))


func _origin() -> Vector2:
	var cs: float = _cell_size()
	return Vector2((_board.size.x - cs * float(M.W)) * 0.5, 0.0)


func _cell_at(p: Vector2) -> Vector2i:
	var cs: float = _cell_size()
	var q: Vector2 = (p - _origin()) / cs
	var c: Vector2i = Vector2i(int(floor(q.x)), int(floor(q.y)))
	if c.x < 0 or c.y < 0 or c.x >= M.W or c.y >= M.H:
		return Vector2i(-1, -1)
	return c


func _on_board_input(event: InputEvent) -> void:
	if not can_act():
		return
	var p: Vector2 = Vector2.INF
	var down: bool = false
	var up: bool = false
	if event is InputEventScreenTouch:
		p = (event as InputEventScreenTouch).position
		down = (event as InputEventScreenTouch).pressed
		up = not down
	elif event is InputEventScreenDrag:
		p = (event as InputEventScreenDrag).position
	elif event is InputEventMouseButton and not DisplayServer.is_touchscreen_available():
		p = (event as InputEventMouseButton).position
		down = (event as InputEventMouseButton).pressed
		up = not down
	elif event is InputEventMouseMotion and not DisplayServer.is_touchscreen_available():
		p = (event as InputEventMouseMotion).position
	if p == Vector2.INF:
		return
	_drag_pos = p
	var c: Vector2i = _cell_at(p)
	if down:
		_drag_from = c
	elif up:
		if _drag_from.x >= 0:
			if c == _drag_from:
				tap_cell(c)
			elif c.x >= 0:
				drop(_drag_from, c)
		_drag_from = Vector2i(-1, -1)
	_board.queue_redraw()


func _order_rects() -> Array:
	var out: Array = []
	var ids: Array = M.open_orders(st)
	var w: float = (_orders.size.x - 20.0) / 3.0
	for k: int in ids.size():
		out.append(Rect2(Vector2(float(k) * (w + 10.0), 0), Vector2(w, _orders.size.y)))
	return out


func _on_orders_input(event: InputEvent) -> void:
	var p: Vector2 = Vector2.INF
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		p = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and not DisplayServer.is_touchscreen_available():
		p = (event as InputEventMouseButton).position
	if p == Vector2.INF:
		return
	var ids: Array = M.open_orders(st)
	var rects: Array = _order_rects()
	for k: int in rects.size():
		if (rects[k] as Rect2).has_point(p):
			deliver(int(ids[k]))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()


# ------------------------------------------------------------------ dibujo

func _chain(c: String) -> Dictionary:
	return (st["cat"]["chains"] as Dictionary).get(c, {})


## Un objeto: forma de su cadena, mas grande y mas vistoso cuanto mas nivel.
func _draw_item(ctl: Control, p: Vector2, cs: float, c: String, l: int) -> void:
	var badge: bool = l > 0
	l = absi(l)
	var d: Dictionary = _chain(c)
	var col: Color = Color(str(d.get("color", "#cccccc"))).lightened(0.1 - 0.05 * float(l))
	var s: float = cs * (0.22 + 0.025 * float(mini(l, 8)))
	match str(d.get("look", "")):
		"bread":
			ctl.draw_circle(p + Vector2(0, s * 0.1), s, col)
			for k: int in mini(l, 4):
				ctl.draw_line(p + Vector2(-s * 0.5 + s * 0.33 * float(k), -s * 0.5), p + Vector2(-s * 0.3 + s * 0.33 * float(k), s * 0.3), col.darkened(0.3), 3.0)
		"cup":
			ctl.draw_rect(Rect2(p + Vector2(-s * 0.8, -s * 0.6), Vector2(s * 1.4, s * 1.4)), col)
			ctl.draw_arc(p + Vector2(s * 0.7, 0), s * 0.35, -PI * 0.5, PI * 0.5, 10, col, 4.0)
		"flower":
			for k2: int in 5:
				var a: float = TAU * float(k2) / 5.0
				ctl.draw_circle(p + Vector2(cos(a), sin(a)) * s * 0.55, s * 0.45, col)
			ctl.draw_circle(p, s * 0.35, Color("#ffd166"))
		"tool":
			ctl.draw_rect(Rect2(p + Vector2(-s * 0.15, -s), Vector2(s * 0.3, s * 2.0)), Color("#8b5a3c"))
			ctl.draw_rect(Rect2(p + Vector2(-s * 0.8, -s), Vector2(s * 1.6, s * 0.6)), col)
		_:
			ctl.draw_circle(p, s, col)
	## Nivel en una esquinita.
	if not badge:
		return
	ctl.draw_circle(p + Vector2(cs * 0.3, cs * 0.3), cs * 0.13, Color("#5a3a20"))
	var t: String = str(l)
	var tw: float = _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, int(cs * 0.2)).x
	ctl.draw_string(_font, p + Vector2(cs * 0.3 - tw * 0.5, cs * 0.37), t, HORIZONTAL_ALIGNMENT_LEFT, -1, int(cs * 0.2), Color.WHITE)


func _draw_board() -> void:
	var cs: float = _cell_size()
	var o: Vector2 = _origin()
	for y: int in M.H:
		for x: int in M.W:
			var r: Rect2 = Rect2(o + Vector2(x, y) * cs, Vector2(cs, cs)).grow(-2.0)
			_board.draw_rect(r, Color("#e8d5b0") if (x + y) % 2 == 0 else Color("#dfc89f"))
	var want: Dictionary = M.wanted(st)
	for c: Variant in st["grid"]:
		var it: Dictionary = st["grid"][c]
		var p: Vector2 = o + (Vector2(c) + Vector2(0.5, 0.5)) * cs
		if c == _drag_from and _drag_pos != Vector2.ZERO and not it.has("gen"):
			p = _drag_pos
		if it.has("gen"):
			_board.draw_rect(Rect2(o + Vector2(c) * cs, Vector2(cs, cs)).grow(-4.0), Color(str(_chain(str(it["gen"])).get("color", "#999"))).darkened(0.35))
			_draw_item(_board, p + Vector2(0, -cs * 0.05 + sin(_anim_t * 4.0) * 2.0), cs, str(it["gen"]), -3)
			_board.draw_string(_font, o + Vector2(c) * cs + Vector2(6, cs - 8), str(_chain(str(it["gen"])).get("gen", "")), HORIZONTAL_ALIGNMENT_LEFT, cs - 10, int(cs * 0.16), Color.WHITE)
		else:
			if (want.get(str(it["c"]), {}) as Dictionary).has(int(it["l"])):
				_board.draw_rect(Rect2(o + Vector2(c) * cs, Vector2(cs, cs)).grow(-3.0), Color("#5bd17a"), false, 4.0)
			var grow: float = 1.0 + (float(_pop["t"]) * 0.6 if not _pop.is_empty() and _pop["c"] == c else 0.0)
			_draw_item(_board, p, cs * grow, str(it["c"]), int(it["l"]))


func _draw_orders() -> void:
	var ids: Array = M.open_orders(st)
	var rects: Array = _order_rects()
	for k: int in ids.size():
		var o: Dictionary = st["orders"][int(ids[k])]
		var r: Rect2 = rects[k]
		var ok_now: bool = not M.order_cells(st, int(ids[k])).is_empty()
		_orders.draw_rect(r, Color("#fffaf0") if not ok_now else Color("#d8f5d8"))
		_orders.draw_rect(r, Color("#5bd17a") if ok_now else Color("#c9b083"), false, 4.0)
		## Cara del cliente y lo que pide.
		_orders.draw_circle(r.position + Vector2(36, 36), 24.0, Color("#f1c27d"))
		_orders.draw_circle(r.position + Vector2(28, 32), 3.0, Color("#333333"))
		_orders.draw_circle(r.position + Vector2(44, 32), 3.0, Color("#333333"))
		_orders.draw_string(_font, r.position + Vector2(68, 44), str(o["who"]), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 72, 20, Color("#5a3a20"))
		var need: Array = o["need"]
		var cs: float = minf(80.0, (r.size.x - 10.0) / float(maxi(1, need.size())))
		for j: int in need.size():
			_draw_item(_orders, r.position + Vector2(cs * 0.5 + 5.0 + cs * float(j), r.size.y - cs * 0.6 - 6.0), cs, str(need[j][0]), int(need[j][1]))
		if ok_now:
			var t: String = Kit.text("mb_deliver", "Entregar")
			_orders.draw_string(_font, r.position + Vector2(10, 76), t, HORIZONTAL_ALIGNMENT_LEFT, r.size.x, 22, Color("#2e8b57"))


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = int(st["coins"]) * 10 + maxi(0, int(1000.0 * float(level.get("par", 300.0)) / maxf(1.0, time_in_level)))
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "time": snappedf(time_in_level, 0.1), "taps": int(st["taps"])})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


func stars_earned() -> int:
	var par: float = maxf(1.0, float(level.get("par", 300.0)))
	return 3 if time_in_level <= par else (2 if time_in_level <= par * 1.5 else 1)


func retry() -> void:
	_reset()


func open_pause() -> void:
	if finished or get_tree().paused or get_node_or_null("PauseMenu") != null:
		return
	PauseMenu.open(self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		## Aviso de vuelta: energia llena.
		if not st.is_empty() and not finished:
			var falta: int = M.MAX_ENERGY - int(st["energy"])
			Notify.game_reminder = {} if falta <= 0 else {"delay": int(float(falta) * float(st["regen"])),
				"content": Kit.text("mb_notify", "\u00a1Energ\u00eda llena! Tus clientes esperan sus pedidos")}
		if is_inside_tree() and not UI.test_mode:
			open_pause()


func bot_state() -> Dictionary:
	return {"deaths": deaths, "coins": coins, "finished": finished, "failed": failed, "stomps": 0, "time": time_in_level,
		"energy": int(st.get("energy", 0)), "taps": int(st.get("taps", 0))}
