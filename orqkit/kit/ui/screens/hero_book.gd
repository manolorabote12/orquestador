class_name HeroBook
extends Control
## Coleccion de heroes como seccion de la casa propia (game_hub.gd, pestana "heroes" con layout
## "libro"): cada heroe es una carta grande con su retrato pintado (retrato_<id> de la casa), el sello de
## su elemento, su nivel y sus estrellas; los que faltan, en sombra. Tocar una abre su ficha: subir de
## nivel y meterlo o sacarlo del equipo. Los sistemas son los de siempre (kit/turns/heroes.gd).
##
## "heroes": {"layout": "libro", "title": "Libro de contratos", "fondo": "res://...", "card": "pergamino"|"oscura"}

signal changed

var hub: GameHub
var cfg: Dictionary = {}
var _grid: GridContainer
var _info: Label
var _filter: String = ""


func _ready() -> void:
	var bg: Texture2D = GameHub.tex(str(cfg.get("fondo", "")))
	if bg != null:
		var tr: TextureRect = TextureRect.new()
		tr.name = "Backdrop"
		tr.texture = bg
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tr)
	else:
		var cr: ColorRect = ColorRect.new()
		cr.color = UI.colors["fondo"].darkened(0.2)
		cr.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(cr)
	var col: VBoxContainer = VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 26.0
	col.offset_right = -26.0
	col.offset_top = 132.0
	col.offset_bottom = -8.0
	col.add_theme_constant_override("separation", 10)
	add_child(col)
	var title: Label = Label.new()
	title.name = "BookTitle"
	title.text = str(cfg.get("title", Kit.text("heroes", "Héroes")))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color("#f6e7c2"))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	title.add_theme_constant_override("outline_size", 9)
	col.add_child(title)
	_info = Label.new()
	_info.name = "BookInfo"
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.add_theme_font_size_override("font_size", 20)
	_info.add_theme_color_override("font_color", Color("#f3e3b5"))
	_info.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_info.add_theme_constant_override("outline_size", 6)
	col.add_child(_info)
	col.add_child(_filters())
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var center: CenterContainer = CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	_grid = GridContainer.new()
	_grid.name = "BookGrid"
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 16)
	_grid.add_theme_constant_override("v_separation", 26)
	center.add_child(_grid)
	refresh()


static func portrait(id: String) -> Texture2D:
	var casa: Dictionary = ((Kit.assets.get("ui", {}) as Dictionary).get("casa", {})) as Dictionary
	var hub_cfg: Dictionary = Kit.config.get("hub", {}) as Dictionary
	var own: Dictionary = ((hub_cfg.get("heroes", {}) as Dictionary).get("portraits", {})) as Dictionary
	if own.has(id):
		return GameHub.tex(str(own[id]))
	if casa.has("retrato_" + id):
		return GameHub.tex(str(casa["retrato_" + id]))
	## El lider del equipo base es el protagonista del juego (su retrato es el del heroe).
	var base_party: Array = TurnsParty.catalog({"rpg": Heroes._rpg()}).get("party", [])
	if not base_party.is_empty() and str(base_party[0]) == id and casa.has("retrato_heroe"):
		return GameHub.tex(str(casa["retrato_heroe"]))
	return null


static func seal(el: String) -> Texture2D:
	var casa: Dictionary = ((Kit.assets.get("ui", {}) as Dictionary).get("casa", {})) as Dictionary
	var hub_cfg: Dictionary = Kit.config.get("hub", {}) as Dictionary
	var own: Dictionary = ((hub_cfg.get("heroes", {}) as Dictionary).get("seals", {})) as Dictionary
	if own.has(el):
		return GameHub.tex(str(own[el]))
	if casa.has("sello_" + el):
		return GameHub.tex(str(casa["sello_" + el]))
	return null


