extends Node3D
## Carreras de karts 3D: circuito con curvas, rivales, derrapes con turbo y placas de turbo.
## El kart acelera solo; botones IZQUIERDA y DERECHA para girar y DERRAPE (mantener) para coger
## las curvas y cargar el turbo. Llega en el puesto que pide el nivel para pasar.
## Objetos: las cajas de la pista dan cascara, platano o turbo; el boton OBJETO (o la tecla E) lo usa.
## En directo (Online.arena_match, hasta 4 pilotos): cada movil mueve su kart y lo manda 10 veces
## por segundo; los bots los mueve el anfitrion (la sesion mas baja); las cascaras y platanos
## cruzan la red y cada uno decide si le han dado a el. Al cruzar la meta, tu puesto entre las
## personas va al servidor (trofeos) y la carrera sigue de fondo.
## Reglas, IA, bot y analizador en kart_map.gd.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const M = preload("res://kit/kart/kart_map.gd")
const NET_RATE: float = 0.1
const NET_TIMEOUT: float = 8.0
const HOST_TIMEOUT: float = 3.0
const COLORS: Array[Color] = [Color("#3fa7ff"), Color("#e53935"), Color("#fdd835"), Color("#43a047"), Color("#8e24aa"), Color("#ff7043"), Color("#ec407a"), Color("#26c6da")]

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

var _cam: Camera3D
var _karts: Array = []
var _hud: Control
var _pos_lbl: Label
var _lap_lbl: Label
var _big: Label
var _left_btn: Button
var _right_btn: Button
var _drift_btn: Button
var _bot: bool = false
var _t: float = 0.0
var _steer_l: bool = false
var _steer_r: bool = false
var _drift_held: bool = false
var _map_pts: PackedVector2Array = PackedVector2Array()
var _map_rect: Rect2 = Rect2()
var _item_btn: Button
var _use_pressed: bool = false
var _box_nodes: Array = []
var _shot_nodes: Dictionary = {}
## En directo: sala, canal, si mueves los bots y cuando se supo de cada uno por ultima vez.
var online: Dictionary = {}
var net: RealtimeChannel = null
var host: bool = false
var reported: bool = false
var my_id: String = ""
var _send_acc: float = 0.0
var _host_sid: String = ""
var _seen: Dictionary = {}


func _ready() -> void:
	level = Kit.current_level()
	if not level.has("kart") and Kit.param("kart", null) is Dictionary:
		level = level.duplicate()
		level["kart"] = Kit.param("kart", {})
	if not Online.arena_match.is_empty():
		online = Online.arena_match.duplicate(true)
	par = float(level.get("par", 120))
	_reset()
	if not online.is_empty():
		_net_setup()
	_build_env()
	_build_track()
	_build_karts()
	_build_items()
	_build_hud()
	_sync(1.0)
	Audio.play_track("nivel")
	if not online.is_empty():
		_net_open()
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "kart", "laps": int(st["laps"]), "online": not online.is_empty()})


func bot_script() -> String:
	return "res://qa/kart_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(13.0, 3.0)


func wants_backdrop() -> bool:
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
	if not online.is_empty():
		## Misma carrera en todos los moviles: la semilla de la sala y sitio para todos en la parrilla.
		var rows2: Array = []
		for r2: Variant in level.get("map", []):
			if not (str(r2).begins_with("#") and str(r2).substr(1).is_valid_int()):
				rows2.append(r2)
		rows2.append("#%d" % int(online.get("semilla", 1)))
		lv["map"] = rows2
		lv["rivals"] = maxi(int(lv.get("rivals", 5)), (online.get("jugadores", []) as Array).size() - 1)
	st = M.new_state(lv)
	time_in_level = 0.0
	coins = 0


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


# ------------------------------------------------------------------ circuito

func _build_env() -> void:
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sm: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("#2e74c9")
	sm.sky_horizon_color = Color("#c8e4f8")
	sm.ground_horizon_color = Color("#c8e4f8")
	sm.ground_bottom_color = Color("#3c6b35")
	var sky: Sky = Sky.new()
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.27
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 35.0, 0.0)
	sun.light_energy = 0.48
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	add_child(sun)
	_cam = Camera3D.new()
	_cam.keep_aspect = Camera3D.KEEP_WIDTH
	_cam.fov = 66.0
	_cam.far = 500.0
	add_child(_cam)
	_cam.make_current()


## Asfalto: gris con grano, linea blanca en los bordes y discontinua en el centro.
static func _road_tex() -> ImageTexture:
	var img: Image = Image.create(64, 64, false, Image.FORMAT_RGB8)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 3
	for y: int in 64:
		for x: int in 64:
			var c: Color = Color("#4a4c50") * rng.randf_range(0.88, 1.0)
			if x < 3 or x > 60:
				c = Color("#eeeeee")
			if absi(x - 32) < 1 and y < 32:
				c = Color("#d8d8d8")
			img.set_pixel(x, y, Color(c.r, c.g, c.b))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func _curb_tex() -> ImageTexture:
	var img: Image = Image.create(8, 16, false, Image.FORMAT_RGB8)
	for y: int in 16:
		for x: int in 8:
			img.set_pixel(x, y, Color("#e53935") if y < 8 else Color("#fafafa"))
	return ImageTexture.create_from_image(img)


