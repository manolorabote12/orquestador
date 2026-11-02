class_name HowToPanel
extends UiModal
## Ventana "Como se juega": las reglas del genero numeradas y un boton para empezar.
## El juego queda en pausa mientras esta abierta.

var _was_paused: bool = false


static func open(host: Node) -> HowToPanel:
	var p: HowToPanel = HowToPanel.new()
	p.name = "HowToPanel"
	p.layer = 62
	host.add_child(p)
	return p


func _ready() -> void:
	_was_paused = get_tree().paused
	get_tree().paused = true
	build_frame(Kit.text("howto_title", "C\u00f3mo se juega"), 620.0)
	var ls: Array[String] = HowTo.lines(Genres.current())
	for i: int in ls.size():
		var row: HBoxContainer = HBoxContainer.new()
		row.name = "Rule%d" % (i + 1)
		row.add_theme_constant_override("separation", 14)
		var n: Label = Label.new()
		n.text = str(i + 1)
		n.custom_minimum_size = Vector2(44.0, 0.0)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		n.theme_type_variation = "HeaderLabel"
		n.add_theme_color_override("font_color", UI.colors["acento"])
		row.add_child(n)
		var t: Label = Label.new()
		t.text = ls[i]
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(t)
		body.add_child(row)
	var go: Button = UI.make_button(Kit.text("howto_go", "\u00a1A jugar!"), true, "play")
	go.name = "BtnHowToGo"
	go.pressed.connect(close)
	body.add_child(go)


func close() -> void:
	get_tree().paused = _was_paused
	super.close()
