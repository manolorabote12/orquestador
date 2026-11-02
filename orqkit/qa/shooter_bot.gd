extends RefCounted
## Bot del genero naves. Cada 2 fotogramas prueba 33 posiciones de la nave y elige la mejor:
## 1 - Peligro: simula 0.9 s de cada bala y de cada enemigo cercano contra el camino que haria
##     la nave para llegar a esa posicion (con su velocidad real). Lo que choca puntua muy mal.
## 2 - Ganas: ponerse debajo del enemigo mas bajo (dispara sola) y debajo de monedas y mejoras.
## 3 - Moverse cuesta un poco: no baila sin motivo.
## Juega como una persona que esquiva bien, no como un dios: si gana, el nivel es jugable.

const STEP: float = 0.05
const LOOK: float = 0.9
const SHIP_SPEED: float = 1300.0


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
		if f % 2 == 0:
			game.set("bot_x", best_x(game))
	return false


static func best_x(game: Node) -> float:
	var consts: Dictionary = (game.get_script() as Script).get_script_constant_map()
	var w: float = consts["W"]
	var py: float = consts["PLAYER_Y"]
	var pr: float = consts["PLAYER_R"]
	var px: float = game.get("player_x")
	var speed: float = float(game.call("enemy_speed"))
	var kinds: Dictionary = consts["KINDS"]
	var bullets: Array = game.get("bullets")
	var enemies: Array = game.get("enemies")
	var pickups: Array = game.get("pickups")
	var boss: Dictionary = game.get("boss")
	var best: float = px
	var best_v: float = -INF
	var x: float = 40.0
	while x <= w - 40.0:
		var v: float = 0.0
		## 1 - Peligro a lo largo del camino.
		var t: float = 0.0
		while t <= LOOK:
			var sx: float = move_toward(px, x, SHIP_SPEED * t)
			var ship: Vector2 = Vector2(sx, py)
			var weight: float = 1.0 - t / (LOOK + 0.2)
			for b: Dictionary in bullets:
				var bp: Vector2 = (b["pos"] as Vector2) + (b["vel"] as Vector2) * t
				if bp.distance_to(ship) < pr + 9.0 + 16.0:
					v -= 120.0 * weight
			for e: Dictionary in enemies:
				var ep: Vector2 = e["pos"]
				if ep.y < py - 420.0:
					continue
				var k: Dictionary = kinds[e["kind"]]
				ep.y += speed * float(k["speed"]) * t
				if absf(ep.x - sx) < float(e["r"]) + pr + 18.0 and absf(ep.y - py) < float(e["r"]) + pr + 18.0:
					v -= 200.0 * weight
			if not boss.is_empty():
				var bp2: Vector2 = boss["pos"]
				if absf(bp2.x - sx) < float(boss["r"]) + pr + 20.0 and absf(bp2.y - py) < float(boss["r"]) + pr + 20.0:
					v -= 200.0 * weight
			t += STEP
		## 2 - Ganas: debajo del objetivo mas bajo (rocas al final: aguantan mucho).
		var target_x: float = INF
		var target_y: float = -INF
		for e: Dictionary in enemies:
			var ep2: Vector2 = e["pos"]
			var score_y: float = ep2.y - (300.0 if e["kind"] == "A" else 0.0)
			if ep2.y > 0.0 and ep2.y < py - 120.0 and score_y > target_y:
				target_y = score_y
				target_x = ep2.x
		if target_x == INF and not boss.is_empty():
			target_x = (boss["pos"] as Vector2).x
		if target_x != INF:
			v += 25.0 * maxf(0.0, 1.0 - absf(x - target_x) / 160.0)
		for it: Dictionary in pickups:
			var ip: Vector2 = it["pos"]
			if ip.y > py - 600.0 and ip.y < py + 20.0:
				v += (30.0 if it["kind"] == "W" else 12.0) * maxf(0.0, 1.0 - absf(x - ip.x) / 90.0)
		## 3 - Moverse cuesta un poco; el centro es mas seguro que los bordes.
		v -= 0.015 * absf(x - px) + 0.004 * absf(x - w * 0.5)
		if v > best_v:
			best_v = v
			best = x
		x += 20.0
	return best
