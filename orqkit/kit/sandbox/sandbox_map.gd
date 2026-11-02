extends RefCounted
## Mundo abierto (sandbox 2D): mundo generado con semilla, picar y poner bloques, fabricar
## herramientas, dia y noche con monstruos. Reglas, fisica, bot y analizador (lo usan el juego, el
## bot y el analizador: todo lo que decide esta aqui).
## 1 - Mapa (game.json -> levels[i].map): los biomas de izquierda a derecha, una letra por trozo de
##     32 columnas: "b" bosque, "l" llanura, "m" montana, "d" desierto. Ej.: ["lbmbd"].
## 2 - Parametros: "seed" (el mundo), "goal_item" y "goal_n" (lo que hay que conseguir en el nivel),
##     "day" y "night" (segundos), "mobs" (monstruos a la vez por la noche, 0-5).
## 3 - El mundo, el inventario y la hora se guardan (save_data / load_into): todos los niveles con
##     el mismo mapa y semilla son el mismo mundo.

const Rules = preload("res://kit/rules.gd")
const TILE: float = 40.0
const H: int = 80
const PW: float = 28.0
const PH: float = 72.0
const MW: float = 30.0
const MH: float = 34.0
const SPEED: float = 230.0
const GRAV: float = 2000.0
const JUMP: float = 640.0
const REACH: float = 4.5
const MAX_HP: int = 10

const AIR: int = 0
const GRASS: int = 1
const DIRT: int = 2
const STONE: int = 3
const LOG: int = 4
const LEAVES: int = 5
const COAL: int = 6
const IRON: int = 7
const GOLD: int = 8
const CRYSTAL: int = 9
const BEDROCK: int = 10
const PLANKS: int = 11
const SAND: int = 12
const TORCH: int = 13

## Por bloque: solido, segundos con la mano, nivel de pico necesario, si el pico ayuda y que suelta.
const BLOCKS: Array = [
	{"solid": false, "time": 0.0, "tier": 0, "pick": false, "drop": ""},
	{"solid": true, "time": 0.45, "tier": 0, "pick": false, "drop": "tierra"},
	{"solid": true, "time": 0.4, "tier": 0, "pick": false, "drop": "tierra"},
	{"solid": true, "time": 1.4, "tier": 1, "pick": true, "drop": "piedra"},
	{"solid": false, "time": 0.9, "tier": 0, "pick": false, "drop": "tronco"},
	{"solid": false, "time": 0.15, "tier": 0, "pick": false, "drop": ""},
	{"solid": true, "time": 1.5, "tier": 1, "pick": true, "drop": "carbon"},
	{"solid": true, "time": 1.8, "tier": 2, "pick": true, "drop": "hierro"},
	{"solid": true, "time": 2.0, "tier": 3, "pick": true, "drop": "oro"},
	{"solid": true, "time": 2.4, "tier": 3, "pick": true, "drop": "cristal"},
	{"solid": true, "time": 0.0, "tier": 99, "pick": true, "drop": ""},
	{"solid": true, "time": 0.7, "tier": 0, "pick": false, "drop": "tablas"},
	{"solid": true, "time": 0.4, "tier": 0, "pick": false, "drop": "arena"},
	{"solid": false, "time": 0.1, "tier": 0, "pick": false, "drop": "antorcha"},
]
const PLACE: Dictionary = {"tierra": DIRT, "arena": SAND, "piedra": STONE, "tablas": PLANKS, "antorcha": TORCH}
const PICKS: Dictionary = {"pico_madera": 1, "pico_piedra": 2, "pico_hierro": 3}
const PICK_FOR: Array[String] = ["", "pico_madera", "pico_piedra", "pico_hierro"]
const SWORDS: Dictionary = {"espada_madera": 2, "espada_piedra": 3, "espada_hierro": 5}
## Recetas en el orden del menu. "at": lo que hay que tener construido (mesa u horno).
const RECIPES: Dictionary = {
	"tablas": {"in": {"tronco": 1}, "out": 4, "at": ""},
	"palos": {"in": {"tablas": 2}, "out": 4, "at": ""},
	"mesa": {"in": {"tablas": 4}, "out": 1, "at": ""},
	"pico_madera": {"in": {"tablas": 3, "palos": 2}, "out": 1, "at": "mesa"},
	"espada_madera": {"in": {"tablas": 2, "palos": 1}, "out": 1, "at": "mesa"},
	"pico_piedra": {"in": {"piedra": 3, "palos": 2}, "out": 1, "at": "mesa"},
	"espada_piedra": {"in": {"piedra": 2, "palos": 1}, "out": 1, "at": "mesa"},
	"horno": {"in": {"piedra": 8}, "out": 1, "at": "mesa"},
	"antorcha": {"in": {"carbon": 1, "palos": 1}, "out": 4, "at": ""},
	"lingote_hierro": {"in": {"hierro": 1, "carbon": 1}, "out": 1, "at": "horno"},
	"pico_hierro": {"in": {"lingote_hierro": 3, "palos": 2}, "out": 1, "at": "mesa"},
	"espada_hierro": {"in": {"lingote_hierro": 2, "palos": 1}, "out": 1, "at": "mesa"},
	"lingote_oro": {"in": {"oro": 1, "carbon": 1}, "out": 1, "at": "horno"},
	"corona": {"in": {"lingote_oro": 4, "cristal": 2}, "out": 1, "at": "mesa"},
}
## Materias primas: de que bloques salen.
const RAW: Dictionary = {"tronco": [LOG], "piedra": [STONE], "carbon": [COAL], "hierro": [IRON], "oro": [GOLD], "cristal": [CRYSTAL],
	"tierra": [DIRT, GRASS], "arena": [SAND]}
const BIOMES: String = "blmd"
const AMP: Dictionary = {"b": 3.0, "l": 1.6, "m": 9.0, "d": 2.0}
const TREE_GAP: Dictionary = {"b": Vector2i(4, 7), "l": Vector2i(9, 15), "m": Vector2i(10, 16), "d": Vector2i(0, 0)}


