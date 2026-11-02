extends RefCounted
## Analizador del corredor 3D: comprueba SIN jugar que un nivel es justo.
## 1 - Filas de 3 carriles con ".CBHW"; al menos 60 filas; las 4 primeras sin obstaculos.
## 2 - Nunca 3 trenes en una fila (muro) ni dos filas con obstaculos seguidas (tiempo de reaccion).
## 3 - Siempre hay un carril sin tren alcanzable cambiando como mucho un carril entre filas con
##     trenes (las vallas y barras se saltan o se pasan agachado: no cortan el paso).

const LANES: int = 3


static func blocked(ch: String) -> bool:
	return ch == "W"


static func obstacle(ch: String) -> bool:
	return ch == "W" or ch == "B" or ch == "H"


static func analyze(level: Dictionary) -> Dictionary:
	var rows: Array[String] = []
	for r: Variant in level.get("map", []):
		rows.append(str(r))
	var issues: Array[String] = []
	var coins: int = 0
	if rows.size() < 60:
		issues.append("lanes_short")
	var prev_obstacle: bool = false
	for i: int in rows.size():
		var r: String = rows[i]
		if r.length() != LANES:
			if not issues.has("lanes_bad_row"):
				issues.append("lanes_bad_row")
			continue
		var obs: bool = false
		for ch: String in r:
			if not ".CBHW".contains(ch) and not issues.has("lanes_bad_char"):
				issues.append("lanes_bad_char")
			if obstacle(ch):
				obs = true
			if ch == "C":
				coins += 1
		if obs and i < 4 and not issues.has("lanes_hot_start"):
			issues.append("lanes_hot_start")
		if r == "WWW" and not issues.has("lanes_wall"):
			issues.append("lanes_wall")
		if obs and prev_obstacle and not issues.has("lanes_too_close"):
			issues.append("lanes_too_close")
		prev_obstacle = obs
	if not issues.has("lanes_bad_row"):
		var reach: Array[bool] = [true, true, true]
		for r: String in rows:
			var nxt: Array[bool] = [false, false, false]
			for l: int in LANES:
				if blocked(r[l]):
					continue
				for dl: int in [-1, 0, 1]:
					var p: int = l + dl
					if p >= 0 and p < LANES and reach[p]:
						nxt[l] = true
			reach = nxt
			if not reach.has(true):
				issues.append("lanes_blocked")
				break
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": coins, "enemies": 0, "enemy_problems": [], "rows": rows.size()}
