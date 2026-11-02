extends RefCounted
## Flechas (tipo Arrows / Tap Away): un tablero lleno de flechas rectas; toca una y sale volando en
## la direccion de su punta si no hay otra flecha en el camino hasta el borde. Si la hay, choca y
## cuesta una vida. Se gana vaciando el tablero.
## Nivel: "w", "h" y "arrows": [{"x", "y" (casilla de la punta), "d": "u"|"d"|"l"|"r", "n": largo}];
## el cuerpo ocupa n casillas hacia atras desde la punta. "lives": vidas (fallos permitidos).

const Rules = preload("res://kit/rules.gd")
const DIRS: Dictionary = {"u": Vector2i(0, -1), "d": Vector2i(0, 1), "l": Vector2i(-1, 0), "r": Vector2i(1, 0)}


static func cells_of(a: Dictionary) -> Array:
	var out: Array = []
	var dv: Vector2i = DIRS.get(str(a.get("d", "u")), Vector2i(0, -1))
	var tip: Vector2i = Vector2i(int(a.get("x", 0)), int(a.get("y", 0)))
	for k: int in maxi(1, int(a.get("n", 1))):
		out.append(tip - dv * k)
	return out


static func new_state(level: Dictionary) -> Dictionary:
	var w: int = clampi(int(level.get("w", 6)), 2, 16)
	var h: int = clampi(int(level.get("h", 8)), 2, 20)
	var arrows: Array = []
	for a: Variant in level.get("arrows", []):
		arrows.append({"x": int(a.get("x", 0)), "y": int(a.get("y", 0)), "d": str(a.get("d", "u")), "n": maxi(1, int(a.get("n", 1))), "out": false})
	var st: Dictionary = {"w": w, "h": h, "arrows": arrows, "left": arrows.size(), "lives": clampi(int(level.get("lives", 3)), 1, 9),
		"mistakes": 0, "moves": 0, "won": arrows.is_empty(), "lost": false, "rng": RandomNumberGenerator.new()}
	st["rules"] = Rules.load_rules(level)
	Rules.hook(st, "on_start")
	return st


## Que flecha (indice) ocupa cada casilla: {Vector2i: indice}, sin las que ya salieron.
static func occupancy(st: Dictionary) -> Dictionary:
	var occ: Dictionary = {}
	for i: int in (st["arrows"] as Array).size():
		var a: Dictionary = st["arrows"][i]
		if bool(a["out"]):
			continue
		for c: Variant in cells_of(a):
			occ[c] = i
	return occ


## Primera flecha que se cruza en el camino de la flecha i hasta el borde (-1 si el camino esta libre).
static func blocker(st: Dictionary, i: int, occ: Dictionary = {}) -> int:
	if occ.is_empty():
		occ = occupancy(st)
	var a: Dictionary = st["arrows"][i]
	var dv: Vector2i = DIRS[str(a["d"])]
	var p: Vector2i = Vector2i(int(a["x"]), int(a["y"])) + dv
	while p.x >= 0 and p.y >= 0 and p.x < int(st["w"]) and p.y < int(st["h"]):
		if occ.has(p) and int(occ[p]) != i:
			return int(occ[p])
		p += dv
	return -1


## Tocar la flecha i: {"ok": true} si sale, {"ok": false, "by": la que estorba} si choca.
static func tap(st: Dictionary, i: int) -> Dictionary:
	if bool(st["won"]) or bool(st["lost"]) or i < 0 or i >= (st["arrows"] as Array).size() or bool(st["arrows"][i]["out"]):
		return {}
	var b: int = blocker(st, i)
	var out: Dictionary = {"ok": b < 0, "by": b, "i": i}
	st["moves"] = int(st["moves"]) + 1
	if b < 0:
		st["arrows"][i]["out"] = true
		st["left"] = int(st["left"]) - 1
		if int(st["left"]) <= 0:
			st["won"] = true
	else:
		st["mistakes"] = int(st["mistakes"]) + 1
		if int(st["mistakes"]) >= int(st["lives"]):
			st["lost"] = true
	Rules.hook(st, "on_tap", [out])
	return out


static func arrow_at(st: Dictionary, c: Vector2i) -> int:
	return int(occupancy(st).get(c, -1))


## Bot: la primera flecha con el camino libre (-1 si no queda ninguna).
static func bot_move(st: Dictionary) -> int:
	var occ: Dictionary = occupancy(st)
	for i: int in (st["arrows"] as Array).size():
		if not bool(st["arrows"][i]["out"]) and blocker(st, i, occ) < 0:
			return i
	return -1


## Analizador: flechas dentro y sin pisarse, bastantes, y que se pueda vaciar (quitar las libres una a
## una siempre funciona: quitar una nunca bloquea a otra). Sin flechas libres al empezar no hay juego,
## y si casi todas lo estan es un paseo.
static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var st: Dictionary = new_state(level)
	var w: int = int(st["w"])
	var h: int = int(st["h"])
	var seen: Dictionary = {}
	for a: Variant in st["arrows"]:
		if not DIRS.has(str(a["d"])):
			issues.append("arrow_bad_dir")
		for c: Variant in cells_of(a):
			var cc: Vector2i = c
			if cc.x < 0 or cc.y < 0 or cc.x >= w or cc.y >= h:
				issues.append("arrow_outside")
			elif seen.has(cc):
				issues.append("arrow_overlap")
			seen[cc] = true
	var n: int = (st["arrows"] as Array).size()
	if n < 4:
		issues.append("arrow_few")
	if issues.is_empty():
		var occ: Dictionary = occupancy(st)
		var free0: int = 0
		for i: int in n:
			free0 += 1 if blocker(st, i, occ) < 0 else 0
		if free0 * 2 > n and n > 6:
			issues.append("arrow_too_easy")
		var guard: int = 0
		while not bool(st["won"]) and guard <= n:
			guard += 1
			var m: int = bot_move(st)
			if m < 0:
				break
			tap(st, m)
		if not bool(st["won"]):
			issues.append("arrow_stuck")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": n, "enemies": 0, "enemy_problems": []}
