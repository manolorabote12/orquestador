class_name TurnsParty
extends RefCounted
## RPG por turnos de equipo (plantilla por datos): lo usan el juego, el bot y el analizador.
## Se activa con "rpg" en game.json o en el nivel ({"preset": "equipo"} o {"party": [...]}); sin
## eso el RPG es el de siempre (TurnsLogic, un heroe).
## 1 - Equipos: tus heroes (party) contra oleadas de enemigos (una fila del mapa por oleada, una
##     letra por enemigo). Cada uno tiene vida, ataque, defensa, velocidad, elemento y habilidades.
## 2 - Turnos por velocidad (barra de turno, como en los RPG de movil): cada tic todos suman su
##     velocidad; el primero que llega a 1000 actua y resta 1000. Lo rapido actua mas veces.
## 3 - Habilidades: a quien (enemy, all_enemies, ally, all_allies, self), cuanto pega (power x
##     ataque), golpes (hits), cura (heal, parte de la vida maxima del objetivo), escudo (shield),
##     estados (effects), quitar lo malo (cleanse), espera (cooldown, en turnos del que la usa) y
##     aviso (telegraph: el turno antes se avisa).
## 4 - Estados: poison (6 % de la vida al empezar su turno), burn (35 % del ataque del que lo
##     puso), regen (+8 %), stun (pierde el turno), taunt (los enemigos le pegan a el), atk_up
##     (x1,4), atk_down (x0,7), def_up (recibe x0,65), def_down (recibe x1,4). Duran "turns" turnos
##     del que los lleva.
## 5 - Elementos: fire > nature > water > fire (x1,3; al reves x0,8); light y dark x1,3 entre si.
## 6 - Dano = ataque x power x elemento x estados x 100 / (100 + defensa) (+-10 % al jugar; el
##     analizador usa el medio). Espinas (thorns): devuelve esa parte del dano recibido.
## 7 - lineup (estilo criaturas): solo pelea el primero vivo de cada lado; al caer sale el siguiente.
## 8 - Entre oleadas: +10 % de vida, sin estados, esperas y barras a cero. Pociones: curan un 40 %
##     a un heroe (gastan el turno). Se gana al acabar las oleadas; se pierde si caen todos.

const METER: float = 1000.0
const ELEM_ADV: Dictionary = {"fire": "nature", "nature": "water", "water": "fire"}
const STATUS: Array[String] = ["poison", "burn", "regen", "stun", "taunt", "atk_up", "atk_down", "def_up", "def_down"]
const BAD: Array[String] = ["poison", "burn", "stun", "atk_down", "def_down"]

## Heroes, enemigos, habilidades y estilos: kit/turns/party_catalog.json (la fabrica lee el mismo
## archivo para comprobar los niveles que hace).
##   Estilos ("rpg": {"preset": "equipo"}); lo del juego o del nivel va encima:
##   equipo: tipo Raid / Summoners War / AFK: cuatro heroes de elementos distintos y enemigos de
##     todos los elementos (el arquero entra en el equipo).
##   criaturas: tipo Pokemon: uno contra uno con lineup, tres criaturas de elementos (fuego, agua,
##     planta) con cuatro movimientos y rivales de los mismos elementos.
const CATALOG_PATH: String = "res://kit/turns/party_catalog.json"
static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
		_data = parsed if parsed is Dictionary else {"default": {"heroes": {}, "enemies": {}, "skills": {}, "party": [], "lineup": false}, "presets": {}}
	return _data


# ------------------------------------------------------------------ catalogo

## \u00bfEste nivel va en modo equipo? (el juego tambien mira game.json -> "rpg").
static func wanted(level: Dictionary) -> bool:
	return level.get("rpg", null) is Dictionary


