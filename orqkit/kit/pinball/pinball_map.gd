extends RefCounted
## Pinball: la bola sale por el carril de la derecha, rebota en setas, tirachinas y dianas, y tu la
## mantienes viva con las dos palas. Llega a la puntuacion objetivo antes de perder las bolas.
## Fisica propia (60 ticks por segundo, 4 subpasos) para que el bot y la escena den lo mismo.
## Nivel: "bumpers" (lista de [x, y]), "targets" (dianas: lista de [x, y]), "goal" (puntos),
## "balls" (bolas), "gravity", "seed". La mesa mide 480 x 800.

const Rules = preload("res://kit/rules.gd")
const TPS: int = 60
const SUB: int = 4
const W: float = 480.0
const H: float = 800.0
const R: float = 10.0
const FLIP_LEN: float = 88.0
const FLIP_W: float = 9.0
const FLIP_REST: float = 0.52
const FLIP_UP: float = -0.45
const FLIP_SPEED: float = 22.0
const BUMPER_R: float = 24.0
const MAXV: float = 1500.0
## Paredes fijas (segmentos): marco, carril de salida, guias de las palas.
const WALLS: Array = [
	[20, 790, 20, 120], [20, 120, 60, 50], [60, 50, 140, 20], [140, 20, 340, 20], [340, 20, 420, 50], [420, 50, 465, 110],
	[465, 110, 465, 790], [432, 790, 432, 230],
	[20, 560, 142, 690], [432, 560, 338, 690],
]
## Tirachinas (rebotan con fuerza): encima de las palas.
const SLINGS: Array = [[66, 520, 112, 610], [386, 520, 340, 610]]
const PIVOTS: Array = [Vector2(142, 690), Vector2(338, 690)]


static func new_state(level: Dictionary) -> Dictionary:
	var bumpers: Array = []
	for b: Variant in level.get("bumpers", [[160, 220], [320, 220], [240, 320]]):
		bumpers.append({"p": Vector2(float(b[0]), float(b[1])), "flash": 0})
	var targets: Array = []
	for t: Variant in level.get("targets", []):
		targets.append({"p": Vector2(float(t[0]), float(t[1])), "down": false})
	var st: Dictionary = {"bumpers": bumpers, "targets": targets, "lanes": [false, false, false], "flip": [FLIP_REST, FLIP_REST], "flip_w": [0.0, 0.0],
		"ball": {}, "balls": int(level.get("balls", 3)), "goal": int(level.get("goal", 5000)), "score": 0, "mult": 1,
		"gravity": float(level.get("gravity", 620.0)), "tick": 0, "wait": 30, "won": false, "lost": false, "log": [],
		"rng": int(level.get("seed", 7)) * 7919 + 13, "drained": 0}
	st["rules"] = Rules.load_rules(level)
	Rules.hook(st, "on_start")
	return st


static func _rand(st: Dictionary) -> float:
	st["rng"] = (int(st["rng"]) * 1103515245 + 12345) % 2147483648
	return float(int(st["rng"]) % 100000) / 100000.0


static func _launch(st: Dictionary) -> void:
	st["ball"] = {"p": Vector2(448, 760), "v": Vector2(0, -1180.0 - 160.0 * _rand(st))}
	(st["log"] as Array).append({"k": "launch"})


## Extremo de cada pala segun su angulo (la izquierda apunta a la derecha y al reves).
static func flipper_tip(st: Dictionary, i: int) -> Vector2:
	var a: float = float(st["flip"][i])
	var piv: Vector2 = PIVOTS[i]
	var dir: Vector2 = Vector2(cos(a), sin(a)) if i == 0 else Vector2(-cos(a), sin(a))
	return piv + dir * FLIP_LEN


## Un tick: left y right, si esa pala esta pulsada.
static func tick(st: Dictionary, left: bool, right: bool) -> void:
	if bool(st["won"]) or bool(st["lost"]):
		return
	st["tick"] = int(st["tick"]) + 1
	for b: Variant in st["bumpers"]:
		if int(b["flash"]) > 0:
			b["flash"] = int(b["flash"]) - 1
	var dt: float = 1.0 / float(TPS * SUB)
	var press: Array = [left, right]
	if (st["ball"] as Dictionary).is_empty():
		st["wait"] = int(st["wait"]) - 1
		if int(st["wait"]) <= 0:
			_launch(st)
		_move_flippers(st, press, 1.0 / float(TPS))
		return
	for s: int in SUB:
		_move_flippers(st, press, dt)
		_step_ball(st, dt)
		if (st["ball"] as Dictionary).is_empty() or bool(st["won"]):
			break


