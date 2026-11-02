extends RefCounted
## Tirachinas (estilo Angry Birds): lectura del nivel, balistica para apuntar y analizador.
## La fisica de los derrumbes es la de Godot (cuerpos rigidos) en sling_game.gd; el analizador
## comprueba sin jugar que el nivel tiene sentido y el bot de QA lo juega de verdad (estricto).
## 1 - Mapa (game.json -> levels[i].map), de arriba abajo, una casilla = CELL px, la ultima fila
##     apoyada en el suelo: "W" madera, "S" piedra, "I" hielo, "=" tablon (los seguidos en una
##     fila son una sola pieza), "|" poste (los seguidos en una columna, una sola pieza), "P"
##     cerdo, "K" cerdo rey (grande), "T" caja de TNT, "#" roca fija, "." aire. "#semilla".
## 2 - Lo de la izquierda del mapa empieza en STRUCT_X; el tirachinas esta en SLING.
## 3 - Pajaros (parametro "birds"): red (normal), yellow (toca: acelera en linea recta), blue
##     (toca: se parte en tres), black (toca o al chocar: explota).
## Parametros: "birds", "par" (puntos para 3 estrellas).

const CELL: float = 64.0
const GROUND_Y: float = 0.0
const STRUCT_X: float = 560.0
const SLING: Vector2 = Vector2(150.0, -150.0)
const G: float = 980.0
const MAX_PULL: float = 130.0
const POWER: float = 8.2
const BIRDS: Array[String] = ["red", "yellow", "blue", "black"]
## Material: vida, densidad (masa por casilla) y color.
const MATS: Dictionary = {"W": {"hp": 70.0, "mass": 1.0}, "S": {"hp": 180.0, "mass": 2.4}, "I": {"hp": 30.0, "mass": 0.8},
	"=": {"hp": 60.0, "mass": 0.8}, "|": {"hp": 60.0, "mass": 0.8}, "T": {"hp": 20.0, "mass": 0.8}}


## Piezas en px del mundo (y hacia abajo, suelo en y = 0): {"kind", "rect": Rect2, "mat"} y
## cerdos {"kind": "pig"|"king", "c": Vector2, "r"}.
static func parse(level: Dictionary) -> Dictionary:
	var rows: Array[String] = []
	var seed_v: int = int(level.get("seed", 1))
	for r: Variant in level.get("map", []):
		var row: String = str(r)
		if row.begins_with("#") and row.length() > 1 and row.substr(1).is_valid_int():
			seed_v = int(row.substr(1))
			continue
		rows.append(row)
	var h: int = rows.size()
	var pieces: Array = []
	var pigs: Array = []
	var used: Dictionary = {}
	for y: int in h:
		for x: int in rows[y].length():
			if used.has(Vector2i(x, y)):
				continue
			var ch: String = rows[y][x]
			var top: float = GROUND_Y - float(h - y) * CELL
			var left: float = STRUCT_X + float(x) * CELL
			## Encima de un tablon (que ocupa lo de abajo de su casilla) se apoya mas abajo.
			if y + 1 < h and x < (rows[y + 1] as String).length() and (rows[y + 1] as String)[x] == "=" and ch != "=":
				top += CELL * 0.7
			match ch:
				"W", "S", "I", "T", "#":
					pieces.append({"kind": "rock" if ch == "#" else "block", "mat": ch, "rect": Rect2(left, top, CELL, CELL)})
				"=":
					var n: int = 0
					while x + n < rows[y].length() and rows[y][x + n] == "=":
						used[Vector2i(x + n, y)] = true
						n += 1
					pieces.append({"kind": "block", "mat": "=", "rect": Rect2(left, top + CELL * 0.7, CELL * float(n), CELL * 0.3)})
				"|":
					var m: int = 0
					while y + m < h and x < rows[y + m].length() and rows[y + m][x] == "|":
						used[Vector2i(x, y + m)] = true
						m += 1
					pieces.append({"kind": "block", "mat": "|", "rect": Rect2(left + CELL * 0.35, top, CELL * 0.3, CELL * float(m))})
				"P":
					pigs.append({"kind": "pig", "c": Vector2(left + CELL * 0.5, top + CELL * 0.6 - 1.0), "r": CELL * 0.4})
				"K":
					pigs.append({"kind": "king", "c": Vector2(left + CELL * 0.5, top + CELL * 0.52 - 1.0), "r": CELL * 0.48})
	var birds: Array[String] = []
	for b: Variant in level.get("birds", ["red", "red", "red"]):
		if BIRDS.has(str(b)):
			birds.append(str(b))
	if birds.is_empty():
		birds = ["red", "red", "red"]
	return {"rows": rows, "pieces": pieces, "pigs": pigs, "birds": birds, "seed": seed_v,
		"width": float(rows[0].length() if not rows.is_empty() else 1) * CELL}


