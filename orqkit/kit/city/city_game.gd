extends Node2D
## Ciudad: elige abajo que construir y toca el solar. Haz crecer la ciudad hasta la meta.
## Reglas, simulacion, bot y analizador en city_map.gd.
## 1 - Todo necesita tocar una carretera unida al ayuntamiento (si no, sale un aviso rojo).
## 2 - Casas = habitantes; tiendas y fabricas = trabajo; parques = felicidad; las fabricas
##     molestan a las casas de al lado. Las casas felices suben a bloques de pisos.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const REVIVE_SECS: float = 40.0
const MapRules = preload("res://kit/city/city_map.gd")
const TOOLS: Array[String] = ["road", "house", "shop", "factory", "park"]

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
var tool: String = "house"

var _font: Font
var _world: Node2D
var _camera: Camera2D
var _pop_label: Label
var _money_label: Label
var _time_label: Label
var _bar: ColorRect
var _bar_back: ColorRect
var _tools: HBoxContainer
var _cell: float = 64.0
var _origin: Vector2 = Vector2.ZERO
var _pops: Array[Dictionary] = []
var _t: float = 0.0
var _bot_cd: float = 0.0
var _last_pop: int = 0
var _net: Dictionary = {}


func _ready() -> void:
	level = Kit.current_level()
	par = float(level.get("par", 0))
	RenderingServer.set_default_clear_color(Color("#5a9a4a"))
	_font = UI.theme.get_font("font", "Label") if UI.theme != null else ThemeDB.fallback_font
	_world = Node2D.new()
	_world.name = "World"
	_world.draw.connect(_draw_world)
	add_child(_world)
	_camera = Camera2D.new()
	add_child(_camera)
	_camera.make_current()
	_camera.position = Vector2(360, 640)
	_build_hud()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "city", "goal": int(st["goal"])})


func bot_script() -> String:
	return "res://qa/city_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(16.0, 6.0)


func wants_backdrop() -> bool:
	return false


func _reset() -> void:
	finished = false
	failed = false
	st = MapRules.new_state(level)
	coins_total = int(st["goal"])
	coins = 0
	time_in_level = 0.0
	_pops.clear()
	_last_pop = 0
	var w: int = maxi(1, int(st["w"]))
	var h: int = maxi(1, int(st["h"]))
	_cell = minf(76.0, minf(690.0 / float(w), 880.0 / float(h)))
	_origin = Vector2(360.0 - float(w) * _cell * 0.5, 620.0 - float(h) * _cell * 0.5)
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
	var safe: MarginContainer = UI.safe_root(root, 12.0)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col: VBoxContainer = VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(col)
	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 8)
	col.add_child(top)
	_pop_label = _label(top, 30)
	var bar: Control = Control.new()
	bar.custom_minimum_size = Vector2(0, 26)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(bar)
	_bar_back = ColorRect.new()
	_bar_back.color = Color(0, 0, 0, 0.45)
	_bar_back.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bar_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(_bar_back)
	_bar = ColorRect.new()
	_bar.color = Color("#3f8cff")
	_bar.position = Vector2(3, 3)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(_bar)
	_time_label = _label(top, 26)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)
	var row2: HBoxContainer = HBoxContainer.new()
	row2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row2)
	row2.add_child(UiIcon.make("coin", Kit.color("coin", Color("#ffd23f")), 34.0))
	_money_label = _label(row2, 30)
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(spacer)
	_tools = HBoxContainer.new()
	_tools.name = "Tools"
	_tools.alignment = BoxContainer.ALIGNMENT_CENTER
	_tools.add_theme_constant_override("separation", 6)
	col.add_child(_tools)
	for t: String in TOOLS:
		var b: Button = UI.make_button("")
		b.name = "Tool_" + t
		b.custom_minimum_size = Vector2(128, 112)
		b.toggle_mode = true
		b.add_theme_font_size_override("font_size", 22)
		b.pressed.connect(set_tool.bind(t))
		_tools.add_child(b)


