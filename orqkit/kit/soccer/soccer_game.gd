extends Node3D
## Futbol 3D arcade: mando a la izquierda para mover al jugador marcado (cambia solo al que esta
## mas cerca del balon), boton TIRO (sin balon: entrada para robar) y PASE. Estadio con publico,
## porterias con red y camara de television que sigue al balon. Gana el partido para pasar.
## Reglas, IA, bot y analizador en soccer_map.gd.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const M = preload("res://kit/soccer/soccer_map.gd")

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

var _font: Font
var _cam: Camera3D
var _men: Array = []
var _ball: Node3D
var _ball_mesh: MeshInstance3D
var _ball_shadow: MeshInstance3D
var _ring: MeshInstance3D
var _hud: Control
var _score_lbl: Label
var _clock_lbl: Label
var _big: Label
var _shoot_btn: Button
var _pass_btn: Button
var _bot: bool = false
var _t: float = 0.0
var _move_id: int = -1
var _move_o: Vector2 = Vector2.ZERO
var _move_v: Vector2 = Vector2.ZERO
var _want_shoot: bool = false
var _want_pass: bool = false
var _col_us: Color
var _col_them: Color


func _ready() -> void:
	level = Kit.current_level()
	par = float(level.get("par", 90))
	_font = UI.theme.get_font("font", "Label") if UI.theme != null else ThemeDB.fallback_font
	_col_us = Kit.color("player", Color("#3fa7ff"))
	_col_them = Color("#e53935") if _col_us.h > 0.4 or _col_us.h < 0.05 and _col_us.s < 0.3 else Color("#1e88e5")
	if absf(_col_us.h - _col_them.h) < 0.12:
		_col_them = Color("#fdd835")
	_reset()
	_build_env()
	_build_stadium()
	_build_people()
	_build_hud()
	_sync(1.0)
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "soccer", "skill": float(st["skill"])})


func bot_script() -> String:
	return "res://qa/soccer_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(4.0, 2.5)


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
		_boost_bot()
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


# ------------------------------------------------------------------ estadio

func _build_env() -> void:
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sm: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("#2d5d9a")
	sm.sky_horizon_color = Color("#a9cdf0")
	sm.ground_horizon_color = Color("#a9cdf0")
	sm.ground_bottom_color = Color("#2c3e50")
	var sky: Sky = Sky.new()
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.25
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-62.0, -20.0, 0.0)
	sun.light_energy = 0.45
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)
	_cam = Camera3D.new()
	_cam.fov = 52.0
	_cam.far = 300.0
	add_child(_cam)
	_cam.make_current()


func _build_stadium() -> void:
	var w: float = float(st["w"])
	var l: float = float(st["l"])
	## Cesped a franjas.
	var stripes: int = 10
	for k: int in stripes:
		var col: Color = Color("#3f8f3a") if k % 2 == 0 else Color("#3a8435")
		_box(Vector3(w + 4.0, 0.1, l / float(stripes)), col, Vector3(w * 0.5, -0.05, l / float(stripes) * (float(k) + 0.5)))
	_box(Vector3(w + 10.0, 0.09, l + 14.0), Color("#2f6d2b"), Vector3(w * 0.5, -0.07, l * 0.5))
	## Lineas.
	var line: Color = Color(1, 1, 1, 0.95)
	var lw: float = 0.12
	for side: float in [0.0, w]:
		_box(Vector3(lw, 0.02, l), line, Vector3(side, 0.01, l * 0.5), null, true)
	for end: float in [0.0, l]:
		_box(Vector3(w, 0.02, lw), line, Vector3(w * 0.5, 0.01, end), null, true)
	_box(Vector3(w, 0.02, lw), line, Vector3(w * 0.5, 0.01, l * 0.5), null, true)
	var circle: MeshInstance3D = MeshInstance3D.new()
	var tm: TorusMesh = TorusMesh.new()
	tm.inner_radius = 3.0
	tm.outer_radius = 3.12
	tm.rings = 48
	tm.material = mat(line, 0.0, true)
	circle.mesh = tm
	circle.scale = Vector3(1, 0.02, 1)
	circle.position = Vector3(w * 0.5, 0.01, l * 0.5)
	add_child(circle)
	for end2: float in [0.0, l]:
		var dir: float = 1.0 if end2 == 0.0 else -1.0
		var bw: float = M.GOAL_W + 6.0
		_box(Vector3(bw, 0.02, lw), line, Vector3(w * 0.5, 0.01, end2 + dir * M.BOX), null, true)
		for sx: float in [-1.0, 1.0]:
			_box(Vector3(lw, 0.02, M.BOX), line, Vector3(w * 0.5 + sx * bw * 0.5, 0.01, end2 + dir * M.BOX * 0.5), null, true)
		_goal(Vector3(w * 0.5, 0, end2), dir)
	## Vallas de publicidad y gradas con publico.
	var acc: Color = Kit.color("accent", Color("#ff7043"))
	for side2: float in [-1.6, w + 1.6]:
		_box(Vector3(0.2, 0.9, l + 3.0), acc if side2 < 0 else acc.lerp(Color.WHITE, 0.3), Vector3(side2, 0.45, l * 0.5))
	for end3: float in [-1.6, l + 1.6]:
		for sx2: float in [-1.0, 1.0]:
			_box(Vector3((w - M.GOAL_W) * 0.5 - 1.5, 0.9, 0.2), acc.lerp(Color("#1a237e"), 0.4), Vector3(w * 0.5 + sx2 * ((w - M.GOAL_W) * 0.25 + 2.0), 0.45, end3))
	_stands(w, l)


