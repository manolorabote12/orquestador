extends Node2D
## Sigilo por turnos (tipo Hitman GO): toca un punto vecino para ir alli. Los guardias vigilan el
## punto que tienen delante (en rojo): no te quedes ahi. Llegales por detras o por un lado y
## quedan fuera. Llega a la salida; el maletin y pocos movimientos dan estrellas. Deshacer y
## reiniciar siempre a mano. Reglas, resolutor y analizador en stealth_map.gd.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const M = preload("res://kit/stealth/stealth_map.gd")

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
var _hero_tex: Texture2D = null
var _foe_tex: Texture2D = null
var _history: Array = []
var _vis: Dictionary = {}
var _fx: Array = []
var _log_seen: int = 0
var _t: float = 0.0
var _bot_path: Array = []
var _bot_wait: float = 0.0


var _hint_btn: Button

func _ready() -> void:
	level = Kit.current_level()
	RenderingServer.set_default_clear_color(Color("#1e2a32"))
	_hero_tex = _tex_of(Kit.sprite_by_role("jugador"))
	_foe_tex = _tex_of(Kit.sprite_by_role("enemigo"))
	_build_hud()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "stealth", "guards": (st["guards"] as Array).size()})


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
	return "res://qa/stealth_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(1.4, 1.2)


func _reset() -> void:
	finished = false
	failed = false
	st = M.new_state(level)
	coins_total = 1 if (st["item"] as Vector2i).x >= 0 else 0
	coins = 0
	time_in_level = 0.0
	_history = []
	_fx = []
	_log_seen = 0
	_bot_path = []
	Hint.reset(self)
	_snap()
	_refresh()


func _snap() -> void:
	_vis = {"p": Vector2(st["p"])}
	for i: int in (st["guards"] as Array).size():
		_vis[i] = Vector2(st["guards"][i]["p"])


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
	var bu: Button = UI.make_button(Kit.text("st_undo", "Deshacer"), false, "back")
	bu.name = "BtnUndo"
	bu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bu.pressed.connect(undo)
	bottom.add_child(bu)
	var br: Button = UI.make_button(Kit.text("st_restart", "Reiniciar"), false, "retry")
	br.name = "BtnRestart"
	br.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	br.pressed.connect(retry)
	bottom.add_child(br)
	_hint_btn = Hint.make_button(self, use_hint)
	bottom.add_child(_hint_btn)


func _refresh() -> void:
	if st.is_empty() or _info == null:
		return
	var brief: String = ("   \u2714 " + Kit.text("st_case", "Malet\u00edn")) if bool(st["has_item"]) else ""
	_info.text = Kit.text("st_moves", "Movimientos: {n}/{par}").format({"n": int(st["moves"]), "par": int(st["par"])}) + brief
	if _hint_btn != null:
		_hint_btn.text = Hint.label(self)
		_hint_btn.disabled = finished


func can_act() -> bool:
	return not finished and not failed and is_inside_tree() and not get_tree().paused and not bool(st["won"]) and not bool(st["lost"])


func _cs() -> float:
	return minf((_view.size.x - 80.0) / float(maxi(1, int(st["w"]) - 1)), (_view.size.y - 420.0) / float(maxi(1, int(st["h"]) - 1)))


func _o() -> Vector2:
	var cs: float = _cs()
	var bw: Vector2 = Vector2(float(int(st["w"]) - 1), float(int(st["h"]) - 1)) * cs
	return Vector2((_view.size.x - bw.x) * 0.5, 150.0 + (_view.size.y - 400.0 - bw.y) * 0.5)


func _np(p: Vector2) -> Vector2:
	return _o() + p * _cs()


func go(q: Vector2i) -> bool:
	if not can_act() or not M.linked(st, st["p"], q):
		return false
	_history.append({"st": M._copy(st), "has": st["has_item"]})
	M.move(st, q)
	_sfx("click", -8.0)
	_collect_log()
	_refresh()
	if bool(st["won"]):
		_finish()
	elif bool(st["lost"]):
		_lose()
	return true


## Pista: el siguiente paso del camino mas corto (con el maletin si aun no lo llevas).
func use_hint() -> void:
	if not can_act():
		return
	var path: Array = M.solve(st, (st["item"] as Vector2i).x >= 0 and not bool(st["has_item"]))
	if path.is_empty():
		path = M.solve(st, false)
	if path.is_empty():
		Hint.say(self, Kit.text("hint_none", "Desde aqu\u00ed no hay salida: deshaz o reinicia"))
		return
	if not await Hint.pay(self):
		Hint.say(self, Kit.text("hint_no_coins", "Te faltan monedas para la pista"))
		return
	if is_inside_tree() and can_act():
		go(path[0])
	_refresh()


func undo() -> void:
	if _history.is_empty() or finished:
		return
	var h: Dictionary = _history.pop_back()
	st = h["st"]
	failed = false
	_snap()
	_refresh()