static func biomes_of(level: Dictionary) -> String:
	var s: String = ""
	for r: Variant in level.get("map", []):
		for c: String in str(r).strip_edges():
			if BIOMES.contains(c):
				s += c
	return s


static func world_key(level: Dictionary) -> String:
	return "%s:%d" % [biomes_of(level), int(level.get("seed", 1))]


# ------------------------------------------------------------------ mundo

static func new_state(level: Dictionary) -> Dictionary:
	var biomes: String = biomes_of(level)
	if biomes.length() < 1:
		biomes = "lbl"
	var w: int = clampi(biomes.length() * 32, 96, 288)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(level.get("seed", 1))
	var grid: PackedByteArray = PackedByteArray()
	grid.resize(w * H)
	grid.fill(AIR)
	var surface: PackedInt32Array = PackedInt32Array()
	surface.resize(w)
	## 1 - Altura del suelo: suma de ondas con la amplitud de cada bioma (suavizada en los bordes).
	var amps: Array[float] = []
	for x: int in w:
		amps.append(float(AMP[biomes[mini(biomes.length() - 1, x / 32)]]))
	var a1: float = rng.randf() * TAU
	var a2: float = rng.randf() * TAU
	var a3: float = rng.randf() * TAU
	for x2: int in w:
		var amp: float = 0.0
		var cnt: int = 0
		for k: int in range(maxi(0, x2 - 10), mini(w, x2 + 11)):
			amp += amps[k]
			cnt += 1
		amp /= float(cnt)
		var hgt: float = sin(float(x2) * 0.045 + a1) * 0.8 + sin(float(x2) * 0.11 + a2) * 0.35 + sin(float(x2) * 0.021 + a3) * 0.6
		surface[x2] = clampi(int(round(30.0 - amp * 0.5 + hgt * amp)), 12, 44)
	for x3: int in w:
		var b: String = biomes[mini(biomes.length() - 1, x3 / 32)]
		var s: int = surface[x3]
		var soil: int = 2 if b == "m" else (5 if b == "d" else 4)
		for y: int in range(s, H):
			var id: int = STONE
			if y >= H - 2:
				id = BEDROCK
			elif y == s:
				id = SAND if b == "d" else GRASS
			elif y <= s + soil:
				id = SAND if b == "d" else DIRT
			grid[y * w + x3] = id
	## 2 - Cuevas: gusanos que excavan bajo tierra.
	for c: int in w / 18:
		var px: float = rng.randf_range(4.0, float(w - 5))
		var py: float = rng.randf_range(float(surface[int(px)] + 8), float(H - 7))
		var ang: float = rng.randf() * TAU
		var rad: int = rng.randi_range(1, 2)
		for st2: int in rng.randi_range(30, 70):
			ang += rng.randf_range(-0.5, 0.5)
			px = clampf(px + cos(ang), 2.0, float(w - 3))
			py = clampf(py + sin(ang) * 0.6, 4.0, float(H - 4))
			for dx: int in range(-rad, rad + 1):
				for dy: int in range(-rad, rad + 1):
					var cx: int = int(px) + dx
					var cy: int = int(py) + dy
					if cx > 0 and cx < w - 1 and cy < H - 2 and cy > surface[cx] + 3 and dx * dx + dy * dy <= rad * rad + 1:
						grid[cy * w + cx] = AIR
	## 3 - Vetas de mineral: mas valioso, mas hondo y mas escaso.
	_veins(grid, w, surface, rng, COAL, maxi(8, w / 4), 3, Vector2i(3, 7))
	_veins(grid, w, surface, rng, IRON, maxi(6, w / 6), 12, Vector2i(3, 5))
	_veins(grid, w, surface, rng, GOLD, maxi(5, w / 10), 24, Vector2i(2, 4))
	_veins(grid, w, surface, rng, CRYSTAL, maxi(4, w / 14), 34, Vector2i(1, 3))
	## 4 - Arboles (los troncos y las hojas no estorban al andar).
	var x4: int = 3
	while x4 < w - 4:
		var b2: String = biomes[mini(biomes.length() - 1, x4 / 32)]
		var gap: Vector2i = TREE_GAP[b2]
		if gap.x == 0:
			x4 += 3
			continue
		var s2: int = surface[x4]
		if grid[s2 * w + x4] == GRASS and absi(x4 - w / 2) > 1:
			var th: int = rng.randi_range(4, 6)
			for k2: int in th:
				grid[(s2 - 1 - k2) * w + x4] = LOG
			var top: int = s2 - th
			for lx: int in range(-2, 3):
				for ly: int in range(-2, 2):
					var gx: int = x4 + lx
					var gy: int = top + ly
					if gx >= 0 and gx < w and gy >= 0 and lx * lx + ly * ly <= 5 and grid[gy * w + gx] == AIR:
						grid[gy * w + gx] = LEAVES
		x4 += rng.randi_range(gap.x, gap.y)
	var sx: int = w / 2
	var st: Dictionary = {"w": w, "grid": grid, "surface": surface, "biomes": biomes, "key": world_key(level), "rng": rng,
		"p": Vector2((float(sx) + 0.5) * TILE, float(surface[sx]) * TILE), "v": Vector2.ZERO, "on_floor": false, "kb": 0.0,
		"spawn": Vector2((float(sx) + 0.5) * TILE, float(surface[sx]) * TILE), "facing": 1,
		"hp": MAX_HP, "hurt_cd": 0.0, "calm": 0.0, "dead": false, "won": false,
		"inv": {}, "got": {}, "edits": {}, "clock": 0.0, "time": 0.0,
		"day": float(level.get("day", 180.0)), "night": float(level.get("night", 70.0)), "max_mobs": clampi(int(level.get("mobs", 2)), 0, 5),
		"mobs": [], "mob_cd": 3.0, "kills": 0, "hit_cd": 0.0,
		"goal_item": str(level.get("goal_item", "mesa")), "goal_n": maxi(1, int(level.get("goal_n", 1))),
		"mine_target": Vector2i(-1, -1), "mine_cell": Vector2i(-1, -1), "mine_t": 0.0, "in": {"x": 0.0, "jump": false},
		"broke": [], "bot": {}}
	st["rules"] = Rules.load_rules(level)
	Rules.hook(st, "on_start")
	return st


