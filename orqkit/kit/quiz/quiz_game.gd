extends Node2D
## Juego de preguntas: cada nivel es una tanda de preguntas con 4 respuestas contra el reloj.
## 1 - El heroe presenta (arriba, con su arte); la pregunta en una tarjeta y 4 botones grandes.
## 2 - Acierto: moneda y racha. Fallo o tiempo: se marca la buena y se lee la explicacion.
## 3 - Pasas el nivel con los aciertos de game.json -> levels[i].pass; si no, a repetir.
## 4 - Estrellas: 3 todo bien, 2 con un fallo como mucho (o el 80 %), 1 si pasas justo.
## Nivel: levels[i] = {"map": ["QQQQQ"], "questions": [{"q", "a": [4], "ok", "why"}], "time", "pass"}.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const REVEAL_TIME: float = 1.9

var questions: Array = []
var finished: bool = false
var failed: bool = false
var deaths: int = 0
var time_in_level: float = 0.0
var coins: int = 0
var coins_total: int = 0
var correct: int = 0
var streak: int = 0
var best_streak: int = 0
var index: int = 0
var time_per_question: float = 20.0
var time_left: float = 20.0
var to_pass: int = 1
var answering: bool = false
var fast: bool = false
var auto_retry: bool = false
var result_panel: ResultPanel

var _hud: CanvasLayer
var _counter: Label
var _streak_label: Label
var _timer_fill: ColorRect
var _timer_back: ColorRect
var _card_text: Label
var _why: Label
var _buttons: Array[Button] = []
var _host: Control
var _reveal_left: float = 0.0


func _ready() -> void:
	var lv: Dictionary = Kit.current_level()
	var qs: Variant = lv.get("questions", [])
	questions = qs if qs is Array else []
	time_per_question = float(lv.get("time", 20.0))
	to_pass = clampi(int(lv.get("pass", ceili(questions.size() * 0.6))), 1, maxi(questions.size(), 1))
	coins_total = questions.size()
	RenderingServer.set_default_clear_color(Kit.color("sky", Color("#1b2a41")))
	_build_ui()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "quiz", "questions": questions.size(), "pass": to_pass})


## Juego de interfaz (preguntas y botones): sin etalonaje para que el texto se vea limpio.
func wants_grade() -> bool:
	return false


func bot_script() -> String:
	return "res://qa/quiz_bot.gd"


func _build_ui() -> void:
	_hud = CanvasLayer.new()
	_hud.name = "Hud"
	_hud.layer = 10
	add_child(_hud)
	var root: Control = Control.new()
	root.theme = UI.theme
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.add_child(root)
	var safe: MarginContainer = UI.safe_root(root, 24.0)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	safe.add_child(col)
	## 1 - Barra: aciertos, racha y pausa.
	var top: HBoxContainer = HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	col.add_child(top)
	top.add_child(UiIcon.make("coin", Kit.color("coin", UI.colors["acento"]), 40.0))
	_counter = Label.new()
	_counter.name = "Counter"
	top.add_child(_counter)
	_streak_label = Label.new()
	_streak_label.name = "Streak"
	_streak_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_streak_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_streak_label.add_theme_color_override("font_color", UI.colors["acento"])
	top.add_child(_streak_label)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)
	## 2 - El presentador: el heroe con su arte.
	_host = Control.new()
	_host.name = "Host"
	_host.custom_minimum_size = Vector2(0.0, 170.0)
	col.add_child(_host)
	var portrait: TextureRect = TextureRect.new()
	portrait.name = "HostSprite"
	portrait.texture = DialogPanel.portrait_of(Kit.sprite_by_role("jugador"))
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	_host.add_child(portrait)
	_host.resized.connect(func() -> void: portrait.pivot_offset = _host.size * 0.5)
	## 3 - Tiempo.
	_timer_back = ColorRect.new()
	_timer_back.custom_minimum_size = Vector2(0.0, 14.0)
	_timer_back.color = UI.colors["borde"]
	col.add_child(_timer_back)
	_timer_fill = ColorRect.new()
	_timer_fill.name = "TimerFill"
	_timer_fill.color = UI.colors["acento"]
	_timer_back.add_child(_timer_fill)
	## 4 - Tarjeta de la pregunta.
	var card: PanelContainer = PanelContainer.new()
	card.name = "Card"
	col.add_child(card)
	var card_col: VBoxContainer = VBoxContainer.new()
	card_col.add_theme_constant_override("separation", 10)
	card.add_child(card_col)
	_card_text = Label.new()
	_card_text.name = "Question"
	_card_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_text.theme_type_variation = "HeaderLabel"
	_card_text.add_theme_font_size_override("font_size", 38)
	_card_text.custom_minimum_size = Vector2(0.0, 150.0)
	_card_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card_col.add_child(_card_text)
	_why = Label.new()
	_why.name = "Why"
	_why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_why.theme_type_variation = "SubtleLabel"
	_why.modulate.a = 0.0
	card_col.add_child(_why)
	## 5 - Respuestas abajo, donde llega el pulgar.
	var grow: Control = Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(grow)
	var answers: VBoxContainer = VBoxContainer.new()
	answers.name = "Answers"
	answers.add_theme_constant_override("separation", 14)
	col.add_child(answers)
	for k: int in 4:
		var b: Button = UI.make_button("", false, "")
		b.name = "Answer%d" % k
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(0.0, 96.0)
		b.pressed.connect(answer.bind(k))
		answers.add_child(b)
		_buttons.append(b)


