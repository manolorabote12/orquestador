extends Node3D
## Vista 3D del battle royale (game.json -> "view": "3d"): solo dibuja. La isla, los jugadores, el
## botin, las balas y la zona salen del mismo estado que la vista 2D (royale_map.gd), asi que el
## analizador, los bots y el modo en directo no cambian. Camara de persecucion con angulo fijo
## (como los battle royale y brawlers de movil): arriba sigue siendo el norte y los mandos igual.
## Escala: un pixel de la logica = 1/32 m (una casilla de 64 px = 2 m).

const M = preload("res://kit/royale/royale_map.gd")
const K: float = 1.0 / 32.0
const MAX_BULLETS: int = 256
const MAX_FX: int = 200

var game: Node = null
var _cam: Camera3D
var _agents: Array = []
var _loot_root: Node3D
var _loot_sig: String = ""
var _bullets: MultiMeshInstance3D
var _tracers: MultiMeshInstance3D
var _fx: MultiMeshInstance3D
var _zone: MeshInstance3D
var _next: MeshInstance3D
var _plane: Node3D
var _hurt_rect: ColorRect
var _t: float = 0.0


static func mat(col: Color, emission: float = 0.0, unshaded: bool = false) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.85
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emission
	if col.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


static func to3(p: Vector2, y: float = 0.0) -> Vector3:
	return Vector3(p.x * K, y, p.y * K)


func setup(g: Node) -> void:
	game = g
	name = "View3D"
	_build_env()
	_build_island()
	_build_dynamic()
	sync(0.0)


func _st() -> Dictionary:
	return game.get("st")


# ------------------------------------------------------------------ escenario

func _build_env() -> void:
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sm: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("#4a90d9")
	sm.sky_horizon_color = Color("#bfe0ff")
	sm.ground_horizon_color = Color("#bfe0ff")
	sm.ground_bottom_color = Color("#2f7fb8")
	var sky: Sky = Sky.new()
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.2
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58.0, -25.0, 0.0)
	sun.light_energy = 0.42
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 45.0
	add_child(sun)
	_cam = Camera3D.new()
	_cam.fov = 55.0
	_cam.far = 400.0
	add_child(_cam)
	_cam.make_current()
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_hurt_rect = ColorRect.new()
	_hurt_rect.color = Color(1, 0, 0, 0)
	_hurt_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hurt_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_hurt_rect)


func _hash(x: int, y: int) -> int:
	return absi((x * 73856093) ^ (y * 19349663)) % 1000


