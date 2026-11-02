extends RefCounted
## Solitario clasico (Klondike, robando de 1 en 1): reglas, reparto, buscador de solucion, bot y
## analizador.
## 1 - Mapa (game.json -> levels[i].map): ["klondike"]. El reparto sale de "seed" (siempre el
##     mismo con la misma semilla) y el analizador solo acepta semillas con solucion.
## 2 - 7 columnas (la ultima carta boca arriba), mazo y descarte, y 4 bases que se llenan del As
##     al Rey por palo. En las columnas se baja alternando colores; en una columna vacia solo
##     entra un Rey. "passes": vueltas que se pueden dar al mazo (0 = sin limite).
## Cartas: [palo 0-3, valor 1-13]; palos 0 y 3 negros, 1 y 2 rojos.

const MAX_NODES: int = 6000


static func deck(seed_v: int) -> Array:
	var d: Array = []
	for s: int in 4:
		for v: int in range(1, 14):
			d.append([s, v])
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.seed = seed_v
	for i: int in range(d.size() - 1, 0, -1):
		var j: int = r.randi_range(0, i)
		var t: Variant = d[i]
		d[i] = d[j]
		d[j] = t
	return d


static func red(c: Array) -> bool:
	return int(c[0]) == 1 or int(c[0]) == 2


static func new_state(level: Dictionary) -> Dictionary:
	var d: Array = deck(int(level.get("seed", 1)))
	var cols: Array = []
	var k: int = 0
	for i: int in 7:
		var col: Array = []
		for j: int in i + 1:
			col.append([d[k][0], d[k][1], j == i])
			k += 1
		cols.append(col)
	var stock: Array = []
	for i2: int in range(k, d.size()):
		stock.append([d[i2][0], d[i2][1], false])
	return {"cols": cols, "stock": stock, "waste": [], "found": [0, 0, 0, 0], "moves": 0, "passes": int(level.get("passes", 0)), "pass": 0}


static func top_of(arr: Array) -> Variant:
	return arr[arr.size() - 1] if not arr.is_empty() else null


static func can_found(st: Dictionary, c: Array) -> bool:
	return int(st["found"][int(c[0])]) == int(c[1]) - 1


static func can_stack(dst: Array, c: Array) -> bool:
	if dst.is_empty():
		return int(c[1]) == 13
	var t: Array = dst[dst.size() - 1]
	return bool(t[2]) and int(t[1]) == int(c[1]) + 1 and red(t) != red(c)


static func won(st: Dictionary) -> bool:
	for f: Variant in st["found"]:
		if int(f) != 13:
			return false
	return true


## Jugadas posibles: {"t": tipo, ...}. Tipos: "wf" descarte->base, "cf" columna->base,
## "wc" descarte->columna, "cc" columna(desde i)->columna, "draw", "recycle".
static func moves(st: Dictionary) -> Array:
	var out: Array = []
	var cols: Array = st["cols"]
	var w: Variant = top_of(st["waste"])
	if w != null and can_found(st, w):
		out.append({"t": "wf"})
	for a: int in 7:
		var col: Array = cols[a]
		var t: Variant = top_of(col)
		if t != null and can_found(st, t):
			out.append({"t": "cf", "a": a})
	if w != null:
		for b: int in 7:
			if can_stack(cols[b], w):
				out.append({"t": "wc", "b": b})
	for a2: int in 7:
		var col2: Array = cols[a2]
		for i: int in col2.size():
			if not bool(col2[i][2]):
				continue
			for b2: int in 7:
				if b2 == a2:
					continue
				## No mover un Rey que ya esta en el fondo a otra columna vacia (no sirve de nada).
				if i == 0 and (cols[b2] as Array).is_empty():
					continue
				if can_stack(cols[b2], col2[i]):
					out.append({"t": "cc", "a": a2, "i": i, "b": b2})
			break
	if not (st["stock"] as Array).is_empty():
		out.append({"t": "draw"})
	elif not (st["waste"] as Array).is_empty() and (int(st["passes"]) == 0 or int(st["pass"]) < int(st["passes"]) - 1):
		out.append({"t": "recycle"})
	return out


