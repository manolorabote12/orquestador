extends Node3D
## Shooter 3D de zombis en primera persona: aguanta todas las oleadas en la arena. Mando a la
## izquierda, arrastra a la derecha para mirar (con ayuda de punteria suave), boton de disparo,
## recarga y cambio de arma. Armas y botiquines repartidos por el mapa.
## Cooperativo en directo (Online.arena_match con modo "coop"): hasta 4 en la misma arena; el
## anfitrion mueve los zombis y cada uno manda como va (ver zombie_map.gd, punto 3).
## Reglas, zombis, bot y analizador en zombie_map.gd.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const M = preload("res://kit/zombie/zombie_map.gd")
const T: float = 2.0
const EYE: float = 1.6
const SKIN: Dictionary = {
	"walker": [Color("#7f9a6a"), Color("#4f5d72"), Color("#3a3226")],
	"runner": [Color("#a3b58a"), Color("#8c2f2f"), Color("#2b2b33")],
	"brute": [Color("#6b7f58"), Color("#5a4a3a"), Color("#26221c")],
}

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
var _gun: Node3D
var _gun_models: Dictionary = {}
var _flash_light: OmniLight3D
var _flash_mesh: MeshInstance3D
var _kick: float = 0.0
var _zomb: Dictionary = {}
var _picks: Array = []
var _heals: Array = []
var _blood: CPUParticles3D
var _hud: Control
var _info: Label
var _wave_lbl: Label
var _ammo_lbl: Label
var _hp_bar: Control
var _hurt: ColorRect
var _fire_btn: Button
var _reload_btn: Button
var _swap_btn: Button
var _hit_t: float = 0.0
var _bot: bool = false
var _t: float = 0.0
var _move_id: int = -1
var _move_o: Vector2 = Vector2.ZERO
var _move_v: Vector2 = Vector2.ZERO
var _look_id: int = -1
var _look_last: Vector2 = Vector2.ZERO
var _firing: bool = false
var _want_reload: bool = false
var _bob: float = 0.0
var _total: int = 0
## En directo: sala, canal, quien mueve los zombis y los companeros en pantalla.
var online: Dictionary = {}
var host: bool = false
var net: RealtimeChannel = null
var reported: bool = false
var _send_acc: float = 0.0
var _snap_acc: float = 0.0
var _start_ms: int = 0
var _mate_nodes: Dictionary = {}
var _team_lbl: Label
var _down: ColorRect
const NET_RATE: float = 0.125
const NET_TIMEOUT: float = 8.0


func _ready() -> void:
	level = Kit.current_level()
	if not level.has("fps") and Kit.param("fps", null) is Dictionary:
		level = level.duplicate()
		level["fps"] = Kit.param("fps", {})
	par = float(level.get("par", 200))
	if str(Online.arena_match.get("modo", "")) == "coop":
		online = Online.arena_match.duplicate(true)
	_reset()
	_build_env()
	_build_arena()
	_build_gun()
	_build_hud()
	if not online.is_empty():
		_net_open()
		_build_mates()
	_sync(1.0)
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "zombie", "waves": int(st["waves"]), "online": not online.is_empty()})


func bot_script() -> String:
	return "res://qa/zombie_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(9.0, 2.5)


func wants_backdrop() -> bool:
	return false


func _reset() -> void:
	finished = false
	failed = false
	if online.is_empty():
		st = M.new_state(level)
	else:
		_net_state_setup()
	coins = 0
	time_in_level = 0.0
	_total = 0
	for w: int in int(st["waves"]):
		_total += int(st["count"]) + int(st["grow"]) * w
	coins_total = _total
	for id: Variant in _zomb.keys():
		(_zomb[id] as Node3D).queue_free()
	_zomb.clear()


static func mat(col: Color, emission: float = 0.0) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.85
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emission
	if col.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
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
	return Vector3(p.x * T, y, p.y * T)


## Textura hecha a mano (sin archivos): losas de hormigon con manchas o tablones de caja.
static func _tex(kind: String, seed_v: int) -> ImageTexture:
	var img: Image = Image.create(64, 64, false, Image.FORMAT_RGB8)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_v
	for y: int in 64:
		for x: int in 64:
			var v: float = rng.randf_range(0.85, 1.0)
			var c: Color
			if kind == "floor":
				c = Color("#5b5a57") * v
				if x % 32 == 0 or y % 32 == 0:
					c = Color("#3e3d3b")
			elif kind == "crate":
				c = Color("#8a6334") * v
				if y % 16 == 0 or x < 3 or x > 60:
					c = Color("#4b3219")
				if absi(x - y) < 3 or absi(x - (63 - y)) < 3:
					c = Color("#5e4021")
			else:
				c = Color("#6e6a63") * v
				if y % 12 == 0 or (x + (y / 12) * 16) % 32 == 0:
					c = Color("#4a4640")
			img.set_pixel(x, y, Color(c.r, c.g, c.b))
	## Manchas oscuras.
	if kind == "floor":
		for k: int in 5:
			var cx: int = rng.randi_range(0, 63)
			var cy: int = rng.randi_range(0, 63)
			for yy: int in range(-6, 7):
				for xx: int in range(-6, 7):
					if xx * xx + yy * yy < 30 and rng.randf() < 0.7:
						var px: int = posmod(cx + xx, 64)
						var py: int = posmod(cy + yy, 64)
						img.set_pixel(px, py, img.get_pixel(px, py) * 0.7)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func _tmat(tex: Texture2D, scale: Vector3) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_texture = tex
	m.uv1_scale = scale
	m.roughness = 0.9
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return m


# ------------------------------------------------------------------ arena

