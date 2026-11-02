extends RefCounted
## Comecocos (tipo Pac-Man): laberinto de puntos. Te mueves de casilla en casilla (giras en cuanto
## se puede hacia donde pidas) y te comes los puntos; los fantasmas te persiguen cada uno a su
## manera, con ratos de dispersarse. Las pildoras grandes los asustan un rato: entonces se comen
## (y vuelven a su casa). Tres vidas. Te comes todos los puntos: ganas. Todo va por ticks.
## Mapa ("map"): "#" muro, "." punto, "o" pildora, " " vacio, "P" salida, "G" casa de los
## fantasmas (uno por "G"). Un pasillo que llega al borde da la vuelta al otro lado.
## Nivel: "speed" (casillas por tick del heroe), "ghost_speed", "fright" (ticks de susto), "lives".

const Rules = preload("res://kit/rules.gd")
const TPS: int = 10
const DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 0)]
## Personalidades por orden de salida: perseguidor, emboscador, tonto y caprichoso.
const KINDS: Array[String] = ["chase", "ambush", "shy", "fickle"]
const RELEASE: int = 30
const SHIELD: int = 20


static func new_state(level: Dictionary) -> Dictionary:
	var rows: Array = []
	var dots: Dictionary = {}
	var homes: Array = []
	var start: Vector2i = Vector2i(1, 1)
	var y: int = 0
	for r: Variant in level.get("map", []):
		var row: String = str(r)
		if row.begins_with("#") and row.length() > 1 and row.substr(1).is_valid_int():
			continue
		var clean: String = ""
		for x: int in row.length():
			var ch: String = row[x]
			var p: Vector2i = Vector2i(x, y)
			if ch == "." or ch == "o":
				dots[p] = ch
			elif ch == "P":
				start = p
			elif ch == "G":
				homes.append(p)
			clean += "#" if ch == "#" else " "
		rows.append(clean)
		y += 1
	var ghosts: Array = []
	for i: int in homes.size():
		ghosts.append({"k": KINDS[i % KINDS.size()], "p": homes[i], "from": homes[i], "home": homes[i], "dir": Vector2i(0, -1),
			"acc": 0.0, "out": i * RELEASE, "eaten": false, "frozen": 0})
	var st: Dictionary = {"map": rows, "w": (rows[0] as String).length() if not rows.is_empty() else 0, "h": rows.size(),
		"p": start, "from": start, "start": start, "dir": Vector2i.ZERO, "want": Vector2i.ZERO, "acc": 0.0,
		"speed": float(level.get("speed", 0.5)), "ghost_speed": float(level.get("ghost_speed", 0.38)), "fright_len": int(level.get("fright", 60)),
		"fright": 0, "combo": 0, "dots": dots, "dots_total": dots.size(), "ghosts": ghosts, "lives": int(level.get("lives", 3)), "deaths": 0,
		"shield": 0, "score": 0, "tick": 0, "won": false, "lost": false, "log": [], "rng": int(level.get("seed", 7)) * 7919 + 13}
	st["rules"] = Rules.load_rules(level)
	Rules.hook(st, "on_start")
	return st


static func wall(st: Dictionary, p: Vector2i) -> bool:
	if p.y < 0 or p.y >= int(st["h"]):
		return true
	var x: int = posmod(p.x, int(st["w"]))
	return (st["map"][p.y] as String)[x] == "#"


static func wrap_cell(st: Dictionary, p: Vector2i) -> Vector2i:
	return Vector2i(posmod(p.x, int(st["w"])), p.y)


static func _rand(st: Dictionary, n: int) -> int:
	st["rng"] = (int(st["rng"]) * 1103515245 + 12345) % 2147483648
	return int(st["rng"]) % maxi(1, n)


## Fase de los fantasmas: dispersarse (true) o perseguir. Ciclos de 7 s y 20 s.
static func scatter(st: Dictionary) -> bool:
	var t: int = int(st["tick"]) % 270
	return t < 70


## Un tick: want es la direccion que pide el jugador (se recuerda hasta que se puede girar).
static func tick(st: Dictionary, want: Vector2i) -> void:
	if bool(st["won"]) or bool(st["lost"]):
		return
	st["tick"] = int(st["tick"]) + 1
	if want != Vector2i.ZERO:
		st["want"] = want
	if int(st["fright"]) > 0:
		st["fright"] = int(st["fright"]) - 1
		if int(st["fright"]) == 0:
			st["combo"] = 0
	if int(st["shield"]) > 0:
		st["shield"] = int(st["shield"]) - 1
	## Heroe.
	st["from"] = st["p"]
	st["acc"] = float(st["acc"]) + float(st["speed"])
	while float(st["acc"]) >= 1.0:
		st["acc"] = float(st["acc"]) - 1.0
		var p: Vector2i = st["p"]
		var w: Vector2i = st["want"]
		if w != Vector2i.ZERO and not wall(st, p + w):
			st["dir"] = w
		var d: Vector2i = st["dir"]
		if d != Vector2i.ZERO and not wall(st, p + d):
			st["p"] = wrap_cell(st, p + d)
			_eat(st)
		_collide(st)
	## Fantasmas.
	for g: Variant in st["ghosts"]:
		_ghost(st, g)
	_collide(st)
	if (st["dots"] as Dictionary).is_empty():
		st["won"] = true


