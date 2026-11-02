extends Node2D
## Lucha 1 contra 1 (tipo Street Fighter): flechas para andar y saltar; botones de punetazo,
## patada, cubrirse (mantener) y especial (con media barra). Gana dos asaltos. Reglas, IA, bot y
## analizador en fighter_map.gd (todo va por ticks).
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const M = preload("res://kit/fighter/fighter_map.gd")
const DT: float = 1.0 / float(M.TPS)

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
## Lo que pide el jugador (botones mantenidos y golpe pendiente).
var hold: Dictionary = {"left": false, "right": false, "block": false}
var pending_attack: String = ""
var pending_jump: bool = false

var _view: Control
var _bars: Control
var _btn_special: Button
var _hero_tex: Texture2D = null
var _foe_tex: Texture2D = null
var _acc: float = 0.0
var _fx: Array = []
var _log_seen: int = 0
var _t: float = 0.0
var _shake: float = 0.0
var _banner: String = ""
var _banner_t: float = 0.0


func _ready() -> void:
	level = Kit.current_level()
	RenderingServer.set_default_clear_color(Color("#1a1423"))
	_hero_tex = _tex_of(Kit.sprite_by_role("jugador"))
	_foe_tex = _tex_of(Kit.sprite_by_role("enemigo"))
	_build_hud()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "fighter", "style": str(level.get("foe_style", ""))})


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
	return "res://qa/fighter_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(3.5, 1.2)


func _reset() -> void:
	finished = false
	failed = false
	st = M.new_state(level)
	time_in_level = 0.0
	_acc = 0.0
	_fx = []
	_log_seen = 0
	hold = {"left": false, "right": false, "block": false}
	pending_attack = ""
	pending_jump = false
	_show_banner(Kit.text("fg_round", "Asalto {n}").format({"n": 1}))


func _show_banner(txt: String) -> void:
	_banner = txt
	_banner_t = 1.6


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
	_bars = Control.new()
	_bars.name = "Bars"
	_bars.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bars.custom_minimum_size = Vector2(0, 96)
	_bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bars.draw.connect(_draw_bars)
	top.add_child(_bars)
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
	pad.add_theme_constant_override("separation", 10)
	col.add_child(pad)
	var moves: GridContainer = GridContainer.new()
	moves.columns = 3
	moves.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(moves)
	_hold_btn(moves, "BtnLeft", "\u25c0", "left")
	var bj: Button = UI.make_button("\u25b2", false)
	bj.name = "BtnJump"
	bj.custom_minimum_size = Vector2(110, 110)
	bj.button_down.connect(func() -> void: pending_jump = true)
	moves.add_child(bj)
	_hold_btn(moves, "BtnRight", "\u25b6", "right")
	var sp: Control = Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(sp)
	var acts: GridContainer = GridContainer.new()
	acts.columns = 2
	acts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(acts)
	_attack_btn(acts, "BtnPunch", Kit.text("fg_punch", "Pu\u00f1o"), "punch", true)
	_attack_btn(acts, "BtnKick", Kit.text("fg_kick", "Patada"), "kick", true)
	_hold_btn(acts, "BtnBlock", Kit.text("fg_block", "Cubrir"), "block")
	_btn_special = _attack_btn(acts, "BtnSpecial", Kit.text("fg_special", "Especial"), "special", false)


func _hold_btn(parent: Control, nm: String, txt: String, key: String) -> Button:
	var b: Button = UI.make_button(txt, false)
	b.name = nm
	b.custom_minimum_size = Vector2(110, 110)
	b.button_down.connect(func() -> void: hold[key] = true)
	b.button_up.connect(func() -> void: hold[key] = false)
	parent.add_child(b)
	return b


func _attack_btn(parent: Control, nm: String, txt: String, move: String, primary: bool) -> Button:
	var b: Button = UI.make_button(txt, primary)
	b.name = nm
	b.custom_minimum_size = Vector2(150, 110)
	b.button_down.connect(func() -> void: pending_attack = move)
	parent.add_child(b)
	return b


