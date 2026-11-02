extends RefCounted
## Metroidvania: un mundo de salas conectadas en el que las habilidades abren caminos nuevos.
## Todo va por casillas y ticks (10 por segundo): andar una casilla por tick, saltar sube 4, el
## doble salto (J) otras 3 en el aire, el impulso (D) cruza 4 casillas de golpe una vez por salto,
## el martillo (B) rompe los bloques "%" y las llaves (K) abren las puertas "L". Los pinchos quitan
## una vida y te devuelven al ultimo suelo seguro. Llegar a la meta G gana.
## Mapa ("map"): "#" roca, "." aire, "P" salida, "^" pinchos, "%" bloque rompible, "L" puerta,
## "J" "D" "B" habilidades, "K" llave, "$" moneda, "+" corazon, "E" enemigo, "G" meta.
## Nivel: "hp" (vidas), "seed".

const Rules = preload("res://kit/rules.gd")
const TPS: int = 10
const JUMP: int = 4
const DASH: int = 4
const ENEMY_EVERY: int = 3
const INVULN: int = 12
const ITEMS: String = "JDBK$+"


static func new_state(level: Dictionary) -> Dictionary:
	var rows: Array = []
	var items: Dictionary = {}
	var enemies: Array = []
	var start: Vector2i = Vector2i(1, 1)
	var goal: Vector2i = Vector2i(-1, -1)
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
			elif ch == "G":
				goal = p
				ch = "."
			elif ITEMS.contains(ch):
				items[p] = ch
				ch = "."
			elif ch == "E":
				enemies.append({"p": p, "dir": 1 if x % 2 == 0 else -1, "alive": true})
				ch = "."
			clean += ch
		rows.append(clean)
		y += 1
	var coins: int = 0
	for v: Variant in items.values():
		if str(v) == "$":
			coins += 1
	var st: Dictionary = {"map": rows, "w": (rows[0] as String).length() if not rows.is_empty() else 0, "h": rows.size(),
		"p": start, "from": start, "safe": start, "rise": 0, "air_jump": true, "dash_ok": true, "face": 1,
		"abil": {"J": false, "D": false, "B": false}, "keys": 0, "items": items, "goal": goal, "enemies": enemies,
		"hp": int(level.get("hp", 3)), "max_hp": int(level.get("hp", 3)), "inv": 0, "coins": 0, "coins_total": coins,
		"seen": {}, "tick": 0, "won": false, "lost": false, "log": [], "deaths": 0}
	_see(st)
	st["rules"] = Rules.load_rules(level)
	Rules.hook(st, "on_start")
	return st


static func cell(st: Dictionary, p: Vector2i) -> String:
	if p.x < 0 or p.y < 0 or p.x >= int(st["w"]) or p.y >= int(st["h"]):
		return "#"
	return (st["map"][p.y] as String)[p.x]


static func _put(st: Dictionary, p: Vector2i, ch: String) -> void:
	var row: String = st["map"][p.y]
	st["map"][p.y] = row.substr(0, p.x) + ch + row.substr(p.x + 1)


static func solid(st: Dictionary, p: Vector2i) -> bool:
	var c: String = cell(st, p)
	return c == "#" or c == "%" or c == "L"


static func grounded(st: Dictionary, p: Vector2i) -> bool:
	return solid(st, p + Vector2i(0, 1))


## Sala (de 14 x 10) en la que esta una casilla: para el minimapa.
static func room_of(p: Vector2i) -> Vector2i:
	return Vector2i(p.x / 14, p.y / 10)


static func _see(st: Dictionary) -> void:
	(st["seen"] as Dictionary)[room_of(st["p"])] = true


## Un tick: dir (-1, 0, 1), jump, dash y attack son lo que pulsa el jugador este tick.
static func tick(st: Dictionary, dir: int, jump: bool, dash: bool, attack: bool) -> void:
	if bool(st["won"]) or bool(st["lost"]):
		return
	st["tick"] = int(st["tick"]) + 1
	if int(st["inv"]) > 0:
		st["inv"] = int(st["inv"]) - 1
	st["from"] = st["p"]
	if dir != 0:
		st["face"] = dir
	if attack:
		_attack(st)
	_move(st, dir, jump, dash)
	_enemies(st)
	_touch(st)


