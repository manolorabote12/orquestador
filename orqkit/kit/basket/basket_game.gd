extends Node3D
## Baloncesto 3D callejero: media pista al aire libre con valla y ciudad alrededor. Mando a la
## izquierda para mover a tu jugador (el que lleva el balon o el mas cercano), TIRO se mantiene y
## se suelta en la zona verde de la barra; PASE. En defensa los botones son SALTAR (tapon) y
## ROBAR. Gana el partido para pasar. Reglas, IA, bot y analizador en basket_map.gd.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const M = preload("res://kit/basket/basket_map.gd")
const BALL_R: float = 0.17
const RIM_H: float = 3.05

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
var _men: Array = []
var _ball: Node3D
var _ball_mesh: MeshInstance3D
var _ball_shadow: MeshInstance3D
var _ring: MeshInstance3D
var _net: MeshInstance3D
var _net_t: float = 0.0
var _hud: Control
var _score_lbl: Label
var _clock_lbl: Label
var _big: Label
var _hint: Label
var _shoot_btn: Button
var _pass_btn: Button
var _bot: bool = false
var _t: float = 0.0
var _move_id: int = -1
var _move_o: Vector2 = Vector2.ZERO
var _move_v: Vector2 = Vector2.ZERO
var _shoot_held: bool = false
var _want_pass: bool = false
var _col_us: Color
var _col_them: Color


func _ready() -> void:
	level = Kit.current_level()
	par = float(level.get("par", 120))
	_col_us = Kit.color("player", Color("#3fa7ff"))
	_col_them = Color("#e53935") if _col_us.h > 0.4 or _col_us.h < 0.05 and _col_us.s < 0.3 else Color("#1e88e5")
	if absf(_col_us.h - _col_them.h) < 0.12:
		_col_them = Color("#fdd835")
	_reset()
	_build_env()
	_build_court()
	_build_people()
	_build_hud()
	_sync(1.0)
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "basket", "skill": float(st["skill"])})


func bot_script() -> String:
	return "res://qa/basket_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(5.0, 2.0)


func wants_backdrop() -> bool:
	return false


func _reset() -> void:
	finished = false
	failed = false
	## Cada revancha es un partido distinto.
	var lv: Dictionary = level.duplicate()
	lv["seed"] = int(level.get("seed", 1)) + deaths * 131
	if deaths > 0:
		lv["map"] = []
	st = M.new_state(lv)
	if _bot:
		M.boost(st)
	time_in_level = 0.0
	coins = 0


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


func _box(size: Vector3, col: Color, at: Vector3, parent: Node3D = null, unshaded: bool = false) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var b: BoxMesh = BoxMesh.new()
	b.size = size
	b.material = mat(col, 0.0, unshaded)
	mi.mesh = b
	mi.position = at
	(parent if parent != null else self).add_child(mi)
	return mi


static func to3(p: Vector2, y: float = 0.0) -> Vector3:
	return Vector3(p.x, y, p.y)


# ------------------------------------------------------------------ pista

func _build_env() -> void:
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sm: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("#3b78c4")
	sm.sky_horizon_color = Color("#bfe0f7")
	sm.ground_horizon_color = Color("#bfe0f7")
	sm.ground_bottom_color = Color("#4a4a4a")
	var sky: Sky = Sky.new()
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.26
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 30.0, 0.0)
	sun.light_energy = 0.48
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 50.0
	add_child(sun)
	_cam = Camera3D.new()
	_cam.keep_aspect = Camera3D.KEEP_WIDTH
	_cam.fov = 70.0
	_cam.far = 300.0
	add_child(_cam)
	_cam.make_current()


