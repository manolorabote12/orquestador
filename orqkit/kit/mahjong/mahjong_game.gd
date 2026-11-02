extends Node2D
## Mahjong solitario: quita parejas de fichas libres con el mismo dibujo hasta vaciar el tablero.
## Reglas, reparto y bot en mahjong_map.gd.
## 1 - Toca una ficha libre (sin nada encima y con un lado abierto) y luego otra igual.
## 2 - Las fichas tapadas se ven mas oscuras. Pista: ilumina una pareja. Barajar: reparte otra vez
##     los dibujos que quedan (pocas veces por nivel). Sin parejas y sin barajadas, se pierde.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const MapRules = preload("res://kit/mahjong/mahjong_map.gd")
const TW: float = 72.0
const TH: float = 92.0
const LAYER: Vector2 = Vector2(-9.0, -12.0)
const FACE_COLORS: Array[Color] = [Color("#d6403a"), Color("#2f9a52"), Color("#2f6fd0"), Color("#d9a21a")]
const AREA: Rect2 = Rect2(16, 176, 688, 900)

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
var selected: int = -1
var hints_used: int = 0

var _font: Font
var _world: Node2D
var _camera: Camera2D
var _pairs_label: Label
var _time_label: Label
var _toast: Label
var _toast_t: float = 0.0
var _hint_btn: Button
var _shuffle_btn: Button
var _hint: Array = []
var _hint_t: float = 0.0
var _shake: int = -1
var _shake_t: float = 0.0
var _pops: Array[Dictionary] = []
var _t: float = 0.0
var _k: float = 1.0
var _origin: Vector2 = Vector2.ZERO


func _ready() -> void:
	level = Kit.current_level()
	par = float(level.get("par", 0))
	RenderingServer.set_default_clear_color(Color("#1f4a3a"))
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
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "mahjong", "tiles": (st["tiles"] as Array).size()})


func bot_script() -> String:
	return "res://qa/mahjong_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(3.0, 2.0)


## Fichas claras: sin el brillo del etalonaje (las quemaria).
func wants_grade() -> bool:
	return false


func _reset() -> void:
	finished = false
	failed = false
	st = MapRules.new_state(level)
	coins_total = (st["tiles"] as Array).size() / 2
	coins = 0
	selected = -1
	hints_used = 0
	_hint = []
	_pops.clear()
	time_in_level = 0.0
	_layout()
	_refresh()


## 1 - Escala y posicion del tablero para que quepa entero en la zona de juego.
func _layout() -> void:
	var cols: int = 1
	var rows: int = 1
	var top: int = 0
	for t: Dictionary in st["tiles"]:
		cols = maxi(cols, int(t["x"]) + 1)
		rows = maxi(rows, int(t["y"]) + 1)
		top = maxi(top, int(t["z"]))
	var w: float = float(cols) * TW + float(top) * absf(LAYER.x) + 8.0
	var h: float = float(rows) * TH + float(top) * absf(LAYER.y) + 8.0
	_k = minf(1.25, minf(AREA.size.x / w, AREA.size.y / h))
	var size: Vector2 = Vector2(float(cols) * TW, float(rows) * TH) * _k
	_origin = AREA.get_center() - size * 0.5 + Vector2(float(top) * absf(LAYER.x), float(top) * absf(LAYER.y)) * _k * 0.5


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
	top.add_child(UiIcon.make("grid", Color("#fff3c0"), 40.0))
	_pairs_label = Label.new()
	_pairs_label.name = "Pairs"
	_pairs_label.add_theme_font_size_override("font_size", 34)
	_pairs_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_pairs_label.add_theme_constant_override("outline_size", 7)
	_pairs_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_pairs_label)
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
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(spacer)
	var bottom: HBoxContainer = HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 24)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(bottom)
	_hint_btn = UI.make_button(Kit.text("mj_hint", "Pista"))
	_hint_btn.name = "BtnHint"
	_hint_btn.custom_minimum_size = Vector2(250, 88)
	_hint_btn.pressed.connect(use_hint)
	bottom.add_child(_hint_btn)
	_shuffle_btn = UI.make_button("")
	_shuffle_btn.name = "BtnShuffle"
	_shuffle_btn.custom_minimum_size = Vector2(250, 88)
	_shuffle_btn.pressed.connect(use_shuffle)
	bottom.add_child(_shuffle_btn)


