extends RefCounted
## Fusion con pedidos (tipo Gossip Harbor / Merge Mansion): reglas, bot y analizador.
## 1 - Tablero de 7x9. Los generadores (horno, tetera...) sacan un objeto de nivel 1 de su cadena
##     al tocarlos (gasta 1 de energia). Dos objetos iguales se fusionan en el siguiente.
## 2 - Los clientes piden objetos (cadena y nivel); entregarlos da monedas y avanza la historia.
##     Se gana al cumplir todos los pedidos del nivel.
## 3 - La energia se recarga con el tiempo (tambien con la app cerrada) y con un anuncio.
## 4 - Nivel: "orders": [{"who", "need": [[cadena, nivel], ...], "reward"}], "chains" (generadores del
##     tablero), "energy" (al empezar), "regen" (segundos por energia), "par" y "merge" (catalogo).

const CATALOG_PATH: String = "res://kit/mergeboard/merge_catalog.json"
const Rules = preload("res://kit/rules.gd")
const W: int = 7
const H: int = 9
const MAX_ENERGY: int = 100
## Lo que tarda una persona en cada gesto (tocar, arrastrar).
const ACT_TIME: float = 0.7

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
		_data = parsed if parsed is Dictionary else {"default": {"chains": {}}, "presets": {}}
	return _data


static func catalog(level: Dictionary) -> Dictionary:
	var c: Dictionary = (data()["default"] as Dictionary).duplicate(true)
	var extra: Variant = level.get("merge", {})
	if extra is Dictionary:
		var add: Variant = (extra as Dictionary).get("chains", {})
		if add is Dictionary:
			for k: Variant in add:
				if add[k] is Dictionary and (c["chains"] as Dictionary).has(str(k)):
					var m: Dictionary = (c["chains"][str(k)] as Dictionary).duplicate(true)
					m.merge(add[k] as Dictionary, true)
					c["chains"][str(k)] = m
		for k2: String in ["place", "people"]:
			if (extra as Dictionary).has(k2):
				c[k2] = extra[k2]
	return c


static func max_level(st: Dictionary, chain: String) -> int:
	return ((st["cat"]["chains"] as Dictionary).get(chain, {}).get("items", []) as Array).size()


static func item_name(st: Dictionary, chain: String, lv: int) -> String:
	var items: Array = (st["cat"]["chains"] as Dictionary).get(chain, {}).get("items", [])
	return str(items[clampi(lv - 1, 0, items.size() - 1)]) if not items.is_empty() else chain


static func new_state(level: Dictionary) -> Dictionary:
	var cat: Dictionary = catalog(level)
	var grid: Dictionary = {}
	var chains: Array = []
	for ch: Variant in level.get("chains", (cat["chains"] as Dictionary).keys()):
		if (cat["chains"] as Dictionary).has(str(ch)):
			chains.append(str(ch))
	## Generadores en la fila de abajo, de izquierda a derecha.
	for i: int in chains.size():
		grid[Vector2i(i, H - 1)] = {"gen": chains[i]}
	## Un par listo para fusionar de cada cadena (13 nov: el tablero empezaba vacio y la primera foto
	## era un damero sin nada; en los juegos de este tipo se empieza con objetos a mano).
	var spots: Array[Vector2i] = [Vector2i(1, 2), Vector2i(2, 2), Vector2i(4, 3), Vector2i(5, 3), Vector2i(1, 5), Vector2i(2, 5), Vector2i(4, 6), Vector2i(5, 6)]
	for i2: int in mini(chains.size() * 2, spots.size()):
		grid[spots[i2]] = {"c": chains[i2 / 2], "l": 1}
	var orders: Array = []
	for o: Variant in level.get("orders", []):
		var need: Array = []
		for n: Variant in (o as Dictionary).get("need", []):
			if (n as Array).size() >= 2 and chains.has(str(n[0])):
				need.append([str(n[0]), clampi(int(n[1]), 1, 8)])
		if not need.is_empty():
			orders.append({"who": str(o.get("who", "")), "need": need, "reward": int(o.get("reward", 10)), "done": false})
	var st: Dictionary = {"cat": cat, "grid": grid, "chains": chains, "orders": orders, "energy": clampi(int(level.get("energy", 60)), 0, MAX_ENERGY * 3),
		"regen": maxf(2.0, float(level.get("regen", 20.0))), "regen_t": 0.0, "t": 0.0, "coins": 0, "won": false, "taps": 0, "merges": 0, "rng": RandomNumberGenerator.new()}
	(st["rng"] as RandomNumberGenerator).seed = int(level.get("seed", 1))
	st["rules"] = Rules.load_rules(level)
	Rules.hook(st, "on_start")
	return st