## La pista pintada en una imagen: zona, linea de tiros libres, triple y medio campo.
func _court_texture() -> ImageTexture:
	var ppm: int = 28
	var iw: int = int(M.W) * ppm
	var ih: int = int(M.L) * ppm
	var img: Image = Image.create(iw, ih, false, Image.FORMAT_RGB8)
	var base: Color = Color("#2f6db5")
	var key: Color = Color("#d9632b")
	var line: Color = Color("#f5f5f5")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 11
	var hoop: Vector2 = M.HOOP * float(ppm)
	for y: int in ih:
		for x: int in iw:
			var p: Vector2 = Vector2(x, y) / float(ppm)
			var c: Color = base
			if absf(p.x - M.W * 0.5) < 2.45 and p.y < 5.8:
				c = key
			if p.distance_to(Vector2(M.W * 0.5, 5.8)) < 1.8 and p.y > 5.8:
				c = key
			c = c * rng.randf_range(0.94, 1.0)
			img.set_pixel(x, y, Color(c.r, c.g, c.b))
	var lw: float = 0.07
	for y2: int in ih:
		for x2: int in iw:
			var q: Vector2 = Vector2(x2, y2) / float(ppm)
			var on: bool = false
			## Bordes y medio campo.
			if q.x < lw or q.x > M.W - lw or q.y < lw or q.y > M.L - lw:
				on = true
			## Zona.
			if (absf(absf(q.x - M.W * 0.5) - 2.45) < lw * 0.5 and q.y < 5.8) or (absf(q.y - 5.8) < lw * 0.5 and absf(q.x - M.W * 0.5) < 2.45):
				on = true
			if absf(q.distance_to(Vector2(M.W * 0.5, 5.8)) - 1.8) < lw * 0.5 and q.y > 5.8:
				on = true
			## Triple: arco y rectas en las esquinas.
			var dh: float = q.distance_to(M.HOOP)
			if absf(dh - M.ARC) < lw * 0.5 and q.y > M.HOOP.y:
				on = true
			if q.y <= M.HOOP.y and absf(absf(q.x - M.W * 0.5) - M.ARC) < lw * 0.5:
				on = true
			## Circulo de medio campo.
			if absf(q.distance_to(Vector2(M.W * 0.5, M.L)) - 1.8) < lw * 0.5:
				on = true
			if on:
				img.set_pixel(x2, y2, line)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _build_court() -> void:
	var court: MeshInstance3D = MeshInstance3D.new()
	court.name = "Court"
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(M.W, M.L)
	var cm: StandardMaterial3D = StandardMaterial3D.new()
	cm.albedo_texture = _court_texture()
	cm.roughness = 0.7
	cm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	pm.material = cm
	court.mesh = pm
	court.position = Vector3(M.W * 0.5, 0.0, M.L * 0.5)
	add_child(court)
	## Suelo de cemento alrededor y la otra media pista (mas oscura, fuera de juego).
	var ground: MeshInstance3D = MeshInstance3D.new()
	var gp: PlaneMesh = PlaneMesh.new()
	gp.size = Vector2(80, 80)
	gp.material = mat(Color("#7d7a73"))
	ground.mesh = gp
	ground.position = Vector3(M.W * 0.5, -0.01, M.L * 0.5)
	add_child(ground)
	_box(Vector3(M.W, 0.005, M.L), Color("#2a5b96"), Vector3(M.W * 0.5, 0.0, M.L * 1.5))
	## Canasta: poste, brazo, tablero, aro y red.
	var hx: float = M.HOOP.x
	_box(Vector3(0.22, 3.6, 0.22), Color("#37474f"), Vector3(hx, 1.8, -0.9))
	_box(Vector3(0.14, 0.14, 1.9), Color("#37474f"), Vector3(hx, 3.45, 0.05))
	_box(Vector3(0.42, 0.42, 0.06), Color("#455a64"), Vector3(hx, 3.45, 1.0))
	_box(Vector3(1.8, 1.05, 0.05), Color(1, 1, 1, 0.85), Vector3(hx, 3.45, 1.15))
	for e: Array in [[Vector3(1.8, 0.05, 0.06), Vector3(0, 0.5, 0)], [Vector3(1.8, 0.05, 0.06), Vector3(0, -0.5, 0)], [Vector3(0.05, 1.05, 0.06), Vector3(0.88, 0, 0)], [Vector3(0.05, 1.05, 0.06), Vector3(-0.88, 0, 0)],
			[Vector3(0.59, 0.04, 0.07), Vector3(0, 0.0, 0)], [Vector3(0.59, 0.04, 0.07), Vector3(0, -0.42, 0)], [Vector3(0.04, 0.45, 0.07), Vector3(0.28, -0.2, 0)], [Vector3(0.04, 0.45, 0.07), Vector3(-0.28, -0.2, 0)]]:
		_box(e[0], Color("#e64a19") if (e[0] as Vector3).x < 1.0 and (e[0] as Vector3).y < 1.0 else Color("#263238"), Vector3(hx, 3.45, 1.18) + (e[1] as Vector3))
	var rim: MeshInstance3D = MeshInstance3D.new()
	rim.name = "Rim"
	var tm: TorusMesh = TorusMesh.new()
	tm.inner_radius = 0.22
	tm.outer_radius = 0.25
	tm.material = mat(Color("#ff5722"), 0.3)
	rim.mesh = tm
	rim.position = to3(M.HOOP, RIM_H)
	add_child(rim)
	_net = MeshInstance3D.new()
	var nc: CylinderMesh = CylinderMesh.new()
	nc.top_radius = 0.23
	nc.bottom_radius = 0.14
	nc.height = 0.42
	nc.cap_top = false
	nc.cap_bottom = false
	var nm: StandardMaterial3D = mat(Color(1, 1, 1, 0.55))
	nm.cull_mode = BaseMaterial3D.CULL_DISABLED
	nc.material = nm
	_net.mesh = nc
	_net.position = to3(M.HOOP, RIM_H - 0.22)
	add_child(_net)
	## Valla de alambre en los tres lados (y bancos), farolas y ciudad.
	var fence_m: StandardMaterial3D = mat(Color(0.75, 0.78, 0.8, 0.28))
	fence_m.cull_mode = BaseMaterial3D.CULL_DISABLED
	for f: Array in [[Vector3(M.W + 4.0, 3.2, 0.03), Vector3(M.W * 0.5, 1.6, -2.0)], [Vector3(0.03, 3.2, M.L * 2.0 + 2.0), Vector3(-2.0, 1.6, M.L - 1.0)], [Vector3(0.03, 3.2, M.L * 2.0 + 2.0), Vector3(M.W + 2.0, 1.6, M.L - 1.0)]]:
		var mi: MeshInstance3D = MeshInstance3D.new()
		var bm: BoxMesh = BoxMesh.new()
		bm.size = f[0]
		bm.material = fence_m
		mi.mesh = bm
		mi.position = f[1]
		add_child(mi)
		## Postes.
		var sz: Vector3 = f[0]
		var long: float = maxf(sz.x, sz.z)
		var steps: int = int(long / 3.0)
		for k: int in steps + 1:
			var t: float = -long * 0.5 + float(k) * long / float(steps)
			var at: Vector3 = (f[1] as Vector3) + (Vector3(t, 0, 0) if sz.x > sz.z else Vector3(0, 0, t))
			_box(Vector3(0.08, 3.3, 0.08), Color("#90a4ae"), Vector3(at.x, 1.65, at.z))
	for side: float in [-1.4, M.W + 1.4]:
		_box(Vector3(0.5, 0.45, 3.0), Color("#8d6e63"), Vector3(side, 0.22, M.L * 0.6))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	for k2: int in 26:
		var a: float = PI + PI * float(k2) / 25.0
		var rad: float = rng.randf_range(24.0, 34.0)
		var at2: Vector3 = Vector3(M.W * 0.5 + cos(a) * rad * 1.2, 0, M.L * 0.6 + sin(a) * rad)
		var hh: float = rng.randf_range(8.0, 22.0)
		var col: Color = [Color("#b0715a"), Color("#c9b79c"), Color("#8f9aa8"), Color("#d8c3a5")][k2 % 4]
		_box(Vector3(rng.randf_range(6.0, 10.0), hh, rng.randf_range(6.0, 10.0)), col, at2 + Vector3(0, hh * 0.5, 0))
		## Ventanas.
		for wy: int in int(hh / 3.0):
			_box(Vector3(5.0, 0.8, 0.1), Color("#5c7a99"), at2 + Vector3(0, 2.0 + float(wy) * 3.0, 4.0 if at2.z < 0 else -4.0))
	## Arboles.
	for tp: Vector3 in [Vector3(-5, 0, 2), Vector3(-6, 0, 9), Vector3(M.W + 5, 0, 3), Vector3(M.W + 6, 0, 10), Vector3(-4, 0, -5), Vector3(M.W + 4, 0, -6)]:
		_box(Vector3(0.35, 2.4, 0.35), Color("#6d4c41"), tp + Vector3(0, 1.2, 0))
		var crown: MeshInstance3D = MeshInstance3D.new()
		var sp: SphereMesh = SphereMesh.new()
		sp.radius = 1.6
		sp.height = 2.8
		sp.material = mat(Color("#4c8a3f"))
		crown.mesh = sp
		crown.position = tp + Vector3(0, 3.4, 0)
		add_child(crown)


