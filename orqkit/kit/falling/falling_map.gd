extends RefCounted
## Bloques que caen (estilo clasico de piezas de 4): reglas, bolsa de piezas con semilla, bot y
## analizador.
## 1 - Mapa (game.json -> levels[i].map): las filas de abajo del pozo de 10 de ancho con basura
##     ya puesta ("#" bloque, "." hueco). Puede ir vacio (["."*10]).
## 2 - Las piezas caen; se mueven a los lados, giran y bajan de golpe. Una fila llena se borra.
##     Si una pieza nueva no cabe arriba, se pierde.
## 3 - Se gana al borrar "lines" filas. Parametros: "speed" (filas por segundo) y "seed".

const Rules = preload("res://kit/rules.gd")
const W: int = 10
const H: int = 20
const SHAPES: Dictionary = {
	"I": [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)],
	"O": [Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(2, 1)],
	"T": [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
	"S": [Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1)],
	"Z": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)],
	"J": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
	"L": [Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
}
const ORDER: Array[String] = ["I", "O", "T", "S", "Z", "J", "L"]


static func new_state(level: Dictionary) -> Dictionary:
	var grid: Array = []
	for y: int in H:
		var row: Array = []
		row.resize(W)
		row.fill("")
		grid.append(row)
	var rows: Array = level.get("map", [])
	var start: int = H - rows.size()
	for k: int in rows.size():
		var s: String = str(rows[k])
		for x: int in mini(W, s.length()):
			if s[x] == "#" and start + k >= 0:
				grid[start + k][x] = "G"
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(level.get("seed", 1))
	var st: Dictionary = {"grid": grid, "rng": rng, "bag": [], "lines": 0, "goal": int(level.get("lines", 10)), "speed": float(level.get("speed", 1.5)),
		"fall": 0.0, "piece": {}, "next": "", "over": false, "won": false, "pieces": 0, "score": 0}
	st["next"] = _draw(st)
	spawn(st)
	st["rules"] = Rules.load_rules(level)
	Rules.hook(st, "on_start")
	return st


static func _draw(st: Dictionary) -> String:
	var bag: Array = st["bag"]
	if bag.is_empty():
		bag.append_array(ORDER)
		var rng: RandomNumberGenerator = st["rng"]
		for i: int in range(bag.size() - 1, 0, -1):
			var j: int = rng.randi_range(0, i)
			var t: Variant = bag[i]
			bag[i] = bag[j]
			bag[j] = t
	return str(bag.pop_back())


## Celdas de la pieza k girada r veces (giro sobre una caja de 4x4; la O no gira).
static func cells(kind: String, rot: int) -> Array:
	var out: Array = []
	var size: int = 4 if kind == "I" else (4 if kind == "O" else 3)
	for c: Vector2i in SHAPES[kind]:
		var p: Vector2i = c
		if kind != "O":
			for k: int in posmod(rot, 4):
				p = Vector2i(size - 1 - p.y, p.x)
		out.append(p)
	return out


static func fits(st: Dictionary, kind: String, rot: int, pos: Vector2i) -> bool:
	for c: Vector2i in cells(kind, rot):
		var p: Vector2i = pos + c
		if p.x < 0 or p.x >= W or p.y >= H:
			return false
		if p.y >= 0 and str(st["grid"][p.y][p.x]) != "":
			return false
	return true


## Vacia las n filas ocupadas mas altas (segunda oportunidad).
static func clear_top(st: Dictionary, n: int) -> void:
	var grid: Array = st["grid"]
	var cleared: int = 0
	for y: int in H:
		if cleared >= n:
			break
		var row: Array = grid[y]
		if row.any(func(c: Variant) -> bool: return str(c) != ""):
			row.fill("")
			cleared += 1


static func spawn(st: Dictionary) -> void:
	var kind: String = st["next"]
	st["next"] = _draw(st)
	st["piece"] = {"kind": kind, "rot": 0, "pos": Vector2i(3, -1)}
	st["pieces"] = int(st["pieces"]) + 1
	if not fits(st, kind, 0, Vector2i(3, -1)):
		st["over"] = true


