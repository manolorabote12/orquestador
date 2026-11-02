extends RefCounted
## Fusion: las reglas del tablero, el bot y el analizador (los tres usan las MISMAS funciones).
## Tablero de W x H casillas; 0 = vacia, v = pieza de valor 2^v. Se suelta una pieza en una
## columna, cae hasta abajo y se junta con las vecinas iguales: la pieza sube un valor por cada
## vecina que se come. Las fusiones encadenan.
## Mapa: H filas de W caracteres: "." vacia o "1".."9" (pieza que ya esta al empezar).
## Giro "piedras": "#" piedra (valor -1). No se junta con nada; se rompe cuando hay una fusion
## justo al lado.
## Parametros: "goal" (valor que hay que conseguir), "seq" (piezas que van saliendo, en bucle)
## y "par_moves" (jugadas del bot: para las estrellas).
## 1 - Filas iguales, caracteres validos, secuencia con piezas de 1 a 4.
## 2 - Jugando como el bot (mirando la pieza actual y la siguiente) se llega a la meta.

const MAX_MOVES: int = 400


static func parse(level: Dictionary) -> Array:
	var rows: Array[String] = []
	for r: Variant in level.get("map", []):
		rows.append(str(r))
	var h: int = rows.size()
	var w: int = rows[0].length() if h > 0 else 0
	var cells: Array[int] = []
	for y: int in h:
		for x: int in w:
			var ch: String = rows[y][x] if x < rows[y].length() else "."
			cells.append(-1 if ch == "#" else (int(ch) if ch >= "1" and ch <= "9" else 0))
	return [w, h, cells]


static func seq_of(level: Dictionary) -> Array[int]:
	var out: Array[int] = []
	for v: Variant in level.get("seq", [1, 2, 1, 3]):
		out.append(clampi(int(v), 1, 9))
	return out


static func top_free(cells: Array[int], w: int, h: int, col: int) -> int:
	for y: int in range(h - 1, -1, -1):
		if cells[y * w + col] == 0:
			return y
	return -1


static func _gravity(cells: Array[int], w: int, h: int, focus: int) -> int:
	var f: int = focus
	for x: int in w:
		var write: int = h - 1
		for y: int in range(h - 1, -1, -1):
			var v: int = cells[y * w + x]
			if v == 0:
				continue
			if write != y:
				cells[write * w + x] = v
				cells[y * w + x] = 0
				if f == y * w + x:
					f = write * w + x
			write -= 1
	return f


## 3 - Suelta 'value' en 'col'. Devuelve [tablero nuevo, fusiones, casilla final] o [] si la
## columna esta llena. Regla de fusion: la casilla que acaba de cambiar se come a sus vecinas
## iguales (izquierda, derecha, abajo, arriba); si no tiene, se busca cualquier pareja igual
## (de abajo arriba, de izquierda a derecha) y la de abajo se come a la de arriba.
static func drop(cells: Array[int], w: int, h: int, col: int, value: int) -> Array:
	var y0: int = top_free(cells, w, h, col)
	if y0 < 0:
		return []
	var b: Array[int] = cells.duplicate()
	var focus: int = y0 * w + col
	b[focus] = value
	var merges: int = 0
	var broken: int = 0
	for guard: int in 64:
		var fx: int = focus % w
		var fy: int = focus / w
		var eaten: int = 0
		for d: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = fx + d.x
			var ny: int = fy + d.y
			if nx < 0 or nx >= w or ny < 0 or ny >= h:
				continue
			if b[ny * w + nx] == b[focus] and b[focus] > 0:
				b[ny * w + nx] = 0
				eaten += 1
		if eaten > 0:
			b[focus] += eaten
			merges += eaten
			focus = _gravity(b, w, h, focus)
			## Piedras pegadas a la pieza que acaba de crecer: se rompen (y lo de encima cae).
			var hit: int = 0
			for d2: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var sx: int = focus % w + d2.x
				var sy: int = focus / w + d2.y
				if sx >= 0 and sx < w and sy >= 0 and sy < h and b[sy * w + sx] == -1:
					b[sy * w + sx] = 0
					hit += 1
			if hit > 0:
				broken += hit
				focus = _gravity(b, w, h, focus)
			continue
		var found: int = -1
		for y: int in range(h - 1, -1, -1):
			for x: int in w:
				var v: int = b[y * w + x]
				if v <= 0:
					continue
				if (x + 1 < w and b[y * w + x + 1] == v) or (y > 0 and b[(y - 1) * w + x] == v):
					found = y * w + x
					break
			if found >= 0:
				break
		if found < 0:
			break
		focus = found
	return [b, merges, focus, broken]


