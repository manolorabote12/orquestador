extends RefCounted
## Bot del puzle de bloques. En cada jugada prueba todas las piezas de la bandeja en todas las
## casillas y se queda con la mejor segun:
## 1 - Lineas que limpia (y gemas que se lleva).
## 2 - Hueco que deja para las piezas grandes (3x3, 1x5 y 5x1 que aun caben).
## 3 - Casillas sueltas que quedan aisladas (malas: no las llena casi nada).
## 4 - Lo que caben las otras piezas de la bandeja despues de esta.
## Las piezas salen en el mismo orden que a la persona: si el bot gana, el nivel es jugable.


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
		## Sin prisa (fotos, clip): una jugada cada medio segundo, como una persona.
		if not bool(game.get("fast")) and f % 30 != 0:
			continue
		var m: Array = best_move(game)
		if m.is_empty():
			continue
		game.call("place", m[0], m[1])
	return false


static func best_move(game: Node) -> Array:
	var n: int = game.get_script().get_script_constant_map()["N"]
	var pieces: Array = game.get_script().get_script_constant_map()["PIECES"]
	var board: Array = game.get("board")
	var tray: Array = game.get("tray")
	## 1 - Primera pasada: todas las jugadas con la valoracion rapida.
	var cands: Array = []
	for slot: int in 3:
		var p: int = tray[slot]
		if p < 0:
			continue
		for y: int in n:
			for x: int in n:
				if not _fits(board, pieces[p], x, y, n):
					continue
				var b2: Array = _put(board, pieces[p], x, y)
				var res: Vector2i = _clear(b2, n)
				var v: float = _value(b2, res, tray, slot, pieces, n)
				cands.append([v, slot, Vector2i(x, y), b2])
	if cands.is_empty():
		return []
	cands.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	## 2 - Segunda pasada: las 8 mejores, mirando la mejor jugada siguiente con otra pieza.
	var best: Array = [cands[0][1], cands[0][2]]
	var best_v: float = -INF
	for c: Array in cands.slice(0, 8):
		var b2: Array = c[3]
		var follow: float = 0.0
		var any_other: bool = false
		for s2: int in 3:
			var p2: int = tray[s2]
			if s2 == int(c[1]) or p2 < 0:
				continue
			any_other = true
			var bf: float = -1000.0
			for y: int in n:
				for x: int in n:
					if not _fits(b2, pieces[p2], x, y, n):
						continue
					var b3: Array = _put(b2, pieces[p2], x, y)
					var r3: Vector2i = _clear(b3, n)
					var v3: float = 100.0 * float(r3.x) + 70.0 * float(r3.y) - 6.0 * float(_isolated(b3, n)) + 14.0 * float(_count_fits(b3, pieces[18], n) > 0)
					bf = maxf(bf, v3)
			follow += bf
		var total: float = float(c[0]) + (0.6 * follow if any_other else 0.0)
		if total > best_v:
			best_v = total
			best = [c[1], c[2]]
	return best


static func _put(board: Array, piece: Array, x: int, y: int) -> Array:
	var b2: Array = board.duplicate(true)
	for c: Array in piece:
		b2[y + int(c[1])][x + int(c[0])] = 1
	return b2


static func _value(b2: Array, res: Vector2i, tray: Array, slot: int, pieces: Array, n: int) -> float:
	var v: float = 100.0 * float(res.x) + 70.0 * float(res.y)
	v += 14.0 * float(_count_fits(b2, pieces[18], n) > 0) + 9.0 * float(_count_fits(b2, pieces[14], n) > 0) + 9.0 * float(_count_fits(b2, pieces[15], n) > 0)
	v += 2.0 * minf(float(_count_fits(b2, pieces[18], n)), 4.0)
	v -= 6.0 * float(_isolated(b2, n))
	for s2: int in 3:
		if s2 != slot and int(tray[s2]) >= 0 and _count_fits(b2, pieces[tray[s2]], n) == 0:
			v -= 400.0
	v += 1.5 * float(_near_full(b2, n))
	return v


static func _fits(board: Array, piece: Array, x: int, y: int, n: int) -> bool:
	for c: Array in piece:
		var cx: int = x + int(c[0])
		var cy: int = y + int(c[1])
		if cx >= n or cy >= n or int(board[cy][cx]) != 0:
			return false
	return true


static func _count_fits(board: Array, piece: Array, n: int) -> int:
	var k: int = 0
	for y: int in n:
		for x: int in n:
			if _fits(board, piece, x, y, n):
				k += 1
	return k


## Limpia filas y columnas llenas. Devuelve (lineas, gemas).
static func _clear(b: Array, n: int) -> Vector2i:
	var fr: Array[int] = []
	var fc: Array[int] = []
	for y: int in n:
		var full: bool = true
		for x: int in n:
			if int(b[y][x]) == 0:
				full = false
				break
		if full:
			fr.append(y)
	for x: int in n:
		var full2: bool = true
		for y: int in n:
			if int(b[y][x]) == 0:
				full2 = false
				break
		if full2:
			fc.append(x)
	var gems: int = 0
	for y: int in fr:
		for x: int in n:
			if int(b[y][x]) == 2:
				gems += 1
			b[y][x] = 0
	for x: int in fc:
		for y: int in n:
			if int(b[y][x]) == 2:
				gems += 1
			b[y][x] = 0
	return Vector2i(fr.size() + fc.size(), gems)


static func _isolated(b: Array, n: int) -> int:
	var k: int = 0
	for y: int in n:
		for x: int in n:
			if int(b[y][x]) != 0:
				continue
			var free: int = 0
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx >= 0 and ny >= 0 and nx < n and ny < n and int(b[ny][nx]) == 0:
					free += 1
			if free == 0:
				k += 1
	return k


## Celdas ocupadas en filas/columnas con gemas: acercarse a limpiarlas.
static func _near_full(b: Array, n: int) -> int:
	var k: int = 0
	for y: int in n:
		var has_gem: bool = false
		var filled: int = 0
		for x: int in n:
			if int(b[y][x]) == 2:
				has_gem = true
			if int(b[y][x]) != 0:
				filled += 1
		if has_gem:
			k += filled
	for x: int in n:
		var has_gem2: bool = false
		var filled2: int = 0
		for y: int in n:
			if int(b[y][x]) == 2:
				has_gem2 = true
			if int(b[y][x]) != 0:
				filled2 += 1
		if has_gem2:
			k += filled2
	return k
