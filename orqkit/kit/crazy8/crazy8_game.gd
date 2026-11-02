extends Node2D
## Cartas locas: tu mano abajo, los rivales arriba y en medio el mazo y la mesa. Toca una carta que
## valga (mismo color o mismo numero/simbolo); si no tienes, toca el mazo para robar. Con un comodin
## eliges color. Reglas, bots y analizador en crazy8_map.gd.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel al acabar.

const M = preload("res://kit/crazy8/crazy8_map.gd")
const CARD_COLORS: Dictionary = {"r": Color("#e74c3c"), "g": Color("#27ae60"), "b": Color("#2e86de"), "y": Color("#f1c40f")}
const RIVAL_DELAY: float = 0.8

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
var _pass_btn: Button
var _picker: HBoxContainer
var _pending: int = -1
var _rival_t: float = 0.0
var _anim_t: float = 0.0
var _flash: float = 0.0


var _hint_btn: Button

func _ready() -> void:
	level = Kit.current_level()
	RenderingServer.set_default_clear_color(Color("#0f5132"))
	_font = ThemeDB.fallback_font
	_build_hud()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "crazy8", "players": int(st["n"])})


func bot_script() -> String:
	return "res://qa/crazy8_bot.gd"


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
	_pending = -1
	_rival_t = RIVAL_DELAY
	if _picker != null:
		_picker.visible = false
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
	_pass_btn = UI.make_button(Kit.text("c8_pass", "Pasar"), false)
	_pass_btn.name = "BtnPass"
	_pass_btn.pressed.connect(pass_turn)
	top.add_child(_pass_btn)
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
	_picker = HBoxContainer.new()
	_picker.name = "ColorPicker"
	_picker.alignment = BoxContainer.ALIGNMENT_CENTER
	_picker.add_theme_constant_override("separation", 14)
	_picker.visible = false
	col.add_child(_picker)
	for c: String in M.COLORS:
		var b: Button = Button.new()
		b.name = "Pick_" + c
		b.custom_minimum_size = Vector2(110, 110)
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.bg_color = CARD_COLORS[c]
		sb.set_corner_radius_all(55)
		for s: String in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(s, sb)
		b.pressed.connect(choose_color.bind(c))
		_picker.add_child(b)


func my_turn() -> bool:
	return not st.is_empty() and int(st["turn"]) == 0 and not bool(st["won"]) and not bool(st["lost"])


func can_act() -> bool:
	return not finished and not failed and is_inside_tree() and not get_tree().paused and my_turn()


## Jugar la carta idx de tu mano (si es comodin, primero se elige color).
func play_card(idx: int, color: String = "") -> bool:
	if not can_act():
		return false
	var hand: Array = st["hands"][0]
	if idx < 0 or idx >= hand.size() or not M.playable(st, str(hand[idx])):
		_flash = 0.3
		return false
	if M.is_wild(str(hand[idx])) and color == "":
		_pending = idx
		_picker.visible = true
		return false
	if M.play(st, idx, color):
		_sfx("click", -4.0)
		_after_move()
		return true
	_flash = 0.3
	return false


func choose_color(c: String) -> void:
	_picker.visible = false
	if _pending >= 0:
		var i: int = _pending
		_pending = -1
		play_card(i, c)


func draw() -> void:
	if not can_act() or str(st["drew"]) != "":
		return
	M.draw_card(st)
	_sfx("powerup", -12.0)
	_rival_t = RIVAL_DELAY
	_after_move()


func pass_turn() -> void:
	if can_act() and str(st["drew"]) != "":
		M.pass_turn(st)
		_rival_t = RIVAL_DELAY
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
	if _deck_rect().has_point(p):
		draw()
		return
	var rects: Array = _hand_rects()
	for i: int in range(rects.size() - 1, -1, -1):
		if (rects[i] as Rect2).has_point(p):
			play_card(i)
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
	_info.text = Kit.text("c8_your_turn", "Tu turno") if my_turn() else Kit.text("c8_rival_turn", "Juega el rival {n}").format({"n": int(st["turn"])})
	_pass_btn.visible = my_turn() and str(st["drew"]) != "" and str(st["drew"]) != "-"
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
			_rival_t = RIVAL_DELAY
			M.auto_turn(st, false)
			_sfx("click", -10.0)
			_after_move()
	_view.queue_redraw()


