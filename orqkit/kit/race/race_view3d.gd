class_name Race3DView
extends Node3D
## Vista 3D de las carreras (game.json -> "view": "3d"). Solo dibuja: la carrera, el analizador,
## el bot y las reglas son las de race_game.gd, asi que todo lo validado sigue valiendo.
## 1 - Carretera en 3D siguiendo las curvas (asfalto, bordillos, lineas, salida y meta).
## 2 - Paisaje low-poly con los colores del juego: arboles, rocas, cielo y niebla.
## 3 - Coches low-poly (tu coche con el color de acento), conos, monedas que giran y turbos.
## 4 - Camara de persecucion que se inclina en las curvas y abre el angulo con la velocidad.

## Pixeles del juego 2D -> metros: lateral y hacia delante (la pista se estira para que corra).
const SX: float = 0.02
const SZ: float = 0.035
const VIEW_BEHIND: float = 30.0
const VIEW_AHEAD: float = 140.0

var game: Node2D
var _camera: Camera3D
var _car: Node3D
var _rivals: Array[Node3D] = []
var _items: Array[Node3D] = []
var _coins: Array[Node3D] = []
var _road: MeshInstance3D
var _shake: float = 0.0
var _cam_x: float = 0.0
var _last_crashes: int = 0
var _spin: float = 0.0


func setup(g: Node2D) -> void:
	game = g
	name = "View3D"
	_build_environment()
	_road = MeshInstance3D.new()
	_road.name = "Road"
	add_child(_road)
	_road.mesh = _build_road()
	add_child(_build_scenery())
	_camera = Camera3D.new()
	_camera.name = "Camera3D"
	_camera.fov = 62.0
	_camera.far = 400.0
	add_child(_camera)
	_camera.make_current()


## Punto del mundo 3D para una distancia y posicion lateral del juego (en pixeles).
func pos(dist: float, lat_px: float, y: float = 0.0) -> Vector3:
	return Vector3((float(game.call("center_at", dist)) + lat_px) * SX, y, -dist * SZ)


# ------------------------------------------------------------------ escenario

## Noche si el cielo del juego es oscuro: ciudad con neones. Si no, dia con arboles.
func is_night() -> bool:
	return Kit.color("sky", Color("#1b2a41")).v < 0.3


func _horizon() -> Color:
	var sky_col: Color = Kit.color("sky", Color("#1b2a41"))
	if is_night():
		return sky_col.lightened(0.2).lerp(Kit.color("accent", Color.ORANGE), 0.12)
	return sky_col.lightened(0.4)


func _build_environment() -> void:
	var sky_col: Color = Kit.color("sky", Color("#1b2a41"))
	var horizon: Color = _horizon()
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky_mat: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = sky_col.darkened(0.1) if not is_night() else sky_col
	sky_mat.sky_horizon_color = horizon
	sky_mat.ground_horizon_color = horizon
	sky_mat.ground_bottom_color = sky_col.darkened(0.4)
	var sky: Sky = Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7 if is_night() else 0.9
	env.fog_enabled = true
	env.fog_light_color = horizon
	env.fog_density = 0.004
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -35.0, 0.0)
	sun.light_energy = 0.55 if is_night() else 1.1
	sun.light_color = Color(0.75, 0.8, 1.0) if is_night() else Color(1.0, 0.97, 0.9)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	add_child(sun)


## Color del suelo: el "solido" del juego (de noche mas oscuro, de dia algo mas vivo).
func _ground() -> Color:
	var solid: Color = Kit.color("solid", Color("#4f6787"))
	if is_night():
		return solid.darkened(0.55)
	return Color.from_hsv(solid.h, clampf(solid.s + 0.1, 0.2, 0.75), clampf(solid.v, 0.4, 0.7))


static func _mat(col: Color, emission: float = 0.0) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.85
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emission
	return m


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	## a-b delante, d-c detras (sentido antihorario visto desde arriba).
	st.set_color(col)
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(d)


