extends RefCounted
## Bombas (tipo Bomberman): laberinto de bloques fijos "#" y cajas "+" que se rompen. Pones bombas
## que explotan en cruz; las llamas rompen la primera caja, matan monstruos (y a ti) y hacen
## explotar otras bombas. La salida esta escondida bajo una caja: cuando no quedan monstruos y
## la has destapado, pisarla gana. Todo va por ticks (10 por segundo) para que el bot y la escena
## jueguen igual.
## Mapa ("map"): "#" fijo, "+" caja, "." suelo, "P" salida del heroe, monstruos "e" globo (va a su
## aire), "c" perseguidor (te sigue si estas cerca), "f" rapido; cajas con premio: "X" salida,
## "B" bomba de mas, "R" mas alcance, "S" mas velocidad.
## Nivel: "bombs" (bombas a la vez), "range" (alcance), "lives" (vidas), "par" (segundos para 3 estrellas).

const Rules = preload("res://kit/rules.gd")
const TPS: int = 10
const FUSE: int = 22
const FLAME: int = 6
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
## Ticks entre pasos de cada monstruo.
const ENEMY_CD: Dictionary = {"e": 6, "c": 6, "f": 4}
## Ticks sin que te hagan dano al volver a salir tras perder una vida.
const SHIELD: int = 30


static func new_state(level: Dictionary) -> Dictionary:
	var rows: Array = []
	var enemies: Array = []
	var hidden: Dictionary = {}
	var start: Vector2i = Vector2i(1, 1)
	var y: int = 0
	for r: Variant in level.get("map", []):
		var row: String = str(r)
		if row.begins_with("#") and row.length() > 1 and row.substr(1).is_valid_int():
			continue
		var clean: String = ""
		for x: int in row.length():
			var ch: String = row[x]
			var p: Vector2i = Vector2i(x, y)
			if ch == "P":
				start = p
				ch = "."
			elif ENEMY_CD.has(ch):
				enemies.append({"k": ch, "p": p, "from": p, "dir": DIRS[(x + y) % 4], "cd": int(ENEMY_CD[ch]), "alive": true})
				ch = "."
			elif ["X", "B", "R", "S"].has(ch):
				hidden[p] = ch
				ch = "+"
			clean += ch
		rows.append(clean)
		y += 1
	var st: Dictionary = {"map": rows, "w": (rows[0] as String).length() if not rows.is_empty() else 0, "h": rows.size(),
		"p": start, "start": start, "from": start, "lives": int(level.get("lives", 3)), "deaths": 0, "shield": 0, "move_cd": 0, "speed": 3, "bombs": [], "flames": {}, "enemies": enemies, "hidden": hidden,
		"items": {}, "exit": Vector2i(-1, -1), "max_bombs": int(level.get("bombs", 1)), "range": int(level.get("range", 2)),
		"tick": 0, "won": false, "lost": false, "log": [], "rng": int(level.get("seed", 7)) * 7919 + 13, "kills": 0, "crates": 0}
	st["rules"] = Rules.load_rules(level)
	Rules.hook(st, "on_start")
	return st


static func cell(st: Dictionary, p: Vector2i) -> String:
	if p.x < 0 or p.y < 0 or p.x >= int(st["w"]) or p.y >= int(st["h"]):
		return "#"
	return (st["map"][p.y] as String)[p.x]


static func _put_cell(st: Dictionary, p: Vector2i, ch: String) -> void:
	var row: String = st["map"][p.y]
	st["map"][p.y] = row.substr(0, p.x) + ch + row.substr(p.x + 1)


static func bomb_at(st: Dictionary, p: Vector2i) -> Dictionary:
	for b: Variant in st["bombs"]:
		if (b as Dictionary)["p"] == p:
			return b
	return {}


static func open_cell(st: Dictionary, p: Vector2i) -> bool:
	return cell(st, p) == "." and bomb_at(st, p).is_empty()


static func enemies_left(st: Dictionary) -> int:
	var n: int = 0
	for e: Variant in st["enemies"]:
		if bool(e["alive"]):
			n += 1
	return n