static func _eat(st: Dictionary) -> void:
	var p: Vector2i = st["p"]
	var d: String = str((st["dots"] as Dictionary).get(p, ""))
	if d == "":
		return
	(st["dots"] as Dictionary).erase(p)
	if d == "o":
		st["fright"] = int(st["fright_len"])
		st["combo"] = 0
		st["score"] = int(st["score"]) + 50
		for g: Variant in st["ghosts"]:
			if not bool(g["eaten"]):
				g["dir"] = -(g["dir"] as Vector2i)
		(st["log"] as Array).append({"k": "power", "at": p})
	else:
		st["score"] = int(st["score"]) + 10
		(st["log"] as Array).append({"k": "dot", "at": p})
	Rules.hook(st, "on_eat", [d])


static func frightened(st: Dictionary, g: Dictionary) -> bool:
	return int(st["fright"]) > 0 and not bool(g["eaten"])


static func _target(st: Dictionary, g: Dictionary) -> Vector2i:
	var p: Vector2i = st["p"]
	var w: int = int(st["w"])
	var h: int = int(st["h"])
	if bool(g["eaten"]):
		return g["home"]
	var corners: Array = [Vector2i(w - 2, 0), Vector2i(1, 0), Vector2i(1, h - 1), Vector2i(w - 2, h - 1)]
	var idx: int = KINDS.find(str(g["k"]))
	if scatter(st):
		return corners[idx]
	match str(g["k"]):
		"ambush":
			return p + (st["dir"] as Vector2i) * 4
		"shy":
			var gp: Vector2i = g["p"]
			return p if (gp - p).length_squared() > 64 else corners[idx]
		"fickle":
			var lead: Vector2i = p + (st["dir"] as Vector2i) * 2
			var first: Vector2i = (st["ghosts"][0] as Dictionary)["p"]
			return lead * 2 - first
	return p


static func _ghost(st: Dictionary, g: Dictionary) -> void:
	g["from"] = g["p"]
	if int(st["tick"]) < int(g["out"]):
		return
	if int(g["frozen"]) > 0:
		g["frozen"] = int(g["frozen"]) - 1
		return
	var sp: float = float(st["ghost_speed"])
	if bool(g["eaten"]):
		sp = 1.0
	elif frightened(st, g):
		sp *= 0.55
	g["acc"] = float(g["acc"]) + sp
	while float(g["acc"]) >= 1.0:
		g["acc"] = float(g["acc"]) - 1.0
		var at: Vector2i = g["p"]
		if bool(g["eaten"]) and at == g["home"]:
			g["eaten"] = false
			g["frozen"] = 15
			return
		var back: Vector2i = -(g["dir"] as Vector2i)
		var opts: Array = []
		for d: Vector2i in DIRS:
			if d != back and not wall(st, at + d):
				opts.append(d)
		if opts.is_empty() and not wall(st, at + back):
			opts.append(back)
		if opts.is_empty():
			return
		var pick: Vector2i = opts[0]
		if frightened(st, g):
			pick = opts[_rand(st, opts.size())]
		else:
			var tgt: Vector2i = _target(st, g)
			var best: float = INF
			for d2: Variant in opts:
				var q: Vector2i = at + (d2 as Vector2i)
				var dd: float = Vector2(q - tgt).length_squared()
				if dd < best:
					best = dd
					pick = d2
		g["dir"] = pick
		g["p"] = wrap_cell(st, at + pick)


static func _collide(st: Dictionary) -> void:
	if bool(st["lost"]):
		return
	var p: Vector2i = st["p"]
	for g: Variant in st["ghosts"]:
		if bool(g["eaten"]) or int(st["tick"]) < int(g["out"]):
			continue
		var touch: bool = g["p"] == p or (g["p"] == st["from"] and g["from"] == p)
		if not touch:
			continue
		if frightened(st, g):
			g["eaten"] = true
			st["combo"] = int(st["combo"]) + 1
			var pts: int = 100 * int(pow(2.0, float(int(st["combo"]))))
			st["score"] = int(st["score"]) + pts
			(st["log"] as Array).append({"k": "ghost", "at": g["p"], "n": pts})
			Rules.hook(st, "on_ghost", [str(g["k"])])
		elif int(st["shield"]) <= 0:
			_die(st)
			return


