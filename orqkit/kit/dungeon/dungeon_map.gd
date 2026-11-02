extends RefCounted
## Mazmorras (RPG de accion, estilo Archero / Soul Knight): datos, salas, botin y analizador.
## Mapa (game.json -> levels[i].map): la planta de la mazmorra, una letra por sala:
##   S salida - M monstruos - E elite (un golem y su escolta) - T tesoro (cofre) - B jefe - # nada
## Las salas vecinas (arriba, abajo, izquierda, derecha) se unen con puertas que se abren al
## limpiar la sala. Parametros: "power" (vida y dano de los monstruos), "seed" (forma de las salas
## y donde salen los monstruos) y "par" (segundos para la tercera estrella).
## Analizador (SIN jugar):
## 1 - Entre 4 y 16 salas, una S y una B, solo letras validas y filas iguales.
## 2 - Todas las salas se alcanzan desde la salida.
## 3 - El jefe esta a 3 salas o mas de la salida.

const ROOM_W: int = 11
const ROOM_H: int = 15
const TILE: float = 64.0
const KINDS: String = "SMETB"
const DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

## Monstruos: vida, dano, velocidad (px/s), experiencia y como se mueven.
const ENEMIES: Dictionary = {
	"slime": {"hp": 30.0, "dmg": 8.0, "speed": 85.0, "xp": 6, "r": 24.0, "ai": "chase"},
	"bat": {"hp": 16.0, "dmg": 6.0, "speed": 150.0, "xp": 5, "r": 18.0, "ai": "zigzag"},
	"archer": {"hp": 24.0, "dmg": 9.0, "speed": 70.0, "xp": 8, "r": 22.0, "ai": "shoot", "rate": 2.2},
	"golem": {"hp": 130.0, "dmg": 18.0, "speed": 55.0, "xp": 25, "r": 34.0, "ai": "slam", "rate": 3.2},
	"boss": {"hp": 650.0, "dmg": 12.0, "speed": 70.0, "xp": 80, "r": 54.0, "ai": "boss", "rate": 2.6},
}

## Habilidades al subir de nivel (se eligen entre 3 al azar).
const SKILLS: Array[String] = ["multi", "diagonal", "rebote", "dano", "cadencia", "vida", "robo", "escudo", "rapido"]

## Equipo: cada pieza da su bonus segun la rareza.
const SLOTS: Array[String] = ["arma", "armadura", "anillo"]
const RARITIES: Array[String] = ["comun", "raro", "epico", "legendario"]
const RARITY_COLORS: Array[Color] = [Color("#cfd3da"), Color("#4aa3ff"), Color("#b36bff"), Color("#ffb020")]
## Bonus por rareza: arma = % de dano, armadura = vida extra, anillo = % de critico.
const GEAR_BONUS: Dictionary = {"arma": [10.0, 22.0, 38.0, 60.0], "armadura": [15.0, 35.0, 60.0, 100.0], "anillo": [5.0, 10.0, 16.0, 25.0]}


static func parse(level: Dictionary) -> Dictionary:
	var rows: Array[String] = []
	for r: Variant in level.get("map", []):
		rows.append(str(r))
	var rooms: Dictionary = {}
	var start: Vector2i = Vector2i(-1, -1)
	var boss: Vector2i = Vector2i(-1, -1)
	var error: String = ""
	for y: int in rows.size():
		if rows[y].length() != rows[0].length():
			error = "dungeon_bad_rows"
		for x: int in rows[y].length():
			var ch: String = rows[y][x]
			if ch == "#" or ch == ".":
				continue
			if not KINDS.contains(ch):
				error = "dungeon_bad_char"
				continue
			rooms[Vector2i(x, y)] = ch
			if ch == "S":
				start = Vector2i(x, y) if start.x < 0 else Vector2i(-2, -2)
			elif ch == "B":
				boss = Vector2i(x, y) if boss.x < 0 else Vector2i(-2, -2)
	return {"rooms": rooms, "start": start, "boss": boss, "error": error}


## Distancia en salas desde 'from' (por puertas) a cada sala.
static func room_dist(rooms: Dictionary, from: Vector2i) -> Dictionary:
	var d: Dictionary = {from: 0}
	var q: Array[Vector2i] = [from]
	var head: int = 0
	while head < q.size():
		var c: Vector2i = q[head]
		head += 1
		for dir: Vector2i in DIRS:
			var n: Vector2i = c + dir
			if rooms.has(n) and not d.has(n):
				d[n] = int(d[c]) + 1
				q.append(n)
	return d


## Siguiente sala hacia 'to' (o la misma si ya esta).
static func next_room(rooms: Dictionary, from: Vector2i, to: Vector2i) -> Vector2i:
	var d: Dictionary = room_dist(rooms, to)
	var best: Vector2i = from
	var bv: int = int(d.get(from, 999))
	for dir: Vector2i in DIRS:
		var n: Vector2i = from + dir
		if d.has(n) and int(d[n]) < bv:
			bv = int(d[n])
			best = n
	return best


