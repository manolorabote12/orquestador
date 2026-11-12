extends Node2D
## Genero carreras: coches vistos desde arriba en una carretera con curvas, contra 3 rivales.
## 1 - El coche acelera solo; arrastra el dedo (o flechas) para cambiar de carril.
## 2 - Conos y coches lentos frenan mucho al chocar; salirse del asfalto frena.
## 3 - Las monedas cargan el turbo y las placas de turbo lo dan al momento. Boton de turbo.
## 4 - Al cruzar la meta cuenta tu puesto: 1.o 3 estrellas, 2.o 2, 3.o 1. Cuarto: reintentar.
## El nivel (game.json -> levels[i]) trae: map (una fila por tramo, ver RaceTrack) y rival_speed.

const ROW: float = 96.0
const LANE_W: float = 110.0
const MAX_SPEED: float = 640.0
const CAR_SIZE: Vector2 = Vector2(58.0, 100.0)
const RIVAL_COLORS: Array[Color] = [Color("#e5533d"), Color("#3f8efc"), Color("#4cc26a")]

var rows: Array[String] = []
var level: Dictionary = {}
var track_len: float = 0.0
var finished: bool = false
var failed: bool = false
var started: bool = false
var deaths: int = 0
var time_in_level: float = 0.0
var coins: int = 0
var coins_total: int = 0
var crashes: int = 0
var place: int = 4
var fast: bool = false
var auto_retry: bool = false
var bot_lat: float = INF
var result_panel: ResultPanel

## Jugador: d = distancia recorrida (px), lat = posicion lateral respecto al centro (px).
var d: float = 0.0
var lat: float = 0.0
var speed: float = 0.0
var nitro: float = 0.0
var boost_left: float = 0.0
var stun_left: float = 0.0
var rivals: Array[Dictionary] = []
var items: Array[Dictionary] = []

var _road: Node2D
var _world: Node2D
var _car: Node2D
var _camera: Camera2D
var _countdown: float = 2.4
var _drag_from: float = 0.0
var _drag_lat: float = 0.0
var _dragging: bool = false
var _hud: CanvasLayer
var _place_label: Label
var _coins_label: Label
var _progress: Control
## Lineas de velocidad (sobre todo con turbo): la critica pedia sensacion de rapidez (12 nov).
var _speed_fx: Control
var _nitro_ready_was: bool = false
var _nitro_fill: ColorRect
var _nitro_btn: Button
var _go_label: Label
var _attempt: int = 0
var _center_cache: PackedFloat32Array = PackedFloat32Array()
## Vista 3D (game.json -> "view": "3d"): la misma carrera dibujada en 3D.
var view3d: Race3DView = null


func _ready() -> void:
	level = Kit.current_level()
	for r: Variant in level.get("map", []):
		rows.append(str(r))
	track_len = float(rows.size()) * ROW
	RenderingServer.set_default_clear_color(Kit.color("sky", Color("#1b2a41")))
	_build_centers()
	_world = Node2D.new()
	_world.name = "World"
	add_child(_world)
	_road = RoadDrawer.new()
	_road.set("game", self)
	_world.add_child(_road)
	_camera = Camera2D.new()
	_world.add_child(_camera)
	_camera.make_current()
	Juice.register_camera(_camera)
	_build_hud()
	if str(Kit.param("view", "2d")) == "3d":
		view3d = Race3DView.new()
		add_child(view3d)
		view3d.setup(self)
		_world.visible = false
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "race", "rows": rows.size(), "view": "3d" if view3d != null else "2d"})


## Bandera para los bots: este juego se juega con RaceBot.
func race_bot_step() -> void:
	pass


## Centro de la carretera (x) en cada fila: las curvas lo desplazan poco a poco.
func _build_centers() -> void:
	_center_cache.resize(rows.size() + 1)
	var x: float = 0.0
	var v: float = 0.0
	for i: int in rows.size() + 1:
		var c: String = rows[mini(i, rows.size() - 1)][0]
		var target: float = -26.0 if c == "<" else (26.0 if c == ">" else 0.0)
		v = lerpf(v, target, 0.15)
		x += v
		_center_cache[i] = x


