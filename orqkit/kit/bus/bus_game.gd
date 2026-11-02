extends Node2D
## Bus jam: toca a un pasajero con camino libre hasta arriba; sale andando y sube al autobus de
## su color o espera en la parada. Autobus lleno (3) se va y llega otro. Ganas al subirlos a
## todos; pierdes con la parada llena y sin jugada. Ayuda: VIP (saca a cualquiera).
## Reglas, reparto, bot y analizador en bus_map.gd (logica pura).
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const M = preload("res://kit/bus/bus_map.gd")
const BOARD: Rect2 = Rect2(40, 410, 640, 690)
const BUS_Y: float = 118.0
const BUS_H: float = 112.0
const STOP_Y: float = 300.0
const SLOT: float = 74.0
const WALK: float = 12.0
const COLS: Array[Color] = [Color("#e53950"), Color("#1fb6d9"), Color("#f5b301"), Color("#43a047"), Color("#8e5cd9"),
	Color("#ff7a1a"), Color("#ec5fa4"), Color("#2f6fd0")]

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
var _vip_btn: Button
var _bot: bool = false
var _bot_t: float = 0.0
var _t: float = 0.0
var _cell: float = 72.0
var _origin: Vector2 = Vector2.ZERO
## Pasajeros andando: {"id", "color", "pts": [Vector2...], "d": recorrido}; autobuses que se van.
var _walkers: Array = []
var _leaving: Array = []
var _bus_in: Array = [1.0, 1.0]
var _shake: int = -1
var _shake_t: float = 0.0
var _vip_mode: bool = false


func _ready() -> void:
	level = Kit.current_level()
	par = float(level.get("par", 0))
	RenderingServer.set_default_clear_color(Kit.color("sky", Color("#4a7a9e")).darkened(0.35))
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
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "bus", "people": (st["people"] as Array).size()})


func bot_script() -> String:
	return "res://qa/bus_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(4.0, 3.0)


func wants_grade() -> bool:
	return false


func _reset() -> void:
	finished = false
	failed = false
	var lv: Dictionary = level.duplicate()
	if deaths > 0:
		var rows: Array = []
		for r: Variant in level.get("map", []):
			if not (str(r).begins_with("#") and str(r).substr(1).is_valid_int()):
				rows.append(r)
		rows.append("#%d" % (int(M.parse(level)["seed"]) + deaths * 131))
		lv["map"] = rows
	st = M.new_state(lv)
	coins_total = (st["people"] as Array).size() / M.SEATS
	coins = 0
	helps_used = 0
	time_in_level = 0.0
	_walkers.clear()
	_leaving.clear()
	_bus_in = [1.0, 1.0]
	_vip_mode = false
	_cell = minf(84.0, minf(BOARD.size.x / float(st["w"]), BOARD.size.y / float(st["h"])))
	_origin = Vector2(360.0 - float(st["w"]) * _cell * 0.5, BOARD.position.y)
	_refresh()


func cell_pos(c: Vector2i) -> Vector2:
	return _origin + (Vector2(c) + Vector2(0.5, 0.5)) * _cell


func person_pos(id: int) -> Vector2:
	return cell_pos(st["people"][id]["cell"] as Vector2i)


func bus_rect(i: int) -> Rect2:
	var n: int = (st["buses"] as Array).size()
	var w: float = 300.0 if n == 1 else 260.0
	var x0: float = 360.0 - (float(n) * w + float(n - 1) * 24.0) * 0.5
	return Rect2(Vector2(x0 + float(i) * (w + 24.0), BUS_Y), Vector2(w, BUS_H))


func seat_pos(i: int, s: int) -> Vector2:
	var r: Rect2 = bus_rect(i)
	return Vector2(r.position.x + r.size.x * (0.3 + 0.22 * float(s)), r.position.y + r.size.y * 0.42)


