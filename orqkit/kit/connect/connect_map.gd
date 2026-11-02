extends RefCounted
## Conecta 4 contra la maquina: reglas, IA rival (minimax), bot y analizador.
## 1 - Mapa (game.json -> levels[i].map): el tablero de arriba abajo (6 filas de 7 al empezar):
##     "." vacio, "#" casilla tapada (no se puede usar), "R" ficha tuya y "Y" ficha del rival ya
##     puestas.
## 2 - Se suelta la ficha en una columna y cae hasta abajo. Gana quien junte 4 en raya
##     (horizontal, vertical o diagonal). Tablero lleno = empate (cuenta como no ganar).
## Parametros: "depth" (lo que piensa el rival, 1-4), "mistake" (probabilidad de que juegue al
## azar), "first" ("player" o "ai") y "seed".

const W: int = 7
const H: int = 6


static func new_state(level: Dictionary) -> Dictionary:
	var rows: Array = level.get("map", [])
	var g: Array = []
	for y: int in H:
		var row: Array = []
		var s: String = str(rows[y]) if y < rows.size() else "......."
		for x: int in W:
			row.append(s[x] if x < s.length() and s[x] in [".", "#", "R", "Y"] else ".")
		g.append(row)
	return {"g": g, "turn": "R" if str(level.get("first", "player")) == "player" else "Y", "winner": "", "moves": 0,
		"depth": int(level.get("depth", 2)), "mistake": float(level.get("mistake", 0.2)), "seed": int(level.get("seed", 1)), "line": []}


static func drop_row(g: Array, x: int) -> int:
	if x < 0 or x >= W:
		return -1
	for y: int in range(H - 1, -1, -1):
		if str(g[y][x]) == ".":
			return y
	return -1


static func valid(g: Array) -> Array:
	var out: Array = []
	for x: int in [3, 2, 4, 1, 5, 0, 6]:
		if drop_row(g, x) >= 0:
			out.append(x)
	return out


## Las 4 en raya de "p" (lista de casillas) o [].
static func line_of(g: Array, p: String) -> Array:
	for y: int in H:
		for x: int in W:
			for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]:
				var cells: Array = []
				for k: int in 4:
					var c: Vector2i = Vector2i(x, y) + d * k
					if c.x < 0 or c.y < 0 or c.x >= W or c.y >= H or str(g[c.y][c.x]) != p:
						break
					cells.append(c)
				if cells.size() == 4:
					return cells
	return []


static func play(st: Dictionary, x: int) -> bool:
	if str(st["winner"]) != "":
		return false
	var g: Array = st["g"]
	var y: int = drop_row(g, x)
	if y < 0:
		return false
	g[y][x] = st["turn"]
	st["moves"] = int(st["moves"]) + 1
	var line: Array = line_of(g, str(st["turn"]))
	if not line.is_empty():
		st["winner"] = st["turn"]
		st["line"] = line
	elif valid(g).is_empty():
		st["winner"] = "draw"
	st["turn"] = "Y" if str(st["turn"]) == "R" else "R"
	return true


## Valor de una ventana de 4 para "p".
static func _window(a: int, b: int, empty: int) -> int:
	if a == 4:
		return 10000
	if a == 3 and empty == 1:
		return 50
	if a == 2 and empty == 2:
		return 8
	if b == 3 and empty == 1:
		return -60
	return 0


static var _wins: Array = []


## Las 69 ventanas de 4 del tablero (se calculan una vez).
static func _windows() -> Array:
	if _wins.is_empty():
		for y: int in H:
			for x: int in W:
				for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]:
					var e: Vector2i = Vector2i(x, y) + d * 3
					if e.x < 0 or e.y < 0 or e.x >= W or e.y >= H:
						continue
					var cells: Array = []
					for k: int in 4:
						cells.append(Vector2i(x, y) + d * k)
					_wins.append(cells)
	return _wins


