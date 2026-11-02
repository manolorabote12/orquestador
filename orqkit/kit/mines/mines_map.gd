extends RefCounted
## Buscaminas (sin adivinar): reglas, resolutor logico, bot y analizador.
## 1 - Mapa (game.json -> levels[i].map): "*" mina, "." casilla y "S" la casilla de salida (se
##     abre sola al empezar; siempre sin minas alrededor).
## 2 - Tocar abre la casilla (si es 0 se abren las vecinas solas). Mantener (o el modo bandera)
##     pone una bandera. Abrir una mina quita una vida ("lives"); sin vidas se pierde.
## 3 - Se gana al abrir todas las casillas sin mina.
## Analizador: el resolutor logico (vecinos y subconjuntos) abre el tablero entero desde la
## salida, sin tener que adivinar nunca.

const N8: Array[Vector2i] = [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-1, 1),
	Vector2i(0, 1), Vector2i(1, 1)]


static func new_state(level: Dictionary) -> Dictionary:
	var rows: Array = level.get("map", [])
	var h: int = rows.size()
	var w: int = str(rows[0]).length() if h > 0 else 0
	var mines: Dictionary = {}
	var start: Vector2i = Vector2i(-1, -1)
	for y: int in h:
		var s: String = str(rows[y])
		for x: int in w:
			var ch: String = s[x] if x < s.length() else "."
			if ch == "*":
				mines[Vector2i(x, y)] = true
			elif ch == "S":
				start = Vector2i(x, y)
	var st: Dictionary = {"w": w, "h": h, "mines": mines, "open": {}, "flags": {}, "lives": int(level.get("lives", 1)), "booms": 0,
		"start": start, "safe": w * h - mines.size(), "won": false}
	if start.x >= 0:
		reveal(st, start)
	return st


