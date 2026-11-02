extends RefCounted
## Minigolf: la fisica de la bola y el analizador. El juego, el bot y el analizador usan la MISMA
## funcion step(): lo que el bot prueba en su cabeza es exactamente lo que pasa al tirar.
## Unidades: casillas y segundos (el juego multiplica por CELL para dibujar).
## Mapa: "#" muro, "." cesped, "B" bola, "H" hoyo, "W" agua (golpe de castigo y vuelves),
## "S" arena (frena mucho). Parametros del nivel: "par" (golpes para 3 estrellas).
## Mezcla con el RPG (giro "monstruos"): "M" monstruos en el campo. La bola los derriba al
## pasar; el hoyo esta cerrado hasta derribarlos a todos.
## Giro "viento" (level.wind, casillas/s2): empuja la bola mientras rueda (nunca mas que el
## rozamiento, asi que siempre acaba parando).
## 1 - Todas las filas miden lo mismo; una bola y un hoyo.
## 2 - El plan del bot (el mismo que usa QA) mete la bola en par + 2 golpes como mucho.

const DT: float = 1.0 / 60.0
const MAX_SPEED: float = 14.0
const RADIUS: float = 0.18
const HOLE_R: float = 0.3
const SINK_SPEED: float = 6.5
const BOUNCE: float = 0.75
const MAX_STEPS: int = 600
const ANGLES: int = 40
const POWERS: Array[float] = [0.18, 0.3, 0.42, 0.55, 0.7, 0.85, 1.0]
const MONSTER_R: float = 0.42


static func parse(level: Dictionary) -> Array[String]:
	var rows: Array[String] = []
	for r: Variant in level.get("map", []):
		rows.append(str(r))
	return rows


static func find(rows: Array[String], ch: String) -> Vector2:
	for y: int in rows.size():
		var x: int = rows[y].find(ch)
		if x >= 0:
			return Vector2(float(x) + 0.5, float(y) + 0.5)
	return Vector2(-1.0, -1.0)


static func tile(rows: Array[String], p: Vector2) -> String:
	var x: int = int(floorf(p.x))
	var y: int = int(floorf(p.y))
	if y < 0 or y >= rows.size() or x < 0 or x >= rows[y].length():
		return "#"
	return rows[y][x]


static func _solid(rows: Array[String], p: Vector2) -> bool:
	return tile(rows, p + Vector2(RADIUS, 0.0)) == "#" or tile(rows, p - Vector2(RADIUS, 0.0)) == "#" \
		or tile(rows, p + Vector2(0.0, RADIUS)) == "#" or tile(rows, p - Vector2(0.0, RADIUS)) == "#"


## 3 - Un paso de fisica. Devuelve [pos, vel, estado]: "rueda", "parada", "hoyo" o "agua".
static func step(rows: Array[String], pos: Vector2, vel: Vector2, hole: Vector2, hole_open: bool = true, wind: Vector2 = Vector2.ZERO) -> Array:
	var p: Vector2 = pos
	var v: Vector2 = vel + wind * DT
	var nx: Vector2 = Vector2(p.x + v.x * DT, p.y)
	if _solid(rows, nx):
		v.x = -v.x * BOUNCE
	else:
		p = nx
	var ny: Vector2 = Vector2(p.x, p.y + v.y * DT)
	if _solid(rows, ny):
		v.y = -v.y * BOUNCE
	else:
		p = ny
	var sand: bool = tile(rows, p) == "S"
	var speed: float = v.length()
	var decel: float = (4.5 + 3.2 * speed) if sand else (1.4 + 0.75 * speed)
	speed = maxf(0.0, speed - decel * DT)
	v = v.normalized() * speed if speed > 0.0 else Vector2.ZERO
	if hole_open and p.distance_to(hole) < HOLE_R and speed < SINK_SPEED:
		return [hole, Vector2.ZERO, "hoyo"]
	if tile(rows, p) == "W":
		return [p, Vector2.ZERO, "agua"]
	if speed < 0.06:
		return [p, Vector2.ZERO, "parada"]
	return [p, v, "rueda"]


## 4 - Tiro completo en la cabeza: donde acaba, como y que monstruos derriba por el camino.
static func simulate(rows: Array[String], pos: Vector2, vel: Vector2, hole: Vector2, monsters: Array[Vector2] = [], wind: Vector2 = Vector2.ZERO) -> Dictionary:
	var p: Vector2 = pos
	var v: Vector2 = vel
	var alive: Array[Vector2] = monsters.duplicate()
	var hits: Array[Vector2] = []
	for i: int in MAX_STEPS:
		var r: Array = step(rows, p, v, hole, alive.is_empty(), wind)
		p = r[0]
		v = r[1]
		for k: int in range(alive.size() - 1, -1, -1):
			if p.distance_to(alive[k]) < MONSTER_R:
				hits.append(alive[k])
				alive.remove_at(k)
		if str(r[2]) != "rueda":
			return {"end": p, "state": str(r[2]), "hits": hits}
	return {"end": p, "state": "parada", "hits": hits}


