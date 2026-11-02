extends RefCounted
## Granja cozy (estilo Hay Day): reglas, simulacion pura, bot y analizador.
## 1 - Parcelas: se siembra un cultivo (cuesta su semilla), crece solo y se cosecha (2 por parcela).
## 2 - Animales: comen pienso y al rato dan su producto (gallina huevo, vaca leche, oveja lana).
## 3 - Maquinas: transforman (pienso, pan, queso, tarta, jersey...). Cola de hasta 3 encargos.
## 4 - Pedidos: siempre 3 en el tablon; al entregar uno dan monedas y sale otro. Se puede
##     rechazar un pedido (sale otro al rato). El nivel se gana al cumplir "goal" pedidos.
## Mapa (game.json -> levels[i].map), vista desde arriba, una letra por casilla:
##   . parcela - , hierba - ~ agua - t arbol - h casa - G gallinero - V establo de vacas
##   O redil de ovejas - M molino de pienso - P panaderia - Q queseria - T pasteleria - J telar
## Parametros: "goal" (pedidos), "crops" (cultivos que se pueden sembrar), "coins" (al empezar),
## "seed" (pedidos) y "par" (segundos para la tercera estrella).
## Analizador: filas iguales, al menos 4 parcelas, cultivos validos y el bot cumple la meta en
## menos de 25 minutos de juego (devuelve el tiempo como par).

const CROPS: Dictionary = {
	"trigo": {"t": 20.0, "seed": 1, "value": 3},
	"maiz": {"t": 35.0, "seed": 2, "value": 5},
	"zanahoria": {"t": 50.0, "seed": 3, "value": 8},
	"fresa": {"t": 70.0, "seed": 4, "value": 11},
	"calabaza": {"t": 100.0, "seed": 6, "value": 16},
}
const ANIMALS: Dictionary = {
	"G": {"kind": "gallina", "product": "huevo", "t": 30.0, "count": 3},
	"V": {"kind": "vaca", "product": "leche", "t": 50.0, "count": 2},
	"O": {"kind": "oveja", "product": "lana", "t": 70.0, "count": 2},
}
## Maquinas: letra -> recetas {producto: [ingredientes, segundos, cantidad]}.
const MACHINES: Dictionary = {
	"M": {"name": "molino", "recipes": {"pienso": [{"trigo": 2, "maiz": 1}, 10.0, 3]}},
	"P": {"name": "panaderia", "recipes": {"pan": [{"trigo": 3}, 25.0, 1], "galletas": [{"trigo": 2, "huevo": 1}, 35.0, 1]}},
	"Q": {"name": "queseria", "recipes": {"queso": [{"leche": 2}, 40.0, 1], "mantequilla": [{"leche": 1}, 25.0, 1]}},
	"T": {"name": "pasteleria", "recipes": {"tarta_fresa": [{"fresa": 2, "huevo": 1, "trigo": 1}, 50.0, 1], "pastel_calabaza": [{"calabaza": 1, "huevo": 1, "trigo": 1}, 60.0, 1]}},
	"J": {"name": "telar", "recipes": {"jersey": [{"lana": 2}, 55.0, 1]}},
}
const QUEUE_MAX: int = 3
const HARVEST: int = 2
const REJECT_WAIT: float = 20.0
const LIMIT_T: float = 1500.0
const FEED: String = "pienso"


## Valor de cualquier producto (cultivos por tabla; lo demas por lo que cuesta hacerlo).
static func value(item: String) -> float:
	if CROPS.has(item):
		return float(CROPS[item]["value"])
	match item:
		"pienso":
			return 3.0
		"huevo":
			return 9.0
		"leche":
			return 14.0
		"lana":
			return 20.0
	var r: Array = recipe_of(item)
	if r.is_empty():
		return 1.0
	var v: float = 0.0
	for k: Variant in (r[0] as Dictionary):
		v += value(str(k)) * float(r[0][k])
	return (v + float(r[1]) * 0.25) / float(r[2]) * 1.3


static func recipe_of(item: String) -> Array:
	for m: Variant in MACHINES:
		var rs: Dictionary = MACHINES[m]["recipes"]
		if rs.has(item):
			return rs[item]
	return []


static func machine_of(item: String) -> String:
	for m: Variant in MACHINES:
		if (MACHINES[m]["recipes"] as Dictionary).has(item):
			return str(m)
	return ""


