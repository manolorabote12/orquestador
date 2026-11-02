extends RefCounted
## Cruzar (saltos por carriles, estilo arcade de cruzar carreteras): reglas, simulacion pura, bot
## y analizador (lo usan el juego, el bot y el analizador: todo lo que decide esta aqui).
## 1 - Mapa (game.json -> levels[i].map): una fila por carril, de abajo (salida) a arriba (meta):
##     "g:..t..c..."   hierba de 9 casillas: "t" arbol (no se pasa), "c" moneda
##     "r>2.5:..cc...c......"  carretera: sentido (> o <), casillas por segundo y el patron que se
##                             repite (c coche de 1, TT camion de 2) de 12 a 20 casillas
##     "w<1.5:.LLL...LL....."  rio: troncos (L); hay que ir encima y te arrastran
##     "t>16:7"   via: tren a 16 casillas/s cada 7 s (avisa con la luz antes de pasar)
##     "F"        meta (la ultima fila)
## 2 - Se salta una casilla por toque (arriba, abajo, izquierda, derecha). Te pillan los coches y el
##     tren; en el rio, fuera de un tronco te hundes, y si el tronco te saca de la pantalla, tambien.

const W: int = 9
const HOP: float = 0.13
const TRAIN_LEN: float = 8.0
const WARN: float = 1.3


static func parse(level: Dictionary) -> Array:
	var out: Array = []
	for r: Variant in level.get("map", []):
		var s: String = str(r).strip_edges()
		if s == "":
			continue
		var kind: String = s[0]
		var row: Dictionary = {"kind": kind, "dir": 1.0, "speed": 0.0, "pat": "", "period": 0.0}
		if kind == "g":
			row["pat"] = s.substr(2).rpad(W, ".").left(W)
		elif kind in ["r", "w", "t"]:
			var head: String = s.get_slice(":", 0)
			row["dir"] = -1.0 if head.contains("<") else 1.0
			row["speed"] = float(head.substr(2))
			var tail: String = s.get_slice(":", 1)
			if kind == "t":
				row["period"] = float(tail)
			else:
				row["pat"] = tail
		elif kind == "F":
			row["pat"] = ".".repeat(W)
		out.append(row)
	return out


static func new_state(level: Dictionary) -> Dictionary:
	var rows: Array = parse(level)
	var coins: Dictionary = {}
	for i: int in rows.size():
		var r: Dictionary = rows[i]
		if str(r["kind"]) == "g":
			for x: int in W:
				if str(r["pat"])[x] == "c":
					coins[Vector2i(x, i)] = true
	return {"rows": rows, "row": 0, "x": 4.0, "t": 0.0, "dead": false, "won": false, "coins": coins, "got": 0,
		"coins_total": coins.size(), "cause": "", "hops": 0, "best": 0}


## Intervalos [a, b) ocupados en la fila en el instante t (en casillas, dentro de la pantalla).
static func blockers(row: Dictionary, t: float) -> Array:
	var out: Array = []
	var kind: String = row["kind"]
	if kind == "r" or kind == "w":
		var pat: String = row["pat"]
		var L: int = pat.length()
		if L == 0:
			return out
		var off: float = fposmod(float(row["dir"]) * float(row["speed"]) * t, float(L))
		var want: String = "L" if kind == "w" else "cT"
		for k: int in L:
			if want.contains(pat[k]):
				var a: float = fposmod(float(k) + off, float(L))
				## Se repite cada L casillas: lo que cae dentro de la pantalla (0..W).
				for rep: int in [-1, 0, 1]:
					var aa: float = a + float(rep * L)
					if aa < float(W) and aa + 1.0 > 0.0:
						out.append(Vector2(aa, aa + 1.0))
	elif kind == "t":
		var per: float = float(row["period"])
		var ph: float = fposmod(t, per)
		var pass_t: float = (float(W) + TRAIN_LEN) / float(row["speed"])
		var start: float = per - pass_t
		if ph >= start:
			var head: float = (ph - start) * float(row["speed"])
			if float(row["dir"]) > 0.0:
				out.append(Vector2(head - TRAIN_LEN, head))
			else:
				out.append(Vector2(float(W) - head, float(W) - head + TRAIN_LEN))
	return out


