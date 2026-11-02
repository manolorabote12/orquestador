extends RefCounted
## Tragaperras con aldea (tipo Coin Master): reglas, tiradas, bot y analizador. Casino SOCIAL:
## monedas de mentira que no se compran ni se cambian por nada (el juego va marcado para +18).
## 1 - Cada tirada gasta tiradas (tantas como la apuesta: x1, x2, x3, x5) y saca 3 simbolos.
##     Tres iguales pagan su premio por la apuesta; las monedas sueltas pagan un poco cada una.
##     Simbolos especiales: "spin" (tres = tiradas gratis), "pick" (tres = elige 1 de 3 cofres),
##     "raid" (tres = asalto: excava 3 de 9 hoyos con tesoros).
## 2 - Con las monedas se construye la aldea: cada edificio tiene 3 mejoras. Se gana al terminarla.
## 3 - Las tiradas se recargan con el tiempo (tambien con la app cerrada) y con un anuncio.
## 4 - Estilo dados (tipo Monopoly Go, catalogo "mode": "dice"): se tiran dos dados y la ficha avanza
##     por un tablero de 20 casillas (monedas, saco, cofres, asalto, tiradas, impuesto); pasar por la
##     salida paga. Mismas tiradas, apuesta, bonus y aldea.
## 5 - Todo por datos: kit/slots/slots_catalog.json + levels[i]["slots"] (preset y cambios).
##     Nivel: "scale" (cuanto cuestan los edificios), "spins" (al empezar), "regen" (segundos por
##     tirada), "par" (3 estrellas) y "seed".

const CATALOG_PATH: String = "res://kit/slots/slots_catalog.json"
const Rules = preload("res://kit/rules.gd")
const BETS: Array[int] = [1, 2, 3, 5]
const MAX_SPINS: int = 50
## Lo que tarda una persona en cada tirada (girar, mirar y volver a tocar).
const SPIN_TIME: float = 2.2
const LOOKS: Array[String] = ["coin", "bag", "chest", "energy", "hammer", "pig", "star", "cherry", "bell", "seven", "gem", "crown",
	"house", "tower", "mill", "statue", "ship", "tree", "castle", "well", "tent", "bridge"]

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
		_data = parsed if parsed is Dictionary else {"default": {"symbols": {}, "buildings": {}}, "presets": {}}
	return _data


static func catalog(level: Dictionary) -> Dictionary:
	var c: Dictionary = (data()["default"] as Dictionary).duplicate(true)
	var extra: Variant = level.get("slots", {})
	if extra is Dictionary:
		var pr: Variant = (extra as Dictionary).get("preset", "")
		for p: Variant in (pr if pr is Array else [pr]):
			if (data()["presets"] as Dictionary).has(str(p)):
				_merge(c, data()["presets"][str(p)])
		_merge(c, extra)
	return c


static func _merge(c: Dictionary, extra: Dictionary) -> void:
	for sec: String in ["symbols", "buildings"]:
		var add: Variant = extra.get(sec, {})
		if add is Dictionary:
			for k: Variant in add:
				if add[k] is Dictionary:
					var m: Dictionary = ((c[sec] as Dictionary).get(str(k), {}) as Dictionary).duplicate(true)
					m.merge(add[k] as Dictionary, true)
					c[sec][str(k)] = m
				elif add[k] == null:
					(c[sec] as Dictionary).erase(str(k))
	for k2: String in ["cur", "village", "mode", "pass", "board"]:
		if extra.has(k2):
			c[k2] = extra[k2]
	if extra.get("tiles", null) is Dictionary:
		if not c.has("tiles"):
			c["tiles"] = {}
		for t: Variant in extra["tiles"]:
			if extra["tiles"][t] is Dictionary:
				var m2: Dictionary = ((c["tiles"] as Dictionary).get(str(t), {}) as Dictionary).duplicate(true)
				m2.merge(extra["tiles"][t] as Dictionary, true)
				c["tiles"][str(t)] = m2


