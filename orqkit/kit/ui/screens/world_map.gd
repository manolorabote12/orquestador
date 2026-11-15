class_name WorldMap
extends Control
## Mapa del mundo de la supervivencia (15 nov, «todos los juegos tienen la misma rejilla de niveles; el
## de supervivencia tiene que tener sus zonas, como Last Day on Earth»). Cada nivel es una ZONA del
## mapa, con su nombre (el de game.json), su dibujo (casas, coches, arboles... los de la GPU), su
## peligro (calaveras), su objetivo y sus estrellas. Un camino de tierra las une de abajo arriba; lo que
## aun no has alcanzado queda en la niebla. Arriba, el refugio: noches aguantadas y zonas despejadas.

const ZONE_GAP: float = 300.0
const NODE: float = 168.0

var _canvas: Control
var _scroll: ScrollContainer
var _points: Array[Vector2] = []
var _unlocked: int = 1
var _t: float = 0.0


static func open_in(host: Control) -> WorldMap:
	var w: WorldMap = WorldMap.new()
	w.name = "WorldMap"
	w.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.add_child(w)
	return w


func _ready() -> void:
	theme = UI.theme
	_unlocked = Save.unlocked_count()
	var root: MarginContainer = UI.safe_root(self)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	root.add_child(col)
	col.add_child(_top_bar())
	col.add_child(_shelter())
	if SurvivalDungeon.enabled():
		col.add_child(_dungeon_card())
	_scroll = ScrollContainer.new()
	_scroll.name = "MapScroll"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_scroll)
	_canvas = Control.new()
	_canvas.name = "MapCanvas"
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var n: int = Kit.level_count()
	_canvas.custom_minimum_size = Vector2(0, ZONE_GAP * float(n) + 120.0)
	_canvas.draw.connect(_draw_map)
	_canvas.resized.connect(_place)
	_scroll.add_child(_canvas)
	for i: int in n:
		_canvas.add_child(_zone(i))
	_place.call_deferred()


func _process(delta: float) -> void:
	_t += delta
	if _canvas != null:
		_canvas.queue_redraw()


func _top_bar() -> Control:
	var bar: HBoxContainer = HBoxContainer.new()
	bar.add_theme_constant_override("separation", 12)
	var back: Button = UI.make_icon_button("back")
	back.name = "BtnBack"
	back.pressed.connect(func() -> void: UI.goto(UI.SCREEN_TITLE))
	bar.add_child(back)
	var header: Label = Label.new()
	header.name = "Header"
	header.theme_type_variation = "HeaderLabel"
	header.text = Kit.text("world_map", "Mapa del mundo")
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(header)
	var stars: HBoxContainer = HBoxContainer.new()
	stars.alignment = BoxContainer.ALIGNMENT_END
	stars.custom_minimum_size = Vector2(UI.MIN_TOUCH + 8.0, 0)
	stars.add_child(UiIcon.make("star", UI.colors["acento"], 34.0))
	var total: Label = Label.new()
	total.name = "StarsTotal"
	var s: int = 0
	for i: int in Kit.level_count():
		s += Save.stars_for(str(i))
	total.text = str(s)
	stars.add_child(total)
	bar.add_child(stars)
	return bar


## El refugio: lo que llevas (zonas despejadas, noches aguantadas) y a donde toca ir.
func _shelter() -> Control:
	var box: PanelContainer = PanelContainer.new()
	box.name = "Shelter"
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(UI.colors["panel"], 0.92)
	sb.border_color = UI.colors["acento"]
	sb.border_width_bottom = 4
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 18.0
	sb.content_margin_right = 18.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	box.add_theme_stylebox_override("panel", sb)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	var tex: Texture2D = UI.fx_art("casa")
	if tex != null:
		var tr: TextureRect = TextureRect.new()
		tr.texture = tex
		tr.custom_minimum_size = Vector2(78, 78)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(tr)
	else:
		row.add_child(UiIcon.make("shield", UI.colors["acento"], 64.0))
	var v: VBoxContainer = VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(v)
	var cleared: int = 0
	var nights: int = 0
	for i: int in Kit.level_count():
		if Save.stars_for(str(i)) > 0:
			cleared += 1
			nights += int(_level(i).get("nights", 1))
	var t1: Label = Label.new()
	t1.text = Kit.text("shelter", "Tu refugio")
	t1.add_theme_font_size_override("font_size", 28)
	v.add_child(t1)
	var t2: Label = Label.new()
	t2.text = Kit.text("shelter_info", "{z}/{n} zonas despejadas  ·  {k} noches aguantadas").format(
		{"z": cleared, "n": Kit.level_count(), "k": nights})
	t2.add_theme_font_size_override("font_size", 19)
	t2.add_theme_color_override("font_color", UI.colors["texto_suave"])
	t2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t2)
	return box


