extends RefCounted
## Reversi contra la maquina. Juegas con negras (empiezas). Pones una ficha que encierre fichas
## del rival en linea (horizontal, vertical o diagonal) y se dan la vuelta. Si no puedes poner,
## pasas; cuando nadie puede, gana quien tenga mas fichas (empate = no ganada).
## Nivel: "size" (6 u 8), "rival" (profundidad 1 a 3), "mistake" (probabilidad de jugada al azar),
## "seed" y "bonus" (casillas de esquina que ya son tuyas al empezar: ventaja para aprender, 0 a 2).
## Tablero: Array de size*size; 0 vacia, 1 tuya (negras), 2 del rival (blancas).

const Rules = preload("res://kit/rules.gd")
const DIRS: Array = [[-1, -1], [0, -1], [1, -1], [-1, 0], [1, 0], [-1, 1], [0, 1], [1, 1]]


static func new_state(level: Dictionary) -> Dictionary:
	var n: int = 8 if int(level.get("size", 8)) >= 8 else 6
	var b: Array = []
	b.resize(n * n)
	b.fill(0)
	var h: int = n / 2
	b[(h - 1) * n + h - 1] = 2
	b[h * n + h] = 2
	b[(h - 1) * n + h] = 1
	b[h * n + h - 1] = 1
	var corners: Array = [0, n * n - 1, n - 1, n * (n - 1)]
	for k: int in clampi(int(level.get("bonus", 0)), 0, 2):
		b[corners[k]] = 1
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(level.get("seed", 1))
	var st: Dictionary = {"b": b, "n": n, "turn": 1, "plies": 0, "passes": 0, "rival": clampi(int(level.get("rival", 1)), 1, 3),
		"mistake": clampf(float(level.get("mistake", 0.0)), 0.0, 0.6), "last": -1, "flipped": [], "won": false, "lost": false,
		"draw": false, "rng": rng}
	st["rules"] = Rules.load_rules(level)
	Rules.hook(st, "on_start")
	return st


## Fichas que se darian la vuelta al poner en i (vacio si no vale).
static func flips(b: Array, n: int, i: int, who: int) -> Array:
	if b[i] != 0:
		return []
	var out: Array = []
	var x: int = i % n
	var y: int = i / n
	var other: int = 3 - who
	for d: Variant in DIRS:
		var line: Array = []
		var cx: int = x + int(d[0])
		var cy: int = y + int(d[1])
		while cx >= 0 and cx < n and cy >= 0 and cy < n and b[cy * n + cx] == other:
			line.append(cy * n + cx)
			cx += int(d[0])
			cy += int(d[1])
		if not line.is_empty() and cx >= 0 and cx < n and cy >= 0 and cy < n and b[cy * n + cx] == who:
			out.append_array(line)
	return out


## Jugadas validas; las esquinas primero (la busqueda corta antes).
static func moves(b: Array, n: int, who: int) -> Array:
	var out: Array = []
	var last: int = n * n - 1
	for i: int in [0, n - 1, last - n + 1, last]:
		if b[i] == 0 and not flips(b, n, i, who).is_empty():
			out.append(i)
	for j: int in n * n:
		if j == 0 or j == n - 1 or j == last - n + 1 or j == last:
			continue
		if b[j] == 0 and _touches(b, n, j, 3 - who) and not flips(b, n, j, who).is_empty():
			out.append(j)
	return out


static func _touches(b: Array, n: int, i: int, other: int) -> bool:
	var x: int = i % n
	var y: int = i / n
	for d: Variant in DIRS:
		var cx: int = x + int(d[0])
		var cy: int = y + int(d[1])
		if cx >= 0 and cx < n and cy >= 0 and cy < n and b[cy * n + cx] == other:
			return true
	return false


static func apply(b: Array, n: int, i: int, who: int) -> Array:
	var nb: Array = b.duplicate()
	for f: Variant in flips(b, n, i, who):
		nb[int(f)] = who
	nb[i] = who
	return nb


static func count(b: Array, who: int) -> int:
	return b.count(who)


## Pone en i la ficha de quien juega. Devuelve false si no vale. Pasa el turno solo si el otro no
## puede jugar; si nadie puede, acaba.
static func play(st: Dictionary, i: int) -> bool:
	if bool(st["won"]) or bool(st["lost"]) or bool(st["draw"]):
		return false
	var n: int = int(st["n"])
	var who: int = int(st["turn"])
	var f: Array = flips(st["b"], n, i, who)
	if i < 0 or i >= n * n or f.is_empty():
		return false
	st["b"] = apply(st["b"], n, i, who)
	st["last"] = i
	st["flipped"] = f
	st["plies"] = int(st["plies"]) + 1
	Rules.hook(st, "on_place", [i, f.size(), who])
	_advance(st)
	return true


static func _advance(st: Dictionary) -> void:
	var n: int = int(st["n"])
	var next: int = 3 - int(st["turn"])
	if not moves(st["b"], n, next).is_empty():
		st["turn"] = next
		st["passes"] = 0
		return
	if not moves(st["b"], n, int(st["turn"])).is_empty():
		st["passes"] = int(st["passes"]) + 1
		return
	var me: int = count(st["b"], 1)
	var him: int = count(st["b"], 2)
	st["won"] = me > him
	st["lost"] = him > me
	st["draw"] = me == him


