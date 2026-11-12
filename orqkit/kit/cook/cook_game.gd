extends Node2D
## Cocina: gestion de tiempo en un puesto de comida (estilo Cooking Fever). Reglas en cook_map.gd.
## 1 - Toca la carne cruda, las salchichas o las patatas para ponerlas al fuego; cuando esten
##     doradas, toca la plancha para pasarlas a la bandeja elegida (no las dejes quemarse).
## 2 - Toca los ingredientes en orden para montar el plato en la bandeja (pan, carne, lechuga...).
## 3 - Toca al cliente para servirle lo de la bandeja. Cuanta mas paciencia le quede, mas propina.
## 4 - La papelera vacia la bandeja. Gana la meta de monedas antes de que acabe el dia.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const MapRules = preload("res://kit/cook/cook_map.gd")
const SEAT_X: Array[float] = [110.0, 280.0, 450.0, 620.0]
const TRAY_POS: Array[Vector2] = [Vector2(230, 640), Vector2(490, 640)]
## Cajas de ingredientes y fuegos: solo los que usa el menu del nivel (se colocan en _layout).
const ALL_BINS: Array[String] = ["pan", "pan_largo", "lechuga", "queso", "ketchup", "vaso", "tarta"]
const ALL_GRILLS: Array[String] = ["carne", "salchicha", "patatas"]
const HAIR: Array[Color] = [Color("#3a2a1e"), Color("#e8c25a"), Color("#a0402a"), Color("#1e1e26"), Color("#8a6a4a")]
const CUSTOMER_COLORS: Array[Color] = [Color("#e07a5f"), Color("#81b29a"), Color("#f2cc8f"), Color("#7aa6d9"), Color("#c38bd9")]

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
var tray_sel: int = 0
var par: float = 0.0

var _font: Font
var _world: Node2D
## El protagonista del juego hace de cocinero junto a los fuegos (13 nov: la cocina no tenia a nadie).
var _chef: Node2D
var _camera: Camera2D
var _coins_label: Label
var _time_label: Label
var _goal_bar: ColorRect
var _goal_back: ColorRect
var _toast: Label
var _toast_t: float = 0.0
var _pops: Array[Dictionary] = []
var _t: float = 0.0
var _last_coins: int = 0
var _bot_cd: float = 0.0
var BINS: Array = []
var GRILLS: Dictionary = {}


func _ready() -> void:
	level = Kit.current_level()
	par = float(level.get("par", 0))
	RenderingServer.set_default_clear_color(Color("#f2e6d0"))
	_font = UI.theme.get_font("font", "Label") if UI.theme != null else ThemeDB.fallback_font
	_world = Node2D.new()
	_world.name = "World"
	_world.draw.connect(_draw_world)
	add_child(_world)
	_camera = Camera2D.new()
	add_child(_camera)
	_camera.make_current()
	_camera.position = Vector2(360, 640)
	var art: Dictionary = Kit.sprite_by_role("jugador")
	if not art.is_empty():
		_chef = Node2D.new()
		_chef.name = "Chef"
		_chef.z_index = 3
		var sh: Polygon2D = Polygon2D.new()
		sh.polygon = LevelBuilder._circle(62.0, 18)
		sh.scale = Vector2(1.0, 0.3)
		sh.color = Color(0, 0, 0, 0.22)
		_chef.add_child(sh)
		var spr: AnimatedSprite2D = SpriteKit.animado(art, 190.0, "idle", true)
		Skins.apply(spr)
		_chef.add_child(spr)
		add_child(_chef)
	_build_hud()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "cook", "goal": st["goal"]})


func bot_script() -> String:
	return "res://qa/cook_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(14.0, 4.0)


func wants_backdrop() -> bool:
	return false


## Local claro: sin el brillo del etalonaje (lo quemaria).
func wants_grade() -> bool:
	return false


func _reset() -> void:
	finished = false
	failed = false
	st = MapRules.new_state(level)
	_layout()
	coins_total = int(st["goal"])
	tray_sel = 0
	time_in_level = 0.0
	_pops.clear()
	_last_coins = 0
	_refresh()


