extends RefCounted
## Bot de la serpiente (la estrategia segura clasica). En cada casilla nueva:
## 1 - Camino mas corto a la fruta (sin pisar paredes ni cuerpo; la cola se mueve).
## 2 - Antes de ir, simula comersela: si desde ahi aun puede llegar a su cola, va.
## 3 - Si no, sigue a su cola por la casilla libre con mas espacio alrededor (no se encierra).
## Si gana con las reglas reales, el nivel es jugable.

const DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]


static func run(tree: SceneTree, game: Node, max_frames: int) -> bool:
	game.set("auto_retry", true)
	game.set("fast", true)
	var last_head: Vector2i = Vector2i(-99, -99)
	var last_len: int = -1
	## Casillas visitadas con la misma longitud: si da vueltas, se arriesga un poco mas.
	var visits: Dictionary = {}
	for f: int in max_frames:
		await tree.physics_frame
		if not is_instance_valid(game):
			return false
		if bool(game.get("finished")):
			return true
		if int(game.get("deaths")) >= 3:
			return false
		var body: Array = game.get("body")
		if body.is_empty():
			continue
		if body[0] != last_head or body.size() != last_len:
			if body.size() != last_len:
				visits.clear()
			last_head = body[0]
			last_len = body.size()
			visits[last_head] = int(visits.get(last_head, 0)) + 1
			var d: Vector2i = decide(game, visits)
			if d != Vector2i.ZERO:
				game.call("turn", d)
	return false


static func free_cell(game: Node, blocked: Dictionary, c: Vector2i) -> bool:
	return not bool(game.call("wall", c)) and not blocked.has(c)


## Distancias BFS desde 'from'. 'blocked' = casillas ocupadas.
static func bfs(game: Node, blocked: Dictionary, from: Vector2i) -> Dictionary:
	var dist: Dictionary = {from: 0}
	var prev: Dictionary = {}
	var q: Array[Vector2i] = [from]
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		for d: Vector2i in DIRS:
			var n: Vector2i = game.call("next_cell", c, d)
			if dist.has(n) or not free_cell(game, blocked, n):
				continue
			dist[n] = int(dist[c]) + 1
			prev[n] = c
			q.append(n)
	return {"dist": dist, "prev": prev}


## Espacio que le queda a una serpiente: casillas alcanzables contando que la cola se va
## soltando (una casilla del cuerpo a distancia j de la cola queda libre en j + 1 pasos).
static func room(game: Node, body: Array) -> int:
	var vac: Dictionary = {}
	for i: int in body.size():
		vac[body[i]] = body.size() - i
	var head: Vector2i = body[0]
	var dist: Dictionary = {head: 0}
	var q: Array[Vector2i] = [head]
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		var t: int = int(dist[c]) + 1
		for d: Vector2i in DIRS:
			var n: Vector2i = game.call("next_cell", c, d)
			if dist.has(n) or bool(game.call("wall", n)):
				continue
			if vac.has(n) and int(vac[n]) > t:
				continue
			dist[n] = t
			q.append(n)
	return dist.size()


## Direccion para pasar de 'a' a la casilla vecina 'b' (contando los tuneles).
static func dir_to(game: Node, a: Vector2i, b: Vector2i) -> Vector2i:
	for d: Vector2i in DIRS:
		if game.call("next_cell", a, d) == b:
			return d
	return Vector2i.ZERO


static func occupied(body: Array, skip_tail: int) -> Dictionary:
	var o: Dictionary = {}
	for i: int in body.size() - skip_tail:
		o[body[i]] = true
	return o


static func decide(game: Node, visits: Dictionary = {}) -> Vector2i:
	var body: Array = game.get("body")
	var head: Vector2i = body[0]
	var dir: Vector2i = game.get("dir")
	var fruit: Vector2i = game.get("fruit")
	## 1 y 2 - Ir a la fruta si despues sigue teniendo salida.
	var blocked: Dictionary = occupied(body, 1)
	blocked.erase(head)
	var r: Dictionary = bfs(game, blocked, head)
	if fruit.x >= 0 and (r["dist"] as Dictionary).has(fruit):
		var path: Array[Vector2i] = []
		var c: Vector2i = fruit
		while c != head:
			path.push_front(c)
			c = (r["prev"] as Dictionary)[c]
		var virt: Array = body.duplicate()
		for p: Vector2i in path:
			virt.push_front(p)
			if p != fruit:
				virt.pop_back()
		## Seguro si despues de comer le queda sitio de sobra (la cola se va soltando).
		var safe: bool = room(game, virt) >= virt.size() + 4
		var last_fruit: bool = int(game.get("eaten")) + 1 >= int(game.call("goal"))
		if safe or last_fruit:
			var step: Vector2i = dir_to(game, head, path[0])
			if step != -dir and step != Vector2i.ZERO:
				return step
	## 3 - Seguir la cola por donde haya mas sitio.
	var best: Vector2i = Vector2i.ZERO
	var best_v: float = -INF
	for d: Vector2i in DIRS:
		if d == -dir:
			continue
		var n: Vector2i = game.call("next_cell", head, d)
		if not free_cell(game, blocked, n):
			continue
		var moved: Array = body.duplicate()
		moved.push_front(n)
		moved.pop_back()
		var space: int = room(game, moved)
		var roomy: bool = space >= moved.size() + 4
		## Con sitio de sobra, acercarse a la fruta; si ya ha pasado mucho por ahi, evitarlo.
		var to_fruit: float = float(absi(n.x - fruit.x) + absi(n.y - fruit.y)) if fruit.x >= 0 else 0.0
		var v: float = float(mini(space, body.size() + 8)) * 4.0 + (500.0 if roomy else 0.0) - to_fruit * 3.0 - float(visits.get(n, 0)) * 6.0
		if v > best_v:
			best_v = v
			best = d
	return best
