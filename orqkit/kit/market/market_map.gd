extends RefCounted
## Tienda 3D (simulador tipo "idle arcade": My Mini Mart, Burger Please). Reglas, simulacion pura,
## bot y analizador (lo usan el juego, el bot y el analizador).
## 1 - Mapa (game.json -> levels[i].map): la tienda vista desde arriba, una letra por casilla:
##     "#" pared, "." suelo, "1"-"4" caja de un producto (se coge sin fin), "a"-"d" su estanteria,
##     "R" caja registradora, "E" puerta, "S" sitio para contratar reponedor, "K" para contratar
##     cajero, "U" mejora (llevas mas cosas a la vez).
## 2 - Parametros: "goal" (dinero que hay que ganar), "products" (cuantos estan abiertos al
##     empezar), "costs" (lo que cuesta abrir cada producto), "hire" ([reponedor, cajero]),
##     "upgrade" (coste de la mejora), "spawn" (segundos entre clientes), "seed".
## 3 - Los clientes entran, cogen de las estanterias lo que quieren, hacen cola y pagan si hay
##     alguien en la caja; el dinero se queda junto a la caja hasta que lo recoges. Con el dinero
##     abres productos y contratas ayuda pisando su sitio. Se gana al llegar a "goal".

const SPEED: float = 4.2
const R: float = 0.3
const SHELF_CAP: int = 8
const PICK_T: float = 0.12
const SERVE_T: float = 0.55
const PATIENCE: float = 30.0
const PRICES: Array[int] = [4, 6, 9, 14]
const HELPER_SPEED: float = 3.2


static func rows(level: Dictionary) -> Array:
	var m: Variant = level.get("map", [])
	var out: Array = []
	if m is Array:
		for r: Variant in m:
			var t: String = str(r)
			if t.begins_with("#") and t.substr(1).is_valid_int():
				continue
			out.append(t)
	return out


static func cell(st: Dictionary, x: int, y: int) -> String:
	var m: Array = st["map"]
	if y < 0 or y >= m.size() or x < 0 or x >= str(m[y]).length():
		return "#"
	return str(m[y])[x]


## Casillas por las que se anda (las cajas, estanterias y la caja registradora son solidas).
static func walkable(st: Dictionary, x: int, y: int) -> bool:
	return ".ESKU".contains(cell(st, x, y))


static func center(c: Vector2i) -> Vector2:
	return Vector2(c) + Vector2(0.5, 0.5)


static func new_state(level: Dictionary) -> Dictionary:
	var m: Array = rows(level)
	var st: Dictionary = {"map": m, "h": m.size(), "w": str(m[0]).length() if m.size() > 0 else 0, "t": 0.0, "money": int(level.get("money", 0)),
		"pile": 0, "earned": 0, "goal": maxi(10, int(level.get("goal", 200))), "won": false, "served": 0, "lost": 0, "events": [],
		"spawn": clampf(float(level.get("spawn", 6.0)), 2.0, 20.0), "spawn_t": 1.0, "customers": [], "serve_t": 0.0,
		"pick_t": 0.0, "pay_t": 0.0, "helpers": {}, "cid": 0}
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(level.get("seed", 1))
	st["rng"] = rng
	var crates: Dictionary = {}
	var shelves: Dictionary = {}
	var spots: Dictionary = {}
	var register: Vector2i = Vector2i(-1, -1)
	var door: Vector2i = Vector2i(-1, -1)
	for y: int in m.size():
		var row: String = str(m[y])
		for x: int in row.length():
			var c: String = row[x]
			if c >= "1" and c <= "4":
				crates[int(c) - 1] = Vector2i(x, y)
			elif c >= "a" and c <= "d":
				shelves[c.unicode_at(0) - 97] = Vector2i(x, y)
			elif c == "R":
				register = Vector2i(x, y)
			elif c == "E":
				door = Vector2i(x, y)
			elif c in ["S", "K", "U"]:
				spots[c] = Vector2i(x, y)
	st["crates"] = crates
	st["register"] = register
	st["door"] = door
	var costs: Array = level.get("costs", [0, 60, 160, 360])
	var open_n: int = clampi(int(level.get("products", 1)), 1, 4)
	var prods: Array = []
	for k: int in 4:
		if not shelves.has(k) or not crates.has(k):
			continue
		prods.append({"id": k, "shelf": shelves[k], "crate": crates[k], "items": SHELF_CAP / 2 if k < open_n else 0,
			"open": k < open_n, "cost": int(costs[k]) if k < costs.size() else 100 * (k + 1), "paid": 0})
	st["prods"] = prods
	## Sitios para pagar: productos cerrados (en su estanteria) y ayudas.
	var hire: Array = level.get("hire", [120, 200])
	st["spots"] = {}
	if spots.has("S"):
		st["spots"]["S"] = {"c": spots["S"], "cost": int(hire[0]) if hire.size() > 0 else 120, "paid": 0, "done": false}
	if spots.has("K"):
		st["spots"]["K"] = {"c": spots["K"], "cost": int(hire[1]) if hire.size() > 1 else 200, "paid": 0, "done": false}
	if spots.has("U"):
		st["spots"]["U"] = {"c": spots["U"], "cost": int(level.get("upgrade", 80)), "paid": 0, "done": false}
	var start: Vector2 = center(register) + Vector2(0, -1)
	if not walkable(st, register.x, register.y - 1):
		start = center(door) + Vector2(0, -1)
	st["me"] = {"p": start, "carry": [], "cap": 4, "path": []}
	return st


