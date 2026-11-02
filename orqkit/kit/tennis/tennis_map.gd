extends RefCounted
## Tenis 3D (individual): pista de verdad, saque, peloteo, globos, voleas, bote, red y fuera, con
## el tanteo de siempre (15, 30, 40, iguales y ventaja). Reglas, simulacion pura, IA del rival,
## bot y analizador.
## Coordenadas en metros: x a lo ancho (centro 0), y a lo largo (red en y = 0). Tu mitad es la de
## abajo (y > 0) y la camara esta detras de ti. Altura "h" de la pelota aparte.
## 1 - Mapa (game.json -> levels[i].map): no se usa para la pista; la fila "#semilla" da el azar.
## 2 - Parametros: "skill" (0-1, rival), "games" (juegos para ganar el partido, 1-6), "speed"
##     (0-1, lo rapida que va la pelota).
## 3 - El golpe sale solo cuando la pelota esta a tu alcance; el mando decide hacia donde. Si
##     pulsas GOLPE justo antes (ventana corta) el tiro es perfecto: mas fuerte y preciso. GLOBO
##     la tira alta y al fondo.

const HW: float = 4.115
const HL: float = 11.885
const SERVICE: float = 6.4
const NET_H: float = 0.95
const G: float = 9.8
const REACH: float = 1.25
const SPEED: float = 4.3
const PERFECT_WIN: float = 0.3


static func new_state(level: Dictionary) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var seed_v: int = int(level.get("seed", 1))
	for r: Variant in level.get("map", []):
		var t: String = str(r)
		if t.begins_with("#") and t.substr(1).is_valid_int():
			seed_v = int(t.substr(1))
	rng.seed = seed_v
	var st: Dictionary = {"rng": rng, "t": 0.0, "over": false, "won": false, "events": [],
		"games_to": clampi(int(level.get("games", 3)), 1, 6), "games": [0, 0], "points": [0, 0], "server": 0, "serve_side": 1,
		"skill": clampf(float(level.get("skill", 0.4)), 0.0, 1.0), "pace": clampf(float(level.get("speed", 0.4)), 0.0, 1.0),
		"ball": {"p": Vector2.ZERO, "h": 1.0, "v": Vector2.ZERO, "vh": 0.0, "bounces": 0, "last": -1, "live": false, "landed": Vector2.ZERO},
		"phase": "serve", "pause_t": 0.6, "rally": 0, "streak": 0,
		"players": [
			{"i": 0, "p": Vector2(0.5, HL + 0.6), "skill": 0.75, "goal": Vector2(0.5, HL + 0.6), "press_t": 0.0, "swing_t": 0.0, "react": 0.0, "lob": false},
			{"i": 1, "p": Vector2(-0.5, -HL - 0.6), "skill": clampf(float(level.get("skill", 0.4)), 0.0, 1.0), "goal": Vector2(-0.5, -HL - 0.6), "press_t": 0.0, "swing_t": 0.0, "react": 0.0, "lob": false}]}
	_setup_serve(st)
	return st


static func _ev(st: Dictionary, kind: String, extra: Dictionary = {}) -> void:
	var e: Dictionary = {"kind": kind}
	e.merge(extra)
	(st["events"] as Array).append(e)


static func side_sign(i: int) -> float:
	## Jugador 0 abajo (y > 0), jugador 1 arriba (y < 0).
	return 1.0 if i == 0 else -1.0


## Saque: el que saca a su linea de fondo, a la derecha o a la izquierda segun el punto.
static func _setup_serve(st: Dictionary) -> void:
	var srv: int = int(st["server"])
	var pts: Array = st["points"]
	var side: float = 1.0 if (int(pts[0]) + int(pts[1])) % 2 == 0 else -1.0
	st["serve_side"] = side
	for pl: Dictionary in st["players"]:
		var s: float = side_sign(int(pl["i"]))
		## Derecha del que saca (vista desde su lado).
		var x: float = side * 0.8 * s
		if int(pl["i"]) != srv:
			x = -side * 2.2 * s * -1.0
		pl["p"] = Vector2(x, s * (HL + 0.5))
		pl["goal"] = pl["p"]
		pl["swing_t"] = 0.0
		pl["press_t"] = 0.0
	var b: Dictionary = st["ball"]
	var sp: Dictionary = st["players"][srv]
	b["p"] = sp["p"]
	b["h"] = 1.0
	b["v"] = Vector2.ZERO
	b["vh"] = 0.0
	b["bounces"] = 0
	b["live"] = false
	b["last"] = srv
	st["phase"] = "serve"
	st["serve_t"] = 0.0
	st["rally"] = 0
	st["pause_t"] = 0.8


