extends RefCounted
## Fusion de frutas (tipo juego de la sandia): sueltas frutas en un tarro; caen con fisica y, si dos
## iguales se tocan, se juntan en la siguiente mas grande. Llega a la fruta objetivo antes de que
## el tarro rebose (una fruta quieta por encima de la linea un rato). Fisica propia por ticks (30
## por segundo) para que el bot, el analizador y la escena den lo mismo.
## Nivel: "goal" (tipo de fruta a conseguir, 4..10), "drop_max" (tipos que pueden salir, 3..5),
## "width" (ancho del tarro), "seed".

const Rules = preload("res://kit/rules.gd")
const TPS: int = 30
const DT: float = 1.0 / 30.0
const H: float = 560.0
const LINE: float = 110.0
const GRAV: float = 900.0
const RADII: Array[float] = [13.0, 17.0, 22.0, 27.0, 33.0, 40.0, 47.0, 55.0, 64.0, 74.0, 86.0]
const POINTS: Array[int] = [1, 3, 6, 10, 15, 21, 28, 36, 45, 55, 66]
const OVER_TICKS: int = 60
const COOLDOWN: int = 15
const ITERS: int = 3


static func new_state(level: Dictionary) -> Dictionary:
	var st: Dictionary = {"w": float(level.get("width", 360.0)), "fruits": [], "next_id": 1, "goal": int(level.get("goal", 7)),
		"drop_max": int(level.get("drop_max", 5)), "cur": 0, "next": 0, "cool": 0, "over": 0, "best": 0, "score": 0, "drops": 0,
		"merges": 0, "tick": 0, "won": false, "lost": false, "log": [], "rng": int(level.get("seed", 7)) * 7919 + 13}
	st["cur"] = _pick(st)
	st["next"] = _pick(st)
	st["rules"] = Rules.load_rules(level)
	Rules.hook(st, "on_start")
	return st


static func _rand(st: Dictionary, n: int) -> int:
	st["rng"] = (int(st["rng"]) * 1103515245 + 12345) % 2147483648
	return int(st["rng"]) % maxi(1, n)


static func _pick(st: Dictionary) -> int:
	## Las pequenas salen mas.
	var m: int = clampi(int(st["drop_max"]), 1, 6)
	var a: int = _rand(st, m)
	var b: int = _rand(st, m)
	return mini(a, b) if _rand(st, 3) > 0 else maxi(a, b)


## Suelta la fruta actual en x (se ajusta para que quepa).
static func drop(st: Dictionary, x: float) -> bool:
	if bool(st["won"]) or bool(st["lost"]) or int(st["cool"]) > 0:
		return false
	var t: int = int(st["cur"])
	var r: float = RADII[t]
	x = clampf(x, r, float(st["w"]) - r)
	(st["fruits"] as Array).append({"id": int(st["next_id"]), "t": t, "p": Vector2(x, r + 4.0), "v": Vector2.ZERO, "age": 0})
	st["next_id"] = int(st["next_id"]) + 1
	st["cur"] = st["next"]
	st["next"] = _pick(st)
	st["cool"] = COOLDOWN
	st["drops"] = int(st["drops"]) + 1
	(st["log"] as Array).append({"k": "drop", "t": t, "x": x})
	return true


static func tick(st: Dictionary) -> void:
	if bool(st["won"]) or bool(st["lost"]):
		return
	st["tick"] = int(st["tick"]) + 1
	if int(st["cool"]) > 0:
		st["cool"] = int(st["cool"]) - 1
	var fr: Array = st["fruits"]
	var w: float = float(st["w"])
	## Dinamica por posiciones: mover, deshacer solapes y sacar la velocidad de lo que se movio
	## (asi una pila quieta tiene velocidad casi cero).
	for f: Variant in fr:
		var fd: Dictionary = f
		fd["o"] = fd["p"]
		fd["v"] = (fd["v"] as Vector2) + Vector2(0, GRAV * DT)
		fd["p"] = (fd["p"] as Vector2) + (fd["v"] as Vector2) * DT
		fd["age"] = int(fd["age"]) + 1
	for it: int in ITERS:
		## Paredes y suelo.
		for f2: Variant in fr:
			var fd2: Dictionary = f2
			var r: float = RADII[int(fd2["t"])]
			var p: Vector2 = fd2["p"]
			p.x = clampf(p.x, r, w - r)
			if p.y > H - r:
				p.y = H - r
			fd2["p"] = p
		## Choques entre frutas (y fusiones).
		var i: int = 0
		while i < fr.size():
			var a: Dictionary = fr[i]
			var j: int = i + 1
			while j < fr.size():
				var b: Dictionary = fr[j]
				var ra: float = RADII[int(a["t"])]
				var rb: float = RADII[int(b["t"])]
				var d: Vector2 = (b["p"] as Vector2) - (a["p"] as Vector2)
				var dist: float = d.length()
				var minr: float = ra + rb
				if dist < minr:
					if int(a["t"]) == int(b["t"]):
						_merge(st, i, j)
						j = fr.size()
						i = -1
						break
					var n: Vector2 = d / dist if dist > 0.001 else Vector2(1, 0)
					var over: float = minr - dist
					var ma: float = ra * ra
					var mb: float = rb * rb
					var ka: float = mb / (ma + mb)
					var kb: float = ma / (ma + mb)
					a["p"] = (a["p"] as Vector2) - n * over * ka
					b["p"] = (b["p"] as Vector2) + n * over * kb
				j += 1
			i += 1
			if bool(st["won"]):
				return
	for f3: Variant in fr:
		var fd3: Dictionary = f3
		var nv: Vector2 = ((fd3["p"] as Vector2) - (fd3.get("o", fd3["p"]) as Vector2)) / DT * 0.99
		if (fd3["p"] as Vector2).y >= H - RADII[int(fd3["t"])] - 0.5:
			nv.x *= 0.85
		fd3["v"] = nv
	## Rebosar: alguna fruta que ya cayo, quieta y por encima de la linea.
	var high: bool = false
	for f4: Variant in fr:
		var fd4: Dictionary = f4
		if int(fd4["age"]) > 45 and (fd4["p"] as Vector2).y - RADII[int(fd4["t"])] < LINE and (fd4["v"] as Vector2).length() < 60.0:
			high = true
	st["over"] = int(st["over"]) + 1 if high else 0
	if int(st["over"]) >= OVER_TICKS:
		st["lost"] = true
		(st["log"] as Array).append({"k": "lost"})


