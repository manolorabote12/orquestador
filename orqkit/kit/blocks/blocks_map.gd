extends RefCounted
## Analizador del puzle de bloques: comprueba SIN jugar que un nivel es justo.
## 1 - 8 filas de 8 con ".#G".
## 2 - Como mucho un 40 % del tablero ocupado al empezar y ninguna linea ya llena.
## 3 - Hay objetivo: gemas (como mucho 12) o un numero de lineas (lines >= 1).
## 4 - El par de piezas es razonable (entre 8 y 80).

const N: int = 8


static func analyze(level: Dictionary) -> Dictionary:
	var rows: Array[String] = []
	for r: Variant in level.get("map", []):
		rows.append(str(r))
	var issues: Array[String] = []
	var gems: int = 0
	var filled: int = 0
	if rows.size() != N:
		issues.append("blocks_bad_size")
	for r: String in rows:
		if r.length() != N:
			if not issues.has("blocks_bad_size"):
				issues.append("blocks_bad_size")
			continue
		for ch: String in r:
			if not ".#G".contains(ch) and not issues.has("blocks_bad_char"):
				issues.append("blocks_bad_char")
			if ch != ".":
				filled += 1
			if ch == "G":
				gems += 1
		if not r.contains(".") and not issues.has("blocks_full_line"):
			issues.append("blocks_full_line")
	if issues.is_empty():
		for x: int in N:
			var full: bool = true
			for y: int in N:
				if rows[y][x] == ".":
					full = false
			if full:
				issues.append("blocks_full_line")
				break
	if filled > int(N * N * 0.4):
		issues.append("blocks_crowded")
	if gems > 12:
		issues.append("blocks_many_gems")
	if gems == 0 and int(level.get("lines", 0)) < 1:
		issues.append("blocks_no_goal")
	var p: int = int(level.get("par", 24))
	if p < 8 or p > 80:
		issues.append("blocks_bad_par")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": gems, "enemies": 0, "enemy_problems": []}
