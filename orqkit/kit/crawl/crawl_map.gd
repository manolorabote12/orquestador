extends RefCounted
## Roguelike por turnos (tipo Pixel Dungeon): mazmorra de casillas con niebla; cada paso tuyo es un
## turno y los monstruos que te ven se acercan. Chocar con un monstruo es atacarle. Pociones, armas,
## armaduras y oro. Bajar por la escalera ">" gana el nivel (si hay jefe "B", hay que vencerle antes).
## Mapa ("map"): "#" muro, "." suelo, "P" salida, ">" escalera, monstruos "r" rata, "g" goblin,
## "o" orco, "s" esqueleto, "B" jefe; objetos "!" pocion, "/" espada, "]" armadura, "$" oro.
## Nivel: "hp", "atk", "def" (del heroe), "sight" (vista), "potions" (que llevas al empezar).

const Rules = preload("res://kit/rules.gd")
const MONSTERS: Dictionary = {"r": {"hp": 3, "atk": 2, "def": 0, "xp": 1}, "g": {"hp": 6, "atk": 3, "def": 0, "xp": 2},
	"o": {"hp": 11, "atk": 4, "def": 1, "xp": 4}, "s": {"hp": 8, "atk": 5, "def": 0, "xp": 3}, "B": {"hp": 26, "atk": 6, "def": 2, "xp": 10}}
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


static func new_state(level: Dictionary) -> Dictionary:
	var rows: Array = []
	var mons: Array = []
	var items: Dictionary = {}
	var start: Vector2i = Vector2i.ZERO
	var stairs: Vector2i = Vector2i(-1, -1)
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
			elif ch == ">":
				stairs = p
			elif MONSTERS.has(ch):
				var m: Dictionary = MONSTERS[ch]
				mons.append({"k": ch, "p": p, "hp": int(m["hp"]), "max": int(m["hp"]), "awake": ch == "B"})
				ch = "."
			elif ["!", "/", "]", "$"].has(ch):
				items[p] = ch
				ch = "."
			clean += ch
		rows.append(clean)
		y += 1
	var st: Dictionary = {"map": rows, "w": (rows[0] as String).length() if not rows.is_empty() else 0, "h": rows.size(), "p": start,
		"stairs": stairs, "mons": mons, "items": items, "hp": int(level.get("hp", 20)), "max_hp": int(level.get("hp", 20)),
		"atk": int(level.get("atk", 3)), "def": int(level.get("def", 0)), "potions": int(level.get("potions", 1)), "gold": 0, "xp": 0,
		"sight": int(level.get("sight", 5)), "seen": {}, "turn": 0, "won": false, "lost": false, "log": []}
	_see(st)
	st["rules"] = Rules.load_rules(level)
	Rules.hook(st, "on_start")
	return st


static func wall(st: Dictionary, p: Vector2i) -> bool:
	if p.x < 0 or p.y < 0 or p.x >= int(st["w"]) or p.y >= int(st["h"]):
		return true
	return (st["map"][p.y] as String)[p.x] == "#"


static func mon_at(st: Dictionary, p: Vector2i) -> Dictionary:
	for m: Variant in st["mons"]:
		if int(m["hp"]) > 0 and m["p"] == p:
			return m
	return {}


## Linea de vision (Bresenham sin atravesar muros).
static func can_see(st: Dictionary, a: Vector2i, b: Vector2i) -> bool:
	var d: Vector2i = b - a
	var n: int = maxi(absi(d.x), absi(d.y))
	for k: int in range(1, n):
		var q: Vector2i = a + Vector2i(roundi(float(d.x) * float(k) / float(n)), roundi(float(d.y) * float(k) / float(n)))
		if wall(st, q):
			return false
	return true


static func visible(st: Dictionary, q: Vector2i) -> bool:
	var p: Vector2i = st["p"]
	return absi(q.x - p.x) + absi(q.y - p.y) <= int(st["sight"]) and can_see(st, p, q)