static func catalog(level: Dictionary) -> Dictionary:
	var cat: Dictionary = (data()["default"] as Dictionary).duplicate(true)
	var extra: Variant = level.get("rpg", {})
	if extra is Dictionary:
		var pr: Variant = (extra as Dictionary).get("preset", "")
		for p: Variant in (pr if pr is Array else [pr]):
			if (data()["presets"] as Dictionary).has(str(p)):
				_merge(cat, data()["presets"][str(p)])
		_merge(cat, extra)
	return cat


static func _merge(cat: Dictionary, extra: Dictionary) -> void:
	for sec: String in ["heroes", "enemies", "skills"]:
		var add: Variant = extra.get(sec, {})
		if add is Dictionary:
			for k: Variant in add:
				if add[k] is Dictionary:
					cat[sec][str(k)] = (add[k] as Dictionary).duplicate(true)
				elif add[k] == null:
					(cat[sec] as Dictionary).erase(str(k))
	if extra.get("party", null) is Array:
		cat["party"] = (extra["party"] as Array).duplicate()
	if extra.has("lineup"):
		cat["lineup"] = bool(extra["lineup"])


# ------------------------------------------------------------------ estado

## level: "map" (oleadas), "rpg" (catalogo), "party" (opcional: quienes van), "hero_level"
## (fuerza del equipo: +6 % por nivel), "mult" (fuerza de los enemigos), "potions".
static func new_state(level: Dictionary) -> Dictionary:
	var cat: Dictionary = catalog(level)
	var ids: Array = level.get("party", cat["party"])
	var lvl: float = 1.0 + 0.06 * float(maxi(0, int(level.get("hero_level", 1)) - 1))
	var heroes: Array = []
	for id: Variant in ids:
		if (cat["heroes"] as Dictionary).has(str(id)) and heroes.size() < 4:
			heroes.append(_unit(cat["heroes"][str(id)], str(id), "hero", lvl))
			heroes[-1]["uid"] = heroes.size()
	return {"cat": cat, "waves": level.get("map", ["W"]), "wave": -1, "heroes": heroes, "enemies": [],
		"mult": float(level.get("mult", 1.0)), "potions": int(level.get("potions", 2)), "lineup": bool(cat["lineup"]),
		"won": false, "lost": false, "turn": 0, "boost": 1.0, "hero_boost": 1.0}


static func _unit(d: Dictionary, id: String, side: String, m: float) -> Dictionary:
	var hp: float = float(d.get("hp", 100.0)) * m
	var cds: Dictionary = {}
	for s: Variant in d.get("skills", []):
		cds[str(s)] = 0
	return {"id": id, "side": side, "name": str(d.get("name", id)), "hp": hp, "max_hp": hp, "atk": float(d.get("atk", 15.0)) * m,
		"def": float(d.get("def", 10.0)), "spd": float(d.get("spd", 100.0)), "element": str(d.get("element", "")),
		"thorns": float(d.get("thorns", 0.0)), "boss": bool(d.get("boss", false)), "look": str(d.get("look", "")),
		"skills": (d.get("skills", []) as Array).duplicate(), "cd": cds, "status": {}, "shield": 0.0, "meter": 0.0,
		"alive": true, "warn": ""}


## Saca la siguiente oleada. false si no quedan (has ganado).
static func next_wave(st: Dictionary) -> bool:
	st["wave"] = int(st["wave"]) + 1
	var waves: Array = st["waves"]
	if int(st["wave"]) >= waves.size():
		st["won"] = true
		return false
	for h: Dictionary in st["heroes"]:
		if bool(h["alive"]):
			if int(st["wave"]) > 0:
				h["hp"] = minf(float(h["max_hp"]), float(h["hp"]) + float(h["max_hp"]) * 0.1)
			h["status"] = {}
			h["shield"] = 0.0
			h["meter"] = 0.0
			h["warn"] = ""
			for s: String in h["cd"]:
				h["cd"][s] = 0
	var list: Array = []
	var row: String = str(waves[int(st["wave"])])
	for i: int in row.length():
		var k: String = row[i]
		if (st["cat"]["enemies"] as Dictionary).has(k):
			var u: Dictionary = _unit(st["cat"]["enemies"][k], k, "enemy", float(st["mult"]))
			u["uid"] = 100 * (int(st["wave"]) + 1) + i
			list.append(u)
	st["enemies"] = list
	return true


