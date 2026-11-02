class_name LigaPanel
extends UiModal
## Liga de aldeas: asaltos a las aldeas de otros jugadores (por internet, por turnos).
## 1 - Pide apodo si no hay (es lo unico que ven los demas) y sube tu aldea tal como esta.
## 2 - Tus trofeos, "Buscar rival" (el servidor elige una aldea con trofeos parecidos),
##     el ranking del juego y quien te ha atacado.
## 3 - Tras el asalto (open_result): estrellas, destruccion, botin y trofeos; otro rival o volver.

const VSave = preload("res://kit/village/village_save.gd")

var _status: Label
var _trophies: Label
var _content: VBoxContainer
var _find: Button
var result: Dictionary = {}


static func open(host: Node) -> LigaPanel:
	var p: LigaPanel = LigaPanel.new()
	p.name = "LigaPanel"
	p.layer = 60
	host.add_child(p)
	return p


## Ventana de resultado al acabar un asalto de liga.
static func open_result(host: Node, match_data: Dictionary, stars: int, pct: int, loot: int, server: Dictionary) -> LigaPanel:
	var p: LigaPanel = LigaPanel.new()
	p.name = "LigaPanel"
	p.layer = 60
	p.result = {"match": match_data, "stars": stars, "pct": pct, "loot": loot, "server": server}
	host.add_child(p)
	return p


## Fin de una repeticion: como acabo aquel asalto; verlo otra vez o volver.
static func open_replay_end(host: Node, data: Dictionary, stars: int, pct: int) -> LigaPanel:
	var p: LigaPanel = LigaPanel.new()
	p.name = "LigaPanel"
	p.layer = 60
	p.result = {"replay": data, "stars": stars, "pct": pct}
	host.add_child(p)
	return p


func _ready() -> void:
	if result.has("replay"):
		_build_replay_end()
		return
	if not result.is_empty():
		_build_result()
		return
	build_frame(Kit.text("liga", "Liga de aldeas"), 600.0)
	var top: HBoxContainer = HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 12)
	body.add_child(top)
	top.add_child(UiIcon.make("trophy", Kit.color("coin", UI.colors["acento"]), 56.0))
	_trophies = Label.new()
	_trophies.name = "Trophies"
	_trophies.theme_type_variation = "HeaderLabel"
	_trophies.text = "\u2014"
	top.add_child(_trophies)
	_status = Label.new()
	_status.name = "Status"
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_status)
	_find = UI.make_button(Kit.text("liga_find", "Buscar rival"), true, "play")
	_find.name = "BtnFind"
	_find.disabled = true
	_find.pressed.connect(find_rival)
	body.add_child(_find)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_content = VBoxContainer.new()
	_content.name = "Content"
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	scroll.add_child(_content)
	var close_btn: Button = UI.make_button(Kit.text("close", "Cerrar"), false, "close")
	close_btn.name = "BtnClose"
	close_btn.pressed.connect(close)
	body.add_child(close_btn)
	if not Online.available():
		_status.text = Kit.text("liga_offline", "La liga necesita internet. Tus asaltos de siempre siguen en \u00abAtacar\u00bb.")
		return
	if Online.alias() == "":
		_ask_alias()
	else:
		_load.call_deferred()


func _ask_alias() -> void:
	_status.text = Kit.text("alias_ask", "Elige un apodo para salir en la clasificaci\u00f3n (no pongas tu nombre real)")
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "AliasRow"
	row.add_theme_constant_override("separation", 12)
	_content.add_child(row)
	var edit: LineEdit = LineEdit.new()
	edit.name = "AliasEdit"
	edit.max_length = Online.ALIAS_MAX
	edit.placeholder_text = Kit.text("alias", "Apodo")
	edit.custom_minimum_size = Vector2(0.0, UI.MIN_TOUCH)
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(edit)
	var ok: Button = UI.make_button(Kit.text("save", "Guardar"), true, "")
	ok.name = "BtnAlias"
	row.add_child(ok)
	var send: Callable = func(_t: String = "") -> void:
		var err: String = Online.set_alias(edit.text)
		if err != "":
			_status.text = err
			return
		row.queue_free()
		_load()
	ok.pressed.connect(send)
	edit.text_submitted.connect(send)


