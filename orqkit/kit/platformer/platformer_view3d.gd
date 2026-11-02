extends Node3D
## Vista 3D (2.5D) de plataformas, runner y volador (game.json -> "view": "3d"). Solo dibuja:
## la fisica, el bot, el analizador y las reglas son las de platformer_game.gd, asi que todo lo
## validado en 2D sigue valiendo tal cual.
## 1 - Bloques de verdad: cubos con la textura del juego, cesped arriba y cimientos; pinchos conos.
## 2 - Todo lo demas (jugador, enemigos, monedas, meta, poderes, balas, textos) se refleja: cada
##     sprite, poligono o texto 2D tiene un gemelo 3D que copia posicion, giro, escala, animacion,
##     color y visibilidad. Los estallidos de particulas salen tambien en 3D.
## 3 - El mundo 2D se oculta con la mascara de capas del viewport: sigue vivo para la fisica.
## 4 - Fondo con colinas y arboles de dia o ciudad con neones de noche; camara con perspectiva.

## 1 - Capa en la que se esconde el mundo 2D (el HUD sigue en la capa normal).
const HIDE_LAYER: int = 1 << 19
## 2 - Profundidad de los bloques: el plano del juego (z = 0) queda en medio de la losa.
const DEPTH_BACK: float = -1.4
const DEPTH_FRONT: float = 0.6
const FOUNDATION: float = 8.0

var game: Node2D
var tile: float = 64.0
var _camera: Camera3D
var _mirror: Node3D
## instance_id -> {"src": Node, "twin": Node3D, "kind": String, "z": float, "mat": Material}
var _twins: Dictionary = {}
var _pending: Array[Node] = []
var _old_mask: int = -1
var _nearest: bool = true
var _tile_tex: Texture2D = null


func setup(g: Node2D) -> void:
	game = g
	name = "View3D"
	tile = float(g.get("tile"))
	_nearest = int(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter", 1)) == 0
	_tile_tex = Kit.first_tile_texture()
	_build_environment()
	var rows: Array[String] = g.get("rows")
	add_child(_build_blocks(rows))
	add_child(_build_spikes(rows))
	add_child(_build_scenery(rows))
	_mirror = Node3D.new()
	_mirror.name = "Mirror"
	add_child(_mirror)
	_camera = Camera3D.new()
	_camera.name = "Camera3D"
	_camera.fov = 50.0
	_camera.near = 0.3
	_camera.far = 220.0
	add_child(_camera)
	_camera.make_current()
	## 3 - Esconder el 2D: la mascara del viewport deja de pintar la capa HIDE_LAYER.
	var vp: Viewport = get_viewport()
	_old_mask = int(vp.canvas_cull_mask)
	vp.canvas_cull_mask = _old_mask & ~HIDE_LAYER
	get_tree().node_added.connect(_on_node_added)
	_collect(game)
	_process(0.0)


func _exit_tree() -> void:
	if _old_mask >= 0 and get_viewport() != null:
		get_viewport().canvas_cull_mask = _old_mask
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)


# ------------------------------------------------------------------ escenario

## Noche si el cielo del juego es oscuro: ciudad con neones. Si no, dia con colinas y arboles.
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
	sky_mat.sky_top_color = sky_col if is_night() else sky_col.darkened(0.1)
	sky_mat.sky_horizon_color = horizon
	sky_mat.ground_horizon_color = horizon
	sky_mat.ground_bottom_color = sky_col.darkened(0.5)
	var sky: Sky = Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	## Luz ambiente de color (no del cielo): con cielos muy claros el cielo lo quemaba todo.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = horizon.lerp(Color.WHITE, 0.35)
	env.ambient_light_energy = 0.55 if is_night() else 0.45
	env.fog_enabled = true
	env.fog_light_color = sky_col.lightened(0.1) if is_night() else horizon
	## Niebla por profundidad: el plano del juego (a ~19 m) queda limpio y el fondo se funde.
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_depth_begin = 24.0
	env.fog_depth_end = 70.0 if is_night() else 85.0
	env.fog_depth_curve = 1.4
	env.fog_density = 1.0
	env.fog_sky_affect = 0.25
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	sun.light_energy = 0.5 if is_night() else 0.85
	sun.light_color = Color(0.75, 0.8, 1.0) if is_night() else Color(1.0, 0.97, 0.9)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	add_child(sun)