## Casillas de una sala: "#" pared o columna, "." suelo. Puertas en el centro de cada lado con
## sala vecina. La forma sale de la semilla y la clase de sala.
static func room_tiles(rooms: Dictionary, cell: Vector2i, seed: int) -> Array[String]:
	var g: Array = []
	for y: int in ROOM_H:
		var row: Array = []
		for x: int in ROOM_W:
			row.append("#" if x == 0 or y == 0 or x == ROOM_W - 1 or y == ROOM_H - 1 else ".")
		g.append(row)
	var kind: String = str(rooms.get(cell, "M"))
	var h: int = absi(hash(Vector3i(cell.x, cell.y, seed)))
	var pattern: int = 0 if kind in ["S", "B", "T"] else h % 5
	var pillars: Array[Vector2i] = []
	match pattern:
		1:
			pillars = [Vector2i(3, 4), Vector2i(7, 4), Vector2i(3, 10), Vector2i(7, 10)]
		2:
			pillars = [Vector2i(4, 7), Vector2i(5, 7), Vector2i(6, 7), Vector2i(2, 4), Vector2i(8, 10)]
		3:
			pillars = [Vector2i(3, 5), Vector2i(3, 6), Vector2i(7, 8), Vector2i(7, 9)]
		4:
			pillars = [Vector2i(2, 3), Vector2i(8, 3), Vector2i(5, 6), Vector2i(2, 11), Vector2i(8, 11), Vector2i(5, 9)]
	if kind == "B":
		pillars = [Vector2i(2, 4), Vector2i(8, 4), Vector2i(2, 10), Vector2i(8, 10)]
	for p: Vector2i in pillars:
		g[p.y][p.x] = "#"
	for i: int in 4:
		if rooms.has(cell + DIRS[i]):
			var d: Vector2i = door_tile(i)
			g[d.y][d.x] = "."
			## La casilla de dentro de la puerta siempre libre.
			var inside: Vector2i = d - DIRS[i]
			g[inside.y][inside.x] = "."
	var out: Array[String] = []
	for row: Array in g:
		out.append("".join(row))
	return out


## Casilla de la puerta del lado i (0 arriba, 1 derecha, 2 abajo, 3 izquierda).
static func door_tile(i: int) -> Vector2i:
	match i:
		0:
			return Vector2i(ROOM_W / 2, 0)
		1:
			return Vector2i(ROOM_W - 1, ROOM_H / 2)
		2:
			return Vector2i(ROOM_W / 2, ROOM_H - 1)
	return Vector2i(0, ROOM_H / 2)


## Monstruos de una sala: [tipo, casilla]. Lejos de las puertas y del centro de la entrada.
static func room_enemies(rooms: Dictionary, cell: Vector2i, seed: int, floor_i: int) -> Array:
	var kind: String = str(rooms.get(cell, "M"))
	var out: Array = []
	if kind in ["S", "T"]:
		return out
	var tiles: Array[String] = room_tiles(rooms, cell, seed)
	var rnd: RandomNumberGenerator = RandomNumberGenerator.new()
	rnd.seed = hash(Vector3i(cell.x * 7, cell.y * 13, seed))
	var list: Array[String] = []
	if kind == "B":
		list = ["boss"]
	elif kind == "E":
		list = ["golem", "slime", "archer"]
	else:
		var n: int = 3 + mini(floor_i / 2, 3) + rnd.randi_range(0, 1)
		var pool: Array[String] = ["slime", "slime", "bat"]
		if floor_i >= 1:
			pool.append("archer")
		if floor_i >= 3:
			pool.append("archer")
		for k: int in n:
			list.append(pool[rnd.randi_range(0, pool.size() - 1)])
	for t: String in list:
		for attempt: int in 60:
			var c: Vector2i = Vector2i(rnd.randi_range(1, ROOM_W - 2), rnd.randi_range(2, ROOM_H - 6))
			if t == "boss":
				c = Vector2i(ROOM_W / 2, 4)
			if tiles[c.y][c.x] != ".":
				continue
			var ok: bool = true
			for e: Array in out:
				if (e[1] as Vector2i).distance_to(c) < 2.0:
					ok = false
			if ok:
				out.append([t, c])
				break
	return out


## Pieza de equipo al abrir un cofre: tipo, rareza y bonus (mas rara cuanto mas honda).
static func roll_gear(rnd: RandomNumberGenerator, floor_i: int) -> Dictionary:
	var slot: String = SLOTS[rnd.randi_range(0, SLOTS.size() - 1)]
	var roll: float = rnd.randf() + 0.06 * float(floor_i)
	var r: int = 3 if roll > 1.15 else (2 if roll > 0.9 else (1 if roll > 0.55 else 0))
	return {"slot": slot, "rarity": r, "bonus": float(GEAR_BONUS[slot][r])}


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var p: Dictionary = parse(level)
	var rooms: Dictionary = p["rooms"]
	if str(p["error"]) != "":
		issues.append(str(p["error"]))
	if rooms.size() < 4 or rooms.size() > 16:
		issues.append("dungeon_rooms")
	var start: Vector2i = p["start"]
	var boss: Vector2i = p["boss"]
	if start.x < 0:
		issues.append("dungeon_start")
	if boss.x < 0:
		issues.append("dungeon_boss")
	if issues.is_empty():
		var d: Dictionary = room_dist(rooms, start)
		if d.size() != rooms.size():
			issues.append("dungeon_unreachable")
		elif int(d.get(boss, 0)) < 3:
			issues.append("dungeon_boss_close")
	var monsters: int = 0
	for c: Variant in rooms:
		monsters += 1 if str(rooms[c]) in ["M", "E", "B"] else 0
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": monsters, "enemies": monsters, "enemy_problems": []}