## Banda a lo largo de la linea central entre "a" y "b" metros del centro (a < b).
func _strip(nm: String, a: float, b: float, y: float, m: StandardMaterial3D, v_scale: float) -> void:
	var tr: Dictionary = st["track"]
	var line: Array = tr["line"]
	var n: int = line.size()
	var stl: SurfaceTool = SurfaceTool.new()
	stl.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in n + 1:
		var k: int = i % n
		var nrm: Vector2 = (tr["tan"][k] as Vector2).orthogonal()
		var d: float = float(tr["dist"][k]) if i < n else float(tr["length"])
		var pa: Vector2 = (line[k] as Vector2) + nrm * a
		var pb: Vector2 = (line[k] as Vector2) + nrm * b
		if i > 0:
			pass
		stl.set_normal(Vector3.UP)
		stl.set_uv(Vector2(0, d / v_scale))
		stl.add_vertex(to3(pa, y))
		stl.set_normal(Vector3.UP)
		stl.set_uv(Vector2(1, d / v_scale))
		stl.add_vertex(to3(pb, y))
	for i2: int in n:
		var o: int = i2 * 2
		stl.add_index(o)
		stl.add_index(o + 2)
		stl.add_index(o + 1)
		stl.add_index(o + 1)
		stl.add_index(o + 2)
		stl.add_index(o + 3)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = nm
	var mesh: ArrayMesh = stl.commit()
	mesh.surface_set_material(0, m)
	mi.mesh = mesh
	add_child(mi)


func _build_track() -> void:
	var tr: Dictionary = st["track"]
	var line: Array = tr["line"]
	var w: float = float(st["width"])
	var n: int = line.size()
	var road_m: StandardMaterial3D = StandardMaterial3D.new()
	road_m.albedo_texture = _road_tex()
	road_m.roughness = 0.9
	road_m.cull_mode = BaseMaterial3D.CULL_DISABLED
	road_m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_strip("Road", -w * 0.5, w * 0.5, 0.02, road_m, 8.0)
	var curb_m: StandardMaterial3D = StandardMaterial3D.new()
	curb_m.albedo_texture = _curb_tex()
	curb_m.cull_mode = BaseMaterial3D.CULL_DISABLED
	curb_m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_strip("CurbL", -w * 0.5 - 0.9, -w * 0.5, 0.03, curb_m, 3.0)
	_strip("CurbR", w * 0.5, w * 0.5 + 0.9, 0.03, curb_m, 3.0)
	## Cesped grande.
	var ground: MeshInstance3D = MeshInstance3D.new()
	var gp: PlaneMesh = PlaneMesh.new()
	gp.size = Vector2(600, 600)
	gp.material = mat(Color("#5c9e48"))
	ground.mesh = gp
	add_child(ground)
	## Barreras de neumaticos a los dos lados (rojo y blanco), con MultiMesh.
	var barrier: Array[Transform3D] = []
	var cols: Array[Color] = []
	var lim: float = w * 0.5 + 4.6
	var acc: float = 0.0
	for i: int in n:
		acc += (line[i] as Vector2).distance_to(line[(i + 1) % n])
		if acc < 2.2:
			continue
		acc = 0.0
		var nrm: Vector2 = (tr["tan"][i] as Vector2).orthogonal()
		for sgn: float in [-1.0, 1.0]:
			var bp: Vector2 = (line[i] as Vector2) + nrm * sgn * lim
			## No poner barrera encima de otro tramo de pista.
			var near: int = M.nearest(st, bp, i)
			if absf(((bp - (line[near] as Vector2)).dot((tr["tan"][near] as Vector2).orthogonal()))) < lim - 0.5 and absf(float(tr["dist"][near]) - float(tr["dist"][i])) > 20.0:
				continue
			barrier.append(Transform3D(Basis(Vector3.UP, -(tr["tan"][i] as Vector2).angle()), to3(bp, 0.45)))
			cols.append(Color("#e53935") if (barrier.size() / 2) % 2 == 0 else Color("#f5f5f5"))
	_multi("Barrier", barrier, cols, Vector3(2.0, 0.9, 0.7))
	## Meta: cuadros blancos y negros y un arco.
	var p0: Vector2 = line[0]
	var t0: Vector2 = tr["tan"][0]
	var n0: Vector2 = t0.orthogonal()
	for cx: int in int(w / 1.0):
		for cy: int in 2:
			var at: Vector2 = p0 + n0 * (-w * 0.5 + 0.5 + cx) + t0 * (cy * 1.0 - 0.5)
			var tile: MeshInstance3D = _box(Vector3(1.0, 0.02, 1.0), Color("#fafafa") if (cx + cy) % 2 == 0 else Color("#212121"), to3(at, 0.04))
			tile.rotation.y = -t0.angle()
	for sgn2: float in [-1.0, 1.0]:
		_box(Vector3(0.5, 5.0, 0.5), Color("#37474f"), to3(p0 + n0 * sgn2 * (w * 0.5 + 1.5), 2.5))
	var arch: MeshInstance3D = _box(Vector3(w + 3.5, 1.0, 0.4), Color("#ff7043"), to3(p0, 5.3))
	arch.rotation.y = -t0.angle() + PI * 0.5
	## Placas de turbo (flechas que brillan).
	for pi: int in (st["pads"] as Array):
		var pp: Vector2 = line[pi]
		var pt: Vector2 = tr["tan"][pi]
		for k: int in 3:
			var ar: MeshInstance3D = _box(Vector3(2.6, 0.03, 0.6), Color("#ffb300"), to3(pp + pt * (float(k) - 1.0) * 1.0, 0.05), null, 1.6)
			ar.rotation.y = -pt.angle() + PI * 0.5
	## Gradas junto a la meta y arboles alrededor (lejos de la pista).
	var gs: Vector2 = p0 + n0 * (w * 0.5 + 9.0)
	for row: int in 5:
		var g: MeshInstance3D = _box(Vector3(22.0, 0.6, 1.4), Color("#90a4ae").darkened(row * 0.05), to3(gs + n0 * row * 1.4, 0.3 + row * 0.6))
		g.rotation.y = -t0.angle()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = n
	var trunks: Array[Transform3D] = []
	var crowns: Array[Transform3D] = []
	var tcol: Array[Color] = []
	var ccol: Array[Color] = []
	var box: Rect2 = Rect2(line[0], Vector2.ZERO)
	for q: Vector2 in line:
		box = box.expand(q)
	box = box.grow(40.0)
	for k2: int in 260:
		var tp: Vector2 = Vector2(rng.randf_range(box.position.x, box.end.x), rng.randf_range(box.position.y, box.end.y))
		var best: float = INF
		for i3: int in range(0, n, 4):
			best = minf(best, tp.distance_to(line[i3]))
		if best < w * 0.5 + 9.0:
			continue
		var s: float = rng.randf_range(0.8, 1.5)
		trunks.append(Transform3D(Basis().scaled(Vector3(s, s, s)), to3(tp, 1.2 * s)))
		crowns.append(Transform3D(Basis().scaled(Vector3(s, s, s)), to3(tp, 3.4 * s)))
		tcol.append(Color("#6d4c41"))
		ccol.append(Color("#3f8a3a").lerp(Color("#7cb342"), rng.randf()))
	_multi("Trunks", trunks, tcol, Vector3(0.5, 2.4, 0.5))
	_multi("Trees", crowns, ccol, Vector3(2.6, 2.6, 2.6))
	## Minimapa (en pantalla).
	var rect: Rect2 = Rect2(line[0], Vector2.ZERO)
	for q2: Vector2 in line:
		rect = rect.expand(q2)
	_map_rect = rect
	for i4: int in range(0, n, 2):
		_map_pts.append(line[i4])
	_map_pts.append(line[0])


