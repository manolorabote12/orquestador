extends RefCounted
## Imperio (estrategia en tiempo real, estilo Age of Empires / Guerras Tribales): datos, reglas
## compartidas y analizador. El juego, el bot y la fabrica (niveles/generador.py, *_imperio) usan
## exactamente las mismas tablas.
## Mapa (game.json -> levels[i].map), vista desde arriba, una letra por casilla:
##   . hierba - ~ agua - ^ roca (no se pasa)
##   T arbol (madera) - B arbustos de bayas (comida) - O mina de oro (oro)
##   P tu centro urbano (3x3) - E centro urbano rival (3x3)
##   Edificios rivales: c cuartel, q arqueria, l establo, w taller (2x2), h casa (2x2),
##   t torre (1x1), # empalizada (1x1)
## Un edificio se marca con su letra en la casilla de arriba a la izquierda y el resto de su
## huella va en ".".
## Parametros del nivel: "start" {comida, madera, oro}, "villagers" (aldeanos al empezar),
## "ai" {income, first_wave, wave_every, wave_size, wave_grow, age2_at, age3_at, max_army},
## "par" (segundos para la segunda estrella) y "seconds" (limite, 0 = sin limite).
## Analizador (SIN jugar):
## 1 - Tamano 14-28 de ancho y 16-34 de alto, filas iguales, edificios dentro y sin solaparse.
## 2 - Un solo centro tuyo y al menos un centro rival, a 10 casillas o mas de camino.
## 3 - Se llega andando a cada centro rival.
## 4 - Cerca de tu centro hay madera, comida y oro suficientes, y sitio para construir.
## Plantilla por datos (game.json o nivel -> "empire"): nombres y numeros de tropas y edificios
## ("units", "builds": vida, dano, coste, tiempo, alcance, velocidad... y "name"), coste de las
## edades ("ages") y nombres de los recursos ("res_names"). Los papeles no cambian (aldeano,
## lancero, arquero, jinete, ariete...), asi la IA rival y el bot saben jugar igual. Estilos:
## "fantasia" y "galactico". apply(level) lo pone antes de jugar; sin datos, todo como siempre.

const RES: Array[String] = ["comida", "madera", "oro"]
const TERRAIN: Dictionary = {".": 0, "~": 1, "^": 2, "T": 3, "B": 4, "O": 5}
const GRASS: int = 0
const WATER: int = 1
const ROCK: int = 2
const TREE: int = 3
const BUSH: int = 4
const GOLD: int = 5
## Que recurso da cada terreno y cuanto tiene cada casilla.
const NODE_RES: Dictionary = {3: "madera", 4: "comida", 5: "oro"}
const NODE_AMOUNT: Dictionary = {3: 80.0, 4: 120.0, 5: 160.0}
const GATHER: Dictionary = {"comida": 1.0, "madera": 1.0, "oro": 0.8}
const FARM_RATE: float = 0.75
const FARM_FOOD: float = 400.0
const CARRY: float = 10.0
const MAX_POP: int = 60
## Mercado: se dan 100 de comida o madera y se reciben 40 de oro.
const TRADE_GIVE: int = 100
const TRADE_GET: int = 40

