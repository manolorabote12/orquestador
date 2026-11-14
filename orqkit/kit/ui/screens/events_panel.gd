class_name EventsPanel
extends UiModal
## Elegir evento (kit/brawl/events.gd): una tarjeta grande por modo con su color, que se juega y en
## que mapa; abajo, el personaje con el que vas a jugar (tocar para cambiarlo).

signal changed


static func open(host: Node) -> EventsPanel:
	var p: EventsPanel = EventsPanel.new()
	p.name = "EventsPanel"
	host.add_child(p)
	return p


func _ready() -> void:
	build_frame(Kit.text("events", "Eventos"), 660.0)
	var list: VBoxContainer = VBoxContainer.new()
	list.name = "Events"
	list.add_theme_constant_override("separation", 12)
	body.add_child(list)
	for m: String in BrawlEvents.modes():
		list.add_child(_card(m))
	var who: Button = UI.make_button(Kit.text("event_brawler", "Juegas con {x}").format({"x": str(Brawlers.chosen().get("name", ""))}), false, "star")
	who.name = "BtnBrawler"
	who.pressed.connect(func() -> void:
		var bp: BrawlersPanel = BrawlersPanel.open(get_parent())
		bp.changed.connect(func() -> void:
			who.text = Kit.text("event_brawler", "Juegas con {x}").format({"x": str(Brawlers.chosen().get("name", ""))})
			changed.emit()))
	body.add_child(who)
	var close_b: Button = UI.make_button(Kit.text("close", "Cerrar"), false, "close")
	close_b.name = "BtnClose"
	close_b.pressed.connect(func() -> void: close())
	body.add_child(close_b)


func _card(mode: String) -> Control:
	var col: Color = Color(str(BrawlEvents.INFO[mode]["col"]))
	var b: Button = Button.new()
	b.name = "Event_" + mode
	b.custom_minimum_size = Vector2(600.0, 150.0)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = col.darkened(0.45)
	sb.border_color = col.lightened(0.2)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(18)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 4)
	var hov: StyleBoxFlat = sb.duplicate()
	hov.bg_color = col.darkened(0.3)
	for st: String in ["normal", "focus"]:
		b.add_theme_stylebox_override(st, sb)
	for st2: String in ["hover", "pressed"]:
		b.add_theme_stylebox_override(st2, hov)
	## Ilustracion del modo dibujada por la GPU (assets/ui/eventos) de fondo, con un velo para leer.
	var art: Texture2D = UI.event_art(mode)
	if art != null:
		b.custom_minimum_size = Vector2(600.0, 190.0)
		var pic: TextureRect = TextureRect.new()
		pic.name = "Art"
		pic.texture = art
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		pic.set_anchors_preset(Control.PRESET_FULL_RECT)
		pic.offset_left = 4.0
		pic.offset_top = 4.0
		pic.offset_right = -4.0
		pic.offset_bottom = -4.0
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(pic)
		var veil: ColorRect = ColorRect.new()
		veil.set_anchors_preset(Control.PRESET_FULL_RECT)
		veil.color = Color(col.darkened(0.7), 0.45)
		veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(veil)
	var h: HBoxContainer = HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 16.0
	h.offset_right = -16.0
	h.add_theme_constant_override("separation", 16)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var ic: UiIcon = UiIcon.make(str(BrawlEvents.INFO[mode]["icon"]), col.lightened(0.5), 92.0)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var v: VBoxContainer = VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var t: Label = Label.new()
	t.text = BrawlEvents.mode_name(mode)
	t.add_theme_font_size_override("font_size", 34)
	t.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	t.add_theme_constant_override("outline_size", 8)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(t)
	var d: Label = Label.new()
	d.text = BrawlEvents.mode_desc(mode)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.add_theme_font_size_override("font_size", 19)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(d)
	var mp: Label = Label.new()
	mp.text = Kit.text("event_map", "Mapa: {m}").format({"m": BrawlEvents.map_name(BrawlEvents.current(mode))})
	mp.add_theme_font_size_override("font_size", 18)
	mp.add_theme_color_override("font_color", col.lightened(0.55))
	mp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(mp)
	b.pressed.connect(func() -> void:
		Audio.play("click")
		BrawlEvents.play(mode))
	return b
