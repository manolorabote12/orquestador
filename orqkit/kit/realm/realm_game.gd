extends Node2D
## Reino (estrategia tipo Kingshot / Whiteout Survival): sube la ciudad, el ejercito se entrena solo
## en tiempo real y conquista los campamentos hasta derrotar al jefe. Reglas, batallas, bot y
## analizador en realm_map.gd (catalogo por datos en realm_catalog.json).
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel al acabar.

const M = preload("res://kit/realm/realm_map.gd")
const SAVE_KEY: String = "realm_save"
const RES_COLORS: Dictionary = {"food": "#f2c53d", "wood": "#b07a45", "stone": "#a7adb8"}
const TROOP_COLORS: Dictionary = {"infantry": "#e05a4f", "cavalry": "#4aa3f0", "archer": "#5bd17a"}

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
var selected: String = ""

var _font: Font
var _res_lbl: Label
var _city: Control
var _army: Control
var _info_lbl: Label
var _up_btn: Button
var _help_btn: Button
var _ad_btn: Button
var _camp_lbl: Label
var _attack_btn: Button
var _rects: Dictionary = {}
var _anim_t: float = 0.0
var _flash: Dictionary = {}
var _think_t: float = 0.0
var _save_t: float = 0.0
var _ui_t: float = 0.0


func _ready() -> void:
	level = Kit.current_level()
	RenderingServer.set_default_clear_color(Color("#203024"))
	_font = UI.theme.get_font("font", "Label") if UI.theme != null else ThemeDB.fallback_font
	_build_hud()
	_reset()
	_restore()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "realm", "camps": (st["camps"] as Array).size()})


func bot_script() -> String:
	return "res://qa/realm_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(25.0, 12.0)


func _reset() -> void:
	finished = false
	failed = false
	st = M.new_state(level)
	time_in_level = 0.0
	_think_t = 0.0
	selected = M.center_id(st["cat"])
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
	_res_lbl = Label.new()
	_res_lbl.name = "Res"
	_res_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_res_lbl.add_theme_font_size_override("font_size", 26)
	_res_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top.add_child(_res_lbl)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)
	_city = Control.new()
	_city.name = "City"
	_city.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_city.mouse_filter = Control.MOUSE_FILTER_STOP
	_city.draw.connect(_draw_city)
	_city.gui_input.connect(_on_city_input)
	col.add_child(_city)
	_army = Control.new()
	_army.name = "Army"
	_army.custom_minimum_size = Vector2(0.0, 84.0)
	_army.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_army.draw.connect(_draw_army)
	col.add_child(_army)
	_info_lbl = Label.new()
	_info_lbl.name = "Info"
	_info_lbl.add_theme_font_size_override("font_size", 24)
	_info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_info_lbl)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	_up_btn = UI.make_button("", true, "")
	_up_btn.name = "BtnUpgrade"
	_up_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_up_btn.clip_text = true
	_up_btn.pressed.connect(press_upgrade)
	row.add_child(_up_btn)
	_help_btn = UI.make_button("", false, "")
	_help_btn.name = "BtnHelp"
	_help_btn.custom_minimum_size = Vector2(150.0, 96.0)
	_help_btn.pressed.connect(press_help)
	row.add_child(_help_btn)
	_ad_btn = UI.make_button(Kit.text("re_finish", "Terminar"), false, "play")
	_ad_btn.name = "BtnFinishAd"
	_ad_btn.custom_minimum_size = Vector2(170.0, 96.0)
	_ad_btn.pressed.connect(press_finish_ad)
	row.add_child(_ad_btn)
	var camp_row: HBoxContainer = HBoxContainer.new()
	camp_row.add_theme_constant_override("separation", 8)
	col.add_child(camp_row)
	_camp_lbl = Label.new()
	_camp_lbl.name = "Camp"
	_camp_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_camp_lbl.add_theme_font_size_override("font_size", 24)
	_camp_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	camp_row.add_child(_camp_lbl)
	_attack_btn = UI.make_button(Kit.text("re_attack", "Atacar"), true, "skull")
	_attack_btn.name = "BtnAttack"
	_attack_btn.custom_minimum_size = Vector2(220.0, 96.0)
	_attack_btn.pressed.connect(press_attack)
	camp_row.add_child(_attack_btn)


