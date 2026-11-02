extends RefCounted
## Parkour 3D (obby): recorrido de plataformas en el aire hasta la meta, en tercera persona.
## Reglas, fisica, bot y analizador (lo usan el juego, el bot y el analizador).
## 1 - Mapa (game.json -> levels[i].map): una pieza por fila, numeros separados por espacios.
##     P x y z sx sy sz              plataforma (centro y tamano)
##     M x y z sx sy sz ax ay az T f plataforma que va y viene (amplitud, periodo y fase 0-1)
##     F x y z sx sy sz T f          plataforma que aparece y desaparece (solida el 60 % del ciclo)
##     C x y z sx sy sz              punto de control (se reaparece aqui al caer)
##     J x y z sx sy sz              cama elastica (salto muy alto)
##     G x y z sx sy sz              meta
##     L x y z sx sy sz              lava (tocarla es caer)
##     S x y z largo vel             barra que gira (vel en rad/s) a la altura y: hay que saltarla
##     O x y z                       moneda
##     La primera pieza es la salida. El orden de las piezas es el orden del recorrido.
## 2 - Todo depende del tiempo de forma pura: el bot simula el futuro con step() y elige cuando
##     esperar y cuando saltar. El analizador juega el nivel con el bot.

const PW: float = 0.7
const PH: float = 1.6
const SPEED: float = 7.0
const AIR: float = 0.85
const GRAV: float = 32.0
const JUMP: float = 11.5
const PAD: float = 18.0
const COYOTE: float = 0.1
const FALL_Y: float = -12.0
const STAND: String = "PMFCJG"


static func parse(level: Dictionary) -> Array:
	var out: Array = []
	for row: Variant in level.get("map", []):
		var t: PackedStringArray = str(row).strip_edges().split(" ", false)
		if t.size() < 4:
			continue
		var k: String = t[0]
		var n: Array[float] = []
		for i: int in range(1, t.size()):
			n.append(float(t[i]))
		var pc: Dictionary = {"k": k, "c": Vector3(n[0], n[1], n[2]), "s": Vector3.ONE, "a": Vector3.ZERO, "per": 0.0, "ph": 0.0,
			"i": out.size()}
		if k in ["P", "C", "J", "G", "L", "M", "F"] and n.size() >= 6:
			pc["s"] = Vector3(maxf(0.2, n[3]), maxf(0.2, n[4]), maxf(0.2, n[5]))
		if k == "M" and n.size() >= 11:
			pc["a"] = Vector3(n[6], n[7], n[8])
			pc["per"] = maxf(0.5, n[9])
			pc["ph"] = n[10]
		elif k == "F" and n.size() >= 8:
			pc["per"] = maxf(0.8, n[6])
			pc["ph"] = n[7]
		elif k == "S" and n.size() >= 5:
			pc["s"] = Vector3(n[3], 0.3, 0.3)
			pc["per"] = n[4]
		elif k not in ["P", "C", "J", "G", "L", "M", "F", "O", "S"]:
			continue
		out.append(pc)
	return out


static func new_state(level: Dictionary) -> Dictionary:
	var pieces: Array = parse(level)
	var spawn: Vector3 = Vector3.ZERO
	if not pieces.is_empty():
		var p0: Dictionary = pieces[0]
		spawn = (p0["c"] as Vector3) + Vector3(0, (p0["s"] as Vector3).y * 0.5, 0)
	var coins: int = 0
	for pc: Dictionary in pieces:
		if str(pc["k"]) == "O":
			coins += 1
	var st: Dictionary = {"pieces": pieces, "p": spawn, "v": Vector3.ZERO, "t": 0.0, "on_floor": true, "ground": 0, "coyote": 0.0,
		"yaw": _yaw_to(spawn, _next_target_pos(pieces, 0, 0.0)), "cp": spawn, "cp_i": 0, "dead": false, "won": false,
		"got": {}, "coins_total": coins, "deaths": 0, "sim": false, "jumped": false, "best": 0, "events": []}
	return st


