extends Node2D
## Gemas y heroes: cambia dos gemas vecinas (tocando una y otra, o arrastrando) para hacer lineas.
## Cada color hace atacar a tus heroes de ese color; los corazones curan. Cuando un heroe brilla, toca
## su retrato para su especial. Los monstruos atacan al llegar a 0 su cuenta atras.
## Reglas, bot y analizador en gemrpg_map.gd. Contrato con el kit: finished, deaths, time_in_level,
## fast, auto_retry, bot_script(), bot_state(), retry(), open_pause() y ResultPanel/FailPanel.

const M = preload("res://kit/gemrpg/gemrpg_map.gd")
const GEM_COLS: Array[String] = ["#ef476f", "#118ab2", "#06d6a0", "#ffd166", "#7b2cbf", "#ff8fab"]

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
var selected: int = -1

var _view: Control
var _info: Label
var _hero_tex: Texture2D = null
var _pops: Array = []
var _floats: Array = []
var _shake: float = 0.0
var _hurt: float = 0.0
var _drag_from: int = -1
var _drag_pos: Vector2 = Vector2.ZERO
var _t: float = 0.0


func _ready() -> void:
	level = Kit.current_level()
	RenderingServer.set_default_clear_color(Color("#16132a"))
	var hero: Dictionary = Kit.sprite_by_role("jugador")
	if not hero.is_empty():
		var sf: SpriteFrames = SpriteKit.frames_de(hero)
		for anim: String in sf.get_animation_names():
			if sf.get_frame_count(anim) > 0:
				_hero_tex = sf.get_frame_texture(anim, 0)
				break
	_build_hud()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "gemrpg", "waves": coins_total})


func wants_grade() -> bool:
	return false


func bot_script() -> String:
	return "res://qa/gemrpg_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(2.5, 1.5)


func _reset() -> void:
	finished = false
	failed = false
	st = M.new_state(level)
	coins_total = (st["waves"] as Array).size()
	coins = 0
	time_in_level = 0.0
	selected = -1
	_pops = []
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
	safe.add_child(col)
	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top)
	_info = Label.new()
	_info.name = "Info"
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	_view.draw.connect(_draw_view)
	_view.gui_input.connect(_on_input)
	col.add_child(_view)


func _refresh() -> void:
	if st.is_empty() or _info == null:
		return
	var txt: String = Kit.text("gr_wave", "Oleada {a}/{b}").format({"a": mini(int(st["wave"]) + 1, coins_total), "b": coins_total})
	if int(st["max_moves"]) > 0:
		txt += "   " + Kit.text("gr_moves", "Jugadas {a}/{b}").format({"a": int(st["moves"]), "b": int(st["max_moves"])})
	_info.text = txt
	coins = int(st["wave"])
	_view.queue_redraw()


func can_act() -> bool:
	return not finished and not failed and is_inside_tree() and not get_tree().paused and not bool(st["won"]) and not bool(st["lost"])


# ------------------------------------------------------------------ zonas de la pantalla

func _enemy_rect() -> Rect2:
	return Rect2(Vector2(0, 0), Vector2(_view.size.x, _view.size.y * 0.22))


func _team_rect(k: int) -> Rect2:
	var n: int = (st["team"] as Array).size()
	var w: float = minf(150.0, (_view.size.x - 20.0) / float(maxi(n, 1)))
	var x0: float = (_view.size.x - w * float(n)) * 0.5
	return Rect2(Vector2(x0 + w * float(k), _view.size.y * 0.235), Vector2(w, w * 0.9)).grow(-6.0)


func _board() -> Rect2:
	var top: float = _view.size.y * 0.235 + minf(150.0, (_view.size.x - 20.0) / float(maxi((st["team"] as Array).size(), 1))) * 0.9 + 40.0
	var side: float = minf(_view.size.x - 8.0, _view.size.y - top - 4.0)
	return Rect2(Vector2((_view.size.x - side) * 0.5, top), Vector2(side, side))


func _cell_at(p: Vector2) -> int:
	var b: Rect2 = _board()
	if not b.has_point(p):
		return -1
	var cs: float = b.size.x / float(M.N)
	return clampi(int((p.y - b.position.y) / cs), 0, M.N - 1) * M.N + clampi(int((p.x - b.position.x) / cs), 0, M.N - 1)


# ------------------------------------------------------------------ acciones

