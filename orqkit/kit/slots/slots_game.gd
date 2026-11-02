extends Node2D
## Tragaperras con aldea (tipo Coin Master): tira, gana monedas de mentira y construye la aldea.
## Tiradas que se recargan con el tiempo (y con un anuncio), bonus de cofres y de asalto.
## Reglas, bot y analizador en slots_map.gd (catalogo por datos en slots_catalog.json).
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel al acabar.

const M = preload("res://kit/slots/slots_map.gd")
const SAVE_KEY: String = "slots_save"
const AD_SPINS: int = 15
const SYM_COLORS: Dictionary = {"coin": "#f2c53d", "bag": "#b07a45", "star": "#ffd84a", "chest": "#c98a3a", "energy": "#5ad1ff",
	"hammer": "#9aa4b5", "pig": "#f59fb8", "cherry": "#e04848", "bell": "#f2c53d", "seven": "#e04848", "gem": "#62e0f0", "crown": "#ffd166"}

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

var _font: Font
var _coins_lbl: Label
var _spins_lbl: Label
var _village: Control
var _machine: Control
var _spin_btn: Button
var _bet_btn: Button
var _ad_btn: Button
var _build_btn: Button
var _msg: Label
var _bonus_box: Control
## Animacion de los rodillos: tiempo que queda y simbolos de paso.
var _roll_t: float = 0.0
var _show: Array = []
var _pending: Dictionary = {}
var _flash: float = 0.0
var _built_flash: Dictionary = {}
var _anim_t: float = 0.0
var _save_t: float = 0.0
var _bot_t: float = 0.0
## Casilla que se dibuja (va alcanzando a la de verdad paso a paso).
var _token: float = 0.0


func _ready() -> void:
	level = Kit.current_level()
	RenderingServer.set_default_clear_color(Color("#2a1e3d"))
	_font = UI.theme.get_font("font", "Label") if UI.theme != null else ThemeDB.fallback_font
	_build_hud()
	_reset()
	_restore()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "slots", "cost": M.village_cost(st)})


func bot_script() -> String:
	return "res://qa/slots_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(3.0, 2.5)


func _reset() -> void:
	finished = false
	failed = false
	var lv: Dictionary = level.duplicate()
	## Cada partida su suerte (el analizador prueba muchas): la semilla cambia al reintentar.
	lv["seed"] = int(level.get("seed", 1)) * 31 + deaths * 977 + (0 if (UI.test_mode or auto_retry) else int(Time.get_unix_time_from_system()) % 100000)
	st = M.new_state(lv)
	time_in_level = 0.0
	_show = ["coin", "star", "bag"]
	_roll_t = 0.0
	_pending = {}
	_refresh()


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
	_coins_lbl = Label.new()
	_coins_lbl.name = "Coins"
	_coins_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_coins_lbl.add_theme_font_size_override("font_size", 46)
	_coins_lbl.add_theme_color_override("font_color", Color("#ffd166"))
	top.add_child(_coins_lbl)
	_spins_lbl = Label.new()
	_spins_lbl.name = "Spins"
	_spins_lbl.add_theme_font_size_override("font_size", 34)
	_spins_lbl.add_theme_color_override("font_color", Color("#9be7ff"))
	top.add_child(_spins_lbl)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)
	_village = Control.new()
	_village.name = "Village"
	_village.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_village.mouse_filter = Control.MOUSE_FILTER_STOP
	_village.draw.connect(_draw_village)
	_village.gui_input.connect(_on_village_input)
	col.add_child(_village)
	_build_btn = UI.make_button("", false, "coin")
	_build_btn.name = "BtnBuild"
	_build_btn.pressed.connect(build_next)
	col.add_child(_build_btn)
	_machine = Control.new()
	_machine.name = "Machine"
	_machine.custom_minimum_size = Vector2(0.0, 300.0)
	_machine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_machine.draw.connect(_draw_machine)
	col.add_child(_machine)
	_bonus_box = Control.new()
	_bonus_box.name = "Bonus"
	_bonus_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bonus_box.mouse_filter = Control.MOUSE_FILTER_STOP
	_bonus_box.visible = false
	_bonus_box.draw.connect(_draw_bonus)
	_bonus_box.gui_input.connect(_on_bonus_input)
	_machine.add_child(_bonus_box)
	_msg = Label.new()
	_msg.name = "Msg"
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg.add_theme_font_size_override("font_size", 34)
	_msg.custom_minimum_size = Vector2(0.0, 48.0)
	col.add_child(_msg)
	var low: HBoxContainer = HBoxContainer.new()
	low.add_theme_constant_override("separation", 10)
	col.add_child(low)
	_bet_btn = UI.make_button("x1", false, "")
	_bet_btn.name = "BtnBet"
	_bet_btn.custom_minimum_size = Vector2(140.0, 110.0)
	_bet_btn.pressed.connect(cycle_bet)
	low.add_child(_bet_btn)
	_spin_btn = UI.make_button(Kit.text("sl_spin", "TIRAR"), true, "play")
	_spin_btn.name = "BtnSpin"
	_spin_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_spin_btn.custom_minimum_size = Vector2(0.0, 110.0)
	_spin_btn.pressed.connect(press_spin)
	low.add_child(_spin_btn)
	_ad_btn = UI.make_button("+%d" % AD_SPINS, false, "play")
	_ad_btn.name = "BtnAdSpins"
	_ad_btn.custom_minimum_size = Vector2(150.0, 110.0)
	_ad_btn.pressed.connect(ad_spins)
	low.add_child(_ad_btn)
	var note: Label = Label.new()
	note.name = "Note"
	note.text = Kit.text("sl_note", "Monedas de mentira: no se compran ni se cambian por dinero")
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 18)
	note.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	col.add_child(note)


