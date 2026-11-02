extends Node2D
## Defensa por carriles (estilo Plants vs Zombies) en vertical: los zombis bajan por 5 carriles
## hacia tu casa. Toca una carta y luego una casilla para plantar; toca los soles para cogerlos.
## Cada carril tiene un cortacesped que salva una vez. Ganas al acabar con todas las oleadas.
## Simulacion, bot y analizador en lawn_map.gd.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const M = preload("res://kit/lawn/lawn_map.gd")
const X0: float = 40.0
const Y0: float = 168.0
const CW: float = 128.0
const RH: float = 88.0
const PLANT_COL: Dictionary = {"sunflower": "#ffd23f", "peashooter": "#43a047", "snowpea": "#4fc3f7", "wallnut": "#a0703a",
	"potatomine": "#c9a06a", "cherrybomb": "#e53935", "repeater": "#2e7d32"}

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
var sel: String = ""

var _world: Node2D
var _camera: Camera2D
var _hud: Control
var _sun_lbl: Label
var _bar: ProgressBar
var _cards: Array[Control] = []
var _bot: bool = false
var _bot_t: float = 0.0
var _t: float = 0.0
var _fx: Array = []
var _flash: Dictionary = {}
var _mower_run: Array = []


class SeedCard:
	extends Control
	var game: Node
	var kind: String = ""

	func _draw() -> void:
		var st0: Dictionary = game.get("st")
		if st0.is_empty():
			return
		var r: Rect2 = Rect2(Vector2.ZERO, size)
		var cost: int = int(M.PLANTS[kind]["cost"])
		var ready: float = float(st0["ready"][kind])
		var picked: bool = str(game.get("sel")) == kind
		draw_rect(Rect2(r.position + Vector2(3, 5), r.size), Color(0, 0, 0, 0.35))
		draw_rect(r, Color("#ffd23f") if picked else Color("#5a3a1c"))
		draw_rect(r.grow(-4.0), Color("#f4e2b8"))
		game.call("draw_plant", self, kind, r.get_center() - Vector2(0, 12), 0.62)
		var f: Font = UI.font if UI.font != null else ThemeDB.fallback_font
		var txt: String = str(cost)
		var tw: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		draw_string(f, Vector2(r.size.x * 0.5 - tw * 0.5, r.size.y - 10.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#3a2410"))
		## Recarga (sombra que baja) y sin soles (apagada).
		var rec: float = float(M.PLANTS[kind]["recharge"])
		if ready > 0.0:
			draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * ready / rec)), Color(0, 0, 0, 0.5))
		elif int(st0["sun"]) < cost:
			draw_rect(r, Color(0, 0, 0, 0.35))


func _ready() -> void:
	level = Kit.current_level()
	RenderingServer.set_default_clear_color(Color("#3b5a2a"))
	_world = Node2D.new()
	_world.name = "World"
	_world.draw.connect(_draw_world)
	add_child(_world)
	_camera = Camera2D.new()
	add_child(_camera)
	_camera.make_current()
	_camera.position = Vector2(360, 640)
	Juice.register_camera(_camera)
	_build_hud()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "lawn", "zombies": int(st["total"])})


func bot_script() -> String:
	return "res://qa/lawn_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(40.0, 30.0)


func _reset() -> void:
	finished = false
	failed = false
	var lv: Dictionary = level.duplicate()
	if deaths > 0:
		lv["seed"] = M.seed_of(level) + deaths * 131
		lv["map"] = ["jardin", "#%d" % (M.seed_of(level) + deaths * 131)]
	st = M.new_state(lv)
	coins = 0
	coins_total = int(st["total"])
	time_in_level = 0.0
	sel = ""
	_fx.clear()
	_flash.clear()
	_mower_run.clear()
	_rebuild_cards()
	_refresh()


func cell_rect(c: Vector2i) -> Rect2:
	return Rect2(Vector2(X0 + float(c.x) * CW, Y0 + float(c.y) * RH), Vector2(CW, RH))


func lane_x(lane: int) -> float:
	return X0 + (float(lane) + 0.5) * CW


func row_y(y: float) -> float:
	return Y0 + y * RH