func _build_road() -> ArrayMesh:
	var consts: Dictionary = (game.get_script() as Script).get_script_constant_map()
	var row: float = consts["ROW"]
	var lane: float = consts["LANE_W"]
	var half: float = lane * 2.0
	var n_rows: int = (game.get("rows") as Array).size()
	var grass: Color = _ground()
	var asphalt: Color = Color(0.13, 0.13, 0.16) if is_night() else Color(0.22, 0.23, 0.26)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(-10, n_rows + 14):
		var d0: float = float(i) * row
		var d1: float = d0 + row
		## 1 - Cesped a franjas, asfalto y bordillos rojos y blancos.
		var g: Color = grass if i % 2 == 0 else grass.darkened(0.07)
		_quad(st, pos(d1, -half - 3000.0, -0.02), pos(d1, half + 3000.0, -0.02), pos(d0, half + 3000.0, -0.02), pos(d0, -half - 3000.0, -0.02), g)
		_quad(st, pos(d1, -half), pos(d1, half), pos(d0, half), pos(d0, -half), asphalt if i % 2 == 0 else asphalt.lightened(0.02))
		var kerb: Color = Color(0.85, 0.18, 0.16) if i % 2 == 0 else Color(0.95, 0.95, 0.95)
		for s: float in [-1.0, 1.0]:
			var a0: float = s * half
			var a1: float = s * (half + 18.0)
			if s < 0.0:
				_quad(st, pos(d1, a1, 0.01), pos(d1, a0, 0.01), pos(d0, a0, 0.01), pos(d0, a1, 0.01), kerb)
			else:
				_quad(st, pos(d1, a0, 0.01), pos(d1, a1, 0.01), pos(d0, a1, 0.01), pos(d0, a0, 0.01), kerb)
		## 2 - Lineas de carril discontinuas.
		for k: int in [-1, 0, 1]:
			var x: float = float(k) * lane
			var dm: float = d0 + row * 0.5
			_quad(st, pos(dm, x - 3.0, 0.015), pos(dm, x + 3.0, 0.015), pos(d0, x + 3.0, 0.015), pos(d0, x - 3.0, 0.015), Color(1, 1, 1, 0.8))
		## 3 - Salida y meta a cuadros.
		if i == 0 or i == n_rows:
			for q: int in 16:
				var col: Color = Color.WHITE if (q + (0 if i == 0 else 1)) % 2 == 0 else Color(0.05, 0.05, 0.05)
				var x0: float = -half + float(q) * half / 8.0
				_quad(st, pos(d0 + 14.0, x0, 0.02), pos(d0 + 14.0, x0 + half / 8.0, 0.02), pos(d0, x0 + half / 8.0, 0.02), pos(d0, x0, 0.02), col)
	st.generate_normals()
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.95
	st.set_material(m)
	return st.commit()


func _build_scenery() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Scenery"
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1234 + Kit.level_index * 77
	var consts: Dictionary = (game.get_script() as Script).get_script_constant_map()
	var row: float = consts["ROW"]
	var half: float = float(consts["LANE_W"]) * 2.0
	var n_rows: int = (game.get("rows") as Array).size()
	var leaf: Color = Kit.color("accent", Color("#4cc26a"))
	leaf = Color.from_hsv(fposmod(leaf.h + 0.25, 1.0) if absf(leaf.h - 0.33) > 0.2 else leaf.h, 0.55, 0.55)
	if is_night():
		return _build_city(root, rng, row, half, n_rows)
	var trunks: Array[Transform3D] = []
	var crowns: Array[Transform3D] = []
	var rocks: Array[Transform3D] = []
	for i: int in range(-10, n_rows + 14, 1):
		for s: float in [-1.0, 1.0]:
			if rng.randf() < 0.45:
				continue
			var off: float = s * (half + rng.randf_range(160.0, 1400.0))
			var p: Vector3 = pos(float(i) * row + rng.randf_range(0.0, row), off)
			var sc: float = rng.randf_range(0.8, 1.6)
			if rng.randf() < 0.75:
				trunks.append(Transform3D(Basis().scaled(Vector3(sc, sc, sc)), p + Vector3(0, 0.6 * sc, 0)))
				crowns.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * rng.randf_range(0.9, 1.4), sc)), p + Vector3(0, 2.1 * sc, 0)))
			else:
				rocks.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * 0.6, sc)), p + Vector3(0, 0.3 * sc, 0)))
	var trunk_mesh: CylinderMesh = CylinderMesh.new()
	trunk_mesh.top_radius = 0.14
	trunk_mesh.bottom_radius = 0.2
	trunk_mesh.height = 1.2
	trunk_mesh.radial_segments = 6
	trunk_mesh.material = _mat(Color(0.42, 0.28, 0.18))
	var crown_mesh: CylinderMesh = CylinderMesh.new()
	crown_mesh.top_radius = 0.0
	crown_mesh.bottom_radius = 1.0
	crown_mesh.height = 2.6
	crown_mesh.radial_segments = 7
	crown_mesh.material = _mat(leaf)
	var rock_mesh: SphereMesh = SphereMesh.new()
	rock_mesh.radius = 0.7
	rock_mesh.height = 1.2
	rock_mesh.radial_segments = 6
	rock_mesh.rings = 3
	rock_mesh.material = _mat(Color(0.55, 0.55, 0.58))
	for pair: Array in [[trunk_mesh, trunks], [crown_mesh, crowns], [rock_mesh, rocks]]:
		var list: Array = pair[1]
		if list.is_empty():
			continue
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = pair[0]
		mm.instance_count = list.size()
		for k: int in list.size():
			mm.set_instance_transform(k, list[k])
		var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
		mmi.multimesh = mm
		root.add_child(mmi)
	return root


