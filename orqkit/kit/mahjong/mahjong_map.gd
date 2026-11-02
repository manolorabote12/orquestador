extends RefCounted
## Mahjong solitario (estilo Mahjong Solitaire / Tile Match): reglas, reparto, bot y analizador.
## 1 - Mapa (game.json -> levels[i].map): filas de digitos; cada digito es la altura de la pila
##     de fichas en esa casilla ("." o "0" = vacio). Ejemplo: ["1221", "1331", "1221"].
## 2 - Una ficha esta libre si no tiene otra encima y le falta la vecina de la izquierda o la de
##     la derecha en su misma altura. Se quitan parejas de fichas libres con el mismo dibujo.
## 3 - Reparto: se elige un orden de parejas libres desde el tablero lleno (una solucion) y se
##     le da el mismo dibujo a cada pareja, asi que siempre hay solucion. Barajar reparte otra vez
##     los dibujos que quedan con el mismo metodo. Si lo que queda no tiene salida por como estan
##     colocadas las fichas (p. ej. dos en la misma pila), devuelve al tablero las ultimas parejas
##     quitadas hasta que la tenga: barajar siempre deja un tablero con solucion.
## Parametros: "kinds" (dibujos distintos, 4-24), "seed", "shuffles" (barajadas) y "par" (segundos).

const KINDS_MAX: int = 24
const TRIES: int = 60


## Fichas del mapa: [{"x", "y", "z"}] ordenadas por altura, fila y columna.
static func parse(level: Dictionary) -> Array:
	var out: Array = []
	var rows: Array = level.get("map", [])
	for y: int in rows.size():
		var row: String = str(rows[y])
		for x: int in row.length():
			var ch: String = row[x]
			if ch >= "1" and ch <= "9":
				for z: int in int(ch):
					out.append({"x": x, "y": y, "z": z})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["z"]) != int(b["z"]):
			return int(a["z"]) < int(b["z"])
		if int(a["y"]) != int(b["y"]):
			return int(a["y"]) < int(b["y"])
		return int(a["x"]) < int(b["x"]))
	return out


static func _key(x: int, y: int, z: int) -> int:
	return (z * 256 + y) * 256 + x + 1000


## Indice de posiciones vivas -> ficha.
static func occupancy(tiles: Array, alive: Array) -> Dictionary:
	var occ: Dictionary = {}
	for i: int in tiles.size():
		if alive[i]:
			var t: Dictionary = tiles[i]
			occ[_key(int(t["x"]), int(t["y"]), int(t["z"]))] = i
	return occ


static func is_free(tiles: Array, occ: Dictionary, i: int) -> bool:
	var t: Dictionary = tiles[i]
	var x: int = int(t["x"])
	var y: int = int(t["y"])
	var z: int = int(t["z"])
	if occ.has(_key(x, y, z + 1)):
		return false
	return not occ.has(_key(x - 1, y, z)) or not occ.has(_key(x + 1, y, z))


static func free_tiles(tiles: Array, alive: Array) -> Array[int]:
	var occ: Dictionary = occupancy(tiles, alive)
	var out: Array[int] = []
	for i: int in tiles.size():
		if alive[i] and is_free(tiles, occ, i):
			out.append(i)
	return out


## 1 - Reparte dibujos a las fichas vivas: busca un orden de parejas libres hasta vaciar el tablero
##     y le da a cada pareja un dibujo de "pairs" (lista de dibujos, uno por pareja).
## Devuelve {"faces": {indice: dibujo}, "order": [[a, b], ...]} o {} si no encuentra orden.
static func deal(tiles: Array, alive: Array, pairs: Array, seed_v: int) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	for attempt: int in TRIES:
		rng.seed = seed_v * 7919 + attempt * 104729
		var al: Array = alive.duplicate()
		var order: Array = []
		var ok: bool = true
		var left: int = 0
		for a: Variant in al:
			if a:
				left += 1
		while left > 0:
			var fr: Array[int] = free_tiles(tiles, al)
			if fr.size() < 2:
				ok = false
				break
			## Preferir fichas altas: asi no se quedan pilas sueltas al final.
			fr.sort_custom(func(p: int, q: int) -> bool: return int(tiles[p]["z"]) > int(tiles[q]["z"]))
			var top: int = mini(fr.size(), 2 + rng.randi_range(0, 3))
			var a_i: int = fr[rng.randi_range(0, top - 1)]
			fr.erase(a_i)
			var b_i: int = fr[rng.randi_range(0, fr.size() - 1)]
			al[a_i] = false
			al[b_i] = false
			order.append([a_i, b_i])
			left -= 2
		if ok:
			var shuffled: Array = pairs.duplicate()
			for i: int in range(shuffled.size() - 1, 0, -1):
				var j: int = rng.randi_range(0, i)
				var tmp: Variant = shuffled[i]
				shuffled[i] = shuffled[j]
				shuffled[j] = tmp
			var faces: Dictionary = {}
			for k: int in order.size():
				faces[order[k][0]] = int(shuffled[k])
				faces[order[k][1]] = int(shuffled[k])
			return {"faces": faces, "order": order}
	return {}


## Lista de dibujos (uno por pareja) para n parejas con "kinds" dibujos distintos.
static func pair_faces(n_pairs: int, kinds: int) -> Array:
	var out: Array = []
	for k: int in n_pairs:
		out.append(k % clampi(kinds, 1, KINDS_MAX))
	return out


