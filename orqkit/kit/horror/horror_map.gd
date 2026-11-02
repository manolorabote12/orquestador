extends RefCounted
## Terror 3D (escapa de la casa): busca las llaves y sal por la puerta mientras un monstruo
## recorre los pasillos; si te ve te persigue, si te pilla pierdes una vida. Escondete en un
## armario para que te pierda. Reglas, simulacion pura, monstruo, bot y analizador.
## 1 - Mapa (game.json -> levels[i].map): casillas de 2 m. "#" pared, "." suelo, "P" salida del
##     jugador, "X" puerta de salida (se abre con todas las llaves), "k" llave, "M" monstruo,
##     "H" armario para esconderse. Una fila "#semilla" para la ronda del monstruo.
## 2 - Parametros: "lives" (3), "speed" (del monstruo, 0-1), "sight" (metros que ve), "time".
## Coordenadas en casillas (x, y); en 3D cada casilla mide TILE metros.

const TILE: float = 2.0
const R: float = 0.28
const SPEED: float = 1.65
const CATCH: float = 0.45
const LOSE_T: float = 3.0


static func rows(level: Dictionary) -> Array:
	var out: Array = []
	for r: Variant in level.get("map", []):
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


static func walkable(st: Dictionary, x: int, y: int) -> bool:
	var c: String = cell(st, x, y)
	if c == "X":
		return bool(st.get("open", false))
	return c != "#"


static func center(c: Vector2i) -> Vector2:
	return Vector2(c) + Vector2(0.5, 0.5)


static func new_state(level: Dictionary) -> Dictionary:
	var m: Array = rows(level)
	var seed_v: int = int(level.get("seed", 1))
	for r: Variant in level.get("map", []):
		var t: String = str(r)
		if t.begins_with("#") and t.substr(1).is_valid_int():
			seed_v = int(t.substr(1))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_v
	var st: Dictionary = {"map": m, "h": m.size(), "w": str(m[0]).length() if m.size() > 0 else 0, "rng": rng, "t": 0.0,
		"keys": [], "got": 0, "hides": [], "exit": Vector2i(-1, -1), "start": Vector2.ZERO, "open": false, "won": false,
		"over": false, "lives": clampi(int(level.get("lives", 3)), 1, 9), "caught": 0, "events": [], "hidden": false, "hide_at": -1,
		"yaw": 0.0, "pitch": 0.0, "time": float(level.get("time", 0.0))}
	var mstart: Vector2 = Vector2.ZERO
	for y: int in m.size():
		var row: String = str(m[y])
		for x: int in row.length():
			var c: String = row[x]
			match c:
				"P":
					st["start"] = center(Vector2i(x, y))
				"X":
					st["exit"] = Vector2i(x, y)
				"k":
					(st["keys"] as Array).append({"c": Vector2i(x, y), "got": false})
				"H":
					(st["hides"] as Array).append(Vector2i(x, y))
				"M":
					mstart = center(Vector2i(x, y))
	st["p"] = st["start"]
	var spd: float = clampf(float(level.get("speed", 0.5)), 0.0, 1.0)
	st["mon"] = {"p": mstart, "start": mstart, "dir": Vector2.RIGHT, "state": "patrol", "path": [], "goal": Vector2.ZERO, "seen_t": 0.0,
		"last": Vector2.ZERO, "patrol": 1.0 + 0.25 * spd, "chase": 1.25 + 0.3 * spd, "sight": clampf(float(level.get("sight", 7.0)), 4.0, 12.0) / TILE,
		"wait": 1.5}
	st["yaw"] = _face_open(st, st["start"])
	return st


static func _face_open(st: Dictionary, p: Vector2) -> float:
	var c: Vector2i = Vector2i(floori(p.x), floori(p.y))
	for d: Vector2i in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
		if walkable(st, c.x + d.x, c.y + d.y):
			return atan2(-float(d.x), -float(d.y))
	return 0.0


static func _ev(st: Dictionary, kind: String, extra: Dictionary = {}) -> void:
	var e: Dictionary = {"kind": kind}
	e.merge(extra)
	(st["events"] as Array).append(e)


# ------------------------------------------------------------------ vista y caminos

