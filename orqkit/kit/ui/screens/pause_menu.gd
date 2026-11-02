class_name PauseMenu
extends UiModal
## Menu de pausa: congela el juego y ofrece seguir, reiniciar, ajustes o volver a niveles.

signal resumed


static func open(host: Node) -> PauseMenu:
	var m: PauseMenu = PauseMenu.new()
	m.name = "PauseMenu"
	host.get_tree().paused = true
	host.add_child(m)
	return m


func _ready() -> void:
	Audio.muffle(true)
	build_frame(Kit.text("paused", "Pausa"), 520.0)
	var resume: Button = UI.make_button(Kit.text("resume", "Continuar"), true, "play")
	resume.name = "BtnResume"
	resume.pressed.connect(resume_game)
	body.add_child(resume)
	var restart: Button = UI.make_button(Kit.text("restart", "Reiniciar"), false, "retry")
	restart.name = "BtnRestart"
	restart.pressed.connect(_on_restart)
	body.add_child(restart)
	if HowTo.has(Genres.current()):
		var how: Button = UI.make_button(Kit.text("howto_title", "C\u00f3mo se juega"), false, "star")
		how.name = "BtnHowTo"
		how.pressed.connect(func() -> void: HowToPanel.open(self))
		body.add_child(how)
	var settings: Button = UI.make_button(Kit.text("settings", "Ajustes"), false, "gear")
	settings.name = "BtnSettings"
	settings.pressed.connect(func() -> void: SettingsPanel.open(self))
	body.add_child(settings)
	var levels: Button = UI.make_button(Kit.text("levels", "Niveles"), false, "grid")
	levels.name = "BtnLevels"
	levels.pressed.connect(func() -> void: UI.goto(UI.SCREEN_LEVELS))
	body.add_child(levels)
	_add_chat.call_deferred()


## Charla en directo con los personajes: solo si el autor la ha activado (se pregunta al servidor).
func _add_chat() -> void:
	if not await Online.chat_active() or not is_instance_valid(body):
		return
	var first: Dictionary = ChatPanel.characters()
	var name_txt: String = str(first[first.keys()[0]]["name"])
	var talk: Button = UI.make_button(Kit.text("chat_with", "Hablar con {name}").format({"name": name_txt}), false, "share")
	talk.name = "BtnChat"
	talk.pressed.connect(func() -> void: ChatPanel.open(self))
	body.add_child(talk)
	body.move_child(talk, 1)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		if get_node_or_null("SettingsPanel") == null and get_node_or_null("ChatPanel") == null and get_node_or_null("HowToPanel") == null:
			get_viewport().set_input_as_handled()
			resume_game()


func _exit_tree() -> void:
	Audio.muffle(false)


## 1 - Al seguir se quita la pausa y se cierra la ventana.
func resume_game() -> void:
	get_tree().paused = false
	resumed.emit()
	close()


func _on_restart() -> void:
	get_tree().paused = false
	UI.goto(UI.game_scene())