static func parse(level: Dictionary) -> Dictionary:
	var rows: Array[String] = []
	for r: Variant in level.get("map", []):
		rows.append(str(r))
	var plots: Array[Vector2i] = []
	var animals: Array = []
	var machines: Array = []
	var error: String = ""
	for y: int in rows.size():
		if rows[y].length() != rows[0].length():
			error = "farm_bad_rows"
		for x: int in rows[y].length():
			var ch: String = rows[y][x]
			if ch == ".":
				plots.append(Vector2i(x, y))
			elif ANIMALS.has(ch):
				animals.append([ch, Vector2i(x, y)])
			elif MACHINES.has(ch):
				machines.append([ch, Vector2i(x, y)])
			elif not ",~th".contains(ch):
				error = "farm_bad_char"
	return {"rows": rows, "plots": plots, "animals": animals, "machines": machines, "error": error}


## Lo que se puede conseguir en este nivel (para los pedidos).
static func available(level: Dictionary) -> Array[String]:
	var p: Dictionary = parse(level)
	var out: Array[String] = []
	for c: Variant in level.get("crops", ["trigo"]):
		if CROPS.has(str(c)):
			out.append(str(c))
	var has_feed: bool = false
	for m: Array in p["machines"]:
		if str(m[0]) == "M":
			has_feed = true
	for a: Array in p["animals"]:
		if has_feed and out.has("trigo") and out.has("maiz"):
			out.append(str(ANIMALS[a[0]]["product"]))
	for m: Array in p["machines"]:
		for item: Variant in MACHINES[m[0]]["recipes"]:
			if item == FEED:
				continue
			var ok: bool = true
			for ing: Variant in MACHINES[m[0]]["recipes"][item][0]:
				if not out.has(str(ing)):
					ok = false
			if ok and not out.has(str(item)):
				out.append(str(item))
	return out


static func new_state(level: Dictionary) -> Dictionary:
	var p: Dictionary = parse(level)
	var plots: Array = []
	for c: Vector2i in p["plots"]:
		plots.append({"cell": c, "crop": "", "t": 0.0})
	var animals: Array = []
	for a: Array in p["animals"]:
		for k: int in int(ANIMALS[a[0]]["count"]):
			animals.append({"key": a[0], "cell": a[1], "fed": false, "t": 0.0, "ready": false, "slot": k})
	var machines: Array = []
	for m: Array in p["machines"]:
		machines.append({"key": m[0], "cell": m[1], "queue": [], "t": 0.0, "done": []})
	var st: Dictionary = {"coins": float(level.get("coins", 20)), "inv": {}, "plots": plots, "animals": animals, "machines": machines,
		"orders": [], "done": 0, "goal": int(level.get("goal", 5)), "time": 0.0, "avail": available(level),
		"seed": int(level.get("seed", 1)), "n": 0, "crops": level.get("crops", ["trigo"]), "wait": 0.0}
	for k: int in 3:
		(st["orders"] as Array).append(_new_order(st))
	return st


## Pedido nuevo: 1 a 3 cosas de lo que se puede hacer, con mas variedad segun se avanza.
static func _new_order(st: Dictionary) -> Dictionary:
	var rnd: RandomNumberGenerator = RandomNumberGenerator.new()
	rnd.seed = int(st["seed"]) * 1009 + int(st["n"]) * 7919
	st["n"] = int(st["n"]) + 1
	var avail: Array = st["avail"]
	var pool: Array = []
	for it: Variant in avail:
		if str(it) != FEED:
			pool.append(str(it))
	var kinds: int = mini(rnd.randi_range(1, 2 + mini(int(st["n"]) / 4, 1)), pool.size())
	var items: Dictionary = {}
	var total: float = 0.0
	for k: int in kinds:
		var it: String = pool[rnd.randi_range(0, pool.size() - 1)]
		var v: float = value(it)
		var qty: int = clampi(int(round(24.0 / v)) + rnd.randi_range(-1, 1), 1, 8)
		items[it] = int(items.get(it, 0)) + qty
		total += v * float(qty)
	return {"items": items, "reward": int(ceil(total * 1.5)), "xp": int(ceil(total / 4.0))}


static func count(st: Dictionary, item: String) -> int:
	return int((st["inv"] as Dictionary).get(item, 0))


static func add(st: Dictionary, item: String, n: int) -> void:
	st["inv"][item] = count(st, item) + n


# ------------------------------------------------------------------ simulacion