# ------------------------------------------------------------------ acciones

func can_act() -> bool:
	return not finished and is_inside_tree() and not get_tree().paused and not st.is_empty()


func select(b: String) -> void:
	selected = b
	_sfx("click", -12.0)
	_refresh()


func press_upgrade() -> void:
	if can_act() and selected != "" and M.upgrade(st, selected):
		_sfx("click", -4.0)
		_refresh()


func press_help() -> void:
	if can_act() and M.help(st):
		_sfx("powerup", -8.0)
		_refresh()


func press_finish_ad() -> void:
	if not can_act() or (st["queue"] as Dictionary).is_empty():
		return
	var placement: String = "finish_build"
	var ok: Array[bool] = [false]
	var on_ok: Callable = func(p: String) -> void:
		if p == placement:
			ok[0] = true
	Ads.reward_earned.connect(on_ok)
	await Ads.show_rewarded(placement)
	Ads.reward_earned.disconnect(on_ok)
	if ok[0] and not st.is_empty():
		M.finish_now(st)
		_refresh()


func press_attack() -> void:
	if not can_act():
		return
	var r: Dictionary = M.attack(st)
	if r.is_empty():
		return
	var at: Vector2 = _city.global_position + _city.size * 0.5
	if bool(r["win"]):
		_sfx("win", -6.0)
		if not fast:
			UI.float_text(get_node("Hud"), at, Kit.text("re_victory", "\u00a1Victoria!"), Color("#ffd166"), 56)
	else:
		_sfx("hurt", -4.0)
		if not fast:
			UI.float_text(get_node("Hud"), at, Kit.text("re_defeat", "Derrota: entrena m\u00e1s"), Color("#ff7b7b"), 44)
	QA.log_event("battle", {"camp": int(r["camp"]), "win": bool(r["win"]), "lost": int(r["lost"])})
	_refresh()
	if bool(st["won"]):
		_finish()


func bot_step() -> void:
	if not can_act():
		return
	M.help(st)
	var b: String = M.bot_build(st)
	if b != "":
		selected = b
		press_upgrade()
	if M.should_attack(st):
		press_attack()


func _sfx(n: String, vol: float = -6.0) -> void:
	if not fast:
		Audio.play(n, 0.1, vol)


func _rname(r: String) -> String:
	return str(st["cat"]["res"].get(r, {}).get("name", r))


func _bname(b: String) -> String:
	return str(st["cat"]["buildings"].get(b, {}).get("name", b))