## La Guarida: mazmorra de pisos sin fin (survival_dungeon.gd). Cerrada hasta despejar 3 zonas.
func _dungeon_card() -> Control:
	var open: bool = SurvivalDungeon.unlocked()
	var b: Button = Button.new()
	b.name = "BtnDungeon"
	b.custom_minimum_size = Vector2(0, 104)
	b.disabled = not open
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color("#2a1416") if open else Color("#1d1d1f")
	sb.border_color = Color("#ff6b5b") if open else Color(1, 1, 1, 0.12)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(16)
	var hov: StyleBoxFlat = sb.duplicate()
	hov.bg_color = Color("#3a1a1c")
	for st: String in ["normal", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, sb)
	for st2: String in ["hover", "pressed"]:
		b.add_theme_stylebox_override(st2, hov)
	var row: HBoxContainer = HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 14.0
	row.offset_right = -14.0
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var tex: Texture2D = UI.fx_art("guarida")
	if tex != null:
		var tr: TextureRect = TextureRect.new()
		tr.texture = tex
		tr.custom_minimum_size = Vector2(86, 86)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not open:
			tr.modulate = Color(0.3, 0.3, 0.3)
		row.add_child(tr)
	else:
		row.add_child(UiIcon.make("skull", Color("#ff6b5b"), 72.0))
	var v: VBoxContainer = VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(v)
	var t1: Label = Label.new()
	t1.text = Kit.text("dungeon", "La Guarida")
	t1.add_theme_font_size_override("font_size", 28)
	t1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(t1)
	var t2: Label = Label.new()
	t2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t2.add_theme_font_size_override("font_size", 18)
	t2.add_theme_color_override("font_color", Color("#ffb3a8") if open else UI.colors["texto_suave"])
	t2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if open:
		t2.text = Kit.text("dungeon_info", "Mazmorra sin fin  ·  piso {n}  ·  récord {b}  ·  premio {c}").format(
			{"n": SurvivalDungeon.floor_n(), "b": SurvivalDungeon.best(), "c": SurvivalDungeon.reward(SurvivalDungeon.floor_n())})
	else:
		t2.text = Kit.text("dungeon_locked", "Se abre al despejar {n} zonas del mapa").format({"n": SurvivalDungeon.OPEN_AFTER})
	v.add_child(t2)
	b.pressed.connect(func() -> void:
		Audio.play("click")
		SurvivalDungeon.play())
	return b


func _level(i: int) -> Dictionary:
	var levels: Array = Kit.config.get("levels", [])
	return levels[i] as Dictionary if i < levels.size() and levels[i] is Dictionary else {}


## Dibujo de la zona segun su nombre (los del decorado de la GPU; si no hay, un icono).
static func zone_art(zone_name: String) -> String:
	var n: String = zone_name.to_lower()
	var pairs: Array = [
		[["cueva", "guarida", "bunker", "búnker", "mina", "cripta", "mazmorra", "nido", "madriguera", "laboratorio"], "guarida"],
		[["gasolinera", "autopista", "carretera", "garaje", "parking", "taller", "puente", "tunel", "túnel"], "coche"],
		[["bosque", "selva", "arbol", "árbol", "pradera", "parque", "jardin", "jardín"], "arbol"],
		[["granja", "huerto", "campo", "rancho", "establo"], "arbusto_bayas"],
		[["torre", "radio", "antena", "faro", "monte", "colina", "roca", "cantera", "presa"], "roca"],
		[["barrio", "ciudad", "calle", "pueblo", "aldea", "casa", "hospital", "escuela", "centro"], "casa"],
	]
	for p: Array in pairs:
		for w: String in p[0]:
			if n.contains(w):
				return str(p[1])
	return "caja"


