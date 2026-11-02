extends RefCounted
## Bot de burbujas: en cada disparo elige el angulo con bubble_map.best_angle (el mismo calculo
## que el analizador) y dispara con las reglas reales. Si gana, el nivel es jugable.

const MapRules = preload("res://kit/bubble/bubble_map.gd")


static func run(tree: SceneTree, game: Node, max_frames: int) -> bool:
	game.set("auto_retry", true)
	for f: int in max_frames:
		await tree.physics_frame
		if not is_instance_valid(game):
			return false
		if bool(game.get("finished")):
			return true
		if int(game.get("deaths")) >= 2:
			return false
		if not bool(game.call("can_shoot")):
			continue
		## Sin prisa (capturas): un disparo cada 0,5 s.
		if not bool(game.get("fast")) and f % 30 != 0:
			continue
		var a: float = MapRules.best_angle(game.get("grid"), int(game.get("lose_row")), str(game.get("current")))
		game.call("shoot", a)
	return false
