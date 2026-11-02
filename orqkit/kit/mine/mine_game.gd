extends Node2D
## Minas: idle de excavar (estilo Idle Miner) en corte lateral. Las reglas estan en mine_map.gd.
## 1 - Arriba la superficie: la torre del ascensor, el monton de mineral y el almacen donde el
##     transportista vende. Abajo, los pozos uno debajo de otro (desliza para bajar).
## 2 - Toca una estacion sin gerente para que haga un viaje (mineros, ascensor o transportista).
## 3 - Al tocarla tambien se elige: abajo salen sus datos y los botones de mejorar, contratar
##     gerente (trabaja solo) e impulso (x2 un rato, solo con gerente).
## 4 - Abre pozos mas hondos: cada uno da un mineral que vale 10 veces mas.
## 5 - Ganas al ganar la meta de dinero del nivel. Si sales a mitad, la mina sigue: al volver
##     cobras lo que han hecho los gerentes (hasta 2 horas, a mitad de ritmo).
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel al acabar.

const MapRules = preload("res://kit/mine/mine_map.gd")
const W: float = 720.0
const SURFACE: float = 330.0
const ROW: float = 210.0
const SHAFT_X: float = 64.0
const SHAFT_W: float = 96.0
const BOX_X: float = 182.0
const FACE_X: float = 640.0
const ORE_COLORS: Dictionary = {"c": "#3a3a3a", "h": "#b0563a", "b": "#c8873a", "p": "#d8dde6", "o": "#ffd23f", "r": "#e0304a",
	"e": "#2fd07a", "d": "#7fe8ff"}
const OFFLINE_MAX: float = 7200.0

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
var selected: Array = ["elev", 0]

var _world: Node2D
var _camera: Camera2D
var _font: Font
var _cash: Label
var _rate: Label
var _goal: Label
var _goal_bar: ColorRect
var _goal_back: ColorRect
var _title: Label
var _stats: Label
var _btn_up: Button
var _btn_up10: Button
var _btn_mgr: Button
var _btn_boost: Button
var _toast: Label
var _toast_t: float = 0.0
var _hud_t: float = 0.0
var _press_pos: Vector2 = Vector2.ZERO
var _pressing: bool = false
var _dragging: bool = false
var _sold_t: float = 0.0
var _pops: Array[Dictionary] = []
var _last_cash: float = 0.0


func _ready() -> void:
	level = Kit.current_level()
	par = float(level.get("par", 0))
	RenderingServer.set_default_clear_color(Color("#2a1c12"))
	_world = Node2D.new()
	_world.name = "World"
	_world.draw.connect(_draw_world)
	add_child(_world)
	_camera = Camera2D.new()
	add_child(_camera)
	_camera.make_current()
	Juice.register_camera(_camera)
	_font = UI.theme.get_font("font", "Label") if UI.theme != null else ThemeDB.fallback_font
	_build_hud()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "mine", "shafts": (st["shafts"] as Array).size(), "goal": st["goal"]})


func bot_script() -> String:
	return "res://qa/mine_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(25.0, 6.0)


func _reset() -> void:
	finished = false
	failed = false
	st = MapRules.new_state(level)
	coins_total = (st["shafts"] as Array).size()
	selected = ["elev", 0]
	_pops.clear()
	_restore()
	_last_cash = float(st["cash"])
	time_in_level = float(st["time"])
	_camera.position = Vector2(W * 0.5, 640.0 - 180.0)
	_clamp_camera()
	_refresh()


# ------------------------------------------------------------------ guardar y cobrar al volver

func _save_key() -> String:
	return "%s:%d" % [str(Kit.config.get("title", "")), Kit.level_index]


func _restore() -> void:
	if auto_retry or UI.test_mode or QA.enabled:
		return
	var all: Dictionary = Save.meta().get("mine", {})
	var saved: Variant = all.get(_save_key())
	if not (saved is Dictionary) or not ((saved as Dictionary).get("state") is Dictionary):
		return
	st = (saved["state"] as Dictionary).duplicate(true)
	var away: float = clampf(Time.get_unix_time_from_system() - float(saved.get("at", 0.0)), 0.0, OFFLINE_MAX)
	## Solo producen solos los gerentes: hace falta ascensor y almacen con gerente y algun pozo.
	var auto: bool = st["elev"]["mgr"] and st["ware"]["mgr"]
	var any_shaft: bool = false
	for s: Dictionary in st["shafts"]:
		any_shaft = any_shaft or (s["open"] and s["mgr"])
	if auto and any_shaft and away > 30.0:
		var won: float = MapRules.income(st) * away * 0.5
		st["cash"] = float(st["cash"]) + won
		st["earned"] = float(st["earned"]) + won
		_toast_now(Kit.text("mine_offline", "Mientras no estabas: +{n}").format({"n": fmt(won)}))