# ------------------------------------------------------------------ guardado (la tienda sigue entre niveles)

static func shop_key(level: Dictionary) -> String:
	return str(hash("|".join(PackedStringArray(rows(level)))))


static func save_data(st: Dictionary, level: Dictionary) -> Dictionary:
	var paid: Dictionary = {}
	for pr: Dictionary in st["prods"]:
		paid[str(pr["id"])] = [int(pr["paid"]), bool(pr["open"])]
	var spots: Dictionary = {}
	for k: String in st["spots"]:
		spots[k] = [int(st["spots"][k]["paid"]), bool(st["spots"][k]["done"])]
	return {"key": shop_key(level), "prods": paid, "spots": spots, "money": int(st["money"]) + int(st["pile"]), "cap": int(st["me"]["cap"])}


static func load_into(st: Dictionary, level: Dictionary, d: Dictionary) -> bool:
	if str(d.get("key", "")) != shop_key(level):
		return false
	var pd: Variant = d.get("prods", {})
	if pd is Dictionary:
		for pr: Dictionary in st["prods"]:
			var v: Variant = (pd as Dictionary).get(str(pr["id"]), [])
			if v is Array and (v as Array).size() == 2:
				pr["paid"] = clampi(int(v[0]), 0, int(pr["cost"]))
				if bool(v[1]) and not bool(pr["open"]):
					pr["open"] = true
					pr["items"] = SHELF_CAP / 2
	var sd: Variant = d.get("spots", {})
	if sd is Dictionary:
		for k: String in st["spots"]:
			var v2: Variant = (sd as Dictionary).get(k, [])
			if v2 is Array and (v2 as Array).size() == 2:
				var sp: Dictionary = st["spots"][k]
				sp["paid"] = clampi(int(v2[0]), 0, int(sp["cost"]))
				sp["done"] = bool(v2[1])
				if bool(sp["done"]) and k != "U":
					(st["helpers"] as Dictionary)[k] = {"p": center(sp["c"]), "carry": [], "cap": 4, "path": []}
	st["money"] = clampi(int(d.get("money", 0)), 0, 1000000)
	st["me"]["cap"] = clampi(int(d.get("cap", 4)), 4, 16)
	return true


# ------------------------------------------------------------------ sitios utiles

## Donde se pone alguien para usar una casilla solida (la casilla libre de al lado mas cercana a la puerta).
static func stand_at(st: Dictionary, c: Vector2i) -> Vector2:
	var best: Vector2 = center(c)
	var bd: float = INF
	var door: Vector2 = center(st["door"])
	for d: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
		var n: Vector2i = c + d
		if walkable(st, n.x, n.y):
			var q: Vector2 = center(n)
			var dd: float = q.distance_to(door)
			if dd < bd:
				bd = dd
				best = q
	return best


