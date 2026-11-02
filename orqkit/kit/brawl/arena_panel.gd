class_name ArenaPanel
extends UiModal
## Arena en directo: buscar partida, sala de espera y resultado.
## 1 - Pide apodo si no hay. "Buscar partida": el servidor te mete en una sala (hasta 4).
## 2 - Sala de espera: quien ha entrado y la cuenta atras; lo que falte lo rellenan bots.
## 3 - Al empezar, la arena se abre con Online.arena_match (todos el mismo nivel a la vez).
## 4 - Resultado (open_result): puesto, eliminaciones y trofeos; otra partida o salir.

var result: Dictionary = {}
var room: Dictionary = {}
var _status: Label
var _list: VBoxContainer
var _find: Button
var _polling: bool = false
var _code: LineEdit
var _start_btn: Button = null
var mode: String = "todos"


static func open(host: Node) -> ArenaPanel:
	var p: ArenaPanel = ArenaPanel.new()
	p.name = "ArenaPanel"
	p.layer = 60
	host.add_child(p)
	return p


static func open_result(host: Node, place: int, kills: int, server: Dictionary, coop: bool = false, wave: int = 0, time_s: float = -1.0) -> ArenaPanel:
	var p: ArenaPanel = ArenaPanel.new()
	p.name = "ArenaPanel"
	p.layer = 60
	p.result = {"place": place, "kills": kills, "server": server, "coop": coop, "wave": wave, "time": time_s}
	host.add_child(p)
	return p


func _ready() -> void:
	if not result.is_empty():
		_build_result()
		return
	var royale: bool = Genres.current() == "royale"
	var zombie: bool = Genres.current() == "zombie"
	var kart: bool = Genres.current() == "kart"
	build_frame(Kit.text("royale_live", "Battle royale online") if royale else (Kit.text("zb_live", "Cooperativo online") if zombie
		else (Kit.text("kt_live", "Carreras online") if kart else Kit.text("arena_live", "Arena online"))), 600.0)
	_status = Label.new()
	_status.name = "Status"
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.text = Kit.text("royale_live_info", "Hasta 8 jugadores en directo; el resto de la isla son bots.") if royale \
		else (Kit.text("zb_live_info", "Hasta 4 jugadores juntos contra las oleadas. Quien cae vuelve en la siguiente.") if zombie \
		else (Kit.text("kt_live_info", "Hasta 4 pilotos en directo, con objetos. Los huecos de la parrilla los ocupan bots.") if kart \
		else Kit.text("arena_live_info", "Hasta 4 jugadores en directo. Si falta gente, entran bots.")))
	body.add_child(_status)
	_find = UI.make_button(Kit.text("arena_find", "Buscar partida"), true, "play")
	_find.name = "BtnFind"
	_find.pressed.connect(find)
	body.add_child(_find)
	## Con amigos: sala privada con codigo.
	var priv: HBoxContainer = HBoxContainer.new()
	priv.name = "Private"
	priv.add_theme_constant_override("separation", 10)
	body.add_child(priv)
	## Modo de la sala con amigos: todos contra todos o cooperativo (juntos contra oleadas).
	var mode_btn: Button = UI.make_button(Kit.text("arena_mode_ffa", "Modo: todos contra todos"), false, "")
	mode_btn.name = "BtnMode"
	mode_btn.pressed.connect(func() -> void:
		mode = "coop" if mode == "todos" else "todos"
		mode_btn.text = Kit.text("arena_mode_coop", "Modo: cooperativo") if mode == "coop" else Kit.text("arena_mode_ffa", "Modo: todos contra todos"))
	mode_btn.visible = not royale and not zombie
	body.add_child(mode_btn)
	var create: Button = UI.make_button(Kit.text("arena_private", "Sala con amigos"), false, "share")
	create.name = "BtnPrivate"
	create.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	create.pressed.connect(create_private)
	priv.add_child(create)
	_code = LineEdit.new()
	_code.name = "CodeEdit"
	_code.max_length = 6
	_code.placeholder_text = Kit.text("arena_code", "C\u00f3digo")
	_code.custom_minimum_size = Vector2(150.0, UI.MIN_TOUCH)
	priv.add_child(_code)
	var join: Button = UI.make_button(Kit.text("clan_join", "Unirme"), false, "")
	join.name = "BtnJoinPrivate"
	join.pressed.connect(join_private)
	priv.add_child(join)
	_list = VBoxContainer.new()
	_list.name = "List"
	_list.add_theme_constant_override("separation", 8)
	body.add_child(_list)
	var close_btn: Button = UI.make_button(Kit.text("close", "Cerrar"), false, "close")
	close_btn.name = "BtnClose"
	close_btn.pressed.connect(func() -> void:
		_polling = false
		close())
	body.add_child(close_btn)
	if not Online.available():
		_status.text = Kit.text("arena_offline", "La arena online necesita internet.")
		_find.disabled = true
	elif Online.alias() == "":
		_find.disabled = true
		_ask_alias()
	else:
		_show_top.call_deferred()


