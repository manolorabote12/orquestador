extends RefCounted
## Escalada (estilo Hill Climb Racing): fisica propia del vehiculo, bot y analizador.
## Fisica propia (no la de Godot) para que el juego, el bot y el analizador hagan exactamente lo
## mismo con los mismos mandos. Metros, y hacia arriba, x hacia la meta.
## 1 - Mapa (game.json -> levels[i].map): "T:h,h,h..." alturas del suelo cada STEP metros (varias
##     filas "T:" se encadenan), "F:x,x" bidones de gasolina, "C:x,x" monedas. "#semilla".
## 2 - Coche: chasis rigido con dos ruedas de suspension (muelle y amortiguador), traccion a las
##     dos ruedas limitada por el agarre, gas y freno (que da marcha atras parado). En el aire, el
##     gas lo inclina hacia atras y el freno hacia delante.
## 3 - Se pierde si la cabeza del conductor toca el suelo (vuelco) o si se acaba la gasolina y el
##     coche se para. Se gana al llegar a la meta ("goal" metros).
## 4 - Mejoras (taller, Save.upgrade_level): motor, suspension, ruedas y deposito. El analizador
##     juega sin ninguna: todos los niveles se pueden pasar sin comprar nada.
## Parametros: "goal" (metros), "fuel_rate" (gasolina por segundo), "par" (segundos).

const STEP: float = 4.0
const DT: float = 1.0 / 120.0
const G: float = 12.0
const MASS: float = 1.0
const INERTIA: float = 1.5
const WHEEL_R: float = 0.42
const REST: float = 0.52
const MOUNTS: Array[Vector2] = [Vector2(-1.05, -0.3), Vector2(1.05, -0.3)]
const HEAD: Vector2 = Vector2(-0.15, 0.85)
const CORNERS: Array[Vector2] = [Vector2(-1.35, -0.1), Vector2(1.35, -0.1), Vector2(-1.2, 0.45), Vector2(1.1, 0.4)]
const FUEL_MAX: float = 100.0


static func parse(level: Dictionary) -> Dictionary:
	var hs: Array[float] = []
	var fuel: Array[float] = []
	var coins: Array[float] = []
	var seed_v: int = int(level.get("seed", 1))
	for r: Variant in level.get("map", []):
		var row: String = str(r)
		if row.begins_with("#") and row.substr(1).is_valid_int():
			seed_v = int(row.substr(1))
			continue
		var body: String = row.substr(2)
		for v: String in body.split(",", false):
			if not v.strip_edges().is_valid_float():
				continue
			if row.begins_with("T:"):
				hs.append(float(v))
			elif row.begins_with("F:"):
				fuel.append(float(v))
			elif row.begins_with("C:"):
				coins.append(float(v))
	var fallback: bool = hs.size() < 20
	if fallback:
		hs.clear()
		for k: int in 60:
			hs.append(sin(float(k) * 0.3) * 2.0)
	var length: float = float(hs.size() - 1) * STEP
	var goal: float = clampf(float(level.get("goal", length - 20.0)), 40.0, length - 10.0)
	return {"h": hs, "fuel": fuel, "coins": coins, "seed": seed_v, "length": length, "goal": goal, "fallback": fallback}


## Altura del suelo en x: curva de Catmull-Rom por los puntos (suave y sin escalones).
static func ground(info: Dictionary, x: float) -> float:
	var hs: Array = info["h"]
	var last: int = hs.size() - 1
	var fx: float = clampf(x / STEP, 0.0, float(last) - 0.0001)
	var i: int = int(fx)
	var t: float = fx - float(i)
	var p0: float = float(hs[maxi(i - 1, 0)])
	var p1: float = float(hs[i])
	var p2: float = float(hs[mini(i + 1, last)])
	var p3: float = float(hs[mini(i + 2, last)])
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t)


static func normal(info: Dictionary, x: float) -> Vector2:
	var d: float = (ground(info, x + 0.1) - ground(info, x - 0.1)) / 0.2
	return Vector2(-d, 1.0).normalized()


