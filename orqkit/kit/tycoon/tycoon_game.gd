extends Node2D
## Tycoon (idle de negocios y de minas): compra negocios o sube de nivel pozos, ascensor y almacen,
## contrata gerentes para que trabajen solos y junta el dinero de la meta. Reglas, simulacion, bot y
## analizador en tycoon_map.gd (catalogo por datos en tycoon_catalog.json).
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel al acabar.

const M = preload("res://kit/tycoon/tycoon_map.gd")
const SAVE_KEY: String = "tycoon_save"
const INV_KEY: String = "tycoon_investors"
const BUY_STEPS: Array[int] = [1, 10, 100, 0]
const LOOK_COLORS: Dictionary = {
	"lemon": "#f7d84a", "paper": "#e9e4d4", "car": "#4aa3f0", "pizza": "#f0a04a", "donut": "#f08fb6", "fish": "#6fc3df",
	"ball": "#f4f4f4", "film": "#8a6cf0", "coal": "#3b3f46", "iron": "#a7adb8", "copper": "#d9824a", "silver": "#d8dee8",
	"gold": "#f2c53d", "gem": "#62e0f0", "shop": "#5bc27a", "coffee": "#8b5a3c", "bank": "#c9b26b", "rocket": "#e85d5d",
	"farm": "#86c45a", "factory": "#8c96a8", "oil": "#2b2b33", "phone": "#4b5bd6", "game": "#d65bd0", "burger": "#e3a04b",
	"cake": "#f5c6d6", "hotel": "#5b8fd6"}

var level: Dictionary = {}
var st: Dictionary = {}
var finished: bool = false
var failed: bool = false
var deaths: int = 0
var time_in_level: float = 0.0
var coins: int = 0
var coins_total: int = 0
var fast: bool = false
var auto_retry: bool = false
var result_panel: ResultPanel
## Cuantas se compran de golpe (0 = todas las que se pueda).
var buy_step: int = 1

var _money_lbl: Label
var _rate_lbl: Label
var _goal_bar: ProgressBar
var _list: VBoxContainer
var _cards: Dictionary = {}
var _step_btn: Button
var _up_btn: Button
var _hint: Dictionary = {}
var _hint_t: float = 0.0
var _save_t: float = 0.0
var _anim_t: float = 0.0
var _pops: Array = []
var _font: Font
var _bot: bool = false
var _think_t: float = 0.0


func _ready() -> void:
	level = Kit.current_level()
	RenderingServer.set_default_clear_color(Color("#1c2333") if _mode() == "biz" else Color("#2a1f18"))
	_font = UI.theme.get_font("font", "Label") if UI.theme != null else ThemeDB.fallback_font
	## El protagonista abajo, en el hueco que deja la lista de negocios (13 nov: media pantalla vacia).
	var mas: Node2D = SpriteKit.mascota(250.0)
	if mas != null:
		var layer: CanvasLayer = CanvasLayer.new()
		layer.name = "Mascot"
		layer.layer = 10
		add_child(layer)
		var vp: Vector2 = get_viewport_rect().size
		mas.position = Vector2(vp.x * 0.5, vp.y * 0.86)
		layer.add_child(mas)
	_build_hud()
	_reset()
	_restore()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "tycoon", "mode": str(st["mode"]), "target": float(st["target"])})


func _mode() -> String:
	return "mine" if str(M.catalog(level).get("mode", "biz")) == "mine" else "biz"


func bot_script() -> String:
	return "res://qa/tycoon_bot.gd"


func capture_delays() -> Vector2:
	## Con varios negocios ya comprados (sin prisa el bot piensa una vez por segundo).
	return Vector2(20.0, 9.0)


func investors() -> int:
	return int(Save.get_setting(INV_KEY, 0))


func _reset() -> void:
	finished = false
	failed = false
	## Los inversores (de niveles ya ganados) dan un 2 % mas cada uno; el bot y las pruebas sin ellos.
	var bonus: float = 1.0 if (_bot or auto_retry or UI.test_mode) else 1.0 + 0.02 * float(investors())
	st = M.new_state(level, bonus)
	time_in_level = 0.0
	_think_t = 0.0
	_build_cards()
	_refresh(true)


