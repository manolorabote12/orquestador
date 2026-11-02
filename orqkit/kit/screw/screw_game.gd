extends Node2D
## Puzle de tornillos (estilo Screw Jam): toca los tornillos libres; van a la caja de su color
## o a los huecos de espera. Las placas sin tornillos caen y las cajas llenas se van. Ganas al
## quitarlos todos; pierdes si se llenan los huecos sin jugada. Ayuda: HUECO EXTRA.
## Reglas, reparto, bot y analizador en screw_map.gd (logica pura).
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const M = preload("res://kit/screw/screw_map.gd")
const CELL: float = 80.0
const BOARD_Y: float = 300.0
const BOX_Y: float = 112.0
const BOX_W: float = 196.0
const BOX_H: float = 124.0
const HOLD_Y: float = 1036.0
const SLOT: float = 78.0
const R: float = 23.0
## Colores de los tornillos (y de sus cajas); cada uno con su marca en la cabeza.
const COLS: Array[Color] = [Color("#e53950"), Color("#1fb6d9"), Color("#f5b301"), Color("#43a047"), Color("#8e5cd9"),
	Color("#ff7a1a"), Color("#ec5fa4"), Color("#2f6fd0")]
## Placas de metacrilato de colores suaves (no se confunden con los tornillos).
const PLATES: Array[Color] = [Color("#f2c18d"), Color("#9fd8cb"), Color("#f7a8a0"), Color("#b7c4f2"), Color("#d8e89a"), Color("#e6b8e8")]

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
var _extra_btn: Button
var _bot: bool = false
var _bot_t: float = 0.0
var _t: float = 0.0
var _origin: Vector2 = Vector2.ZERO
## Tornillos en camino (id -> posicion dibujada), placas cayendo, cajas que se van o llegan.
var _pos: Dictionary = {}
var _spin: Dictionary = {}
var _falls: Array = []
var _pops: Array = []
var _box_in: Array = [1.0, 1.0, 1.0]
var _shake: int = -1
var _shake_t: float = 0.0
var _hold_shake: float = 0.0


func _ready() -> void:
	level = Kit.current_level()
	par = float(level.get("par", 0))
	RenderingServer.set_default_clear_color(Kit.color("sky", Color("#36506e")).darkened(0.2))
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
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "screw", "screws": (st["screws"] as Array).size()})


func bot_script() -> String:
	return "res://qa/screw_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(4.0, 3.0)


func wants_grade() -> bool:
	return false


func _reset() -> void:
	finished = false
	failed = false
	var lv: Dictionary = level.duplicate()
	if deaths > 0:
		## Otro reparto de colores al reintentar (mismas placas).
		var rows: Array = []
		for r: Variant in level.get("map", []):
			if not (str(r).begins_with("#") and str(r).substr(1).is_valid_int()):
				rows.append(r)
		rows.append("#%d" % (int(M.parse(level)["seed"]) + deaths * 131))
		lv["map"] = rows
	st = M.new_state(lv)
	coins_total = (st["screws"] as Array).size() / M.BOX
	coins = 0
	helps_used = 0
	time_in_level = 0.0
	_pos.clear()
	_spin.clear()
	_falls.clear()
	_pops.clear()
	_box_in = [1.0, 1.0, 1.0]
	_layout()
	_refresh()


## Centra en la pantalla el rectangulo que ocupan las placas.
func _layout() -> void:
	var box: Rect2i = Rect2i()
	var first: bool = true
	for p: Dictionary in st["plates"]:
		box = p["rect"] if first else box.merge(p["rect"] as Rect2i)
		first = false
	var size: Vector2 = Vector2(box.size) * CELL
	_origin = Vector2(360.0, BOARD_Y + float(M.ROWS) * CELL * 0.5) - size * 0.5 - Vector2(box.position) * CELL


func cell_center(c: Vector2i) -> Vector2:
	return _origin + (Vector2(c) + Vector2(0.5, 0.5)) * CELL


func screw_pos(id: int) -> Vector2:
	return cell_center(st["screws"][id]["cell"] as Vector2i)


func plate_rect(r: Rect2i) -> Rect2:
	return Rect2(_origin + Vector2(r.position) * CELL, Vector2(r.size) * CELL).grow(-6.0)


func box_rect(i: int) -> Rect2:
	var n: int = (st["boxes"] as Array).size()
	var gap: float = 22.0
	var x0: float = 360.0 - (float(n) * BOX_W + float(n - 1) * gap) * 0.5
	return Rect2(Vector2(x0 + float(i) * (BOX_W + gap), BOX_Y), Vector2(BOX_W, BOX_H))