func hold_pos(k: int) -> Vector2:
	var n: int = int(st["hold_max"])
	return Vector2(360.0 - float(n) * SLOT * 0.5 + (float(k) + 0.5) * SLOT, STOP_Y + SLOT * 0.5)


func cell_at(p: Vector2) -> Vector2i:
	var c: Vector2i = Vector2i(floori((p.x - _origin.x) / _cell), floori((p.y - _origin.y) / _cell))
	if c.x < 0 or c.y < 0 or c.x >= int(st["w"]) or c.y >= int(st["h"]):
		return Vector2i(-1, -1)
	return c


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
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row)
	_vip_btn = UI.make_button("", false)
	_vip_btn.name = "BtnVip"
	_vip_btn.custom_minimum_size = Vector2(300, 88)
	_vip_btn.pressed.connect(toggle_vip)
	row.add_child(_vip_btn)


func _refresh() -> void:
	_left_lbl.text = Kit.text("bu_left", "Quedan {n}").format({"n": M.left(st) + (st["hold"] as Array).size()})
	_vip_btn.text = (Kit.text("bu_cancel", "Cancelar") if _vip_mode else Kit.text("bu_vip", "VIP")) + " (%d)" % int(st["vip"])
	_vip_btn.disabled = int(st["vip"]) <= 0 or finished
	_vip_btn.visible = not _bot
	_world.queue_redraw()


# ------------------------------------------------------------------ jugar

func can_act() -> bool:
	return not finished and is_inside_tree() and not get_tree().paused


func person_at(p: Vector2) -> int:
	var c: Vector2i = cell_at(p)
	if c.x < 0:
		return -1
	return int(M.occupied(st).get(c, -1))


func tap(p: Vector2) -> void:
	if not can_act():
		return
	var id: int = person_at(p)
	if id < 0:
		return
	if _vip_mode:
		_do_pick(id, true)
		return
	if not M.can_leave(st, id):
		_shake = id
		_shake_t = 0.3
		_sfx("click", -14.0, 0.6)
		return
	if not M.can_place(st, st["people"][id]):
		_sfx("click", -12.0, 0.5)
		return
	_do_pick(id, false)


func _do_pick(id: int, vip: bool) -> void:
	if not M.pick(st, id, vip):
		return
	if vip:
		helps_used += 1
		_vip_mode = false
		_sfx("powerup", -6.0)
	else:
		_sfx("click", -8.0, 1.1 + randf() * 0.2)
	Juice.vibrate(10)
	_events()


func toggle_vip() -> void:
	if not can_act() or int(st["vip"]) <= 0:
		return
	_vip_mode = not _vip_mode
	_refresh()


