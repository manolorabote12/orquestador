extends Node3D
## Terror 3D en primera persona: casa a oscuras con linterna. Mando a la izquierda, arrastra a la
## derecha para mirar, boton para esconderte en un armario. Encuentra las llaves y sal antes de
## que te pille el monstruo (tienes vidas; las llaves cogidas se quedan).
## Reglas, monstruo, bot y analizador en horror_map.gd.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const M = preload("res://kit/horror/horror_map.gd")
const T: float = 2.0
const EYE: float = 1.6

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
var _torch: SpotLight3D
var _mon: Node3D
var _mon_eyes: OmniLight3D
var _keys: Array = []
var _door: Node3D
var _door_light: OmniLight3D
var _hud: Control
var _info: Label
var _keys_lbl: Label
var _lives_bar: Control
var _hide_btn: Button
var _slats: Control
var _flash: ColorRect
var _scare: Node3D
var _scare_t: float = 0.0
var _bot: bool = false
var _t: float = 0.0
var _move_id: int = -1
var _move_o: Vector2 = Vector2.ZERO
var _move_v: Vector2 = Vector2.ZERO
var _look_id: int = -1
var _look_last: Vector2 = Vector2.ZERO
var _want_hide: bool = false
var _step_t: float = 0.0
var _bob: float = 0.0


func _ready() -> void:
	level = Kit.current_level()
	par = float(level.get("par", 120))
	_font = UI.theme.get_font("font", "Label") if UI.theme != null else ThemeDB.fallback_font
	_reset()
	_build_env()
	_build_house()
	_build_hud()
	_sync(1.0)
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "horror", "keys": (st["keys"] as Array).size()})


func bot_script() -> String:
	return "res://qa/horror_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(3.0, 3.0)


func wants_backdrop() -> bool:
	return false


func _reset() -> void:
	finished = false
	failed = false
	st = M.new_state(level)
	coins = 0
	coins_total = (st["keys"] as Array).size()
	time_in_level = 0.0


static func mat(col: Color, emission: float = 0.0) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.9
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


# ------------------------------------------------------------------ casa

func _build_env() -> void:
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#030305")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#8a9cc8")
	env.ambient_light_energy = 0.13
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	add_child(we)
	_cam = Camera3D.new()
	_cam.fov = 70.0
	_cam.near = 0.05
	_cam.far = 60.0
	add_child(_cam)
	_cam.make_current()
	## Linterna (y un poco de luz alrededor para no ir del todo a ciegas).
	_torch = SpotLight3D.new()
	_torch.light_color = Color("#ffe2b0")
	_torch.light_energy = 3.2
	_torch.spot_range = 18.0
	_torch.spot_angle = 34.0
	_torch.spot_attenuation = 0.8
	_torch.shadow_enabled = false
	_cam.add_child(_torch)
	var glow: OmniLight3D = OmniLight3D.new()
	glow.light_color = Color("#9fb0d8")
	glow.light_energy = 0.6
	glow.omni_range = 4.0
	_cam.add_child(glow)


