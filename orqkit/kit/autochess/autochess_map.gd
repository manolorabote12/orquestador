extends RefCounted
## Batalla automatica (tipo Auto Chess): rondas de compra y combate. Cada ronda cobras oro, compras
## unidades en la tienda (5 al azar, se puede rehacer), las colocas en tu mitad del tablero y luchan
## solas contra el ejercito de esa ronda. Tres iguales se funden en una de 2 estrellas (y tres de 2,
## en una de 3). Pierdes una vida por ronda perdida; ganas el nivel si pasas todas las rondas.
## Nivel: "rounds" (cada ronda: [{"t": tipo, "s": estrellas, "x", "y"}] del rival, en SU mitad),
## "lives", "gold" (oro por ronda), "seed" (la tienda), "slots" (unidades que caben en el tablero).
## Tablero de W x H: tu mitad son las filas H/2..H-1; el banquillo, BENCH huecos fuera del tablero.

const Rules = preload("res://kit/rules.gd")
const W: int = 6
const H: int = 8
const BENCH: int = 6
const SHOP: int = 5
const REROLL: int = 2
## Tipo -> vida, dano, alcance (casillas), cada cuanto pega (s), velocidad (casillas/s), coste.
const TYPES: Dictionary = {
	"warrior": {"hp": 60, "dmg": 9, "range": 1, "cd": 1.0, "spd": 1.6, "cost": 1},
	"archer": {"hp": 38, "dmg": 8, "range": 4, "cd": 1.1, "spd": 1.5, "cost": 1},
	"knight": {"hp": 110, "dmg": 6, "range": 1, "cd": 1.2, "spd": 1.2, "cost": 2},
	"mage": {"hp": 40, "dmg": 7, "range": 3, "cd": 1.6, "spd": 1.3, "cost": 2, "splash": 1},
	"assassin": {"hp": 46, "dmg": 13, "range": 1, "cd": 0.9, "spd": 2.4, "cost": 3, "dive": true},
	"healer": {"hp": 42, "dmg": 4, "range": 3, "cd": 1.4, "spd": 1.3, "cost": 3, "heal": 10},
}
const STAR_MULT: Array[float] = [0.0, 1.0, 1.8, 3.2]
## Sinergias (solo tu ejercito): con NEED unidades del mismo tipo en el tablero, ese tipo gana
## un extra. Tipo -> [que mejora (hp|dmg|rate|heal), cuanto].
const SYNERGY_NEED: int = 2
const SYNERGY: Dictionary = {
	"warrior": ["hp", 1.25], "archer": ["rate", 0.8], "knight": ["hp", 1.3],
	"mage": ["dmg", 1.3], "assassin": ["dmg", 1.3], "healer": ["heal", 1.5],
}
const SYNERGY_TXT: Dictionary = {"hp": "+{p}% vida", "dmg": "+{p}% da\u00f1o", "rate": "+{p}% velocidad", "heal": "+{p}% curas"}


static func new_state(level: Dictionary) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(level.get("seed", 1))
	var st: Dictionary = {"round": 0, "rounds": level.get("rounds", []), "lives": clampi(int(level.get("lives", 3)), 1, 5),
		"gold": 0, "income": clampi(int(level.get("gold", 6)), 3, 12), "slots": clampi(int(level.get("slots", 3)), 1, 10),
		"board": [], "bench": [], "shop": [], "rng": rng, "won": false, "lost": false, "last": "", "uid": 0, "wins": 0}
	st["rules"] = Rules.load_rules(level)
	Rules.hook(st, "on_start")
	start_round(st)
	return st


## Empieza la fase de compra de la ronda: oro (con racha), tienda nueva, un hueco mas cada 2 rondas.
static func start_round(st: Dictionary) -> void:
	st["gold"] = int(st["gold"]) + int(st["income"]) + mini(int(st["wins"]), 3)
	if int(st["round"]) > 0 and int(st["round"]) % 2 == 0:
		st["slots"] = mini(int(st["slots"]) + 1, 8)
	roll_shop(st)


static func roll_shop(st: Dictionary) -> void:
	var rng: RandomNumberGenerator = st["rng"]
	var names: Array = TYPES.keys()
	names.sort()
	var shop: Array = []
	for k: int in SHOP:
		## Las caras salen menos al principio.
		var t: String = str(names[rng.randi_range(0, names.size() - 1)])
		if int(TYPES[t]["cost"]) == 3 and int(st["round"]) < 2 and rng.randf() < 0.6:
			t = "warrior" if rng.randf() < 0.5 else "archer"
		shop.append(t)
	st["shop"] = shop


