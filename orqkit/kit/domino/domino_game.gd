extends Node2D
## Domino: tus fichas abajo, los rivales arriba y en medio la mesa. Toca una ficha que case con una
## punta; si casa con las dos, eliges punta. Si no puedes, roba del pozo (o pasa si no queda).
## Reglas, bots y analizador en domino_map.gd.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel al acabar.

const M = preload("res://kit/domino/domino_map.gd")
const RIVAL_DELAY: float = 0.8
## Donde va cada punto en media ficha (0-1), de 0 a 6.
const PIPS: Array = [[], [Vector2(0.5, 0.5)], [Vector2(0.25, 0.25), Vector2(0.75, 0.75)],
	[Vector2(0.25, 0.25), Vector2(0.5, 0.5), Vector2(0.75, 0.75)],
	[Vector2(0.25, 0.25), Vector2(0.75, 0.25), Vector2(0.25, 0.75), Vector2(0.75, 0.75)],
	[Vector2(0.25, 0.25), Vector2(0.75, 0.25), Vector2(0.5, 0.5), Vector2(0.25, 0.75), Vector2(0.75, 0.75)],
	[Vector2(0.25, 0.22), Vector2(0.75, 0.22), Vector2(0.25, 0.5), Vector2(0.75, 0.5), Vector2(0.25, 0.78), Vector2(0.75, 0.78)]]

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
var _draw_btn: Button
var _left_btn: Button
var _right_btn: Button
var _sel: int = -1
var _rival_t: float = 0.0
var _anim_t: float = 0.0
var _flash: float = 0.0


var _hint_btn: Button

func _ready() -> void:
	level = Kit.current_level()
	RenderingServer.set_default_clear_color(Color("#14532d"))
	_build_hud()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "domino", "players": int(st["n"])})


func bot_script() -> String:
	return "res://qa/domino_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(2.4, 1.6)


func _reset() -> void:
	Hint.reset(self)
	finished = false
	failed = false
	st = M.new_state(level)
	coins = 0
	coins_total = 0
	time_in_level = 0.0
	_sel = -1
	_rival_t = RIVAL_DELAY
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
	## Pista: la jugada que haria el bot (la primera gratis; despues anuncio o monedas).
	if not Kit.versus:
		_hint_btn = Hint.make_button(self, use_hint)
		_hint_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
		top.add_child(_hint_btn)
		top.move_child(_hint_btn, pause_btn.get_index())
	_view = Control.new()
	_view.name = "View"
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.draw.connect(_draw_view)
	_view.gui_input.connect(_on_input)
	col.add_child(_view)
	var bar: HBoxContainer = HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 12)
	col.add_child(bar)
	_left_btn = UI.make_button(Kit.text("dom_left", "Izquierda"), true)
	_left_btn.name = "BtnLeft"
	_left_btn.pressed.connect(func() -> void: play_selected("l"))
	bar.add_child(_left_btn)
	_draw_btn = UI.make_button(Kit.text("dom_draw", "Robar"), false)
	_draw_btn.name = "BtnDraw"
	_draw_btn.pressed.connect(draw_or_pass)
	bar.add_child(_draw_btn)
	_right_btn = UI.make_button(Kit.text("dom_right", "Derecha"), true)
	_right_btn.name = "BtnRight"
	_right_btn.pressed.connect(func() -> void: play_selected("r"))
	bar.add_child(_right_btn)


func my_turn() -> bool:
	return not st.is_empty() and int(st["turn"]) == 0 and not bool(st["won"]) and not bool(st["lost"])


func can_act() -> bool:
	return not finished and not failed and is_inside_tree() and not get_tree().paused and my_turn()


## Tocar la ficha idx de tu mano: si casa en una sola punta, se juega; si en las dos, eliges.
func tap_tile(idx: int) -> void:
	if not can_act():
		return
	var hand: Array = st["hands"][0]
	if idx < 0 or idx >= hand.size():
		return
	var f: Array = M.fits(st, hand[idx])
	if f.is_empty():
		_flash = 0.3
		_sfx("hurt", -14.0)
		return
	if f.size() == 1 or int(st["left"]) == int(st["right"]):
		_sel = idx
		play_selected(str(f[0]))
		return
	_sel = idx
	_refresh()


func play_selected(side: String) -> void:
	if not can_act() or _sel < 0:
		return
	var i: int = _sel
	_sel = -1
	if M.play(st, i, side):
		_sfx("click", -4.0)
		_rival_t = RIVAL_DELAY
		_after_move()
	else:
		_refresh()


func draw_or_pass() -> void:
	if not can_act() or M.can_play(st, 0):
		return
	if not M.draw(st):
		M.pass_turn(st)
		_rival_t = RIVAL_DELAY
	_sfx("powerup", -12.0)
	_after_move()


