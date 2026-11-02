extends RefCounted
## Mundo de cubos en 3D: mundo generado con semilla, picar y poner cubos, fabricar con las mismas
## recetas que el mundo abierto 2D (sandbox_map.gd), fisica de cubos y bot que abre camino picando.
## Reglas, fisica, bot y analizador (lo usan el juego, el bot y el analizador).
## 1 - Mapa (game.json -> levels[i].map): los biomas, una letra por cuarto del mundo ("b" bosque,
##     "l" llanura, "m" montana, "d" desierto) y una fila "#semilla".
## 2 - Parametros: "seed", "goal_item" y "goal_n" (lo que hay que conseguir). El mundo y el
##     inventario se guardan entre niveles (save_data / load_into).
## Ejes: x y z en el suelo, y hacia arriba. Un cubo mide 1.

const S = preload("res://kit/sandbox/sandbox_map.gd")
const Rules = preload("res://kit/rules.gd")
const X: int = 48
const Z: int = 48
const Y: int = 32
const PW: float = 0.6
const PH: float = 1.75
const EYE: float = 1.55
const SPEED: float = 4.6
const GRAV: float = 26.0
const JUMP: float = 8.6
const REACH: float = 4.6


static func biomes_of(level: Dictionary) -> String:
	return S.biomes_of(level)


static func world_key(level: Dictionary) -> String:
	return "3d:" + S.world_key(level)


static func idx(x: int, y: int, z: int) -> int:
	return (y * Z + z) * X + x


static func new_state(level: Dictionary) -> Dictionary:
	var biomes: String = biomes_of(level)
	if biomes.length() < 1:
		biomes = "bl"
	var seed_v: int = int(level.get("seed", 1))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_v
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = seed_v
	noise.frequency = 0.045
	noise.fractal_octaves = 3
	var grid: PackedByteArray = PackedByteArray()
	grid.resize(X * Y * Z)
	grid.fill(S.AIR)
	var height: PackedInt32Array = PackedInt32Array()
	height.resize(X * Z)
	## 1 - Relieve: cada cuarto del mundo con su bioma (mas montana, mas altura).
	for z: int in Z:
		for x: int in X:
			var b: String = _biome(biomes, x, z)
			var amp: float = float(S.AMP[b]) * 0.9
			var h: int = clampi(int(12.0 + noise.get_noise_2d(float(x), float(z)) * amp * 1.4), 6, Y - 8)
			height[z * X + x] = h
			for y: int in h + 1:
				var id: int = S.STONE
				if y == 0:
					id = S.BEDROCK
				elif y == h:
					id = S.SAND if b == "d" else S.GRASS
				elif y >= h - (2 if b == "m" else 3):
					id = S.SAND if b == "d" else S.DIRT
				grid[idx(x, y, z)] = id
	## 2 - Cuevas: gusanos en 3D.
	for c: int in 10:
		var p: Vector3 = Vector3(rng.randf_range(4, X - 5), rng.randf_range(3, 8), rng.randf_range(4, Z - 5))
		var d: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, rng.randf() * TAU)
		for s2: int in rng.randi_range(25, 50):
			d = (d + Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(-0.2, 0.2), rng.randf_range(-0.4, 0.4))).normalized()
			p += d
			p = p.clamp(Vector3(2, 2, 2), Vector3(X - 3, Y - 6, Z - 3))
			for dx: int in range(-1, 2):
				for dy: int in range(-1, 2):
					for dz: int in range(-1, 2):
						var q: Vector3i = Vector3i(int(p.x) + dx, int(p.y) + dy, int(p.z) + dz)
						if q.y > 0 and q.y < int(height[q.z * X + q.x]) - 2:
							grid[idx(q.x, q.y, q.z)] = S.AIR
	## 3 - Vetas de mineral cada vez mas hondas.
	_veins(grid, height, rng, S.COAL, 70, 2, Vector2i(3, 6))
	_veins(grid, height, rng, S.IRON, 45, 4, Vector2i(2, 5))
	_veins(grid, height, rng, S.GOLD, 26, 6, Vector2i(2, 4))
	_veins(grid, height, rng, S.CRYSTAL, 16, 8, Vector2i(1, 3))
	## 4 - Arboles (troncos y hojas no estorban, como en 2D).
	for t: int in 200:
		var x2: int = rng.randi_range(2, X - 3)
		var z2: int = rng.randi_range(2, Z - 3)
		var b2: String = _biome(biomes, x2, z2)
		var keep: float = {"b": 0.5, "l": 0.12, "m": 0.1, "d": 0.0}[b2]
		var h2: int = height[z2 * X + x2]
		if rng.randf() > keep or grid[idx(x2, h2, z2)] != S.GRASS or (absi(x2 - X / 2) < 2 and absi(z2 - Z / 2) < 2):
			continue
		if grid[idx(x2, h2 + 1, z2)] != S.AIR:
			continue
		var th: int = rng.randi_range(4, 5)
		for k: int in th:
			grid[idx(x2, h2 + 1 + k, z2)] = S.LOG
		var top: int = h2 + th
		for lx: int in range(-2, 3):
			for lz: int in range(-2, 3):
				for ly: int in range(-1, 2):
					var q2: Vector3i = Vector3i(x2 + lx, top + ly, z2 + lz)
					if q2.x >= 0 and q2.x < X and q2.z >= 0 and q2.z < Z and q2.y < Y and lx * lx + lz * lz + ly * ly <= 5 and grid[idx(q2.x, q2.y, q2.z)] == S.AIR:
						grid[idx(q2.x, q2.y, q2.z)] = S.LEAVES
	var sp: Vector3 = Vector3(float(X / 2) + 0.5, float(height[(Z / 2) * X + X / 2] + 1), float(Z / 2) + 0.5)
	var st: Dictionary = {"grid": grid, "height": height, "biomes": biomes, "key": world_key(level), "rng": rng,
		"p": sp, "v": Vector3.ZERO, "on_floor": false, "spawn": sp, "yaw": 0.0, "pitch": 0.0,
		"hp": S.MAX_HP, "dead": false, "won": false, "inv": {}, "got": {}, "edits": {}, "time": 0.0, "clock": 0.0,
		"goal_item": str(level.get("goal_item", "mesa")), "goal_n": maxi(1, int(level.get("goal_n", 1))),
		"mine_target": Vector3i(-1, -1, -1), "mine_cell": Vector3i(-1, -1, -1), "mine_t": 0.0,
		"broke": [], "changed": [], "bot": {}, "ver": 0}
	st["rules"] = Rules.load_rules(level)
	Rules.hook(st, "on_start")
	return st


