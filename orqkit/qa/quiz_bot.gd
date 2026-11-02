extends RefCounted
## Bot del juego de preguntas: lee como una persona (un momento por pregunta) y contesta bien,
## salvo una de cada cinco, que falla a proposito: asi se prueba tambien el fallo y que con
## algun error se sigue pasando el nivel.


static func run(tree: SceneTree, game: Node, max_frames: int) -> bool:
	game.set("auto_retry", true)
	game.set("fast", true)
	var wait: int = 0
	for f: int in max_frames:
		await tree.physics_frame
		if not is_instance_valid(game):
			return false
		if bool(game.get("finished")):
			return true
		if int(game.get("deaths")) >= 2:
			return false
		if not bool(game.get("answering")):
			wait = 0
			continue
		wait += 1
		if wait < 20:
			continue
		var q: Dictionary = game.call("current")
		var ok: int = int(q.get("ok", 0))
		var i: int = int(game.get("index"))
		game.call("answer", ok if i % 5 != 3 else (ok + 1) % 4)
	return false