func _build_people() -> void:
	for pl: Dictionary in st["players"]:
		var tm: int = int(pl["team"])
		var col: Color = _col_us if tm == 0 else _col_them
		var root: Node3D = Node3D.new()
		root.name = "Player%d" % int(pl["i"])
		add_child(root)
		var body: Node3D = Node3D.new()
		body.name = "Body"
		root.add_child(body)
		var skin: Color = [Color("#f2c49b"), Color("#a86b4a"), Color("#6b4430"), Color("#e0ac80")][int(pl["i"]) % 4]
		var torso: MeshInstance3D = MeshInstance3D.new()
		var cap: CapsuleMesh = CapsuleMesh.new()
		cap.radius = 0.27
		cap.height = 0.95
		cap.material = mat(col)
		torso.mesh = cap
		torso.position = Vector3(0, 1.25, 0)
		body.add_child(torso)
		_box(Vector3(0.5, 0.32, 0.3), col.darkened(0.25), Vector3(0, 0.86, 0), body)
		var head: MeshInstance3D = MeshInstance3D.new()
		var sp: SphereMesh = SphereMesh.new()
		sp.radius = 0.2
		sp.height = 0.42
		sp.material = mat(skin)
		head.mesh = sp
		head.position = Vector3(0, 1.95, 0)
		body.add_child(head)
		var legs: Array = []
		for sx: float in [-0.12, 0.12]:
			var leg: Node3D = Node3D.new()
			leg.position = Vector3(sx, 0.72, 0)
			_box(Vector3(0.14, 0.66, 0.16), skin, Vector3(0, -0.36, 0), leg)
			_box(Vector3(0.17, 0.12, 0.28), Color("#fafafa"), Vector3(0, -0.68, -0.05), leg)
			body.add_child(leg)
			legs.append(leg)
		var arms: Array = []
		for ax: float in [-0.34, 0.34]:
			var arm: Node3D = Node3D.new()
			arm.position = Vector3(ax, 1.55, 0)
			_box(Vector3(0.12, 0.62, 0.12), skin, Vector3(0, -0.3, 0), arm)
			body.add_child(arm)
			arms.append(arm)
		var num: Label3D = Label3D.new()
		num.text = str(int(pl["slot"]) + (1 if tm == 0 else 4))
		num.font_size = 64
		num.pixel_size = 0.006
		num.outline_size = 8
		num.position = Vector3(0, 1.3, 0.29)
		body.add_child(num)
		_men.append({"root": root, "body": body, "legs": legs, "arms": arms})
	_ball = Node3D.new()
	_ball.name = "Ball"
	add_child(_ball)
	_ball_mesh = MeshInstance3D.new()
	var bs: SphereMesh = SphereMesh.new()
	bs.radius = BALL_R
	bs.height = BALL_R * 2.0
	bs.material = mat(Color("#e8701a"))
	_ball_mesh.mesh = bs
	_ball.add_child(_ball_mesh)
	for k2: int in 2:
		var seam: MeshInstance3D = MeshInstance3D.new()
		var tor: TorusMesh = TorusMesh.new()
		tor.inner_radius = BALL_R - 0.004
		tor.outer_radius = BALL_R + 0.006
		tor.material = mat(Color("#1b1b1b"))
		seam.mesh = tor
		seam.rotation_degrees = Vector3(90, 0, 0) if k2 == 0 else Vector3(0, 0, 90)
		_ball_mesh.add_child(seam)
	_ball_shadow = MeshInstance3D.new()
	var disc: CylinderMesh = CylinderMesh.new()
	disc.top_radius = 0.16
	disc.bottom_radius = 0.16
	disc.height = 0.01
	disc.material = mat(Color(0, 0, 0, 0.4), 0.0, true)
	_ball_shadow.mesh = disc
	add_child(_ball_shadow)
	_ring = MeshInstance3D.new()
	var rt: TorusMesh = TorusMesh.new()
	rt.inner_radius = 0.42
	rt.outer_radius = 0.55
	rt.material = mat(Color("#ffd23f"), 0.8, true)
	_ring.mesh = rt
	_ring.scale = Vector3(1, 0.1, 1)
	add_child(_ring)


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
	var board: PanelContainer = PanelContainer.new()
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(board)
	var bh: HBoxContainer = HBoxContainer.new()
	bh.alignment = BoxContainer.ALIGNMENT_CENTER
	bh.add_theme_constant_override("separation", 18)
	board.add_child(bh)
	_score_lbl = Label.new()
	_score_lbl.name = "Score"
	_score_lbl.add_theme_font_size_override("font_size", 38)
	bh.add_child(_score_lbl)
	_clock_lbl = Label.new()
	_clock_lbl.name = "Clock"
	_clock_lbl.add_theme_font_size_override("font_size", 28)
	_clock_lbl.modulate = Color(1, 1, 1, 0.85)
	bh.add_child(_clock_lbl)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)
	_big = Label.new()
	_big.name = "Big"
	_big.theme_type_variation = "TitleLabel"
	_big.add_theme_font_size_override("font_size", 88)
	_big.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_big.add_theme_constant_override("outline_size", 14)
	_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_big.set_anchors_preset(Control.PRESET_CENTER)
	_big.position = Vector2(-360, -260)
	_big.size = Vector2(720, 150)
	_big.modulate.a = 0.0
	_big.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_big)
	_hint = Label.new()
	_hint.name = "Hint"
	_hint.add_theme_font_size_override("font_size", 28)
	_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_hint.add_theme_constant_override("outline_size", 8)
	_hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_hint.position = Vector2(-330, 130)
	_hint.size = Vector2(660, 80)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_hint)
	_shoot_btn = _round_button("BtnShoot", Kit.text("bk_shoot", "Tiro"), Vector2(-230, -310), 190.0, Kit.color("accent", Color("#ff7043")))
	_shoot_btn.button_down.connect(func() -> void: _shoot_held = true)
	_shoot_btn.button_up.connect(func() -> void: _shoot_held = false)
	_pass_btn = _round_button("BtnPass", Kit.text("bk_pass", "Pase"), Vector2(-440, -200), 150.0, Color("#4fc3f7"))
	_pass_btn.button_down.connect(func() -> void: _want_pass = true)


