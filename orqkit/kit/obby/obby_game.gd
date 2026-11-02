extends Node3D
## Parkour 3D (obby) en tercera persona: mando a la izquierda, arrastra a la derecha para girar la
## camara, toca a la derecha o el boton para saltar. Plataformas que se mueven, que desaparecen,
## barras que giran, lava, camas elasticas y puntos de control hasta la meta.
## Reglas, fisica, bot y analizador en obby_map.gd.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel al acabar.

const M = preload("res://kit/obby/obby_map.gd")
const CAM_DIST: float = 6.5
const CAM_UP: float = 3.2

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
var _camera: Camera3D
var _cam_yaw: float = 0.0
var _cam_pitch: float = 0.32
var _hero: Node3D
var _hero_vis: Node3D
var _legs: Array[Node3D] = []
var _shadow: MeshInstance3D
var _nodes: Dictionary = {}
var _hud: Control
var _prog: Control
var _info: Label
var _jump_btn: Button
var _flash: ColorRect
var _bot: bool = false
var _t: float = 0.0
var _dead_t: float = 0.0
var _move_id: int = -1
var _move_o: Vector2 = Vector2.ZERO
var _move_v: Vector2 = Vector2.ZERO
var _look_id: int = -1
var _look_last: Vector2 = Vector2.ZERO
var _look_t: float = 0.0
var _look_moved: float = 0.0
var _jump_held: bool = false
var _tap_jump: float = 0.0
var _squash: float = 0.0


func _ready() -> void:
	level = Kit.current_level()
	par = float(level.get("par", 60))
	_font = UI.theme.get_font("font", "Label") if UI.theme != null else ThemeDB.fallback_font
	_build_env()
	_reset()
	_build_world()
	_build_hero()
	_build_hud()
	_place_camera(1.0)
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "obby", "pieces": (st["pieces"] as Array).size()})


func bot_script() -> String:
	return "res://qa/obby_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(1.5, 2.2)


func wants_backdrop() -> bool:
	return false


func _reset() -> void:
	finished = false
	failed = false
	st = M.new_state(level)
	coins = 0
	coins_total = int(st["coins_total"])
	time_in_level = 0.0
	_cam_yaw = float(st["yaw"])


static func mat(col: Color, emission: float = 0.0) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.7
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emission
	if col.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func _mesh_box(size: Vector3, col: Color, at: Vector3 = Vector3.ZERO, emission: float = 0.0) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var b: BoxMesh = BoxMesh.new()
	b.size = size
	b.material = mat(col, emission)
	mi.mesh = b
	mi.position = at
	return mi


# ------------------------------------------------------------------ escenario

func _build_env() -> void:
	var sky_col: Color = Kit.color("sky", Color("#62b6ff"))
	## Cielo siempre de dia y con color (un gris o un negro no dejan ver el vacio).
	if sky_col.s < 0.3 or sky_col.v < 0.45:
		sky_col = Color.from_hsv(sky_col.h if sky_col.s >= 0.3 else 0.57, 0.55, 0.95)
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sm: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sm.sky_top_color = sky_col.darkened(0.15)
	sm.sky_horizon_color = sky_col.lightened(0.45)
	sm.ground_horizon_color = sky_col.lightened(0.45)
	sm.ground_bottom_color = sky_col.lightened(0.2)
	var sky: Sky = Sky.new()
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.25
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60.0, -35.0, 0.0)
	sun.light_energy = 0.5
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 50.0
	add_child(sun)
	_camera = Camera3D.new()
	_camera.fov = 70.0
	_camera.far = 300.0
	add_child(_camera)
	_camera.make_current()


func _palette() -> Array[Color]:
	var acc: Color = Kit.color("accent", Color("#ff7043"))
	return [acc, Color("#4fc3f7"), Color("#81c784"), Color("#ffb74d"), Color("#ba68c8"), acc.lerp(Color.WHITE, 0.35)]


