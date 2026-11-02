extends RefCounted
## Puzle de tornillos (estilo Screw Jam / Wood Nuts): reglas, reparto, bot y analizador.
## 1 - Mapa (game.json -> levels[i].map): una linea por placa, de abajo arriba:
##     "x,y,w,h:sx,sy;sx,sy" = placa de w x h casillas desde (x,y) y sus tornillos en las
##     casillas (sx,sy), que tienen que estar dentro de la placa. "#semilla" al final.
## 2 - Un tornillo esta libre si ninguna placa mas alta (que siga puesta) pisa su casilla. Al
##     tocarlo va a la caja de su color si hay una abierta con sitio; si no, a los huecos de
##     espera. Una placa sin tornillos cae. Una caja con 3 tornillos se va y llega la siguiente,
##     que se lleva los de su color que esperaban.
## 3 - Se gana al quitar todos los tornillos. Se pierde con los huecos de espera llenos y
##     ningun tornillo libre que vaya a una caja (con usos de HUECO EXTRA, se puede seguir).
## 4 - Reparto: se quitan tornillos libres al azar hasta vaciar (las placas caen igual que al
##     jugar) y cada tres seguidos reciben un color; las cajas llegan en ese orden, asi que
##     siempre hay una forma de ganar sin usar los huecos.
## Parametros: "kinds" (colores, 3-8), "boxes" (cajas abiertas a la vez, 1-3), "hold" (huecos
## de espera, 3-7), "extra" (usos del hueco extra) y "par" (segundos).

const KINDS_MAX: int = 8
const BOX: int = 3
const HOLD_MAX: int = 9
const COLS: int = 7
const ROWS: int = 9


## Lee las placas. Las mal escritas, fuera del tablero o sin tornillos validos se ignoran.
static func parse(level: Dictionary) -> Dictionary:
	var plates: Array = []
	var screws: Array = []
	var seed_v: int = int(level.get("seed", 1))
	var used: Dictionary = {}
	for r: Variant in level.get("map", []):
		var row: String = str(r).strip_edges()
		if row.begins_with("#") and row.substr(1).is_valid_int():
			seed_v = int(row.substr(1))
			continue
		var parts: PackedStringArray = row.split(":")
		if parts.size() != 2:
			continue
		var g: PackedStringArray = parts[0].split(",")
		if g.size() != 4:
			continue
		var ok: bool = true
		for v: String in g:
			if not v.strip_edges().is_valid_int():
				ok = false
		if not ok:
			continue
		var rect: Rect2i = Rect2i(int(g[0]), int(g[1]), int(g[2]), int(g[3]))
		if rect.size.x < 1 or rect.size.y < 1 or rect.position.x < 0 or rect.position.y < 0 or rect.end.x > COLS or rect.end.y > ROWS:
			continue
		var mine: Array = []
		for s: String in parts[1].split(";", false):
			var c: PackedStringArray = s.split(",")
			if c.size() != 2 or not c[0].strip_edges().is_valid_int() or not c[1].strip_edges().is_valid_int():
				continue
			var cell: Vector2i = Vector2i(int(c[0]), int(c[1]))
			if not rect.has_point(cell) or used.has(cell):
				continue
			used[cell] = true
			mine.append(cell)
		if mine.is_empty():
			continue
		var pid: int = plates.size()
		plates.append({"id": pid, "rect": rect, "gone": false})
		for cell2: Vector2i in mine:
			screws.append({"id": screws.size(), "plate": pid, "cell": cell2, "color": -1, "gone": false})
	if screws.size() < 3:
		plates = [{"id": 0, "rect": Rect2i(1, 3, 5, 2), "gone": false}]
		screws = []
		for k: int in 3:
			screws.append({"id": k, "plate": 0, "cell": Vector2i(1 + k * 2, 3 + k % 2), "color": -1, "gone": false})
	## Siempre multiplo de 3: sobran los ultimos de las placas de arriba que tengan otro.
	var i: int = screws.size() - 1
	while screws.size() % 3 != 0 and i >= 0:
		var pid2: int = int(screws[i]["plate"])
		var n: int = 0
		for s2: Dictionary in screws:
			if int(s2["plate"]) == pid2:
				n += 1
		if n > 1:
			screws.remove_at(i)
		i -= 1
	while screws.size() % 3 != 0:
		var last: int = int(screws[screws.size() - 1]["plate"])
		screws = screws.filter(func(s3: Dictionary) -> bool: return int(s3["plate"]) != last)
		plates.remove_at(plates.size() - 1)
	for k2: int in screws.size():
		screws[k2]["id"] = k2
	return {"plates": plates, "screws": screws, "seed": seed_v}


