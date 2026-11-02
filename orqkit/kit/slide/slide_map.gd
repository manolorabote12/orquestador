extends RefCounted
## Puzle de deslizar (el de 15): el dibujo partido en n x n piezas con un hueco. Tocas una pieza de
## la fila o la columna del hueco y se desliza (con las que haya en medio). Gana el dibujo entero.
## Nivel: "n" (3 a 5), "tiles" (pieza en cada casilla; la n*n-1 es el hueco), "sol" (casillas que
## tocar, en orden, para resolverlo: la fabrica lo desordena moviendo el hueco y guarda la vuelta),
## "moves" (limite de piezas movidas, 0 = sin limite), "scene", "hero", "bg", "ground" (el dibujo).

const Rules = preload("res://kit/rules.gd")


static func new_state(level: Dictionary) -> Dictionary:
	var n: int = clampi(int(level.get("n", 3)), 2, 6)
	var tiles: Array = []
	for t: Variant in level.get("tiles", []):
		tiles.append(int(t))
	var st: Dictionary = {"n": n, "tiles": tiles, "moves": 0, "max_moves": int(level.get("moves", 0)), "won": false, "lost": false,
		"last": []}
	st["rules"] = Rules.load_rules(level)
	Rules.hook(st, "on_start")
	return st


static func blank_of(tiles: Array, n: int) -> int:
	return tiles.find(n * n - 1)


static func solved(tiles: Array) -> bool:
	for i: int in tiles.size():
		if int(tiles[i]) != i:
			return false
	return true


## Casillas que se mueven al tocar s (de la mas cercana al hueco a s), vacio si no se puede.
static func slide_path(tiles: Array, n: int, s: int) -> Array:
	var b: int = blank_of(tiles, n)
	if s < 0 or s >= n * n or s == b:
		return []
	var step: int = 0
	if s / n == b / n:
		step = 1 if s > b else -1
	elif s % n == b % n:
		step = n if s > b else -n
	else:
		return []
	var out: Array = []
	var c: int = b + step
	while true:
		out.append(c)
		if c == s:
			break
		c += step
	return out


## Toca la casilla s. Devuelve cuantas piezas se movieron (0 si no vale).
static func tap(st: Dictionary, s: int) -> int:
	if bool(st["won"]) or bool(st["lost"]):
		return 0
	var n: int = int(st["n"])
	var tiles: Array = st["tiles"]
	var path: Array = slide_path(tiles, n, s)
	if path.is_empty():
		return 0
	var moved: Array = []
	for c: Variant in path:
		var b: int = blank_of(tiles, n)
		tiles[b] = tiles[int(c)]
		tiles[int(c)] = n * n - 1
		moved.append([int(c), b])
	st["last"] = moved
	st["moves"] = int(st["moves"]) + path.size()
	Rules.hook(st, "on_slide", [s, path.size()])
	if solved(tiles):
		st["won"] = true
	elif int(st["max_moves"]) > 0 and int(st["moves"]) >= int(st["max_moves"]):
		st["lost"] = true
	return path.size()


static func placed_count(st: Dictionary) -> int:
	var c: int = 0
	var tiles: Array = st["tiles"]
	for i: int in tiles.size():
		if int(tiles[i]) == i and i != tiles.size() - 1:
			c += 1
	return c


## Se puede resolver (paridad de las inversiones y fila del hueco).
static func solvable(tiles: Array, n: int) -> bool:
	var inv: int = 0
	var flat: Array = []
	for t: Variant in tiles:
		if int(t) != n * n - 1:
			flat.append(int(t))
	for a: int in flat.size():
		for b: int in range(a + 1, flat.size()):
			if int(flat[a]) > int(flat[b]):
				inv += 1
	if n % 2 == 1:
		return inv % 2 == 0
	var row_from_bottom: int = n - blank_of(tiles, n) / n
	return (inv + row_from_bottom) % 2 == 1


## Bot: la siguiente casilla de la solucion de la fabrica (si sigue en su camino).
static func bot_move(st: Dictionary, sol: Array) -> int:
	var k: int = int(st.get("bot_k", 0))
	if k >= sol.size():
		return -1
	st["bot_k"] = k + 1
	return int(sol[k])


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var n: int = int(level.get("n", 0))
	var tiles: Array = []
	for t: Variant in level.get("tiles", []):
		tiles.append(int(t))
	if n < 3 or n > 5:
		issues.append("slide_size")
	elif tiles.size() != n * n:
		issues.append("slide_tiles")
	else:
		var seen: Dictionary = {}
		for t: Variant in tiles:
			seen[int(t)] = true
		if seen.size() != n * n or not seen.has(0) or not seen.has(n * n - 1):
			issues.append("slide_not_permutation")
		elif not solvable(tiles, n):
			issues.append("slide_unsolvable")
		elif solved(tiles):
			issues.append("slide_already_solved")
		else:
			var st: Dictionary = new_state(level)
			var sol: Array = level.get("sol", [])
			for s: Variant in sol:
				if tap(st, int(s)) == 0:
					break
			if not bool(st["won"]):
				issues.append("slide_bad_solution")
			if int(level.get("moves", 0)) > 0 and int(level.get("moves", 0)) < sol.size():
				issues.append("slide_moves_short")
			var placed: int = placed_count(new_state(level))
			if placed * 2 > n * n:
				issues.append("slide_almost_done")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": maxi(0, n * n - 1), "enemies": 0, "enemy_problems": []}
