extends Node2D
## Estrategia por turnos: toca una unidad tuya (se ven en azul sus casillas y en rojo a quien puede
## atacar), toca una casilla para moverla y luego un rival para atacar o "Esperar". "Fin del turno"
## pasa al rival, que juega unidad a unidad. Gana capturando su cuartel (2 turnos con infanteria
## encima) o sin unidades rivales. Reglas, IA, bot y analizador en tactics_map.gd.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const M = preload("res://kit/tactics/tactics_map.gd")
const STEP: float = 0.45

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
## Fase: "player" (te toca), "enemy" (juega el rival).
var phase: String = "player"
var selected: int = -1

var _view: Control
var _info: Label
var _vs: VersusBar
var _wait_btn: Button
var _end_btn: Button
var _reach: Dictionary = {}
var _targets: Array = []
## Zona de peligro del rival tocado (casillas que puede atacar el turno que viene).
var _danger: Dictionary = {}
var _danger_id: int = -1
var _anim: Dictionary = {}
var _queue: Array = []
var _enemy_t: float = 0.0
var _floats: Array = []
var _t: float = 0.0


func _ready() -> void:
	level = Kit.current_level()
	RenderingServer.set_default_clear_color(Color("#1b2a1f"))
	_build_hud()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "tactics", "units": M.alive(st, 1).size()})


func wants_grade() -> bool:
	return false


func bot_script() -> String:
	return "res://qa/tactics_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(3.0, 1.5)


func _reset() -> void:
	finished = false
	failed = false
	st = M.new_state(level)
	coins_total = M.alive(st, 2).size()
	coins = 0
	time_in_level = 0.0
	phase = "player"
	selected = -1
	_reach = {}
	_targets = []
	_danger = {}
	_danger_id = -1
	_anim = {}
	_queue = []
	_floats = []
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
	col.add_theme_constant_override("separation", 6)
	safe.add_child(col)
	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top)
	_info = Label.new()
	_info.name = "Info"
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.add_theme_font_size_override("font_size", 26)
	_info.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_info.add_theme_constant_override("outline_size", 6)
	top.add_child(_info)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)
	_vs = VersusBar.make()
	col.add_child(_vs)
	_view = Control.new()
	_view.name = "View"
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.draw.connect(_draw_view)
	_view.gui_input.connect(_on_input)
	col.add_child(_view)
	var bottom: HBoxContainer = HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	col.add_child(bottom)
	_wait_btn = UI.make_button(Kit.text("tc_wait", "Esperar"), false, "")
	_wait_btn.name = "BtnWait"
	_wait_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wait_btn.pressed.connect(wait_selected)
	bottom.add_child(_wait_btn)
	_end_btn = UI.make_button(Kit.text("tc_end", "Fin del turno"), true, "play")
	_end_btn.name = "BtnEndTurn"
	_end_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_end_btn.pressed.connect(end_turn)
	bottom.add_child(_end_btn)


func _refresh() -> void:
	if st.is_empty() or _info == null:
		return
	var who: String = Kit.text("tc_you", "Tu turno") if phase == "player" else Kit.text("tc_ai", "Juega el rival...")
	_info.text = Kit.text("tc_turn", "Turno {a}/{b}").format({"a": int(st["turn"]), "b": int(st["max_turns"])}) + "  \u00b7  " + who
	coins = coins_total - M.alive(st, 2).size()
	_vs.set_state(M.alive(st, 1).size(), M.alive(st, 2).size(), phase == "player")
	_wait_btn.disabled = not can_act() or selected < 0
	_end_btn.disabled = not can_act()
	_view.queue_redraw()


# ------------------------------------------------------------------ jugar

func can_act() -> bool:
	return not finished and is_inside_tree() and not get_tree().paused and phase == "player" and _anim.is_empty() \
		and not bool(st["won"]) and not bool(st["lost"])


func _board() -> Rect2:
	var w: int = int(st["w"])
	var h: int = int(st["h"])
	var cs: float = minf((_view.size.x - 8.0) / float(w), (_view.size.y - 8.0) / float(h))
	var sz: Vector2 = Vector2(w, h) * cs
	return Rect2((_view.size - sz) * 0.5, sz)


func _cell() -> float:
	return _board().size.x / float(int(st["w"]))


