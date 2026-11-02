extends RefCounted
## Gemas y heroes (tipo Puzzle & Dragons): un tablero de 7x7 gemas de 5 colores y corazones. Cambias
## dos gemas vecinas; si hacen linea de 3 o mas, se rompen (y caen otras, con cadenas). Cada color
## hace atacar a los heroes de ese color y los corazones curan al equipo. Los heroes cargan su
## especial con sus gemas. Los monstruos atacan cuando su cuenta atras llega a 0.
## Nivel: "team" ([{"c": color 0-4, "atk", "skill": "blast"|"heal"|"stun"}]), "hp" (vida del equipo),
## "waves" ([[{"c", "hp", "atk", "every"}]]: monstruos por oleada), "moves" (0 = sin limite), "seed".
## Colores: 0 fuego, 1 agua, 2 naturaleza, 3 luz, 4 sombra, 5 corazon.

const Rules = preload("res://kit/rules.gd")
const N: int = 7
const COLORS: int = 6
const HEART: int = 5
const CHARGE: int = 12


## Ventaja de colores: fuego > naturaleza > agua > fuego; luz <-> sombra.
static func advantage(attacker: int, defender: int) -> float:
	if (attacker == 0 and defender == 2) or (attacker == 2 and defender == 1) or (attacker == 1 and defender == 0):
		return 1.5
	if (attacker == 2 and defender == 0) or (attacker == 1 and defender == 2) or (attacker == 0 and defender == 1):
		return 0.6
	if (attacker == 3 and defender == 4) or (attacker == 4 and defender == 3):
		return 1.5
	return 1.0


static func new_state(level: Dictionary) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(level.get("seed", 1))
	var team: Array = []
	for h: Variant in level.get("team", []):
		team.append({"c": int(h["c"]), "atk": int(h.get("atk", 10)), "skill": str(h.get("skill", "blast")), "charge": 0})
	var hp: int = int(level.get("hp", 300))
	var st: Dictionary = {"board": [], "rng": rng, "team": team, "hp": hp, "max_hp": hp, "waves": level.get("waves", []), "wave": 0,
		"enemies": [], "moves": 0, "max_moves": int(level.get("moves", 0)), "won": false, "lost": false, "last": [], "stun": 0}
	var b: Array = []
	for i: int in N * N:
		var c: int = rng.randi_range(0, COLORS - 1)
		## Sin lineas al empezar.
		while (i % N >= 2 and int(b[i - 1]) == c and int(b[i - 2]) == c) or (i / N >= 2 and int(b[i - N]) == c and int(b[i - 2 * N]) == c):
			c = (c + 1) % COLORS
		b.append(c)
	st["board"] = b
	_load_wave(st)
	st["rules"] = Rules.load_rules(level)
	Rules.hook(st, "on_start")
	return st


static func _load_wave(st: Dictionary) -> void:
	var waves: Array = st["waves"]
	var out: Array = []
	if int(st["wave"]) < waves.size():
		for e: Variant in waves[int(st["wave"])]:
			out.append({"c": int(e["c"]), "hp": int(e["hp"]), "max": int(e["hp"]), "atk": int(e["atk"]), "every": int(e.get("every", 3)),
				"cd": int(e.get("every", 3))})
	st["enemies"] = out


## Lineas de 3 o mas: casillas que se rompen.
static func matches(b: Array) -> Dictionary:
	var hit: Dictionary = {}
	for y: int in N:
		var run: int = 1
		for x: int in range(1, N + 1):
			if x < N and int(b[y * N + x]) == int(b[y * N + x - 1]) and int(b[y * N + x]) >= 0:
				run += 1
			else:
				if run >= 3:
					for k: int in run:
						hit[y * N + x - 1 - k] = true
				run = 1
	for x2: int in N:
		var run2: int = 1
		for y2: int in range(1, N + 1):
			if y2 < N and int(b[y2 * N + x2]) == int(b[(y2 - 1) * N + x2]) and int(b[y2 * N + x2]) >= 0:
				run2 += 1
			else:
				if run2 >= 3:
					for k2: int in run2:
						hit[(y2 - 1 - k2) * N + x2] = true
				run2 = 1
	return hit


static func adjacent(a: int, b: int) -> bool:
	return (absi(a - b) == 1 and a / N == b / N) or absi(a - b) == N


