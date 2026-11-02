extends RefCounted
## Pesca: las reglas del tiempo y el analizador. El juego, el bot y el analizador usan las MISMAS
## funciones (lo que el bot calcula es exactamente lo que pasa).
## Mapa: una fila por franja de agua, de arriba abajo. "." agua, "F" pez, "X" medusa. Las filas
## dan la vuelta: cada franja se mueve a su velocidad (parametro "speeds", casillas/s; el signo
## es el sentido). El anzuelo baja por el centro (x = ancho / 2).
## Parametros: "speeds" (una por fila), "goal" (peces para ganar), "time" (segundos).
## Giro "tormenta" (level.storm): las franjas van cada vez mas rapido (velocidad x (1 + 2 storm t)).
## 1 - Filas iguales, una velocidad por fila, al menos 'goal' peces.
## 2 - Pescando como el bot (soltar en cuanto el anzuelo vaya a coger un pez sin tocar medusas)
##     se llega a la meta con al menos un 20 % del tiempo de sobra.

const DESCEND: float = 5.0
const RISE: float = 8.0
const HALF: float = 0.38
const STING_PENALTY: float = 2.0


static func parse(level: Dictionary) -> Array[String]:
	var rows: Array[String] = []
	for r: Variant in level.get("map", []):
		rows.append(str(r))
	return rows


static func speeds_of(level: Dictionary, n: int) -> Array[float]:
	var out: Array[float] = []
	var raw: Array = level.get("speeds", [])
	for i: int in n:
		out.append(float(raw[i]) if i < raw.size() else (1.5 if i % 2 == 0 else -1.5))
	return out


## Posicion (0..ancho) del inicio de la casilla 'x' de la fila 'lane' en el instante t.
static func pos_at(x: int, speed: float, t: float, width: int, storm: float = 0.0) -> float:
	return fposmod(float(x) + speed * (t + storm * t * t), float(width))


## 3 - Que hay bajo el anzuelo en la fila 'lane' en el instante t: "F" (y su x), "X" o "".
static func under_hook(rows: Array[String], speeds: Array[float], lane: int, t: float, taken: Dictionary, storm: float = 0.0) -> Array:
	var w: int = rows[lane].length()
	var hx: float = float(w) * 0.5
	var found: Array = ["", -1]
	for x: int in w:
		var ch: String = rows[lane][x]
		if ch == "." or taken.has(Vector2i(x, lane)):
			continue
		var p: float = pos_at(x, speeds[lane], t, w, storm)
		## La pieza ocupa [p, p + 1) dando la vuelta; el anzuelo, [hx - HALF, hx + HALF].
		var d: float = fposmod(hx - p, float(w))
		if d < 1.0 + HALF or d > float(w) - HALF:
			if ch == "X":
				return ["X", x]
			found = ["F", x]
	return found


## 4 - Si se suelta el anzuelo en t: [resultado, fila, x, instante]. resultado: "pez", "medusa"
## o "nada" (llega al fondo).
static func drop_result(rows: Array[String], speeds: Array[float], t: float, taken: Dictionary, storm: float = 0.0) -> Array:
	for lane: int in rows.size():
		var tl: float = t + (float(lane) + 0.5) / DESCEND
		var u: Array = under_hook(rows, speeds, lane, tl, taken, storm)
		if u[0] == "X":
			return ["medusa", lane, int(u[1]), tl]
		if u[0] == "F":
			return ["pez", lane, int(u[1]), tl]
	return ["nada", rows.size() - 1, -1, t + float(rows.size()) / DESCEND]


## Cuando vuelve a estar libre el anzuelo tras llegar a la fila 'lane' en el instante t.
static func back_at(lane: int, t: float) -> float:
	return t + (float(lane) + 0.5) / RISE


## 5 - Partida del bot en la cabeza: segundos que tarda en pescar 'goal' peces (INF si no puede).
static func bot_time(rows: Array[String], speeds: Array[float], goal: int, limit: float, storm: float = 0.0) -> float:
	var taken: Dictionary = {}
	var t: float = 0.0
	var caught: int = 0
	while t < limit:
		var r: Array = drop_result(rows, speeds, t, taken, storm)
		if r[0] == "pez":
			taken[Vector2i(int(r[2]), int(r[1]))] = true
			caught += 1
			t = back_at(int(r[1]), float(r[3]))
			if caught >= goal:
				return t
		else:
			t += 1.0 / 60.0
	return INF


static func analyze(level: Dictionary) -> Dictionary:
	var rows: Array[String] = parse(level)
	var issues: Array[String] = []
	var fish: int = 0
	if rows.is_empty():
		issues.append("grid_empty")
	for y: int in rows.size():
		if rows[y].length() != rows[0].length() or rows[y].length() < 6:
			if not issues.has("grid_bad_rows"):
				issues.append("grid_bad_rows")
			continue
		for x: int in rows[y].length():
			var ch: String = rows[y][x]
			if ch == "F":
				fish += 1
			elif ch != "." and ch != "X":
				if not issues.has("grid_bad_char"):
					issues.append("grid_bad_char")
	var goal: int = int(level.get("goal", 5))
	var limit: float = float(level.get("time", 60.0))
	if fish < goal:
		issues.append("fishing_not_enough_fish")
	var used: float = INF
	if issues.is_empty():
		used = bot_time(rows, speeds_of(level, rows.size()), goal, limit, float(level.get("storm", 0.0)))
		if used > limit * 0.8:
			issues.append("fishing_too_hard")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": fish, "enemies": 0, "enemy_problems": [],
		"bot_time": used}
