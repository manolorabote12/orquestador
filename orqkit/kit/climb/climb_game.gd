extends Node2D
## Escalada (estilo Hill Climb Racing): GAS a la derecha y FRENO a la izquierda. Llega a la meta
## sin volcar (si la cabeza del conductor toca el suelo, se acabo) y sin quedarte sin gasolina:
## coge los bidones por el camino. En el aire, el gas levanta el morro y el freno lo baja.
## Fisica, bot y analizador en climb_map.gd (la misma para todos). Las mejoras del taller
## (motor, suspension, ruedas, deposito) se compran en la tienda con monedas.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const M = preload("res://kit/climb/climb_map.gd")
const PX: float = 56.0
const UPS: Array[String] = ["motor", "suspension", "ruedas", "deposito"]

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
var gas: bool = false
var brake: bool = false
var _gas_touch: bool = false
var _brake_touch: bool = false

var _world: Node2D
var _camera: Camera2D
var _hud: Control
var _dist_lbl: Label
var _coins_lbl: Label
var _fuel_bar: Control
var _gas_btn: Button
var _brake_btn: Button
var _bot: bool = false
var _acc: float = 0.0
var _t: float = 0.0
var _hero_tex: Texture2D = null
var _body: Color = Color("#e8b04b")
var _ground_col: Color = Color("#6fae4f")


class FuelGauge:
	extends Control
	var game: Node

	func _draw() -> void:
		var st0: Dictionary = game.get("st")
		if st0.is_empty():
			return
		var f: float = clampf(float(st0["fuel"]) / maxf(1.0, float(st0["tank"])), 0.0, 1.0)
		var r: Rect2 = Rect2(Vector2(46, 8), Vector2(size.x - 54.0, size.y - 16.0))
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.35))
		draw_rect(r, Color("#2a2a2a"))
		var col: Color = Color("#4caf50").lerp(Color("#e53950"), clampf(1.0 - f * 2.5, 0.0, 1.0))
		if f < 0.2 and int(Time.get_ticks_msec() / 250) % 2 == 0:
			col = col.lightened(0.4)
		draw_rect(Rect2(r.position, Vector2(r.size.x * f, r.size.y)), col)
		## Bidon.
		var c: Vector2 = Vector2(22, size.y * 0.5)
		draw_rect(Rect2(c - Vector2(12, 14), Vector2(24, 28)), Color("#e53950"))
		draw_rect(Rect2(c + Vector2(2, -20), Vector2(9, 7)), Color("#e53950"))
		draw_line(c + Vector2(-7, -8), c + Vector2(7, 8), Color("#ffd23f"), 3.0)


func _ready() -> void:
	level = Kit.current_level()
	par = float(level.get("par", 0))
	RenderingServer.set_default_clear_color(Kit.color("sky", Color("#7ec8f0")))
	_body = Kit.color("accent", Color("#e8b04b"))
	_ground_col = Kit.color("ground", Color("#6fae4f"))
	if _ground_col.get_luminance() < 0.2 or _ground_col.s < 0.2:
		_ground_col = Color("#6fae4f")
	var hero: Dictionary = Kit.sprite_by_role("jugador")
	if not hero.is_empty():
		var sf: SpriteFrames = SpriteKit.frames_de(hero)
		for anim: String in sf.get_animation_names():
			if sf.get_frame_count(anim) > 0:
				_hero_tex = sf.get_frame_texture(anim, 0)
				break
	_world = Node2D.new()
	_world.name = "World"
	_world.draw.connect(_draw_world)
	add_child(_world)
	_camera = Camera2D.new()
	add_child(_camera)
	_camera.make_current()
	Juice.register_camera(_camera)
	_build_hud()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "climb", "goal": float(st["info"]["goal"])})


func bot_script() -> String:
	return "res://qa/climb_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(6.0, 4.0)


func ups() -> Dictionary:
	var out: Dictionary = {}
	for u: String in UPS:
		out[u] = Save.upgrade_level(u)
	return out


