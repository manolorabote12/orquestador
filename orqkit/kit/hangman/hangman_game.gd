extends Node2D
## Ahorcado con globos: toca letras del teclado; las que no estan revientan un globo del ramo del
## que cuelga el heroe. Pista: destapa una letra. Reglas, bot y analizador en hangman_map.gd.
## La palabra sale del diccionario del idioma del jugador (Kit.lang()).
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const M = preload("res://kit/hangman/hangman_map.gd")
const D = preload("res://kit/words/words_dict.gd")
const BALLOON_COLS: Array[String] = ["#ff5d73", "#ffb703", "#4cc9f0", "#80ed99", "#c77dff", "#ff8fab", "#f4a261", "#90e0ef"]

var level: Dictionary = {}
var st: Dictionary = {}
var finished: bool = false
var failed: bool = false
var deaths: int = 0
var time_in_level: float = 0.0
var coins: int = 0
var coins_total: int = 1
var fast: bool = false
var auto_retry: bool = false
var result_panel: ResultPanel

var _view: Control
var _info: Label
var _hint_btn: Button
var _keys: GridContainer
var _hero: Texture2D = null
var _pops: Array = []
var _fall: float = 0.0
var _t: float = 0.0


func _ready() -> void:
	level = Kit.current_level()
	RenderingServer.set_default_clear_color(Kit.color("sky", Color("#8ecae6")))
	var hero: Dictionary = Kit.sprite_by_role("jugador")
	if not hero.is_empty():
		var sf: SpriteFrames = SpriteKit.frames_de(hero)
		for anim: String in sf.get_animation_names():
			if sf.get_frame_count(anim) > 0:
				_hero = sf.get_frame_texture(anim, 0)
				break
	_build_hud()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "hangman", "len": int(level.get("len", 5))})


func bot_script() -> String:
	return "res://qa/hangman_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(2.5, 1.6)


func _reset() -> void:
	finished = false
	failed = false
	st = M.new_state(level, Kit.lang(), deaths)
	coins = 0
	time_in_level = 0.0
	_pops.clear()
	_fall = 0.0
	_build_keys()
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
	col.add_theme_constant_override("separation", 10)
	safe.add_child(col)
	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top)
	_info = Label.new()
	_info.name = "Info"
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.add_theme_font_size_override("font_size", 28)
	_info.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_info.add_theme_constant_override("outline_size", 6)
	top.add_child(_info)
	_hint_btn = UI.make_button("", false, "star")
	_hint_btn.name = "BtnHint"
	_hint_btn.pressed.connect(hint)
	top.add_child(_hint_btn)
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
	_keys = GridContainer.new()
	_keys.name = "Keys"
	_keys.columns = 7
	_keys.add_theme_constant_override("h_separation", 6)
	_keys.add_theme_constant_override("v_separation", 6)
	col.add_child(_keys)


func _build_keys() -> void:
	for c: Node in _keys.get_children():
		c.queue_free()
	for ch: String in D.alphabet(str(st["lang"])):
		var b: Button = Button.new()
		b.name = "Key_" + ch
		b.text = ch
		## Teclas del alto minimo de dedo (88).
		b.custom_minimum_size = Vector2(88, UI.MIN_TOUCH)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 32)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(press.bind(ch))
		_keys.add_child(b)


func can_act() -> bool:
	return not finished and not failed and is_inside_tree() and not get_tree().paused and not st.is_empty()


func press(ch: String) -> void:
	if not can_act():
		return
	var r: String = M.guess(st, ch)
	if r == "":
		return
	var key: Button = _keys.get_node_or_null("Key_" + ch)
	if key != null:
		key.disabled = true
		key.modulate = Color(0.55, 1.0, 0.6) if r == "hit" else Color(1.0, 0.5, 0.5, 0.7)
	if r == "hit":
		_sfx("coin", -8.0)
	else:
		_pops.append({"i": int(st["misses"]) - 1, "t": 0.0})
		_sfx("hurt", -10.0)
	_refresh()
	if bool(st["won"]):
		_finish()
	elif bool(st["lost"]):
		_lose()