## 1 - Que ingredientes salen: los de las recetas del menu. Cajas en una fila; fuegos de dos en dos.
func _layout() -> void:
	var used: Dictionary = {}
	for d: Variant in st["menu"]:
		for it: Variant in MapRules.RECIPES[d]["steps"]:
			used[str(it)] = true
	var bins: Array[String] = []
	for it: String in ALL_BINS:
		if used.has(it):
			bins.append(it)
	BINS = []
	var gap: float = minf(112.0, 660.0 / float(maxi(1, bins.size())))
	for i: int in bins.size():
		BINS.append([bins[i], Vector2(360.0 + (float(i) - float(bins.size() - 1) * 0.5) * gap, 862.0)])
	GRILLS = {}
	var n: int = 0
	for it: String in ALL_GRILLS:
		if used.has(it):
			GRILLS[it] = Vector2(150.0 + float(n % 2) * 360.0, 1010.0 + float(n / 2) * 118.0)
			n += 1
	if n == 1:
		GRILLS[GRILLS.keys()[0]] = Vector2(330.0, 1010.0)
	## El cocinero en el hueco libre: entre los fuegos, o a la derecha si solo hay uno en el centro.
	if _chef != null:
		_chef.position = Vector2(615.0, 1235.0) if n == 1 else Vector2(330.0, 1240.0)


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
	safe.add_child(col)
	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 10)
	col.add_child(top)
	top.add_child(UiIcon.make("coin", Kit.color("coin", Color("#ffd23f")), 44.0))
	_coins_label = Label.new()
	_coins_label.name = "Coins"
	_coins_label.add_theme_font_size_override("font_size", 34)
	_coins_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_coins_label.add_theme_constant_override("outline_size", 7)
	top.add_child(_coins_label)
	var bar: Control = Control.new()
	bar.custom_minimum_size = Vector2(0, 30)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(bar)
	_goal_back = ColorRect.new()
	_goal_back.color = Color(0, 0, 0, 0.45)
	_goal_back.set_anchors_preset(Control.PRESET_FULL_RECT)
	_goal_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(_goal_back)
	_goal_bar = ColorRect.new()
	_goal_bar.color = Color("#56d36a")
	_goal_bar.position = Vector2(3, 3)
	_goal_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(_goal_bar)
	_time_label = Label.new()
	_time_label.name = "Time"
	_time_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_time_label.add_theme_constant_override("outline_size", 6)
	top.add_child(_time_label)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)
	_toast = Label.new()
	_toast.name = "Toast"
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.add_theme_color_override("font_color", Color("#fff3c0"))
	_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_toast.add_theme_constant_override("outline_size", 7)
	col.add_child(_toast)


func _toast_now(t: String) -> void:
	_toast.text = t
	_toast_t = 2.2


func _refresh() -> void:
	if _coins_label == null or st.is_empty():
		return
	_coins_label.text = "%d/%d" % [int(st["coins"]), int(st["goal"])]
	_goal_bar.size = Vector2(maxf(0.0, (_goal_back.size.x - 6.0) * clampf(float(st["coins"]) / float(st["goal"]), 0.0, 1.0)), _goal_back.size.y - 6.0)
	var left: int = maxi(0, int(ceil(float(st["seconds"]) - float(st["time"]))))
	_time_label.text = "%d:%02d" % [left / 60, left % 60]
	coins = mini(int(st["coins"]), coins_total)


# ------------------------------------------------------------------ acciones

func can_act() -> bool:
	return not finished and is_inside_tree() and not get_tree().paused