## Ciudad de noche: edificios a los lados con franjas de neon de los colores del juego.
func _build_city(root: Node3D, rng: RandomNumberGenerator, row: float, half: float, n_rows: int) -> Node3D:
	var blocks: Array[Transform3D] = []
	var neon_a: Array[Transform3D] = []
	var neon_b: Array[Transform3D] = []
	for i: int in range(-10, n_rows + 14, 2):
		for s: float in [-1.0, 1.0]:
			if rng.randf() < 0.2:
				continue
			var off: float = s * (half + rng.randf_range(260.0, 900.0))
			var p: Vector3 = pos(float(i) * row + rng.randf_range(0.0, row), off)
			var w: float = rng.randf_range(3.0, 6.0)
			var hgt: float = rng.randf_range(5.0, 22.0)
			var dep: float = rng.randf_range(3.0, 6.0)
			blocks.append(Transform3D(Basis().scaled(Vector3(w, hgt, dep)), p + Vector3(0, hgt * 0.5, 0)))
			## Franjas de neon en la fachada que mira a la carretera.
			var face: float = p.x - s * w * 0.5 - s * 0.06
			for k: int in rng.randi_range(1, 3):
				var y: float = rng.randf_range(2.0, hgt - 0.5)
				var t: Transform3D = Transform3D(Basis().scaled(Vector3(0.1, 0.18, dep * 0.9)), Vector3(face, y, p.z))
				if rng.randf() < 0.5:
					neon_a.append(t)
				else:
					neon_b.append(t)
	var cube: BoxMesh = BoxMesh.new()
	cube.size = Vector3.ONE
	cube.material = _mat(Kit.color("solid", Color("#4f6787")).darkened(0.6))
	var na: BoxMesh = BoxMesh.new()
	na.size = Vector3.ONE
	na.material = _mat(Kit.color("accent", Color.ORANGE), 1.3)
	var nb: BoxMesh = BoxMesh.new()
	nb.size = Vector3.ONE
	nb.material = _mat(Kit.color("danger", Color("#ff6b5b")).lerp(Color(0.3, 0.7, 1.0), 0.5), 1.3)
	for pair: Array in [[cube, blocks], [na, neon_a], [nb, neon_b]]:
		var list: Array = pair[1]
		if list.is_empty():
			continue
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = pair[0]
		mm.instance_count = list.size()
		for k: int in list.size():
			mm.set_instance_transform(k, list[k])
		var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
		mmi.multimesh = mm
		root.add_child(mmi)
	return root


# ------------------------------------------------------------------ coches y objetos