static func side(st: Dictionary, s: String) -> Array:
	return st["heroes"] if s == "hero" else st["enemies"]


static func foes(st: Dictionary, u: Dictionary) -> Array:
	return side(st, "enemy" if str(u["side"]) == "hero" else "hero")


static func living(arr: Array) -> Array:
	return arr.filter(func(x: Dictionary) -> bool: return bool(x["alive"]))


## Los que pueden pelear ahora (con lineup, solo el primero vivo).
static func fighters(st: Dictionary, arr: Array) -> Array:
	var al: Array = living(arr)
	if bool(st["lineup"]) and al.size() > 1:
		return [al[0]]
	return al


# ------------------------------------------------------------------ turnos

## Quien actua ahora (suma velocidad hasta que alguien llega a METER). {} si no queda nadie.
static func next_actor(st: Dictionary) -> Dictionary:
	var all: Array = fighters(st, st["heroes"]) + fighters(st, st["enemies"])
	if all.is_empty():
		return {}
	for guard: int in 400:
		var best: Dictionary = {}
		for u: Dictionary in all:
			if float(u["meter"]) >= METER and (best.is_empty() or float(u["meter"]) > float(best["meter"])):
				best = u
		if not best.is_empty():
			best["meter"] = float(best["meter"]) - METER
			return best
		for u2: Dictionary in all:
			u2["meter"] = float(u2["meter"]) + float(u2["spd"])
	return all[0]


## Los proximos n en actuar (para la barra de turnos), sin tocar la partida.
static func preview_order(st: Dictionary, n: int) -> Array:
	var all: Array = fighters(st, st["heroes"]) + fighters(st, st["enemies"])
	var meters: Array = all.map(func(u: Dictionary) -> float: return float(u["meter"]))
	var out: Array = []
	for guard: int in 600:
		if out.size() >= n or all.is_empty():
			break
		var bi: int = -1
		for i: int in all.size():
			if float(meters[i]) >= METER and (bi < 0 or float(meters[i]) > float(meters[bi])):
				bi = i
		if bi >= 0:
			meters[bi] = float(meters[bi]) - METER
			out.append(all[bi])
			continue
		for i2: int in all.size():
			meters[i2] = float(meters[i2]) + float(all[i2]["spd"])
	return out


## Habilidades listas de una unidad (sin espera).
static func ready_skills(st: Dictionary, u: Dictionary) -> Array:
	return (u["skills"] as Array).filter(func(s: Variant) -> bool: return int(u["cd"].get(str(s), 0)) <= 0)


static func skill(st: Dictionary, id: String) -> Dictionary:
	return (st["cat"]["skills"] as Dictionary).get(id, {"target": "enemy", "power": 1.0})


## Inicio del turno de u: venenos, quemaduras y regeneracion. Devuelve los eventos y si pierde el
## turno (aturdido o muerto por lo que lleva).
static func start_turn(st: Dictionary, u: Dictionary) -> Dictionary:
	var ev: Array = []
	var stt: Dictionary = u["status"]
	if stt.has("poison"):
		ev.append_array(_hurt(st, u, float(u["max_hp"]) * 0.06, "poison"))
	if stt.has("burn") and bool(u["alive"]):
		ev.append_array(_hurt(st, u, float(stt["burn"].get("value", 5.0)), "burn"))
	if stt.has("regen") and bool(u["alive"]):
		var before: float = float(u["hp"])
		u["hp"] = minf(float(u["max_hp"]), before + float(u["max_hp"]) * 0.08)
		ev.append({"type": "heal", "unit": u, "amount": float(u["hp"]) - before})
	var skip: bool = not bool(u["alive"]) or stt.has("stun")
	if stt.has("stun") and bool(u["alive"]):
		ev.append({"type": "stunned", "unit": u})
	return {"events": ev, "skip": skip}


