extends RefCounted
## Hundir la flota contra la maquina. Cada uno tiene su flota escondida en su tablero; por turnos
## se dispara a una casilla del rival: agua, tocado o hundido. Si tocas, vuelves a disparar (asi es
## mas agil en el movil). Gana quien hunde antes toda la flota contraria.
## Nivel: "n" (6 a 10), "ships" (largos, p. ej. [4, 3, 3, 2, 2]), "rival" (0 dispara al azar, 1 caza
## alrededor de lo tocado, 2 ademas dispara en damero), "mistake" (disparo al azar a veces) y "seed".
## Tableros: Array de n*n con el numero del barco (0 agua); disparos: Dictionary casilla -> "x"/"o".

const Rules = preload("res://kit/rules.gd")


static func place_fleet(n: int, ships: Array, rng: RandomNumberGenerator) -> Array:
	for _attempt: int in 200:
		var b: Array = []
		b.resize(n * n)
		b.fill(0)
		var ok: bool = true
		for k: int in ships.size():
			var L: int = int(ships[k])
			var placed: bool = false
			for _try: int in 100:
				var horiz: bool = rng.randf() < 0.5
				var x: int = rng.randi_range(0, n - (L if horiz else 1))
				var y: int = rng.randi_range(0, n - (1 if horiz else L))
				var cells: Array = []
				var free: bool = true
				for j: int in L:
					var c: int = (y + (0 if horiz else j)) * n + x + (j if horiz else 0)
					## Sin tocarse con otro barco (ni en diagonal).
					for dy: int in [-1, 0, 1]:
						for dx: int in [-1, 0, 1]:
							var cx: int = c % n + dx
							var cy: int = c / n + dy
							if cx >= 0 and cx < n and cy >= 0 and cy < n and int(b[cy * n + cx]) != 0:
								free = false
					cells.append(c)
				if free:
					for c2: Variant in cells:
						b[int(c2)] = k + 1
					placed = true
					break
			if not placed:
				ok = false
				break
		if ok:
			return b
	return []


static func new_state(level: Dictionary) -> Dictionary:
	var n: int = clampi(int(level.get("n", 8)), 5, 10)
	var ships: Array = []
	for s: Variant in level.get("ships", [3, 2, 2]):
		ships.append(int(s))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(level.get("seed", 1))
	var st: Dictionary = {"n": n, "ships": ships, "mine": place_fleet(n, ships, rng), "theirs": place_fleet(n, ships, rng),
		"shots_mine": {}, "shots_theirs": {}, "turn": 1, "rival": clampi(int(level.get("rival", 1)), 0, 2),
		"mistake": clampf(float(level.get("mistake", 0.0)), 0.0, 0.8), "won": false, "lost": false, "last": -1, "last_result": "",
		"rng": rng, "shots": 0}
	st["rules"] = Rules.load_rules(level)
	Rules.hook(st, "on_start")
	return st


static func sunk(board: Array, shots: Dictionary, ship: int) -> bool:
	for i: int in board.size():
		if int(board[i]) == ship and not shots.has(i):
			return false
	return true


static func fleet_left(board: Array, shots: Dictionary, ships: Array) -> int:
	var c: int = 0
	for k: int in ships.size():
		if not sunk(board, shots, k + 1):
			c += 1
	return c


## Dispara quien tenga el turno a la casilla i del otro: "water", "hit", "sunk" o "" (no vale).
static func fire(st: Dictionary, i: int) -> String:
	if bool(st["won"]) or bool(st["lost"]):
		return ""
	var me: bool = int(st["turn"]) == 1
	var board: Array = st["theirs"] if me else st["mine"]
	var shots: Dictionary = st["shots_mine"] if me else st["shots_theirs"]
	var n: int = int(st["n"])
	if i < 0 or i >= n * n or shots.has(i):
		return ""
	if me:
		st["shots"] = int(st["shots"]) + 1
	var ship: int = int(board[i])
	shots[i] = "x" if ship > 0 else "o"
	st["last"] = i
	var res: String = "water"
	if ship > 0:
		res = "sunk" if sunk(board, shots, ship) else "hit"
	st["last_result"] = res
	Rules.hook(st, "on_shot", [i, res, me])
	if fleet_left(board, shots, st["ships"]) == 0:
		st["won"] = me
		st["lost"] = not me
	elif res == "water":
		st["turn"] = 2 if me else 1
	return res


