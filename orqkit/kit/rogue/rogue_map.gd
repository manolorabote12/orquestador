extends RefCounted
## Arquero (tipo Archero): salas de una arena vista desde arriba. Mueve al heroe arrastrando; cuando
## se para, dispara solo al enemigo mas cercano. Limpia la sala y elige 1 de 3 habilidades antes de
## la siguiente. La vida se guarda entre salas; si llega a 0, se pierde. Gana quien limpia la ultima.
## Nivel: "rooms" ([{"enemies": [{"k": "slime"|"bat"|"archer"|"boss", "x", "y"}]}, ...]) y "seed"
## (las habilidades que salen) y "power" (multiplica la vida y el dano de los enemigos; 1 = normal). Unidades de la arena: ARENA (9 x 14); el heroe entra por abajo.
## Todo es determinista (paso fijo del bot y azar con semilla): el analizador lo juega entero.

const Rules = preload("res://kit/rules.gd")
const ARENA: Vector2 = Vector2(9.0, 14.0)
const HERO_R: float = 0.4
const HERO_SPEED: float = 4.5
const ARROW_SPEED: float = 14.0
const START: Vector2 = Vector2(4.5, 12.6)
const SKILLS: Array[String] = ["doble", "rapido", "fuerza", "diagonal", "vida", "escudo"]
## Enemigos: radio, vida, velocidad, dano al tocar, disparo (cada cuantos s, 0 nunca), dano de bala, balas.
const KINDS: Dictionary = {
	"slime": {"r": 0.45, "hp": 30.0, "speed": 1.5, "touch": 10.0, "shoot": 0.0, "bullet": 0.0, "n": 0},
	"bat": {"r": 0.35, "hp": 16.0, "speed": 2.9, "touch": 8.0, "shoot": 0.0, "bullet": 0.0, "n": 0},
	"archer": {"r": 0.42, "hp": 24.0, "speed": 0.5, "touch": 8.0, "shoot": 2.4, "bullet": 12.0, "n": 1},
	"boss": {"r": 0.95, "hp": 260.0, "speed": 1.0, "touch": 20.0, "shoot": 2.4, "bullet": 12.0, "n": 3},
}


static func new_state(level: Dictionary) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(level.get("seed", 1))
	var st: Dictionary = {"rooms": level.get("rooms", []), "room": 0, "hero": {"p": START, "hp": 100.0, "max_hp": 100.0, "cd": 0.4, "inv": 0.0},
		"skills": {}, "enemies": [], "arrows": [], "bullets": [], "offer": [], "phase": "fight", "t": 0.0, "kills": 0,
		"power": clampf(float(level.get("power", 1.0)), 0.3, 5.0), "won": false, "lost": false, "rng": rng}
	_spawn(st)
	st["rules"] = Rules.load_rules(level)
	Rules.hook(st, "on_start")
	return st


static func _spawn(st: Dictionary) -> void:
	var out: Array = []
	var rooms: Array = st["rooms"]
	if int(st["room"]) < rooms.size():
		var k: int = 0
		for e: Variant in (rooms[int(st["room"])] as Dictionary).get("enemies", []):
			var kind: String = str((e as Dictionary).get("k", "slime"))
			if not KINDS.has(kind):
				kind = "slime"
			var info: Dictionary = KINDS[kind]
			var hp0: float = float(info["hp"]) * float(st["power"])
			out.append({"k": kind, "p": Vector2(float(e.get("x", 4.5)), float(e.get("y", 4.0))), "hp": hp0, "max": hp0,
				"cd": 1.0 + 0.35 * float(k), "ph": float(k) * 1.7, "hit": 0.0})
			k += 1
	st["enemies"] = out
	st["arrows"] = []
	st["bullets"] = []
	(st["hero"] as Dictionary)["p"] = START
	(st["hero"] as Dictionary)["cd"] = 0.4