func _on_input(event: InputEvent) -> void:
	if auto_retry or st.is_empty():
		return
	var pos: Vector2 = Vector2.INF
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		pos = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and not DisplayServer.is_touchscreen_available():
		pos = (event as InputEventMouseButton).position
	if pos == Vector2.INF:
		return
	var best: Vector2i = Vector2i(-1, -1)
	var bd: float = _cs() * 0.55
	for n: Variant in M.neighbors(st, st["p"]):
		var d: float = _np(Vector2(n)).distance_to(pos)
		if d < bd:
			bd = d
			best = n
	if best.x >= 0:
		go(best)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()


func _sfx(nm: String, vol: float = -6.0) -> void:
	if not fast:
		Audio.play(nm, 0.1, vol)


func _collect_log() -> void:
	var lg: Array = st["log"]
	while _log_seen < lg.size():
		var e: Dictionary = lg[_log_seen]
		_log_seen += 1
		match str(e["k"]):
			"kill":
				_fx.append({"at": e["at"], "t": 0.0, "k": "kill"})
				_sfx("stomp", -4.0)
			"item":
				coins = 1
				_fx.append({"at": e["at"], "t": 0.0, "k": "item"})
				_sfx("powerup", -4.0)
			"caught":
				_fx.append({"at": e["at"], "t": 0.0, "k": "caught"})


func _physics_process(delta: float) -> void:
	if st.is_empty() or get_tree().paused:
		return
	_t += delta
	if not finished and not failed:
		time_in_level += delta
		if auto_retry:
			_bot_wait -= delta * (20.0 if fast else 1.0)
			if _bot_wait <= 0.0:
				_bot_wait = 0.45
				bot_step()
	var sp: float = minf(1.0, delta * 12.0)
	_vis["p"] = (_vis["p"] as Vector2).lerp(Vector2(st["p"]), sp)
	for i: int in (st["guards"] as Array).size():
		_vis[i] = (_vis.get(i, Vector2(st["guards"][i]["p"])) as Vector2).lerp(Vector2(st["guards"][i]["p"]), sp)
	for f: Variant in _fx:
		(f as Dictionary)["t"] = float((f as Dictionary)["t"]) + delta
	_fx = _fx.filter(func(f: Dictionary) -> bool: return float(f["t"]) < 0.8)
	_view.queue_redraw()


func bot_step() -> void:
	if not can_act():
		return
	if _bot_path.is_empty():
		_bot_path = M.solve(st, (st["item"] as Vector2i).x >= 0 and not bool(st["has_item"]))
		if _bot_path.is_empty():
			_bot_path = M.solve(st, false)
	if not _bot_path.is_empty():
		go(_bot_path.pop_front())


# ------------------------------------------------------------------ dibujo