# ------------------------------------------------------------------ paso

## inp (tu jugador): {"move": Vector2, "hit": bool (pulsado ahora), "lob": bool}. Sin inp, IA.
static func step(st: Dictionary, inp: Dictionary, dt: float) -> void:
	if bool(st["over"]):
		return
	st["t"] = float(st["t"]) + dt
	for pl0: Dictionary in st["players"]:
		pl0["swing_t"] = maxf(0.0, float(pl0["swing_t"]) - dt)
		pl0["press_t"] = maxf(0.0, float(pl0["press_t"]) - dt)
	if float(st["pause_t"]) > 0.0:
		st["pause_t"] = float(st["pause_t"]) - dt
		return
	var me: Dictionary = st["players"][0]
	if not inp.is_empty():
		var mv: Vector2 = inp.get("move", Vector2.ZERO)
		if mv.length() > 1.0:
			mv = mv.normalized()
		me["want_v"] = mv * SPEED
		me["aim_x"] = mv.x
		if bool(inp.get("hit", false)) or bool(inp.get("lob", false)):
			me["press_t"] = PERFECT_WIN
			me["lob"] = bool(inp.get("lob", false))
	if str(st["phase"]) == "serve":
		_serve_phase(st, inp, dt)
		return
	for pl: Dictionary in st["players"]:
		if int(pl["i"]) == 0 and not inp.is_empty():
			pass
		else:
			_think(st, pl, dt)
		_move(st, pl, dt)
	_ball(st, dt)


static func _serve_phase(st: Dictionary, inp: Dictionary, dt: float) -> void:
	var srv: int = int(st["server"])
	var sp: Dictionary = st["players"][srv]
	st["serve_t"] = float(st["serve_t"]) + dt
	var b: Dictionary = st["ball"]
	b["p"] = sp["p"]
	## Bote de la pelota antes de sacar.
	b["h"] = 1.0 + absf(sin(float(st["serve_t"]) * 3.0)) * 0.3
	var go: bool = false
	var perfect: bool = false
	if srv == 0 and not inp.is_empty():
		go = float(sp["press_t"]) > 0.0
		perfect = go
		## Si no pulsas en 2,5 s, saca solo (normal).
		if float(st["serve_t"]) > 2.5:
			go = true
	else:
		go = float(st["serve_t"]) > 0.7
		perfect = (st["rng"] as RandomNumberGenerator).randf() < float(sp["skill"]) * 0.6
	if not go:
		return
	sp["press_t"] = 0.0
	var s: float = side_sign(srv)
	var side: float = float(st["serve_side"])
	## Al cuadro de saque cruzado del otro lado.
	var rng: RandomNumberGenerator = st["rng"]
	var tx: float = -side * s * rng.randf_range(0.6, HW - 0.5)
	var ty: float = -s * rng.randf_range(SERVICE - 1.6, SERVICE - 0.4)
	var t_fly: float = lerpf(0.95, 0.72, float(st["pace"])) * (0.85 if perfect else 1.0)
	b["h"] = 2.6
	_launch(st, srv, Vector2(tx, ty), t_fly)
	st["phase"] = "rally"
	sp["swing_t"] = 0.35
	_ev(st, "serve", {"i": srv, "perfect": perfect})