func _build_hud() -> void:
	var hud: CanvasLayer = CanvasLayer.new()
	hud.name = "Hud"
	hud.layer = 20
	add_child(hud)
	var root: Control = Control.new()
	root.theme = UI.theme
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(root)
	var safe: MarginContainer = UI.safe_root(root, 14.0)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col: VBoxContainer = VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 8)
	safe.add_child(col)
	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top)
	var money_box: VBoxContainer = VBoxContainer.new()
	money_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	money_box.add_theme_constant_override("separation", 0)
	top.add_child(money_box)
	_money_lbl = Label.new()
	_money_lbl.name = "Money"
	_money_lbl.add_theme_font_size_override("font_size", 54)
	_money_lbl.add_theme_color_override("font_color", Kit.color("coin", Color("#ffd166")))
	money_box.add_child(_money_lbl)
	_rate_lbl = Label.new()
	_rate_lbl.name = "Rate"
	_rate_lbl.add_theme_font_size_override("font_size", 26)
	money_box.add_child(_rate_lbl)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)
	_goal_bar = ProgressBar.new()
	_goal_bar.name = "Goal"
	_goal_bar.custom_minimum_size = Vector2(0.0, 34.0)
	_goal_bar.show_percentage = false
	_goal_bar.max_value = 1.0
	_goal_bar.step = 0.0
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = Color("#5bd17a")
	fill.set_corner_radius_all(14)
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.35)
	bg.set_corner_radius_all(14)
	_goal_bar.add_theme_stylebox_override("fill", fill)
	_goal_bar.add_theme_stylebox_override("background", bg)
	col.add_child(_goal_bar)
	var goal_lbl: Label = Label.new()
	goal_lbl.name = "GoalText"
	goal_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	goal_lbl.add_theme_font_size_override("font_size", 22)
	goal_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_goal_bar.add_child(goal_lbl)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_list = VBoxContainer.new()
	_list.name = "List"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_list)
	var low: HBoxContainer = HBoxContainer.new()
	low.add_theme_constant_override("separation", 10)
	col.add_child(low)
	_step_btn = UI.make_button("x1", false, "")
	_step_btn.name = "BtnStep"
	_step_btn.custom_minimum_size = Vector2(150.0, 96.0)
	_step_btn.pressed.connect(cycle_step)
	low.add_child(_step_btn)
	_up_btn = UI.make_button("", true, "star")
	_up_btn.name = "BtnUpgrade"
	_up_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_up_btn.clip_text = true
	_up_btn.pressed.connect(buy_next_upgrade)
	low.add_child(_up_btn)


## Una tarjeta por negocio (o por almacen, ascensor y pozo): dibujo que se toca para trabajar,
## nombre y cuantas, barra del ciclo, boton de comprar y boton de gerente.
func _build_cards() -> void:
	for c: Node in _list.get_children():
		c.queue_free()
	_cards.clear()
	for sid: Variant in st["order"]:
		var id: String = str(sid)
		var card: PanelContainer = PanelContainer.new()
		card.name = "Card_" + id
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.bg_color = Color("#2b3550") if str(st["mode"]) == "biz" else Color("#4a3628")
		sb.set_corner_radius_all(18)
		sb.set_content_margin_all(10)
		sb.border_color = Color(1, 1, 1, 0.08)
		sb.set_border_width_all(3)
		card.add_theme_stylebox_override("panel", sb)
		_list.add_child(card)
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		card.add_child(row)
		var art: Control = Control.new()
		art.name = "Art"
		art.custom_minimum_size = Vector2(120.0, 120.0)
		art.mouse_filter = Control.MOUSE_FILTER_STOP
		art.draw.connect(_draw_art.bind(art, id))
		art.gui_input.connect(_on_art_input.bind(id))
		row.add_child(art)
		var mid: VBoxContainer = VBoxContainer.new()
		mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mid.add_theme_constant_override("separation", 2)
		row.add_child(mid)
		var name_lbl: Label = Label.new()
		name_lbl.name = "Name"
		name_lbl.add_theme_font_size_override("font_size", 28)
		name_lbl.clip_text = true
		mid.add_child(name_lbl)
		var bar: Control = Control.new()
		bar.name = "Bar"
		bar.custom_minimum_size = Vector2(0.0, 40.0)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.draw.connect(_draw_bar.bind(bar, id))
		mid.add_child(bar)
		var info_lbl: Label = Label.new()
		info_lbl.name = "Info"
		info_lbl.add_theme_font_size_override("font_size", 22)
		info_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
		info_lbl.clip_text = true
		mid.add_child(info_lbl)
		var right: VBoxContainer = VBoxContainer.new()
		right.add_theme_constant_override("separation", 6)
		row.add_child(right)
		var buy_btn: Button = UI.make_button("", true, "")
		buy_btn.name = "BtnBuy"
		buy_btn.custom_minimum_size = Vector2(200.0, 96.0)
		buy_btn.add_theme_font_size_override("font_size", 24)
		buy_btn.pressed.connect(press_buy.bind(id))
		right.add_child(buy_btn)
		var mgr_btn: Button = UI.make_button("", false, "")
		mgr_btn.name = "BtnManager"
		## Alto minimo de dedo (88): se pulsa a menudo.
		mgr_btn.custom_minimum_size = Vector2(200.0, UI.MIN_TOUCH)
		mgr_btn.add_theme_font_size_override("font_size", 20)
		mgr_btn.pressed.connect(press_manager.bind(id))
		right.add_child(mgr_btn)
		_cards[id] = {"card": card, "art": art, "bar": bar, "name": name_lbl, "info": info_lbl, "buy": buy_btn, "mgr": mgr_btn, "style": sb}