## Suelo de una pieza (con un poco de variacion), muros, arboles y rocas.
func _build_island() -> void:
	var st: Dictionary = _st()
	var w: int = int(st["w"])
	var h: int = int(st["h"])
	var tile: float = M.TILE * K
	var sea: MeshInstance3D = MeshInstance3D.new()
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(w * tile + 400.0, h * tile + 400.0)
	pm.material = mat(Color("#2f7fb8"))
	sea.mesh = pm
	sea.name = "Sea"
	sea.position = Vector3(w * tile * 0.5, -0.35, h * tile * 0.5)
	add_child(sea)
	var stool: SurfaceTool = SurfaceTool.new()
	stool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var walls: Array[Vector3] = []
	var trees: Array[Vector3] = []
	var rocks: Array[Vector3] = []
	for y: int in h:
		for x: int in w:
			var c: String = M.cell(st, x, y)
			if c == "~":
				continue
			var hh: int = _hash(x, y)
			var col: Color = Color("#4c8f3a") if hh % 7 != 0 else Color("#478a36")
			var top: float = 0.0
			match c:
				",":
					col = Color("#e8d39a")
					top = -0.08
				"_":
					col = Color("#a8794c") if (x + y) % 2 == 0 else Color("#9c6f45")
					top = 0.04
				"#":
					col = Color("#757a88")
					walls.append(Vector3((x + 0.5) * tile, 0, (y + 0.5) * tile))
				"t":
					trees.append(Vector3((x + 0.5) * tile, 0, (y + 0.5) * tile))
				"r":
					rocks.append(Vector3((x + 0.5) * tile, 0, (y + 0.5) * tile))
			var a: Vector3 = Vector3(x * tile, top, y * tile)
			var corners: Array[Vector3] = [a, a + Vector3(tile, 0, 0), a + Vector3(tile, 0, tile), a + Vector3(0, 0, tile)]
			for k: int in [0, 1, 2, 0, 2, 3]:
				stool.set_color(col)
				stool.set_normal(Vector3.UP)
				stool.add_vertex(corners[k])
			## Borde de la isla hacia el agua: una pared de tierra.
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if M.cell(st, x + d.x, y + d.y) != "~":
					continue
				var e0: Vector3
				var e1: Vector3
				if d.x == 1:
					e0 = a + Vector3(tile, 0, 0)
					e1 = a + Vector3(tile, 0, tile)
				elif d.x == -1:
					e0 = a + Vector3(0, 0, tile)
					e1 = a
				elif d.y == 1:
					e0 = a + Vector3(tile, 0, tile)
					e1 = a + Vector3(0, 0, tile)
				else:
					e0 = a
					e1 = a + Vector3(tile, 0, 0)
				var down: Vector3 = Vector3(0, -0.6 - top, 0)
				var side: Color = Color("#c9b27a")
				var quad: Array[Vector3] = [e0, e1, e1 + down, e0 + down]
				for k2: int in [0, 1, 2, 0, 2, 3]:
					stool.set_color(side)
					stool.set_normal(Vector3(d.x, 0, d.y))
					stool.add_vertex(quad[k2])
	var ground: MeshInstance3D = MeshInstance3D.new()
	ground.name = "Island"
	var gm: StandardMaterial3D = mat(Color.WHITE)
	gm.vertex_color_use_as_albedo = true
	gm.vertex_color_is_srgb = true
	var mesh: ArrayMesh = stool.commit()
	mesh.surface_set_material(0, gm)
	ground.mesh = mesh
	add_child(ground)
	_multi("Walls", walls, _box_mesh(Vector3(tile, 2.6, tile), Color("#8c919e")), Vector3(0, 1.3, 0))
	_multi("Trunks", trees, _cyl_mesh(0.22, 1.6, Color("#6b4a2b")), Vector3(0, 0.8, 0))
	_multi("Canopies", trees, _sphere_mesh(1.35, Color("#2a7a36")), Vector3(0, 2.4, 0))
	_multi("Rocks", rocks, _sphere_mesh(0.9, Color("#8e939c")), Vector3(0, 0.35, 0), Vector3(1.0, 0.7, 0.9))


func _box_mesh(size: Vector3, col: Color) -> BoxMesh:
	var b: BoxMesh = BoxMesh.new()
	b.size = size
	b.material = mat(col)
	return b


func _cyl_mesh(r: float, hgt: float, col: Color) -> CylinderMesh:
	var c: CylinderMesh = CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = hgt
	c.radial_segments = 10
	c.material = mat(col)
	return c


func _sphere_mesh(r: float, col: Color) -> SphereMesh:
	var s: SphereMesh = SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 12
	s.rings = 6
	s.material = mat(col)
	return s


func _multi(nm: String, at: Array[Vector3], mesh: Mesh, off: Vector3, sc: Vector3 = Vector3.ONE) -> void:
	if at.is_empty():
		return
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = at.size()
	for k: int in at.size():
		var b: Basis = Basis.from_scale(sc * (0.9 + 0.2 * float(_hash(int(at[k].x * 7.0), int(at[k].z * 7.0)) % 10) / 10.0))
		mm.set_instance_transform(k, Transform3D(b, at[k] + off))
	var mi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mi.name = nm
	mi.multimesh = mm
	add_child(mi)


func _pool(nm: String, mesh: Mesh, n: int) -> MultiMeshInstance3D:
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = n
	mm.visible_instance_count = 0
	var mi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mi.name = nm
	mi.multimesh = mm
	add_child(mi)
	return mi