func _refresh() -> void:
	if st.is_empty() or _res_lbl == null:
		return
	var parts: Array[String] = []
	for r: Variant in st["res"]:
		parts.append("%s %d" % [_rname(str(r)), int(st["res"][r])])
	_res_lbl.text = "   ".join(parts)
	var b: String = selected
	if b != "" and (st["lv"] as Dictionary).has(b):
		var d: Dictionary = st["cat"]["buildings"][b]
		var l: int = int(st["lv"][b])
		var what: String = ""
		match str(d.get("role", "")):
			"prod":
				what = "+%.1f %s/s" % [float(d.get("rate", 1.0)) * float(l), _rname(str(d.get("res", "")))]
			"train":
				var tr: String = str(d.get("troop", ""))
				what = "+%.2f %s/s" % [float(d.get("speed", 0.3)) * float(l), str(st["cat"]["troops"].get(tr, {}).get("name", tr))]
			"center":
				what = Kit.text("re_center", "Ning\u00fan edificio pasa de su nivel")
		_info_lbl.text = _bname(b) + "  " + Kit.text("re_level", "Nv {n}").format({"n": l}) + "  \u00b7  " + what
		var cost: Dictionary = M.up_cost(st, b)
		var cp: Array[String] = []
		for r2: Variant in cost:
			if float(cost[r2]) > 0.0:
				cp.append("%d %s" % [int(cost[r2]), _rname(str(r2))])
		var why: String = M.why_not(st, b)
		var verb: String = Kit.text("re_build", "Construir") if l == 0 else Kit.text("re_upgrade", "Mejorar")
		_up_btn.text = "  " + verb + "  " + ", ".join(cp) + "  (%ds)" % int(ceil(M.up_time(st, b)))
		if why == "center":
			_up_btn.text = "  " + Kit.text("re_need_center", "Sube antes el {c}").format({"c": _bname(M.center_id(st["cat"]))})
		elif why == "max":
			_up_btn.text = "  " + Kit.text("re_max", "Nivel m\u00e1ximo")
		elif why == "busy":
			_up_btn.text = "  " + Kit.text("re_busy", "Obra en marcha")
		_up_btn.disabled = why != ""
		_fit(_up_btn)
	var q: Dictionary = st["queue"]
	_help_btn.disabled = q.is_empty() or float(st["help_t"]) > 0.0
	_help_btn.text = Kit.text("re_help", "Ayuda") if float(st["help_t"]) <= 0.0 else "%ds" % int(ceil(float(st["help_t"])))
	_ad_btn.visible = not q.is_empty() and Ads.rewarded_available()
	var ci: int = M.next_camp(st)
	if ci >= 0:
		var camp: Dictionary = st["camps"][ci]
		var mine: int = M.power(st["cat"], st["army"])
		var theirs: int = M.power(st["cat"], camp["army"])
		## Prevision exacta: si ganas y cuantas tropas pierdes.
		var fc: Dictionary = M.forecast(st)
		var guess: String = Kit.text("re_win", "Ganas: pierdes {n} tropas").format({"n": int(fc["lost"])}) if bool(fc["win"]) \
			else Kit.text("re_lose", "A\u00fan no: perder\u00edas la batalla")
		_camp_lbl.text = ("%s  %d/%d\n" % [str(camp["name"]), ci + 1, (st["camps"] as Array).size()]) + \
			Kit.text("re_power", "Tu poder {a} \u00b7 enemigo {b}").format({"a": mine, "b": theirs}) + "\n" + guess
		_camp_lbl.add_theme_color_override("font_color", Color("#9be79b") if bool(fc["win"]) else Color("#ff9b9b"))
		_attack_btn.disabled = M.total_army(st) < 1.0
	_city.queue_redraw()
	_army.queue_redraw()



## Texto largo (costes con varios recursos): letra mas pequena para que quepa en el boton.
func _fit(b: Button) -> void:
	b.remove_theme_font_size_override("font_size")
	var f: Font = b.get_theme_font("font")
	var fs: int = b.get_theme_font_size("font_size")
	var room: float = b.size.x - 64.0
	var w: float = f.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if room > 0.0 and w > room:
		b.add_theme_font_size_override("font_size", maxi(int(float(fs) * room / w * 0.95), int(float(fs) * 0.55)))

# ------------------------------------------------------------------ bucle

func _physics_process(delta: float) -> void:
	if st.is_empty() or finished or get_tree().paused:
		return
	_anim_t += delta
	var reps: int = 8 if fast else 1
	for k: int in reps:
		if fast and auto_retry and float(st["t"]) >= _think_t:
			_think_t = float(st["t"]) + M.BOT_EVERY
			bot_step()
			if finished:
				return
		var done: Array = M.step(st, delta if not fast else M.DT)
		for b: Variant in done:
			_flash[str(b)] = 0.6
			_sfx("powerup", -6.0)
	time_in_level = float(st["t"])
	for f: Variant in _flash.keys():
		_flash[f] = float(_flash[f]) - delta
		if float(_flash[f]) <= 0.0:
			_flash.erase(f)
	_ui_t -= delta
	if _ui_t <= 0.0 or fast:
		_ui_t = 0.2
		_refresh()
	else:
		_city.queue_redraw()
		_army.queue_redraw()
	_save_t += delta
	if _save_t >= 5.0:
		_save_t = 0.0
		_autosave()


func _on_city_input(event: InputEvent) -> void:
	var p: Vector2 = Vector2.INF
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		p = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and not DisplayServer.is_touchscreen_available():
		p = (event as InputEventMouseButton).position
	if p == Vector2.INF:
		return
	for b: Variant in _rects:
		if (_rects[b] as Rect2).has_point(p):
			select(str(b))
			return


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()


