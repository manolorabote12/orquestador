extends RefCounted
## Conduccion 3D por la ciudad (repartos contra reloj): recoge cada paquete y llevalo a su sitio
## antes de que se acabe el tiempo, esquivando el trafico. Reglas, fisica del coche, trafico, bot
## y analizador (lo usan el juego, el bot y el analizador).
## 1 - Mapa (game.json -> levels[i].map): la ciudad en casillas de TILE metros: "." calle,
##     "#" manzana de edificios, "p" parque, "S" salida. Fila "#semilla" para el trafico.
## 2 - Parametros: "jobs" ([[x1, y1, x2, y2], ...]: recoger en una casilla y entregar en otra),
##     "time" (segundos por reparto), "traffic" (coches), "speed" del trafico (0-1).
## Coordenadas en metros (x, y); el coche mira hacia "a" (0 = hacia -y, el norte).

const TILE: float = 10.0
const CAR_R: float = 1.1
const ACCEL: float = 10.0
const BRAKE: float = 18.0
const MAX_V: float = 22.0
const TURN: float = 2.3
const STOP_R: float = 4.5


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


static func road(st: Dictionary, x: int, y: int) -> bool:
	return ".S".contains(cell(st, x, y))


static func tcenter(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * TILE


static func tile_of(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / TILE), floori(p.y / TILE))


static func dir_of(a: float) -> Vector2:
	return Vector2(-sin(a), -cos(a))


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
		"jobs": [], "job": 0, "carrying": false, "left": 0.0, "per_job": clampf(float(level.get("time", 60.0)), 15.0, 300.0),
		"won": false, "over": false, "events": [], "traffic": [], "crashes": 0, "done": 0}
	var start: Vector2i = Vector2i(1, 1)
	for y: int in m.size():
		var row: String = str(m[y])
		for x: int in row.length():
			if row[x] == "S":
				start = Vector2i(x, y)
	st["car"] = {"p": tcenter(start), "a": _open_dir(st, start), "v": 0.0}
	for j: Variant in level.get("jobs", []):
		if j is Array and (j as Array).size() == 4:
			(st["jobs"] as Array).append({"from": Vector2i(int(j[0]), int(j[1])), "to": Vector2i(int(j[2]), int(j[3]))})
	st["left"] = float(st["per_job"])
	var spd: float = clampf(float(level.get("speed", 0.4)), 0.0, 1.0)
	var roads: Array[Vector2i] = []
	for y2: int in m.size():
		for x2: int in str(m[y2]).length():
			if road(st, x2, y2) and Vector2i(x2, y2).distance_to(start) > 2.5:
				roads.append(Vector2i(x2, y2))
	for k: int in clampi(int(level.get("traffic", 6)), 0, 30):
		if roads.is_empty():
			break
		var c: Vector2i = roads[rng.randi_range(0, roads.size() - 1)]
		(st["traffic"] as Array).append({"p": tcenter(c), "q": tcenter(c), "from": c, "to": c, "v": 5.0 + 4.0 * spd + rng.randf_range(-1.0, 1.0), "a": 0.0,
			"col": rng.randi_range(0, 7), "wait": 0.0, "dir": Vector2(0, -1)})
	return st


static func _open_dir(st: Dictionary, c: Vector2i) -> float:
	for d: Vector2i in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1)]:
		if road(st, c.x + d.x, c.y + d.y):
			return atan2(-float(d.x), -float(d.y))
	return 0.0


static func target(st: Dictionary) -> Vector2i:
	var jobs: Array = st["jobs"]
	if int(st["job"]) >= jobs.size():
		return Vector2i(-1, -1)
	var j: Dictionary = jobs[int(st["job"])]
	return j["to"] if bool(st["carrying"]) else j["from"]


static func _ev(st: Dictionary, kind: String, extra: Dictionary = {}) -> void:
	var e: Dictionary = {"kind": kind}
	e.merge(extra)
	(st["events"] as Array).append(e)


