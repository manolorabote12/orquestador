extends RefCounted
## Cortar fruta (estilo Fruit Ninja): reglas, simulacion pura, bot y analizador.
## 1 - Mapa (game.json -> levels[i].map): una oleada por fila; cada letra un objeto que sale
##     lanzado desde abajo: F fruta, G fruta dorada (vale 3), B bomba. Ej.: ["FF", "FBF", "FFFG"].
## 2 - Desliza el dedo para cortar. Fruta que cae sin cortar = una vida menos; cortar una bomba
##     = se pierde. Se gana al acabar todas las oleadas con vidas.
## Parametros: "lives" (frutas que se pueden escapar), "speed" (1 = normal), "gap" (segundos
## entre oleadas) y "seed".

const W: float = 720.0
const FLOOR: float = 1420.0
const GRAVITY: float = 1500.0
const R_FRUIT: float = 46.0
const R_BOMB: float = 40.0


static func new_state(level: Dictionary) -> Dictionary:
	var waves: Array = []
	for r: Variant in level.get("map", []):
		var row: String = str(r).strip_edges()
		var items: Array = []
		for i: int in row.length():
			if row[i] in ["F", "G", "B"]:
				items.append(row[i])
		if not items.is_empty():
			waves.append(items)
	var fruits: int = 0
	for wv: Array in waves:
		for it: String in wv:
			if it != "B":
				fruits += 1
	return {"waves": waves, "wave": 0, "next_t": 0.8, "items": [], "time": 0.0, "lives": int(level.get("lives", 3)), "missed": 0,
		"cut": 0, "fruits": fruits, "points": 0, "boom": false, "won": false, "speed": float(level.get("speed", 1.0)),
		"gap": float(level.get("gap", 1.6)), "seed": int(level.get("seed", 1)), "uid": 0, "combo": 0, "best_combo": 0}


static func _rng(st: Dictionary, k: int) -> RandomNumberGenerator:
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.seed = int(st["seed"]) * 7919 + int(st["wave"]) * 104729 + k * 31337
	return r


## 1 - Lanza la siguiente oleada: objetos repartidos a lo ancho, con un poco de desfase.
static func _launch(st: Dictionary) -> void:
	var wv: Array = st["waves"][int(st["wave"])]
	var n: int = wv.size()
	var sp: float = float(st["speed"])
	for k: int in n:
		var r: RandomNumberGenerator = _rng(st, k)
		var x: float = 130.0 + (W - 260.0) * (float(k) + 0.5) / float(n) + r.randf_range(-40.0, 40.0)
		var vy: float = -r.randf_range(1450.0, 1700.0) * sqrt(sp)
		var vx: float = (W * 0.5 - x) * r.randf_range(0.25, 0.6) * sp
		st["uid"] = int(st["uid"]) + 1
		(st["items"] as Array).append({"id": int(st["uid"]), "kind": wv[k], "p": Vector2(x, FLOOR - 10.0), "v": Vector2(vx, vy),
			"delay": float(k) * 0.18 / sp, "cut": false, "spin": r.randf_range(-4.0, 4.0)})
	st["wave"] = int(st["wave"]) + 1
	st["next_t"] = float(st["gap"]) / sp + 1.1


static func step(st: Dictionary, dt: float) -> void:
	if st["won"] or st["boom"] or lost(st):
		return
	st["time"] = float(st["time"]) + dt
	var items: Array = st["items"]
	var sp: float = float(st["speed"])
	if int(st["wave"]) < (st["waves"] as Array).size():
		st["next_t"] = float(st["next_t"]) - dt
		if float(st["next_t"]) <= 0.0 and _airborne(st) <= 1:
			_launch(st)
	var keep: Array = []
	for it: Dictionary in items:
		if float(it["delay"]) > 0.0:
			it["delay"] = float(it["delay"]) - dt
			keep.append(it)
			continue
		it["v"] = (it["v"] as Vector2) + Vector2(0, GRAVITY * sp) * dt
		it["p"] = (it["p"] as Vector2) + (it["v"] as Vector2) * dt
		if (it["p"] as Vector2).y > FLOOR + 60.0 and (it["v"] as Vector2).y > 0.0:
			if not it["cut"] and it["kind"] != "B":
				st["missed"] = int(st["missed"]) + 1
				st["combo"] = 0
			continue
		keep.append(it)
	st["items"] = keep
	if int(st["wave"]) >= (st["waves"] as Array).size() and _airborne(st) == 0 and not lost(st):
		st["won"] = true


