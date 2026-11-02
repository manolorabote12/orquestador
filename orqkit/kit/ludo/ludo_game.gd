extends Node2D
## Parchis: toca el dado para tirar y luego la ficha que quieres mover (si solo hay una, va sola).
## Reglas, dado, rivales, bot y analizador en ludo_map.gd.
## 1 - Con un 6 sales de casa y vuelves a tirar. Comer o meter una ficha en la meta da otra tirada.
## 2 - Las casillas con estrella son seguras. Gana quien mete antes todas sus fichas.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const MapRules = preload("res://kit/ludo/ludo_map.gd")
const CELL: float = 46.0
const ORIGIN: Vector2 = Vector2(15, 250)
const COLORS: Array[Color] = [Color("#e8343a"), Color("#2f9a52"), Color("#f2c84b"), Color("#2f6fd8")]
const STEP_T: float = 0.11

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

var _font: Font
var _world: Node2D
var _camera: Camera2D
var _info: Label
var _phase: String = "roll"
var _wait: float = 0.6
var _rolled: int = 0
var _again: bool = false
var _sixes: int = 0
var _anim: Dictionary = {}
var _die_t: float = 0.0
var _t: float = 0.0
var _track: Array[Vector2i] = []
var _homes: Array = []


var _hint_btn: Button

func _ready() -> void:
	level = Kit.current_level()
	par = float(level.get("par", 60))
	RenderingServer.set_default_clear_color(Color("#2a3448"))
	_font = UI.theme.get_font("font", "Label") if UI.theme != null else ThemeDB.fallback_font
	_build_paths()
	_world = Node2D.new()
	_world.name = "World"
	_world.draw.connect(_draw_world)
	add_child(_world)
	_camera = Camera2D.new()
	add_child(_camera)
	_camera.make_current()
	_camera.position = Vector2(360, 640)
	_build_hud()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "ludo", "rivals": int(level.get("rivals", 1))})


func bot_script() -> String:
	return "res://qa/ludo_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(6.0, 1.2)


func wants_grade() -> bool:
	return false


## 1 - Casillas del tablero de 15x15: recorrido de 52 y los 4 pasillos de meta.
func _build_paths() -> void:
	var segs: Array = [[Vector2i(1, 6), Vector2i(1, 0), 5], [Vector2i(6, 5), Vector2i(0, -1), 6], [Vector2i(7, 0), Vector2i(1, 0), 2],
		[Vector2i(8, 1), Vector2i(0, 1), 5], [Vector2i(9, 6), Vector2i(1, 0), 6], [Vector2i(14, 7), Vector2i(0, 1), 2],
		[Vector2i(13, 8), Vector2i(-1, 0), 5], [Vector2i(8, 9), Vector2i(0, 1), 6], [Vector2i(7, 14), Vector2i(-1, 0), 2],
		[Vector2i(6, 13), Vector2i(0, -1), 5], [Vector2i(5, 8), Vector2i(-1, 0), 6], [Vector2i(0, 7), Vector2i(0, -1), 2]]
	_track.clear()
	for sg: Array in segs:
		for k: int in int(sg[2]):
			_track.append((sg[0] as Vector2i) + (sg[1] as Vector2i) * k)
	_homes = [[], [], [], []]
	for k2: int in 6:
		_homes[0].append(Vector2i(1 + k2, 7))
		_homes[1].append(Vector2i(7, 1 + k2))
		_homes[2].append(Vector2i(13 - k2, 7))
		_homes[3].append(Vector2i(7, 13 - k2))


func _reset() -> void:
	Hint.reset(self)
	finished = false
	failed = false
	var lv: Dictionary = level.duplicate()
	## Cada intento, otras tiradas del dado.
	lv["seed"] = int(level.get("seed", 1)) + deaths * 7919
	st = MapRules.new_state(lv)
	coins_total = (st["players"][0]["tokens"] as Array).size()
	coins = 0
	time_in_level = 0.0
	_phase = "roll"
	_wait = 0.6
	_anim = {}
	_again = false
	_sixes = 0
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
	_info = Label.new()
	_info.name = "Info"
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.add_theme_font_size_override("font_size", 32)
	_info.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_info.add_theme_constant_override("outline_size", 6)
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