func _build_dynamic() -> void:
	var st: Dictionary = _st()
	for a: Dictionary in st["agents"]:
		_agents.append(_make_agent(a))
	_loot_root = Node3D.new()
	_loot_root.name = "Loot"
	add_child(_loot_root)
	_bullets = _pool("Bullets", _box_mesh(Vector3(0.09, 0.09, 0.8), Color("#fff3a0")), MAX_BULLETS)
	(_bullets.multimesh.mesh as BoxMesh).material = mat(Color("#fff3a0"), 2.0, true)
	_tracers = _pool("Flashes", _sphere_mesh(0.22, Color("#ffd27a")), 64)
	(_tracers.multimesh.mesh as SphereMesh).material = mat(Color("#ffd27a"), 2.5, true)
	_fx = _pool("Sparks", _box_mesh(Vector3(0.14, 0.14, 0.14), Color("#ff7a5a")), MAX_FX)
	(_fx.multimesh.mesh as BoxMesh).material = mat(Color("#ff7a5a"), 1.0, true)
	## Zona: una pared azul que se cierra y el circulo siguiente en blanco.
	_zone = MeshInstance3D.new()
	_zone.name = "Zone"
	var zc: CylinderMesh = CylinderMesh.new()
	zc.top_radius = 1.0
	zc.bottom_radius = 1.0
	zc.height = 1.0
	zc.radial_segments = 96
	zc.cap_top = false
	zc.cap_bottom = false
	var zm: StandardMaterial3D = mat(Color(0.3, 0.45, 1.0, 0.3), 0.0, true)
	zm.cull_mode = BaseMaterial3D.CULL_DISABLED
	zc.material = zm
	_zone.mesh = zc
	add_child(_zone)
	_next = MeshInstance3D.new()
	_next.name = "NextZone"
	var tm: TorusMesh = TorusMesh.new()
	tm.inner_radius = 0.985
	tm.outer_radius = 1.0
	tm.rings = 96
	tm.material = mat(Color(1, 1, 1, 0.85), 0.0, true)
	_next.mesh = tm
	add_child(_next)
	## Avion.
	_plane = Node3D.new()
	_plane.name = "Plane"
	var body: MeshInstance3D = MeshInstance3D.new()
	body.mesh = _box_mesh(Vector3(1.2, 1.0, 5.0), Color("#e6e9ee"))
	_plane.add_child(body)
	var wing: MeshInstance3D = MeshInstance3D.new()
	wing.mesh = _box_mesh(Vector3(6.0, 0.15, 1.2), Color("#cfd4dc"))
	_plane.add_child(wing)
	var tail: MeshInstance3D = MeshInstance3D.new()
	tail.mesh = _box_mesh(Vector3(2.2, 0.12, 0.7), Color("#cfd4dc"))
	tail.position = Vector3(0, 0.4, 2.2)
	_plane.add_child(tail)
	add_child(_plane)


## Un soldado: cuerpo, cabeza, mochila, arma (cambia con lo que lleva) y barra de vida.
func _make_agent(a: Dictionary) -> Dictionary:
	var me: bool = int(a["id"]) == 0
	var col: Color = Kit.color("player", Color("#3fa7ff")) if me else Color.from_hsv(fmod(float(a["nid"]) * 0.137, 1.0) * 0.25, 0.65, 0.95)
	var root: Node3D = Node3D.new()
	root.name = "Agent%d" % int(a["nid"])
	add_child(root)
	var body_m: StandardMaterial3D = mat(col)
	var torso: MeshInstance3D = MeshInstance3D.new()
	var cap: CapsuleMesh = CapsuleMesh.new()
	cap.radius = 0.32
	cap.height = 1.2
	cap.material = body_m
	torso.mesh = cap
	torso.position = Vector3(0, 0.75, 0)
	root.add_child(torso)
	var head: MeshInstance3D = MeshInstance3D.new()
	head.mesh = _sphere_mesh(0.24, Color("#f2c49b"))
	head.position = Vector3(0, 1.55, 0)
	root.add_child(head)
	var pack: MeshInstance3D = MeshInstance3D.new()
	pack.mesh = _box_mesh(Vector3(0.42, 0.5, 0.22), col.darkened(0.4))
	pack.position = Vector3(0, 0.95, 0.3)
	root.add_child(pack)
	var gun: MeshInstance3D = MeshInstance3D.new()
	gun.mesh = _box_mesh(Vector3(0.1, 0.12, 0.8), Color("#2a2d33"))
	gun.position = Vector3(0.22, 1.0, -0.45)
	gun.name = "Gun"
	root.add_child(gun)
	var vest: MeshInstance3D = MeshInstance3D.new()
	var vc: CapsuleMesh = CapsuleMesh.new()
	vc.radius = 0.35
	vc.height = 0.7
	vc.material = mat(Color("#4aa8ff"))
	vest.mesh = vc
	vest.position = Vector3(0, 0.9, 0)
	vest.name = "Vest"
	root.add_child(vest)
	var bar: MeshInstance3D = MeshInstance3D.new()
	bar.mesh = _box_mesh(Vector3(0.9, 0.09, 0.02), Color("#ff5a5a"))
	(bar.mesh as BoxMesh).material = mat(Color("#ff5a5a"), 0.0, true)
	bar.position = Vector3(0, 2.1, 0)
	bar.name = "Hp"
	root.add_child(bar)
	if not bool(a["bot"]) and not me:
		var lbl: Label3D = Label3D.new()
		lbl.text = str(a["name"])
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.font_size = 48
		lbl.pixel_size = 0.008
		lbl.position = Vector3(0, 2.45, 0)
		lbl.outline_size = 10
		root.add_child(lbl)
	return {"root": root, "mat": body_m, "col": col, "gun": gun, "vest": vest, "bar": bar}


