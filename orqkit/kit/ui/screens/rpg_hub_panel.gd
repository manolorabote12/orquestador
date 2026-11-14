class_name RpgHubPanel
extends UiModal
## Elegir modo en el RPG de heroes (kit/turns/rpg_modes.gd): campana, torre de pruebas (piso y premio)
## y arena (liga, puntos y entradas de hoy). Una tarjeta grande por modo, como los RPG de coleccion.

const MODES: Array = [
	["campaign", "star", "#5fae4f"],
	["tower", "trophy", "#c77d3a"],
	["arena", "sword", "#7b5cc4"],
]


static func open(host: Node) -> RpgHubPanel:
	var p: RpgHubPanel = RpgHubPanel.new()
	p.name = "RpgHubPanel"
	host.add_child(p)
	return p


func _ready() -> void:
	build_frame(Kit.text("rpg_modes", "Modos de juego"), 660.0)
	var list: VBoxContainer = VBoxContainer.new()
	list.name = "Modes"
	list.add_theme_constant_override("separation", 14)
	body.add_child(list)
	for m: Array in MODES:
		list.add_child(_card(str(m[0]), str(m[1]), Color(str(m[2]))))
	var close_b: Button = UI.make_button(Kit.text("close", "Cerrar"), false, "close")
	close_b.name = "BtnClose"
	close_b.pressed.connect(func() -> void: close())
	body.add_child(close_b)


func _texts(mode: String) -> Array:
	match mode:
		"tower":
			var n: int = RpgModes.floor_n()
			return [Kit.text("rpg_tower", "Torre de pruebas"),
				Kit.text("rpg_tower_desc", "Pisos sin fin, cada uno m\u00e1s duro. Cofre cada 5 pisos."),
				Kit.text("rpg_tower_next", "Piso {n}  ·  premio {c}").format({"n": n, "c": RpgModes.tower_reward(n)})]
		"arena":
			return [Kit.text("rpg_arena", "Arena"),
				Kit.text("rpg_arena_desc", "Lucha contra equipos de otros jugadores y sube de liga."),
				Kit.text("rpg_arena_info", "Liga {l}  ·  {p} puntos  ·  entradas {t}/{max}").format(
					{"l": RpgModes.league_name(), "p": RpgModes.rating(), "t": RpgModes.tickets(), "max": RpgModes.TICKETS})]
	return [Kit.text("rpg_campaign", "Campa\u00f1a"),
		Kit.text("rpg_campaign_desc", "La historia: cap\u00edtulo a cap\u00edtulo hasta el jefe final."),
		Kit.text("rpg_campaign_info", "Nivel {n}").format({"n": int(Save.progress().get("unlocked", 1))})]


func _card(mode: String, icon: String, col: Color) -> Control:
	var tx: Array = _texts(mode)
	var b: Button = Button.new()
	b.name = "Mode_" + mode
	b.custom_minimum_size = Vector2(600.0, 160.0)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = col.darkened(0.45)
	sb.border_color = col.lightened(0.25)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(18)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 4)
	var hov: StyleBoxFlat = sb.duplicate()
	hov.bg_color = col.darkened(0.3)
	for st: String in ["normal", "focus"]:
		b.add_theme_stylebox_override(st, sb)
	for st2: String in ["hover", "pressed"]:
		b.add_theme_stylebox_override(st2, hov)
	var h: HBoxContainer = HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 16.0
	h.offset_right = -16.0
	h.add_theme_constant_override("separation", 16)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var ic: UiIcon = UiIcon.make(icon, col.lightened(0.5), 88.0)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var v: VBoxContainer = VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	for i: int in 3:
		var l: Label = Label.new()
		l.text = str(tx[i])
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if i == 1 else TextServer.AUTOWRAP_OFF
		l.add_theme_font_size_override("font_size", [34, 19, 19][i])
		if i == 0:
			l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
			l.add_theme_constant_override("outline_size", 8)
		if i == 2:
			l.add_theme_color_override("font_color", Color(RpgModes.league()[3]) if mode == "arena" else col.lightened(0.6))
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(l)
	if mode == "arena" and RpgModes.tickets() <= 0:
		b.disabled = true
		b.modulate = Color(1, 1, 1, 0.6)
	b.pressed.connect(func() -> void:
		Audio.play("click")
		RpgModes.play(mode))
	return b