func _round_button(nm: String, text: String, off: Vector2, size_px: float, col: Color) -> Button:
	var b: Button = UI.make_button(text, true)
	b.name = nm
	b.custom_minimum_size = Vector2(size_px, size_px * 0.75)
	b.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	b.offset_left = off.x
	b.offset_top = off.y
	b.offset_right = off.x + size_px
	b.offset_bottom = off.y + size_px * 0.75
	b.self_modulate = col.lerp(Color.WHITE, 0.2)
	_hud.add_child(b)
	return b


## Mando y barra de tiro (encima de tu jugador, con la zona verde).
func _draw_hud() -> void:
	if _move_id >= 0:
		_hud.draw_circle(_move_o, 100.0, Color(1, 1, 1, 0.12))
		_hud.draw_arc(_move_o, 100.0, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 3.0)
		_hud.draw_circle(_move_o + _move_v * 100.0, 40.0, Color(1, 1, 1, 0.45))
	elif not _bot:
		var home: Vector2 = Vector2(170.0, _hud.size.y - 280.0)
		_hud.draw_arc(home, 90.0, 0.0, TAU, 40, Color(1, 1, 1, 0.22), 3.0)
		_hud.draw_circle(home, 36.0, Color(1, 1, 1, 0.16))
	var ctrl: int = int(st["ctrl"])
	if ctrl < 0:
		return
	var pl: Dictionary = st["players"][ctrl]
	var c: float = float(pl["charge"])
	if c <= 0.0 or _cam == null:
		return
	var at: Vector2 = _cam.unproject_position(to3(pl["p"], 2.4)) + Vector2(60, -40)
	var hgt: float = 150.0
	var r: Rect2 = Rect2(at.x, at.y - hgt, 26.0, hgt)
	_hud.draw_rect(r.grow(4.0), Color(0, 0, 0, 0.6))
	var zone_y: float = at.y - hgt * (M.PERFECT / 1.3)
	_hud.draw_rect(Rect2(at.x, zone_y - hgt * 0.07 / 1.3, 26.0, hgt * 0.14 / 1.3), Color("#43d17a"))
	var fill: float = clampf(c / 1.3, 0.0, 1.0) * hgt
	_hud.draw_rect(Rect2(at.x + 6.0, at.y - fill, 14.0, fill), Color(1, 1, 1, 0.9))


