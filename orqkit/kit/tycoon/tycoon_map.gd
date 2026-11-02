extends RefCounted
## Tycoon (idle de negocios tipo AdVenture Capitalist y de minas tipo Idle Miner Tycoon): reglas,
## simulacion, bot y analizador. Todo por datos: kit/tycoon/tycoon_catalog.json + levels[i]["tycoon"].
## 1 - Modo "biz" (negocios): cada negocio da dinero cada X segundos; comprar mas unidades sube lo
##     que da (cada una un poco mas cara) y al llegar a 25, 50, 100... unidades va el doble de rapido.
## 2 - Modo "mine" (mina): los pozos sacan mineral a su caja, el ascensor lo sube y el almacen lo
##     vende. Cada parte sube de nivel y la mas lenta frena a las demas (el cuello de botella).
## 3 - Sin gerente, cada parte trabaja un ciclo cuando la tocas; con gerente trabaja sola, tambien
##     con la app cerrada (ganancias sin conexion, hasta 2 horas).
## 4 - Mejoras: multiplican lo que da un negocio o un pozo (o todos). Se gana al juntar "target"
##     de dinero ganado. Nivel: "target", "start", "open" (negocios o pozos del nivel), "par" (3
##     estrellas) y "tycoon" (catalogo: "preset" y cambios; null quita una entrada).
## La fabrica (fabrica/niveles/tycoon.py) tiene una copia exacta de la simulacion para calibrar.

const CATALOG_PATH: String = "res://kit/tycoon/tycoon_catalog.json"
const Rules = preload("res://kit/rules.gd")
const DT: float = 0.05
const BOT_EVERY: float = 1.0
## Lo que tarda una persona en volver a tocar algo que se ha parado (de media).
const TAP_DELAY: float = 0.5
const OFFLINE_CAP: float = 7200.0
const LOOKS: Array[String] = ["lemon", "paper", "car", "pizza", "donut", "fish", "ball", "film", "coal", "iron", "copper",
	"silver", "gold", "gem", "shop", "coffee", "bank", "rocket", "farm", "factory", "oil", "phone", "game", "burger", "cake", "hotel"]

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
		_data = parsed if parsed is Dictionary else {"default": {"mode": "biz", "biz": {}}, "presets": {}}
	return _data


## Catalogo del nivel: el de serie, los estilos ("preset", texto o lista) y lo que traiga encima.
static func catalog(level: Dictionary) -> Dictionary:
	var c: Dictionary = (data()["default"] as Dictionary).duplicate(true)
	var extra: Variant = level.get("tycoon", {})
	if extra is Dictionary:
		var pr: Variant = (extra as Dictionary).get("preset", "")
		for p: Variant in (pr if pr is Array else [pr]):
			if (data()["presets"] as Dictionary).has(str(p)):
				_merge(c, data()["presets"][str(p)])
		_merge(c, extra)
	return c


static func _merge(c: Dictionary, extra: Dictionary) -> void:
	for sec: String in ["biz", "shafts"]:
		var add: Variant = extra.get(sec, {})
		if not c.has(sec):
			c[sec] = {}
		if add is Dictionary:
			for k: Variant in add:
				if add[k] is Dictionary:
					var base: Dictionary = (c[sec] as Dictionary).get(str(k), {})
					var merged: Dictionary = base.duplicate(true)
					merged.merge(add[k] as Dictionary, true)
					c[sec][str(k)] = merged
				elif add[k] == null:
					(c[sec] as Dictionary).erase(str(k))
	for sec2: String in ["lift", "store"]:
		if extra.get(sec2, null) is Dictionary:
			var b2: Dictionary = (c.get(sec2, {}) as Dictionary).duplicate(true)
			b2.merge(extra[sec2] as Dictionary, true)
			c[sec2] = b2
	for k2: String in ["mode", "cur", "every"]:
		if extra.has(k2):
			c[k2] = extra[k2]
	for k3: String in ["milestones", "upgrades"]:
		if extra.get(k3, null) is Array:
			c[k3] = (extra[k3] as Array).duplicate(true)


