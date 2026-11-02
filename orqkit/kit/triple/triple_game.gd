extends Node2D
## Triple de fichas (estilo Tile Master): toca las fichas libres del monton; van a la bandeja y
## tres iguales desaparecen. Si la bandeja se llena, se pierde; si vacias el monton, ganas.
## Ayudas: DESHACER (la ultima ficha vuelve) y BARAJAR (otros dibujos, siempre con solucion).
## Reglas, reparto, bot y analizador en triple_map.gd (logica pura).
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const M = preload("res://kit/triple/triple_map.gd")
const TW: float = 92.0
const TH: float = 100.0
const AREA: Rect2 = Rect2(20, 180, 680, 760)
const TRAY_Y: float = 1000.0
const SLOT: float = 88.0
const COLS: Array[Color] = [Color("#e53950"), Color("#f5b301"), Color("#ec5fa4"), Color("#1fb6d9"), Color("#43a047"), Color("#8e5cd9"),
	Color("#2f6fd0"), Color("#ff7a1a"), Color("#e0b000"), Color("#c0392b"), Color("#139e8e"), Color("#b8860b")]

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
var helps_used: int = 0

var _world: Node2D
var _camera: Camera2D
var _left_lbl: Label
var _undo_btn: Button
var _shuffle_btn: Button
var _bot: bool = false
var _bot_t: float = 0.0
var _t: float = 0.0
var _k: float = 1.0
var _origin: Vector2 = Vector2.ZERO
## Fichas que vuelan a la bandeja: {"kind", "from": Vector2, "t"} y la bandeja dibujada.
var _fly: Array = []
var _tray_pos: Dictionary = {}
var _pops: Array = []
var _shake: int = -1
var _shake_t: float = 0.0


func _ready() -> void:
	level = Kit.current_level()
	par = float(level.get("par", 0))
	RenderingServer.set_default_clear_color(Kit.color("sky", Color("#2a3f6b")).darkened(0.15))
	_world = Node2D.new()
	_world.name = "World"
	_world.draw.connect(_draw_world)
	add_child(_world)
	_camera = Camera2D.new()
	add_child(_camera)
	_camera.make_current()
	_camera.position = Vector2(360, 640)
	Juice.register_camera(_camera)
	_build_hud()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "triple", "tiles": (st["tiles"] as Array).size()})


func bot_script() -> String:
	return "res://qa/triple_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(4.0, 3.0)


## Fichas claras: sin el brillo del etalonaje.
func wants_grade() -> bool:
	return false


func _reset() -> void:
	finished = false
	failed = false
	var lv: Dictionary = level.duplicate()
	if deaths > 0:
		## Otro reparto al reintentar (mismo monton, otros dibujos).
		var rows: Array = []
		for r: Variant in level.get("map", []):
			if not (str(r).begins_with("#") and str(r).substr(1).is_valid_int()):
				rows.append(r)
		rows.append("#%d" % (int(M.parse(level)["seed"]) + deaths * 131))
		lv["map"] = rows
	st = M.new_state(lv)
	coins_total = (st["tiles"] as Array).size() / 3
	coins = 0
	helps_used = 0
	time_in_level = 0.0
	_fly.clear()
	_tray_pos.clear()
	_pops.clear()
	_layout()
	_refresh()


## Escala y posicion del monton para que quepa en la zona de juego.
func _layout() -> void:
	var w: float = 1.0
	var h: float = 1.0
	for t: Dictionary in st["tiles"]:
		w = maxf(w, float(t["x"]) + 1.0)
		h = maxf(h, float(t["y"]) + 1.0)
	_k = minf(1.1, minf(AREA.size.x / (w * TW + 10.0), AREA.size.y / (h * TH + 10.0)))
	_origin = AREA.get_center() - Vector2(w * TW, h * TH) * _k * 0.5


func tile_rect(t: Dictionary) -> Rect2:
	var p: Vector2 = _origin + Vector2(float(t["x"]) * TW, float(t["y"]) * TH) * _k - Vector2(0, float(t["z"]) * 6.0 * _k)
	return Rect2(p + Vector2(3, 3) * _k, Vector2(TW - 6.0, TH - 6.0) * _k)