func _save_state() -> void:
	if finished or auto_retry or UI.test_mode or QA.enabled or st.is_empty():
		return
	var m: Dictionary = Save.meta()
	if not m.has("mine"):
		m["mine"] = {}
	(m["mine"] as Dictionary)[_save_key()] = {"state": st.duplicate(true), "at": Time.get_unix_time_from_system()}
	Save.save_data()


func _clear_saved() -> void:
	var m: Dictionary = Save.meta()
	if m.has("mine") and (m["mine"] as Dictionary).has(_save_key()):
		(m["mine"] as Dictionary).erase(_save_key())
		Save.save_data()


func _exit_tree() -> void:
	_save_state()


# ------------------------------------------------------------------ interfaz

static func fmt(x: float) -> String:
	if x < 1000.0:
		return str(int(floor(x)))
	var units: Array[String] = ["K", "M", "B", "T", "aa", "ab", "ac", "ad"]
	var u: int = -1
	while x >= 1000.0 and u < units.size() - 1:
		x /= 1000.0
		u += 1
	return ("%.2f" % x if x < 10.0 else ("%.1f" % x if x < 100.0 else str(int(x)))) + units[u]


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
	col.add_theme_constant_override("separation", 6)
	safe.add_child(col)
	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 12)
	col.add_child(top)
	top.add_child(UiIcon.make("coin", Kit.color("coin", Color("#ffd23f")), 52.0))
	_cash = Label.new()
	_cash.name = "Cash"
	_cash.add_theme_font_size_override("font_size", 46)
	_cash.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_cash.add_theme_constant_override("outline_size", 8)
	top.add_child(_cash)
	_rate = Label.new()
	_rate.name = "Rate"
	_rate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rate.add_theme_color_override("font_color", Color("#9ff0a8"))
	_rate.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_rate.add_theme_constant_override("outline_size", 6)
	top.add_child(_rate)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)
	## Barra de la meta.
	var bar: Control = Control.new()
	bar.custom_minimum_size = Vector2(0, 40)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(bar)
	_goal_back = ColorRect.new()
	_goal_back.color = Color(0, 0, 0, 0.55)
	_goal_back.set_anchors_preset(Control.PRESET_FULL_RECT)
	_goal_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(_goal_back)
	_goal_bar = ColorRect.new()
	_goal_bar.color = Kit.color("accent", Color("#e8b04b"))
	_goal_bar.position = Vector2(3, 3)
	_goal_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(_goal_bar)
	_goal = Label.new()
	_goal.name = "Goal"
	_goal.set_anchors_preset(Control.PRESET_FULL_RECT)
	_goal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_goal.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_goal.add_theme_font_size_override("font_size", 24)
	_goal.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_goal.add_theme_constant_override("outline_size", 6)
	bar.add_child(_goal)
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
	## Panel de la estacion elegida.
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "Station"
	col.add_child(panel)
	var pv: VBoxContainer = VBoxContainer.new()
	pv.add_theme_constant_override("separation", 6)
	panel.add_child(pv)
	_title = Label.new()
	_title.name = "Title"
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pv.add_child(_title)
	_stats = Label.new()
	_stats.name = "Stats"
	_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stats.add_theme_font_size_override("font_size", 22)
	_stats.add_theme_color_override("font_color", UI.colors["texto_suave"])
	pv.add_child(_stats)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	pv.add_child(row)
	_btn_up = _small_button("BtnUp", true, _on_up.bind(1))
	row.add_child(_btn_up)
	_btn_up10 = _small_button("BtnUp10", false, _on_up.bind(10))
	row.add_child(_btn_up10)
	_btn_mgr = _small_button("BtnManager", false, _on_manager)
	row.add_child(_btn_mgr)
	_btn_boost = _small_button("BtnBoost", false, _on_boost)
	row.add_child(_btn_boost)


func _small_button(id: String, primary: bool, cb: Callable) -> Button:
	var b: Button = UI.make_button("", primary, "")
	b.name = id
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(UI.MIN_TOUCH, 104)
	b.clip_text = false
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(cb)
	return b


func _toast_now(t: String) -> void:
	if _toast == null:
		return
	_toast.text = t
	_toast_t = 3.5


func _station_name() -> String:
	match str(selected[0]):
		"elev":
			return Kit.text("mine_elevator", "Ascensor")
		"ware":
			return Kit.text("mine_warehouse", "Almac\u00e9n")
	return Kit.text("mine_shaft", "Pozo {n}").format({"n": int(selected[1]) + 1})


