extends Node2D
## Imperio: estrategia en tiempo real (estilo Age of Empires / Guerras Tribales) en el movil.
## 1 - Aldeanos: recogen comida (bayas y granjas), madera y oro y lo llevan al centro urbano o a
##     un almacen. Toca un recurso arriba para mandar un aldeano mas a ese trabajo.
## 2 - Construir: casas (poblacion), granjas, almacen, cuartel, arqueria, establo, taller y torres.
##     Toca un edificio, mueve la sombra tocando el mapa y confirma.
## 3 - Edades: la II desbloquea arqueros, jinetes y torres; la III arietes, y cada edad hace mas
##     fuertes a tus tropas.
## 4 - Ejercito: lancero gana a jinete, jinete a arquero y arquero a lancero; el ariete derriba
##     edificios. "Atacar" manda a todo el ejercito a por la base rival; tocar el mapa lo mueve ahi.
## 5 - El rival tiene su propia economia, entrena con sus edificios (si los destruyes, deja de
##     entrenar esas tropas) y ataca por oleadas cada vez mas grandes.
## 6 - Ganas al destruir todos los centros rivales; pierdes si cae el tuyo. Estrellas: 1 por
##     ganar, +1 si lo haces antes del par (segundos) y +1 si tu centro sigue con mas de la mitad.
## Mapa y tablas: ver empire_map.gd (las mismas que el bot y la fabrica).
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const MapRules = preload("res://kit/empire/empire_map.gd")
const CELL: float = 40.0
const MINE: int = 0
const RIVAL: int = 1
const OWNER_COLORS: Array[Color] = [Color("#3f8cff"), Color("#e0483e")]
const TICK_FAST: float = 0.1
const STEPS_FAST: int = 6

var rows: Array[String] = []
var level: Dictionary = {}
var finished: bool = false
var failed: bool = false
var deaths: int = 0
var time_in_level: float = 0.0
var coins: int = 0
var coins_total: int = 0
var fast: bool = false
var auto_retry: bool = false
var result_panel: ResultPanel

var w: int = 0
var h: int = 0
var terrain: PackedByteArray = PackedByteArray()
var amount: Dictionary = {}
var buildings: Array[Dictionary] = []
var units: Array[Dictionary] = []
var stock: Array[Dictionary] = [{}, {}]
var age: Array[int] = [1, 1]
var aging: float = 0.0
var par: float = 480.0
var seconds: float = 0.0
var ai: Dictionary = {}
var waves_sent: int = 0
var next_wave: float = 0.0
var lost_buildings: int = 0
var rally: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var speed: float = 1.0
## Campana de alarma: los aldeanos se esconden en el centro y los almacenes (y disparan flechas).
var bell: bool = false
## Niebla de guerra (giro "niebla" o level.fog): solo se ve lo que tienen cerca tus aldeanos,
## tropas y edificios; lo explorado se recuerda (los edificios rivales, no sus tropas).
var fog: bool = false
var explored: PackedByteArray = PackedByteArray()
var seen: PackedByteArray = PackedByteArray()
var _fog_t: float = 0.0
var _fog_layer: Node2D
## Modo de construir: tipo elegido y casilla de la sombra.
var placing: String = ""
var ghost: Vector2i = Vector2i(-1, -1)

var _blocked: PackedByteArray = PackedByteArray()
var _occ: Dictionary = {}
var _fields: Dictionary = {}
var _dirty: bool = true
var _ground_dirty: bool = true
var _next_id: int = 0
var _ai_t: float = 0.0
var _clean_t: float = 0.0
var _alarm: Array[Dictionary] = [{}, {}]
var _fx: Array[Dictionary] = []
var _hud_t: float = 0.0
var _toast_t: float = 0.0
var _tab: String = "aldea"

var _ground: Node2D
var _world: Node2D
var _camera: Camera2D
var _chips: Array[Button] = []
var _info: Label
var _toast: Label
var _actions: HBoxContainer
var _tabs: Dictionary = {}
var _speed_btn: Button
var _press_pos: Vector2 = Vector2.ZERO
var _pressing: bool = false
var _dragging: bool = false


## Icono pequeno de cada recurso (espiga, tronco y pepita) para los botones de arriba.
class ResIcon:
	extends Control
	var kind: String = "comida"

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		match kind:
			"comida":
				draw_line(c + Vector2(0, 14), c + Vector2(0, -12), Color("#c99a3b"), 3.0)
				for k: int in 4:
					draw_circle(c + Vector2(-5, -8 + k * 6), 4.0, Color("#f2c84b"))
					draw_circle(c + Vector2(5, -5 + k * 6), 4.0, Color("#f2c84b"))
			"madera":
				draw_rect(Rect2(c + Vector2(-14, -6), Vector2(28, 12)), Color("#8a5a2b"))
				draw_circle(c + Vector2(14, 0), 6.0, Color("#d9a066"))
				draw_circle(c + Vector2(14, 0), 2.5, Color("#8a5a2b"))
			_:
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -13), c + Vector2(12, 0), c + Vector2(0, 13), c + Vector2(-12, 0)]), Color("#ffd23f"))
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -13), c + Vector2(5, 0), c + Vector2(0, 13), c + Vector2(-5, 0)]), Color("#fff1a6"))


func _ready() -> void:
	level = Kit.current_level()
	if not level.has("empire") and Kit.param("empire", null) is Dictionary:
		level = level.duplicate()
		level["empire"] = Kit.param("empire", {})
	MapRules.apply(level)
	RenderingServer.set_default_clear_color(Color(str(_biome()["g"])).darkened(0.6))
	_ground = Node2D.new()
	_ground.name = "Ground"
	_ground.draw.connect(_draw_ground)
	add_child(_ground)
	_world = Node2D.new()
	_world.name = "World"
	_world.draw.connect(_draw_world)
	add_child(_world)
	_fog_layer = Node2D.new()
	_fog_layer.name = "Fog"
	_fog_layer.draw.connect(_draw_fog)
	add_child(_fog_layer)
	_camera = Camera2D.new()
	add_child(_camera)
	_camera.make_current()
	Juice.register_camera(_camera)
	_build_hud()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "empire", "w": w, "h": h, "rivals": coins_total})


func bot_script() -> String:
	return "res://qa/empire_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(50.0, 12.0)


# ------------------------------------------------------------------ montaje

func _reset() -> void:
	finished = false
	failed = false
	time_in_level = 0.0
	rows.clear()
	for r: Variant in level.get("map", []):
		rows.append(str(r))
	var p: Dictionary = MapRules.parse(rows)
	w = int(p["w"])
	h = int(p["h"])
	terrain = (p["terrain"] as PackedByteArray).duplicate()
	amount.clear()
	for y: int in h:
		for x: int in w:
			var t: int = terrain[y * w + x]
			if MapRules.NODE_AMOUNT.has(t):
				amount[Vector2i(x, y)] = float(MapRules.NODE_AMOUNT[t])
	buildings.clear()
	units.clear()
	_occ.clear()
	_fields.clear()
	_fx.clear()
	_alarm = [{}, {}]
	for b: Dictionary in p["buildings"]:
		_add_building(str(b["kind"]), int(b["owner"]), b["cell"], true)
	var st: Dictionary = level.get("start", {})
	stock[MINE] = {"comida": float(st.get("comida", 200)), "madera": float(st.get("madera", 200)), "oro": float(st.get("oro", 100))}
	stock[RIVAL] = {"comida": 50.0, "madera": 50.0, "oro": 0.0}
	age = [1, 1]
	aging = 0.0
	ai = MapRules.AI_DEFAULT.duplicate()
	ai.merge(level.get("ai", {}), true)
	par = float(level.get("par", 480))
	seconds = float(level.get("seconds", 0))
	waves_sent = 0
	bell = false
	next_wave = float(ai["first_wave"])
	lost_buildings = 0
	_ai_t = 0.0
	placing = ""
	coins = 0
	coins_total = 0
	for b: Dictionary in buildings:
		if int(b["owner"]) == RIVAL:
			coins_total += 1
	_rebuild_blocked()
	_set_rallies()
	fog = bool(level.get("fog", false)) or Twist.has("niebla")
	explored = PackedByteArray()
	explored.resize(w * h)
	seen = PackedByteArray()
	seen.resize(w * h)
	_fog_t = 0.0
	var home: int = main_center(MINE)
	var jobs: Array[String] = ["comida", "madera", "comida", "oro", "madera"]
	for k: int in int(level.get("villagers", 3)):
		var u: Dictionary = _spawn("aldeano", MINE, home)
		if not u.is_empty():
			u["job"] = jobs[k % jobs.size()]
	_update_fog()
	_ground_dirty = true
	_ground.queue_redraw()
	_fit_camera()
	_show_tab(_tab if _tab != "" else "aldea")
	_update_hud()


func _add_building(kind: String, owner: int, c: Vector2i, done: bool) -> Dictionary:
	var info: Dictionary = MapRules.builds[kind]
	var s: int = int(info["size"])
	var mx: float = float(info["hp"])
	var b: Dictionary = {"id": _next_id, "kind": kind, "owner": owner, "cell": c, "size": s, "max": mx,
		"hp": mx if done else mx * 0.1, "done": done, "prog": 1.0 if done else 0.0, "queue": [], "qt": 0.0, "cd": 0.0,
		"alive": true, "food": MapRules.FARM_FOOD if kind == "granja" else 0.0}
	_next_id += 1
	buildings.append(b)
	for dy: int in s:
		for dx: int in s:
			_occ[c + Vector2i(dx, dy)] = b
	_dirty = true
	return b


func _rebuild_blocked() -> void:
	_blocked = MapRules.blocked_grid(w, h, terrain, _occ)
	_fields.clear()
	_dirty = false


func _set_rallies() -> void:
	for o: int in 2:
		var me: int = main_center(o)
		var foe: int = main_center(1 - o)
		if me < 0:
			continue
		var a: Vector2 = center_of(buildings[me])
		var b: Vector2 = center_of(buildings[foe]) if foe >= 0 else Vector2(float(w) * 0.5, float(h) * 0.5)
		var p: Vector2 = a + (b - a).normalized() * 4.0
		rally[o] = _free_near(p)


func _fit_camera() -> void:
	var vp: Vector2 = get_viewport_rect().size
	var z: float = clampf(vp.x / (float(w) * CELL), 0.45, 1.4)
	_camera.zoom = Vector2.ONE * z
	var home: int = main_center(MINE)
	var at: Vector2 = center_of(buildings[home]) * CELL if home >= 0 else Vector2(float(w), float(h)) * CELL * 0.5
	_camera.position = at + Vector2(0.0, -40.0)
	_clamp_camera()


