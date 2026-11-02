extends Node2D
## Granja cozy (estilo Hay Day). Reglas en farm_map.gd (las mismas que el bot y el analizador).
## 1 - Elige una semilla abajo y toca parcelas vacias para sembrar; toca las maduras para cosechar.
## 2 - Toca un corral: recoge lo que hayan dado los animales y da pienso a los que tengan hambre.
## 3 - Toca una maquina: recoge lo hecho y abajo salen sus recetas para encargar mas.
## 4 - Tablon de pedidos: entrega cuando tengas todo (la X cambia un pedido por otro, con espera).
## 5 - Ganas al cumplir los pedidos del nivel. Estrellas por tiempo (par).
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel al acabar.

const MapRules = preload("res://kit/farm/farm_map.gd")
const CELL: float = 88.0
const NAMES: Dictionary = {"trigo": "Trigo", "maiz": "Ma\u00edz", "zanahoria": "Zanahoria", "fresa": "Fresa", "calabaza": "Calabaza",
	"huevo": "Huevo", "leche": "Leche", "lana": "Lana", "pienso": "Pienso", "pan": "Pan", "galletas": "Galletas", "queso": "Queso",
	"mantequilla": "Mantequilla", "tarta_fresa": "Tarta de fresa", "pastel_calabaza": "Pastel de calabaza", "jersey": "Jersey"}

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
var seed_pick: String = "trigo"
var machine_open: int = -1
var rows: Array[String] = []

var _world: Node2D
var _camera: Camera2D
var _font: Font
var _coins_label: Label
var _goal_label: Label
var _toast: Label
var _toast_t: float = 0.0
var _inv_box: HBoxContainer
var _orders_box: HBoxContainer
var _seeds_box: HBoxContainer
var _machine_panel: PanelContainer
var _machine_box: VBoxContainer
var _hud_t: float = 0.0
var _sig: String = ""
var _pops: Array[Dictionary] = []
var _flies: Array[Vector2] = []


