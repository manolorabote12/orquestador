extends RefCounted
## Bot del RPG: piensa como una persona sensata (TurnsLogic.policy) y elige una accion cuando
## le toca, con un segundo para "pensar".

const THINK: float = 0.6


static func run(tree: SceneTree, game: Node, max_frames: int) -> bool:
	game.set("auto_retry", true)
	var acc: float = 0.0
	for f: int in max_frames:
		await tree.physics_frame
		if not is_instance_valid(game):
			return false
		if bool(game.get("finished")):
			return true
		if int(game.get("deaths")) >= 2:
			return false
		## Modo equipo: el bot es el boton AUTO (la misma cabeza que el analizador).
		if bool(game.get("party_mode")):
			if not bool(game.get("auto")):
				game.set("auto", true)
				game.call("_auto_turn")
			continue
		if not bool(game.call("waiting_player")):
			acc = 0.0
			continue
		acc += 1.0 / 60.0
		if acc < THINK:
			continue
		acc = 0.0
		var a: Array = TurnsLogic.policy(game.get("state"))
		game.call("act", str(a[0]), int(a[1]))
	return false