static func evaluate(g: Array, p: String) -> int:
	var score: int = 0
	for y: int in H:
		if str(g[y][3]) == p:
			score += 4
	for cells: Array in _windows():
		var a: int = 0
		var b: int = 0
		var em: int = 0
		for c: Vector2i in cells:
			var ch: String = g[c.y][c.x]
			if ch == p:
				a += 1
			elif ch == ".":
				em += 1
			elif ch != "#":
				b += 1
		if a + em == 4 or b + em == 4:
			score += _window(a, b, em)
	return score


## Hace 4 en raya la ficha recien puesta en (x, y)?
static func wins_at(g: Array, x: int, y: int, p: String) -> bool:
	for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]:
		var n: int = 1
		for sgn: int in [1, -1]:
			var c: Vector2i = Vector2i(x, y) + d * sgn
			while c.x >= 0 and c.y >= 0 and c.x < W and c.y < H and str(g[c.y][c.x]) == p:
				n += 1
				c += d * sgn
		if n >= 4:
			return true
	return false


static func _minimax(g: Array, depth: int, alpha: int, beta: int, maxing: bool, p: String) -> int:
	var o: String = "Y" if p == "R" else "R"
	var moves: Array = valid(g)
	if depth == 0 or moves.is_empty():
		return evaluate(g, p)
	var a: int = alpha
	var b: int = beta
	var me: String = p if maxing else o
	var best: int = -1000000 if maxing else 1000000
	for x: int in moves:
		var y: int = drop_row(g, x)
		g[y][x] = me
		var v: int
		if wins_at(g, x, y, me):
			v = (100000 + depth) if maxing else (-100000 - depth)
		else:
			v = _minimax(g, depth - 1, a, b, not maxing, p)
		g[y][x] = "."
		if maxing:
			best = maxi(best, v)
			a = maxi(a, best)
		else:
			best = mini(best, v)
			b = mini(b, best)
		if a >= b:
			break
	return best


static func best_move(g: Array, p: String, depth: int) -> int:
	var best_x: int = -1
	var best_v: int = -10000000
	for x: int in valid(g):
		var y: int = drop_row(g, x)
		g[y][x] = p
		var v: int = 1000000 if wins_at(g, x, y, p) else _minimax(g, depth - 1, -10000000, 10000000, false, p)
		g[y][x] = "."
		if v > best_v:
			best_v = v
			best_x = x
	return best_x


## Jugada del rival: piensa "depth" jugadas; a veces se equivoca (sale de la semilla).
static func ai_move(st: Dictionary) -> int:
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.seed = int(st["seed"]) * 7919 + int(st["moves"]) * 31
	var moves: Array = valid(st["g"])
	if moves.is_empty():
		return -1
	if r.randf() < float(st["mistake"]):
		## Aun equivocandose, nunca deja escapar una victoria en una.
		for x: int in moves:
			var y: int = drop_row(st["g"], x)
			st["g"][y][x] = "Y"
			var win: bool = wins_at(st["g"], x, y, "Y")
			st["g"][y][x] = "."
			if win:
				return x
		return int(moves[r.randi_range(0, moves.size() - 1)])
	return best_move(st["g"], "Y", maxi(1, int(st["depth"])))


## El bot (el jugador) piensa 5 jugadas.
static func bot_move(st: Dictionary) -> int:
	return best_move(st["g"], "R", 5)


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var rows: Array = level.get("map", [])
	if rows.size() != H:
		issues.append("connect_size")
	for r: Variant in rows:
		if str(r).length() != W:
			issues.append("connect_size")
			break
	var par: int = 0
	if issues.is_empty():
		var st: Dictionary = new_state(level)
		if not line_of(st["g"], "R").is_empty() or not line_of(st["g"], "Y").is_empty():
			issues.append("connect_already_won")
		else:
			var guard: int = 0
			while str(st["winner"]) == "" and guard < 60:
				guard += 1
				if str(st["turn"]) == "R":
					play(st, bot_move(st))
				else:
					play(st, ai_move(st))
			if str(st["winner"]) != "R":
				issues.append("connect_too_hard")
			par = int(st["moves"])
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": 1, "enemies": 0, "enemy_problems": [], "par": par}
