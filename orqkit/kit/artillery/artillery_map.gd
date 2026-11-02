extends RefCounted
## Artilleria por turnos (tipo Worms): dos equipos sobre un terreno que se rompe. En tu turno
## mueves al soldado que toca (un poco) y disparas el bazuca eligiendo angulo y fuerza; el viento
## desvia el proyectil. La explosion hace un crater y quita vida a todos los que pille (tambien a
## los tuyos). Si el suelo bajo un soldado cae al agua, se ahoga. Gana el equipo que quede.
## Nivel: "ground" (alturas de cada columna, 0..H), "team" y "foes" (columnas de cada soldado),
## "hp", "wind" (viento maximo), "ai" (punteria del rival, 0..1), "seed".

const Rules = preload("res://kit/rules.gd")
const W: int = 120
const H: int = 160
const GRAV: float = 60.0
const VMAX: float = 96.0
const STEP: float = 0.04
const CRATER: float = 7.0
const BLAST: float = 11.0
const DMG: float = 50.0
const WALK: int = 14
const CLIMB: int = 3
const SUDDEN: int = 24


static func new_state(level: Dictionary) -> Dictionary:
	var ground: Array = []
	for v: Variant in level.get("ground", []):
		ground.append(float(v))
	while ground.size() < W:
		ground.append(40.0)
	var units: Array = []
	var hp: int = int(level.get("hp", 100))
	for x: Variant in level.get("team", [20, 32]):
		units.append({"team": 1, "x": int(x), "hp": hp, "max": hp, "alive": true})
	for x2: Variant in level.get("foes", [88, 100]):
		units.append({"team": 2, "x": int(x2), "hp": int(level.get("foe_hp", hp)), "max": int(level.get("foe_hp", hp)), "alive": true})
	var st: Dictionary = {"ground": ground, "units": units, "turn": 0, "side": 1, "cur": {1: -1, 2: -1}, "active": -1,
		"wind": 0.0, "wind_max": float(level.get("wind", 10.0)), "ai": float(level.get("ai", 0.5)), "water": 3.0,
		"walk_left": WALK, "won": false, "lost": false, "log": [], "rng": int(level.get("seed", 7)) * 7919 + 13, "shots": 0}
	st["rules"] = Rules.load_rules(level)
	Rules.hook(st, "on_start")
	_next_unit(st)
	return st


static func _rand(st: Dictionary) -> float:
	st["rng"] = (int(st["rng"]) * 1103515245 + 12345) % 2147483648
	return float(int(st["rng"]) % 100000) / 100000.0


static func height(st: Dictionary, x: float) -> float:
	var i: int = clampi(int(floor(x)), 0, W - 1)
	return float(st["ground"][i])


static func unit_pos(st: Dictionary, u: Dictionary) -> Vector2:
	return Vector2(float(u["x"]) + 0.5, height(st, float(u["x"])))


static func alive(st: Dictionary, team: int) -> Array:
	var out: Array = []
	for u: Variant in st["units"]:
		if bool(u["alive"]) and int(u["team"]) == team:
			out.append(u)
	return out


static func active_unit(st: Dictionary) -> Dictionary:
	var i: int = int(st["active"])
	return st["units"][i] if i >= 0 else {}


## Pasa al siguiente soldado vivo del equipo al que le toca.
static func _next_unit(st: Dictionary) -> void:
	var side: int = int(st["side"])
	var units: Array = st["units"]
	var start: int = int(st["cur"][side])
	for k: int in units.size():
		var i: int = (start + 1 + k) % units.size()
		if bool(units[i]["alive"]) and int(units[i]["team"]) == side:
			st["cur"][side] = i
			st["active"] = i
			break
	st["walk_left"] = WALK
	st["wind"] = snappedf((_rand(st) * 2.0 - 1.0) * float(st["wind_max"]), 0.5)


## Un paso del soldado activo (dir -1 o 1). Sube escalones pequenos; caer mucho hace dano.
static func walk(st: Dictionary, dir: int) -> bool:
	if bool(st["won"]) or bool(st["lost"]) or int(st["walk_left"]) <= 0:
		return false
	var u: Dictionary = active_unit(st)
	var nx: int = int(u["x"]) + signi(dir)
	if nx < 1 or nx > W - 2:
		return false
	var dh: float = height(st, nx) - height(st, int(u["x"]))
	if dh > CLIMB:
		return false
	for o: Variant in st["units"]:
		if o != u and bool(o["alive"]) and int(o["x"]) == nx:
			return false
	u["x"] = nx
	st["walk_left"] = int(st["walk_left"]) - 1
	if dh < -12.0:
		_hurt(st, u, int((-dh - 12.0) * 2.0))
	_settle(st)
	return true


