extends RefCounted
## Minas (idle de excavar, estilo Idle Miner): reglas, simulacion pura, bot y analizador. El juego
## dibuja y toca; aqui esta todo lo que decide (lo usan el juego, el bot y el analizador).
## Cadena: los mineros de cada pozo excavan y dejan el mineral en su caja; el ascensor baja pozo
## a pozo cargando hasta llenarse y lo sube; el transportista lo lleva al almacen y se vende.
## Sin gerente, cada estacion hace un viaje por toque; con gerente trabaja sola y tiene impulso
## (x2 de velocidad un rato). Mejorar sube la cantidad (y cada 10 niveles un trabajador mas).
## Mapa (game.json -> levels[i].map): un texto por pozo, de arriba abajo; la letra es el mineral:
##   c carbon, h hierro, b bronce, p plata, o oro, r rubi, e esmeralda, d diamante.
## Parametros: "goal" (dinero para ganar), "start" (dinero al empezar), "par" (segundos, estrellas).
## Analizador: 3-10 pozos con minerales validos, meta positiva y el bot llega a la meta en menos de
## 20 minutos de juego jugando con las mismas reglas (devuelve el tiempo como "par").

const ORES: String = "chbpored"
const MAX_LEVEL: int = 400
const MINER_T: float = 3.0
const BOOST_T: float = 30.0
const BOOST_CD: float = 90.0
const BOOST_X: float = 2.0
const LIMIT_T: float = 1200.0


## Valor del mineral de un pozo (cada pozo mas hondo vale 10 veces mas).
static func value(i: int) -> float:
	return pow(10.0, float(i))


static func open_cost(i: int) -> float:
	return 0.0 if i == 0 else 120.0 * pow(14.0, float(i - 1))


static func workers(lvl: int) -> int:
	return 1 + mini(lvl / 10, 4)


## Lo que saca un pozo por viaje (todos sus mineros) y cuanto tarda.
static func dig_amount(i: int, lvl: int) -> float:
	return 10.0 * value(i) * pow(1.13, float(lvl - 1)) * float(workers(lvl))


static func dig_time(lvl: int) -> float:
	return MINER_T / (1.0 + 0.02 * float(lvl - 1))


static func shaft_cost(i: int, lvl: int) -> float:
	return 8.0 * value(i) * pow(1.18, float(lvl - 1))


static func elev_cap(lvl: int) -> float:
	return 25.0 * pow(1.16, float(lvl - 1))


## Pozos por segundo que recorre el ascensor.
static func elev_speed(lvl: int) -> float:
	return 2.5 * (1.0 + 0.03 * float(lvl - 1))


static func elev_cost(lvl: int) -> float:
	return 15.0 * pow(1.17, float(lvl - 1))


static func ware_cap(lvl: int) -> float:
	return 25.0 * pow(1.16, float(lvl - 1)) * float(workers(lvl))


static func ware_time(lvl: int) -> float:
	return 3.0 / (1.0 + 0.03 * float(lvl - 1))


static func ware_cost(lvl: int) -> float:
	return 15.0 * pow(1.17, float(lvl - 1))


static func manager_cost(hired: int) -> float:
	return 40.0 * pow(4.0, float(hired))


## Estado inicial de una partida.
static func new_state(level: Dictionary) -> Dictionary:
	var shafts: Array = []
	for r: Variant in level.get("map", []):
		var k: String = str(r).strip_edges()
		shafts.append({"kind": k.substr(0, 1) if k != "" else "c", "open": shafts.is_empty(), "lvl": 1, "mgr": false, "box": 0.0,
			"busy": false, "t": 0.0, "boost": 0.0, "cd": 0.0})
	return {"cash": float(level.get("start", 0)), "earned": 0.0, "time": 0.0, "hired": 0, "shafts": shafts,
		"elev": {"lvl": 1, "mgr": false, "busy": false, "pos": -1.0, "dir": 0, "load": 0.0, "boost": 0.0, "cd": 0.0},
		"ware": {"lvl": 1, "mgr": false, "busy": false, "t": 0.0, "carry": 0.0, "boost": 0.0, "cd": 0.0},
		"surface": 0.0, "goal": float(level.get("goal", 1000))}


static func open_count(st: Dictionary) -> int:
	var n: int = 0
	for s: Dictionary in st["shafts"]:
		if s["open"]:
			n += 1
	return n


