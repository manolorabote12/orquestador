extends RefCounted
## Baloncesto 3D callejero (media pista, 1-3 por equipo): los dos equipos atacan la misma canasta.
## Tiro con barra de tiempo (suelta en la zona verde), pases, robos, tapones, rebotes, triples y
## reloj de posesion. Reglas, simulacion pura, IA de los dos equipos, bot y analizador.
## Coordenadas en metros: x a lo ancho (0-W), y desde la linea de fondo (la canasta en y = 1.6)
## hasta medio campo (y = L). La camara mira desde medio campo hacia la canasta.
## 1 - Mapa (game.json -> levels[i].map): no se usa para la pista; la fila "#semilla" da el azar.
## 2 - Parametros: "players" (por equipo, 1-3), "skill" (0-1, rivales), "mates" (0-1, tus
##     companeros), "points" (para ganar, canastas de 2 y triples de 3), "time" (segundos; si se
##     acaba gana el que va por delante y, si hay empate, la siguiente canasta).
## 3 - Reglas de la calle: tras un rebote defensivo o un robo hay que sacar el balon fuera de la
##     linea de triple antes de tirar; tras canasta, el otro equipo saca desde arriba.

const W: float = 15.0
const L: float = 14.0
const HOOP: Vector2 = Vector2(7.5, 1.6)
const ARC: float = 6.0
const CHECK: Vector2 = Vector2(7.5, 9.6)
const PR: float = 0.4
const SPEED: float = 6.2
const SHOT_CLOCK: float = 12.0
const PERFECT: float = 0.78
## Puestos de ataque sin balon: esquinas, alas y arriba.
const SPOTS: Array[Vector2] = [Vector2(1.2, 1.8), Vector2(13.8, 1.8), Vector2(2.4, 6.4), Vector2(12.6, 6.4), Vector2(7.5, 8.4), Vector2(4.6, 3.4), Vector2(10.4, 3.4)]


static func new_state(level: Dictionary) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var seed_v: int = int(level.get("seed", 1))
	for r: Variant in level.get("map", []):
		var t: String = str(r)
		if t.begins_with("#") and t.substr(1).is_valid_int():
			seed_v = int(t.substr(1))
	rng.seed = seed_v
	var n: int = clampi(int(level.get("players", 2)), 1, 3)
	var st: Dictionary = {"rng": rng, "t": 0.0, "time": clampf(float(level.get("time", 150.0)), 40.0, 600.0),
		"points": clampi(int(level.get("points", 11)), 3, 41), "score": [0, 0], "over": false, "won": false, "events": [],
		"players": [], "n": n, "owner": -1, "poss": 0, "clear": false, "clock": SHOT_CLOCK, "pause_t": 0.0, "ctrl": 0,
		"ball": {"mode": "held", "p": CHECK, "h": 1.0, "from": Vector2.ZERO, "to": Vector2.ZERO, "fh": 0.0, "th": 0.0, "t": 0.0, "dur": 1.0,
			"made": false, "pts": 0, "shooter": -1, "target": -1},
		"skill": clampf(float(level.get("skill", 0.4)), 0.0, 1.0), "mates": clampf(float(level.get("mates", 0.6)), 0.0, 1.0),
		"sudden": false}
	for team: int in 2:
		for k: int in n:
			(st["players"] as Array).append({"i": team * n + k, "team": team, "slot": k, "p": CHECK, "v": Vector2.ZERO, "face": Vector2(0, -1),
				"skill": float(st["mates"]) if team == 0 else float(st["skill"]), "think": rng.randf() * 0.1, "goal": CHECK,
				"charge": 0.0, "aim_c": 0.0, "jump": 0.0, "steal_cd": 0.0, "hold_t": 0.0, "spot": -1})
	check_ball(st, 0)
	return st


static func _ev(st: Dictionary, kind: String, extra: Dictionary = {}) -> void:
	var e: Dictionary = {"kind": kind}
	e.merge(extra)
	(st["events"] as Array).append(e)


static func team_of(st: Dictionary, i: int) -> int:
	return -1 if i < 0 else int(st["players"][i]["team"])