func _build_env() -> void:
	var env: Environment = Environment.new()
	var sky: Sky = Sky.new()
	var sm: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("#2a2140")
	sm.sky_horizon_color = Color("#c2603a")
	sm.ground_bottom_color = Color("#1a1612")
	sm.ground_horizon_color = Color("#6b3a28")
	sm.sun_angle_max = 12.0
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#b8a8c8")
	env.ambient_light_energy = 0.28
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.light_color = Color("#ffb27a")
	sun.light_energy = 0.5
	sun.rotation_degrees = Vector3(-28, -40, 0)
	add_child(sun)
	_cam = Camera3D.new()
	## En vertical se mide el angulo a lo ancho (si no, en el movil se ve todo por un tubo).
	_cam.keep_aspect = Camera3D.KEEP_WIDTH
	_cam.fov = 70.0
	_cam.near = 0.05
	_cam.far = 120.0
	add_child(_cam)
	_cam.make_current()


func _build_arena() -> void:
	var w: int = int(st["w"])
	var h: int = int(st["h"])
	var walls: Array[Vector3] = []
	var crates: Array[Vector3] = []
	for y: int in h:
		for x: int in w:
			var c: String = M.cell(st, x, y)
			var at: Vector3 = Vector3((x + 0.5) * T, 0, (y + 0.5) * T)
			if c == "#":
				walls.append(at)
			elif c == "c":
				crates.append(at)
	var floor_mi: MeshInstance3D = MeshInstance3D.new()
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(w * T + 40.0, h * T + 40.0)
	pm.material = _tmat(_tex("floor", 3), Vector3((w * T + 40.0) / 4.0, (h * T + 40.0) / 4.0, 1))
	floor_mi.mesh = pm
	floor_mi.position = Vector3(w * T / 2.0, 0, h * T / 2.0)
	add_child(floor_mi)
	_multi("Walls", walls, Vector3(T, 3.2, T), _tmat(_tex("wall", 5), Vector3(1, 1.6, 1)), Vector3(0, 1.6, 0))
	_multi("Crates", crates, Vector3(T * 0.9, 1.3, T * 0.9), _tmat(_tex("crate", 7), Vector3(1, 1, 1)), Vector3(0, 0.65, 0))
	## Ciudad en ruinas alrededor (para que no se vea el vacio).
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = w * 13 + h
	var ruins: Array[Vector3] = []
	var cx: float = w * T / 2.0
	var cz: float = h * T / 2.0
	for k: int in 34:
		var a: float = TAU * float(k) / 34.0 + rng.randf_range(-0.05, 0.05)
		var rad: float = maxf(w, h) * T * 0.75 + rng.randf_range(6.0, 16.0)
		ruins.append(Vector3(cx + cos(a) * rad, 0, cz + sin(a) * rad))
	for k2: int in ruins.size():
		var hh: float = rng.randf_range(6.0, 18.0)
		_box(Vector3(rng.randf_range(5.0, 9.0), hh, rng.randf_range(5.0, 9.0)), Color("#2e2a2c").lerp(Color("#4a3c36"), rng.randf()), ruins[k2] + Vector3(0, hh / 2.0, 0))
		## Alguna ventana encendida.
		if rng.randf() < 0.4:
			_box(Vector3(0.9, 0.7, 0.2), Color("#ffb347"), ruins[k2] + Vector3(0, hh * 0.6, 0) + (Vector3(cx, 0, cz) - ruins[k2]).normalized() * 3.0, null, 1.4)
	## Farolas en las esquinas de la arena.
	for corner: Vector2 in [Vector2(1.5, 1.5), Vector2(w - 1.5, 1.5), Vector2(1.5, h - 1.5), Vector2(w - 1.5, h - 1.5)]:
		var base: Vector3 = to3(corner)
		_box(Vector3(0.15, 4.2, 0.15), Color("#2b2b2b"), base + Vector3(0, 2.1, 0))
		_box(Vector3(0.6, 0.15, 0.4), Color("#ffe0a0"), base + Vector3(0, 4.25, 0), null, 2.0)
		var lamp: OmniLight3D = OmniLight3D.new()
		lamp.light_color = Color("#ffd29a")
		lamp.light_energy = 1.4
		lamp.omni_range = 11.0
		lamp.position = base + Vector3(0, 4.0, 0)
		add_child(lamp)
	## Armas por el suelo.
	for pk: Dictionary in st["pickups"]:
		var node: Node3D = Node3D.new()
		node.position = to3(M.center(pk["c"]), 0.9)
		add_child(node)
		var model: Node3D = _gun_model(str(pk["item"]))
		model.scale = Vector3(1.6, 1.6, 1.6)
		node.add_child(model)
		var ring: MeshInstance3D = MeshInstance3D.new()
		var cyl: CylinderMesh = CylinderMesh.new()
		cyl.top_radius = 0.6
		cyl.bottom_radius = 0.6
		cyl.height = 0.04
		cyl.material = mat(Color(1.0, 0.8, 0.2, 0.55), 1.5)
		ring.mesh = cyl
		ring.position = Vector3(0, -0.86, 0)
		node.add_child(ring)
		_picks.append(node)
	## Botiquines (salen entre oleadas).
	for hl: Dictionary in st["heals"]:
		var kit_n: Node3D = Node3D.new()
		kit_n.position = to3(M.center(hl["c"]), 0.35)
		add_child(kit_n)
		_box(Vector3(0.6, 0.4, 0.45), Color("#f2f2f2"), Vector3.ZERO, kit_n, 0.3)
		_box(Vector3(0.36, 0.1, 0.47), Color("#e53935"), Vector3(0, 0, 0), kit_n, 1.0)
		_box(Vector3(0.1, 0.36, 0.47), Color("#e53935"), Vector3(0, 0, 0), kit_n, 1.0)
		_heals.append(kit_n)
	## Sangre al acertar.
	_blood = CPUParticles3D.new()
	_blood.emitting = false
	_blood.one_shot = true
	_blood.amount = 14
	_blood.lifetime = 0.5
	_blood.explosiveness = 1.0
	_blood.direction = Vector3(0, 1, 0)
	_blood.spread = 70.0
	_blood.initial_velocity_min = 1.5
	_blood.initial_velocity_max = 3.5
	_blood.gravity = Vector3(0, -9.0, 0)
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(0.06, 0.06, 0.06)
	bm.material = mat(Color("#8e0f12"))
	_blood.mesh = bm
	add_child(_blood)


