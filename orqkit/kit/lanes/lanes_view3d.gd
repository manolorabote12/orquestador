extends Node3D
## Vista 3D del corredor: solo dibuja el estado de lanes_game.gd.
## 1 - Via de 3 carriles con traviesas y railes, cesped o asfalto a los lados.
## 2 - Ciudad de neon de noche o bosque de dia, segun los colores del juego.
## 3 - Vallas bajas a rayas, barras altas sobre postes, trenes con ventanas, monedas que giran.
## 4 - El heroe es su propio dibujo en 3D (siempre de cara a la camara) con sombra; salta y
##     se agacha. Camara detras y por encima que sigue el carril con suavidad.

const VIEW_BEHIND: float = 12.0
const VIEW_AHEAD: float = 110.0

var game: Node2D
var _camera: Camera3D
var _hero: Node3D
var _hero_sprite: Node3D
var _shadow: MeshInstance3D
var _items: Array[Node3D] = []
var _coins: Array[Node3D] = []
var _shake: float = 0.0
var _cam_x: float = 0.0
var _spin: float = 0.0


func setup(g: Node2D) -> void:
	game = g
	name = "View3D"
	_build_environment()
	var n_rows: int = (game.get("rows") as Array).size()
	add_child(_build_track(n_rows))
	add_child(_build_scenery(n_rows))
	_camera = Camera3D.new()
	_camera.name = "Camera3D"
	_camera.fov = 64.0
	_camera.far = 260.0
	add_child(_camera)
	_camera.make_current()
	_build_hero()


func is_night() -> bool:
	return Kit.color("sky", Color("#1b2a41")).v < 0.3


static func mat(col: Color, emission: float = 0.0) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.85
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emission
	return m


func _box(size: Vector3, col: Color, at: Vector3, emission: float = 0.0) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var b: BoxMesh = BoxMesh.new()
	b.size = size
	b.material = mat(col, emission)
	mi.mesh = b
	mi.position = at
	return mi


# ------------------------------------------------------------------ escenario

func _build_environment() -> void:
	var sky_col: Color = Kit.color("sky", Color("#1b2a41"))
	var horizon: Color = sky_col.lightened(0.2).lerp(Kit.color("accent", Color.ORANGE), 0.12) if is_night() else sky_col.lightened(0.4)
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sm: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sm.sky_top_color = sky_col if is_night() else sky_col.darkened(0.1)
	sm.sky_horizon_color = horizon
	sm.ground_horizon_color = horizon
	sm.ground_bottom_color = sky_col.darkened(0.4)
	var sky: Sky = Sky.new()
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.75 if is_night() else 0.95
	env.fog_enabled = true
	env.fog_light_color = horizon
	env.fog_density = 0.007
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	sun.light_energy = 0.6 if is_night() else 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)


func _build_track(n_rows: int) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Track"
	var consts: Dictionary = (game.get_script() as Script).get_script_constant_map()
	var row: float = consts["ROW"]
	var lw: float = consts["LANE_W"]
	var length: float = float(n_rows + 30) * row
	var solid: Color = Kit.color("solid", Color("#4f6787"))
	var ground: Color = solid.darkened(0.55) if is_night() else Color.from_hsv(solid.h, clampf(solid.s + 0.1, 0.2, 0.75), clampf(solid.v, 0.4, 0.7))
	var g: MeshInstance3D = _box(Vector3(400.0, 0.1, length + 200.0), ground, Vector3(0, -0.1, -length * 0.5 + 40.0))
	root.add_child(g)
	## Lecho de grava de cada carril, railes y traviesas (MultiMesh: miles sin coste).
	var bed: Color = Color(0.28, 0.27, 0.3) if is_night() else Color(0.55, 0.5, 0.45)
	for l: int in 3:
		var x: float = float(l - 1) * lw
		root.add_child(_box(Vector3(lw * 0.92, 0.06, length), bed, Vector3(x, 0.0, -length * 0.5 + 20.0)))
		for s: float in [-0.55, 0.55]:
			root.add_child(_box(Vector3(0.08, 0.1, length), Color(0.75, 0.76, 0.8), Vector3(x + s, 0.1, -length * 0.5 + 20.0)))
	var sleeper: BoxMesh = BoxMesh.new()
	sleeper.size = Vector3(lw * 0.8, 0.06, 0.28)
	sleeper.material = mat(Color(0.35, 0.25, 0.18))
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = sleeper
	var per_lane: int = int(length / 1.2)
	mm.instance_count = per_lane * 3
	for l: int in 3:
		for k: int in per_lane:
			mm.set_instance_transform(l * per_lane + k, Transform3D(Basis(), Vector3(float(l - 1) * lw, 0.05, 20.0 - float(k) * 1.2)))
	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	root.add_child(mmi)
	## Meta: arco a cuadros.
	var finish_z: float = -float(game.get("track_len"))
	root.add_child(_box(Vector3(0.4, 4.0, 0.4), Color.WHITE, Vector3(-lw * 1.7, 2.0, finish_z)))
	root.add_child(_box(Vector3(0.4, 4.0, 0.4), Color.WHITE, Vector3(lw * 1.7, 2.0, finish_z)))
	for q: int in 10:
		var col: Color = Color.WHITE if q % 2 == 0 else Color(0.05, 0.05, 0.05)
		root.add_child(_box(Vector3(lw * 3.4 / 10.0, 0.6, 0.2), col, Vector3(-lw * 1.7 + (float(q) + 0.5) * lw * 3.4 / 10.0, 3.8, finish_z)))
	return root