func center_at(dist: float) -> float:
	var f: float = clampf(dist / ROW, 0.0, float(rows.size()))
	var i: int = int(floor(f))
	var j: int = mini(i + 1, rows.size())
	return lerpf(_center_cache[i], _center_cache[j], f - float(i))


func curve_at(dist: float) -> float:
	var i: int = clampi(int(dist / ROW), 0, rows.size() - 1)
	var c: String = rows[i][0]
	return -1.0 if c == "<" else (1.0 if c == ">" else 0.0)


func lane_lat(l: int) -> float:
	return (float(l) - 1.5) * LANE_W


func lane_of(lat_px: float) -> int:
	return clampi(int(round(lat_px / LANE_W + 1.5)), 0, 3)


func world(dist: float, lat_px: float) -> Vector2:
	return Vector2(center_at(dist) + lat_px, -dist)


# ------------------------------------------------------------------ montaje

func _reset() -> void:
	for n: Node in _world.get_children():
		if n != _road and n != _camera:
			n.queue_free()
	d = 0.0
	lat = lane_lat(1)
	speed = 0.0
	nitro = 0.0
	boost_left = 0.0
	stun_left = 0.0
	coins = 0
	crashes = 0
	failed = false
	finished = false
	started = false
	_countdown = 0.0 if fast else 2.4
	place = 4
	items.clear()
	coins_total = 0
	for i: int in rows.size():
		for l: int in 4:
			var ch: String = rows[i][l + 1]
			if ch == ".":
				continue
			var n: Node2D = _make_item(ch)
			var it: Dictionary = {"kind": ch, "d": (float(i) + 0.5) * ROW, "lat": lane_lat(l), "node": n, "alive": true}
			items.append(it)
			_world.add_child(n)
			n.position = world(it["d"], it["lat"])
			if ch == "C":
				coins_total += 1
	rivals.clear()
	var names: Array = Kit.param("texts.rivals", ["Rojo", "Azul", "Verde"])
	var rs: float = float(level.get("rival_speed", 0.9))
	for k: int in 3:
		var car: Node2D = make_car(RIVAL_COLORS[k], false)
		_world.add_child(car)
		var tag: Label = Label.new()
		tag.text = str(names[k % names.size()])
		tag.add_theme_font_size_override("font_size", 22)
		tag.position = Vector2(-60.0, -CAR_SIZE.y * 0.5 - 34.0)
		tag.size = Vector2(120.0, 28.0)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		car.add_child(tag)
		rivals.append({"d": ROW * (1.4 + 1.3 * float(k)), "lat": lane_lat([0, 2, 3][k]), "speed": 0.0,
			"top": MAX_SPEED * rs * (1.0 - 0.025 * float(k)), "node": car, "done_at": -1.0})
	_car = make_car(Skins.recolor(Kit.color("accent", Color.ORANGE)), true)
	_world.add_child(_car)
	if view3d != null:
		view3d.rebuild()
	_place_cars()
	_update_hud()


## Coche dibujado (sin arte): carroceria redondeada, parabrisas, ruedas y franja.
static func make_car(col: Color, player_car: bool) -> Node2D:
	var n: Node2D = Node2D.new()
	var w: float = CAR_SIZE.x * 0.5
	var h: float = CAR_SIZE.y * 0.5
	for p: Vector2 in [Vector2(-w, -h * 0.55), Vector2(w, -h * 0.55), Vector2(-w, h * 0.55), Vector2(w, h * 0.55)]:
		var wheel: Polygon2D = Polygon2D.new()
		wheel.color = Color(0.08, 0.08, 0.1)
		wheel.polygon = PackedVector2Array([Vector2(-7, -14), Vector2(7, -14), Vector2(7, 14), Vector2(-7, 14)])
		wheel.position = p
		n.add_child(wheel)
	var body: Polygon2D = Polygon2D.new()
	body.name = "Body"
	body.color = col
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in 20:
		var a: float = TAU * float(i) / 20.0
		pts.append(Vector2(cos(a) * w * 0.98, sin(a) * h) * Vector2(1.0, 1.0).lerp(Vector2(1.08, 1.0), absf(sin(a))))
	body.polygon = pts
	n.add_child(body)
	var glass: Polygon2D = Polygon2D.new()
	glass.color = Color(0.75, 0.9, 1.0, 0.85)
	glass.polygon = PackedVector2Array([Vector2(-w * 0.7, -h * 0.35), Vector2(w * 0.7, -h * 0.35), Vector2(w * 0.6, -h * 0.05), Vector2(-w * 0.6, -h * 0.05)])
	n.add_child(glass)
	if player_car:
		var stripe: Polygon2D = Polygon2D.new()
		stripe.color = Color(1, 1, 1, 0.85)
		stripe.polygon = PackedVector2Array([Vector2(-5, -h * 0.95), Vector2(5, -h * 0.95), Vector2(5, h * 0.95), Vector2(-5, h * 0.95)])
		n.add_child(stripe)
	return n


