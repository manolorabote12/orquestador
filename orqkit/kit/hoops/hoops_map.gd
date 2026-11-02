extends RefCounted
## Canasta (estilo Basketball / Flick shot): reglas, vuelo del balon, bot y analizador.
## 1 - Mapa (game.json -> levels[i].map): una letra por tiro, en una o varias filas:
##     "." canasta quieta, "m" canasta que se mueve a los lados, "f" lanzamiento desde lejos
##     (el balon sale de una esquina), "w" con viento.
## 2 - Se lanza deslizando hacia arriba: la direccion y lo largo del gesto dan la velocidad.
## 3 - Canasta si el balon baja por dentro del aro. Se gana con "goal" canastas.
## Parametros: "goal", "seed" y "wind" (empuje lateral en los tiros "w").

const G: float = 2400.0
const HOOP_Y: float = 400.0
const RIM: float = 62.0
const BALL_R: float = 30.0
const START: Vector2 = Vector2(360, 1080)
const SPEED_K: float = 3.4


static func shots_of(level: Dictionary) -> Array:
	var out: Array = []
	for r: Variant in level.get("map", []):
		var s: String = str(r)
		for i: int in s.length():
			if s[i] in [".", "m", "f", "w"]:
				out.append(s[i])
	return out


static func new_state(level: Dictionary) -> Dictionary:
	return {"shots": shots_of(level), "i": 0, "made": 0, "streak": 0, "points": 0, "goal": int(level.get("goal", 3)),
		"seed": int(level.get("seed", 1)), "wind": float(level.get("wind", 260.0)), "time": 0.0, "results": [], "done": false}


static func current(st: Dictionary) -> String:
	return str(st["shots"][int(st["i"])]) if int(st["i"]) < (st["shots"] as Array).size() else ""


static func start_of(st: Dictionary) -> Vector2:
	if current(st) == "f":
		return Vector2(140.0 if int(st["i"]) % 2 == 0 else 580.0, 1100.0)
	return START


## Donde esta el aro en el instante t (los "m" van y vienen).
static func hoop_x(st: Dictionary, t: float) -> float:
	if current(st) != "m":
		return 360.0
	return 360.0 + sin(t * 1.6 + float(int(st["i"]))) * 170.0


static func wind_of(st: Dictionary) -> float:
	if current(st) != "w":
		return 0.0
	return float(st["wind"]) * (1.0 if int(st["i"]) % 2 == 0 else -1.0)


static func velocity_of(swipe: Vector2) -> Vector2:
	return (swipe * SPEED_K).limit_length(2600.0)


## Vuelo del balon: devuelve "in", "rim" o "miss" y el instante en que cruza la altura del aro.
static func fly(st: Dictionary, v: Vector2, t0: float) -> Dictionary:
	var p: Vector2 = start_of(st)
	var vel: Vector2 = v
	var wind: float = wind_of(st)
	var dt: float = 1.0 / 120.0
	var t: float = 0.0
	var peaked: bool = false
	while t < 3.0:
		vel.y += G * dt
		vel.x += wind * dt
		var prev: Vector2 = p
		p += vel * dt
		t += dt
		if vel.y > 0.0:
			peaked = true
		if peaked and prev.y < HOOP_Y and p.y >= HOOP_Y:
			var f: float = (HOOP_Y - prev.y) / maxf(0.001, p.y - prev.y)
			var x: float = lerpf(prev.x, p.x, f)
			var hx: float = hoop_x(st, t0 + t)
			var dx: float = absf(x - hx)
			if dx <= RIM - BALL_R * 0.6:
				return {"res": "in", "t": t, "x": x}
			if dx <= RIM + BALL_R:
				return {"res": "rim", "t": t, "x": x}
			return {"res": "miss", "t": t, "x": x}
		if p.y > 1400.0:
			break
	return {"res": "miss", "t": t, "x": p.x, "short": true}


static func shoot(st: Dictionary, v: Vector2) -> Dictionary:
	if bool(st["done"]):
		return {}
	var r: Dictionary = fly(st, v, float(st["time"]))
	var res: String = str(r["res"])
	if res == "rim":
		## Al aro: entra o sale segun la semilla (la mitad de las veces).
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = int(st["seed"]) * 7919 + int(st["i"]) * 31
		res = "in" if rng.randf() < 0.5 else "miss"
		r["rim"] = true
	r["res"] = res
	if res == "in":
		st["made"] = int(st["made"]) + 1
		st["streak"] = int(st["streak"]) + 1
		st["points"] = int(st["points"]) + (3 if current(st) == "f" else 2) + (1 if int(st["streak"]) >= 3 else 0)
	else:
		st["streak"] = 0
	(st["results"] as Array).append(res)
	st["i"] = int(st["i"]) + 1
	var left: int = (st["shots"] as Array).size() - int(st["i"])
	if int(st["made"]) >= int(st["goal"]) or int(st["made"]) + left < int(st["goal"]) or left == 0:
		st["done"] = true
	return r


static func won(st: Dictionary) -> bool:
	return int(st["made"]) >= int(st["goal"])


## El bot busca el gesto que mete el balon por el centro (adelantandose si el aro se mueve) y
## le pone un error de mano humano que sale de la semilla.
static func bot_swipe(st: Dictionary, t0: float) -> Vector2:
	var best: Vector2 = Vector2(0, -600)
	var best_e: float = INF
	for vy_i: int in range(18, 26):
		var vy: float = -float(vy_i) * 100.0
		for vx_i: int in range(-24, 25):
			var vx: float = float(vx_i) * 25.0
			var r: Dictionary = fly(st, Vector2(vx, vy), t0)
			if r.has("short"):
				continue
			if str(r["res"]) == "miss" and absf(float(r["x"]) - hoop_x(st, t0 + float(r["t"]))) > RIM * 2.0:
				continue
			var e: float = absf(float(r["x"]) - hoop_x(st, t0 + float(r["t"])))
			if e < best_e:
				best_e = e
				best = Vector2(vx, vy)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(st["seed"]) * 104729 + int(st["i"]) * 13
	var err: Vector2 = Vector2(rng.randfn(0.0, 40.0), rng.randfn(0.0, 30.0))
	return (best + err) / SPEED_K


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var shots: Array = shots_of(level)
	if shots.size() < 3 or shots.size() > 15:
		issues.append("hoops_shots")
	var goal: int = int(level.get("goal", 3))
	if goal < 1 or goal > shots.size():
		issues.append("hoops_goal")
	var par: int = 0
	if issues.is_empty():
		var st: Dictionary = new_state(level)
		while not bool(st["done"]):
			shoot(st, velocity_of(bot_swipe(st, float(st["time"]))))
			st["time"] = float(st["time"]) + 2.2
		if not won(st):
			issues.append("hoops_too_hard")
		par = int(st["i"])
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": goal, "enemies": 0, "enemy_problems": [], "par": par}