func try_swap(a: int, b: int) -> void:
	if not can_act():
		return
	var board: Array = st["board"]
	## Donde se rompera (para el efecto), con el cambio hecho en una copia.
	var copy: Array = board.duplicate()
	var t: int = int(copy[a])
	copy[a] = copy[b]
	copy[b] = t
	var will: Dictionary = M.matches(copy)
	var res: Dictionary = M.swap(st, a, b)
	selected = -1
	if res.is_empty():
		_sfx("hurt", -16.0)
		_view.queue_redraw()
		return
	for i: Variant in will.keys():
		_pops.append({"i": int(i), "c": int(copy[int(i)]), "t": 0.0})
	for h: Variant in res["hits"]:
		_floats.append({"txt": "-%d" % int(h["dmg"]), "where": "enemy", "col": Color(GEM_COLS[int((st["team"] as Array)[int(h["hero"])]["c"])]), "t": 0.0})
	if int(res["heal"]) > 0:
		_floats.append({"txt": "+%d" % int(res["heal"]), "where": "team", "col": Color("#06d6a0"), "t": 0.0})
	for e: Variant in res["enemy_hits"]:
		_floats.append({"txt": "-%d" % int(e), "where": "team", "col": Color("#ff6b6b"), "t": 0.0})
		_shake = 0.3
		_hurt = 0.4
	_sfx("coin" if int(res["combo"]) < 2 else "powerup", -8.0)
	_after()


func skill(k: int) -> void:
	if can_act() and M.use_skill(st, k):
		_sfx("powerup", -4.0)
		_floats.append({"txt": "\u2605", "where": "enemy", "col": Color("#ffd166"), "t": 0.0})
		_after()


func _after() -> void:
	_refresh()
	if bool(st["won"]):
		_finish()
	elif bool(st["lost"]):
		_lose()


func bot_step() -> void:
	if not can_act():
		return
	var m: Array = M.bot_move(st)
	if m.is_empty():
		return
	if int(m[0]) < 0:
		skill(int(m[1]))
	else:
		try_swap(int(m[0]), int(m[1]))


func _on_input(event: InputEvent) -> void:
	var pressed: bool = false
	var released: bool = false
	var p: Vector2 = Vector2.INF
	if event is InputEventScreenTouch:
		p = (event as InputEventScreenTouch).position
		pressed = (event as InputEventScreenTouch).pressed
		released = not pressed
	elif event is InputEventMouseButton and not DisplayServer.is_touchscreen_available():
		p = (event as InputEventMouseButton).position
		pressed = (event as InputEventMouseButton).pressed
		released = not pressed
	elif event is InputEventScreenDrag:
		_drag_pos = (event as InputEventScreenDrag).position
		return
	if p == Vector2.INF:
		return
	if pressed:
		for k: int in (st["team"] as Array).size():
			if _team_rect(k).has_point(p):
				skill(k)
				return
		var c: int = _cell_at(p)
		if c < 0:
			return
		if selected >= 0 and M.adjacent(selected, c):
			try_swap(selected, c)
			return
		selected = c
		_drag_from = c
		_drag_pos = p
		_view.queue_redraw()
	elif released and _drag_from >= 0:
		## Arrastre: a la vecina en la direccion del dedo.
		var b: Rect2 = _board()
		var cs: float = b.size.x / float(M.N)
		var from_c: Vector2 = b.position + (Vector2(_drag_from % M.N, _drag_from / M.N) + Vector2(0.5, 0.5)) * cs
		var d: Vector2 = p - from_c
		var from: int = _drag_from
		_drag_from = -1
		if d.length() > cs * 0.45:
			var to: int = from + (int(signf(d.x)) if absf(d.x) > absf(d.y) else int(signf(d.y)) * M.N)
			if to >= 0 and to < M.N * M.N and M.adjacent(from, to):
				try_swap(from, to)


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
	_shake = maxf(0.0, _shake - delta)
	_hurt = maxf(0.0, _hurt - delta)
	if not finished and not failed:
		time_in_level += delta
		if fast and auto_retry:
			bot_step()
	for p: Variant in _pops:
		(p as Dictionary)["t"] = float((p as Dictionary)["t"]) + delta
	_pops = _pops.filter(func(p: Dictionary) -> bool: return float(p["t"]) < 0.35)
	for f: Variant in _floats:
		(f as Dictionary)["t"] = float((f as Dictionary)["t"]) + delta
	_floats = _floats.filter(func(f: Dictionary) -> bool: return float(f["t"]) < 0.9)
	_view.queue_redraw()