# ------------------------------------------------------------------ acciones

func can_act() -> bool:
	return not finished and is_inside_tree() and not get_tree().paused and not st.is_empty()


func rolling() -> bool:
	return _roll_t > 0.0


func cycle_bet() -> void:
	var i: int = M.BETS.find(int(st["bet"]))
	st["bet"] = M.BETS[(i + 1) % M.BETS.size()]
	_sfx("click", -10.0)
	_refresh()


func press_spin() -> void:
	if not can_act() or rolling() or not (st["bonus"] as Dictionary).is_empty():
		return
	if int(st["spins"]) < int(st["bet"]):
		st["bet"] = 1
		if int(st["spins"]) < 1:
			_msg.text = Kit.text("sl_no_spins", "Sin tiradas: espera o mira un anuncio")
			_sfx("hurt", -12.0)
			_refresh()
			return
	var r: Dictionary = M.spin(st)
	if r.is_empty():
		return
	_pending = r
	_msg.text = ""
	_roll_t = 0.0 if fast else 0.9
	_sfx("click", -6.0)
	if fast:
		_land()
	_refresh()


## Los rodillos paran: premio, bonus o nada.
func _land() -> void:
	var r: Dictionary = _pending
	_pending = {}
	if not (r.get("reels", []) as Array).is_empty():
		_show = r["reels"]
	if float(r.get("coins", 0.0)) > 0.0:
		var big: bool = float(r["coins"]) >= 10.0 * M.expected(st) * float(st["bet"])
		_msg.text = "+" + _fmt(float(r["coins"]))
		_flash = 0.8 if big else 0.4
		_sfx("powerup" if big else "coin", -4.0)
		if big and not fast:
			UI.float_text(get_node("Hud"), _machine.global_position + Vector2(_machine.size.x * 0.5 - 80.0, 30.0), Kit.text("sl_big", "\u00a1Premio gordo!"), Color("#ffd166"), 48)
	elif int(r.get("spins", 0)) > 0:
		_msg.text = Kit.text("sl_free", "+{n} tiradas").format({"n": int(r["spins"])})
		_sfx("powerup", -4.0)
	elif str(r.get("bonus", "")) == "pick":
		_msg.text = Kit.text("sl_pick", "Elige un cofre")
		_sfx("powerup", -4.0)
	elif str(r.get("bonus", "")) == "raid":
		_msg.text = Kit.text("sl_raid", "\u00a1Asalto! Excava 3 hoyos")
		_sfx("powerup", -4.0)
	_refresh()


func choose(i: int) -> void:
	if not can_act():
		return
	var b: Dictionary = st["bonus"]
	if str(b.get("kind", "")) == "pick":
		var won: float = M.pick(st, i)
		_msg.text = "+" + _fmt(won)
		_sfx("coin", -2.0)
	elif str(b.get("kind", "")) == "raid":
		var w2: float = M.dig(st, i)
		if w2 < 0.0:
			return
		_msg.text = ("+" + _fmt(w2)) if w2 > 0.0 else Kit.text("sl_empty", "Vacio")
		_sfx("coin" if w2 > 0.0 else "click", -4.0)
	_refresh()


