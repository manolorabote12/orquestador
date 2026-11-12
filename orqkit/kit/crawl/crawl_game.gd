extends Node2D
## Roguelike por turnos: toca una casilla y el heroe va andando (para si aparece un monstruo); toca
## un monstruo al lado para atacarle y a tu heroe para esperar un turno. Boton de pocion.
## Niebla: lo no visto, negro; lo visto que no ves ahora, oscuro. Reglas, bot y analizador en crawl_map.gd.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const M = preload("res://kit/crawl/crawl_map.gd")
const WALK: float = 0.13
const MON_COL: Dictionary = {"r": "#9e9e9e", "g": "#66bb6a", "o": "#8d6e63", "s": "#eceff1", "B": "#c62828"}

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
var _potion_btn: Button
var _hero_tex: Texture2D = null
## Dibujos de los monstruos por letra del mapa (recortados a lo que ocupa el dibujo).
var _mon_tex: Dictionary = {}
var _path: Array = []
var _walk_t: float = 0.0
var _cam: Vector2 = Vector2.ZERO
var _floats: Array = []
var _log_seen: int = 0
var _t: float = 0.0


var _explore_btn: Button
## Exploracion automatica en marcha.
var exploring: bool = false

func _ready() -> void:
	level = Kit.current_level()
	RenderingServer.set_default_clear_color(Color("#0b0b10"))
	var hero: Dictionary = Kit.sprite_by_role("jugador")
	if not hero.is_empty():
		var sf: SpriteFrames = SpriteKit.frames_de(hero)
		for anim: String in sf.get_animation_names():
			if sf.get_frame_count(anim) > 0:
				_hero_tex = _recortar(sf.get_frame_texture(anim, 0))
				break
	## Monstruos con el arte del juego (antes eran circulos de color; la critica: «nivel vacio»).
	for letra: String in ["r", "g", "s", "o", "B"]:
		var rol: String = {"r": "walker", "g": "spiky", "s": "flyer", "o": "spiky", "B": "boss"}[letra]
		var e: Dictionary = Kit.sprite_entry(str(Kit.param("art.enemies." + rol, "")))
		if not e.is_empty():
			var sfm: SpriteFrames = SpriteKit.frames_de(e)
			for an: String in sfm.get_animation_names():
				if sfm.get_frame_count(an) > 0:
					_mon_tex[letra] = _recortar(sfm.get_frame_texture(an, 0))
					break
	_build_hud()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "crawl", "monsters": (st["mons"] as Array).size()})


func wants_grade() -> bool:
	return false


## Vista desde arriba: el fondo ilustrado (de perfil) no pega detras del tablero y distraia.
func wants_backdrop() -> bool:
	return false


