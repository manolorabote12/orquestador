extends RefCounted
## Tu aldea (entre asaltos): que has construido y a que nivel, guardado en Save.meta()["aldea"].
## 1 - Huecos fijos (SLOTS): cada uno se desbloquea con un nivel de ayuntamiento y se construye
##     con monedas del botin. Nada sube por encima del nivel del ayuntamiento (maximo 3).
## 2 - Lo construido ayuda en los asaltos: cuarteles = mas tropas, elixir = tropas mas fuertes,
##     oro = mas botin (bonus()).

const MAX_LEVEL: int = 3
const HALL_PRICES: Array[int] = [0, 400, 1000]
const SIZE: int = 18
const SLOTS: Array[Dictionary] = [
	{"id": "oro1", "key": "G", "cell": Vector2i(4, 7), "hall": 1, "price": 80},
	{"id": "elixir1", "key": "E", "cell": Vector2i(12, 7), "hall": 1, "price": 80},
	{"id": "canon1", "key": "C", "cell": Vector2i(7, 3), "hall": 1, "price": 120},
	{"id": "cuartel1", "key": "K", "cell": Vector2i(7, 12), "hall": 1, "price": 100},
	{"id": "mina1", "key": "M", "cell": Vector2i(3, 11), "hall": 2, "price": 150},
	{"id": "arquera1", "key": "A", "cell": Vector2i(12, 11), "hall": 2, "price": 250},
	{"id": "canon2", "key": "C", "cell": Vector2i(3, 3), "hall": 2, "price": 200},
	{"id": "muralla", "key": "#", "cell": Vector2i(6, 6), "hall": 2, "price": 150},
	{"id": "mortero1", "key": "O", "cell": Vector2i(12, 3), "hall": 3, "price": 400},
	{"id": "cuartel2", "key": "K", "cell": Vector2i(10, 14), "hall": 3, "price": 300},
	{"id": "arquera2", "key": "A", "cell": Vector2i(3, 14), "hall": 3, "price": 400},
]


static func data() -> Dictionary:
	var m: Dictionary = Save.meta()
	var d: Variant = m.get("aldea", {})
	if not d is Dictionary or (d as Dictionary).is_empty():
		d = {"hall": 1, "built": {}}
		m["aldea"] = d
		Save.data["meta"] = m
	return d


static func hall() -> int:
	return int(data().get("hall", 1))


static func level(id: String) -> int:
	return int((data().get("built", {}) as Dictionary).get(id, 0))


static func slot(id: String) -> Dictionary:
	for s: Dictionary in SLOTS:
		if s["id"] == id:
			return s
	return {}


## Precio de construir (nivel 0 -> 1) o mejorar; -1 si no se puede (bloqueado o al maximo).
static func price(id: String) -> int:
	if id == "hall":
		var h: int = hall()
		return HALL_PRICES[h] if h < MAX_LEVEL else -1
	var s: Dictionary = slot(id)
	if s.is_empty() or hall() < int(s["hall"]):
		return -1
	var lv: int = level(id)
	if lv >= mini(hall(), MAX_LEVEL):
		return -1
	return int(s["price"]) * (lv + 1)


## Construye o mejora pagando con monedas. Devuelve true si se hizo.
static func build(id: String) -> bool:
	var p: int = price(id)
	if p < 0 or not Save.spend(p):
		return false
	var d: Dictionary = data()
	if id == "hall":
		d["hall"] = hall() + 1
	else:
		var b: Dictionary = d.get("built", {})
		b[id] = level(id) + 1
		d["built"] = b
	Save.save_data()
	QA.log_event("village_build", {"id": id, "level": level(id) if id != "hall" else hall()})
	return true


## Ejercito de los asaltos de liga (segun el ayuntamiento; las ayudas se suman despues).
static func liga_army(h: int) -> Dictionary:
	match h:
		1:
			return {"guerrero": 10, "arquera": 6}
		2:
			return {"guerrero": 12, "arquera": 8, "gigante": 1}
	return {"guerrero": 14, "arquera": 10, "gigante": 3}


## Ayuda en los asaltos.
static func bonus() -> Dictionary:
	var extra: int = level("cuartel1") + level("cuartel2")
	var strength: float = 0.04 * float(level("elixir1"))
	var loot: float = 0.1 * float(level("oro1"))
	return {"troops": extra, "strength": strength, "loot": loot}


## Mapa de la aldea (mismo formato que los niveles) con lo construido.
static func rows() -> Array[String]:
	var g: Array = []
	for y: int in SIZE:
		var r: Array[String] = []
		for x: int in SIZE:
			r.append(".")
		g.append(r)
	g[7][7] = "H"
	for s: Dictionary in SLOTS:
		if level(s["id"]) <= 0:
			continue
		var c: Vector2i = s["cell"]
		if s["key"] == "#":
			## Muralla: el cuadrado de 5x5 alrededor del ayuntamiento.
			for k: int in 5:
				for e: Vector2i in [Vector2i(c.x + k, c.y), Vector2i(c.x + k, c.y + 4), Vector2i(c.x, c.y + k), Vector2i(c.x + 4, c.y + k)]:
					g[e.y][e.x] = "#"
		else:
			g[c.y][c.x] = s["key"]
	var out: Array[String] = []
	for r: Array in g:
		out.append("".join(r))
	return out
