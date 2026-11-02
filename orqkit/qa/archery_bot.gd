extends RefCounted
## Bot del tiro con arco: la misma punteria que el analizador (archery_map.gd -> bot_aim: busca el
## mejor angulo y fuerza contando viento y dianas que se mueven) con un poco de pulso humano.

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