func _load() -> void:
	_status.text = Kit.text("loading", "Cargando...")
	var me: Dictionary = await Online.liga_publish(VSave.rows(), VSave.hall())
	if not is_inside_tree():
		return
	if me.is_empty():
		_status.text = Kit.text("liga_error", "No se pudo conectar con la liga. Int\u00e9ntalo m\u00e1s tarde.")
		return
	_trophies.text = str(int(me.get("trofeos", 0)))
	_status.text = Kit.text("liga_ready", "Tu aldea ya est\u00e1 en la liga: otros jugadores pueden atacarla.")
	_find.disabled = false
	var rows: Array = await Online.liga_top(10)
	var defs: Array = await Online.liga_defenses()
	if not is_inside_tree():
		return
	await _clan_section()
	if not is_inside_tree():
		return
	await _war_section()
	if not is_inside_tree():
		return
	_section(Kit.text("liga_ranking", "Ranking"))
	for r: Variant in rows:
		if r is Dictionary:
			var d: Dictionary = r
			_row("%d. %s" % [int(d.get("posicion", 0)), str(d.get("alias", ""))], str(int(d.get("trofeos", 0))), bool(d.get("tuyo", false)))
	_section(Kit.text("liga_defenses", "Te han atacado"))
	if defs.is_empty():
		_row(Kit.text("liga_no_defenses", "Nadie todav\u00eda"), "", false)
	for r: Variant in defs:
		if r is Dictionary:
			var d: Dictionary = r
			var delta: int = int(d.get("trofeos", 0))
			_row("%s  %s" % [str(d.get("alias", "")), "\u2605".repeat(int(d.get("estrellas", 0))) if int(d.get("estrellas", 0)) > 0 else "\u2717"],
				("%+d" % delta), false)
			## Repeticion: ver como te atacaron.
			if bool(d.get("repeticion", false)):
				var attack: int = int(d.get("ataque", 0))
				var watch: Button = UI.make_button(Kit.text("replay_watch", "Ver repetici\u00f3n"), false, "play")
				watch.name = "BtnReplay%d" % attack
				watch.pressed.connect(func() -> void:
					watch.disabled = true
					var rep: Dictionary = await Online.liga_replay_get(attack)
					if rep.is_empty():
						_status.text = Kit.text("liga_error", "No se pudo conectar. Int\u00e9ntalo m\u00e1s tarde.")
						watch.disabled = false
						return
					Online.liga_replay = rep
					UI.goto(UI.game_scene()))
				_content.add_child(watch)


## Clan: el tuyo (nombre, codigo para invitar, miembros y puesto) o crear / unirse con un codigo.
func _clan_section() -> void:
	var box: VBoxContainer = VBoxContainer.new()
	box.name = "Clan"
	box.add_theme_constant_override("separation", 8)
	_content.add_child(box)
	var info: Dictionary = await Online.clan_info()
	if not is_inside_tree():
		return
	_fill_clan(box, info)


