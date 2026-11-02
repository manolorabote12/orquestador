extends RefCounted
## Bot del puzle de cajas: resuelve el nivel (minimo de empujes, como el analizador) y lo juega
## con las reglas reales: camina hasta detras de cada caja y la empuja. Si algo sale distinto de
## lo previsto, reinicia y vuelve a resolver.

const MapRules = preload("res://kit/sokoban/sokoban_map.gd")


static func run(tree: SceneTree, game: Node, max_frames: int) -> bool:
	game.set("auto_retry", true)
	game.set("fast", true)
	var rows: Array[String] = game.get("rows")
	var ice: bool = bool(game.get("ice"))
	var plan: Array = MapRules.solve(rows, ice)
	var steps: Array[Vector2i] = []
	var walls: Dictionary = game.get("walls")
	## Pasos a pie + empuje para cada [caja, direccion] del plan, simulando las cajas.
	var sim: Dictionary = (game.get("boxes") as Dictionary).duplicate()
	var me: Vector2i = game.get("cell")
	for push: Array in plan:
		var b: Vector2i = push[0]
		var d: Vector2i = push[1]
		var path: Array[Vector2i] = MapRules.walk(walls, sim, me, b - d)
		if path.is_empty() and me != b - d:
			return false
		steps.append_array(path)
		steps.append(d)
		sim.erase(b)
		sim[MapRules.slide_end(walls, sim, b, d, ice)] = true
		me = b
	var i: int = 0
	for f: int in max_frames:
		await tree.physics_frame
		if not is_instance_valid(game):
			return false
		if bool(game.get("finished")):
			return true
		if i < steps.size() and bool(game.call("can_move")):
			if bool(game.call("try_move", steps[i])):
				i += 1
			else:
				return false
	return false
