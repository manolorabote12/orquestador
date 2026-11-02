extends Node2D
## Duelo de cartas en tiempo real (estilo Clash Royale): arrastra una carta de tu mano a tu mitad
## de la arena (los hechizos, a cualquier sitio). Las tropas van solas por su carril a por las
## torres rivales. Gana quien tire la torre del rey o tenga mas coronas al acabar el tiempo.
## Reglas, IA rival, bot y analizador en clash_map.gd (simulacion pura). Nace en 3D
## (clash_view3d.gd); en 2D se ve desde arriba con las mismas reglas.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const M = preload("res://kit/clash/clash_map.gd")
const View3D = preload("res://kit/clash/clash_view3d.gd")
const S: float = 30.0
const ORIGIN: Vector2 = Vector2(90, 112)
const TEAM: Array[Color] = [Color("#3d8bff"), Color("#ff4a4a")]
## Color de cada carta (marco) y lo que se ve dentro.
const CARD_COL: Dictionary = {"knight": "#8fa3b8", "archers": "#e8749b", "giant": "#d9a066", "minions": "#7e6bd9",
	"musketeer": "#b06ad9", "skeletons": "#e8e8e8", "hog": "#c98a5a", "valkyrie": "#ff9a3c", "babydragon": "#6fcf5a",
	"cannon": "#6b6b78", "fireball": "#ff7a1a", "arrows": "#d9c36b"}

var level: Dictionary = {}
var st: Dictionary = {}
var finished: bool = false
var failed: bool = false
var deaths: int = 0
var time_in_level: float = 0.0
var coins: int = 0
var coins_total: int = 3
var fast: bool = false
var auto_retry: bool = false
var result_panel: ResultPanel
var view3d: Node3D = null

var _world: Node2D
var _camera: Camera2D
var _hud: Control
var _cards: Array[Control] = []
var _next_card: Control
var _elixir_bar: Control
var _timer_lbl: Label
var _crowns_lbl: Label
var _bot: bool = false
var _t: float = 0.0
## Carta elegida (0-3) y si se esta arrastrando; posicion en la arena (casillas).
var sel: int = -1
var dragging: bool = false
var drag_arena: Vector2 = Vector2(-1, -1)
var _drag_screen: Vector2 = Vector2.ZERO
var _fx: Array = []
var _shots: Array = []