func select(id: int) -> void:
	var u: Dictionary = M.unit_by_id(st, id)
	if u.is_empty() or int(u["side"]) != 1 or bool(u["done"]):
		selected = -1
		_reach = {}
		_targets = []
	else:
		selected = id
		_reach = {} if bool(u["moved"]) else M.reach(st, u)
		var here: Vector2i = Vector2i(int(u["x"]), int(u["y"]))
		_targets = [] if (str(u["t"]) == "art" and bool(u.get("shifted", false))) else M.targets_from(st, u, here)
		_sfx("click", -12.0)
	_refresh()


func tap_cell(c: Vector2i) -> void:
	if not can_act():
		return
	var other: Dictionary = M.unit_at(st, c)
	if selected >= 0:
		var u: Dictionary = M.unit_by_id(st, selected)
		## Atacar a un rival marcado.
		if not other.is_empty() and int(other["side"]) == 2 and _targets.has(other):
			_do_attack(u, other)
			return
		## Moverse a una casilla marcada.
		if not bool(u["moved"]) and _reach.has(c) and (other.is_empty() or int(other["id"]) == int(u["id"])):
			var from: Vector2i = Vector2i(int(u["x"]), int(u["y"]))
			M.move(st, int(u["id"]), c)
			_anim = {"id": int(u["id"]), "from": from, "to": c, "t": 0.0}
			_reach = {}
			_targets = [] if (str(u["t"]) == "art" and bool(u.get("shifted", false))) else M.targets_from(st, u, c)
			if _targets.is_empty():
				M.wait(st, int(u["id"]))
				selected = -1
			_sfx("click", -10.0)
			_refresh()
			return
	if not other.is_empty() and int(other["side"]) == 1 and not bool(other["done"]):
		_danger = {}
		_danger_id = -1
		select(int(other["id"]))
	elif not other.is_empty() and int(other["side"]) == 2:
		## Tocar un rival: ver hasta donde puede pegar (otra vez para quitarlo).
		select(-1)
		if _danger_id == int(other["id"]):
			_danger = {}
			_danger_id = -1
		else:
			_danger = M.threat(st, other)
			_danger_id = int(other["id"])
		_refresh()
	else:
		_danger = {}
		_danger_id = -1
		select(-1)


func _do_attack(u: Dictionary, v: Dictionary) -> void:
	var hp0: int = int(v["hp"])
	var my0: int = int(u["hp"])
	if not M.move(st, int(u["id"]), Vector2i(int(u["x"]), int(u["y"]))) and not bool(u["moved"]):
		return
	if not M.attack(st, int(u["id"]), int(v["id"])):
		return
	_float(Vector2i(int(v["x"]), int(v["y"])), hp0 - int(v["hp"]), true)
	if int(u["hp"]) < my0:
		_float(Vector2i(int(u["x"]), int(u["y"])), my0 - int(u["hp"]), false)
	_sfx("hurt" if int(v["hp"]) > 0 else "coin", -6.0)
	selected = -1
	_targets = []
	_refresh()
	_check()


func wait_selected() -> void:
	if can_act() and selected >= 0:
		var u: Dictionary = M.unit_by_id(st, selected)
		if not bool(u["moved"]):
			M.move(st, selected, Vector2i(int(u["x"]), int(u["y"])))
		M.wait(st, selected)
		select(-1)


func end_turn() -> void:
	if not can_act():
		return
	selected = -1
	_reach = {}
	_targets = []
	_danger = {}
	_danger_id = -1
	M.end_turn(st)
	if _check():
		return
	phase = "enemy"
	_queue = M.ai_order(st)
	_enemy_t = STEP * 0.6
	_refresh()


## Turno del rival: una unidad cada STEP segundos (al momento con prisa).
func _enemy_step() -> void:
	while not _queue.is_empty():
		var u: Dictionary = _queue.pop_front()
		if int(u["hp"]) <= 0 or bool(u["done"]):
			continue
		var plan: Dictionary = M.ai_plan(st, u, float(st["ai_smart"]))
		var from: Vector2i = Vector2i(int(u["x"]), int(u["y"]))
		var target: Dictionary = M.unit_by_id(st, int(plan["target"])) if int(plan["target"]) >= 0 else {}
		var thp: int = int(target.get("hp", 0))
		var uhp: int = int(u["hp"])
		M.ai_do(st, u, plan)
		if Vector2i(plan["to"]) != from:
			_anim = {"id": int(u["id"]), "from": from, "to": Vector2i(plan["to"]), "t": 0.0}
		if not target.is_empty() and int(target["hp"]) < thp:
			_float(Vector2i(int(target["x"]), int(target["y"])), thp - int(target["hp"]), false)
			_sfx("hurt", -8.0)
		if int(u["hp"]) < uhp:
			_float(Vector2i(int(u["x"]), int(u["y"])), uhp - int(u["hp"]), true)
		_refresh()
		if _check():
			return
		return
	M.end_turn(st)
	phase = "player"
	_refresh()
	_check()