func _reset() -> void:
	finished = false
	failed = false
	coins = 0
	correct = 0
	streak = 0
	best_streak = 0
	index = 0
	_show_question()


func current() -> Dictionary:
	if index < 0 or index >= questions.size() or not questions[index] is Dictionary:
		return {}
	return questions[index]


func _show_question() -> void:
	var q: Dictionary = current()
	answering = not q.is_empty()
	time_left = time_per_question
	_reveal_left = 0.0
	_card_text.text = str(q.get("q", ""))
	_why.text = ""
	_why.modulate.a = 0.0
	var opts: Array = q.get("a", [])
	for k: int in 4:
		var b: Button = _buttons[k]
		b.text = str(opts[k]) if k < opts.size() else ""
		b.disabled = false
		b.theme_type_variation = ""
		b.modulate = Color.WHITE
	_update_hud()
	if not UI.test_mode:
		UI.pop_in(_card_text, 0.0)


func _update_hud() -> void:
	_counter.text = "%d/%d" % [correct, questions.size()]
	_streak_label.text = (Kit.text("quiz_question", "Pregunta") + " %d/%d" % [mini(index + 1, questions.size()), questions.size()]) \
		+ ("   x%d" % streak if streak >= 2 else "")


## Responde con la opcion k (0 a 3). -1 = se acabo el tiempo.
func answer(k: int) -> void:
	if not answering or finished or get_tree().paused:
		return
	answering = false
	var q: Dictionary = current()
	var ok: int = int(q.get("ok", 0))
	var right: bool = k == ok
	for i: int in 4:
		_buttons[i].disabled = true
	_buttons[ok].disabled = false
	_buttons[ok].theme_type_variation = "PrimaryButton"
	if right:
		correct += 1
		coins += 1
		streak += 1
		best_streak = maxi(best_streak, streak)
		Audio.play("coin")
		UI.float_text(_hud.get_child(0), _buttons[ok].get_global_rect().get_center() - Vector2(0.0, 60.0),
			Kit.text("quiz_correct", "\u00a1Correcto!"), UI.colors["exito"], 34)
		var spr: Control = _host.get_node_or_null("HostSprite") as Control
		if spr != null:
			UI.pop_in(spr, 0.0)
	else:
		streak = 0
		Audio.play("hurt")
		Juice.shake(0.25)
		if k >= 0:
			_buttons[k].modulate = UI.colors["peligro"]
		_why.text = (Kit.text("quiz_time", "\u00a1Se acab\u00f3 el tiempo!") + "  " if k < 0 else "") + str(q.get("why", ""))
		_why.modulate.a = 1.0
	QA.log_event("quiz_answer", {"index": index, "right": right, "timeout": k < 0})
	_reveal_left = REVEAL_TIME * (0.6 if right else 1.0) * (0.15 if fast else 1.0)
	_update_hud()


func _next() -> void:
	index += 1
	if index >= questions.size():
		_end()
		return
	_show_question()


func _process(delta: float) -> void:
	if finished or get_tree().paused:
		return
	time_in_level += delta
	if answering:
		time_left -= delta
		var w: float = _timer_back.size.x * clampf(time_left / maxf(time_per_question, 0.1), 0.0, 1.0)
		_timer_fill.size = Vector2(w, _timer_back.size.y)
		_timer_fill.color = UI.colors["peligro"] if time_left < 5.0 else UI.colors["acento"]
		if time_left <= 0.0:
			answer(-1)
	elif _reveal_left > 0.0:
		_reveal_left -= delta
		if _reveal_left <= 0.0:
			_next()


# ------------------------------------------------------------------ final

func _end() -> void:
	if correct < to_pass:
		_lose()
		return
	finished = true
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = correct * 300 + best_streak * 100
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "correct": correct, "total": questions.size(), "stars": stars})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


func stars_earned() -> int:
	var n: int = questions.size()
	if correct >= n:
		return 3
	if correct >= n - 1 or float(correct) >= float(n) * 0.8:
		return 2
	return 1


func _lose() -> void:
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "few_correct", "correct": correct, "pass": to_pass, "deaths": deaths})
	if auto_retry:
		retry()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("quiz_lost", "Te faltan aciertos"),
		Kit.text("quiz_hint", "Acierta al menos {n} preguntas para pasar de nivel").format({"n": to_pass}))
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
	return {"deaths": deaths, "coins": coins, "finished": finished, "failed": failed, "stomps": 0,
		"correct": correct, "index": index, "answering": answering}
