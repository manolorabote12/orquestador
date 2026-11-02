extends RefCounted
## Damas contra la maquina: reglas (captura obligatoria, saltos encadenados, coronar), IA rival
## (minimax), bot y analizador.
## 1 - Mapa (game.json -> levels[i].map): el tablero de 8x8 de arriba abajo: "." casilla,
##     "w" ficha tuya, "W" dama tuya, "b" ficha rival, "B" dama rival. Tus fichas suben.
## 2 - Las fichas se mueven en diagonal hacia delante; si puedes comer, tienes que comer (y seguir
##     comiendo con la misma ficha). Al llegar al final se coronan: la dama va hacia atras tambien.
## 3 - Gana quien deja al otro sin fichas o sin movimientos.
## Parametros: "depth" (lo que piensa el rival, 1-4), "mistake" (probabilidad de jugar al azar)
## y "seed".

const N: int = 8
const MAX_MOVES: int = 160


static func new_state(level: Dictionary) -> Dictionary:
	var rows: Array = level.get("map", [])
	var g: Array = []
	for y: int in N:
		var row: Array = []
		var s: String = str(rows[y]) if y < rows.size() else "........"
		for x: int in N:
			row.append(s[x] if x < s.length() and s[x] in ["w", "W", "b", "B"] else ".")
		g.append(row)
	return {"g": g, "turn": "w", "winner": "", "moves": 0, "depth": int(level.get("depth", 2)), "mistake": float(level.get("mistake", 0.2)),
		"seed": int(level.get("seed", 1)), "captured": {"w": 0, "b": 0}}


static func side_of(ch: String) -> String:
	return ch.to_lower() if ch != "." else ""


static func _dirs(ch: String) -> Array:
	if ch == "W" or ch == "B":
		return [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]
	return [Vector2i(-1, -1), Vector2i(1, -1)] if ch == "w" else [Vector2i(-1, 1), Vector2i(1, 1)]