func _refresh() -> void:
	if _pairs_label == null or st.is_empty():
		return
	_pairs_label.text = "%d" % (int(st["left"]) / 2)
	var s: int = int(time_in_level)
	_time_label.text = "%d:%02d" % [s / 60, s % 60]
	_shuffle_btn.text = "%s (%d)" % [Kit.text("mj_shuffle", "Barajar"), int(st["shuffles"])]
	_shuffle_btn.disabled = int(st["shuffles"]) <= 0
	coins = coins_total - int(st["left"]) / 2


func _toast_now(t: String) -> void:
	_toast.text = t
	_toast_t = 2.2


# ------------------------------------------------------------------ acciones

func can_act() -> bool:
	return not finished and is_inside_tree() and not get_tree().paused


func tile_rect(i: int) -> Rect2:
	var t: Dictionary = st["tiles"][i]
	var p: Vector2 = Vector2(float(t["x"]) * TW, float(t["y"]) * TH) + LAYER * float(t["z"])
	return Rect2(_origin + p * _k, Vector2(TW, TH) * _k)


## La ficha de arriba del todo en ese punto (o -1).
func tile_at(p: Vector2) -> int:
	var tiles: Array = st["tiles"]
	for i: int in range(tiles.size() - 1, -1, -1):
		if st["alive"][i] and tile_rect(i).has_point(p):
			return i
	return -1


func tap_world(p: Vector2) -> void:
	if not can_act():
		return
	var i: int = tile_at(p)
	if i < 0:
		selected = -1
		return
	tap_tile(i)


func tap_tile(i: int) -> void:
	var occ: Dictionary = MapRules.occupancy(st["tiles"], st["alive"])
	if not MapRules.is_free(st["tiles"], occ, i):
		_shake = i
		_shake_t = 0.3
		if not fast:
			_toast_now(Kit.text("mj_blocked", "Esa ficha est\u00e1 bloqueada"))
			Audio.play("hurt", 0.05, -10.0)
		return
	if selected < 0 or selected == i:
		selected = -1 if selected == i else i
		_sfx("click")
		return
	var a: int = selected
	if MapRules.match_pair(st, a, i):
		selected = -1
		_hint = []
		for j: int in [a, i]:
			_pops.append({"rect": tile_rect(j), "face": int(st["faces"][j]), "t": 0.35})
		_sfx("coin")
		_after_match()
	else:
		selected = i
		_sfx("click")


func _after_match() -> void:
	_refresh()
	if int(st["left"]) <= 0:
		_finish()
		return
	if MapRules.hint(st).is_empty():
		if MapRules.shuffle(st):
			if not fast:
				_toast_now(Kit.text("mj_shuffled", "No quedan parejas: barajo las fichas"))
			_refresh()
			coins = coins_total - int(st["left"]) / 2
		else:
			_lose()


func use_hint() -> void:
	if not can_act():
		return
	_hint = MapRules.hint(st)
	_hint_t = 2.5
	hints_used += 1


func use_shuffle() -> void:
	if not can_act():
		return
	if MapRules.shuffle(st):
		selected = -1
		_hint = []
		_sfx("click")
		_refresh()


func _sfx(n: String) -> void:
	if not fast:
		Audio.play(n, 0.1, -6.0)


