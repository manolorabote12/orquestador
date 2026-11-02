extends RefCounted
## Hexa sort (estilo Hexa Sort / Hexa Puzzle): reglas, reparto, bot y analizador.
## 1 - Mapa (game.json -> levels[i].map): filas de casillas hexagonales (las impares van media
##     casilla a la derecha): "." libre, "#" piedra (no se usa), " " o "-" fuera del tablero y
##     "a".."h" una pila ya puesta con ese color arriba. "#semilla" al final.
## 2 - Cada turno hay 3 pilas para elegir (de 2 a 6 fichas, de 1 a 3 colores). Al poner una en una
##     casilla libre, las vecinas con el mismo color arriba le pasan esas fichas, y sigue en
##     cadena con lo que queda destapado. Una pila con 10 o mas del mismo color arriba se limpia.
## 3 - Se gana al limpiar "goal" fichas. Se pierde con el tablero lleno (si queda MARTILLO, que
##     rompe una pila entera, se puede seguir).
## 4 - Cada fusion junta dos tramos del mismo color en uno, asi que la cadena siempre acaba.
## Parametros: "kinds" (colores, 3-8), "goal" (fichas a limpiar), "hammer" (usos), "par".

const CLEAR: int = 10
const KINDS_MAX: int = 8
const OFFER: int = 3


static func dirs(y: int) -> Array[Vector2i]:
	if y % 2 == 1:
		return [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, -1), Vector2i(0, 1), Vector2i(1, 1)]
	return [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 1), Vector2i(0, 1)]