func _multi(nm: String, at: Array[Vector3], size: Vector3, m: Material, off: Vector3) -> void:
	if at.is_empty():
		return
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var b: BoxMesh = BoxMesh.new()
	b.size = size
	b.material = m
	mm.mesh = b
	mm.instance_count = at.size()
	for k: int in at.size():
		mm.set_instance_transform(k, Transform3D(Basis.IDENTITY, at[k] + off))
	var mi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mi.name = nm
	mi.multimesh = mm
	add_child(mi)


## Arma hecha con cajas (pistola, escopeta o fusil), apuntando hacia -Z.
func _gun_model(kind: String) -> Node3D:
	var g: Node3D = Node3D.new()
	var metal: Color = Color("#2d3036")
	var lk: String = str((st.get("weapons", M.WEAPONS) as Dictionary).get(kind, {}).get("look", M.LOOKS.get(kind, "pistol"))) if not st.is_empty() else str(M.LOOKS.get(kind, "pistol"))
	match lk:
		"shotgun":
			_box(Vector3(0.07, 0.07, 0.62), metal, Vector3(0, 0.02, -0.25), g)
			_box(Vector3(0.09, 0.09, 0.22), Color("#6b4423"), Vector3(0, -0.02, -0.12), g)
			_box(Vector3(0.08, 0.14, 0.22), Color("#6b4423"), Vector3(0, -0.04, 0.12), g)
		"rifle":
			_box(Vector3(0.06, 0.08, 0.6), metal, Vector3(0, 0.02, -0.2), g)
			_box(Vector3(0.05, 0.16, 0.07), Color("#1f2125"), Vector3(0, -0.08, -0.12), g)
			_box(Vector3(0.06, 0.12, 0.2), Color("#3d4a2f"), Vector3(0, -0.01, 0.14), g)
			_box(Vector3(0.03, 0.05, 0.12), metal, Vector3(0, 0.08, -0.1), g)
		_:
			_box(Vector3(0.06, 0.07, 0.24), metal, Vector3(0, 0.02, -0.06), g)
			_box(Vector3(0.05, 0.13, 0.06), Color("#1f2125"), Vector3(0, -0.07, 0.03), g)
	return g


func _build_gun() -> void:
	_gun = Node3D.new()
	_gun.position = Vector3(0.12, -0.17, -0.36)
	_gun.rotation.y = 0.06
	_gun.scale = Vector3(0.62, 0.62, 0.62)
	_cam.add_child(_gun)
	for kind: String in (st["weapons"] as Dictionary).keys():
		var model: Node3D = _gun_model(kind)
		model.visible = false
		_gun.add_child(model)
		_gun_models[kind] = model
	## Brazo.
	_box(Vector3(0.07, 0.07, 0.1), Color("#c48a63"), Vector3(0.0, -0.08, 0.06), _gun)
	_box(Vector3(0.1, 0.1, 0.22), Color("#3b4636"), Vector3(0.02, -0.11, 0.2), _gun)
	_flash_light = OmniLight3D.new()
	_flash_light.light_color = Color("#ffcf73")
	_flash_light.light_energy = 0.0
	_flash_light.omni_range = 7.0
	_flash_light.position = Vector3(0, 0.05, -0.7)
	_gun.add_child(_flash_light)
	_flash_mesh = _box(Vector3(0.12, 0.12, 0.12), Color("#ffd27a"), Vector3(0, 0.03, -0.62), _gun, 4.0)
	_flash_mesh.visible = false


