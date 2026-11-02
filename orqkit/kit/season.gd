extends Node
## Misiones y pase de temporada. Autoload "Season".
## 1 - Misiones: 3 diarias y 3 semanales, elegidas con la fecha (las mismas para todos ese dia).
##     Se cuentan solas escuchando los eventos de partida (QA.logged): partidas, niveles superados,
##     estrellas, niveles perfectos, monedas recogidas y enemigos. Al completarlas se cobran:
##     monedas para la tienda y XP del pase.
## 2 - Pase de temporada: dura un mes (UTC). 20 niveles de 500 XP. Cada nivel da un premio gratis
##     (monedas) y otro premium (mas monedas y aspectos exclusivos en el 10 y el 20). El premium se
##     desbloquea con la compra "pase" (Store) y vale los premios ya ganados de esa temporada.
## 3 - Cada estrella ganada da 10 XP. Todo se guarda en Save.meta()["season"].

signal changed

const TIER_XP: int = 500
const TIERS: int = 20
const STAR_XP: int = 10
const DAILY_REWARD: Dictionary = {"coins": 40, "xp": 100}
const WEEKLY_REWARD: Dictionary = {"coins": 150, "xp": 400}
## tipo -> [objetivo diario, objetivo semanal]
const KINDS: Dictionary = {
	"play": [5, 25], "win": [3, 15], "stars": [6, 30], "perfect": [1, 6], "coins": [20, 120], "kills": [25, 150],
}
const COIN_GENRES: Array[String] = ["platformer", "runner", "flyer", "snake", "breakout", "race", "lanes", "shooter", "jumper"]
const KILL_GENRES: Array[String] = ["horde", "shooter", "tower", "brawl"]
const SKIN_TIERS: Dictionary = {10: "estelar", 20: "aurora"}

## Para las pruebas: dia (dias desde 1970) y momento fijos.
var fake_day: int = -1


func _ready() -> void:
	QA.logged.connect(_on_event)


func day() -> int:
	return fake_day if fake_day >= 0 else Save.today()


func week() -> int:
	## Semanas que empiezan en lunes (el 1-1-1970 fue jueves).
	return int(floor(float(day() + 3) / 7.0))


func season_id() -> String:
	var d: Dictionary = Time.get_date_dict_from_unix_time(day() * 86400)
	return "%04d-%02d" % [int(d["year"]), int(d["month"])]


## Segundos que quedan de temporada (fin de mes UTC).
func season_left() -> int:
	var d: Dictionary = Time.get_date_dict_from_unix_time(day() * 86400)
	var y: int = int(d["year"])
	var m: int = int(d["month"]) + 1
	if m > 12:
		m = 1
		y += 1
	var end: int = Time.get_unix_time_from_datetime_dict({"year": y, "month": m, "day": 1, "hour": 0, "minute": 0, "second": 0})
	var now: int = int(Time.get_unix_time_from_system()) if fake_day < 0 else day() * 86400
	return maxi(end - now, 0)


func state() -> Dictionary:
	var m: Dictionary = Save.meta()
	var st: Dictionary = m.get("season", {})
	var dirty: bool = false
	if int(st.get("day", -1)) != day():
		st["day"] = day()
		st["daily"] = _pick(day(), 0)
		dirty = true
	if int(st.get("week", -1)) != week():
		st["week"] = week()
		st["weekly"] = _pick(week(), 1)
		dirty = true
	if str(st.get("id", "")) != season_id():
		st["id"] = season_id()
		st["xp"] = 0
		st["claimed_free"] = []
		st["claimed_premium"] = []
		st["premium"] = false
		dirty = true
	if dirty:
		m["season"] = st
		Save.data["meta"] = m
		Save.save_data()
	return st


## 3 misiones distintas, elegidas con la fecha y solo de tipos que tienen sentido en este genero.
func _pick(seed_n: int, slot: int) -> Array:
	var kinds: Array[String] = ["play", "win", "stars", "perfect"]
	if Genres.current() in COIN_GENRES:
		kinds.append("coins")
	if Genres.current() in KILL_GENRES:
		kinds.append("kills")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash("%s:%d:%d" % [str(Kit.config.get("title", "")), seed_n, slot])
	var out: Array = []
	while out.size() < 3 and not kinds.is_empty():
		var k: String = kinds.pop_at(rng.randi_range(0, kinds.size() - 1))
		out.append({"kind": k, "goal": int((KINDS[k] as Array)[slot]), "have": 0, "claimed": false})
	return out


func missions(weekly: bool = false) -> Array:
	return state().get("weekly" if weekly else "daily", [])


