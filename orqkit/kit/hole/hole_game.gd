extends Node2D
## Agujero: un agujero negro que se traga la ciudad. Arrastra el dedo para moverlo.
## Reglas, simulacion, bot y analizador en hole_map.gd.
## 1 - Solo cabe lo que es mas pequeno que el agujero: empieza por conos y gente, luego coches,
##     casas y por fin edificios. Lo que te comes cae dentro girando.
## 2 - La camara se aleja segun crece. Gana al llegar a la meta antes de que acabe el tiempo.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const REVIVE_SECS: float = 15.0
const MapRules = preload("res://kit/hole/hole_map.gd")
const COLORS: Dictionary = {"c": Color("#ff7a2a"), "p": Color("#f1c9a0"), "b": Color("#8a5a32"), "f": Color("#5a6a7a"), "t": Color("#3f9a3a"),
	"a": Color("#e8483e"), "k": Color("#ffcf3a"), "h": Color("#d98a5a"), "E": Color("#7a8aa8")}

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
var _bar: ColorRect
var _bar_back: ColorRect
var _time_label: Label
var _pct_label: Label
var _touch: Vector2 = Vector2.INF
var _drag: Vector2 = Vector2.ZERO
var _falling: Array[Dictionary] = []
var _bot_dir: Vector2 = Vector2.ZERO
var _bot_cd: float = 0.0
var _t: float = 0.0


func _ready() -> void:
	level = Kit.current_level()
	par = float(level.get("par", 0))
	RenderingServer.set_default_clear_color(Color("#4a8a4a"))
	_font = UI.theme.get_font("font", "Label") if UI.theme != null else ThemeDB.fallback_font
	_world = Node2D.new()
	_world.name = "World"
	_world.draw.connect(_draw_world)
	add_child(_world)
	_camera = Camera2D.new()
	add_child(_camera)
	_camera.make_current()
	_build_hud()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "hole", "objects": (st["objs"] as Array).size()})


func bot_script() -> String:
	return "res://qa/hole_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(9.0, 4.0)


func wants_backdrop() -> bool:
	return false


func _reset() -> void:
	finished = false
	failed = false
	st = MapRules.new_state(level)
	coins_total = 100
	coins = 0
	time_in_level = 0.0
	_falling.clear()
	_touch = Vector2.INF
	_drag = Vector2.ZERO
	_camera.position = st["pos"]
	_camera.zoom = Vector2.ONE * 1.3
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
	safe.add_child(col)
	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 10)
	col.add_child(top)
	_pct_label = Label.new()
	_pct_label.name = "Pct"
	_pct_label.add_theme_font_size_override("font_size", 34)
	_pct_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_pct_label.add_theme_constant_override("outline_size", 7)
	top.add_child(_pct_label)
	var bar: Control = Control.new()
	bar.custom_minimum_size = Vector2(0, 30)
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
	_bar.color = Color("#a46ad9")
	_bar.position = Vector2(3, 3)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(_bar)
	_time_label = Label.new()
	_time_label.name = "Time"
	_time_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_time_label.add_theme_constant_override("outline_size", 6)
	top.add_child(_time_label)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)


func _refresh() -> void:
	if _pct_label == null or st.is_empty():
		return
	var goal: float = maxf(0.01, float(st["goal"]))
	var f: float = clampf(MapRules.progress(st) / goal, 0.0, 1.0)
	coins = int(round(f * 100.0))
	_pct_label.text = "%d%%" % coins
	_bar.size = Vector2(maxf(0.0, (_bar_back.size.x - 6.0) * f), _bar_back.size.y - 6.0)
	var left: int = maxi(0, int(ceil(float(st["seconds"]) - float(st["time"]))))
	_time_label.text = "%d:%02d" % [left / 60, left % 60]


# ------------------------------------------------------------------ acciones

func can_act() -> bool:
	return not finished and is_inside_tree() and not get_tree().paused


func bot_step() -> void:
	_bot_dir = MapRules.bot_dir(st) * 0.9


# ------------------------------------------------------------------ bucle

