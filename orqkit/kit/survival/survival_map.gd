extends RefCounted
## Supervivencia 2D vista desde arriba: una isla con hambre y sed, recoger, fabricar, hoguera y
## noches con lobos. Simulacion pura: la usan el juego (survival_game.gd), el bot y el analizador.
## Coordenadas en casillas (1 = una casilla); el centro de la casilla (x, y) es (x + 0,5, y + 0,5).
## 1 - Mapa (game.json -> levels[i].map): "~" mar, "." hierba, "," arena, "T" arbol (madera),
##     "R" roca (piedra), "G" hierba alta (fibra), "B" arbusto de bayas (comida), "W" charca (agua
##     dulce), "D" guarida de lobos, "X" restos del naufragio (botin), "P" salida; "#semilla".
## 2 - Parametros: "goal" ("noches" o "balsa"), "nights" (1-6), "day" y "night" (segundos),
##     "wolves" (lobos por guarida y noche), "hunger" y "thirst" (puntos por segundo), "raft"
##     ([madera, fibra] de la balsa).
## 3 - USAR hace lo que toca segun lo que tengas al lado: golpear al lobo, beber de la charca,
##     echar lena a la hoguera o recoger (arbol, roca, hierba alta, bayas, restos); recoger sigue
##     solo hasta agotarlo o hasta que te mueves. COMER: una baya. FABRICAR: hacha, lanza, hoguera
##     y balsa. Los lobos salen de noche y no se acercan a una hoguera encendida.
## 4 - Plantilla por datos (levels[i].survival, ver DEFAULT_CAT): objetos, recursos del mapa,
##     recetas, herramientas que se gastan, criaturas (lobos de noche, zombis siempre, presas que
##     huyen), comida cruda que se cocina en la hoguera (cruda enferma), frio de noche, mochila
##     limitada, construcciones (muros que las criaturas no cruzan, mesa de trabajo) y metas por
##     receta ("win"). Sin "survival" todo es como siempre (los valores de abajo).

const SPEED: float = 3.6
const PLAYER_R: float = 0.32
const WOLF_SPEED: float = 3.0
const WOLF_HP: float = 50.0
const WOLF_BITE: float = 10.0
const BITE_CD: float = 1.3
const PUNCH: float = 10.0
const SPEAR: float = 30.0
const HIT_CD: float = 0.55
const REACH: float = 1.6
const FIRE_R: float = 3.6
const FIRE_START: float = 70.0
const FIRE_MAX: float = 150.0
const WOOD_FUEL: float = 35.0
const BERRY_FOOD: float = 22.0
const BERRY_REGROW: float = 25.0
const WALK: String = ".,GP"
const YIELD: Dictionary = {"T": 4, "R": 3, "G": 2, "B": 3, "X": 1}
const ITEM_OF: Dictionary = {"T": "wood", "R": "stone", "G": "fiber", "B": "berry"}
const GATHER_T: Dictionary = {"T": 1.1, "R": 1.4, "G": 0.5, "B": 0.4, "X": 1.0}
const CRATE: Dictionary = {"wood": 3, "fiber": 2, "berry": 2}
const RECIPES: Dictionary = {"hacha": {"wood": 3, "stone": 2, "fiber": 2}, "lanza": {"wood": 3, "stone": 1, "fiber": 2},
	"hoguera": {"wood": 4, "stone": 3}}
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
## Catalogo por defecto (la isla de siempre). Un nivel lo cambia con "survival": {"items": ...,
## "tiles": ..., "recipes": ..., "creatures": ..., "cold": 0.0, "bag": 0, "tool_uses": 0}; cada
## seccion se mezcla por clave con esta (lo que no se dice, se queda).
## items: food/water/heal (al comer), fuel (lena), cook (en que se convierte en la hoguera),
##   sick (segundos enfermo si se come asi).
## tiles: walk, item + yield + time (+ tool: herramienta que lo acelera, regrow: vuelve a salir),
##   loot ({objeto: n} al abrirlo; keep: se queda al vaciarlo), needs (herramienta sin la que no se
##   puede), water (se bebe), den (criatura que sale de ahi), herd (presas).
## recipes: cost, y lo que da: tool ({gather, dmg}), fire, build (pieza en la casilla de delante),
##   item ({objeto: n}), win (acabar la partida ganando); station: "fire" o una construccion cerca.
## creatures: hp, dmg, speed, when ("night" o "always"), hostile, fear_fire, flee, drops, y para
##   dibujarla look ("wolf", "zombie", "beast") y color.
## Para dibujar: cada casilla puede llevar look (como cual de las de siempre se dibuja: T, R, G,
##   B, D, X, o H casa en ruinas, C coche) y tint (color); palette {ground, sand, sea}; names
##   {id: "nombre"} para lo que no tenga texto propio (sv_<id>).
const DEFAULT_CAT: Dictionary = {
	"items": {"wood": {"fuel": 35.0}, "stone": {}, "fiber": {}, "berry": {"food": 22.0},
		"meat": {"food": 12.0, "sick": 18.0, "cook": "cooked"}, "cooked": {"food": 45.0}},
	"tiles": {
		"T": {"item": "wood", "yield": 4, "time": 1.1, "tool": "hacha"},
		"R": {"item": "stone", "yield": 3, "time": 1.4, "tool": "hacha"},
		"G": {"item": "fiber", "yield": 2, "time": 0.5, "walk": true},
		"B": {"item": "berry", "yield": 3, "time": 0.4, "regrow": 25.0},
		"X": {"loot": {"wood": 3, "fiber": 2, "berry": 2}, "yield": 1, "time": 1.0},
		"W": {"water": true},
		"D": {"den": "wolf"},
		".": {"walk": true}, ",": {"walk": true}, "P": {"walk": true}, "~": {}},
	"recipes": {"hacha": {"cost": {"wood": 3, "stone": 2, "fiber": 2}, "tool": {"gather": 0.5}},
		"lanza": {"cost": {"wood": 3, "stone": 1, "fiber": 2}, "tool": {"dmg": 30.0}},
		"hoguera": {"cost": {"wood": 4, "stone": 3}, "fire": true}},
	"creatures": {"wolf": {"hp": 50.0, "dmg": 10.0, "speed": 3.0, "when": "night", "hostile": true, "fear_fire": true, "drops": {}}},
	"cold": 0.0, "bag": 0, "tool_uses": 0, "palette": {}, "names": {}}
## Estilos ya hechos ("survival": {"preset": "zombis"}): se ponen encima del de por defecto y lo
## que traiga el nivel va encima de ellos. null en una receta, criatura u objeto la quita.
##   zombis: apocalipsis (casas "H" y coches "C" para saquear, zombis "Z" que no temen al fuego y
##     salen siempre, ciervos "A", chatarra, tela, latas, vendas, machete, muros y una radio).
##   invierno: frio de noche (hoguera, cama o abrigo de piel), ciervos "A" que dan carne y piel.
##   caza: selva con ciervos "A" y jabalies "J" (guarida) que embisten; la carne cruda enferma.
const PRESETS: Dictionary = {
	"zombis": {
		"items": {"scrap": {}, "cloth": {}, "can": {"food": 30.0, "water": 10.0}, "venda": {"heal": 40.0}},
		"tiles": {"H": {"loot": {"can": 1, "cloth": 1, "scrap": 1}, "yield": 3, "time": 1.2, "look": "H", "keep": true},
			"C": {"loot": {"scrap": 2, "cloth": 1}, "yield": 2, "time": 1.4, "look": "C", "keep": true},
			"Z": {"den": "zombie", "look": "D", "tint": "#5f7f4f"}, "A": {"walk": true, "herd": "deer"}},
		"recipes": {"lanza": null, "machete": {"cost": {"wood": 2, "scrap": 2, "fiber": 1}, "tool": {"dmg": 40.0}},
			"venda": {"cost": {"cloth": 2}, "item": {"venda": 1}}, "muro": {"cost": {"wood": 3}, "build": "muro"},
			"radio": {"cost": {"scrap": 5, "cloth": 2, "wood": 3}, "win": true}},
		"creatures": {"zombie": {"hp": 40.0, "dmg": 12.0, "speed": 1.9, "when": "always", "hostile": true, "fear_fire": false,
			"drops": {"cloth": 1}, "look": "zombie", "color": "#7da36a"},
			"deer": {"hp": 25.0, "dmg": 0.0, "speed": 3.2, "when": "always", "hostile": false, "flee": true, "drops": {"meat": 2},
				"look": "beast", "color": "#b07a4a"}},
		"bag": 30, "tool_uses": 40, "palette": {"ground": "#7f9a5c", "sand": "#cbb98a"}},
	"invierno": {
		"items": {"fur": {}},
		"tiles": {"A": {"walk": true, "herd": "deer"}, "T": {"item": "wood", "yield": 4, "time": 1.1, "tool": "hacha", "tint": "#2e5d4b"},
			"B": {"item": "berry", "yield": 2, "time": 0.4, "regrow": 35.0, "tint": "#5c7a8a"}},
		"recipes": {"abrigo": {"cost": {"fur": 2, "fiber": 2}, "tool": {"warm": 0.35}}},
		"creatures": {"deer": {"hp": 25.0, "dmg": 0.0, "speed": 3.2, "when": "always", "hostile": false, "flee": true,
			"drops": {"meat": 2, "fur": 1}, "look": "beast", "color": "#a07850"}},
		"cold": 2.0, "palette": {"ground": "#dfe7ee", "sand": "#c7d1da", "sea": "#2c5d7c"}},
	"caza": {
		"tiles": {"A": {"walk": true, "herd": "deer"}, "J": {"den": "boar", "look": "D", "tint": "#6b4a2b"}},
		"creatures": {"deer": {"hp": 25.0, "dmg": 0.0, "speed": 3.2, "when": "always", "hostile": false, "flee": true, "drops": {"meat": 2},
			"look": "beast", "color": "#b07a4a"},
			"boar": {"hp": 45.0, "dmg": 9.0, "speed": 2.6, "when": "night", "hostile": true, "fear_fire": true, "drops": {"meat": 3},
				"look": "beast", "color": "#5a3d2b"}},
		"palette": {"ground": "#4f9a3e", "sand": "#d9c27e"}},
}
## Construcciones que se pueden levantar con "build" (muro: no lo cruza nadie; puerta: solo tu).
const BUILDS: Dictionary = {"muro": {"block": true}, "puerta": {"block": true, "door": true}, "mesa": {"block": true, "station": true},
	"cama": {"block": false, "warm": true}}


