extends RefCounted
## Analizador del genero __ES__ (esqueleto de nuevo_genero.py): comprueba SIN jugar que un nivel
## es justo. El validador de la fabrica lo llama con analyze(level) a traves de Genres.
## Reglas de la plantilla (cambialas junto con las del juego):
## 1 - Todas las filas miden lo mismo y hay exactamente una salida P.
## 2 - Hay al menos una moneda C.
## 3 - Todas las monedas se alcanzan desde la salida sin pisar rocas (#) ni pinchos (X).

const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


static func analyze(level: Dictionary) -> Dictionary:
	var rows: Array[String] = []
	for r: Variant in level.get("map", []):
		rows.append(str(r))
	var issues: Array[String] = []
	var coins: Array[Vector2i] = []
	var starts: Array[Vector2i] = []
	if rows.is_empty():
		issues.append("grid_empty")
	for y: int in rows.size():
		if rows[y].length() != rows[0].length():
			if not issues.has("grid_bad_rows"):
				issues.append("grid_bad_rows")
			continue
		for x: int in rows[y].length():
			var ch: String = rows[y][x]
			if ch == "C":
				coins.append(Vector2i(x, y))
			elif ch == "P":
				starts.append(Vector2i(x, y))
			elif not "#.X".contains(ch):
				if not issues.has("grid_bad_char"):
					issues.append("grid_bad_char")
	if starts.size() != 1:
		issues.append("grid_no_start")
	if coins.is_empty():
		issues.append("grid_no_coins")
	if issues.is_empty():
		var seen: Dictionary = reach(rows, starts[0])
		for c: Vector2i in coins:
			if not seen.has(c):
				issues.append("grid_unreachable")
				break
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": coins.size(), "enemies": 0, "enemy_problems": []}


static func walkable(rows: Array[String], c: Vector2i) -> bool:
	if c.y < 0 or c.y >= rows.size() or c.x < 0 or c.x >= rows[c.y].length():
		return false
	var ch: String = rows[c.y][c.x]
	return ch != "#" and ch != "X"


## 4 - Casillas alcanzables desde 'from' (busqueda en anchura). Valor = casilla anterior.
static func reach(rows: Array[String], from: Vector2i) -> Dictionary:
	var prev: Dictionary = {from: from}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for d: Vector2i in DIRS:
			var n: Vector2i = c + d
			if not prev.has(n) and walkable(rows, n):
				prev[n] = c
				queue.append(n)
	return prev


## 5 - Primer paso del camino mas corto hacia la moneda mas cercana (lo usa el bot).
static func first_step(rows: Array[String], from: Vector2i, targets: Dictionary) -> Vector2i:
	var prev: Dictionary = {from: from}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if targets.has(c) and c != from:
			var step: Vector2i = c
			while prev[step] != from:
				step = prev[step]
			return step - from
		for d: Vector2i in DIRS:
			var n: Vector2i = c + d
			if not prev.has(n) and walkable(rows, n):
				prev[n] = c
				queue.append(n)
	return Vector2i.ZERO
