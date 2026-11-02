extends Node2D
## Artilleria por turnos (tipo Worms): en tu turno mueve al soldado con las flechas y apunta
## arrastrando hacia atras (como un tirachinas): la direccion y la fuerza salen del arrastre y al
## soltar dispara. Mira el viento arriba. Luego dispara el rival. Reglas, IA, bot y analizador en
## artillery_map.gd.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const M = preload("res://kit/artillery/artillery_map.gd")
const PULL: float = 320.0

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
var _aim_lbl: Label
var _btn_l: Button
var _btn_r: Button
var _hero_tex: Texture2D = null
var _foe_tex: Texture2D = null
## Lo que se ve (estado de antes del disparo hasta que acaba la animacion).
var _shown: Dictionary = {}
var _anim: Dictionary = {}
var _fx: Array = []
var _log_seen: int = 0
var _t: float = 0.0
var _wait: float = 0.0
var _drag_from: Vector2 = Vector2.INF
var _drag_to: Vector2 = Vector2.ZERO
var aim_angle: float = 45.0
var aim_power: float = 0.0
var _shake: float = 0.0


func _ready() -> void:
	level = Kit.current_level()
	RenderingServer.set_default_clear_color(Color("#87c5e8"))
	_hero_tex = _tex_of(Kit.sprite_by_role("jugador"))
	_foe_tex = _tex_of(Kit.sprite_by_role("enemigo"))
	_build_hud()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "artillery", "foes": M.alive(st, 2).size()})


func _tex_of(d: Dictionary) -> Texture2D:
	if d.is_empty():
		return null
	var sf: SpriteFrames = SpriteKit.frames_de(d)
	for anim: String in sf.get_animation_names():
		if sf.get_frame_count(anim) > 0:
			return sf.get_frame_texture(anim, 0)
	return null


func wants_grade() -> bool:
	return false


func bot_script() -> String:
	return "res://qa/artillery_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(2.4, 1.6)


func _reset() -> void:
	finished = false
	failed = false
	st = M.new_state(level)
	_shown = st.duplicate(true)
	_anim = {}
	_fx = []
	_log_seen = 0
	_wait = 0.6
	time_in_level = 0.0
	aim_power = 0.0
	_drag_from = Vector2.INF
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
	_view = Control.new()
	_view.name = "View"
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.draw.connect(_draw_view)
	_view.gui_input.connect(_on_input)
	root.add_child(_view)
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
	_info.add_theme_font_size_override("font_size", 28)
	_info.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_info.add_theme_constant_override("outline_size", 6)
	top.add_child(_info)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)
	var gap: Control = Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(gap)
	var bottom: HBoxContainer = HBoxContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_theme_constant_override("separation", 16)
	col.add_child(bottom)
	_btn_l = UI.make_button("\u25c0", false)
	_btn_l.name = "BtnLeft"
	_btn_l.pressed.connect(walk.bind(-1))
	bottom.add_child(_btn_l)
	_aim_lbl = Label.new()
	_aim_lbl.name = "Aim"
	_aim_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_aim_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aim_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_aim_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_aim_lbl.add_theme_constant_override("outline_size", 6)
	bottom.add_child(_aim_lbl)
	_btn_r = UI.make_button("\u25b6", false)
	_btn_r.name = "BtnRight"
	_btn_r.pressed.connect(walk.bind(1))
	bottom.add_child(_btn_r)


func my_turn() -> bool:
	return can_act() and int(st["side"]) == 1 and _anim.is_empty() and _wait <= 0.0


func can_act() -> bool:
	return not finished and not failed and is_inside_tree() and not get_tree().paused and not bool(st["won"]) and not bool(st["lost"])


func _refresh() -> void:
	if st.is_empty() or _info == null:
		return
	var w: float = float(st["wind"])
	var arrow: String = ("\u25b6" if w > 0.0 else "\u25c0").repeat(clampi(int(round(absf(w) / 4.0)) + 1, 1, 4)) if absf(w) >= 0.5 else "-"
	_info.text = Kit.text("atl_wind", "Viento") + " " + arrow + "   " + (Kit.text("atl_you", "Tu turno") if int(st["side"]) == 1 else Kit.text("atl_ai", "Dispara el rival..."))
	var mine: bool = my_turn()
	_btn_l.disabled = not mine or int(st["walk_left"]) <= 0
	_btn_r.disabled = not mine or int(st["walk_left"]) <= 0
	if mine and aim_power > 0.0:
		_aim_lbl.text = "%d\u00b0  %d%%" % [int(round(aim_angle)), int(round(aim_power * 100.0))]
	elif mine:
		_aim_lbl.text = Kit.text("atl_drag", "Arrastra hacia atr\u00e1s y suelta")
	else:
		_aim_lbl.text = ""