func _label(parent: Control, size: int) -> Label:
	var l: Label = Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	parent.add_child(l)
	return l


func set_tool(t: String) -> void:
	tool = t
	_sfx("click")
	_refresh()


func _tool_name(t: String) -> String:
	return {"road": Kit.text("city_road", "Calle"), "house": Kit.text("city_house", "Casa"), "shop": Kit.text("city_shop", "Tienda"),
		"factory": Kit.text("city_factory", "F\u00e1brica"), "park": Kit.text("city_park", "Parque")}[t]


func _refresh() -> void:
	if _pop_label == null or st.is_empty():
		return
	var pop: int = int(st["pop"])
	coins = mini(pop, coins_total)
	_pop_label.text = "%d/%d" % [pop, int(st["goal"])]
	_money_label.text = "%d" % int(st["money"])
	_bar.size = Vector2(maxf(0.0, (_bar_back.size.x - 6.0) * clampf(float(pop) / float(maxi(1, int(st["goal"]))), 0.0, 1.0)), _bar_back.size.y - 6.0)
	var left: int = maxi(0, int(ceil(float(st["seconds"]) - float(st["time"]))))
	_time_label.text = "%d:%02d" % [left / 60, left % 60]
	for b: Node in _tools.get_children():
		var t: String = str(b.name).trim_prefix("Tool_")
		var cost: int = int(MapRules.BUILD[t]["cost"])
		(b as Button).text = "%s\n%d" % [_tool_name(t), cost]
		(b as Button).button_pressed = t == tool
		(b as Button).modulate = Color.WHITE if float(st["money"]) >= float(cost) else Color(1, 1, 1, 0.5)


# ------------------------------------------------------------------ acciones

func can_act() -> bool:
	return not finished and is_inside_tree() and not get_tree().paused


func tap_world(p: Vector2) -> void:
	if not can_act():
		return
	var c: Vector2i = Vector2i(floori((p.x - _origin.x) / _cell), floori((p.y - _origin.y) / _cell))
	place(tool, c)


func place(what: String, c: Vector2i) -> bool:
	if MapRules.build(st, what, c):
		_pops.append({"p": _origin + (Vector2(c) + Vector2(0.5, 0.2)) * _cell, "text": "-%d" % int(MapRules.BUILD[what]["cost"]), "t": 1.0,
			"col": Color("#ffd23f")})
		_sfx("click")
		_refresh()
		return true
	if not fast and MapRules.at(st, c) != "#":
		Audio.play("hurt", 0.05, -12.0)
	return false


func _sfx(n: String) -> void:
	if not fast:
		Audio.play(n, 0.1, -8.0)


func bot_step() -> void:
	if not can_act():
		return
	var m: Array = MapRules.bot_pick(st)
	if not m.is_empty():
		tool = str(m[0])
		place(str(m[0]), m[1])


# ------------------------------------------------------------------ bucle

func _physics_process(delta: float) -> void:
	_t += delta
	for p: Dictionary in _pops:
		p["t"] = float(p["t"]) - delta
	_pops = _pops.filter(func(p: Dictionary) -> bool: return float(p["t"]) > 0.0)
	if finished:
		_world.queue_redraw()
		return
	var mult: float = 8.0 if fast else 1.0
	if fast and auto_retry:
		_bot_cd -= delta * mult
		if _bot_cd <= 0.0:
			bot_step()
			_bot_cd = 1.5
	MapRules.step(st, delta * mult)
	time_in_level = float(st["time"])
	if int(st["pop"]) > _last_pop + 4 and not fast:
		_pops.append({"p": Vector2(360, 330), "text": "+%d" % (int(st["pop"]) - _last_pop), "t": 1.0, "col": Color("#9ad0ff")})
		_last_pop = int(st["pop"])
	_refresh()
	if bool(st["won"]):
		_finish()
	elif bool(st["over"]):
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
	var score: int = int(st["pop"]) * 20 + int(st["money"]) + maxi(0, int(float(st["seconds"]) - time_in_level)) * 10
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
	return 3 if par <= 0.0 or time_in_level <= par * 1.4 else 2