const BUILD: Dictionary = {
	"centro": {"size": 3, "hp": 1600.0, "pop": 5, "drop": true, "trains": ["aldeano"], "shoot": {"range": 5.5, "dmg": 5.0, "rate": 1.6}},
	"casa": {"size": 2, "hp": 350.0, "cost": {"madera": 30}, "time": 8.0, "pop": 5},
	"granja": {"size": 2, "hp": 200.0, "cost": {"madera": 40}, "time": 8.0, "food": true},
	"almacen": {"size": 2, "hp": 400.0, "cost": {"madera": 80}, "time": 10.0, "drop": true},
	"cuartel": {"size": 2, "hp": 700.0, "cost": {"madera": 150}, "time": 15.0, "trains": ["lancero"]},
	"arqueria": {"size": 2, "hp": 600.0, "cost": {"madera": 150}, "time": 15.0, "trains": ["arquero"], "age": 2},
	"establo": {"size": 2, "hp": 650.0, "cost": {"madera": 150, "oro": 50}, "time": 18.0, "trains": ["jinete"], "age": 2},
	"taller": {"size": 2, "hp": 600.0, "cost": {"madera": 200, "oro": 100}, "time": 20.0, "trains": ["ariete"], "age": 3},
	"torre": {"size": 1, "hp": 550.0, "cost": {"madera": 100, "oro": 50}, "time": 18.0, "age": 2, "shoot": {"range": 5.5, "dmg": 7.0, "rate": 1.3}},
	"muro": {"size": 1, "hp": 400.0, "cost": {"madera": 10}, "time": 3.0},
}
## Lo que puedes construir tu, en el orden de los botones.
const PLAYER_BUILD: Array[String] = ["casa", "granja", "almacen", "cuartel", "arqueria", "establo", "torre", "taller"]
const ENEMY_CHARS: Dictionary = {"E": "centro", "c": "cuartel", "q": "arqueria", "l": "establo", "w": "taller", "h": "casa",
	"t": "torre", "#": "muro"}

## Tropas. "bonus": dano multiplicado contra ese tipo (piedra, papel, tijera): el lancero gana al
## jinete, el jinete al arquero y el arquero al lancero. "bld": dano contra edificios.
## "pierce": dano que recibe de flechas (el ariete casi no lo nota).
const UNITS: Dictionary = {
	"aldeano": {"hp": 25.0, "dmg": 3.0, "rate": 1.5, "range": 0.7, "speed": 1.9, "cost": {"comida": 50}, "time": 5.0, "bld": 0.3},
	"lancero": {"hp": 60.0, "dmg": 6.0, "rate": 1.0, "range": 0.75, "speed": 1.6, "cost": {"comida": 40, "madera": 20}, "time": 7.0,
		"bonus": {"jinete": 3.0}, "bld": 0.6},
	"arquero": {"hp": 35.0, "dmg": 5.0, "rate": 1.2, "range": 4.0, "speed": 1.6, "cost": {"madera": 30, "oro": 35}, "time": 8.0,
		"bonus": {"lancero": 2.0}, "bld": 0.25, "arrow": true},
	"jinete": {"hp": 120.0, "dmg": 8.0, "rate": 1.1, "range": 0.8, "speed": 2.6, "cost": {"comida": 70, "oro": 60}, "time": 10.0,
		"bonus": {"arquero": 2.5}, "bld": 0.6},
	"ariete": {"hp": 220.0, "dmg": 45.0, "rate": 2.5, "range": 0.8, "speed": 0.9, "cost": {"madera": 140, "oro": 70}, "time": 14.0,
		"bld": 1.0, "only_bld": true, "pierce": 0.2},
}
const ARMY: Array[String] = ["lancero", "arquero", "jinete", "ariete"]
const AGE_COST: Array[Dictionary] = [{}, {}, {"comida": 300, "oro": 80}, {"comida": 500, "oro": 250}]
const AGE_TIME: Array[float] = [0.0, 0.0, 20.0, 30.0]
const AI_DEFAULT: Dictionary = {"income": 1.0, "first_wave": 210.0, "wave_every": 110.0, "wave_size": 4, "wave_grow": 2,
	"age2_at": 260.0, "age3_at": 540.0, "max_army": 24}
const AI_RATE: Dictionary = {"comida": 1.6, "madera": 1.0, "oro": 0.9}