static func nbrs(st: Dictionary, c: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d: Vector2i in dirs(c.y):
		if (st["cells"] as Dictionary).has(c + d):
			out.append(c + d)
	return out


static func parse(level: Dictionary) -> Dictionary:
	var cells: Dictionary = {}
	var stones: Array = []
	var pre: Dictionary = {}
	var seed_v: int = int(level.get("seed", 1))
	var y: int = 0
	for r: Variant in level.get("map", []):
		var row: String = str(r)
		if row.begins_with("#") and row.substr(1).is_valid_int():
			seed_v = int(row.substr(1))
			continue
		for x: int in row.length():
			var ch: String = row[x]
			if ch == ".":
				cells[Vector2i(x, y)] = true
			elif ch == "#":
				stones.append(Vector2i(x, y))
			elif "abcdefgh".contains(ch):
				cells[Vector2i(x, y)] = true
				pre[Vector2i(x, y)] = "abcdefgh".find(ch)
		y += 1
	var fallback: bool = cells.size() < 7
	if fallback:
		cells = {}
		pre = {}
		for k: int in 12:
			cells[Vector2i(k % 4, k / 4)] = true
	return {"cells": cells, "stones": stones, "pre": pre, "seed": seed_v, "fallback": fallback}


static func new_state(level: Dictionary) -> Dictionary:
	var info: Dictionary = parse(level)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(info["seed"])
	var st: Dictionary = {"cells": {}, "stones": info["stones"], "rng": rng, "over": false, "won": false, "stuck": false,
		"events": [], "kinds": clampi(int(level.get("kinds", 4)), 3, KINDS_MAX), "goal": maxi(10, int(level.get("goal", 60))),
		"hammer": clampi(int(level.get("hammer", 1)), 0, 9), "cleared": 0, "moves": 0, "offer": []}
	for c: Vector2i in info["cells"]:
		st["cells"][c] = []
	for c2: Vector2i in info["pre"]:
		var top: int = int(info["pre"][c2]) % int(st["kinds"])
		var s: Array = []
		var other: int = (top + 1 + rng.randi_range(0, int(st["kinds"]) - 2)) % int(st["kinds"])
		for k: int in rng.randi_range(0, 2):
			s.append(other)
		for k2: int in rng.randi_range(2, 3):
			s.append(top)
		st["cells"][c2] = s
	_refill(st)
	return st


static func _ev(st: Dictionary, kind: String, extra: Dictionary = {}) -> void:
	var e: Dictionary = {"kind": kind}
	e.merge(extra)
	(st["events"] as Array).append(e)


## Una pila al azar: de 2 a 6 fichas en 1 a 3 tramos de colores distintos.
static func random_stack(st: Dictionary) -> Array:
	var rng: RandomNumberGenerator = st["rng"]
	var kinds: int = int(st["kinds"])
	var h: int = rng.randi_range(2, 6)
	var segs: int = 1
	var roll: float = rng.randf()
	if roll > 0.45:
		segs = 2 if roll < 0.87 else 3
	segs = mini(segs, h)
	var s: Array = []
	var last: int = -1
	for i: int in segs:
		var col: int = rng.randi_range(0, kinds - 1)
		if col == last:
			col = (col + 1) % kinds
		last = col
		var n: int = h / segs + (1 if i < h % segs else 0)
		for k: int in n:
			s.append(col)
	return s


static func _refill(st: Dictionary) -> void:
	var offer: Array = st["offer"]
	var any: bool = false
	for o: Variant in offer:
		if o != null:
			any = true
	if any:
		return
	offer.clear()
	for i: int in OFFER:
		offer.append(random_stack(st))
	_ev(st, "refill")


# ------------------------------------------------------------------ jugar

static func top(s: Array) -> int:
	return -1 if s.is_empty() else int(s[s.size() - 1])


static func run_len(s: Array) -> int:
	if s.is_empty():
		return 0
	var c: int = top(s)
	var n: int = 0
	for i: int in range(s.size() - 1, -1, -1):
		if int(s[i]) != c:
			break
		n += 1
	return n


static func empty_cells(st: Dictionary) -> Array:
	var out: Array = []
	for c: Vector2i in st["cells"]:
		if (st["cells"][c] as Array).is_empty():
			out.append(c)
	return out


## Pone la pila "i" de las ofrecidas en la casilla "c" y resuelve la cadena.
static func place(st: Dictionary, i: int, c: Vector2i) -> bool:
	if bool(st["over"]) or i < 0 or i >= (st["offer"] as Array).size() or st["offer"][i] == null:
		return false
	if not (st["cells"] as Dictionary).has(c) or not (st["cells"][c] as Array).is_empty():
		return false
	st["cells"][c] = (st["offer"][i] as Array).duplicate()
	st["offer"][i] = null
	st["moves"] = int(st["moves"]) + 1
	_ev(st, "place", {"offer": i, "cell": c, "stack": (st["cells"][c] as Array).duplicate()})
	resolve(st, c)
	_refill(st)
	_check_end(st)
	return true


## Cadena: la casilla recibe de sus vecinas lo de su color de arriba; lo destapado se mira despues.
static func resolve(st: Dictionary, start: Vector2i) -> void:
	var cells: Dictionary = st["cells"]
	var queue: Array[Vector2i] = [start]
	var guard: int = 0
	while not queue.is_empty() and guard < 500:
		guard += 1
		var x: Vector2i = queue.pop_front()
		var s: Array = cells[x]
		if s.is_empty():
			continue
		var c: int = top(s)
		for n: Vector2i in nbrs(st, x):
			var ns: Array = cells[n]
			if ns.is_empty() or top(ns) != c:
				continue
			var k: int = run_len(ns)
			for j: int in k:
				s.append(ns.pop_back())
			_ev(st, "move", {"from": n, "to": x, "n": k, "color": c})
			if not queue.has(n):
				queue.append(n)
		if run_len(s) >= CLEAR:
			var k2: int = run_len(s)
			for j2: int in k2:
				s.pop_back()
			st["cleared"] = int(st["cleared"]) + k2
			_ev(st, "clear", {"cell": x, "n": k2, "color": c})
			if not queue.has(x):
				queue.append(x)
			## Lo destapado alrededor tambien puede encajar ahora.
			for n2: Vector2i in nbrs(st, x):
				if not queue.has(n2) and not (cells[n2] as Array).is_empty():
					queue.append(n2)


static func _check_end(st: Dictionary) -> void:
	st["stuck"] = false
	if int(st["cleared"]) >= int(st["goal"]):
		st["over"] = true
		st["won"] = true
		_ev(st, "end", {"won": true})
		return
	if not empty_cells(st).is_empty():
		return
	if int(st["hammer"]) > 0:
		st["stuck"] = true
		_ev(st, "stuck")
		return
	st["over"] = true
	st["won"] = false
	_ev(st, "end", {"won": false})


## Ayuda: rompe la pila entera de una casilla (no cuenta para la meta).
static func hammer(st: Dictionary, c: Vector2i) -> bool:
	if int(st["hammer"]) <= 0 or bool(st["over"]) or not (st["cells"] as Dictionary).has(c) or (st["cells"][c] as Array).is_empty():
		return false
	var n: int = (st["cells"][c] as Array).size()
	st["cells"][c] = []
	st["hammer"] = int(st["hammer"]) - 1
	_ev(st, "hammer", {"cell": c, "n": n})
	_check_end(st)
	return true


# ------------------------------------------------------------------ bot

## Un jugador sensato: prueba cada pila en cada hueco y se queda con la que mas limpia y deja el
## tablero mas ordenado (pocos tramos, huecos libres y sin colores revueltos junto a los huecos).
static func bot_move(st: Dictionary) -> Dictionary:
	if bool(st["over"]):
		return {}
	var empties: Array = empty_cells(st)
	if empties.is_empty():
		if int(st["hammer"]) > 0:
			return {"hammer": _worst(st)}
		return {}
	var best: Dictionary = {}
	var bs: float = -INF
	for i: int in (st["offer"] as Array).size():
		if st["offer"][i] == null:
			continue
		for c: Vector2i in _candidates(st, empties, st["offer"][i]):
			var sim: Dictionary = _clone(st)
			place(sim, i, c)
			var sc: float = _score(sim) + 10.0 * float(int(sim["cleared"]) - int(st["cleared"]))
			if bool(sim["won"]):
				sc += 10000.0
			if sc > bs:
				bs = sc
				best = {"offer": i, "cell": c}
	## Casi lleno y sin limpiar nada: mejor romper la pila mas revuelta antes.
	if empties.size() <= 1 and int(st["hammer"]) > 0 and bs < _score(st) - 6.0:
		return {"hammer": _worst(st)}
	return best


## Huecos que merece la pena probar: los que juntan con su color de arriba y los mas apartados
## (con muchos huecos, probarlos todos solo hace lento al bot sin jugar mejor).
static func _candidates(st: Dictionary, empties: Array, stack: Array) -> Array:
	if empties.size() <= 10:
		return empties
	var out: Array = []
	var rest: Array = []
	for c: Vector2i in empties:
		var hit: bool = false
		var busy: int = 0
		for n: Vector2i in nbrs(st, c):
			var t: int = top(st["cells"][n])
			if t >= 0:
				busy += 1
			if t == top(stack):
				hit = true
		if hit:
			out.append(c)
		else:
			rest.append([busy, c])
	rest.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
	for k: int in mini(5, rest.size()):
		out.append(rest[k][1])
	return out


static func _score(st: Dictionary) -> float:
	var runs: int = 0
	var tiles: int = 0
	for c: Vector2i in st["cells"]:
		var s: Array = st["cells"][c]
		tiles += s.size()
		for i: int in s.size():
			if i == 0 or int(s[i]) != int(s[i - 1]):
				runs += 1
	var empties: Array = empty_cells(st)
	var mix: int = 0
	for e: Vector2i in empties:
		var seen: Dictionary = {}
		for n: Vector2i in nbrs(st, e):
			var t: int = top(st["cells"][n])
			if t >= 0:
				seen[t] = true
		mix += seen.size()
	## Tramos altos de un color cerca de limpiarse valen algo.
	var tall: float = 0.0
	for c2: Vector2i in st["cells"]:
		tall += float(run_len(st["cells"][c2])) * 0.25
	return -2.0 * float(runs) + 3.0 * float(empties.size()) - 0.5 * float(mix) + tall - 0.05 * float(tiles)


static func _worst(st: Dictionary) -> Vector2i:
	var best: Vector2i = Vector2i(-1, -1)
	var bw: int = -1
	for c: Vector2i in st["cells"]:
		var s: Array = st["cells"][c]
		var runs: int = 0
		for i: int in s.size():
			if i == 0 or int(s[i]) != int(s[i - 1]):
				runs += 1
		var w: int = runs * 10 + s.size()
		if not s.is_empty() and w > bw:
			bw = w
			best = c
	return best


static func _clone(st: Dictionary) -> Dictionary:
	var c: Dictionary = {}
	for k: String in st:
		if k == "rng":
			## Copia del generador: lo que salga despues no cambia la partida de verdad.
			var r: RandomNumberGenerator = RandomNumberGenerator.new()
			r.seed = (st[k] as RandomNumberGenerator).seed
			r.state = (st[k] as RandomNumberGenerator).state
			c[k] = r
		elif k == "events":
			c[k] = []
		elif st[k] is Array or st[k] is Dictionary:
			c[k] = (st[k] as Variant).duplicate(true)
		else:
			c[k] = st[k]
	return c


static func bot_step(st: Dictionary) -> void:
	var m: Dictionary = bot_move(st)
	if m.has("hammer"):
		hammer(st, m["hammer"])
	elif m.has("offer"):
		place(st, int(m["offer"]), m["cell"])


static func bot_play(level: Dictionary) -> Dictionary:
	var st: Dictionary = new_state(level)
	var guard: int = 0
	while not bool(st["over"]) and guard < 400:
		var before: int = int(st["moves"]) + int(st["hammer"]) * 1000
		bot_step(st)
		(st["events"] as Array).clear()
		guard += 1
		if int(st["moves"]) + int(st["hammer"]) * 1000 == before:
			break
	return {"won": bool(st["won"]), "moves": int(st["moves"]), "cleared": int(st["cleared"]), "hammer_left": int(st["hammer"])}


# ------------------------------------------------------------------ analizador

static func analyze(level: Dictionary) -> Dictionary:
	var info: Dictionary = parse(level)
	var issues: Array[String] = []
	var n: int = (info["cells"] as Dictionary).size()
	if n < 10 or bool(info["fallback"]):
		issues.append("hexa_small")
	if (info["pre"] as Dictionary).size() * 2 > n:
		issues.append("hexa_too_full")
	var wins: int = 0
	var moves: int = 0
	if issues.is_empty():
		var base: int = int(info["seed"])
		for k: int in 3:
			var lv: Dictionary = level.duplicate()
			var rows: Array = []
			for r: Variant in level.get("map", []):
				if not (str(r).begins_with("#") and str(r).substr(1).is_valid_int()):
					rows.append(r)
			rows.append("#%d" % (base + k * 97))
			lv["map"] = rows
			var res: Dictionary = bot_play(lv)
			moves += int(res["moves"])
			if bool(res["won"]):
				wins += 1
		if wins < 2:
			issues.append("hexa_too_hard")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": 0, "enemies": 0, "enemy_problems": [],
		"par": int(float(moves) / 3.0 * 4.0) + 20, "wins": wins}