static func _biome(biomes: String, x: int, z: int) -> String:
	var q: int = (1 if x >= X / 2 else 0) + (2 if z >= Z / 2 else 0)
	return biomes[q % biomes.length()]


static func _veins(grid: PackedByteArray, height: PackedInt32Array, rng: RandomNumberGenerator, id: int, count: int, depth: int, size: Vector2i) -> void:
	for k: int in count:
		var x: int = rng.randi_range(1, X - 2)
		var z: int = rng.randi_range(1, Z - 2)
		var top: int = int(height[z * X + x]) - depth
		if top < 2:
			continue
		var y: int = rng.randi_range(1, top)
		for n: int in rng.randi_range(size.x, size.y):
			if x > 0 and x < X - 1 and z > 0 and z < Z - 1 and y > 0 and y < Y - 1 and grid[idx(x, y, z)] == S.STONE:
				grid[idx(x, y, z)] = id
			match rng.randi_range(0, 5):
				0:
					x += 1
				1:
					x -= 1
				2:
					z += 1
				3:
					z -= 1
				4:
					y += 1
				_:
					y -= 1


static func at(st: Dictionary, x: int, y: int, z: int) -> int:
	if x < 0 or z < 0 or x >= X or z >= Z or y < 0:
		return S.BEDROCK
	if y >= Y:
		return S.AIR
	return (st["grid"] as PackedByteArray)[idx(x, y, z)]


static func solid(st: Dictionary, x: int, y: int, z: int) -> bool:
	return bool(S.BLOCKS[at(st, x, y, z)]["solid"])


static func set_cell(st: Dictionary, c: Vector3i, id: int) -> void:
	var grid: PackedByteArray = st["grid"]
	grid[idx(c.x, c.y, c.z)] = id
	st["grid"] = grid
	(st["edits"] as Dictionary)["%d,%d,%d" % [c.x, c.y, c.z]] = id
	(st["changed"] as Array).append(c)