## Zombi hecho con cajas: piernas, cuerpo con ropa rota, brazos hacia delante y ojos rojos.
func _zombie_node(z: Dictionary) -> Node3D:
	var kind: String = z["kind"]
	var cols: Array = SKIN[kind]
	var s: float = 1.35 if kind == "brute" else (0.9 if kind == "runner" else 1.0)
	var n: Node3D = Node3D.new()
	add_child(n)
	var body: Node3D = Node3D.new()
	body.name = "Body"
	body.scale = Vector3(s * (1.25 if kind == "brute" else 1.0), s, s)
	n.add_child(body)
	for sx: float in [-0.13, 0.13]:
		var leg: MeshInstance3D = _box(Vector3(0.17, 0.8, 0.18), cols[2], Vector3(sx, 0.4, 0), body)
		leg.name = "LegL" if sx < 0 else "LegR"
	_box(Vector3(0.5, 0.62, 0.28), cols[1], Vector3(0, 1.1, 0), body)
	_box(Vector3(0.18, 0.2, 0.29), cols[0], Vector3(0.1, 0.95, 0.0), body)
	var head: MeshInstance3D = _box(Vector3(0.3, 0.32, 0.3), cols[0], Vector3(0.0, 1.6, -0.02), body)
	head.name = "Head"
	for ex: float in [-0.07, 0.07]:
		_box(Vector3(0.06, 0.04, 0.02), Color("#ff2a1a"), Vector3(ex, 1.63, -0.17), body, 3.0)
	_box(Vector3(0.14, 0.04, 0.02), Color("#2a0d0d"), Vector3(0, 1.51, -0.17), body)
	for ax: float in [-0.32, 0.32]:
		var arm: Node3D = Node3D.new()
		arm.name = "ArmL" if ax < 0 else "ArmR"
		arm.position = Vector3(ax, 1.35, 0)
		body.add_child(arm)
		_box(Vector3(0.13, 0.13, 0.6), cols[0], Vector3(0, -0.02, -0.28), arm)
		_box(Vector3(0.15, 0.15, 0.22), cols[1], Vector3(0, 0, -0.05), arm)
	return n


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
	_hurt = ColorRect.new()
	_hurt.color = Color(0.7, 0, 0, 0)
	_hurt.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hurt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_hurt)
	var safe: MarginContainer = UI.safe_root(_hud, 14.0)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	safe.add_child(top)
	_hp_bar = Control.new()
	_hp_bar.custom_minimum_size = Vector2(230, 56)
	_hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_bar.draw.connect(_draw_hp)
	top.add_child(_hp_bar)
	_wave_lbl = Label.new()
	_wave_lbl.name = "Wave"
	_wave_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wave_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wave_lbl.add_theme_font_size_override("font_size", 30)
	_wave_lbl.add_theme_color_override("font_color", Color("#ffd8a8"))
	_wave_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_wave_lbl.add_theme_constant_override("outline_size", 8)
	top.add_child(_wave_lbl)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)
	_info = Label.new()
	_info.name = "Info"
	_info.add_theme_font_size_override("font_size", 44)
	_info.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_info.add_theme_constant_override("outline_size", 10)
	_info.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_info.position = Vector2(-320, 200)
	_info.size = Vector2(640, 120)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_info)
	_say(Kit.text("zb_hint", "Aguanta todas las oleadas. \u00a1Busca armas mejores!"), Color("#f0e6d8"))
	## Botones de la derecha: disparo grande, recarga y cambio de arma encima.
	_fire_btn = UI.make_button(Kit.text("zb_fire", "Disparar"), true)
	_fire_btn.name = "BtnFire"
	_fire_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_fire_btn.offset_left = -250.0
	_fire_btn.offset_top = -330.0
	_fire_btn.offset_right = -40.0
	_fire_btn.offset_bottom = -170.0
	_fire_btn.button_down.connect(func() -> void: _firing = true)
	_fire_btn.button_up.connect(func() -> void: _firing = false)
	_hud.add_child(_fire_btn)
	_reload_btn = UI.make_button(Kit.text("zb_reload", "Recargar"), false)
	_reload_btn.name = "BtnReload"
	_reload_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_reload_btn.offset_left = -250.0
	_reload_btn.offset_top = -450.0
	_reload_btn.offset_right = -40.0
	_reload_btn.offset_bottom = -360.0
	_reload_btn.pressed.connect(func() -> void: _want_reload = true)
	_hud.add_child(_reload_btn)
	_swap_btn = UI.make_button(Kit.text("zb_swap", "Cambiar arma"), false)
	_swap_btn.name = "BtnSwap"
	_swap_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_swap_btn.offset_left = -250.0
	_swap_btn.offset_top = -560.0
	_swap_btn.offset_right = -40.0
	_swap_btn.offset_bottom = -470.0
	_swap_btn.pressed.connect(_swap)
	_hud.add_child(_swap_btn)
	_ammo_lbl = Label.new()
	_ammo_lbl.name = "Ammo"
	_ammo_lbl.add_theme_font_size_override("font_size", 34)
	_ammo_lbl.add_theme_color_override("font_color", Color("#ffffff"))
	_ammo_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_ammo_lbl.add_theme_constant_override("outline_size", 8)
	_ammo_lbl.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_ammo_lbl.offset_left = -330.0
	_ammo_lbl.offset_top = -150.0
	_ammo_lbl.offset_right = -40.0
	_ammo_lbl.offset_bottom = -90.0
	_ammo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ammo_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_ammo_lbl)


func _draw_hp() -> void:
	var me: Dictionary = st["me"]
	var f: float = clampf(float(me["hp"]) / float(me["max_hp"]), 0.0, 1.0)
	_hp_bar.draw_rect(Rect2(0, 12, 220, 30), Color(0, 0, 0, 0.55))
	var col: Color = Color("#4caf50") if f > 0.5 else (Color("#ffb300") if f > 0.25 else Color("#e53935"))
	_hp_bar.draw_rect(Rect2(3, 15, 214.0 * f, 24), col)
	## Cruz de vida.
	_hp_bar.draw_rect(Rect2(6, 22, 20, 10), Color.WHITE)
	_hp_bar.draw_rect(Rect2(11, 17, 10, 20), Color.WHITE)


func _draw_hud() -> void:
	var sz: Vector2 = _hud.size
	var c: Vector2 = sz / 2.0
	## Mira (se abre al disparar y se pone roja al acertar).
	var spread: float = 10.0 + _kick * 40.0 + float(st["weapons"][str(st["me"]["weapon"])]["spread"]) * 150.0
	var col: Color = Color("#ff5252") if _hit_t > 0.0 else Color(1, 1, 1, 0.85)
	for d: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		_hud.draw_line(c + d * spread, c + d * (spread + 14.0), col, 3.0)
	_hud.draw_circle(c, 2.5, col)
	if _move_id >= 0:
		_hud.draw_circle(_move_o, 100.0, Color(1, 1, 1, 0.08))
		_hud.draw_arc(_move_o, 100.0, 0.0, TAU, 48, Color(1, 1, 1, 0.25), 3.0)
		_hud.draw_circle(_move_o + Vector2(_move_v.x, -_move_v.y) * 100.0, 40.0, Color(1, 1, 1, 0.3))
	elif not _bot:
		var home: Vector2 = Vector2(170.0, sz.y - 280.0)
		_hud.draw_arc(home, 90.0, 0.0, TAU, 40, Color(1, 1, 1, 0.16), 3.0)
	## Radar: puntos rojos de los zombis cercanos alrededor de la mira.
	var me_p: Vector2 = st["me"]["p"]
	var yaw: float = float(st["yaw"])
	for z: Dictionary in st["zombies"]:
		if float(z["hp"]) <= 0.0:
			continue
		var to: Vector2 = (z["p"] as Vector2) - me_p
		if to.length() > 8.0:
			continue
		var rel: float = wrapf(atan2(-to.x, -to.y) - yaw, -PI, PI)
		if absf(rel) < 0.6:
			continue
		var dir: Vector2 = Vector2(-sin(rel), -cos(rel))
		_hud.draw_circle(c + Vector2(dir.x, dir.y) * 150.0, 9.0, Color(1, 0.2, 0.15, clampf(1.2 - to.length() / 8.0, 0.25, 0.9)))


