class_name ResultPanel
extends UiModal
## Pantalla de nivel superado: estrellas que se encienden una a una, monedas y puntos
## que cuentan hacia arriba, aviso de record y botones de siguiente, repetir y niveles.

var result: Dictionary = {}
var stars: StarRow


static func open(host: Node, data: Dictionary) -> ResultPanel:
	var r: ResultPanel = ResultPanel.new()
	r.name = "ResultPanel"
	r.result = data
	## Maraton: suma el nivel (y si era el ultimo, la completa).
	if Marathon.active():
		Marathon.on_win(int(data.get("score", 0)))
		r.result = data.duplicate()
		r.result["marathon"] = true
	## Contrarreloj: guarda el tiempo si es record.
	if TimeAttack.active() and not Marathon.active() and not Kit.is_extra():
		if r.result == data:
			r.result = data.duplicate()
		r.result["time_attack"] = TimeAttack.on_win(Kit.level_index, TimeAttack.game_time(host))
	host.add_child(r)
	return r


func _ready() -> void:
	build_frame(Kit.text("level_complete", "Nivel completado"))
	stars = StarRow.make(3, 0, 104.0)
	stars.name = "Stars"
	body.add_child(stars)
	stars.animate_fill(int(result.get("stars", 1)), 0.45)
	Audio.play_voice("victoria")

	var coins_row: HBoxContainer = HBoxContainer.new()
	coins_row.alignment = BoxContainer.ALIGNMENT_CENTER
	coins_row.add_theme_constant_override("separation", 14)
	body.add_child(coins_row)
	coins_row.add_child(UiIcon.make("coin", Kit.color("coin", UI.colors["acento"]), 48.0))
	var coins: Label = Label.new()
	coins.name = "CoinsValue"
	coins_row.add_child(coins)
	var total: int = int(result.get("coins_total", 0))
	UI.count_up(coins, int(result.get("coins", 0)), "%d/" + str(total), 0.7)

	var score: Label = Label.new()
	score.name = "ScoreValue"
	score.theme_type_variation = "HeaderLabel"
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(score)
	UI.count_up(score, int(result.get("score", 0)), "%d", 1.0)

	## Monedas para la tienda: 10 por estrella y las monedas del nivel (hasta 40).
	var earned: int = Save.with_fortune(int(result.get("stars", 1)) * 10 + mini(int(result.get("coins", 0)), 40))
	## Evento del autor "monedas dobles".
	var event_x: int = Online.coin_multiplier()
	earned *= event_x
	if not bool(result.get("no_reward", false)):
		Save.add_wallet(earned)
	## Modo experto: medalla del nivel y el doble de monedas.
	if Expert.active() and not Marathon.active() and not Kit.is_extra() and not bool(result.get("no_reward", false)):
		var ex: Dictionary = Expert.on_win(Kit.level_index, earned)
		earned += int(ex["extra"])
		var med: Label = Label.new()
		med.name = "ExpertMedal"
		med.text = (Kit.text("ex_medal_new", "\u00a1Medalla de experto!") if bool(ex["first"]) else Kit.text("ex_medal", "Medalla de experto")) \
			+ "  \u00b7  x%d " % Expert.BONUS + Kit.text("ex_coins", "monedas")
		med.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		med.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		med.add_theme_color_override("font_color", Color("#ff9f43"))
		body.add_child(med)
		if bool(ex["first"]):
			UI.pop_in(med, 0.6)
	var reward: Label = Label.new()
	reward.name = "Reward"
	reward.text = "+%d  " % earned + Kit.text("for_shop", "para la tienda") + ("  (x2 " + Kit.text("event", "evento") + ")" if event_x > 1 else "")
	reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward.add_theme_color_override("font_color", UI.colors["acento"])
	body.add_child(reward)
	if bool(result.get("marathon", false)):
		var mar: Label = Label.new()
		mar.name = "Marathon"
		mar.text = (Kit.text("mar_done", "\u00a1Marat\u00f3n completa!") + " " + Marathon.summary()) if Marathon.done() else Marathon.banner_text()
		if Marathon.lap_ready():
			mar.text = Kit.text("mar_lap_done", "\u00a1Vuelta {n} completada! La siguiente lleva giros y +1 vida.").format({"n": Marathon.lap()})
		mar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mar.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		mar.add_theme_color_override("font_color", Color("#ffd166"))
		body.add_child(mar)
	if result.has("time_attack"):
		var info: Dictionary = result["time_attack"]
		var ta: Label = Label.new()
		ta.name = "TimeAttack"
		ta.text = TimeAttack.result_text(info)
		ta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ta.add_theme_color_override("font_color", Color("#ffd166") if bool(info.get("record", false)) else Color("#7ee8fa"))
		body.add_child(ta)
		if bool(info.get("record", false)):
			UI.pop_in(ta, 0.6)

	## Trofeos por las estrellas nuevas y un cofre si hay hueco (se abren en la pantalla principal).
	if not bool(result.get("no_reward", false)):
		var won: Dictionary = Chests.on_level_won(str(Kit.level_index), int(result.get("stars", 1)))
		var parts: Array[String] = []
		if int(won["trophies"]) > 0:
			parts.append("+%d " % int(won["trophies"]) + Kit.text("trophies_word", "trofeos"))
		if str(won["chest"]) != "":
			parts.append(Kit.text("chest_" + str(won["chest"]), ChestPanel.chest_name(str(won["chest"]))))
		elif bool(won["full"]):
			parts.append(Kit.text("chests_full", "Cofres llenos"))
		if not parts.is_empty():
			var loot: Label = Label.new()
			loot.name = "Loot"
			loot.text = ",  ".join(parts)
			loot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			loot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			loot.add_theme_color_override("font_color", UI.colors["exito"])
			body.add_child(loot)
			UI.pop_in(loot, 0.9)

	## Bonificado opcional: el jugador elige ver un anuncio para duplicar el premio.
	if not bool(result.get("no_reward", false)) and earned > 0 and Ads.rewarded_available():
		var double: Button = UI.make_button(Kit.text("double_reward", "x2 viendo un anuncio"), false, "play")
		double.name = "BtnDouble"
		double.pressed.connect(_on_double.bind(double, reward, earned))
		body.add_child(double)

	if bool(result.get("record", false)):
		var rec: Label = Label.new()
		rec.name = "Record"
		rec.text = Kit.text("new_record", "Nuevo record")
		rec.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rec.add_theme_color_override("font_color", UI.colors["exito"])
		body.add_child(rec)
		_record_in.call_deferred(rec)

	## Modo clase: el profesor ve el progreso.
	if Classroom.joined():
		Classroom.sync()
	## Juego regalo: el mensaje secreto aparece al superar el nivel elegido.
	if Gift.reveal_now(Kit.level_index):
		(func() -> void: GiftPanel.open(self, "reveal")).call_deferred()
	## Buen momento para preguntar si le gusta (opinion privada antes que valoracion publica).
	elif not Prize.earned_now(Kit.level_index) and RatePrompt.should_ask(int(result.get("stars", 1))):
		(func() -> void: RatePanel.open(self)).call_deferred()

	## Premio real del autor (juegos para negocios): se gana al superar el nivel N.
	if Prize.earned_now(Kit.level_index):
		var prize: Button = UI.make_button(Kit.text("prize_won", "\u00a1Has ganado un premio!"), true, "trophy")
		prize.name = "BtnPrize"
		prize.pressed.connect(func() -> void:
			PrizePanel.open(self, Kit.level_index)
			prize.queue_free())
		body.add_child(prize)
		UI.pop_in(prize, 0.8)

	_online_section()

	var has_next: bool = Kit.level_index + 1 < Kit.level_count()
	## Maraton sin fin: al acabar la vuelta, la siguiente (en la fila de abajo, en vez de repetir).
	var lap_b: Button = null
	if not has_next and Marathon.active() and Marathon.lap_ready():
		lap_b = UI.make_button(Kit.text("mar_next_lap", "Vuelta {n}").format({"n": Marathon.lap() + 1}), true, "play")
		lap_b.name = "BtnNextLap"
		lap_b.pressed.connect(func() -> void:
			Marathon.next_lap()
			Marathon.prepare(0)
			UI.goto(UI.game_scene()))
	elif has_next:
		var next: Button = UI.make_button(Kit.text("next", "Siguiente"), true, "play")
		next.name = "BtnNext"
		next.pressed.connect(_on_next)
		body.add_child(next)
	var retry: Button = UI.make_button(Kit.text("retry", "Repetir"), not has_next, "retry")
	retry.name = "BtnRetry"
	retry.pressed.connect(func() -> void: UI.goto(UI.game_scene()))
	var levels: Button = UI.make_button(Kit.text("levels", "Niveles"), false, "grid")
	levels.name = "BtnLevels"
	levels.pressed.connect(func() -> void: UI.goto(UI.SCREEN_LEVELS))
	if lap_b != null:
		retry.queue_free()
		button_row([lap_b, levels])
	else:
		button_row([retry, levels])