func _multi(nm: String, xf: Array[Transform3D], cols: Array[Color], size: Vector3) -> void:
	if xf.is_empty():
		return
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var b: BoxMesh = BoxMesh.new()
	b.size = size
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.85
	b.material = m
	mm.mesh = b
	mm.instance_count = xf.size()
	for k: int in xf.size():
		mm.set_instance_transform(k, xf[k])
		mm.set_instance_color(k, cols[k])
	var mi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mi.name = nm
	mi.multimesh = mm
	add_child(mi)


## Kart hecho con cajas: chasis, morro, aler\u00f3n, cuatro ruedas, piloto con casco y chispas.
func _build_karts() -> void:
	for k: Dictionary in st["karts"]:
		var i: int = int(k["i"])
		var col: Color = Kit.color("player", COLORS[0]) if i == 0 else COLORS[1 + (i - 1) % (COLORS.size() - 1)]
		var root: Node3D = Node3D.new()
		root.name = "Kart%d" % i
		add_child(root)
		var body: Node3D = Node3D.new()
		body.name = "Body"
		root.add_child(body)
		## El kart mira hacia -Z.
		_box(Vector3(1.2, 0.3, 2.0), col, Vector3(0, 0.35, 0), body)
		_box(Vector3(0.9, 0.22, 0.6), col.lightened(0.15), Vector3(0, 0.42, -1.15), body)
		_box(Vector3(1.4, 0.08, 0.35), Color("#212121"), Vector3(0, 0.75, 0.95), body)
		_box(Vector3(0.08, 0.35, 0.08), Color("#212121"), Vector3(0.45, 0.58, 0.95), body)
		_box(Vector3(0.08, 0.35, 0.08), Color("#212121"), Vector3(-0.45, 0.58, 0.95), body)
		var wheels: Array = []
		for wx: float in [-0.68, 0.68]:
			for wz: float in [-0.7, 0.7]:
				var wh: MeshInstance3D = MeshInstance3D.new()
				var cyl: CylinderMesh = CylinderMesh.new()
				cyl.top_radius = 0.26
				cyl.bottom_radius = 0.26
				cyl.height = 0.28
				cyl.material = mat(Color("#1b1b1b"))
				wh.mesh = cyl
				wh.rotation_degrees = Vector3(0, 0, 90)
				wh.position = Vector3(wx, 0.26, wz)
				body.add_child(wh)
				wheels.append(wh)
		var driver: MeshInstance3D = MeshInstance3D.new()
		var cap: CapsuleMesh = CapsuleMesh.new()
		cap.radius = 0.24
		cap.height = 0.7
		cap.material = mat(Color("#37474f"))
		driver.mesh = cap
		driver.position = Vector3(0, 0.8, 0.15)
		body.add_child(driver)
		var helmet: MeshInstance3D = MeshInstance3D.new()
		var sp: SphereMesh = SphereMesh.new()
		sp.radius = 0.22
		sp.height = 0.44
		sp.material = mat(col.lightened(0.3))
		helmet.mesh = sp
		helmet.position = Vector3(0, 1.25, 0.1)
		body.add_child(helmet)
		_box(Vector3(0.3, 0.1, 0.05), Color("#263238"), Vector3(0, 1.27, -0.12), body)
		var sparks: CPUParticles3D = CPUParticles3D.new()
		sparks.emitting = false
		sparks.amount = 24
		sparks.lifetime = 0.35
		sparks.direction = Vector3(0, 1, 1)
		sparks.spread = 35.0
		sparks.initial_velocity_min = 2.0
		sparks.initial_velocity_max = 4.0
		sparks.gravity = Vector3(0, -6, 0)
		var sm: BoxMesh = BoxMesh.new()
		sm.size = Vector3(0.07, 0.07, 0.07)
		var spm: StandardMaterial3D = mat(Color.WHITE, 2.0, true)
		spm.vertex_color_use_as_albedo = true
		sm.material = spm
		sparks.mesh = sm
		sparks.position = Vector3(0, 0.15, 0.9)
		body.add_child(sparks)
		var flame: MeshInstance3D = _box(Vector3(0.35, 0.25, 0.7), Color("#ff9100"), Vector3(0, 0.45, 1.35), body, 3.0)
		flame.visible = false
		## En directo, el nombre de cada piloto encima de su kart.
		if str(k.get("name", "")) != "" and not bool(k["me"]):
			var tag: Label3D = Label3D.new()
			tag.name = "Name"
			tag.text = str(k["name"])
			tag.font_size = 64
			tag.pixel_size = 0.012
			tag.outline_size = 14
			tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			tag.position = Vector3(0, 2.2, 0)
			tag.modulate = col.lightened(0.4)
			root.add_child(tag)
		_karts.append({"root": root, "body": body, "wheels": wheels, "sparks": sparks, "flame": flame})


