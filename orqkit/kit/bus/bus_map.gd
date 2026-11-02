extends RefCounted
## Bus jam (estilo Bus Jam / Bus Out): reglas, reparto, bot y analizador.
## 1 - Mapa (game.json -> levels[i].map): "P" pasajero, "." hueco libre, "#" pared. La salida es
##     el borde de arriba: un pasajero sale si hay camino por huecos libres (arriba, abajo,
##     izquierda, derecha) hasta la primera fila, o si ya esta en ella. "#semilla" al final.
## 2 - Al salir va al autobus si es de su color y le queda sitio; si no, a la parada (huecos de
##     espera). Un autobus con 3 se va y llega el siguiente, que recoge a los de su color que
##     esperaban. Cada pasajero que sale deja hueco y puede abrir camino a otros.
## 3 - Se gana al subir a todos. Se pierde con la parada llena y ningun pasajero que pueda salir
##     a un autobus (con la ayuda VIP, que saca a cualquiera aunque este encerrado, se sigue).
## 4 - Reparto: se sacan pasajeros con camino al azar hasta vaciar; cada tres seguidos reciben un
##     color y los autobuses llegan en ese orden, asi que siempre hay forma de ganar.
## Parametros: "kinds" (colores, 3-8), "buses" (autobuses a la vez, 1-2), "hold" (parada, 3-7),
## "vip" (usos) y "par" (segundos).

const KINDS_MAX: int = 8
const SEATS: int = 3
const HOLD_MAX: int = 9
const DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]


static func parse(level: Dictionary) -> Dictionary:
	var rows: Array[String] = []
	var seed_v: int = int(level.get("seed", 1))
	for r: Variant in level.get("map", []):
		var row: String = str(r)
		if row.begins_with("#") and row.substr(1).is_valid_int():
			seed_v = int(row.substr(1))
			continue
		rows.append(row)
	var w: int = 0
	for row2: String in rows:
		w = maxi(w, row2.length())
	var walls: Dictionary = {}
	var people: Array = []
	for y: int in rows.size():
		for x: int in w:
			var ch: String = rows[y][x] if x < rows[y].length() else "#"
			if ch == "#":
				walls[Vector2i(x, y)] = true
			elif ch == "P":
				people.append({"id": people.size(), "cell": Vector2i(x, y), "color": -1, "gone": false})
	var fallback: bool = people.size() < 3
	if fallback:
		rows = ["...", "PPP"]
		w = 3
		walls = {}
		people = []
		for k: int in 3:
			people.append({"id": k, "cell": Vector2i(k, 1), "color": -1, "gone": false})
	## Siempre multiplo de 3 (sobran los de mas abajo).
	while people.size() % 3 != 0:
		people.pop_back()
	return {"w": w, "h": rows.size(), "walls": walls, "people": people, "seed": seed_v, "fallback": fallback}


static func new_state(level: Dictionary) -> Dictionary:
	var info: Dictionary = parse(level)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(info["seed"])
	var st: Dictionary = {"w": info["w"], "h": info["h"], "walls": info["walls"], "people": info["people"], "rng": rng,
		"over": false, "won": false, "stuck": false, "events": [], "kinds": clampi(int(level.get("kinds", 4)), 3, KINDS_MAX),
		"hold_max": clampi(int(level.get("hold", 5)), 3, 7), "vip": clampi(int(level.get("vip", 1)), 0, 9),
		"buses": [], "queue": [], "hold": [], "moves": 0, "boarded": 0}
	deal(st)
	for b: int in clampi(int(level.get("buses", 1)), 1, 2):
		st["buses"].append(_next_bus(st))
	return st


static func _ev(st: Dictionary, kind: String, extra: Dictionary = {}) -> void:
	var e: Dictionary = {"kind": kind}
	e.merge(extra)
	(st["events"] as Array).append(e)


# ------------------------------------------------------------------ caminos