static func _mult(x: Dictionary) -> float:
	return BOOST_X if float(x["boost"]) > 0.0 else 1.0


## Un paso de simulacion.
static func step(st: Dictionary, dt: float) -> void:
	st["time"] = float(st["time"]) + dt
	for i: int in (st["shafts"] as Array).size():
		var s: Dictionary = st["shafts"][i]
		_tick_boost(s, dt)
		if not s["open"]:
			continue
		if not s["busy"] and s["mgr"]:
			s["busy"] = true
			s["t"] = 0.0
		if s["busy"]:
			s["t"] = float(s["t"]) + dt * _mult(s)
			if float(s["t"]) >= dig_time(int(s["lvl"])):
				s["busy"] = false
				s["t"] = 0.0
				s["box"] = float(s["box"]) + dig_amount(i, int(s["lvl"]))
	_step_elev(st, dt)
	_step_ware(st, dt)


static func _tick_boost(x: Dictionary, dt: float) -> void:
	x["boost"] = maxf(0.0, float(x["boost"]) - dt)
	x["cd"] = maxf(0.0, float(x["cd"]) - dt)


static func _step_elev(st: Dictionary, dt: float) -> void:
	var e: Dictionary = st["elev"]
	_tick_boost(e, dt)
	var last: int = open_count(st) - 1
	if not e["busy"]:
		if e["mgr"]:
			e["busy"] = true
			e["dir"] = 1
		else:
			return
	var v: float = elev_speed(int(e["lvl"])) * _mult(e) * dt
	var cap: float = elev_cap(int(e["lvl"]))
	if int(e["dir"]) > 0:
		var before: float = float(e["pos"])
		e["pos"] = minf(float(last), before + v)
		## Carga en cada pozo por el que pasa.
		for i: int in range(int(floor(before)) + 1, int(floor(float(e["pos"]))) + 1):
			if i < 0 or i > last:
				continue
			var s: Dictionary = st["shafts"][i]
			var take: float = minf(float(s["box"]), cap - float(e["load"]))
			s["box"] = float(s["box"]) - take
			e["load"] = float(e["load"]) + take
		if float(e["load"]) >= cap - 0.001 or float(e["pos"]) >= float(last):
			e["dir"] = -1
	else:
		e["pos"] = maxf(-1.0, float(e["pos"]) - v)
		if float(e["pos"]) <= -1.0:
			st["surface"] = float(st["surface"]) + float(e["load"])
			e["load"] = 0.0
			e["busy"] = false
			e["dir"] = 0


static func _step_ware(st: Dictionary, dt: float) -> void:
	var w: Dictionary = st["ware"]
	_tick_boost(w, dt)
	if not w["busy"]:
		if w["mgr"] and float(st["surface"]) > 0.0:
			w["busy"] = true
			w["t"] = 0.0
		else:
			return
	var half: float = ware_time(int(w["lvl"]))
	var before: float = float(w["t"])
	w["t"] = before + dt * _mult(w)
	## A mitad de viaje recoge lo que hay junto al ascensor; al volver lo vende.
	if before < half and float(w["t"]) >= half:
		var take: float = minf(float(st["surface"]), ware_cap(int(w["lvl"])))
		st["surface"] = float(st["surface"]) - take
		w["carry"] = take
	if float(w["t"]) >= half * 2.0:
		st["cash"] = float(st["cash"]) + float(w["carry"])
		st["earned"] = float(st["earned"]) + float(w["carry"])
		w["carry"] = 0.0
		w["busy"] = false
		w["t"] = 0.0


# ------------------------------------------------------------------ acciones

## Toque en una estacion sin gerente: empieza un viaje (si no esta ya trabajando).
static func tap(st: Dictionary, what: String, i: int = 0) -> bool:
	var x: Dictionary = _station(st, what, i)
	if x.is_empty() or x["busy"] or (what == "shaft" and not x["open"]):
		return false
	if what == "ware" and float(st["surface"]) <= 0.0:
		return false
	x["busy"] = true
	if what == "elev":
		x["dir"] = 1
	else:
		x["t"] = 0.0
	return true


