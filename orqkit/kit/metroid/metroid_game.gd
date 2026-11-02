extends Node2D
## Metroidvania: flechas para andar, boton de saltar (otra vez en el aire con el doble salto),
## impulso y golpe. Explora las salas, consigue habilidades y vuelve a las puertas que no podias
## cruzar. El minimapa ensena las salas visitadas. Reglas, bot y analizador en metroid_map.gd.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const M = preload("res://kit/metroid/metroid_map.gd")
const DT: float = 1.0 / float(M.TPS)
const TILE: float = 56.0
const ITEM_COL: Dictionary = {"J": "#4cc9f0", "D": "#ffd166", "B": "#ef476f", "K": "#f4a261", "$": "#ffd54f", "+": "#ff6b81"}

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
var hold: Dictionary = {"left": false, "right": false}
var want_jump: bool = false
var want_dash: bool = false
var want_attack: bool = false

var _view: Control
var _hud: Control
var _btn_dash: Button
var _tile_tex: Texture2D = null
var _hero_tex: Texture2D = null
var _foe_tex: Texture2D = null
var _acc: float = 0.0
var _prev: Vector2 = Vector2.ZERO
var _prev_en: Array = []
var _cam: Vector2 = Vector2.ZERO
var _fx: Array = []
var _log_seen: int = 0
var _t: float = 0.0
var _swing: float = 0.0
var _toast: String = ""
var _toast_t: float = 0.0


func _ready() -> void:
	level = Kit.current_level()
	RenderingServer.set_default_clear_color(Color("#141726"))
	_tile_tex = Kit.first_tile_texture()
	_hero_tex = _tex_of(Kit.sprite_by_role("jugador"))
	_foe_tex = _tex_of(Kit.sprite_by_role("enemigo"))
	_build_hud()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "metroid"})


func _tex_of(d: Dictionary) -> Texture2D:
	if d.is_empty():
		return null
	var sf: SpriteFrames = SpriteKit.frames_de(d)
	for anim: String in sf.get_animation_names():
		if sf.get_frame_count(anim) > 0:
			return sf.get_frame_texture(anim, 0)
	return null


func wants_grade() -> bool:
	return false


func bot_script() -> String:
	return "res://qa/metroid_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(3.0, 3.0)


func _reset() -> void:
	finished = false
	failed = false
	st = M.new_state(level)
	coins_total = int(st["coins_total"])
	coins = 0
	time_in_level = 0.0
	_acc = 0.0
	_fx = []
	_log_seen = 0
	_prev = Vector2(st["p"])
	_cam = _prev
	_snap_enemies()
	hold = {"left": false, "right": false}
	want_jump = false
	want_dash = false
	want_attack = false


