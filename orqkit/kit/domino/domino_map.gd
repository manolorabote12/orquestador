extends RefCounted
## Domino (doble seis, a robar): cada jugador empieza con 7 fichas; se juega una ficha que case con
## una de las dos puntas de la mesa. Si no puedes, robas del pozo hasta poder (o pasas si no queda).
## Gana quien se queda sin fichas; si nadie puede jugar (cierre), gana quien suma menos puntos.
## Nivel: "players" (2-4), "hand" (fichas al empezar) y "deck" (las 28 fichas en orden: [a, b]):
## sin azar, la fabrica elige mazos con los que tu bot gana (fabrica/niveles: espejo en Python).
## La primera ficha la pone quien tenga el doble mas alto (o la ficha mas alta) y se empieza por el.

const Rules = preload("res://kit/rules.gd")


static func full_set() -> Array:
	var out: Array = []
	for a: int in 7:
		for b: int in range(a, 7):
			out.append([a, b])
	return out


static func new_state(level: Dictionary) -> Dictionary:
	var n: int = clampi(int(level.get("players", 2)), 2, 4)
	var pool: Array = []
	for t: Variant in level.get("deck", full_set()):
		pool.append([int(t[0]), int(t[1])])
	pool.reverse()
	var hands: Array = []
	for p: int in n:
		hands.append([])
	for k: int in clampi(int(level.get("hand", 7)), 3, 9):
		for p2: int in n:
			if not pool.is_empty():
				(hands[p2] as Array).append(pool.pop_back())
	var st: Dictionary = {"n": n, "hands": hands, "pool": pool, "chain": [], "left": -1, "right": -1, "turn": 0, "passes": 0,
		"won": false, "lost": false, "winner": -1, "turns": 0, "rng": RandomNumberGenerator.new()}
	## Sale quien tiene el doble mas alto (o la ficha que mas suma) y la pone el.
	var best: int = -1
	var who: int = 0
	var idx: int = 0
	for p3: int in n:
		for i: int in (hands[p3] as Array).size():
			var t2: Array = hands[p3][i]
			var score: int = (100 + int(t2[0])) if int(t2[0]) == int(t2[1]) else int(t2[0]) + int(t2[1])
			if score > best:
				best = score
				who = p3
				idx = i
	st["turn"] = who
	st["rules"] = Rules.load_rules(level)
	Rules.hook(st, "on_start")
	play(st, idx, "r")
	return st


static func pips(t: Array) -> int:
	return int(t[0]) + int(t[1])


## Donde puede ir la ficha: [] si en ninguna punta; ["l"], ["r"] o ["l", "r"].
static func fits(st: Dictionary, t: Array) -> Array:
	if (st["chain"] as Array).is_empty():
		return ["r"]
	var out: Array = []
	if int(t[0]) == int(st["left"]) or int(t[1]) == int(st["left"]):
		out.append("l")
	if int(t[0]) == int(st["right"]) or int(t[1]) == int(st["right"]):
		out.append("r")
	return out


static func can_play(st: Dictionary, p: int) -> bool:
	for t: Variant in st["hands"][p]:
		if not fits(st, t).is_empty():
			return true
	return false


## El jugador del turno juega su ficha idx en la punta side ("l" o "r").
static func play(st: Dictionary, idx: int, side: String) -> bool:
	if bool(st["won"]) or bool(st["lost"]):
		return false
	var p: int = int(st["turn"])
	var hand: Array = st["hands"][p]
	if idx < 0 or idx >= hand.size():
		return false
	var t: Array = hand[idx]
	var f: Array = fits(st, t)
	if not f.has(side):
		return false
	hand.remove_at(idx)
	var chain: Array = st["chain"]
	if chain.is_empty():
		chain.append([int(t[0]), int(t[1])])
		st["left"] = int(t[0])
		st["right"] = int(t[1])
	elif side == "l":
		var o: int = int(t[1]) if int(t[0]) == int(st["left"]) else int(t[0])
		chain.push_front([o, int(st["left"])])
		st["left"] = o
	else:
		var o2: int = int(t[1]) if int(t[0]) == int(st["right"]) else int(t[0])
		chain.append([int(st["right"]), o2])
		st["right"] = o2
	st["passes"] = 0
	Rules.hook(st, "on_play", [p, t, side])
	if hand.is_empty():
		_end(st, p)
		return true
	_next(st)
	return true