# ------------------------------------------------------------------ dibujo

func _draw_city() -> void:
	var sz: Vector2 = _city.size
	_city.draw_rect(Rect2(Vector2.ZERO, sz), Color("#4f8a3c"))
	## Camino y muralla.
	_city.draw_rect(Rect2(Vector2(sz.x * 0.47, 0), Vector2(sz.x * 0.06, sz.y)), Color("#c9b083"))
	_city.draw_rect(Rect2(Vector2(6, 6), sz - Vector2(12, 12)), Color("#8c96a8"), false, 8.0)
	var ids: Array[String] = M.building_ids(st["cat"])
	var c: String = M.center_id(st["cat"])
	_rects.clear()
	var others: Array[String] = []
	for b: String in ids:
		if b != c:
			others.append(b)
	var cell: Vector2 = Vector2(sz.x / 3.0, sz.y / (1.0 + ceilf(float(others.size()) / 3.0)))
	if c != "":
		_draw_bld(c, Rect2(Vector2(sz.x / 3.0, 0), cell))
	for i: int in others.size():
		var pos: Vector2 = Vector2(float(i % 3) * cell.x, (1.0 + float(i / 3)) * cell.y)
		_draw_bld(others[i], Rect2(pos, cell))


func _draw_bld(b: String, r: Rect2) -> void:
	_rects[b] = r
	var d: Dictionary = st["cat"]["buildings"][b]
	var l: int = int(st["lv"][b])
	var ctr: Vector2 = r.get_center() + Vector2(0, -10)
	var s: float = minf(r.size.x, r.size.y) * (0.32 + 0.03 * float(mini(l, 6)))
	if _flash.has(b):
		s *= 1.0 + float(_flash[b]) * 0.3
	if b == selected:
		_city.draw_circle(ctr, s * 1.25, Color(1.0, 0.85, 0.4, 0.25))
	if l == 0:
		_city.draw_rect(Rect2(ctr - Vector2(s, s * 0.7), Vector2(s * 2.0, s * 1.4)), Color(1, 1, 1, 0.3), false, 3.0)
	else:
		_draw_look(ctr, s, str(d.get("look", "")))
	var q: Dictionary = st["queue"]
	if not q.is_empty() and str(q["b"]) == b:
		var p: float = 1.0 - float(q["left"]) / maxf(0.01, float(q["total"]))
		var bar: Rect2 = Rect2(ctr + Vector2(-s, s * 0.85), Vector2(s * 2.0, 12))
		_city.draw_rect(bar, Color(0, 0, 0, 0.5))
		_city.draw_rect(Rect2(bar.position, Vector2(bar.size.x * p, bar.size.y)), Color("#ffd166"))
		var a: float = sin(_anim_t * 10.0) * 0.6
		var hp: Vector2 = ctr + Vector2(s * 0.8, -s * 0.8)
		_city.draw_line(hp, hp + Vector2(cos(a - 2.0), sin(a - 2.0)) * 26.0, Color("#8b5a3c"), 5.0)
	var badge: Vector2 = ctr + Vector2(-s, -s)
	_city.draw_circle(badge, 18.0, Color("#1c2333"))
	var txt: String = str(l)
	var tw: float = _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	_city.draw_string(_font, badge + Vector2(-tw * 0.5, 8), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
	var nm: String = str(d.get("name", b))
	var nw: float = _font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	_city.draw_string(_font, Vector2(r.get_center().x - nw * 0.5, r.end.y - 6), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.9))