static func count_blocks(st: Dictionary, id: int) -> int:
	var n: int = 0
	for b: int in (st["grid"] as PackedByteArray):
		if b == id:
			n += 1
	return n


# ------------------------------------------------------------------ inventario (el de 2D)

static func have(st: Dictionary, item: String) -> int:
	return S.have(st, item)


static func give(st: Dictionary, item: String, n: int) -> void:
	S.give(st, item, n)


static func craft(st: Dictionary, id: String) -> bool:
	var ok: bool = S.craft(st, id)
	if ok:
		Rules.hook(st, "on_craft", [id])
	return ok


static func can_craft(st: Dictionary, id: String) -> bool:
	return S.can_craft(st, id)


static func mine_time(st: Dictionary, id: int) -> float:
	return S.mine_time(st, id)


# ------------------------------------------------------------------ picar, poner y mirar

static func eye(st: Dictionary) -> Vector3:
	return (st["p"] as Vector3) + Vector3(0, EYE, 0)


static func feet(st: Dictionary) -> Vector3i:
	var p: Vector3 = st["p"]
	return Vector3i(floori(p.x), floori(p.y + 0.01), floori(p.z))


static func in_reach(st: Dictionary, c: Vector3i) -> bool:
	return eye(st).distance_to(Vector3(c) + Vector3(0.5, 0.5, 0.5)) <= REACH


## Rayo por la rejilla (DDA): primer cubo que no es aire. Devuelve {"cell", "normal"} o {}.
static func raycast(st: Dictionary, from: Vector3, dir: Vector3, max_d: float = REACH) -> Dictionary:
	var d: Vector3 = dir.normalized()
	var c: Vector3i = Vector3i(floori(from.x), floori(from.y), floori(from.z))
	var step: Vector3i = Vector3i(int(signf(d.x)), int(signf(d.y)), int(signf(d.z)))
	var t_max: Vector3 = Vector3.ZERO
	var t_delta: Vector3 = Vector3.ZERO
	for a: int in 3:
		if d[a] == 0.0:
			t_max[a] = INF
			t_delta[a] = INF
		else:
			var nb: float = float(c[a] + (1 if step[a] > 0 else 0))
			t_max[a] = (nb - from[a]) / d[a]
			t_delta[a] = absf(1.0 / d[a])
	var normal: Vector3i = Vector3i.ZERO
	var t: float = 0.0
	while t <= max_d:
		if at(st, c.x, c.y, c.z) != S.AIR and c.y >= 0:
			return {"cell": c, "normal": normal}
		var a2: int = 0
		if t_max.y < t_max[a2]:
			a2 = 1
		if t_max.z < t_max[a2]:
			a2 = 2
		t = t_max[a2]
		t_max[a2] += t_delta[a2]
		c[a2] += step[a2]
		normal = Vector3i.ZERO
		normal[a2] = -step[a2]
	return {}


static func can_mine(st: Dictionary, c: Vector3i) -> bool:
	var id: int = at(st, c.x, c.y, c.z)
	return id != S.AIR and c.y > 0 and mine_time(st, id) < INF


static func break_cell(st: Dictionary, c: Vector3i) -> void:
	var id: int = at(st, c.x, c.y, c.z)
	if id == S.AIR:
		return
	set_cell(st, c, S.AIR)
	(st["broke"] as Array).append([c, id])
	give(st, str(S.BLOCKS[id]["drop"]), 1)
	if id == S.LEAVES and (st["rng"] as RandomNumberGenerator).randf() < 0.16:
		give(st, "manzana", 1)
	if id == S.LOG:
		## El arbol cae entero.
		var y: int = c.y + 1
		while at(st, c.x, y, c.z) == S.LOG:
			set_cell(st, Vector3i(c.x, y, c.z), S.AIR)
			give(st, "tronco", 1)
			y += 1
	Rules.hook(st, "on_break", [c, id])


static func _body_box(p: Vector3) -> AABB:
	return AABB(p - Vector3(PW * 0.5, 0, PW * 0.5), Vector3(PW, PH, PW))


static func can_place(st: Dictionary, c: Vector3i, item: String) -> bool:
	if not S.PLACE.has(item) or have(st, item) < 1 or at(st, c.x, c.y, c.z) != S.AIR or c.y <= 0 or c.y >= Y - 1:
		return false
	if c.x < 0 or c.z < 0 or c.x >= X or c.z >= Z or not in_reach(st, c):
		return false
	if bool(S.BLOCKS[int(S.PLACE[item])]["solid"]) and AABB(Vector3(c), Vector3.ONE).intersects(_body_box(st["p"])):
		return false
	return true


