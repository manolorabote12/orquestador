class_name GiftPanel
extends UiModal
## Juego regalo (ver kit/gift.gd). mode "intro": para quien es y que hay un mensaje escondido.
## "reveal": el mensaje secreto (al superar el nivel elegido). "show": volver a leerlo.

var mode: String = "show"


static func open(host: Node, m: String = "show") -> GiftPanel:
	var p: GiftPanel = GiftPanel.new()
	p.name = "GiftPanel"
	p.layer = 63
	p.mode = m
	host.add_child(p)
	return p


func _ready() -> void:
	var d: Dictionary = Gift.info()
	if mode == "intro":
		Save.set_setting("regalo_intro", true)
	if mode == "reveal":
		Gift.mark_revealed()
		Audio.play_voice("victoria")
	var title: String = Kit.text("gift_title", "Un regalo para ti") if mode == "intro" else Kit.text("gift_msg_title", "Tu mensaje")
	build_frame(title, 620.0)
	var head: Label = _line(Gift.headline(), "Head")
	head.theme_type_variation = "HeaderLabel"
	head.add_theme_color_override("font_color", UI.colors["acento"])
	if mode == "intro":
		_line(Kit.text("gift_hidden", "Hay un mensaje escondido: aparece al superar el nivel {n}.").format({"n": Gift.goal_level()}), "Hint")
		var go: Button = UI.make_button(Kit.text("gift_start", "\u00a1A jugar!"), true, "play")
		go.name = "BtnGiftGo"
		go.pressed.connect(close)
		body.add_child(go)
		return
	if not Gift.revealed():
		_line(Kit.text("gift_hidden", "Hay un mensaje escondido: aparece al superar el nivel {n}.").format({"n": Gift.goal_level()}), "Hint")
	else:
		var msg: Label = _line(str(d.get("mensaje", "")), "Message")
		msg.add_theme_font_size_override("font_size", 34)
		UI.pop_in(msg, 0.35)
	var ok: Button = UI.make_button(Kit.text("close", "Cerrar"), mode != "reveal", "close")
	ok.name = "BtnGiftClose"
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
