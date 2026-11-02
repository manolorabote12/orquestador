extends Node2D
## Bombas (tipo Bomberman): arrastra el dedo para moverte (joystick donde toques) y pulsa el boton
## de la bomba. Rompe cajas, busca la salida escondida, vence a todos los monstruos y pisala.
## Tres vidas por nivel. Reglas, bot y analizador en bomber_map.gd (todo va por ticks).
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const M = preload("res://kit/bomber/bomber_map.gd")
const DT: float = 1.0 / float(M.TPS)
const MON_COL: Dictionary = {"e": "#f06292", "c": "#9575cd", "f": "#4dd0e1"}

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
## Direccion que pide el jugador (o el bot) y bomba pendiente.
var want_dir: Vector2i = Vector2i.ZERO
var want_drop: bool = false
var stick: HordeStick

var _view: Control
var _info: Label
var _bomb_btn: Button
var _hero_tex: Texture2D = null
var _acc: float = 0.0
var _vis: Dictionary = {}
var _fx: Array = []
var _log_seen: int = 0
var _t: float = 0.0
var _shake: float = 0.0


func _ready() -> void:
	level = Kit.current_level()
	RenderingServer.set_default_clear_color(Color("#1b1d27"))
	var hero: Dictionary = Kit.sprite_by_role("jugador")
	if not hero.is_empty():
		var sf: SpriteFrames = SpriteKit.frames_de(hero)
		for anim: String in sf.get_animation_names():
			if sf.get_frame_count(anim) > 0:
				_hero_tex = sf.get_frame_texture(anim, 0)
				break
	_build_hud()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "bomber", "enemies": (st["enemies"] as Array).size()})


func wants_grade() -> bool:
	return false


func bot_script() -> String:
	return "res://qa/bomber_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(3.2, 2.0)


func _reset() -> void:
	finished = false
	failed = false
	st = M.new_state(level)
	coins_total = 0
	coins = 0
	time_in_level = 0.0
	_acc = 0.0
	_fx = []
	_log_seen = 0
	_vis = {"p": Vector2(st["p"])}
	for i: int in (st["enemies"] as Array).size():
		_vis[i] = Vector2(st["enemies"][i]["p"])
	want_dir = Vector2i.ZERO
	want_drop = false
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
	_info.add_theme_font_size_override("font_size", 26)
	_info.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_info.add_theme_constant_override("outline_size", 6)
	top.add_child(_info)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)
	_view = Control.new()
	_view.name = "View"
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.draw.connect(_draw_view)
	col.add_child(_view)
	var bottom: HBoxContainer = HBoxContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.custom_minimum_size = Vector2(0, 190)
	col.add_child(bottom)
	var hint: Label = Label.new()
	hint.name = "Hint"
	hint.text = Kit.text("bm_move", "Arrastra para moverte")
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(1, 1, 1, 0.45)
	bottom.add_child(hint)
	_bomb_btn = UI.make_button("", true)
	_bomb_btn.name = "BtnBomb"
	_bomb_btn.custom_minimum_size = Vector2(180, 180)
	_bomb_btn.button_down.connect(drop_bomb)
	var art: Control = Control.new()
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.draw.connect(func() -> void: _draw_bomb(art, art.size * 0.5, art.size.x * 0.3, 1.0))
	_bomb_btn.add_child(art)
	bottom.add_child(_bomb_btn)
	stick = HordeStick.new()
	stick.name = "Stick"
	add_child(stick)
	_bomb_btn.resized.connect(func() -> void: stick.blocked = [_bomb_btn.get_global_rect().grow(20.0)])


func _refresh() -> void:
	if st.is_empty() or _info == null:
		return
	_info.text = "\u2665 %d   \u2620 %d   \u25cf %d   \u2731 %d   %d s" % [int(st["lives"]), M.enemies_left(st), int(st["max_bombs"]), int(st["range"]), int(time_in_level)]
	_bomb_btn.disabled = not can_act()


func can_act() -> bool:
	return not finished and not failed and is_inside_tree() and not get_tree().paused and not bool(st["won"]) and not bool(st["lost"])


func drop_bomb() -> void:
	if can_act():
		want_drop = true


func _cs() -> float:
	return minf(_view.size.x / float(st["w"]), _view.size.y / float(st["h"]))


func _origin() -> Vector2:
	var cs: float = _cs()
	var shake: Vector2 = Vector2(sin(_t * 70.0), cos(_t * 53.0)) * _shake * 8.0
	return (_view.size - Vector2(float(st["w"]), float(st["h"])) * cs) * 0.5 + shake