func can_act() -> bool:
	return not finished and not failed and is_inside_tree() and not get_tree().paused and not bool(st["won"]) and not bool(st["lost"])


func press(move: String) -> void:
	pending_attack = move


func _player_cmd() -> Dictionary:
	var dir: int = 0
	if hold["left"] or Input.is_action_pressed("ui_left"):
		dir -= 1
	if hold["right"] or Input.is_action_pressed("ui_right"):
		dir += 1
	var c: Dictionary = {"dir": dir, "jump": pending_jump or Input.is_action_just_pressed("ui_up"), "block": bool(hold["block"]), "attack": pending_attack}
	pending_attack = ""
	pending_jump = false
	return c


func _tick() -> void:
	var r0: int = int(st["round"])
	var cmd: Dictionary = M.bot_cmd(st) if auto_retry else _player_cmd()
	M.tick(st, cmd, M.ai_cmd(st))
	_collect_log()
	if int(st["round"]) != r0 and not bool(st["won"]) and not bool(st["lost"]):
		_show_banner(Kit.text("fg_round", "Asalto {n}").format({"n": int(st["round"])}))
	if bool(st["won"]):
		_finish()
	elif bool(st["lost"]):
		_lose()


func _physics_process(delta: float) -> void:
	if st.is_empty() or get_tree().paused:
		return
	_t += delta
	_shake = maxf(0.0, _shake - delta * 3.0)
	_banner_t = maxf(0.0, _banner_t - delta)
	if not finished and not failed:
		time_in_level += delta
		if fast and auto_retry:
			for k: int in 20:
				if not can_act():
					break
				_tick()
		else:
			_acc += delta
			while _acc >= DT and can_act():
				_acc -= DT
				_tick()
	var mid: float = (float(st["f"][0]["x"]) + float(st["f"][1]["x"])) * 0.5
	_cam = lerpf(_cam, clampf(mid, VIEW_W * 0.5, M.STAGE - VIEW_W * 0.5), minf(1.0, delta * 4.0))
	for f: Variant in _fx:
		(f as Dictionary)["t"] = float((f as Dictionary)["t"]) + delta
	_fx = _fx.filter(func(f: Dictionary) -> bool: return float(f["t"]) < 0.5)
	if _btn_special != null:
		_btn_special.disabled = int(st["f"][0]["meter"]) < 50 or not can_act()
	_view.queue_redraw()
	_bars.queue_redraw()


func _collect_log() -> void:
	var lg: Array = st["log"]
	while _log_seen < lg.size():
		var e: Dictionary = lg[_log_seen]
		_log_seen += 1
		match str(e["k"]):
			"hit":
				var v: Dictionary = st["f"][int(e["who"])]
				_fx.append({"k": "hit", "x": float(v["x"]) - float(v["face"]) * 2.0, "y": float(v["y"]) + 14.0, "t": 0.0, "n": int(e["n"])})
				_shake = 0.5 if int(e["n"]) >= 10 else 0.3
				_sfx("stomp" if int(e["n"]) >= 10 else "hurt", -6.0)
				if not fast:
					Juice.vibrate(20)
			"block":
				var v2: Dictionary = st["f"][int(e["who"])]
				_fx.append({"k": "block", "x": float(v2["x"]) + float(v2["face"]) * 3.0, "y": float(v2["y"]) + 14.0, "t": 0.0})
				_sfx("land", -6.0)
			"swing":
				_sfx("jump", -16.0)
			"combo":
				var va: Dictionary = st["f"][int(e["who"])]
				_fx.append({"k": "combo", "x": float(va["x"]), "y": float(va["y"]) + 26.0, "t": 0.0, "n": int(e["n"]), "who": int(e["who"])})
				_sfx("coin", -8.0)
			"special":
				_sfx("shoot", -6.0)
			"round":
				var w: int = int(e["winner"])
				_show_banner(Kit.text("fg_ko", "\u00a1K.O.!") if int(st["f"][0]["hp"]) <= 0 or int(st["f"][1]["hp"]) <= 0 else Kit.text("fg_time", "\u00a1Tiempo!"))
				if w == 0:
					_sfx("win", -8.0)


