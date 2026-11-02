extends Node2D
## Hundir la flota: arriba, en pequeno, tu flota y los disparos del rival; abajo, en grande, el mar
## del rival: toca una casilla para disparar. Si tocas, repites. Reglas, rival, bot y analizador en
## battle_map.gd. Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry,
## bot_script(), bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const M = preload("res://kit/battle/battle_map.gd")
const THINK: float = 0.7

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
var _turn_label: Label
var _vs: VersusBar
var _think: float = 0.0
var _fx: Array = []
var _t: float = 0.0


var _hint_btn: Button

func _ready() -> void:
	level = Kit.current_level()
	RenderingServer.set_default_clear_color(Color("#0b2545"))
	_build_hud()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "battle", "n": int(st["n"])})


func wants_grade() -> bool:
	return false


func bot_script() -> String:
	return "res://qa/battle_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(3.0, 1.5)


func _reset() -> void:
	Hint.reset(self)
	finished = false
	failed = false
	st = M.new_state(level)
	coins_total = (st["ships"] as Array).size()
	coins = 0
	time_in_level = 0.0
	_think = THINK
	_fx.clear()
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
	safe.add_child(col)
	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top)
	_turn_label = Label.new()
	_turn_label.name = "Turn"
	_turn_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_turn_label.add_theme_font_size_override("font_size", 30)
	_turn_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_turn_label.add_theme_constant_override("outline_size", 7)
	top.add_child(_turn_label)
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
	_vs = VersusBar.make()
	col.add_child(_vs)
	_view = Control.new()
	_view.name = "View"
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.draw.connect(_draw_view)
	_view.gui_input.connect(_on_input)
	col.add_child(_view)


func _refresh() -> void:
	if _hint_btn != null:
		_hint_btn.text = Hint.label(self)
	if st.is_empty() or _turn_label == null:
		return
	var res: String = str(st["last_result"])
	var txt: String = Kit.text("bt_you", "Tu turno: dispara") if int(st["turn"]) == 1 else Kit.text("bt_ai", "Dispara el rival...")
	if res == "sunk":
		txt = Kit.text("bt_sunk", "\u00a1Hundido!") + "  " + txt
	elif res == "hit":
		txt = Kit.text("bt_hit", "\u00a1Tocado!") + "  " + txt
	_turn_label.text = txt
	var n_ships: int = (st["ships"] as Array).size()
	coins = n_ships - M.fleet_left(st["theirs"], st["shots_mine"], st["ships"])
	_vs.set_state(M.fleet_left(st["mine"], st["shots_theirs"], st["ships"]), M.fleet_left(st["theirs"], st["shots_mine"], st["ships"]), int(st["turn"]) == 1)
	_view.queue_redraw()


func can_act() -> bool:
	return not finished and is_inside_tree() and not get_tree().paused and int(st["turn"]) == 1 and not bool(st["won"]) and not bool(st["lost"])


## Rectangulos: tu mar (pequeno, arriba) y el del rival (grande, abajo).
func _mine_rect() -> Rect2:
	var side: float = minf(_view.size.x * 0.42, _view.size.y * 0.3)
	return Rect2(Vector2((_view.size.x - side) * 0.5, 4.0), Vector2(side, side))


func _theirs_rect() -> Rect2:
	var m: Rect2 = _mine_rect()
	var side: float = minf(_view.size.x - 8.0, _view.size.y - m.end.y - 24.0)
	return Rect2(Vector2((_view.size.x - side) * 0.5, m.end.y + 20.0), Vector2(side, side))


func shoot(i: int) -> void:
	if not can_act():
		return
	_do(i)


func _do(i: int) -> void:
	var me: bool = int(st["turn"]) == 1
	var r: String = M.fire(st, i)
	if r == "":
		return
	_fx.append({"i": i, "me": me, "r": r, "t": 0.0})
	_think = THINK
	if r == "water":
		_sfx("click", -10.0)
	else:
		_sfx("coin" if me else "hurt", -6.0)
	_refresh()
	if bool(st["won"]):
		_finish()
	elif bool(st["lost"]):
		_lose()


func _sfx(nm: String, vol: float = -6.0) -> void:
	if not fast:
		Audio.play(nm, 0.1, vol)


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
	if can_act():
		var i: int = M.bot_shot(st)
		if i >= 0:
			_do(i)


func _on_input(event: InputEvent) -> void:
	var p: Vector2 = Vector2.INF
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		p = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and not DisplayServer.is_touchscreen_available():
		p = (event as InputEventMouseButton).position
	if p == Vector2.INF:
		return
	var r: Rect2 = _theirs_rect()
	if not r.has_point(p):
		return
	var n: int = int(st["n"])
	var q: Vector2 = (p - r.position) / r.size * float(n)
	shoot(clampi(int(q.y), 0, n - 1) * n + clampi(int(q.x), 0, n - 1))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()