# ------------------------------------------------------------------ bucle

func bot_step() -> void:
	if can_act():
		var a: Dictionary = M.bot_action(st)
		want_dir = a["dir"]
		want_drop = bool(a["drop"])


func _read_input() -> void:
	var v: Vector2 = stick.vector if stick != null else Vector2.ZERO
	var k: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if k.length() > 0.1:
		v = k
	if v.length() < 0.35:
		want_dir = Vector2i.ZERO
	elif absf(v.x) > absf(v.y):
		want_dir = Vector2i(int(signf(v.x)), 0)
	else:
		want_dir = Vector2i(0, int(signf(v.y)))
	if Input.is_action_just_pressed("ui_accept"):
		want_drop = true


func _tick() -> void:
	var lives0: int = int(st["lives"])
	M.tick(st, want_dir, want_drop)
	want_drop = false
	_collect_log()
	if int(st["lives"]) < lives0 and not bool(st["lost"]):
		_vis["p"] = Vector2(st["p"])
	if bool(st["won"]):
		_finish()
	elif bool(st["lost"]):
		_lose()


func _physics_process(delta: float) -> void:
	if st.is_empty() or get_tree().paused:
		return
	_t += delta
	_shake = maxf(0.0, _shake - delta * 3.0)
	if not finished and not failed:
		time_in_level += delta
		if fast and auto_retry:
			## Validar: el bot juega a toda velocidad.
			for k: int in 8:
				if not can_act():
					break
				bot_step()
				_tick()
		else:
			if not auto_retry:
				_read_input()
			_acc += delta
			while _acc >= DT and can_act():
				_acc -= DT
				if auto_retry:
					bot_step()
				_tick()
	## Movimiento suave hacia la casilla real.
	var sp: float = 1.0 / (float(st["speed"]) * DT) * delta * 1.15
	_vis["p"] = (_vis["p"] as Vector2).move_toward(Vector2(st["p"]), sp)
	for i: int in (st["enemies"] as Array).size():
		var e: Dictionary = st["enemies"][i]
		_vis[i] = (_vis[i] as Vector2).move_toward(Vector2(e["p"]), 1.0 / (float(M.ENEMY_CD[str(e["k"])]) * DT) * delta * 1.15)
	for f: Variant in _fx:
		(f as Dictionary)["t"] = float((f as Dictionary)["t"]) + delta
	_fx = _fx.filter(func(f: Dictionary) -> bool: return float(f["t"]) < 0.9)
	_refresh()
	_view.queue_redraw()


func _collect_log() -> void:
	var lg: Array = st["log"]
	while _log_seen < lg.size():
		var e: Dictionary = lg[_log_seen]
		_log_seen += 1
		match str(e["k"]):
			"bomb":
				_sfx("click", -10.0)
			"boom":
				_shake = maxf(_shake, 0.6)
				_sfx("stomp", -4.0)
				if not fast:
					Juice.vibrate(20)
			"kill":
				_fx.append({"at": e["at"], "txt": "+100", "col": Color("#ffd166"), "t": 0.0})
				_sfx("coin", -8.0)
			"item":
				_fx.append({"at": e["at"], "txt": {"B": "+1 \u25cf", "R": "+1 \u2731", "S": "\u00bb"}.get(str(e.get("i", "")), "+"), "col": Color("#80ed99"), "t": 0.0})
				_sfx("powerup", -8.0)
			"exit":
				_fx.append({"at": e["at"], "txt": Kit.text("bm_exit", "\u00a1Salida!"), "col": Color("#4cc9f0"), "t": 0.0})
			"dead":
				_sfx("hurt", -4.0)
				_shake = 1.0


func _sfx(nm: String, vol: float = -6.0) -> void:
	if not fast:
		Audio.play(nm, 0.1, vol)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()


# ------------------------------------------------------------------ dibujo