func cell_at(p: Vector2) -> Vector2i:
	var c: Vector2i = Vector2i(floori((p.x - X0) / CW), floori((p.y - Y0) / RH))
	if c.x < 0 or c.x >= M.LANES or c.y < 0 or c.y >= M.ROWS:
		return Vector2i(-1, -1)
	return c


# ------------------------------------------------------------------ interfaz

func _build_hud() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "Hud"
	layer.layer = 20
	add_child(layer)
	_hud = Control.new()
	_hud.theme = UI.theme
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_hud)
	var safe: MarginContainer = UI.safe_root(_hud, 12.0)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col: VBoxContainer = VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 8)
	safe.add_child(col)
	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 12)
	col.add_child(top)
	top.add_child(UiIcon.make("star", Color("#ffd23f"), 44.0))
	_sun_lbl = Label.new()
	_sun_lbl.name = "Sun"
	_sun_lbl.add_theme_font_size_override("font_size", 34)
	_sun_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_sun_lbl.add_theme_constant_override("outline_size", 8)
	_sun_lbl.custom_minimum_size = Vector2(90, 0)
	top.add_child(_sun_lbl)
	_bar = ProgressBar.new()
	_bar.name = "Waves"
	_bar.show_percentage = false
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bar.custom_minimum_size = Vector2(0, 24)
	_bar.max_value = 1.0
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_bar)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)
	var grow: Control = Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(grow)
	var bank: HBoxContainer = HBoxContainer.new()
	bank.name = "Bank"
	bank.alignment = BoxContainer.ALIGNMENT_CENTER
	bank.add_theme_constant_override("separation", 6)
	bank.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(bank)


func _rebuild_cards() -> void:
	var bank: Node = _hud.find_child("Bank", true, false)
	for c: Node in bank.get_children():
		bank.remove_child(c)
		c.queue_free()
	_cards.clear()
	for kind: String in st["cards"]:
		var card: Control = SeedCard.new()
		card.name = "Card_" + kind
		card.set("game", self)
		card.set("kind", kind)
		card.custom_minimum_size = Vector2(minf(94.0, 690.0 / float((st["cards"] as Array).size()) - 6.0), 128)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.gui_input.connect(_card_input.bind(kind))
		bank.add_child(card)
		_cards.append(card)


func _refresh() -> void:
	if _sun_lbl == null or st.is_empty():
		return
	_sun_lbl.text = str(int(st["sun"]))
	_bar.value = M.progress(st)
	for c: Control in _cards:
		c.queue_redraw()


# ------------------------------------------------------------------ jugar

func can_act() -> bool:
	return not finished and is_inside_tree() and not get_tree().paused


func _card_input(event: InputEvent, kind: String) -> void:
	var pressed: bool = (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed) or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)
	if pressed and can_act():
		_bot = false
		sel = "" if sel == kind else kind
		_sfx("click", -12.0, 1.2)
		_refresh()


## Toque en el jardin: coge un sol si hay uno ahi; si no, planta lo elegido.
func tap(p: Vector2) -> void:
	if not can_act():
		return
	for s: Dictionary in st["suns"]:
		if Vector2(X0 + float(s["x"]) * CW, row_y(float(s["y"]))).distance_to(p) < 52.0:
			if M.collect(st, int(s["id"])):
				_events()
			return
	var c: Vector2i = cell_at(p)
	if c.x < 0 or sel == "":
		return
	if M.plant(st, sel, c):
		sel = ""
		_events()
	else:
		_sfx("click", -14.0, 0.5)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()
		return
	var pressed: bool = false
	var pos: Vector2 = Vector2.ZERO
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		pressed = true
		pos = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		pressed = true
		pos = (event as InputEventMouseButton).position
	if pressed:
		_bot = false
		tap(get_canvas_transform().affine_inverse() * pos)


