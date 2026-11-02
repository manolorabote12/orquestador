extends Node2D
## Bloques de colores: arrastra cada bloque por los huecos hasta la puerta de su color (barras de
## colores en el borde) y sale si cabe. Vacia el tablero. Reglas, bot y analizador en blockjam_map.gd.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel al acabar.

const M = preload("res://kit/blockjam/blockjam_map.gd")

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
var _drag: int = -1
var _drag_from: Vector2 = Vector2.ZERO
var _drag_cell0: Vector2i = Vector2i.ZERO
var _vis: Dictionary = {}
var _leaving: Array = []
var _bump: Dictionary = {}
var _anim_t: float = 0.0
var _palette: Array = []


func _ready() -> void:
	level = Kit.current_level()
	RenderingServer.set_default_clear_color(Color("#1e2a3a"))
	for c: Variant in level.get("colors", ["#e74c3c", "#3498db", "#f1c40f", "#2ecc71", "#9b59b6", "#e67e22"]):
		_palette.append(Color(str(c)))
	_build_hud()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "blockjam", "blocks": coins_total})


func bot_script() -> String:
	return "res://qa/blockjam_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(2.2, 1.6)


func _reset() -> void:
	finished = false
	failed = false
	st = M.new_state(level)
	coins_total = (st["blocks"] as Array).size()
	coins = 0
	time_in_level = 0.0
	_drag = -1
	_vis.clear()
	_leaving.clear()
	for i: int in coins_total:
		_vis[i] = Vector2(st["blocks"][i]["p"])
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
	var cs: float = minf((sz.x - 60.0) / float(w), (sz.y - 60.0) / float(h))
	var b: Vector2 = Vector2(w, h) * cs
	return Rect2((sz - b) * 0.5, b)


## Mueve el bloque i una casilla (lo usan el dedo y el bot).
func move_block(i: int, dir: String) -> String:
	if not can_act():
		return ""
	var r: String = M.step(st, i, dir)
	if r == "out":
		coins = coins_total - int(st["left"])
		_leaving.append({"i": i, "dir": dir, "t": 0.0})
		_sfx("coin", -4.0)
		if _drag == i:
			_drag = -1
	elif r == "move":
		_sfx("click", -18.0)
	else:
		_bump[i] = 0.15
	_refresh()
	if bool(st["won"]):
		_finish()
	elif bool(st["lost"]):
		_lose()
	return r


func bot_step() -> void:
	if can_act():
		var m: Array = M.bot_move(st)
		if not m.is_empty():
			move_block(int(m[0]), str(m[1]))


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
	if state == 0 or not can_act():
		return
	var b: Rect2 = _board()
	var cs: float = b.size.x / float(int(st["w"]))
	if state == 1:
		var c: Vector2i = Vector2i(floori((pos.x - b.position.x) / cs), floori((pos.y - b.position.y) / cs))
		_drag = int(M.occupancy(st).get(c, -1))
		_drag_from = pos
		if _drag >= 0:
			_drag_cell0 = st["blocks"][_drag]["p"]
	elif state == -1:
		_drag = -1
	elif _drag >= 0:
		## El bloque persigue al dedo casilla a casilla (si choca, se queda donde puede).
		var want: Vector2i = _drag_cell0 + Vector2i(roundi((pos.x - _drag_from.x) / cs), roundi((pos.y - _drag_from.y) / cs))
		for k: int in 12:
			if _drag < 0:
				break
			var cur: Vector2i = st["blocks"][_drag]["p"]
			var dlt: Vector2i = want - cur
			if dlt == Vector2i.ZERO:
				break
			var first: String = ("r" if dlt.x > 0 else "l") if absi(dlt.x) >= absi(dlt.y) else ("d" if dlt.y > 0 else "u")
			var second: String = ("d" if dlt.y > 0 else "u") if absi(dlt.x) >= absi(dlt.y) else ("r" if dlt.x > 0 else "l")
			var r: String = move_block(_drag, first)
			if r == "" and (dlt.x != 0 and dlt.y != 0):
				r = move_block(_drag, second)
			if r == "" or r == "out":
				break


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
	var txt: String = Kit.text("bj_left", "Quedan {n}").format({"n": int(st["left"])})
	if int(st["max_moves"]) > 0:
		txt += "\n" + Kit.text("bj_moves", "Pasos {a}/{b}").format({"a": int(st["moves"]), "b": int(st["max_moves"])})
	_info.text = txt
	_view.queue_redraw()


func _physics_process(delta: float) -> void:
	if st.is_empty() or get_tree().paused:
		return
	_anim_t += delta
	if not finished and not failed:
		time_in_level += delta
		if fast and auto_retry:
			for k: int in 3:
				bot_step()
	for i: int in (st["blocks"] as Array).size():
		var target: Vector2 = Vector2(st["blocks"][i]["p"])
		_vis[i] = (_vis.get(i, target) as Vector2).lerp(target, 1.0 - exp(-22.0 * delta))
	for l: Variant in _leaving:
		l["t"] = float(l["t"]) + delta
	_leaving = _leaving.filter(func(l: Dictionary) -> bool: return float(l["t"]) < 0.45)
	for k2: Variant in _bump.keys():
		_bump[k2] = float(_bump[k2]) - delta
		if float(_bump[k2]) <= 0.0:
			_bump.erase(k2)
	_view.queue_redraw()


# ------------------------------------------------------------------ dibujo

