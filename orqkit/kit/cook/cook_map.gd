extends RefCounted
## Cocina (gestion de tiempo, estilo Cooking Fever): reglas, simulacion pura, bot y analizador.
## 1 - Llegan clientes (hasta 4 a la vez) y cada uno pide un plato. Su paciencia baja; si se acaba,
##     se va sin pagar (y pierdes una vida de la racha de "sin fallos").
## 2 - Platos: se montan tocando ingredientes en orden sobre la bandeja. Algunos ingredientes se
##     cocinan antes (carne en la plancha, patatas en la freidora) y se queman si se dejan mucho.
## 3 - Bandeja: un plato a medio montar; tocar al cliente que lo pidio lo sirve (cobra y propina
##     segun la paciencia que le quedaba). La papelera vacia la bandeja.
## 4 - Se gana al llegar a la meta de monedas antes de que acabe el dia (segundos del nivel).
## Mapa (game.json -> levels[i].map): los platos del menu, uno por fila (ver RECIPES).
## Parametros: "goal" (monedas), "seconds" (duracion del dia), "customers" (clientes del dia),
## "patience" (segundos de paciencia), "seed" (orden de pedidos) y "par" (monedas para 3 estrellas).

const RECIPES: Dictionary = {
	"hamburguesa": {"steps": ["pan", "carne", "lechuga"], "price": 12},
	"hamburguesa_queso": {"steps": ["pan", "carne", "queso", "lechuga"], "price": 16},
	"patatas": {"steps": ["patatas"], "price": 6},
	"perrito": {"steps": ["pan_largo", "salchicha", "ketchup"], "price": 10},
	"refresco": {"steps": ["vaso"], "price": 4},
	"tarta": {"steps": ["tarta"], "price": 9},
}
## Ingredientes que se cocinan: segundos hasta estar hechos y hasta quemarse.
const COOK: Dictionary = {
	"carne": {"done": 5.0, "burn": 12.0, "slots": 3},
	"salchicha": {"done": 4.0, "burn": 11.0, "slots": 3},
	"patatas": {"done": 6.0, "burn": 14.0, "slots": 2},
}
const MAX_SEATS: int = 4
const TRAY: int = 2


static func new_state(level: Dictionary) -> Dictionary:
	var menu: Array = []
	for r: Variant in level.get("map", []):
		var k: String = str(r).strip_edges()
		if RECIPES.has(k):
			menu.append(k)
	var st: Dictionary = {"menu": menu, "coins": 0, "time": 0.0, "seconds": float(level.get("seconds", 120)),
		"goal": int(level.get("goal", 100)), "left": int(level.get("customers", 20)), "patience": float(level.get("patience", 25)),
		"seed": int(level.get("seed", 1)), "n": 0, "next_t": 0.4, "seats": [], "grill": {}, "trays": [], "served": 0, "lost": 0,
		"burnt": 0, "won": false, "over": false}
	for k: Variant in COOK:
		var slots: Array = []
		for s: int in int(COOK[k]["slots"]):
			slots.append({"t": -1.0})
		st["grill"][k] = slots
	for t: int in TRAY:
		(st["trays"] as Array).append([])
	for s: int in MAX_SEATS:
		(st["seats"] as Array).append({})
	return st


static func _rng(st: Dictionary) -> RandomNumberGenerator:
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.seed = int(st["seed"]) * 7919 + int(st["n"]) * 104729
	return r


