extends RefCounted
## Estrategia por turnos (tipo Advance Wars): mapa de casillas con terreno, dos ejercitos y cuarteles.
## Terreno ("map", una cadena por fila): "." llano, "f" bosque (+1 defensa, cuesta 2), "m" montana (+2,
## cuesta 3, solo infanteria), "~" agua (no se pasa), "c" ciudad (cura 2 y +1 defensa; la infanteria la
## captura), "H" tu cuartel, "h" el del rival.
## Unidades ("units": [{"t": "inf"|"tank"|"art", "x", "y", "side": 1|2}]): por turno cada una mueve y
## luego ataca (la artilleria ataca de lejos y solo si no se ha movido) o espera.
## Se gana capturando el cuartel rival (infanteria encima al acabar tu turno) o sin unidades rivales;
## se pierde igual al reves o si se acaban los turnos ("turns").

const Rules = preload("res://kit/rules.gd")
const TYPES: Dictionary = {
	"inf": {"move": 3, "atk": 5, "def": 1, "min": 1, "max": 1, "cost": {".": 1, "f": 1, "m": 2, "c": 1, "H": 1, "h": 1}},
	"tank": {"move": 5, "atk": 7, "def": 3, "min": 1, "max": 1, "cost": {".": 1, "f": 2, "c": 1, "H": 1, "h": 1}},
	"art": {"move": 3, "atk": 6, "def": 1, "min": 2, "max": 3, "cost": {".": 1, "f": 2, "c": 1, "H": 1, "h": 1}},
}
## Multiplicador de dano atacante -> defensor (los tanques aplastan infanteria; la infanteria apenas les hace nada).
const VS: Dictionary = {"inf": {"inf": 1.0, "tank": 0.35, "art": 0.9}, "tank": {"inf": 1.3, "tank": 1.0, "art": 1.2},
	"art": {"inf": 1.2, "tank": 1.0, "art": 1.1}}
const TERRAIN_DEF: Dictionary = {".": 0, "f": 1, "m": 2, "c": 1, "H": 2, "h": 2, "~": 0}


static func new_state(level: Dictionary) -> Dictionary:
	var rows: Array = []
	## El terreno va en "tiles" (la fabrica deja en "map" tambien las unidades y la semilla).
	for r: Variant in level.get("tiles", level.get("map", [])):
		rows.append(str(r))
	var units: Array = []
	var uid: int = 0
	for u: Variant in level.get("units", []):
		var d: Dictionary = u
		uid += 1
		units.append({"id": uid, "t": str(d.get("t", "inf")), "x": int(d["x"]), "y": int(d["y"]), "side": int(d.get("side", 1)), "hp": 10,
			"moved": false, "done": false})
	var owner: Dictionary = {}
	for y: int in rows.size():
		for x: int in (rows[y] as String).length():
			var ch: String = (rows[y] as String)[x]
			if ch == "H":
				owner[Vector2i(x, y)] = 1
			elif ch == "h":
				owner[Vector2i(x, y)] = 2
			elif ch == "c":
				owner[Vector2i(x, y)] = 0
	var st: Dictionary = {"map": rows, "w": (rows[0] as String).length() if not rows.is_empty() else 0, "h": rows.size(), "units": units,
		"owner": owner, "side": 1, "turn": 1, "max_turns": int(level.get("turns", 30)), "won": false, "lost": false, "log": [],
		"ai_smart": clampf(float(level.get("ai", 1.0)), 0.0, 1.0), "mistake": clampf(float(level.get("mistake", 0.0)), 0.0, 0.8)}
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(level.get("seed", 1))
	st["rng"] = rng
	st["rules"] = Rules.load_rules(level)
	Rules.hook(st, "on_start")
	return st


static func tile(st: Dictionary, p: Vector2i) -> String:
	if p.x < 0 or p.y < 0 or p.x >= int(st["w"]) or p.y >= int(st["h"]):
		return "~"
	return (st["map"][p.y] as String)[p.x]


static func unit_at(st: Dictionary, p: Vector2i) -> Dictionary:
	for u: Variant in st["units"]:
		if int(u["x"]) == p.x and int(u["y"]) == p.y and int(u["hp"]) > 0:
			return u
	return {}


static func unit_by_id(st: Dictionary, id: int) -> Dictionary:
	for u: Variant in st["units"]:
		if int(u["id"]) == id:
			return u
	return {}


static func alive(st: Dictionary, side: int) -> Array:
	return (st["units"] as Array).filter(func(u: Dictionary) -> bool: return int(u["side"]) == side and int(u["hp"]) > 0)