## Coche low-poly: carroceria, cabina de cristal, 4 ruedas y aleron.
## Corredor dibujado: el sprite animado mirando siempre a la camara, con sombra en el suelo.
static func rider3d(entry: Dictionary, height_m: float) -> Node3D:
	var n: Node3D = Node3D.new()
	var spr: AnimatedSprite3D = AnimatedSprite3D.new()
	spr.name = "Rider"
	spr.sprite_frames = SpriteKit.frames_de(entry)
	var celda: Array = entry.get("celda", [32, 32])
	spr.pixel_size = height_m / maxf(1.0, float(celda[1]))
	spr.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	spr.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	spr.shaded = false
	spr.position = Vector3(0, height_m * 0.5, 0)
	for a: String in ["run", "walk", "idle"]:
		if spr.sprite_frames.has_animation(a):
			spr.play(a)
			break
	n.add_child(spr)
	var sh: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = height_m * 0.38
	cm.bottom_radius = height_m * 0.38
	cm.height = 0.02
	var sm: StandardMaterial3D = StandardMaterial3D.new()
	sm.albedo_color = Color(0, 0, 0, 0.35)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cm.material = sm
	sh.mesh = cm
	sh.position = Vector3(0, 0.03, 0)
	sh.scale = Vector3(1.0, 1.0, 0.6)
	n.add_child(sh)
	return n


static func make_car3d(col: Color, player_car: bool) -> Node3D:
	var n: Node3D = Node3D.new()
	var body: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(1.25, 0.45, 3.0)
	bm.material = _mat(col)
	body.mesh = bm
	body.position = Vector3(0, 0.45, 0)
	n.add_child(body)
	var cab: MeshInstance3D = MeshInstance3D.new()
	var cm: BoxMesh = BoxMesh.new()
	cm.size = Vector3(1.0, 0.4, 1.3)
	cm.material = _mat(Color(0.12, 0.16, 0.22))
	cab.mesh = cm
	cab.position = Vector3(0, 0.85, 0.25)
	n.add_child(cab)
	var wheel: CylinderMesh = CylinderMesh.new()
	wheel.top_radius = 0.3
	wheel.bottom_radius = 0.3
	wheel.height = 0.26
	wheel.radial_segments = 10
	wheel.material = _mat(Color(0.07, 0.07, 0.08))
	for p: Vector3 in [Vector3(-0.66, 0.3, -1.0), Vector3(0.66, 0.3, -1.0), Vector3(-0.66, 0.3, 1.0), Vector3(0.66, 0.3, 1.0)]:
		var w: MeshInstance3D = MeshInstance3D.new()
		w.mesh = wheel
		w.position = p
		w.rotation = Vector3(0, 0, PI * 0.5)
		n.add_child(w)
	## Faros delanteros y pilotos traseros que brillan.
	for x: float in [-0.42, 0.42]:
		for front: bool in [true, false]:
			var l: MeshInstance3D = MeshInstance3D.new()
			var lm: BoxMesh = BoxMesh.new()
			lm.size = Vector3(0.26, 0.12, 0.04)
			lm.material = _mat(Color(1.0, 0.95, 0.75) if front else Color(1.0, 0.15, 0.1), 2.0)
			l.mesh = lm
			l.position = Vector3(x, 0.5, -1.51 if front else 1.51)
			n.add_child(l)
	if player_car:
		var wing: MeshInstance3D = MeshInstance3D.new()
		var wm: BoxMesh = BoxMesh.new()
		wm.size = Vector3(1.3, 0.08, 0.35)
		wm.material = _mat(Color(0.95, 0.95, 0.95))
		wing.mesh = wm
		wing.position = Vector3(0, 0.95, 1.35)
		n.add_child(wing)
		var stripe: MeshInstance3D = MeshInstance3D.new()
		var sm: BoxMesh = BoxMesh.new()
		sm.size = Vector3(0.22, 0.02, 3.02)
		sm.material = _mat(Color(1, 1, 1))
		stripe.mesh = sm
		stripe.position = Vector3(0, 0.68, 0)
		n.add_child(stripe)
	return n


