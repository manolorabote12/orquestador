class_name Album
extends RefCounted
## Album de personajes (13 nov, profundidad: coleccion). Todos los generos.
## 1 - Las cartas son los personajes y objetos del juego (game.json -> "album": [{"sprite", "name",
##     "rarity"}]; sin lista, los sprites del manifest). La del heroe se tiene desde el principio.
## 2 - Salen en los cofres (madera 2, plata 4, oro 8, magico 15) y, al azar, segun su rareza.
## 3 - Las repetidas suben la carta de nivel (hasta 5) pagando monedas, como en los juegos grandes.
## 4 - Cada nivel por encima del 1 da +1 % de monedas para siempre (bonus()); completar el album
##     entero, +5 % mas. Asi las monedas siempre tienen en que gastarse.
## Todo en Save.meta()["album"] = {sprite: {"n": copias, "lvl": nivel}}.

const MAX_LEVEL: int = 5
## Copias que hacen falta para pasar del nivel i al i+1 (indice = nivel actual) y su precio.
const NEED: Array[int] = [0, 2, 4, 10, 20]
const COST: Array[int] = [0, 50, 150, 400, 1000]
const WEIGHT: Dictionary = {"comun": 60.0, "raro": 28.0, "epico": 10.0, "legendario": 3.0}
const PER_CHEST: Dictionary = {"madera": 2, "plata": 4, "oro": 8, "magico": 15}
const COLORS: Dictionary = {"comun": "#9fb3c8", "raro": "#4fa3ff", "epico": "#b46bff", "legendario": "#ffb52e"}


## Las cartas del juego, en orden.
static func cards() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var lst: Variant = Kit.param("album", [])
	if lst is Array:
		for c: Variant in lst:
			if c is Dictionary and Kit.sprite_entry(str((c as Dictionary).get("sprite", ""))).size() > 0:
				out.append(c as Dictionary)
	if not out.is_empty():
		return out
	var sprites: Dictionary = Kit.assets.get("sprites", {})
	var k: int = 0
	for id: String in sprites.keys():
		var rol: String = str((sprites[id] as Dictionary).get("rol", ""))
		if not rol in ["jugador", "enemigo", "objeto"]:
			continue
		k += 1
		var rarity: String = "legendario" if id == "jefe" else ("comun" if rol != "enemigo" else ("raro" if k % 3 == 0 else "comun"))
		out.append({"sprite": id, "name": _fallback_name(id, rol, k), "rarity": rarity})
	return out


static func _fallback_name(id: String, rol: String, k: int) -> String:
	if id == "jefe" and str(Kit.param("boss_name", "")) != "":
		return str(Kit.param("boss_name", ""))
	if rol == "jugador":
		return str(Kit.param("story.cast.heroe.name", Kit.text("hero", "Héroe")))
	if rol == "objeto":
		return Kit.text("coins", "Monedas")
	return Kit.text("album_card", "Carta %d") % k


static func available() -> bool:
	return cards().size() >= 3


static func _data() -> Dictionary:
	var m: Dictionary = Save.meta()
	var a: Dictionary = m.get("album", {})
	## La carta del heroe se tiene desde el principio (el album no empieza vacio).
	for c: Dictionary in cards():
		var id: String = str(c["sprite"])
		if Kit.sprite_entry(id).get("rol", "") == "jugador" and not a.has(id):
			a[id] = {"n": 0, "lvl": 1}
	m["album"] = a
	Save.data["meta"] = m
	return a


static func entry(id: String) -> Dictionary:
	return _data().get(id, {"n": 0, "lvl": 0})


static func owned(id: String) -> bool:
	return int(entry(id).get("lvl", 0)) >= 1


static func count_owned() -> int:
	var n: int = 0
	for c: Dictionary in cards():
		if owned(str(c["sprite"])):
			n += 1
	return n


## Pura: cuantas copias hacen falta y cuanto cuesta subir desde el nivel lvl (-1 si ya es el maximo).
static func need(lvl: int) -> int:
	return NEED[lvl] if lvl >= 1 and lvl < MAX_LEVEL else -1


static func cost(lvl: int) -> int:
	return COST[lvl] if lvl >= 1 and lvl < MAX_LEVEL else -1


static func can_upgrade(id: String) -> bool:
	var e: Dictionary = entry(id)
	var lvl: int = int(e.get("lvl", 0))
	return lvl >= 1 and lvl < MAX_LEVEL and int(e.get("n", 0)) >= need(lvl) and Save.wallet() >= cost(lvl)


static func upgrade(id: String) -> bool:
	if not can_upgrade(id):
		return false
	var e: Dictionary = entry(id)
	var lvl: int = int(e["lvl"])
	if not Save.spend(cost(lvl)):
		return false
	var a: Dictionary = _data()
	a[id] = {"n": int(e["n"]) - need(lvl), "lvl": lvl + 1}
	Save.save_data()
	QA.log_event("album_upgrade", {"card": id, "level": lvl + 1})
	return true


## Cuantas cartas se pueden subir ahora (para el aviso del boton de la portada).
static func upgradable() -> int:
	var n: int = 0
	for c: Dictionary in cards():
		if can_upgrade(str(c["sprite"])):
			n += 1
	return n


## Anade n cartas al azar segun su rareza. Devuelve los ids que han salido (con repeticiones).
static func drop(rng: RandomNumberGenerator, n: int) -> Array[String]:
	var cs: Array[Dictionary] = cards()
	var got: Array[String] = []
	if cs.is_empty():
		return got
	var total: float = 0.0
	for c: Dictionary in cs:
		total += float(WEIGHT.get(str(c.get("rarity", "comun")), 60.0))
	var a: Dictionary = _data()
	for i: int in range(n):
		var r: float = rng.randf() * total
		var pick: Dictionary = cs[cs.size() - 1]
		for c: Dictionary in cs:
			r -= float(WEIGHT.get(str(c.get("rarity", "comun")), 60.0))
			if r <= 0.0:
				pick = c
				break
		var id: String = str(pick["sprite"])
		var e: Dictionary = a.get(id, {"n": 0, "lvl": 0})
		## La primera copia descubre la carta (nivel 1); las demas son para subirla.
		if int(e.get("lvl", 0)) == 0:
			e = {"n": 0, "lvl": 1}
		else:
			e = {"n": int(e.get("n", 0)) + 1, "lvl": int(e["lvl"])}
		a[id] = e
		got.append(id)
	Save.save_data()
	return got


static func for_chest(chest_type: String, rng: RandomNumberGenerator) -> Array[String]:
	if not available():
		return []
	return drop(rng, int(PER_CHEST.get(chest_type, 2)))


## Bonus de monedas del album: +1 % por cada nivel por encima del 1 y +5 % con el album completo.
static func bonus() -> float:
	if not available():
		return 0.0
	var b: float = 0.0
	var all: bool = true
	for c: Dictionary in cards():
		var lvl: int = int(entry(str(c["sprite"])).get("lvl", 0))
		if lvl <= 0:
			all = false
		b += 0.01 * float(maxi(lvl - 1, 0))
	return b + (0.05 if all else 0.0)


static func card_name(id: String) -> String:
	for c: Dictionary in cards():
		if str(c["sprite"]) == id:
			return str(c.get("name", id))
	return id


static func rarity_color(rarity: String) -> Color:
	return Color(str(COLORS.get(rarity, COLORS["comun"])))