func build_next() -> void:
	if not can_act():
		return
	var nb: Array = M.next_build(st)
	if int(nb[0]) >= 0 and M.build(st, int(nb[0])):
		_built_flash[int(nb[0])] = 0.6
		_sfx("powerup", -4.0)
		_refresh()
		if bool(st["won"]):
			_finish()


func ad_spins() -> void:
	if not can_act():
		return
	var placement: String = "spins"
	var ok: Array[bool] = [false]
	var on_ok: Callable = func(p: String) -> void:
		if p == placement:
			ok[0] = true
	Ads.reward_earned.connect(on_ok)
	await Ads.show_rewarded(placement)
	Ads.reward_earned.disconnect(on_ok)
	if ok[0] and not st.is_empty():
		st["spins"] = int(st["spins"]) + AD_SPINS
		_msg.text = Kit.text("sl_free", "+{n} tiradas").format({"n": AD_SPINS})
		_refresh()


func bot_step() -> void:
	if not can_act() or rolling():
		return
	var nb: Array = M.next_build(st)
	if int(nb[0]) >= 0 and float(nb[1]) <= float(st["coins"]):
		build_next()
		return
	var b: Dictionary = st["bonus"]
	if str(b.get("kind", "")) == "pick":
		choose(randi() % 3)
		return
	if str(b.get("kind", "")) == "raid":
		for i: int in 9:
			if not (b["dug"] as Array).has(i):
				choose(i)
				return
	st["bet"] = M.bot_bet(st)
	press_spin()


func _sfx(n: String, vol: float = -6.0) -> void:
	if not fast:
		Audio.play(n, 0.1, vol)


func _fmt(v: float) -> String:
	if v >= 1000000.0:
		return "%.1fM" % (v / 1000000.0)
	if v >= 10000.0:
		return "%.1fK" % (v / 1000.0)
	return str(int(v))


func _refresh() -> void:
	if st.is_empty() or _coins_lbl == null:
		return
	var cur: String = str((st["cat"] as Dictionary).get("cur", ""))
	_coins_lbl.text = Kit.text("sl_coins", "Monedas {n}").format({"n": (cur + " " if cur != "" else "") + _fmt(float(st["coins"]))})
	var nxt: String = ""
	if int(st["spins"]) < M.MAX_SPINS:
		nxt = "  (%ds)" % int(ceil(float(st["regen"]) - float(st["regen_t"])))
	_spins_lbl.text = Kit.text("sl_spins", "Tiradas {n}").format({"n": int(st["spins"])}) + nxt
	_bet_btn.text = "x%d" % int(st["bet"])
	var busy: bool = rolling() or not (st["bonus"] as Dictionary).is_empty()
	_spin_btn.disabled = busy or finished
	_ad_btn.visible = Ads.rewarded_available() and int(st["spins"]) < 10
	var nb: Array = M.next_build(st)
	if int(nb[0]) >= 0:
		var b: Dictionary = st["builds"][int(nb[0])]
		var nm: String = str((st["cat"]["buildings"] as Dictionary).get(str(b["id"]), {}).get("name", b["id"]))
		_build_btn.text = "  " + Kit.text("sl_build", "Construir {b}").format({"b": nm}) + "   " + _fmt(float(nb[1]))
		_build_btn.disabled = float(nb[1]) > float(st["coins"]) or finished
	else:
		_build_btn.disabled = true
	_bonus_box.visible = not (st["bonus"] as Dictionary).is_empty() and not rolling()
	_village.queue_redraw()
	_machine.queue_redraw()
	_bonus_box.queue_redraw()


# ------------------------------------------------------------------ bucle

func _physics_process(delta: float) -> void:
	if st.is_empty() or finished or get_tree().paused:
		return
	_anim_t += delta
	var reps: int = 4 if fast else 1
	for k: int in reps:
		M.tick(st, delta if not fast else M.SPIN_TIME)
		if fast and auto_retry:
			bot_step()
		if finished:
			return
	time_in_level = float(st["t"])
	if bool(st.get("dice_mode", false)):
		var target: float = float(st["pos"])
		if _roll_t > 0.0 and not _pending.is_empty():
			target = float(_pending.get("from", st["pos"]))
		if int(_token) != int(target):
			_token = fmod(_token + delta * 9.0, float(maxi(1, (st["cat"]["board"] as Array).size())))
			if fast or absf(_token - target) < 0.2:
				_token = target
	if _roll_t > 0.0:
		_roll_t -= delta
		if int(_anim_t * 20.0) % 2 == 0 and not bool(st.get("dice_mode", false)):
			_show = [M._roll(_spin_rng()), M._roll(_spin_rng()), M._roll(_spin_rng())]
		if _roll_t <= 0.0:
			_land()
	_flash = maxf(0.0, _flash - delta)
	for i: Variant in _built_flash.keys():
		_built_flash[i] = float(_built_flash[i]) - delta
		if float(_built_flash[i]) <= 0.0:
			_built_flash.erase(i)
	_refresh()
	_save_t += delta
	if _save_t >= 5.0:
		_save_t = 0.0
		_autosave()


