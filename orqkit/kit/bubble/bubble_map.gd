extends RefCounted
## Burbujas (bubble shooter): las reglas, la fisica del disparo y el analizador. El juego, el bot
## y el analizador usan EXACTAMENTE estas funciones (lo que calcula el bot es lo que pasa).
## Tablero hexagonal: filas de W burbujas (las impares, desplazadas media burbuja, de W - 1).
## Mapa (game.json -> levels[i].map): una fila por texto, de arriba abajo; "." hueco y a..f colores.
## Parametros: "shots" (disparos), "seed" (orden de los colores que salen), "lose_row" (si una
## burbuja queda en esa fila o mas abajo, se pierde).
## Reglas:
## 1 - El disparo sale de abajo en el centro, rebota en las paredes y se pega a la primera burbuja
##     que toca (o al techo), en el hueco libre mas cercano.
## 2 - Si junta 3 o mas del mismo color, explotan; las que quedan sueltas (sin camino al techo) caen.
## 3 - El color siguiente sale de los colores que quedan en el tablero, en un orden fijo (seed).
## 4 - Se gana al vaciar el tablero; se pierde sin disparos o si se llega a la fila lose_row.
## Analizador:
## 5 - Filas validas (W y W - 1 alternadas), de 2 a 6 colores, ninguna en la fila de perder.
## 6 - El bot (mismas reglas, mira el disparo actual) lo vacia con los disparos del nivel.

const W: int = 8
const ROW_H: float = 0.8660254
const STEP: float = 0.12
const ANGLES: int = 61
const MAX_ANGLE: float = 1.31
const COLORS: String = "abcdef"


static func row_len(r: int) -> int:
	return W if r % 2 == 0 else W - 1


static func center(r: int, c: int) -> Vector2:
	return Vector2(float(c) + (1.0 if r % 2 == 1 else 0.5), float(r) * ROW_H + 0.5)


static func launcher(rows_total: int) -> Vector2:
	return Vector2(float(W) * 0.5, float(rows_total) * ROW_H + 1.6)


## Tablero: Dictionary Vector2i(fila, col) -> color (String).
static func parse(level: Dictionary) -> Dictionary:
	var g: Dictionary = {}
	var rows: Array = level.get("map", [])
	for r: int in rows.size():
		var s: String = str(rows[r])
		for c: int in mini(s.length(), row_len(r)):
			if s[c] != ".":
				g[Vector2i(r, c)] = s[c]
	return g


static func neighbors(cell: Vector2i) -> Array[Vector2i]:
	var r: int = cell.x
	var c: int = cell.y
	var out: Array[Vector2i] = [Vector2i(r, c - 1), Vector2i(r, c + 1)]
	if r % 2 == 0:
		out.append_array([Vector2i(r - 1, c - 1), Vector2i(r - 1, c), Vector2i(r + 1, c - 1), Vector2i(r + 1, c)])
	else:
		out.append_array([Vector2i(r - 1, c), Vector2i(r - 1, c + 1), Vector2i(r + 1, c), Vector2i(r + 1, c + 1)])
	var ok: Array[Vector2i] = []
	for n: Vector2i in out:
		if n.x >= 0 and n.y >= 0 and n.y < row_len(n.x):
			ok.append(n)
	return ok


static func _near(g: Dictionary, p: Vector2) -> bool:
	if p.y <= 0.5:
		return true
	var r0: int = int(floor((p.y - 0.5) / ROW_H))
	for r: int in range(r0 - 1, r0 + 2):
		if r < 0:
			continue
		var c0: int = int(floor(p.x - (1.0 if r % 2 == 1 else 0.5)))
		for c: int in range(c0 - 1, c0 + 2):
			if g.has(Vector2i(r, c)) and center(r, c).distance_to(p) < 0.88:
				return true
	return false


## 1 - Trayectoria de un disparo: [puntos del camino (para dibujarlo), casilla donde se pega].
## Casilla (-1, -1) si no hay sitio (no deberia pasar).
static func trace(g: Dictionary, rows_total: int, angle: float) -> Array:
	var p: Vector2 = launcher(rows_total)
	var d: Vector2 = Vector2(sin(angle), -cos(angle))
	var pts: PackedVector2Array = PackedVector2Array([p])
	for i: int in 2000:
		p += d * STEP
		if p.x < 0.5:
			p.x = 1.0 - p.x
			d.x = -d.x
			pts.append(p)
		elif p.x > float(W) - 0.5:
			p.x = 2.0 * (float(W) - 0.5) - p.x
			d.x = -d.x
			pts.append(p)
		if _near(g, p):
			break
	pts.append(p)
	return [pts, snap(g, p)]


## Hueco libre mas cercano a p que este pegado al techo o a otra burbuja.
static func snap(g: Dictionary, p: Vector2) -> Vector2i:
	var best: Vector2i = Vector2i(-1, -1)
	var best_d: float = INF
	var r0: int = int(round((p.y - 0.5) / ROW_H))
	for r: int in range(maxi(r0 - 1, 0), r0 + 2):
		for c: int in row_len(r):
			var cell: Vector2i = Vector2i(r, c)
			if g.has(cell):
				continue
			var held: bool = r == 0
			if not held:
				for n: Vector2i in neighbors(cell):
					if g.has(n):
						held = true
						break
			if not held:
				continue
			var dd: float = center(r, c).distance_to(p)
			if dd < best_d:
				best_d = dd
				best = cell
	return best


