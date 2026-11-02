extends RefCounted
## Bot de estrategia: la misma IA que el analizador (tactics_map.gd -> ai_plan con BOT_SMART), una
## unidad cada 0,6 s de juego. Con prisa lo hace el propio juego.

static func run(tree: SceneTree, game: Node, max_frames: int) -> bool:
	game.set("auto_retry", true)
	game.set("fast", true)
	var think: int = 0
	for f: int in max_frames:
		await tree.physics_frame
		if not is_instance_valid(game):
			return false
		if bool(game.get("finished")) and not bool(game.get("failed")):
			return true
		if int(game.get("deaths")) >= 2:
			return false
		if bool(game.get("fast")) or not bool(game.call("can_act")):
			continue
		think += 1
		if think % 36 == 0:
			game.call("bot_step")
	return false