func _goal(at: Vector3, dir: float) -> void:
	var g: Node3D = Node3D.new()
	g.position = at
	add_child(g)
	var post: Color = Color("#f5f5f5")
	var gw: float = M.GOAL_W
	for sx: float in [-gw * 0.5, gw * 0.5]:
		_box(Vector3(0.12, 2.3, 0.12), post, Vector3(sx, 1.15, 0), g)
	_box(Vector3(gw + 0.12, 0.12, 0.12), post, Vector3(0, 2.3, 0), g)
	var net: MeshInstance3D = _box(Vector3(gw, 2.3, 1.6), Color(1, 1, 1, 0.22), Vector3(0, 1.15, -dir * 0.8), g)
	((net.mesh as BoxMesh).material as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED


## Gradas escalonadas con aficionados de colores (en MultiMesh, ligero).
func _stands(w: float, l: float) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	var fans: Array[Transform3D] = []
	var cols: Array[Color] = []
	var concrete: Color = Color("#6d7380")
	for row: int in 5:
		var off: float = 3.0 + float(row) * 1.2
		var hgt: float = 0.6 + float(row) * 0.7
		for side: float in [-1.0, 1.0]:
			var x: float = w * 0.5 + side * (w * 0.5 + off)
			_box(Vector3(1.2, hgt, l + 8.0 + float(row) * 2.4), concrete.darkened(float(row) * 0.05), Vector3(x, hgt * 0.5, l * 0.5))
			var zz: float = -4.0
			while zz < l + 4.0:
				if rng.randf() < 0.8:
					fans.append(Transform3D(Basis.IDENTITY, Vector3(x + rng.randf_range(-0.3, 0.3), hgt + 0.3, zz + rng.randf_range(-0.2, 0.2))))
					cols.append(Color.from_hsv(rng.randf(), 0.6, 0.9) if rng.randf() < 0.5 else (_col_us if rng.randf() < 0.6 else _col_them))
				zz += 0.75
	## Fondos detras de las porterias.
	for row2: int in 5:
		var off2: float = 3.2 + float(row2) * 1.2
		var hgt2: float = 0.6 + float(row2) * 0.7
		for end: float in [-1.0, 1.0]:
			var z: float = l * 0.5 + end * (l * 0.5 + off2)
			_box(Vector3(w + 8.0 + float(row2) * 2.4, hgt2, 1.2), concrete.darkened(float(row2) * 0.05), Vector3(w * 0.5, hgt2 * 0.5, z))
			var xx: float = -4.0
			while xx < w + 4.0:
				if rng.randf() < 0.8:
					fans.append(Transform3D(Basis.IDENTITY, Vector3(xx + rng.randf_range(-0.2, 0.2), hgt2 + 0.3, z + rng.randf_range(-0.3, 0.3))))
					cols.append(Color.from_hsv(rng.randf(), 0.6, 0.9) if rng.randf() < 0.5 else (_col_us if rng.randf() < 0.6 else _col_them))
				xx += 0.75
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var fb: BoxMesh = BoxMesh.new()
	fb.size = Vector3(0.4, 0.6, 0.35)
	var fm: StandardMaterial3D = mat(Color.WHITE)
	fm.vertex_color_use_as_albedo = true
	fm.vertex_color_is_srgb = true
	fb.material = fm
	mm.mesh = fb
	mm.instance_count = fans.size()
	for k: int in fans.size():
		mm.set_instance_transform(k, fans[k])
		mm.set_instance_color(k, cols[k])
	var mi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mi.name = "Crowd"
	mi.multimesh = mm
	add_child(mi)


func _build_people() -> void:
	for pl: Dictionary in st["players"]:
		var tm: int = int(pl["team"])
		var col: Color = _col_us if tm == 0 else _col_them
		if str(pl["role"]) == "gk":
			col = Color("#43a047") if tm == 0 else Color("#8e24aa")
		var root: Node3D = Node3D.new()
		root.name = "Player%d" % int(pl["i"])
		add_child(root)
		var body_m: StandardMaterial3D = mat(col)
		var torso: MeshInstance3D = MeshInstance3D.new()
		var cap: CapsuleMesh = CapsuleMesh.new()
		cap.radius = 0.3
		cap.height = 1.1
		cap.material = body_m
		torso.mesh = cap
		torso.position = Vector3(0, 0.85, 0)
		root.add_child(torso)
		var head: MeshInstance3D = MeshInstance3D.new()
		var sp: SphereMesh = SphereMesh.new()
		sp.radius = 0.22
		sp.height = 0.44
		sp.material = mat(Color("#f2c49b"))
		head.mesh = sp
		head.position = Vector3(0, 1.62, 0)
		root.add_child(head)
		var legs: Array = []
		for sx: float in [-0.13, 0.13]:
			var leg: Node3D = Node3D.new()
			leg.position = Vector3(sx, 0.5, 0)
			_box(Vector3(0.16, 0.5, 0.18), Color("#fafafa") if tm == 0 else Color("#212121"), Vector3(0, -0.25, 0), leg)
			root.add_child(leg)
			legs.append(leg)
		var num: Label3D = Label3D.new()
		num.text = str(int(pl["slot"]) + 1)
		num.font_size = 64
		num.pixel_size = 0.006
		num.outline_size = 8
		num.position = Vector3(0, 1.0, 0.32)
		num.rotation_degrees = Vector3(0, 0, 0)
		root.add_child(num)
		_men.append({"root": root, "legs": legs})
	_ball = Node3D.new()
	_ball.name = "Ball"
	add_child(_ball)
	_ball_mesh = MeshInstance3D.new()
	var bs: SphereMesh = SphereMesh.new()
	bs.radius = M.BALL_R
	bs.height = M.BALL_R * 2.0
	bs.material = mat(Color("#fafafa"))
	_ball_mesh.mesh = bs
	_ball.add_child(_ball_mesh)
	for k2: int in 4:
		var patch: MeshInstance3D = MeshInstance3D.new()
		var pb: BoxMesh = BoxMesh.new()
		pb.size = Vector3(0.12, 0.12, 0.12)
		pb.material = mat(Color("#212121"))
		patch.mesh = pb
		patch.position = Vector3(cos(k2 * 1.6), sin(k2 * 2.3), cos(k2 * 0.9)).normalized() * (M.BALL_R - 0.03)
		_ball_mesh.add_child(patch)
	_ball_shadow = MeshInstance3D.new()
	var disc: CylinderMesh = CylinderMesh.new()
	disc.top_radius = 0.26
	disc.bottom_radius = 0.26
	disc.height = 0.01
	disc.material = mat(Color(0, 0, 0, 0.45), 0.0, true)
	_ball_shadow.mesh = disc
	add_child(_ball_shadow)
	## Aro amarillo bajo el jugador que manejas.
	_ring = MeshInstance3D.new()
	var rt: TorusMesh = TorusMesh.new()
	rt.inner_radius = 0.48
	rt.outer_radius = 0.62
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
	var bh: HBoxContainer = HBoxContainer.new()
	bh.alignment = BoxContainer.ALIGNMENT_CENTER
	bh.add_theme_constant_override("separation", 18)
	board.add_child(bh)
	_score_lbl = Label.new()
	_score_lbl.name = "Score"
	_score_lbl.add_theme_font_size_override("font_size", 40)
	bh.add_child(_score_lbl)
	_clock_lbl = Label.new()
	_clock_lbl.name = "Clock"
	_clock_lbl.add_theme_font_size_override("font_size", 30)
	_clock_lbl.modulate = Color(1, 1, 1, 0.8)
	bh.add_child(_clock_lbl)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)
	_big = Label.new()
	_big.name = "Big"
	_big.theme_type_variation = "TitleLabel"
	_big.add_theme_font_size_override("font_size", 96)
	_big.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_big.add_theme_constant_override("outline_size", 14)
	_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_big.set_anchors_preset(Control.PRESET_CENTER)
	_big.position = Vector2(-360, -200)
	_big.size = Vector2(720, 160)
	_big.modulate.a = 0.0
	_big.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_big)
	_shoot_btn = _round_button("BtnShoot", Kit.text("sc_shoot", "Tiro"), Vector2(-230, -300), 180.0, Kit.color("accent", Color("#ff7043")))
	_shoot_btn.button_down.connect(func() -> void: _want_shoot = true)
	_pass_btn = _round_button("BtnPass", Kit.text("sc_pass", "Pase"), Vector2(-420, -200), 140.0, Color("#4fc3f7"))
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
	tw.tween_interval(0.9)
	tw.tween_property(_big, "modulate:a", 0.0, 0.35)