func hint() -> void:
	if not can_act():
		return
	var ch: String = M.use_hint(st)
	if ch != "":
		var key: Button = _keys.get_node_or_null("Key_" + ch)
		if key != null:
			key.disabled = true
			key.modulate = Color(0.55, 1.0, 0.6)
		_sfx("powerup", -8.0)
		_refresh()
		if bool(st["won"]):
			_finish()


func bot_step() -> void:
	if can_act():
		var ch: String = M.bot_letter(st)
		if ch != "":
			press(ch)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()
	elif event is InputEventKey and (event as InputEventKey).pressed and can_act():
		var ch: String = char((event as InputEventKey).unicode).to_upper()
		if ch.length() == 1 and D.alphabet(str(st["lang"])).contains(ch):
			press(ch)


func _sfx(nm: String, vol: float = -6.0) -> void:
	if not fast:
		Audio.play(nm, 0.1, vol)


func _refresh() -> void:
	if st.is_empty() or _info == null:
		return
	var left: int = int(st["lives"]) - int(st["misses"])
	_info.text = Kit.text("hm_balloons", "Globos {a}/{b}").format({"a": left, "b": int(st["lives"])})
	_hint_btn.text = " " + str(int(st["hints"]))
	_hint_btn.disabled = int(st["hints"]) <= 0
	_view.queue_redraw()


func _physics_process(delta: float) -> void:
	if st.is_empty() or get_tree().paused:
		return
	_t += delta
	if not finished and not failed:
		time_in_level += delta
		if fast and auto_retry:
			bot_step()
	for p: Variant in _pops:
		(p as Dictionary)["t"] = float((p as Dictionary)["t"]) + delta
	if bool(st.get("lost", false)):
		_fall = minf(1.0, _fall + delta * 1.5)
	_view.queue_redraw()


# ------------------------------------------------------------------ dibujo

func _draw_view() -> void:
	if st.is_empty():
		return
	var sz: Vector2 = _view.size
	var font: Font = _view.get_theme_font("font", "Label")
	var lives: int = int(st["lives"])
	var left: int = lives - int(st["misses"])
	## Suelo lejano y nubes.
	var ground: Color = Kit.color("ground", Color("#7cb518"))
	_view.draw_rect(Rect2(Vector2(-20, sz.y * 0.7), Vector2(sz.x + 40, sz.y * 0.3)), ground)
	_view.draw_rect(Rect2(Vector2(-20, sz.y * 0.7), Vector2(sz.x + 40, 10)), ground.lightened(0.25))
	for k: int in 3:
		var cx: float = fmod(_t * 12.0 * float(k + 1) + float(k) * 260.0, sz.x + 200.0) - 100.0
		var cy: float = 40.0 + float(k) * 50.0
		for j: int in 3:
			_view.draw_circle(Vector2(cx + float(j - 1) * 34.0, cy + (8.0 if j != 1 else 0.0)), 28.0, Color(1, 1, 1, 0.7))
	## El heroe colgando, con un vaiven suave (y cayendo si se acaban los globos).
	var sway: float = sin(_t * 1.6) * 10.0
	var hero_c: Vector2 = Vector2(sz.x * 0.5 + sway, sz.y * 0.36 + _fall * sz.y * 0.6)
	var knot: Vector2 = hero_c + Vector2(0, -70)
	for b: int in lives:
		var a: float = lerpf(-0.9, 0.9, float(b) / maxf(1.0, float(lives - 1)))
		var bp: Vector2 = knot + Vector2(sin(a) * 120.0, -110.0 - cos(a) * 60.0) + Vector2(0, sin(_t * 2.0 + float(b)) * 6.0)
		var col: Color = Color(BALLOON_COLS[b % BALLOON_COLS.size()])
		if b < left:
			_view.draw_line(knot, bp + Vector2(0, 34), Color(0.2, 0.2, 0.2, 0.7), 2.0)
			_draw_balloon(bp, col)
		else:
			## Reventado: unos trozos que se abren y se desvanecen.
			var pop: float = 1.0
			for p: Variant in _pops:
				if int((p as Dictionary)["i"]) == lives - 1 - b:
					pop = float((p as Dictionary)["t"])
			if pop < 0.5:
				for s: int in 6:
					var da: float = TAU * float(s) / 6.0
					_view.draw_circle(bp + Vector2(cos(da), sin(da)) * (20.0 + pop * 90.0), 6.0 * (1.0 - pop * 2.0), col)
	if not bool(st["lost"]) or _fall < 1.0:
		if _hero != null:
			var ts: Vector2 = _hero.get_size()
			var k2: float = 130.0 / maxf(ts.x, ts.y)
			_view.draw_texture_rect(_hero, Rect2(hero_c - ts * k2 * 0.5, ts * k2), false)
		else:
			_view.draw_circle(hero_c + Vector2(0, -30), 26.0, Color("#ffd6a5"))
			_view.draw_rect(Rect2(hero_c + Vector2(-24, -6), Vector2(48, 60)), Color("#e63946"))
		_view.draw_line(knot, hero_c + Vector2(0, -50), Color(0.2, 0.2, 0.2, 0.8), 3.0)
	## La palabra.
	var word: String = str(st["word"])
	var shown: String = M.shown(st) if not bool(st["lost"]) else word
	var n: int = word.length()
	var cell: float = minf(84.0, (sz.x - 20.0) / float(n))
	var x0: float = (sz.x - cell * float(n)) * 0.5
	var y0: float = sz.y * 0.78
	for i: int in n:
		var r: Rect2 = Rect2(Vector2(x0 + float(i) * cell, y0), Vector2(cell, cell)).grow(-5.0)
		_view.draw_rect(r, Color(1, 1, 1, 0.92))
		_view.draw_rect(r, Color(0, 0, 0, 0.6), false, 3.0)
		var ch: String = shown[i]
		if ch != "_":
			var miss_col: Color = Color("#d62828") if bool(st["lost"]) and M.shown(st)[i] == "_" else Color("#1d3557")
			_view.draw_string(font, Vector2(r.position.x, r.end.y - r.size.y * 0.22), ch, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, int(r.size.y * 0.62), miss_col)


