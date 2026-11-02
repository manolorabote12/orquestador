extends Node2D
## Damas contra la maquina: toca una ficha tuya y luego la casilla a la que va.
## Reglas, IA rival, bot y analizador en checkers_map.gd.
## 1 - Si puedes comer, solo se iluminan las fichas que comen (es obligatorio).
## 2 - Los saltos encadenados se hacen de una vez: tocas la casilla final.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const MapRules = preload("res://kit/checkers/checkers_map.gd")
const CELL: float = 84.0
const ORIGIN: Vector2 = Vector2(360.0 - 4.0 * CELL, 300.0)
const THINK: float = 0.7

var level: Dictionary = {}
var st: Dictionary = {}
var finished: bool = false
var failed: bool = false
var deaths: int = 0
var time_in_level: float = 0.0
var coins: int = 0
var coins_total: int = 1
var fast: bool = false
var auto_retry: bool = false
var result_panel: ResultPanel
var par: float = 0.0
var selected: Vector2i = Vector2i(-1, -1)

var _font: Font
var _world: Node2D
var _camera: Camera2D
var _turn_label: Label
var _hint_btn: Button
var _vs: VersusBar
var _anim: Dictionary = {}
var _think: float = 0.0
var _t: float = 0.0


func _ready() -> void:
	level = Kit.current_level()
	par = float(level.get("par", 40))
	RenderingServer.set_default_clear_color(Color("#3a2618"))
	_font = UI.theme.get_font("font", "Label") if UI.theme != null else ThemeDB.fallback_font
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
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "checkers", "depth": int(st["depth"])})


## Tablero claro: sin el brillo del etalonaje (lo quemaria).
func wants_grade() -> bool:
	return false


func bot_script() -> String:
	return "res://qa/checkers_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(4.0, 1.5)


func _reset() -> void:
	Hint.reset(self)
	finished = false
	failed = false
	st = MapRules.new_state(level)
	coins = 0
	time_in_level = 0.0
	selected = Vector2i(-1, -1)
	_anim = {}
	_think = THINK
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
	_turn_label.add_theme_font_size_override("font_size", 34)
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
	## Tu contra el rival: el heroe del juego, los marcadores y a quien le toca.
	_vs = VersusBar.make()
	col.add_child(_vs)


func _refresh() -> void:
	if _hint_btn != null:
		_hint_btn.text = Hint.label(self)
	if _turn_label == null or st.is_empty():
		return
	_turn_label.text = Kit.text("dm_you", "Tu turno") if str(st["turn"]) == "w" else Kit.text("dm_ai", "Piensa el rival...")
	if Kit.versus:
		_turn_label.text = Versus.turn_text(1 if str(st["turn"]) == "w" else 2)
	if _vs != null:
		_vs.set_state(int(st["captured"]["w"]), int(st["captured"]["b"]), str(st["turn"]) == "w")


# ------------------------------------------------------------------ acciones

func can_act() -> bool:
	return not finished and is_inside_tree() and not get_tree().paused and _anim.is_empty() and (str(st["turn"]) == "w" or Kit.versus) and str(st["winner"]) == ""


func _my_moves() -> Array:
	return MapRules.moves_of(st["g"], str(st["turn"]) if Kit.versus else "w")


func tap_cell(c: Vector2i) -> void:
	if not can_act():
		return
	var moves: Array = _my_moves()
	if selected.x >= 0:
		for mv: Dictionary in moves:
			var p: Array = mv["path"]
			if p[0] == selected and p[p.size() - 1] == c:
				_do(mv)
				return
	for mv2: Dictionary in moves:
		if (mv2["path"] as Array)[0] == c:
			selected = c
			_sfx("click")
			return
	selected = Vector2i(-1, -1)


func _do(mv: Dictionary) -> void:
	var p: Array = mv["path"]
	var a: Vector2i = p[0]
	var who: String = str(st["g"][a.y][a.x])
	MapRules.play(st, mv)
	_anim = {"path": p, "who": who, "t": 0.0, "eat": mv["eat"]}
	selected = Vector2i(-1, -1)
	_think = THINK
	_sfx("coin" if not (mv["eat"] as Array).is_empty() else "click")
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
	if can_act():
		var mv: Dictionary = MapRules.bot_move(st)
		if not mv.is_empty():
			_do(mv)


# ------------------------------------------------------------------ bucle

func _physics_process(delta: float) -> void:
	_t += delta
	var dt: float = delta * (8.0 if fast else 1.0)
	time_in_level += dt
	if not _anim.is_empty():
		_anim["t"] = float(_anim["t"]) + dt * 4.0
		if float(_anim["t"]) >= float((_anim["path"] as Array).size() - 1):
			_anim = {}
			_check_end()
	elif not finished and str(st["winner"]) == "" and str(st["turn"]) == "b" and not Kit.versus:
		_think -= dt
		if _think <= 0.0:
			var mv: Dictionary = MapRules.ai_move(st)
			if not mv.is_empty():
				_do(mv)
	elif not finished and str(st["winner"]) != "":
		_check_end()
	if fast and auto_retry and not finished:
		bot_step()
	_world.queue_redraw()


