class_name Match3Bot
extends RefCounted
## Bot del puzle: en cada turno prueba todas las jugadas en una copia del tablero y elige la que
## mas puntos da (el hielo y las especiales cuentan extra). Juega como una persona atenta, sin
## ver el futuro de las piezas que caen. Si pasa el nivel, el objetivo es razonable.


static func run(tree: SceneTree, game: Node, max_frames: int) -> bool:
	game.set("auto_retry", true)
	for f: int in max_frames:
		await tree.physics_frame
		if not is_instance_valid(game):
			return false
		if bool(game.get("finished")):
			return true
		if bool(game.get("busy")) or tree.paused:
			continue
		var m: Array = best_move(game.get("logic"))
		if m.is_empty():
			continue
		await game.call("try_swap", m[0], m[1])
	return false


static func best_move(logic: Match3Logic) -> Array:
	var best: Array = []
	var best_v: float = -1.0
	for m: Array in logic.all_moves():
		var sim: Match3Logic = logic.clone()
		var before: int = sim.score
		var ice0: int = sim.ice_left
		var made0: int = sim.specials_made
		sim.apply_swap(m[0], m[1])
		var v: float = float(sim.score - before) + float(ice0 - sim.ice_left) * 150.0 + float(sim.specials_made - made0) * 100.0
		## Mas abajo, mas cascadas: pequena preferencia por jugar abajo.
		v += float((m[0] as Vector2i).y) * 2.0
		if v > best_v:
			best_v = v
			best = m
	return best