static func free_cell(st: Dictionary, near: Vector2i) -> Vector2i:
	var best: Vector2i = Vector2i(-1, -1)
	var bd: int = 9999
	for y: int in H:
		for x: int in W:
			var c: Vector2i = Vector2i(x, y)
			if not (st["grid"] as Dictionary).has(c):
				var d: int = absi(c.x - near.x) + absi(c.y - near.y)
				if d < bd:
					bd = d
					best = c
	return best


## Tocar un generador: un objeto de nivel 1 en la casilla libre mas cercana.
static func tap(st: Dictionary, cell: Vector2i) -> Vector2i:
	var g: Variant = (st["grid"] as Dictionary).get(cell, null)
	if not (g is Dictionary) or not (g as Dictionary).has("gen") or int(st["energy"]) <= 0:
		return Vector2i(-1, -1)
	var f: Vector2i = free_cell(st, cell)
	if f.x < 0:
		return f
	st["grid"][f] = {"c": str(g["gen"]), "l": 1}
	st["energy"] = int(st["energy"]) - 1
	st["taps"] = int(st["taps"]) + 1
	Rules.hook(st, "on_tap", [cell, f])
	return f


## Arrastrar a -> b: si son iguales se fusionan en b; si b esta libre, se mueve. Devuelve lo hecho.
static func drag(st: Dictionary, a: Vector2i, b: Vector2i) -> String:
	var grid: Dictionary = st["grid"]
	if a == b or not grid.has(a) or (grid[a] as Dictionary).has("gen"):
		return ""
	if b.x < 0 or b.y < 0 or b.x >= W or b.y >= H:
		return ""
	if not grid.has(b):
		grid[b] = grid[a]
		grid.erase(a)
		return "move"
	var ia: Dictionary = grid[a]
	var ib: Dictionary = grid[b]
	if ib.has("gen") or str(ia["c"]) != str(ib["c"]) or int(ia["l"]) != int(ib["l"]) or int(ia["l"]) >= max_level(st, str(ia["c"])):
		return ""
	grid.erase(a)
	grid[b] = {"c": str(ib["c"]), "l": int(ib["l"]) + 1}
	st["merges"] = int(st["merges"]) + 1
	Rules.hook(st, "on_merge", [b])
	return "merge"


## Celdas que cumplirian un pedido ([] si falta algo).
static func order_cells(st: Dictionary, i: int) -> Array:
	var used: Array = []
	for n: Variant in st["orders"][i]["need"]:
		var found: bool = false
		for c: Variant in st["grid"]:
			var it: Dictionary = st["grid"][c]
			if not it.has("gen") and not used.has(c) and str(it["c"]) == str(n[0]) and int(it["l"]) == int(n[1]):
				used.append(c)
				found = true
				break
		if not found:
			return []
	return used


static func deliver(st: Dictionary, i: int) -> bool:
	if i < 0 or i >= (st["orders"] as Array).size() or bool(st["orders"][i]["done"]):
		return false
	var cells: Array = order_cells(st, i)
	if cells.is_empty():
		return false
	for c: Variant in cells:
		(st["grid"] as Dictionary).erase(c)
	st["orders"][i]["done"] = true
	st["coins"] = int(st["coins"]) + int(st["orders"][i]["reward"])
	Rules.hook(st, "on_deliver", [i])
	var all_done: bool = true
	for o: Variant in st["orders"]:
		all_done = all_done and bool(o["done"])
	st["won"] = all_done
	return true


## Pedidos a la vista: los 3 primeros sin hacer (como en estos juegos, van saliendo).
static func open_orders(st: Dictionary) -> Array:
	var out: Array = []
	for i: int in (st["orders"] as Array).size():
		if not bool(st["orders"][i]["done"]):
			out.append(i)
			if out.size() >= 3:
				break
	return out


static func tick(st: Dictionary, dt: float) -> void:
	st["t"] = float(st["t"]) + dt
	Rules.hook(st, "on_step", [dt])
	if int(st["energy"]) >= MAX_ENERGY:
		st["regen_t"] = 0.0
		return
	st["regen_t"] = float(st["regen_t"]) + dt
	while float(st["regen_t"]) >= float(st["regen"]) and int(st["energy"]) < MAX_ENERGY:
		st["regen_t"] = float(st["regen_t"]) - float(st["regen"])
		st["energy"] = int(st["energy"]) + 1


## Energia que hace falta para todos los pedidos (un objeto de nivel L sale de 2^(L-1) toques).
static func energy_needed(level: Dictionary) -> int:
	var e: int = 0
	for o: Variant in level.get("orders", []):
		for n: Variant in (o as Dictionary).get("need", []):
			e += 1 << (clampi(int(n[1]), 1, 8) - 1)
	return e


# ------------------------------------------------------------------ bot y analizador