## Mar de nubes muy abajo y nubes sueltas: se nota lo alto que esta el recorrido.
func _build_backdrop() -> void:
	var pieces: Array = st["pieces"]
	var lo: Vector3 = Vector3(INF, INF, INF)
	var hi: Vector3 = -lo
	for pc: Dictionary in pieces:
		lo = lo.min(pc["c"])
		hi = hi.max(pc["c"])
	if pieces.is_empty():
		return
	var mid: Vector3 = (lo + hi) * 0.5
	var sea: MeshInstance3D = MeshInstance3D.new()
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(700, 700)
	var sky_col: Color = Kit.color("sky", Color("#62b6ff"))
	if sky_col.s < 0.3 or sky_col.v < 0.45:
		sky_col = Color.from_hsv(sky_col.h if sky_col.s >= 0.3 else 0.57, 0.55, 0.95)
	var sm: StandardMaterial3D = mat(sky_col.lerp(Color.WHITE, 0.35).darkened(0.08))
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.material = sm
	sea.mesh = pm
	sea.name = "CloudSea"
	sea.position = Vector3(mid.x, lo.y - 22.0, mid.z)
	add_child(sea)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = pieces.size() * 977 + int(hi.z)
	var cm: StandardMaterial3D = mat(Color(0.97, 0.98, 1.0))
	var ext: Vector3 = (hi - lo).abs() + Vector3(40, 0, 40)
	for k: int in 26:
		var puff: MeshInstance3D = MeshInstance3D.new()
		var sp: SphereMesh = SphereMesh.new()
		sp.radius = 1.0
		sp.height = 2.0
		sp.radial_segments = 12
		sp.rings = 6
		sp.material = cm
		puff.mesh = sp
		puff.scale = Vector3(rng.randf_range(3.0, 7.0), rng.randf_range(0.8, 1.6), rng.randf_range(2.5, 5.0))
		puff.position = Vector3(mid.x + rng.randf_range(-0.5, 0.5) * ext.x, lo.y - rng.randf_range(7.0, 18.0), mid.z + rng.randf_range(-0.5, 0.5) * ext.z)
		add_child(puff)


func _build_world() -> void:
	_build_backdrop()
	var pal: Array[Color] = _palette()
	var pieces: Array = st["pieces"]
	for pc: Dictionary in pieces:
		var k: String = pc["k"]
		var s: Vector3 = pc["s"]
		var root: Node3D = Node3D.new()
		root.name = "Piece%d" % int(pc["i"])
		root.position = pc["c"]
		add_child(root)
		_nodes[int(pc["i"])] = root
		var col: Color = pal[int(pc["i"]) % pal.size()]
		match k:
			"P", "M", "F", "C", "J", "G":
				if k == "M":
					col = Color("#4aa8ff")
				elif k == "F":
					col = Color("#ffd54a")
				elif k == "C":
					col = Color("#5ad17a")
				elif k == "J":
					col = Color("#ff5fc8")
				elif k == "G":
					col = Color("#ffd23f")
				root.add_child(_mesh_box(s, col.darkened(0.12)))
				## Tapa mas clara: se lee bien donde se pisa.
				root.add_child(_mesh_box(Vector3(s.x - 0.08, 0.08, s.z - 0.08), col.lightened(0.25), Vector3(0, s.y * 0.5 + 0.01, 0)))
				if k == "C":
					_flag(root, Vector3(s.x * 0.5 - 0.3, s.y * 0.5, -s.z * 0.5 + 0.3), Color("#ffffff"))
				elif k == "J":
					var pad: MeshInstance3D = MeshInstance3D.new()
					var cy: CylinderMesh = CylinderMesh.new()
					cy.top_radius = minf(s.x, s.z) * 0.38
					cy.bottom_radius = cy.top_radius
					cy.height = 0.12
					cy.material = mat(Color("#ffffff"), 0.6)
					pad.mesh = cy
					pad.position = Vector3(0, s.y * 0.5 + 0.08, 0)
					pad.name = "Pad"
					root.add_child(pad)
				elif k == "G":
					## Arco de meta con dos postes y un cartel.
					root.add_child(_mesh_box(Vector3(0.3, 3.0, 0.3), Color("#ffffff"), Vector3(-s.x * 0.5 + 0.3, s.y * 0.5 + 1.5, 0)))
					root.add_child(_mesh_box(Vector3(0.3, 3.0, 0.3), Color("#ffffff"), Vector3(s.x * 0.5 - 0.3, s.y * 0.5 + 1.5, 0)))
					root.add_child(_mesh_box(Vector3(s.x, 0.6, 0.3), Kit.color("accent", Color("#ff7043")), Vector3(0, s.y * 0.5 + 3.0, 0), 0.4))
			"L":
				root.add_child(_mesh_box(s, Color("#e0260a"), Vector3.ZERO, 0.9))
			"S":
				var hub: MeshInstance3D = _mesh_box(Vector3(0.4, 0.9, 0.4), Color("#333a48"), Vector3(0, -0.3, 0))
				root.add_child(hub)
				var bar: Node3D = Node3D.new()
				bar.name = "Bar"
				bar.add_child(_mesh_box(Vector3(s.x, 0.28, 0.28), Color("#ff3b4a"), Vector3.ZERO, 0.5))
				root.add_child(bar)
			"O":
				var coin: MeshInstance3D = MeshInstance3D.new()
				var cm: CylinderMesh = CylinderMesh.new()
				cm.top_radius = 0.38
				cm.bottom_radius = 0.38
				cm.height = 0.1
				cm.material = mat(Kit.color("coin", Color("#ffd54a")), 0.5)
				coin.mesh = cm
				coin.rotation_degrees = Vector3(90, 0, 0)
				coin.name = "Coin"
				root.add_child(coin)


