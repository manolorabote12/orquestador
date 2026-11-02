extends Node
## Capturas del combate (nivel 3 con el bot y un golpe recibido). Guarda user://combate_N.png

var shots: int = 0


func _ready() -> void:
	UI.test_mode = true
	Kit.level_index = 2
	var game: Node = (load(UI.game_scene()) as PackedScene).instantiate()
	add_child(game)
	var player: PlayerPlatformer = game.get("player")
	var tile: float = float(Kit.param("tile_size", 64.0))
	var rows: Array[String] = game.get("rows")
	await get_tree().create_timer(0.4).timeout
	Input.action_press("move_right")
	var hold: int = 0
	var last_stomps: int = 0
	var after_stomp: int = -1
	for f: int in 60 * 14:
		await get_tree().physics_frame
		if f == 40:
			await _shot()
		if int(game.get("stomps")) > last_stomps:
			last_stomps = int(game.get("stomps"))
			after_stomp = 7
		if after_stomp > 0:
			after_stomp -= 1
			if after_stomp == 0 and shots < 4:
				await _shot()
		if bool(game.get("finished")):
			break
		if hold > 0:
			hold -= 1
			if hold == 0:
				Input.action_release("jump")
			continue
		if not player.is_on_floor():
			continue
		var feet: Vector2 = player.global_position
		var row: int = int(floor((feet.y - 2.0) / tile))
		var front: int = int(floor((feet.x + 30.0) / tile))
		var under: int = int(floor((feet.x + 22.0) / tile))
		var near_enemy: bool = false
		for v: Variant in game.get("enemies"):
			if is_instance_valid(v) and (v as Enemy).alive:
				var dx: float = (v as Enemy).hitbox().position.x - feet.x
				if dx > -10.0 and dx < tile * 2.3 and (v as Enemy).hitbox().end.y > feet.y - tile * 1.6:
					near_enemy = true
		if LevelAnalyzer.is_solid(rows, front, row) or not LevelAnalyzer.is_solid(rows, under, row + 1) or rows[row][front] == "^" or near_enemy:
			Input.action_press("jump")
			hold = 22
	Input.action_release("move_right")
	Input.action_release("jump")
	game.queue_free()
	await get_tree().process_frame
	## Golpe: el jugador quieto y un enemigo que viene de frente.
	var cfg: Dictionary = Kit.config.duplicate(true)
	cfg["levels"] = [{"name": "Golpe", "map": [
		"............", "............", "............", "............", "............", "............",
		"............", "............", "............", "..P....E...G", "############", "############"]}]
	Kit.set_config(cfg)
	Kit.level_index = 0
	var g2: Node = (load(UI.game_scene()) as PackedScene).instantiate()
	add_child(g2)
	var p2: PlayerPlatformer = g2.get("player")
	for f: int in 60 * 6:
		await get_tree().physics_frame
		if p2.hp < p2.max_hp:
			for k: int in 5:
				await get_tree().physics_frame
			await _shot()
			break
	get_tree().quit()


func _shot() -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://combate_%d.png" % shots)
	shots += 1
