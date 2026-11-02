extends Node2D
## Mundo abierto: muevete con las flechas, salta, manten el dedo sobre un bloque para picarlo y
## toca un hueco con un bloque elegido para ponerlo. Fabrica herramientas con lo que encuentras y
## cumple la meta del nivel. De noche salen monstruos: tocalos para pegarles.
## Reglas, mundo, fisica, bot y analizador en sandbox_map.gd. El mundo se guarda entre niveles.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const MapRules = preload("res://kit/sandbox/sandbox_map.gd")
const T: float = 40.0
const SAVE_KEY: String = "sandbox_world"
const NAMES: Dictionary = {
	"tierra": "Tierra", "arena": "Arena", "piedra": "Piedra", "tronco": "Tronco", "tablas": "Tablas", "palos": "Palos",
	"mesa": "Mesa de trabajo", "pico_madera": "Pico de madera", "espada_madera": "Espada de madera",
	"pico_piedra": "Pico de piedra", "espada_piedra": "Espada de piedra", "horno": "Horno", "carbon": "Carb\u00f3n",
	"antorcha": "Antorcha", "hierro": "Hierro", "lingote_hierro": "Lingote de hierro", "pico_hierro": "Pico de hierro",
	"espada_hierro": "Espada de hierro", "oro": "Oro", "lingote_oro": "Lingote de oro", "cristal": "Cristal",
	"corona": "Corona", "manzana": "Manzana", "monstruo": "Monstruos",
}
const BLOCK_COL: Array = [Color(0, 0, 0, 0), Color("#8a5a3a"), Color("#8a5a3a"), Color("#7d8590"), Color("#8b5e34"),
	Color("#3f9a46"), Color("#7d8590"), Color("#7d8590"), Color("#7d8590"), Color("#7d8590"), Color("#33363d"),
	Color("#c08a4f"), Color("#e3cf8f"), Color(0, 0, 0, 0)]
const ORE_COL: Dictionary = {6: Color("#1f1f24"), 7: Color("#e0a878"), 8: Color("#ffd54a"), 9: Color("#6ee7ff")}

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
var par: float = 0.0

var _font: Font
var _world: Node2D
var _camera: Camera2D
var _info: Label
var _goal_lbl: Label
var _bar: Control
var _hotbar: HBoxContainer
var _craft_panel: PanelContainer
var _craft_list: VBoxContainer
var _selected: String = ""
var _hold: Vector2i = Vector2i(-1, -1)
var _hold_on: bool = false
var _bot: bool = false
var _t: float = 0.0
var _save_t: float = 0.0
var _parts: Array = []
var _inv_sig: String = ""
var _was_night: bool = false
var _hurt_flash: float = 0.0
var _last_hp: int = 10
var _vis_y: float = 0.0
var _hit_sfx: float = 0.0
var _ver: int = 0


func _ready() -> void:
	level = Kit.current_level()
	par = float(level.get("par", 240))
	RenderingServer.set_default_clear_color(Color("#7ec8f0"))
	_font = UI.theme.get_font("font", "Label") if UI.theme != null else ThemeDB.fallback_font
	_world = Node2D.new()
	_world.name = "World"
	_world.draw.connect(_draw_world)
	add_child(_world)
	_camera = Camera2D.new()
	add_child(_camera)
	_camera.make_current()
	_reset()
	_build_hud()
	var tc: Node = (load("res://kit/platformer/touch_controls.gd") as GDScript).new()
	tc.name = "TouchControls"
	add_child(tc)
	_camera.position = _cam_target()
	_camera.reset_smoothing()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "sandbox", "goal": str(st["goal_item"])})


func bot_script() -> String:
	return "res://qa/sandbox_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(0.9, 1.1)


func wants_backdrop() -> bool:
	return false


func _reset() -> void:
	finished = false
	failed = false
	st = MapRules.new_state(level)
	if not UI.test_mode:
		var saved: Variant = Save.meta().get(SAVE_KEY, {})
		if saved is Dictionary:
			MapRules.load_into(st, saved as Dictionary)
	coins_total = int(st["goal_n"])
	coins = 0
	time_in_level = 0.0
	_last_hp = int(st["hp"])
	_vis_y = (st["p"] as Vector2).y
	_refresh()


func _persist() -> void:
	if UI.test_mode or st.is_empty():
		return
	Save.meta()[SAVE_KEY] = MapRules.save_data(st)
	Save.save_data()


func item_name(id: String) -> String:
	return Kit.text("sb_i_" + id, str(NAMES.get(id, id)))


