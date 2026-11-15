class_name GameHub
extends Control
## Casa propia de cada juego (15 nov, «que no sea la misma plantilla para todos»). En vez de la portada
## comun, una pantalla con navegacion INVENTADA por la fabrica para ese juego (game.json "hub"):
## sus secciones, sus nombres, su forma de moverse y su campana. El esqueleto sale de lo que funciona
## en los grandes (pestanas abajo, campana central, botin que se llena solo); la metafora, los nombres
## y el aspecto son del juego. Los sistemas (heroes, invocar, torre, arena, misiones) son los del kit.
##
## "hub": {
##   "nav": {"shape": "sello"|"estandarte"|"losa", "connector": "cadena"|"cuerda"|"ninguno", "metal": "#hex"},
##   "tabs": [{"id": "campaign"|"heroes"|"summon"|"modes"|"tavern", "name": "La Grieta", "icon": "chain", "main": true}],
##   "campaign": {"layout": "descenso"|"ascenso", "node": "ancla", "verb": "Bajar a", "stage": "etapa",
##                "idle": {"name": "Caldero de esencia", "verb": "Recoger"}, "boss_every": 5},
##   "title": "texto pequeno de la cabecera"
## }

const NAV_H: float = 150.0

var cfg: Dictionary = {}
var _content: Control
var _nav: Control
var _tab_buttons: Dictionary = {}
var _current: String = ""
var _wallet: Label
var _power: Label
var _t: float = 0.0


static func enabled() -> bool:
	var h: Variant = Kit.config.get("hub", null)
	return h is Dictionary and not ((h as Dictionary).get("tabs", []) as Array).is_empty()


static func open_in(host: Control) -> GameHub:
	var g: GameHub = GameHub.new()
	g.name = "GameHub"
	g.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.add_child(g)
	return g


func _ready() -> void:
	cfg = (Kit.config.get("hub", {}) as Dictionary).duplicate(true)
	_link_art()
	theme = UI.theme
	_content = Control.new()
	_content.name = "HubContent"
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.offset_bottom = -NAV_H + 18.0
	add_child(_content)
	add_child(_header())
	_nav = _build_nav()
	add_child(_nav)
	var main: String = ""
	for t: Variant in cfg.get("tabs", []):
		if bool((t as Dictionary).get("main", false)):
			main = str((t as Dictionary)["id"])
	if main == "":
		main = str(((cfg["tabs"] as Array)[0] as Dictionary)["id"])
	show_tab(main)


func _book_layout() -> bool:
	var h: Dictionary = cfg.get("heroes", {})
	return str(h.get("layout", "")) == "libro" or HeroBook.portrait(str(Heroes.roster().keys()[0])) != null if not Heroes.roster().is_empty() else false


## Lo que la GPU dibujo para la casa (assets/manifest.json ui.casa: fondo, botin, etapa, jefe, nav_<id>)
## se engancha donde game.json no diga otra cosa.
func _link_art() -> void:
	var casa: Dictionary = ((Kit.assets.get("ui", {}) as Dictionary).get("casa", {})) as Dictionary
	if casa.is_empty():
		return
	for t: Variant in cfg.get("tabs", []):
		var d: Dictionary = t
		if not d.has("art") and casa.has("nav_" + str(d["id"])):
			d["art"] = str(casa["nav_" + str(d["id"])])
	var camp: Dictionary = cfg.get("campaign", {})
	for pair: Array in [["fondo", "fondo"], ["node_art", "etapa"], ["boss_art", "jefe"]]:
		if not camp.has(pair[0]) and casa.has(pair[1]):
			camp[pair[0]] = str(casa[pair[1]])
	var heroes: Dictionary = cfg.get("heroes", {})
	if not heroes.has("fondo") and casa.has("libro"):
		heroes["fondo"] = str(casa["libro"])
	cfg["heroes"] = heroes
	var idle: Dictionary = camp.get("idle", {})
	if not idle.has("art") and casa.has("botin"):
		idle["art"] = str(casa["botin"])
	camp["idle"] = idle
	cfg["campaign"] = camp


func _process(delta: float) -> void:
	_t += delta
	if _nav != null:
		_nav.queue_redraw()


## Textura del juego (arte de la casa: res://assets/ui/casa/...). null si no hay.
static var _tex_cache: Dictionary = {}


static func tex(path: String) -> Texture2D:
	if path == "":
		return null
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _tex_cache[path]


