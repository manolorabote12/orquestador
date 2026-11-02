extends RefCounted
## Analizador del genero a_medida (esqueleto de nuevo_genero.py): comprueba SIN jugar que un nivel
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


## 6 - Generador de niveles (en GDScript: asi un genero hecho a medida no necesita Python).
## Devuelve las filas del mapa del nivel i de n; d = dificultad 0-1; misma semilla, mismo nivel.
## Plantilla: una sola salida abajo en el centro y todas las monedas alcanzables sin pinchos.
static func generate(i: int, n: int, d: float, seed_value: int) -> Array:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + i
	var w: int = 7
	var h: int = 9 + mini(i, 4)
	var start: Vector2i = Vector2i(w / 2, h - 1)
	var keep: Array[Vector2i] = [start, start + Vector2i(0, -1), start + Vector2i(-1, 0), start + Vector2i(1, 0)]
	for attempt: int in 300:
		var g: Array = []
		for y: int in h:
			var row: Array = []
			for x: int in w:
				row.append(".")
			g.append(row)
		g[start.y][start.x] = "P"
		var cells: Array[Vector2i] = []
		for y2: int in h:
			for x2: int in w:
				if not keep.has(Vector2i(x2, y2)):
					cells.append(Vector2i(x2, y2))
		for k: int in range(cells.size() - 1, 0, -1):
			var j: int = rng.randi_range(0, k)
			var tmp: Vector2i = cells[k]
			cells[k] = cells[j]
			cells[j] = tmp
		var n_rocks: int = int(float(w * h) * (0.12 + 0.06 * d))
		var n_spikes: int = maxi(1, 1 + i + int(d * 3.0))
		var n_coins: int = 5 + 2 * mini(i, 4)
		for a: int in n_rocks:
			g[cells[a].y][cells[a].x] = "#"
		for b: int in n_spikes:
			g[cells[n_rocks + b].y][cells[n_rocks + b].x] = "X"
		for c: int in n_coins:
			g[cells[n_rocks + n_spikes + c].y][cells[n_rocks + n_spikes + c].x] = "C"
		var rows: Array[String] = []
		for r: Variant in g:
			rows.append("".join(r as Array))
		if bool(analyze({"map": rows})["completable"]):
			return rows
	var fallback: Array = []
	for y3: int in h:
		fallback.append("C".repeat(w) if y3 == 0 else (".".repeat(w / 2) + "P" + ".".repeat(w - w / 2 - 1) if y3 == h - 1 else ".".repeat(w)))
	return fallback