# ------------------------------------------------------------------ geometria

func _cs() -> float:
	return _view.size.x / float(M.W)


func _base_y() -> float:
	return _view.size.y - 210.0


func to_screen(p: Vector2) -> Vector2:
	var cs: float = _cs()
	var shake: Vector2 = Vector2(sin(_t * 61.0), cos(_t * 47.0)) * _shake * 10.0
	return Vector2(p.x * cs, _base_y() - p.y * cs) + shake


# ------------------------------------------------------------------ acciones

func walk(dir: int) -> void:
	if my_turn() and M.walk(st, dir):
		_shown = st.duplicate(true)
		_sfx("click", -12.0)
		_collect_log()
		_check_end()
		_refresh()


func shoot(angle: float, power: float) -> void:
	if not can_act() or not _anim.is_empty():
		return
	var before: Dictionary = st.duplicate(true)
	var side: int = int(st["side"])
	var shot: Dictionary = M.fire(st, angle, power)
	aim_power = 0.0
	if fast:
		_shown = st.duplicate(true)
		_collect_log()
		_check_end()
		return
	_shown = before
	_anim = {"path": shot["path"], "i": 0.0, "side": side, "hit": shot["hit"]}
	_sfx("shoot", -6.0)


func _on_input(event: InputEvent) -> void:
	if not my_turn() or auto_retry:
		return
	var pos: Vector2 = Vector2.INF
	var pressed: int = -1
	if event is InputEventScreenTouch:
		pos = (event as InputEventScreenTouch).position
		pressed = 1 if (event as InputEventScreenTouch).pressed else 0
	elif event is InputEventScreenDrag:
		pos = (event as InputEventScreenDrag).position
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and not DisplayServer.is_touchscreen_available():
		pos = (event as InputEventMouseButton).position
		pressed = 1 if (event as InputEventMouseButton).pressed else 0
	elif event is InputEventMouseMotion and _drag_from != Vector2.INF and not DisplayServer.is_touchscreen_available():
		pos = (event as InputEventMouseMotion).position
	if pos == Vector2.INF:
		return
	if pressed == 1:
		_drag_from = pos
		_drag_to = pos
		aim_power = 0.0
	elif pressed == 0:
		if _drag_from != Vector2.INF:
			_drag_from = Vector2.INF
			if aim_power >= 0.08:
				shoot(aim_angle, aim_power)
			aim_power = 0.0
	elif _drag_from != Vector2.INF:
		_drag_to = pos
		var pull: Vector2 = _drag_from - _drag_to
		aim_power = clampf(pull.length() / PULL, 0.0, 1.0)
		if pull.length() > 8.0:
			aim_angle = rad_to_deg(atan2(-pull.y, pull.x))
	_refresh()


func bot_step() -> void:
	if not can_act() or not _anim.is_empty():
		return
	var b: Dictionary = M.best_shot(st) if int(st["side"]) == 1 else M.ai_shot(st)
	aim_angle = float(b["angle"])
	aim_power = float(b["power"])
	shoot(aim_angle, aim_power)


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
	_shake = maxf(0.0, _shake - delta * 2.5)
	if not finished and not failed:
		time_in_level += delta
		if fast and auto_retry:
			for k: int in 4:
				bot_step()
		elif not _anim.is_empty():
			_anim["i"] = float(_anim["i"]) + delta / 0.05
			if int(_anim["i"]) >= (_anim["path"] as Array).size() - 1:
				_anim = {}
				_shown = st.duplicate(true)
				_collect_log()
				_wait = 1.1
				_check_end()
		else:
			_wait -= delta
			if _wait <= 0.0 and can_act():
				if int(st["side"]) == 2:
					bot_step()
				elif auto_retry:
					bot_step()
	for f: Variant in _fx:
		(f as Dictionary)["t"] = float((f as Dictionary)["t"]) + delta
	_fx = _fx.filter(func(f: Dictionary) -> bool: return float(f["t"]) < float(f.get("life", 1.0)))
	_refresh()
	_view.queue_redraw()


func _collect_log() -> void:
	var lg: Array = st["log"]
	while _log_seen < lg.size():
		var e: Dictionary = lg[_log_seen]
		_log_seen += 1
		match str(e["k"]):
			"boom":
				_fx.append({"k": "boom", "at": e["at"], "t": 0.0, "life": 0.5})
				_shake = 0.8
				_sfx("stomp", -2.0)
				if not fast:
					Juice.vibrate(25)
			"splash":
				_fx.append({"k": "splash", "at": e["at"], "t": 0.0, "life": 0.6})
			"hit":
				_fx.append({"k": "txt", "at": e["at"] + Vector2(0, 8), "txt": "-%d" % int(e["n"]), "col": Color("#ff5252") if int(e["team"]) == 1 else Color("#ffd166"), "t": 0.0, "life": 1.2})
				_sfx("hurt" if int(e["team"]) == 1 else "coin", -8.0)
			"kill", "drown":
				_fx.append({"k": "txt", "at": e["at"] + Vector2(0, 14), "txt": "\u2620", "col": Color.WHITE, "t": 0.0, "life": 1.4})
			"flood":
				_fx.append({"k": "txt", "at": Vector2(float(M.W) * 0.35, float(st["water"]) + 10.0), "txt": Kit.text("atl_flood", "\u00a1Sube el agua!"), "col": Color("#4cc9f0"), "t": 0.0, "life": 1.5})


