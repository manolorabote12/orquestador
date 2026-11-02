class_name Survival3DView
extends Node3D
## Vista 3D de la supervivencia (game.json -> "view": "3d"). Solo dibuja: las reglas, el bot y el
## analizador son los de survival_map.gd, asi que todo lo validado en 2D sigue valiendo.
## 1 - La isla en bloques bajos (una casilla = 1 m): mar, arena y hierba; las charcas, hundidas.
## 2 - Arboles, rocas, hierba alta, arbustos con bayas, guaridas y restos en low-poly (MultiMesh).
## 3 - El jugador y los lobos con el arte del juego (figuras que miran a la camara) o, si no hay
##     arte, hechos con formas.
## 4 - Dia y noche: el sol baja y el cielo se oscurece; la hoguera alumbra de verdad (luz naranja).
## 5 - Camara alta en diagonal que sigue al jugador (la vista de los survival de movil).

const M = preload("res://kit/survival/survival_map.gd")
const H_SAND: float = 0.0
const H_GRASS: float = 0.08
const H_POND: float = -0.14
const H_SEA: float = -0.32
const CAM_OFF: Vector3 = Vector3(0.0, 9.0, 6.4)

var game: Node2D
var _camera: Camera3D
var _sun: DirectionalLight3D
var _env: Environment
var _sky: ProceduralSkyMaterial
var _props: Node3D
var _player: Node3D
var _player_spr: AnimatedSprite3D = null
var _wolves: Dictionary = {}
var _fire: Node3D
var _flame: MeshInstance3D
var _fire_light: OmniLight3D
var _me_light: OmniLight3D
var _t: float = 0.0


func setup(g: Node2D) -> void:
	game = g
	name = "View3D"
	_build_environment()
	add_child(_build_ground())
	_props = Node3D.new()
	_props.name = "Props3D"
	add_child(_props)
	rebuild_props()
	_build_player()
	_build_fire()
	_camera = Camera3D.new()
	_camera.name = "Camera3D"
	_camera.fov = 48.0
	_camera.keep_aspect = Camera3D.KEEP_WIDTH
	_camera.far = 300.0
	add_child(_camera)
	_camera.make_current()
	sync(1.0)


func st() -> Dictionary:
	return game.get("st")


func h_of(ch: String) -> float:
	match ch:
		"~":
			return H_SEA
		"W":
			return H_POND
		",":
			return H_SAND
	return H_GRASS


func at(p: Vector2, y: float = 0.0) -> Vector3:
	return Vector3(p.x, y, p.y)


static func mat(col: Color, emission: float = 0.0) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.9
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emission
	return m


# ------------------------------------------------------------------ escenario

func _build_environment() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	_sky = ProceduralSkyMaterial.new()
	_sky.sky_top_color = Color("#3b8fd9")
	_sky.sky_horizon_color = Color("#bfe3f7")
	_sky.ground_horizon_color = Color("#bfe3f7")
	_sky.ground_bottom_color = Color("#1f6fa8")
	var sky: Sky = Sky.new()
	sky.sky_material = _sky
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color.WHITE
	_env.ambient_light_energy = 0.28
	_env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = _env
	add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-58.0, 30.0, 0.0)
	_sun.light_energy = 0.5
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 40.0
	add_child(_sun)
	## Mar hasta el horizonte.
	var sea: MeshInstance3D = MeshInstance3D.new()
	sea.name = "Sea"
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(400, 400)
	pm.material = mat(Color("#1f6fa8"))
	sea.mesh = pm
	var s0: Dictionary = st()
	sea.position = Vector3(float(s0["w"]) * 0.5, H_SEA, float(s0["h"]) * 0.5)
	add_child(sea)


