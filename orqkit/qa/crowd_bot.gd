extends RefCounted
## Bot de la multitud: la misma cabeza que el analizador (crowd_map.gd -> best): en cada puerta la
## que mas deja y nunca por la trampa. Con prisa (validar) lo hace el propio juego.

static func run(tree: SceneTree, game: Node, max_frames: int) -> bool:
	game.set("auto_retry", true)
	game.set("fast", true)
	for f: int in max_frames:
		await tree.physics_frame
		if not is_instance_valid(game):
			return false
		if bool(game.get("finished")):
			return true
		if int(game.get("deaths")) >= 2:
			return false
		if not bool(game.get("fast")):
			game.call("bot_step")
	return false