## Linea de vision por la rejilla (las paredes y la puerta cerrada tapan).
static func sees(st: Dictionary, a: Vector2, b: Vector2) -> bool:
	var d: float = a.distance_to(b)
	var n: int = maxi(1, ceili(d / 0.2))
	for k: int in range(1, n):
		var q: Vector2 = a.lerp(b, float(k) / float(n))
		if not walkable(st, floori(q.x), floori(q.y)):
			return false
	return true


## Camino por casillas con coste extra cerca de un peligro (para el bot).
static func path(st: Dictionary, from: Vector2, to: Vector2, avoid: Vector2 = Vector2.INF, avoid_r: float = 0.0) -> Array:
	var s: Vector2i = Vector2i(floori(from.x), floori(from.y))
	var t: Vector2i = Vector2i(floori(to.x), floori(to.y))
	if s == t:
		return [to]
	var cost: Dictionary = {s: 0.0}
	var came: Dictionary = {s: s}
	var open: Array = [[0.0, s]]
	var guard: int = 0
	while not open.is_empty() and guard < 4000:
		guard += 1
		var bi: int = 0
		for i: int in open.size():
			if float(open[i][0]) < float(open[bi][0]):
				bi = i
		var c: Vector2i = open[bi][1]
		open.remove_at(bi)
		if c == t:
			break
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if not walkable(st, n.x, n.y) and n != t:
				continue
			var extra: float = 0.0
			if avoid != Vector2.INF:
				var dd: float = center(n).distance_to(avoid)
				if dd < avoid_r:
					extra = (avoid_r - dd) * 6.0
			var nc: float = float(cost[c]) + 1.0 + extra
			if nc < float(cost.get(n, INF)):
				cost[n] = nc
				came[n] = c
				open.append([nc + Vector2(n).distance_to(Vector2(t)), n])
	if not came.has(t):
		return []
	var out: Array = [to]
	var c2: Vector2i = came[t]
	while c2 != s:
		out.push_front(center(c2))
		c2 = came[c2]
	return out


static func _free(st: Dictionary, p: Vector2) -> bool:
	for off: Vector2 in [Vector2(R, 0), Vector2(-R, 0), Vector2(0, R), Vector2(0, -R), Vector2(R, R) * 0.7, Vector2(-R, R) * 0.7, Vector2(R, -R) * 0.7, Vector2(-R, -R) * 0.7]:
		var q: Vector2 = p + off
		if not walkable(st, floori(q.x), floori(q.y)):
			return false
	return true


# ------------------------------------------------------------------ paso

## inp = {"move": Vector2 (relativo a la mirada: y adelante), "hide": bool (entrar o salir del armario)}.
static func step(st: Dictionary, inp: Dictionary, dt: float) -> void:
	if bool(st["over"]):
		return
	st["t"] = float(st["t"]) + dt
	var p: Vector2 = st["p"]
	## Armario: entrar si estas al lado de uno; salir otra vez.
	if bool(inp.get("hide", false)):
		if bool(st["hidden"]):
			st["hidden"] = false
			_ev(st, "unhide")
		else:
			var h: int = near_hide(st)
			if h >= 0:
				st["hidden"] = true
				st["hide_at"] = h
				st["p"] = center(st["hides"][h])
				p = st["p"]
				_ev(st, "hide")
	if not bool(st["hidden"]):
		var mv: Vector2 = inp.get("move", Vector2.ZERO)
		if mv.length() > 1.0:
			mv = mv.normalized()
		var yaw: float = float(st["yaw"])
		var fwd: Vector2 = Vector2(-sin(yaw), -cos(yaw))
		var right: Vector2 = Vector2(cos(yaw), -sin(yaw))
		var d: Vector2 = (right * mv.x + fwd * mv.y) * SPEED * dt
		for axis: int in 2:
			var np: Vector2 = p
			np[axis] += d[axis]
			if _free(st, np):
				p = np
		st["p"] = p
	## Llaves y salida.
	for k: Dictionary in st["keys"]:
		if not bool(k["got"]) and p.distance_to(center(k["c"])) < 0.55:
			k["got"] = true
			st["got"] = int(st["got"]) + 1
			_ev(st, "key")
			if int(st["got"]) >= (st["keys"] as Array).size():
				st["open"] = true
				_ev(st, "open")
	var ex: Vector2i = st["exit"]
	if bool(st["open"]) and p.distance_to(center(ex)) < 0.6:
		st["won"] = true
		st["over"] = true
		_ev(st, "win")
		return
	_monster(st, dt)