func tap_world(p: Vector2) -> void:
	if not can_act():
		return
	## Clientes.
	if p.y > 170.0 and p.y < 520.0:
		for i: int in SEAT_X.size():
			if absf(p.x - SEAT_X[i]) < 80.0:
				if MapRules.serve(st, tray_sel, i):
					_sfx("coin")
				elif not fast:
					_toast_now(Kit.text("cook_wrong", "Eso no es lo que ha pedido"))
				return
	## Bandejas y papelera.
	for i: int in TRAY_POS.size():
		if p.distance_to(TRAY_POS[i]) < 110.0:
			tray_sel = i
			return
	if p.distance_to(Vector2(660, 650)) < 50.0:
		MapRules.clear_tray(st, tray_sel)
		_sfx("click")
		return
	## Ingredientes.
	for b: Array in BINS:
		if p.distance_to(b[1]) < 55.0:
			if MapRules.add(st, tray_sel, str(b[0])):
				_sfx("click")
			elif not fast:
				_toast_now(Kit.text("cook_order", "No va en ese orden"))
			return
	## Fuegos: tocar la caja de crudos (izquierda) cocina; tocar un hueco hecho lo sirve.
	for k: Variant in GRILLS:
		var g: Vector2 = GRILLS[k]
		if p.distance_to(g + Vector2(-70, 0)) < 45.0:
			if MapRules.start_cook(st, str(k)):
				_sfx("click")
			return
		var slots: Array = st["grill"][k]
		for i: int in slots.size():
			if p.distance_to(_slot_pos(str(k), i)) < 40.0:
				var state: String = MapRules.cook_state(str(k), float(slots[i]["t"]))
				if state == "burnt":
					MapRules.trash_slot(st, str(k), i)
				elif state == "done":
					MapRules.add(st, tray_sel, str(k))
				return


func _sfx(n: String) -> void:
	if not fast:
		Audio.play(n, 0.1, -6.0)


func bot_step() -> void:
	MapRules.bot_act(st)


# ------------------------------------------------------------------ bucle

func _physics_process(delta: float) -> void:
	if finished:
		return
	var steps: int = 4 if fast else 1
	var dt: float = 0.25 if fast else delta
	for k: int in steps:
		if fast and auto_retry:
			_bot_cd -= dt
			if _bot_cd <= 0.0 and MapRules.bot_act(st):
				_bot_cd = 0.35
		MapRules.step(st, dt)
		if st["won"] or st["over"]:
			break
	_t += delta
	time_in_level = float(st["time"])
	if int(st["coins"]) > _last_coins:
		_pops.append({"text": "+%d" % (int(st["coins"]) - _last_coins), "t": 1.0})
		if _chef != null and not fast:
			Juice.squash(_chef, Vector2(0.86, 1.16), 0.3)
			Juice.sparkle(self, _chef.position + Vector2(0, -170), Kit.color("coin", Color("#ffd23f")), 8, 180.0)
		_last_coins = int(st["coins"])
	var keep: Array[Dictionary] = []
	for p: Dictionary in _pops:
		p["t"] = float(p["t"]) - delta
		if float(p["t"]) > 0.0:
			keep.append(p)
	_pops = keep
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0:
			_toast.text = ""
	_refresh()
	if st["won"]:
		_finish()
	elif st["over"]:
		_lose()
	_world.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()
		return
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		tap_world(get_canvas_transform().affine_inverse() * (event as InputEventScreenTouch).position)


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = int(st["coins"]) * 10 + maxi(0, int(float(st["seconds"]) - float(st["time"]))) * 20
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "time": snappedf(time_in_level, 0.1), "deaths": deaths,
		"served": int(st["served"]), "lost": int(st["lost"])})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


func stars_earned() -> int:
	if deaths > 0:
		return 1
	if int(st["lost"]) == 0 and (par <= 0.0 or time_in_level <= par * 1.4):
		return 3
	return 2


func _lose() -> void:
	if finished:
		return
	finished = true
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "cook", "coins": int(st["coins"]), "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("cook_lost", "\u00a1Se acab\u00f3 el d\u00eda!"),
		Kit.text("cook_fail_hint", "Pon la carne al fuego antes de que la pidan y sirve primero a quien tenga menos paciencia."))
	p.closed.connect(retry)


func retry() -> void:
	_reset()


