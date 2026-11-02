extends RefCounted
## Futbol 3D (arcade, pocos por equipo): campo cerrado con paredes, porterias, porteros, pases,
## tiros y robos. Reglas, simulacion pura, IA de los dos equipos, bot y analizador.
## Coordenadas en metros: x a lo ancho, y a lo largo. Tu porteria abajo (y = L) y atacas hacia
## arriba (y = 0), asi el norte de la pantalla es la porteria rival.
## 1 - Mapa (game.json -> levels[i].map): no se usa para el campo (es siempre igual); la fila
##     "#semilla" da el azar del partido.
## 2 - Parametros: "players" (por equipo, 2-5, el primero es el portero), "skill" (0-1, rivales),
##     "mates" (0-1, tus companeros), "time" (segundos de partido), "need" (diferencia de goles
##     para ganar el nivel, 1 por defecto), "length" y "width" del campo.

const W_DEF: float = 26.0
const L_DEF: float = 40.0
const GOAL_W: float = 6.0
const BOX: float = 6.5
const PR: float = 0.45
const BALL_R: float = 0.22
const CTRL: float = 0.75
const MAX_SPEED: float = 7.6


static func new_state(level: Dictionary) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var seed_v: int = int(level.get("seed", 1))
	for r: Variant in level.get("map", []):
		var t: String = str(r)
		if t.begins_with("#") and t.substr(1).is_valid_int():
			seed_v = int(t.substr(1))
	rng.seed = seed_v
	var n: int = clampi(int(level.get("players", 3)), 2, 5)
	var st: Dictionary = {"w": clampf(float(level.get("width", W_DEF)), 18.0, 40.0), "l": clampf(float(level.get("length", L_DEF)), 26.0, 60.0),
		"rng": rng, "t": 0.0, "time": clampf(float(level.get("time", 90.0)), 30.0, 300.0), "score": [0, 0], "over": false,
		"won": false, "events": [], "players": [], "ball": {"p": Vector2.ZERO, "v": Vector2.ZERO, "h": 0.0, "vh": 0.0},
		"owner": -1, "last_touch": -1, "kick_cd": {}, "pause_t": 0.0, "need": maxi(1, int(level.get("need", 1))), "ctrl": -1,
		"skill": clampf(float(level.get("skill", 0.4)), 0.0, 1.0), "mates": clampf(float(level.get("mates", 0.65)), 0.0, 1.0)}
	for team: int in 2:
		for k: int in n:
			var sk: float = float(st["mates"]) if team == 0 else float(st["skill"])
			(st["players"] as Array).append({"i": team * n + k, "team": team, "role": "gk" if k == 0 else ("def" if k == 1 and n > 2 else "att"),
				"slot": k, "p": Vector2.ZERO, "v": Vector2.ZERO, "face": Vector2(0, -1 if team == 0 else 1), "skill": sk,
				"think": rng.randf() * 0.1, "goal": Vector2.ZERO, "act": "", "tackle_cd": 0.0})
	st["n"] = n
	kickoff(st, 0)
	return st


static func goal_y(st: Dictionary, team: int) -> float:
	## La porteria que defiende cada equipo.
	return float(st["l"]) if team == 0 else 0.0


static func attack_dir(team: int) -> float:
	return -1.0 if team == 0 else 1.0


## Saque desde el centro: todos a su sitio; saca "team".
static func kickoff(st: Dictionary, team: int) -> void:
	var w: float = float(st["w"])
	var l: float = float(st["l"])
	var n: int = int(st["n"])
	for pl: Dictionary in st["players"]:
		var tm: int = int(pl["team"])
		var home: Vector2 = _home(st, pl, Vector2(w * 0.5, l * 0.5))
		## Cada uno en su mitad.
		if tm == 0:
			home.y = maxf(home.y, l * 0.5 + 1.2)
		else:
			home.y = minf(home.y, l * 0.5 - 1.2)
		pl["p"] = home
		pl["v"] = Vector2.ZERO
	var b: Dictionary = st["ball"]
	b["p"] = Vector2(w * 0.5, l * 0.5)
	b["v"] = Vector2.ZERO
	b["h"] = 0.0
	b["vh"] = 0.0
	st["owner"] = -1
	## El delantero del equipo que saca, junto al balon.
	var taker: Dictionary = st["players"][team * n + (n - 1)]
	taker["p"] = Vector2(w * 0.5, l * 0.5 + 0.9 * (1.0 if team == 0 else -1.0))
	st["pause_t"] = 0.8
	st["kick_cd"] = {}


