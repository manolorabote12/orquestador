extends Node3D
## Tenis 3D: pista dura con gradas, red y juez de silla. Mando a la izquierda para moverte (y
## para apuntar: hacia donde empujas va la pelota), GOLPE justo antes de pegarle para un tiro
## perfecto y GLOBO para tirarla alta al fondo. Gana el partido para pasar.
## Reglas, IA, bot y analizador en tennis_map.gd.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const M = preload("res://kit/tennis/tennis_map.gd")
const BALL_R: float = 0.13

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
var _ball: MeshInstance3D
var _ball_shadow: MeshInstance3D
var _spot: MeshInstance3D
var _hud: Control
var _score_lbl: Label
var _big: Label
var _hint: Label
var _hit_btn: Button
var _lob_btn: Button
var _bot: bool = false
var _t: float = 0.0
var _move_id: int = -1
var _move_o: Vector2 = Vector2.ZERO
var _move_v: Vector2 = Vector2.ZERO
var _want_hit: bool = false
var _want_lob: bool = false
var _col_us: Color
var _col_them: Color
var _crowd: MultiMeshInstance3D


func _ready() -> void:
	level = Kit.current_level()
	par = float(level.get("par", 150))
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
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "tennis", "skill": float(st["skill"])})


func bot_script() -> String:
	return "res://qa/tennis_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(4.5, 1.6)


func wants_backdrop() -> bool:
	return false


func _reset() -> void:
	finished = false
	failed = false
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
	sm.sky_top_color = Color("#2f6fbf")
	sm.sky_horizon_color = Color("#cfe6f7")
	sm.ground_horizon_color = Color("#cfe6f7")
	sm.ground_bottom_color = Color("#3d4a3a")
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
	sun.rotation_degrees = Vector3(-58.0, 25.0, 0.0)
	sun.light_energy = 0.48
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)
	_cam = Camera3D.new()
	_cam.keep_aspect = Camera3D.KEEP_WIDTH
	_cam.fov = 62.0
	_cam.far = 300.0
	add_child(_cam)
	_cam.make_current()