static func _rand(st: Dictionary, n: int) -> int:
	st["rng"] = (int(st["rng"]) * 1103515245 + 12345) % 2147483648
	return int(st["rng"]) % maxi(1, n)


## Un tick: el heroe intenta ir hacia dir y, si drop, pone bomba donde esta.
static func tick(st: Dictionary, dir: Vector2i, drop: bool) -> void:
	if bool(st["won"]) or bool(st["lost"]):
		return
	st["tick"] = int(st["tick"]) + 1
	if int(st["shield"]) > 0:
		st["shield"] = int(st["shield"]) - 1
	var p: Vector2i = st["p"]
	if drop and (st["bombs"] as Array).size() < int(st["max_bombs"]) and bomb_at(st, p).is_empty():
		(st["bombs"] as Array).append({"p": p, "t": FUSE, "r": int(st["range"])})
		(st["log"] as Array).append({"k": "bomb", "at": p})
	st["from"] = p
	if int(st["move_cd"]) > 0:
		st["move_cd"] = int(st["move_cd"]) - 1
	elif dir != Vector2i.ZERO:
		var q: Vector2i = p + dir
		if open_cell(st, q):
			st["p"] = q
			st["move_cd"] = int(st["speed"]) - 1
			_pick(st)
	## Bombas y llamas.
	for b: Variant in st["bombs"]:
		(b as Dictionary)["t"] = int(b["t"]) - 1
	var boom: bool = true
	while boom:
		boom = false
		for b: Variant in (st["bombs"] as Array).duplicate():
			if int(b["t"]) <= 0:
				_explode(st, b)
				boom = true
	var fl: Dictionary = st["flames"]
	for k: Variant in fl.keys():
		fl[k] = int(fl[k]) - 1
		if int(fl[k]) <= 0:
			fl.erase(k)
	_enemies(st)
	_deaths(st)
	if not bool(st["lost"]) and enemies_left(st) == 0 and st["p"] == st["exit"]:
		st["won"] = true


static func _pick(st: Dictionary) -> void:
	var p: Vector2i = st["p"]
	var it: String = str((st["items"] as Dictionary).get(p, ""))
	if it == "":
		return
	(st["items"] as Dictionary).erase(p)
	match it:
		"B":
			st["max_bombs"] = mini(int(st["max_bombs"]) + 1, 5)
		"R":
			st["range"] = mini(int(st["range"]) + 1, 6)
		"S":
			st["speed"] = maxi(int(st["speed"]) - 1, 2)
	(st["log"] as Array).append({"k": "item", "at": p, "i": it})
	Rules.hook(st, "on_item", [it])


## Casillas que alcanza una bomba en p con alcance r (se para en fijos; la primera caja se rompe).
static func blast(st: Dictionary, p: Vector2i, r: int) -> Array:
	var out: Array = [p]
	for d: Vector2i in DIRS:
		for k: int in range(1, r + 1):
			var q: Vector2i = p + d * k
			var c: String = cell(st, q)
			if c == "#":
				break
			out.append(q)
			if c == "+":
				break
	return out


static func _explode(st: Dictionary, b: Dictionary) -> void:
	(st["bombs"] as Array).erase(b)
	(st["log"] as Array).append({"k": "boom", "at": b["p"]})
	for q: Variant in blast(st, b["p"], int(b["r"])):
		var qi: Vector2i = q
		(st["flames"] as Dictionary)[qi] = FLAME
		if cell(st, qi) == "+":
			_put_cell(st, qi, ".")
			st["crates"] = int(st["crates"]) + 1
			var h: String = str((st["hidden"] as Dictionary).get(qi, ""))
			if h == "X":
				st["exit"] = qi
				(st["log"] as Array).append({"k": "exit", "at": qi})
			elif h != "":
				(st["items"] as Dictionary)[qi] = h
			(st["hidden"] as Dictionary).erase(qi)
		var other: Dictionary = bomb_at(st, qi)
		if not other.is_empty():
			other["t"] = 0


