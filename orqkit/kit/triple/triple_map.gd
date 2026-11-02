extends RefCounted
## Triple de fichas (estilo Tile Master / Triple Tile): reglas, reparto, bot y analizador.
## 1 - Mapa (game.json -> levels[i].map): capas separadas por "=": en cada capa, "X" es una
##     ficha en esa columna y fila; las capas impares van desplazadas media ficha (abajo a la
##     derecha), asi que una ficha de arriba tapa hasta cuatro de la capa de abajo. "#semilla".
## 2 - Una ficha esta libre si ninguna de una capa mas alta la pisa. Al tocarla va a la bandeja
##     (al lado de las de su mismo dibujo); tres iguales en la bandeja desaparecen. Si la bandeja
##     se llena sin trio, se pierde. Se gana al vaciar el tablero.
## 3 - Reparto: desde el tablero lleno se quitan fichas libres de tres en tres y cada trio recibe
##     el mismo dibujo, asi que siempre hay una forma de ganar. Barajar reparte otra vez los
##     dibujos que quedan en el tablero con el mismo metodo.
## 4 - Ayudas: DESHACER (la ultima ficha vuelve a su sitio) y BARAJAR, con usos limitados.
## Parametros: "kinds" (dibujos distintos, 4-12), "tray" (huecos de la bandeja, 7), "undo" y
## "shuffle" (usos) y "par" (segundos).

const KINDS_MAX: int = 12
const TRIES: int = 80


static func parse(level: Dictionary) -> Dictionary:
	var tiles: Array = []
	var seed_v: int = int(level.get("seed", 1))
	var z: int = 0
	var started: bool = false
	var y: int = 0
	for r: Variant in level.get("map", []):
		var row: String = str(r)
		if row.begins_with("#") and row.substr(1).is_valid_int():
			seed_v = int(row.substr(1))
			continue
		if row.begins_with("="):
			if started:
				z += 1
			started = true
			y = 0
			continue
		started = true
		for x: int in row.length():
			if row[x] == "X":
				var off: float = 0.5 if z % 2 == 1 else 0.0
				tiles.append({"x": float(x) + off, "y": float(y) + off, "z": z})
		y += 1
	if tiles.size() < 6:
		tiles = []
		for k: int in 9:
			tiles.append({"x": float(k % 3), "y": float(k / 3), "z": 0})
	## Siempre multiplo de 3 (se quitan las ultimas de la capa mas alta si sobran).
	while tiles.size() % 3 != 0:
		tiles.pop_back()
	for i: int in tiles.size():
		tiles[i]["id"] = i
		tiles[i]["kind"] = -1
		tiles[i]["gone"] = false
	return {"tiles": tiles, "seed": seed_v}


static func new_state(level: Dictionary) -> Dictionary:
	var info: Dictionary = parse(level)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(info["seed"])
	var st: Dictionary = {"tiles": info["tiles"], "tray": [], "rng": rng, "over": false, "won": false, "events": [],
		"kinds": clampi(int(level.get("kinds", 6)), 4, KINDS_MAX), "tray_max": clampi(int(level.get("tray", 7)), 4, 9),
		"undo": clampi(int(level.get("undo", 2)), 0, 9), "shuffle": clampi(int(level.get("shuffle", 1)), 0, 9),
		"history": [], "moves": 0, "cleared": 0}
	deal(st, st["tiles"])
	return st


static func _ev(st: Dictionary, kind: String, extra: Dictionary = {}) -> void:
	var e: Dictionary = {"kind": kind}
	e.merge(extra)
	(st["events"] as Array).append(e)


# ------------------------------------------------------------------ geometria

static func covers(top: Dictionary, below: Dictionary) -> bool:
	return int(top["z"]) > int(below["z"]) and absf(float(top["x"]) - float(below["x"])) < 0.99 and absf(float(top["y"]) - float(below["y"])) < 0.99


static func is_free_in(t: Dictionary, pool: Array) -> bool:
	for u: Dictionary in pool:
		if u != t and covers(u, t):
			return false
	return true


static func on_board(st: Dictionary) -> Array:
	var out: Array = []
	for t: Dictionary in st["tiles"]:
		if not bool(t["gone"]):
			out.append(t)
	return out


static func free_tiles(st: Dictionary) -> Array:
	var board: Array = on_board(st)
	var out: Array = []
	for t: Dictionary in board:
		if is_free_in(t, board):
			out.append(t)
	return out


static func is_free(st: Dictionary, id: int) -> bool:
	var t: Dictionary = st["tiles"][id]
	return not bool(t["gone"]) and is_free_in(t, on_board(st))


# ------------------------------------------------------------------ reparto

