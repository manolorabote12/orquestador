extends RefCounted
## Analizador de la serpiente: comprueba SIN jugar que un nivel es justo.
## 1 - Todas las filas miden lo mismo y solo usan ".#SC"; una salida S como mucho.
## 2 - La salida tiene 3 casillas libres hacia abajo (el cuerpo inicial) y 2 hacia arriba.
## 3 - Todo el suelo esta conectado (ninguna fruta puede caer en un hueco cerrado).
## 4 - El objetivo deja sitio: la serpiente final ocupa como mucho el 35 % del suelo.
## 5 - Ningun callejon sin salida de una casilla.
## Giro "tuneles" (level.wrap): por los huecos del borde se sale por el lado contrario. step() es
## la UNICA regla de movimiento (juego, bot, analizador y fabrica/niveles/generador.py).

const DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]


## Casilla siguiente desde c hacia d. Con tuneles, salir por un borde es entrar por el contrario.
static func step(c: Vector2i, d: Vector2i, w: int, h: int, wrap: bool) -> Vector2i:
	var n: Vector2i = c + d
	if wrap and w > 0 and h > 0:
		n = Vector2i(posmod(n.x, w), posmod(n.y, h))
	return n


static func analyze(level: Dictionary) -> Dictionary:
	var rows: Array[String] = []
	for r: Variant in level.get("map", []):
		rows.append(str(r))
	var issues: Array[String] = []
	var cells: Array[Vector2i] = []
	var starts: Array[Vector2i] = []
	var coins: int = 0
	if rows.size() < 8:
		issues.append("snake_small")
	for y: int in rows.size():
		if rows[y].length() != rows[0].length():
			if not issues.has("snake_bad_rows"):
				issues.append("snake_bad_rows")
			continue
		for x: int in rows[y].length():
			var ch: String = rows[y][x]
			if not ".#SC".contains(ch) and not issues.has("snake_bad_char"):
				issues.append("snake_bad_char")
			if ch != "#":
				cells.append(Vector2i(x, y))
			if ch == "S":
				starts.append(Vector2i(x, y))
			if ch == "C":
				coins += 1
	if starts.size() > 1:
		issues.append("snake_two_starts")
	var wrap: bool = bool(level.get("wrap", false))
	var w: int = rows[0].length() if not rows.is_empty() else 0
	var h: int = rows.size()
	if issues.is_empty():
		var s: Vector2i = starts[0] if not starts.is_empty() else Vector2i(rows[0].length() / 2, rows.size() - 3)
		for k: int in range(-2, 3):
			var c: Vector2i = s + Vector2i(0, k)
			if c.y < 0 or c.y >= rows.size() or rows[c.y][c.x] == "#":
				issues.append("snake_start_blocked")
				break
		var seen: Dictionary = {}
		var q: Array[Vector2i] = []
		if not cells.is_empty():
			seen[cells[0]] = true
			q.append(cells[0])
		while not q.is_empty():
			var c2: Vector2i = q.pop_front()
			for d: Vector2i in DIRS:
				var n: Vector2i = step(c2, d, w, h, wrap)
				if n.x < 0 or n.y < 0 or n.y >= rows.size() or n.x >= rows[0].length() or rows[n.y][n.x] == "#" or seen.has(n):
					continue
				seen[n] = true
				q.append(n)
		if seen.size() != cells.size():
			issues.append("snake_disconnected")
		## 5 - Sin callejones de una casilla (trampas donde la serpiente no puede dar la vuelta).
		for c3: Vector2i in cells:
			var open: int = 0
			for d3: Vector2i in DIRS:
				var m: Vector2i = step(c3, d3, w, h, wrap)
				if m.x >= 0 and m.y >= 0 and m.y < rows.size() and m.x < rows[0].length() and rows[m.y][m.x] != "#":
					open += 1
			if open <= 1:
				issues.append("snake_dead_end")
				break
		if float(3 + int(level.get("goal", 12))) > float(cells.size()) * 0.35:
			issues.append("snake_goal_too_big")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": coins, "enemies": 0, "enemy_problems": []}