static func _enemies(st: Dictionary) -> void:
	var p: Vector2i = st["p"]
	for e: Variant in st["enemies"]:
		var ed: Dictionary = e
		if not bool(ed["alive"]):
			continue
		ed["from"] = ed["p"]
		ed["cd"] = int(ed["cd"]) - 1
		if int(ed["cd"]) > 0:
			continue
		ed["cd"] = int(ENEMY_CD[str(ed["k"])])
		var at: Vector2i = ed["p"]
		var nxt: Vector2i = at
		if str(ed["k"]) == "c" and absi(p.x - at.x) + absi(p.y - at.y) <= 5 and int(st["shield"]) <= 0:
			var path: Array = _path(st, at, p, 9)
			if not path.is_empty():
				nxt = path[0]
		if nxt == at:
			var d: Vector2i = ed["dir"]
			var opts: Array = []
			for dd: Vector2i in DIRS:
				if _enemy_free(st, at + dd, ed) and dd != -d:
					opts.append(dd)
			if opts.is_empty() and _enemy_free(st, at - d, ed):
				opts.append(-d)
			if not opts.is_empty():
				## Sigue recto si puede; en los cruces a veces gira.
				if opts.has(d) and _rand(st, 3) > 0:
					nxt = at + d
				else:
					var pick: Vector2i = opts[_rand(st, opts.size())]
					nxt = at + pick
		if nxt != at:
			ed["dir"] = nxt - at
			ed["p"] = nxt


static func _enemy_free(st: Dictionary, q: Vector2i, me: Dictionary) -> bool:
	if not open_cell(st, q) or (st["flames"] as Dictionary).has(q):
		return false
	for o: Variant in st["enemies"]:
		if o != me and bool(o["alive"]) and o["p"] == q:
			return false
	return true


static func _path(st: Dictionary, a: Vector2i, b: Vector2i, limit: int) -> Array:
	var prev: Dictionary = {a: a}
	var q: Array = [a]
	var depth: Dictionary = {a: 0}
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		if c == b:
			break
		if int(depth[c]) >= limit:
			continue
		for d: Vector2i in DIRS:
			var n: Vector2i = c + d
			if prev.has(n) or not (open_cell(st, n) or n == b):
				continue
			prev[n] = c
			depth[n] = int(depth[c]) + 1
			q.append(n)
	if not prev.has(b):
		return []
	var out: Array = []
	var cur: Vector2i = b
	while cur != a:
		out.push_front(cur)
		cur = prev[cur]
	return out


static func _deaths(st: Dictionary) -> void:
	var fl: Dictionary = st["flames"]
	for e: Variant in st["enemies"]:
		if bool(e["alive"]) and fl.has(e["p"]):
			e["alive"] = false
			st["kills"] = int(st["kills"]) + 1
			(st["log"] as Array).append({"k": "kill", "at": e["p"]})
			Rules.hook(st, "on_kill", [str(e["k"])])
	var p: Vector2i = st["p"]
	if int(st["shield"]) > 0:
		return
	var hit: bool = fl.has(p)
	for e2: Variant in st["enemies"]:
		## Mismo sitio o cruzandose (uno va donde estaba el otro).
		if bool(e2["alive"]) and (e2["p"] == p or (e2["p"] == st["from"] and e2["from"] == p)):
			hit = true
	if not hit:
		return
	(st["log"] as Array).append({"k": "dead", "at": p})
	st["deaths"] = int(st["deaths"]) + 1
	st["lives"] = int(st["lives"]) - 1
	if int(st["lives"]) <= 0:
		st["lost"] = true
		return
	## Vuelves a la salida con un escudo un momento.
	st["p"] = st["start"]
	st["from"] = st["start"]
	st["move_cd"] = 0
	st["shield"] = SHIELD


# ------------------------------------------------------------------ bot

## Ticks hasta que cada casilla arda (0 = ya arde), con reaccion en cadena.
static func danger(st: Dictionary, extra: Dictionary = {}) -> Dictionary:
	var bombs: Array = []
	for b: Variant in st["bombs"]:
		bombs.append({"p": b["p"], "t": int(b["t"]), "r": int(b["r"])})
	if not extra.is_empty():
		bombs.append(extra)
	var changed: bool = true
	while changed:
		changed = false
		for b: Variant in bombs:
			for q: Variant in blast(st, b["p"], int(b["r"])):
				for o: Variant in bombs:
					if o["p"] == q and int(o["t"]) > int(b["t"]):
						o["t"] = int(b["t"])
						changed = true
	var out: Dictionary = {}
	for k: Variant in st["flames"]:
		out[k] = 0
	for b2: Variant in bombs:
		for q2: Variant in blast(st, b2["p"], int(b2["r"])):
			out[q2] = mini(int(out.get(q2, 999)), int(b2["t"]))
	return out