func _snap_enemies() -> void:
	_prev_en = []
	for e: Variant in st["enemies"]:
		_prev_en.append(Vector2(e["p"]))


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
	_view = Control.new()
	_view.name = "View"
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.draw.connect(_draw_view)
	root.add_child(_view)
	var safe: MarginContainer = UI.safe_root(root, 14.0)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col: VBoxContainer = VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(col)
	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top)
	_hud = Control.new()
	_hud.name = "Status"
	_hud.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hud.custom_minimum_size = Vector2(0, 110)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.draw.connect(_draw_hud)
	top.add_child(_hud)
	## Mapa grande de las salas visitadas (pausa el juego).
	var map_btn: Button = UI.make_icon_button("grid")
	map_btn.name = "BtnMap"
	map_btn.pressed.connect(open_map)
	top.add_child(map_btn)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)
	var gap: Control = Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(gap)
	var pad: HBoxContainer = HBoxContainer.new()
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_theme_constant_override("separation", 8)
	col.add_child(pad)
	for d: Array in [["BtnLeft", "\u25c0", "left"], ["BtnRight", "\u25b6", "right"]]:
		var b: Button = UI.make_button(str(d[1]), false)
		b.name = str(d[0])
		b.custom_minimum_size = Vector2(104, 116)
		var key: String = str(d[2])
		b.button_down.connect(func() -> void: hold[key] = true)
		b.button_up.connect(func() -> void: hold[key] = false)
		pad.add_child(b)
	var sp: Control = Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(sp)
	var ba: Button = UI.make_button(Kit.text("mv_attack", "Golpe"), false)
	ba.name = "BtnAttack"
	ba.custom_minimum_size = Vector2(112, 116)
	ba.button_down.connect(func() -> void: want_attack = true)
	pad.add_child(ba)
	_btn_dash = UI.make_button(Kit.text("mv_dash", "Impulso"), false)
	_btn_dash.name = "BtnDash"
	_btn_dash.custom_minimum_size = Vector2(112, 116)
	_btn_dash.button_down.connect(func() -> void: want_dash = true)
	pad.add_child(_btn_dash)
	var bj: Button = UI.make_button(Kit.text("mv_jump", "Saltar"), true)
	bj.name = "BtnJump"
	bj.custom_minimum_size = Vector2(130, 116)
	bj.button_down.connect(func() -> void: want_jump = true)
	pad.add_child(bj)
	## Que quepan en un movil estrecho: texto mas pequeno y recortado si hace falta.
	for c: Node in pad.get_children():
		if c is Button:
			(c as Button).clip_text = true
			(c as Button).add_theme_font_size_override("font_size", 21)


func can_act() -> bool:
	return not finished and not failed and is_inside_tree() and not get_tree().paused and not bool(st["won"]) and not bool(st["lost"])


func _tick() -> void:
	_prev = Vector2(st["p"])
	_snap_enemies()
	if auto_retry:
		M.bot_tick(st)
	else:
		var dir: int = 0
		if hold["left"] or Input.is_action_pressed("ui_left"):
			dir -= 1
		if hold["right"] or Input.is_action_pressed("ui_right"):
			dir += 1
		var j: bool = want_jump or Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("ui_accept")
		M.tick(st, dir, j, want_dash, want_attack)
	want_jump = false
	want_dash = false
	want_attack = false
	_collect_log()
	if bool(st["won"]):
		_finish()
	elif bool(st["lost"]):
		_lose()


func _physics_process(delta: float) -> void:
	if st.is_empty() or get_tree().paused:
		return
	_t += delta
	_swing = maxf(0.0, _swing - delta * 4.0)
	_toast_t = maxf(0.0, _toast_t - delta)
	if not finished and not failed:
		time_in_level += delta
		if fast and auto_retry:
			for k: int in 10:
				if not can_act():
					break
				_tick()
		else:
			_acc += delta
			while _acc >= DT and can_act():
				_acc -= DT
				_tick()
	var target: Vector2 = Vector2(st["p"])
	_cam = _cam.lerp(target, minf(1.0, delta * 6.0))
	for f: Variant in _fx:
		(f as Dictionary)["t"] = float((f as Dictionary)["t"]) + delta
	_fx = _fx.filter(func(f: Dictionary) -> bool: return float(f["t"]) < 0.7)
	if _btn_dash != null:
		_btn_dash.visible = bool(st["abil"]["D"])
	_view.queue_redraw()
	_hud.queue_redraw()


