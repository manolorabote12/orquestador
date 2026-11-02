class_name LeaderboardPanel
extends UiModal
## Clasificacion de un nivel: los 10 mejores apodos y tu puesto. Si aun no tienes apodo, lo pide
## (es lo unico que ven los demas). Sube tu marca antes de cargar la lista.

var level: int = 0
var score: int = 0
var _list: VBoxContainer
var _status: Label
var friends: bool = false
var _tabs: HBoxContainer
var _friends_box: VBoxContainer


static func open(host: Node, lv: int, sc: int) -> LeaderboardPanel:
	var p: LeaderboardPanel = LeaderboardPanel.new()
	p.name = "LeaderboardPanel"
	p.layer = 60
	p.level = lv
	p.score = sc
	host.add_child(p)
	return p


func _ready() -> void:
	build_frame(board_title(level))
	_status = Label.new()
	_status.name = "Status"
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_status)
	## Todos / Amigos.
	_tabs = HBoxContainer.new()
	_tabs.name = "Tabs"
	_tabs.add_theme_constant_override("separation", 10)
	_tabs.visible = false
	body.add_child(_tabs)
	for k: String in ["all", "friends"]:
		var t: Button = UI.make_button(Kit.text("lb_all", "Todos") if k == "all" else Kit.text("lb_friends", "Amigos"), k == "all", "")
		t.name = "Tab_" + k
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.pressed.connect(_switch.bind(k == "friends"))
		_tabs.add_child(t)
	_friends_box = VBoxContainer.new()
	_friends_box.name = "Friends"
	_friends_box.visible = false
	_friends_box.add_theme_constant_override("separation", 8)
	body.add_child(_friends_box)
	_list = VBoxContainer.new()
	_list.name = "List"
	_list.add_theme_constant_override("separation", 8)
	body.add_child(_list)
	var close_btn: Button = UI.make_button(Kit.text("close", "Cerrar"), false, "close")
	close_btn.name = "BtnClose"
	close_btn.pressed.connect(close)
	if Online.alias() == "":
		_ask_alias()
	else:
		_load.call_deferred()
	body.add_child(close_btn)


## 1 - Apodo: solo letras y numeros, sin palabrotas; se puede borrar apagando la clasificacion.
func _ask_alias() -> void:
	_status.text = Kit.text("alias_ask", "Elige un apodo para salir en la clasificaci\u00f3n (no pongas tu nombre real)")
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
	if score > 0:
		await Online.submit(level, score)
	var rows: Array = await Online.top(level, 10)
	if not is_inside_tree():
		return
	_tabs.visible = true
	show_rows(rows)


## Cambia entre la clasificacion de todos y la de tus amigos (con tu codigo y para anadir otro).
func _switch(to_friends: bool) -> void:
	friends = to_friends
	for t: Node in _tabs.get_children():
		(t as Button).theme_type_variation = "PrimaryButton" if (t.name == "Tab_friends") == friends else ""
	_friends_box.visible = friends
	_status.text = Kit.text("loading", "Cargando...")
	if friends:
		await _build_friends()
		show_rows(await Online.friends_top(level))
	else:
		show_rows(await Online.top(level, 10))


func _build_friends() -> void:
	for c: Node in _friends_box.get_children():
		c.queue_free()
	var code: String = await Online.friend_code()
	if not is_inside_tree():
		return
	var mine: Button = UI.make_button(Kit.text("friend_code", "Tu c\u00f3digo: {code} (compartir)").format({"code": code}), false, "share")
	mine.name = "BtnMyCode"
	mine.pressed.connect(func() -> void:
		_status.text = Online.share(Kit.text("friend_share", "A\u00f1\u00e1deme en {game} con mi c\u00f3digo {code}").format(
			{"game": str(Kit.config.get("title", "")), "code": code})))
	_friends_box.add_child(mine)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_friends_box.add_child(row)
	var edit: LineEdit = LineEdit.new()
	edit.name = "FriendEdit"
	edit.max_length = 6
	edit.placeholder_text = Kit.text("friend_hint", "C\u00f3digo de tu amigo")
	edit.custom_minimum_size = Vector2(0.0, UI.MIN_TOUCH)
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(edit)
	var add: Button = UI.make_button(Kit.text("friend_add", "A\u00f1adir"), true, "")
	add.name = "BtnAddFriend"
	add.pressed.connect(func() -> void:
		var r: Dictionary = await Online.friend_add(edit.text)
		if r.is_empty():
			_status.text = Kit.text("friend_bad", "No hay nadie con ese c\u00f3digo")
			return
		edit.text = ""
		show_rows(await Online.friends_top(level)))
	row.add_child(add)


func show_rows(rows: Array) -> void:
	for c: Node in _list.get_children():
		c.queue_free()
	if rows.is_empty():
		_status.text = Kit.text("leaderboard_empty", "Sin conexi\u00f3n o nadie ha jugado a\u00fan este nivel")
		return
	_status.text = ""
	for r: Variant in rows:
		if not r is Dictionary:
			continue
		var d: Dictionary = r
		var mine: bool = bool(d.get("tuyo", false))
		var line: HBoxContainer = HBoxContainer.new()
		line.name = "Row%d" % int(d.get("posicion", 0))
		line.add_theme_constant_override("separation", 14)
		_list.add_child(line)
		var pos: Label = Label.new()
		pos.text = "%d." % int(d.get("posicion", 0))
		pos.custom_minimum_size = Vector2(56.0, 0.0)
		line.add_child(pos)
		var who: Label = Label.new()
		who.text = str(d.get("alias", "?"))
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		who.clip_text = true
		line.add_child(who)
		var pts: Label = Label.new()
		pts.text = board_value(level, int(d.get("puntos", 0)))
		line.add_child(pts)
		var col: Color = UI.colors["acento"] if mine else (Kit.color("coin", UI.colors["acento"]) if int(d.get("posicion", 0)) <= 3 else UI.colors["texto"])
		for l: Label in [pos, who, pts]:
			l.add_theme_color_override("font_color", col)


## Titulo del tablero: nivel, contrarreloj de un nivel o maraton.
static func board_title(lv: int) -> String:
	var head: String = Kit.text("leaderboard", "Clasificaci\u00f3n") + " - "
	if lv == Marathon.LB_LEVEL:
		return head + Kit.text("mar_short", "Marat\u00f3n")
	if lv >= TimeAttack.LB_BASE:
		return head + Kit.text("ta_short", "Contrarreloj") + " " + str(lv - TimeAttack.LB_BASE + 1)
	return head + Kit.text("level", "Nivel") + " " + str(lv + 1)


## Puntos como se leen en cada tablero (tiempo en el contrarreloj).
static func board_value(lv: int, p: int) -> String:
	if lv >= TimeAttack.LB_BASE and lv != Marathon.LB_LEVEL:
		return TimeAttack.fmt(TimeAttack.from_score(p))
	return str(p)