func _check() -> bool:
	if bool(st["won"]):
		_finish()
		return true
	if bool(st["lost"]):
		_lose()
		return true
	return false


## Bot: la misma IA que el analizador (prudencia maxima), unidad a unidad.
func bot_step() -> void:
	if not can_act():
		return
	for u: Variant in M.ai_order(st):
		if not bool(u["done"]) and int(u["hp"]) > 0:
			var plan: Dictionary = M.ai_plan(st, u, M.BOT_SMART)
			M.ai_do(st, u, plan)
			_refresh()
			_check()
			return
	end_turn()


func _float(c: Vector2i, n: int, good: bool) -> void:
	if n > 0:
		_floats.append({"c": c, "n": n, "good": good, "t": 0.0})


func _on_input(event: InputEvent) -> void:
	var p: Vector2 = Vector2.INF
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		p = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and not DisplayServer.is_touchscreen_available():
		p = (event as InputEventMouseButton).position
	if p == Vector2.INF:
		return
	var b: Rect2 = _board()
	if not b.has_point(p):
		return
	var q: Vector2 = (p - b.position) / _cell()
	tap_cell(Vector2i(int(q.x), int(q.y)))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()


func _sfx(nm: String, vol: float = -6.0) -> void:
	if not fast:
		Audio.play(nm, 0.1, vol)


func _physics_process(delta: float) -> void:
	if st.is_empty() or get_tree().paused:
		return
	_t += delta
	var dt: float = delta * (20.0 if fast else 1.0)
	if not finished:
		time_in_level += delta
	if not _anim.is_empty():
		_anim["t"] = float(_anim["t"]) + dt * 4.0
		if float(_anim["t"]) >= 1.0:
			_anim = {}
			_refresh()
	elif phase == "enemy" and not finished:
		_enemy_t -= dt
		if _enemy_t <= 0.0:
			_enemy_t = STEP
			_enemy_step()
	elif fast and auto_retry and not finished:
		bot_step()
	for f: Variant in _floats:
		(f as Dictionary)["t"] = float((f as Dictionary)["t"]) + delta
	_floats = _floats.filter(func(f: Dictionary) -> bool: return float(f["t"]) < 1.0)
	_view.queue_redraw()


# ------------------------------------------------------------------ dibujo

const SIDE_COL: Array[Color] = [Color("#9e9e9e"), Color("#3a86ff"), Color("#e63946")]


