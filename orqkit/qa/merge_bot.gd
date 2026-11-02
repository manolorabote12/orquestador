extends RefCounted
## Bot de la fusion: elige la columna mirando la pieza actual y la siguiente (merge_map.gd,
## best_column: lo mismo que usa el analizador) y la suelta.

const MapRules = preload("res://kit/merge/merge_map.gd")


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
		if bool(game.call("can_drop")):
			var c: int = MapRules.best_column(game.get("cells"), int(game.get("w")), int(game.get("h")),
				int(game.call("current_piece")), int(game.call("next_piece")))
			if c < 0:
				return false
			game.call("drop_in", c)
	return false