func _filters() -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Filters"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	var els: Array[String] = [""]
	for id: String in Heroes.roster():
		var e: String = str(Heroes.hero(id).get("element", ""))
		if e != "" and not els.has(e):
			els.append(e)
	for e: String in els:
		var b: Button = Button.new()
		b.name = "Filter_" + (e if e != "" else "all")
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(64, 64)
		var face: Control = Control.new()
		face.set_anchors_preset(Control.PRESET_FULL_RECT)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.draw.connect(func() -> void:
			var c: Vector2 = face.size * 0.5
			var on: bool = _filter == e
			if on:
				face.draw_circle(c, 31.0, Color(UI.colors["acento"], 0.55))
			var t: Texture2D = seal(e) if e != "" else null
			if t != null:
				face.draw_texture_rect(t, Rect2(c - Vector2(26, 26), Vector2(52, 52)), false, Color.WHITE if on or _filter == "" else Color(0.7, 0.7, 0.7))
			else:
				face.draw_circle(c, 24.0, Heroes.ELEM_COL.get(e, Color("#f6e7c2")) if e != "" else Color("#f6e7c2"))
				face.draw_arc(c, 24.0, 0.0, TAU, 32, Color("#2a1a33"), 3.0, true))
		b.add_child(face)
		b.pressed.connect(func() -> void:
			_filter = e
			Audio.play("click")
			for x: Node in row.get_children():
				for y: Node in x.get_children():
					(y as Control).queue_redraw()
			refresh())
		row.add_child(b)
	return row


func refresh() -> void:
	for c: Node in _grid.get_children():
		c.queue_free()
	var team: Array[String] = Heroes.team()
	var ids: Array = Heroes.roster().keys()
	ids.sort_custom(func(a: String, b: String) -> bool:
		var ka: int = (0 if team.has(a) else 1 if Heroes.owned(a) else 2) * 10 - Heroes.RARITIES.find(Heroes.rarity(a))
		var kb: int = (0 if team.has(b) else 1 if Heroes.owned(b) else 2) * 10 - Heroes.RARITIES.find(Heroes.rarity(b))
		return ka < kb)
	var n_own: int = 0
	for id: String in ids:
		if Heroes.owned(id):
			n_own += 1
		if _filter != "" and str(Heroes.hero(id).get("element", "")) != _filter:
			continue
		_grid.add_child(_card(id, team.has(id)))
	_info.text = Kit.text("book_info", "{n} de {max} firmados  ·  equipo {t}/4  ·  poder {p}").format(
		{"n": n_own, "max": ids.size(), "t": team.size(), "p": Heroes.team_power(team)})
	if hub != null:
		hub.refresh()