func open_pause() -> void:
	if finished or get_tree().paused or get_node_or_null("PauseMenu") != null:
		return
	PauseMenu.open(self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_inside_tree() and not UI.test_mode:
			open_pause()


func bot_state() -> Dictionary:
	return {"pos": Vector2(float(st.get("coins", 0)), float(st.get("served", 0))), "deaths": deaths, "coins": coins, "finished": finished,
		"failed": failed, "stomps": 0, "time": time_in_level, "served": int(st.get("served", 0)), "lost": int(st.get("lost", 0))}


# ------------------------------------------------------------------ dibujo

func _slot_pos(item: String, i: int) -> Vector2:
	return GRILLS[item] + Vector2(float(i) * 66.0, 0)


func _text(at: Vector2, s: String, size: int, col: Color) -> void:
	var wd: float = _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p: Vector2 = at - Vector2(wd * 0.5, 0.0)
	for o: Vector2 in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)]:
		_world.draw_string(_font, p + o, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.8))
	_world.draw_string(_font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


static func draw_ing(ci: CanvasItem, item: String, c: Vector2, k: float, state: String = "done") -> void:
	match item:
		"pan":
			ci.draw_set_transform(c, 0.0, Vector2(1.0, 0.45))
			ci.draw_circle(Vector2.ZERO, 26.0 * k, Color("#d9953b"))
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			for i: int in 3:
				ci.draw_circle(c + Vector2(-10 + i * 10, -5) * k, 1.6 * k, Color("#fff3d0"))
		"carne":
			var col: Color = {"raw": Color("#d9707a"), "done": Color("#7a4426"), "burnt": Color("#2a1a12")}.get(state, Color("#7a4426"))
			ci.draw_set_transform(c, 0.0, Vector2(1.0, 0.4))
			ci.draw_circle(Vector2.ZERO, 24.0 * k, col)
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"lechuga":
			for i: int in 4:
				ci.draw_circle(c + Vector2(-15 + i * 10, sin(float(i)) * 3.0) * k, 8.0 * k, Color("#6fc04a"))
		"queso":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-22, -4) * k, c + Vector2(22, -4) * k, c + Vector2(14, 6) * k, c + Vector2(-14, 6) * k]), Color("#f5c842"))
		"pan_largo":
			ci.draw_set_transform(c, 0.0, Vector2(1.0, 0.32))
			ci.draw_circle(Vector2.ZERO, 30.0 * k, Color("#d9953b"))
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"salchicha":
			var col2: Color = {"raw": Color("#e88a8a"), "done": Color("#b0503a"), "burnt": Color("#2a1a12")}.get(state, Color("#b0503a"))
			ci.draw_line(c + Vector2(-22, 0) * k, c + Vector2(22, 0) * k, col2, 10.0 * k)
		"ketchup":
			ci.draw_rect(Rect2(c + Vector2(-9, -16) * k, Vector2(18, 30) * k), Color("#d9302a"))
			ci.draw_rect(Rect2(c + Vector2(-4, -24) * k, Vector2(8, 9) * k), Color("#f4f4f4"))
		"patatas":
			var col3: Color = {"raw": Color("#f5e6a0"), "done": Color("#f2c84b"), "burnt": Color("#5a4020")}.get(state, Color("#f2c84b"))
			ci.draw_rect(Rect2(c + Vector2(-14, -2) * k, Vector2(28, 20) * k), Color("#d9302a"))
			for i: int in 5:
				ci.draw_line(c + Vector2(-10 + i * 5, 0) * k, c + Vector2(-12 + i * 6, -18) * k, col3, 4.0 * k)
		"vaso":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-12, -18) * k, c + Vector2(12, -18) * k, c + Vector2(9, 18) * k, c + Vector2(-9, 18) * k]), Color("#3f8cff"))
			ci.draw_line(c + Vector2(4, -18) * k, c + Vector2(8, -30) * k, Color("#ffffff"), 3.0 * k)
		"tarta":
			ci.draw_rect(Rect2(c + Vector2(-18, -4) * k, Vector2(36, 16) * k), Color("#e8c08a"))
			ci.draw_rect(Rect2(c + Vector2(-18, -10) * k, Vector2(36, 7) * k), Color("#ff9ab8"))
			ci.draw_circle(c + Vector2(0, -14) * k, 4.0 * k, Color("#e8344a"))