func _make_item(ch: String) -> Node2D:
	var n: Node2D = Node2D.new()
	match ch:
		"C":
			var entry: Dictionary = Kit.sprite_entry(str(Kit.param("art.coin", "moneda")))
			if not entry.is_empty():
				n.add_child(SpriteKit.animado(entry, 44.0, "spin", false))
			else:
				var c: Polygon2D = Polygon2D.new()
				c.color = Kit.color("coin", Color("#f6cf7a"))
				c.polygon = LevelBuilder._circle(18.0, 14)
				n.add_child(c)
		"N":
			var pad: Polygon2D = Polygon2D.new()
			pad.color = Color(0.3, 0.85, 1.0, 0.85)
			pad.polygon = PackedVector2Array([Vector2(-40, 20), Vector2(0, -26), Vector2(40, 20), Vector2(0, 2)])
			n.add_child(pad)
		"O":
			var cone: Polygon2D = Polygon2D.new()
			cone.color = Color("#ff8a1f")
			cone.polygon = PackedVector2Array([Vector2(0, -26), Vector2(20, 18), Vector2(-20, 18)])
			n.add_child(cone)
			var band: Polygon2D = Polygon2D.new()
			band.color = Color(1, 1, 1)
			band.polygon = PackedVector2Array([Vector2(-9, -2), Vector2(9, -2), Vector2(12, 5), Vector2(-12, 5)])
			n.add_child(band)
		"T":
			n.add_child(make_car(Color(0.55, 0.58, 0.62), false))
	return n


# ------------------------------------------------------------------ HUD

func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.name = "Hud"
	_hud.layer = 20
	add_child(_hud)
	var root: Control = Control.new()
	root.theme = UI.theme
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(root)
	_speed_fx = Control.new()
	_speed_fx.name = "SpeedLines"
	_speed_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	_speed_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speed_fx.draw.connect(_draw_speed_lines)
	root.add_child(_speed_fx)
	var safe: MarginContainer = UI.safe_root(root, 20.0)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col: VBoxContainer = VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 8)
	safe.add_child(col)
	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 14)
	col.add_child(top)
	_place_label = Label.new()
	_place_label.name = "Place"
	_place_label.theme_type_variation = "HeaderLabel"
	top.add_child(_place_label)
	top.add_child(UiIcon.make("coin", Kit.color("coin", UI.colors["acento"]), 40.0))
	_coins_label = Label.new()
	_coins_label.name = "Coins"
	_coins_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_coins_label)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)
	_progress = Control.new()
	_progress.name = "Progress"
	_progress.custom_minimum_size = Vector2(0.0, 16.0)
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress.draw.connect(_draw_progress)
	col.add_child(_progress)
	_go_label = Label.new()
	_go_label.name = "Go"
	_go_label.theme_type_variation = "TitleLabel"
	_go_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_go_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_go_label)
	var grow: Control = Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(grow)
	var bottom: HBoxContainer = HBoxContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.alignment = BoxContainer.ALIGNMENT_END
	col.add_child(bottom)
	_nitro_btn = UI.make_button(Kit.text("nitro", "Turbo"), true, "")
	_nitro_btn.name = "BtnNitro"
	_nitro_btn.custom_minimum_size = Vector2(220.0, 120.0)
	_nitro_btn.add_theme_font_size_override("font_size", 40)
	_nitro_btn.pressed.connect(use_nitro)
	bottom.add_child(_nitro_btn)
	_nitro_fill = ColorRect.new()
	_nitro_fill.color = Color(0.3, 0.85, 1.0, 0.55)
	_nitro_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_nitro_fill.show_behind_parent = false
	_nitro_btn.add_child(_nitro_fill)


