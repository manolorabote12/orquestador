extends Node3D
## Conduccion 3D por la ciudad: botones de girar a la izquierda, acelerar y frenar a la derecha.
## Una flecha te dice a donde ir: recoge el paquete (luz amarilla) y entregalo (luz verde) antes de
## que se acabe el tiempo. Reglas, coche, trafico, bot y analizador en drive_map.gd.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const M = preload("res://kit/drive/drive_map.gd")
const CAR_COLS: Array[Color] = [Color("#e53935"), Color("#1e88e5"), Color("#fdd835"), Color("#43a047"), Color("#fb8c00"), Color("#8e24aa"), Color("#eceff1"), Color("#263238")]

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

var _font: Font
var _cam: Camera3D
var _car: Node3D
var _wheels: Array[Node3D] = []
var _traffic: Array = []
var _beacon: Node3D
var _beacon_mat: StandardMaterial3D
var _hud: Control
var _time_lbl: Label
var _jobs_lbl: Label
var _arrow: Control
var _info: Label
var _bot: bool = false
var _t: float = 0.0
var _steer: float = 0.0
var _gas: float = 0.0
var _held: Dictionary = {}
var _cam_a: float = 0.0
var _shake: float = 0.0


func _ready() -> void:
	level = Kit.current_level()
	par = float(level.get("par", 120))
	_font = UI.theme.get_font("font", "Label") if UI.theme != null else ThemeDB.fallback_font
	_reset()
	_build_env()
	_build_city()
	_build_cars()
	_build_hud()
	_cam_a = float(st["car"]["a"])
	_sync(1.0)
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "drive", "jobs": (st["jobs"] as Array).size()})


func bot_script() -> String:
	return "res://qa/drive_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(4.0, 3.0)


func wants_backdrop() -> bool:
	return false


func _reset() -> void:
	finished = false
	failed = false
	st = M.new_state(level)
	coins = 0
	coins_total = (st["jobs"] as Array).size()
	time_in_level = 0.0


static func mat(col: Color, emission: float = 0.0, unshaded: bool = false) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.8
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emission
	if col.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _box(size: Vector3, col: Color, at: Vector3, parent: Node3D = null, emission: float = 0.0) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var b: BoxMesh = BoxMesh.new()
	b.size = size
	b.material = mat(col, emission)
	mi.mesh = b
	mi.position = at
	(parent if parent != null else self).add_child(mi)
	return mi


static func to3(p: Vector2, y: float = 0.0) -> Vector3:
	return Vector3(p.x, y, p.y)


# ------------------------------------------------------------------ ciudad

func _build_env() -> void:
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sm: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("#3a7bd5")
	sm.sky_horizon_color = Color("#cfe6ff")
	sm.ground_horizon_color = Color("#cfe6ff")
	sm.ground_bottom_color = Color("#566573")
	var sky: Sky = Sky.new()
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.28
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	sun.light_energy = 0.45
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	add_child(sun)
	_cam = Camera3D.new()
	_cam.fov = 62.0
	_cam.far = 500.0
	add_child(_cam)
	_cam.make_current()


## Fachada con ventanas (textura hecha en el codigo).
func _facade() -> ImageTexture:
	var img: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y: int in 32:
		for x: int in 32:
			var win: bool = (x % 8) >= 2 and (x % 8) <= 5 and (y % 8) >= 2 and (y % 8) <= 5
			img.set_pixel(x, y, Color(0.55, 0.7, 0.85) if win else Color.WHITE)
	return ImageTexture.create_from_image(img)