## Boton de la casa propia: liso con el color del juego y canto de su acento (sin la piel generica).
static func styled_button(text: String, primary: bool) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	var base: Color = UI.colors["panel_hi"] if primary else Color("#3f7f4c")
	var rim: Color = UI.colors["acento"]
	var n: StyleBoxFlat = StyleBoxFlat.new()
	n.bg_color = base
	n.border_color = rim
	n.set_border_width_all(4)
	n.set_corner_radius_all(28 if primary else 18)
	n.shadow_color = Color(base.darkened(0.6), 0.9)
	n.shadow_size = 0
	n.expand_margin_bottom = 0
	n.border_width_bottom = 9
	n.content_margin_left = 20.0
	n.content_margin_right = 20.0
	var hv: StyleBoxFlat = n.duplicate()
	hv.bg_color = base.lightened(0.12)
	var pr: StyleBoxFlat = n.duplicate()
	pr.bg_color = base.darkened(0.1)
	pr.border_width_bottom = 4
	for st: String in ["normal", "focus"]:
		b.add_theme_stylebox_override(st, n)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", pr)
	b.add_theme_stylebox_override("disabled", n)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	b.add_theme_constant_override("outline_size", 7)
	b.add_theme_font_size_override("font_size", 30)
	return b


func metal() -> Color:
	return Color(str((cfg.get("nav", {}) as Dictionary).get("metal", "#8d8597")))


func accent() -> Color:
	return UI.colors["acento"]


func glow() -> Color:
	return UI.colors["panel_hi"]


# ------------------------------------------------------------------ cabecera

func _header() -> Control:
	var bar: HBoxContainer = HBoxContainer.new()
	bar.name = "HubHeader"
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 18.0
	bar.offset_right = -18.0
	bar.offset_top = UI.safe_rect(get_viewport()).position.y + 18.0 if is_inside_tree() else 18.0
	bar.custom_minimum_size = Vector2(0, 92)
	bar.add_theme_constant_override("separation", 12)
	## Retrato del lider del equipo en un medallon.
	var av: Control = Control.new()
	av.name = "Avatar"
	av.custom_minimum_size = Vector2(88, 88)
	av.clip_contents = true
	av.draw.connect(func() -> void:
		av.draw_circle(av.size * 0.5, 44.0, glow().darkened(0.45))
		av.draw_arc(av.size * 0.5, 41.0, 0.0, TAU, 40, accent(), 5.0, true))
	bar.add_child(av)
	var lead: Array = Heroes.team() if Heroes.enabled() else []
	if not lead.is_empty():
		var fig: Node2D = Heroes.figure(str(lead[0]), 150.0)
		fig.position = Vector2(44, 128)
		av.add_child(fig)
	var v: VBoxContainer = VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	bar.add_child(v)
	var nm: Label = Label.new()
	nm.text = str(cfg.get("title", Kit.text("title", str(Kit.config.get("title", "")))))
	nm.add_theme_font_size_override("font_size", 26)
	nm.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	nm.add_theme_constant_override("outline_size", 6)
	v.add_child(nm)
	_power = Label.new()
	_power.add_theme_font_size_override("font_size", 19)
	_power.add_theme_color_override("font_color", accent())
	_power.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_power.add_theme_constant_override("outline_size", 5)
	v.add_child(_power)
	var sp: Control = Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(sp)
	var pill: PanelContainer = PanelContainer.new()
	pill.add_theme_stylebox_override("panel", _pill_box())
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(pill)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	pill.add_child(row)
	row.add_child(UiIcon.make("coin", Kit.color("coin", accent()), 32.0))
	_wallet = Label.new()
	_wallet.name = "Wallet"
	_wallet.add_theme_font_size_override("font_size", 24)
	row.add_child(_wallet)
	var plus: Button = UI.make_icon_button("coin")
	plus.custom_minimum_size = Vector2(44, 44)
	plus.visible = false
	row.add_child(plus)
	refresh()
	return bar


func _pill_box() -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(UI.colors["panel"], 0.9)
	sb.border_color = accent().darkened(0.2)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(20)
	sb.content_margin_left = 12.0
	sb.content_margin_right = 16.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	return sb


func refresh() -> void:
	if _wallet != null:
		_wallet.text = _short(Save.wallet())
	if _power != null:
		_power.text = Kit.text("hub_power", "Poder {p}").format({"p": _short(Heroes.team_power())}) if Heroes.enabled() else ""


static func _short(n: int) -> String:
	if n >= 100000:
		return "%dk" % (n / 1000)
	if n >= 10000:
		return "%.1fk" % (float(n) / 1000.0)
	return str(n)