func _refresh() -> void:
	if _hint_btn != null:
		_hint_btn.text = Hint.label(self)
	if _info == null or st.is_empty():
		return
	var home: int = 0
	for v: Variant in st["players"][0]["tokens"]:
		if int(v) == MapRules.GOAL:
			home += 1
	coins = home
	if int(st["turn"]) == 0:
		_info.text = Kit.text("ludo_roll", "Toca el dado") if _phase == "roll" else (Kit.text("ludo_pick", "Elige ficha") if _phase == "pick" else "")
	else:
		_info.text = Kit.text("ludo_ai", "Juega el rival...")


# ------------------------------------------------------------------ turno

func can_act() -> bool:
	return not finished and is_inside_tree() and not get_tree().paused and int(st["turn"]) == 0 and _anim.is_empty()


func roll_die() -> void:
	if _phase != "roll" or not _anim.is_empty() or finished:
		return
	_rolled = MapRules.roll(st)
	_die_t = 0.45
	_sfx("click")
	var p: int = int(st["turn"])
	_sixes = _sixes + 1 if _rolled == 6 else 0
	_again = _rolled == 6
	var opts: Array = MapRules.legal(st, p, _rolled)
	if _sixes >= 3 or opts.is_empty():
		## Como en las reglas del analizador: con un 6 se vuelve a tirar aunque no se pueda mover.
		_end_turn(_sixes < 3 and _again)
		return
	if p != 0 or opts.size() == 1:
		var care: float = 1.0 if p == 0 else float(st["skill"])
		_start_move(p, MapRules.choose(st, p, _rolled, care) if p != 0 else int(opts[0]))
		return
	_phase = "pick"
	_refresh()


func pick(t: int) -> void:
	if _phase != "pick" or int(st["turn"]) != 0 or not MapRules.legal(st, 0, _rolled).has(t):
		return
	_start_move(0, t)


func _start_move(p: int, t: int) -> void:
	var from: int = int(st["players"][p]["tokens"][t])
	var r: Dictionary = MapRules.move(st, p, t, _rolled)
	var to: int = int(st["players"][p]["tokens"][t])
	_anim = {"p": p, "t": t, "from": from, "to": to, "k": 0.0, "r": r}
	_phase = "anim"
	if int(r["capture"]) >= 0:
		_again = true
	if bool(r["home"]):
		_again = true
	_refresh()


func _end_turn(again: bool) -> void:
	if int(st["winner"]) >= 0:
		if int(st["winner"]) == 0:
			_finish()
		else:
			_lose()
		return
	if not again:
		_sixes = 0
		st["turn"] = (int(st["turn"]) + 1) % (st["players"] as Array).size()
		st["turns"] = int(st["turns"]) + 1
	_phase = "roll"
	_wait = 0.25 if fast else 0.7
	_refresh()


func _sfx(n: String) -> void:
	if not fast:
		Audio.play(n, 0.1, -8.0)


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
	if int(st["turn"]) != 0 or finished or not _anim.is_empty():
		return
	if _phase == "roll":
		roll_die()
	elif _phase == "pick":
		pick(MapRules.choose(st, 0, _rolled, 1.0))


# ------------------------------------------------------------------ bucle

func _physics_process(delta: float) -> void:
	_t += delta
	var dt: float = delta * (8.0 if fast else 1.0)
	time_in_level += dt
	_die_t = maxf(0.0, _die_t - dt)
	if finished:
		_world.queue_redraw()
		return
	if not _anim.is_empty():
		var steps: int = maxi(1, int(_anim["to"]) - maxi(0, int(_anim["from"])))
		_anim["k"] = float(_anim["k"]) + dt / STEP_T
		if float(_anim["k"]) >= float(steps) + 1.0:
			var r: Dictionary = _anim["r"]
			_anim = {}
			if int(r["capture"]) >= 0:
				_sfx("hurt")
			elif bool(r["home"]):
				_sfx("coin")
			_end_turn(_again)
	elif _phase == "roll" and int(st["turn"]) != 0:
		_wait -= dt
		if _wait <= 0.0:
			roll_die()
	if fast and auto_retry:
		bot_step()
	_world.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()
		return
	if not (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed) or not can_act():
		return
	var p: Vector2 = get_canvas_transform().affine_inverse() * (event as InputEventScreenTouch).position
	if _phase == "roll" and p.distance_to(_die_pos()) < 90.0:
		roll_die()
		return
	if _phase == "pick":
		for t: int in (st["players"][0]["tokens"] as Array).size():
			if p.distance_to(_token_pos(0, t, int(st["players"][0]["tokens"][t]))) < CELL * 0.6:
				pick(t)
				return


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	coins = coins_total
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = 1000 + int(st["captures"][0]) * 150 + maxi(0, 150 - int(st["turns"])) * 5
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "time": snappedf(time_in_level, 0.1), "deaths": deaths})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


