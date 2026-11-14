class_name HeroesPanel
extends UiModal
## Heroes del RPG (kit/turns/heroes.gd): tu coleccion con rareza, estrellas y nivel; tocar uno lo
## mete o lo saca del equipo (hasta 4) y "Subir" le sube el nivel con la moneda del juego. Los que
## aun no tienes salen en sombra (se consiguen invocando).

signal changed

var _grid: GridContainer
var _top: Label


static func open(host: Node) -> HeroesPanel:
	var p: HeroesPanel = HeroesPanel.new()
	p.name = "HeroesPanel"
	host.add_child(p)
	return p


func _ready() -> void:
	build_frame(Kit.text("heroes", "H\u00e9roes"), 680.0)
	_top = Label.new()
	_top.name = "HeroesInfo"
	_top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_top.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_top.theme_type_variation = "SubtleLabel"
	body.add_child(_top)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0.0, 760.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var center: CenterContainer = CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	_grid = GridContainer.new()
	_grid.name = "HeroesGrid"
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	center.add_child(_grid)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	body.add_child(row)
	var sum: Button = UI.make_button(Kit.text("summon", "Invocar"), true, "star")
	sum.name = "BtnSummon"
	sum.pressed.connect(func() -> void:
		var sp: SummonPanel = SummonPanel.open(get_parent())
		sp.changed.connect(func() -> void:
			changed.emit()
			_refresh()))
	row.add_child(sum)
	var close_b: Button = UI.make_button(Kit.text("close", "Cerrar"), false, "close")
	close_b.name = "BtnClose"
	close_b.pressed.connect(func() -> void: close())
	row.add_child(close_b)
	_refresh()


func _refresh() -> void:
	for c: Node in _grid.get_children():
		c.queue_free()
	var team: Array[String] = Heroes.team()
	var ids: Array = Heroes.roster().keys()
	## Primero los tuyos (los del equipo delante) y por rareza; despues los que faltan.
	ids.sort_custom(func(a: String, b: String) -> bool:
		var ka: int = (0 if team.has(a) else 1 if Heroes.owned(a) else 2) * 10 - Heroes.RARITIES.find(Heroes.rarity(a))
		var kb: int = (0 if team.has(b) else 1 if Heroes.owned(b) else 2) * 10 - Heroes.RARITIES.find(Heroes.rarity(b))
		return ka < kb)
	for id: String in ids:
		_grid.add_child(_card(id, team.has(id)))
	var syn: Dictionary = Heroes.synergy(team)
	var syn_txt: String = ""
	if float(syn["bonus"]) > 0.0:
		syn_txt = "  \u00b7  " + Kit.text("hero_synergy", "Sinergia {e} x{n}: +{p} %").format({"e": Heroes.elem_name(str(syn["element"])),
			"n": int(syn["n"]), "p": int(round(float(syn["bonus"]) * 100.0))})
	_top.text = Kit.text("hero_power", "Poder {p}").format({"p": Heroes.team_power(team)}) + syn_txt + "\n" \
		+ Kit.text("heroes_info", "{n} de {max} h\u00e9roes  \u00b7  equipo {t}/4").format(
		{"n": Heroes.owned_ids().size(), "max": ids.size(), "t": team.size()}) + "\n" \
		+ Kit.text("heroes_hint", "Toca un h\u00e9roe para meterlo o sacarlo del equipo.")


func _card(id: String, in_team: bool) -> Control:
	var d: Dictionary = Heroes.hero(id)
	var mine: bool = Heroes.owned(id)
	var rc: Color = Heroes.rarity_color(id)
	var card: Button = Button.new()
	card.name = "Hero_" + id
	card.custom_minimum_size = Vector2(200.0, 330.0)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = UI.colors.get("panel", Color(0.12, 0.12, 0.16)).darkened(0.1 if mine else 0.4)
	sb.border_color = UI.colors.get("acento", Color.ORANGE) if in_team else (rc if mine else Color(0.3, 0.3, 0.35))
	sb.set_border_width_all(6 if in_team else 3)
	sb.set_corner_radius_all(16)
	for st: String in ["normal", "hover", "pressed", "focus"]:
		card.add_theme_stylebox_override(st, sb)
	var v: VBoxContainer = VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 8.0
	v.offset_right = -8.0
	v.offset_top = 8.0
	v.offset_bottom = -8.0
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 2)
	card.add_child(v)
	var rl: Label = _lab(Kit.text("rarity_" + Heroes.rarity(id), Heroes.rarity(id).capitalize()), 15, rc)
	v.add_child(rl)
	var pic: Control = Control.new()
	pic.custom_minimum_size = Vector2(0.0, 120.0)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(pic)
	var fig: Node2D = Heroes.figure(id, 112.0)
	fig.position = Vector2(92.0, 118.0)
	if not mine:
		fig.modulate = Color(0, 0, 0, 0.7)
	pic.add_child(fig)
	v.add_child(_lab(str(d.get("name", id)), 22, Color.WHITE))
	if mine:
		v.add_child(_lab("\u2605".repeat(Heroes.stars(id)) + "\u2606".repeat(Heroes.MAX_STARS - Heroes.stars(id)), 18, Color("#ffc94d")))
		v.add_child(_lab(Kit.text("brawler_level", "Nivel %d") % Heroes.level(id), 17, Color("#c9a6ff")))
		if Heroes.level(id) < Heroes.MAX_LEVEL:
			var up: Button = UI.make_button(Kit.text("hero_up", "Subir") + " %d" % Heroes.level_cost(id), true, Store.currency_icon())
			up.name = "BtnUp"
			up.custom_minimum_size = Vector2(0.0, 48.0)
			up.add_theme_font_size_override("font_size", 17)
			up.disabled = Save.wallet() < Heroes.level_cost(id)
			up.pressed.connect(func() -> void:
				if Heroes.level_up(id):
					Audio.play("powerup")
					Juice.burst(self, up.get_global_rect().get_center(), rc, 20)
					changed.emit()
					_refresh.call_deferred())
			v.add_child(up)
		if in_team:
			v.add_child(_lab(Kit.text("hero_in_team", "\u2714 En el equipo"), 16, UI.colors.get("acento", Color.ORANGE)))
	else:
		v.add_child(_lab(Kit.text("hero_locked", "Se consigue invocando"), 15, UI.colors.get("texto_suave", Color(0.7, 0.7, 0.75))))
	card.pressed.connect(func() -> void:
		if Heroes.toggle_team(id):
			Audio.play("coin")
			changed.emit()
			_refresh()
		else:
			Audio.play("hurt", 0.0, -8.0))
	return card


func _lab(t: String, size: int, col: Color) -> Label:
	var l: Label = Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
