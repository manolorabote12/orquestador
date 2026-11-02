extends Node3D
## Mundo de cubos en 3D (primera persona): mando izquierdo para andar, arrastra a la derecha para
## mirar, manten el dedo quieto sobre un cubo para picarlo y toca un hueco con un cubo elegido para
## ponerlo. Fabrica con las mismas recetas que el mundo abierto 2D. El mundo se guarda entre niveles.
## Reglas, mundo, fisica, bot y analizador en voxel_map.gd.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const V = preload("res://kit/voxel/voxel_map.gd")
const S = preload("res://kit/sandbox/sandbox_map.gd")
const MapRules = preload("res://kit/sandbox/sandbox_map.gd")
const SAVE_KEY: String = "voxel_world"
const CHUNK: int = 16
const NAMES: Dictionary = {
	"tierra": "Tierra", "arena": "Arena", "piedra": "Piedra", "tronco": "Tronco", "tablas": "Tablas", "palos": "Palos",
	"mesa": "Mesa de trabajo", "pico_madera": "Pico de madera", "espada_madera": "Espada de madera",
	"pico_piedra": "Pico de piedra", "espada_piedra": "Espada de piedra", "horno": "Horno", "carbon": "Carb\u00f3n",
	"antorcha": "Antorcha", "hierro": "Hierro", "lingote_hierro": "Lingote de hierro", "pico_hierro": "Pico de hierro",
	"espada_hierro": "Espada de hierro", "oro": "Oro", "lingote_oro": "Lingote de oro", "cristal": "Cristal",
	"corona": "Corona", "manzana": "Manzana", "monstruo": "Monstruos",
}
const BLOCK_COL: Array = [Color(0, 0, 0, 0), Color("#8a5a3a"), Color("#8a5a3a"), Color("#7d8590"), Color("#8b5e34"),
	Color("#3f9a46"), Color("#7d8590"), Color("#7d8590"), Color("#7d8590"), Color("#7d8590"), Color("#33363d"),
	Color("#c08a4f"), Color("#e3cf8f"), Color(0, 0, 0, 0)]
const ORE_COL: Dictionary = {6: Color("#1f1f24"), 7: Color("#e0a878"), 8: Color("#ffd54a"), 9: Color("#6ee7ff")}
const FACES: Array = [
	[Vector3i(0, 1, 0), [Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 1, 1), Vector3(0, 1, 1)], 1.0],
	[Vector3i(0, -1, 0), [Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 0, 0), Vector3(0, 0, 0)], 0.55],
	[Vector3i(1, 0, 0), [Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(1, 1, 1), Vector3(1, 0, 1)], 0.8],
	[Vector3i(-1, 0, 0), [Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(0, 1, 0), Vector3(0, 0, 0)], 0.75],
	[Vector3i(0, 0, 1), [Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(0, 1, 1), Vector3(0, 0, 1)], 0.85],
	[Vector3i(0, 0, -1), [Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 0, 0)], 0.7],
]

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
var _chunks: Dictionary = {}
var _mat: StandardMaterial3D
var _atlas: ImageTexture
var _highlight: MeshInstance3D
var _sun: DirectionalLight3D
var _hud_root: Control
var _info: Label
var _goal_lbl: Label
var _bar: Control
var _hotbar: HBoxContainer
var _craft_panel: PanelContainer
var _craft_list: VBoxContainer
var _cross: Control
var _selected: String = ""
var _inv_sig: String = ""
var _bot: bool = false
var _t: float = 0.0
var _save_t: float = 0.0
var _ver: int = 0
var _move_id: int = -1
var _move_o: Vector2 = Vector2.ZERO
var _move_v: Vector2 = Vector2.ZERO
var _look_id: int = -1
var _look_last: Vector2 = Vector2.ZERO
var _look_start: Vector2 = Vector2.ZERO
var _look_t: float = 0.0
var _look_moved: float = 0.0
var _hold_cell: Vector3i = Vector3i(-1, -1, -1)
var _jump_btn: Button
var _jump_held: bool = false
var _hit_sfx: float = 0.0


func _ready() -> void:
	level = Kit.current_level()
	par = float(level.get("par", 240))
	_font = UI.theme.get_font("font", "Label") if UI.theme != null else ThemeDB.fallback_font
	_build_world_env()
	_reset()
	_build_hud()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "voxel", "goal": str(st["goal_item"])})


func bot_script() -> String:
	return "res://qa/voxel_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(1.2, 1.6)


func wants_backdrop() -> bool:
	return false


func _reset() -> void:
	finished = false
	failed = false
	st = V.new_state(level)
	if not UI.test_mode:
		var saved: Variant = Save.meta().get(SAVE_KEY, {})
		if saved is Dictionary:
			V.load_into(st, saved as Dictionary)
	coins_total = int(st["goal_n"])
	coins = 0
	time_in_level = 0.0
	_build_all_chunks()
	_refresh()


func _persist() -> void:
	if UI.test_mode or st.is_empty():
		return
	Save.meta()[SAVE_KEY] = V.save_data(st)
	Save.save_data()


func item_name(id: String) -> String:
	return Kit.text("sb_i_" + id, str(NAMES.get(id, id)))


# ------------------------------------------------------------------ mundo 3D

