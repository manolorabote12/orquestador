extends RefCounted
## Bot de fusion con pedidos: la misma cabeza que el analizador (mergeboard_map.gd -> bot_act):
## entrega, fusiona lo que sirve o toca el generador al que mas le falta. Con prisa (validar) lo
## hace el propio juego con el tiempo mucho mas rapido; sin prisa (capturas), este bucle.

static func run(tree: SceneTree, game: Node, max_frames: int) -> bool:
	game.set("auto_retry", true)
	game.set("fast", true)
	var next: float = 0.0
	for f: int in max_frames:
		await tree.physics_frame
		if not is_instance_valid(game):
			return false
		if bool(game.get("finished")) and not bool(game.get("failed")):
			return true
		if bool(game.get("fast")) or not bool(game.call("can_act")):
			continue
		if float(game.get("time_in_level")) >= next:
			next = float(game.get("time_in_level")) + 0.7
			game.call("bot_step")
	return false