static func _new_unit(st: Dictionary, t: String, stars: int) -> Dictionary:
	st["uid"] = int(st["uid"]) + 1
	return {"id": int(st["uid"]), "t": t, "s": stars, "x": -1, "y": -1}


## Compra la unidad del hueco i de la tienda (al banquillo, o funde si ya hay dos iguales).
static func buy(st: Dictionary, i: int) -> bool:
	var shop: Array = st["shop"]
	if i < 0 or i >= shop.size() or str(shop[i]) == "" or bool(st["won"]) or bool(st["lost"]):
		return false
	var t: String = str(shop[i])
	var cost: int = int(TYPES[t]["cost"])
	if int(st["gold"]) < cost:
		return false
	var copies: int = _count(st, t, 1)
	if (st["bench"] as Array).size() >= BENCH and copies < 2:
		return false
	st["gold"] = int(st["gold"]) - cost
	shop[i] = ""
	(st["bench"] as Array).append(_new_unit(st, t, 1))
	_merge(st, t, 1)
	Rules.hook(st, "on_buy", [t])
	return true


static func _count(st: Dictionary, t: String, s: int) -> int:
	var n: int = 0
	for u: Variant in (st["bench"] as Array) + (st["board"] as Array):
		if str(u["t"]) == t and int(u["s"]) == s:
			n += 1
	return n


## Tres iguales -> una de una estrella mas (se queda donde estaba la del tablero, si la hay).
static func _merge(st: Dictionary, t: String, s: int) -> void:
	if s >= 3 or _count(st, t, s) < 3:
		return
	var keep: Dictionary = {}
	var gone: int = 0
	for arr_name: String in ["board", "bench"]:
		var arr: Array = st[arr_name]
		for k: int in range(arr.size() - 1, -1, -1):
			var u: Dictionary = arr[k]
			if gone < 3 and str(u["t"]) == t and int(u["s"]) == s:
				if keep.is_empty() and arr_name == "board":
					keep = u
				else:
					arr.remove_at(k)
				gone += 1
	if keep.is_empty():
		var nu: Dictionary = _new_unit(st, t, s + 1)
		(st["bench"] as Array).append(nu)
	else:
		keep["s"] = s + 1
		## La que se queda en el tablero cuenta como una de las tres.
	Rules.hook(st, "on_merge", [t, s + 1])
	_merge(st, t, s + 1)


static func reroll(st: Dictionary) -> bool:
	if int(st["gold"]) < REROLL or bool(st["won"]) or bool(st["lost"]):
		return false
	st["gold"] = int(st["gold"]) - REROLL
	roll_shop(st)
	return true


## Coloca (o mueve) una unidad en tu mitad del tablero; si la casilla tiene otra, se cambian.
static func place(st: Dictionary, id: int, cell: Vector2i) -> bool:
	if cell.x < 0 or cell.x >= W or cell.y < H / 2 or cell.y >= H:
		return false
	var u: Dictionary = _find(st, id)
	if u.is_empty():
		return false
	var on_board: bool = (st["board"] as Array).has(u)
	var other: Dictionary = {}
	for v: Variant in st["board"]:
		if int(v["x"]) == cell.x and int(v["y"]) == cell.y:
			other = v
	if not on_board and other.is_empty() and (st["board"] as Array).size() >= int(st["slots"]):
		return false
	if not other.is_empty() and int(other["id"]) != id:
		if on_board:
			other["x"] = int(u["x"])
			other["y"] = int(u["y"])
		else:
			(st["board"] as Array).erase(other)
			(st["bench"] as Array).append(other)
			other["x"] = -1
			other["y"] = -1
	if not on_board:
		(st["bench"] as Array).erase(u)
		(st["board"] as Array).append(u)
	u["x"] = cell.x
	u["y"] = cell.y
	return true


## Devuelve una unidad del tablero al banquillo (si cabe).
static func unplace(st: Dictionary, id: int) -> bool:
	var u: Dictionary = _find(st, id)
	if u.is_empty() or not (st["board"] as Array).has(u) or (st["bench"] as Array).size() >= BENCH:
		return false
	(st["board"] as Array).erase(u)
	(st["bench"] as Array).append(u)
	u["x"] = -1
	u["y"] = -1
	return true