func _build_scenery(n_rows: int) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Scenery"
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 4321 + Kit.level_index * 31
	var length: float = float(n_rows + 30) * 6.0
	var blocks: Array[Transform3D] = []
	var lights: Array[Transform3D] = []
	var z: float = 20.0
	while z > -length:
		for s: float in [-1.0, 1.0]:
			if rng.randf() < 0.25:
				continue
			var x: float = s * rng.randf_range(7.0, 22.0)
			if is_night():
				var hgt: float = rng.randf_range(6.0, 26.0)
				var w: float = rng.randf_range(3.5, 6.5)
				blocks.append(Transform3D(Basis().scaled(Vector3(w, hgt, rng.randf_range(4.0, 7.0))), Vector3(x, hgt * 0.5, z)))
				for k: int in rng.randi_range(1, 3):
					lights.append(Transform3D(Basis().scaled(Vector3(0.12, 0.22, 3.5)), Vector3(x - s * w * 0.5 - s * 0.07, rng.randf_range(2.0, hgt - 0.5), z)))
			else:
				var sc: float = rng.randf_range(0.9, 1.7)
				blocks.append(Transform3D(Basis().scaled(Vector3(sc, sc * rng.randf_range(1.0, 1.5), sc)), Vector3(x, 1.4 * sc, z)))
		z -= rng.randf_range(4.0, 9.0)
	var shape: Mesh
	var body_col: Color
	if is_night():
		var bm: BoxMesh = BoxMesh.new()
		bm.size = Vector3.ONE
		shape = bm
		body_col = Kit.color("solid", Color("#4f6787")).darkened(0.6)
	else:
		var cone: CylinderMesh = CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 1.1
		cone.height = 2.8
		cone.radial_segments = 7
		shape = cone
		var leaf: Color = Kit.color("accent", Color("#4cc26a"))
		body_col = Color.from_hsv(fposmod(leaf.h + 0.25, 1.0) if absf(leaf.h - 0.33) > 0.2 else leaf.h, 0.55, 0.55)
	(shape as PrimitiveMesh).material = mat(body_col)
	for pair: Array in [[shape, blocks], [null, lights]]:
		var list: Array = pair[1]
		if list.is_empty():
			continue
		var mesh: Mesh = pair[0]
		if mesh == null:
			var nm: BoxMesh = BoxMesh.new()
			nm.size = Vector3.ONE
			nm.material = mat(Kit.color("accent", Color.ORANGE), 1.3)
			mesh = nm
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = list.size()
		for k: int in list.size():
			mm.set_instance_transform(k, list[k])
		var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
		mmi.multimesh = mm
		root.add_child(mmi)
	return root


# ------------------------------------------------------------------ heroe y objetos

func _build_hero() -> void:
	_hero = Node3D.new()
	_hero.name = "Hero"
	add_child(_hero)
	var art: Dictionary = Kit.sprite_by_role("jugador")
	if not art.is_empty():
		var spr: AnimatedSprite3D = AnimatedSprite3D.new()
		spr.sprite_frames = SpriteKit.frames_de(art)
		var celda: Array = art.get("celda", [32, 32])
		spr.pixel_size = 1.6 / maxf(float(celda[1]), 1.0)
		spr.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST if str(Kit.param("ui.profile", "")) == "pixel" else BaseMaterial3D.TEXTURE_FILTER_LINEAR
		spr.shaded = false
		spr.position = Vector3(0, 0.8, 0)
		if spr.sprite_frames.has_animation("run"):
			spr.play("run")
		elif spr.sprite_frames.has_animation("idle"):
			spr.play("idle")
		_hero_sprite = spr
	else:
		var cap: MeshInstance3D = MeshInstance3D.new()
		var cm: CapsuleMesh = CapsuleMesh.new()
		cm.radius = 0.35
		cm.height = 1.5
		cm.material = mat(Skins.recolor(Kit.color("accent", Color.ORANGE)))
		cap.mesh = cm
		cap.position = Vector3(0, 0.75, 0)
		_hero_sprite = cap
	_hero.add_child(_hero_sprite)
	_shadow = MeshInstance3D.new()
	var disc: CylinderMesh = CylinderMesh.new()
	disc.top_radius = 0.5
	disc.bottom_radius = 0.5
	disc.height = 0.02
	var sm: StandardMaterial3D = mat(Color(0, 0, 0, 0.45))
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	disc.material = sm
	_shadow.mesh = disc
	add_child(_shadow)