class CardView:
	extends Control
	var game: Node
	var slot: int = 0
	var small: bool = false

	func _draw() -> void:
		var st0: Dictionary = game.get("st")
		if st0.is_empty():
			return
		var card: String = str(st0["queues"][0][0]) if slot < 0 else str(st0["hands"][0][slot])
		var r: Rect2 = Rect2(Vector2.ZERO, size)
		var col: Color = Color(str(CARD_COL.get(card, "#888888")))
		var cost: int = int(M.CARDS[card]["cost"])
		var can: bool = float(st0["elixir"][0]) >= float(cost)
		var lifted: float = -14.0 if slot >= 0 and int(game.get("sel")) == slot else 0.0
		r.position.y += lifted
		draw_rect(Rect2(r.position + Vector2(3, 5), r.size), Color(0, 0, 0, 0.35))
		draw_rect(r, Color("#ffd23f") if lifted < 0.0 else Color("#1b2233"))
		draw_rect(r.grow(-4.0), col.darkened(0.25))
		draw_rect(Rect2(r.position + Vector2(8, 8), r.size - Vector2(16, 34 if not small else 16)), col)
		game.call("draw_card_icon", self, card, r.get_center() - Vector2(0, 8 if not small else 0), r.size.x / 110.0)
		if not small:
			## Gota de elixir con el coste.
			var d: Vector2 = Vector2(r.position.x + 18.0, r.end.y - 16.0)
			draw_circle(d, 15.0, Color("#2b1140"))
			draw_circle(d, 12.0, Color("#d94bd9"))
			var f: Font = UI.font if UI.font != null else ThemeDB.fallback_font
			var tw: float = f.get_string_size(str(cost), HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
			draw_string_outline(f, d + Vector2(-tw * 0.5, 8), str(cost), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 5, Color(0, 0, 0, 0.8))
			draw_string(f, d + Vector2(-tw * 0.5, 8), str(cost), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
		if not can:
			draw_rect(r, Color(0.05, 0.05, 0.1, 0.55))


class ElixirBar:
	extends Control
	var game: Node

	func _draw() -> void:
		var st0: Dictionary = game.get("st")
		if st0.is_empty():
			return
		var e: float = float(st0["elixir"][0])
		var r: Rect2 = Rect2(Vector2.ZERO, size)
		draw_rect(r, Color("#1b1030"))
		var w: float = (r.size.x - 50.0) / 10.0
		for i: int in 10:
			var cell: Rect2 = Rect2(Vector2(46.0 + float(i) * w, 4.0), Vector2(w - 3.0, r.size.y - 8.0))
			draw_rect(cell, Color("#3a2050"))
			var fill: float = clampf(e - float(i), 0.0, 1.0)
			if fill > 0.0:
				draw_rect(Rect2(cell.position, Vector2(cell.size.x * fill, cell.size.y)), Color("#d94bd9") if fill >= 1.0 else Color("#9b3aa0"))
		draw_circle(Vector2(22, r.size.y * 0.5), 20.0, Color("#2b1140"))
		draw_circle(Vector2(22, r.size.y * 0.5), 16.0, Color("#d94bd9"))
		var f: Font = UI.font if UI.font != null else ThemeDB.fallback_font
		var txt: String = str(int(e))
		var tw: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
		draw_string_outline(f, Vector2(22.0 - tw * 0.5, r.size.y * 0.5 + 9.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, 5, Color(0, 0, 0, 0.8))
		draw_string(f, Vector2(22.0 - tw * 0.5, r.size.y * 0.5 + 9.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)


func _ready() -> void:
	level = Kit.current_level()
	RenderingServer.set_default_clear_color(Color("#2d5a2d"))
	_world = Node2D.new()
	_world.name = "World"
	_world.draw.connect(_draw_world)
	add_child(_world)
	_camera = Camera2D.new()
	add_child(_camera)
	_camera.make_current()
	_camera.position = Vector2(360, 640)
	Juice.register_camera(_camera)
	_reset_state()
	if str(Kit.param("view", "3d")) == "3d":
		view3d = View3D.new()
		add_child(view3d)
		view3d.call("setup", self)
		_world.visible = false
	_build_hud()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "clash", "view": "3d" if view3d != null else "2d"})


func bot_script() -> String:
	return "res://qa/clash_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(14.0, 10.0)


func _reset_state() -> void:
	finished = false
	failed = false
	var lv: Dictionary = level.duplicate()
	if deaths > 0:
		lv["seed"] = M.seed_of(level) + deaths * 131
		lv["map"] = ["arena", "#%d" % (M.seed_of(level) + deaths * 131)]
	st = M.new_state(lv)
	coins = 0
	time_in_level = 0.0
	sel = -1
	dragging = false
	_fx.clear()
	_shots.clear()


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
	_crowns_lbl = Label.new()
	_crowns_lbl.name = "Crowns"
	_crowns_lbl.add_theme_font_size_override("font_size", 32)
	_crowns_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_crowns_lbl.add_theme_constant_override("outline_size", 8)
	_crowns_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_crowns_lbl)
	_timer_lbl = Label.new()
	_timer_lbl.name = "Timer"
	_timer_lbl.add_theme_font_size_override("font_size", 34)
	_timer_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_timer_lbl.add_theme_constant_override("outline_size", 8)
	top.add_child(_timer_lbl)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)
	var grow: Control = Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(grow)
	## Mano: la siguiente pequena a la izquierda y las 4 cartas; debajo, el elixir.
	var hand: HBoxContainer = HBoxContainer.new()
	hand.name = "Hand"
	hand.alignment = BoxContainer.ALIGNMENT_CENTER
	hand.add_theme_constant_override("separation", 8)
	hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(hand)
	_next_card = CardView.new()
	_next_card.name = "NextCard"
	_next_card.set("game", self)
	_next_card.set("slot", -1)
	_next_card.set("small", true)
	_next_card.custom_minimum_size = Vector2(70, 92)
	_next_card.size_flags_vertical = Control.SIZE_SHRINK_END
	_next_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hand.add_child(_next_card)
	for i: int in 4:
		var c: Control = CardView.new()
		c.name = "Card_%d" % i
		c.set("game", self)
		c.set("slot", i)
		c.custom_minimum_size = Vector2(132, 164)
		c.mouse_filter = Control.MOUSE_FILTER_STOP
		c.gui_input.connect(_card_input.bind(i))
		hand.add_child(c)
		_cards.append(c)
	_elixir_bar = ElixirBar.new()
	_elixir_bar.name = "Elixir"
	_elixir_bar.set("game", self)
	_elixir_bar.custom_minimum_size = Vector2(0, 44)
	_elixir_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_elixir_bar)
	_refresh()


