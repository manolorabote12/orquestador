class_name Chests
extends RefCounted
## Cofres y ruta de trofeos (como en los juegos grandes), guardados en Save.meta().
## 1 - Cofres: al superar un nivel ganas uno si tienes hueco (4 huecos). Se abre uno a la vez:
##     empiezas a abrirlo y tarda segun su rareza (madera 5 min, plata 30, oro 2 h, magico 6 h).
##     Se acelera viendo un anuncio con premio (-30 min) o pagando monedas (2 por minuto que falte).
##     Dentro: monedas y, a veces, un aspecto del heroe que aun no tienes.
## 2 - Ruta de trofeos: cada estrella nueva da 10 trofeos; cada 50 hay un premio (monedas, un
##     cofre o un aspecto) que se cobra una vez.
## Todo con la hora del movil; nada se compra con dinero real aqui.

const SLOTS: int = 4
const TYPES: Dictionary = {
	"madera": {"secs": 300, "coins": Vector2i(20, 40), "skin": 0.0, "color": Color("#b27a45")},
	"plata": {"secs": 1800, "coins": Vector2i(60, 100), "skin": 0.08, "color": Color("#c9d3e0")},
	"oro": {"secs": 7200, "coins": Vector2i(150, 250), "skin": 0.2, "color": Color("#ffcc33")},
	"magico": {"secs": 21600, "coins": Vector2i(350, 600), "skin": 0.6, "color": Color("#b36bff")},
}
## Orden en que salen (se repite): muchos de madera, alguno de plata y oro, y uno magico.
const CYCLE: Array[String] = ["madera", "madera", "plata", "madera", "oro", "madera", "plata", "madera", "madera", "magico", "plata", "oro"]
const TROPHY_STEP: int = 50


static func _data() -> Dictionary:
	var m: Dictionary = Save.meta()
	if not (m.get("chests", null) is Dictionary):
		m["chests"] = {"slots": [], "cycle": 0, "trophies": 0, "road": [], "stars": {}}
	var d: Dictionary = m["chests"]
	for k: String in ["slots", "road"]:
		if not (d.get(k, null) is Array):
			d[k] = []
	if not (d.get("stars", null) is Dictionary):
		d["stars"] = {}
	return d


static func now() -> int:
	return int(Time.get_unix_time_from_system())


static func slots() -> Array:
	return _data()["slots"]


## Al superar un nivel: trofeos por las estrellas nuevas y un cofre si cabe. Devuelve lo ganado.
static func on_level_won(level_id: String, stars: int) -> Dictionary:
	var d: Dictionary = _data()
	var before: int = int((d["stars"] as Dictionary).get(level_id, 0))
	var new_stars: int = maxi(0, stars - before)
	if new_stars > 0:
		d["stars"][level_id] = stars
		d["trophies"] = int(d["trophies"]) + new_stars * 10
	var chest: String = ""
	if (d["slots"] as Array).size() < SLOTS:
		chest = CYCLE[int(d["cycle"]) % CYCLE.size()]
		d["cycle"] = int(d["cycle"]) + 1
		(d["slots"] as Array).append({"type": chest, "start": -1})
	Save.save_data()
	return {"chest": chest, "trophies": new_stars * 10, "full": chest == ""}


static func unlocking() -> int:
	var s: Array = slots()
	for i: int in s.size():
		if int(s[i]["start"]) >= 0 and seconds_left(i) > 0:
			return i
	return -1


static func seconds_left(i: int) -> int:
	var s: Array = slots()
	if i < 0 or i >= s.size():
		return 0
	var c: Dictionary = s[i]
	if int(c["start"]) < 0:
		return int(TYPES[str(c["type"])]["secs"])
	return maxi(0, int(c["start"]) + int(TYPES[str(c["type"])]["secs"]) - now())


static func ready(i: int) -> bool:
	var s: Array = slots()
	return i >= 0 and i < s.size() and int(s[i]["start"]) >= 0 and seconds_left(i) <= 0


## Empezar a abrir (solo uno a la vez).
static func start(i: int) -> bool:
	var s: Array = slots()
	if i < 0 or i >= s.size() or int(s[i]["start"]) >= 0 or unlocking() >= 0:
		return false
	s[i]["start"] = now()
	Save.save_data()
	return true


static func skip_cost(i: int) -> int:
	return maxi(5, ceili(float(seconds_left(i)) / 60.0) * 2)


## Acelerar: con monedas (todo) o con un anuncio (30 minutos).
static func speed_up(i: int, with_ad: bool) -> bool:
	var s: Array = slots()
	if i < 0 or i >= s.size():
		return false
	if int(s[i]["start"]) < 0:
		s[i]["start"] = now()
	if with_ad:
		s[i]["start"] = int(s[i]["start"]) - 1800
	else:
		if not Save.spend(skip_cost(i)):
			return false
		s[i]["start"] = now() - int(TYPES[str(s[i]["type"])]["secs"])
	Save.save_data()
	return true


