extends Node2D
## Solitario clasico: toca una carta y va sola a su mejor sitio (base primero, luego columna).
## Toca el mazo para robar. Reglas, buscador de solucion, bot y analizador en klondike_map.gd.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const MapRules = preload("res://kit/klondike/klondike_map.gd")
const CW: float = 92.0
const CH: float = 128.0
const GAP: float = 100.0
const X0: float = 360.0 - 3.0 * GAP - CW * 0.5
const TOP_Y: float = 190.0
const TAB_Y: float = 360.0
const RANKS: Array[String] = ["", "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]

var level: Dictionary = {}
var st: Dictionary = {}
var finished: bool = false
var failed: bool = false
var deaths: int = 0
var time_in_level: float = 0.0
var coins: int = 0
var coins_total: int = 52
var fast: bool = false
var auto_retry: bool = false
var result_panel: ResultPanel
var par: float = 0.0

var _font: Font
var _world: Node2D
## Mesa y dorso de las cartas con los colores del juego, y el protagonista mirando la partida (13 nov:
## todos los solitarios eran el mismo tapete verde con dorso azul).
var _felt: Color = Color("#1e6a3a")
var _back: Color = Color("#2f5ad8")
var _emblem: Texture2D
var _camera: Camera2D
var _info: Label
var _plan: Array = []
var _shake: Vector2i = Vector2i(-1, -1)
var _shake_t: float = 0.0
var _t: float = 0.0
var _bot_cd: float = 0.0


func _ready() -> void:
	level = Kit.current_level()
	par = float(level.get("par", 330))
	RenderingServer.set_default_clear_color(Color("#1e6a3a").lerp(Kit.color("solid", Color("#1e6a3a")).darkened(0.35), 0.45))
	_font = UI.theme.get_font("font", "Label") if UI.theme != null else ThemeDB.fallback_font
	_world = Node2D.new()
	_world.name = "World"
	_world.draw.connect(_draw_world)
	_felt = Color("#1e6a3a").lerp(Kit.color("solid", Color("#1e6a3a")).darkened(0.35), 0.45)
	_back = Kit.color("accent", Color("#2f5ad8")).darkened(0.1)
	var art: Dictionary = Kit.sprite_by_role("jugador")
	if not art.is_empty():
		var sf: SpriteFrames = SpriteKit.frames_de(art)
		for an: String in sf.get_animation_names():
			if sf.get_frame_count(an) > 0:
				_emblem = sf.get_frame_texture(an, 0)
				break
	var mas: Node2D = SpriteKit.mascota(230.0)
	if mas != null:
		mas.position = Vector2(600.0, 1230.0)
		mas.modulate = Color(1, 1, 1, 0.92)
		add_child(mas)
	add_child(_world)
	_camera = Camera2D.new()
	add_child(_camera)
	_camera.make_current()
	_camera.position = Vector2(360, 640)
	_build_hud()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "klondike", "seed": int(level.get("seed", 1))})


## Tablero claro: sin el brillo del etalonaje (lo quemaria).
func wants_grade() -> bool:
	return false


func bot_script() -> String:
	return "res://qa/klondike_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(5.0, 2.0)


func wants_backdrop() -> bool:
	return false


func _reset() -> void:
	finished = false
	failed = false
	st = MapRules.new_state(level)
	coins = 0
	time_in_level = 0.0
	_plan = []
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
	col.add_child(top)
	_info = Label.new()
	_info.name = "Info"
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.add_theme_font_size_override("font_size", 30)
	_info.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_info.add_theme_constant_override("outline_size", 6)
	top.add_child(_info)
	var hint: Button = UI.make_button(Kit.text("kl_hint", "Pista"))
	hint.name = "BtnHint"
	hint.custom_minimum_size = Vector2(160, 72)
	hint.pressed.connect(use_hint)
	top.add_child(hint)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)


func _refresh() -> void:
	if _info == null or st.is_empty():
		return
	var f: int = 0
	for v: Variant in st["found"]:
		f += int(v)
	coins = f
	var s: int = int(time_in_level)
	_info.text = "%d/52   %d:%02d" % [f, s / 60, s % 60]


# ------------------------------------------------------------------ acciones

func can_act() -> bool:
	return not finished and is_inside_tree() and not get_tree().paused


func do_move(m: Dictionary) -> void:
	MapRules.apply(st, m)
	_sfx("coin" if str(m["t"]) in ["wf", "cf"] else "click")
	_refresh()
	if MapRules.won(st):
		_finish()