static func occupied(st: Dictionary) -> Dictionary:
	var occ: Dictionary = {}
	for p: Dictionary in st["people"]:
		if not bool(p["gone"]):
			occ[p["cell"]] = int(p["id"])
	return occ


## Camino de la casilla a la salida (lista de casillas, la ultima en la fila de arriba) o [].
static func path_out(st: Dictionary, from: Vector2i, occ: Dictionary) -> Array:
	if from.y == 0:
		return [from]
	var prev: Dictionary = {from: from}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if c.y == 0:
			var path: Array = [c]
			while prev[c] != c:
				c = prev[c]
				path.push_front(c)
			return path
		for d: Vector2i in DIRS:
			var n: Vector2i = c + d
			if n.x < 0 or n.y < 0 or n.x >= int(st["w"]) or n.y >= int(st["h"]) or prev.has(n):
				continue
			if (st["walls"] as Dictionary).has(n) or occ.has(n):
				continue
			prev[n] = c
			queue.append(n)
	return []


static func can_leave(st: Dictionary, id: int) -> bool:
	var p: Dictionary = st["people"][id]
	return not bool(p["gone"]) and not path_out(st, p["cell"], occupied(st)).is_empty()


static func free_people(st: Dictionary) -> Array:
	var occ: Dictionary = occupied(st)
	var out: Array = []
	for p: Dictionary in st["people"]:
		if not bool(p["gone"]) and not path_out(st, p["cell"], occ).is_empty():
			out.append(p)
	return out


static func left(st: Dictionary) -> int:
	var n: int = 0
	for p: Dictionary in st["people"]:
		if not bool(p["gone"]):
			n += 1
	return n


# ------------------------------------------------------------------ reparto

static func plan_order(st: Dictionary) -> Array:
	var rng: RandomNumberGenerator = st["rng"]
	var order: Array = []
	var occ: Dictionary = occupied(st)
	var left_people: Array = (st["people"] as Array).duplicate()
	while not left_people.is_empty():
		var free: Array = []
		for p: Dictionary in left_people:
			if not path_out(st, p["cell"], occ).is_empty():
				free.append(p)
		if free.is_empty():
			return []
		var pick: Dictionary = free[rng.randi_range(0, free.size() - 1)]
		order.append(pick)
		left_people.erase(pick)
		occ.erase(pick["cell"])
	return order


static func deal(st: Dictionary) -> bool:
	var order: Array = plan_order(st)
	if order.is_empty():
		## Encerrados sin salida: se reparten igual (el analizador rechaza el mapa).
		order = (st["people"] as Array).duplicate()
	var kinds: int = int(st["kinds"])
	var cycle: Array = range(kinds)
	var queue: Array = []
	var last: int = -1
	for i: int in order.size() / 3:
		if i % kinds == 0:
			cycle.shuffle()
			if int(cycle[0]) == last and kinds > 1:
				cycle.push_back(cycle.pop_front())
		var col: int = int(cycle[i % kinds])
		last = col
		queue.append(col)
		for k: int in 3:
			(order[i * 3 + k] as Dictionary)["color"] = col
	st["queue"] = queue
	return true


static func _next_bus(st: Dictionary) -> Dictionary:
	var q: Array = st["queue"]
	if q.is_empty():
		return {"color": -1, "ids": []}
	return {"color": int(q.pop_front()), "ids": []}


# ------------------------------------------------------------------ jugar

static func bus_for(st: Dictionary, color: int) -> int:
	var buses: Array = st["buses"]
	for i: int in buses.size():
		if int(buses[i]["color"]) == color and (buses[i]["ids"] as Array).size() < SEATS:
			return i
	return -1


static func can_place(st: Dictionary, p: Dictionary) -> bool:
	return bus_for(st, int(p["color"])) >= 0 or (st["hold"] as Array).size() < int(st["hold_max"])