## Lanza la pelota desde donde esta hasta "to" en "t_fly" segundos, pasando la red.
static func _launch(st: Dictionary, who: int, to: Vector2, t_fly: float) -> void:
	var b: Dictionary = st["ball"]
	var p: Vector2 = b["p"]
	var h0: float = float(b["h"])
	var t: float = t_fly
	for k: int in 12:
		var vh: float = (0.5 * G * t * t - h0) / t
		var v: Vector2 = (to - p) / t
		## Altura al pasar por la red (y = 0).
		if absf(v.y) < 0.001 or signf(p.y) == signf(to.y):
			break
		var tn: float = -p.y / v.y
		var hn: float = h0 + vh * tn - 0.5 * G * tn * tn
		if hn > NET_H + 0.25:
			break
		t *= 1.1
	b["v"] = (to - p) / t
	b["vh"] = (0.5 * G * t * t - h0) / t
	b["bounces"] = 0
	b["last"] = who
	b["live"] = true
	b["landed"] = to
	b["net_done"] = false


static func _move(st: Dictionary, pl: Dictionary, dt: float) -> void:
	var speed: float = SPEED * (0.8 + 0.25 * float(pl["skill"]))
	var want: Vector2
	if pl.has("want_v"):
		want = (pl["want_v"] as Vector2).limit_length(speed)
		pl.erase("want_v")
	else:
		var to: Vector2 = (pl["goal"] as Vector2) - (pl["p"] as Vector2)
		want = to.normalized() * speed * clampf(to.length() / 0.5, 0.0, 1.0) if to.length() > 0.05 else Vector2.ZERO
	var p: Vector2 = (pl["p"] as Vector2) + want * dt
	var s: float = side_sign(int(pl["i"]))
	p.x = clampf(p.x, -HW - 3.0, HW + 3.0)
	## Cada uno en su mitad (sin tocar la red).
	if s > 0.0:
		p.y = clampf(p.y, 0.6, HL + 4.0)
	else:
		p.y = clampf(p.y, -HL - 4.0, -0.6)
	pl["p"] = p
	pl["v"] = want


## Golpear: si la pelota viene hacia ti y esta a tu alcance, sale el golpe.
static func _try_hit(st: Dictionary, pl: Dictionary) -> bool:
	var b: Dictionary = st["ball"]
	var i: int = int(pl["i"])
	if not bool(b["live"]) or int(b["last"]) == i:
		return false
	var s: float = side_sign(i)
	var bp: Vector2 = b["p"]
	if signf(bp.y) != s:
		return false
	var h: float = float(b["h"])
	if h > 2.7 or h < 0.1:
		return false
	if (pl["p"] as Vector2).distance_to(bp) > REACH:
		return false
	## Despues del primer bote o de volea (antes de botar, si esta lejos de la linea de fondo).
	if int(b["bounces"]) == 0 and absf(bp.y) > HL - 1.0:
		return false
	_hit(st, pl)
	return true


static func _hit(st: Dictionary, pl: Dictionary) -> void:
	var i: int = int(pl["i"])
	var s: float = side_sign(i)
	var rng: RandomNumberGenerator = st["rng"]
	var sk: float = float(pl["skill"])
	var perfect: bool = float(pl["press_t"]) > 0.0
	var lob: bool = bool(pl["lob"]) and perfect
	pl["press_t"] = 0.0
	pl["lob"] = false
	pl["swing_t"] = 0.3
	## Hacia donde: el mando (x) o, sin mando, lejos del rival.
	var opp: Dictionary = st["players"][1 - i]
	var aim: float = float(pl.get("aim_x", 0.0)) * s
	if absf(aim) < 0.25:
		var away: float = -signf((opp["p"] as Vector2).x) if absf((opp["p"] as Vector2).x) > 0.5 else (1.0 if rng.randf() < 0.5 else -1.0)
		aim = away * rng.randf_range(0.45, 0.6 + 0.4 * sk)
	var tx: float = clampf(aim, -1.0, 1.0) * (HW - (0.35 if perfect else 0.9))
	## Los tiros cruzados y abiertos caen mas cortos (con angulo); los demas al fondo.
	var depth: float = rng.randf_range(HL - 4.0, HL - 1.0)
	if absf(aim) > 0.7:
		depth = rng.randf_range(HL - 6.5, HL - 2.5)
	if lob:
		depth = HL - 1.2
	var to: Vector2 = Vector2(tx, -s * depth)
	## Error: menos destreza y sin golpe perfecto, mas desvio (y alguna fuera o a la red).
	var err: float = (0.55 if perfect else 1.25) * (1.25 - sk)
	to += Vector2(rng.randfn(0.0, err), rng.randfn(0.0, err * 1.1))
	var pace: float = float(st["pace"])
	var t_fly: float = lerpf(1.1, 0.78, pace) * (0.78 if perfect else 1.0)
	if lob:
		t_fly = 1.9
	(st["ball"] as Dictionary)["h"] = maxf(float(st["ball"]["h"]), 0.6)
	_launch(st, i, to, t_fly)
	## A veces a la red (golpe flojo y bajo).
	if rng.randf() < (0.08 if perfect else 0.16) * (1.1 - sk):
		var b: Dictionary = st["ball"]
		b["vh"] = float(b["vh"]) * 0.55
	st["rally"] = int(st["rally"]) + 1
	_ev(st, "hit", {"i": i, "perfect": perfect, "lob": lob})