func _clamp_camera() -> void:
	var vp: Vector2 = get_viewport_rect().size / _camera.zoom
	var mw: float = float(w) * CELL
	var mh: float = float(h) * CELL
	var hx: float = vp.x * 0.5
	var hy: float = vp.y * 0.5
	_camera.position.x = mw * 0.5 if mw <= vp.x else clampf(_camera.position.x, hx, mw - hx)
	## Se deja margen arriba y abajo para que el mapa no quede tapado por la interfaz.
	_camera.position.y = mh * 0.5 if mh + 520.0 / _camera.zoom.y <= vp.y else clampf(_camera.position.y, hy - 220.0 / _camera.zoom.y, mh - hy + 300.0 / _camera.zoom.y)


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
	var safe: MarginContainer = UI.safe_root(root, 16.0)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col: VBoxContainer = VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 8)
	safe.add_child(col)
	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 8)
	col.add_child(top)
	for r: String in MapRules.RES:
		var b: Button = UI.make_button("", false, "")
		b.name = "Chip_" + r
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		b.custom_minimum_size = Vector2(UI.MIN_TOUCH, UI.MIN_TOUCH)
		var ic: ResIcon = ResIcon.new()
		ic.kind = r
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.custom_minimum_size = Vector2(34, 34)
		ic.size = Vector2(34, 34)
		ic.position = Vector2(10, 27)
		b.add_child(ic)
		b.pressed.connect(assign.bind(r))
		## Que quepan los cuatro recursos, la velocidad y la pausa en un movil estrecho.
		b.custom_minimum_size = Vector2(0.0, UI.MIN_TOUCH)
		b.clip_text = true
		b.add_theme_font_size_override("font_size", 22)
		top.add_child(b)
		_chips.append(b)
	_speed_btn = UI.make_button("x1", false, "")
	_speed_btn.name = "BtnSpeed"
	_speed_btn.custom_minimum_size = Vector2(UI.MIN_TOUCH, UI.MIN_TOUCH)
	_speed_btn.pressed.connect(toggle_speed)
	top.add_child(_speed_btn)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)
	_info = Label.new()
	_info.name = "Info"
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.add_theme_color_override("font_color", UI.colors["texto"])
	_info.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_info.add_theme_constant_override("outline_size", 6)
	col.add_child(_info)
	_toast = Label.new()
	_toast.name = "Toast"
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.add_theme_color_override("font_color", Kit.color("accent", Color("#ffd23f")))
	_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_toast.add_theme_constant_override("outline_size", 8)
	col.add_child(_toast)
	var grow: Control = Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(grow)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "ActionsScroll"
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 150)
	col.add_child(scroll)
	_actions = HBoxContainer.new()
	_actions.name = "Actions"
	_actions.add_theme_constant_override("separation", 8)
	scroll.add_child(_actions)
	var tabs: HBoxContainer = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	col.add_child(tabs)
	var names: Dictionary = {"aldea": Kit.text("empire_tab_village", "Aldea"), "construir": Kit.text("empire_tab_build", "Construir"),
		"ejercito": Kit.text("empire_tab_army", "Ej\u00e9rcito")}
	for k: String in ["aldea", "construir", "ejercito"]:
		var t: Button = UI.make_button(str(names[k]), false, "")
		t.name = "Tab_" + k
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.toggle_mode = true
		t.custom_minimum_size = Vector2(0.0, t.custom_minimum_size.y)
		t.clip_text = true
		t.pressed.connect(_show_tab.bind(k))
		tabs.add_child(t)
		_tabs[k] = t


func _cost_text(cost: Dictionary) -> String:
	var parts: Array[String] = []
	var short: Dictionary = {"comida": Kit.text("empire_food_short", "C"), "madera": Kit.text("empire_wood_short", "M"), "oro": Kit.text("empire_gold_short", "O")}
	for rn: String in MapRules.res_names:
		short[rn] = str(MapRules.res_names[rn]).substr(0, 1).to_upper()
	for k: String in MapRules.RES:
		if cost.has(k):
			parts.append("%d%s" % [int(cost[k]), str(short[k])])
	return " ".join(parts)


## Boton de accion: nombre arriba y coste (o lo que falta) debajo.
func _card(id: String, title: String, sub: String, enabled: bool, cb: Callable, primary: bool = false) -> Button:
	var b: Button = UI.make_button("", primary, "")
	b.name = "Act_" + id
	b.custom_minimum_size = Vector2(150, 132)
	b.disabled = not enabled
	b.pressed.connect(cb)
	var v: VBoxContainer = VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	for k: int in 2:
		var l: Label = Label.new()
		l.text = title if k == 0 else sub
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(140, 0)
		if k == 1:
			l.add_theme_font_size_override("font_size", 22)
			l.add_theme_color_override("font_color", UI.colors["texto_suave"])
		v.add_child(l)
	_actions.add_child(b)
	return b


func _name(kind: String) -> String:
	var es: Dictionary = {"aldeano": "Aldeano", "lancero": "Lancero", "arquero": "Arquero", "jinete": "Jinete", "ariete": "Ariete",
		"casa": "Casa", "granja": "Granja", "almacen": "Almac\u00e9n", "cuartel": "Cuartel", "arqueria": "Arquer\u00eda",
		"establo": "Establo", "taller": "Taller", "torre": "Torre", "muro": "Muro", "centro": "Centro urbano"}
	## Lo que nombra el propio juego (estilo o contenido inventado) manda.
	var own: String = MapRules.custom_name(kind)
	if own != "":
		return own
	return Kit.text("empire_" + kind, str(es.get(kind, kind)))


func _show_tab(k: String) -> void:
	_tab = k
	for t: Variant in _tabs:
		(_tabs[t] as Button).button_pressed = t == k
	_rebuild_actions()


func _rebuild_actions() -> void:
	if _actions == null:
		return
	for c: Node in _actions.get_children():
		_actions.remove_child(c)
		c.queue_free()
	if placing != "":
		_card("place", Kit.text("empire_place_here", "Construir aqu\u00ed"), _name(placing), can_place(placing, ghost), confirm_place, true)
		_card("cancel", Kit.text("empire_cancel", "Cancelar"), "", true, cancel_place)
		return
	var st: Dictionary = stock[MINE]
	match _tab:
		"aldea":
			var cost: Dictionary = MapRules.units["aldeano"]["cost"]
			_card("aldeano", _name("aldeano"), _cost_text(cost), MapRules.can_pay(st, cost), train.bind("aldeano"), true)
			if age[MINE] < 3:
				var nxt: int = age[MINE] + 1
				var title: String = Kit.text("empire_age_up", "Edad {n}").format({"n": _roman(nxt)})
				var sub: String = Kit.text("empire_aging", "Avanzando...") if aging > 0.0 else _cost_text(MapRules.age_cost[nxt])
				_card("age", title, sub, aging <= 0.0 and MapRules.can_pay(st, MapRules.age_cost[nxt]), age_up)
			if age[MINE] >= 2:
				for r: String in ["comida", "madera"]:
					_card("sell_" + r, Kit.text("empire_sell", "Mercado"), "%d%s > %d%s" % [MapRules.TRADE_GIVE, _cost_text({r: 1}).trim_prefix("1"),
						MapRules.TRADE_GET, _cost_text({"oro": 1}).trim_prefix("1")], MapRules.can_pay(st, {r: MapRules.TRADE_GIVE}), trade.bind(r))
			_card("bell", Kit.text("empire_bell", "Campana"), Kit.text("empire_bell_back", "Volver") if bell else Kit.text("empire_bell_hide", "Esconderse"), true, ring_bell)
		"construir":
			for kind: String in MapRules.PLAYER_BUILD:
				var info: Dictionary = MapRules.builds[kind]
				var need: int = int(info.get("age", 1))
				var sub2: String = _cost_text(info.get("cost", {})) if age[MINE] >= need else Kit.text("empire_needs_age", "Edad {n}").format({"n": _roman(need)})
				_card(kind, _name(kind), sub2, age[MINE] >= need and MapRules.can_pay(st, info.get("cost", {})), start_place.bind(kind))
		"ejercito":
			_card("attack", Kit.text("empire_attack", "\u00a1Atacar!"), "%d" % army_count(MINE), army_count(MINE) > 0, attack, true)
			_card("recall", Kit.text("empire_recall", "Volver"), "", army_count(MINE) > 0, recall)
			for kind: String in MapRules.ARMY:
				var src: String = _trainer_of(kind)
				var ok: bool = has_building(src, MINE)
				var cost2: Dictionary = MapRules.units[kind]["cost"]
				var sub3: String = _cost_text(cost2) if ok else Kit.text("empire_needs", "Necesita {b}").format({"b": _name(src)})
				_card(kind, _name(kind), sub3, ok and MapRules.can_pay(st, cost2), train.bind(kind))


func _roman(n: int) -> String:
	return ["", "I", "II", "III"][clampi(n, 0, 3)]


func _update_hud() -> void:
	if _info == null:
		return
	var st: Dictionary = stock[MINE]
	for i: int in MapRules.RES.size():
		var r: String = MapRules.RES[i]
		_chips[i].text = "%d \u00b7%d " % [int(st[r]), workers(r)]
	var t: int = int(time_in_level)
	var age_txt: String = Kit.text("empire_age", "Edad {n}").format({"n": _roman(age[MINE])})
	if aging > 0.0:
		age_txt += " (%ds)" % int(ceil(aging))
	_info.text = "%s   %s %d/%d   %d:%02d" % [age_txt, Kit.text("empire_pop", "Poblaci\u00f3n"), pop(MINE), pop_cap(MINE), t / 60, t % 60]
	_speed_btn.text = "x%d" % int(speed)


func toast(text: String) -> void:
	if _toast == null:
		return
	_toast.text = text
	_toast_t = 3.0


# ------------------------------------------------------------------ acciones (toque y bot)

func can_act() -> bool:
	return not finished and is_inside_tree() and not get_tree().paused


func train(kind: String) -> bool:
	if not can_act():
		return false
	var src: String = "centro" if kind == "aldeano" else _trainer_of(kind)
	var best: Dictionary = {}
	for b: Dictionary in buildings:
		if b["alive"] and b["done"] and int(b["owner"]) == MINE and str(b["kind"]) == src and (b["queue"] as Array).size() < 5:
			if best.is_empty() or (b["queue"] as Array).size() < (best["queue"] as Array).size():
				best = b
	var cost: Dictionary = MapRules.units[kind]["cost"]
	if best.is_empty() or not MapRules.can_pay(stock[MINE], cost):
		return false
	MapRules.pay(stock[MINE], cost)
	(best["queue"] as Array).append(kind)
	_rebuild_actions()
	_update_hud()
	return true


## Mercado (Edad II): cambia comida o madera por oro, para cuando se acaban las minas.
func trade(give: String) -> bool:
	if not can_act() or age[MINE] < 2 or not (give in ["comida", "madera"]):
		return false
	if not MapRules.can_pay(stock[MINE], {give: MapRules.TRADE_GIVE}):
		return false
	MapRules.pay(stock[MINE], {give: MapRules.TRADE_GIVE})
	stock[MINE]["oro"] = float(stock[MINE]["oro"]) + float(MapRules.TRADE_GET)
	Audio.play("coin", 0.1, -4.0)
	_update_hud()
	return true