## Saque desde arriba: el equipo "team" ataca, cada defensor delante de su par.
static func check_ball(st: Dictionary, team: int) -> void:
	var n: int = int(st["n"])
	st["poss"] = team
	st["clear"] = false
	st["clock"] = SHOT_CLOCK
	for pl: Dictionary in st["players"]:
		var k: int = int(pl["slot"])
		var off: Vector2 = Vector2(0, 0)
		if k > 0:
			off = Vector2(-4.5 if k == 1 else 4.5, -2.4)
		var p: Vector2 = CHECK + off
		if int(pl["team"]) != team:
			p += (HOOP - p).normalized() * 1.3
		pl["p"] = p
		pl["v"] = Vector2.ZERO
		pl["charge"] = 0.0
		pl["jump"] = 0.0
		pl["hold_t"] = 0.0
	var b: Dictionary = st["ball"]
	b["mode"] = "held"
	st["owner"] = team * n
	b["p"] = CHECK
	st["pause_t"] = 0.9


# ------------------------------------------------------------------ paso

## inp: el jugador que manejas: {"move": Vector2, "shoot": bool (mantener y soltar; en defensa,
## saltar a taponar), "pass": bool (en defensa, robar)}. Sin inp todos piensan solos.
static func step(st: Dictionary, inp: Dictionary, dt: float) -> void:
	if bool(st["over"]):
		return
	st["t"] = float(st["t"]) + dt
	if float(st["pause_t"]) > 0.0:
		st["pause_t"] = float(st["pause_t"]) - dt
		return
	_pick_controlled(st)
	for pl: Dictionary in st["players"]:
		pl["steal_cd"] = maxf(0.0, float(pl["steal_cd"]) - dt)
		pl["jump"] = maxf(0.0, float(pl["jump"]) - dt)
		if int(pl["i"]) == int(st["ctrl"]) and not inp.is_empty():
			_human(st, pl, inp, dt)
		else:
			_ai_charge(st, pl, dt)
			pl["think"] = float(pl["think"]) - dt
			if float(pl["think"]) <= 0.0:
				pl["think"] = 0.1 + (1.0 - float(pl["skill"])) * 0.18
				think(st, pl)
		_move(st, pl, dt)
	_separate(st)
	_ball(st, dt)
	## Reloj de posesion: si se acaba, el balon es del otro equipo.
	if str(st["ball"]["mode"]) == "held" or str(st["ball"]["mode"]) == "pass":
		st["clock"] = float(st["clock"]) - dt
		if float(st["clock"]) <= 0.0:
			_ev(st, "shot_clock")
			check_ball(st, 1 - int(st["poss"]))
	if float(st["t"]) >= float(st["time"]) and not bool(st["over"]) and not bool(st["sudden"]):
		var s: Array = st["score"]
		if int(s[0]) != int(s[1]):
			_end(st)
		else:
			st["sudden"] = true
			_ev(st, "sudden")


static func _end(st: Dictionary) -> void:
	st["over"] = true
	var s: Array = st["score"]
	st["won"] = int(s[0]) > int(s[1])
	_ev(st, "end")


## El que manejas: el de tu equipo con el balon; si no, el mas cercano al balon (o a quien lo lleva).
static func _pick_controlled(st: Dictionary) -> void:
	var owner: int = int(st["owner"])
	var n: int = int(st["n"])
	if owner >= 0 and owner < n:
		st["ctrl"] = owner
		return
	var bp: Vector2 = ball_pos(st)
	var cur: int = int(st["ctrl"])
	var best: int = cur
	var bd: float = (st["players"][cur]["p"] as Vector2).distance_to(bp) - 1.5
	for k: int in n:
		var d: float = (st["players"][k]["p"] as Vector2).distance_to(bp)
		if d < bd:
			bd = d
			best = k
	st["ctrl"] = best


static func ball_pos(st: Dictionary) -> Vector2:
	var b: Dictionary = st["ball"]
	if str(b["mode"]) == "held" and int(st["owner"]) >= 0:
		return st["players"][int(st["owner"])]["p"]
	return b["p"]