## Pelota en el aire: gravedad, red, botes y el punto cuando se acaba.
static func _ball(st: Dictionary, dt: float) -> void:
	var b: Dictionary = st["ball"]
	if not bool(b["live"]):
		return
	for pl: Dictionary in st["players"]:
		if _try_hit(st, pl):
			return
	var p0: Vector2 = b["p"]
	var p: Vector2 = p0 + (b["v"] as Vector2) * dt
	var vh: float = float(b["vh"]) - G * dt
	var h: float = float(b["h"]) + vh * dt
	## Red.
	if signf(p0.y) != signf(p.y) and p0.y != 0.0:
		if h < NET_H and absf(p.x) < HW + 0.9:
			b["p"] = Vector2(p.x, 0.15 * signf(p0.y))
			b["h"] = h
			_ev(st, "net")
			_point(st, 1 - int(b["last"]), "net")
			return
	if h <= 0.0:
		h = -h * 0.3
		vh = -vh * 0.68
		b["bounces"] = int(b["bounces"]) + 1
		b["v"] = (b["v"] as Vector2) * 0.85
		_ev(st, "bounce", {"p": p})
		var hitter: int = int(b["last"])
		if int(b["bounces"]) == 1:
			## Primer bote: tiene que caer dentro del campo del rival.
			var rs: float = side_sign(1 - hitter)
			if signf(p.y) != rs or absf(p.x) > HW + 0.04 or absf(p.y) > HL + 0.04:
				b["p"] = p
				b["h"] = 0.0
				_point(st, 1 - hitter, "out")
				return
		elif int(b["bounces"]) >= 2:
			b["p"] = p
			b["h"] = 0.0
			_point(st, hitter, "twice")
			return
	b["p"] = p
	b["h"] = h
	b["vh"] = vh
	## Si sale lejos sin que nadie llegue (despues del bote), punto para el que golpeo.
	if absf(p.y) > HL + 7.0 or absf(p.x) > HW + 7.0:
		if int(b["bounces"]) >= 1:
			_point(st, int(b["last"]), "past")
		else:
			_point(st, 1 - int(b["last"]), "out")


## Tanteo: 0, 15, 30, 40, iguales, ventaja, juego. Gana el partido quien llega a "games_to".
static func _point(st: Dictionary, winner: int, why: String) -> void:
	var b: Dictionary = st["ball"]
	b["live"] = false
	var pts: Array = st["points"]
	pts[winner] = int(pts[winner]) + 1
	_ev(st, "point", {"winner": winner, "why": why})
	var a: int = int(pts[winner])
	var o: int = int(pts[1 - winner])
	if a >= 4 and a - o >= 2:
		var gm: Array = st["games"]
		gm[winner] = int(gm[winner]) + 1
		pts[0] = 0
		pts[1] = 0
		st["server"] = 1 - int(st["server"])
		_ev(st, "game", {"winner": winner})
		if int(gm[winner]) >= int(st["games_to"]):
			st["over"] = true
			st["won"] = winner == 0
			_ev(st, "end")
			return
	_setup_serve(st)
	st["pause_t"] = 1.2


