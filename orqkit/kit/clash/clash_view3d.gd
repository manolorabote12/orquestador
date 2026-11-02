extends Node3D
## Vista 3D del duelo de cartas (nace en 3D). Solo dibuja: las reglas, la IA, el bot y el
## analizador son los de clash_map.gd. Una casilla de la arena = 1 m (x a lo ancho, z a lo largo).
## 1 - Arena: cesped a cuadros, caminos de los carriles, rio con dos puentes de madera y vallas.
## 2 - Torres de princesa y del rey con el color de cada lado (azul tu, rojo el rival), su vida
##     encima y escombros al caer; el rey duerme (ojos cerrados) hasta que despierta.
## 3 - Tropas hechas con formas (cada carta con su silueta) sobre un aro de su color; las que
##     vuelan, en alto con sombra. Saltan un poco al andar y se encogen al golpear.
## 4 - Disparos como bolas que vuelan, hechizos que caen y estallan, y la zona donde se puede
##     soltar la carta al arrastrarla (verde si vale, rojo si no).
## 5 - Camara alta detras de tu lado mirando a la arena (como los juegos de cartas de movil).

const M = preload("res://kit/clash/clash_map.gd")
const TEAM: Array[Color] = [Color("#3d8bff"), Color("#ff4a4a")]
## Las tropas se ven algo mas grandes que su casilla (se leen mejor en el movil).
const UNIT_SCALE: float = 1.8

var game: Node2D
var _camera: Camera3D
var _units: Dictionary = {}
var _bars: Dictionary = {}
var _fx: Array = []
var _ghost: MeshInstance3D
var _ghost_ring: MeshInstance3D
var _no_zone: MeshInstance3D
var _dyn: Node3D
var _t: float = 0.0
var _mats: Dictionary = {}


func setup(g: Node2D) -> void:
	game = g
	name = "View3D"
	_build_environment()
	_build_arena()
	_dyn = Node3D.new()
	_dyn.name = "Dynamic"
	add_child(_dyn)
	_build_ghost()
	_camera = Camera3D.new()
	_camera.name = "Camera3D"
	_camera.fov = 44.0
	_camera.keep_aspect = Camera3D.KEEP_WIDTH
	_camera.far = 200.0
	add_child(_camera)
	_camera.position = Vector3(9.0, 29.0, 40.0)
	_camera.look_at(Vector3(9.0, 0.0, 17.6), Vector3.UP)
	_camera.make_current()
	rebuild()


func st() -> Dictionary:
	return game.get("st")


func mat(col: Color, alpha: bool = false) -> StandardMaterial3D:
	var key: String = col.to_html() + ("a" if alpha else "")
	if _mats.has(key):
		return _mats[key]
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.85
	if alpha or col.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mats[key] = m
	return m


func _mesh(mesh: Mesh, col: Color, pos: Vector3, parent: Node3D) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat(col)
	mi.position = pos
	parent.add_child(mi)
	return mi


static func box(s: Vector3) -> BoxMesh:
	var b: BoxMesh = BoxMesh.new()
	b.size = s
	return b


static func cyl(r: float, h: float, top: float = -1.0) -> CylinderMesh:
	var c: CylinderMesh = CylinderMesh.new()
	c.top_radius = r if top < 0.0 else top
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 16
	return c


static func ball(r: float) -> SphereMesh:
	var s: SphereMesh = SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 12
	s.rings = 6
	return s


static func capsule(r: float, h: float) -> CapsuleMesh:
	var c: CapsuleMesh = CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 12
	c.rings = 4
	return c


# ------------------------------------------------------------------ escenario

func _build_environment() -> void:
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#2d5a2d")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.26
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60.0, 25.0, 0.0)
	sun.light_energy = 0.5
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)