## Donde esta una pieza en el instante t.
static func center_at(pc: Dictionary, t: float) -> Vector3:
	var c: Vector3 = pc["c"]
	if str(pc["k"]) == "M":
		c += (pc["a"] as Vector3) * sin(TAU * (t / float(pc["per"]) + float(pc["ph"])))
	return c


static func solid_at(pc: Dictionary, t: float) -> bool:
	var k: String = pc["k"]
	if k == "F":
		return fmod(t / float(pc["per"]) + float(pc["ph"]) + 10.0, 1.0) < 0.6
	return STAND.contains(k)


## 0..1: lo que le falta a una plataforma que desaparece (para el aviso de parpadeo).
static func fade_left(pc: Dictionary, t: float) -> float:
	var f: float = fmod(t / float(pc["per"]) + float(pc["ph"]) + 10.0, 1.0)
	return clampf((0.6 - f) / 0.6, 0.0, 1.0) if f < 0.6 else 0.0


static func box_at(pc: Dictionary, t: float) -> AABB:
	var s: Vector3 = pc["s"]
	return AABB(center_at(pc, t) - s * 0.5, s)


static func body(p: Vector3) -> AABB:
	return AABB(p - Vector3(PW * 0.5, 0, PW * 0.5), Vector3(PW, PH, PW))


static func spinner_angle(pc: Dictionary, t: float) -> float:
	return float(pc["per"]) * t


## La barra que gira toca al jugador.
static func spinner_hits(pc: Dictionary, p: Vector3, t: float) -> bool:
	var c: Vector3 = pc["c"]
	if c.y < p.y - 0.15 or c.y > p.y + PH:
		return false
	var a: float = spinner_angle(pc, t)
	var half: float = float((pc["s"] as Vector3).x) * 0.5
	var d: Vector2 = Vector2(cos(a), sin(a))
	var q: Vector2 = Vector2(p.x - c.x, p.z - c.z)
	var along: float = clampf(q.dot(d), -half, half)
	return (q - d * along).length() < PW * 0.5 + 0.15


static func _next_target_pos(pieces: Array, from: int, t: float) -> Vector3:
	var k: int = next_target(pieces, from)
	if k < 0:
		return Vector3.ZERO
	return center_at(pieces[k], t)


## La siguiente pieza donde se puede estar de pie despues de la pieza "from".
static func next_target(pieces: Array, from: int) -> int:
	for k: int in range(from + 1, pieces.size()):
		if STAND.contains(str(pieces[k]["k"])):
			return k
	return -1


static func _yaw_to(a: Vector3, b: Vector3) -> float:
	var d: Vector3 = b - a
	if Vector2(d.x, d.z).length() < 0.01:
		return 0.0
	return atan2(-d.x, -d.z)


