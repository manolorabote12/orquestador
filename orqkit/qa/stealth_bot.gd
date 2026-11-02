extends RefCounted
## Bot del sigilo: resuelve el tablero (con el maletin) y lo juega paso a paso (stealth_map.gd -> solve).
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
