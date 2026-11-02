extends RefCounted
## Bot del mundo abierto: la misma cabeza que el analizador (sandbox_map.gd -> bot_control): elige
## lo que falta para la meta, busca camino picando lo que estorba y fabrica. Con prisa lo hace el
## propio juego; sin prisa, el juego lo conduce en cada paso en cuanto lo despierta bot_step.

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
