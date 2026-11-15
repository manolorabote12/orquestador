class_name HeroSheet
extends UiModal
## Ficha de un heroe (desde el libro de la casa, hero_book.gd): retrato grande, rareza, elemento,
## habilidades, nivel y estrellas; subir de nivel y meterlo o sacarlo del equipo.

signal changed

var id: String = ""


static func open(host: Node, hero_id: String) -> HeroSheet:
	var p: HeroSheet = HeroSheet.new()
	p.name = "HeroSheet"
	p.id = hero_id
	host.add_child(p)
	return p


func _ready() -> void:
	var mine: bool = Heroes.owned(id)
	build_frame(Heroes.display_name(id) if mine else Kit.text("hero_unknown", "Sin firmar"), 640.0)
	_fill()


func _fill() -> void:
	for c: Node in body.get_children():
		c.queue_free()
	var mine: bool = Heroes.owned(id)
	var d: Dictionary = Heroes.hero(id)
	var el: String = str(d.get("element", ""))
	var pic: Control = Control.new()
	pic.name = "Portrait"
	pic.custom_minimum_size = Vector2(0, 520)
	pic.clip_contents = true
	body.add_child(pic)
	var tex: Texture2D = HeroBook.portrait(id)
	if tex != null:
		var tr: TextureRect = TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		if not mine:
			tr.modulate = Color(0.12, 0.1, 0.16)
		pic.add_child(tr)
	else:
		var fig: Node2D = Heroes.figure(id, 300.0)
		fig.position = Vector2(300, 500)
		if not mine:
			fig.modulate = Color(0, 0, 0, 0.7)
		pic.add_child(fig)
	var rc: Color = Heroes.rarity_color(id)
	body.add_child(_lab(Kit.text("rarity_" + Heroes.rarity(id), Heroes.rarity(id).capitalize()) + "  ·  " + Heroes.elem_name(el), 22, rc))
	body.add_child(_lab(", ".join(Heroes.skill_names(id)), 19, Heroes.ELEM_COL.get(el, Color(0.85, 0.85, 0.9)).lightened(0.35)))
	if not mine:
		body.add_child(_lab(Kit.text("hero_locked", "Se consigue invocando"), 20, UI.colors["texto_suave"]))
		var close0: Button = UI.make_button(Kit.text("close", "Cerrar"), false, "close")
		close0.pressed.connect(func() -> void: close())
		body.add_child(close0)
		return
	body.add_child(_lab("★".repeat(Heroes.stars(id)) + "☆".repeat(Heroes.MAX_STARS - Heroes.stars(id)) + "    " + Kit.text("brawler_level", "Nivel %d") % Heroes.level(id), 24, Color("#ffd23f")))
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	body.add_child(row)
	if Heroes.level(id) < Heroes.MAX_LEVEL:
		var up: Button = UI.make_button(Kit.text("hero_up", "Subir") + "  %d" % Heroes.level_cost(id), true, "coin")
		up.name = "BtnUp"
		up.disabled = Save.wallet() < Heroes.level_cost(id)
		up.pressed.connect(func() -> void:
			if Heroes.level_up(id):
				Audio.play("powerup")
				Juice.burst(self, up.get_global_rect().get_center(), Heroes.rarity_color(id), 22)
				changed.emit()
				_fill.call_deferred())
		row.add_child(up)
	var in_team: bool = Heroes.team().has(id)
	var tm: Button = UI.make_button(Kit.text("hero_out", "Sacar del equipo") if in_team else Kit.text("hero_in", "Al equipo"), not in_team, "")
	tm.name = "BtnTeam"
	tm.pressed.connect(func() -> void:
		if Heroes.toggle_team(id):
			Audio.play("coin")
			changed.emit()
			_fill.call_deferred()
		else:
			Audio.play("hurt", 0.0, -8.0)
			UI.float_text(self, tm.get_global_rect().get_center(), Kit.text("team_full", "El equipo ya tiene 4"), UI.colors["acento"], 26))
	row.add_child(tm)
	var close_b: Button = UI.make_button(Kit.text("close", "Cerrar"), false, "close")
	close_b.name = "BtnClose"
	close_b.pressed.connect(func() -> void: close())
	body.add_child(close_b)


func _lab(t: String, size: int, col: Color) -> Label:
	var l: Label = Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l