static func lvl(st: Dictionary, s: String) -> int:
	return int((st["skills"] as Dictionary).get(s, 0))


static func attack_interval(st: Dictionary) -> float:
	return 0.55 * pow(0.8, lvl(st, "rapido"))


static func arrow_damage(st: Dictionary) -> float:
	return 10.0 * pow(1.3, lvl(st, "fuerza"))


static func nearest_enemy(st: Dictionary, from: Vector2) -> int:
	var best: int = -1
	var bd: float = INF
	for i: int in (st["enemies"] as Array).size():
		var d: float = (st["enemies"][i]["p"] as Vector2).distance_squared_to(from)
		if d < bd:
			bd = d
			best = i
	return best


static func _clamp_arena(p: Vector2, r: float) -> Vector2:
	return Vector2(clampf(p.x, r, ARENA.x - r), clampf(p.y, r, ARENA.y - r))


static func _hurt(st: Dictionary, dmg: float) -> void:
	var hero: Dictionary = st["hero"]
	if float(hero["inv"]) > 0.0:
		return
	var k: float = pow(0.8, lvl(st, "escudo")) * sqrt(float(st["power"]))
	hero["hp"] = maxf(0.0, float(hero["hp"]) - dmg * k)
	hero["inv"] = 0.5
	Rules.hook(st, "on_hurt", [dmg * k])
	if float(hero["hp"]) <= 0.0:
		st["lost"] = true
		st["phase"] = "lost"