func _build_arena() -> void:
	var arena: Node3D = Node3D.new()
	arena.name = "Arena"
	add_child(arena)
	## Cesped a cuadros (un solo mesh con colores por vertice).
	var stl: SurfaceTool = SurfaceTool.new()
	stl.begin(Mesh.PRIMITIVE_TRIANGLES)
	for y: int in int(M.H):
		if float(y) >= M.RIVER_TOP and float(y) < M.RIVER_BOT:
			continue
		for x: int in int(M.W):
			var col: Color = Color("#5c9c42") if (x + y) % 2 == 0 else Color("#55913d")
			## Caminos de los carriles (un poco mas claros).
			if absf(float(x) + 0.5 - M.BRIDGES[0]) < 1.2 or absf(float(x) + 0.5 - M.BRIDGES[1]) < 1.2:
				col = col.lerp(Color("#c9b47a"), 0.28)
			for v: Vector3 in [Vector3(x, 0, y), Vector3(x + 1, 0, y), Vector3(x + 1, 0, y + 1), Vector3(x, 0, y), Vector3(x + 1, 0, y + 1), Vector3(x, 0, y + 1)]:
				stl.set_color(col)
				stl.set_normal(Vector3.UP)
				stl.add_vertex(v)
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.95
	var ground: MeshInstance3D = MeshInstance3D.new()
	ground.name = "Ground"
	var mesh: ArrayMesh = stl.commit()
	mesh.surface_set_material(0, m)
	ground.mesh = mesh
	arena.add_child(ground)
	## Borde de piedra alrededor y suelo de fuera.
	_mesh(box(Vector3(60, 0.2, 80)), Color("#3f6b35"), Vector3(9, -0.35, 16), arena)
	for side: Array in [[Vector3(-0.4, 0.3, 16), Vector3(0.8, 0.6, 32.8)], [Vector3(18.4, 0.3, 16), Vector3(0.8, 0.6, 32.8)],
			[Vector3(9, 0.3, -0.4), Vector3(19.6, 0.6, 0.8)], [Vector3(9, 0.3, 32.4), Vector3(19.6, 0.6, 0.8)]]:
		_mesh(box(side[1]), Color("#6f6a60"), side[0], arena)
	## Rio y puentes.
	_mesh(box(Vector3(18, 0.1, M.RIVER_BOT - M.RIVER_TOP)), Color("#2f86c0"), Vector3(9, -0.18, (M.RIVER_TOP + M.RIVER_BOT) * 0.5), arena)
	for bx: float in M.BRIDGES:
		_mesh(box(Vector3(2.2, 0.16, 2.6)), Color("#a0703a"), Vector3(bx, 0.02, 16.0), arena)
		for k: int in 5:
			_mesh(box(Vector3(2.2, 0.04, 0.08)), Color("#7a5228"), Vector3(bx, 0.12, 15.0 + 0.5 * float(k)), arena)
		for sx: float in [-1.15, 1.15]:
			_mesh(box(Vector3(0.12, 0.35, 2.6)), Color("#6b4a2b"), Vector3(bx + sx, 0.25, 16.0), arena)


func _build_ghost() -> void:
	_ghost = MeshInstance3D.new()
	_ghost.name = "Ghost"
	_ghost.mesh = cyl(0.8, 0.06)
	_ghost.visible = false
	add_child(_ghost)
	_ghost_ring = MeshInstance3D.new()
	_ghost_ring.mesh = cyl(1.0, 0.04)
	_ghost_ring.visible = false
	add_child(_ghost_ring)
	_no_zone = MeshInstance3D.new()
	_no_zone.name = "NoZone"
	_no_zone.mesh = box(Vector3(18, 0.02, M.RIVER_BOT))
	_no_zone.material_override = mat(Color(1, 0.2, 0.2, 0.18), true)
	_no_zone.position = Vector3(9, 0.05, M.RIVER_BOT * 0.5)
	_no_zone.visible = false
	add_child(_no_zone)


## Vuelve a crear torres y tropas desde el estado (al empezar o reintentar).
func rebuild() -> void:
	for c: Node in _dyn.get_children():
		_dyn.remove_child(c)
		c.queue_free()
	_units.clear()
	_bars.clear()
	_fx.clear()
	sync(1.0)


# ------------------------------------------------------------------ figuras

