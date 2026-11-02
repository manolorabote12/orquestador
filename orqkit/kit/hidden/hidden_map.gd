extends RefCounted
## Buscar objetos: una escena llena de figuras (las del dibujo por datos de spotdiff/scene_draw.gd)
## y abajo la lista de las que hay que encontrar. Tocas una y, si es de la lista, se marca.
## Nivel: "shapes" (figuras; se dibujan en ese orden, las de despues tapan), "targets" (indices
## de las que hay que encontrar: cada una es la UNICA de su clase en la escena), "time" (segundos,
## 0 = sin limite), "misses" (fallos permitidos, 0 = sin limite), "hints" (pistas), "bg", "ground".

const Rules = preload("res://kit/rules.gd")
const MIN_SIZE: float = 0.05
## Figuras que se dibujan casi igual: cuentan como la misma (no puede haber una "gemela" de la buscada).
const FAMILY: Dictionary = {"kite": "tri", "balloon": "circle", "gift": "square", "cloud": "bush"}


static func family(k: String) -> String:
	return str(FAMILY.get(k, k))


static func new_state(level: Dictionary) -> Dictionary:
	var st: Dictionary = {"shapes": (level.get("shapes", []) as Array).duplicate(true), "targets": (level.get("targets", []) as Array).duplicate(),
		"found": [], "misses": 0, "max_misses": int(level.get("misses", 0)), "time": float(level.get("time", 0)), "elapsed": 0.0,
		"hints": int(level.get("hints", 2)), "hinted": -1, "won": false, "lost": false, "taps": 0}
	st["rules"] = Rules.load_rules(level)
	Rules.hook(st, "on_start")
	return st


## Radio de una figura en coordenadas 0-1 (las del nivel).
static func radius(sh: Dictionary) -> float:
	return float(sh.get("s", 0.1)) * 0.5


## Que figura de la lista (sin encontrar) hay en el punto p (0-1). -1 si ninguna.
static func target_at(st: Dictionary, p: Vector2) -> int:
	var best: int = -1
	var bd: float = 1e9
	for t: Variant in st["targets"]:
		var i: int = int(t)
		if (st["found"] as Array).has(i):
			continue
		var sh: Dictionary = st["shapes"][i]
		var d: float = p.distance_to(Vector2(float(sh["x"]), float(sh["y"])))
		if d <= maxf(radius(sh) * 1.25, 0.05) and d < bd:
			bd = d
			best = i
	return best


## Toque en p (0-1): "found", "miss" o "" (si ya ha acabado).
static func tap(st: Dictionary, p: Vector2) -> String:
	if bool(st["won"]) or bool(st["lost"]):
		return ""
	st["taps"] = int(st["taps"]) + 1
	var i: int = target_at(st, p)
	if i >= 0:
		(st["found"] as Array).append(i)
		if int(st["hinted"]) == i:
			st["hinted"] = -1
		Rules.hook(st, "on_found", [i])
		if (st["found"] as Array).size() >= (st["targets"] as Array).size():
			st["won"] = true
		return "found"
	st["misses"] = int(st["misses"]) + 1
	Rules.hook(st, "on_miss", [p])
	if int(st["max_misses"]) > 0 and int(st["misses"]) >= int(st["max_misses"]):
		st["lost"] = true
	return "miss"


static func step(st: Dictionary, dt: float) -> void:
	if bool(st["won"]) or bool(st["lost"]):
		return
	st["elapsed"] = float(st["elapsed"]) + dt
	if float(st["time"]) > 0.0 and float(st["elapsed"]) >= float(st["time"]):
		st["lost"] = true


## Pista: senala una figura que falta (la primera de la lista).
static func use_hint(st: Dictionary) -> int:
	if int(st["hints"]) <= 0 or bool(st["won"]) or bool(st["lost"]):
		return -1
	for t: Variant in st["targets"]:
		if not (st["found"] as Array).has(int(t)):
			st["hints"] = int(st["hints"]) - 1
			st["hinted"] = int(t)
			return int(t)
	return -1


## Bot: toca el centro de la siguiente figura que falta.
static func bot_point(st: Dictionary) -> Vector2:
	for t: Variant in st["targets"]:
		if not (st["found"] as Array).has(int(t)):
			var sh: Dictionary = st["shapes"][int(t)]
			return Vector2(float(sh["x"]), float(sh["y"]))
	return Vector2(-1, -1)


## Cuanto de la figura i tapan las que se dibujan despues (0 = nada, 1 = entera).
static func covered(shapes: Array, i: int) -> float:
	var a: Dictionary = shapes[i]
	var pa: Vector2 = Vector2(float(a["x"]), float(a["y"]))
	var ra: float = radius(a)
	var worst: float = 0.0
	for j: int in range(i + 1, shapes.size()):
		var b: Dictionary = shapes[j]
		var d: float = pa.distance_to(Vector2(float(b["x"]), float(b["y"])))
		var rb: float = radius(b)
		if d < ra + rb:
			worst = maxf(worst, clampf((ra + rb - d) / (2.0 * ra), 0.0, 1.0))
	return worst


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var shapes: Array = level.get("shapes", [])
	var targets: Array = level.get("targets", [])
	if targets.size() < 3 or targets.size() > 10:
		issues.append("hidden_target_count")
	var seen: Dictionary = {}
	for t: Variant in targets:
		var i: int = int(t)
		if i < 0 or i >= shapes.size() or seen.has(i):
			issues.append("hidden_bad_target")
			continue
		seen[i] = true
		var sh: Dictionary = shapes[i]
		var kind: String = family(str(sh.get("k", "")))
		var same: int = 0
		for o: Variant in shapes:
			if family(str((o as Dictionary).get("k", ""))) == kind:
				same += 1
		if same != 1:
			issues.append("hidden_not_unique")
		if float(sh.get("s", 0)) < MIN_SIZE:
			issues.append("hidden_too_small")
		var x: float = float(sh.get("x", 0))
		var y: float = float(sh.get("y", 0))
		if x < 0.05 or x > 0.95 or y < 0.05 or y > 0.95:
			issues.append("hidden_off_scene")
		if covered(shapes, i) > 0.35:
			issues.append("hidden_covered")
	if float(level.get("time", 0)) > 0.0 and float(level.get("time", 0)) < 4.0 * targets.size():
		issues.append("hidden_time_short")
	var r: Dictionary = {"won": false}
	if issues.is_empty():
		var st: Dictionary = new_state(level)
		while not bool(st["won"]) and not bool(st["lost"]):
			var p: Vector2 = bot_point(st)
			if p.x < 0.0 or tap(st, p) != "found":
				break
			step(st, 1.5)
		if not bool(st["won"]):
			issues.append("hidden_bot_failed")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": targets.size(), "enemies": 0, "enemy_problems": []}