## Ids de una seccion de mas barato a mas caro (asi el orden no depende del archivo).
static func _sorted(sec: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for k: Variant in sec:
		ids.append(str(k))
	ids.sort_custom(func(a: String, b: String) -> bool:
		var ca: float = float((sec[a] as Dictionary).get("cost", 0.0))
		var cb: float = float((sec[b] as Dictionary).get("cost", 0.0))
		return ca < cb or (ca == cb and a < b))
	return ids


# ------------------------------------------------------------------ estado

static func new_state(level: Dictionary, bonus: float = 1.0) -> Dictionary:
	var cat: Dictionary = catalog(level)
	var mode: String = "mine" if str(cat.get("mode", "biz")) == "mine" else "biz"
	var open: int = clampi(int(level.get("open", 99)), 1, 99)
	var st: Dictionary = {"mode": mode, "cat": cat, "money": float(level.get("start", 0.0)), "earned": 0.0,
		"target": maxf(1.0, float(level.get("target", 1000.0))), "t": 0.0, "stations": {}, "order": [], "ups": {}, "upgrades": [],
		"stock": 0.0, "bonus": maxf(1.0, bonus), "taps": 0, "buys": 0, "won": false}
	var stations: Dictionary = st["stations"]
	if mode == "biz":
		var ids: Array[String] = _sorted(cat.get("biz", {}))
		ids = ids.slice(0, open)
		for i: int in ids.size():
			stations[ids[i]] = {"kind": "biz", "n": 1 if i == 0 else 0, "mgr": false, "run": false, "prog": 0.0, "box": 0.0}
		st["order"] = ids
	else:
		var sids: Array[String] = _sorted(cat.get("shafts", {}))
		sids = sids.slice(0, open)
		stations["store"] = {"kind": "store", "n": 1, "mgr": false, "run": false, "prog": 0.0, "box": 0.0}
		stations["lift"] = {"kind": "lift", "n": 1, "mgr": false, "run": false, "prog": 0.0, "box": 0.0}
		for j: int in sids.size():
			stations[sids[j]] = {"kind": "shaft", "n": 1 if j == 0 else 0, "mgr": false, "run": false, "prog": 0.0, "box": 0.0}
		var order: Array = ["store", "lift"]
		order.append_array(sids)
		st["order"] = order
	st["upgrades"] = _upgrades(st)
	st["rules"] = Rules.load_rules(level)
	Rules.hook(st, "on_start")
	return st


## Mejoras del nivel: las del catalogo (de lo que hay en el nivel) o, si no trae, una x3 por
## negocio o pozo (a 5 veces su gerente) y una x2 para todo al final.
static func _upgrades(st: Dictionary) -> Array:
	var cat: Dictionary = st["cat"]
	var out: Array = []
	if cat.get("upgrades", null) is Array:
		for u: Variant in cat["upgrades"]:
			if u is Dictionary and (str(u.get("target", "")) == "all" or (st["stations"] as Dictionary).has(str(u.get("target", "")))):
				out.append({"id": str(u.get("id", str(u.get("target", "")) + "_x" + str(u.get("mult", 2)))), "target": str(u.get("target", "all")),
					"mult": maxf(1.0, float(u.get("mult", 2.0))), "cost": maxf(1.0, float(u.get("cost", 1000.0))), "name": str(u.get("name", ""))})
		return out
	var last: float = 0.0
	for sid: Variant in st["order"]:
		var s: Dictionary = st["stations"][sid]
		if str(s["kind"]) == "biz" or str(s["kind"]) == "shaft":
			var mgr: float = float(info(st, str(sid)).get("manager", 1000.0))
			out.append({"id": str(sid) + "_x3", "target": str(sid), "mult": 3.0, "cost": mgr * 5.0, "name": ""})
			last = maxf(last, mgr)
	if last > 0.0:
		out.append({"id": "all_x2", "target": "all", "mult": 2.0, "cost": last * 20.0, "name": ""})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["cost"]) < float(b["cost"]))
	return out


## Datos de catalogo de una parte.
static func info(st: Dictionary, sid: String) -> Dictionary:
	var cat: Dictionary = st["cat"]
	var kind: String = str((st["stations"][sid] as Dictionary)["kind"])
	if kind == "biz":
		return (cat.get("biz", {}) as Dictionary).get(sid, {})
	if kind == "shaft":
		return (cat.get("shafts", {}) as Dictionary).get(sid, {})
	var d: Dictionary = {"name": "", "cap": 10.0, "time": 3.0, "up": 15.0, "growth": 1.11, "manager": 500.0}
	d.merge(cat.get(kind, {}) as Dictionary, true)
	return d


static func name_of(st: Dictionary, sid: String) -> String:
	return str(info(st, sid).get("name", sid))