## Rodillos de paso (solo para la animacion: no toca la suerte de verdad).
var _anim_state: Dictionary = {}
func _spin_rng() -> Dictionary:
	if _anim_state.is_empty():
		var r: RandomNumberGenerator = RandomNumberGenerator.new()
		r.randomize()
		_anim_state = {"syms": st["syms"], "total_w": st["total_w"], "cat": st["cat"], "rng": r}
	return _anim_state


# ------------------------------------------------------------------ entrada

func _on_village_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed) or \
		(event is InputEventMouseButton and (event as InputEventMouseButton).pressed and not DisplayServer.is_touchscreen_available())
	if pressed:
		build_next()


func _on_bonus_input(event: InputEvent) -> void:
	var p: Vector2 = Vector2.INF
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		p = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and not DisplayServer.is_touchscreen_available():
		p = (event as InputEventMouseButton).position
	if p == Vector2.INF:
		return
	var rects: Array = _bonus_rects()
	for i: int in rects.size():
		if (rects[i] as Rect2).has_point(p):
			choose(i)
			return


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()


# ------------------------------------------------------------------ dibujo

func _draw_village() -> void:
	var sz: Vector2 = _village.size
	_village.draw_rect(Rect2(Vector2(0, sz.y * 0.62), Vector2(sz.x, sz.y * 0.38)), Color("#4f8a3c"))
	_village.draw_rect(Rect2(Vector2.ZERO, Vector2(sz.x, sz.y * 0.62)), Color("#7cc3f0"))
	_village.draw_circle(Vector2(sz.x * 0.85, sz.y * 0.18), 34.0, Color("#ffe27a"))
	for k: int in 3:
		var cx0: float = fmod(_anim_t * 12.0 + float(k) * sz.x / 3.0, sz.x + 160.0) - 80.0
		var cy0: float = sz.y * (0.12 + 0.1 * float(k % 2))
		for j: int in 3:
			_village.draw_circle(Vector2(cx0 + float(j) * 26.0, cy0 + (8.0 if j == 1 else 0.0)), 22.0, Color(1, 1, 1, 0.85))
	var vname: String = str((st["cat"] as Dictionary).get("village", ""))
	if vname != "":
		_village.draw_string(_font, Vector2(16, 40), vname, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1, 1, 1, 0.9))
	var n: int = (st["builds"] as Array).size()
	for i: int in n:
		var b: Dictionary = st["builds"][i]
		var stage: int = int(b["stage"])
		var cx: float = sz.x * (float(i) + 0.5) / float(n)
		var base_y: float = sz.y * 0.78 + (12.0 if i % 2 == 1 else -12.0)
		var s: float = minf(sz.x / float(n) * 0.7, sz.y * 0.42) * (0.7 + 0.15 * float(stage))
		if _built_flash.has(i):
			s *= 1.0 + float(_built_flash[i]) * 0.4
		var look: String = str((st["cat"]["buildings"] as Dictionary).get(str(b["id"]), {}).get("look", "house"))
		_draw_building(_village, Vector2(cx, base_y), s, look, stage)
		## Estrellas de las mejoras hechas.
		for k: int in (b["costs"] as Array).size():
			var sp: Vector2 = Vector2(cx - 22.0 + 22.0 * float(k), base_y + 26.0)
			_star(_village, sp, 9.0, Color("#ffd166") if k < stage else Color(0, 0, 0, 0.35))