# ------------------------------------------------------------------ objetos en 3D

## Cajas de objetos: cubos que giran y brillan con una interrogacion encima.
func _build_items() -> void:
	_box_nodes.clear()
	for b: Dictionary in st["boxes"]:
		var root: Node3D = Node3D.new()
		root.name = "ItemBox%d" % _box_nodes.size()
		root.position = to3(b["p"], 1.0)
		add_child(root)
		var cube: MeshInstance3D = _box(Vector3(1.1, 1.1, 1.1), Color(0.35, 0.75, 1.0, 0.75), Vector3.ZERO, root, 1.2)
		cube.rotation = Vector3(0.6, 0.0, 0.6)
		var q: Label3D = Label3D.new()
		q.text = "?"
		q.font_size = 96
		q.pixel_size = 0.01
		q.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		q.outline_size = 18
		q.no_depth_test = false
		root.add_child(q)
		_box_nodes.append(root)


func _shot_node(sh: Dictionary) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Shot_" + str(sh["id"]).replace(":", "_")
	var mi: MeshInstance3D = MeshInstance3D.new()
	if M.effect(st, str(sh["kind"])) == "seek":
		var sp: SphereMesh = SphereMesh.new()
		sp.radius = 0.45
		sp.height = 0.6
		sp.material = mat(Color("#2e7d32"), 0.4)
		mi.mesh = sp
		mi.position = Vector3(0, 0.35, 0)
		var rim: MeshInstance3D = MeshInstance3D.new()
		var cy: CylinderMesh = CylinderMesh.new()
		cy.top_radius = 0.5
		cy.bottom_radius = 0.5
		cy.height = 0.12
		cy.material = mat(Color("#fafafa"))
		rim.mesh = cy
		rim.position = Vector3(0, 0.2, 0)
		root.add_child(rim)
	else:
		var cap: CapsuleMesh = CapsuleMesh.new()
		cap.radius = 0.26
		cap.height = 1.35
		cap.material = mat(Color("#fdd835"), 0.3)
		mi.mesh = cap
		mi.rotation_degrees = Vector3(0, 0, 70)
		mi.position = Vector3(0, 0.3, 0)
	root.add_child(mi)
	add_child(root)
	return root


func _sync_items() -> void:
	for k: int in _box_nodes.size():
		var n: Node3D = _box_nodes[k]
		var b: Dictionary = st["boxes"][k]
		n.visible = float(b["cd"]) <= 0.0
		n.rotation.y = _t * 1.6 + float(k)
		n.position.y = 1.0 + sin(_t * 3.0 + float(k)) * 0.12
	var alive: Dictionary = {}
	for sh: Dictionary in st["shots"]:
		var id: String = str(sh["id"])
		alive[id] = true
		var node: Node3D = _shot_nodes.get(id) as Node3D
		if node == null:
			node = _shot_node(sh)
			_shot_nodes[id] = node
		node.position = to3(sh["p"])
		if M.effect(st, str(sh["kind"])) == "seek":
			node.rotation.y = _t * 12.0
	for id2: String in _shot_nodes.keys():
		if not alive.has(id2):
			(_shot_nodes[id2] as Node3D).queue_free()
			_shot_nodes.erase(id2)
	var item: String = str(st["karts"][0]["item"])
	if _item_btn != null:
		_item_btn.visible = not _bot and bool(st["items_on"])
		_item_btn.disabled = item == ""
		_item_btn.text = item_label(item) if not (st["items"] as Dictionary).get(item, {}).has("name") else str(st["items"][item]["name"])
		if int(st["karts"][0].get("ammo", 0)) > 1:
			_item_btn.text += " x%d" % int(st["karts"][0]["ammo"])