func _refresh() -> void:
	if _cash == null or st.is_empty():
		return
	_cash.text = fmt(float(st["cash"]))
	_rate.text = "+%s/s" % fmt(MapRules.income(st))
	var goal: float = float(st["goal"])
	var f: float = clampf(float(st["earned"]) / goal, 0.0, 1.0)
	_goal_bar.size = Vector2(maxf(0.0, (_goal_back.size.x - 6.0) * f), _goal_back.size.y - 6.0)
	_goal.text = Kit.text("mine_goal", "Meta") + " %s / %s" % [fmt(float(st["earned"])), fmt(goal)]
	var what: String = str(selected[0])
	var i: int = int(selected[1])
	var x: Dictionary = MapRules._station(st, what, i)
	var cash: float = float(st["cash"])
	if what == "shaft" and not x["open"]:
		var oc: float = MapRules.open_cost(i)
		_title.text = _station_name() + " \u00b7 " + _ore_name(str(x["kind"]))
		_stats.text = Kit.text("mine_locked", "Pozo cerrado: \u00e1brelo para sacar un mineral que vale {n} veces m\u00e1s").format({"n": 10})
		_btn_up.text = Kit.text("mine_open", "Abrir") + "\n" + fmt(oc)
		_btn_up.disabled = MapRules.next_closed(st) != i or cash < oc
		_btn_up10.visible = false
		_btn_mgr.visible = false
		_btn_boost.visible = false
		return
	_btn_up10.visible = true
	_btn_mgr.visible = true
	_btn_boost.visible = true
	var lvl: int = int(x["lvl"])
	_title.text = "%s \u00b7 %s %d" % [_station_name(), Kit.text("mine_level", "Nv"), lvl]
	match what:
		"shaft":
			_stats.text = Kit.text("mine_shaft_stats", "{w} mineros \u00b7 {a} por viaje \u00b7 {r}/s").format({"w": MapRules.workers(lvl),
				"a": fmt(MapRules.dig_amount(i, lvl)), "r": fmt(MapRules.dig_amount(i, lvl) / MapRules.dig_time(lvl))})
		"elev":
			_stats.text = Kit.text("mine_elev_stats", "Carga {c} \u00b7 {r}/s").format({"c": fmt(MapRules.elev_cap(lvl)), "r": fmt(MapRules.elev_rate(st))})
		"ware":
			_stats.text = Kit.text("mine_ware_stats", "{w} transportistas \u00b7 Carga {c} \u00b7 {r}/s").format({"w": MapRules.workers(lvl),
				"c": fmt(MapRules.ware_cap(lvl)), "r": fmt(MapRules.ware_rate(st))})
	var uc: float = MapRules.upgrade_cost(st, what, i)
	_btn_up.text = Kit.text("mine_upgrade", "Mejorar") + "\n" + fmt(uc)
	_btn_up.disabled = cash < uc
	var c10: float = _cost_n(what, i, 10)
	_btn_up10.text = "x10\n" + fmt(c10)
	_btn_up10.disabled = cash < c10
	if x["mgr"]:
		_btn_mgr.text = Kit.text("mine_has_manager", "Gerente\nlisto")
		_btn_mgr.disabled = true
		var cd: float = float(x["cd"])
		_btn_boost.text = Kit.text("mine_boost", "Impulso") + ("\n%ds" % int(ceil(float(x["boost"]))) if float(x["boost"]) > 0.0 else ("\n%ds" % int(ceil(cd)) if cd > 0.0 else "\nx2"))
		_btn_boost.disabled = cd > 0.0
	else:
		var mc: float = MapRules.manager_cost(int(st["hired"]))
		_btn_mgr.text = Kit.text("mine_manager", "Gerente") + "\n" + fmt(mc)
		_btn_mgr.disabled = cash < mc
		_btn_boost.text = Kit.text("mine_boost", "Impulso") + "\n-"
		_btn_boost.disabled = true


func _cost_n(what: String, i: int, n: int) -> float:
	var sim: Dictionary = {"cash": 1e300, "shafts": st["shafts"].duplicate(true), "elev": st["elev"].duplicate(), "ware": st["ware"].duplicate()}
	var total: float = 0.0
	for k: int in n:
		var c: float = MapRules.upgrade_cost(sim, what, i)
		if c == INF:
			break
		total += c
		MapRules.upgrade(sim, what, i)
	return total


func _ore_name(k: String) -> String:
	var es: Dictionary = {"c": "Carb\u00f3n", "h": "Hierro", "b": "Bronce", "p": "Plata", "o": "Oro", "r": "Rub\u00ed", "e": "Esmeralda", "d": "Diamante"}
	return Kit.text("mine_ore_" + k, str(es.get(k, k)))


# ------------------------------------------------------------------ acciones (toques y bot)

func can_act() -> bool:
	return not finished and is_inside_tree() and not get_tree().paused


func select(what: String, i: int = 0) -> void:
	selected = [what, i]
	_refresh()


func tap(what: String, i: int = 0) -> bool:
	if not can_act():
		return false
	select(what, i)
	if MapRules.tap(st, what, i):
		if not fast:
			Audio.play("click", 0.1, -8.0)
		return true
	return false