## Isla: la cara de arriba de cada casilla y sus lados donde la vecina esta mas baja.
func _build_ground() -> MeshInstance3D:
	var s0: Dictionary = st()
	var w: int = int(s0["w"])
	var h: int = int(s0["h"])
	var stl: SurfaceTool = SurfaceTool.new()
	stl.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sand: Color = M.pal(s0, "sand", Color("#e8d39a"))
	var grass: Color = Kit.color("ground", Color("#6fae4f"))
	if grass.get_luminance() < 0.25 or grass.s < 0.2:
		grass = Color("#6fae4f")
	grass = M.pal(s0, "ground", grass)
	## Con luz y sol la hierba se aclara: un poco mas apagada que en 2D.
	grass = grass.darkened(0.14)
	grass.s = minf(grass.s, 0.62)
	for y: int in h:
		for x: int in w:
			var ch: String = M.tile(s0, Vector2i(x, y))
			if ch == "~":
				continue
			var top: float = h_of(ch)
			var col: Color = Color("#3fa7e0") if bool(M.tile_def(s0, ch).get("water", false)) else (sand if ch == "," else grass.lightened(float((x * 73 + y * 151) % 7) / 7.0 * 0.07))
			_quad(stl, Vector3(x, top, y), Vector3(x + 1, top, y), Vector3(x + 1, top, y + 1), Vector3(x, top, y + 1), col, Vector3.UP)
			## Lados: hasta la altura de la vecina (o del mar).
			for d: Vector2i in M.DIRS:
				var nb: float = h_of(M.tile(s0, Vector2i(x, y) + d))
				if nb >= top:
					continue
				var side: Color = (sand if ch != "W" else Color("#2b7fb3")).darkened(0.25)
				var a: Vector3
				var b: Vector3
				if d == Vector2i(1, 0):
					a = Vector3(x + 1, 0, y + 1)
					b = Vector3(x + 1, 0, y)
				elif d == Vector2i(-1, 0):
					a = Vector3(x, 0, y)
					b = Vector3(x, 0, y + 1)
				elif d == Vector2i(0, 1):
					a = Vector3(x, 0, y + 1)
					b = Vector3(x + 1, 0, y + 1)
				else:
					a = Vector3(x + 1, 0, y)
					b = Vector3(x, 0, y)
				_quad(stl, Vector3(a.x, top, a.z), Vector3(b.x, top, b.z), Vector3(b.x, nb, b.z), Vector3(a.x, nb, a.z), side, Vector3(d.x, 0, d.y))
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.95
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Island"
	var mesh: ArrayMesh = stl.commit()
	mesh.surface_set_material(0, m)
	mi.mesh = mesh
	return mi


func _quad(stl: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, n: Vector3) -> void:
	for v: Vector3 in [a, b, c, a, c, d]:
		stl.set_color(col)
		stl.set_normal(n)
		stl.add_vertex(v)