static func _station(st: Dictionary, what: String, i: int) -> Dictionary:
	match what:
		"shaft":
			return st["shafts"][i] if i >= 0 and i < (st["shafts"] as Array).size() else {}
		"elev":
			return st["elev"]
		"ware":
			return st["ware"]
	return {}


static func upgrade_cost(st: Dictionary, what: String, i: int = 0) -> float:
	var x: Dictionary = _station(st, what, i)
	if x.is_empty():
		return INF
	var l: int = int(x["lvl"])
	if l >= MAX_LEVEL:
		return INF
	match what:
		"shaft":
			return shaft_cost(i, l) if x["open"] else INF
		"elev":
			return elev_cost(l)
	return ware_cost(l)


static func upgrade(st: Dictionary, what: String, i: int = 0) -> bool:
	var c: float = upgrade_cost(st, what, i)
	if c == INF or float(st["cash"]) < c:
		return false
	st["cash"] = float(st["cash"]) - c
	var x: Dictionary = _station(st, what, i)
	x["lvl"] = int(x["lvl"]) + 1
	return true


static func next_closed(st: Dictionary) -> int:
	for i: int in (st["shafts"] as Array).size():
		if not st["shafts"][i]["open"]:
			return i
	return -1


static func open_next(st: Dictionary) -> bool:
	var i: int = next_closed(st)
	if i < 0 or float(st["cash"]) < open_cost(i):
		return false
	st["cash"] = float(st["cash"]) - open_cost(i)
	st["shafts"][i]["open"] = true
	return true


static func hire(st: Dictionary, what: String, i: int = 0) -> bool:
	var x: Dictionary = _station(st, what, i)
	var c: float = manager_cost(int(st["hired"]))
	if x.is_empty() or x["mgr"] or float(st["cash"]) < c or (what == "shaft" and not x["open"]):
		return false
	st["cash"] = float(st["cash"]) - c
	x["mgr"] = true
	st["hired"] = int(st["hired"]) + 1
	return true


static func boost(st: Dictionary, what: String, i: int = 0) -> bool:
	var x: Dictionary = _station(st, what, i)
	if x.is_empty() or not x["mgr"] or float(x["cd"]) > 0.0:
		return false
	x["boost"] = BOOST_T
	x["cd"] = BOOST_CD
	return true


# ------------------------------------------------------------------ ritmos (para el bot y la interfaz)

static func shafts_rate(st: Dictionary) -> float:
	var r: float = 0.0
	for i: int in (st["shafts"] as Array).size():
		var s: Dictionary = st["shafts"][i]
		if s["open"]:
			r += dig_amount(i, int(s["lvl"])) / dig_time(int(s["lvl"]))
	return r


static func elev_rate(st: Dictionary) -> float:
	var lvl: int = int(st["elev"]["lvl"])
	var trip: float = 2.0 * float(maxi(open_count(st), 1)) / elev_speed(lvl)
	return elev_cap(lvl) / trip


static func ware_rate(st: Dictionary) -> float:
	var lvl: int = int(st["ware"]["lvl"])
	return ware_cap(lvl) / (2.0 * ware_time(lvl))


## Dinero por segundo cuando todo trabaja solo: lo marca la estacion mas lenta.
static func income(st: Dictionary) -> float:
	return minf(shafts_rate(st), minf(elev_rate(st), ware_rate(st)))


## Potencial de la cadena: como el ingreso, pero suave (sube algo al mejorar cualquier estacion,
## no solo la mas lenta), para que el bot vea las compras que preparan la siguiente.
static func potential(st: Dictionary) -> float:
	return 1.0 / (1.0 / maxf(shafts_rate(st), 0.001) + 1.0 / maxf(elev_rate(st), 0.001) + 1.0 / maxf(ware_rate(st), 0.001))


