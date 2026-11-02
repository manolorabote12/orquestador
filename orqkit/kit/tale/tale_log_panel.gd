class_name TaleLogPanel
extends UiModal
## Historial de la aventura: lo que ha dicho cada uno y lo que has elegido, del principio del
## capitulo hasta ahora (se abre con "Historial" arriba; el juego espera).

var lines: Array = []


static func open(host: Node, log_lines: Array) -> TaleLogPanel:
	var p: TaleLogPanel = TaleLogPanel.new()
	p.name = "TaleLogPanel"
	p.layer = 60
	p.lines = log_lines
	host.add_child(p)
	return p


func _ready() -> void:
	build_frame(Kit.text("tale_log", "Historial"), 640.0)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.custom_minimum_size = Vector2(0.0, minf(820.0, root.get_viewport().get_visible_rect().size.y - 420.0))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var list: VBoxContainer = VBoxContainer.new()
	list.name = "Lines"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	scroll.add_child(list)
	for e: Variant in lines:
		var d: Dictionary = e
		var l: Label = Label.new()
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if d.has("choice"):
			l.text = "\u25b8 " + str(d["choice"])
			l.add_theme_color_override("font_color", UI.colors["acento"])
		else:
			var who: String = str(d.get("who", ""))
			l.text = (who + ": " if who != "" else "") + str(d.get("text", ""))
			l.add_theme_font_size_override("font_size", 24)
		list.add_child(l)
	var close_btn: Button = UI.make_button(Kit.text("close", "Cerrar"), true, "close")
	close_btn.name = "BtnClose"
	close_btn.pressed.connect(close)
	body.add_child(close_btn)
	## Empieza abajo, en lo ultimo que ha pasado.
	await get_tree().process_frame
	if is_instance_valid(scroll):
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