# ------------------------------------------------------------------ acciones

func can_act() -> bool:
	return not finished and is_inside_tree() and not get_tree().paused and not st.is_empty()


func cycle_step() -> void:
	buy_step = BUY_STEPS[(BUY_STEPS.find(buy_step) + 1) % BUY_STEPS.size()]
	_sfx("click", -10.0)
	_refresh(true)


func _count_for(sid: String) -> int:
	var s: Dictionary = st["stations"][sid]
	if str(s["kind"]) != "biz" and int(s["n"]) == 0:
		return 1
	if buy_step == 0:
		return maxi(1, M.max_count(st, sid))
	return buy_step


func press_buy(sid: String) -> void:
	if not can_act():
		return
	var was: int = int(st["stations"][sid]["n"])
	var ms: int = M.doubles(st, sid)
	if M.buy(st, sid, _count_for(sid)):
		_sfx("coin", -6.0)
		if M.doubles(st, sid) > ms:
			_pop(sid, Kit.text("ty_double", "x2!"), Color("#ffd166"))
			_sfx("powerup", -6.0)
		elif was == 0:
			_pop(sid, Kit.text("ty_new", "Nuevo!"), Color("#5bd17a"))
		_refresh(true)
	else:
		_sfx("hurt", -14.0)


func press_manager(sid: String) -> void:
	if not can_act():
		return
	if M.hire(st, sid):
		_sfx("powerup", -6.0)
		_pop(sid, Kit.text("ty_auto", "Automatico"), Color("#9be7ff"))
		_refresh(true)


func buy_next_upgrade() -> void:
	if not can_act():
		return
	var p: Array = M.pending_upgrades(st)
	if p.is_empty():
		return
	var u: Dictionary = p[0]
	if M.buy_upgrade(st, str(u["id"])):
		_sfx("powerup", -4.0)
		var tg: String = str(u["target"])
		_pop(tg if _cards.has(tg) else str((st["order"] as Array)[0]), "x%d" % int(u["mult"]), Color("#ffd166"))
		_refresh(true)


func tap_station(sid: String) -> void:
	if can_act() and M.tap(st, sid):
		_sfx("click", -12.0)


func _on_art_input(event: InputEvent, sid: String) -> void:
	var pressed: bool = (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed) or \
		(event is InputEventMouseButton and (event as InputEventMouseButton).pressed and not DisplayServer.is_touchscreen_available())
	if pressed:
		tap_station(sid)


func bot_step() -> void:
	if can_act():
		M.bot_tick(st)
		_refresh(true)


func _sfx(n: String, vol: float = -6.0) -> void:
	if not fast:
		Audio.play(n, 0.1, vol)


func _pop(sid: String, text: String, col: Color) -> void:
	if fast or not _cards.has(sid):
		return
	var art: Control = _cards[sid]["art"]
	UI.float_text(get_node("Hud"), art.global_position + art.size * 0.5, text, col, 34)


# ------------------------------------------------------------------ bucle

