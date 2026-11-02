extends RefCounted
## Analizador del genero naves: comprueba SIN jugar que un nivel es justo.
## 1 - Todas las filas miden 7 y solo usan ".EZTACWB".
## 2 - Al menos 12 filas; las 2 primeras sin enemigos que disparen (hay que poder colocarse).
## 3 - El jefe "B" solo en la ultima fila y como mucho uno.
## 4 - Ninguna fila tapa el paso: como mucho 5 amenazas y nunca mas de 4 rocas.
## 5 - Nunca mas de 5 tiradores (E o T) en 3 filas seguidas: las balas siempre se pueden esquivar.

const COLS: int = 7
const VALID: String = ".EZTACWB"


static func analyze(level: Dictionary) -> Dictionary:
	var rows: Array[String] = []
	for r: Variant in level.get("map", []):
		rows.append(str(r))
	var issues: Array[String] = []
	var coins: int = 0
	var enemies: int = 0
	var bosses: int = 0
	if rows.size() < 12:
		issues.append("shooter_short")
	for y: int in rows.size():
		var r: String = rows[y]
		if r.length() != COLS:
			if not issues.has("shooter_bad_row"):
				issues.append("shooter_bad_row")
			continue
		var threats: int = 0
		var rocks: int = 0
		for ch: String in r:
			if not VALID.contains(ch):
				if not issues.has("shooter_bad_char"):
					issues.append("shooter_bad_char")
			if "EZTA".contains(ch):
				threats += 1
				enemies += 1
			if ch == "A":
				rocks += 1
			if ch == "C":
				coins += 1
			if ch == "B":
				bosses += 1
				if y != rows.size() - 1 and not issues.has("shooter_boss_not_last"):
					issues.append("shooter_boss_not_last")
		if threats > 5 or rocks > 4:
			if not issues.has("shooter_wall"):
				issues.append("shooter_wall")
		if y < 2 and (r.contains("E") or r.contains("T")):
			if not issues.has("shooter_hot_start"):
				issues.append("shooter_hot_start")
	if bosses > 1:
		issues.append("shooter_two_bosses")
	for y: int in maxi(rows.size() - 2, 0):
		var n: int = 0
		for k: int in 3:
			n += rows[y + k].count("E") + rows[y + k].count("T")
		if n > 5:
			issues.append("shooter_bullet_hell")
			break
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": coins, "enemies": enemies,
		"enemy_problems": [], "rows": rows.size(), "boss": bosses == 1}