func _draw_view() -> void:
	if st.is_empty():
		return
	var b: Rect2 = _board()
	var w: int = int(st["w"])
	var h: int = int(st["h"])
	var cs: float = b.size.x / float(w)
	_view.draw_rect(b.grow(6.0), Color("#3b4a5e"))
	_view.draw_rect(b, Color("#d9dee6"))
	for y: int in h:
		for x: int in w:
			var r: Rect2 = Rect2(b.position + Vector2(x, y) * cs, Vector2(cs, cs)).grow(-1.5)
			if (st["walls"] as Dictionary).has(Vector2i(x, y)):
				_view.draw_rect(r, Color("#3b4a5e"))
			else:
				_view.draw_rect(r, Color("#e8ecf1") if (x + y) % 2 == 0 else Color("#dfe4ea"))
	## Puertas: barras de su color fuera del borde.
	for d: Variant in st["doors"]:
		var door: Dictionary = d
		var col: Color = _palette[int(door.get("c", 0)) % _palette.size()]
		var a0: float = float(int(door.get("at", 0))) * cs
		var ln: float = float(int(door.get("len", 1))) * cs
		var rr: Rect2
		match str(door.get("side", "t")):
			"t":
				rr = Rect2(b.position + Vector2(a0 + 3, -20), Vector2(ln - 6, 16))
			"b":
				rr = Rect2(b.position + Vector2(a0 + 3, b.size.y + 4), Vector2(ln - 6, 16))
			"l":
				rr = Rect2(b.position + Vector2(-20, a0 + 3), Vector2(16, ln - 6))
			_:
				rr = Rect2(b.position + Vector2(b.size.x + 4, a0 + 3), Vector2(16, ln - 6))
		_view.draw_rect(rr, col)
	## Bloques (el que se arrastra, un poco mas grande).
	for i: int in (st["blocks"] as Array).size():
		var blk: Dictionary = st["blocks"][i]
		var off: Vector2 = Vector2.ZERO
		var alpha: float = 1.0
		if bool(blk["out"]):
			var gone: bool = true
			for l: Variant in _leaving:
				if int(l["i"]) == i:
					gone = false
					off = Vector2(M.DIRS[str(l["dir"])]) * float(l["t"]) * cs * 8.0
					alpha = 1.0 - float(l["t"]) / 0.45
			if gone:
				continue
		if _bump.has(i):
			off += Vector2(sin(_anim_t * 80.0), 0) * 4.0
		_draw_block(b, cs, blk, (_vis.get(i, Vector2(blk["p"])) as Vector2), off, alpha, i == _drag)


func _draw_block(b: Rect2, cs: float, blk: Dictionary, at: Vector2, off: Vector2, alpha: float, held: bool) -> void:
	var col: Color = _palette[int(blk["c"]) % _palette.size()]
	col.a = alpha
	var cells: Dictionary = {}
	for c: Variant in blk["cells"]:
		cells[c] = true
	for c2: Variant in blk["cells"]:
		var v: Vector2i = c2
		var r: Rect2 = Rect2(b.position + (at + Vector2(v)) * cs + off, Vector2(cs, cs)).grow(-3.0 if not held else -1.0)
		## Une las casillas del mismo bloque (sin hueco entre ellas).
		if cells.has(v + Vector2i(1, 0)):
			r = r.grow_side(SIDE_RIGHT, 6.0)
		if cells.has(v + Vector2i(0, 1)):
			r = r.grow_side(SIDE_BOTTOM, 6.0)
		_view.draw_rect(r, col)
		_view.draw_rect(Rect2(r.position + Vector2(4, 4), Vector2(r.size.x - 8, 6)), col.lightened(0.3))
	if held:
		var c0: Vector2i = blk["cells"][0]
		_view.draw_circle(b.position + (at + Vector2(c0) + Vector2(0.5, 0.5)) * cs + off, cs * 0.12, Color(1, 1, 1, 0.8))


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = maxi(1, coins_total * 100 + (maxi(0, int(st["max_moves"]) - int(st["moves"])) * 5))
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "moves": int(st["moves"]), "time": snappedf(time_in_level, 0.1)})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


## Estrellas: con pasos contados, por lo que sobra; sin limite, por el tiempo (rapido = 3).
func stars_earned() -> int:
	if int(st["max_moves"]) > 0:
		var left: float = 1.0 - float(st["moves"]) / float(st["max_moves"])
		return 3 if left >= 0.3 else (2 if left >= 0.1 else 1)
	var per: float = time_in_level / float(maxi(1, coins_total))
	return 3 if per <= 6.0 else (2 if per <= 12.0 else 1)


func _lose() -> void:
	if failed:
		return
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "blockjam", "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("bj_lost", "Sin pasos"), Kit.text("bj_lost_hint", "Saca primero los bloques que tapan a los dem\u00e1s y busca el camino m\u00e1s corto a cada puerta."))
	p.closed.connect(retry)


## Segunda oportunidad (FailPanel, con anuncio): unos movimientos mas y se sigue donde ibas.
func revive() -> void:
	st["max_moves"] = int(st["max_moves"]) + extra_moves()
	failed = false
	_refresh()


func extra_moves() -> int:
	return maxi(3, int(st.get("max_moves", 0)) / 4)


func revive_text() -> String:
	return Kit.text("revive_moves", "+{n} movimientos").format({"n": extra_moves()})


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
		"moves": int(st.get("moves", 0)), "left": int(st.get("left", 0))}