func _build_world_env() -> void:
	var sky_col: Color = Color("#7ec8f0")
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky_mat: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#3f8fd9")
	sky_mat.sky_horizon_color = sky_col.lightened(0.3)
	sky_mat.ground_horizon_color = sky_col.lightened(0.3)
	sky_mat.ground_bottom_color = Color("#2a3a2a")
	var sky: Sky = Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.35
	env.fog_enabled = false
	env.fog_light_color = sky_col.lightened(0.3)
	env.fog_density = 0.008
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 0.95
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	_sun.light_energy = 0.75
	_sun.shadow_enabled = false
	add_child(_sun)
	_camera = Camera3D.new()
	_camera.fov = 72.0
	_camera.near = 0.05
	_camera.far = 120.0
	add_child(_camera)
	_camera.make_current()
	_atlas = _make_atlas()
	_mat = StandardMaterial3D.new()
	_mat.albedo_texture = _atlas
	_mat.vertex_color_use_as_albedo = true
	_mat.vertex_color_is_srgb = true
	_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_mat.roughness = 1.0
	## Sin luces dinamicas (como el clasico y mas ligero en el movil): la sombra de cada cara va
	## en el color de sus vertices, y bajo tierra todo se oscurece.
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_highlight = MeshInstance3D.new()
	_highlight.mesh = _box_lines()
	var hm: StandardMaterial3D = StandardMaterial3D.new()
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.albedo_color = Color(1, 1, 1, 0.9)
	_highlight.material_override = hm
	_highlight.visible = false
	add_child(_highlight)


## Textura de los cubos (16x16 por cubo, hecha aqui): motas, vetas de mineral, hierba arriba y
## anillos en el tronco. Celdas: 0-13 los cubos y 14 hierba de arriba, 15 tronco de arriba.
func _make_atlas() -> ImageTexture:
	var img: Image = Image.create(16 * 16, 16, false, Image.FORMAT_RGBA8)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 42
	for tile: int in 16:
		var base: Color = Color.WHITE
		if tile < BLOCK_COL.size():
			base = BLOCK_COL[tile]
		if tile == 14:
			base = Color("#5cb84a")
		elif tile == 15:
			base = Color("#c99a5e")
		elif tile == S.TORCH:
			base = Color("#ffb340")
		for y: int in 16:
			for x: int in 16:
				var c: Color = base.darkened(rng.randf_range(0.0, 0.16))
				if tile == S.GRASS and y < 4 + (x * 7 % 3):
					c = Color("#5cb84a").darkened(rng.randf_range(0.0, 0.15))
				if ORE_COL.has(tile) and (x * 13 + y * 7) % 11 < 2 and x % 5 != 0:
					c = ORE_COL[tile]
				if tile == S.PLANKS and y % 5 == 4:
					c = base.darkened(0.3)
				if tile == S.LOG and x % 4 == 1:
					c = base.darkened(0.3)
				if tile == 15 and absi(Vector2i(x - 8, y - 8).length_squared() - 30) < 8:
					c = base.darkened(0.35)
				if tile == S.LEAVES and rng.randf() < 0.18:
					c = base.lightened(0.25)
				img.set_pixel(tile * 16 + x, y, c)
	return ImageTexture.create_from_image(img)


func _tile_for(id: int, face: int) -> int:
	if id == S.GRASS:
		return 14 if face == 0 else (S.DIRT if face == 1 else S.GRASS)
	if id == S.LOG and face < 2:
		return 15
	return id


func _build_all_chunks() -> void:
	for k: Variant in _chunks:
		(_chunks[k] as MeshInstance3D).queue_free()
	_chunks.clear()
	for cz: int in ceili(float(V.Z) / float(CHUNK)):
		for cx: int in ceili(float(V.X) / float(CHUNK)):
			_build_chunk(Vector2i(cx, cz))


func _see_through(id: int) -> bool:
	return id == S.AIR or id == S.TORCH or id == S.LEAVES


## Malla de un trozo del mundo: solo las caras que dan al aire (o a hojas).
func _build_chunk(c: Vector2i) -> void:
	var stool: SurfaceTool = SurfaceTool.new()
	stool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any: bool = false
	for y: int in V.Y:
		for z: int in range(c.y * CHUNK, mini(V.Z, (c.y + 1) * CHUNK)):
			for x: int in range(c.x * CHUNK, mini(V.X, (c.x + 1) * CHUNK)):
				var id: int = V.at(st, x, y, z)
				if id == S.AIR:
					continue
				var small: bool = id == S.TORCH
				for f: int in FACES.size():
					var fd: Array = FACES[f]
					var nrm: Vector3i = fd[0]
					var nb: int = V.at(st, x + nrm.x, y + nrm.y, z + nrm.z) if y + nrm.y < V.Y else S.AIR
					if not small and not _see_through(nb) and nb != S.AIR:
						continue
					if id == S.LEAVES and nb == S.LEAVES:
						continue
					any = true
					var tile: int = _tile_for(id, f)
					var shade: float = float(fd[2])
					var deep: int = int((st["height"] as PackedInt32Array)[z * V.X + x]) - y
					if deep > 1:
						shade *= clampf(1.0 - 0.09 * float(deep), 0.35, 1.0)
					var col: Color = Color(shade, shade, shade)
					if id == S.TORCH:
						col = Color(1.6, 1.4, 1.0)
					var corners: Array = fd[1]
					var uvs: Array[Vector2] = [Vector2(0, 1), Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)]
					var pts: Array[Vector3] = []
					for v: Vector3 in corners:
						if small:
							pts.append(Vector3(x, y, z) + Vector3(0.42, 0.0, 0.42) + v * Vector3(0.16, 0.7, 0.16))
						else:
							pts.append(Vector3(x, y, z) + v)
					for k: int in [0, 1, 2, 0, 2, 3]:
						stool.set_color(col)
						stool.set_normal(Vector3(nrm))
						stool.set_uv(Vector2((float(tile) + uvs[k].x) / 16.0, uvs[k].y))
						stool.add_vertex(pts[k])
	var mi: MeshInstance3D = _chunks.get(c, null)
	if mi == null:
		mi = MeshInstance3D.new()
		mi.name = "Chunk_%d_%d" % [c.x, c.y]
		add_child(mi)
		_chunks[c] = mi
	if any:
		var mesh: ArrayMesh = stool.commit()
		mesh.surface_set_material(0, _mat)
		mi.mesh = mesh
	else:
		mi.mesh = null


