class_name SurvivalDungeon
extends RefCounted
## La Guarida (15 nov, «el de supervivencia tiene sus mazmorras»): mazmorra de pisos sin fin de la
## supervivencia. Se abre al despejar 3 zonas del mapa. Cada piso es una zona ya vista pero casi a
## oscuras (dia corto, noche larga), con mas bestias y menos comida: aguantar la noche es pasar de piso.
## Premio por piso y cofre cada 5. Va como nivel extra (no toca estrellas ni desbloqueos del mapa).
## Se guarda en Save.meta()["sv_dungeon"].

const INDEX: int = 9300
const OPEN_AFTER: int = 3

static var active: bool = false


static func enabled() -> bool:
	return Genres.current() == "survival" and Kit.level_count() >= OPEN_AFTER


static func unlocked() -> bool:
	return enabled() and Save.unlocked_count() > OPEN_AFTER


static func _m() -> Dictionary:
	var meta: Dictionary = Save.meta()
	if not meta.get("sv_dungeon") is Dictionary:
		meta["sv_dungeon"] = {"floor": 1, "best": 0}
	return meta["sv_dungeon"]


static func floor_n() -> int:
	return int(_m().get("floor", 1))


static func best() -> int:
	return int(_m().get("best", 0))


static func reward(n: int) -> int:
	return (50 + 15 * n) * (4 if n % 5 == 0 else 1)


static func floor_level(n: int) -> Dictionary:
	var levels: Array = Kit.config.get("levels", [])
	var lv: Dictionary = (levels[(n - 1) % levels.size()] as Dictionary).duplicate(true)
	lv["name"] = Kit.text("dungeon_floor", "La Guarida: piso {n}").format({"n": n})
	lv["goal"] = "noches"
	lv["nights"] = 1
	lv["day"] = maxi(10, 24 - n)
	lv["night"] = 34 + mini(n, 12) * 3
	lv["wolves"] = int(lv.get("wolves", 1)) + 1 + n / 3
	lv["hunger"] = float(lv.get("hunger", 0.5)) * (1.0 + 0.04 * float(mini(n, 15)))
	lv["thirst"] = float(lv.get("thirst", 0.7)) * (1.0 + 0.04 * float(mini(n, 15)))
	lv.erase("par")
	return lv


static func play() -> bool:
	if not unlocked():
		return false
	Kit.extra_level = floor_level(floor_n())
	Kit.extra_index = INDEX
	Kit.level_index = INDEX
	active = true
	QA.log_event("sv_dungeon", {"floor": floor_n()})
	UI.goto(UI.game_scene())
	return true


static func stop() -> void:
	if not active:
		return
	active = false
	if Kit.extra_index == INDEX:
		Kit.extra_index = -1
		Kit.extra_level = {}
		Kit.level_index = 0


## Fin de un piso: guarda y da el premio. Devuelve el texto del cartel ("" si no era la Guarida).
static func on_end(won: bool) -> String:
	if not active or not Kit.is_extra() or Kit.extra_index != INDEX:
		return ""
	var m: Dictionary = _m()
	var n: int = floor_n()
	var note: String
	if won:
		var prize: int = reward(n)
		Save.add_wallet(prize)
		m["best"] = maxi(best(), n)
		m["floor"] = n + 1
		Kit.extra_level = floor_level(n + 1)
		note = Kit.text("dungeon_won", "¡Piso {n} superado! +{c} monedas. Abajo te espera el piso {k}.").format({"n": n, "c": prize, "k": n + 1})
	else:
		note = Kit.text("dungeon_lost", "La Guarida te ha parado en el piso {n}. Fabrica mejores armas y vuelve.").format({"n": n})
	Save.save_data()
	QA.log_event("sv_dungeon_end", {"floor": n, "won": won})
	return note