static func look_of(st: Dictionary, sid: String) -> String:
	var l: String = str(info(st, sid).get("look", ""))
	var kind: String = str(st["stations"][sid]["kind"])
	if l == "" or not LOOKS.has(l):
		return "shop" if kind == "biz" else ("factory" if kind == "store" else ("rocket" if kind == "lift" else "coal"))
	return l


## Veces que se ha doblado la velocidad (negocios) o lo que da (mina) por las unidades o niveles.
static func doubles(st: Dictionary, sid: String) -> int:
	var s: Dictionary = st["stations"][sid]
	var n: int = int(s["n"])
	if str(st["mode"]) == "biz":
		var k: int = 0
		for m: Variant in (st["cat"] as Dictionary).get("milestones", []):
			if n >= int(m):
				k += 1
		return k
	return n / maxi(1, int((st["cat"] as Dictionary).get("every", 10)))


## Siguiente meta de unidades o niveles (0 si no hay).
static func next_milestone(st: Dictionary, sid: String) -> int:
	var n: int = int(st["stations"][sid]["n"])
	if str(st["mode"]) == "biz":
		for m: Variant in (st["cat"] as Dictionary).get("milestones", []):
			if int(m) > n:
				return int(m)
		return 0
	var e: int = maxi(1, int((st["cat"] as Dictionary).get("every", 10)))
	return (n / e + 1) * e


static func mult(st: Dictionary, sid: String) -> float:
	var m: float = 1.0
	for u: Variant in st["upgrades"]:
		if (st["ups"] as Dictionary).has(str(u["id"])) and (str(u["target"]) == sid or str(u["target"]) == "all"):
			m *= float(u["mult"])
	return m


## Segundos de un ciclo.
static func cycle_time(st: Dictionary, sid: String) -> float:
	var s: Dictionary = st["stations"][sid]
	var t: float = maxf(0.05, float(info(st, sid).get("time", 1.0)))
	if str(s["kind"]) == "biz":
		return maxf(0.05, t / pow(2.0, float(doubles(st, sid))))
	if str(s["kind"]) == "lift":
		return t + 0.5 * float(maxi(0, open_shafts(st) - 1))
	return t


static func open_shafts(st: Dictionary) -> int:
	var k: int = 0
	for sid: Variant in st["order"]:
		var s: Dictionary = st["stations"][sid]
		if str(s["kind"]) == "shaft" and int(s["n"]) > 0:
			k += 1
	return k


## Lo que da (o lleva) un ciclo.
static func amount(st: Dictionary, sid: String) -> float:
	var s: Dictionary = st["stations"][sid]
	var n: float = float(s["n"])
	var inf: Dictionary = info(st, sid)
	match str(s["kind"]):
		"biz":
			return n * float(inf.get("profit", 1.0)) * mult(st, sid) * float(st["bonus"])
		"shaft":
			return n * float(inf.get("value", 1.0)) * pow(2.0, float(doubles(st, sid))) * mult(st, sid) * float(st["bonus"])
		_:
			return n * float(inf.get("cap", 10.0)) * pow(2.0, float(doubles(st, sid))) * float(st["bonus"])


# ------------------------------------------------------------------ compras

## Coste de comprar 'count' unidades (negocios) o niveles (mina) a partir de los que hay.
static func cost(st: Dictionary, sid: String, count: int = 1) -> float:
	var s: Dictionary = st["stations"][sid]
	var inf: Dictionary = info(st, sid)
	var g: float = maxf(1.0001, float(inf.get("growth", 1.1)))
	var n: int = int(s["n"])
	var base: float
	if str(s["kind"]) == "biz":
		base = float(inf.get("cost", 1.0)) * pow(g, float(n))
	elif n == 0:
		return float(inf.get("cost", 1.0))
	else:
		base = float(inf.get("up", 10.0)) * pow(g, float(n - 1))
	return base * (pow(g, float(count)) - 1.0) / (g - 1.0)


## Cuantas se pueden comprar con el dinero que hay (para el boton MAX).
static func max_count(st: Dictionary, sid: String) -> int:
	var s: Dictionary = st["stations"][sid]
	if str(s["kind"]) != "biz" and int(s["n"]) == 0:
		return 1 if float(st["money"]) >= cost(st, sid, 1) else 0
	var c1: float = cost(st, sid, 1)
	if float(st["money"]) < c1:
		return 0
	var g: float = maxf(1.0001, float(info(st, sid).get("growth", 1.1)))
	var k: int = int(floor(log(float(st["money"]) * (g - 1.0) / c1 + 1.0) / log(g)))
	while k > 1 and cost(st, sid, k) > float(st["money"]):
		k -= 1
	return maxi(1, k)