func box_slot(i: int, k: int) -> Vector2:
	var r: Rect2 = box_rect(i)
	return Vector2(r.position.x + r.size.x * (0.22 + 0.28 * float(k)), r.position.y + r.size.y * 0.58)


func hold_slot(i: int) -> Vector2:
	var n: int = int(st["hold_max"])
	var x0: float = 360.0 - float(n) * SLOT * 0.5
	return Vector2(x0 + (float(i) + 0.5) * SLOT, HOLD_Y + SLOT * 0.5 + 10.0)


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
	col.add_child(row)
	_extra_btn = UI.make_button("", false)
	_extra_btn.name = "BtnExtra"
	_extra_btn.custom_minimum_size = Vector2(330, 92)
	_extra_btn.pressed.connect(use_extra)
	row.add_child(_extra_btn)


func _refresh() -> void:
	_left_lbl.text = Kit.text("sw_left", "Quedan {n}").format({"n": M.on_board(st).size()})
	_extra_btn.text = Kit.text("sw_extra", "Hueco extra") + " (%d)" % int(st["extra"])
	_extra_btn.disabled = int(st["extra"]) <= 0 or int(st["hold_max"]) >= M.HOLD_MAX or finished
	_extra_btn.visible = not _bot
	_world.queue_redraw()


# ------------------------------------------------------------------ jugar

func can_act() -> bool:
	return not finished and is_inside_tree() and not get_tree().paused


## Tornillo bajo el dedo: el de la placa mas alta (aunque este tapado, para avisar).
func screw_at(p: Vector2) -> int:
	var best: int = -1
	var bp: int = -1
	for s: Dictionary in st["screws"]:
		if bool(s["gone"]):
			continue
		if screw_pos(int(s["id"])).distance_to(p) <= CELL * 0.5 and int(s["plate"]) > bp:
			bp = int(s["plate"])
			best = int(s["id"])
	return best


func tap(p: Vector2) -> void:
	if not can_act():
		return
	var id: int = screw_at(p)
	if id < 0:
		return
	if not M.is_free(st, id):
		_shake = id
		_shake_t = 0.25
		_sfx("click", -14.0, 0.6)
		return
	if not M.can_place(st, st["screws"][id]):
		_hold_shake = 0.3
		_sfx("click", -12.0, 0.5)
		return
	_do_pick(id)


func _do_pick(id: int) -> void:
	var from: Vector2 = screw_pos(id)
	if not M.pick(st, id):
		return
	_pos[id] = from
	_spin[id] = 0.0
	_sfx("click", -8.0, 1.1 + randf() * 0.2)
	Juice.vibrate(10)
	_events()


func use_extra() -> void:
	if not can_act():
		return
	if M.use_extra(st):
		helps_used += 1
		_sfx("powerup", -6.0)
		_events()


func _events() -> void:
	for e: Dictionary in st["events"]:
		match str(e["kind"]):
			"fall":
				var pid: int = int(e["plate"])
				if not fast:
					_falls.append({"plate": pid, "y": 0.0, "v": -120.0, "rot": 0.0, "w": (randf() - 0.5) * 3.0})
				_sfx("hit", -10.0, 0.8)
			"boxdone":
				coins += 1
				var i: int = int(e["box"])
				_sfx("coin", -4.0, 1.0 + 0.1 * float(coins % 4))
				if not fast:
					_pops.append({"color": int(e["color"]), "r": box_rect(i), "t": 0.0})
					Juice.burst(self, box_rect(i).get_center(), COLS[int(e["color"]) % COLS.size()], 14)
					_box_in[i] = 0.0
				for id: Variant in e["ids"]:
					_pos.erase(int(id))
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
			if m.has("extra"):
				use_extra()
			elif m.has("pick"):
				_do_pick(int(m["pick"]))
	## Animaciones: los tornillos giran y vuelan a su caja o hueco; las placas caen.
	var boxes: Array = st["boxes"]
	for i: int in boxes.size():
		var ids: Array = boxes[i]["ids"]
		for k: int in ids.size():
			_glide(int(ids[k]), box_slot(i, k), delta)
		_box_in[i] = minf(1.0, float(_box_in[i]) + delta * 4.0)
	var hold: Array = st["hold"]
	for j: int in hold.size():
		_glide(int(hold[j]["id"]), hold_slot(j), delta)
	for f: Dictionary in _falls:
		f["v"] = float(f["v"]) + 2200.0 * delta
		f["y"] = float(f["y"]) + float(f["v"]) * delta
		f["rot"] = float(f["rot"]) + float(f["w"]) * delta
	_falls = _falls.filter(func(f: Dictionary) -> bool: return float(f["y"]) < 1400.0)
	for p: Dictionary in _pops:
		p["t"] = float(p["t"]) + delta
	_pops = _pops.filter(func(p: Dictionary) -> bool: return float(p["t"]) < 0.4)
	_shake_t = maxf(0.0, _shake_t - delta)
	_hold_shake = maxf(0.0, _hold_shake - delta)
	if is_instance_valid(_extra_btn):
		var pulse: float = 0.75 + 0.25 * sin(_t * 9.0) if bool(st["stuck"]) else 1.0
		_extra_btn.modulate = Color(1, pulse, pulse)
	_world.queue_redraw()