static func item_label(item: String) -> String:
	match item:
		"cascara":
			return Kit.text("kt_shell", "C\u00e1scara")
		"platano":
			return Kit.text("kt_banana", "Pl\u00e1tano")
		"turbo":
			return Kit.text("kt_boost", "Turbo")
	return Kit.text("kt_item", "Objeto")


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
	_hud.draw.connect(_draw_hud)
	layer.add_child(_hud)
	var safe: MarginContainer = UI.safe_root(_hud, 14.0)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	safe.add_child(top)
	var col: VBoxContainer = VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(col)
	_pos_lbl = Label.new()
	_pos_lbl.name = "Position"
	_pos_lbl.add_theme_font_size_override("font_size", 64)
	_pos_lbl.add_theme_color_override("font_color", Color("#ffd23f"))
	_pos_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_pos_lbl.add_theme_constant_override("outline_size", 12)
	col.add_child(_pos_lbl)
	_lap_lbl = Label.new()
	_lap_lbl.name = "Lap"
	_lap_lbl.add_theme_font_size_override("font_size", 30)
	_lap_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_lap_lbl.add_theme_constant_override("outline_size", 8)
	col.add_child(_lap_lbl)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)
	_big = Label.new()
	_big.name = "Big"
	_big.theme_type_variation = "TitleLabel"
	_big.add_theme_font_size_override("font_size", 110)
	_big.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_big.add_theme_constant_override("outline_size", 16)
	_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_big.set_anchors_preset(Control.PRESET_CENTER)
	_big.position = Vector2(-360, -300)
	_big.size = Vector2(720, 170)
	_big.modulate.a = 0.0
	_big.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_big)
	_left_btn = _hold_button("BtnLeft", "\u25c0", Vector2(30, -260), Vector2(150, 150))
	_left_btn.button_down.connect(func() -> void: _steer_l = true)
	_left_btn.button_up.connect(func() -> void: _steer_l = false)
	_right_btn = _hold_button("BtnRight", "\u25b6", Vector2(200, -260), Vector2(150, 150))
	_right_btn.button_down.connect(func() -> void: _steer_r = true)
	_right_btn.button_up.connect(func() -> void: _steer_r = false)
	_drift_btn = _hold_button("BtnDrift", Kit.text("kt_drift", "Derrape"), Vector2(-260, -260), Vector2(230, 150))
	_drift_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_drift_btn.offset_left = -260.0
	_drift_btn.offset_right = -30.0
	_drift_btn.offset_top = -260.0
	_drift_btn.offset_bottom = -110.0
	## Pegado al borde derecho: si el texto pide mas sitio, crece hacia dentro (no se sale).
	_drift_btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_drift_btn.add_theme_font_size_override("font_size", 44)
	_drift_btn.self_modulate = Kit.color("accent", Color("#ff7043")).lerp(Color.WHITE, 0.2)
	_drift_btn.button_down.connect(func() -> void: _drift_held = true)
	_drift_btn.button_up.connect(func() -> void: _drift_held = false)
	_item_btn = _hold_button("BtnItem", Kit.text("kt_item", "Objeto"), Vector2(-260, -430), Vector2(230, 150))
	_item_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_item_btn.offset_left = -260.0
	_item_btn.offset_right = -30.0
	_item_btn.offset_top = -420.0
	_item_btn.offset_bottom = -290.0
	_item_btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_item_btn.add_theme_font_size_override("font_size", 40)
	_item_btn.self_modulate = Color("#4fc3f7").lerp(Color.WHITE, 0.25)
	_item_btn.button_down.connect(func() -> void: _use_pressed = true)


func _hold_button(nm: String, text: String, off: Vector2, sz: Vector2) -> Button:
	var b: Button = UI.make_button(text, true)
	b.name = nm
	b.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	b.offset_left = off.x
	b.offset_top = off.y
	b.offset_right = off.x + sz.x
	b.offset_bottom = off.y + sz.y
	b.add_theme_font_size_override("font_size", 52)
	_hud.add_child(b)
	return b


## Minimapa arriba a la derecha (con todos los karts) y barra de carga del derrape.
func _draw_hud() -> void:
	var sz: Vector2 = _hud.size
	var box: Rect2 = Rect2(sz.x - 210.0, 130.0, 190.0, 190.0)
	_hud.draw_rect(box, Color(0, 0, 0, 0.35))
	var r: Rect2 = _map_rect
	var sc: float = 170.0 / maxf(r.size.x, r.size.y)
	var org: Vector2 = box.position + Vector2(10, 10) + (Vector2(170, 170) - r.size * sc) * 0.5
	var pts: PackedVector2Array = PackedVector2Array()
	for q: Vector2 in _map_pts:
		pts.append(org + (q - r.position) * sc)
	if pts.size() > 1:
		_hud.draw_polyline(pts, Color(1, 1, 1, 0.8), 4.0)
	var ks: Array = st["karts"]
	for k: int in range(ks.size() - 1, -1, -1):
		var c: Color = Kit.color("player", COLORS[0]) if k == 0 else COLORS[1 + (k - 1) % (COLORS.size() - 1)]
		_hud.draw_circle(org + ((ks[k]["p"] as Vector2) - r.position) * sc, 7.0 if k == 0 else 5.0, c)
	var me: Dictionary = ks[0]
	if int(me["drift"]) != 0 and not _bot:
		var lvl: int = M.drift_level(me)
		var colr: Color = [Color(1, 1, 1, 0.6), Color("#4fc3f7"), Color("#ff9100"), Color("#d500f9")][lvl]
		var w: float = clampf(float(me["drift_t"]) / 1.9, 0.0, 1.0) * 300.0
		_hud.draw_rect(Rect2(sz.x * 0.5 - 150.0, sz.y - 330.0, 300.0, 18.0), Color(0, 0, 0, 0.5))
		_hud.draw_rect(Rect2(sz.x * 0.5 - 150.0, sz.y - 330.0, w, 18.0), colr)


