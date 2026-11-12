extends Node
## Capturas de un juego fabricado (galeria de la app y revision visual por IA):
##   godot --path <proyecto> --resolution 720x1280 res://qa/capturas.tscn -- --out=/ruta/carpeta
## Guarda 1_titulo, 2_niveles, 3_juego, 4_juego, 5_resultado (.png).

var out_dir: String = "user://capturas"


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(out_dir)
	UI.test_mode = true
	Ads.enabled = false
	Save.reset_all()
	Save.unlock_level(1)
	Save.submit_stars("0", 3)
	var title: Node = _add(UI.SCREEN_TITLE)
	await _shot("1_titulo", 1.6)
	title.queue_free()
	var levels: Node = _add(UI.SCREEN_LEVELS)
	await _shot("2_niveles", 1.0)
	levels.queue_free()
	Kit.level_index = mini(1, Kit.level_count() - 1)
	var game: Node = _add(UI.game_scene())
	await get_tree().physics_frame
	## 3 - Puzle: el bot resuelve al instante; la foto es del tablero y de un par de jugadas.
	if game.has_method("match3_bot_step"):
		await _shot("3_juego", 1.0)
		for k: int in 2:
			var m: Array = Match3Bot.best_move(game.get("logic"))
			if not m.is_empty():
				await game.call("try_swap", m[0], m[1])
		await _shot("4_juego", 0.5)
		ResultPanel.open(game, {"stars": 3, "coins": 8, "coins_total": 8, "score": 9450, "record": true})
		await _shot("5_resultado", 2.4)
		get_tree().quit()
		return
	## 1b - Auditoria de la interfaz del juego (antes de que juegue el bot: con sus botones).
	await get_tree().physics_frame
	await get_tree().physics_frame
	_audit(game)
	QaBot.run(get_tree(), game, 60 * 60)
	## 2 - Hordas: fotos con la horda ya crecida y la eleccion de mejora.
	var horde: bool = game.has_method("horde_bot_step")
	## 4 - Torres y carreras: con efectos (el bot los quita para ir rapido) y ya en plena partida.
	var custom: bool = game.has_method("bot_script")
	var slow: bool = game.has_method("tower_bot_step") or game.has_method("race_bot_step") or custom
	if slow:
		await get_tree().physics_frame
		game.set("fast", false)
	var first: float = 14.0 if horde else (26.0 if game.has_method("tower_bot_step") else (1.2 if custom else (8.0 if slow else 2.2)))
	var second: float = 1.4 if custom else (6.0 if horde or slow else 2.6)
	## 5 - Un genero puede pedir cuando hacer las fotos (p. ej. naves: con la oleada en pantalla).
	if game.has_method("capture_delays"):
		var dl: Vector2 = game.call("capture_delays")
		first = dl.x
		second = dl.y
	await _shot_playing(game, "3_juego", first)
	await _shot_playing(game, "4_juego", second)
	if horde:
		game.set("auto_pick", false)
		game.call("_gain_xp", 60)
		await _shot("6_mejoras", 0.9)
		game.set("auto_pick", true)
		var panel: Node = game.get_node_or_null("LevelUpPanel")
		if panel != null:
			panel.call("_pick", 0)
		get_tree().paused = false
	QaBot.release_all()
	ResultPanel.open(game, {"stars": 3, "coins": 5, "coins_total": 5, "score": 3480, "record": true})
	await _shot("5_resultado", 2.4)
	game.queue_free()
	await _boss_shot()
	get_tree().quit()


## 1 - Si el ultimo nivel tiene jefe, foto del combate (el bot juega hasta llegar a el).
func _boss_shot() -> void:
	await get_tree().physics_frame
	Kit.level_index = Kit.level_count() - 1
	var game: Node = _add(UI.game_scene())
	await get_tree().physics_frame
	var b: Variant = game.get("boss")
	if b == null or not (b is Node):
		game.queue_free()
		return
	QaBot.run(get_tree(), game, 60 * 60)
	var tile: float = float(Kit.param("tile_size", 64.0))
	var player: Node2D = game.get("player")
	for i: int in 240:
		await get_tree().create_timer(0.25, true, false, true).timeout
		if not is_instance_valid(b) or not (b as Enemy).alive:
			break
		if absf((b as Node2D).global_position.x - player.global_position.x) < tile * 5.0:
			await _shot("6_jefe", 0.5)
			break
	QaBot.release_all()
	game.queue_free()


func _audit(game: Node) -> void:
	var probs: Array[String] = UI.audit(game)
	probs.append_array(UI.legibility(game))
	var f: FileAccess = FileAccess.open(out_dir.path_join("auditoria.json"), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"genre": str(Kit.param("genre", "")), "problemas": probs}))
		f.close()


func _add(path: String) -> Node:
	var n: Node = (load(path) as PackedScene).instantiate()
	add_child(n)
	return n


## Foto de la partida en juego: si el bot ya ha terminado el nivel (puzles rapidos, 13 nov: los
## tornillos salian con «Nivel completado» en las dos fotos), se reintenta y se fotografia el
## principio del nivel.
func _shot_playing(game: Node, shot_name: String, wait: float) -> void:
	await get_tree().create_timer(wait, true, false, true).timeout
	if is_instance_valid(game) and bool(game.get("finished")) and game.has_method("retry"):
		get_tree().paused = false
		game.call("retry")
		## El panel de «Nivel completado» no siempre se cierra con retry(): fuera.
		for n: Node in get_tree().root.find_children("*", "ResultPanel", true, false):
			n.queue_free()
		await _shot(shot_name, 0.12)
		return
	await _shot(shot_name, 0.0)


func _shot(shot_name: String, wait: float) -> void:
	await get_tree().create_timer(wait, true, false, true).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(shot_name + ".png"))