func _refresh() -> void:
	if _timer_lbl == null:
		return
	var left: float = maxf(0.0, float(st["time"]) - float(st["t"]))
	_timer_lbl.text = ("%s %d:%02d" % [Kit.text("cl_overtime", "Prorroga"), int(left) / 60, int(left) % 60]) if bool(st["overtime"]) else "%d:%02d" % [int(left) / 60, int(left) % 60]
	if float(st["t"]) > float(st["time"]) - 60.0 and not bool(st["overtime"]) and int(_t * 2.0) % 2 == 0:
		_timer_lbl.add_theme_color_override("font_color", Color("#ff9ad9"))
	else:
		_timer_lbl.remove_theme_color_override("font_color")
	_crowns_lbl.text = Kit.text("cl_crowns", "Coronas {a} - {b}").format({"a": int(st["crowns"][0]), "b": int(st["crowns"][1])})
	for c: Control in _cards:
		c.queue_redraw()
	_next_card.queue_redraw()
	_elixir_bar.queue_redraw()
	var hide: bool = _bot
	for c2: Control in _cards:
		c2.modulate.a = 0.55 if hide else 1.0


# ------------------------------------------------------------------ jugar

func can_act() -> bool:
	return not finished and is_inside_tree() and not get_tree().paused


## De pantalla a la arena (casillas). En 3D, el rayo de la camara contra el suelo.
func screen_to_arena(p: Vector2) -> Vector2:
	if view3d != null:
		return view3d.call("ground_at", p)
	var w: Vector2 = get_canvas_transform().affine_inverse() * p
	return (w - ORIGIN) / S


func arena_to_world(a: Vector2) -> Vector2:
	return ORIGIN + a * S


## Juega la carta elegida en un punto de la arena. Devuelve true si ha salido.
func deploy(slot: int, at: Vector2) -> bool:
	if not can_act():
		return false
	var card: String = str(st["hands"][0][slot])
	if M.play_card(st, 0, slot, at):
		sel = -1
		_sfx("click", -6.0, 0.9)
		Juice.vibrate(12)
		_events()
		return true
	if float(st["elixir"][0]) < float(M.CARDS[card]["cost"]):
		QA.log_event("clash_no_elixir", {"card": card})
	_sfx("click", -14.0, 0.5)
	return false


func _card_input(event: InputEvent, i: int) -> void:
	if not can_act():
		return
	var pressed: int = 0
	if event is InputEventScreenTouch:
		pressed = 1 if (event as InputEventScreenTouch).pressed else 2
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		pressed = 1 if (event as InputEventMouseButton).pressed else 2
	if pressed == 1:
		_bot = false
		sel = i
		dragging = true
		_drag_screen = _cards[i].get_global_rect().get_center()
		drag_arena = Vector2(-1, -1)
		_sfx("click", -12.0, 1.2)
		_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()
		return
	_pointer(event)


func _input(event: InputEvent) -> void:
	## Mientras se arrastra una carta, el dedo se sigue aunque este encima de la mano.
	if dragging and (event is InputEventScreenDrag or event is InputEventMouseMotion):
		_drag_screen = (event as InputEvent).get("position")
		var a: Vector2 = screen_to_arena(_drag_screen)
		drag_arena = a if _drag_screen.y < _hand_top() else Vector2(-1, -1)
	elif dragging and ((event is InputEventScreenTouch and not (event as InputEventScreenTouch).pressed) or (event is InputEventMouseButton and not (event as InputEventMouseButton).pressed)):
		dragging = false
		var pos: Vector2 = (event as InputEvent).get("position")
		if pos.y < _hand_top() and sel >= 0:
			deploy(sel, screen_to_arena(pos))
		drag_arena = Vector2(-1, -1)
		get_viewport().set_input_as_handled()


func _pointer(event: InputEvent) -> void:
	if not can_act() or dragging:
		return
	var pressed: bool = false
	var pos: Vector2 = Vector2.ZERO
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		pressed = true
		pos = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		pressed = true
		pos = (event as InputEventMouseButton).position
	if pressed and sel >= 0 and pos.y < _hand_top():
		## Toca carta y luego toca la arena.
		_bot = false
		deploy(sel, screen_to_arena(pos))