func _lose() -> void:
	if finished:
		return
	finished = true
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "time", "pop": int(st["pop"]), "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("city_lost", "\u00a1Se acab\u00f3 el plazo!"),
		Kit.text("city_fail_hint", "Deja calles para seguir creciendo, pon trabajo para todos y parques junto a las casas (las f\u00e1bricas, lejos)."))
	p.closed.connect(retry)


## Segunda oportunidad (FailPanel, con anuncio): mas tiempo para llegar a la meta de habitantes.
func revive() -> void:
	st["seconds"] = float(st["seconds"]) + REVIVE_SECS
	st["over"] = false
	finished = false
	failed = false
	_refresh()


func revive_text() -> String:
	return Kit.text("revive_secs", "+{n} segundos").format({"n": int(REVIVE_SECS)})


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
	return {"pos": Vector2(float(st.get("pop", 0)), float(st.get("money", 0))), "deaths": deaths, "coins": coins, "finished": finished,
		"failed": failed, "stomps": 0, "time": time_in_level, "pop": int(st.get("pop", 0))}


# ------------------------------------------------------------------ dibujo

func _draw_cell(c: Vector2i, ch: String, r: Rect2) -> void:
	var k: float = _cell
	match ch:
		"~":
			_world.draw_rect(r, Color("#3f8ad8"))
			_world.draw_line(r.position + Vector2(k * 0.2, k * 0.4 + sin(_t * 2.0 + float(c.x)) * 3.0), r.position + Vector2(k * 0.6, k * 0.4), Color(1, 1, 1, 0.4), 2.0)
		"^":
			for q: Vector2 in [Vector2(0.3, 0.35), Vector2(0.7, 0.4), Vector2(0.5, 0.72)]:
				_world.draw_circle(r.position + q * k + Vector2(2, 3), k * 0.2, Color(0, 0, 0, 0.2))
				_world.draw_circle(r.position + q * k, k * 0.2, Color("#2f7a32"))
		"=":
			_world.draw_rect(r, Color("#55585f"))
			for d: Vector2i in MapRules.N4:
				var n: String = MapRules.at(st, c + d)
				if n == "=" or n == "T":
					_world.draw_line(r.get_center(), r.get_center() + Vector2(d) * k * 0.5, Color("#f2d24a"), 2.0)
		"T":
			_world.draw_rect(r.grow(-k * 0.06), Color("#e8e0d0"))
			_world.draw_colored_polygon(PackedVector2Array([r.position + Vector2(k * 0.1, k * 0.4), r.position + Vector2(k * 0.5, k * 0.08), r.position + Vector2(k * 0.9, k * 0.4)]), Color("#c84a3a"))
			for i: int in 3:
				_world.draw_rect(Rect2(r.position + Vector2(k * (0.22 + float(i) * 0.22), k * 0.48), Vector2(k * 0.1, k * 0.4)), Color("#b0a890"))
		"H":
			var hs: Dictionary = (st["houses"] as Dictionary).get(c, {"lvl": 0})
			if int(hs["lvl"]) == 0:
				_world.draw_rect(Rect2(r.position + Vector2(k * 0.18, k * 0.4), Vector2(k * 0.64, k * 0.48)), Color("#f0e0c8"))
				_world.draw_colored_polygon(PackedVector2Array([r.position + Vector2(k * 0.1, k * 0.42), r.position + Vector2(k * 0.5, k * 0.12), r.position + Vector2(k * 0.9, k * 0.42)]), Color("#d8603a"))
				_world.draw_rect(Rect2(r.position + Vector2(k * 0.42, k * 0.62), Vector2(k * 0.16, k * 0.26)), Color("#7a4a2a"))
			else:
				_world.draw_rect(Rect2(r.position + Vector2(k * 0.15, k * 0.08), Vector2(k * 0.7, k * 0.82)), Color("#c8b8e8"))
				for yy: int in 4:
					for xx: int in 2:
						_world.draw_rect(Rect2(r.position + Vector2(k * (0.25 + float(xx) * 0.3), k * (0.15 + float(yy) * 0.18)), Vector2(k * 0.18, k * 0.1)), Color("#5a7ab8"))
		"S":
			_world.draw_rect(Rect2(r.position + Vector2(k * 0.12, k * 0.3), Vector2(k * 0.76, k * 0.58)), Color("#f4f0e8"))
			for s: int in 4:
				_world.draw_rect(Rect2(r.position + Vector2(k * (0.12 + float(s) * 0.19), k * 0.22), Vector2(k * 0.095, k * 0.16)), Color("#3f8cff"))
			_world.draw_rect(Rect2(r.position + Vector2(k * 0.3, k * 0.55), Vector2(k * 0.4, k * 0.33)), Color("#9ad0ff"))
		"F":
			_world.draw_rect(Rect2(r.position + Vector2(k * 0.1, k * 0.4), Vector2(k * 0.8, k * 0.5)), Color("#8a8a92"))
			_world.draw_rect(Rect2(r.position + Vector2(k * 0.62, k * 0.12), Vector2(k * 0.14, k * 0.32)), Color("#6a6a72"))
			var sm: float = fmod(_t * 0.6 + float(c.x) * 0.3, 1.0)
			_world.draw_circle(r.position + Vector2(k * 0.69, k * (0.08 - sm * 0.3)), k * (0.08 + sm * 0.1), Color(0.8, 0.8, 0.8, 0.6 - sm * 0.5))
		"P":
			_world.draw_rect(r.grow(-k * 0.06), Color("#7ad06a"))
			_world.draw_circle(r.position + Vector2(k * 0.32, k * 0.35), k * 0.17, Color("#3f9a3a"))
			_world.draw_circle(r.position + Vector2(k * 0.68, k * 0.62), k * 0.15, Color("#3f9a3a"))
			_world.draw_circle(r.position + Vector2(k * 0.4, k * 0.72), k * 0.07, Color("#ff7aa0"))
	## Aviso: edificio sin carretera.
	if ch in ["H", "S", "F"] and not MapRules.on_road(st, c, _net) and fmod(_t, 1.0) < 0.6:
		_world.draw_circle(r.position + Vector2(k * 0.82, k * 0.18), k * 0.13, Color("#e04a4a"))