static func train_warning(row: Dictionary, t: float) -> bool:
	if str(row["kind"]) != "t":
		return false
	var per: float = float(row["period"])
	var ph: float = fposmod(t, per)
	var pass_t: float = (float(W) + TRAIN_LEN) / float(row["speed"])
	return ph >= per - pass_t - WARN


static func _on(ints: Array, x: float, pad: float) -> bool:
	for iv: Vector2 in ints:
		if x + 0.5 + pad > iv.x and x + 0.5 - pad < iv.y:
			return true
	return false


## Comprueba si el jugador sigue vivo en su fila (llamar tras moverse y en cada paso).
static func _check(st: Dictionary) -> void:
	var row: Dictionary = st["rows"][int(st["row"])]
	var kind: String = row["kind"]
	var x: float = st["x"]
	if kind == "r" and _on(blockers(row, st["t"]), x, 0.3):
		_die(st, "car")
	elif kind == "t" and _on(blockers(row, st["t"]), x, 0.4):
		_die(st, "train")
	elif kind == "w":
		## En el rio hay que estar sobre un tronco (con el centro encima).
		if not _on(blockers(row, st["t"]), x, -0.15):
			_die(st, "water")
		elif x < -0.4 or x > float(W) - 0.6:
			_die(st, "edge")


static func _die(st: Dictionary, cause: String) -> void:
	st["dead"] = true
	st["cause"] = cause


## Un salto: dir = Vector2i(dx, dy) con dy = 1 hacia la meta. Devuelve si se ha movido.
static func hop(st: Dictionary, d: Vector2i) -> bool:
	if bool(st["dead"]) or bool(st["won"]):
		return false
	var rows: Array = st["rows"]
	var nr: int = int(st["row"]) + d.y
	if nr < 0 or nr >= rows.size():
		return false
	var nx: float = float(st["x"]) + float(d.x)
	## Al saltar a tierra se cae en la casilla entera mas cercana.
	if str(rows[nr]["kind"]) != "w":
		nx = roundf(nx)
	if nx < 0.0 or nx > float(W - 1):
		return false
	if str(rows[nr]["kind"]) == "g":
		var xi: int = int(roundf(nx))
		if str(rows[nr]["pat"])[xi] == "t":
			return false
	st["row"] = nr
	st["x"] = nx
	st["hops"] = int(st["hops"]) + 1
	st["best"] = maxi(int(st["best"]), nr)
	var key: Vector2i = Vector2i(int(roundf(nx)), nr)
	if (st["coins"] as Dictionary).has(key):
		(st["coins"] as Dictionary).erase(key)
		st["got"] = int(st["got"]) + 1
	if str(rows[nr]["kind"]) == "F":
		st["won"] = true
		return true
	_check(st)
	return true


## Avanza el tiempo: los troncos arrastran y los coches pasan.
static func step(st: Dictionary, dt: float) -> void:
	if bool(st["dead"]) or bool(st["won"]):
		return
	st["t"] = float(st["t"]) + dt
	var row: Dictionary = st["rows"][int(st["row"])]
	if str(row["kind"]) == "w":
		st["x"] = float(st["x"]) + float(row["dir"]) * float(row["speed"]) * dt
	_check(st)


static func copy_state(st: Dictionary) -> Dictionary:
	var c: Dictionary = st.duplicate()
	c["coins"] = (st["coins"] as Dictionary).duplicate()
	return c


# ------------------------------------------------------------------ bot

const ACTS: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, 0), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1)]
const DEC: float = 0.15
const SUB: float = DEC / 3.0


## Plan del bot: busca (lo mas adelantado primero) una secuencia de saltos cada 0,15 s que llega a la
## meta sin morir, simulando el futuro con estas mismas reglas. Devuelve la lista de acciones.
static func plan(level: Dictionary, limit_t: float = 150.0) -> Array:
	return plan_from(new_state(level), limit_t)


