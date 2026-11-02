class_name LevelAnalyzer
extends RefCounted
## Analizador de niveles: decide SIN JUGAR si un nivel se puede completar con la fisica real
## del jugador. Es la primera herramienta de QA de la fabrica: un nivel imposible no sale.
##
## Como funciona:
## 1 - Simula el salto real (misma gravedad, salto variable, apex) y la caida desde un borde.
## 2 - Marca las casillas donde el jugador puede estar de pie.
## 3 - Une dos casillas si el arco permite llegar sin chocar con bloques ni caer en pinchos.
## 4 - Busca un camino desde la salida hasta la meta y comprueba que las monedas se alcanzan.
## 12 - Enemigos: los que andan deben tener suelo, ninguno puede estar encima de la salida
## y por toda su ruta de patrulla tiene que haber hueco para saltar por encima.
## 13 - Runner (auto_run): no hay vuelta atras ni espera. Sin muros de 3 o mas bloques,
## sin plataformas moviles ni jefe (no se puede esperar ni pelear parado).
## 14 - Volador (flap): otra cuenta. Cada columna con bloques (tuberia) deja un hueco; el hueco
## debe medir 4 casillas o mas y no puede saltar de altura mas de lo que se sube o baja volando.
## Limitacion conocida: es una aproximacion por casillas (prudente). Las pruebas con bots
## completan la verificacion con la fisica real.

const DT: float = 1.0 / 60.0


static func analyze(map: Array, tile: float, params: Dictionary) -> Dictionary:
	var p: Dictionary = PlayerPlatformer.DEFAULTS.duplicate()
	for key: String in params.keys():
		if p.has(key):
			p[key] = float(params[key])
	if float(p.get("flap", 0.0)) > 0.5:
		return flap_analyze(static_rows(LevelBuilder.normalize(map)))
	var rows: Array[String] = static_rows(LevelBuilder.normalize(map))
	var h: int = rows.size()
	var w: int = rows[0].length() if h > 0 else 0
	var issues: Array[String] = []

	var jump_arc: Array[Vector2] = simulate_arc(p, true, (h + 4) * tile)
	var walk_arc: Array[Vector2] = simulate_arc(p, false, (h + 4) * tile)
	var apex_px: float = 0.0
	for pt: Vector2 in jump_arc:
		apex_px = maxf(apex_px, -pt.y)
	var max_up_tiles: int = int(floor(apex_px / tile))

	var spawn: Vector2i = _find(rows, LevelBuilder.PLAYER)
	var goal: Vector2i = _find(rows, LevelBuilder.GOAL)
	if spawn.x < 0:
		issues.append("no_spawn")
	if goal.x < 0:
		issues.append("no_goal")
	if not issues.is_empty():
		return {"completable": false, "issues": issues, "max_up_tiles": max_up_tiles}

	## 5 - La salida puede estar en el aire: el jugador cae hasta el primer suelo.
	var start: Vector2i = _drop(rows, spawn)
	if start.y < 0:
		issues.append("spawn_falls_out")
		return {"completable": false, "issues": issues, "max_up_tiles": max_up_tiles}

	var visited: Dictionary = {start: true}
	var queue: Array[Vector2i] = [start]
	var max_dx: int = int(ceil(_max_x(jump_arc) / tile)) + 1
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for ty: int in h:
			for tx: int in range(maxi(cur.x - max_dx, 0), mini(cur.x + max_dx + 1, w)):
				var target: Vector2i = Vector2i(tx, ty)
				if visited.has(target) or not is_standing(rows, tx, ty):
					continue
				## 11 - Andar a la casilla de al lado por el mismo suelo.
				if ty == cur.y and absi(tx - cur.x) == 1:
					visited[target] = true
					queue.append(target)
					continue
				if _reachable(rows, cur, target, tile, p, jump_arc) or _reachable(rows, cur, target, tile, p, walk_arc):
					visited[target] = true
					queue.append(target)

	var goal_stand: Vector2i = _drop(rows, goal)
	var completable: bool = goal_stand.y >= 0 and visited.has(goal_stand)
	if not completable:
		issues.append("goal_unreachable")

	var enemy_report: Dictionary = check_enemies(rows, spawn)
	for issue: String in enemy_report["issues"]:
		if not issues.has(issue):
			issues.append(issue)

	if float(p.get("auto_run", 0.0)) > 0.5:
		for issue: String in runner_issues(LevelBuilder.normalize(map)):
			if not issues.has(issue):
				issues.append(issue)

	var missing_coins: Array[Vector2i] = []
	var total_coins: int = 0
	for y: int in h:
		for x: int in w:
			if rows[y][x] != LevelBuilder.COIN:
				continue
			total_coins += 1
			if not _coin_reachable(rows, Vector2i(x, y), visited, max_up_tiles) and not _coin_by_arc(rows, Vector2i(x, y), visited, tile, p, jump_arc):
				missing_coins.append(Vector2i(x, y))
	if not missing_coins.is_empty():
		issues.append("coins_unreachable")

	return {
		"completable": completable,
		"issues": issues,
		"reachable_cells": visited.size(),
		"max_up_tiles": max_up_tiles,
		"apex_px": snappedf(apex_px, 0.1),
		"coins_total": total_coins,
		"coins_unreachable": missing_coins,
		"enemies": enemy_report["count"],
		"enemy_problems": enemy_report["detail"],
	}


