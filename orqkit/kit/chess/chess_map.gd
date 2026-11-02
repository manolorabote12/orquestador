extends RefCounted
## Ajedrez contra la maquina (reglas de siempre salvo enroque y captura al paso; el peon que llega al
## final se convierte en dama). Juegas con blancas. Se gana dando jaque mate; tablas (ahogado o
## demasiadas jugadas) cuentan como no ganada.
## Nivel: "rival" (profundidad 1 o 2), "mistake" (probabilidad de que el rival juegue al azar), "quitar" (piezas que le faltan al rival al empezar, p. ej.
## ["q", "r"]: ventaja para aprender), "seed" (desempates del rival) y "max_plies" (jugadas maximas).
## Tablero: Array de 64 casillas (0 = a8 ... 63 = h1); "" vacia, mayuscula blanca, minuscula negra.

const Rules = preload("res://kit/rules.gd")
const VAL: Dictionary = {"p": 100, "n": 320, "b": 330, "r": 500, "q": 900, "k": 0}
const START: String = "rnbqkbnrpppppppp" + "................................" + "PPPPPPPPRNBQKBNR"
const KNIGHT: Array = [[-2, -1], [-2, 1], [-1, -2], [-1, 2], [1, -2], [1, 2], [2, -1], [2, 1]]
const KING: Array = [[-1, -1], [-1, 0], [-1, 1], [0, -1], [0, 1], [1, -1], [1, 0], [1, 1]]
const ROOK_D: Array = [[-1, 0], [1, 0], [0, -1], [0, 1]]
const BISHOP_D: Array = [[-1, -1], [-1, 1], [1, -1], [1, 1]]


static func new_state(level: Dictionary) -> Dictionary:
	var b: Array = []
	for ch: String in START:
		b.append("" if ch == "." else ch)
	## Ventaja: se quitan piezas del rival (de dentro afuera, sin tocar al rey).
	for q: Variant in level.get("quitar", []):
		var p: String = str(q).to_lower()
		for i: int in [3, 2, 5, 1, 6, 0, 7, 8, 9, 10, 11, 12, 13, 14, 15]:
			if b[i] == p:
				b[i] = ""
				break
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(level.get("seed", 1))
	var st: Dictionary = {"b": b, "white": true, "plies": 0, "max_plies": clampi(int(level.get("max_plies", 200)), 20, 400),
		"rival": clampi(int(level.get("rival", 1)), 1, 2), "mistake": clampf(float(level.get("mistake", 0.0)), 0.0, 0.6), "last": [], "won": false, "lost": false, "draw": false, "rng": rng}
	st["rules"] = Rules.load_rules(level)
	Rules.hook(st, "on_start")
	return st


static func is_white(p: String) -> bool:
	return p != "" and p == p.to_upper()


## Movimientos sin mirar si dejan al rey en jaque: [desde, hasta].
static func pseudo_moves(b: Array, white: bool) -> Array:
	var out: Array = []
	for i: int in 64:
		var p: String = b[i]
		if p == "" or is_white(p) != white:
			continue
		var x: int = i % 8
		var y: int = i / 8
		match p.to_lower():
			"p":
				var dy: int = -1 if white else 1
				var y1: int = y + dy
				if y1 >= 0 and y1 < 8 and b[y1 * 8 + x] == "":
					out.append([i, y1 * 8 + x])
					var start_row: int = 6 if white else 1
					if y == start_row and b[(y + 2 * dy) * 8 + x] == "":
						out.append([i, (y + 2 * dy) * 8 + x])
				for dx: int in [-1, 1]:
					var x2: int = x + dx
					if x2 >= 0 and x2 < 8 and y1 >= 0 and y1 < 8:
						var t: String = b[y1 * 8 + x2]
						if t != "" and is_white(t) != white:
							out.append([i, y1 * 8 + x2])
			"n", "k":
				for d: Variant in (KNIGHT if p.to_lower() == "n" else KING):
					var x3: int = x + int(d[0])
					var y3: int = y + int(d[1])
					if x3 < 0 or x3 > 7 or y3 < 0 or y3 > 7:
						continue
					var t2: String = b[y3 * 8 + x3]
					if t2 == "" or is_white(t2) != white:
						out.append([i, y3 * 8 + x3])
			_:
				var dirs: Array = []
				if p.to_lower() != "b":
					dirs += ROOK_D
				if p.to_lower() != "r":
					dirs += BISHOP_D
				for d2: Variant in dirs:
					var x4: int = x + int(d2[0])
					var y4: int = y + int(d2[1])
					while x4 >= 0 and x4 < 8 and y4 >= 0 and y4 < 8:
						var t3: String = b[y4 * 8 + x4]
						if t3 == "":
							out.append([i, y4 * 8 + x4])
						else:
							if is_white(t3) != white:
								out.append([i, y4 * 8 + x4])
							break
						x4 += int(d2[0])
						y4 += int(d2[1])
	return out