func _build_house() -> void:
	var w: int = int(st["w"])
	var h: int = int(st["h"])
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = w * 31 + h
	var walls: Array[Vector3] = []
	var floors: Array[Vector3] = []
	for y: int in h:
		for x: int in w:
			var c: String = M.cell(st, x, y)
			var at: Vector3 = Vector3((x + 0.5) * T, 0, (y + 0.5) * T)
			if c == "#":
				walls.append(at)
			else:
				floors.append(at)
	_multi("Walls", walls, Vector3(T, 2.8, T), Color("#8a7266"), Vector3(0, 1.4, 0), _texture("wall"))
	_multi("Floor", floors, Vector3(T, 0.1, T), Color("#8a6a4c"), Vector3(0, -0.05, 0), _texture("floor"))
	_multi("Ceiling", floors, Vector3(T, 0.1, T), Color("#2a2730"), Vector3(0, 2.85, 0))
	## Zocalos y algun cuadro torcido en las paredes que dan al pasillo.
	for y2: int in h:
		for x2: int in w:
			if M.cell(st, x2, y2) != "#":
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if M.walkable(st, x2 + d.x, y2 + d.y) and rng.randf() < 0.06:
					var face: Vector3 = Vector3((x2 + 0.5 + d.x * 0.52) * T, 1.6, (y2 + 0.5 + d.y * 0.52) * T)
					var frame: MeshInstance3D = _box(Vector3(0.7 if d.y != 0 else 0.05, 0.9, 0.05 if d.y != 0 else 0.7), Color("#6d4c2f"), face)
					frame.rotation.z = rng.randf_range(-0.2, 0.2)
	## Llaves.
	for k: Dictionary in st["keys"]:
		var node: Node3D = Node3D.new()
		node.position = to3(M.center(k["c"]), 1.0)
		add_child(node)
		var ring: MeshInstance3D = MeshInstance3D.new()
		var tm: TorusMesh = TorusMesh.new()
		tm.inner_radius = 0.07
		tm.outer_radius = 0.13
		tm.material = mat(Color("#ffd23f"), 1.2)
		ring.mesh = tm
		ring.rotation_degrees = Vector3(90, 0, 0)
		ring.position = Vector3(0, 0.12, 0)
		node.add_child(ring)
		_box(Vector3(0.05, 0.28, 0.05), Color("#ffd23f"), Vector3(0, -0.06, 0), node, 1.2)
		_box(Vector3(0.09, 0.04, 0.04), Color("#ffd23f"), Vector3(0.05, -0.16, 0), node, 1.2)
		var kl: OmniLight3D = OmniLight3D.new()
		kl.light_color = Color("#ffcf6a")
		kl.light_energy = 0.9
		kl.omni_range = 2.6
		node.add_child(kl)
		_keys.append(node)
	## Armarios.
	for hc: Vector2i in st["hides"]:
		var wr: Node3D = Node3D.new()
		wr.position = to3(M.center(hc))
		add_child(wr)
		_box(Vector3(1.5, 2.3, 1.5), Color("#2b1d14"), Vector3(0, 1.15, 0), wr)
		_box(Vector3(0.04, 2.1, 1.52), Color("#140d08"), Vector3(0, 1.15, 0), wr)
		_box(Vector3(1.52, 2.1, 0.04), Color("#140d08"), Vector3(0, 1.15, 0), wr)
	## Puerta de salida.
	var ex: Vector2i = st["exit"]
	_door = Node3D.new()
	_door.name = "ExitDoor"
	_door.position = to3(M.center(ex))
	add_child(_door)
	_box(Vector3(1.4, 2.4, 0.2), Color("#5a2e1a"), Vector3(0, 1.2, 0), _door)
	_box(Vector3(0.12, 0.12, 0.25), Color("#c9a14a"), Vector3(0.5, 1.15, 0), _door, 0.5)
	_door_light = OmniLight3D.new()
	_door_light.light_color = Color("#ff3b30")
	_door_light.light_energy = 1.2
	_door_light.omni_range = 4.0
	_door_light.position = Vector3(0, 2.6, 0.6)
	_door.add_child(_door_light)
	## El monstruo: alto, oscuro, con los ojos rojos.
	_mon = Node3D.new()
	_mon.name = "Monster"
	add_child(_mon)
	var body: MeshInstance3D = MeshInstance3D.new()
	var cap: CapsuleMesh = CapsuleMesh.new()
	cap.radius = 0.34
	cap.height = 1.9
	cap.material = mat(Color("#0d0d10"))
	body.mesh = cap
	body.position = Vector3(0, 1.1, 0)
	_mon.add_child(body)
	var head: MeshInstance3D = MeshInstance3D.new()
	var sp: SphereMesh = SphereMesh.new()
	sp.radius = 0.25
	sp.height = 0.55
	sp.material = mat(Color("#c9c3b8"))
	head.mesh = sp
	head.position = Vector3(0, 2.2, 0)
	_mon.add_child(head)
	for sx: float in [-0.09, 0.09]:
		_box(Vector3(0.07, 0.05, 0.03), Color("#ff1a1a"), Vector3(sx, 2.25, -0.23), _mon, 4.0)
	for sx2: float in [-0.42, 0.42]:
		_box(Vector3(0.12, 1.1, 0.12), Color("#0d0d10"), Vector3(sx2, 1.3, -0.15), _mon).rotation.x = -0.6
	_mon_eyes = OmniLight3D.new()
	_mon_eyes.light_color = Color("#ff2020")
	_mon_eyes.light_energy = 0.8
	_mon_eyes.omni_range = 2.2
	_mon_eyes.position = Vector3(0, 2.2, -0.4)
	_mon.add_child(_mon_eyes)