## Avanza dt segundos con el heroe moviendose hacia move (cero = quieto: dispara).
static func step(st: Dictionary, dt: float, move: Vector2) -> void:
	if str(st["phase"]) != "fight":
		return
	st["t"] = float(st["t"]) + dt
	var hero: Dictionary = st["hero"]
	hero["inv"] = maxf(0.0, float(hero["inv"]) - dt)
	var moving: bool = move.length() > 0.15
	if moving:
		hero["p"] = _clamp_arena((hero["p"] as Vector2) + move.limit_length(1.0) * HERO_SPEED * dt, HERO_R)
	hero["cd"] = float(hero["cd"]) - dt
	var enemies: Array = st["enemies"]
	if not moving and float(hero["cd"]) <= 0.0 and not enemies.is_empty():
		var ti: int = nearest_enemy(st, hero["p"])
		var dir: Vector2 = ((enemies[ti]["p"] as Vector2) - (hero["p"] as Vector2)).normalized()
		var n: int = 1 + lvl(st, "doble")
		for k: int in n:
			var off: Vector2 = dir.orthogonal() * (float(k) - float(n - 1) * 0.5) * 0.3
			(st["arrows"] as Array).append({"p": (hero["p"] as Vector2) + off, "v": dir * ARROW_SPEED})
		for k2: int in lvl(st, "diagonal"):
			for sgn: float in [-1.0, 1.0]:
				(st["arrows"] as Array).append({"p": hero["p"], "v": dir.rotated(sgn * deg_to_rad(30.0 + 12.0 * float(k2))) * ARROW_SPEED})
		hero["cd"] = attack_interval(st)
	## Flechas.
	var keep: Array = []
	var dmg: float = arrow_damage(st)
	for a: Variant in st["arrows"]:
		a["p"] = (a["p"] as Vector2) + (a["v"] as Vector2) * dt
		var ap: Vector2 = a["p"]
		if ap.x < 0.0 or ap.y < 0.0 or ap.x > ARENA.x or ap.y > ARENA.y:
			continue
		var hit: bool = false
		for e: Variant in enemies:
			if ap.distance_to(e["p"]) < float(KINDS[e["k"]]["r"]) + 0.15:
				e["hp"] = float(e["hp"]) - dmg
				e["hit"] = 0.12
				hit = true
				break
		if not hit:
			keep.append(a)
	st["arrows"] = keep
	## Enemigos.
	var hp: Vector2 = hero["p"]
	for e2: Variant in enemies:
		var info: Dictionary = KINDS[e2["k"]]
		e2["hit"] = maxf(0.0, float(e2["hit"]) - dt)
		e2["ph"] = float(e2["ph"]) + dt
		var ep: Vector2 = e2["p"]
		var to: Vector2 = (hp - ep).normalized()
		match str(e2["k"]):
			"bat":
				to = (to + to.orthogonal() * sin(float(e2["ph"]) * 3.0) * 0.9).normalized()
			"archer":
				to = Vector2(cos(float(e2["ph"]) * 0.7), sin(float(e2["ph"]) * 0.5)) * 0.6
		e2["p"] = _clamp_arena(ep + to * float(info["speed"]) * dt, float(info["r"]))
		if float(info["shoot"]) > 0.0:
			e2["cd"] = float(e2["cd"]) - dt
			if float(e2["cd"]) <= 0.0:
				e2["cd"] = float(info["shoot"])
				var bd: Vector2 = (hp - (e2["p"] as Vector2)).normalized()
				var nb: int = int(info["n"])
				for b: int in nb:
					var ang: float = (float(b) - float(nb - 1) * 0.5) * deg_to_rad(16.0)
					(st["bullets"] as Array).append({"p": e2["p"], "v": bd.rotated(ang) * (6.0 if str(e2["k"]) == "archer" else 5.0), "d": float(info["bullet"])})
		if (e2["p"] as Vector2).distance_to(hp) < HERO_R + float(info["r"]):
			_hurt(st, float(info["touch"]))
	## Balas enemigas.
	var keep2: Array = []
	for bl: Variant in st["bullets"]:
		bl["p"] = (bl["p"] as Vector2) + (bl["v"] as Vector2) * dt
		var bp: Vector2 = bl["p"]
		if bp.x < 0.0 or bp.y < 0.0 or bp.x > ARENA.x or bp.y > ARENA.y:
			continue
		if bp.distance_to(hero["p"]) < HERO_R + 0.15:
			_hurt(st, float(bl["d"]))
			continue
		keep2.append(bl)
	st["bullets"] = keep2
	## Bajas y fin de sala.
	var alive: Array = []
	for e3: Variant in enemies:
		if float(e3["hp"]) > 0.0:
			alive.append(e3)
		else:
			st["kills"] = int(st["kills"]) + 1
			Rules.hook(st, "on_kill", [e3])
	st["enemies"] = alive
	Rules.hook(st, "on_step", [dt])
	if bool(st["lost"]):
		return
	if alive.is_empty():
		if int(st["room"]) >= (st["rooms"] as Array).size() - 1:
			st["won"] = true
			st["phase"] = "won"
		else:
			st["phase"] = "pick"
			st["bullets"] = []
			st["arrows"] = []
			var pool: Array = SKILLS.duplicate()
			var offer: Array = []
			for k3: int in 3:
				offer.append(pool.pop_at((st["rng"] as RandomNumberGenerator).randi_range(0, pool.size() - 1)))
			st["offer"] = offer


## Elige una habilidad de las ofrecidas y entra en la sala siguiente.
static func pick(st: Dictionary, skill: String) -> bool:
	if str(st["phase"]) != "pick" or not (st["offer"] as Array).has(skill):
		return false
	(st["skills"] as Dictionary)[skill] = lvl(st, skill) + 1
	var hero: Dictionary = st["hero"]
	if skill == "vida":
		hero["max_hp"] = float(hero["max_hp"]) + 25.0
		hero["hp"] = minf(float(hero["max_hp"]), float(hero["hp"]) + 45.0)
	Rules.hook(st, "on_pick", [skill])
	st["room"] = int(st["room"]) + 1
	st["offer"] = []
	st["phase"] = "fight"
	_spawn(st)
	return true