func _draw_look(p: Vector2, s: float, look: String) -> void:
	var wall: Color = Color("#d9c3a0")
	var roof: Color = Color("#b5533c")
	match look:
		"castle":
			_city.draw_rect(Rect2(p + Vector2(-s, -s * 0.5), Vector2(s * 2.0, s * 1.2)), Color("#c9cfd8"))
			for k: int in 3:
				_city.draw_rect(Rect2(p + Vector2(-s + s * 0.8 * float(k), -s * 1.1), Vector2(s * 0.4, s * 0.7)), Color("#aeb6c2"))
				_city.draw_colored_polygon(PackedVector2Array([p + Vector2(-s - 4 + s * 0.8 * float(k), -s * 1.1), p + Vector2(-s + s * 0.2 + s * 0.8 * float(k), -s * 1.5), p + Vector2(-s + s * 0.4 + 4 + s * 0.8 * float(k), -s * 1.1)]), Color("#4b5bd6"))
			_city.draw_rect(Rect2(p + Vector2(-s * 0.25, s * 0.2), Vector2(s * 0.5, s * 0.5)), Color("#5a3a20"))
		"farm":
			_city.draw_rect(Rect2(p + Vector2(-s, s * 0.1), Vector2(s * 2.0, s * 0.6)), Color("#e3c25a"))
			_city.draw_rect(Rect2(p + Vector2(-s * 0.5, -s * 0.6), Vector2(s, s * 0.7)), Color("#c0504d"))
			_city.draw_colored_polygon(PackedVector2Array([p + Vector2(-s * 0.6, -s * 0.6), p + Vector2(0, -s), p + Vector2(s * 0.6, -s * 0.6)]), Color("#7a2e2b"))
		"mill":
			_city.draw_rect(Rect2(p + Vector2(-s * 0.8, -s * 0.4), Vector2(s * 1.6, s)), Color("#8b5a3c"))
			for k2: int in 3:
				_city.draw_circle(p + Vector2(-s * 0.5 + s * 0.5 * float(k2), s * 0.8), s * 0.2, Color("#b07a45"))
		"quarry":
			_city.draw_colored_polygon(PackedVector2Array([p + Vector2(-s, s * 0.7), p + Vector2(-s * 0.3, -s * 0.7), p + Vector2(s * 0.4, -s * 0.2), p + Vector2(s, s * 0.7)]), Color("#8c96a8"))
			_city.draw_rect(Rect2(p + Vector2(-s * 0.2, s * 0.2), Vector2(s * 0.5, s * 0.4)), Color("#c9cfd8"))
		"stable":
			_city.draw_rect(Rect2(p + Vector2(-s, -s * 0.3), Vector2(s * 2.0, s)), Color("#a0663a"))
			_city.draw_colored_polygon(PackedVector2Array([p + Vector2(-s * 1.1, -s * 0.3), p + Vector2(0, -s * 0.9), p + Vector2(s * 1.1, -s * 0.3)]), Color("#5a3a20"))
			_city.draw_rect(Rect2(p + Vector2(-s * 0.3, s * 0.1), Vector2(s * 0.6, s * 0.6)), Color("#3a2716"))
		"range":
			_city.draw_rect(Rect2(p + Vector2(-s * 0.9, -s * 0.4), Vector2(s * 1.8, s)), wall)
			_city.draw_circle(p + Vector2(s * 0.5, -s * 0.8), s * 0.3, Color("#ffffff"))
			_city.draw_circle(p + Vector2(s * 0.5, -s * 0.8), s * 0.18, Color("#e05a4f"))
		_:
			_city.draw_rect(Rect2(p + Vector2(-s * 0.9, -s * 0.4), Vector2(s * 1.8, s)), wall)
			_city.draw_colored_polygon(PackedVector2Array([p + Vector2(-s, -s * 0.4), p + Vector2(0, -s), p + Vector2(s, -s * 0.4)]), roof)