func _physics_process(delta: float) -> void:
	if st.is_empty() or finished:
		return
	if get_tree().paused:
		return
	_anim_t += delta
	## Con prisa (bot de la fabrica) el tiempo corre 10 veces y el bot piensa cada segundo de juego.
	var reps: int = 10 if fast else 1
	var done: Array = []
	for k: int in reps:
		if fast and auto_retry and float(st["t"]) >= _think_t:
			_think_t = float(st["t"]) + M.BOT_EVERY
			M.bot_tick(st)
		done.append_array(M.step(st, delta if not fast else M.DT))
		if bool(st["won"]):
			break
	time_in_level = float(st["t"])
	if not fast:
		for d: Variant in done:
			var sid: String = str(d[0])
			var kind: String = str(st["stations"][sid]["kind"])
			if (kind == "biz" or kind == "store") and float(d[1]) > 0.0:
				_pop(sid, "+" + M.fmt(float(d[1])), Color("#ffd166"))
	_hint_t -= delta
	if _hint_t <= 0.0:
		_hint_t = 1.0
		_hint = M.best_buy(st)
	_refresh(not done.is_empty())
	_save_t += delta
	if _save_t >= 5.0:
		_save_t = 0.0
		_autosave()
	if bool(st["won"]):
		_finish()


func _refresh(full: bool = false) -> void:
	if st.is_empty() or _money_lbl == null:
		return
	var cur: String = str((st["cat"] as Dictionary).get("cur", "$"))
	_money_lbl.text = cur + " " + M.fmt(float(st["money"]))
	_rate_lbl.text = Kit.text("ty_per_s", "{n} por segundo").format({"n": cur + " " + M.fmt(M.rate(st))})
	_goal_bar.value = clampf(float(st["earned"]) / float(st["target"]), 0.0, 1.0)
	(_goal_bar.get_node("GoalText") as Label).text = Kit.text("ty_goal", "Meta: {n}").format({"n": cur + " " + M.fmt(float(st["earned"])) + " / " + M.fmt(float(st["target"]))})
	for sid: Variant in _cards:
		var c: Dictionary = _cards[sid]
		(c["bar"] as Control).queue_redraw()
		(c["art"] as Control).queue_redraw()
		if full:
			_refresh_card(str(sid))
	if full:
		_step_btn.text = "x%d" % buy_step if buy_step > 0 else Kit.text("ty_max", "MAX")
		var p: Array = M.pending_upgrades(st)
		if p.is_empty():
			_up_btn.text = "  " + Kit.text("ty_no_upgrades", "Todo mejorado")
			_up_btn.disabled = true
		else:
			var u: Dictionary = p[0]
			var who: String = Kit.text("ty_all", "todo") if str(u["target"]) == "all" else M.name_of(st, str(u["target"]))
			var nm: String = str(u.get("name", ""))
			_up_btn.text = "  " + (nm if nm != "" else "x%d %s" % [int(u["mult"]), who]) + "   " + cur + M.fmt(float(u["cost"]))
			_up_btn.disabled = float(u["cost"]) > float(st["money"])


func _refresh_card(sid: String) -> void:
	var c: Dictionary = _cards[sid]
	var s: Dictionary = st["stations"][sid]
	var n: int = int(s["n"])
	var kind: String = str(s["kind"])
	var cur: String = str((st["cat"] as Dictionary).get("cur", "$"))
	var nm: String = M.name_of(st, sid)
	if kind == "biz":
		(c["name"] as Label).text = nm + ("   x%d" % n if n > 0 else "")
	else:
		(c["name"] as Label).text = nm + ("   " + Kit.text("ty_level", "Nv {n}").format({"n": n}) if n > 0 else "")
	var info: String = ""
	if n > 0:
		var nmx: int = M.next_milestone(st, sid)
		var per: String = "+" + cur + M.fmt(M.amount(st, sid)) if kind != "lift" and kind != "store" else M.fmt(M.amount(st, sid)) + " " + Kit.text("ty_per_trip", "por viaje")
		info = per + "  \u00b7  %.1fs" % M.cycle_time(st, sid)
		if nmx > 0:
			info += "  \u00b7  x2: %d" % nmx
	else:
		info = Kit.text("ty_locked", "Por abrir")
	(c["info"] as Label).text = info
	var count: int = _count_for(sid)
	var price: float = M.cost(st, sid, count)
	var buy: Button = c["buy"]
	if n == 0:
		buy.text = Kit.text("ty_open", "Abrir") + "\n" + cur + M.fmt(price)
	elif kind == "biz":
		buy.text = Kit.text("ty_buy", "Comprar") + " x%d\n%s%s" % [count, cur, M.fmt(price)]
	else:
		buy.text = Kit.text("ty_up", "Subir") + " +%d\n%s%s" % [count, cur, M.fmt(price)]
	buy.disabled = price > float(st["money"])
	var mgr: Button = c["mgr"]
	mgr.visible = n > 0
	if bool(s["mgr"]):
		mgr.text = Kit.text("ty_auto", "Automatico")
		mgr.disabled = true
	else:
		mgr.text = Kit.text("ty_manager", "Gerente") + " " + cur + M.fmt(M.manager_cost(st, sid))
		mgr.disabled = M.manager_cost(st, sid) > float(st["money"])
	(c["card"] as Control).modulate = Color(1, 1, 1, 1.0 if n > 0 else 0.72)
	## La compra que mas conviene ahora, con borde dorado.
	var sb: StyleBoxFlat = c["style"]
	var hinted: bool = not _hint.is_empty() and str(_hint.get("id", "")) == sid
	sb.border_color = Color("#ffd166") if hinted else Color(1, 1, 1, 0.08)


