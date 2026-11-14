class_name RpgModes
extends RefCounted
## Modos del RPG de heroes (15 nov, como los RPG de coleccion mas jugados): ademas de la campana,
## 1 - Torre de pruebas: pisos sin fin, cada uno mas duro (+9 %); premio por piso y cofre cada 5.
## 2 - Arena: combates contra equipos de otros jugadores (rivales generados con tu misma fuerza y
##     heroes de la coleccion). 5 entradas al dia. Ganar sube puntos de liga (Bronce, Plata, Oro,
##     Platino, Diamante y Leyenda) y perder baja un poco. Premio por victoria segun tu liga.
## Los dos van como nivel extra (no tocan estrellas ni desbloqueos de la campana). Se guarda en
## Save.meta()["rpg_modes"].

const TOWER_INDEX: int = 9100
const ARENA_INDEX: int = 9200
const TICKETS: int = 5
const START_RATING: int = 1000
## [id, nombre, puntos minimos, color, monedas por victoria]
const LEAGUES: Array = [
	["bronce", "Bronce", 0, "#cd7f32", 60], ["plata", "Plata", 1100, "#cfd8dc", 80], ["oro", "Oro", 1250, "#ffd447", 110],
	["platino", "Platino", 1450, "#7fe7ff", 150], ["diamante", "Diamante", 1700, "#b388ff", 200], ["leyenda", "Leyenda", 2000, "#ff6b5b", 260]]
const RIVAL_NAMES: Array[String] = ["Kairo", "Nyra", "Bastian", "Lumi", "Draven", "Selka", "Orrin", "Mavi", "Tarek", "Ylva", "Zorak", "Ines",
	"Rook", "Alba", "Fenn", "Cyra", "Odo", "Vela", "Garr", "Mina"]

static var active: String = ""
static var rival: Dictionary = {}


static func enabled() -> bool:
	return Heroes.enabled() and not (Kit.config.get("levels", []) as Array).is_empty()


static func _m() -> Dictionary:
	var meta: Dictionary = Save.meta()
	if not meta.get("rpg_modes") is Dictionary:
		meta["rpg_modes"] = {"floor": 1, "best_floor": 0, "rating": START_RATING, "best_rating": START_RATING, "tickets": TICKETS,
			"day": "", "wins": 0, "losses": 0}
	var m: Dictionary = meta["rpg_modes"]
	## Entradas de arena: se rellenan cada dia.
	var today: String = Time.get_date_string_from_system()
	if str(m.get("day", "")) != today:
		m["day"] = today
		m["tickets"] = TICKETS
	return m


# ------------------------------------------------------------------ torre

static func floor_n() -> int:
	return int(_m().get("floor", 1))


static func tower_mult(n: int) -> float:
	return 0.85 + 0.09 * float(n)


static func tower_reward(n: int) -> int:
	return (40 + 10 * n) * (5 if n % 5 == 0 else 1)


static func tower_level(n: int) -> Dictionary:
	var levels: Array = Kit.config.get("levels", [])
	var lv: Dictionary = (levels[(n - 1) % levels.size()] as Dictionary).duplicate(true)
	lv["mult"] = float(lv.get("mult", 1.0)) * tower_mult(n)
	lv["potions"] = mini(int(lv.get("potions", 2)), 1)
	lv["name"] = Kit.text("rpg_tower_floor", "Torre: piso {n}").format({"n": n})
	return lv


# ------------------------------------------------------------------ arena

static func rating() -> int:
	return int(_m().get("rating", START_RATING))


static func tickets() -> int:
	return int(_m().get("tickets", TICKETS))


static func league(r: int = -1) -> Array:
	var pts: int = rating() if r < 0 else r
	var out: Array = LEAGUES[0]
	for l: Array in LEAGUES:
		if pts >= int(l[2]):
			out = l
	return out


static func league_name(r: int = -1) -> String:
	var l: Array = league(r)
	return Kit.text("league_" + str(l[0]), str(l[1]))


## Rival de tu nivel: cuatro heroes de la coleccion con la fuerza de tu equipo (algo mas cuanto mas
## alta tu liga). Fijo hasta que juegas contra el.
static func make_rival(seed_v: int = -1) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_v if seed_v >= 0 else (rating() * 31 + int(_m().get("wins", 0)) * 7 + int(_m().get("losses", 0)) * 13)
	var all: Array = Heroes.roster().keys()
	all.sort()
	var ids: Array = []
	while ids.size() < mini(4, all.size()):
		var id: String = str(all[rng.randi_range(0, all.size() - 1)])
		if not ids.has(id):
			ids.append(id)
	var mine: Array = Heroes.team()
	var pw: float = 0.0
	for id: Variant in mine:
		pw += Heroes.power_mult(str(id))
	pw = pw / maxf(1.0, float(mine.size())) * (1.0 + float(Heroes.synergy(mine)["bonus"]))
	var f: float = clampf(0.9 + float(rating() - START_RATING) / 2500.0, 0.85, 1.35) * rng.randf_range(0.92, 1.06)
	return {"name": RIVAL_NAMES[rng.randi_range(0, RIVAL_NAMES.size() - 1)], "heroes": ids, "mult": pw * f,
		"rating": maxi(0, rating() + rng.randi_range(-60, 60))}


