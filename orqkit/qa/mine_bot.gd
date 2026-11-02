extends RefCounted
## Bot de las minas: toca lo que no tiene gerente y compra con la misma cabeza que el analizador
## (mine_map.gd -> best_action: lo que mas sube el ingreso por moneda, gerentes cuando salen baratos).

const MapRules = preload("res://kit/mine/mine_map.gd")


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
		## Sin prisa (capturas) se piensa cada 0,25 s; con prisa, cada fotograma.
		if not bool(game.get("fast")) and think % 15 != 0:
			continue
		game.call("bot_step")
	return false