## Lo que falta por pedidos a la vista: {cadena: {nivel: cuantos}}.
static func wanted(st: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for i: Variant in open_orders(st):
		for n: Variant in st["orders"][i]["need"]:
			var ch: String = str(n[0])
			if not out.has(ch):
				out[ch] = {}
			out[ch][int(n[1])] = int(out[ch].get(int(n[1]), 0)) + 1
	return out


## Un gesto del bot: entregar, fusionar lo que sirve o tocar el generador que hace falta.
## Devuelve que hizo ("" si no pudo hacer nada).
static func bot_act(st: Dictionary) -> String:
	for i: Variant in open_orders(st):
		if deliver(st, int(i)):
			return "deliver"
	var want: Dictionary = wanted(st)
	## Fusionar: pares iguales por debajo del nivel mas alto que se pide de su cadena (de abajo arriba).
	var by: Dictionary = {}
	for c: Variant in st["grid"]:
		var it: Dictionary = st["grid"][c]
		if it.has("gen"):
			continue
		var key: String = "%s:%d" % [str(it["c"]), int(it["l"])]
		if not by.has(key):
			by[key] = []
		(by[key] as Array).append(c)
	var best_key: String = ""
	var best_l: int = 99
	for key2: Variant in by:
		var parts: PackedStringArray = str(key2).split(":")
		var ch: String = parts[0]
		var l: int = int(parts[1])
		var top: int = 0
		for lv: Variant in (want.get(ch, {}) as Dictionary):
			top = maxi(top, int(lv))
		## Se guardan los que ya sirven tal cual para un pedido.
		var keep: int = int((want.get(ch, {}) as Dictionary).get(l, 0))
		if (by[key2] as Array).size() - keep >= 2 and l < top and l < best_l:
			best_l = l
			best_key = str(key2)
	if best_key != "":
		var cells: Array = by[best_key]
		if drag(st, cells[0], cells[1]) == "merge":
			return "merge"
	## Tocar: la cadena a la que mas le falta (lo pedido menos lo que ya hay en el tablero, contado
	## en objetos de nivel 1); si a ninguna le falta, la que mas pide.
	var best_ch: String = ""
	var need_e: int = -999999
	for ch2: Variant in want:
		var e: int = 0
		var top2: int = 0
		for lv2: Variant in want[ch2]:
			e += (1 << (int(lv2) - 1)) * int(want[ch2][lv2])
			top2 = maxi(top2, int(lv2))
		var have: int = 0
		for c4: Variant in st["grid"]:
			var it4: Dictionary = st["grid"][c4]
			if not it4.has("gen") and str(it4["c"]) == str(ch2) and int(it4["l"]) <= top2:
				have += 1 << (int(it4["l"]) - 1)
		if e - have > need_e:
			need_e = e - have
			best_ch = str(ch2)
	if best_ch != "" and int(st["energy"]) > 0:
		for c2: Variant in st["grid"]:
			if (st["grid"][c2] as Dictionary).get("gen", "") == best_ch:
				if tap(st, c2).x >= 0:
					return "tap"
	## Tablero lleno: se tira lo de menos nivel que no se pide.
	if free_cell(st, Vector2i(0, 0)).x < 0:
		var low: Vector2i = Vector2i(-1, -1)
		var ll: int = 99
		for c3: Variant in st["grid"]:
			var it3: Dictionary = st["grid"][c3]
			if not it3.has("gen") and int(it3["l"]) < ll and not (want.get(str(it3["c"]), {}) as Dictionary).has(int(it3["l"])):
				ll = int(it3["l"])
				low = c3
		if low.x >= 0:
			(st["grid"] as Dictionary).erase(low)
			return "trash"
	return ""


static func bot_play(level: Dictionary, limit: float = 1800.0) -> Dictionary:
	var st: Dictionary = new_state(level)
	while float(st["t"]) < limit and not bool(st["won"]):
		var did: String = bot_act(st)
		tick(st, ACT_TIME if did != "" else 1.0)
	return {"won": bool(st["won"]), "time": float(st["t"]), "taps": int(st["taps"]), "merges": int(st["merges"])}


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var st: Dictionary = new_state(level)
	if (st["chains"] as Array).is_empty() or (st["chains"] as Array).size() > W:
		issues.append("merge_chains")
	if (st["orders"] as Array).is_empty():
		issues.append("merge_no_orders")
	var par: float = maxf(60.0, float(level.get("par", 300.0)))
	var r: Dictionary = {"time": 0.0}
	if issues.is_empty():
		r = bot_play(level, par * 1.6)
		if not bool(r["won"]):
			issues.append("merge_too_slow")
		elif float(r["time"]) < 20.0:
			issues.append("merge_too_easy")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": (st["orders"] as Array).size(), "enemies": 0, "enemy_problems": [], "time": r.get("time", 0.0)}
