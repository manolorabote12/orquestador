extends RefCounted
## Datos y analizador de la aldea (asalto a una base, estilo juegos de clanes).
## Mapa: cuadricula; cada edificio se marca con su letra en la casilla de arriba a la izquierda
## y el resto de su huella va en "." (la huella sale de la tabla TYPES).
##   H ayuntamiento 3x3 - G almacen de oro - E almacen de elixir - M mina - K casa (2x2)
##   C canon - A torre arquera - O mortero (2x2, defensas) - # muro (1x1) - . hierba
## El analizador comprueba SIN jugar:
## 1 - Tamano 14-24, filas iguales, edificios dentro y sin solaparse.
## 2 - Un solo ayuntamiento y al menos una defensa.
## 3 - Hay sitio para desplegar: el borde de la base queda libre (al menos 40 casillas validas).
## 4 - Ejercito con al menos 5 tropas y tiempo de sobra.

const TYPES: Dictionary = {
	"H": {"id": "hall", "size": 3, "hp": 1600.0, "h": 46.0, "loot": 300},
	"G": {"id": "gold", "size": 2, "hp": 700.0, "h": 30.0, "loot": 200},
	"E": {"id": "elixir", "size": 2, "hp": 700.0, "h": 30.0, "loot": 200},
	"M": {"id": "mine", "size": 2, "hp": 420.0, "h": 22.0, "loot": 60},
	"K": {"id": "house", "size": 2, "hp": 380.0, "h": 30.0, "loot": 0},
	"C": {"id": "cannon", "size": 2, "hp": 520.0, "h": 14.0, "loot": 0, "def": true, "range": 5.0, "dmg": 30.0, "rate": 0.8},
	"A": {"id": "archer", "size": 2, "hp": 460.0, "h": 52.0, "loot": 0, "def": true, "range": 6.5, "dmg": 15.0, "rate": 0.5},
	"O": {"id": "mortar", "size": 2, "hp": 480.0, "h": 18.0, "loot": 0, "def": true, "range": 7.5, "min": 2.5, "dmg": 26.0, "rate": 4.0, "splash": 1.3},
	"#": {"id": "wall", "size": 1, "hp": 300.0, "h": 16.0, "loot": 0, "wall": true},
}

const TROOPS: Dictionary = {
	"guerrero": {"hp": 120.0, "dmg": 22.0, "rate": 1.0, "range": 0.7, "speed": 1.7, "pref": ""},
	"arquera": {"hp": 50.0, "dmg": 16.0, "rate": 1.0, "range": 3.3, "speed": 1.7, "pref": ""},
	"gigante": {"hp": 580.0, "dmg": 46.0, "rate": 2.0, "range": 0.7, "speed": 1.05, "pref": "def"},
}
const ORDER: Array[String] = ["gigante", "guerrero", "arquera"]


## Lista de edificios del mapa: [{"key", "cell": Vector2i, "size"}]; si algo esta mal, "error".
static func parse(map: Array) -> Dictionary:
	var out: Array[Dictionary] = []
	if map.is_empty():
		return {"buildings": out, "error": "village_empty", "w": 0, "h": 0}
	var w: int = str(map[0]).length()
	var h: int = map.size()
	var used: Dictionary = {}
	var error: String = ""
	for y: int in h:
		var row: String = str(map[y])
		if row.length() != w:
			error = "village_bad_rows"
		for x: int in mini(row.length(), w):
			var ch: String = row[x]
			if not TYPES.has(ch):
				continue
			var s: int = int(TYPES[ch]["size"])
			for dy: int in s:
				for dx: int in s:
					var c: Vector2i = Vector2i(x + dx, y + dy)
					if c.x >= w or c.y >= h:
						error = "village_outside"
					elif used.has(c):
						error = "village_overlap"
					elif (dx != 0 or dy != 0) and str(map[c.y])[c.x] != ".":
						error = "village_overlap"
					used[c] = true
			out.append({"key": ch, "cell": Vector2i(x, y), "size": s})
	return {"buildings": out, "error": error, "w": w, "h": h, "used": used}


## Casillas donde se pueden soltar tropas: dentro del mapa y a mas de 1 casilla de cualquier edificio.
static func deploy_cells(parsed: Dictionary) -> Array[Vector2i]:
	var used: Dictionary = parsed.get("used", {})
	var out: Array[Vector2i] = []
	for y: int in int(parsed["h"]):
		for x: int in int(parsed["w"]):
			var ok: bool = true
			for dy: int in range(-1, 2):
				for dx: int in range(-1, 2):
					if used.has(Vector2i(x + dx, y + dy)):
						ok = false
			if ok:
				out.append(Vector2i(x, y))
	return out


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var map: Array = level.get("map", [])
	var p: Dictionary = parse(map)
	if str(p["error"]) != "":
		issues.append(str(p["error"]))
	var w: int = int(p["w"])
	var h: int = int(p["h"])
	if w < 14 or w > 24 or h < 14 or h > 24:
		issues.append("village_size")
	var halls: int = 0
	var defs: int = 0
	var loot: int = 0
	for b: Dictionary in p["buildings"]:
		var t: Dictionary = TYPES[b["key"]]
		if b["key"] == "H":
			halls += 1
		if bool(t.get("def", false)):
			defs += 1
		loot += int(t["loot"])
	if halls != 1:
		issues.append("village_hall")
	if defs == 0:
		issues.append("village_no_defense")
	if deploy_cells(p).size() < 40:
		issues.append("village_no_room")
	var army: Dictionary = level.get("army", {})
	var n: int = 0
	for k: String in army.keys():
		if not TROOPS.has(k):
			issues.append("village_bad_troop")
		n += int(army[k])
	if n < 5:
		issues.append("village_small_army")
	if float(level.get("seconds", 120.0)) < 60.0:
		issues.append("village_short")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": loot, "enemies": defs, "enemy_problems": []}