## Mejoras: 0-4 cada una (las da el taller; el analizador usa 0).
static func new_state(level: Dictionary, ups: Dictionary = {}) -> Dictionary:
	var info: Dictionary = parse(level)
	var x0: float = 6.0
	var y0: float = ground(info, x0) + REST + WHEEL_R + 0.35
	var tank: float = FUEL_MAX * (1.0 + 0.25 * float(ups.get("deposito", 0)))
	return {"info": info, "p": Vector2(x0, y0), "a": 0.0, "v": Vector2.ZERO, "w": 0.0, "wheel_rot": [0.0, 0.0],
		"comp": [0.0, 0.0], "touch": [false, false], "fuel": tank, "tank": tank, "t": 0.0, "over": false, "won": false,
		"cause": "", "coins_got": [], "fuel_got": [], "events": [], "stuck_t": 0.0, "air_t": 0.0, "best_x": x0, "flips": 0,
		"rot_acc": 0.0, "engine": 15.0 * (1.0 + 0.12 * float(ups.get("motor", 0))), "vmax": 21.0 * (1.0 + 0.08 * float(ups.get("motor", 0))),
		"k": 260.0 * (1.0 + 0.1 * float(ups.get("suspension", 0))), "c": 20.0 * (1.0 + 0.1 * float(ups.get("suspension", 0))),
		"mu": 1.15 * (1.0 + 0.1 * float(ups.get("ruedas", 0))), "fuel_rate": clampf(float(level.get("fuel_rate", 1.25)), 0.3, 4.0)}


static func _ev(st: Dictionary, kind: String, extra: Dictionary = {}) -> void:
	var e: Dictionary = {"kind": kind}
	e.merge(extra)
	(st["events"] as Array).append(e)


static func to_world(st: Dictionary, local: Vector2) -> Vector2:
	return (st["p"] as Vector2) + local.rotated(float(st["a"]))


static func _point_vel(st: Dictionary, wp: Vector2) -> Vector2:
	var r: Vector2 = wp - (st["p"] as Vector2)
	return (st["v"] as Vector2) + Vector2(-float(st["w"]) * r.y, float(st["w"]) * r.x)


