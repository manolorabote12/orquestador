extends RefCounted
## Sigilo por turnos (tipo Hitman GO): un tablero de puntos unidos por caminos. Cada turno te mueves
## a un punto vecino; si alli hay un guardia, lo eliminas. Despues mueven los guardias: si tienes
## el punto que miran, te pillan. Guardias quietos (miran siempre igual), que patrullan (avanzan y
## al llegar al final dan media vuelta) y que giran (un cuarto de vuelta por turno). Llega a la
## salida. Estrellas: llegar, coger el maletin y hacerlo en pocos movimientos.
## Mapa ("map", rejilla doble): en las casillas pares hay puntos ("." punto, "P" salida del heroe,
## "X" salida, "C" maletin; guardias quietos "N" "S" "E" "W" segun miran, que patrullan "n" "s" "e"
## "w", que giran "R"); en las impares los caminos ("-" y "|"); " " nada.
## Nivel: "par" (movimientos para la estrella), "seed".

const Rules = preload("res://kit/rules.gd")
const DIRS: Dictionary = {"N": Vector2i(0, -1), "S": Vector2i(0, 1), "E": Vector2i(1, 0), "W": Vector2i(-1, 0)}
const CW: Dictionary = {"N": "E", "E": "S", "S": "W", "W": "N"}


static func new_state(level: Dictionary) -> Dictionary:
	var rows: Array = []
	for r: Variant in level.get("map", []):
		var row: String = str(r)
		if row.begins_with("#") and row.length() > 1 and row.substr(1).is_valid_int():
			continue
		rows.append(row)
	var nodes: Dictionary = {}
	var guards: Array = []
	var start: Vector2i = Vector2i.ZERO
	var exit: Vector2i = Vector2i(-1, -1)
	var item: Vector2i = Vector2i(-1, -1)
	var h: int = rows.size()
	var w: int = 0
	for row2: Variant in rows:
		w = maxi(w, (row2 as String).length())
	for y: int in range(0, h, 2):
		for x: int in range(0, w, 2):
			var ch: String = _at(rows, x, y)
			if ch == " ":
				continue
			var p: Vector2i = Vector2i(x / 2, y / 2)
			nodes[p] = true
			match ch:
				"P":
					start = p
				"X":
					exit = p
				"C":
					item = p
				"N", "S", "E", "W":
					guards.append({"p": p, "d": ch, "kind": "stand", "alive": true})
				"n", "s", "e", "w":
					guards.append({"p": p, "d": ch.to_upper(), "kind": "patrol", "alive": true})
				"R":
					guards.append({"p": p, "d": "N", "kind": "rotate", "alive": true})
	var edges: Dictionary = {}
	for q: Variant in nodes:
		var qp: Vector2i = q
		for d: String in DIRS:
			var n: Vector2i = qp + DIRS[d]
			var mid: Vector2i = qp * 2 + DIRS[d]
			var c: String = _at(rows, mid.x, mid.y)
			if nodes.has(n) and (c == "-" or c == "|"):
				edges[[qp, n]] = true
	var st: Dictionary = {"nodes": nodes, "edges": edges, "w": (w + 1) / 2, "h": (h + 1) / 2, "p": start, "start": start, "exit": exit,
		"item": item, "has_item": false, "guards": guards, "moves": 0, "kills": 0, "par": int(level.get("par", 12)),
		"won": false, "lost": false, "log": []}
	st["rules"] = Rules.load_rules(level)
	Rules.hook(st, "on_start")
	return st


static func _at(rows: Array, x: int, y: int) -> String:
	if y < 0 or y >= rows.size() or x < 0 or x >= (rows[y] as String).length():
		return " "
	return (rows[y] as String)[x]


static func linked(st: Dictionary, a: Vector2i, b: Vector2i) -> bool:
	return (st["edges"] as Dictionary).has([a, b])


static func neighbors(st: Dictionary, a: Vector2i) -> Array:
	var out: Array = []
	for d: String in DIRS:
		var n: Vector2i = a + DIRS[d]
		if linked(st, a, n):
			out.append(n)
	return out


## Punto que vigila un guardia (si hay camino en esa direccion).
static func watch(st: Dictionary, g: Dictionary) -> Vector2i:
	var n: Vector2i = (g["p"] as Vector2i) + DIRS[str(g["d"])]
	return n if linked(st, g["p"], n) else Vector2i(-99, -99)