## Vende (te devuelve su coste por cada copia que lleva dentro).
static func sell(st: Dictionary, id: int) -> bool:
	var u: Dictionary = _find(st, id)
	if u.is_empty():
		return false
	(st["board"] as Array).erase(u)
	(st["bench"] as Array).erase(u)
	st["gold"] = int(st["gold"]) + int(TYPES[str(u["t"])]["cost"]) * [0, 1, 3, 9][int(u["s"])]
	return true


static func _find(st: Dictionary, id: int) -> Dictionary:
	for u: Variant in (st["bench"] as Array) + (st["board"] as Array):
		if int(u["id"]) == id:
			return u
	return {}


# ------------------------------------------------------------------ combate

## Unidades de combate: copia con vida, dano... segun tipo y estrellas. side 1 tu, 2 rival.
## Tipos con sinergia activa en tu tablero.
static func synergies(st: Dictionary) -> Array:
	var count: Dictionary = {}
	for u: Variant in st["board"]:
		count[str(u["t"])] = int(count.get(str(u["t"]), 0)) + 1
	var out: Array = []
	for t: Variant in SYNERGY:
		if int(count.get(t, 0)) >= SYNERGY_NEED:
			out.append(str(t))
	return out


## Texto corto de una sinergia: "+25% vida".
static func synergy_text(t: String) -> String:
	var s: Array = SYNERGY[t]
	var v: float = float(s[1])
	var pct: int = int(round((1.0 / v - 1.0) * 100.0)) if str(s[0]) == "rate" else int(round((v - 1.0) * 100.0))
	return Kit.text("ac_syn_" + str(s[0]), str(SYNERGY_TXT[str(s[0])])).format({"p": pct})


static func fighters(st: Dictionary) -> Array:
	var out: Array = []
	var syn: Array = synergies(st)
	for u: Variant in st["board"]:
		var f: Dictionary = _fighter(u, 1)
		if syn.has(str(u["t"])):
			var s: Array = SYNERGY[str(u["t"])]
			match str(s[0]):
				"hp":
					f["hp"] = float(f["hp"]) * float(s[1])
					f["max"] = f["hp"]
				"dmg":
					f["dmg"] = float(f["dmg"]) * float(s[1])
				"rate":
					f["rate"] = float(s[1])
				"heal":
					f["heal_mult"] = float(s[1])
		out.append(f)
	var rounds: Array = st["rounds"]
	if int(st["round"]) < rounds.size():
		var k: int = 0
		for e: Variant in rounds[int(st["round"])]:
			k += 1
			out.append(_fighter({"id": 1000 + k, "t": str(e["t"]), "s": int(e.get("s", 1)), "x": int(e["x"]), "y": int(e["y"])}, 2))
	return out


static func _fighter(u: Dictionary, side: int) -> Dictionary:
	var spec: Dictionary = TYPES[str(u["t"])]
	var m: float = STAR_MULT[clampi(int(u["s"]), 1, 3)]
	var hp: float = float(spec["hp"]) * m
	return {"id": int(u["id"]), "t": str(u["t"]), "s": int(u["s"]), "side": side, "pos": Vector2(float(u["x"]) + 0.5, float(u["y"]) + 0.5),
		"hp": hp, "max": hp, "dmg": float(spec["dmg"]) * m, "range": float(spec["range"]), "cd": 0.3 + 0.05 * float(int(u["id"]) % 5),
		"spd": float(spec["spd"]), "target": -1, "hit": 0.0}