## Texturas hechas en el codigo: papel pintado viejo con rayas y suelo de tablas.
func _texture(kind: String) -> ImageTexture:
	var img: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7 if kind == "wall" else 11
	for y: int in 64:
		for x: int in 64:
			var c: Color
			if kind == "wall":
				c = Color("#7d6458") if (x / 8) % 2 == 0 else Color("#6e5549")
				if y > 52:
					c = Color("#3e2a20")
				elif y == 52 or y == 51:
					c = Color("#2a1b14")
				if (x * 7 + y * 3) % 23 == 0:
					c = c.darkened(0.25)
			else:
				var plank: int = y / 16
				c = Color("#6b4a33").lerp(Color("#5a3d2a"), float(plank % 2))
				if y % 16 == 0 or (x + plank * 23) % 64 == 0:
					c = Color("#2e1f15")
			img.set_pixel(x, y, c.darkened(rng.randf_range(0.0, 0.12)))
	return ImageTexture.create_from_image(img)


func _multi(nm: String, at: Array[Vector3], size: Vector3, col: Color, off: Vector3, tex: Texture2D = null) -> void:
	if at.is_empty():
		return
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var b: BoxMesh = BoxMesh.new()
	b.size = size
	b.material = mat(col)
	if tex != null:
		(b.material as StandardMaterial3D).albedo_texture = tex
		(b.material as StandardMaterial3D).albedo_color = Color(0.78, 0.74, 0.72)
	mm.mesh = b
	mm.instance_count = at.size()
	for k: int in at.size():
		mm.set_instance_transform(k, Transform3D(Basis.IDENTITY, at[k] + off))
	var mi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mi.name = nm
	mi.multimesh = mm
	add_child(mi)


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
	## Rendijas del armario (cuando estas escondido).
	_slats = Control.new()
	_slats.set_anchors_preset(Control.PRESET_FULL_RECT)
	_slats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slats.visible = false
	_slats.draw.connect(func() -> void:
		var sz: Vector2 = _slats.size
		var y: float = 0.0
		while y < sz.y:
			_slats.draw_rect(Rect2(0, y, sz.x, 46.0), Color(0.03, 0.02, 0.01, 0.94))
			y += 62.0)
	_hud.add_child(_slats)
	_flash = ColorRect.new()
	_flash.color = Color(0.6, 0, 0, 0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_flash)
	var safe: MarginContainer = UI.safe_root(_hud, 14.0)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	safe.add_child(top)
	_lives_bar = Control.new()
	_lives_bar.custom_minimum_size = Vector2(160, 60)
	_lives_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lives_bar.draw.connect(_draw_lives)
	top.add_child(_lives_bar)
	_keys_lbl = Label.new()
	_keys_lbl.name = "Keys"
	_keys_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_keys_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_keys_lbl.add_theme_font_size_override("font_size", 32)
	_keys_lbl.add_theme_color_override("font_color", Color("#ffd23f"))
	top.add_child(_keys_lbl)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)
	_info = Label.new()
	_info.name = "Info"
	_info.add_theme_font_size_override("font_size", 28)
	_info.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_info.add_theme_constant_override("outline_size", 8)
	_info.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_info.position = Vector2(-320, 130)
	_info.size = Vector2(640, 80)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_info)
	_say(Kit.text("hr_hint", "Encuentra las llaves y escapa. Que no te vea."), Color("#e0e0e0"))
	_hide_btn = UI.make_button(Kit.text("hr_hide", "Esconderse"), true)
	_hide_btn.name = "BtnHide"
	_hide_btn.custom_minimum_size = Vector2(230, 120)
	_hide_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_hide_btn.offset_left = -270.0
	_hide_btn.offset_top = -230.0
	_hide_btn.offset_right = -40.0
	_hide_btn.offset_bottom = -110.0
	_hide_btn.visible = false
	_hide_btn.pressed.connect(func() -> void: _want_hide = true)
	_hud.add_child(_hide_btn)


func _draw_lives() -> void:
	for k: int in clampi(int(level.get("lives", 3)), 1, 9):
		var c: Vector2 = Vector2(22.0 + float(k) * 40.0, 30.0)
		var on: bool = k < int(st["lives"])
		var col: Color = Color("#ff4d5e") if on else Color(1, 1, 1, 0.2)
		_lives_bar.draw_circle(c + Vector2(-5, -3), 7.0, col)
		_lives_bar.draw_circle(c + Vector2(5, -3), 7.0, col)
		_lives_bar.draw_colored_polygon(PackedVector2Array([c + Vector2(-12, 0), c + Vector2(12, 0), c + Vector2(0, 13)]), col)