func _say(text: String, col: Color) -> void:
	if fast or _info == null:
		return
	_info.text = text
	_info.add_theme_color_override("font_color", col)
	_info.modulate.a = 1.0
	var tw: Tween = _info.create_tween()
	tw.tween_interval(1.8)
	tw.tween_property(_info, "modulate:a", 0.0, 0.6)


func _swap() -> void:
	var me: Dictionary = st["me"]
	var guns: Array = me["guns"]
	if guns.size() < 2:
		return
	var k: int = (guns.find(me["weapon"]) + 1) % guns.size()
	me["weapon"] = guns[k]
	me["ammo"] = int(st["weapons"][str(guns[k])]["mag"])
	me["reload"] = 0.0
	me["cd"] = 0.3
	_sfx("ui_swoosh", -6.0)


# ------------------------------------------------------------------ bucle

func can_act() -> bool:
	return not finished and is_inside_tree() and not get_tree().paused


func bot_step() -> void:
	_bot = true


func _sfx(n: String, vol: float = -10.0, pitch: float = 1.0) -> void:
	if not fast:
		Audio.play(n, 0.08, vol, pitch)


func _physics_process(delta: float) -> void:
	_t += delta
	if finished:
		return
	if fast and auto_retry:
		_bot = true
	## En directo: todos empiezan a la vez (cuenta atras de la sala).
	if not online.is_empty() and Time.get_ticks_msec() < _start_ms:
		_wave_lbl.text = Kit.text("arena_starts", "Empieza en {s} s").format({"s": ceili(float(_start_ms - Time.get_ticks_msec()) / 1000.0)})
		_sync(delta)
		return
	var steps: int = 4 if fast and online.is_empty() else 1
	for k: int in steps:
		if finished or get_tree().paused:
			break
		var inp: Dictionary = {}
		if _bot and bool(st["me"]["dead"]):
			inp = {}
		elif _bot:
			inp = M.bot_control(st, delta)
		else:
			var mv: Vector2 = _move_v
			var keys: Vector2 = Input.get_vector("move_left", "move_right", "move_down", "move_up")
			if keys.length() > 0.1:
				mv = keys
			_assist(delta)
			inp = {"move": mv, "fire": _firing or Input.is_action_pressed("jump"), "reload": _want_reload}
			_want_reload = false
		var before: Vector2 = st["me"]["p"]
		M.step(st, inp, delta)
		time_in_level += delta
		_bob += (st["me"]["p"] as Vector2).distance_to(before) * 4.0
		if net != null:
			_net_tick(delta)
		_events()
		if bool(st["over"]):
			_end()
			break
	_sync(delta)


## Ayuda de punteria (como en los shooters de movil): si un zombi esta casi en la mira, la mira se
## va hacia el poco a poco.
func _assist(delta: float) -> void:
	var p: Vector2 = st["me"]["p"]
	var yaw: float = float(st["yaw"])
	var best: float = 0.14
	var pull: float = 0.0
	for z: Dictionary in st["zombies"]:
		if float(z["hp"]) <= 0.0:
			continue
		var to: Vector2 = (z["p"] as Vector2) - p
		if to.length() > 14.0:
			continue
		var err: float = wrapf(atan2(-to.x, -to.y) - yaw, -PI, PI)
		if absf(err) < best and M.sees(st, p, z["p"]):
			best = absf(err)
			pull = err
	st["yaw"] = yaw + clampf(pull, -1.2 * delta, 1.2 * delta)


func _events() -> void:
	for e: Dictionary in st["events"]:
		match str(e["kind"]):
			"shot":
				_kick = 1.0
				var hits: Array = e["hits"]
				var heavy: bool = int(st["weapons"].get(str(e["weapon"]), {}).get("pellets", 1)) > 1
				_sfx("shoot", -4.0 if heavy else -8.0, 0.7 if heavy else 1.0)
				if net != null and not host:
					var dm: Array = e.get("dmgs", [])
					for h: int in hits.size():
						net.send("hit", {"id": int(hits[h]), "d": float(dm[h]) if h < dm.size() else 20.0})
				if not hits.is_empty():
					_hit_t = 0.12
					for z: Dictionary in st["zombies"]:
						if hits.has(int(z["id"])):
							_bleed(to3(z["p"], 1.3))
							break
			"kill":
				coins = int(st["kills"])
				_sfx("stomp", -6.0, 0.7)
			"hurt":
				_hurt.color.a = 0.45
				_sfx("hurt", -6.0)
				Juice.vibrate(40)
			"wave":
				_sfx("ui_big", -4.0)
				_say(Kit.text("zb_wave", "Oleada %d") % int(e["n"]), Color("#ff8a65"))
			"weapon":
				_sfx("powerup", -4.0)
				_say(Kit.text("zb_got", "\u00a1Nueva arma: %s!") % _wname(str(e["item"])), Color("#ffd54f"))
			"heal":
				_sfx("coin", -4.0)
			"reload":
				_sfx("ui_tick", -10.0, 0.6)
			"dead":
				deaths += 1
			"bite":
				if net != null:
					net.send("bite", {"n": int(e["nid"]), "d": float(e["dmg"])})
			"down":
				deaths += 1
				_sfx("hurt", 0.0, 0.7)
				_say(Kit.text("zb_down", "Has ca\u00eddo: vuelves en la siguiente oleada"), Color("#ff6b6b"))
			"respawn":
				_sfx("powerup", -4.0)
				_say(Kit.text("zb_back", "\u00a1De vuelta!"), Color("#5ad17a"))
			"win", "team_lost":
				if net != null and host:
					net.send("end", {"won": str(e["kind"]) == "win"})
			"new_host":
				host = true
	(st["events"] as Array).clear()