func _events() -> void:
	for e: Dictionary in st["events"]:
		match str(e["kind"]):
			"leave":
				if not fast:
					var id: int = int(e["id"])
					var pts: Array = []
					for c: Vector2i in e["path"]:
						pts.append(cell_pos(c))
					if pts.is_empty():
						pts.append(person_pos(id))
					pts.append(Vector2((pts[pts.size() - 1] as Vector2).x, _origin.y - _cell * 0.4))
					pts.append(seat_pos(int(e["bus"]), int(e["seat"])) if e.has("bus") else hold_pos(int(e["hold"])))
					_walkers.append({"id": id, "color": int(st["people"][id]["color"]), "pts": pts, "d": 0.0})
			"unhold":
				if not fast:
					var id2: int = int(e["id"])
					var from: Vector2 = hold_pos(0)
					for w: Dictionary in _walkers:
						if int(w["id"]) == id2:
							from = (w["pts"] as Array).back()
					_walkers = _walkers.filter(func(w2: Dictionary) -> bool: return int(w2["id"]) != id2)
					_walkers.append({"id": id2, "color": int(st["people"][id2]["color"]), "pts": [from, seat_pos(int(e["bus"]), int(e["seat"]))], "d": 0.0})
			"depart":
				coins += 1
				_sfx("coin", -4.0, 1.0 + 0.1 * float(coins % 4))
				if not fast:
					_leaving.append({"r": bus_rect(int(e["bus"])), "color": int(e["color"]), "t": 0.0})
					Juice.burst(self, bus_rect(int(e["bus"])).get_center(), COLS[int(e["color"]) % COLS.size()], 12)
				for id3: Variant in e["ids"]:
					_walkers = _walkers.filter(func(w3: Dictionary) -> bool: return int(w3["id"]) != int(id3))
			"arrive":
				if not fast:
					_bus_in[int(e["bus"])] = 0.0
			"stuck":
				_sfx("click", -8.0, 0.5)
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
	for w: Dictionary in _walkers:
		w["d"] = float(w["d"]) + delta * WALK * _cell
	_walkers = _walkers.filter(func(w: Dictionary) -> bool: return float(w["d"]) < _length(w["pts"]))
	for l: Dictionary in _leaving:
		l["t"] = float(l["t"]) + delta
	_leaving = _leaving.filter(func(l: Dictionary) -> bool: return float(l["t"]) < 0.6)
	for i: int in _bus_in.size():
		_bus_in[i] = minf(1.0, float(_bus_in[i]) + delta * 2.2)
	_shake_t = maxf(0.0, _shake_t - delta)
	if is_instance_valid(_vip_btn):
		var pulse: float = 0.75 + 0.25 * sin(_t * 9.0) if bool(st.get("stuck", false)) else 1.0
		_vip_btn.modulate = Color(1, pulse, pulse)
	_world.queue_redraw()
	if finished:
		return
	time_in_level += delta
	if fast and auto_retry:
		_bot = true
	if _bot and can_act():
		_bot_t -= delta
		if fast or _bot_t <= 0.0:
			_bot_t = 0.4
			var m: Dictionary = M.bot_move(st)
			if m.has("vip"):
				_do_pick(int(m["vip"]), true)
			elif m.has("pick"):
				_do_pick(int(m["pick"]), false)


func _length(pts: Array) -> float:
	var d: float = 0.0
	for k: int in range(1, pts.size()):
		d += (pts[k - 1] as Vector2).distance_to(pts[k])
	return d


func _along(pts: Array, d: float) -> Vector2:
	for k: int in range(1, pts.size()):
		var seg: float = (pts[k - 1] as Vector2).distance_to(pts[k])
		if d <= seg:
			return (pts[k - 1] as Vector2).lerp(pts[k], d / maxf(seg, 0.001))
		d -= seg
	return pts.back()


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
		tap(get_canvas_transform().affine_inverse() * pos)


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
	if deaths > 0 or helps_used >= 2:
		return 1
	return 3 if helps_used == 0 else 2


func _lose() -> void:
	if finished:
		return
	finished = true
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "stop_full", "left": M.left(st), "deaths": deaths})
	Audio.play("hurt")
	Juice.shake(0.3)
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("bu_lost", "\u00a1La parada est\u00e1 llena!"),
		Kit.text("bu_fail_hint", "Saca primero a los del color del autob\u00fas y a los que abren camino; deja la parada para cuando no haya otra."))
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
		"left": M.left(st), "hold": (st["hold"] as Array).size(), "helps": helps_used}


# ------------------------------------------------------------------ dibujo

