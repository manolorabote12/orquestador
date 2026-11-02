extends RefCounted
## Defensa por carriles (estilo Plants vs Zombies) en vertical: simulacion pura, bot y analizador.
## 1 - Jardin de LANES carriles (x) por ROWS filas (y); los zombis bajan desde arriba (y < 0)
##     hacia la casa (y = ROWS). Cada carril tiene un cortacesped que salva una vez.
## 2 - Soles: caen del cielo y los dan los girasoles; se tocan para cogerlos. Cada planta cuesta
##     soles y tiene un tiempo de recarga.
## 3 - Plantas: girasol, lanzaguisantes, guisante de hielo (frena), nuez (muro), patatamina (tarda
##     en armarse y revienta al pisarla), cereza bomba (3x3) y repetidor (dos guisantes).
## 4 - Zombis: normal, con cono, con cubo y corredor. Se comen lo que tienen delante.
## 5 - Oleadas (parametro "waves": [{"t": segundos, "z": ["normal", ...]}]); se gana cuando han
##     salido todas y no queda ninguno. Si un zombi llega a la casa sin cortacesped, se pierde.
## Parametros: "waves", "plants" (cartas disponibles), "sun" (soles al empezar), "sky" (segundos
## entre soles del cielo), "par".

const LANES: int = 5
const ROWS: int = 9
const PLANTS: Dictionary = {
	"sunflower": {"cost": 50, "hp": 300.0, "recharge": 7.5},
	"peashooter": {"cost": 100, "hp": 300.0, "recharge": 7.5, "fire": 1.4, "dmg": 20.0, "peas": 1},
	"snowpea": {"cost": 175, "hp": 300.0, "recharge": 7.5, "fire": 1.4, "dmg": 20.0, "peas": 1, "slow": true},
	"wallnut": {"cost": 50, "hp": 4000.0, "recharge": 30.0},
	"potatomine": {"cost": 25, "hp": 300.0, "recharge": 30.0, "arm": 12.0},
	"cherrybomb": {"cost": 150, "hp": 9999.0, "recharge": 50.0, "fuse": 1.2},
	"repeater": {"cost": 200, "hp": 300.0, "recharge": 7.5, "fire": 1.4, "dmg": 20.0, "peas": 2},
}
const ZOMBIES: Dictionary = {
	"normal": {"hp": 190.0, "speed": 0.2},
	"cone": {"hp": 560.0, "speed": 0.2},
	"bucket": {"hp": 1300.0, "speed": 0.2},
	"runner": {"hp": 190.0, "speed": 0.36},
}
const EAT_DPS: float = 100.0
const PEA_SPEED: float = 6.0
const SUN_VALUE: int = 25
const SUNFLOWER_EVERY: float = 12.0
const BOOM_DMG: float = 1800.0
const ORDER: Array[String] = ["sunflower", "peashooter", "wallnut", "potatomine", "snowpea", "cherrybomb", "repeater"]


static func waves_of(level: Dictionary) -> Array:
	var out: Array = []
	for w: Variant in level.get("waves", []):
		if w is Dictionary:
			var zs: Array = []
			for z: Variant in (w as Dictionary).get("z", []):
				if ZOMBIES.has(str(z)):
					zs.append(str(z))
			if not zs.is_empty():
				out.append({"t": float((w as Dictionary).get("t", 0.0)), "z": zs})
	if out.is_empty():
		out = [{"t": 20.0, "z": ["normal"]}, {"t": 45.0, "z": ["normal", "normal"]}]
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["t"]) < float(b["t"]))
	return out


