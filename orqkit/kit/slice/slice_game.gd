extends Node2D
## Cortar fruta: desliza el dedo para cortar la fruta en el aire sin tocar las bombas.
## Reglas, simulacion, bot y analizador en slice_map.gd.
## 1 - El trazo del dedo deja una estela; cada fruta cortada se parte en dos y salpica zumo.
## 2 - Tres frutas o mas de un solo trazo = combo. Fruta que cae entera = una vida menos.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const MapRules = preload("res://kit/slice/slice_map.gd")
const FRUITS: Array[String] = ["sandia", "naranja", "manzana", "limon", "coco"]

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
var _score_label: Label
var _hearts: HBoxContainer
var _toast: Label
var _toast_t: float = 0.0
var _trail: Array[Dictionary] = []
var _halves: Array[Dictionary] = []
var _splats: Array[Dictionary] = []
var _pops: Array[Dictionary] = []
var _touching: bool = false
var _last: Vector2 = Vector2.ZERO
var _stroke_cuts: int = 0
var _boom_t: float = 0.0
var _bot_cd: float = 0.0
var _t: float = 0.0


func _ready() -> void:
	level = Kit.current_level()
	par = float(level.get("par", 0))
	RenderingServer.set_default_clear_color(Color("#3a2618"))
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
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "slice", "fruits": int(st["fruits"])})


func bot_script() -> String:
	return "res://qa/slice_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(5.0, 1.6)


func wants_backdrop() -> bool:
	return false


func _reset() -> void:
	finished = false
	failed = false
	st = MapRules.new_state(level)
	coins_total = int(st["fruits"])
	coins = 0
	time_in_level = 0.0
	_trail.clear()
	_halves.clear()
	_splats.clear()
	_pops.clear()
	_boom_t = 0.0
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
	top.add_child(UiIcon.make("star", Color("#ffd23f"), 40.0))
	_score_label = Label.new()
	_score_label.name = "Score"
	_score_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_score_label.add_theme_font_size_override("font_size", 38)
	_score_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_score_label.add_theme_constant_override("outline_size", 7)
	top.add_child(_score_label)
	_hearts = HBoxContainer.new()
	_hearts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_hearts)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)
	_toast = Label.new()
	_toast.name = "Toast"
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 40)
	_toast.add_theme_color_override("font_color", Color("#fff3c0"))
	_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_toast.add_theme_constant_override("outline_size", 8)
	col.add_child(_toast)


func _refresh() -> void:
	if _score_label == null or st.is_empty():
		return
	_score_label.text = "%d" % int(st["points"])
	coins = int(st["cut"])
	var lives: int = int(st["lives"])
	if _hearts.get_child_count() != lives:
		for c: Node in _hearts.get_children():
			c.queue_free()
		for i: int in lives:
			_hearts.add_child(UiIcon.make("heart", Color("#ff5a6a"), 38.0))
	for i: int in _hearts.get_child_count():
		(_hearts.get_child(i) as Control).modulate = Color(1, 1, 1, 0.25) if i >= lives - int(st["missed"]) else Color.WHITE


func _toast_now(t: String) -> void:
	_toast.text = t
	_toast_t = 1.0


# ------------------------------------------------------------------ acciones

func can_act() -> bool:
	return not finished and is_inside_tree() and not get_tree().paused


