class_name TowerBot
extends RefCounted
## Bot del tower defense: juega como una persona sensata, sin trucos.
## 1 - Cada vez que puede, construye siguiendo un orden (rayo, rayo, hielo, canon, ...) en la
##     casilla libre que mas tramo de camino cubre con el alcance de esa torre.
## 2 - Si ya no quedan buenas casillas, mejora la torre que mas camino cubre.
## 3 - Lanza la siguiente oleada en cuanto termina la anterior (sin esperar la cuenta atras).
## Si pierde, reintenta; el validador exige ganar a la primera o a la segunda.

const ORDER: Array[String] = ["rayo", "rayo", "hielo", "canon", "rayo", "canon", "rayo", "hielo", "canon", "canon"]


static func run(tree: SceneTree, game: Node, max_frames: int) -> bool:
	game.set("auto_retry", true)
	game.set("fast", true)
	var frames: int = maxi(max_frames, 60 * 60 * 15)
	for f: int in frames:
		await tree.physics_frame
		if not is_instance_valid(game):
			return false
		if bool(game.get("finished")):
			return true
		if int(game.get("deaths")) >= 3:
			return false
		if f % 10 == 0:
			spend(game)
		if not bool(game.get("in_wave")):
			game.call("start_wave")
	return false


static func coverage(game: Node, c: Vector2i, r: float) -> int:
	var n: int = 0
	var from: Vector2 = game.call("cell_pos", c)
	for p: Vector2 in game.get("path_px"):
		if p.distance_to(from) <= r:
			n += 1
	return n


static func spend(game: Node) -> void:
	var towers: Dictionary = game.get("towers")
	var kind: String = ORDER[towers.size() % ORDER.size()] if towers.size() < 14 else "canon"
	var spec: Dictionary = (game.get_script() as Script).get_script_constant_map()["TOWERS"][kind]
	var cell: float = game.get("cell")
	var rows: Array = game.get("rows")
	if int(game.get("gold")) >= int(spec["cost"]):
		var best: Vector2i = Vector2i(-1, -1)
		var best_n: int = 1
		for y: int in rows.size():
			for x: int in str(rows[0]).length():
				var c: Vector2i = Vector2i(x, y)
				if not bool(game.call("buildable", c)):
					continue
				var n: int = coverage(game, c, float(spec["range"]) * cell)
				if n > best_n:
					best_n = n
					best = c
		if best.x >= 0 and best_n >= 3:
			game.call("build", best, kind)
			return
	## 2 - Mejorar la torre que mas cubre (si hay oro).
	var best_t: Vector2i = Vector2i(-1, -1)
	var best_cov: int = -1
	for c: Variant in towers.keys():
		var cost: int = game.call("upgrade_cost", c)
		if cost <= 0 or cost > int(game.get("gold")):
			continue
		var n2: int = coverage(game, c, float(game.call("tower_range", c)))
		if n2 > best_cov:
			best_cov = n2
			best_t = c
	if best_t.x >= 0 and towers.size() >= 4:
		game.call("upgrade", best_t)