static func place(st: Dictionary, c: Vector3i, item: String) -> bool:
	if not can_place(st, c, item):
		return false
	set_cell(st, c, int(S.PLACE[item]))
	give(st, item, -1)
	return true


# ------------------------------------------------------------------ fisica

static func _free(st: Dictionary, box: AABB) -> bool:
	var a: Vector3 = box.position
	var b: Vector3 = box.end - Vector3(0.001, 0.001, 0.001)
	for y: int in range(floori(a.y), floori(b.y) + 1):
		for z: int in range(floori(a.z), floori(b.z) + 1):
			for x: int in range(floori(a.x), floori(b.x) + 1):
				if solid(st, x, y, z):
					return false
	return true


## Un paso. inp = {"move": Vector2 (x a la derecha, y adelante, relativo a donde miras), "jump": bool}.
static func step(st: Dictionary, inp: Dictionary, dt: float) -> void:
	if bool(st["dead"]) or bool(st["won"]):
		return
	st["time"] = float(st["time"]) + dt
	st["clock"] = float(st["clock"]) + dt
	Rules.hook(st, "on_step", [dt])
	var mv: Vector2 = inp.get("move", Vector2.ZERO)
	if mv.length() > 1.0:
		mv = mv.normalized()
	var yaw: float = float(st["yaw"])
	var fwd: Vector3 = Vector3(-sin(yaw), 0, -cos(yaw))
	var right: Vector3 = Vector3(cos(yaw), 0, -sin(yaw))
	var want: Vector3 = (right * mv.x + fwd * mv.y) * SPEED
	var v: Vector3 = st["v"]
	v.x = want.x
	v.z = want.z
	v.y = maxf(v.y - GRAV * dt, -30.0)
	if bool(inp.get("jump", false)) and bool(st["on_floor"]):
		v.y = JUMP
	var p: Vector3 = st["p"]
	var on_floor: bool = false
	var n: int = maxi(1, ceili(v.length() * dt / 0.25))
	var sdt: float = dt / float(n)
	for k: int in n:
		for a: int in [0, 2]:
			var np: Vector3 = p
			np[a] += v[a] * sdt
			if _free(st, _body_box(np)):
				p = np
			elif bool(st["on_floor"]) and _free(st, _body_box(np + Vector3(0, 1.0, 0))):
				## Escalon de un cubo: se sube solo.
				p = np + Vector3(0, 1.0, 0)
			else:
				v[a] = 0.0
		var ny: Vector3 = p + Vector3(0, v.y * sdt, 0)
		if _free(st, _body_box(ny)):
			p = ny
		else:
			if v.y < 0.0:
				p.y = floorf(p.y + v.y * sdt) + 1.0
				p.y = maxf(p.y, floorf(p.y))
				on_floor = true
			v.y = 0.0
	## Por si acaso: nunca dentro de un cubo.
	var guard: int = 0
	while not _free(st, _body_box(p)) and guard < Y:
		p.y = floorf(p.y) + 1.0
		guard += 1
	p.x = clampf(p.x, 0.4, float(X) - 0.4)
	p.z = clampf(p.z, 0.4, float(Z) - 0.4)
	st["p"] = p
	st["v"] = v
	st["on_floor"] = on_floor or (v.y == 0.0 and not _free(st, _body_box(p - Vector3(0, 0.05, 0))))
	## Picar.
	var mt: Vector3i = st["mine_target"]
	if mt.x >= 0 and can_mine(st, mt) and in_reach(st, mt):
		if mt != (st["mine_cell"] as Vector3i):
			st["mine_cell"] = mt
			st["mine_t"] = 0.0
		st["mine_t"] = float(st["mine_t"]) + dt
		if float(st["mine_t"]) >= mine_time(st, at(st, mt.x, mt.y, mt.z)):
			break_cell(st, mt)
			st["mine_cell"] = Vector3i(-1, -1, -1)
			st["mine_t"] = 0.0
	else:
		st["mine_cell"] = Vector3i(-1, -1, -1)
		st["mine_t"] = 0.0
	if p.y < -4.0:
		st["dead"] = true