## Abrir uno listo: monedas y quiza un aspecto. Devuelve {"type", "coins", "skin"} o {}.
static func open(i: int) -> Dictionary:
	if not ready(i):
		return {}
	var s: Array = slots()
	var c: Dictionary = s[i]
	var t: Dictionary = TYPES[str(c["type"])]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(str(c["start"]) + str(c["type"]) + str(i))
	var coins: int = rng.randi_range((t["coins"] as Vector2i).x, (t["coins"] as Vector2i).y)
	var skin: String = ""
	if rng.randf() < float(t["skin"]):
		var missing: Array[String] = []
		for sk: Dictionary in Skins.LIST:
			if int(sk["price"]) > 0 and not Save.owns_skin(str(sk["id"])):
				missing.append(str(sk["id"]))
		if not missing.is_empty():
			skin = missing[rng.randi_range(0, missing.size() - 1)]
			Save.grant_skin(skin)
	## Cartas del album (13 nov).
	var cards: Array[String] = Album.for_chest(str(c["type"]), rng)
	## Arena: puntos de fuerza para mejorar personajes.
	var pts: Array = Brawlers.chest_points(str(c["type"]), rng) if Genres.current() == "brawl" else []
	s.remove_at(i)
	Save.add_wallet(coins)
	Save.save_data()
	QA.log_event("chest_open", {"type": str(c["type"]), "coins": coins, "skin": skin, "cards": cards.size()})
	return {"type": str(c["type"]), "coins": coins, "skin": skin, "cards": cards, "points": pts}


# ------------------------------------------------------------------ ruta de trofeos

static func trophies() -> int:
	return int(_data()["trophies"])


## Ligas (13 nov): los trofeos te suben de liga; con la campana larga (40+ niveles, 3 estrellas) se
## llega a Leyenda tras muchas horas. [umbral, clave de texto, nombre en espanol, color].
const LEAGUES: Array = [[0, "lg_bronze", "Bronce", "#c98a4b"], [150, "lg_silver", "Plata", "#c7d0dc"],
	[400, "lg_gold", "Oro", "#ffcf3f"], [800, "lg_platinum", "Platino", "#7fe0d4"],
	[1300, "lg_diamond", "Diamante", "#8fb8ff"], [2000, "lg_master", "Maestro", "#c78bff"], [3000, "lg_legend", "Leyenda", "#ff6f6f"]]


static func league_index(t: int) -> int:
	var i: int = 0
	for k: int in range(LEAGUES.size()):
		if t >= int(LEAGUES[k][0]):
			i = k
	return i


static func league_name(i: int) -> String:
	return Kit.text(str(LEAGUES[i][1]), str(LEAGUES[i][2]))


## Premio del escalon k (1, 2, 3...): monedas, cofre o aspecto, en ese ritmo.
static func road_reward(k: int) -> Dictionary:
	match k % 4:
		1:
			return {"kind": "coins", "amount": 50 + 25 * k}
		2:
			return {"kind": "chest", "type": "oro" if k % 8 == 6 else "plata"}
		3:
			return {"kind": "coins", "amount": 100 + 30 * k}
		_:
			return {"kind": "chest", "type": "magico"}


static func road_claimed(k: int) -> bool:
	return (_data()["road"] as Array).has(k)


static func road_claimable() -> Array[int]:
	var out: Array[int] = []
	for k: int in range(1, trophies() / TROPHY_STEP + 1):
		if not road_claimed(k):
			out.append(k)
	return out


## Cobrar un escalon de la ruta. Un cofre de premio necesita hueco.
static func claim_road(k: int) -> Dictionary:
	if road_claimed(k) or trophies() < k * TROPHY_STEP:
		return {}
	var r: Dictionary = road_reward(k)
	if str(r["kind"]) == "chest":
		if slots().size() >= SLOTS:
			return {"error": "full"}
		## Cofre de premio: ya viene abierto (listo para abrir).
		slots().append({"type": str(r["type"]), "start": now() - int(TYPES[str(r["type"])]["secs"])})
	else:
		Save.add_wallet(int(r["amount"]))
	(_data()["road"] as Array).append(k)
	Save.save_data()
	return r


static func pending() -> int:
	var n: int = road_claimable().size()
	for i: int in slots().size():
		if ready(i):
			n += 1
	return n


static func fmt_time(secs: int) -> String:
	if secs >= 3600:
		return "%dh %02dm" % [secs / 3600, (secs % 3600) / 60]
	if secs >= 60:
		return "%dm %02ds" % [secs / 60, secs % 60]
	return "%ds" % secs