## Cazador: si hay tocados sin hundir, dispara al lado (en la linea si ya hay dos); si no, al azar
## (en damero si "parity"). Lo usan el rival y tu bot.
static func hunt(board: Array, shots: Dictionary, n: int, ships: Array, parity: bool, rng: RandomNumberGenerator) -> int:
	var open_hits: Array = []
	for k: Variant in shots.keys():
		var i: int = int(k)
		if str(shots[k]) == "x" and not sunk(board, shots, int(board[i])):
			open_hits.append(i)
	if not open_hits.is_empty():
		open_hits.sort()
		var cand: Array = []
		if open_hits.size() >= 2:
			var a: int = int(open_hits[0])
			var b: int = int(open_hits[open_hits.size() - 1])
			if a / n == b / n:
				cand = [a - 1, b + 1]
				cand = cand.filter(func(c: int) -> bool: return c >= 0 and c < n * n and c / n == a / n)
			else:
				cand = [a - n, b + n]
		if cand.is_empty() or cand.all(func(c: int) -> bool: return c < 0 or c >= n * n or shots.has(c)):
			cand = []
			for h: Variant in open_hits:
				var hi: int = int(h)
				for d: int in [-1, 1, -n, n]:
					var c2: int = hi + d
					if c2 < 0 or c2 >= n * n:
						continue
					if (d == -1 or d == 1) and c2 / n != hi / n:
						continue
					cand.append(c2)
		cand = cand.filter(func(c: int) -> bool: return c >= 0 and c < n * n and not shots.has(c))
		if not cand.is_empty():
			return int(cand[rng.randi_range(0, cand.size() - 1)])
	var free: Array = []
	var smallest: int = 99
	for k2: int in ships.size():
		if not sunk(board, shots, k2 + 1):
			smallest = mini(smallest, int(ships[k2]))
	for j: int in n * n:
		if shots.has(j):
			continue
		if parity and smallest >= 2 and ((j % n) + (j / n)) % 2 != 0:
			continue
		free.append(j)
	if free.is_empty():
		for j2: int in n * n:
			if not shots.has(j2):
				free.append(j2)
	return int(free[rng.randi_range(0, free.size() - 1)]) if not free.is_empty() else -1


static func rival_shot(st: Dictionary) -> int:
	var rng: RandomNumberGenerator = st["rng"]
	var n: int = int(st["n"])
	var shots: Dictionary = st["shots_theirs"]
	if int(st["rival"]) == 0 or rng.randf() < float(st["mistake"]):
		var free: Array = []
		for j: int in n * n:
			if not shots.has(j):
				free.append(j)
		return int(free[rng.randi_range(0, free.size() - 1)]) if not free.is_empty() else -1
	return hunt(st["mine"], shots, n, st["ships"], int(st["rival"]) >= 2, rng)


## Tu bot: el mismo cazador en damero.
static func bot_shot(st: Dictionary) -> int:
	return hunt(st["theirs"], st["shots_mine"], int(st["n"]), st["ships"], true, st["rng"])


static func bot_play(level: Dictionary) -> Dictionary:
	var st: Dictionary = new_state(level)
	var guard: int = 0
	while not bool(st["won"]) and not bool(st["lost"]) and guard < 400:
		guard += 1
		var i: int = bot_shot(st) if int(st["turn"]) == 1 else rival_shot(st)
		if i < 0 or fire(st, i) == "":
			break
	return {"won": bool(st["won"]), "shots": int(st["shots"])}


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var n: int = int(level.get("n", 8))
	var ships: Array = level.get("ships", [])
	var cells: int = 0
	for s: Variant in ships:
		cells += int(s)
		if int(s) < 1 or int(s) > n - 1:
			issues.append("battle_bad_ship")
	if n < 5 or n > 10 or ships.size() < 2 or cells * 3 > n * n:
		issues.append("battle_board")
	var r: Dictionary = {"won": false, "shots": 0}
	if issues.is_empty():
		var st: Dictionary = new_state(level)
		if (st["mine"] as Array).is_empty() or (st["theirs"] as Array).is_empty():
			issues.append("battle_no_room")
		else:
			r = bot_play(level)
			if not bool(r["won"]):
				issues.append("battle_unbeatable")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": ships.size(), "enemies": 0, "enemy_problems": [], "bot_shots": r.get("shots", 0)}