## Fin del turno: bajan esperas y estados; avisa si la habilidad con aviso queda lista.
static func end_turn(st: Dictionary, u: Dictionary) -> Array:
	var ev: Array = []
	for s: String in u["cd"]:
		u["cd"][s] = maxi(0, int(u["cd"][s]) - 1)
	var stt: Dictionary = u["status"]
	for k: String in stt.keys():
		stt[k]["turns"] = int(stt[k]["turns"]) - 1
		if int(stt[k]["turns"]) <= 0:
			stt.erase(k)
	u["warn"] = ""
	for s2: Variant in u["skills"]:
		if bool(skill(st, str(s2)).get("telegraph", false)) and int(u["cd"][str(s2)]) <= 0 and bool(u["alive"]):
			u["warn"] = str(s2)
			ev.append({"type": "warn", "unit": u, "skill": str(s2)})
	st["turn"] = int(st["turn"]) + 1
	_check(st)
	return ev


## Usa una habilidad. target: la unidad elegida (para enemy/ally) o {}. rng: +-10 % o null.
static func use_skill(st: Dictionary, u: Dictionary, sid: String, target: Dictionary, rng: RandomNumberGenerator) -> Array:
	var sk: Dictionary = skill(st, sid)
	var ev: Array = [{"type": "skill", "unit": u, "skill": sid}]
	u["cd"][sid] = int(sk.get("cooldown", 0)) + (1 if int(sk.get("cooldown", 0)) > 0 else 0)
	var targets: Array = targets_for(st, u, sid, target)
	for t: Dictionary in targets:
		if float(sk.get("power", 0.0)) > 0.0:
			for h: int in int(sk.get("hits", 1)):
				if not bool(t["alive"]):
					break
				var dmg: float = damage(st, u, t, float(sk["power"])) * _var(rng)
				ev.append_array(_hurt(st, t, dmg, "hit", u))
				if float(t["thorns"]) > 0.0 and bool(u["alive"]):
					ev.append_array(_hurt(st, u, dmg * float(t["thorns"]), "thorns"))
				if float(sk.get("drain", 0.0)) > 0.0 and bool(u["alive"]):
					var b0: float = float(u["hp"])
					u["hp"] = minf(float(u["max_hp"]), b0 + dmg * float(sk["drain"]))
					ev.append({"type": "heal", "unit": u, "amount": float(u["hp"]) - b0})
		if float(sk.get("heal", 0.0)) > 0.0 and bool(t["alive"]):
			var b1: float = float(t["hp"])
			t["hp"] = minf(float(t["max_hp"]), b1 + float(t["max_hp"]) * float(sk["heal"]))
			ev.append({"type": "heal", "unit": t, "amount": float(t["hp"]) - b1})
		if float(sk.get("shield", 0.0)) > 0.0 and bool(t["alive"]):
			t["shield"] = float(t["shield"]) + float(t["max_hp"]) * float(sk["shield"])
			ev.append({"type": "shield", "unit": t, "amount": float(t["shield"])})
		if bool(sk.get("cleanse", false)):
			for b: String in BAD:
				(t["status"] as Dictionary).erase(b)
		for ef: Dictionary in sk.get("effects", []):
			if not bool(t["alive"]):
				continue
			var ch: float = float(ef.get("chance", 1.0))
			if (rng == null and ch < 0.5) or (rng != null and rng.randf() > ch):
				continue
			var stn: String = str(ef["status"])
			var val: float = float(ef.get("value", float(u["atk"]) * 0.35))
			## El que va justo despues de ponerlo cuenta su turno: +1 si se pone a uno mismo.
			var turns: int = int(ef.get("turns", 2)) + (1 if t == u else 0)
			t["status"][stn] = {"turns": turns, "value": val}
			ev.append({"type": "status", "unit": t, "status": stn})
	_check(st)
	return ev