## El frame trae margen transparente alrededor: se recorta a lo que ocupa el dibujo para que el
## personaje llene su casilla (12 nov: el heroe media 15 px en el movil, critica 5/10).
func _recortar(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	var img: Image = tex.get_image()
	if img == null or img.is_empty():
		return tex
	if img.is_compressed():
		img.decompress()
	var used: Rect2i = img.get_used_rect()
	if used.size.x < 2 or used.size.y < 2:
		return tex
	return ImageTexture.create_from_image(img.get_region(used))


func bot_script() -> String:
	return "res://qa/crawl_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(1.2, 2.2)


func _reset() -> void:
	finished = false
	failed = false
	st = M.new_state(level)
	coins_total = (st["items"] as Dictionary).size()
	coins = 0
	time_in_level = 0.0
	_path = []
	_floats = []
	_log_seen = 0
	_cam = Vector2(st["p"])
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
	_info.add_theme_font_size_override("font_size", 28)
	_info.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_info.add_theme_constant_override("outline_size", 6)
	top.add_child(_info)
	_potion_btn = UI.make_button("1", false, "heart")
	_potion_btn.name = "BtnPotion"
	_potion_btn.pressed.connect(drink)
	top.add_child(_potion_btn)
	## Explorar solo: anda hasta lo que falta por ver o el objeto mas cercano y para si ve peligro.
	_explore_btn = UI.make_button(Kit.text("rl_explore", "Explorar"), false, "")
	_explore_btn.name = "BtnExplore"
	_explore_btn.pressed.connect(explore)
	top.add_child(_explore_btn)
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
	_info.text = "\u2665 %d/%d   \u2694 %d   \u25c6 %d   $%d" % [int(st["hp"]), int(st["max_hp"]), int(st["atk"]), int(st["def"]), int(st["gold"])]
	_potion_btn.text = "     " + str(int(st["potions"]))
	_potion_btn.disabled = not can_act() or int(st["potions"]) <= 0
	if _explore_btn != null:
		_explore_btn.disabled = not can_act()
		_explore_btn.theme_type_variation = "PrimaryButton" if exploring else ""
	coins = coins_total - (st["items"] as Dictionary).size()
	_view.queue_redraw()


func can_act() -> bool:
	return not finished and not failed and is_inside_tree() and not get_tree().paused and not bool(st["won"]) and not bool(st["lost"])


func _cs() -> float:
	## Casillas mas grandes (7,5 de ancho): heroe y monstruos se leen en el movil (12 nov).
	return minf(_view.size.x / 7.5, 110.0)


## Casilla bajo un punto de la vista (la camara centra al heroe).
func _cell_at(p: Vector2) -> Vector2i:
	var cs: float = _cs()
	var o: Vector2 = _view.size * 0.5 - (_cam + Vector2(0.5, 0.5)) * cs
	var q: Vector2 = (p - o) / cs
	return Vector2i(floori(q.x), floori(q.y))


# ------------------------------------------------------------------ acciones

func act(a: Variant) -> void:
	if not can_act():
		return
	var hp0: int = int(st["hp"])
	if a is String:
		M.drink(st)
	elif a == Vector2i.ZERO:
		M.rest(st)
	elif not M.step(st, a):
		_path = []
		return
	_collect_log()
	if int(st["hp"]) < hp0:
		_path = []
		exploring = false
	_refresh()
	if bool(st["won"]):
		_finish()
	elif bool(st["lost"]):
		_lose()


func drink() -> void:
	if can_act() and int(st["potions"]) > 0:
		_sfx("powerup", -8.0)
		act("drink")


func _collect_log() -> void:
	var lg: Array = st["log"]
	while _log_seen < lg.size():
		var e: Dictionary = lg[_log_seen]
		_log_seen += 1
		match str(e["k"]):
			"hit":
				_floats.append({"at": e["at"], "txt": "-%d" % int(e["n"]), "col": Color("#ffd166"), "t": 0.0})
				_sfx("coin", -10.0)
			"hurt":
				_floats.append({"at": e["at"], "txt": "-%d" % int(e["n"]), "col": Color("#ff5252"), "t": 0.0})
				_sfx("hurt", -10.0)
			"item":
				_floats.append({"at": e["at"], "txt": {"!": "+1 \u2665", "/": "+2 \u2694", "]": "+1 \u25c6", "$": "+10 $"}.get(str(e.get("i", "")), "+"),
					"col": Color("#80ed99"), "t": 0.0})
				_sfx("powerup", -10.0)
			"level":
				_floats.append({"at": e["at"], "txt": Kit.text("rl_level", "\u00a1Nivel {n}!").format({"n": int(e["n"]) + 1}), "col": Color("#4cc9f0"), "t": 0.0})


func tap_cell(c: Vector2i) -> void:
	if not can_act():
		return
	exploring = false
	var p: Vector2i = st["p"]
	if c == p:
		_path = []
		act(Vector2i.ZERO)
		return
	if absi(c.x - p.x) + absi(c.y - p.y) == 1 and not M.mon_at(st, c).is_empty():
		_path = []
		act(c - p)
		return
	if not (st["seen"] as Dictionary).has(c):
		return
	_path = M.path_to(st, c, true)
	_walk_t = 0.0


## Boton Explorar: encadena caminos hasta que no queda nada, hay peligro o te hacen dano.
func explore() -> void:
	if not can_act():
		return
	if exploring:
		exploring = false
		_path = []
		_refresh()
		return
	if M.danger(st):
		_floats.append({"at": st["p"], "txt": Kit.text("rl_danger", "\u00a1Monstruo a la vista!"), "col": Color("#ff5252"), "t": 0.0})
		return
	_path = M.explore_path(st)
	if _path.is_empty():
		_floats.append({"at": st["p"], "txt": Kit.text("rl_explored", "Ya no queda nada por explorar"), "col": Color("#4cc9f0"), "t": 0.0})
		return
	exploring = true
	_walk_t = 0.0
	_refresh()


func bot_step() -> void:
	if can_act():
		act(M.bot_action(st))


func _on_input(event: InputEvent) -> void:
	var p: Vector2 = Vector2.INF
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		p = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and not DisplayServer.is_touchscreen_available():
		p = (event as InputEventMouseButton).position
	if p != Vector2.INF:
		tap_cell(_cell_at(p))


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
	if not finished and not failed:
		time_in_level += delta
		if fast and auto_retry:
			bot_step()
		elif not _path.is_empty():
			_walk_t -= delta
			if _walk_t <= 0.0:
				_walk_t = WALK
				var nxt: Vector2i = _path.pop_front()
				## Para si hay un monstruo despierto a la vista.
				var danger: bool = false
				for m: Variant in st["mons"]:
					if int(m["hp"]) > 0 and bool(m["awake"]) and M.visible(st, m["p"]):
						danger = true
				act(nxt - Vector2i(st["p"]))
				if danger:
					_path = []
					if exploring:
						exploring = false
						_floats.append({"at": st["p"], "txt": Kit.text("rl_danger", "\u00a1Monstruo a la vista!"), "col": Color("#ff5252"), "t": 0.0})
						_refresh()
		elif exploring:
			## Siguiente tramo de la exploracion (o se acaba).
			_path = M.explore_path(st)
			if _path.is_empty():
				exploring = false
				_refresh()
	_cam = _cam.lerp(Vector2(st["p"]), minf(1.0, delta * 10.0))
	for f: Variant in _floats:
		(f as Dictionary)["t"] = float((f as Dictionary)["t"]) + delta
	_floats = _floats.filter(func(f: Dictionary) -> bool: return float(f["t"]) < 0.9)
	_view.queue_redraw()


# ------------------------------------------------------------------ dibujo

func _draw_view() -> void:
	if st.is_empty():
		return
	var cs: float = _cs()
	var o: Vector2 = _view.size * 0.5 - (_cam + Vector2(0.5, 0.5)) * cs
	var seen: Dictionary = st["seen"]
	var floor_c: Color = Kit.color("ground", Color("#5d4e3a")).darkened(0.12)
	var wall_c: Color = Color("#3b3b4f")
	var x0: int = maxi(0, floori(-o.x / cs) - 1)
	var y0: int = maxi(0, floori(-o.y / cs) - 1)
	var x1: int = mini(int(st["w"]), ceili((_view.size.x - o.x) / cs) + 1)
	var y1: int = mini(int(st["h"]), ceili((_view.size.y - o.y) / cs) + 1)
	for y: int in range(y0, y1):
		for x: int in range(x0, x1):
			var q: Vector2i = Vector2i(x, y)
			if not seen.has(q):
				continue
			var r: Rect2 = Rect2(o + Vector2(x, y) * cs, Vector2(cs, cs))
			var vis: bool = M.visible(st, q)
			if M.wall(st, q):
				_view.draw_rect(r, wall_c)
				_view.draw_rect(Rect2(r.position, Vector2(cs, cs * 0.18)), wall_c.lightened(0.25))
			else:
				_view.draw_rect(r.grow(-1.0), floor_c if (x + y) % 2 == 0 else floor_c.darkened(0.06))
				if q == st["stairs"]:
					for k: int in 4:
						_view.draw_rect(Rect2(r.position + Vector2(cs * 0.15, cs * (0.2 + 0.17 * float(k))), Vector2(cs * (0.7 - 0.12 * float(k)), cs * 0.12)), Color("#cfd8dc"))
				var it: String = str((st["items"] as Dictionary).get(q, ""))
				if it != "":
					_item(r.get_center(), it, cs)
			if not vis:
				_view.draw_rect(r, Color(0, 0, 0, 0.6))
			else:
				## Luz de antorcha: mas oscuro cuanto mas lejos del heroe.
				var dd: float = Vector2(q).distance_to(Vector2(st["p"])) / float(maxi(1, int(st["sight"])))
				_view.draw_rect(r, Color(0, 0, 0, clampf(dd * 0.4, 0.0, 0.4)))
	## Camino que va a seguir.
	for q2: Variant in _path:
		_view.draw_circle(o + (Vector2(q2) + Vector2(0.5, 0.5)) * cs, cs * 0.08, Color(1, 1, 1, 0.5))
	## Monstruos (solo los que se ven ahora).
	for m: Variant in st["mons"]:
		if int(m["hp"]) <= 0 or not M.visible(st, m["p"]):
			continue
		var c: Vector2 = o + (Vector2(m["p"]) + Vector2(0.5, 0.5)) * cs
		var big: float = 1.3 if str(m["k"]) == "B" else 1.0
		var col: Color = Color(str(MON_COL.get(str(m["k"]), "#aaaaaa")))
		_view.draw_circle(c + Vector2(0, cs * 0.3), cs * 0.3 * big, Color(0, 0, 0, 0.35))
		var mt: Texture2D = _mon_tex.get(str(m["k"]), null)
		if mt != null:
			_draw_fit(mt, c, cs * 0.9 * big, sin(_t * 4.0 + float(Vector2(m["p"]).x)) * cs * 0.03)
		else:
			_view.draw_circle(c, cs * 0.34 * big, col)
			_view.draw_circle(c + Vector2(-cs * 0.11, -cs * 0.06) * big, cs * 0.06 * big, Color.BLACK if str(m["k"]) != "B" else Color("#ffd54f"))
			_view.draw_circle(c + Vector2(cs * 0.11, -cs * 0.06) * big, cs * 0.06 * big, Color.BLACK if str(m["k"]) != "B" else Color("#ffd54f"))
		if not bool(m["awake"]):
			_view.draw_string(_view.get_theme_font("font", "Label"), c + Vector2(cs * 0.2, -cs * 0.25), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.8))
		if int(m["hp"]) < int(m["max"]):
			var bw: float = cs * 0.7
			_view.draw_rect(Rect2(c + Vector2(-bw * 0.5, cs * 0.4), Vector2(bw, 6)), Color(0, 0, 0, 0.6))
			_view.draw_rect(Rect2(c + Vector2(-bw * 0.5, cs * 0.4), Vector2(bw * float(m["hp"]) / float(m["max"]), 6)), Color("#ef5350"))
	## Heroe.
	var hc: Vector2 = o + (Vector2(st["p"]) + Vector2(0.5, 0.5)) * cs
	if _hero_tex != null:
		_view.draw_circle(hc + Vector2(0, cs * 0.32), cs * 0.3, Color(0, 0, 0, 0.35))
		_draw_fit(_hero_tex, hc, cs * 0.96, absf(sin(_t * 3.0)) * -cs * 0.03)
	else:
		_view.draw_circle(hc, cs * 0.36, Color("#4cc9f0"))
	## Numeros.
	var font: Font = _view.get_theme_font("font", "Label")
	for f: Variant in _floats:
		var fd: Dictionary = f
		var fp: Vector2 = o + (Vector2(fd["at"]) + Vector2(0.1, 0.2)) * cs - Vector2(0, float(fd["t"]) * 40.0)
		_view.draw_string_outline(font, fp, str(fd["txt"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, 6, Color.BLACK)
		_view.draw_string(font, fp, str(fd["txt"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, fd["col"])


## Dibujo centrado en la casilla, que ocupa como mucho «lado» (y un poco de vaiven).
func _draw_fit(tex: Texture2D, c: Vector2, lado: float, dy: float) -> void:
	var ts: Vector2 = tex.get_size()
	var k: float = lado / maxf(ts.x, ts.y)
	_view.draw_texture_rect(tex, Rect2(c - ts * k * 0.5 + Vector2(0, dy), ts * k), false)


func _item(c: Vector2, it: String, cs: float) -> void:
	match it:
		"!":
			_view.draw_circle(c + Vector2(0, cs * 0.08), cs * 0.2, Color("#ef476f"))
			_view.draw_rect(Rect2(c + Vector2(-cs * 0.06, -cs * 0.24), Vector2(cs * 0.12, cs * 0.16)), Color("#cfd8dc"))
		"/":
			_view.draw_line(c + Vector2(-cs * 0.25, cs * 0.25), c + Vector2(cs * 0.25, -cs * 0.25), Color("#cfd8dc"), cs * 0.08)
			_view.draw_line(c + Vector2(-cs * 0.2, cs * 0.05), c + Vector2(-cs * 0.05, cs * 0.2), Color("#8d6e63"), cs * 0.08)
		"]":
			_view.draw_colored_polygon(PackedVector2Array([c + Vector2(-cs * 0.22, -cs * 0.22), c + Vector2(cs * 0.22, -cs * 0.22), c + Vector2(cs * 0.22, cs * 0.05),
				c + Vector2(0, cs * 0.26), c + Vector2(-cs * 0.22, cs * 0.05)]), Color("#90a4ae"))
		"$":
			_view.draw_circle(c, cs * 0.17, Color("#ffd54f"))
			_view.draw_circle(c, cs * 0.1, Color("#ffb300"))


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = 300 + int(st["gold"]) * 5 + int(st["xp"]) * 20 + int(st["hp"]) * 10
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "coins": coins, "turns": int(st["turn"]), "time": snappedf(time_in_level, 0.1)})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


## Estrellas: con todos los objetos y media vida o mas, 3; con media vida, 2; si no, 1.
func stars_earned() -> int:
	var half: bool = int(st["hp"]) * 2 >= int(st["max_hp"])
	if half and (st["items"] as Dictionary).is_empty():
		return 3
	return 2 if half else 1


func _lose() -> void:
	if failed:
		return
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "crawl", "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("rl_lost", "\u00a1Has caido!"),
		Kit.text("rl_hint", "Pelea en los pasillos (de uno en uno), recoge espadas y armaduras y bebe la pocion antes de que sea tarde."))
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
		"turn": int(st.get("turn", 0)), "hp": int(st.get("hp", 0))}
