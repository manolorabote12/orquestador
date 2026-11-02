extends Node2D
## Adivina la palabra (estilo Wordle): escribe palabras con el teclado de abajo; cada letra se pinta
## de verde (en su sitio), amarillo (esta en otro sitio) o gris (no esta).
## Reglas, eleccion de la palabra, bot y analizador en wordle_map.gd; diccionarios en kit/words.
## La palabra sale del diccionario del idioma del jugador (Kit.lang()).
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const REVIVE_N: int = 1
const M = preload("res://kit/wordle/wordle_map.gd")
const D = preload("res://kit/words/words_dict.gd")
const COL_G: Color = Color("#4caf50")
const COL_Y: Color = Color("#e6b422")
const COL_X: Color = Color("#5a6270")
const COL_EMPTY: Color = Color("#1f2a3c")

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
var typed: String = ""

var _font: Font
var _board: Control
var _keys: Control
var _msg: Label
var _hint_btn: Button
var _shake: float = 0.0
var _flip: Dictionary = {}
var _t: float = 0.0
var _key_rects: Dictionary = {}


func _ready() -> void:
	level = Kit.current_level()
	RenderingServer.set_default_clear_color(Color("#121a28"))
	_font = UI.theme.get_font("font", "Label") if UI.theme != null else ThemeDB.fallback_font
	_build_hud()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "wordle", "len": int(st["len"]), "lang": str(st["lang"])})


func bot_script() -> String:
	return "res://qa/wordle_bot.gd"


func capture_delays() -> Vector2:
	## Con una y dos filas escritas (el bot prueba cada 0,8 s): antes de acertar.
	return Vector2(1.0, 0.9)


func _reset() -> void:
	finished = false
	failed = false
	st = M.new_state(level, Kit.lang(), deaths)
	typed = ""
	coins = 0
	time_in_level = 0.0
	_flip.clear()
	if _msg != null:
		_msg.text = ""
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
	var title: Label = Label.new()
	title.name = "Title"
	title.text = Kit.text("wd_title", "Adivina la palabra")
	title.theme_type_variation = "HeaderLabel"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	_hint_btn = UI.make_button(Kit.text("wd_hint", "Pista"), false, "star")
	_hint_btn.name = "BtnHint"
	_hint_btn.pressed.connect(use_hint)
	top.add_child(_hint_btn)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)
	_board = Control.new()
	_board.name = "Board"
	_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.draw.connect(_draw_board)
	col.add_child(_board)
	_msg = Label.new()
	_msg.name = "Msg"
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg.add_theme_font_size_override("font_size", 30)
	_msg.add_theme_color_override("font_color", Color("#ffe08a"))
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_msg)
	_keys = Control.new()
	_keys.name = "Keyboard"
	_keys.custom_minimum_size = Vector2(0.0, 3.0 * 104.0)
	_keys.mouse_filter = Control.MOUSE_FILTER_STOP
	_keys.draw.connect(_draw_keys)
	_keys.gui_input.connect(_on_keys_input)
	col.add_child(_keys)


func _rows() -> Array[String]:
	var r: Array[String] = ["QWERTYUIOP", "ASDFGHJKL" + ("\u00d1" if str(st.get("lang", "")) == "es" else ""), "<ZXCVBNM>"]
	return r


# ------------------------------------------------------------------ acciones

func can_act() -> bool:
	return not finished and not failed and is_inside_tree() and not get_tree().paused


## Escribe una letra (o "<" borrar, ">" enviar).
func press(k: String) -> void:
	if not can_act():
		return
	if k == "<":
		typed = typed.substr(0, maxi(0, typed.length() - 1))
	elif k == ">":
		submit()
		return
	elif typed.length() < int(st["len"]):
		typed += k
		_sfx("click", -14.0)
	_refresh()


## Envia lo escrito. true si era un intento valido.
func submit() -> bool:
	if not can_act():
		return false
	var why: String = M.why_not(st, typed)
	if why != "":
		_shake = 0.35
		_msg.text = {"short": Kit.text("wd_short", "Faltan letras"), "word": Kit.text("wd_not_word", "No est\u00e1 en el diccionario"),
			"hard": Kit.text("wd_hard", "Usa las pistas que ya tienes")}.get(why, "")
		_sfx("hurt", -10.0)
		_refresh()
		return false
	var row: int = (st["rows"] as Array).size()
	M.guess(st, typed)
	_flip[row] = 0.0
	typed = ""
	_msg.text = ""
	_sfx("coin", -8.0)
	_refresh()
	if bool(st["won"]):
		coins = 1
		_finish()
	elif bool(st["over"]):
		_lose()
	return true