func _after_move() -> void:
	_refresh()
	if bool(st["won"]):
		_finish()
	elif bool(st["lost"]):
		_lose()


## Pista: el siguiente movimiento lo hace el bot por ti (cuenta como tu jugada).
func use_hint() -> void:
	if not can_act():
		return
	if not await Hint.pay(self):
		Hint.say(self, Kit.text("hint_no_coins", "Te faltan monedas para la pista"))
		return
	if is_inside_tree() and can_act():
		bot_step()
	_refresh()


func bot_step() -> void:
	if st.is_empty() or finished or failed:
		return
	M.auto_turn(st, int(st["turn"]) == 0)
	_after_move()


func _on_input(event: InputEvent) -> void:
	var p: Vector2 = Vector2.INF
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		p = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and not DisplayServer.is_touchscreen_available():
		p = (event as InputEventMouseButton).position
	if p == Vector2.INF or not can_act():
		return
	var rects: Array = _hand_rects()
	for i: int in rects.size():
		if (rects[i] as Rect2).has_point(p):
			tap_tile(i)
			return


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()


func _sfx(n: String, vol: float = -6.0) -> void:
	if not fast:
		Audio.play(n, 0.1, vol)


func _refresh() -> void:
	if _hint_btn != null:
		_hint_btn.text = Hint.label(self)
	if st.is_empty() or _info == null:
		return
	_info.text = (Kit.text("dom_your_turn", "Tu turno") if my_turn() else Kit.text("dom_rival_turn", "Juega el rival {n}").format({"n": int(st["turn"])})) + \
		"\n" + Kit.text("dom_pool", "Pozo: {n}").format({"n": (st["pool"] as Array).size()})
	var stuck: bool = my_turn() and not M.can_play(st, 0)
	_draw_btn.visible = stuck
	_draw_btn.text = Kit.text("dom_draw", "Robar") if not (st["pool"] as Array).is_empty() else Kit.text("dom_pass", "Pasar")
	var choose: bool = my_turn() and _sel >= 0
	_left_btn.visible = choose
	_right_btn.visible = choose
	_view.queue_redraw()


func _physics_process(delta: float) -> void:
	if st.is_empty() or get_tree().paused:
		return
	_anim_t += delta
	_flash = maxf(0.0, _flash - delta)
	if finished or failed:
		return
	time_in_level += delta
	if fast and auto_retry:
		bot_step()
	elif not my_turn():
		_rival_t -= delta
		if _rival_t <= 0.0:
			_rival_t = RIVAL_DELAY * 0.6
			M.auto_turn(st, false)
			_sfx("click", -10.0)
			_after_move()
	_view.queue_redraw()


# ------------------------------------------------------------------ dibujo

func _tile_w() -> float:
	return clampf(_view.size.x / 6.4, 50.0, 130.0)


func _hand_rects() -> Array:
	var hand: Array = st["hands"][0]
	var w: float = _tile_w() * 0.5
	var h: float = _tile_w()
	var n: int = hand.size()
	var step: float = minf(w + 10.0, (_view.size.x - 24.0 - w) / float(maxi(1, n - 1)))
	var x0: float = (_view.size.x - (step * float(n - 1) + w)) * 0.5
	var out: Array = []
	for i: int in n:
		var lift: float = 18.0 if my_turn() and not M.fits(st, hand[i]).is_empty() else 0.0
		if i == _sel:
			lift = 34.0
		out.append(Rect2(Vector2(x0 + step * float(i), _view.size.y - h - 10.0 - lift), Vector2(w, h)))
	return out


## Una ficha: a y b en sus dos mitades (horizontal: a la izquierda; vertical: a arriba).
func _draw_tile(r: Rect2, a: int, b: int, vertical: bool, glow: bool = false) -> void:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color("#fdfaf2")
	sb.set_corner_radius_all(int(minf(r.size.x, r.size.y) * 0.16))
	sb.border_color = Color("#ffd166") if glow else Color("#1b1b1b")
	sb.set_border_width_all(4 if glow else 2)
	_view.draw_style_box(sb, r)
	var half: Vector2 = Vector2(r.size.x, r.size.y * 0.5) if vertical else Vector2(r.size.x * 0.5, r.size.y)
	var h1: Rect2 = Rect2(r.position, half)
	var h2: Rect2 = Rect2(r.position + (Vector2(0, half.y) if vertical else Vector2(half.x, 0)), half)
	if vertical:
		_view.draw_line(Vector2(r.position.x + 4, h2.position.y), Vector2(r.end.x - 4, h2.position.y), Color("#444444"), 2.0)
	else:
		_view.draw_line(Vector2(h2.position.x, r.position.y + 4), Vector2(h2.position.x, r.end.y - 4), Color("#444444"), 2.0)
	var pr: float = minf(half.x, half.y) * 0.1
	for k: int in 2:
		var hr: Rect2 = h1 if k == 0 else h2
		for pp: Variant in PIPS[a if k == 0 else b]:
			_view.draw_circle(hr.position + (pp as Vector2) * hr.size, pr, Color("#1b1b1b"))