func _flag(parent: Node3D, at: Vector3, col: Color) -> void:
	parent.add_child(_mesh_box(Vector3(0.08, 1.8, 0.08), Color("#e0e0e0"), at + Vector3(0, 0.9, 0)))
	var f: MeshInstance3D = _mesh_box(Vector3(0.7, 0.45, 0.04), col, at + Vector3(-0.38, 1.55, 0))
	f.name = "Flag"
	parent.add_child(f)


func _build_hero() -> void:
	_hero = Node3D.new()
	_hero.name = "Hero"
	add_child(_hero)
	var art: Dictionary = Kit.sprite_by_role("jugador")
	if not art.is_empty():
		var spr: AnimatedSprite3D = AnimatedSprite3D.new()
		spr.sprite_frames = SpriteKit.frames_de(art)
		var celda: Array = art.get("celda", [32, 32])
		spr.pixel_size = 1.7 / maxf(float(celda[1]), 1.0)
		spr.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST if str(Kit.param("ui.profile", "")) == "pixel" else BaseMaterial3D.TEXTURE_FILTER_LINEAR
		spr.shaded = false
		spr.position = Vector3(0, 0.85, 0)
		spr.name = "Sprite"
		if spr.sprite_frames.has_animation("idle"):
			spr.play("idle")
		_hero_vis = spr
	else:
		## Muneco de bloques (como en los obby): cuerpo, cabeza, ojos y piernas que se mueven.
		var body_col: Color = Skins.recolor(Kit.color("accent", Color("#ff7043")))
		var v: Node3D = Node3D.new()
		v.add_child(_mesh_box(Vector3(0.62, 0.6, 0.36), body_col, Vector3(0, 0.95, 0)))
		v.add_child(_mesh_box(Vector3(0.5, 0.48, 0.5), Color("#ffd9b0"), Vector3(0, 1.5, 0)))
		v.add_child(_mesh_box(Vector3(0.08, 0.1, 0.02), Color("#202020"), Vector3(-0.11, 1.55, -0.26)))
		v.add_child(_mesh_box(Vector3(0.08, 0.1, 0.02), Color("#202020"), Vector3(0.11, 1.55, -0.26)))
		for sx: float in [-0.16, 0.16]:
			var leg: Node3D = Node3D.new()
			leg.position = Vector3(sx, 0.65, 0)
			leg.add_child(_mesh_box(Vector3(0.26, 0.65, 0.3), body_col.darkened(0.35), Vector3(0, -0.32, 0)))
			v.add_child(leg)
			_legs.append(leg)
		for sx2: float in [-0.42, 0.42]:
			v.add_child(_mesh_box(Vector3(0.2, 0.55, 0.26), body_col.lightened(0.1), Vector3(sx2, 0.98, 0)))
		_hero_vis = v
	_hero.add_child(_hero_vis)
	_shadow = MeshInstance3D.new()
	var disc: CylinderMesh = CylinderMesh.new()
	disc.top_radius = 0.42
	disc.bottom_radius = 0.42
	disc.height = 0.02
	disc.material = mat(Color(0, 0, 0, 0.4))
	_shadow.mesh = disc
	add_child(_shadow)


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
	_flash = ColorRect.new()
	_flash.color = Color(1, 0.3, 0.2, 0.0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_flash)
	var safe: MarginContainer = UI.safe_root(_hud, 14.0)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	safe.add_child(top)
	_prog = Control.new()
	_prog.name = "Progress"
	_prog.custom_minimum_size = Vector2(0, 70)
	_prog.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_prog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prog.draw.connect(_draw_progress)
	top.add_child(_prog)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)
	_info = Label.new()
	_info.name = "Info"
	_info.add_theme_font_size_override("font_size", 26)
	_info.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_info.add_theme_constant_override("outline_size", 6)
	_info.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_info.position = Vector2(-300, 120)
	_info.size = Vector2(600, 40)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_info)
	_jump_btn = UI.make_button(Kit.text("ob_jump", "Saltar"), true)
	_jump_btn.name = "BtnJump"
	_jump_btn.custom_minimum_size = Vector2(170, 130)
	_jump_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_jump_btn.offset_left = -210.0
	_jump_btn.offset_top = -230.0
	_jump_btn.offset_right = -36.0
	_jump_btn.offset_bottom = -90.0
	_jump_btn.button_down.connect(func() -> void: _jump_held = true)
	_jump_btn.button_up.connect(func() -> void: _jump_held = false)
	_hud.add_child(_jump_btn)


