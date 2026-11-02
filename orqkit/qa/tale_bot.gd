extends RefCounted
## Bot de la aventura: busca el camino al final bueno (tale_map.gd -> path_to) y lo sigue.
## Con prisa elige una decision por fotograma; sin prisa (capturas y clip) una cada 2 s.

static func run(tree: SceneTree, game: Node, max_frames: int) -> bool:
	game.set("auto_retry", true)
	game.set("fast", true)
	var think: int = 0
	for f: int in max_frames:
		await tree.process_frame
		if not is_instance_valid(game):
			return false
		if bool(game.get("finished")):
			return str(game.get("ending")) == "bueno"
		if not bool(game.call("can_act")):
			continue
		think += 1
		if not bool(game.get("fast")) and think % 120 != 0:
			continue
		game.call("bot_step")
	return false