## Un paso de combate (dt segundos). Devuelve eventos [{"k": "hit"/"heal", "a", "b", "n"}].
static func battle_step(fs: Array, dt: float) -> Array:
	var ev: Array = []
	for f: Variant in fs:
		var a: Dictionary = f
		if float(a["hp"]) <= 0.0:
			continue
		a["hit"] = maxf(0.0, float(a["hit"]) - dt)
		var spec: Dictionary = TYPES[str(a["t"])]
		## Sanadora: cura al aliado mas herido que tenga a mano.
		if spec.has("heal"):
			var worst: Dictionary = {}
			for g: Variant in fs:
				if int(g["side"]) == int(a["side"]) and float(g["hp"]) > 0.0 and float(g["hp"]) < float(g["max"]) * 0.85 \
						and (a["pos"] as Vector2).distance_to(g["pos"]) <= float(a["range"]) + 0.5:
					if worst.is_empty() or float(g["hp"]) / float(g["max"]) < float(worst["hp"]) / float(worst["max"]):
						worst = g
			if not worst.is_empty():
				a["cd"] = float(a["cd"]) - dt
				if float(a["cd"]) <= 0.0:
					a["cd"] = float(spec["cd"]) * float(a.get("rate", 1.0))
					var amount: float = float(spec["heal"]) * STAR_MULT[int(a["s"])] * float(a.get("heal_mult", 1.0))
					worst["hp"] = minf(float(worst["max"]), float(worst["hp"]) + amount)
					ev.append({"k": "heal", "a": int(a["id"]), "b": int(worst["id"]), "n": int(amount)})
				continue
		## Objetivo: el rival mas cercano (la asesina, el mas lejano: salta a la retaguardia).
		var tgt: Dictionary = {}
		var best: float = 1e9
		for g2: Variant in fs:
			if int(g2["side"]) == int(a["side"]) or float(g2["hp"]) <= 0.0:
				continue
			var d: float = (a["pos"] as Vector2).distance_to(g2["pos"])
			var key: float = -d if bool(spec.get("dive", false)) and float(a["max"]) == float(a["hp"]) and int(a["target"]) < 0 else d
			if key < best:
				best = key
				tgt = g2
		if tgt.is_empty():
			continue
		if bool(spec.get("dive", false)) and int(a["target"]) < 0:
			## Salta una vez detras del objetivo.
			a["pos"] = (tgt["pos"] as Vector2) + Vector2(0.0, -0.8 if int(a["side"]) == 1 else 0.8)
		a["target"] = int(tgt["id"])
		var dist: float = (a["pos"] as Vector2).distance_to(tgt["pos"])
		if dist > float(a["range"]) + 0.15:
			var step: Vector2 = ((tgt["pos"] as Vector2) - (a["pos"] as Vector2)).normalized() * float(a["spd"]) * dt
			var np: Vector2 = (a["pos"] as Vector2) + step
			## Sin meterse encima de otra unidad viva.
			var blocked: bool = false
			for g3: Variant in fs:
				if g3 != a and float(g3["hp"]) > 0.0 and np.distance_to(g3["pos"]) < 0.55 and np.distance_to(g3["pos"]) < (a["pos"] as Vector2).distance_to(g3["pos"]):
					blocked = true
			if blocked:
				np = (a["pos"] as Vector2) + step.rotated(PI * 0.5 if int(a["id"]) % 2 == 0 else -PI * 0.5) * 0.7
			a["pos"] = np
			continue
		a["cd"] = float(a["cd"]) - dt
		if float(a["cd"]) <= 0.0:
			a["cd"] = float(spec["cd"]) * float(a.get("rate", 1.0))
			var hits: Array = [tgt]
			if spec.has("splash"):
				for g4: Variant in fs:
					if g4 != tgt and int(g4["side"]) == int(tgt["side"]) and float(g4["hp"]) > 0.0 and (g4["pos"] as Vector2).distance_to(tgt["pos"]) <= float(spec["splash"]) + 0.2:
						hits.append(g4)
			for hd: Variant in hits:
				var n: float = float(a["dmg"]) * (1.0 if hd == tgt else 0.5)
				hd["hp"] = float(hd["hp"]) - n
				hd["hit"] = 0.2
				ev.append({"k": "hit", "a": int(a["id"]), "b": int(hd["id"]), "n": int(round(n))})
	return ev


## Quien gana un combate: 1, 2 o 0 si sigue.
static func winner(fs: Array) -> int:
	var a: bool = false
	var b: bool = false
	for f: Variant in fs:
		if float(f["hp"]) > 0.0:
			if int(f["side"]) == 1:
				a = true
			else:
				b = true
	if a and b:
		return 0
	return 1 if a else 2


## Combate entero (para el analizador y el bot): devuelve 1 o 2 (a los 40 s, gana quien tenga mas vida).
static func simulate(fs: Array) -> int:
	var t: float = 0.0
	while t < 40.0:
		battle_step(fs, 0.1)
		t += 0.1
		var w: int = winner(fs)
		if w != 0:
			return w
	return hp_winner(fs)


## A los 40 s sin ganador: gana quien tenga mas vida en pie.
static func hp_winner(fs: Array) -> int:
	var hp1: float = 0.0
	var hp2: float = 0.0
	for f: Variant in fs:
		if int(f["side"]) == 1:
			hp1 += maxf(0.0, float(f["hp"]))
		else:
			hp2 += maxf(0.0, float(f["hp"]))
	return 1 if hp1 > hp2 else 2