## La pista pintada en una imagen: fondo, lineas de individuales y dobles, cuadros de saque.
func _court_texture(w: float, l: float) -> ImageTexture:
	var ppm: int = 16
	var iw: int = int(w * ppm)
	var ih: int = int(l * ppm)
	var img: Image = Image.create(iw, ih, false, Image.FORMAT_RGB8)
	var outer: Color = Color("#3f8f5a")
	var inner: Color = Color("#2f6fb3")
	var line: Color = Color("#f7f7f7")
	var dw: float = M.HW + 1.37
	var lw: float = 0.08
	for y: int in ih:
		for x: int in iw:
			var q: Vector2 = Vector2(float(x) / ppm - w * 0.5, float(y) / ppm - l * 0.5)
			var c: Color = inner if absf(q.x) <= dw and absf(q.y) <= M.HL else outer
			var on: bool = false
			if absf(q.y) <= M.HL + lw:
				if absf(absf(q.x) - M.HW) < lw or absf(absf(q.x) - dw) < lw:
					on = true
			if absf(q.x) <= dw + lw and absf(absf(q.y) - M.HL) < lw:
				on = true
			if absf(q.x) <= M.HW and absf(absf(q.y) - M.SERVICE) < lw:
				on = true
			if absf(q.x) < lw and absf(q.y) <= M.SERVICE:
				on = true
			if absf(q.x) < lw and absf(absf(q.y) - M.HL) < 0.3:
				on = true
			img.set_pixel(x, y, line if on else c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _build_court() -> void:
	var w: float = 18.0
	var l: float = 36.0
	var court: MeshInstance3D = MeshInstance3D.new()
	court.name = "Court"
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(w, l)
	var cm: StandardMaterial3D = StandardMaterial3D.new()
	cm.albedo_texture = _court_texture(w, l)
	cm.roughness = 0.8
	cm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	pm.material = cm
	court.mesh = pm
	add_child(court)
	## Red con sus postes y la cinta blanca.
	var nw: float = (M.HW + 1.37) * 2.0 + 1.0
	var net_m: StandardMaterial3D = mat(Color(0.08, 0.08, 0.1, 0.55))
	net_m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var net: MeshInstance3D = MeshInstance3D.new()
	net.name = "Net"
	var nb: BoxMesh = BoxMesh.new()
	nb.size = Vector3(nw, M.NET_H - 0.1, 0.02)
	nb.material = net_m
	net.mesh = nb
	net.position = Vector3(0, (M.NET_H - 0.1) * 0.5 + 0.02, 0)
	add_child(net)
	_box(Vector3(nw, 0.07, 0.04), Color("#fafafa"), Vector3(0, M.NET_H - 0.05, 0))
	for sx: float in [-nw * 0.5, nw * 0.5]:
		_box(Vector3(0.1, 1.1, 0.1), Color("#2e3b2f"), Vector3(sx, 0.55, 0))
	## Juez de silla.
	_box(Vector3(0.12, 2.0, 0.12), Color("#5d4037"), Vector3(nw * 0.5 + 1.3, 1.0, 0))
	_box(Vector3(0.7, 0.1, 0.7), Color("#33691e"), Vector3(nw * 0.5 + 1.3, 2.05, 0))
	_box(Vector3(0.4, 0.6, 0.3), Color("#263238"), Vector3(nw * 0.5 + 1.3, 2.4, 0))
	## Muro con anuncios al fondo y a los lados, gradas con publico.
	for z: float in [-l * 0.5, l * 0.5]:
		_box(Vector3(w, 1.2, 0.2), Color("#1b5e20"), Vector3(0, 0.6, z))
	for x: float in [-w * 0.5, w * 0.5]:
		_box(Vector3(0.2, 1.2, l), Color("#1b5e20"), Vector3(x, 0.6, 0))
	var seats: Array[Vector3] = []
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	for row: int in 7:
		var hh: float = 1.4 + row * 0.55
		var off: float = 0.6 + row * 0.75
		_box(Vector3(0.75, 0.5, l + off * 2.0), Color("#90a4ae").darkened(row * 0.04), Vector3(-w * 0.5 - off, hh - 0.25, 0))
		_box(Vector3(0.75, 0.5, l + off * 2.0), Color("#90a4ae").darkened(row * 0.04), Vector3(w * 0.5 + off, hh - 0.25, 0))
		_box(Vector3(w + off * 2.0, 0.5, 0.75), Color("#90a4ae").darkened(row * 0.04), Vector3(0, hh - 0.25, -l * 0.5 - off))
		var zz: float = -l * 0.5 + 0.4
		while zz < l * 0.5 - 0.3:
			if rng.randf() < 0.8:
				seats.append(Vector3(-w * 0.5 - off, hh + 0.3, zz))
			if rng.randf() < 0.8:
				seats.append(Vector3(w * 0.5 + off, hh + 0.3, zz))
			zz += 0.6
		var xx: float = -w * 0.5
		while xx < w * 0.5:
			if rng.randf() < 0.8:
				seats.append(Vector3(xx, hh + 0.3, -l * 0.5 - off))
			xx += 0.6
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var cb: BoxMesh = BoxMesh.new()
	cb.size = Vector3(0.4, 0.55, 0.35)
	var crowd_m: StandardMaterial3D = StandardMaterial3D.new()
	crowd_m.vertex_color_use_as_albedo = true
	crowd_m.vertex_color_is_srgb = true
	cb.material = crowd_m
	mm.mesh = cb
	mm.instance_count = seats.size()
	var shirts: Array[Color] = [Color("#e53935"), Color("#fdd835"), Color("#1e88e5"), Color("#fafafa"), Color("#43a047"), Color("#8e24aa"), Color("#ff7043")]
	for k: int in seats.size():
		mm.set_instance_transform(k, Transform3D(Basis.IDENTITY, seats[k]))
		mm.set_instance_color(k, shirts[rng.randi_range(0, shirts.size() - 1)])
	_crowd = MultiMeshInstance3D.new()
	_crowd.multimesh = mm
	add_child(_crowd)
	## Suelo alrededor.
	var ground: MeshInstance3D = MeshInstance3D.new()
	var gp: PlaneMesh = PlaneMesh.new()
	gp.size = Vector2(120, 120)
	gp.material = mat(Color("#556b4f"))
	ground.mesh = gp
	ground.position = Vector3(0, -0.02, 0)
	add_child(ground)


func _build_people() -> void:
	for pl: Dictionary in st["players"]:
		var i: int = int(pl["i"])
		var col: Color = _col_us if i == 0 else _col_them
		var root: Node3D = Node3D.new()
		root.name = "Player%d" % i
		add_child(root)
		var body: Node3D = Node3D.new()
		root.add_child(body)
		var skin: Color = Color("#f2c49b") if i == 0 else Color("#c68a5e")
		var torso: MeshInstance3D = MeshInstance3D.new()
		var cap: CapsuleMesh = CapsuleMesh.new()
		cap.radius = 0.26
		cap.height = 0.9
		cap.material = mat(col)
		torso.mesh = cap
		torso.position = Vector3(0, 1.2, 0)
		body.add_child(torso)
		_box(Vector3(0.48, 0.28, 0.3), Color("#fafafa"), Vector3(0, 0.82, 0), body)
		var head: MeshInstance3D = MeshInstance3D.new()
		var sp: SphereMesh = SphereMesh.new()
		sp.radius = 0.19
		sp.height = 0.4
		sp.material = mat(skin)
		head.mesh = sp
		head.position = Vector3(0, 1.86, 0)
		body.add_child(head)
		_box(Vector3(0.4, 0.06, 0.4), col.lightened(0.2), Vector3(0, 2.0, -0.05), body)
		var legs: Array = []
		for sx: float in [-0.12, 0.12]:
			var leg: Node3D = Node3D.new()
			leg.position = Vector3(sx, 0.7, 0)
			_box(Vector3(0.14, 0.64, 0.16), skin, Vector3(0, -0.34, 0), leg)
			_box(Vector3(0.17, 0.12, 0.28), Color("#fafafa"), Vector3(0, -0.66, -0.05), leg)
			body.add_child(leg)
			legs.append(leg)
		## Brazo con la raqueta (a la derecha).
		var arm: Node3D = Node3D.new()
		arm.name = "Arm"
		arm.position = Vector3(0.33, 1.5, 0)
		body.add_child(arm)
		_box(Vector3(0.11, 0.6, 0.11), skin, Vector3(0, -0.28, 0), arm)
		_box(Vector3(0.05, 0.32, 0.05), Color("#212121"), Vector3(0, -0.72, -0.08), arm)
		var head_r: MeshInstance3D = MeshInstance3D.new()
		var tor: TorusMesh = TorusMesh.new()
		tor.inner_radius = 0.13
		tor.outer_radius = 0.16
		tor.material = mat(Color("#ff7043") if i == 0 else Color("#455a64"))
		head_r.mesh = tor
		head_r.position = Vector3(0, -1.02, -0.12)
		head_r.rotation_degrees = Vector3(0, 0, 90)
		head_r.scale = Vector3(1.0, 1.0, 1.35)
		arm.add_child(head_r)
		_box(Vector3(0.11, 0.55, 0.11), skin, Vector3(-0.33, 1.25, 0), body)
		_men.append({"root": root, "legs": legs, "arm": arm})
	_ball = MeshInstance3D.new()
	_ball.name = "Ball"
	var bs: SphereMesh = SphereMesh.new()
	bs.radius = BALL_R
	bs.height = BALL_R * 2.0
	bs.material = mat(Color("#d7f542"), 0.35)
	_ball.mesh = bs
	add_child(_ball)
	_ball_shadow = MeshInstance3D.new()
	var disc: CylinderMesh = CylinderMesh.new()
	disc.top_radius = 0.12
	disc.bottom_radius = 0.12
	disc.height = 0.01
	disc.material = mat(Color(0, 0, 0, 0.45), 0.0, true)
	_ball_shadow.mesh = disc
	add_child(_ball_shadow)
	## Marca donde va a botar la pelota que te llega (ayuda para colocarse).
	_spot = MeshInstance3D.new()
	var rt: TorusMesh = TorusMesh.new()
	rt.inner_radius = 0.22
	rt.outer_radius = 0.3
	rt.material = mat(Color(1.0, 0.85, 0.2, 0.8), 0.6, true)
	_spot.mesh = rt
	_spot.scale = Vector3(1, 0.1, 1)
	add_child(_spot)


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
	_hud.draw.connect(_draw_stick)
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
	_score_lbl = Label.new()
	_score_lbl.name = "Score"
	_score_lbl.add_theme_font_size_override("font_size", 32)
	_score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	board.add_child(_score_lbl)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)
	_big = Label.new()
	_big.name = "Big"
	_big.theme_type_variation = "TitleLabel"
	_big.add_theme_font_size_override("font_size", 80)
	_big.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_big.add_theme_constant_override("outline_size", 14)
	_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_big.set_anchors_preset(Control.PRESET_CENTER)
	_big.position = Vector2(-360, -240)
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
	_say(Kit.text("tn_hint", "Mu\u00e9vete hacia la pelota y pulsa GOLPE justo antes de darle"), Color("#ffffff"))
	_hit_btn = _round_button("BtnHit", Kit.text("tn_hit", "Golpe"), Vector2(-230, -310), 190.0, Kit.color("accent", Color("#ff7043")))
	_hit_btn.button_down.connect(func() -> void: _want_hit = true)
	_lob_btn = _round_button("BtnLob", Kit.text("tn_lob", "Globo"), Vector2(-440, -200), 150.0, Color("#4fc3f7"))
	_lob_btn.button_down.connect(func() -> void: _want_lob = true)


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