# ------------------------------------------------------------------ interfaz

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
	_bar = Control.new()
	_bar.name = "Bar"
	_bar.custom_minimum_size = Vector2(230, 84)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.draw.connect(_draw_bar)
	top.add_child(_bar)
	var mid: VBoxContainer = VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(mid)
	_goal_lbl = _label(26)
	_goal_lbl.name = "Goal"
	_goal_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	## Un texto largo se recorta y no empuja el boton de pausa fuera de la pantalla.
	_goal_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	mid.add_child(_goal_lbl)
	_info = _label(22)
	_info.name = "Info"
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_info.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_info.modulate = Color(1, 1, 1, 0.85)
	mid.add_child(_info)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)
	## Barra de objetos: tocar uno lo elige (los bloques se ponen tocando un hueco; la manzana se come).
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	var craft_btn: Button = UI.make_button(Kit.text("sb_craft", "Fabricar"), true)
	craft_btn.name = "BtnCraft"
	craft_btn.custom_minimum_size = Vector2(170, 84)
	craft_btn.add_theme_font_size_override("font_size", 26)
	craft_btn.pressed.connect(_toggle_craft)
	row.add_child(craft_btn)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 90)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(scroll)
	_hotbar = HBoxContainer.new()
	_hotbar.add_theme_constant_override("separation", 6)
	scroll.add_child(_hotbar)
	## Menu de fabricar (encima de todo).
	_craft_panel = PanelContainer.new()
	_craft_panel.name = "CraftPanel"
	_craft_panel.visible = false
	_craft_panel.set_anchors_preset(Control.PRESET_CENTER)
	_craft_panel.custom_minimum_size = Vector2(640, 860)
	_craft_panel.position = Vector2(40, 210)
	root.add_child(_craft_panel)
	var pc: VBoxContainer = VBoxContainer.new()
	pc.add_theme_constant_override("separation", 10)
	_craft_panel.add_child(pc)
	var head: HBoxContainer = HBoxContainer.new()
	pc.add_child(head)
	var title: Label = _label(34)
	title.text = Kit.text("sb_craft", "Fabricar")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close: Button = UI.make_button(Kit.text("sb_close", "Cerrar"))
	close.name = "BtnCloseCraft"
	close.custom_minimum_size = Vector2(170, 80)
	close.pressed.connect(_toggle_craft)
	head.add_child(close)
	var sc2: ScrollContainer = ScrollContainer.new()
	sc2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc2.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pc.add_child(sc2)
	_craft_list = VBoxContainer.new()
	_craft_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_craft_list.add_theme_constant_override("separation", 8)
	sc2.add_child(_craft_list)
	_refresh()


func _label(size_px: int) -> Label:
	var l: Label = Label.new()
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _refresh() -> void:
	if st.is_empty() or _goal_lbl == null:
		return
	var g: String = str(st["goal_item"])
	var got: int = mini(int((st["got"] as Dictionary).get(g, 0)), int(st["goal_n"]))
	coins = got
	_goal_lbl.text = "%s: %s %d/%d" % [Kit.text("sb_goal", "Meta"), item_name(g), got, int(st["goal_n"])]
	var nxt: Array = MapRules.bot_goal(st)
	var hint: String = ""
	if nxt.size() == 2 and str(nxt[0]) == "craft":
		hint = Kit.text("sb_hint_craft", "Ya puedes fabricar: %s") % item_name(str(nxt[1]))
	elif nxt.size() == 2 and str(nxt[0]) == "gather":
		hint = Kit.text("sb_hint_get", "Busca: %s") % item_name(str(nxt[1]))
	elif nxt.size() == 2 and str(nxt[0]) == "hunt":
		hint = Kit.text("sb_hint_hunt", "Espera a la noche y lucha")
	_info.text = hint
	## La barra solo se rehace si cambia el inventario.
	var sig: String = JSON.stringify(st["inv"]) + _selected
	if sig != _inv_sig:
		_inv_sig = sig
		_rebuild_hotbar()
	if _bar != null:
		_bar.queue_redraw()


func _rebuild_hotbar() -> void:
	for c: Node in _hotbar.get_children():
		c.queue_free()
	var inv: Dictionary = st["inv"]
	var order: Array = []
	for k: String in MapRules.PLACE:
		if inv.has(k):
			order.append(k)
	if inv.has("manzana"):
		order.append("manzana")
	for k2: String in inv:
		if not order.has(k2):
			order.append(k2)
	if _selected != "" and not inv.has(_selected):
		_selected = ""
	for id: String in order:
		var b: Button = Button.new()
		b.name = "Item_" + id
		b.custom_minimum_size = Vector2(84, 84)
		b.toggle_mode = true
		b.button_pressed = id == _selected
		b.tooltip_text = item_name(id)
		var item: String = id
		b.draw.connect(func() -> void:
			_draw_icon(b, item, Rect2(Vector2(12, 8), Vector2(60, 60)))
			b.draw_string(_font, Vector2(8, 80), str(MapRules.have(st, item)), HORIZONTAL_ALIGNMENT_RIGHT, 70.0, 22, Color.WHITE))
		b.pressed.connect(func() -> void: _pick(item))
		_hotbar.add_child(b)


func _pick(id: String) -> void:
	if id == "manzana":
		if MapRules.eat(st):
			_sfx("powerup")
			UI.float_text(_world, MapRules.center(st) - Vector2(0, 50), "+4", Color("#ff6b6b"), 30)
		_inv_sig = ""
		_refresh()
		return
	_selected = "" if _selected == id or not MapRules.PLACE.has(id) else id
	_inv_sig = ""
	_refresh()