func _big_text(text: String, col: Color, hold: float = 0.6) -> void:
	if fast or _big == null:
		return
	_big.text = text
	_big.add_theme_color_override("font_color", col)
	_big.modulate.a = 1.0
	_big.scale = Vector2.ONE * 0.6
	_big.pivot_offset = _big.size * 0.5
	var tw: Tween = _big.create_tween()
	tw.tween_property(_big, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(hold)
	tw.tween_property(_big, "modulate:a", 0.0, 0.25)


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
	if finished and online.is_empty():
		return
	if fast and auto_retry:
		_bot = true
	var live: bool = not online.is_empty()
	var steps: int = 4 if fast and not live else 1
	for k: int in steps:
		if (finished and not live) or get_tree().paused:
			break
		if live:
			M.net_follow(st, delta)
		var inp: Dictionary = {}
		if not _bot:
			var s: float = (1.0 if _steer_r else 0.0) - (1.0 if _steer_l else 0.0)
			var keys: float = Input.get_axis("move_left", "move_right")
			if absf(keys) > 0.1:
				s = keys
			## Ojo: en la pista, girar a la derecha es girar el angulo hacia +.
			inp = {"steer": s, "drift": _drift_held or Input.is_action_pressed("jump"), "gas": 1.0 if not Input.is_action_pressed("move_down") else -0.5,
				"use": _use_pressed}
		M.step(st, inp, delta)
		_use_pressed = false
		time_in_level += delta
		_events()
		if bool(st["over"]):
			_end()
			break
	if live:
		_net_tick(delta)
	_sync(delta)


func _events() -> void:
	for e: Dictionary in st["events"]:
		match str(e["kind"]):
			"count":
				var n: int = int(e["n"])
				_big_text(str(n) if n > 0 else Kit.text("kt_go", "\u00a1YA!"), Color("#ffd23f") if n > 0 else Color("#5ad17a"), 0.5)
				_sfx("ui_tick" if n > 0 else "powerup", -4.0)
			"lap":
				var last: bool = int(e["n"]) == int(st["laps"])
				_big_text(Kit.text("kt_last", "\u00a1\u00daltima vuelta!") if last else Kit.text("kt_lap", "Vuelta %d") % int(e["n"]), Color("#ffffff"), 0.8)
				_sfx("ui_big", -6.0)
			"mini_turbo":
				if int(e["i"]) == 0:
					_sfx("powerup", -8.0, 1.0 + 0.15 * float(e["level"]))
					Juice.vibrate(20)
			"pad":
				if int(e["i"]) == 0:
					_sfx("powerup", -8.0, 1.3)
			"bump":
				if int(e["a"]) == 0 or int(e["b"]) == 0:
					_sfx("stomp", -12.0)
			"wall":
				if int(e["i"]) == 0:
					_sfx("hurt", -10.0)
					Juice.vibrate(40)
			"finish":
				if int(e["i"]) == 0:
					coins = maxi(0, 7 - int(e["pos"]))
			"item_get":
				if int(e["i"]) == 0:
					_sfx("coin", -8.0, 1.2)
			"item_use":
				if int(e["i"]) == 0:
					var fx2: String = M.effect(st, str(e["item"]))
					_sfx("shoot" if fx2 == "seek" else ("powerup" if fx2 in ["boost", "star"] else "click"), -8.0)
				if net != null and e.has("shot"):
					var sh: Dictionary = e["shot"]
					var sp: Vector2 = sh["p"]
					var sd: Vector2 = sh["d"]
					net.send("it", {"id": str(st["karts"][int(e["i"])]["sid"]), "n": int(sh["n"]), "k": str(sh["kind"]),
						"p": [snappedf(sp.x, 0.01), snappedf(sp.y, 0.01)], "d": [snappedf(sd.x, 0.001), snappedf(sd.y, 0.001)],
						"v": snappedf(float(sh["v"]), 0.1), "t": snappedf(float(sh["ttl"]), 0.1)})
			"hit":
				if int(e["i"]) == 0:
					_sfx("hurt", -6.0)
					Juice.vibrate(60)
					_big_text(Kit.text("kt_spin", "\u00a1Trompo!"), Color("#ff7043"), 0.4)
				else:
					_sfx("stomp", -12.0)
			"block":
				if int(e["i"]) == 0:
					_sfx("stomp", -6.0, 1.3)
			"end":
				if not online.is_empty():
					_net_end.call_deferred()
		## En directo: el disparo que se ha gastado en un kart de este movil se borra en los demas.
		if net != null and str(e["kind"]) in ["hit", "block"] and str(e.get("id", "")) != "":
			net.send("hx", {"id": str(e["id"])})
	(st["events"] as Array).clear()


func _sync(delta: float) -> void:
	var ks: Array = st["karts"]
	for k: int in ks.size():
		var kd: Dictionary = ks[k]
		var e: Dictionary = _karts[k]
		var root: Node3D = e["root"]
		root.position = to3(kd["p"])
		## El angulo de la simulacion (x, y) es hacia +X con a = 0; el kart mira a -Z.
		var a: float = float(kd["a"])
		var drift: int = int(kd["drift"])
		root.rotation.y = -a - PI * 0.5 + float(drift) * -0.35 + float(kd.get("stun", 0.0)) * 14.0
		var body: Node3D = e["body"]
		body.rotation.z = lerpf(body.rotation.z, float(kd["steer"]) * -0.06, minf(1.0, delta * 8.0))
		body.position.y = absf(sin(_t * 20.0 + float(k))) * 0.02 * clampf(float(kd["v"]) / 10.0, 0.0, 1.0) + (0.05 if bool(kd["off"]) and int(_t * 15.0) % 2 == 0 else 0.0)
		for wh: MeshInstance3D in e["wheels"]:
			wh.rotation.x += float(kd["v"]) * delta / 0.26
		var sparks: CPUParticles3D = e["sparks"]
		var lvl: int = M.drift_level(kd)
		sparks.emitting = drift != 0 and not fast and lvl > 0
		sparks.color = [Color.WHITE, Color("#4fc3f7"), Color("#ff9100"), Color("#d500f9")][lvl]
		(e["flame"] as Node3D).visible = float(kd["boost_t"]) > 0.0 and int(_t * 20.0) % 2 == 0
		## Estrella: el kart brilla con colores que cambian.
		body.scale = Vector3.ONE * (1.0 + 0.08 * sin(_t * 30.0)) if float(kd.get("star_t", 0.0)) > 0.0 else Vector3.ONE
	## Interfaz.
	var me: Dictionary = ks[0]
	var pos: int = M.position(st, 0)
	_pos_lbl.text = "%d\u00ba/%d" % [pos, ks.size()]
	_lap_lbl.text = Kit.text("kt_laps", "Vuelta %d/%d") % [mini(int(me["lap"]) + 1, int(st["laps"])), int(st["laps"])]
	for b: Button in [_left_btn, _right_btn, _drift_btn]:
		b.visible = not _bot
	_sync_items()
	_hud.queue_redraw()
	## Camara de persecucion (detras y algo alta; en el derrape se abre un poco).
	var p: Vector3 = to3(me["p"])
	var dir: Vector2 = Vector2.from_angle(float(me["a"]))
	var back: Vector3 = to3(-dir) * 7.5
	var want: Vector3 = p + back + Vector3(0, 3.6, 0)
	_cam.position = _cam.position.lerp(want, minf(1.0, delta * 6.0)) if not fast and delta < 0.5 else want
	_cam.look_at(p + to3(dir) * 6.0 + Vector3(0, 0.8, 0), Vector3.UP)
	_cam.fov = lerpf(_cam.fov, 66.0 + (8.0 if float(me["boost_t"]) > 0.0 else 0.0), minf(1.0, delta * 4.0))
	Audio.set_intensity(clampf(0.4 + float(int(me["lap"])) * 0.2 + (0.2 if pos == 1 else 0.0), 0.0, 1.0))


# ------------------------------------------------------------------ toques

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()
		return
	if not can_act():
		return
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		_bot = false
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo and (event as InputEventKey).keycode == KEY_E:
		_use_pressed = true


# ------------------------------------------------------------------ final

func _end() -> void:
	if bool(st["won"]):
		_finish()
	else:
		_lose()


func _finish() -> void:
	if finished:
		return
	finished = true
	var place: int = int(st.get("place", 6))
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = maxi(1, 5000 - place * 600 - int(time_in_level) * 10)
	coins = maxi(0, 7 - place)
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "time": snappedf(time_in_level, 0.1), "place": place})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


