class_name TournamentPanel
extends UiModal
## Torneo semanal: el mismo nivel para todos durante una semana y su propia clasificacion.
## 1 - Nivel de la semana, lo que queda para que acabe y tu mejor marca.
## 2 - Si quedaste en el podio la semana pasada: premio en monedas (se cobra una vez).
## 3 - "Jugar el torneo" abre el nivel aunque no lo hayas desbloqueado; al acabarlo, la marca sube sola.

var info: Dictionary = {}
var _status: Label
var _list: VBoxContainer
var _play: Button


static func open(host: Node) -> TournamentPanel:
	var p: TournamentPanel = TournamentPanel.new()
	p.name = "TournamentPanel"
	p.layer = 60
	host.add_child(p)
	return p


func _ready() -> void:
	build_frame(Kit.text("torneo", "Torneo semanal"), 600.0)
	_status = Label.new()
	_status.name = "Status"
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.text = Kit.text("loading", "Cargando...")
	body.add_child(_status)
	_play = UI.make_button(Kit.text("torneo_play", "Jugar el torneo"), true, "play")
	_play.name = "BtnPlay"
	_play.disabled = true
	_play.pressed.connect(play)
	body.add_child(_play)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 380)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_list = VBoxContainer.new()
	_list.name = "List"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)
	var close_btn: Button = UI.make_button(Kit.text("close", "Cerrar"), false, "close")
	close_btn.name = "BtnClose"
	close_btn.pressed.connect(close)
	body.add_child(close_btn)
	_load.call_deferred()


func _load() -> void:
	info = await Online.torneo_info()
	if not is_inside_tree():
		return
	if info.is_empty():
		_status.text = Kit.text("torneo_offline", "El torneo necesita internet. Vuelve a intentarlo luego.")
		return
	var lv: int = int(info.get("nivel", 0))
	var names: Array = Kit.config.get("levels", [])
	var lname: String = str((names[lv] as Dictionary).get("name", "")) if lv < names.size() else ""
	var tr: Variant = (Kit.config.get("i18n", {}) as Dictionary).get(Kit.lang(), {}).get("_levels", []) if Kit.config.get("i18n", {}) is Dictionary else []
	if tr is Array and lv < (tr as Array).size():
		lname = str(((tr as Array)[lv] as Dictionary).get("name", lname))
	var secs: int = int(info.get("segundos", 0))
	var left: String = Kit.text("torneo_left", "Quedan {d} d {h} h").format({"d": secs / 86400, "h": (secs % 86400) / 3600})
	_status.text = Kit.text("level", "Nivel") + " %d \u00b7 %s\n%s" % [lv + 1, lname, left]
	if int(info.get("mejor", 0)) > 0:
		_status.text += "\n" + Kit.text("torneo_best", "Tu mejor: {s}").format({"s": int(info["mejor"])})
	_play.disabled = false
	if int(info.get("premio", 0)) > 0:
		var prize: Button = UI.make_button(Kit.text("torneo_prize", "\u00a1Podio la semana pasada! Cobrar {n}").format({"n": int(info["premio"])}), true, "coin")
		prize.name = "BtnPrize"
		prize.pressed.connect(func() -> void:
			prize.disabled = true
			var got: int = await Online.torneo_claim()
			if got > 0:
				Audio.play("coin")
				UI.float_text(root, prize.get_global_rect().get_center() - Vector2(0, 60), "+%d" % got, Kit.color("coin", UI.colors["acento"]), 40)
			prize.queue_free())
		body.add_child(prize)
		body.move_child(prize, 2)
	if Online.alias() == "":
		var hint: Label = Label.new()
		hint.text = Kit.text("torneo_alias", "Para salir en el torneo, elige un apodo en la clasificaci\u00f3n de cualquier nivel.")
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.theme_type_variation = "SubtleLabel"
		_list.add_child(hint)
	var rows: Array = await Online.torneo_top(10)
	if not is_inside_tree():
		return
	if rows.is_empty():
		var e: Label = Label.new()
		e.text = Kit.text("torneo_empty", "Nadie ha jugado todav\u00eda esta semana. \u00a1S\u00e9 el primero!")
		e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_list.add_child(e)
	for r: Variant in rows:
		if not r is Dictionary:
			continue
		var d: Dictionary = r
		var h: HBoxContainer = HBoxContainer.new()
		_list.add_child(h)
		var a: Label = Label.new()
		a.text = "%d. %s" % [int(d.get("posicion", 0)), str(d.get("alias", ""))]
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		a.clip_text = true
		if bool(d.get("tuyo", false)):
			a.add_theme_color_override("font_color", UI.colors["acento"])
		h.add_child(a)
		var b: Label = Label.new()
		b.text = str(int(d.get("puntos", 0)))
		h.add_child(b)


func play() -> void:
	Online.torneo = info.duplicate()
	Kit.level_index = int(info.get("nivel", 0))
	QA.log_event("torneo_play", {"nivel": Kit.level_index, "semana": str(info.get("semana", ""))})
	get_tree().paused = false
	UI.goto(UI.game_scene())