## Toque en una carta: la mejor jugada que empiece por ella.
func tap_source(kind: String, a: int, i: int) -> void:
	if not can_act():
		return
	var best: Dictionary = {}
	for m: Dictionary in MapRules.moves(st):
		var t: String = str(m["t"])
		var ok: bool = false
		if kind == "waste":
			ok = t == "wf" or t == "wc"
		elif kind == "col":
			ok = (t == "cf" and int(m["a"]) == a and i == (st["cols"][a] as Array).size() - 1) or (t == "cc" and int(m["a"]) == a and int(m["i"]) <= i)
		if ok and (best.is_empty() or MapRules._rank(st, m) < MapRules._rank(st, best)):
			best = m
	if best.is_empty():
		_shake = Vector2i(a, i)
		_shake_t = 0.3
		return
	_plan = []
	do_move(best)


func tap_stock() -> void:
	if not can_act():
		return
	for m: Dictionary in MapRules.moves(st):
		if str(m["t"]) == "draw" or str(m["t"]) == "recycle":
			_plan = []
			do_move(m)
			return


func use_hint() -> void:
	if not can_act():
		return
	if _plan.is_empty():
		_plan = MapRules.solve(st)
	if _plan.is_empty():
		## Sin solucion desde aqui: se repite el reparto.
		_lose()
		return
	do_move(_plan.pop_front())


func _sfx(n: String) -> void:
	if not fast:
		Audio.play(n, 0.1, -10.0)


func bot_step() -> void:
	if not can_act():
		return
	if _plan.is_empty():
		_plan = MapRules.solve(st)
		if _plan.is_empty():
			_lose()
			return
	do_move(_plan.pop_front())


# ------------------------------------------------------------------ bucle

func _physics_process(delta: float) -> void:
	_t += delta
	_shake_t = maxf(0.0, _shake_t - delta)
	if finished:
		_world.queue_redraw()
		return
	time_in_level += delta * (4.0 if fast else 1.0)
	if fast and auto_retry:
		bot_step()
	_refresh()
	_world.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()
		return
	if not (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed):
		return
	var p: Vector2 = get_canvas_transform().affine_inverse() * (event as InputEventScreenTouch).position
	if Rect2(Vector2(X0, TOP_Y), Vector2(CW, CH)).has_point(p):
		tap_stock()
		return
	if Rect2(Vector2(X0 + GAP, TOP_Y), Vector2(CW + 40.0, CH)).has_point(p):
		tap_source("waste", 0, 0)
		return
	for a: int in 7:
		var col: Array = st["cols"][a]
		for i: int in range(col.size() - 1, -1, -1):
			if _card_rect(a, i).has_point(p):
				if bool(col[i][2]):
					tap_source("col", a, i)
				return


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	coins = 52
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = 5200 + maxi(0, int(par * 1.4 - time_in_level)) * 10
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
	return 3 if time_in_level <= par * 1.4 else 2


func _lose() -> void:
	if finished:
		return
	finished = true
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "stuck", "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("kl_lost", "\u00a1Sin salida!"),
		Kit.text("kl_fail_hint", "Destapa primero las columnas con m\u00e1s cartas boca abajo y no llenes huecos vac\u00edos sin un Rey."))
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
	return {"pos": Vector2(float(coins), float(st.get("moves", 0))), "deaths": deaths, "coins": coins, "finished": finished,
		"failed": failed, "stomps": 0, "time": time_in_level, "found": coins}


# ------------------------------------------------------------------ dibujo

func _card_rect(a: int, i: int) -> Rect2:
	var col: Array = st["cols"][a]
	var y: float = TAB_Y
	for k: int in i:
		y += 38.0 if bool(col[k][2]) else 20.0
	var r: Rect2 = Rect2(Vector2(X0 + float(a) * GAP, y), Vector2(CW, CH))
	if _shake_t > 0.0 and _shake == Vector2i(a, i):
		r.position.x += sin(_shake_t * 60.0) * 5.0
	return r