func stars_earned() -> int:
	if deaths > 0:
		return 1
	return 3 if int(st["captures"][0]) >= 1 or int(st["turns"]) <= int(par) else 2


func _lose() -> void:
	if finished:
		return
	finished = true
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "ludo", "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("ludo_lost", "\u00a1Gan\u00f3 un rival!"),
		Kit.text("ludo_fail_hint", "Saca fichas en cuanto puedas, para en las casillas con estrella y come cuando tengas un rival a tiro."))
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
	return {"pos": Vector2(float(st.get("turns", 0)), float(coins)), "deaths": deaths, "coins": coins, "finished": finished,
		"failed": failed, "stomps": 0, "time": time_in_level, "turns": int(st.get("turns", 0))}


# ------------------------------------------------------------------ dibujo

func _cell_pos(c: Vector2i) -> Vector2:
	return ORIGIN + (Vector2(c) + Vector2(0.5, 0.5)) * CELL


func _die_pos() -> Vector2:
	return Vector2(360, 1060)


## Donde se dibuja una ficha (casa, recorrido, pasillo o meta).
func _token_pos(p: int, t: int, pos: int) -> Vector2:
	var seat: int = int(st["players"][p]["seat"])
	if pos < 0:
		var base: Vector2i = [Vector2i(0, 0), Vector2i(9, 0), Vector2i(9, 9), Vector2i(0, 9)][seat]
		var off: Vector2 = [Vector2(1.7, 1.7), Vector2(4.3, 1.7), Vector2(1.7, 4.3), Vector2(4.3, 4.3)][t]
		return ORIGIN + (Vector2(base) + off) * CELL
	if pos == MapRules.GOAL:
		return ORIGIN + Vector2(7.5, 7.5) * CELL + Vector2(cos(float(seat) * PI * 0.5 + PI), sin(float(seat) * PI * 0.5 + PI)) * CELL * 0.7 \
			+ Vector2(float(t) * 6.0, 0)
	if pos >= MapRules.TRACK - 1:
		return _cell_pos(_homes[seat][pos - (MapRules.TRACK - 1)])
	return _cell_pos(_track[MapRules.board_cell(st, p, pos)])


func _draw_token(at: Vector2, col: Color, glow: bool) -> void:
	_world.draw_circle(at + Vector2(2, 4), CELL * 0.36, Color(0, 0, 0, 0.35))
	_world.draw_circle(at, CELL * 0.36, col.darkened(0.35))
	_world.draw_circle(at + Vector2(0, -3), CELL * 0.3, col)
	_world.draw_circle(at + Vector2(-4, -7), CELL * 0.1, Color(1, 1, 1, 0.6))
	if glow:
		_world.draw_arc(at, CELL * 0.48, 0.0, TAU, 20, Color(1, 1, 1, 0.6 + 0.4 * sin(_t * 8.0)), 4.0)