func _draw_army() -> void:
	var sz: Vector2 = _army.size
	_army.draw_rect(Rect2(Vector2.ZERO, sz), Color(0, 0, 0, 0.3))
	var w: float = sz.x / 3.0
	for i: int in M.TYPES.size():
		var t: String = M.TYPES[i]
		var x: float = w * float(i)
		var col: Color = Color(str(TROOP_COLORS.get(t, "#ffffff")))
		var c: Vector2 = Vector2(x + 40.0, sz.y * 0.5)
		## Soldadito: cabeza, cuerpo y su arma (lanza, caballo o arco).
		_army.draw_circle(c + Vector2(0, -16), 10.0, Color("#f1c27d"))
		_army.draw_rect(Rect2(c + Vector2(-10, -6), Vector2(20, 26)), col)
		match t:
			"infantry":
				_army.draw_line(c + Vector2(14, 22), c + Vector2(14, -30), Color("#8b5a3c"), 4.0)
			"cavalry":
				_army.draw_rect(Rect2(c + Vector2(-20, 14), Vector2(40, 12)), Color("#7a4e2d"))
			_:
				_army.draw_arc(c + Vector2(14, 0), 16.0, -PI * 0.5, PI * 0.5, 10, Color("#8b5a3c"), 3.0)
		var n: String = str(int(st["army"][t]))
		var nm: String = str(st["cat"]["troops"].get(t, {}).get("name", t))
		_army.draw_string(_font, Vector2(x + 66.0, sz.y * 0.45), n, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color.WHITE)
		_army.draw_string(_font, Vector2(x + 66.0, sz.y * 0.85), nm, HORIZONTAL_ALIGNMENT_LEFT, w - 70.0, 18, Color(1, 1, 1, 0.7))


# ------------------------------------------------------------------ guardar

func _save_id() -> String:
	return "%d:%s" % [Kit.level_index, str(level.get("name", ""))]


func _autosave() -> void:
	if UI.test_mode or auto_retry or finished:
		return
	var camps: Array = []
	for c: Variant in st["camps"]:
		camps.append({"done": bool(c["done"]), "army": c["army"]})
	Save.set_setting(SAVE_KEY, {"level": _save_id(), "res": st["res"], "lv": st["lv"], "army": st["army"], "heroes": st["heroes"],
		"camps": camps, "queue": st["queue"], "t": float(st["t"]), "time": Time.get_unix_time_from_system()})
	## Aviso de vuelta: obra terminada (o, sin obra, el ejercito ha crecido en una hora).
	var q: Dictionary = st["queue"]
	Notify.game_reminder = {"delay": maxi(600, int(float(q["left"]))) if not q.is_empty() else 3600,
		"content": Kit.text("re_notify_build", "\u00a1Obra terminada! Tu reino te espera") if not q.is_empty() else Kit.text("re_notify_army", "Tu ej\u00e9rcito ha crecido: \u00a1a conquistar!")}


## Al volver: la ciudad sigue y lo que se produce y se entrena ha seguido con la app cerrada (hasta 2 h).
func _restore() -> void:
	if UI.test_mode:
		return
	var sv: Variant = Save.get_setting(SAVE_KEY, {})
	if not (sv is Dictionary) or str((sv as Dictionary).get("level", "")) != _save_id():
		return
	for k: String in ["res", "lv", "army"]:
		if sv.get(k, null) is Dictionary:
			for x: Variant in sv[k]:
				if (st[k] as Dictionary).has(str(x)):
					st[k][str(x)] = sv[k][x] if k != "lv" else int(sv[k][x])
	st["heroes"] = (sv.get("heroes", []) as Array).duplicate()
	var camps: Array = sv.get("camps", [])
	for i: int in mini(camps.size(), (st["camps"] as Array).size()):
		st["camps"][i]["done"] = bool(camps[i].get("done", false))
		if camps[i].get("army", null) is Dictionary:
			st["camps"][i]["army"] = camps[i]["army"]
	if sv.get("queue", {}) is Dictionary:
		st["queue"] = (sv["queue"] as Dictionary).duplicate()
	st["t"] = float(sv.get("t", 0.0))
	var away: float = clampf(Time.get_unix_time_from_system() - float(sv.get("time", 0.0)), 0.0, 7200.0)
	var tt: float = float(st["t"])
	var n: int = int(away / 5.0)
	for k2: int in n:
		M.step(st, 5.0)
	st["t"] = tt
	_refresh()


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	Save.set_setting(SAVE_KEY, {})
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = maxi(1, M.power(st["cat"], st["army"]) * 10 + int(10000.0 * float(level.get("par", 300.0)) / maxf(1.0, time_in_level)))
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "time": snappedf(time_in_level, 0.1), "fights": int(st["fights"])})
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
		"army": int(M.total_army(st)) if not st.is_empty() else 0, "fights": int(st.get("fights", 0)), "camps_left": (M.next_camp(st) if not st.is_empty() else -1)}