func _make_item(kind: String) -> Node3D:
	var n: Node3D = Node3D.new()
	match kind:
		"C":
			var m: MeshInstance3D = MeshInstance3D.new()
			var cyl: CylinderMesh = CylinderMesh.new()
			cyl.top_radius = 0.38
			cyl.bottom_radius = 0.38
			cyl.height = 0.1
			cyl.radial_segments = 16
			cyl.material = mat(Kit.color("coin", Color("#f6cf7a")), 0.6)
			m.mesh = cyl
			m.rotation = Vector3(PI * 0.5, 0, 0)
			m.position = Vector3(0, 0.9, 0)
			n.add_child(m)
			_coins.append(n)
		"B":
			## Valla baja a rayas: se salta.
			for k: int in 5:
				var col: Color = Color(0.95, 0.2, 0.15) if k % 2 == 0 else Color(0.97, 0.97, 0.97)
				n.add_child(_box(Vector3(0.38, 0.32, 0.22), col, Vector3(-0.76 + 0.38 * float(k), 0.5, 0)))
			n.add_child(_box(Vector3(0.1, 0.5, 0.1), Color(0.3, 0.3, 0.32), Vector3(-0.85, 0.25, 0)))
			n.add_child(_box(Vector3(0.1, 0.5, 0.1), Color(0.3, 0.3, 0.32), Vector3(0.85, 0.25, 0)))
		"H":
			## Barra alta sobre dos postes: hay que agacharse.
			n.add_child(_box(Vector3(0.14, 2.0, 0.14), Color(0.3, 0.3, 0.34), Vector3(-0.95, 1.0, 0)))
			n.add_child(_box(Vector3(0.14, 2.0, 0.14), Color(0.3, 0.3, 0.34), Vector3(0.95, 1.0, 0)))
			n.add_child(_box(Vector3(2.0, 0.45, 0.2), Kit.color("danger", Color("#ff6b5b")), Vector3(0, 1.45, 0), 0.4))
		"W":
			## Tren: largo, con ventanas iluminadas.
			var body: Color = Kit.color("enemy", Color("#d9774a"))
			n.add_child(_box(Vector3(2.0, 2.6, 5.6), body, Vector3(0, 1.4, 0)))
			n.add_child(_box(Vector3(2.02, 0.5, 5.62), body.darkened(0.35), Vector3(0, 0.35, 0)))
			for z: float in [-1.8, -0.6, 0.6, 1.8]:
				for s: float in [-1.0, 1.0]:
					n.add_child(_box(Vector3(0.04, 0.6, 0.8), Color(1.0, 0.92, 0.6), Vector3(s * 1.01, 1.9, z), 1.2))
			n.add_child(_box(Vector3(1.4, 0.7, 0.04), Color(1.0, 0.95, 0.7), Vector3(0, 1.9, 2.81), 1.6))
	return n


func rebuild() -> void:
	for n: Node3D in _items:
		n.queue_free()
	_items.clear()
	_coins.clear()
	for it: Dictionary in game.get("items"):
		var n: Node3D = _make_item(str(it["kind"]))
		add_child(n)
		n.position = Vector3(float(game.call("lane_x", int(it["lane"]))), 0.0, -float(it["d"]))
		_items.append(n)
	_cam_x = float(game.get("lat"))
	sync()


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func sync() -> void:
	if _hero == null:
		return
	var d: float = game.get("d")
	var lat: float = game.get("lat")
	var h: float = float(game.call("height"))
	var sliding: bool = float(game.get("slide_t")) > 0.0
	_hero.position = Vector3(lat, h, -d)
	_hero_sprite.scale = Vector3(1.15, 0.55, 1.0) if sliding else Vector3.ONE
	_hero_sprite.position.y = 0.45 if sliding else 0.8
	_hero.visible = not (float(game.get("invuln")) > 0.0 and int(float(game.get("invuln")) * 10.0) % 2 == 0)
	_shadow.position = Vector3(lat, 0.08, -d)
	_shadow.scale = Vector3.ONE * clampf(1.0 - h * 0.25, 0.5, 1.0)
	var items: Array = game.get("items")
	for k: int in mini(items.size(), _items.size()):
		var it: Dictionary = items[k]
		var dd: float = float(it["d"]) - d
		_items[k].visible = bool(it["alive"]) and dd > -VIEW_BEHIND and dd < VIEW_AHEAD
	_update_camera(d, lat, h)


func _update_camera(d: float, lat: float, h: float) -> void:
	_cam_x = lerpf(_cam_x, lat, 0.12)
	var pos: Vector3 = Vector3(_cam_x * 0.85, 3.4 + h * 0.35, -d + 6.2)
	if _shake > 0.0:
		pos += Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * _shake * 0.35
		_shake = maxf(_shake - 0.03, 0.0)
	_camera.position = pos
	_camera.look_at(Vector3(_cam_x * 0.7, 1.0 + h * 0.2, -d - 9.0), Vector3.UP)
	var k: float = clampf(float(game.get("speed")) / 16.0, 0.0, 1.4)
	_camera.fov = lerpf(_camera.fov, 60.0 + 10.0 * k, 0.08)


func _process(delta: float) -> void:
	_spin += delta * 3.5
	for c: Node3D in _coins:
		if c.visible:
			c.rotation.y = _spin
