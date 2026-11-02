class_name DialogPanel
extends CanvasLayer
## Dialogos entre niveles: caja abajo con el retrato del que habla (su sprite del juego), su
## nombre y el texto escribiendose. Tocar en cualquier sitio completa la frase o pasa a la
## siguiente; "Omitir" lo cierra todo. Si la frase tiene voz grabada, suena.
## Funciona con el juego en pausa.

signal finished

const CHARS_PER_SECOND: float = 42.0

## [{"who": "heroe", "text": "...", "voice": "d0_0"}]
var lines: Array = []
## {"heroe": {"name": "Bigotes", "sprite": {...entrada del manifest}}, ...}
var cast: Dictionary = {}
var index: int = -1
var _shown: float = 0.0
var _root: Control
var _box: PanelContainer
var _portrait: TextureRect
var _name: Label
var _text: Label
var _hint: Label
var _closing: bool = false


static func open(host: Node, story_lines: Array, story_cast: Dictionary) -> DialogPanel:
	var d: DialogPanel = DialogPanel.new()
	d.name = "DialogPanel"
	d.lines = story_lines
	d.cast = story_cast
	host.add_child(d)
	return d


func _init() -> void:
	layer = 70
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.theme = UI.theme
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.gui_input.connect(_on_input)
	add_child(_root)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	var safe: MarginContainer = UI.safe_root(_root)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col: VBoxContainer = VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(col)
	var gap: Control = Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(gap)
	## 2 - Abajo: retrato + nombre + texto.
	_box = PanelContainer.new()
	_box.name = "Box"
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_box)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(row)
	_portrait = TextureRect.new()
	_portrait.name = "Portrait"
	_portrait.custom_minimum_size = Vector2(150.0, 150.0)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(_portrait)
	var right: VBoxContainer = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(right)
	_name = Label.new()
	_name.name = "Name"
	_name.add_theme_color_override("font_color", UI.colors["acento"])
	right.add_child(_name)
	_text = Label.new()
	_text.name = "Text"
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(0.0, 150.0)
	right.add_child(_text)
	## 1 - Abajo: omitir (no "saltar": en el juego saltar es otra cosa) y la pista para seguir.
	var foot: HBoxContainer = HBoxContainer.new()
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(foot)
	var skip: Button = Button.new()
	skip.name = "BtnSkip"
	skip.text = Kit.text("skip_story", "Omitir")
	skip.flat = true
	skip.theme_type_variation = "SubtleLabel"
	skip.custom_minimum_size = Vector2(0.0, UI.MIN_TOUCH * 0.7)
	skip.pressed.connect(close)
	foot.add_child(skip)
	_hint = Label.new()
	_hint.name = "Hint"
	_hint.text = Kit.text("tap_continue", "Toca para seguir")
	_hint.theme_type_variation = "SubtleLabel"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(_hint)
	UI.pop_in(_box, 0.0)
	advance()


## Pasa a la siguiente frase (o cierra si no quedan).
func advance() -> void:
	index += 1
	if index >= lines.size():
		close()
		return
	var line: Dictionary = lines[index] if lines[index] is Dictionary else {}
	var who: String = str(line.get("who", "narrador"))
	var person: Dictionary = cast.get(who, {})
	_name.text = str(person.get("name", ""))
	_name.visible = _name.text != ""
	var tex: Texture2D = portrait_of(person.get("sprite", {}))
	_portrait.texture = tex
	_portrait.visible = tex != null
	## El narrador habla en cursiva: sin retrato y con el texto centrado.
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if who == "narrador" else HORIZONTAL_ALIGNMENT_LEFT
	_text.text = str(line.get("text", ""))
	_text.visible_characters = 0
	_shown = 0.0
	_hint.modulate.a = 0.0
	## Los malos hablan con el color de peligro en el nombre.
	_name.add_theme_color_override("font_color", UI.colors["peligro"] if who in ["rival", "jefe"] else UI.colors["acento"])
	var voice: String = str(line.get("voice", ""))
	if voice != "" and Kit.assets.get("voces", {}).has(voice):
		Audio.play_voice(voice)
	else:
		Audio.play("click", 0.05, -6.0)
	QA.log_event("dialog_line", {"index": index, "who": who})


func line_done() -> bool:
	return _text.visible_characters < 0 or _text.visible_characters >= _text.get_total_character_count()


func _process(delta: float) -> void:
	if _text == null or index < 0 or index >= lines.size():
		return
	if not line_done():
		_shown += delta * CHARS_PER_SECOND
		_text.visible_characters = int(_shown)
	elif _hint.modulate.a < 1.0:
		_hint.modulate.a = minf(1.0, _hint.modulate.a + delta * 3.0)


func _on_input(event: InputEvent) -> void:
	var tap: bool = (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) \
		or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	if not tap:
		return
	_root.accept_event()
	if line_done():
		advance()
	else:
		_text.visible_characters = -1


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		if line_done():
			advance()
		else:
			_text.visible_characters = -1


func close() -> void:
	if _closing:
		return
	_closing = true
	finished.emit()
	queue_free()


## Retrato: el primer frame de "idle" (o de la primera animacion) del sprite del personaje.
static func portrait_of(entry: Variant) -> Texture2D:
	if not entry is Dictionary or (entry as Dictionary).is_empty():
		return null
	var sf: SpriteFrames = SpriteKit.frames_de(entry as Dictionary)
	for anim: String in ["idle", "run", "walk", "fly"]:
		if sf.has_animation(anim) and sf.get_frame_count(anim) > 0:
			return sf.get_frame_texture(anim, 0)
	for anim: StringName in sf.get_animation_names():
		if sf.get_frame_count(anim) > 0:
			return sf.get_frame_texture(anim, 0)
	return null