func _physics_process(delta: float) -> void:
	_t += delta
	for fo: Dictionary in _falling:
		fo["t"] = float(fo["t"]) - delta
	_falling = _falling.filter(func(fo: Dictionary) -> bool: return float(fo["t"]) > 0.0)
	if finished:
		_world.queue_redraw()
		return
	var dir: Vector2 = _drag / 90.0 if _touch != Vector2.INF else Vector2.ZERO
	if auto_retry:
		_bot_cd -= delta * (4.0 if fast else 1.0)
		if _bot_cd <= 0.0:
			bot_step()
			_bot_cd = 0.3
		dir = _bot_dir
	var steps: int = 4 if fast else 1
	for k: int in steps:
		for o: Dictionary in MapRules.step(st, dir, delta):
			_falling.append({"o": o, "t": 0.45})
			if not fast:
				Audio.play("coin", 0.15, -14.0)
	time_in_level = float(st["time"])
	## Camara: sigue al agujero y se aleja cuando crece.
	var z: float = clampf(60.0 / float(st["r"]) * 1.3, 0.55, 1.3)
	## Sin alejarse mas que el ancho de la ciudad (13 nov: la ciudad quedaba en una columna estrecha
	## con hierba vacia a los lados).
	var city: Vector2 = st["size"]
	z = maxf(z, get_viewport_rect().size.x / maxf(1.0, city.x + 40.0))
	_camera.zoom = _camera.zoom.lerp(Vector2(z, z), minf(1.0, delta * 2.0))
	_camera.position = _camera.position.lerp(st["pos"], minf(1.0, delta * 8.0))
	## La camara no ensena lo que hay fuera de la ciudad por los lados.
	var half_w: float = get_viewport_rect().size.x * 0.5 / _camera.zoom.x
	_camera.position.x = clampf(_camera.position.x, minf(half_w - 20.0, city.x * 0.5), maxf(city.x - half_w + 20.0, city.x * 0.5))
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
	if event is InputEventScreenTouch:
		var te: InputEventScreenTouch = event
		_touch = te.position if te.pressed else Vector2.INF
		_drag = Vector2.ZERO
	elif event is InputEventScreenDrag and _touch != Vector2.INF:
		_drag = ((event as InputEventScreenDrag).position - _touch).limit_length(90.0)


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	coins = coins_total
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = int(st["eaten"]) * 10 + maxi(0, int(float(st["seconds"]) - time_in_level)) * 20
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
	QA.log_event("death", {"cause": "time", "progress": snappedf(MapRules.progress(st), 0.01), "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("hole_lost", "\u00a1Se acab\u00f3 el tiempo!"),
		Kit.text("hole_fail_hint", "Al principio come cosas peque\u00f1as que est\u00e9n juntas: as\u00ed creces r\u00e1pido y luego caben las grandes."))
	p.closed.connect(retry)


## Segunda oportunidad (FailPanel, con anuncio): 15 segundos mas para tragartelo todo.
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
	return {"pos": st.get("pos", Vector2.ZERO), "deaths": deaths, "coins": coins, "finished": finished, "failed": failed, "stomps": 0,
		"time": time_in_level, "progress": MapRules.progress(st) if not st.is_empty() else 0.0}


# ------------------------------------------------------------------ dibujo

## Un objeto visto desde arriba, centrado en c, con escala k (para cuando cae).
static func draw_obj(ci: CanvasItem, kind: String, c: Vector2, r: float, k: float, ang: float) -> void:
	var col: Color = COLORS.get(kind, Color.GRAY)
	ci.draw_set_transform(c, ang, Vector2(k, k))
	match kind:
		"c":
			ci.draw_colored_polygon(PackedVector2Array([Vector2(0, -r), Vector2(r * 0.8, r * 0.8), Vector2(-r * 0.8, r * 0.8)]), col)
			ci.draw_rect(Rect2(Vector2(-r * 0.5, -r * 0.05), Vector2(r, r * 0.25)), Color.WHITE)
		"p":
			ci.draw_circle(Vector2(0, r * 0.3), r * 0.8, [Color("#3f8cff"), Color("#e84a8a"), Color("#56c46a")][int(absf(c.x + c.y)) % 3])
			ci.draw_circle(Vector2(0, -r * 0.2), r * 0.55, col)
		"b":
			ci.draw_rect(Rect2(Vector2(-r, -r * 0.4), Vector2(r * 2.0, r * 0.8)), col)
			ci.draw_rect(Rect2(Vector2(-r, -r * 0.4), Vector2(r * 2.0, r * 0.2)), col.darkened(0.3))
		"f":
			ci.draw_circle(Vector2.ZERO, r * 0.4, col)
			ci.draw_circle(Vector2(0, -r * 0.5), r * 0.55, Color("#fff3a0"))
		"t":
			ci.draw_circle(Vector2(3, 4), r, Color(0, 0, 0, 0.2))
			ci.draw_circle(Vector2.ZERO, r, col)
			ci.draw_circle(Vector2(-r * 0.3, -r * 0.3), r * 0.55, col.lightened(0.2))
		"a":
			ci.draw_rect(Rect2(Vector2(-r, -r * 0.5), Vector2(r * 2.0, r)), col)
			ci.draw_rect(Rect2(Vector2(-r * 0.3, -r * 0.42), Vector2(r * 0.7, r * 0.84)), Color("#2a3a52"))
			ci.draw_rect(Rect2(Vector2(-r * 0.2, -r * 0.36), Vector2(r * 0.5, r * 0.72)), col.lightened(0.2))
		"k":
			ci.draw_rect(Rect2(Vector2(-r * 0.8, -r * 0.8), Vector2(r * 1.6, r * 1.6)), Color("#f4f0e8"))
			for s: int in 4:
				ci.draw_rect(Rect2(Vector2(-r * 0.8 + float(s) * r * 0.4, -r * 0.8), Vector2(r * 0.2, r * 1.6)), col)
		"h":
			ci.draw_rect(Rect2(Vector2(-r * 0.78, -r * 0.78), Vector2(r * 1.56, r * 1.56)), Color("#f0e0c8"))
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-r * 0.85, -r * 0.85), Vector2(r * 0.85, -r * 0.85), Vector2(0, 0)]), col)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-r * 0.85, r * 0.85), Vector2(r * 0.85, r * 0.85), Vector2(0, 0)]), col.darkened(0.15))
		"E":
			ci.draw_rect(Rect2(Vector2(-r * 0.75 + 6, -r * 0.75 + 8), Vector2(r * 1.5, r * 1.5)), Color(0, 0, 0, 0.25))
			ci.draw_rect(Rect2(Vector2(-r * 0.75, -r * 0.75), Vector2(r * 1.5, r * 1.5)), col)
			for yy: int in 3:
				for xx: int in 3:
					ci.draw_rect(Rect2(Vector2(-r * 0.6 + float(xx) * r * 0.45, -r * 0.6 + float(yy) * r * 0.45), Vector2(r * 0.3, r * 0.3)), Color("#bcd8f0"))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_world() -> void:
	if st.is_empty():
		return
	var size: Vector2 = st["size"]
	var cell: float = MapRules.CELL
	## Calles, aceras y cesped (mismo trazado que el generador: calle cada 5 casillas).
	_world.draw_rect(Rect2(Vector2(-400, -400), size + Vector2(800, 800)), Color("#3a6a3a"))
	_world.draw_rect(Rect2(Vector2.ZERO, size), Color("#6aaa5a"))
	var cols: int = int(size.x / cell)
	var rows: int = int(size.y / cell)
	for y: int in rows:
		for x: int in cols:
			var r: Rect2 = Rect2(Vector2(x, y) * cell, Vector2(cell, cell))
			if x % 5 == 0 or y % 5 == 0:
				_world.draw_rect(r, Color("#55585f"))
				if x % 5 == 0 and y % 5 != 0:
					_world.draw_rect(Rect2(r.position + Vector2(cell * 0.47, cell * 0.2), Vector2(cell * 0.06, cell * 0.6)), Color("#f2d24a"))
				elif y % 5 == 0 and x % 5 != 0:
					_world.draw_rect(Rect2(r.position + Vector2(cell * 0.2, cell * 0.47), Vector2(cell * 0.6, cell * 0.06)), Color("#f2d24a"))
			elif x % 5 in [1, 4] or y % 5 in [1, 4]:
				_world.draw_rect(r, Color("#c8c4b8"))
	## Objetos que quedan.
	var hp: Vector2 = st["pos"]
	var hr: float = float(st["r"])
	for o: Dictionary in st["objs"]:
		if o["eaten"]:
			continue
		draw_obj(_world, str(o["k"]), o["p"], float(o["r"]), 1.0, 0.0)
	## El agujero: negro con borde de color y un brillo que gira.
	_world.draw_circle(hp, hr + 6.0, Color("#a46ad9"))
	_world.draw_circle(hp, hr, Color("#0a0a12"))
	_world.draw_arc(hp, hr * 0.8, _t * 2.0, _t * 2.0 + 1.6, 16, Color(0.6, 0.4, 0.9, 0.35), 4.0)
	## Lo que cae: se encoge y gira hacia el centro.
	for fo: Dictionary in _falling:
		var o2: Dictionary = fo["o"]
		var f: float = clampf(float(fo["t"]) / 0.45, 0.0, 1.0)
		draw_obj(_world, str(o2["k"]), hp.lerp(o2["p"], f), float(o2["r"]), f, (1.0 - f) * 4.0)