static func buy(st: Dictionary, sid: String, count: int = 1) -> bool:
	if not (st["stations"] as Dictionary).has(sid) or count <= 0:
		return false
	var s: Dictionary = st["stations"][sid]
	if str(s["kind"]) != "biz" and int(s["n"]) == 0:
		count = 1
	var c: float = cost(st, sid, count)
	if c > float(st["money"]) + 0.0001:
		return false
	st["money"] = float(st["money"]) - c
	s["n"] = int(s["n"]) + count
	st["buys"] = int(st["buys"]) + 1
	Rules.hook(st, "on_buy", [sid, count])
	return true


static func manager_cost(st: Dictionary, sid: String) -> float:
	return float(info(st, sid).get("manager", 1000.0))


static func hire(st: Dictionary, sid: String) -> bool:
	var s: Dictionary = st["stations"][sid]
	if bool(s["mgr"]) or int(s["n"]) <= 0:
		return false
	var c: float = manager_cost(st, sid)
	if c > float(st["money"]) + 0.0001:
		return false
	st["money"] = float(st["money"]) - c
	s["mgr"] = true
	s["run"] = true
	st["buys"] = int(st["buys"]) + 1
	return true


static func upgrade_by_id(st: Dictionary, uid: String) -> Dictionary:
	for u: Variant in st["upgrades"]:
		if str(u["id"]) == uid:
			return u
	return {}


static func buy_upgrade(st: Dictionary, uid: String) -> bool:
	var u: Dictionary = upgrade_by_id(st, uid)
	if u.is_empty() or (st["ups"] as Dictionary).has(uid) or float(u["cost"]) > float(st["money"]) + 0.0001:
		return false
	st["money"] = float(st["money"]) - float(u["cost"])
	st["ups"][uid] = true
	st["buys"] = int(st["buys"]) + 1
	return true


## Las mejoras que aun no se han comprado, de mas barata a mas cara.
static func pending_upgrades(st: Dictionary) -> Array:
	var out: Array = []
	for u: Variant in st["upgrades"]:
		if not (st["ups"] as Dictionary).has(str(u["id"])):
			out.append(u)
	return out


## Tocar una parte parada: trabaja un ciclo.
static func tap(st: Dictionary, sid: String) -> bool:
	var s: Dictionary = st["stations"][sid]
	if int(s["n"]) <= 0 or bool(s["run"]):
		return false
	s["run"] = true
	st["taps"] = int(st["taps"]) + 1
	return true


# ------------------------------------------------------------------ simulacion

## Avanza el tiempo. Devuelve los ciclos acabados [[id, cantidad]] (para los efectos).
static func step(st: Dictionary, dt: float) -> Array:
	var done: Array = []
	st["t"] = float(st["t"]) + dt
	for sid: Variant in st["order"]:
		var s: Dictionary = st["stations"][sid]
		if int(s["n"]) <= 0 or not (bool(s["run"]) or bool(s["mgr"])):
			continue
		s["run"] = true
		var ct: float = cycle_time(st, str(sid))
		s["prog"] = float(s["prog"]) + dt / ct
		var guard: int = 0
		while float(s["prog"]) >= 1.0 and guard < 50:
			guard += 1
			var got: float = _complete(st, str(sid))
			Rules.hook(st, "on_cycle", [str(sid), got])
			done.append([str(sid), got])
			if bool(s["mgr"]):
				s["prog"] = float(s["prog"]) - 1.0
			else:
				s["prog"] = 0.0
				s["run"] = false
				break
	Rules.hook(st, "on_step", [dt])
	if float(st["earned"]) >= float(st["target"]):
		st["won"] = true
	return done


static func _complete(st: Dictionary, sid: String) -> float:
	var s: Dictionary = st["stations"][sid]
	var a: float = amount(st, sid)
	match str(s["kind"]):
		"biz":
			_earn(st, a)
			return a
		"shaft":
			s["box"] = float(s["box"]) + a
			return a
		"lift":
			var left: float = a
			for sid2: Variant in st["order"]:
				var s2: Dictionary = st["stations"][sid2]
				if str(s2["kind"]) == "shaft" and left > 0.0:
					var take: float = minf(left, float(s2["box"]))
					s2["box"] = float(s2["box"]) - take
					left -= take
			st["stock"] = float(st["stock"]) + (a - left)
			return a - left
		_:
			var sell: float = minf(a, float(st["stock"]))
			st["stock"] = float(st["stock"]) - sell
			_earn(st, sell)
			return sell