func _draw_stick() -> void:
	if _move_id >= 0:
		_hud.draw_circle(_move_o, 100.0, Color(1, 1, 1, 0.12))
		_hud.draw_arc(_move_o, 100.0, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 3.0)
		_hud.draw_circle(_move_o + _move_v * 100.0, 40.0, Color(1, 1, 1, 0.45))
	elif not _bot:
		var home: Vector2 = Vector2(170.0, _hud.size.y - 280.0)
		_hud.draw_arc(home, 90.0, 0.0, TAU, 40, Color(1, 1, 1, 0.22), 3.0)
		_hud.draw_circle(home, 36.0, Color(1, 1, 1, 0.16))


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
	tw.tween_interval(1.8)
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
			inp = {"move": mv, "hit": _want_hit or Input.is_action_just_pressed("jump"), "lob": _want_lob or Input.is_action_just_pressed("shoot")}
			_want_hit = false
			_want_lob = false
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
			"hit", "serve":
				_sfx("ui_tap", -4.0 if bool(e["perfect"]) else -8.0, 0.8 if bool(e["perfect"]) else 1.1)
				if int(e["i"]) == 0 and bool(e["perfect"]) and str(e["kind"]) == "hit":
					_say(Kit.text("tn_perfect", "\u00a1Golpe perfecto!"), Color("#43d17a"))
			"bounce":
				_sfx("ui_tick", -18.0)
			"net":
				_sfx("stomp", -10.0)
			"point":
				var ours: bool = int(e["winner"]) == 0
				var why: String = e["why"]
				var txt: String = ""
				match why:
					"net":
						txt = Kit.text("tn_net", "\u00a1A la red!")
					"out":
						txt = Kit.text("tn_out", "\u00a1Fuera!")
					_:
						txt = Kit.text("tn_winner", "\u00a1Punto ganador!") if ours else Kit.text("tn_missed", "No llegaste")
				_say(txt, Color("#5ad17a") if ours else Color("#ff6b6b"))
				_sfx("coin" if ours else "ui_error", -6.0)
				if ours:
					Juice.vibrate(25)
			"game":
				var ours2: bool = int(e["winner"]) == 0
				_big_text(Kit.text("tn_game", "\u00a1Juego!") if ours2 else Kit.text("tn_game_them", "Juego rival"), Color("#ffd23f") if ours2 else Color("#ff6b6b"))
				if ours2:
					coins = int(st["games"][0])
	(st["events"] as Array).clear()