## Mejor jugada para el bot: la compra que mas sube el ingreso por cada moneda (con gerentes
## primero cuando salen baratos). Devuelve [accion, estacion, indice] o [] si conviene esperar.
static func best_action(st: Dictionary) -> Array:
	var cash: float = float(st["cash"])
	var base: float = maxf(income(st), 0.01)
	var pot: float = potential(st)
	## Gerentes: el ascensor, el almacen y luego los pozos de arriba abajo.
	var mc: float = manager_cost(int(st["hired"]))
	if mc <= cash and mc <= maxf(base * 40.0, 60.0):
		if not st["elev"]["mgr"]:
			return ["hire", "elev", 0]
		if not st["ware"]["mgr"]:
			return ["hire", "ware", 0]
		for i: int in (st["shafts"] as Array).size():
			if st["shafts"][i]["open"] and not st["shafts"][i]["mgr"]:
				return ["hire", "shaft", i]
	## Abrir el siguiente pozo en cuanto se puede: es lo que mas hace crecer la mina.
	var nc: int = next_closed(st)
	if nc >= 0 and open_cost(nc) <= cash:
		return ["open", "shaft", nc]
	var best: Array = []
	var best_k: float = 0.0
	var opts: Array = [["up", "elev", 0], ["up", "ware", 0]]
	for i: int in (st["shafts"] as Array).size():
		if st["shafts"][i]["open"]:
			opts.append(["up", "shaft", i])
	if next_closed(st) >= 0:
		opts.append(["open", "shaft", next_closed(st)])
	for o: Array in opts:
		var cost: float = open_cost(int(o[2])) if o[0] == "open" else upgrade_cost(st, str(o[1]), int(o[2]))
		if cost == INF or cost > cash:
			continue
		var sim: Dictionary = st.duplicate(true)
		sim["cash"] = 1e30
		if o[0] == "open":
			sim["shafts"][int(o[2])]["open"] = true
		else:
			upgrade(sim, str(o[1]), int(o[2]))
		var gain: float = potential(sim) - pot
		var k: float = gain / maxf(cost, 0.01)
		if gain > 0.0 and k > best_k:
			best_k = k
			best = o
	return best


static func apply(st: Dictionary, a: Array) -> bool:
	if a.is_empty():
		return false
	match str(a[0]):
		"hire":
			return hire(st, str(a[1]), int(a[2]))
		"open":
			return open_next(st)
		"up":
			return upgrade(st, str(a[1]), int(a[2]))
	return false


## Toques del bot: toca todo lo que no tiene gerente y esta parado.
static func bot_taps(st: Dictionary) -> void:
	for i: int in (st["shafts"] as Array).size():
		var s: Dictionary = st["shafts"][i]
		if s["open"] and not s["mgr"] and not s["busy"]:
			tap(st, "shaft", i)
	if not st["elev"]["mgr"] and not st["elev"]["busy"]:
		tap(st, "elev")
	if not st["ware"]["mgr"] and not st["ware"]["busy"]:
		tap(st, "ware")


## Partida entera del bot sin dibujar (el analizador): segundos hasta la meta o -1.
static func bot_time(level: Dictionary, limit: float = LIMIT_T) -> float:
	var st: Dictionary = new_state(level)
	var dt: float = 0.25
	var think: float = 0.0
	while float(st["time"]) < limit:
		bot_taps(st)
		think -= dt
		if think <= 0.0:
			think = 1.0
			for k: int in 3:
				if not apply(st, best_action(st)):
					break
		step(st, dt)
		if float(st["earned"]) >= float(st["goal"]):
			if OS.get_environment("ORQ_MINE_CALIB") == "2":
				var lv: Array = []
				for s2: Dictionary in st["shafts"]:
					lv.append(int(s2["lvl"]) if s2["open"] else 0)
				print("      pozos ", lv, " asc ", st["elev"]["lvl"], " alm ", st["ware"]["lvl"], " gerentes ", st["hired"], " ingreso ", int(income(st)),
					" ritmos ", int(shafts_rate(st)), "/", int(elev_rate(st)), "/", int(ware_rate(st)))
			return float(st["time"])
	return -1.0


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var rows: Array = level.get("map", [])
	if rows.size() < 3 or rows.size() > 10:
		issues.append("mine_shafts")
	for r: Variant in rows:
		var k: String = str(r).strip_edges()
		if k.length() != 1 or not ORES.contains(k):
			issues.append("mine_bad_ore")
			break
	if float(level.get("goal", 0)) <= 0.0:
		issues.append("mine_goal")
	var t: float = -1.0
	if issues.is_empty():
		t = bot_time(level)
		if t < 0.0:
			issues.append("mine_too_slow")
		elif t < 45.0:
			issues.append("mine_too_easy")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": rows.size(), "enemies": 0, "enemy_problems": [],
		"par": int(ceil(t)) if t > 0.0 else 0}