static func inside(st: Dictionary, c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < int(st["w"]) and c.y < int(st["h"])


static func count(st: Dictionary, c: Vector2i) -> int:
	var k: int = 0
	for d: Vector2i in N8:
		if (st["mines"] as Dictionary).has(c + d):
			k += 1
	return k


## Abre una casilla. Devuelve "mine", "open" o "" (nada que hacer).
static func reveal(st: Dictionary, c: Vector2i) -> String:
	if not inside(st, c) or (st["open"] as Dictionary).has(c) or (st["flags"] as Dictionary).has(c):
		return ""
	if (st["mines"] as Dictionary).has(c):
		st["booms"] = int(st["booms"]) + 1
		st["flags"][c] = true
		return "mine"
	var q: Array = [c]
	st["open"][c] = true
	while not q.is_empty():
		var p: Vector2i = q.pop_back()
		if count(st, p) != 0:
			continue
		for d: Vector2i in N8:
			var n: Vector2i = p + d
			if inside(st, n) and not (st["open"] as Dictionary).has(n) and not (st["mines"] as Dictionary).has(n):
				st["open"][n] = true
				st["flags"].erase(n)
				q.append(n)
	if (st["open"] as Dictionary).size() >= int(st["safe"]):
		st["won"] = true
	return "open"


static func toggle_flag(st: Dictionary, c: Vector2i) -> void:
	if not inside(st, c) or (st["open"] as Dictionary).has(c):
		return
	if (st["flags"] as Dictionary).has(c):
		st["flags"].erase(c)
	else:
		st["flags"][c] = true


static func lost(st: Dictionary) -> bool:
	return int(st["booms"]) >= int(st["lives"])


## 1 - Deduccion logica: {"safe": [casillas seguras], "mines": [minas seguras]} con lo abierto.
static func deduce(st: Dictionary) -> Dictionary:
	var known_mines: Dictionary = (st["flags"] as Dictionary).duplicate()
	var safe: Dictionary = {}
	var cons: Array = []
	for c: Variant in st["open"]:
		var cell: Vector2i = c
		var n: int = count(st, cell)
		if n == 0:
			continue
		var unknown: Array = []
		var m: int = n
		for d: Vector2i in N8:
			var nb: Vector2i = cell + d
			if not inside(st, nb) or (st["open"] as Dictionary).has(nb):
				continue
			if known_mines.has(nb) and (st["mines"] as Dictionary).has(nb):
				m -= 1
			else:
				unknown.append(nb)
		if not unknown.is_empty():
			cons.append([unknown, m])
	var changed: bool = true
	var guard: int = 0
	while changed and guard < 30:
		changed = false
		guard += 1
		for con: Array in cons:
			var unk: Array = []
			var m2: int = int(con[1])
			for u: Variant in con[0]:
				if known_mines.has(u):
					m2 -= 1
				elif not safe.has(u):
					unk.append(u)
			if unk.is_empty():
				continue
			if m2 == 0:
				for u2: Variant in unk:
					safe[u2] = true
				changed = true
			elif m2 == unk.size():
				for u3: Variant in unk:
					known_mines[u3] = true
				changed = true
		## Subconjuntos: si las incognitas de A estan dentro de las de B, la diferencia lleva m(B)-m(A).
		if not changed:
			for a: Array in cons:
				for b: Array in cons:
					if a == b:
						continue
					var ua: Array = _rest(a, known_mines, safe)
					var ub: Array = _rest(b, known_mines, safe)
					if ua.is_empty() or ub.size() <= ua.size():
						continue
					var sub: bool = true
					for u4: Variant in ua:
						if not ub.has(u4):
							sub = false
							break
					if not sub:
						continue
					var diff: Array = ub.filter(func(u5: Variant) -> bool: return not ua.has(u5))
					var md: int = _left(b, known_mines) - _left(a, known_mines)
					if md == 0:
						for u6: Variant in diff:
							safe[u6] = true
						changed = true
					elif md == diff.size():
						for u7: Variant in diff:
							known_mines[u7] = true
						changed = true
	var mines_out: Array = []
	for k: Variant in known_mines:
		if not (st["flags"] as Dictionary).has(k):
			mines_out.append(k)
	return {"safe": safe.keys(), "mines": mines_out}


static func _rest(con: Array, known_mines: Dictionary, safe: Dictionary) -> Array:
	var out: Array = []
	for u: Variant in con[0]:
		if not known_mines.has(u) and not safe.has(u):
			out.append(u)
	return out


static func _left(con: Array, known_mines: Dictionary) -> int:
	var m: int = int(con[1])
	for u: Variant in con[0]:
		if known_mines.has(u):
			m -= 1
	return m


## Jugada del bot: abrir una casilla segura o poner una bandera segura. [que, casilla] o [].
static func bot_move(st: Dictionary) -> Array:
	var d: Dictionary = deduce(st)
	for c: Variant in d["safe"]:
		if not (st["open"] as Dictionary).has(c):
			return ["open", c]
	for c2: Variant in d["mines"]:
		return ["flag", c2]
	return []


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var st: Dictionary = new_state(level)
	var w: int = int(st["w"])
	var h: int = int(st["h"])
	if w < 5 or h < 5 or w > 12 or h > 16:
		issues.append("mines_size")
	if (st["start"] as Vector2i).x < 0:
		issues.append("mines_no_start")
	elif count(st, st["start"]) != 0:
		issues.append("mines_start_not_zero")
	if (st["mines"] as Dictionary).size() < 3:
		issues.append("mines_few")
	var moves: int = 0
	if issues.is_empty():
		var guard: int = 0
		while not bool(st["won"]) and guard < 1000:
			guard += 1
			var m: Array = bot_move(st)
			if m.is_empty():
				issues.append("mines_guess")
				break
			moves += 1
			if str(m[0]) == "open":
				if reveal(st, m[1]) == "mine":
					issues.append("mines_bot_boom")
					break
			else:
				toggle_flag(st, m[1])
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": int(st["safe"]), "enemies": 0, "enemy_problems": [],
		"par": 10 + moves * 2}