static func _try_enter(st: Dictionary, q: Vector2i) -> bool:
	if cell(st, q) == "L" and int(st["keys"]) > 0:
		st["keys"] = int(st["keys"]) - 1
		_put(st, q, ".")
		(st["log"] as Array).append({"k": "door", "at": q})
	return not solid(st, q)


static func _move(st: Dictionary, dir: int, jump: bool, dash: bool) -> void:
	var p: Vector2i = st["p"]
	var ground: bool = grounded(st, p)
	if ground:
		st["air_jump"] = true
		st["dash_ok"] = true
	## Horizontal: impulso (4 casillas de golpe) o un paso.
	if dash and bool(st["abil"]["D"]) and bool(st["dash_ok"]):
		var d: int = dir if dir != 0 else int(st["face"])
		st["dash_ok"] = false
		for k: int in DASH:
			if not _try_enter(st, p + Vector2i(d, 0)):
				break
			p += Vector2i(d, 0)
			st["p"] = p
			_pick(st)
		st["rise"] = 0
		(st["log"] as Array).append({"k": "dash"})
		return
	if dir != 0 and _try_enter(st, p + Vector2i(dir, 0)):
		p += Vector2i(dir, 0)
	st["p"] = p
	ground = grounded(st, p)
	## Vertical.
	if jump:
		if ground:
			st["rise"] = JUMP
			(st["log"] as Array).append({"k": "jump"})
		elif bool(st["abil"]["J"]) and bool(st["air_jump"]):
			st["rise"] = JUMP
			st["air_jump"] = false
			(st["log"] as Array).append({"k": "jump2"})
	if int(st["rise"]) > 0:
		if not solid(st, p + Vector2i(0, -1)):
			p += Vector2i(0, -1)
			st["rise"] = int(st["rise"]) - 1
		else:
			st["rise"] = 0
	elif not grounded(st, p):
		p += Vector2i(0, 1)
	st["p"] = p
	if grounded(st, p) and cell(st, p) != "^":
		st["safe"] = p
	if int(p.y) >= int(st["h"]) - 1:
		_hurt(st, true)


static func _pick(st: Dictionary) -> void:
	var p: Vector2i = st["p"]
	var it: String = str((st["items"] as Dictionary).get(p, ""))
	if it == "":
		return
	(st["items"] as Dictionary).erase(p)
	match it:
		"J", "D", "B":
			st["abil"][it] = true
		"K":
			st["keys"] = int(st["keys"]) + 1
		"$":
			st["coins"] = int(st["coins"]) + 1
		"+":
			st["hp"] = mini(int(st["hp"]) + 1, int(st["max_hp"]))
	(st["log"] as Array).append({"k": "item", "at": p, "i": it})
	Rules.hook(st, "on_item", [it])


static func _touch(st: Dictionary) -> void:
	_pick(st)
	_see(st)
	var p: Vector2i = st["p"]
	if cell(st, p) == "^":
		_hurt(st, true)
		return
	if p == st["goal"]:
		st["won"] = true
		(st["log"] as Array).append({"k": "won"})


static func _attack(st: Dictionary) -> void:
	var p: Vector2i = st["p"]
	var f: Vector2i = Vector2i(int(st["face"]), 0)
	(st["log"] as Array).append({"k": "attack", "at": p + f})
	for e: Variant in st["enemies"]:
		var ep: Vector2i = e["p"]
		if bool(e["alive"]) and (ep == p + f or ep == p or ep == p + f + Vector2i(0, -1) or ep == p + f * 2):
			e["alive"] = false
			(st["log"] as Array).append({"k": "kill", "at": ep})
			Rules.hook(st, "on_kill", [])
	if bool(st["abil"]["B"]):
		for q: Vector2i in [p + f, p + f + Vector2i(0, -1), p + Vector2i(0, 1), p + Vector2i(0, -1)]:
			if cell(st, q) == "%":
				_put(st, q, ".")
				(st["log"] as Array).append({"k": "smash", "at": q})


static func _enemies(st: Dictionary) -> void:
	var move: bool = int(st["tick"]) % ENEMY_EVERY == 0
	var p: Vector2i = st["p"]
	for e: Variant in st["enemies"]:
		if not bool(e["alive"]):
			continue
		var ep: Vector2i = e["p"]
		if move:
			var n: Vector2i = ep + Vector2i(int(e["dir"]), 0)
			if solid(st, n) or not solid(st, n + Vector2i(0, 1)) or cell(st, n) == "^":
				e["dir"] = -int(e["dir"])
			else:
				e["p"] = n
				ep = n
		if ep == p and int(st["inv"]) <= 0:
			_hurt(st, false)


