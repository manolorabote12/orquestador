extends RefCounted
## Torre de poder (tipo los anuncios de Hero Wars / Tower Up): tu heroe tiene un numero de poder;
## toca una sala de la torre: si el enemigo tiene MENOS poder, lo vences y te quedas con su poder;
## si tiene igual o mas, pierdes. Las salas de premio suman (+10) o multiplican (x2); las trampas
## restan (-5) o dividen (/2). Se gana al vencer al jefe de la ultima torre.
## Nivel: "start" (poder inicial) y "towers": [[sala, ...] de abajo arriba, ...]; sala:
##   {"t": "enemy", "p": 8} \u00b7 {"t": "bonus", "op": "+10"} \u00b7 {"t": "trap", "op": "-5"} \u00b7 {"t": "boss", "p": 90}
## Las torres se abren en orden: la siguiente cuando la anterior no tiene enemigos.
## El bot juega perfecto: suma primero, vence al mas debil que puede y multiplica solo si se atasca.

const Rules = preload("res://kit/rules.gd")
const MAX_POWER: int = 999999


static func apply(p: int, op: String) -> int:
	var o: String = op.strip_edges()
	if o.length() < 2 or not o.substr(1).is_valid_int():
		return p
	var k: int = int(o.substr(1))
	match o[0]:
		"+":
			return mini(MAX_POWER, p + k)
		"-":
			return maxi(0, p - k)
		"x":
			return mini(MAX_POWER, p * maxi(1, k))
		"/":
			return p / maxi(1, k)
	return p


static func new_state(level: Dictionary) -> Dictionary:
	var towers: Array = []
	for t: Variant in level.get("towers", []):
		var rooms: Array = []
		for r: Variant in (t as Array):
			var d: Dictionary = (r as Dictionary).duplicate()
			d["done"] = false
			rooms.append(d)
		towers.append(rooms)
	var st: Dictionary = {"p": maxi(1, int(level.get("start", 5))), "towers": towers, "won": false, "lost": false, "moves": 0, "rng": RandomNumberGenerator.new()}
	st["rules"] = Rules.load_rules(level)
	Rules.hook(st, "on_start")
	return st


## Torre que se puede atacar ahora: la primera con enemigos (o jefe) sin vencer.
static func open_tower(st: Dictionary) -> int:
	for i: int in (st["towers"] as Array).size():
		for r: Variant in st["towers"][i]:
			if not bool(r["done"]) and (str(r["t"]) == "enemy" or str(r["t"]) == "boss"):
				return i
	return -1


static func can_pick(st: Dictionary, t: int, r: int) -> bool:
	if bool(st["won"]) or bool(st["lost"]) or t < 0 or t >= (st["towers"] as Array).size():
		return false
	if r < 0 or r >= (st["towers"][t] as Array).size() or bool(st["towers"][t][r]["done"]):
		return false
	return t <= open_tower(st)


## Entrar en una sala. Devuelve {"ok", "before", "after", "kind"} (ok false = derrota).
static func pick(st: Dictionary, t: int, r: int) -> Dictionary:
	if not can_pick(st, t, r):
		return {}
	var room: Dictionary = st["towers"][t][r]
	var before: int = int(st["p"])
	var ok: bool = true
	match str(room["t"]):
		"enemy", "boss":
			if before > int(room["p"]):
				st["p"] = mini(MAX_POWER, before + int(room["p"]))
			else:
				ok = false
				st["lost"] = true
		_:
			st["p"] = apply(before, str(room.get("op", "+0")))
	room["done"] = ok
	st["moves"] = int(st["moves"]) + 1
	var out: Dictionary = {"ok": ok, "before": before, "after": int(st["p"]), "kind": str(room["t"]), "tower": t, "room": r}
	Rules.hook(st, "on_pick", [out])
	if ok and str(room["t"]) == "boss":
		st["won"] = true
	elif ok and open_tower(st) < 0:
		st["won"] = true
	return out