## Arboles, rocas, hierba, arbustos y bayas, guaridas y restos (se rehace al agotarse algo).
func rebuild_props() -> void:
	## Fuera del arbol ya (si no, los nuevos no podrian llevar el mismo nombre este fotograma).
	for c0: Node in _props.get_children():
		_props.remove_child(c0)
		c0.queue_free()
	var s0: Dictionary = st()
	var trunks: Array[Transform3D] = []
	var crowns: Array[Transform3D] = []
	var crown_c: Array[Color] = []
	var rocks: Array[Transform3D] = []
	var rock_c: Array[Color] = []
	var tufts: Array[Transform3D] = []
	var bushes: Array[Transform3D] = []
	var berries: Array[Transform3D] = []
	var dens: Array[Transform3D] = []
	var crates: Array[Transform3D] = []
	var houses: Array[Transform3D] = []
	var house_c: Array[Color] = []
	var roofs: Array[Transform3D] = []
	var cars: Array[Transform3D] = []
	var car_c: Array[Color] = []
	var walls: Array[Transform3D] = []
	## Casas y coches saqueados siguen ahi (sin "res"): tambien se dibujan.
	var spots: Dictionary = {}
	for c: Vector2i in s0["res"]:
		spots[c] = s0["res"][c]
	for y: int in int(s0["h"]):
		for x: int in int(s0["w"]):
			var cc: Vector2i = Vector2i(x, y)
			if not spots.has(cc) and M.look(s0, M.tile(s0, cc)) in ["H", "C"]:
				spots[cc] = {"kind": M.tile(s0, cc), "left": 0, "done": true}
	for c: Vector2i in spots:
		var r: Dictionary = spots[c]
		var p: Vector3 = at(M.center(c), H_GRASS)
		var k: int = (c.x * 31 + c.y * 17) % 7
		var rot: Basis = Basis(Vector3.UP, float(k) * 0.9)
		var kind: String = str(r["kind"])
		match M.look(s0, kind):
			"H":
				houses.append(Transform3D(Basis(), p + Vector3(0, 0.45, 0)))
				house_c.append(Color("#b7a58c") if not r.has("done") else Color("#8a8178"))
				roofs.append(Transform3D(Basis(Vector3.UP, PI * 0.25), p + Vector3(0, 1.05, 0)))
			"C":
				cars.append(Transform3D(rot, p + Vector3(0, 0.25, 0)))
				car_c.append(Color("#c0543c") if not r.has("done") else Color("#7d6e66"))
			"T":
				var s: float = 0.75 + 0.25 * float(r["left"]) / float(M.tile_yield(s0, kind))
				trunks.append(Transform3D(rot, p + Vector3(0, 0.35, 0)))
				crowns.append(Transform3D(rot.scaled(Vector3(s, s, s)), p + Vector3(0, 0.95 * s + 0.2, 0)))
				crowns.append(Transform3D(rot.scaled(Vector3(s * 0.72, s * 0.72, s * 0.72)), p + Vector3(0, 1.45 * s + 0.2, 0)))
				var g: Color = M.tint(s0, kind, Color("#2f7d32")).lerp(M.tint(s0, kind, Color("#4caf50")).lightened(0.15), float(k) / 7.0)
				crown_c.append(g.darkened(0.1))
				crown_c.append(g.lightened(0.08))
			"R":
				rocks.append(Transform3D(rot.scaled(Vector3(0.75, 0.45, 0.6)), p + Vector3(0, 0.2, 0)))
				rocks.append(Transform3D(rot.rotated(Vector3.UP, 0.7).scaled(Vector3(0.4, 0.3, 0.35)), p + Vector3(0.18, 0.42, 0.05)))
				rock_c.append(Color("#8d96a0"))
				rock_c.append(Color("#b4bcc5"))
			"G":
				for j: int in 4:
					var o: Vector3 = Vector3(cos(float(j) * 1.7 + float(k)), 0, sin(float(j) * 1.7 + float(k))) * 0.2
					tufts.append(Transform3D(Basis(Vector3(1, 0, 0), 0.15 * float(j - 2)), p + o + Vector3(0, 0.22, 0)))
			"B":
				bushes.append(Transform3D(rot, p + Vector3(0, 0.25, 0)))
				for j2: int in int(r["left"]):
					var a2: float = float(j2) * 2.1 + float(k)
					berries.append(Transform3D(Basis(), p + Vector3(cos(a2) * 0.28, 0.38 + 0.08 * float(j2 % 2), sin(a2) * 0.28)))
			"X":
				crates.append(Transform3D(rot, p + Vector3(0, 0.2, 0)))
	for d: Vector2i in s0["dens"]:
		dens.append(Transform3D(Basis().scaled(Vector3(1.1, 0.65, 1.1)), at(M.center(d), H_SAND)))
	_multi("Trunks", trunks, [], _box(Vector3(0.18, 0.7, 0.18)), mat(Color("#7a4b2a")))
	_multi("Crowns", crowns, crown_c, _cone(0.48, 0.85, 6), null)
	_multi("Rocks", rocks, rock_c, _box(Vector3(1, 1, 1)), null)
	_multi("Tufts", tufts, [], _cone(0.07, 0.45, 4), mat(Color("#8bc34a")))
	_multi("Bushes", bushes, [], _sphere(0.34, 6), mat(M.tint(s0, "B", Color("#3e8e41"))))
	_multi("Berries", berries, [], _sphere(0.08, 5), mat(Color("#e53950"), 0.3))
	_multi("Dens", dens, [], _sphere(0.6, 7), mat(Color("#4e4036")))
	_multi("Crates", crates, [], _box(Vector3(0.6, 0.4, 0.45)), mat(Color("#a8743f")))
	_multi("Houses", houses, house_c, _box(Vector3(0.9, 0.9, 0.9)), null)
	_multi("Roofs", roofs, [], _cone(0.72, 0.45, 4), mat(Color("#7b3f2e")))
	_multi("Cars", cars, car_c, _box(Vector3(0.9, 0.42, 0.5)), null)
	for bc: Vector2i in s0["built"]:
		walls.append(Transform3D(Basis(), at(M.center(bc), H_GRASS) + Vector3(0, 0.45, 0)))
	_multi("Walls", walls, [], _box(Vector3(0.98, 0.9, 0.98)), mat(Color("#8d6e63")))
	## Boca de cada guarida (y ojos que brillan de noche).
	for d2: Vector2i in s0["dens"]:
		var hole: MeshInstance3D = MeshInstance3D.new()
		hole.mesh = _box(Vector3(0.5, 0.36, 0.08))
		hole.material_override = mat(Color("#120c0c"))
		hole.position = at(M.center(d2), H_SAND + 0.22) + Vector3(0, 0, 0.6)
		_props.add_child(hole)