static func pile_pos(st: Dictionary) -> Vector2:
	var r: Vector2i = st["register"]
	for d: Vector2i in [Vector2i(1, -1), Vector2i(-1, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
		if walkable(st, r.x + d.x, r.y + d.y):
			return center(r + d)
	return center(r)


static func cashier_pos(st: Dictionary) -> Vector2:
	var r: Vector2i = st["register"]
	if walkable(st, r.x, r.y - 1):
		return center(r + Vector2i(0, -1))
	return stand_at(st, r)


static func queue_pos(st: Dictionary, k: int) -> Vector2:
	var r: Vector2i = st["register"]
	var dir: float = 1.0 if r.x < int(st["w"]) / 2 else -1.0
	return center(r) + Vector2(dir * (1.0 + 0.85 * float(k)), 1.0)


static func prod(st: Dictionary, id: int) -> Dictionary:
	for p: Dictionary in st["prods"]:
		if int(p["id"]) == id:
			return p
	return {}


static func open_ids(st: Dictionary) -> Array[int]:
	var out: Array[int] = []
	for p: Dictionary in st["prods"]:
		if bool(p["open"]):
			out.append(int(p["id"]))
	return out


## Lo siguiente que se puede comprar: {"kind": "prod"/"S"/"K"/"U", "id", "pos", "left"} o {}.
static func next_buy(st: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	for p: Dictionary in st["prods"]:
		if not bool(p["open"]):
			var left: int = int(p["cost"]) - int(p["paid"])
			if best.is_empty() or left < int(best["left"]):
				best = {"kind": "prod", "id": int(p["id"]), "pos": stand_at(st, p["shelf"]), "left": left}
	for k: String in st["spots"]:
		var sp: Dictionary = st["spots"][k]
		if not bool(sp["done"]):
			var left2: int = int(sp["cost"]) - int(sp["paid"])
			if best.is_empty() or left2 < int(best["left"]):
				best = {"kind": k, "id": -1, "pos": center(sp["c"]), "left": left2}
	return best


# ------------------------------------------------------------------ caminos

static func path(st: Dictionary, from: Vector2, to: Vector2) -> Array:
	var s: Vector2i = Vector2i(floori(from.x), floori(from.y))
	var t: Vector2i = Vector2i(floori(to.x), floori(to.y))
	if s == t:
		return [to]
	var came: Dictionary = {s: s}
	var q: Array[Vector2i] = [s]
	var i: int = 0
	while i < q.size():
		var c: Vector2i = q[i]
		i += 1
		if c == t:
			break
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if not came.has(n) and (walkable(st, n.x, n.y) or n == t):
				came[n] = c
				q.append(n)
	if not came.has(t):
		return [to]
	var out: Array = [to]
	var c2: Vector2i = came[t]
	while c2 != s:
		out.push_front(center(c2))
		c2 = came[c2]
	return out


## Mover algo por su camino; devuelve true al llegar.
static func _walk(st: Dictionary, body: Dictionary, speed: float, dt: float) -> bool:
	var pth: Array = body["path"]
	var p: Vector2 = body["p"]
	var left: float = speed * dt
	while left > 0.0 and not pth.is_empty():
		var nx: Vector2 = pth[0]
		var d: float = p.distance_to(nx)
		if d <= left:
			p = nx
			left -= d
			pth.pop_front()
		else:
			body["dir"] = (nx - p).normalized()
			p += (nx - p) / d * left
			left = 0.0
	body["p"] = p
	return pth.is_empty()


static func go(st: Dictionary, body: Dictionary, to: Vector2) -> void:
	if body.get("goal", Vector2.INF) == to and not (body["path"] as Array).is_empty():
		return
	body["goal"] = to
	body["path"] = path(st, body["p"], to)


# ------------------------------------------------------------------ paso

static func _ev(st: Dictionary, kind: String, extra: Dictionary = {}) -> void:
	var e: Dictionary = {"kind": kind}
	e.merge(extra)
	(st["events"] as Array).append(e)


## Mover al jugador (mando: Vector2 en casillas por segundo, ya multiplicado por la velocidad).
static func move_me(st: Dictionary, mv: Vector2, dt: float) -> void:
	var me: Dictionary = st["me"]
	var p: Vector2 = me["p"]
	if mv.length() > 1.0:
		mv = mv.normalized()
	var d: Vector2 = mv * SPEED * dt
	if d.length() > 0.0:
		me["dir"] = d.normalized()
	for axis: int in 2:
		var np: Vector2 = p
		np[axis] += d[axis]
		if _free(st, np):
			p = np
	me["p"] = p


static func _free(st: Dictionary, p: Vector2) -> bool:
	for off: Vector2 in [Vector2(R, 0), Vector2(-R, 0), Vector2(0, R), Vector2(0, -R), Vector2(R, R) * 0.7, Vector2(-R, R) * 0.7, Vector2(R, -R) * 0.7, Vector2(-R, -R) * 0.7]:
		var q: Vector2 = p + off
		if not walkable(st, floori(q.x), floori(q.y)):
			return false
	return true


static func step(st: Dictionary, dt: float) -> void:
	if bool(st["won"]):
		return
	st["t"] = float(st["t"]) + dt
	_customers(st, dt)
	_act(st, st["me"], dt, true)
	_helpers(st, dt)
	_serve(st, dt)
	if int(st["earned"]) >= int(st["goal"]):
		st["won"] = true
		_ev(st, "win")


## Lo que hace alguien (el jugador o un reponedor) segun donde esta: coger de una caja, reponer,
## recoger el dinero y pagar en un sitio.
static func _act(st: Dictionary, body: Dictionary, dt: float, is_me: bool) -> void:
	var p: Vector2 = body["p"]
	var carry: Array = body["carry"]
	body["pick_t"] = float(body.get("pick_t", 0.0)) - dt
	for pr: Dictionary in st["prods"]:
		if not bool(pr["open"]):
			continue
		var id: int = int(pr["id"])
		## Coger de la caja (de un solo producto a la vez).
		if p.distance_to(center(pr["crate"])) < 1.15 and carry.size() < int(body["cap"]) and (carry.is_empty() or int(carry[0]) == id):
			if float(body["pick_t"]) <= 0.0:
				carry.append(id)
				body["pick_t"] = PICK_T
				if is_me:
					_ev(st, "pick", {"id": id})
		## Reponer la estanteria.
		if p.distance_to(center(pr["shelf"])) < 1.15 and carry.has(id) and int(pr["items"]) < SHELF_CAP:
			if float(body["pick_t"]) <= 0.0:
				carry.erase(id)
				pr["items"] = int(pr["items"]) + 1
				body["pick_t"] = PICK_T
				if is_me:
					_ev(st, "stock", {"id": id})
	if not is_me:
		return
	## Recoger el dinero de la caja.
	if int(st["pile"]) > 0 and p.distance_to(pile_pos(st)) < 1.0:
		st["money"] = int(st["money"]) + int(st["pile"])
		_ev(st, "cash", {"n": int(st["pile"])})
		st["pile"] = 0
	## Pagar: estando encima, el dinero va entrando poco a poco.
	st["pay_t"] = float(st["pay_t"]) - dt
	if int(st["money"]) > 0 and float(st["pay_t"]) <= 0.0:
		for pr2: Dictionary in st["prods"]:
			if not bool(pr2["open"]) and p.distance_to(stand_at(st, pr2["shelf"])) < 0.7:
				_pay(st, pr2)
				if int(pr2["paid"]) >= int(pr2["cost"]):
					pr2["open"] = true
					pr2["items"] = SHELF_CAP / 2
					_ev(st, "unlock", {"what": "prod", "id": int(pr2["id"])})
		for k: String in st["spots"]:
			var sp: Dictionary = st["spots"][k]
			if not bool(sp["done"]) and p.distance_to(center(sp["c"])) < 0.7:
				_pay(st, sp)
				if int(sp["paid"]) >= int(sp["cost"]):
					sp["done"] = true
					if k == "U":
						body["cap"] = int(body["cap"]) + 4
					else:
						(st["helpers"] as Dictionary)[k] = {"p": center(sp["c"]), "carry": [], "cap": 4, "path": []}
					_ev(st, "unlock", {"what": k})


static func _pay(st: Dictionary, thing: Dictionary) -> void:
	var step_n: int = maxi(1, ceili(float(thing["cost"]) / 30.0))
	var n: int = mini(mini(step_n, int(st["money"])), int(thing["cost"]) - int(thing["paid"]))
	thing["paid"] = int(thing["paid"]) + n
	st["money"] = int(st["money"]) - n
	st["pay_t"] = 0.05
	_ev(st, "pay", {"n": n})


static func _cashier_here(st: Dictionary) -> bool:
	if (st["helpers"] as Dictionary).has("K"):
		return true
	return (st["me"]["p"] as Vector2).distance_to(center(st["register"])) < 1.4


## La caja: el primero de la cola paga si hay alguien atendiendo.
static func _serve(st: Dictionary, dt: float) -> void:
	var first: Dictionary = {}
	for c: Dictionary in st["customers"]:
		if str(c["state"]) == "queue" and int(c["slot"]) == 0 and bool(c["at"]):
			first = c
	if first.is_empty() or not _cashier_here(st):
		st["serve_t"] = 0.0
		return
	st["serve_t"] = float(st["serve_t"]) + dt
	if float(st["serve_t"]) < SERVE_T:
		return
	st["serve_t"] = 0.0
	var total: int = 0
	for id: int in first["got"]:
		total += PRICES[id]
	st["pile"] = int(st["pile"]) + total
	st["earned"] = int(st["earned"]) + total
	st["served"] = int(st["served"]) + 1
	first["state"] = "leave"
	go(st, first, center(st["door"]))
	_ev(st, "sale", {"n": total})


static func _customers(st: Dictionary, dt: float) -> void:
	var rng: RandomNumberGenerator = st["rng"]
	var cs: Array = st["customers"]
	st["spawn_t"] = float(st["spawn_t"]) - dt
	var open: Array[int] = open_ids(st)
	if float(st["spawn_t"]) <= 0.0 and cs.size() < 8 and not open.is_empty():
		st["spawn_t"] = float(st["spawn"]) * (1.0 - 0.1 * float(open.size() - 1)) * rng.randf_range(0.8, 1.2)
		var want: Array = []
		for k: int in rng.randi_range(1, mini(3, 1 + open.size())):
			want.append(open[rng.randi_range(0, open.size() - 1)])
		var c: Dictionary = {"id": int(st["cid"]), "p": center(st["door"]) + Vector2(0, 0.4), "want": want, "got": [], "state": "shop",
			"path": [], "wait": 0.0, "take_t": 0.0, "slot": -1, "at": false, "col": rng.randi_range(0, 7)}
		st["cid"] = int(st["cid"]) + 1
		cs.append(c)
	## Huecos de la cola por orden de llegada.
	var slot: int = 0
	for c2: Dictionary in cs:
		if str(c2["state"]) == "queue":
			if int(c2["slot"]) != slot:
				c2["slot"] = slot
				c2["at"] = false
				go(st, c2, queue_pos(st, slot))
			slot += 1
	var k2: int = cs.size() - 1
	while k2 >= 0:
		var c3: Dictionary = cs[k2]
		var state: String = c3["state"]
		if state == "shop":
			var got: Array = c3["got"]
			var want2: Array = c3["want"]
			if got.size() >= want2.size():
				c3["state"] = "queue"
				c3["slot"] = -1
			else:
				var pr: Dictionary = prod(st, int(want2[got.size()]))
				var spot: Vector2 = stand_at(st, pr["shelf"])
				go(st, c3, spot)
				if _walk(st, c3, 2.6, dt):
					c3["wait"] = float(c3["wait"]) + dt
					c3["take_t"] = float(c3["take_t"]) - dt
					if int(pr["items"]) > 0 and float(c3["take_t"]) <= 0.0:
						pr["items"] = int(pr["items"]) - 1
						got.append(int(pr["id"]))
						c3["take_t"] = 0.35
						c3["wait"] = 0.0
		elif state == "queue":
			if int(c3["slot"]) >= 0 and _walk(st, c3, 2.6, dt):
				c3["at"] = true
				c3["wait"] = float(c3["wait"]) + dt
		elif state == "leave":
			if _walk(st, c3, 2.8, dt):
				cs.remove_at(k2)
				k2 -= 1
				continue
		## Sin paciencia se va (sin pagar).
		if state != "leave" and float(c3["wait"]) > PATIENCE:
			c3["state"] = "leave"
			c3["angry"] = true
			st["lost"] = int(st["lost"]) + 1
			for id: int in c3["got"]:
				var pr3: Dictionary = prod(st, id)
				pr3["items"] = mini(SHELF_CAP, int(pr3["items"]) + 1)
			go(st, c3, center(st["door"]))
			_ev(st, "angry")
		k2 -= 1


## Reponedor contratado: lleva a la estanteria que mas lo necesita.
static func _helpers(st: Dictionary, dt: float) -> void:
	var hs: Dictionary = st["helpers"]
	if not hs.has("S"):
		return
	var h: Dictionary = hs["S"]
	var carry: Array = h["carry"]
	if str(h.get("mode", "get")) == "get":
		if carry.is_empty():
			var need: Dictionary = _neediest(st, 6)
			if need.is_empty():
				return
			h["want"] = int(need["id"])
		var pr: Dictionary = prod(st, int(h.get("want", 0)))
		go(st, h, stand_at(st, pr["crate"]))
		if _walk(st, h, HELPER_SPEED, dt):
			_act(st, h, dt, false)
			if carry.size() >= int(h["cap"]):
				h["mode"] = "put"
	else:
		var pr2: Dictionary = prod(st, int(carry[0])) if not carry.is_empty() else {}
		if pr2.is_empty():
			h["mode"] = "get"
			return
		go(st, h, stand_at(st, pr2["shelf"]))
		if _walk(st, h, HELPER_SPEED, dt):
			_act(st, h, dt, false)
			if carry.is_empty() or int(pr2["items"]) >= SHELF_CAP:
				carry.clear()
				h["mode"] = "get"


static func _neediest(st: Dictionary, below: int) -> Dictionary:
	var best: Dictionary = {}
	for pr: Dictionary in st["prods"]:
		if bool(pr["open"]) and int(pr["items"]) < below and (best.is_empty() or int(pr["items"]) < int(best["items"])):
			best = pr
	return best


# ------------------------------------------------------------------ bot

## El bot: atiende si hay cola, repone lo que falta, recoge el dinero y compra lo siguiente.
## Devuelve el mando (Vector2) para move_me.
static func bot_control(st: Dictionary) -> Vector2:
	var me: Dictionary = st["me"]
	var p: Vector2 = me["p"]
	var carry: Array = me["carry"]
	var goal: Vector2 = cashier_pos(st)
	var queue_n: int = 0
	for c: Dictionary in st["customers"]:
		if str(c["state"]) == "queue":
			queue_n += 1
	var cashier: bool = (st["helpers"] as Dictionary).has("K")
	var buy: Dictionary = next_buy(st)
	if not carry.is_empty():
		var pr: Dictionary = prod(st, int(carry[0]))
		if int(pr["items"]) < SHELF_CAP:
			goal = stand_at(st, pr["shelf"])
		elif queue_n > 0 and not cashier:
			goal = cashier_pos(st)
		else:
			var other: Dictionary = _neediest(st, SHELF_CAP)
			goal = stand_at(st, other["shelf"]) if not other.is_empty() and carry.has(int(other["id"])) else cashier_pos(st)
	elif queue_n > 0 and not cashier:
		goal = cashier_pos(st)
	elif not buy.is_empty() and int(st["money"]) + int(st["pile"]) >= int(buy["left"]):
		goal = pile_pos(st) if int(st["money"]) < int(buy["left"]) else buy["pos"]
	elif not _neediest(st, 4).is_empty():
		goal = stand_at(st, _neediest(st, 4)["crate"])
	elif int(st["pile"]) > 0:
		goal = pile_pos(st)
	elif not _neediest(st, SHELF_CAP).is_empty() and not (st["helpers"] as Dictionary).has("S"):
		goal = stand_at(st, _neediest(st, SHELF_CAP)["crate"])
	if p.distance_to(goal) < 0.15:
		return Vector2.ZERO
	var pth: Array = path(st, p, goal)
	var nx: Vector2 = pth[0] if not pth.is_empty() else goal
	return (nx - p).normalized() * minf(1.0, p.distance_to(nx) / 0.3 + 0.3)


static func bot_play(level: Dictionary, dt: float = 1.0 / 20.0, limit: float = 900.0) -> Dictionary:
	var st: Dictionary = new_state(level)
	while not bool(st["won"]) and float(st["t"]) < limit:
		move_me(st, bot_control(st), dt)
		step(st, dt)
		(st["events"] as Array).clear()
	return {"won": bool(st["won"]), "time": float(st["t"]), "served": int(st["served"]), "lost": int(st["lost"]), "earned": int(st["earned"])}


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var st: Dictionary = new_state(level)
	if int(st["w"]) < 6 or int(st["h"]) < 8:
		issues.append("market_size")
	if (st["register"] as Vector2i).x < 0 or (st["door"] as Vector2i).x < 0:
		issues.append("market_layout")
	if open_ids(st).is_empty():
		issues.append("market_products")
	var par: int = 0
	if issues.is_empty():
		var r: Dictionary = bot_play(level)
		if not bool(r["won"]):
			issues.append("market_too_hard")
		par = int(float(r["time"]) * 1.4) + 20
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": 0, "enemies": 0, "enemy_problems": [], "par": par}
