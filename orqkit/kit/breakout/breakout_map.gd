extends RefCounted
## Analizador del rompebloques: comprueba SIN jugar que un nivel es justo.
## 1 - Todas las filas miden 9 y solo usan ".123#CLM"; entre 3 y 12 filas.
## 2 - Al menos 12 ladrillos que se rompen.
## 3 - Todos los ladrillos que se rompen son alcanzables: la pelota llega desde abajo por los
##     huecos, y cada ladrillo roto abre paso (el acero nunca).
## 4 - No hay una fila entera de acero (encerraria todo lo de arriba).

const COLS: int = 9
const VALID: String = ".123#CLM"


static func analyze(level: Dictionary) -> Dictionary:
	var rows: Array[String] = []
	for r: Variant in level.get("map", []):
		rows.append(str(r))
	var issues: Array[String] = []
	var breakable: int = 0
	var coins: int = 0
	if rows.size() < 3 or rows.size() > 12:
		issues.append("breakout_rows")
	for r: String in rows:
		if r.length() != COLS:
			if not issues.has("breakout_bad_row"):
				issues.append("breakout_bad_row")
			continue
		for ch: String in r:
			if not VALID.contains(ch) and not issues.has("breakout_bad_char"):
				issues.append("breakout_bad_char")
			if ch != "." and ch != "#":
				breakable += 1
			if ch == "C":
				coins += 1
		if r == "#".repeat(COLS):
			issues.append("breakout_steel_wall")
	if breakable < 12:
		issues.append("breakout_few_bricks")
	if issues.is_empty() and not all_reachable(rows):
		issues.append("breakout_unreachable")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": coins, "enemies": 0,
		"enemy_problems": [], "bricks": breakable}


## 3 - Inundacion desde abajo: huecos conectados con la zona de la pala; un ladrillo pegado a
##     una zona alcanzada se puede romper y abre su casilla.
static func all_reachable(rows: Array[String]) -> bool:
	var h: int = rows.size()
	var open: Dictionary = {}
	var changed: bool = true
	## La fila "h" (debajo del todo) es la zona de juego: siempre abierta.
	for c: int in COLS:
		open[Vector2i(c, h)] = true
	while changed:
		changed = false
		for r: int in range(h - 1, -1, -1):
			for c: int in COLS:
				var k: Vector2i = Vector2i(c, r)
				if open.has(k) or rows[r][c] == "#":
					continue
				for d: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
					if open.has(k + d):
						open[k] = true
						changed = true
						break
	for r: int in h:
		for c: int in COLS:
			if rows[r][c] != "." and rows[r][c] != "#" and not open.has(Vector2i(c, r)):
				return false
	return true