static func _airborne(st: Dictionary) -> int:
	var k: int = 0
	for it: Dictionary in st["items"]:
		if not it["cut"]:
			k += 1
	return k


static func lost(st: Dictionary) -> bool:
	return bool(st["boom"]) or int(st["missed"]) >= int(st["lives"])


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var t: float = 0.0 if ab.length_squared() < 0.001 else clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


## Un trazo de a a b: corta lo que toque. Devuelve los objetos cortados (diccionarios).
static func slice(st: Dictionary, a: Vector2, b: Vector2) -> Array:
	var out: Array = []
	if lost(st) or st["won"]:
		return out
	for it: Dictionary in st["items"]:
		if it["cut"] or float(it["delay"]) > 0.0:
			continue
		var rad: float = R_BOMB if it["kind"] == "B" else R_FRUIT
		if _seg_dist(it["p"], a, b) <= rad:
			it["cut"] = true
			out.append(it)
			if it["kind"] == "B":
				st["boom"] = true
				return out
			st["cut"] = int(st["cut"]) + 1
			st["combo"] = int(st["combo"]) + 1
			st["best_combo"] = maxi(int(st["best_combo"]), int(st["combo"]))
			st["points"] = int(st["points"]) + (3 if it["kind"] == "G" else 1) + (1 if int(st["combo"]) >= 3 else 0)
	return out


# ------------------------------------------------------------------ bot

## El bot corta la fruta mas alta que este cerca de su punto mas alto, con un trazo corto que
## no pase cerca de ninguna bomba. Devuelve [a, b] o [].
static func bot_cut(st: Dictionary) -> Array:
	var best: Dictionary = {}
	for it: Dictionary in st["items"]:
		if it["cut"] or it["kind"] == "B" or float(it["delay"]) > 0.0:
			continue
		var p: Vector2 = it["p"]
		## Como una persona: espera a que la fruta este cerca de lo mas alto (va mas lenta).
		if p.y > 1250.0 or p.y < 80.0 or ((it["v"] as Vector2).y < -420.0 and p.y > 500.0):
			continue
		if best.is_empty() or (it["v"] as Vector2).y > (best["v"] as Vector2).y:
			best = it
	if best.is_empty():
		return []
	var c: Vector2 = best["p"]
	for d: Vector2 in [Vector2(1, 0), Vector2(0, 1), Vector2(1, 1).normalized(), Vector2(1, -1).normalized()]:
		var a: Vector2 = c - d * 30.0
		var b: Vector2 = c + d * 30.0
		var safe: bool = true
		for it2: Dictionary in st["items"]:
			if it2["kind"] == "B" and not it2["cut"] and _seg_dist(it2["p"], a, b) < R_BOMB + 34.0:
				safe = false
				break
		if safe:
			return [a, b]
	return []


static func bot_play(level: Dictionary) -> Dictionary:
	var st: Dictionary = new_state(level)
	var dt: float = 1.0 / 30.0
	var cd: float = 0.0
	var guard: int = 0
	while not st["won"] and not lost(st) and guard < 30 * 600:
		guard += 1
		cd -= dt
		if cd <= 0.0:
			var cut: Array = bot_cut(st)
			if not cut.is_empty():
				slice(st, cut[0], cut[1])
				## Un humano rapido: un corte cada ~0,22 s.
				cd = 0.22
		step(st, dt)
	return {"won": bool(st["won"]), "time": float(st["time"]), "missed": int(st["missed"]), "boom": bool(st["boom"]), "points": int(st["points"])}


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var st: Dictionary = new_state(level)
	var waves: Array = st["waves"]
	if waves.size() < 3 or waves.size() > 40:
		issues.append("slice_waves")
	for wv: Array in waves:
		if wv.size() > 7:
			issues.append("slice_wave_big")
			break
	if int(st["fruits"]) < 3:
		issues.append("slice_fruits")
	var par: int = 0
	if issues.is_empty():
		var r: Dictionary = bot_play(level)
		if not bool(r["won"]):
			issues.append("slice_too_hard")
		par = int(r["time"])
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": int(st["fruits"]), "enemies": 0, "enemy_problems": [],
		"par": par}
