extends RefCounted
## Lanza cuchillos (tipo Knife Hit): un tronco gira arriba; toca para lanzar un cuchillo que se clava
## abajo del tronco. Si choca con otro cuchillo clavado, se pierde. Clava todos para partir el tronco;
## las manzanas del borde dan monedas al darles.
## Nivel: "knives" (cuantos lanzar), "stuck" (angulos de los que ya vienen clavados), "apples"
## (angulos de las manzanas) y "spin" (giro: [{"v": grados/s, "d": segundos}, ...] que se repite;
## v negativo gira al reves y 0 se para). Los angulos son del tronco: 0 a la derecha, 90 abajo.
## Todo es determinista: el bot espera a que el hueco de abajo este libre al llegar el cuchillo.

const Rules = preload("res://kit/rules.gd")
## Separacion minima (grados) entre dos cuchillos; manzana: radio en grados para darle.
const GAP: float = 13.0
const APPLE_R: float = 9.0
## Lo que tarda el cuchillo en llegar al tronco.
const FLY_T: float = 0.1


static func new_state(level: Dictionary) -> Dictionary:
	var spin: Array = []
	for s: Variant in level.get("spin", [{"v": 120.0, "d": 1.0}]):
		spin.append({"v": float((s as Dictionary).get("v", 120.0)), "d": maxf(0.1, float((s as Dictionary).get("d", 1.0)))})
	if spin.is_empty():
		spin = [{"v": 120.0, "d": 1.0}]
	var stuck: Array = []
	for a: Variant in level.get("stuck", []):
		stuck.append(fposmod(float(a), 360.0))
	var apples: Array = []
	for a2: Variant in level.get("apples", []):
		apples.append(fposmod(float(a2), 360.0))
	var st: Dictionary = {"rot": 0.0, "t": 0.0, "spin": spin, "si": 0, "st": 0.0, "knives": stuck, "own": 0, "apples": apples, "got": 0,
		"to_throw": clampi(int(level.get("knives", 7)), 1, 30), "thrown": 0, "flying": -1.0, "won": false, "lost": false, "rng": RandomNumberGenerator.new()}
	st["rules"] = Rules.load_rules(level)
	Rules.hook(st, "on_start")
	return st


## Giro del tronco dentro de dt segundos (sin cambiar el estado): [rot, si, st].
static func spin_after(st: Dictionary, dt: float) -> Array:
	var rot: float = float(st["rot"])
	var si: int = int(st["si"])
	var t: float = float(st["st"])
	var left: float = dt
	var spin: Array = st["spin"]
	var guard: int = 0
	while left > 0.0 and guard < 1000:
		guard += 1
		var seg: Dictionary = spin[si]
		var room: float = float(seg["d"]) - t
		var use: float = minf(room, left)
		rot += float(seg["v"]) * use
		t += use
		left -= use
		if t >= float(seg["d"]) - 0.000001:
			t = 0.0
			si = (si + 1) % spin.size()
	return [fposmod(rot, 360.0), si, t]


## Angulo del tronco que esta abajo (donde se clava el cuchillo) con el tronco girado rot.
static func hit_angle(rot: float) -> float:
	return fposmod(90.0 - rot, 360.0)


static func ang_dist(a: float, b: float) -> float:
	var d: float = fposmod(a - b, 360.0)
	return minf(d, 360.0 - d)


## Distancia (grados) del cuchillo clavado mas cercano a un angulo.
static func clearance(st: Dictionary, a: float) -> float:
	var best: float = 360.0
	for k: Variant in st["knives"]:
		best = minf(best, ang_dist(a, float(k)))
	return best


static func throw(st: Dictionary) -> bool:
	if bool(st["won"]) or bool(st["lost"]) or float(st["flying"]) >= 0.0 or int(st["thrown"]) >= int(st["to_throw"]):
		return false
	st["flying"] = FLY_T
	return true


