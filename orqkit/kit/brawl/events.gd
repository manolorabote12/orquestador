class_name BrawlEvents
extends RefCounted
## Eventos de la arena (como los juegos de arena: eliges modo y mapa antes de jugar).
## 1 - Los niveles del juego se agrupan por modo (nivel "mode": showdown, survival, ball, turrets).
## 2 - Cada modo ensena su mapa de ahora: el siguiente que no has ganado de ese modo, o, si ya los
##     ganaste todos, uno que rota cada dia. Solo cuentan los niveles desbloqueados.
## 3 - Jugar un evento pone Kit.level_index en ese nivel y abre la partida.

const INFO: Dictionary = {
	"showdown": {"name": "Supervivencia", "desc": "Todos contra todos: queda el último en pie.", "col": "#7fd45f", "icon": "skull"},
	"survival": {"name": "Asalto", "desc": "Oleadas de rivales: aguanta y acaba con todas.", "col": "#ff8a3d", "icon": "star"},
	"ball": {"name": "Atrapabalón", "desc": "3 contra 3: mete el balón en su portería.", "col": "#4fc3ff", "icon": "trophy"},
	"turrets": {"name": "Asedio", "desc": "3 contra 3: tumba su torreta antes que ellos la tuya.", "col": "#d07cff", "icon": "cube"},
}
const ORDER: Array[String] = ["showdown", "ball", "survival", "turrets"]


static func mode_of(lv: Dictionary) -> String:
	var m: String = str(lv.get("mode", "showdown"))
	return m if INFO.has(m) else "showdown"


## {modo: [indices de nivel]} solo con los desbloqueados (al menos el primero de cada modo).
static func by_mode() -> Dictionary:
	var out: Dictionary = {}
	var levels: Array = Kit.config.get("levels", [])
	for i: int in levels.size():
		if not (levels[i] is Dictionary):
			continue
		var m: String = mode_of(levels[i])
		if not out.has(m):
			out[m] = []
		if i < maxi(1, Save.unlocked_count()) or (out[m] as Array).is_empty():
			(out[m] as Array).append(i)
	return out


## Hay eventos (dos modos o mas): si no, se juega como siempre por niveles.
static func available() -> bool:
	return Genres.current() == "brawl" and by_mode().size() >= 2


static func modes() -> Array[String]:
	var bm: Dictionary = by_mode()
	var out: Array[String] = []
	for m: String in ORDER:
		if bm.has(m):
			out.append(m)
	return out


## El mapa de ahora de un modo: el primero sin ganar, o uno que rota cada dia.
static func current(mode: String, day: int = -1) -> int:
	var idx: Array = by_mode().get(mode, [])
	if idx.is_empty():
		return -1
	for i: Variant in idx:
		if int(i) >= Save.unlocked_count() - 1 and int(i) < Save.unlocked_count():
			return int(i)
	var d: int = day if day >= 0 else int(Time.get_unix_time_from_system() / 86400.0)
	return int(idx[d % idx.size()])


static func mode_name(mode: String) -> String:
	return Kit.text("ev_" + mode, str(INFO[mode]["name"]))


static func mode_desc(mode: String) -> String:
	return Kit.text("ev_" + mode + "_desc", str(INFO[mode]["desc"]))


static func map_name(i: int) -> String:
	var levels: Array = Kit.config.get("levels", [])
	return str((levels[i] as Dictionary).get("name", "")) if i >= 0 and i < levels.size() and levels[i] is Dictionary else ""


## Abre la partida del evento.
static func play(mode: String) -> bool:
	var i: int = current(mode)
	if i < 0:
		return false
	Kit.level_index = i
	QA.log_event("event_play", {"mode": mode, "level": i})
	UI.goto(UI.game_scene())
	return true