func _draw_world() -> void:
	if st.is_empty():
		return
	var board: Rect2 = Rect2(ORIGIN, Vector2(15, 15) * CELL)
	_world.draw_rect(board.grow(10.0), Color("#f4f0e8"))
	## Casas de colores en las esquinas.
	var bases: Array = [Vector2i(0, 0), Vector2i(9, 0), Vector2i(9, 9), Vector2i(0, 9)]
	for s: int in 4:
		var r: Rect2 = Rect2(ORIGIN + Vector2(bases[s]) * CELL, Vector2(6, 6) * CELL)
		_world.draw_rect(r, COLORS[s])
		_world.draw_rect(r.grow(-CELL * 0.8), Color("#fbfaf4"))
	## Recorrido, salidas, casillas seguras y pasillos.
	for i: int in _track.size():
		var c: Vector2i = _track[i]
		var r2: Rect2 = Rect2(ORIGIN + Vector2(c) * CELL, Vector2(CELL, CELL))
		var col: Color = Color("#fbfaf4")
		if i % 13 == 0:
			col = COLORS[i / 13].lightened(0.25)
		_world.draw_rect(r2, col)
		_world.draw_rect(r2, Color("#b8b0a0"), false, 1.0)
		if MapRules.SAFE.has(i) and i % 13 != 0:
			_world.draw_circle(r2.get_center(), CELL * 0.18, Color("#c8c0b0"))
	for s2: int in 4:
		for c2: Vector2i in _homes[s2]:
			var r3: Rect2 = Rect2(ORIGIN + Vector2(c2) * CELL, Vector2(CELL, CELL))
			_world.draw_rect(r3, COLORS[s2].lightened(0.15))
			_world.draw_rect(r3, Color("#b8b0a0"), false, 1.0)
	## Meta: cuatro triangulos.
	var ctr: Vector2 = ORIGIN + Vector2(7.5, 7.5) * CELL
	var hq: float = CELL * 1.5
	var corners: Array = [ctr + Vector2(-hq, -hq), ctr + Vector2(hq, -hq), ctr + Vector2(hq, hq), ctr + Vector2(-hq, hq)]
	for s3: int in 4:
		var a: Vector2 = corners[(s3 + 3) % 4]
		var b: Vector2 = corners[s3]
		_world.draw_colored_polygon(PackedVector2Array([a, b, ctr]), COLORS[s3])
	## Fichas (la que se mueve, paso a paso).
	var picks: Array = MapRules.legal(st, 0, _rolled) if _phase == "pick" else []
	for p: int in (st["players"] as Array).size():
		var seat: int = int(st["players"][p]["seat"])
		var toks: Array = st["players"][p]["tokens"]
		for t: int in toks.size():
			var pos: int = int(toks[t])
			if not _anim.is_empty() and int(_anim["p"]) == p and int(_anim["t"]) == t:
				var from: int = int(_anim["from"])
				var k: int = mini(int(float(_anim["k"])), int(_anim["to"]) - maxi(0, from))
				pos = (maxi(0, from) + k) if from >= 0 else (-1 if float(_anim["k"]) < 1.0 else 0)
				pos = mini(pos, int(_anim["to"]))
			var at: Vector2 = _token_pos(p, t, pos)
			_draw_token(at + Vector2(0, -sin(fmod(float(_anim.get("k", 0.0)), 1.0) * PI) * 10.0 if not _anim.is_empty() and int(_anim["p"]) == p and int(_anim["t"]) == t else 0.0),
				COLORS[seat], p == 0 and picks.has(t))
	## Dado.
	var dp: Vector2 = _die_pos()
	var turn_col: Color = COLORS[int(st["players"][int(st["turn"])]["seat"])]
	_world.draw_rect(Rect2(dp - Vector2(70, 70), Vector2(140, 140)), turn_col.darkened(0.2))
	var face: int = _rolled if _die_t <= 0.0 else 1 + int(_t * 30.0) % 6
	var rr: Rect2 = Rect2(dp - Vector2(52, 52), Vector2(104, 104)).grow(0.0)
	if _phase == "roll" and int(st["turn"]) == 0 and not finished:
		rr = rr.grow(4.0 + 3.0 * sin(_t * 6.0))
	_world.draw_rect(rr, Color("#fbfaf4"))
	if face > 0:
		var pips: Dictionary = {1: [Vector2(0, 0)], 2: [Vector2(-1, -1), Vector2(1, 1)], 3: [Vector2(-1, -1), Vector2(0, 0), Vector2(1, 1)],
			4: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)], 5: [Vector2(-1, -1), Vector2(1, -1), Vector2(0, 0), Vector2(-1, 1), Vector2(1, 1)],
			6: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 1), Vector2(1, 1)]}
		for q: Vector2 in pips[face]:
			_world.draw_circle(dp + q * 26.0, 9.0, Color("#22222a"))