func _glide(id: int, want: Vector2, delta: float) -> void:
	var cur: Vector2 = _pos.get(id, want)
	_pos[id] = cur.lerp(want, minf(1.0, delta * 12.0))
	_spin[id] = float(_spin.get(id, 0.0)) + delta * 14.0 * minf(1.0, cur.distance_to(want) / 40.0)


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
	QA.log_event("death", {"cause": "hold_full", "left": M.on_board(st).size(), "deaths": deaths})
	Audio.play("hurt")
	Juice.shake(0.3)
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("sw_lost", "\u00a1No quedan huecos!"),
		Kit.text("sw_fail_hint", "Quita primero los tornillos del color de las cajas abiertas y deja los huecos de espera para cuando no haya otra."))
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
		"left": M.on_board(st).size(), "hold": (st["hold"] as Array).size(), "helps": helps_used}


# ------------------------------------------------------------------ dibujo

## Cabeza de tornillo: color, brillo, ranura en cruz y una marca distinta por color (se juega
## aunque no distingas colores).
static func draw_screw(ci: CanvasItem, color: int, c: Vector2, s: float, rot: float = 0.0, dim: float = 1.0) -> void:
	var col: Color = COLS[color % COLS.size()] * Color(dim, dim, dim)
	ci.draw_circle(c + Vector2(2, 4) * s, R * s, Color(0, 0, 0, 0.3))
	ci.draw_circle(c, R * s, col.darkened(0.35))
	ci.draw_circle(c - Vector2(1, 2) * s, (R - 3.0) * s, col)
	ci.draw_circle(c - Vector2(6, 8) * s, 6.0 * s, Color(1, 1, 1, 0.35 * dim))
	var a: Vector2 = Vector2(cos(rot), sin(rot)) * 12.0 * s
	var b: Vector2 = Vector2(-a.y, a.x)
	var slot: Color = col.darkened(0.55)
	ci.draw_line(c - a, c + a, slot, 5.0 * s)
	if color % 2 == 0:
		ci.draw_line(c - b, c + b, slot, 5.0 * s)
	else:
		ci.draw_circle(c, 4.0 * s, slot)


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


## Una placa con sus agujeros (en local: el que llama pone la transformacion si cae).
func _draw_plate(pid: int, r: Rect2) -> void:
	var col: Color = PLATES[pid % PLATES.size()]
	_round(Rect2(r.position + Vector2(4, 8), r.size), 22.0, Color(0, 0, 0, 0.25))
	_round(r, 22.0, Color(col.darkened(0.3), 0.92))
	_round(r.grow(-5.0), 18.0, Color(col, 0.86))
	_round(Rect2(r.position + Vector2(10, 8), Vector2(r.size.x - 20.0, 8.0)), 4.0, Color(1, 1, 1, 0.35))
	for s: Dictionary in st["screws"]:
		if int(s["plate"]) == pid:
			var c: Vector2 = cell_center(s["cell"] as Vector2i) - plate_rect(st["plates"][pid]["rect"]).position + r.position
			_world.draw_circle(c, R + 4.0, col.darkened(0.5))
			_world.draw_circle(c, R + 1.0, Color(0.1, 0.1, 0.14, 0.75))