static func _in(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < N and c.y < N


## Saltos encadenados desde "from" (lista de caminos: [desde, a1, a2...] y las comidas).
static func _jumps(g: Array, from: Vector2i, ch: String, eaten: Array) -> Array:
	var out: Array = []
	var me: String = side_of(ch)
	for d: Vector2i in _dirs(ch):
		var mid: Vector2i = from + d
		var to: Vector2i = from + d * 2
		if not _in(to) or str(g[to.y][to.x]) != ".":
			continue
		var m: String = str(g[mid.y][mid.x])
		if m == "." or side_of(m) == me or eaten.has(mid):
			continue
		var e2: Array = eaten.duplicate()
		e2.append(mid)
		## Corona al llegar: el salto se acaba ahi.
		var crowned: bool = (ch == "w" and to.y == 0) or (ch == "b" and to.y == N - 1)
		g[from.y][from.x] = "."
		g[to.y][to.x] = ch
		var more: Array = [] if crowned else _jumps(g, to, ch, e2)
		g[to.y][to.x] = "."
		g[from.y][from.x] = ch
		if more.is_empty():
			out.append({"path": [from, to], "eat": e2})
		else:
			for mv: Dictionary in more:
				var p: Array = [from]
				p.append_array(mv["path"])
				out.append({"path": p, "eat": mv["eat"]})
	return out


## Todas las jugadas legales del bando: {"path": [casillas], "eat": [comidas]}. Comer es obligatorio.
static func moves_of(g: Array, side: String) -> Array:
	var jumps: Array = []
	var steps: Array = []
	for y: int in N:
		for x: int in N:
			var ch: String = str(g[y][x])
			if side_of(ch) != side:
				continue
			var c: Vector2i = Vector2i(x, y)
			for j: Dictionary in _jumps(g, c, ch, []):
				var p: Array = j["path"]
				## _jumps devuelve [from, to, ...] con from repetido al encadenar: lo limpiamos.
				var clean: Array = []
				for q: Variant in p:
					if clean.is_empty() or clean[clean.size() - 1] != q:
						clean.append(q)
				jumps.append({"path": clean, "eat": j["eat"]})
			if jumps.is_empty():
				for d: Vector2i in _dirs(ch):
					var to: Vector2i = c + d
					if _in(to) and str(g[to.y][to.x]) == ".":
						steps.append({"path": [c, to], "eat": []})
	return jumps if not jumps.is_empty() else steps


static func apply(g: Array, mv: Dictionary) -> void:
	var p: Array = mv["path"]
	var a: Vector2i = p[0]
	var b: Vector2i = p[p.size() - 1]
	var ch: String = str(g[a.y][a.x])
	g[a.y][a.x] = "."
	for e: Vector2i in mv["eat"]:
		g[e.y][e.x] = "."
	if ch == "w" and b.y == 0:
		ch = "W"
	elif ch == "b" and b.y == N - 1:
		ch = "B"
	g[b.y][b.x] = ch


static func play(st: Dictionary, mv: Dictionary) -> bool:
	if str(st["winner"]) != "":
		return false
	apply(st["g"], mv)
	st["captured"][st["turn"]] = int(st["captured"][st["turn"]]) + (mv["eat"] as Array).size()
	st["moves"] = int(st["moves"]) + 1
	st["turn"] = "b" if str(st["turn"]) == "w" else "w"
	if moves_of(st["g"], str(st["turn"])).is_empty():
		st["winner"] = "b" if str(st["turn"]) == "w" else "w"
	elif int(st["moves"]) >= MAX_MOVES:
		st["winner"] = "draw"
	return true


static func evaluate(g: Array, side: String) -> int:
	var s: int = 0
	for y: int in N:
		for x: int in N:
			var ch: String = str(g[y][x])
			if ch == ".":
				continue
			var v: int = 30 if ch == "W" or ch == "B" else 10
			## Avanzar y el centro valen un poco.
			if ch == "w":
				v += (N - 1 - y)
			elif ch == "b":
				v += y
			if x >= 2 and x <= 5:
				v += 1
			s += v if side_of(ch) == side else -v
	return s


static func _minimax(g: Array, depth: int, a: int, b: int, side: String, me: String) -> int:
	var moves: Array = moves_of(g, side)
	if moves.is_empty():
		return -10000 - depth if side == me else 10000 + depth
	if depth == 0:
		return evaluate(g, me)
	var other: String = "b" if side == "w" else "w"
	var maxing: bool = side == me
	var best: int = -1000000 if maxing else 1000000
	for mv: Dictionary in moves:
		var copy: Array = []
		for row: Variant in g:
			copy.append((row as Array).duplicate())
		apply(copy, mv)
		var v: int = _minimax(copy, depth - 1, a, b, other, me)
		if maxing:
			best = maxi(best, v)
			a = maxi(a, best)
		else:
			best = mini(best, v)
			b = mini(b, best)
		if a >= b:
			break
	return best


static func best_move(g: Array, side: String, depth: int) -> Dictionary:
	var moves: Array = moves_of(g, side)
	var other: String = "b" if side == "w" else "w"
	var best: Dictionary = moves[0] if not moves.is_empty() else {}
	var best_v: int = -10000000
	for mv: Dictionary in moves:
		var copy: Array = []
		for row: Variant in g:
			copy.append((row as Array).duplicate())
		apply(copy, mv)
		var v: int = _minimax(copy, depth - 1, -10000000, 10000000, other, side)
		if v > best_v:
			best_v = v
			best = mv
	return best


static func ai_move(st: Dictionary) -> Dictionary:
	var moves: Array = moves_of(st["g"], "b")
	if moves.is_empty():
		return {}
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.seed = int(st["seed"]) * 7919 + int(st["moves"]) * 31
	if r.randf() < float(st["mistake"]):
		return moves[r.randi_range(0, moves.size() - 1)]
	return best_move(st["g"], "b", maxi(1, int(st["depth"])))


static func bot_move(st: Dictionary) -> Dictionary:
	return best_move(st["g"], "w", 4)


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var rows: Array = level.get("map", [])
	if rows.size() != N:
		issues.append("checkers_size")
	var st: Dictionary = new_state(level)
	if moves_of(st["g"], "w").is_empty() or moves_of(st["g"], "b").is_empty():
		issues.append("checkers_no_moves")
	var par: int = 0
	if issues.is_empty():
		var guard: int = 0
		while str(st["winner"]) == "" and guard < MAX_MOVES + 2:
			guard += 1
			if str(st["turn"]) == "w":
				play(st, bot_move(st))
			else:
				play(st, ai_move(st))
		if str(st["winner"]) != "w":
			issues.append("checkers_too_hard")
		par = int(st["moves"])
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": 1, "enemies": 0, "enemy_problems": [], "par": par}
