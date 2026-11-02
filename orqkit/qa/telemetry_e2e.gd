extends Node
## Prueba de punta a punta de los datos anonimos: el bot juega el nivel 1, se envia el lote al
## servidor de game.json -> telemetry y se sale con 0 si el servidor lo acepto (lo lanza la fabrica).


func _ready() -> void:
	Save.reset_all()
	Save.set_setting("telemetry", true, false)
	Telemetry.queue.clear()
	Kit.level_index = 0
	var game: Node = (load(UI.game_scene()) as PackedScene).instantiate()
	add_child(game)
	await get_tree().physics_frame
	var done: bool = await QaBot.run(get_tree(), game, 60 * 120)
	QaBot.release_all()
	print("[TELEMETRIA] bot=", done, " cola=", Telemetry.queue.size())
	Telemetry.flush()
	var t: float = 0.0
	while Telemetry.queue.size() > 0 and t < 10.0:
		await get_tree().create_timer(0.2, true, false, true).timeout
		t += 0.2
	print("[TELEMETRIA] enviado=", Telemetry.queue.is_empty())
	get_tree().quit(0 if Telemetry.queue.is_empty() and done else 1)
