extends RefCounted
## 2048: desliza el tablero hacia un lado; las fichas iguales que chocan se suman en una. Tras cada
## movimiento sale una ficha nueva (2, o 4 a veces). Se gana al hacer la ficha objetivo; se pierde si
## no queda ningun movimiento. Las rocas no se mueven y cortan la fila.
## Nivel: "size" (lado 3-6), "target" (ficha objetivo), "rocks" (casillas fijas [[x, y], ...]),
## "start" (fichas iniciales [[x, y, valor], ...]; si no hay, salen dos al azar), "seed" (el azar de
## las fichas nuevas: con la misma semilla y las mismas jugadas sale lo mismo) y "undo" (deshacer).

const Rules = preload("res://kit/rules.gd")
const ROCK: int = -1
const DIRS: Dictionary = {"l": Vector2i(-1, 0), "r": Vector2i(1, 0), "u": Vector2i(0, -1), "d": Vector2i(0, 1)}


static func new_state(level: Dictionary) -> Dictionary:
	var n: int = clampi(int(level.get("size", 4)), 3, 6)
	var b: Array = []
	b.resize(n * n)
	b.fill(0)
	for r: Variant in level.get("rocks", []):
		var x: int = int(r[0])
		var y: int = int(r[1])
		if x >= 0 and y >= 0 and x < n and y < n:
			b[y * n + x] = ROCK
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(level.get("seed", 1))
	var st: Dictionary = {"n": n, "b": b, "target": maxi(4, int(level.get("target", 128))), "score": 0, "moves": 0, "best": 0,
		"undo": clampi(int(level.get("undo", 2)), 0, 9), "prev": {}, "won": false, "lost": false, "rng": rng}
	var start: Array = level.get("start", [])
	if start.is_empty():
		_spawn(st)
		_spawn(st)
	else:
		for t: Variant in start:
			b[int(t[1]) * n + int(t[0])] = int(t[2])
	st["best"] = max_tile(st)
	st["rules"] = Rules.load_rules(level)
	Rules.hook(st, "on_start")
	return st


static func max_tile(st: Dictionary) -> int:
	var m: int = 0
	for v: Variant in st["b"]:
		m = maxi(m, int(v))
	return m


## Ficha nueva en un hueco al azar (de la semilla): 2 casi siempre, 4 una de cada diez.
static func _spawn(st: Dictionary) -> int:
	var empty: Array = []
	var b: Array = st["b"]
	for i: int in b.size():
		if int(b[i]) == 0:
			empty.append(i)
	if empty.is_empty():
		return -1
	var rng: RandomNumberGenerator = st["rng"]
	var at: int = int(empty[rng.randi_range(0, empty.size() - 1)])
	b[at] = 4 if rng.randf() < 0.1 else 2
	return at


## Las casillas de cada fila o columna, empezando por el lado hacia el que se desliza.
static func _lines(n: int, dir: String) -> Array:
	var out: Array = []
	for k: int in n:
		var line: Array = []
		for j: int in n:
			match dir:
				"l":
					line.append(k * n + j)
				"r":
					line.append(k * n + (n - 1 - j))
				"u":
					line.append(j * n + k)
				"d":
					line.append((n - 1 - j) * n + k)
		out.append(line)
	return out


## Desliza sin sacar ficha nueva. Devuelve {"moved", "gain", "anim": [{"from", "to", "v", "merge"}]}.
static func _slide(b: Array, n: int, dir: String) -> Dictionary:
	var gain: int = 0
	var anim: Array = []
	var moved: bool = false
	for line: Variant in _lines(n, dir):
		var seg_start: int = 0
		var cells: Array = line
		while seg_start < cells.size():
			## Tramo entre rocas.
			var seg: Array = []
			var k: int = seg_start
			while k < cells.size() and int(b[int(cells[k])]) != ROCK:
				seg.append(cells[k])
				k += 1
			var write: int = 0
			var last_v: int = 0
			var last_merged: bool = true
			var vals: Array = []
			for idx: Variant in seg:
				var v: int = int(b[int(idx)])
				if v == 0:
					continue
				if not last_merged and v == last_v:
					vals[vals.size() - 1] = v * 2
					gain += v * 2
					last_merged = true
					anim.append({"from": int(idx), "to": int(seg[write - 1]), "v": v, "merge": true})
					moved = true
				else:
					vals.append(v)
					last_v = v
					last_merged = false
					anim.append({"from": int(idx), "to": int(seg[write]), "v": v, "merge": false})
					if int(idx) != int(seg[write]):
						moved = true
					write += 1
			for s: int in seg.size():
				b[int(seg[s])] = int(vals[s]) if s < vals.size() else 0
			seg_start = k + 1
	return {"moved": moved, "gain": gain, "anim": anim}


static func can_move(st: Dictionary) -> bool:
	for d: String in ["l", "r", "u", "d"]:
		var b: Array = (st["b"] as Array).duplicate()
		if bool(_slide(b, int(st["n"]), d)["moved"]):
			return true
	return false