static func try_move(st: Dictionary, dx: int, drot: int) -> bool:
	var p: Dictionary = st["piece"]
	if p.is_empty():
		return false
	var nrot: int = int(p["rot"]) + drot
	for kick: int in ([0] if drot == 0 else [0, -1, 1, -2, 2]):
		var np: Vector2i = (p["pos"] as Vector2i) + Vector2i(dx + kick, 0)
		if fits(st, p["kind"], nrot, np):
			p["pos"] = np
			p["rot"] = nrot
			return true
	return false


## Fija la pieza, borra filas y saca la siguiente. Devuelve las filas borradas.
static func lock(st: Dictionary) -> int:
	var p: Dictionary = st["piece"]
	var placed: Array = []
	for c: Vector2i in cells(p["kind"], int(p["rot"])):
		var q: Vector2i = (p["pos"] as Vector2i) + c
		if q.y < 0:
			st["over"] = true
			return 0
		st["grid"][q.y][q.x] = p["kind"]
		placed.append(q)
	Rules.hook(st, "on_lock", [placed])
	var cleared: int = clear_full(st)
	if int(st["lines"]) >= int(st["goal"]):
		st["won"] = true
		st["piece"] = {}
		return cleared
	spawn(st)
	return cleared


## Borra las filas llenas, suma filas y puntos, y avisa a las reglas. Devuelve cuantas.
static func clear_full(st: Dictionary) -> int:
	var grid: Array = st["grid"]
	var cleared: int = 0
	var y: int = H - 1
	while y >= 0:
		var full: bool = true
		for x: int in W:
			if str(grid[y][x]) == "":
				full = false
				break
		if full:
			grid.remove_at(y)
			var row: Array = []
			row.resize(W)
			row.fill("")
			grid.insert(0, row)
			cleared += 1
		else:
			y -= 1
	st["lines"] = int(st["lines"]) + cleared
	st["score"] = int(st["score"]) + [0, 100, 300, 500, 800][mini(cleared, 4)]
	if cleared > 0:
		Rules.hook(st, "on_clear", [cleared])
	return cleared


static func hard_drop(st: Dictionary) -> int:
	var p: Dictionary = st["piece"]
	if p.is_empty():
		return 0
	while fits(st, p["kind"], int(p["rot"]), (p["pos"] as Vector2i) + Vector2i(0, 1)):
		p["pos"] = (p["pos"] as Vector2i) + Vector2i(0, 1)
	return lock(st)


## Gravedad: baja una fila cada 1/speed segundos; si no puede, se fija.
static func step(st: Dictionary, dt: float) -> int:
	if st["over"] or st["won"] or (st["piece"] as Dictionary).is_empty():
		return 0
	st["fall"] = float(st["fall"]) + dt * float(st["speed"])
	var cleared: int = 0
	if not (st.get("rules", []) as Array).is_empty():
		## Las reglas ven donde esta la pieza que cae (para no meterse en ella).
		var busy: Array = []
		var pc: Dictionary = st["piece"]
		for c: Vector2i in cells(pc["kind"], int(pc["rot"])):
			busy.append((pc["pos"] as Vector2i) + c)
		st["busy"] = busy
		Rules.hook(st, "on_step", [dt])
		cleared += clear_full(st)
		if int(st["lines"]) >= int(st["goal"]):
			st["won"] = true
			st["piece"] = {}
			return cleared
	while float(st["fall"]) >= 1.0 and not st["over"] and not st["won"]:
		st["fall"] = float(st["fall"]) - 1.0
		var p: Dictionary = st["piece"]
		if fits(st, p["kind"], int(p["rot"]), (p["pos"] as Vector2i) + Vector2i(0, 1)):
			p["pos"] = (p["pos"] as Vector2i) + Vector2i(0, 1)
		else:
			cleared += lock(st)
	return cleared


# ------------------------------------------------------------------ bot