static func _see(st: Dictionary) -> void:
	var p: Vector2i = st["p"]
	var r: int = int(st["sight"])
	for y: int in range(p.y - r, p.y + r + 1):
		for x: int in range(p.x - r, p.x + r + 1):
			var q: Vector2i = Vector2i(x, y)
			if x >= 0 and y >= 0 and x < int(st["w"]) and y < int(st["h"]) and visible(st, q):
				st["seen"][q] = true


## Un paso (o ataque) en la direccion d. Devuelve false si no se puede (muro).
static func step(st: Dictionary, d: Vector2i) -> bool:
	if bool(st["won"]) or bool(st["lost"]):
		return false
	var p: Vector2i = st["p"]
	var q: Vector2i = p + d
	var m: Dictionary = mon_at(st, q)
	if not m.is_empty():
		var spec: Dictionary = MONSTERS[str(m["k"])]
		var dmg: int = maxi(1, int(st["atk"]) - int(spec["def"]))
		m["hp"] = int(m["hp"]) - dmg
		m["awake"] = true
		(st["log"] as Array).append({"k": "hit", "at": q, "n": dmg})
		if int(m["hp"]) <= 0:
			st["xp"] = int(st["xp"]) + int(spec["xp"])
			Rules.hook(st, "on_kill", [str(m["k"])])
			_level_up(st)
	elif wall(st, q):
		return false
	else:
		st["p"] = q
		_pick(st)
		if q == st["stairs"] and not _boss_alive(st):
			st["won"] = true
			return true
	_monsters(st)
	_tick(st)
	_see(st)
	return true


## Cada turno: +1 de vida cada 8 turnos (como en Pixel Dungeon).
static func _tick(st: Dictionary) -> void:
	st["turn"] = int(st["turn"]) + 1
	if int(st["turn"]) % 8 == 0 and not bool(st["lost"]):
		st["hp"] = mini(int(st["max_hp"]), int(st["hp"]) + 1)


## Esperar un turno (los monstruos se mueven).
static func rest(st: Dictionary) -> void:
	if bool(st["won"]) or bool(st["lost"]):
		return
	_monsters(st)
	_tick(st)


static func drink(st: Dictionary) -> bool:
	if int(st["potions"]) <= 0 or bool(st["won"]) or bool(st["lost"]):
		return false
	st["potions"] = int(st["potions"]) - 1
	st["hp"] = mini(int(st["max_hp"]), int(st["hp"]) + 10)
	_monsters(st)
	_tick(st)
	return true


## Subir de nivel: cada 6 de experiencia, +3 de vida maxima (y te cura 3) y +1 de ataque cada dos.
static func _level_up(st: Dictionary) -> void:
	var lvl: int = int(st["xp"]) / 6
	var had: int = int(st.get("lvl", 0))
	if lvl > had:
		st["lvl"] = lvl
		st["max_hp"] = int(st["max_hp"]) + 3
		st["hp"] = int(st["hp"]) + 3
		if lvl % 2 == 0:
			st["atk"] = int(st["atk"]) + 1
		(st["log"] as Array).append({"k": "level", "at": st["p"], "n": lvl})


static func _pick(st: Dictionary) -> void:
	var p: Vector2i = st["p"]
	var items: Dictionary = st["items"]
	if not items.has(p):
		return
	match str(items[p]):
		"!":
			st["potions"] = int(st["potions"]) + 1
		"/":
			st["atk"] = int(st["atk"]) + 2
		"]":
			st["def"] = int(st["def"]) + 1
		"$":
			st["gold"] = int(st["gold"]) + 10
	(st["log"] as Array).append({"k": "item", "at": p, "n": 0, "i": str(items[p])})
	Rules.hook(st, "on_item", [str(items[p])])
	items.erase(p)


static func _boss_alive(st: Dictionary) -> bool:
	for m: Variant in st["mons"]:
		if str(m["k"]) == "B" and int(m["hp"]) > 0:
			return true
	return false


