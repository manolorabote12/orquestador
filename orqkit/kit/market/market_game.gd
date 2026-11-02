extends Node3D
## Tienda 3D (simulador tipo "idle arcade"): arrastra en cualquier sitio para andar. Pasa por las
## cajas para cargar, por las estanterias para reponer, quedate en la caja para cobrar, recoge el
## dinero y pisa los sitios con precio para abrir productos o contratar ayuda. La tienda (lo
## abierto y el dinero) sigue de un nivel al siguiente. Reglas, bot y analizador en market_map.gd.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel al acabar.

const M = preload("res://kit/market/market_map.gd")
const SAVE_KEY: String = "market_shop"
const PROD_COL: Array[Color] = [Color("#e8443a"), Color("#d9a35b"), Color("#eef3ff"), Color("#ffd23f")]
const PROD_NAMES: Array[String] = ["Fruta", "Pan", "Leche", "Queso"]
const CUST_COL: Array[Color] = [Color("#4fc3f7"), Color("#81c784"), Color("#ba68c8"), Color("#ffb74d"), Color("#f06292"), Color("#90a4ae"), Color("#aed581"), Color("#ff8a65")]

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
var _me: Node3D
var _me_stack: Node3D
var _helpers: Dictionary = {}
var _cust_nodes: Dictionary = {}
var _shelf_items: Dictionary = {}
var _locks: Dictionary = {}
var _pile: Node3D
var _hud: Control
var _money_lbl: Label
var _goal_bar: Control
var _bot: bool = false
var _t: float = 0.0
var _move_id: int = -1
var _move_o: Vector2 = Vector2.ZERO
var _move_v: Vector2 = Vector2.ZERO
var _save_t: float = 0.0
var _pick_pitch: float = 0.0


func _ready() -> void:
	level = Kit.current_level()
	par = float(level.get("par", 180))
	_font = UI.theme.get_font("font", "Label") if UI.theme != null else ThemeDB.fallback_font
	_build_env()
	_reset()
	_build_shop()
	_build_hud()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "market", "goal": int(st["goal"])})


func bot_script() -> String:
	return "res://qa/market_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(12.0, 4.0)


func wants_backdrop() -> bool:
	return false


func _reset() -> void:
	finished = false
	failed = false
	st = M.new_state(level)
	if not UI.test_mode:
		var saved: Variant = Save.meta().get(SAVE_KEY, {})
		if saved is Dictionary:
			M.load_into(st, level, saved as Dictionary)
	coins = 0
	coins_total = 0
	time_in_level = 0.0


func _persist() -> void:
	if UI.test_mode or st.is_empty():
		return
	Save.meta()[SAVE_KEY] = M.save_data(st, level)
	Save.save_data()


func prod_name(id: int) -> String:
	var names: Variant = level.get("names", [])
	if names is Array and id < (names as Array).size() and str(names[id]) != "":
		return str(names[id])
	return Kit.text("mk_p%d" % id, PROD_NAMES[id])


static func mat(col: Color, emission: float = 0.0, unshaded: bool = false) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.8
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emission
	if col.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _box(size: Vector3, col: Color, at: Vector3 = Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var b: BoxMesh = BoxMesh.new()
	b.size = size
	b.material = mat(col)
	mi.mesh = b
	mi.position = at
	(parent if parent != null else self).add_child(mi)
	return mi


static func to3(p: Vector2, y: float = 0.0) -> Vector3:
	return Vector3(p.x, y, p.y)


# ------------------------------------------------------------------ escenario

func _build_env() -> void:
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Kit.color("bg", Color("#2b3a55")).darkened(0.2)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.28
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60.0, -30.0, 0.0)
	sun.light_energy = 0.45
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	add_child(sun)
	_cam = Camera3D.new()
	_cam.fov = 50.0
	add_child(_cam)
	_cam.make_current()