## Trayectoria de un disparo (no cambia nada). angle en grados (0 derecha, 90 arriba), power 0..1.
static func simulate(st: Dictionary, from: Vector2, angle: float, power: float, wind: float) -> Dictionary:
	var a: float = deg_to_rad(angle)
	var v: Vector2 = Vector2(cos(a), sin(a)) * clampf(power, 0.05, 1.0) * VMAX
	var p: Vector2 = from + Vector2(0, 3.0)
	var path: Array = [p]
	var me: Dictionary = active_unit(st)
	for i: int in 400:
		v.x += wind * STEP
		v.y -= GRAV * STEP
		p += v * STEP
		if i % 2 == 0:
			path.append(p)
		if p.x < 0.0 or p.x >= float(W):
			return {"end": p, "hit": "out", "path": path}
		if p.y <= float(st["water"]):
			return {"end": p, "hit": "water", "path": path}
		if p.y <= height(st, p.x):
			return {"end": Vector2(p.x, height(st, p.x)), "hit": "ground", "path": path}
		if i > 3:
			for u: Variant in st["units"]:
				if bool(u["alive"]) and (u != me or i > 12) and p.distance_to(unit_pos(st, u) + Vector2(0, 2.0)) < 2.6:
					return {"end": p, "hit": "unit", "path": path}
	return {"end": p, "hit": "out", "path": path}


## Dano que haria una explosion en at a cada soldado (indice -> dano).
static func blast_damage(st: Dictionary, at: Vector2) -> Dictionary:
	var out: Dictionary = {}
	for i: int in (st["units"] as Array).size():
		var u: Dictionary = st["units"][i]
		if not bool(u["alive"]):
			continue
		var d: float = at.distance_to(unit_pos(st, u) + Vector2(0, 2.0))
		if d < BLAST:
			out[i] = int(round(DMG * (1.0 - d / BLAST) + 8.0))
	return out


## Dispara el soldado activo y pasa el turno. Devuelve la trayectoria para la animacion.
static func fire(st: Dictionary, angle: float, power: float) -> Dictionary:
	if bool(st["won"]) or bool(st["lost"]):
		return {}
	var u: Dictionary = active_unit(st)
	var shot: Dictionary = simulate(st, unit_pos(st, u), angle, power, float(st["wind"]))
	st["shots"] = int(st["shots"]) + 1
	Rules.hook(st, "on_fire", [int(st["side"])])
	var hits: Dictionary = {}
	if str(shot["hit"]) == "ground" or str(shot["hit"]) == "unit":
		var at: Vector2 = shot["end"]
		hits = blast_damage(st, at)
		_crater(st, at)
		(st["log"] as Array).append({"k": "boom", "at": at})
		for i: Variant in hits:
			_hurt(st, st["units"][int(i)], int(hits[i]))
	else:
		(st["log"] as Array).append({"k": "splash", "at": shot["end"]})
	_settle(st)
	shot["hits"] = hits
	_end_turn(st)
	return shot


static func _crater(st: Dictionary, at: Vector2) -> void:
	var g: Array = st["ground"]
	for x: int in range(maxi(0, int(at.x - CRATER) - 1), mini(W, int(at.x + CRATER) + 2)):
		var dx: float = float(x) + 0.5 - at.x
		if absf(dx) >= CRATER:
			continue
		var s: float = sqrt(CRATER * CRATER - dx * dx)
		if float(g[x]) > at.y - s:
			g[x] = maxf(0.0, minf(float(g[x]), at.y - s))


static func _hurt(st: Dictionary, u: Dictionary, n: int) -> void:
	if not bool(u["alive"]) or n <= 0:
		return
	u["hp"] = maxi(0, int(u["hp"]) - n)
	(st["log"] as Array).append({"k": "hit", "at": unit_pos(st, u), "n": n, "team": int(u["team"])})
	if int(u["hp"]) <= 0:
		_kill(st, u)


static func _kill(st: Dictionary, u: Dictionary) -> void:
	u["alive"] = false
	(st["log"] as Array).append({"k": "kill", "at": unit_pos(st, u), "team": int(u["team"])})
	Rules.hook(st, "on_kill", [int(u["team"])])


## Los que se quedan sin suelo (agua) se ahogan; mira si alguien ha ganado.
static func _settle(st: Dictionary) -> void:
	for u: Variant in st["units"]:
		if bool(u["alive"]) and height(st, float(u["x"])) <= float(st["water"]):
			(st["log"] as Array).append({"k": "drown", "at": unit_pos(st, u), "team": int(u["team"])})
			_kill(st, u)
	if alive(st, 2).is_empty():
		st["won"] = true
	elif alive(st, 1).is_empty():
		st["lost"] = true