## 2 - Pega la burbuja y resuelve: [tablero nuevo, explotadas, caidas].
static func place(g: Dictionary, cell: Vector2i, color: String) -> Array:
	var b: Dictionary = g.duplicate()
	if cell.x < 0:
		return [b, 0, 0]
	b[cell] = color
	var group: Array[Vector2i] = [cell]
	var seen: Dictionary = {cell: true}
	var i: int = 0
	while i < group.size():
		for n: Vector2i in neighbors(group[i]):
			if not seen.has(n) and b.get(n, "") == color:
				seen[n] = true
				group.append(n)
		i += 1
	if group.size() < 3:
		return [b, 0, 0]
	for q: Vector2i in group:
		b.erase(q)
	## Lo que no tiene camino al techo cae.
	var held: Dictionary = {}
	var stack: Array[Vector2i] = []
	for k: Variant in b:
		var kc: Vector2i = k
		if kc.x == 0:
			held[kc] = true
			stack.append(kc)
	while not stack.is_empty():
		var q2: Vector2i = stack.pop_back()
		for n2: Vector2i in neighbors(q2):
			if b.has(n2) and not held.has(n2):
				held[n2] = true
				stack.append(n2)
	var dropped: int = 0
	for k2: Variant in b.keys():
		if not held.has(k2):
			b.erase(k2)
			dropped += 1
	return [b, group.size(), dropped]


## 3 - Color del disparo n: de los que quedan, en un orden fijo por la semilla.
static func next_color(g: Dictionary, seed_v: int, n: int) -> String:
	var left: Array[String] = []
	for k: Variant in g:
		var col: String = g[k]
		if not left.has(col):
			left.append(col)
	if left.is_empty():
		return "a"
	left.sort()
	var h: int = absi(int(hash(seed_v * 7919 + n * 104729)))
	return left[h % left.size()]


static func angle_of(i: int) -> float:
	return -MAX_ANGLE + 2.0 * MAX_ANGLE * float(i) / float(ANGLES - 1)


static func lowest_row(g: Dictionary) -> int:
	var m: int = -1
	for k: Variant in g:
		m = maxi(m, (k as Vector2i).x)
	return m


## 4 - Disparo que elige el bot: lo que mas explota y tira; si nada explota, junto a su color y
## lo mas arriba posible. Devuelve el angulo.
static func best_angle(g: Dictionary, rows_total: int, color: String) -> float:
	var best: float = 0.0
	var best_s: float = -INF
	var tried: Dictionary = {}
	for i: int in ANGLES:
		var a: float = angle_of(i)
		var cell: Vector2i = trace(g, rows_total, a)[1]
		if cell.x < 0 or tried.has(cell):
			continue
		tried[cell] = true
		var r: Array = place(g, cell, color)
		var s: float = float(int(r[1]) * 10 + int(r[2]) * 14)
		if int(r[1]) == 0:
			for n: Vector2i in neighbors(cell):
				if g.get(n, "") == color:
					s += 3.0
		s -= float(cell.x) * 0.5
		if s > best_s:
			best_s = s
			best = a
	return best


## Partida del bot en la cabeza: disparos para vaciar el tablero (0 si no lo consigue).
static func bot_shots(level: Dictionary) -> int:
	var g: Dictionary = parse(level)
	var rows_total: int = int(level.get("lose_row", 12))
	var shots: int = int(level.get("shots", 30))
	var seed_v: int = int(level.get("seed", 1))
	for n: int in shots:
		if g.is_empty():
			return n
		var col: String = next_color(g, seed_v, n)
		var cell: Vector2i = trace(g, rows_total, best_angle(g, rows_total, col))[1]
		g = place(g, cell, col)[0]
		if lowest_row(g) >= rows_total:
			return 0
	return shots if g.is_empty() else 0


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var rows: Array = level.get("map", [])
	var lose: int = int(level.get("lose_row", 12))
	if rows.is_empty() or rows.size() >= lose:
		issues.append("bubble_rows")
	var colors: Dictionary = {}
	for r: int in rows.size():
		var s: String = str(rows[r])
		if s.length() != row_len(r) and not issues.has("bubble_bad_row"):
			issues.append("bubble_bad_row")
		for ch: String in s:
			if ch == ".":
				continue
			if not COLORS.contains(ch):
				if not issues.has("bubble_bad_char"):
					issues.append("bubble_bad_char")
				continue
			colors[ch] = true
	if colors.size() < 2 or colors.size() > 6:
		issues.append("bubble_colors")
	var used: int = 0
	if issues.is_empty():
		used = bot_shots(level)
		if used == 0:
			issues.append("bubble_too_hard")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": parse(level).size(), "enemies": 0, "enemy_problems": [],
		"bot_shots": used}