## Casillas a las que puede ir (Dijkstra por coste de terreno; no atraviesa rivales; acaba en vacia).
static func reach(st: Dictionary, u: Dictionary) -> Dictionary:
	var spec: Dictionary = TYPES[str(u["t"])]
	var costs: Dictionary = spec["cost"]
	var start: Vector2i = Vector2i(int(u["x"]), int(u["y"]))
	var best: Dictionary = {start: 0}
	var open: Array = [start]
	while not open.is_empty():
		var bi: int = 0
		for k: int in open.size():
			if int(best[open[k]]) < int(best[open[bi]]):
				bi = k
		var p: Vector2i = open[bi]
		open.remove_at(bi)
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = p + d
			var t: String = tile(st, q)
			if not costs.has(t):
				continue
			var other: Dictionary = unit_at(st, q)
			if not other.is_empty() and int(other["side"]) != int(u["side"]):
				continue
			var c: int = int(best[p]) + int(costs[t])
			if c <= int(spec["move"]) and (not best.has(q) or c < int(best[q])):
				best[q] = c
				open.append(q)
	var out: Dictionary = {}
	for q2: Variant in best.keys():
		var occ: Dictionary = unit_at(st, q2)
		if occ.is_empty() or int(occ["id"]) == int(u["id"]):
			out[q2] = int(best[q2])
	return out


## Rivales a los que puede atacar desde from (a distancia min..max de manhattan).
static func targets_from(st: Dictionary, u: Dictionary, from: Vector2i) -> Array:
	var spec: Dictionary = TYPES[str(u["t"])]
	var out: Array = []
	for v: Variant in st["units"]:
		if int(v["hp"]) <= 0 or int(v["side"]) == int(u["side"]):
			continue
		var dist: int = absi(int(v["x"]) - from.x) + absi(int(v["y"]) - from.y)
		if dist >= int(spec["min"]) and dist <= int(spec["max"]):
			out.append(v)
	return out


## Dano de a sobre b (sin azar): ataque x vida/10 x tipo, menos la defensa del terreno y de b.
static func damage(st: Dictionary, a: Dictionary, b: Dictionary) -> int:
	var sa: Dictionary = TYPES[str(a["t"])]
	var sb: Dictionary = TYPES[str(b["t"])]
	var terrain: int = int(TERRAIN_DEF.get(tile(st, Vector2i(int(b["x"]), int(b["y"]))), 0))
	var raw: float = float(sa["atk"]) * float(VS[str(a["t"])][str(b["t"])]) * float(int(a["hp"])) / 10.0
	var red: float = 1.0 - 0.1 * float(terrain + int(sb["def"]))
	return maxi(1, int(round(raw * maxf(0.2, red))))


## Lo que pasaria si a ataca ahora a b: [dano, contraataque] (mismas cuentas que attack()).
static func preview(st: Dictionary, a: Dictionary, b: Dictionary) -> Array:
	var d: int = damage(st, a, b)
	var left: int = maxi(0, int(b["hp"]) - d)
	var back: int = 0
	var dist: int = absi(int(b["x"]) - int(a["x"])) + absi(int(b["y"]) - int(a["y"]))
	if left > 0 and int(TYPES[str(b["t"])]["min"]) == 1 and dist == 1:
		var hurt: Dictionary = b.duplicate()
		hurt["hp"] = left
		back = damage(st, hurt, a)
	return [d, back]


## Zona de peligro de una unidad: casillas que puede atacar en su proximo turno (moviendose y
## pegando; la artilleria, solo desde donde esta).
static func threat(st: Dictionary, u: Dictionary) -> Dictionary:
	var spec: Dictionary = TYPES[str(u["t"])]
	var froms: Array = [Vector2i(int(u["x"]), int(u["y"]))] if str(u["t"]) == "art" else reach(st, u).keys()
	var out: Dictionary = {}
	var lo: int = int(spec["min"])
	var hi: int = int(spec["max"])
	for f: Variant in froms:
		var p: Vector2i = f
		for dy: int in range(-hi, hi + 1):
			for dx: int in range(-hi, hi + 1):
				var dist: int = absi(dx) + absi(dy)
				var q: Vector2i = p + Vector2i(dx, dy)
				if dist >= lo and dist <= hi and q.x >= 0 and q.y >= 0 and q.x < int(st["w"]) and q.y < int(st["h"]):
					out[q] = true
	return out


