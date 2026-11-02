extends Node2D
## Comecocos (tipo Pac-Man): desliza el dedo hacia donde quieras ir (se recuerda hasta que se
## pueda girar). Come todos los puntos sin que te pillen los fantasmas; las pildoras grandes los
## asustan y entonces te los puedes comer. Tres vidas. Reglas, bot y analizador en chomp_map.gd.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const M = preload("res://kit/chomp/chomp_map.gd")
const DT: float = 1.0 / float(M.TPS)
const SWIPE: float = 28.0
const GHOST_COL: Array[String] = ["#ef5350", "#f48fb1", "#4dd0e1", "#ffb74d"]

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
var want: Vector2i = Vector2i.ZERO

var _view: Control
var _info: Label
var _hero_tex: Texture2D = null
var _acc: float = 0.0
var _vis: Dictionary = {}
var _fx: Array = []
var _log_seen: int = 0
var _t: float = 0.0
var _touch: Vector2 = Vector2.INF
var _face: Vector2i = Vector2i(1, 0)


func _ready() -> void:
	level = Kit.current_level()
	RenderingServer.set_default_clear_color(Color("#0d0f1f"))
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
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "chomp", "dots": int(st["dots_total"])})


func wants_grade() -> bool:
	return false


func bot_script() -> String:
	return "res://qa/chomp_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(4.0, 2.5)


func _reset() -> void:
	finished = false
	failed = false
	st = M.new_state(level)
	coins_total = int(st["dots_total"])
	coins = 0
	time_in_level = 0.0
	_acc = 0.0
	_fx = []
	_log_seen = 0
	want = Vector2i.ZERO
	_vis = {"p": Vector2(st["p"])}
	for i: int in (st["ghosts"] as Array).size():
		_vis[i] = Vector2(st["ghosts"][i]["p"])
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
	_view = Control.new()
	_view.name = "View"
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.draw.connect(_draw_view)
	_view.gui_input.connect(_on_input)
	root.add_child(_view)
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
	_info.add_theme_font_size_override("font_size", 28)
	_info.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_info.add_theme_constant_override("outline_size", 6)
	top.add_child(_info)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)
	var gap: Control = Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(gap)
	var hint: Label = Label.new()
	hint.name = "Hint"
	hint.text = Kit.text("cm_swipe", "Desliza para girar")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(1, 1, 1, 0.45)
	col.add_child(hint)


func _refresh() -> void:
	if st.is_empty() or _info == null:
		return
	_info.text = "\u2665 %d   %d   \u25cf %d" % [int(st["lives"]), int(st["score"]), (st["dots"] as Dictionary).size()]


func can_act() -> bool:
	return not finished and not failed and is_inside_tree() and not get_tree().paused and not bool(st["won"]) and not bool(st["lost"])


func _cs() -> float:
	return minf(_view.size.x / float(st["w"]), (_view.size.y - 260.0) / float(st["h"]))


func _origin() -> Vector2:
	var cs: float = _cs()
	return Vector2((_view.size.x - float(st["w"]) * cs) * 0.5, 120.0 + (_view.size.y - 260.0 - float(st["h"]) * cs) * 0.5)


func steer(d: Vector2i) -> void:
	if can_act():
		want = d


func _on_input(event: InputEvent) -> void:
	var pos: Vector2 = Vector2.INF
	var pressed: int = -1
	if event is InputEventScreenTouch:
		pos = (event as InputEventScreenTouch).position
		pressed = 1 if (event as InputEventScreenTouch).pressed else 0
	elif event is InputEventScreenDrag:
		pos = (event as InputEventScreenDrag).position
	elif event is InputEventMouseButton and not DisplayServer.is_touchscreen_available():
		pos = (event as InputEventMouseButton).position
		pressed = 1 if (event as InputEventMouseButton).pressed else 0
	elif event is InputEventMouseMotion and _touch != Vector2.INF and not DisplayServer.is_touchscreen_available():
		pos = (event as InputEventMouseMotion).position
	if pos == Vector2.INF:
		return
	if pressed == 1:
		_touch = pos
	elif pressed == 0:
		_touch = Vector2.INF
	elif _touch != Vector2.INF:
		var dv: Vector2 = pos - _touch
		if dv.length() >= SWIPE:
			steer(Vector2i(int(signf(dv.x)), 0) if absf(dv.x) > absf(dv.y) else Vector2i(0, int(signf(dv.y))))
			_touch = pos


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()
	elif event.is_action_pressed("ui_left"):
		steer(Vector2i(-1, 0))
	elif event.is_action_pressed("ui_right"):
		steer(Vector2i(1, 0))
	elif event.is_action_pressed("ui_up"):
		steer(Vector2i(0, -1))
	elif event.is_action_pressed("ui_down"):
		steer(Vector2i(0, 1))