func _events() -> void:
	for e: Dictionary in st["events"]:
		match str(e["kind"]):
			"plant":
				_sfx("click", -6.0, 0.8)
				Juice.vibrate(10)
			"collect":
				_sfx("coin", -8.0, 1.3)
				if not fast:
					var p: Vector2 = e["p"]
					_fx.append({"kind": "fly", "a": Vector2(X0 + p.x * CW, row_y(p.y)), "t": 0.0})
			"shoot":
				_sfx("click", -18.0, 1.6)
			"hit":
				if not fast:
					_fx.append({"kind": "splat", "p": Vector2(lane_x(int(e["lane"])), row_y(float(e["y"]))), "t": 0.0, "slow": bool(e["slow"])})
			"die":
				coins += 1
				_sfx("stomp", -10.0, 0.9 + randf() * 0.2)
				if not fast:
					_fx.append({"kind": "die", "p": Vector2(lane_x(int(e["lane"])), row_y(float(e["y"]))), "t": 0.0, "z": str(e["kind"])})
			"boom":
				_sfx("hurt", -2.0, 0.6)
				if not fast:
					Juice.shake(0.25)
					var c: Vector2i = e["cell"]
					_fx.append({"kind": "boom", "p": cell_rect(c).get_center(), "r": (float(int(e["reach"])) + 0.6) * CW, "t": 0.0})
			"eaten":
				_sfx("hurt", -12.0, 1.4)
			"mower":
				_sfx("powerup", -4.0, 0.7)
				_mower_run.append({"lane": int(e["lane"]), "t": 0.0})
			"wave":
				if not fast:
					var txt: String = Kit.text("pz_last", "\u00a1Ultima oleada!") if bool(e["last"]) else Kit.text("pz_wave", "\u00a1Llegan zombis!")
					UI.float_text(_hud, Vector2(360, 520), txt, Color("#ff7043") if bool(e["last"]) else Color.WHITE, 44 if bool(e["last"]) else 36)
			"end":
				if bool(e["won"]):
					_finish.call_deferred()
				else:
					_lose.call_deferred()
	(st["events"] as Array).clear()
	_refresh()


func _sfx(nm: String, vol: float = -10.0, pitch: float = 1.0) -> void:
	if not fast:
		Audio.play(nm, 0.05, vol, pitch)


func bot_step() -> void:
	_bot = true


func _physics_process(delta: float) -> void:
	_t += delta
	for f: Dictionary in _fx:
		f["t"] = float(f["t"]) + delta
	_fx = _fx.filter(func(f: Dictionary) -> bool: return float(f["t"]) < 0.6)
	for m: Dictionary in _mower_run:
		m["t"] = float(m["t"]) + delta
	_mower_run = _mower_run.filter(func(m: Dictionary) -> bool: return float(m["t"]) < 1.2)
	if finished:
		_world.queue_redraw()
		return
	if fast and auto_retry:
		_bot = true
	var steps: int = 20 if fast else 1
	var dt: float = 0.1 if fast else delta
	for k: int in steps:
		if finished or bool(st["over"]):
			break
		time_in_level += dt
		if _bot:
			_bot_t -= dt
			if _bot_t <= 0.0:
				_bot_t = 0.4
				for j: int in 3:
					M.bot_act(st)
		M.step(st, dt)
		_events()
	_world.queue_redraw()


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var mowers: int = 0
	for m: Variant in st["mowers"]:
		if bool(m):
			mowers += 1
	var score: int = maxi(1, coins * 100 + mowers * 500 + int(st["sun"]))
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "time": snappedf(time_in_level, 0.1), "mowers": mowers})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


## Estrellas por cortacespedes que quedan: todos 3, perdiste uno 2, mas 1.
func stars_earned() -> int:
	var used: int = 0
	for m: Variant in st["mowers"]:
		if not bool(m):
			used += 1
	return 3 if used == 0 else (2 if used == 1 else 1)


func _lose() -> void:
	if finished:
		return
	finished = true
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "house", "killed": int(st["killed"]), "deaths": deaths})
	Audio.play("hurt")
	Juice.shake(0.4)
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("pz_lost", "\u00a1Los zombis han entrado en casa!"),
		Kit.text("pz_fail_hint", "Planta girasoles al principio para tener soles, pon un tirador en cada carril por el que bajen y una nuez delante de los conos y cubos."))
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
	if st.is_empty():
		return {}
	return {"deaths": deaths, "coins": coins, "finished": finished, "failed": failed, "time": time_in_level,
		"killed": int(st["killed"]), "total": int(st["total"]), "sun": int(st["sun"]), "plants": (st["plants"] as Dictionary).size()}


# ------------------------------------------------------------------ dibujo

