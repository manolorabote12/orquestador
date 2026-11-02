class_name CrossPanel
extends UiModal
## Promocion cruzada: "Mas juegos del mismo creador" (game.json -> "cross": [{title, url, genre}]).
## Lo rellena la fabrica con los otros juegos del autor (en Google Play o para jugar en la web).
## Cada toque se apunta (QA "cross_click") para saber que juego trae a mas jugadores.


static func games() -> Array:
	var out: Array = []
	for g: Variant in Kit.config.get("cross", []):
		if g is Dictionary and str((g as Dictionary).get("url", "")).begins_with("https://") and str(g.get("title", "")) != "":
			out.append(g)
	return out.slice(0, 6)


static func open(host: Node) -> CrossPanel:
	var p: CrossPanel = CrossPanel.new()
	p.name = "CrossPanel"
	host.add_child(p)
	return p


func _ready() -> void:
	build_frame(Kit.text("cross_title", "M\u00e1s juegos del creador"))
	for g: Variant in games():
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		body.add_child(row)
		var name_lbl: Label = Label.new()
		name_lbl.text = str(g["title"])
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(name_lbl)
		var b: Button = UI.make_button(Kit.text("cross_play", "Jugar"), true, "play")
		b.name = "BtnCross"
		var url: String = str(g["url"])
		b.pressed.connect(func() -> void:
			QA.log_event("cross_click", {"title": str(g["title"]), "url": url})
			if not UI.test_mode:
				OS.shell_open(url))
		row.add_child(b)
	var close_b: Button = UI.make_button(Kit.text("close", "Cerrar"), false, "close")
	close_b.name = "BtnClose"
	close_b.pressed.connect(close)
	body.add_child(close_b)