func _big_text(text: String, col: Color) -> void:
	if fast or _big == null:
		return
	_big.text = text
	_big.add_theme_color_override("font_color", col)
	_big.modulate.a = 1.0
	_big.scale = Vector2.ONE * 0.6
	_big.pivot_offset = _big.size * 0.5
	var tw: Tween = _big.create_tween()
	tw.tween_property(_big, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.8)
	tw.tween_property(_big, "modulate:a", 0.0, 0.35)


func _say(text: String, col: Color) -> void:
	if fast or _hint == null:
		return
	_hint.text = text
	_hint.add_theme_color_override("font_color", col)
	_hint.modulate.a = 1.0
	var tw: Tween = _hint.create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(_hint, "modulate:a", 0.0, 0.5)


# ------------------------------------------------------------------ bucle

func can_act() -> bool:
	return not finished and is_inside_tree() and not get_tree().paused


func bot_step() -> void:
	if not _bot:
		M.boost(st)
	_bot = true


func _sfx(n: String, vol: float = -10.0, pitch: float = 1.0) -> void:
	if not fast:
		Audio.play(n, 0.05, vol, pitch)


func _physics_process(delta: float) -> void:
	_t += delta
	if finished:
		return
	if fast and auto_retry and not _bot:
		M.boost(st)
		_bot = true
	var steps: int = 4 if fast else 1
	for k: int in steps:
		if finished or get_tree().paused:
			break
		var inp: Dictionary = {}
		if not _bot:
			var mv: Vector2 = _move_v
			var keys: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
			if keys.length() > 0.1:
				mv = keys
			inp = {"move": mv, "shoot": _shoot_held or Input.is_action_pressed("shoot"), "pass": _want_pass or Input.is_action_just_pressed("jump")}
			_want_pass = false
		M.step(st, inp, delta)
		time_in_level += delta
		_events()
		if bool(st["over"]):
			_end()
			break
	_sync(delta)


