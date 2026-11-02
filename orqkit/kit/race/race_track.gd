class_name RaceTrack
extends RefCounted
## Pistas de las carreras. Cada fila del mapa es un tramo de carretera, de la salida (fila 0)
## a la meta (ultima fila): primer caracter = curva ("<" izquierda, ">" derecha, "|" recta) y
## despues 4 carriles: "." libre, "C" moneda, "N" turbo, "O" cono, "T" coche lento.
## El analizador comprueba sin jugar que:
## 1 - La pista mide al menos 120 tramos y las 8 primeras filas estan limpias.
## 2 - Nunca hay una fila con los 4 carriles cortados.
## 3 - Siempre hay paso cambiando como mucho un carril por tramo (no hay muros imposibles).

const LANES: int = 4


static func blocked(ch: String) -> bool:
	return ch == "O" or ch == "T"


static func analyze(level: Dictionary) -> Dictionary:
	var rows: Array = level.get("map", [])
	var issues: Array[String] = []
	if rows.size() < 120:
		issues.append("race_short")
	for i: int in rows.size():
		var r: String = str(rows[i])
		if r.length() != LANES + 1 or not "<>|".contains(r[0]):
			if not issues.has("race_bad_row"):
				issues.append("race_bad_row")
			continue
		if i < 8 and (r.contains("O") or r.contains("T")):
			if not issues.has("race_start_blocked"):
				issues.append("race_start_blocked")
		var free: int = 0
		for l: int in LANES:
			if not blocked(r[l + 1]):
				free += 1
		if free == 0 and not issues.has("race_wall"):
			issues.append("race_wall")
	if not issues.has("race_bad_row"):
		## 3 - Carriles alcanzables fila a fila (se puede cambiar un carril por tramo).
		var reach: Array[bool] = [true, true, true, true]
		for i: int in rows.size():
			var r: String = str(rows[i])
			var nxt: Array[bool] = [false, false, false, false]
			for l: int in LANES:
				if blocked(r[l + 1]):
					continue
				for d: int in [-1, 0, 1]:
					var p: int = l + d
					if p >= 0 and p < LANES and reach[p]:
						nxt[l] = true
			reach = nxt
			if not reach.has(true):
				issues.append("race_blocked")
				break
	var coins: int = 0
	for r: Variant in rows:
		coins += str(r).count("C")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": coins, "enemies": 0, "enemy_problems": [],
		"rows": rows.size()}
