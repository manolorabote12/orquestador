extends RefCounted
## Analizador de saltos: comprueba SIN jugar que se puede subir hasta la meta.
## 1 - 9 columnas, una salida P (abajo) y una meta G (arriba).
## 2 - Hay un camino de plataformas desde P hasta G: cada salto sube 3 filas como mucho (8 desde un
##     muelle) y se mueve 3 columnas como mucho (los lados se tocan; las moviles valen en cualquier
##     columna). Las que se rompen valen una vez, que es lo que hace falta para subir.

const COLS: int = 9
const MAX_UP: int = 3
const SPRING_UP: int = 8
const MAX_SIDE: int = 3


static func analyze(level: Dictionary) -> Dictionary:
	var rows: Array[String] = []
	for r: Variant in level.get("map", []):
		rows.append(str(r))
	var issues: Array[String] = []
	var plats: Array[Dictionary] = []
	var start: int = -1
	var goal: int = -1
	var coins: int = 0
	for y: int in rows.size():
		if rows[y].length() != COLS and not issues.has("jumper_width"):
			issues.append("jumper_width")
		for x: int in rows[y].length():
			var ch: String = rows[y][x]
			if ch == "C":
				coins += 1
			if "=~x^PGE".contains(ch):
				## Fila contada desde abajo.
				var p: Dictionary = {"r": rows.size() - 1 - y, "c": x, "k": ch}
				if ch == "P":
					start = plats.size()
				if ch == "G":
					goal = plats.size()
				plats.append(p)
			elif ch != "." and ch != "C" and not issues.has("jumper_bad_char"):
				issues.append("jumper_bad_char")
	if start < 0:
		issues.append("jumper_no_start")
	if goal < 0:
		issues.append("jumper_no_goal")
	if issues.is_empty() and not reachable(plats, start, goal):
		issues.append("jumper_unreachable")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": coins, "enemies": 0, "enemy_problems": []}


static func reachable(plats: Array[Dictionary], start: int, goal: int) -> bool:
	var seen: Dictionary = {start: true}
	var queue: Array[int] = [start]
	while not queue.is_empty():
		var i: int = queue.pop_front()
		if i == goal:
			return true
		var a: Dictionary = plats[i]
		var up_max: int = SPRING_UP if a["k"] == "^" else MAX_UP
		for j: int in plats.size():
			if seen.has(j):
				continue
			var b: Dictionary = plats[j]
			var up: int = int(b["r"]) - int(a["r"])
			if up < 1 or up > up_max:
				continue
			var dc: int = absi(int(b["c"]) - int(a["c"]))
			dc = mini(dc, COLS - dc)
			if b["k"] == "G" or b["k"] == "~" or a["k"] == "~" or dc <= MAX_SIDE:
				seen[j] = true
				queue.append(j)
	return false