func _box_lines() -> ImmediateMesh:
	var m: ImmediateMesh = ImmediateMesh.new()
	m.surface_begin(Mesh.PRIMITIVE_LINES)
	var e: float = 0.01
	var a: Vector3 = Vector3(-e, -e, -e)
	var b: Vector3 = Vector3(1 + e, 1 + e, 1 + e)
	var cs: Array[Vector3] = [Vector3(a.x, a.y, a.z), Vector3(b.x, a.y, a.z), Vector3(b.x, a.y, b.z), Vector3(a.x, a.y, b.z),
		Vector3(a.x, b.y, a.z), Vector3(b.x, b.y, a.z), Vector3(b.x, b.y, b.z), Vector3(a.x, b.y, b.z)]
	for pr: Array in [[0, 1], [1, 2], [2, 3], [3, 0], [4, 5], [5, 6], [6, 7], [7, 4], [0, 4], [1, 5], [2, 6], [3, 7]]:
		m.surface_add_vertex(cs[pr[0]])
		m.surface_add_vertex(cs[pr[1]])
	m.surface_end()
	return m


func _rebuild_changed() -> void:
	var ch: Array = st["changed"]
	if ch.is_empty():
		return
	var todo: Dictionary = {}
	for c: Vector3i in ch:
		for d: Vector2i in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = Vector2i((c.x + d.x) / CHUNK, (c.z + d.y) / CHUNK)
			if c.x + d.x >= 0 and c.z + d.y >= 0 and c.x + d.x < V.X and c.z + d.y < V.Z:
				todo[q] = true
	ch.clear()
	for q: Vector2i in todo:
		_build_chunk(q)


# ------------------------------------------------------------------ interfaz

func _build_hud() -> void:
	var hud: CanvasLayer = CanvasLayer.new()
	hud.name = "Hud"
	hud.layer = 20
	add_child(hud)
	var root: Control = Control.new()
	root.theme = UI.theme
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(root)
	_hud_root = root
	_cross = Control.new()
	_cross.name = "Cross"
	_cross.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cross.draw.connect(_draw_cross)
	root.add_child(_cross)
	_jump_btn = UI.make_button(Kit.text("vx_jump", "Saltar"), true)
	_jump_btn.name = "BtnJump"
	_jump_btn.custom_minimum_size = Vector2(170, 130)
	_jump_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_jump_btn.offset_left = -210.0
	_jump_btn.offset_top = -230.0
	_jump_btn.offset_right = -36.0
	_jump_btn.offset_bottom = -90.0
	_jump_btn.button_down.connect(func() -> void: _jump_held = true)
	_jump_btn.button_up.connect(func() -> void: _jump_held = false)
	root.add_child(_jump_btn)
	var safe: MarginContainer = UI.safe_root(root, 14.0)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col: VBoxContainer = VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 8)
	safe.add_child(col)
	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top)
	_bar = Control.new()
	_bar.name = "Bar"
	_bar.custom_minimum_size = Vector2(220, 84)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.draw.connect(_draw_bar)
	top.add_child(_bar)
	var mid: VBoxContainer = VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(mid)
	_goal_lbl = _label(26)
	_goal_lbl.name = "Goal"
	_goal_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	## Un texto largo se recorta y no empuja el boton de pausa fuera de la pantalla.
	_goal_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	mid.add_child(_goal_lbl)
	_info = _label(22)
	_info.name = "Info"
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_info.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_info.modulate = Color(1, 1, 1, 0.85)
	mid.add_child(_info)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)
	## Barra de objetos: tocar uno lo elige (los bloques se ponen tocando un hueco; la manzana se come).
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	var craft_btn: Button = UI.make_button(Kit.text("sb_craft", "Fabricar"), true)
	craft_btn.name = "BtnCraft"
	craft_btn.custom_minimum_size = Vector2(170, 84)
	craft_btn.add_theme_font_size_override("font_size", 26)
	craft_btn.pressed.connect(_toggle_craft)
	row.add_child(craft_btn)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 90)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(scroll)
	_hotbar = HBoxContainer.new()
	_hotbar.add_theme_constant_override("separation", 6)
	scroll.add_child(_hotbar)
	## Menu de fabricar (encima de todo).
	_craft_panel = PanelContainer.new()
	_craft_panel.name = "CraftPanel"
	_craft_panel.visible = false
	_craft_panel.set_anchors_preset(Control.PRESET_CENTER)
	_craft_panel.custom_minimum_size = Vector2(640, 860)
	_craft_panel.position = Vector2(40, 210)
	root.add_child(_craft_panel)
	var pc: VBoxContainer = VBoxContainer.new()
	pc.add_theme_constant_override("separation", 10)
	_craft_panel.add_child(pc)
	var head: HBoxContainer = HBoxContainer.new()
	pc.add_child(head)
	var title: Label = _label(34)
	title.text = Kit.text("sb_craft", "Fabricar")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close: Button = UI.make_button(Kit.text("sb_close", "Cerrar"))
	close.name = "BtnCloseCraft"
	close.custom_minimum_size = Vector2(170, 80)
	close.pressed.connect(_toggle_craft)
	head.add_child(close)
	var sc2: ScrollContainer = ScrollContainer.new()
	sc2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc2.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pc.add_child(sc2)
	_craft_list = VBoxContainer.new()
	_craft_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_craft_list.add_theme_constant_override("separation", 8)
	sc2.add_child(_craft_list)
	_refresh()