static func _veins(grid: PackedByteArray, w: int, surface: PackedInt32Array, rng: RandomNumberGenerator, id: int, count: int, depth: int, size: Vector2i) -> void:
	for k: int in count:
		var x: int = rng.randi_range(2, w - 3)
		var lo: int = surface[x] + depth
		if lo > H - 4:
			continue
		var y: int = rng.randi_range(lo, H - 4)
		for n: int in rng.randi_range(size.x, size.y):
			if x > 0 and x < w - 1 and y > 0 and y < H - 2 and grid[y * w + x] == STONE:
				grid[y * w + x] = id
			match rng.randi_range(0, 3):
				0:
					x += 1
				1:
					x -= 1
				2:
					y += 1
				_:
					y -= 1


static func at(st: Dictionary, x: int, y: int) -> int:
	if x < 0 or x >= int(st["w"]) or y >= H:
		return BEDROCK
	if y < 0:
		return AIR
	return (st["grid"] as PackedByteArray)[y * int(st["w"]) + x]


static func solid(st: Dictionary, x: int, y: int) -> bool:
	return bool(BLOCKS[at(st, x, y)]["solid"])


static func set_cell(st: Dictionary, x: int, y: int, id: int) -> void:
	## Los Packed*Array se copian al sacarlos del diccionario: hay que volver a guardarlo.
	var grid: PackedByteArray = st["grid"]
	grid[y * int(st["w"]) + x] = id
	st["grid"] = grid
	(st["edits"] as Dictionary)["%d,%d" % [x, y]] = id


static func count_blocks(st: Dictionary, id: int) -> int:
	var n: int = 0
	for b: int in (st["grid"] as PackedByteArray):
		if b == id:
			n += 1
	return n


static func is_night(st: Dictionary) -> bool:
	return fmod(float(st["clock"]), float(st["day"]) + float(st["night"])) >= float(st["day"])


## Luz del cielo de 0 a 1 (amanecer y anochecer suaves).
static func daylight(st: Dictionary) -> float:
	var cyc: float = float(st["day"]) + float(st["night"])
	var t: float = fmod(float(st["clock"]), cyc)
	var d: float = float(st["day"])
	if t < d:
		return clampf(minf(t + 8.0, d - t) / 8.0, 0.3, 1.0)
	return 0.3


# ------------------------------------------------------------------ inventario

static func have(st: Dictionary, item: String) -> int:
	return int((st["inv"] as Dictionary).get(item, 0))


static func give(st: Dictionary, item: String, n: int) -> void:
	if item == "" or n == 0:
		return
	var inv: Dictionary = st["inv"]
	inv[item] = have(st, item) + n
	if int(inv[item]) <= 0:
		inv.erase(item)
	st["ver"] = int(st.get("ver", 0)) + 1
	if n > 0:
		_gain(st, item, n)


## Lo conseguido en este nivel (la meta cuenta desde que empieza el nivel).
static func _gain(st: Dictionary, item: String, n: int) -> void:
	var got: Dictionary = st["got"]
	got[item] = int(got.get(item, 0)) + n
	if item == str(st["goal_item"]) and int(got[item]) >= int(st["goal_n"]):
		st["won"] = true


static func tier(st: Dictionary) -> int:
	var t: int = 0
	for k: String in PICKS:
		if have(st, k) > 0:
			t = maxi(t, int(PICKS[k]))
	return t


static func damage(st: Dictionary) -> int:
	var d: int = 1
	for k: String in SWORDS:
		if have(st, k) > 0:
			d = maxi(d, int(SWORDS[k]))
	return d


static func can_craft(st: Dictionary, id: String) -> bool:
	if not RECIPES.has(id):
		return false
	var r: Dictionary = RECIPES[id]
	if str(r["at"]) != "" and have(st, str(r["at"])) < 1:
		return false
	for k: String in r["in"]:
		if have(st, k) < int(r["in"][k]):
			return false
	return true


static func craft(st: Dictionary, id: String) -> bool:
	if not can_craft(st, id):
		return false
	var r: Dictionary = RECIPES[id]
	for k: String in r["in"]:
		give(st, k, -int(r["in"][k]))
	give(st, id, int(r["out"]))
	Rules.hook(st, "on_craft", [id])
	return true


static func eat(st: Dictionary) -> bool:
	if have(st, "manzana") < 1 or int(st["hp"]) >= MAX_HP:
		return false
	give(st, "manzana", -1)
	st["hp"] = mini(MAX_HP, int(st["hp"]) + 4)
	return true


# ------------------------------------------------------------------ picar y poner

static func center(st: Dictionary) -> Vector2:
	return (st["p"] as Vector2) - Vector2(0.0, PH * 0.5)


static func feet(st: Dictionary) -> Vector2i:
	var p: Vector2 = st["p"]
	return Vector2i(floori(p.x / TILE), floori((p.y - 1.0) / TILE))


static func in_reach(st: Dictionary, c: Vector2i) -> bool:
	return center(st).distance_to((Vector2(c) + Vector2(0.5, 0.5)) * TILE) <= REACH * TILE


static func mine_time(st: Dictionary, id: int) -> float:
	var b: Dictionary = BLOCKS[id]
	var t: int = tier(st)
	if int(b["tier"]) > t:
		return INF
	if bool(b["pick"]):
		return float(b["time"]) / (1.0 + 0.7 * float(t))
	return float(b["time"]) / (1.0 + 0.25 * float(t))


static func can_mine(st: Dictionary, c: Vector2i) -> bool:
	var id: int = at(st, c.x, c.y)
	return id != AIR and c.y >= 0 and c.x >= 0 and c.x < int(st["w"]) and mine_time(st, id) < INF


