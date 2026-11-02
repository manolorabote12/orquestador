extends RefCounted
## Bot del hexa sort: la misma cabeza que el analizador (hexa_map.gd -> bot_move): prueba cada
## pila en cada hueco y se queda con la que mas limpia y mas ordena; martillo si se llena.
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
