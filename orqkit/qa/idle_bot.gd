extends RefCounted
## Bot del clicker: toca 4 veces por segundo (como una persona tranquila), coge las monedas de oro
## y cada medio segundo compra lo que mas renta por moneda (ayudante o mejor toque).

const TAP_EVERY: float = 0.25


static func run(tree: SceneTree, game: Node, max_frames: int) -> bool:
	game.set("auto_retry", true)
	var acc: float = 0.0
	var shop_acc: float = 0.0
	for f: int in max_frames:
		await tree.physics_frame
		if not is_instance_valid(game):
			return false
		if bool(game.get("finished")):
			return true
		if int(game.get("deaths")) >= 2:
			return false
		acc += 1.0 / 60.0
		shop_acc += 1.0 / 60.0
		if acc >= TAP_EVERY:
			acc -= TAP_EVERY
			game.call("tap")
		if bool(game.get("gold_up")):
			game.call("grab_gold")
		if shop_acc >= 0.5:
			shop_acc = 0.0
			var helpers: Array = game.get("helpers")
			var bank: float = float(game.get("bank"))
			var best: int = -2
			var best_ratio: float = 0.0
			for i: int in helpers.size():
				var cost: float = float(game.call("helper_cost", i))
				if cost <= bank and float((helpers[i] as Dictionary)["cps"]) / cost > best_ratio:
					best_ratio = float((helpers[i] as Dictionary)["cps"]) / cost
					best = i
			var tc: float = float(game.call("tap_cost"))
			if tc <= bank and float(game.get("tap_value")) * 4.0 / tc > best_ratio:
				game.call("buy_tap")
			elif best >= 0:
				game.call("buy", best)
	return false