## Cada planta con su forma (tambien en las cartas).
func draw_plant(ci: CanvasItem, kind: String, c: Vector2, s: float) -> void:
	var stem: Color = Color("#2e7d32")
	match kind:
		"sunflower":
			ci.draw_line(c + Vector2(0, 10) * s, c + Vector2(0, 40) * s, stem, 6.0 * s)
			for k: int in 10:
				var a: float = TAU * float(k) / 10.0 + _t * 0.4
				ci.draw_circle(c + Vector2(cos(a), sin(a)) * 22.0 * s, 10.0 * s, Color("#ffd23f"))
			ci.draw_circle(c, 15.0 * s, Color("#8a5a2b"))
			ci.draw_circle(c + Vector2(-5, -3) * s, 2.5 * s, Color.BLACK)
			ci.draw_circle(c + Vector2(5, -3) * s, 2.5 * s, Color.BLACK)
		"peashooter", "snowpea", "repeater":
			var col: Color = Color(str(PLANT_COL[kind]))
			ci.draw_line(c + Vector2(0, 12) * s, c + Vector2(0, 40) * s, stem, 6.0 * s)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, 30) * s, c + Vector2(-18, 22) * s, c + Vector2(-4, 36) * s]), stem.lightened(0.2))
			ci.draw_circle(c, 20.0 * s, col)
			## La boca mira hacia arriba (por donde vienen).
			ci.draw_rect(Rect2(c + Vector2(-9, -34) * s, Vector2(18, 20) * s), col.darkened(0.1))
			ci.draw_circle(c + Vector2(0, -34) * s, 8.0 * s, col.darkened(0.45))
			ci.draw_circle(c + Vector2(-8, 2) * s, 4.0 * s, Color.BLACK)
			ci.draw_circle(c + Vector2(8, 2) * s, 4.0 * s, Color.BLACK)
			if kind == "repeater":
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-6, 14) * s, c + Vector2(6, 14) * s, c + Vector2(0, 26) * s]), Color("#1b5e20"))
			if kind == "snowpea":
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-18, -6) * s, c + Vector2(-26, -20) * s, c + Vector2(-10, -14) * s]), Color("#b3e5fc"))
		"wallnut":
			ci.draw_set_transform(c, 0.0, Vector2(1.0, 1.2))
			ci.draw_circle(Vector2.ZERO, 24.0 * s, Color("#8d5a2b"))
			ci.draw_circle(Vector2(-2, -2) * s, 21.0 * s, Color("#c08a4a"))
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			ci.draw_circle(c + Vector2(-8, -6) * s, 5.0 * s, Color.WHITE)
			ci.draw_circle(c + Vector2(8, -6) * s, 5.0 * s, Color.WHITE)
			ci.draw_circle(c + Vector2(-8, -6) * s, 2.5 * s, Color.BLACK)
			ci.draw_circle(c + Vector2(8, -6) * s, 2.5 * s, Color.BLACK)
		"potatomine":
			ci.draw_set_transform(c + Vector2(0, 10) * s, 0.0, Vector2(1.3, 0.8))
			ci.draw_circle(Vector2.ZERO, 18.0 * s, Color("#c9a06a"))
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			ci.draw_line(c + Vector2(0, -2) * s, c + Vector2(0, -16) * s, Color("#555555"), 3.0 * s)
			ci.draw_circle(c + Vector2(0, -18) * s, 5.0 * s, Color("#e53935"))
		"cherrybomb":
			ci.draw_line(c + Vector2(-10, -4) * s, c + Vector2(2, -26) * s, stem, 4.0 * s)
			ci.draw_line(c + Vector2(12, -4) * s, c + Vector2(2, -26) * s, stem, 4.0 * s)
			ci.draw_circle(c + Vector2(-12, 6) * s, 15.0 * s, Color("#e53935"))
			ci.draw_circle(c + Vector2(13, 8) * s, 15.0 * s, Color("#c62828"))
			ci.draw_circle(c + Vector2(-16, 2) * s, 4.0 * s, Color(1, 1, 1, 0.6))