func _collect_log() -> void:
	var lg: Array = st["log"]
	while _log_seen < lg.size():
		var e: Dictionary = lg[_log_seen]
		_log_seen += 1
		match str(e["k"]):
			"item":
				var it: String = str(e["i"])
				_fx.append({"at": e["at"], "t": 0.0, "c": it})
				if it == "$":
					coins += 1
					_sfx("coin", -8.0)
				else:
					_sfx("powerup", -4.0)
					var names: Dictionary = {"J": Kit.text("mv_got_jump", "\u00a1Doble salto! Salta otra vez en el aire"),
						"D": Kit.text("mv_got_dash", "\u00a1Impulso! Cruza fosos en el aire"),
						"B": Kit.text("mv_got_hammer", "\u00a1Martillo! Golpea los bloques agrietados"),
						"K": Kit.text("mv_got_key", "\u00a1Una llave! Abre una puerta"), "+": Kit.text("mv_got_heart", "+1 vida")}
					_toast = str(names.get(it, ""))
					_toast_t = 2.6
			"jump", "jump2":
				_sfx("jump", -10.0)
			"dash":
				_sfx("shoot", -8.0)
			"attack":
				_swing = 1.0
				_sfx("click", -12.0)
			"kill", "smash":
				_fx.append({"at": e["at"], "t": 0.0, "c": "x"})
				_sfx("stomp", -6.0)
			"door":
				_sfx("ui_open", -6.0)
			"hurt":
				_sfx("hurt", -4.0)
				if not fast:
					Juice.vibrate(30)
				_prev = Vector2(st["p"])
				_cam = _prev


func _sfx(nm: String, vol: float = -6.0) -> void:
	if not fast:
		Audio.play(nm, 0.1, vol)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()
	elif event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		match (event as InputEventKey).keycode:
			KEY_X:
				want_attack = true
			KEY_C:
				want_dash = true
			KEY_Z:
				want_jump = true


# ------------------------------------------------------------------ dibujo

func _o() -> Vector2:
	return _view.size * Vector2(0.5, 0.45) - (_cam + Vector2(0.5, 0.5)) * TILE