## Pista: descubre una letra (una por nivel).
func use_hint() -> void:
	if not can_act():
		return
	var h: Array = M.hint(st)
	if int(h[0]) < 0:
		return
	_msg.text = Kit.text("wd_hint_msg", "La letra {n} es {c}").format({"n": int(h[0]) + 1, "c": str(h[1])})
	_sfx("powerup", -8.0)
	_refresh()


func bot_step() -> void:
	if not can_act():
		return
	typed = M.bot_guess(st)
	submit()


func _sfx(n: String, vol: float = -6.0) -> void:
	if not fast:
		Audio.play(n, 0.1, vol)


func _refresh() -> void:
	if _board == null or st.is_empty():
		return
	_hint_btn.disabled = int(st["hint_left"]) <= 0 or finished
	_board.queue_redraw()
	_keys.queue_redraw()


# ------------------------------------------------------------------ bucle y entrada

func _physics_process(delta: float) -> void:
	_t += delta
	_shake = maxf(0.0, _shake - delta)
	for r: Variant in _flip.keys():
		_flip[r] = float(_flip[r]) + delta * (6.0 if fast else 1.6)
		if float(_flip[r]) > 1.2:
			_flip.erase(r)
	if not finished:
		time_in_level += delta
	if fast and auto_retry and can_act():
		bot_step()
	if _shake > 0.0 or not _flip.is_empty():
		_board.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()
		return
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var kc: Key = (event as InputEventKey).keycode
		if kc == KEY_ENTER or kc == KEY_KP_ENTER:
			press(">")
		elif kc == KEY_BACKSPACE:
			press("<")
		else:
			var ch: String = char((event as InputEventKey).unicode).to_upper()
			if ch.length() == 1 and D.alphabet(str(st["lang"])).contains(ch):
				press(ch)


func _on_keys_input(event: InputEvent) -> void:
	var at: Vector2 = Vector2.INF
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		at = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and not DisplayServer.is_touchscreen_available():
		at = (event as InputEventMouseButton).position
	if at == Vector2.INF:
		return
	for k: String in _key_rects:
		if (_key_rects[k] as Rect2).has_point(at):
			press(k)
			return


# ------------------------------------------------------------------ dibujo

func _draw_board() -> void:
	if st.is_empty():
		return
	var n: int = int(st["len"])
	var tries: int = int(st["tries"])
	var sz: Vector2 = _board.size
	var cell: float = minf(minf((sz.x - 20.0) / float(n), (sz.y - 20.0) / float(tries)), 108.0)
	var gap: float = cell * 0.1
	var w: float = cell * float(n)
	var h: float = cell * float(tries)
	var o: Vector2 = Vector2((sz.x - w) * 0.5, (sz.y - h) * 0.5)
	var fs: int = int(cell * 0.56)
	for r: int in tries:
		var dx: float = sin(_t * 60.0) * 14.0 * _shake if r == (st["rows"] as Array).size() else 0.0
		for i: int in n:
			var rect: Rect2 = Rect2(o + Vector2(float(i) * cell + gap * 0.5 + dx, float(r) * cell + gap * 0.5), Vector2(cell - gap, cell - gap))
			var ch: String = ""
			var col: Color = COL_EMPTY
			var border: Color = Color("#3a4a64")
			if r < (st["rows"] as Array).size():
				ch = str(st["rows"][r])[i]
				var m: String = str(st["marks"][r])[i]
				## Volteo letra a letra al enviar.
				var shown: bool = not _flip.has(r) or float(_flip[r]) > float(i) * 0.18 + 0.1
				col = (COL_G if m == M.GREEN else (COL_Y if m == M.YELLOW else COL_X)) if shown else COL_EMPTY
				border = col
				if _flip.has(r):
					var k: float = clampf((float(_flip[r]) - float(i) * 0.18) / 0.2, 0.0, 1.0)
					var sq: float = absf(cos(k * PI))
					rect = Rect2(rect.position + Vector2(0.0, rect.size.y * (1.0 - sq) * 0.5), Vector2(rect.size.x, maxf(2.0, rect.size.y * sq)))
			elif r == (st["rows"] as Array).size() and i < typed.length():
				ch = typed[i]
				border = Color("#8aa0c8")
			elif r == (st["rows"] as Array).size() and (st["hints"] as Array).has(i):
				ch = str(st["word"])[i]
				border = COL_G
			_board.draw_rect(rect, col)
			_board.draw_rect(rect, border, false, 3.0)
			if ch != "":
				var tw: float = _font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				var tc: Color = Color.WHITE if col != COL_EMPTY or r != (st["rows"] as Array).size() or i < typed.length() else Color(0.6, 0.9, 0.6)
				_board.draw_string(_font, rect.get_center() + Vector2(-tw * 0.5, fs * 0.36), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, tc)