## Nota de un tablero (heuristica clasica): filas borradas buenas; altura, agujeros y desnivel malos.
static func _rate(grid: Array, cleared: int) -> float:
	var heights: Array = []
	var holes: int = 0
	for x: int in W:
		var h: int = 0
		var seen: bool = false
		for y: int in H:
			if str(grid[y][x]) != "":
				if not seen:
					h = H - y
					seen = true
			elif seen:
				holes += 1
		heights.append(h)
	var agg: int = 0
	var bump: int = 0
	for x2: int in W:
		agg += int(heights[x2])
		if x2 > 0:
			bump += absi(int(heights[x2]) - int(heights[x2 - 1]))
	return -0.51 * float(agg) + 0.76 * float(cleared) - 0.36 * float(holes) - 0.18 * float(bump)


## Mejor sitio para la pieza actual: [giro, columna].
static func best_place(st: Dictionary) -> Array:
	var p: Dictionary = st["piece"]
	var best: Array = [0, 3]
	var best_v: float = -INF
	for rot: int in (1 if p["kind"] == "O" else 4):
		for x: int in range(-2, W):
			var pos: Vector2i = Vector2i(x, -1)
			if not fits(st, p["kind"], rot, pos):
				continue
			while fits(st, p["kind"], rot, pos + Vector2i(0, 1)):
				pos += Vector2i(0, 1)
			var g: Array = []
			for row: Array in st["grid"]:
				g.append(row.duplicate())
			var ok: bool = true
			for c: Vector2i in cells(p["kind"], rot):
				var q: Vector2i = pos + c
				if q.y < 0:
					ok = false
					break
				g[q.y][q.x] = "X"
			if not ok:
				continue
			var cleared: int = 0
			var y: int = H - 1
			while y >= 0:
				if not g[y].has(""):
					g.remove_at(y)
					var row2: Array = []
					row2.resize(W)
					row2.fill("")
					g.insert(0, row2)
					cleared += 1
				else:
					y -= 1
			var v: float = _rate(g, cleared)
			if v > best_v:
				best_v = v
				best = [rot, x]
	return best


## Un paso del bot hacia su sitio: girar, mover o soltar. Devuelve que hizo.
static func bot_act(st: Dictionary, target: Array) -> String:
	var p: Dictionary = st["piece"]
	if p.is_empty():
		return ""
	if posmod(int(p["rot"]), 4) != posmod(int(target[0]), 4):
		if try_move(st, 0, 1):
			return "rot"
	var x: int = (p["pos"] as Vector2i).x
	if x < int(target[1]) and try_move(st, 1, 0):
		return "move"
	if x > int(target[1]) and try_move(st, -1, 0):
		return "move"
	hard_drop(st)
	return "drop"


static func bot_play(level: Dictionary) -> Dictionary:
	var st: Dictionary = new_state(level)
	var dt: float = 1.0 / 30.0
	var cd: float = 0.0
	var target: Array = []
	var last: int = -1
	var guard: int = 0
	while not st["over"] and not st["won"] and guard < 30 * 900:
		guard += 1
		if int(st["pieces"]) != last:
			last = int(st["pieces"])
			target = best_place(st)
		cd -= dt
		if cd <= 0.0:
			## Una persona: un toque cada 0,12 s.
			bot_act(st, target)
			cd = 0.12
		step(st, dt)
	return {"won": bool(st["won"]), "lines": int(st["lines"]), "time": float(guard) * dt}


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var rows: Array = level.get("map", [])
	if rows.size() > 12:
		issues.append("falling_too_high")
	var full_row: bool = false
	for r: Variant in rows:
		if str(r).length() != W:
			issues.append("falling_width")
			break
		if not str(r).contains("."):
			full_row = true
	if full_row:
		issues.append("falling_full_row")
	var par: int = 0
	if issues.is_empty():
		var r2: Dictionary = bot_play(level)
		if not bool(r2["won"]):
			issues.append("falling_too_hard")
		par = int(r2["time"])
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": int(level.get("lines", 10)), "enemies": 0,
		"enemy_problems": [], "par": par}