## A quien le toca una habilidad (con provocar: los golpes a uno van al que provoca).
static func targets_for(st: Dictionary, u: Dictionary, sid: String, target: Dictionary) -> Array:
	var sk: Dictionary = skill(st, sid)
	var mine: Array = fighters(st, side(st, str(u["side"])))
	var theirs: Array = fighters(st, foes(st, u))
	match str(sk.get("target", "enemy")):
		"self":
			return [u]
		"all_allies":
			return mine
		"ally":
			if not target.is_empty() and bool(target["alive"]) and mine.has(target):
				return [target]
			return [lowest(mine)] if not mine.is_empty() else []
		"all_enemies":
			return theirs
		_:
			for t: Dictionary in theirs:
				if (t["status"] as Dictionary).has("taunt"):
					return [t]
			if not target.is_empty() and bool(target["alive"]) and theirs.has(target):
				return [target]
			return [lowest(theirs)] if not theirs.is_empty() else []


static func lowest(arr: Array) -> Dictionary:
	var best: Dictionary = {}
	for x: Dictionary in arr:
		if bool(x["alive"]) and (best.is_empty() or float(x["hp"]) / float(x["max_hp"]) < float(best["hp"]) / float(best["max_hp"])):
			best = x
	return best


static func elem_mult(a: String, d: String) -> float:
	if a == "" or d == "":
		return 1.0
	if str(ELEM_ADV.get(a, "")) == d:
		return 1.3
	if str(ELEM_ADV.get(d, "")) == a:
		return 0.8
	if (a == "light" and d == "dark") or (a == "dark" and d == "light"):
		return 1.3
	return 1.0


## Dano medio de u a t con esa potencia (sin el +-10 %).
static func damage(st: Dictionary, u: Dictionary, t: Dictionary, power: float) -> float:
	var m: float = float(u["atk"]) * power * elem_mult(str(u["element"]), str(t["element"]))
	var su: Dictionary = u["status"]
	var stt: Dictionary = t["status"]
	if su.has("atk_up"):
		m *= 1.4
	if su.has("atk_down"):
		m *= 0.7
	if stt.has("def_up"):
		m *= 0.65
	if stt.has("def_down"):
		m *= 1.4
	m *= float(st["boost"]) if str(u["side"]) == "enemy" else float(st["hero_boost"])
	return m * 100.0 / (100.0 + float(t["def"]))


static func _hurt(st: Dictionary, t: Dictionary, amount: float, kind: String, from: Dictionary = {}) -> Array:
	var a: float = amount
	if float(t["shield"]) > 0.0:
		var ab: float = minf(float(t["shield"]), a)
		t["shield"] = float(t["shield"]) - ab
		a -= ab
	t["hp"] = float(t["hp"]) - a
	var ev: Array = [{"type": kind, "unit": t, "amount": amount, "from": from}]
	if float(t["hp"]) <= 0.0 and bool(t["alive"]):
		t["hp"] = 0.0
		t["alive"] = false
		t["status"] = {}
		ev.append({"type": "ko", "unit": t})
	return ev


static func _check(st: Dictionary) -> void:
	if living(st["heroes"]).is_empty():
		st["lost"] = true


static func wave_clear(st: Dictionary) -> bool:
	return living(st["enemies"]).is_empty()


## Pocion: cura un 40 % a un heroe (gasta el turno del que la usa).
static func use_potion(st: Dictionary, u: Dictionary, target: Dictionary) -> Array:
	if int(st["potions"]) <= 0:
		return []
	var t: Dictionary = target if not target.is_empty() and bool(target["alive"]) else lowest(living(st["heroes"]))
	if t.is_empty():
		return []
	st["potions"] = int(st["potions"]) - 1
	var b: float = float(t["hp"])
	t["hp"] = minf(float(t["max_hp"]), b + float(t["max_hp"]) * 0.4)
	return [{"type": "potion", "unit": u}, {"type": "heal", "unit": t, "amount": float(t["hp"]) - b}]