func _draw_balloon(p: Vector2, col: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for k: int in 20:
		var a: float = TAU * float(k) / 20.0
		pts.append(p + Vector2(cos(a) * 30.0, sin(a) * 36.0))
	_view.draw_colored_polygon(pts, col)
	_view.draw_colored_polygon(PackedVector2Array([p + Vector2(-6, 40), p + Vector2(6, 40), p + Vector2(0, 33)]), col.darkened(0.2))
	_view.draw_circle(p + Vector2(-10, -14), 7.0, Color(1, 1, 1, 0.55))


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	coins = 1
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var left: int = int(st["lives"]) - int(st["misses"])
	var score: int = 300 + left * 100 + str(st["word"]).length() * 20
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "misses": int(st["misses"]), "time": snappedf(time_in_level, 0.1)})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


## Estrellas: sin reventar ninguno (ni pista), 3; con la mitad o mas de los globos, 2; si no, 1.
func stars_earned() -> int:
	var used: int = int(level.get("hint", 1)) - int(st["hints"])
	if int(st["misses"]) == 0 and used == 0:
		return 3
	return 2 if int(st["misses"]) * 2 <= int(st["lives"]) else 1


func _lose() -> void:
	if failed:
		return
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "hangman", "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("hm_lost", "Era: {w}").format({"w": str(st["word"])}),
		Kit.text("hm_hint", "Empieza por las vocales y luego las letras mas comunes (S, R, N, L, T)."))
	p.closed.connect(retry)


## Segunda oportunidad (FailPanel, con anuncio): una vida mas y se sigue donde ibas.
func revive() -> void:
	st["misses"] = maxi(0, int(st["misses"]) - 1)
	failed = false
	_refresh()


func revive_text() -> String:
	return Kit.text("revive_life", "Una vida m\u00e1s")


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
	return {"deaths": deaths, "coins": coins, "finished": finished, "failed": failed, "stomps": 0, "time": time_in_level,
		"misses": int(st.get("misses", 0))}