# ------------------------------------------------------------------ navegacion

## Barra de abajo: un boton por seccion con la forma del juego (sellos, estandartes o losas) y, si
## toca, unidos por una cadena o una cuerda. La seccion principal va en el centro, mas grande.
func _build_nav() -> Control:
	var nav: Control = Control.new()
	nav.name = "HubNav"
	nav.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	nav.offset_top = -NAV_H
	nav.draw.connect(_draw_nav_back.bind(nav))
	var row: HBoxContainer = HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 8.0
	row.offset_right = -8.0
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 0)
	nav.add_child(row)
	for t: Variant in cfg.get("tabs", []):
		var d: Dictionary = t
		var b: Button = _nav_button(d)
		row.add_child(b)
		_tab_buttons[str(d["id"])] = b
	return nav


func _shape() -> String:
	return str((cfg.get("nav", {}) as Dictionary).get("shape", "sello"))


func _connector() -> String:
	return str((cfg.get("nav", {}) as Dictionary).get("connector", "ninguno"))


func _draw_nav_back(nav: Control) -> void:
	var w: float = nav.size.x
	var h: float = nav.size.y
	nav.draw_rect(Rect2(0, 24, w, h - 24), UI.colors["fondo"].darkened(0.35))
	nav.draw_rect(Rect2(0, 24, w, 4), metal().darkened(0.1))
	var y: float = 24.0 + (h - 24.0) * 0.42
	match _connector():
		"cadena":
			## Eslabones: ovalos alternos (de frente y de canto) de punta a punta.
			var x: float = 14.0
			var k: int = 0
			while x < w - 14.0:
				if k % 2 == 0:
					_ring(nav, Vector2(x + 13.0, y), Vector2(15.0, 8.0), metal())
				else:
					nav.draw_line(Vector2(x + 2.0, y), Vector2(x + 24.0, y), metal().darkened(0.25), 6.0, true)
				x += 22.0
				k += 1
		"cuerda":
			var pts: PackedVector2Array = PackedVector2Array()
			for i: int in 41:
				var xx: float = w * float(i) / 40.0
				pts.append(Vector2(xx, y + sin(float(i) * 0.9) * 3.0))
			nav.draw_polyline(pts, metal(), 7.0, true)
			nav.draw_polyline(pts, metal().lightened(0.3), 2.0, true)


func _ring(c: CanvasItem, at: Vector2, r: Vector2, col: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in 25:
		var a: float = TAU * float(i) / 24.0
		pts.append(at + Vector2(cos(a) * r.x, sin(a) * r.y))
	c.draw_polyline(pts, col.darkened(0.35), 7.0, true)
	c.draw_polyline(pts, col, 4.0, true)


func _nav_button(d: Dictionary) -> Button:
	var main: bool = bool(d.get("main", false))
	var b: Button = Button.new()
	b.name = "Tab_" + str(d["id"])
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, NAV_H)
	var face: Control = Control.new()
	face.set_anchors_preset(Control.PRESET_FULL_RECT)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.draw.connect(_draw_tab.bind(face, d))
	b.add_child(face)
	var ic: UiIcon = UiIcon.make(str(d.get("icon", "star")), Color("#f6efe0"), 64.0 if main else 44.0)
	ic.name = "Icon"
	ic.visible = GameHub.tex(str(d.get("art", ""))) == null
	ic.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	var r: float = 64.0 if main else 44.0
	ic.offset_left = -r * 0.5
	ic.offset_right = r * 0.5
	ic.offset_top = (6.0 if main else 50.0) + (60.0 - r) * 0.0
	ic.offset_bottom = ic.offset_top + r
	if not main:
		ic.offset_top = 47.0
		ic.offset_bottom = 47.0 + r
	else:
		ic.offset_top = 14.0
		ic.offset_bottom = 14.0 + r
	b.add_child(ic)
	var lb: Label = Label.new()
	lb.name = "Name"
	lb.text = str(d.get("name", d["id"]))
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	lb.offset_top = -34.0
	lb.offset_bottom = -6.0
	lb.add_theme_font_size_override("font_size", 19 if not main else 21)
	lb.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	lb.add_theme_constant_override("outline_size", 6)
	lb.clip_text = true
	b.add_child(lb)
	b.pressed.connect(func() -> void:
		Audio.play("click")
		show_tab(str(d["id"])))
	return b