func _make_item3d(kind: String) -> Node3D:
	var n: Node3D = Node3D.new()
	match kind:
		"C":
			var m: MeshInstance3D = MeshInstance3D.new()
			var cyl: CylinderMesh = CylinderMesh.new()
			cyl.top_radius = 0.42
			cyl.bottom_radius = 0.42
			cyl.height = 0.12
			cyl.radial_segments = 16
			cyl.material = _mat(Kit.color("coin", Color("#f6cf7a")), 0.6)
			m.mesh = cyl
			m.rotation = Vector3(PI * 0.5, 0, 0)
			m.position = Vector3(0, 0.9, 0)
			n.add_child(m)
			_coins.append(n)
		"N":
			var pad: MeshInstance3D = MeshInstance3D.new()
			var b: BoxMesh = BoxMesh.new()
			b.size = Vector3(1.7, 0.05, 2.2)
			b.material = _mat(Color(0.25, 0.8, 1.0), 1.2)
			pad.mesh = b
			pad.position = Vector3(0, 0.03, 0)
			n.add_child(pad)
			for k: int in 2:
				var arrow: MeshInstance3D = MeshInstance3D.new()
				var am: PrismMesh = PrismMesh.new()
				am.size = Vector3(1.0, 0.6, 0.06)
				am.material = _mat(Color(1, 1, 1), 0.8)
				arrow.mesh = am
				arrow.rotation = Vector3(-PI * 0.5, 0, 0)
				arrow.position = Vector3(0, 0.07, 0.5 - float(k) * 0.8)
				n.add_child(arrow)
		"O":
			var cone: MeshInstance3D = MeshInstance3D.new()
			var cm: CylinderMesh = CylinderMesh.new()
			cm.top_radius = 0.03
			cm.bottom_radius = 0.32
			cm.height = 0.85
			cm.radial_segments = 10
			cm.material = _mat(Color("#ff8a1f"))
			cone.mesh = cm
			cone.position = Vector3(0, 0.43, 0)
			n.add_child(cone)
			var band: MeshInstance3D = MeshInstance3D.new()
			var bm: CylinderMesh = CylinderMesh.new()
			bm.top_radius = 0.2
			bm.bottom_radius = 0.25
			bm.height = 0.14
			bm.radial_segments = 10
			bm.material = _mat(Color(1, 1, 1))
			band.mesh = bm
			band.position = Vector3(0, 0.45, 0)
			n.add_child(band)
		"T":
			n.add_child(make_car3d(Color(0.55, 0.58, 0.62), false))
	return n


## Se llama al (re)empezar la carrera: crea coches y objetos a partir del estado del juego.
func rebuild() -> void:
	for n: Node3D in _items:
		n.queue_free()
	for n: Node3D in _rivals:
		n.queue_free()
	if _car != null:
		_car.queue_free()
	_items.clear()
	_rivals.clear()
	_coins.clear()
	for it: Dictionary in game.get("items"):
		var n: Node3D = _make_item3d(str(it["kind"]))
		add_child(n)
		n.position = pos(float(it["d"]), float(it["lat"]))
		_items.append(n)
	var colors: Array = (game.get_script() as Script).get_script_constant_map()["RIVAL_COLORS"]
	var names: Array = Kit.param("texts.rivals", ["Rojo", "Azul", "Verde"])
	var rivals: Array = game.get("rivals")
	## Corredores con el arte del juego (caracoles, ranas, naves...): sin arte, coches.
	var rival_art: Array[Dictionary] = []
	for role: String in ["walker", "flyer", "spiky"]:
		var e: Dictionary = Kit.sprite_entry(str(Kit.param("art.enemies." + role, "")))
		if not e.is_empty():
			rival_art.append(e)
	for k: int in rivals.size():
		var car: Node3D
		if not rival_art.is_empty():
			car = rider3d(rival_art[k % rival_art.size()], 2.2)
		elif not Kit.sprite_by_role("jugador").is_empty():
			## Sin arte de rivales: el mismo corredor del jugador teñido de otro color (todos del mismo mundo).
			car = rider3d(Kit.sprite_by_role("jugador"), 2.2)
			(car.get_node("Rider") as AnimatedSprite3D).modulate = Color.WHITE.lerp(colors[k % colors.size()], 0.55)
		else:
			car = make_car3d(colors[k % colors.size()], false)
		var tag: Label3D = Label3D.new()
		tag.text = str(names[k % names.size()])
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		## Nombre pequeño encima (antes tapaba media pantalla al pasar cerca).
		tag.font_size = 40
		tag.pixel_size = 0.006
		tag.outline_size = 12
		tag.position = Vector3(0, 2.7 if car.get_node_or_null("Rider") != null else 1.9, 0)
		tag.no_depth_test = false
		car.add_child(tag)
		add_child(car)
		_rivals.append(car)
	var hero: Dictionary = Kit.sprite_by_role("jugador")
	_car = rider3d(hero, 2.3) if not hero.is_empty() else make_car3d(Skins.recolor(Kit.color("accent", Color.ORANGE)), true)
	add_child(_car)
	_last_crashes = int(game.get("crashes"))
	_cam_x = pos(float(game.get("d")), float(game.get("lat"))).x
	sync()


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