static func _human(st: Dictionary, pl: Dictionary, inp: Dictionary, dt: float) -> void:
	var mv: Vector2 = inp.get("move", Vector2.ZERO)
	if mv.length() > 1.0:
		mv = mv.normalized()
	pl["want_v"] = mv * SPEED
	if mv.length() > 0.2:
		pl["face"] = mv.normalized()
	var has: bool = int(st["owner"]) == int(pl["i"]) and str(st["ball"]["mode"]) == "held"
	var shoot: bool = bool(inp.get("shoot", false))
	if has:
		## Mantener carga la barra; al soltar se tira.
		if shoot:
			pl["charge"] = minf(1.3, float(pl["charge"]) + dt / 0.9)
		elif float(pl["charge"]) > 0.0:
			var c: float = float(pl["charge"])
			pl["charge"] = 0.0
			shoot_ball(st, pl, c)
		elif bool(inp.get("pass", false)):
			var to: Dictionary = best_pass(st, pl)
			if not to.is_empty():
				pass_ball(st, pl, to)
	else:
		pl["charge"] = 0.0
		if shoot and float(pl["jump"]) <= 0.0:
			_jump(st, pl)
		elif bool(inp.get("pass", false)):
			_steal(st, pl)


static func _move(st: Dictionary, pl: Dictionary, dt: float) -> void:
	var speed: float = SPEED * (0.8 + 0.2 * float(pl["skill"]))
	if int(st["owner"]) == int(pl["i"]):
		speed *= 0.9
	if float(pl["charge"]) > 0.0:
		speed *= 0.2
	var want: Vector2
	if pl.has("want_v"):
		want = (pl["want_v"] as Vector2).limit_length(speed)
		pl.erase("want_v")
	else:
		var to: Vector2 = (pl["goal"] as Vector2) - (pl["p"] as Vector2)
		want = to.normalized() * speed * clampf(to.length() / 0.8, 0.0, 1.0) if to.length() > 0.08 else Vector2.ZERO
	var v: Vector2 = (pl["v"] as Vector2).move_toward(want, 30.0 * dt)
	pl["v"] = v
	var p: Vector2 = (pl["p"] as Vector2) + v * dt
	p.x = clampf(p.x, 0.3, W - 0.3)
	p.y = clampf(p.y, 0.3, L - 0.3)
	## Nadie se mete debajo del aro.
	if p.distance_to(HOOP) < 0.55:
		p = HOOP + (p - HOOP).normalized() * 0.55
	pl["p"] = p
	if v.length() > 0.5:
		pl["face"] = v.normalized()
	if int(st["owner"]) == int(pl["i"]):
		pl["hold_t"] = float(pl["hold_t"]) + dt
		## Fuera de la linea de triple ya se ha "sacado" el balon.
		if bool(st["clear"]) and p.distance_to(HOOP) > ARC + 0.3:
			st["clear"] = false
			_ev(st, "cleared")


static func _separate(st: Dictionary) -> void:
	var ps: Array = st["players"]
	for a: int in ps.size():
		for b: int in range(a + 1, ps.size()):
			var d: Vector2 = (ps[a]["p"] as Vector2) - (ps[b]["p"] as Vector2)
			var l: float = d.length()
			if l < PR * 2.0 and l > 0.001:
				var push: Vector2 = d / l * (PR * 2.0 - l) * 0.5
				ps[a]["p"] = (ps[a]["p"] as Vector2) + push
				ps[b]["p"] = (ps[b]["p"] as Vector2) - push


# ------------------------------------------------------------------ tiros, pases y robos

## Probabilidad de meter desde p: cerca del aro casi seguro; de lejos menos; con un defensor
## encima mucho menos. "c" es donde se solto la barra (la zona verde es PERFECT).
static func shot_chance(st: Dictionary, pl: Dictionary, p: Vector2, c: float) -> float:
	var d: float = p.distance_to(HOOP)
	var base: float = clampf(0.92 - 0.065 * maxf(0.0, d - 1.0), 0.12, 0.92)
	var timing: float = 1.0 - minf(1.0, absf(c - PERFECT) / 0.35) * 0.8
	var dd: float = _defender_dist(st, pl, p)
	var contest: float = 1.0 if dd > 1.8 else 0.5 + 0.5 * dd / 1.8
	return clampf(base * timing * contest * (0.8 + 0.3 * float(pl["skill"])), 0.02, 0.97)


static func _defender_dist(st: Dictionary, pl: Dictionary, p: Vector2) -> float:
	var best: float = INF
	for o: Dictionary in st["players"]:
		if int(o["team"]) != int(pl["team"]):
			best = minf(best, (o["p"] as Vector2).distance_to(p))
	return best