static func _deadly(dg: Dictionary, q: Vector2i, arrive: int) -> bool:
	if not dg.has(q):
		return false
	var t: int = int(dg[q])
	return arrive >= t - 1 and arrive <= t + FLAME


static func _near_enemy(st: Dictionary, q: Vector2i, dist: int) -> bool:
	for e: Variant in st["enemies"]:
		if bool(e["alive"]):
			var ep: Vector2i = e["p"]
			if absi(ep.x - q.x) + absi(ep.y - q.y) <= dist:
				return true
	return false


## Camino (con tiempos) a la casilla mas cercana que cumpla goal; evita llamas y monstruos.
static func _search(st: Dictionary, dg: Dictionary, goal: Callable, avoid_enemies: int = 1, limit: int = 60) -> Array:
	var a: Vector2i = st["p"]
	var sp: int = int(st["speed"])
	var prev: Dictionary = {a: a}
	var tt: Dictionary = {a: int(st["move_cd"])}
	var q: Array = [a]
	var hit: Vector2i = Vector2i(-99, -99)
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		if goal.call(c, int(tt[c])):
			hit = c
			break
		if int(tt[c]) > limit:
			continue
		for d: Vector2i in DIRS:
			var n: Vector2i = c + d
			if prev.has(n) or not open_cell(st, n):
				continue
			var arrive: int = int(tt[c]) + sp
			if _deadly(dg, n, arrive) or _deadly(dg, c, arrive - 1):
				continue
			if _near_enemy(st, n, avoid_enemies):
				continue
			prev[n] = c
			tt[n] = arrive
			q.append(n)
	if hit.x == -99:
		return []
	var out: Array = []
	var cur: Vector2i = hit
	while cur != a:
		out.push_front(cur)
		cur = prev[cur]
	if out.is_empty():
		out = [a]
	return out


static func _safe_goal(dg: Dictionary) -> Callable:
	return func(c: Vector2i, _t: int) -> bool: return not dg.has(c)


## Merece la pena una bomba aqui: rompe una caja o pilla un monstruo en linea.
static func _bomb_useful(st: Dictionary, c: Vector2i) -> bool:
	for q: Variant in blast(st, c, int(st["range"])):
		if cell(st, q) == "+":
			return true
		for e: Variant in st["enemies"]:
			if bool(e["alive"]) and e["p"] == q and q != c:
				return true
	return false


static func _escape_with_bomb(st: Dictionary, c: Vector2i) -> Array:
	var dg: Dictionary = danger(st, {"p": c, "t": FUSE, "r": int(st["range"])})
	## El refugio, lejos de los monstruos (se mueven mientras huyes).
	var esc: Array = _search(st, dg, func(q: Vector2i, _t: int) -> bool: return not dg.has(q) and not _near_enemy(st, q, 3), 1, FUSE)
	if esc.is_empty() and _near_enemy(st, c, 3):
		esc = _search(st, dg, func(q: Vector2i, _t: int) -> bool: return not dg.has(q) and not _near_enemy(st, q, 2), 1, FUSE)
	return esc