func _build_city() -> void:
	var w: int = int(st["w"])
	var h: int = int(st["h"])
	var T: float = M.TILE
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = w * 97 + h * 7 + int(st["rng"].seed) % 1000
	_box(Vector3(w * T + 200.0, 0.2, h * T + 200.0), Color("#7d8a79"), Vector3(w * T * 0.5, -0.15, h * T * 0.5))
	var facade: ImageTexture = _facade()
	var trees: Array[Vector3] = []
	for y: int in h:
		for x: int in w:
			var c: String = M.cell(st, x, y)
			var at: Vector3 = Vector3((x + 0.5) * T, 0, (y + 0.5) * T)
			if M.road(st, x, y):
				_box(Vector3(T, 0.06, T), Color("#3b3f45"), at + Vector3(0, -0.02, 0))
				## Lineas discontinuas en el centro de cada tramo.
				var horiz: bool = M.road(st, x - 1, y) or M.road(st, x + 1, y)
				var vert: bool = M.road(st, x, y - 1) or M.road(st, x, y + 1)
				if horiz and not vert:
					for k: int in 2:
						_box(Vector3(2.0, 0.02, 0.18), Color("#f5f5f5"), at + Vector3(-2.5 + 5.0 * float(k), 0.03, 0))
				elif vert and not horiz:
					for k2: int in 2:
						_box(Vector3(0.18, 0.02, 2.0), Color("#f5f5f5"), at + Vector3(0, 0.03, -2.5 + 5.0 * float(k2)))
			elif c == "p":
				_box(Vector3(T, 0.2, T), Color("#4c8f3a"), at + Vector3(0, 0.05, 0))
				for k3: int in 2:
					trees.append(at + Vector3(rng.randf_range(-3.0, 3.0), 0, rng.randf_range(-3.0, 3.0)))
			else:
				## Acera y edificio de altura y color variados.
				_box(Vector3(T, 0.25, T), Color("#b0aba0"), at + Vector3(0, 0.1, 0))
				var hgt: float = rng.randf_range(8.0, 28.0)
				var col: Color = Color.from_hsv(rng.randf_range(0.0, 1.0), rng.randf_range(0.1, 0.35), rng.randf_range(0.6, 0.9))
				var b: MeshInstance3D = _box(Vector3(T - 1.6, hgt, T - 1.6), col, at + Vector3(0, hgt * 0.5 + 0.2, 0))
				var bm: StandardMaterial3D = (b.mesh as BoxMesh).material
				bm.albedo_texture = facade
				bm.uv1_scale = Vector3(1.0, hgt / 8.0, 1.0)
				_box(Vector3(T - 1.2, 0.4, T - 1.2), col.darkened(0.3), at + Vector3(0, hgt + 0.4, 0))
	## Anillo de edificios alrededor: la ciudad no se acaba de golpe.
	for y3: int in range(-2, h + 2):
		for x3: int in range(-2, w + 2):
			if x3 >= 0 and x3 < w and y3 >= 0 and y3 < h:
				continue
			var at3: Vector3 = Vector3((x3 + 0.5) * T, 0, (y3 + 0.5) * T)
			var hgt3: float = rng.randf_range(10.0, 34.0)
			var col3: Color = Color.from_hsv(rng.randf_range(0.0, 1.0), rng.randf_range(0.1, 0.3), rng.randf_range(0.55, 0.85))
			var b3: MeshInstance3D = _box(Vector3(T - 1.0, hgt3, T - 1.0), col3, at3 + Vector3(0, hgt3 * 0.5, 0))
			var bm3: StandardMaterial3D = (b3.mesh as BoxMesh).material
			bm3.albedo_texture = facade
			bm3.uv1_scale = Vector3(1.0, hgt3 / 8.0, 1.0)
	for tp: Vector3 in trees:
		_box(Vector3(0.4, 2.0, 0.4), Color("#6b4a2b"), tp + Vector3(0, 1.0, 0))
		var crown: MeshInstance3D = MeshInstance3D.new()
		var sp: SphereMesh = SphereMesh.new()
		sp.radius = 1.6
		sp.height = 3.0
		sp.material = mat(Color("#2e7d32"))
		crown.mesh = sp
		crown.position = tp + Vector3(0, 3.0, 0)
		add_child(crown)
	## Baliza del sitio al que ir.
	_beacon = Node3D.new()
	_beacon.name = "Beacon"
	add_child(_beacon)
	var beam: MeshInstance3D = MeshInstance3D.new()
	var cy: CylinderMesh = CylinderMesh.new()
	cy.top_radius = 2.6
	cy.bottom_radius = 2.6
	cy.height = 26.0
	_beacon_mat = mat(Color(1.0, 0.85, 0.2, 0.32), 1.5, true)
	_beacon_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cy.material = _beacon_mat
	beam.mesh = cy
	beam.position = Vector3(0, 13.0, 0)
	_beacon.add_child(beam)
	var ring: MeshInstance3D = MeshInstance3D.new()
	var tm: TorusMesh = TorusMesh.new()
	tm.inner_radius = 3.6
	tm.outer_radius = 4.2
	tm.material = _beacon_mat
	ring.mesh = tm
	ring.scale = Vector3(1, 0.15, 1)
	ring.position = Vector3(0, 0.1, 0)
	_beacon.add_child(ring)


