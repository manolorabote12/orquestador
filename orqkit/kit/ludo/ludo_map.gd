extends RefCounted
## Parchis (estilo Ludo King): reglas, dado con semilla, rivales, bot y analizador.
## 1 - Mapa (game.json -> levels[i].map): ["ludo"]. Parametros: "rivals" (1-3), "tokens" (fichas
##     por jugador, 2-4), "skill" (0-1: lo bien que juegan los rivales) y "seed" (el dado).
## 2 - Recorrido de 52 casillas y 6 de pasillo hasta la meta (58 pasos). Con un 6 se sale de casa y
##     se vuelve a tirar. Caer donde hay una ficha rival (fuera de las casillas seguras) la manda a
##     su casa. Para entrar en la meta hace falta el numero justo.
## 3 - Gana quien mete todas sus fichas en la meta. Tu eres el jugador 0.

const TRACK: int = 52
const HOME: int = 6
const GOAL: int = TRACK - 1 + HOME
const SAFE: Array[int] = [0, 8, 13, 21, 26, 34, 39, 47]


static func new_state(level: Dictionary) -> Dictionary:
	var rivals: int = clampi(int(level.get("rivals", 1)), 1, 3)
	var tokens: int = clampi(int(level.get("tokens", 4)), 1, 4)
	var players: Array = []
	for p: int in rivals + 1:
		var toks: Array = []
		for t: int in tokens:
			toks.append(-1)
		## Asientos repartidos: con 1 rival, enfrente.
		var seat: int = p * (2 if rivals == 1 else 1)
		players.append({"seat": seat, "tokens": toks})
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(level.get("seed", 1))
	return {"players": players, "turn": 0, "rng": rng, "die": 0, "winner": -1, "turns": 0, "skill": float(level.get("skill", 0.5)),
		"captures": [0, 0, 0, 0], "sixes": 0}


static func roll(st: Dictionary) -> int:
	var d: int = (st["rng"] as RandomNumberGenerator).randi_range(1, 6)
	st["die"] = d
	return d


## Casilla del recorrido comun (0-51) de un paso "pos" del jugador, o -1 si esta en casa, en el
## pasillo o en la meta.
static func board_cell(st: Dictionary, p: int, pos: int) -> int:
	if pos < 0 or pos >= TRACK - 1:
		return -1
	return (pos + int(st["players"][p]["seat"]) * 13) % TRACK


static func can_move(st: Dictionary, p: int, t: int, d: int) -> bool:
	var pos: int = int(st["players"][p]["tokens"][t])
	if pos == GOAL:
		return false
	if pos < 0:
		return d == 6
	return pos + d <= GOAL


static func legal(st: Dictionary, p: int, d: int) -> Array:
	var out: Array = []
	for t: int in (st["players"][p]["tokens"] as Array).size():
		if can_move(st, p, t, d):
			out.append(t)
	return out


## Mueve la ficha t del jugador p. Devuelve {"capture": jugador comido o -1, "home": entro en meta}.
static func move(st: Dictionary, p: int, t: int, d: int) -> Dictionary:
	var toks: Array = st["players"][p]["tokens"]
	var pos: int = int(toks[t])
	var npos: int = 0 if pos < 0 else pos + d
	toks[t] = npos
	var res: Dictionary = {"capture": -1, "home": npos == GOAL}
	var cell: int = board_cell(st, p, npos)
	if cell >= 0 and not SAFE.has(cell):
		for q: int in (st["players"] as Array).size():
			if q == p:
				continue
			var qt: Array = st["players"][q]["tokens"]
			for k: int in qt.size():
				if board_cell(st, q, int(qt[k])) == cell:
					qt[k] = -1
					res["capture"] = q
					st["captures"][p] = int(st["captures"][p]) + 1
	var done: bool = true
	for v: Variant in toks:
		if int(v) != GOAL:
			done = false
	if done:
		st["winner"] = p
	return res


## Que ficha mover: puntua comer, meter en meta, salir de casa, salir de peligro y avanzar.
## "care" (0-1) es lo bien que juega (0 = la primera que pueda).
static func choose(st: Dictionary, p: int, d: int, care: float) -> int:
	var opts: Array = legal(st, p, d)
	if opts.is_empty():
		return -1
	if care <= 0.0:
		return int(opts[0])
	var best: int = int(opts[0])
	var best_v: float = -INF
	for t: int in opts:
		var pos: int = int(st["players"][p]["tokens"][t])
		var npos: int = 0 if pos < 0 else pos + d
		var v: float = float(npos) * 0.1
		var cell: int = board_cell(st, p, npos)
		if npos == GOAL:
			v += 30.0
		if pos < 0:
			v += 18.0
		if cell >= 0 and not SAFE.has(cell) and _enemy_at(st, p, cell):
			v += 40.0 * care
		if cell >= 0 and SAFE.has(cell):
			v += 6.0 * care
		if pos >= TRACK - 1:
			v += 4.0
		v -= _danger(st, p, npos) * 12.0 * care
		v += _danger(st, p, pos) * 8.0 * care
		if v > best_v:
			best_v = v
			best = t
	return best


static func _enemy_at(st: Dictionary, p: int, cell: int) -> bool:
	for q: int in (st["players"] as Array).size():
		if q != p:
			for v: Variant in st["players"][q]["tokens"]:
				if board_cell(st, q, int(v)) == cell:
					return true
	return false


## Peligro de una posicion: rivales a 1-6 casillas por detras.
static func _danger(st: Dictionary, p: int, pos: int) -> float:
	var cell: int = board_cell(st, p, pos)
	if cell < 0 or SAFE.has(cell):
		return 0.0
	var n: float = 0.0
	for q: int in (st["players"] as Array).size():
		if q == p:
			continue
		for v: Variant in st["players"][q]["tokens"]:
			var c: int = board_cell(st, q, int(v))
			if c < 0:
				continue
			var gap: int = (cell - c + TRACK) % TRACK
			if gap >= 1 and gap <= 6:
				n += 1.0
	return n


## Un turno entero del jugador que toca (tirar, mover, repetir con 6). Devuelve los movimientos.
static func play_turn(st: Dictionary, care_player: float) -> Array:
	var p: int = int(st["turn"])
	var log: Array = []
	var again: bool = true
	var sixes: int = 0
	while again and int(st["winner"]) < 0:
		var d: int = roll(st)
		again = d == 6
		sixes += 1 if d == 6 else 0
		if sixes >= 3:
			break
		var care: float = care_player if p == 0 else float(st["skill"])
		var t: int = choose(st, p, d, care)
		if t >= 0:
			var r: Dictionary = move(st, p, t, d)
			log.append({"p": p, "t": t, "d": d, "r": r})
			if int(r["capture"]) >= 0 or bool(r["home"]):
				again = true
		else:
			log.append({"p": p, "t": -1, "d": d, "r": {}})
	st["turn"] = (p + 1) % (st["players"] as Array).size()
	st["turns"] = int(st["turns"]) + 1
	return log


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var st: Dictionary = new_state(level)
	var guard: int = 0
	while int(st["winner"]) < 0 and guard < 2000:
		guard += 1
		play_turn(st, 1.0)
	if int(st["winner"]) != 0:
		issues.append("ludo_too_hard")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": (st["players"][0]["tokens"] as Array).size(), "enemies": 0,
		"enemy_problems": [], "par": int(st["turns"])}