static func _blocked(st: Dictionary, p: Vector2) -> bool:
	for off: Vector2 in [Vector2(CAR_R, 0), Vector2(-CAR_R, 0), Vector2(0, CAR_R), Vector2(0, -CAR_R)]:
		var q: Vector2 = p + off
		if not road(st, floori(q.x / TILE), floori(q.y / TILE)):
			return true
	return false


# ------------------------------------------------------------------ paso

## inp = {"steer": -1..1 (derecha positivo), "gas": -1..1 (frenar / marcha atras negativo)}.
static func step(st: Dictionary, inp: Dictionary, dt: float) -> void:
	if bool(st["over"]):
		return
	st["t"] = float(st["t"]) + dt
	var car: Dictionary = st["car"]
	var v: float = float(car["v"])
	var gas: float = clampf(float(inp.get("gas", 0.0)), -1.0, 1.0)
	var steer: float = clampf(float(inp.get("steer", 0.0)), -1.0, 1.0)
	if gas > 0.0:
		v += ACCEL * gas * dt
	elif gas < 0.0:
		v += (BRAKE if v > 0.0 else ACCEL * 0.5) * gas * dt
	v -= v * 0.35 * dt
	if gas == 0.0:
		v = move_toward(v, 0.0, 3.0 * dt)
	v = clampf(v, -6.0, MAX_V)
	## Gira mas despacio a mucha velocidad y nada parado.
	var grip: float = clampf(absf(v) / 6.0, 0.0, 1.0) * (1.0 - 0.35 * clampf(absf(v) / MAX_V, 0.0, 1.0))
	car["a"] = wrapf(float(car["a"]) - steer * TURN * grip * signf(v) * dt, -PI, PI)
	var p: Vector2 = car["p"]
	var mv: Vector2 = dir_of(float(car["a"])) * v * dt
	var hit: bool = false
	for axis: int in 2:
		var np: Vector2 = p
		np[axis] += mv[axis]
		if _blocked(st, np):
			hit = true
		else:
			p = np
	if hit and absf(v) > 4.0:
		v *= 0.45
		_ev(st, "bump", {"v": absf(v)})
		st["crashes"] = int(st["crashes"]) + 1
	elif hit:
		v *= 0.8
	car["p"] = p
	car["v"] = v
	_traffic(st, dt)
	## Choque con un coche del trafico.
	for o: Dictionary in st["traffic"]:
		var d: Vector2 = p - (o["q"] as Vector2)
		if d.length() < CAR_R * 2.0 and d.length() > 0.01:
			car["p"] = (o["q"] as Vector2) + d.normalized() * CAR_R * 2.0
			if _blocked(st, car["p"]):
				car["p"] = p
			if absf(float(car["v"])) > 3.0:
				_ev(st, "crash", {"v": absf(float(car["v"]))})
				st["crashes"] = int(st["crashes"]) + 1
			car["v"] = float(car["v"]) * 0.3
			o["wait"] = 1.0
	## Repartos.
	var tg: Vector2i = target(st)
	if tg.x >= 0 and (car["p"] as Vector2).distance_to(tcenter(tg)) < STOP_R and absf(float(car["v"])) < 12.0:
		if bool(st["carrying"]):
			st["carrying"] = false
			st["job"] = int(st["job"]) + 1
			st["done"] = int(st["done"]) + 1
			_ev(st, "deliver", {"bonus": int(float(st["left"]))})
			if int(st["job"]) >= (st["jobs"] as Array).size():
				st["won"] = true
				st["over"] = true
				_ev(st, "win")
				return
			st["left"] = float(st["per_job"])
		else:
			st["carrying"] = true
			_ev(st, "pickup")
	st["left"] = float(st["left"]) - dt
	if float(st["left"]) <= 0.0:
		st["over"] = true
		_ev(st, "timeout")


