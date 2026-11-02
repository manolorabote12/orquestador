extends RefCounted
## Bot del puzle de tubos: resuelve el nivel con el mismo solucionador que el analizador (minimo
## de movimientos) y lo juega con las reglas reales, un vertido cada vez. Si algo sale distinto,
## vuelve a resolver desde donde esta.

const MapRules = preload("res://kit/sort/sort_map.gd")


static func run(tree: SceneTree, game: Node, max_frames: int) -> bool:
	game.set("auto_retry", true)
	var plan: Array = []
	var i: int = 0
	for f: int in max_frames:
		await tree.physics_frame
		if not is_instance_valid(game):
			return false
		if bool(game.get("finished")):
			return true
		if not bool(game.call("can_move")):
			continue
		## Sin prisa (capturas): un movimiento cada 0,4 s.
		if not bool(game.get("fast")) and f % 24 != 0:
			continue
		if i >= plan.size():
			plan = MapRules.solve(game.get("tubes"), int(game.get("cap")))
			i = 0
			if plan.is_empty():
				return false
		var m: Array = plan[i]
		if bool(game.call("pour", int(m[0]), int(m[1]))):
			i += 1
		else:
			plan = []
	return false