static func step(st: Dictionary, dt: float) -> void:
	if st["won"] or st["over"]:
		return
	st["time"] = float(st["time"]) + dt
	## Llegada de clientes.
	st["next_t"] = float(st["next_t"]) - dt
	if float(st["next_t"]) <= 0.0 and int(st["left"]) > 0:
		var seats: Array = st["seats"]
		for i: int in seats.size():
			if (seats[i] as Dictionary).is_empty():
				var r: RandomNumberGenerator = _rng(st)
				st["n"] = int(st["n"]) + 1
				var menu: Array = st["menu"]
				var dish: String = str(menu[r.randi_range(0, menu.size() - 1)])
				var order: Array = [dish]
				## A veces piden tambien bebida o patatas.
				if menu.size() > 1 and r.randf() < 0.35:
					var extra: String = str(menu[r.randi_range(0, menu.size() - 1)])
					if extra != dish:
						order.append(extra)
				seats[i] = {"order": order, "got": [], "patience": float(st["patience"]) + 4.0 * float(order.size() - 1), "max": float(st["patience"]) + 4.0 * float(order.size() - 1)}
				st["left"] = int(st["left"]) - 1
				break
		st["next_t"] = 1.2 + _rng(st).randf() * 2.2
	for s: Dictionary in st["seats"]:
		if s.is_empty():
			continue
		s["patience"] = float(s["patience"]) - dt
	for i: int in (st["seats"] as Array).size():
		var s2: Dictionary = st["seats"][i]
		if not s2.is_empty() and float(s2["patience"]) <= 0.0:
			st["seats"][i] = {}
			st["lost"] = int(st["lost"]) + 1
	for k: Variant in st["grill"]:
		for sl: Dictionary in st["grill"][k]:
			if float(sl["t"]) >= 0.0:
				sl["t"] = float(sl["t"]) + dt
	if int(st["coins"]) >= int(st["goal"]):
		st["won"] = true
	elif float(st["time"]) >= float(st["seconds"]) or (int(st["left"]) <= 0 and _empty(st)):
		st["over"] = true


static func _empty(st: Dictionary) -> bool:
	for s: Dictionary in st["seats"]:
		if not s.is_empty():
			return false
	return true


## Pone a cocinar un ingrediente en un hueco libre.
static func start_cook(st: Dictionary, item: String) -> bool:
	if not COOK.has(item):
		return false
	for sl: Dictionary in st["grill"][item]:
		if float(sl["t"]) < 0.0:
			sl["t"] = 0.0
			return true
	return false


static func cook_state(item: String, t: float) -> String:
	if t < 0.0:
		return "empty"
	if t < float(COOK[item]["done"]):
		return "raw"
	if t < float(COOK[item]["burn"]):
		return "done"
	return "burnt"


## Tira a la basura lo quemado de un hueco.
static func trash_slot(st: Dictionary, item: String, i: int) -> void:
	var sl: Dictionary = st["grill"][item][i]
	if cook_state(item, float(sl["t"])) == "burnt":
		st["burnt"] = int(st["burnt"]) + 1
	sl["t"] = -1.0


## Que plato se esta montando en una bandeja (o "" si no encaja con ninguno del menu).
static func tray_dish(st: Dictionary, tray: Array) -> String:
	for d: Variant in st["menu"]:
		if (RECIPES[d]["steps"] as Array) == tray:
			return str(d)
	return ""


static func _prefix_ok(st: Dictionary, tray: Array) -> bool:
	for d: Variant in st["menu"]:
		var steps: Array = RECIPES[d]["steps"]
		if tray.size() <= steps.size() and steps.slice(0, tray.size()) == tray:
			return true
	return false


## Anade un ingrediente a la bandeja (los cocinados se cogen hechos de la plancha).
static func add(st: Dictionary, ti: int, item: String) -> bool:
	if ti < 0 or ti >= TRAY:
		return false
	var tray: Array = st["trays"][ti]
	var next: Array = tray.duplicate()
	next.append(item)
	if not _prefix_ok(st, next):
		return false
	if COOK.has(item):
		var found: int = -1
		var slots: Array = st["grill"][item]
		for i: int in slots.size():
			if cook_state(item, float(slots[i]["t"])) == "done":
				found = i
				break
		if found < 0:
			return false
		slots[found]["t"] = -1.0
	tray.append(item)
	return true


static func clear_tray(st: Dictionary, ti: int) -> void:
	st["trays"][ti] = []


## Sirve la bandeja al cliente del asiento si pidio ese plato.
static func serve(st: Dictionary, ti: int, seat: int) -> bool:
	var s: Dictionary = st["seats"][seat]
	if s.is_empty():
		return false
	var dish: String = tray_dish(st, st["trays"][ti])
	if dish == "":
		return false
	var pending: Array = (s["order"] as Array).duplicate()
	for g: Variant in s["got"]:
		pending.erase(g)
	if not pending.has(dish):
		return false
	(s["got"] as Array).append(dish)
	st["trays"][ti] = []
	if (s["got"] as Array).size() >= (s["order"] as Array).size():
		var price: int = 0
		for d: Variant in s["order"]:
			price += int(RECIPES[d]["price"])
		var tip: int = int(round(float(price) * 0.5 * float(s["patience"]) / float(s["max"])))
		st["coins"] = int(st["coins"]) + price + tip
		st["served"] = int(st["served"]) + 1
		st["seats"][seat] = {}
	return true