## Un trozo de trazo: corta, parte la fruta y salpica.
func cut_segment(a: Vector2, b: Vector2) -> void:
	if not can_act():
		return
	_trail.append({"p": b, "t": 0.18})
	var hit: Array = MapRules.slice(st, a, b)
	var dir: Vector2 = (b - a).normalized() if a.distance_to(b) > 1.0 else Vector2.RIGHT
	for it: Dictionary in hit:
		if it["kind"] == "B":
			_boom_t = 1.0
			_lose()
			return
		_stroke_cuts += 1
		var col: Color = _juice(it)
		var nrm: Vector2 = Vector2(-dir.y, dir.x)
		for s: float in [-1.0, 1.0]:
			_halves.append({"p": it["p"], "v": (it["v"] as Vector2) * 0.4 + nrm * s * 180.0, "rot": dir.angle(), "spin": s * 5.0,
				"side": s, "kind": it["kind"], "id": int(it["id"]), "t": 1.6})
		_splats.append({"p": it["p"], "col": col, "t": 2.5, "r": 40.0 + float(int(it["id"]) % 3) * 12.0})
		_sfx("coin")
	if _stroke_cuts >= 3 and not fast:
		_toast_now(Kit.text("slice_combo", "\u00a1Combo!") + " x%d" % _stroke_cuts)
	_refresh()


func _juice(it: Dictionary) -> Color:
	if it["kind"] == "G":
		return Color("#ffd23f")
	return [Color("#e8344a"), Color("#ff9a2a"), Color("#e8344a"), Color("#f2e04a"), Color("#f4f0e8")][int(it["id"]) % FRUITS.size()]


func _sfx(n: String) -> void:
	if not fast:
		Audio.play(n, 0.1, -8.0)


func bot_step() -> void:
	if not can_act():
		return
	var c: Array = MapRules.bot_cut(st)
	if not c.is_empty():
		_stroke_cuts = 0
		cut_segment(c[0], c[1])


# ------------------------------------------------------------------ bucle

func _physics_process(delta: float) -> void:
	_t += delta
	_boom_t = maxf(0.0, _boom_t - delta)
	for arr: Array in [_trail, _splats, _pops]:
		for p: Dictionary in arr:
			p["t"] = float(p["t"]) - delta
	_trail = _trail.filter(func(p: Dictionary) -> bool: return float(p["t"]) > 0.0)
	_splats = _splats.filter(func(p: Dictionary) -> bool: return float(p["t"]) > 0.0)
	_pops = _pops.filter(func(p: Dictionary) -> bool: return float(p["t"]) > 0.0)
	for hv: Dictionary in _halves:
		hv["v"] = (hv["v"] as Vector2) + Vector2(0, MapRules.GRAVITY) * delta
		hv["p"] = (hv["p"] as Vector2) + (hv["v"] as Vector2) * delta
		hv["rot"] = float(hv["rot"]) + float(hv["spin"]) * delta
		hv["t"] = float(hv["t"]) - delta
	_halves = _halves.filter(func(p: Dictionary) -> bool: return float(p["t"]) > 0.0)
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0:
			_toast.text = ""
	if finished:
		_world.queue_redraw()
		return
	var steps: int = 4 if fast else 1
	for k: int in steps:
		if fast and auto_retry:
			_bot_cd -= delta
			if _bot_cd <= 0.0:
				bot_step()
				_bot_cd = 0.22 / 4.0
		var missed: int = int(st["missed"])
		MapRules.step(st, delta)
		if int(st["missed"]) > missed and not fast:
			Audio.play("hurt", 0.05, -8.0)
		if finished:
			break
	time_in_level = float(st["time"])
	_refresh()
	if MapRules.lost(st):
		_lose()
	elif bool(st["won"]):
		_finish()
	_world.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()
		return
	var inv: Transform2D = get_canvas_transform().affine_inverse()
	if event is InputEventScreenTouch:
		var te: InputEventScreenTouch = event
		_touching = te.pressed
		_last = inv * te.position
		_stroke_cuts = 0
	elif event is InputEventScreenDrag and _touching:
		var p: Vector2 = inv * (event as InputEventScreenDrag).position
		cut_segment(_last, p)
		_last = p


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = int(st["points"]) * 50 + int(st["best_combo"]) * 40
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "time": snappedf(time_in_level, 0.1), "deaths": deaths,
		"missed": int(st["missed"])})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


func stars_earned() -> int:
	if deaths > 0:
		return 1
	return 3 if int(st["missed"]) == 0 else 2