func age_up() -> bool:
	if not can_act() or aging > 0.0 or age[MINE] >= 3:
		return false
	var cost: Dictionary = MapRules.age_cost[age[MINE] + 1]
	if not MapRules.can_pay(stock[MINE], cost):
		return false
	MapRules.pay(stock[MINE], cost)
	aging = MapRules.AGE_TIME[age[MINE] + 1]
	_rebuild_actions()
	return true


## Manda un aldeano mas a 'job', sacandolo del trabajo que mas tenga (o de 'from_job').
func assign(job: String, from_job: String = "") -> bool:
	var counts: Dictionary = {"comida": workers("comida"), "madera": workers("madera"), "oro": workers("oro"), "": workers("")}
	var from: String = from_job if from_job != "" and int(counts.get(from_job, 0)) > 0 else ""
	if from == "" and int(counts[""]) == 0:
		var most: int = 0
		for r: String in MapRules.RES:
			if r != job and int(counts[r]) > most:
				most = int(counts[r])
				from = r
		if from == "":
			return false
	for u: Dictionary in units:
		if u["alive"] and int(u["owner"]) == MINE and str(u["kind"]) == "aldeano" and str(u["job"]) == from:
			u["job"] = job
			u["state"] = "go"
			_update_hud()
			return true
	return false


func start_place(kind: String) -> void:
	if not can_act():
		return
	placing = kind
	ghost = find_spot(kind)
	_rebuild_actions()


func cancel_place() -> void:
	placing = ""
	_rebuild_actions()


func confirm_place() -> void:
	if place(placing, ghost):
		placing = ""
		_rebuild_actions()
	else:
		toast(Kit.text("empire_no_room", "Ah\u00ed no se puede construir"))


func can_place(kind: String, c: Vector2i) -> bool:
	if not MapRules.builds.has(kind) or kind == "centro":
		return false
	var info: Dictionary = MapRules.builds[kind]
	var s: int = int(info["size"])
	if age[MINE] < int(info.get("age", 1)) or not MapRules.fits(w, h, _blocked, c, s):
		return false
	## Un hueco de una casilla con otros edificios (para que no se cierren los caminos), menos las
	## torres y muros, y dentro de tu territorio (cerca de algun edificio tuyo).
	var near: bool = false
	var mid: Vector2 = Vector2(c) + Vector2(s, s) * 0.5
	for dy: int in range(-1, s + 1):
		for dx: int in range(-1, s + 1):
			var n: Vector2i = c + Vector2i(dx, dy)
			if _occ.has(n) and s > 1:
				return false
	for b: Dictionary in buildings:
		if b["alive"] and int(b["owner"]) == MINE and center_of(b).distance_to(mid) <= 9.5:
			near = true
		if b["alive"] and int(b["owner"]) == RIVAL and center_of(b).distance_to(mid) <= 6.0:
			return false
	for u: Dictionary in units:
		if u["alive"] and Rect2(Vector2(c), Vector2(s, s)).has_point(u["pos"]):
			return false
	return near


func place(kind: String, c: Vector2i) -> bool:
	if not can_act() or not can_place(kind, c):
		return false
	var cost: Dictionary = MapRules.builds[kind].get("cost", {})
	if not MapRules.can_pay(stock[MINE], cost):
		return false
	MapRules.pay(stock[MINE], cost)
	_add_building(kind, MINE, c, false)
	_rebuild_blocked()
	Audio.play("click", 0.1, -4.0)
	_update_hud()
	return true


## Mejor sitio para un edificio: cerca del centro (las granjas, pegadas; el almacen, al lado del
## bosque; las torres, hacia el rival).
func find_spot(kind: String) -> Vector2i:
	var home: int = main_center(MINE)
	if home < 0 or not MapRules.builds.has(kind):
		return Vector2i(-1, -1)
	var s: int = int(MapRules.builds[kind]["size"])
	var hc: Vector2 = center_of(buildings[home])
	var target: Vector2 = hc
	if kind == "almacen":
		target = _store_target()
	elif kind == "torre":
		target = rally[MINE]
	var best: Vector2i = Vector2i(-1, -1)
	var best_score: float = INF
	for y: int in h:
		for x: int in w:
			var c: Vector2i = Vector2i(x, y)
			var mid: Vector2 = Vector2(c) + Vector2(s, s) * 0.5
			if mid.distance_to(target) > 12.0 or (kind != "almacen" and mid.distance_to(hc) > 9.5):
				continue
			var sc: float = mid.distance_to(target)
			if kind == "almacen":
				sc += mid.distance_to(hc) * 0.2
			if sc < best_score and can_place(kind, c):
				best_score = sc
				best = c
	return best


## Distancia del recurso mas cercano de ese tipo a donde se deja (centro o almacen); INF si no queda.
func trip(job: String) -> float:
	var t: int = {"comida": MapRules.BUSH, "madera": MapRules.TREE, "oro": MapRules.GOLD}[job]
	var drops: Array[Vector2] = []
	for b: Dictionary in buildings:
		if b["alive"] and int(b["owner"]) == MINE and bool(MapRules.builds[b["kind"]].get("drop", false)):
			drops.append(center_of(b))
	var best: float = INF
	for c: Variant in amount:
		var v: Vector2i = c
		if terrain[v.y * w + v.x] != t:
			continue
		var p: Vector2 = Vector2(v) + Vector2(0.5, 0.5)
		for d: Vector2 in drops:
			best = minf(best, p.distance_to(d))
	return best


## Lo que queda de un recurso en el mapa (la comida cuenta tambien las granjas).
func res_left(job: String) -> float:
	if job == "comida":
		return food_left()
	var t: int = MapRules.TREE if job == "madera" else MapRules.GOLD
	var n: float = 0.0
	var home: int = main_center(MINE)
	var hc: Vector2 = center_of(buildings[home]) if home >= 0 else Vector2.ZERO
	for c: Variant in amount:
		var v: Vector2i = c
		## Solo lo de tu lado del mapa (lo del rival esta lejos y protegido).
		if terrain[v.y * w + v.x] == t and (Vector2(v) + Vector2(0.5, 0.5)).distance_to(hc) <= 13.0:
			n += float(amount[c])
	return n


## Hace falta un almacen nuevo? (la madera o el oro que quedan pillan lejos)
func needs_store() -> bool:
	return (res_left("oro") > 0.0 and trip("oro") >= 6.0) or (res_left("madera") > 0.0 and trip("madera") >= 6.0)


## Donde poner el almacen: junto al oro o la madera que mas lejos pille de donde se deja.
func _store_target() -> Vector2:
	var home: int = main_center(MINE)
	var hc: Vector2 = center_of(buildings[home])
	var job: String = "oro" if res_left("oro") > 0.0 and trip("oro") >= trip("madera") else "madera"
	var t: int = MapRules.GOLD if job == "oro" else MapRules.TREE
	var drops: Array[Vector2] = []
	for b: Dictionary in buildings:
		if b["alive"] and int(b["owner"]) == MINE and bool(MapRules.builds[b["kind"]].get("drop", false)):
			drops.append(center_of(b))
	var best: Vector2 = hc
	var bd: float = INF
	for c: Variant in amount:
		var v: Vector2i = c
		if terrain[v.y * w + v.x] != t:
			continue
		var p: Vector2 = Vector2(v) + Vector2(0.5, 0.5)
		var d: float = p.distance_to(hc)
		var near_drop: float = INF
		for dp: Vector2 in drops:
			near_drop = minf(near_drop, p.distance_to(dp))
		if near_drop < 4.0:
			continue
		if d < bd:
			bd = d
			best = p
	return best


func _nearest_node(t: int, from: Vector2, min_d: float) -> Vector2:
	var best: Vector2 = from
	var bd: float = INF
	for c: Variant in amount:
		var v: Vector2i = c
		if terrain[v.y * w + v.x] != t:
			continue
		var d: float = (Vector2(v) + Vector2(0.5, 0.5)).distance_to(from)
		if d >= min_d and d < bd:
			bd = d
			best = Vector2(v) + Vector2(0.5, 0.5)
	return best


func attack() -> void:
	var n: int = 0
	for u: Dictionary in units:
		if u["alive"] and int(u["owner"]) == MINE and str(u["kind"]) != "aldeano":
			u["order"] = "attack"
			n += 1
	if n > 0:
		toast(Kit.text("empire_attacking", "\u00a1Al ataque!"))
		Audio.play("jump", 0.1)


func recall() -> void:
	for u: Dictionary in units:
		if u["alive"] and int(u["owner"]) == MINE and str(u["kind"]) != "aldeano":
			u["order"] = "move"
			u["goal"] = rally[MINE]


## Toque en el mapa sin construir: el ejercito va a ese punto (y pelea por el camino).
func move_army(p: Vector2) -> bool:
	var n: int = 0
	var goal: Vector2 = _free_near(p)
	for u: Dictionary in units:
		if u["alive"] and int(u["owner"]) == MINE and str(u["kind"]) != "aldeano":
			u["order"] = "move"
			u["goal"] = goal
			n += 1
	if n > 0:
		_fx.append({"type": "flag", "at": goal, "t": 1.2})
	return n > 0


func toggle_speed() -> void:
	speed = 2.0 if speed < 1.5 else 1.0
	_update_hud()


# ------------------------------------------------------------------ consultas

func center_of(b: Dictionary) -> Vector2:
	return Vector2(b["cell"]) + Vector2(b["size"], b["size"]) * 0.5


func main_center(owner: int) -> int:
	for i: int in buildings.size():
		var b: Dictionary = buildings[i]
		if b["alive"] and int(b["owner"]) == owner and str(b["kind"]) == "centro":
			return i
	return -1


func has_building(kind: String, owner: int, done_only: bool = true) -> bool:
	for b: Dictionary in buildings:
		if b["alive"] and int(b["owner"]) == owner and str(b["kind"]) == kind and (b["done"] or not done_only):
			return true
	return false


func count_buildings(kind: String, owner: int) -> int:
	var n: int = 0
	for b: Dictionary in buildings:
		if b["alive"] and int(b["owner"]) == owner and str(b["kind"]) == kind:
			n += 1
	return n


func building_pending(kind: String) -> bool:
	for b: Dictionary in buildings:
		if b["alive"] and int(b["owner"]) == MINE and str(b["kind"]) == kind and not b["done"]:
			return true
	return false


func queued(kind: String) -> int:
	var n: int = 0
	for b: Dictionary in buildings:
		if b["alive"] and int(b["owner"]) == MINE:
			n += (b["queue"] as Array).count(kind)
	return n


func count_units(kind: String, owner: int) -> int:
	var n: int = 0
	for u: Dictionary in units:
		if u["alive"] and int(u["owner"]) == owner and str(u["kind"]) == kind:
			n += 1
	return n


func army_count(owner: int) -> int:
	var n: int = 0
	for u: Dictionary in units:
		if u["alive"] and int(u["owner"]) == owner and str(u["kind"]) != "aldeano":
			n += 1
	return n