static func break_cell(st: Dictionary, c: Vector2i) -> void:
	var id: int = at(st, c.x, c.y)
	if id == AIR:
		return
	set_cell(st, c.x, c.y, AIR)
	(st["broke"] as Array).append([c, id])
	give(st, str(BLOCKS[id]["drop"]), 1)
	Rules.hook(st, "on_break", [c, id])
	if id == LEAVES and (st["rng"] as RandomNumberGenerator).randf() < 0.16:
		give(st, "manzana", 1)
	if id == LOG:
		## El arbol cae entero: los troncos de encima y sus hojas.
		var y: int = c.y - 1
		while at(st, c.x, y) == LOG:
			set_cell(st, c.x, y, AIR)
			(st["broke"] as Array).append([Vector2i(c.x, y), LOG])
			give(st, "tronco", 1)
			y -= 1
		if at(st, c.x, y) == LEAVES or at(st, c.x, y + 1) == AIR:
			for lx: int in range(-2, 3):
				for ly: int in range(-2, 2):
					if at(st, c.x + lx, y + 1 + ly) == LEAVES and absi(lx) + absi(ly) <= 3:
						var q: Vector2i = Vector2i(c.x + lx, y + 1 + ly)
						set_cell(st, q.x, q.y, AIR)
						if (st["rng"] as RandomNumberGenerator).randf() < 0.12:
							give(st, "manzana", 1)


static func _body_rect(p: Vector2, w: float, h: float) -> Rect2:
	return Rect2(p.x - w * 0.5, p.y - h, w, h)


static func can_place(st: Dictionary, c: Vector2i, item: String) -> bool:
	if not PLACE.has(item) or have(st, item) < 1 or at(st, c.x, c.y) != AIR or c.y < 0 or c.y >= H - 1:
		return false
	if c.x < 0 or c.x >= int(st["w"]) or not in_reach(st, c):
		return false
	var id: int = int(PLACE[item])
	var cell: Rect2 = Rect2(Vector2(c) * TILE, Vector2(TILE, TILE))
	if bool(BLOCKS[id]["solid"]):
		if cell.intersects(_body_rect(st["p"], PW, PH)):
			return false
		for m: Dictionary in st["mobs"]:
			if cell.intersects(_body_rect(m["p"], MW, MH)):
				return false
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if solid(st, c.x + d.x, c.y + d.y):
			return true
	return false


static func place(st: Dictionary, c: Vector2i, item: String) -> bool:
	if not can_place(st, c, item):
		return false
	set_cell(st, c.x, c.y, int(PLACE[item]))
	var inv: Dictionary = st["inv"]
	inv[item] = have(st, item) - 1
	if int(inv[item]) <= 0:
		inv.erase(item)
	st["ver"] = int(st.get("ver", 0)) + 1
	return true


## Golpe a un monstruo (indice en st.mobs). Devuelve si lo ha tocado.
static func hit(st: Dictionary, k: int) -> bool:
	if float(st["hit_cd"]) > 0.0 or k < 0 or k >= (st["mobs"] as Array).size():
		return false
	var m: Dictionary = st["mobs"][k]
	if center(st).distance_to((m["p"] as Vector2) - Vector2(0, MH * 0.5)) > 2.6 * TILE:
		return false
	st["hit_cd"] = 0.4
	m["hp"] = float(m["hp"]) - float(damage(st))
	m["v"] = Vector2(signf((m["p"] as Vector2).x - (st["p"] as Vector2).x) * 420.0, -380.0)
	m["flash"] = 0.15
	if float(m["hp"]) <= 0.0:
		(st["mobs"] as Array).remove_at(k)
		st["kills"] = int(st["kills"]) + 1
		_gain(st, "monstruo", 1)
	return true


static func mob_near(st: Dictionary, dist: float) -> int:
	var best: int = -1
	var bd: float = dist * TILE
	var c: Vector2 = center(st)
	for k: int in (st["mobs"] as Array).size():
		var d: float = c.distance_to((st["mobs"][k]["p"] as Vector2) - Vector2(0, MH * 0.5))
		if d < bd:
			bd = d
			best = k
	return best


# ------------------------------------------------------------------ fisica

static func _free(st: Dictionary, x0: float, y0: float, x1: float, y1: float) -> bool:
	for ty: int in range(floori(y0 / TILE), floori((y1 - 0.01) / TILE) + 1):
		for tx: int in range(floori(x0 / TILE), floori((x1 - 0.01) / TILE) + 1):
			if solid(st, tx, ty):
				return false
	return true


## Mueve un cuerpo (jugador o monstruo) con choques contra los bloques; sube solo escalones de 1.
static func move_body(st: Dictionary, b: Dictionary, w: float, h: float, dt: float) -> void:
	var v: Vector2 = b["v"]
	v.y = minf(v.y + GRAV * dt, 1100.0)
	var n: int = maxi(1, ceili(maxf(absf(v.x), absf(v.y)) * dt / 14.0))
	var sdt: float = dt / float(n)
	var p: Vector2 = b["p"]
	var on_floor: bool = bool(b.get("on_floor", false))
	b["blocked"] = false
	for k: int in n:
		var nx: float = p.x + v.x * sdt
		if not _free(st, nx - w * 0.5, p.y - h, nx + w * 0.5, p.y):
			if on_floor and v.x != 0.0 and _free(st, nx - w * 0.5, p.y - h - TILE, nx + w * 0.5, p.y - TILE):
				p.y -= TILE
				p.x = nx
				b["stepped"] = TILE
			else:
				if v.x > 0.0:
					p.x = floorf((nx + w * 0.5) / TILE) * TILE - w * 0.5 - 0.01
				else:
					p.x = (floorf((nx - w * 0.5) / TILE) + 1.0) * TILE + w * 0.5 + 0.01
				b["blocked"] = true
		else:
			p.x = nx
		var ny: float = p.y + v.y * sdt
		on_floor = false
		if not _free(st, p.x - w * 0.5, ny - h, p.x + w * 0.5, ny):
			if v.y > 0.0:
				ny = floorf(ny / TILE) * TILE
				on_floor = true
			else:
				ny = (floorf((ny - h) / TILE) + 1.0) * TILE + h + 0.01
			v.y = 0.0
		p.y = ny
	b["p"] = p
	b["v"] = v
	b["on_floor"] = on_floor