# ------------------------------------------------------------------ cabeza (bot, rival y AUTO)

## La mejor jugada de u: ["skill", id, objetivo] o ["potion", "", objetivo]. La misma cabeza para
## los enemigos, el bot y el boton AUTO: puntua cada habilidad lista por lo que consigue.
static func think(st: Dictionary, u: Dictionary) -> Array:
	var best: Array = []
	var bs: float = -INF
	var mine: Array = fighters(st, side(st, str(u["side"])))
	var theirs: Array = fighters(st, foes(st, u))
	if theirs.is_empty():
		return ["skill", str((u["skills"] as Array)[0]) if not (u["skills"] as Array).is_empty() else "", {}]
	for sid: Variant in ready_skills(st, u):
		var sk: Dictionary = skill(st, str(sid))
		var tgs: Array = []
		match str(sk.get("target", "enemy")):
			"enemy":
				tgs = theirs
			"ally":
				tgs = mine
			_:
				tgs = [{}]
		for tg: Dictionary in tgs:
			var sc: float = _score(st, u, str(sid), tg)
			if sc > bs:
				bs = sc
				best = ["skill", str(sid), tg]
	if str(u["side"]) == "hero" and int(st["potions"]) > 0:
		var low: Dictionary = lowest(living(st["heroes"]))
		if not low.is_empty() and float(low["hp"]) < float(low["max_hp"]) * 0.3:
			var heal_ready: bool = false
			for sid2: Variant in ready_skills(st, u):
				heal_ready = heal_ready or float(skill(st, str(sid2)).get("heal", 0.0)) > 0.0
			if not heal_ready and bs < float(low["max_hp"]) * 0.5:
				best = ["potion", "", low]
	return best


static func _score(st: Dictionary, u: Dictionary, sid: String, tg: Dictionary) -> float:
	var sk: Dictionary = skill(st, sid)
	var tgs: Array = targets_for(st, u, sid, tg)
	var sc: float = 0.0
	var danger: bool = false
	for e: Dictionary in fighters(st, foes(st, u)):
		danger = danger or bool(e["boss"]) or str(e["warn"]) != ""
	for t: Dictionary in tgs:
		var mine: bool = str(t["side"]) == str(u["side"])
		if float(sk.get("power", 0.0)) > 0.0 and not mine:
			var dmg: float = damage(st, u, t, float(sk["power"])) * float(sk.get("hits", 1))
			sc += minf(dmg, float(t["hp"]))
			if dmg >= float(t["hp"]):
				sc += 30.0 + float(t["atk"]) * 2.0
			sc += dmg * float(sk.get("drain", 0.0)) * 0.5
		if float(sk.get("heal", 0.0)) > 0.0 and mine:
			var miss: float = float(t["max_hp"]) - float(t["hp"])
			var h: float = minf(miss, float(t["max_hp"]) * float(sk["heal"]))
			sc += h * (1.6 if float(t["hp"]) < float(t["max_hp"]) * 0.5 else 0.5)
		if float(sk.get("shield", 0.0)) > 0.0 and mine:
			sc += float(t["max_hp"]) * float(sk["shield"]) * 0.6
		if bool(sk.get("cleanse", false)) and mine:
			for b: String in BAD:
				if (t["status"] as Dictionary).has(b):
					sc += 25.0
		for ef: Dictionary in sk.get("effects", []):
			var s: String = str(ef["status"])
			var turns: float = float(ef.get("turns", 2))
			if (t["status"] as Dictionary).has(s):
				continue
			match s:
				"stun":
					sc += float(t["atk"]) * (3.0 if bool(t["boss"]) or str(t["warn"]) != "" else 1.5)
				"poison":
					sc += float(t["max_hp"]) * 0.06 * turns * 0.8
				"burn":
					sc += float(u["atk"]) * 0.35 * turns * 0.8
				"regen":
					sc += float(t["max_hp"]) * 0.08 * turns * 0.5
				"taunt":
					sc += 45.0 if danger and float(u["hp"]) > float(u["max_hp"]) * 0.5 else 3.0
				"atk_up":
					sc += float(t["atk"]) * 0.4 * turns * 0.7
				"def_up":
					sc += (35.0 if danger else 8.0) * (1.0 if float(t["hp"]) > float(t["max_hp"]) * 0.3 else 2.0)
				"atk_down":
					sc += float(t["atk"]) * 0.3 * turns
				"def_down":
					sc += float(u["atk"]) * 0.4 * turns * 0.7
	return sc