## Rayas que salen del centro hacia los bordes: mas y mas largas cuanto mas rapido (y con turbo, doradas).
func _draw_speed_lines() -> void:
	if fast:
		return
	var k: float = clampf((speed / MAX_SPEED - 0.75) * 3.0, 0.0, 1.0)
	if boost_left > 0.0:
		k = 1.0
	if k <= 0.02:
		return
	var sz: Vector2 = _speed_fx.size
	var c: Vector2 = Vector2(sz.x * 0.5, sz.y * 0.42)
	var col: Color = Color(1.0, 0.85, 0.4) if boost_left > 0.0 else Color(1, 1, 1)
	var n: int = 10 + int(k * 14.0)
	var t: float = time_in_level
	for i: int in n:
		var a: float = TAU * float(i) / float(n) + sin(float(i) * 12.9898) * 0.3
		var ph: float = fposmod(t * (1.6 + k) + float(i) * 0.37, 1.0)
		var dir: Vector2 = Vector2(cos(a), sin(a))
		var r0: float = sz.length() * (0.28 + 0.3 * ph)
		var r1: float = r0 + sz.length() * (0.05 + 0.1 * k)
		_speed_fx.draw_line(c + dir * r0, c + dir * r1, Color(col, 0.10 + 0.22 * k * (1.0 - ph)), 3.0 + 3.0 * k, true)


func _draw_progress() -> void:
	var w: float = _progress.size.x
	_progress.draw_rect(Rect2(0, 6, w, 4), UI.colors["borde"])
	for k: int in rivals.size():
		var x: float = w * clampf(float(rivals[k]["d"]) / track_len, 0.0, 1.0)
		_progress.draw_circle(Vector2(x, 8), 7.0, RIVAL_COLORS[k])
	_progress.draw_circle(Vector2(w * clampf(d / track_len, 0.0, 1.0), 8), 9.0, Kit.color("accent", Color.ORANGE))


func _update_hud() -> void:
	if _place_label == null:
		return
	_place_label.text = "%d.\u00ba/4" % place
	_coins_label.text = "%d/%d" % [coins, coins_total]
	_nitro_btn.disabled = nitro < 1.0 or boost_left > 0.0
	## Turbo listo: el boton da un salto para que se note.
	var listo: bool = not _nitro_btn.disabled
	if listo and not _nitro_ready_was and not fast:
		_nitro_btn.pivot_offset = _nitro_btn.size * 0.5
		var tw: Tween = _nitro_btn.create_tween()
		tw.tween_property(_nitro_btn, "scale", Vector2(1.15, 1.15), 0.12)
		tw.tween_property(_nitro_btn, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)
		Audio.play("coin", 0.05, -8.0)
	_nitro_ready_was = listo
	_nitro_fill.position = Vector2(4, 4)
	_nitro_fill.size = Vector2((_nitro_btn.size.x - 8.0) * clampf(nitro, 0.0, 1.0), _nitro_btn.size.y - 8.0)
	_progress.queue_redraw()
	if _speed_fx != null:
		_speed_fx.queue_redraw()


# ------------------------------------------------------------------ carrera

func _physics_process(delta: float) -> void:
	if finished or failed or get_tree().paused:
		return
	time_in_level += delta
	if not started:
		_countdown -= delta
		_go_label.text = str(int(ceil(_countdown))) if _countdown > 0.0 else Kit.text("go", "Ya")
		if _countdown <= 0.0:
			started = true
			_hide_go()
		_place_cars()
		return
	_drive(delta)
	_drive_rivals(delta)
	_check_items()
	_place_cars()
	place = 1
	for r: Dictionary in rivals:
		## Quien ya cruzo la meta va delante aunque se haya parado justo detras de la linea.
		if float(r["done_at"]) >= 0.0 or float(r["d"]) > d:
			place += 1
	_update_hud()
	if d >= track_len:
		_finish()