func _sfx(nm: String, vol: float = -6.0) -> void:
	if not fast:
		Audio.play(nm, 0.1, vol)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()
	elif event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		match (event as InputEventKey).keycode:
			KEY_Z:
				pending_attack = "punch"
			KEY_X:
				pending_attack = "kick"
			KEY_C:
				pending_attack = "special"
	if event is InputEventKey and (event as InputEventKey).keycode == KEY_SHIFT:
		hold["block"] = (event as InputEventKey).pressed


# ------------------------------------------------------------------ dibujo

## Camara: se ven 72 de los 100 metros del escenario, siguiendo el centro de la pelea.
const VIEW_W: float = 72.0
var _cam: float = 50.0


func _k() -> float:
	return _view.size.x / VIEW_W


func _floor_y() -> float:
	return _view.size.y * 0.62


func _to_screen(x: float, y: float) -> Vector2:
	var shake: Vector2 = Vector2(sin(_t * 71.0), cos(_t * 53.0)) * _shake * 8.0
	return Vector2((x - _cam) * _k() + _view.size.x * 0.5, _floor_y() - y * _k()) + shake


func _draw_bars() -> void:
	if st.is_empty():
		return
	var w: float = _bars.size.x
	var bw: float = (w - 110.0) * 0.5
	var font: Font = _bars.get_theme_font("font", "Label")
	for i: int in 2:
		var f: Dictionary = st["f"][i]
		var x0: float = 0.0 if i == 0 else w - bw
		var r: Rect2 = Rect2(Vector2(x0, 8), Vector2(bw, 26))
		_bars.draw_rect(r, Color(0, 0, 0, 0.6))
		var pct: float = float(f["hp"]) / float(f["max"])
		var fill: Rect2 = Rect2(r.position + Vector2(0 if i == 0 else bw * (1.0 - pct), 0), Vector2(bw * pct, 26))
		_bars.draw_rect(fill, Color("#06d6a0") if pct > 0.5 else (Color("#ffd166") if pct > 0.25 else Color("#ef476f")))
		_bars.draw_rect(r, Color.WHITE, false, 2.0)
		## Barra de especial.
		var mr: Rect2 = Rect2(Vector2(x0, 40), Vector2(bw * 0.7, 10))
		if i == 1:
			mr.position.x = w - bw * 0.7
		_bars.draw_rect(mr, Color(0, 0, 0, 0.6))
		_bars.draw_rect(Rect2(mr.position, Vector2(mr.size.x * float(f["meter"]) / 100.0, 10)), Color("#4cc9f0") if int(f["meter"]) >= 50 else Color("#3a6ea5"))
		## Asaltos ganados.
		for k: int in 2:
			var c: Vector2 = Vector2(x0 + 14.0 + float(k) * 26.0, 70) if i == 0 else Vector2(w - 14.0 - float(k) * 26.0, 70)
			_bars.draw_circle(c, 9.0, Color("#ffd166") if int(st["wins"][i]) > k else Color(1, 1, 1, 0.2))
	var secs: String = str(maxi(0, int(ceil(float(st["time"]) / float(M.TPS)))))
	_bars.draw_string_outline(font, Vector2(w * 0.5 - 24, 38), secs, HORIZONTAL_ALIGNMENT_CENTER, 48, 38, 6, Color.BLACK)
	_bars.draw_string(font, Vector2(w * 0.5 - 24, 38), secs, HORIZONTAL_ALIGNMENT_CENTER, 48, 38, Color.WHITE)