## Un paso. inp = {"move": Vector2 (x derecha, y adelante, segun yaw), "jump": bool}.
static func step(st: Dictionary, inp: Dictionary, dt: float) -> void:
	if bool(st["won"]) or bool(st["dead"]):
		return
	var pieces: Array = st["pieces"]
	var t0: float = float(st["t"])
	var t1: float = t0 + dt
	st["t"] = t1
	var p: Vector3 = st["p"]
	var v: Vector3 = st["v"]
	## 1 - La plataforma de debajo te lleva con ella.
	var g: int = int(st["ground"])
	if bool(st["on_floor"]) and g >= 0 and g < pieces.size() and str(pieces[g]["k"]) == "M":
		p += center_at(pieces[g], t1) - center_at(pieces[g], t0)
	## 2 - Mando: andar relativo a la camara; en el aire se controla algo menos.
	var mv: Vector2 = inp.get("move", Vector2.ZERO)
	if mv.length() > 1.0:
		mv = mv.normalized()
	var yaw: float = float(st["yaw"])
	var fwd: Vector3 = Vector3(-sin(yaw), 0, -cos(yaw))
	var right: Vector3 = Vector3(cos(yaw), 0, -sin(yaw))
	var want: Vector3 = (right * mv.x + fwd * mv.y) * SPEED
	var k_ctl: float = 1.0 if bool(st["on_floor"]) else AIR
	v.x = lerpf(v.x, want.x, minf(1.0, 18.0 * k_ctl * dt))
	v.z = lerpf(v.z, want.z, minf(1.0, 18.0 * k_ctl * dt))
	st["coyote"] = COYOTE if bool(st["on_floor"]) else maxf(0.0, float(st["coyote"]) - dt)
	if bool(inp.get("jump", false)) and float(st["coyote"]) > 0.0 and not bool(st["jumped"]):
		v.y = JUMP
		st["coyote"] = 0.0
		st["jumped"] = true
		_ev(st, "jump")
	if not bool(inp.get("jump", false)):
		st["jumped"] = false
	v.y = maxf(v.y - GRAV * dt, -26.0)
	## 3 - Moverse eje a eje contra las plataformas solidas de ahora.
	var boxes: Array = []
	for pc: Dictionary in pieces:
		if solid_at(pc, t1):
			var bx: AABB = box_at(pc, t1)
			if bx.grow(4.0).has_point(p):
				boxes.append([bx, int(pc["i"])])
	var on_floor: bool = false
	var ground: int = -1
	var n: int = maxi(1, ceili(v.length() * dt / 0.2))
	var sdt: float = dt / float(n)
	for s: int in n:
		for axis: int in [0, 2, 1]:
			var np: Vector3 = p
			np[axis] += v[axis] * sdt
			var hit: Array = _hit(boxes, body(np))
			if hit.is_empty():
				p = np
				continue
			var hb: AABB = hit[0]
			if axis == 1:
				if v.y <= 0.0:
					p.y = hb.end.y
					on_floor = true
					ground = int(hit[1])
				else:
					p.y = hb.position.y - PH - 0.001
				v.y = 0.0
			else:
				## Un escaloncito (menos de 0,35) se sube solo.
				var up: Vector3 = np + Vector3(0, hb.end.y - np.y + 0.001, 0)
				if hb.end.y - p.y < 0.35 and hb.end.y - p.y > 0.0 and _hit(boxes, body(up)).is_empty():
					p = up
				else:
					v[axis] = 0.0
	## Sigue de pie si debajo hay suelo (al andar por el borde).
	if not on_floor and v.y <= 0.0:
		var below: Array = _hit(boxes, body(p - Vector3(0, 0.05, 0)))
		if not below.is_empty():
			on_floor = true
			ground = int(below[1])
	st["p"] = p
	st["v"] = v
	st["on_floor"] = on_floor
	st["ground"] = ground
	## 4 - Lo que pasa segun donde estas.
	if on_floor and ground >= 0:
		var gp: Dictionary = pieces[ground]
		var gk: String = gp["k"]
		if int(gp["i"]) > int(st["best"]):
			st["best"] = int(gp["i"])
		if gk == "J":
			v.y = PAD
			st["v"] = v
			st["on_floor"] = false
			st["coyote"] = 0.0
			_ev(st, "pad")
		elif gk == "C" and int(st["cp_i"]) < ground:
			st["cp_i"] = ground
			st["cp"] = center_at(gp, t1) + Vector3(0, (gp["s"] as Vector3).y * 0.5, 0)
			_ev(st, "checkpoint")
		elif gk == "G":
			st["won"] = true
			_ev(st, "win")
			return
	var bp: AABB = body(p)
	for pc2: Dictionary in pieces:
		var k2: String = pc2["k"]
		if k2 == "L" and box_at(pc2, t1).intersects(bp):
			_die(st)
			return
		if k2 == "S" and spinner_hits(pc2, p, t1):
			_die(st)
			return
		if k2 == "O" and not bool(st["sim"]) and not (st["got"] as Dictionary).has(int(pc2["i"])) and (pc2["c"] as Vector3).distance_to(p + Vector3(0, 0.8, 0)) < 1.0:
			(st["got"] as Dictionary)[int(pc2["i"])] = true
			_ev(st, "coin")
	if p.y < FALL_Y:
		_die(st)