## Catalogo del nivel: el de por defecto con lo que traiga "survival" encima (por clave).
static func catalog(level: Dictionary) -> Dictionary:
	var cat: Dictionary = DEFAULT_CAT.duplicate(true)
	var extra: Variant = level.get("survival", {})
	if extra is Dictionary:
		## "preset": un estilo o varios ("zombis" o ["zombis", "invierno"]), en ese orden.
		var pr: Variant = (extra as Dictionary).get("preset", "")
		for p: Variant in (pr if pr is Array else [pr]):
			if PRESETS.has(str(p)):
				_merge_cat(cat, PRESETS[str(p)])
		_merge_cat(cat, extra)
	return cat


static func _merge_cat(cat: Dictionary, extra: Dictionary) -> void:
	for sec: String in ["items", "tiles", "recipes", "creatures"]:
		var add: Variant = (extra as Dictionary).get(sec, {})
		if add is Dictionary:
			for k: Variant in add:
				if add[k] is Dictionary:
					cat[sec][str(k)] = (add[k] as Dictionary).duplicate(true)
				elif add[k] == null:
					(cat[sec] as Dictionary).erase(str(k))
	for k3: String in ["palette", "names"]:
		if (extra as Dictionary).get(k3, null) is Dictionary:
			(cat[k3] as Dictionary).merge((extra as Dictionary)[k3], true)
	for k2: String in ["cold", "bag", "tool_uses"]:
		if (extra as Dictionary).has(k2):
			cat[k2] = (extra as Dictionary)[k2]


static func parse(level: Dictionary) -> Dictionary:
	var rows: Array[String] = []
	var seed_v: int = int(level.get("seed", 1))
	for r: Variant in level.get("map", []):
		var t: String = str(r)
		if t.begins_with("#") and t.substr(1).is_valid_int():
			seed_v = int(t.substr(1))
		elif t != "":
			rows.append(t)
	if rows.size() < 5:
		rows = ["~~~~~~~~~~~", "~,,,,,,,,,~", "~,..T.R..,~", "~,.G.B.W.,~", "~,..P....,~", "~,.T...G.,~", "~,,,,D,,,,~", "~~~~~~~~~~~"]
	return {"rows": rows, "seed": seed_v}


static func new_state(level: Dictionary) -> Dictionary:
	var info: Dictionary = parse(level)
	var rows: Array[String] = info["rows"]
	var h: int = rows.size()
	var w: int = 0
	for r: String in rows:
		w = maxi(w, r.length())
	var cat: Dictionary = catalog(level)
	var tiles: Dictionary = cat["tiles"]
	var grid: Array = []
	var res: Dictionary = {}
	var ponds: Array[Vector2i] = []
	var dens: Array[Vector2i] = []
	var herds: Array[Vector2i] = []
	var start: Vector2i = Vector2i(w / 2, h / 2)
	for y: int in h:
		var line: Array[String] = []
		for x: int in w:
			var ch: String = rows[y][x] if x < rows[y].length() else "~"
			if ch == "P":
				start = Vector2i(x, y)
				ch = "."
			var td: Dictionary = tiles.get(ch, {})
			if td.has("item") or td.has("loot"):
				res[Vector2i(x, y)] = {"kind": ch, "left": int(td.get("yield", 1)), "regrow": 0.0}
			elif bool(td.get("water", false)):
				ponds.append(Vector2i(x, y))
			elif td.has("den"):
				dens.append(Vector2i(x, y))
			if td.has("herd"):
				herds.append(Vector2i(x, y))
			line.append(ch)
		grid.append(line)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(info["seed"])
	var raft: Array = level.get("raft", [12, 8])
	var inv: Dictionary = {}
	for it: String in cat["items"]:
		inv[it] = 0
	## La balsa de siempre es una receta que gana; otras metas son recetas con "win".
	if str(level.get("goal", "noches")) == "balsa" and not (cat["recipes"] as Dictionary).has("balsa"):
		cat["recipes"]["balsa"] = {"cost": {"wood": int(raft[0]) if raft.size() > 0 else 12, "fiber": int(raft[1]) if raft.size() > 1 else 8}, "win": true}
	var st: Dictionary = {"grid": grid, "w": w, "h": h, "res": res, "ponds": ponds, "dens": dens, "start": start, "rng": rng,
		"t": 0.0, "over": false, "won": false, "cause": "", "events": [],
		"goal": str(level.get("goal", "noches")) if str(level.get("goal", "noches")) in ["balsa", "receta"] else "noches", "cat": cat, "herds": herds, "built": {},
		"nights": clampi(int(level.get("nights", 2)), 1, 6), "day": clampf(float(level.get("day", 60.0)), 25.0, 240.0),
		"night": clampf(float(level.get("night", 35.0)), 15.0, 120.0), "wolves": clampi(int(level.get("wolves", 1)), 0, 5),
		"hunger_rate": clampf(float(level.get("hunger", 0.55)), 0.1, 2.0), "thirst_rate": clampf(float(level.get("thirst", 0.8)), 0.1, 2.0),
		"raft": {"wood": int(raft[0]) if raft.size() > 0 else 12, "fiber": int(raft[1]) if raft.size() > 1 else 8},
		"night_i": 0, "survived": 0, "is_night": false,
		"me": {"p": Vector2(start) + Vector2(0.5, 0.5), "face": Vector2.DOWN, "hp": 100.0, "food": 100.0, "water": 100.0,
			"inv": inv, "tools": {}, "hit_cd": 0.0, "job": {}, "hurt": 0.0, "warm": 100.0, "sick": 0.0},
		"wolves_list": [], "fire": {}, "flow": {}, "flow_t": 0.0, "wolf_n": 0, "bot": {}}
	start_creatures(st)
	return st


static func _ev(st: Dictionary, kind: String, extra: Dictionary = {}) -> void:
	var e: Dictionary = {"kind": kind}
	e.merge(extra)
	(st["events"] as Array).append(e)


# ------------------------------------------------------------------ casillas

static func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x)), int(floor(p.y)))


static func center(c: Vector2i) -> Vector2:
	return Vector2(c) + Vector2(0.5, 0.5)


static func tile(st: Dictionary, c: Vector2i) -> String:
	if c.x < 0 or c.y < 0 or c.x >= int(st["w"]) or c.y >= int(st["h"]):
		return "~"
	return str(st["grid"][c.y][c.x])


static func walkable(st: Dictionary, c: Vector2i) -> bool:
	if not bool((st["cat"]["tiles"] as Dictionary).get(tile(st, c), {}).get("walk", false)):
		return false
	var b: String = str((st["built"] as Dictionary).get(c, ""))
	return b == "" or not bool(BUILDS[b]["block"]) or bool(BUILDS[b].get("door", false))


## Las criaturas tampoco cruzan puertas.
static func creature_walkable(st: Dictionary, c: Vector2i) -> bool:
	if not walkable(st, c):
		return false
	var b: String = str((st["built"] as Dictionary).get(c, ""))
	return b == "" or not bool(BUILDS[b]["block"])


## Datos de una casilla del catalogo ({} si no tiene nada especial).
static func tile_def(st: Dictionary, kind: String) -> Dictionary:
	return (st["cat"]["tiles"] as Dictionary).get(kind, {})


## Como se dibuja una casilla (la letra de siempre si no dice "look").
static func look(st: Dictionary, kind: String) -> String:
	return str(tile_def(st, kind).get("look", kind))


static func tint(st: Dictionary, kind: String, fallback: Color) -> Color:
	var t: String = str(tile_def(st, kind).get("tint", ""))
	return Color.from_string(t, fallback) if t != "" else fallback


static func pal(st: Dictionary, key: String, fallback: Color) -> Color:
	var t: String = str((st["cat"]["palette"] as Dictionary).get(key, ""))
	return Color.from_string(t, fallback) if t != "" else fallback


static func tile_yield(st: Dictionary, kind: String) -> int:
	return maxi(1, int(tile_def(st, kind).get("yield", 1)))


static func item_def(st: Dictionary, item: String) -> Dictionary:
	return (st["cat"]["items"] as Dictionary).get(item, {})


## Cuantas cosas llevas (para la mochila).
static func carried(st: Dictionary) -> int:
	var n: int = 0
	for k: String in st["me"]["inv"]:
		n += int(st["me"]["inv"][k])
	return n


static func bag_full(st: Dictionary) -> bool:
	return int(st["cat"]["bag"]) > 0 and carried(st) >= int(st["cat"]["bag"])