static func step(st: Dictionary, dt: float) -> void:
	st["time"] = float(st["time"]) + dt
	st["wait"] = maxf(0.0, float(st["wait"]) - dt)
	for p: Dictionary in st["plots"]:
		if str(p["crop"]) != "":
			p["t"] = float(p["t"]) + dt
	for a: Dictionary in st["animals"]:
		if a["fed"] and not a["ready"]:
			a["t"] = float(a["t"]) + dt
			if float(a["t"]) >= float(ANIMALS[a["key"]]["t"]):
				a["ready"] = true
	for m: Dictionary in st["machines"]:
		var q: Array = m["queue"]
		if q.is_empty():
			continue
		m["t"] = float(m["t"]) + dt
		var r: Array = MACHINES[m["key"]]["recipes"][q[0]]
		if float(m["t"]) >= float(r[1]):
			(m["done"] as Array).append(q[0])
			q.pop_front()
			m["t"] = 0.0


static func ready(p: Dictionary) -> bool:
	return str(p["crop"]) != "" and float(p["t"]) >= float(CROPS[p["crop"]]["t"])


# ------------------------------------------------------------------ acciones

static func plant(st: Dictionary, i: int, crop: String) -> bool:
	if i < 0 or i >= (st["plots"] as Array).size() or not (st["crops"] as Array).has(crop):
		return false
	var p: Dictionary = st["plots"][i]
	var cost: float = float(CROPS[crop]["seed"])
	if str(p["crop"]) != "" or float(st["coins"]) < cost:
		return false
	st["coins"] = float(st["coins"]) - cost
	p["crop"] = crop
	p["t"] = 0.0
	return true


static func harvest(st: Dictionary, i: int) -> bool:
	var p: Dictionary = st["plots"][i]
	if not ready(p):
		return false
	add(st, str(p["crop"]), HARVEST)
	p["crop"] = ""
	p["t"] = 0.0
	return true


## Toque en un animal: si tiene producto se recoge; si no, se le da pienso.
static func tend(st: Dictionary, i: int) -> bool:
	var a: Dictionary = st["animals"][i]
	if a["ready"]:
		add(st, str(ANIMALS[a["key"]]["product"]), 1)
		a["ready"] = false
		a["fed"] = false
		a["t"] = 0.0
		return true
	if not a["fed"] and count(st, FEED) > 0:
		add(st, FEED, -1)
		a["fed"] = true
		a["t"] = 0.0
		return true
	return false


static func can_make(st: Dictionary, mi: int, item: String) -> bool:
	var m: Dictionary = st["machines"][mi]
	var rs: Dictionary = MACHINES[m["key"]]["recipes"]
	if not rs.has(item) or (m["queue"] as Array).size() >= QUEUE_MAX:
		return false
	for ing: Variant in rs[item][0]:
		if count(st, str(ing)) < int(rs[item][0][ing]):
			return false
	return true


static func make(st: Dictionary, mi: int, item: String) -> bool:
	if not can_make(st, mi, item):
		return false
	var m: Dictionary = st["machines"][mi]
	var r: Array = MACHINES[m["key"]]["recipes"][item]
	for ing: Variant in r[0]:
		add(st, str(ing), -int(r[0][ing]))
	(m["queue"] as Array).append(item)
	return true


## Recoge lo que ha terminado una maquina.
static func collect(st: Dictionary, mi: int) -> int:
	var m: Dictionary = st["machines"][mi]
	var n: int = 0
	for item: Variant in m["done"]:
		var r: Array = MACHINES[m["key"]]["recipes"][item]
		add(st, str(item), int(r[2]))
		n += 1
	(m["done"] as Array).clear()
	return n


static func can_deliver(st: Dictionary, oi: int) -> bool:
	var o: Dictionary = st["orders"][oi]
	for it: Variant in o["items"]:
		if count(st, str(it)) < int(o["items"][it]):
			return false
	return true


static func deliver(st: Dictionary, oi: int) -> bool:
	if not can_deliver(st, oi):
		return false
	var o: Dictionary = st["orders"][oi]
	for it: Variant in o["items"]:
		add(st, str(it), -int(o["items"][it]))
	st["coins"] = float(st["coins"]) + float(o["reward"])
	st["done"] = int(st["done"]) + 1
	st["orders"][oi] = _new_order(st)
	return true


static func reject(st: Dictionary, oi: int) -> bool:
	if float(st["wait"]) > 0.0:
		return false
	st["orders"][oi] = _new_order(st)
	st["wait"] = REJECT_WAIT
	return true


# ------------------------------------------------------------------ bot