static func monsters_of(rows: Array[String]) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for y: int in rows.size():
		for x: int in rows[y].length():
			if rows[y][x] == "M":
				out.append(Vector2(float(x) + 0.5, float(y) + 0.5))
	return out


## 5 - Distancia andando (casillas) desde cada casilla a las metas (el hoyo o los monstruos),
## sin cruzar muros ni agua.
static func distances(rows: Array[String], hole: Vector2, targets: Array[Vector2] = []) -> Dictionary:
	var dist: Dictionary = {}
	var queue: Array[Vector2i] = []
	var goals: Array[Vector2] = targets.duplicate()
	if goals.is_empty():
		goals.append(hole)
	for g: Vector2 in goals:
		var c0: Vector2i = Vector2i(int(g.x), int(g.y))
		dist[c0] = 0
		queue.append(c0)
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if dist.has(n) or n.y < 0 or n.y >= rows.size() or n.x < 0 or n.x >= rows[n.y].length():
				continue
			var ch: String = rows[n.y][n.x]
			if ch == "#" or ch == "W":
				continue
			dist[n] = int(dist[c]) + 1
			queue.append(n)
	return dist


## 6 - El mejor tiro que se le ocurre al bot: si alguno mete la bola, ese; si quedan monstruos,
## el que derriba mas; si no, el que deja la bola mas cerca de la meta andando (nunca al agua).
static func plan_shot(rows: Array[String], pos: Vector2, hole: Vector2, dist: Dictionary, monsters: Array[Vector2] = [], wind: Vector2 = Vector2.ZERO) -> Vector2:
	var best: Vector2 = Vector2.ZERO
	var best_score: float = INF
	var to_monsters: Dictionary = distances(rows, hole, monsters) if not monsters.is_empty() else dist
	for a: int in ANGLES:
		var ang: float = TAU * float(a) / float(ANGLES)
		var dir: Vector2 = Vector2(cos(ang), sin(ang))
		for pw: float in POWERS:
			var vel: Vector2 = dir * pw * MAX_SPEED
			var r: Dictionary = simulate(rows, pos, vel, hole, monsters, wind)
			if r["state"] == "hoyo":
				return vel
			if r["state"] == "agua":
				continue
			var e: Vector2 = r["end"]
			var c: Vector2i = Vector2i(int(e.x), int(e.y))
			var hits: int = (r["hits"] as Array).size()
			var left: bool = hits < monsters.size()
			var table: Dictionary = to_monsters if left else dist
			if not table.has(c):
				continue
			var score: float = float(table[c]) - float(hits) * 1000.0 + pw * 0.01
			if not left:
				score += e.distance_to(hole) * 0.3
			if score < best_score:
				best_score = score
				best = vel
	return best


## 7 - Cuantos golpes necesita el plan del bot (0 = no la mete en 'limit').
static func strokes_needed(rows: Array[String], limit: int, wind: Vector2 = Vector2.ZERO) -> int:
	var ball: Vector2 = find(rows, "B")
	var hole: Vector2 = find(rows, "H")
	var dist: Dictionary = distances(rows, hole)
	var alive: Array[Vector2] = monsters_of(rows)
	var pos: Vector2 = ball
	for s: int in limit:
		var vel: Vector2 = plan_shot(rows, pos, hole, dist, alive, wind)
		if vel == Vector2.ZERO:
			return 0
		var r: Dictionary = simulate(rows, pos, vel, hole, alive, wind)
		if r["state"] == "hoyo":
			return s + 1
		for h: Vector2 in r["hits"]:
			alive.erase(h)
		if r["state"] != "agua":
			pos = r["end"]
	return 0


static func analyze(level: Dictionary) -> Dictionary:
	var rows: Array[String] = parse(level)
	var issues: Array[String] = []
	if rows.is_empty():
		issues.append("grid_empty")
	var balls: int = 0
	var holes: int = 0
	for y: int in rows.size():
		if rows[y].length() != rows[0].length():
			if not issues.has("grid_bad_rows"):
				issues.append("grid_bad_rows")
			continue
		for x: int in rows[y].length():
			var ch: String = rows[y][x]
			if ch == "B":
				balls += 1
			elif ch == "H":
				holes += 1
			elif not "#.WSM".contains(ch):
				if not issues.has("grid_bad_char"):
					issues.append("grid_bad_char")
	if balls != 1 or holes != 1:
		issues.append("golf_ball_hole")
	var par: int = int(level.get("par", 3))
	var need: int = 0
	if issues.is_empty():
		need = strokes_needed(rows, par + 2, wind_of(level))
		if need == 0:
			issues.append("golf_too_hard")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": 0, "enemies": 0, "enemy_problems": [],
		"strokes": need}


static func wind_of(level: Dictionary) -> Vector2:
	var w: Variant = level.get("wind", [])
	if w is Array and (w as Array).size() == 2:
		return Vector2(float(w[0]), float(w[1])).limit_length(1.0)
	return Vector2.ZERO