## Un paso de juego. inp = {"x": -1..1, "jump": bool}; st.mine_target es la celda que se pica.
static func step(st: Dictionary, inp: Dictionary, dt: float) -> void:
	if bool(st["dead"]) or bool(st["won"]):
		return
	st["time"] = float(st["time"]) + dt
	st["clock"] = float(st["clock"]) + dt
	Rules.hook(st, "on_step", [dt])
	st["hit_cd"] = maxf(0.0, float(st["hit_cd"]) - dt)
	st["hurt_cd"] = maxf(0.0, float(st["hurt_cd"]) - dt)
	## 1 - Jugador.
	var ix: float = clampf(float(inp.get("x", 0.0)), -1.0, 1.0)
	if ix != 0.0:
		st["facing"] = int(signf(ix))
	var kb: float = float(st["kb"]) * pow(0.02, dt)
	st["kb"] = kb if absf(kb) > 5.0 else 0.0
	var body: Dictionary = {"p": st["p"], "v": Vector2(ix * SPEED + kb, (st["v"] as Vector2).y), "on_floor": st["on_floor"]}
	if bool(inp.get("jump", false)) and bool(st["on_floor"]):
		body["v"] = Vector2((body["v"] as Vector2).x, -JUMP)
		body["on_floor"] = false
	move_body(st, body, PW, PH, dt)
	st["p"] = body["p"]
	st["v"] = body["v"]
	st["on_floor"] = body["on_floor"]
	st["stepped"] = float(body.get("stepped", 0.0))
	## 2 - Picar.
	var mt: Vector2i = st["mine_target"]
	if mt.x >= 0 and can_mine(st, mt) and in_reach(st, mt):
		if mt != (st["mine_cell"] as Vector2i):
			st["mine_cell"] = mt
			st["mine_t"] = 0.0
		st["mine_t"] = float(st["mine_t"]) + dt
		if float(st["mine_t"]) >= mine_time(st, at(st, mt.x, mt.y)):
			break_cell(st, mt)
			st["mine_cell"] = Vector2i(-1, -1)
			st["mine_t"] = 0.0
	else:
		st["mine_cell"] = Vector2i(-1, -1)
		st["mine_t"] = 0.0
	## 3 - Vida: se recupera sola si nadie te toca un rato.
	st["calm"] = float(st["calm"]) + dt
	if float(st["calm"]) > 6.0 and int(st["hp"]) < MAX_HP:
		st["hp"] = int(st["hp"]) + 1
		st["calm"] = 3.0
	## 4 - Monstruos: salen de noche cerca de la superficie y se queman al amanecer.
	_mobs_step(st, dt)
	if int(st["hp"]) <= 0:
		st["dead"] = true


static func _mobs_step(st: Dictionary, dt: float) -> void:
	var mobs: Array = st["mobs"]
	var night: bool = is_night(st)
	var f: Vector2i = feet(st)
	var w: int = int(st["w"])
	st["mob_cd"] = float(st["mob_cd"]) - dt
	if night and float(st["mob_cd"]) <= 0.0 and mobs.size() < int(st["max_mobs"]):
		st["mob_cd"] = 5.0
		var surf: int = (st["surface"] as PackedInt32Array)[clampi(f.x, 0, w - 1)]
		if f.y <= surf + 4:
			var rng: RandomNumberGenerator = st["rng"]
			var sx: int = clampi(f.x + (1 if rng.randf() < 0.5 else -1) * rng.randi_range(11, 15), 1, w - 2)
			var sy: int = 0
			while sy < H - 1 and not solid(st, sx, sy):
				sy += 1
			if absi(sx - f.x) > 8:
				mobs.append({"p": Vector2((float(sx) + 0.5) * TILE, float(sy) * TILE), "v": Vector2.ZERO, "on_floor": false, "hp": 3.0, "flash": 0.0})
	var pr: Rect2 = _body_rect(st["p"], PW, PH)
	var k: int = mobs.size() - 1
	while k >= 0:
		var m: Dictionary = mobs[k]
		m["flash"] = maxf(0.0, float(m.get("flash", 0.0)) - dt)
		if not night:
			m["hp"] = float(m["hp"]) - dt * 1.5
		var dx: float = (st["p"] as Vector2).x - (m["p"] as Vector2).x
		var mv: Vector2 = m["v"]
		var want: float = signf(dx) * 95.0 if absf(dx) > 6.0 else 0.0
		mv.x = lerpf(mv.x, want, minf(1.0, dt * 4.0))
		if bool(m.get("blocked", false)) and bool(m["on_floor"]):
			mv.y = -600.0
		m["v"] = mv
		move_body(st, m, MW, MH, dt)
		if _body_rect(m["p"], MW, MH).intersects(pr) and float(st["hurt_cd"]) <= 0.0:
			st["hp"] = int(st["hp"]) - 1
			st["hurt_cd"] = 0.9
			st["calm"] = 0.0
			st["kb"] = signf(-dx) * 420.0 if dx != 0.0 else 420.0
			st["v"] = Vector2((st["v"] as Vector2).x, -300.0)
		if float(m["hp"]) <= 0.0 or absf(dx) > 30.0 * TILE:
			mobs.remove_at(k)
		k -= 1


## Volver a empezar tras morir: en la cama (el punto de salida) con todo lo que llevabas.
static func respawn(st: Dictionary) -> void:
	st["p"] = st["spawn"]
	_unstick(st)
	st["v"] = Vector2.ZERO
	st["hp"] = MAX_HP
	st["dead"] = false
	st["mobs"] = []
	st["mob_cd"] = 6.0
	st["bot"] = {}
	st["mine_target"] = Vector2i(-1, -1)


