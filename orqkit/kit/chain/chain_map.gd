extends RefCounted
## Cadena de bolas (tipo Zuma): una fila de bolas de colores avanza por un camino hacia el agujero.
## Desde tu lanzador disparas bolas: si al meterla juntas tres o mas del mismo color, se van. El
## hueco se cierra: si quedan dos del mismo color frente a frente, la parte de delante vuelve atras
## y puede encadenar otra explosion. Si la primera bola llega al agujero, pierdes. Todo va por ticks.
## Nivel: "path" (puntos x, y seguidos en un campo de 600 x 900), "shooter" [x, y], "balls" (colores
## de delante a atras, 0..4), "speed" (avance por tick), "colors", "seed".

const Rules = preload("res://kit/rules.gd")
const TPS: int = 20
const D: float = 34.0
const FIELD: Vector2 = Vector2(600, 900)
const PULL: float = 4.5
const INTRO: float = 7.0
const COOLDOWN: int = 6


static func new_state(level: Dictionary) -> Dictionary:
	var pts: Array = []
	var raw: Array = level.get("path", [])
	var i: int = 0
	while i + 1 < raw.size():
		pts.append(Vector2(float(raw[i]), float(raw[i + 1])))
		i += 2
	if pts.size() < 2:
		pts = [Vector2(50, 100), Vector2(550, 100), Vector2(550, 400), Vector2(50, 400), Vector2(50, 700), Vector2(550, 700)]
	var cum: Array = [0.0]
	for k: int in range(1, pts.size()):
		cum.append(float(cum[k - 1]) + (pts[k] as Vector2).distance_to(pts[k - 1]))
	var balls: Array = []
	for c: Variant in level.get("balls", []):
		balls.append(int(c))
	var sh: Array = level.get("shooter", [300, 780])
	var st: Dictionary = {"pts": pts, "cum": cum, "len": float(cum[cum.size() - 1]), "segs": [{"s": 0.0, "b": balls}],
		"speed": float(level.get("speed", 0.8)), "colors": int(level.get("colors", 4)), "shooter": Vector2(float(sh[0]), float(sh[1])),
		"cur": 0, "next": 0, "cool": 0, "tick": 0, "intro": float(level.get("intro", 420.0)), "score": 0, "combo": 0, "shots": 0,
		"popped": 0, "total": balls.size(), "won": false, "lost": false, "log": [], "rng": int(level.get("seed", 7)) * 7919 + 13}
	st["cur"] = _pick_color(st)
	st["next"] = _pick_color(st)
	st["rules"] = Rules.load_rules(level)
	Rules.hook(st, "on_start")
	return st


static func _rand(st: Dictionary, n: int) -> int:
	st["rng"] = (int(st["rng"]) * 1103515245 + 12345) % 2147483648
	return int(st["rng"]) % maxi(1, n)


## Un color que siga en la cadena (asi siempre hay jugada).
static func _pick_color(st: Dictionary) -> int:
	var have: Array = []
	for sg: Variant in st["segs"]:
		for c: Variant in sg["b"]:
			if not have.has(int(c)):
				have.append(int(c))
	if have.is_empty():
		return _rand(st, int(st["colors"]))
	return have[_rand(st, have.size())]


## Punto y direccion del camino a la distancia s.
static func at(st: Dictionary, s: float) -> Vector2:
	var pts: Array = st["pts"]
	var cum: Array = st["cum"]
	if s <= 0.0:
		return pts[0]
	var lo: int = 0
	var hi: int = cum.size() - 1
	if s >= float(cum[hi]):
		return pts[hi]
	while hi - lo > 1:
		var mid: int = (lo + hi) / 2
		if float(cum[mid]) <= s:
			lo = mid
		else:
			hi = mid
	var t: float = (s - float(cum[lo])) / maxf(0.001, float(cum[hi]) - float(cum[lo]))
	return (pts[lo] as Vector2).lerp(pts[hi], t)


static func tangent(st: Dictionary, s: float) -> Vector2:
	return (at(st, s + 2.0) - at(st, s - 2.0)).normalized()


static func balls_left(st: Dictionary) -> int:
	var n: int = 0
	for sg: Variant in st["segs"]:
		n += (sg["b"] as Array).size()
	return n


static func head(st: Dictionary) -> float:
	return float(st["segs"][0]["s"]) if not (st["segs"] as Array).is_empty() else 0.0