func _draw_view() -> void:
	if st.is_empty():
		return
	var cs: float = _cs()
	var sz: Vector2 = _view.size
	var floor_c: Color = Kit.color("ground", Color("#577590"))
	_view.draw_rect(Rect2(Vector2.ZERO, sz), Color("#1e2a32"))
	## Mesa del tablero.
	var bw: Vector2 = Vector2(float(int(st["w"]) - 1), float(int(st["h"]) - 1)) * cs
	var board: Rect2 = Rect2(_o() - Vector2(cs * 0.6, cs * 0.6), bw + Vector2(cs * 1.2, cs * 1.2))
	_view.draw_rect(Rect2(board.position + Vector2(0, 12), board.size), Color(0, 0, 0, 0.35))
	_view.draw_rect(board, floor_c.darkened(0.25))
	_view.draw_rect(board, floor_c.lightened(0.1), false, 4.0)
	## Caminos.
	for e: Variant in st["edges"]:
		var a: Vector2i = e[0]
		var b: Vector2i = e[1]
		if a.x > b.x or a.y > b.y:
			continue
		_view.draw_line(_np(Vector2(a)), _np(Vector2(b)), Color("#e9ecef"), cs * 0.1)
	## Puntos vigilados (rojo) y donde puedes ir (verde).
	var watched: Dictionary = {}
	for g: Variant in st["guards"]:
		if bool(g["alive"]):
			var w2: Vector2i = M.watch(st, g)
			if w2.x != -99:
				watched[w2] = true
	var nexts: Array = M.neighbors(st, st["p"]) if can_act() else []
	for n: Variant in st["nodes"]:
		var c: Vector2 = _np(Vector2(n))
		_view.draw_circle(c + Vector2(0, 4), cs * 0.17, Color(0, 0, 0, 0.35))
		var col: Color = Color("#f8f9fa")
		if watched.has(n):
			col = Color("#ff6b6b")
		_view.draw_circle(c, cs * 0.16, col)
		if nexts.has(n):
			_view.draw_arc(c, cs * 0.24 + 2.0 * sin(_t * 6.0), 0.0, TAU, 24, Color("#80ed99") if not watched.has(n) else Color("#ffb4a2"), 4.0)
	## Salida y maletin.
	var ex: Vector2 = _np(Vector2(st["exit"]))
	_view.draw_rect(Rect2(ex - Vector2(cs * 0.22, cs * 0.3), Vector2(cs * 0.44, cs * 0.52)), Color("#06d6a0"))
	_view.draw_rect(Rect2(ex - Vector2(cs * 0.16, cs * 0.24), Vector2(cs * 0.32, cs * 0.42)), Color("#1b4332"))
	if (st["item"] as Vector2i).x >= 0 and not bool(st["has_item"]):
		var ic: Vector2 = _np(Vector2(st["item"])) + Vector2(0, -cs * 0.05 + sin(_t * 3.0) * 4.0)
		_view.draw_rect(Rect2(ic - Vector2(cs * 0.18, cs * 0.1), Vector2(cs * 0.36, cs * 0.24)), Color("#8d5524"))
		_view.draw_rect(Rect2(ic - Vector2(cs * 0.07, cs * 0.17), Vector2(cs * 0.14, cs * 0.08)), Color("#8d5524"), false, 3.0)
	## Guardias con su mirada.
	for i: int in (st["guards"] as Array).size():
		var g2: Dictionary = st["guards"][i]
		if not bool(g2["alive"]):
			continue
		var gc: Vector2 = _np(_vis[i])
		var dir: Vector2 = Vector2(M.DIRS[str(g2["d"])])
		var side: Vector2 = Vector2(-dir.y, dir.x)
		_view.draw_colored_polygon(PackedVector2Array([gc + dir * cs * 0.2 + side * cs * 0.08, gc + dir * cs * 0.85 + side * cs * 0.3,
			gc + dir * cs * 0.85 - side * cs * 0.3, gc + dir * cs * 0.2 - side * cs * 0.08]), Color(1, 0.3, 0.3, 0.28))
		_token(gc, _foe_tex, Color("#e63946"), cs, dir.x < 0.0)
		var mark: Vector2 = gc + Vector2(cs * 0.22, -cs * 0.3)
		match str(g2["kind"]):
			"patrol":
				_view.draw_line(mark - dir * 8.0, mark + dir * 8.0, Color.WHITE, 4.0)
				_view.draw_circle(mark + dir * 8.0, 5.0, Color.WHITE)
			"rotate":
				_view.draw_arc(mark, 9.0, 0.3, TAU - 0.6, 12, Color.WHITE, 3.0)
	## Heroe.
	_token(_np(_vis["p"]), _hero_tex, Color("#4cc9f0"), cs, false)
	for f: Variant in _fx:
		var fd: Dictionary = f
		var fc: Vector2 = _np(Vector2(fd["at"]))
		var tt: float = float(fd["t"]) / 0.8
		var fcol: Color = Color("#ffd166") if str(fd["k"]) == "item" else (Color("#ff6b6b") if str(fd["k"]) == "caught" else Color.WHITE)
		for s: int in 8:
			var an: float = TAU * float(s) / 8.0
			_view.draw_circle(fc + Vector2(cos(an), sin(an)) * cs * (0.2 + 0.6 * tt), 6.0 * (1.0 - tt), fcol)


func _token(c: Vector2, tex: Texture2D, col: Color, cs: float, flip: bool) -> void:
	_view.draw_circle(c + Vector2(0, cs * 0.05), cs * 0.27, Color(0, 0, 0, 0.35))
	_view.draw_circle(c, cs * 0.25, col)
	if tex != null:
		var ts: Vector2 = tex.get_size()
		var k: float = cs * 0.62 / maxf(ts.x, ts.y)
		var r: Rect2 = Rect2(c - ts * k * 0.5 - Vector2(0, cs * 0.12), ts * k)
		if flip:
			_view.draw_set_transform(Vector2(c.x * 2.0, 0), 0.0, Vector2(-1, 1))
		_view.draw_texture_rect(tex, r, false)
		_view.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = 1000 + (500 if bool(st["has_item"]) else 0) + maxi(0, int(st["par"]) - int(st["moves"])) * 100 + int(st["kills"]) * 50
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "coins": coins, "moves": int(st["moves"]), "time": snappedf(time_in_level, 0.1)})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


## Estrellas: llegar (1), con el maletin (+1) y en los movimientos del objetivo (+1).
func stars_earned() -> int:
	var s: int = 1
	if bool(st["has_item"]) or (st["item"] as Vector2i).x < 0:
		s += 1
	if int(st["moves"]) <= int(st["par"]):
		s += 1
	return s


func _lose() -> void:
	if failed:
		return
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "stealth", "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("st_caught", "\u00a1Te han visto!"),
		Kit.text("st_hint", "Los puntos rojos los vigila un guardia: no acabes ah\u00ed. Ac\u00e9rcate por detr\u00e1s o por un lado para dejarlo fuera. Puedes deshacer."))
	p.closed.connect(undo)


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
	return {"deaths": deaths, "coins": coins, "finished": finished, "failed": failed, "stomps": int(st.get("kills", 0)), "time": time_in_level,
		"moves": int(st.get("moves", 0))}