## Lo que se usa al jugar (copia de las tablas con lo del juego encima; ver apply).
static var units: Dictionary = UNITS.duplicate(true)
static var builds: Dictionary = BUILD.duplicate(true)
static var age_cost: Array = AGE_COST.duplicate(true)
static var res_names: Dictionary = {}
const PRESETS: Dictionary = {
	"fantasia": {"units": {"aldeano": {"name": "Pe\u00f3n"}, "lancero": {"name": "Guardi\u00e1n"}, "arquero": {"name": "Elfa arquera", "range": 4.4},
		"jinete": {"name": "Jinete de grifo", "speed": 2.9, "hp": 110.0}, "ariete": {"name": "G\u00f3lem", "hp": 260.0, "speed": 0.8}},
		"builds": {"centro": {"name": "Ciudadela"}, "cuartel": {"name": "Barracones"}, "arqueria": {"name": "Arboleda"}, "establo": {"name": "Nido de grifos"},
			"taller": {"name": "Forja de g\u00f3lems"}, "torre": {"name": "Torre de mago", "shoot": {"range": 6.0, "dmg": 7.0, "rate": 1.3}}},
		"res_names": {"oro": "man\u00e1"}},
	"galactico": {"units": {"aldeano": {"name": "Dron minero"}, "lancero": {"name": "Marine"}, "arquero": {"name": "Francotirador", "range": 4.6, "dmg": 5.5},
		"jinete": {"name": "Moto a\u00e9rea", "speed": 3.0}, "ariete": {"name": "Tanque de asedio", "dmg": 50.0}},
		"builds": {"centro": {"name": "Base"}, "casa": {"name": "M\u00f3dulo"}, "granja": {"name": "Invernadero"}, "almacen": {"name": "Silo"},
			"cuartel": {"name": "Barracones"}, "arqueria": {"name": "Academia"}, "establo": {"name": "Hangar"}, "taller": {"name": "F\u00e1brica"},
			"torre": {"name": "Torreta"}, "muro": {"name": "Barrera"}},
		"res_names": {"comida": "energ\u00eda", "madera": "metal", "oro": "cristal"}},
}


## Pone el catalogo de una partida: lo de serie, el estilo ("preset") y lo del juego encima.
static func apply(level: Dictionary) -> void:
	units = UNITS.duplicate(true)
	builds = BUILD.duplicate(true)
	age_cost = AGE_COST.duplicate(true)
	res_names = {}
	var extra: Variant = level.get("empire", {})
	if not (extra is Dictionary):
		return
	var layers: Array = []
	var pr: Variant = (extra as Dictionary).get("preset", "")
	for p: Variant in (pr if pr is Array else [pr]):
		if PRESETS.has(str(p)):
			layers.append(PRESETS[str(p)])
	layers.append(extra)
	for lay: Dictionary in layers:
		for sec: Array in [["units", units], ["builds", builds]]:
			var add: Variant = lay.get(sec[0], {})
			if add is Dictionary:
				for k: Variant in add:
					if (sec[1] as Dictionary).has(str(k)) and add[k] is Dictionary:
						(sec[1][str(k)] as Dictionary).merge(add[k], true)
		if lay.get("ages", null) is Array:
			for i: int in mini(4, (lay["ages"] as Array).size()):
				if lay["ages"][i] is Dictionary and i >= 2:
					age_cost[i] = (lay["ages"][i] as Dictionary).duplicate()
		if lay.get("res_names", null) is Dictionary:
			res_names.merge(lay["res_names"], true)


## Nombre de una tropa o edificio que trae el juego ("" si es el de serie).
static func custom_name(kind: String) -> String:
	var d: Dictionary = units.get(kind, builds.get(kind, {}))
	return str(d.get("name", ""))


const DIR8: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]


## Mejora de una tropa por la edad: +15 % de vida y de dano por cada edad despues de la primera.
static func age_mult(age: int) -> float:
	return 1.0 + 0.15 * float(maxi(age - 1, 0))


## Dano de un golpe de 'a' contra una tropa 'b' (o contra un edificio si b == "").
static func hit(a: String, b: String, age: int) -> float:
	var u: Dictionary = units[a]
	var d: float = float(u["dmg"]) * age_mult(age)
	if b == "":
		return d * float(u.get("bld", 0.5))
	if bool(u.get("only_bld", false)):
		return 0.0
	d *= float((u.get("bonus", {}) as Dictionary).get(b, 1.0))
	if bool(u.get("arrow", false)):
		d *= float(units[b].get("pierce", 1.0))
	return d


## Dano de una flecha de torre o centro contra una tropa.
static func arrow_hit(dmg: float, b: String) -> float:
	return dmg * float(units[b].get("pierce", 1.0))


static func can_pay(stock: Dictionary, cost: Dictionary) -> bool:
	for k: Variant in cost:
		if float(stock.get(k, 0.0)) < float(cost[k]) - 0.001:
			return false
	return true