func _label(size_px: int) -> Label:
	var l: Label = Label.new()
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _refresh() -> void:
	if st.is_empty() or _goal_lbl == null:
		return
	var g: String = str(st["goal_item"])
	var got: int = mini(int((st["got"] as Dictionary).get(g, 0)), int(st["goal_n"]))
	coins = got
	_goal_lbl.text = "%s: %s %d/%d" % [Kit.text("sb_goal", "Meta"), item_name(g), got, int(st["goal_n"])]
	var nxt: Array = MapRules.bot_goal(st)
	var hint: String = ""
	if nxt.size() == 2 and str(nxt[0]) == "craft":
		hint = Kit.text("sb_hint_craft", "Ya puedes fabricar: %s") % item_name(str(nxt[1]))
	elif nxt.size() == 2 and str(nxt[0]) == "gather":
		hint = Kit.text("sb_hint_get", "Busca: %s") % item_name(str(nxt[1]))
	elif nxt.size() == 2 and str(nxt[0]) == "hunt":
		hint = Kit.text("sb_hint_hunt", "Espera a la noche y lucha")
	_info.text = hint
	## La barra solo se rehace si cambia el inventario.
	var sig: String = JSON.stringify(st["inv"]) + _selected
	if sig != _inv_sig:
		_inv_sig = sig
		_rebuild_hotbar()
	if _bar != null:
		_bar.queue_redraw()


func _rebuild_hotbar() -> void:
	for c: Node in _hotbar.get_children():
		c.queue_free()
	var inv: Dictionary = st["inv"]
	var order: Array = []
	for k: String in MapRules.PLACE:
		if inv.has(k):
			order.append(k)
	if inv.has("manzana"):
		order.append("manzana")
	for k2: String in inv:
		if not order.has(k2):
			order.append(k2)
	if _selected != "" and not inv.has(_selected):
		_selected = ""
	for id: String in order:
		var b: Button = Button.new()
		b.name = "Item_" + id
		b.custom_minimum_size = Vector2(84, 84)
		b.toggle_mode = true
		b.button_pressed = id == _selected
		b.tooltip_text = item_name(id)
		var item: String = id
		b.draw.connect(func() -> void:
			_draw_icon(b, item, Rect2(Vector2(12, 8), Vector2(60, 60)))
			b.draw_string(_font, Vector2(8, 80), str(MapRules.have(st, item)), HORIZONTAL_ALIGNMENT_RIGHT, 70.0, 22, Color.WHITE))
		b.pressed.connect(func() -> void: _pick(item))
		_hotbar.add_child(b)


func _pick(id: String) -> void:
	if id == "manzana":
		if MapRules.eat(st):
			_sfx("powerup")
			UI.float_text(_hud_root, _mid() - Vector2(0, 50), "+4", Color("#ff6b6b"), 30)
		_inv_sig = ""
		_refresh()
		return
	_selected = "" if _selected == id or not MapRules.PLACE.has(id) else id
	_inv_sig = ""
	_refresh()


func _toggle_craft() -> void:
	_craft_panel.visible = not _craft_panel.visible
	if _craft_panel.visible:
		_fill_craft()
		UI.pop_in(_craft_panel)


func _fill_craft() -> void:
	for c: Node in _craft_list.get_children():
		c.queue_free()
	var goal: String = str(st["goal_item"])
	for id: String in MapRules.RECIPES:
		var r: Dictionary = MapRules.RECIPES[id]
		var row: PanelContainer = PanelContainer.new()
		row.name = "Recipe_" + id
		var hb: HBoxContainer = HBoxContainer.new()
		hb.add_theme_constant_override("separation", 12)
		row.add_child(hb)
		var ic: Control = Control.new()
		ic.custom_minimum_size = Vector2(72, 72)
		var item: String = id
		ic.draw.connect(func() -> void: _draw_icon(ic, item, Rect2(Vector2(6, 6), Vector2(60, 60))))
		hb.add_child(ic)
		var tx: VBoxContainer = VBoxContainer.new()
		tx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(tx)
		var nm: Label = Label.new()
		nm.text = item_name(id) + ("  x%d" % int(r["out"]) if int(r["out"]) > 1 else "")
		nm.add_theme_font_size_override("font_size", 26)
		if id == goal:
			nm.add_theme_color_override("font_color", Color("#ffd54a"))
		tx.add_child(nm)
		var parts: Array[String] = []
		for k: String in r["in"]:
			parts.append("%d %s" % [int(r["in"][k]), item_name(k).to_lower()])
		if str(r["at"]) != "":
			parts.append(Kit.text("sb_at", "en: %s") % item_name(str(r["at"])).to_lower())
		var ing: Label = Label.new()
		ing.text = ", ".join(parts)
		ing.add_theme_font_size_override("font_size", 20)
		ing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ing.modulate = Color(1, 1, 1, 0.75)
		tx.add_child(ing)
		var mk: Button = UI.make_button(Kit.text("sb_make", "Hacer"), MapRules.can_craft(st, id))
		mk.name = "Make_" + id
		mk.custom_minimum_size = Vector2(130, 76)
		mk.disabled = not MapRules.can_craft(st, id)
		mk.pressed.connect(func() -> void: _craft(item))
		hb.add_child(mk)
		_craft_list.add_child(row)