func _wname(item: String) -> String:
	## Las armas inventadas por el juego traen su nombre.
	var nm: String = str((st.get("weapons", {}) as Dictionary).get(item, {}).get("name", ""))
	if nm != "":
		return nm
	match item:
		"escopeta":
			return Kit.text("zb_shotgun", "Escopeta")
		"fusil":
			return Kit.text("zb_rifle", "Fusil")
	return Kit.text("zb_pistol", "Pistola")


func _bleed(at: Vector3) -> void:
	if fast:
		return
	_blood.position = at
	_blood.restart()
	_blood.emitting = true


func _sync(delta: float) -> void:
	var me: Dictionary = st["me"]
	var p: Vector2 = me["p"]
	var bob: float = sin(_bob) * 0.04
	_cam.position = to3(p, EYE + bob)
	_cam.rotation = Vector3(float(st["pitch"]), float(st["yaw"]), 0.0)
	## Arma: la que llevas, con retroceso y fogonazo.
	_kick = maxf(0.0, _kick - delta * 7.0)
	_hit_t = maxf(0.0, _hit_t - delta)
	for kind: String in _gun_models.keys():
		(_gun_models[kind] as Node3D).visible = kind == str(me["weapon"])
	var rl: float = float(me["reload"])
	_gun.position = Vector3(0.12, -0.17 + cos(_bob * 0.5) * 0.008 - (0.12 if rl > 0.0 else 0.0), -0.36 + _kick * 0.04)
	_gun.rotation.x = _kick * 0.22 - (0.6 if rl > 0.0 else 0.0)
	_flash_light.light_energy = 3.0 if _kick > 0.75 else 0.0
	_flash_mesh.visible = _kick > 0.75
	_hurt.color.a = maxf(0.0, _hurt.color.a - delta * 1.2)
	## Zombis.
	var seen: Dictionary = {}
	for z: Dictionary in st["zombies"]:
		var id: int = int(z["id"])
		seen[id] = true
		if not _zomb.has(id):
			_zomb[id] = _zombie_node(z)
		var n: Node3D = _zomb[id]
		var body: Node3D = n.get_node("Body")
		var dead: bool = float(z["hp"]) <= 0.0
		n.position = to3(z["p"])
		var zd: Vector2 = z["dir"]
		if not dead:
			n.rotation.y = lerp_angle(n.rotation.y, atan2(-zd.x, -zd.y), minf(1.0, delta * 8.0))
			var spd: float = 9.0 if str(z["kind"]) == "runner" else 5.0
			var sw: float = sin(_t * spd + float(id))
			(body.get_node("LegL") as Node3D).rotation.x = sw * 0.5
			(body.get_node("LegR") as Node3D).rotation.x = -sw * 0.5
			(body.get_node("ArmL") as Node3D).rotation.x = 0.1 + sw * 0.15
			(body.get_node("ArmR") as Node3D).rotation.x = 0.1 - sw * 0.15
			body.rotation.z = sin(_t * 2.0 + float(id)) * 0.08
			body.position.y = absf(sw) * 0.04
			body.rotation.x = -0.25 if float(z["hit_t"]) > 0.0 else 0.0
		else:
			var dt2: float = float(z["dead_t"])
			body.rotation.x = minf(1.5, dt2 * 5.0)
			body.position.y = -maxf(0.0, dt2 - 1.2) * 0.6
			n.visible = dt2 < 2.4
	for id2: Variant in _zomb.keys():
		if not seen.has(id2):
			(_zomb[id2] as Node3D).queue_free()
			_zomb.erase(id2)
	## Cosas del suelo.
	var pks: Array = st["pickups"]
	for k: int in pks.size():
		var node: Node3D = _picks[k]
		node.visible = not bool(pks[k]["got"])
		node.rotation.y = _t * 1.5
		node.position.y = 0.9 + sin(_t * 2.0 + float(k)) * 0.08
	var hls: Array = st["heals"]
	for k2: int in hls.size():
		(_heals[k2] as Node3D).visible = bool(hls[k2]["on"])
		(_heals[k2] as Node3D).rotation.y = _t
	## Interfaz.
	var wv: int = maxi(1, int(st["wave"]))
	_wave_lbl.text = Kit.text("zb_waves", "Oleada %d/%d  \u00b7  Zombis %d") % [wv, int(st["waves"]), M.alive_count(st)]
	var w: Dictionary = st["weapons"][str(me["weapon"])]
	_ammo_lbl.text = Kit.text("zb_reloading", "Recargando...") if rl > 0.0 else ("%s  %d/%d" % [_wname(str(me["weapon"])), int(me["ammo"]), int(w["mag"])])
	_swap_btn.visible = (me["guns"] as Array).size() > 1 and not _bot
	_fire_btn.visible = not _bot
	_reload_btn.visible = not _bot
	_hp_bar.queue_redraw()
	_hud.queue_redraw()
	Audio.set_intensity(clampf(float(M.alive_count(st)) / 10.0, 0.3, 1.0))
	if not online.is_empty():
		_sync_mates()