## Valoracion desde las negras (las tuyas): esquinas, bordes, no regalar casillas junto a una
## esquina libre y, al final, fichas (sin contar jugadas posibles: asi es rapida).
static func evaluate(b: Array, n: int) -> int:
	var s: int = 0
	var empty: int = b.count(0)
	for i: int in n * n:
		var v: int = int(b[i])
		if v == 0:
			continue
		var x: int = i % n
		var y: int = i / n
		var w: int = 1
		var cx: bool = x == 0 or x == n - 1
		var cy: bool = y == 0 or y == n - 1
		if cx and cy:
			w = 30
		elif cx or cy:
			w = 4
		## Junto a una esquina que sigue libre: peligroso.
		var kx: int = 0 if x < n / 2 else n - 1
		var ky: int = 0 if y < n / 2 else n - 1
		if absi(x - kx) <= 1 and absi(y - ky) <= 1 and not (cx and cy) and b[ky * n + kx] == 0:
			w = -8 if (x != kx and y != ky) else -3
		s += w if v == 1 else -w
	if empty < n:
		s += (b.count(1) - b.count(2)) * 3
	return s


static func _final_score(b: Array) -> int:
	var d: int = b.count(1) - b.count(2)
	return 0 if d == 0 else (10000 + d if d > 0 else -10000 + d)


static func _search(b: Array, n: int, who: int, depth: int, alpha: int, beta: int) -> int:
	var ms: Array = moves(b, n, who)
	if ms.is_empty():
		if moves(b, n, 3 - who).is_empty():
			return _final_score(b)
		return _search(b, n, 3 - who, depth, alpha, beta)
	if depth == 0:
		return evaluate(b, n)
	if who == 1:
		var best: int = -1000000
		for i: Variant in ms:
			best = maxi(best, _search(apply(b, n, int(i), 1), n, 2, depth - 1, alpha, beta))
			alpha = maxi(alpha, best)
			if alpha >= beta:
				break
		return best
	var worst: int = 1000000
	for j: Variant in ms:
		worst = mini(worst, _search(apply(b, n, int(j), 2), n, 1, depth - 1, alpha, beta))
		beta = mini(beta, worst)
		if alpha >= beta:
			break
	return worst


## Mejor casilla para quien juega a la profundidad dada; empates, al azar de la semilla.
static func best_move(st: Dictionary, depth: int) -> int:
	var b: Array = st["b"]
	var n: int = int(st["n"])
	var who: int = int(st["turn"])
	var ms: Array = moves(b, n, who)
	if ms.is_empty():
		return -1
	var bv: int = 0
	var ties: Array = []
	for i: Variant in ms:
		var v: int = _search(apply(b, n, int(i), who), n, 3 - who, depth - 1, -1000000, 1000000)
		if who == 2:
			v = -v
		if ties.is_empty() or v > bv:
			bv = v
			ties = [int(i)]
		elif v == bv:
			ties.append(int(i))
	return ties[(st["rng"] as RandomNumberGenerator).randi_range(0, ties.size() - 1)] if ties.size() > 1 else ties[0]


## Tu bot: piensa tres jugadas.
static func bot_move(st: Dictionary) -> int:
	return best_move(st, 3)


static func rival_move(st: Dictionary) -> int:
	var rng: RandomNumberGenerator = st["rng"]
	if rng.randf() < float(st["mistake"]):
		var ms: Array = moves(st["b"], int(st["n"]), int(st["turn"]))
		if not ms.is_empty():
			return ms[rng.randi_range(0, ms.size() - 1)]
	return best_move(st, int(st["rival"]))


static func bot_play(level: Dictionary) -> Dictionary:
	var st: Dictionary = new_state(level)
	var guard: int = 0
	while not bool(st["won"]) and not bool(st["lost"]) and not bool(st["draw"]) and guard < 200:
		guard += 1
		var i: int = bot_move(st) if int(st["turn"]) == 1 else rival_move(st)
		if i < 0 or not play(st, i):
			break
	return {"won": bool(st["won"]), "plies": int(st["plies"]), "me": count(st["b"], 1), "him": count(st["b"], 2)}


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var r: Dictionary = {"won": false, "plies": 0}
	if not [6, 8].has(int(level.get("size", 8))):
		issues.append("reversi_size")
	if int(level.get("rival", 1)) < 1 or int(level.get("rival", 1)) > 3:
		issues.append("reversi_rival")
	if issues.is_empty():
		r = bot_play(level)
		if not bool(r["won"]):
			issues.append("reversi_unbeatable")
		## Que no se acabe en un suspiro (rival sin fichas a las pocas jugadas).
		elif int(r["plies"]) < int(level.get("size", 8)) * int(level.get("size", 8)) / 3:
			issues.append("reversi_too_short")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": 0, "enemies": 0, "enemy_problems": [], "bot_plies": r.get("plies", 0)}
