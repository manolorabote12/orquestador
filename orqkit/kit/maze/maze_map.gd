extends RefCounted
## Analizador del laberinto: comprueba SIN jugar que un nivel es justo (Genres lo llama).
## Mapa: "#" roca, "." suelo, "P" salida, "C" moneda, "X" pinchos, "L" llave, "D" puerta.
## 1 - Todas las filas miden lo mismo y hay exactamente una salida P.
## 2 - Hay al menos una moneda C. Como mucho una llave; si hay puertas, tiene que haber llave.
## 3 - La llave se alcanza sin cruzar puertas; con la llave, todas las monedas se alcanzan
##     sin pisar rocas (#) ni pinchos (X).
## Mezcla con la serpiente (level.cola = true, giro "cola"): cada casilla que dejas atras se
## cierra. Tiene que existir un camino que recoja todo sin volver a pisar nada (lo busca
## cola_path, con un tope de pasos; el bot sigue ese mismo camino).

const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


static func analyze(level: Dictionary) -> Dictionary:
	var rows: Array[String] = []
	for r: Variant in level.get("map", []):
		rows.append(str(r))
	var issues: Array[String] = []
	var coins: Array[Vector2i] = []
	var starts: Array[Vector2i] = []
	var keys: Array[Vector2i] = []
	var doors: int = 0
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
			elif ch == "L":
				keys.append(Vector2i(x, y))
			elif ch == "D":
				doors += 1
			elif not "#.X".contains(ch):
				if not issues.has("grid_bad_char"):
					issues.append("grid_bad_char")
	if starts.size() != 1:
		issues.append("grid_no_start")
	if coins.is_empty():
		issues.append("grid_no_coins")
	if keys.size() > 1 or (doors > 0 and keys.is_empty()):
		issues.append("maze_bad_key")
	if issues.is_empty():
		var has_key: bool = keys.is_empty()
		if not keys.is_empty():
			has_key = reach(rows, starts[0], false).has(keys[0])
			if not has_key:
				issues.append("maze_key_unreachable")
		var seen: Dictionary = reach(rows, starts[0], has_key)
		for c: Vector2i in coins:
			if not seen.has(c):
				issues.append("grid_unreachable")
				break
	if issues.is_empty() and bool(level.get("cola", false)) and cola_path(rows).is_empty():
		issues.append("maze_cola_impossible")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": coins.size(), "enemies": 0, "enemy_problems": []}


static func walkable(rows: Array[String], c: Vector2i, has_key: bool = true) -> bool:
	if c.y < 0 or c.y >= rows.size() or c.x < 0 or c.x >= rows[c.y].length():
		return false
	var ch: String = rows[c.y][c.x]
	return ch != "#" and ch != "X" and (has_key or ch != "D")


## 4 - Casillas alcanzables desde 'from' (busqueda en anchura). Valor = casilla anterior.
static func reach(rows: Array[String], from: Vector2i, has_key: bool = true) -> Dictionary:
	var prev: Dictionary = {from: from}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for d: Vector2i in DIRS:
			var n: Vector2i = c + d
			if not prev.has(n) and walkable(rows, n, has_key):
				prev[n] = c
				queue.append(n)
	return prev


## 5 - Primer paso del camino mas corto hacia la moneda mas cercana (lo usa el bot).
static func first_step(rows: Array[String], from: Vector2i, targets: Dictionary, has_key: bool = true) -> Vector2i:
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
			if not prev.has(n) and walkable(rows, n, has_key):
				prev[n] = c
				queue.append(n)
	return Vector2i.ZERO


## 6 - Mezcla con la serpiente: camino que recoge todas las monedas (y la llave antes de su
## puerta) sin pisar dos veces la misma casilla. [] si no hay (o si cuesta demasiado buscarlo).
const COLA_BUDGET: int = 60000


static func cola_path(rows: Array[String]) -> Array[Vector2i]:
	var start: Vector2i = Vector2i(-1, -1)
	var coins: Dictionary = {}
	var key: Vector2i = Vector2i(-1, -1)
	for y: int in rows.size():
		for x: int in rows[y].length():
			var ch: String = rows[y][x]
			if ch == "P":
				start = Vector2i(x, y)
			elif ch == "C":
				coins[Vector2i(x, y)] = true
			elif ch == "L":
				key = Vector2i(x, y)
	if start.x < 0:
		return []
	var path: Array[Vector2i] = [start]
	var used: Dictionary = {start: true}
	var budget: Array[int] = [COLA_BUDGET]
	if _cola_dfs(rows, start, used, path, coins.size(), coins, key == Vector2i(-1, -1), key, budget):
		return path
	return []


static func _cola_dfs(rows: Array[String], at: Vector2i, used: Dictionary, path: Array[Vector2i], left: int,
		coins: Dictionary, has_key: bool, key: Vector2i, budget: Array[int]) -> bool:
	if left == 0:
		return true
	budget[0] -= 1
	if budget[0] <= 0:
		return false
	## Poda: si alguna moneda ya no se alcanza por casillas libres, por aqui no.
	var free: Dictionary = _reach_free(rows, at, used, true)
	for c: Vector2i in coins:
		if not used.has(c) and not free.has(c):
			return false
	for d: Vector2i in DIRS:
		var n: Vector2i = at + d
		if used.has(n) or not walkable(rows, n, has_key):
			continue
		used[n] = true
		path.append(n)
		var got: int = 1 if coins.has(n) else 0
		if _cola_dfs(rows, n, used, path, left - got, coins, has_key or n == key, key, budget):
			return true
		path.pop_back()
		used.erase(n)
	return false


static func _reach_free(rows: Array[String], from: Vector2i, used: Dictionary, has_key: bool) -> Dictionary:
	var seen: Dictionary = {from: true}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for d: Vector2i in DIRS:
			var n: Vector2i = c + d
			if not seen.has(n) and not used.has(n) and walkable(rows, n, has_key):
				seen[n] = true
				queue.append(n)
	return seen