func slot_rect(i: int) -> Rect2:
	var n: int = int(st["tray_max"])
	var x0: float = 360.0 - float(n) * SLOT * 0.5
	return Rect2(Vector2(x0 + float(i) * SLOT + 4.0, TRAY_Y + 12.0), Vector2(SLOT - 8.0, SLOT + 4.0))


# ------------------------------------------------------------------ interfaz

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
	var safe: MarginContainer = UI.safe_root(root, 16.0)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col: VBoxContainer = VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(col)
	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 12)
	col.add_child(top)
	var title: Label = Label.new()
	title.text = str(level.get("name", Kit.text("level", "Nivel")))
	title.add_theme_font_size_override("font_size", 34)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	top.add_child(title)
	_left_lbl = Label.new()
	_left_lbl.name = "Left"
	_left_lbl.add_theme_font_size_override("font_size", 30)
	top.add_child(_left_lbl)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)
	var grow: Control = Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(grow)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	col.add_child(row)
	_undo_btn = UI.make_button("", false)
	_undo_btn.name = "BtnUndo"
	_undo_btn.custom_minimum_size = Vector2(250, 96)
	_undo_btn.pressed.connect(use_undo)
	row.add_child(_undo_btn)
	_shuffle_btn = UI.make_button("", false)
	_shuffle_btn.name = "BtnShuffle"
	_shuffle_btn.custom_minimum_size = Vector2(250, 96)
	_shuffle_btn.pressed.connect(use_shuffle)
	row.add_child(_shuffle_btn)


func _refresh() -> void:
	var left: int = M.on_board(st).size()
	_left_lbl.text = Kit.text("tr_left", "Quedan {n}").format({"n": left})
	_undo_btn.text = Kit.text("tr_undo", "Deshacer") + " (%d)" % int(st["undo"])
	_undo_btn.disabled = int(st["undo"]) <= 0 or (st["history"] as Array).is_empty() or finished
	_shuffle_btn.text = Kit.text("tr_shuffle", "Barajar") + " (%d)" % int(st["shuffle"])
	_shuffle_btn.disabled = int(st["shuffle"]) <= 0 or finished
	for b: Button in [_undo_btn, _shuffle_btn]:
		b.visible = not _bot
	_world.queue_redraw()


# ------------------------------------------------------------------ jugar

func can_act() -> bool:
	return not finished and is_inside_tree() and not get_tree().paused


func tile_at(p: Vector2) -> int:
	var best: int = -1
	var bz: int = -1
	for t: Dictionary in st["tiles"]:
		if bool(t["gone"]):
			continue
		if tile_rect(t).has_point(p) and int(t["z"]) > bz:
			bz = int(t["z"])
			best = int(t["id"])
	return best


func tap(p: Vector2) -> void:
	if not can_act():
		return
	var id: int = tile_at(p)
	if id < 0:
		return
	if not M.is_free(st, id):
		_shake = id
		_shake_t = 0.25
		_sfx("click", -14.0, 0.6)
		return
	_do_pick(id)


func _do_pick(id: int) -> void:
	var t: Dictionary = st["tiles"][id]
	var from: Vector2 = tile_rect(t).get_center()
	if not M.pick(st, id):
		return
	if not fast:
		_tray_pos[id] = from
	_sfx("click", -8.0, 1.0 + randf() * 0.15)
	Juice.vibrate(10)
	_events()


func use_undo() -> void:
	if not can_act():
		return
	if M.undo(st):
		helps_used += 1
		_sfx("click", -6.0, 0.8)
		_events()


func use_shuffle() -> void:
	if not can_act():
		return
	if M.shuffle(st):
		helps_used += 1
		_sfx("powerup", -6.0)
		_events()