func _toggle_craft() -> void:
	_craft_panel.visible = not _craft_panel.visible
	if _craft_panel.visible:
		_fill_craft()
		UI.pop_in(_craft_panel)


func _fill_craft() -> void:
	for c: Node in _craft_list.get_children():
		c.queue_free()
	var goal: String = str(st["goal_item"])
	for id: String in MapRules.RECIPES:
		var r: Dictionary = MapRules.RECIPES[id]
		var row: PanelContainer = PanelContainer.new()
		row.name = "Recipe_" + id
		var hb: HBoxContainer = HBoxContainer.new()
		hb.add_theme_constant_override("separation", 12)
		row.add_child(hb)
		var ic: Control = Control.new()
		ic.custom_minimum_size = Vector2(72, 72)
		var item: String = id
		ic.draw.connect(func() -> void: _draw_icon(ic, item, Rect2(Vector2(6, 6), Vector2(60, 60))))
		hb.add_child(ic)
		var tx: VBoxContainer = VBoxContainer.new()
		tx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(tx)
		var nm: Label = Label.new()
		nm.text = item_name(id) + ("  x%d" % int(r["out"]) if int(r["out"]) > 1 else "")
		nm.add_theme_font_size_override("font_size", 26)
		if id == goal:
			nm.add_theme_color_override("font_color", Color("#ffd54a"))
		tx.add_child(nm)
		var parts: Array[String] = []
		for k: String in r["in"]:
			parts.append("%d %s" % [int(r["in"][k]), item_name(k).to_lower()])
		if str(r["at"]) != "":
			parts.append(Kit.text("sb_at", "en: %s") % item_name(str(r["at"])).to_lower())
		var ing: Label = Label.new()
		ing.text = ", ".join(parts)
		ing.add_theme_font_size_override("font_size", 20)
		ing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ing.modulate = Color(1, 1, 1, 0.75)
		tx.add_child(ing)
		var mk: Button = UI.make_button(Kit.text("sb_make", "Hacer"), MapRules.can_craft(st, id))
		mk.name = "Make_" + id
		mk.custom_minimum_size = Vector2(130, 76)
		mk.disabled = not MapRules.can_craft(st, id)
		mk.pressed.connect(func() -> void: _craft(item))
		hb.add_child(mk)
		_craft_list.add_child(row)


func _craft(id: String) -> void:
	if not MapRules.craft(st, id):
		return
	_sfx("powerup")
	Juice.vibrate(20)
	UI.float_text(_world, MapRules.center(st) - Vector2(0, 60), "+%d %s" % [int(MapRules.RECIPES[id]["out"]), item_name(id)], Color("#ffd54a"), 28)
	_fill_craft()
	_refresh()
	_check_end()


# ------------------------------------------------------------------ acciones

func can_act() -> bool:
	return not finished and is_inside_tree() and not get_tree().paused


func bot_step() -> void:
	_bot = true


func _sfx(n: String, vol: float = -10.0) -> void:
	if not fast:
		Audio.play(n, 0.1, vol)


func _check_end() -> void:
	if bool(st["won"]):
		_finish()
	elif bool(st["dead"]):
		_lose()


# ------------------------------------------------------------------ bucle

func _physics_process(delta: float) -> void:
	_t += delta
	_hurt_flash = maxf(0.0, _hurt_flash - delta)
	_hit_sfx -= delta
	if finished:
		_world.queue_redraw()
		return
	if fast and auto_retry:
		_bot = true
	var steps: int = 4 if fast else 1
	for k: int in steps:
		if finished or get_tree().paused:
			break
		var inp: Dictionary = {"x": 0.0, "jump": false}
		if _bot:
			MapRules.bot_control(st)
			inp = st["in"]
		else:
			inp = {"x": Input.get_axis("move_left", "move_right"), "jump": Input.is_action_pressed("jump")}
			st["mine_target"] = _hold if _hold_on else Vector2i(-1, -1)
		var was_floor: bool = bool(st["on_floor"])
		MapRules.step(st, inp, delta)
		if bool(inp.get("jump", false)) and was_floor and not bool(st["on_floor"]):
			_sfx("jump", -16.0)
		time_in_level += delta
		_after_step()
	_save_t += delta
	if _save_t > 15.0:
		_save_t = 0.0
		_persist()
	var target: Vector2 = _cam_target()
	_camera.position = _camera.position.lerp(target, minf(1.0, delta * 6.0)) if not fast else target
	_vis_y = lerpf(_vis_y, (st["p"] as Vector2).y, minf(1.0, delta * 18.0))
	if absf(_vis_y - (st["p"] as Vector2).y) > T * 1.5:
		_vis_y = (st["p"] as Vector2).y
	_world.queue_redraw()
	_bar.queue_redraw()