## Ids ordenados (por "order" o por id) para que el resultado no dependa del archivo.
static func _ids(sec: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for k: Variant in sec:
		ids.append(str(k))
	ids.sort_custom(func(a: String, b: String) -> bool:
		var oa: float = float((sec[a] as Dictionary).get("order", 0.0))
		var ob: float = float((sec[b] as Dictionary).get("order", 0.0))
		return oa < ob or (oa == ob and a < b))
	return ids


static func new_state(level: Dictionary) -> Dictionary:
	var cat: Dictionary = catalog(level)
	var syms: Array[String] = _ids(cat["symbols"])
	var total_w: float = 0.0
	for s: String in syms:
		total_w += maxf(0.0, float(cat["symbols"][s].get("w", 1.0)))
	var b_ids: Array[String] = _ids(cat["buildings"])
	var scale: float = maxf(0.05, float(level.get("scale", 1.0)))
	var builds: Array = []
	for b: String in b_ids:
		var costs: Array = []
		for x: Variant in cat["buildings"][b].get("costs", [100, 200, 400]):
			costs.append(maxf(1.0, round(float(x) * scale / 10.0) * 10.0))
		builds.append({"id": b, "stage": 0, "costs": costs})
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(level.get("seed", 1))
	var st: Dictionary = {"cat": cat, "syms": syms, "total_w": total_w, "builds": builds, "coins": 0.0, "spins": clampi(int(level.get("spins", 30)), 1, MAX_SPINS),
		"regen": maxf(5.0, float(level.get("regen", 40.0))), "regen_t": 0.0, "t": 0.0, "bet": 1, "rng": rng, "last": [], "won": false,
		"bonus": {}, "spent": 0, "spun": 0, "pos": 0, "dice": [1, 1], "dice_mode": str(cat.get("mode", "")) == "dice" and not (cat.get("board", []) as Array).is_empty()}
	st["rules"] = Rules.load_rules(level)
	Rules.hook(st, "on_start")
	return st


static func sym(st: Dictionary, id: String) -> Dictionary:
	return (st["cat"]["symbols"] as Dictionary).get(id, {})


static func _roll(st: Dictionary) -> String:
	var rng: RandomNumberGenerator = st["rng"]
	var r: float = rng.randf() * float(st["total_w"])
	for s: String in st["syms"]:
		r -= maxf(0.0, float(sym(st, s).get("w", 1.0)))
		if r <= 0.0:
			return s
	return str((st["syms"] as Array).back())


## Una tirada con la apuesta actual. Devuelve {"reels": [3 ids], "coins", "spins", "bonus": ""|"pick"|"raid"}.
## Los bonus se resuelven aparte (pick / dig); hasta entonces no se puede tirar.
static func spin(st: Dictionary) -> Dictionary:
	var bet: int = int(st["bet"])
	if not (st["bonus"] as Dictionary).is_empty() or int(st["spins"]) < bet or bool(st["won"]):
		return {}
	st["spins"] = int(st["spins"]) - bet
	st["spent"] = int(st["spent"]) + bet
	st["spun"] = int(st["spun"]) + 1
	if bool(st.get("dice_mode", false)):
		var mv: Dictionary = _move(st, bet)
		Rules.hook(st, "on_spin", [mv])
		return mv
	var reels: Array = [_roll(st), _roll(st), _roll(st)]
	st["last"] = reels
	var out: Dictionary = {"reels": reels, "coins": 0.0, "spins": 0, "bonus": ""}
	var three: bool = reels[0] == reels[1] and reels[1] == reels[2]
	if three:
		var s: Dictionary = sym(st, str(reels[0]))
		match str(s.get("kind", "coins")):
			"spin":
				out["spins"] = int(s.get("pay", 10)) * bet
			"pick":
				out["bonus"] = "pick"
				st["bonus"] = {"kind": "pick", "base": float(s.get("pay", 100)) * bet, "opts": _pick_opts(st)}
			"raid":
				out["bonus"] = "raid"
				st["bonus"] = {"kind": "raid", "base": float(s.get("pay", 100)) * bet, "holes": _raid_holes(st), "dug": [], "won": 0.0}
			_:
				out["coins"] = float(s.get("pay", 10)) * bet
	else:
		for r: Variant in reels:
			out["coins"] = float(out["coins"]) + float(sym(st, str(r)).get("one", 0.0)) * bet
	st["coins"] = float(st["coins"]) + float(out["coins"])
	st["spins"] = mini(MAX_SPINS * 4, int(st["spins"]) + int(out["spins"]))
	Rules.hook(st, "on_spin", [out])
	return out


## Dados: la ficha avanza la suma; la casilla donde cae decide el premio.
static func _move(st: Dictionary, bet: int) -> Dictionary:
	var rng: RandomNumberGenerator = st["rng"]
	var d1: int = rng.randi_range(1, 6)
	var d2: int = rng.randi_range(1, 6)
	st["dice"] = [d1, d2]
	var board: Array = st["cat"]["board"]
	var from: int = int(st["pos"])
	var to: int = from + d1 + d2
	var out: Dictionary = {"reels": [], "dice": [d1, d2], "from": from, "coins": 0.0, "spins": 0, "bonus": "", "tile": ""}
	if to >= board.size():
		out["coins"] = float(st["cat"].get("pass", 0.0)) * bet
		out["passed"] = true
	to = to % board.size()
	st["pos"] = to
	var kind: String = str(board[to])
	out["tile"] = kind
	var pay: float = float(tile(st, kind).get("pay", 0.0))
	match kind:
		"spin":
			out["spins"] = int(pay) * bet
		"pick":
			out["bonus"] = "pick"
			st["bonus"] = {"kind": "pick", "base": pay * bet, "opts": _pick_opts(st)}
		"raid":
			out["bonus"] = "raid"
			st["bonus"] = {"kind": "raid", "base": pay * bet, "holes": _raid_holes(st), "dug": [], "won": 0.0}
		"go":
			pass
		_:
			out["coins"] = float(out["coins"]) + pay * bet
	## El impuesto no deja en negativo.
	out["coins"] = maxf(-float(st["coins"]), float(out["coins"]))
	st["coins"] = float(st["coins"]) + float(out["coins"])
	st["spins"] = mini(MAX_SPINS * 4, int(st["spins"]) + int(out["spins"]))
	return out


static func tile(st: Dictionary, kind: String) -> Dictionary:
	return (st["cat"].get("tiles", {}) as Dictionary).get(kind, {})


## Cofres del bonus "pick": multiplicadores 1, 2 y 4 desordenados.
static func _pick_opts(st: Dictionary) -> Array:
	var o: Array = [1.0, 2.0, 4.0]
	var rng: RandomNumberGenerator = st["rng"]
	for i: int in range(2, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Variant = o[i]
		o[i] = o[j]
		o[j] = tmp
	return o


## Hoyos del asalto: 9 hoyos, 4 con tesoro (x1, x1, x2, x3) y 5 vacios.
static func _raid_holes(st: Dictionary) -> Array:
	var h: Array = [1.0, 1.0, 2.0, 3.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	var rng: RandomNumberGenerator = st["rng"]
	for i: int in range(h.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Variant = h[i]
		h[i] = h[j]
		h[j] = tmp
	return h


## Bonus pick: elige un cofre (0-2). Devuelve las monedas ganadas.
static func pick(st: Dictionary, i: int) -> float:
	var b: Dictionary = st["bonus"]
	if str(b.get("kind", "")) != "pick":
		return 0.0
	var won: float = float(b["base"]) * float(b["opts"][clampi(i, 0, 2)])
	st["coins"] = float(st["coins"]) + won
	st["bonus"] = {}
	return won


## Bonus asalto: excava un hoyo (0-8); a los 3 se acaba. Devuelve las monedas de ese hoyo.
static func dig(st: Dictionary, i: int) -> float:
	var b: Dictionary = st["bonus"]
	if str(b.get("kind", "")) != "raid" or (b["dug"] as Array).has(i) or i < 0 or i > 8:
		return -1.0
	(b["dug"] as Array).append(i)
	var won: float = float(b["base"]) * float(b["holes"][i])
	b["won"] = float(b["won"]) + won
	st["coins"] = float(st["coins"]) + won
	if (b["dug"] as Array).size() >= 3:
		st["bonus"] = {}
	return won


## Edificio que toca mejorar (el mas barato de los que faltan) y lo que cuesta. [-1, 0] si no hay.
static func next_build(st: Dictionary) -> Array:
	var best: int = -1
	var bc: float = INF
	for i: int in (st["builds"] as Array).size():
		var b: Dictionary = st["builds"][i]
		if int(b["stage"]) < (b["costs"] as Array).size():
			var c: float = float(b["costs"][int(b["stage"])])
			if c < bc:
				bc = c
				best = i
	return [best, bc if best >= 0 else 0.0]


static func build(st: Dictionary, i: int) -> bool:
	if i < 0 or i >= (st["builds"] as Array).size():
		return false
	var b: Dictionary = st["builds"][i]
	if int(b["stage"]) >= (b["costs"] as Array).size():
		return false
	var c: float = float(b["costs"][int(b["stage"])])
	if c > float(st["coins"]) + 0.001:
		return false
	st["coins"] = float(st["coins"]) - c
	b["stage"] = int(b["stage"]) + 1
	Rules.hook(st, "on_build", [i])
	st["won"] = village_done(st)
	return true


static func village_done(st: Dictionary) -> bool:
	for b: Variant in st["builds"]:
		if int(b["stage"]) < (b["costs"] as Array).size():
			return false
	return true


static func village_cost(st: Dictionary) -> float:
	var t: float = 0.0
	for b: Variant in st["builds"]:
		for i: int in range(int(b["stage"]), (b["costs"] as Array).size()):
			t += float(b["costs"][i])
	return t


## Recarga de tiradas con el tiempo (hasta el maximo).
static func tick(st: Dictionary, dt: float) -> void:
	st["t"] = float(st["t"]) + dt
	Rules.hook(st, "on_step", [dt])
	if int(st["spins"]) >= MAX_SPINS:
		st["regen_t"] = 0.0
		return
	st["regen_t"] = float(st["regen_t"]) + dt
	while float(st["regen_t"]) >= float(st["regen"]) and int(st["spins"]) < MAX_SPINS:
		st["regen_t"] = float(st["regen_t"]) - float(st["regen"])
		st["spins"] = int(st["spins"]) + 1


## Tiradas que vuelven con la app cerrada.
static func offline_spins(st: Dictionary, seconds: float) -> int:
	return clampi(int(seconds / float(st["regen"])), 0, maxi(0, MAX_SPINS - int(st["spins"])))


# ------------------------------------------------------------------ bot y analizador

## Lo que valen de media 1 tirada x1 en monedas (con bonus y tiradas gratis a su valor).
static func expected(st: Dictionary) -> float:
	if bool(st.get("dice_mode", false)):
		return expected_dice(st["cat"])
	var tw: float = float(st["total_w"])
	var ev: float = 0.0
	var spins_back: float = 0.0
	var p_three: float = 0.0
	for s: String in st["syms"]:
		var d: Dictionary = sym(st, s)
		var p: float = maxf(0.0, float(d.get("w", 1.0))) / tw
		var p3: float = p * p * p
		p_three += p3
		match str(d.get("kind", "coins")):
			"spin":
				spins_back += p3 * float(d.get("pay", 10))
			"pick":
				ev += p3 * float(d.get("pay", 100)) * 7.0 / 3.0
			"raid":
				ev += p3 * float(d.get("pay", 100)) * 7.0 / 3.0
			_:
				ev += p3 * float(d.get("pay", 10))
		## Sueltas (sin tres iguales): cada una paga "one"; se aproxima con 3 por p sin el trio.
		ev += 3.0 * p * float(d.get("one", 0.0)) * (1.0 - p * p)
	return ev / maxf(0.05, 1.0 - spins_back)


## Dados: con 2d6 la ficha acaba igual de a menudo en cada casilla; de media avanza 7 (pasa por la
## salida 7 veces cada 20 tiradas).
static func expected_dice(cat: Dictionary) -> float:
	var board: Array = cat.get("board", [])
	if board.is_empty():
		return 0.0
	var ev: float = 0.0
	var back: float = 0.0
	for k: Variant in board:
		var pay: float = float((cat.get("tiles", {}) as Dictionary).get(str(k), {}).get("pay", 0.0))
		match str(k):
			"spin":
				back += pay
			"pick", "raid":
				ev += pay * 7.0 / 3.0
			"go":
				pass
			_:
				ev += pay
	ev = ev / float(board.size()) + float(cat.get("pass", 0.0)) * 7.0 / float(board.size())
	return ev / maxf(0.05, 1.0 - back / float(board.size()))


## El bot: apuesta x1 (o mas si le sobran tiradas), resuelve los bonus a ciegas y construye en
## cuanto puede. Devuelve {"won", "time", "spun"}.
static func bot_play(level: Dictionary, limit: float = 1800.0, seed_add: int = 0) -> Dictionary:
	var lv: Dictionary = level.duplicate()
	lv["seed"] = int(level.get("seed", 1)) * 7 + seed_add * 104729
	var st: Dictionary = new_state(lv)
	while float(st["t"]) < limit and not bool(st["won"]):
		bot_step(st)
		tick(st, SPIN_TIME)
	return {"won": bool(st["won"]), "time": float(st["t"]), "spun": int(st["spun"])}


## Un paso del bot: construir, resolver bonus o tirar.
static func bot_step(st: Dictionary) -> void:
	var nb: Array = next_build(st)
	while int(nb[0]) >= 0 and float(nb[1]) <= float(st["coins"]):
		build(st, int(nb[0]))
		nb = next_build(st)
	var b: Dictionary = st["bonus"]
	if str(b.get("kind", "")) == "pick":
		pick(st, (st["rng"] as RandomNumberGenerator).randi_range(0, 2))
		return
	if str(b.get("kind", "")) == "raid":
		for i: int in 9:
			if not (b["dug"] as Array).has(i):
				dig(st, i)
				return
	st["bet"] = bot_bet(st)
	spin(st)


static func bot_bet(st: Dictionary) -> int:
	## Como una persona prudente: x2 solo con muchas tiradas guardadas.
	return 2 if int(st["spins"]) >= 30 else 1


## Analizador: la aldea se puede terminar y, de media, en un tiempo razonable (10 partidas).
static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var st: Dictionary = new_state(level)
	if (st["syms"] as Array).size() < 4:
		issues.append("slots_few_symbols")
	if (st["builds"] as Array).size() < 2 or (st["builds"] as Array).size() > 8:
		issues.append("slots_buildings")
	if expected(st) <= 0.0:
		issues.append("slots_no_pay")
	var par: float = maxf(60.0, float(level.get("par", 300.0)))
	var times: Array[float] = []
	var lost: int = 0
	if issues.is_empty():
		for k: int in 10:
			var r: Dictionary = bot_play(level, par * 3.0, k)
			if bool(r["won"]):
				times.append(float(r["time"]))
			else:
				lost += 1
		times.sort()
		if lost > 2:
			issues.append("slots_too_slow")
		elif not times.is_empty() and times[times.size() / 2] > par * 1.5:
			issues.append("slots_too_slow")
		elif not times.is_empty() and times[times.size() / 2] < 40.0:
			issues.append("slots_too_easy")
	var med: float = times[times.size() / 2] if not times.is_empty() else 0.0
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": 0, "enemies": 0, "enemy_problems": [], "time": med, "ev": expected(st)}