## Trafico: de casilla en casilla por las calles, girando al azar en los cruces (sin dar la vuelta).
static func _traffic(st: Dictionary, dt: float) -> void:
	var rng: RandomNumberGenerator = st["rng"]
	var car_p: Vector2 = st["car"]["p"]
	for o: Dictionary in st["traffic"]:
		if float(o["wait"]) > 0.0:
			o["wait"] = float(o["wait"]) - dt
			continue
		var to: Vector2i = o["to"]
		var goal: Vector2 = tcenter(to)
		var p: Vector2 = o["p"]
		if p.distance_to(goal) < 0.3:
			var from: Vector2i = o["from"]
			var opts: Array[Vector2i] = []
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = to + d
				if road(st, n.x, n.y) and n != from:
					opts.append(n)
			if opts.is_empty():
				opts.append(from)
			o["from"] = to
			o["to"] = opts[rng.randi_range(0, opts.size() - 1)]
			continue
		## Va por su carril (a la derecha) y para si el jugador esta justo delante en el.
		var dir: Vector2 = (goal - p).normalized()
		var lane: Vector2 = Vector2(-dir.y, dir.x) * 2.3
		var ahead: Vector2 = car_p - (p + lane)
		var along: float = ahead.dot(dir)
		if along > 0.0 and along < 6.0 and absf(ahead.dot(Vector2(-dir.y, dir.x))) < 2.0 and float(o.get("block_t", 0.0)) < 1.2:
			o["block_t"] = float(o.get("block_t", 0.0)) + dt
			continue
		## Sin paciencia infinita: tras un momento sigue (y se le olvida un rato).
		o["block_t"] = maxf(-1.5, float(o.get("block_t", 0.0)) - dt * 0.5) if float(o.get("block_t", 0.0)) < 1.2 else -1.5
		var step_d: float = minf(float(o["v"]) * dt, p.distance_to(goal))
		o["p"] = p + dir * step_d
		o["dir"] = (o["dir"] as Vector2).lerp(dir, minf(1.0, dt * 6.0)).normalized()
		var dd: Vector2 = o["dir"]
		o["q"] = (o["p"] as Vector2) + Vector2(-dd.y, dd.x) * 2.3
		o["a"] = atan2(-dd.x, -dd.y)


# ------------------------------------------------------------------ bot

static func path(st: Dictionary, from: Vector2i, to: Vector2i) -> Array:
	var came: Dictionary = {from: from}
	var q: Array[Vector2i] = [from]
	var i: int = 0
	while i < q.size():
		var c: Vector2i = q[i]
		i += 1
		if c == to:
			break
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if not came.has(n) and road(st, n.x, n.y):
				came[n] = c
				q.append(n)
	if not came.has(to):
		return []
	var out: Array = []
	var c2: Vector2i = to
	while c2 != from:
		out.push_front(c2)
		c2 = came[c2]
	return out