func _craft(id: String) -> void:
	if not MapRules.craft(st, id):
		return
	_sfx("powerup")
	Juice.vibrate(20)
	UI.float_text(_hud_root, _mid() - Vector2(0, 60), "+%d %s" % [int(MapRules.RECIPES[id]["out"]), item_name(id)], Color("#ffd54a"), 28)
	_fill_craft()
	_refresh()
	_check_end()


# ------------------------------------------------------------------ acciones


# ------------------------------------------------------------------ acciones

func can_act() -> bool:
	return not finished and is_inside_tree() and not get_tree().paused


func bot_step() -> void:
	_bot = true


func _sfx(n: String, vol: float = -10.0) -> void:
	if not fast:
		Audio.play(n, 0.1, vol)


func _check_end() -> void:
	if bool(st["won"]):
		_finish()
	elif bool(st["dead"]):
		_lose()


func _mid() -> Vector2:
	return get_viewport().get_visible_rect().size * 0.5


# ------------------------------------------------------------------ bucle

func _physics_process(delta: float) -> void:
	_t += delta
	_hit_sfx -= delta
	if finished:
		return
	if fast and auto_retry:
		_bot = true
	var steps: int = 4 if fast else 1
	for k: int in steps:
		if finished or get_tree().paused:
			break
		var inp: Dictionary = {}
		if _bot:
			V.bot_control(st)
			inp = st["in"]
		else:
			var mv: Vector2 = _move_v
			var keys: Vector2 = Input.get_vector("move_left", "move_right", "move_down", "move_up")
			if keys.length() > 0.1:
				mv = keys
			inp = {"move": mv, "jump": _jump_held or Input.is_action_pressed("jump")}
			_update_hold(delta)
		var was_floor: bool = bool(st["on_floor"])
		V.step(st, inp, delta)
		if bool(inp.get("jump", false)) and was_floor and not bool(st["on_floor"]):
			_sfx("jump", -16.0)
		time_in_level += delta
		_after_step()
	_save_t += delta
	if _save_t > 15.0:
		_save_t = 0.0
		_persist()
	_place_camera()
	_rebuild_changed()
	_update_highlight()


func _place_camera() -> void:
	_camera.position = V.eye(st)
	_camera.rotation = Vector3(float(st["pitch"]), float(st["yaw"]), 0.0)


## Picar mientras se mantiene el dedo quieto: el rayo sale por donde esta el dedo.
func _update_hold(delta: float) -> void:
	st["mine_target"] = Vector3i(-1, -1, -1)
	if _look_id < 0:
		return
	_look_t += delta
	if _look_t < 0.25 or _look_moved > 40.0:
		return
	var hit: Dictionary = _ray_at(_look_last)
	if not hit.is_empty():
		_hold_cell = hit["cell"]
		st["mine_target"] = _hold_cell


func _ray_at(sp: Vector2) -> Dictionary:
	if _camera == null:
		return {}
	return V.raycast(st, V.eye(st), _camera.project_ray_normal(sp))


func _update_highlight() -> void:
	if fast:
		_highlight.visible = false
		return
	var hit: Dictionary = V.raycast(st, V.eye(st), -_camera.global_transform.basis.z)
	var mc: Vector3i = st["mine_cell"]
	if mc.x >= 0:
		hit = {"cell": mc}
	_highlight.visible = not hit.is_empty()
	if _highlight.visible:
		var c: Vector3i = hit["cell"]
		_highlight.position = Vector3(c)
		## Al picar, el contorno se encoge y late: se ve cuanto falta.
		var pr: float = 0.0
		if mc.x >= 0:
			pr = clampf(float(st["mine_t"]) / maxf(0.05, V.mine_time(st, V.at(st, mc.x, mc.y, mc.z))), 0.0, 1.0)
		var s: float = 1.0 - 0.12 * pr
		_highlight.scale = Vector3(s, s, s)
		_highlight.position += Vector3.ONE * (1.0 - s) * 0.5
		(_highlight.material_override as StandardMaterial3D).albedo_color = Color(1, 1.0 - pr * 0.6, 1.0 - pr * 0.8, 0.9)


func _after_step() -> void:
	var broke: Array = st["broke"]
	if not broke.is_empty():
		for b: Array in broke:
			var drop: String = str(S.BLOCKS[int(b[1])]["drop"])
			if drop != "" and not fast:
				UI.float_text(_hud_root, _mid() + Vector2(0, -60), "+1 " + item_name(drop), Color.WHITE, 26)
			if not fast:
				_burst3d(Vector3(b[0] as Vector3i) + Vector3(0.5, 0.5, 0.5), int(b[1]))
		broke.clear()
		_sfx("coin", -14.0)
		Juice.vibrate(8)
		_refresh()
	elif int(st.get("ver", 0)) != _ver:
		_refresh()
	_ver = int(st.get("ver", 0))
	if (st["mine_cell"] as Vector3i).x >= 0 and _hit_sfx <= 0.0:
		_hit_sfx = 0.22
		_sfx("click", -20.0)
	## Bajo tierra, la musica se apaga un poco.
	var f: Vector3i = V.feet(st)
	var surf: int = int((st["height"] as PackedInt32Array)[clampi(f.z, 0, V.Z - 1) * V.X + clampi(f.x, 0, V.X - 1)])
	Audio.set_intensity(0.5 if f.y < surf - 2 else 0.85)
	_check_end()