static func pay(stock: Dictionary, cost: Dictionary) -> void:
	for k: Variant in cost:
		stock[k] = float(stock.get(k, 0.0)) - float(cost[k])


## Edificios del mapa: [{"kind", "owner" (0 tu, 1 rival), "cell", "size"}] y el terreno.
static func parse(map: Array) -> Dictionary:
	var out: Array[Dictionary] = []
	var error: String = ""
	if map.is_empty():
		return {"buildings": out, "error": "empire_empty", "w": 0, "h": 0, "terrain": PackedByteArray()}
	var w: int = str(map[0]).length()
	var h: int = map.size()
	var terrain: PackedByteArray = PackedByteArray()
	terrain.resize(w * h)
	var used: Dictionary = {}
	for y: int in h:
		var row: String = str(map[y])
		if row.length() != w:
			error = "empire_bad_rows"
		for x: int in w:
			var ch: String = row[x] if x < row.length() else "."
			if TERRAIN.has(ch):
				terrain[y * w + x] = int(TERRAIN[ch])
				continue
			var kind: String = "centro" if ch == "P" else str(ENEMY_CHARS.get(ch, ""))
			if kind == "":
				error = "empire_bad_char"
				continue
			var s: int = int(builds[kind]["size"])
			for dy: int in s:
				for dx: int in s:
					var c: Vector2i = Vector2i(x + dx, y + dy)
					if c.x >= w or c.y >= h:
						error = "empire_outside"
					elif used.has(c) or ((dx != 0 or dy != 0) and str(map[c.y])[c.x] != "."):
						error = "empire_overlap"
					used[c] = true
			out.append({"kind": kind, "owner": 0 if ch == "P" else 1, "cell": Vector2i(x, y), "size": s})
	return {"buildings": out, "error": error, "w": w, "h": h, "terrain": terrain, "used": used}


## Casillas bloqueadas (terreno que no se pisa y edificios).
static func blocked_grid(w: int, h: int, terrain: PackedByteArray, used: Dictionary) -> PackedByteArray:
	var b: PackedByteArray = PackedByteArray()
	b.resize(w * h)
	for i: int in w * h:
		b[i] = 1 if terrain[i] != GRASS else 0
	for c: Variant in used:
		var v: Vector2i = c
		b[v.y * w + v.x] = 1
	return b


## Mapa de distancias (en pasos de 8 direcciones) hasta pegarse a alguna de las casillas 'goals'.
## Las casillas libres vecinas de un objetivo valen 0; -1 = no se llega.
static func field(w: int, h: int, blocked: PackedByteArray, goals: Array[Vector2i]) -> PackedInt32Array:
	var d: PackedInt32Array = PackedInt32Array()
	d.resize(w * h)
	d.fill(-1)
	var q: Array[Vector2i] = []
	for g: Vector2i in goals:
		if g.x >= 0 and g.y >= 0 and g.x < w and g.y < h and blocked[g.y * w + g.x] == 0 and d[g.y * w + g.x] != 0:
			d[g.y * w + g.x] = 0
			q.append(g)
		for dir: Vector2i in DIR8:
			var n: Vector2i = g + dir
			if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h:
				continue
			var i: int = n.y * w + n.x
			if blocked[i] == 0 and d[i] != 0:
				d[i] = 0
				q.append(n)
	var head: int = 0
	while head < q.size():
		var c: Vector2i = q[head]
		head += 1
		var dc: int = d[c.y * w + c.x]
		for dir: Vector2i in DIR8:
			var n: Vector2i = c + dir
			if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h:
				continue
			var i: int = n.y * w + n.x
			if blocked[i] != 0 or d[i] >= 0:
				continue
			## En diagonal solo si las dos casillas de los lados estan libres (no se cortan esquinas).
			if dir.x != 0 and dir.y != 0 and (blocked[c.y * w + n.x] != 0 or blocked[n.y * w + c.x] != 0):
				continue
			d[i] = dc + 1
			q.append(n)
	return d


