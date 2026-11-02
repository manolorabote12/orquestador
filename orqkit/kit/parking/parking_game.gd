extends Node2D
## Atasco de aparcamiento: toca cada coche para sacarlo; si tiene algo delante, choca y vuelve.
## Reglas, bot y analizador en parking_map.gd.
## 1 - Cada coche solo va hacia donde mira (la flecha del techo). Saca primero los que tapan.
## 2 - Cada choque quita una vida; sin vidas se repite el nivel. Sin choques, 3 estrellas.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const MapRules = preload("res://kit/parking/parking_map.gd")
const CAR_COLORS: Array[Color] = [Color("#e8483e"), Color("#3f8cff"), Color("#f2c84b"), Color("#56c46a"), Color("#a46ad9"),
	Color("#ff8a3a"), Color("#3fd0d0"), Color("#ff6fae"), Color("#f4f4f0"), Color("#5a6a8a")]
const AREA: Rect2 = Rect2(40, 200, 640, 860)

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
var _left_label: Label
var _hearts: HBoxContainer
var _toast: Label
var _toast_t: float = 0.0
var _cell: float = 80.0
var _origin: Vector2 = Vector2.ZERO
var _anims: Dictionary = {}
var _t: float = 0.0
var _decor: Array = []


func _ready() -> void:
	level = Kit.current_level()
	par = float(level.get("par", 0))
	RenderingServer.set_default_clear_color(Color("#3a3d44"))
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
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "parking", "cars": (st["cars"] as Dictionary).size()})


func bot_script() -> String:
	return "res://qa/parking_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(1.6, 0.9)


func wants_backdrop() -> bool:
	return false


func _reset() -> void:
	finished = false
	failed = false
	st = MapRules.new_state(level)
	coins_total = (st["cars"] as Dictionary).size()
	coins = 0
	_anims.clear()
	time_in_level = 0.0
	_layout()
	_refresh()


## 1 - Tamano de casilla para que quepa el aparcamiento con su carretera alrededor.
func _layout() -> void:
	var size: Vector2i = st["size"]
	_cell = minf(104.0, minf(AREA.size.x / (float(size.x) + 0.8), AREA.size.y / (float(size.y) + 0.8)))
	_origin = AREA.get_center() - Vector2(size) * _cell * 0.5
	## Decoracion fija: manchas de aceite y hojas en el asfalto (misma semilla, mismo sitio).
	_decor.clear()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(str(level.get("map", [])))
	for i: int in 6:
		_decor.append([Vector2(rng.randf_range(0.0, float(size.x)), rng.randf_range(0.0, float(size.y))), rng.randf_range(0.12, 0.3)])


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
	_hearts = HBoxContainer.new()
	_hearts.name = "Hearts"
	_hearts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_hearts)
	_left_label = Label.new()
	_left_label.name = "Left"
	_left_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_left_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left_label.add_theme_font_size_override("font_size", 34)
	_left_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_left_label.add_theme_constant_override("outline_size", 7)
	top.add_child(_left_label)
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


func _refresh() -> void:
	if _left_label == null or st.is_empty():
		return
	var total: int = (st["cars"] as Dictionary).size()
	var gone: int = (st["gone"] as Dictionary).size()
	_left_label.text = "%d / %d" % [gone, total]
	coins = gone
	var lives: int = int(st["lives"])
	if _hearts.get_child_count() != lives:
		for c: Node in _hearts.get_children():
			c.queue_free()
		for i: int in lives:
			_hearts.add_child(UiIcon.make("heart", Color("#ff5a6a"), 40.0))
	for i: int in _hearts.get_child_count():
		var h: Control = _hearts.get_child(i)
		h.modulate = Color(1, 1, 1, 0.25) if i >= lives - int(st["bumps"]) else Color.WHITE


func _toast_now(t: String) -> void:
	_toast.text = t
	_toast_t = 2.0


# ------------------------------------------------------------------ acciones

func can_act() -> bool:
	return not finished and is_inside_tree() and not get_tree().paused


func cell_center(c: Vector2i) -> Vector2:
	return _origin + (Vector2(c) + Vector2(0.5, 0.5)) * _cell


func car_at(p: Vector2) -> String:
	var c: Vector2i = Vector2i(floori((p.x - _origin.x) / _cell), floori((p.y - _origin.y) / _cell))
	for k: Variant in st["cars"]:
		if (st["gone"] as Dictionary).has(k):
			continue
		if (st["cars"][k]["cells"] as Array).has(c):
			return str(k)
	return ""


func tap_world(p: Vector2) -> void:
	if not can_act():
		return
	var k: String = car_at(p)
	if k != "":
		tap_car(k)


func tap_car(k: String) -> void:
	if _anims.has(k) and str(_anims[k]["type"]) == "bump":
		return
	var pr: Dictionary = MapRules.probe(st, k)
	if MapRules.tap(st, k):
		_anims[k] = {"type": "out", "t": 0.0}
		_sfx("coin")
	else:
		_anims[k] = {"type": "bump", "t": 0.0, "dist": float(pr["stop"]) + 0.22}
		if not fast:
			Audio.play("hurt", 0.05, -6.0)
			_toast_now(Kit.text("park_blocked", "\u00a1Hay algo delante!"))
	_refresh()
	if MapRules.won(st):
		_finish()
	elif MapRules.lost(st):
		_lose()