# ------------------------------------------------------------------ bucle

func can_act() -> bool:
	return not finished and is_inside_tree() and not get_tree().paused


func bot_step() -> void:
	if not _bot:
		_boost_bot()
	_bot = true


## El bot juega con tu equipo como una persona que sabe (igual que en el analizador).
func _boost_bot() -> void:
	var n: int = int(st["n"])
	for k: int in range(1, n):
		st["players"][k]["skill"] = maxf(float(st["players"][k]["skill"]), 0.9 if k == n - 1 else float(st["mates"]))


func _sfx(n: String, vol: float = -10.0, pitch: float = 1.0) -> void:
	if not fast:
		Audio.play(n, 0.05, vol, pitch)


func _physics_process(delta: float) -> void:
	_t += delta
	if finished:
		return
	if fast and auto_retry and not _bot:
		_boost_bot()
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
			inp = {"move": mv, "shoot": _want_shoot or Input.is_action_just_pressed("shoot"), "pass": _want_pass or Input.is_action_just_pressed("jump")}
			_want_shoot = false
			_want_pass = false
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
			"kick":
				_sfx("ui_tap", -10.0, 0.7 + float(e["power"]) / 40.0)
			"pass":
				pass
			"goal":
				var ours: bool = int(e["team"]) == 0
				if ours:
					coins = int(st["score"][0])
					_big_text(Kit.text("sc_goal", "\u00a1GOOOL!"), Color("#ffd23f"))
					_sfx("win", -4.0)
					Juice.vibrate(60)
					if not fast:
						Juice.burst(_hud, get_viewport().get_visible_rect().size * 0.5, Color("#ffd23f"), 50)
				else:
					_big_text(Kit.text("sc_goal_them", "Gol rival"), Color("#ff6b6b"))
					_sfx("hurt", -6.0)
				Audio.set_intensity(1.0)
			"save":
				_sfx("ui_big", -8.0)
				var pl: Dictionary = st["players"][int(e["i"])]
				if int(pl["team"]) == 0:
					_big_text(Kit.text("sc_save", "\u00a1Parad\u00f3n!"), Color("#5ad17a"))
			"steal", "tackle":
				_sfx("stomp", -12.0)
			"wall":
				_sfx("ui_tick", -18.0)
			"shot":
				pass
	(st["events"] as Array).clear()