func _make_tower(e: Dictionary) -> Node3D:
	var n: Node3D = Node3D.new()
	var col: Color = TEAM[int(e["side"])]
	var king: bool = str(e["kind"]) == "king"
	var r: float = float(e["r"])
	_mesh(cyl(r * 0.95, 1.6 if king else 2.0, r * 0.8), Color("#8f8778"), Vector3(0, 0.8 if king else 1.0, 0), n)
	_mesh(cyl(r, 0.35), col.darkened(0.2), Vector3(0, 1.75 if king else 2.15, 0), n)
	for k: int in 8:
		var a: float = TAU * float(k) / 8.0
		_mesh(box(Vector3(0.35, 0.35, 0.35)), Color("#a39b8a"), Vector3(cos(a) * r * 0.85, 2.1 if king else 2.5, sin(a) * r * 0.85), n)
	if king:
		## El rey: cuerpo, cabeza y corona.
		_mesh(capsule(0.45, 1.2), col, Vector3(0, 2.4, 0), n)
		_mesh(ball(0.35), Color("#f6d2b0"), Vector3(0, 3.25, 0), n)
		_mesh(cyl(0.32, 0.3, 0.38), Color("#ffd23f"), Vector3(0, 3.65, 0), n)
	else:
		## Princesa con arco en lo alto.
		_mesh(capsule(0.28, 0.8), col, Vector3(0, 2.75, 0), n)
		_mesh(ball(0.22), Color("#f6d2b0"), Vector3(0, 3.3, 0), n)
		_mesh(ball(0.24), Color("#ffd23f"), Vector3(0, 3.42, -0.05), n)
	return n


func _make_unit(e: Dictionary) -> Node3D:
	var n: Node3D = Node3D.new()
	var col: Color = TEAM[int(e["side"])]
	var card: String = str(e.get("card", ""))
	var body: Node3D = Node3D.new()
	body.name = "Body"
	n.add_child(body)
	var fly: float = 1.6 if bool(e.get("air", false)) else 0.0
	body.position.y = fly
	## Aro del equipo en el suelo (y sombra si vuela).
	var ring: MeshInstance3D = _mesh(cyl(float(e["r"]) + 0.12, 0.04), col if fly == 0.0 else Color(0, 0, 0, 0.3), Vector3(0, 0.03, 0), n)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var skin: Color = Color("#f6d2b0")
	match card:
		"knight":
			_mesh(capsule(0.32, 1.0), col, Vector3(0, 0.55, 0), body)
			_mesh(ball(0.26), Color("#b9c2cc"), Vector3(0, 1.2, 0), body)
			_mesh(box(Vector3(0.08, 0.08, 0.9)), Color("#e6ebf2"), Vector3(0.38, 0.75, -0.3), body)
		"archers":
			_mesh(capsule(0.22, 0.75), col, Vector3(0, 0.42, 0), body)
			_mesh(ball(0.19), skin, Vector3(0, 0.92, 0), body)
			_mesh(cyl(0.2, 0.3, 0.0), Color("#e8749b"), Vector3(0, 1.15, 0), body)
			_mesh(box(Vector3(0.05, 0.6, 0.05)), Color("#8a5a2b"), Vector3(0.3, 0.6, -0.1), body)
		"giant":
			_mesh(capsule(0.6, 1.8), col.lerp(Color("#d9a066"), 0.4), Vector3(0, 1.0, 0), body)
			_mesh(ball(0.42), skin, Vector3(0, 2.15, 0), body)
			_mesh(ball(0.3), skin, Vector3(0.65, 1.1, -0.1), body)
			_mesh(ball(0.3), skin, Vector3(-0.65, 1.1, -0.1), body)
		"minions":
			_mesh(ball(0.3), col.lerp(Color("#4a6bd9"), 0.5), Vector3(0, 0, 0), body)
			_mesh(box(Vector3(0.7, 0.05, 0.3)), Color("#2b3f8a"), Vector3(-0.4, 0.1, 0), body)
			_mesh(box(Vector3(0.7, 0.05, 0.3)), Color("#2b3f8a"), Vector3(0.4, 0.1, 0), body)
		"musketeer":
			_mesh(capsule(0.28, 0.95), col, Vector3(0, 0.52, 0), body)
			_mesh(ball(0.22), skin, Vector3(0, 1.12, 0), body)
			_mesh(cyl(0.3, 0.06), Color("#b06ad9"), Vector3(0, 1.32, 0), body)
			_mesh(box(Vector3(0.07, 0.07, 1.0)), Color("#2a2a3a"), Vector3(0.3, 0.75, -0.35), body)
		"skeletons":
			_mesh(capsule(0.16, 0.55), Color("#ececec"), Vector3(0, 0.3, 0), body)
			_mesh(ball(0.17), Color.WHITE, Vector3(0, 0.7, 0), body)
			_mesh(cyl(0.12, 0.04), col, Vector3(0, 0.45, 0), body)
		"hog":
			_mesh(box(Vector3(0.6, 0.55, 1.0)), Color("#e6a0a0"), Vector3(0, 0.4, 0), body)
			_mesh(capsule(0.22, 0.7), col, Vector3(0, 0.95, 0.1), body)
			_mesh(ball(0.2), Color("#c98a5a"), Vector3(0, 1.4, 0.1), body)
			_mesh(box(Vector3(0.08, 0.6, 0.08)), Color("#8a5a2b"), Vector3(0.3, 1.3, 0), body)
		"valkyrie":
			_mesh(capsule(0.34, 1.0), col, Vector3(0, 0.55, 0), body)
			_mesh(ball(0.25), skin, Vector3(0, 1.2, 0), body)
			_mesh(ball(0.27), Color("#ff9a3c"), Vector3(0, 1.3, 0.08), body)
			_mesh(box(Vector3(1.0, 0.2, 0.06)), Color("#e6ebf2"), Vector3(0, 0.8, -0.35), body)
		"babydragon":
			_mesh(ball(0.45), Color("#4caf50"), Vector3(0, 0, 0), body)
			_mesh(ball(0.28), Color("#5fcf60"), Vector3(0, 0.25, -0.45), body)
			_mesh(box(Vector3(0.9, 0.05, 0.45)), Color("#ff9a3c"), Vector3(-0.6, 0.15, 0), body)
			_mesh(box(Vector3(0.9, 0.05, 0.45)), Color("#ff9a3c"), Vector3(0.6, 0.15, 0), body)
		"cannon":
			_mesh(cyl(0.85, 0.4), Color("#6b4a2b"), Vector3(0, 0.2, 0), body)
			_mesh(cyl(0.28, 1.1), Color("#33333d"), Vector3(0, 0.75, -0.2), body).rotation_degrees.x = -70.0
		_:
			_mesh(capsule(0.3, 0.9), col, Vector3(0, 0.5, 0), body)
	return n