static func max_value(cells: Array[int]) -> int:
	var m: int = 0
	for v: int in cells:
		m = maxi(m, v)
	return m


## 4 - Lo que le gusta al bot (entero, sin empates raros): valor alto, sitio libre, poco escalon.
static func score(cells: Array[int], w: int, h: int) -> int:
	var empty: int = 0
	var stones: int = 0
	var rough: int = 0
	var tallest: int = 0
	for x: int in w:
		var height: int = 0
		for y: int in h:
			var v: int = cells[y * w + x]
			if v == -1:
				stones += 1
			if v == 0:
				empty += 1
			else:
				height = maxi(height, h - y)
				if x + 1 < w and cells[y * w + x + 1] > 0 and absi(cells[y * w + x + 1] - v) >= 3:
					rough += 1
				if y + 1 < h and cells[(y + 1) * w + x] > 0 and cells[(y + 1) * w + x] < v:
					rough += 1
		tallest = maxi(tallest, height)
	return max_value(cells) * 1000 + empty * 20 - rough * 12 - tallest * 6 - stones * 25


## 5 - Columna que elige el bot mirando la pieza actual y la siguiente (-1 = no cabe en ninguna).
static func best_column(cells: Array[int], w: int, h: int, now: int, next: int) -> int:
	var best: int = -1
	var best_s: int = -1000000000
	for c1: int in w:
		var r1: Array = drop(cells, w, h, c1, now)
		if r1.is_empty():
			continue
		var b1: Array[int] = r1[0]
		var s: int = -500000 + score(b1, w, h)
		for c2: int in w:
			var r2: Array = drop(b1, w, h, c2, next)
			if r2.is_empty():
				continue
			s = maxi(s, score(r2[0], w, h))
		if s > best_s:
			best_s = s
			best = c1
	return best


## 6 - Partida del bot en la cabeza: jugadas para llegar a 'goal' (0 = no llega).
static func bot_moves(cells: Array[int], w: int, h: int, seq: Array[int], goal: int) -> int:
	var b: Array[int] = cells.duplicate()
	for m: int in MAX_MOVES:
		if max_value(b) >= goal:
			return m
		var now: int = seq[m % seq.size()]
		var nxt: int = seq[(m + 1) % seq.size()]
		var c: int = best_column(b, w, h, now, nxt)
		if c < 0:
			return 0
		b = drop(b, w, h, c, now)[0]
	return 0


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var rows: Array = level.get("map", [])
	if rows.is_empty():
		issues.append("grid_empty")
	for r: Variant in rows:
		var s: String = str(r)
		if s.length() != str(rows[0]).length():
			if not issues.has("grid_bad_rows"):
				issues.append("grid_bad_rows")
		for ch: String in s:
			if ch != "." and ch != "#" and not (ch >= "1" and ch <= "9"):
				if not issues.has("grid_bad_char"):
					issues.append("grid_bad_char")
	var seq: Array[int] = seq_of(level)
	for v: int in seq:
		if v > 4:
			issues.append("merge_bad_seq")
			break
	var goal: int = int(level.get("goal", 6))
	var moves: int = 0
	if issues.is_empty():
		var p: Array = parse(level)
		moves = bot_moves(p[2], p[0], p[1], seq, goal)
		if moves == 0:
			issues.append("merge_too_hard")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": 0, "enemies": 0, "enemy_problems": [],
		"bot_moves": moves}
