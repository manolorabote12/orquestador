extends RefCounted
## Billar (estilo 8 Ball Pool, modo reto en solitario): fisica, bot y analizador.
## 1 - Mapa (game.json -> levels[i].map): la mesa en una rejilla de 9x15: "C" bola blanca, "o"
##     bola de color, "." vacio. Cada casilla son 60 px de la mesa (540x900, troneras en las
##     esquinas y en el centro de las bandas largas).
## 2 - Arrastra hacia atras desde la blanca para apuntar y soltar con fuerza. Las bolas chocan,
##     rebotan en las bandas y se frenan. Meter la blanca = falta (vuelve al centro y se gasta
##     el tiro).
## 3 - Se gana al meter todas las bolas de color en "shots" tiros.

const TW: float = 540.0
const TH: float = 900.0
const R: float = 15.0
const POCKET_R: float = 30.0
const FRICTION: float = 230.0
const MAX_SPEED: float = 1700.0
const DT: float = 1.0 / 120.0
const POCKETS: Array[Vector2] = [Vector2(0, 0), Vector2(TW, 0), Vector2(0, TH * 0.5), Vector2(TW, TH * 0.5), Vector2(0, TH), Vector2(TW, TH)]


static func new_state(level: Dictionary) -> Dictionary:
	var rows: Array = level.get("map", [])
	var balls: Array = []
	var cue: Vector2 = Vector2(TW * 0.5, TH * 0.78)
	for y: int in rows.size():
		var s: String = str(rows[y])
		for x: int in s.length():
			var p: Vector2 = Vector2((float(x) + 0.5) * 60.0, (float(y) + 0.5) * 60.0)
			if s[x] == "C":
				cue = p
			elif s[x] == "o":
				balls.append({"p": p, "v": Vector2.ZERO, "in": false, "id": balls.size() + 1})
	var all: Array = [{"p": cue, "v": Vector2.ZERO, "in": false, "id": 0}]
	all.append_array(balls)
	return {"balls": all, "shots": int(level.get("shots", 6)), "used": 0, "potted": 0, "fouls": 0, "won": false, "lost": false,
		"total": balls.size()}


static func moving(st: Dictionary) -> bool:
	for b: Dictionary in st["balls"]:
		if not b["in"] and (b["v"] as Vector2).length_squared() > 1.0:
			return true
	return false


## Un paso de fisica. Devuelve las bolas que han caido en este paso.
static func step(st: Dictionary, dt: float = DT) -> Array:
	var fallen: Array = []
	var balls: Array = st["balls"]
	for b: Dictionary in balls:
		if b["in"]:
			continue
		var v: Vector2 = b["v"]
		var sp: float = v.length()
		if sp > 0.0:
			sp = maxf(0.0, sp - FRICTION * dt)
			v = v.normalized() * sp
		var p: Vector2 = (b["p"] as Vector2) + v * dt
		## Troneras.
		for pk: Vector2 in POCKETS:
			if p.distance_to(pk) < POCKET_R:
				b["in"] = true
				fallen.append(b)
				break
		if b["in"]:
			b["v"] = Vector2.ZERO
			continue
		## Bandas.
		if p.x < R:
			p.x = R
			v.x = absf(v.x) * 0.8
		elif p.x > TW - R:
			p.x = TW - R
			v.x = -absf(v.x) * 0.8
		if p.y < R:
			p.y = R
			v.y = absf(v.y) * 0.8
		elif p.y > TH - R:
			p.y = TH - R
			v.y = -absf(v.y) * 0.8
		b["p"] = p
		b["v"] = v
	## Choques entre bolas (elasticos, misma masa).
	for i: int in balls.size():
		var a: Dictionary = balls[i]
		if a["in"]:
			continue
		for j: int in range(i + 1, balls.size()):
			var c: Dictionary = balls[j]
			if c["in"]:
				continue
			var d: Vector2 = (c["p"] as Vector2) - (a["p"] as Vector2)
			var dist: float = d.length()
			if dist < R * 2.0 and dist > 0.001:
				var n: Vector2 = d / dist
				var overlap: float = R * 2.0 - dist
				a["p"] = (a["p"] as Vector2) - n * overlap * 0.5
				c["p"] = (c["p"] as Vector2) + n * overlap * 0.5
				var rel: float = ((a["v"] as Vector2) - (c["v"] as Vector2)).dot(n)
				if rel > 0.0:
					var imp: Vector2 = n * rel * 0.96
					a["v"] = (a["v"] as Vector2) - imp
					c["v"] = (c["v"] as Vector2) + imp
	return fallen


## Tira con la blanca (direccion y fuerza 0-1) y simula hasta que todo se para.
## Devuelve {"potted": n, "foul": bool}.
static func shoot(st: Dictionary, dir: Vector2, power: float) -> Dictionary:
	var cue: Dictionary = st["balls"][0]
	cue["v"] = dir.normalized() * clampf(power, 0.05, 1.0) * MAX_SPEED
	st["used"] = int(st["used"]) + 1
	var res: Dictionary = settle(st)
	return res