## Turno de los monstruos: los que te ven despiertan; los despiertos se acercan (BFS) y pegan si estan al lado.
static func _monsters(st: Dictionary) -> void:
	var p: Vector2i = st["p"]
	for m: Variant in st["mons"]:
		if int(m["hp"]) <= 0:
			continue
		var mp: Vector2i = m["p"]
		if not bool(m["awake"]) and absi(mp.x - p.x) + absi(mp.y - p.y) <= int(st["sight"]) and can_see(st, mp, p):
			m["awake"] = true
		if not bool(m["awake"]):
			continue
		if absi(mp.x - p.x) + absi(mp.y - p.y) == 1:
			var spec: Dictionary = MONSTERS[str(m["k"])]
			var dmg: int = maxi(1, int(spec["atk"]) - int(st["def"]))
			st["hp"] = int(st["hp"]) - dmg
			(st["log"] as Array).append({"k": "hurt", "at": p, "n": dmg})
			if int(st["hp"]) <= 0:
				st["hp"] = 0
				st["lost"] = true
				return
			continue
		var nxt: Vector2i = _next_step(st, mp, p, 12)
		if nxt != mp and mon_at(st, nxt).is_empty() and nxt != p:
			m["p"] = nxt


## Primer paso del camino mas corto de a hasta b (sin atravesar muros ni monstruos), con limite.
static func _next_step(st: Dictionary, a: Vector2i, b: Vector2i, limit: int) -> Vector2i:
	var prev: Dictionary = {a: a}
	var q: Array = [a]
	var head: int = 0
	while head < q.size():
		var c: Vector2i = q[head]
		head += 1
		if c == b:
			break
		if absi(c.x - a.x) + absi(c.y - a.y) > limit:
			continue
		for d: Vector2i in DIRS:
			var n: Vector2i = c + d
			if prev.has(n) or wall(st, n) or (n != b and not mon_at(st, n).is_empty()):
				continue
			prev[n] = c
			q.append(n)
	if not prev.has(b):
		return a
	var cur: Vector2i = b
	while prev[cur] != a:
		cur = prev[cur]
	return cur


## Camino para el jugador hasta un sitio (para tocar una casilla y andar). [] si no hay.
static func path_to(st: Dictionary, goal: Vector2i, only_seen: bool = true, through_mons: bool = false) -> Array:
	var a: Vector2i = st["p"]
	var prev: Dictionary = {a: a}
	var q: Array = [a]
	var head: int = 0
	while head < q.size():
		var c: Vector2i = q[head]
		head += 1
		if c == goal:
			break
		for d: Vector2i in DIRS:
			var n: Vector2i = c + d
			if prev.has(n) or wall(st, n) or (only_seen and not (st["seen"] as Dictionary).has(n)):
				continue
			if n != goal and not through_mons and not mon_at(st, n).is_empty():
				continue
			prev[n] = c
			q.append(n)
	if not prev.has(goal) or goal == a:
		return []
	var out: Array = []
	var cur: Vector2i = goal
	while cur != a:
		out.push_front(cur)
		cur = prev[cur]
	return out


# ------------------------------------------------------------------ bot

## Bot: bebe si esta bajo; si hay un monstruo al lado, le pega; si no: objetos vistos, monstruos
## despiertos que se pueden ganar, sin explorar lo mas cercano y, al final, la escalera.
static func bot_action(st: Dictionary) -> Variant:
	var p: Vector2i = st["p"]
	if int(st["hp"]) <= int(st["max_hp"]) / 3 and int(st["potions"]) > 0:
		return "drink"
	for d: Vector2i in DIRS:
		if not mon_at(st, p + d).is_empty():
			return d
	var goals: Array = []
	for it: Variant in (st["items"] as Dictionary).keys():
		if (st["seen"] as Dictionary).has(it):
			goals.append(it)
	## Un monstruo despierto viene a por ti: esperarle (como mucho 3 turnos seguidos) en vez de perseguirle.
	var coming: bool = false
	for m: Variant in st["mons"]:
		var mp: Vector2i = m["p"]
		if int(m["hp"]) > 0 and bool(m["awake"]) and absi(mp.x - p.x) + absi(mp.y - p.y) <= int(st["sight"]) + 2:
			coming = true
	if coming and int(st.get("bot_wait", 0)) < 3:
		st["bot_wait"] = int(st.get("bot_wait", 0)) + 1
		return Vector2i.ZERO
	st["bot_wait"] = 0
	if goals.is_empty():
		for m2: Variant in st["mons"]:
			if int(m2["hp"]) > 0 and str(m2["k"]) == "B" and (st["seen"] as Dictionary).has(m2["p"]):
				goals.append(m2["p"])
	if goals.is_empty() and (st["seen"] as Dictionary).has(st["stairs"]) and not _boss_alive(st):
		goals.append(st["stairs"])
	var best: Array = []
	for g: Variant in goals:
		var pth: Array = path_to(st, g, true)
		if not pth.is_empty() and (best.is_empty() or pth.size() < best.size()):
			best = pth
	if best.is_empty():
		best = _frontier(st)
	if best.is_empty():
		return Vector2i.ZERO
	return Vector2i(best[0]) - p