## Una jugada del bot: elige las dos fichas de la siguiente pareja.
func bot_step() -> void:
	if not can_act():
		return
	var p: Array = MapRules.bot_pick(st)
	if p.is_empty():
		if not MapRules.shuffle(st):
			_lose()
		return
	selected = -1
	tap_tile(int(p[0]))
	tap_tile(int(p[1]))


# ------------------------------------------------------------------ bucle

func _physics_process(delta: float) -> void:
	if finished:
		return
	if fast and auto_retry:
		bot_step()
	time_in_level += delta * (4.0 if fast else 1.0)
	_t += delta
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0:
			_toast.text = ""
	_hint_t = maxf(0.0, _hint_t - delta)
	_shake_t = maxf(0.0, _shake_t - delta)
	var keep: Array[Dictionary] = []
	for p: Dictionary in _pops:
		p["t"] = float(p["t"]) - delta
		if float(p["t"]) > 0.0:
			keep.append(p)
	_pops = keep
	_refresh()
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
	coins = coins_total
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = coins_total * 100 + maxi(0, int(par * 1.4 - time_in_level)) * 20 - hints_used * 50
	var record: bool = Save.submit_best(level_id, maxi(0, score))
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "time": snappedf(time_in_level, 0.1), "deaths": deaths,
		"hints": hints_used})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": maxi(0, score), "record": record})
	await Ads.show_interstitial("level_end")


func stars_earned() -> int:
	if deaths > 0:
		return 1
	if hints_used <= 1 and (par <= 0.0 or time_in_level <= par * 1.4):
		return 3
	return 2


func _lose() -> void:
	if finished:
		return
	finished = true
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "mahjong", "left": int(st["left"]), "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("mj_lost", "\u00a1No quedan parejas!"),
		Kit.text("mj_fail_hint", "Quita antes las fichas de arriba y las de los extremos de las filas largas."))
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
	return {"pos": Vector2(float(st.get("left", 0)), float(st.get("moves", 0))), "deaths": deaths, "coins": coins, "finished": finished,
		"failed": failed, "stomps": 0, "time": time_in_level, "left": int(st.get("left", 0)), "shuffles": int(st.get("shuffles", 0))}


# ------------------------------------------------------------------ dibujo

## Dibujo de una ficha: 6 formas x 4 colores.
static func draw_face(ci: CanvasItem, f: int, c: Vector2, s: float) -> void:
	var col: Color = FACE_COLORS[(f + f / 6) % FACE_COLORS.size()]
	var dark: Color = col.darkened(0.35)
	match f % 6:
		0:
			ci.draw_circle(c, 22.0 * s, col)
			ci.draw_circle(c, 15.0 * s, Color("#fbf6e6"))
			ci.draw_circle(c, 8.0 * s, col)
			ci.draw_arc(c, 22.0 * s, 0.0, TAU, 24, dark, 2.0 * s)
		1:
			var pts: PackedVector2Array = PackedVector2Array()
			for k: int in 10:
				var r: float = (24.0 if k % 2 == 0 else 10.0) * s
				var a: float = -PI * 0.5 + float(k) * PI / 5.0
				pts.append(c + Vector2(cos(a), sin(a)) * r)
			ci.draw_colored_polygon(pts, col)
		2:
			ci.draw_circle(c + Vector2(-10, -6) * s, 12.0 * s, col)
			ci.draw_circle(c + Vector2(10, -6) * s, 12.0 * s, col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-21.5, -2) * s, c + Vector2(21.5, -2) * s, c + Vector2(0, 22) * s]), col)
		3:
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -25) * s, c + Vector2(17, 0) * s, c + Vector2(0, 25) * s, c + Vector2(-17, 0) * s]), col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -12) * s, c + Vector2(8, 0) * s, c + Vector2(0, 12) * s, c + Vector2(-8, 0) * s]), col.lightened(0.45))
		4:
			for k: int in 5:
				var a2: float = -PI * 0.5 + float(k) * TAU / 5.0
				ci.draw_circle(c + Vector2(cos(a2), sin(a2)) * 12.0 * s, 9.0 * s, col)
			ci.draw_circle(c, 7.0 * s, Color("#f5d04a") if col != FACE_COLORS[3] else Color("#d6403a"))
		5:
			for k: int in 3:
				var y: float = (-16.0 + float(k) * 16.0) * s
				ci.draw_rect(Rect2(c + Vector2(-20 * s, y - 4.0 * s), Vector2(40, 8) * s), col)
				ci.draw_circle(c + Vector2(-20 * s, y), 4.0 * s, dark)
				ci.draw_circle(c + Vector2(20 * s, y), 4.0 * s, dark)