# ------------------------------------------------------------------ guardado

static func save_data(st: Dictionary) -> Dictionary:
	var p: Vector3 = st["p"]
	return {"key": st["key"], "edits": (st["edits"] as Dictionary).duplicate(), "inv": (st["inv"] as Dictionary).duplicate(),
		"pos": [p.x, p.y, p.z], "yaw": float(st["yaw"])}


static func load_into(st: Dictionary, d: Dictionary) -> bool:
	if str(d.get("key", "")) != str(st["key"]):
		return false
	var grid: PackedByteArray = st["grid"]
	var raw: Variant = d.get("edits", {})
	if raw is Dictionary:
		for k: Variant in raw:
			var parts: PackedStringArray = str(k).split(",")
			if parts.size() != 3:
				continue
			var c: Vector3i = Vector3i(int(parts[0]), int(parts[1]), int(parts[2]))
			var id: int = int(raw[k])
			if c.x >= 0 and c.x < X and c.y >= 0 and c.y < Y and c.z >= 0 and c.z < Z and id >= 0 and id < S.BLOCKS.size():
				grid[idx(c.x, c.y, c.z)] = id
				(st["edits"] as Dictionary)[str(k)] = id
	st["grid"] = grid
	var inv: Variant = d.get("inv", {})
	if inv is Dictionary:
		for k2: Variant in inv:
			if int(inv[k2]) > 0:
				(st["inv"] as Dictionary)[str(k2)] = int(inv[k2])
	var pos: Variant = d.get("pos", [])
	if pos is Array and (pos as Array).size() == 3:
		st["p"] = Vector3(clampf(float(pos[0]), 1.0, float(X - 1)), clampf(float(pos[1]), 1.0, float(Y - 2)), clampf(float(pos[2]), 1.0, float(Z - 1)))
	st["yaw"] = float(d.get("yaw", 0.0))
	return true


static func respawn(st: Dictionary) -> void:
	st["p"] = st["spawn"]
	st["v"] = Vector3.ZERO
	st["hp"] = S.MAX_HP
	st["dead"] = false
	st["bot"] = {}


# ------------------------------------------------------------------ bot

## Lo siguiente: la meta (recetas y materias, igual que en 2D).
static func bot_goal(st: Dictionary) -> Array:
	return S.bot_goal(st)


static func _dig_cost(st: Dictionary, x: int, y: int, z: int) -> float:
	var id: int = at(st, x, y, z)
	if not bool(S.BLOCKS[id]["solid"]):
		return 0.0
	var t: float = mine_time(st, id)
	if t == INF or y <= 0:
		return -1.0
	return t * 1.5 + 0.4


## Camino (A*) de pie en pie: andar, caer, subir un escalon y picar lo que estorbe.
static func find_path(st: Dictionary, start: Vector3i, target: Vector3i) -> Array:
	var tc: Vector3 = Vector3(target) + Vector3(0.5, 0.5, 0.5)
	var g: Dictionary = {start: 0.0}
	var came: Dictionary = {}
	var open: Array = [[_h(start, tc), start]]
	var closed: Dictionary = {}
	var n: int = 0
	while not open.is_empty() and n < 7000:
		var cur: Vector3i = _pop(open)
		if closed.has(cur):
			continue
		closed[cur] = true
		n += 1
		if (Vector3(cur) + Vector3(0.5, EYE, 0.5)).distance_to(tc) <= REACH - 0.7:
			var out: Array = [cur]
			while came.has(out[0]):
				out.push_front(came[out[0]])
			return out
		var gc: float = float(g[cur])
		var edges: Array = []
		for d: Vector3i in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
			var nx: int = cur.x + d.x
			var nz: int = cur.z + d.z
			if nx < 1 or nz < 1 or nx >= X - 1 or nz >= Z - 1:
				continue
			var c1: float = _dig_cost(st, nx, cur.y, nz)
			var c2: float = _dig_cost(st, nx, cur.y + 1, nz)
			if c1 >= 0.0 and c2 >= 0.0:
				if solid(st, nx, cur.y - 1, nz):
					edges.append([Vector3i(nx, cur.y, nz), 1.0 + c1 + c2])
				else:
					var ny: int = cur.y - 1
					while ny > 1 and not solid(st, nx, ny - 1, nz):
						ny -= 1
					edges.append([Vector3i(nx, ny, nz), 1.0 + c1 + c2 + 0.2 * float(cur.y - ny)])
			if solid(st, nx, cur.y, nz):
				var u1: float = _dig_cost(st, cur.x, cur.y + 2, cur.z)
				var u2: float = _dig_cost(st, nx, cur.y + 1, nz)
				var u3: float = _dig_cost(st, nx, cur.y + 2, nz)
				if u1 >= 0.0 and u2 >= 0.0 and u3 >= 0.0 and cur.y + 2 < Y:
					edges.append([Vector3i(nx, cur.y + 1, nz), 1.6 + u1 + u2 + u3])
		var cd: float = _dig_cost(st, cur.x, cur.y - 1, cur.z)
		if cd > 0.0 and cur.y - 1 > 1:
			var ny2: int = cur.y - 1
			while ny2 > 1 and not solid(st, cur.x, ny2 - 1, cur.z):
				ny2 -= 1
			edges.append([Vector3i(cur.x, ny2, cur.z), 1.0 + cd + 0.2 * float(cur.y - ny2)])
		for e: Array in edges:
			var nn: Vector3i = e[0]
			var ng: float = gc + float(e[1])
			if not closed.has(nn) and ng < float(g.get(nn, INF)):
				g[nn] = ng
				came[nn] = cur
				S._heap_push(open, [ng + 1.6 * _h(nn, tc), nn])
	return []