func _draw_zombie(z: Dictionary) -> void:
	var p: Vector2 = Vector2(lane_x(int(z["lane"])), row_y(float(z["y"])) + RH * 0.45)
	var bob: float = 0.0 if bool(z["eating"]) else sin(_t * 6.0 + float(int(z["id"]))) * 3.0
	var skin: Color = Color("#9ccc65") if float(z["slow"]) <= 0.0 else Color("#80deea")
	var coat: Color = Color("#5d4037")
	if str(z["kind"]) == "runner":
		coat = Color("#c62828")
	_world.draw_circle(p + Vector2(0, 28), 22.0, Color(0, 0, 0, 0.25))
	_world.draw_rect(Rect2(p + Vector2(-18, -6 + bob), Vector2(36, 34)), coat)
	_world.draw_rect(Rect2(p + Vector2(-4, -6 + bob), Vector2(8, 16)), Color("#e53935"))
	## Brazos hacia delante (abajo), que es donde esta la casa.
	_world.draw_line(p + Vector2(-16, 4 + bob), p + Vector2(-22, 28 + bob), skin, 7.0)
	_world.draw_line(p + Vector2(16, 4 + bob), p + Vector2(22, 28 + bob), skin, 7.0)
	var head: Vector2 = p + Vector2(0, -20 + bob)
	_world.draw_circle(head, 17.0, skin)
	_world.draw_circle(head + Vector2(-6, 2), 5.0, Color.WHITE)
	_world.draw_circle(head + Vector2(7, 3), 3.5, Color.WHITE)
	_world.draw_circle(head + Vector2(-6, 3), 2.0, Color.BLACK)
	_world.draw_line(head + Vector2(-7, 10), head + Vector2(7, 10), Color("#3e2723"), 2.0)
	match str(z["kind"]):
		"cone":
			_world.draw_colored_polygon(PackedVector2Array([head + Vector2(-15, -8), head + Vector2(15, -8), head + Vector2(0, -42)]), Color("#ff9800"))
			_world.draw_line(head + Vector2(-9, -20), head + Vector2(9, -20), Color.WHITE, 3.0)
		"bucket":
			_world.draw_colored_polygon(PackedVector2Array([head + Vector2(-18, -4), head + Vector2(18, -4), head + Vector2(14, -32), head + Vector2(-14, -32)]), Color("#90a4ae"))
			_world.draw_line(head + Vector2(-16, -10), head + Vector2(16, -10), Color("#607d8b"), 3.0)
	var frac: float = float(z["hp"]) / maxf(1.0, float(z["max"]))
	if frac < 0.999:
		_world.draw_rect(Rect2(p + Vector2(-20, -48), Vector2(40, 5)), Color(0, 0, 0, 0.5))
		_world.draw_rect(Rect2(p + Vector2(-20, -48), Vector2(40 * frac, 5)), Color("#e53935"))