## Pasajero visto desde arriba en diagonal: cuerpo de su color, cabeza y una marca por color.
static func draw_person(ci: CanvasItem, color: int, c: Vector2, s: float, dim: float = 1.0) -> void:
	var col: Color = COLS[color % COLS.size()] * Color(dim, dim, dim)
	ci.draw_circle(c + Vector2(0, 16) * s, 15.0 * s, Color(0, 0, 0, 0.25))
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-14, 18) * s, c + Vector2(-11, -2) * s, c + Vector2(11, -2) * s,
		c + Vector2(14, 18) * s]), col)
	ci.draw_circle(c + Vector2(0, -2) * s, 11.0 * s, col)
	ci.draw_circle(c + Vector2(0, -14) * s, 10.0 * s, Color("#f6d2b0") * Color(dim, dim, dim))
	ci.draw_arc(c + Vector2(0, -16) * s, 10.0 * s, PI, TAU, 10, col.darkened(0.35), 5.0 * s)
	## Marca en el pecho: se distingue aunque no veas bien los colores.
	match color % 4:
		0:
			ci.draw_circle(c + Vector2(0, 8) * s, 3.5 * s, Color(1, 1, 1, 0.8 * dim))
		1:
			ci.draw_rect(Rect2(c + Vector2(-3.5, 4.5) * s, Vector2(7, 7) * s), Color(1, 1, 1, 0.8 * dim))
		2:
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, 3) * s, c + Vector2(4.5, 12) * s, c + Vector2(-4.5, 12) * s]), Color(1, 1, 1, 0.8 * dim))
		3:
			ci.draw_line(c + Vector2(-4, 8) * s, c + Vector2(4, 8) * s, Color(1, 1, 1, 0.8 * dim), 3.0 * s)


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


func _draw_bus(r: Rect2, color: int, alpha: float = 1.0) -> void:
	var col: Color = COLS[color % COLS.size()]
	_round(Rect2(r.position + Vector2(0, 8), r.size), 22.0, Color(0, 0, 0, 0.3 * alpha))
	_round(r, 22.0, Color(col.darkened(0.25), alpha))
	_round(r.grow(-6.0), 18.0, Color(col, alpha))
	## Ventanas (una por asiento) y ruedas.
	for s: int in M.SEATS:
		var w: Rect2 = Rect2(Vector2(r.position.x + r.size.x * (0.3 + 0.22 * float(s)) - 26.0, r.position.y + 14.0), Vector2(52, 48))
		_round(w, 10.0, Color(0.85, 0.95, 1.0, 0.9 * alpha))
	_round(Rect2(r.position + Vector2(14, 14), Vector2(36, 70)), 8.0, Color(0.85, 0.95, 1.0, 0.75 * alpha))
	for wx: float in [0.22, 0.78]:
		_world.draw_circle(Vector2(r.position.x + r.size.x * wx, r.end.y - 2.0), 15.0, Color(0.12, 0.12, 0.15, alpha))
		_world.draw_circle(Vector2(r.position.x + r.size.x * wx, r.end.y - 2.0), 6.0, Color(0.6, 0.6, 0.65, alpha))