# ------------------------------------------------------------------ dibujo

func _draw_bar(bar: Control, sid: String) -> void:
	var s: Dictionary = st["stations"][sid]
	var r: Rect2 = Rect2(Vector2(0, 6), Vector2(bar.size.x, bar.size.y - 12))
	bar.draw_rect(r, Color(0, 0, 0, 0.35))
	if int(s["n"]) <= 0:
		return
	var p: float = clampf(float(s["prog"]), 0.0, 1.0)
	## Los ciclos muy rapidos se ven como barra llena (si no, parpadea).
	if M.cycle_time(st, sid) < 0.25 and (bool(s["run"]) or bool(s["mgr"])):
		p = 1.0
	bar.draw_rect(Rect2(r.position, Vector2(r.size.x * p, r.size.y)), Color("#5bd17a") if bool(s["mgr"]) else Color("#4aa3f0"))
	var kind: String = str(s["kind"])
	var txt: String = ""
	if kind == "shaft":
		txt = M.fmt(float(s["box"]))
	elif kind == "store":
		txt = M.fmt(float(st["stock"]))
	elif not bool(s["run"]) and not bool(s["mgr"]):
		txt = Kit.text("ty_tap", "Toca el dibujo")
	if txt != "":
		bar.draw_string(_font, Vector2(8, r.position.y + r.size.y * 0.5 + 8), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)


func _draw_art(art: Control, sid: String) -> void:
	var s: Dictionary = st["stations"][sid]
	var look: String = M.look_of(st, sid)
	var col: Color = Color(str(LOOK_COLORS.get(look, "#cccccc")))
	var c: Vector2 = art.size * 0.5
	var working: bool = int(s["n"]) > 0 and (bool(s["run"]) or bool(s["mgr"]))
	art.draw_circle(c, 56.0, Color(1, 1, 1, 0.08))
	if not working and int(s["n"]) > 0:
		## Parado: un circulo que late para que se toque.
		var pulse: float = 0.5 + 0.5 * sin(_anim_t * 6.0)
		art.draw_arc(c, 54.0, 0.0, TAU, 40, Color(1.0, 0.82, 0.4, 0.4 + 0.5 * pulse), 4.0)
	var kind: String = str(s["kind"])
	var bob: float = sin(_anim_t * 8.0) * 3.0 if working else 0.0
	if kind == "shaft":
		_draw_miner(art, c, col, float(s["prog"]), working)
	elif kind == "lift":
		var y: float = lerpf(-30.0, 30.0, 0.5 - 0.5 * cos(float(s["prog"]) * TAU))
		art.draw_line(c + Vector2(0, -56), c + Vector2(0, 56), Color(0.2, 0.2, 0.2), 4.0)
		art.draw_rect(Rect2(c + Vector2(-26, y - 22), Vector2(52, 44)), Color("#c9a14a"))
		art.draw_rect(Rect2(c + Vector2(-20, y - 16), Vector2(40, 18)), Color("#3b3f46"))
	elif kind == "store":
		art.draw_rect(Rect2(c + Vector2(-40, -10), Vector2(80, 46)), Color("#8c96a8"))
		art.draw_colored_polygon(PackedVector2Array([c + Vector2(-48, -10), c + Vector2(0, -44), c + Vector2(48, -10)]), Color("#c0504d"))
		var cx: float = lerpf(-30.0, 30.0, float(s["prog"]))
		art.draw_rect(Rect2(c + Vector2(cx - 14, 26 + bob * 0.3), Vector2(28, 16)), Color("#f2c53d"))
	else:
		_draw_look(art, c + Vector2(0, bob), look, col)
	if int(s["n"]) <= 0:
		art.draw_circle(c, 56.0, Color(0, 0, 0, 0.45))
		art.draw_arc(c + Vector2(0, -8), 12.0, PI, TAU, 12, Color(1, 1, 1, 0.9), 6.0)
		art.draw_rect(Rect2(c + Vector2(-18, -8), Vector2(36, 28)), Color(1, 1, 1, 0.9))