# ------------------------------------------------------------------ cada fotograma

func sync(delta: float) -> void:
	if game == null:
		return
	var st: Dictionary = _st()
	if st.is_empty():
		return
	_t += delta
	var agents: Array = st["agents"]
	## Si se rehizo la partida (reintento), los soldados se rehacen.
	if _agents.size() != agents.size():
		for e: Dictionary in _agents:
			(e["root"] as Node3D).queue_free()
		_agents.clear()
		for a0: Dictionary in agents:
			_agents.append(_make_agent(a0))
	for k: int in agents.size():
		var a: Dictionary = agents[k]
		var e: Dictionary = _agents[k]
		var root: Node3D = e["root"]
		root.visible = bool(a["alive"]) and bool(a["landed"])
		if not root.visible:
			continue
		var p: Vector3 = to3(a["p"])
		## Al caer del avion, baja un momento en paracaidas.
		var since: float = float(st["time"]) - float(a["drop_t"])
		if since >= 0.0 and since < 0.6:
			p.y += (0.6 - since) * 12.0
		root.position = p
		var aim: Vector2 = (a["aim"] as Vector2)
		if aim.length() > 0.01:
			root.rotation.y = lerp_angle(root.rotation.y, atan2(-aim.x, -aim.y), minf(1.0, delta * 16.0) if delta > 0.0 else 1.0)
		(e["mat"] as StandardMaterial3D).albedo_color = Color.WHITE if float(a["hit_t"]) > 0.0 else (e["col"] as Color)
		var wpn: String = str(a["weapon"])
		var gun: MeshInstance3D = e["gun"]
		gun.visible = wpn != "punos"
		if gun.visible:
			gun.scale = Vector3(1, 1, 0.7 + 0.25 * float(M.WEAPONS[wpn]["tier"]))
		(e["vest"] as Node3D).visible = float(a["armor"]) > 0.0
		var bar: MeshInstance3D = e["bar"]
		bar.visible = k != 0 and float(a["hp"]) < M.MAX_HP
		bar.scale = Vector3(maxf(0.02, float(a["hp"]) / M.MAX_HP), 1, 1)
		bar.rotation.y = -root.rotation.y
	_sync_loot(st)
	_sync_bullets(st)
	_sync_fx(delta)
	## Zona.
	var zr: float = float(st["zone_r"]) * K
	_zone.position = to3(st["zone_c"], 6.0)
	_zone.scale = Vector3(zr, 14.0, zr)
	_next.visible = int(st["phase"]) >= 0
	if _next.visible:
		var nr: float = float(st["to_r"]) * K
		_next.position = to3(st["to_c"], 0.15)
		_next.scale = Vector3(nr, 4.0, nr)
	## Avion.
	_plane.visible = float(st["time"]) < M.PLANE_T + 0.5
	if _plane.visible:
		_plane.position = to3(M.plane_pos(st), 22.0)
		var dir: Vector2 = ((st["plane_b"] as Vector2) - (st["plane_a"] as Vector2)).normalized()
		_plane.rotation.y = atan2(-dir.x, -dir.y)
	## Camara: detras y arriba, siempre mirando al norte.
	var me: Dictionary = agents[0]
	var target: Vector3 = to3(me["p"]) if bool(me["landed"]) else to3(M.plane_pos(st))
	var lift: float = 0.0 if bool(me["landed"]) else 18.0
	var want: Vector3 = target + Vector3(0, 16.0 + lift, 10.5 + lift * 0.5)
	_cam.position = _cam.position.lerp(want, minf(1.0, delta * 8.0)) if delta > 0.0 and not bool(game.get("fast")) else want
	_cam.look_at(_cam.position - Vector3(0, 16.0 + lift, 10.5 + lift * 0.5) + Vector3(0, 1.0, 0), Vector3.UP)
	var sh: float = float(game.get("_shake"))
	_cam.position += Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * sh * 0.25
	_hurt_rect.color.a = float(game.get("_hurt")) * 0.5