# ------------------------------------------------------------------ toques

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()
		return
	if not can_act():
		return
	var size: Vector2 = get_viewport().get_visible_rect().size
	if event is InputEventScreenTouch:
		var te: InputEventScreenTouch = event
		if te.pressed:
			_bot = false
			if te.position.x < size.x * 0.45 and _move_id < 0:
				_move_id = te.index
				_move_o = te.position
				_move_v = Vector2.ZERO
			elif _look_id < 0:
				_look_id = te.index
				_look_last = te.position
		else:
			if te.index == _move_id:
				_move_id = -1
				_move_v = Vector2.ZERO
			elif te.index == _look_id:
				_look_id = -1
	elif event is InputEventScreenDrag:
		var dr: InputEventScreenDrag = event
		if dr.index == _move_id:
			_move_v = ((dr.position - _move_o) / 100.0).limit_length(1.0)
			_move_v.y = -_move_v.y
		elif dr.index == _look_id:
			_look(dr.position - _look_last)
			_look_last = dr.position
	elif event is InputEventMouseMotion and (event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_RIGHT:
		_look((event as InputEventMouseMotion).relative)


func _look(d: Vector2) -> void:
	st["yaw"] = wrapf(float(st["yaw"]) - d.x * 0.005, -PI, PI)
	st["pitch"] = clampf(float(st["pitch"]) - d.y * 0.004, -0.5, 0.5)


# ------------------------------------------------------------------ en directo

## La arena de la sala (misma semilla para todos); el anfitrion es el de sesion mas baja.
func _net_state_setup() -> void:
	var lv: Dictionary = level.duplicate(true)
	var rows: Array = []
	for r: Variant in level.get("map", []):
		if not (str(r).begins_with("#") and str(r).substr(1).is_valid_int()):
			rows.append(r)
	rows.append("#%d" % int(online.get("semilla", 1)))
	lv["map"] = rows
	## Mas zombis cuantos mas sois.
	var players: Array = []
	for j: Variant in online.get("jugadores", []):
		if j is Dictionary:
			players.append(j)
	players.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return int(x.get("slot", 0)) < int(y.get("slot", 0)))
	lv["count"] = int(level.get("count", 6)) + 2 * maxi(0, players.size() - 1)
	st = M.new_state(lv)
	var my_id: String = str(online.get("yo", ""))
	var aliases: Array = []
	var ids: Array[String] = []
	var me: int = 0
	for k: int in players.size():
		aliases.append(str(players[k].get("alias", "")))
		ids.append(str(players[k].get("sesion", "")))
		if str(players[k].get("sesion", "")) == my_id:
			me = k
	var sorted_ids: Array[String] = ids.duplicate()
	sorted_ids.sort()
	host = not sorted_ids.is_empty() and sorted_ids[0] == my_id
	M.setup_online(st, aliases, me, host)
	_start_ms = int(online.get("start_ms", Time.get_ticks_msec()))
	_total = 0
	for w: int in int(st["waves"]):
		_total += int(st["count"]) + int(st["grow"]) * w
	coins_total = _total


func _net_open() -> void:
	net = Online.arena_channel(str(online.get("sala", "")))
	add_child(net)
	net.received.connect(_on_net)
	QA.log_event("zombie_live_start", {"sala": str(online.get("sala", "")), "host": host, "players": (online.get("jugadores", []) as Array).size()})


## 8 veces por segundo: como vas tu (todos) y los zombis (el anfitrion). Y quien se ha ido.
func _net_tick(delta: float) -> void:
	M.move_mates(st, delta)
	_send_acc += delta
	if _send_acc >= NET_RATE:
		_send_acc = 0.0
		net.send("st", {"v": M.net_pack_me(st)})
		if host:
			net.send("zs", M.net_snapshot(st))
	var gone: Array = M.net_timeouts(st, NET_TIMEOUT)
	if not host and str(st["role"]) == "client" and float(st["t"]) - float(st.get("host_t", 0.0)) > NET_TIMEOUT and float(st["t"]) > NET_TIMEOUT:
		## El anfitrion no contesta: lo es el siguiente que queda (por orden de sala).
		var me_n: int = int(st["my_nid"])
		var first: int = me_n
		for m: Variant in (st["mates"] as Dictionary).values():
			var md: Dictionary = m
			if not bool(md["gone"]) and int(md["nid"]) < first:
				first = int(md["nid"])
		if first == me_n:
			M.make_host(st)
			host = true
	if not gone.is_empty():
		QA.log_event("zombie_live_gone", {"nids": gone})


func _on_net(event: String, d: Dictionary) -> void:
	if st.is_empty():
		return
	match event:
		"st":
			var v: Variant = d.get("v", [])
			if v is Array:
				M.net_apply_mate(st, v)
		"zs":
			if not host:
				M.net_apply_snap(st, d)
		"hit":
			if host:
				M.net_hit(st, int(d.get("id", -1)), float(d.get("d", 0.0)))
		"bite":
			if int(d.get("n", -1)) == int(st["my_nid"]):
				M.hurt_me(st, clampf(float(d.get("d", 0.0)), 0.0, 40.0))
		"end":
			M.net_end(st, bool(d.get("won", false)))