static func _merge(st: Dictionary, i: int, j: int) -> void:
	var fr: Array = st["fruits"]
	var a: Dictionary = fr[i]
	var b: Dictionary = fr[j]
	var t: int = int(a["t"])
	var at: Vector2 = ((a["p"] as Vector2) + (b["p"] as Vector2)) * 0.5
	fr.remove_at(j)
	fr.remove_at(i)
	st["merges"] = int(st["merges"]) + 1
	st["score"] = int(st["score"]) + POINTS[mini(t + 1, POINTS.size() - 1)]
	if t + 1 >= RADII.size():
		## Dos de las mas grandes: desaparecen con premio.
		st["score"] = int(st["score"]) + 100
		(st["log"] as Array).append({"k": "mega", "at": at})
	else:
		fr.append({"id": int(st["next_id"]), "t": t + 1, "p": at, "o": at, "v": ((a["v"] as Vector2) + (b["v"] as Vector2)) * 0.5 + Vector2(0, -60), "age": 50})
		st["next_id"] = int(st["next_id"]) + 1
		st["best"] = maxi(int(st["best"]), t + 1)
		(st["log"] as Array).append({"k": "merge", "at": at, "t": t + 1})
		Rules.hook(st, "on_merge", [t + 1])
		if t + 1 >= int(st["goal"]):
			st["won"] = true
			(st["log"] as Array).append({"k": "won"})


# ------------------------------------------------------------------ bot

## Donde tocaria primero una fruta de radio r soltada en x: {y (centro al tocar), t (tipo tocado)}.
static func landing(st: Dictionary, x: float, r: float) -> Dictionary:
	var best: Dictionary = {"y": H - r, "t": -1}
	for f: Variant in st["fruits"]:
		var p: Vector2 = f["p"]
		var rr: float = RADII[int(f["t"])] + r
		var dx: float = absf(p.x - x)
		if dx < rr:
			var y: float = p.y - sqrt(rr * rr - dx * dx)
			if y < float(best["y"]):
				best = {"y": y, "t": int(f["t"])}
	return best


## Mejor sitio para soltar: encima de una igual, si no junto a parecidas y lo mas bajo posible.
static func bot_x(st: Dictionary) -> float:
	var t: int = int(st["cur"])
	var r: float = RADII[t]
	var w: float = float(st["w"])
	var best_x: float = w * 0.5
	var best_v: float = -INF
	var n: int = 24
	for k: int in n + 1:
		var x: float = r + (w - 2.0 * r) * float(k) / float(n)
		var l: Dictionary = landing(st, x, r)
		var v: float = float(l["y"]) / H * 6.0
		if int(l["t"]) == t:
			v += 12.0 + float(t)
		elif int(l["t"]) >= 0:
			v -= absf(float(int(l["t"]) - t)) * 1.5
			if int(l["t"]) < t:
				v -= 2.0
		## Las grandes, a los lados.
		v -= absf(x - (r if t >= 4 else w * 0.5)) / w * (1.5 if t >= 4 else 0.3)
		if float(l["y"]) - r < LINE + 20.0:
			v -= 30.0
		if v > best_v:
			best_v = v
			best_x = x
	return best_x


static func bot_play(level: Dictionary, max_ticks: int = 30 * 600) -> Dictionary:
	var st: Dictionary = new_state(level)
	while not bool(st["won"]) and not bool(st["lost"]) and int(st["tick"]) < max_ticks:
		if int(st["cool"]) <= 0:
			drop(st, bot_x(st))
		tick(st)
	return {"won": bool(st["won"]), "ticks": int(st["tick"]), "drops": int(st["drops"]), "best": int(st["best"])}


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var goal: int = int(level.get("goal", 7))
	if goal < 4 or goal > 10:
		issues.append("fruit_goal")
	if int(level.get("drop_max", 5)) >= goal:
		issues.append("fruit_drop_max")
	var r: Dictionary = {"won": false}
	if issues.is_empty():
		r = bot_play(level)
		if not bool(r["won"]):
			issues.append("fruit_bot_failed")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": 0, "enemies": 0, "enemy_problems": [], "bot": r}