static func attacked(b: Array, sq: int, by_white: bool) -> bool:
	var x: int = sq % 8
	var y: int = sq / 8
	## Peones: atacan en diagonal hacia delante (los blancos suben).
	var py: int = y + (1 if by_white else -1)
	if py >= 0 and py < 8:
		for dx: int in [-1, 1]:
			var px: int = x + dx
			if px >= 0 and px < 8 and b[py * 8 + px] == ("P" if by_white else "p"):
				return true
	for d: Variant in KNIGHT:
		var nx: int = x + int(d[0])
		var ny: int = y + int(d[1])
		if nx >= 0 and nx < 8 and ny >= 0 and ny < 8 and b[ny * 8 + nx] == ("N" if by_white else "n"):
			return true
	for d2: Variant in KING:
		var kx: int = x + int(d2[0])
		var ky: int = y + int(d2[1])
		if kx >= 0 and kx < 8 and ky >= 0 and ky < 8 and b[ky * 8 + kx] == ("K" if by_white else "k"):
			return true
	for d3: Variant in ROOK_D + BISHOP_D:
		var straight: bool = int(d3[0]) == 0 or int(d3[1]) == 0
		var rx: int = x + int(d3[0])
		var ry: int = y + int(d3[1])
		while rx >= 0 and rx < 8 and ry >= 0 and ry < 8:
			var t: String = b[ry * 8 + rx]
			if t != "":
				if is_white(t) == by_white:
					var lt: String = t.to_lower()
					if lt == "q" or (lt == "r" and straight) or (lt == "b" and not straight):
						return true
				break
			rx += int(d3[0])
			ry += int(d3[1])
	return false


static func king_sq(b: Array, white: bool) -> int:
	return b.find("K" if white else "k")


static func in_check(b: Array, white: bool) -> bool:
	var k: int = king_sq(b, white)
	return k >= 0 and attacked(b, k, not white)


## Aplica un movimiento en una copia del tablero (con dama al coronar).
static func apply(b: Array, m: Array) -> Array:
	var nb: Array = b.duplicate()
	var p: String = nb[int(m[0])]
	nb[int(m[1])] = p
	nb[int(m[0])] = ""
	var y: int = int(m[1]) / 8
	if p == "P" and y == 0:
		nb[int(m[1])] = "Q"
	elif p == "p" and y == 7:
		nb[int(m[1])] = "q"
	return nb


static func legal_moves(b: Array, white: bool) -> Array:
	var out: Array = []
	for m: Variant in pseudo_moves(b, white):
		if not in_check(apply(b, m), white):
			out.append(m)
	return out


## Juega el movimiento m del bando al que le toca. Devuelve false si no es legal.
static func play(st: Dictionary, m: Array) -> bool:
	if bool(st["won"]) or bool(st["lost"]) or bool(st["draw"]):
		return false
	var legal: bool = false
	for x: Variant in legal_moves(st["b"], bool(st["white"])):
		if int(x[0]) == int(m[0]) and int(x[1]) == int(m[1]):
			legal = true
	if not legal:
		return false
	var captured: String = st["b"][int(m[1])]
	st["b"] = apply(st["b"], m)
	st["last"] = [int(m[0]), int(m[1])]
	st["plies"] = int(st["plies"]) + 1
	Rules.hook(st, "on_move", [m, captured])
	st["white"] = not bool(st["white"])
	var replies: Array = legal_moves(st["b"], bool(st["white"]))
	if replies.is_empty():
		if in_check(st["b"], bool(st["white"])):
			st["won"] = not bool(st["white"])
			st["lost"] = bool(st["white"])
		else:
			st["draw"] = true
	elif int(st["plies"]) >= int(st["max_plies"]):
		st["draw"] = true
	return true


## Valoracion desde las blancas: material, centro, peones que avanzan y, si al rival solo le queda
## el rey, llevarlo al borde y acercar el propio (asi el bot sabe dar mate).
static func evaluate(b: Array) -> int:
	var s: int = 0
	var wk: int = -1
	var bk: int = -1
	var black_pieces: int = 0
	var white_pieces: int = 0
	for i: int in 64:
		var p: String = b[i]
		if p == "":
			continue
		var w: bool = is_white(p)
		var lp: String = p.to_lower()
		var v: int = int(VAL[lp])
		var x: int = i % 8
		var y: int = i / 8
		var center: int = 6 - (absi(2 * x - 7) + absi(2 * y - 7)) / 2
		if lp == "k":
			if w:
				wk = i
			else:
				bk = i
		else:
			if w:
				white_pieces += 1
			else:
				black_pieces += 1
		var bonus: int = 0
		if lp == "n" or lp == "b":
			bonus = center * 4
		elif lp == "p":
			bonus = (6 - y if w else y - 1) * 6 + (center if x > 1 and x < 6 else 0)
		elif lp == "q":
			bonus = center * 2
		s += (v + bonus) if w else -(v + bonus)
	if black_pieces == 0 and bk >= 0 and wk >= 0:
		var bx: int = bk % 8
		var by: int = bk / 8
		var edge: int = maxi(absi(2 * bx - 7), absi(2 * by - 7))
		var dist: int = maxi(absi(bx - wk % 8), absi(by - wk / 8))
		s += edge * 40 - dist * 20
	if white_pieces == 0 and wk >= 0 and bk >= 0:
		s -= maxi(absi(2 * (wk % 8) - 7), absi(2 * (wk / 8) - 7)) * 40
	return s