## Fin en directo: el resultado al servidor (sin trofeos) y la ventana del cooperativo.
func _net_end() -> void:
	if reported:
		return
	reported = true
	finished = true
	var won: bool = bool(st["won"])
	failed = not won
	coins = int(st["kills"])
	Audio.play("win" if won else "hurt")
	if won:
		Audio.play_track("victoria", false)
	QA.log_event("zombie_live_end", {"won": won, "wave": int(st["wave"]), "kills": coins})
	var sala: String = str(online.get("sala", ""))
	Online.arena_match = {}
	var r: Dictionary = await Online.arena_result(sala, 1 if won else 2)
	if not is_inside_tree():
		return
	ArenaPanel.open_result(self, 1 if won else 2, coins, r, true, int(st["wave"]))


## Companeros: soldado hecho con cajas, con su nombre encima.
func _build_mates() -> void:
	for m: Variant in (st["mates"] as Dictionary).values():
		var md: Dictionary = m
		var n: Node3D = Node3D.new()
		n.name = "Mate%d" % int(md["nid"])
		add_child(n)
		var body: Node3D = Node3D.new()
		body.name = "Body"
		n.add_child(body)
		var col: Color = [Color("#3fa7ff"), Color("#43a047"), Color("#fdd835"), Color("#ab47bc")][int(md["nid"]) % 4]
		_box(Vector3(0.2, 0.8, 0.2), Color("#37474f"), Vector3(-0.12, 0.4, 0), body)
		_box(Vector3(0.2, 0.8, 0.2), Color("#37474f"), Vector3(0.12, 0.4, 0), body)
		_box(Vector3(0.52, 0.65, 0.3), col, Vector3(0, 1.12, 0), body)
		_box(Vector3(0.3, 0.3, 0.3), Color("#e0ac80"), Vector3(0, 1.62, 0), body)
		_box(Vector3(0.34, 0.12, 0.34), col.darkened(0.3), Vector3(0, 1.8, 0), body)
		var gun: Node3D = _gun_model("fusil")
		gun.position = Vector3(0.22, 1.2, -0.3)
		body.add_child(gun)
		var tag: Label3D = Label3D.new()
		tag.text = str(md["alias"])
		tag.font_size = 48
		tag.pixel_size = 0.008
		tag.outline_size = 10
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.no_depth_test = true
		tag.modulate = col.lightened(0.3)
		tag.position = Vector3(0, 2.2, 0)
		n.add_child(tag)
		_mate_nodes[int(md["nid"])] = n
	_team_lbl = Label.new()
	_team_lbl.name = "Team"
	_team_lbl.add_theme_font_size_override("font_size", 24)
	_team_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_team_lbl.add_theme_constant_override("outline_size", 6)
	_team_lbl.position = Vector2(20, 90)
	_team_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_team_lbl)
	_down = ColorRect.new()
	_down.color = Color(0.15, 0.0, 0.0, 0.45)
	_down.set_anchors_preset(Control.PRESET_FULL_RECT)
	_down.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_down.visible = false
	_hud.add_child(_down)


func _sync_mates() -> void:
	var lines: Array[String] = []
	for m: Variant in (st["mates"] as Dictionary).values():
		var md: Dictionary = m
		var n: Node3D = _mate_nodes.get(int(md["nid"]))
		if n == null:
			continue
		n.visible = not bool(md["gone"])
		n.position = to3(md["p"])
		n.rotation.y = float(md["yaw"])
		var body: Node3D = n.get_node("Body")
		body.rotation.x = 0.0 if bool(md["alive"]) else -1.5
		body.position.y = 0.0 if bool(md["alive"]) else 0.25
		if not bool(md["gone"]):
			lines.append("%s  %s" % [str(md["alias"]), ("\u2665 %d" % int(md["hp"])) if bool(md["alive"]) else Kit.text("zb_mate_down", "ca\u00eddo")])
	if _team_lbl != null:
		_team_lbl.text = "\n".join(lines)
	if _down != null:
		_down.visible = bool(st["me"]["dead"])


# ------------------------------------------------------------------ final

func _end() -> void:
	if not online.is_empty():
		_net_end()
		return
	if bool(st["won"]):
		_finish()
	else:
		_lose()


func _finish() -> void:
	if finished:
		return
	finished = true
	coins = int(st["kills"])
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var me: Dictionary = st["me"]
	var score: int = maxi(1, int(st["kills"]) * 100 + int(float(me["hp"]) * 20.0) - int(time_in_level) * 5)
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "time": snappedf(time_in_level, 0.1), "hp": int(me["hp"]), "kills": int(st["kills"])})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


func stars_earned() -> int:
	var me: Dictionary = st["me"]
	var f: float = float(me["hp"]) / float(me["max_hp"])
	if f < 0.25:
		return 1
	return 3 if f >= 0.5 and (par <= 0.0 or time_in_level <= par) else 2


func _lose() -> void:
	if finished:
		return
	finished = true
	failed = true
	QA.log_event("death", {"cause": "zombie", "wave": int(st["wave"]), "kills": int(st["kills"])})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("zb_lost", "\u00a1Te han comido!"),
		Kit.text("zb_fail_hint", "Retrocede mientras disparas y no te dejes acorralar. Coge las armas del suelo y los botiquines entre oleadas."))
	p.closed.connect(retry)


func retry() -> void:
	_reset()
	_sync(1.0)


func open_pause() -> void:
	## En directo no se para (los demas siguen jugando).
	if finished or not online.is_empty() or get_tree().paused or get_node_or_null("PauseMenu") != null:
		return
	PauseMenu.open(self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_inside_tree() and not UI.test_mode:
			open_pause()


func bot_state() -> Dictionary:
	var me: Dictionary = st.get("me", {})
	return {"online": not online.is_empty(), "host": host, "reported": reported, "pos": me.get("p", Vector2.ZERO), "deaths": deaths, "coins": coins, "finished": finished, "failed": failed,
		"time": time_in_level, "wave": int(st.get("wave", 0)), "hp": float(me.get("hp", 0.0)), "kills": int(st.get("kills", 0))}