## Acaba la ronda con el ganador w: vida, racha, siguiente ronda o final.
static func finish_round(st: Dictionary, w: int) -> void:
	st["last"] = "win" if w == 1 else "loss"
	if w == 1:
		st["wins"] = int(st["wins"]) + 1
	else:
		st["wins"] = 0
		st["lives"] = int(st["lives"]) - 1
	Rules.hook(st, "on_round_end", [w])
	if int(st["lives"]) <= 0:
		st["lost"] = true
		return
	st["round"] = int(st["round"]) + 1
	if int(st["round"]) >= (st["rounds"] as Array).size():
		st["won"] = true
		return
	start_round(st)


# ------------------------------------------------------------------ bot

## Bot: compra lo que funde o lo mejor que puede pagar, llena el tablero (cuerpo a cuerpo delante,
## a distancia detras) y rehace la tienda si le sobra oro.
static func bot_shop(st: Dictionary) -> void:
	for _pass: int in 6:
		var bought: bool = false
		var shop: Array = st["shop"]
		var best_i: int = -1
		var best_v: float = -1.0
		for i: int in shop.size():
			var t: String = str(shop[i])
			if t == "" or int(TYPES[t]["cost"]) > int(st["gold"]):
				continue
			var v: float = float(TYPES[t]["cost"]) + float(_count(st, t, 1)) * 3.0 + float(_count(st, t, 2)) * 2.0
			if (st["board"] as Array).size() + (st["bench"] as Array).size() >= int(st["slots"]) + 2 and _count(st, t, 1) == 0:
				v -= 4.0
			if v > best_v:
				best_v = v
				best_i = i
		if best_i >= 0 and best_v > 0.0 and buy(st, best_i):
			bought = true
		elif int(st["gold"]) >= REROLL + 3:
			reroll(st)
			bought = true
		if not bought:
			break
	bot_arrange(st)


static func bot_arrange(st: Dictionary) -> void:
	## Lo mejor (mas estrellas y coste) al tablero hasta llenar los huecos.
	var all: Array = (st["bench"] as Array) + (st["board"] as Array)
	all.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var va: int = int(a["s"]) * 10 + int(TYPES[str(a["t"])]["cost"])
		var vb: int = int(b["s"]) * 10 + int(TYPES[str(b["t"])]["cost"])
		return va > vb if va != vb else int(a["id"]) < int(b["id"]))
	var chosen: Array = all.slice(0, int(st["slots"]))
	var bench: Array = []
	for u: Variant in all:
		if not chosen.has(u):
			u["x"] = -1
			u["y"] = -1
			bench.append(u)
	st["board"] = []
	st["bench"] = bench.slice(0, BENCH)
	var front: Array = chosen.filter(func(u: Dictionary) -> bool: return float(TYPES[str(u["t"])]["range"]) <= 1.0)
	var back: Array = chosen.filter(func(u: Dictionary) -> bool: return float(TYPES[str(u["t"])]["range"]) > 1.0)
	var cols: Array = [2, 3, 1, 4, 0, 5]
	var fi: int = 0
	for u2: Variant in front:
		var row: int = H / 2 if fi < W else H / 2 + 1
		u2["x"] = int(cols[fi % W])
		u2["y"] = row
		(st["board"] as Array).append(u2)
		fi += 1
	var bi: int = 0
	for u3: Variant in back:
		var row2: int = H - 1 if bi < W else H - 2
		u3["x"] = int(cols[bi % W])
		u3["y"] = row2
		(st["board"] as Array).append(u3)
		bi += 1


static func bot_play(level: Dictionary) -> Dictionary:
	var st: Dictionary = new_state(level)
	var guard: int = 0
	while not bool(st["won"]) and not bool(st["lost"]) and guard < 50:
		guard += 1
		bot_shop(st)
		finish_round(st, simulate(fighters(st)))
	return {"won": bool(st["won"]), "lives": int(st["lives"]), "round": int(st["round"])}


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var rounds: Array = level.get("rounds", [])
	if rounds.size() < 2 or rounds.size() > 12:
		issues.append("autochess_rounds")
	for r: Variant in rounds:
		for e: Variant in r:
			if not TYPES.has(str(e.get("t", ""))) or int(e.get("y", 0)) >= H / 2 or int(e.get("y", 0)) < 0 or int(e.get("x", 0)) < 0 or int(e.get("x", 0)) >= W:
				issues.append("autochess_bad_enemy")
	var r2: Dictionary = {"won": false, "lives": 0}
	if issues.is_empty():
		r2 = bot_play(level)
		if not bool(r2["won"]):
			issues.append("autochess_unbeatable")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": rounds.size(), "enemies": 0, "enemy_problems": [], "bot_lives": r2.get("lives", 0)}
