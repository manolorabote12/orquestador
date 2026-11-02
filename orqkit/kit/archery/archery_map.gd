extends RefCounted
## Tiro con arco: diana, viento y flechas contadas. Reglas, simulacion pura, bot y analizador.
## 1 - Mapa (game.json -> levels[i].map): una linea por cosa (metros desde el arquero, y hacia arriba):
##     "t:30,2,0.6,0,0"    diana en x=30, y=2, radio 0.6, se mueve arriba y abajo (amplitud) a una
##                          velocidad (vueltas por segundo)
##     "g:45,6"             globo (romperlo da una flecha mas)
##     "w:-1.5"             viento (m/s2 a lo largo; negativo, en contra)
## 2 - Parametros: "arrows" (flechas) y "goal" (puntos para ganar). Cada diana da de 10 (centro) a 1.
## 3 - Se tira arrastrando hacia atras: el angulo es el contrario y la fuerza, lo que estiras.

const G: float = 9.8
const VMAX: float = 62.0
const DT: float = 1.0 / 120.0
const BOW: Vector2 = Vector2(0.0, 1.5)


static func parse(level: Dictionary) -> Dictionary:
	var targets: Array = []
	var balloons: Array = []
	var wind: float = 0.0
	for r: Variant in level.get("map", []):
		var s: String = str(r).strip_edges()
		if s.length() < 3 or s[1] != ":":
			continue
		var v: PackedStringArray = s.substr(2).split(",")
		match s[0]:
			"t":
				if v.size() >= 3:
					targets.append({"p": Vector2(float(v[0]), float(v[1])), "r": float(v[2]), "amp": float(v[3]) if v.size() > 3 else 0.0,
						"spd": float(v[4]) if v.size() > 4 else 0.0})
			"g":
				if v.size() >= 2:
					balloons.append({"p": Vector2(float(v[0]), float(v[1])), "popped": false})
			"w":
				wind = float(v[0])
	return {"targets": targets, "balloons": balloons, "wind": wind}


static func new_state(level: Dictionary) -> Dictionary:
	var d: Dictionary = parse(level)
	return {"targets": d["targets"], "balloons": d["balloons"], "wind": d["wind"], "arrows": int(level.get("arrows", 5)),
		"goal": int(level.get("goal", 20)), "score": 0, "t": 0.0, "shots": [], "seed": int(level.get("seed", 1)), "best": 0}


static func target_pos(tg: Dictionary, t: float) -> Vector2:
	return (tg["p"] as Vector2) + Vector2(0.0, float(tg["amp"]) * sin(TAU * float(tg["spd"]) * t))


## Vuelo de una flecha disparada en el instante t0. Devuelve {"points": la diana que toca (0-10),
## "target": indice o -1, "balloon": indice o -1, "path": trayectoria, "end": donde acaba, "t": duracion}.
static func fly(st: Dictionary, angle: float, power: float, t0: float, keep_path: bool = false) -> Dictionary:
	var p: Vector2 = BOW
	var v: Vector2 = Vector2(cos(angle), sin(angle)) * clampf(power, 0.0, 1.0) * VMAX
	var wind: float = float(st["wind"])
	var t: float = 0.0
	var path: Array = []
	var out: Dictionary = {"points": 0, "target": -1, "balloon": -1, "path": path, "end": p, "t": 0.0}
	while t < 6.0:
		var prev: Vector2 = p
		v += Vector2(wind, -G) * DT
		p += v * DT
		t += DT
		if keep_path and int(t / DT) % 3 == 0:
			path.append(p)
		## Globos: un circulo de 0,5 m.
		for bi: int in (st["balloons"] as Array).size():
			var b: Dictionary = st["balloons"][bi]
			if not bool(b["popped"]) and _seg_dist(prev, p, b["p"]) < 0.5 and out["balloon"] == -1:
				out["balloon"] = bi
		## Dianas: al cruzar su plano (x), si la altura cae dentro del radio.
		for ti: int in (st["targets"] as Array).size():
			var tg: Dictionary = st["targets"][ti]
			var tx: float = (tg["p"] as Vector2).x
			if prev.x < tx and p.x >= tx:
				var f: float = (tx - prev.x) / maxf(0.0001, p.x - prev.x)
				var y: float = lerpf(prev.y, p.y, f)
				var c: Vector2 = target_pos(tg, t0 + t)
				var dy: float = absf(y - c.y)
				if dy <= float(tg["r"]):
					out["points"] = 10 - mini(9, int(dy / float(tg["r"]) * 10.0))
					out["target"] = ti
					out["end"] = Vector2(tx, y)
					out["t"] = t
					return out
		if p.y < 0.0 or p.x > 120.0:
			break
	out["end"] = p
	out["t"] = t
	return out