func _goal_text(lv: Dictionary) -> String:
	match str(lv.get("goal", "noches")):
		"receta":
			return Kit.text("zone_goal_craft", "Fabrica lo que falta")
		"balsa":
			return Kit.text("zone_goal_raft", "Construye la balsa y escapa")
	var k: int = int(lv.get("nights", 1))
	return Kit.text("zone_goal_nights", "Aguanta {n} noche(s)").format({"n": k})


func _zone(i: int) -> Control:
	var lv: Dictionary = _level(i)
	var open: bool = i < _unlocked
	var current: bool = i == _unlocked - 1
	var nm: String = str(lv.get("name", Kit.text("zone_n", "Zona {n}").format({"n": i + 1})))
	var node: VBoxContainer = VBoxContainer.new()
	node.name = "Zone%d" % (i + 1)
	node.alignment = BoxContainer.ALIGNMENT_CENTER
	node.add_theme_constant_override("separation", 4)
	node.custom_minimum_size = Vector2(260, 0)
	var b: Button = Button.new()
	b.name = "Level%d" % (i + 1)
	b.custom_minimum_size = Vector2(NODE, NODE)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.flat = true
	b.disabled = not open
	b.focus_mode = Control.FOCUS_NONE
	var ring: Control = Control.new()
	ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var acc: Color = UI.colors["acento"]
	ring.draw.connect(func() -> void:
		var c: Vector2 = ring.size * 0.5
		var r: float = minf(ring.size.x, ring.size.y) * 0.46
		ring.draw_circle(c + Vector2(0, 8), r, Color(0, 0, 0, 0.35))
		ring.draw_circle(c, r, Color("#2b2a24") if open else Color("#1c1c1c"))
		ring.draw_circle(c, r - 7.0, Color("#6b5a3c") if open else Color("#333333"))
		var col: Color = acc if current else (Color("#e9d8a6") if open else Color("#555555"))
		ring.draw_arc(c, r, 0.0, TAU, 48, col, 6.0 if current else 4.0, true))
	b.add_child(ring)
	var tex: Texture2D = UI.fx_art(zone_art(nm))
	if tex != null:
		var tr: TextureRect = TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.offset_left = 22.0
		tr.offset_top = 18.0
		tr.offset_right = -22.0
		tr.offset_bottom = -26.0
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not open:
			tr.modulate = Color(0.25, 0.25, 0.28)
		b.add_child(tr)
	if not open:
		var lock: UiIcon = UiIcon.make("lock", Color(1, 1, 1, 0.85), 56.0)
		lock.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		lock.offset_left = -28.0
		lock.offset_right = 28.0
		lock.offset_top = -28.0
		lock.offset_bottom = 28.0
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(lock)
	b.pressed.connect(_play.bind(i))
	node.add_child(b)
	## Cartel: nombre, peligro y objetivo (o estrellas si ya la despejaste).
	var plate: PanelContainer = PanelContainer.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.07, 0.06, 0.82)
	sb.border_color = acc if current else Color(1, 1, 1, 0.12)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	plate.add_theme_stylebox_override("panel", sb)
	plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(plate)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(v)
	var title: Label = Label.new()
	title.text = nm if open else "???"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	v.add_child(title)
	var danger: HBoxContainer = HBoxContainer.new()
	danger.alignment = BoxContainer.ALIGNMENT_CENTER
	danger.add_theme_constant_override("separation", 2)
	v.add_child(danger)
	var n: int = maxi(Kit.level_count(), 2)
	var skulls: int = clampi(1 + int(round(4.0 * float(i) / float(n - 1))), 1, 5)
	for k: int in 5:
		danger.add_child(UiIcon.make("skull", Color("#ff6b5b") if k < skulls else Color(1, 1, 1, 0.15), 22.0))
	if open and Save.stars_for(str(i)) > 0:
		var row: StarRow = StarRow.make(3, Save.stars_for(str(i)), 26.0)
		row.name = "Stars"
		row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		row.custom_minimum_size = Vector2(96, 28)
		v.add_child(row)
	elif open:
		var goal: Label = Label.new()
		goal.text = _goal_text(lv)
		goal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		goal.add_theme_font_size_override("font_size", 18)
		goal.add_theme_color_override("font_color", acc)
		v.add_child(goal)
	return node