## Un turno: el heroe va a q (vecino). Devuelve false si no se puede.
static func move(st: Dictionary, q: Vector2i) -> bool:
	if bool(st["won"]) or bool(st["lost"]) or not linked(st, st["p"], q):
		return false
	var from: Vector2i = st["p"]
	st["p"] = q
	st["moves"] = int(st["moves"]) + 1
	(st["log"] as Array).append({"k": "move", "from": from, "to": q})
	for g: Variant in st["guards"]:
		if bool(g["alive"]) and g["p"] == q:
			g["alive"] = false
			st["kills"] = int(st["kills"]) + 1
			(st["log"] as Array).append({"k": "kill", "at": q})
			Rules.hook(st, "on_kill", [str(g["kind"])])
	if q == st["item"] and not bool(st["has_item"]):
		st["has_item"] = true
		(st["log"] as Array).append({"k": "item", "at": q})
	if q == st["exit"]:
		st["won"] = true
		(st["log"] as Array).append({"k": "won"})
		return true
	_guards(st)
	return true


static func _guards(st: Dictionary) -> void:
	var p: Vector2i = st["p"]
	for g: Variant in st["guards"]:
		if not bool(g["alive"]):
			continue
		if watch(st, g) == p:
			g["p"] = p
			st["lost"] = true
			(st["log"] as Array).append({"k": "caught", "at": p})
			return
	for g2: Variant in st["guards"]:
		if not bool(g2["alive"]):
			continue
		match str(g2["kind"]):
			"patrol":
				var n: Vector2i = watch(st, g2)
				if n.x == -99:
					g2["d"] = CW[CW[str(g2["d"])]]
				else:
					g2["p"] = n
					if watch(st, g2).x == -99:
						g2["d"] = CW[CW[str(g2["d"])]]
			"rotate":
				for k: int in 4:
					g2["d"] = CW[str(g2["d"])]
					if watch(st, g2).x != -99:
						break
		if g2["p"] == p:
			st["lost"] = true
			(st["log"] as Array).append({"k": "caught", "at": p})
			return
	(st["log"] as Array).append({"k": "guards"})


# ------------------------------------------------------------------ resolver

static func _key(st: Dictionary) -> String:
	var s: String = str(st["p"]) + ("i" if bool(st["has_item"]) else "")
	for g: Variant in st["guards"]:
		s += "|" + (str(g["p"]) + str(g["d"]) if bool(g["alive"]) else "x")
	return s


static func _copy(st: Dictionary) -> Dictionary:
	var c: Dictionary = st.duplicate(false)
	c["guards"] = (st["guards"] as Array).duplicate(true)
	c["log"] = []
	return c


## Busqueda en anchura: camino mas corto a la salida (con el maletin si want_item).
static func solve(st: Dictionary, want_item: bool = false, limit: int = 20000) -> Array:
	var start: Dictionary = _copy(st)
	var seen: Dictionary = {_key(start) + str(want_item): true}
	var q: Array = [[start, []]]
	var i: int = 0
	while i < q.size() and i < limit:
		var cur: Dictionary = q[i][0]
		var path: Array = q[i][1]
		i += 1
		for n: Variant in neighbors(cur, cur["p"]):
			var nx: Dictionary = _copy(cur)
			move(nx, n)
			if bool(nx["lost"]):
				continue
			var np: Array = path.duplicate()
			np.append(n)
			if bool(nx["won"]):
				if not want_item or bool(nx["has_item"]):
					return np
				continue
			var k: String = _key(nx)
			if seen.has(k):
				continue
			seen[k] = true
			q.append([nx, np])
	return []


static func bot_play(level: Dictionary) -> Dictionary:
	var st: Dictionary = new_state(level)
	var path: Array = solve(st, (st["item"] as Vector2i).x >= 0)
	if path.is_empty():
		path = solve(st, false)
	for n: Variant in path:
		move(st, n)
	return {"won": bool(st["won"]), "moves": int(st["moves"]), "item": bool(st["has_item"]), "kills": int(st["kills"])}


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var st: Dictionary = new_state(level)
	if (st["exit"] as Vector2i).x < 0:
		issues.append("stealth_no_exit")
	if (st["guards"] as Array).is_empty():
		issues.append("stealth_no_guards")
	var r: Dictionary = {"won": false}
	if issues.is_empty():
		var best: Array = solve(st, false)
		if best.is_empty():
			issues.append("stealth_unsolvable")
		else:
			## Los guardias tienen que importar: ir por el camino corto sin mirarlos tiene que salir mal.
			var free: Dictionary = _copy(st)
			for g: Variant in free["guards"]:
				g["alive"] = false
			var naive: Dictionary = _copy(st)
			for n: Variant in solve(free, false):
				move(naive, n)
			if bool(naive["won"]):
				issues.append("stealth_trivial")
			r = bot_play(level)
			if not bool(r["won"]):
				issues.append("stealth_bot_failed")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": 1 if (st["item"] as Vector2i).x >= 0 else 0,
		"enemies": (st["guards"] as Array).size(), "enemy_problems": [], "bot": r}