## Un tick: la cadena avanza (empujada desde atras), los huecos se cierran.
static func tick(st: Dictionary) -> void:
	if bool(st["won"]) or bool(st["lost"]):
		return
	st["tick"] = int(st["tick"]) + 1
	if int(st["cool"]) > 0:
		st["cool"] = int(st["cool"]) - 1
	var segs: Array = st["segs"]
	if segs.is_empty():
		return
	## Entrada rapida al principio.
	var v: float = float(st["speed"])
	if head(st) < float(st["intro"]):
		v = INTRO
	var last: Dictionary = segs[segs.size() - 1]
	last["s"] = float(last["s"]) + v
	## Los de delante con el mismo color en el hueco vuelven atras.
	for i: int in range(segs.size() - 2, -1, -1):
		var a: Dictionary = segs[i]
		var b: Dictionary = segs[i + 1]
		if int((a["b"] as Array).back()) == int((b["b"] as Array).front()):
			a["s"] = float(a["s"]) - PULL
	_merge(st)
	if head(st) >= float(st["len"]):
		st["lost"] = true
		(st["log"] as Array).append({"k": "lost"})


## Junta los trozos que se tocan; si en la union hay tres o mas del mismo color, explotan (combo).
static func _merge(st: Dictionary) -> void:
	var segs: Array = st["segs"]
	var i: int = 0
	while i < segs.size() - 1:
		var a: Dictionary = segs[i]
		var b: Dictionary = segs[i + 1]
		var a_tail: float = float(a["s"]) - float((a["b"] as Array).size() - 1) * D
		if float(b["s"]) + D >= a_tail - 0.01:
			var pulled: bool = int((a["b"] as Array).back()) == int((b["b"] as Array).front())
			var join: int = (a["b"] as Array).size()
			a["s"] = float(b["s"]) + float(join) * D
			(a["b"] as Array).append_array(b["b"])
			segs.remove_at(i + 1)
			if pulled:
				st["combo"] = int(st["combo"]) + 1
				if _pop(st, i, join):
					i = 0
					continue
			continue
		i += 1


## Mira la racha de colores alrededor de la bola idx del trozo si; si son 3 o mas, fuera.
static func _pop(st: Dictionary, si: int, idx: int) -> bool:
	var segs: Array = st["segs"]
	var sg: Dictionary = segs[si]
	var b: Array = sg["b"]
	if idx < 0 or idx >= b.size():
		return false
	var c: int = int(b[idx])
	var lo: int = idx
	var hi: int = idx
	while lo > 0 and int(b[lo - 1]) == c:
		lo -= 1
	while hi < b.size() - 1 and int(b[hi + 1]) == c:
		hi += 1
	var n: int = hi - lo + 1
	if n < 3:
		return false
	var front: Array = b.slice(0, lo)
	var rear: Array = b.slice(hi + 1)
	var s0: float = float(sg["s"])
	segs.remove_at(si)
	var at_i: int = si
	if not front.is_empty():
		segs.insert(at_i, {"s": s0, "b": front})
		at_i += 1
	if not rear.is_empty():
		segs.insert(at_i, {"s": s0 - float(hi + 1) * D, "b": rear})
	var mult: int = maxi(1, int(st["combo"]))
	st["score"] = int(st["score"]) + n * 10 * mult
	st["popped"] = int(st["popped"]) + n
	(st["log"] as Array).append({"k": "pop", "at": at(st, s0 - float(lo + hi) * 0.5 * D), "n": n, "combo": mult, "c": c})
	Rules.hook(st, "on_pop", [n])
	if segs.is_empty():
		st["won"] = true
		(st["log"] as Array).append({"k": "won"})
	return true


## Bola que tocaria un disparo en esa direccion: {si, idx, t} o vacio.
static func ray_hit(st: Dictionary, dir: Vector2) -> Dictionary:
	var o: Vector2 = st["shooter"]
	var best: Dictionary = {}
	var r: float = D * 0.5
	for si: int in (st["segs"] as Array).size():
		var sg: Dictionary = st["segs"][si]
		for j: int in (sg["b"] as Array).size():
			var s: float = float(sg["s"]) - float(j) * D
			if s < 0.0:
				break
			var c: Vector2 = at(st, s)
			var oc: Vector2 = c - o
			var t: float = oc.dot(dir)
			if t <= 0.0:
				continue
			var d2: float = oc.length_squared() - t * t
			if d2 > r * r * 1.1:
				continue
			var th: float = t - sqrt(maxf(0.0, r * r * 1.1 - d2))
			if best.is_empty() or th < float(best["t"]):
				best = {"si": si, "idx": j, "t": th, "s": s}
	return best