## Icono de un producto dibujado con formas (lo usan el mundo y los botones).
class ItemIcon:
	extends Control
	var item: String = ""
	var size_px: float = 40.0

	func _draw() -> void:
		draw_item(self, item, size * 0.5, size_px)

	static func draw_item(ci: CanvasItem, item: String, c: Vector2, s: float) -> void:
		var k: float = s / 40.0
		match item:
			"trigo":
				ci.draw_line(c + Vector2(0, 16) * k, c + Vector2(0, -14) * k, Color("#c99a3b"), 3.0 * k)
				for i: int in 4:
					ci.draw_circle(c + Vector2(-5, -10 + i * 6) * k, 4.0 * k, Color("#f2c84b"))
					ci.draw_circle(c + Vector2(5, -7 + i * 6) * k, 4.0 * k, Color("#f2c84b"))
			"maiz":
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-10, 16) * k, c + Vector2(-4, -6) * k, c + Vector2(0, 16) * k]), Color("#5fae4a"))
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-7, 14) * k, c + Vector2(0, -18) * k, c + Vector2(7, 14) * k]), Color("#f5d33f"))
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(10, 16) * k, c + Vector2(4, -4) * k, c + Vector2(0, 16) * k]), Color("#4f9a3a"))
			"zanahoria":
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-8, -6) * k, c + Vector2(8, -6) * k, c + Vector2(0, 18) * k]), Color("#f28a2b"))
				for i: int in 3:
					ci.draw_line(c + Vector2(0, -6) * k, c + Vector2(-6 + i * 6, -18) * k, Color("#4f9a3a"), 3.0 * k)
			"fresa":
				ci.draw_circle(c + Vector2(-5, 0) * k, 9.0 * k, Color("#e8344a"))
				ci.draw_circle(c + Vector2(5, 0) * k, 9.0 * k, Color("#e8344a"))
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-13, 2) * k, c + Vector2(13, 2) * k, c + Vector2(0, 16) * k]), Color("#e8344a"))
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-8, -8) * k, c + Vector2(0, -14) * k, c + Vector2(8, -8) * k, c + Vector2(0, -4) * k]), Color("#4f9a3a"))
				for i: int in 4:
					ci.draw_circle(c + Vector2(-5 + (i % 2) * 9, 1 + (i / 2) * 6) * k, 1.2 * k, Color("#ffe27a"))
			"calabaza":
				ci.draw_circle(c + Vector2(-6, 3) * k, 11.0 * k, Color("#e07a2a"))
				ci.draw_circle(c + Vector2(6, 3) * k, 11.0 * k, Color("#e07a2a"))
				ci.draw_circle(c + Vector2(0, 3) * k, 12.0 * k, Color("#f2913a"))
				ci.draw_rect(Rect2(c + Vector2(-2, -14) * k, Vector2(4, 7) * k), Color("#6b4423"))
			"huevo":
				ci.draw_set_transform(c, 0.0, Vector2(0.8, 1.0))
				ci.draw_circle(Vector2.ZERO, 13.0 * k, Color("#fbf3e4"))
				ci.draw_circle(Vector2(-4, -4) * k, 4.0 * k, Color(1, 1, 1, 0.9))
				ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"leche":
				ci.draw_rect(Rect2(c + Vector2(-9, -6) * k, Vector2(18, 22) * k), Color("#f5f8fb"))
				ci.draw_rect(Rect2(c + Vector2(-6, -14) * k, Vector2(12, 8) * k), Color("#f5f8fb"))
				ci.draw_rect(Rect2(c + Vector2(-6, -17) * k, Vector2(12, 4) * k), Color("#3f8cff"))
				ci.draw_rect(Rect2(c + Vector2(-9, 2) * k, Vector2(18, 6) * k), Color("#8fd0ff"))
			"lana":
				for i: int in 5:
					ci.draw_circle(c + Vector2(cos(i * 1.25) * 7.0, sin(i * 1.25) * 6.0) * k, 8.0 * k, Color("#f4f1ea"))
				ci.draw_circle(c, 7.0 * k, Color("#e6e1d6"))
			"pienso":
				ci.draw_rect(Rect2(c + Vector2(-11, -10) * k, Vector2(22, 26) * k), Color("#b88a4a"))
				ci.draw_rect(Rect2(c + Vector2(-8, -16) * k, Vector2(16, 7) * k), Color("#9a7038"))
				ci.draw_circle(c + Vector2(0, 4) * k, 4.0 * k, Color("#f2c84b"))
			"pan":
				ci.draw_set_transform(c, 0.0, Vector2(1.0, 0.65))
				ci.draw_circle(Vector2.ZERO, 16.0 * k, Color("#c98a3b"))
				ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				for i: int in 3:
					ci.draw_line(c + Vector2(-8 + i * 7, -6) * k, c + Vector2(-4 + i * 7, 2) * k, Color("#f2d08a"), 2.0 * k)
			"galletas":
				for i: int in 2:
					var p: Vector2 = c + Vector2(-5 + i * 9, -3 + i * 6) * k
					ci.draw_circle(p, 10.0 * k, Color("#d9a066"))
					ci.draw_circle(p + Vector2(-3, -2) * k, 1.8 * k, Color("#5a3a20"))
					ci.draw_circle(p + Vector2(3, 2) * k, 1.8 * k, Color("#5a3a20"))
			"queso":
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-15, 12) * k, c + Vector2(15, 12) * k, c + Vector2(15, -2) * k, c + Vector2(-15, -10) * k]), Color("#f5c842"))
				ci.draw_circle(c + Vector2(-5, 4) * k, 3.0 * k, Color("#d9a520"))
				ci.draw_circle(c + Vector2(7, 6) * k, 2.5 * k, Color("#d9a520"))
			"mantequilla":
				ci.draw_rect(Rect2(c + Vector2(-14, -6) * k, Vector2(28, 16) * k), Color("#fbe28a"))
				ci.draw_rect(Rect2(c + Vector2(-14, -10) * k, Vector2(28, 5) * k), Color("#ffeeb0"))
			"tarta_fresa", "pastel_calabaza":
				var top: Color = Color("#ff9ab8") if item == "tarta_fresa" else Color("#f2913a")
				ci.draw_rect(Rect2(c + Vector2(-15, -2) * k, Vector2(30, 14) * k), Color("#e8c08a"))
				ci.draw_rect(Rect2(c + Vector2(-15, -8) * k, Vector2(30, 7) * k), top)
				ci.draw_circle(c + Vector2(0, -12) * k, 4.0 * k, Color("#e8344a") if item == "tarta_fresa" else Color("#6b4423"))
			"jersey":
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-8, -14) * k, c + Vector2(8, -14) * k, c + Vector2(18, -4) * k, c + Vector2(13, 2) * k,
					c + Vector2(10, -2) * k, c + Vector2(10, 16) * k, c + Vector2(-10, 16) * k, c + Vector2(-10, -2) * k, c + Vector2(-13, 2) * k,
					c + Vector2(-18, -4) * k]), Color("#c0503a"))
				ci.draw_line(c + Vector2(-10, 6) * k, c + Vector2(10, 6) * k, Color("#f4f1ea"), 2.0 * k)
			_:
				ci.draw_circle(c, 10.0 * k, Color("#cccccc"))


func _ready() -> void:
	level = Kit.current_level()
	par = float(level.get("par", 0))
	for r: Variant in level.get("map", []):
		rows.append(str(r))
	RenderingServer.set_default_clear_color(Color("#4f7a34"))
	_world = Node2D.new()
	_world.name = "World"
	_world.draw.connect(_draw_world)
	add_child(_world)
	_camera = Camera2D.new()
	add_child(_camera)
	_camera.make_current()
	Juice.register_camera(_camera)
	_font = UI.theme.get_font("font", "Label") if UI.theme != null else ThemeDB.fallback_font
	for k: int in 5:
		_flies.append(Vector2(randf() * 600.0, randf() * 400.0))
	_build_hud()
	_reset()
	_fit_camera()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "farm", "goal": st["goal"]})


func bot_script() -> String:
	return "res://qa/farm_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(20.0, 5.0)


func _reset() -> void:
	finished = false
	failed = false
	st = MapRules.new_state(level)
	coins_total = int(st["goal"])
	var cs: Array = st["crops"]
	seed_pick = str(cs[0]) if not cs.is_empty() else "trigo"
	machine_open = -1
	_sig = ""
	_pops.clear()
	time_in_level = 0.0
	_rebuild_seeds()
	_refresh()


