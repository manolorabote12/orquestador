class_name HordeArena
extends RefCounted
## Analizador de arenas de hordas (vista desde arriba). Sin jugar comprueba que:
## 1 - Hay salida (P) y alrededor de ella un claro de 5x5 sin rocas.
## 2 - La arena es amplia (al menos 16x20) y casi todo es suelo libre (rocas <= 18 %).
## 3 - Todo el suelo esta conectado: no hay huecos encerrados donde nacerian enemigos atrapados.
## 4 - El borde esta cerrado por rocas (nadie se sale del mundo).


static func analyze(map: Array) -> Dictionary:
	var rows: Array[String] = LevelBuilder.normalize(map)
	var h: int = rows.size()
	var w: int = rows[0].length() if h > 0 else 0
	var issues: Array[String] = []
	var start: Vector2i = Vector2i(-1, -1)
	var free: int = 0
	for y: int in h:
		for x: int in w:
			if rows[y][x] == "P":
				start = Vector2i(x, y)
			if rows[y][x] != "#":
				free += 1
	if start.x < 0:
		return {"completable": false, "issues": ["no_spawn"], "coins_total": 0, "enemies": 0, "enemy_problems": []}
	if w < 16 or h < 20:
		issues.append("horde_small")
	var cells: int = maxi((w - 2) * (h - 2), 1)
	if float(cells - free) / float(cells) > 0.18 + 0.001:
		issues.append("horde_cramped")
	for dy: int in range(-2, 3):
		for dx: int in range(-2, 3):
			if _rock(rows, start.x + dx, start.y + dy):
				if not issues.has("horde_spawn_blocked"):
					issues.append("horde_spawn_blocked")
	for x: int in w:
		if rows[0][x] != "#" or rows[h - 1][x] != "#":
			if not issues.has("horde_open_border"):
				issues.append("horde_open_border")
	for y: int in h:
		if rows[y][0] != "#" or rows[y][w - 1] != "#":
			if not issues.has("horde_open_border"):
				issues.append("horde_open_border")
	## 3 - Relleno desde la salida.
	var seen: Dictionary = {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if seen.has(n) or _rock(rows, n.x, n.y):
				continue
			seen[n] = true
			queue.append(n)
	if seen.size() < free:
		issues.append("horde_pockets")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": 0, "enemies": 0, "enemy_problems": [],
		"free": free, "reachable": seen.size()}


static func _rock(rows: Array[String], x: int, y: int) -> bool:
	if y < 0 or y >= rows.size() or x < 0 or x >= rows[0].length():
		return true
	return rows[y][x] == "#"