## Sitio de cada uno segun su papel y donde esta el balon.
static func _home(st: Dictionary, pl: Dictionary, ball: Vector2) -> Vector2:
	var w: float = float(st["w"])
	var l: float = float(st["l"])
	var tm: int = int(pl["team"])
	var gy: float = goal_y(st, tm)
	var dir: float = attack_dir(tm)
	var n: int = int(st["n"])
	var role: String = pl["role"]
	if role == "gk":
		## Cierra el angulo: en la linea entre el balon y el centro de la porteria.
		var gc: Vector2 = Vector2(w * 0.5, gy)
		var to_b: Vector2 = (ball - gc)
		if to_b.length() < 0.1:
			to_b = Vector2(0, dir)
		var at: Vector2 = gc + to_b.normalized() * 1.5
		return Vector2(clampf(at.x, w * 0.5 - GOAL_W * 0.4, w * 0.5 + GOAL_W * 0.4), gy + dir * clampf(absf(at.y - gy), 0.8, 1.6))
	var lanes: int = n - 1
	var k: int = int(pl["slot"]) - 1
	var lane_x: float = w * (0.5 + (float(k) - float(lanes - 1) * 0.5) * (0.62 / maxf(1.0, float(lanes - 1)) if lanes > 1 else 0.0))
	var depth: float = 0.32 if role == "def" else 0.62
	## Se mueven con el balon: adelantados si ataca su equipo.
	var base_y: float = gy + dir * l * depth
	var follow: float = (ball.y - l * 0.5) * 0.45
	return Vector2(lerpf(lane_x, ball.x, 0.3), clampf(base_y + follow, 1.5, l - 1.5))


static func _ev(st: Dictionary, kind: String, extra: Dictionary = {}) -> void:
	var e: Dictionary = {"kind": kind}
	e.merge(extra)
	(st["events"] as Array).append(e)


# ------------------------------------------------------------------ paso

## inp: lo que hace el jugador que manejas: {"move": Vector2, "pass": bool, "shoot": bool}.
static func step(st: Dictionary, inp: Dictionary, dt: float) -> void:
	if bool(st["over"]):
		return
	st["t"] = float(st["t"]) + dt
	if float(st["pause_t"]) > 0.0:
		st["pause_t"] = float(st["pause_t"]) - dt
		return
	var kc: Dictionary = st["kick_cd"]
	for k: Variant in kc.keys():
		kc[k] = float(kc[k]) - dt
		if float(kc[k]) <= 0.0:
			kc.erase(k)
	_pick_controlled(st)
	for pl: Dictionary in st["players"]:
		pl["tackle_cd"] = maxf(0.0, float(pl["tackle_cd"]) - dt)
		if int(pl["i"]) == int(st["ctrl"]) and not inp.is_empty():
			_human(st, pl, inp)
		else:
			pl["think"] = float(pl["think"]) - dt
			if float(pl["think"]) <= 0.0:
				pl["think"] = 0.12 + (1.0 - float(pl["skill"])) * 0.16
				think(st, pl)
		_move(st, pl, dt)
	_ball(st, dt)
	if float(st["t"]) >= float(st["time"]) and not bool(st["over"]):
		st["over"] = true
		var s: Array = st["score"]
		st["won"] = int(s[0]) - int(s[1]) >= int(st["need"])
		_ev(st, "end")


## El que manejas: el de tu equipo (no el portero) que lleva el balon o el mas cercano a el.
static func _pick_controlled(st: Dictionary) -> void:
	var owner: int = int(st["owner"])
	var n: int = int(st["n"])
	if owner >= 0 and owner < n:
		st["ctrl"] = owner
		return
	var bp: Vector2 = st["ball"]["p"]
	var cur: int = int(st["ctrl"])
	var best: int = cur
	var bd: float = INF if cur < 1 else (st["players"][cur]["p"] as Vector2).distance_to(bp) - 2.0
	for k: int in range(1, n):
		var d: float = (st["players"][k]["p"] as Vector2).distance_to(bp)
		if d < bd:
			bd = d
			best = k
	st["ctrl"] = best