static func _search(b: Array, white: bool, depth: int, alpha: int, beta: int) -> int:
	## En las hojas no se buscan mates (el mate de un movimiento se ve un nivel antes): mucho mas rapido.
	if depth == 0:
		return evaluate(b)
	var moves: Array = legal_moves(b, white)
	if moves.is_empty():
		if in_check(b, white):
			return (-100000 - depth) if white else (100000 + depth)
		return 0
	_order(b, moves)
	if white:
		var best: int = -1000000
		for m: Variant in moves:
			best = maxi(best, _search(apply(b, m), false, depth - 1, alpha, beta))
			alpha = maxi(alpha, best)
			if alpha >= beta:
				break
		return best
	var worst: int = 1000000
	for m2: Variant in moves:
		worst = mini(worst, _search(apply(b, m2), true, depth - 1, alpha, beta))
		beta = mini(beta, worst)
		if alpha >= beta:
			break
	return worst


## Capturas primero (la pieza mas valiosa con la que menos vale): mas cortes en la busqueda.
static func _order(b: Array, moves: Array) -> void:
	moves.sort_custom(func(m1: Array, m2: Array) -> bool:
		var c1: int = int(VAL.get(str(b[int(m1[1])]).to_lower(), 0)) * 10 - int(VAL.get(str(b[int(m1[0])]).to_lower(), 0)) / 10 if b[int(m1[1])] != "" else -1
		var c2: int = int(VAL.get(str(b[int(m2[1])]).to_lower(), 0)) * 10 - int(VAL.get(str(b[int(m2[0])]).to_lower(), 0)) / 10 if b[int(m2[1])] != "" else -1
		if c1 != c2:
			return c1 > c2
		return int(m1[0]) * 64 + int(m1[1]) < int(m2[0]) * 64 + int(m2[1]))


## Mejor movimiento del bando que mueve a la profundidad dada; empates, al azar de la semilla.
static func best_move(st: Dictionary, depth: int) -> Array:
	var b: Array = st["b"]
	var white: bool = bool(st["white"])
	var moves: Array = legal_moves(b, white)
	if moves.is_empty():
		return []
	_order(b, moves)
	var best: Array = []
	var bv: int = 0
	var ties: Array = []
	for m: Variant in moves:
		var v: int = _search(apply(b, m), not white, depth - 1, -1000000, 1000000)
		if not white:
			v = -v
		if best.is_empty() or v > bv:
			bv = v
			best = m
			ties = [m]
		elif v == bv:
			ties.append(m)
	if ties.size() > 1:
		best = ties[(st["rng"] as RandomNumberGenerator).randi_range(0, ties.size() - 1)]
	return best


## Tu bot: profundidad 2.
static func bot_move(st: Dictionary) -> Array:
	return best_move(st, 2)


## El rival: a veces (mistake) juega una jugada cualquiera; si no, la mejor a su profundidad.
static func rival_move(st: Dictionary) -> Array:
	var rng: RandomNumberGenerator = st["rng"]
	if rng.randf() < float(st["mistake"]):
		var moves: Array = legal_moves(st["b"], bool(st["white"]))
		if not moves.is_empty():
			moves.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) * 64 + int(a[1]) < int(b[0]) * 64 + int(b[1]))
			return moves[rng.randi_range(0, moves.size() - 1)]
	return best_move(st, int(st["rival"]))


static func bot_play(level: Dictionary) -> Dictionary:
	var st: Dictionary = new_state(level)
	while not bool(st["won"]) and not bool(st["lost"]) and not bool(st["draw"]):
		var m: Array = bot_move(st) if bool(st["white"]) else rival_move(st)
		if m.is_empty():
			break
		play(st, m)
	return {"won": bool(st["won"]), "plies": int(st["plies"]), "draw": bool(st["draw"])}


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var r: Dictionary = {"won": false, "plies": 0}
	if int(level.get("rival", 1)) < 1 or int(level.get("rival", 1)) > 2:
		issues.append("chess_rival")
	for q: Variant in level.get("quitar", []):
		if not ["q", "r", "b", "n", "p"].has(str(q).to_lower()):
			issues.append("chess_bad_handicap")
	if issues.is_empty():
		r = bot_play(level)
		if not bool(r["won"]):
			issues.append("chess_unbeatable")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": 0, "enemies": 0, "enemy_problems": [], "bot_plies": r.get("plies", 0)}
