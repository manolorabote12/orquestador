class_name RaceBot
extends RefCounted
## Bot de las carreras: elige carril mirando 9 tramos por delante (evita conos y coches lentos,
## prefiere monedas y turbos, no cambia de carril sin motivo) y usa el turbo en cuanto lo tiene
## y el carril esta despejado. El validador exige acabar entre los 3 primeros a la primera o
## a la segunda: asi la velocidad de los rivales es justa.


static func run(tree: SceneTree, game: Node, max_frames: int) -> bool:
	game.set("auto_retry", true)
	game.set("fast", true)
	var frames: int = maxi(max_frames, 60 * 60 * 6)
	for f: int in frames:
		await tree.physics_frame
		if not is_instance_valid(game):
			return false
		if bool(game.get("finished")):
			return true
		if int(game.get("deaths")) >= 3:
			return false
		if f % 4 == 0:
			game.set("bot_lat", game.call("lane_lat", best_lane(game)))
		if float(game.get("nitro")) >= 1.0 and not lane_danger(game, game.call("lane_of", game.get("lat")), 10):
			game.call("use_nitro")
	return false


static func lane_danger(game: Node, l: int, ahead: int) -> bool:
	return bool(game.call("_lane_blocked", l, float(game.get("d")) - 40.0, ahead))


static func best_lane(game: Node) -> int:
	var d: float = game.get("d")
	var row: float = (game.get_script() as Script).get_script_constant_map()["ROW"]
	var cur: int = game.call("lane_of", game.get("lat"))
	var score: Array[float] = [0.0, 0.0, 0.0, 0.0]
	for it: Dictionary in game.get("items"):
		if not bool(it["alive"]):
			continue
		var dd: float = float(it["d"]) - d
		if dd < -30.0 or dd > row * 9.0:
			continue
		var l: int = game.call("lane_of", float(it["lat"]))
		var near: float = 1.0 - dd / (row * 9.0)
		match str(it["kind"]):
			"O", "T":
				score[l] -= 100.0 * (0.5 + near)
			"C":
				score[l] += 6.0 * near
			"N":
				score[l] += 12.0 * near
	var best: int = cur
	var best_v: float = -INF
	for l: int in 4:
		## Cambiar de carril cuesta un poco (y dos carriles de golpe, mas).
		var v: float = score[l] - 2.0 * absf(float(l - cur))
		## Para llegar a un carril lejano hay que pasar por el de en medio.
		if absi(l - cur) == 2 and score[(l + cur) >> 1] < -60.0:
			v -= 80.0
		if v > best_v:
			best_v = v
			best = l
	return best