static func arena_level(r: Dictionary) -> Dictionary:
	var levels: Array = Kit.config.get("levels", [])
	var lv: Dictionary = (levels[mini(2, levels.size() - 1)] as Dictionary).duplicate(true)
	var rpg: Dictionary = (lv.get("rpg", {}) as Dictionary).duplicate(true)
	var enemies: Dictionary = (rpg.get("enemies", {}) as Dictionary).duplicate(true)
	var roster: Dictionary = Heroes.roster()
	var row: String = ""
	for i: int in (r["heroes"] as Array).size():
		var id: String = str(r["heroes"][i])
		var d: Dictionary = (roster.get(id, {}) as Dictionary).duplicate(true)
		d["ref"] = id
		enemies[str(i + 1)] = d
		row += str(i + 1)
	rpg["enemies"] = enemies
	lv["rpg"] = rpg
	lv["map"] = [row]
	lv["mult"] = float(r["mult"])
	lv["potions"] = 1
	lv["name"] = Kit.text("rpg_arena_vs", "Arena: contra {x}").format({"x": str(r["name"])})
	return lv


# ------------------------------------------------------------------ jugar

static func play(mode: String) -> bool:
	if not enabled():
		return false
	if mode == "arena":
		if tickets() <= 0:
			return false
		rival = make_rival()
		Kit.extra_level = arena_level(rival)
		Kit.extra_index = ARENA_INDEX
	elif mode == "tower":
		Kit.extra_level = tower_level(floor_n())
		Kit.extra_index = TOWER_INDEX
	else:
		stop()
		UI.goto(UI.SCREEN_LEVELS)
		return true
	active = mode
	Kit.level_index = Kit.extra_index
	QA.log_event("rpg_mode", {"mode": mode, "floor": floor_n(), "rating": rating()})
	UI.goto(UI.game_scene())
	return true


static func stop() -> void:
	if active == "":
		return
	active = ""
	if Kit.extra_index == TOWER_INDEX or Kit.extra_index == ARENA_INDEX:
		Kit.extra_index = -1
		Kit.extra_level = {}
		Kit.level_index = 0


## Fin de una partida de torre o arena: guarda el progreso y da el premio. Devuelve el texto para el
## cartel del final ("" si no era de estos modos).
static func on_end(won: bool) -> String:
	if active == "" or not Kit.is_extra():
		return ""
	var m: Dictionary = _m()
	var note: String = ""
	if active == "tower":
		var n: int = floor_n()
		if won:
			var prize: int = tower_reward(n)
			Save.add_wallet(prize)
			m["best_floor"] = maxi(int(m.get("best_floor", 0)), n)
			m["floor"] = n + 1
			Kit.extra_level = tower_level(n + 1)
			note = Kit.text("rpg_tower_won", "¡Piso {n} superado! +{c} monedas").format({"n": n, "c": prize})
		else:
			note = Kit.text("rpg_tower_lost", "El piso {n} te ha parado: mejora tu equipo y vuelve").format({"n": n})
	elif active == "arena":
		m["tickets"] = maxi(0, int(m.get("tickets", TICKETS)) - 1)
		var before: String = league_name()
		var diff: int = int(rival.get("rating", rating())) - rating()
		if won:
			var pts: int = clampi(24 + diff / 20, 12, 36)
			var prize2: int = int(league()[4])
			m["rating"] = rating() + pts
			m["wins"] = int(m.get("wins", 0)) + 1
			Save.add_wallet(prize2)
			note = Kit.text("rpg_arena_won", "¡Victoria! +{p} puntos de liga y +{c} monedas").format({"p": pts, "c": prize2})
		else:
			var lose: int = clampi(14 - diff / 30, 6, 20)
			m["rating"] = maxi(0, rating() - lose)
			m["losses"] = int(m.get("losses", 0)) + 1
			note = Kit.text("rpg_arena_lost", "Derrota: -{p} puntos de liga").format({"p": lose})
		m["best_rating"] = maxi(int(m.get("best_rating", START_RATING)), rating())
		if league_name() != before:
			note += "\n" + Kit.text("rpg_league_up", "¡Nueva liga: {l}!").format({"l": league_name()})
		## Rival nuevo para la siguiente.
		rival = make_rival()
		Kit.extra_level = arena_level(rival)
	Save.save_data()
	QA.log_event("rpg_mode_end", {"mode": active, "won": won, "floor": floor_n(), "rating": rating()})
	return note