func _hand_top() -> float:
	if _cards.is_empty():
		return 1060.0
	return _cards[0].get_global_rect().position.y - 16.0


func _events() -> void:
	for e: Dictionary in st["events"]:
		match str(e["kind"]):
			"hit":
				if bool(e["ranged"]) and not fast:
					_shots.append({"a": e["a"], "b": e["b"], "t": 0.0, "side": int(e["side"])})
				if view3d != null:
					view3d.call("on_hit", e)
			"spell":
				_fx.append({"p": e["p"], "r": float(e["radius"]), "t": 0.0, "card": str(e["card"])})
				_sfx("hit", -4.0, 0.7 if str(e["card"]) == "fireball" else 1.2)
				if not fast:
					Juice.shake(0.12)
				if view3d != null:
					view3d.call("on_spell", e)
			"die":
				if str(e["kind"]) in ["tower", "king"]:
					_sfx("hurt", -2.0, 0.7)
					if not fast:
						Juice.shake(0.35)
				else:
					_sfx("stomp", -12.0, 1.0 + randf() * 0.2)
				if view3d != null:
					view3d.call("on_die", e)
			"crown":
				if int(e["side"]) == 0:
					coins = int(st["crowns"][0])
					_sfx("coin", -2.0)
					if not fast:
						UI.float_text(_hud, Vector2(360, 380), Kit.text("cl_crown", "\u00a1Corona!"), Color("#ffd23f"), 54)
			"overtime":
				if not fast:
					UI.float_text(_hud, Vector2(360, 520), Kit.text("cl_sudden", "\u00a1Muerte s\u00fabita!"), Color("#ff9ad9"), 48)
			"play":
				if view3d != null:
					view3d.call("on_play", e)
			"end":
				if int(e["winner"]) == 0:
					_finish.call_deferred()
				else:
					_lose.call_deferred()
	(st["events"] as Array).clear()


func _sfx(n: String, vol: float = -10.0, pitch: float = 1.0) -> void:
	if not fast:
		Audio.play(n, 0.05, vol, pitch)


func bot_step() -> void:
	_bot = true


func _physics_process(delta: float) -> void:
	_t += delta
	for f: Dictionary in _fx:
		f["t"] = float(f["t"]) + delta
	_fx = _fx.filter(func(f: Dictionary) -> bool: return float(f["t"]) < 0.5)
	for s: Dictionary in _shots:
		s["t"] = float(s["t"]) + delta * 4.0
	_shots = _shots.filter(func(s: Dictionary) -> bool: return float(s["t"]) < 1.0)
	if finished:
		_world.queue_redraw()
		return
	if fast and auto_retry:
		_bot = true
	## Con prisa (QA) la partida corre 20 veces mas deprisa con pasos de 0,1 s.
	var steps: int = 20 if fast else 1
	var dt: float = 0.1 if fast else delta
	for k: int in steps:
		if finished or bool(st["over"]):
			break
		time_in_level += dt
		if _bot:
			M.think_step(st, 0, dt)
		M.think_step(st, 1, dt)
		M.step(st, dt)
		_events()
	if view3d != null:
		view3d.call("sync", delta)
	_refresh()
	_world.queue_redraw()


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var hp_left: float = 0.0
	for t: Dictionary in M.towers(st, 0):
		hp_left += float(t["hp"])
	var score: int = maxi(1, int(st["crowns"][0]) * 1000 + int(hp_left / 10.0))
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "time": snappedf(time_in_level, 0.1), "crowns": int(st["crowns"][0])})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


## Estrellas = coronas (ganar siempre da al menos una).
func stars_earned() -> int:
	return clampi(int(st["crowns"][0]), 1, 3)


func _lose() -> void:
	if finished:
		return
	finished = true
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "towers", "crowns": (st["crowns"] as Array).duplicate(), "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("cl_lost", "\u00a1Derrota!"),
		Kit.text("cl_fail_hint", "Defiende en tu lado con lo justo y ataca con el elixir que te sobre: un tanque delante y tropas de apoyo detr\u00e1s."))
	p.closed.connect(retry)