## Lo que falta para todos los pedidos (contando ingredientes de lo que hay que fabricar).
static func needs(st: Dictionary) -> Dictionary:
	var need: Dictionary = {}
	for o: Dictionary in st["orders"]:
		for it: Variant in o["items"]:
			_need(need, str(it), int(o["items"][it]))
	## Lo que ya se tiene o esta en camino descuenta.
	var have: Dictionary = (st["inv"] as Dictionary).duplicate()
	for p: Dictionary in st["plots"]:
		if str(p["crop"]) != "":
			have[p["crop"]] = int(have.get(p["crop"], 0)) + HARVEST
	for a: Dictionary in st["animals"]:
		if a["fed"]:
			var pr: String = str(ANIMALS[a["key"]]["product"])
			have[pr] = int(have.get(pr, 0)) + 1
	for m: Dictionary in st["machines"]:
		for it: Variant in (m["queue"] as Array) + (m["done"] as Array):
			var r: Array = MACHINES[m["key"]]["recipes"][it]
			have[it] = int(have.get(it, 0)) + int(r[2])
	var out: Dictionary = {}
	for it: Variant in need:
		var left: int = int(need[it]) - int(have.get(it, 0))
		if left > 0:
			out[it] = left
	return out


static func _need(need: Dictionary, item: String, n: int) -> void:
	need[item] = int(need.get(item, 0)) + n
	var r: Array = recipe_of(item)
	if not r.is_empty():
		for ing: Variant in r[0]:
			_need(need, str(ing), int(ceil(float(n) / float(r[2]))) * int(r[0][ing]))
	for a: Variant in ANIMALS:
		if str(ANIMALS[a]["product"]) == item:
			_need(need, FEED, n)


## Un turno del bot: recoge, entrega, fabrica, alimenta y siembra lo que haga falta.
static func bot_turn(st: Dictionary) -> void:
	for i: int in (st["plots"] as Array).size():
		harvest(st, i)
	for mi: int in (st["machines"] as Array).size():
		collect(st, mi)
	for a: int in (st["animals"] as Array).size():
		if st["animals"][a]["ready"]:
			tend(st, a)
	for oi: int in 3:
		deliver(st, oi)
	var need: Dictionary = needs(st)
	## Maquinas: lo que piden los pedidos y, si faltan, ingredientes intermedios (pienso).
	for mi: int in (st["machines"] as Array).size():
		var m: Dictionary = st["machines"][mi]
		for item: Variant in MACHINES[m["key"]]["recipes"]:
			if int(need.get(item, 0)) > 0 and make(st, mi, str(item)):
				need = needs(st)
	## Animales con hambre.
	for a: int in (st["animals"] as Array).size():
		var an: Dictionary = st["animals"][a]
		if not an["fed"] and not an["ready"] and int(need.get(str(ANIMALS[an["key"]]["product"]), 0)) > 0:
			tend(st, a)
	## Siembra: lo que mas falta (en orden de lo que menos tarda); si no falta nada, trigo.
	var crops: Array = (st["crops"] as Array).duplicate()
	crops.sort_custom(func(a: Variant, b: Variant) -> bool: return float(CROPS[a]["t"]) < float(CROPS[b]["t"]))
	for i: int in (st["plots"] as Array).size():
		if str(st["plots"][i]["crop"]) != "":
			continue
		var pick: String = ""
		for c: Variant in crops:
			if int(need.get(c, 0)) > 0:
				pick = str(c)
				break
		if pick == "":
			pick = str(crops[0])
		if plant(st, i, pick):
			need[pick] = int(need.get(pick, 0)) - HARVEST
	## Un pedido que no avanza nada (falta algo que no hay) se cambia.
	for oi: int in 3:
		for it: Variant in st["orders"][oi]["items"]:
			if not (st["avail"] as Array).has(it):
				reject(st, oi)


static func bot_time(level: Dictionary, limit: float = LIMIT_T) -> float:
	var st: Dictionary = new_state(level)
	var dt: float = 0.5
	var think: float = 0.0
	while float(st["time"]) < limit:
		think -= dt
		if think <= 0.0:
			think = 2.0
			bot_turn(st)
		step(st, dt)
		if int(st["done"]) >= int(st["goal"]):
			return float(st["time"])
	return -1.0


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var p: Dictionary = parse(level)
	if str(p["error"]) != "":
		issues.append(str(p["error"]))
	if (p["plots"] as Array).size() < 4:
		issues.append("farm_plots")
	for c: Variant in level.get("crops", []):
		if not CROPS.has(str(c)):
			issues.append("farm_crop")
	if (level.get("crops", []) as Array).is_empty():
		issues.append("farm_crop")
	if int(level.get("goal", 0)) <= 0:
		issues.append("farm_goal")
	var t: float = -1.0
	if issues.is_empty():
		t = bot_time(level)
		if t < 0.0:
			issues.append("farm_too_slow")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": int(level.get("goal", 0)), "enemies": 0,
		"enemy_problems": [], "par": int(ceil(t)) if t > 0.0 else 0}