func _draw_building(c: Control, p: Vector2, s: float, look: String, stage: int) -> void:
	if stage == 0:
		## Solar vacio: contorno.
		c.draw_rect(Rect2(p + Vector2(-s * 0.5, -s), Vector2(s, s)), Color(1, 1, 1, 0.25), false, 3.0)
		return
	var wall: Color = [Color("#d9b38c"), Color("#e8c9a0"), Color("#f5dfbf")][mini(stage, 3) - 1]
	var roof: Color = [Color("#8c4a2f"), Color("#b5533c"), Color("#d4573c")][mini(stage, 3) - 1]
	match look:
		"tower", "castle":
			c.draw_rect(Rect2(p + Vector2(-s * 0.3, -s * 1.3), Vector2(s * 0.6, s * 1.3)), wall.darkened(0.1))
			for k: int in 3:
				c.draw_rect(Rect2(p + Vector2(-s * 0.3 + s * 0.24 * float(k), -s * 1.42), Vector2(s * 0.14, s * 0.14)), wall.darkened(0.1))
		"mill":
			c.draw_rect(Rect2(p + Vector2(-s * 0.3, -s * 0.9), Vector2(s * 0.6, s * 0.9)), wall)
			var hub: Vector2 = p + Vector2(0, -s * 0.85)
			for k2: int in 4:
				var a: float = _anim_t * 1.5 + PI * 0.5 * float(k2)
				c.draw_line(hub, hub + Vector2(cos(a), sin(a)) * s * 0.6, Color("#f0f0f0"), 6.0)
		"well":
			c.draw_rect(Rect2(p + Vector2(-s * 0.4, -s * 0.4), Vector2(s * 0.8, s * 0.4)), Color("#9aa4b5"))
			c.draw_line(p + Vector2(-s * 0.35, -s * 0.4), p + Vector2(-s * 0.35, -s), roof, 6.0)
			c.draw_line(p + Vector2(s * 0.35, -s * 0.4), p + Vector2(s * 0.35, -s), roof, 6.0)
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(-s * 0.5, -s), p + Vector2(0, -s * 1.3), p + Vector2(s * 0.5, -s)]), roof)
		"statue":
			c.draw_rect(Rect2(p + Vector2(-s * 0.35, -s * 0.25), Vector2(s * 0.7, s * 0.25)), Color("#9aa4b5"))
			c.draw_circle(p + Vector2(0, -s * 0.85), s * 0.18, Color("#c9cfd8"))
			c.draw_rect(Rect2(p + Vector2(-s * 0.15, -s * 0.7), Vector2(s * 0.3, s * 0.45)), Color("#c9cfd8"))
		"tree":
			c.draw_rect(Rect2(p + Vector2(-s * 0.08, -s * 0.5), Vector2(s * 0.16, s * 0.5)), Color("#7a4e2d"))
			c.draw_circle(p + Vector2(0, -s * 0.8), s * 0.42, Color("#3f9a4a"))
		"tent":
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(-s * 0.55, 0), p + Vector2(0, -s), p + Vector2(s * 0.55, 0)]), roof)
		"ship":
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(-s * 0.6, -s * 0.3), p + Vector2(s * 0.6, -s * 0.3), p + Vector2(s * 0.4, 0), p + Vector2(-s * 0.4, 0)]), Color("#7a4e2d"))
			c.draw_line(p + Vector2(0, -s * 0.3), p + Vector2(0, -s * 1.2), Color("#5a3a20"), 5.0)
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s * 1.15), p + Vector2(s * 0.45, -s * 0.5), p + Vector2(0, -s * 0.5)]), Color("#f5f5f5"))
		_:
			c.draw_rect(Rect2(p + Vector2(-s * 0.45, -s * 0.7), Vector2(s * 0.9, s * 0.7)), wall)
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(-s * 0.55, -s * 0.7), p + Vector2(0, -s * 1.15), p + Vector2(s * 0.55, -s * 0.7)]), roof)
			c.draw_rect(Rect2(p + Vector2(-s * 0.1, -s * 0.35), Vector2(s * 0.2, s * 0.35)), roof.darkened(0.3))


