extends Node2D
## Lanza cuchillos: toca para lanzar; el cuchillo se clava abajo del tronco que gira. Si choca con
## otro, se pierde. Clava todos y el tronco se parte. Las manzanas del borde dan monedas.
## Reglas, bot y analizador en knifehit_map.gd.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel al acabar.

const M = preload("res://kit/knifehit/knifehit_map.gd")

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

var _view: Control
var _info: Label
var _shake: float = 0.0
var _bounce: float = -1.0
var _break_t: float = -1.0
var _hit_flash: float = 0.0
var _wood: Color = Color("#c98b4f")


func _ready() -> void:
	level = Kit.current_level()
	RenderingServer.set_default_clear_color(Color("#1f2433"))
	if bool(level.get("boss", false)):
		_wood = Color("#8d99ae")
	_build_hud()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "knifehit", "knives": int(st["to_throw"])})


func bot_script() -> String:
	return "res://qa/knifehit_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(2.0, 1.6)


func _reset() -> void:
	finished = false
	failed = false
	st = M.new_state(level)
	coins_total = (st["apples"] as Array).size()
	coins = 0
	time_in_level = 0.0
	_bounce = -1.0
	_break_t = -1.0
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
	col.add_theme_constant_override("separation", 8)
	safe.add_child(col)
	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top)
	_info = Label.new()
	_info.name = "Info"
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.clip_text = true
	_info.add_theme_font_size_override("font_size", 28)
	top.add_child(_info)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)
	_view = Control.new()
	_view.name = "View"
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.draw.connect(_draw_view)
	_view.gui_input.connect(_on_input)
	col.add_child(_view)


func can_act() -> bool:
	return not finished and not failed and is_inside_tree() and not get_tree().paused and not st.is_empty()


func throw_knife() -> bool:
	if not can_act() or _break_t >= 0.0:
		return false
	if M.throw(st):
		_sfx("shoot", -8.0)
		return true
	return false


func bot_step() -> void:
	if can_act() and M.bot_should_throw(st):
		throw_knife()


func _on_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		throw_knife()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and not DisplayServer.is_touchscreen_available():
		throw_knife()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("jump"):
		throw_knife()


func _sfx(n: String, vol: float = -6.0) -> void:
	if not fast:
		Audio.play(n, 0.1, vol)


func _refresh() -> void:
	if st.is_empty() or _info == null:
		return
	var left: int = int(st["to_throw"]) - int(st["thrown"])
	_info.text = Kit.text("kh_left", "Cuchillos {n}").format({"n": left}) + ("   " + Kit.text("kh_boss", "JEFE") if bool(level.get("boss", false)) else "")
	_view.queue_redraw()


func _physics_process(delta: float) -> void:
	if st.is_empty() or get_tree().paused:
		return
	_shake = maxf(0.0, _shake - delta * 3.0)
	_hit_flash = maxf(0.0, _hit_flash - delta * 4.0)
	if _bounce >= 0.0:
		_bounce += delta
	if _break_t >= 0.0:
		_break_t += delta
		_view.queue_redraw()
		if _break_t > (0.05 if fast else 0.9):
			_finish()
		return
	if finished or failed:
		_view.queue_redraw()
		return
	time_in_level += delta
	if fast and auto_retry:
		bot_step()
	var out: Dictionary = M.step(st, delta)
	if not out.is_empty():
		if bool(out["ok"]):
			_hit_flash = 1.0
			_shake = 0.4
			_sfx("land", -4.0)
			if bool(out["apple"]):
				coins = int(st["got"])
				_sfx("coin", -4.0)
		_refresh()
		if bool(st["lost"]):
			_lose()
		elif bool(st["won"]):
			_break_t = 0.0
			_sfx("stomp", -2.0)
	_view.queue_redraw()


# ------------------------------------------------------------------ dibujo

func _log_center() -> Vector2:
	return Vector2(_view.size.x * 0.5, _view.size.y * 0.32) + Vector2(sin(time_in_level * 60.0), cos(time_in_level * 47.0)) * _shake * 10.0


func _log_r() -> float:
	return minf(_view.size.x * 0.28, 170.0)


func _draw_knife(tip: Vector2, dir: Vector2, len_k: float, alpha: float = 1.0) -> void:
	var side: Vector2 = dir.orthogonal()
	var blade: PackedVector2Array = PackedVector2Array([tip, tip - dir * len_k * 0.55 + side * len_k * 0.09, tip - dir * len_k * 0.55 - side * len_k * 0.09])
	_view.draw_colored_polygon(blade, Color(0.86, 0.89, 0.93, alpha))
	var h0: Vector2 = tip - dir * len_k * 0.55
	_view.draw_line(h0 + side * len_k * 0.13, h0 - side * len_k * 0.13, Color(0.35, 0.37, 0.42, alpha), len_k * 0.05)
	_view.draw_line(h0, tip - dir * len_k, Color(0.48, 0.27, 0.15, alpha), len_k * 0.11)