func _build_shop() -> void:
	var w: int = int(st["w"])
	var h: int = int(st["h"])
	var floor_a: Color = Color("#cfc5ad")
	var floor_b: Color = floor_a.darkened(0.07)
	var wall: Color = Kit.color("accent", Color("#ff7043")).lerp(Color("#6d4c41"), 0.55)
	for y: int in h:
		for x: int in w:
			var c: String = M.cell(st, x, y)
			var at: Vector3 = Vector3(x + 0.5, 0, y + 0.5)
			if c == "#":
				_box(Vector3(1, 0.7, 1), wall, at + Vector3(0, 0.35, 0))
				continue
			_box(Vector3(1, 0.1, 1), floor_a if (x + y) % 2 == 0 else floor_b, at + Vector3(0, -0.05, 0))
			if c == "E":
				_box(Vector3(1, 0.04, 1), Color("#6d4c41"), at + Vector3(0, 0.02, 0))
	## Cajas de producto, estanterias y sitios para abrir.
	for pr: Dictionary in st["prods"]:
		var id: int = int(pr["id"])
		var col: Color = PROD_COL[id]
		var cp: Vector3 = to3(M.center(pr["crate"]))
		var crate: Node3D = Node3D.new()
		crate.position = cp
		add_child(crate)
		_box(Vector3(0.9, 0.55, 0.9), Color("#a0703d"), Vector3(0, 0.28, 0), crate)
		for k: int in 4:
			_box(Vector3(0.3, 0.22, 0.3), col, Vector3(-0.2 + 0.4 * float(k % 2), 0.66, -0.2 + 0.4 * float(k / 2)), crate)
		crate.name = "Crate%d" % id
		var sp: Vector3 = to3(M.center(pr["shelf"]))
		var shelf: Node3D = Node3D.new()
		shelf.position = sp
		shelf.name = "Shelf%d" % id
		add_child(shelf)
		_box(Vector3(0.95, 0.08, 0.7), Color("#8d99ae"), Vector3(0, 0.45, 0), shelf)
		_box(Vector3(0.95, 0.08, 0.7), Color("#8d99ae"), Vector3(0, 0.95, 0), shelf)
		_box(Vector3(0.08, 1.1, 0.7), Color("#6c7a91"), Vector3(-0.45, 0.55, 0), shelf)
		_box(Vector3(0.08, 1.1, 0.7), Color("#6c7a91"), Vector3(0.45, 0.55, 0), shelf)
		var items: Array = []
		for k2: int in M.SHELF_CAP:
			var it: MeshInstance3D = _box(Vector3(0.18, 0.2, 0.2), col, Vector3(-0.3 + 0.2 * float(k2 % 4), 0.6 + 0.5 * float(k2 / 4), 0.0), shelf)
			items.append(it)
		_shelf_items[id] = items
		_locks["p%d" % id] = _make_lock(M.stand_at(st, pr["shelf"]), int(pr["cost"]), prod_name(id), col)
	for k3: String in st["spots"]:
		var spd: Dictionary = st["spots"][k3]
		var label: String = {"S": Kit.text("mk_hire_s", "Reponedor"), "K": Kit.text("mk_hire_k", "Cajero"), "U": Kit.text("mk_upgrade", "Llevar m\u00e1s")}[k3]
		_locks[k3] = _make_lock(M.center(spd["c"]), int(spd["cost"]), label, Color("#5ad17a") if k3 != "U" else Color("#4fc3f7"))
	## Caja registradora y mont\u00f3n de dinero.
	var rp: Vector3 = to3(M.center(st["register"]))
	var reg: Node3D = Node3D.new()
	reg.name = "Register"
	reg.position = rp
	add_child(reg)
	_box(Vector3(0.95, 0.9, 0.95), Color("#455a64"), Vector3(0, 0.45, 0), reg)
	_box(Vector3(0.45, 0.3, 0.35), Color("#263238"), Vector3(0, 1.05, -0.1), reg)
	_box(Vector3(0.4, 0.05, 0.3), Color("#80deea"), Vector3(0, 1.22, -0.12), reg)
	_pile = Node3D.new()
	_pile.name = "Pile"
	_pile.position = to3(M.pile_pos(st))
	add_child(_pile)
	_me = _make_person(Kit.color("player", Color("#3fa7ff")), true)
	_me.name = "Me"
	_me_stack = Node3D.new()
	_me_stack.position = Vector3(0, 0.9, 0.35)
	_me.add_child(_me_stack)


## Sitio para pagar: cuadro en el suelo con el precio y una barra que se llena.
func _make_lock(at: Vector2, cost: int, what: String, col: Color) -> Dictionary:
	var root: Node3D = Node3D.new()
	root.position = to3(at, 0.02)
	add_child(root)
	var pad: MeshInstance3D = _box(Vector3(0.9, 0.03, 0.9), Color(col.r, col.g, col.b, 0.55), Vector3.ZERO, root)
	(pad.mesh as BoxMesh).material = mat(Color(col.r, col.g, col.b, 0.55), 0.3, true)
	var fill: MeshInstance3D = _box(Vector3(0.9, 0.04, 0.9), col, Vector3(0, 0.01, 0), root)
	(fill.mesh as BoxMesh).material = mat(col, 0.6, true)
	fill.scale = Vector3(0.001, 1, 1)
	var lbl: Label3D = Label3D.new()
	lbl.text = "%s\n%d" % [what, cost]
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.font_size = 46
	lbl.pixel_size = 0.006
	lbl.outline_size = 12
	lbl.position = Vector3(0, 0.75, 0)
	lbl.modulate = Color.WHITE
	root.add_child(lbl)
	return {"root": root, "fill": fill, "label": lbl}