func _sfx(n: String) -> void:
	if not fast:
		Audio.play(n, 0.1, -6.0)


func bot_step() -> void:
	if not can_act():
		return
	var k: String = MapRules.bot_pick(st)
	if k != "":
		tap_car(k)


# ------------------------------------------------------------------ bucle

func _physics_process(delta: float) -> void:
	_t += delta
	var done: Array = []
	for k: Variant in _anims:
		_anims[k]["t"] = float(_anims[k]["t"]) + delta * (4.0 if fast else 1.0)
		if float(_anims[k]["t"]) > (1.2 if str(_anims[k]["type"]) == "out" else 0.4):
			done.append(k)
	for k: Variant in done:
		_anims.erase(k)
	if finished:
		_world.queue_redraw()
		return
	if fast and auto_retry:
		bot_step()
	time_in_level += delta * (4.0 if fast else 1.0)
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0:
			_toast.text = ""
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
	var score: int = coins_total * 100 - int(st["bumps"]) * 150 + maxi(0, 60 - int(time_in_level)) * 10
	var record: bool = Save.submit_best(level_id, maxi(0, score))
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "time": snappedf(time_in_level, 0.1), "deaths": deaths,
		"bumps": int(st["bumps"])})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": maxi(0, score), "record": record})
	await Ads.show_interstitial("level_end")


func stars_earned() -> int:
	if deaths > 0:
		return 1
	if int(st["bumps"]) == 0:
		return 3
	return 2 if int(st["bumps"]) == 1 else 1


func _lose() -> void:
	if finished:
		return
	finished = true
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "parking", "bumps": int(st["bumps"]), "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("park_lost", "\u00a1Demasiados golpes!"),
		Kit.text("park_fail_hint", "Mira hacia d\u00f3nde apunta cada coche y saca primero los que tapan la salida a los dem\u00e1s."))
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
	return {"pos": Vector2(float((st.get("gone", {}) as Dictionary).size()), float(st.get("bumps", 0))), "deaths": deaths, "coins": coins,
		"finished": finished, "failed": failed, "stomps": 0, "time": time_in_level, "bumps": int(st.get("bumps", 0))}


# ------------------------------------------------------------------ dibujo