func _star(c: Control, p: Vector2, r: float, col: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for k: int in 10:
		var a: float = -PI * 0.5 + PI * float(k) / 5.0
		pts.append(p + Vector2(cos(a), sin(a)) * (r if k % 2 == 0 else r * 0.45))
	c.draw_colored_polygon(pts, col)


func _draw_machine() -> void:
	if bool(st.get("dice_mode", false)):
		_draw_board()
		return
	var sz: Vector2 = _machine.size
	var frame: Rect2 = Rect2(Vector2(10, 10), sz - Vector2(20, 20))
	_machine.draw_rect(frame, Color("#c0392b"))
	_machine.draw_rect(frame.grow(-12.0), Color("#1a1326"))
	var w: float = (frame.size.x - 24.0 - 20.0) / 3.0
	for i: int in 3:
		var r: Rect2 = Rect2(frame.position + Vector2(12.0 + float(i) * (w + 10.0), 22.0), Vector2(w, frame.size.y - 44.0))
		_machine.draw_rect(r, Color("#f7f1e3"))
		if _flash > 0.0:
			_machine.draw_rect(r, Color(1.0, 0.85, 0.3, _flash * 0.6))
		var sid: String = str(_show[i]) if i < _show.size() else "coin"
		var look: String = str(M.sym(st, sid).get("look", "coin"))
		_draw_sym(_machine, r.get_center(), minf(r.size.x, r.size.y) * 0.32, look)


## Tablero (estilo dados): 20 casillas en anillo, la ficha y los dos dados en medio.
func _board_cell(i: int, n: int, r: Rect2) -> Rect2:
	var side: int = n / 4
	var cw: float = r.size.x / float(side + 1)
	var ch: float = r.size.y / float(side + 1)
	var p: Vector2
	if i < side:
		p = Vector2(float(i) * cw, 0.0)
	elif i < side * 2:
		p = Vector2(float(side) * cw, float(i - side) * ch)
	elif i < side * 3:
		p = Vector2(float(side * 3 - i) * cw, float(side) * ch)
	else:
		p = Vector2(0.0, float(side * 4 - i) * ch)
	return Rect2(r.position + p + Vector2(2, 2), Vector2(cw - 4, ch - 4))


func _draw_board() -> void:
	var sz: Vector2 = _machine.size
	var r: Rect2 = Rect2(Vector2(10, 10), sz - Vector2(20, 20))
	_machine.draw_rect(r, Color("#2f6b3a"))
	var board: Array = st["cat"].get("board", [])
	var cols: Dictionary = {"go": "#ffd166", "coins": "#f7f1e3", "bag": "#e8c9a0", "pick": "#c98a3a", "raid": "#f59fb8", "spin": "#9be7ff", "tax": "#e05a4f"}
	var looks: Dictionary = {"coins": "coin", "bag": "bag", "pick": "chest", "raid": "pig", "spin": "energy", "tax": "hammer", "go": "star"}
	for i: int in board.size():
		var cell: Rect2 = _board_cell(i, board.size(), r)
		_machine.draw_rect(cell, Color(str(cols.get(str(board[i]), "#cccccc"))))
		_draw_sym(_machine, cell.get_center(), minf(cell.size.x, cell.size.y) * 0.28, str(looks.get(str(board[i]), "coin")))
	## Ficha (salta casilla a casilla mientras ruedan los dados).
	var pos: int = int(_token) % maxi(1, board.size())
	var tc: Rect2 = _board_cell(pos, board.size(), r)
	_machine.draw_circle(tc.get_center() + Vector2(0, -6 - absf(sin(_anim_t * 12.0)) * 6.0), 14.0, Color("#4b5bd6"))
	_machine.draw_circle(tc.get_center() + Vector2(0, -10 - absf(sin(_anim_t * 12.0)) * 6.0), 6.0, Color("#ffffff"))
	var dice: Array = st.get("dice", [1, 1])
	var mid: Vector2 = r.get_center()
	for k: int in 2:
		var v: int = randi_range(1, 6) if rolling() else int(dice[k])
		var dr: Rect2 = Rect2(mid + Vector2(-70.0 + 76.0 * float(k), -32.0), Vector2(64, 64))
		_machine.draw_rect(dr, Color("#ffffff"))
		_pips(dr, v)


func _pips(dr: Rect2, v: int) -> void:
	var c: Vector2 = dr.get_center()
	var o: float = dr.size.x * 0.27
	var spots: Array = {1: [Vector2.ZERO], 2: [Vector2(-o, -o), Vector2(o, o)], 3: [Vector2(-o, -o), Vector2.ZERO, Vector2(o, o)],
		4: [Vector2(-o, -o), Vector2(o, -o), Vector2(-o, o), Vector2(o, o)], 5: [Vector2(-o, -o), Vector2(o, -o), Vector2.ZERO, Vector2(-o, o), Vector2(o, o)],
		6: [Vector2(-o, -o), Vector2(o, -o), Vector2(-o, 0), Vector2(o, 0), Vector2(-o, o), Vector2(o, o)]}.get(v, [])
	for s: Variant in spots:
		_machine.draw_circle(c + (s as Vector2), 6.0, Color("#222222"))


## Dibujo de cada simbolo (por "look").
func _draw_sym(c: Control, p: Vector2, s: float, look: String) -> void:
	var col: Color = Color(str(SYM_COLORS.get(look, "#cccccc")))
	match look:
		"coin":
			c.draw_circle(p, s, col)
			c.draw_arc(p, s * 0.72, 0.0, TAU, 32, col.darkened(0.25), 5.0)
		"bag":
			c.draw_circle(p + Vector2(0, s * 0.15), s * 0.85, col)
			c.draw_rect(Rect2(p + Vector2(-s * 0.3, -s * 0.85), Vector2(s * 0.6, s * 0.3)), col.darkened(0.2))
			c.draw_circle(p + Vector2(0, s * 0.2), s * 0.28, Color("#f2c53d"))
		"star":
			_star(c, p, s, col)
		"chest":
			c.draw_rect(Rect2(p + Vector2(-s, -s * 0.3), Vector2(s * 2.0, s * 1.1)), col)
			c.draw_rect(Rect2(p + Vector2(-s, -s * 0.8), Vector2(s * 2.0, s * 0.5)), col.darkened(0.2))
			c.draw_rect(Rect2(p + Vector2(-s * 0.15, -s * 0.45), Vector2(s * 0.3, s * 0.35)), Color("#f2c53d"))
		"energy":
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(s * 0.2, -s), p + Vector2(-s * 0.6, s * 0.15), p + Vector2(-s * 0.05, s * 0.15),
				p + Vector2(-s * 0.25, s), p + Vector2(s * 0.6, -s * 0.2), p + Vector2(s * 0.05, -s * 0.2)]), col)
		"hammer":
			c.draw_line(p + Vector2(-s * 0.5, s * 0.9), p + Vector2(s * 0.3, -s * 0.4), Color("#8b5a3c"), s * 0.25)
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(-s * 0.1, -s), p + Vector2(s * 0.9, -s * 0.35), p + Vector2(s * 0.6, s * 0.05), p + Vector2(-s * 0.4, -s * 0.6)]), col)
		"pig":
			c.draw_circle(p, s * 0.9, col)
			c.draw_circle(p + Vector2(0, s * 0.15), s * 0.35, col.darkened(0.15))
			c.draw_circle(p + Vector2(-s * 0.35, -s * 0.3), s * 0.1, Color("#333333"))
			c.draw_circle(p + Vector2(s * 0.35, -s * 0.3), s * 0.1, Color("#333333"))
		"seven":
			c.draw_string(_font, p + Vector2(-s * 0.45, s * 0.6), "7", HORIZONTAL_ALIGNMENT_LEFT, -1, int(s * 2.0), col)
		"cherry":
			c.draw_circle(p + Vector2(-s * 0.4, s * 0.35), s * 0.4, col)
			c.draw_circle(p + Vector2(s * 0.4, s * 0.35), s * 0.4, col)
			c.draw_line(p + Vector2(-s * 0.4, 0), p + Vector2(0, -s * 0.9), Color("#3f9a4a"), 4.0)
			c.draw_line(p + Vector2(s * 0.4, 0), p + Vector2(0, -s * 0.9), Color("#3f9a4a"), 4.0)
		"bell":
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(-s * 0.8, s * 0.6), p + Vector2(-s * 0.5, -s * 0.6), p + Vector2(0, -s * 0.9), p + Vector2(s * 0.5, -s * 0.6), p + Vector2(s * 0.8, s * 0.6)]), col)
			c.draw_circle(p + Vector2(0, s * 0.75), s * 0.18, col.darkened(0.3))
		"gem":
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, s), p + Vector2(-s, -s * 0.2), p + Vector2(-s * 0.5, -s * 0.8), p + Vector2(s * 0.5, -s * 0.8), p + Vector2(s, -s * 0.2)]), col)
		_:
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(-s, s * 0.6), p + Vector2(-s, -s * 0.5), p + Vector2(-s * 0.5, 0), p + Vector2(0, -s * 0.8),
				p + Vector2(s * 0.5, 0), p + Vector2(s, -s * 0.5), p + Vector2(s, s * 0.6)]), col)