func _events() -> void:
	for e: Dictionary in st["events"]:
		match str(e["kind"]):
			"triple":
				coins += 1
				_sfx("coin", -4.0, 1.0 + 0.1 * float(coins % 4))
				if not fast:
					for id: Variant in e["ids"]:
						var at: Vector2 = _tray_pos.get(int(id), Vector2(360, TRAY_Y + 50))
						_pops.append({"kind": int(e["kind"]), "p": at, "t": 0.0})
						_tray_pos.erase(int(id))
					Juice.burst(self, Vector2(360, TRAY_Y + 50), COLS[int(e["kind"]) % COLS.size()], 14)
			"undo":
				_tray_pos.erase(int(e["id"]))
			"end":
				if bool(e["won"]):
					_finish.call_deferred()
				else:
					_lose.call_deferred()
	(st["events"] as Array).clear()
	_refresh()


func _sfx(n: String, vol: float = -10.0, pitch: float = 1.0) -> void:
	if not fast:
		Audio.play(n, 0.05, vol, pitch)


func bot_step() -> void:
	_bot = true


func _physics_process(delta: float) -> void:
	_t += delta
	if finished:
		return
	time_in_level += delta
	if fast and auto_retry:
		_bot = true
	if _bot and can_act():
		_bot_t -= delta
		if fast or _bot_t <= 0.0:
			_bot_t = 0.35
			var m: Dictionary = M.bot_move(st)
			if m.has("undo"):
				use_undo()
			elif m.has("shuffle"):
				use_shuffle()
			elif m.has("pick"):
				_do_pick(int(m["pick"]))
	## Animaciones: las fichas de la bandeja se deslizan a su hueco y los trios se desvanecen.
	var tray: Array = st["tray"]
	for i: int in tray.size():
		var id: int = int(tray[i]["id"])
		var want: Vector2 = slot_rect(i).get_center()
		var cur: Vector2 = _tray_pos.get(id, want)
		_tray_pos[id] = cur.lerp(want, minf(1.0, delta * 14.0))
	for p: Dictionary in _pops:
		p["t"] = float(p["t"]) + delta
	_pops = _pops.filter(func(p: Dictionary) -> bool: return float(p["t"]) < 0.35)
	_shake_t = maxf(0.0, _shake_t - delta)
	_world.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()
		return
	var pressed: bool = false
	var pos: Vector2 = Vector2.ZERO
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		pressed = true
		pos = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		pressed = true
		pos = (event as InputEventMouseButton).position
	if pressed:
		_bot = false
		## De pantalla a mundo (la camara esta centrada en 360x640 sin zoom).
		var world: Vector2 = get_canvas_transform().affine_inverse() * pos
		tap(world)


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = maxi(1, coins * 100 + maxi(0, int(par - time_in_level)) * 10 - helps_used * 150)
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "time": snappedf(time_in_level, 0.1), "helps": helps_used})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


func stars_earned() -> int:
	if deaths > 0 or helps_used >= 3:
		return 1
	return 3 if helps_used == 0 else 2


func _lose() -> void:
	if finished:
		return
	finished = true
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "tray_full", "left": M.on_board(st).size(), "deaths": deaths})
	Audio.play("hurt")
	Juice.shake(0.3)
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("tr_lost", "\u00a1La bandeja se ha llenado!"),
		Kit.text("tr_fail_hint", "Coge primero las fichas que ya tienes en la bandeja y no llenes los huecos con sueltas. Deshacer te salva de un mal toque."))
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
	if st.is_empty():
		return {}
	return {"deaths": deaths, "coins": coins, "finished": finished, "failed": failed, "time": time_in_level,
		"left": M.on_board(st).size(), "tray": (st["tray"] as Array).size(), "helps": helps_used}


# ------------------------------------------------------------------ dibujo