func _draw_stick() -> void:
	if _move_id >= 0:
		_hud.draw_circle(_move_o, 100.0, Color(1, 1, 1, 0.08))
		_hud.draw_arc(_move_o, 100.0, 0.0, TAU, 48, Color(1, 1, 1, 0.25), 3.0)
		_hud.draw_circle(_move_o + Vector2(_move_v.x, -_move_v.y) * 100.0, 40.0, Color(1, 1, 1, 0.3))
	elif not _bot:
		var home: Vector2 = Vector2(170.0, _hud.size.y - 280.0)
		_hud.draw_arc(home, 90.0, 0.0, TAU, 40, Color(1, 1, 1, 0.16), 3.0)


func _say(text: String, col: Color) -> void:
	if fast or _info == null:
		return
	_info.text = text
	_info.add_theme_color_override("font_color", col)
	_info.modulate.a = 1.0
	var tw: Tween = _info.create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(_info, "modulate:a", 0.0, 0.6)


# ------------------------------------------------------------------ bucle

func can_act() -> bool:
	return not finished and is_inside_tree() and not get_tree().paused


func bot_step() -> void:
	_bot = true


func _sfx(n: String, vol: float = -10.0, pitch: float = 1.0) -> void:
	if not fast:
		Audio.play(n, 0.05, vol, pitch)


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
		if _scare_t > 0.0 and not fast:
			break
		var inp: Dictionary = {}
		if _bot:
			inp = M.bot_control(st, delta)
		else:
			var mv: Vector2 = _move_v
			var keys: Vector2 = Input.get_vector("move_left", "move_right", "move_down", "move_up")
			if keys.length() > 0.1:
				mv = keys
			inp = {"move": mv, "hide": _want_hide or Input.is_action_just_pressed("jump")}
			_want_hide = false
		var before: Vector2 = st["p"]
		M.step(st, inp, delta)
		time_in_level += delta
		_bob += (st["p"] as Vector2).distance_to(before) * 5.0
		_events()
		if bool(st["over"]):
			_end()
			break
	_sync(delta)


func _events() -> void:
	for e: Dictionary in st["events"]:
		match str(e["kind"]):
			"key":
				coins = int(st["got"])
				_sfx("ui_reward", -4.0)
				Juice.vibrate(25)
				_say(Kit.text("hr_key", "\u00a1Una llave! (%d/%d)") % [int(st["got"]), (st["keys"] as Array).size()], Color("#ffd23f"))
			"open":
				_sfx("powerup", -4.0)
				_say(Kit.text("hr_open", "La puerta se ha abierto. \u00a1Corre!"), Color("#5ad17a"))
			"spotted":
				_sfx("ui_error", -2.0, 0.6)
				Juice.vibrate(30)
				_say(Kit.text("hr_spotted", "\u00a1Te ha visto!"), Color("#ff4d4d"))
			"hide":
				_sfx("ui_close", -8.0)
			"unhide":
				_sfx("ui_open", -8.0)
			"caught":
				deaths = int(st["caught"])
				_sfx("hurt", 0.0, 0.7)
				Juice.vibrate(120)
				if not fast:
					_jumpscare()
			"win":
				pass
	(st["events"] as Array).clear()


## Susto: la cara del monstruo delante de la camara, todo rojo y temblando.
func _jumpscare() -> void:
	_scare_t = 0.9
	if _scare == null:
		_scare = Node3D.new()
		var face: MeshInstance3D = MeshInstance3D.new()
		var sp: SphereMesh = SphereMesh.new()
		sp.radius = 0.35
		sp.height = 0.8
		sp.material = mat(Color("#d8d0c4"))
		face.mesh = sp
		_scare.add_child(face)
		for sx: float in [-0.12, 0.12]:
			_box(Vector3(0.1, 0.07, 0.04), Color("#ff1a1a"), Vector3(sx, 0.08, -0.33), _scare, 5.0)
		_box(Vector3(0.3, 0.12, 0.04), Color("#120000"), Vector3(0, -0.18, -0.33), _scare)
		_cam.add_child(_scare)
	_scare.position = Vector3(0, -0.05, -0.75)
	_scare.rotation = Vector3(0, PI, 0)
	_scare.visible = true
	_flash.color.a = 0.55