# ------------------------------------------------------------------ dibujo

func _card_size() -> Vector2:
	var w: float = clampf(_view.size.x * 0.19, 70.0, 130.0)
	return Vector2(w, w * 1.45)


func _deck_rect() -> Rect2:
	var cs: Vector2 = _card_size()
	return Rect2(Vector2(_view.size.x * 0.5 - cs.x - 16.0, _view.size.y * 0.36), cs)


func _hand_rects() -> Array:
	var hand: Array = st["hands"][0]
	var cs: Vector2 = _card_size()
	var n: int = hand.size()
	var avail: float = _view.size.x - 24.0
	var step: float = minf(cs.x + 8.0, (avail - cs.x) / float(maxi(1, n - 1)))
	var total: float = step * float(n - 1) + cs.x
	var x0: float = (_view.size.x - total) * 0.5
	var out: Array = []
	for i: int in n:
		var lift: float = 22.0 if my_turn() and M.playable(st, str(hand[i])) and (str(st["drew"]) == "" or str(st["drew"]) == "-" or i == n - 1) else 0.0
		out.append(Rect2(Vector2(x0 + step * float(i), _view.size.y - cs.y - 12.0 - lift), cs))
	return out


func _draw_card(r: Rect2, card: String, face: bool = true) -> void:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.set_corner_radius_all(int(r.size.x * 0.12))
	sb.border_color = Color.WHITE
	sb.set_border_width_all(4)
	if not face:
		sb.bg_color = Color("#2d3436")
		_view.draw_style_box(sb, r)
		_view.draw_string(_font, r.position + Vector2(0, r.size.y * 0.58), "?", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, int(r.size.x * 0.45), Color("#636e72"))
		return
	var wild: bool = M.is_wild(card)
	sb.bg_color = Color("#222222") if wild else CARD_COLORS[card.substr(0, 1)]
	_view.draw_style_box(sb, r)
	var c: Vector2 = r.get_center()
	var rad: float = r.size.x * 0.34
	if wild:
		for k: int in 4:
			_view.draw_colored_polygon(_wedge(c, rad, float(k) * PI * 0.5), CARD_COLORS[M.COLORS[k]])
	else:
		_view.draw_circle(c, rad, Color(1, 1, 1, 0.9))
	var v: String = M.value_of(card)
	var label: String = {"S": "", "R": "", "D": "+2", "W": "", "F": "+4"}.get(v, v)
	var tc: Color = Color.WHITE if wild else (CARD_COLORS[card.substr(0, 1)] as Color).darkened(0.25)
	if label != "":
		_view.draw_string(_font, Vector2(r.position.x, c.y + rad * 0.42), label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, int(rad * 1.15), tc)
	elif v == "S":
		_view.draw_arc(c, rad * 0.6, 0.0, TAU, 24, tc, 6.0)
		_view.draw_line(c + Vector2(-rad, rad) * 0.42, c + Vector2(rad, -rad) * 0.42, tc, 6.0)
	elif v == "R":
		_view.draw_arc(c, rad * 0.55, 0.3, PI - 0.3, 14, tc, 6.0)
		_view.draw_arc(c, rad * 0.55, PI + 0.3, TAU - 0.3, 14, tc, 6.0)
		_view.draw_colored_polygon(PackedVector2Array([c + Vector2(rad * 0.55, -rad * 0.35), c + Vector2(rad * 0.8, 0), c + Vector2(rad * 0.3, 0)]), tc)
		_view.draw_colored_polygon(PackedVector2Array([c + Vector2(-rad * 0.55, rad * 0.35), c + Vector2(-rad * 0.8, 0), c + Vector2(-rad * 0.3, 0)]), tc)
	if not wild:
		_view.draw_string(_font, r.position + Vector2(8, r.size.x * 0.24), label if label != "" else v, HORIZONTAL_ALIGNMENT_LEFT, -1, int(r.size.x * 0.2), Color.WHITE)