static func _hit(boxes: Array, b: AABB) -> Array:
	for e: Array in boxes:
		if (e[0] as AABB).intersects(b):
			return e
	return []


static func _ev(st: Dictionary, kind: String) -> void:
	if not bool(st["sim"]):
		(st["events"] as Array).append(kind)


static func _die(st: Dictionary) -> void:
	st["dead"] = true
	_ev(st, "dead")


## Volver al ultimo punto de control (cuenta una caida).
static func respawn(st: Dictionary) -> void:
	st["deaths"] = int(st["deaths"]) + 1
	st["p"] = st["cp"]
	st["v"] = Vector3.ZERO
	st["dead"] = false
	st["on_floor"] = true
	st["ground"] = int(st["cp_i"])
	st["yaw"] = _yaw_to(st["p"], _next_target_pos(st["pieces"], int(st["cp_i"]), float(st["t"])))
	st["bot"] = {}


# ------------------------------------------------------------------ bot

## Copia ligera para simular el futuro (las piezas se comparten, no se tocan).
static func _sim_copy(st: Dictionary) -> Dictionary:
	var s: Dictionary = {}
	for k: String in ["pieces", "p", "v", "t", "on_floor", "ground", "coyote", "yaw", "cp", "cp_i", "dead", "won", "jumped", "best"]:
		s[k] = st[k]
	if st.has("wp"):
		s["wp"] = st["wp"]
	s["got"] = {}
	s["events"] = []
	s["sim"] = true
	return s


## Ir hacia la pieza "target" (donde este en cada instante); saltar a los "jump" s (o nunca si < 0).
static func _drive(s: Dictionary, target: int, run_t: float, jump_t: float, speed: float = 1.0) -> Dictionary:
	var pc: Dictionary = (s["pieces"] as Array)[target]
	var aim: Vector3 = center_at(pc, float(s["t"]))
	if s.has("wp"):
		aim = s["wp"]
	var to: Vector3 = aim - (s["p"] as Vector3)
	var flat: Vector2 = Vector2(to.x, to.z)
	if flat.length() > 0.05:
		s["yaw"] = atan2(-to.x, -to.z)
	var go: float = speed if flat.length() > 0.3 else minf(speed, flat.length() / 0.3)
	var jump: bool = jump_t >= 0.0 and run_t >= jump_t
	## Ademas salta solo al llegar al borde de donde esta o con lava justo delante.
	if run_t >= 0.0 and not jump and bool(s["on_floor"]) and flat.length() > 0.3:
		jump = _auto_jump(s, Vector3(to.x, 0, to.z).normalized(), target)
	return {"move": Vector2(0, go) if run_t >= 0.0 else Vector2.ZERO, "jump": jump}


static func _auto_jump(s: Dictionary, dir: Vector3, target: int) -> bool:
	var pieces: Array = s["pieces"]
	var g: int = int(s["ground"])
	if g < 0:
		return false
	var t: float = float(s["t"])
	var p: Vector3 = s["p"]
	var ahead: Vector3 = p + dir * 0.45
	var gb: AABB = box_at(pieces[g], t)
	if g != target and (ahead.x < gb.position.x or ahead.x > gb.end.x or ahead.z < gb.position.z or ahead.z > gb.end.z):
		return true
	var far: Vector3 = p + dir * 0.85
	for pc: Dictionary in pieces:
		if str(pc["k"]) == "L":
			var lb: AABB = box_at(pc, t)
			if lb.end.y >= p.y - 0.1 and lb.position.y <= p.y + 0.5 and far.x > lb.position.x - 0.3 and far.x < lb.end.x + 0.3 and far.z > lb.position.z - 0.3 and far.z < lb.end.z + 0.3:
				return true
	return false


