extends RefCounted
## Bot del bus jam: la misma cabeza que el analizador (bus_map.gd -> bot_move): llena autobuses,
## abre caminos, mira una jugada por delante y usa el VIP si se queda sin jugada.
## Con prisa lo hace el propio juego (una jugada por fotograma).

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