func _sync_loot(st: Dictionary) -> void:
	var ids: PackedStringArray = PackedStringArray()
	for it: Dictionary in st["loot"]:
		ids.append(str(it.get("id", "")) + str(it["item"]))
	var sig: String = ",".join(ids)
	if sig != _loot_sig:
		_loot_sig = sig
		for c: Node in _loot_root.get_children():
			c.queue_free()
		for it2: Dictionary in st["loot"]:
			var item: String = str(it2["item"])
			var col: Color = game.call("_rarity_col", item)
			var n: Node3D = Node3D.new()
			n.position = to3(it2["p"], 0.0)
			var glow: MeshInstance3D = MeshInstance3D.new()
			var gc: CylinderMesh = CylinderMesh.new()
			gc.top_radius = 0.5
			gc.bottom_radius = 0.5
			gc.height = 0.03
			gc.material = mat(Color(col.r, col.g, col.b, 0.45), 0.8, true)
			glow.mesh = gc
			glow.position = Vector3(0, 0.03, 0)
			n.add_child(glow)
			var obj: MeshInstance3D = MeshInstance3D.new()
			if M.WEAPONS.has(item):
				obj.mesh = _box_mesh(Vector3(0.14, 0.16, 0.6 + 0.15 * float(M.WEAPONS[item]["tier"])), col.darkened(0.2))
			elif item.begins_with("chaleco"):
				obj.mesh = _box_mesh(Vector3(0.5, 0.55, 0.25), col)
			else:
				obj.mesh = _box_mesh(Vector3(0.4, 0.3, 0.3), Color("#ff8fa0"))
			obj.position = Vector3(0, 0.45, 0)
			obj.name = "Obj"
			n.add_child(obj)
			_loot_root.add_child(n)
	for n2: Node in _loot_root.get_children():
		var o: Node3D = n2.get_node_or_null("Obj")
		if o != null:
			o.rotation.y = _t * 1.6
			o.position.y = 0.45 + sin(_t * 3.0 + (n2 as Node3D).position.x) * 0.08


func _sync_bullets(st: Dictionary) -> void:
	var mm: MultiMesh = _bullets.multimesh
	var bl: Array = st["bullets"]
	var n: int = mini(bl.size(), MAX_BULLETS)
	for k: int in n:
		var b: Dictionary = bl[k]
		var v: Vector2 = (b["v"] as Vector2).normalized()
		var basis: Basis = Basis(Vector3.UP, atan2(-v.x, -v.y))
		mm.set_instance_transform(k, Transform3D(basis, to3(b["p"], 1.0)))
	mm.visible_instance_count = n


## Fogonazos (de los disparos que apunta el juego) y chispas; aqui se gastan, como en la vista 2D.
func _sync_fx(delta: float) -> void:
	var tr: Array = game.get("_tracers")
	var mm: MultiMesh = _tracers.multimesh
	var n: int = 0
	var k: int = tr.size() - 1
	while k >= 0:
		var e: Dictionary = tr[k]
		if n < mm.instance_count:
			mm.set_instance_transform(n, Transform3D(Basis.from_scale(Vector3.ONE * (0.6 + float(e["t"]) * 8.0)), to3((e["a"] as Vector2).lerp(e["b"], 0.6), 1.0)))
			n += 1
		e["t"] = float(e["t"]) - delta
		if float(e["t"]) <= 0.0:
			tr.remove_at(k)
		k -= 1
	mm.visible_instance_count = n
	var fx: Array = game.get("_fx")
	var mm2: MultiMesh = _fx.multimesh
	var n2: int = 0
	k = fx.size() - 1
	while k >= 0:
		var f: Dictionary = fx[k]
		f["p"] = (f["p"] as Vector2) + (f["v"] as Vector2) * delta
		f["t"] = float(f["t"]) - delta
		if n2 < MAX_FX:
			mm2.set_instance_transform(n2, Transform3D(Basis.IDENTITY, to3(f["p"], 0.4 + float(f["t"]) * 2.0)))
			n2 += 1
		if float(f["t"]) <= 0.0:
			fx.remove_at(k)
		k -= 1
	mm2.visible_instance_count = n2