func _bonus_rects() -> Array:
	var b: Dictionary = st.get("bonus", {})
	var sz: Vector2 = _bonus_box.size
	var out: Array = []
	if str(b.get("kind", "")) == "pick":
		var w: float = (sz.x - 80.0) / 3.0
		for i: int in 3:
			out.append(Rect2(Vector2(20.0 + float(i) * (w + 20.0), sz.y * 0.25), Vector2(w, sz.y * 0.5)))
	elif str(b.get("kind", "")) == "raid":
		var cw: float = minf((sz.x - 60.0) / 3.0, (sz.y - 40.0) / 3.0)
		var o: Vector2 = (sz - Vector2(cw * 3.0, cw * 3.0)) * 0.5
		for k: int in 9:
			out.append(Rect2(o + Vector2(float(k % 3), float(k / 3)) * cw + Vector2(4, 4), Vector2(cw - 8.0, cw - 8.0)))
	return out


func _draw_bonus() -> void:
	var b: Dictionary = st.get("bonus", {})
	if b.is_empty():
		return
	_bonus_box.draw_rect(Rect2(Vector2.ZERO, _bonus_box.size), Color(0.08, 0.05, 0.12, 0.92))
	var rects: Array = _bonus_rects()
	for i: int in rects.size():
		var r: Rect2 = rects[i]
		if str(b["kind"]) == "pick":
			_draw_sym(_bonus_box, r.get_center(), r.size.x * 0.3, "chest")
		else:
			var dug: bool = (b["dug"] as Array).has(i)
			_bonus_box.draw_rect(r, Color("#6b4a2b") if not dug else Color("#3a2716"))
			if dug and float(b["holes"][i]) > 0.0:
				_draw_sym(_bonus_box, r.get_center(), r.size.x * 0.28, "coin")