func _ask_alias() -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "AliasRow"
	row.add_theme_constant_override("separation", 12)
	_list.add_child(row)
	var edit: LineEdit = LineEdit.new()
	edit.name = "AliasEdit"
	edit.max_length = Online.ALIAS_MAX
	edit.placeholder_text = Kit.text("alias", "Apodo")
	edit.custom_minimum_size = Vector2(0.0, UI.MIN_TOUCH)
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(edit)
	var ok: Button = UI.make_button(Kit.text("save", "Guardar"), true, "")
	row.add_child(ok)
	var send: Callable = func(_t: String = "") -> void:
		var err: String = Online.set_alias(edit.text)
		if err != "":
			_status.text = err
			return
		row.queue_free()
		_find.disabled = false
		_show_top()
	ok.pressed.connect(send)
	edit.text_submitted.connect(send)


func _show_top() -> void:
	var rows: Array = await Online.arena_top(5)
	if not is_inside_tree() or _polling:
		return
	for c: Node in _list.get_children():
		c.queue_free()
	if rows.is_empty():
		return
	var t: Label = Label.new()
	t.text = Kit.text("liga_ranking", "Ranking")
	t.theme_type_variation = "SubtleLabel"
	_list.add_child(t)
	for r: Variant in rows:
		if r is Dictionary:
			var d: Dictionary = r
			_line("%d. %s" % [int(d.get("posicion", 0)), str(d.get("alias", ""))], str(int(d.get("trofeos", 0))), bool(d.get("tuyo", false)))


func _line(left: String, right: String, mine: bool) -> void:
	var h: HBoxContainer = HBoxContainer.new()
	_list.add_child(h)
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


func create_private() -> void:
	_find.disabled = true
	var r: Dictionary = await Online.arena_private_create(mode)
	if not is_inside_tree():
		return
	if r.is_empty():
		_status.text = Kit.text("liga_error", "No se pudo conectar. Int\u00e9ntalo m\u00e1s tarde.")
		_find.disabled = false
		return
	room = r
	_polling = true
	_poll()


func join_private() -> void:
	var r: Dictionary = await Online.arena_private_join(_code.text)
	if not is_inside_tree():
		return
	if r.is_empty():
		_status.text = Kit.text("arena_bad_code", "No hay ninguna sala abierta con ese c\u00f3digo")
		return
	_find.disabled = true
	room = r
	_polling = true
	_poll()


func find() -> void:
	_find.disabled = true
	_status.text = Kit.text("liga_searching", "Buscando rival...")
	var r: Dictionary = await Online.arena_find()
	if not is_inside_tree():
		return
	if r.is_empty():
		_status.text = Kit.text("liga_error", "No se pudo conectar. Int\u00e9ntalo m\u00e1s tarde.")
		_find.disabled = false
		return
	room = r
	_polling = true
	_poll()


## Sala de espera: se pregunta cada segundo hasta que empieza.
func _poll() -> void:
	while _polling and is_inside_tree():
		var st: Dictionary = await Online.arena_state(str(room.get("sala", "")))
		if not is_inside_tree() or not _polling:
			return
		if st.is_empty():
			_status.text = Kit.text("liga_error", "No se pudo conectar. Int\u00e9ntalo m\u00e1s tarde.")
			_polling = false
			_find.disabled = false
			return
		for c: Node in _list.get_children():
			c.queue_free()
		var players: Array = st.get("jugadores", [])
		for j: Variant in players:
			if j is Dictionary:
				_line(str((j as Dictionary).get("alias", "")), "", str((j as Dictionary).get("sesion", "")) == Online.device())
		for k: int in mini(int(st.get("cupo", 4)), 8) - players.size():
			_line(Kit.text("zb_waiting", "Esperando a un compa\u00f1ero...") if Genres.current() == "zombie" else Kit.text("arena_waiting", "Esperando... (si no, un bot)"), "", false)
		var en: float = float(st.get("en", 0.0))
		if bool(st.get("privada", false)) and not bool(st.get("empezada", false)):
			_status.text = Kit.text("arena_private_wait", "Sala con amigos \u00b7 c\u00f3digo {code}").format({"code": str(st.get("codigo", ""))}) \
				+ ("\n" + Kit.text("arena_mode_coop", "Modo: cooperativo") if str(st.get("modo", "")) == "coop" else "")
			if _start_btn == null:
				var share: Button = UI.make_button(Kit.text("arena_share", "Compartir c\u00f3digo"), false, "share")
				share.name = "BtnShareCode"
				var code: String = str(st.get("codigo", ""))
				share.pressed.connect(func() -> void:
					_status.text = Online.share(Kit.text("arena_invite", "\u00a1Juega conmigo en {game}! Sala {code}").format({"game": str(Kit.config.get("title", "")), "code": code})))
				body.add_child(share)
				body.move_child(share, 2)
				_start_btn = UI.make_button(Kit.text("arena_go", "Empezar"), true, "play")
				_start_btn.name = "BtnStart"
				_start_btn.visible = int(room.get("slot", 1)) == 0
				_start_btn.pressed.connect(func() -> void:
					_start_btn.disabled = true
					await Online.arena_start(str(room.get("sala", ""))))
				body.add_child(_start_btn)
				body.move_child(_start_btn, 2)
		else:
			_status.text = Kit.text("arena_starts", "Empieza en {s} s").format({"s": int(ceil(en))})
		if bool(st.get("empezada", false)):
			_start(st, en)
			return
		await get_tree().create_timer(1.0, true).timeout