func _make_person(col: Color, me: bool) -> Node3D:
	var root: Node3D = Node3D.new()
	add_child(root)
	var torso: MeshInstance3D = MeshInstance3D.new()
	var cap: CapsuleMesh = CapsuleMesh.new()
	cap.radius = 0.24
	cap.height = 0.9
	cap.material = mat(col)
	torso.mesh = cap
	torso.position = Vector3(0, 0.5, 0)
	root.add_child(torso)
	var head: MeshInstance3D = MeshInstance3D.new()
	var sp: SphereMesh = SphereMesh.new()
	sp.radius = 0.2
	sp.height = 0.4
	sp.material = mat(Color("#f2c49b"))
	head.mesh = sp
	head.position = Vector3(0, 1.12, 0)
	root.add_child(head)
	if me:
		## Gorra del tendero.
		_box(Vector3(0.42, 0.1, 0.42), Kit.color("accent", Color("#ff7043")), Vector3(0, 1.3, -0.04), root)
	return root


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
	var col: VBoxContainer = VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(col)
	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top)
	_goal_bar = Control.new()
	_goal_bar.name = "Goal"
	_goal_bar.custom_minimum_size = Vector2(0, 64)
	_goal_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_goal_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_goal_bar.draw.connect(_draw_goal)
	top.add_child(_goal_bar)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)
	var wallet: HBoxContainer = HBoxContainer.new()
	wallet.alignment = BoxContainer.ALIGNMENT_CENTER
	wallet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(wallet)
	wallet.add_child(UiIcon.make("coin", Kit.color("coin", Color("#ffd54a")), 44.0))
	_money_lbl = Label.new()
	_money_lbl.name = "Money"
	_money_lbl.add_theme_font_size_override("font_size", 44)
	_money_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_money_lbl.add_theme_constant_override("outline_size", 8)
	wallet.add_child(_money_lbl)


func _draw_goal() -> void:
	if st.is_empty():
		return
	var w: float = _goal_bar.size.x - 12.0
	var f: float = clampf(float(st["earned"]) / float(st["goal"]), 0.0, 1.0)
	var r: Rect2 = Rect2(Vector2(6, 8), Vector2(w, 24))
	_goal_bar.draw_rect(r, Color(0, 0, 0, 0.45))
	_goal_bar.draw_rect(Rect2(r.position, Vector2(w * f, 24)), Color("#5ad17a"))
	_goal_bar.draw_string(_font, Vector2(6, 58), Kit.text("mk_goal", "Ventas: %d / %d") % [int(st["earned"]), int(st["goal"])], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)


func _draw_stick() -> void:
	if _move_id >= 0:
		_hud.draw_circle(_move_o, 100.0, Color(1, 1, 1, 0.12))
		_hud.draw_arc(_move_o, 100.0, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 3.0)
		_hud.draw_circle(_move_o + _move_v * 100.0, 40.0, Color(1, 1, 1, 0.45))


# ------------------------------------------------------------------ acciones

func can_act() -> bool:
	return not finished and is_inside_tree() and not get_tree().paused


func bot_step() -> void:
	_bot = true


func _sfx(n: String, vol: float = -10.0, pitch: float = 1.0) -> void:
	if not fast:
		Audio.play(n, 0.05, vol, pitch)


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
		var mv: Vector2 = M.bot_control(st) if _bot else _move_v
		if not _bot:
			var keys: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
			if keys.length() > 0.1:
				mv = keys
		M.move_me(st, mv, delta)
		M.step(st, delta)
		time_in_level += delta
		_events()
		if bool(st["won"]):
			_finish()
			break
	_save_t += delta
	if _save_t > 10.0:
		_save_t = 0.0
		_persist()
	_sync(delta)