func _after_step() -> void:
	## Bloques rotos: trocitos, sonido y "+1".
	var broke: Array = st["broke"]
	if not broke.is_empty():
		for b: Array in broke:
			var c: Vector2i = b[0]
			var col: Color = BLOCK_COL[int(b[1])] if int(b[1]) < BLOCK_COL.size() else Color.GRAY
			if ORE_COL.has(int(b[1])):
				col = ORE_COL[int(b[1])]
			if not fast:
				for n: int in 6:
					_parts.append({"p": (Vector2(c) + Vector2(randf(), randf())) * T, "v": Vector2(randf_range(-120, 120), randf_range(-260, -60)),
						"t": 0.6, "c": col})
			var drop: String = str(MapRules.BLOCKS[int(b[1])]["drop"])
			if drop != "" and not fast:
				UI.float_text(_world, (Vector2(c) + Vector2(0.5, 0.0)) * T, "+1 " + item_name(drop), Color.WHITE, 22)
		broke.clear()
		_sfx("coin", -14.0)
		Juice.vibrate(8)
		_refresh()
	elif int(st["hp"]) != _last_hp or int(st.get("ver", 0)) != _ver:
		_refresh()
	_ver = int(st.get("ver", 0))
	if (st["mine_cell"] as Vector2i).x >= 0 and _hit_sfx <= 0.0:
		_hit_sfx = 0.22
		_sfx("click", -20.0)
	if int(st["hp"]) < _last_hp:
		_hurt_flash = 0.3
		_sfx("hurt", -8.0)
		Juice.vibrate(30)
	_last_hp = int(st["hp"])
	var night: bool = MapRules.is_night(st)
	## Musica: de noche y bajo tierra, mas apagada; con monstruos cerca, a tope.
	var under: bool = MapRules.feet(st).y > (st["surface"] as PackedInt32Array)[clampi(MapRules.feet(st).x, 0, int(st["w"]) - 1)] + 3
	Audio.set_intensity(1.0 if MapRules.mob_near(st, 6.0) >= 0 else (0.45 if night or under else 0.85))
	if night != _was_night:
		_was_night = night
		if not fast:
			UI.float_text(_world, MapRules.center(st) - Vector2(0, 120), Kit.text("sb_night", "\u00a1Cae la noche!") if night else Kit.text("sb_day", "Amanece"),
				Color("#9fb4ff") if night else Color("#ffe08a"), 36)
	_check_end()


func _cam_target() -> Vector2:
	var c: Vector2 = MapRules.center(st) - Vector2(0, 60)
	var w: float = float(st["w"]) * T
	return Vector2(clampf(c.x, 360.0, w - 360.0), clampf(c.y, 640.0, float(MapRules.H) * T - 640.0))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()
		return
	if not can_act() or _craft_panel.visible:
		return
	var inv: Transform2D = get_canvas_transform().affine_inverse()
	if event is InputEventScreenTouch:
		var te: InputEventScreenTouch = event
		if te.pressed:
			if _on_buttons(te.position):
				return
			_bot = false
			_tap(inv * te.position)
		else:
			_hold_on = false
	elif event is InputEventScreenDrag and _hold_on:
		var dr: InputEventScreenDrag = event
		var q: Vector2 = inv * dr.position
		_hold = Vector2i(floori(q.x / T), floori(q.y / T))


func _on_buttons(sp: Vector2) -> bool:
	var size: Vector2 = get_viewport().get_visible_rect().size
	var y: float = size.y - 130.0
	for c: Vector2 in [Vector2(110.0, y), Vector2(290.0, y), Vector2(size.x - 120.0, y)]:
		if sp.distance_to(c) < 105.0:
			return true
	return false


func _tap(q: Vector2) -> void:
	## 1 - Un monstruo cerca del dedo: golpe.
	var mobs: Array = st["mobs"]
	for k: int in mobs.size():
		if q.distance_to((mobs[k]["p"] as Vector2) - Vector2(0, MapRules.MH * 0.5)) < 60.0:
			if MapRules.hit(st, k):
				_sfx("stomp")
				Juice.vibrate(15)
			return
	var c: Vector2i = Vector2i(floori(q.x / T), floori(q.y / T))
	## 2 - Con un bloque elegido y un hueco: ponerlo.
	if _selected != "" and MapRules.at(st, c.x, c.y) == MapRules.AIR:
		if MapRules.place(st, c, _selected):
			_sfx("land", -12.0)
			_refresh()
		return
	## 3 - Si no, picar mientras se mantiene el dedo.
	_hold = c
	_hold_on = true


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	coins = coins_total
	_persist()
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = maxi(1, 10000 - int(time_in_level) * 10)
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "time": snappedf(time_in_level, 0.1), "deaths": deaths})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


func stars_earned() -> int:
	if deaths > 0:
		return 1
	return 3 if par <= 0.0 or time_in_level <= par else 2


func _lose() -> void:
	if finished:
		return
	finished = true
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "mob", "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("sb_lost", "\u00a1Te han vencido!"),
		Kit.text("sb_fail_hint", "De noche, b\u00fascate un refugio bajo tierra o hazte una espada. Lo que llevabas sigue contigo."))
	p.closed.connect(retry)


## Volver a la vida en el punto de salida, con el inventario y lo conseguido en el nivel.
func retry() -> void:
	finished = false
	failed = false
	MapRules.respawn(st)
	_last_hp = int(st["hp"])
	_refresh()


