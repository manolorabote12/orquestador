extends RefCounted
## Reino (estrategia tipo Kingshot / Whiteout Survival): reglas, simulacion, batallas, bot y analizador.
## 1 - La ciudad: castillo (manda: ningun edificio pasa de su nivel), granja, aserradero y cantera
##     (producen solos), cuartel, establo y arqueria (entrenan soldados SOLOS y sin parar mientras
##     haya comida: el ejercito crece en tiempo real). Un constructor: una mejora a la vez, con tiempo.
## 2 - Tropas con piedra, papel, tijera: lanceros ganan a jinetes, jinetes a arqueros y arqueros a
##     lanceros (x1,5 de dano; al reves x0,75). Batalla por rondas; la mitad de los caidos vuelven
##     heridos y curados (como en el hospital de estos juegos).
## 3 - El mapa: campamentos en orden; el ultimo es el jefe. Ganarlos da recursos y heroes (mas
##     ataque a un tipo de tropa). Se gana al derrotar al jefe.
## 4 - Ayuda gratis cada 20 s (acelera la obra un 30 %) y, en el juego, terminar la obra con un anuncio.
## 5 - Todo por datos: kit/realm/realm_catalog.json + levels[i]["realm"]. Los campamentos del nivel
##     ("camps": [{"at", "str", "mix", "reward", "hero", "name"}]) se miden contra el ejercito que
##     tendria el bot en ese momento ("at" = parte del par): asi el reto vale con cualquier catalogo.

const CATALOG_PATH: String = "res://kit/realm/realm_catalog.json"
const Rules = preload("res://kit/rules.gd")
const DT: float = 0.5
const BOT_EVERY: float = 1.0
const HELP_EVERY: float = 20.0
const HELP_CUT: float = 0.3
const ROUNDS: int = 12
const TYPES: Array[String] = ["infantry", "cavalry", "archer"]

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
		_data = parsed if parsed is Dictionary else {"default": {"res": {}, "buildings": {}, "troops": {}, "heroes": {}}, "presets": {}}
	return _data


static func catalog(level: Dictionary) -> Dictionary:
	var c: Dictionary = (data()["default"] as Dictionary).duplicate(true)
	var extra: Variant = level.get("realm", {})
	if extra is Dictionary:
		var pr: Variant = (extra as Dictionary).get("preset", "")
		for p: Variant in (pr if pr is Array else [pr]):
			if (data()["presets"] as Dictionary).has(str(p)):
				_merge(c, data()["presets"][str(p)])
		_merge(c, extra)
	return c


static func _merge(c: Dictionary, extra: Dictionary) -> void:
	for sec: String in ["res", "buildings", "troops", "heroes"]:
		var add: Variant = extra.get(sec, {})
		if add is Dictionary:
			for k: Variant in add:
				if add[k] is Dictionary and (c[sec] as Dictionary).has(str(k)):
					var m: Dictionary = (c[sec][str(k)] as Dictionary).duplicate(true)
					m.merge(add[k] as Dictionary, true)
					c[sec][str(k)] = m
	for k2: String in ["realm", "camp_names"]:
		if extra.has(k2):
			c[k2] = extra[k2]


