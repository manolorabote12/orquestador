extends Control
## Selector de niveles: rejilla con numero, estrellas conseguidas y candado en los bloqueados.
## Con mas de WORLD_MIN niveles, agrupados en mundos de WORLD_SIZE: cabecera con su nombre y sus
## estrellas, un tinte distinto por mundo y, si aun no has llegado, "supera el mundo anterior".

const WORLD_SIZE: int = 5
const WORLD_MIN: int = 7

var grid: GridContainer
var grids: Array[GridContainer] = []
var _ta_button: Button
var _ex_button: Button


func _ready() -> void:
	Versus.stop()
	Marathon.stop()
	theme = UI.theme
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg: ColorRect = ColorRect.new()
	bg.color = UI.colors["fondo"]
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var root: MarginContainer = UI.safe_root(self)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 28)
	root.add_child(col)

	## 1 - Barra superior: volver, titulo centrado y total de estrellas.
	var bar: HBoxContainer = HBoxContainer.new()
	bar.add_theme_constant_override("separation", 12)
	col.add_child(bar)
	var back: Button = UI.make_icon_button("back")
	back.name = "BtnBack"
	back.pressed.connect(func() -> void: UI.goto(UI.SCREEN_TITLE))
	bar.add_child(back)
	var header: Label = Label.new()
	header.name = "Header"
	header.theme_type_variation = "HeaderLabel"
	header.text = Kit.text("levels", "Niveles")
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(header)
	var total_box: HBoxContainer = HBoxContainer.new()
	total_box.custom_minimum_size = Vector2(UI.MIN_TOUCH + 8.0, 0.0)
	total_box.alignment = BoxContainer.ALIGNMENT_END
	total_box.add_theme_constant_override("separation", 6)
	bar.add_child(total_box)
	total_box.add_child(UiIcon.make("star", UI.colors["acento"], 36.0))
	var total: Label = Label.new()
	total.name = "StarsTotal"
	total.text = str(_stars_total())
	total_box.add_child(total)

	## 1b - Contrarreloj: rejuega los niveles contra tu mejor tiempo (cambia estrellas por tiempos).
	if TimeAttack.available():
		_ta_button = UI.make_button("", false, "")
		_ta_button.name = "BtnTimeAttack"
		_ta_button.toggle_mode = true
		_ta_button.button_pressed = TimeAttack.active()
		_ta_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_ta_button.custom_minimum_size = Vector2(420, UI.MIN_TOUCH)
		_ta_button.toggled.connect(func(on: bool) -> void:
			if on:
				Expert.stop()
				TimeAttack.start()
			else:
				TimeAttack.stop()
			_show_mode())
		col.add_child(_ta_button)
	else:
		TimeAttack.stop()
	## 1c - Experto: los niveles superados con un giro dificil; medalla por nivel.
	if Expert.available():
		_ex_button = UI.make_button("", false, "")
		_ex_button.name = "BtnExpert"
		_ex_button.toggle_mode = true
		_ex_button.button_pressed = Expert.active()
		_ex_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_ex_button.custom_minimum_size = Vector2(420, UI.MIN_TOUCH)
		_ex_button.toggled.connect(func(on: bool) -> void:
			if on:
				Expert.start()
			else:
				Expert.stop()
			_show_mode())
		col.add_child(_ex_button)
	else:
		Expert.stop()
	## 2 - Rejilla con desplazamiento por si el juego tiene muchos niveles.
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 26)
	scroll.add_child(list)
	var unlocked: int = Save.unlocked_count()
	var count: int = Kit.level_count()
	var per: int = WORLD_SIZE if count >= WORLD_MIN else maxi(count, 1)
	var w: int = 0
	var start: int = 0
	while start < count:
		var end: int = mini(start + per, count)
		if per < count:
			list.add_child(_world_header(w, start, end, start < unlocked))
		var center: CenterContainer = CenterContainer.new()
		center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_child(center)
		var g: GridContainer = GridContainer.new()
		g.name = "World%d" % (w + 1)
		g.columns = 3
		g.add_theme_constant_override("h_separation", 24)
		g.add_theme_constant_override("v_separation", 24)
		center.add_child(g)
		for i: int in range(start, end):
			g.add_child(_level_button(i, i < unlocked))
		grids.append(g)
		start = end
		w += 1
	grid = grids[0] if not grids.is_empty() else GridContainer.new()
	_show_mode()
	_intro.call_deferred()