func _events() -> void:
	for e: Dictionary in st["events"]:
		match str(e["kind"]):
			"pick":
				_pick_pitch = minf(_pick_pitch + 0.06, 0.6)
				_sfx("ui_tick", -14.0, 0.9 + _pick_pitch)
			"stock":
				_pick_pitch = maxf(0.0, _pick_pitch - 0.06)
				_sfx("ui_pop", -14.0, 0.9 + _pick_pitch)
			"sale":
				_sfx("ui_coin", -8.0)
			"cash":
				_sfx("ui_reward", -8.0)
				Juice.vibrate(15)
				if not fast and _money_lbl != null:
					UI.pop_in(_money_lbl)
			"pay":
				_sfx("ui_tick", -18.0, 1.3)
			"unlock":
				_sfx("powerup", -6.0)
				Juice.vibrate(40)
				if not fast:
					Juice.burst(_hud, get_viewport().get_visible_rect().size * 0.5, Color("#5ad17a"), 30)
				_persist()
			"angry":
				_sfx("ui_error", -12.0)
	(st["events"] as Array).clear()


## Lo que se ve: el tendero con su pila, clientes con lo que quieren, estanterias, dinero y sitios.
func _sync(delta: float) -> void:
	var me: Dictionary = st["me"]
	var p: Vector2 = me["p"]
	_me.position = to3(p)
	var dir: Vector2 = me.get("dir", Vector2(0, 1))
	_me.rotation.y = lerp_angle(_me.rotation.y, atan2(-dir.x, -dir.y), minf(1.0, delta * 14.0))
	_sync_stack(_me_stack, me["carry"])
	## Ayudantes.
	for k: String in st["helpers"]:
		var hd: Dictionary = st["helpers"][k]
		if not _helpers.has(k):
			var node: Node3D = _make_person(Color("#5ad17a") if k == "S" else Color("#ffd23f"), false)
			var stack: Node3D = Node3D.new()
			stack.position = Vector3(0, 0.9, 0.35)
			node.add_child(stack)
			_helpers[k] = {"node": node, "stack": stack}
		var hn: Dictionary = _helpers[k]
		var hp: Vector2 = hd["p"] if k == "S" else M.cashier_pos(st)
		(hn["node"] as Node3D).position = to3(hp)
		var hdir: Vector2 = hd.get("dir", Vector2(0, 1))
		(hn["node"] as Node3D).rotation.y = atan2(-hdir.x, -hdir.y) if k == "S" else PI
		_sync_stack(hn["stack"], hd["carry"])
	## Clientes.
	var seen: Dictionary = {}
	for c: Dictionary in st["customers"]:
		var cid: int = int(c["id"])
		seen[cid] = true
		if not _cust_nodes.has(cid):
			var node2: Node3D = _make_person(CUST_COL[int(c["col"]) % CUST_COL.size()], false)
			var bub: Node3D = Node3D.new()
			bub.position = Vector3(0, 1.75, 0)
			bub.name = "Bubble"
			node2.add_child(bub)
			_cust_nodes[cid] = node2
		var n2: Node3D = _cust_nodes[cid]
		n2.position = to3(c["p"])
		var cdir: Vector2 = c.get("dir", Vector2(0, -1))
		n2.rotation.y = atan2(-cdir.x, -cdir.y)
		_sync_bubble(n2.get_node("Bubble"), c)
	for cid2: Variant in _cust_nodes.keys():
		if not seen.has(cid2):
			(_cust_nodes[cid2] as Node3D).queue_free()
			_cust_nodes.erase(cid2)
	## Estanterias y sitios.
	for pr: Dictionary in st["prods"]:
		var items: Array = _shelf_items[int(pr["id"])]
		for k2: int in items.size():
			(items[k2] as Node3D).visible = bool(pr["open"]) and k2 < int(pr["items"])
		_sync_lock(_locks["p%d" % int(pr["id"])], not bool(pr["open"]), int(pr["paid"]), int(pr["cost"]))
		(get_node("Crate%d" % int(pr["id"])) as Node3D).visible = bool(pr["open"])
	for k3: String in st["spots"]:
		var sp: Dictionary = st["spots"][k3]
		_sync_lock(_locks[k3], not bool(sp["done"]), int(sp["paid"]), int(sp["cost"]))
	## Monton de billetes junto a la caja.
	var bills: int = mini(int(st["pile"]) / 4, 30)
	while _pile.get_child_count() < bills:
		var i: int = _pile.get_child_count()
		_box(Vector3(0.32, 0.06, 0.18), Color("#4caf50"), Vector3(-0.17 + 0.34 * float(i % 2), 0.04 + 0.07 * float(i / 2), 0), _pile)
	while _pile.get_child_count() > bills:
		var last: Node = _pile.get_child(_pile.get_child_count() - 1)
		_pile.remove_child(last)
		last.queue_free()
	if _money_lbl != null:
		_money_lbl.text = str(int(st["money"]))
	_goal_bar.queue_redraw()
	_hud.queue_redraw()
	## Camara: arriba y detras, mirando al norte.
	## Encuadre: se ve casi toda la tienda (centrada en ancho) y se sigue al tendero de arriba abajo.
	var cx: float = float(st["w"]) * 0.5
	var want: Vector3 = Vector3(lerpf(cx, p.x, 0.35), 0, p.y) + Vector3(0, 13.0, 8.0)
	_cam.position = _cam.position.lerp(want, minf(1.0, delta * 6.0)) if not fast and _t > 0.2 else want
	_cam.look_at(_cam.position - Vector3(0, 13.0, 8.0), Vector3.UP)
	Audio.set_intensity(0.6 + 0.4 * clampf(float((st["customers"] as Array).size()) / 6.0, 0.0, 1.0))