static func _flip(col: Array) -> void:
	if not col.is_empty() and not bool(col[col.size() - 1][2]):
		col[col.size() - 1][2] = true


static func apply(st: Dictionary, m: Dictionary) -> void:
	var cols: Array = st["cols"]
	match str(m["t"]):
		"wf":
			var c: Array = (st["waste"] as Array).pop_back()
			st["found"][int(c[0])] = int(c[1])
		"cf":
			var col: Array = cols[int(m["a"])]
			var c2: Array = col.pop_back()
			st["found"][int(c2[0])] = int(c2[1])
			_flip(col)
		"wc":
			var c3: Array = (st["waste"] as Array).pop_back()
			(cols[int(m["b"])] as Array).append([c3[0], c3[1], true])
		"cc":
			var src: Array = cols[int(m["a"])]
			var run: Array = src.slice(int(m["i"]))
			src.resize(int(m["i"]))
			(cols[int(m["b"])] as Array).append_array(run)
			_flip(src)
		"draw":
			var c4: Array = (st["stock"] as Array).pop_back()
			(st["waste"] as Array).append([c4[0], c4[1], true])
		"recycle":
			var w: Array = st["waste"]
			w.reverse()
			for c5: Array in w:
				c5[2] = false
			st["stock"] = w
			st["waste"] = []
			st["pass"] = int(st["pass"]) + 1
	st["moves"] = int(st["moves"]) + 1


static func copy(st: Dictionary) -> Dictionary:
	var c: Dictionary = st.duplicate()
	var cols: Array = []
	for col: Array in st["cols"]:
		var cc: Array = []
		for card: Array in col:
			cc.append(card.duplicate())
		cols.append(cc)
	c["cols"] = cols
	var stock: Array = []
	for card2: Array in st["stock"]:
		stock.append(card2.duplicate())
	c["stock"] = stock
	var waste: Array = []
	for card3: Array in st["waste"]:
		waste.append(card3.duplicate())
	c["waste"] = waste
	c["found"] = (st["found"] as Array).duplicate()
	return c


static func _key(st: Dictionary) -> String:
	var s: String = str(st["found"]) + "|" + str((st["stock"] as Array).size()) + "|"
	for col: Array in st["cols"]:
		s += str(col.size()) + ":" + (str(top_of(col)) if not col.is_empty() else "-") + ";"
	return s


## Orden de preferencia de jugadas (lo que haria una persona que sabe).
static func _rank(st: Dictionary, m: Dictionary) -> int:
	match str(m["t"]):
		"cf", "wf":
			return 0
		"cc":
			## Mejor si destapa una carta boca abajo.
			var col: Array = st["cols"][int(m["a"])]
			return 1 if int(m["i"]) > 0 and not bool(col[int(m["i"]) - 1][2]) else 4
		"wc":
			return 2
		"draw":
			return 5
	return 6


## Busca una solucion (profundidad primero con estados vistos). Devuelve la lista de jugadas o [].
static func solve(st: Dictionary) -> Array:
	var seen: Dictionary = {}
	var path: Array = []
	var nodes: Array = [0]
	if _dfs(copy(st), seen, path, nodes):
		return path
	return []


static func _dfs(st: Dictionary, seen: Dictionary, path: Array, nodes: Array) -> bool:
	if won(st):
		return true
	nodes[0] = int(nodes[0]) + 1
	if int(nodes[0]) > MAX_NODES:
		return false
	var k: String = _key(st) + str((st["waste"] as Array).size())
	if seen.has(k):
		return false
	seen[k] = true
	var ms: Array = moves(st)
	ms.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _rank(st, a) < _rank(st, b))
	for m: Dictionary in ms:
		var nx: Dictionary = copy(st)
		apply(nx, m)
		path.append(m)
		if _dfs(nx, seen, path, nodes):
			return true
		path.pop_back()
	return false


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var st: Dictionary = new_state(level)
	var sol: Array = solve(st)
	if sol.is_empty():
		issues.append("klondike_no_solution")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": 52, "enemies": 0, "enemy_problems": [],
		"par": int(sol.size() * 2.2) + 30}