## Un paso de fisica con los mandos (gas, freno). Se llama con DT fijo.
static func step(st: Dictionary, gas: bool, brake: bool) -> void:
	if bool(st["over"]):
		return
	var info: Dictionary = st["info"]
	var force: Vector2 = Vector2(0.0, -G * MASS)
	var torque: float = 0.0
	var p: Vector2 = st["p"]
	var a: float = float(st["a"])
	var has_fuel: bool = float(st["fuel"]) > 0.0
	var drive: float = 0.0
	if has_fuel and gas:
		drive = 1.0
	elif brake:
		drive = -1.0
	var any_touch: bool = false
	var down: Vector2 = Vector2(0, -1).rotated(a)
	for i: int in 2:
		var mount: Vector2 = to_world(st, MOUNTS[i])
		var c: Vector2 = mount + down * REST
		var n: Vector2 = normal(info, c.x)
		var dist: float = (c.y - ground(info, c.x)) * n.y
		var pen: float = WHEEL_R - dist
		st["touch"][i] = pen > 0.0
		st["comp"][i] = clampf(pen, 0.0, REST)
		if pen <= 0.0:
			continue
		any_touch = true
		pen = minf(pen, REST + 0.2)
		var contact: Vector2 = c - n * dist
		var vel: Vector2 = _point_vel(st, contact)
		var vn: float = vel.dot(n)
		var fs: float = maxf(0.0, float(st["k"]) * pen - float(st["c"]) * vn)
		var t: Vector2 = Vector2(n.y, -n.x)
		var vt: float = vel.dot(t)
		## Traccion: el motor empuja menos cuanto mas rapido va; el freno frena y luego da marcha atras.
		var ft: float = 0.0
		if drive > 0.0:
			ft = float(st["engine"]) * 0.5 * clampf(1.0 - vt / float(st["vmax"]), 0.0, 1.0)
		elif drive < 0.0:
			if vt > 0.6:
				ft = -float(st["engine"]) * 0.6
			else:
				ft = -float(st["engine"]) * 0.25 * clampf(1.0 + vt / 5.0, 0.0, 1.0)
		## Rodando sin pisar: se frena poco a poco (resistencia), sin patinar.
		ft -= vt * 0.12
		var lim: float = float(st["mu"]) * fs
		ft = clampf(ft, -lim, lim)
		var f: Vector2 = n * fs + t * ft
		force += f
		## La traccion empuja casi a la altura del eje (asi el coche no hace el caballito con nada).
		var r: Vector2 = contact - p
		var r_drive: Vector2 = contact + n * WHEEL_R * 0.8 - p
		var fn: Vector2 = n * fs
		var fd: Vector2 = t * ft
		torque += (r.x * fn.y - r.y * fn.x) + (r_drive.x * fd.y - r_drive.y * fd.x)
		st["wheel_rot"][i] = float(st["wheel_rot"][i]) + vt / WHEEL_R * DT
	## La carroceria tampoco atraviesa el suelo (cae de lado o de techo).
	for cl: Vector2 in CORNERS:
		var wp: Vector2 = to_world(st, cl)
		var gy: float = ground(info, wp.x)
		if wp.y < gy:
			var n2: Vector2 = normal(info, wp.x)
			var vel2: Vector2 = _point_vel(st, wp)
			var f2: Vector2 = n2 * maxf(0.0, 400.0 * (gy - wp.y) - 25.0 * vel2.dot(n2)) - Vector2(n2.y, -n2.x) * vel2.dot(Vector2(n2.y, -n2.x)) * 2.0
			force += f2
			var r2: Vector2 = wp - p
			torque += r2.x * f2.y - r2.y * f2.x
	## En el aire: gas = morro arriba, freno = morro abajo.
	if not any_touch:
		st["air_t"] = float(st["air_t"]) + DT
		if drive > 0.0:
			torque += 4.2
		elif drive < 0.0:
			torque -= 4.2
	else:
		## Con ruedas en el suelo el motor tambien tira del chasis hacia atras (y el freno, hacia
		## delante), como en los juegos de este tipo: con gas se levanta el morro.
		torque += 1.6 * drive
		st["w"] = float(st["w"]) * 0.995
		if float(st["air_t"]) > 1.2:
			_ev(st, "air", {"t": float(st["air_t"])})
		st["air_t"] = 0.0
	st["v"] = (st["v"] as Vector2) + force / MASS * DT
	st["w"] = (float(st["w"]) + torque / INERTIA * DT) * 0.998
	st["p"] = (st["p"] as Vector2) + (st["v"] as Vector2) * DT
	var da: float = float(st["w"]) * DT
	st["a"] = wrapf(a + da, -PI, PI)
	## Vueltas en el aire (premio): se cuentan al aterrizar.
	if not any_touch:
		st["rot_acc"] = float(st["rot_acc"]) + da
	else:
		var turns: int = int(absf(float(st["rot_acc"])) / (TAU * 0.9))
		if turns > 0:
			st["flips"] = int(st["flips"]) + turns
			_ev(st, "flip", {"n": turns})
		st["rot_acc"] = 0.0
	st["t"] = float(st["t"]) + DT
	if gas and has_fuel or (st["v"] as Vector2).length() > 0.5:
		st["fuel"] = maxf(0.0, float(st["fuel"]) - float(st["fuel_rate"]) * DT)
	_pickups(st)
	_check(st)


static func _pickups(st: Dictionary) -> void:
	var info: Dictionary = st["info"]
	var x: float = (st["p"] as Vector2).x
	for i: int in (info["fuel"] as Array).size():
		var fx: float = float(info["fuel"][i])
		if not (st["fuel_got"] as Array).has(i) and absf(fx - x) < 1.4 and absf(ground(info, fx) + 1.0 - (st["p"] as Vector2).y) < 2.6:
			st["fuel_got"].append(i)
			st["fuel"] = float(st["tank"])
			_ev(st, "fuel", {"i": i})
	for j: int in (info["coins"] as Array).size():
		var cx: float = float(info["coins"][j])
		if not (st["coins_got"] as Array).has(j) and absf(cx - x) < 1.3 and absf(ground(info, cx) + 1.1 - (st["p"] as Vector2).y) < 2.4:
			st["coins_got"].append(j)
			_ev(st, "coin", {"i": j})


static func _check(st: Dictionary) -> void:
	var info: Dictionary = st["info"]
	var head: Vector2 = to_world(st, HEAD)
	if head.y < ground(info, head.x) + 0.12:
		_end(st, false, "crash")
		return
	var p: Vector2 = st["p"]
	if p.x >= float(info["goal"]):
		_end(st, true, "goal")
		return
	if p.x > float(st["best_x"]) + 0.5:
		st["best_x"] = p.x
		st["stuck_t"] = 0.0
	else:
		st["stuck_t"] = float(st["stuck_t"]) + DT
	## Sin gasolina y parado (o sin avanzar 8 s), se acabo.
	if float(st["fuel"]) <= 0.0 and (st["v"] as Vector2).length() < 0.3 and float(st["stuck_t"]) > 1.5:
		_end(st, false, "fuel")
	elif float(st["stuck_t"]) > 25.0:
		_end(st, false, "stuck")
	elif p.y < -200.0 or p.x < -5.0:
		_end(st, false, "crash")