static func new_state(level: Dictionary) -> Dictionary:
	var info: Dictionary = parse(level)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(info["seed"])
	var st: Dictionary = {"plates": info["plates"], "screws": info["screws"], "rng": rng, "over": false, "won": false,
		"stuck": false, "events": [], "kinds": clampi(int(level.get("kinds", 5)), 3, KINDS_MAX),
		"hold_max": clampi(int(level.get("hold", 5)), 3, 7), "extra": clampi(int(level.get("extra", 1)), 0, 9),
		"boxes": [], "queue": [], "hold": [], "moves": 0, "cleared": 0}
	var nb: int = clampi(int(level.get("boxes", 2)), 1, 3)
	deal(st)
	for b: int in nb:
		st["boxes"].append(_next_box(st))
	return st


static func _ev(st: Dictionary, kind: String, extra: Dictionary = {}) -> void:
	var e: Dictionary = {"kind": kind}
	e.merge(extra)
	(st["events"] as Array).append(e)


# ------------------------------------------------------------------ geometria

## Placas puestas que pisan la casilla del tornillo (las que estan encima de la suya).
static func is_free(st: Dictionary, id: int) -> bool:
	var s: Dictionary = st["screws"][id]
	if bool(s["gone"]):
		return false
	return _free_in(s, st["plates"])


static func _free_in(s: Dictionary, plates: Array) -> bool:
	for p: Dictionary in plates:
		if int(p["id"]) > int(s["plate"]) and not bool(p["gone"]) and (p["rect"] as Rect2i).has_point(s["cell"] as Vector2i):
			return false
	return true


static func on_board(st: Dictionary) -> Array:
	var out: Array = []
	for s: Dictionary in st["screws"]:
		if not bool(s["gone"]):
			out.append(s)
	return out


static func free_screws(st: Dictionary) -> Array:
	var out: Array = []
	for s: Dictionary in st["screws"]:
		if not bool(s["gone"]) and _free_in(s, st["plates"]):
			out.append(s)
	return out


static func plate_left(st: Dictionary, pid: int) -> int:
	var n: int = 0
	for s: Dictionary in st["screws"]:
		if int(s["plate"]) == pid and not bool(s["gone"]):
			n += 1
	return n


# ------------------------------------------------------------------ reparto

## Orden de jugadas que vacia el tablero quitando tornillos libres al azar (las placas caen
## en cuanto se quedan sin tornillos, como en el juego).
static func plan_order(st: Dictionary) -> Array:
	var rng: RandomNumberGenerator = st["rng"]
	var plates: Array = []
	for p: Dictionary in st["plates"]:
		plates.append({"id": int(p["id"]), "rect": p["rect"], "gone": false})
	var left: Array = (st["screws"] as Array).duplicate()
	var count: Dictionary = {}
	for s: Dictionary in left:
		count[int(s["plate"])] = int(count.get(int(s["plate"]), 0)) + 1
	var order: Array = []
	while not left.is_empty():
		var free: Array = []
		for s2: Dictionary in left:
			if _free_in(s2, plates):
				free.append(s2)
		if free.is_empty():
			return []
		var pick: Dictionary = free[rng.randi_range(0, free.size() - 1)]
		order.append(pick)
		left.erase(pick)
		var pid: int = int(pick["plate"])
		count[pid] = int(count[pid]) - 1
		if int(count[pid]) <= 0:
			plates[pid]["gone"] = true
	return order


