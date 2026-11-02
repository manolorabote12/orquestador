extends Node
## Save: guardado a prueba de cortes (escribe en .tmp y luego sustituye).
## Autoload "Save".

const PATH: String = "user://save.json"
const SCHEMA: int = 1

var data: Dictionary = {}


func _ready() -> void:
	load_data()


func defaults() -> Dictionary:
	return {
		"schema": SCHEMA,
		"settings": {"music": 0.8, "sfx": 1.0, "haptics": true},
		"progress": {"unlocked": 1, "best": {}, "stars": {}, "coins": 0},
		"meta": {"wallet": 0, "daily_day": -1, "streak": 0, "skins": ["original"], "skin": "original"},
	}


## 1 - Si el archivo esta corrupto o es de otra version, se recupera sin perder la partida.
func load_data() -> void:
	data = defaults()
	if not FileAccess.file_exists(PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not (parsed is Dictionary):
		push_warning("Save: archivo ilegible, se usan valores por defecto")
		QA.log_event("save_corrupt")
		return
	_merge(data, parsed as Dictionary)
	data["schema"] = SCHEMA


func save_data() -> bool:
	var tmp_path: String = PATH + ".tmp"
	var file: FileAccess = FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_error("Save: no se pudo escribir " + tmp_path)
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	var dir: DirAccess = DirAccess.open("user://")
	if dir == null:
		return false
	if dir.file_exists(PATH.get_file()):
		dir.remove(PATH.get_file())
	return dir.rename(tmp_path.get_file(), PATH.get_file()) == OK


func get_setting(key: String, fallback: Variant) -> Variant:
	var settings: Dictionary = data.get("settings", {})
	return settings.get(key, fallback)


func set_setting(key: String, value: Variant, persist: bool = true) -> void:
	var settings: Dictionary = data.get("settings", {})
	settings[key] = value
	data["settings"] = settings
	if persist:
		save_data()


func progress() -> Dictionary:
	return data.get("progress", {})


## 2 - Guarda la mejor marca de un nivel. Devuelve true si es record.
func submit_best(level_id: String, score: int) -> bool:
	if Kit.is_extra() and level_id == str(Kit.extra_index):
		return false
	var prog: Dictionary = progress()
	var best: Dictionary = prog.get("best", {})
	var old: int = int(best.get(level_id, -1))
	if score <= old:
		return false
	best[level_id] = score
	prog["best"] = best
	data["progress"] = prog
	save_data()
	return true


func unlock_level(index: int) -> void:
	## El nivel extra del reto no desbloquea nada.
	if Kit.is_extra() and index > Kit.extra_index:
		return
	var prog: Dictionary = progress()
	prog["unlocked"] = maxi(int(prog.get("unlocked", 1)), index + 1)
	data["progress"] = prog
	save_data()


## 3 - Estrellas de un nivel (0 a 3). Solo se guarda la mejor.
func stars_for(level_id: String) -> int:
	var stars: Dictionary = progress().get("stars", {})
	return int(stars.get(level_id, 0))


func submit_stars(level_id: String, count: int) -> bool:
	if Kit.is_extra() and level_id == str(Kit.extra_index):
		return false
	var prog: Dictionary = progress()
	var stars: Dictionary = prog.get("stars", {})
	var old: int = int(stars.get(level_id, 0))
	if count <= old:
		return false
	stars[level_id] = clampi(count, 0, 3)
	prog["stars"] = stars
	data["progress"] = prog
	save_data()
	return true


func unlocked_count() -> int:
	return int(progress().get("unlocked", 1))


## 4 - Progresion comun a todos los generos: cartera de monedas, premio diario y aspectos.
const DAILY: Array[int] = [20, 30, 40, 50, 60, 80, 120]


func meta() -> Dictionary:
	return data.get("meta", {})


func wallet() -> int:
	return int(meta().get("wallet", 0))


func add_wallet(amount: int) -> void:
	var m: Dictionary = meta()
	m["wallet"] = maxi(int(m.get("wallet", 0)) + amount, 0)
	data["meta"] = m
	save_data()


func spend(amount: int) -> bool:
	if amount > wallet():
		return false
	add_wallet(-amount)
	return true


static func today() -> int:
	return int(Time.get_unix_time_from_system() / 86400.0)


## Premio de hoy sin cobrarlo (0 si ya se cobro). La racha sigue si ayer tambien se cobro.
func daily_pending(day: int) -> int:
	var m: Dictionary = meta()
	var last: int = int(m.get("daily_day", -1))
	if last == day:
		return 0
	var streak: int = int(m.get("streak", 0)) + 1 if last == day - 1 else 1
	return DAILY[mini(streak, DAILY.size()) - 1]


func claim_daily(day: int) -> int:
	var amount: int = daily_pending(day)
	if amount == 0:
		return 0
	var m: Dictionary = meta()
	var last: int = int(m.get("daily_day", -1))
	m["streak"] = int(m.get("streak", 0)) + 1 if last == day - 1 else 1
	m["daily_day"] = day
	m["wallet"] = int(m.get("wallet", 0)) + amount
	data["meta"] = m
	save_data()
	return amount


func streak() -> int:
	return int(meta().get("streak", 0))


func owns_skin(id: String) -> bool:
	return (meta().get("skins", ["original"]) as Array).has(id)


## Aspecto regalado (pase de temporada): se anade sin cobrar.
func grant_skin(id: String) -> void:
	if owns_skin(id):
		return
	var m: Dictionary = meta()
	var owned: Array = m.get("skins", ["original"])
	owned.append(id)
	m["skins"] = owned
	data["meta"] = m
	save_data()


func buy_skin(id: String, price: int) -> bool:
	if owns_skin(id) or not spend(price):
		return false
	var m: Dictionary = meta()
	var owned: Array = m.get("skins", ["original"])
	owned.append(id)
	m["skins"] = owned
	m["skin"] = id
	data["meta"] = m
	save_data()
	return true


func equip_skin(id: String) -> bool:
	if not owns_skin(id):
		return false
	var m: Dictionary = meta()
	m["skin"] = id
	data["meta"] = m
	save_data()
	return true


## 8 - Mejoras compradas con monedas (permanentes). "heart": +1 vida por nivel de mejora.
## heart: corazon extra (plataformas, hordas) - tropas: +12 % de vida y dano por nivel (aldea)
## luchador: +8 % de vida y dano por nivel (arena).
const UPGRADES: Dictionary = {"heart": {"max": 2, "prices": [300, 700]}, "tropas": {"max": 3, "prices": [250, 600, 1200]},
	"luchador": {"max": 3, "prices": [250, 600, 1200]},
	## Escalada: el taller del coche.
	"motor": {"max": 4, "prices": [150, 400, 900, 1800]}, "suspension": {"max": 4, "prices": [120, 350, 800, 1600]},
	"ruedas": {"max": 4, "prices": [120, 350, 800, 1600]}, "deposito": {"max": 4, "prices": [100, 300, 700, 1400]}}


func upgrade_level(id: String) -> int:
	return int((meta().get("upgrades", {}) as Dictionary).get(id, 0))


func upgrade_price(id: String) -> int:
	if not UPGRADES.has(id):
		return -1
	var lvl: int = upgrade_level(id)
	var prices: Array = UPGRADES[id]["prices"]
	return int(prices[lvl]) if lvl < prices.size() else -1


func buy_upgrade(id: String) -> bool:
	var price: int = upgrade_price(id)
	if price < 0 or not spend(price):
		return false
	var m: Dictionary = meta()
	var ups: Dictionary = m.get("upgrades", {})
	ups[id] = upgrade_level(id) + 1
	m["upgrades"] = ups
	data["meta"] = m
	save_data()
	return true


func reset_all() -> void:
	data = defaults()
	save_data()


func _merge(base: Dictionary, extra: Dictionary) -> void:
	for key: Variant in extra.keys():
		if base.has(key) and base[key] is Dictionary and extra[key] is Dictionary:
			_merge(base[key], extra[key])
		else:
			base[key] = extra[key]