func _draw_tile(i: int, r: Rect2, face: int, free: bool, alpha: float = 1.0) -> void:
	var depth: Vector2 = Vector2(5, 6) * _k
	_world.draw_rect(Rect2(r.position + depth + Vector2(3, 3) * _k, r.size), Color(0, 0, 0, 0.25 * alpha))
	_world.draw_rect(Rect2(r.position + depth, r.size), Color("#b89c6a").darkened(0.1) * Color(1, 1, 1, alpha))
	_world.draw_rect(Rect2(r.position + depth * 0.5, r.size), Color("#d8c8a0") * Color(1, 1, 1, alpha))
	var z: int = int(st["tiles"][i]["z"]) if i >= 0 else 0
	_world.draw_rect(r, Color("#fbf6e6").lerp(Color("#fff0c8"), minf(1.0, float(z) * 0.25)) * Color(1, 1, 1, alpha))
	_world.draw_rect(Rect2(r.position, Vector2(r.size.x, 5.0 * _k)), Color(1, 1, 1, 0.7 * alpha))
	_world.draw_rect(r, Color("#9a8a6a") * Color(1, 1, 1, alpha), false, 1.5)
	draw_face(_world, face, r.get_center(), _k * 1.05)
	if not free:
		_world.draw_rect(r, Color(0.1, 0.12, 0.1, 0.32 * alpha))
	if i == selected:
		_world.draw_rect(r.grow(2.0), Color("#ffd23f"), false, 5.0)
	if _hint_t > 0.0 and _hint.has(i):
		_world.draw_rect(r.grow(3.0), Color(0.3, 0.9, 1.0, 0.5 + 0.5 * sin(_t * 9.0)), false, 5.0)


func _draw_world() -> void:
	if st.is_empty():
		return
	## Mesa de fieltro con un marco de madera debajo del tablero.
	var tiles: Array = st["tiles"]
	if tiles.is_empty():
		return
	var bounds: Rect2 = tile_rect(0)
	for i: int in tiles.size():
		bounds = bounds.merge(tile_rect(i))
	_world.draw_rect(bounds.grow(26.0), Color(0, 0, 0, 0.28))
	_world.draw_rect(bounds.grow(20.0), Color("#6a4226"))
	_world.draw_rect(bounds.grow(12.0), Color("#24614a"))
	_world.draw_rect(bounds.grow(12.0), Color("#3a8a68"), false, 2.0)
	var occ: Dictionary = MapRules.occupancy(tiles, st["alive"])
	for i: int in tiles.size():
		if not st["alive"][i]:
			continue
		var r: Rect2 = tile_rect(i)
		if i == _shake and _shake_t > 0.0:
			r.position.x += sin(_shake_t * 60.0) * 5.0
		if i == selected:
			r.position.y -= 4.0
		_draw_tile(i, r, int(st["faces"][i]), MapRules.is_free(tiles, occ, i))
	for p: Dictionary in _pops:
		var f: float = float(p["t"]) / 0.35
		var r2: Rect2 = p["rect"]
		var c: Vector2 = r2.get_center() + Vector2(0, -(1.0 - f) * 40.0)
		_draw_tile(-1, Rect2(c - r2.size * 0.5, r2.size), int(p["face"]), true, f)