# ------------------------------------------------------------------ simulacion (analizador)

## Partida entera con la misma cabeza para los dos lados y dano medio. pessimistic: tu equipo
## pega un 10 % menos y los enemigos un 10 % mas.
static func simulate(level: Dictionary, pessimistic: bool = false) -> Dictionary:
	var st: Dictionary = new_state(level)
	if pessimistic:
		st["boost"] = 1.1
		st["hero_boost"] = 0.9
	next_wave(st)
	var turns: int = 0
	while not bool(st["won"]) and not bool(st["lost"]) and turns < 900:
		play_turn(st, null)
		turns += 1
	var hp: float = 0.0
	var mx: float = 0.0
	for h: Dictionary in st["heroes"]:
		hp += float(h["hp"])
		mx += float(h["max_hp"])
	return {"won": bool(st["won"]), "hp_left": hp / maxf(1.0, mx), "turns": turns,
		"alive": living(st["heroes"]).size(), "potions": int(st["potions"])}


## Un turno entero con la cabeza (para la simulacion y para pruebas).
static func play_turn(st: Dictionary, rng: RandomNumberGenerator) -> Array:
	var u: Dictionary = next_actor(st)
	if u.is_empty():
		return []
	var ev: Array = []
	var s: Dictionary = start_turn(st, u)
	ev.append_array(s["events"])
	if not bool(s["skip"]):
		var a: Array = think(st, u)
		if not a.is_empty():
			if str(a[0]) == "potion":
				ev.append_array(use_potion(st, u, a[2]))
			else:
				ev.append_array(use_skill(st, u, str(a[1]), a[2], rng))
	ev.append_array(end_turn(st, u))
	if not bool(st["lost"]) and wave_clear(st):
		next_wave(st)
		ev.append({"type": "wave"})
	return ev


static func _var(rng: RandomNumberGenerator) -> float:
	return 1.0 if rng == null else rng.randf_range(0.9, 1.1)


## Analizador del modo equipo: oleadas validas y la partida se gana con dano medio (con al menos
## un 25 % de vida del equipo) y con mala suerte.
static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var cat: Dictionary = catalog(level)
	var waves: Array = level.get("map", [])
	var n: int = 0
	if waves.size() < 1 or waves.size() > 8:
		issues.append("turns_waves")
	for w: Variant in waves:
		var row: String = str(w)
		if row.length() < 1 or row.length() > 5:
			if not issues.has("turns_wave_size"):
				issues.append("turns_wave_size")
		for c: String in row:
			if not (cat["enemies"] as Dictionary).has(c) and not issues.has("turns_bad_enemy"):
				issues.append("turns_bad_enemy")
		n += row.length()
	var st: Dictionary = new_state(level)
	if (st["heroes"] as Array).is_empty():
		issues.append("turns_no_party")
	for h: Dictionary in st["heroes"]:
		for s: Variant in h["skills"]:
			if not (cat["skills"] as Dictionary).has(str(s)) and not issues.has("turns_bad_skill"):
				issues.append("turns_bad_skill")
	var sim: Dictionary = {}
	if issues.is_empty():
		sim = simulate(level)
		var bad: Dictionary = simulate(level, true)
		if not bool(sim["won"]) or float(sim["hp_left"]) < 0.25 or not bool(bad["won"]):
			issues.append("turns_too_hard")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": n, "enemies": n, "enemy_problems": [], "sim": sim}
