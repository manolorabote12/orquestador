extends RefCounted
## Analizador del puzle de cajas: comprueba SIN jugar que un nivel es justo, y lo resuelve.
## Mapa: "#" muro, "." suelo, "P" heroe, "B" caja, "O" hueco, "Q" caja en su hueco, "R" heroe en hueco.
## 1 - Filas del mismo ancho, un heroe, entre 1 y 6 cajas y tantos huecos como cajas.
## 2 - Ninguna caja empieza donde ya no podria llegar a un hueco (rincon o pared sin hueco).
## 3 - Tiene solucion: busqueda en anchura por empujes (la misma que fabrica/niveles/generador.py).
## Giro "hielo" (level.ice): el suelo resbala y una caja empujada sigue hasta chocar con un muro u
## otra caja (pasa por encima de los huecos sin pararse). El heroe no resbala.

const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const MAX_STATES: int = 80000


static func parse(rows: Array[String]) -> Dictionary:
	var walls: Dictionary = {}
	var boxes: Dictionary = {}
	var goals: Dictionary = {}
	var player: Vector2i = Vector2i(-1, -1)
	var players: int = 0
	var bad: bool = false
	for y: int in rows.size():
		for x: int in rows[y].length():
			var ch: String = rows[y][x]
			var c: Vector2i = Vector2i(x, y)
			match ch:
				"#":
					walls[c] = true
				"B":
					boxes[c] = true
				"O":
					goals[c] = true
				"Q":
					boxes[c] = true
					goals[c] = true
				"P":
					player = c
					players += 1
				"R":
					player = c
					goals[c] = true
					players += 1
				".":
					pass
				_:
					bad = true
	## Fuera del mapa es muro (asi ninguna busqueda se escapa aunque el borde no este cerrado).
	var w: int = 0
	for r: String in rows:
		w = maxi(w, r.length())
	for x: int in range(-1, w + 1):
		walls[Vector2i(x, -1)] = true
		walls[Vector2i(x, rows.size())] = true
	for y: int in rows.size():
		walls[Vector2i(-1, y)] = true
		for x: int in range(rows[y].length(), w + 1):
			walls[Vector2i(x, y)] = true
	return {"walls": walls, "boxes": boxes, "goals": goals, "player": player, "players": players, "bad": bad}


static func analyze(level: Dictionary) -> Dictionary:
	var rows: Array[String] = []
	for r: Variant in level.get("map", []):
		rows.append(str(r))
	var issues: Array[String] = []
	if rows.is_empty():
		issues.append("sokoban_empty")
		return {"completable": false, "issues": issues, "coins_total": 0, "enemies": 0, "enemy_problems": []}
	for r: String in rows:
		if r.length() != rows[0].length() and not issues.has("sokoban_bad_rows"):
			issues.append("sokoban_bad_rows")
	var m: Dictionary = parse(rows)
	if bool(m["bad"]):
		issues.append("sokoban_bad_char")
	if int(m["players"]) != 1:
		issues.append("sokoban_no_player")
	var nb: int = (m["boxes"] as Dictionary).size()
	if nb < 1 or nb > 6:
		issues.append("sokoban_box_count")
	if nb != (m["goals"] as Dictionary).size():
		issues.append("sokoban_goals_mismatch")
	var ice: bool = bool(level.get("ice", false))
	if issues.is_empty():
		if dead_box(m["walls"], m["goals"], m["boxes"], ice):
			issues.append("sokoban_dead_box")
	if issues.is_empty() and solve(rows, ice).is_empty() and not _solved(m["boxes"], m["goals"]):
		issues.append("sokoban_unsolvable")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": nb, "enemies": 0, "enemy_problems": []}


static func _solved(boxes: Dictionary, goals: Dictionary) -> bool:
	for b: Vector2i in boxes:
		if not goals.has(b):
			return false
	return true


## Casillas desde las que una caja todavia puede llegar a algun hueco (se tira desde los huecos).
static func live_cells(walls: Dictionary, goals: Dictionary) -> Dictionary:
	var alive: Dictionary = goals.duplicate()
	var stack: Array[Vector2i] = []
	for g: Vector2i in goals:
		stack.append(g)
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		for d: Vector2i in DIRS:
			var b: Vector2i = c + d
			var j: Vector2i = c + d * 2
			if not alive.has(b) and not walls.has(b) and not walls.has(j):
				alive[b] = true
				stack.append(b)
	return alive


static func zone(walls: Dictionary, boxes: Dictionary, from: Vector2i) -> Dictionary:
	var seen: Dictionary = {from: true}
	var stack: Array[Vector2i] = [from]
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		for d: Vector2i in DIRS:
			var n: Vector2i = c + d
			if not seen.has(n) and not walls.has(n) and not boxes.has(n):
				seen[n] = true
				stack.append(n)
	return seen