static func _hurt(st: Dictionary, respawn: bool) -> void:
	st["hp"] = int(st["hp"]) - 1
	st["deaths"] = int(st["deaths"]) + 1
	st["inv"] = INVULN
	(st["log"] as Array).append({"k": "hurt", "at": st["p"]})
	if int(st["hp"]) <= 0:
		st["lost"] = true
		return
	if respawn:
		st["p"] = st["safe"]
		st["rise"] = 0


# ------------------------------------------------------------------ planificador y bot

## Simulacion del heroe solo (sin enemigos) para planificar: estado compacto.
static func _sim(st: Dictionary, s: Array, dir: int, jump: bool, dash: bool) -> Array:
	## s = [x, y, rise, air_jump, dash_ok]
	var p: Vector2i = Vector2i(s[0], s[1])
	var rise: int = s[2]
	var aj: bool = s[3]
	var dk: bool = s[4]
	var ab: Dictionary = st["abil"]
	var keys: bool = int(st["keys"]) > 0
	var smash: bool = bool(ab["B"])
	var ground: bool = _psolid(st, p + Vector2i(0, 1), keys, smash)
	if ground:
		aj = true
		dk = true
	if dash:
		if not (bool(ab["D"]) and dk) or dir == 0:
			return []
		dk = false
		for k: int in DASH:
			if _psolid(st, p + Vector2i(dir, 0), keys, smash):
				break
			p += Vector2i(dir, 0)
			if cell(st, p) == "^":
				return []
		return [p.x, p.y, 0, aj, dk]
	if dir != 0 and not _psolid(st, p + Vector2i(dir, 0), keys, smash):
		p += Vector2i(dir, 0)
	ground = _psolid(st, p + Vector2i(0, 1), keys, smash)
	if jump:
		if ground:
			rise = JUMP
		elif bool(ab["J"]) and aj:
			rise = JUMP
			aj = false
		else:
			return []
	if rise > 0:
		if not _psolid(st, p + Vector2i(0, -1), keys, smash):
			p += Vector2i(0, -1)
			rise -= 1
		else:
			rise = 0
	elif not ground:
		p += Vector2i(0, 1)
	if cell(st, p) == "^" or p.y >= int(st["h"]) - 1:
		return []
	return [p.x, p.y, rise, aj, dk]


## Para planificar: las puertas cuentan como abiertas si hay llave y los bloques si hay martillo.
static func _psolid(st: Dictionary, p: Vector2i, keys: bool, smash: bool) -> bool:
	var c: String = cell(st, p)
	if c == "#":
		return true
	if c == "%":
		return not smash
	if c == "L":
		return not keys
	return false


const ACTIONS: Array = [[0, false, false], [1, false, false], [-1, false, false], [0, true, false], [1, true, false], [-1, true, false],
	[1, false, true], [-1, false, true]]


## Busqueda en anchura sobre el estado del heroe: camino de acciones a la casilla objetivo mas
## cercana de targets (un diccionario de casillas). Devuelve {path: [acciones], at: casilla}.
static func plan(st: Dictionary, targets: Dictionary, limit: int = 60000) -> Dictionary:
	var p: Vector2i = st["p"]
	var s0: Array = [p.x, p.y, int(st["rise"]), bool(st["air_jump"]), bool(st["dash_ok"])]
	var key0: String = str(s0)
	var prev: Dictionary = {key0: null}
	var q: Array = [s0]
	var i: int = 0
	while i < q.size() and i < limit:
		var s: Array = q[i]
		i += 1
		var at: Vector2i = Vector2i(s[0], s[1])
		if targets.has(at) and i > 1:
			var path: Array = []
			var k: String = str(s)
			while prev[k] != null:
				var pr: Array = prev[k]
				path.push_front(pr[1])
				k = pr[0]
			return {"path": path, "at": at}
		for a: Variant in ACTIONS:
			var n: Array = _sim(st, s, int(a[0]), bool(a[1]), bool(a[2]))
			if n.is_empty():
				continue
			var nk: String = str(n)
			if prev.has(nk):
				continue
			prev[nk] = [str(s), a]
			q.append(n)
	return {}