## Colores: cada tres del orden de jugadas, uno; las cajas llegan en ese mismo orden.
static func deal(st: Dictionary) -> bool:
	var order: Array = plan_order(st)
	if order.is_empty():
		return false
	var kinds: int = int(st["kinds"])
	var cycle: Array = range(kinds)
	var queue: Array = []
	var last: int = -1
	for i: int in order.size() / 3:
		if i % kinds == 0:
			cycle.shuffle()
			## Que no lleguen dos cajas seguidas del mismo color al cambiar de vuelta.
			if int(cycle[0]) == last and kinds > 1:
				cycle.push_back(cycle.pop_front())
		var col: int = int(cycle[i % kinds])
		last = col
		queue.append(col)
		for k: int in 3:
			(order[i * 3 + k] as Dictionary)["color"] = col
	st["queue"] = queue
	return true


static func _next_box(st: Dictionary) -> Dictionary:
	var q: Array = st["queue"]
	if q.is_empty():
		return {"color": -1, "ids": []}
	return {"color": int(q.pop_front()), "ids": []}


# ------------------------------------------------------------------ jugar

## Caja abierta de ese color con sitio (-1 si no hay).
static func box_for(st: Dictionary, color: int) -> int:
	var boxes: Array = st["boxes"]
	for i: int in boxes.size():
		if int(boxes[i]["color"]) == color and (boxes[i]["ids"] as Array).size() < BOX:
			return i
	return -1


static func can_place(st: Dictionary, s: Dictionary) -> bool:
	return box_for(st, int(s["color"])) >= 0 or (st["hold"] as Array).size() < int(st["hold_max"])


## Toca un tornillo. Devuelve true si se ha quitado.
static func pick(st: Dictionary, id: int) -> bool:
	if bool(st["over"]) or id < 0 or id >= (st["screws"] as Array).size() or not is_free(st, id):
		return false
	var s: Dictionary = st["screws"][id]
	if not can_place(st, s):
		return false
	s["gone"] = true
	st["moves"] = int(st["moves"]) + 1
	var b: int = box_for(st, int(s["color"]))
	if b >= 0:
		(st["boxes"][b]["ids"] as Array).append(id)
		_ev(st, "pick", {"id": id, "box": b, "slot": (st["boxes"][b]["ids"] as Array).size() - 1})
	else:
		(st["hold"] as Array).append({"id": id, "color": int(s["color"])})
		_ev(st, "pick", {"id": id, "hold": (st["hold"] as Array).size() - 1})
	var pid: int = int(s["plate"])
	if plate_left(st, pid) == 0:
		st["plates"][pid]["gone"] = true
		_ev(st, "fall", {"plate": pid})
	_settle(st)
	_check_end(st)
	return true


## Cajas llenas se van; la siguiente se lleva de la espera los de su color (y puede llenarse).
static func _settle(st: Dictionary) -> void:
	var boxes: Array = st["boxes"]
	var again: bool = true
	while again:
		again = false
		for i: int in boxes.size():
			if (boxes[i]["ids"] as Array).size() >= BOX:
				st["cleared"] = int(st["cleared"]) + BOX
				_ev(st, "boxdone", {"box": i, "color": int(boxes[i]["color"]), "ids": (boxes[i]["ids"] as Array).duplicate()})
				boxes[i] = _next_box(st)
				_pull_hold(st, i)
				again = true


static func _pull_hold(st: Dictionary, i: int) -> void:
	var box: Dictionary = st["boxes"][i]
	var hold: Array = st["hold"]
	var k: int = 0
	while k < hold.size() and (box["ids"] as Array).size() < BOX:
		if int(hold[k]["color"]) == int(box["color"]) and int(box["color"]) >= 0:
			(box["ids"] as Array).append(int(hold[k]["id"]))
			_ev(st, "unhold", {"id": int(hold[k]["id"]), "box": i, "slot": (box["ids"] as Array).size() - 1})
			hold.remove_at(k)
		else:
			k += 1


static func _check_end(st: Dictionary) -> void:
	st["stuck"] = false
	if on_board(st).is_empty() and (st["hold"] as Array).is_empty():
		st["over"] = true
		st["won"] = true
		_ev(st, "end", {"won": true})
		return
	for s: Dictionary in free_screws(st):
		if can_place(st, s):
			return
	if int(st["extra"]) > 0 and int(st["hold_max"]) < HOLD_MAX:
		st["stuck"] = true
		_ev(st, "stuck")
		return
	st["over"] = true
	st["won"] = false
	_ev(st, "end", {"won": false})


