class_name BrawlersPanel
extends UiModal
## Personajes de la arena (ver kit/brawl/brawlers.gd): una ficha por personaje con su dibujo,
## vida, velocidad y dano en barras, su forma de disparar y su super. Los bloqueados salen en
## sombra con los trofeos que faltan. Tocar uno libre lo elige (se juega con el en la arena).

signal changed

var _grid: GridContainer
var _top: Label

const ATTACK_TEXT: Dictionary = {
	"rafaga": ["brawler_atk_rafaga", "Ráfaga de 3"],
	"escopeta": ["brawler_atk_escopeta", "Escopeta de cerca"],
	"franco": ["brawler_atk_franco", "Tiro largo y fuerte"],
}
const SUPER_TEXT: Dictionary = {
	"ola": ["brawler_sup_ola", "Súper: onda en círculo"],
	"escudo": ["brawler_sup_escudo", "Súper: escudo 3 s"],
	"dash": ["brawler_sup_dash", "Súper: embestida"],
	"cura": ["brawler_sup_cura", "Súper: cura al equipo"],
	"bomba": ["brawler_sup_bomba", "Súper: bomba"],
}


static func open(host: Node) -> BrawlersPanel:
	var p: BrawlersPanel = BrawlersPanel.new()
	p.name = "BrawlersPanel"
	host.add_child(p)
	return p


func _ready() -> void:
	build_frame(Kit.text("brawlers", "Personajes"), 660.0)
	_top = Label.new()
	_top.name = "BrawlersInfo"
	_top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_top.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_top.theme_type_variation = "SubtleLabel"
	body.add_child(_top)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0.0, 720.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var center: CenterContainer = CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	_grid = GridContainer.new()
	_grid.name = "BrawlersGrid"
	_grid.columns = 2
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
	var cur: String = str(Brawlers.chosen()["id"])
	var n_free: int = 0
	for b: Dictionary in Brawlers.catalog():
		if Brawlers.unlocked(b):
			n_free += 1
		_grid.add_child(_card(b, str(b["id"]) == cur))
	_top.text = Kit.text("brawlers_info", "{n} de {max} desbloqueados  ·  {t} trofeos").format(
		{"n": n_free, "max": Brawlers.catalog().size(), "t": Chests.trophies()}) + "\n" \
		+ Kit.text("brawlers_hint", "Gana partidas para conseguir trofeos y desbloquear más.")


func _card(b: Dictionary, selected: bool) -> Control:
	var free: bool = Brawlers.unlocked(b)
	var tint: Color = Brawlers.tint(b)
	var card: Button = Button.new()
	card.name = "Brawler_" + str(b["id"])
	card.custom_minimum_size = Vector2(290.0, 330.0)
	card.focus_mode = Control.FOCUS_ALL
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = UI.colors.get("panel", Color(0.12, 0.12, 0.16)).darkened(0.12 if free else 0.35)
	sb.border_color = UI.colors.get("acento", Color.ORANGE) if selected else (tint.darkened(0.3) if free else Color(0.3, 0.3, 0.35))
	sb.set_border_width_all(6 if selected else 3)
	sb.set_corner_radius_all(18)
	for st: String in ["normal", "hover", "pressed", "focus"]:
		card.add_theme_stylebox_override(st, sb)
	var v: VBoxContainer = VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 12.0
	v.offset_right = -12.0
	v.offset_top = 10.0
	v.offset_bottom = -10.0
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 4)
	card.add_child(v)
	var pic: Control = Control.new()
	pic.custom_minimum_size = Vector2(0.0, 112.0)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(pic)
	var entry: Dictionary = Brawlers.sprite_entry(b)
	if not entry.is_empty():
		var spr: AnimatedSprite2D = SpriteKit.animado(entry, 104.0, "idle", free)
		spr.position = Vector2(133.0, 58.0)
		spr.self_modulate = tint
		if not free:
			spr.modulate = Color(0, 0, 0, 0.7)
		pic.add_child(spr)
	var nm: Label = Label.new()
	nm.text = str(b.get("name", b["id"]))
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.add_theme_font_size_override("font_size", 26)
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(nm)
	if not free:
		var lk: Label = Label.new()
		lk.name = "Locked"
		lk.text = Kit.text("brawler_locked", "Se gana con {t} trofeos").format({"t": int(b.get("trophies", 0))})
		lk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lk.add_theme_font_size_override("font_size", 19)
		lk.add_theme_color_override("font_color", UI.colors.get("texto_suave", Color(0.7, 0.7, 0.75)))
		lk.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(lk)
	for stat: Array in [["hp", Kit.text("stat_hp", "Vida"), Color("#5fd35f")], ["speed", Kit.text("stat_speed", "Velocidad"), Color("#4fc3ff")],
			["dmg", Kit.text("stat_dmg", "Daño"), Color("#ff6b5b")]]:
		v.add_child(_bar(str(stat[1]), float(b.get(stat[0], 1.0)), stat[2] as Color))
	for pair: Array in [ATTACK_TEXT.get(str(b.get("attack", "rafaga")), ATTACK_TEXT["rafaga"]), SUPER_TEXT.get(str(b.get("super", "ola")), SUPER_TEXT["ola"])]:
		var l: Label = Label.new()
		l.text = Kit.text(str(pair[0]), str(pair[1]))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 19)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(l)
	if selected:
		var s: Label = Label.new()
		s.name = "Selected"
		s.text = Kit.text("brawler_selected", "✔ Elegido")
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s.add_theme_color_override("font_color", UI.colors.get("acento", Color.ORANGE))
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(s)
	var id: String = str(b["id"])
	card.pressed.connect(func() -> void:
		if Brawlers.choose(id):
			Audio.play("coin")
			changed.emit()
			_refresh()
		else:
			Audio.play("hurt", 0.0, -8.0))
	return card


func _bar(label: String, k: float, col: Color) -> Control:
	var h: HBoxContainer = HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l: Label = Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(110.0, 0.0)
	l.add_theme_font_size_override("font_size", 18)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(l)
	var bar: ProgressBar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(140.0, 14.0)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.show_percentage = false
	bar.max_value = 1.5
	bar.value = clampf(k, 0.2, 1.5)
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = col
	fill.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("fill", fill)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(bar)
	return h