## Hay un monstruo despierto a la vista? (la exploracion automatica se para)
static func danger(st: Dictionary) -> bool:
	for m: Variant in st["mons"]:
		if int(m["hp"]) > 0 and bool(m["awake"]) and visible(st, m["p"]):
			return true
	return false


## Exploracion automatica: camino al objeto visto mas cercano; si no, a lo que falta por ver; si
## ya esta todo visto, a la escalera (con el jefe vencido). Vacio = nada que hacer o peligro.
static func explore_path(st: Dictionary) -> Array:
	if danger(st):
		return []
	var best: Array = []
	for it: Variant in (st["items"] as Dictionary).keys():
		if (st["seen"] as Dictionary).has(it):
			var pth: Array = path_to(st, it, true)
			if not pth.is_empty() and (best.is_empty() or pth.size() < best.size()):
				best = pth
	if best.is_empty():
		best = _frontier(st)
	if best.is_empty() and (st["seen"] as Dictionary).has(st["stairs"]) and not _boss_alive(st):
		best = path_to(st, st["stairs"], true)
	return best


## Camino a la casilla vista mas cercana que tenga al lado algo sin ver (explorar).
static func _frontier(st: Dictionary) -> Array:
	var a: Vector2i = st["p"]
	var seen: Dictionary = st["seen"]
	var prev: Dictionary = {a: a}
	var q: Array = [a]
	var head: int = 0
	var target: Vector2i = Vector2i(-1, -1)
	while head < q.size():
		var c: Vector2i = q[head]
		head += 1
		var open: bool = false
		for d: Vector2i in DIRS:
			if not seen.has(c + d) and not wall(st, c + d):
				open = true
		if open and c != a:
			target = c
			break
		for d2: Vector2i in DIRS:
			var n: Vector2i = c + d2
			if prev.has(n) or wall(st, n) or not seen.has(n) or not mon_at(st, n).is_empty():
				continue
			prev[n] = c
			q.append(n)
	if target.x < 0:
		return []
	var out: Array = []
	var cur: Vector2i = target
	while cur != a:
		out.push_front(cur)
		cur = prev[cur]
	return out


static func bot_play(level: Dictionary) -> Dictionary:
	var st: Dictionary = new_state(level)
	var guard: int = 0
	while not bool(st["won"]) and not bool(st["lost"]) and guard < 1500:
		guard += 1
		var a: Variant = bot_action(st)
		if a is String:
			drink(st)
		elif a == Vector2i.ZERO:
			rest(st)
		else:
			step(st, a)
	return {"won": bool(st["won"]), "turns": int(st["turn"]), "hp": int(st["hp"])}


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var st: Dictionary = new_state(level)
	if (st["stairs"] as Vector2i).x < 0:
		issues.append("crawl_no_stairs")
	if int(st["w"]) < 8 or int(st["h"]) < 8:
		issues.append("crawl_small")
	if path_to(st, st["stairs"], false, true).is_empty() and (st["stairs"] as Vector2i).x >= 0:
		issues.append("crawl_stairs_unreachable")
	var r: Dictionary = {"won": false, "turns": 0}
	if issues.is_empty():
		r = bot_play(level)
		if not bool(r["won"]):
			issues.append("crawl_bot_failed")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": (st["items"] as Dictionary).size(), "enemies": (st["mons"] as Array).size(),
		"enemy_problems": [], "bot_turns": r.get("turns", 0)}