func _start(st: Dictionary, en: float) -> void:
	_polling = false
	Online.arena_match = {"sala": str(st.get("sala", "")), "yo": Online.device(), "jugadores": st.get("jugadores", []),
		"nivel": int(st.get("nivel", 0)), "semilla": int(st.get("semilla", 0)), "start_ms": Time.get_ticks_msec() + int(en * 1000.0),
		"modo": str(st.get("modo", "todos"))}
	Kit.level_index = int(st.get("nivel", 0))
	QA.log_event("arena_live_match", {"players": (st.get("jugadores", []) as Array).size()})
	get_tree().paused = false
	UI.goto(UI.game_scene())


func _build_result() -> void:
	var place: int = int(result["place"])
	if bool(result.get("coop", false)):
		_build_coop_result(place == 1)
		return
	var kart: bool = float(result.get("time", -1.0)) >= 0.0
	var win_title: String = Kit.text("kt_live_win", "\u00a1Has ganado la carrera!") if kart else Kit.text("brawl_win", "\u00a1\u00daltimo en pie!")
	build_frame(win_title if place == 1 else Kit.text("arena_place", "Puesto {n}").format({"n": place}), 560.0)
	var info: Label = Label.new()
	info.name = "Info"
	var server: Dictionary = result["server"]
	var tro: String = Kit.text("liga_trophies", "Trofeos: {n}").format({"n": int(server.get("trofeos", 0))}) + \
		("  (%+d)" % int(server.get("delta", 0))) if server.has("trofeos") else Kit.text("liga_not_saved", "Sin conexi\u00f3n: no cuenta")
	if kart:
		var ts: float = float(result["time"])
		info.text = Kit.text("kt_live_time", "Tiempo: {t}").format({"t": "%d:%04.1f" % [int(ts) / 60, fmod(ts, 60.0)]}) + "\n" + tro
	else:
		info.text = Kit.text("arena_kills", "Eliminaciones: {n}").format({"n": int(result["kills"])}) + "\n" + tro
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(info)
	var again: Button = UI.make_button(Kit.text("arena_again", "Otra partida"), true, "play")
	again.name = "BtnAgain"
	again.pressed.connect(func() -> void:
		var host: Node = get_parent()
		close()
		ArenaPanel.open(host))
	body.add_child(again)
	var out: Button = UI.make_button(Kit.text("levels", "Niveles"), false, "grid")
	out.name = "BtnOut"
	out.pressed.connect(func() -> void: UI.goto(UI.SCREEN_LEVELS))
	body.add_child(out)


## Cooperativo: ganasteis o no, hasta que oleada llegasteis y tus eliminaciones (sin trofeos).
func _build_coop_result(win: bool) -> void:
	build_frame(Kit.text("coop_win", "\u00a1Victoria en equipo!") if win else Kit.text("coop_lose", "\u00a1Os han ganado!"), 560.0)
	var info: Label = Label.new()
	info.name = "Info"
	info.text = Kit.text("coop_reached", "Oleada {w} \u00b7 {k} eliminaciones tuyas").format({"w": int(result.get("wave", 0)), "k": int(result["kills"])})
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(info)
	var again: Button = UI.make_button(Kit.text("arena_again", "Otra partida"), true, "play")
	again.name = "BtnAgain"
	again.pressed.connect(func() -> void:
		var host: Node = get_parent()
		close()
		ArenaPanel.open(host))
	body.add_child(again)
	var out: Button = UI.make_button(Kit.text("levels", "Niveles"), false, "grid")
	out.name = "BtnOut"
	out.pressed.connect(func() -> void: UI.goto(UI.SCREEN_LEVELS))
	body.add_child(out)