func _draw_keys() -> void:
	if st.is_empty():
		return
	_key_rects.clear()
	var rows: Array[String] = _rows()
	var sz: Vector2 = _keys.size
	var kh: float = sz.y / 3.0
	var kw: float = minf(sz.x / 10.0, 80.0)
	var fs: int = 30
	for r: int in rows.size():
		var row: String = rows[r]
		var units: float = 0.0
		for ch: String in row:
			units += 1.5 if ch == "<" or ch == ">" else 1.0
		var x: float = (sz.x - units * kw) * 0.5
		for ch2: String in row:
			var wide: float = 1.5 if ch2 == "<" or ch2 == ">" else 1.0
			var rect: Rect2 = Rect2(Vector2(x + 3.0, float(r) * kh + 4.0), Vector2(kw * wide - 6.0, kh - 8.0))
			_key_rects[ch2] = rect
			var m: String = str((st["keys"] as Dictionary).get(ch2, ""))
			## Gris = probada y no esta: casi apagada, para que se vea de un vistazo lo que queda.
			var col: Color = Color("#4a5b7a") if m == "" else (COL_G if m == M.GREEN else (COL_Y if m == M.YELLOW else Color("#1b212b")))
			_keys.draw_rect(rect, col)
			var label: String = ch2
			var kfs: int = fs
			if ch2 == "<":
				label = Kit.text("wd_del", "Borrar")
				kfs = 20
			elif ch2 == ">":
				label = Kit.text("wd_ok", "OK")
				kfs = 24
			var tw: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, kfs).x
			_keys.draw_string(_font, rect.get_center() + Vector2(-tw * 0.5, kfs * 0.36), label, HORIZONTAL_ALIGNMENT_LEFT, -1, kfs, Color(1, 1, 1, 0.35) if m == M.GRAY else Color.WHITE)
			x += kw * wide


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var used: int = (st["rows"] as Array).size()
	var score: int = maxi(1, (int(st["tries"]) - used + 1) * 300 + int(st["hint_left"]) * 200)
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "tries": used, "time": snappedf(time_in_level, 0.1)})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


## Estrellas por intentos: hasta la mitad, 3; hasta dos de menos, 2; si no, 1 (la pista quita una).
func stars_earned() -> int:
	var used: int = (st["rows"] as Array).size()
	var tries: int = int(st["tries"])
	var s: int = 3 if used <= tries / 2 + 1 else (2 if used <= tries - 1 else 1)
	if int(st["hint_left"]) <= 0:
		s = maxi(1, s - 1)
	return s


func _lose() -> void:
	if failed:
		return
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "wordle", "word": str(st["word"]), "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("wd_lost", "La palabra era {w}").format({"w": str(st["word"])}),
		Kit.text("wd_lost_hint", "Empieza con palabras de letras distintas y muy usadas. Otra palabra te espera."))
	p.closed.connect(retry)


## Al reintentar sale otra palabra (si no, ya te la sabrias).
## Segunda oportunidad (FailPanel, con anuncio): una fila mas para adivinar la palabra.
func revive() -> void:
	st["tries"] = int(st["tries"]) + REVIVE_N
	st["over"] = false
	failed = false
	_refresh()


func revive_text() -> String:
	return Kit.text("revive_tries", "+{n} intentos").format({"n": REVIVE_N})


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
		"tries": (st.get("rows", []) as Array).size(), "word": str(st.get("word", ""))}
