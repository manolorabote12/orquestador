extends RefCounted
## Bot del laberinto: primero la llave (si la hay), despues por el camino mas corto a la moneda
## mas cercana sin pisar pinchos. Con cola (mezcla con la serpiente) sigue el camino sin
## repetir casillas que encuentra el analizador (cola_path). Juega con las reglas reales.

const MapRules = preload("res://kit/maze/maze_map.gd")


static func run(tree: SceneTree, game: Node, max_frames: int) -> bool:
	game.set("auto_retry", true)
	game.set("fast", true)
	for f: int in max_frames:
		await tree.physics_frame
		if not is_instance_valid(game):
			return false
		if bool(game.get("finished")):
			return true
		if int(game.get("deaths")) >= 3:
			return false
		if bool(game.call("can_move")) and bool(game.get("cola")):
			var path: Array[Vector2i] = MapRules.cola_path(game.get("rows")) if _path_for(game).is_empty() else _path_for(game)
			game.set_meta("cola_path", path)
			var i: int = path.find(game.get("cell"))
			if i < 0 or i + 1 >= path.size():
				return false
			game.call("try_move", path[i + 1] - path[i])
		elif bool(game.call("can_move")):
			var rows: Array[String] = game.get("rows")
			var has_key: bool = bool(game.get("has_key"))
			var targets: Dictionary = game.get("coin_cells")
			if not has_key and game.get("key_cell") != Vector2i(-1, -1):
				targets = {game.get("key_cell"): true}
			var step: Vector2i = MapRules.first_step(rows, game.get("cell"), targets, has_key)
			if step != Vector2i.ZERO:
				game.call("try_move", step)
	return false


static func _path_for(game: Node) -> Array[Vector2i]:
	var p: Variant = game.get_meta("cola_path", [])
	var out: Array[Vector2i] = []
	for c: Variant in p:
		out.append(c)
	return out