## Busca cuanto esperar y cuando saltar para llegar de pie a "target" sin caer.
static func plan(st: Dictionary, target: int, dt: float) -> Dictionary:
	var waits: Array[float] = [0.0, 0.15, 0.3, 0.45, 0.6, 0.8, 1.0, 1.25, 1.5, 1.8, 2.2]
	var jumps: Array[float] = [-1.0, 0.0, 0.08, 0.16, 0.24, 0.32, 0.42, 0.55, 0.7, 0.9]
	var horizon: float = 3.2
	var tpc: Dictionary = (st["pieces"] as Array)[target]
	if str(tpc["k"]) == "J":
		horizon = 4.0
	for sp: float in [1.0, 0.55]:
		for w: float in waits:
			for j: float in jumps:
				var r: Dictionary = _try(st, target, dt, w, j, sp, horizon)
				if not r.is_empty():
					return r
	return {}


static func _try(st: Dictionary, target: int, dt: float, w: float, j: float, sp: float, horizon: float) -> Dictionary:
	var s: Dictionary = _sim_copy(st)
	var tt: float = 0.0
	while tt < w + horizon:
		step(s, _drive(s, target, tt - w, j, sp), dt)
		tt += dt
		if bool(s["dead"]):
			return {}
		var arrived: bool = bool(s["on_floor"]) and int(s["ground"]) >= target
		if s.has("wp"):
			var wp: Vector3 = s["wp"]
			arrived = bool(s["on_floor"]) and int(s["ground"]) == target and Vector2(wp.x - (s["p"] as Vector3).x, wp.z - (s["p"] as Vector3).z).length() < 0.8
		if bool(s["won"]) or arrived:
			if bool(s["won"]) or _survives(s, dt, 0.6):
				return {"wait": w, "jump": j, "target": target, "speed": sp}
			return {}
	return {}


## Tras llegar, quedarse quieto un momento no mata (no vale caer al lado de una barra o en una
## plataforma que se esta yendo).
static func _survives(s: Dictionary, dt: float, secs: float) -> bool:
	var tt: float = 0.0
	while tt < secs:
		step(s, {"move": Vector2.ZERO, "jump": false}, dt)
		tt += dt
		if bool(s["dead"]):
			return false
	return bool(s["on_floor"]) or bool(s["won"])


## El bot: en el suelo planifica el siguiente salto; luego lo ejecuta tal cual.
static func bot_control(st: Dictionary, dt: float, again: bool = true) -> Dictionary:
	var bot: Dictionary = st.get("bot", {})
	st["bot"] = bot
	if bool(st["dead"]) or bool(st["won"]):
		return {}
	var pieces: Array = st["pieces"]
	if float(st.get("bot_wait", 0.0)) > 0.0:
		st["bot_wait"] = float(st["bot_wait"]) - dt
		return {"move": Vector2.ZERO, "jump": false}
	if bot.is_empty():
		if not bool(st["on_floor"]):
			return {"move": Vector2.ZERO, "jump": false}
		var from: int = int(st["ground"])
		var target: int = next_target(pieces, from)
		if target < 0:
			return {}
		var pl: Dictionary = {}
		## En una plataforma con barra o lava por delante: primero cruzarla hasta su final.
		var wp: Vector3 = _waypoint(st, from, target)
		if wp != Vector3.INF:
			st["wp"] = wp
			pl = plan(st, from, dt)
			st.erase("wp")
			if not pl.is_empty():
				pl["wp"] = wp
		if pl.is_empty():
			pl = plan(st, target, dt)
		if pl.is_empty():
			## Sin plan seguro: probar con la siguiente pieza (a veces se salta una).
			var t2: int = next_target(pieces, target)
			if t2 >= 0:
				pl = plan(st, t2, dt)
		if pl.is_empty():
			st["bot_fail"] = int(st.get("bot_fail", 0)) + 1
			st["bot_wait"] = 0.3
			return {"move": Vector2.ZERO, "jump": false}
		bot.merge(pl)
		bot["tt"] = 0.0
	var tt: float = float(bot["tt"])
	## Plan cumplido (de pie donde tocaba): se planifica el siguiente en este mismo paso.
	var done: bool = bool(st["on_floor"]) and int(st["ground"]) >= int(bot["target"])
	if bot.has("wp"):
		var w: Vector3 = bot["wp"]
		done = bool(st["on_floor"]) and int(st["ground"]) == int(bot["target"]) and Vector2(w.x - (st["p"] as Vector3).x, w.z - (st["p"] as Vector3).z).length() < 0.8
	if (tt > float(bot["wait"]) + 0.05 and done) or tt > float(bot["wait"]) + 4.5:
		st["bot"] = {}
		if not again:
			return {"move": Vector2.ZERO, "jump": false}
		return bot_control(st, dt, false)
	if bot.has("wp"):
		st["wp"] = bot["wp"]
	var inp: Dictionary = _drive(st, int(bot["target"]), tt - float(bot["wait"]), float(bot["jump"]), float(bot.get("speed", 1.0)))
	st.erase("wp")
	bot["tt"] = tt + dt
	return inp