func _make_car(col: Color, me: bool) -> Node3D:
	var root: Node3D = Node3D.new()
	add_child(root)
	_box(Vector3(1.9, 0.7, 4.2), col, Vector3(0, 0.6, 0), root)
	_box(Vector3(1.7, 0.6, 2.2), col.lightened(0.15), Vector3(0, 1.2, 0.2), root)
	_box(Vector3(1.6, 0.45, 0.05), Color("#9fd3ff"), Vector3(0, 1.2, -0.92), root)
	_box(Vector3(0.4, 0.15, 0.05), Color("#fff7c2"), Vector3(-0.6, 0.65, -2.11), root, 1.5)
	_box(Vector3(0.4, 0.15, 0.05), Color("#fff7c2"), Vector3(0.6, 0.65, -2.11), root, 1.5)
	_box(Vector3(0.4, 0.15, 0.05), Color("#ff3030"), Vector3(-0.6, 0.65, 2.11), root, 1.0)
	_box(Vector3(0.4, 0.15, 0.05), Color("#ff3030"), Vector3(0.6, 0.65, 2.11), root, 1.0)
	for wx: float in [-0.95, 0.95]:
		for wz: float in [-1.35, 1.35]:
			var wh: Node3D = Node3D.new()
			wh.position = Vector3(wx, 0.38, wz)
			var cy: CylinderMesh = CylinderMesh.new()
			cy.top_radius = 0.38
			cy.bottom_radius = 0.38
			cy.height = 0.3
			cy.material = mat(Color("#1b1b1b"))
			var mi: MeshInstance3D = MeshInstance3D.new()
			mi.mesh = cy
			mi.rotation_degrees = Vector3(0, 0, 90)
			wh.add_child(mi)
			root.add_child(wh)
			if me:
				_wheels.append(wh)
	if me:
		## Paquete en el techo cuando lo llevas.
		var box: MeshInstance3D = _box(Vector3(0.9, 0.6, 0.9), Color("#c58b4f"), Vector3(0, 1.85, 0.4), root)
		box.name = "Parcel"
	return root


func _build_cars() -> void:
	_car = _make_car(Kit.color("accent", Color("#ff7043")), true)
	_car.name = "Car"
	for o: Dictionary in st["traffic"]:
		_traffic.append(_make_car(CAR_COLS[int(o["col"]) % CAR_COLS.size()], false))


# ------------------------------------------------------------------ interfaz

func _build_hud() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "Hud"
	layer.layer = 20
	add_child(layer)
	_hud = Control.new()
	_hud.theme = UI.theme
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_hud)
	var safe: MarginContainer = UI.safe_root(_hud, 14.0)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col: VBoxContainer = VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(col)
	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top)
	_jobs_lbl = Label.new()
	_jobs_lbl.name = "Jobs"
	_jobs_lbl.add_theme_font_size_override("font_size", 28)
	_jobs_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_jobs_lbl.add_theme_constant_override("outline_size", 6)
	top.add_child(_jobs_lbl)
	_time_lbl = Label.new()
	_time_lbl.name = "Time"
	_time_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_time_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time_lbl.add_theme_font_size_override("font_size", 46)
	_time_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_time_lbl.add_theme_constant_override("outline_size", 8)
	top.add_child(_time_lbl)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)
	_arrow = Control.new()
	_arrow.name = "Arrow"
	_arrow.custom_minimum_size = Vector2(0, 110)
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow.draw.connect(_draw_arrow)
	col.add_child(_arrow)
	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 30)
	_info.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_info.add_theme_constant_override("outline_size", 8)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_info)
	_say(Kit.text("dr_hint", "Recoge el paquete: sigue la flecha"), Color("#ffd23f"))
	## Pedales y volante.
	_pedal("BtnLeft", "\u25c0", Vector2(20, -220), Vector2(140, 140), "left", Color("#4fc3f7"), false)
	_pedal("BtnRight", "\u25b6", Vector2(175, -220), Vector2(140, 140), "right", Color("#4fc3f7"), false)
	_pedal("BtnGas", Kit.text("dr_gas", "Gas"), Vector2(-175, -290), Vector2(155, 210), "gas", Color("#5ad17a"), true)
	_pedal("BtnBrake", Kit.text("dr_brake", "Freno"), Vector2(-340, -220), Vector2(150, 140), "brake", Color("#ff6b6b"), true)