static func shoot_ball(st: Dictionary, pl: Dictionary, c: float) -> void:
	if bool(st["clear"]):
		_ev(st, "must_clear")
		return
	var p: Vector2 = pl["p"]
	var d: float = p.distance_to(HOOP)
	var chance: float = shot_chance(st, pl, p, c)
	var rng: RandomNumberGenerator = st["rng"]
	var made: bool = rng.randf() < chance
	var b: Dictionary = st["ball"]
	b["mode"] = "shot"
	b["from"] = p
	b["fh"] = 2.2
	b["to"] = HOOP
	b["th"] = 3.05
	b["t"] = 0.0
	b["dur"] = 0.75 + d * 0.05
	b["made"] = made
	b["pts"] = 3 if d > ARC else 2
	b["shooter"] = int(pl["i"])
	b["blocked"] = false
	st["owner"] = -1
	pl["jump"] = 0.45
	_ev(st, "shot", {"i": int(pl["i"]), "pts": int(b["pts"]), "chance": chance, "timing": c, "perfect": absf(c - PERFECT) < 0.07})
	## Tapon: si un defensor salta pegado al tirador justo ahora.
	for o: Dictionary in st["players"]:
		if int(o["team"]) != int(pl["team"]) and float(o["jump"]) > 0.25 and (o["p"] as Vector2).distance_to(p) < 1.1:
			if rng.randf() < 0.25 + 0.35 * float(o["skill"]):
				_block(st, o)
				return


static func _block(st: Dictionary, o: Dictionary) -> void:
	var b: Dictionary = st["ball"]
	var rng: RandomNumberGenerator = st["rng"]
	b["blocked"] = true
	b["made"] = false
	_loose(st, (b["from"] as Vector2) + Vector2(rng.randf_range(-2.5, 2.5), rng.randf_range(1.0, 3.0)), 2.4)
	_ev(st, "block", {"i": int(o["i"])})


static func _jump(st: Dictionary, pl: Dictionary) -> void:
	pl["jump"] = 0.5
	_ev(st, "jump", {"i": int(pl["i"])})
	var b: Dictionary = st["ball"]
	## Saltar justo despues del tiro tambien tapa.
	if str(b["mode"]) == "shot" and float(b["t"]) < 0.22 and not bool(b["blocked"]) and team_of(st, int(b["shooter"])) != int(pl["team"]):
		if (pl["p"] as Vector2).distance_to(b["from"]) < 1.2 and (st["rng"] as RandomNumberGenerator).randf() < 0.35 + 0.35 * float(pl["skill"]):
			_block(st, pl)