func _draw_world() -> void:
	if st.is_empty():
		return
	## Tablero de fondo con los agujeros de la pared.
	var back: Rect2 = Rect2(Vector2(24, BOARD_Y - 16.0), Vector2(672, float(M.ROWS) * CELL + 32.0))
	_round(back, 30.0, Color(0, 0, 0, 0.18))
	## Placas de abajo arriba; cada tornillo justo despues de su placa (lo tapan las de encima).
	for p: Dictionary in st["plates"]:
		if bool(p["gone"]):
			continue
		var pid: int = int(p["id"])
		_draw_plate(pid, plate_rect(p["rect"]))
		for s: Dictionary in st["screws"]:
			if int(s["plate"]) != pid or bool(s["gone"]):
				continue
			var c: Vector2 = cell_center(s["cell"] as Vector2i)
			if int(s["id"]) == _shake and _shake_t > 0.0:
				c.x += sin(_shake_t * 70.0) * 5.0
			draw_screw(_world, int(s["color"]), c, 1.0, 0.6 + float(int(s["id"]) % 5) * 0.5, 1.0 if M.is_free(st, int(s["id"])) else 0.8)
	## Placas cayendo (girando sobre su centro).
	for f: Dictionary in _falls:
		var pr: Rect2 = plate_rect(st["plates"][int(f["plate"])]["rect"])
		var cen: Vector2 = pr.get_center() + Vector2(0, float(f["y"]))
		_world.draw_set_transform(cen, float(f["rot"]), Vector2.ONE)
		_draw_plate(int(f["plate"]), Rect2(-pr.size * 0.5, pr.size))
		_world.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_boxes()
	_draw_hold()


func _draw_boxes() -> void:
	var boxes: Array = st["boxes"]
	for i: int in boxes.size():
		var color: int = int(boxes[i]["color"])
		var r: Rect2 = box_rect(i)
		var k: float = 0.6 + 0.4 * float(_box_in[i])
		r = Rect2(r.get_center() - r.size * k * 0.5, r.size * k)
		if color < 0:
			_round(r, 20.0, Color(1, 1, 1, 0.08))
			continue
		var col: Color = COLS[color % COLS.size()]
		_round(Rect2(r.position + Vector2(0, 8), r.size), 20.0, col.darkened(0.45))
		_round(r, 20.0, col)
		_round(Rect2(r.position + Vector2(10, 8), Vector2(r.size.x - 20.0, 12.0)), 6.0, Color(1, 1, 1, 0.3))
		for s: int in M.BOX:
			var c: Vector2 = r.get_center() + (box_slot(i, s) - box_rect(i).get_center()) * k
			_world.draw_circle(c, (R + 3.0) * k, col.darkened(0.5))
		var ids: Array = boxes[i]["ids"]
		for s2: int in ids.size():
			var id: int = int(ids[s2])
			draw_screw(_world, color, _pos.get(id, box_slot(i, s2)), 0.9, float(_spin.get(id, 0.0)))
	## Cajas que se van: suben y se desvanecen.
	for p: Dictionary in _pops:
		var f: float = float(p["t"]) / 0.4
		var pr: Rect2 = p["r"]
		pr.position.y -= f * 90.0
		_round(pr, 20.0, Color(COLS[int(p["color"]) % COLS.size()], 1.0 - f))
	## Las que vienen detras: cuadraditos de su color en orden.
	var q: Array = st["queue"]
	var n: int = mini(q.size(), 6)
	var x0: float = 360.0 - float(n) * 34.0 * 0.5
	for j: int in n:
		var rr: Rect2 = Rect2(Vector2(x0 + float(j) * 34.0 + 4.0, BOX_Y + BOX_H + 18.0), Vector2(26, 18))
		_round(rr, 6.0, Color(COLS[int(q[j]) % COLS.size()], 0.9 - 0.1 * float(j)))


func _draw_hold() -> void:
	var n: int = int(st["hold_max"])
	var hold: Array = st["hold"]
	var danger: bool = hold.size() >= n - 1
	var dx: float = sin(_hold_shake * 60.0) * 6.0 if _hold_shake > 0.0 else 0.0
	var panel: Rect2 = Rect2(Vector2(360.0 - float(n) * SLOT * 0.5 - 14.0 + dx, HOLD_Y), Vector2(float(n) * SLOT + 28.0, SLOT + 20.0))
	var rim: Color = Color("#e53950") if danger and int(_t * 4.0) % 2 == 0 else Color("#2b3346")
	_round(Rect2(panel.position + Vector2(0, 6), panel.size), 22.0, Color(0, 0, 0, 0.3))
	_round(panel, 22.0, rim)
	_round(panel.grow(-5.0), 18.0, Color("#4a5670"))
	for i: int in n:
		_world.draw_circle(hold_slot(i) + Vector2(dx, 0), R + 5.0, Color(0, 0, 0, 0.3))
	for j: int in hold.size():
		var id: int = int(hold[j]["id"])
		draw_screw(_world, int(hold[j]["color"]), (_pos.get(id, hold_slot(j)) as Vector2) + Vector2(dx, 0), 0.9, float(_spin.get(id, 0.0)))