## Orden de jugadas que vacia "pool" (fichas del tablero) cogiendo fichas libres de tres en tres.
## [] si no lo encuentra (no deberia: siempre hay alguna libre en lo alto).
static func plan_order(st: Dictionary, pool: Array) -> Array:
	var rng: RandomNumberGenerator = st["rng"]
	for attempt: int in TRIES:
		var left: Array = pool.duplicate()
		var order: Array = []
		var ok: bool = true
		while not left.is_empty():
			var free: Array = []
			for t: Dictionary in left:
				if is_free_in(t, left):
					free.append(t)
			if free.size() < 3:
				ok = false
				break
			for k: int in 3:
				var j: int = rng.randi_range(0, free.size() - 1)
				order.append(free[j])
				left.erase(free[j])
				free.remove_at(j)
		if ok:
			return order
	return []


## Da dibujos a "pool": cada tres del orden de jugadas, un dibujo (asi siempre hay forma de ganar).
static func deal(st: Dictionary, pool: Array) -> bool:
	var order: Array = plan_order(st, pool)
	if order.is_empty():
		return false
	var kinds: int = int(st["kinds"])
	var cycle: Array = range(kinds)
	for i: int in order.size() / 3:
		if i % kinds == 0:
			cycle.shuffle()
		for k: int in 3:
			(order[i * 3 + k] as Dictionary)["kind"] = int(cycle[i % kinds])
	return true


# ------------------------------------------------------------------ jugar

static func tray_count(st: Dictionary, kind: int) -> int:
	var n: int = 0
	for k: Variant in st["tray"]:
		if int(k["kind"]) == kind:
			n += 1
	return n


## Toca una ficha. Devuelve true si se ha movido a la bandeja.
static func pick(st: Dictionary, id: int) -> bool:
	if bool(st["over"]) or id < 0 or id >= (st["tiles"] as Array).size() or not is_free(st, id):
		return false
	var t: Dictionary = st["tiles"][id]
	var tray: Array = st["tray"]
	t["gone"] = true
	## Al lado de las de su dibujo (o al final).
	var at: int = tray.size()
	for i: int in range(tray.size() - 1, -1, -1):
		if int(tray[i]["kind"]) == int(t["kind"]):
			at = i + 1
			break
	tray.insert(at, {"id": id, "kind": int(t["kind"])})
	(st["history"] as Array).append(id)
	st["moves"] = int(st["moves"]) + 1
	_ev(st, "pick", {"id": id, "slot": at})
	if tray_count(st, int(t["kind"])) >= 3:
		var removed: Array = []
		for i2: int in range(tray.size() - 1, -1, -1):
			if int(tray[i2]["kind"]) == int(t["kind"]):
				removed.append(int(tray[i2]["id"]))
				tray.remove_at(i2)
		st["cleared"] = int(st["cleared"]) + 3
		## Lo que ya hizo trio no se puede deshacer (lo demas, si).
		for rid: Variant in removed:
			(st["history"] as Array).erase(int(rid))
		_ev(st, "triple", {"kind": int(t["kind"]), "ids": removed})
	if on_board(st).is_empty() and tray.is_empty():
		st["over"] = true
		st["won"] = true
		_ev(st, "end", {"won": true})
	elif tray.size() >= int(st["tray_max"]):
		st["over"] = true
		st["won"] = false
		_ev(st, "end", {"won": false})
	return true


static func undo(st: Dictionary) -> bool:
	var hist: Array = st["history"]
	if int(st["undo"]) <= 0 or hist.is_empty() or bool(st["over"]):
		return false
	var id: int = int(hist.pop_back())
	var tray: Array = st["tray"]
	for i: int in tray.size():
		if int(tray[i]["id"]) == id:
			tray.remove_at(i)
			break
	st["tiles"][id]["gone"] = false
	st["undo"] = int(st["undo"]) - 1
	_ev(st, "undo", {"id": id})
	return true


## Barajar: los dibujos que quedan en el tablero se reparten otra vez siguiendo un orden de
## jugadas que gana: primero completan lo que hay en la bandeja y luego van de tres en tres.
static func shuffle(st: Dictionary) -> bool:
	if int(st["shuffle"]) <= 0 or bool(st["over"]):
		return false
	var board: Array = on_board(st)
	var order: Array = plan_order(st, board)
	if order.is_empty():
		return false
	var avail: Dictionary = {}
	for t: Dictionary in board:
		avail[int(t["kind"])] = int(avail.get(int(t["kind"]), 0)) + 1
	var held: Dictionary = {}
	for k: Variant in st["tray"]:
		held[int(k["kind"])] = int(held.get(int(k["kind"]), 0)) + 1
	var rng: RandomNumberGenerator = st["rng"]
	for t2: Dictionary in order:
		var choice: int = -1
		for want: int in [2, 1]:
			for kd: int in held:
				if int(held[kd]) == want and int(avail.get(kd, 0)) > 0:
					choice = kd
					break
			if choice >= 0:
				break
		if choice < 0:
			var opts: Array = []
			for kd2: int in avail:
				if int(avail[kd2]) > 0:
					opts.append(kd2)
			choice = int(opts[rng.randi_range(0, opts.size() - 1)])
		t2["kind"] = choice
		avail[choice] = int(avail[choice]) - 1
		held[choice] = (int(held.get(choice, 0)) + 1) % 3
	st["shuffle"] = int(st["shuffle"]) - 1
	st["history"] = []
	_ev(st, "shuffle")
	return true


