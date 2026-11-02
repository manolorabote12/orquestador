class_name LevelUpPanel
extends UiModal
## Subida de nivel en las hordas: el juego se pausa y eliges 1 de 3 mejoras.
## Cada opcion es un boton grande con su nombre y lo que hace.

signal chosen(index: int)

var options: Array[Dictionary] = []


static func open(host: Node, opts: Array[Dictionary]) -> LevelUpPanel:
	var p: LevelUpPanel = LevelUpPanel.new()
	p.name = "LevelUpPanel"
	p.options = opts
	host.add_child(p)
	return p


func _ready() -> void:
	build_frame(Kit.text("level_up", "Subes de nivel"))
	for i: int in options.size():
		var o: Dictionary = options[i]
		var b: Button = UI.make_button("", i == 0, "")
		b.name = "Option%d" % i
		b.custom_minimum_size = Vector2(0.0, 124.0)
		b.pressed.connect(_pick.bind(i))
		body.add_child(b)
		## 1 - Nombre grande y descripcion debajo, con salto de linea si no cabe.
		var box: VBoxContainer = VBoxContainer.new()
		box.set_anchors_preset(Control.PRESET_FULL_RECT)
		box.offset_left = 24.0
		box.offset_right = -24.0
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(box)
		var t: Label = Label.new()
		t.text = str(o.get("title", ""))
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(t)
		var d: Label = Label.new()
		d.text = str(o.get("desc", ""))
		d.theme_type_variation = "SubtleLabel"
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(d)


func _pick(i: int) -> void:
	chosen.emit(i)
	queue_free()
