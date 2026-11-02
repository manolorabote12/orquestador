class_name SeasonPanel
extends UiModal
## Misiones y pase de temporada (autoload Season).
## 1 - Pestana "Misiones": 3 diarias y 3 semanales con su barra; las completas se cobran con un toque.
## 2 - Pestana "Pase": nivel y XP, lo que queda de temporada y los 20 niveles con su premio gratis
##     y premium (cobrar si ya lo alcanzaste). Si el juego tiene tienda, boton para el premium.
## 3 - Pestana "Logros" (autoload Feats): cada logro con su barra; los conseguidos, marcados.

var tab: String = "missions"
var _list: VBoxContainer
var _tabs: HBoxContainer


static func open(host: Node, start_tab: String = "missions") -> SeasonPanel:
	var p: SeasonPanel = SeasonPanel.new()
	p.name = "SeasonPanel"
	p.layer = 60
	p.tab = start_tab
	host.add_child(p)
	return p


func _ready() -> void:
	build_frame(Kit.text("season", "Misiones y pase"), 620.0)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 10)
	body.add_child(_tabs)
	for t: Array in [["missions", Kit.text("missions", "Misiones")], ["pass", Kit.text("pass", "Pase")], ["feats", Kit.text("feats", "Logros")]]:
		var b: Button = UI.make_button(str(t[1]), false, "")
		b.name = "Tab_" + str(t[0])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void:
			tab = str(t[0])
			_refresh())
		_tabs.add_child(b)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0.0, 640.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_list = VBoxContainer.new()
	_list.name = "List"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_list)
	var close_btn: Button = UI.make_button(Kit.text("close", "Cerrar"), false, "close")
	close_btn.name = "BtnClose"
	close_btn.pressed.connect(close)
	body.add_child(close_btn)
	Store.purchased.connect(func(_id: String) -> void:
		if is_inside_tree():
			_refresh())
	_refresh()


func _refresh() -> void:
	for c: Node in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	for b: Node in _tabs.get_children():
		(b as Button).theme_type_variation = "PrimaryButton" if b.name == "Tab_" + tab else ""
	if tab == "missions":
		_missions_view()
	elif tab == "feats":
		_feats_view()
	else:
		_pass_view()


func _label(t: String, subtle: bool = false) -> Label:
	var l: Label = Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if subtle:
		l.theme_type_variation = "SubtleLabel"
	_list.add_child(l)
	return l


func _missions_view() -> void:
	for weekly: bool in [false, true]:
		var reward: Dictionary = Season.WEEKLY_REWARD if weekly else Season.DAILY_REWARD
		_label(Kit.text("weekly", "Semanales") if weekly else Kit.text("daily", "Diarias"), true)
		var i: int = 0
		for m: Variant in Season.missions(weekly):
			var d: Dictionary = m
			var row: HBoxContainer = HBoxContainer.new()
			row.add_theme_constant_override("separation", 12)
			_list.add_child(row)
			var col: VBoxContainer = VBoxContainer.new()
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(col)
			var t: Label = Label.new()
			t.text = Season.mission_text(d)
			t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			col.add_child(t)
			var bar: ProgressBar = ProgressBar.new()
			bar.max_value = float(d["goal"])
			bar.value = float(d["have"])
			bar.show_percentage = false
			bar.custom_minimum_size = Vector2(0.0, 18.0)
			col.add_child(bar)
			var idx: int = i
			var b: Button
			if bool(d["claimed"]):
				b = UI.make_button(Kit.text("claimed", "\u00a1Cobrado!"), false, "")
				b.disabled = true
			elif int(d["have"]) >= int(d["goal"]):
				b = UI.make_button("+%d" % int(reward["coins"]), true, "coin")
				b.pressed.connect(func() -> void:
					var r: Dictionary = Season.claim_mission(weekly, idx)
					if not r.is_empty():
						Audio.play("coin")
						UI.float_text(b, b.size * 0.5, "+%d XP" % int(r["xp"]), UI.colors["acento"])
					_refresh.call_deferred())
			else:
				b = UI.make_button("%d/%d" % [int(d["have"]), int(d["goal"])], false, "")
				b.disabled = true
			b.name = ("Weekly_%d" if weekly else "Daily_%d") % i
			b.custom_minimum_size = Vector2(170.0, UI.MIN_TOUCH)
			row.add_child(b)
			i += 1