func _draw_world() -> void:
	if st.is_empty():
		return
	var walking: Dictionary = {}
	for w: Dictionary in _walkers:
		walking[int(w["id"])] = true
	## Carretera y autobuses (el que llega entra desde la derecha; el que se va sale por la izquierda).
	_world.draw_rect(Rect2(Vector2(-40, BUS_Y - 10.0), Vector2(800, BUS_H + 30.0)), Color("#3b3f48"))
	for k: int in 12:
		_world.draw_rect(Rect2(Vector2(float(k) * 70.0, BUS_Y + BUS_H + 12.0), Vector2(40, 5)), Color(1, 1, 1, 0.5))
	for l: Dictionary in _leaving:
		var lr: Rect2 = l["r"]
		lr.position.x -= pow(float(l["t"]) / 0.6, 2.0) * 760.0
		_draw_bus(lr, int(l["color"]))
	var buses: Array = st["buses"]
	for i: int in buses.size():
		var color: int = int(buses[i]["color"])
		if color < 0:
			continue
		var r: Rect2 = bus_rect(i)
		r.position.x += (1.0 - ease(float(_bus_in[i]), 0.4)) * 520.0
		_draw_bus(r, color)
		var ids: Array = buses[i]["ids"]
		var dx: float = r.position.x - bus_rect(i).position.x
		for s: int in ids.size():
			if not walking.has(int(ids[s])):
				draw_person(_world, color, seat_pos(i, s) + Vector2(dx, 0), 0.95)
	## Los que vienen: autobuses pequenos en orden.
	var q: Array = st["queue"]
	for j: int in mini(q.size(), 5):
		_round(Rect2(Vector2(560.0 + float(j) * 30.0, BUS_Y + BUS_H + 26.0), Vector2(24, 14)), 4.0, Color(COLS[int(q[j]) % COLS.size()], 0.9 - 0.12 * float(j)))
	## Parada con sus huecos (roja cuando queda uno).
	var n: int = int(st["hold_max"])
	var hold: Array = st["hold"]
	var danger: bool = hold.size() >= n - 1
	var panel: Rect2 = Rect2(Vector2(360.0 - float(n) * SLOT * 0.5 - 12.0, STOP_Y - 6.0), Vector2(float(n) * SLOT + 24.0, SLOT + 12.0))
	_round(panel, 20.0, Color("#e53950") if danger and int(_t * 4.0) % 2 == 0 else Color("#2b3346"))
	_round(panel.grow(-5.0), 16.0, Color("#56627e"))
	for k2: int in n:
		_world.draw_circle(hold_pos(k2), SLOT * 0.36, Color(0, 0, 0, 0.25))
	for k3: int in hold.size():
		if not walking.has(int(hold[k3]["id"])):
			draw_person(_world, int(hold[k3]["color"]), hold_pos(k3), 0.95)
	## Estacion: suelo, paredes y la salida arriba (flechas).
	var board: Rect2 = Rect2(_origin, Vector2(float(st["w"]), float(st["h"])) * _cell)
	_round(board.grow(14.0), 22.0, Color("#2b3346"))
	for y: int in int(st["h"]):
		for x: int in int(st["w"]):
			var c: Vector2i = Vector2i(x, y)
			var r2: Rect2 = Rect2(_origin + Vector2(c) * _cell, Vector2(_cell, _cell))
			if (st["walls"] as Dictionary).has(c):
				_round(r2.grow(-2.0), 8.0, Color("#6b5a4a"))
				_round(Rect2(r2.position + Vector2(4, 3), r2.size - Vector2(8, 14)), 6.0, Color("#8a7660"))
			else:
				_world.draw_rect(r2.grow(-1.5), Color("#d9dde6") if (x + y) % 2 == 0 else Color("#cdd2dc"))
	for x2: int in int(st["w"]):
		var ax: float = _origin.x + (float(x2) + 0.5) * _cell
		var ay: float = _origin.y - 22.0 + sin(_t * 4.0 + float(x2)) * 2.0
		_world.draw_colored_polygon(PackedVector2Array([Vector2(ax - 9, ay + 6), Vector2(ax + 9, ay + 6), Vector2(ax, ay - 6)]), Color(1, 1, 1, 0.45))
	## Pasajeros: los que pueden salir, brillantes y dando saltitos; los encerrados, apagados.
	var occ: Dictionary = M.occupied(st)
	var k_s: float = _cell / 72.0
	for p: Dictionary in st["people"]:
		if bool(p["gone"]):
			continue
		var pid: int = int(p["id"])
		var pos: Vector2 = cell_pos(p["cell"] as Vector2i)
		var free: bool = not M.path_out(st, p["cell"], occ).is_empty()
		if free:
			pos.y -= absf(sin(_t * 5.0 + float(pid))) * 3.0
		if pid == _shake and _shake_t > 0.0:
			pos.x += sin(_shake_t * 70.0) * 5.0
		draw_person(_world, int(p["color"]), pos, k_s * 1.25, 1.0 if free else 0.78)
		if _vip_mode:
			_world.draw_arc(pos, _cell * 0.45, 0.0, TAU, 20, Color("#ffd23f"), 3.0)
	for w2: Dictionary in _walkers:
		draw_person(_world, int(w2["color"]), _along(w2["pts"], float(w2["d"])), 1.1)
