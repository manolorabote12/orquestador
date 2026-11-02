extends Node
## Logros: retos a largo plazo que valen para TODOS los generos. Autoload "Feats".
## 1 - Se cuentan solos escuchando los eventos de partida (QA.logged): level_start, death y
##     level_complete (con "stars" y "deaths" si el genero los manda).
## 2 - Al conseguir uno: aviso en pantalla, sonido y monedas para la tienda (una sola vez).
## 3 - Todo se guarda en Save.meta()["feats"]: progreso, conseguidos, racha sin morir, derrotas por
##     nivel y dias jugados.
## 4 - Se ven en Misiones y pase -> pestana "Logros" (SeasonPanel).

signal unlocked(id: String)

## id -> [objetivo, monedas]. "all_levels" y "all_stars" usan el numero de niveles del juego.
const LIST: Array[Array] = [
	["first_win", 1, 20], ["play_20", 20, 40], ["flawless", 1, 30], ["stars_3", 1, 30], ["comeback", 1, 40],
	["streak_5", 5, 60], ["levels_10", 10, 80], ["stars_30", 30, 100], ["days_3", 3, 50], ["daily", 1, 40],
	["all_levels", -1, 150], ["all_stars", -1, 300],
	["marathon_5", 5, 80], ["marathon_all", 1, 200], ["record_3", 3, 60],
]
const NAMES: Dictionary = {
	"first_win": "Primer paso", "play_20": "Sin parar", "flawless": "Impecable", "stars_3": "Tres estrellas",
	"comeback": "Nunca te rindas", "streak_5": "Imparable", "levels_10": "Veterano", "stars_30": "Cazaestrellas",
	"days_3": "Fiel", "daily": "Retador", "all_levels": "Lo has visto todo", "all_stars": "Perfeccionista",
	"marathon_5": "Fondista", "marathon_all": "Maratoniano", "record_3": "Contra el reloj",
}
const HOW: Dictionary = {
	"first_win": "Supera tu primer nivel", "play_20": "Juega 20 partidas", "flawless": "Supera un nivel sin morir",
	"stars_3": "Consigue 3 estrellas en un nivel", "comeback": "Gana un nivel en el que hab\u00edas perdido 3 veces",
	"streak_5": "Supera 5 niveles seguidos sin morir", "levels_10": "Supera 10 niveles", "stars_30": "Gana 30 estrellas",
	"days_3": "Juega 3 d\u00edas distintos", "daily": "Supera un reto del d\u00eda", "all_levels": "Supera todos los niveles",
	"all_stars": "3 estrellas en todos los niveles",
	"marathon_5": "Supera 5 niveles seguidos en una marat\u00f3n", "marathon_all": "Completa una marat\u00f3n",
	"record_3": "Mejora 3 veces un r\u00e9cord de contrarreloj",
}

var _level_deaths: int = 0


func _ready() -> void:
	QA.logged.connect(_on_event)


func state() -> Dictionary:
	var m: Dictionary = Save.meta()
	var f: Variant = m.get("feats", {})
	return f if f is Dictionary else {}


func _store(f: Dictionary) -> void:
	var m: Dictionary = Save.meta()
	m["feats"] = f
	Save.data["meta"] = m
	Save.save_data()


func goal(id: String) -> int:
	for e: Array in LIST:
		if str(e[0]) == id:
			return int(e[1]) if int(e[1]) > 0 else maxi(Kit.level_count(), 1)
	return 1


func reward(id: String) -> int:
	for e: Array in LIST:
		if str(e[0]) == id:
			return int(e[2])
	return 0


func progress(id: String) -> int:
	return int((state().get("progress", {}) as Dictionary).get(id, 0))


func done(id: String) -> bool:
	return bool((state().get("done", {}) as Dictionary).get(id, false))


func done_count() -> int:
	return (state().get("done", {}) as Dictionary).size()


func title(id: String) -> String:
	return Kit.text("feat_" + id, str(NAMES.get(id, id)))


func how(id: String) -> String:
	return Kit.text("feat_how_" + id, str(HOW.get(id, "")))