func _fit_camera() -> void:
	var vp: Vector2 = get_viewport_rect().size
	var mw: float = float(rows[0].length()) * CELL if not rows.is_empty() else 600.0
	var mh: float = float(rows.size()) * CELL
	var room_h: float = vp.y - 560.0
	var z: float = minf(vp.x * 0.96 / mw, room_h / mh)
	_camera.zoom = Vector2.ONE * z
	## El mapa queda entre la barra de arriba (~130 px) y el tablon de abajo (~430 px).
	_camera.position = Vector2(mw * 0.5, mh * 0.5 + (430.0 - 130.0) * 0.5 / z)


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
	var safe: MarginContainer = UI.safe_root(root, 14.0)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col: VBoxContainer = VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 6)
	safe.add_child(col)
	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 10)
	col.add_child(top)
	top.add_child(UiIcon.make("coin", Kit.color("coin", Color("#ffd23f")), 44.0))
	_coins_label = Label.new()
	_coins_label.name = "Coins"
	_coins_label.add_theme_font_size_override("font_size", 38)
	_coins_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_coins_label.add_theme_constant_override("outline_size", 7)
	top.add_child(_coins_label)
	_goal_label = Label.new()
	_goal_label.name = "Goal"
	_goal_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_goal_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_goal_label.add_theme_constant_override("outline_size", 6)
	top.add_child(_goal_label)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)
	_toast = Label.new()
	_toast.name = "Toast"
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.add_theme_color_override("font_color", Color("#fff3c0"))
	_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_toast.add_theme_constant_override("outline_size", 7)
	col.add_child(_toast)
	var grow: Control = Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(grow)
	## Panel de una maquina (recetas).
	_machine_panel = PanelContainer.new()
	_machine_panel.name = "Machine"
	_machine_panel.visible = false
	col.add_child(_machine_panel)
	_machine_box = VBoxContainer.new()
	_machine_box.add_theme_constant_override("separation", 6)
	_machine_panel.add_child(_machine_box)
	## Granero (lo que tienes).
	var inv_scroll: ScrollContainer = ScrollContainer.new()
	inv_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inv_scroll.custom_minimum_size = Vector2(0, 62)
	col.add_child(inv_scroll)
	_inv_box = HBoxContainer.new()
	_inv_box.name = "Inventory"
	_inv_box.add_theme_constant_override("separation", 10)
	inv_scroll.add_child(_inv_box)
	## Tablon de pedidos.
	_orders_box = HBoxContainer.new()
	_orders_box.name = "Orders"
	_orders_box.add_theme_constant_override("separation", 8)
	col.add_child(_orders_box)
	## Semillas.
	_seeds_box = HBoxContainer.new()
	_seeds_box.name = "Seeds"
	_seeds_box.add_theme_constant_override("separation", 8)
	col.add_child(_seeds_box)


func _icon(item: String, px: float) -> ItemIcon:
	var ic: ItemIcon = ItemIcon.new()
	ic.item = item
	ic.size_px = px
	ic.custom_minimum_size = Vector2(px, px)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return ic


func item_name(item: String) -> String:
	return Kit.text("farm_item_" + item, str(NAMES.get(item, item)))


func _toast_now(t: String) -> void:
	if _toast == null:
		return
	_toast.text = t
	_toast_t = 2.5


func _rebuild_seeds() -> void:
	if _seeds_box == null:
		return
	for c: Node in _seeds_box.get_children():
		_seeds_box.remove_child(c)
		c.queue_free()
	for crop: Variant in st["crops"]:
		var b: Button = UI.make_button("", str(crop) == seed_pick, "")
		b.name = "Seed_" + str(crop)
		b.custom_minimum_size = Vector2(UI.MIN_TOUCH, 92)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(pick_seed.bind(str(crop)))
		var v: VBoxContainer = VBoxContainer.new()
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(v)
		var ic: ItemIcon = _icon(str(crop), 40.0)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(ic)
		var l: Label = Label.new()
		l.text = "%d" % int(MapRules.CROPS[crop]["seed"])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 20)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(l)
		_seeds_box.add_child(b)


func pick_seed(crop: String) -> void:
	seed_pick = crop
	_rebuild_seeds()
	_toast_now(Kit.text("farm_seed_pick", "Semilla: {s}. Toca las parcelas vac\u00edas").format({"s": item_name(crop)}))


func _refresh() -> void:
	if _coins_label == null or st.is_empty():
		return
	_coins_label.text = "%d" % int(st["coins"])
	_goal_label.text = Kit.text("farm_orders_done", "Pedidos {a}/{b}").format({"a": int(st["done"]), "b": int(st["goal"])})
	coins = int(st["done"])
	## Solo se rehacen las listas si algo ha cambiado (asi un dedo pulsando no pierde el boton).
	var sig: String = str(st["inv"]) + str(st["orders"]) + str(float(st["wait"]) > 0.0) + str(machine_open)
	if machine_open >= 0:
		var mm: Dictionary = st["machines"][machine_open]
		sig += str((mm["queue"] as Array).size())
	if sig == _sig:
		return
	_sig = sig
	for c: Node in _inv_box.get_children():
		_inv_box.remove_child(c)
		c.queue_free()
	var inv: Dictionary = st["inv"]
	var keys: Array = inv.keys()
	keys.sort()
	for it: Variant in keys:
		if int(inv[it]) <= 0:
			continue
		var h: HBoxContainer = HBoxContainer.new()
		h.add_child(_icon(str(it), 40.0))
		var l: Label = Label.new()
		l.text = "%d" % int(inv[it])
		l.add_theme_font_size_override("font_size", 26)
		h.add_child(l)
		_inv_box.add_child(h)
	for c: Node in _orders_box.get_children():
		_orders_box.remove_child(c)
		c.queue_free()
	for oi: int in (st["orders"] as Array).size():
		_orders_box.add_child(_order_card(oi))
	if machine_open >= 0:
		_fill_machine()


