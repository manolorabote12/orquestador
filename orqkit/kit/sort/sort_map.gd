extends RefCounted
## Puzle de tubos (ordenar colores): las reglas, el solucionador y el analizador. El juego, el bot
## y la fabrica (niveles/generador.py, funciones *_tubos) usan exactamente las mismas reglas.
## Mapa (game.json -> levels[i].map): un texto por tubo, de abajo arriba; cada letra (a..i) es una
## porcion de un color y "." es un tubo vacio. Parametros: "cap" (porciones por tubo, 4 por
## defecto) y "par" (movimientos de la mejor solucion, para las estrellas).
## Reglas:
## 1 - Se vierte del tubo A al B si A tiene algo, B tiene sitio y B esta vacio o arriba tiene el
##     mismo color que arriba de A. Pasa todo el bloque de ese color que quepa.
## 2 - Se gana cuando cada tubo esta vacio o lleno de un solo color.
## Analizador:
## 3 - Entre 3 y 14 tubos, cap de 2 a 6, cada color exactamente cap porciones, como mucho 9 colores.
## 4 - Tiene solucion (busqueda en anchura con el minimo de movimientos) y no empieza resuelto.

const MAX_STATES: int = 60000
const COLORS: String = "abcdefghi"


static func parse(level: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for r: Variant in level.get("map", []):
		out.append(str(r).replace(".", ""))
	return out


static func cap_of(level: Dictionary) -> int:
	return clampi(int(level.get("cap", 4)), 2, 6)


## Cuantas porciones seguidas del mismo color hay arriba del tubo.
static func top_run(t: String) -> int:
	if t.is_empty():
		return 0
	var c: String = t[t.length() - 1]
	var n: int = 0
	for i: int in range(t.length() - 1, -1, -1):
		if t[i] != c:
			break
		n += 1
	return n


static func can_pour(tubes: Array[String], a: int, b: int, cap: int) -> bool:
	if a == b or a < 0 or b < 0 or a >= tubes.size() or b >= tubes.size():
		return false
	var ta: String = tubes[a]
	var tb: String = tubes[b]
	if ta.is_empty() or tb.length() >= cap:
		return false
	return tb.is_empty() or tb[tb.length() - 1] == ta[ta.length() - 1]


## Resultado de verter (copia nueva). Si no se puede, devuelve los mismos tubos.
static func pour(tubes: Array[String], a: int, b: int, cap: int) -> Array[String]:
	var out: Array[String] = tubes.duplicate()
	if not can_pour(tubes, a, b, cap):
		return out
	var k: int = mini(top_run(tubes[a]), cap - tubes[b].length())
	var c: String = tubes[a][tubes[a].length() - 1]
	out[a] = tubes[a].substr(0, tubes[a].length() - k)
	out[b] = tubes[b] + c.repeat(k)
	return out


static func solved(tubes: Array[String], cap: int) -> bool:
	for t: String in tubes:
		if t.is_empty():
			continue
		if t.length() != cap or top_run(t) != cap:
			return false
	return true


## Movimiento que no sirve de nada: pasar un tubo de un solo color entero a uno vacio.
static func _useless(tubes: Array[String], a: int, b: int) -> bool:
	return tubes[b].is_empty() and top_run(tubes[a]) == tubes[a].length()


static func _key(tubes: Array[String]) -> String:
	var s: Array[String] = tubes.duplicate()
	s.sort()
	return "|".join(s)


## Mejor solucion: lista de [a, b]. Vacia si no hay (o si ya esta resuelto).
static func solve(tubes: Array[String], cap: int) -> Array:
	if solved(tubes, cap):
		return []
	var seen: Dictionary = {_key(tubes): true}
	var frontier: Array = [[tubes, []]]
	while not frontier.is_empty() and seen.size() < MAX_STATES:
		var next: Array = []
		for node: Array in frontier:
			var t: Array[String] = node[0]
			for a: int in t.size():
				for b: int in t.size():
					if not can_pour(t, a, b, cap) or _useless(t, a, b):
						continue
					var nt: Array[String] = pour(t, a, b, cap)
					var k: String = _key(nt)
					if seen.has(k):
						continue
					seen[k] = true
					var path: Array = (node[1] as Array).duplicate()
					path.append([a, b])
					if solved(nt, cap):
						return path
					next.append([nt, path])
		frontier = next
	return []


## Hay algun movimiento util? (si no, el jugador se ha quedado atascado)
static func has_moves(tubes: Array[String], cap: int) -> bool:
	for a: int in tubes.size():
		for b: int in tubes.size():
			if can_pour(tubes, a, b, cap) and not _useless(tubes, a, b):
				return true
	return false


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var tubes: Array[String] = parse(level)
	var cap: int = cap_of(level)
	if tubes.size() < 3 or tubes.size() > 14:
		issues.append("sort_tubes")
	var counts: Dictionary = {}
	for t: String in tubes:
		if t.length() > cap and not issues.has("sort_overfull"):
			issues.append("sort_overfull")
		for ch: String in t:
			if not COLORS.contains(ch):
				if not issues.has("sort_bad_char"):
					issues.append("sort_bad_char")
				continue
			counts[ch] = int(counts.get(ch, 0)) + 1
	for ch: Variant in counts:
		if int(counts[ch]) != cap:
			issues.append("sort_color_count")
			break
	if counts.size() > 9 or counts.is_empty():
		issues.append("sort_colors")
	var moves: int = 0
	if issues.is_empty():
		if solved(tubes, cap):
			issues.append("sort_already_solved")
		else:
			moves = solve(tubes, cap).size()
			if moves == 0:
				issues.append("sort_unsolvable")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": counts.size(), "enemies": 0, "enemy_problems": [],
		"par": moves}
