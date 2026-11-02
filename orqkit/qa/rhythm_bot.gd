extends RefCounted
## Bot de ritmo: toca como una persona con buen oido. Cada nota la toca con un error de hasta
## 50 ms (a veces antes, a veces despues), sin ver el futuro: solo mira lo que esta en pantalla.

const ERROR: float = 0.05


static func run(tree: SceneTree, game: Node, max_frames: int) -> bool:
	game.set("auto_retry", true)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 77
	## Por nota (indice): cuando la va a tocar este bot.
	var plan: Dictionary = {}
	for f: int in max_frames:
		await tree.physics_frame
		if not is_instance_valid(game):
			return false
		if bool(game.get("finished")):
			return true
		if int(game.get("deaths")) >= 2:
			return false
		var t: float = float(game.call("now"))
		var notes: Array = game.get("notes")
		for i: int in notes.size():
			var n: Dictionary = notes[i]
			if int(n["state"]) != 0:
				continue
			var nt: float = float(n["t"])
			if nt - t > 1.0:
				break
			if not plan.has(i):
				plan[i] = nt + rng.randf_range(-ERROR, ERROR)
			if t >= float(plan[i]):
				game.call("tap", int(n["lane"]))
	return false