func _on_up(n: int) -> void:
	var what: String = str(selected[0])
	var i: int = int(selected[1])
	if what == "shaft" and not st["shafts"][i]["open"]:
		if MapRules.open_next(st):
			Audio.play("powerup")
			_toast_now(Kit.text("mine_opened", "\u00a1Pozo nuevo abierto!"))
			Juice.vibrate(25)
		_refresh()
		return
	var done: int = 0
	for k: int in n:
		if not MapRules.upgrade(st, what, i):
			break
		done += 1
	if done > 0:
		Audio.play("coin", 0.1, -4.0)
		_pops.append({"text": "+%d" % done, "at": _station_pos(what, i), "t": 1.0})
	_refresh()


func _on_manager() -> void:
	if MapRules.hire(st, str(selected[0]), int(selected[1])):
		Audio.play("powerup")
		_toast_now(Kit.text("mine_hired", "\u00a1Gerente contratado! Ahora trabaja solo"))
	_refresh()


func _on_boost() -> void:
	if MapRules.boost(st, str(selected[0]), int(selected[1])):
		Audio.play("powerup")
		Juice.vibrate(20)
	_refresh()


## Turno del bot: toca lo parado y hace hasta 3 compras con la cabeza del analizador.
func bot_step() -> void:
	MapRules.bot_taps(st)
	for k: int in 3:
		var a: Array = MapRules.best_action(st)
		if a.is_empty() or not MapRules.apply(st, a):
			break
	## Impulsos cuando estan listos (los usaria cualquiera).
	for what: String in ["elev", "ware"]:
		MapRules.boost(st, what)
	for i: int in (st["shafts"] as Array).size():
		MapRules.boost(st, "shaft", i)


# ------------------------------------------------------------------ simulacion

func _physics_process(delta: float) -> void:
	if finished:
		return
	var steps: int = 8 if fast else 1
	var dt: float = 0.25 if fast else delta * (3.0 if auto_retry else 1.0)
	for k: int in steps:
		MapRules.step(st, dt)
		if float(st["earned"]) >= float(st["goal"]):
			time_in_level = float(st["time"])
			_finish()
			return
	time_in_level = float(st["time"])
	coins = MapRules.open_count(st)
	if float(st["cash"]) > _last_cash + 0.5 and not fast:
		_sold_t -= delta
		if _sold_t <= 0.0:
			_sold_t = 0.6
			Audio.play("coin", 0.05, -12.0)
	_last_cash = float(st["cash"])
	for p: Dictionary in _pops:
		p["t"] = float(p["t"]) - delta
	var keep: Array[Dictionary] = []
	for p: Dictionary in _pops:
		if float(p["t"]) > 0.0:
			keep.append(p)
	_pops = keep
	_hud_t -= delta
	if _hud_t <= 0.0:
		_hud_t = 0.15
		_refresh()
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0:
			_toast.text = ""
	_world.queue_redraw()


# ------------------------------------------------------------------ entrada

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()
		return
	if event is InputEventScreenDrag:
		var dr: InputEventScreenDrag = event
		if _pressing and (_dragging or dr.position.distance_to(_press_pos) > 14.0):
			_dragging = true
			_camera.position.y -= dr.relative.y / _camera.zoom.y
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
	tap_world(get_canvas_transform().affine_inverse() * t.position)


## Toque en el mundo (en pixeles del mundo): elige la estacion y, si no tiene gerente, trabaja.
func tap_world(p: Vector2) -> void:
	if p.y < SURFACE:
		tap("elev" if p.x < BOX_X else "ware")
		return
	var i: int = int((p.y - SURFACE) / ROW)
	if i < 0 or i >= (st["shafts"] as Array).size():
		return
	if p.x < SHAFT_X + SHAFT_W + 10.0:
		tap("elev")
		return
	if st["shafts"][i]["open"]:
		tap("shaft", i)
	else:
		select("shaft", i)


func _clamp_camera() -> void:
	var vp: Vector2 = get_viewport_rect().size
	_camera.zoom = Vector2.ONE * (vp.x / W)
	var half: float = vp.y * 0.5 / _camera.zoom.y
	var bottom: float = SURFACE + float((st.get("shafts", []) as Array).size()) * ROW + 360.0
	_camera.position.x = W * 0.5
	_camera.position.y = clampf(_camera.position.y, half - 200.0, maxf(half - 200.0, bottom - half))


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	_clear_saved()
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = maxi(0, 30000 - int(time_in_level) * 20) + MapRules.open_count(st) * 500
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "time": snappedf(time_in_level, 0.1), "deaths": 0,
		"shafts": MapRules.open_count(st), "managers": int(st["hired"])})
	Audio.play("win")
	Audio.play_track("victoria", false)
	Juice.burst(self, _camera.position, Kit.color("coin", Color.YELLOW), 30, 420.0)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


func stars_earned() -> int:
	if par <= 0.0 or time_in_level <= par * 1.6:
		return 3
	return 2 if time_in_level <= par * 2.5 else 1