## Dibujo de cada tipo de ficha: forma y color distintos (se juega aunque no distingas colores).
static func draw_icon(ci: CanvasItem, kind: int, c: Vector2, s: float) -> void:
	var col: Color = COLS[kind % COLS.size()]
	var dark: Color = col.darkened(0.3)
	match kind % 12:
		0:
			## Manzana.
			ci.draw_circle(c + Vector2(-7, 3) * s, 16.0 * s, col)
			ci.draw_circle(c + Vector2(7, 3) * s, 16.0 * s, col)
			ci.draw_rect(Rect2(c + Vector2(-2, -20) * s, Vector2(4, 10) * s), Color("#6d4422"))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(2, -16) * s, c + Vector2(16, -22) * s, c + Vector2(8, -10) * s]), Color("#43a047"))
		1:
			var pts: PackedVector2Array = PackedVector2Array()
			for k: int in 10:
				var r: float = (26.0 if k % 2 == 0 else 11.0) * s
				var a: float = -PI * 0.5 + float(k) * PI / 5.0
				pts.append(c + Vector2(cos(a), sin(a)) * r)
			ci.draw_colored_polygon(pts, col)
		2:
			ci.draw_circle(c + Vector2(-10, -5) * s, 13.0 * s, col)
			ci.draw_circle(c + Vector2(10, -5) * s, 13.0 * s, col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-22.5, -1) * s, c + Vector2(22.5, -1) * s, c + Vector2(0, 24) * s]), col)
		3:
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -26) * s, c + Vector2(19, -6) * s, c + Vector2(0, 26) * s, c + Vector2(-19, -6) * s]), col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -26) * s, c + Vector2(19, -6) * s, c + Vector2(-19, -6) * s]), col.lightened(0.35))
		4:
			## Hoja.
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -26) * s, c + Vector2(17, -4) * s, c + Vector2(0, 24) * s, c + Vector2(-17, -4) * s]), col)
			ci.draw_line(c + Vector2(0, -20) * s, c + Vector2(0, 22) * s, dark, 3.0 * s)
		5:
			## Luna.
			ci.draw_circle(c, 22.0 * s, col)
			ci.draw_circle(c + Vector2(10, -8) * s, 18.0 * s, Color("#fdfbf4"))
		6:
			## Gota.
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -27) * s, c + Vector2(15, 2) * s, c + Vector2(-15, 2) * s]), col)
			ci.draw_circle(c + Vector2(0, 6) * s, 16.0 * s, col)
		7:
			## Flor.
			for k2: int in 5:
				var a2: float = -PI * 0.5 + float(k2) * TAU / 5.0
				ci.draw_circle(c + Vector2(cos(a2), sin(a2)) * 13.0 * s, 10.0 * s, col)
			ci.draw_circle(c, 8.0 * s, Color("#ffe066"))
		8:
			## Rayo.
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(6, -27) * s, c + Vector2(-14, 3) * s, c + Vector2(0, 3) * s, c + Vector2(-6, 27) * s,
				c + Vector2(14, -5) * s, c + Vector2(0, -5) * s]), col)
		9:
			## Seta.
			ci.draw_rect(Rect2(c + Vector2(-7, 0) * s, Vector2(14, 22) * s), Color("#f3e3c3"))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-24, 4) * s, c + Vector2(-16, -16) * s, c + Vector2(0, -24) * s, c + Vector2(16, -16) * s, c + Vector2(24, 4) * s]), col)
			ci.draw_circle(c + Vector2(-8, -10) * s, 4.0 * s, Color.WHITE)
			ci.draw_circle(c + Vector2(9, -6) * s, 3.0 * s, Color.WHITE)
		10:
			## Pez.
			ci.draw_circle(c + Vector2(-4, 0) * s, 15.0 * s, col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(8, 0) * s, c + Vector2(25, -14) * s, c + Vector2(25, 14) * s]), col)
			ci.draw_circle(c + Vector2(-10, -4) * s, 3.5 * s, Color.WHITE)
		11:
			## Corona.
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-22, 16) * s, c + Vector2(-22, -14) * s, c + Vector2(-11, -2) * s, c + Vector2(0, -20) * s,
				c + Vector2(11, -2) * s, c + Vector2(22, -14) * s, c + Vector2(22, 16) * s]), col)
	if kind >= 12:
		ci.draw_arc(c, 27.0 * s, 0.0, TAU, 24, dark, 3.0 * s)