func open_pause() -> void:
	if finished or get_tree().paused or get_node_or_null("PauseMenu") != null:
		return
	_persist()
	PauseMenu.open(self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_inside_tree() and not UI.test_mode:
			_persist()
			open_pause()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		_persist()


func bot_state() -> Dictionary:
	var g: String = str(st.get("goal_item", ""))
	return {"pos": st.get("p", Vector2.ZERO), "deaths": deaths, "coins": coins, "finished": finished, "failed": failed, "stomps": int(st.get("kills", 0)),
		"time": time_in_level, "got": int((st.get("got", {}) as Dictionary).get(g, 0))}


# ------------------------------------------------------------------ dibujo

func _hash(x: int, y: int) -> int:
	return absi((x * 73856093) ^ (y * 19349663)) % 1000


func _draw_block(ci: CanvasItem, id: int, r: Rect2, x: int, y: int) -> void:
	var col: Color = BLOCK_COL[id]
	match id:
		MapRules.GRASS:
			ci.draw_rect(r, col)
			ci.draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.28)), Color("#5cb84a"))
			ci.draw_rect(Rect2(r.position + Vector2(0, r.size.y * 0.28), Vector2(r.size.x, r.size.y * 0.08)), Color("#3f8a36"))
		MapRules.LOG:
			ci.draw_rect(Rect2(r.position + Vector2(r.size.x * 0.18, 0), Vector2(r.size.x * 0.64, r.size.y)), col)
			ci.draw_rect(Rect2(r.position + Vector2(r.size.x * 0.32, 0), Vector2(r.size.x * 0.08, r.size.y)), col.darkened(0.25))
			ci.draw_rect(Rect2(r.position + Vector2(r.size.x * 0.6, 0), Vector2(r.size.x * 0.06, r.size.y)), col.darkened(0.2))
			return
		MapRules.LEAVES:
			ci.draw_rect(r.grow(2.0), col * Color(1, 1, 1, 0.92))
			for k: int in 3:
				var h: int = _hash(x * 3 + k, y)
				ci.draw_circle(r.position + Vector2(float(h % 37) + 2.0, float((h / 37) % 37) + 2.0) * r.size.x / 40.0, r.size.x * 0.12, col.lightened(0.18))
			return
		MapRules.PLANKS:
			ci.draw_rect(r, col)
			for k2: int in 3:
				ci.draw_line(r.position + Vector2(0, r.size.y * (0.33 * float(k2) + 0.3)), r.position + Vector2(r.size.x, r.size.y * (0.33 * float(k2) + 0.3)), col.darkened(0.25), 2.0)
			return
		MapRules.TORCH:
			ci.draw_rect(Rect2(r.position + Vector2(r.size.x * 0.44, r.size.y * 0.35), Vector2(r.size.x * 0.12, r.size.y * 0.65)), Color("#8b5e34"))
			var fl: float = 0.85 + 0.15 * sin(_t * 12.0 + float(x))
			ci.draw_circle(r.position + Vector2(r.size.x * 0.5, r.size.y * 0.3), r.size.x * 0.16 * fl, Color("#ffb340"))
			ci.draw_circle(r.position + Vector2(r.size.x * 0.5, r.size.y * 0.3), r.size.x * 0.08, Color("#fff3b0"))
			return
		_:
			ci.draw_rect(r, col)
	## Textura: motas con la semilla de la celda (las del mineral, con su color).
	var dots: int = 4 if ORE_COL.has(id) else 2
	for k3: int in dots:
		var h2: int = _hash(x + k3 * 7, y + k3 * 13)
		var pos: Vector2 = r.position + Vector2(float(h2 % 31) + 4.0, float((h2 / 31) % 31) + 4.0) * r.size.x / 40.0
		if ORE_COL.has(id):
			ci.draw_rect(Rect2(pos, Vector2(r.size.x * 0.2, r.size.y * 0.2)), ORE_COL[id])
		else:
			ci.draw_rect(Rect2(pos, Vector2(r.size.x * 0.1, r.size.y * 0.1)), col.darkened(0.18))
	if id == MapRules.CRYSTAL:
		ci.draw_rect(r.grow(-r.size.x * 0.35), Color(0.6, 1, 1, 0.5 + 0.3 * sin(_t * 3.0 + float(x + y))))