static func near_hide(st: Dictionary) -> int:
	var p: Vector2 = st["p"]
	var hs: Array = st["hides"]
	for i: int in hs.size():
		if p.distance_to(center(hs[i])) < 1.1:
			return i
	return -1


static func _monster(st: Dictionary, dt: float) -> void:
	var mon: Dictionary = st["mon"]
	var mp: Vector2 = mon["p"]
	var p: Vector2 = st["p"]
	var rng: RandomNumberGenerator = st["rng"]
	var sees_me: bool = not bool(st["hidden"]) and mp.distance_to(p) < float(mon["sight"]) and sees(st, mp, p)
	## Ve por delante (un cono amplio) o oye muy cerca.
	if sees_me and mp.distance_to(p) > 1.2:
		var to: Vector2 = (p - mp).normalized()
		if to.dot(mon["dir"]) < -0.2:
			sees_me = false
	if sees_me:
		if str(mon["state"]) != "chase":
			_ev(st, "spotted")
		mon["state"] = "chase"
		mon["last"] = p
		mon["seen_t"] = 0.0
	var speed: float = float(mon["patrol"])
	match str(mon["state"]):
		"chase":
			speed = float(mon["chase"])
			mon["seen_t"] = float(mon["seen_t"]) + dt
			if float(mon["seen_t"]) > LOSE_T:
				mon["state"] = "search"
				mon["path"] = path(st, mp, mon["last"])
			elif sees_me:
				mon["path"] = [p]
			elif (mon["path"] as Array).is_empty():
				mon["path"] = path(st, mp, mon["last"])
		"search":
			if (mon["path"] as Array).is_empty():
				mon["state"] = "patrol"
				mon["wait"] = 1.0
		"patrol":
			if (mon["path"] as Array).is_empty():
				mon["wait"] = float(mon["wait"]) - dt
				if float(mon["wait"]) <= 0.0:
					mon["path"] = path(st, mp, _random_floor(st, rng))
					mon["wait"] = rng.randf_range(0.5, 2.0)
	var pth: Array = mon["path"]
	var left: float = speed * dt
	while left > 0.0 and not pth.is_empty():
		var nx: Vector2 = pth[0]
		var d: float = mp.distance_to(nx)
		if d <= left:
			mp = nx
			left -= d
			pth.pop_front()
		else:
			mon["dir"] = (nx - mp).normalized()
			mp += (nx - mp) / d * left
			left = 0.0
	mon["p"] = mp
	## Te pilla (si estas escondido solo si te vio entrar: estando en caza y muy cerca).
	var caught: bool = mp.distance_to(p) < CATCH and (not bool(st["hidden"]) or str(mon["state"]) == "chase" and float(mon["seen_t"]) < 0.4)
	if caught:
		st["caught"] = int(st["caught"]) + 1
		st["lives"] = int(st["lives"]) - 1
		_ev(st, "caught")
		if int(st["lives"]) <= 0:
			st["over"] = true
			_ev(st, "dead")
		else:
			respawn(st)


static func _random_floor(st: Dictionary, rng: RandomNumberGenerator) -> Vector2:
	for k: int in 40:
		var x: int = rng.randi_range(1, int(st["w"]) - 2)
		var y: int = rng.randi_range(1, int(st["h"]) - 2)
		if walkable(st, x, y) and cell(st, x, y) != "H":
			return center(Vector2i(x, y))
	return st["mon"]["start"]


## Tras pillarte: vuelves a la entrada y el monstruo a su sitio (las llaves que tenias se quedan).
static func respawn(st: Dictionary) -> void:
	st["p"] = st["start"]
	st["hidden"] = false
	st["yaw"] = _face_open(st, st["start"])
	var mon: Dictionary = st["mon"]
	mon["p"] = mon["start"]
	mon["state"] = "patrol"
	mon["path"] = []
	mon["wait"] = 2.5
	st["bot"] = {}


# ------------------------------------------------------------------ bot

