extends RefCounted
## Bot del solitario: piensa la partida al empezar (el mismo buscador que el analizador) y la
## juega a ritmo de persona: una jugada cada 0,4 s.

const EVERY: float = 0.4


static func run(tree: SceneTree, game: Node, max_frames: int) -> bool:
	game.set("auto_retry", true)
	var plan: Array = []
	var planned_for: int = -1
	var acc: float = 0.0
	for f: int in max_frames:
		await tree.physics_frame
		if not is_instance_valid(game):
			return false
		if bool(game.get("finished")):
			return true
		if int(game.get("deaths")) >= 2:
			return false
		## Al empezar (o tras perder) se busca la solucion desde el reparto.
		if planned_for != int(game.get("deaths")):
			planned_for = int(game.get("deaths"))
			var deal: Dictionary = CardsLogic.parse(game.get("rows"))
			plan = CardsLogic.solve(deal["cols"], deal["stock"], 200000)
			if plan.is_empty():
				return false
		acc += 1.0 / 60.0
		if acc < EVERY or plan.is_empty():
			continue
		acc = 0.0
		var mv: int = int(plan.pop_front())
		if mv < 0:
			game.call("draw_stock")
		else:
			game.call("play", mv)
	return false
