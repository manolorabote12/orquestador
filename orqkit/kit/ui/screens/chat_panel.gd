class_name ChatPanel
extends UiModal
## Charla en directo con los personajes del juego (el heroe, el rival y el jefe).
## 1 - Arriba, el retrato y el nombre; si hay varios personajes, se elige con sus botones.
## 2 - Burbujas: las tuyas a la derecha, las del personaje a la izquierda (con "..." mientras piensa).
## 3 - Preguntas rapidas para empezar y una caja para escribir (200 letras como mucho).
## 4 - Las respuestas las da el servidor (con la IA y filtros). Sin red, el personaje contesta con
##     sus frases de la historia: nunca se queda callado.

const QUICK: Array[String] = ["chat_q_who", "chat_q_tip", "chat_q_secret"]
const QUICK_TEXT: Dictionary = {"chat_q_who": "\u00bfQui\u00e9n eres?", "chat_q_tip": "\u00bfAlg\u00fan truco para ganar?", "chat_q_secret": "Cu\u00e9ntame un secreto"}

var who: String = "heroe"
var people: Dictionary = {}
var history: Dictionary = {}
var busy: bool = false
var _portrait: TextureRect
var _name: Label
var _list: VBoxContainer
var _scroll: ScrollContainer
var _input: LineEdit
var _send: Button
var _offline_i: int = 0


static func open(host: Node) -> ChatPanel:
	var p: ChatPanel = ChatPanel.new()
	p.name = "ChatPanel"
	p.layer = 65
	host.add_child(p)
	return p


static func characters() -> Dictionary:
	var out: Dictionary = {}
	var c: Dictionary = Story.cast()
	for k: String in ["heroe", "rival", "jefe"]:
		if c.has(k) and str((c[k] as Dictionary).get("name", "")) != "":
			out[k] = c[k]
	if out.is_empty():
		out["heroe"] = {"name": Kit.text("hero_name", Kit.text("hero", "H\u00e9roe")), "sprite": Kit.sprite_by_role("jugador")}
	return out


func _ready() -> void:
	people = characters()
	who = people.keys()[0]
	build_frame("", 640.0)
	var top: HBoxContainer = HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	body.add_child(top)
	_portrait = TextureRect.new()
	_portrait.name = "Portrait"
	_portrait.custom_minimum_size = Vector2(110, 110)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	top.add_child(_portrait)
	var names: VBoxContainer = VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(names)
	_name = Label.new()
	_name.name = "Name"
	_name.theme_type_variation = "HeaderLabel"
	names.add_child(_name)
	var sub: Label = Label.new()
	sub.theme_type_variation = "SubtleLabel"
	sub.text = Kit.text("chat_live", "Charla en directo")
	names.add_child(sub)
	if people.size() > 1:
		var tabs: HBoxContainer = HBoxContainer.new()
		tabs.name = "Tabs"
		tabs.add_theme_constant_override("separation", 10)
		body.add_child(tabs)
		for k: String in people.keys():
			var t: Button = UI.make_button(str(people[k]["name"]), k == who, "")
			t.name = "Tab_" + k
			t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			t.pressed.connect(switch_to.bind(k))
			tabs.add_child(t)
	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.custom_minimum_size = Vector2(0, 430)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.name = "Messages"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 12)
	_scroll.add_child(_list)
	var quick: HBoxContainer = HBoxContainer.new()
	quick.name = "Quick"
	quick.add_theme_constant_override("separation", 8)
	body.add_child(quick)
	for q: String in QUICK:
		var b: Button = Button.new()
		b.text = Kit.text(q, str(QUICK_TEXT[q]))
		b.custom_minimum_size = Vector2(0, 88)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", 22)
		b.pressed.connect(func() -> void: send(b.text))
		quick.add_child(b)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	body.add_child(row)
	_input = LineEdit.new()
	_input.name = "Input"
	_input.max_length = 200
	_input.placeholder_text = Kit.text("chat_placeholder", "Escribe aqu\u00ed\u2026")
	_input.custom_minimum_size = Vector2(0, 88)
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.text_submitted.connect(func(t: String) -> void: send(t))
	row.add_child(_input)
	_send = UI.make_button(Kit.text("chat_send", "Enviar"), true, "play")
	_send.name = "BtnSend"
	_send.custom_minimum_size = Vector2(170, 88)
	_send.pressed.connect(func() -> void: send(_input.text))
	row.add_child(_send)
	var close_btn: Button = UI.make_button(Kit.text("close", "Cerrar"), false, "close")
	close_btn.name = "BtnClose"
	close_btn.pressed.connect(close)
	body.add_child(close_btn)
	switch_to(who)