## Jugada: desliza, suma, saca ficha nueva y mira si se gana o se pierde. {} si no se mueve nada.
static func move(st: Dictionary, dir: String) -> Dictionary:
	if bool(st["won"]) or bool(st["lost"]) or not DIRS.has(dir):
		return {}
	var before: Dictionary = {"b": (st["b"] as Array).duplicate(), "score": int(st["score"]), "rng": (st["rng"] as RandomNumberGenerator).state}
	var r: Dictionary = _slide(st["b"], int(st["n"]), dir)
	if not bool(r["moved"]):
		return {}
	st["prev"] = before
	st["score"] = int(st["score"]) + int(r["gain"])
	st["moves"] = int(st["moves"]) + 1
	r["spawn"] = _spawn(st)
	st["best"] = maxi(int(st["best"]), max_tile(st))
	Rules.hook(st, "on_move", [dir, r])
	if max_tile(st) >= int(st["target"]):
		st["won"] = true
	elif not can_move(st):
		st["lost"] = true
	return r


## Deshacer la ultima jugada (el azar tambien vuelve atras: no se puede "pescar" otra ficha).
static func undo(st: Dictionary) -> bool:
	var p: Dictionary = st["prev"]
	if p.is_empty() or int(st["undo"]) <= 0 or bool(st["won"]):
		return false
	st["b"] = (p["b"] as Array).duplicate()
	st["score"] = int(p["score"])
	(st["rng"] as RandomNumberGenerator).state = int(p["rng"])
	st["undo"] = int(st["undo"]) - 1
	st["lost"] = false
	st["prev"] = {}
	return true


## Lo bueno que es un tablero para el bot: huecos, la ficha mayor en una esquina, filas ordenadas y
## vecinas parecidas.
static func _eval(b: Array, n: int) -> float:
	var empty: int = 0
	var mx: int = 0
	var smooth: float = 0.0
	var mono: float = 0.0
	for y: int in n:
		for x: int in n:
			var v: int = int(b[y * n + x])
			if v == 0:
				empty += 1
				continue
			if v < 0:
				continue
			mx = maxi(mx, v)
			var lv: float = log(float(v)) / log(2.0)
			if x + 1 < n and int(b[y * n + x + 1]) > 0:
				var r: float = log(float(b[y * n + x + 1])) / log(2.0)
				smooth -= absf(lv - r)
				mono += 1.0 if lv >= r else -0.5
			if y + 1 < n and int(b[(y + 1) * n + x]) > 0:
				var d: float = log(float(b[(y + 1) * n + x])) / log(2.0)
				smooth -= absf(lv - d)
				mono += 1.0 if lv >= d else -0.5
	var corner: float = 0.0
	for c: int in [0, n - 1, n * (n - 1), n * n - 1]:
		if int(b[c]) == mx:
			corner = 2.0 * log(float(mx)) / log(2.0)
	return float(empty) * 2.7 + smooth * 0.3 + mono * 0.6 + corner


## Jugada del bot: mira dos jugadas por delante (el azar es de la semilla, asi que lo sabe).
static func bot_move(st: Dictionary) -> String:
	var best: String = ""
	var bv: float = -INF
	for d: String in ["u", "l", "r", "d"]:
		var s1: Dictionary = _copy(st)
		var r: Dictionary = move(s1, d)
		if r.is_empty():
			continue
		var v: float = float(r["gain"]) * 0.05
		if bool(s1["won"]):
			return d
		var best2: float = -INF
		for d2: String in ["u", "l", "r", "d"]:
			var s2: Dictionary = _copy(s1)
			var r2: Dictionary = move(s2, d2)
			if r2.is_empty():
				continue
			best2 = maxf(best2, _eval(s2["b"], int(s2["n"])) + float(r2["gain"]) * 0.05 + (100.0 if bool(s2["won"]) else 0.0))
		v += best2 if best2 > -INF else _eval(s1["b"], int(s1["n"])) - 50.0
		if v > bv:
			bv = v
			best = d
	return best


static func _copy(st: Dictionary) -> Dictionary:
	var c: Dictionary = {"n": st["n"], "b": (st["b"] as Array).duplicate(), "target": st["target"], "score": st["score"], "moves": st["moves"],
		"best": st["best"], "undo": 0, "prev": {}, "won": st["won"], "lost": st["lost"], "rules": []}
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = (st["rng"] as RandomNumberGenerator).seed
	rng.state = (st["rng"] as RandomNumberGenerator).state
	c["rng"] = rng
	return c


static func bot_play(level: Dictionary, max_moves: int = 3000) -> Dictionary:
	var st: Dictionary = new_state(level)
	while int(st["moves"]) < max_moves and not bool(st["won"]) and not bool(st["lost"]):
		var d: String = bot_move(st)
		if d == "":
			break
		move(st, d)
	return {"won": bool(st["won"]), "moves": int(st["moves"]), "best": max_tile(st)}


## Analizador: tablero y objetivo posibles (el objetivo cabe en las casillas libres) y el bot llega.
static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var n: int = int(level.get("size", 0))
	var target: int = int(level.get("target", 0))
	if n < 3 or n > 6:
		issues.append("n2048_size")
	if target < 8 or (target & (target - 1)) != 0:
		issues.append("n2048_target")
	var rocks: int = (level.get("rocks", []) as Array).size()
	var free: int = n * n - rocks
	if free < 6 or target > int(pow(2.0, float(free + 1))):
		issues.append("n2048_no_room")
	var r: Dictionary = {"won": false, "moves": 0}
	if issues.is_empty():
		r = bot_play(level)
		if not bool(r["won"]):
			issues.append("n2048_unbeatable")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": 0, "enemies": 0, "enemy_problems": [], "bot_moves": r.get("moves", 0)}