func _make_bar(e: Dictionary) -> Node3D:
	var n: Node3D = Node3D.new()
	var w: float = 1.6 if str(e.get("kind", "")) == "unit" else 2.6
	var bg: MeshInstance3D = MeshInstance3D.new()
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(w, 0.18)
	bg.mesh = q
	var mb: StandardMaterial3D = StandardMaterial3D.new()
	mb.albedo_color = Color(0, 0, 0, 0.7)
	mb.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mb.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mb.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mb.no_depth_test = true
	mb.billboard_keep_scale = true
	bg.material_override = mb
	n.add_child(bg)
	var fill: MeshInstance3D = MeshInstance3D.new()
	fill.name = "Fill"
	var q2: QuadMesh = QuadMesh.new()
	q2.size = Vector2(w - 0.06, 0.12)
	q2.center_offset = Vector3((w - 0.06) * 0.5, 0, 0.001)
	fill.mesh = q2
	var mf: StandardMaterial3D = mb.duplicate()
	mf.albedo_color = TEAM[int(e["side"])].lightened(0.25)
	mf.render_priority = 1
	fill.material_override = mf
	fill.position.x = -(w - 0.06) * 0.5
	n.add_child(fill)
	n.set_meta("w", w)
	return n


# ------------------------------------------------------------------ cada fotograma