static func score_text(st: Dictionary, who: int) -> String:
	var pts: Array = st["points"]
	var a: int = int(pts[who])
	var o: int = int(pts[1 - who])
	if a >= 3 and o >= 3:
		return "40" if a == o else ("AD" if a > o else "40")
	return ["0", "15", "30", "40"][mini(a, 3)]


# ------------------------------------------------------------------ IA

## Donde va a estar la pelota cuando se pueda golpear (tras el primer bote, a media altura).
static func predict(st: Dictionary, i: int) -> Vector2:
	var b: Dictionary = st["ball"]
	var p: Vector2 = b["p"]
	var v: Vector2 = b["v"]
	var h: float = float(b["h"])
	var vh: float = float(b["vh"])
	var bounces: int = int(b["bounces"])
	var s: float = side_sign(i)
	var dt: float = 1.0 / 30.0
	for k: int in 120:
		p += v * dt
		vh -= G * dt
		h += vh * dt
		if h <= 0.0:
			h = -h * 0.3
			vh = -vh * 0.68
			v *= 0.85
			bounces += 1
		if signf(p.y) == s and bounces >= 1 and vh < 0.0 and h < 1.4:
			return p
		if absf(p.y) > HL + 3.5:
			return Vector2(p.x, s * (HL + 2.5))
	return p


static func _think(st: Dictionary, pl: Dictionary, dt: float) -> void:
	var i: int = int(pl["i"])
	var s: float = side_sign(i)
	var b: Dictionary = st["ball"]
	var sk: float = float(pl["skill"])
	## Al golpear el rival tarda un poco en reaccionar (y calcula peor cuanto menos destreza).
	var shot_id: int = int(st["rally"])
	if int(pl.get("seen", -1)) != shot_id:
		pl["seen"] = shot_id
		pl["react"] = 0.3 - 0.2 * sk
		var rng0: RandomNumberGenerator = st["rng"]
		pl["miss"] = Vector2(rng0.randfn(0.0, 0.9 * (1.0 - sk)), rng0.randfn(0.0, 0.6 * (1.0 - sk)))
	pl["react"] = float(pl["react"]) - dt
	if float(pl["react"]) > 0.0:
		return
	pl["react"] = 0.1
	if bool(b["live"]) and int(b["last"]) != i:
		var at: Vector2 = predict(st, i) + (pl["miss"] as Vector2)
		## Un poco detras de la pelota, para pegarle de cara.
		pl["goal"] = at + Vector2(0.35 * -signf(at.x) if absf(at.x) > 0.5 else 0.0, s * 0.45)
		## Pulsar el golpe a tiempo (mas a menudo cuanto mejor es).
		var close: bool = (pl["p"] as Vector2).distance_to(b["p"]) < REACH + 2.5
		if close and float(pl["press_t"]) <= 0.0 and (st["rng"] as RandomNumberGenerator).randf() < 0.15 + 0.6 * sk:
			pl["press_t"] = PERFECT_WIN
			pl["lob"] = (st["rng"] as RandomNumberGenerator).randf() < 0.08 and absf((st["players"][1 - i]["p"] as Vector2).y) < 6.0
	else:
		## Volver al centro de su linea de fondo.
		pl["goal"] = Vector2(0.0, s * (HL + 0.4))


# ------------------------------------------------------------------ bot y analizador

static func boost(st: Dictionary) -> void:
	st["players"][0]["skill"] = maxf(float(st["players"][0]["skill"]), 0.82)


static func bot_play(level: Dictionary, dt: float = 1.0 / 30.0) -> Dictionary:
	var st: Dictionary = new_state(level)
	boost(st)
	var guard: int = 0
	while not bool(st["over"]) and guard < 30 * 60 * 40:
		step(st, {}, dt)
		(st["events"] as Array).clear()
		guard += 1
	return {"won": bool(st["won"]), "games": st["games"], "time": float(st["t"])}


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var wins: int = 0
	var gsum: int = 0
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
		gsum += int(r["games"][0])
		tsum += float(r["time"])
		if bool(r["won"]):
			wins += 1
	if wins < 2:
		issues.append("tennis_too_hard")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": 0, "enemies": 1, "enemy_problems": [],
		"par": int(tsum / 3.0 * 1.2) + 10}