## Trocitos del cubo roto (cubos pequenos que saltan y caen).
func _burst3d(at_p: Vector3, id: int) -> void:
	var col: Color = BLOCK_COL[id] if id < BLOCK_COL.size() else Color.GRAY
	if ORE_COL.has(id):
		col = ORE_COL[id]
	if id == S.GRASS:
		col = Color("#5cb84a")
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = col
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(0.14, 0.14, 0.14)
	for n: int in 8:
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mat
		mi.position = at_p + Vector3(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3), randf_range(-0.3, 0.3))
		add_child(mi)
		var to: Vector3 = mi.position + Vector3(randf_range(-0.6, 0.6), randf_range(-0.9, -0.3), randf_range(-0.6, 0.6))
		var tw: Tween = mi.create_tween()
		tw.tween_property(mi, "position", to, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(mi, "scale", Vector3.ONE * 0.2, 0.45)
		tw.tween_callback(mi.queue_free)


# ------------------------------------------------------------------ toques

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()
		return
	if not can_act() or _craft_panel.visible:
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
				_look_start = te.position
				_look_t = 0.0
				_look_moved = 0.0
		else:
			if te.index == _move_id:
				_move_id = -1
				_move_v = Vector2.ZERO
			elif te.index == _look_id:
				_look_id = -1
				## Toque corto sin arrastrar: poner el cubo elegido (o comer si es la manzana).
				if _look_t < 0.25 and _look_moved < 24.0:
					_tap(te.position)
				st["mine_target"] = Vector3i(-1, -1, -1)
	elif event is InputEventScreenDrag:
		var dr: InputEventScreenDrag = event
		if dr.index == _move_id:
			_move_v = ((dr.position - _move_o) / 110.0).limit_length(1.0)
			_move_v.y = -_move_v.y
		elif dr.index == _look_id:
			var d: Vector2 = dr.position - _look_last
			_look_last = dr.position
			_look_moved += d.length()
			## Mirar: arrastrar mueve la vista (menos si se esta picando).
			var sens: float = 0.0045 if _look_t < 0.25 or _look_moved > 40.0 else 0.0015
			st["yaw"] = wrapf(float(st["yaw"]) - d.x * sens, -PI, PI)
			st["pitch"] = clampf(float(st["pitch"]) - d.y * sens, -1.45, 1.45)


func _tap(sp: Vector2) -> void:
	var hit: Dictionary = _ray_at(sp)
	if hit.is_empty():
		return
	if _selected == "":
		_info.text = Kit.text("vx_hint_place", "Elige un cubo abajo para ponerlo; mant\u00e9n el dedo para picar")
		return
	var c: Vector3i = (hit["cell"] as Vector3i) + (hit["normal"] as Vector3i)
	if V.place(st, c, _selected):
		_sfx("land", -12.0)
		Juice.vibrate(10)
		_refresh()
	else:
		_sfx("ui_error", -12.0)


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	coins = coins_total
	_persist()
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = maxi(1, 10000 - int(time_in_level) * 10)
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "time": snappedf(time_in_level, 0.1), "deaths": deaths})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


func stars_earned() -> int:
	if deaths > 0:
		return 1
	return 3 if par <= 0.0 or time_in_level <= par else 2


func _lose() -> void:
	if finished:
		return
	finished = true
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "fall", "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("vx_lost", "\u00a1Te has ca\u00eddo!"),
		Kit.text("vx_fail_hint", "Pica con cuidado bajo tus pies. Lo que llevabas sigue contigo."))
	p.closed.connect(retry)


func retry() -> void:
	finished = false
	failed = false
	V.respawn(st)
	_refresh()


func open_pause() -> void:
	if finished or get_tree().paused or get_node_or_null("PauseMenu") != null:
		return
	_persist()
	PauseMenu.open(self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_inside_tree() and not UI.test_mode:
			_persist()
			open_pause()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		_persist()


func bot_state() -> Dictionary:
	var g: String = str(st.get("goal_item", ""))
	return {"pos": st.get("p", Vector3.ZERO), "deaths": deaths, "coins": coins, "finished": finished, "failed": failed,
		"time": time_in_level, "got": int((st.get("got", {}) as Dictionary).get(g, 0))}


# ------------------------------------------------------------------ dibujo de la interfaz

func _draw_bar() -> void:
	if st.is_empty():
		return
	for k: int in S.MAX_HP / 2:
		var c: Vector2 = Vector2(22.0 + float(k) * 40.0, 24.0)
		var full: int = clampi(int(st["hp"]) - k * 2, 0, 2)
		_heart(c, Color(0, 0, 0, 0.5), 1.15)
		if full > 0:
			_heart(c, Color("#ff4d5e") if full == 2 else Color("#ff9aa5"), 1.0)
	## Altura: lo hondo que estas (las vetas buenas estan abajo).
	var f: Vector3i = V.feet(st)
	_bar.draw_string(_font, Vector2(6.0, 76.0), Kit.text("vx_depth", "Altura %d") % f.y, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)


func _heart(c: Vector2, col: Color, sc: float) -> void:
	var r: float = 9.0 * sc
	_bar.draw_circle(c + Vector2(-r * 0.55, -r * 0.2), r * 0.62, col)
	_bar.draw_circle(c + Vector2(r * 0.55, -r * 0.2), r * 0.62, col)
	_bar.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 1.15, 0), c + Vector2(r * 1.15, 0), c + Vector2(0, r * 1.2)]), col)