func bot_step() -> void:
	if can_act():
		want = M.bot_dir(st)


func _tick() -> void:
	var lives0: int = int(st["lives"])
	M.tick(st, want)
	want = Vector2i.ZERO
	if (st["dir"] as Vector2i) != Vector2i.ZERO:
		_face = st["dir"]
	_collect_log()
	if int(st["lives"]) < lives0 and not bool(st["lost"]):
		_vis["p"] = Vector2(st["p"])
		for i: int in (st["ghosts"] as Array).size():
			_vis[i] = Vector2(st["ghosts"][i]["p"])
	if bool(st["won"]):
		_finish()
	elif bool(st["lost"]):
		_lose()


func _physics_process(delta: float) -> void:
	if st.is_empty() or get_tree().paused:
		return
	_t += delta
	if not finished and not failed:
		time_in_level += delta
		if fast and auto_retry:
			for k: int in 6:
				if not can_act():
					break
				bot_step()
				_tick()
		else:
			_acc += delta
			while _acc >= DT and can_act():
				_acc -= DT
				if auto_retry:
					bot_step()
				_tick()
	_vis["p"] = _glide(_vis["p"], Vector2(st["p"]), float(st["speed"]) / DT * delta * 1.1)
	for i: int in (st["ghosts"] as Array).size():
		var g: Dictionary = st["ghosts"][i]
		var sp: float = 1.0 if bool(g["eaten"]) else float(st["ghost_speed"]) * (0.55 if M.frightened(st, g) else 1.0)
		_vis[i] = _glide(_vis[i], Vector2(g["p"]), sp / DT * delta * 1.1)
	for f: Variant in _fx:
		(f as Dictionary)["t"] = float((f as Dictionary)["t"]) + delta
	_fx = _fx.filter(func(f: Dictionary) -> bool: return float(f["t"]) < 0.9)
	_refresh()
	_view.queue_redraw()


func _glide(from: Vector2, to: Vector2, step: float) -> Vector2:
	if from.distance_to(to) > 1.6:
		return to
	return from.move_toward(to, step)


func _collect_log() -> void:
	var lg: Array = st["log"]
	while _log_seen < lg.size():
		var e: Dictionary = lg[_log_seen]
		_log_seen += 1
		match str(e["k"]):
			"dot":
				coins += 1
				if not fast and int(st["tick"]) % 2 == 0:
					Audio.play("ui_tick", 0.05, -16.0)
			"power":
				coins += 1
				_sfx("powerup", -6.0)
			"ghost":
				_fx.append({"at": e["at"], "txt": str(int(e["n"])), "col": Color("#4cc9f0"), "t": 0.0})
				_sfx("stomp", -4.0)
			"dead":
				_sfx("hurt", -2.0)
				if not fast:
					Juice.vibrate(40)


func _sfx(nm: String, vol: float = -6.0) -> void:
	if not fast:
		Audio.play(nm, 0.1, vol)


# ------------------------------------------------------------------ dibujo

