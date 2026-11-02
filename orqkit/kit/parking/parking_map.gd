extends RefCounted
## Atasco de aparcamiento (estilo Parking Jam / Car Escape): reglas, bot y analizador.
## 1 - Mapa (game.json -> levels[i].map): "." asfalto, "#" obstaculo (arbol, cono), y coches de
##     2 o 3 casillas: la MAYUSCULA es el morro y las minusculas de la misma letra el resto.
##     El coche mira hacia su morro: "aA" va a la derecha, "Aa" a la izquierda, y en vertical
##     igual (morro arriba = sube).
## 2 - Tocar un coche lo arranca hacia delante: si el camino hasta el borde esta libre, sale del
##     aparcamiento; si no, choca con lo primero que encuentra y vuelve a su sitio (un golpe).
## 3 - Se gana cuando salen todos. Con "lives" golpes se pierde.
## Analizador: letras validas (un morro por coche, cuerpo recto y pegado), y que exista un orden
## para sacar todos (sin ciclos de coches que se tapan unos a otros).

const DIRS: Dictionary = {"R": Vector2i(1, 0), "L": Vector2i(-1, 0), "D": Vector2i(0, 1), "U": Vector2i(0, -1)}


## Coches del mapa: {letra: {"cells": [Vector2i], "dir": Vector2i, "head": Vector2i}} o {"_error": motivo}.
static func parse(level: Dictionary) -> Dictionary:
	var rows: Array = level.get("map", [])
	var cells: Dictionary = {}
	var heads: Dictionary = {}
	for y: int in rows.size():
		var row: String = str(rows[y])
		for x: int in row.length():
			var ch: String = row[x]
			if ch == "." or ch == "#" or ch == " ":
				continue
			var k: String = ch.to_upper()
			if not cells.has(k):
				cells[k] = []
			(cells[k] as Array).append(Vector2i(x, y))
			if ch == k:
				if heads.has(k):
					return {"_error": "parking_heads"}
				heads[k] = Vector2i(x, y)
	var cars: Dictionary = {}
	for k: Variant in cells:
		var cs: Array = cells[k]
		if not heads.has(k) or cs.size() < 2 or cs.size() > 3:
			return {"_error": "parking_car"}
		var h: Vector2i = heads[k]
		var same_row: bool = true
		var same_col: bool = true
		for c: Vector2i in cs:
			same_row = same_row and c.y == h.y
			same_col = same_col and c.x == h.x
		if not same_row and not same_col:
			return {"_error": "parking_shape"}
		var lo: int = 99
		var hi: int = -1
		for c: Vector2i in cs:
			var v: int = c.x if same_row else c.y
			lo = mini(lo, v)
			hi = maxi(hi, v)
		if hi - lo + 1 != cs.size():
			return {"_error": "parking_shape"}
		var hv: int = h.x if same_row else h.y
		if hv != lo and hv != hi:
			return {"_error": "parking_shape"}
		var d: Vector2i
		if same_row:
			d = Vector2i(1, 0) if hv == hi else Vector2i(-1, 0)
		else:
			d = Vector2i(0, 1) if hv == hi else Vector2i(0, -1)
		cars[k] = {"cells": cs, "dir": d, "head": h}
	return cars


static func size_of(level: Dictionary) -> Vector2i:
	var rows: Array = level.get("map", [])
	var w: int = 0
	for r: Variant in rows:
		w = maxi(w, str(r).length())
	return Vector2i(w, rows.size())


static func walls(level: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var rows: Array = level.get("map", [])
	for y: int in rows.size():
		var row: String = str(rows[y])
		for x: int in row.length():
			if row[x] == "#":
				out[Vector2i(x, y)] = true
	return out


static func new_state(level: Dictionary) -> Dictionary:
	var cars: Dictionary = parse(level)
	var ok: bool = not cars.has("_error")
	return {"cars": cars if ok else {}, "gone": {}, "walls": walls(level), "size": size_of(level), "bumps": 0,
		"lives": int(level.get("lives", 3)), "moves": 0, "ok": ok}


static func _occupied(st: Dictionary) -> Dictionary:
	var occ: Dictionary = {}
	for k: Variant in st["cars"]:
		if not (st["gone"] as Dictionary).has(k):
			for c: Vector2i in st["cars"][k]["cells"]:
				occ[c] = k
	return occ


## Lo que hay delante del coche: {"free": true} si sale, o {"free": false, "stop": casillas que
## avanza antes de chocar, "hit": letra o "#"}.
static func probe(st: Dictionary, k: String) -> Dictionary:
	var car: Dictionary = st["cars"][k]
	var d: Vector2i = car["dir"]
	var p: Vector2i = car["head"] + d
	var occ: Dictionary = _occupied(st)
	var size: Vector2i = st["size"]
	var steps: int = 0
	while p.x >= 0 and p.y >= 0 and p.x < size.x and p.y < size.y:
		if (st["walls"] as Dictionary).has(p):
			return {"free": false, "stop": steps, "hit": "#"}
		if occ.has(p):
			return {"free": false, "stop": steps, "hit": str(occ[p])}
		steps += 1
		p += d
	return {"free": true, "stop": steps, "hit": ""}


## Toca un coche: true si sale; si choca, cuenta un golpe.
static func tap(st: Dictionary, k: String) -> bool:
	if not (st["cars"] as Dictionary).has(k) or (st["gone"] as Dictionary).has(k):
		return false
	st["moves"] = int(st["moves"]) + 1
	if bool(probe(st, k)["free"]):
		st["gone"][k] = true
		return true
	st["bumps"] = int(st["bumps"]) + 1
	return false


static func won(st: Dictionary) -> bool:
	return bool(st["ok"]) and (st["gone"] as Dictionary).size() == (st["cars"] as Dictionary).size()


static func lost(st: Dictionary) -> bool:
	return int(st["lives"]) > 0 and int(st["bumps"]) >= int(st["lives"])


## Coches que pueden salir ya.
static func free_cars(st: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var keys: Array = (st["cars"] as Dictionary).keys()
	keys.sort()
	for k: Variant in keys:
		if not (st["gone"] as Dictionary).has(k) and bool(probe(st, str(k))["free"]):
			out.append(str(k))
	return out


static func bot_pick(st: Dictionary) -> String:
	var fr: Array[String] = free_cars(st)
	return fr[0] if not fr.is_empty() else ""


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var size: Vector2i = size_of(level)
	if size.x < 3 or size.y < 3 or size.x > 8 or size.y > 10:
		issues.append("parking_size")
	var cars: Dictionary = parse(level)
	if cars.has("_error"):
		issues.append(str(cars["_error"]))
	elif cars.size() < 2 or cars.size() > 26:
		issues.append("parking_count")
	var par: int = 0
	var depth: int = 0
	if issues.is_empty():
		var st: Dictionary = new_state(level)
		var guard: int = 0
		while not won(st) and guard < 64:
			guard += 1
			var fr: Array[String] = free_cars(st)
			if fr.is_empty():
				issues.append("parking_deadlock")
				break
			## Por rondas: cuantas rondas hacen falta mide lo enredado que esta.
			for k: String in fr:
				tap(st, k)
			depth += 1
		par = (st["cars"] as Dictionary).size()
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": par, "enemies": 0, "enemy_problems": [],
		"par": par, "depth": depth}