func _draw_view() -> void:
	if st.is_empty():
		return
	var sz: Vector2 = _view.size
	var o: Vector2 = _o()
	var sky: Color = Kit.color("sky", Color("#1d2240"))
	_view.draw_rect(Rect2(Vector2.ZERO, sz), sky.darkened(0.2))
	## Fondo con un poco de profundidad.
	for i: int in 14:
		var px: float = fmod(float(i) * 211.0 - _cam.x * TILE * 0.3, sz.x + 200.0) - 100.0
		var ph: float = 220.0 + 90.0 * sin(float(i) * 1.3)
		_view.draw_rect(Rect2(Vector2(px, sz.y * 0.75 - ph - _cam.y * 4.0), Vector2(120, ph + 600)), sky.darkened(0.35))
	var rock: Color = Kit.color("ground", Color("#4a4e69"))
	var x0: int = maxi(0, floori(-o.x / TILE) - 1)
	var y0: int = maxi(0, floori(-o.y / TILE) - 1)
	var x1: int = mini(int(st["w"]), ceili((sz.x - o.x) / TILE) + 1)
	var y1: int = mini(int(st["h"]), ceili((sz.y - o.y) / TILE) + 1)
	for y: int in range(y0, y1):
		for x: int in range(x0, x1):
			var q: Vector2i = Vector2i(x, y)
			var c: String = M.cell(st, q)
			var r: Rect2 = Rect2(o + Vector2(x, y) * TILE, Vector2(TILE, TILE))
			match c:
				"#":
					if _tile_tex != null:
						_view.draw_texture_rect(_tile_tex, r, false)
					else:
						_view.draw_rect(r, rock)
					if M.cell(st, q + Vector2i(0, -1)) != "#":
						_view.draw_rect(Rect2(r.position, Vector2(TILE, 6)), rock.lightened(0.35))
				"%":
					_view.draw_rect(r.grow(-2), Color("#8d6e63"))
					_view.draw_line(r.position + Vector2(10, 8), r.get_center(), Color("#3e2723"), 4.0)
					_view.draw_line(r.get_center(), r.position + Vector2(TILE - 12, TILE - 10), Color("#3e2723"), 4.0)
					_view.draw_line(r.get_center(), r.position + Vector2(8, TILE - 14), Color("#3e2723"), 3.0)
				"L":
					_view.draw_rect(r.grow(-3), Color("#6d4c41"))
					_view.draw_rect(r.grow(-3), Color("#f4a261"), false, 4.0)
					_view.draw_circle(r.get_center() + Vector2(0, -4), 7.0, Color("#f4a261"))
					_view.draw_rect(Rect2(r.get_center() + Vector2(-3, 0), Vector2(6, 12)), Color("#f4a261"))
				"^":
					for k: int in 3:
						var bx: float = r.position.x + TILE * (float(k) / 3.0)
						_view.draw_colored_polygon(PackedVector2Array([Vector2(bx, r.end.y), Vector2(bx + TILE / 6.0, r.end.y - TILE * 0.55), Vector2(bx + TILE / 3.0, r.end.y)]), Color("#cfd8dc"))
	## Objetos.
	for k2: Variant in st["items"]:
		var it: String = str(st["items"][k2])
		var c2: Vector2 = o + (Vector2(k2) + Vector2(0.5, 0.5)) * TILE + Vector2(0, sin(_t * 3.0 + float((k2 as Vector2i).x)) * 5.0)
		_item(c2, it)
	## Meta.
	var gp: Vector2i = st["goal"]
	if gp.x >= 0:
		var gc: Vector2 = o + (Vector2(gp) + Vector2(0.5, 0.5)) * TILE
		for ring: int in 3:
			_view.draw_arc(gc, TILE * (0.25 + 0.15 * float(ring)) + sin(_t * 4.0 + float(ring)) * 3.0, 0.0, TAU, 24, Color(0.6, 1.0, 0.8, 0.8 - 0.2 * float(ring)), 4.0)
	## Enemigos (suavizados entre ticks).
	var a: float = clampf(_acc / DT, 0.0, 1.0)
	for i: int in (st["enemies"] as Array).size():
		var e: Dictionary = st["enemies"][i]
		if not bool(e["alive"]):
			continue
		var ep: Vector2 = (_prev_en[i] as Vector2).lerp(Vector2(e["p"]), a) if i < _prev_en.size() else Vector2(e["p"])
		var ec: Vector2 = o + (ep + Vector2(0.5, 0.5)) * TILE
		if _foe_tex != null:
			_sprite(_foe_tex, ec, int(e["dir"]) < 0)
		else:
			_view.draw_circle(ec, TILE * 0.38, Color("#ef476f"))
	## Heroe.
	var hp: Vector2 = _prev.lerp(Vector2(st["p"]), a) if _prev.distance_to(Vector2(st["p"])) < 6.0 else Vector2(st["p"])
	var hc: Vector2 = o + (hp + Vector2(0.5, 0.5)) * TILE
	if int(st["inv"]) <= 0 or int(_t * 12.0) % 2 == 0:
		if _hero_tex != null:
			_sprite(_hero_tex, hc, int(st["face"]) < 0)
		else:
			_view.draw_circle(hc, TILE * 0.4, Color("#4cc9f0"))
	if _swing > 0.0:
		var f: float = float(st["face"])
		_view.draw_arc(hc + Vector2(f * TILE * 0.4, 0), TILE * 0.6, -1.2 if f > 0 else PI - 1.2, 1.2 if f > 0 else PI + 1.2, 12, Color(1, 1, 1, _swing), 6.0)
	for fx: Variant in _fx:
		var fd: Dictionary = fx
		var fc: Vector2 = o + (Vector2(fd["at"]) + Vector2(0.5, 0.5)) * TILE
		var tt: float = float(fd["t"]) / 0.7
		var col: Color = Color(str(ITEM_COL.get(str(fd["c"]), "#ffffff")))
		for s: int in 8:
			var an: float = TAU * float(s) / 8.0
			_view.draw_circle(fc + Vector2(cos(an), sin(an)) * TILE * (0.2 + 0.8 * tt), 6.0 * (1.0 - tt), col)
	## Aviso de habilidad nueva.
	if _toast_t > 0.0:
		var font: Font = _view.get_theme_font("font", "Label")
		var al: float = clampf(_toast_t / 0.4, 0.0, 1.0)
		var tp: Vector2 = Vector2(30, sz.y * 0.28)
		_view.draw_string_outline(font, tp, _toast, HORIZONTAL_ALIGNMENT_CENTER, sz.x - 60.0, 34, 8, Color(0, 0, 0, al))
		_view.draw_string(font, tp, _toast, HORIZONTAL_ALIGNMENT_CENTER, sz.x - 60.0, 34, Color(1, 0.9, 0.5, al))