func _sync_stack(stack: Node3D, carry: Array) -> void:
	while stack.get_child_count() < carry.size():
		_box(Vector3(0.3, 0.16, 0.24), Color.WHITE, Vector3(0, 0.17 * float(stack.get_child_count()), 0), stack)
	while stack.get_child_count() > carry.size():
		var last: Node = stack.get_child(stack.get_child_count() - 1)
		stack.remove_child(last)
		last.queue_free()
	for k: int in carry.size():
		var mi: MeshInstance3D = stack.get_child(k)
		((mi.mesh as BoxMesh).material as StandardMaterial3D).albedo_color = PROD_COL[int(carry[k])]


## Encima de cada cliente: lo que le falta (o una cara enfadada si se va sin comprar).
func _sync_bubble(bub: Node3D, c: Dictionary) -> void:
	var want: Array = c["want"]
	var got: int = (c["got"] as Array).size()
	var sig: String = "%d/%d/%s" % [got, want.size(), str(c["state"])]
	if str(bub.get_meta("sig", "")) == sig:
		return
	bub.set_meta("sig", sig)
	for ch: Node in bub.get_children():
		ch.queue_free()
	if str(c["state"]) == "leave":
		if bool(c.get("angry", false)):
			_box(Vector3(0.3, 0.3, 0.05), Color("#ff5a5a"), Vector3.ZERO, bub)
		return
	if str(c["state"]) == "queue":
		_box(Vector3(0.3, 0.3, 0.05), Color("#5ad17a"), Vector3.ZERO, bub)
		return
	var left: Array = want.slice(got)
	for k: int in left.size():
		_box(Vector3(0.22, 0.22, 0.05), PROD_COL[int(left[k])], Vector3(-0.13 * float(left.size() - 1) + 0.26 * float(k), 0, 0), bub)


func _sync_lock(lk: Dictionary, show: bool, paid: int, cost: int) -> void:
	(lk["root"] as Node3D).visible = show
	if show:
		var f: float = clampf(float(paid) / float(maxi(1, cost)), 0.0, 1.0)
		(lk["fill"] as Node3D).scale = Vector3(maxf(0.001, f), 1, 1)
		(lk["fill"] as Node3D).position.x = -0.45 * (1.0 - f)


# ------------------------------------------------------------------ toques

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()
		return
	if not can_act():
		return
	if event is InputEventScreenTouch:
		var te: InputEventScreenTouch = event
		if te.pressed and _move_id < 0:
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

func _finish() -> void:
	if finished:
		return
	finished = true
	_persist()
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = int(st["earned"]) * 10 + int(st["served"]) * 5 - int(st["lost"]) * 20
	var record: bool = Save.submit_best(level_id, maxi(1, score))
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "time": snappedf(time_in_level, 0.1), "lost": int(st["lost"])})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": 0, "coins_total": 0, "score": maxi(1, score), "record": record})
	await Ads.show_interstitial("level_end")


func stars_earned() -> int:
	var lost: int = int(st.get("lost", 0))
	if lost > 6:
		return 1
	return 3 if lost <= 2 and (par <= 0.0 or time_in_level <= par) else 2


func retry() -> void:
	get_tree().reload_current_scene()


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
	return {"pos": (st.get("me", {}) as Dictionary).get("p", Vector2.ZERO), "deaths": deaths, "coins": coins, "finished": finished, "failed": failed,
		"time": time_in_level, "earned": int(st.get("earned", 0)), "served": int(st.get("served", 0)), "lost": int(st.get("lost", 0))}