func retry() -> void:
	_reset_state()
	if view3d != null:
		view3d.call("rebuild")
	_refresh()


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
		"crowns": (st["crowns"] as Array).duplicate(), "units": (st["ents"] as Array).size(), "played": (st["played"] as Array).duplicate()}


# ------------------------------------------------------------------ dibujo

## Dibujo de cada carta (en la mano y en 2D): forma propia para reconocerla sin leer.
func draw_card_icon(ci: CanvasItem, card: String, c: Vector2, s: float) -> void:
	var steel: Color = Color("#e6ebf2")
	var dark: Color = Color("#2a2a3a")
	match card:
		"knight":
			ci.draw_line(c + Vector2(-18, 22) * s, c + Vector2(18, -22) * s, steel, 8.0 * s)
			ci.draw_line(c + Vector2(-20, 6) * s, c + Vector2(-4, 22) * s, Color("#8a5a2b"), 7.0 * s)
		"archers":
			ci.draw_arc(c + Vector2(-6, 0) * s, 22.0 * s, -PI * 0.45, PI * 0.45, 12, Color("#8a5a2b"), 6.0 * s)
			ci.draw_line(c + Vector2(-2, -20) * s, c + Vector2(-2, 20) * s, steel, 2.0 * s)
			ci.draw_line(c + Vector2(-10, 0) * s, c + Vector2(24, 0) * s, dark, 3.0 * s)
		"giant":
			ci.draw_circle(c, 22.0 * s, Color("#f0c8a0"))
			ci.draw_rect(Rect2(c + Vector2(-16, -6) * s, Vector2(32, 6) * s), Color("#a06a40"))
		"minions":
			ci.draw_circle(c, 13.0 * s, Color("#4a6bd9"))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-10, -2) * s, c + Vector2(-30, -16) * s, c + Vector2(-24, 6) * s]), Color("#2b3f8a"))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(10, -2) * s, c + Vector2(30, -16) * s, c + Vector2(24, 6) * s]), Color("#2b3f8a"))
		"musketeer":
			ci.draw_line(c + Vector2(-22, 10) * s, c + Vector2(24, -12) * s, dark, 7.0 * s)
			ci.draw_circle(c + Vector2(-8, 4) * s, 8.0 * s, Color("#8a5a2b"))
		"skeletons":
			ci.draw_circle(c + Vector2(0, -4) * s, 18.0 * s, Color.WHITE)
			ci.draw_circle(c + Vector2(-7, -6) * s, 5.0 * s, dark)
			ci.draw_circle(c + Vector2(7, -6) * s, 5.0 * s, dark)
			ci.draw_rect(Rect2(c + Vector2(-8, 10) * s, Vector2(16, 8) * s), Color.WHITE)
		"hog":
			ci.draw_line(c + Vector2(-16, 20) * s, c + Vector2(14, -16) * s, Color("#8a5a2b"), 6.0 * s)
			ci.draw_rect(Rect2(c + Vector2(4, -26) * s, Vector2(22, 16) * s), Color("#9aa3ad"))
		"valkyrie":
			ci.draw_line(c + Vector2(0, -22) * s, c + Vector2(0, 24) * s, Color("#8a5a2b"), 5.0 * s)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -22) * s, c + Vector2(22, -14) * s, c + Vector2(22, 6) * s, c + Vector2(0, -2) * s]), steel)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -22) * s, c + Vector2(-22, -14) * s, c + Vector2(-22, 6) * s, c + Vector2(0, -2) * s]), steel)
		"babydragon":
			ci.draw_circle(c, 16.0 * s, Color("#4caf50"))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(10, -6) * s, c + Vector2(30, -14) * s, c + Vector2(26, 4) * s]), Color("#ff9a3c"))
			ci.draw_circle(c + Vector2(-5, -5) * s, 3.0 * s, dark)
		"cannon":
			ci.draw_rect(Rect2(c + Vector2(-20, 4) * s, Vector2(40, 16) * s), Color("#6b4a2b"))
			ci.draw_line(c + Vector2(-6, 6) * s, c + Vector2(20, -16) * s, dark, 12.0 * s)
		"fireball":
			ci.draw_circle(c, 20.0 * s, Color("#ff7a1a"))
			ci.draw_circle(c + Vector2(-4, -4) * s, 11.0 * s, Color("#ffd23f"))
		"arrows":
			for k: int in 3:
				var o: Vector2 = Vector2(-14 + 14 * k, 0) * s
				ci.draw_line(c + o + Vector2(0, 22) * s, c + o + Vector2(0, -16) * s, Color("#8a5a2b"), 3.0 * s)
				ci.draw_colored_polygon(PackedVector2Array([c + o + Vector2(-6, -14) * s, c + o + Vector2(6, -14) * s, c + o + Vector2(0, -26) * s]), steel)