static func check_enemies(rows: Array[String], spawn: Vector2i) -> Dictionary:
	var issues: Array[String] = []
	var detail: Array[String] = []
	var count: int = 0
	for y: int in rows.size():
		for x: int in rows[y].length():
			var ch: String = rows[y][x]
			if not Enemy.KINDS.has(ch):
				continue
			count += 1
			var kind: String = str(Enemy.KINDS[ch])
			if absi(x - spawn.x) <= 3 and absi(y - spawn.y) <= 2:
				issues.append("enemy_near_spawn")
				detail.append("%s junto a la salida en %d,%d" % [kind, x, y])
			if kind == "flyer":
				continue
			if not is_solid(rows, x, y + 1):
				issues.append("enemy_floating")
				detail.append("%s sin suelo en %d,%d" % [kind, x, y])
				continue
			## 13 - Ruta de patrulla: hasta pared, pinchos o borde. Necesita 2 casillas libres encima.
			var x0: int = x
			while x0 - 1 >= 0 and _walkable(rows, x0 - 1, y):
				x0 -= 1
			var x1: int = x
			while x1 + 1 < rows[y].length() and _walkable(rows, x1 + 1, y):
				x1 += 1
			## El jefe necesita una arena amplia y alta para que se pueda saltar sobre el.
			var alto: int = 4 if kind == "boss" else 2
			if kind == "boss" and x1 - x0 < 9:
				issues.append("boss_arena_small")
				detail.append("arena del jefe de %d casillas (minimo 10)" % (x1 - x0 + 1))
			for px: int in range(x0, x1 + 1):
				var bloqueado: bool = false
				for dy: int in range(1, alto + 1):
					if is_solid(rows, px, y - dy):
						bloqueado = true
				if bloqueado:
					issues.append("enemy_unavoidable")
					detail.append("%s sin hueco para saltarlo en %d,%d" % [kind, px, y])
					break
	return {"count": count, "issues": issues, "detail": detail}


## 14 - Las plataformas moviles cuentan como suelo en su posicion central (aproximacion
## prudente: su recorrido se mantiene dentro del hueco). Los bots comprueban el resto.
static func flap_analyze(rows: Array[String]) -> Dictionary:
	var issues: Array[String] = []
	var h: int = rows.size()
	var w: int = rows[0].length() if h > 0 else 0
	var spawn: Vector2i = _find(rows, LevelBuilder.PLAYER)
	var goal: Vector2i = _find(rows, LevelBuilder.GOAL)
	if spawn.x < 0:
		issues.append("no_spawn")
	if goal.x < 0:
		issues.append("no_goal")
	if not issues.is_empty():
		return {"completable": false, "issues": issues, "max_up_tiles": 0}
	var last_center: float = float(spawn.y)
	var last_x: int = spawn.x
	var min_gap: int = 99
	var coins: int = 0
	var problems: Array[String] = []
	for x: int in range(1, w - 1):
		var best_top: int = -1
		var best_len: int = 0
		var cur_top: int = -1
		var cur: int = 0
		var pipe: bool = false
		for y: int in h:
			if rows[y][x] == LevelBuilder.COIN:
				coins += 1
			if is_solid(rows, x, y):
				cur = 0
				if y >= 1 and y <= h - 3:
					pipe = true
				continue
			if cur == 0:
				cur_top = y
			cur += 1
			if cur > best_len:
				best_len = cur
				best_top = cur_top
		if not pipe:
			continue
		min_gap = mini(min_gap, best_len)
		var center: float = float(best_top) + float(best_len) * 0.5
		var dx: float = float(x - last_x)
		var climb: float = last_center - center
		## 1 - Subir cuesta mas que bajar: margen prudente por columna recorrida.
		if climb > 0.45 * dx + 1.0 or -climb > 0.9 * dx + 1.5:
			if not issues.has("flap_gap_jump"):
				issues.append("flap_gap_jump")
			problems.append("salto de hueco en columna %d" % x)
		last_center = center
		last_x = x
	if min_gap < 4:
		issues.append("flap_gap_small")
	return {
		"completable": issues.is_empty(), "issues": issues, "max_up_tiles": 0, "coins_total": coins,
		"coins_unreachable": [], "enemies": 0, "enemy_problems": problems,
	}