## El bot: va a la llave mas cercana (o a la salida) evitando al monstruo; si le persigue y esta
## cerca, se esconde en el armario mas a mano y espera a que se vaya.
static func bot_control(st: Dictionary, dt: float) -> Dictionary:
	var bot: Dictionary = st.get("bot", {})
	st["bot"] = bot
	var p: Vector2 = st["p"]
	var mon: Dictionary = st["mon"]
	var mp: Vector2 = mon["p"]
	var danger: bool = str(mon["state"]) == "chase" and mp.distance_to(p) < 5.0
	bot["think"] = float(bot.get("think", 0.0)) - dt
	if bool(st["hidden"]):
		bot["hid_t"] = float(bot.get("hid_t", 0.0)) + dt
		## Salir cuando ya no persigue y esta lejos (o tras mucho rato).
		if (str(mon["state"]) != "chase" and mp.distance_to(p) > 3.5) or float(bot["hid_t"]) > 12.0:
			bot["hid_t"] = 0.0
			bot["wait_out"] = float(bot.get("wait_out", 0.0)) + dt
			if float(bot["wait_out"]) > 0.6:
				bot["wait_out"] = 0.0
				bot["path"] = []
				return {"move": Vector2.ZERO, "hide": true}
		return {"move": Vector2.ZERO, "hide": false}
	if danger:
		var h: int = near_hide(st)
		if h >= 0:
			return {"move": Vector2.ZERO, "hide": true}
	if float(bot["think"]) <= 0.0 or (bot.get("path", []) as Array).is_empty():
		bot["think"] = 0.3
		var goal: Vector2 = center(st["exit"]) if bool(st["open"]) else _nearest_key(st)
		if danger:
			## Al armario mas cercano que no este detras del monstruo.
			var best: Vector2 = Vector2.INF
			var bd: float = INF
			for hc: Vector2i in st["hides"]:
				var q: Vector2 = center(hc)
				var dq: float = q.distance_to(p)
				if q.distance_to(mp) > dq * 0.9 and dq < bd:
					bd = dq
					best = q
			if best != Vector2.INF and bd < 6.0:
				goal = best
		var avoid_r: float = 3.5 if str(mon["state"]) == "chase" else 2.5
		bot["path"] = path(st, p, goal, mp, avoid_r)
	var pth: Array = bot["path"]
	while not pth.is_empty() and (pth[0] as Vector2).distance_to(p) < 0.12:
		pth.pop_front()
	if pth.is_empty():
		return {"move": Vector2.ZERO, "hide": false}
	var nx: Vector2 = pth[0]
	var to: Vector2 = nx - p
	st["yaw"] = atan2(-to.x, -to.y)
	return {"move": Vector2(0, 1), "hide": false}


static func _nearest_key(st: Dictionary) -> Vector2:
	var p: Vector2 = st["p"]
	var best: Vector2 = center(st["exit"])
	var bd: float = INF
	for k: Dictionary in st["keys"]:
		if not bool(k["got"]):
			var pth: Array = path(st, p, center(k["c"]))
			var d: float = float(pth.size())
			if not pth.is_empty() and d < bd:
				bd = d
				best = center(k["c"])
	return best


static func bot_play(level: Dictionary, dt: float = 1.0 / 20.0, limit: float = 600.0) -> Dictionary:
	var st: Dictionary = new_state(level)
	while not bool(st["over"]) and float(st["t"]) < limit:
		step(st, bot_control(st, dt), dt)
		(st["events"] as Array).clear()
	return {"won": bool(st["won"]), "time": float(st["t"]), "caught": int(st["caught"]), "keys": int(st["got"])}


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var st: Dictionary = new_state(level)
	if (st["keys"] as Array).is_empty():
		issues.append("horror_keys")
	if (st["exit"] as Vector2i).x < 0:
		issues.append("horror_exit")
	if (st["mon"]["start"] as Vector2) == Vector2.ZERO:
		issues.append("horror_monster")
	## Todo se alcanza desde la entrada.
	if issues.is_empty():
		st["open"] = true
		for k: Dictionary in st["keys"]:
			if path(st, st["start"], center(k["c"])).is_empty():
				issues.append("horror_unreachable")
				break
		if path(st, st["start"], center(st["exit"])).is_empty():
			issues.append("horror_unreachable")
	var par: int = 0
	if issues.is_empty():
		var r: Dictionary = bot_play(level)
		if not bool(r["won"]) or int(r["caught"]) > 1:
			issues.append("horror_too_hard")
		par = int(float(r["time"]) * 1.5) + 20
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": (st["keys"] as Array).size(), "enemies": 1, "enemy_problems": [], "par": par}