## Lo mismo desde una partida ya empezada (el juego lo usa si el bot entra a mitad).
static func plan_from(st0: Dictionary, limit_t: float = 150.0) -> Array:
	var rows: int = (st0["rows"] as Array).size()
	var heap: Array = [[0.0, copy_state(st0), []]]
	var seen: Dictionary = {}
	var n: int = 0
	while not heap.is_empty() and n < 40000:
		n += 1
		var cur: Array = _pop(heap)
		var st: Dictionary = cur[1]
		if bool(st["won"]):
			return cur[2]
		if float(st["t"]) > float(st0["t"]) + limit_t:
			continue
		for a: Vector2i in ACTS:
			var s2: Dictionary = copy_state(st)
			if a != Vector2i.ZERO and not hop(s2, a):
				continue
			if bool(s2["dead"]):
				continue
			## Esperar hasta la siguiente decision, con pasos cortos (los coches no saltan casillas).
			for k: int in 3:
				step(s2, SUB)
			if bool(s2["dead"]):
				continue
			var key: String = "%d|%d|%d" % [int(s2["row"]), int(roundf(float(s2["x"]) * 4.0)), int(float(s2["t"]) / DEC)]
			if seen.has(key):
				continue
			seen[key] = true
			var pl: Array = (cur[2] as Array).duplicate()
			pl.append(a)
			## Lo mas prometedor primero: mas filas avanzadas y menos tiempo.
			_push(heap, [float(rows - int(s2["row"])) * 10.0 + float(s2["t"]) * 0.8, s2, pl])
	return []


static func _push(h: Array, item: Array) -> void:
	h.append(item)
	var i: int = h.size() - 1
	while i > 0:
		var p: int = (i - 1) / 2
		if float(h[p][0]) <= float(h[i][0]):
			break
		var t: Variant = h[p]
		h[p] = h[i]
		h[i] = t
		i = p


static func _pop(h: Array) -> Array:
	var top: Array = h[0]
	var last: Variant = h.pop_back()
	if not h.is_empty():
		h[0] = last
		var i: int = 0
		var n: int = h.size()
		while true:
			var l: int = i * 2 + 1
			var m: int = i
			if l < n and float(h[l][0]) < float(h[m][0]):
				m = l
			if l + 1 < n and float(h[l + 1][0]) < float(h[m][0]):
				m = l + 1
			if m == i:
				break
			var t: Variant = h[m]
			h[m] = h[i]
			h[i] = t
			i = m
	return top


## Partida del bot siguiendo su plan (lo mismo que hace el juego con el bot puesto).
static func bot_play(level: Dictionary) -> Dictionary:
	var acts: Array = plan(level)
	var st: Dictionary = new_state(level)
	for a: Vector2i in acts:
		if a != Vector2i.ZERO:
			hop(st, a)
		for k: int in 3:
			step(st, SUB)
	return {"won": bool(st["won"]), "time": float(st["t"]), "dead": bool(st["dead"]), "got": int(st["got"]), "steps": acts.size()}


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var rows: Array = parse(level)
	if rows.size() < 6 or rows.size() > 80:
		issues.append("hopper_rows")
	elif str(rows[0]["kind"]) != "g" or str(rows[rows.size() - 1]["kind"]) != "F":
		issues.append("hopper_ends")
	for r: Dictionary in rows:
		var k: String = r["kind"]
		if (k == "r" or k == "w") and (str(r["pat"]).length() < 12 or str(r["pat"]).length() > 24 or float(r["speed"]) <= 0.0):
			issues.append("hopper_lane")
			break
		if k == "t" and (float(r["period"]) < 4.0 or float(r["speed"]) < 8.0):
			issues.append("hopper_train")
			break
		if not (k in ["g", "r", "w", "t", "F"]):
			issues.append("hopper_kind")
			break
	var par: int = 0
	if issues.is_empty():
		if str(rows[0]["pat"])[4] == "t":
			issues.append("hopper_start")
		else:
			var r2: Dictionary = bot_play(level)
			if not bool(r2["won"]):
				issues.append("hopper_too_hard")
			par = int(float(r2["time"]) * 1.6) + 5
	var coins: int = 0
	for r3: Dictionary in rows:
		if str(r3["kind"]) == "g":
			coins += str(r3["pat"]).count("c")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": coins, "enemies": 0, "enemy_problems": [], "par": par}