func sync(delta: float) -> void:
	var s0: Dictionary = st()
	if s0.is_empty():
		return
	var alive: Dictionary = {}
	for e: Dictionary in s0["ents"]:
		var id: int = int(e["id"])
		alive[id] = true
		var node: Node3D = _units.get(id, null)
		var kind: String = str(e.get("kind", ""))
		var p: Vector3 = Vector3((e["p"] as Vector2).x, 0.0, (e["p"] as Vector2).y)
		if node == null:
			node = _make_tower(e) if kind in ["tower", "king"] else _make_unit(e)
			node.position = p
			_dyn.add_child(node)
			_units[id] = node
			var bar: Node3D = _make_bar(e)
			_dyn.add_child(bar)
			_bars[id] = bar
			if kind == "unit":
				node.scale = Vector3.ONE * 0.2
		## Movimiento suave, mirando hacia donde va, saltitos al andar.
		var before: Vector3 = node.position
		node.position = node.position.lerp(p, minf(1.0, delta * 14.0))
		if kind == "unit":
			node.scale = node.scale.lerp(Vector3.ONE * UNIT_SCALE, minf(1.0, delta * 8.0))
			var mv: Vector3 = node.position - before
			var body: Node3D = node.get_node_or_null("Body")
			if mv.length() > 0.002:
				node.rotation.y = lerp_angle(node.rotation.y, atan2(-mv.x, -mv.z), minf(1.0, delta * 10.0))
				if body != null:
					body.position.y = (1.6 if bool(e.get("air", false)) else 0.0) + absf(sin(_t * 12.0 + float(id))) * 0.12
			elif body != null and bool(e.get("air", false)):
				body.position.y = 1.6 + sin(_t * 4.0 + float(id)) * 0.1
			if float(e.get("deploy", 0.0)) > 0.0:
				node.scale = Vector3.ONE * UNIT_SCALE * (1.0 - float(e["deploy"]) * 0.5)
		## Vida encima (solo si ha recibido algo).
		var bar2: Node3D = _bars.get(id, null)
		if bar2 != null:
			var frac: float = clampf(float(e["hp"]) / maxf(1.0, float(e["max"])), 0.0, 1.0)
			var top: float = 4.1 if kind == "king" else (3.8 if kind == "tower" else (3.0 if bool(e.get("air", false)) else 1.5 + float(e["r"]) * 1.4))
			bar2.position = node.position + Vector3(0, top, 0)
			bar2.visible = frac < 0.999 or kind in ["tower", "king"]
			(bar2.get_node("Fill") as Node3D).scale.x = maxf(0.001, frac)
	## Lo que ya no esta: torres a escombros; tropas, se encogen y se van.
	for id2: int in _units.keys():
		if not alive.has(id2):
			var n2: Node3D = _units[id2]
			_units.erase(id2)
			if _bars.has(id2):
				(_bars[id2] as Node).queue_free()
				_bars.erase(id2)
			var tw: Tween = n2.create_tween()
			tw.tween_property(n2, "scale", Vector3(1.2, 0.05, 1.2), 0.25)
			tw.tween_callback(n2.queue_free)
	_sync_fx(delta)
	_sync_ghost()


func _sync_fx(delta: float) -> void:
	for f: Dictionary in _fx:
		f["t"] = float(f["t"]) + delta
		var n: Node3D = f["node"]
		var k: float = clampf(float(f["t"]) / float(f["dur"]), 0.0, 1.0)
		match str(f["kind"]):
			"shot":
				n.position = (f["a"] as Vector3).lerp(f["b"], k) + Vector3(0, sin(k * PI) * 0.8, 0)
			"fall":
				n.position = (f["b"] as Vector3) + Vector3(0, (1.0 - k) * 14.0, (1.0 - k) * 6.0)
				if k >= 1.0 and not bool(f.get("boom", false)):
					f["boom"] = true
					_boom(f["b"], float(f["r"]), Color("#ff7a1a"))
			"boom":
				n.scale = Vector3.ONE * (0.3 + k)
				(n as MeshInstance3D).transparency = k
	for f2: Dictionary in _fx:
		if float(f2["t"]) >= float(f2["dur"]) and str(f2["kind"]) != "fall":
			(f2["node"] as Node).queue_free()
		elif str(f2["kind"]) == "fall" and float(f2["t"]) >= float(f2["dur"]):
			(f2["node"] as Node).queue_free()
	_fx = _fx.filter(func(f3: Dictionary) -> bool: return float(f3["t"]) < float(f3["dur"]))


func _sync_ghost() -> void:
	var drag: bool = bool(game.get("dragging"))
	var slot: int = int(game.get("sel"))
	var at: Vector2 = game.get("drag_arena")
	var s0: Dictionary = st()
	if not drag or slot < 0 or s0.is_empty() or at.x < 0.0:
		_ghost.visible = false
		_ghost_ring.visible = false
		_no_zone.visible = drag and slot >= 0 and not s0.is_empty() and not bool(M.CARDS[str(s0["hands"][0][slot])].get("spell", false))
		return
	var card: String = str(s0["hands"][0][slot])
	var ok: bool = M.can_drop(0, card, at)
	var spell: bool = bool(M.CARDS[card].get("spell", false))
	_no_zone.visible = not spell
	_ghost.visible = true
	_ghost.position = Vector3(at.x, 0.08, at.y)
	_ghost.material_override = mat(Color(0.3, 1.0, 0.45, 0.45) if ok else Color(1.0, 0.3, 0.3, 0.45), true)
	_ghost_ring.visible = spell
	if spell:
		var r: float = float(M.CARDS[card]["radius"])
		_ghost_ring.scale = Vector3(r, 1, r)
		_ghost_ring.position = Vector3(at.x, 0.07, at.y)
		_ghost_ring.material_override = mat(Color(1.0, 0.85, 0.3, 0.25), true)