## Mete objetos en la mochila (lo que no cabe se pierde). Devuelve cuantos entraron.
static func give(st: Dictionary, item: String, n: int) -> int:
	var inv: Dictionary = st["me"]["inv"]
	var room: int = n if int(st["cat"]["bag"]) <= 0 else clampi(int(st["cat"]["bag"]) - carried(st), 0, n)
	inv[item] = int(inv.get(item, 0)) + room
	return room


## Mover un cuerpo redondo resbalando por las casillas que no se pisan.
static func _slide(st: Dictionary, p: Vector2, d: Vector2, r: float, creature: bool = false) -> Vector2:
	var nx: Vector2 = Vector2(p.x + d.x, p.y)
	if _free(st, nx, r, creature):
		p = nx
	var ny: Vector2 = Vector2(p.x, p.y + d.y)
	if _free(st, ny, r, creature):
		p = ny
	return p


static func _free(st: Dictionary, p: Vector2, r: float, creature: bool = false) -> bool:
	for o: Vector2 in [Vector2(-r, -r), Vector2(r, -r), Vector2(-r, r), Vector2(r, r)]:
		var c: Vector2i = cell_of(p + o)
		if not (creature_walkable(st, c) if creature else walkable(st, c)):
			return false
	return true


static func is_night_at(st: Dictionary, t: float) -> bool:
	var cyc: float = float(st["day"]) + float(st["night"])
	return fmod(t, cyc) >= float(st["day"])


## Segundos que faltan para que se haga de noche (0 si ya es de noche).
static func to_night(st: Dictionary) -> float:
	var cyc: float = float(st["day"]) + float(st["night"])
	var f: float = fmod(float(st["t"]), cyc)
	return maxf(0.0, float(st["day"]) - f)


## Segundos que faltan para que amanezca (0 si es de dia).
static func to_dawn(st: Dictionary) -> float:
	var cyc: float = float(st["day"]) + float(st["night"])
	var f: float = fmod(float(st["t"]), cyc)
	return maxf(0.0, cyc - f) if f >= float(st["day"]) else 0.0


static func fire_on(st: Dictionary) -> bool:
	var f: Dictionary = st["fire"]
	return not f.is_empty() and float(f["fuel"]) > 0.0


static func in_light(st: Dictionary, p: Vector2, margin: float = 0.0) -> bool:
	return fire_on(st) and p.distance_to(st["fire"]["p"]) < FIRE_R - margin


# ------------------------------------------------------------------ paso

## inp: {"move": Vector2 (0..1), "use": bool, "eat": bool, "craft": id de receta (hacha, lanza, hoguera, balsa...),
##       "want": {"what": "drink" | "gather", "cell": Vector2i} (opcional: que hacer con USAR si se puede)}.
static func step(st: Dictionary, inp: Dictionary, dt: float) -> void:
	if bool(st["over"]):
		return
	st["t"] = float(st["t"]) + dt
	var me: Dictionary = st["me"]
	_cycle(st)
	## Mover (y moverse corta lo que estuvieras recogiendo).
	var mv: Vector2 = inp.get("move", Vector2.ZERO)
	if mv.length() > 1.0:
		mv = mv.normalized()
	if mv.length() > 0.15:
		me["face"] = mv.normalized()
		me["p"] = _slide(st, me["p"], mv * SPEED * dt, PLAYER_R)
		if not (me["job"] as Dictionary).is_empty():
			me["job"] = {}
	if str(inp.get("craft", "")) != "":
		craft(st, str(inp["craft"]))
	if bool(inp.get("eat", false)):
		eat(st)
	if str(inp.get("drop", "")) != "":
		drop(st, str(inp["drop"]), int(inp.get("drop_n", 1)))
	if bool(inp.get("use", false)):
		use(st, inp.get("want", {}))
	me["hit_cd"] = maxf(0.0, float(me["hit_cd"]) - dt)
	me["hurt"] = maxf(0.0, float(me["hurt"]) - dt)
	_job(st, dt)
	_needs(st, dt)
	_fire(st, dt)
	_regrow(st, dt)
	_wolves(st, dt)
	_prey_respawn(st, dt)
	if float(me["hp"]) <= 0.0 and not bool(st["over"]):
		_end(st, false, str(st.get("last_hurt", "hambre")))


static func _cycle(st: Dictionary) -> void:
	var night: bool = is_night_at(st, float(st["t"]))
	if night and not bool(st["is_night"]):
		st["is_night"] = true
		st["night_i"] = int(st["night_i"]) + 1
		_ev(st, "night", {"n": int(st["night_i"])})
		_spawn_wolves(st)
	elif not night and bool(st["is_night"]):
		st["is_night"] = false
		st["survived"] = int(st["survived"]) + 1
		_ev(st, "dawn", {"n": int(st["survived"])})
		for wf: Dictionary in st["wolves_list"]:
			if str(creature(st, wf).get("when", "night")) == "night":
				wf["leaving"] = true
		if str(st["goal"]) == "noches" and int(st["survived"]) >= int(st["nights"]):
			_end(st, true, "noches")


static func _end(st: Dictionary, won: bool, cause: String) -> void:
	st["over"] = true
	st["won"] = won
	st["cause"] = cause
	_ev(st, "end", {"won": won, "cause": cause})


static func _needs(st: Dictionary, dt: float) -> void:
	var me: Dictionary = st["me"]
	me["food"] = maxf(0.0, float(me["food"]) - float(st["hunger_rate"]) * dt)
	me["water"] = maxf(0.0, float(me["water"]) - float(st["thirst_rate"]) * dt)
	var hp: float = float(me["hp"])
	if float(me["food"]) <= 0.0:
		hp -= 3.0 * dt
		st["last_hurt"] = "hambre"
	if float(me["water"]) <= 0.0:
		hp -= 3.0 * dt
		st["last_hurt"] = "sed"
	## Frio (si el nivel lo tiene): de noche baja el calor; la hoguera y la cama lo devuelven.
	var cold: float = float(st["cat"]["cold"])
	for tl: String in me["tools"]:
		var wm: float = float(recipe_def(st, tl).get("tool", {}).get("warm", 1.0))
		cold *= wm
	if cold > 0.0:
		var warm_src: bool = in_light(st, me["p"]) or _near_build(st, me["p"], "cama", 1.5)
		if warm_src:
			me["warm"] = minf(100.0, float(me["warm"]) + 8.0 * dt)
		elif bool(st["is_night"]):
			me["warm"] = maxf(0.0, float(me["warm"]) - cold * dt)
		else:
			me["warm"] = maxf(0.0, float(me["warm"]) - cold * 0.25 * dt)
		if float(me["warm"]) <= 0.0:
			hp -= 3.0 * dt
			st["last_hurt"] = "frio"
	## Enfermo (comida cruda): pierde vida mientras dure.
	if float(me["sick"]) > 0.0:
		me["sick"] = maxf(0.0, float(me["sick"]) - dt)
		hp -= 1.0 * dt
		st["last_hurt"] = "enfermo"
	if float(me["food"]) > 40.0 and float(me["water"]) > 40.0 and float(me["sick"]) <= 0.0 and float(me["warm"]) > 20.0:
		hp = minf(100.0, hp + 1.2 * dt)
	me["hp"] = hp


static func _fire(st: Dictionary, dt: float) -> void:
	var f: Dictionary = st["fire"]
	if f.is_empty():
		return
	var before: bool = float(f["fuel"]) > 0.0
	f["fuel"] = maxf(0.0, float(f["fuel"]) - dt)
	if before and float(f["fuel"]) <= 0.0:
		_ev(st, "fire_out")


static func _regrow(st: Dictionary, dt: float) -> void:
	for c: Vector2i in st["res"]:
		var r: Dictionary = st["res"][c]
		var td: Dictionary = tile_def(st, str(r["kind"]))
		if td.has("regrow") and int(r["left"]) < tile_yield(st, str(r["kind"])):
			r["regrow"] = float(r["regrow"]) + dt
			if float(r["regrow"]) >= float(td["regrow"]):
				r["regrow"] = 0.0
				r["left"] = int(r["left"]) + 1
				_ev(st, "regrow", {"cell": c})


# ------------------------------------------------------------------ acciones

static func has(st: Dictionary, cost: Dictionary) -> bool:
	var inv: Dictionary = st["me"]["inv"]
	for k: String in cost:
		if int(inv.get(k, 0)) < int(cost[k]):
			return false
	return true


## Coste de una receta ({} si no existe).
static func recipe(st: Dictionary, id: String) -> Dictionary:
	return (st["cat"]["recipes"] as Dictionary).get(id, {}).get("cost", {})


static func recipe_def(st: Dictionary, id: String) -> Dictionary:
	return (st["cat"]["recipes"] as Dictionary).get(id, {})