func _pedal(nm: String, text: String, off: Vector2, size: Vector2, key: String, col: Color, right: bool) -> void:
	var b: Button = UI.make_button(text, true)
	b.name = nm
	b.self_modulate = col
	b.add_theme_font_size_override("font_size", 40)
	if right:
		b.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	else:
		b.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	b.offset_left = off.x
	b.offset_top = off.y
	b.offset_right = off.x + size.x
	b.offset_bottom = off.y + size.y
	b.button_down.connect(func() -> void:
		_held[key] = true
		_bot = false)
	b.button_up.connect(func() -> void: _held.erase(key))
	_hud.add_child(b)


## Flecha hacia el objetivo (girada segun hacia donde mira el coche) y los metros que faltan.
func _draw_arrow() -> void:
	var tg: Vector2i = M.target(st)
	if tg.x < 0:
		return
	var car: Dictionary = st["car"]
	var to: Vector2 = M.tcenter(tg) - (car["p"] as Vector2)
	var ang: float = atan2(-to.x, -to.y) - float(car["a"])
	var c: Vector2 = Vector2(_arrow.size.x * 0.5, 55.0)
	var col: Color = Color("#5ad17a") if bool(st["carrying"]) else Color("#ffd23f")
	var d: Vector2 = Vector2(0, -1).rotated(-ang)
	var side: Vector2 = Vector2(-d.y, d.x)
	_arrow.draw_colored_polygon(PackedVector2Array([c + d * 44.0, c - d * 22.0 + side * 28.0, c - d * 8.0, c - d * 22.0 - side * 28.0]), col)
	_arrow.draw_string(_font, Vector2(c.x + 60.0, c.y + 10.0), "%d m" % int(to.length()), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE)


func _say(text: String, col: Color) -> void:
	if fast or _info == null:
		return
	_info.text = text
	_info.add_theme_color_override("font_color", col)
	_info.modulate.a = 1.0
	var tw: Tween = _info.create_tween()
	tw.tween_interval(1.8)
	tw.tween_property(_info, "modulate:a", 0.0, 0.5)


# ------------------------------------------------------------------ bucle

func can_act() -> bool:
	return not finished and is_inside_tree() and not get_tree().paused


func bot_step() -> void:
	_bot = true


func _sfx(n: String, vol: float = -10.0, pitch: float = 1.0) -> void:
	if not fast:
		Audio.play(n, 0.05, vol, pitch)


func _physics_process(delta: float) -> void:
	_t += delta
	if finished:
		return
	if fast and auto_retry:
		_bot = true
	var steps: int = 4 if fast else 1
	for k: int in steps:
		if finished or get_tree().paused:
			break
		var inp: Dictionary
		if _bot:
			inp = M.bot_control(st)
		else:
			var steer: float = (1.0 if _held.has("right") else 0.0) - (1.0 if _held.has("left") else 0.0)
			var gas: float = (1.0 if _held.has("gas") else 0.0) - (1.0 if _held.has("brake") else 0.0)
			var keys: Vector2 = Input.get_vector("move_left", "move_right", "move_down", "move_up")
			if keys.length() > 0.1:
				steer = keys.x
				gas = keys.y
			inp = {"steer": steer, "gas": gas}
		M.step(st, inp, delta)
		time_in_level += delta
		_events()
		if bool(st["over"]):
			_end()
			break
	_sync(delta)


func _events() -> void:
	for e: Dictionary in st["events"]:
		match str(e["kind"]):
			"pickup":
				_sfx("ui_reward", -6.0)
				Juice.vibrate(25)
				_say(Kit.text("dr_pickup", "\u00a1Paquete recogido! Ll\u00e9valo a la luz verde"), Color("#5ad17a"))
			"deliver":
				coins = int(st["done"])
				_sfx("ui_coin", -4.0)
				Juice.vibrate(40)
				_say(Kit.text("dr_deliver", "\u00a1Entregado! +%d s de sobra") % int(e["bonus"]), Color("#ffd23f"))
			"bump":
				_sfx("stomp", -10.0)
				_shake = 0.3
			"crash":
				_sfx("hurt", -8.0)
				Juice.vibrate(30)
				_shake = 0.5
	(st["events"] as Array).clear()