func _reset() -> void:
	finished = false
	failed = false
	st = M.new_state(level, ups())
	coins_total = (st["info"]["coins"] as Array).size()
	coins = 0
	time_in_level = 0.0
	gas = false
	brake = false
	_gas_touch = false
	_brake_touch = false
	_acc = 0.0
	_camera.position = world(st["p"]) + Vector2(160, -60)
	_refresh()


func world(m: Vector2) -> Vector2:
	return Vector2(m.x * PX, -m.y * PX)


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
	var safe: MarginContainer = UI.safe_root(_hud, 14.0)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col: VBoxContainer = VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 8)
	safe.add_child(col)
	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 12)
	col.add_child(top)
	_dist_lbl = _label(32)
	_dist_lbl.name = "Distance"
	_dist_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_dist_lbl)
	top.add_child(UiIcon.make("coin", Kit.color("coin", UI.colors["acento"]), 40.0))
	_coins_lbl = _label(30)
	_coins_lbl.name = "Coins"
	top.add_child(_coins_lbl)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)
	_fuel_bar = FuelGauge.new()
	_fuel_bar.name = "Fuel"
	_fuel_bar.set("game", self)
	_fuel_bar.custom_minimum_size = Vector2(0, 46)
	_fuel_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_fuel_bar)
	var grow: Control = Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(grow)
	var pedals: HBoxContainer = HBoxContainer.new()
	pedals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(pedals)
	_brake_btn = _pedal("BtnBrake", Kit.text("hc_brake", "FRENO"), Color("#e53950"))
	_brake_btn.button_down.connect(func() -> void:
		_brake_touch = true
		_bot = false)
	_brake_btn.button_up.connect(func() -> void: _brake_touch = false)
	pedals.add_child(_brake_btn)
	var mid: Control = Control.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pedals.add_child(mid)
	_gas_btn = _pedal("BtnGas", Kit.text("hc_gas", "GAS"), Color("#43a047"))
	_gas_btn.button_down.connect(func() -> void:
		_gas_touch = true
		_bot = false)
	_gas_btn.button_up.connect(func() -> void: _gas_touch = false)
	pedals.add_child(_gas_btn)


func _label(sz: int) -> Label:
	var l: Label = Label.new()
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _pedal(nm: String, text: String, col: Color) -> Button:
	var b: Button = UI.make_button(text, true)
	b.name = nm
	b.custom_minimum_size = Vector2(230, 190)
	b.add_theme_font_size_override("font_size", 40)
	b.self_modulate = col.lerp(Color.WHITE, 0.25)
	b.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	return b


func _refresh() -> void:
	if _dist_lbl == null or st.is_empty():
		return
	var x: float = maxf(0.0, (st["p"] as Vector2).x - 6.0)
	var goal: float = float(st["info"]["goal"]) - 6.0
	_dist_lbl.text = "%d / %d m" % [int(x), int(goal)]
	_coins_lbl.text = str(coins)
	_fuel_bar.queue_redraw()


# ------------------------------------------------------------------ jugar

func can_act() -> bool:
	return not finished and is_inside_tree() and not get_tree().paused


func bot_step() -> void:
	_bot = true


func _physics_process(delta: float) -> void:
	_t += delta
	if finished:
		_world.queue_redraw()
		return
	if fast and auto_retry:
		_bot = true
	## Pedales (dedo) o teclado.
	var key_gas: bool = Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D)
	var key_brake: bool = Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A)
	if key_gas or key_brake:
		_bot = false
	gas = _gas_touch or key_gas
	brake = _brake_touch or key_brake
	## Pasos fijos de fisica (con prisa, muchos por fotograma).
	_acc += delta if not fast else 0.35
	var n: int = 0
	while _acc >= M.DT and n < 60:
		_acc -= M.DT
		n += 1
		var g: bool = gas
		var b: bool = brake
		if _bot:
			var inp: Array = M.bot_input(st, 0.5)
			g = bool(inp[0])
			b = bool(inp[1])
		M.step(st, g, b)
		time_in_level += M.DT
		_events()
		if finished or bool(st["over"]):
			break
	## Camara: por delante del coche y algo mas lejos cuanto mas rapido.
	var v: Vector2 = st["v"]
	var want: Vector2 = world(st["p"]) + Vector2(170.0 + v.x * 6.0, -30.0)
	_camera.position = _camera.position.lerp(want, minf(1.0, delta * 5.0))
	var z: float = clampf(1.0 - v.length() / 70.0, 0.72, 1.0)
	_camera.zoom = _camera.zoom.lerp(Vector2(z, z), minf(1.0, delta * 2.0))
	_refresh()
	_world.queue_redraw()