# ------------------------------------------------------------------ bot

## Un paso del bot: mantener la plancha llena de lo que hace falta, montar el plato del cliente
## con menos paciencia y servirlo. Devuelve true si hizo algo.
static func bot_act(st: Dictionary) -> bool:
	## 1 - Quitar lo quemado.
	for k: Variant in st["grill"]:
		var slots: Array = st["grill"][k]
		for i: int in slots.size():
			if cook_state(str(k), float(slots[i]["t"])) == "burnt":
				trash_slot(st, str(k), i)
				return true
	## 2 - Servir lo que este listo en alguna bandeja.
	for ti: int in TRAY:
		var dish: String = tray_dish(st, st["trays"][ti])
		if dish == "":
			continue
		var best: int = -1
		var bp: float = INF
		for si: int in (st["seats"] as Array).size():
			var s: Dictionary = st["seats"][si]
			if s.is_empty():
				continue
			var pending: Array = (s["order"] as Array).duplicate()
			for g: Variant in s["got"]:
				pending.erase(g)
			if pending.has(dish) and float(s["patience"]) < bp:
				bp = float(s["patience"])
				best = si
		if best >= 0:
			return serve(st, ti, best)
		clear_tray(st, ti)
		return true
	## 3 - Lo que hace falta: platos pendientes por orden de paciencia.
	var need: Array = []
	var seats: Array = (st["seats"] as Array).duplicate()
	seats.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("patience", 999.0)) < float(b.get("patience", 999.0)))
	for s: Dictionary in seats:
		if s.is_empty():
			continue
		var pending: Array = (s["order"] as Array).duplicate()
		for g: Variant in s["got"]:
			pending.erase(g)
		need.append_array(pending)
	## Plancha: que haya hechos o haciendose tantos como hagan falta.
	var want: Dictionary = {}
	for d: Variant in need:
		for ing: Variant in RECIPES[d]["steps"]:
			if COOK.has(ing):
				want[ing] = int(want.get(ing, 0)) + 1
	for k: Variant in want:
		var have: int = 0
		for sl: Dictionary in st["grill"][k]:
			if float(sl["t"]) >= 0.0:
				have += 1
		if have < int(want[k]) and start_cook(st, str(k)):
			return true
	## 4 - Montar el plato mas urgente en una bandeja vacia o a medias.
	for d: Variant in need:
		var steps: Array = RECIPES[d]["steps"]
		for ti: int in TRAY:
			var tray: Array = st["trays"][ti]
			if tray.size() < steps.size() and steps.slice(0, tray.size()) == tray:
				if add(st, ti, str(steps[tray.size()])):
					return true
				break
	return false


static func bot_play(level: Dictionary) -> Dictionary:
	var st: Dictionary = new_state(level)
	var dt: float = 0.25
	var cd: float = 0.0
	while not st["won"] and not st["over"]:
		cd -= dt
		if cd <= 0.0 and bot_act(st):
			## Un humano rapido: un toque cada ~0,35 s.
			cd = 0.35
		step(st, dt)
	return {"won": bool(st["won"]), "coins": int(st["coins"]), "time": float(st["time"]), "lost": int(st["lost"])}


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var menu: Array = level.get("map", [])
	if menu.is_empty() or menu.size() > 6:
		issues.append("cook_menu")
	for d: Variant in menu:
		if not RECIPES.has(str(d).strip_edges()):
			issues.append("cook_dish")
			break
	var par: int = 0
	if issues.is_empty():
		var r: Dictionary = bot_play(level)
		if not bool(r["won"]):
			issues.append("cook_too_hard")
		par = int(r["time"])
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": int(level.get("goal", 0)), "enemies": 0,
		"enemy_problems": [], "par": par}