func _draw_world() -> void:
	if st.is_empty():
		return
	## Calle de arriba (de donde salen) y jardin a cuadros.
	_world.draw_rect(Rect2(Vector2(0, Y0 - 140.0), Vector2(720, 140)), Color("#6d6d6d"))
	_world.draw_rect(Rect2(Vector2(0, Y0 - 12.0), Vector2(720, 12)), Color("#9e9e9e"))
	for y: int in M.ROWS:
		for x: int in M.LANES:
			var r: Rect2 = cell_rect(Vector2i(x, y))
			_world.draw_rect(r, Color("#7cc45a") if (x + y) % 2 == 0 else Color("#6db54d"))
	## Casa y cortacespedes abajo.
	var house_y: float = row_y(float(M.ROWS))
	_world.draw_rect(Rect2(Vector2(0, house_y), Vector2(720, 300)), Color("#8d6e63"))
	_world.draw_rect(Rect2(Vector2(0, house_y), Vector2(720, 10)), Color("#5d4037"))
	for lane: int in M.LANES:
		var mx: float = lane_x(lane)
		var run_y: float = 0.0
		var showing: bool = bool(st["mowers"][lane])
		for m: Dictionary in _mower_run:
			if int(m["lane"]) == lane:
				run_y = -float(m["t"]) * 1000.0
				showing = true
		if showing:
			var mp: Vector2 = Vector2(mx, house_y + 26.0 + run_y)
			_world.draw_rect(Rect2(mp - Vector2(26, 14), Vector2(52, 28)), Color("#e53935"))
			_world.draw_rect(Rect2(mp - Vector2(20, 22), Vector2(40, 10)), Color("#424242"))
			_world.draw_circle(mp + Vector2(-20, 14), 7.0, Color("#212121"))
			_world.draw_circle(mp + Vector2(20, 14), 7.0, Color("#212121"))
	## Plantas.
	for cell: Vector2i in st["plants"]:
		var pd: Dictionary = st["plants"][cell]
		var c: Vector2 = cell_rect(cell).get_center()
		var sc: float = 1.0
		if str(pd["kind"]) == "cherrybomb":
			sc = 1.0 + float(pd["t"]) * 0.4
		if str(pd["kind"]) == "potatomine" and float(pd["t"]) < float(M.PLANTS["potatomine"]["arm"]):
			c.y += 14.0
		draw_plant(_world, str(pd["kind"]), c, sc)
		var frac: float = float(pd["hp"]) / float(M.PLANTS[str(pd["kind"])]["hp"])
		if frac < 0.99 and str(pd["kind"]) != "cherrybomb":
			_world.draw_rect(Rect2(c + Vector2(-24, 36), Vector2(48, 5)), Color(0, 0, 0, 0.4))
			_world.draw_rect(Rect2(c + Vector2(-24, 36), Vector2(48 * frac, 5)), Color("#8bc34a"))
	## Casillas libres resaltadas con una carta elegida.
	if sel != "":
		for y2: int in M.ROWS:
			for x2: int in M.LANES:
				if not (st["plants"] as Dictionary).has(Vector2i(x2, y2)):
					_world.draw_rect(cell_rect(Vector2i(x2, y2)).grow(-4.0), Color(1, 1, 1, 0.12 + 0.06 * sin(_t * 6.0)), false, 3.0)
	## Guisantes, zombis, soles y efectos.
	for pea: Dictionary in st["peas"]:
		_world.draw_circle(Vector2(lane_x(int(pea["lane"])), row_y(float(pea["y"]))), 9.0, Color("#4fc3f7") if bool(pea["slow"]) else Color("#76ff03"))
	var zs: Array = (st["zombies"] as Array).duplicate()
	zs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["y"]) < float(b["y"]))
	for z: Dictionary in zs:
		_draw_zombie(z)
	for s: Dictionary in st["suns"]:
		var sp: Vector2 = Vector2(X0 + float(s["x"]) * CW, row_y(float(s["y"])))
		if bool(s["sky"]):
			sp.y -= maxf(0.0, 1.0 - float(s["t"]) / 1.2) * 300.0
		var blink: float = 1.0 if float(s["t"]) < 8.0 else (0.4 + 0.6 * absf(sin(_t * 10.0)))
		for k: int in 8:
			var a: float = TAU * float(k) / 8.0 + _t
			_world.draw_line(sp, sp + Vector2(cos(a), sin(a)) * 34.0, Color(1.0, 0.85, 0.2, 0.6 * blink), 4.0)
		_world.draw_circle(sp, 22.0, Color(1.0, 0.82, 0.15, blink))
		_world.draw_circle(sp, 14.0, Color(1.0, 0.95, 0.5, blink))
	for f: Dictionary in _fx:
		var k2: float = float(f["t"]) / 0.6
		match str(f["kind"]):
			"fly":
				var q: Vector2 = (f["a"] as Vector2).lerp(Vector2(80, 60), minf(1.0, k2 * 1.6))
				_world.draw_circle(q, 18.0 * (1.0 - k2 * 0.5), Color(1.0, 0.82, 0.15, 1.0 - k2))
			"splat":
				_world.draw_circle(f["p"], 10.0 + 10.0 * k2, Color(0.5, 1.0, 0.3, 0.6 * (1.0 - k2)) if not bool(f["slow"]) else Color(0.6, 0.9, 1.0, 0.6 * (1.0 - k2)))
			"die":
				_world.draw_circle((f["p"] as Vector2) + Vector2(0, 30), 30.0 * (1.0 + k2), Color(0.3, 0.3, 0.3, 0.5 * (1.0 - k2)))
			"boom":
				_world.draw_circle(f["p"], float(f["r"]) * (0.5 + 0.5 * k2), Color(1.0, 0.5, 0.1, 0.7 * (1.0 - k2)))