## Recetas en el orden del catalogo (para los botones del juego).
static func recipe_ids(st: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for k: String in st["cat"]["recipes"]:
		out.append(k)
	return out


static func is_tool_recipe(st: Dictionary, id: String) -> bool:
	return recipe_def(st, id).has("tool")


## Esta cerca lo que pide la receta (hoguera encendida o una construccion)?
static func station_ok(st: Dictionary, id: String) -> bool:
	var need: String = str(recipe_def(st, id).get("station", ""))
	if need == "":
		return true
	if need == "fire":
		return fire_on(st) and (st["me"]["p"] as Vector2).distance_to(st["fire"]["p"]) < FIRE_R
	return _near_build(st, st["me"]["p"], need, 2.6)


static func _near_build(st: Dictionary, p: Vector2, kind: String, r: float) -> bool:
	for c: Vector2i in st["built"]:
		if str(st["built"][c]) == kind and center(c).distance_to(p) <= r:
			return true
	return false


## Casilla donde se levantaria una construccion (la de delante); (-1, -1) si no se puede.
static func build_cell(st: Dictionary) -> Vector2i:
	var me: Dictionary = st["me"]
	var p: Vector2 = me["p"]
	var c: Vector2i = cell_of(p + (me["face"] as Vector2) * 1.0)
	if c == cell_of(p) or not walkable(st, c) or (st["built"] as Dictionary).has(c) or (st["res"] as Dictionary).has(c):
		return Vector2i(-1, -1)
	for wf: Dictionary in st["wolves_list"]:
		if cell_of(wf["p"]) == c:
			return Vector2i(-1, -1)
	return c


static func can_craft(st: Dictionary, id: String) -> bool:
	var rd: Dictionary = recipe_def(st, id)
	if rd.is_empty():
		return false
	if rd.has("tool") and (st["me"]["tools"] as Dictionary).has(id):
		return false
	if rd.has("build") and build_cell(st).x < 0:
		return false
	var cost: Dictionary = rd.get("cost", {})
	return has(st, cost) and station_ok(st, id)


static func craft(st: Dictionary, id: String) -> bool:
	if not can_craft(st, id):
		return false
	var me: Dictionary = st["me"]
	var rd: Dictionary = recipe_def(st, id)
	var cost: Dictionary = rd.get("cost", {})
	for k: String in cost:
		me["inv"][k] = int(me["inv"][k]) - int(cost[k])
	if rd.has("tool"):
		me["tools"][id] = int(st["cat"]["tool_uses"]) if int(st["cat"]["tool_uses"]) > 0 else true
	if bool(rd.get("fire", false)):
		st["fire"] = {"p": me["p"], "fuel": FIRE_START}
	if rd.has("build"):
		var bc: Vector2i = build_cell(st)
		st["built"][bc] = str(rd["build"])
		st["flow_t"] = 0.0
		_ev(st, "build", {"cell": bc, "what": str(rd["build"])})
	var gives: Dictionary = rd.get("item", {})
	for it: String in gives:
		give(st, it, int(gives[it]))
	_ev(st, "craft", {"item": id})
	if bool(rd.get("win", false)):
		_end(st, true, id)
	return true


## Mejor cosa para comer ahora: lo que mas alimenta sin enfermar (si no hay, lo que haya).
static func best_food(st: Dictionary) -> String:
	var best: String = ""
	var bs: float = -INF
	for it: String in st["me"]["inv"]:
		var d: Dictionary = item_def(st, it)
		if int(st["me"]["inv"][it]) <= 0 or float(d.get("food", 0.0)) + float(d.get("heal", 0.0)) <= 0.0:
			continue
		var sc: float = float(d.get("food", 0.0)) - float(d.get("sick", 0.0)) * 4.0
		if sc > bs:
			bs = sc
			best = it
	return best


static func eat(st: Dictionary, what: String = "") -> bool:
	var me: Dictionary = st["me"]
	var it: String = what if what != "" else best_food(st)
	if it == "" or int(me["inv"].get(it, 0)) <= 0:
		return false
	var d: Dictionary = item_def(st, it)
	var heal: float = float(d.get("heal", 0.0))
	if float(me["food"]) >= 99.0 and heal <= 0.0:
		return false
	me["inv"][it] = int(me["inv"][it]) - 1
	me["food"] = minf(100.0, float(me["food"]) + float(d.get("food", 0.0)))
	me["water"] = minf(100.0, float(me["water"]) + float(d.get("water", 0.0)))
	if heal > 0.0:
		me["hp"] = minf(100.0, float(me["hp"]) + heal)
		me["sick"] = 0.0
	if float(d.get("sick", 0.0)) > 0.0:
		me["sick"] = float(me["sick"]) + float(d["sick"])
		_ev(st, "sick")
	_ev(st, "eat", {"item": it, "food": float(d.get("food", 0.0))})
	return true


## Tira cosas de la mochila (para hacer sitio). Devuelve cuantas.
static func drop(st: Dictionary, item: String, n: int = 1) -> int:
	var inv: Dictionary = st["me"]["inv"]
	var k: int = clampi(n, 0, int(inv.get(item, 0)))
	if k <= 0:
		return 0
	inv[item] = int(inv[item]) - k
	_ev(st, "drop", {"item": item, "n": k})
	return k


## Lo que mas sobra (lo que mas llevas de lo que no hace falta); "" si nada.
static func surplus(st: Dictionary, want: Dictionary = {}) -> String:
	var best: String = ""
	var bs: int = 0
	for it: String in st["me"]["inv"]:
		var extra: int = int(st["me"]["inv"][it]) - int(want.get(it, 0))
		if float(item_def(st, it).get("food", 0.0)) > 0.0:
			extra -= 2
		if extra > bs:
			bs = extra
			best = it
	return best


## Algo crudo que se puede cocinar (o "").
static func cookable(st: Dictionary) -> String:
	for it: String in st["me"]["inv"]:
		if int(st["me"]["inv"][it]) > 0 and str(item_def(st, it).get("cook", "")) != "":
			return it
	return ""


## Dano del mejor arma que llevas (o el punetazo).
static func weapon(st: Dictionary) -> Dictionary:
	var best: Dictionary = {"id": "", "dmg": PUNCH}
	for id: String in st["me"]["tools"]:
		var dmg: float = float(recipe_def(st, id).get("tool", {}).get("dmg", 0.0))
		if dmg > float(best["dmg"]):
			best = {"id": id, "dmg": dmg}
	return best


## Gasta un uso de una herramienta (si se gastan); se rompe al llegar a 0.
static func wear(st: Dictionary, id: String) -> void:
	var tools: Dictionary = st["me"]["tools"]
	if id == "" or not tools.has(id) or not (tools[id] is int):
		return
	tools[id] = int(tools[id]) - 1
	if int(tools[id]) <= 0:
		tools.erase(id)
		_ev(st, "tool_broke", {"item": id})


## Lo que hara USAR ahora mismo: "hit", "drink", "fuel", "gather" o "" (nada al lado).
## Por orden: golpear al lobo, beber si tienes sed, echar lena y recoger lo que tienes delante.
## want: lo que se quiere (el bot dice a que casilla va), si esta al alcance.
static func use_target(st: Dictionary, want: Dictionary = {}) -> Dictionary:
	var me: Dictionary = st["me"]
	var p: Vector2 = me["p"]
	if str(want.get("what", "")) == "gather" and want.has("cell"):
		var wc: Vector2i = want["cell"]
		if st["res"].has(wc) and int(st["res"][wc]["left"]) > 0 and p.distance_to(center(wc)) <= REACH:
			return {"what": "gather", "cell": wc}
	## Ir a beber manda (si no, junto a la hoguera USAR echaria lena y no beberia nunca).
	if str(want.get("what", "")) == "drink" and want.has("cell") and bool(tile_def(st, tile(st, want["cell"])).get("water", false)) \
			and p.distance_to(center(want["cell"])) <= REACH and float(me["water"]) < 97.0:
		return {"what": "drink", "cell": want["cell"]}
	var best_w: Dictionary = {}
	var bd: float = REACH
	for wf: Dictionary in st["wolves_list"]:
		var d: float = p.distance_to(wf["p"])
		if d < bd and not bool(wf.get("leaving", false)):
			bd = d
			best_w = wf
	if not best_w.is_empty():
		return {"what": "hit", "wolf": best_w}
	if fire_on(st) or not (st["fire"] as Dictionary).is_empty():
		if p.distance_to(st["fire"]["p"]) < REACH and fuel_item(st) != "" and float(st["fire"]["fuel"]) < FIRE_MAX - WOOD_FUEL * 0.5:
			return {"what": "fuel"}
		if fire_on(st) and p.distance_to(st["fire"]["p"]) < REACH and cookable(st) != "":
			return {"what": "cook"}
	var here: Vector2i = cell_of(p)
	var best: Dictionary = {}
	var bdist: float = INF
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			var c: Vector2i = here + Vector2i(dx, dy)
			if p.distance_to(center(c)) > REACH:
				continue
			var t: String = tile(st, c)
			var d2: float = p.distance_to(center(c)) - (me["face"] as Vector2).dot((center(c) - p).normalized()) * 0.3
			if bool(tile_def(st, t).get("water", false)) and float(me["water"]) < 97.0 and (d2 < bdist or float(me["water"]) < 90.0 or str(want.get("what", "")) == "drink"):
				bdist = -INF if float(me["water"]) < 90.0 or str(want.get("what", "")) == "drink" else d2
				best = {"what": "drink", "cell": c}
			elif st["res"].has(c) and int(st["res"][c]["left"]) > 0 and d2 < bdist:
				bdist = d2
				best = {"what": "gather", "cell": c}
	return best


## Lo que se puede echar al fuego (o "").
static func fuel_item(st: Dictionary) -> String:
	for it: String in st["me"]["inv"]:
		if int(st["me"]["inv"][it]) > 0 and float(item_def(st, it).get("fuel", 0.0)) > 0.0:
			return it
	return ""


static func use(st: Dictionary, want: Dictionary = {}) -> String:
	var me: Dictionary = st["me"]
	var tg: Dictionary = use_target(st, want)
	match str(tg.get("what", "")):
		"hit":
			if float(me["hit_cd"]) > 0.0:
				return ""
			me["hit_cd"] = HIT_CD
			var wf: Dictionary = tg["wolf"]
			var wp: Dictionary = weapon(st)
			wf["hp"] = float(wf["hp"]) - float(wp["dmg"])
			wear(st, str(wp["id"]))
			wf["stun"] = 0.35
			wf["p"] = _slide(st, wf["p"], ((wf["p"] as Vector2) - (me["p"] as Vector2)).normalized() * 0.6, 0.3, true)
			_ev(st, "hit_wolf", {"id": int(wf["id"]), "dead": float(wf["hp"]) <= 0.0, "kind": str(wf.get("kind", "wolf"))})
			if float(wf["hp"]) <= 0.0:
				(st["wolves_list"] as Array).erase(wf)
				var drops: Dictionary = creature(st, wf).get("drops", {})
				for it: String in drops:
					give(st, it, int(drops[it]))
				if not drops.is_empty():
					_ev(st, "loot", {"items": drops})
			return "hit"
		"drink":
			me["water"] = 100.0
			_ev(st, "drink")
			return "drink"
		"fuel":
			var fi: String = fuel_item(st)
			me["inv"][fi] = int(me["inv"][fi]) - 1
			st["fire"]["fuel"] = minf(FIRE_MAX, float(st["fire"]["fuel"]) + float(item_def(st, fi)["fuel"]))
			_ev(st, "fuel")
			return "fuel"
		"cook":
			var raw: String = cookable(st)
			var done: String = str(item_def(st, raw)["cook"])
			me["inv"][raw] = int(me["inv"][raw]) - 1
			me["inv"][done] = int(me["inv"].get(done, 0)) + 1
			_ev(st, "cook", {"item": done})
			return "cook"
		"gather":
			me["job"] = {"cell": tg["cell"], "t": 0.0}
			return "gather"
	return ""


## Recoger sigue solo: una unidad cada "time" de la casilla (menos con su herramienta).
static func _job(st: Dictionary, dt: float) -> void:
	var me: Dictionary = st["me"]
	var job: Dictionary = me["job"]
	if job.is_empty():
		return
	var c: Vector2i = job["cell"]
	if not st["res"].has(c) or int(st["res"][c]["left"]) <= 0 or (me["p"] as Vector2).distance_to(center(c)) > REACH + 0.1:
		me["job"] = {}
		return
	var r: Dictionary = st["res"][c]
	var kind: String = str(r["kind"])
	var td: Dictionary = tile_def(st, kind)
	if td.has("item") and bag_full(st):
		me["job"] = {}
		_ev(st, "bag_full")
		return
	var tool_id: String = str(td.get("tool", ""))
	var fast: bool = tool_id != "" and (me["tools"] as Dictionary).has(tool_id)
	var need: float = float(td.get("time", 1.0)) * (float(recipe_def(st, tool_id).get("tool", {}).get("gather", 1.0)) if fast else 1.0)
	## Sin la herramienta que pide ("needs"), no se puede.
	if str(td.get("needs", "")) != "" and not (me["tools"] as Dictionary).has(str(td["needs"])):
		me["job"] = {}
		_ev(st, "need_tool", {"item": str(td["needs"])})
		return
	job["t"] = float(job["t"]) + dt
	if float(job["t"]) < need:
		return
	job["t"] = 0.0
	r["left"] = int(r["left"]) - 1
	if fast:
		wear(st, tool_id)
	if td.has("loot"):
		var loot: Dictionary = td["loot"]
		for k: String in loot:
			give(st, k, int(loot[k]))
		_ev(st, "gather", {"item": "crate", "cell": c})
	else:
		var item: String = str(td["item"])
		give(st, item, 1)
		_ev(st, "gather", {"item": item, "cell": c})
	if int(r["left"]) <= 0:
		if not td.has("regrow"):
			## Arbol, roca, hierba o restos agotados: queda suelo (tocon, piedrecitas...); las casas
			## y coches ("keep") se quedan, ya saqueados.
			if not bool(td.get("keep", false)):
				st["grid"][c.y][c.x] = "."
			st["res"].erase(c)
			st["flow_t"] = 0.0
			_ev(st, "depleted", {"cell": c, "was": kind})
		me["job"] = {}


# ------------------------------------------------------------------ lobos

## Datos de la criatura (por su "kind"; los lobos de siempre si no lo dice).
static func creature(st: Dictionary, wf: Dictionary) -> Dictionary:
	return (st["cat"]["creatures"] as Dictionary).get(str(wf.get("kind", "wolf")), DEFAULT_CAT["creatures"]["wolf"])


static func den_kind(st: Dictionary, d: Vector2i) -> String:
	return str(tile_def(st, tile(st, d)).get("den", "wolf"))


## Al caer la noche salen de cada guarida (las de "always" salen tambien al empezar).
static func _spawn_wolves(st: Dictionary, at_start: bool = false) -> void:
	for d: Vector2i in st["dens"]:
		var kind: String = den_kind(st, d)
		var when: String = str((st["cat"]["creatures"] as Dictionary).get(kind, {}).get("when", "night"))
		if at_start and when != "always":
			continue
		for k: int in int(st["wolves"]):
			_spawn(st, kind, d)


static func _spawn(st: Dictionary, kind: String, home: Vector2i) -> void:
	var rng: RandomNumberGenerator = st["rng"]
	var cd: Dictionary = (st["cat"]["creatures"] as Dictionary).get(kind, DEFAULT_CAT["creatures"]["wolf"])
	var spot: Vector2 = center(home)
	if not creature_walkable(st, home):
		for dir: Vector2i in DIRS:
			if creature_walkable(st, home + dir):
				spot = center(home + dir)
				break
	spot += Vector2(rng.randf_range(-0.2, 0.2), rng.randf_range(-0.2, 0.2))
	st["wolf_n"] = int(st["wolf_n"]) + 1
	(st["wolves_list"] as Array).append({"id": int(st["wolf_n"]), "kind": kind, "p": spot, "home": home, "hp": float(cd.get("hp", WOLF_HP)),
		"cd": 0.5 + rng.randf(), "stun": 0.0, "wander": Vector2.ZERO, "wt": 0.0, "leaving": false})
	_ev(st, "wolf", {"id": int(st["wolf_n"]), "kind": kind})


## Presas que se fueron (cazadas) vuelven a salir en su prado cada cierto tiempo.
static func _prey_respawn(st: Dictionary, dt: float) -> void:
	var herds: Array = st["herds"]
	if herds.is_empty():
		return
	st["herd_t"] = float(st.get("herd_t", 0.0)) + dt
	if float(st["herd_t"]) < 40.0:
		return
	st["herd_t"] = 0.0
	var alive: int = 0
	for wf: Dictionary in st["wolves_list"]:
		if not bool(creature(st, wf).get("hostile", true)):
			alive += 1
	if alive >= herds.size():
		return
	for hc: Vector2i in herds:
		if center(hc).distance_to(st["me"]["p"]) > 6.0:
			_spawn(st, str(tile_def(st, tile(st, hc))["herd"]), hc)
			return


static func start_creatures(st: Dictionary) -> void:
	_spawn_wolves(st, true)
	for hc: Vector2i in st["herds"]:
		_spawn(st, str(tile_def(st, tile(st, hc))["herd"]), hc)
	(st["events"] as Array).clear()


## Mapa de pasos hasta ti (cada medio segundo): los lobos bajan por el.
static func _flow(st: Dictionary) -> Dictionary:
	var from: Vector2i = cell_of(st["me"]["p"])
	var dist: Dictionary = {from: 0}
	var q: Array[Vector2i] = [from]
	var i: int = 0
	while i < q.size():
		var c: Vector2i = q[i]
		i += 1
		if int(dist[c]) > 24:
			continue
		for d: Vector2i in DIRS:
			var n: Vector2i = c + d
			if not dist.has(n) and creature_walkable(st, n):
				dist[n] = int(dist[c]) + 1
				q.append(n)
	return dist


static func _wolves(st: Dictionary, dt: float) -> void:
	var list: Array = st["wolves_list"]
	if list.is_empty():
		return
	st["flow_t"] = float(st["flow_t"]) - dt
	if float(st["flow_t"]) <= 0.0:
		st["flow_t"] = 0.5
		st["flow"] = _flow(st)
	var flow: Dictionary = st["flow"]
	var me: Dictionary = st["me"]
	var mp: Vector2 = me["p"]
	var rng: RandomNumberGenerator = st["rng"]
	var gone: Array = []
	for wf: Dictionary in list:
		var p: Vector2 = wf["p"]
		var cdef: Dictionary = creature(st, wf)
		var spd: float = float(cdef.get("speed", WOLF_SPEED))
		var fear: bool = bool(cdef.get("fear_fire", true))
		wf["cd"] = maxf(0.0, float(wf["cd"]) - dt)
		if float(wf["stun"]) > 0.0:
			wf["stun"] = float(wf["stun"]) - dt
			continue
		var want: Vector2 = Vector2.ZERO
		if not bool(cdef.get("hostile", true)):
			## Presa: pace cerca de su prado y huye si te acercas.
			if p.distance_to(mp) < 3.5 and bool(cdef.get("flee", true)):
				want = (p - mp).normalized()
			else:
				wf["wt"] = float(wf["wt"]) - dt
				if float(wf["wt"]) <= 0.0:
					wf["wt"] = rng.randf_range(1.5, 3.0)
					var back: Vector2 = (center(wf["home"]) - p) * 0.15
					wf["wander"] = (Vector2.from_angle(rng.randf() * TAU) * 0.4 + back).limit_length(0.6)
				want = wf["wander"]
		elif bool(wf["leaving"]):
			## Amanece: vuelven a su guarida y desaparecen.
			want = (center(wf["home"]) - p)
			if want.length() < 1.2 or float(wf.get("gone_t", 0.0)) > 6.0:
				gone.append(wf)
				continue
			wf["gone_t"] = float(wf.get("gone_t", 0.0)) + dt
		else:
			var c: Vector2i = cell_of(p)
			var dist_me: float = p.distance_to(mp)
			if flow.has(c) and int(flow[c]) < 14:
				if int(flow[c]) <= 1:
					want = mp - p
				else:
					var best: Vector2i = c
					for d: Vector2i in DIRS:
						var n: Vector2i = c + d
						if flow.has(n) and int(flow[n]) < int(flow[best]):
							best = n
					want = center(best) - p
			else:
				## Lejos: merodean cerca de la guarida.
				wf["wt"] = float(wf["wt"]) - dt
				if float(wf["wt"]) <= 0.0:
					wf["wt"] = rng.randf_range(1.0, 2.5)
					wf["wander"] = Vector2.from_angle(rng.randf() * TAU) * 0.5
				want = wf["wander"]
			if dist_me < 0.85 and float(wf["cd"]) <= 0.0:
				wf["cd"] = BITE_CD
				me["hp"] = float(me["hp"]) - float(cdef.get("dmg", WOLF_BITE))
				me["hurt"] = 0.4
				me["job"] = {}
				st["last_hurt"] = "lobos" if str(wf.get("kind", "wolf")) == "wolf" else str(wf["kind"])
				_ev(st, "bite", {"id": int(wf["id"])})
		if want.length() > 0.001:
			var prey_m: float = 0.55 if not bool(cdef.get("hostile", true)) and want.length() < 0.99 else 1.0
			var stepv: Vector2 = want.normalized() * minf(spd * prey_m * dt, want.length() if bool(cdef.get("hostile", true)) else spd * dt)
			var np: Vector2 = _slide(st, p, stepv, 0.3, true)
			## La luz de la hoguera no la cruzan los que le tienen miedo (rondan en el borde).
			if fear and not bool(wf["leaving"]) and in_light(st, np) and not in_light(st, p):
				np = p
			elif fear and not bool(wf["leaving"]) and in_light(st, np) and in_light(st, p):
				## Pillado dentro cuando se encendio: sale hacia fuera.
				np = _slide(st, p, ((p - (st["fire"]["p"] as Vector2)).normalized()) * spd * dt, 0.3, true)
			wf["p"] = np
	for g: Dictionary in gone:
		list.erase(g)
		_ev(st, "wolf_gone", {"id": int(g["id"])})


# ------------------------------------------------------------------ caminos (bot)

## Camino por casillas hasta cualquiera de "goals" (la primera la mas cercana). [] si no hay.
static func path_to(st: Dictionary, goals: Dictionary) -> Array[Vector2i]:
	var from: Vector2i = cell_of(st["me"]["p"])
	var out: Array[Vector2i] = []
	if goals.has(from):
		return out
	var prev: Dictionary = {from: from}
	var q: Array[Vector2i] = [from]
	var i: int = 0
	while i < q.size():
		var c: Vector2i = q[i]
		i += 1
		if goals.has(c):
			var k: Vector2i = c
			while k != from:
				out.push_front(k)
				k = prev[k]
			return out
		for d: Vector2i in DIRS:
			var n: Vector2i = c + d
			if not prev.has(n) and walkable(st, n):
				prev[n] = c
				q.append(n)
	return out


static func reachable(st: Dictionary, from: Vector2i) -> Dictionary:
	var seen: Dictionary = {from: true}
	var q: Array[Vector2i] = [from]
	var i: int = 0
	while i < q.size():
		var c: Vector2i = q[i]
		i += 1
		for d: Vector2i in DIRS:
			var n: Vector2i = c + d
			if not seen.has(n) and walkable(st, n):
				seen[n] = true
				q.append(n)
	return seen


## Casillas pisables pegadas a las que cumplen "pred" (para ir a recoger o a beber).
static func spots_near(st: Dictionary, cells: Array) -> Dictionary:
	var out: Dictionary = {}
	for c: Vector2i in cells:
		for dy: int in range(-1, 2):
			for dx: int in range(-1, 2):
				var n: Vector2i = c + Vector2i(dx, dy)
				if (dx != 0 or dy != 0) and walkable(st, n) and center(n).distance_to(center(c)) <= REACH:
					out[n] = c
	return out


# ------------------------------------------------------------------ bot

## Un superviviente sensato: bebe y come antes de ir mal, prepara la hoguera antes de la noche
## (junto a la charca), pasa la noche a la luz y recoge lo que le falta para la meta.
static func bot_control(st: Dictionary, dt: float) -> Dictionary:
	var me: Dictionary = st["me"]
	var b: Dictionary = st["bot"]
	var inv: Dictionary = me["inv"]
	var p: Vector2 = me["p"]
	var out: Dictionary = {"move": Vector2.ZERO, "use": false, "eat": false, "craft": ""}
	if not b.has("camp"):
		b["camp"] = _camp(st)
	b["think"] = float(b.get("think", 0.0)) - dt
	## Fabricar en cuanto se puede (la meta, las herramientas una vez y la cura si esta enfermo).
	var order: Array[String] = recipe_ids(st)
	order.sort_custom(func(x: String, y: String) -> bool: return bool(recipe_def(st, x).get("win", false)) and not bool(recipe_def(st, y).get("win", false)))
	for id: String in order:
		var rd: Dictionary = recipe_def(st, id)
		if rd.has("fire") or rd.has("build") or not can_craft(st, id):
			continue
		var useful: bool = bool(rd.get("win", false)) or (rd.has("tool") and (not rd["tool"].has("dmg") or hostile_any(st)))
		if not useful and rd.has("item") and float(me["sick"]) > 0.0:
			for it: String in rd["item"]:
				useful = useful or float(item_def(st, it).get("heal", 0.0)) > 0.0
		if useful:
			out["craft"] = id
			return out
	var food_it: String = best_food(st)
	var raw_wait: bool = food_it != "" and float(item_def(st, food_it).get("sick", 0.0)) > 0.0 and fire_on(st) and float(me["food"]) > 18.0
	if food_it != "" and not raw_wait and (float(me["food"]) < 55.0 or (float(me["sick"]) > 0.0 and float(item_def(st, food_it).get("heal", 0.0)) > 0.0)):
		out["eat"] = true
	var night: bool = bool(st["is_night"])
	var soon: float = to_night(st)
	var camp: Vector2i = b["camp"]
	## Lobo encima: si hay hoguera, a la luz; si no, a golpes.
	var near_wolf: Dictionary = {}
	for wf: Dictionary in st["wolves_list"]:
		if not bool(wf["leaving"]) and bool(creature(st, wf).get("hostile", true)) and p.distance_to(wf["p"]) < 2.6:
			near_wolf = wf
	if not near_wolf.is_empty():
		var afraid: bool = bool(creature(st, near_wolf).get("fear_fire", true))
		if afraid and fire_on(st) and not in_light(st, p, 0.6) and p.distance_to(st["fire"]["p"]) < 9.0:
			return _go(st, out, {cell_of(st["fire"]["p"]): true}, "luz")
		if not afraid and p.distance_to(near_wolf["p"]) < REACH - 0.1:
			out["use"] = true
			return out
		if p.distance_to(near_wolf["p"]) < REACH - 0.1:
			out["use"] = true
			return out
		if not in_light(st, p):
			out["move"] = ((near_wolf["p"] as Vector2) - p).normalized()
			return out
	## Lo que corre prisa: beber y comer (y llenarse antes de que caiga la noche).
	var before_night: bool = not night and soon < 26.0
	if float(me["water"]) < (35.0 if not night else 22.0) or (before_night and float(me["water"]) < 75.0):
		return _go_use(st, out, spots_near(st, st["ponds"]), "beber", "drink")
	## Frio: a calentarse a la hoguera antes de que haga dano.
	if float(st["cat"]["cold"]) > 0.0 and float(me["warm"]) < 35.0 and fire_on(st) and not in_light(st, p, 0.8):
		return _go(st, out, {cell_of(st["fire"]["p"]): true}, "calor")
	## Comida cruda y hoguera encendida: a cocinarla.
	if cookable(st) != "" and fire_on(st) and (float(me["food"]) < 65.0 or p.distance_to(st["fire"]["p"]) < REACH):
		if p.distance_to(st["fire"]["p"]) < REACH - 0.15:
			out["use"] = true
			return out
		if float(me["food"]) < 65.0:
			return _go(st, out, {cell_of(st["fire"]["p"]): true}, "cocinar")
	if (float(me["food"]) < (40.0 if not night else 22.0) or (before_night and float(me["food"]) < 60.0)) and food_it == "":
		var bushes: Array = food_tiles(st)
		if not bushes.is_empty():
			return _go_use(st, out, spots_near(st, bushes), "bayas", "gather")
		## Sin plantas: a cazar la presa mas cercana.
		if not night and not _nearest_prey(st).is_empty():
			return _hunt(st, out)
	## Noche: hoguera encendida y a su luz (con lena para echarle).
	var fire_need: float = to_dawn(st) + 4.0 if night else float(st["night"]) + minf(soon, 20.0) + 4.0
	var fire_id: String = fire_recipe(st)
	if (night or soon < 22.0) and fire_id != "":
		if not fire_on(st):
			if can_craft(st, fire_id):
				if cell_of(p) == camp or (night and soon <= 0.0) or path_to(st, {camp: true}).is_empty():
					out["craft"] = fire_id
					return out
				return _go(st, out, {camp: true}, "campamento")
			if night:
				return _gather_for(st, out, recipe(st, fire_id))
		elif float(st["fire"]["fuel"]) < fire_need and fuel_item(st) != "":
			if p.distance_to(st["fire"]["p"]) < REACH - 0.15:
				out["use"] = true
				return out
			return _go(st, out, {cell_of(st["fire"]["p"]): true}, "lena")
		elif night:
			if p.distance_to(st["fire"]["p"]) > 1.2:
				return _go(st, out, {cell_of(st["fire"]["p"]): true}, "luz")
			return out
	## De dia: lo que falta (hoguera de esta noche, herramientas y la meta).
	var want: Dictionary = {}
	var fruit: Array = food_tiles(st)
	if not fruit.is_empty():
		want[str(tile_def(st, str(st["res"][fruit[0]]["kind"]))["item"])] = 2
	var fuel_it: String = _fuel_kind(st)
	if fire_id != "" and (not fire_on(st) or float(st["fire"]["fuel"]) < float(st["night"]) + 10.0):
		_add(want, recipe(st, fire_id))
		if fuel_it != "":
			_add(want, {fuel_it: int(ceil(float(st["night"]) / float(item_def(st, fuel_it)["fuel"])))})
	for id: String in recipe_ids(st):
		var rd: Dictionary = recipe_def(st, id)
		if rd.has("tool") and not (me["tools"] as Dictionary).has(id) and (not rd["tool"].has("dmg") or hostile_any(st)):
			_add(want, rd.get("cost", {}))
		elif bool(rd.get("win", false)) and str(st["goal"]) != "noches":
			_add(want, rd.get("cost", {}))
	return _gather_for(st, out, want)


## Hay criaturas que atacan en este nivel?
static func hostile_any(st: Dictionary) -> bool:
	if int(st["wolves"]) <= 0:
		return false
	for d: Vector2i in st["dens"]:
		if bool((st["cat"]["creatures"] as Dictionary).get(den_kind(st, d), {}).get("hostile", true)):
			return true
	return false


## La receta que enciende fuego ("" si no hay).
static func fire_recipe(st: Dictionary) -> String:
	for id: String in recipe_ids(st):
		if bool(recipe_def(st, id).get("fire", false)):
			return id
	return ""


static func _fuel_kind(st: Dictionary) -> String:
	for it: String in st["cat"]["items"]:
		if float(item_def(st, it).get("fuel", 0.0)) > 0.0:
			return it
	return ""


## Casillas con algo de comer que quede.
static func food_tiles(st: Dictionary) -> Array:
	var out: Array = []
	for c: Vector2i in st["res"]:
		var td: Dictionary = tile_def(st, str(st["res"][c]["kind"]))
		if int(st["res"][c]["left"]) > 0 and td.has("item") and float(item_def(st, str(td["item"])).get("food", 0.0)) > 0.0:
			out.append(c)
	return out


## Persigue a la presa mas cercana y le pega al alcanzarla.
static func _hunt(st: Dictionary, out: Dictionary) -> Dictionary:
	var prey: Dictionary = _nearest_prey(st)
	var p: Vector2 = st["me"]["p"]
	if p.distance_to(prey["p"]) < REACH - 0.15:
		out["use"] = true
		return out
	st["bot"]["think"] = 0.0
	return _go(st, out, {cell_of(prey["p"]): true}, "caza")


static func _prey_gives(st: Dictionary, item: String) -> bool:
	for k: String in st["cat"]["creatures"]:
		var cd: Dictionary = st["cat"]["creatures"][k]
		if not bool(cd.get("hostile", true)) and (cd.get("drops", {}) as Dictionary).has(item):
			for t: Vector2i in st["herds"]:
				if str(tile_def(st, tile(st, t)).get("herd", "")) == k:
					return true
	return false


static func _nearest_prey(st: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var bd: float = 14.0
	for wf: Dictionary in st["wolves_list"]:
		if not bool(creature(st, wf).get("hostile", true)):
			var d: float = (st["me"]["p"] as Vector2).distance_to(wf["p"])
			if d < bd:
				bd = d
				best = wf
	return best


static func _add(a: Dictionary, b: Dictionary) -> void:
	for k: String in b:
		a[k] = int(a.get(k, 0)) + int(b[k])


## Va a recoger lo que mas falta (lo mas cercano de eso).
static func _gather_for(st: Dictionary, out: Dictionary, want: Dictionary) -> Dictionary:
	var inv: Dictionary = st["me"]["inv"]
	var kinds: Array = []
	for item: String in want:
		if int(inv.get(item, 0)) < int(want.get(item, 0)):
			kinds.append(item)
	if kinds.is_empty():
		var fk: String = _fuel_kind(st)
		kinds = [fk if fk != "" else "wood"]
		## Lena de sobra para varias noches: no hace falta mas.
		if int(inv.get(kinds[0], 0)) >= 24:
			return out
		## Con mochila pequena no se llena de lena de mas.
		if int(st["cat"]["bag"]) > 0 and carried(st) >= int(st["cat"]["bag"]) * 2 / 3:
			return out
	if bag_full(st) or (int(st["cat"]["bag"]) > 0 and carried(st) >= int(st["cat"]["bag"]) - 2):
		## Llena: tira lo que sobra para hacer sitio a lo que falta.
		var sp: String = surplus(st, want)
		if sp != "":
			out["drop"] = sp
			out["drop_n"] = mini(3, int(inv[sp]) - int(want.get(sp, 0)))
			return out
		if bag_full(st):
			return out
	## Lo que solo dan las presas (piel, carne): a cazar.
	if not bool(st["is_night"]) and not _nearest_prey(st).is_empty():
		for k: String in kinds:
			if _prey_gives(st, k):
				return _hunt(st, out)
	var tiles: Array = []
	for c: Vector2i in st["res"]:
		var r: Dictionary = st["res"][c]
		var td: Dictionary = tile_def(st, str(r["kind"]))
		## Sin mochila limitada se saquea todo; con mochila, solo lo que da algo que falta.
		var loot_ok: bool = td.has("loot") and int(st["cat"]["bag"]) <= 0
		for li: String in td.get("loot", {}):
			loot_ok = loot_ok or li in kinds
		if int(r["left"]) > 0 and (str(td.get("item", "")) in kinds or loot_ok):
			if str(td.get("needs", "")) == "" or (st["me"]["tools"] as Dictionary).has(str(td["needs"])):
				tiles.append(c)
	if tiles.is_empty():
		return out
	return _go_use(st, out, spots_near(st, tiles), "recoger", "gather")


static func _go_use(st: Dictionary, out: Dictionary, spots: Dictionary, why: String, what: String) -> Dictionary:
	var me: Dictionary = st["me"]
	var c: Vector2i = cell_of(me["p"])
	if spots.has(c):
		## Ya esta al lado: mira hacia ello y usa (recoger sigue solo).
		var tgt: Vector2i = spots[c]
		var want: Dictionary = {"what": what, "cell": tgt}
		me["face"] = (center(tgt) - (me["p"] as Vector2)).normalized()
		if (me["job"] as Dictionary).is_empty():
			var tg: Dictionary = use_target(st, want)
			if not tg.is_empty() and str(tg["what"]) in [what, "hit"]:
				out["use"] = true
				out["want"] = want
			else:
				## Todavia no llega: un paso hacia ello (nunca un empujon que no mueve).
				out["move"] = (center(tgt) - (me["p"] as Vector2)).normalized()
		return out
	return _go(st, out, spots, why)


static func _go(st: Dictionary, out: Dictionary, goals: Dictionary, why: String) -> Dictionary:
	var me: Dictionary = st["me"]
	var b: Dictionary = st["bot"]
	var path: Array = b.get("path", [])
	if float(b.get("think", 0.0)) <= 0.0 or str(b.get("why", "")) != why or path.is_empty():
		b["think"] = 0.4
		b["why"] = why
		path = path_to(st, goals)
		b["path"] = path
	var p: Vector2 = me["p"]
	while not path.is_empty() and p.distance_to(center(path[0])) < 0.2:
		path.pop_front()
	if path.is_empty():
		if goals.size() == 1:
			var g: Vector2i = goals.keys()[0]
			out["move"] = (center(g) - p).normalized() if p.distance_to(center(g)) > 0.12 else Vector2.ZERO
		return out
	out["move"] = (center(path[0]) - p).normalized()
	return out


## Donde montar el campamento: junto a la charca y cerca de las bayas.
static func _camp(st: Dictionary) -> Vector2i:
	var start: Vector2i = st["start"]
	var reach: Dictionary = reachable(st, start)
	var best: Vector2i = start
	var bs: float = INF
	var bushes: Array = food_tiles(st)
	for c2: Vector2i in reach:
		var dp: float = INF
		for w: Vector2i in st["ponds"]:
			dp = minf(dp, Vector2(c2).distance_to(Vector2(w)))
		if dp < 1.5:
			continue
		var db: float = 12.0
		for bb: Vector2i in bushes:
			db = minf(db, Vector2(c2).distance_to(Vector2(bb)))
		var dd: float = INF
		for d: Vector2i in st["dens"]:
			dd = minf(dd, Vector2(c2).distance_to(Vector2(d)))
		var s: float = dp + 0.4 * db - minf(dd, 10.0) * 0.3
		if s < bs:
			bs = s
			best = c2
	return best


# ------------------------------------------------------------------ analizador

static func bot_play(level: Dictionary, dt: float = 1.0 / 20.0) -> Dictionary:
	var st: Dictionary = new_state(level)
	var limit: float = 60.0 + float(st["day"] + st["night"]) * (float(st["nights"]) + 1.0 if str(st["goal"]) == "noches" else 6.0)
	if str(st["goal"]) == "receta" and win_recipe(st) == "":
		return {"won": false, "cause": "sin_meta", "time": 0.0, "hp": 100.0, "survived": 0}
	while not bool(st["over"]) and float(st["t"]) < limit:
		step(st, bot_control(st, dt), dt)
		(st["events"] as Array).clear()
	return {"won": bool(st["won"]), "cause": str(st["cause"]) if bool(st["over"]) else "tiempo", "time": float(st["t"]),
		"hp": float(st["me"]["hp"]), "survived": int(st["survived"])}


static func map_issues(st: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var start: Vector2i = st["start"]
	var reach: Dictionary = reachable(st, start)
	var water: bool = false
	for c: Vector2i in spots_near(st, st["ponds"]):
		if reach.has(c):
			water = true
	if not water:
		out.append("survival_no_water")
	var food: int = 0
	var got: Dictionary = {}
	for c2: Vector2i in st["res"]:
		var near: bool = false
		for n: Vector2i in spots_near(st, [c2]):
			if reach.has(n):
				near = true
		if not near:
			continue
		var td: Dictionary = tile_def(st, str(st["res"][c2]["kind"]))
		if td.has("item"):
			var it: String = str(td["item"])
			if float(item_def(st, it).get("food", 0.0)) > 0.0:
				food += 1
			got[it] = int(got.get(it, 0)) + tile_yield(st, str(st["res"][c2]["kind"]))
		elif td.has("loot"):
			for it2: String in td["loot"]:
				got[it2] = int(got.get(it2, 0)) + int(td["loot"][it2]) * tile_yield(st, str(st["res"][c2]["kind"]))
	## Las presas tambien dan de comer (cada una cuenta como un arbusto).
	for hc: Vector2i in st["herds"]:
		if reach.has(hc):
			food += 1
			## Y lo que sueltan al cazarlas (vuelven a salir: cuenta como tres).
			var drops: Dictionary = (st["cat"]["creatures"] as Dictionary).get(str(tile_def(st, tile(st, hc)).get("herd", "")), {}).get("drops", {})
			for it4: String in drops:
				got[it4] = int(got.get(it4, 0)) + int(drops[it4]) * 3
	if food < 2:
		out.append("survival_no_food")
	## Lo que hace falta: hoguera, herramientas, la meta y la lena de todas las noches.
	var need: Dictionary = {}
	for id: String in recipe_ids(st):
		var rd: Dictionary = recipe_def(st, id)
		if rd.has("tool") or bool(rd.get("fire", false)) or (bool(rd.get("win", false)) and str(st["goal"]) != "noches"):
			_add(need, rd.get("cost", {}))
	var fk: String = _fuel_kind(st)
	if fk != "" and fire_recipe(st) != "":
		_add(need, {fk: int(ceil(float(st["night"]) / float(item_def(st, fk)["fuel"]))) * int(st["nights"])})
	for it3: String in need:
		if int(got.get(it3, 0)) < int(need[it3]):
			out.append("survival_few_resources")
			break
	if str(st["goal"]) == "receta" and win_recipe(st) == "":
		out.append("survival_no_goal")
	for d: Vector2i in st["dens"]:
		if Vector2(d).distance_to(Vector2(start)) < 7.0:
			out.append("survival_den_near")
			break
	if reach.size() < 40:
		out.append("survival_small")
	return out


## La receta que gana la partida ("" si no hay).
static func win_recipe(st: Dictionary) -> String:
	for id: String in recipe_ids(st):
		if bool(recipe_def(st, id).get("win", false)):
			return id
	return ""


# ------------------------------------------------------------------ guardar la partida

## Foto de la partida que se puede guardar en JSON (para seguir otro dia donde se dejo).
static func snapshot(st: Dictionary) -> Dictionary:
	var me: Dictionary = st["me"]
	var res: Array = []
	for c: Vector2i in st["res"]:
		res.append([c.x, c.y, int(st["res"][c]["left"]), snappedf(float(st["res"][c]["regrow"]), 0.01)])
	var built: Array = []
	for c2: Vector2i in st["built"]:
		built.append([c2.x, c2.y, str(st["built"][c2])])
	var mobs: Array = []
	for wf: Dictionary in st["wolves_list"]:
		mobs.append([str(wf.get("kind", "wolf")), snappedf((wf["p"] as Vector2).x, 0.01), snappedf((wf["p"] as Vector2).y, 0.01),
			float(wf["hp"]), (wf["home"] as Vector2i).x, (wf["home"] as Vector2i).y, bool(wf["leaving"])])
	var grid: Array = []
	for row: Array in st["grid"]:
		grid.append("".join(PackedStringArray(row)))
	var tools: Dictionary = {}
	for k: String in me["tools"]:
		tools[k] = me["tools"][k]
	var fire: Dictionary = {}
	if not (st["fire"] as Dictionary).is_empty():
		fire = {"x": (st["fire"]["p"] as Vector2).x, "y": (st["fire"]["p"] as Vector2).y, "fuel": float(st["fire"]["fuel"])}
	return {"v": 1, "t": float(st["t"]), "night_i": int(st["night_i"]), "survived": int(st["survived"]), "is_night": bool(st["is_night"]),
		"me": {"x": (me["p"] as Vector2).x, "y": (me["p"] as Vector2).y, "hp": float(me["hp"]), "food": float(me["food"]),
			"water": float(me["water"]), "warm": float(me["warm"]), "sick": float(me["sick"]), "inv": (me["inv"] as Dictionary).duplicate(), "tools": tools},
		"res": res, "built": built, "mobs": mobs, "grid": grid, "fire": fire, "wolf_n": int(st["wolf_n"])}


## La partida de un nivel a partir de su foto ({} si la foto no vale).
static func restore(level: Dictionary, snap: Dictionary) -> Dictionary:
	if int(snap.get("v", 0)) != 1:
		return {}
	var st: Dictionary = new_state(level)
	var grid: Array = snap.get("grid", [])
	if grid.size() != int(st["h"]):
		return {}
	for y: int in grid.size():
		var row: String = str(grid[y])
		if row.length() != int(st["w"]):
			return {}
		for x: int in row.length():
			st["grid"][y][x] = row[x]
	st["t"] = float(snap["t"])
	st["night_i"] = int(snap["night_i"])
	st["survived"] = int(snap["survived"])
	st["is_night"] = bool(snap["is_night"])
	st["wolf_n"] = int(snap.get("wolf_n", 0))
	var me: Dictionary = st["me"]
	var sm: Dictionary = snap["me"]
	me["p"] = Vector2(float(sm["x"]), float(sm["y"]))
	for k: String in ["hp", "food", "water", "warm", "sick"]:
		me[k] = float(sm.get(k, me[k]))
	for it: String in sm.get("inv", {}):
		me["inv"][it] = int(sm["inv"][it])
	me["tools"] = {}
	for t: String in sm.get("tools", {}):
		var v: Variant = sm["tools"][t]
		me["tools"][t] = int(v) if (v is float or v is int) else true
	st["res"] = {}
	for r: Array in snap.get("res", []):
		st["res"][Vector2i(int(r[0]), int(r[1]))] = {"kind": tile(st, Vector2i(int(r[0]), int(r[1]))), "left": int(r[2]), "regrow": float(r[3])}
	st["built"] = {}
	for b: Array in snap.get("built", []):
		if BUILDS.has(str(b[2])):
			st["built"][Vector2i(int(b[0]), int(b[1]))] = str(b[2])
	st["wolves_list"] = []
	var n: int = 0
	for m: Array in snap.get("mobs", []):
		n += 1
		(st["wolves_list"] as Array).append({"id": int(st["wolf_n"]) + n, "kind": str(m[0]), "p": Vector2(float(m[1]), float(m[2])),
			"home": Vector2i(int(m[4]), int(m[5])), "hp": float(m[3]), "cd": 1.0, "stun": 0.0, "wander": Vector2.ZERO, "wt": 0.0, "leaving": bool(m[6])})
	st["wolf_n"] = int(st["wolf_n"]) + n
	var f: Dictionary = snap.get("fire", {})
	st["fire"] = {} if f.is_empty() else {"p": Vector2(float(f["x"]), float(f["y"])), "fuel": float(f["fuel"])}
	(st["rng"] as RandomNumberGenerator).seed = int(parse(level)["seed"]) + int(float(st["t"]) * 10.0)
	st["flow_t"] = 0.0
	(st["events"] as Array).clear()
	return st


static func analyze(level: Dictionary) -> Dictionary:
	var st0: Dictionary = new_state(level)
	var issues: Array[String] = map_issues(st0)
	var wins: int = 0
	var tsum: float = 0.0
	var causes: Array[String] = []
	if issues.is_empty():
		var base: int = int(parse(level)["seed"])
		for k: int in 3:
			var lv: Dictionary = level.duplicate()
			var rows: Array = []
			for r: Variant in level.get("map", []):
				if not (str(r).begins_with("#") and str(r).substr(1).is_valid_int()):
					rows.append(r)
			rows.append("#%d" % (base + k * 97))
			lv["map"] = rows
			var r2: Dictionary = bot_play(lv)
			tsum += float(r2["time"])
			if bool(r2["won"]):
				wins += 1
			else:
				causes.append(str(r2["cause"]))
		if wins < 2:
			issues.append("survival_too_hard")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": 0, "enemies": st0["dens"].size() * int(st0["wolves"]),
		"enemy_problems": [], "par": int(tsum / 3.0 * 1.1) + 5, "causes": causes}
