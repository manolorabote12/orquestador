extends RefCounted
## Bot del corredor 3D. Cada fotograma:
## 1 - Carril: el mas cercano sin tren en los proximos metros (cambia de uno en uno y solo si
##     el carril de paso tambien esta libre); entre carriles libres, el de las monedas.
## 2 - Valla delante en su carril: salta a tiempo (el centro del salto sobre la valla).
## 3 - Barra alta delante: se agacha a tiempo.
## Si gana con las reglas reales, el nivel es jugable.


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
		if not bool(game.get("started")):
			continue
		step(game)
	return false


static func train_near(game: Node, l: int, ahead: float) -> bool:
	var d: float = game.get("d")
	for it: Dictionary in game.get("items"):
		var dd: float = float(it["d"]) - d
		if dd > ahead:
			break
		if it["kind"] == "W" and int(it["lane"]) == l and dd > -3.4:
			return true
	return false


static func step(game: Node) -> void:
	var d: float = game.get("d")
	var speed: float = maxf(float(game.get("speed")), 6.0)
	var lane: int = game.get("lane")
	var lat: float = game.get("lat")
	var horizon: float = 6.0 + speed * 0.75
	## 1 - Elegir carril.
	var score: Array[float] = [0.0, 0.0, 0.0]
	for l: int in 3:
		if train_near(game, l, horizon):
			score[l] -= 1000.0
		score[l] -= 3.0 * float(absi(l - lane))
	for it: Dictionary in game.get("items"):
		var dd: float = float(it["d"]) - d
		if dd > 30.0:
			break
		if dd > 0.0 and it["kind"] == "C" and bool(it["alive"]):
			score[int(it["lane"])] += 2.0 * (1.0 - dd / 30.0)
	var best: int = lane
	for l: int in 3:
		if score[l] > score[best] + 0.5:
			best = l
	if best != lane and absf(lat - float(game.call("lane_x", lane))) < 0.3:
		var nxt: int = lane + (1 if best > lane else -1)
		if not train_near(game, nxt, 4.0 + speed * 0.25):
			game.call("move_lane", 1 if best > lane else -1)
	## 2 y 3 - Saltar o agacharse ante lo que viene en el carril donde esta.
	var here: int = clampi(int(round(lat / 2.2)) + 1, 0, 2)
	for it: Dictionary in game.get("items"):
		var dd2: float = float(it["d"]) - d
		if dd2 > 14.0:
			break
		if dd2 < 0.0 or int(it["lane"]) != here:
			continue
		if it["kind"] == "B" and dd2 <= speed * 0.33 and float(game.get("jump_t")) <= 0.0:
			game.call("jump")
			break
		if it["kind"] == "H" and dd2 <= speed * 0.2 + 1.0 and float(game.get("slide_t")) <= 0.0:
			game.call("slide")
			break