func _order_card(oi: int) -> Control:
	var o: Dictionary = st["orders"][oi]
	var card: PanelContainer = PanelContainer.new()
	card.name = "Order_%d" % oi
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(190, 0)
	card.clip_contents = true
	## Tarjeta de papel de pedido (margenes pequenos para que quepan tres).
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color("#fff3d6")
	sb.border_color = Color("#c99a5a")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(6)
	card.add_theme_stylebox_override("panel", sb)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	card.add_child(v)
	var items: HBoxContainer = HBoxContainer.new()
	items.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(items)
	for it: Variant in o["items"]:
		var need: int = int(o["items"][it])
		var have: int = MapRules.count(st, str(it))
		var box: VBoxContainer = VBoxContainer.new()
		box.add_child(_icon(str(it), 34.0))
		var l: Label = Label.new()
		l.text = "%d/%d" % [mini(have, need), need]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 18)
		l.add_theme_color_override("font_color", Color("#2f8a3a") if have >= need else Color("#7a5a3a"))
		box.add_child(l)
		items.add_child(box)
	var row: HBoxContainer = HBoxContainer.new()
	v.add_child(row)
	var b: Button = UI.make_button("+%d" % int(o["reward"]), MapRules.can_deliver(st, oi), "")
	b.name = "Deliver_%d" % oi
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(UI.MIN_TOUCH, UI.MIN_TOUCH)
	b.add_theme_font_size_override("font_size", 24)
	b.disabled = not MapRules.can_deliver(st, oi)
	b.pressed.connect(deliver.bind(oi))
	row.add_child(b)
	var x: Button = UI.make_icon_button("close")
	x.custom_minimum_size = Vector2(UI.MIN_TOUCH, UI.MIN_TOUCH)
	x.name = "Reject_%d" % oi
	x.disabled = float(st["wait"]) > 0.0
	x.pressed.connect(reject.bind(oi))
	row.add_child(x)
	return card


func _fill_machine() -> void:
	for c: Node in _machine_box.get_children():
		_machine_box.remove_child(c)
		c.queue_free()
	var m: Dictionary = st["machines"][machine_open]
	var info: Dictionary = MapRules.MACHINES[m["key"]]
	var head: HBoxContainer = HBoxContainer.new()
	_machine_box.add_child(head)
	var t: Label = Label.new()
	t.text = Kit.text("farm_m_" + str(info["name"]), str(info["name"]).capitalize()) + "  (%d/%d)" % [(m["queue"] as Array).size(), MapRules.QUEUE_MAX]
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var close: Button = UI.make_icon_button("close")
	close.name = "CloseMachine"
	close.pressed.connect(func() -> void:
		machine_open = -1
		_machine_panel.visible = false)
	head.add_child(close)
	for item: Variant in info["recipes"]:
		var r: Array = info["recipes"][item]
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_machine_box.add_child(row)
		row.add_child(_icon(str(item), 40.0))
		var eq: Label = Label.new()
		eq.text = "="
		row.add_child(eq)
		for ing: Variant in r[0]:
			row.add_child(_icon(str(ing), 30.0))
			var n: Label = Label.new()
			n.text = "%d/%d" % [MapRules.count(st, str(ing)), int(r[0][ing])]
			n.add_theme_font_size_override("font_size", 18)
			n.add_theme_color_override("font_color", Color("#9ff0a8") if MapRules.count(st, str(ing)) >= int(r[0][ing]) else Color("#ff9a8a"))
			row.add_child(n)
		var sp: Control = Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(sp)
		var b: Button = UI.make_button(Kit.text("farm_make", "Hacer"), true, "")
		b.name = "Make_" + str(item)
		b.custom_minimum_size = Vector2(150, UI.MIN_TOUCH)
		b.disabled = not MapRules.can_make(st, machine_open, str(item))
		b.pressed.connect(make.bind(machine_open, str(item)))
		row.add_child(b)


# ------------------------------------------------------------------ acciones (toques y bot)

func can_act() -> bool:
	return not finished and is_inside_tree() and not get_tree().paused


func deliver(oi: int) -> void:
	if not can_act():
		return
	var reward: int = int(st["orders"][oi]["reward"])
	if MapRules.deliver(st, oi):
		if not fast:
			Audio.play("coin")
			Juice.vibrate(20)
			_toast_now(Kit.text("farm_delivered", "\u00a1Pedido entregado! +{n}").format({"n": reward}))
		_check_win()
	_refresh()