## Accion del bot: {"dir": Vector2i, "drop": bool}.
static func bot_action(st: Dictionary) -> Dictionary:
	var p: Vector2i = st["p"]
	var dg: Dictionary = danger(st)
	var idle: Dictionary = {"dir": Vector2i.ZERO, "drop": false}
	if int(st["move_cd"]) > 0:
		return idle
	## 1 - En peligro (llamas que vienen o un monstruo pegado): huir.
	if dg.has(p) or _near_enemy(st, p, 1):
		if not dg.has(p) and (st["bombs"] as Array).size() < int(st["max_bombs"]) and not _escape_with_bomb(st, p).is_empty():
			return {"dir": Vector2i.ZERO, "drop": true}
		var esc: Array = _search(st, dg, func(c: Vector2i, _t: int) -> bool: return not dg.has(c) and not _near_enemy(st, c, 3), 1)
		if esc.is_empty():
			esc = _search(st, dg, func(c: Vector2i, _t: int) -> bool: return not dg.has(c) and not _near_enemy(st, c, 1), 1)
		if esc.is_empty():
			esc = _search(st, dg, func(c: Vector2i, _t: int) -> bool: return not dg.has(c) and not _near_enemy(st, c, 1), 0)
		if esc.is_empty():
			esc = _search(st, dg, _safe_goal(dg), 0)
		return {"dir": (esc[0] as Vector2i) - p if not esc.is_empty() and esc[0] != p else Vector2i.ZERO, "drop": false}
	## 2 - Salida destapada y sin monstruos: a la salida.
	if enemies_left(st) == 0 and (st["exit"] as Vector2i).x >= 0:
		var ex: Vector2i = st["exit"]
		var pe: Array = _search(st, dg, func(c: Vector2i, _t: int) -> bool: return c == ex, 0, 200)
		if not pe.is_empty() and pe[0] != p:
			return {"dir": (pe[0] as Vector2i) - p, "drop": false}
		return idle
	## 3 - Bomba aqui si sirve y hay por donde huir.
	if (st["bombs"] as Array).size() < int(st["max_bombs"]) and _bomb_useful(st, p) and not _escape_with_bomb(st, p).is_empty():
		return {"dir": Vector2i.ZERO, "drop": true}
	## 4 - Ir a recoger premios o a un sitio donde una bomba sirva.
	var items: Dictionary = st["items"]
	var goal: Callable = func(c: Vector2i, _t: int) -> bool:
		return items.has(c) or (not dg.has(c) and c != p and _bomb_useful(st, c))
	var path: Array = _search(st, dg, goal, 1, 200)
	if not path.is_empty() and path[0] != p:
		var nx: Vector2i = path[0]
		## Espera si al lado hay una bomba a punto de estallar sobre el siguiente paso.
		return {"dir": nx - p, "drop": false}
	## 5 - Nada que hacer: esperar a que los monstruos se acerquen (o deambular).
	return idle


static func bot_play(level: Dictionary, max_ticks: int = 3000) -> Dictionary:
	var st: Dictionary = new_state(level)
	while not bool(st["won"]) and not bool(st["lost"]) and int(st["tick"]) < max_ticks:
		var a: Dictionary = bot_action(st)
		tick(st, a["dir"], bool(a["drop"]))
	return {"won": bool(st["won"]), "ticks": int(st["tick"]), "lost": bool(st["lost"]), "left": enemies_left(st), "exit": st["exit"], "deaths": int(st["deaths"])}


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var st: Dictionary = new_state(level)
	if int(st["w"]) < 7 or int(st["h"]) < 7:
		issues.append("bomber_small")
	var xs: int = 0
	for v: Variant in (st["hidden"] as Dictionary).values():
		if str(v) == "X":
			xs += 1
	if xs != 1:
		issues.append("bomber_exit")
	if (st["enemies"] as Array).is_empty():
		issues.append("bomber_no_enemies")
	if not open_cell(st, st["p"]):
		issues.append("bomber_start")
	for e: Variant in st["enemies"]:
		var ep: Vector2i = e["p"]
		if absi(ep.x - (st["p"] as Vector2i).x) + absi(ep.y - (st["p"] as Vector2i).y) < 5:
			issues.append("bomber_enemy_near_start")
			break
	var r: Dictionary = {"won": false, "ticks": 0}
	if issues.is_empty():
		r = bot_play(level)
		## El bot (que reacciona al instante) puede perder como mucho una de las vidas.
		if not bool(r["won"]) or int(r["deaths"]) > 1:
			issues.append("bomber_bot_failed")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": 0, "enemies": (st["enemies"] as Array).size(),
		"enemy_problems": [], "bot_ticks": r.get("ticks", 0), "bot": r}