static func _earn(st: Dictionary, a: float) -> void:
	st["money"] = float(st["money"]) + a
	st["earned"] = float(st["earned"]) + a


## Dinero por segundo que da todo seguido. 'managed_only': solo lo que tiene gerente (sin conexion);
## si no, lo que no tiene gerente cuenta con lo que tarda una persona en volver a tocarlo.
static func rate(st: Dictionary, managed_only: bool = false, soft: bool = false) -> float:
	var biz: float = 0.0
	var shafts: float = 0.0
	var lift: float = INF
	var store: float = INF
	for sid: Variant in st["order"]:
		var s: Dictionary = st["stations"][sid]
		if int(s["n"]) <= 0:
			if str(s["kind"]) == "lift":
				lift = 0.0
			elif str(s["kind"]) == "store":
				store = 0.0
			continue
		var ct: float = cycle_time(st, str(sid))
		var eff: float = 1.0 if bool(s["mgr"]) else (0.0 if managed_only else ct / (ct + TAP_DELAY))
		var r: float = amount(st, str(sid)) / ct * eff
		match str(s["kind"]):
			"biz":
				biz += r
			"shaft":
				shafts += r
			"lift":
				lift = r
			_:
				store = r
	if str(st["mode"]) == "biz":
		return biz
	if soft:
		## Para que el bot vea que subir algo que no es el cuello de botella tambien ayuda (si
		## no, con dos partes igualadas ninguna compra sube nada).
		if minf(shafts, minf(lift, store)) <= 0.0:
			return 0.0
		return pow(pow(shafts, -4.0) + pow(lift, -4.0) + pow(store, -4.0), -0.25)
	return minf(shafts, minf(lift, store))


## Ganancias con la app cerrada: lo que tiene gerente, hasta 2 horas.
static func offline_gain(st: Dictionary, seconds: float) -> float:
	return rate(st, true) * clampf(seconds, 0.0, OFFLINE_CAP)


# ------------------------------------------------------------------ bot

## Lo que haria una persona lista: la compra que mas rinde para lo que cuesta, contando lo que
## falta para poder pagarla. {"kind": "buy"|"count"|"mgr"|"up", "id", "count", "cost"} o {}.
static func best_buy(st: Dictionary) -> Dictionary:
	var r0: float = rate(st)
	var rs: float = rate(st, false, true)
	var best: Dictionary = {}
	var bs: float = INF
	var cands: Array = []
	for sid: Variant in st["order"]:
		var s: Dictionary = st["stations"][sid]
		cands.append({"kind": "buy", "id": str(sid), "count": 1})
		var nm: int = next_milestone(st, str(sid))
		if int(s["n"]) > 0 and nm > int(s["n"]) + 1 and nm - int(s["n"]) <= 25:
			cands.append({"kind": "buy", "id": str(sid), "count": nm - int(s["n"])})
		if int(s["n"]) > 0 and not bool(s["mgr"]):
			cands.append({"kind": "mgr", "id": str(sid), "count": 0})
	for u: Variant in pending_upgrades(st):
		cands.append({"kind": "up", "id": str(u["id"]), "count": 0})
	for c: Dictionary in cands:
		var price: float = _price(st, c)
		var gain: float = _gain(st, c, rs)
		if gain <= 0.0:
			continue
		var wait: float = maxf(0.0, price - float(st["money"])) / maxf(r0, 0.000001)
		if r0 <= 0.0 and price > float(st["money"]):
			continue
		var score: float = price / gain + wait
		if score < bs:
			bs = score
			best = c
			best["cost"] = price
	return best


static func _price(st: Dictionary, c: Dictionary) -> float:
	match str(c["kind"]):
		"buy":
			return cost(st, str(c["id"]), maxi(1, int(c["count"])))
		"mgr":
			return manager_cost(st, str(c["id"]))
		_:
			return float(upgrade_by_id(st, str(c["id"])).get("cost", INF))