func attacking(owner: int) -> int:
	var n: int = 0
	for u: Dictionary in units:
		if u["alive"] and int(u["owner"]) == owner and str(u["order"]) == "attack":
			n += 1
	return n


func workers(job: String) -> int:
	var n: int = 0
	for u: Dictionary in units:
		if u["alive"] and int(u["owner"]) == MINE and str(u["kind"]) == "aldeano" and str(u["job"]) == job:
			n += 1
	return n


func pop(owner: int) -> int:
	var n: int = 0
	for u: Dictionary in units:
		if u["alive"] and int(u["owner"]) == owner:
			n += 1
	return n


func pop_cap(owner: int) -> int:
	var n: int = 0
	for b: Dictionary in buildings:
		if b["alive"] and b["done"] and int(b["owner"]) == owner:
			n += int(MapRules.builds[b["kind"]].get("pop", 0))
	return mini(n, MapRules.MAX_POP)


## Comida que queda al alcance (bayas y granjas tuyas).
func food_left() -> float:
	var n: float = 0.0
	for c: Variant in amount:
		var v: Vector2i = c
		if terrain[v.y * w + v.x] == MapRules.BUSH:
			n += float(amount[c])
	for b: Dictionary in buildings:
		if b["alive"] and int(b["owner"]) == MINE and str(b["kind"]) == "granja":
			n += float(b["food"])
	return n


func _trainer_of(kind: String) -> String:
	for k: Variant in MapRules.builds:
		if (MapRules.builds[k].get("trains", []) as Array).has(kind):
			return str(k)
	return ""


# ------------------------------------------------------------------ simulacion

func _physics_process(delta: float) -> void:
	if finished:
		return
	var steps: int = STEPS_FAST if fast else 1
	## Con el bot jugando despacio (fotos y clip de la tienda) va a x4 para que se vea la batalla.
	var dt: float = TICK_FAST if fast else delta * speed * (4.0 if auto_retry else 1.0)
	for s: int in steps:
		_tick(dt)
		if finished:
			break
	_hud_t -= delta
	if _hud_t <= 0.0:
		_hud_t = 0.25
		_update_hud()
		if placing == "":
			_refresh_enabled()
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0:
			_toast.text = ""
	_world.queue_redraw()
	if fog:
		_fog_layer.queue_redraw()
	if _ground_dirty:
		_ground.queue_redraw()


## Activa o apaga los botones segun lo que puedes pagar (sin rehacerlos).
func _refresh_enabled() -> void:
	var need: Dictionary = {}
	var st: Dictionary = stock[MINE]
	match _tab:
		"aldea":
			need["aldeano"] = MapRules.can_pay(st, MapRules.units["aldeano"]["cost"])
			need["sell_comida"] = MapRules.can_pay(st, {"comida": MapRules.TRADE_GIVE})
			need["sell_madera"] = MapRules.can_pay(st, {"madera": MapRules.TRADE_GIVE})
			if age[MINE] < 3:
				need["age"] = aging <= 0.0 and MapRules.can_pay(st, MapRules.age_cost[age[MINE] + 1])
		"construir":
			for k: String in MapRules.PLAYER_BUILD:
				need[k] = age[MINE] >= int(MapRules.builds[k].get("age", 1)) and MapRules.can_pay(st, MapRules.builds[k].get("cost", {}))
		"ejercito":
			for k: String in MapRules.ARMY:
				need[k] = has_building(_trainer_of(k), MINE) and MapRules.can_pay(st, MapRules.units[k]["cost"])
			need["attack"] = army_count(MINE) > 0
			need["recall"] = army_count(MINE) > 0
	var stale: bool = false
	for b: Node in _actions.get_children():
		var id: String = str(b.name).trim_prefix("Act_")
		if need.has(id):
			(b as Button).disabled = not bool(need[id])
		if id == "attack":
			var l: Label = (b.get_child(0) as Node).get_child(1) as Label
			l.text = "%d" % army_count(MINE)
		if id == "age" and aging <= 0.0 and age[MINE] < 3 and ((b.get_child(0) as Node).get_child(1) as Label).text == Kit.text("empire_aging", "Avanzando..."):
			stale = true
		if (id in MapRules.ARMY) and ((b.get_child(0) as Node).get_child(1) as Label).text.begins_with(Kit.text("empire_needs", "Necesita {b}").get_slice("{", 0)) and has_building(_trainer_of(id), MINE):
			stale = true
	if stale:
		_rebuild_actions()


func _tick(dt: float) -> void:
	time_in_level += dt
	if _dirty:
		_rebuild_blocked()
	_step_age(dt)
	if fog:
		_fog_t -= dt
		if _fog_t <= 0.0:
			_fog_t = 0.25
			_update_fog()
	_step_buildings(dt)
	_step_ai(dt)
	for u: Dictionary in units:
		if not u["alive"]:
			continue
		if str(u["kind"]) == "aldeano" and int(u["owner"]) == MINE:
			_step_villager(u, dt)
		else:
			_step_military(u, dt)
	_separate()
	for f: Dictionary in _fx:
		f["t"] = float(f["t"]) - dt
	var keep_fx: Array[Dictionary] = []
	for f: Dictionary in _fx:
		if float(f["t"]) > 0.0:
			keep_fx.append(f)
	_fx = keep_fx
	_clean_t -= dt
	if _clean_t <= 0.0:
		_clean_t = 2.0
		var keep_u: Array[Dictionary] = []
		for u: Dictionary in units:
			if u["alive"]:
				keep_u.append(u)
		units = keep_u
		for o: int in 2:
			if not _alarm[o].is_empty() and time_in_level - float(_alarm[o]["t"]) > 8.0:
				_alarm[o] = {}
	if seconds > 0.0 and time_in_level >= seconds and not finished:
		_lose(Kit.text("empire_time_up", "Se acab\u00f3 el tiempo"))


## Lo que se ve ahora (4 casillas alrededor de cada tropa, 5 mas el tamano de cada edificio).
func _update_fog() -> void:
	if not fog:
		return
	seen.fill(0)
	var eyes: Array = []
	for u: Dictionary in units:
		if u["alive"] and int(u["owner"]) == MINE and not bool(u.get("hidden", false)):
			eyes.append([u["pos"], 4.0])
	for b: Dictionary in buildings:
		if b["alive"] and int(b["owner"]) == MINE:
			eyes.append([center_of(b), 4.5 + float(b["size"]) * 0.5])
	for e: Array in eyes:
		var p: Vector2 = e[0]
		var r: float = e[1]
		for y: int in range(maxi(0, int(p.y - r)), mini(h, int(p.y + r) + 1)):
			for x: int in range(maxi(0, int(p.x - r)), mini(w, int(p.x + r) + 1)):
				if (Vector2(x, y) + Vector2(0.5, 0.5)).distance_to(p) <= r:
					seen[y * w + x] = 1
					explored[y * w + x] = 1


func visible_at(p: Vector2) -> bool:
	if not fog:
		return true
	var c: Vector2i = _cell(p)
	return seen[c.y * w + c.x] == 1


func explored_at(p: Vector2) -> bool:
	if not fog:
		return true
	var c: Vector2i = _cell(p)
	return explored[c.y * w + c.x] == 1


func _draw_fog() -> void:
	if not fog:
		return
	for y: int in h:
		for x: int in w:
			var i: int = y * w + x
			if seen[i] == 1:
				continue
			var a: float = 0.45 if explored[i] == 1 else 0.93
			_fog_layer.draw_rect(Rect2(Vector2(x, y) * CELL, Vector2(CELL, CELL)), Color(0.04, 0.05, 0.08, a))


func _step_age(dt: float) -> void:
	if aging > 0.0:
		aging -= dt
		if aging <= 0.0:
			aging = 0.0
			age[MINE] += 1
			toast(Kit.text("empire_new_age", "\u00a1Entras en la Edad {n}!").format({"n": _roman(age[MINE])}))
			Audio.play("powerup")
			QA.log_event("empire_age", {"age": age[MINE], "time": snappedf(time_in_level, 0.1)})
			_rebuild_actions()


func _step_buildings(dt: float) -> void:
	for b: Dictionary in buildings:
		if not b["alive"]:
			continue
		var info: Dictionary = MapRules.builds[b["kind"]]
		if not b["done"]:
			var t: float = float(info.get("time", 10.0))
			b["prog"] = float(b["prog"]) + dt / t
			b["hp"] = minf(float(b["max"]), float(b["hp"]) + float(b["max"]) * 0.9 * dt / t)
			if float(b["prog"]) >= 1.0:
				b["done"] = true
				b["prog"] = 1.0
				_dirty = true
				if int(b["owner"]) == MINE:
					_rebuild_actions()
			continue
		var q: Array = b["queue"]
		if not q.is_empty():
			var kind: String = str(q[0])
			if int(b["owner"]) == MINE and pop(MINE) >= pop_cap(MINE):
				continue
			b["qt"] = float(b["qt"]) + dt
			if float(b["qt"]) >= float(MapRules.units[kind]["time"]):
				b["qt"] = 0.0
				q.pop_front()
				var u: Dictionary = _spawn(kind, int(b["owner"]), buildings.find(b))
				if not u.is_empty() and kind == "aldeano":
					u["job"] = _auto_job()
		if info.has("shoot"):
			b["cd"] = float(b["cd"]) - dt
			if float(b["cd"]) <= 0.0:
				var sh: Dictionary = info["shoot"]
				var c: Vector2 = center_of(b)
				var tgt: Dictionary = _nearest_foe_at(c, 1 - int(b["owner"]), float(sh["range"]) + float(b["size"]) * 0.5, false)
				if not tgt.is_empty():
					## Cada aldeano escondido dentro anade flechas (hasta el triple).
					b["cd"] = float(sh["rate"]) / minf(3.0, 1.0 + 0.25 * float(_garrison(b)))
					var dmg: float = MapRules.arrow_hit(float(sh["dmg"]) * MapRules.age_mult(age[int(b["owner"])]), str(tgt["kind"]))
					_hurt_unit(tgt, dmg, c)
					_fx.append({"type": "arrow", "from": c, "to": tgt["pos"], "t": 0.25})


func _garrison(b: Dictionary) -> int:
	if int(b["owner"]) != MINE:
		return 0
	var n: int = 0
	var r: Rect2 = Rect2(Vector2(b["cell"]), Vector2(b["size"], b["size"])).grow(1.5)
	for u: Dictionary in units:
		if u["alive"] and bool(u.get("hidden", false)) and r.has_point(u["pos"]):
			n += 1
	return n


func hidden_count() -> int:
	var n: int = 0
	for u: Dictionary in units:
		if u["alive"] and bool(u.get("hidden", false)):
			n += 1
	return n


## Campana: todos los aldeanos a esconderse (o, si ya suena, de vuelta al trabajo).
func ring_bell() -> void:
	bell = not bell
	for u: Dictionary in units:
		if u["alive"] and int(u["owner"]) == MINE and str(u["kind"]) == "aldeano":
			if bell:
				u["state"] = "hide"
			elif bool(u.get("hidden", false)) or str(u["state"]) == "hide":
				u["hidden"] = false
				u["state"] = "go"
	toast(Kit.text("empire_bell_on", "\u00a1Campana! Los aldeanos se esconden") if bell else Kit.text("empire_bell_off", "De vuelta al trabajo"))
	_rebuild_actions()