## Bot: esquiva balas que vienen, se aleja de quien se acerca y, si no hay peligro, se para a disparar.
static func bot_move(st: Dictionary) -> Vector2:
	var hp: Vector2 = st["hero"]["p"]
	var push: Vector2 = Vector2.ZERO
	for bl: Variant in st["bullets"]:
		var v: Vector2 = bl["v"]
		var rel: Vector2 = hp - (bl["p"] as Vector2)
		var tt: float = rel.dot(v) / maxf(0.001, v.length_squared())
		if tt < 0.0 or tt > 0.9:
			continue
		var miss: Vector2 = rel - v * tt
		if miss.length() < 0.95:
			var side: Vector2 = miss.normalized() if miss.length() > 0.05 else v.orthogonal().normalized()
			push += side * (1.0 - tt)
	for e: Variant in st["enemies"]:
		var info: Dictionary = KINDS[e["k"]]
		if str(e["k"]) == "archer":
			continue
		var d: Vector2 = hp - (e["p"] as Vector2)
		var keep: float = float(info["r"]) + {"bat": 2.9}.get(str(e["k"]), 1.9)
		if d.length() < keep:
			push += d.normalized() * (keep - d.length())
	if push.length() < 0.05:
		return Vector2.ZERO
	## Sin pegarse a las paredes: un empujon hacia el centro si esta cerca del borde.
	var center: Vector2 = ARENA * 0.5 - hp
	if hp.x < 1.2 or hp.x > ARENA.x - 1.2 or hp.y < 1.2 or hp.y > ARENA.y - 1.2:
		push += center.normalized() * 0.8
	return push.normalized()


const PICK_ORDER: Array[String] = ["doble", "rapido", "fuerza", "diagonal", "escudo", "vida"]


static func bot_pick(st: Dictionary) -> String:
	var offer: Array = st["offer"]
	var hero: Dictionary = st["hero"]
	if offer.has("vida") and float(hero["hp"]) < float(hero["max_hp"]) * 0.5:
		return "vida"
	for s: String in PICK_ORDER:
		if offer.has(s):
			return s
	return str(offer[0]) if not offer.is_empty() else ""


static func bot_play(level: Dictionary, max_t: float = 300.0) -> Dictionary:
	var st: Dictionary = new_state(level)
	var dt: float = 1.0 / 30.0
	while float(st["t"]) < max_t and not bool(st["won"]) and not bool(st["lost"]):
		if str(st["phase"]) == "pick":
			pick(st, bot_pick(st))
			continue
		step(st, dt, bot_move(st))
	return {"won": bool(st["won"]), "hp": float(st["hero"]["hp"]), "t": float(st["t"]), "room": int(st["room"])}


## Analizador: salas con enemigos conocidos, dentro de la arena y lejos de la entrada, y el bot gana.
static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var rooms: Array = level.get("rooms", [])
	if rooms.is_empty() or rooms.size() > 8:
		issues.append("rogue_rooms")
	var total: int = 0
	for r: Variant in rooms:
		var en: Array = (r as Dictionary).get("enemies", [])
		if en.is_empty() or en.size() > 12:
			issues.append("rogue_room_size")
		for e: Variant in en:
			total += 1
			if not KINDS.has(str((e as Dictionary).get("k", ""))):
				issues.append("rogue_bad_enemy")
			var p: Vector2 = Vector2(float(e.get("x", -1.0)), float(e.get("y", -1.0)))
			if p.x < 0.5 or p.y < 0.5 or p.x > ARENA.x - 0.5 or p.y > ARENA.y - 0.5:
				issues.append("rogue_outside")
			elif p.distance_to(START) < 4.0:
				issues.append("rogue_spawn_close")
	var r2: Dictionary = {"won": false, "hp": 0.0}
	if issues.is_empty():
		r2 = bot_play(level)
		if not bool(r2["won"]):
			issues.append("rogue_unbeatable")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": total, "enemies": total, "enemy_problems": [],
		"bot_hp": r2.get("hp", 0.0), "bot_t": r2.get("t", 0.0)}