static func _human(st: Dictionary, pl: Dictionary, inp: Dictionary) -> void:
	var mv: Vector2 = inp.get("move", Vector2.ZERO)
	if mv.length() > 1.0:
		mv = mv.normalized()
	pl["goal"] = (pl["p"] as Vector2) + mv * 3.0
	pl["want_v"] = mv * MAX_SPEED
	if mv.length() > 0.2:
		pl["face"] = mv.normalized()
	var has: bool = int(st["owner"]) == int(pl["i"])
	if bool(inp.get("shoot", false)):
		if has:
			var aim: float = clampf(mv.x, -1.0, 1.0)
			var tgt: Vector2 = Vector2(float(st["w"]) * 0.5 + aim * GOAL_W * 0.42, goal_y(st, 1))
			kick(st, pl, (tgt - (pl["p"] as Vector2)).normalized(), 21.0, 0.6)
		else:
			_tackle(st, pl, 1.0)
	elif bool(inp.get("pass", false)) and has:
		var to: Dictionary = best_pass(st, pl, pl["face"])
		if not to.is_empty():
			_pass_to(st, pl, to)
		else:
			kick(st, pl, pl["face"], 14.0, 0.0)


## Mover hacia su objetivo (o con la velocidad que pide el mando).
static func _move(st: Dictionary, pl: Dictionary, dt: float) -> void:
	var speed: float = MAX_SPEED * (0.78 + 0.22 * float(pl["skill"]))
	if int(st["owner"]) == int(pl["i"]):
		speed *= 0.88
	var want: Vector2
	if pl.has("want_v"):
		want = pl["want_v"]
		pl.erase("want_v")
		want = want.limit_length(speed)
	else:
		var to: Vector2 = (pl["goal"] as Vector2) - (pl["p"] as Vector2)
		want = to.normalized() * minf(speed, to.length() * 3.0) if to.length() > 0.05 else Vector2.ZERO
	var v: Vector2 = pl["v"]
	v = v.move_toward(want, 30.0 * dt)
	var p: Vector2 = (pl["p"] as Vector2) + v * dt
	p.x = clampf(p.x, PR, float(st["w"]) - PR)
	p.y = clampf(p.y, PR, float(st["l"]) - PR)
	## Nadie se pisa: se separan un poco.
	for o: Dictionary in st["players"]:
		if o == pl:
			continue
		var d: Vector2 = p - (o["p"] as Vector2)
		if d.length() < PR * 2.0 and d.length() > 0.001:
			p += d.normalized() * (PR * 2.0 - d.length()) * 0.5
	pl["p"] = p
	pl["v"] = v
	if v.length() > 0.5 and int(st["ctrl"]) != int(pl["i"]):
		pl["face"] = v.normalized()


static func kick(st: Dictionary, pl: Dictionary, dir: Vector2, power: float, lift: float) -> void:
	var b: Dictionary = st["ball"]
	var d: Vector2 = dir.normalized() if dir.length() > 0.01 else Vector2(0, attack_dir(int(pl["team"])))
	b["p"] = (pl["p"] as Vector2) + d * (PR + BALL_R + 0.05)
	b["v"] = d * power
	b["vh"] = lift * 6.0
	st["owner"] = -1
	st["last_touch"] = int(pl["i"])
	(st["kick_cd"] as Dictionary)[int(pl["i"])] = 0.3
	_ev(st, "kick", {"i": int(pl["i"]), "power": power})


static func _pass_to(st: Dictionary, pl: Dictionary, to: Dictionary) -> void:
	var tp: Vector2 = (to["p"] as Vector2) + (to["v"] as Vector2) * 0.4
	var d: Vector2 = tp - (pl["p"] as Vector2)
	kick(st, pl, d, clampf(8.0 + d.length() * 0.9, 9.0, 18.0), 0.0)
	_ev(st, "pass", {"i": int(pl["i"]), "to": int(to["i"])})