## Trabajo para un aldeano nuevo: el que tenga menos gente segun el reparto de la edad.
func _auto_job() -> String:
	var mix: Dictionary = {"comida": 0.5, "madera": 0.35, "oro": 0.15} if age[MINE] == 1 else {"comida": 0.4, "madera": 0.3, "oro": 0.3}
	var best: String = "comida"
	var bv: float = INF
	for r: String in MapRules.RES:
		if r != "comida" and res_left(r) <= 0.0:
			continue
		var v: float = float(workers(r) + 1) / float(mix[r])
		if v < bv:
			bv = v
			best = r
	return best


func _spawn(kind: String, owner: int, bi: int) -> Dictionary:
	if bi < 0:
		return {}
	var b: Dictionary = buildings[bi]
	var c: Vector2i = b["cell"]
	var s: int = int(b["size"])
	var toward: Vector2 = rally[owner]
	var best: Vector2i = Vector2i(-1, -1)
	var bd: float = INF
	for dy: int in range(-1, s + 1):
		for dx: int in range(-1, s + 1):
			var n: Vector2i = c + Vector2i(dx, dy)
			if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h or _blocked[n.y * w + n.x] != 0:
				continue
			var d: float = (Vector2(n) + Vector2(0.5, 0.5)).distance_to(toward)
			if d < bd:
				bd = d
				best = n
	if best.x < 0:
		best = Vector2i(_free_near(center_of(b)))
	var info: Dictionary = MapRules.units[kind]
	var mx: float = float(info["hp"]) * MapRules.age_mult(age[owner])
	var jit: float = float(_next_id % 7) * 0.05 - 0.15
	var u: Dictionary = {"id": _next_id, "kind": kind, "owner": owner, "pos": Vector2(best) + Vector2(0.5 + jit, 0.5 - jit),
		"hp": mx, "max": mx, "cd": 0.0, "rt": 0.0, "tgt": {}, "order": "idle", "goal": rally[owner], "job": "", "carry": 0.0,
		"ctype": "", "state": "go", "src": Vector2i(-1, -1), "alive": true, "face": 1.0}
	_next_id += 1
	units.append(u)
	return u


func _free_near(p: Vector2) -> Vector2:
	var c: Vector2i = Vector2i(clampi(int(p.x), 0, w - 1), clampi(int(p.y), 0, h - 1))
	if _blocked.size() == w * h and _blocked[c.y * w + c.x] == 0:
		return Vector2(c) + Vector2(0.5, 0.5)
	for r: int in range(1, 8):
		for dy: int in range(-r, r + 1):
			for dx: int in range(-r, r + 1):
				var n: Vector2i = c + Vector2i(dx, dy)
				if n.x >= 0 and n.y >= 0 and n.x < w and n.y < h and _blocked[n.y * w + n.x] == 0:
					return Vector2(n) + Vector2(0.5, 0.5)
	return Vector2(c) + Vector2(0.5, 0.5)


## Mapa de distancias con nombre (se rehace cuando cambia el mapa).
func _field(key: String) -> PackedInt32Array:
	if _fields.has(key):
		return _fields[key]
	if _fields.size() > 48:
		_fields.clear()
	var goals: Array[Vector2i] = []
	var parts: PackedStringArray = key.split(":")
	match parts[0]:
		"res":
			var t: int = {"comida": MapRules.BUSH, "madera": MapRules.TREE, "oro": MapRules.GOLD}[parts[1]]
			for c: Variant in amount:
				var v: Vector2i = c
				if terrain[v.y * w + v.x] == t:
					goals.append(v)
			if parts[1] == "comida":
				for b: Dictionary in buildings:
					if b["alive"] and b["done"] and int(b["owner"]) == int(parts[2]) and str(b["kind"]) == "granja":
						goals.append_array(_cells_of(b))
		"home":
			for b: Dictionary in buildings:
				if b["alive"] and int(b["owner"]) == int(parts[1]) and str(b["kind"]) == "centro":
					goals.append_array(_cells_of(b))
		"drop":
			for b: Dictionary in buildings:
				if b["alive"] and b["done"] and int(b["owner"]) == int(parts[1]) and bool(MapRules.builds[b["kind"]].get("drop", false)):
					goals.append_array(_cells_of(b))
		"bld":
			for b: Dictionary in buildings:
				if b["alive"] and int(b["owner"]) == int(parts[1]) and str(b["kind"]) != "muro":
					goals.append_array(_cells_of(b))
		"pt":
			goals.append(Vector2i(int(parts[1]), int(parts[2])))
	var f: PackedInt32Array = MapRules.field(w, h, _blocked, goals)
	_fields[key] = f
	return f