func _draw_view() -> void:
	if st.is_empty():
		return
	var b: Rect2 = _board()
	var cs: float = _cell()
	var w: int = int(st["w"])
	var h: int = int(st["h"])
	var owner: Dictionary = st["owner"]
	var caps: Dictionary = st.get("caps", {})
	_view.draw_rect(b.grow(6.0), Color("#0f1a12"))
	for y: int in h:
		for x: int in w:
			var r: Rect2 = Rect2(b.position + Vector2(x, y) * cs, Vector2(cs, cs))
			var t: String = M.tile(st, Vector2i(x, y))
			var base: Color = Color("#7cb342") if (x + y) % 2 == 0 else Color("#74aa3e")
			if t == "~":
				base = Color("#2f7fc1").lightened(0.06 * sin(_t * 2.0 + float(x + y)))
			_view.draw_rect(r, base)
			var c: Vector2 = r.get_center()
			match t:
				"f":
					for k: int in 3:
						var o: Vector2 = Vector2([-0.22, 0.2, 0.0][k], [0.12, 0.1, -0.18][k]) * cs
						_view.draw_circle(c + o, cs * 0.2, Color("#2e7d32"))
				"m":
					_view.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.42, 0.35) * cs, c + Vector2(0, -0.4) * cs, c + Vector2(0.42, 0.35) * cs]), Color("#8d8d8d"))
					_view.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.13, -0.1) * cs, c + Vector2(0, -0.4) * cs, c + Vector2(0.13, -0.1) * cs]), Color("#f5f5f5"))
				"c", "H", "h":
					var big: bool = t != "c"
					var bw: float = cs * (0.62 if big else 0.46)
					_view.draw_rect(Rect2(c + Vector2(-bw * 0.5, -bw * 0.25), Vector2(bw, bw * 0.75)), Color("#d7ccc8"))
					_view.draw_colored_polygon(PackedVector2Array([c + Vector2(-bw * 0.6, -bw * 0.25), c + Vector2(0, -bw * 0.75), c + Vector2(bw * 0.6, -bw * 0.25)]), Color("#8d6e63"))
					var own: int = int(owner.get(Vector2i(x, y), 0))
					_view.draw_line(c + Vector2(bw * 0.35, -bw * 0.3), c + Vector2(bw * 0.35, -bw * 1.0), Color("#4e342e"), 3.0)
					_view.draw_rect(Rect2(c + Vector2(bw * 0.35, -bw * 1.0), Vector2(bw * 0.4, bw * 0.25)), SIDE_COL[own])
					if caps.has(Vector2i(x, y)):
						var pts: float = float(int(caps[Vector2i(x, y)]["pts"])) / 20.0
						_view.draw_rect(Rect2(r.position + Vector2(4, cs - 10), Vector2((cs - 8) * pts, 6)), Color("#ffd166"))
	## Zona de peligro del rival tocado (naranja con borde).
	for dq: Variant in _danger.keys():
		var dr: Rect2 = Rect2(b.position + Vector2(dq) * cs, Vector2(cs, cs)).grow(-3.0)
		_view.draw_rect(dr, Color(1.0, 0.35, 0.1, 0.4))
		_view.draw_rect(dr, Color(1.0, 0.4, 0.1, 0.9), false, 3.0)
	## Casillas a las que llega (azul) y rivales a los que ataca (rojo).
	for q: Variant in _reach.keys():
		_view.draw_rect(Rect2(b.position + Vector2(q) * cs, Vector2(cs, cs)).grow(-2.0), Color(0.3, 0.6, 1.0, 0.38))
	for v: Variant in _targets:
		var tr: Rect2 = Rect2(b.position + Vector2(int(v["x"]), int(v["y"])) * cs, Vector2(cs, cs))
		_view.draw_rect(tr.grow(-2.0), Color(1.0, 0.25, 0.2, 0.3 + 0.2 * sin(_t * 6.0)))
	## Unidades.
	for u: Variant in st["units"]:
		if int(u["hp"]) <= 0:
			continue
		var pos: Vector2 = b.position + (Vector2(int(u["x"]), int(u["y"])) + Vector2(0.5, 0.5)) * cs
		if not _anim.is_empty() and int(_anim["id"]) == int(u["id"]):
			var k2: float = clampf(float(_anim["t"]), 0.0, 1.0)
			pos = b.position + (Vector2(_anim["from"]).lerp(Vector2(_anim["to"]), k2) + Vector2(0.5, 0.5)) * cs
		_draw_unit(pos, u, cs, int(u["id"]) == selected)
	var font: Font = _view.get_theme_font("font", "Label")
	## Antes de atacar: dano que harias y contraataque que te llevarias.
	if selected >= 0:
		var su: Dictionary = M.unit_by_id(st, selected)
		for v2: Variant in _targets:
			var pv: Array = M.preview(st, su, v2)
			var tp: Vector2 = b.position + Vector2(int(v2["x"]), int(v2["y"])) * cs
			var big: int = maxi(24, int(cs * 0.42))
			var kill: bool = int(pv[0]) >= int(v2["hp"])
			var txt: String = ("-%d" % int(pv[0])) + (" \u2620" if kill else "")
			## Dano encima de la casilla del rival; contraataque debajo.
			var top_at: Vector2 = tp + Vector2(-cs * 0.5, -4.0)
			_view.draw_string_outline(font, top_at, txt, HORIZONTAL_ALIGNMENT_CENTER, cs * 2.0, big, 7, Color.BLACK)
			_view.draw_string(font, top_at, txt, HORIZONTAL_ALIGNMENT_CENTER, cs * 2.0, big, Color("#ffd166"))
			if int(pv[1]) > 0:
				var bt: String = "\u21a9 -%d" % int(pv[1])
				var low_at: Vector2 = tp + Vector2(-cs * 0.5, cs + big * 0.8)
				_view.draw_string_outline(font, low_at, bt, HORIZONTAL_ALIGNMENT_CENTER, cs * 2.0, int(big * 0.8), 6, Color.BLACK)
				_view.draw_string(font, low_at, bt, HORIZONTAL_ALIGNMENT_CENTER, cs * 2.0, int(big * 0.8), Color("#ff6b6b"))
	## Numeros de dano que suben.
	for f: Variant in _floats:
		var fd: Dictionary = f
		var fp: Vector2 = b.position + (Vector2(fd["c"]) + Vector2(0.2, 0.3)) * cs - Vector2(0, float(fd["t"]) * 40.0)
		_view.draw_string_outline(font, fp, "-%d" % int(fd["n"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, 6, Color.BLACK)
		_view.draw_string(font, fp, "-%d" % int(fd["n"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("#ffd166") if bool(fd["good"]) else Color("#ff6b6b"))


func _draw_unit(c: Vector2, u: Dictionary, cs: float, sel: bool) -> void:
	var side: int = int(u["side"])
	var col: Color = SIDE_COL[side]
	var dim: bool = side == 1 and bool(u["done"]) and phase == "player"
	if dim:
		col = col.lerp(Color("#555555"), 0.6)
	var r: float = cs * 0.38
	if sel:
		_view.draw_circle(c, r + 6.0 + 2.0 * sin(_t * 8.0), Color(1, 0.9, 0.3, 0.8))
	_view.draw_circle(c + Vector2(2, 4), r, Color(0, 0, 0, 0.35))
	_view.draw_circle(c, r, col.darkened(0.35))
	_view.draw_circle(c, r * 0.86, col)
	var ink: Color = Color("#fdfdfd")
	match str(u["t"]):
		"inf":
			_view.draw_circle(c + Vector2(0, -r * 0.3), r * 0.22, ink)
			_view.draw_rect(Rect2(c + Vector2(-r * 0.2, -r * 0.08), Vector2(r * 0.4, r * 0.5)), ink)
		"tank":
			_view.draw_rect(Rect2(c + Vector2(-r * 0.5, -r * 0.05), Vector2(r * 1.0, r * 0.42)), ink)
			_view.draw_rect(Rect2(c + Vector2(-r * 0.25, -r * 0.32), Vector2(r * 0.5, r * 0.3)), ink)
			_view.draw_line(c + Vector2(0, -r * 0.2), c + Vector2(r * 0.6 * (1.0 if side == 1 else -1.0), -r * 0.42), ink, 4.0)
		"art":
			_view.draw_circle(c + Vector2(-r * 0.2, r * 0.25), r * 0.22, ink)
			_view.draw_line(c + Vector2(-r * 0.2, r * 0.15), c + Vector2(r * 0.45, -r * 0.45), ink, 6.0)
	if int(u["hp"]) < 10:
		var font: Font = _view.get_theme_font("font", "Label")
		var hp_p: Vector2 = c + Vector2(r * 0.3, r * 0.95)
		_view.draw_string_outline(font, hp_p, str(int(u["hp"])), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 5, Color.BLACK)
		_view.draw_string(font, hp_p, str(int(u["hp"])), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = 600 + M.alive(st, 1).size() * 150 + maxi(0, int(st["max_turns"]) - int(st["turn"])) * 30
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "turns": int(st["turn"]), "time": snappedf(time_in_level, 0.1)})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins_total, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


## Estrellas: sin perder unidades, 3; perdiendo menos de la mitad, 2; si no, 1.
func stars_earned() -> int:
	var start: int = 0
	for u: Variant in level.get("units", []):
		if int((u as Dictionary).get("side", 1)) == 1:
			start += 1
	var left: int = M.alive(st, 1).size()
	return 3 if left >= start else (2 if left * 2 > start else 1)


func _lose() -> void:
	if failed:
		return
	finished = true
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "tactics", "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var title: String = Kit.text("tc_time", "Se acabaron los turnos") if int(st["turn"]) > int(st["max_turns"]) else Kit.text("tc_lost", "\u00a1Derrota!")
	var p: FailPanel = FailPanel.open(self, title,
		Kit.text("tc_hint", "Avanza en grupo, deja que la artilleria dispare desde lejos y usa los bosques y montanas para defenderte."))
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
		"turn": int(st.get("turn", 0))}