# ------------------------------------------------------------------ dibujo

func _gem(c: Vector2, col: int, r: float) -> void:
	var cc: Color = Color(GEM_COLS[col])
	_view.draw_circle(c + Vector2(0, 3), r, cc.darkened(0.5))
	if col == M.HEART:
		_view.draw_circle(c + Vector2(-r * 0.32, -r * 0.15), r * 0.48, cc)
		_view.draw_circle(c + Vector2(r * 0.32, -r * 0.15), r * 0.48, cc)
		_view.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.78, 0), c + Vector2(r * 0.78, 0), c + Vector2(0, r * 0.8)]), cc)
		return
	var sides: int = [6, 4, 3, 8, 5][col]
	var pts: PackedVector2Array = PackedVector2Array()
	for k: int in sides:
		var a: float = -PI * 0.5 + TAU * float(k) / float(sides) + (PI / 4.0 if sides == 4 else 0.0)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	_view.draw_colored_polygon(pts, cc)
	_view.draw_circle(c + Vector2(-r * 0.28, -r * 0.3), r * 0.22, Color(1, 1, 1, 0.45))


func _draw_view() -> void:
	if st.is_empty():
		return
	var off: Vector2 = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 8.0 * _shake if not fast else Vector2.ZERO
	var font: Font = _view.get_theme_font("font", "Label")
	## Monstruos.
	var er: Rect2 = _enemy_rect()
	var foes: Array = (st["enemies"] as Array).filter(func(e: Dictionary) -> bool: return int(e["hp"]) > 0)
	for k: int in foes.size():
		var e: Dictionary = foes[k]
		var cx: float = er.size.x * (float(k) + 0.5) / float(foes.size())
		var c: Vector2 = Vector2(cx, er.size.y * 0.45) + off
		var rad: float = minf(er.size.y * 0.32, er.size.x / float(foes.size()) * 0.3) * (1.0 if k == 0 else 0.8)
		var ec: Color = Color(GEM_COLS[int(e["c"])])
		_view.draw_circle(c + Vector2(0, 6), rad, Color(0, 0, 0, 0.35))
		_view.draw_circle(c, rad, ec.darkened(0.2))
		_view.draw_circle(c + Vector2(-rad * 0.35, -rad * 0.15), rad * 0.18, Color.WHITE)
		_view.draw_circle(c + Vector2(rad * 0.35, -rad * 0.15), rad * 0.18, Color.WHITE)
		_view.draw_circle(c + Vector2(-rad * 0.32, -rad * 0.12), rad * 0.08, Color.BLACK)
		_view.draw_circle(c + Vector2(rad * 0.38, -rad * 0.12), rad * 0.08, Color.BLACK)
		_view.draw_line(c + Vector2(-rad * 0.3, rad * 0.35), c + Vector2(rad * 0.3, rad * 0.3), Color.BLACK, 4.0)
		var bw: float = rad * 2.2
		_view.draw_rect(Rect2(c + Vector2(-bw * 0.5, rad + 8), Vector2(bw, 10)), Color(0, 0, 0, 0.6))
		_view.draw_rect(Rect2(c + Vector2(-bw * 0.5, rad + 8), Vector2(bw * float(e["hp"]) / float(e["max"]), 10)), Color("#ef476f"))
		## Cuenta atras de su ataque.
		var cd_c: Vector2 = c + Vector2(rad * 0.85, -rad * 0.85)
		_view.draw_circle(cd_c, 20.0, Color("#ffd166") if int(e["cd"]) <= 1 else Color("#2b2d42"))
		_view.draw_string(font, cd_c + Vector2(-20, 9), str(int(e["cd"])), HORIZONTAL_ALIGNMENT_CENTER, 40, 24, Color.BLACK if int(e["cd"]) <= 1 else Color.WHITE)
	if int(st["stun"]) > 0:
		_view.draw_string(font, Vector2(0, er.end.y - 6), Kit.text("gr_stun", "\u00a1Aturdidos!"), HORIZONTAL_ALIGNMENT_CENTER, er.size.x, 26, Color("#ffd166"))
	## Equipo: retratos con su carga; el primero lleva el arte del heroe del juego.
	var team: Array = st["team"]
	for k2: int in team.size():
		var h: Dictionary = team[k2]
		var tr: Rect2 = _team_rect(k2)
		var hc: Color = Color(GEM_COLS[int(h["c"])])
		var full: bool = int(h["charge"]) >= M.CHARGE
		if full:
			_view.draw_rect(tr.grow(5.0 + 2.0 * sin(_t * 8.0)), Color(1, 0.9, 0.3, 0.8))
		_view.draw_rect(tr, hc.darkened(0.45))
		_view.draw_rect(tr, hc, false, 4.0)
		if k2 == 0 and _hero_tex != null:
			var ts: Vector2 = _hero_tex.get_size()
			var kk: float = (tr.size.y * 0.8) / maxf(ts.x, ts.y)
			_view.draw_texture_rect(_hero_tex, Rect2(tr.get_center() - ts * kk * 0.5 - Vector2(0, 6), ts * kk), false)
		else:
			_gem(tr.get_center() - Vector2(0, 8), int(h["c"]), tr.size.y * 0.28)
		_view.draw_rect(Rect2(tr.position + Vector2(4, tr.size.y - 12), Vector2((tr.size.x - 8) * float(h["charge"]) / float(M.CHARGE), 8)), Color("#ffd166"))
	## Vida del equipo.
	var hb: Rect2 = Rect2(Vector2(_view.size.x * 0.08, _team_rect(0).end.y + 10), Vector2(_view.size.x * 0.84, 16))
	_view.draw_rect(hb, Color(0, 0, 0, 0.6))
	_view.draw_rect(Rect2(hb.position, Vector2(hb.size.x * float(st["hp"]) / float(st["max_hp"]), hb.size.y)), Color("#06d6a0") if _hurt <= 0.0 else Color("#ef476f"))
	_view.draw_string(font, hb.position + Vector2(0, 14), "%d/%d" % [int(st["hp"]), int(st["max_hp"])], HORIZONTAL_ALIGNMENT_CENTER, hb.size.x, 18, Color.WHITE)
	## Tablero.
	var b: Rect2 = _board()
	var cs: float = b.size.x / float(M.N)
	_view.draw_rect(b.grow(6.0), Color("#0d0b1a"))
	var board: Array = st["board"]
	for i: int in M.N * M.N:
		var cell: Rect2 = Rect2(b.position + Vector2(i % M.N, i / M.N) * cs, Vector2(cs, cs))
		_view.draw_rect(cell.grow(-1.0), Color("#221d3d") if (i % M.N + i / M.N) % 2 == 0 else Color("#1d1934"))
		if i == selected:
			_view.draw_rect(cell.grow(-2.0), Color(1, 0.9, 0.3, 0.5))
		_gem(cell.get_center(), int(board[i]), cs * 0.36)
	for p: Variant in _pops:
		var pd: Dictionary = p
		var pc: Vector2 = b.position + (Vector2(int(pd["i"]) % M.N, int(pd["i"]) / M.N) + Vector2(0.5, 0.5)) * cs
		_view.draw_arc(pc, cs * (0.3 + float(pd["t"]) * 1.4), 0.0, TAU, 20, Color(GEM_COLS[int(pd["c"])]).lerp(Color.WHITE, 0.4), 4.0)
	## Numeros.
	for f: Variant in _floats:
		var fd: Dictionary = f
		var y0: float = er.size.y * 0.3 if str(fd["where"]) == "enemy" else hb.position.y - 10
		var fp: Vector2 = Vector2(_view.size.x * 0.5 - 60 + float(_floats.find(f) % 3) * 50, y0 - float(fd["t"]) * 50.0)
		_view.draw_string_outline(font, fp, str(fd["txt"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 32, 7, Color.BLACK)
		_view.draw_string(font, fp, str(fd["txt"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 32, fd["col"])


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = 300 + int(st["hp"]) * 3 + maxi(0, 60 - int(st["moves"])) * 10
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "moves": int(st["moves"]), "time": snappedf(time_in_level, 0.1)})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins_total, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


## Estrellas por la vida que le queda al equipo.
func stars_earned() -> int:
	var f: float = float(st["hp"]) / float(st["max_hp"])
	return 3 if f >= 0.6 else (2 if f >= 0.3 else 1)


func _lose() -> void:
	if failed:
		return
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "gemrpg", "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("gr_lost", "\u00a1Tu equipo cayo!"),
		Kit.text("gr_hint", "Ataca con el color que gana al del monstruo (fuego > naturaleza > agua > fuego) y guarda corazones para cuando haga falta."))
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
		"moves": int(st.get("moves", 0)), "hp": int(st.get("hp", 0))}
