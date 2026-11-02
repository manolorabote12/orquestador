extends RefCounted
## Analizador del solitario: comprueba SIN jugar que el reparto es justo.
## 1 - Mesa de 5 a 8 columnas, de 2 a 6 cartas cada una, letras validas, y un mazo "S..." de
##     8 cartas o mas.
## 2 - Tiene solucion (lo comprueba el mismo buscador que usa el bot).
## 3 - No es un paseo: sin mirar nada, jugando siempre la primera carta posible y tirando del
##     mazo si no hay, no se limpia la mesa (asi hay que pensar un poco).


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var deal: Dictionary = CardsLogic.parse(level.get("map", []))
	if deal.is_empty():
		return {"completable": false, "issues": ["cards_bad_map"], "coins_total": 3, "enemies": 0, "enemy_problems": []}
	var cols: Array = deal["cols"]
	var stock: Array = deal["stock"]
	if cols.size() < 5 or cols.size() > 8:
		issues.append("cards_columns")
	for c: Variant in cols:
		if (c as Array).size() < 2 or (c as Array).size() > 6:
			if not issues.has("cards_column_size"):
				issues.append("cards_column_size")
	if stock.size() < 8:
		issues.append("cards_stock_small")
	if issues.is_empty():
		if CardsLogic.solve(cols, stock).is_empty():
			issues.append("cards_unsolvable")
		elif _greedy_wins(cols, stock):
			issues.append("cards_too_easy")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": 3, "enemies": 0, "enemy_problems": []}


static func _greedy_wins(cols: Array, stock: Array) -> bool:
	var heights: Array[int] = []
	for c: Variant in cols:
		heights.append((c as Array).size())
	var top: int = int(stock[0])
	var nxt: int = 1
	while true:
		var moved: bool = false
		for i: int in heights.size():
			if heights[i] > 0 and CardsLogic.adjacent(int((cols[i] as Array)[heights[i] - 1]), top):
				heights[i] -= 1
				top = int((cols[i] as Array)[heights[i]])
				moved = true
				break
		if moved:
			continue
		if nxt >= stock.size():
			break
		top = int(stock[nxt])
		nxt += 1
	var left: int = 0
	for h: int in heights:
		left += h
	return left == 0