func _physics_process(delta: float) -> void:
	if st.is_empty() or get_tree().paused:
		return
	_t += delta
	var dt: float = delta * (8.0 if fast else 1.0)
	if not finished:
		time_in_level += dt
		if int(st["turn"]) == 2 and not bool(st["won"]) and not bool(st["lost"]):
			_think -= dt
			if _think <= 0.0:
				var i: int = M.rival_shot(st)
				if i >= 0:
					_do(i)
		elif fast and auto_retry:
			bot_step()
	for f: Variant in _fx:
		(f as Dictionary)["t"] = float((f as Dictionary)["t"]) + delta
	_fx = _fx.filter(func(f: Dictionary) -> bool: return float(f["t"]) < 0.8)
	_view.queue_redraw()


# ------------------------------------------------------------------ dibujo

func _draw_board(r: Rect2, board: Array, shots: Dictionary, show_ships: bool, mine: bool) -> void:
	var n: int = int(st["n"])
	var cs: float = r.size.x / float(n)
	_view.draw_rect(r.grow(6.0), Color("#061a33"))
	for i: int in n * n:
		var cell: Rect2 = Rect2(r.position + Vector2(i % n, i / n) * cs, Vector2(cs, cs))
		var wave: float = 0.04 * sin(_t * 2.0 + float(i % n) * 0.7 + float(i / n) * 0.5)
		_view.draw_rect(cell.grow(-1.0), Color("#1d5c96").lightened(wave))
		var ship: int = int(board[i])
		var sunk: bool = ship > 0 and M.sunk(board, shots, ship)
		if ship > 0 and (show_ships or sunk):
			_view.draw_rect(cell.grow(-cs * 0.12), Color("#8d99ae") if not sunk else Color("#5c4d4d"))
		if shots.has(i):
			var c: Vector2 = cell.get_center()
			if str(shots[i]) == "x":
				_view.draw_circle(c, cs * 0.3, Color("#ef233c"))
				_view.draw_circle(c, cs * 0.15, Color("#ffb703"))
			else:
				_view.draw_circle(c, cs * 0.12, Color(1, 1, 1, 0.75))
	## Si es tu turno, el mar del rival brilla un poco.
	if not mine and can_act():
		_view.draw_rect(r.grow(6.0), Color(1.0, 0.85, 0.3, 0.35 + 0.25 * sin(_t * 4.0)), false, 4.0)


func _draw_view() -> void:
	if st.is_empty():
		return
	var font: Font = _view.get_theme_font("font", "Label")
	var mr: Rect2 = _mine_rect()
	var tr: Rect2 = _theirs_rect()
	_draw_board(mr, st["mine"], st["shots_theirs"], true, true)
	_draw_board(tr, st["theirs"], st["shots_mine"], bool(st["lost"]), false)
	_view.draw_string(font, Vector2(mr.position.x - 210.0, mr.position.y + 34.0), Kit.text("bt_mine", "Tu flota"), HORIZONTAL_ALIGNMENT_RIGHT, 200, 24, Color(1, 1, 1, 0.8))
	## Efectos: salpicadura (agua) o explosion (tocado).
	var n: int = int(st["n"])
	for f: Variant in _fx:
		var fd: Dictionary = f
		var r: Rect2 = tr if bool(fd["me"]) else mr
		var cs: float = r.size.x / float(n)
		var i: int = int(fd["i"])
		var c: Vector2 = r.position + (Vector2(i % n, i / n) + Vector2(0.5, 0.5)) * cs
		var k: float = float(fd["t"]) / 0.8
		var col: Color = Color(1, 1, 1, 1.0 - k) if str(fd["r"]) == "water" else Color(1.0, 0.6, 0.1, 1.0 - k)
		_view.draw_arc(c, cs * (0.3 + k * 1.2), 0.0, TAU, 24, col, 4.0)


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var left: int = M.fleet_left(st["mine"], st["shots_theirs"], st["ships"])
	var score: int = 400 + left * 150 + maxi(0, int(st["n"]) * int(st["n"]) - int(st["shots"])) * 5
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "shots": int(st["shots"]), "time": snappedf(time_in_level, 0.1)})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


## Estrellas por los barcos que te quedan: todos, 3; mas de la mitad, 2; si no, 1.
func stars_earned() -> int:
	var total: int = (st["ships"] as Array).size()
	var left: int = M.fleet_left(st["mine"], st["shots_theirs"], st["ships"])
	return 3 if left == total else (2 if left * 2 > total else 1)


func _lose() -> void:
	if failed:
		return
	finished = true
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "battle", "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("bt_lost", "\u00a1Hundieron tu flota!"),
		Kit.text("bt_hint", "Dispara en damero (como las casillas negras del ajedrez) y, cuando toques, sigue la linea del barco."))
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
		"shots": int(st.get("shots", 0))}