func _events() -> void:
	for e: Dictionary in st["events"]:
		match str(e["kind"]):
			"coin":
				coins += 1
				_sfx("coin", -8.0, 1.0 + 0.04 * float(coins % 6))
			"fuel":
				_sfx("powerup", -4.0)
				_toast(Kit.text("hc_fuel", "\u00a1Gasolina!"), Color("#ff7043"))
			"flip":
				coins += 5 * int(e["n"])
				_sfx("coin", -2.0, 1.3)
				_toast(Kit.text("hc_flip", "\u00a1Vuelta! +{n}").format({"n": 5 * int(e["n"])}), Color("#ffd23f"))
			"air":
				coins += 2
				_toast(Kit.text("hc_air", "\u00a1En el aire! +2"), Color("#8be0ff"))
			"end":
				if bool(e["won"]):
					_finish.call_deferred()
				else:
					_lose.call_deferred(str(e["cause"]))
	(st["events"] as Array).clear()


func _toast(text: String, col: Color) -> void:
	if not fast:
		UI.float_text(_hud, Vector2(360, 420), text, col, 44)


func _sfx(nm: String, vol: float = -10.0, pitch: float = 1.0) -> void:
	if not fast:
		Audio.play(nm, 0.05, vol, pitch)


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = maxi(1, coins * 20 + int(float(st["fuel"])) * 5 + maxi(0, int(par - time_in_level)) * 15)
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "time": snappedf(time_in_level, 0.1), "coins": coins})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


func stars_earned() -> int:
	if par <= 0.0 or time_in_level <= par:
		return 3
	return 2 if time_in_level <= par * 1.35 else 1


func _lose(cause: String = "crash") -> void:
	if finished:
		return
	finished = true
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": cause, "x": snappedf((st["p"] as Vector2).x, 0.1), "deaths": deaths})
	Audio.play("hurt")
	if cause == "crash":
		Juice.shake(0.4)
	if auto_retry:
		retry.call_deferred()
		return
	var title: String = Kit.text("hc_lost_fuel", "\u00a1Sin gasolina!") if cause == "fuel" else Kit.text("hc_lost_crash", "\u00a1Has volcado!")
	var p: FailPanel = FailPanel.open(self, title,
		Kit.text("hc_fail_hint", "Suelta el gas si el morro sube mucho y frena antes de las bajadas. En el aire, el gas levanta el morro y el freno lo baja. Mejora el coche en la tienda."))
	p.closed.connect(retry)


## Segunda oportunidad (FailPanel, con anuncio): el coche de pie donde volco y medio deposito.
func revive() -> void:
	var p: Vector2 = st["p"]
	st["p"] = Vector2(p.x, M.ground(st["info"], p.x) + M.REST + M.WHEEL_R + 0.35)
	st["a"] = 0.0
	st["v"] = Vector2.ZERO
	st["w"] = 0.0
	st["over"] = false
	st["cause"] = ""
	st["stuck_t"] = 0.0
	st["fuel"] = maxf(float(st["fuel"]), float(st["tank"]) * 0.5)
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
	if st.is_empty():
		return {}
	return {"deaths": deaths, "coins": coins, "finished": finished, "failed": failed, "time": time_in_level,
		"x": (st["p"] as Vector2).x, "goal": float(st["info"]["goal"]), "fuel": float(st["fuel"])}


# ------------------------------------------------------------------ dibujo