## Mando, punto de mira y boton de saltar (encima de la vista 3D).
func _draw_cross() -> void:
	var size: Vector2 = _cross.size
	var m: Vector2 = size * 0.5
	_cross.draw_line(m - Vector2(14, 0), m + Vector2(14, 0), Color(1, 1, 1, 0.85), 3.0)
	_cross.draw_line(m - Vector2(0, 14), m + Vector2(0, 14), Color(1, 1, 1, 0.85), 3.0)
	if _move_id < 0 and not _bot:
		## Pista del mando cuando no se toca: aqui se anda.
		var home: Vector2 = Vector2(170.0, size.y - 300.0)
		_cross.draw_arc(home, 90.0, 0.0, TAU, 40, Color(1, 1, 1, 0.22), 3.0)
		_cross.draw_circle(home, 36.0, Color(1, 1, 1, 0.16))
	if _move_id >= 0:
		_cross.draw_circle(_move_o, 110.0, Color(1, 1, 1, 0.12))
		_cross.draw_arc(_move_o, 110.0, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 3.0)
		_cross.draw_circle(_move_o + Vector2(_move_v.x, -_move_v.y) * 110.0, 44.0, Color(1, 1, 1, 0.45))
	if _look_id >= 0 and _look_t >= 0.25 and _look_moved <= 40.0:
		var pr: float = clampf((_look_t - 0.25) / 1.2, 0.0, 1.0)
		_cross.draw_arc(_look_last, 46.0, -PI * 0.5, -PI * 0.5 + TAU * pr, 32, Color("#ffd54a"), 6.0)


func _process(_delta: float) -> void:
	if _cross != null:
		_cross.queue_redraw()


# ------------------------------------------------------------------ iconos (como en 2D)

func _hash(x: int, y: int) -> int:
	return absi((x * 73856093) ^ (y * 19349663)) % 1000


func _draw_block(ci: CanvasItem, id: int, r: Rect2, x: int, y: int) -> void:
	var col: Color = BLOCK_COL[id]
	match id:
		MapRules.GRASS:
			ci.draw_rect(r, col)
			ci.draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.28)), Color("#5cb84a"))
			ci.draw_rect(Rect2(r.position + Vector2(0, r.size.y * 0.28), Vector2(r.size.x, r.size.y * 0.08)), Color("#3f8a36"))
		MapRules.LOG:
			ci.draw_rect(Rect2(r.position + Vector2(r.size.x * 0.18, 0), Vector2(r.size.x * 0.64, r.size.y)), col)
			ci.draw_rect(Rect2(r.position + Vector2(r.size.x * 0.32, 0), Vector2(r.size.x * 0.08, r.size.y)), col.darkened(0.25))
			ci.draw_rect(Rect2(r.position + Vector2(r.size.x * 0.6, 0), Vector2(r.size.x * 0.06, r.size.y)), col.darkened(0.2))
			return
		MapRules.LEAVES:
			ci.draw_rect(r.grow(2.0), col * Color(1, 1, 1, 0.92))
			for k: int in 3:
				var h: int = _hash(x * 3 + k, y)
				ci.draw_circle(r.position + Vector2(float(h % 37) + 2.0, float((h / 37) % 37) + 2.0) * r.size.x / 40.0, r.size.x * 0.12, col.lightened(0.18))
			return
		MapRules.PLANKS:
			ci.draw_rect(r, col)
			for k2: int in 3:
				ci.draw_line(r.position + Vector2(0, r.size.y * (0.33 * float(k2) + 0.3)), r.position + Vector2(r.size.x, r.size.y * (0.33 * float(k2) + 0.3)), col.darkened(0.25), 2.0)
			return
		MapRules.TORCH:
			ci.draw_rect(Rect2(r.position + Vector2(r.size.x * 0.44, r.size.y * 0.35), Vector2(r.size.x * 0.12, r.size.y * 0.65)), Color("#8b5e34"))
			var fl: float = 0.85 + 0.15 * sin(_t * 12.0 + float(x))
			ci.draw_circle(r.position + Vector2(r.size.x * 0.5, r.size.y * 0.3), r.size.x * 0.16 * fl, Color("#ffb340"))
			ci.draw_circle(r.position + Vector2(r.size.x * 0.5, r.size.y * 0.3), r.size.x * 0.08, Color("#fff3b0"))
			return
		_:
			ci.draw_rect(r, col)
	## Textura: motas con la semilla de la celda (las del mineral, con su color).
	var dots: int = 4 if ORE_COL.has(id) else 2
	for k3: int in dots:
		var h2: int = _hash(x + k3 * 7, y + k3 * 13)
		var pos: Vector2 = r.position + Vector2(float(h2 % 31) + 4.0, float((h2 / 31) % 31) + 4.0) * r.size.x / 40.0
		if ORE_COL.has(id):
			ci.draw_rect(Rect2(pos, Vector2(r.size.x * 0.2, r.size.y * 0.2)), ORE_COL[id])
		else:
			ci.draw_rect(Rect2(pos, Vector2(r.size.x * 0.1, r.size.y * 0.1)), col.darkened(0.18))
	if id == MapRules.CRYSTAL:
		ci.draw_rect(r.grow(-r.size.x * 0.35), Color(0.6, 1, 1, 0.5 + 0.3 * sin(_t * 3.0 + float(x + y))))