func reject(oi: int) -> void:
	if MapRules.reject(st, oi):
		_toast_now(Kit.text("farm_rejected", "Pedido cambiado. El siguiente cambio, en {n} s").format({"n": int(MapRules.REJECT_WAIT)}))
	_refresh()


func make(mi: int, item: String) -> void:
	if MapRules.make(st, mi, item) and not fast:
		Audio.play("click", 0.1, -4.0)
	_refresh()


## Toque en el mundo (en casillas).
func tap_cell(c: Vector2i) -> void:
	if not can_act():
		return
	for i: int in (st["plots"] as Array).size():
		var p: Dictionary = st["plots"][i]
		if p["cell"] != c:
			continue
		if MapRules.ready(p):
			var crop: String = str(p["crop"])
			MapRules.harvest(st, i)
			_pops.append({"item": crop, "at": _center(c), "t": 1.0, "n": MapRules.HARVEST})
			if not fast:
				Audio.play("coin", 0.15, -8.0)
		elif str(p["crop"]) == "":
			if MapRules.plant(st, i, seed_pick):
				if not fast:
					Audio.play("click", 0.1, -8.0)
			else:
				_toast_now(Kit.text("farm_no_coins", "No tienes monedas para esa semilla"))
		else:
			var left: float = float(MapRules.CROPS[p["crop"]]["t"]) - float(p["t"])
			_toast_now(Kit.text("farm_growing", "{s}: faltan {n} s").format({"s": item_name(str(p["crop"])), "n": int(ceil(left))}))
		_refresh()
		return
	var any: bool = false
	var hungry: bool = false
	for a: int in (st["animals"] as Array).size():
		var an: Dictionary = st["animals"][a]
		if an["cell"] != c:
			continue
		any = true
		if an["ready"]:
			_pops.append({"item": str(MapRules.ANIMALS[an["key"]]["product"]), "at": _center(c), "t": 1.0, "n": 1})
		if MapRules.tend(st, a):
			pass
		elif not an["fed"]:
			hungry = true
	if any:
		if hungry:
			_toast_now(Kit.text("farm_need_feed", "Tienen hambre: haz pienso en el molino"))
		elif not fast:
			Audio.play("click", 0.1, -6.0)
		_refresh()
		return
	for mi: int in (st["machines"] as Array).size():
		if st["machines"][mi]["cell"] != c:
			continue
		var m: Dictionary = st["machines"][mi]
		for item: Variant in m["done"]:
			_pops.append({"item": str(item), "at": _center(c), "t": 1.0, "n": 1})
		MapRules.collect(st, mi)
		machine_open = mi
		_machine_panel.visible = true
		_refresh()
		return


func bot_step() -> void:
	MapRules.bot_turn(st)
	_check_win()


func _check_win() -> void:
	if int(st["done"]) >= int(st["goal"]) and not finished:
		time_in_level = float(st["time"])
		_finish()


# ------------------------------------------------------------------ simulacion

func _physics_process(delta: float) -> void:
	if finished:
		return
	var steps: int = 8 if fast else 1
	var dt: float = 0.25 if fast else delta * (3.0 if auto_retry else 1.0)
	for k: int in steps:
		MapRules.step(st, dt)
	time_in_level = float(st["time"])
	_check_win()
	var keep: Array[Dictionary] = []
	for p: Dictionary in _pops:
		p["t"] = float(p["t"]) - delta
		if float(p["t"]) > 0.0:
			keep.append(p)
	_pops = keep
	for i: int in _flies.size():
		_flies[i] += Vector2(sin(time_in_level * 1.3 + float(i) * 2.0), cos(time_in_level * 0.9 + float(i))) * 30.0 * delta
	_hud_t -= delta
	if _hud_t <= 0.0:
		_hud_t = 0.5
		_refresh()
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0:
			_toast.text = ""
	_world.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()
		return
	if event is InputEventScreenTouch and not (event as InputEventScreenTouch).pressed:
		var w: Vector2 = get_canvas_transform().affine_inverse() * (event as InputEventScreenTouch).position
		tap_cell(Vector2i(int(floor(w.x / CELL)), int(floor(w.y / CELL))))


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = maxi(0, 20000 - int(time_in_level) * 15) + int(st["coins"]) * 5
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "time": snappedf(time_in_level, 0.1), "deaths": 0,
		"orders": int(st["done"])})
	Audio.play("win")
	Audio.play_track("victoria", false)
	Juice.burst(self, _camera.position, Kit.color("coin", Color.YELLOW), 28, 380.0)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


func stars_earned() -> int:
	if par <= 0.0 or time_in_level <= par * 1.8:
		return 3
	return 2 if time_in_level <= par * 3.0 else 1


func retry() -> void:
	_reset()