func _draw_progress() -> void:
	if st.is_empty():
		return
	var w: float = _prog.size.x - 20.0
	var n: int = maxi(1, (st["pieces"] as Array).size() - 1)
	var f: float = clampf(float(st["best"]) / float(n), 0.0, 1.0)
	var r: Rect2 = Rect2(Vector2(6, 10), Vector2(w, 22))
	_prog.draw_rect(r, Color(0, 0, 0, 0.45))
	_prog.draw_rect(Rect2(r.position, Vector2(w * f, 22)), Kit.color("accent", Color("#ff7043")))
	## Puntos de control en la barra.
	for pc: Dictionary in st["pieces"]:
		if str(pc["k"]) == "C":
			var x: float = r.position.x + w * float(pc["i"]) / float(n)
			_prog.draw_circle(Vector2(x, r.get_center().y), 9.0, Color("#5ad17a") if int(pc["i"]) <= int(st["cp_i"]) else Color(1, 1, 1, 0.6))
	_prog.draw_string(_font, Vector2(6, 62), "%d%%   %s %d/%d   %s %d" % [int(f * 100.0), Kit.text("ob_coins", "Monedas"), coins, coins_total,
		Kit.text("ob_falls", "Ca\u00eddas"), deaths], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)


func _draw_hud() -> void:
	if _move_id >= 0:
		_hud.draw_circle(_move_o, 110.0, Color(1, 1, 1, 0.12))
		_hud.draw_arc(_move_o, 110.0, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 3.0)
		_hud.draw_circle(_move_o + Vector2(_move_v.x, -_move_v.y) * 110.0, 44.0, Color(1, 1, 1, 0.45))
	elif not _bot:
		var home: Vector2 = Vector2(170.0, _hud.size.y - 300.0)
		_hud.draw_arc(home, 90.0, 0.0, TAU, 40, Color(1, 1, 1, 0.22), 3.0)
		_hud.draw_circle(home, 36.0, Color(1, 1, 1, 0.16))


# ------------------------------------------------------------------ acciones

func can_act() -> bool:
	return not finished and is_inside_tree() and not get_tree().paused


func bot_step() -> void:
	_bot = true


func _sfx(n: String, vol: float = -10.0) -> void:
	if not fast:
		Audio.play(n, 0.1, vol)


# ------------------------------------------------------------------ bucle

func _physics_process(delta: float) -> void:
	_t += delta
	if finished:
		return
	if fast and auto_retry:
		_bot = true
	var steps: int = 4 if fast else 1
	for k: int in steps:
		if finished or get_tree().paused:
			break
		if bool(st["dead"]):
			_dead_t -= delta
			if _dead_t <= 0.0 or fast:
				M.respawn(st)
				deaths = int(st["deaths"])
				_cam_yaw = float(st["yaw"])
			continue
		var inp: Dictionary = {}
		if _bot:
			inp = M.bot_control(st, delta)
		else:
			var mv: Vector2 = _move_v
			var keys: Vector2 = Input.get_vector("move_left", "move_right", "move_down", "move_up")
			if keys.length() > 0.1:
				mv = keys
			st["yaw"] = _cam_yaw
			inp = {"move": mv, "jump": _jump_held or _tap_jump > 0.0 or Input.is_action_pressed("jump")}
			_tap_jump = maxf(0.0, _tap_jump - delta)
		M.step(st, inp, delta)
		time_in_level += delta
		_events()
		if bool(st["won"]):
			_finish()
			break
	_animate(delta)