## Toca un pasajero: sale si tiene camino (o con vip=true aunque no lo tenga).
static func pick(st: Dictionary, id: int, vip: bool = false) -> bool:
	if bool(st["over"]) or id < 0 or id >= (st["people"] as Array).size():
		return false
	var p: Dictionary = st["people"][id]
	if bool(p["gone"]) or not can_place(st, p):
		return false
	var path: Array = path_out(st, p["cell"], occupied(st))
	if path.is_empty() and not vip:
		return false
	if vip:
		if int(st["vip"]) <= 0:
			return false
		st["vip"] = int(st["vip"]) - 1
		path = []
	p["gone"] = true
	st["moves"] = int(st["moves"]) + 1
	var b: int = bus_for(st, int(p["color"]))
	if b >= 0:
		(st["buses"][b]["ids"] as Array).append(id)
		_ev(st, "leave", {"id": id, "path": path, "bus": b, "seat": (st["buses"][b]["ids"] as Array).size() - 1, "vip": vip})
	else:
		(st["hold"] as Array).append({"id": id, "color": int(p["color"])})
		_ev(st, "leave", {"id": id, "path": path, "hold": (st["hold"] as Array).size() - 1, "vip": vip})
	_settle(st)
	_check_end(st)
	return true


static func _settle(st: Dictionary) -> void:
	var buses: Array = st["buses"]
	var again: bool = true
	while again:
		again = false
		for i: int in buses.size():
			if (buses[i]["ids"] as Array).size() >= SEATS:
				st["boarded"] = int(st["boarded"]) + SEATS
				_ev(st, "depart", {"bus": i, "color": int(buses[i]["color"]), "ids": (buses[i]["ids"] as Array).duplicate()})
				buses[i] = _next_bus(st)
				_ev(st, "arrive", {"bus": i, "color": int(buses[i]["color"])})
				_pull_hold(st, i)
				again = true


static func _pull_hold(st: Dictionary, i: int) -> void:
	var bus: Dictionary = st["buses"][i]
	var hold: Array = st["hold"]
	var k: int = 0
	while k < hold.size() and (bus["ids"] as Array).size() < SEATS:
		if int(hold[k]["color"]) == int(bus["color"]) and int(bus["color"]) >= 0:
			(bus["ids"] as Array).append(int(hold[k]["id"]))
			_ev(st, "unhold", {"id": int(hold[k]["id"]), "bus": i, "seat": (bus["ids"] as Array).size() - 1})
			hold.remove_at(k)
		else:
			k += 1


static func _check_end(st: Dictionary) -> void:
	st["stuck"] = false
	if left(st) == 0 and (st["hold"] as Array).is_empty():
		st["over"] = true
		st["won"] = true
		_ev(st, "end", {"won": true})
		return
	for p: Dictionary in free_people(st):
		if can_place(st, p):
			return
	## Atascado: con VIP se puede sacar a uno del color del autobus (o a la parada si queda sitio).
	if int(st["vip"]) > 0 and _vip_target(st) >= 0:
		st["stuck"] = true
		_ev(st, "stuck")
		return
	st["over"] = true
	st["won"] = false
	_ev(st, "end", {"won": false})


static func _vip_target(st: Dictionary) -> int:
	for p: Dictionary in st["people"]:
		if not bool(p["gone"]) and bus_for(st, int(p["color"])) >= 0:
			return int(p["id"])
	for p2: Dictionary in st["people"]:
		if not bool(p2["gone"]) and can_place(st, p2):
			return int(p2["id"])
	return -1


# ------------------------------------------------------------------ bot