func _draw_icon(ci: CanvasItem, id: String, r: Rect2) -> void:
	if MapRules.PLACE.has(id) and id != "antorcha":
		_draw_block(ci, int(MapRules.PLACE[id]), r, 3, 5)
		return
	var c: Vector2 = r.get_center()
	var s: float = r.size.x
	var mat: Color = Color("#c08a4f")
	if id.ends_with("piedra"):
		mat = Color("#9aa3ad")
	elif id.ends_with("hierro"):
		mat = Color("#e6e9ee")
	match id:
		"tronco":
			ci.draw_rect(Rect2(c - Vector2(s * 0.3, s * 0.4), Vector2(s * 0.6, s * 0.8)), Color("#8b5e34"))
			ci.draw_circle(c - Vector2(0, s * 0.4), s * 0.3, Color("#d9a86a"))
		"palos":
			ci.draw_line(c + Vector2(-s * 0.3, s * 0.35), c + Vector2(s * 0.3, -s * 0.35), Color("#8b5e34"), s * 0.12)
		"mesa":
			ci.draw_rect(Rect2(c - Vector2(s * 0.42, s * 0.3), Vector2(s * 0.84, s * 0.2)), Color("#c08a4f"))
			ci.draw_rect(Rect2(c + Vector2(-s * 0.36, -s * 0.1), Vector2(s * 0.12, s * 0.45)), Color("#8b5e34"))
			ci.draw_rect(Rect2(c + Vector2(s * 0.24, -s * 0.1), Vector2(s * 0.12, s * 0.45)), Color("#8b5e34"))
		"horno":
			ci.draw_rect(Rect2(c - Vector2(s * 0.4, s * 0.4), Vector2(s * 0.8, s * 0.8)), Color("#6d737c"))
			ci.draw_rect(Rect2(c + Vector2(-s * 0.2, 0), Vector2(s * 0.4, s * 0.25)), Color("#ff7a2a"))
		"carbon", "hierro", "oro", "cristal":
			var oc: Color = {"carbon": Color("#2a2a30"), "hierro": Color("#e0a878"), "oro": Color("#ffd54a"), "cristal": Color("#6ee7ff")}[id]
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.38), c + Vector2(s * 0.34, 0), c + Vector2(0, s * 0.38), c + Vector2(-s * 0.34, 0)]), oc)
			ci.draw_line(c + Vector2(-s * 0.12, -s * 0.12), c + Vector2(0, -s * 0.24), Color(1, 1, 1, 0.6), 3.0)
		"lingote_hierro", "lingote_oro":
			var ic: Color = Color("#e6e9ee") if id == "lingote_hierro" else Color("#ffd54a")
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.42, s * 0.2), c + Vector2(s * 0.42, s * 0.2), c + Vector2(s * 0.28, -s * 0.15), c + Vector2(-s * 0.28, -s * 0.15)]), ic)
			ci.draw_line(c + Vector2(-s * 0.2, -s * 0.05), c + Vector2(s * 0.1, -s * 0.05), Color(1, 1, 1, 0.7), 3.0)
		"antorcha":
			ci.draw_rect(Rect2(c + Vector2(-s * 0.06, -s * 0.1), Vector2(s * 0.12, s * 0.5)), Color("#8b5e34"))
			ci.draw_circle(c + Vector2(0, -s * 0.2), s * 0.16, Color("#ffb340"))
		"manzana":
			ci.draw_circle(c + Vector2(0, s * 0.05), s * 0.32, Color("#e8483e"))
			ci.draw_line(c + Vector2(0, -s * 0.25), c + Vector2(s * 0.08, -s * 0.4), Color("#5a3a20"), 3.0)
		"corona":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.4, s * 0.25), c + Vector2(s * 0.4, s * 0.25), c + Vector2(s * 0.4, -s * 0.25),
				c + Vector2(s * 0.2, 0), c + Vector2(0, -s * 0.35), c + Vector2(-s * 0.2, 0), c + Vector2(-s * 0.4, -s * 0.25)]), Color("#ffd54a"))
			ci.draw_circle(c + Vector2(0, s * 0.1), s * 0.07, Color("#6ee7ff"))
		"monstruo":
			ci.draw_circle(c, s * 0.34, Color("#3b2a5a"))
			ci.draw_circle(c + Vector2(-s * 0.12, -s * 0.05), s * 0.07, Color("#ff5a5a"))
			ci.draw_circle(c + Vector2(s * 0.12, -s * 0.05), s * 0.07, Color("#ff5a5a"))
		_:
			if id.begins_with("pico"):
				ci.draw_line(c + Vector2(-s * 0.3, s * 0.38), c + Vector2(s * 0.12, -s * 0.1), Color("#8b5e34"), s * 0.1)
				ci.draw_arc(c + Vector2(s * 0.08, s * 0.05), s * 0.42, -PI * 0.95, -PI * 0.15, 10, mat, s * 0.13)
			elif id.begins_with("espada"):
				ci.draw_line(c + Vector2(-s * 0.32, s * 0.32), c + Vector2(s * 0.34, -s * 0.34), mat, s * 0.14)
				ci.draw_line(c + Vector2(-s * 0.32, s * 0.08), c + Vector2(-s * 0.08, s * 0.32), Color("#8b5e34"), s * 0.1)
			else:
				ci.draw_rect(r.grow(-s * 0.2), mat)