func _cells_of(b: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var s: int = int(b["size"])
	for dy: int in s:
		for dx: int in s:
			out.append(Vector2i(b["cell"]) + Vector2i(dx, dy))
	return out


func _cell(p: Vector2) -> Vector2i:
	return Vector2i(clampi(int(floor(p.x)), 0, w - 1), clampi(int(floor(p.y)), 0, h - 1))


## Un paso siguiendo el mapa de distancias. Devuelve 1 si ya ha llegado, 0 si avanza y -1 si no
## hay camino.
func _follow(u: Dictionary, key: String, dt: float) -> int:
	var f: PackedInt32Array = _field(key)
	var p: Vector2 = u["pos"]
	var c: Vector2i = _cell(p)
	var v: int = f[c.y * w + c.x]
	if _blocked[c.y * w + c.x] != 0:
		u["pos"] = _free_near(p)
		return 0
	if v == 0:
		return 1
	if v < 0:
		return -1
	var best: Vector2i = c
	var bv: int = v
	for dir: Vector2i in MapRules.DIR8:
		var n: Vector2i = c + dir
		if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h:
			continue
		var nv: int = f[n.y * w + n.x]
		if nv < 0 or nv >= bv:
			continue
		if dir.x != 0 and dir.y != 0 and (_blocked[c.y * w + n.x] != 0 or _blocked[n.y * w + c.x] != 0):
			continue
		bv = nv
		best = n
	_walk(u, Vector2(best) + Vector2(0.5, 0.5), dt)
	return 0


func _speed_of(u: Dictionary) -> float:
	return float(MapRules.units[u["kind"]]["speed"])


## Anda en linea recta hacia 'to' y resbala por las paredes.
func _walk(u: Dictionary, to: Vector2, dt: float) -> void:
	var p: Vector2 = u["pos"]
	var d: Vector2 = to - p
	var step: float = _speed_of(u) * dt
	if d.length() <= step:
		u["pos"] = _slide(p, d)
		return
	var mv: Vector2 = d.normalized() * step
	if absf(mv.x) > 0.01:
		u["face"] = signf(mv.x)
	u["pos"] = _slide(p, mv)


func _slide(p: Vector2, d: Vector2) -> Vector2:
	var n: Vector2 = p + d
	if _free(n):
		return n
	if _free(Vector2(n.x, p.y)):
		return Vector2(n.x, p.y)
	if _free(Vector2(p.x, n.y)):
		return Vector2(p.x, n.y)
	return p


func _free(p: Vector2) -> bool:
	if p.x < 0.0 or p.y < 0.0 or p.x >= float(w) or p.y >= float(h):
		return false
	return _blocked[int(p.y) * w + int(p.x)] == 0


func _step_villager(u: Dictionary, dt: float) -> void:
	var job: String = str(u["job"])
	if bool(u.get("hidden", false)):
		## Escondido en un edificio: sale cuando no queda ningun enemigo cerca (y no suena la campana).
		u["rt"] = float(u["rt"]) - dt
		u["hid_t"] = float(u.get("hid_t", 0.0)) + dt
		if float(u["rt"]) <= 0.0:
			u["rt"] = 1.0
			## Sale si no hay enemigos cerca, o despues de 30 s aunque los haya (la economia no
			## puede pararse para siempre); con la campana sonando se queda dentro.
			if not bell and (_nearest_foe_at(u["pos"], RIVAL, 8.0, false).is_empty() or float(u["hid_t"]) > 30.0):
				u["hidden"] = false
				u["state"] = "go"
		return
	match str(u["state"]):
		"hide":
			var r0: int = _follow(u, "home:%d" % MINE, dt)
			if r0 != 0:
				u["hidden"] = true
				u["rt"] = 2.0
				u["hid_t"] = 0.0
				if r0 == 1 and float(u["carry"]) > 0.0:
					stock[MINE][str(u["ctype"])] = float(stock[MINE].get(str(u["ctype"]), 0.0)) + float(u["carry"])
					u["carry"] = 0.0
			return
		"go":
			if job == "":
				if (u["pos"] as Vector2).distance_to(rally[MINE]) > 2.5:
					_follow(u, "pt:%d:%d" % [int(rally[MINE].x), int(rally[MINE].y)], dt)
				return
			if float(u["carry"]) >= MapRules.CARRY or (float(u["carry"]) > 0.0 and str(u["ctype"]) != job):
				u["state"] = "back"
				return
			var r: int = _follow(u, "res:%s:%d" % [job, MINE], dt)
			if r == 1:
				var src: Vector2i = _adjacent_source(u["pos"], job)
				if src.x >= 0:
					u["src"] = src
					u["state"] = "work"
					u["ctype"] = job
			elif r < 0:
				## No queda de ese recurso: si lleva algo lo deja; si no, espera en casa.
				if float(u["carry"]) > 0.0:
					u["state"] = "back"
				elif (u["pos"] as Vector2).distance_to(rally[MINE]) > 2.5:
					_follow(u, "pt:%d:%d" % [int(rally[MINE].x), int(rally[MINE].y)], dt)
		"work":
			var src2: Vector2i = u["src"]
			if job != str(u["ctype"]):
				u["state"] = "go"
				return
			var b: Variant = _occ.get(src2)
			var rate: float = 0.0
			if b != null:
				var bd: Dictionary = b
				if not bd["alive"] or str(bd["kind"]) != "granja" or not bd["done"] or float(bd["food"]) <= 0.0:
					u["state"] = "go"
					return
				rate = MapRules.FARM_RATE * dt
				bd["food"] = float(bd["food"]) - rate
				if float(bd["food"]) <= 0.0:
					_remove_building(bd, false)
			else:
				if not amount.has(src2):
					u["state"] = "go"
					return
				rate = float(MapRules.GATHER[job]) * dt
				amount[src2] = float(amount[src2]) - rate
				if float(amount[src2]) <= 0.0:
					amount.erase(src2)
					terrain[src2.y * w + src2.x] = MapRules.GRASS
					_dirty = true
					_ground_dirty = true
			u["carry"] = float(u["carry"]) + rate
			u["face"] = signf(float(src2.x) + 0.5 - (u["pos"] as Vector2).x) if absf(float(src2.x) + 0.5 - (u["pos"] as Vector2).x) > 0.1 else float(u["face"])
			if float(u["carry"]) >= MapRules.CARRY:
				u["state"] = "back"
		"back":
			var r2: int = _follow(u, "drop:%d" % MINE, dt)
			if r2 == 1 or r2 < 0:
				if r2 == 1:
					var k: String = str(u["ctype"])
					stock[MINE][k] = float(stock[MINE].get(k, 0.0)) + float(u["carry"])
				u["carry"] = 0.0
				u["state"] = "go"


func _adjacent_source(p: Vector2, job: String) -> Vector2i:
	var c: Vector2i = _cell(p)
	var t: int = {"comida": MapRules.BUSH, "madera": MapRules.TREE, "oro": MapRules.GOLD}[job]
	for dir: Vector2i in MapRules.DIR8:
		var n: Vector2i = c + dir
		if amount.has(n) and terrain[n.y * w + n.x] == t:
			return n
		if job == "comida" and _occ.has(n):
			var b: Dictionary = _occ[n]
			if b["alive"] and b["done"] and str(b["kind"]) == "granja" and int(b["owner"]) == MINE:
				return n
	return Vector2i(-1, -1)


func _aggro(u: Dictionary) -> float:
	match str(u["order"]):
		"attack":
			return 4.5
		"move":
			return 3.0
	return 7.0 if int(u["owner"]) == RIVAL else 5.5


func _step_military(u: Dictionary, dt: float) -> void:
	var kind: String = str(u["kind"])
	var info: Dictionary = MapRules.units[kind]
	var rng: float = float(info["range"])
	var owner: int = int(u["owner"])
	u["cd"] = float(u["cd"]) - dt
	u["rt"] = float(u["rt"]) - dt
	var only_bld: bool = bool(info.get("only_bld", false))
	## Alarma: si atacan un edificio tuyo, las tropas paradas cerca acuden.
	if str(u["order"]) == "idle" and not _alarm[owner].is_empty() and kind != "aldeano":
		var at: Vector2 = _alarm[owner]["at"]
		if at.distance_to(u["pos"]) < 14.0:
			u["order"] = "move"
			u["goal"] = _free_near(at)
	if not only_bld and float(u["rt"]) <= 0.0:
		u["rt"] = 0.4
		u["tgt"] = _nearest_foe_at(u["pos"], 1 - owner, _aggro(u), kind == "aldeano")
	var tgt: Dictionary = u["tgt"]
	if not tgt.is_empty() and tgt["alive"] and not bool(tgt.get("hidden", false)):
		var d: float = (tgt["pos"] as Vector2).distance_to(u["pos"])
		if d <= rng + 0.35:
			if float(u["cd"]) <= 0.0:
				u["cd"] = float(info["rate"])
				_hurt_unit(tgt, MapRules.hit(kind, str(tgt["kind"]), age[owner]), u["pos"])
				if bool(info.get("arrow", false)):
					_fx.append({"type": "arrow", "from": u["pos"], "to": tgt["pos"], "t": 0.2})
				else:
					_fx.append({"type": "hit", "at": tgt["pos"], "t": 0.15})
		else:
			_walk(u, tgt["pos"], dt)
		return
	if kind == "aldeano":
		return
	if str(u["order"]) == "attack":
		var bi: Dictionary = _building_in_range(u["pos"], 1 - owner, rng + 0.55)
		if not bi.is_empty():
			if float(u["cd"]) <= 0.0:
				u["cd"] = float(info["rate"])
				_hurt_building(bi, MapRules.hit(kind, "", age[owner]), u["pos"], owner)
				if bool(info.get("arrow", false)):
					_fx.append({"type": "arrow", "from": u["pos"], "to": center_of(bi), "t": 0.2})
			return
		if _follow(u, "bld:%d" % (1 - owner), dt) < 0:
			u["order"] = "idle"
		return
	var goal: Vector2 = u["goal"]
	var key: String = "pt:%d:%d" % [int(goal.x), int(goal.y)]
	if str(u["order"]) == "move":
		if _follow(u, key, dt) != 0:
			u["order"] = "idle"
		return
	if (u["pos"] as Vector2).distance_to(goal) > 2.2:
		_follow(u, key, dt)


func _nearest_foe_at(p: Vector2, foe: int, radius: float, _unused: bool) -> Dictionary:
	var best: Dictionary = {}
	var bd: float = radius
	for o: Dictionary in units:
		if not o["alive"] or int(o["owner"]) != foe or bool(o.get("hidden", false)):
			continue
		var d: float = (o["pos"] as Vector2).distance_to(p)
		if d < bd:
			bd = d
			best = o
	return best


func _building_in_range(p: Vector2, foe: int, rng: float) -> Dictionary:
	var best: Dictionary = {}
	var bd: float = rng
	for b: Dictionary in buildings:
		if not b["alive"] or int(b["owner"]) != foe:
			continue
		var r: Rect2 = Rect2(Vector2(b["cell"]), Vector2(b["size"], b["size"]))
		var q: Vector2 = Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
		var d: float = q.distance_to(p)
		## Los muros solo si estorban (muy cerca); asi las tropas van a por lo importante.
		if str(b["kind"]) == "muro":
			d += 0.3
		if d <= bd:
			bd = d
			best = b
	return best


func _hurt_unit(u: Dictionary, dmg: float, from: Vector2) -> void:
	if not u["alive"] or dmg <= 0.0:
		return
	u["hp"] = float(u["hp"]) - dmg
	var owner: int = int(u["owner"])
	if str(u["kind"]) == "aldeano":
		if _alarm[owner].is_empty():
			_alarm[owner] = {"at": from, "t": time_in_level}
		## Un aldeano atacado corre a esconderse (y avisa a los de alrededor).
		if owner == MINE and str(u["state"]) != "hide":
			for o: Dictionary in units:
				if o["alive"] and int(o["owner"]) == MINE and str(o["kind"]) == "aldeano" and (o["pos"] as Vector2).distance_to(u["pos"]) < 5.0:
					o["state"] = "hide"
	if float(u["hp"]) <= 0.0:
		u["alive"] = false
		if owner == MINE and not fast:
			Audio.play("hurt", 0.1, -10.0)


func _hurt_building(b: Dictionary, dmg: float, from: Vector2, attacker: int) -> void:
	if not b["alive"]:
		return
	b["hp"] = float(b["hp"]) - dmg
	var owner: int = int(b["owner"])
	if _alarm[owner].is_empty() or time_in_level - float(_alarm[owner]["t"]) > 3.0:
		_alarm[owner] = {"at": from, "t": time_in_level}
		if owner == MINE and not fast:
			toast(Kit.text("empire_under_attack", "\u00a1Atacan tu aldea!"))
			Juice.vibrate(30)
	if float(b["hp"]) <= 0.0:
		_remove_building(b, true)
		if attacker == MINE and not fast:
			Juice.shake(0.2)


func _remove_building(b: Dictionary, destroyed: bool) -> void:
	b["alive"] = false
	for c: Vector2i in _cells_of(b):
		if is_same(_occ.get(c), b):
			_occ.erase(c)
	_dirty = true
	if not destroyed:
		return
	var owner: int = int(b["owner"])
	_fx.append({"type": "boom", "at": center_of(b), "t": 0.6, "size": float(b["size"])})
	if not fast:
		Audio.play("explosion" if str(b["kind"]) == "centro" else "hurt", 0.1)
	if owner == RIVAL:
		coins += 1
		if str(b["kind"]) == "centro":
			QA.log_event("empire_center_down", {"time": snappedf(time_in_level, 0.1)})
			if main_center(RIVAL) < 0:
				_win.call_deferred()
				finished = true
	else:
		lost_buildings += 1
		if str(b["kind"]) == "centro" and main_center(MINE) < 0:
			_lose(Kit.text("empire_center_lost", "Ha ca\u00eddo tu centro urbano"))


## Empuja un poco a las tropas que se pisan.
func _separate() -> void:
	var grid: Dictionary = {}
	for u: Dictionary in units:
		if u["alive"] and not bool(u.get("hidden", false)):
			var c: Vector2i = _cell(u["pos"])
			if not grid.has(c):
				grid[c] = []
			(grid[c] as Array).append(u)
	for c: Variant in grid:
		var list: Array = grid[c]
		if list.size() < 2:
			continue
		for i: int in list.size():
			for j: int in range(i + 1, list.size()):
				var a: Dictionary = list[i]
				var b: Dictionary = list[j]
				var d: Vector2 = (a["pos"] as Vector2) - (b["pos"] as Vector2)
				var l: float = d.length()
				if l >= 0.42:
					continue
				var push: Vector2 = (d / l if l > 0.001 else Vector2(0.7, 0.7) if (int(a["id"]) % 2) == 0 else Vector2(-0.7, 0.7)) * (0.42 - l) * 0.5
				a["pos"] = _slide(a["pos"], push)
				b["pos"] = _slide(b["pos"], -push)


# ------------------------------------------------------------------ el rival

func _step_ai(dt: float) -> void:
	var inc: float = float(ai["income"])
	for k: String in MapRules.RES:
		stock[RIVAL][k] = float(stock[RIVAL][k]) + float(MapRules.AI_RATE[k]) * inc * dt
	if age[RIVAL] < 2 and time_in_level >= float(ai["age2_at"]):
		age[RIVAL] = 2
	if age[RIVAL] < 3 and time_in_level >= float(ai["age3_at"]):
		age[RIVAL] = 3
	_ai_t -= dt
	if _ai_t <= 0.0:
		_ai_t = 1.0
		var army: int = army_count(RIVAL)
		for b: Dictionary in buildings:
			if not b["alive"] or not b["done"] or int(b["owner"]) != RIVAL:
				continue
			var trains: Array = MapRules.builds[b["kind"]].get("trains", [])
			if trains.is_empty() or str(trains[0]) == "aldeano" or not (b["queue"] as Array).is_empty():
				continue
			var kind: String = str(trains[0])
			var need_age: int = 3 if kind == "ariete" else (2 if kind in ["arquero", "jinete"] else 1)
			## El ejercito rival crece con el tiempo (no tiene 20 tropas en el minuto 3).
			var cap_now: int = mini(int(ai["max_army"]), 3 + int(time_in_level / 22.0))
			if age[RIVAL] < need_age or army >= cap_now:
				continue
			var cost: Dictionary = MapRules.units[kind]["cost"]
			if MapRules.can_pay(stock[RIVAL], cost):
				MapRules.pay(stock[RIVAL], cost)
				(b["queue"] as Array).append(kind)
				army += 1
	if time_in_level >= next_wave:
		var want: int = int(ai["wave_size"]) + int(ai["wave_grow"]) * waves_sent
		var sent: int = 0
		for u: Dictionary in units:
			if sent >= want:
				break
			if u["alive"] and int(u["owner"]) == RIVAL and str(u["order"]) == "idle":
				u["order"] = "attack"
				sent += 1
		if sent >= 2 or army_count(RIVAL) >= want:
			waves_sent += 1
			next_wave = time_in_level + float(ai["wave_every"])
			if not fast:
				toast(Kit.text("empire_wave_fog", "\u00a1El rival se acerca!") if fog else Kit.text("empire_wave", "\u00a1El rival ataca con {n} tropas!").format({"n": sent}))
				Audio.play("hurt", 0.1)
			QA.log_event("empire_wave", {"n": sent, "time": snappedf(time_in_level, 0.1)})
		else:
			## Aun no tiene bastante: lo intenta un poco mas tarde.
			for u: Dictionary in units:
				if u["alive"] and int(u["owner"]) == RIVAL and str(u["order"]) == "attack" and sent > 0:
					u["order"] = "idle"
					sent -= 1
			next_wave = time_in_level + 15.0


# ------------------------------------------------------------------ entrada

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()
		return
	## El raton tambien llega como toque (emulate_touch_from_mouse), asi que basta con los toques.
	if event is InputEventScreenDrag:
		var dr: InputEventScreenDrag = event
		if _pressing and (_dragging or dr.position.distance_to(_press_pos) > 14.0):
			_dragging = true
			_camera.position -= dr.relative / _camera.zoom
			_clamp_camera()
		return
	if not (event is InputEventScreenTouch):
		return
	var t: InputEventScreenTouch = event
	if t.pressed:
		_pressing = true
		_dragging = false
		_press_pos = t.position
		return
	var was_drag: bool = _dragging
	_pressing = false
	_dragging = false
	if was_drag or not can_act():
		return
	tap_world((get_canvas_transform().affine_inverse() * t.position) / CELL)


## Toque en el mapa (en casillas): mueve la sombra del edificio o el ejercito.
func tap_world(p: Vector2) -> void:
	if placing != "":
		var s: int = int(MapRules.builds[placing]["size"])
		ghost = Vector2i(int(floor(p.x - float(s) * 0.5 + 0.5)), int(floor(p.y - float(s) * 0.5 + 0.5)))
		_rebuild_actions()
		return
	if p.x < 0.0 or p.y < 0.0 or p.x >= float(w) or p.y >= float(h):
		return
	move_army(p)


# ------------------------------------------------------------------ final

func _win() -> void:
	if result_panel != null:
		return
	finished = true
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = maxi(0, 20000 - int(time_in_level) * 15) + coins * 200 + army_count(MINE) * 20
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "time": snappedf(time_in_level, 0.1), "deaths": deaths,
		"destroyed": coins, "lost": lost_buildings, "age": age[MINE], "waves": waves_sent})
	Audio.play("win")
	Audio.play_track("victoria", false)
	toast(Kit.text("empire_victory", "\u00a1Victoria! El reino es tuyo"))
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