## Reto de un amigo, clasificacion online y boton para retar (ver kit/online.gd).
func _online_section() -> void:
	## El nivel extra del reto cambia cada dia: sin clasificacion ni retos a amigos.
	if Kit.is_extra():
		return
	var sc: int = int(result.get("score", 0))
	var ch: Dictionary = Online.challenge_for(Kit.level_index)
	if not ch.is_empty():
		var beat: bool = sc > int(ch["score"])
		var cl: Label = Label.new()
		cl.name = "Challenge"
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if beat:
			cl.text = Kit.text("challenge_won", "\u00a1Reto de {who} superado!").format({"who": ch["from"]})
		else:
			cl.text = Kit.text("challenge_left", "Reto de {who}: te faltan {n} puntos").format({"who": ch["from"], "n": int(ch["score"]) - sc + 1})
		cl.add_theme_color_override("font_color", UI.colors["exito"] if beat else UI.colors["acento"])
		body.add_child(cl)
	if sc <= 0:
		return
	var buttons: Array[Button] = []
	var sent: bool = false
	if Online.available():
		if Online.alias() != "":
			Online.submit(Kit.level_index, sc)
			sent = true
			_torneo_line.call_deferred(sc)
		var lb: Button = UI.make_button(Kit.text("leaderboard", "Clasificaci\u00f3n"), false, "trophy")
		lb.name = "BtnLeaderboard"
		## En contrarreloj se abre la clasificacion de tiempos (el record ya se subio al ganar).
		var ta_best: float = float((result.get("time_attack", {}) as Dictionary).get("best", 0.0))
		if ta_best > 0.0:
			lb.pressed.connect(func() -> void: LeaderboardPanel.open(get_parent(), TimeAttack.LB_BASE + Kit.level_index, 0 if sent else TimeAttack.to_score(ta_best)))
		else:
			lb.pressed.connect(func() -> void: LeaderboardPanel.open(get_parent(), Kit.level_index, 0 if sent else sc))
		buttons.append(lb)
	var dare: Button = UI.make_button(Kit.text("challenge", "Retar"), false, "share")
	dare.name = "BtnChallenge"
	dare.pressed.connect(func() -> void:
		var msg: String = Online.share(Online.challenge_text(Kit.level_index, sc))
		UI.float_text(root, dare.get_global_rect().get_center() - Vector2(0.0, 70.0), msg, UI.colors["acento"], 26))
	buttons.append(dare)
	button_row(buttons)