func open_pause() -> void:
	if finished or get_tree().paused or get_node_or_null("PauseMenu") != null:
		return
	PauseMenu.open(self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_inside_tree() and not UI.test_mode:
			open_pause()


func bot_state() -> Dictionary:
	return {"pos": Vector2(float(st.get("done", 0)), float(st.get("coins", 0))), "deaths": 0, "coins": coins, "finished": finished,
		"failed": failed, "stomps": 0, "time": time_in_level, "orders": int(st.get("done", 0))}


# ------------------------------------------------------------------ dibujo

func _center(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * CELL


func _text(at: Vector2, s: String, size: int, col: Color) -> void:
	var wd: float = _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p: Vector2 = at - Vector2(wd * 0.5, 0.0)
	for o: Vector2 in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)]:
		_world.draw_string(_font, p + o, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.75))
	_world.draw_string(_font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _bubble(at: Vector2, item: String, t: float, faded: bool = false) -> void:
	var p: Vector2 = at + Vector2(0, -CELL * 0.62 + sin(t * 4.0) * 4.0)
	_world.draw_circle(p, 24.0, Color(1, 1, 1, 0.55 if faded else 0.95))
	_world.draw_colored_polygon(PackedVector2Array([p + Vector2(-6, 20), p + Vector2(6, 20), p + Vector2(0, 30)]), Color(1, 1, 1, 0.55 if faded else 0.95))
	ItemIcon.draw_item(_world, item, p, 30.0)


func _draw_world() -> void:
	if rows.is_empty() or st.is_empty():
		return
	var t: float = time_in_level
	var w: int = rows[0].length()
	var h: int = rows.size()
	var g1: Color = Kit.color("grass", Color("#7cc05a"))
	## Hierba con un poco de variacion, flores y matas.
	_world.draw_rect(Rect2(Vector2(-CELL, -CELL), Vector2(w + 2, h + 2) * CELL), g1.darkened(0.08))
	for y: int in h:
		for x: int in w:
			var r: Rect2 = Rect2(Vector2(x, y) * CELL, Vector2(CELL, CELL))
			_world.draw_rect(r, g1 if (x * 7 + y * 3) % 5 != 0 else g1.lightened(0.05))
			var hsh: int = absi(x * 73 + y * 37)
			if hsh % 3 == 0:
				_world.draw_line(r.position + Vector2(20, 60), r.position + Vector2(24, 50), g1.darkened(0.25), 3.0)
				_world.draw_line(r.position + Vector2(26, 60), r.position + Vector2(28, 48), g1.darkened(0.25), 3.0)
			if hsh % 7 == 0:
				var fl: Vector2 = r.position + Vector2(62, 24)
				for k: int in 5:
					_world.draw_circle(fl + Vector2(cos(k * 1.26), sin(k * 1.26)) * 5.0, 3.5, Color("#fff3f0") if hsh % 2 == 0 else Color("#ffd1e8"))
				_world.draw_circle(fl, 3.0, Color("#ffd23f"))
	## Camino de tierra alrededor de las parcelas (bordes suaves).
	for y: int in h:
		for x: int in w:
			var ch: String = rows[y][x]
			var r: Rect2 = Rect2(Vector2(x, y) * CELL, Vector2(CELL, CELL))
			var c: Vector2 = r.get_center()
			match ch:
				"~":
					_world.draw_rect(r.grow(-4.0), Color("#5aa8e0"))
					_world.draw_rect(r.grow(-4.0), Color("#3f8cc4"), false, 4.0)
					_world.draw_arc(c + Vector2(-10, 4), 8.0 + fmod(t * 6.0, 14.0), 0.0, TAU, 16, Color(1, 1, 1, 0.5 - fmod(t * 6.0, 14.0) / 30.0), 2.0)
				"t":
					_world.draw_circle(c + Vector2(4, 30), 26.0, Color(0, 0, 0, 0.18))
					_world.draw_rect(Rect2(c + Vector2(-6, 6), Vector2(12, 30)), Color("#7a4a26"))
					var sway: float = sin(t * 1.2 + float(x)) * 2.0
					_world.draw_circle(c + Vector2(sway, -8), 30.0, Color("#3f8a36"))
					_world.draw_circle(c + Vector2(-12 + sway, -16), 16.0, Color("#56a845"))
					_world.draw_circle(c + Vector2(10, 0), 4.0, Color("#e8344a"))
				"h":
					_draw_house(r)
	for i: int in (st["plots"] as Array).size():
		_draw_plot(st["plots"][i], t)
	_draw_pens(t)
	for mi: int in (st["machines"] as Array).size():
		_draw_machine(mi, t)
	## Mariposas.
	for f: Vector2 in _flies:
		var fp: Vector2 = Vector2(fmod(absf(f.x), float(w) * CELL), fmod(absf(f.y), float(h) * CELL))
		var flap: float = absf(sin(t * 14.0 + f.x)) * 6.0
		_world.draw_colored_polygon(PackedVector2Array([fp, fp + Vector2(-8, -flap), fp + Vector2(-6, 4)]), Color("#ffd1e8"))
		_world.draw_colored_polygon(PackedVector2Array([fp, fp + Vector2(8, -flap), fp + Vector2(6, 4)]), Color("#ffd1e8"))
	for p: Dictionary in _pops:
		var pp: Vector2 = (p["at"] as Vector2) + Vector2(0, -40.0 - (1.0 - float(p["t"])) * 50.0)
		ItemIcon.draw_item(_world, str(p["item"]), pp, 36.0)
		_text(pp + Vector2(30, 8), "+%d" % int(p["n"]), 24, Color("#fff3c0"))
	## Luz de la tarde que va y viene (ambiente).
	var warm: float = (sin(t * TAU / 240.0) + 1.0) * 0.5
	_world.draw_rect(Rect2(Vector2(-CELL, -CELL), Vector2(w + 2, h + 2) * CELL), Color(1.0, 0.7, 0.4, 0.08 * warm))


func _draw_plot(p: Dictionary, t: float) -> void:
	var c: Vector2i = p["cell"]
	var r: Rect2 = Rect2(Vector2(c) * CELL, Vector2(CELL, CELL)).grow(-5.0)
	_world.draw_rect(r, Color("#8a5a32"))
	for k: int in 3:
		var y: float = r.position.y + 14.0 + float(k) * 24.0
		_world.draw_line(Vector2(r.position.x + 8.0, y), Vector2(r.end.x - 8.0, y), Color("#6b4423"), 4.0)
	_world.draw_rect(r, Color("#6b4423"), false, 3.0)
	var crop: String = str(p["crop"])
	if crop == "":
		return
	var f: float = clampf(float(p["t"]) / float(MapRules.CROPS[crop]["t"]), 0.0, 1.0)
	var mid: Vector2 = r.get_center()
	var sway: float = sin(t * 2.0 + float(c.x)) * 2.0
	if f < 0.35:
		for k: int in 3:
			var sp: Vector2 = mid + Vector2(-20 + k * 20, 6)
			_world.draw_line(sp, sp + Vector2(-4 + sway, -10), Color("#6fc04a"), 3.0)
			_world.draw_line(sp, sp + Vector2(4 + sway, -10), Color("#6fc04a"), 3.0)
	elif f < 1.0:
		for k: int in 3:
			var sp2: Vector2 = mid + Vector2(-20 + k * 20, 14)
			_world.draw_line(sp2, sp2 + Vector2(sway, -30.0 * f), Color("#4f9a3a"), 4.0)
			_world.draw_circle(sp2 + Vector2(sway, -30.0 * f), 7.0, Color("#6fc04a"))
		_world.draw_rect(Rect2(Vector2(r.position.x + 8.0, r.end.y - 10.0), Vector2((r.size.x - 16.0) * f, 5.0)), Color("#ffd23f"))
	else:
		for k: int in 3:
			ItemIcon.draw_item(_world, crop, mid + Vector2(-20 + k * 20 + sway, -4 + (k % 2) * 8), 28.0)
		var sp3: float = fmod(t * 2.0 + float(c.x + c.y), 2.0)
		if sp3 < 0.5:
			_world.draw_circle(mid + Vector2(24, -24), 4.0 * (1.0 - sp3 * 2.0) + 1.0, Color(1, 1, 0.8, 0.9))


func _draw_house(r: Rect2) -> void:
	var b: Rect2 = r.grow(-8.0)
	_world.draw_rect(Rect2(b.position + Vector2(6, 8), b.size), Color(0, 0, 0, 0.2))
	_world.draw_rect(Rect2(Vector2(b.position.x, b.get_center().y - 4.0), Vector2(b.size.x, b.size.y * 0.55)), Color("#f2e3c6"))
	_world.draw_colored_polygon(PackedVector2Array([Vector2(b.position.x - 6.0, b.get_center().y), Vector2(b.get_center().x, b.position.y - 6.0),
		Vector2(b.end.x + 6.0, b.get_center().y)]), Color("#c0503a"))
	_world.draw_rect(Rect2(Vector2(b.get_center().x - 9.0, b.end.y - 26.0), Vector2(18, 26)), Color("#7a4a26"))
	_world.draw_rect(Rect2(Vector2(b.position.x + 8.0, b.end.y - 30.0), Vector2(14, 12)), Color("#8fd0ff"))
	_world.draw_line(Vector2(b.end.x - 16.0, b.position.y + 8.0), Vector2(b.end.x - 16.0, b.position.y - 6.0), Color("#7d7f86"), 6.0)
	var smoke: float = fmod(time_in_level * 12.0, 30.0)
	_world.draw_circle(Vector2(b.end.x - 16.0 + smoke * 0.3, b.position.y - 12.0 - smoke), 5.0 + smoke * 0.15, Color(1, 1, 1, 0.5 - smoke / 60.0))


func _draw_pens(t: float) -> void:
	var cells: Dictionary = {}
	for a: Dictionary in st["animals"]:
		if not cells.has(a["cell"]):
			cells[a["cell"]] = []
		(cells[a["cell"]] as Array).append(a)
	for c: Variant in cells:
		var cell: Vector2i = c
		var r: Rect2 = Rect2(Vector2(cell) * CELL, Vector2(CELL, CELL)).grow(-3.0)
		_world.draw_rect(r, Color("#c9b070"))
		## Valla.
		for k: int in 5:
			var x: float = r.position.x + float(k) * r.size.x / 4.0
			_world.draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color("#8a5a2b"), 4.0)
		_world.draw_line(r.position + Vector2(0, 8), Vector2(r.end.x, r.position.y + 8.0), Color("#a87038"), 4.0)
		_world.draw_line(Vector2(r.position.x, r.end.y - 8.0), r.end - Vector2(0, 8), Color("#a87038"), 4.0)
		var list: Array = cells[c]
		var any_ready: bool = false
		var any_hungry: bool = false
		for i: int in list.size():
			var a: Dictionary = list[i]
			var ap: Vector2 = r.position + Vector2(18.0 + float(i % 2) * 34.0, 28.0 + float(i / 2) * 30.0)
			ap.x += sin(t * 0.8 + float(i) * 2.0) * 4.0
			_draw_animal(str(MapRules.ANIMALS[a["key"]]["kind"]), ap, t + float(i))
			any_ready = any_ready or a["ready"]
			any_hungry = any_hungry or (not a["fed"] and not a["ready"])
		var key: String = str((list[0] as Dictionary)["key"])
		if any_ready:
			_bubble(r.get_center(), str(MapRules.ANIMALS[key]["product"]), t)
		elif any_hungry:
			_bubble(r.get_center(), MapRules.FEED, t, true)