static func plants_of(level: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for p: Variant in level.get("plants", ["sunflower", "peashooter", "wallnut"]):
		if PLANTS.has(str(p)) and not out.has(str(p)):
			out.append(str(p))
	if not out.has("sunflower"):
		out.push_front("sunflower")
	if not out.has("peashooter"):
		out.insert(1, "peashooter")
	return out


static func seed_of(level: Dictionary) -> int:
	var s: int = int(level.get("seed", 1))
	for r: Variant in level.get("map", []):
		var row: String = str(r)
		if row.begins_with("#") and row.substr(1).is_valid_int():
			s = int(row.substr(1))
	return s


static func new_state(level: Dictionary) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_of(level)
	var cards: Array[String] = plants_of(level)
	var ready: Dictionary = {}
	for c: String in cards:
		## Al empezar: lo barato listo; las bombas y la nuez tardan.
		ready[c] = 0.0 if float(PLANTS[c]["recharge"]) < 20.0 else float(PLANTS[c]["recharge"]) * 0.5
	var waves: Array = waves_of(level)
	var total: int = 0
	for w: Dictionary in waves:
		total += (w["z"] as Array).size()
	return {"rng": rng, "t": 0.0, "sun": int(level.get("sun", 150)), "sky": clampf(float(level.get("sky", 9.0)), 4.0, 30.0),
		"sky_t": 4.0, "plants": {}, "zombies": [], "peas": [], "suns": [], "cards": cards, "ready": ready, "mowers": [true, true, true, true, true],
		"waves": waves, "wave_i": 0, "spawned": 0, "total": total, "killed": 0, "over": false, "won": false, "events": [], "next_id": 0}


static func _ev(st: Dictionary, kind: String, extra: Dictionary = {}) -> void:
	var e: Dictionary = {"kind": kind}
	e.merge(extra)
	(st["events"] as Array).append(e)


static func _id(st: Dictionary) -> int:
	st["next_id"] = int(st["next_id"]) + 1
	return int(st["next_id"])


# ------------------------------------------------------------------ acciones

static func can_plant(st: Dictionary, kind: String, cell: Vector2i) -> bool:
	if bool(st["over"]) or not (st["cards"] as Array).has(kind):
		return false
	if cell.x < 0 or cell.x >= LANES or cell.y < 0 or cell.y >= ROWS or (st["plants"] as Dictionary).has(cell):
		return false
	return int(st["sun"]) >= int(PLANTS[kind]["cost"]) and float(st["ready"][kind]) <= 0.0


static func plant(st: Dictionary, kind: String, cell: Vector2i) -> bool:
	if not can_plant(st, kind, cell):
		return false
	var d: Dictionary = PLANTS[kind]
	st["sun"] = int(st["sun"]) - int(d["cost"])
	st["ready"][kind] = float(d["recharge"])
	st["plants"][cell] = {"kind": kind, "hp": float(d["hp"]), "cd": 0.6, "t": 0.0, "sun_t": SUNFLOWER_EVERY * 0.5}
	_ev(st, "plant", {"kind": kind, "cell": cell})
	return true


## Coge un sol del suelo (por su id).
static func collect(st: Dictionary, id: int) -> bool:
	var suns: Array = st["suns"]
	for i: int in suns.size():
		if int(suns[i]["id"]) == id:
			st["sun"] = int(st["sun"]) + int(suns[i]["v"])
			_ev(st, "collect", {"id": id, "p": Vector2(float(suns[i]["x"]), float(suns[i]["y"]))})
			suns.remove_at(i)
			return true
	return false


# ------------------------------------------------------------------ simulacion

static func step(st: Dictionary, dt: float) -> void:
	if bool(st["over"]):
		return
	var rng: RandomNumberGenerator = st["rng"]
	st["t"] = float(st["t"]) + dt
	var t: float = float(st["t"])
	for c: String in st["ready"]:
		st["ready"][c] = maxf(0.0, float(st["ready"][c]) - dt)
	## Soles del cielo (caen en un sitio al azar y se quedan 10 s).
	st["sky_t"] = float(st["sky_t"]) - dt
	if float(st["sky_t"]) <= 0.0:
		st["sky_t"] = float(st["sky"])
		_drop_sun(st, Vector2(rng.randf_range(0.3, float(LANES) - 0.3), rng.randf_range(1.0, float(ROWS) - 1.0)), true)
	var suns: Array = st["suns"]
	for s: Dictionary in suns:
		s["t"] = float(s["t"]) + dt
	st["suns"] = suns.filter(func(s2: Dictionary) -> bool: return float(s2["t"]) < 10.0)
	## Oleadas.
	var waves: Array = st["waves"]
	while int(st["wave_i"]) < waves.size() and t >= float(waves[int(st["wave_i"])]["t"]):
		var w: Dictionary = waves[int(st["wave_i"])]
		var k: int = 0
		for zk: Variant in w["z"]:
			var lane: int = rng.randi_range(0, LANES - 1)
			var zd: Dictionary = ZOMBIES[str(zk)]
			(st["zombies"] as Array).append({"id": _id(st), "kind": str(zk), "lane": lane, "y": -0.4 - 0.7 * float(k), "hp": float(zd["hp"]),
				"max": float(zd["hp"]), "speed": float(zd["speed"]), "slow": 0.0, "eating": false})
			st["spawned"] = int(st["spawned"]) + 1
			k += 1
		_ev(st, "wave", {"i": int(st["wave_i"]), "last": int(st["wave_i"]) == waves.size() - 1})
		st["wave_i"] = int(st["wave_i"]) + 1
	_plants_act(st, dt)
	_peas_move(st, dt)
	_zombies_act(st, dt)
	_check_end(st)


static func _drop_sun(st: Dictionary, p: Vector2, sky: bool) -> void:
	(st["suns"] as Array).append({"id": _id(st), "x": p.x, "y": p.y, "v": SUN_VALUE, "t": 0.0, "sky": sky})
	_ev(st, "sun", {"p": p, "sky": sky})


## El primer zombi por delante (mas abajo, el mas cercano a la planta) en un carril.
static func _front_zombie(st: Dictionary, lane: int, below_y: float) -> Dictionary:
	var best: Dictionary = {}
	for z: Dictionary in st["zombies"]:
		if int(z["lane"]) == lane and float(z["y"]) < below_y + 0.4 and float(z["y"]) > -1.0:
			if best.is_empty() or float(z["y"]) > float(best["y"]):
				best = z
	return best


static func _plants_act(st: Dictionary, dt: float) -> void:
	var plants: Dictionary = st["plants"]
	for cell: Vector2i in plants.keys():
		var p: Dictionary = plants[cell]
		var d: Dictionary = PLANTS[str(p["kind"])]
		p["t"] = float(p["t"]) + dt
		match str(p["kind"]):
			"sunflower":
				p["sun_t"] = float(p["sun_t"]) - dt
				if float(p["sun_t"]) <= 0.0:
					p["sun_t"] = SUNFLOWER_EVERY
					_drop_sun(st, Vector2(float(cell.x) + 0.5, float(cell.y) + 0.3), false)
			"peashooter", "snowpea", "repeater":
				p["cd"] = float(p["cd"]) - dt
				if float(p["cd"]) <= 0.0 and not _front_zombie(st, cell.x, float(cell.y)).is_empty():
					p["cd"] = float(d["fire"])
					for k: int in int(d["peas"]):
						(st["peas"] as Array).append({"lane": cell.x, "y": float(cell.y) + 0.2 + 0.35 * float(k), "dmg": float(d["dmg"]), "slow": bool(d.get("slow", false))})
					_ev(st, "shoot", {"cell": cell})
			"potatomine":
				if float(p["t"]) >= float(d["arm"]):
					for z: Dictionary in st["zombies"]:
						if int(z["lane"]) == cell.x and absf(float(z["y"]) - float(cell.y)) < 0.6:
							_boom(st, cell, 0)
							break
			"cherrybomb":
				if float(p["t"]) >= float(d["fuse"]):
					_boom(st, cell, 1)


## Revienta: dano a los zombis de la casilla (o del 3x3) y la planta desaparece.
static func _boom(st: Dictionary, cell: Vector2i, reach: int) -> void:
	(st["plants"] as Dictionary).erase(cell)
	_ev(st, "boom", {"cell": cell, "reach": reach})
	for z: Dictionary in st["zombies"]:
		if absi(int(z["lane"]) - cell.x) <= reach and absf(float(z["y"]) - float(cell.y)) < float(reach) + 0.75:
			_hurt(st, z, BOOM_DMG)


static func _peas_move(st: Dictionary, dt: float) -> void:
	var keep: Array = []
	for pea: Dictionary in st["peas"]:
		pea["y"] = float(pea["y"]) - PEA_SPEED * dt
		var hit: bool = false
		for z: Dictionary in st["zombies"]:
			if int(z["lane"]) == int(pea["lane"]) and float(z["hp"]) > 0.0 and absf(float(z["y"]) - float(pea["y"])) < 0.35:
				_hurt(st, z, float(pea["dmg"]))
				if bool(pea["slow"]):
					z["slow"] = 3.0
				_ev(st, "hit", {"lane": int(pea["lane"]), "y": float(pea["y"]), "slow": bool(pea["slow"])})
				hit = true
				break
		if not hit and float(pea["y"]) > -1.5:
			keep.append(pea)
	st["peas"] = keep


static func _hurt(st: Dictionary, z: Dictionary, dmg: float) -> void:
	if float(z["hp"]) <= 0.0:
		return
	z["hp"] = float(z["hp"]) - dmg
	if float(z["hp"]) <= 0.0:
		st["killed"] = int(st["killed"]) + 1
		_ev(st, "die", {"id": int(z["id"]), "lane": int(z["lane"]), "y": float(z["y"]), "kind": str(z["kind"])})


static func _zombies_act(st: Dictionary, dt: float) -> void:
	var plants: Dictionary = st["plants"]
	for z: Dictionary in st["zombies"]:
		if float(z["hp"]) <= 0.0:
			continue
		z["slow"] = maxf(0.0, float(z["slow"]) - dt)
		var cell: Vector2i = Vector2i(int(z["lane"]), int(floor(float(z["y"]) + 0.55)))
		var food: Dictionary = plants.get(cell, {})
		## Come lo que tiene delante (la cereza no se come: revienta antes).
		if not food.is_empty() and str(food["kind"]) != "cherrybomb" and float(z["y"]) > -0.5:
			z["eating"] = true
			food["hp"] = float(food["hp"]) - EAT_DPS * dt * (0.5 if float(z["slow"]) > 0.0 else 1.0)
			if float(food["hp"]) <= 0.0:
				plants.erase(cell)
				_ev(st, "eaten", {"cell": cell})
			continue
		z["eating"] = false
		z["y"] = float(z["y"]) + float(z["speed"]) * dt * (0.5 if float(z["slow"]) > 0.0 else 1.0)
		if float(z["y"]) >= float(ROWS) - 0.1:
			var lane: int = int(z["lane"])
			if bool(st["mowers"][lane]):
				st["mowers"][lane] = false
				_ev(st, "mower", {"lane": lane})
				for z2: Dictionary in st["zombies"]:
					if int(z2["lane"]) == lane and float(z2["hp"]) > 0.0 and float(z2["y"]) > -0.5:
						_hurt(st, z2, 99999.0)
			else:
				st["over"] = true
				st["won"] = false
				_ev(st, "end", {"won": false, "lane": lane})
				return
	st["zombies"] = (st["zombies"] as Array).filter(func(z3: Dictionary) -> bool: return float(z3["hp"]) > 0.0)


static func _check_end(st: Dictionary) -> void:
	if bool(st["over"]):
		return
	if int(st["wave_i"]) >= (st["waves"] as Array).size() and (st["zombies"] as Array).is_empty():
		st["over"] = true
		st["won"] = true
		_ev(st, "end", {"won": true})


static func progress(st: Dictionary) -> float:
	return float(st["killed"]) / maxf(1.0, float(st["total"]))


# ------------------------------------------------------------------ bot

## Un jardinero sensato: girasoles abajo al principio, un tirador en cada carril con zombis (mas
## si llegan fuertes), nuez delante de los conos y cubos, cereza donde se juntan, patatamina
## delante del que viene solo. Coge todos los soles.
static func bot_think(st: Dictionary) -> Dictionary:
	if not (st["suns"] as Array).is_empty():
		return {"collect": int(st["suns"][0]["id"])}
	var plants: Dictionary = st["plants"]
	var threat: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
	var nearest: Array[float] = [-9.0, -9.0, -9.0, -9.0, -9.0]
	for z: Dictionary in st["zombies"]:
		if float(z["y"]) > -1.2:
			threat[int(z["lane"])] += float(z["hp"])
			nearest[int(z["lane"])] = maxf(nearest[int(z["lane"])], float(z["y"]))
	var shooters: Array[int] = [0, 0, 0, 0, 0]
	var sunflowers: int = 0
	for cell: Vector2i in plants:
		var k: String = str(plants[cell]["kind"])
		if k in ["peashooter", "snowpea", "repeater"]:
			shooters[cell.x] += 2 if k == "repeater" else 1
		elif k == "sunflower":
			sunflowers += 1
	## 1 - Cereza donde hay 3 o mas juntos (o un cubo muy adelantado).
	if can_afford(st, "cherrybomb"):
		for z2: Dictionary in st["zombies"]:
			var n: int = 0
			for z3: Dictionary in st["zombies"]:
				if absi(int(z3["lane"]) - int(z2["lane"])) <= 1 and absf(float(z3["y"]) - float(z2["y"])) < 1.4:
					n += 1
			if (n >= 3 or (str(z2["kind"]) == "bucket" and float(z2["y"]) > 4.5)) and float(z2["y"]) > 0.5:
				var c: Vector2i = Vector2i(int(z2["lane"]), clampi(int(round(float(z2["y"]) + 0.3)), 0, ROWS - 1))
				if not plants.has(c):
					return {"plant": "cherrybomb", "cell": c}
	## 2 - Carriles con zombis y sin tirador (o con poco para lo que viene): tirador abajo.
	var worst: int = -1
	var need_best: float = 0.0
	for lane: int in LANES:
		if threat[lane] <= 0.0:
			continue
		var need: float = threat[lane] / 250.0 - float(shooters[lane])
		if shooters[lane] == 0:
			need += 10.0 + nearest[lane]
		if need > need_best:
			need_best = need
			worst = lane
	if worst >= 0 and need_best > 0.5:
		## Si viene muy cerca y no hay tirador: patatamina no da tiempo; nuez para frenar.
		var kind: String = "repeater" if can_afford(st, "repeater") and shooters[worst] >= 1 else ("snowpea" if can_afford(st, "snowpea") and threat[worst] > 600.0 else "peashooter")
		var cell: Vector2i = _free_cell(plants, worst, [ROWS - 2, ROWS - 3, ROWS - 4, ROWS - 1])
		if cell.x >= 0 and can_afford(st, kind):
			return {"plant": kind, "cell": cell}
		if nearest[worst] > 4.0 and shooters[worst] == 0 and can_afford(st, "wallnut"):
			var wc: Vector2i = _free_cell(plants, worst, [clampi(int(nearest[worst]) + 2, 3, ROWS - 2)])
			if wc.x >= 0:
				return {"plant": "wallnut", "cell": wc}
	## 3 - Nuez delante de conos y cubos que ya bajan.
	for z4: Dictionary in st["zombies"]:
		if str(z4["kind"]) in ["cone", "bucket"] and float(z4["y"]) > 1.0 and can_afford(st, "wallnut"):
			var wall: Vector2i = Vector2i(int(z4["lane"]), 4)
			var has_wall: bool = false
			for y: int in range(3, 6):
				if plants.has(Vector2i(int(z4["lane"]), y)) and str(plants[Vector2i(int(z4["lane"]), y)]["kind"]) == "wallnut":
					has_wall = true
			if not has_wall and not plants.has(wall) and float(z4["y"]) < 3.6:
				return {"plant": "wallnut", "cell": wall}
	## 4 - Patatamina delante del primero de un carril (si aun queda lejos).
	for lane2: int in LANES:
		if nearest[lane2] > -0.5 and nearest[lane2] < 2.5 and can_afford(st, "potatomine"):
			var mc: Vector2i = Vector2i(lane2, 5)
			if not plants.has(mc):
				return {"plant": "potatomine", "cell": mc}
	## 5 - Economia: girasoles en la fila de abajo (y luego la de arriba) hasta 8.
	if sunflowers < 8 and can_afford(st, "sunflower"):
		for row: int in [ROWS - 1, ROWS - 2]:
			for lane3: int in [2, 1, 3, 0, 4]:
				var sc: Vector2i = Vector2i(lane3, row)
				if not plants.has(sc):
					return {"plant": "sunflower", "cell": sc}
	## 6 - Con soles de sobra, refuerza el carril mas flojo.
	if int(st["sun"]) >= 300:
		var weak: int = 0
		for lane4: int in LANES:
			if shooters[lane4] < shooters[weak]:
				weak = lane4
		var kind2: String = "repeater" if can_afford(st, "repeater") else "peashooter"
		var cc: Vector2i = _free_cell(plants, weak, [ROWS - 2, ROWS - 3, ROWS - 4, ROWS - 5])
		if cc.x >= 0 and can_afford(st, kind2):
			return {"plant": kind2, "cell": cc}
	return {}


static func can_afford(st: Dictionary, kind: String) -> bool:
	return (st["cards"] as Array).has(kind) and int(st["sun"]) >= int(PLANTS[kind]["cost"]) and float(st["ready"][kind]) <= 0.0


static func _free_cell(plants: Dictionary, lane: int, rows: Array) -> Vector2i:
	for y: Variant in rows:
		var c: Vector2i = Vector2i(lane, int(y))
		if not plants.has(c):
			return c
	return Vector2i(-1, -1)


static func bot_act(st: Dictionary) -> void:
	var m: Dictionary = bot_think(st)
	if m.has("collect"):
		collect(st, int(m["collect"]))
	elif m.has("plant"):
		plant(st, str(m["plant"]), m["cell"])


static func bot_play(level: Dictionary, dt: float = 0.1) -> Dictionary:
	var st: Dictionary = new_state(level)
	var think: float = 0.0
	while not bool(st["over"]) and float(st["t"]) < 900.0:
		think -= dt
		if think <= 0.0:
			think = 0.4
			for k: int in 3:
				bot_act(st)
		step(st, dt)
		(st["events"] as Array).clear()
	var mowers: int = 0
	for m: Variant in st["mowers"]:
		if bool(m):
			mowers += 1
	return {"won": bool(st["won"]), "t": float(st["t"]), "mowers": mowers, "killed": int(st["killed"]), "total": int(st["total"])}


# ------------------------------------------------------------------ analizador

static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var waves: Array = waves_of(level)
	if waves.is_empty():
		issues.append("lawn_no_waves")
	var wins: int = 0
	var mowers: int = 0
	if issues.is_empty():
		var base: int = seed_of(level)
		for k: int in 3:
			var lv: Dictionary = level.duplicate()
			lv["seed"] = base + k * 97
			lv["map"] = ["jardin", "#%d" % (base + k * 97)]
			var r: Dictionary = bot_play(lv)
			if bool(r["won"]):
				wins += 1
				mowers += int(r["mowers"])
		if wins < 2:
			issues.append("lawn_too_hard")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": 0, "enemies": 0, "enemy_problems": [],
		"par": int(level.get("par", 0)), "wins": wins, "mowers": mowers}