static func best_pass(st: Dictionary, pl: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var bv: float = -INF
	for o: Dictionary in st["players"]:
		if int(o["team"]) != int(pl["team"]) or o == pl:
			continue
		var v: float = _open(st, o) * 2.0 - (o["p"] as Vector2).distance_to(pl["p"]) * 0.1 - _lane_risk(st, pl["p"], o["p"], int(pl["team"])) * 3.0
		if v > bv:
			bv = v
			best = o
	return best


static func _open(st: Dictionary, pl: Dictionary) -> float:
	return minf(_defender_dist(st, pl, pl["p"]), 4.0)


static func _lane_risk(st: Dictionary, a: Vector2, b: Vector2, tm: int) -> float:
	var risk: float = 0.0
	for o: Dictionary in st["players"]:
		if int(o["team"]) == tm:
			continue
		var q: Vector2 = o["p"]
		var ab: Vector2 = b - a
		var t: float = clampf((q - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		var dist: float = (a + ab * t - q).length()
		if dist < 0.8 and t > 0.1 and t < 0.9:
			risk += 1.0 - dist / 0.8
	return risk


static func pass_ball(st: Dictionary, pl: Dictionary, to: Dictionary) -> void:
	var b: Dictionary = st["ball"]
	b["mode"] = "pass"
	b["from"] = pl["p"]
	b["fh"] = 1.3
	b["to"] = to["p"]
	b["th"] = 1.3
	b["t"] = 0.0
	b["dur"] = maxf(0.2, (pl["p"] as Vector2).distance_to(to["p"]) / 13.0)
	b["target"] = int(to["i"])
	st["owner"] = -1
	pl["hold_t"] = 0.0
	_ev(st, "pass", {"i": int(pl["i"]), "to": int(to["i"])})


static func _steal(st: Dictionary, pl: Dictionary) -> void:
	if float(pl["steal_cd"]) > 0.0:
		return
	pl["steal_cd"] = 0.9
	var owner: int = int(st["owner"])
	if owner < 0 or team_of(st, owner) == int(pl["team"]) or str(st["ball"]["mode"]) != "held":
		return
	var h: Dictionary = st["players"][owner]
	if (h["p"] as Vector2).distance_to(pl["p"]) > 1.15:
		_ev(st, "reach", {"i": int(pl["i"])})
		return
	var chance: float = 0.22 + 0.3 * float(pl["skill"]) - 0.15 * float(h["skill"])
	if (st["rng"] as RandomNumberGenerator).randf() < chance:
		_gain(st, pl, true)
		_ev(st, "steal", {"i": int(pl["i"])})
	else:
		_ev(st, "reach", {"i": int(pl["i"])})


## pl coge el balon. Si cambia de equipo, hay que sacarlo fuera del triple (reglas de la calle).
static func _gain(st: Dictionary, pl: Dictionary, change_rule: bool) -> void:
	var tm: int = int(pl["team"])
	var b: Dictionary = st["ball"]
	b["mode"] = "held"
	st["owner"] = int(pl["i"])
	pl["hold_t"] = 0.0
	pl["charge"] = 0.0
	if tm != int(st["poss"]):
		st["poss"] = tm
		st["clock"] = SHOT_CLOCK
		st["clear"] = change_rule and (pl["p"] as Vector2).distance_to(HOOP) < ARC + 0.3
	elif change_rule:
		st["clock"] = SHOT_CLOCK


static func _loose(st: Dictionary, to: Vector2, h: float) -> void:
	var b: Dictionary = st["ball"]
	b["from"] = ball_pos(st) if str(b["mode"]) == "held" else b["p"]
	b["mode"] = "loose"
	b["to"] = Vector2(clampf(to.x, 0.5, W - 0.5), clampf(to.y, 0.5, L - 0.5))
	b["fh"] = h
	b["th"] = 0.25
	b["t"] = 0.0
	b["dur"] = 0.55 + (b["from"] as Vector2).distance_to(b["to"]) * 0.05
	st["owner"] = -1


## Balon: en la mano va con el jugador; en el aire sigue su curva; suelto se puede coger.
static func _ball(st: Dictionary, dt: float) -> void:
	var b: Dictionary = st["ball"]
	var mode: String = b["mode"]
	if mode == "held":
		b["p"] = ball_pos(st)
		b["h"] = 1.0
		return
	b["t"] = float(b["t"]) + dt
	var k: float = clampf(float(b["t"]) / float(b["dur"]), 0.0, 1.0)
	var arc: float = 2.6 if mode == "shot" else (0.4 if mode == "pass" else 1.4)
	b["p"] = (b["from"] as Vector2).lerp(b["to"], k)
	b["h"] = lerpf(float(b["fh"]), float(b["th"]), k) + sin(k * PI) * arc
	if mode == "pass":
		## Interceptar: un rival pegado a la linea del pase.
		for o: Dictionary in st["players"]:
			if int(o["team"]) != int(st["poss"]) and (o["p"] as Vector2).distance_to(b["p"]) < 0.55 and k > 0.15 and k < 0.9:
				if (st["rng"] as RandomNumberGenerator).randf() < 0.25 + 0.4 * float(o["skill"]):
					_gain(st, o, true)
					_ev(st, "steal", {"i": int(o["i"]), "pass": true})
					return
		var tg: Dictionary = st["players"][int(b["target"])]
		b["to"] = (b["to"] as Vector2).move_toward(tg["p"], 6.0 * dt)
		if k >= 1.0:
			_gain(st, tg, false)
			_ev(st, "catch", {"i": int(tg["i"])})
		return
	if mode == "shot":
		if k >= 1.0:
			var tm: int = team_of(st, int(b["shooter"]))
			if bool(b["made"]):
				var s: Array = st["score"]
				s[tm] = int(s[tm]) + int(b["pts"])
				_ev(st, "score", {"team": tm, "pts": int(b["pts"]), "i": int(b["shooter"])})
				if int(s[tm]) >= int(st["points"]) or bool(st["sudden"]):
					_end(st)
					return
				check_ball(st, 1 - tm)
			else:
				## Rebote: el aro lo escupe hacia un lado.
				var rng: RandomNumberGenerator = st["rng"]
				var a: float = rng.randf_range(-PI * 0.9, -PI * 0.1)
				var dist: float = rng.randf_range(1.2, 3.8)
				b["p"] = HOOP
				b["h"] = 3.05
				_loose(st, HOOP + Vector2(cos(a), -sin(a)) * dist, 3.05)
				_ev(st, "rim")
		return
	## Suelto: lo coge el primero que llega (si esta bajo).
	if float(b["h"]) < 2.4:
		var best: Dictionary = {}
		var bd: float = 0.7
		for o: Dictionary in st["players"]:
			var d: float = (o["p"] as Vector2).distance_to(b["p"])
			if d < bd:
				bd = d
				best = o
		if not best.is_empty():
			var was: int = int(st["poss"])
			_gain(st, best, true)
			_ev(st, "rebound", {"i": int(best["i"]), "off": int(best["team"]) == was})
			return
	if k >= 1.0:
		b["from"] = b["p"]
		b["fh"] = 0.25
		b["th"] = 0.25
		b["t"] = 0.0
		b["dur"] = 0.5


# ------------------------------------------------------------------ IA

## Carga de tiro de la IA: suelta cerca de la zona verde (mejor cuanto mas destreza).
static func _ai_charge(st: Dictionary, pl: Dictionary, dt: float) -> void:
	if float(pl["charge"]) <= 0.0:
		return
	if int(st["owner"]) != int(pl["i"]):
		pl["charge"] = 0.0
		return
	pl["charge"] = float(pl["charge"]) + dt / 0.9
	if float(pl["charge"]) >= float(pl["aim_c"]):
		var c: float = float(pl["charge"])
		pl["charge"] = 0.0
		shoot_ball(st, pl, c)


static func think(st: Dictionary, pl: Dictionary) -> void:
	var tm: int = int(pl["team"])
	var b: Dictionary = st["ball"]
	var mode: String = b["mode"]
	var p: Vector2 = pl["p"]
	var rng: RandomNumberGenerator = st["rng"]
	var sk: float = float(pl["skill"])
	## Balon suelto: los dos mas cercanos van a por el (uno por equipo).
	if mode == "loose":
		var bp: Vector2 = b["to"] if float(b["t"]) < float(b["dur"]) else b["p"]
		if _closest(st, tm, bp) == int(pl["i"]):
			pl["goal"] = bp
			return
	var attacking: bool = int(st["poss"]) == tm
	if attacking and mode == "held" and int(st["owner"]) == int(pl["i"]):
		_think_holder(st, pl)
		return
	if attacking:
		## Sin balon: a un hueco libre lejos de los defensores (y que no sea el del que lleva el balon).
		var hp: Vector2 = ball_pos(st)
		var bestv: float = -INF
		var bests: Vector2 = p
		for s: Vector2 in SPOTS:
			if s.distance_to(hp) < 3.0:
				continue
			var taken: bool = false
			for o: Dictionary in st["players"]:
				if o != pl and int(o["team"]) == tm and (o["goal"] as Vector2).distance_to(s) < 1.5:
					taken = true
			if taken:
				continue
			var v: float = minf(_defender_dist(st, pl, s), 4.0) - s.distance_to(p) * 0.15
			if v > bestv:
				bestv = v
				bests = s
		pl["goal"] = bests
		return
	## Defensa: cada uno a su par, entre el y la canasta (mas pegado al que lleva el balon).
	var n: int = int(st["n"])
	var man: Dictionary = st["players"][(1 - tm) * n + int(pl["slot"])]
	var owner: int = int(st["owner"])
	var on_ball: bool = int(man["i"]) == owner
	var mp: Vector2 = man["p"]
	var gap: float = (1.0 - 0.25 * sk) if on_ball else 2.2
	pl["goal"] = mp + (HOOP - mp).normalized() * gap
	if on_ball and mode == "held":
		var h: Dictionary = st["players"][owner]
		## Si va a tirar, salta.
		if float(h["charge"]) > 0.25 and p.distance_to(h["p"]) < 1.3 and float(pl["jump"]) <= 0.0 and rng.randf() < 0.3 + 0.5 * sk:
			_jump(st, pl)
		elif p.distance_to(h["p"]) < 1.1 and float(pl["steal_cd"]) <= 0.0 and rng.randf() < 0.05 + 0.1 * sk:
			_steal(st, pl)


static func _think_holder(st: Dictionary, pl: Dictionary) -> void:
	var p: Vector2 = pl["p"]
	var rng: RandomNumberGenerator = st["rng"]
	var sk: float = float(pl["skill"])
	if float(pl["charge"]) > 0.0:
		pl["goal"] = p
		return
	if bool(st["clear"]):
		## Sacar el balon fuera del triple por el camino mas corto.
		pl["goal"] = HOOP + (p - HOOP).normalized() * (ARC + 1.2)
		return
	var good: float = shot_chance(st, pl, p, PERFECT)
	var hurry: bool = float(st["clock"]) < 3.0
	## Mejor pase: un companero mucho mas solo.
	var to: Dictionary = best_pass(st, pl)
	if not to.is_empty() and float(pl["hold_t"]) > 0.5:
		var their: float = shot_chance(st, to, to["p"], PERFECT)
		if their > good + 0.1 and _lane_risk(st, p, to["p"], int(pl["team"])) < 0.3:
			pass_ball(st, pl, to)
			return
	if (good > 0.64 - 0.08 * sk and float(pl["hold_t"]) > 0.4) or hurry or (good > 0.4 and float(pl["hold_t"]) > 4.5):
		pl["charge"] = 0.001
		pl["aim_c"] = PERFECT + rng.randfn(0.0, 0.16 - 0.12 * sk)
		pl["goal"] = p
		return
	## Penetrar: hacia el aro, esquivando al defensor por el lado libre.
	var dd: Vector2 = Vector2.ZERO
	for o: Dictionary in st["players"]:
		if int(o["team"]) != int(pl["team"]):
			var rel: Vector2 = p - (o["p"] as Vector2)
			if rel.length() < 2.0:
				dd += rel.normalized() * (2.0 - rel.length())
	var to_hoop: Vector2 = (HOOP - p).normalized()
	var side: Vector2 = to_hoop.orthogonal() * (1.0 if dd.dot(to_hoop.orthogonal()) >= 0.0 else -1.0)
	pl["goal"] = p + (to_hoop + side * minf(dd.length(), 1.2)).normalized() * 2.0


static func _closest(st: Dictionary, tm: int, q: Vector2) -> int:
	var best: int = -1
	var bd: float = INF
	for o: Dictionary in st["players"]:
		if int(o["team"]) == tm:
			var d: float = (o["p"] as Vector2).distance_to(q)
			if d < bd:
				bd = d
				best = int(o["i"])
	return best


# ------------------------------------------------------------------ bot y analizador

static func boost(st: Dictionary) -> void:
	## El bot juega con tu equipo como una persona que sabe.
	for k: int in int(st["n"]):
		st["players"][k]["skill"] = maxf(float(st["players"][k]["skill"]), 0.85 if k == 0 else float(st["mates"]))


static func bot_play(level: Dictionary, dt: float = 1.0 / 30.0) -> Dictionary:
	var st: Dictionary = new_state(level)
	boost(st)
	var guard: int = 0
	while not bool(st["over"]) and guard < 60 * 60 * 30:
		step(st, {}, dt)
		(st["events"] as Array).clear()
		guard += 1
	return {"won": bool(st["won"]), "score": st["score"], "time": float(st["t"])}


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var wins: int = 0
	var pts: int = 0
	var tsum: float = 0.0
	var base: int = int(level.get("seed", 1))
	for r0: Variant in level.get("map", []):
		var t0: String = str(r0)
		if t0.begins_with("#") and t0.substr(1).is_valid_int():
			base = int(t0.substr(1))
	for k: int in 3:
		var lv: Dictionary = level.duplicate()
		lv["seed"] = base + k * 97
		lv["map"] = []
		var r: Dictionary = bot_play(lv)
		pts += int(r["score"][0])
		tsum += float(r["time"])
		if bool(r["won"]):
			wins += 1
	if wins < 2:
		issues.append("basket_too_hard")
	if pts == 0:
		issues.append("basket_no_points")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": 0, "enemies": int(level.get("players", 2)), "enemy_problems": [],
		"par": int(tsum / 3.0 * 1.2) + 10}