func _draw_world() -> void:
	if st.is_empty():
		return
	var info: Dictionary = st["info"]
	var cam: Vector2 = _camera.position
	var half: Vector2 = get_viewport_rect().size * 0.5 / _camera.zoom
	var x0: float = (cam.x - half.x) / PX - 2.0
	var x1: float = (cam.x + half.x) / PX + 2.0
	## Cielo con montanas lejanas (se mueven mas despacio que el suelo).
	var sky: Color = Kit.color("sky", Color("#7ec8f0"))
	for layer: int in 2:
		var k: float = 0.15 + 0.2 * float(layer)
		var pts: PackedVector2Array = PackedVector2Array()
		var base: float = cam.y + half.y + 50.0
		pts.append(Vector2(cam.x - half.x - 40.0, base))
		var sx: float = cam.x - half.x - 40.0
		while sx <= cam.x + half.x + 40.0:
			## Las montanas avanzan con la camara (las lejanas, casi a su paso: se mueven poco).
			var u: float = sx - cam.x * (1.0 - k)
			var hh: float = sin(u * 0.004 + float(layer) * 2.0) * 90.0 + sin(u * 0.011) * 40.0
			pts.append(Vector2(sx, cam.y - 40.0 + float(layer) * 120.0 - hh))
			sx += 40.0
		pts.append(Vector2(cam.x + half.x + 40.0, base))
		_world.draw_colored_polygon(pts, sky.darkened(0.12 + 0.12 * float(layer)).lerp(_ground_col, 0.15 + 0.15 * float(layer)))
	## Nubes lejanas.
	for c: int in 6:
		var cxp: float = fposmod(float(c) * 420.0 - cam.x * 0.1, 2520.0) + cam.x - half.x - 300.0
		var cyp: float = cam.y - half.y + 120.0 + float((c * 97) % 5) * 60.0
		for b: int in 3:
			_world.draw_circle(Vector2(cxp + float(b) * 46.0, cyp - (18.0 if b == 1 else 0.0)), 38.0 if b == 1 else 30.0, Color(1, 1, 1, 0.55))
	## Suelo: hierba arriba y tierra con capas debajo.
	var step: float = 0.5
	var x: float = maxf(0.0, x0)
	var dirt: Color = Color("#8a5a2b")
	while x < minf(x1, float(info["length"])):
		var a: Vector2 = world(Vector2(x, M.ground(info, x)))
		var b: Vector2 = world(Vector2(x + step, M.ground(info, x + step)))
		var bottom: float = cam.y + half.y + 80.0
		_world.draw_colored_polygon(PackedVector2Array([a, b, Vector2(b.x, bottom), Vector2(a.x, bottom)]), dirt)
		_world.draw_colored_polygon(PackedVector2Array([a + Vector2(0, 26), b + Vector2(0, 26), Vector2(b.x, b.y + 60), Vector2(a.x, a.y + 60)]), dirt.darkened(0.15))
		_world.draw_colored_polygon(PackedVector2Array([a - Vector2(0, 2), b - Vector2(0, 2), b + Vector2(0, 16), a + Vector2(0, 16)]), _ground_col)
		x += step
	## Meta, bidones y monedas.
	var gx: float = float(info["goal"])
	if gx > x0 and gx < x1:
		var gp: Vector2 = world(Vector2(gx, M.ground(info, gx)))
		_world.draw_line(gp, gp - Vector2(0, 200), Color("#5a4632"), 6.0)
		for r: int in 3:
			for c: int in 6:
				_world.draw_rect(Rect2(gp + Vector2(3 + c * 16, -200 + r * 16), Vector2(16, 16)), Color.WHITE if (r + c) % 2 == 0 else Color("#222222"))
	for i: int in (info["fuel"] as Array).size():
		var fx: float = float(info["fuel"][i])
		if fx < x0 or fx > x1 or (st["fuel_got"] as Array).has(i):
			continue
		var fp: Vector2 = world(Vector2(fx, M.ground(info, fx) + 0.9)) + Vector2(0, sin(_t * 3.0 + fx) * 5.0)
		_world.draw_rect(Rect2(fp - Vector2(20, 26), Vector2(40, 52)), Color("#c62828"))
		_world.draw_rect(Rect2(fp - Vector2(16, 22), Vector2(32, 44)), Color("#e53950"))
		_world.draw_rect(Rect2(fp + Vector2(4, -36), Vector2(12, 10)), Color("#c62828"))
		_world.draw_line(fp + Vector2(-10, -12), fp + Vector2(10, 12), Color("#ffd23f"), 4.0)
	var coin_c: Color = Kit.color("coin", Color("#f6cf7a"))
	for j: int in (info["coins"] as Array).size():
		var cx: float = float(info["coins"][j])
		if cx < x0 or cx > x1 or (st["coins_got"] as Array).has(j):
			continue
		var cp: Vector2 = world(Vector2(cx, M.ground(info, cx) + 1.1))
		var sq: float = absf(cos(_t * 3.0 + float(j)))
		_world.draw_set_transform(cp, 0.0, Vector2(maxf(0.2, sq), 1.0))
		_world.draw_circle(Vector2.ZERO, 15.0, coin_c.darkened(0.25))
		_world.draw_circle(Vector2.ZERO, 11.0, coin_c)
		_world.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_car()