func _fill_clan(box: VBoxContainer, info: Dictionary) -> void:
	for c: Node in box.get_children():
		c.queue_free()
	var t: Label = Label.new()
	t.theme_type_variation = "SubtleLabel"
	box.add_child(t)
	if not info.is_empty():
		t.text = Kit.text("clan", "Clan") + ": " + str(info.get("nombre", "")) + "  \u00b7  #%d  \u00b7  %d" % [int(info.get("puesto", 0)), int(info.get("trofeos", 0))]
		for m: Variant in info.get("miembros", []):
			if m is Dictionary:
				var l: Label = Label.new()
				l.text = "%s  %d" % [str((m as Dictionary).get("alias", "")), int((m as Dictionary).get("trofeos", 0))]
				if bool((m as Dictionary).get("tuyo", false)):
					l.add_theme_color_override("font_color", UI.colors["acento"])
				box.add_child(l)
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		box.add_child(row)
		var invite: Button = UI.make_button(Kit.text("clan_invite", "Invitar ({code})").format({"code": str(info.get("codigo", ""))}), false, "share")
		invite.name = "BtnInvite"
		invite.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		invite.pressed.connect(func() -> void:
			var msg: String = Online.share(Kit.text("clan_share", "\u00danete a mi clan {name} en {game} con el c\u00f3digo {code}").format(
				{"name": str(info.get("nombre", "")), "game": str(Kit.config.get("title", "")), "code": str(info.get("codigo", ""))}))
			_status.text = msg)
		row.add_child(invite)
		var leave: Button = UI.make_button(Kit.text("clan_leave", "Salir"), false, "close")
		leave.name = "BtnLeave"
		leave.pressed.connect(func() -> void:
			await Online.clan_leave()
			if is_instance_valid(box):
				_fill_clan(box, {}))
		row.add_child(leave)
		return
	t.text = Kit.text("clan_none", "Sin clan: crea uno o \u00fanete con un c\u00f3digo")
	var edit: LineEdit = LineEdit.new()
	edit.name = "ClanEdit"
	edit.max_length = 14
	edit.placeholder_text = Kit.text("clan_hint", "Nombre del clan o c\u00f3digo")
	edit.custom_minimum_size = Vector2(0.0, UI.MIN_TOUCH)
	box.add_child(edit)
	var row2: HBoxContainer = HBoxContainer.new()
	row2.add_theme_constant_override("separation", 10)
	box.add_child(row2)
	var create: Button = UI.make_button(Kit.text("clan_create", "Crear clan"), true, "")
	create.name = "BtnClanCreate"
	create.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	create.pressed.connect(func() -> void:
		if Online.clean_alias(edit.text) == "":
			_status.text = Kit.text("alias_bad", "Usa de 3 a 14 letras o n\u00fameros, sin palabrotas")
			return
		var r: Dictionary = await Online.clan_create(Online.clean_alias(edit.text))
		if r.is_empty():
			_status.text = Kit.text("clan_taken", "Ese nombre no vale o ya existe")
			return
		_fill_clan(box, await Online.clan_info()))
	row2.add_child(create)
	var join: Button = UI.make_button(Kit.text("clan_join", "Unirme"), false, "")
	join.name = "BtnClanJoin"
	join.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join.pressed.connect(func() -> void:
		var r: Dictionary = await Online.clan_join(edit.text)
		if r.is_empty():
			_status.text = Kit.text("clan_bad_code", "No hay ning\u00fan clan con ese c\u00f3digo (o est\u00e1 lleno)")
			return
		_fill_clan(box, await Online.clan_info()))
	row2.add_child(join)


## Guerra de clanes de la semana: cada estrella de tus asaltos suma para tu clan.
func _war_section() -> void:
	var w: Dictionary = await Online.clan_war()
	if not is_inside_tree() or w.is_empty():
		return
	var secs: int = int(w.get("segundos", 0))
	_section(Kit.text("war", "Guerra de clanes") + "  \u00b7  " + Kit.text("ends_in", "acaba en {d} d {h} h").format({"d": secs / 86400, "h": (secs % 86400) / 3600}))
	var prize: int = int(w.get("premio", 0))
	if prize > 0:
		var claim: Button = UI.make_button(Kit.text("war_claim", "Tu clan qued\u00f3 {n}.\u00ba: cobrar {c}").format({"n": int(w.get("puesto_pasado", 0)), "c": prize}), true, "trophy")
		claim.name = "BtnWarClaim"
		claim.pressed.connect(func() -> void:
			claim.disabled = true
			var got: int = await Online.clan_war_claim()
			if got > 0:
				UI.float_text(claim, claim.size * 0.5, "+%d" % got, UI.colors["acento"])
				claim.text = Kit.text("claimed", "\u00a1Cobrado!")
				Audio.play("coin"))
		_content.add_child(claim)
	var top: Array = w.get("top", [])
	if top.is_empty():
		_row(Kit.text("war_empty", "Nadie ha sumado estrellas esta semana"), "", false)
	for r: Variant in top.slice(0, 5):
		if r is Dictionary:
			var d: Dictionary = r
			_row("%d. %s" % [int(d.get("posicion", 0)), str(d.get("nombre", ""))], "\u2605 %d" % int(d.get("estrellas", 0)), bool(d.get("tuyo", false)))
	var mine: Variant = w.get("clan", null)
	if mine is Dictionary:
		_row(Kit.text("war_yours", "Tus estrellas para {name}").format({"name": str((mine as Dictionary).get("nombre", ""))}),
			"\u2605 %d" % int((mine as Dictionary).get("tus_estrellas", 0)), true)


func _section(t: String) -> void:
	var l: Label = Label.new()
	l.text = t
	l.theme_type_variation = "SubtleLabel"
	_content.add_child(l)