static func _mat(col: Color, emission: float = 0.0) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.85
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emission
	return m


static func _instanced(mesh: Mesh, mat: Material, xforms: Array[Transform3D], cols: Array[Color], label: String) -> MultiMeshInstance3D:
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i: int in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_color(i, cols[i])
	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.name = label
	mmi.multimesh = mm
	mmi.material_override = mat
	return mmi


## 1 - Material de los bloques: la textura de casilla del juego en triplanar (1 casilla = 1 m).
func _block_mat(col: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = _mat(col)
	m.vertex_color_use_as_albedo = true
	if _tile_tex != null:
		m.albedo_texture = _tile_tex
		m.albedo_color = Color.WHITE
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST if _nearest else BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return m


func _is_solid(rows: Array[String], x: int, y: int) -> bool:
	if y < 0 or y >= rows.size() or x < 0 or x >= rows[y].length():
		return false
	return rows[y][x] == LevelBuilder.SOLID


func _build_blocks(rows: Array[String]) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Blocks"
	var solid: Color = Kit.color("solid", Color.WHITE)
	var base: Color = Color.WHITE if _tile_tex != null else solid
	var depth: float = DEPTH_FRONT - DEPTH_BACK
	var mid_z: float = (DEPTH_FRONT + DEPTH_BACK) * 0.5
	var xf: Array[Transform3D] = []
	var cols: Array[Color] = []
	var tops: Array[Transform3D] = []
	var top_cols: Array[Color] = []
	var h: int = rows.size()
	for y: int in h:
		for x: int in rows[y].length():
			if not _is_solid(rows, x, y):
				continue
			var shade: float = 0.04 if (x + y) % 2 == 0 else 0.0
			xf.append(Transform3D(Basis.IDENTITY, Vector3(x + 0.5, -(y + 0.5), mid_z)))
			cols.append(base.darkened(shade + 0.18 * float(y) / float(maxi(h, 1)) * 0.5))
			## 2 - Cesped/borde claro en las casillas con aire encima.
			if not _is_solid(rows, x, y - 1):
				tops.append(Transform3D(Basis.IDENTITY, Vector3(x + 0.5, -float(y) - 0.07, mid_z)))
				top_cols.append(Color.WHITE.darkened(shade))
			## 3 - Cimientos bajo el suelo del fondo (en los fosos no: se tiene que ver el vacio).
			if y == h - 1:
				var b: Basis = Basis.IDENTITY.scaled(Vector3(1.0, FOUNDATION, 1.0))
				xf.append(Transform3D(b, Vector3(x + 0.5, -float(h) - FOUNDATION * 0.5, mid_z)))
				cols.append(base.darkened(0.45))
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(1.0, 1.0, depth)
	if not xf.is_empty():
		root.add_child(_instanced(box, _block_mat(Color.WHITE), xf, cols, "Cubes"))
	var slab: BoxMesh = BoxMesh.new()
	slab.size = Vector3(1.0, 0.16, depth + 0.06)
	var top_col: Color = solid.lightened(0.3 if _tile_tex == null else 0.12)
	var top_mat: StandardMaterial3D = _mat(top_col)
	top_mat.vertex_color_use_as_albedo = true
	top_mat.albedo_color = top_col
	if not tops.is_empty():
		root.add_child(_instanced(slab, top_mat, tops, top_cols, "Tops"))
	return root


func _build_spikes(rows: Array[String]) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Spikes"
	var xf: Array[Transform3D] = []
	var cols: Array[Color] = []
	for y: int in rows.size():
		for x: int in rows[y].length():
			if rows[y][x] != LevelBuilder.SPIKE:
				continue
			for i: int in 2:
				for k: int in 3:
					var z: float = lerpf(DEPTH_BACK + 0.35, DEPTH_FRONT - 0.3, float(k) / 2.0)
					xf.append(Transform3D(Basis.IDENTITY, Vector3(x + 0.25 + 0.5 * i, -float(y) - 0.75, z)))
					cols.append(Color.WHITE)
	if xf.is_empty():
		return root
	var cone: CylinderMesh = CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.2
	cone.height = 0.5
	cone.radial_segments = 6
	cone.rings = 1
	var m: StandardMaterial3D = _mat(Kit.color("danger", Color.RED).darkened(0.15), 0.3)
	m.roughness = 0.5
	root.add_child(_instanced(cone, m, xf, cols, "Cones"))
	return root


## 4 - Fondo: suelo lejano y colinas con arboles (dia) o edificios con ventanas (noche).
func _build_scenery(rows: Array[String]) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Scenery"
	var w: float = 0.0
	for r: String in rows:
		w = maxf(w, float(r.length()))
	var h: float = float(rows.size())
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7919 + Kit.level_index * 31
	var solid: Color = Kit.color("solid", Color("#4f6787"))
	var ground: Color = solid.darkened(0.55) if is_night() else Color.from_hsv(solid.h, clampf(solid.s + 0.1, 0.2, 0.7), clampf(solid.v * 0.85, 0.35, 0.65))
	var plane: MeshInstance3D = MeshInstance3D.new()
	plane.name = "Ground"
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(w + 160.0, 120.0)
	plane.mesh = pm
	plane.material_override = _mat(ground)
	plane.position = Vector3(w * 0.5, -h - 0.02, DEPTH_BACK - 60.2)
	root.add_child(plane)
	var x0: float = -40.0
	var x1: float = w + 40.0
	if is_night():
		_city(root, rng, x0, x1, -h)
	else:
		_hills(root, rng, x0, x1, -h, ground)
	return root


func _hills(root: Node3D, rng: RandomNumberGenerator, x0: float, x1: float, y0: float, ground: Color) -> void:
	var hx: Array[Transform3D] = []
	var hc: Array[Color] = []
	var x: float = x0
	while x < x1:
		var r: float = rng.randf_range(5.0, 12.0)
		var tall: float = rng.randf_range(0.35, 0.8) * r
		var z: float = rng.randf_range(-42.0, -18.0)
		hx.append(Transform3D(Basis.IDENTITY.scaled(Vector3(r, tall, r * 0.7)), Vector3(x, y0, z)))
		hc.append(ground.lerp(_horizon(), clampf((-z - 18.0) / 40.0, 0.0, 0.35)).darkened(rng.randf_range(0.0, 0.1)))
		x += r * rng.randf_range(0.8, 1.3)
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 14
	sphere.rings = 7
	var hm: StandardMaterial3D = _mat(Color.WHITE)
	hm.vertex_color_use_as_albedo = true
	root.add_child(_instanced(sphere, hm, hx, hc, "Hills"))
	## Arboles low-poly entre el camino y las colinas.
	var tx: Array[Transform3D] = []
	var tc: Array[Color] = []
	var cx: Array[Transform3D] = []
	var cc: Array[Color] = []
	var leaf: Color = Color.from_hsv(fposmod(ground.h + 0.02, 1.0), clampf(ground.s + 0.15, 0.3, 0.8), clampf(ground.v * 0.9, 0.3, 0.6))
	x = x0
	while x < x1:
		x += rng.randf_range(1.6, 4.5)
		var z: float = rng.randf_range(-11.0, -3.2)
		var s: float = rng.randf_range(0.8, 1.5)
		tx.append(Transform3D(Basis.IDENTITY.scaled(Vector3(s, s, s)), Vector3(x, y0 + 0.6 * s, z)))
		tc.append(Color("#6b4a32"))
		cx.append(Transform3D(Basis.IDENTITY.scaled(Vector3(s, s * rng.randf_range(1.0, 1.4), s)), Vector3(x, y0 + 1.9 * s, z)))
		cc.append(leaf.lightened(rng.randf_range(-0.06, 0.1)))
	var trunk: CylinderMesh = CylinderMesh.new()
	trunk.top_radius = 0.12
	trunk.bottom_radius = 0.18
	trunk.height = 1.2
	trunk.radial_segments = 6
	var tm: StandardMaterial3D = _mat(Color.WHITE)
	tm.vertex_color_use_as_albedo = true
	root.add_child(_instanced(trunk, tm, tx, tc, "Trunks"))
	var crown: CylinderMesh = CylinderMesh.new()
	crown.top_radius = 0.0
	crown.bottom_radius = 0.8
	crown.height = 2.0
	crown.radial_segments = 7
	var cm: StandardMaterial3D = _mat(Color.WHITE)
	cm.vertex_color_use_as_albedo = true
	root.add_child(_instanced(crown, cm, cx, cc, "Crowns"))


func _city(root: Node3D, rng: RandomNumberGenerator, x0: float, x1: float, y0: float) -> void:
	var accent: Color = Kit.color("accent", Color.ORANGE)
	var neon: Array[Color] = [accent, Kit.color("coin", Color.YELLOW), Color("#5ee7ff"), Color("#ff5fa2")]
	var bx: Array[Transform3D] = []
	var bc: Array[Color] = []
	var wx: Array[Transform3D] = []
	var wc: Array[Color] = []
	var body: Color = Kit.color("sky", Color("#1b2a41")).darkened(0.35)
	for layer: int in 2:
		var x: float = x0
		while x < x1:
			var bw: float = rng.randf_range(2.5, 6.0)
			var bh: float = rng.randf_range(4.0, 12.0) + layer * 7.0
			var z: float = -16.0 - layer * 16.0 - rng.randf_range(0.0, 6.0)
			bx.append(Transform3D(Basis.IDENTITY.scaled(Vector3(bw, bh, 3.0)), Vector3(x + bw * 0.5, y0 + bh * 0.5, z)))
			bc.append(body.lightened(rng.randf_range(0.0, 0.08) + layer * 0.05))
			## Ventanas encendidas al azar en la cara de delante.
			var col: Color = neon[rng.randi() % neon.size()]
			var fy: float = 1.2
			while fy < bh - 0.8:
				var fx: float = 0.6
				while fx < bw - 0.5:
					if rng.randf() < 0.24:
						wx.append(Transform3D(Basis.IDENTITY, Vector3(x + fx + 0.2, y0 + fy, z + 1.52)))
						wc.append(col if rng.randf() < 0.3 else Color(1.0, 0.86, 0.6))
					fx += 0.9
				fy += 1.3
			x += bw + rng.randf_range(0.3, 2.0)
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3.ONE
	var bm: StandardMaterial3D = _mat(Color.WHITE)
	bm.vertex_color_use_as_albedo = true
	root.add_child(_instanced(box, bm, bx, bc, "Buildings"))
	if wx.is_empty():
		return
	var win: QuadMesh = QuadMesh.new()
	win.size = Vector2(0.4, 0.55)
	var wm: StandardMaterial3D = StandardMaterial3D.new()
	wm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wm.vertex_color_use_as_albedo = true
	root.add_child(_instanced(win, wm, wx, wc, "Windows"))


# ------------------------------------------------------------------ espejo 2D -> 3D

func _on_node_added(n: Node) -> void:
	if n is CanvasItem and game != null and game.is_ancestor_of(n):
		_pending.append(n)


func _collect(root: Node) -> void:
	for c: Node in root.get_children():
		if c is CanvasLayer or c == self:
			continue
		if c is CanvasItem:
			_pending.append(c)
		_collect(c)


## Que hacer con un nodo 2D: "" (no tocar: HUD), "hide" (esconder sin gemelo) o "mirror".
func _role(n: Node) -> String:
	var p: Node = n
	var verdict: String = "mirror"
	while p != null and p != game:
		if p is CanvasLayer:
			return ""
		if p != n and p is MovingPlatform:
			verdict = "hide"
		if p.name == "Solids" or p.is_in_group("spike"):
			verdict = "hide"
		p = p.get_parent()
	if p == null:
		return ""
	return verdict


func _register(n: Node) -> void:
	if not is_instance_valid(n) or not n.is_inside_tree():
		return
	var id: int = n.get_instance_id()
	if _twins.has(id):
		return
	var role: String = _role(n)
	if role == "":
		return
	(n as CanvasItem).visibility_layer = HIDE_LAYER
	if role == "hide":
		return
	var twin: Node3D = null
	var kind: String = ""
	var mat: Material = null
	if n is MovingPlatform:
		var mp: MovingPlatform = n as MovingPlatform
		var mi: MeshInstance3D = MeshInstance3D.new()
		var bm: BoxMesh = BoxMesh.new()
		bm.size = Vector3(mp.width / tile, mp.height / tile, DEPTH_FRONT - DEPTH_BACK)
		mi.mesh = bm
		mi.material_override = _block_mat(Kit.color("solid", Color.WHITE).lightened(0.15))
		twin = mi
		kind = "platform"
	elif n is AnimatedSprite2D:
		var a: AnimatedSprite2D = n as AnimatedSprite2D
		var a3: AnimatedSprite3D = AnimatedSprite3D.new()
		a3.sprite_frames = a.sprite_frames
		_sprite_common(a3, a.centered, a.offset)
		twin = a3
		kind = "anim"
	elif n is Sprite2D:
		var s: Sprite2D = n as Sprite2D
		var s3: Sprite3D = Sprite3D.new()
		s3.texture = s.texture
		s3.hframes = s.hframes
		s3.vframes = s.vframes
		s3.region_enabled = s.region_enabled
		s3.region_rect = s.region_rect
		_sprite_common(s3, s.centered, s.offset)
		twin = s3
		kind = "sprite"
	elif n is Polygon2D:
		var poly: Polygon2D = n as Polygon2D
		var mesh: ArrayMesh = _poly_mesh(poly)
		if mesh == null:
			return
		var pm: MeshInstance3D = MeshInstance3D.new()
		pm.mesh = mesh
		var sm: StandardMaterial3D = StandardMaterial3D.new()
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm.cull_mode = BaseMaterial3D.CULL_DISABLED
		sm.vertex_color_use_as_albedo = true
		if poly.texture != null:
			sm.albedo_texture = poly.texture
			sm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST if _nearest else BaseMaterial3D.TEXTURE_FILTER_LINEAR
			sm.texture_repeat = true
		pm.material_override = sm
		pm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mat = sm
		twin = pm
		kind = "poly"
	elif n is Label:
		var l: Label = n as Label
		var l3: Label3D = Label3D.new()
		l3.pixel_size = 1.0 / tile
		l3.font = l.get_theme_font("font")
		l3.font_size = l.get_theme_font_size("font_size")
		l3.outline_size = l.get_theme_constant("outline_size")
		l3.outline_modulate = l.get_theme_color("font_outline_color")
		l3.no_depth_test = true
		l3.render_priority = 10
		l3.outline_render_priority = 9
		twin = l3
		kind = "label"
	elif n is CPUParticles2D:
		_burst(n as CPUParticles2D)
		return
	else:
		return
	twin.name = "Twin_" + str(n.name)
	_mirror.add_child(twin)
	_twins[id] = {"src": n, "twin": twin, "kind": kind, "z": _depth_of(n), "mat": mat, "a": -1.0}


func _sprite_common(s: SpriteBase3D, centered: bool, off: Vector2) -> void:
	s.pixel_size = 1.0 / tile
	s.centered = centered
	s.offset = Vector2(off.x, -off.y)
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.double_sided = true
	s.shaded = false
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST if _nearest else BaseMaterial3D.TEXTURE_FILTER_LINEAR
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


## Poligono 2D -> malla plana (en casillas, Y hacia arriba) con sus colores por vertice.
func _poly_mesh(poly: Polygon2D) -> ArrayMesh:
	var pts: PackedVector2Array = poly.polygon
	if pts.size() < 3:
		return null
	var idx: PackedInt32Array = Geometry2D.triangulate_polygon(pts)
	if idx.is_empty():
		return null
	var verts: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	var uvs: PackedVector2Array = PackedVector2Array()
	var per_vertex: bool = poly.vertex_colors.size() == pts.size()
	var tex_size: Vector2 = Vector2.ONE
	if poly.texture != null:
		tex_size = Vector2(maxf(poly.texture.get_width(), 1.0), maxf(poly.texture.get_height(), 1.0))
	var has_uv: bool = poly.uv.size() == pts.size()
	for i: int in pts.size():
		var p: Vector2 = pts[i] + poly.offset
		verts.append(Vector3(p.x / tile, -p.y / tile, 0.0))
		colors.append(poly.vertex_colors[i] if per_vertex else Color.WHITE)
		uvs.append((poly.uv[i] if has_uv else pts[i]) / tex_size)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Profundidad del gemelo: delante del plano del juego, ordenado como el dibujo 2D
## (los hijos encima del padre, los hermanos posteriores encima, z_index manda).
func _depth_of(n: Node) -> float:
	var depth: int = 0
	var zi: int = 0
	var relative: bool = true
	var p: Node = n
	while p != null and p != game:
		if p is CanvasItem and relative:
			zi += (p as CanvasItem).z_index
			relative = (p as CanvasItem).z_as_relative
		depth += 1
		p = p.get_parent()
	return 0.01 + float(depth) * 0.006 + float(mini(n.get_index(), 20)) * 0.003 + float(clampi(zi, -10, 60)) * 0.004


## Color heredado: modulate de toda la cadena hasta el juego (y self_modulate del propio nodo).
func _tint(n: CanvasItem) -> Color:
	var c: Color = n.self_modulate
	var p: Node = n
	while p != null and p != game:
		if p is CanvasItem:
			c *= (p as CanvasItem).modulate
		p = p.get_parent()
	return c


func _to3d(xf: Transform2D, z: float) -> Transform3D:
	var b: Basis = Basis(Vector3(xf.x.x, -xf.x.y, 0.0), Vector3(-xf.y.x, xf.y.y, 0.0), Vector3(0.0, 0.0, 1.0))
	return Transform3D(b, Vector3(xf.origin.x / tile, -xf.origin.y / tile, z))


## Estallido 2D -> estallido 3D con los mismos colores, fuerza y cantidad.
func _burst(fx: CPUParticles2D) -> void:
	var p3: CPUParticles3D = CPUParticles3D.new()
	var at: Vector2 = (game.get_global_transform().affine_inverse() * fx.get_global_transform()).origin
	p3.position = Vector3(at.x / tile, -at.y / tile, 0.2)
	p3.one_shot = true
	p3.explosiveness = fx.explosiveness
	p3.amount = maxi(fx.amount, 1)
	p3.lifetime = fx.lifetime
	p3.direction = Vector3(0.0, 1.0, 0.0)
	p3.spread = fx.spread
	p3.initial_velocity_min = fx.initial_velocity_min / tile
	p3.initial_velocity_max = fx.initial_velocity_max / tile
	p3.gravity = Vector3(0.0, -fx.gravity.y / tile, 0.0)
	var cube: BoxMesh = BoxMesh.new()
	var side: float = (fx.scale_amount_min + fx.scale_amount_max) * 0.5 / tile * 1.4
	cube.size = Vector3(side, side, side)
	var m: StandardMaterial3D = _mat(fx.color, 0.6)
	cube.material = m
	p3.mesh = cube
	p3.emitting = true
	_mirror.add_child(p3)
	get_tree().create_timer(fx.lifetime + 0.6).timeout.connect(p3.queue_free)


# ------------------------------------------------------------------ cada frame

func _process(_delta: float) -> void:
	if game == null:
		return
	if not _pending.is_empty():
		var batch: Array[Node] = _pending.duplicate()
		_pending.clear()
		for n: Node in batch:
			_register(n)
	var inv: Transform2D = game.get_global_transform().affine_inverse()
	var gone: Array[int] = []
	for id: int in _twins:
		var e: Dictionary = _twins[id]
		var src: Variant = e["src"]
		var twin: Node3D = e["twin"]
		if not is_instance_valid(src) or not (src as Node).is_inside_tree():
			twin.queue_free()
			gone.append(id)
			continue
		var ci: CanvasItem = src as CanvasItem
		twin.visible = ci.is_visible_in_tree()
		if not twin.visible:
			continue
		var kind: String = e["kind"]
		var z: float = e["z"]
		match kind:
			"platform":
				var o: Vector2 = (inv * (src as Node2D).get_global_transform()).origin
				twin.transform = Transform3D(Basis.IDENTITY, Vector3(o.x / tile, -o.y / tile, (DEPTH_FRONT + DEPTH_BACK) * 0.5))
			"label":
				var l: Label = src as Label
				var lx: Transform2D = inv * l.get_global_transform()
				var center: Vector2 = lx * (l.size * 0.5)
				var l3: Label3D = twin as Label3D
				l3.text = l.text
				l3.position = Vector3(center.x / tile, -center.y / tile, 0.6)
				l3.scale = Vector3(lx.get_scale().x, lx.get_scale().y, 1.0)
				var tint: Color = _tint(l)
				l3.modulate = l.get_theme_color("font_color") * tint
				l3.outline_modulate = Color(l3.outline_modulate, tint.a)
			_:
				twin.transform = _to3d(inv * (src as Node2D).get_global_transform(), z)
				var tint2: Color = _tint(ci)
				if kind == "poly":
					var poly: Polygon2D = src as Polygon2D
					var col: Color = poly.color * tint2
					var sm: StandardMaterial3D = e["mat"]
					if sm.albedo_color != col:
						sm.albedo_color = col
						sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if col.a < 0.99 else BaseMaterial3D.TRANSPARENCY_DISABLED
				elif kind == "anim":
					var a: AnimatedSprite2D = src as AnimatedSprite2D
					var a3: AnimatedSprite3D = twin as AnimatedSprite3D
					if a3.animation != a.animation:
						a3.animation = a.animation
					a3.frame = a.frame
					a3.flip_h = a.flip_h
					a3.flip_v = a.flip_v
					a3.modulate = tint2
				elif kind == "sprite":
					var s: Sprite2D = src as Sprite2D
					var s3: Sprite3D = twin as Sprite3D
					s3.texture = s.texture
					s3.frame = s.frame
					s3.flip_h = s.flip_h
					s3.flip_v = s.flip_v
					s3.modulate = tint2
	for id: int in gone:
		_twins.erase(id)
	_follow()


## 4 - Camara: sigue a la camara 2D (con sus limites y temblores) y ve lo mismo de alto.
func _follow() -> void:
	var cam2: Camera2D = game.get("camera")
	if cam2 == null or _camera == null:
		return
	var c: Vector2 = cam2.get_screen_center_position() + cam2.offset
	var vis: Vector2 = get_viewport().get_visible_rect().size / cam2.zoom
	var h_tiles: float = vis.y / tile
	var dist: float = 0.86 * (h_tiles * 0.5) / tan(deg_to_rad(_camera.fov * 0.5))
	var lift: float = 2.2
	_camera.position = Vector3(c.x / tile - 0.6, -c.y / tile + lift, dist)
	_camera.rotation = Vector3(-atan2(lift, dist), -atan2(0.6, dist), 0.0)


## Para las pruebas: cuantos gemelos hay de cada tipo.
func twin_counts() -> Dictionary:
	var out: Dictionary = {}
	for id: int in _twins:
		var k: String = (_twins[id] as Dictionary)["kind"]
		out[k] = int(out.get(k, 0)) + 1
	return out
