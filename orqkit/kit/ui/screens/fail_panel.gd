class_name FailPanel
extends UiModal
## Derrota en los generos por intentos (torres, carreras): titulo, por que, reintentar o niveles.
## Al reintentar emite closed y se cierra; el juego reinicia el nivel.
## Contra la frustracion: tras SKIP_AFTER derrotas en el mismo nivel se puede saltar viendo un
## anuncio con premio (o gratis tras SKIP_FREE derrotas, o si el juego no tiene anuncios).

const SKIP_AFTER: int = 3
const SKIP_FREE: int = 5

var title_text: String = ""
var info_text: String = ""
## Maraton sin vidas: el panel solo ofrece volver (y ensena el resumen).
var marathon_over: bool = false


static func open(host: Node, title: String, info: String) -> FailPanel:
	## Modo clase: el profe ve donde se atasca cada alumno.
	if Classroom.joined():
		Classroom.sync()
	var p: FailPanel = FailPanel.new()
	p.name = "FailPanel"
	p.title_text = title
	p.info_text = info
	if Marathon.active():
		var left: int = Marathon.on_fail()
		if left <= 0:
			p.marathon_over = true
			p.title_text = Kit.text("mar_over", "Fin de la marat\u00f3n")
			p.info_text = Marathon.summary()
		else:
			p.info_text = info + "\n" + Kit.text("mar_lives", "Marat\u00f3n: te quedan {n} vidas").format({"n": left}) + "  " + Marathon.hearts()
			var banner: Node = host.get_node_or_null("MarathonBanner/Text")
			if banner is Label:
				(banner as Label).text = Marathon.banner_text()
	host.add_child(p)
	return p


func _ready() -> void:
	build_frame(title_text)
	Audio.play_voice("derrota")
	var info: Label = Label.new()
	info.name = "Info"
	info.text = info_text
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(info)
	if marathon_over:
		var back: Button = UI.make_button(Kit.text("mar_back", "Volver"), true, "back")
		back.name = "BtnMarathonBack"
		back.pressed.connect(func() -> void:
			Marathon.stop()
			get_tree().paused = false
			UI.goto(UI.SCREEN_TITLE))
		body.add_child(back)
		if Online.available():
			var rank: Button = UI.make_button(Kit.text("leaderboard", "Clasificaci\u00f3n"), false, "trophy")
			rank.name = "BtnMarathonRank"
			rank.pressed.connect(func() -> void: LeaderboardPanel.open(self, Marathon.LB_LEVEL, Marathon.record()))
			body.add_child(rank)
		return
	## Segunda oportunidad: seguir donde ibas viendo un anuncio (una vez por nivel).
	if can_revive():
		var g: Node = get_parent()
		var what: String = str(g.call("revive_text")) if g.has_method("revive_text") else Kit.text("revive", "Continuar")
		var rv: Button = UI.make_button(what + "  (" + Kit.text("ad_short", "anuncio") + ")", true, "play")
		rv.name = "BtnRevive"
		rv.pressed.connect(_on_revive.bind(rv))
		body.add_child(rv)
	var retry: Button = UI.make_button(Kit.text("retry", "Repetir"), not can_revive(), "retry")
	retry.name = "BtnRetry"
	retry.pressed.connect(func() -> void:
		closed.emit()
		queue_free())
	body.add_child(retry)
	if can_skip():
		var skip: Button = UI.make_button(Kit.text("skip_level", "Saltar nivel") + ("" if free_skip() else "  (" + Kit.text("ad_short", "anuncio") + ")"), false, "play")
		skip.name = "BtnSkip"
		skip.pressed.connect(_on_skip.bind(skip))
		body.add_child(skip)
	var levels: Button = UI.make_button(Kit.text("levels", "Niveles"), false, "grid")
	levels.name = "BtnLevels"
	levels.pressed.connect(func() -> void:
		get_tree().paused = false
		UI.goto(UI.SCREEN_LEVELS))
	body.add_child(levels)



## Se puede seguir? El juego sabe revivir (revive()), su perfil lo recomienda, hay anuncio y aun
## no se ha usado en este nivel. En la maraton no (la vida ya se ha contado).
## Los puzles dan "una vida mas" o "+N movimientos" (revive_text() lo dice; anuncio "extra_moves").
func can_revive() -> bool:
	var g: Node = get_parent()
	if g == null or not g.has_method("revive") or Marathon.active() or Kit.is_extra():
		return false
	if int(g.get_meta("revived_level", -1)) == Kit.level_index:
		return false
	return (Monetize.rewarded_on("revive") or Monetize.rewarded_on("extra_moves")) and Ads.rewarded_available()


func _on_revive(btn: Button) -> void:
	btn.disabled = true
	var placement: String = "revive" if Monetize.rewarded_on("revive") else "extra_moves"
	var ok: Array[bool] = [false]
	var on_ok: Callable = func(p: String) -> void:
		if p == placement:
			ok[0] = true
	Ads.reward_earned.connect(on_ok)
	await Ads.show_rewarded(placement)
	Ads.reward_earned.disconnect(on_ok)
	if not ok[0]:
		if is_instance_valid(btn):
			btn.disabled = false
		return
	var g: Node = get_parent()
	g.set_meta("revived_level", Kit.level_index)
	QA.log_event("revive", {"level": Kit.level_index})
	get_tree().paused = false
	queue_free()
	g.call("revive")


func _deaths() -> int:
	var g: Node = get_parent()
	return int(g.get("deaths")) if g != null and g.get("deaths") != null else 0


func can_skip() -> bool:
	if Marathon.active():
		return false
	return _deaths() >= SKIP_AFTER and Kit.level_index + 1 < Kit.level_count()


func free_skip() -> bool:
	return _deaths() >= SKIP_FREE or not Ads.rewarded_available()


func _on_skip(btn: Button) -> void:
	btn.disabled = true
	if not free_skip():
		var placement: String = "skip_level"
		var ok: Array[bool] = [false]
		var on_ok: Callable = func(p: String) -> void:
			if p == placement:
				ok[0] = true
		Ads.reward_earned.connect(on_ok)
		await Ads.show_rewarded(placement)
		Ads.reward_earned.disconnect(on_ok)
		if not ok[0]:
			if is_instance_valid(btn):
				btn.disabled = false
			return
	skip_level()


## Desbloquea el siguiente y lo abre (cuenta como saltado: sin estrellas en este).
func skip_level() -> void:
	QA.log_event("level_skip", {"level": Kit.level_index, "deaths": _deaths()})
	Save.unlock_level(Kit.level_index + 1)
	Kit.level_index += 1
	get_tree().paused = false
	if not UI.test_mode:
		UI.goto(UI.game_scene())
	queue_free()