func _hide_go() -> void:
	if fast:
		_go_label.text = ""
		return
	var tw: Tween = _go_label.create_tween()
	tw.tween_interval(0.6)
	tw.tween_callback(func() -> void: _go_label.text = "")


func steer_input() -> float:
	return Input.get_axis("move_left", "move_right")


func _drive(delta: float) -> void:
	## Direccion: el bot fija un carril; la persona arrastra o usa las flechas.
	if bot_lat != INF:
		lat = move_toward(lat, bot_lat, 560.0 * delta)
	elif _dragging:
		lat = move_toward(lat, _drag_lat, 900.0 * delta)
	else:
		lat += steer_input() * 520.0 * delta
	## Las curvas empujan hacia fuera segun la velocidad.
	lat -= curve_at(d) * 70.0 * (speed / MAX_SPEED) * delta
	lat = clampf(lat, -LANE_W * 2.4, LANE_W * 2.4)
	var top: float = MAX_SPEED
	if absf(lat) > LANE_W * 2.0:
		top *= 0.55
	if boost_left > 0.0:
		boost_left -= delta
		top *= 1.45
	if stun_left > 0.0:
		stun_left -= delta
		top *= 0.6
	top *= Mods.tune("speed")
	speed = move_toward(speed, top, (520.0 if speed < top else 900.0) * delta)
	d += speed * delta


func _drive_rivals(delta: float) -> void:
	for r: Dictionary in rivals:
		if float(r["done_at"]) >= 0.0:
			continue
		## Ligero "goma": si van muy atras aprietan un poco; muy delante, levantan.
		var gap: float = (float(r["d"]) - d) / ROW
		var top: float = float(r["top"]) * (1.05 if gap < -14.0 else (0.97 if gap > 14.0 else 1.0))
		r["speed"] = move_toward(float(r["speed"]), top, 460.0 * delta)
		r["d"] = float(r["d"]) + float(r["speed"]) * delta
		## Esquivan lo que tienen delante cambiando al carril libre mas cercano.
		var l: int = lane_of(float(r["lat"]))
		var want: int = l
		if _lane_blocked(l, float(r["d"]), 4):
			for alt: int in [l - 1, l + 1, l - 2, l + 2]:
				if alt >= 0 and alt < 4 and not _lane_blocked(alt, float(r["d"]), 4):
					want = alt
					break
		r["lat"] = move_toward(float(r["lat"]), lane_lat(want), 420.0 * delta)
		if float(r["d"]) >= track_len:
			r["done_at"] = time_in_level
	## Los coches lentos tambien avanzan.
	for it: Dictionary in items:
		if it["kind"] == "T" and bool(it["alive"]):
			it["d"] = float(it["d"]) + MAX_SPEED * 0.3 * delta


func _lane_blocked(l: int, from_d: float, ahead_rows: int) -> bool:
	for it: Dictionary in items:
		if not bool(it["alive"]) or not RaceTrack.blocked(it["kind"]):
			continue
		var dd: float = float(it["d"]) - from_d
		if dd > 0.0 and dd < ROW * float(ahead_rows) and lane_of(float(it["lat"])) == l:
			return true
	return false