## Cuanto sube el dinero por segundo con esa compra (se prueba en una copia).
static func _gain(st: Dictionary, c: Dictionary, r0: float) -> float:
	var stations: Dictionary = st["stations"]
	var keep_n: Dictionary = {}
	var keep_mgr: Dictionary = {}
	var sid: String = str(c["id"])
	var r1: float = r0
	match str(c["kind"]):
		"buy":
			var s: Dictionary = stations[sid]
			var old: int = int(s["n"])
			s["n"] = old + (1 if str(s["kind"]) != "biz" and old == 0 else maxi(1, int(c["count"])))
			r1 = rate(st, false, true)
			s["n"] = old
			## Abrir un pozo nuevo sin capacidad no sube nada al momento, pero abre camino: cuenta
			## como lo que daria si el ascensor y el almacen pudieran.
			if str(s["kind"]) == "shaft" and old == 0:
				r1 = maxf(r1, r0 + amount_if(st, sid, 1) / cycle_time(st, sid) * 0.25)
		"mgr":
			var s2: Dictionary = stations[sid]
			s2["mgr"] = true
			r1 = rate(st, false, true)
			s2["mgr"] = false
		_:
			st["ups"][sid] = true
			r1 = rate(st, false, true)
			(st["ups"] as Dictionary).erase(sid)
	return r1 - r0


static func amount_if(st: Dictionary, sid: String, n: int) -> float:
	var s: Dictionary = st["stations"][sid]
	var old: int = int(s["n"])
	s["n"] = n
	var a: float = amount(st, sid)
	s["n"] = old
	return a


static func apply_buy(st: Dictionary, c: Dictionary) -> bool:
	match str(c.get("kind", "")):
		"buy":
			return buy(st, str(c["id"]), maxi(1, int(c["count"])))
		"mgr":
			return hire(st, str(c["id"]))
		"up":
			return buy_upgrade(st, str(c["id"]))
	return false


## Un "pensamiento" del bot (cada segundo): toca lo parado y compra lo que convenga (hasta 6).
static func bot_tick(st: Dictionary) -> void:
	for sid: Variant in st["order"]:
		tap(st, str(sid))
	for k: int in 6:
		var b: Dictionary = best_buy(st)
		if b.is_empty() or float(b["cost"]) > float(st["money"]) or not apply_buy(st, b):
			break


## Juega el nivel con el bot hasta la meta o 'limit' segundos. {"won", "time", "buys", "taps"}.
static func bot_play(level: Dictionary, limit: float = 900.0) -> Dictionary:
	var st: Dictionary = new_state(level)
	var next_think: float = 0.0
	while float(st["t"]) < limit and not bool(st["won"]):
		if float(st["t"]) >= next_think:
			bot_tick(st)
			next_think += BOT_EVERY
		step(st, DT)
	return {"won": bool(st["won"]), "time": snappedf(float(st["t"]), 0.01), "buys": int(st["buys"]), "taps": int(st["taps"])}


## Analizador: catalogo sano y el bot llega a la meta a tiempo (ni un paseo ni eterno).
static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var st: Dictionary = new_state(level)
	if (st["order"] as Array).size() < (3 if str(st["mode"]) == "mine" else 2):
		issues.append("tycoon_few_stations")
	for sid: Variant in st["order"]:
		var inf: Dictionary = info(st, str(sid))
		for k: String in (["cost", "growth", "time", "profit", "manager"] if str(st["stations"][sid]["kind"]) == "biz" else ["time", "manager"]):
			if float(inf.get(k, 0.0)) <= 0.0 and not (k == "cost"):
				issues.append("tycoon_bad_" + k + "_" + str(sid))
	var par: float = maxf(30.0, float(level.get("par", 180.0)))
	var limit: float = minf(900.0, maxf(par * 1.6, par + 60.0))
	var r: Dictionary = {"won": false, "time": 0.0}
	if issues.is_empty():
		r = bot_play(level, limit)
		if not bool(r["won"]):
			issues.append("tycoon_too_slow")
		elif float(r["time"]) < 15.0:
			issues.append("tycoon_too_easy")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": 0, "enemies": 0, "enemy_problems": [], "time": r.get("time", 0.0)}


## Numeros cortos: 1.2K, 3.4M, 5.6B, 7.8T y luego aa, ab...
static func fmt(v: float) -> String:
	if v < 1000.0:
		return str(int(floor(v)))
	var units: Array[String] = ["K", "M", "B", "T"]
	var e: int = int(floor(log(v) / log(1000.0)))
	var u: String
	if e - 1 < units.size():
		u = units[e - 1]
	else:
		var k: int = e - 1 - units.size()
		u = char(97 + (k / 26) % 26) + char(97 + k % 26)
	var x: float = v / pow(1000.0, float(e))
	if x >= 100.0:
		return "%d%s" % [int(x), u]
	if x >= 10.0:
		return "%.1f%s" % [floorf(x * 10.0) / 10.0, u]
	return "%.2f%s" % [floorf(x * 100.0) / 100.0, u]
