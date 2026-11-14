class_name Brawlers
extends RefCounted
## Personajes de la arena (13 nov): cada uno con su vida, velocidad, dano, forma de disparar y super.
## 1 - Catalogo base (LIST) que el juego puede renombrar y redibujar (game.json -> "brawlers":
##     [{"id", "name", "sprite"?, "tint"?, ...}] con los mismos ids o nuevos).
## 2 - Se desbloquean con trofeos (ruta de trofeos: Chests.trophies()); el primero y el segundo,
##     desde el principio. El elegido se guarda en Save.meta()["brawler"].
## 3 - Disparos: "rafaga" (3 balas juntas), "escopeta" (5 abiertas, corto alcance) y "franco"
##     (una bala larga y fuerte). Supers: "ola" (anillo de balas), "escudo" (3 s casi sin dano),
##     "dash" (embestida que golpea al llegar), "cura" (a ti y a tu equipo cerca) y "bomba"
##     (explosion donde esta el rival mas cercano).
## Los aliados y los rivales usan personajes del catalogo (por orden), asi cada partida se ve variada.
## 4 - Nivel de fuerza (1 a 11, como en los juegos de arena): los cofres dan puntos de fuerza a los
##     personajes desbloqueados y con puntos + monedas se mejoran. Cada nivel, +8 % de vida y dano.

const LIST: Array[Dictionary] = [
	{"id": "tenaza", "name": "Chispa", "hp": 1.0, "speed": 1.0, "dmg": 1.0, "attack": "rafaga", "super": "ola", "trophies": 0},
	{"id": "coraza", "name": "Coraza", "hp": 1.45, "speed": 0.86, "dmg": 0.9, "attack": "escopeta", "super": "escudo", "trophies": 0},
	{"id": "aguja", "name": "Aguja", "hp": 0.78, "speed": 1.0, "dmg": 1.0, "attack": "franco", "super": "bomba", "trophies": 60},
	{"id": "rapida", "name": "Rayo", "hp": 0.86, "speed": 1.22, "dmg": 0.92, "attack": "rafaga", "super": "dash", "trophies": 150},
	{"id": "alga", "name": "Brote", "hp": 1.0, "speed": 1.0, "dmg": 0.82, "attack": "rafaga", "super": "cura", "trophies": 300},
	{"id": "tinta", "name": "Tinta", "hp": 0.92, "speed": 1.0, "dmg": 1.08, "attack": "escopeta", "super": "bomba", "trophies": 500},
	{"id": "perla", "name": "Perla", "hp": 0.8, "speed": 1.05, "dmg": 1.22, "attack": "franco", "super": "ola", "trophies": 800},
	{"id": "rey", "name": "Rey", "hp": 1.3, "speed": 0.95, "dmg": 1.12, "attack": "escopeta", "super": "dash", "trophies": 1200},
]
const MAX_LEVEL: int = 11
## Puntos y monedas para pasar del nivel n al n+1 (indice n-1).
const POINTS_NEED: Array[int] = [20, 30, 50, 80, 130, 210, 340, 550, 890, 1440]
const COINS_NEED: Array[int] = [20, 35, 75, 140, 290, 480, 800, 1250, 1875, 2800]
const PER_LEVEL: float = 0.08
## Puntos de fuerza por cofre (se reparten entre 1 o 2 personajes desbloqueados).
const CHEST_POINTS: Dictionary = {"madera": Vector2i(10, 20), "plata": Vector2i(30, 50), "oro": Vector2i(80, 120), "magico": Vector2i(200, 300)}

## Sprites del juego por orden (el arte que dibuja la fabrica) y tintes para distinguir los repetidos.
const SPRITES: Array[String] = ["heroe", "enemigo_walker", "enemigo_spiky", "enemigo_flyer", "jefe"]
const TINTS: Array[String] = ["", "#9fd8ff", "#ffb3c7", "#c8ffb0", "#ffe08a", "#d6b8ff", "#ffffff", "#ffcf9e"]
const ATTACKS: Dictionary = {
	"rafaga": {"n": 3, "spread": 0.07, "range": 1.0, "speed": 1.0, "dmg": 1.0},
	"escopeta": {"n": 5, "spread": 0.17, "range": 0.62, "speed": 0.95, "dmg": 0.82},
	"franco": {"n": 1, "spread": 0.0, "range": 1.35, "speed": 1.4, "dmg": 2.3},
}