## Jugada del bot: [torre, sala] o [] si no hay ninguna buena.
static func bot_move(st: Dictionary) -> Array:
	var t: int = open_tower(st)
	if t < 0:
		return []
	var p: int = int(st["p"])
	var best: Array = []
	## 1 - Sumas (siempre ayudan y mejor antes de multiplicar), en cualquier torre ya abierta.
	for ti: int in t + 1:
		for ri: int in (st["towers"][ti] as Array).size():
			var room: Dictionary = st["towers"][ti][ri]
			if not bool(room["done"]) and str(room["t"]) == "bonus" and str(room.get("op", "")).begins_with("+"):
				return [ti, ri]
	## 2 - El enemigo mas debil que se puede vencer (el jefe, el ultimo).
	var bp: int = MAX_POWER + 1
	for ti2: int in t + 1:
		for ri2: int in (st["towers"][ti2] as Array).size():
			var room2: Dictionary = st["towers"][ti2][ri2]
			if not bool(room2["done"]) and (str(room2["t"]) == "enemy" or str(room2["t"]) == "boss") and p > int(room2["p"]):
				var pr: int = int(room2["p"]) + (MAX_POWER if str(room2["t"]) == "boss" and _enemies_left(st, ti2) > 1 else 0)
				if pr < bp:
					bp = pr
					best = [ti2, ri2]
	if not best.is_empty():
		return best
	## 3 - Atascado: el mayor multiplicador.
	var bm: int = 1
	for ti3: int in t + 1:
		for ri3: int in (st["towers"][ti3] as Array).size():
			var room3: Dictionary = st["towers"][ti3][ri3]
			if not bool(room3["done"]) and str(room3["t"]) == "bonus" and str(room3.get("op", "")).begins_with("x") and apply(p, str(room3["op"])) > bm * p:
				bm = apply(p, str(room3["op"])) / maxi(1, p)
				best = [ti3, ri3]
	return best


static func _enemies_left(st: Dictionary, t: int) -> int:
	var n: int = 0
	for r: Variant in st["towers"][t]:
		if not bool(r["done"]) and (str(r["t"]) == "enemy" or str(r["t"]) == "boss"):
			n += 1
	return n


static func bot_play(level: Dictionary) -> Dictionary:
	var st: Dictionary = new_state(level)
	for k: int in 200:
		if bool(st["won"]) or bool(st["lost"]):
			break
		var m: Array = bot_move(st)
		if m.is_empty():
			break
		pick(st, int(m[0]), int(m[1]))
	return {"won": bool(st["won"]), "power": int(st["p"]), "moves": int(st["moves"])}


## Analizador: el bot (que juega perfecto) gana, y no es un paseo (atacar a lo loco pierde).
static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var towers: Array = level.get("towers", [])
	if towers.is_empty():
		issues.append("tower_empty")
	var bosses: int = 0
	for t: Variant in towers:
		for r: Variant in (t as Array):
			var k: String = str((r as Dictionary).get("t", ""))
			if not ["enemy", "bonus", "trap", "boss"].has(k):
				issues.append("tower_bad_room")
			bosses += 1 if k == "boss" else 0
	if bosses != 1:
		issues.append("tower_one_boss")
	var r2: Dictionary = {"won": false}
	if issues.is_empty():
		r2 = bot_play(level)
		if not bool(r2["won"]):
			issues.append("tower_unbeatable")
		elif _naive_wins(level):
			issues.append("tower_too_easy")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": 0, "enemies": 0, "enemy_problems": [], "power": r2.get("power", 0)}


## Jugador sin pensar: de abajo arriba, torre a torre (sin saltarse trampas). Si eso gana, es un paseo.
static func _naive_wins(level: Dictionary) -> bool:
	var st: Dictionary = new_state(level)
	for t: int in (st["towers"] as Array).size():
		for r: int in (st["towers"][t] as Array).size():
			if not can_pick(st, t, r):
				continue
			var o: Dictionary = pick(st, t, r)
			if o.is_empty() or not bool(o["ok"]):
				return false
			if bool(st["won"]):
				return true
	return bool(st["won"])