## Ayuda: un hueco de espera mas.
static func use_extra(st: Dictionary) -> bool:
	if int(st["extra"]) <= 0 or bool(st["over"]) or int(st["hold_max"]) >= HOLD_MAX:
		return false
	st["extra"] = int(st["extra"]) - 1
	st["hold_max"] = int(st["hold_max"]) + 1
	_ev(st, "extra")
	_check_end(st)
	return true


# ------------------------------------------------------------------ bot

## Un jugador sensato: llena cajas (antes la que esta casi llena), suelta placas, mira una
## jugada por delante y solo usa la espera para el color que llega antes.
static func bot_move(st: Dictionary) -> Dictionary:
	if bool(st["over"]):
		return {}
	var free: Array = free_screws(st)
	var best: int = -1
	var bs: float = -INF
	var room: int = int(st["hold_max"]) - (st["hold"] as Array).size()
	for s: Dictionary in free:
		if not can_place(st, s):
			continue
		var sc: float = 0.0
		var b: int = box_for(st, int(s["color"]))
		if b >= 0:
			sc = 100.0 + 10.0 * float((st["boxes"][b]["ids"] as Array).size())
		else:
			var qi: int = (st["queue"] as Array).find(int(s["color"]))
			sc = 20.0 - 4.0 * float(qi if qi >= 0 else 12)
			if room <= 1:
				sc -= 60.0
		## Una jugada por delante: cuantas jugadas a caja deja abiertas.
		var sim: Dictionary = _clone(st)
		pick(sim, int(s["id"]))
		if bool(sim["won"]):
			return {"pick": int(s["id"])}
		if bool(sim["over"]):
			sc -= 500.0
		var good: int = 0
		for s2: Dictionary in free_screws(sim):
			if box_for(sim, int(s2["color"])) >= 0:
				good += 1
		sc += 6.0 * float(mini(good, 4)) - 8.0 * float((sim["hold"] as Array).size())
		if plate_left(st, int(s["plate"])) == 1:
			sc += 8.0
		if sc > bs:
			bs = sc
			best = int(s["id"])
	## Sin jugada (o solo una que pierde): hueco extra si queda.
	if (best < 0 or bs < -300.0) and int(st["extra"]) > 0 and int(st["hold_max"]) < HOLD_MAX:
		return {"extra": true}
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
	if m.has("extra"):
		use_extra(st)
	elif m.has("pick"):
		pick(st, int(m["pick"]))


static func bot_play(level: Dictionary) -> Dictionary:
	var st: Dictionary = new_state(level)
	var guard: int = 0
	while not bool(st["over"]) and guard < 1000:
		var before: int = int(st["moves"]) + int(st["extra"]) * 1000
		bot_step(st)
		(st["events"] as Array).clear()
		guard += 1
		if int(st["moves"]) + int(st["extra"]) * 1000 == before:
			break
	return {"won": bool(st["won"]), "moves": int(st["moves"]), "extra_left": int(st["extra"])}


# ------------------------------------------------------------------ analizador

static func analyze(level: Dictionary) -> Dictionary:
	var info: Dictionary = parse(level)
	var issues: Array[String] = []
	var n: int = (info["screws"] as Array).size()
	var raw: int = 0
	for r: Variant in level.get("map", []):
		if not str(r).begins_with("#"):
			raw += 1
	if n < 6:
		issues.append("screw_small")
	if (info["plates"] as Array).size() < raw:
		issues.append("screw_bad_plate")
	var wins: int = 0
	if issues.is_empty():
		var base: int = int(info["seed"])
		for k: int in 3:
			var lv: Dictionary = level.duplicate()
			var rows: Array = []
			for r2: Variant in level.get("map", []):
				if not (str(r2).begins_with("#") and str(r2).substr(1).is_valid_int()):
					rows.append(r2)
			rows.append("#%d" % (base + k * 97))
			lv["map"] = rows
			if bool(bot_play(lv)["won"]):
				wins += 1
		if wins < 2:
			issues.append("screw_too_hard")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": 0, "enemies": 0, "enemy_problems": [],
		"par": int(float(n) * 2.2) + 10, "wins": wins}
