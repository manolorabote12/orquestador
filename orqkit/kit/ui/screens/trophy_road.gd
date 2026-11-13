class_name TrophyRoad
extends UiModal
## Ruta de trofeos: cada estrella nueva da 10 trofeos y cada 50 hay un premio que se cobra con un
## toque (monedas o cofres). La barra ensena cuanto falta para el siguiente.

signal changed


static func open(host: Node) -> TrophyRoad:
	var p: TrophyRoad = TrophyRoad.new()
	p.name = "TrophyRoad"
	host.add_child(p)
	return p


func _ready() -> void:
	build_frame(Kit.text("trophy_road", "Ruta de trofeos"), 600.0)
	_fill()


func _fill() -> void:
	for c: Node in body.get_children():
		if c != header:
			c.queue_free()
	var t: int = Chests.trophies()
	var top: HBoxContainer = HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 12)
	body.add_child(top)
	top.add_child(UiIcon.make("trophy", UI.colors["acento"], 56.0))
	var tl: Label = Label.new()
	tl.name = "Trophies"
	tl.text = str(t)
	tl.theme_type_variation = "HeaderLabel"
	top.add_child(tl)
	var li: int = Chests.league_index(t)
	var lg: Label = Label.new()
	lg.name = "League"
	lg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lg.text = Kit.text("league", "Liga") + " " + Chests.league_name(li)
	if li + 1 < Chests.LEAGUES.size():
		lg.text += "  \u00b7  " + Kit.text("league_next", "%d para %s") % [int(Chests.LEAGUES[li + 1][0]) - t, Chests.league_name(li + 1)]
	lg.add_theme_color_override("font_color", Color(str(Chests.LEAGUES[li][3])))
	body.add_child(lg)
	var next_k: int = t / Chests.TROPHY_STEP + 1
	var bar: ProgressBar = ProgressBar.new()
	bar.name = "NextBar"
	bar.custom_minimum_size = Vector2(0, 26)
	bar.show_percentage = false
	bar.max_value = Chests.TROPHY_STEP
	bar.value = t % Chests.TROPHY_STEP
	body.add_child(bar)
	var hint: Label = Label.new()
	hint.theme_type_variation = "SubtleLabel"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.text = Kit.text("trophy_hint", "Cada estrella nueva da 10 trofeos. Faltan %d para el siguiente premio.") % (next_k * Chests.TROPHY_STEP - t)
	body.add_child(hint)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 560)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)
	var first_open: Control = null
	for k: int in range(1, maxi(next_k + 6, 10)):
		var row: PanelContainer = PanelContainer.new()
		row.name = "Step%d" % k
		var hb: HBoxContainer = HBoxContainer.new()
		hb.add_theme_constant_override("separation", 12)
		row.add_child(hb)
		var need: Label = Label.new()
		need.text = str(k * Chests.TROPHY_STEP)
		need.custom_minimum_size = Vector2(90, 0)
		hb.add_child(need)
		var r: Dictionary = Chests.road_reward(k)
		var art: Control = Control.new()
		art.custom_minimum_size = Vector2(80, 70)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rr: Dictionary = r
		art.draw.connect(func() -> void:
			if str(rr["kind"]) == "chest":
				ChestPanel.draw_chest(art, Rect2(Vector2(8, 6), Vector2(64, 54)), ChestPanel.type_color(str(rr["type"])))
			else:
				art.draw_circle(Vector2(40, 35), 26.0, Kit.color("coin", UI.colors["acento"])))
		hb.add_child(art)
		var what: Label = Label.new()
		what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		what.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		what.text = ChestPanel.chest_name(str(r["type"])) if str(r["kind"]) == "chest" else "%d %s" % [int(r["amount"]), Kit.text("coins_word", "monedas")]
		hb.add_child(what)
		if Chests.road_claimed(k):
			var ok: Label = Label.new()
			ok.text = Kit.text("claimed", "Cobrado")
			ok.add_theme_color_override("font_color", UI.colors["exito"])
			hb.add_child(ok)
			row.modulate = Color(1, 1, 1, 0.7)
		elif t >= k * Chests.TROPHY_STEP:
			var b: Button = UI.make_button(Kit.text("claim", "Cobrar"), true, "star")
			b.name = "BtnClaim%d" % k
			b.pressed.connect(_claim.bind(k, b))
			hb.add_child(b)
			if first_open == null:
				first_open = row
		else:
			row.modulate = Color(1, 1, 1, 0.45)
		list.add_child(row)
	var close_b: Button = UI.make_button(Kit.text("close", "Cerrar"), false, "close")
	close_b.name = "BtnCloseRoad"
	close_b.pressed.connect(close)
	body.add_child(close_b)
	if first_open != null:
		(func() -> void: scroll.ensure_control_visible(first_open)).call_deferred()


func _claim(k: int, b: Button) -> void:
	var r: Dictionary = Chests.claim_road(k)
	if r.has("error"):
		Audio.play("ui_error", 0.0, -6.0)
		UI.float_text(root, b.get_global_rect().get_center(), Kit.text("chests_full", "Cofres llenos"), UI.colors["peligro"], 30)
		return
	if r.is_empty():
		return
	Audio.play("ui_reward", 0.0, -4.0)
	Juice.vibrate(40)
	Juice.burst(root, b.get_global_rect().get_center(), UI.colors["acento"], 24)
	if str(r["kind"]) == "coins":
		var size: Vector2 = root.get_viewport().get_visible_rect().size
		UI.fly_coins(root, b.get_global_rect().get_center(), Vector2(size.x - 140.0, 60.0), int(r["amount"]))
	changed.emit()
	_fill()