## Dibujo de cada habilidad: doble flecha arriba, impulso, martillo y llave.
func _icon(cv: CanvasItem, c: Vector2, it: String, s: float, col: Color) -> void:
	match it:
		"J":
			for k: int in 2:
				var y: float = c.y + s * (0.15 - 0.6 * float(k))
				cv.draw_colored_polygon(PackedVector2Array([Vector2(c.x - s * 0.7, y + s * 0.45), Vector2(c.x, y - s * 0.3), Vector2(c.x + s * 0.7, y + s * 0.45)]), col)
		"D":
			for k2: int in 2:
				var x: float = c.x + s * (-0.55 + 0.6 * float(k2))
				cv.draw_polyline(PackedVector2Array([Vector2(x, c.y - s * 0.6), Vector2(x + s * 0.5, c.y), Vector2(x, c.y + s * 0.6)]), col, maxf(2.0, s * 0.25))
		"B":
			cv.draw_rect(Rect2(c + Vector2(-s * 0.75, -s * 0.75), Vector2(s * 1.5, s * 0.6)), col)
			cv.draw_rect(Rect2(c + Vector2(-s * 0.15, -s * 0.2), Vector2(s * 0.3, s * 1.0)), col)
		"K":
			cv.draw_arc(c + Vector2(-s * 0.35, 0), s * 0.38, 0.0, TAU, 12, col, maxf(2.0, s * 0.22))
			cv.draw_line(c, c + Vector2(s * 0.85, 0), col, maxf(2.0, s * 0.22))
			cv.draw_line(c + Vector2(s * 0.6, 0), c + Vector2(s * 0.6, s * 0.35), col, maxf(2.0, s * 0.2))


func _sprite(tex: Texture2D, c: Vector2, flip: bool) -> void:
	var ts: Vector2 = tex.get_size()
	var k: float = TILE * 1.05 / maxf(ts.x, ts.y)
	var r: Rect2 = Rect2(c - ts * k * 0.5 + Vector2(0, -TILE * 0.03), ts * k)
	if flip:
		_view.draw_set_transform(Vector2(c.x * 2.0, 0), 0.0, Vector2(-1, 1))
	_view.draw_texture_rect(tex, r, false)
	_view.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _item(c: Vector2, it: String) -> void:
	var col: Color = Color(str(ITEM_COL.get(it, "#ffffff")))
	match it:
		"$":
			_view.draw_circle(c, TILE * 0.2, col)
			_view.draw_circle(c, TILE * 0.12, col.darkened(0.2))
		"+":
			_view.draw_circle(c + Vector2(-7, -4), 9.0, col)
			_view.draw_circle(c + Vector2(7, -4), 9.0, col)
			_view.draw_colored_polygon(PackedVector2Array([c + Vector2(-15, 0), c + Vector2(15, 0), c + Vector2(0, 16)]), col)
		_:
			_view.draw_circle(c, TILE * 0.42, Color(col, 0.25 + 0.1 * sin(_t * 6.0)))
			_view.draw_circle(c, TILE * 0.3, col)
			_icon(_view, c, it, TILE * 0.26, Color("#1d1d2c"))


