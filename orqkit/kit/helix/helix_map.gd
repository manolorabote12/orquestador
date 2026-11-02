extends RefCounted
## Torre en espiral (estilo Helix Jump): reglas, simulacion pura, bot y analizador.
## 1 - Mapa (game.json -> levels[i].map): una fila por piso, de arriba abajo, 12 casillas
##     alrededor de la torre: "." suelo, "o" hueco, "x" zona roja.
## 2 - La bola bota siempre por delante. Arrastras para girar la torre: si al caer tiene un hueco
##     debajo, baja al piso siguiente; si es suelo, rebota; si es rojo, se pierde.
## 3 - Bajando 3 pisos seguidos sin rebotar la bola se enciende y rompe el siguiente piso (aunque
##     sea rojo). Se gana al llegar abajo del todo.
## Parametros: "bounce" (segundos de un bote) y "spin" (velocidad maxima de giro de una persona).

const SLOTS: int = 12
const BALL_ANGLE: float = PI * 0.5
const FALL: float = 0.3


static func floors_of(level: Dictionary) -> Array:
	var out: Array = []
	for r: Variant in level.get("map", []):
		var s: String = str(r).strip_edges()
		if s.length() == SLOTS:
			out.append(s)
	return out


static func new_state(level: Dictionary) -> Dictionary:
	return {"floors": floors_of(level), "floor": 0, "rot": 0.0, "next": float(level.get("bounce", 0.6)), "bounce": float(level.get("bounce", 0.6)),
		"streak": 0, "time": 0.0, "dead": false, "won": false, "score": 0, "smashed": {}, "falling": false}


static func slot_under(st: Dictionary) -> int:
	var a: float = fposmod(BALL_ANGLE - float(st["rot"]), TAU)
	return int(a / (TAU / float(SLOTS))) % SLOTS


## Giro de la torre que deja la casilla k debajo de la bola (centrada).
static func rot_for(k: int) -> float:
	return BALL_ANGLE - (float(k) + 0.5) * TAU / float(SLOTS)


static func step(st: Dictionary, dt: float) -> String:
	if st["dead"] or st["won"]:
		return ""
	st["time"] = float(st["time"]) + dt
	st["next"] = float(st["next"]) - dt
	if float(st["next"]) > 0.0:
		return ""
	var fl: Array = st["floors"]
	var i: int = int(st["floor"])
	if i >= fl.size():
		st["won"] = true
		return "win"
	var ch: String = str(fl[i])[slot_under(st)]
	if ch == "o" or int(st["streak"]) >= 3:
		if ch != "o":
			st["smashed"][i] = true
		st["floor"] = i + 1
		st["streak"] = int(st["streak"]) + 1 if ch == "o" else 0
		st["score"] = int(st["score"]) + 1 + int(st["streak"])
		st["next"] = FALL
		if int(st["floor"]) >= fl.size():
			st["won"] = true
			return "win"
		return "pass"
	if ch == "x":
		st["dead"] = true
		return "dead"
	st["streak"] = 0
	st["next"] = float(st["bounce"])
	return "bounce"


## El bot: si llega al hueco antes de caer, gira hacia el; si no, se queda (o se aparta) sobre
## suelo seguro y espera al siguiente bote, con la velocidad de giro de una persona.
static func bot_target(st: Dictionary, spin: float) -> float:
	var fl: Array = st["floors"]
	var i: int = int(st["floor"])
	if i >= fl.size():
		return float(st["rot"])
	var row: String = fl[i]
	var reach: float = spin * maxf(0.0, float(st["next"]) - 0.06)
	var best: float = INF
	for k: int in SLOTS:
		if row[k] != "o":
			continue
		var d: float = wrapf(rot_for(k) - float(st["rot"]), -PI, PI)
		if absf(d) <= reach and (best == INF or absf(d) < absf(best)):
			best = d
	if best != INF:
		return float(st["rot"]) + best
	## 2 - No llega: acercarse al hueco mas cercano lo que se pueda, parando sobre suelo seguro.
	var gap_d: float = INF
	for k3: int in SLOTS:
		if row[k3] == "o":
			var d3: float = wrapf(rot_for(k3) - float(st["rot"]), -PI, PI)
			if gap_d == INF or absf(d3) < absf(gap_d):
				gap_d = d3
	var sgn: float = signf(gap_d) if gap_d != INF else 1.0
	var best2: float = INF
	var pick: float = 0.0
	for k2: int in SLOTS:
		if row[k2] == "x":
			continue
		var d2: float = wrapf(rot_for(k2) - float(st["rot"]), -PI, PI)
		if absf(d2) > reach and absf(d2) > 0.27:
			continue
		## Preferir lo que mas acerca al hueco (en su direccion).
		var score: float = d2 * sgn - (0.0 if absf(d2) <= reach else 10.0)
		if best2 == INF or score > best2:
			best2 = score
			pick = d2
	return float(st["rot"]) + pick


static func spin_toward(st: Dictionary, target: float, max_speed: float, dt: float) -> void:
	var d: float = target - float(st["rot"])
	st["rot"] = float(st["rot"]) + clampf(d, -max_speed * dt, max_speed * dt)


static func bot_play(level: Dictionary) -> Dictionary:
	var st: Dictionary = new_state(level)
	var spin: float = float(level.get("spin", 5.0))
	var dt: float = 1.0 / 30.0
	var guard: int = 0
	## Reaccion humana: decide el giro un poco tarde (0,15 s despues de cada bote).
	var react: float = 0.0
	while not st["won"] and not st["dead"] and guard < 30 * 300:
		guard += 1
		react -= dt
		if react <= 0.0:
			spin_toward(st, bot_target(st, spin), spin, dt)
		var ev: String = step(st, dt)
		if ev == "bounce" or ev == "pass":
			react = 0.15
	return {"won": bool(st["won"]), "dead": bool(st["dead"]), "time": float(st["time"])}


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var fl: Array = floors_of(level)
	if fl.size() < 5 or fl.size() > 60:
		issues.append("helix_floors")
	if fl.size() != (level.get("map", []) as Array).size():
		issues.append("helix_row")
	for r: String in fl:
		if not r.contains("o"):
			issues.append("helix_no_gap")
			break
	var par: int = 0
	if issues.is_empty():
		var r: Dictionary = bot_play(level)
		if not bool(r["won"]):
			issues.append("helix_too_hard")
		par = int(r["time"])
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": fl.size(), "enemies": 0, "enemy_problems": [], "par": par}