## Roba una ficha del pozo ("" si no quedan). Solo si no puede jugar.
static func draw(st: Dictionary) -> bool:
	var p: int = int(st["turn"])
	if bool(st["won"]) or bool(st["lost"]) or can_play(st, p) or (st["pool"] as Array).is_empty():
		return false
	(st["hands"][p] as Array).append((st["pool"] as Array).pop_back())
	return true


## Pasa (solo si no puede jugar ni robar). Si pasan todos seguidos, cierre.
static func pass_turn(st: Dictionary) -> bool:
	var p: int = int(st["turn"])
	if can_play(st, p) or not (st["pool"] as Array).is_empty():
		return false
	st["passes"] = int(st["passes"]) + 1
	if int(st["passes"]) >= int(st["n"]):
		var low: int = 9999
		var who: int = 0
		for q: int in int(st["n"]):
			var s: int = 0
			for t: Variant in st["hands"][q]:
				s += pips(t)
			if s < low:
				low = s
				who = q
		_end(st, who)
		return true
	_next(st)
	return true


static func _next(st: Dictionary) -> void:
	st["turn"] = (int(st["turn"]) + 1) % int(st["n"])
	st["turns"] = int(st["turns"]) + 1


static func _end(st: Dictionary, p: int) -> void:
	st["winner"] = p
	st["won"] = p == 0
	st["lost"] = p != 0


## Rival: la primera ficha que case, en la primera punta posible.
static func rival_move(st: Dictionary) -> Array:
	var hand: Array = st["hands"][int(st["turn"])]
	for i: int in hand.size():
		var f: Array = fits(st, hand[i])
		if not f.is_empty():
			return [i, str(f[0])]
	return []


## Tu bot: juega la ficha que mas suma (los dobles antes) y en la punta que deja mas jugadas propias.
static func bot_move(st: Dictionary) -> Array:
	var hand: Array = st["hands"][int(st["turn"])]
	var best: Array = []
	var bs: float = -1.0
	for i: int in hand.size():
		var t: Array = hand[i]
		for side: Variant in fits(st, t):
			var s: float = float(pips(t)) + (6.0 if int(t[0]) == int(t[1]) else 0.0)
			var open: int = int(t[1]) if int(t[0]) == int(st["left" if side == "l" else "right"]) else int(t[0])
			for j: int in hand.size():
				if j != i and (int(hand[j][0]) == open or int(hand[j][1]) == open):
					s += 1.5
			if s > bs:
				bs = s
				best = [i, str(side)]
	return best


## Un turno automatico del jugador del turno (bot listo o rival). false si la partida acabo.
static func auto_turn(st: Dictionary, smart: bool) -> bool:
	if bool(st["won"]) or bool(st["lost"]):
		return false
	var m: Array = bot_move(st) if smart else rival_move(st)
	if not m.is_empty():
		play(st, int(m[0]), str(m[1]))
	elif not draw(st):
		pass_turn(st)
	return true


static func bot_play(level: Dictionary, max_turns: int = 400) -> Dictionary:
	var st: Dictionary = new_state(level)
	var guard: int = 0
	while not bool(st["won"]) and not bool(st["lost"]) and guard < max_turns * 4:
		guard += 1
		auto_turn(st, int(st["turn"]) == 0)
	return {"won": bool(st["won"]), "turns": int(st["turns"]), "winner": int(st["winner"])}


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var deck: Array = level.get("deck", [])
	var n: int = int(level.get("players", 2))
	if n < 2 or n > 4:
		issues.append("dom_players")
	if deck.size() != 28:
		issues.append("dom_deck_size")
	var seen: Dictionary = {}
	for t: Variant in deck:
		var a: int = mini(int(t[0]), int(t[1]))
		var b: int = maxi(int(t[0]), int(t[1]))
		if a < 0 or b > 6 or seen.has(a * 10 + b):
			issues.append("dom_bad_tile")
			break
		seen[a * 10 + b] = true
	if n * int(level.get("hand", 7)) > 28:
		issues.append("dom_hand")
	var r: Dictionary = {"won": false}
	if issues.is_empty():
		r = bot_play(level)
		if not bool(r["won"]):
			issues.append("dom_unbeatable")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": 0, "enemies": 0, "enemy_problems": [], "bot_turns": r.get("turns", 0)}