## Mueve la unidad (si puede ir) y la marca como movida.
static func move(st: Dictionary, id: int, to: Vector2i) -> bool:
	var u: Dictionary = unit_by_id(st, id)
	if u.is_empty() or bool(u["done"]) or bool(u["moved"]) or int(u["side"]) != int(st["side"]) or not reach(st, u).has(to):
		return false
	var from: Vector2i = Vector2i(int(u["x"]), int(u["y"]))
	u["x"] = to.x
	u["y"] = to.y
	u["moved"] = true
	u["shifted"] = to != from
	Rules.hook(st, "on_move", [u, from, to])
	return true


## Ataca (la artilleria solo si no se ha desplazado). Contraataque cuerpo a cuerpo si sobrevive.
static func attack(st: Dictionary, id: int, target_id: int) -> bool:
	var u: Dictionary = unit_by_id(st, id)
	var v: Dictionary = unit_by_id(st, target_id)
	if u.is_empty() or v.is_empty() or bool(u["done"]) or int(u["side"]) != int(st["side"]) or int(v["hp"]) <= 0:
		return false
	var at: Vector2i = Vector2i(int(u["x"]), int(u["y"]))
	if not targets_from(st, u, at).has(v):
		return false
	if str(u["t"]) == "art" and bool(u.get("shifted", false)):
		return false
	var d: int = damage(st, u, v)
	v["hp"] = maxi(0, int(v["hp"]) - d)
	(st["log"] as Array).append({"a": id, "b": target_id, "d": d})
	if int(v["hp"]) > 0 and TYPES[str(v["t"])]["min"] == 1 and absi(int(v["x"]) - at.x) + absi(int(v["y"]) - at.y) == 1:
		var back: int = damage(st, v, u)
		u["hp"] = maxi(0, int(u["hp"]) - back)
		(st["log"] as Array).append({"a": target_id, "b": id, "d": back})
	u["done"] = true
	Rules.hook(st, "on_attack", [u, v, d])
	_check_end(st)
	return true


static func wait(st: Dictionary, id: int) -> void:
	var u: Dictionary = unit_by_id(st, id)
	if not u.is_empty():
		u["done"] = true


## Fin del turno del bando que juega: capturas, curas en ciudades, cambio de bando.
static func end_turn(st: Dictionary) -> void:
	if bool(st["won"]) or bool(st["lost"]):
		return
	var side: int = int(st["side"])
	var owner: Dictionary = st["owner"]
	## Capturar: la infanteria encima suma su vida (10 si esta entera) cada fin de turno; con 20, es suya.
	## Si se va o muere, se pierde lo sumado.
	var caps: Dictionary = st.get("caps", {})
	var keep: Dictionary = {}
	for u: Variant in alive(st, side):
		var p: Vector2i = Vector2i(int(u["x"]), int(u["y"]))
		if str(u["t"]) == "inf" and owner.has(p) and int(owner[p]) != side:
			var prev: Dictionary = caps.get(p, {})
			var pts: int = (int(prev.get("pts", 0)) if int(prev.get("id", -1)) == int(u["id"]) else 0) + int(u["hp"])
			if pts < 20:
				keep[p] = {"id": int(u["id"]), "pts": pts}
				continue
			var was_hq: bool = tile(st, p) == ("h" if side == 1 else "H")
			owner[p] = side
			Rules.hook(st, "on_capture", [u, p])
			if was_hq:
				st["won"] = side == 1
				st["lost"] = side == 2
				return
	for k: Variant in caps.keys():
		var other: Dictionary = unit_by_id(st, int(caps[k]["id"]))
		if not other.is_empty() and int(other["side"]) != side and int(other["hp"]) > 0 and Vector2i(int(other["x"]), int(other["y"])) == k:
			keep[k] = caps[k]
	st["caps"] = keep
	_check_end(st)
	if bool(st["won"]) or bool(st["lost"]):
		return
	var next: int = 2 if side == 1 else 1
	st["side"] = next
	if next == 1:
		st["turn"] = int(st["turn"]) + 1
		if int(st["turn"]) > int(st["max_turns"]):
			st["lost"] = true
			return
	for u2: Variant in st["units"]:
		if int(u2["side"]) == next:
			u2["moved"] = false
			u2["done"] = false
			u2["shifted"] = false
			var p2: Vector2i = Vector2i(int(u2["x"]), int(u2["y"]))
			if owner.has(p2) and int(owner[p2]) == next and int(u2["hp"]) > 0:
				u2["hp"] = mini(10, int(u2["hp"]) + 2)


static func _check_end(st: Dictionary) -> void:
	if alive(st, 2).is_empty():
		st["won"] = true
	elif alive(st, 1).is_empty():
		st["lost"] = true


static func hq_of(st: Dictionary, side: int) -> Vector2i:
	var ch: String = "H" if side == 1 else "h"
	for y: int in int(st["h"]):
		var x: int = (st["map"][y] as String).find(ch)
		if x >= 0:
			return Vector2i(x, y)
	return Vector2i(-1, -1)


