class_name RatePanel
extends UiModal
## "Te esta gustando?" (ver kit/rate.gd).

var _box: LineEdit


static func open(host: Node) -> RatePanel:
	var p: RatePanel = RatePanel.new()
	p.name = "RatePanel"
	p.layer = 61
	RatePrompt.asked()
	host.add_child(p)
	return p


func _ready() -> void:
	var title: String = str(Kit.config.get("title", ""))
	build_frame(Kit.text("rate_q", "\u00bfTe est\u00e1 gustando {g}?").format({"g": title}), 600.0)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	body.add_child(row)
	var yes: Button = UI.make_button(Kit.text("rate_yes", "\u00a1S\u00ed!"), true, "heart")
	yes.name = "BtnRateYes"
	yes.pressed.connect(_on_yes)
	row.add_child(yes)
	var no: Button = UI.make_button(Kit.text("rate_no", "No mucho"), false, "")
	no.name = "BtnRateNo"
	no.pressed.connect(_on_no)
	row.add_child(no)
	var later: Button = UI.make_button(Kit.text("not_now", "Ahora no"), false, "")
	later.name = "BtnRateLater"
	later.pressed.connect(close)
	body.add_child(later)


func _clear() -> void:
	for c: Node in body.get_children():
		if c == header:
			continue
		body.remove_child(c)
		c.queue_free()


func _on_yes() -> void:
	RatePrompt.answer(true)
	_clear()
	var t: Label = _line(Kit.text("rate_thanks_yes", "\u00a1Gracias! \u00bfNos dejas 5 estrellas en la tienda? Ayuda much\u00edsimo."), "Thanks")
	t.theme_type_variation = "HeaderLabel"
	var url: String = RatePrompt.store_url()
	if url != "":
		var go: Button = UI.make_button(Kit.text("rate_go", "Valorar"), true, "star")
		go.name = "BtnRateStore"
		go.pressed.connect(func() -> void:
			if not UI.test_mode:
				OS.shell_open(url)
			close())
		body.add_child(go)
	_close_button()


func _on_no() -> void:
	_clear()
	_line(Kit.text("rate_improve", "\u00bfQu\u00e9 mejorar\u00edas? Se lo contamos a quien lo ha hecho."), "Ask")
	_box = LineEdit.new()
	_box.name = "RateText"
	_box.max_length = 300
	_box.placeholder_text = Kit.text("rate_hint", "Por ejemplo: el nivel 4 es muy dif\u00edcil")
	_box.custom_minimum_size = Vector2(500, UI.MIN_TOUCH)
	body.add_child(_box)
	var send: Button = UI.make_button(Kit.text("rate_send", "Enviar"), true, "share")
	send.name = "BtnRateSend"
	send.pressed.connect(func() -> void:
		RatePrompt.answer(false, _box.text)
		_clear()
		_line(Kit.text("rate_thanks_no", "Gracias, lo tendremos en cuenta."), "Thanks")
		_close_button())
	body.add_child(send)


func _line(text: String, n: String) -> Label:
	var l: Label = Label.new()
	l.name = n
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(500, 0)
	body.add_child(l)
	return l


func _close_button() -> void:
	var ok: Button = UI.make_button(Kit.text("close", "Cerrar"), false, "close")
	ok.name = "BtnRateClose"
	ok.pressed.connect(close)
	body.add_child(ok)
