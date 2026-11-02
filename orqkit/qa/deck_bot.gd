extends RefCounted
## Bot del mazo: la misma cabeza que el analizador (deck_map.gd -> bot_choice y bot_pick).
## Con prisa juega una carta por fotograma; sin prisa (capturas y clip) una cada 0,6 s.

const MapRules = preload("res://kit/deck/deck_map.gd")


static func run(tree: SceneTree, game: Node, max_frames: int) -> bool:
	game.set("auto_retry", true)
	game.set("fast", true)
	var think: int = 0
	for f: int in max_frames:
		await tree.process_frame
		if not is_instance_valid(game):
			return false
		if bool(game.get("finished")) and not bool(game.get("failed")):
			return true
		if not bool(game.call("can_act")):
			continue
		think += 1
		if not bool(game.get("fast")) and think % 36 != 0:
			continue
		game.call("bot_step")
	return false