## Siguiente objetivo: habilidades y llaves primero (lo que abre camino), luego la meta.
static func _targets(st: Dictionary) -> Dictionary:
	var t: Dictionary = {}
	for k: Variant in st["items"]:
		var it: String = str(st["items"][k])
		if it in ["J", "D", "B", "K"] or (it == "+" and int(st["hp"]) < int(st["max_hp"])):
			t[k] = true
	return t


## Accion del bot para este tick: [dir, jump, dash, attack]. Guarda su plan en st["bot_plan"].
static func bot_action(st: Dictionary) -> Array:
	var p: Vector2i = st["p"]
	var face: int = int(st["face"])
	## Enemigo delante o encima: golpe.
	for e: Variant in st["enemies"]:
		if bool(e["alive"]):
			var d: Vector2i = (e["p"] as Vector2i) - p
			if absi(d.y) <= 1 and absi(d.x) <= 2 and d.x != 0:
				st["face"] = signi(d.x)
				st["bot_expect"] = ""
				return [0, false, false, true]
	var plan_a: Array = st.get("bot_plan", [])
	var now: Array = [p.x, p.y, int(st["rise"]), bool(st["air_jump"]), bool(st["dash_ok"])]
	## Si algo nos ha sacado del plan (un golpe, una puerta), se vuelve a planificar.
	if str(st.get("bot_expect", "")) != str(now):
		plan_a = []
	if plan_a.is_empty():
		var t: Dictionary = _targets(st)
		var r: Dictionary = plan(st, t) if not t.is_empty() else {}
		if r.is_empty():
			var g: Dictionary = {}
			if (st["goal"] as Vector2i).x >= 0:
				g[st["goal"]] = true
			r = plan(st, g)
		plan_a = r.get("path", [])
	if plan_a.is_empty():
		st["bot_plan"] = []
		return [0, false, false, false]
	var a: Array = plan_a.pop_front()
	st["bot_plan"] = plan_a
	## Delante hay un bloque rompible o lo tienes encima: martillazo antes de seguir.
	var dir: int = int(a[0])
	var ahead: Vector2i = p + Vector2i(dir if dir != 0 else face, 0)
	if (cell(st, ahead) == "%" or cell(st, ahead + Vector2i(0, -1)) == "%" or cell(st, p + Vector2i(0, -1)) == "%" and bool(a[1])) and bool(st["abil"]["B"]):
		if dir != 0:
			st["face"] = dir
		plan_a.push_front(a)
		st["bot_plan"] = plan_a
		st["bot_expect"] = ""
		return [0, false, false, true]
	st["bot_expect"] = str(_sim(st, now, dir, bool(a[1]), bool(a[2])))
	return [dir, bool(a[1]), bool(a[2]), false]


static func bot_tick(st: Dictionary) -> void:
	var a: Array = bot_action(st)
	tick(st, int(a[0]), bool(a[1]), bool(a[2]), bool(a[3]))


static func bot_play(level: Dictionary, max_ticks: int = 4000) -> Dictionary:
	var st: Dictionary = new_state(level)
	var stuck: int = 0
	while not bool(st["won"]) and not bool(st["lost"]) and int(st["tick"]) < max_ticks:
		var before: Vector2i = st["p"]
		bot_tick(st)
		stuck = stuck + 1 if st["p"] == before else 0
		if stuck > 40:
			break
	return {"won": bool(st["won"]), "ticks": int(st["tick"]), "deaths": int(st["deaths"]), "abil": st["abil"], "p": st["p"]}


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var st: Dictionary = new_state(level)
	if (st["goal"] as Vector2i).x < 0:
		issues.append("metroid_no_goal")
	if int(st["w"]) < 15 or int(st["h"]) < 10:
		issues.append("metroid_small")
	## La gracia: la meta no se alcanza con lo que tienes al empezar.
	if issues.is_empty():
		var g: Dictionary = {st["goal"]: true}
		if not plan(st, g).is_empty():
			issues.append("metroid_no_gates")
	var r: Dictionary = {"won": false}
	if issues.is_empty():
		r = bot_play(level)
		if not bool(r["won"]) or int(r["deaths"]) > 1:
			issues.append("metroid_bot_failed")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": int(st["coins_total"]), "enemies": (st["enemies"] as Array).size(),
		"enemy_problems": [], "bot": r}