## Robar: si el que lleva el balon esta cerca, se lo quitas (mas facil con mas destreza).
static func _tackle(st: Dictionary, pl: Dictionary, chance: float) -> void:
	if float(pl["tackle_cd"]) > 0.0:
		return
	pl["tackle_cd"] = 0.7
	var owner: int = int(st["owner"])
	if owner < 0:
		return
	var o: Dictionary = st["players"][owner]
	if int(o["team"]) == int(pl["team"]):
		return
	if (o["p"] as Vector2).distance_to(pl["p"]) < 1.3 and (st["rng"] as RandomNumberGenerator).randf() < chance:
		st["owner"] = int(pl["i"])
		st["last_touch"] = int(pl["i"])
		(st["kick_cd"] as Dictionary)[owner] = 0.6
		_ev(st, "tackle", {"i": int(pl["i"])})


static func _ball(st: Dictionary, dt: float) -> void:
	var b: Dictionary = st["ball"]
	var owner: int = int(st["owner"])
	var w: float = float(st["w"])
	var l: float = float(st["l"])
	if owner >= 0:
		var o: Dictionary = st["players"][owner]
		b["p"] = (o["p"] as Vector2) + (o["face"] as Vector2) * (PR + BALL_R + 0.12)
		b["v"] = o["v"]
		b["h"] = 0.0
		b["vh"] = 0.0
	else:
		var v: Vector2 = b["v"]
		var p: Vector2 = (b["p"] as Vector2) + v * dt
		b["vh"] = float(b["vh"]) - 20.0 * dt
		b["h"] = maxf(0.0, float(b["h"]) + float(b["vh"]) * dt)
		if float(b["h"]) <= 0.0:
			b["vh"] = absf(float(b["vh"])) * 0.35 if float(b["vh"]) < -2.0 else 0.0
			v = v.move_toward(Vector2.ZERO, (1.8 + v.length() * 0.25) * dt)
		## Gol: cruza la linea entre los postes (y por debajo del larguero).
		var in_mouth: bool = absf(p.x - w * 0.5) < GOAL_W * 0.5 - BALL_R and float(b["h"]) < 2.2
		if p.y < 0.0 and in_mouth:
			_goal(st, 0)
			return
		if p.y > l and in_mouth:
			_goal(st, 1)
			return
		## Paredes del campo (rebota).
		if p.x < BALL_R or p.x > w - BALL_R:
			v.x = -v.x * 0.7
			p.x = clampf(p.x, BALL_R, w - BALL_R)
			_ev(st, "wall")
		if (p.y < BALL_R or p.y > l - BALL_R) and not in_mouth:
			v.y = -v.y * 0.7
			p.y = clampf(p.y, BALL_R, l - BALL_R)
			_ev(st, "wall")
		b["p"] = p
		b["v"] = v
		## Alguien la controla: el que este mas cerca y a tiempo (el portero la para con las manos).
		var best: int = -1
		var bd: float = INF
		for pl: Dictionary in st["players"]:
			if (st["kick_cd"] as Dictionary).has(int(pl["i"])):
				continue
			var reach: float = CTRL + (0.85 if str(pl["role"]) == "gk" and _in_box(st, pl, p) else 0.0)
			var d: float = (pl["p"] as Vector2).distance_to(p)
			if d < reach and float(b["h"]) < (2.3 if str(pl["role"]) == "gk" else 1.0) and d < bd:
				## Un balon muy rapido se escapa a quien no es portero.
				if v.length() > 16.0 and str(pl["role"]) != "gk" and (st["rng"] as RandomNumberGenerator).randf() > 0.35 + 0.4 * float(pl["skill"]):
					continue
				bd = d
				best = int(pl["i"])
		if best >= 0:
			var prev: int = int(st["last_touch"])
			st["owner"] = best
			st["last_touch"] = best
			var pl2: Dictionary = st["players"][best]
			if prev >= 0 and int(st["players"][prev]["team"]) != int(pl2["team"]):
				_ev(st, "save" if str(pl2["role"]) == "gk" else "steal", {"i": best})
			else:
				_ev(st, "control", {"i": best})


static func _in_box(st: Dictionary, pl: Dictionary, p: Vector2) -> bool:
	var gy: float = goal_y(st, int(pl["team"]))
	return absf(p.y - gy) < BOX and absf(p.x - float(st["w"]) * 0.5) < GOAL_W * 0.5 + 3.0


static func _goal(st: Dictionary, team: int) -> void:
	var s: Array = st["score"]
	s[team] = int(s[team]) + 1
	_ev(st, "goal", {"team": team, "by": int(st["last_touch"])})
	kickoff(st, 1 - team)
	st["pause_t"] = 1.6