# ------------------------------------------------------------------ efectos (los llama el juego)

func on_hit(e: Dictionary) -> void:
	var n: Node3D = _units.get(int(e["from"]), null)
	if n != null:
		var body: Node3D = n.get_node_or_null("Body")
		if body != null:
			body.scale = Vector3(1.15, 0.85, 1.15)
			var tw: Tween = body.create_tween()
			tw.tween_property(body, "scale", Vector3.ONE, 0.15)
	if bool(e["ranged"]) and not bool(game.get("fast")):
		var a: Vector2 = e["a"]
		var b: Vector2 = e["b"]
		var shot: MeshInstance3D = _mesh(ball(0.14), TEAM[int(e["side"])].lightened(0.5), Vector3(a.x, 1.2, a.y), _dyn)
		_fx.append({"kind": "shot", "node": shot, "a": Vector3(a.x, 1.2, a.y), "b": Vector3(b.x, 1.0, b.y), "t": 0.0, "dur": 0.22})


func on_spell(e: Dictionary) -> void:
	if bool(game.get("fast")):
		return
	var p: Vector2 = e["p"]
	if str(e["card"]) == "fireball":
		var fb: MeshInstance3D = _mesh(ball(0.7), Color("#ff7a1a"), Vector3(p.x, 10.0, p.y), _dyn)
		_fx.append({"kind": "fall", "node": fb, "b": Vector3(p.x, 0.5, p.y), "r": float(e["radius"]), "t": 0.0, "dur": 0.35})
	else:
		for k: int in 9:
			var o: Vector2 = Vector2(cos(float(k) * 2.4), sin(float(k) * 2.4)) * float(e["radius"]) * 0.6 * sqrt(float(k) / 9.0)
			var ar: MeshInstance3D = _mesh(box(Vector3(0.06, 0.8, 0.06)), Color("#8a5a2b"), Vector3(p.x + o.x, 10.0, p.y + o.y), _dyn)
			_fx.append({"kind": "fall", "node": ar, "b": Vector3(p.x + o.x, 0.4, p.y + o.y), "r": 0.6, "t": -0.03 * float(k), "dur": 0.3})
		_boom(Vector3(p.x, 0.1, p.y), float(e["radius"]), Color("#d9c36b"))


func _boom(at: Vector3, r: float, col: Color) -> void:
	var b: MeshInstance3D = MeshInstance3D.new()
	b.mesh = cyl(r, 0.1)
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color(col, 0.6)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	b.material_override = m
	b.position = Vector3(at.x, 0.15, at.z)
	_dyn.add_child(b)
	_fx.append({"kind": "boom", "node": b, "t": 0.0, "dur": 0.4})


func on_die(e: Dictionary) -> void:
	if str(e["kind"]) in ["tower", "king"]:
		var p: Vector2 = e["p"]
		var rub: Node3D = Node3D.new()
		rub.name = "Rubble"
		_dyn.add_child(rub)
		for k: int in 6:
			_mesh(box(Vector3(0.6, 0.35, 0.5)), Color("#8d8a80"), Vector3(p.x + cos(float(k)) * 0.9, 0.18, p.y + sin(float(k) * 1.7) * 0.9), rub)
		if not bool(game.get("fast")):
			_boom(Vector3(p.x, 0.1, p.y), 2.5, Color("#e8e0d0"))


func on_play(e: Dictionary) -> void:
	if bool(game.get("fast")):
		return
	var p: Vector2 = e["p"]
	if not bool(M.CARDS[str(e["card"])].get("spell", false)):
		_boom(Vector3(p.x, 0.1, p.y), 1.0, TEAM[int(e["side"])])


## Punto del suelo bajo un punto de la pantalla (casillas de la arena).
func ground_at(screen: Vector2) -> Vector2:
	if _camera == null:
		return Vector2(-1, -1)
	var o: Vector3 = _camera.project_ray_origin(screen)
	var d: Vector3 = _camera.project_ray_normal(screen)
	if absf(d.y) < 0.0001:
		return Vector2(-1, -1)
	var t: float = -o.y / d.y
	var hit: Vector3 = o + d * t
	return Vector2(hit.x, hit.z)


func screen_pos(a: Vector2, h: float = 1.0) -> Vector2:
	return _camera.unproject_position(Vector3(a.x, h, a.y)) if _camera != null else Vector2.ZERO


func _process(delta: float) -> void:
	_t += delta