static func _move_flippers(st: Dictionary, press: Array, dt: float) -> void:
	for i: int in 2:
		var a: float = float(st["flip"][i])
		var target: float = FLIP_UP if bool(press[i]) else FLIP_REST
		var sp: float = FLIP_SPEED if bool(press[i]) else FLIP_SPEED * 0.6
		var na: float = move_toward(a, target, sp * dt)
		st["flip_w"][i] = (na - a) / dt
		st["flip"][i] = na


static func _closest(a: Vector2, b: Vector2, p: Vector2) -> Vector2:
	var ab: Vector2 = b - a
	var t: float = clampf((p - a).dot(ab) / maxf(0.0001, ab.length_squared()), 0.0, 1.0)
	return a + ab * t


static func _bounce(ball: Dictionary, n: Vector2, e: float, surf: Vector2 = Vector2.ZERO) -> void:
	var v: Vector2 = ball["v"]
	var rel: Vector2 = v - surf
	var vn: float = rel.dot(n)
	if vn < 0.0:
		ball["v"] = v - n * vn * (1.0 + e)


static func _step_ball(st: Dictionary, dt: float) -> void:
	var ball: Dictionary = st["ball"]
	var v: Vector2 = ball["v"]
	v.y += float(st["gravity"]) * dt
	if v.length() > MAXV:
		v = v.normalized() * MAXV
	ball["v"] = v
	ball["p"] = (ball["p"] as Vector2) + v * dt
	var p: Vector2 = ball["p"]
	## Paredes.
	for w: Variant in WALLS:
		_seg(ball, Vector2(float(w[0]), float(w[1])), Vector2(float(w[2]), float(w[3])), 0.0, 0.45, Vector2.ZERO)
	## Tirachinas.
	for sl: Variant in SLINGS:
		if _seg(ball, Vector2(float(sl[0]), float(sl[1])), Vector2(float(sl[2]), float(sl[3])), 0.0, 0.45, Vector2.ZERO):
			var a: Vector2 = Vector2(float(sl[0]), float(sl[1]))
			var b: Vector2 = Vector2(float(sl[2]), float(sl[3]))
			var n: Vector2 = (b - a).orthogonal().normalized()
			if n.dot(Vector2(240, 600) - a) < 0.0:
				n = -n
			ball["v"] = (ball["v"] as Vector2) + n * 380.0
			_score(st, 10, ball["p"], "sling")
	## Palas (con la velocidad de su superficie).
	for i: int in 2:
		var piv: Vector2 = PIVOTS[i]
		var tip: Vector2 = flipper_tip(st, i)
		var c: Vector2 = _closest(piv, tip, ball["p"])
		var arm: Vector2 = c - piv
		var w2: float = float(st["flip_w"][i]) * (1.0 if i == 0 else -1.0)
		var surf: Vector2 = Vector2(-arm.y, arm.x) * w2
		_seg(ball, piv, tip, FLIP_W, 0.25, surf)
	## Setas.
	for bm: Variant in st["bumpers"]:
		var d: Vector2 = (ball["p"] as Vector2) - (bm["p"] as Vector2)
		if d.length() < BUMPER_R + R:
			var n2: Vector2 = d.normalized() if d.length() > 0.01 else Vector2(0, -1)
			ball["p"] = (bm["p"] as Vector2) + n2 * (BUMPER_R + R)
			var sp: float = maxf((ball["v"] as Vector2).length(), 620.0)
			ball["v"] = n2 * sp
			bm["flash"] = 8
			_score(st, 100, bm["p"], "bumper")
	## Dianas: tocarlas las tumba; todas tumbadas, premio y vuelven.
	for tg: Variant in st["targets"]:
		if bool(tg["down"]):
			continue
		var tp: Vector2 = tg["p"]
		if _seg(ball, tp + Vector2(-14, 0), tp + Vector2(14, 0), 4.0, 0.5, Vector2.ZERO):
			tg["down"] = true
			_score(st, 250, tp, "target")
			var all_down: bool = true
			for t2: Variant in st["targets"]:
				if not bool(t2["down"]):
					all_down = false
			if all_down:
				_score(st, 1500, tp, "bank")
				st["mult"] = mini(int(st["mult"]) + 1, 4)
				for t3: Variant in st["targets"]:
					t3["down"] = false
	## Pasillos de arriba: encender los tres sube el multiplicador.
	var bp: Vector2 = ball["p"]
	if bp.y < 95.0 and bp.y > 60.0:
		for li: int in 3:
			if absf(bp.x - (180.0 + 60.0 * float(li))) < 14.0 and not bool(st["lanes"][li]):
				st["lanes"][li] = true
				_score(st, 50, bp, "lane")
		if bool(st["lanes"][0]) and bool(st["lanes"][1]) and bool(st["lanes"][2]):
			st["lanes"] = [false, false, false]
			st["mult"] = mini(int(st["mult"]) + 1, 4)
			_score(st, 500, bp, "lanes")
	## Se cuela.
	if bp.y > H + 20.0 or bp.x < 0.0 or bp.x > W:
		st["ball"] = {}
		st["balls"] = int(st["balls"]) - 1
		st["drained"] = int(st["drained"]) + 1
		st["mult"] = 1
		(st["log"] as Array).append({"k": "drain"})
		if int(st["balls"]) <= 0:
			st["lost"] = true
		else:
			st["wait"] = 45


