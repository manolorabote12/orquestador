extends RefCounted
## Bot de apilar: juega como una persona con buen pulso pero no perfecta. Para cada bloque elige
## donde soltar con un pequeno error (como el dedo de verdad) y suelta cuando el bloque pasa por
## ese punto. Si el nivel es justo, llega arriba.

const ERROR_PX: float = 9.0


static func run(tree: SceneTree, game: Node, max_frames: int) -> bool:
	game.set("auto_retry", true)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 4242 + Kit.level_index
	var aim: float = 0.0
	var aimed_for: int = -1
	for f: int in max_frames:
		await tree.physics_frame
		if not is_instance_valid(game):
			return false
		if bool(game.get("finished")):
			return true
		if int(game.get("deaths")) >= 2:
			return false
		var tower: Array = game.get("tower")
		if tower.size() != aimed_for:
			aimed_for = tower.size()
			aim = clampf(rng.randfn(0.0, ERROR_PX), -ERROR_PX * 2.5, ERROR_PX * 2.5)
		var top: Array = tower[tower.size() - 1]
		var goal: float = float(top[0]) + aim
		var x: float = float(game.get("moving_x"))
		var dir: float = float(game.get("moving_dir"))
		## Suelta en cuanto el bloque llega (o se pasa un poco) del punto elegido, yendo hacia el.
		if (x - goal) * dir >= 0.0 and absf(x - goal) < 40.0:
			game.call("drop")
	return false
