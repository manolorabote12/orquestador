extends RefCounted
## Ciudad (constructor estilo Pocket City / SimCity BuildIt): reglas, simulacion pura, bot y
## analizador.
## 1 - Mapa (game.json -> levels[i].map): "." solar libre, "~" agua, "^" bosque (se puede talar
##     pagando), "=" carretera ya hecha y "T" ayuntamiento (de ahi salen las carreteras).
## 2 - Construyes carreteras, casas, tiendas, fabricas y parques. Solo funciona lo que toca una
##     carretera unida al ayuntamiento.
## 3 - Cada segundo: las casas se llenan hasta su capacidad si hay trabajo (tiendas y fabricas) y
##     segun la felicidad (parques cerca suben, fabricas cerca bajan). Una casa feliz y llena
##     sube a bloque de pisos (mas gente). Impuestos: dinero por habitante y por tienda con
##     clientes.
## 4 - Se gana al llegar a "goal" habitantes antes de "seconds". Parametros: "money" (de salida).

const BUILD: Dictionary = {
	"road": {"cost": 10, "ch": "="},
	"house": {"cost": 50, "ch": "H"},
	"shop": {"cost": 90, "ch": "S"},
	"factory": {"cost": 140, "ch": "F"},
	"park": {"cost": 60, "ch": "P"},
}
const CLEAR_COST: int = 20
const HOUSE_CAP: Array[int] = [8, 22]
const SHOP_JOBS: int = 6
const FACTORY_JOBS: int = 14
const TAX: float = 0.12
const SHOP_INCOME: float = 0.9
const UPGRADE_TIME: float = 12.0


static func new_state(level: Dictionary) -> Dictionary:
	var rows: Array = level.get("map", [])
	var grid: Array = []
	var w: int = 0
	for r: Variant in rows:
		w = maxi(w, str(r).length())
	var hall: Vector2i = Vector2i(-1, -1)
	for y: int in rows.size():
		var row: Array = []
		var s: String = str(rows[y])
		for x: int in w:
			var ch: String = s[x] if x < s.length() else "."
			if ch == "T":
				hall = Vector2i(x, y)
			row.append(ch)
		grid.append(row)
	return {"grid": grid, "w": w, "h": rows.size(), "hall": hall, "money": float(level.get("money", 400)), "pop": 0.0,
		"houses": {}, "time": 0.0, "seconds": float(level.get("seconds", 240)), "goal": int(level.get("goal", 100)),
		"won": false, "over": false, "tick": 0.0, "jobs": 0, "happy": 1.0, "connected": {}}


static func at(st: Dictionary, c: Vector2i) -> String:
	if c.x < 0 or c.y < 0 or c.x >= int(st["w"]) or c.y >= int(st["h"]):
		return "#"
	return str(st["grid"][c.y][c.x])


const N4: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


## Casillas de carretera unidas al ayuntamiento.
static func road_net(st: Dictionary) -> Dictionary:
	var seen: Dictionary = {}
	var q: Array = [st["hall"]]
	seen[st["hall"]] = true
	while not q.is_empty():
		var c: Vector2i = q.pop_back()
		for d: Vector2i in N4:
			var n: Vector2i = c + d
			if not seen.has(n) and at(st, n) == "=":
				seen[n] = true
				q.append(n)
	return seen


static func on_road(st: Dictionary, c: Vector2i, net: Dictionary) -> bool:
	for d: Vector2i in N4:
		if net.has(c + d):
			return true
	return false


## Se puede construir "what" en c? Devuelve el coste total (con talar) o -1.
static func cost_at(st: Dictionary, what: String, c: Vector2i) -> int:
	if not BUILD.has(what):
		return -1
	var ch: String = at(st, c)
	if ch != "." and ch != "^":
		return -1
	var cost: int = int(BUILD[what]["cost"]) + (CLEAR_COST if ch == "^" else 0)
	if what == "road":
		## Las carreteras tienen que salir de la red.
		var net: Dictionary = road_net(st)
		if not on_road(st, c, net):
			return -1
	return cost


static func build(st: Dictionary, what: String, c: Vector2i) -> bool:
	var cost: int = cost_at(st, what, c)
	if cost < 0 or float(st["money"]) < float(cost):
		return false
	st["money"] = float(st["money"]) - float(cost)
	st["grid"][c.y][c.x] = str(BUILD[what]["ch"])
	if what == "house":
		st["houses"][c] = {"pop": 0.0, "lvl": 0, "happy_t": 0.0}
	return true