func mission_text(m: Dictionary) -> String:
	var n: int = int(m.get("goal", 0))
	match str(m.get("kind", "")):
		"play":
			return Kit.text("m_play", "Juega {n} partidas").format({"n": n})
		"win":
			return Kit.text("m_win", "Supera {n} niveles").format({"n": n})
		"stars":
			return Kit.text("m_stars", "Consigue {n} estrellas").format({"n": n})
		"perfect":
			return Kit.text("m_perfect", "Supera {n} niveles con 3 estrellas").format({"n": n})
		"coins":
			return Kit.text("m_coins", "Recoge {n} monedas").format({"n": n})
		"kills":
			return Kit.text("m_kills", "Derrota {n} enemigos").format({"n": n})
	return ""


## Misiones completadas sin cobrar (para el aviso del boton).
func pending() -> int:
	var n: int = 0
	for weekly: bool in [false, true]:
		for m: Variant in missions(weekly):
			var d: Dictionary = m
			if int(d["have"]) >= int(d["goal"]) and not bool(d["claimed"]):
				n += 1
	n += claimable_tiers().size()
	return n


func claim_mission(weekly: bool, index: int) -> Dictionary:
	var st: Dictionary = state()
	var list: Array = st.get("weekly" if weekly else "daily", [])
	if index < 0 or index >= list.size():
		return {}
	var m: Dictionary = list[index]
	if int(m["have"]) < int(m["goal"]) or bool(m["claimed"]):
		return {}
	m["claimed"] = true
	var reward: Dictionary = WEEKLY_REWARD if weekly else DAILY_REWARD
	st["xp"] = int(st.get("xp", 0)) + int(reward["xp"])
	Save.add_wallet(int(reward["coins"]))
	QA.log_event("mission_claim", {"kind": m["kind"], "weekly": weekly})
	changed.emit()
	return reward


# ------------------------------------------------------------------ pase de temporada

func xp() -> int:
	return int(state().get("xp", 0))


func tier() -> int:
	return mini(xp() / TIER_XP, TIERS)


func premium() -> bool:
	return bool(state().get("premium", false))


func unlock_premium() -> void:
	var st: Dictionary = state()
	st["premium"] = true
	Save.save_data()
	QA.log_event("pass_premium")
	changed.emit()


## Premio de un nivel del pase: {"coins", "skin"}.
func reward(t: int, is_premium: bool) -> Dictionary:
	if is_premium:
		return {"coins": 60 + t * 10, "skin": str(SKIN_TIERS.get(t, ""))}
	return {"coins": 20 + t * 5, "skin": ""}


## Niveles alcanzados con premio sin cobrar: [[nivel, premium], ...].
func claimable_tiers() -> Array:
	var st: Dictionary = state()
	var out: Array = []
	for t: int in range(1, tier() + 1):
		if not (st.get("claimed_free", []) as Array).has(t):
			out.append([t, false])
		if bool(st.get("premium", false)) and not (st.get("claimed_premium", []) as Array).has(t):
			out.append([t, true])
	return out


func claim_tier(t: int, is_premium: bool) -> Dictionary:
	var st: Dictionary = state()
	if t < 1 or t > tier() or (is_premium and not premium()):
		return {}
	var key: String = "claimed_premium" if is_premium else "claimed_free"
	var done: Array = st.get(key, [])
	if done.has(t):
		return {}
	done.append(t)
	st[key] = done
	var r: Dictionary = reward(t, is_premium)
	Save.add_wallet(int(r["coins"]))
	if str(r["skin"]) != "":
		Save.grant_skin(str(r["skin"]))
	QA.log_event("pass_claim", {"tier": t, "premium": is_premium})
	changed.emit()
	return r


# ------------------------------------------------------------------ contar

func _on_event(e: Dictionary) -> void:
	var ev: String = str(e.get("event", ""))
	if ev != "level_start" and ev != "level_complete":
		return
	## Los bots de las pruebas y las capturas no cuentan.
	if UI.test_mode and not bool(get_meta("count_in_tests", false)):
		return
	var st: Dictionary = state()
	var adds: Dictionary = {}
	if ev == "level_start":
		adds["play"] = 1
	else:
		var stars: int = int(e.get("stars", 0))
		adds["win"] = 1
		adds["stars"] = stars
		adds["perfect"] = 1 if stars >= 3 else 0
		adds["coins"] = int(e.get("coins", 0))
		adds["kills"] = int(e.get("kills", 0))
		st["xp"] = int(st.get("xp", 0)) + stars * STAR_XP
	for key: String in ["daily", "weekly"]:
		for m: Variant in st.get(key, []):
			var d: Dictionary = m
			d["have"] = mini(int(d["have"]) + int(adds.get(str(d["kind"]), 0)), int(d["goal"]))
	Save.save_data()
	changed.emit()