func stars_earned() -> int:
	var place: int = int(st.get("place", 6))
	return 3 if place == 1 else (2 if place <= 2 else 1)


func _lose() -> void:
	if finished:
		return
	finished = true
	failed = true
	deaths += 1
	var place: int = int(st.get("place", 6))
	QA.log_event("death", {"cause": "race", "place": place})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("kt_lost", "Has llegado %d\u00ba") % place,
		Kit.text("kt_fail_hint", "Mant\u00e9n DERRAPE en las curvas largas y su\u00e9ltalo al salir: cuanto m\u00e1s dura, m\u00e1s turbo."))
	p.closed.connect(retry)


func retry() -> void:
	_reset()
	for n: Node3D in _shot_nodes.values():
		n.queue_free()
	_shot_nodes.clear()
	_use_pressed = false
	_sync(1.0)


func open_pause() -> void:
	## En directo no se para (los demas siguen corriendo).
	if not online.is_empty():
		return
	if finished or get_tree().paused or get_node_or_null("PauseMenu") != null:
		return
	PauseMenu.open(self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_inside_tree() and not UI.test_mode:
			open_pause()


# ------------------------------------------------------------------ en directo

## Parrilla de la sala: el anfitrion (sesion mas baja) mueve los bots; la cuenta atras acaba
## a la vez en todos los moviles (start_ms de la sala).
func _net_setup() -> void:
	my_id = str(online.get("yo", ""))
	var players: Array = []
	for j: Variant in online.get("jugadores", []):
		if j is Dictionary:
			players.append(j)
	players.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return int(x.get("slot", 0)) < int(y.get("slot", 0)))
	var ids: Array[String] = []
	for p: Dictionary in players:
		ids.append(str(p.get("sesion", "")))
	ids.sort()
	host = not ids.is_empty() and ids[0] == my_id
	_host_sid = ids[0] if not ids.is_empty() else my_id
	M.setup_online(st, players, my_id, host)
	var start_ms: int = int(online.get("start_ms", Time.get_ticks_msec()))
	st["go_t"] = 3.0 + maxf(0.0, float(start_ms - Time.get_ticks_msec()) / 1000.0)