## Felicidad de una casa: parques a 2 casillas suben, fabricas a 2 casillas bajan.
static func happiness(st: Dictionary, c: Vector2i) -> float:
	var h: float = 1.0
	for dy: int in range(-2, 3):
		for dx: int in range(-2, 3):
			var ch: String = at(st, c + Vector2i(dx, dy))
			if ch == "P":
				h += 0.25
			elif ch == "F":
				h -= 0.3
	return clampf(h, 0.3, 1.75)


## 1 - Un segundo de ciudad.
static func _tick(st: Dictionary) -> void:
	var net: Dictionary = road_net(st)
	var jobs: int = 0
	var shops: int = 0
	for y: int in int(st["h"]):
		for x: int in int(st["w"]):
			var ch: String = str(st["grid"][y][x])
			if (ch == "S" or ch == "F") and on_road(st, Vector2i(x, y), net):
				jobs += SHOP_JOBS if ch == "S" else FACTORY_JOBS
				if ch == "S":
					shops += 1
	st["jobs"] = jobs
	## Sin trabajo para todos, la ciudad no pasa de 1,3 personas por puesto.
	var cap_jobs: float = float(jobs) * 1.3 + 6.0
	var pop: float = 0.0
	var connected: Dictionary = {}
	var hsum: float = 0.0
	for c: Variant in st["houses"]:
		var hs: Dictionary = st["houses"][c]
		var ok: bool = on_road(st, c, net)
		if ok:
			connected[c] = true
		var hap: float = happiness(st, c)
		hsum += hap
		var cap: float = float(HOUSE_CAP[int(hs["lvl"])]) * minf(1.0, hap) if ok else 0.0
		var p: float = float(hs["pop"])
		p += (cap - p) * 0.12 if p < cap else (cap - p) * 0.3
		hs["pop"] = maxf(0.0, p)
		## Casa feliz y casi llena: tras un rato sube a bloque de pisos.
		if ok and int(hs["lvl"]) == 0 and hap >= 1.2 and p >= cap * 0.9:
			hs["happy_t"] = float(hs["happy_t"]) + 1.0
			if float(hs["happy_t"]) >= UPGRADE_TIME:
				hs["lvl"] = 1
		pop += float(hs["pop"])
	if pop > cap_jobs:
		var k: float = cap_jobs / pop
		for c2: Variant in st["houses"]:
			st["houses"][c2]["pop"] = float(st["houses"][c2]["pop"]) * lerpf(1.0, k, 0.3)
		pop = lerpf(pop, cap_jobs, 0.3)
	st["pop"] = pop
	st["connected"] = connected
	st["happy"] = hsum / float(maxi(1, (st["houses"] as Dictionary).size()))
	var customers: float = minf(float(shops) * 12.0, pop)
	st["money"] = float(st["money"]) + pop * TAX + customers / 12.0 * SHOP_INCOME


static func step(st: Dictionary, dt: float) -> void:
	if st["won"] or st["over"]:
		return
	st["time"] = float(st["time"]) + dt
	st["tick"] = float(st["tick"]) + dt
	while float(st["tick"]) >= 1.0:
		st["tick"] = float(st["tick"]) - 1.0
		_tick(st)
	if int(st["pop"]) >= int(st["goal"]):
		st["won"] = true
	elif float(st["time"]) >= float(st["seconds"]):
		st["over"] = true


# ------------------------------------------------------------------ bot

## El bot planifica calles en cuadricula (cada 3 casillas desde el ayuntamiento) y nunca
## construye encima: asi siempre puede seguir alargando la ciudad.
static func is_street(st: Dictionary, c: Vector2i) -> bool:
	var hall: Vector2i = st["hall"]
	return posmod(c.x - hall.x, 3) == 0 or posmod(c.y - hall.y + 2, 3) == 0


## Huecos libres junto a la red de carreteras (fuera de las calles planificadas).
static func _spots(st: Dictionary, net: Dictionary) -> Array:
	var out: Array = []
	for y: int in int(st["h"]):
		for x: int in int(st["w"]):
			var c: Vector2i = Vector2i(x, y)
			var ch: String = at(st, c)
			if (ch == "." or ch == "^") and on_road(st, c, net) and not is_street(st, c):
				out.append(c)
	return out