func _draw_world() -> void:
	if st.is_empty() or view3d != null:
		return
	var arena: Rect2 = Rect2(ORIGIN, Vector2(M.W, M.H) * S)
	_world.draw_rect(arena.grow(8.0), Color("#3b2a1a"))
	for y: int in int(M.H):
		for x: int in int(M.W):
			_world.draw_rect(Rect2(ORIGIN + Vector2(x, y) * S, Vector2(S, S)), Color("#7cc45a") if (x + y) % 2 == 0 else Color("#72b852"))
	_world.draw_rect(Rect2(ORIGIN + Vector2(0, M.RIVER_TOP) * S, Vector2(M.W, M.RIVER_BOT - M.RIVER_TOP) * S), Color("#3fa7e0"))
	for bx: float in M.BRIDGES:
		_world.draw_rect(Rect2(ORIGIN + Vector2(bx - 1.0, M.RIVER_TOP - 0.2) * S, Vector2(2.0, M.RIVER_BOT - M.RIVER_TOP + 0.4) * S), Color("#a0703a"))
	if dragging and sel >= 0 and not bool(M.CARDS[str(st["hands"][0][sel])].get("spell", false)):
		_world.draw_rect(Rect2(ORIGIN, Vector2(M.W, M.RIVER_BOT) * S), Color(1, 0.2, 0.2, 0.18))
	for e: Dictionary in st["ents"]:
		var p: Vector2 = arena_to_world(e["p"])
		var col: Color = TEAM[int(e["side"])]
		var kind: String = str(e.get("kind", ""))
		if kind == "tower" or kind == "king":
			var rr: float = float(e["r"]) * S
			_world.draw_rect(Rect2(p - Vector2(rr, rr), Vector2(rr, rr) * 2.0), col.darkened(0.3))
			_world.draw_rect(Rect2(p - Vector2(rr, rr) * 0.7, Vector2(rr, rr) * 1.4), col if kind == "tower" or bool(e["active"]) else col.darkened(0.5))
		else:
			if bool(e.get("air", false)):
				_world.draw_circle(p + Vector2(0, 10), float(e["r"]) * S * 0.8, Color(0, 0, 0, 0.25))
				p.y -= 10.0
			_world.draw_circle(p, float(e["r"]) * S + 3.0, col.darkened(0.4))
			draw_card_icon(_world, str(e["card"]), p, float(e["r"]) * S / 26.0)
		var frac: float = float(e["hp"]) / maxf(1.0, float(e["max"]))
		if frac < 1.0:
			var bw: float = maxf(26.0, float(e["r"]) * S * 2.0)
			_world.draw_rect(Rect2(p + Vector2(-bw * 0.5, -float(e["r"]) * S - 10.0), Vector2(bw, 5)), Color(0, 0, 0, 0.6))
			_world.draw_rect(Rect2(p + Vector2(-bw * 0.5, -float(e["r"]) * S - 10.0), Vector2(bw * frac, 5)), col.lightened(0.2))
	for s: Dictionary in _shots:
		var q: Vector2 = arena_to_world((s["a"] as Vector2).lerp(s["b"], float(s["t"])))
		_world.draw_circle(q, 4.0, TEAM[int(s["side"])].lightened(0.4))
	for f: Dictionary in _fx:
		var k: float = float(f["t"]) / 0.5
		_world.draw_circle(arena_to_world(f["p"]), float(f["r"]) * S * (0.6 + 0.4 * k), Color(1.0, 0.55, 0.1, 0.5 * (1.0 - k)))
	if dragging and sel >= 0 and drag_arena.x >= 0.0:
		var card: String = str(st["hands"][0][sel])
		var ok: bool = M.can_drop(0, card, drag_arena)
		var rad: float = float(M.CARDS[card].get("radius", 0.8)) * S
		_world.draw_circle(arena_to_world(drag_arena), rad, Color(0.3, 1, 0.4, 0.35) if ok else Color(1, 0.3, 0.3, 0.35))