## Si el jugador quedo dentro de bloques (mundo cambiado), lo sube hasta el aire.
static func _unstick(st: Dictionary) -> void:
	var p: Vector2 = st["p"]
	var guard: int = 0
	while not _free(st, p.x - PW * 0.5, p.y - PH, p.x + PW * 0.5, p.y) and guard < H:
		p.y -= TILE
		guard += 1
	st["p"] = p


# ------------------------------------------------------------------ guardado

static func save_data(st: Dictionary) -> Dictionary:
	var p: Vector2 = st["p"]
	return {"key": st["key"], "edits": (st["edits"] as Dictionary).duplicate(), "inv": (st["inv"] as Dictionary).duplicate(),
		"pos": [p.x, p.y], "clock": float(st["clock"])}


static func load_into(st: Dictionary, d: Dictionary) -> bool:
	if str(d.get("key", "")) != str(st["key"]):
		return false
	var w: int = int(st["w"])
	var grid: PackedByteArray = st["grid"]
	var edits: Dictionary = st["edits"]
	var raw: Variant = d.get("edits", {})
	if raw is Dictionary:
		for k: Variant in raw:
			var parts: PackedStringArray = str(k).split(",")
			if parts.size() != 2:
				continue
			var x: int = int(parts[0])
			var y: int = int(parts[1])
			var id: int = int(raw[k])
			if x >= 0 and x < w and y >= 0 and y < H and id >= 0 and id < BLOCKS.size():
				grid[y * w + x] = id
				edits[str(k)] = id
	var inv: Variant = d.get("inv", {})
	if inv is Dictionary:
		for k2: Variant in inv:
			if int(inv[k2]) > 0:
				(st["inv"] as Dictionary)[str(k2)] = int(inv[k2])
	var pos: Variant = d.get("pos", [])
	if pos is Array and (pos as Array).size() == 2:
		st["p"] = Vector2(clampf(float(pos[0]), TILE, float(w - 1) * TILE), clampf(float(pos[1]), TILE, float(H - 2) * TILE))
		_unstick(st)
	st["grid"] = grid
	st["clock"] = float(d.get("clock", 0.0))
	return true


# ------------------------------------------------------------------ bot

## Que hace falta ahora para tener n de item: ["craft", receta], ["gather", materia] o [] si ya esta.
static func plan(st: Dictionary, item: String, n: int, depth: int = 0) -> Array:
	if have(st, item) >= n or depth > 12:
		return []
	if RECIPES.has(item):
		var r: Dictionary = RECIPES[item]
		var at_: String = str(r["at"])
		if at_ != "" and have(st, at_) < 1:
			return plan(st, at_, 1, depth + 1)
		for k: String in r["in"]:
			var sub: Array = plan(st, k, int(r["in"][k]), depth + 1)
			if not sub.is_empty():
				return sub
		return ["craft", item]
	if not RAW.has(item):
		return []
	var need: int = 0
	for id: int in RAW[item]:
		need = maxi(need, int(BLOCKS[id]["tier"]))
	if tier(st) < need:
		return plan(st, PICK_FOR[need], 1, depth + 1)
	return ["gather", item]


## Lo siguiente que quiere el bot: la meta del nivel y, de paso, una espada cuando ya puede.
static func bot_goal(st: Dictionary) -> Array:
	var g: String = str(st["goal_item"])
	var left: int = int(st["goal_n"]) - int((st["got"] as Dictionary).get(g, 0))
	## Cazar monstruos: primero una espada (de piedra si se puede) y luego a esperar la noche fuera.
	if g == "monstruo":
		if damage(st) < 3:
			var sw: Array = plan(st, "espada_piedra", 1)
			if not sw.is_empty():
				return sw
		return ["hunt", ""]
	var a: Array = plan(st, g, have(st, g) + maxi(1, left))
	if a.size() == 2 and str(a[0]) == "craft":
		return a
	for sw: String in ["espada_piedra", "espada_madera"]:
		if have(st, sw) > 0:
			break
		if can_craft(st, sw) and have(st, "mesa") > 0 and (sw != "espada_madera" or tier(st) >= 1):
			return ["craft", sw]
	return a


