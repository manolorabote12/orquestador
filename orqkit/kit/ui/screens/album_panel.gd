class_name AlbumPanel
extends UiModal
## Album: las cartas del juego en una cuadricula (ver kit/album.gd). Las que no tienes salen en
## sombra con «?». En cada una: rareza (color del borde), nivel, copias para subir y el boton de
## subir con su precio. Arriba, cuantas tienes y el bonus de monedas que te da el album.

signal changed

var _grid: GridContainer
var _top: Label


static func open(host: Node) -> AlbumPanel:
	var p: AlbumPanel = AlbumPanel.new()
	p.name = "AlbumPanel"
	host.add_child(p)
	return p


func _ready() -> void:
	build_frame(Kit.text("album", "Álbum"), 640.0)
	_top = Label.new()
	_top.name = "AlbumInfo"
	_top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_top.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_top.theme_type_variation = "SubtleLabel"
	body.add_child(_top)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0.0, 700.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var center: CenterContainer = CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	_grid = GridContainer.new()
	_grid.name = "AlbumGrid"
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 14)
	_grid.add_theme_constant_override("v_separation", 14)
	center.add_child(_grid)
	var close_b: Button = UI.make_button(Kit.text("close", "Cerrar"), false, "close")
	close_b.name = "BtnClose"
	close_b.pressed.connect(func() -> void: close())
	body.add_child(close_b)
	_refresh()


func _refresh() -> void:
	for c: Node in _grid.get_children():
		c.queue_free()
	var cs: Array[Dictionary] = Album.cards()
	_top.text = Kit.text("album_info", "%d de %d cartas  ·  +%d %% de monedas") % [Album.count_owned(), cs.size(), int(round(Album.bonus() * 100.0))] \
		+ "\n" + Kit.text("album_hint", "Salen en los cofres. Las repetidas suben la carta de nivel.")
	for c: Dictionary in cs:
		_grid.add_child(_card(c))


func _card(c: Dictionary) -> Control:
	var id: String = str(c["sprite"])
	var e: Dictionary = Album.entry(id)
	var lvl: int = int(e.get("lvl", 0))
	var have: bool = lvl >= 1
	var col: Color = Album.rarity_color(str(c.get("rarity", "comun")))
	var card: PanelContainer = PanelContainer.new()
	card.name = "Card_" + id
	card.custom_minimum_size = Vector2(180.0, 270.0)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = UI.colors.get("panel", Color(0.12, 0.12, 0.16)).darkened(0.15)
	sb.border_color = col if have else col.darkened(0.6)
	sb.set_border_width_all(5)
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", sb)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	card.add_child(v)
	var pic: Control = Control.new()
	pic.custom_minimum_size = Vector2(160.0, 120.0)
	pic.clip_contents = true
	v.add_child(pic)
	var entry: Dictionary = Kit.sprite_entry(id)
	if not entry.is_empty():
		var spr: AnimatedSprite2D = SpriteKit.animado(entry, 104.0, "idle", false)
		spr.position = Vector2(80.0, 60.0)
		if not have:
			spr.modulate = Color(0, 0, 0, 0.75)
			spr.stop()
		pic.add_child(spr)
	if not have:
		var q: Label = Label.new()
		q.text = "?"
		q.theme_type_variation = "HeaderLabel"
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q.set_anchors_preset(Control.PRESET_CENTER)
		q.position = Vector2(64.0, 30.0)
		pic.add_child(q)
	var nm: Label = Label.new()
	nm.text = str(c.get("name", id)) if have else "???"
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.clip_text = true
	nm.custom_minimum_size = Vector2(160.0, 0.0)
	nm.add_theme_font_size_override("font_size", 22)
	v.add_child(nm)
	var lv: Label = Label.new()
	lv.name = "Level"
	lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv.add_theme_font_size_override("font_size", 20)
	lv.add_theme_color_override("font_color", col)
	lv.text = (Kit.text("album_level", "Nivel %d") % lvl) if have else Kit.text("album_locked", "Sin descubrir")
	v.add_child(lv)
	if have and lvl < Album.MAX_LEVEL:
		var bar: ProgressBar = ProgressBar.new()
		bar.custom_minimum_size = Vector2(0, 14)
		bar.show_percentage = false
		bar.max_value = Album.need(lvl)
		bar.value = mini(int(e.get("n", 0)), Album.need(lvl))
		v.add_child(bar)
		var b: Button = UI.make_button("%d" % Album.cost(lvl), Album.can_upgrade(id), "coin")
		b.name = "Up_" + id
		b.custom_minimum_size = Vector2(0, 56)
		b.disabled = not Album.can_upgrade(id)
		b.tooltip_text = "%d/%d" % [int(e.get("n", 0)), Album.need(lvl)]
		b.pressed.connect(func() -> void:
			if Album.upgrade(id):
				Audio.play("powerup")
				Juice.burst(root, card.get_global_rect().get_center(), col, 28)
				changed.emit()
				_refresh())
		v.add_child(b)
	elif have:
		var mx: Label = Label.new()
		mx.text = Kit.text("album_max", "¡Al máximo!")
		mx.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mx.add_theme_color_override("font_color", col)
		v.add_child(mx)
	return card