## Estrellas o mejores tiempos segun el modo, y el texto del interruptor.
func _show_mode() -> void:
	var on: bool = TimeAttack.active()
	var ex: bool = Expert.active()
	if _ta_button != null and _ta_button.button_pressed != on:
		_ta_button.set_pressed_no_signal(on)
	if _ex_button != null:
		_ex_button.set_pressed_no_signal(ex)
		_ex_button.text = Kit.text("ex_short", "Experto") + ": " + (Kit.text("ta_on", "s\u00ed") if ex else Kit.text("ta_off", "no"))
		_ex_button.theme_type_variation = "PrimaryButton" if ex else ""
	if _ta_button != null:
		_ta_button.text = Kit.text("ta_short", "Contrarreloj") + ": " + (Kit.text("ta_on", "s\u00ed") if on else Kit.text("ta_off", "no"))
		_ta_button.theme_type_variation = "PrimaryButton" if on else ""
	for g: GridContainer in grids:
		for b: Node in g.get_children():
			var stars_row: Node = b.get_node_or_null("Stars")
			var best_l: Node = b.get_node_or_null("Best")
			if stars_row != null:
				(stars_row as CanvasItem).visible = not on
			if best_l != null:
				(best_l as CanvasItem).visible = on
			var medal: Node = b.get_node_or_null("Medal")
			if medal != null:
				(medal as CanvasItem).visible = ex


## Cabecera de un mundo: "Mundo N", sus estrellas y, si esta cerrado, que hace falta.
func _world_header(w: int, from: int, to: int, open: bool) -> Control:
	var box: PanelContainer = PanelContainer.new()
	box.name = "WorldHeader%d" % (w + 1)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	var base: Color = UI.colors["panel"]
	var tint: Color = Color.from_hsv(fmod(0.08 + 0.17 * float(w), 1.0), 0.55, 0.85)
	sb.bg_color = base.lerp(tint, 0.18)
	sb.border_color = tint.lerp(base, 0.4) if open else UI.colors["borde"]
	sb.border_width_left = 6
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 20.0
	sb.content_margin_right = 20.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	box.add_theme_stylebox_override("panel", sb)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	var name_l: Label = Label.new()
	name_l.text = Kit.text("world_n", "Mundo {n}").format({"n": w + 1})
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_l)
	if open:
		var got: int = 0
		for i: int in range(from, to):
			got += Save.stars_for(str(i))
		row.add_child(UiIcon.make("star", UI.colors["acento"], 30.0))
		var st: Label = Label.new()
		st.text = "%d/%d" % [got, (to - from) * 3]
		row.add_child(st)
	else:
		var need: Label = Label.new()
		need.text = Kit.text("world_locked", "Supera el mundo anterior")
		need.add_theme_color_override("font_color", UI.colors["texto_suave"])
		row.add_child(need)
		box.modulate = Color(1, 1, 1, 0.75)
	return box


func _level_button(i: int, open: bool) -> Button:
	var b: Button = UI.make_button(str(i + 1) if open else "", false, "")
	b.name = "Level%d" % (i + 1)
	b.custom_minimum_size = Vector2(180.0, 196.0)
	b.add_theme_font_size_override("font_size", int(float(UI.p()["title_size"]) * 0.75))
	b.disabled = not open
	if open:
		b.theme_type_variation = "PrimaryButton" if i == Save.unlocked_count() - 1 else ""
		var row: StarRow = StarRow.make(3, Save.stars_for(str(i)), 40.0)
		row.name = "Stars"
		row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		row.offset_left = -70.0
		row.offset_right = 70.0
		row.offset_top = -62.0
		row.offset_bottom = -22.0
		b.add_child(row)
		var best: Label = Label.new()
		best.name = "Best"
		best.text = TimeAttack.fmt(TimeAttack.best(i))
		best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		best.add_theme_font_size_override("font_size", 28)
		## Sobre el boton del nivel actual (claro) el tiempo va oscuro para leerse bien.
		best.add_theme_color_override("font_color", Color("#1b1b2f") if b.theme_type_variation == "PrimaryButton" else Color("#7ee8fa"))
		best.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		best.offset_left = -80.0
		best.offset_right = 80.0
		best.offset_top = -60.0
		best.offset_bottom = -20.0
		best.mouse_filter = Control.MOUSE_FILTER_IGNORE
		best.visible = false
		b.add_child(best)
		## Medalla de experto (se ve con el modo experto encendido).
		var medal: UiIcon = UiIcon.make("trophy", Color("#ff9f43") if Expert.has_medal(i) else Color(1, 1, 1, 0.18), 44.0)
		medal.name = "Medal"
		medal.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		medal.offset_left = -54.0
		medal.offset_top = 8.0
		medal.offset_right = -10.0
		medal.offset_bottom = 52.0
		medal.mouse_filter = Control.MOUSE_FILTER_IGNORE
		medal.visible = false
		b.add_child(medal)
		b.pressed.connect(_play.bind(i))
	else:
		var lock: UiIcon = UiIcon.make("lock", UI.colors["texto_suave"], 72.0)
		lock.name = "Lock"
		lock.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		lock.offset_left = -36.0
		lock.offset_right = 36.0
		lock.offset_top = -40.0
		lock.offset_bottom = 32.0
		b.add_child(lock)
	return b


func _intro() -> void:
	var k: int = 0
	for g: GridContainer in grids:
		for b: Node in g.get_children():
			UI.pop_in(b as Control, 0.05 * float(mini(k, 12)))
			k += 1


func _stars_total() -> int:
	var n: int = 0
	for i: int in Kit.level_count():
		n += Save.stars_for(str(i))
	return n


func _play(i: int) -> void:
	Kit.level_index = i
	Expert.prepare(i)
	UI.goto(UI.game_scene())