func _draw_view() -> void:
	if st.is_empty():
		return
	var cs: float = _cs()
	var o: Vector2 = _origin()
	var ground: Color = Kit.color("ground", Color("#4f8a4b"))
	var block: Color = Color("#5c6370")
	var crate: Color = Kit.color("platform", Color("#a1683a"))
	var fl: Dictionary = st["flames"]
	var open: bool = M.enemies_left(st) == 0
	for y: int in int(st["h"]):
		for x: int in int(st["w"]):
			var q: Vector2i = Vector2i(x, y)
			var r: Rect2 = Rect2(o + Vector2(x, y) * cs, Vector2(cs, cs))
			var c: String = M.cell(st, q)
			if c == "#":
				_view.draw_rect(r, block)
				_view.draw_rect(Rect2(r.position, Vector2(cs, cs * 0.16)), block.lightened(0.25))
				_view.draw_rect(Rect2(r.position + Vector2(0, cs * 0.84), Vector2(cs, cs * 0.16)), block.darkened(0.3))
				continue
			_view.draw_rect(r, ground if (x + y) % 2 == 0 else ground.darkened(0.08))
			if c == "+":
				var cr: Rect2 = r.grow(-cs * 0.06)
				_view.draw_rect(cr, crate)
				_view.draw_rect(cr, crate.darkened(0.35), false, cs * 0.07)
				_view.draw_line(cr.position, cr.end, crate.darkened(0.3), cs * 0.06)
				_view.draw_line(cr.position + Vector2(cr.size.x, 0), cr.position + Vector2(0, cr.size.y), crate.darkened(0.3), cs * 0.06)
				continue
			if q == st["exit"]:
				var dr: Rect2 = r.grow(-cs * 0.12)
				_view.draw_rect(dr, Color("#263238"))
				var glow: Color = Color("#4cc9f0") if open else Color("#78909c")
				_view.draw_rect(dr.grow(-cs * 0.08), glow.darkened(0.2 + 0.15 * sin(_t * 4.0)) if open else glow.darkened(0.4))
				_view.draw_rect(dr, glow, false, cs * 0.06)
			var it: String = str((st["items"] as Dictionary).get(q, ""))
			if it != "":
				_item(r.get_center(), it, cs)
	## Bombas (laten antes de estallar).
	for b: Variant in st["bombs"]:
		var k: float = 1.0 + 0.08 * sin(_t * (8.0 + 30.0 / maxf(1.0, float(b["t"]))))
		_draw_bomb(_view, o + (Vector2(b["p"]) + Vector2(0.5, 0.55)) * cs, cs * 0.32 * k, float(b["t"]) / float(M.FUSE))
	## Llamas.
	for q2: Variant in fl:
		var r2: Rect2 = Rect2(o + Vector2(q2) * cs, Vector2(cs, cs))
		var a: float = clampf(float(fl[q2]) / float(M.FLAME), 0.0, 1.0)
		_view.draw_rect(r2.grow(-cs * 0.04), Color(1.0, 0.45, 0.1, 0.85 * a))
		_view.draw_rect(r2.grow(-cs * 0.2), Color(1.0, 0.85, 0.3, 0.95 * a))
		_view.draw_circle(r2.get_center(), cs * 0.16, Color(1, 1, 0.9, a))
	## Monstruos.
	for i: int in (st["enemies"] as Array).size():
		var e: Dictionary = st["enemies"][i]
		if not bool(e["alive"]):
			continue
		var c2: Vector2 = o + ((_vis[i] as Vector2) + Vector2(0.5, 0.5)) * cs
		var col: Color = Color(str(MON_COL.get(str(e["k"]), "#aaaaaa")))
		var bob: float = sin(_t * 6.0 + float(i)) * cs * 0.04
		_view.draw_circle(c2 + Vector2(0, cs * 0.3), cs * 0.26, Color(0, 0, 0, 0.25))
		_view.draw_circle(c2 + Vector2(0, bob), cs * 0.34, col)
		var look: Vector2 = Vector2(e["dir"]) * cs * 0.05
		for sx: float in [-1.0, 1.0]:
			_view.draw_circle(c2 + Vector2(sx * cs * 0.12, -cs * 0.06 + bob), cs * 0.09, Color.WHITE)
			_view.draw_circle(c2 + Vector2(sx * cs * 0.12, -cs * 0.06 + bob) + look, cs * 0.045, Color.BLACK)
		if str(e["k"]) == "c":
			_view.draw_line(c2 + Vector2(-cs * 0.2, -cs * 0.2 + bob), c2 + Vector2(-cs * 0.04, -cs * 0.13 + bob), Color.BLACK, 3.0)
			_view.draw_line(c2 + Vector2(cs * 0.2, -cs * 0.2 + bob), c2 + Vector2(cs * 0.04, -cs * 0.13 + bob), Color.BLACK, 3.0)
	## Heroe (parpadea con escudo).
	if int(st["shield"]) <= 0 or int(_t * 10.0) % 2 == 0:
		var hc: Vector2 = o + ((_vis["p"] as Vector2) + Vector2(0.5, 0.5)) * cs
		if _hero_tex != null:
			var ts: Vector2 = _hero_tex.get_size()
			var k2: float = cs * 0.95 / maxf(ts.x, ts.y)
			_view.draw_texture_rect(_hero_tex, Rect2(hc - ts * k2 * 0.5, ts * k2), false)
		else:
			_view.draw_circle(hc, cs * 0.36, Color("#ffffff"))
	var font: Font = _view.get_theme_font("font", "Label")
	for f: Variant in _fx:
		var fd: Dictionary = f
		var fp: Vector2 = o + (Vector2(fd["at"]) + Vector2(0.0, 0.3)) * cs - Vector2(0, float(fd["t"]) * 40.0)
		_view.draw_string_outline(font, fp, str(fd["txt"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, 6, Color.BLACK)
		_view.draw_string(font, fp, str(fd["txt"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, fd["col"])


func _draw_bomb(cv: CanvasItem, c: Vector2, r: float, fuse: float) -> void:
	cv.draw_circle(c, r, Color("#212121"))
	cv.draw_circle(c + Vector2(-r * 0.35, -r * 0.35), r * 0.22, Color(1, 1, 1, 0.35))
	cv.draw_rect(Rect2(c + Vector2(-r * 0.25, -r * 1.2), Vector2(r * 0.5, r * 0.3)), Color("#424242"))
	var tip: Vector2 = c + Vector2(r * 0.35, -r * 1.45)
	cv.draw_line(c + Vector2(0, -r * 1.15), tip, Color("#bcaaa4"), maxf(2.0, r * 0.12))
	var sp: float = r * (0.22 + 0.1 * sin(_t * 30.0)) * clampf(0.5 + fuse, 0.5, 1.2)
	cv.draw_circle(tip, sp, Color("#ffca28"))
	cv.draw_circle(tip, sp * 0.5, Color("#fff8e1"))


func _item(c: Vector2, it: String, cs: float) -> void:
	_view.draw_circle(c, cs * 0.34, Color(0, 0, 0, 0.35))
	_view.draw_circle(c, cs * 0.3, Color("#fff3e0"))
	match it:
		"B":
			_draw_bomb(_view, c + Vector2(0, cs * 0.05), cs * 0.15, 1.0)
		"R":
			_view.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -cs * 0.22), c + Vector2(cs * 0.15, cs * 0.05), c + Vector2(cs * 0.08, cs * 0.18),
				c + Vector2(-cs * 0.08, cs * 0.18), c + Vector2(-cs * 0.15, cs * 0.05)]), Color("#ff7043"))
		"S":
			_view.draw_colored_polygon(PackedVector2Array([c + Vector2(-cs * 0.15, -cs * 0.15), c + Vector2(cs * 0.0, -cs * 0.15), c + Vector2(cs * 0.0, cs * 0.05),
				c + Vector2(cs * 0.18, cs * 0.08), c + Vector2(cs * 0.18, cs * 0.16), c + Vector2(-cs * 0.15, cs * 0.16)]), Color("#42a5f5"))


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = 500 + int(st["kills"]) * 100 + int(st["crates"]) * 10 + int(st["lives"]) * 200 + maxi(0, int(level.get("par", 90)) - int(time_in_level)) * 5
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "coins": coins, "ticks": int(st["tick"]), "time": snappedf(time_in_level, 0.1)})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


## Estrellas: sin perder vidas y a tiempo, 3; sin perder vidas o a tiempo, 2; si no, 1.
func stars_earned() -> int:
	var secs: float = float(st["tick"]) * DT
	var clean: bool = int(st["deaths"]) == 0
	var quick: bool = secs <= float(level.get("par", 90))
	if clean and quick:
		return 3
	return 2 if clean or quick else 1


func _lose() -> void:
	if failed:
		return
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "bomber", "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("bm_lost", "\u00a1Sin vidas!"),
		Kit.text("bm_hint", "Pon la bomba y escondete tras una esquina: la explosion va en cruz. Los monstruos mueren si les pillan las llamas."))
	p.closed.connect(retry)


func retry() -> void:
	_reset()


func open_pause() -> void:
	if finished or get_tree().paused or get_node_or_null("PauseMenu") != null:
		return
	if stick != null:
		stick.release()
	PauseMenu.open(self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_inside_tree() and not UI.test_mode:
			open_pause()


func bot_state() -> Dictionary:
	return {"deaths": deaths, "coins": coins, "finished": finished, "failed": failed, "stomps": int(st.get("kills", 0)), "time": time_in_level,
		"tick": int(st.get("tick", 0)), "lives": int(st.get("lives", 0))}