## Torneo semanal: si este es el nivel de la semana, sube la marca y dice tu puesto.
func _torneo_line(sc: int) -> void:
	if Online.torneo.is_empty() or int(Online.torneo.get("nivel", -1)) != Kit.level_index:
		return
	var r: Dictionary = await Online.torneo_submit(Kit.level_index, sc)
	if r.is_empty() or not is_instance_valid(body):
		return
	var l: Label = Label.new()
	l.name = "Torneo"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.text = Kit.text("torneo_rank", "Torneo: puesto {n} \u00b7 tu mejor {s}").format({"n": int(r.get("posicion", 0)), "s": int(r.get("mejor", 0))})
	l.add_theme_color_override("font_color", UI.colors["acento"])
	body.add_child(l)
	body.move_child(l, 1)
	UI.pop_in(l, 0.0)


func _record_in(rec: Label) -> void:
	UI.pop_in(rec, 1.3)


func _on_next() -> void:
	Kit.level_index += 1
	Expert.prepare(Kit.level_index)
	Marathon.prepare(Kit.level_index)
	UI.goto(UI.game_scene())


func _on_double(btn: Button, label: Label, earned: int) -> void:
	btn.disabled = true
	var placement: String = "double_reward"
	var ok: Array[bool] = [false]
	var on_ok: Callable = func(p: String) -> void:
		if p == placement:
			ok[0] = true
	Ads.reward_earned.connect(on_ok)
	await Ads.show_rewarded(placement)
	Ads.reward_earned.disconnect(on_ok)
	if not is_instance_valid(btn):
		return
	if ok[0]:
		Save.add_wallet(earned)
		label.text = "+%d  " % (earned * 2) + Kit.text("for_shop", "para la tienda")
		UI.pop_in(label, 1.2)
		btn.queue_free()
	else:
		btn.disabled = false
