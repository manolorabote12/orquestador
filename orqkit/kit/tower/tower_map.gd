class_name TowerMap
extends RefCounted
## Mapas del tower defense. Leyenda: "." se puede construir, "=" camino, "S" entrada del camino,
## "B" base (lo que defiendes), "#" roca (ni camino ni torre).
## El analizador comprueba sin jugar que:
## 1 - Hay una S y una B unidas por un unico camino (sin cruces ni atajos: cada casilla de
##     camino tiene como mucho 2 vecinas de camino).
## 2 - El camino es largo (14 casillas o mas): da tiempo a disparar.
## 3 - Hay sitio para torres junto al camino (12 casillas construibles a 1 de distancia o mas).


static func rows_of(map: Array) -> Array[String]:
	return LevelBuilder.normalize(map)


static func is_path(ch: String) -> bool:
	return ch == "=" or ch == "S" or ch == "B"


## Casillas del camino en orden, de S a B (vacio si no hay camino).
static func path_cells(rows: Array[String]) -> Array[Vector2i]:
	var start: Vector2i = find(rows, "S")
	var out: Array[Vector2i] = []
	if start.x < 0:
		return out
	var prev: Vector2i = Vector2i(-9, -9)
	var cur: Vector2i = start
	for guard: int in 400:
		out.append(cur)
		if rows[cur.y][cur.x] == "B":
			return out
		var nxt: Vector2i = Vector2i(-1, -1)
		for d: Vector2i in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
			var n: Vector2i = cur + d
			if n == prev or n.y < 0 or n.y >= rows.size() or n.x < 0 or n.x >= rows[0].length():
				continue
			if is_path(rows[n.y][n.x]) and not out.has(n):
				nxt = n
				break
		if nxt.x < 0:
			return []
		prev = cur
		cur = nxt
	return []


static func find(rows: Array[String], ch: String) -> Vector2i:
	for y: int in rows.size():
		var x: int = rows[y].find(ch)
		if x >= 0:
			return Vector2i(x, y)
	return Vector2i(-1, -1)


static func analyze(map: Array) -> Dictionary:
	var rows: Array[String] = rows_of(map)
	var issues: Array[String] = []
	if find(rows, "S").x < 0 or find(rows, "B").x < 0:
		return {"completable": false, "issues": ["td_no_path"], "coins_total": 0, "enemies": 0, "enemy_problems": []}
	var path: Array[Vector2i] = path_cells(rows)
	if path.is_empty():
		issues.append("td_broken_path")
	elif path.size() < 14:
		issues.append("td_short_path")
	## 1 - Sin cruces: ninguna casilla de camino con 3 o mas vecinas de camino.
	for y: int in rows.size():
		for x: int in rows[0].length():
			if not is_path(rows[y][x]):
				continue
			var n: int = 0
			for d: Vector2i in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
				var c: Vector2i = Vector2i(x, y) + d
				if c.y >= 0 and c.y < rows.size() and c.x >= 0 and c.x < rows[0].length() and is_path(rows[c.y][c.x]):
					n += 1
			if n > 2 and not issues.has("td_branch"):
				issues.append("td_branch")
	var spots: int = 0
	for y: int in rows.size():
		for x: int in rows[0].length():
			if rows[y][x] != ".":
				continue
			for d: Vector2i in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
				var c: Vector2i = Vector2i(x, y) + d
				if c.y >= 0 and c.y < rows.size() and c.x >= 0 and c.x < rows[0].length() and is_path(rows[c.y][c.x]):
					spots += 1
					break
	if spots < 12:
		issues.append("td_no_room")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": 0, "enemies": 0, "enemy_problems": [],
		"path_len": path.size(), "spots": spots}