## Dibujo de un plato entero (para los bocadillos de los clientes).
static func draw_dish(ci: CanvasItem, dish: String, c: Vector2, k: float) -> void:
	var steps: Array = MapRules.RECIPES[dish]["steps"]
	for i: int in steps.size():
		draw_ing(ci, str(steps[i]), c + Vector2(0, -float(i) * 7.0 * k), k)
	if steps[0] == "pan":
		draw_ing(ci, "pan", c + Vector2(0, -float(steps.size()) * 7.0 * k), k)


func _draw_world() -> void:
	if st.is_empty():
		return
	## Pared con azulejos, ventana y suelo del local.
	_world.draw_rect(Rect2(-100, -100, 920, 640), Color("#f6ead6"))
	for y: int in range(0, 540, 40):
		for x: int in range(0, 760, 40):
			if (x / 40 + y / 40) % 2 == 0:
				_world.draw_rect(Rect2(float(x), float(y), 40, 40), Color("#efdcbf"))
	_world.draw_rect(Rect2(-100, 520, 920, 900), Color("#9a6a42"))
	_world.draw_rect(Rect2(-100, 520, 920, 40), Color("#7a4a26"))
	## Toldo.
	for i: int in 10:
		_world.draw_rect(Rect2(-100.0 + float(i) * 92.0, 110, 92, 40), Color("#e0483e") if i % 2 == 0 else Color("#fbfbf6"))
	## Pizarra con el menu y sus precios, lamparas y estantes (detras de los clientes).
	var board: Rect2 = Rect2(Vector2(180, 196), Vector2(360, 230))
	_world.draw_rect(board.grow(10.0), Color("#8a5a32"))
	_world.draw_rect(board, Color("#2f4a3a"))
	var menu: Array = st["menu"]
	for j: int in menu.size():
		var cx: float = board.position.x + 60.0 + float(j % 3) * 120.0
		var cy: float = board.position.y + 66.0 + float(j / 3) * 104.0
		draw_dish(_world, str(menu[j]), Vector2(cx, cy), 0.75)
		_text(Vector2(cx, cy + 44.0), "%d" % int(MapRules.RECIPES[menu[j]]["price"]), 24, Color("#fff3c0"))
	for lx: float in [60.0, 660.0]:
		_world.draw_line(Vector2(lx, 150), Vector2(lx, 200), Color("#3a3a3a"), 3.0)
		_world.draw_colored_polygon(PackedVector2Array([Vector2(lx - 26, 228), Vector2(lx + 26, 228), Vector2(lx + 12, 200), Vector2(lx - 12, 200)]), Color("#3e6e5a"))
		_world.draw_circle(Vector2(lx, 232), 8.0, Color("#fff3a0"))
		_world.draw_rect(Rect2(Vector2(lx - 50, 330), Vector2(100, 10)), Color("#8a5a32"))
		for q: int in 3:
			_world.draw_rect(Rect2(Vector2(lx - 42 + float(q) * 30.0, 300), Vector2(22, 30)), [Color("#e0483e"), Color("#f2c84b"), Color("#6fc04a")][q])
	## Clientes.
	var seats: Array = st["seats"]
	for i: int in seats.size():
		var s: Dictionary = seats[i]
		if s.is_empty():
			continue
		var p: Vector2 = Vector2(SEAT_X[i], 420 + sin(_t * 3.0 + float(i)) * 3.0)
		var col: Color = CUSTOMER_COLORS[(i + int(st["n"])) % CUSTOMER_COLORS.size()]
		var f: float = float(s["patience"]) / float(s["max"])
		var hair: Color = HAIR[(i * 3 + int(st["n"])) % HAIR.size()]
		_world.draw_circle(p + Vector2(0, 22), 38.0, col)
		_world.draw_rect(Rect2(p + Vector2(-38, 22), Vector2(76, 80)), col)
		_world.draw_rect(Rect2(p + Vector2(-8, 4), Vector2(16, 30)), col.lightened(0.35))
		_world.draw_circle(p + Vector2(0, -24), 34.0, Color("#f1c9a0"))
		_world.draw_circle(p + Vector2(-33, -22), 8.0, Color("#e8b88a"))
		_world.draw_circle(p + Vector2(33, -22), 8.0, Color("#e8b88a"))
		_world.draw_arc(p + Vector2(0, -26), 34.0, PI * 1.02, TAU * 0.99, 16, hair, 16.0)
		_world.draw_circle(p + Vector2(-18, -14), 6.0, Color(1.0, 0.55, 0.55, 0.45))
		_world.draw_circle(p + Vector2(18, -14), 6.0, Color(1.0, 0.55, 0.55, 0.45))
		_world.draw_circle(p + Vector2(-12, -28), 4.0, Color("#2a2a2a"))
		_world.draw_circle(p + Vector2(12, -28), 4.0, Color("#2a2a2a"))
		if f > 0.4:
			_world.draw_arc(p + Vector2(0, -16), 10.0, 0.3, PI - 0.3, 8, Color("#2a2a2a"), 3.0)
		else:
			_world.draw_arc(p + Vector2(0, -6), 10.0, PI + 0.3, TAU - 0.3, 8, Color("#2a2a2a"), 3.0)
		## Bocadillo con el pedido.
		var pending: Array = (s["order"] as Array).duplicate()
		for g: Variant in s["got"]:
			pending.erase(g)
		var b: Rect2 = Rect2(p + Vector2(-60, -190), Vector2(120, 110))
		_world.draw_rect(b, Color(1, 1, 1, 0.95))
		_world.draw_colored_polygon(PackedVector2Array([p + Vector2(-10, -80), p + Vector2(10, -80), p + Vector2(0, -62)]), Color(1, 1, 1, 0.95))
		for j: int in pending.size():
			draw_dish(_world, str(pending[j]), b.position + Vector2(60.0 + (float(j) - float(pending.size() - 1) * 0.5) * 54.0, 70.0), 0.8)
		## Paciencia.
		_world.draw_rect(Rect2(p + Vector2(-40, 108), Vector2(80, 10)), Color(0, 0, 0, 0.4))
		_world.draw_rect(Rect2(p + Vector2(-40, 108), Vector2(80.0 * f, 10)), Color("#56d36a").lerp(Color("#e0404a"), 1.0 - f))
	## Mostrador con las bandejas y la papelera.
	_world.draw_rect(Rect2(-100, 560, 920, 170), Color("#c98a5a"))
	_world.draw_rect(Rect2(-100, 560, 920, 16), Color("#e0a874"))
	for i: int in TRAY_POS.size():
		var tp: Vector2 = TRAY_POS[i]
		_world.draw_set_transform(tp, 0.0, Vector2(1.0, 0.5))
		_world.draw_circle(Vector2.ZERO, 100.0, Color("#fbfbf6"))
		_world.draw_arc(Vector2.ZERO, 100.0, 0.0, TAU, 32, Color("#ffd23f") if i == tray_sel else Color("#d0c8b8"), 10.0 if i == tray_sel else 4.0)
		_world.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var tray: Array = st["trays"][i]
		for j: int in tray.size():
			draw_ing(_world, str(tray[j]), tp + Vector2(0, 10.0 - float(j) * 12.0), 1.3)
		var dish: String = MapRules.tray_dish(st, tray)
		if dish != "":
			_text(tp + Vector2(0, 76), "\u2713", 30, Color("#2f8a3a"))
	_world.draw_rect(Rect2(Vector2(630, 615), Vector2(60, 70)), Color("#6a6a72"))
	_world.draw_rect(Rect2(Vector2(624, 605), Vector2(72, 14)), Color("#8a8a92"))
	## Cocina: cajas de ingredientes y fuegos.
	_world.draw_rect(Rect2(-100, 760, 920, 700), Color("#5a5a62"))
	for y: int in range(760, 1300, 60):
		for x: int in range(0, 720, 60):
			if (x / 60 + y / 60) % 2 == 0:
				_world.draw_rect(Rect2(float(x), float(y), 60, 60), Color("#626270"))
	_world.draw_rect(Rect2(-100, 760, 920, 12), Color("#44444c"))
	for b: Array in BINS:
		var bp: Vector2 = b[1]
		_world.draw_rect(Rect2(bp - Vector2(48, 44), Vector2(96, 88)), Color("#d8d0c0"))
		_world.draw_rect(Rect2(bp - Vector2(48, 44), Vector2(96, 88)), Color("#8a8072"), false, 3.0)
		draw_ing(_world, str(b[0]), bp, 1.2)
	for k: Variant in GRILLS:
		var g: Vector2 = GRILLS[k]
		## Caja de crudos para poner al fuego.
		_world.draw_rect(Rect2(g + Vector2(-110, -36), Vector2(70, 72)), Color("#e8e0d0"))
		draw_ing(_world, str(k), g + Vector2(-75, 0), 0.9, "raw")
		var slots: Array = st["grill"][k]
		var w: float = 66.0 * float(slots.size()) + 10.0
		_world.draw_rect(Rect2(g + Vector2(-46, -50), Vector2(w + 16, 100)), Color("#9aa0a8"))
		_world.draw_rect(Rect2(g + Vector2(-46, -50), Vector2(w + 16, 8)), Color("#c4c9d0"))
		_world.draw_rect(Rect2(g + Vector2(-38, -40), Vector2(w, 80)), Color("#2a2a2e") if str(k) != "patatas" else Color("#c0a040"))
		for i: int in slots.size():
			var fp: Vector2 = _slot_pos(str(k), i) + Vector2(0, 30)
			var fl: float = 4.0 + 2.0 * sin(_t * 11.0 + float(i) * 1.7)
			if float(slots[i]["t"]) >= 0.0:
				for q: int in 3:
					_world.draw_circle(fp + Vector2(-12.0 + float(q) * 12.0, 0), fl, Color("#ff8a2a"))
					_world.draw_circle(fp + Vector2(-12.0 + float(q) * 12.0, 1), fl * 0.5, Color("#ffe066"))
			else:
				_world.draw_arc(_slot_pos(str(k), i), 26.0, 0.0, TAU, 20, Color(1, 1, 1, 0.12), 2.0)
		for i: int in slots.size():
			var sp: Vector2 = _slot_pos(str(k), i)
			var t: float = float(slots[i]["t"])
			var state: String = MapRules.cook_state(str(k), t)
			if state == "empty":
				continue
			draw_ing(_world, str(k), sp, 1.0, state)
			if state == "raw" or state == "done":
				var lim: float = float(MapRules.COOK[k]["done"]) if state == "raw" else float(MapRules.COOK[k]["burn"])
				var base: float = 0.0 if state == "raw" else float(MapRules.COOK[k]["done"])
				var fr: float = clampf((t - base) / (lim - base), 0.0, 1.0)
				_world.draw_arc(sp, 30.0, -PI * 0.5, -PI * 0.5 + TAU * fr, 20, Color("#ffd23f") if state == "raw" else Color("#ff6b5b"), 4.0)
			if state == "done":
				var s2: float = fmod(_t * 18.0, 22.0)
				_world.draw_circle(sp + Vector2(6, -18 - s2), 4.0, Color(1, 1, 1, 0.6 - s2 / 40.0))
			if state == "burnt":
				_world.draw_circle(sp + Vector2(0, -24 - fmod(_t * 20.0, 20.0)), 7.0, Color(0.2, 0.2, 0.2, 0.6))
	for p: Dictionary in _pops:
		_text(Vector2(120, 210 - (1.0 - float(p["t"])) * 40.0), str(p["text"]), 38, Color("#ffd23f"))