func _draw_tab(face: Control, d: Dictionary) -> void:
	var main: bool = bool(d.get("main", false))
	var on: bool = _current == str(d["id"])
	var c: Vector2 = Vector2(face.size.x * 0.5, 46.0 if main else 70.0)
	var r: float = 52.0 if main else 34.0
	var base: Color = glow() if (on or main) else metal().darkened(0.45)
	var rim: Color = accent() if on else metal()
	if on:
		var k: float = 0.5 + 0.5 * sin(_t * 3.0)
		face.draw_circle(c, r + 10.0 + 4.0 * k, Color(glow(), 0.25))
	match _shape():
		"estandarte":
			var w: float = r * 1.5
			var top: float = c.y - r
			var pts: PackedVector2Array = PackedVector2Array([Vector2(c.x - w * 0.5, top), Vector2(c.x + w * 0.5, top),
				Vector2(c.x + w * 0.5, c.y + r * 0.7), Vector2(c.x, c.y + r * 1.05), Vector2(c.x - w * 0.5, c.y + r * 0.7)])
			face.draw_colored_polygon(pts, base.darkened(0.2))
			var closed: PackedVector2Array = pts.duplicate()
			closed.append(pts[0])
			face.draw_polyline(closed, rim, 4.0, true)
		"losa":
			var rect: Rect2 = Rect2(c - Vector2(r, r * 0.85), Vector2(r * 2.0, r * 1.7))
			var sb: StyleBoxFlat = StyleBoxFlat.new()
			sb.bg_color = base.darkened(0.2)
			sb.border_color = rim
			sb.set_border_width_all(4)
			sb.set_corner_radius_all(int(r * 0.35))
			face.draw_style_box(sb, rect)
		_:
			## Sello: disco con relieve y canto.
			face.draw_circle(c + Vector2(0, 5), r, Color(0, 0, 0, 0.35))
			face.draw_circle(c, r, base.darkened(0.25))
			face.draw_circle(c + Vector2(-r * 0.15, -r * 0.18), r * 0.72, base.lightened(0.08))
			## Sello pintado por la GPU (icono redondo de la seccion), dentro del canto.
			var art: Texture2D = GameHub.tex(str(d.get("art", "")))
			if art != null:
				var rr: float = r - 5.0
				face.draw_texture_rect(art, Rect2(c - Vector2(rr, rr), Vector2(rr, rr) * 2.0), false, Color.WHITE if (on or main) else Color(0.78, 0.76, 0.82))
			face.draw_arc(c, r - 2.0, 0.0, TAU, 40, rim, 4.0, true)
			if main:
				for i: int in 12:
					var a: float = TAU * float(i) / 12.0 + _t * 0.2
					face.draw_circle(c + Vector2(cos(a), sin(a)) * (r + 1.0), 3.5, rim)


func show_tab(id: String) -> void:
	var d: Dictionary = {}
	for t: Variant in cfg.get("tabs", []):
		if str((t as Dictionary)["id"]) == id:
			d = t
	if d.is_empty():
		return
	## Secciones que son ventanas del kit: se abren encima y la seccion de antes se queda.
	match id:
		"heroes":
			## Con libro (heroes.layout "libro" o retratos pintados por la GPU): seccion propia; si no, la ventana.
			if not Heroes.enabled():
				return
			if not _book_layout():
				var hp: HeroesPanel = HeroesPanel.open(self)
				hp.changed.connect(refresh)
				return
		"summon":
			if Heroes.enabled():
				var sp: SummonPanel = SummonPanel.open(self)
				sp.tree_exited.connect(refresh)
			return
		"modes":
			if RpgModes.enabled():
				RpgHubPanel.open(self)
			return
		"tavern":
			TavernPanel.open(self, d)
			return
	_current = id
	for c: Node in _content.get_children():
		c.queue_free()
	if id == "heroes":
		var hb: HeroBook = HeroBook.new()
		hb.name = "HeroBook"
		hb.hub = self
		hb.cfg = cfg.get("heroes", {})
		hb.set_anchors_preset(Control.PRESET_FULL_RECT)
		_content.add_child(hb)
	if id == "campaign":
		var v: CampaignView = CampaignView.new()
		v.name = "Campaign"
		v.hub = self
		v.cfg = cfg.get("campaign", {})
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		_content.add_child(v)
	for k: String in _tab_buttons:
		var b: Button = _tab_buttons[k]
		for ch: Node in b.get_children():
			if ch is Control:
				(ch as Control).queue_redraw()