func _lose() -> void:
	if finished:
		return
	finished = true
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "bomb" if bool(st["boom"]) else "missed", "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var title: String = Kit.text("slice_boom", "\u00a1Bomba!") if bool(st["boom"]) else Kit.text("slice_lost", "\u00a1Se escap\u00f3 la fruta!")
	var p: FailPanel = FailPanel.open(self, title,
		Kit.text("slice_fail_hint", "Corta la fruta cuando est\u00e1 arriba del todo, que va m\u00e1s lenta, y rodea las bombas."))
	p.closed.connect(retry)


## Segunda oportunidad (FailPanel, con anuncio): fuera las bombas que vuelan y una fruta de margen.
func revive() -> void:
	st["boom"] = false
	st["items"] = (st["items"] as Array).filter(func(it: Dictionary) -> bool: return str(it.get("kind", "")) != "B")
	st["missed"] = mini(int(st["missed"]), int(st["lives"]) - 1)
	_boom_t = 0.0
	finished = false
	failed = false
	_refresh()


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
	return {"pos": Vector2(float(st.get("cut", 0)), float(st.get("missed", 0))), "deaths": deaths, "coins": coins, "finished": finished,
		"failed": failed, "stomps": 0, "time": time_in_level, "missed": int(st.get("missed", 0)), "boom": bool(st.get("boom", false))}


# ------------------------------------------------------------------ dibujo

## Una fruta entera (o media, con side = -1/1) centrada en c.
static func draw_fruit(ci: CanvasItem, kind: String, id: int, c: Vector2, rot: float, side: float = 0.0) -> void:
	var f: String = "dorada" if kind == "G" else FRUITS[id % FRUITS.size()]
	var r: float = MapRules.R_FRUIT
	var skin: Color = {"sandia": Color("#2f9a3a"), "naranja": Color("#ff9a2a"), "manzana": Color("#d8283a"), "limon": Color("#f2e04a"),
		"coco": Color("#7a5232"), "dorada": Color("#ffcf3a")}[f]
	var flesh: Color = {"sandia": Color("#ff4a5a"), "naranja": Color("#ffc06a"), "manzana": Color("#fff0c8"), "limon": Color("#fff6a0"),
		"coco": Color("#f8f4ec"), "dorada": Color("#fff2a0")}[f]
	ci.draw_set_transform(c, rot, Vector2.ONE)
	if side == 0.0:
		ci.draw_circle(Vector2(4, 6), r, Color(0, 0, 0, 0.25))
		ci.draw_circle(Vector2.ZERO, r, skin)
		if f == "sandia":
			for k: int in 3:
				ci.draw_arc(Vector2.ZERO, r * (0.35 + 0.25 * float(k)), -0.9, 0.9, 10, skin.darkened(0.35), 5.0)
		ci.draw_circle(Vector2(-r * 0.35, -r * 0.35), r * 0.22, Color(1, 1, 1, 0.35))
		if f == "manzana" or f == "naranja":
			ci.draw_line(Vector2(0, -r), Vector2(4, -r - 12), Color("#5a3a1a"), 4.0)
			ci.draw_circle(Vector2(12, -r - 6), 7.0, Color("#5aaa3a"))
		if f == "dorada":
			ci.draw_arc(Vector2.ZERO, r - 4.0, 0.0, TAU, 24, Color(1, 1, 1, 0.6), 3.0)
	else:
		## Media fruta: semicirculo de piel con la pulpa a la vista.
		var pts: PackedVector2Array = PackedVector2Array()
		var pts2: PackedVector2Array = PackedVector2Array()
		for k: int in 13:
			var a: float = PI * float(k) / 12.0 + (0.0 if side > 0.0 else PI)
			pts.append(Vector2(cos(a), sin(a)) * r)
			pts2.append(Vector2(cos(a), sin(a)) * (r - 7.0))
		ci.draw_colored_polygon(pts, skin)
		ci.draw_colored_polygon(pts2, flesh)
		if f == "sandia":
			for k: int in 4:
				ci.draw_circle(Vector2(-18.0 + float(k) * 12.0, side * 14.0), 3.0, Color("#2a1a12"))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func draw_bomb(ci: CanvasItem, c: Vector2, t: float) -> void:
	var r: float = MapRules.R_BOMB
	ci.draw_circle(c + Vector2(4, 6), r, Color(0, 0, 0, 0.3))
	ci.draw_circle(c, r, Color("#22222a"))
	ci.draw_circle(c + Vector2(-r * 0.35, -r * 0.35), r * 0.2, Color(1, 1, 1, 0.25))
	ci.draw_rect(Rect2(c + Vector2(-8, -r - 8), Vector2(16, 12)), Color("#555560"))
	ci.draw_line(c + Vector2(0, -r - 8), c + Vector2(10, -r - 22), Color("#c8a060"), 3.0)
	var sp: float = 6.0 + 3.0 * sin(t * 30.0)
	ci.draw_circle(c + Vector2(10, -r - 24), sp, Color("#ffcf3a"))
	ci.draw_circle(c + Vector2(10, -r - 24), sp * 0.5, Color("#ffffff"))
	ci.draw_line(c + Vector2(-12, -6), c + Vector2(12, 6), Color("#e04a4a"), 4.0)
	ci.draw_line(c + Vector2(-12, 6), c + Vector2(12, -6), Color("#e04a4a"), 4.0)


