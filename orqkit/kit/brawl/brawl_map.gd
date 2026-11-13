extends RefCounted
## Analizador de la arena: comprueba SIN jugar que un nivel es justo.
## 1 - Tamano razonable (9-25 de ancho, 11-31 de alto) y filas iguales.
## 2 - Una salida tuya (P) y de 1 a 6 rivales (R), ninguno a menos de 4 casillas de ti.
## 3 - Se llega andando a todos los rivales y a todas las cajas (las cajas cortan el paso
##     hasta que se rompen, asi que cuentan como muro).
## 4 - Rivales que se pueden ganar: vida, punteria, reaccion y gas dentro de margenes.
## 5 - Modos: "ball" pide las dos porterias (G y g) y se llega a ellas; "turrets", las dos
##     torretas (T y t); en los de equipo, como mucho 3 aliados (A) y tiempo de 60 a 300 s.

const NEIGHBORS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var map: Array = level.get("map", [])
	if map.is_empty():
		return {"completable": false, "issues": ["brawl_empty"], "coins_total": 0, "enemies": 0, "enemy_problems": []}
	var w: int = str(map[0]).length()
	var h: int = map.size()
	for r: Variant in map:
		if str(r).length() != w and not issues.has("brawl_bad_rows"):
			issues.append("brawl_bad_rows")
	if w < 9 or w > 25 or h < 11 or h > 31:
		issues.append("brawl_size")
	var start: Vector2i = Vector2i(-1, -1)
	var rivals: Array[Vector2i] = []
	var boxes: Array[Vector2i] = []
	var players: int = 0
	var marks: Dictionary = {}
	for y: int in h:
		var row: String = str(map[y])
		for x: int in mini(row.length(), w):
			match row[x]:
				"P":
					start = Vector2i(x, y)
					players += 1
				"R":
					rivals.append(Vector2i(x, y))
				"B":
					boxes.append(Vector2i(x, y))
				"A", "G", "g", "T", "t", "O":
					if not marks.has(row[x]):
						marks[row[x]] = []
					(marks[row[x]] as Array).append(Vector2i(x, y))
	if players != 1:
		issues.append("brawl_player")
	if rivals.is_empty() or rivals.size() > 6:
		issues.append("brawl_rivals")
	if issues.has("brawl_bad_rows") or players != 1:
		return {"completable": false, "issues": issues, "coins_total": boxes.size(), "enemies": rivals.size(), "enemy_problems": []}
	for r: Vector2i in rivals:
		if Vector2(r - start).length() < 4.0:
			issues.append("brawl_rival_close")
			break
	## Alcance desde tu salida.
	var seen: Dictionary = {start: true}
	var queue: Array[Vector2i] = [start]
	var head: int = 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		for n: Vector2i in NEIGHBORS:
			var nc: Vector2i = c + n
			if nc.x < 0 or nc.y < 0 or nc.x >= w or nc.y >= h or seen.has(nc):
				continue
			var ch: String = str(map[nc.y])[nc.x]
			if ch == "#" or ch == "B":
				continue
			seen[nc] = true
			queue.append(nc)
	for r: Vector2i in rivals:
		if not seen.has(r):
			issues.append("brawl_unreachable")
			break
	for b: Vector2i in boxes:
		var touch: bool = false
		for n: Vector2i in NEIGHBORS:
			if seen.has(b + n):
				touch = true
		if not touch:
			issues.append("brawl_box_closed")
			break
	var mode: String = str(level.get("mode", "showdown"))
	var need: Array = {"ball": ["G", "g"], "turrets": ["T", "t"]}.get(mode, [])
	for ch: String in need:
		if not marks.has(ch):
			issues.append("brawl_%s_missing" % mode)
			break
	for ch: String in marks.keys():
		for c: Variant in marks[ch]:
			if not seen.has(c) and not issues.has("brawl_unreachable"):
				issues.append("brawl_unreachable")
	if (marks.get("A", []) as Array).size() > 3:
		issues.append("brawl_allies")
	if mode in ["ball", "turrets"]:
		var t: float = float(level.get("time", 150.0))
		if t < 60.0 or t > 300.0:
			issues.append("brawl_time")
	if float(seen.size()) < float(w * h) * 0.45:
		issues.append("brawl_cramped")
	var hp: float = float(level.get("rival_hp", 2600.0))
	if hp < 1000.0 or hp > 6000.0:
		issues.append("brawl_rival_hp")
	if float(level.get("aim", 0.2)) < 0.04:
		issues.append("brawl_aim_perfect")
	if float(level.get("reaction", 0.45)) < 0.2:
		issues.append("brawl_too_fast")
	if float(level.get("gas_start", 40.0)) < 15.0 or float(level.get("gas_time", 40.0)) < 15.0:
		issues.append("brawl_gas_early")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": boxes.size(), "enemies": rivals.size(), "enemy_problems": []}