func _feats_view() -> void:
	var head: Label = _label(Kit.text("feats_count", "{n} de {t} conseguidos").format({"n": Feats.done_count(), "t": Feats.LIST.size()}), true)
	head.name = "FeatsHead"
	for e: Array in Feats.LIST:
		var id: String = str(e[0])
		var row: HBoxContainer = HBoxContainer.new()
		row.name = "Feat_" + id
		row.add_theme_constant_override("separation", 12)
		_list.add_child(row)
		var col: VBoxContainer = VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		var t: Label = Label.new()
		t.text = Feats.title(id)
		col.add_child(t)
		var how: Label = Label.new()
		how.text = Feats.how(id)
		how.theme_type_variation = "SubtleLabel"
		how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(how)
		var bar: ProgressBar = ProgressBar.new()
		bar.max_value = float(Feats.goal(id))
		bar.value = float(Feats.progress(id))
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0.0, 14.0)
		col.add_child(bar)
		var b: Button
		if Feats.done(id):
			b = UI.make_button(Kit.text("feat_done", "\u00a1Hecho!"), true, "star")
		else:
			b = UI.make_button("+%d" % Feats.reward(id), false, "coin")
		b.disabled = true
		b.custom_minimum_size = Vector2(170.0, UI.MIN_TOUCH)
		row.add_child(b)


func _pass_view() -> void:
	var secs: int = Season.season_left()
	var head: Label = _label(Kit.text("pass_level", "Nivel {t} de {max}  \u00b7  {xp} XP").format(
		{"t": Season.tier(), "max": Season.TIERS, "xp": Season.xp()}))
	head.name = "PassHead"
	var bar: ProgressBar = ProgressBar.new()
	bar.max_value = float(Season.TIER_XP)
	bar.value = float(Season.xp() % Season.TIER_XP) if Season.tier() < Season.TIERS else float(Season.TIER_XP)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0.0, 22.0)
	_list.add_child(bar)
	_label(Kit.text("ends_in", "acaba en {d} d {h} h").format({"d": secs / 86400, "h": (secs % 86400) / 3600}), true)
	if not Season.premium() and Store.available():
		var buy: Button = UI.make_button(Kit.text("pass_buy", "Desbloquear premium \u00b7 {p}").format({"p": Store.price("pase_temporada")}), true, "star")
		buy.name = "BtnPassBuy"
		buy.pressed.connect(func() -> void: Store.buy("pase_temporada"))
		_list.add_child(buy)
	var st: Dictionary = Season.state()
	for t: int in range(1, Season.TIERS + 1):
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_list.add_child(row)
		var n: Label = Label.new()
		n.text = str(t)
		n.custom_minimum_size = Vector2(56.0, 0.0)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if t <= Season.tier():
			n.add_theme_color_override("font_color", UI.colors["acento"])
		row.add_child(n)
		for prem: bool in [false, true]:
			var r: Dictionary = Season.reward(t, prem)
			var txt: String = "+%d" % int(r["coins"]) + ("  " + Kit.text("skin", "Aspecto") if str(r["skin"]) != "" else "")
			var done: bool = (st.get("claimed_premium" if prem else "claimed_free", []) as Array).has(t)
			var b: Button = UI.make_button(Kit.text("claimed", "\u00a1Cobrado!") if done else txt, prem and not done and t <= Season.tier() and Season.premium(), "star" if prem else "coin")
			b.name = ("Prem_%d" if prem else "Free_%d") % t
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.custom_minimum_size = Vector2(0.0, UI.MIN_TOUCH)
			b.disabled = done or t > Season.tier() or (prem and not Season.premium())
			var tt: int = t
			b.pressed.connect(func() -> void:
				if not Season.claim_tier(tt, prem).is_empty():
					Audio.play("coin")
				_refresh.call_deferred())
			row.add_child(b)