func _events() -> void:
	for e: String in st["events"]:
		match e:
			"jump":
				_sfx("jump", -12.0)
				_squash = 0.25
			"pad":
				_sfx("powerup", -8.0)
				Juice.vibrate(20)
				_squash = 0.4
			"checkpoint":
				_sfx("ui_reward", -6.0)
				Juice.vibrate(25)
				_say(Kit.text("ob_checkpoint", "\u00a1Punto de control!"), Color("#5ad17a"))
			"coin":
				coins = (st["got"] as Dictionary).size()
				_sfx("coin", -8.0)
			"dead":
				_sfx("hurt", -6.0)
				Juice.vibrate(40)
				_dead_t = 0.7
				if _flash != null and not fast:
					_flash.color.a = 0.45
				QA.log_event("death", {"cause": "fall", "piece": int(st["best"])})
			"win":
				pass
	(st["events"] as Array).clear()


func _say(text: String, col: Color) -> void:
	if fast or _info == null:
		return
	_info.text = text
	_info.add_theme_color_override("font_color", col)
	_info.modulate.a = 1.0
	UI.pop_in(_info)
	var tw: Tween = _info.create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(_info, "modulate:a", 0.0, 0.4)


## Piezas que se mueven, barras, monedas, el muneco y la camara.
func _animate(delta: float) -> void:
	var t: float = float(st["t"])
	for pc: Dictionary in st["pieces"]:
		var node: Node3D = _nodes.get(int(pc["i"]), null)
		if node == null:
			continue
		var k: String = pc["k"]
		if k == "M":
			node.position = M.center_at(pc, t)
		elif k == "F":
			## Parpadea al final (aviso de que se va) y, mientras no esta, queda solo su sombra fina.
			var on: bool = M.solid_at(pc, t)
			if on:
				node.scale = Vector3.ONE
				node.visible = M.fade_left(pc, t) >= 0.25 or int(t * 12.0) % 2 == 0
			else:
				node.visible = true
				node.scale = Vector3(1, 0.12, 1)
		elif k == "S":
			(node.get_node("Bar") as Node3D).rotation.y = -M.spinner_angle(pc, t)
		elif k == "O":
			var got: bool = (st["got"] as Dictionary).has(int(pc["i"]))
			node.visible = not got
			node.rotation.y = t * 3.0
			node.position = (pc["c"] as Vector3) + Vector3(0, sin(t * 2.5 + float(pc["i"])) * 0.12, 0)
		elif k == "J":
			var pad: Node3D = node.get_node_or_null("Pad")
			if pad != null:
				pad.scale = Vector3(1, 1.0 + sin(t * 8.0) * 0.3, 1)
		elif k == "C":
			var fl: Node3D = node.get_node_or_null("Flag")
			if fl != null:
				fl.rotation.y = sin(t * 3.0) * 0.25
	## Muneco: posicion, mirando hacia donde va, piernas al andar y estirarse al saltar.
	var p: Vector3 = st["p"]
	var v: Vector3 = st["v"]
	_hero.position = p
	_hero.visible = not bool(st["dead"]) or int(_t * 12.0) % 2 == 0
	var flat: Vector2 = Vector2(v.x, v.z)
	if flat.length() > 0.5:
		_hero.rotation.y = lerp_angle(_hero.rotation.y, atan2(-v.x, -v.z), minf(1.0, delta * 12.0))
	_squash = maxf(0.0, _squash - delta)
	var stretch: float = 1.0 + _squash * 0.6
	_hero_vis.scale = Vector3(1.0 / sqrt(stretch), stretch, 1.0 / sqrt(stretch))
	var swing: float = sin(_t * 14.0) * clampf(flat.length() / M.SPEED, 0.0, 1.0) * 0.8 if bool(st["on_floor"]) else 0.5
	for i: int in _legs.size():
		_legs[i].rotation.x = swing * (1.0 if i == 0 else -1.0)
	if _hero_vis is AnimatedSprite3D:
		var spr: AnimatedSprite3D = _hero_vis
		var anim: String = "run" if flat.length() > 0.5 and bool(st["on_floor"]) else ("jump" if not bool(st["on_floor"]) else "idle")
		if spr.sprite_frames.has_animation(anim) and spr.animation != anim:
			spr.play(anim)
	## Sombra en lo que hay justo debajo.
	var ground_y: float = -1000.0
	for pc2: Dictionary in st["pieces"]:
		if M.solid_at(pc2, t):
			var b: AABB = M.box_at(pc2, t)
			if p.x > b.position.x and p.x < b.end.x and p.z > b.position.z and p.z < b.end.z and b.end.y <= p.y + 0.05 and b.end.y > ground_y:
				ground_y = b.end.y
	_shadow.visible = ground_y > -999.0
	_shadow.position = Vector3(p.x, ground_y + 0.02, p.z)
	var h: float = clampf((p.y - ground_y) / 6.0, 0.0, 0.8)
	_shadow.scale = Vector3.ONE * (1.0 - h)
	if _flash != null:
		_flash.color.a = maxf(0.0, _flash.color.a - delta * 1.5)
	if _bot:
		_cam_yaw = lerp_angle(_cam_yaw, float(st["yaw"]), minf(1.0, delta * 3.0))
	_place_camera(delta)
	var n: int = maxi(1, (st["pieces"] as Array).size() - 1)
	Audio.set_intensity(0.55 + 0.45 * clampf(float(st["best"]) / float(n), 0.0, 1.0))
	_prog.queue_redraw()
	_hud.queue_redraw()