func _draw_miner(art: Control, c: Vector2, ore: Color, prog: float, working: bool) -> void:
	## Veta de mineral a la derecha y minero con pico a la izquierda.
	for k: int in 4:
		art.draw_circle(c + Vector2(26 + (k % 2) * 14, -18 + k * 12), 10.0, ore)
	art.draw_circle(c + Vector2(-22, -18), 13.0, Color("#f1c27d"))
	art.draw_rect(Rect2(c + Vector2(-36, -32), Vector2(28, 10)), Color("#f2c53d"))
	art.draw_rect(Rect2(c + Vector2(-34, -4), Vector2(24, 34)), Color("#3f6fb5"))
	var a: float = -0.9 + (sin(prog * TAU * 2.0) * 0.9 if working else 0.0)
	var hand: Vector2 = c + Vector2(-12, 4)
	var tip: Vector2 = hand + Vector2(cos(a), sin(a)) * 34.0
	art.draw_line(hand, tip, Color("#8b5a3c"), 5.0)
	art.draw_line(tip + Vector2(sin(a), -cos(a)) * 10.0, tip - Vector2(sin(a), -cos(a)) * 10.0, Color("#a7adb8"), 5.0)


## Dibujos sencillos de cada negocio (por "look").
func _draw_look(art: Control, c: Vector2, look: String, col: Color) -> void:
	var dark: Color = col.darkened(0.35)
	match look:
		"lemon", "ball", "coal", "gold":
			art.draw_circle(c, 34.0, col)
			art.draw_circle(c + Vector2(-10, -10), 10.0, col.lightened(0.35))
			if look == "lemon":
				art.draw_line(c + Vector2(0, -34), c + Vector2(10, -46), Color("#5bc27a"), 6.0)
			elif look == "ball":
				art.draw_arc(c, 34.0, 0.0, TAU, 32, Color("#333333"), 3.0)
				art.draw_line(c + Vector2(-34, 0), c + Vector2(34, 0), Color("#333333"), 3.0)
		"donut":
			art.draw_circle(c, 36.0, Color("#d9a066"))
			art.draw_circle(c, 30.0, col)
			art.draw_circle(c, 12.0, Color(0, 0, 0, 0.35))
		"pizza":
			art.draw_colored_polygon(PackedVector2Array([c + Vector2(0, 38), c + Vector2(-36, -30), c + Vector2(36, -30)]), col)
			art.draw_line(c + Vector2(-38, -32), c + Vector2(38, -32), Color("#c9822e"), 10.0)
			for p: Vector2 in [Vector2(-10, -12), Vector2(10, -8), Vector2(0, 12)]:
				art.draw_circle(c + p, 6.0, Color("#c0392b"))
		"gem", "iron", "copper", "silver":
			art.draw_colored_polygon(PackedVector2Array([c + Vector2(0, 40), c + Vector2(-34, -6), c + Vector2(-18, -30), c + Vector2(18, -30), c + Vector2(34, -6)]), col)
			art.draw_colored_polygon(PackedVector2Array([c + Vector2(0, 40), c + Vector2(-12, -6), c + Vector2(12, -6)]), col.lightened(0.3))
		"car":
			art.draw_rect(Rect2(c + Vector2(-42, -6), Vector2(84, 26)), col)
			art.draw_rect(Rect2(c + Vector2(-24, -26), Vector2(48, 22)), col.lightened(0.2))
			art.draw_circle(c + Vector2(-24, 22), 10.0, Color("#222222"))
			art.draw_circle(c + Vector2(24, 22), 10.0, Color("#222222"))
		"fish":
			art.draw_circle(c + Vector2(-6, 0), 26.0, col)
			art.draw_colored_polygon(PackedVector2Array([c + Vector2(18, 0), c + Vector2(42, -20), c + Vector2(42, 20)]), dark)
			art.draw_circle(c + Vector2(-18, -6), 5.0, Color("#222222"))
		"rocket":
			art.draw_rect(Rect2(c + Vector2(-14, -30), Vector2(28, 56)), Color("#eeeeee"))
			art.draw_colored_polygon(PackedVector2Array([c + Vector2(-14, -30), c + Vector2(0, -50), c + Vector2(14, -30)]), col)
			art.draw_circle(c + Vector2(0, -10), 7.0, Color("#4aa3f0"))
			art.draw_colored_polygon(PackedVector2Array([c + Vector2(-8, 26), c + Vector2(0, 46), c + Vector2(8, 26)]), Color("#f0a04a"))
		"oil":
			art.draw_circle(c + Vector2(0, 10), 26.0, col)
			art.draw_colored_polygon(PackedVector2Array([c + Vector2(-22, 0), c + Vector2(0, -42), c + Vector2(22, 0)]), col)
		"coffee":
			art.draw_rect(Rect2(c + Vector2(-26, -20), Vector2(44, 50)), Color("#eeeeee"))
			art.draw_rect(Rect2(c + Vector2(-22, -16), Vector2(36, 12)), col)
			art.draw_arc(c + Vector2(22, 4), 12.0, -PI * 0.5, PI * 0.5, 12, Color("#eeeeee"), 6.0)
		"burger", "cake":
			art.draw_rect(Rect2(c + Vector2(-36, -26), Vector2(72, 18)), col)
			art.draw_rect(Rect2(c + Vector2(-38, -6), Vector2(76, 12)), Color("#5bc27a") if look == "burger" else Color("#ffffff"))
			art.draw_rect(Rect2(c + Vector2(-36, 8), Vector2(72, 16)), Color("#7a3e1d") if look == "burger" else col.darkened(0.15))
			art.draw_rect(Rect2(c + Vector2(-34, 26), Vector2(68, 10)), col)
		"phone", "game", "film", "paper":
			art.draw_rect(Rect2(c + Vector2(-30, -38), Vector2(60, 76)), dark)
			art.draw_rect(Rect2(c + Vector2(-24, -30), Vector2(48, 54)), col)
			for k: int in 3:
				art.draw_line(c + Vector2(-18, -20 + k * 14), c + Vector2(18, -20 + k * 14), dark, 4.0)
		_:
			## Edificio (tienda, banco, hotel, granja, fabrica...).
			art.draw_rect(Rect2(c + Vector2(-38, -14), Vector2(76, 52)), col)
			art.draw_colored_polygon(PackedVector2Array([c + Vector2(-44, -14), c + Vector2(0, -44), c + Vector2(44, -14)]), dark)
			art.draw_rect(Rect2(c + Vector2(-10, 10), Vector2(20, 28)), dark)
			art.draw_rect(Rect2(c + Vector2(-30, -4), Vector2(14, 12)), Color("#fff4c2"))
			art.draw_rect(Rect2(c + Vector2(16, -4), Vector2(14, 12)), Color("#fff4c2"))