func _sync(delta: float) -> void:
	var car: Dictionary = st["car"]
	var p: Vector2 = car["p"]
	var a: float = float(car["a"])
	_car.position = to3(p)
	_car.rotation.y = a
	var v: float = float(car["v"])
	for wh: Node3D in _wheels:
		wh.rotate_object_local(Vector3.RIGHT, -v * delta / 0.38)
	(_car.get_node("Parcel") as Node3D).visible = bool(st["carrying"])
	var traffic: Array = st["traffic"]
	for k: int in mini(traffic.size(), _traffic.size()):
		var o: Dictionary = traffic[k]
		(_traffic[k] as Node3D).position = to3(o["q"])
		(_traffic[k] as Node3D).rotation.y = float(o["a"])
	var tg: Vector2i = M.target(st)
	_beacon.visible = tg.x >= 0
	if tg.x >= 0:
		_beacon.position = to3(M.tcenter(tg))
		_beacon_mat.albedo_color = Color(0.3, 1.0, 0.45, 0.32) if bool(st["carrying"]) else Color(1.0, 0.85, 0.2, 0.32)
		_beacon_mat.emission = _beacon_mat.albedo_color
	## Camara de persecucion: detras del coche, girando con suavidad.
	_cam_a = lerp_angle(_cam_a, a, minf(1.0, delta * 3.5)) if not fast and delta < 0.5 else a
	var back: Vector2 = -M.dir_of(_cam_a) * (9.0 + absf(v) * 0.15)
	var want: Vector3 = to3(p + back, 4.6 + absf(v) * 0.05)
	_cam.position = _cam.position.lerp(want, minf(1.0, delta * 8.0)) if not fast and delta < 0.5 else want
	_cam.look_at(to3(p + M.dir_of(_cam_a) * 4.0, 1.2), Vector3.UP)
	_cam.fov = 62.0 + absf(v) * 0.6
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta)
		_cam.position += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake * 0.4
	var left: float = maxf(0.0, float(st["left"]))
	_time_lbl.text = "%d" % ceili(left)
	_time_lbl.add_theme_color_override("font_color", Color("#ff6b6b") if left < 10.0 else Color.WHITE)
	_jobs_lbl.text = Kit.text("dr_jobs", "Repartos %d/%d") % [int(st["done"]), (st["jobs"] as Array).size()]
	_arrow.queue_redraw()
	Audio.set_intensity(clampf(0.5 + absf(v) / M.MAX_V * 0.4 + (0.2 if left < 10.0 else 0.0), 0.0, 1.0))


# ------------------------------------------------------------------ final

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()


func _end() -> void:
	if bool(st["won"]):
		_finish()
	else:
		_lose()


func _finish() -> void:
	if finished:
		return
	finished = true
	coins = int(st["done"])
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = maxi(1, 10000 - int(time_in_level) * 15 - int(st["crashes"]) * 200)
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "time": snappedf(time_in_level, 0.1), "crashes": int(st["crashes"])})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


func stars_earned() -> int:
	var c: int = int(st.get("crashes", 0))
	if c > 6:
		return 1
	return 3 if c <= 2 and (par <= 0.0 or time_in_level <= par) else 2


func _lose() -> void:
	if finished:
		return
	finished = true
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "time", "done": int(st["done"])})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("dr_lost", "\u00a1Se acab\u00f3 el tiempo!"),
		Kit.text("dr_fail_hint", "Frena antes de las curvas y no choques: cada golpe te para."))
	p.closed.connect(retry)


## Segunda oportunidad (FailPanel, con anuncio): medio tiempo de reparto mas para este encargo.
func revive() -> void:
	st["left"] = float(st["per_job"]) * 0.5
	st["over"] = false
	finished = false
	failed = false


func revive_text() -> String:
	return Kit.text("revive_secs", "+{n} segundos").format({"n": int(float(st.get("per_job", 30.0)) * 0.5)})


func retry() -> void:
	_reset()
	_cam_a = float(st["car"]["a"])
	_sync(1.0)


func open_pause() -> void:
	if finished or get_tree().paused or get_node_or_null("PauseMenu") != null:
		return
	_held.clear()
	PauseMenu.open(self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_inside_tree() and not UI.test_mode:
			open_pause()


func bot_state() -> Dictionary:
	return {"pos": (st.get("car", {}) as Dictionary).get("p", Vector2.ZERO), "deaths": deaths, "coins": coins, "finished": finished,
		"failed": failed, "time": time_in_level, "done": int(st.get("done", 0)), "crashes": int(st.get("crashes", 0))}
