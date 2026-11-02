extends RefCounted
## Bot de la aldea: ataca como una persona normal.
## 1 - Elige un frente: la casilla de despliegue mas cerca del centro de la base.
## 2 - Primero los gigantes (se comen las defensas); 2 s despues, guerreros y arqueras detras.
## 3 - Guarda un tercio de las tropas y, cuando el primer grupo se queda corto, las suelta
##     junto al edificio vivo mas cercano al borde.


static func run(tree: SceneTree, game: Node, max_frames: int) -> bool:
	game.set("auto_retry", true)
	var queue: Array = []
	var planned: bool = false
	var reserve_sent: bool = false
	var last_try: int = -1
	for f: int in max_frames:
		await tree.physics_frame
		if not is_instance_valid(game):
			return false
		if bool(game.get("finished")):
			return true
		if int(game.get("deaths")) >= 2:
			return false
		if bool(game.get("failed")):
			continue
		var t: float = float(game.get("time_in_level"))
		if t < 0.05:
			## Nuevo intento (o el primero): se replanifica.
			planned = false
			reserve_sent = false
			queue.clear()
		if not planned:
			planned = true
			queue = _plan(game)
		while not queue.is_empty() and float(queue[0][0]) <= t:
			var item: Array = queue.pop_front()
			game.call("deploy", item[1], item[2])
		## Reserva: cuando quedan pocas tropas vivas.
		if queue.is_empty() and not reserve_sent and int(game.call("bot_state")["troops_alive"]) <= 3 and f != last_try:
			last_try = f
			var left: Dictionary = game.get("left")
			var any: bool = false
			for k: String in left.keys():
				if int(left[k]) > 0:
					any = true
			if not any:
				reserve_sent = true
			else:
				var cell: Vector2i = _front(game, true)
				var k2: float = t
				for kind: String in ["gigante", "guerrero", "arquera"]:
					for i: int in int(left.get(kind, 0)):
						k2 += 0.15
						queue.append([k2, kind, _near(game, cell, i)])
				reserve_sent = true
	return false


static func _plan(game: Node) -> Array:
	var army: Dictionary = game.get("left")
	var cell: Vector2i = _front(game, false)
	var out: Array = []
	var t: float = 0.5
	var g: int = int(army.get("gigante", 0))
	for i: int in g:
		out.append([t, "gigante", _near(game, cell, i)])
		t += 0.15
	if g > 0:
		t += 2.0
	var w: int = int(army.get("guerrero", 0))
	var a: int = int(army.get("arquera", 0))
	## Dos tercios ahora; el resto, de reserva.
	for i: int in int(ceil(float(w) * 0.67)):
		out.append([t, "guerrero", _near(game, cell, i)])
		t += 0.12
	t += 0.6
	for i: int in int(ceil(float(a) * 0.67)):
		out.append([t, "arquera", _near(game, cell, i + 3)])
		t += 0.12
	return out


## Casilla de despliegue mas cerca del centro de la base (o, con late=true, del edificio vivo mas cercano al borde).
static func _front(game: Node, late: bool) -> Vector2i:
	var cells: Array = game.call("deploy_cells")
	var b: Array = game.get("buildings")
	var target: Vector2 = Vector2.ZERO
	var n: int = 0
	if late:
		var best_d: float = 1e9
		for i: int in b.size():
			if not b[i]["alive"] or b[i]["wall"]:
				continue
			var c: Vector2 = game.call("center_of", i)
			for dc: Vector2i in cells:
				var d: float = (Vector2(dc) + Vector2(0.5, 0.5)).distance_to(c)
				if d < best_d:
					best_d = d
					target = c
		n = 1
	else:
		for i: int in b.size():
			if b[i]["wall"]:
				continue
			target += game.call("center_of", i)
			n += 1
		target /= float(maxi(n, 1))
	var best: Vector2i = cells[0] if not cells.is_empty() else Vector2i.ZERO
	var bd: float = 1e9
	for dc: Vector2i in cells:
		var d: float = (Vector2(dc) + Vector2(0.5, 0.5)).distance_to(target)
		if d < bd:
			bd = d
			best = dc
	return best


## Casilla de despliegue cercana a cell (se reparten un poco para no amontonarse).
static func _near(game: Node, cell: Vector2i, i: int) -> Vector2i:
	var offs: Array[Vector2i] = [Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(2, 0), Vector2i(0, 2)]
	for k: int in offs.size():
		var c: Vector2i = cell + offs[(i + k) % offs.size()]
		if bool(game.call("can_deploy", c)):
			return c
	return cell