func _draw_car() -> void:
	var a: float = float(st["a"])
	var p: Vector2 = world(st["p"])
	## Ruedas con su suspension (debajo del chasis).
	for i: int in 2:
		var mount: Vector2 = M.to_world(st, M.MOUNTS[i])
		var down: Vector2 = Vector2(0, -1).rotated(a)
		var wc: Vector2 = mount + down * (M.REST - float(st["comp"][i]))
		var wp: Vector2 = world(wc)
		_world.draw_line(world(mount), wp, Color("#555555"), 7.0)
		var r: float = M.WHEEL_R * PX
		_world.draw_circle(wp, r, Color("#222222"))
		_world.draw_circle(wp, r * 0.55, Color("#9aa3ad"))
		var rot: float = -float(st["wheel_rot"][i])
		for k: int in 3:
			var d: Vector2 = Vector2(cos(rot + TAU * float(k) / 3.0), sin(rot + TAU * float(k) / 3.0)) * r * 0.5
			_world.draw_line(wp - d, wp + d, Color("#5a6470"), 4.0)
	## Chasis (todoterreno), con el conductor y su cabeza (el arte del juego si lo hay).
	_world.draw_set_transform(p, -a, Vector2.ONE)
	var s: float = PX
	var body: PackedVector2Array = PackedVector2Array([Vector2(-1.4, 0.15) * s, Vector2(1.45, 0.15) * s, Vector2(1.45, -0.25) * s,
		Vector2(1.0, -0.35) * s, Vector2(0.55, -0.35) * s, Vector2(0.35, -0.05) * s, Vector2(-1.4, -0.05) * s])
	var shadow: PackedVector2Array = PackedVector2Array()
	for q: Vector2 in body:
		shadow.append(q + Vector2(0, 6))
	_world.draw_colored_polygon(shadow, Color(0, 0, 0, 0.25))
	_world.draw_colored_polygon(body, _body)
	_world.draw_line(Vector2(-1.4, 0.15) * s, Vector2(1.45, 0.15) * s, _body.darkened(0.4), 5.0)
	_world.draw_rect(Rect2(Vector2(0.6, -0.3) * s, Vector2(0.35, 0.2) * s), Color(0.8, 0.95, 1.0, 0.85))
	## Conductor: cuerpo y cabeza (la cabeza es lo que no puede tocar el suelo).
	_world.draw_line(Vector2(-0.15, -0.05) * s, Vector2(-0.15, -0.6) * s, Color("#3d5afe"), 16.0)
	var head: Vector2 = Vector2(M.HEAD.x, -M.HEAD.y) * s
	if _hero_tex != null:
		var hs: float = 0.62 * s
		_world.draw_texture_rect(_hero_tex, Rect2(head - Vector2(hs, hs) * 0.5, Vector2(hs, hs)), false)
	else:
		_world.draw_circle(head, 0.25 * s, Color("#f6d2b0"))
		_world.draw_arc(head - Vector2(0, 2), 0.26 * s, PI, TAU, 12, Color("#e53950"), 9.0)
	_world.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