## Vidas, habilidades, monedas y minimapa de salas.
func _draw_hud() -> void:
	if st.is_empty():
		return
	var font: Font = _hud.get_theme_font("font", "Label")
	for i: int in int(st["max_hp"]):
		var c: Vector2 = Vector2(22 + 34 * i, 24)
		var col: Color = Color("#ff6b81") if i < int(st["hp"]) else Color(1, 1, 1, 0.2)
		_hud.draw_circle(c + Vector2(-6, -3), 8.0, col)
		_hud.draw_circle(c + Vector2(6, -3), 8.0, col)
		_hud.draw_colored_polygon(PackedVector2Array([c + Vector2(-13, 0), c + Vector2(13, 0), c + Vector2(0, 14)]), col)
	var ax: float = 12.0
	for ab: String in ["J", "D", "B"]:
		var have: bool = bool(st["abil"][ab])
		_hud.draw_circle(Vector2(ax + 14, 70), 16.0, Color(str(ITEM_COL[ab])) if have else Color(1, 1, 1, 0.12))
		if have:
			_icon(_hud, Vector2(ax + 14, 70), ab, 10.0, Color("#1d1d2c"))
		ax += 40.0
	if int(st["keys"]) > 0:
		_icon(_hud, Vector2(ax + 16, 70), "K", 12.0, Color(ITEM_COL["K"]))
		_hud.draw_string(font, Vector2(ax + 34, 78), "x%d" % int(st["keys"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(ITEM_COL["K"]))
		ax += 80.0
	_hud.draw_string(font, Vector2(ax + 8, 78), "$ %d/%d" % [int(st["coins"]), int(st["coins_total"])], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(ITEM_COL["$"]))
	## Minimapa.
	var rw: int = (int(st["w"]) - 1) / 14
	var rh: int = (int(st["h"]) - 1) / 10
	var cell: Vector2 = Vector2(26, 18)
	var mo: Vector2 = Vector2(_hud.size.x - float(rw) * cell.x - 8.0, 8)
	var cur: Vector2i = M.room_of(st["p"])
	for ry: int in rh:
		for rx: int in rw:
			var rr: Rect2 = Rect2(mo + Vector2(rx, ry) * cell, cell - Vector2(3, 3))
			var seen: bool = (st["seen"] as Dictionary).has(Vector2i(rx, ry))
			_hud.draw_rect(rr, Color("#4cc9f0") if Vector2i(rx, ry) == cur else (Color(1, 1, 1, 0.45) if seen else Color(1, 1, 1, 0.08)))
	var gr: Vector2i = M.room_of(st["goal"])
	if (st["seen"] as Dictionary).has(gr):
		_hud.draw_circle(mo + (Vector2(gr) + Vector2(0.45, 0.4)) * cell, 4.0, Color("#80ed99"))


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = 1000 + int(st["coins"]) * 50 + int(st["hp"]) * 200 + maxi(0, 120 - int(time_in_level)) * 5
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "coins": coins, "ticks": int(st["tick"]), "time": snappedf(time_in_level, 0.1)})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


## Estrellas: todas las monedas sin perder vidas, 3; la mitad de las monedas o sin perder vidas, 2.
func stars_earned() -> int:
	var all_c: bool = int(st["coins"]) >= int(st["coins_total"])
	var clean: bool = int(st["deaths"]) == 0
	if all_c and clean:
		return 3
	return 2 if clean or int(st["coins"]) * 2 >= int(st["coins_total"]) else 1


func _lose() -> void:
	if failed:
		return
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "metroid", "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("mv_lost", "\u00a1Sin vidas!"),
		Kit.text("mv_hint", "Si una puerta no se abre, busca la habilidad en otra sala: el muro alto pide doble salto, el foso de pinchos impulso y los bloques agrietados martillo."))
	p.closed.connect(retry)


func retry() -> void:
	_reset()


func open_map() -> void:
	if finished or st.is_empty() or get_tree().paused:
		return
	hold = {"left": false, "right": false}
	MetroidMapPanel.open(self, st)


func open_pause() -> void:
	if finished or get_tree().paused or get_node_or_null("PauseMenu") != null:
		return
	hold = {"left": false, "right": false}
	PauseMenu.open(self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_inside_tree() and not UI.test_mode:
			open_pause()


func bot_state() -> Dictionary:
	return {"deaths": deaths, "coins": coins, "finished": finished, "failed": failed, "stomps": 0, "time": time_in_level,
		"tick": int(st.get("tick", 0)), "hp": int(st.get("hp", 0))}
