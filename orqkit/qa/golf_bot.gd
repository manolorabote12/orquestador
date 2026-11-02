extends RefCounted
## Bot del minigolf: cuando la bola esta parada, piensa el tiro con la misma fisica del juego
## (golf_map.gd: plan_shot) y tira. Si la mete en par + 4 golpes como mucho, el hoyo es justo.

const MapRules = preload("res://kit/golf/golf_map.gd")


static func run(tree: SceneTree, game: Node, max_frames: int) -> bool:
	game.set("auto_retry", true)
	game.set("fast", true)
	var rows: Array[String] = game.get("rows")
	var hole: Vector2 = game.get("hole")
	var dist: Dictionary = MapRules.distances(rows, hole)
	for f: int in max_frames:
		await tree.physics_frame
		if not is_instance_valid(game):
			return false
		if bool(game.get("finished")):
			return true
		if int(game.get("deaths")) >= 2:
			return false
		if bool(game.call("can_shoot")):
			var v: Vector2 = MapRules.plan_shot(rows, game.get("ball"), hole, dist, game.get("monsters"), game.get("wind"))
			if v == Vector2.ZERO:
				return false
			game.call("shoot", v)
	return false
