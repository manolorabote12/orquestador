extends RefCounted
## Multitud (tipo Count Masters / el anuncio de Last War): tu grupo corre solo hacia delante; tu lo
## mueves a izquierda o derecha para pasar por las puertas que mas suman (+10, x2...) y no por las
## que restan, esquivar trampas y llegar al final con mas gente que el jefe.
## 1 - Nivel: "track": lista de cosas en orden de distancia "d":
##       {"t": "gate", "l": "+10", "r": "x2"}  dos puertas (operacion + - x /)
##       {"t": "enemy", "n": 20}               grupo enemigo: se restan unos a otros
##       {"t": "trap", "lane": "l"|"r", "k": 8} trampa en un carril: quita k si pasas por ahi
##       {"t": "boss", "n": 120}                el jefe al final: hay que llegar con mas
##     "start" (gente al empezar) y "speed" (metros por segundo). El mapa es ["multitud"].
## 2 - Todas las operaciones crecen con la gente que llevas: quedarse siempre con lo mayor es lo
##     mejor (asi el bot juega perfecto y el analizador sabe el mejor final posible).

const LANE_X: float = 0.5
const MAX_CROWD: int = 999
const Rules = preload("res://kit/rules.gd")


static func apply(n: int, op: String) -> int:
	var o: String = op.strip_edges()
	if o.length() < 2:
		return n
	var k: int = int(o.substr(1))
	match o[0]:
		"+":
			return mini(MAX_CROWD, n + k)
		"-":
			return maxi(0, n - k)
		"x":
			return mini(MAX_CROWD, n * maxi(1, k))
		"/":
			return n / maxi(1, k)
	return n


static func track(level: Dictionary) -> Array:
	var t: Array = (level.get("track", []) as Array).duplicate(true)
	t.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("d", 0)) < float(b.get("d", 0)))
	return t


static func new_state(level: Dictionary) -> Dictionary:
	var st: Dictionary = {"n": maxi(1, int(level.get("start", 1))), "x": 0.0, "d": 0.0, "i": 0, "track": track(level), "speed": clampf(float(level.get("speed", 7.0)), 3.0, 15.0),
		"won": false, "lost": false, "log": [], "rng": RandomNumberGenerator.new()}
	(st["rng"] as RandomNumberGenerator).seed = int(level.get("seed", 1))
	st["rules"] = Rules.load_rules(level)
	Rules.hook(st, "on_start")
	return st


static func lane_of(x: float) -> String:
	return "l" if x < 0.0 else "r"


## Avanza; cuando pasa por algo, se aplica con el carril de ese momento. Devuelve lo que paso.
static func step(st: Dictionary, dt: float) -> Array:
	var out: Array = []
	if bool(st["won"]) or bool(st["lost"]):
		return out
	st["d"] = float(st["d"]) + float(st["speed"]) * dt
	var tr: Array = st["track"]
	while int(st["i"]) < tr.size() and float(tr[int(st["i"])].get("d", 0)) <= float(st["d"]):
		var e: Dictionary = tr[int(st["i"])]
		st["i"] = int(st["i"]) + 1
		var before: int = int(st["n"])
		var lane: String = lane_of(float(st["x"]))
		match str(e.get("t", "")):
			"gate":
				st["n"] = apply(before, str(e.get(lane, "+0")))
			"enemy":
				st["n"] = maxi(0, before - int(e.get("n", 0)))
			"trap":
				if str(e.get("lane", "l")) == lane:
					st["n"] = maxi(0, before - int(e.get("k", 0)))
			"boss":
				if before > int(e.get("n", 0)):
					st["n"] = before - int(e.get("n", 0))
					st["won"] = true
				else:
					st["n"] = 0
		var info: Dictionary = {"e": e, "lane": lane, "before": before, "after": int(st["n"])}
		Rules.hook(st, "on_event", [info])
		info["after"] = int(st["n"])
		out.append(info)
		if int(st["n"]) <= 0:
			st["lost"] = true
			break
	if int(st["i"]) >= tr.size() and not bool(st["won"]) and not bool(st["lost"]):
		st["won"] = true
	return out


## Lo mejor que se puede llegar (el bot): en cada puerta la que mas deja y sin pisar trampas.
## Devuelve {"lanes": carril por cosa, "end": gente antes del jefe, "boss"}.
static func best(level: Dictionary) -> Dictionary:
	var n: int = maxi(1, int(level.get("start", 1)))
	var lanes: Array = []
	var boss: int = 0
	for e: Variant in track(level):
		var d: Dictionary = e
		match str(d.get("t", "")):
			"gate":
				var l: int = apply(n, str(d.get("l", "+0")))
				var r: int = apply(n, str(d.get("r", "+0")))
				lanes.append("l" if l >= r else "r")
				n = maxi(l, r)
			"enemy":
				lanes.append("")
				n = maxi(0, n - int(d.get("n", 0)))
			"trap":
				lanes.append("r" if str(d.get("lane", "l")) == "l" else "l")
			"boss":
				lanes.append("")
				boss = int(d.get("n", 0))
			_:
				lanes.append("")
		if n <= 0:
			break
	return {"lanes": lanes, "end": n, "boss": boss}


## El peor camino (siempre la puerta mala): para que haya que pensar.
static func worst(level: Dictionary) -> int:
	var n: int = maxi(1, int(level.get("start", 1)))
	for e: Variant in track(level):
		var d: Dictionary = e
		match str(d.get("t", "")):
			"gate":
				n = mini(apply(n, str(d.get("l", "+0"))), apply(n, str(d.get("r", "+0"))))
			"enemy":
				n = maxi(0, n - int(d.get("n", 0)))
			"trap":
				n = maxi(0, n - int(d.get("k", 0)))
		if n <= 0:
			return 0
	return n


## A que carril ir ahora (el de la siguiente cosa que importa).
static func bot_lane(st: Dictionary, lanes: Array) -> float:
	var tr: Array = st["track"]
	for i: int in range(int(st["i"]), tr.size()):
		if i < lanes.size() and str(lanes[i]) != "":
			return -LANE_X if str(lanes[i]) == "l" else LANE_X
	return float(st["x"])


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var tr: Array = track(level)
	if tr.is_empty() or str((tr.back() as Dictionary).get("t", "")) != "boss":
		issues.append("crowd_no_boss")
	for e: Variant in tr:
		if str((e as Dictionary).get("t", "")) == "gate":
			for side: String in ["l", "r"]:
				var op: String = str(e.get(side, ""))
				if op.length() < 2 or not "+-x/".contains(op[0]) or not op.substr(1).is_valid_int():
					issues.append("crowd_bad_gate")
	var b: Dictionary = best(level)
	if issues.is_empty():
		if int(b["end"]) <= int(b["boss"]):
			issues.append("crowd_too_hard")
		elif worst(level) > int(b["boss"]):
			issues.append("crowd_too_easy")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": 0, "enemies": 0, "enemy_problems": [], "end": b["end"], "boss": b["boss"]}