func _draw_view() -> void:
	if st.is_empty():
		return
	## Rivales.
	var n: int = int(st["n"])
	for p: int in range(1, n):
		var ctr: Vector2 = Vector2(_view.size.x * float(p) / float(n), 54.0)
		_view.draw_circle(ctr, 40.0, Color("#ffd166") if int(st["turn"]) == p else Color("#0b3d20"))
		_view.draw_circle(ctr, 34.0, Color("#95a5a6"))
		_view.draw_circle(ctr + Vector2(-11, -5), 5.0, Color("#2d3436"))
		_view.draw_circle(ctr + Vector2(11, -5), 5.0, Color("#2d3436"))
		_view.draw_arc(ctr + Vector2(0, 7), 12.0, 0.3, PI - 0.3, 10, Color("#2d3436"), 3.0)
		_view.draw_string(ThemeDB.fallback_font, ctr + Vector2(-60, 66), Kit.text("dom_tiles", "{n} fichas").format({"n": (st["hands"][p] as Array).size()}),
			HORIZONTAL_ALIGNMENT_CENTER, 120, 22, Color.WHITE)
	## Mesa: la cadena en zigzag (filas que van y vuelven), dentro de su caja.
	var chain: Array = st["chain"]
	var area: Rect2 = Rect2(Vector2(12, 140), Vector2(_view.size.x - 24, _view.size.y - 140 - _tile_w() - 70))
	var tw: float = minf(_tile_w() * 1.05, area.size.x / 6.2)
	var th: float = tw * 0.5
	var per_row: int = maxi(1, int(area.size.x / (tw + 4.0)))
	var rows: int = int(ceil(float(chain.size()) / float(per_row)))
	var y0: float = area.position.y + maxf(0.0, (area.size.y - float(rows) * (th + 14.0)) * 0.5)
	for i: int in chain.size():
		var row: int = i / per_row
		var colx: int = i % per_row
		if row % 2 == 1:
			colx = per_row - 1 - colx
		var x: float = area.position.x + (area.size.x - float(per_row) * (tw + 4.0)) * 0.5 + float(colx) * (tw + 4.0)
		var t: Array = chain[i]
		var a: int = int(t[0]) if row % 2 == 0 else int(t[1])
		var b: int = int(t[1]) if row % 2 == 0 else int(t[0])
		var glow: bool = _sel >= 0 and (i == 0 or i == chain.size() - 1)
		_draw_tile(Rect2(Vector2(x, y0 + float(row) * (th + 14.0)), Vector2(tw, th)), a, b, false, glow)
	## Tu mano.
	var rects: Array = _hand_rects()
	var hand: Array = st["hands"][0]
	for i2: int in rects.size():
		var t2: Array = hand[i2]
		_draw_tile(rects[i2], int(t2[0]), int(t2[1]), true, i2 == _sel)
	if _flash > 0.0 and not rects.is_empty():
		var all: Rect2 = (rects[0] as Rect2).merge(rects[rects.size() - 1])
		_view.draw_rect(all.grow(8.0), Color(1, 0.3, 0.3, _flash * 2.0), false, 5.0)


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var left: int = 0
	for p: int in range(1, int(st["n"])):
		for t: Variant in st["hands"][p]:
			left += M.pips(t)
	var score: int = maxi(1, left * 10)
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "turns": int(st["turns"]), "time": snappedf(time_in_level, 0.1)})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


## Estrellas por las fichas que les dejas a los rivales.
func stars_earned() -> int:
	var fewest: int = 99
	for p: int in range(1, int(st["n"])):
		fewest = mini(fewest, (st["hands"][p] as Array).size())
	return 3 if fewest >= 4 else (2 if fewest >= 2 else 1)


func _lose() -> void:
	if failed:
		return
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "domino", "deaths": deaths, "winner": int(st["winner"])})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("dom_lost", "Ha ganado un rival"), Kit.text("dom_lost_hint", "Suelta primero las fichas que m\u00e1s suman y los dobles, y guarda n\u00fameros para no quedarte sin jugada."))
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
		"turns": int(st.get("turns", 0)), "hand": (st["hands"][0] as Array).size() if not st.is_empty() else 0}