func stars_earned() -> int:
	var s: int = 1
	if par <= 0.0 or time_in_level <= par:
		s += 1
	var home: int = main_center(MINE)
	if home >= 0 and float(buildings[home]["hp"]) >= float(buildings[home]["max"]) * 0.5:
		s += 1
	return s


func _lose(why: String) -> void:
	if finished:
		return
	finished = true
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "empire", "time": snappedf(time_in_level, 0.1), "destroyed": coins, "age": age[MINE]})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("empire_lost", "\u00a1Tu reino ha ca\u00eddo!"),
		why + ". " + Kit.text("empire_fail_hint", "Entrena lanceros contra jinetes, arqueros contra lanceros y sube de edad antes."))
	p.closed.connect(retry)


func retry() -> void:
	speed = 1.0
	_reset()


func open_pause() -> void:
	if finished or get_tree().paused or get_node_or_null("PauseMenu") != null:
		return
	_pressing = false
	PauseMenu.open(self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_inside_tree() and not UI.test_mode:
			open_pause()


func bot_state() -> Dictionary:
	return {"pos": Vector2(float(coins), float(pop(MINE))), "deaths": deaths, "coins": coins, "finished": finished, "failed": failed,
		"stomps": 0, "time": time_in_level, "age": age[MINE], "army": army_count(MINE), "rival_army": army_count(RIVAL),
		"villagers": count_units("aldeano", MINE), "waves": waves_sent}


# ------------------------------------------------------------------ dibujo

## Colores del terreno segun el bioma que pide el juego (game.json -> "biome").
const BIOMES: Dictionary = {
	"pradera": {"g": "#5c8a3c", "t1": "#2f6b2a", "t2": "#3f8a36", "w": "#3b78c2", "w2": "#7fb2ea", "r": "#7d7f86", "b": "#3d7a33"},
	"desierto": {"g": "#d4b36a", "t1": "#4f8a3a", "t2": "#6fae4a", "w": "#3fa0c8", "w2": "#9fe0f0", "r": "#a8865a", "b": "#6a8a3a"},
	"nieve": {"g": "#dfe8ee", "t1": "#2d5a4a", "t2": "#f4fbff", "w": "#7fb0d8", "w2": "#d8ecfa", "r": "#8c949c", "b": "#4a7a5a"},
	"otono": {"g": "#8c8a40", "t1": "#b8542a", "t2": "#e08a3a", "w": "#3b78c2", "w2": "#7fb2ea", "r": "#7d7f86", "b": "#7a6a2a"},
	"volcan": {"g": "#4a3f3a", "t1": "#3b4a2a", "t2": "#56663a", "w": "#e0582a", "w2": "#ffb03a", "r": "#2c2826", "b": "#4a5a2a"},
}


func _biome() -> Dictionary:
	return BIOMES.get(str(Kit.config.get("biome", "pradera")), BIOMES["pradera"])


func _draw_ground() -> void:
	_ground_dirty = false
	var bm: Dictionary = _biome()
	var g1: Color = Color(str(bm["g"]))
	var g2: Color = g1.darkened(0.06)
	var t1: Color = Color(str(bm["t1"]))
	var t2: Color = Color(str(bm["t2"]))
	var desert: bool = str(Kit.config.get("biome", "")) == "desierto"
	for y: int in h:
		for x: int in w:
			var r: Rect2 = Rect2(Vector2(x, y) * CELL, Vector2(CELL, CELL))
			var t: int = terrain[y * w + x]
			_ground.draw_rect(r, g1 if (x + y) % 2 == 0 else g2)
			var c: Vector2 = r.get_center()
			if t == MapRules.WATER:
				_ground.draw_rect(r, Color(str(bm["w"])))
				_ground.draw_line(c + Vector2(-12, -4), c + Vector2(-2, -4), Color(str(bm["w2"])), 2.0)
				_ground.draw_line(c + Vector2(2, 6), c + Vector2(12, 6), Color(str(bm["w2"])), 2.0)
			elif t == MapRules.ROCK:
				_ground.draw_colored_polygon(PackedVector2Array([c + Vector2(-17, 14), c + Vector2(-8, -12), c + Vector2(4, -16),
					c + Vector2(17, 12)]), Color(str(bm["r"])))
				_ground.draw_line(c + Vector2(-8, -12), c + Vector2(0, 8), Color(str(bm["r"])).darkened(0.25), 2.0)
			elif t == MapRules.TREE:
				_ground.draw_circle(c + Vector2(3, 6), 13.0, Color(0, 0, 0, 0.18))
				if desert:
					## Palmera: tronco y hojas en estrella.
					_ground.draw_line(c + Vector2(0, 14), c + Vector2(2, -6), Color("#8a5a2b"), 4.0)
					for k: int in 5:
						var ang: float = -PI * 0.5 + (float(k) - 2.0) * 0.7
						_ground.draw_line(c + Vector2(2, -6), c + Vector2(2, -6) + Vector2(cos(ang), sin(ang) * 0.6 + 0.3) * 14.0, t1, 4.0)
				else:
					_ground.draw_rect(Rect2(c + Vector2(-3, 4), Vector2(6, 12)), Color("#6b4423"))
					_ground.draw_circle(c + Vector2(0, -3), 15.0, t1)
					_ground.draw_circle(c + Vector2(-5, -7), 7.0, t2)
			elif t == MapRules.BUSH:
				_ground.draw_circle(c, 13.0, Color(str(bm["b"])))
				for k: int in 5:
					_ground.draw_circle(c + Vector2(cos(k * 1.3) * 7.0, sin(k * 1.3) * 7.0), 3.0, Color("#d8344a"))
			elif t == MapRules.GOLD:
				_ground.draw_colored_polygon(PackedVector2Array([c + Vector2(-16, 12), c + Vector2(-10, -8), c + Vector2(6, -13),
					c + Vector2(16, 10)]), Color("#8a8178"))
				_ground.draw_circle(c + Vector2(-4, 0), 5.0, Color("#ffd23f"))
				_ground.draw_circle(c + Vector2(6, 3), 4.0, Color("#ffe27a"))
				_ground.draw_circle(c + Vector2(1, -7), 3.0, Color("#ffd23f"))


func _draw_world() -> void:
	for b: Dictionary in buildings:
		if b["alive"] and (int(b["owner"]) == MINE or explored_at(center_of(b))):
			_draw_building(b)
	## Bandera del punto de reunion.
	var rp: Vector2 = rally[MINE] * CELL
	_world.draw_line(rp + Vector2(0, 12), rp + Vector2(0, -16), Color("#e8e2d0"), 2.0)
	_world.draw_colored_polygon(PackedVector2Array([rp + Vector2(0, -16), rp + Vector2(14, -11), rp + Vector2(0, -6)]), OWNER_COLORS[MINE])
	for u: Dictionary in units:
		if u["alive"] and not bool(u.get("hidden", false)) and (int(u["owner"]) == MINE or visible_at(u["pos"])):
			_draw_unit(u)
	for f: Dictionary in _fx:
		match str(f["type"]):
			"arrow":
				var a: Vector2 = (f["from"] as Vector2) * CELL
				var b2: Vector2 = (f["to"] as Vector2) * CELL
				var k: float = 1.0 - float(f["t"]) / 0.25
				var p: Vector2 = a.lerp(b2, clampf(k, 0.0, 1.0))
				_world.draw_line(p - (b2 - a).normalized() * 9.0, p, Color("#f3e3b5"), 2.0)
			"hit":
				_world.draw_circle((f["at"] as Vector2) * CELL, 5.0, Color(1, 1, 1, 0.7))
			"boom":
				var r: float = (1.0 - float(f["t"]) / 0.6) * CELL * float(f["size"]) * 0.8 + 8.0
				_world.draw_circle((f["at"] as Vector2) * CELL, r, Color(1.0, 0.6, 0.2, float(f["t"])))
			"flag":
				var fp: Vector2 = (f["at"] as Vector2) * CELL
				_world.draw_arc(fp, 14.0 + (1.2 - float(f["t"])) * 10.0, 0.0, TAU, 20, Color(1, 1, 1, float(f["t"]) / 1.2), 3.0)
	if placing != "" and ghost.x >= 0:
		var s: int = int(MapRules.builds[placing]["size"])
		var ok: bool = can_place(placing, ghost)
		var gr: Rect2 = Rect2(Vector2(ghost) * CELL, Vector2(s, s) * CELL)
		_world.draw_rect(gr, Color(0.3, 1.0, 0.4, 0.35) if ok else Color(1.0, 0.25, 0.2, 0.35))
		_world.draw_rect(gr, Color(1, 1, 1, 0.9), false, 3.0)


func _draw_building(b: Dictionary) -> void:
	var s: float = float(b["size"])
	var r: Rect2 = Rect2(Vector2(b["cell"]) * CELL, Vector2(s, s) * CELL).grow(-3.0)
	var own: Color = OWNER_COLORS[int(b["owner"])]
	var a: float = 1.0 if b["done"] else 0.55
	var wall: Color = Color("#c9b48a", a)
	var roof: Color = Color(own.darkened(0.15), a)
	var c: Vector2 = r.get_center()
	var kind: String = str(b["kind"])
	match kind:
		"granja":
			_world.draw_rect(r, Color("#9c7a3c", a))
			for k: int in 4:
				var y: float = r.position.y + (float(k) + 0.5) * r.size.y / 4.0
				_world.draw_line(Vector2(r.position.x + 4.0, y), Vector2(r.end.x - 4.0, y), Color("#c9a64a", a), 4.0)
			_world.draw_rect(r, Color(own, a), false, 2.0)
		"muro":
			_world.draw_rect(r, Color("#8f7d62", a))
			_world.draw_rect(r, Color(own, a), false, 2.0)
		"torre":
			_world.draw_rect(Rect2(r.position + Vector2(4, 6), r.size), Color(0, 0, 0, 0.25 * a))
			var tw: Rect2 = r.grow(-3.0)
			tw.position.y -= 14.0
			tw.size.y += 14.0
			_world.draw_rect(tw, Color("#a9a39a", a))
			_world.draw_rect(Rect2(tw.position, Vector2(tw.size.x, tw.size.y * 0.45)), Color("#c4beb4", a))
			for k: int in 3:
				_world.draw_rect(Rect2(Vector2(tw.position.x + float(k) * tw.size.x / 3.0 + 1.0, tw.position.y - 5.0), Vector2(tw.size.x / 3.0 - 3.0, 6.0)), Color("#c4beb4", a))
			_world.draw_rect(Rect2(Vector2(tw.get_center().x - 3.0, tw.end.y - 12.0), Vector2(6, 10)), Color("#4a3a2a", a))
			_world.draw_rect(Rect2(tw.get_center() - Vector2(5, 14), Vector2(10, 8)), roof)
		_:
			## Casa vista desde arriba y un poco de frente: sombra, fachada (con puerta) y tejado a
			## dos aguas con su caballete; el centro urbano lleva ventanas y bandera.
			_world.draw_rect(Rect2(r.position + Vector2(5, 6), r.size), Color(0, 0, 0, 0.22 * a))
			var front_h: float = r.size.y * 0.36
			var face: Rect2 = Rect2(Vector2(r.position.x, r.end.y - front_h), Vector2(r.size.x, front_h))
			_world.draw_rect(face, wall)
			_world.draw_rect(Rect2(face.position, Vector2(face.size.x, 3.0)), wall.darkened(0.25))
			var door_w: float = r.size.x * (0.16 if s >= 3.0 else 0.22)
			_world.draw_rect(Rect2(Vector2(c.x - door_w * 0.5, face.end.y - front_h * 0.72), Vector2(door_w, front_h * 0.72)), Color("#5a3a20", a))
			if kind == "centro":
				for k: int in [-1, 1]:
					_world.draw_rect(Rect2(Vector2(c.x + float(k) * r.size.x * 0.3 - 6.0, face.position.y + front_h * 0.3), Vector2(12, 10)), Color("#ffe9a8", a))
			var top: Rect2 = Rect2(r.position, Vector2(r.size.x, r.size.y - front_h))
			var mid_x: float = top.get_center().x
			_world.draw_colored_polygon(PackedVector2Array([top.position + Vector2(-3, 0), Vector2(mid_x, top.position.y), Vector2(mid_x, top.end.y), Vector2(top.position.x - 3.0, top.end.y)]), roof.lightened(0.14))
			_world.draw_colored_polygon(PackedVector2Array([Vector2(mid_x, top.position.y), Vector2(top.end.x + 3.0, top.position.y), Vector2(top.end.x + 3.0, top.end.y), Vector2(mid_x, top.end.y)]), roof.darkened(0.08))
			_world.draw_line(Vector2(mid_x, top.position.y), Vector2(mid_x, top.end.y), roof.darkened(0.35), 3.0)
			_world.draw_line(Vector2(top.position.x - 3.0, top.end.y), Vector2(top.end.x + 3.0, top.end.y), roof.darkened(0.4), 3.0)
			var mark: Color = Color(1, 1, 1, 0.9 * a)
			var mc: Vector2 = top.get_center()
			match kind:
				"centro":
					_world.draw_line(mc + Vector2(0, 0), mc + Vector2(0, -44), Color("#e8e2d0", a), 3.0)
					_world.draw_colored_polygon(PackedVector2Array([mc + Vector2(0, -44), mc + Vector2(24, -37), mc + Vector2(0, -30)]), Color(own.lightened(0.25), a))
				"cuartel":
					_world.draw_line(mc + Vector2(-9, -9), mc + Vector2(9, 9), mark, 3.0)
					_world.draw_line(mc + Vector2(9, -9), mc + Vector2(-9, 9), mark, 3.0)
				"arqueria":
					_world.draw_arc(mc + Vector2(-4, 0), 11.0, -1.2, 1.2, 10, mark, 3.0)
					_world.draw_line(mc + Vector2(0, -10), mc + Vector2(0, 10), mark, 1.5)
				"establo":
					_world.draw_arc(mc, 9.0, PI * 0.15, PI * 1.85, 14, mark, 4.0)
				"taller":
					_world.draw_arc(mc, 9.0, 0.0, TAU, 14, mark, 3.0)
					_world.draw_line(mc + Vector2(-9, 0), mc + Vector2(9, 0), mark, 2.0)
					_world.draw_line(mc + Vector2(0, -9), mc + Vector2(0, 9), mark, 2.0)
				"almacen":
					_world.draw_rect(Rect2(mc - Vector2(8, 8), Vector2(16, 16)), Color("#8a5a2b", a))
					_world.draw_line(mc - Vector2(8, 8), mc + Vector2(8, 8), Color("#d9a066", a), 2.0)
	if not b["done"]:
		_bar(Vector2(r.get_center().x, r.end.y - 6.0), r.size.x * 0.8, float(b["prog"]), Color("#ffd23f"))
	elif float(b["hp"]) < float(b["max"]) - 0.5:
		_bar(Vector2(r.get_center().x, r.position.y - 4.0), r.size.x * 0.8, float(b["hp"]) / float(b["max"]), Color("#56d36a") if int(b["owner"]) == MINE else Color("#ff6b5b"))
	if not (b["queue"] as Array).is_empty() and b["done"]:
		var kind2: String = str((b["queue"] as Array)[0])
		var q: float = float(b["qt"]) / float(MapRules.units[kind2]["time"])
		_bar(Vector2(r.get_center().x, r.end.y - 6.0), r.size.x * 0.6, q, Color("#8fd0ff"))


func _draw_unit(u: Dictionary) -> void:
	## Se dibuja alrededor de (0, 0) y un 30 % mas grande para que se vea bien en el movil.
	_world.draw_set_transform((u["pos"] as Vector2) * CELL, 0.0, Vector2.ONE * 1.3)
	var p: Vector2 = Vector2.ZERO
	var own: Color = OWNER_COLORS[int(u["owner"])]
	var dark: Color = Color(0, 0, 0, 0.55)
	var f: float = float(u["face"])
	match str(u["kind"]):
		"aldeano":
			_world.draw_circle(p + Vector2(0, 2), 8.0, dark)
			_world.draw_circle(p, 7.0, own.lightened(0.35))
			_world.draw_circle(p + Vector2(0, -3), 4.0, Color("#f1c9a0"))
			if float(u["carry"]) > 0.5:
				var cc: Color = {"comida": Color("#d8344a"), "madera": Color("#8a5a2b"), "oro": Color("#ffd23f")}.get(str(u["ctype"]), Color.WHITE)
				_world.draw_rect(Rect2(p + Vector2(-f * 9.0 - 3.0, -2.0), Vector2(6, 6)), cc)
		"lancero":
			_world.draw_circle(p + Vector2(0, 2), 10.0, dark)
			_world.draw_circle(p, 9.0, own)
			_world.draw_line(p + Vector2(-f * 4.0, 8.0), p + Vector2(f * 12.0, -14.0), Color("#e8e2d0"), 2.0)
			_world.draw_circle(p + Vector2(0, -2), 4.0, Color("#c0c4cc"))
		"arquero":
			_world.draw_circle(p + Vector2(0, 2), 9.0, dark)
			_world.draw_circle(p, 8.0, own)
			_world.draw_arc(p + Vector2(f * 6.0, 0), 9.0, -PI * 0.5 + (0.0 if f > 0.0 else PI), PI * 0.5 + (0.0 if f > 0.0 else PI), 8, Color("#8a5a2b"), 2.0)
			_world.draw_circle(p + Vector2(0, -2), 3.5, Color("#5a7a2f"))
		"jinete":
			_world.draw_circle(p + Vector2(0, 3), 13.0, dark)
			_world.draw_rect(Rect2(p + Vector2(-13, -5), Vector2(26, 11)), Color("#7a4a26"))
			_world.draw_circle(p + Vector2(f * 13.0, -3), 4.5, Color("#7a4a26"))
			_world.draw_circle(p + Vector2(0, -4), 7.0, own)
			_world.draw_line(p + Vector2(0, -4), p + Vector2(f * 16.0, -12.0), Color("#e8e2d0"), 2.0)
		"ariete":
			_world.draw_rect(Rect2(p + Vector2(-14, -9), Vector2(28, 18)), dark)
			_world.draw_rect(Rect2(p + Vector2(-13, -10), Vector2(26, 16)), Color("#6b4423"))
			_world.draw_colored_polygon(PackedVector2Array([p + Vector2(-13, -10), p + Vector2(13, -10), p + Vector2(0, -18)]), own)
			_world.draw_rect(Rect2(p + Vector2(f * 10.0 - 4.0, -3), Vector2(8, 6)), Color("#a9a39a"))
	if float(u["hp"]) < float(u["max"]) - 0.1:
		_bar(p + Vector2(0, -16), 22.0, float(u["hp"]) / float(u["max"]), Color("#56d36a") if int(u["owner"]) == MINE else Color("#ff6b5b"))
	_world.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _bar(c: Vector2, wd: float, f: float, col: Color) -> void:
	var r: Rect2 = Rect2(c - Vector2(wd * 0.5, 3.0), Vector2(wd, 6.0))
	_world.draw_rect(r, Color(0, 0, 0, 0.6))
	_world.draw_rect(Rect2(r.position, Vector2(wd * clampf(f, 0.0, 1.0), 6.0)), col)
