extends RefCounted
## Bot de la granja: el mismo turno que el analizador (farm_map.gd -> bot_turn) cada 2 s de juego.

const MapRules = preload("res://kit/farm/farm_map.gd")


static func run(tree: SceneTree, game: Node, max_frames: int) -> bool:
	game.set("auto_retry", true)
	game.set("fast", true)
	var think: int = 0
	for f: int in max_frames:
		await tree.physics_frame
		if not is_instance_valid(game):
			return false
		if bool(game.get("finished")):
			return not bool(game.get("failed"))
		if not bool(game.call("can_act")):
			continue
		think += 1
		if not bool(game.get("fast")) and think % 20 != 0:
			continue
		game.call("bot_step")
	return false