func _row(left: String, right: String, mine: bool) -> void:
	var h: HBoxContainer = HBoxContainer.new()
	_content.add_child(h)
	var a: Label = Label.new()
	a.text = left
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a.clip_text = true
	if mine:
		a.add_theme_color_override("font_color", UI.colors["acento"])
	h.add_child(a)
	var b: Label = Label.new()
	b.text = right
	h.add_child(b)


## Pide rival al servidor y empieza el asalto.
func find_rival() -> void:
	_find.disabled = true
	_status.text = Kit.text("liga_searching", "Buscando rival...")
	var r: Dictionary = await Online.liga_rival()
	if not is_inside_tree():
		return
	if r.is_empty():
		_status.text = Kit.text("liga_no_rivals", "A\u00fan no hay rivales. \u00a1Comparte el juego para que haya m\u00e1s aldeas!")
		_find.disabled = false
		return
	Online.liga_match = r
	QA.log_event("liga_rival", {"alias": str(r.get("alias", "")), "trofeos": int(r.get("trofeos", 0))})
	get_tree().paused = false
	UI.goto(UI.game_scene())


func _build_replay_end() -> void:
	var data: Dictionary = result["replay"]
	build_frame(Kit.text("replay", "Repetici\u00f3n"), 560.0)
	var info: Label = Label.new()
	info.name = "Info"
	info.text = Kit.text("replay_result", "{name} hizo {s} estrellas y el {p} %").format(
		{"name": str(data.get("alias", "")), "s": int(result["stars"]), "p": int(result["pct"])})
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(info)
	var again: Button = UI.make_button(Kit.text("replay_again", "Ver otra vez"), true, "play")
	again.name = "BtnReplayAgain"
	again.pressed.connect(func() -> void:
		Online.liga_replay = data
		UI.goto(UI.game_scene()))
	body.add_child(again)
	var home: Button = UI.make_button(Kit.text("village_home", "Mi aldea"), false, "grid")
	home.name = "BtnHome"
	home.pressed.connect(func() -> void: UI.goto("res://scenes/village_home.tscn"))
	body.add_child(home)


func _build_result() -> void:
	var stars: int = int(result["stars"])
	build_frame(Kit.text("liga_win", "\u00a1Victoria!") if stars >= 1 else Kit.text("liga_lose", "\u00a1Derrota!"), 560.0)
	var who: Label = Label.new()
	who.text = Kit.text("liga_vs", "Contra {name}").format({"name": str((result["match"] as Dictionary).get("alias", ""))})
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(who)
	var st: HBoxContainer = HBoxContainer.new()
	st.alignment = BoxContainer.ALIGNMENT_CENTER
	st.add_theme_constant_override("separation", 10)
	body.add_child(st)
	for i: int in 3:
		var ic: UiIcon = UiIcon.make("star", Kit.color("coin", Color("#ffcf3f")) if i < stars else (UI.colors["texto_suave"] as Color).darkened(0.3), 72.0)
		st.add_child(ic)
		UI.pop_in(ic, 0.15 * float(i))
	var info: Label = Label.new()
	info.name = "Info"
	var server: Dictionary = result["server"]
	var tro: String = (Kit.text("liga_trophies", "Trofeos: {n}").format({"n": int(server.get("trofeos", 0))})) if server.has("trofeos") \
		else Kit.text("liga_not_saved", "Sin conexi\u00f3n: este asalto no cuenta para la liga")
	info.text = "%d %%  \u00b7  +%d  " % [int(result["pct"]), int(result["loot"])] + Kit.text("for_shop", "para la tienda") + "\n" + tro
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(info)
	var again: Button = UI.make_button(Kit.text("liga_next", "Siguiente rival"), true, "play")
	again.name = "BtnNext"
	again.pressed.connect(func() -> void:
		again.disabled = true
		var r: Dictionary = await Online.liga_rival()
		if r.is_empty():
			info.text = Kit.text("liga_no_rivals", "A\u00fan no hay rivales. \u00a1Comparte el juego para que haya m\u00e1s aldeas!")
			return
		Online.liga_match = r
		UI.goto(UI.game_scene()))
	body.add_child(again)
	var home: Button = UI.make_button(Kit.text("village_home", "Mi aldea"), false, "grid")
	home.name = "BtnHome"
	home.pressed.connect(func() -> void: UI.goto("res://scenes/village_home.tscn"))
	body.add_child(home)
