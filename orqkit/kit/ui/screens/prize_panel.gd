class_name PrizePanel
extends UiModal
## El premio real (ver kit/prize.gd). Ganado: el codigo en grande, copiar y abrir la web del
## negocio. Por ganar: lo que hay que hacer para conseguirlo.
## claim_level >= 0 lo abre la pantalla de nivel superado: primero cobra el premio.

var claim_level: int = -1
var _code: Label


static func open(host: Node, claim_at: int = -1) -> PrizePanel:
	var p: PrizePanel = PrizePanel.new()
	p.name = "PrizePanel"
	p.layer = 62
	p.claim_level = claim_at
	host.add_child(p)
	return p


func _ready() -> void:
	build_frame(Kit.text("prize_title", "Tu premio"), 600.0)
	if claim_level >= 0 and not Prize.has_won():
		var wait: Label = _line(Kit.text("prize_wait", "Preparando tu premio..."), "Wait")
		var got: Dictionary = await Prize.claim(claim_level)
		if not is_inside_tree():
			return
		wait.queue_free()
		if got.is_empty():
			_line(Kit.text("prize_fail", "No se pudo conseguir ahora. Vuelve a la portada y pulsa Premio."), "Fail")
			_close_button()
			return
		Audio.play_voice("victoria")
	if Prize.has_won():
		_show_won(Prize.won())
	elif Prize.info().is_empty():
		_line(Kit.text("prize_none", "Ahora mismo no hay premio. \u00a1Vuelve pronto!"), "None")
	else:
		var goal: Label = _line(Prize.goal_text(), "Goal")
		goal.theme_type_variation = "HeaderLabel"
		var d: Dictionary = Prize.info()
		if str(d.get("donde", "")) != "":
			_line(str(d["donde"]), "Where")
		var exp: String = Prize.expiry_text(d)
		if exp != "":
			_line(exp, "Until")
	_close_button()


func _show_won(w: Dictionary) -> void:
	var t: Label = _line(str(w.get("texto", "")), "What")
	t.theme_type_variation = "HeaderLabel"
	_code = _line(str(w.get("codigo", "")), "Code")
	_code.add_theme_font_size_override("font_size", 56)
	_code.add_theme_color_override("font_color", UI.colors["acento"])
	UI.pop_in(_code, 0.3)
	var how: String = Kit.text("prize_show", "Ens\u00e9\u00f1alo o escr\u00edbelo al pagar")
	if str(w.get("donde", "")) != "":
		how += "\n" + str(w["donde"])
	_line(how, "How")
	var exp: String = Prize.expiry_text(w)
	if exp != "":
		_line(exp, "Until")
	var copy: Button = UI.make_button(Kit.text("prize_copy", "Copiar c\u00f3digo"), true, "share")
	copy.name = "BtnPrizeCopy"
	copy.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(str(w.get("codigo", "")))
		copy.text = Kit.text("prize_copied", "Copiado"))
	body.add_child(copy)
	if str(w.get("web", "")) != "":
		var web: Button = UI.make_button(Kit.text("prize_web", "Ir a la web"), false, "play")
		web.name = "BtnPrizeWeb"
		web.pressed.connect(func() -> void:
			if not UI.test_mode:
				OS.shell_open(str(w["web"])))
		body.add_child(web)


func _line(text: String, n: String) -> Label:
	var l: Label = Label.new()
	l.name = n
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(480, 0)
	body.add_child(l)
	return l


func _close_button() -> void:
	var ok: Button = UI.make_button(Kit.text("close", "Cerrar"), false, "close")
	ok.name = "BtnPrizeClose"
	ok.pressed.connect(close)
	body.add_child(ok)