func _place_camera(delta: float) -> void:
	var p: Vector3 = (st["p"] as Vector3) + Vector3(0, 1.2, 0)
	var back: Vector3 = Vector3(sin(_cam_yaw), 0, cos(_cam_yaw)) * cos(_cam_pitch) * CAM_DIST + Vector3(0, sin(_cam_pitch) * CAM_DIST + CAM_UP * 0.4, 0)
	var want: Vector3 = p + back
	_camera.position = _camera.position.lerp(want, minf(1.0, delta * 8.0)) if not fast else want
	_camera.look_at(p + Vector3(0, 0.3, 0), Vector3.UP)


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
				_look_t = _t
				_look_moved = 0.0
		else:
			if te.index == _move_id:
				_move_id = -1
				_move_v = Vector2.ZERO
			elif te.index == _look_id:
				_look_id = -1
				## Toque corto a la derecha: salto.
				if _t - _look_t < 0.25 and _look_moved < 24.0:
					_tap_jump = 0.12
	elif event is InputEventScreenDrag:
		var dr: InputEventScreenDrag = event
		if dr.index == _move_id:
			_move_v = ((dr.position - _move_o) / 110.0).limit_length(1.0)
			_move_v.y = -_move_v.y
		elif dr.index == _look_id:
			var d: Vector2 = dr.position - _look_last
			_look_last = dr.position
			_look_moved += d.length()
			_cam_yaw = wrapf(_cam_yaw - d.x * 0.006, -PI, PI)
			_cam_pitch = clampf(_cam_pitch + d.y * 0.004, 0.05, 1.1)


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	coins = (st["got"] as Dictionary).size()
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = maxi(1, 10000 - int(time_in_level * 20.0) - deaths * 500 + coins * 300)
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "time": snappedf(time_in_level, 0.1), "deaths": deaths})
	Audio.play("win")
	Audio.play_track("victoria", false)
	if not fast:
		Juice.burst(_hud, get_viewport().get_visible_rect().size * 0.5, Color("#ffd23f"), 40)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


func stars_earned() -> int:
	if deaths > 2:
		return 1
	return 3 if deaths == 0 and (par <= 0.0 or time_in_level <= par) else 2


func retry() -> void:
	_reset()
	_place_camera(1.0)


func open_pause() -> void:
	if finished or get_tree().paused or get_node_or_null("PauseMenu") != null:
		return
	PauseMenu.open(self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_inside_tree() and not UI.test_mode:
			open_pause()


func bot_state() -> Dictionary:
	return {"pos": st.get("p", Vector3.ZERO), "deaths": deaths, "coins": coins, "finished": finished, "failed": failed,
		"time": time_in_level, "best": int(st.get("best", 0))}