func _draw_tile(r: Rect2, kind: int, free: bool, alpha: float = 1.0) -> void:
	var depth: float = 7.0 * _k
	var rad: float = 14.0 * _k
	_round(Rect2(r.position + Vector2(2, depth + 3), r.size), rad, Color(0, 0, 0, 0.28 * alpha))
	_round(Rect2(r.position + Vector2(0, depth), r.size), rad, Color("#c9b996") * Color(1, 1, 1, alpha))
	_round(r, rad, Color("#fdfbf4") * Color(1, 1, 1, alpha))
	_round(Rect2(r.position + Vector2(4, 4) * _k, Vector2(r.size.x - 8.0 * _k, 10.0 * _k)), 6.0 * _k, Color(1, 1, 1, 0.8 * alpha))
	draw_icon(_world, kind, r.get_center() + Vector2(0, 2) * _k, _k * 1.12)
	if not free:
		_round(r, rad, Color(0.08, 0.1, 0.18, 0.5 * alpha))


## Rectangulo con esquinas redondas (un solo poligono: con transparencia no se oscurecen
## las esquinas por pintar dos veces).
func _round(r: Rect2, rad: float, col: Color) -> void:
	rad = minf(rad, minf(r.size.x, r.size.y) * 0.5)
	var pts: PackedVector2Array = PackedVector2Array()
	var corners: Array = [[r.end - Vector2(rad, rad), 0.0], [Vector2(r.position.x + rad, r.end.y - rad), PI * 0.5],
		[r.position + Vector2(rad, rad), PI], [Vector2(r.end.x - rad, r.position.y + rad), PI * 1.5]]
	for c: Array in corners:
		for k: int in 5:
			var a: float = float(c[1]) + float(k) / 4.0 * PI * 0.5
			pts.append((c[0] as Vector2) + Vector2(cos(a), sin(a)) * rad)
	_world.draw_colored_polygon(pts, col)


func _draw_world() -> void:
	if st.is_empty():
		return
	var board: Array = M.on_board(st)
	## Monton: de abajo arriba (y de arriba abajo en pantalla dentro de cada capa).
	board.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["z"]) != int(b["z"]):
			return int(a["z"]) < int(b["z"])
		return float(a["y"]) < float(b["y"]))
	for t: Dictionary in board:
		var r: Rect2 = tile_rect(t)
		if int(t["id"]) == _shake and _shake_t > 0.0:
			r.position.x += sin(_shake_t * 70.0) * 5.0
		_draw_tile(r, int(t["kind"]), M.is_free_in(t, board))
	## Bandeja: madera con huecos; se pone roja cuando queda un hueco.
	var n: int = int(st["tray_max"])
	var tray: Array = st["tray"]
	var full: bool = tray.size() >= n - 1
	var panel: Rect2 = Rect2(Vector2(360.0 - float(n) * SLOT * 0.5 - 14.0, TRAY_Y), Vector2(float(n) * SLOT + 28.0, SLOT + 30.0))
	var warn: Color = Color("#e53950") if full and int(_t * 4.0) % 2 == 0 else Color("#6d4422")
	var keep_k: float = _k
	_k = 1.0
	_round(Rect2(panel.position + Vector2(0, 6), panel.size), 22.0, Color(0, 0, 0, 0.3))
	_round(panel, 22.0, warn)
	_round(panel.grow(-6.0), 18.0, Color("#a8743f"))
	for i: int in n:
		_round(slot_rect(i), 12.0, Color(0, 0, 0, 0.22))
	for i2: int in tray.size():
		var id: int = int(tray[i2]["id"])
		var c: Vector2 = _tray_pos.get(id, slot_rect(i2).get_center())
		var sr: Rect2 = slot_rect(i2)
		_draw_tile(Rect2(c - sr.size * 0.5, sr.size), int(tray[i2]["kind"]), true)
	for p: Dictionary in _pops:
		var f: float = 1.0 - float(p["t"]) / 0.35
		var sz: Vector2 = Vector2(SLOT - 8.0, SLOT + 4.0) * (1.0 + (1.0 - f) * 0.4)
		_draw_tile(Rect2((p["p"] as Vector2) - sz * 0.5, sz), int(p["kind"]), true, f)
	_k = keep_k