static func draw_suit(ci: CanvasItem, s: int, c: Vector2, k: float) -> void:
	var col: Color = Color("#d8303a") if s == 1 or s == 2 else Color("#22222a")
	match s:
		0:
			ci.draw_circle(c + Vector2(-5, 2) * k, 5.5 * k, col)
			ci.draw_circle(c + Vector2(5, 2) * k, 5.5 * k, col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-10, 0) * k, c + Vector2(0, -12) * k, c + Vector2(10, 0) * k]), col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-4, 12) * k, c + Vector2(0, 2) * k, c + Vector2(4, 12) * k]), col)
		1:
			ci.draw_circle(c + Vector2(-5, -3) * k, 6.0 * k, col)
			ci.draw_circle(c + Vector2(5, -3) * k, 6.0 * k, col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-11, -1) * k, c + Vector2(11, -1) * k, c + Vector2(0, 12) * k]), col)
		2:
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -12) * k, c + Vector2(9, 0) * k, c + Vector2(0, 12) * k, c + Vector2(-9, 0) * k]), col)
		3:
			ci.draw_circle(c + Vector2(0, -6) * k, 5.5 * k, col)
			ci.draw_circle(c + Vector2(-6, 2) * k, 5.5 * k, col)
			ci.draw_circle(c + Vector2(6, 2) * k, 5.5 * k, col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-4, 12) * k, c + Vector2(0, 0) * k, c + Vector2(4, 12) * k]), col)


func _card(r: Rect2, card: Variant) -> void:
	_world.draw_rect(Rect2(r.position + Vector2(2, 3), r.size), Color(0, 0, 0, 0.25))
	if card == null or not bool(card[2]):
		_world.draw_rect(r, Color("#f4f4f0"))
		_world.draw_rect(r.grow(-5.0), _back)
		for k: int in 4:
			_world.draw_rect(r.grow(-12.0 - float(k) * 8.0), Color(1, 1, 1, 0.12), false, 2.0)
		if _emblem != null and r.size.y > 60.0:
			var e: float = minf(r.size.x, r.size.y) * 0.62
			_world.draw_texture_rect(_emblem, Rect2(r.get_center() - Vector2(e, e) * 0.5, Vector2(e, e)), false, Color(1, 1, 1, 0.85))
		return
	_world.draw_rect(r, Color("#fbfaf4"))
	_world.draw_rect(r, Color("#c8c4b8"), false, 1.5)
	var s: int = int(card[0])
	var red: bool = s == 1 or s == 2
	var txt: String = RANKS[int(card[1])]
	_world.draw_string(_font, r.position + Vector2(7, 28), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("#d8303a") if red else Color("#22222a"))
	draw_suit(_world, s, r.position + Vector2(r.size.x - 18, 18), 0.8)
	draw_suit(_world, s, r.get_center() + Vector2(0, 12), 2.0)


func _slot(r: Rect2) -> void:
	_world.draw_rect(r, Color(0, 0, 0, 0.15))
	_world.draw_rect(r, Color(1, 1, 1, 0.3), false, 2.0)


func _draw_world() -> void:
	if st.is_empty():
		return
	## El tapete es el color de fondo (asi el protagonista, detras de las cartas, se ve).
	for k: int in 40:
		_world.draw_circle(Vector2(fmod(float(k * 97), 720.0), fmod(float(k * 151), 1280.0)), 60.0, Color(1, 1, 1, 0.015))
	## Mazo, descarte y bases.
	var stock_r: Rect2 = Rect2(Vector2(X0, TOP_Y), Vector2(CW, CH))
	if (st["stock"] as Array).is_empty():
		_slot(stock_r)
		_world.draw_arc(stock_r.get_center(), 22.0, 0.4, TAU - 0.4, 16, Color(1, 1, 1, 0.5), 5.0)
	else:
		_card(stock_r, null)
	var waste: Array = st["waste"]
	var wr: Rect2 = Rect2(Vector2(X0 + GAP, TOP_Y), Vector2(CW, CH))
	if waste.is_empty():
		_slot(wr)
	else:
		for k2: int in mini(3, waste.size()):
			var c: Variant = waste[waste.size() - mini(3, waste.size()) + k2]
			_card(Rect2(wr.position + Vector2(float(k2) * 20.0, 0), wr.size), c)
	for f: int in 4:
		var fr: Rect2 = Rect2(Vector2(X0 + float(3 + f) * GAP, TOP_Y), Vector2(CW, CH))
		var v: int = int(st["found"][f])
		if v == 0:
			_slot(fr)
			draw_suit(_world, f, fr.get_center(), 2.0)
		else:
			_card(fr, [f, v, true])
	## Columnas.
	for a: int in 7:
		var col: Array = st["cols"][a]
		if col.is_empty():
			_slot(Rect2(Vector2(X0 + float(a) * GAP, TAB_Y), Vector2(CW, CH)))
		for i: int in col.size():
			_card(_card_rect(a, i), col[i])