## El bot decide la entrada de este paso: deja st.in y st.mine_target listos para step().
static func bot_control(st: Dictionary) -> void:
	var bot: Dictionary = st["bot"]
	st["in"] = {"x": 0.0, "jump": false}
	st["mine_target"] = Vector2i(-1, -1)
	if bool(st["dead"]) or bool(st["won"]):
		return
	## 1 - Defenderse y comer.
	if int(st["hp"]) <= 5:
		eat(st)
	var mk: int = mob_near(st, 2.4)
	if mk >= 0:
		hit(st, mk)
		return
	## 2 - Fabricar todo lo que ya se puede.
	for k: int in 6:
		var a: Array = bot_goal(st)
		if a.size() == 2 and str(a[0]) == "craft":
			craft(st, str(a[1]))
			if bool(st["won"]):
				return
		else:
			break
	var goal: Array = bot_goal(st)
	if goal.size() == 2 and str(goal[0]) == "hunt":
		_bot_hunt(st, bot)
		return
	if goal.size() != 2 or str(goal[0]) != "gather":
		return
	var item: String = str(goal[1])
	## 3 - Elegir un bloque de la materia que falta y un camino hasta tenerlo a mano.
	var tgt: Vector2i = bot.get("target", Vector2i(-1, -1))
	if tgt.x < 0 or not (RAW[item] as Array).has(at(st, tgt.x, tgt.y)) or str(bot.get("item", "")) != item:
		var bad: Dictionary = bot.get("bad", {}) if str(bot.get("item", "")) == item else {}
		var wait: int = int(bot.get("wait", 0)) - 1
		bot.clear()
		bot["item"] = item
		bot["bad"] = bad
		bot["wait"] = wait
		if wait > 0:
			return
		tgt = _pick_target(st, item, bad)
		bot["target"] = tgt
		if tgt.x < 0:
			return
		bot["path"] = find_path(st, feet(st), tgt)
		bot["i"] = 0
		bot["stuck"] = 0.0
		bot["last"] = feet(st)
		bot["replans"] = 0
	if in_reach(st, tgt) and bool(st["on_floor"]):
		st["mine_target"] = tgt
		return
	var path: Array = bot.get("path", [])
	if path.is_empty():
		_bad_target(st, bot, tgt)
		return
	var cur: Vector2i = feet(st)
	var i: int = int(bot["i"])
	var idx: int = path.find(cur)
	if idx >= i:
		i = idx + 1
	bot["i"] = i
	## 4 - Atasco: si no avanzo en un rato, se busca otro camino (y al final otro bloque).
	if cur != (bot["last"] as Vector2i):
		bot["last"] = cur
		bot["stuck"] = 0.0
	else:
		bot["stuck"] = float(bot["stuck"]) + 1.0
	if i >= path.size() or float(bot["stuck"]) > 360.0:
		bot["replans"] = int(bot["replans"]) + 1
		if int(bot["replans"]) > 4:
			_bad_target(st, bot, tgt)
			return
		bot["path"] = find_path(st, cur, tgt)
		bot["i"] = 0
		bot["stuck"] = 0.0
		return
	var n: Vector2i = path[i]
	## 5 - Abrir paso picando y luego moverse.
	for c: Vector2i in _digs(cur, n):
		if solid(st, c.x, c.y):
			if can_mine(st, c):
				st["mine_target"] = c
				bot["stuck"] = 0.0
			else:
				bot["stuck"] = 999.0
			return
	var tx: float = (float(n.x) + 0.5) * TILE
	var px: float = (st["p"] as Vector2).x
	if n.x != cur.x:
		var cx: float = (float(cur.x) + 0.5) * TILE
		## Para subir un escalon no puede asomar por la columna de detras.
		if n.y < cur.y and (px - cx) * signf(cx - tx) > 6.0:
			st["in"] = {"x": signf(cx - px) * 0.5, "jump": false}
		else:
			st["in"] = {"x": signf(tx - px), "jump": false}
	elif absf(tx - px) > 3.0:
		st["in"] = {"x": signf(tx - px) * 0.5, "jump": false}


## Cazar: volver a la superficie (al punto de salida) y esperar a que vengan.
static func _bot_hunt(st: Dictionary, bot: Dictionary) -> void:
	var sp: Vector2 = st["spawn"]
	var home: Vector2i = Vector2i(floori(sp.x / TILE), floori((sp.y - 1.0) / TILE))
	var cur: Vector2i = feet(st)
	if absi(cur.x - home.x) + absi(cur.y - home.y) <= 2:
		return
	bot["wait"] = int(bot.get("wait", 0)) - 1
	if str(bot.get("item", "")) != "hunt" or (bot.get("path", []) as Array).is_empty() or int(bot.get("i", 0)) >= (bot["path"] as Array).size():
		if int(bot["wait"]) > 0:
			return
		bot.clear()
		bot["item"] = "hunt"
		bot["wait"] = 90
		bot["path"] = find_path(st, cur, home + Vector2i(0, -1))
		bot["i"] = 0
		if (bot["path"] as Array).is_empty():
			return
	var path: Array = bot["path"]
	var idx: int = path.find(cur)
	if idx >= int(bot["i"]):
		bot["i"] = idx + 1
	if int(bot["i"]) >= path.size():
		return
	var n: Vector2i = path[int(bot["i"])]
	for c: Vector2i in _digs(cur, n):
		if solid(st, c.x, c.y):
			if can_mine(st, c):
				st["mine_target"] = c
			return
	var tx: float = (float(n.x) + 0.5) * TILE
	var px: float = (st["p"] as Vector2).x
	if n.x != cur.x:
		var cx: float = (float(cur.x) + 0.5) * TILE
		if n.y < cur.y and (px - cx) * signf(cx - tx) > 6.0:
			st["in"] = {"x": signf(cx - px) * 0.5, "jump": false}
		else:
			st["in"] = {"x": signf(tx - px), "jump": false}
	elif absf(tx - px) > 3.0:
		st["in"] = {"x": signf(tx - px) * 0.5, "jump": false}


static func _bad_target(st: Dictionary, bot: Dictionary, tgt: Vector2i) -> void:
	var bad: Dictionary = bot.get("bad", {})
	bad[tgt] = true
	var item: String = str(bot.get("item", ""))
	bot.clear()
	bot["bad"] = bad
	bot["item"] = item
	bot["wait"] = 8


## Celdas que hay que vaciar para ir de cur a n (paso del camino).
static func _digs(cur: Vector2i, n: Vector2i) -> Array:
	if n.x == cur.x and n.y > cur.y:
		return [Vector2i(cur.x, cur.y + 1)]
	if n.y < cur.y:
		return [Vector2i(cur.x, cur.y - 2), Vector2i(n.x, cur.y - 1), Vector2i(n.x, cur.y - 2)]
	return [Vector2i(n.x, cur.y - 1), Vector2i(n.x, cur.y)]


static func _pick_target(st: Dictionary, item: String, bad: Dictionary) -> Vector2i:
	var ids: Array = RAW[item]
	var f: Vector2i = feet(st)
	var w: int = int(st["w"])
	var grid: PackedByteArray = st["grid"]
	var best: Vector2i = Vector2i(-1, -1)
	var bd: float = INF
	for y: int in H:
		for x: int in w:
			if ids.has(grid[y * w + x]):
				var c: Vector2i = Vector2i(x, y)
				if bad.has(c):
					continue
				var d: float = absf(float(x - f.x)) + 1.6 * maxf(0.0, float(y - f.y)) + 0.6 * maxf(0.0, float(f.y - y))
				if d < bd:
					bd = d
					best = c
	return best


static func _dig_cost(st: Dictionary, x: int, y: int) -> float:
	var id: int = at(st, x, y)
	if not bool(BLOCKS[id]["solid"]):
		return 0.0
	var t: float = mine_time(st, id)
	if t == INF or y < 0:
		return -1.0
	return t * 1.5 + 0.4