func _draw_world() -> void:
	if st.is_empty():
		return
	## Tabla de madera con vetas.
	_world.draw_rect(Rect2(-100, -100, 920, 1500), Color("#7a4e2e"))
	for i: int in 9:
		var x: float = float(i) * 90.0
		_world.draw_rect(Rect2(x, -100, 88, 1500), Color("#86583a") if i % 2 == 0 else Color("#7f5334"))
		_world.draw_line(Vector2(x + 88, -100), Vector2(x + 88, 1400), Color("#5a361e"), 3.0)
		for k: int in 5:
			var y: float = fmod(float(i * 211 + k * 307), 1280.0)
			_world.draw_arc(Vector2(x + 44, y), 18.0 + float(k % 3) * 6.0, 0.4, 2.6, 8, Color(0, 0, 0, 0.08), 2.0)
	for s: Dictionary in _splats:
		var a: float = clampf(float(s["t"]) / 2.5, 0.0, 1.0)
		var col: Color = s["col"]
		_world.draw_circle(s["p"], float(s["r"]), Color(col.r, col.g, col.b, 0.45 * a))
		for k: int in 5:
			var ang: float = float(k) * 1.3 + float(s["r"])
			_world.draw_circle((s["p"] as Vector2) + Vector2(cos(ang), sin(ang)) * float(s["r"]) * 1.2, 8.0, Color(col.r, col.g, col.b, 0.4 * a))
	for it: Dictionary in st["items"]:
		if it["cut"] or float(it["delay"]) > 0.0:
			continue
		if it["kind"] == "B":
			draw_bomb(_world, it["p"], _t)
		else:
			draw_fruit(_world, it["kind"], int(it["id"]), it["p"], _t * float(it["spin"]))
	for hv: Dictionary in _halves:
		draw_fruit(_world, hv["kind"], int(hv["id"]), hv["p"], float(hv["rot"]), float(hv["side"]))
	## Estela del corte.
	if _trail.size() >= 2:
		for i: int in range(1, _trail.size()):
			var a2: float = clampf(float(_trail[i]["t"]) / 0.18, 0.0, 1.0)
			_world.draw_line(_trail[i - 1]["p"], _trail[i]["p"], Color(1, 1, 1, 0.85 * a2), 10.0 * a2 + 2.0)
	if _boom_t > 0.0:
		_world.draw_rect(Rect2(-100, -100, 920, 1500), Color(1, 1, 1, _boom_t * 0.8))