func _draw_icon(ci: CanvasItem, id: String, r: Rect2) -> void:
	if MapRules.PLACE.has(id) and id != "antorcha":
		_draw_block(ci, int(MapRules.PLACE[id]), r, 3, 5)
		return
	var c: Vector2 = r.get_center()
	var s: float = r.size.x
	var mat: Color = Color("#c08a4f")
	if id.ends_with("piedra"):
		mat = Color("#9aa3ad")
	elif id.ends_with("hierro"):
		mat = Color("#e6e9ee")
	match id:
		"tronco":
			ci.draw_rect(Rect2(c - Vector2(s * 0.3, s * 0.4), Vector2(s * 0.6, s * 0.8)), Color("#8b5e34"))
			ci.draw_circle(c - Vector2(0, s * 0.4), s * 0.3, Color("#d9a86a"))
		"palos":
			ci.draw_line(c + Vector2(-s * 0.3, s * 0.35), c + Vector2(s * 0.3, -s * 0.35), Color("#8b5e34"), s * 0.12)
		"mesa":
			ci.draw_rect(Rect2(c - Vector2(s * 0.42, s * 0.3), Vector2(s * 0.84, s * 0.2)), Color("#c08a4f"))
			ci.draw_rect(Rect2(c + Vector2(-s * 0.36, -s * 0.1), Vector2(s * 0.12, s * 0.45)), Color("#8b5e34"))
			ci.draw_rect(Rect2(c + Vector2(s * 0.24, -s * 0.1), Vector2(s * 0.12, s * 0.45)), Color("#8b5e34"))
		"horno":
			ci.draw_rect(Rect2(c - Vector2(s * 0.4, s * 0.4), Vector2(s * 0.8, s * 0.8)), Color("#6d737c"))
			ci.draw_rect(Rect2(c + Vector2(-s * 0.2, 0), Vector2(s * 0.4, s * 0.25)), Color("#ff7a2a"))
		"carbon", "hierro", "oro", "cristal":
			var oc: Color = {"carbon": Color("#2a2a30"), "hierro": Color("#e0a878"), "oro": Color("#ffd54a"), "cristal": Color("#6ee7ff")}[id]
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.38), c + Vector2(s * 0.34, 0), c + Vector2(0, s * 0.38), c + Vector2(-s * 0.34, 0)]), oc)
			ci.draw_line(c + Vector2(-s * 0.12, -s * 0.12), c + Vector2(0, -s * 0.24), Color(1, 1, 1, 0.6), 3.0)
		"lingote_hierro", "lingote_oro":
			var ic: Color = Color("#e6e9ee") if id == "lingote_hierro" else Color("#ffd54a")
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.42, s * 0.2), c + Vector2(s * 0.42, s * 0.2), c + Vector2(s * 0.28, -s * 0.15), c + Vector2(-s * 0.28, -s * 0.15)]), ic)
			ci.draw_line(c + Vector2(-s * 0.2, -s * 0.05), c + Vector2(s * 0.1, -s * 0.05), Color(1, 1, 1, 0.7), 3.0)
		"antorcha":
			ci.draw_rect(Rect2(c + Vector2(-s * 0.06, -s * 0.1), Vector2(s * 0.12, s * 0.5)), Color("#8b5e34"))
			ci.draw_circle(c + Vector2(0, -s * 0.2), s * 0.16, Color("#ffb340"))
		"manzana":
			ci.draw_circle(c + Vector2(0, s * 0.05), s * 0.32, Color("#e8483e"))
			ci.draw_line(c + Vector2(0, -s * 0.25), c + Vector2(s * 0.08, -s * 0.4), Color("#5a3a20"), 3.0)
		"corona":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.4, s * 0.25), c + Vector2(s * 0.4, s * 0.25), c + Vector2(s * 0.4, -s * 0.25),
				c + Vector2(s * 0.2, 0), c + Vector2(0, -s * 0.35), c + Vector2(-s * 0.2, 0), c + Vector2(-s * 0.4, -s * 0.25)]), Color("#ffd54a"))
			ci.draw_circle(c + Vector2(0, s * 0.1), s * 0.07, Color("#6ee7ff"))
		"monstruo":
			ci.draw_circle(c, s * 0.34, Color("#3b2a5a"))
			ci.draw_circle(c + Vector2(-s * 0.12, -s * 0.05), s * 0.07, Color("#ff5a5a"))
			ci.draw_circle(c + Vector2(s * 0.12, -s * 0.05), s * 0.07, Color("#ff5a5a"))
		_:
			if id.begins_with("pico"):
				ci.draw_line(c + Vector2(-s * 0.3, s * 0.38), c + Vector2(s * 0.12, -s * 0.1), Color("#8b5e34"), s * 0.1)
				ci.draw_arc(c + Vector2(s * 0.08, s * 0.05), s * 0.42, -PI * 0.95, -PI * 0.15, 10, mat, s * 0.13)
			elif id.begins_with("espada"):
				ci.draw_line(c + Vector2(-s * 0.32, s * 0.32), c + Vector2(s * 0.34, -s * 0.34), mat, s * 0.14)
				ci.draw_line(c + Vector2(-s * 0.32, s * 0.08), c + Vector2(-s * 0.08, s * 0.32), Color("#8b5e34"), s * 0.1)
			else:
				ci.draw_rect(r.grow(-s * 0.2), mat)