## Avanza dt segundos. Devuelve {} o el impacto: {"ok", "angle", "apple"}.
static func step(st: Dictionary, dt: float) -> Dictionary:
	if bool(st["won"]) or bool(st["lost"]):
		return {}
	var out: Dictionary = {}
	var fl: float = float(st["flying"])
	var adv: float = dt
	if fl >= 0.0 and fl <= dt:
		adv = fl
	var s: Array = spin_after(st, adv)
	st["rot"] = s[0]
	st["si"] = s[1]
	st["st"] = s[2]
	st["t"] = float(st["t"]) + adv
	if fl >= 0.0:
		fl -= adv
		st["flying"] = fl
		if fl <= 0.000001:
			st["flying"] = -1.0
			out = _land(st)
			if adv < dt and not bool(st["lost"]):
				var s2: Array = spin_after(st, dt - adv)
				st["rot"] = s2[0]
				st["si"] = s2[1]
				st["st"] = s2[2]
				st["t"] = float(st["t"]) + dt - adv
	Rules.hook(st, "on_step", [dt])
	return out


static func _land(st: Dictionary) -> Dictionary:
	var a: float = hit_angle(float(st["rot"]))
	var ok: bool = clearance(st, a) >= GAP
	var apple: bool = false
	st["thrown"] = int(st["thrown"]) + 1
	if not ok:
		st["lost"] = true
	else:
		(st["knives"] as Array).append(a)
		st["own"] = int(st["own"]) + 1
		for i: int in range((st["apples"] as Array).size() - 1, -1, -1):
			if ang_dist(a, float(st["apples"][i])) <= APPLE_R:
				(st["apples"] as Array).remove_at(i)
				st["got"] = int(st["got"]) + 1
				apple = true
		if int(st["thrown"]) >= int(st["to_throw"]):
			st["won"] = true
	var out: Dictionary = {"ok": ok, "angle": a, "apple": apple}
	Rules.hook(st, "on_hit", [out])
	return out


## El bot lanza si, cuando llegue el cuchillo, abajo hay hueco con margen.
static func bot_should_throw(st: Dictionary) -> bool:
	if float(st["flying"]) >= 0.0 or bool(st["won"]) or bool(st["lost"]):
		return false
	var s: Array = spin_after(st, FLY_T)
	return clearance(st, hit_angle(float(s[0]))) >= GAP + 2.5


static func bot_play(level: Dictionary, max_t: float = 90.0) -> Dictionary:
	var st: Dictionary = new_state(level)
	var dt: float = 1.0 / 60.0
	while float(st["t"]) < max_t and not bool(st["won"]) and not bool(st["lost"]):
		if bot_should_throw(st):
			throw(st)
		step(st, dt)
	return {"won": bool(st["won"]), "t": float(st["t"]), "apples": int(st["got"])}


## Analizador: cabe lo que hay que clavar, nada nace pisado y el bot lo parte a tiempo.
static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var stuck: Array = level.get("stuck", [])
	var n: int = int(level.get("knives", 0))
	if n < 1 or n > 30:
		issues.append("knife_count")
	if float(stuck.size() + n) * GAP * 1.6 > 360.0:
		issues.append("knife_too_many")
	for i: int in stuck.size():
		for j: int in range(i + 1, stuck.size()):
			if ang_dist(float(stuck[i]), float(stuck[j])) < GAP:
				issues.append("knife_overlap")
	var spin: Array = level.get("spin", [])
	var moving: bool = false
	for s: Variant in spin:
		moving = moving or absf(float((s as Dictionary).get("v", 0.0))) >= 30.0
	if not moving:
		issues.append("knife_no_spin")
	var r: Dictionary = {"won": false, "t": 0.0}
	if issues.is_empty():
		r = bot_play(level)
		if not bool(r["won"]):
			issues.append("knife_unbeatable")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": (level.get("apples", []) as Array).size(), "enemies": 0,
		"enemy_problems": [], "bot_time": r.get("t", 0.0)}