func _multi(nm: String, xf: Array[Transform3D], cols: Array[Color], mesh: Mesh, m: Material) -> void:
	if xf.is_empty():
		return
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not cols.is_empty()
	if m != null:
		mesh.surface_set_material(0, m)
	elif mm.use_colors:
		var vm: StandardMaterial3D = StandardMaterial3D.new()
		vm.vertex_color_use_as_albedo = true
		vm.vertex_color_is_srgb = true
		vm.roughness = 0.9
		mesh.surface_set_material(0, vm)
	mm.mesh = mesh
	mm.instance_count = xf.size()
	for i: int in xf.size():
		mm.set_instance_transform(i, xf[i])
		if mm.use_colors:
			mm.set_instance_color(i, cols[i])
	var mi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mi.name = nm
	mi.multimesh = mm
	_props.add_child(mi)


static func _box(size: Vector3) -> ArrayMesh:
	var b: BoxMesh = BoxMesh.new()
	b.size = size
	return _to_array(b)


static func _cone(r: float, hgt: float, seg: int) -> ArrayMesh:
	var c: CylinderMesh = CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = r
	c.height = hgt
	c.radial_segments = seg
	c.rings = 1
	return _to_array(c)


static func _sphere(r: float, seg: int) -> ArrayMesh:
	var s: SphereMesh = SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = seg
	s.rings = maxi(3, seg / 2)
	return _to_array(s)


## Mallas con su propio material por superficie (para que cada MultiMesh tenga el suyo).
static func _to_array(p: PrimitiveMesh) -> ArrayMesh:
	var am: ArrayMesh = ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, p.get_mesh_arrays())
	return am


# ------------------------------------------------------------------ personajes y hoguera

func _figure(entry: Dictionary, height_m: float, anim: String) -> AnimatedSprite3D:
	var spr: AnimatedSprite3D = AnimatedSprite3D.new()
	spr.sprite_frames = SpriteKit.frames_de(entry)
	var celda: Array = entry.get("celda", [32, 32])
	spr.pixel_size = height_m / (float(celda[1]) * 0.86)
	spr.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	spr.shaded = false
	spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	spr.position = Vector3(0, height_m * 0.5, 0)
	if spr.sprite_frames.has_animation(anim):
		spr.play(anim)
	return spr