func _check_items() -> void:
	for it: Dictionary in items:
		if not bool(it["alive"]):
			continue
		var dd: float = absf(float(it["d"]) - d)
		if dd > CAR_SIZE.y * 0.6 or absf(float(it["lat"]) - lat) > CAR_SIZE.x * 0.85:
			continue
		match str(it["kind"]):
			"C":
				it["alive"] = false
				(it["node"] as Node2D).visible = false
				coins += 1
				nitro = minf(nitro + 0.12, 1.0)
				if not fast:
					Audio.play("coin", 0.1, -6.0)
			"N":
				it["alive"] = false
				boost_left = maxf(boost_left, 1.4)
				if not fast:
					Audio.play("powerup", 0.05, -4.0)
			"O", "T":
				if stun_left > 0.3:
					continue
				it["alive"] = false
				(it["node"] as Node2D).modulate.a = 0.35
				speed *= 0.35
				stun_left = 0.9
				crashes += 1
				QA.log_event("crash", {"kind": it["kind"], "d": int(d / ROW)})
				if not fast:
					Audio.play("hurt")
					Juice.shake(0.35)
					Juice.vibrate(40)
	## Choque con rivales: ambos frenan un poco y se separan.
	for r: Dictionary in rivals:
		if absf(float(r["d"]) - d) < CAR_SIZE.y * 0.9 and absf(float(r["lat"]) - lat) < CAR_SIZE.x * 0.9:
			speed *= 0.97
			r["speed"] = float(r["speed"]) * 0.97
			lat += signf(lat - float(r["lat"]) + 0.01) * 4.0


func use_nitro() -> void:
	if nitro < 1.0 or boost_left > 0.0 or not started:
		return
	nitro = 0.0
	boost_left = 2.5
	Audio.play("powerup")
	if not fast:
		Juice.shake(0.25)
		Juice.vibrate(30)
	QA.log_event("nitro", {"d": int(d / ROW)})


func _place_cars() -> void:
	_car.position = world(d, lat)
	_car.rotation = clampf((steer_input() if bot_lat == INF else signf(bot_lat - lat)) * 0.12, -0.15, 0.15)
	for r: Dictionary in rivals:
		(r["node"] as Node2D).position = world(float(r["d"]), float(r["lat"]))
	for it: Dictionary in items:
		if it["kind"] == "T":
			(it["node"] as Node2D).position = world(float(it["d"]), float(it["lat"]))
	_camera.position = Vector2(center_at(d + 300.0), -d - 330.0)
	if view3d != null:
		view3d.sync()
		return
	_road.queue_redraw()


# ------------------------------------------------------------------ entrada

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()
		return
	if event.is_action_pressed("jump") or event.is_action_pressed("shoot"):
		use_nitro()
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		_dragging = mb.pressed and mb.position.y > 200.0
		_drag_from = mb.position.x
		_drag_lat = lat
	elif event is InputEventMouseMotion and _dragging:
		_drag_lat = clampf(lat + ((event as InputEventMouseMotion).position.x - _drag_from) * 1.3, -LANE_W * 2.4, LANE_W * 2.4)
		_drag_from = (event as InputEventMouseMotion).position.x


# ------------------------------------------------------------------ final

func _finish() -> void:
	if place > 3:
		_lose()
		return
	finished = true
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = (4 - place) * 1000 + coins * 50 - crashes * 100
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "place": place, "coins": coins, "crashes": crashes, "deaths": deaths, "stars": stars})
	Audio.play("win")
	Audio.play_track("victoria", false)
	_update_hud()
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": maxi(score, 0), "record": record})
	await Ads.show_interstitial("level_end")


## Estrellas segun el puesto: 1.o tres, 2.o dos, 3.o una.
func stars_earned() -> int:
	return clampi(4 - place, 1, 3)


func _lose() -> void:
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "place", "place": place, "deaths": deaths})
	if auto_retry:
		retry()
		return
	Audio.play("hurt")
	var p: FailPanel = FailPanel.open(self, Kit.text("race_lost", "Te han ganado"), Kit.text("need_podium", "Acaba entre los 3 primeros para pasar"))
	p.closed.connect(retry)


func retry() -> void:
	_attempt += 1
	_reset()


func open_pause() -> void:
	if finished or get_tree().paused or get_node_or_null("PauseMenu") != null:
		return
	_dragging = false
	PauseMenu.open(self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_inside_tree() and not UI.test_mode:
			open_pause()


func bot_state() -> Dictionary:
	return {
		"pos": Vector2(lat, d), "deaths": deaths, "coins": coins, "finished": finished, "failed": failed, "stomps": 0,
		"place": place, "crashes": crashes, "progress": clampf(d / maxf(track_len, 1.0), 0.0, 1.0),
	}