## Un coche visto desde arriba, mirando a la derecha en su marco (largo en casillas).
static func draw_car(ci: CanvasItem, center: Vector2, angle: float, cells: int, cell: float, col: Color) -> void:
	var l: float = float(cells) * cell - cell * 0.18
	var w: float = cell * 0.7
	ci.draw_set_transform(center, angle, Vector2.ONE)
	var r: float = w * 0.28
	## Sombra y ruedas.
	ci.draw_rect(Rect2(Vector2(-l * 0.5 + 4.0, -w * 0.5 + 6.0), Vector2(l, w)), Color(0, 0, 0, 0.3))
	for sx: float in [-l * 0.32, l * 0.32]:
		for sy: float in [-w * 0.5, w * 0.5]:
			ci.draw_rect(Rect2(Vector2(sx - w * 0.16, sy - w * 0.09), Vector2(w * 0.32, w * 0.18)), Color("#1e1e22"))
	## Carroceria con esquinas redondas.
	ci.draw_rect(Rect2(Vector2(-l * 0.5 + r, -w * 0.5), Vector2(l - 2.0 * r, w)), col)
	ci.draw_rect(Rect2(Vector2(-l * 0.5, -w * 0.5 + r), Vector2(l, w - 2.0 * r)), col)
	for cx: float in [-l * 0.5 + r, l * 0.5 - r]:
		for cy: float in [-w * 0.5 + r, w * 0.5 - r]:
			ci.draw_circle(Vector2(cx, cy), r, col)
	## Techo, lunas y faros (el morro a la derecha).
	var roof: Rect2 = Rect2(Vector2(-l * 0.22, -w * 0.36), Vector2(l * 0.4, w * 0.72))
	ci.draw_rect(roof, col.lightened(0.18))
	ci.draw_rect(Rect2(Vector2(l * 0.18, -w * 0.34), Vector2(l * 0.1, w * 0.68)), Color("#2a3a52"))
	ci.draw_rect(Rect2(Vector2(-l * 0.33, -w * 0.32), Vector2(l * 0.08, w * 0.64)), Color("#2a3a52"))
	ci.draw_circle(Vector2(l * 0.5 - 4.0, -w * 0.3), w * 0.09, Color("#fff6b0"))
	ci.draw_circle(Vector2(l * 0.5 - 4.0, w * 0.3), w * 0.09, Color("#fff6b0"))
	ci.draw_rect(Rect2(Vector2(-l * 0.5, -w * 0.36), Vector2(4, w * 0.16)), Color("#d02a2a"))
	ci.draw_rect(Rect2(Vector2(-l * 0.5, w * 0.2), Vector2(4, w * 0.16)), Color("#d02a2a"))
	## Flecha del techo: hacia donde va.
	var a: float = w * 0.2
	ci.draw_colored_polygon(PackedVector2Array([roof.get_center() + Vector2(a, 0), roof.get_center() + Vector2(-a * 0.6, -a * 0.8),
		roof.get_center() + Vector2(-a * 0.6, a * 0.8)]), Color(1, 1, 1, 0.9))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_world() -> void:
	if st.is_empty():
		return
	var size: Vector2i = st["size"]
	var lot: Rect2 = Rect2(_origin, Vector2(size) * _cell)
	## Carretera alrededor con linea discontinua, bordillo y aparcamiento.
	_world.draw_rect(Rect2(-100, -100, 920, 1500), Color("#5d8a4a"))
	_world.draw_rect(lot.grow(_cell * 0.55), Color("#4a4d55"))
	var road: Rect2 = lot.grow(_cell * 0.28)
	var dash: float = _cell * 0.3
	var x: float = road.position.x
	while x < road.end.x:
		_world.draw_rect(Rect2(Vector2(x, road.position.y - 2.0), Vector2(dash, 4)), Color("#f2d24a"))
		_world.draw_rect(Rect2(Vector2(x, road.end.y - 2.0), Vector2(dash, 4)), Color("#f2d24a"))
		x += dash * 2.0
	var y: float = road.position.y
	while y < road.end.y:
		_world.draw_rect(Rect2(Vector2(road.position.x - 2.0, y), Vector2(4, dash)), Color("#f2d24a"))
		_world.draw_rect(Rect2(Vector2(road.end.x - 2.0, y), Vector2(4, dash)), Color("#f2d24a"))
		y += dash * 2.0
	_world.draw_rect(lot.grow(4.0), Color("#c8c8c0"))
	_world.draw_rect(lot, Color("#62656e"))
	for i: int in size.x + 1:
		_world.draw_line(lot.position + Vector2(float(i) * _cell, 0), lot.position + Vector2(float(i) * _cell, lot.size.y * 0.12), Color(1, 1, 1, 0.35), 2.0)
		_world.draw_line(lot.position + Vector2(float(i) * _cell, lot.size.y), lot.position + Vector2(float(i) * _cell, lot.size.y * 0.88), Color(1, 1, 1, 0.35), 2.0)
	for d: Array in _decor:
		_world.draw_circle(lot.position + (d[0] as Vector2) * _cell, float(d[1]) * _cell, Color(0, 0, 0, 0.12))
	## Obstaculos: arboles en maceta y conos.
	for c: Variant in st["walls"]:
		var p: Vector2 = cell_center(c)
		if (int((c as Vector2i).x) + int((c as Vector2i).y)) % 2 == 0:
			_world.draw_rect(Rect2(p - Vector2(_cell * 0.4, _cell * 0.4), Vector2(_cell * 0.8, _cell * 0.8)), Color("#8a6a4a"))
			_world.draw_circle(p, _cell * 0.36, Color("#3f8a3a"))
			_world.draw_circle(p + Vector2(-_cell * 0.1, -_cell * 0.1), _cell * 0.22, Color("#5aaa4a"))
		else:
			_world.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -_cell * 0.36), p + Vector2(_cell * 0.26, _cell * 0.3), p + Vector2(-_cell * 0.26, _cell * 0.3)]), Color("#ff7a2a"))
			_world.draw_rect(Rect2(p + Vector2(-_cell * 0.17, -_cell * 0.02), Vector2(_cell * 0.34, _cell * 0.08)), Color.WHITE)
			_world.draw_rect(Rect2(p + Vector2(-_cell * 0.32, _cell * 0.28), Vector2(_cell * 0.64, _cell * 0.08)), Color("#d05a1a"))
	## Coches (los que salen, por la carretera hasta fuera de la pantalla).
	var keys: Array = (st["cars"] as Dictionary).keys()
	keys.sort()
	for k: Variant in keys:
		var car: Dictionary = st["cars"][k]
		var gone: bool = (st["gone"] as Dictionary).has(k)
		if gone and not _anims.has(k):
			continue
		var cs: Array = car["cells"]
		var c: Vector2 = Vector2.ZERO
		for q: Vector2i in cs:
			c += cell_center(q)
		c /= float(cs.size())
		var d: Vector2 = Vector2(car["dir"])
		if _anims.has(k):
			var an: Dictionary = _anims[k]
			var t: float = float(an["t"])
			if str(an["type"]) == "out":
				c += d * (t * t * 1400.0 + t * 300.0)
			else:
				c += d * sin(clampf(t / 0.4, 0.0, 1.0) * PI) * float(an["dist"]) * _cell
		var col: Color = CAR_COLORS[(str(k).unicode_at(0) - 65) % CAR_COLORS.size()]
		draw_car(_world, c, d.angle(), cs.size(), _cell, col)