static func new_state(level: Dictionary) -> Dictionary:
	var tiles: Array = parse(level)
	var alive: Array = []
	alive.resize(tiles.size())
	alive.fill(true)
	var faces: Array = []
	faces.resize(tiles.size())
	faces.fill(0)
	var st: Dictionary = {"tiles": tiles, "alive": alive, "faces": faces, "order": [], "left": tiles.size(),
		"shuffles": int(level.get("shuffles", 2)), "seed": int(level.get("seed", 1)), "moves": 0, "ok": false, "removed": [],
		"returned": 0}
	if tiles.size() % 2 != 0 or tiles.is_empty():
		return st
	var d: Dictionary = deal(tiles, alive, pair_faces(tiles.size() / 2, int(level.get("kinds", 8))), int(st["seed"]))
	if d.is_empty():
		return st
	for i: Variant in d["faces"]:
		faces[int(i)] = int(d["faces"][i])
	st["order"] = d["order"]
	st["ok"] = true
	return st


## Quita la pareja si se puede. Devuelve true si la quito.
static func match_pair(st: Dictionary, a: int, b: int) -> bool:
	var tiles: Array = st["tiles"]
	var alive: Array = st["alive"]
	if a == b or a < 0 or b < 0 or a >= tiles.size() or b >= tiles.size() or not alive[a] or not alive[b]:
		return false
	if int(st["faces"][a]) != int(st["faces"][b]):
		return false
	var occ: Dictionary = occupancy(tiles, alive)
	if not is_free(tiles, occ, a) or not is_free(tiles, occ, b):
		return false
	alive[a] = false
	alive[b] = false
	(st["removed"] as Array).append([a, b])
	st["left"] = int(st["left"]) - 2
	st["moves"] = int(st["moves"]) + 1
	return true


## Una pareja que se puede quitar ahora mismo (o [] si no hay ninguna).
static func hint(st: Dictionary) -> Array:
	var fr: Array[int] = free_tiles(st["tiles"], st["alive"])
	var by_face: Dictionary = {}
	for i: int in fr:
		var f: int = int(st["faces"][i])
		if by_face.has(f):
			return [by_face[f], i]
		by_face[f] = i
	return []


## Barajar: vuelve a repartir los dibujos que quedan sobre las fichas vivas (con solucion).
static func shuffle(st: Dictionary) -> bool:
	if int(st["shuffles"]) <= 0 or int(st["left"]) <= 0:
		return false
	st["returned"] = 0
	while true:
		var counts: Dictionary = {}
		for i: int in (st["tiles"] as Array).size():
			if st["alive"][i]:
				var f: int = int(st["faces"][i])
				counts[f] = int(counts.get(f, 0)) + 1
		var pairs: Array = []
		for f: Variant in counts:
			for k: int in int(counts[f]) / 2:
				pairs.append(int(f))
		var d: Dictionary = deal(st["tiles"], st["alive"], pairs, int(st["seed"]) + 31 * (int(st["moves"]) + 1) + int(st["shuffles"]))
		if not d.is_empty():
			for i: Variant in d["faces"]:
				st["faces"][int(i)] = int(d["faces"][i])
			st["order"] = d["order"]
			st["shuffles"] = int(st["shuffles"]) - 1
			return true
		## Sin salida por la colocacion: vuelve al tablero la ultima pareja quitada.
		var rem: Array = st["removed"]
		if rem.is_empty():
			return false
		var last: Array = rem.pop_back()
		st["alive"][int(last[0])] = true
		st["alive"][int(last[1])] = true
		st["left"] = int(st["left"]) + 2
		st["returned"] = int(st["returned"]) + 1
	return false


## Siguiente jugada del bot: la siguiente pareja de la solucion; si alguien se salio del guion,
## cualquier pareja libre. [] si no hay (toca barajar).
static func bot_pick(st: Dictionary) -> Array:
	var occ: Dictionary = occupancy(st["tiles"], st["alive"])
	for p: Variant in st["order"]:
		var a: int = int(p[0])
		var b: int = int(p[1])
		if st["alive"][a] and st["alive"][b] and int(st["faces"][a]) == int(st["faces"][b]) \
				and is_free(st["tiles"], occ, a) and is_free(st["tiles"], occ, b):
			return [a, b]
	return hint(st)


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var tiles: Array = parse(level)
	var rows: Array = level.get("map", [])
	if tiles.size() < 8 or tiles.size() > 144:
		issues.append("mahjong_size")
	if tiles.size() % 2 != 0:
		issues.append("mahjong_odd")
	var width: int = 0
	for r: Variant in rows:
		width = maxi(width, str(r).length())
	if width > 9 or rows.size() > 9:
		issues.append("mahjong_big")
	var par: int = 0
	if issues.is_empty():
		var st: Dictionary = new_state(level)
		if not bool(st["ok"]):
			issues.append("mahjong_no_deal")
		else:
			var guard: int = 0
			while int(st["left"]) > 0 and guard < 200:
				guard += 1
				var p: Array = bot_pick(st)
				if p.is_empty() or not match_pair(st, int(p[0]), int(p[1])):
					issues.append("mahjong_stuck")
					break
			par = int(ceil(float(tiles.size()) / 2.0 * 3.2)) + 10
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": tiles.size() / 2, "enemies": 0,
		"enemy_problems": [], "par": par}
