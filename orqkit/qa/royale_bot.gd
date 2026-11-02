extends RefCounted
## Bot del battle royale: la misma cabeza que los rivales (royale_map.gd -> think) con mejor
## punteria y prudencia (no busca peleas que no le buscan). Con prisa lo hace el propio juego.

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