func _draw_world() -> void:
	if st.is_empty():
		return
	var w: int = int(st["w"])
	var h: int = int(st["h"])
	_net = MapRules.road_net(st)
	_world.draw_rect(Rect2(-100, -100, 920, 1500), Color("#4a8a3e"))
	_world.draw_rect(Rect2(_origin, Vector2(w, h) * _cell).grow(8.0), Color("#3a7034"))
	for y: int in h:
		for x: int in w:
			var r: Rect2 = Rect2(_origin + Vector2(x, y) * _cell, Vector2(_cell, _cell))
			_world.draw_rect(r, Color("#6aaa5a") if (x + y) % 2 == 0 else Color("#64a454"))
			_draw_cell(Vector2i(x, y), str(st["grid"][y][x]), r)
	for p: Dictionary in _pops:
		var a: float = clampf(float(p["t"]), 0.0, 1.0)
		var pos: Vector2 = (p["p"] as Vector2) + Vector2(0, -(1.0 - a) * 40.0)
		var txt: String = str(p["text"])
		var wd: float = _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		_world.draw_string(_font, pos + Vector2(-wd * 0.5 + 2, 2), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(0, 0, 0, 0.6 * a))
		_world.draw_string(_font, pos - Vector2(wd * 0.5, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, (p["col"] as Color) * Color(1, 1, 1, a))
