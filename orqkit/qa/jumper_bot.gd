extends RefCounted
## Bot de saltos: como una persona que mira hacia arriba.
## 1 - Al rebotar elige la plataforma mas alta a la que llega con ese salto (sin enemigo encima).
## 2 - Al caer, si no va a llegar a su destino, busca la plataforma mas alta debajo a la que
##     todavia le da tiempo a llegar de lado, y se pone encima.
## 3 - Se aparta de los enemigos que tiene encima mientras sube.

const REACH_ROWS: float = 3.1
const SPRING_ROWS: float = 8.3
const MOVE: float = 520.0
const GRAV: float = 1500.0


static func run(tree: SceneTree, game: Node, max_frames: int) -> bool:
	game.set("auto_retry", true)
	var row_h: float = float(game.get("ROW_H"))
	var w: float = float(game.call("width"))
	var target: Dictionary = {}
	var last_vy: float = 0.0
	for f: int in max_frames:
		await tree.physics_frame
		if not is_instance_valid(game):
			return false
		if bool(game.get("finished")):
			return true
		if int(game.get("deaths")) >= 3:
			return false
		var pos: Vector2 = game.get("pos")
		var vel: Vector2 = game.get("vel")
		var plats: Array = game.get("platforms")
		if vel.y < 0.0 and last_vy >= 0.0:
			var reach: float = (SPRING_ROWS if vel.y < -1300.0 else REACH_ROWS) * row_h
			target = _pick_up(plats, pos, reach, w, row_h, _danger(game, w, row_h))
			if target.is_empty():
				target = _closest_up(plats, pos, reach, w, row_h)
		if vel.y > 0.0 and not target.is_empty():
			var tp: Vector2 = target["pos"]
			if not bool(target["alive"]) or tp.y < pos.y - 4.0 and not _can_land(pos, vel, tp, w):
				target = _pick_down(plats, pos, vel, w, _danger(game, w, row_h))
			elif tp.y >= pos.y - 4.0:
				## Ya esta por debajo del destino (lo ha pasado): el mas alto de abajo al que llega.
				target = _pick_down(plats, pos, vel, w, _danger(game, w, row_h))
		elif vel.y > 0.0 and target.is_empty():
			target = _pick_down(plats, pos, vel, w, _danger(game, w, row_h))
		last_vy = vel.y
		var steer: float = 0.0
		if not target.is_empty() and target["kind"] != "G":
			var t2: Vector2 = target["pos"]
			var d: float = fposmod(t2.x - pos.x + w * 0.5, w) - w * 0.5
			if absf(d) > 12.0:
				steer = signf(d)
		## Subiendo con un enemigo encima en su columna: se aparta.
		if vel.y < 0.0:
			for e: Dictionary in game.get("enemies"):
				if not bool(e["alive"]):
					continue
				var en: Vector2 = (e["node"] as Node2D).position
				var dx: float = fposmod(en.x - pos.x + w * 0.5, w) - w * 0.5
				if en.y < pos.y and pos.y - en.y < row_h * 3.5 and absf(dx) < 90.0:
					steer = -signf(dx) if dx != 0.0 else 1.0
		game.set("steer", steer)
	return false


static func _dx(a: float, b: float, w: float) -> float:
	return absf(fposmod(b - a + w * 0.5, w) - w * 0.5)


## Plataformas con un enemigo justo encima (el siguiente rebote se lo comeria): mejor no.
static func _danger(game: Node, w: float, row_h: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for e: Dictionary in game.get("enemies"):
		if bool(e["alive"]):
			out.append((e["node"] as Node2D).position)
	return out


static func _risky(p: Vector2, danger: Array[Vector2], w: float) -> bool:
	for en: Vector2 in danger:
		if en.y < p.y and p.y - en.y < 380.0 and _dx(p.x, en.x, w) < 110.0:
			return true
	return false


static func _pick_up(plats: Array, pos: Vector2, reach: float, w: float, row_h: float, danger: Array[Vector2]) -> Dictionary:
	var best: Dictionary = {}
	for pl: Dictionary in plats:
		if not bool(pl["alive"]) or bool(pl.get("enemy", false)) or _risky(pl["pos"], danger, w):
			continue
		var p: Vector2 = pl["pos"]
		var up: float = pos.y - p.y
		if up < row_h * 0.4 or up > reach:
			continue
		if pl["kind"] == "G":
			return pl
		## Tiempo de subida hasta esa altura y bajada un poco: lo que da de si a los lados.
		var room: float = MOVE * 0.75 * (sqrt(2.0 * maxf(reach - up, 1.0) / GRAV) + sqrt(2.0 * up / GRAV) * 0.9)
		if _dx(pos.x, p.x, w) > room and pl["kind"] != "~":
			continue
		if best.is_empty() or p.y < (best["pos"] as Vector2).y:
			best = pl
	return best


static func _can_land(pos: Vector2, vel: Vector2, tp: Vector2, w: float) -> bool:
	var dy: float = tp.y - pos.y
	if dy < 0.0:
		return false
	var t: float = (-vel.y + sqrt(vel.y * vel.y + 2.0 * GRAV * dy)) / GRAV
	return _dx(pos.x, tp.x, w) <= MOVE * t * 0.85 + 50.0


static func _pick_down(plats: Array, pos: Vector2, vel: Vector2, w: float, danger: Array[Vector2]) -> Dictionary:
	var best: Dictionary = {}
	var risky: Dictionary = {}
	for pl: Dictionary in plats:
		if not bool(pl["alive"]):
			continue
		if _risky(pl["pos"], danger, w):
			if risky.is_empty() and _can_land(pos, vel, pl["pos"], w) and (pl["pos"] as Vector2).y >= pos.y + 4.0:
				risky = pl
			continue
		var p: Vector2 = pl["pos"]
		if p.y < pos.y + 4.0:
			continue
		if not _can_land(pos, vel, p, w):
			continue
		if best.is_empty() or p.y < (best["pos"] as Vector2).y:
			best = pl
	return best if not best.is_empty() else risky


## Sin destino comodo: la plataforma de arriba mas cercana de lado (aunque haya que estirarse).
static func _closest_up(plats: Array, pos: Vector2, reach: float, w: float, row_h: float) -> Dictionary:
	var best: Dictionary = {}
	var best_dx: float = INF
	for pl: Dictionary in plats:
		if not bool(pl["alive"]) or bool(pl.get("enemy", false)):
			continue
		var p: Vector2 = pl["pos"]
		var up: float = pos.y - p.y
		if up < row_h * 0.4 or up > reach:
			continue
		var dx: float = _dx(pos.x, p.x, w)
		if dx < best_dx:
			best_dx = dx
			best = pl
	return best