## Zigzag de abajo (zona 1) arriba, como un camino que sube por el mapa.
func _place() -> void:
	var n: int = Kit.level_count()
	var w: float = _canvas.size.x
	var h: float = _canvas.custom_minimum_size.y
	_points.clear()
	for i: int in n:
		var node: Control = _canvas.get_node_or_null("Zone%d" % (i + 1)) as Control
		if node == null:
			continue
		var x: float = w * 0.5 + sin(float(i) * 1.25 + 0.4) * w * 0.24
		var y: float = h - 160.0 - ZONE_GAP * float(i)
		node.size = node.get_combined_minimum_size()
		node.position = Vector2(x - node.size.x * 0.5, y - NODE * 0.5)
		_points.append(Vector2(x, y))
	## Se abre mirando a la zona que toca.
	var cur: int = clampi(_unlocked - 1, 0, maxi(n - 1, 0))
	if cur < _points.size():
		_scroll.scroll_vertical = int(maxf(0.0, _points[cur].y - _scroll.size.y * 0.55))


## Camino de tierra entre zonas (curvo) y niebla sobre lo que aun no has alcanzado.
func _draw_map() -> void:
	if _points.size() < 2:
		return
	var curve: PackedVector2Array = PackedVector2Array()
	for k: int in range(_points.size() - 1):
		var a: Vector2 = _points[k]
		var b: Vector2 = _points[k + 1]
		var mid: Vector2 = (a + b) * 0.5 + Vector2((b.y - a.y) * 0.18, 0)
		for s: int in 16:
			var t: float = float(s) / 16.0
			curve.append(a.lerp(mid, t).lerp(mid.lerp(b, t), t))
	curve.append(_points[_points.size() - 1])
	_canvas.draw_polyline(curve, Color(0, 0, 0, 0.35), 34.0, true)
	_canvas.draw_polyline(curve, Color("#7a5c3a"), 26.0, true)
	_canvas.draw_polyline(curve, Color("#a07d50"), 16.0, true)
	## Huellas: puntos claros hasta tu zona; despues, el camino se apaga.
	var reach: float = 0.0
	if _unlocked - 1 < _points.size():
		reach = _points[clampi(_unlocked - 1, 0, _points.size() - 1)].y
	for j: int in range(0, curve.size(), 3):
		var p: Vector2 = curve[j]
		var lit: bool = p.y >= reach - 1.0
		_canvas.draw_circle(p, 4.0, Color("#f3e3b5", 0.9) if lit else Color(1, 1, 1, 0.12))
	## Niebla: lo que queda por encima de tu zona se oscurece poco a poco.
	if _unlocked - 1 < _points.size() - 1:
		var top: float = reach - ZONE_GAP * 0.55
		for k2: int in 6:
			var y0: float = top - float(k2) * 60.0
			_canvas.draw_rect(Rect2(0, 0, _canvas.size.x, maxf(0.0, y0)), Color(0.02, 0.02, 0.03, 0.09))
	## Tu zona late.
	if _unlocked - 1 < _points.size():
		var c: Vector2 = _points[_unlocked - 1]
		var k3: float = 0.5 + 0.5 * sin(_t * 3.0)
		_canvas.draw_arc(c, NODE * 0.5 + 10.0 + 8.0 * k3, 0.0, TAU, 48, Color(UI.colors["acento"], 0.55 * (1.0 - k3) + 0.2), 4.0, true)


func _play(i: int) -> void:
	Audio.play("click")
	Kit.level_index = i
	TimeAttack.stop()
	Expert.stop()
	UI.goto(UI.game_scene())