## Cada fotograma de fisica: coloca todo segun el estado de la carrera.
func sync() -> void:
	if _car == null:
		return
	var d: float = game.get("d")
	var lat: float = game.get("lat")
	var bot_lat: float = game.get("bot_lat")
	var steer: float = (float(game.call("steer_input")) if bot_lat == INF else signf(bot_lat - lat))
	_car.position = pos(d, lat)
	var ahead: Vector3 = pos(d + 60.0, lat)
	_car.look_at(ahead + Vector3(0, 0, 0), Vector3.UP)
	_car.rotate_object_local(Vector3.UP, -steer * 0.12)
	_car.rotate_object_local(Vector3.FORWARD, steer * 0.05)
	var rivals: Array = game.get("rivals")
	for k: int in mini(rivals.size(), _rivals.size()):
		var r: Dictionary = rivals[k]
		var rd: float = float(r["d"])
		_rivals[k].position = pos(rd, float(r["lat"]))
		_rivals[k].look_at(pos(rd + 60.0, float(r["lat"])), Vector3.UP)
	var items: Array = game.get("items")
	for k: int in mini(items.size(), _items.size()):
		var it: Dictionary = items[k]
		var n: Node3D = _items[k]
		var dd: float = float(it["d"]) - d
		var near: bool = dd > -VIEW_BEHIND / SZ and dd < VIEW_AHEAD / SZ
		var kind: String = str(it["kind"])
		if kind == "C" or kind == "N":
			n.visible = near and bool(it["alive"])
		else:
			n.visible = near
			if not bool(it["alive"]) and n.rotation.z == 0.0:
				## Un cono golpeado sale volando de lado; un coche lento queda cruzado.
				n.rotation = Vector3(0, 0.9, 1.2 if kind == "O" else 0.0)
		if kind == "T" and near:
			n.position = pos(float(it["d"]), float(it["lat"]))
	var crashes: int = game.get("crashes")
	if crashes > _last_crashes and not bool(game.get("fast")):
		shake(0.45)
	_last_crashes = crashes
	_update_camera(d, lat)


func _update_camera(d: float, lat: float) -> void:
	var target: Vector3 = pos(d, lat)
	_cam_x = lerpf(_cam_x, target.x, 0.12)
	var behind: Vector3 = pos(d - 190.0, 0.0)
	var cam_pos: Vector3 = Vector3(lerpf(behind.x, _cam_x, 0.65), 3.0, behind.z)
	if _shake > 0.0:
		cam_pos += Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * _shake * 0.4
		_shake = maxf(_shake - 0.03, 0.0)
	_camera.position = cam_pos
	var look: Vector3 = pos(d + 420.0, lat * 0.5, 0.6)
	_camera.look_at(look, Vector3.UP)
	var consts: Dictionary = (game.get_script() as Script).get_script_constant_map()
	var speed_k: float = clampf(float(game.get("speed")) / float(consts["MAX_SPEED"]), 0.0, 1.6)
	var boost: float = 8.0 if float(game.get("boost_left")) > 0.0 else 0.0
	_camera.fov = lerpf(_camera.fov, 60.0 + 12.0 * speed_k + boost, 0.08)


func _process(delta: float) -> void:
	_spin += delta * 3.0
	for c: Node3D in _coins:
		if c.visible:
			c.rotation.y = _spin
