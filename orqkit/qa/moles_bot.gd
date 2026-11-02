extends RefCounted
## Bot de topos: reacciona como una persona (medio segundo tras verlo
## asomar), golpea a los enemigos (dos veces al de pinchos) y nunca toca al heroe.

const REACTION: float = 0.5


static func run(tree: SceneTree, game: Node, max_frames: int) -> bool:
	game.set("auto_retry", true)
	var cooldown: float = 0.0
	for f: int in max_frames:
		await tree.physics_frame
		if not is_instance_valid(game):
			return false
		if bool(game.get("finished")):
			return true
		if int(game.get("deaths")) >= 2:
			return false
		cooldown -= 1.0 / 60.0
		if cooldown > 0.0:
			continue
		var up: Dictionary = game.get("up")
		var best: int = -1
		var best_left: float = 99.0
		for h: Variant in up.keys():
			var e: Dictionary = up[h]
			if str(e["kind"]) == "friend" or float(e["age"]) < REACTION:
				continue
			if float(e["left"]) < best_left:
				best_left = float(e["left"])
				best = int(h)
		if best >= 0:
			game.call("bonk", best)
			cooldown = 0.12
	return false