static func _die(st: Dictionary) -> void:
	(st["log"] as Array).append({"k": "dead", "at": st["p"]})
	st["deaths"] = int(st["deaths"]) + 1
	st["lives"] = int(st["lives"]) - 1
	if int(st["lives"]) <= 0:
		st["lost"] = true
		return
	## Todos a su sitio; los puntos comidos siguen comidos.
	st["p"] = st["start"]
	st["from"] = st["start"]
	st["dir"] = Vector2i.ZERO
	st["want"] = Vector2i.ZERO
	st["shield"] = SHIELD
	st["fright"] = 0
	var i: int = 0
	for g: Variant in st["ghosts"]:
		g["p"] = g["home"]
		g["from"] = g["home"]
		g["eaten"] = false
		g["dir"] = Vector2i(0, -1)
		g["out"] = int(st["tick"]) + 15 + i * RELEASE
		i += 1


# ------------------------------------------------------------------ bot

## Distancia por pasillos desde varias casillas a todas (BFS con vuelta por los bordes).
static func _bfs(st: Dictionary, sources: Array) -> Dictionary:
	var dist: Dictionary = {}
	var q: Array = []
	for s: Variant in sources:
		dist[s] = 0
		q.append(s)
	var i: int = 0
	while i < q.size():
		var c: Vector2i = q[i]
		i += 1
		for d: Vector2i in DIRS:
			var n: Vector2i = wrap_cell(st, c + d)
			if dist.has(n) or wall(st, n):
				continue
			dist[n] = int(dist[c]) + 1
			q.append(n)
	return dist


## Direccion del bot: la de la heuristica, salvo que al probarla (simulando los fantasmas de
## verdad unos segundos) te pillen; entonces la que mas aguante.
static func bot_dir(st: Dictionary) -> Vector2i:
	var pref: Vector2i = _bot_greedy(st)
	var p: Vector2i = st["p"]
	var close: bool = false
	for g: Variant in st["ghosts"]:
		if not bool(g["eaten"]) and not frightened(st, g) and absi((g["p"] as Vector2i).x - p.x) + absi((g["p"] as Vector2i).y - p.y) <= 9:
			close = true
	if not close or int(st["shield"]) > 0:
		return pref
	var cands: Array = []
	if pref != Vector2i.ZERO:
		cands.append(pref)
	for d: Vector2i in DIRS:
		if not cands.has(d) and not wall(st, p + d):
			cands.append(d)
	var best: Vector2i = pref
	var best_v: float = -INF
	for d2: Variant in cands:
		var v: float = _rollout(st, d2, 26)
		if d2 == pref:
			v += 0.5
		if v > best_v:
			best_v = v
			best = d2
	return best


## Cuanto aguanta (en ticks, y algo por los puntos) yendo hacia d y luego alejandose de los fantasmas.
static func _rollout(st: Dictionary, d: Vector2i, horizon: int) -> float:
	var s: Dictionary = st.duplicate(true)
	s["log"] = []
	var deaths: int = int(s["deaths"])
	var dots0: int = (s["dots"] as Dictionary).size()
	var want: Vector2i = d
	for t: int in horizon:
		tick(s, want)
		if int(s["deaths"]) > deaths or bool(s["lost"]):
			return float(t)
		if bool(s["won"]):
			return float(horizon) + 50.0
		## Despues del primer tramo: en cada cruce, el camino que mas aleja del fantasma cercano.
		if t >= 4:
			var at: Vector2i = s["p"]
			var far: float = -INF
			for dd: Vector2i in DIRS:
				if wall(s, at + dd) or dd == -(s["dir"] as Vector2i):
					continue
				var q: Vector2i = wrap_cell(s, at + dd)
				var near: float = INF
				for g: Variant in s["ghosts"]:
					if not bool(g["eaten"]) and not frightened(s, g):
						near = minf(near, float(absi((g["p"] as Vector2i).x - q.x) + absi((g["p"] as Vector2i).y - q.y)))
				if near > far:
					far = near
					want = dd
	return float(horizon) + float(dots0 - (s["dots"] as Dictionary).size()) * 0.1