func _draw_animal(kind: String, p: Vector2, t: float) -> void:
	_world.draw_circle(p + Vector2(0, 10), 10.0, Color(0, 0, 0, 0.15))
	match kind:
		"gallina":
			_world.draw_circle(p, 9.0, Color("#fbfbf6"))
			_world.draw_circle(p + Vector2(7, -6), 5.0, Color("#fbfbf6"))
			_world.draw_circle(p + Vector2(8, -11), 2.5, Color("#e8344a"))
			_world.draw_colored_polygon(PackedVector2Array([p + Vector2(11, -6), p + Vector2(15, -5), p + Vector2(11, -3)]), Color("#f2a13a"))
		"vaca":
			_world.draw_rect(Rect2(p + Vector2(-14, -8), Vector2(26, 16)), Color("#fbfbf6"))
			_world.draw_circle(p + Vector2(-5, -2), 5.0, Color("#2a2a2a"))
			_world.draw_rect(Rect2(p + Vector2(10, -12), Vector2(10, 12)), Color("#fbfbf6"))
			_world.draw_rect(Rect2(p + Vector2(12, -4), Vector2(8, 5)), Color("#f2b8c0"))
		"oveja":
			for k: int in 5:
				_world.draw_circle(p + Vector2(cos(k * 1.25) * 7.0, sin(k * 1.25) * 5.0), 7.0, Color("#f4f1ea"))
			_world.draw_circle(p + Vector2(12, -4), 5.0, Color("#3a3a3a"))