func _card(id: String, in_team: bool) -> Control:
	var mine: bool = Heroes.owned(id)
	var el: String = str(Heroes.hero(id).get("element", ""))
	var rc: Color = Heroes.rarity_color(id)
	var dark: bool = str(cfg.get("card", "pergamino")) == "oscura"
	var b: Button = Button.new()
	b.name = "Hero_" + id
	b.custom_minimum_size = Vector2(196, 300)
	b.focus_mode = Control.FOCUS_NONE
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color("#2a2030") if dark else Color("#f3e6c6")
	sb.border_color = UI.colors["acento"] if in_team else (rc.darkened(0.15) if mine else Color("#6b5a48"))
	sb.set_border_width_all(6 if in_team else 4)
	sb.set_corner_radius_all(10)
	sb.corner_radius_bottom_left = 30
	sb.corner_radius_bottom_right = 30
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, 5)
	for st: String in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, sb)
	## Retrato: ocupa la carta (recortado arriba); sin retrato, la figura del juego.
	var pic: Control = Control.new()
	pic.set_anchors_preset(Control.PRESET_FULL_RECT)
	pic.offset_left = 6.0
	pic.offset_top = 6.0
	pic.offset_right = -6.0
	pic.offset_bottom = -58.0
	pic.clip_contents = true
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(pic)
	var tex: Texture2D = portrait(id)
	if tex != null:
		var tr: TextureRect = TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not mine:
			tr.modulate = Color(0.12, 0.1, 0.16)
		pic.add_child(tr)
	else:
		var fig: Node2D = Heroes.figure(id, 170.0)
		fig.position = Vector2(92, 228)
		if not mine:
			fig.modulate = Color(0, 0, 0, 0.7)
		pic.add_child(fig)
	if not mine:
		var q: Label = Label.new()
		q.text = "?"
		q.set_anchors_preset(Control.PRESET_FULL_RECT)
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		q.add_theme_font_size_override("font_size", 90)
		q.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
		pic.add_child(q)
	## Nombre en la parte de abajo de la carta.
	var nm: Label = Label.new()
	nm.text = Heroes.display_name(id) if mine else Kit.text("hero_unknown", "Sin firmar")
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	nm.offset_top = -58.0
	nm.offset_bottom = -26.0
	nm.add_theme_font_size_override("font_size", 22)
	nm.add_theme_color_override("font_color", Color("#f6e7c2") if dark else Color("#2a1a33"))
	nm.clip_text = true
	b.add_child(nm)
	if mine:
		var lv: Label = Label.new()
		lv.text = Kit.text("lv_short", "nv %d") % Heroes.level(id)
		lv.position = Vector2(10, 10)
		lv.add_theme_font_size_override("font_size", 18)
		var lsb: StyleBoxFlat = StyleBoxFlat.new()
		lsb.bg_color = Color("#2a1a33")
		lsb.set_corner_radius_all(8)
		lsb.content_margin_left = 7.0
		lsb.content_margin_right = 7.0
		lv.add_theme_stylebox_override("normal", lsb)
		lv.add_theme_color_override("font_color", Color("#f6e7c2"))
		b.add_child(lv)
		var st: Label = Label.new()
		st.text = "★".repeat(Heroes.stars(id))
		st.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		st.offset_left = -110.0
		st.offset_right = -10.0
		st.offset_top = 8.0
		st.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		st.add_theme_font_size_override("font_size", 20)
		st.add_theme_color_override("font_color", Color("#ffd23f"))
		st.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		st.add_theme_constant_override("outline_size", 6)
		b.add_child(st)
	## Sello de cera del elemento, montado sobre el borde de abajo.
	var sl: Control = Control.new()
	sl.custom_minimum_size = Vector2(56, 56)
	sl.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	sl.offset_left = -28.0
	sl.offset_right = 28.0
	sl.offset_top = -30.0
	sl.offset_bottom = 26.0
	sl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stex: Texture2D = seal(el)
	sl.draw.connect(func() -> void:
		if stex != null:
			sl.draw_texture_rect(stex, Rect2(Vector2.ZERO, sl.size), false, Color.WHITE if mine else Color(0.5, 0.5, 0.5))
		else:
			sl.draw_circle(sl.size * 0.5, 22.0, Heroes.ELEM_COL.get(el, Color("#b0bec5")))
			sl.draw_arc(sl.size * 0.5, 22.0, 0.0, TAU, 32, Color(0, 0, 0, 0.35), 3.0, true))
	b.add_child(sl)
	if in_team:
		var rib: Label = Label.new()
		rib.text = Kit.text("hero_in_team_short", "En el equipo")
		rib.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rib.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		rib.offset_top = 200.0
		rib.offset_bottom = 228.0
		var rsb: StyleBoxFlat = StyleBoxFlat.new()
		rsb.bg_color = Color(UI.colors["acento"], 0.92)
		rib.add_theme_stylebox_override("normal", rsb)
		rib.add_theme_color_override("font_color", Color("#2a1a33"))
		rib.add_theme_font_size_override("font_size", 17)
		b.add_child(rib)
	b.pressed.connect(func() -> void:
		Audio.play("click")
		var sheet: HeroSheet = HeroSheet.open(self, id)
		sheet.changed.connect(func() -> void:
			changed.emit()
			refresh()))
	return b