func _sync(delta: float) -> void:
	var p: Vector2 = st["p"]
	var hidden: bool = bool(st["hidden"])
	var bob: float = sin(_bob) * 0.05 if not hidden else 0.0
	_cam.position = to3(p, (EYE - 0.25 if hidden else EYE) + bob)
	_cam.rotation = Vector3(float(st["pitch"]), float(st["yaw"]), 0.0)
	if _scare_t > 0.0:
		_scare_t -= delta
		_cam.rotation += Vector3(randf_range(-0.04, 0.04), randf_range(-0.04, 0.04), 0)
		if _scare_t <= 0.0 and _scare != null:
			_scare.visible = false
	_flash.color.a = maxf(0.0, _flash.color.a - delta * 0.8)
	## Pasos.
	_step_t += (p - (st.get("_last_p", p) as Vector2)).length()
	st["_last_p"] = p
	if _step_t > 0.9:
		_step_t = 0.0
		_sfx("ui_tick", -22.0, 0.5)
	## Monstruo y su andar.
	var mon: Dictionary = st["mon"]
	_mon.position = to3(mon["p"])
	var md: Vector2 = mon["dir"]
	_mon.rotation.y = lerp_angle(_mon.rotation.y, atan2(-md.x, -md.y), minf(1.0, delta * 8.0))
	_mon.position.y = absf(sin(_t * (9.0 if str(mon["state"]) == "chase" else 5.0))) * 0.06
	_mon_eyes.light_energy = 1.6 if str(mon["state"]) == "chase" else 0.7
	## Llaves y puerta.
	var keys: Array = st["keys"]
	for k: int in keys.size():
		var n: Node3D = _keys[k]
		n.visible = not bool(keys[k]["got"])
		n.rotation.y = _t * 2.0
		n.position.y = 1.0 + sin(_t * 2.5 + float(k)) * 0.08
	if bool(st["open"]):
		_door_light.light_color = Color("#3ddc84")
		(_door.get_child(0) as Node3D).rotation.y = lerpf((_door.get_child(0) as Node3D).rotation.y, 1.4, minf(1.0, delta * 2.0))
	## Interfaz.
	_keys_lbl.text = Kit.text("hr_keys", "Llaves %d/%d") % [int(st["got"]), keys.size()]
	_slats.visible = hidden
	var near: bool = M.near_hide(st) >= 0
	_hide_btn.visible = (near or hidden) and not _bot
	_hide_btn.text = Kit.text("hr_unhide", "Salir") if hidden else Kit.text("hr_hide", "Esconderse")
	_lives_bar.queue_redraw()
	_hud.queue_redraw()
	## Latido: mas fuerte cuanto mas cerca esta (y si te persigue, a tope).
	var dist: float = (mon["p"] as Vector2).distance_to(p)
	Audio.set_intensity(1.0 if str(mon["state"]) == "chase" else clampf(1.0 - dist / 8.0, 0.25, 0.9))


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
			var d: Vector2 = dr.position - _look_last
			_look_last = dr.position
			st["yaw"] = wrapf(float(st["yaw"]) - d.x * 0.005, -PI, PI)
			st["pitch"] = clampf(float(st["pitch"]) - d.y * 0.004, -0.9, 0.9)


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
	coins = int(st["got"])
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = maxi(1, 10000 - int(time_in_level) * 20 - int(st["caught"]) * 1500)
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "time": snappedf(time_in_level, 0.1), "caught": int(st["caught"])})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


func stars_earned() -> int:
	var c: int = int(st.get("caught", 0))
	if c > 1:
		return 1
	return 3 if c == 0 and (par <= 0.0 or time_in_level <= par) else 2


func _lose() -> void:
	if finished:
		return
	finished = true
	failed = true
	QA.log_event("death", {"cause": "monster", "keys": int(st["got"])})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("hr_lost", "\u00a1Te ha atrapado!"),
		Kit.text("hr_fail_hint", "Escucha tu coraz\u00f3n: cuanto m\u00e1s late, m\u00e1s cerca est\u00e1. Esc\u00f3ndete en un armario si te ve."))
	p.closed.connect(retry)


func retry() -> void:
	deaths = 0
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
	return {"pos": st.get("p", Vector2.ZERO), "deaths": deaths, "coins": coins, "finished": finished, "failed": failed,
		"time": time_in_level, "keys": int(st.get("got", 0)), "caught": int(st.get("caught", 0))}