func _check_end() -> void:
	if bool(st["won"]):
		_finish()
	elif bool(st["lost"]):
		_lose()


# ------------------------------------------------------------------ dibujo

func _draw_view() -> void:
	if _shown.is_empty():
		return
	var cs: float = _cs()
	var sz: Vector2 = _view.size
	## Cielo y colinas lejanas.
	var sky: Color = Kit.color("sky", Color("#87c5e8"))
	_view.draw_rect(Rect2(Vector2.ZERO, sz), sky)
	_view.draw_rect(Rect2(Vector2(0, sz.y * 0.35), Vector2(sz.x, sz.y * 0.65)), sky.lightened(0.15))
	var far: PackedVector2Array = PackedVector2Array([Vector2(0, _base_y())])
	for x: int in 25:
		far.append(Vector2(sz.x * float(x) / 24.0, _base_y() - cs * (70.0 + 18.0 * sin(float(x) * 0.9) + 10.0 * sin(float(x) * 2.3))))
	far.append(Vector2(sz.x, _base_y()))
	_view.draw_colored_polygon(far, sky.darkened(0.12))
	## Terreno.
	var g: Array = _shown["ground"]
	var ground: Color = Kit.color("ground", Color("#7cb342"))
	var dirt: Color = Color("#8d6e63")
	for x: int in M.W:
		var top: Vector2 = to_screen(Vector2(float(x), float(g[x])))
		var bot: Vector2 = to_screen(Vector2(float(x), 0.0))
		var r: Rect2 = Rect2(Vector2(top.x, top.y), Vector2(cs + 0.6, bot.y - top.y))
		_view.draw_rect(r, dirt)
		_view.draw_rect(Rect2(r.position, Vector2(r.size.x, minf(r.size.y, cs * 2.2))), ground)
	## Agua.
	var wy: float = to_screen(Vector2(0, float(_shown["water"]))).y
	var water: Color = Color(0.15, 0.45, 0.8, 0.85)
	var wave: PackedVector2Array = PackedVector2Array()
	for x2: int in 41:
		wave.append(Vector2(sz.x * float(x2) / 40.0, wy + sin(_t * 2.0 + float(x2) * 0.7) * 4.0))
	wave.append(Vector2(sz.x, sz.y))
	wave.append(Vector2(0, sz.y))
	_view.draw_colored_polygon(wave, water)
	## Soldados.
	var font: Font = _view.get_theme_font("font", "Label")
	var act: int = int(_shown["active"])
	for i: int in (_shown["units"] as Array).size():
		var u: Dictionary = _shown["units"][i]
		if not bool(u["alive"]):
			continue
		var base: Vector2 = to_screen(M.unit_pos(_shown, u))
		var tex: Texture2D = _hero_tex if int(u["team"]) == 1 else _foe_tex
		var h: float = cs * 8.5
		if tex != null:
			var ts: Vector2 = tex.get_size()
			var k: float = h / maxf(ts.x, ts.y)
			var flip: bool = int(u["team"]) == 2
			var rr: Rect2 = Rect2(base - Vector2(ts.x * k * 0.5, ts.y * k), ts * k)
			if flip:
				_view.draw_set_transform(Vector2(base.x * 2.0, 0), 0.0, Vector2(-1, 1))
			_view.draw_texture_rect(tex, rr, false)
			if flip:
				_view.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			_view.draw_circle(base - Vector2(0, h * 0.5), h * 0.45, Color("#4cc9f0") if int(u["team"]) == 1 else Color("#ef5350"))
		var col: Color = Color("#4cc9f0") if int(u["team"]) == 1 else Color("#ef5350")
		var bw: float = cs * 7.0
		var by: float = base.y - h - 16.0
		_view.draw_rect(Rect2(Vector2(base.x - bw * 0.5, by), Vector2(bw, 8)), Color(0, 0, 0, 0.6))
		_view.draw_rect(Rect2(Vector2(base.x - bw * 0.5, by), Vector2(bw * float(u["hp"]) / float(u["max"]), 8)), col)
		_view.draw_string_outline(font, Vector2(base.x - 18, by - 6), str(int(u["hp"])), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 5, Color.BLACK)
		_view.draw_string(font, Vector2(base.x - 18, by - 6), str(int(u["hp"])), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, col.lightened(0.4))
		if i == act and _anim.is_empty() and not finished:
			var bob: float = sin(_t * 5.0) * 6.0
			var ay: float = by - 40.0 + bob
			_view.draw_colored_polygon(PackedVector2Array([Vector2(base.x - 12, ay), Vector2(base.x + 12, ay), Vector2(base.x, ay + 16)]), Color.WHITE)
	## Punteria: linea de tiro y guia de la trayectoria (sin viento, solo el principio).
	if my_turn() and aim_power > 0.0:
		var u2: Dictionary = M.active_unit(st)
		var from: Vector2 = M.unit_pos(st, u2)
		var sim: Dictionary = M.simulate(st, from, aim_angle, aim_power, 0.0)
		var pts: Array = sim["path"]
		var n: int = int(float(pts.size()) * float(level.get("guide", 0.4)))
		for k2: int in range(1, mini(n, pts.size())):
			_view.draw_circle(to_screen(pts[k2]), 4.0, Color(1, 1, 1, 0.85 - 0.6 * float(k2) / float(maxi(1, n))))
		var a: float = deg_to_rad(aim_angle)
		var s0: Vector2 = to_screen(from + Vector2(0, 3))
		_view.draw_line(s0, s0 + Vector2(cos(a), -sin(a)) * (40.0 + 90.0 * aim_power), Color("#ffd166"), 6.0)
	## Proyectil.
	if not _anim.is_empty():
		var path: Array = _anim["path"]
		var idx: int = clampi(int(_anim["i"]), 0, path.size() - 1)
		var pp: Vector2 = to_screen(path[idx])
		for t2: int in range(maxi(0, idx - 6), idx):
			_view.draw_circle(to_screen(path[t2]), 3.0 + float(t2 - idx + 6), Color(1, 1, 1, 0.25))
		_view.draw_circle(pp, 9.0, Color("#37474f"))
		_view.draw_circle(pp + Vector2(-2, -2), 3.0, Color("#ffca28"))
	## Efectos.
	for f: Variant in _fx:
		var fd: Dictionary = f
		var at: Vector2 = to_screen(fd["at"])
		var tt: float = float(fd["t"]) / float(fd.get("life", 1.0))
		match str(fd["k"]):
			"boom":
				_view.draw_circle(at, cs * M.BLAST * (0.4 + tt), Color(1.0, 0.6, 0.15, 0.7 * (1.0 - tt)))
				_view.draw_circle(at, cs * M.CRATER * (0.3 + 0.7 * tt), Color(1.0, 0.95, 0.6, 0.9 * (1.0 - tt)))
			"splash":
				for s: int in 5:
					_view.draw_circle(at + Vector2(float(s - 2) * 10.0, -tt * 60.0 * (1.0 - absf(float(s - 2)) * 0.3)), 6.0, Color(0.8, 0.9, 1.0, 1.0 - tt))
			"txt":
				var tp: Vector2 = at - Vector2(16, tt * 50.0)
				_view.draw_string_outline(font, tp, str(fd["txt"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 34, 7, Color.BLACK)
				_view.draw_string(font, tp, str(fd["txt"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 34, fd["col"])


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var hp: int = 0
	for u: Variant in M.alive(st, 1):
		hp += int(u["hp"])
	var score: int = 500 + hp * 5 + maxi(0, 20 - int(st["turn"])) * 40
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "coins": coins, "turns": int(st["turn"]), "time": snappedf(time_in_level, 0.1)})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


## Estrellas: sin bajas, 3; con una baja, 2; si no, 1.
func stars_earned() -> int:
	var lost: int = 0
	for u: Variant in st["units"]:
		if int(u["team"]) == 1 and not bool(u["alive"]):
			lost += 1
	return 3 if lost == 0 else (2 if lost == 1 else 1)


func _lose() -> void:
	if failed:
		return
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "artillery", "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("atl_lost", "\u00a1Derrota!"),
		Kit.text("atl_hint", "Mira el viento antes de tirar, apunta alto para pasar los montes y aprovecha que el rival se acerque al agua."))
	p.closed.connect(retry)


func retry() -> void:
	_reset()


func open_pause() -> void:
	if finished or get_tree().paused or get_node_or_null("PauseMenu") != null:
		return
	_drag_from = Vector2.INF
	aim_power = 0.0
	PauseMenu.open(self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_inside_tree() and not UI.test_mode:
			open_pause()


func bot_state() -> Dictionary:
	return {"deaths": deaths, "coins": coins, "finished": finished, "failed": failed, "stomps": 0, "time": time_in_level,
		"turn": int(st.get("turn", 0))}