## El bot conduce como una persona: sigue el camino casilla a casilla, frena antes de las curvas
## y si tiene un coche delante.
static func bot_control(st: Dictionary) -> Dictionary:
	var car: Dictionary = st["car"]
	var p: Vector2 = car["p"]
	var tg: Vector2i = target(st)
	if tg.x < 0:
		return {"steer": 0.0, "gas": -1.0}
	var bot: Dictionary = st.get("bot", {})
	st["bot"] = bot
	var here: Vector2i = tile_of(p)
	if bot.get("tg", Vector2i(-9, -9)) != tg or bot.get("from", Vector2i(-9, -9)) != here and not (bot.get("path", []) as Array).has(here):
		bot["tg"] = tg
		bot["path"] = path(st, here, tg)
		bot["from"] = here
	var pth: Array = bot["path"]
	while not pth.is_empty() and here == pth[0]:
		pth.pop_front()
	var aim: Vector2 = tcenter(tg) if pth.is_empty() else tcenter(pth[0])
	## Mira un poco mas alla para trazar las curvas, y va por su carril (a la derecha).
	if pth.size() >= 2 and p.distance_to(aim) < TILE * 0.6:
		aim = aim.lerp(tcenter(pth[1]), 0.5)
	if not pth.is_empty():
		var seg: Vector2 = (tcenter(pth[0]) - tcenter(here)).normalized()
		if seg.length() > 0.1 and p.distance_to(tcenter(tg)) > TILE:
			aim += Vector2(-seg.y, seg.x) * 2.0
	var want: float = atan2(-(aim - p).x, -(aim - p).y)
	var err: float = wrapf(want - float(car["a"]), -PI, PI)
	var steer: float = clampf(-err * 2.2, -1.0, 1.0)
	var v: float = float(car["v"])
	var turn_ahead: bool = pth.size() >= 2 and (Vector2(pth[1] - pth[0])).dot(Vector2(pth[0] - here)) < 0.5
	var top: float = 18.0 if not turn_ahead else 9.0
	if absf(err) > 0.8:
		top = 6.0
	if pth.size() <= 1:
		top = 9.0
	var fwd: Vector2 = dir_of(float(car["a"]))
	var blocked: bool = false
	if float(bot.get("ignore", 0.0)) <= 0.0:
		for o: Dictionary in st["traffic"]:
			var d: Vector2 = (o["q"] as Vector2) - p
			var along: float = d.dot(fwd)
			if along > 0.0 and along < 11.0 and absf(d.dot(Vector2(-fwd.y, fwd.x))) < 2.4:
				top = minf(top, maxf(0.0, along - 4.5) * 1.5)
				blocked = top < 1.0
	else:
		bot["ignore"] = float(bot["ignore"]) - 1.0
	## Un coche parado delante mucho rato: se le rodea (deja de esperarle un momento).
	bot["wait_car"] = float(bot.get("wait_car", 0.0)) + 1.0 if blocked else 0.0
	if float(bot["wait_car"]) > 45.0:
		bot["ignore"] = 45.0
		bot["wait_car"] = 0.0
	var gas: float = 1.0 if v < top - 0.5 else (-1.0 if v > top + 1.5 else 0.0)
	## Atascado contra algo: marcha atras un momento.
	bot["stuck"] = float(bot.get("stuck", 0.0)) + (1.0 if absf(v) < 0.5 and gas > 0.0 else -1.0)
	bot["stuck"] = clampf(float(bot["stuck"]), 0.0, 60.0)
	if float(bot["stuck"]) > 40.0:
		bot["rev"] = 20
		bot["stuck"] = 0.0
	if int(bot.get("rev", 0)) > 0:
		bot["rev"] = int(bot["rev"]) - 1
		return {"steer": -steer, "gas": -1.0}
	return {"steer": steer, "gas": gas}


static func bot_play(level: Dictionary, dt: float = 1.0 / 30.0) -> Dictionary:
	var st: Dictionary = new_state(level)
	var worst: float = INF
	while not bool(st["over"]):
		step(st, bot_control(st), dt)
		worst = minf(worst, float(st["left"]))
		(st["events"] as Array).clear()
	return {"won": bool(st["won"]), "time": float(st["t"]), "crashes": int(st["crashes"]), "done": int(st["done"]), "spare": worst}


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var st: Dictionary = new_state(level)
	if (st["jobs"] as Array).is_empty():
		issues.append("drive_jobs")
	for j: Dictionary in st["jobs"]:
		var f: Vector2i = j["from"]
		var t: Vector2i = j["to"]
		if not road(st, f.x, f.y) or not road(st, t.x, t.y):
			issues.append("drive_stop")
			break
		if path(st, tile_of(st["car"]["p"]), f).is_empty() and tile_of(st["car"]["p"]) != f:
			issues.append("drive_unreachable")
			break
	var par: int = 0
	if issues.is_empty():
		var r: Dictionary = bot_play(level)
		if not bool(r["won"]):
			issues.append("drive_too_hard")
		par = int(float(r["time"]) * 1.3) + 10
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": (st["jobs"] as Array).size(), "enemies": int(level.get("traffic", 6)),
		"enemy_problems": [], "par": par}