## Rompe, deja caer y rellena hasta que no haya lineas. Devuelve cuantas gemas de cada color.
static func resolve(st: Dictionary) -> Array:
	var counts: Array = []
	counts.resize(COLORS)
	counts.fill(0)
	var b: Array = st["board"]
	var rng: RandomNumberGenerator = st["rng"]
	var combo: int = 0
	while true:
		var hit: Dictionary = matches(b)
		if hit.is_empty():
			break
		combo += 1
		for i: Variant in hit.keys():
			counts[int(b[int(i)])] = int(counts[int(b[int(i)])]) + 1
			b[int(i)] = -1
		for x: int in N:
			var col: Array = []
			for y: int in range(N - 1, -1, -1):
				if int(b[y * N + x]) >= 0:
					col.append(int(b[y * N + x]))
			for y2: int in range(N - 1, -1, -1):
				var k: int = N - 1 - y2
				b[y2 * N + x] = int(col[k]) if k < col.size() else rng.randi_range(0, COLORS - 1)
	counts.append(combo)
	return counts


## Cambia dos gemas vecinas. Si no hacen linea, no vale (se deshace). Devuelve el resultado del turno.
static func swap(st: Dictionary, a: int, b: int) -> Dictionary:
	if bool(st["won"]) or bool(st["lost"]) or not adjacent(a, b) or a < 0 or b < 0 or a >= N * N or b >= N * N:
		return {}
	var board: Array = st["board"]
	var t: int = int(board[a])
	board[a] = board[b]
	board[b] = t
	if matches(board).is_empty():
		board[b] = board[a]
		board[a] = t
		return {}
	var counts: Array = resolve(st)
	var combo: int = int(counts[COLORS])
	var res: Dictionary = {"counts": counts, "combo": combo, "hits": [], "heal": 0, "enemy_hits": []}
	## Ataque del equipo (al primer monstruo vivo; con ventaja de color) y curas.
	var mult: float = 1.0 + 0.25 * float(combo - 1)
	for h: Variant in st["team"]:
		var n: int = int(counts[int(h["c"])])
		if n <= 0:
			continue
		h["charge"] = mini(CHARGE, int(h["charge"]) + n)
		var target: Dictionary = _front(st)
		if target.is_empty():
			continue
		var dmg: int = int(round(float(h["atk"]) * float(n) * 0.5 * mult * advantage(int(h["c"]), int(target["c"]))))
		target["hp"] = maxi(0, int(target["hp"]) - dmg)
		(res["hits"] as Array).append({"hero": (st["team"] as Array).find(h), "dmg": dmg})
	var heal: int = int(round(float(counts[HEART]) * 8.0 * mult))
	if heal > 0:
		st["hp"] = mini(int(st["max_hp"]), int(st["hp"]) + heal)
		res["heal"] = heal
	st["moves"] = int(st["moves"]) + 1
	Rules.hook(st, "on_swap", [res])
	_after_turn(st, res)
	return res


static func _front(st: Dictionary) -> Dictionary:
	for e: Variant in st["enemies"]:
		if int(e["hp"]) > 0:
			return e
	return {}


## Fin del turno: oleada siguiente si no quedan monstruos; si no, sus cuentas atras y sus ataques.
static func _after_turn(st: Dictionary, res: Dictionary) -> void:
	if _front(st).is_empty():
		st["wave"] = int(st["wave"]) + 1
		if int(st["wave"]) >= (st["waves"] as Array).size():
			st["won"] = true
			return
		_load_wave(st)
		return
	if int(st["stun"]) > 0:
		st["stun"] = int(st["stun"]) - 1
	else:
		for e: Variant in st["enemies"]:
			if int(e["hp"]) <= 0:
				continue
			e["cd"] = int(e["cd"]) - 1
			if int(e["cd"]) <= 0:
				e["cd"] = int(e["every"])
				st["hp"] = int(st["hp"]) - int(e["atk"])
				(res["enemy_hits"] as Array).append(int(e["atk"]))
	if int(st["hp"]) <= 0:
		st["hp"] = 0
		st["lost"] = true
	elif int(st["max_moves"]) > 0 and int(st["moves"]) >= int(st["max_moves"]):
		st["lost"] = true