static func _pop(h: Array) -> Vector3i:
	var top: Vector3i = h[0][1]
	var last: Variant = h.pop_back()
	if not h.is_empty():
		h[0] = last
		var i: int = 0
		var n: int = h.size()
		while true:
			var l: int = i * 2 + 1
			var m: int = i
			if l < n and float(h[l][0]) < float(h[m][0]):
				m = l
			if l + 1 < n and float(h[l + 1][0]) < float(h[m][0]):
				m = l + 1
			if m == i:
				break
			var t: Variant = h[m]
			h[m] = h[i]
			h[i] = t
			i = m
	return top


static func _h(c: Vector3i, tc: Vector3) -> float:
	return maxf(0.0, absf(float(c.x) + 0.5 - tc.x) + absf(float(c.z) + 0.5 - tc.z) + absf(float(c.y) + EYE - tc.y) - REACH)


static func _digs(cur: Vector3i, n: Vector3i) -> Array:
	if n.x == cur.x and n.z == cur.z and n.y < cur.y:
		return [Vector3i(cur.x, cur.y - 1, cur.z)]
	if n.y > cur.y:
		return [Vector3i(cur.x, cur.y + 2, cur.z), Vector3i(n.x, cur.y + 1, n.z), Vector3i(n.x, cur.y + 2, n.z)]
	return [Vector3i(n.x, cur.y + 1, n.z), Vector3i(n.x, cur.y, n.z)]


static func _pick_target(st: Dictionary, item: String, bad: Dictionary) -> Vector3i:
	var ids: Array = S.RAW[item]
	var f: Vector3i = feet(st)
	var grid: PackedByteArray = st["grid"]
	var best: Vector3i = Vector3i(-1, -1, -1)
	var bd: float = INF
	for y: int in Y:
		for z: int in Z:
			for x: int in X:
				if ids.has(grid[idx(x, y, z)]):
					var c: Vector3i = Vector3i(x, y, z)
					if bad.has(c):
						continue
					var d: float = float(absi(x - f.x) + absi(z - f.z)) + 1.6 * maxf(0.0, float(f.y - y)) + 0.6 * maxf(0.0, float(y - f.y))
					if d < bd:
						bd = d
						best = c
	return best