static func building_ids(cat: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for k: Variant in cat["buildings"]:
		ids.append(str(k))
	ids.sort_custom(func(a: String, b: String) -> bool:
		return float(cat["buildings"][a].get("order", 0)) < float(cat["buildings"][b].get("order", 0)) or \
			(float(cat["buildings"][a].get("order", 0)) == float(cat["buildings"][b].get("order", 0)) and a < b))
	return ids


static func center_id(cat: Dictionary) -> String:
	for b: String in building_ids(cat):
		if str(cat["buildings"][b].get("role", "")) == "center":
			return b
	return ""


# ------------------------------------------------------------------ estado

static func new_state(level: Dictionary, with_camps: bool = true) -> Dictionary:
	var cat: Dictionary = catalog(level)
	var st: Dictionary = {"cat": cat, "res": {}, "lv": {}, "queue": {}, "army": {}, "heroes": [], "camps": [], "t": 0.0,
		"won": false, "help_t": 0.0, "fights": 0, "cap": clampi(int(level.get("cap", 6)), 2, 20), "log": []}
	var start: Dictionary = level.get("start", {"food": 200, "wood": 150, "stone": 100})
	for r: Variant in cat["res"]:
		st["res"][str(r)] = float(start.get(str(r), 0.0))
	for b: String in building_ids(cat):
		var role: String = str(cat["buildings"][b].get("role", ""))
		## Al empezar: castillo, produccion y el primer cuartel; los demas, por construir.
		var first_train: bool = role == "train" and _first_train(cat) == b
		st["lv"][b] = 1 if (role == "center" or role == "prod" or first_train) else 0
	for t: String in TYPES:
		st["army"][t] = float((level.get("army", {}) as Dictionary).get(t, 0.0))
	if with_camps:
		st["camps"] = make_camps(level, cat)
		## Las reglas solo en la partida de verdad (la medida de los campamentos es sin ellas).
		st["rules"] = Rules.load_rules(level)
		Rules.hook(st, "on_start")
	return st


static func _first_train(cat: Dictionary) -> String:
	for b: String in building_ids(cat):
		if str(cat["buildings"][b].get("role", "")) == "train":
			return b
	return ""


## Campamentos del nivel, medidos contra el ejercito que tendria el bot sin atacar (simulacion).
static func make_camps(level: Dictionary, cat: Dictionary) -> Array:
	var specs: Array = level.get("camps", [])
	var out: Array = []
	if specs.is_empty():
		return out
	var par: float = maxf(60.0, float(level.get("par", 300.0)))
	var probe: Dictionary = new_state(level, false)
	var marks: Array = []
	for s: Variant in specs:
		marks.append(clampf(float((s as Dictionary).get("at", 0.5)), 0.02, 1.5) * par)
	var snaps: Dictionary = {}
	var next_think: float = 0.0
	var k: int = 0
	var order: Array = range(marks.size())
	order.sort_custom(func(a: int, b: int) -> bool: return float(marks[a]) < float(marks[b]))
	while k < order.size():
		if float(probe["t"]) >= next_think:
			bot_tick(probe, false)
			next_think += BOT_EVERY
		step(probe, DT)
		while k < order.size() and float(probe["t"]) >= float(marks[order[k]]):
			snaps[order[k]] = {"army": total_army(probe), "rate": _income(probe)}
			k += 1
	var names: Array = cat.get("camp_names", [])
	for i: int in specs.size():
		var s2: Dictionary = specs[i]
		var size: float = float(snaps[i]["army"]) * clampf(float(s2.get("str", 0.7)), 0.05, 3.0)
		var mix: Array = s2.get("mix", [1, 1, 1])
		var msum: float = 0.0
		for m: Variant in mix:
			msum += maxf(0.0, float(m))
		var army: Dictionary = {}
		for j: int in TYPES.size():
			army[TYPES[j]] = floorf(size * maxf(0.0, float(mix[j] if j < mix.size() else 0.0)) / maxf(0.001, msum))
		var reward: Dictionary = {}
		var inc: Dictionary = snaps[i]["rate"]
		for r: Variant in inc:
			reward[str(r)] = roundf(float(inc[r]) * 30.0 * clampf(float(s2.get("reward", 1.0)), 0.0, 5.0))
		var nm: String = str(s2.get("name", names[mini(i, names.size() - 1)] if not names.is_empty() else "Campamento"))
		if i == specs.size() - 1 and names.size() > 0 and not s2.has("name"):
			nm = str(names[names.size() - 1])
		out.append({"name": nm, "army": army, "reward": reward, "hero": str(s2.get("hero", "")), "boss": i == specs.size() - 1, "done": false})
	return out


static func total_army(st: Dictionary) -> float:
	var n: float = 0.0
	for t: String in TYPES:
		n += float(st["army"][t])
	return n


## Poder (lo que se ensena): soldados por su fuerza.
static func power(cat: Dictionary, army: Dictionary) -> int:
	var p: float = 0.0
	for t: String in TYPES:
		var d: Dictionary = cat["troops"].get(t, {})
		p += float(army.get(t, 0.0)) * sqrt(float(d.get("hp", 10.0)) * float(d.get("atk", 3.0)))
	return int(round(p))


static func _income(st: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for r: Variant in st["res"]:
		out[str(r)] = 0.0
	for b: Variant in st["lv"]:
		var d: Dictionary = st["cat"]["buildings"][b]
		if str(d.get("role", "")) == "prod":
			out[str(d.get("res", "food"))] = float(out.get(str(d.get("res", "food")), 0.0)) + float(d.get("rate", 1.0)) * float(st["lv"][b])
	return out


# ------------------------------------------------------------------ obras

## Lo que cuesta subir un edificio a su siguiente nivel ({} si no se puede).
static func up_cost(st: Dictionary, b: String) -> Dictionary:
	var d: Dictionary = st["cat"]["buildings"][b]
	var to: int = int(st["lv"][b]) + 1
	var mul: float = 0.5 if to == 1 else pow(float(d.get("growth", 1.6)), float(to - 2))
	var out: Dictionary = {}
	for r: Variant in d.get("cost", {}):
		out[str(r)] = roundf(float(d["cost"][r]) * mul)
	return out


static func up_time(st: Dictionary, b: String) -> float:
	var d: Dictionary = st["cat"]["buildings"][b]
	var to: int = int(st["lv"][b]) + 1
	var mul: float = 0.5 if to == 1 else pow(float(d.get("growth", 1.6)) * 0.85, float(to - 2))
	return maxf(1.0, float(d.get("time", 3.0)) * mul)


## Por que no se puede mejorar ("" si se puede): obra en marcha, nivel del castillo, tope o recursos.
static func why_not(st: Dictionary, b: String) -> String:
	if not (st["queue"] as Dictionary).is_empty():
		return "busy"
	var c: String = center_id(st["cat"])
	if b == c:
		if int(st["lv"][b]) >= int(st["cap"]):
			return "max"
	elif int(st["lv"][b]) >= int(st["lv"][c]):
		return "center"
	var cost: Dictionary = up_cost(st, b)
	for r: Variant in cost:
		if float(st["res"].get(str(r), 0.0)) + 0.001 < float(cost[r]):
			return "res"
	return ""


static func upgrade(st: Dictionary, b: String) -> bool:
	if why_not(st, b) != "":
		return false
	var cost: Dictionary = up_cost(st, b)
	for r: Variant in cost:
		st["res"][str(r)] = float(st["res"][str(r)]) - float(cost[r])
	var tt: float = up_time(st, b)
	st["queue"] = {"b": b, "left": tt, "total": tt}
	return true


## Ayuda gratis: la obra va un 30 % mas rapido (cada 20 s).
static func help(st: Dictionary) -> bool:
	if (st["queue"] as Dictionary).is_empty() or float(st["help_t"]) > 0.0:
		return false
	var q: Dictionary = st["queue"]
	q["left"] = maxf(0.0, float(q["left"]) - float(q["total"]) * HELP_CUT)
	st["help_t"] = HELP_EVERY
	return true


## Terminar la obra ya (en el juego, con un anuncio).
static func finish_now(st: Dictionary) -> bool:
	if (st["queue"] as Dictionary).is_empty():
		return false
	(st["queue"] as Dictionary)["left"] = 0.0
	return true


# ------------------------------------------------------------------ tiempo

## Avanza: produce, entrena (gastando comida) y la obra corre. Devuelve lo terminado.
static func step(st: Dictionary, dt: float) -> Array:
	var done: Array = []
	st["t"] = float(st["t"]) + dt
	st["help_t"] = maxf(0.0, float(st["help_t"]) - dt)
	var cat: Dictionary = st["cat"]
	for b: Variant in st["lv"]:
		var d: Dictionary = cat["buildings"][b]
		var l: float = float(st["lv"][b])
		if l <= 0.0:
			continue
		match str(d.get("role", "")):
			"prod":
				var r: String = str(d.get("res", "food"))
				st["res"][r] = float(st["res"].get(r, 0.0)) + float(d.get("rate", 1.0)) * l * dt
			"train":
				var tr: String = str(d.get("troop", "infantry"))
				var want: float = float(d.get("speed", 0.3)) * l * dt
				var cost: Dictionary = cat["troops"].get(tr, {}).get("cost", {})
				for rr: Variant in cost:
					if float(cost[rr]) > 0.0:
						want = minf(want, float(st["res"].get(str(rr), 0.0)) / float(cost[rr]))
				want = maxf(0.0, want)
				for rr2: Variant in cost:
					st["res"][str(rr2)] = float(st["res"][str(rr2)]) - want * float(cost[rr2])
				st["army"][tr] = float(st["army"][tr]) + want
	var q: Dictionary = st["queue"]
	if not q.is_empty():
		q["left"] = float(q["left"]) - dt
		if float(q["left"]) <= 0.0:
			st["lv"][str(q["b"])] = int(st["lv"][str(q["b"])]) + 1
			done.append(str(q["b"]))
			st["queue"] = {}
			Rules.hook(st, "on_upgrade", [str(q["b"])])
	Rules.hook(st, "on_step", [dt])
	return done


# ------------------------------------------------------------------ batallas

static func _mult(cat: Dictionary, a: String, b: String) -> float:
	if str(cat["troops"].get(a, {}).get("beats", "")) == b:
		return 1.5
	if str(cat["troops"].get(b, {}).get("beats", "")) == a:
		return 0.75
	return 1.0


static func _bonus(cat: Dictionary, heroes: Array, t: String) -> float:
	var b: float = 0.0
	for h: Variant in heroes:
		var d: Dictionary = cat["heroes"].get(str(h), {})
		if str(d.get("troop", "")) == t:
			b += float(d.get("bonus", 0.0))
	return b


## Batalla por rondas. {"win", "att": ejercito que queda, "def": el del enemigo, "lost": caidos}.
static func battle(cat: Dictionary, att: Dictionary, heroes: Array, dfn: Dictionary) -> Dictionary:
	var a: Dictionary = att.duplicate()
	var d: Dictionary = dfn.duplicate()
	var a0: float = 0.0
	for t: String in TYPES:
		a0 += float(a.get(t, 0.0))
	for r: int in ROUNDS:
		var ta: float = 0.0
		var td: float = 0.0
		for t: String in TYPES:
			ta += float(a.get(t, 0.0))
			td += float(d.get(t, 0.0))
		if ta < 0.5 or td < 0.5:
			break
		var hit_d: Dictionary = _hits(cat, a, heroes, d, td)
		var hit_a: Dictionary = _hits(cat, d, [], a, ta)
		for t2: String in TYPES:
			d[t2] = maxf(0.0, float(d.get(t2, 0.0)) - float(hit_d[t2]))
			a[t2] = maxf(0.0, float(a.get(t2, 0.0)) - float(hit_a[t2]))
	var left_a: float = 0.0
	var left_d: float = 0.0
	for t3: String in TYPES:
		left_a += float(a[t3])
		left_d += float(d[t3])
	return {"win": left_d < 0.5 and left_a >= 0.5, "att": a, "def": d, "lost": a0 - left_a}


## Bajas que causa 'src' en 'tgt' en una ronda (el dano se reparte por cuantos hay de cada tipo).
static func _hits(cat: Dictionary, src: Dictionary, heroes: Array, tgt: Dictionary, tgt_total: float) -> Dictionary:
	var out: Dictionary = {}
	for t: String in TYPES:
		out[t] = 0.0
	for s: String in TYPES:
		var n: float = float(src.get(s, 0.0))
		if n <= 0.0:
			continue
		var atk: float = n * float(cat["troops"][s].get("atk", 3.0)) * (1.0 + _bonus(cat, heroes, s)) * 0.5
		for t2: String in TYPES:
			var share: float = float(tgt.get(t2, 0.0)) / maxf(0.001, tgt_total)
			out[t2] = float(out[t2]) + atk * share * _mult(cat, s, t2) / float(cat["troops"][t2].get("hp", 10.0))
	return out


static func next_camp(st: Dictionary) -> int:
	for i: int in (st["camps"] as Array).size():
		if not bool(st["camps"][i]["done"]):
			return i
	return -1


## Que pasaria si atacas ahora el siguiente campamento (las batallas no tienen azar):
## {"win", "lost"} con las bajas que te quedarian de verdad (la mitad de los caidos vuelve).
static func forecast(st: Dictionary) -> Dictionary:
	var i: int = next_camp(st)
	if i < 0 or total_army(st) < 1.0:
		return {"win": false, "lost": 0}
	var r: Dictionary = battle(st["cat"], st["army"], st["heroes"], st["camps"][i]["army"])
	return {"win": bool(r["win"]), "lost": int(ceil(float(r["lost"]) * 0.5))}


## Atacar el siguiente campamento con todo el ejercito. Devuelve el resultado de la batalla.
static func attack(st: Dictionary) -> Dictionary:
	var i: int = next_camp(st)
	if i < 0 or total_army(st) < 1.0:
		return {}
	var camp: Dictionary = st["camps"][i]
	var r: Dictionary = battle(st["cat"], st["army"], st["heroes"], camp["army"])
	## La mitad de los caidos vuelven heridos y curados.
	for t: String in TYPES:
		var lost: float = float(st["army"][t]) - float(r["att"][t])
		st["army"][t] = float(r["att"][t]) + lost * 0.5
	st["fights"] = int(st["fights"]) + 1
	if bool(r["win"]):
		camp["done"] = true
		for res: Variant in camp["reward"]:
			st["res"][str(res)] = float(st["res"].get(str(res), 0.0)) + float(camp["reward"][res])
		if str(camp["hero"]) != "" and (st["cat"]["heroes"] as Dictionary).has(str(camp["hero"])):
			(st["heroes"] as Array).append(str(camp["hero"]))
		if bool(camp["boss"]):
			st["won"] = true
	else:
		camp["army"] = r["def"]
	r["camp"] = i
	Rules.hook(st, "on_battle", [r])
	return r


# ------------------------------------------------------------------ bot y analizador

## Que edificio subir: el mas bajo (y antes en la lista) de los que se pueden pagar; el castillo
## cuando todos lo alcanzan.
static func bot_build(st: Dictionary) -> String:
	if not (st["queue"] as Dictionary).is_empty():
		return ""
	var best: String = ""
	var bl: int = 999
	for b: String in building_ids(st["cat"]):
		if why_not(st, b) == "" and int(st["lv"][b]) < bl:
			bl = int(st["lv"][b])
			best = b
	return best


## Si atacar ya: gana y le queda al menos la mitad del ejercito.
static func should_attack(st: Dictionary) -> bool:
	var i: int = next_camp(st)
	if i < 0 or total_army(st) < 1.0:
		return false
	var r: Dictionary = battle(st["cat"], st["army"], st["heroes"], st["camps"][i]["army"])
	return bool(r["win"]) and float(r["lost"]) <= total_army(st) * 0.5


static func bot_tick(st: Dictionary, attacks: bool = true) -> void:
	help(st)
	var b: String = bot_build(st)
	if b != "":
		upgrade(st, b)
	if attacks and should_attack(st):
		attack(st)


static func bot_play(level: Dictionary, limit: float = 1200.0) -> Dictionary:
	var st: Dictionary = new_state(level)
	var next_think: float = 0.0
	while float(st["t"]) < limit and not bool(st["won"]):
		if float(st["t"]) >= next_think:
			bot_tick(st)
			next_think += BOT_EVERY
		step(st, DT)
	return {"won": bool(st["won"]), "time": float(st["t"]), "fights": int(st["fights"]), "army": total_army(st)}


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var cat: Dictionary = catalog(level)
	if center_id(cat) == "":
		issues.append("realm_no_center")
	for t: String in TYPES:
		if not (cat["troops"] as Dictionary).has(t):
			issues.append("realm_troop_" + t)
	if (level.get("camps", []) as Array).is_empty():
		issues.append("realm_no_camps")
	var par: float = maxf(60.0, float(level.get("par", 300.0)))
	var r: Dictionary = {"time": 0.0}
	if issues.is_empty():
		r = bot_play(level, par * 1.6)
		if not bool(r["won"]):
			issues.append("realm_too_slow")
		elif float(r["time"]) < 30.0:
			issues.append("realm_too_easy")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": 0, "enemies": (level.get("camps", []) as Array).size(), "enemy_problems": [], "time": r.get("time", 0.0)}