static func _end(st: Dictionary, won: bool, cause: String) -> void:
	st["over"] = true
	st["won"] = won
	st["cause"] = cause
	_ev(st, "end", {"won": won, "cause": cause})


# ------------------------------------------------------------------ bot

## Un conductor prudente: gas casi siempre; suelta o frena si el morro sube demasiado o va muy
## rapido cuesta abajo; en el aire endereza el coche para caer con las dos ruedas.
## "nerve" (0-1) cambia un poco los limites: el analizador prueba tres conductores distintos.
static func bot_input(st: Dictionary, nerve: float = 0.5) -> Array:
	var info: Dictionary = st["info"]
	var a: float = float(st["a"])
	var p: Vector2 = st["p"]
	var touching: bool = bool(st["touch"][0]) or bool(st["touch"][1])
	if not touching:
		## En el aire: igualar el angulo con la pendiente de donde va a caer.
		var land_x: float = p.x + (st["v"] as Vector2).x * 0.5
		var slope: float = atan2(ground(info, land_x + 1.0) - ground(info, land_x - 1.0), 2.0)
		var err: float = a - slope
		var spin: float = float(st["w"])
		if err + spin * 0.25 > 0.12:
			return [false, true]
		if err + spin * 0.25 < -0.12:
			return [true, false]
		return [false, false]
	var slope2: float = atan2(ground(info, p.x + 1.5) - ground(info, p.x - 1.5), 3.0)
	var rel: float = a - slope2
	var limit: float = 0.42 + 0.18 * nerve
	if a > 0.95 + 0.15 * nerve or rel > limit or float(st["w"]) > 1.6:
		## Caballito: suelta el gas; solo frena si ya va a volcar.
		return [false, rel > limit + 0.4 or a > 1.3]
	var speed: float = (st["v"] as Vector2).x
	## Cuesta abajo muy rapido: frena solo con las dos ruedas en el suelo (frenar con una levanta
	## la otra y clava el morro).
	if slope2 < -0.25 and speed > 9.0 + 4.0 * nerve:
		return [false, bool(st["touch"][0]) and bool(st["touch"][1]) and rel > -0.2]
	if rel < -0.5:
		return [true, false]
	return [true, false]


static func bot_play(level: Dictionary, nerve: float = 0.5, max_t: float = 400.0) -> Dictionary:
	var st: Dictionary = new_state(level)
	while not bool(st["over"]) and float(st["t"]) < max_t:
		var inp: Array = bot_input(st, nerve)
		step(st, bool(inp[0]), bool(inp[1]))
		(st["events"] as Array).clear()
	return {"won": bool(st["won"]), "cause": str(st["cause"]), "t": float(st["t"]), "x": (st["p"] as Vector2).x,
		"fuel": float(st["fuel"]), "coins": (st["coins_got"] as Array).size()}


# ------------------------------------------------------------------ analizador

static func analyze(level: Dictionary) -> Dictionary:
	var info: Dictionary = parse(level)
	var issues: Array[String] = []
	if bool(info["fallback"]):
		issues.append("climb_no_terrain")
	## Sin cuestas imposibles: pendiente maxima de un tramo.
	var hs: Array = info["h"]
	for i: int in range(1, hs.size()):
		if absf(float(hs[i]) - float(hs[i - 1])) / STEP > 1.25:
			issues.append("climb_wall")
			break
	var wins: int = 0
	var times: Array[float] = []
	var causes: Array[String] = []
	if issues.is_empty():
		for nerve: float in [0.2, 0.5, 0.8]:
			var r: Dictionary = bot_play(level, nerve)
			causes.append(str(r["cause"]))
			if bool(r["won"]):
				wins += 1
				times.append(float(r["t"]))
		if wins < 2:
			issues.append("climb_too_hard")
	var par: int = int(times.min() * 1.25) + 5 if not times.is_empty() else 120
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": (info["coins"] as Array).size(), "enemies": 0,
		"enemy_problems": [], "par": par, "wins": wins, "causes": causes}