## Velocidad de salida para un tiron (vector desde el tirachinas hacia atras, en px).
static func launch_velocity(pull: Vector2) -> Vector2:
	var p: Vector2 = pull.limit_length(MAX_PULL)
	return -p * POWER


static func max_speed() -> float:
	return MAX_PULL * POWER


## Posicion de un tiro a los t segundos (sin rozamiento).
static func at_time(from: Vector2, v: Vector2, t: float) -> Vector2:
	return from + v * t + Vector2(0, 0.5 * G * t * t)


## Angulos que llevan un tiro de velocidad "speed" desde "from" hasta "to" (alto y bajo); [] si no llega.
static func aim_angles(from: Vector2, to: Vector2, speed: float) -> Array[float]:
	var dx: float = to.x - from.x
	var dy: float = -(to.y - from.y)
	var v2: float = speed * speed
	var disc: float = v2 * v2 - G * (G * dx * dx + 2.0 * dy * v2)
	if disc < 0.0 or absf(dx) < 1.0:
		return []
	var s: float = sqrt(disc)
	return [atan2(v2 - s, G * dx), atan2(v2 + s, G * dx)]


## Tiron (pull) que lanza con ese angulo (rad, hacia arriba positivo) y velocidad.
static func pull_for(angle: float, speed: float) -> Vector2:
	var v: Vector2 = Vector2(cos(angle), -sin(angle)) * speed
	return -v / POWER


# ------------------------------------------------------------------ analizador

static func analyze(level: Dictionary) -> Dictionary:
	var info: Dictionary = parse(level)
	var issues: Array[String] = []
	if (info["pigs"] as Array).is_empty():
		issues.append("sling_no_pigs")
	if (info["rows"] as Array).is_empty():
		issues.append("sling_empty")
	## Cada cerdo tiene que estar al alcance de un tiro a toda potencia.
	for pg: Dictionary in info["pigs"]:
		if aim_angles(SLING, pg["c"], max_speed() * 0.97).is_empty():
			issues.append("sling_out_of_range")
			break
	## Todo apoyado: cada casilla solida o cerdo tiene algo debajo (o es la fila del suelo).
	var rows: Array = info["rows"]
	for y: int in rows.size() - 1:
		var row: String = rows[y]
		for x: int in row.length():
			var ch: String = row[x]
			if "WSITPK#=".contains(ch):
				var below: String = (rows[y + 1] as String)[x] if x < (rows[y + 1] as String).length() else "."
				if below == "." and not (ch == "=" and _plank_held(rows, x, y)):
					issues.append("sling_floating")
					break
		if issues.has("sling_floating"):
			break
	if (info["birds"] as Array).size() < (info["pigs"] as Array).size() / 3 + 1:
		issues.append("sling_few_birds")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": (info["pigs"] as Array).size(), "enemies": 0,
		"enemy_problems": [], "par": int(level.get("par", 0))}


## Un tablon se sostiene si algun trozo suyo tiene algo debajo.
static func _plank_held(rows: Array, x: int, y: int) -> bool:
	var row: String = rows[y]
	var a: int = x
	while a > 0 and row[a - 1] == "=":
		a -= 1
	var b: int = x
	while b < row.length() - 1 and row[b + 1] == "=":
		b += 1
	for k: int in range(a, b + 1):
		var below: String = rows[y + 1]
		if k < below.length() and below[k] != ".":
			return true
	return false