func _draw_view() -> void:
	if st.is_empty():
		return
	var cs: float = _cs()
	var o: Vector2 = _origin()
	var wall_c: Color = Kit.color("platform", Color("#3949ab"))
	if wall_c.get_luminance() < 0.25:
		wall_c = wall_c.lightened(0.35)
	var w: int = int(st["w"])
	var h: int = int(st["h"])
	## Muros: bloques redondeados con borde de neon (se unen con los vecinos).
	for y: int in h:
		for x: int in w:
			var q: Vector2i = Vector2i(x, y)
			if (st["map"][y] as String)[x] != "#":
				continue
			var c: Vector2 = o + (Vector2(q) + Vector2(0.5, 0.5)) * cs
			_view.draw_circle(c, cs * 0.32, wall_c.darkened(0.55))
			for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
				var n: Vector2i = q + d
				if n.x < w and n.y < h and (st["map"][n.y] as String)[n.x] == "#":
					_view.draw_line(c, c + Vector2(d) * cs, wall_c.darkened(0.55), cs * 0.64)
	for y2: int in h:
		for x2: int in w:
			var q2: Vector2i = Vector2i(x2, y2)
			if (st["map"][y2] as String)[x2] != "#":
				continue
			var c2: Vector2 = o + (Vector2(q2) + Vector2(0.5, 0.5)) * cs
			_view.draw_circle(c2, cs * 0.2, wall_c)
			for d2: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
				var n2: Vector2i = q2 + d2
				if n2.x < w and n2.y < h and (st["map"][n2.y] as String)[n2.x] == "#":
					_view.draw_line(c2, c2 + Vector2(d2) * cs, wall_c, cs * 0.4)
	## Puntos y pildoras.
	var dot_c: Color = Kit.color("coin", Color("#ffe082"))
	for k: Variant in st["dots"]:
		var dc: Vector2 = o + (Vector2(k) + Vector2(0.5, 0.5)) * cs
		if str(st["dots"][k]) == "o":
			_view.draw_circle(dc, cs * (0.26 + 0.05 * sin(_t * 8.0)), dot_c)
		else:
			_view.draw_circle(dc, cs * 0.1, dot_c)
	## Fantasmas.
	var fr: int = int(st["fright"])
	for i: int in (st["ghosts"] as Array).size():
		var g: Dictionary = st["ghosts"][i]
		var gc: Vector2 = o + ((_vis[i] as Vector2) + Vector2(0.5, 0.5)) * cs
		var r: float = cs * 0.42
		var body: Color = Color(GHOST_COL[i % GHOST_COL.size()])
		if M.frightened(st, g):
			body = Color("#3949ab") if fr > 20 or int(_t * 8.0) % 2 == 0 else Color("#eeeeee")
		if not bool(g["eaten"]):
			var pts: PackedVector2Array = PackedVector2Array()
			for a: int in 13:
				var ang: float = PI + PI * float(a) / 12.0
				pts.append(gc + Vector2(cos(ang), sin(ang)) * r)
			for wv: int in 7:
				var fx: float = r - 2.0 * r * float(wv) / 6.0
				var fy: float = r * (0.9 if wv % 2 == 0 else 0.6) + sin(_t * 12.0 + float(wv)) * r * 0.06
				pts.append(gc + Vector2(fx, fy))
			_view.draw_colored_polygon(pts, body)
		var look: Vector2 = Vector2(g["dir"]) * r * 0.15
		for sx: float in [-1.0, 1.0]:
			var e: Vector2 = gc + Vector2(sx * r * 0.36, -r * 0.15)
			if M.frightened(st, g):
				_view.draw_circle(e, r * 0.1, Color("#ffccbc"))
			else:
				_view.draw_circle(e, r * 0.24, Color.WHITE)
				_view.draw_circle(e + look, r * 0.12, Color("#1a237e"))
	## Heroe: el arte del juego o la boca que se abre y se cierra.
	if int(st["shield"]) <= 0 or int(_t * 10.0) % 2 == 0:
		var hc: Vector2 = o + ((_vis["p"] as Vector2) + Vector2(0.5, 0.5)) * cs
		if _hero_tex != null:
			var ts: Vector2 = _hero_tex.get_size()
			var k2: float = cs * 1.05 / maxf(ts.x, ts.y)
			_view.draw_texture_rect(_hero_tex, Rect2(hc - ts * k2 * 0.5, ts * k2), false)
		else:
			var mouth: float = 0.5 * absf(sin(_t * 12.0))
			var base: float = Vector2(_face).angle()
			var poly: PackedVector2Array = PackedVector2Array([hc])
			for a2: int in 21:
				var an: float = base + mouth + (TAU - 2.0 * mouth) * float(a2) / 20.0
				poly.append(hc + Vector2(cos(an), sin(an)) * cs * 0.42)
			_view.draw_colored_polygon(poly, Color("#ffd54f"))
	var font: Font = _view.get_theme_font("font", "Label")
	for f: Variant in _fx:
		var fd: Dictionary = f
		var fp: Vector2 = o + (Vector2(fd["at"]) + Vector2(0.0, 0.3)) * cs - Vector2(0, float(fd["t"]) * 40.0)
		_view.draw_string_outline(font, fp, str(fd["txt"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, 6, Color.BLACK)
		_view.draw_string(font, fp, str(fd["txt"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, fd["col"])


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = int(st["score"]) + int(st["lives"]) * 300
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "coins": coins, "ticks": int(st["tick"]), "time": snappedf(time_in_level, 0.1)})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


## Estrellas: sin perder vidas, 3; perdiendo una, 2; si no, 1.
func stars_earned() -> int:
	var d: int = int(st["deaths"])
	return 3 if d == 0 else (2 if d == 1 else 1)


func _lose() -> void:
	if failed:
		return
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "chomp", "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("cm_lost", "\u00a1Te han pillado!"),
		Kit.text("cm_hint", "No te metas en un pasillo con fantasmas por los dos lados y guarda las p\u00edldoras para cuando te acorralen."))
	p.closed.connect(retry)


func retry() -> void:
	_reset()


func open_pause() -> void:
	if finished or get_tree().paused or get_node_or_null("PauseMenu") != null:
		return
	_touch = Vector2.INF
	PauseMenu.open(self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_inside_tree() and not UI.test_mode:
			open_pause()


func bot_state() -> Dictionary:
	return {"deaths": deaths, "coins": coins, "finished": finished, "failed": failed, "stomps": 0, "time": time_in_level,
		"tick": int(st.get("tick", 0)), "lives": int(st.get("lives", 0))}