## Un jugador sensato: sube al autobus antes al que lo llena, despeja caminos y solo usa la
## parada para el color que llega antes; con un apuro usa el VIP.
static func bot_move(st: Dictionary) -> Dictionary:
	if bool(st["over"]):
		return {}
	var free: Array = free_people(st)
	var room: int = int(st["hold_max"]) - (st["hold"] as Array).size()
	var best: int = -1
	var bs: float = -INF
	var base_free: int = free.size()
	## Primero una nota rapida; solo los 6 mejores se miran una jugada por delante (mas rapido).
	var cands: Array = []
	for p: Dictionary in free:
		if not can_place(st, p):
			continue
		var sc: float = 0.0
		var b: int = bus_for(st, int(p["color"]))
		if b >= 0:
			sc = 100.0 + 10.0 * float((st["buses"][b]["ids"] as Array).size())
		else:
			var qi: int = (st["queue"] as Array).find(int(p["color"]))
			sc = 20.0 - 4.0 * float(qi if qi >= 0 else 12)
			if room <= 1:
				sc -= 60.0
		cands.append([sc, p])
	cands.sort_custom(func(a: Array, b2: Array) -> bool: return float(a[0]) > float(b2[0]))
	for c: Array in cands.slice(0, 6):
		var p2: Dictionary = c[1]
		var sc2: float = float(c[0])
		var sim: Dictionary = _clone(st)
		pick(sim, int(p2["id"]))
		if bool(sim["won"]):
			return {"pick": int(p2["id"])}
		if bool(sim["over"]):
			sc2 -= 500.0
		var good: int = 0
		var nf: Array = free_people(sim)
		for p3: Dictionary in nf:
			if bus_for(sim, int(p3["color"])) >= 0:
				good += 1
		sc2 += 6.0 * float(mini(good, 4)) + 2.0 * float(nf.size() - base_free) - 8.0 * float((sim["hold"] as Array).size())
		if sc2 > bs:
			bs = sc2
			best = int(p2["id"])
	if (best < 0 or bs < -300.0) and int(st["vip"]) > 0:
		var t: int = _vip_target(st)
		if t >= 0:
			return {"vip": t}
	if best < 0:
		return {}
	return {"pick": best}


static func _clone(st: Dictionary) -> Dictionary:
	var c: Dictionary = {}
	for k: String in st:
		if k == "rng":
			c[k] = st[k]
		elif k == "events":
			c[k] = []
		elif st[k] is Array or st[k] is Dictionary:
			c[k] = (st[k] as Variant).duplicate(true)
		else:
			c[k] = st[k]
	return c


static func bot_step(st: Dictionary) -> void:
	var m: Dictionary = bot_move(st)
	if m.has("vip"):
		pick(st, int(m["vip"]), true)
	elif m.has("pick"):
		pick(st, int(m["pick"]))


static func bot_play(level: Dictionary) -> Dictionary:
	var st: Dictionary = new_state(level)
	var guard: int = 0
	while not bool(st["over"]) and guard < 1000:
		var before: int = int(st["moves"])
		bot_step(st)
		(st["events"] as Array).clear()
		guard += 1
		if int(st["moves"]) == before:
			break
	return {"won": bool(st["won"]), "moves": int(st["moves"]), "vip_left": int(st["vip"])}


# ------------------------------------------------------------------ analizador

static func analyze(level: Dictionary) -> Dictionary:
	var info: Dictionary = parse(level)
	var issues: Array[String] = []
	var n: int = (info["people"] as Array).size()
	if n < 9 or bool(info["fallback"]):
		issues.append("bus_small")
	## Nadie puede quedar encerrado para siempre (sacando a los que tienen camino se vacia todo).
	var info_st: Dictionary = {"w": info["w"], "h": info["h"], "walls": info["walls"], "people": info["people"], "rng": RandomNumberGenerator.new()}
	if plan_order(info_st).is_empty():
		issues.append("bus_trapped")
	var wins: int = 0
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
			if bool(bot_play(lv)["won"]):
				wins += 1
		if wins < 2:
			issues.append("bus_too_hard")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": 0, "enemies": 0, "enemy_problems": [],
		"par": int(float(n) * 2.0) + 10, "wins": wins}