func _draw_view() -> void:
	if st.is_empty():
		return
	var sz: Vector2 = _view.size
	var k: float = _k()
	var fy: float = _floor_y()
	var sky: Color = Kit.color("sky", Color("#2b2140"))
	_view.draw_rect(Rect2(Vector2.ZERO, sz), sky)
	## Fondo: siluetas y luces del escenario.
	for i: int in 12:
		var bx: float = sz.x * float(i) / 8.0 - (_cam - 50.0) * k * 0.5 - sz.x * 0.2
		var bh: float = 120.0 + 60.0 * sin(float(i) * 1.7)
		_view.draw_rect(Rect2(Vector2(bx - 40, fy - bh - 40), Vector2(80, bh)), sky.darkened(0.3))
	_view.draw_rect(Rect2(Vector2(0, fy), Vector2(sz.x, sz.y - fy)), Kit.color("ground", Color("#5b3a29")).darkened(0.2))
	_view.draw_rect(Rect2(Vector2(0, fy), Vector2(sz.x, 8)), Kit.color("ground", Color("#5b3a29")).lightened(0.2))
	for j: int in 12:
		var lx: float = sz.x * float(j) / 11.0
		_view.draw_line(Vector2(sz.x * 0.5 + (lx - sz.x * 0.5) * 0.4, fy + 8), Vector2(lx, sz.y), Color(0, 0, 0, 0.12), 2.0)
	## Sombras y luchadores.
	for i2: int in 2:
		var f: Dictionary = st["f"][i2]
		_view.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var gs: Vector2 = _to_screen(float(f["x"]), 0.0)
		_view.draw_colored_polygon(_ellipse(gs, 6.0 * k, 1.4 * k), Color(0, 0, 0, 0.35))
	for i3: int in 2:
		_fighter(st["f"][i3], i3)
	## Bolas de energia.
	for s: Variant in st["shots"]:
		var sp: Vector2 = _to_screen(float(s["x"]), float(s["y"]))
		var col: Color = Color("#4cc9f0") if int(s["owner"]) == 0 else Color("#ff6b6b")
		_view.draw_circle(sp, 3.6 * k * (1.0 + 0.1 * sin(_t * 30.0)), Color(col, 0.35))
		_view.draw_circle(sp, 2.4 * k, col)
		_view.draw_circle(sp, 1.2 * k, Color.WHITE)
	## Golpes.
	var font: Font = _view.get_theme_font("font", "Label")
	for fx: Variant in _fx:
		var fd: Dictionary = fx
		var p: Vector2 = _to_screen(float(fd["x"]), float(fd["y"]))
		var tt: float = float(fd["t"]) / 0.5
		if str(fd["k"]) == "hit":
			for a: int in 8:
				var an: float = TAU * float(a) / 8.0 + 0.3
				_view.draw_line(p, p + Vector2(cos(an), sin(an)) * (10.0 + 40.0 * tt), Color(1, 0.9, 0.4, 1.0 - tt), 5.0)
			_view.draw_string_outline(font, p - Vector2(16, 30 + 30.0 * tt), str(int(fd["n"])), HORIZONTAL_ALIGNMENT_LEFT, -1, 32, 6, Color.BLACK)
			_view.draw_string(font, p - Vector2(16, 30 + 30.0 * tt), str(int(fd["n"])), HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color("#ffd166"))
		elif str(fd["k"]) == "combo":
			var txt: String = Kit.text("fg_combo", "Combo x{n}").format({"n": int(fd["n"])})
			var cc: Color = Color("#4cc9f0") if int(fd["who"]) == 0 else Color("#ff6b6b")
			var cp: Vector2 = p - Vector2(90, 20.0 + 40.0 * tt)
			_view.draw_string_outline(font, cp, txt, HORIZONTAL_ALIGNMENT_CENTER, 180, 34, 7, Color(0, 0, 0, 1.0 - tt * 0.5))
			_view.draw_string(font, cp, txt, HORIZONTAL_ALIGNMENT_CENTER, 180, 34, Color(cc, 1.0 - tt * 0.5))
		else:
			_view.draw_arc(p, 18.0 + 10.0 * tt, -1.2, 1.2, 12, Color(0.6, 0.9, 1.0, 1.0 - tt), 6.0)
	## Cartel del asalto / K.O.
	if _banner_t > 0.0:
		var a2: float = clampf(_banner_t / 0.4, 0.0, 1.0)
		var bp: Vector2 = Vector2(sz.x * 0.5 - 200, fy - 260)
		_view.draw_string_outline(font, bp, _banner, HORIZONTAL_ALIGNMENT_CENTER, 400, 72, 12, Color(0, 0, 0, a2))
		_view.draw_string(font, bp, _banner, HORIZONTAL_ALIGNMENT_CENTER, 400, 72, Color(1, 0.85, 0.3, a2))