## Dispara la bola actual hacia dir (vector). Devuelve {hit, at, popped}.
static func fire(st: Dictionary, dir: Vector2) -> Dictionary:
	if bool(st["won"]) or bool(st["lost"]) or int(st["cool"]) > 0:
		return {}
	dir = dir.normalized()
	var color: int = int(st["cur"])
	st["cur"] = st["next"]
	st["next"] = _pick_color(st)
	st["cool"] = COOLDOWN
	st["shots"] = int(st["shots"]) + 1
	st["combo"] = 0
	var h: Dictionary = ray_hit(st, dir)
	if h.is_empty():
		(st["log"] as Array).append({"k": "miss"})
		return {"hit": false, "end": (st["shooter"] as Vector2) + dir * 1400.0, "popped": 0}
	var sg: Dictionary = st["segs"][int(h["si"])]
	var hp: Vector2 = (st["shooter"] as Vector2) + dir * float(h["t"])
	## Delante o detras de la bola tocada segun de que lado llega.
	var idx: int = int(h["idx"])
	if (hp - at(st, float(h["s"]))).dot(tangent(st, float(h["s"]))) < 0.0:
		idx += 1
	(sg["b"] as Array).insert(idx, color)
	sg["s"] = float(sg["s"]) + D
	var p0: int = int(st["popped"])
	st["combo"] = 1
	_pop(st, int(h["si"]), idx)
	_merge(st)
	if int(st["popped"]) == p0:
		st["combo"] = 0
	(st["log"] as Array).append({"k": "insert", "c": color})
	if not bool(st["won"]):
		## Que la bola que tienes siga en la cadena.
		var have: bool = false
		for s2: Variant in st["segs"]:
			if (s2["b"] as Array).has(int(st["cur"])):
				have = true
		if not have:
			st["cur"] = _pick_color(st)
	return {"hit": true, "end": hp, "popped": int(st["popped"]) - p0}


static func swap(st: Dictionary) -> void:
	var c: int = int(st["cur"])
	st["cur"] = st["next"]
	st["next"] = c


# ------------------------------------------------------------------ bot

## Mejor disparo: prueba cada bola visible (y cambiar de bola); prefiere explotar cerca del agujero.
static func bot_shot(st: Dictionary) -> Dictionary:
	var o: Vector2 = st["shooter"]
	var best: Dictionary = {"dir": Vector2.ZERO, "swap": false, "v": -INF}
	var L: float = float(st["len"])
	for sw: bool in [false, true]:
		var cand: Array = []
		for sg: Variant in st["segs"]:
			for j: int in (sg["b"] as Array).size():
				var s: float = float(sg["s"]) - float(j) * D
				if s < 0.0:
					break
				var c: Vector2 = at(st, s)
				var tg: Vector2 = tangent(st, s)
				cand.append([(c + tg * D * 0.3 - o), s])
				cand.append([(c - tg * D * 0.3 - o), s])
		for cd: Variant in cand:
			var s2: Dictionary = st.duplicate(false)
			s2["segs"] = (st["segs"] as Array).duplicate(true)
			s2["log"] = []
			if sw:
				swap(s2)
			s2["cool"] = 0
			var r: Dictionary = fire(s2, cd[0])
			if r.is_empty() or not bool(r["hit"]):
				continue
			var v: float = float(r["popped"]) * 10.0 + float(cd[1]) / L * 6.0
			if bool(s2["won"]):
				v += 1000.0
			## Sin explosion: mejor junto a una del mismo color.
			if int(r["popped"]) == 0:
				v -= 8.0
				v += _pairs(s2) * 0.5
			if sw:
				v -= 0.5
			if v > float(best["v"]):
				best = {"dir": cd[0], "swap": sw, "v": v}
	return best


static func _pairs(st: Dictionary) -> float:
	var n: float = 0.0
	for sg: Variant in st["segs"]:
		var b: Array = sg["b"]
		for j: int in range(1, b.size()):
			if int(b[j]) == int(b[j - 1]):
				n += 1.0
	return n


## Juega el bot: un disparo cada cierto tiempo (como una persona rapida).
static func bot_play(level: Dictionary, every: int = 16, max_ticks: int = 12000) -> Dictionary:
	var st: Dictionary = new_state(level)
	var wait: int = every
	while not bool(st["won"]) and not bool(st["lost"]) and int(st["tick"]) < max_ticks:
		tick(st)
		wait -= 1
		if wait <= 0 and head(st) >= float(st["intro"]) * 0.5:
			wait = every
			var b: Dictionary = bot_shot(st)
			if (b["dir"] as Vector2) != Vector2.ZERO:
				if bool(b["swap"]):
					swap(st)
				fire(st, b["dir"])
	return {"won": bool(st["won"]), "ticks": int(st["tick"]), "shots": int(st["shots"]), "head": snappedf(head(st) / float(st["len"]), 0.01)}


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var st: Dictionary = new_state(level)
	if float(st["len"]) < 1200.0:
		issues.append("chain_short_path")
	if balls_left(st) < 15:
		issues.append("chain_few_balls")
	## El lanzador no puede estar encima del camino.
	for k: int in 60:
		if at(st, float(st["len"]) * float(k) / 60.0).distance_to(st["shooter"]) < D * 1.6:
			issues.append("chain_shooter_on_path")
			break
	var r: Dictionary = {"won": false}
	if issues.is_empty():
		r = bot_play(level)
		if not bool(r["won"]):
			issues.append("chain_bot_failed")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": 0, "enemies": 0, "enemy_problems": [], "bot": r}