func _shadow(r: float) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = 0.01
	cm.radial_segments = 12
	var m: StandardMaterial3D = mat(Color(0, 0, 0, 0.3))
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cm.material = m
	mi.mesh = cm
	mi.position = Vector3(0, 0.02, 0)
	return mi


func _build_player() -> void:
	_player = Node3D.new()
	_player.name = "Player3D"
	add_child(_player)
	_player.add_child(_shadow(0.3))
	var art: Dictionary = Kit.sprite_by_role("jugador")
	if not art.is_empty():
		_player_spr = _figure(art, 1.4, "idle")
		_player.add_child(_player_spr)
	else:
		var body: MeshInstance3D = MeshInstance3D.new()
		var cap: CapsuleMesh = CapsuleMesh.new()
		cap.radius = 0.24
		cap.height = 0.9
		cap.material = mat(Kit.color("player", Kit.color("accent", Color.ORANGE)))
		body.mesh = cap
		body.position = Vector3(0, 0.45, 0)
		_player.add_child(body)
	_me_light = OmniLight3D.new()
	_me_light.light_color = Color("#c9d8ff")
	_me_light.omni_range = 2.6
	_me_light.light_energy = 0.0
	_me_light.position = Vector3(0, 1.4, 0)
	_player.add_child(_me_light)


func _wolf_node(id: int, kind: String = "wolf") -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Wolf3D%d" % id
	root.add_child(_shadow(0.32))
	var cdef: Dictionary = (st()["cat"]["creatures"] as Dictionary).get(kind, {})
	var hostile: bool = bool(cdef.get("hostile", true))
	var lk: String = str(cdef.get("look", "wolf"))
	var id_art: String = str(Kit.param("art.enemies.walker", "")) if hostile else ""
	var entry: Dictionary = Kit.sprite_entry(id_art) if id_art != "" else {}
	if entry.is_empty():
		entry = Kit.sprite_by_role("enemigo" if hostile else "presa")
	var col: Color = Color.from_string(str(cdef.get("color", "#5b6270")), Color("#5b6270"))
	if not entry.is_empty():
		var spr: AnimatedSprite3D = _figure(entry, 1.15, "run")
		spr.name = "Art"
		root.add_child(spr)
	elif lk == "zombie":
		## Zombi: cuerpo, cabeza verdosa y brazos por delante.
		for zp: Array in [[Vector3(0.3, 0.6, 0.36), Vector3(0, 0.55, 0), Color("#5d6b8a")], [Vector3(0.3, 0.3, 0.3), Vector3(0.04, 1.02, 0), col],
				[Vector3(0.45, 0.09, 0.09), Vector3(0.3, 0.75, 0.13), col.darkened(0.1)], [Vector3(0.45, 0.09, 0.09), Vector3(0.3, 0.75, -0.13), col.darkened(0.1)],
				[Vector3(0.11, 0.3, 0.11), Vector3(0, 0.15, 0.09), Color("#3e4a63")], [Vector3(0.11, 0.3, 0.11), Vector3(0, 0.15, -0.09), Color("#3e4a63")]]:
			var zm: MeshInstance3D = MeshInstance3D.new()
			var zb: BoxMesh = BoxMesh.new()
			zb.size = zp[0]
			zb.material = mat(zp[2])
			zm.mesh = zb
			zm.position = zp[1]
			root.add_child(zm)
		for ez: float in [0.07, -0.07]:
			var zeye: MeshInstance3D = MeshInstance3D.new()
			zeye.mesh = _sphere(0.035, 6)
			zeye.material_override = mat(Color("#ff5252"), 3.0)
			zeye.position = Vector3(0.2, 1.06, ez)
			root.add_child(zeye)
	else:
		var c: Color = col if cdef.has("color") else Color("#5b6270")
		var legs: bool = lk == "beast"
		var parts: Array = [[Vector3(0.7, 0.32, 0.32), Vector3(0, 0.36 + (0.12 if legs else 0.0), 0)], [Vector3(0.3, 0.28, 0.28), Vector3(0.42, 0.5 + (0.12 if legs else 0.0), 0)],
				[Vector3(0.08, 0.16, 0.08), Vector3(0.48, 0.7, 0.08)], [Vector3(0.08, 0.16, 0.08), Vector3(0.48, 0.7, -0.08)]]
		if legs:
			for lx: float in [-0.25, 0.25]:
				for lz: float in [-0.1, 0.1]:
					parts.append([Vector3(0.07, 0.3, 0.07), Vector3(lx, 0.15, lz)])
		for part: Array in parts:
			var mi: MeshInstance3D = MeshInstance3D.new()
			var bm: BoxMesh = BoxMesh.new()
			bm.size = part[0]
			bm.material = mat(c)
			mi.mesh = bm
			mi.position = part[1]
			root.add_child(mi)
		var eye: MeshInstance3D = MeshInstance3D.new()
		eye.mesh = _sphere(0.04, 6)
		eye.material_override = mat(Color("#ffe066"), 3.0) if hostile else mat(Color("#1a1a1a"))
		eye.position = Vector3(0.58, 0.55 + (0.12 if legs else 0.0), 0.06)
		root.add_child(eye)
	add_child(root)
	return root