# ------------------------------------------------------------------ guardar

func _save_id() -> String:
	return "%d:%s" % [Kit.level_index, str(level.get("name", ""))]


func _autosave() -> void:
	if UI.test_mode or auto_retry or finished:
		return
	var stages: Array = []
	for b: Variant in st["builds"]:
		stages.append(int(b["stage"]))
	Save.set_setting(SAVE_KEY, {"level": _save_id(), "coins": float(st["coins"]), "spins": int(st["spins"]), "t": float(st["t"]),
		"stages": stages, "time": Time.get_unix_time_from_system()})
	## Aviso de vuelta: tiradas llenas.
	var falta: int = M.MAX_SPINS - int(st["spins"])
	Notify.game_reminder = {} if falta <= 0 else {"delay": int(float(falta) * float(st["regen"])),
		"content": Kit.text("sl_notify", "\u00a1Tienes las tiradas llenas! Ven a construir tu aldea")}


## Al volver: la aldea sigue como estaba y las tiradas se han recargado mientras tanto.
func _restore() -> void:
	if UI.test_mode:
		return
	var sv: Variant = Save.get_setting(SAVE_KEY, {})
	if not (sv is Dictionary) or str((sv as Dictionary).get("level", "")) != _save_id():
		return
	st["coins"] = float(sv.get("coins", 0.0))
	st["spins"] = int(sv.get("spins", st["spins"]))
	st["t"] = float(sv.get("t", 0.0))
	var stages: Array = sv.get("stages", [])
	for i: int in mini(stages.size(), (st["builds"] as Array).size()):
		st["builds"][i]["stage"] = int(stages[i])
	var back: int = M.offline_spins(st, Time.get_unix_time_from_system() - float(sv.get("time", 0.0)))
	st["spins"] = int(st["spins"]) + back
	if back > 0:
		_msg.text = Kit.text("sl_free", "+{n} tiradas").format({"n": back})
	_refresh()


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	Save.set_setting(SAVE_KEY, {})
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = maxi(1, int(10000.0 * float(level.get("par", 300.0)) / maxf(1.0, time_in_level)))
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "time": snappedf(time_in_level, 0.1), "spun": int(st["spun"])})
	Audio.play("win")
	Audio.play_track("victoria", false)
	coins = stars
	coins_total = 3
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


func stars_earned() -> int:
	var par: float = maxf(1.0, float(level.get("par", 300.0)))
	return 3 if time_in_level <= par else (2 if time_in_level <= par * 1.5 else 1)


func retry() -> void:
	_reset()


func open_pause() -> void:
	if finished or get_tree().paused or get_node_or_null("PauseMenu") != null:
		return
	_autosave()
	PauseMenu.open(self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_autosave()
		if is_inside_tree() and not UI.test_mode:
			open_pause()


func bot_state() -> Dictionary:
	return {"deaths": deaths, "coins": coins, "finished": finished, "failed": failed, "stomps": 0, "time": time_in_level,
		"spins": int(st.get("spins", 0)), "built": M.village_cost(st) if not st.is_empty() else 0.0}
