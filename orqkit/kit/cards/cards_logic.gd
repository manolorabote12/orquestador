class_name CardsLogic
extends RefCounted
## Reglas del solitario (Golf) sin dibujo: las usan el juego, el analizador y el bot.
## Mesa: columnas de cartas boca arriba; solo se juega la de abajo de cada columna. Monton: la
## carta de arriba. Una carta se puede jugar si es una mas o una menos que la del monton (la K y
## el A se tocan). Mazo: si no hay jugada, se da la vuelta a la siguiente carta sobre el monton.
## Rango: 1 (A) a 13 (K). Mapa: filas de 7 letras de "A23456789TJQK" (de arriba abajo) y una
## ultima fila "S..." con el mazo (la primera carta del mazo empieza en el monton).

const RANKS: String = "A23456789TJQK"


static func rank_of(ch: String) -> int:
	return RANKS.find(ch) + 1


static func rank_char(r: int) -> String:
	return RANKS[clampi(r, 1, 13) - 1]


static func adjacent(a: int, b: int) -> bool:
	var d: int = absi(a - b)
	return d == 1 or d == 12


## {"cols": [[rangos de arriba abajo]...], "stock": [rangos]} o {} si el mapa esta mal.
static func parse(map: Array) -> Dictionary:
	var cols: Array = []
	var stock: Array[int] = []
	var width: int = -1
	var table_rows: Array[String] = []
	for r: Variant in map:
		var s: String = str(r)
		if s.begins_with("S"):
			for i: int in range(1, s.length()):
				var k: int = rank_of(s[i])
				if k <= 0:
					return {}
				stock.append(k)
		else:
			table_rows.append(s)
	for s: String in table_rows:
		if width < 0:
			width = s.length()
		if s.length() != width:
			return {}
	if width <= 0 or stock.is_empty():
		return {}
	for x: int in width:
		var col: Array[int] = []
		for s: String in table_rows:
			if s[x] != ".":
				var k: int = rank_of(s[x])
				if k <= 0:
					return {}
				col.append(k)
		cols.append(col)
	return {"cols": cols, "stock": stock}


## Busca una solucion: lista de jugadas (indice de columna, o -1 = dar la vuelta al mazo).
## Vacio si no hay (o si se pasa del limite de nodos).
static func solve(cols: Array, stock: Array, max_nodes: int = 60000) -> Array:
	var heights: Array[int] = []
	for c: Variant in cols:
		heights.append((c as Array).size())
	var seen: Dictionary = {}
	var path: Array = []
	var nodes: Array[int] = [0]
	if _dfs(cols, stock, heights, 1, int(stock[0]), seen, path, nodes, max_nodes):
		return path
	return []


static func _dfs(cols: Array, stock: Array, heights: Array[int], next_stock: int, top: int, seen: Dictionary,
		path: Array, nodes: Array[int], max_nodes: int) -> bool:
	var left: int = 0
	for h: int in heights:
		left += h
	if left == 0:
		return true
	nodes[0] += 1
	if nodes[0] > max_nodes:
		return false
	var key: String = "%s|%d|%d" % [str(heights), next_stock, top]
	if seen.has(key):
		return false
	seen[key] = true
	## Primero las columnas mas altas (deja la mesa pareja: suele resolver antes).
	var order: Array[int] = []
	for i: int in heights.size():
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool: return heights[a] > heights[b])
	for i: int in order:
		if heights[i] == 0:
			continue
		var card: int = int((cols[i] as Array)[heights[i] - 1])
		if adjacent(card, top):
			heights[i] -= 1
			path.append(i)
			if _dfs(cols, stock, heights, next_stock, card, seen, path, nodes, max_nodes):
				return true
			path.pop_back()
			heights[i] += 1
	if next_stock < stock.size():
		path.append(-1)
		if _dfs(cols, stock, heights, next_stock + 1, int(stock[next_stock]), seen, path, nodes, max_nodes):
			return true
		path.pop_back()
	return false