func _draw_machine(mi: int, t: float) -> void:
	var m: Dictionary = st["machines"][mi]
	var cell: Vector2i = m["cell"]
	var r: Rect2 = Rect2(Vector2(cell) * CELL, Vector2(CELL, CELL)).grow(-6.0)
	var roofs: Dictionary = {"M": "#8a5a2b", "P": "#c0503a", "Q": "#3f8cff", "T": "#e070a0", "J": "#7a5ab0"}
	_world.draw_rect(Rect2(r.position + Vector2(5, 7), r.size), Color(0, 0, 0, 0.2))
	_world.draw_rect(Rect2(Vector2(r.position.x, r.position.y + r.size.y * 0.35), Vector2(r.size.x, r.size.y * 0.65)), Color("#e8d8b8"))
	_world.draw_colored_polygon(PackedVector2Array([Vector2(r.position.x - 4.0, r.position.y + r.size.y * 0.4), Vector2(r.get_center().x, r.position.y - 4.0),
		Vector2(r.end.x + 4.0, r.position.y + r.size.y * 0.4)]), Color(str(roofs.get(m["key"], "#8a5a2b"))))
	var first: String = str((MapRules.MACHINES[m["key"]]["recipes"] as Dictionary).keys()[0])
	if str(m["key"]) == "M":
		## Aspas del molino girando.
		var hub: Vector2 = r.get_center() + Vector2(0, 2)
		var spin: float = t * (2.0 if not (m["queue"] as Array).is_empty() else 0.3)
		for k: int in 4:
			var a: float = spin + float(k) * PI * 0.5
			_world.draw_line(hub, hub + Vector2(cos(a), sin(a)) * 26.0, Color("#f4f1ea"), 6.0)
		_world.draw_circle(hub, 5.0, Color("#6b4423"))
	else:
		ItemIcon.draw_item(_world, first, r.get_center() + Vector2(0, 12), 30.0)
	var q: Array = m["queue"]
	if not q.is_empty():
		var rr: Array = MapRules.MACHINES[m["key"]]["recipes"][q[0]]
		var f: float = float(m["t"]) / float(rr[1])
		_world.draw_rect(Rect2(Vector2(r.position.x + 6.0, r.end.y - 10.0), Vector2(r.size.x - 12.0, 6.0)), Color(0, 0, 0, 0.4))
		_world.draw_rect(Rect2(Vector2(r.position.x + 6.0, r.end.y - 10.0), Vector2((r.size.x - 12.0) * f, 6.0)), Color("#9ff0a8"))
		## Humo de trabajo.
		var s: float = fmod(t * 20.0, 26.0)
		_world.draw_circle(Vector2(r.end.x - 12.0, r.position.y - s), 4.0 + s * 0.2, Color(1, 1, 1, 0.5 - s / 52.0))
	if not (m["done"] as Array).is_empty():
		_bubble(r.get_center(), str((m["done"] as Array)[0]), t)
	if machine_open == mi:
		_world.draw_rect(r.grow(4.0), Color(1, 1, 1, 0.9), false, 4.0)