# ------------------------------------------------------------------ IA (rival y tu bot)

## Valor de una jugada (ir a 'to' y, si hay, atacar a 'target'): dano hecho - dano recibido,
## capturas, acercarse al objetivo y no quedarse al descubierto.
static func _score(st: Dictionary, u: Dictionary, to: Vector2i, target: Dictionary, smart: float) -> float:
	var side: int = int(u["side"])
	var s: float = 0.0
	if not target.is_empty():
		var save_x: int = int(u["x"])
		var save_y: int = int(u["y"])
		u["x"] = to.x
		u["y"] = to.y
		var d: int = damage(st, u, target)
		var kill: bool = d >= int(target["hp"])
		var back: int = 0
		if not kill and TYPES[str(target["t"])]["min"] == 1 and absi(int(target["x"]) - to.x) + absi(int(target["y"]) - to.y) == 1:
			var hp_save: int = int(target["hp"])
			target["hp"] = hp_save - d
			back = damage(st, target, u)
			target["hp"] = hp_save
		u["x"] = save_x
		u["y"] = save_y
		var worth: float = {"inf": 1.0, "tank": 2.2, "art": 1.6}[str(target["t"])] * (1.0 + float(10 - int(target["hp"])) / 10.0 * smart)
		if (st.get("caps", {}) as Dictionary).has(Vector2i(int(target["x"]), int(target["y"]))):
			worth += 1.5
		s += float(mini(d, int(target["hp"]))) * worth * 3.0 + (25.0 if kill else 0.0) - float(back) * smart * 2.5
	var owner: Dictionary = st["owner"]
	var enemy_hq: Vector2i = hq_of(st, 2 if side == 1 else 1)
	if str(u["t"]) == "inf":
		if owner.has(to) and int(owner[to]) != side:
			s += 40.0 if to == enemy_hq else 18.0
			if int((st.get("caps", {}) as Dictionary).get(to, {}).get("id", -1)) == int(u["id"]):
				s += 30.0
		s -= float(absi(to.x - enemy_hq.x) + absi(to.y - enemy_hq.y)) * 1.6
	## Acercarse al rival mas cercano (los que no capturan).
	var near: int = 99
	for v: Variant in alive(st, 2 if side == 1 else 1):
		near = mini(near, absi(int(v["x"]) - to.x) + absi(int(v["y"]) - to.y))
	if str(u["t"]) == "art":
		s -= float(absi(near - 3)) * 1.5
	else:
		s -= float(near) * 1.0
	## Ir en grupo: cerca de los tuyos (y sin adelantarte solo si no atacas).
	var friends: int = 0
	var my_front: int = 99
	for f: Variant in alive(st, side):
		if int(f["id"]) == int(u["id"]):
			continue
		var fd: int = absi(int(f["x"]) - to.x) + absi(int(f["y"]) - to.y)
		if fd <= 3:
			friends += 1
		var fnear: int = 99
		for e: Variant in alive(st, 2 if side == 1 else 1):
			fnear = mini(fnear, absi(int(e["x"]) - int(f["x"])) + absi(int(e["y"]) - int(f["y"])))
		my_front = mini(my_front, fnear)
	s += float(mini(friends, 3)) * 3.0 * smart
	if target.is_empty() and my_front < 99 and near < my_front - 2:
		s -= float(my_front - 2 - near) * 4.0 * smart
	## Terreno que protege y ciudades propias que curan.
	s += float(TERRAIN_DEF.get(tile(st, to), 0)) * 1.5 * smart
	if owner.has(to) and int(owner[to]) == side and int(u["hp"]) < 7:
		s += 8.0 * smart
	## Amenaza: el dano que le pueden hacer los rivales que llegan en su turno (con su tipo y su vida).
	var threat: int = 0
	var sx: int = int(u["x"])
	var sy: int = int(u["y"])
	u["x"] = to.x
	u["y"] = to.y
	for v2: Variant in alive(st, 2 if side == 1 else 1):
		if not target.is_empty() and int(v2["id"]) == int(target["id"]):
			continue
		var spec: Dictionary = TYPES[str(v2["t"])]
		var dist: int = absi(int(v2["x"]) - to.x) + absi(int(v2["y"]) - to.y)
		var reach_d: int = int(spec["max"]) if str(v2["t"]) == "art" else int(spec["move"]) + int(spec["max"])
		if dist <= reach_d:
			threat += damage(st, v2, u)
		if str(u["t"]) == "art" and dist == 1:
			threat += 6
	u["x"] = sx
	u["y"] = sy
	s -= float(mini(threat, int(u["hp"]) + 2)) * 1.2 * smart * ({"inf": 1.0, "tank": 1.6, "art": 1.4}[str(u["t"])])
	return s


