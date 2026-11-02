class_name ClassPanel
extends UiModal
## Modo clase (kit/classroom.gd): unirse con el codigo del profesor o ver en que clase estas.

var _code: LineEdit
var _alias: LineEdit
var _msg: Label


static func open(host: Node) -> ClassPanel:
	var p: ClassPanel = ClassPanel.new()
	p.name = "ClassPanel"
	p.layer = 64
	host.add_child(p)
	return p


func _ready() -> void:
	build_frame(Kit.text("class_title", "Clase"), 600.0)
	_paint()


func _paint() -> void:
	for c: Node in body.get_children():
		if c == header:
			continue
		body.remove_child(c)
		c.queue_free()
	if Classroom.joined():
		var t: Label = _line(Kit.text("class_in", "Est\u00e1s en {c} como {a}").format({"c": Classroom.class_name_text(), "a": Classroom.student()}), "In")
		t.theme_type_variation = "HeaderLabel"
		_line(Kit.text("class_sync", "Tu profe ve los niveles que superas."), "Info")
		var out: Button = UI.make_button(Kit.text("class_leave", "Salir de la clase"), false, "close")
		out.name = "BtnClassLeave"
		out.pressed.connect(func() -> void:
			Classroom.leave()
			_paint())
		body.add_child(out)
	else:
		_line(Kit.text("class_ask", "Escribe el c\u00f3digo que te ha dado tu profe y tu nombre o un apodo."), "Ask")
		_code = LineEdit.new()
		_code.name = "ClassCode"
		_code.max_length = 6
		_code.placeholder_text = Kit.text("class_code", "C\u00f3digo (6 letras)")
		_code.custom_minimum_size = Vector2(480, UI.MIN_TOUCH)
		_code.alignment = HORIZONTAL_ALIGNMENT_CENTER
		body.add_child(_code)
		_alias = LineEdit.new()
		_alias.name = "ClassAlias"
		_alias.max_length = 14
		_alias.text = Online.alias()
		_alias.placeholder_text = Kit.text("class_name_hint", "Tu nombre o apodo")
		_alias.custom_minimum_size = Vector2(480, UI.MIN_TOUCH)
		_alias.alignment = HORIZONTAL_ALIGNMENT_CENTER
		body.add_child(_alias)
		_msg = _line("", "Msg")
		_msg.add_theme_color_override("font_color", UI.colors["acento"])
		var go: Button = UI.make_button(Kit.text("class_join", "Unirme"), true, "play")
		go.name = "BtnClassJoin"
		go.pressed.connect(func() -> void:
			go.disabled = true
			var err: String = await Classroom.join(_code.text, _alias.text)
			if not is_inside_tree():
				return
			if err == "":
				_paint()
			else:
				_msg.text = err
				go.disabled = false)
		body.add_child(go)
	var ok: Button = UI.make_button(Kit.text("close", "Cerrar"), false, "close")
	ok.name = "BtnClassClose"
	ok.pressed.connect(close)
	body.add_child(ok)


func _line(text: String, n: String) -> Label:
	var l: Label = Label.new()
	l.name = n
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(500, 0)
	body.add_child(l)
	return l