func switch_to(k: String) -> void:
	who = k
	var p: Dictionary = people[k]
	_name.text = str(p["name"])
	_portrait.texture = DialogPanel.portrait_of(p.get("sprite", {}))
	var tabs: Node = body.get_node_or_null("Tabs")
	if tabs != null:
		for t: Node in tabs.get_children():
			(t as Button).theme_type_variation = "PrimaryButton" if t.name == "Tab_" + k else ""
	for c: Node in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var h: Array = history.get(k, [])
	if h.is_empty():
		_bubble(Kit.text("chat_hello_" + k, Kit.text("chat_hello", "\u00a1Hola! \u00bfQu\u00e9 quieres saber?")), false)
	for m: Dictionary in h:
		_bubble(str(m["texto"]), str(m["de"]) == "jugador")


func send(text: String) -> void:
	var t: String = text.strip_edges().left(200)
	if t == "" or busy:
		return
	busy = true
	_input.text = ""
	_send.disabled = true
	var target: String = who
	var h: Array = history.get(target, [])
	_bubble(t, true)
	var thinking: Label = _bubble("\u2026", false)
	var r: Dictionary = await Online.chat(target, t, h)
	var answer: String = str(r.get("texto", ""))
	if answer == "":
		answer = offline_line(target)
	h.append({"de": "jugador", "texto": t})
	h.append({"de": "personaje", "texto": answer})
	history[target] = h
	QA.log_event("chat", {"who": target, "offline": r.is_empty() or bool(r.get("offline", false))})
	if is_instance_valid(thinking):
		thinking.text = answer
		_fit(thinking)
	busy = false
	_send.disabled = false
	_scroll_down.call_deferred()


## Sin red: una frase suya de la historia (o una de siempre).
func offline_line(k: String) -> String:
	var lines: Array[String] = []
	for lv: Variant in Story.config().get("levels", []):
		if not lv is Dictionary:
			continue
		for kind: String in ["intro", "outro"]:
			for l: Variant in (lv as Dictionary).get(kind, []):
				if l is Dictionary and str((l as Dictionary).get("who", "")) == k:
					lines.append(str((l as Dictionary).get("text", "")))
	if lines.is_empty():
		lines = [Kit.text("chat_offline", "\u00a1Ahora no puedo hablar, estoy en plena aventura!")]
	_offline_i += 1
	return lines[_offline_i % lines.size()]


func _bubble(text: String, mine: bool) -> Label:
	var wrap: HBoxContainer = HBoxContainer.new()
	wrap.alignment = BoxContainer.ALIGNMENT_END if mine else BoxContainer.ALIGNMENT_BEGIN
	_list.add_child(wrap)
	var box: PanelContainer = PanelContainer.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = (UI.colors["acento"] as Color) if mine else (UI.colors["panel_hi"] as Color)
	sb.set_corner_radius_all(18)
	sb.corner_radius_bottom_right = 4 if mine else 18
	sb.corner_radius_bottom_left = 18 if mine else 4
	sb.set_content_margin_all(14)
	box.add_theme_stylebox_override("panel", sb)
	box.custom_minimum_size = Vector2(0, 0)
	wrap.add_child(box)
	var l: Label = Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fit(l)
	l.add_theme_color_override("font_color", UI.colors["acento_texto"] if mine else UI.colors["texto"])
	l.add_theme_font_size_override("font_size", 24)
	box.add_child(l)
	UI.pop_in(box, 0.0)
	_scroll_down.call_deferred()
	return l


## Ancho de la burbuja segun el texto (las cortas no ocupan toda la fila).
func _fit(l: Label) -> void:
	l.custom_minimum_size = Vector2(minf(420.0, 24.0 + 15.0 * float(l.text.length())), 0)


func _scroll_down() -> void:
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)