## El bot: fabrica lo que puede, elige un cubo de lo que falta, camina picando y lo pica.
## Deja st.in ({move, jump}), st.mine_target y la mirada (yaw/pitch) listos para step().
static func bot_control(st: Dictionary) -> void:
	var bot: Dictionary = st["bot"]
	st["in"] = {"move": Vector2.ZERO, "jump": false}
	st["mine_target"] = Vector3i(-1, -1, -1)
	if bool(st["dead"]) or bool(st["won"]):
		return
	for k: int in 6:
		var a: Array = bot_goal(st)
		if a.size() == 2 and str(a[0]) == "craft":
			craft(st, str(a[1]))
			if bool(st["won"]):
				return
		else:
			break
	var goal: Array = bot_goal(st)
	if goal.size() != 2 or str(goal[0]) != "gather":
		return
	var item: String = str(goal[1])
	var tgt: Vector3i = bot.get("target", Vector3i(-1, -1, -1))
	if tgt.x < 0 or not (S.RAW[item] as Array).has(at(st, tgt.x, tgt.y, tgt.z)) or str(bot.get("item", "")) != item:
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
		_look_at(st, Vector3(tgt) + Vector3(0.5, 0.5, 0.5))
		st["mine_target"] = tgt
		return
	var path: Array = bot.get("path", [])
	if path.is_empty():
		_bad(bot, tgt)
		return
	var cur: Vector3i = feet(st)
	var i: int = int(bot["i"])
	var found: int = path.find(cur)
	if found >= i:
		i = found + 1
	bot["i"] = i
	if cur != (bot["last"] as Vector3i):
		bot["last"] = cur
		bot["stuck"] = 0.0
	else:
		bot["stuck"] = float(bot["stuck"]) + 1.0
	if i >= path.size() or float(bot["stuck"]) > 300.0:
		bot["replans"] = int(bot["replans"]) + 1
		if int(bot["replans"]) > 4:
			_bad(bot, tgt)
			return
		bot["path"] = find_path(st, cur, tgt)
		bot["i"] = 0
		bot["stuck"] = 0.0
		return
	var nxt: Vector3i = path[i]
	for c: Vector3i in _digs(cur, nxt):
		if solid(st, c.x, c.y, c.z):
			if can_mine(st, c):
				_look_at(st, Vector3(c) + Vector3(0.5, 0.5, 0.5))
				st["mine_target"] = c
				bot["stuck"] = 0.0
			else:
				bot["stuck"] = 999.0
			return
	## Andar hacia el centro del siguiente cubo (mirando hacia alli).
	var p: Vector3 = st["p"]
	var dest: Vector3 = Vector3(float(nxt.x) + 0.5, p.y, float(nxt.z) + 0.5)
	var to: Vector3 = dest - p
	if Vector2(to.x, to.z).length() < 0.08:
		return
	_look_at(st, dest + Vector3(0, EYE, 0))
	var speed: float = 1.0 if Vector2(to.x, to.z).length() > 0.4 else 0.5
	st["in"] = {"move": Vector2(0, speed), "jump": false}


static func _look_at(st: Dictionary, q: Vector3) -> void:
	var d: Vector3 = q - eye(st)
	if Vector2(d.x, d.z).length() > 0.01:
		st["yaw"] = atan2(-d.x, -d.z)
	st["pitch"] = clampf(atan2(d.y, Vector2(d.x, d.z).length()), -1.4, 1.4)


static func _bad(bot: Dictionary, tgt: Vector3i) -> void:
	var bad: Dictionary = bot.get("bad", {})
	bad[tgt] = true
	var item: String = str(bot.get("item", ""))
	bot.clear()
	bot["bad"] = bad
	bot["item"] = item
	bot["wait"] = 8


static func bot_play(level: Dictionary, limit: float = 1500.0) -> Dictionary:
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
	return {"won": bool(st["won"]), "time": float(st["time"]), "deaths": deaths, "inv": st["inv"]}


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var b: String = biomes_of(level)
	if b.length() < 1 or b.length() > 4:
		issues.append("voxel_map")
	var gi: String = str(level.get("goal_item", "mesa"))
	if not S.RECIPES.has(gi) and not S.RAW.has(gi):
		issues.append("voxel_goal")
	var par: int = 0
	if issues.is_empty():
		var st: Dictionary = new_state(level)
		if count_blocks(st, S.COAL) < 20 or count_blocks(st, S.IRON) < 10 or count_blocks(st, S.GOLD) < 6 or count_blocks(st, S.CRYSTAL) < 3:
			issues.append("voxel_ores")
		if count_blocks(st, S.LOG) < 12:
			issues.append("voxel_trees")
	if issues.is_empty():
		var r: Dictionary = bot_play(level)
		if not bool(r["won"]):
			issues.append("voxel_too_hard")
		par = int(float(r["time"]) * 3.0) + 60
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": int(level.get("goal_n", 1)), "enemies": 0,
		"enemy_problems": [], "par": par}