static func runner_issues(raw: Array[String]) -> Array[String]:
	var out: Array[String] = []
	var joined: String = "".join(raw)
	if joined.contains(LevelBuilder.MOVING):
		out.append("runner_moving_platform")
	if joined.contains("B"):
		out.append("runner_boss")
	var rows: Array[String] = static_rows(raw)
	for y: int in range(2, rows.size()):
		for x: int in range(1, rows[0].length()):
			## El muro del borde del mundo (columna llena hasta arriba) no cuenta.
			if is_solid(rows, x, 0):
				continue
			if is_solid(rows, x, y) and is_solid(rows, x, y - 1) and is_solid(rows, x, y - 2) \
					and not is_solid(rows, x - 1, y) and is_solid(rows, x - 1, y + 1):
				if not out.has("runner_wall"):
					out.append("runner_wall")
	return out


static func static_rows(rows: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for r: String in rows:
		out.append(r.replace(LevelBuilder.MOVING, LevelBuilder.SOLID))
	return out


static func _walkable(rows: Array[String], x: int, y: int) -> bool:
	return not is_solid(rows, x, y) and rows[y][x] != LevelBuilder.SPIKE and is_solid(rows, x, y + 1)


## 6 - Trayectoria del pie del jugador corriendo a tope (x >= 0, y hacia arriba negativo).
static func simulate_arc(p: Dictionary, jump: bool, max_drop: float) -> Array[Vector2]:
	var t_apex: float = maxf(float(p["time_to_apex"]), 0.05)
	var g_up: float = 2.0 * float(p["jump_height"]) / (t_apex * t_apex)
	var vy: float = -2.0 * float(p["jump_height"]) / t_apex if jump else 0.0
	var vx: float = float(p["run_speed"])
	var pos: Vector2 = Vector2.ZERO
	var arc: Array[Vector2] = [pos]
	var guard: int = 0
	while pos.y < max_drop and guard < 2000:
		guard += 1
		var g: float = g_up
		if vy > 0.0:
			g = g_up * float(p["fall_gravity_mult"])
		elif jump and absf(vy) < float(p["apex_threshold"]):
			g = g_up * float(p["apex_gravity_mult"])
		vy = minf(vy + g * DT, float(p["max_fall_speed"]))
		pos += Vector2(vx, vy) * DT
		arc.append(pos)
	return arc


static func is_solid(rows: Array[String], x: int, y: int) -> bool:
	if x < 0 or x >= rows[0].length():
		return true
	if y < 0 or y >= rows.size():
		return false
	return rows[y][x] == LevelBuilder.SOLID


static func is_standing(rows: Array[String], x: int, y: int) -> bool:
	if y < 0 or y >= rows.size():
		return false
	if is_solid(rows, x, y) or rows[y][x] == LevelBuilder.SPIKE:
		return false
	return is_solid(rows, x, y + 1)


static func _reachable(rows: Array[String], from: Vector2i, to: Vector2i, tile: float, p: Dictionary, arc: Array[Vector2]) -> bool:
	var dir: float = signf(float(to.x - from.x))
	var start_px: Vector2 = Vector2((from.x + 0.5) * tile, (from.y + 1.0) * tile)
	var target_feet_y: float = (to.y + 1.0) * tile
	var dist: float = absf(float(to.x - from.x)) * tile
	## 7 - Margen: el jugador puede aterrizar con medio cuerpo sobre el bloque.
	var slack: float = tile * 0.5 + float(p["width"]) * 0.5 - 6.0
	var need: float = maxf(dist - slack, 0.0)
	var half_w: float = float(p["width"]) * 0.5 - 2.0
	var body_h: float = float(p["height"])
	## 8 - Momento en que el arco baja hasta la altura del destino.
	var cross: int = -1
	for i: int in range(1, arc.size()):
		var a: float = start_px.y + arc[i - 1].y
		var b: float = start_px.y + arc[i].y
		if arc[i].y > arc[i - 1].y and a <= target_feet_y and b >= target_feet_y:
			cross = i
			break
	if cross < 0 or arc[cross].x < need:
		return false
	## 9 - Dos formas de saltar, como un jugador real: avanzar desde el principio
	## o subir primero y avanzar despues (para esquivar techos y bordes).
	for late: bool in [false, true]:
		if _path_clear(rows, arc, cross, start_px, dir, need, late, half_w, body_h, tile, target_feet_y):
			return true
	return false


static func _path_clear(rows: Array[String], arc: Array[Vector2], cross: int, start_px: Vector2, dir: float, need: float, late: bool, half_w: float, body_h: float, tile: float, target_feet_y: float) -> bool:
	var x_cross: float = arc[cross].x
	for i: int in range(1, cross + 1):
		var pt: Vector2 = arc[i]
		var x_px: float = minf(pt.x, need + 1.0)
		if late:
			x_px = clampf(pt.x - (x_cross - need), 0.0, need + 1.0)
		var fy: float = start_px.y + pt.y
		if i == cross:
			fy = target_feet_y
		if _body_hits(rows, Vector2(start_px.x + dir * x_px, fy), half_w, body_h, tile):
			return false
	return true


static func _body_hits(rows: Array[String], feet: Vector2, half_w: float, body_h: float, tile: float) -> bool:
	var probes: Array[Vector2] = [
		feet + Vector2(-half_w, -4.0), feet + Vector2(half_w, -4.0),
		feet + Vector2(-half_w, -body_h + 4.0), feet + Vector2(half_w, -body_h + 4.0),
		feet + Vector2(0.0, -body_h * 0.5),
	]
	for probe: Vector2 in probes:
		var cx: int = int(floor(probe.x / tile))
		var cy: int = int(floor(probe.y / tile))
		if is_solid(rows, cx, cy):
			return true
		## 10 - Los pinchos solo hacen dano en su parte baja, igual que en el juego.
		if cy >= 0 and cy < rows.size() and cx >= 0 and cx < rows[0].length() and rows[cy][cx] == LevelBuilder.SPIKE:
			if probe.y > cy * tile + tile * 0.55:
				return true
	return false


static func _coin_reachable(rows: Array[String], coin: Vector2i, visited: Dictionary, max_up: int) -> bool:
	for dx: int in range(-1, 2):
		for dy: int in range(0, max_up + 1):
			var stand: Vector2i = Vector2i(coin.x + dx, coin.y + dy)
			if not visited.has(stand):
				continue
			var clear: bool = true
			for k: int in range(coin.y, stand.y):
				if is_solid(rows, coin.x, k):
					clear = false
					break
			if clear:
				return true
	return false


## 12 - Moneda en el aire (por ejemplo encima de pinchos): se coge en mitad de un salto.
static func _coin_by_arc(rows: Array[String], coin: Vector2i, visited: Dictionary, tile: float, p: Dictionary, arc: Array[Vector2]) -> bool:
	var coin_px: Vector2 = Vector2((coin.x + 0.5) * tile, (coin.y + 0.5) * tile)
	var half_w: float = float(p["width"]) * 0.5 - 2.0
	var body_h: float = float(p["height"])
	var reach: float = tile * 0.28 + half_w
	for key: Variant in visited.keys():
		var cell: Vector2i = key
		if absi(cell.x - coin.x) > 7 or cell.y < coin.y:
			continue
		var start_px: Vector2 = Vector2((cell.x + 0.5) * tile, (cell.y + 1.0) * tile)
		for dir: float in [-1.0, 1.0]:
			for i: int in range(1, arc.size()):
				var feet: Vector2 = start_px + Vector2(dir * arc[i].x, arc[i].y)
				if _body_hits(rows, feet, half_w, body_h, tile):
					break
				var center: Vector2 = feet - Vector2(0.0, body_h * 0.5)
				if absf(center.x - coin_px.x) <= reach and absf(center.y - coin_px.y) <= body_h * 0.5 + tile * 0.28:
					return true
				if feet.y > start_px.y + tile:
					break
	return false


static func _find(rows: Array[String], ch: String) -> Vector2i:
	for y: int in rows.size():
		var x: int = rows[y].find(ch)
		if x >= 0:
			return Vector2i(x, y)
	return Vector2i(-1, -1)


static func _drop(rows: Array[String], cell: Vector2i) -> Vector2i:
	var y: int = cell.y
	while y < rows.size():
		if is_standing(rows, cell.x, y):
			return Vector2i(cell.x, y)
		if is_solid(rows, cell.x, y):
			return Vector2i(-1, -1)
		y += 1
	return Vector2i(-1, -1)


static func _max_x(arc: Array[Vector2]) -> float:
	var m: float = 0.0
	for pt: Vector2 in arc:
		m = maxf(m, pt.x)
	return m
