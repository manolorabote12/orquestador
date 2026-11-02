extends RefCounted
## Bot de la artilleria: calcula el mejor disparo con el viento (artillery_map.gd -> best_shot).
## Con prisa (validar) y sin prisa (capturas) lo mueve el propio juego, tick a tick.

static func run(tree: SceneTree, game: Node, max_frames: int) -> bool:
	game.set("auto_retry", true)
	game.set("fast", true)
	var wait: int = 0
	for f: int in max_frames:
		await tree.physics_frame
		if not is_instance_valid(game):
			return false
		if bool(game.get("finished")):
			return true
		if int(game.get("deaths")) >= 2:
			return false
		wait += 1
	return false