## El catalogo del juego: el base con lo que cambie game.json (nombres, sprites, tintes).
static func catalog() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var extra: Variant = Kit.param("brawlers", [])
	var by_id: Dictionary = {}
	if extra is Array:
		for e: Variant in extra:
			if e is Dictionary and str((e as Dictionary).get("id", "")) != "":
				by_id[str((e as Dictionary)["id"])] = e
	for i: int in LIST.size():
		var b: Dictionary = LIST[i].duplicate()
		b["sprite"] = SPRITES[i % SPRITES.size()]
		b["tint"] = TINTS[i % TINTS.size()]
		if by_id.has(b["id"]):
			for k: String in (by_id[b["id"]] as Dictionary).keys():
				b[k] = by_id[b["id"]][k]
		out.append(b)
	return out


static func find(id: String) -> Dictionary:
	for b: Dictionary in catalog():
		if str(b["id"]) == id:
			return b
	return catalog()[0]


static func unlocked(b: Dictionary) -> bool:
	return Chests.trophies() >= int(b.get("trophies", 0))


static func chosen() -> Dictionary:
	var id: String = str(Save.meta().get("brawler", "tenaza"))
	var b: Dictionary = find(id)
	return b if unlocked(b) else catalog()[0]


static func choose(id: String) -> bool:
	var b: Dictionary = find(id)
	if str(b["id"]) != id or not unlocked(b):
		return false
	var m: Dictionary = Save.meta()
	m["brawler"] = id
	Save.data["meta"] = m
	Save.save_data()
	return true


## Personaje de un bot (aliado o rival) por su numero: variado y estable entre partidas.
static func for_bot(i: int) -> Dictionary:
	var cs: Array[Dictionary] = catalog()
	return cs[(i * 3 + 1) % cs.size()]


static func attack_of(b: Dictionary) -> Dictionary:
	return ATTACKS.get(str(b.get("attack", "rafaga")), ATTACKS["rafaga"])


static func sprite_entry(b: Dictionary) -> Dictionary:
	var e: Dictionary = Kit.sprite_entry(str(b.get("sprite", "heroe")))
	if e.is_empty():
		e = Kit.sprite_by_role("jugador")
	return e


static func tint(b: Dictionary) -> Color:
	var t: String = str(b.get("tint", ""))
	return Color(t) if t != "" else Color.WHITE


# ------------------------------------------------------------------ nivel de fuerza

static func _pw() -> Dictionary:
	var m: Dictionary = Save.meta()
	if not m.has("bpow") or not (m["bpow"] is Dictionary):
		m["bpow"] = {}
		Save.data["meta"] = m
	return m["bpow"]


static func _entry(id: String) -> Dictionary:
	var e: Variant = _pw().get(id)
	return e if e is Dictionary else {}


static func level(id: String) -> int:
	return clampi(int(_entry(id).get("lv", 1)), 1, MAX_LEVEL)


static func points(id: String) -> int:
	return int(_entry(id).get("pts", 0))


## Multiplicador de vida y dano por el nivel.
static func power_mult(id: String) -> float:
	return 1.0 + PER_LEVEL * float(level(id) - 1)


static func points_need(id: String) -> int:
	var lv: int = level(id)
	return POINTS_NEED[lv - 1] if lv < MAX_LEVEL else 0


static func coins_need(id: String) -> int:
	var lv: int = level(id)
	return COINS_NEED[lv - 1] if lv < MAX_LEVEL else 0


static func can_upgrade(id: String) -> bool:
	return level(id) < MAX_LEVEL and points(id) >= points_need(id) and Save.wallet() >= coins_need(id)


static func upgrade(id: String) -> bool:
	if not can_upgrade(id) or not unlocked(find(id)):
		return false
	if not Save.spend(coins_need(id)):
		return false
	var e: Dictionary = {"lv": level(id) + 1, "pts": points(id) - points_need(id)}
	_pw()[id] = e
	Save.save_data()
	QA.log_event("brawler_upgrade", {"id": id, "level": e["lv"]})
	return true


static func add_points(id: String, n: int) -> void:
	_pw()[id] = {"lv": level(id), "pts": points(id) + n}


## Puntos de fuerza de un cofre: [{"id", "n"}]. Solo a personajes desbloqueados y sin el maximo.
static func chest_points(kind: String, rng: RandomNumberGenerator) -> Array:
	var r: Vector2i = CHEST_POINTS.get(kind, Vector2i(10, 20))
	var pool: Array[String] = []
	for b: Dictionary in catalog():
		if unlocked(b) and level(str(b["id"])) < MAX_LEVEL:
			pool.append(str(b["id"]))
	if pool.is_empty():
		return []
	var total: int = rng.randi_range(r.x, r.y)
	var out: Array = []
	var picks: int = 1 if pool.size() == 1 or total < 30 else 2
	for k: int in picks:
		var id: String = pool[rng.randi_range(0, pool.size() - 1)]
		pool.erase(id)
		var n: int = total if k == picks - 1 else total / 2
		total -= n
		add_points(id, n)
		out.append({"id": id, "n": n})
		if pool.is_empty():
			break
	return out