func _draw_bar() -> void:
	if st.is_empty():
		return
	## Corazones.
	for k: int in MapRules.MAX_HP / 2:
		var c: Vector2 = Vector2(22.0 + float(k) * 40.0, 24.0)
		var full: int = clampi(int(st["hp"]) - k * 2, 0, 2)
		_heart(c, Color(0, 0, 0, 0.5), 1.15)
		if full > 0:
			_heart(c, Color("#ff4d5e") if full == 2 else Color("#ff9aa5"), 1.0)
	## Reloj del dia: sol o luna y lo que falta.
	var cyc: float = float(st["day"]) + float(st["night"])
	var t: float = fmod(float(st["clock"]), cyc)
	var night: bool = MapRules.is_night(st)
	var left: float = (float(st["day"]) - t) if not night else (cyc - t)
	var ic: Vector2 = Vector2(22.0, 66.0)
	if night:
		_bar.draw_circle(ic, 13.0, Color("#dfe6ff"))
		_bar.draw_circle(ic + Vector2(6, -4), 11.0, Color(0.1, 0.12, 0.25))
	else:
		_bar.draw_circle(ic, 12.0, Color("#ffd54a"))
	_bar.draw_string(_font, Vector2(44.0, 76.0), "%d:%02d" % [int(left) / 60, int(left) % 60], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)


func _heart(c: Vector2, col: Color, sc: float) -> void:
	var r: float = 9.0 * sc
	_bar.draw_circle(c + Vector2(-r * 0.55, -r * 0.2), r * 0.62, col)
	_bar.draw_circle(c + Vector2(r * 0.55, -r * 0.2), r * 0.62, col)
	_bar.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 1.15, 0), c + Vector2(r * 1.15, 0), c + Vector2(0, r * 1.2)]), col)


func _draw_world() -> void:
	if st.is_empty():
		return
	var cam: Vector2 = _camera.position
	var view: Rect2 = Rect2(cam - Vector2(400, 700), Vector2(800, 1400))
	var day: float = MapRules.daylight(st)
	## 1 - Cielo, sol/luna y estrellas.
	var sky: Color = Color("#0b1430").lerp(Color("#7ec8f0"), (day - 0.3) / 0.7)
	_world.draw_rect(view, sky)
	var cyc: float = float(st["day"]) + float(st["night"])
	var ph: float = fmod(float(st["clock"]), cyc)
	if not MapRules.is_night(st):
		var a: float = ph / float(st["day"]) * PI
		_world.draw_circle(cam + Vector2(-cos(a) * 300.0, 120.0 - sin(a) * 420.0) - Vector2(0, 300), 46.0, Color("#ffe27a"))
	else:
		var a2: float = (ph - float(st["day"])) / float(st["night"]) * PI
		for k: int in 30:
			var h: int = _hash(k, 7)
			_world.draw_circle(view.position + Vector2(float(h % 800), float((h * 7) % 600)), 1.5 + float(k % 3), Color(1, 1, 1, 0.5 + 0.3 * sin(_t * 2.0 + float(k))))
		_world.draw_circle(cam + Vector2(-cos(a2) * 300.0, 120.0 - sin(a2) * 420.0) - Vector2(0, 300), 34.0, Color("#e6ecff"))
	## 2 - Celdas a la vista.
	var x0: int = maxi(0, floori(view.position.x / T))
	var x1: int = mini(int(st["w"]) - 1, floori(view.end.x / T))
	var y0: int = maxi(0, floori(view.position.y / T))
	var y1: int = mini(MapRules.H - 1, floori(view.end.y / T))
	var surface: PackedInt32Array = st["surface"]
	var grid: PackedByteArray = st["grid"]
	var w: int = int(st["w"])
	var torches: Array[Vector2] = []
	for y: int in range(maxi(0, y0 - 6), mini(MapRules.H, y1 + 7)):
		for x: int in range(maxi(0, x0 - 6), mini(w, x1 + 7)):
			if grid[y * w + x] == MapRules.TORCH:
				torches.append(Vector2(x, y))
	for y2: int in range(y0, y1 + 1):
		for x2: int in range(x0, x1 + 1):
			var id: int = grid[y2 * w + x2]
			var r: Rect2 = Rect2(Vector2(x2, y2) * T, Vector2(T, T))
			if id == MapRules.AIR or not bool(MapRules.BLOCKS[id]["solid"]):
				if y2 > surface[x2]:
					_world.draw_rect(r, Color("#2b2622") if y2 < surface[x2] + 6 else Color("#22252b"))
			if id != MapRules.AIR:
				_draw_block(_world, id, r, x2, y2)
	## 3 - Grietas de lo que se esta picando.
	var mc: Vector2i = st["mine_cell"]
	if mc.x >= 0:
		var tt: float = MapRules.mine_time(st, MapRules.at(st, mc.x, mc.y))
		var f: float = clampf(float(st["mine_t"]) / maxf(0.01, tt), 0.0, 1.0)
		var r2: Rect2 = Rect2(Vector2(mc) * T, Vector2(T, T))
		_world.draw_rect(r2, Color(0, 0, 0, 0.15 + 0.35 * f))
		for k2: int in int(f * 5.0) + 1:
			var h2: int = _hash(mc.x + k2, mc.y)
			var a3: Vector2 = r2.get_center()
			_world.draw_line(a3, a3 + Vector2(float(h2 % 40) - 20.0, float((h2 / 40) % 40) - 20.0), Color(0, 0, 0, 0.6), 2.0)
		_world.draw_rect(r2, Color(1, 1, 1, 0.7), false, 2.0)
	## 4 - Monstruos y jugador.
	for m: Dictionary in st["mobs"]:
		var mp: Vector2 = m["p"]
		var sq: float = 1.0 + 0.08 * sin(_t * 10.0 + mp.x)
		var mcol: Color = Color("#3b2a5a") if float(m.get("flash", 0.0)) <= 0.0 else Color.WHITE
		_world.draw_rect(Rect2(mp - Vector2(MapRules.MW * 0.5 * sq, MapRules.MH / sq), Vector2(MapRules.MW * sq, MapRules.MH / sq)), mcol)
		var face: float = signf((st["p"] as Vector2).x - mp.x)
		_world.draw_circle(mp + Vector2(face * 6.0 - 6.0, -MapRules.MH * 0.62), 4.0, Color("#ff5a5a"))
		_world.draw_circle(mp + Vector2(face * 6.0 + 6.0, -MapRules.MH * 0.62), 4.0, Color("#ff5a5a"))
	_draw_player()
	for p: Dictionary in _parts:
		var pcol: Color = p["c"]
		pcol.a = clampf(float(p["t"]) * 2.0, 0.0, 1.0)
		_world.draw_rect(Rect2(p["p"], Vector2(7, 7)), pcol)
	_step_parts()
	## 5 - Luz: el cielo alumbra arriba; bajo tierra solo antorchas y tu farol.
	var pc: Vector2 = MapRules.center(st) / T
	for y3: int in range(y0, y1 + 1):
		for x3: int in range(x0, x1 + 1):
			var depth: int = y3 - surface[x3]
			var light: float = day if depth <= 0 else maxf(0.14, day * clampf(1.0 - float(depth) / 10.0, 0.0, 1.0))
			var cc: Vector2 = Vector2(float(x3) + 0.5, float(y3) + 0.5)
			light = maxf(light, 0.85 * clampf(1.0 - cc.distance_to(pc) / 5.0, 0.0, 1.0))
			for tq: Vector2 in torches:
				light = maxf(light, clampf(1.0 - cc.distance_to(tq + Vector2(0.5, 0.5)) / 7.0, 0.0, 1.0))
			if light < 0.97:
				_world.draw_rect(Rect2(Vector2(x3, y3) * T, Vector2(T, T)), Color(0.02, 0.02, 0.06, (1.0 - light) * 0.9))
	if _hurt_flash > 0.0:
		_world.draw_rect(view, Color(1, 0, 0, _hurt_flash * 0.5))


