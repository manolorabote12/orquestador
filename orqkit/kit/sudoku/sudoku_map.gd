extends RefCounted
## Sudoku (4x4, 6x6 o 9x9): reglas, resolutor, bot y analizador.
## 1 - Mapa (game.json -> levels[i].map): una fila por linea, digitos dados y "." en los huecos.
##     El tamano sale del mapa: 4 (cajas 2x2), 6 (cajas 3x2) o 9 (cajas 3x3).
## 2 - Cada fila, columna y caja lleva cada numero una vez. Un numero que no es el de la solucion
##     cuenta como fallo; con "lives" fallos se pierde.
## Analizador: tamano valido, pistas que no se contradicen y solucion UNICA (el resolutor cuenta
## hasta dos soluciones).

const BOXES: Dictionary = {4: Vector2i(2, 2), 6: Vector2i(3, 2), 9: Vector2i(3, 3)}


static func parse(level: Dictionary) -> Array:
	var out: Array = []
	for r: Variant in level.get("map", []):
		var row: Array = []
		var s: String = str(r)
		for i: int in s.length():
			row.append(int(s[i]) if s[i] >= "1" and s[i] <= "9" else 0)
		out.append(row)
	return out


static func box_of(n: int) -> Vector2i:
	return BOXES.get(n, Vector2i(3, 3))


static func can_place(g: Array, n: int, x: int, y: int, v: int) -> bool:
	for k: int in n:
		if int(g[y][k]) == v and k != x:
			return false
		if int(g[k][x]) == v and k != y:
			return false
	var b: Vector2i = box_of(n)
	var bx: int = (x / b.x) * b.x
	var by: int = (y / b.y) * b.y
	for yy: int in range(by, by + b.y):
		for xx: int in range(bx, bx + b.x):
			if (xx != x or yy != y) and int(g[yy][xx]) == v:
				return false
	return true


## Cuenta soluciones (hasta "limit") y deja la primera en "first". Elige siempre la casilla con
## menos opciones: asi un 9x9 se resuelve al momento.
static func solve(g: Array, n: int, limit: int, first: Array) -> int:
	var best_x: int = -1
	var best_y: int = -1
	var best: Array = []
	for y: int in n:
		for x: int in n:
			if int(g[y][x]) != 0:
				continue
			var opts: Array = []
			for v: int in range(1, n + 1):
				if can_place(g, n, x, y, v):
					opts.append(v)
			if opts.is_empty():
				return 0
			if best_x < 0 or opts.size() < best.size():
				best_x = x
				best_y = y
				best = opts
	if best_x < 0:
		if first.is_empty():
			for row: Variant in g:
				first.append((row as Array).duplicate())
		return 1
	var count: int = 0
	for v: Variant in best:
		g[best_y][best_x] = v
		count += solve(g, n, limit - count, first)
		g[best_y][best_x] = 0
		if count >= limit:
			break
	return count


static func new_state(level: Dictionary) -> Dictionary:
	var g: Array = parse(level)
	var n: int = g.size()
	var sol: Array = []
	var work: Array = []
	for row: Variant in g:
		work.append((row as Array).duplicate())
	solve(work, n, 1, sol)
	var given: Dictionary = {}
	for y: int in n:
		for x: int in n:
			if int(g[y][x]) != 0:
				given[Vector2i(x, y)] = true
	return {"grid": g, "n": n, "sol": sol, "given": given, "mistakes": 0, "lives": int(level.get("lives", 3)), "hints": 0}


## Pone un numero: true si es el de la solucion (si no, fallo y no se pone).
static func put(st: Dictionary, x: int, y: int, v: int) -> bool:
	if (st["given"] as Dictionary).has(Vector2i(x, y)) or (st["sol"] as Array).is_empty():
		return false
	if int(st["sol"][y][x]) != v:
		st["mistakes"] = int(st["mistakes"]) + 1
		return false
	st["grid"][y][x] = v
	return true


static func solved(st: Dictionary) -> bool:
	if (st["sol"] as Array).is_empty():
		return false
	for y: int in int(st["n"]):
		for x: int in int(st["n"]):
			if int(st["grid"][y][x]) != int(st["sol"][y][x]):
				return false
	return true


static func lost(st: Dictionary) -> bool:
	return int(st["lives"]) > 0 and int(st["mistakes"]) >= int(st["lives"])


## Siguiente casilla del bot (o de la pista): la vacia con menos opciones. [x, y, valor] o [].
static func next_move(st: Dictionary) -> Array:
	var n: int = int(st["n"])
	var best: Array = []
	var best_k: int = 99
	for y: int in n:
		for x: int in n:
			if int(st["grid"][y][x]) != 0:
				continue
			var k: int = 0
			for v: int in range(1, n + 1):
				if can_place(st["grid"], n, x, y, v):
					k += 1
			if k < best_k:
				best_k = k
				best = [x, y, int(st["sol"][y][x])]
	return best


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var g: Array = parse(level)
	var n: int = g.size()
	if not BOXES.has(n):
		issues.append("sudoku_size")
	else:
		for row: Variant in g:
			if (row as Array).size() != n:
				issues.append("sudoku_size")
				break
	var clues: int = 0
	if issues.is_empty():
		for y: int in n:
			for x: int in n:
				var v: int = int(g[y][x])
				if v != 0:
					clues += 1
					if v > n or not can_place(g, n, x, y, v):
						issues.append("sudoku_clash")
						break
	if issues.is_empty():
		var first: Array = []
		var c: int = solve(g, n, 2, first)
		if c == 0:
			issues.append("sudoku_no_solution")
		elif c > 1:
			issues.append("sudoku_not_unique")
	var empty: int = n * n - clues
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": empty, "enemies": 0, "enemy_problems": [],
		"par": 10 + empty * (3 if n <= 4 else (5 if n <= 6 else 8))}