## Pone el progreso (nunca lo baja) y cobra si llega al objetivo.
func _advance(f: Dictionary, id: String, value: int) -> void:
	var prog: Dictionary = f.get("progress", {})
	var now: int = maxi(int(prog.get(id, 0)), mini(value, goal(id)))
	prog[id] = now
	f["progress"] = prog
	var dn: Dictionary = f.get("done", {})
	if now >= goal(id) and not bool(dn.get(id, false)):
		dn[id] = true
		f["done"] = dn
		Save.add_wallet(reward(id))
		_announce(id)
		unlocked.emit(id)


func _on_event(entry: Dictionary) -> void:
	var ev: String = str(entry.get("event", ""))
	if ev != "level_start" and ev != "level_complete" and ev != "death":
		return
	## Los bots de las pruebas y las capturas no cuentan.
	if (UI.test_mode or QA.enabled or bool(get_meta("off", false))) and not bool(get_meta("count_in_tests", false)):
		return
	var f: Dictionary = state()
	if ev == "level_start":
		_level_deaths = 0
		_advance(f, "play_20", progress("play_20") + 1)
		var days: Array = f.get("days", [])
		var today: int = Save.today()
		if not days.has(today):
			days.append(today)
			if days.size() > 30:
				days.pop_front()
		f["days"] = days
		_advance(f, "days_3", days.size())
	elif ev == "death":
		_level_deaths += 1
		f["streak"] = 0
	else:
		var deaths: int = maxi(int(entry.get("deaths", 0)), _level_deaths)
		var stars: int = int(entry.get("stars", 0))
		_advance(f, "first_win", 1)
		_advance(f, "levels_10", progress("levels_10") + 1)
		if deaths == 0:
			_advance(f, "flawless", 1)
			f["streak"] = int(f.get("streak", 0)) + 1
			_advance(f, "streak_5", int(f["streak"]))
		else:
			f["streak"] = 0
		if deaths >= 3:
			_advance(f, "comeback", 1)
		if stars >= 3:
			_advance(f, "stars_3", 1)
		## Estrellas y niveles del propio guardado (lo mejor de cada nivel); el nivel extra del reto
		## del dia no cuenta para "todos los niveles".
		var st: Dictionary = Save.progress().get("stars", {}) if not Kit.is_extra() else {}
		var total: int = 0
		var full: int = 0
		for k: Variant in st:
			total += int(st[k])
			if int(st[k]) >= 3:
				full += 1
		var lvl: int = int(entry.get("level", Kit.level_index))
		if stars > int(st.get(str(lvl), 0)):
			total += stars - int(st.get(str(lvl), 0))
			if stars >= 3:
				full += 1
		_advance(f, "stars_30", total)
		_advance(f, "all_stars", full)
		if not Kit.is_extra():
			_advance(f, "all_levels", maxi(Save.unlocked_count() - 1, lvl + 1))
		if Twist.daily_done():
			_advance(f, "daily", 1)
		_level_deaths = 0
	_store(f)


## Los modos de juego (maraton y contrarreloj) avisan aqui con el progreso que llevan.
func mode_event(id: String, value: int) -> void:
	if (UI.test_mode or QA.enabled or bool(get_meta("off", false))) and not bool(get_meta("count_in_tests", false)):
		return
	var f: Dictionary = state()
	_advance(f, id, value)
	_store(f)


func _announce(id: String) -> void:
	if UI.test_mode:
		return
	Audio.play("powerup")
	var tree: SceneTree = get_tree()
	if tree == null or tree.current_scene == null:
		return
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 55
	tree.current_scene.add_child(layer)
	var size: Vector2 = get_viewport().get_visible_rect().size
	var text: String = Kit.text("feat_unlocked", "\u00a1Logro! {n}  +{c}").replace("{n}", title(id)).replace("{c}", str(reward(id)))
	UI.float_text(layer, Vector2(size.x * 0.5, size.y * 0.22), text.left(48), UI.colors["acento"], 38)