static func _seg(ball: Dictionary, a: Vector2, b: Vector2, thick: float, e: float, surf: Vector2) -> bool:
	var p: Vector2 = ball["p"]
	var c: Vector2 = _closest(a, b, p)
	var d: Vector2 = p - c
	var rr: float = R + thick
	if d.length_squared() >= rr * rr:
		return false
	var dist: float = d.length()
	var n: Vector2 = d / dist if dist > 0.001 else (b - a).orthogonal().normalized()
	ball["p"] = c + n * rr
	_bounce(ball, n, e, surf)
	return true


static func _score(st: Dictionary, n: int, at: Vector2, kind: String) -> void:
	var pts: int = n * int(st["mult"])
	st["score"] = int(st["score"]) + pts
	(st["log"] as Array).append({"k": "score", "n": pts, "at": at, "what": kind})
	Rules.hook(st, "on_score", [kind, pts])
	if int(st["score"]) >= int(st["goal"]):
		st["won"] = true


# ------------------------------------------------------------------ bot

## Palas del bot: golpea cuando la bola baja por encima de la pala (y no la tiene ya arriba).
static func bot_flips(st: Dictionary) -> Array:
	var out: Array = [false, false]
	var ball: Dictionary = st["ball"]
	if ball.is_empty():
		return out
	var p: Vector2 = ball["p"]
	var v: Vector2 = ball["v"]
	for i: int in 2:
		var piv: Vector2 = PIVOTS[i]
		var tip_rest: Vector2 = piv + (Vector2(cos(FLIP_REST), sin(FLIP_REST)) if i == 0 else Vector2(-cos(FLIP_REST), sin(FLIP_REST))) * FLIP_LEN
		## Cerca del eje la pala apenas empuja: ahi se deja rodar la bola hacia la punta.
		var start: Vector2 = piv.lerp(tip_rest, 0.3)
		var lo: float = minf(start.x, tip_rest.x) - 6.0
		var hi: float = maxf(start.x, tip_rest.x) + 6.0
		## Prediccion corta: donde estara la bola en unas centesimas.
		var q: Vector2 = p + v * 0.045
		var over: bool = q.x > lo and q.x < hi and q.y > piv.y - 70.0 and q.y < tip_rest.y + 12.0
		## Golpes cortos: si la bola se queda en la pala, soltar y volver a golpear.
		var held: int = int((st.get("bot_hold", [0, 0]) as Array)[i])
		if over and v.y > -150.0 and held < 10:
			out[i] = true
	var h: Array = st.get("bot_hold", [0, 0])
	for j: int in 2:
		h[j] = int(h[j]) + 1 if bool(out[j]) else (0 if int(h[j]) < 0 or int(h[j]) >= 10 else int(h[j]))
		if int(h[j]) >= 10 and not bool(out[j]):
			h[j] = -8
		if int(h[j]) < 0:
			h[j] = int(h[j]) + 1
			out[j] = false
	st["bot_hold"] = h
	return out


static func bot_play(level: Dictionary, max_ticks: int = 60 * 300) -> Dictionary:
	var st: Dictionary = new_state(level)
	while not bool(st["won"]) and not bool(st["lost"]) and int(st["tick"]) < max_ticks:
		var f: Array = bot_flips(st)
		tick(st, bool(f[0]), bool(f[1]))
	return {"won": bool(st["won"]), "ticks": int(st["tick"]), "score": int(st["score"]), "drained": int(st["drained"])}


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var st: Dictionary = new_state(level)
	for b: Variant in st["bumpers"]:
		var bp: Vector2 = b["p"]
		if bp.x < 60.0 or bp.x > 400.0 or bp.y < 90.0 or bp.y > 470.0:
			issues.append("pinball_bumper_out")
			break
	var r: Dictionary = {"won": false}
	if issues.is_empty():
		r = bot_play(level)
		if not bool(r["won"]):
			issues.append("pinball_bot_failed")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": 0, "enemies": 0, "enemy_problems": [], "bot": r}