## Camino (A*) de pie en pie hasta un sitio desde el que se alcanza target. Se puede andar, caer,
## subir escalones de 1 y picar lo que estorbe (cuesta su tiempo de picar).
static func find_path(st: Dictionary, start: Vector2i, target: Vector2i) -> Array:
	var w: int = int(st["w"])
	var tc: Vector2 = Vector2(target) + Vector2(0.5, 0.5)
	var g: Dictionary = {start: 0.0}
	var came: Dictionary = {}
	var open: Array = [[1.6 * _h(start, tc), start]]
	var closed: Dictionary = {}
	var expansions: int = 0
	while not open.is_empty() and expansions < 9000:
		var cur: Vector2i = _heap_pop(open)
		if closed.has(cur):
			continue
		closed[cur] = true
		expansions += 1
		if (Vector2(cur) + Vector2(0.5, 0.1)).distance_to(tc) <= REACH - 0.6:
			var out: Array = [cur]
			while came.has(out[0]):
				out.push_front(came[out[0]])
			return out
		var gc: float = float(g[cur])
		var edges: Array = []
		for d: int in [-1, 1]:
			var nx: int = cur.x + d
			if nx < 1 or nx >= w - 1:
				continue
			var c1: float = _dig_cost(st, nx, cur.y)
			var c2: float = _dig_cost(st, nx, cur.y - 1)
			if c1 >= 0.0 and c2 >= 0.0:
				if solid(st, nx, cur.y + 1):
					edges.append([Vector2i(nx, cur.y), 1.0 + c1 + c2])
				else:
					var ny: int = cur.y + 1
					while ny < H - 2 and not solid(st, nx, ny + 1):
						ny += 1
					edges.append([Vector2i(nx, ny), 1.0 + c1 + c2 + 0.2 * float(ny - cur.y)])
			if solid(st, nx, cur.y):
				var u1: float = _dig_cost(st, cur.x, cur.y - 2)
				var u2: float = _dig_cost(st, nx, cur.y - 1)
				var u3: float = _dig_cost(st, nx, cur.y - 2)
				if u1 >= 0.0 and u2 >= 0.0 and u3 >= 0.0 and cur.y - 2 >= 0:
					edges.append([Vector2i(nx, cur.y - 1), 1.6 + u1 + u2 + u3])
		var cd: float = _dig_cost(st, cur.x, cur.y + 1)
		if cd > 0.0 and cur.y + 1 < H - 2:
			var ny2: int = cur.y + 1
			while ny2 < H - 2 and not solid(st, cur.x, ny2 + 1):
				ny2 += 1
			edges.append([Vector2i(cur.x, ny2), 1.0 + cd + 0.2 * float(ny2 - cur.y)])
		for e: Array in edges:
			var nn: Vector2i = e[0]
			var ng: float = gc + float(e[1])
			if not closed.has(nn) and ng < float(g.get(nn, INF)):
				g[nn] = ng
				came[nn] = cur
				_heap_push(open, [ng + 1.6 * _h(nn, tc), nn])
	return []


static func _h(c: Vector2i, tc: Vector2) -> float:
	return maxf(0.0, absf(float(c.x) + 0.5 - tc.x) + absf(float(c.y) - tc.y) - REACH)


static func _heap_push(h: Array, item: Array) -> void:
	h.append(item)
	var i: int = h.size() - 1
	while i > 0:
		var p: int = (i - 1) / 2
		if float(h[p][0]) <= float(h[i][0]):
			break
		var t: Variant = h[p]
		h[p] = h[i]
		h[i] = t
		i = p


static func _heap_pop(h: Array) -> Vector2i:
	var top: Vector2i = h[0][1]
	var last: Variant = h.pop_back()
	if not h.is_empty():
		h[0] = last
		var i: int = 0
		var n: int = h.size()
		while true:
			var l: int = i * 2 + 1
			var r: int = l + 1
			var m: int = i
			if l < n and float(h[l][0]) < float(h[m][0]):
				m = l
			if r < n and float(h[r][0]) < float(h[m][0]):
				m = r
			if m == i:
				break
			var t: Variant = h[m]
			h[m] = h[i]
			h[i] = t
			i = m
	return top


## Partida entera del bot (lo mismo que hace el analizador). Devuelve si gano, tiempo y muertes.
static func bot_play(level: Dictionary, limit: float = 1800.0) -> Dictionary:
	var st: Dictionary = new_state(level)
	var dt: float = 1.0 / 30.0
	var deaths: int = 0
	while not bool(st["won"]) and float(st["time"]) < limit:
		bot_control(st)
		step(st, st["in"], dt)
		if bool(st["dead"]):
			deaths += 1
			if deaths > 3:
				break
			respawn(st)
	return {"won": bool(st["won"]), "time": float(st["time"]), "deaths": deaths, "kills": int(st["kills"]), "inv": st["inv"]}


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var b: String = biomes_of(level)
	if b.length() < 3 or b.length() > 9:
		issues.append("sandbox_map")
	var gi: String = str(level.get("goal_item", "mesa"))
	if not RECIPES.has(gi) and not RAW.has(gi) and gi != "monstruo":
		issues.append("sandbox_goal")
	var par: int = 0
	if issues.is_empty():
		var st: Dictionary = new_state(level)
		if count_blocks(st, COAL) < 20 or count_blocks(st, IRON) < 10 or count_blocks(st, GOLD) < 8 or count_blocks(st, CRYSTAL) < 4:
			issues.append("sandbox_ores")
		if count_blocks(st, LOG) < 12:
			issues.append("sandbox_trees")
	if issues.is_empty():
		var r: Dictionary = bot_play(level)
		if not bool(r["won"]):
			issues.append("sandbox_too_hard")
		## Una persona tarda bastante mas que el bot (que sabe donde esta todo).
		par = int(float(r["time"]) * 3.0) + 60
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": int(level.get("goal_n", 1)), "enemies": 0,
		"enemy_problems": [], "par": par}
