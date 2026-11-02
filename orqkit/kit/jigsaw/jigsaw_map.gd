extends RefCounted
## Rompecabezas: un dibujo partido en cuadrados y desordenado; toca (o arrastra) dos piezas para
## cambiarlas de sitio. La pieza que cae en su sitio se queda fija. Se gana con el dibujo completo.
## Nivel: "size" (lado: 3 a 7 piezas), "order" (que pieza hay en cada hueco, de izquierda a
## derecha y de arriba abajo), "moves" (cambios maximos; 0 = sin limite), el dibujo ("scene",
## "bg", "ground", como en las diferencias) y "hero" (el heroe del juego en medio del dibujo).
## El minimo de cambios es piezas - ciclos de la permutacion; el bot lo consigue siempre.

const Rules = preload("res://kit/rules.gd")


static func new_state(level: Dictionary) -> Dictionary:
	var n: int = clampi(int(level.get("size", 3)), 2, 8)
	var order: Array = []
	for v: Variant in level.get("order", []):
		order.append(int(v))
	if order.size() != n * n:
		order = range(n * n)
	var st: Dictionary = {"n": n, "slots": order, "moves": 0, "max_moves": maxi(0, int(level.get("moves", 0))), "peeks": 2,
		"won": false, "lost": false, "rng": RandomNumberGenerator.new()}
	st["won"] = solved(st)
	st["rules"] = Rules.load_rules(level)
	Rules.hook(st, "on_start")
	return st


static func solved(st: Dictionary) -> bool:
	for i: int in (st["slots"] as Array).size():
		if int(st["slots"][i]) != i:
			return false
	return true


static func placed(st: Dictionary, slot: int) -> bool:
	return slot >= 0 and slot < (st["slots"] as Array).size() and int(st["slots"][slot]) == slot


## Cuantas piezas estan ya en su sitio.
static func placed_count(st: Dictionary) -> int:
	var c: int = 0
	for i: int in (st["slots"] as Array).size():
		c += 1 if int(st["slots"][i]) == i else 0
	return c


## Cambia las piezas de los huecos a y b. Devuelve cuantas piezas han quedado en su sitio con el
## cambio (0, 1 o 2) o -1 si no se puede (la misma, fuera o alguna ya fija).
static func swap(st: Dictionary, a: int, b: int) -> int:
	var sl: Array = st["slots"]
	if bool(st["won"]) or bool(st["lost"]) or a == b or a < 0 or b < 0 or a >= sl.size() or b >= sl.size():
		return -1
	if placed(st, a) or placed(st, b):
		return -1
	var t: int = int(sl[a])
	sl[a] = sl[b]
	sl[b] = t
	st["moves"] = int(st["moves"]) + 1
	var got: int = (1 if placed(st, a) else 0) + (1 if placed(st, b) else 0)
	if solved(st):
		st["won"] = true
	elif int(st["max_moves"]) > 0 and int(st["moves"]) >= int(st["max_moves"]):
		st["lost"] = true
	Rules.hook(st, "on_swap", [a, b, got])
	return got


## Minimo de cambios para resolverlo: piezas fuera de sitio menos ciclos.
static func min_swaps(order: Array) -> int:
	var seen: Dictionary = {}
	var out: int = 0
	for i: int in order.size():
		if seen.has(i) or int(order[i]) == i:
			continue
		var j: int = i
		var len_c: int = 0
		while not seen.has(j):
			seen[j] = true
			j = int(order[j])
			len_c += 1
		out += len_c - 1
	return out


## Jugada del bot: [hueco, hueco] que pone al menos una pieza en su sitio (siempre optimo).
static func bot_move(st: Dictionary) -> Array:
	var sl: Array = st["slots"]
	for i: int in sl.size():
		if int(sl[i]) != i:
			for j: int in sl.size():
				if int(sl[j]) == i:
					return [i, j]
	return []


## Analizador: una permutacion de verdad, que no venga casi hecho, que pida varios cambios y que el
## limite (si lo hay) deje margen sobre el minimo.
static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var n: int = int(level.get("size", 0))
	var order: Array = level.get("order", [])
	if n < 2 or n > 8:
		issues.append("jig_size")
	var ok_perm: bool = order.size() == n * n
	if ok_perm:
		var seen: Dictionary = {}
		for v: Variant in order:
			if int(v) < 0 or int(v) >= order.size() or seen.has(int(v)):
				ok_perm = false
			seen[int(v)] = true
	if not ok_perm:
		issues.append("jig_not_permutation")
	var need: int = 0
	if ok_perm and n >= 2:
		need = min_swaps(order)
		var home: int = 0
		for i: int in order.size():
			home += 1 if int(order[i]) == i else 0
		if home * 4 > order.size():
			issues.append("jig_mostly_done")
		if need < 3:
			issues.append("jig_too_easy")
		var mm: int = int(level.get("moves", 0))
		if mm > 0 and mm < need + 2:
			issues.append("jig_moves_tight")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": order.size(), "enemies": 0, "enemy_problems": [], "min_swaps": need}