# ------------------------------------------------------------------ guardar y sin conexion

func _save_id() -> String:
	return "%d:%s" % [Kit.level_index, str(level.get("name", ""))]


func _autosave() -> void:
	if UI.test_mode or _bot or auto_retry or finished:
		return
	var snap: Dictionary = {}
	for k: String in ["money", "earned", "t", "stations", "ups", "stock"]:
		snap[k] = st[k]
	Save.set_setting(SAVE_KEY, {"level": _save_id(), "snap": snap, "time": Time.get_unix_time_from_system()})
	## Aviso de vuelta: cuando los gerentes hayan llenado la caja (lo maximo sin conexion).
	var r: float = M.rate(st, true)
	Notify.game_reminder = {} if r <= 0.0 else {"delay": int(M.OFFLINE_CAP),
		"content": Kit.text("ty_notify", "Tus gerentes han ganado {n}: \u00a1ven a recogerlo!").format({"n": M.fmt(r * M.OFFLINE_CAP)})}


func _clear_save() -> void:
	var saved: Variant = Save.get_setting(SAVE_KEY, {})
	if saved is Dictionary and not (saved as Dictionary).is_empty():
		Save.set_setting(SAVE_KEY, {})


## Al volver: la partida de este nivel sigue donde estaba y los gerentes han ganado mientras tanto.
func _restore() -> void:
	if UI.test_mode:
		return
	var saved: Variant = Save.get_setting(SAVE_KEY, {})
	if not (saved is Dictionary) or str((saved as Dictionary).get("level", "")) != _save_id():
		return
	var snap: Dictionary = (saved as Dictionary).get("snap", {})
	for k: String in ["money", "earned", "t", "stock"]:
		if snap.has(k):
			st[k] = float(snap[k])
	var stations: Variant = snap.get("stations", {})
	if stations is Dictionary:
		for sid: Variant in stations:
			if (st["stations"] as Dictionary).has(str(sid)):
				var s: Dictionary = st["stations"][str(sid)]
				var old: Dictionary = stations[sid]
				s["n"] = int(old.get("n", s["n"]))
				s["mgr"] = bool(old.get("mgr", false))
				s["box"] = float(old.get("box", 0.0))
	if snap.get("ups", {}) is Dictionary:
		for u: Variant in snap["ups"]:
			st["ups"][str(u)] = true
	var away: float = Time.get_unix_time_from_system() - float((saved as Dictionary).get("time", 0.0))
	var gain: float = M.offline_gain(st, away)
	_refresh(true)
	if gain >= 1.0 and away > 30.0:
		_offline_panel(gain)