func _check_end() -> void:
	var w: String = str(st["winner"])
	if Kit.versus and w != "" and not finished:
		finished = true
		Versus.finish(self, {"w": 1, "b": 2}.get(w, 0))
		return
	if w == "w":
		_finish()
	elif w == "b" or w == "draw":
		_lose()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()
		return
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		var p: Vector2 = get_canvas_transform().affine_inverse() * (event as InputEventScreenTouch).position
		tap_cell(Vector2i(floori((p.x - ORIGIN.x) / CELL), floori((p.y - ORIGIN.y) / CELL)))


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	coins = 1
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = 1000 + int(st["captured"]["w"]) * 100 + maxi(0, 80 - int(st["moves"])) * 10
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
	return 3 if int(st["captured"]["b"]) <= 2 else 2


func _lose() -> void:
	if finished:
		return
	finished = true
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": str(st["winner"]), "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var title: String = Kit.text("dm_draw", "\u00a1Tablas!") if str(st["winner"]) == "draw" else Kit.text("dm_lost", "\u00a1Gan\u00f3 el rival!")
	var p: FailPanel = FailPanel.open(self, title,
		Kit.text("dm_fail_hint", "No dejes fichas sueltas que se puedan comer y corona damas: van hacia atr\u00e1s tambi\u00e9n."))
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
	return {"pos": Vector2(float(st.get("moves", 0)), 0.0), "deaths": deaths, "coins": coins, "finished": finished, "failed": failed,
		"stomps": 0, "time": time_in_level, "winner": str(st.get("winner", ""))}


# ------------------------------------------------------------------ dibujo

func _piece(c: Vector2, ch: String) -> void:
	var mine: bool = ch == "w" or ch == "W"
	var col: Color = Color("#f4ecd8") if mine else Color("#2a2a32")
	var rim: Color = Color("#c8b890") if mine else Color("#111118")
	_world.draw_circle(c + Vector2(3, 5), CELL * 0.38, Color(0, 0, 0, 0.35))
	_world.draw_circle(c, CELL * 0.38, rim)
	_world.draw_circle(c + Vector2(0, -3), CELL * 0.34, col)
	_world.draw_arc(c + Vector2(0, -3), CELL * 0.22, 0.0, TAU, 20, rim, 3.0)
	if ch == "W" or ch == "B":
		var k: Color = Color("#ffcf3a")
		var b: Vector2 = c + Vector2(0, -3)
		_world.draw_colored_polygon(PackedVector2Array([b + Vector2(-16, 8), b + Vector2(-16, -8), b + Vector2(-8, 0), b + Vector2(0, -12),
			b + Vector2(8, 0), b + Vector2(16, -8), b + Vector2(16, 8)]), k)


func _draw_world() -> void:
	if st.is_empty():
		return
	var g: Array = st["g"]
	var board: Rect2 = Rect2(ORIGIN, Vector2(8, 8) * CELL)
	_world.draw_rect(board.grow(22.0), Color("#5a3a1e"))
	_world.draw_rect(board.grow(22.0), Color("#7a5232"), false, 6.0)
	var targets: Array = []
	var movers: Array = []
	if can_act():
		for mv: Dictionary in _my_moves():
			var p: Array = mv["path"]
			movers.append(p[0])
			if p[0] == selected:
				targets.append(p[p.size() - 1])
	for y: int in 8:
		for x: int in 8:
			var r: Rect2 = Rect2(ORIGIN + Vector2(x, y) * CELL, Vector2(CELL, CELL))
			_world.draw_rect(r, Color("#8a5a32") if (x + y) % 2 == 1 else Color("#f0d9b0"))
			var c: Vector2i = Vector2i(x, y)
			if c == selected:
				_world.draw_rect(r, Color(1.0, 0.85, 0.2, 0.45))
			elif movers.has(c) and selected.x < 0:
				_world.draw_rect(r.grow(-3.0), Color(1.0, 0.85, 0.2, 0.25 + 0.15 * sin(_t * 5.0)), false, 4.0)
			if targets.has(c):
				_world.draw_circle(r.get_center(), CELL * 0.16, Color(0.3, 0.9, 0.4, 0.8))
	## Fichas; la que se mueve va por su camino y las comidas desaparecen al pasar.
	var moving: Vector2i = Vector2i(-1, -1)
	if not _anim.is_empty():
		var p2: Array = _anim["path"]
		moving = p2[p2.size() - 1]
	for y2: int in 8:
		for x2: int in 8:
			var ch: String = str(g[y2][x2])
			if ch == "." or Vector2i(x2, y2) == moving:
				continue
			_piece(ORIGIN + (Vector2(x2, y2) + Vector2(0.5, 0.5)) * CELL, ch)
	if not _anim.is_empty():
		var path: Array = _anim["path"]
		var t: float = float(_anim["t"])
		var seg: int = mini(int(t), path.size() - 2)
		var f: float = clampf(t - float(seg), 0.0, 1.0)
		var a: Vector2 = ORIGIN + (Vector2(path[seg]) + Vector2(0.5, 0.5)) * CELL
		var b: Vector2 = ORIGIN + (Vector2(path[seg + 1]) + Vector2(0.5, 0.5)) * CELL
		var eat: Array = _anim["eat"]
		for k: int in eat.size():
			if k >= seg:
				_piece(ORIGIN + (Vector2(eat[k]) + Vector2(0.5, 0.5)) * CELL, "b" if str(_anim["who"]).to_lower() == "w" else "w")
		_piece(a.lerp(b, f) + Vector2(0, -sin(f * PI) * 26.0), str(_anim["who"]))
