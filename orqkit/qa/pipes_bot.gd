extends RefCounted
## Bot de las tuberias: gira cada pieza hasta la solucion (pipes_map.gd -> bot_move);
## el minimo de giros.
## Con prisa (validar) lo hace el propio juego; sin prisa (capturas), una cada 0,6 s.

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
		if bool(game.get("fast")):
			continue
		wait += 1
		if wait % 36 == 0:
			game.call("bot_step")
	return false