# ------------------------------------------------------------------ cabeza (IA de los dos equipos)

## Mejor companero para pasar (mas adelantado y libre, mejor si va en la direccion pedida).
static func best_pass(st: Dictionary, pl: Dictionary, prefer: Vector2 = Vector2.ZERO) -> Dictionary:
	var tm: int = int(pl["team"])
	var dir: float = attack_dir(tm)
	var best: Dictionary = {}
	var bv: float = -INF
	for o: Dictionary in st["players"]:
		if int(o["team"]) != tm or o == pl or str(o["role"]) == "gk":
			continue
		var d: Vector2 = (o["p"] as Vector2) - (pl["p"] as Vector2)
		if d.length() < 3.0 or d.length() > 22.0:
			continue
		var free: float = _space(st, o["p"], tm)
		var lane: float = _lane_clear(st, pl["p"], o["p"], tm)
		var val: float = free * 1.2 + lane * 4.0 + d.y * dir * 0.25
		if prefer.length() > 0.1:
			val += d.normalized().dot(prefer.normalized()) * 4.0
		if val > bv:
			bv = val
			best = o
	return best


## Distancia al rival mas cercano.
static func _space(st: Dictionary, p: Vector2, tm: int) -> float:
	var m: float = 20.0
	for o: Dictionary in st["players"]:
		if int(o["team"]) != tm:
			m = minf(m, (o["p"] as Vector2).distance_to(p))
	return m


## 1 si ningun rival corta la linea de pase, menos cuanto mas cerca esten.
static func _lane_clear(st: Dictionary, a: Vector2, b: Vector2, tm: int) -> float:
	var worst: float = 1.0
	for o: Dictionary in st["players"]:
		if int(o["team"]) == tm:
			continue
		var q: Vector2 = o["p"]
		var ab: Vector2 = b - a
		var f: float = clampf((q - a).dot(ab) / maxf(ab.length_squared(), 0.01), 0.0, 1.0)
		var d: float = q.distance_to(a + ab * f)
		worst = minf(worst, clampf((d - 0.6) / 2.0, 0.0, 1.0))
	return worst