func _wedge(c: Vector2, rad: float, a0: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array([c])
	for k: int in 7:
		var a: float = a0 + PI * 0.5 * float(k) / 6.0
		pts.append(c + Vector2(cos(a), sin(a)) * rad)
	return pts


func _draw_view() -> void:
	if st.is_empty():
		return
	var cs: Vector2 = _card_size()
	## Rivales arriba.
	var n: int = int(st["n"])
	for p: int in range(1, n):
		var x: float = _view.size.x * float(p) / float(n)
		var ctr: Vector2 = Vector2(x, 70.0)
		var turn: bool = int(st["turn"]) == p
		_view.draw_circle(ctr, 46.0, Color("#ffd166") if turn else Color("#1b4332"))
		_view.draw_circle(ctr, 40.0, Color("#95a5a6"))
		_view.draw_circle(ctr + Vector2(-13, -6), 6.0, Color("#2d3436"))
		_view.draw_circle(ctr + Vector2(13, -6), 6.0, Color("#2d3436"))
		_view.draw_arc(ctr + Vector2(0, 8), 14.0, 0.3, PI - 0.3, 10, Color("#2d3436"), 4.0)
		var k: int = (st["hands"][p] as Array).size()
		_view.draw_string(_font, ctr + Vector2(-60, 82), Kit.text("c8_cards", "{n} cartas").format({"n": k}), HORIZONTAL_ALIGNMENT_CENTER, 120, 24, Color.WHITE)
	## Mazo, mesa, color y sentido.
	var dr: Rect2 = _deck_rect()
	_draw_card(dr, "", false)
	if my_turn() and str(st["drew"]) == "":
		_view.draw_rect(dr.grow(6.0), Color(1, 1, 1, 0.35 + 0.25 * sin(_anim_t * 5.0)), false, 4.0)
	var tr: Rect2 = Rect2(Vector2(_view.size.x * 0.5 + 16.0, dr.position.y), cs)
	_draw_card(tr, M.top(st))
	var cc: Vector2 = Vector2(_view.size.x * 0.5, dr.end.y + 46.0)
	_view.draw_circle(cc, 22.0, CARD_COLORS[str(st["color"])])
	_view.draw_arc(cc, 30.0, 0.0, TAU, 24, Color.WHITE, 3.0)
	var dirtxt: String = Kit.text("c8_dir_cw", "sentido horario") if int(st["dir"]) == 1 else Kit.text("c8_dir_ccw", "sentido antihorario")
	_view.draw_string(_font, cc + Vector2(-200, 60), dirtxt, HORIZONTAL_ALIGNMENT_CENTER, 400, 22, Color(1, 1, 1, 0.7))
	## Tu mano.
	var rects: Array = _hand_rects()
	var hand: Array = st["hands"][0]
	for i: int in rects.size():
		_draw_card(rects[i], str(hand[i]))
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
		left += (st["hands"][p] as Array).size()
	var score: int = maxi(1, left * 50)
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "turns": int(st["turns"]), "time": snappedf(time_in_level, 0.1)})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


## Estrellas por las cartas que les dejas a los rivales: muchas, 3; algunas, 2; pocas, 1.
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
	QA.log_event("death", {"cause": "crazy8", "deaths": deaths, "winner": int(st["winner"])})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("c8_lost", "Ha ganado un rival"), Kit.text("c8_lost_hint", "Guarda los comodines para el final y usa los +2 y los saltos cuando a un rival le queden pocas cartas."))
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