static func _seg_dist(a: Vector2, b: Vector2, c: Vector2) -> float:
	var ab: Vector2 = b - a
	var f: float = clampf((c - a).dot(ab) / maxf(0.000001, ab.length_squared()), 0.0, 1.0)
	return (a + ab * f).distance_to(c)


## Tira una flecha (en el instante actual) y apunta el resultado.
## advance: el bot y el analizador saltan el tiempo del vuelo; el juego lo deja correr de verdad.
static func shoot(st: Dictionary, angle: float, power: float, advance: bool = true) -> Dictionary:
	if int(st["arrows"]) <= 0:
		return {}
	var r: Dictionary = fly(st, angle, power, float(st["t"]), true)
	st["arrows"] = int(st["arrows"]) - 1
	st["score"] = int(st["score"]) + int(r["points"])
	st["best"] = maxi(int(st["best"]), int(r["points"]))
	if int(r["balloon"]) >= 0:
		st["balloons"][int(r["balloon"])]["popped"] = true
		st["arrows"] = int(st["arrows"]) + 1
	(st["shots"] as Array).append({"end": r["end"], "points": r["points"], "target": r["target"]})
	if advance:
		st["t"] = float(st["t"]) + maxf(1.2, float(r["t"]) + 0.4)
	return r


static func won(st: Dictionary) -> bool:
	return int(st["score"]) >= int(st["goal"])


static func lost(st: Dictionary) -> bool:
	return int(st["arrows"]) <= 0 and not won(st)


## El bot busca el mejor tiro (angulo y fuerza) para la diana que mas da, sabiendo que se mueve y
## que sopla viento; luego le pone un pulso humano que sale de la semilla.
static func bot_aim(st: Dictionary) -> Vector2:
	var best: Vector2 = Vector2(0.3, 0.8)
	var bv: float = -1.0
	var want_balloon: bool = int(st["arrows"]) <= 2
	for a: int in 40:
		var ang: float = deg_to_rad(-5.0 + float(a) * 1.5)
		for pw: int in 14:
			var power: float = 0.35 + float(pw) * 0.05
			var r: Dictionary = fly(st, ang, power, float(st["t"]))
			var val: float = float(r["points"]) + (6.0 if int(r["balloon"]) >= 0 and want_balloon else 0.0)
			if val > bv:
				bv = val
				best = Vector2(ang, power)
	## Afinar alrededor del mejor.
	var fine: Vector2 = best
	for da: int in range(-6, 7):
		for dp: int in range(-5, 6):
			var cand: Vector2 = best + Vector2(deg_to_rad(float(da) * 0.25), float(dp) * 0.01)
			var r2: Dictionary = fly(st, cand.x, cand.y, float(st["t"]))
			if float(r2["points"]) > bv:
				bv = float(r2["points"])
				fine = cand
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(st["seed"]) * 131 + int(st["arrows"]) * 7
	return fine + Vector2(rng.randfn(0.0, 0.0025), rng.randfn(0.0, 0.004))


static func bot_play(level: Dictionary) -> Dictionary:
	var st: Dictionary = new_state(level)
	var guard: int = 0
	while not won(st) and int(st["arrows"]) > 0 and guard < 40:
		guard += 1
		var aim: Vector2 = bot_aim(st)
		shoot(st, aim.x, aim.y)
	return {"won": won(st), "score": int(st["score"]), "arrows_left": int(st["arrows"]), "time": float(st["t"])}


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var d: Dictionary = parse(level)
	if (d["targets"] as Array).is_empty() or (d["targets"] as Array).size() > 4:
		issues.append("archery_targets")
	for tg: Dictionary in d["targets"]:
		var p: Vector2 = tg["p"]
		if p.x < 10.0 or p.x > 90.0 or p.y < 0.3 or p.y > 25.0 or float(tg["r"]) < 0.25 or float(tg["r"]) > 1.5:
			issues.append("archery_target_place")
			break
	if absf(float(d["wind"])) > 6.0:
		issues.append("archery_wind")
	var arrows: int = int(level.get("arrows", 5))
	var goal: int = int(level.get("goal", 20))
	if arrows < 1 or goal < 1 or goal > arrows * 10:
		issues.append("archery_goal")
	var par: int = 0
	if issues.is_empty():
		var r: Dictionary = bot_play(level)
		if not bool(r["won"]):
			issues.append("archery_too_hard")
		par = int(r["score"])
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": goal, "enemies": 0, "enemy_problems": [], "par": par}