## Jugadores, balon (rodando y botando), el aro del tuyo, marcador y camara.
func _sync(delta: float) -> void:
	var players: Array = st["players"]
	for k: int in players.size():
		var pl: Dictionary = players[k]
		var e: Dictionary = _men[k]
		var root: Node3D = e["root"]
		root.position = to3(pl["p"])
		var face: Vector2 = pl["face"]
		root.rotation.y = lerp_angle(root.rotation.y, atan2(-face.x, -face.y), minf(1.0, delta * 14.0))
		var spd: float = (pl["v"] as Vector2).length()
		var swing: float = sin(_t * 16.0 + float(k)) * clampf(spd / 6.0, 0.0, 1.0) * 0.9
		(e["legs"][0] as Node3D).rotation.x = swing
		(e["legs"][1] as Node3D).rotation.x = -swing
	var b: Dictionary = st["ball"]
	var bp: Vector2 = b["p"]
	_ball.position = to3(bp, M.BALL_R + float(b["h"]))
	var bv: Vector2 = b["v"]
	if bv.length() > 0.1:
		_ball_mesh.rotate(Vector3(bv.y, 0, -bv.x).normalized(), bv.length() * delta / M.BALL_R)
	_ball_shadow.position = to3(bp, 0.02)
	var ctrl: int = int(st["ctrl"])
	_ring.visible = ctrl >= 0
	if ctrl >= 0:
		_ring.position = to3(players[ctrl]["p"], 0.03)
	var s: Array = st["score"]
	_score_lbl.text = "%s %d - %d %s" % [Kit.text("sc_you", "T\u00da"), int(s[0]), int(s[1]), Kit.text("sc_rival", "RIVAL")]
	var left: float = maxf(0.0, float(st["time"]) - float(st["t"]))
	_clock_lbl.text = "%d:%02d" % [int(left) / 60, int(left) % 60]
	var owner: int = int(st["owner"])
	_shoot_btn.text = Kit.text("sc_shoot", "Tiro") if owner >= 0 and owner == ctrl else Kit.text("sc_tackle", "Entrada")
	_pass_btn.disabled = not (owner >= 0 and owner == ctrl)
	_hud.queue_redraw()
	## Camara de television: detras de tu porteria y un poco hacia el balon.
	var w: float = float(st["w"])
	var cx: float = lerpf(w * 0.5, bp.x, 0.55)
	var want: Vector3 = Vector3(cx, 15.0, bp.y + 12.5)
	_cam.position = _cam.position.lerp(want, minf(1.0, delta * 4.0)) if not fast and delta < 0.5 else want
	_cam.look_at(Vector3(cx, 0, bp.y - 1.5), Vector3.UP)
	## Musica: mas intensa cerca de las porterias y al final.
	var near_goal: float = 1.0 - clampf(minf(bp.y, float(st["l"]) - bp.y) / 12.0, 0.0, 1.0)
	Audio.set_intensity(clampf(0.55 + 0.35 * near_goal + (0.2 if left < 15.0 else 0.0), 0.0, 1.0))


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
		if te.pressed and _move_id < 0 and te.position.x < size.x * 0.6:
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
	var score: int = 1000 * int(s[0]) - 300 * int(s[1]) + 500
	var record: bool = Save.submit_best(level_id, maxi(1, score))
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "time": snappedf(time_in_level, 0.1), "for": int(s[0]), "against": int(s[1])})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": maxi(1, score), "record": record})
	await Ads.show_interstitial("level_end")


func stars_earned() -> int:
	var s: Array = st.get("score", [0, 0])
	var diff: int = int(s[0]) - int(s[1])
	return 3 if diff >= 3 or (diff >= 2 and int(s[1]) == 0) else (2 if diff >= 2 or int(s[1]) == 0 else 1)


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
	var title: String = Kit.text("sc_draw", "\u00a1Empate!") if int(s[0]) == int(s[1]) else Kit.text("sc_lost", "Has perdido %d - %d") % [int(s[0]), int(s[1])]
	var p: FailPanel = FailPanel.open(self, title, Kit.text("sc_fail_hint", "Pasa al compa\u00f1ero libre y tira a la esquina lejos del portero."))
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