static func _bot_greedy(st: Dictionary) -> Vector2i:
	var p: Vector2i = st["p"]
	var danger_src: Array = []
	var prey: Array = []
	for g: Variant in st["ghosts"]:
		if bool(g["eaten"]):
			continue
		if frightened(st, g) and int(st["fright"]) > 12:
			prey.append(g["p"])
		elif not frightened(st, g):
			danger_src.append(g["p"])
	var gd: Dictionary = _bfs(st, danger_src) if not danger_src.is_empty() else {}
	var ratio: float = float(st["ghost_speed"]) / maxf(0.01, float(st["speed"]))
	var shield: int = int(st["shield"])
	## BFS del heroe guardando el primer paso y si el camino es seguro.
	var first: Dictionary = {p: Vector2i.ZERO}
	var dist: Dictionary = {p: 0}
	var safe: Dictionary = {p: true}
	var q: Array = [p]
	var i: int = 0
	while i < q.size():
		var c: Vector2i = q[i]
		i += 1
		for d: Vector2i in DIRS:
			var n: Vector2i = wrap_cell(st, c + d)
			if dist.has(n) or wall(st, n):
				continue
			dist[n] = int(dist[c]) + 1
			first[n] = d if c == p else first[c]
			## Seguro si llego antes que cualquier fantasma (con margen).
			var mine: float = float(dist[n]) * ratio
			var theirs: float = float(gd.get(n, 999))
			safe[n] = bool(safe[c]) and (theirs - mine > 3.0 or float(dist[n]) * 1.0 / maxf(0.01, float(st["speed"])) < float(shield))
			q.append(n)
	var best: Vector2i = Vector2i(-1, -1)
	## 1 - Cazar fantasmas asustados que esten cerca.
	for pr: Variant in prey:
		if dist.has(pr) and int(dist[pr]) <= 6 and bool(safe.get(pr, false)):
			if best.x < 0 or int(dist[pr]) < int(dist[best]):
				best = pr
	## 2 - El punto seguro mas cercano (las pildoras, mejor si hay fantasmas cerca y peor si no).
	if best.x < 0:
		var near_threat: bool = not gd.is_empty() and int(gd.get(p, 999)) <= 5
		var best_cost: float = INF
		for k: Variant in st["dots"]:
			if not dist.has(k) or not bool(safe.get(k, false)):
				continue
			var cost: float = float(dist[k])
			if str(st["dots"][k]) == "o":
				cost += -6.0 if near_threat else 6.0
			if cost < best_cost:
				best_cost = cost
				best = k
	## 3 - Ninguno seguro: el mas cercano igualmente (la prueba con fantasmas de bot_dir veta lo mortal).
	if best.x < 0:
		for k2: Variant in st["dots"]:
			if dist.has(k2) and (best.x < 0 or int(dist[k2]) < int(dist[best])):
				best = k2
	if best.x >= 0 and best != p:
		return first[best]
	## 4 - Huir: la casilla alcanzable donde mas tarden los fantasmas en llegar.
	var flee: Vector2i = Vector2i(-1, -1)
	var far: float = -INF
	for c2: Variant in dist:
		if c2 == p:
			continue
		var margin: float = float(gd.get(c2, 999)) - float(dist[c2]) * ratio
		if margin > far:
			far = margin
			flee = c2
	return first[flee] if flee.x >= 0 else Vector2i.ZERO


static func bot_play(level: Dictionary, max_ticks: int = 6000) -> Dictionary:
	var st: Dictionary = new_state(level)
	while not bool(st["won"]) and not bool(st["lost"]) and int(st["tick"]) < max_ticks:
		tick(st, bot_dir(st))
	return {"won": bool(st["won"]), "ticks": int(st["tick"]), "deaths": int(st["deaths"]), "left": (st["dots"] as Dictionary).size()}


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var st: Dictionary = new_state(level)
	if (st["dots"] as Dictionary).size() < 20:
		issues.append("chomp_few_dots")
	if (st["ghosts"] as Array).is_empty():
		issues.append("chomp_no_ghosts")
	var reach: Dictionary = _bfs(st, [st["start"]])
	for k: Variant in st["dots"]:
		if not reach.has(k):
			issues.append("chomp_unreachable_dot")
			break
	## Callejones sin salida: en un comecocos todo pasillo tiene que dar la vuelta.
	for y: int in int(st["h"]):
		for x: int in int(st["w"]):
			var c: Vector2i = Vector2i(x, y)
			if wall(st, c):
				continue
			var n: int = 0
			for d: Vector2i in DIRS:
				if not wall(st, c + d):
					n += 1
			if n <= 1:
				issues.append("chomp_dead_end")
				break
		if issues.has("chomp_dead_end"):
			break
	var r: Dictionary = {"won": false, "ticks": 0, "deaths": 0}
	if issues.is_empty():
		r = bot_play(level)
		if not bool(r["won"]) or int(r["deaths"]) > 1:
			issues.append("chomp_bot_failed")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": 0, "enemies": (st["ghosts"] as Array).size(),
		"enemy_problems": [], "bot": r}