## Orden en que juega un bando: artilleria (dispara sin moverse), tanques e infanteria.
static func ai_order(st: Dictionary) -> Array:
	var order: Array = alive(st, int(st["side"]))
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ra: int = {"art": 0, "tank": 1, "inf": 2}[str(a["t"])]
		var rb: int = {"art": 0, "tank": 1, "inf": 2}[str(b["t"])]
		return ra < rb if ra != rb else int(a["id"]) < int(b["id"]))
	return order


## Lo que hace una unidad: {"to": Vector2i, "target": id o -1}. El rival a veces se equivoca ("mistake").
static func ai_plan(st: Dictionary, u: Dictionary, smart: float) -> Dictionary:
	var here: Vector2i = Vector2i(int(u["x"]), int(u["y"]))
	var spots: Dictionary = reach(st, u)
	if int(u["side"]) == 2 and (st["rng"] as RandomNumberGenerator).randf() < float(st["mistake"]):
		var keys: Array = spots.keys()
		keys.sort()
		return {"to": keys[(st["rng"] as RandomNumberGenerator).randi_range(0, keys.size() - 1)], "target": -1}
	var best_to: Vector2i = here
	var best_target: Dictionary = {}
	var best_s: float = -1e9
	for to: Variant in spots.keys():
		var p: Vector2i = to
		if str(u["t"]) == "art" and p != here:
			var sm: float = _score(st, u, p, {}, smart)
			if sm > best_s:
				best_s = sm
				best_to = p
				best_target = {}
			continue
		var cands: Array = targets_from(st, u, p)
		cands.append({})
		for tg: Variant in cands:
			var sc: float = _score(st, u, p, tg, smart)
			if sc > best_s:
				best_s = sc
				best_to = p
				best_target = tg
	return {"to": best_to, "target": int(best_target["id"]) if not best_target.is_empty() else -1}


## Ejecuta lo planeado para una unidad.
static func ai_do(st: Dictionary, u: Dictionary, plan: Dictionary) -> void:
	move(st, int(u["id"]), plan["to"])
	if int(plan["target"]) >= 0:
		if not attack(st, int(u["id"]), int(plan["target"])):
			wait(st, int(u["id"]))
	else:
		wait(st, int(u["id"]))


## Juega todas las unidades del bando que tiene el turno y acaba el turno.
static func ai_turn(st: Dictionary, smart: float = -1.0) -> void:
	if smart < 0.0:
		smart = float(st["ai_smart"])
	for u: Variant in ai_order(st):
		if bool(st["won"]) or bool(st["lost"]):
			return
		if int(u["hp"]) <= 0 or bool(u["done"]):
			continue
		ai_do(st, u, ai_plan(st, u, smart))
	end_turn(st)


## Tu bot: las mismas cuentas, prudencia maxima y sin fallos.
const BOT_SMART: float = 1.0


static func bot_play(level: Dictionary) -> Dictionary:
	var st: Dictionary = new_state(level)
	var guard: int = 0
	while not bool(st["won"]) and not bool(st["lost"]) and guard < 400:
		guard += 1
		ai_turn(st, BOT_SMART if int(st["side"]) == 1 else -1.0)
	return {"won": bool(st["won"]), "turns": int(st["turn"]), "mine": alive(st, 1).size(), "theirs": alive(st, 2).size()}


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var st: Dictionary = new_state(level)
	if int(st["w"]) < 5 or int(st["h"]) < 5:
		issues.append("tactics_small")
	if hq_of(st, 1).x < 0 or hq_of(st, 2).x < 0:
		issues.append("tactics_no_hq")
	if alive(st, 1).is_empty() or alive(st, 2).is_empty():
		issues.append("tactics_no_units")
	for u: Variant in st["units"]:
		if not TYPES.has(str(u["t"])) or not (TYPES[str(u["t"])]["cost"] as Dictionary).has(tile(st, Vector2i(int(u["x"]), int(u["y"])))):
			issues.append("tactics_bad_unit")
	var r: Dictionary = {"won": false, "turns": 0}
	if issues.is_empty():
		r = bot_play(level)
		if not bool(r["won"]):
			issues.append("tactics_unbeatable")
		elif int(r["turns"]) < 3:
			issues.append("tactics_too_short")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": 0, "enemies": alive(st, 2).size(), "enemy_problems": [],
		"bot_turns": r.get("turns", 0)}