## Especial de un heroe con la carga llena: "blast" (dano grande a todos), "heal" (cura un 40 %),
## "stun" (los monstruos no cuentan 2 turnos). No gasta turno.
static func use_skill(st: Dictionary, k: int) -> bool:
	var team: Array = st["team"]
	if k < 0 or k >= team.size() or int(team[k]["charge"]) < CHARGE or bool(st["won"]) or bool(st["lost"]):
		return false
	var h: Dictionary = team[k]
	h["charge"] = 0
	match str(h["skill"]):
		"blast":
			for e: Variant in st["enemies"]:
				if int(e["hp"]) > 0:
					e["hp"] = maxi(0, int(e["hp"]) - int(round(float(h["atk"]) * 6.0 * advantage(int(h["c"]), int(e["c"])))))
		"heal":
			st["hp"] = mini(int(st["max_hp"]), int(st["hp"]) + int(st["max_hp"]) * 4 / 10)
		"stun":
			st["stun"] = 2
	Rules.hook(st, "on_skill", [k])
	if _front(st).is_empty():
		_after_turn(st, {"enemy_hits": []})
	return true


# ------------------------------------------------------------------ bot

## Todas las jugadas que valen: [[a, b], ...].
static func valid_swaps(b: Array) -> Array:
	var out: Array = []
	for i: int in N * N:
		for j: int in [i + 1, i + N]:
			if j >= N * N or (j == i + 1 and j / N != i / N):
				continue
			var t: int = int(b[i])
			b[i] = b[j]
			b[j] = t
			if not matches(b).is_empty():
				out.append([i, j])
			b[j] = b[i]
			b[i] = t
	return out


## Valor de una jugada: dano esperado al monstruo de delante (y lo que carga), curas si hacen falta.
static func _value(st: Dictionary, counts: Array) -> float:
	var target: Dictionary = _front(st)
	var v: float = 0.0
	for h: Variant in st["team"]:
		var n: int = int(counts[int(h["c"])])
		if n > 0 and not target.is_empty():
			v += float(h["atk"]) * float(n) * advantage(int(h["c"]), int(target["c"]))
			v += float(n) * 1.5
	var missing: float = 1.0 - float(st["hp"]) / float(st["max_hp"])
	v += float(counts[HEART]) * 8.0 * (0.3 + missing * 3.0)
	v *= 1.0 + 0.25 * float(int(counts[COLORS]) - 1)
	return v


## Bot: usa los especiales cuando valen y elige la jugada con mas valor (simulando las cadenas).
static func bot_move(st: Dictionary) -> Array:
	var team: Array = st["team"]
	for k: int in team.size():
		if int(team[k]["charge"]) >= CHARGE:
			var sk: String = str(team[k]["skill"])
			if sk == "blast" or (sk == "heal" and float(st["hp"]) < float(st["max_hp"]) * 0.6) or sk == "stun":
				return [-1, k]
	var best: Array = []
	var bv: float = -1.0
	for m: Variant in valid_swaps(st["board"]):
		var sim: Dictionary = {"board": (st["board"] as Array).duplicate(), "rng": _clone_rng(st["rng"])}
		var b2: Array = sim["board"]
		var t: int = int(b2[int(m[0])])
		b2[int(m[0])] = b2[int(m[1])]
		b2[int(m[1])] = t
		var v: float = _value(st, resolve(sim))
		if v > bv:
			bv = v
			best = m
	return best


static func _clone_rng(r: RandomNumberGenerator) -> RandomNumberGenerator:
	var c: RandomNumberGenerator = RandomNumberGenerator.new()
	c.seed = r.seed
	c.state = r.state
	return c


static func bot_play(level: Dictionary) -> Dictionary:
	var st: Dictionary = new_state(level)
	var guard: int = 0
	while not bool(st["won"]) and not bool(st["lost"]) and guard < 300:
		guard += 1
		var m: Array = bot_move(st)
		if m.is_empty():
			break
		if int(m[0]) < 0:
			use_skill(st, int(m[1]))
		else:
			swap(st, int(m[0]), int(m[1]))
	return {"won": bool(st["won"]), "moves": int(st["moves"]), "hp": int(st["hp"])}


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var team: Array = level.get("team", [])
	if team.size() < 1 or team.size() > 5:
		issues.append("gemrpg_team")
	var waves: Array = level.get("waves", [])
	if waves.is_empty():
		issues.append("gemrpg_no_waves")
	for w: Variant in waves:
		if (w as Array).is_empty() or (w as Array).size() > 3:
			issues.append("gemrpg_bad_wave")
	var r: Dictionary = {"won": false, "moves": 0}
	if issues.is_empty():
		r = bot_play(level)
		if not bool(r["won"]):
			issues.append("gemrpg_unbeatable")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": waves.size(), "enemies": 0, "enemy_problems": [], "bot_moves": r.get("moves", 0)}
