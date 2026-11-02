extends Node
## Capturas de la interfaz en un perfil:
##   godot --path orqkit res://qa/ui_shots.tscn -- --profile=cartoon
## Guarda user://ui_<perfil>_<pantalla>.png

var profile: String = "pixel"


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--profile="):
			profile = a.get_slice("=", 1)
	UI.test_mode = true
	UI.rebuild(profile)
	Save.reset_all()
	Save.unlock_level(1)
	Save.unlock_level(2)
	Save.submit_stars("0", 3)
	Save.submit_stars("1", 2)
	## Cofres en la pantalla principal: uno abriendose y otro listo.
	Chests.on_level_won("0", 3)
	Chests.on_level_won("1", 2)
	Chests.start(0)
	var title: Node = _add(UI.SCREEN_TITLE)
	await _shot("1_titulo", 1.6)
	title.queue_free()
	var levels: Node = _add(UI.SCREEN_LEVELS)
	await _shot("2_niveles", 1.2)
	levels.queue_free()
	var game: Node = _add(UI.game_scene())
	await get_tree().create_timer(0.8).timeout
	game.call("open_pause")
	await _shot("3_pausa", 0.8)
	(game.get_node("PauseMenu") as PauseMenu).resume_game()
	SettingsPanel.open(game)
	await _shot("4_ajustes", 0.8)
	(game.get_node("SettingsPanel") as SettingsPanel).close()
	ResultPanel.open(game, {"stars": 2, "coins": 4, "coins_total": 5, "score": 2870, "record": true})
	await _shot("5_resultado", 2.6)
	get_tree().quit()


func _add(path: String) -> Node:
	var n: Node = (load(path) as PackedScene).instantiate()
	add_child(n)
	return n


func _shot(shot_name: String, wait: float) -> void:
	await get_tree().create_timer(wait, true, false, true).timeout
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("user://ui_%s_%s.png" % [profile, shot_name])
