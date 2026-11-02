extends RefCounted
## Bot de la supervivencia: la misma cabeza que el analizador (survival_map.gd -> bot_control):
## bebe y come a tiempo, monta la hoguera junto a la charca antes de la noche, pasa la noche a su
## luz y recoge lo que falta para la meta. Con prisa lo hace el propio juego (4 pasos por fotograma).

static func run(tree: SceneTree, game: Node, max_frames: int) -> bool:
	game.set("auto_retry", true)
	game.set("fast", true)
	for f: int in max_frames:
		await tree.physics_frame
		if not is_instance_valid(game):
			return false
		if bool(game.get("finished")) and not bool(game.get("failed")):
			return true
		if not bool(game.get("fast")) and bool(game.call("can_act")):
			game.call("bot_step")
	return false