func _offline_panel(gain: float) -> void:
	var p: UiModal = UiModal.new()
	p.name = "OfflinePanel"
	add_child(p)
	p.build_frame(Kit.text("ty_offline_title", "Mientras no estabas"))
	var cur: String = str((st["cat"] as Dictionary).get("cur", "$"))
	var l: Label = Label.new()
	l.text = Kit.text("ty_offline", "Tus gerentes han ganado {n}").format({"n": cur + " " + M.fmt(gain)})
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.body.add_child(l)
	var take: Button = UI.make_button(Kit.text("ty_collect", "Recoger"), false, "coin")
	take.name = "BtnCollect"
	take.pressed.connect(func() -> void:
		_collect(gain)
		p.close())
	var buttons: Array[Button] = [take]
	if Ads.rewarded_available():
		var dbl: Button = UI.make_button(Kit.text("ty_double_ad", "x2 con anuncio"), true, "play")
		dbl.name = "BtnDouble"
		dbl.pressed.connect(_collect_double.bind(gain, p))
		buttons.append(dbl)
	p.button_row(buttons)


func _collect(gain: float) -> void:
	M._earn(st, gain)
	_sfx("coin", -2.0)
	_refresh(true)


func _collect_double(gain: float, p: UiModal) -> void:
	var placement: String = "offline_x2"
	var ok: Array[bool] = [false]
	var on_ok: Callable = func(pl: String) -> void:
		if pl == placement:
			ok[0] = true
	Ads.reward_earned.connect(on_ok)
	await Ads.show_rewarded(placement)
	Ads.reward_earned.disconnect(on_ok)
	_collect(gain * (2.0 if ok[0] else 1.0))
	if is_instance_valid(p):
		p.close()


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	_clear_save()
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = maxi(1, int(10000.0 * float(level.get("par", 180.0)) / maxf(1.0, time_in_level)))
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	if not (_bot or auto_retry or UI.test_mode):
		## Inversores: cada estrella es uno mas para los siguientes niveles (+2 % cada uno).
		Save.set_setting(INV_KEY, investors() + stars)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "time": snappedf(time_in_level, 0.1), "buys": int(st["buys"])})
	Audio.play("win")
	Audio.play_track("victoria", false)
	coins = stars
	coins_total = 3
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


## Estrellas por tiempo: hasta "par", 3; hasta 1,5 veces, 2; si no, 1.
func stars_earned() -> int:
	var par: float = maxf(1.0, float(level.get("par", 180.0)))
	return 3 if time_in_level <= par else (2 if time_in_level <= par * 1.5 else 1)


func retry() -> void:
	_reset()


func open_pause() -> void:
	if finished or get_tree().paused or get_node_or_null("PauseMenu") != null:
		return
	_autosave()
	PauseMenu.open(self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_autosave()
		if is_inside_tree() and not UI.test_mode and what != NOTIFICATION_WM_CLOSE_REQUEST:
			open_pause()


func bot_state() -> Dictionary:
	return {"deaths": deaths, "coins": coins, "finished": finished, "failed": failed, "stomps": 0, "time": time_in_level,
		"earned": float(st.get("earned", 0.0)), "target": float(st.get("target", 0.0)), "buys": int(st.get("buys", 0))}