## Hay sitio para un edificio de lado s con la esquina en c?
static func fits(w: int, h: int, blocked: PackedByteArray, c: Vector2i, s: int) -> bool:
	if c.x < 0 or c.y < 0 or c.x + s > w or c.y + s > h:
		return false
	for dy: int in s:
		for dx: int in s:
			if blocked[(c.y + dy) * w + c.x + dx] != 0:
				return false
	return true


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var p: Dictionary = parse(level.get("map", []))
	var w: int = int(p["w"])
	var h: int = int(p["h"])
	if str(p["error"]) != "":
		issues.append(str(p["error"]))
	if w < 14 or w > 28 or h < 16 or h > 34:
		issues.append("empire_size")
	var mine: Array[Dictionary] = []
	var rivals: Array[Dictionary] = []
	var enemy_n: int = 0
	for b: Dictionary in p["buildings"]:
		if int(b["owner"]) == 0:
			mine.append(b)
		else:
			enemy_n += 1
			if str(b["kind"]) == "centro":
				rivals.append(b)
	if mine.size() != 1:
		issues.append("empire_one_player")
	if rivals.is_empty():
		issues.append("empire_no_enemy")
	if not issues.is_empty():
		return {"completable": false, "issues": issues, "coins_total": enemy_n, "enemies": 0, "enemy_problems": []}
	var terrain: PackedByteArray = p["terrain"]
	var blocked: PackedByteArray = blocked_grid(w, h, terrain, p["used"])
	var home: Dictionary = mine[0]
	var hc: Vector2i = home["cell"]
	var home_cells: Array[Vector2i] = []
	for dy: int in 3:
		for dx: int in 3:
			home_cells.append(hc + Vector2i(dx, dy))
	var from_home: PackedInt32Array = field(w, h, blocked, home_cells)
	## 2 y 3 - A cada centro rival se llega, y no esta pegado.
	for r: Dictionary in rivals:
		var rc: Vector2i = r["cell"]
		var best: int = -1
		for dy: int in range(-1, 4):
			for dx: int in range(-1, 4):
				var c: Vector2i = rc + Vector2i(dx, dy)
				if c.x < 0 or c.y < 0 or c.x >= w or c.y >= h:
					continue
				var v: int = from_home[c.y * w + c.x]
				if v >= 0 and (best < 0 or v < best):
					best = v
		if best < 0:
			issues.append("empire_unreachable")
		elif best < 10:
			issues.append("empire_close")
	## 4 - Recursos que se pueden recoger cerca de casa (a 9 pasos o menos).
	var near: Dictionary = {"comida": 0.0, "madera": 0.0, "oro": 0.0}
	for y: int in h:
		for x: int in w:
			var t: int = terrain[y * w + x]
			if not NODE_RES.has(t):
				continue
			var ok: bool = false
			for dir: Vector2i in DIR8:
				var n: Vector2i = Vector2i(x, y) + dir
				if n.x >= 0 and n.y >= 0 and n.x < w and n.y < h:
					var v: int = from_home[n.y * w + n.x]
					if v >= 0 and v <= 9:
						ok = true
						break
			if ok:
				near[NODE_RES[t]] = float(near[NODE_RES[t]]) + float(NODE_AMOUNT[t])
	if float(near["madera"]) < 800.0:
		issues.append("empire_few_wood")
	if float(near["comida"]) < 360.0:
		issues.append("empire_few_food")
	if float(near["oro"]) < 480.0:
		issues.append("empire_few_gold")
	var spots: int = 0
	for y: int in range(0, h - 1, 2):
		for x: int in range(0, w - 1, 2):
			var c: Vector2i = Vector2i(x, y)
			if fits(w, h, blocked, c, 2):
				var v: int = from_home[y * w + x]
				if v >= 0 and v <= 8:
					spots += 1
	if spots < 8:
		issues.append("empire_no_space")
	var ai: Dictionary = level.get("ai", {})
	if float(ai.get("income", 1.0)) <= 0.0 or float(ai.get("income", 1.0)) > 4.0:
		issues.append("empire_ai")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": enemy_n, "enemies": rivals.size(),
		"enemy_problems": [], "resources": near, "spots": spots}