static func _end_turn(st: Dictionary) -> void:
	if bool(st["won"]) or bool(st["lost"]):
		return
	st["turn"] = int(st["turn"]) + 1
	## Muerte subita: a partir de cierto turno el agua sube.
	if int(st["turn"]) >= SUDDEN:
		st["water"] = float(st["water"]) + 3.0
		(st["log"] as Array).append({"k": "flood"})
		_settle(st)
		if bool(st["won"]) or bool(st["lost"]):
			return
	st["side"] = 3 - int(st["side"])
	_next_unit(st)


# ------------------------------------------------------------------ IA y bot

## Valor de un disparo para el equipo side: dano al rival (y bajas) menos dano propio.
static func _score(st: Dictionary, shot: Dictionary, side: int) -> float:
	if str(shot["hit"]) != "ground" and str(shot["hit"]) != "unit":
		return -50.0
	var at: Vector2 = shot["end"]
	var s: float = 0.0
	var dmg: Dictionary = blast_damage(st, at)
	for i: Variant in dmg:
		var u: Dictionary = st["units"][int(i)]
		var real: float = minf(float(dmg[i]), float(u["hp"]))
		var kill: float = 30.0 if int(dmg[i]) >= int(u["hp"]) else 0.0
		s += (real + kill) * (1.0 if int(u["team"]) != side else -1.6)
	## Ninguno: acercarse al rival mas cercano (y no al agua).
	var best: float = 999.0
	for e: Variant in alive(st, 3 - side):
		best = minf(best, absf(unit_pos(st, e).x - at.x))
	return s - best * 0.15


## Mejor disparo para el soldado activo: barrido grueso y luego fino.
static func best_shot(st: Dictionary) -> Dictionary:
	var side: int = int(st["side"])
	var from: Vector2 = unit_pos(st, active_unit(st))
	var wind: float = float(st["wind"])
	var best: Dictionary = {"angle": 60.0, "power": 0.6, "score": -9999.0}
	var a: float = 6.0
	while a <= 174.0:
		var pw: float = 0.25
		while pw <= 1.001:
			var sc: float = _score(st, simulate(st, from, a, pw, wind), side)
			if sc > float(best["score"]):
				best = {"angle": a, "power": pw, "score": sc}
			pw += 0.05
		a += 4.0
	var b0: Dictionary = best.duplicate()
	for da: float in [-2.0, -1.0, 1.0, 2.0]:
		for dp: float in [-0.025, 0.0, 0.025]:
			var aa: float = float(b0["angle"]) + da
			var pp: float = clampf(float(b0["power"]) + dp, 0.05, 1.0)
			var sc2: float = _score(st, simulate(st, from, aa, pp, wind), side)
			if sc2 > float(best["score"]):
				best = {"angle": aa, "power": pp, "score": sc2}
	return best


## Disparo del rival: el mejor, con fallo segun su punteria.
static func ai_shot(st: Dictionary) -> Dictionary:
	var b: Dictionary = best_shot(st)
	var miss: float = 1.0 - clampf(float(st["ai"]), 0.0, 1.0)
	b["angle"] = float(b["angle"]) + (_rand(st) * 2.0 - 1.0) * miss * 12.0
	b["power"] = clampf(float(b["power"]) + (_rand(st) * 2.0 - 1.0) * miss * 0.12, 0.05, 1.0)
	return b


static func bot_play(level: Dictionary) -> Dictionary:
	var st: Dictionary = new_state(level)
	var guard: int = 0
	var mine: int = 0
	while not bool(st["won"]) and not bool(st["lost"]) and guard < 80:
		guard += 1
		var b: Dictionary = best_shot(st) if int(st["side"]) == 1 else ai_shot(st)
		if int(st["side"]) == 1:
			mine += 1
		fire(st, float(b["angle"]), float(b["power"]))
	var hp: int = 0
	for u: Variant in alive(st, 1):
		hp += int(u["hp"])
	return {"won": bool(st["won"]), "turns": int(st["turn"]), "mine": mine, "hp": hp}


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var st: Dictionary = new_state(level)
	if alive(st, 1).is_empty() or alive(st, 2).is_empty():
		issues.append("artillery_teams")
	for u: Variant in st["units"]:
		if height(st, float(u["x"])) <= float(st["water"]) + 4.0:
			issues.append("artillery_unit_in_water")
			break
	var r: Dictionary = {"won": false, "turns": 0, "mine": 0}
	if issues.is_empty():
		r = bot_play(level)
		if not bool(r["won"]):
			issues.append("artillery_bot_failed")
		elif int(r["mine"]) < 2:
			issues.append("artillery_too_short")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": 0, "enemies": alive(st, 2).size(),
		"enemy_problems": [], "bot": r}