func _ellipse(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for i: int in 16:
		var a: float = TAU * float(i) / 16.0
		out.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return out


func _limb(a: Vector2, b: Vector2, w: float, col: Color) -> void:
	_view.draw_line(a, b, col, w)
	_view.draw_circle(a, w * 0.5, col)
	_view.draw_circle(b, w * 0.5, col)


## Luchador dibujado por partes (piernas, cuerpo, brazos y cabeza) con su postura.
func _fighter(f: Dictionary, idx: int) -> void:
	var k: float = _k()
	var face: float = float(f["face"])
	var base: Vector2 = _to_screen(float(f["x"]), float(f["y"]))
	var col: Color = Kit.color("player", Color("#4cc9f0")) if idx == 0 else Color("#ef476f")
	if idx == 0 and col.get_luminance() < 0.25:
		col = Color("#4cc9f0")
	var dark: Color = col.darkened(0.35)
	var state: String = str(f["state"])
	var move: String = str(f["move"])
	var fr: int = int(f["frame"])
	var bob: float = sin(_t * 6.0 + float(idx)) * k * 0.3
	var lean: float = 0.0
	if state == "stun":
		lean = -0.35
	if state == "ko":
		## Tumbado en el suelo.
		var c: Vector2 = base + Vector2(-face * 6.0 * k, -2.0 * k)
		_limb(c + Vector2(-face * 7.0 * k, 0), c + Vector2(face * 7.0 * k, 0), 4.5 * k, col)
		_view.draw_circle(c + Vector2(face * 10.0 * k, -0.5 * k), 3.0 * k, col.lightened(0.2))
		return
	var hip: Vector2 = base + Vector2(0, -9.0 * k + bob)
	var neck: Vector2 = hip + Vector2(face * lean * 8.0 * k, -8.5 * k).rotated(lean * -face)
	## Piernas.
	var walk: float = sin(_t * 12.0) if state == "walk" else 0.0
	var ff: Vector2 = base + Vector2(face * (3.0 + 2.0 * walk) * k, 0)
	var bf: Vector2 = base + Vector2(-face * (3.0 + 2.0 * walk) * k, 0)
	if float(f["y"]) > 0.0:
		ff = hip + Vector2(face * 3.0 * k, 5.0 * k)
		bf = hip + Vector2(-face * 2.0 * k, 6.0 * k)
	if state == "attack" and move == "kick":
		var ext: float = clampf(float(fr) / float(M.MOVES["kick"]["start"]), 0.0, 1.0)
		ff = hip + Vector2(face * (4.0 + 10.0 * ext) * k, -1.0 * k * ext)
	if state == "attack" and move == "air":
		ff = hip + Vector2(face * 10.0 * k, 4.0 * k)
	_limb(hip, bf, 2.6 * k, dark)
	_limb(hip, ff, 2.6 * k, dark)
	## Cuerpo.
	_limb(hip, neck, 4.6 * k, col)
	## Brazos.
	var sh: Vector2 = neck + Vector2(0, 1.5 * k)
	var fh: Vector2 = sh + Vector2(face * 4.0 * k, 1.0 * k)
	var bh: Vector2 = sh + Vector2(face * 2.0 * k, 3.0 * k)
	if state == "block":
		fh = sh + Vector2(face * 3.0 * k, -2.5 * k)
		bh = sh + Vector2(face * 3.5 * k, -0.5 * k)
		_view.draw_arc(sh + Vector2(face * 4.0 * k, -1.0 * k), 6.0 * k, -PI * 0.5 + (0.0 if face > 0 else PI) - 1.0, -PI * 0.5 + (0.0 if face > 0 else PI) + 1.0, 10, Color(0.6, 0.9, 1.0, 0.5), 3.0)
	elif state == "attack" and move == "punch":
		var ext2: float = clampf(float(fr) / float(M.MOVES["punch"]["start"]), 0.0, 1.0)
		fh = sh + Vector2(face * (4.0 + 6.0 * ext2) * k, 0.5 * k)
	elif state == "attack" and move == "special":
		fh = sh + Vector2(face * 7.0 * k, 1.0 * k)
		bh = sh + Vector2(face * 7.0 * k, 2.5 * k)
		if fr < int(M.MOVES["special"]["start"]):
			_view.draw_circle(fh + Vector2(face * 1.5 * k, 0.8 * k), (1.0 + float(fr) * 0.3) * k, Color(0.7, 0.95, 1.0, 0.8))
	elif state == "stun":
		fh = sh + Vector2(-face * 3.0 * k, -3.0 * k)
		bh = sh + Vector2(-face * 4.0 * k, 1.0 * k)
	_limb(sh, bh, 2.2 * k, dark)
	_limb(sh, fh, 2.2 * k, col.lightened(0.1))
	_view.draw_circle(fh, 1.6 * k, Color("#fff3e0"))
	## Cabeza: el arte del juego (heroe o enemigo) o una cara sencilla.
	var hc: Vector2 = neck + Vector2(face * 0.5 * k, -3.2 * k)
	var tex: Texture2D = _hero_tex if idx == 0 else _foe_tex
	if tex != null:
		var ts: Vector2 = tex.get_size()
		var kk: float = 7.5 * k / maxf(ts.x, ts.y)
		if face < 0.0:
			_view.draw_set_transform(Vector2(hc.x * 2.0, 0), 0.0, Vector2(-1, 1))
		_view.draw_texture_rect(tex, Rect2(hc - ts * kk * 0.5, ts * kk), false)
		_view.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		_view.draw_circle(hc, 3.0 * k, col.lightened(0.25))
		_view.draw_circle(hc + Vector2(face * 1.2 * k, -0.4 * k), 0.6 * k, Color.BLACK)


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = 1000 + int(st["f"][0]["hp"]) * 20 + int(st["hits"]) * 30 + (500 if bool(st["perfect"]) else 0)
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "coins": coins, "rounds": int(st["round"]), "time": snappedf(time_in_level, 0.1),
		"best_combo": int(st.get("best_combo", 0))})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


## Estrellas: 2-0 sin que te toquen, 3; 2-0, 2; 2-1, 1 (y con media vida en el ultimo, 2).
func stars_earned() -> int:
	if bool(st["perfect"]) or (int(st["wins"][1]) == 0 and int(st["f"][0]["hp"]) * 2 >= int(st["f"][0]["max"])):
		return 3
	return 2 if int(st["wins"][1]) == 0 else 1


func _lose() -> void:
	if failed:
		return
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "fighter", "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("fg_lost", "\u00a1Derrota!"),
		Kit.text("fg_hint", "C\u00fabrete cuando el rival golpea y contraataca mientras se recupera; la patada llega m\u00e1s lejos y el especial va bien de lejos."))
	p.closed.connect(retry)


func retry() -> void:
	_reset()


func open_pause() -> void:
	if finished or get_tree().paused or get_node_or_null("PauseMenu") != null:
		return
	hold = {"left": false, "right": false, "block": false}
	PauseMenu.open(self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_inside_tree() and not UI.test_mode:
			open_pause()


func bot_state() -> Dictionary:
	return {"deaths": deaths, "coins": coins, "finished": finished, "failed": failed, "stomps": int(st.get("hits", 0)), "time": time_in_level,
		"round": int(st.get("round", 0))}