## Punto al final de la plataforma donde estas si en ella hay una barra o lava por delante.
static func _waypoint(st: Dictionary, g: int, target: int) -> Vector3:
	var pieces: Array = st["pieces"]
	if g < 0 or target < 0:
		return Vector3.INF
	var t: float = float(st["t"])
	var gb: AABB = box_at(pieces[g], t)
	var p: Vector3 = st["p"]
	var tc: Vector3 = center_at(pieces[target], t)
	var hazard: bool = false
	for pc: Dictionary in pieces:
		var k: String = pc["k"]
		if k != "S" and k != "L":
			continue
		var c: Vector3 = center_at(pc, t)
		if c.x > gb.position.x - 0.2 and c.x < gb.end.x + 0.2 and c.z > gb.position.z - 0.2 and c.z < gb.end.z + 0.2 and c.y > gb.end.y - 0.3 and c.y < gb.end.y + 1.5:
			if Vector2(c.x - tc.x, c.z - tc.z).length() < Vector2(p.x - tc.x, p.z - tc.z).length():
				hazard = true
	if not hazard:
		return Vector3.INF
	var wp: Vector3 = Vector3(clampf(tc.x, gb.position.x + 0.7, gb.end.x - 0.7), gb.end.y, clampf(tc.z, gb.position.z + 0.7, gb.end.z - 0.7))
	if Vector2(wp.x - p.x, wp.z - p.z).length() < 1.0:
		return Vector3.INF
	return wp


static func bot_play(level: Dictionary, dt: float = 1.0 / 30.0, limit: float = 400.0) -> Dictionary:
	var st: Dictionary = new_state(level)
	while not bool(st["won"]) and float(st["t"]) < limit:
		var inp: Dictionary = bot_control(st, dt)
		step(st, inp, dt)
		(st["events"] as Array).clear()
		if bool(st["dead"]):
			if int(st["deaths"]) >= 4:
				break
			respawn(st)
		if int(st.get("bot_fail", 0)) > 12:
			break
	var stuck: String = ""
	if not bool(st["won"]):
		var b: int = int(st["best"])
		var nt: int = next_target(st["pieces"], b)
		stuck = str((st["pieces"] as Array)[nt]["k"]) + str(nt) if nt >= 0 else "?"
	return {"won": bool(st["won"]), "time": float(st["t"]), "deaths": int(st["deaths"]), "stuck": stuck}


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var pieces: Array = parse(level)
	if pieces.size() < 3:
		issues.append("obby_short")
	elif str(pieces[0]["k"]) not in ["P", "C"]:
		issues.append("obby_start")
	var goals: int = 0
	for pc: Dictionary in pieces:
		if str(pc["k"]) == "G":
			goals += 1
	if goals != 1:
		issues.append("obby_goal")
	var par: int = 0
	var coins: int = 0
	if issues.is_empty():
		var r: Dictionary = bot_play(level)
		if not bool(r["won"]) or int(r["deaths"]) > 1:
			issues.append("obby_too_hard")
		par = int(float(r["time"]) * 1.6) + 10
		coins = int(new_state(level)["coins_total"])
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": coins, "enemies": 0, "enemy_problems": [], "par": par}
