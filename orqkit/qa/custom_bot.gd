extends RefCounted
## Bot del genero a_medida (esqueleto de nuevo_genero.py). QaBot.run lo usa porque la escena
## devuelve esta ruta en bot_script(). Si el bot gana con las reglas reales, el nivel es jugable.
## Plantilla: va siempre por el camino mas corto a la moneda mas cercana sin pisar pinchos.

const MapRules = preload("res://kit/custom/custom_map.gd")


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
		if bool(game.call("can_move")):
			var rows: Array[String] = game.get("rows")
			var step: Vector2i = MapRules.first_step(rows, game.get("cell"), game.get("coin_cells"))
			if step != Vector2i.ZERO:
				game.call("try_move", step)
	return false