func _draw_player() -> void:
	var p: Vector2 = Vector2((st["p"] as Vector2).x, _vis_y)
	var f: float = float(st["facing"])
	var walk: float = sin(_t * 14.0) * 5.0 if absf((st["v"] as Vector2).x) > 10.0 and bool(st["on_floor"]) else 0.0
	var body: Color = Kit.color("player", Color("#3fa7ff"))
	## Piernas, cuerpo, cabeza y ojos.
	_world.draw_rect(Rect2(p + Vector2(-11, -24 + walk * 0.2), Vector2(9, 24)), Color("#2c3e66"))
	_world.draw_rect(Rect2(p + Vector2(2, -24 - walk * 0.2), Vector2(9, 24)), Color("#2c3e66"))
	_world.draw_rect(Rect2(p + Vector2(-14, -52), Vector2(28, 30)), body)
	_world.draw_rect(Rect2(p + Vector2(-12, -74), Vector2(24, 24)), Color("#f2c49b"))
	_world.draw_rect(Rect2(p + Vector2(-12, -76), Vector2(24, 7)), Color("#5a3a20"))
	_world.draw_rect(Rect2(p + Vector2(f * 4.0 - 2.0, -66), Vector2(4, 5)), Color("#1a1a1a"))
	## Lo que lleva en la mano: el mejor pico (y se mueve al picar).
	var tool: String = ""
	for k: String in ["pico_hierro", "pico_piedra", "pico_madera"]:
		if MapRules.have(st, k) > 0:
			tool = k
			break
	if _selected != "":
		tool = _selected
	if tool != "":
		var swing: float = sin(_t * 18.0) * 0.6 if (st["mine_cell"] as Vector2i).x >= 0 else 0.0
		_world.draw_set_transform(p + Vector2(f * 16.0, -40.0), swing * f, Vector2(f, 1.0))
		_draw_icon(_world, tool, Rect2(Vector2(-6, -24), Vector2(30, 30)))
		_world.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _step_parts() -> void:
	var dt: float = get_physics_process_delta_time()
	var k: int = _parts.size() - 1
	while k >= 0:
		var p: Dictionary = _parts[k]
		p["v"] = (p["v"] as Vector2) + Vector2(0, 900.0 * dt)
		p["p"] = (p["p"] as Vector2) + (p["v"] as Vector2) * dt
		p["t"] = float(p["t"]) - dt
		if float(p["t"]) <= 0.0:
			_parts.remove_at(k)
		k -= 1