static func _key(boxes: Dictionary, z: Dictionary) -> String:
	var parts: Array[String] = []
	for b: Vector2i in boxes:
		parts.append("%d,%d" % [b.x, b.y])
	parts.sort()
	var best: Vector2i = Vector2i(9999, 9999)
	for c: Vector2i in z:
		if c.y < best.y or (c.y == best.y and c.x < best.x):
			best = c
	return ";".join(parts) + "|%d,%d" % [best.x, best.y]


## Donde acaba una caja empujada desde 'b' hacia 'd' (b + d tiene que estar libre). Sin hielo, una
## casilla; con hielo, sigue hasta que lo siguiente sea muro o caja ('boxes' sin la caja que se mueve).
static func slide_end(walls: Dictionary, boxes: Dictionary, b: Vector2i, d: Vector2i, ice: bool) -> Vector2i:
	var e: Vector2i = b + d
	if not ice:
		return e
	while not walls.has(e + d) and not boxes.has(e + d):
		e += d
	return e


## Casillas buenas para una caja. Sin hielo, las que todavia llegan a un hueco; con hielo, todo el
## suelo menos los rincones sin hueco (de un rincon no se puede sacar una caja).
static func _alive_for(walls: Dictionary, goals: Dictionary, ice: bool, area: Dictionary) -> Dictionary:
	if not ice:
		return live_cells(walls, goals)
	var out: Dictionary = {}
	for c: Vector2i in area:
		if goals.has(c) or not _corner(walls, c):
			out[c] = true
	return out


static func _corner(walls: Dictionary, c: Vector2i) -> bool:
	var h: bool = walls.has(c + Vector2i(1, 0)) or walls.has(c + Vector2i(-1, 0))
	var v: bool = walls.has(c + Vector2i(0, 1)) or walls.has(c + Vector2i(0, -1))
	return h and v


## Solucion con el minimo de empujes: lista de [caja, direccion]. Vacia si no hay (o ya esta resuelto).
static func solve(rows: Array[String], ice: bool = false) -> Array:
	var m: Dictionary = parse(rows)
	var walls: Dictionary = m["walls"]
	var goals: Dictionary = m["goals"]
	var area: Dictionary = zone(walls, {}, m["player"])
	var alive: Dictionary = _alive_for(walls, goals, ice, area)
	var start_boxes: Dictionary = m["boxes"]
	if _solved(start_boxes, goals):
		return []
	var z0: Dictionary = zone(walls, start_boxes, m["player"])
	var seen: Dictionary = {_key(start_boxes, z0): true}
	## Cada nodo: [cajas, zona, camino (lista de [caja, dir])]
	var frontier: Array = [[start_boxes, z0, []]]
	while not frontier.is_empty() and seen.size() < MAX_STATES:
		var next: Array = []
		for node: Array in frontier:
			var boxes: Dictionary = node[0]
			var z: Dictionary = node[1]
			for b: Vector2i in boxes:
				for d: Vector2i in DIRS:
					var from: Vector2i = b - d
					if not z.has(from) or walls.has(b + d) or boxes.has(b + d):
						continue
					var nb: Dictionary = boxes.duplicate()
					nb.erase(b)
					var dest: Vector2i = slide_end(walls, nb, b, d, ice)
					if not alive.has(dest):
						continue
					nb[dest] = true
					var path: Array = (node[2] as Array).duplicate()
					path.append([b, d])
					if _solved(nb, goals):
						return path
					var nz: Dictionary = zone(walls, nb, b)
					var k: String = _key(nb, nz)
					if not seen.has(k):
						seen[k] = true
						next.append([nb, nz, path])
		frontier = next
	return []


## Camino a pie (sin empujar) de 'from' a 'to': lista de direcciones. Vacia si no se puede.
static func walk(walls: Dictionary, boxes: Dictionary, from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if from == to:
		return out
	var prev: Dictionary = {from: from}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if c == to:
			break
		for d: Vector2i in DIRS:
			var n: Vector2i = c + d
			if not prev.has(n) and not walls.has(n) and not boxes.has(n):
				prev[n] = c
				queue.append(n)
	if not prev.has(to):
		return out
	var c2: Vector2i = to
	while c2 != from:
		var p: Vector2i = prev[c2]
		out.push_front(c2 - p)
		c2 = p
	return out


## Caja muerta: no esta en un hueco y ya no puede llegar a ninguno (con hielo: esta en un rincon).
static func dead_box(walls: Dictionary, goals: Dictionary, boxes: Dictionary, ice: bool = false) -> bool:
	var alive: Dictionary = live_cells(walls, goals) if not ice else {}
	for b: Vector2i in boxes:
		if goals.has(b):
			continue
		if (ice and _corner(walls, b)) or (not ice and not alive.has(b)):
			return true
	return false
