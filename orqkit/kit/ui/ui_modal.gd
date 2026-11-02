class_name UiModal
extends CanvasLayer
## Base de las ventanas que se abren encima del juego (ajustes, pausa, resultado).
## Oscurece el fondo, centra un panel con el tema del juego y respeta la zona segura.
## Sigue funcionando con el juego en pausa.

signal closed

var root: Control
var dim: ColorRect
var panel: PanelContainer
var body: VBoxContainer
var header: Label


func _init() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS


## 1 - Monta el marco comun: fondo oscuro, panel centrado y cabecera.
func build_frame(title_text: String, width: float = 560.0) -> void:
	root = Control.new()
	root.name = "Root"
	root.theme = UI.theme
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	dim = ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0, 0, 0, 0.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var safe: MarginContainer = UI.safe_root(root)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(center)
	panel = PanelContainer.new()
	panel.name = "Panel"
	var room: float = root.get_viewport().get_visible_rect().size.x - 64.0
	panel.custom_minimum_size = Vector2(minf(width, room), 0.0)
	center.add_child(panel)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 22)
	panel.add_child(body)
	if title_text != "":
		header = Label.new()
		header.name = "Header"
		header.theme_type_variation = "HeaderLabel"
		header.text = title_text
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(header)
	var tw: Tween = dim.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(dim, "color:a", 0.6, 0.18)
	_appear.call_deferred()


func _appear() -> void:
	UI.pop_in(panel, 0.0)
	Audio.play("ui_open", 0.04, -8.0)
	_fit_room()


## Si el panel no cabe (movil bajito, banner, idioma largo), se juntan sus filas.
func _fit_room() -> void:
	if not is_inside_tree() or body == null:
		return
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var room: float = UI.safe_rect(get_viewport()).size.y - 24.0
	if panel.get_combined_minimum_size().y > room:
		body.add_theme_constant_override("separation", 8)


## 2 - Fila de botones que se reparten el ancho.
func button_row(buttons: Array[Button]) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	for b: Button in buttons:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	body.add_child(row)
	return row


func close() -> void:
	Audio.play("ui_close", 0.04, -10.0)
	closed.emit()
	queue_free()