func _sync(delta: float) -> void:
	var players: Array = st["players"]
	var b: Dictionary = st["ball"]
	for k: int in players.size():
		var pl: Dictionary = players[k]
		var e: Dictionary = _men[k]
		var root: Node3D = e["root"]
		root.position = to3(pl["p"])
		## Mirando siempre hacia la red.
		root.rotation.y = 0.0 if k == 0 else PI
		var spd: float = (pl.get("v", Vector2.ZERO) as Vector2).length()
		var swing: float = sin(_t * 15.0 + float(k)) * clampf(spd / 4.0, 0.0, 1.0) * 0.8
		(e["legs"][0] as Node3D).rotation.x = swing
		(e["legs"][1] as Node3D).rotation.x = -swing
		var arm: Node3D = e["arm"]
		var sw: float = float(pl["swing_t"])
		arm.rotation.x = -1.6 + sin((0.3 - sw) / 0.3 * PI) * 1.4 if sw > 0.0 else -0.5
		arm.rotation.y = (0.3 - sw) * 6.0 - 0.9 if sw > 0.0 else 0.0
	var bp: Vector2 = b["p"]
	_ball.position = to3(bp, BALL_R + float(b["h"]))
	_ball_shadow.position = to3(bp, 0.02)
	var incoming: bool = bool(b["live"]) and int(b["last"]) == 1 and not _bot
	_spot.visible = incoming
	if incoming:
		_spot.position = to3(b["landed"], 0.03)
	var g: Array = st["games"]
	_score_lbl.text = "%s %d  \u00b7  %s - %s  \u00b7  %d %s" % [Kit.text("tn_you", "T\u00da"), int(g[0]), M.score_text(st, 0), M.score_text(st, 1), int(g[1]), Kit.text("tn_rival", "RIVAL")]
	_hit_btn.visible = not _bot
	_lob_btn.visible = not _bot
	_hud.queue_redraw()
	## Camara de television detras de ti, un poco hacia la pelota.
	var me: Vector2 = players[0]["p"]
	var cx: float = lerpf(0.0, (me.x + bp.x) * 0.5, 0.35)
	var want: Vector3 = Vector3(cx, 7.8, maxf(M.HL + 5.5, me.y + 5.0))
	_cam.position = _cam.position.lerp(want, minf(1.0, delta * 3.0)) if not fast and delta < 0.5 else want
	_cam.look_at(Vector3(cx * 0.6, 0.0, -2.5), Vector3.UP)
	Audio.set_intensity(clampf(0.45 + 0.05 * float(st["rally"]), 0.0, 1.0))


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
	var g: Array = st["games"]
	coins = int(g[0])
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = maxi(1, 1500 * int(g[0]) - 600 * int(g[1]) + 500)
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "time": snappedf(time_in_level, 0.1), "for": int(g[0]), "against": int(g[1])})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


func stars_earned() -> int:
	var g: Array = st.get("games", [0, 0])
	return 3 if int(g[1]) == 0 else (2 if int(g[0]) - int(g[1]) >= 2 else 1)


func _lose() -> void:
	if finished:
		return
	finished = true
	failed = true
	deaths += 1
	var g: Array = st["games"]
	QA.log_event("death", {"cause": "match", "for": int(g[0]), "against": int(g[1])})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("tn_lost", "Has perdido %d - %d") % [int(g[0]), int(g[1])],
		Kit.text("tn_fail_hint", "Ponte en el aro amarillo, pulsa GOLPE justo antes de darle y empuja el mando hacia el lado vac\u00edo."))
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
	var g: Array = st.get("games", [0, 0])
	return {"deaths": deaths, "coins": coins, "finished": finished, "failed": failed, "time": time_in_level, "for": int(g[0]), "against": int(g[1])}