func _draw_view() -> void:
	if st.is_empty():
		return
	var c: Vector2 = _log_center()
	var r: float = _log_r()
	var rot: float = deg_to_rad(float(st["rot"]))
	var len_k: float = r * 0.75
	if _break_t >= 0.0:
		var k: float = _break_t * 600.0
		for q: int in 4:
			var a: float = TAU * float(q) / 4.0 + rot
			var off: Vector2 = Vector2(cos(a + 0.6), sin(a + 0.6)) * k + Vector2(0, k * k * 0.002)
			_view.draw_circle(c + off, r * 0.5, _wood.darkened(0.1 * q))
		return
	for kn: Variant in st["knives"]:
		var a2: float = deg_to_rad(float(kn)) + rot
		var dir: Vector2 = Vector2(cos(a2), sin(a2))
		_draw_knife(c + dir * (r - len_k * 0.12), -dir, len_k)
	_view.draw_circle(c, r, _wood.lerp(Color.WHITE, _hit_flash * 0.25))
	for ring: int in 3:
		_view.draw_arc(c, r * (0.3 + 0.22 * ring), 0.0, TAU, 40, _wood.darkened(0.18), 3.0)
	for s: int in 6:
		var a3: float = rot + TAU * float(s) / 6.0
		_view.draw_line(c + Vector2(cos(a3), sin(a3)) * r * 0.2, c + Vector2(cos(a3), sin(a3)) * r * 0.9, _wood.darkened(0.1), 2.0)
	_view.draw_arc(c, r, 0.0, TAU, 48, _wood.darkened(0.35), 6.0)
	for ap: Variant in st["apples"]:
		var a4: float = deg_to_rad(float(ap)) + rot
		var p: Vector2 = c + Vector2(cos(a4), sin(a4)) * (r + 18.0)
		_view.draw_circle(p, 18.0, Color("#e74c3c"))
		_view.draw_line(p + Vector2(0, -16), p + Vector2(4, -26), Color("#5d3a1a"), 3.0)
	## El cuchillo que vuela (o el que espera abajo) y el que rebota si choca.
	var base_y: float = _view.size.y * 0.86
	var fl: float = float(st["flying"])
	var hit_y: float = c.y + r + len_k * 0.12
	if failed and _bounce >= 0.0:
		var bp: Vector2 = Vector2(c.x + _bounce * 260.0, hit_y + 60.0 + _bounce * _bounce * 900.0)
		_draw_knife(bp, Vector2(sin(_bounce * 14.0), -cos(_bounce * 14.0)), len_k)
	elif fl >= 0.0:
		var k2: float = 1.0 - fl / M.FLY_T
		_draw_knife(Vector2(c.x, lerpf(base_y, hit_y, k2)), Vector2(0, -1), len_k)
	elif int(st["thrown"]) < int(st["to_throw"]) and not finished:
		_draw_knife(Vector2(c.x, base_y), Vector2(0, -1), len_k)
	## Cuchillos que quedan (abajo a la izquierda).
	var left: int = int(st["to_throw"]) - int(st["thrown"])
	for i: int in mini(left, 16):
		var y: float = _view.size.y - 30.0 - float(i) * 26.0
		_view.draw_line(Vector2(30, y), Vector2(70, y), Color("#dfe6ee"), 8.0)


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	_break_t = -1.0
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = maxi(1, int(st["to_throw"]) * 50 + int(st["got"]) * 150)
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "apples": int(st["got"]), "time": snappedf(time_in_level, 0.1)})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


## Estrellas por manzanas: todas (o no habia), 3; la mitad o mas, 2; si no, 1.
func stars_earned() -> int:
	if coins_total == 0 or coins >= coins_total:
		return 3
	return 2 if coins * 2 >= coins_total else 1


func _lose() -> void:
	if failed:
		return
	failed = true
	deaths += 1
	_bounce = 0.0
	_shake = 1.0
	QA.log_event("death", {"cause": "knifehit", "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("kh_lost", "\u00a1Choque!"), Kit.text("kh_lost_hint", "Espera a que abajo del tronco haya hueco libre y entonces lanza."))
	p.closed.connect(retry)


func retry() -> void:
	_reset()

## Segunda oportunidad (anuncio con premio, lo ofrece el panel de derrota): sigue la partida.
func revive() -> void:
	failed = false
	_bounce = -1.0
	_shake = 0.0



func open_pause() -> void:
	if finished or get_tree().paused or get_node_or_null("PauseMenu") != null:
		return
	PauseMenu.open(self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_inside_tree() and not UI.test_mode:
			open_pause()


func bot_state() -> Dictionary:
	return {"deaths": deaths, "coins": coins, "finished": finished, "failed": failed, "stomps": 0, "time": time_in_level,
		"thrown": int(st.get("thrown", 0)), "apples": int(st.get("got", 0))}