func _ours(i: int) -> bool:
	return i >= 0 and int(st["players"][i]["team"]) == 0


func _events() -> void:
	for e: Dictionary in st["events"]:
		match str(e["kind"]):
			"shot":
				_sfx("jump", -10.0, 1.2)
				if _ours(int(e["i"])) and bool(e["perfect"]):
					_say(Kit.text("bk_perfect", "\u00a1Lanzamiento perfecto!"), Color("#43d17a"))
			"score":
				var ours: bool = int(e["team"]) == 0
				_net_t = 0.6
				if ours:
					coins = int(st["score"][0])
					_big_text(Kit.text("bk_three", "\u00a1TRIPLE!") if int(e["pts"]) == 3 else "+2", Color("#ffd23f"))
					_sfx("coin", -4.0)
					Juice.vibrate(40)
				else:
					_big_text(Kit.text("bk_them", "Canasta rival"), Color("#ff6b6b"))
					_sfx("ui_error", -8.0)
			"rim":
				_sfx("ui_tick", -6.0, 0.6)
			"block":
				_sfx("stomp", -6.0)
				_big_text(Kit.text("bk_block", "\u00a1TAP\u00d3N!"), Color("#5ad17a") if _ours(int(e["i"])) else Color("#ff6b6b"))
				Juice.vibrate(50)
			"steal":
				_sfx("ui_swoosh", -6.0)
				_say(Kit.text("bk_steal", "\u00a1Robo!") if _ours(int(e["i"])) else Kit.text("bk_stolen", "Te la han robado"), Color("#5ad17a") if _ours(int(e["i"])) else Color("#ff6b6b"))
			"rebound":
				_sfx("ui_tap", -12.0)
				if _ours(int(e["i"])) and bool(st["clear"]):
					_say(Kit.text("bk_clear", "Saca el bal\u00f3n fuera del triple"), Color("#ffd23f"))
			"must_clear":
				_say(Kit.text("bk_clear", "Saca el bal\u00f3n fuera del triple"), Color("#ffd23f"))
			"shot_clock":
				_say(Kit.text("bk_clock", "\u00a1Se acab\u00f3 la posesi\u00f3n!"), Color("#ff9e40"))
			"sudden":
				_big_text(Kit.text("bk_sudden", "\u00a1La siguiente gana!"), Color("#ffd23f"))
			"pass", "catch":
				_sfx("ui_tap", -16.0, 1.3)
	(st["events"] as Array).clear()