func retry() -> void:
	_clear_saved()
	_reset()


func open_pause() -> void:
	if finished or get_tree().paused or get_node_or_null("PauseMenu") != null:
		return
	_pressing = false
	_save_state()
	PauseMenu.open(self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_state()
		if is_inside_tree() and not UI.test_mode:
			open_pause()


func bot_state() -> Dictionary:
	return {"pos": Vector2(float(st.get("earned", 0.0)), float(MapRules.open_count(st))), "deaths": deaths, "coins": coins,
		"finished": finished, "failed": failed, "stomps": 0, "time": time_in_level, "earned": float(st.get("earned", 0.0)),
		"shafts": MapRules.open_count(st), "managers": int(st.get("hired", 0))}


# ------------------------------------------------------------------ dibujo

func _shaft_y(i: int) -> float:
	return SURFACE + float(i) * ROW


func _station_pos(what: String, i: int) -> Vector2:
	match what:
		"elev":
			return Vector2(SHAFT_X + SHAFT_W * 0.5, _elev_y())
		"ware":
			return Vector2(560.0, 230.0)
	return Vector2(420.0, _shaft_y(i) + ROW * 0.55)


func _elev_y() -> float:
	var pos: float = float(st["elev"]["pos"])
	return 250.0 if pos <= -1.0 else lerpf(250.0, _shaft_y(0) + ROW * 0.6, clampf(pos + 1.0, 0.0, 1.0)) if pos < 0.0 else _shaft_y(0) + ROW * 0.6 + pos * ROW


func _text(at: Vector2, s: String, size: int, col: Color, center: bool = true) -> void:
	var wd: float = _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p: Vector2 = at - Vector2(wd * 0.5 if center else 0.0, 0.0)
	for o: Vector2 in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)]:
		_world.draw_string(_font, p + o, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.8))
	_world.draw_string(_font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _draw_world() -> void:
	if st.is_empty():
		return
	var t: float = float(st["time"])
	## Cielo y superficie.
	## Cielo de dia en degradado (la mina siempre trabaja con sol).
	var top: Color = Color("#5aa0e0")
	var low: Color = Color("#bfe3f5")
	_world.draw_rect(Rect2(-200, -900, W + 400, 900), top)
	for k: int in 12:
		var f: float = float(k) / 11.0
		_world.draw_rect(Rect2(-200, float(k) * (SURFACE - 40.0) / 12.0, W + 400, (SURFACE - 40.0) / 12.0 + 1.0), top.lerp(low, f))
	for k: int in 3:
		var hx: float = -60.0 + float(k) * 300.0
		_world.draw_circle(Vector2(hx, SURFACE - 20.0), 150.0, Color("#7fb06a").darkened(0.08 * float(k)))
	_world.draw_circle(Vector2(620, 70), 38.0, Color("#fff3b0"))
	for k: int in 4:
		var cx: float = fmod(80.0 + float(k) * 230.0 + t * 6.0, W + 200.0) - 100.0
		_world.draw_circle(Vector2(cx, 90.0 + float(k % 2) * 30.0), 24.0, Color(1, 1, 1, 0.8))
		_world.draw_circle(Vector2(cx + 26.0, 96.0 + float(k % 2) * 30.0), 18.0, Color(1, 1, 1, 0.8))
	_world.draw_rect(Rect2(-200, SURFACE - 40.0, W + 400, 40.0), Color("#5c8a3c"))
	_world.draw_rect(Rect2(-200, SURFACE - 12.0, W + 400, 12.0), Color("#3d6a2a"))
	_draw_warehouse()
	## Pozos.
	var shafts: Array = st["shafts"]
	for i: int in shafts.size():
		_draw_shaft(i, shafts[i], t)
	## Fondo de la mina.
	var end_y: float = _shaft_y(shafts.size())
	_world.draw_rect(Rect2(-200, end_y, W + 400, 900), Color("#1a120c"))
	_draw_elevator(t)
	_draw_transporter(t)
	for p: Dictionary in _pops:
		_text((p["at"] as Vector2) + Vector2(0, -60.0 + float(p["t"]) * 30.0), str(p["text"]), 34, Color("#9ff0a8"))


func _sel(what: String, i: int) -> bool:
	return str(selected[0]) == what and int(selected[1]) == i


func _draw_warehouse() -> void:
	var r: Rect2 = Rect2(470, 130, 220, SURFACE - 170.0)
	_world.draw_rect(Rect2(r.position + Vector2(8, 8), r.size), Color(0, 0, 0, 0.25))
	_world.draw_rect(r, Color("#b8875a"))
	_world.draw_rect(Rect2(r.position, Vector2(r.size.x, 14)), Color("#8a5a2b"))
	_world.draw_colored_polygon(PackedVector2Array([r.position + Vector2(-14, 0), Vector2(r.get_center().x, r.position.y - 60.0), Vector2(r.end.x + 14.0, r.position.y)]),
		Kit.color("accent", Color("#c0503a")))
	_world.draw_rect(Rect2(Vector2(r.get_center().x - 34.0, r.end.y - 80.0), Vector2(68, 80)), Color("#5a3a20"))
	_world.draw_circle(Vector2(r.get_center().x, r.position.y - 18.0), 18.0, Color("#ffd23f"))
	_text(Vector2(r.get_center().x, r.position.y - 8.0), "$", 26, Color("#7a4a10"))
	if _sel("ware", 0):
		_world.draw_rect(r.grow(6.0), Color(1, 1, 1, 0.9), false, 4.0)
	var w: Dictionary = st["ware"]
	_text(Vector2(r.get_center().x, r.end.y + 34.0), "%s %d" % [Kit.text("mine_level", "Nv"), int(w["lvl"])], 24, Color.WHITE)
	if w["mgr"]:
		_draw_manager(Vector2(r.end.x - 22.0, r.end.y - 30.0), float(w["boost"]) > 0.0)
	## Monton de mineral junto al ascensor.
	var pile: float = float(st["surface"])
	var box: Rect2 = Rect2(BOX_X, SURFACE - 92.0, 90, 52)
	_world.draw_rect(box, Color("#7a5230"))
	_world.draw_rect(box, Color("#4a2e18"), false, 3.0)
	if pile > 0.0:
		_world.draw_colored_polygon(PackedVector2Array([box.position + Vector2(6, 0), box.position + Vector2(45, -minf(30.0, 8.0 + log(pile + 1.0) * 3.0)), box.position + Vector2(84, 0)]), Color("#6a6a6a"))
	_text(Vector2(box.get_center().x, box.end.y - 12.0), fmt(pile), 22, Color.WHITE)


func _draw_transporter(t: float) -> void:
	var w: Dictionary = st["ware"]
	var half: float = MapRules.ware_time(int(w["lvl"]))
	var f: float = float(w["t"]) / half if w["busy"] else 0.0
	## Va del almacen (x 470) al monton (x 290) y vuelve.
	var x: float = lerpf(480.0, 290.0, f) if f <= 1.0 else lerpf(290.0, 480.0, f - 1.0)
	var y: float = SURFACE - 70.0
	var face: float = -1.0 if f <= 1.0 else 1.0
	for k: int in MapRules.workers(int(w["lvl"])):
		var p: Vector2 = Vector2(x + float(k) * 26.0 * -face, y + sin(t * 10.0 + float(k)) * (2.0 if w["busy"] else 0.0))
		_world.draw_rect(Rect2(p + Vector2(face * 14.0 - 14.0, 6), Vector2(28, 18)), Color("#6b4423"))
		if float(w["carry"]) > 0.0:
			_world.draw_circle(p + Vector2(face * 14.0, 4), 10.0, Color("#6a6a6a"))
		_world.draw_circle(p + Vector2(face * 14.0 - 6.0, 26), 5.0, Color("#222"))
		_world.draw_circle(p + Vector2(face * 14.0 + 6.0, 26), 5.0, Color("#222"))
		_draw_worker(p + Vector2(-face * 8.0, 0), face, Color("#3f8cff"), false, t)


func _draw_elevator(t: float) -> void:
	var shafts_n: int = (st["shafts"] as Array).size()
	var col: Rect2 = Rect2(SHAFT_X, 140.0, SHAFT_W, _shaft_y(shafts_n) - 140.0)
	_world.draw_rect(Rect2(col.position.x, SURFACE - 40.0, col.size.x, col.size.y), Color("#120c08"))
	## Torre con la polea.
	for k: int in [0, 1]:
		var x: float = col.position.x + (6.0 if k == 0 else col.size.x - 12.0)
		_world.draw_rect(Rect2(x, 140.0, 6.0, col.end.y - 140.0), Color("#7d7f86"))
	for yi: int in range(150, int(SURFACE) - 30, 34):
		var y: float = float(yi)
		_world.draw_line(Vector2(col.position.x + 6.0, y), Vector2(col.end.x - 6.0, y + 30.0), Color("#5e6066"), 3.0)
	var wheel: Vector2 = Vector2(col.get_center().x, 140.0)
	_world.draw_arc(wheel, 26.0, 0.0, TAU, 20, Color("#a9a39a"), 6.0)
	var e: Dictionary = st["elev"]
	var ang: float = t * (3.0 if e["busy"] else 0.0)
	_world.draw_line(wheel - Vector2(cos(ang), sin(ang)) * 24.0, wheel + Vector2(cos(ang), sin(ang)) * 24.0, Color("#a9a39a"), 4.0)
	var y2: float = _elev_y()
	_world.draw_line(wheel + Vector2(0, 26), Vector2(wheel.x, y2 - 40.0), Color("#c8c2b0"), 3.0)
	var cab: Rect2 = Rect2(col.position.x + 12.0, y2 - 40.0, col.size.x - 24.0, 74.0)
	_world.draw_rect(cab, Color("#c0503a"))
	_world.draw_rect(Rect2(cab.position + Vector2(6, 8), Vector2(cab.size.x - 12.0, 34)), Color("#2a1c12"))
	if float(e["load"]) > 0.0:
		_world.draw_circle(cab.get_center() + Vector2(0, -10), 12.0, Color("#6a6a6a"))
	_text(Vector2(cab.get_center().x, cab.end.y - 6.0), fmt(float(e["load"])), 20, Color.WHITE)
	if e["mgr"]:
		_draw_manager(Vector2(col.end.x + 22.0, 220.0), float(e["boost"]) > 0.0)
	if _sel("elev", 0):
		_world.draw_rect(cab.grow(5.0), Color(1, 1, 1, 0.9), false, 4.0)
	_text(Vector2(col.get_center().x, 104.0), "%s %d" % [Kit.text("mine_level", "Nv"), int(e["lvl"])], 24, Color.WHITE)


func _draw_shaft(i: int, s: Dictionary, t: float) -> void:
	var y0: float = _shaft_y(i)
	var r: Rect2 = Rect2(-200, y0, W + 400, ROW)
	var rock: Color = Color("#5a3d28").darkened(minf(0.5, float(i) * 0.06))
	_world.draw_rect(r, rock)
	## Textura de roca (siempre igual en cada pozo).
	for k: int in 14:
		var px: float = fmod(float(k * 97 + i * 53), W)
		var py: float = y0 + 14.0 + fmod(float(k * 41 + i * 29), ROW - 28.0)
		_world.draw_circle(Vector2(px, py), 5.0 + float(k % 3) * 3.0, rock.darkened(0.18))
	_world.draw_line(Vector2(-200, y0), Vector2(W + 200, y0), rock.darkened(0.4), 4.0)
	var floor_y: float = y0 + ROW - 34.0
	var ore: Color = Color(str(ORE_COLORS.get(str(s["kind"]), "#888888")))
	if not s["open"]:
		_world.draw_rect(Rect2(SHAFT_X + SHAFT_W, y0, W, ROW), Color(0, 0, 0, 0.55))
		var next: bool = MapRules.next_closed(st) == i
		if next:
			var c: Vector2 = Vector2(420, y0 + ROW * 0.42)
			_world.draw_rect(Rect2(c - Vector2(150, 44), Vector2(300, 88)), Color("#2a1c12"))
			_world.draw_rect(Rect2(c - Vector2(150, 44), Vector2(300, 88)), ore, false, 3.0)
			_text(c + Vector2(0, -4), Kit.text("mine_open_shaft", "Abrir pozo {n}").format({"n": i + 1}), 28, Color.WHITE)
			_text(c + Vector2(0, 30), fmt(MapRules.open_cost(i)), 26, Color("#ffd23f") if float(st["cash"]) >= MapRules.open_cost(i) else Color("#ff8a7a"))
			if _sel("shaft", i):
				_world.draw_rect(Rect2(c - Vector2(156, 50), Vector2(312, 100)), Color(1, 1, 1, 0.9), false, 4.0)
		else:
			_text(Vector2(420, y0 + ROW * 0.5), "?", 40, Color(1, 1, 1, 0.3))
		return
	## Tunel excavado, suelo y la veta de mineral al fondo.
	_world.draw_rect(Rect2(SHAFT_X + SHAFT_W, y0 + 40.0, FACE_X - SHAFT_X - SHAFT_W + 20.0, ROW - 74.0), Color("#2e1f14"))
	_world.draw_rect(Rect2(SHAFT_X + SHAFT_W, floor_y, W, 8.0), Color("#7a5a3a"))
	for k: int in 3:
		var bx: float = 260.0 + float(k) * 130.0
		_world.draw_rect(Rect2(bx, y0 + 40.0, 10.0, ROW - 74.0), Color("#6b4423"))
		_world.draw_rect(Rect2(bx - 14.0, y0 + 40.0, 38.0, 10.0), Color("#6b4423"))
		_world.draw_circle(Vector2(bx + 5.0, y0 + 62.0), 7.0, Color(1.0, 0.85, 0.5, 0.7 + 0.2 * sin(t * 3.0 + float(k))))
	for k: int in 7:
		var vp: Vector2 = Vector2(FACE_X + 10.0 + float(k % 3) * 18.0, y0 + 60.0 + float(k) * 16.0)
		_world.draw_colored_polygon(PackedVector2Array([vp + Vector2(0, -9), vp + Vector2(8, 0), vp + Vector2(0, 9), vp + Vector2(-8, 0)]), ore)
	## Caja del pozo.
	var box: Rect2 = Rect2(BOX_X, floor_y - 50.0, 78, 50)
	_world.draw_rect(box, Color("#8a5a2b"))
	_world.draw_rect(box, Color("#4a2e18"), false, 3.0)
	_world.draw_line(box.position, box.end, Color("#4a2e18"), 2.0)
	if float(s["box"]) > 0.0:
		_world.draw_circle(box.get_center() + Vector2(0, -26), 14.0, ore)
	_text(Vector2(box.get_center().x, box.position.y - 34.0), fmt(float(s["box"])), 22, Color.WHITE)
	## Mineros: van a la veta, pican y vuelven.
	var lvl: int = int(s["lvl"])
	var dur: float = MapRules.dig_time(lvl)
	var f: float = float(s["t"]) / dur if s["busy"] else 0.0
	for k: int in MapRules.workers(lvl):
		var off: float = float(k) * 34.0
		var x: float = 0.0
		var face: float = 1.0
		var digging: bool = false
		if f < 0.35:
			x = lerpf(BOX_X + 100.0 + off, FACE_X - 30.0 - off, f / 0.35)
		elif f < 0.7:
			x = FACE_X - 30.0 - off
			digging = true
		else:
			x = lerpf(FACE_X - 30.0 - off, BOX_X + 100.0 + off, (f - 0.7) / 0.3)
			face = -1.0
		if not s["busy"]:
			x = BOX_X + 100.0 + off
		_draw_worker(Vector2(x, floor_y - 30.0), face, Color("#e0a030"), digging, t + float(k))
	if s["mgr"]:
		_draw_manager(Vector2(BOX_X + 40.0, y0 + 64.0), float(s["boost"]) > 0.0)
	elif not s["busy"]:
		## Sin gerente y parado: un dedo que invita a tocar.
		var bob: float = sin(t * 6.0) * 6.0
		_text(Vector2(420, y0 + 96.0 + bob), Kit.text("mine_tap", "\u00a1Toca!"), 30, Color("#ffd23f"))
	_text(Vector2(SHAFT_X + SHAFT_W + 16.0, y0 + 30.0), "%d \u00b7 %s \u00b7 %s %d" % [i + 1, _ore_name(str(s["kind"])), Kit.text("mine_level", "Nv"), lvl], 22,
		Color.WHITE, false)
	if _sel("shaft", i):
		_world.draw_rect(Rect2(SHAFT_X + SHAFT_W + 4.0, y0 + 6.0, W - SHAFT_X - SHAFT_W - 12.0, ROW - 12.0), Color(1, 1, 1, 0.85), false, 4.0)


func _draw_worker(p: Vector2, face: float, shirt: Color, digging: bool, t: float) -> void:
	var step: float = sin(t * 12.0) * 4.0
	_world.draw_circle(p + Vector2(0, 30), 12.0, Color(0, 0, 0, 0.25))
	_world.draw_line(p + Vector2(-4, 14), p + Vector2(-4 + step, 28), Color("#3a2a1a"), 5.0)
	_world.draw_line(p + Vector2(4, 14), p + Vector2(4 - step, 28), Color("#3a2a1a"), 5.0)
	_world.draw_rect(Rect2(p + Vector2(-9, -4), Vector2(18, 20)), shirt)
	_world.draw_circle(p + Vector2(0, -12), 9.0, Color("#f1c9a0"))
	_world.draw_rect(Rect2(p + Vector2(-10, -24), Vector2(20, 8)), Color("#ffd23f"))
	_world.draw_circle(p + Vector2(face * 9.0, -20), 3.0, Color("#fff8c0"))
	if digging:
		var a: float = sin(t * 14.0) * 0.9 - 0.4
		var hand: Vector2 = p + Vector2(face * 8.0, 0)
		var tip: Vector2 = hand + Vector2(cos(a) * face, sin(a)) * 26.0
		_world.draw_line(hand, tip, Color("#8a5a2b"), 4.0)
		_world.draw_line(tip + Vector2(0, -8), tip + Vector2(0, 8), Color("#c0c4cc"), 4.0)


func _draw_manager(p: Vector2, boosting: bool) -> void:
	if boosting:
		_world.draw_circle(p, 26.0, Color(1.0, 0.8, 0.2, 0.35))
	_world.draw_rect(Rect2(p + Vector2(-10, -2), Vector2(20, 22)), Color("#2a2a3a"))
	_world.draw_colored_polygon(PackedVector2Array([p + Vector2(-3, -2), p + Vector2(3, -2), p + Vector2(0, 10)]), Color("#e0304a"))
	_world.draw_circle(p + Vector2(0, -12), 9.0, Color("#f1c9a0"))
	_world.draw_rect(Rect2(p + Vector2(-11, -26), Vector2(22, 6)), Color("#2a2a3a"))
	_world.draw_rect(Rect2(p + Vector2(-7, -36), Vector2(14, 12)), Color("#2a2a3a"))