static func _near(st: Dictionary, c: Vector2i, chs: String, r: int) -> int:
	var k: int = 0
	for dy: int in range(-r, r + 1):
		for dx: int in range(-r, r + 1):
			if chs.contains(at(st, c + Vector2i(dx, dy))):
				k += 1
	return k


## Una decision del bot: [que, casilla] o []. Mantiene trabajo para todos, pone parques junto
## a las casas, fabricas lejos de ellas y alarga carreteras cuando se acaban los huecos.
static func bot_pick(st: Dictionary) -> Array:
	var net: Dictionary = road_net(st)
	var spots: Array = _spots(st, net)
	var money: float = float(st["money"])
	var houses: int = (st["houses"] as Dictionary).size()
	var cap: float = 0.0
	for c: Variant in st["houses"]:
		cap += float(HOUSE_CAP[int(st["houses"][c]["lvl"])])
	var jobs: int = int(st["jobs"])
	if spots.size() < 3:
		## Alargar la carretera hacia donde haya mas solares libres.
		var best: Vector2i = Vector2i(-1, -1)
		var best_s: int = -1
		for c2: Variant in net:
			for d: Vector2i in N4:
				var n: Vector2i = (c2 as Vector2i) + d
				var ch: String = at(st, n)
				if (ch == "." or ch == "^") and is_street(st, n):
					var s: int = _near(st, n, ".^", 1) * 2 + _near(st, n, ".", 2) - (2 if ch == "^" else 0)
					if s > best_s:
						best_s = s
						best = n
		if best.x >= 0 and money >= float(BUILD["road"]["cost"]) + (CLEAR_COST if at(st, best) == "^" else 0):
			return ["road", best]
		return []
	var want: String = "house"
	if float(jobs) * 1.3 + 6.0 < cap * 0.95:
		want = "factory" if money >= 160.0 and jobs >= SHOP_JOBS * 2 else "shop"
	elif houses >= 3 and houses % 3 == 0 and _count(st, "P") < houses / 3:
		want = "park"
	var best_c: Vector2i = Vector2i(-1, -1)
	var best_v: float = -INF
	for c3: Vector2i in spots:
		var v: float = 0.0
		match want:
			"house":
				v = float(_near(st, c3, "P", 2)) * 2.0 - float(_near(st, c3, "F", 2)) * 4.0 + float(_near(st, c3, "H", 1)) * 0.5
			"shop":
				v = float(_near(st, c3, "H", 2)) - float(_near(st, c3, "S", 1))
			"factory":
				v = -float(_near(st, c3, "H", 2)) * 3.0 + float(_near(st, c3, "F", 1))
			"park":
				v = float(_near(st, c3, "H", 2)) * 2.0 - float(_near(st, c3, "P", 2)) * 2.0
		if at(st, c3) == "^":
			v -= 0.5
		if v > best_v:
			best_v = v
			best_c = c3
	if best_c.x < 0:
		return []
	if money < float(cost_at(st, want, best_c)):
		return []
	return [want, best_c]


static func _count(st: Dictionary, ch: String) -> int:
	var k: int = 0
	for row: Variant in st["grid"]:
		for v: Variant in row:
			if str(v) == ch:
				k += 1
	return k


static func bot_play(level: Dictionary) -> Dictionary:
	var st: Dictionary = new_state(level)
	var dt: float = 0.5
	var guard: int = 0
	while not st["won"] and not st["over"] and guard < 4000:
		guard += 1
		## Una persona construye algo cada ~1,5 s como mucho.
		if guard % 3 == 0:
			var m: Array = bot_pick(st)
			if not m.is_empty():
				build(st, str(m[0]), m[1])
		step(st, dt)
	return {"won": bool(st["won"]), "time": float(st["time"]), "pop": int(st["pop"])}


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var st: Dictionary = new_state(level)
	if int(st["w"]) < 6 or int(st["h"]) < 8 or int(st["w"]) > 12 or int(st["h"]) > 18:
		issues.append("city_size")
	if (st["hall"] as Vector2i).x < 0:
		issues.append("city_no_hall")
	var par: int = 0
	if issues.is_empty():
		var r: Dictionary = bot_play(level)
		if not bool(r["won"]):
			issues.append("city_too_hard")
		par = int(r["time"])
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": int(level.get("goal", 100)), "enemies": 0,
		"enemy_problems": [], "par": par}