func _build_fire() -> void:
	_fire = Node3D.new()
	_fire.name = "Fire3D"
	_fire.visible = false
	add_child(_fire)
	for k: int in 7:
		var stone: MeshInstance3D = MeshInstance3D.new()
		stone.mesh = _box(Vector3(0.14, 0.1, 0.12))
		stone.material_override = mat(Color("#8d96a0"))
		var a: float = TAU * float(k) / 7.0
		stone.position = Vector3(cos(a) * 0.32, H_GRASS + 0.05, sin(a) * 0.32)
		_fire.add_child(stone)
	for k2: int in 2:
		var log_mi: MeshInstance3D = MeshInstance3D.new()
		log_mi.mesh = _box(Vector3(0.5, 0.08, 0.1))
		log_mi.material_override = mat(Color("#6d4422"))
		log_mi.position = Vector3(0, H_GRASS + 0.08, 0)
		log_mi.rotation.y = 0.8 + float(k2) * 1.6
		_fire.add_child(log_mi)
	_flame = MeshInstance3D.new()
	_flame.mesh = _cone(0.18, 0.5, 6)
	_flame.material_override = mat(Color("#ff8a1a"), 4.0)
	_flame.position = Vector3(0, H_GRASS + 0.32, 0)
	_fire.add_child(_flame)
	_fire_light = OmniLight3D.new()
	_fire_light.light_color = Color("#ffb347")
	_fire_light.omni_range = M.FIRE_R * 1.35
	_fire_light.light_energy = 0.0
	_fire_light.position = Vector3(0, 0.9, 0)
	_fire.add_child(_fire_light)


# ------------------------------------------------------------------ cada fotograma

## Oscuridad 0..1 (0 dia, 1 noche cerrada), con el atardecer y el amanecer suaves.
func darkness() -> float:
	var s0: Dictionary = st()
	var cyc: float = float(s0["day"]) + float(s0["night"])
	var f: float = fmod(float(s0["t"]), cyc)
	if f >= float(s0["day"]):
		return clampf((f - float(s0["day"])) / 4.0, 0.0, 1.0) * clampf((cyc - f) / 4.0, 0.0, 1.0)
	if float(s0["day"]) - f < 8.0:
		return (8.0 - (float(s0["day"]) - f)) / 8.0 * 0.35
	return 0.0