# ------------------------------------------------------------------ bot

## Un jugador sensato: completa trios, junta parejas cuando hay sitio, nunca llena la bandeja
## con sueltas y tira de deshacer o barajar si se ve en un apuro.
static func bot_move(st: Dictionary) -> Dictionary:
	var free: Array = free_tiles(st)
	if free.is_empty():
		return {}
	var tray: Array = st["tray"]
	var room: int = int(st["tray_max"]) - tray.size()
	var free_by: Dictionary = {}
	for t: Dictionary in free:
		free_by[int(t["kind"])] = int(free_by.get(int(t["kind"]), 0)) + 1
	var best: Dictionary = {}
	var bs: float = -INF
	for t2: Dictionary in free:
		var kd: int = int(t2["kind"])
		var inn: int = tray_count(st, kd)
		var s: float = 0.0
		if inn >= 2:
			s = 100.0
		elif inn == 1:
			s = 60.0 + (20.0 if int(free_by[kd]) >= 2 else 0.0)
		else:
			## Nueva: mejor si hay tres libres a la vista (se cierra seguro).
			s = 10.0 + 15.0 * float(mini(int(free_by[kd]), 3))
		## Lo que destapa cuenta (abre jugadas).
		s += 2.0 * float(_uncovers(st, t2))
		## Con poco sitio, solo lo que cierra.
		var after: int = inn + 1
		var slots_needed: int = 3 - after
		if after < 3 and room - 1 < slots_needed + (1 if int(free_by[kd]) < 3 - inn else 0):
			s -= 80.0
		if s > bs:
			bs = s
			best = t2
	if bs < -20.0:
		if int(st["undo"]) > 0 and not (st["history"] as Array).is_empty():
			return {"undo": true}
		if int(st["shuffle"]) > 0:
			return {"shuffle": true}
	return {"pick": int(best["id"])}


static func _uncovers(st: Dictionary, t: Dictionary) -> int:
	var n: int = 0
	var board: Array = on_board(st)
	for u: Dictionary in board:
		if covers(t, u):
			var other: bool = false
			for v: Dictionary in board:
				if v != t and v != u and covers(v, u):
					other = true
					break
			if not other:
				n += 1
	return n


static func bot_step(st: Dictionary) -> void:
	var m: Dictionary = bot_move(st)
	if m.has("undo"):
		undo(st)
	elif m.has("shuffle"):
		shuffle(st)
	elif m.has("pick"):
		pick(st, int(m["pick"]))


static func bot_play(level: Dictionary) -> Dictionary:
	var st: Dictionary = new_state(level)
	var guard: int = 0
	while not bool(st["over"]) and guard < 2000:
		var before: int = int(st["moves"]) + int(st["undo"]) * 1000 + int(st["shuffle"]) * 100000
		bot_step(st)
		(st["events"] as Array).clear()
		guard += 1
		if int(st["moves"]) + int(st["undo"]) * 1000 + int(st["shuffle"]) * 100000 == before:
			break
	return {"won": bool(st["won"]), "moves": int(st["moves"]), "undo_left": int(st["undo"]), "shuffle_left": int(st["shuffle"])}


# ------------------------------------------------------------------ analizador

static func analyze(level: Dictionary) -> Dictionary:
	var info: Dictionary = parse(level)
	var issues: Array[String] = []
	var n: int = (info["tiles"] as Array).size()
	if n < 9:
		issues.append("triple_small")
	var st0: Dictionary = new_state(level)
	var dealt: bool = true
	for t: Dictionary in st0["tiles"]:
		if int(t["kind"]) < 0:
			dealt = false
	if not dealt:
		issues.append("triple_no_deal")
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
			var r2: Dictionary = bot_play(lv)
			moves += int(r2["moves"])
			if bool(r2["won"]):
				wins += 1
		if wins < 2:
			issues.append("triple_too_hard")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": 0, "enemies": 0, "enemy_problems": [],
		"par": int(float(n) * 1.6) + 10, "wins": wins}