func _sync(delta: float) -> void:
	var players: Array = st["players"]
	var b: Dictionary = st["ball"]
	var owner: int = int(st["owner"])
	for k: int in players.size():
		var pl: Dictionary = players[k]
		var e: Dictionary = _men[k]
		var root: Node3D = e["root"]
		root.position = to3(pl["p"])
		var face: Vector2 = pl["face"]
		## Defensores y tiradores miran hacia la canasta o hacia su par.
		if float(pl["charge"]) > 0.0 or (str(b["mode"]) == "shot" and int(b["shooter"]) == k):
			face = (M.HOOP - (pl["p"] as Vector2)).normalized()
		root.rotation.y = lerp_angle(root.rotation.y, atan2(-face.x, -face.y), minf(1.0, delta * 14.0))
		var spd: float = (pl["v"] as Vector2).length()
		var swing: float = sin(_t * 15.0 + float(k)) * clampf(spd / 5.0, 0.0, 1.0) * 0.8
		(e["legs"][0] as Node3D).rotation.x = swing
		(e["legs"][1] as Node3D).rotation.x = -swing
		var body: Node3D = e["body"]
		var jump: float = float(pl["jump"])
		body.position.y = sin(clampf(jump / 0.5, 0.0, 1.0) * PI) * 0.55 if jump > 0.0 else 0.0
		var up: bool = jump > 0.0 or float(pl["charge"]) > 0.0
		(e["arms"][0] as Node3D).rotation.x = -2.8 if up else -swing * 0.6
		(e["arms"][1] as Node3D).rotation.x = -2.8 if up else (-0.6 if k == owner else swing * 0.6)
	## Balon: botando en la mano, en el aire o suelto.
	var bp: Vector2 = b["p"]
	var bh: float = float(b["h"])
	if str(b["mode"]) == "held" and owner >= 0:
		var pl2: Dictionary = players[owner]
		var f2: Vector2 = pl2["face"]
		var side: Vector2 = f2.orthogonal() * -0.3
		if float(pl2["charge"]) > 0.0:
			bp = (pl2["p"] as Vector2) + f2 * 0.15
			bh = 2.25 + float(_men[owner]["body"].position.y)
		else:
			bp = (pl2["p"] as Vector2) + f2 * 0.3 + side
			bh = BALL_R + absf(sin(_t * 7.0)) * 0.8
	_ball.position = to3(bp, bh)
	_ball_mesh.rotation.x += delta * 8.0
	_ball_shadow.position = to3(bp, 0.02)
	## Red que se mueve al entrar.
	_net_t = maxf(0.0, _net_t - delta)
	_net.scale = Vector3(1.0 - _net_t * 0.3, 1.0 + _net_t * 0.5, 1.0 - _net_t * 0.3)
	var ctrl: int = int(st["ctrl"])
	_ring.visible = ctrl >= 0 and not _bot
	if ctrl >= 0:
		_ring.position = to3(players[ctrl]["p"], 0.03)
	var s: Array = st["score"]
	_score_lbl.text = "%s %d - %d %s" % [Kit.text("bk_you", "T\u00da"), int(s[0]), int(s[1]), Kit.text("bk_rival", "RIVAL")]
	var left: float = maxf(0.0, float(st["time"]) - float(st["t"]))
	_clock_lbl.text = ("%d:%02d" % [int(left) / 60, int(left) % 60]) + ("   %d s" % ceili(float(st["clock"])))
	var attacking: bool = int(st["poss"]) == 0
	_shoot_btn.text = Kit.text("bk_shoot", "Tiro") if attacking else Kit.text("bk_jump", "Saltar")
	_pass_btn.text = Kit.text("bk_pass", "Pase") if attacking else Kit.text("bk_steal_btn", "Robar")
	_shoot_btn.visible = not _bot
	_pass_btn.visible = not _bot
	_hud.queue_redraw()
	## Camara: desde medio campo mirando a la canasta, siguiendo un poco el balon.
	var cx: float = lerpf(M.W * 0.5, bp.x, 0.35)
	var cz: float = M.L + 0.5 - clampf((M.L - bp.y) * 0.15, 0.0, 1.5)
	var want: Vector3 = Vector3(cx, 9.0, cz)
	_cam.position = _cam.position.lerp(want, minf(1.0, delta * 4.0)) if not fast and delta < 0.5 else want
	_cam.look_at(Vector3(cx, 0.0, 4.4), Vector3.UP)
	Audio.set_intensity(clampf(0.5 + (0.3 if left < 20.0 else 0.0) + (0.2 if bool(st["sudden"]) else 0.0), 0.0, 1.0))


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
		if te.pressed and _move_id < 0 and te.position.x < size.x * 0.55:
			_bot = false
			_move_id = te.index
			_move_o = te.position
			_move_v = Vector2.ZERO
		elif not te.pressed and te.index == _move_id:
			_move_id = -1
			_move_v = Vector2.ZERO
	elif event is InputEventScreenDrag:
		var dr: InputEventScreenDrag = event
		if dr.index == _move_id:
			_move_v = ((dr.position - _move_o) / 100.0).limit_length(1.0)


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
	var s: Array = st["score"]
	coins = int(s[0])
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = maxi(1, 500 * int(s[0]) - 200 * int(s[1]) + 500)
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "time": snappedf(time_in_level, 0.1), "for": int(s[0]), "against": int(s[1])})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


func stars_earned() -> int:
	var s: Array = st.get("score", [0, 0])
	var diff: int = int(s[0]) - int(s[1])
	return 3 if diff >= 6 else (2 if diff >= 3 else 1)


func _lose() -> void:
	if finished:
		return
	finished = true
	failed = true
	deaths += 1
	var s: Array = st["score"]
	QA.log_event("death", {"cause": "match", "for": int(s[0]), "against": int(s[1])})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("bk_lost", "Has perdido %d - %d") % [int(s[0]), int(s[1])],
		Kit.text("bk_fail_hint", "Suelta el tiro en la zona verde y busca al compa\u00f1ero solo. Cerca del aro se falla menos."))
	p.closed.connect(retry)


func retry() -> void:
	_reset()
	_sync(1.0)


func open_pause() -> void:
	if finished or get_tree().paused or get_node_or_null("PauseMenu") != null:
		return
	PauseMenu.open(self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_inside_tree() and not UI.test_mode:
			open_pause()


func bot_state() -> Dictionary:
	var s: Array = st.get("score", [0, 0])
	return {"deaths": deaths, "coins": coins, "finished": finished, "failed": failed, "time": time_in_level, "for": int(s[0]), "against": int(s[1])}