static func settle(st: Dictionary) -> Dictionary:
	var potted: int = 0
	var foul: bool = false
	var guard: int = 0
	while moving(st) and guard < 120 * 20:
		guard += 1
		for b: Dictionary in step(st):
			if int(b["id"]) == 0:
				foul = true
			else:
				potted += 1
	finish_shot(st, potted, foul)
	return {"potted": potted, "foul": foul}


static func finish_shot(st: Dictionary, potted: int, foul: bool) -> void:
	st["potted"] = int(st["potted"]) + potted
	if foul:
		st["fouls"] = int(st["fouls"]) + 1
		var cue: Dictionary = st["balls"][0]
		cue["in"] = false
		cue["v"] = Vector2.ZERO
		cue["p"] = _free_spot(st, Vector2(TW * 0.5, TH * 0.78))
	if int(st["potted"]) >= int(st["total"]):
		st["won"] = true
	elif int(st["used"]) >= int(st["shots"]):
		st["lost"] = true


static func _free_spot(st: Dictionary, want: Vector2) -> Vector2:
	var p: Vector2 = want
	for k: int in 40:
		var ok: bool = true
		for b: Dictionary in st["balls"]:
			if int(b["id"]) != 0 and not b["in"] and (b["p"] as Vector2).distance_to(p) < R * 2.2:
				ok = false
				break
		if ok:
			return p
		p += Vector2(0, -R * 2.2) if k % 2 == 0 else Vector2(R * 2.2 * float(k), 0)
		p.x = clampf(p.x, R * 2.0, TW - R * 2.0)
		p.y = clampf(p.y, R * 2.0, TH - R * 2.0)
	return want


static func copy_state(st: Dictionary) -> Dictionary:
	var c: Dictionary = st.duplicate()
	var balls: Array = []
	for b: Dictionary in st["balls"]:
		balls.append(b.duplicate())
	c["balls"] = balls
	return c


## El bot prueba la "bola fantasma" de cada bola hacia cada tronera con varias fuerzas, simula la
## jugada y elige la que mete mas sin meter la blanca. Le pone un poco de error de pulso.
static func bot_shot(st: Dictionary, seed_v: int) -> Array:
	var cue: Vector2 = st["balls"][0]["p"]
	## 1 - Candidatos por geometria: corte pequeno y distancias cortas primero.
	var cands: Array = []
	for b: Dictionary in st["balls"]:
		if int(b["id"]) == 0 or b["in"]:
			continue
		for pk: Vector2 in POCKETS:
			var to_pk: Vector2 = (pk - (b["p"] as Vector2)).normalized()
			var ghost: Vector2 = (b["p"] as Vector2) - to_pk * R * 2.0
			var dir: Vector2 = (ghost - cue).normalized()
			var cut: float = dir.dot(to_pk)
			if cut < 0.25:
				continue
			var cost: float = cue.distance_to(ghost) + (b["p"] as Vector2).distance_to(pk) * 1.3 - cut * 300.0
			cands.append([cost, dir])
	cands.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	var best: Array = []
	var best_s: float = -INF
	## 2 - Simular los mejores con dos fuerzas.
	for c: Array in cands.slice(0, 6):
		for power: float in [0.5, 0.8]:
			var sim: Dictionary = copy_state(st)
			var r: Dictionary = shoot(sim, c[1], power)
			var s: float = float(r["potted"]) * 10.0 - (30.0 if bool(r["foul"]) else 0.0) - power
			if s > best_s:
				best_s = s
				best = [c[1], power]
	if best.is_empty():
		return [(Vector2(TW * 0.5, TH * 0.3) - cue).normalized(), 0.6]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_v
	var dir2: Vector2 = (best[0] as Vector2).rotated(rng.randfn(0.0, 0.006))
	return [dir2, float(best[1])]


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var st: Dictionary = new_state(level)
	if int(st["total"]) < 1 or int(st["total"]) > 10:
		issues.append("pool_balls")
	for i: int in (st["balls"] as Array).size():
		for j: int in range(i + 1, (st["balls"] as Array).size()):
			if (st["balls"][i]["p"] as Vector2).distance_to(st["balls"][j]["p"]) < R * 2.0:
				issues.append("pool_overlap")
				break
	var par: int = 0
	if issues.is_empty():
		var k: int = 0
		while not bool(st["won"]) and not bool(st["lost"]):
			var sh: Array = bot_shot(st, 977 + k * 31)
			shoot(st, sh[0], sh[1])
			k += 1
		if not bool(st["won"]):
			issues.append("pool_too_hard")
		par = int(st["used"])
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": int(st["total"]), "enemies": 0, "enemy_problems": [], "par": par}
