extends RefCounted
## Bot de la pesca: con el anzuelo listo, mira que pasaria si lo soltara ahora (las mismas reglas
## del juego, fishing_map.gd) y solo lo suelta si va a coger un pez sin tocar medusas.

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
		if bool(game.call("can_drop")) and str(game.call("preview")) == "pez":
			game.call("drop")
	return false