static func think(st: Dictionary, pl: Dictionary) -> void:
	var tm: int = int(pl["team"])
	var owner: int = int(st["owner"])
	var bp: Vector2 = st["ball"]["p"]
	var bv: Vector2 = st["ball"]["v"]
	var rng: RandomNumberGenerator = st["rng"]
	var skill: float = float(pl["skill"])
	var p: Vector2 = pl["p"]
	var dir: float = attack_dir(tm)
	var ogy: float = goal_y(st, 1 - tm)
	var goal_c: Vector2 = Vector2(float(st["w"]) * 0.5, ogy)
	## 1 - Con el balon.
	if owner == int(pl["i"]):
		var dg: float = p.distance_to(goal_c)
		var press: float = _space(st, p, tm)
		if str(pl["role"]) == "gk":
			var to: Dictionary = best_pass(st, pl)
			if not to.is_empty():
				_pass_to(st, pl, to)
			else:
				kick(st, pl, Vector2(rng.randf_range(-0.4, 0.4), dir), 18.0, 0.5)
			return
		if dg < 13.0 + 3.0 * skill and absf(p.x - goal_c.x) < 9.0:
			## Tiro a la esquina contraria al portero; con menos destreza se desvia mas.
			var keeper: Dictionary = st["players"][(1 - tm) * int(st["n"])]
			var side: float = -1.0 if (keeper["p"] as Vector2).x > goal_c.x else 1.0
			var tgt: Vector2 = goal_c + Vector2(side * GOAL_W * 0.4 + rng.randfn(0.0, (1.0 - skill) * 2.0 + 0.35), 0)
			kick(st, pl, (tgt - p).normalized(), 19.0 + 4.0 * skill, 0.35)
			_ev(st, "shot", {"i": int(pl["i"])})
			return
		if press < 1.8 + skill * 0.6:
			var to2: Dictionary = best_pass(st, pl)
			if not to2.is_empty() and rng.randf() < 0.55 + 0.4 * skill:
				_pass_to(st, pl, to2)
				return
		## Avanzar esquivando al rival mas cercano.
		var fwd: Vector2 = (goal_c - p).normalized()
		var near: Vector2 = Vector2.ZERO
		var nd: float = 4.0
		for o: Dictionary in st["players"]:
			if int(o["team"]) != tm:
				var d: float = (o["p"] as Vector2).distance_to(p)
				if d < nd:
					nd = d
					near = o["p"]
		if near != Vector2.ZERO:
			var away: Vector2 = (p - near).normalized()
			fwd = (fwd + Vector2(away.x, 0) * 0.9).normalized()
		pl["goal"] = p + fwd * 4.0
		return
	var mine: bool = owner >= 0 and int(st["players"][owner]["team"]) == tm
	## 2 - Portero.
	if str(pl["role"]) == "gk":
		var home: Vector2 = _home(st, pl, bp)
		if owner < 0 and _in_box(st, pl, bp) and bp.distance_to(pl["p"]) < 5.0:
			pl["goal"] = bp
		elif owner < 0 and bv.length() > 6.0 and signf(bv.y) == -dir:
			## Se tira hacia donde va a llegar el balon.
			var ty: float = (pl["p"] as Vector2).y
			var tt: float = (ty - bp.y) / bv.y if absf(bv.y) > 0.01 else 0.0
			var cross: float = bp.x + bv.x * clampf(tt, 0.0, 2.0)
			var react: float = 0.55 + 0.4 * skill
			pl["goal"] = Vector2(lerpf(home.x, clampf(cross, home.x - GOAL_W * 0.6, home.x + GOAL_W * 0.6), react), home.y)
		else:
			pl["goal"] = home
		return
	## 3 - Balon suelto: el mas cercano de cada equipo va a por el.
	if owner < 0:
		if _closest(st, tm, bp) == int(pl["i"]):
			pl["goal"] = bp + bv * 0.25
		else:
			pl["goal"] = _home(st, pl, bp)
		return
	## 4 - Atacando: desmarcarse por delante del balon.
	if mine:
		var h: Vector2 = _home(st, pl, bp)
		h.y = clampf(bp.y + dir * (5.0 + 3.0 * float(pl["slot"] % 2)), 2.0, float(st["l"]) - 2.0)
		pl["goal"] = h
		return
	## 5 - Defendiendo: el mas cercano presiona y roba; el resto cierra entre balon y porteria.
	if _closest(st, tm, bp) == int(pl["i"]):
		pl["goal"] = bp
		if p.distance_to(bp) < 1.3:
			_tackle(st, pl, 0.25 + 0.45 * skill)
	else:
		var own_g: Vector2 = Vector2(float(st["w"]) * 0.5, goal_y(st, tm))
		var h2: Vector2 = _home(st, pl, bp)
		pl["goal"] = h2.lerp(bp.lerp(own_g, 0.45), 0.5)


static func _closest(st: Dictionary, tm: int, q: Vector2) -> int:
	var best: int = -1
	var bd: float = INF
	for o: Dictionary in st["players"]:
		if int(o["team"]) == tm and str(o["role"]) != "gk":
			var d: float = (o["p"] as Vector2).distance_to(q)
			if d < bd:
				bd = d
				best = int(o["i"])
	return best


# ------------------------------------------------------------------ bot y analizador

## El bot maneja a tu jugador con la misma cabeza que los demas (con buena destreza).
static func bot_input(st: Dictionary) -> Dictionary:
	return {}


static func bot_play(level: Dictionary, dt: float = 1.0 / 30.0) -> Dictionary:
	var st: Dictionary = new_state(level)
	var me_skill: float = 0.9
	for k: int in int(st["n"]):
		if k > 0:
			st["players"][k]["skill"] = maxf(float(st["players"][k]["skill"]), me_skill if k == int(st["n"]) - 1 else float(st["mates"]))
	while not bool(st["over"]):
		step(st, bot_input(st), dt)
		(st["events"] as Array).clear()
	return {"won": bool(st["won"]), "score": st["score"]}


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var wins: int = 0
	var gf: int = 0
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
		gf += int(r["score"][0])
		if bool(r["won"]):
			wins += 1
	if wins < 2:
		issues.append("soccer_too_hard")
	if gf == 0:
		issues.append("soccer_no_goals")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": 0, "enemies": int(level.get("players", 3)), "enemy_problems": [],
		"par": int(level.get("time", 90))}