func sync(delta: float) -> void:
	var s0: Dictionary = st()
	if s0.is_empty():
		return
	var me: Dictionary = s0["me"]
	var mp: Vector3 = at(me["p"], H_GRASS if M.tile(s0, M.cell_of(me["p"])) != "," else H_SAND)
	_player.position = mp
	if _player_spr != null:
		var face: Vector2 = me["face"]
		if absf(face.x) > 0.2:
			_player_spr.flip_h = face.x < 0.0
		var moving: bool = (me["job"] as Dictionary).is_empty() and float(game.get("_t")) > 0.0
		var anim: String = "run" if moving and _player_spr.sprite_frames.has_animation("run") else "idle"
		if _player_spr.sprite_frames.has_animation(anim) and _player_spr.animation != anim:
			_player_spr.play(anim)
		_player_spr.rotation.z = sin(_t * 18.0) * 0.1 if not (me["job"] as Dictionary).is_empty() else 0.0
		_player_spr.modulate = Color(1.6, 0.6, 0.6) if float(me["hurt"]) > 0.0 else Color.WHITE
	## Lobos.
	var alive: Dictionary = {}
	for wf: Dictionary in s0["wolves_list"]:
		var id: int = int(wf["id"])
		alive[id] = true
		var n: Node3D = _wolves.get(id) as Node3D
		var wp: Vector3 = at(wf["p"], H_GRASS)
		if n == null:
			n = _wolf_node(id, str(wf.get("kind", "wolf")))
			_wolves[id] = n
			n.position = wp
		var dx: float = wp.x - n.position.x
		var dz: float = wp.z - n.position.z
		n.position = wp
		var art: AnimatedSprite3D = n.get_node_or_null("Art") as AnimatedSprite3D
		if art != null:
			if absf(dx) > 0.002:
				art.flip_h = dx < 0.0
		elif Vector2(dx, dz).length() > 0.002:
			n.rotation.y = -atan2(dz, dx)
		n.visible = not bool(wf["leaving"]) or int(_t * 8.0) % 2 == 0
	for id2: int in _wolves.keys():
		if not alive.has(id2):
			(_wolves[id2] as Node).queue_free()
			_wolves.erase(id2)
	## Hoguera.
	var fire: Dictionary = s0["fire"]
	_fire.visible = not fire.is_empty()
	var on: bool = M.fire_on(s0)
	var dark: float = darkness()
	if not fire.is_empty():
		_fire.position = at(fire["p"], 0.0)
		_flame.visible = on
		var fl: float = 1.0 + sin(_t * 14.0) * 0.12
		_flame.scale = Vector3(1.0, fl, 1.0)
		_fire_light.light_energy = (2.2 + sin(_t * 9.0) * 0.2) * (0.25 + dark) if on else 0.0
	## Dia y noche.
	_sun.light_energy = lerpf(0.5, 0.04, dark)
	_env.ambient_light_energy = lerpf(0.3, 0.06, dark)
	_env.ambient_light_color = Color.WHITE.lerp(Color("#5866a8"), dark)
	_sky.sky_top_color = Color("#3b8fd9").lerp(Color("#0b1030"), dark)
	_sky.sky_horizon_color = Color("#bfe3f7").lerp(Color("#27305a"), dark)
	_me_light.light_energy = 0.9 * dark
	## Camara: alta y en diagonal, siguiendo al jugador.
	var want: Vector3 = mp + CAM_OFF
	_camera.position = _camera.position.lerp(want, minf(1.0, delta * 5.0)) if delta < 0.5 else want
	_camera.look_at(_camera.position - CAM_OFF + Vector3(0, 0.4, 0), Vector3.UP)


## Donde se ve en pantalla un punto de la isla (para los textos que flotan).
func screen_pos(p: Vector2) -> Vector2:
	if _camera == null:
		return Vector2.ZERO
	return _camera.unproject_position(at(p, 1.3))


func _process(delta: float) -> void:
	_t += delta