func _net_open() -> void:
	net = Online.arena_channel(str(online.get("sala", "")))
	add_child(net)
	net.received.connect(_on_net)
	QA.log_event("kart_live_start", {"sala": str(online.get("sala", "")), "host": host, "players": (online.get("jugadores", []) as Array).size()})


## 10 veces por segundo, lo que mueve este movil (tu kart y, si eres el anfitrion, los bots).
## Quien lleva un rato sin dar senales se esconde; si es el anfitrion, otro coge los bots.
func _net_tick(delta: float) -> void:
	_send_acc += delta
	if _send_acc >= NET_RATE and net != null:
		_send_acc = 0.0
		var l: Array = []
		for k: Dictionary in st["karts"]:
			if not bool(k["remote"]):
				l.append({"id": str(k["sid"]), "s": M.net_state(k)})
		net.send("k", {"l": l})
	var ks: Array = st["karts"]
	for i: int in ks.size():
		var kd: Dictionary = ks[i]
		if bool(kd["remote"]) and bool(kd.get("human", false)):
			(_karts[i]["root"] as Node3D).visible = time_in_level < NET_TIMEOUT or time_in_level - float(_seen.get(str(kd["sid"]), 0.0)) < NET_TIMEOUT
	if not host and time_in_level > 5.0 and time_in_level - float(_seen.get(_host_sid, 0.0)) > HOST_TIMEOUT:
		## El anfitrion no contesta: lo es la sesion mas baja de las que siguen.
		var cands: Array[String] = [my_id]
		for kd2: Dictionary in ks:
			var sid: String = str(kd2["sid"])
			if bool(kd2.get("human", false)) and sid != my_id and sid != _host_sid and time_in_level - float(_seen.get(sid, 0.0)) < HOST_TIMEOUT:
				cands.append(sid)
		cands.sort()
		_host_sid = cands[0]
		if _host_sid == my_id:
			host = true
			M.make_host(st)
			QA.log_event("kart_live_host", {"t": snappedf(time_in_level, 0.1)})


func _on_net(event: String, d: Dictionary) -> void:
	if st.is_empty():
		return
	match event:
		"k":
			for e: Variant in d.get("l", []):
				if not e is Dictionary:
					continue
				var sid: String = str((e as Dictionary).get("id", ""))
				var k: Dictionary = M.kart_by_sid(st, sid)
				var s: Variant = (e as Dictionary).get("s", {})
				if k.is_empty() or not bool(k["remote"]) or not s is Dictionary:
					continue
				M.net_apply(st, k, s)
				_seen[sid] = time_in_level
				## Los bots llegan del anfitrion: tambien cuenta como senal suya.
				if sid.begins_with("bot"):
					_seen[_host_sid] = time_in_level
		"it":
			var owner: Dictionary = M.kart_by_sid(st, str(d.get("id", "")))
			var kind: String = str(d.get("k", ""))
			if owner.is_empty() or not bool(owner["remote"]) or not M.effect(st, kind) in ["seek", "trap"]:
				return
			var p: Array = d.get("p", [0.0, 0.0])
			var dd: Array = d.get("d", [1.0, 0.0])
			var at: Vector2 = Vector2(float(p[0]), float(p[1]))
			M.add_shot(st, {"id": "%s:%d" % [str(owner["sid"]), int(d.get("n", 0))], "n": int(d.get("n", 0)), "owner": int(owner["i"]), "kind": kind,
				"p": at, "d": Vector2(float(dd[0]), float(dd[1])).normalized(), "v": clampf(float(d.get("v", 0.0)), 0.0, 60.0),
				"ttl": clampf(float(d.get("t", 3.0)), 0.0, M.BANANA_TTL), "age": 0.0, "idx": M.nearest(st, at, int(owner["idx"]))})
		"hx":
			M.remove_shot(st, str(d.get("id", "")))


## Meta en directo: tu puesto entre las personas al servidor (trofeos) y la ventana de resultado.
func _net_end() -> void:
	if reported:
		return
	reported = true
	finished = true
	## Tu llegada a los demas ya (sin esperar al siguiente envio).
	if net != null:
		net.send("k", {"l": [{"id": my_id, "s": M.net_state(st["karts"][0])}]})
	var place: int = M.human_place(st)
	failed = place != 1
	coins = maxi(0, 5 - place)
	Audio.play("win" if place == 1 else "hurt")
	if place == 1:
		Audio.play_track("victoria", false)
	QA.log_event("kart_live_end", {"place": place, "race_place": int(st.get("place", 0)), "time": snappedf(time_in_level, 0.1)})
	var sala: String = str(online.get("sala", ""))
	Online.arena_match = {}
	var r: Dictionary = await Online.arena_result(sala, place)
	if not is_inside_tree():
		return
	ArenaPanel.open_result(self, place, 0, r, false, 0, time_in_level)


func bot_state() -> Dictionary:
	var ks: Array = st.get("karts", [])
	return {"deaths": deaths, "coins": coins, "finished": finished, "failed": failed, "time": time_in_level,
		"place": int(st.get("place", 0)), "lap": int(ks[0]["lap"]) if ks.size() > 0 else 0}
