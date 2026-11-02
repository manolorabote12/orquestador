extends RefCounted
## Duelo de cartas en tiempo real (estilo Clash Royale): simulacion pura, IA rival, bot y analizador.
## El juego, el bot de QA y el analizador usan estas mismas funciones (step, play_card, think).
## 1 - Arena de 18 x 32 casillas: tu lado abajo (side 0), el rival arriba (side 1). Rio en las
##     filas 15-16 con dos puentes (x 2.5-4.5 y 13.5-15.5); lo de tierra solo cruza por ellos.
## 2 - Cada lado: dos torres de princesa (1400) y la del rey (2400), que despierta cuando le dan o
##     cae una de las suyas. Cada torre caida es una corona; la del rey son las tres y se acaba.
## 3 - Elixir: empieza en 5, +1 cada 2,8 s (el doble el ultimo minuto), hasta 10. Mazo de 8,
##     4 en la mano; la carta jugada vuelve al final del mazo.
## 4 - Tropas: buscan al enemigo mas cercano que ven (5,5 casillas) y que pueden atacar; si no
##     hay, van por su carril (puente) a la torre de ese lado. Hechizos: dano en un circulo.
## 5 - 3 minutos; con empate de coronas, 1 minuto de muerte subita; si sigue, gana quien tenga su
##     torre mas tocada con mas vida.
## Parametros: "deck" (8 cartas tuyas), "ai_deck", "ai_elixir" (ritmo de elixir del rival),
## "ai_level" (vida y dano de sus tropas), "ai_react" (segundos entre decisiones) y "time".

const W: float = 18.0
const H: float = 32.0
const RIVER_TOP: float = 15.0
const RIVER_BOT: float = 17.0
const BRIDGES: Array[float] = [3.5, 14.5]
const ELIXIR_TIME: float = 2.8
const SIGHT: float = 5.5
const DEPLOY: float = 1.0

## Cartas: coste, cuantas salen, vida, dano, segundos entre golpes, alcance, velocidad (casillas/s),
## a que ataca (ground = tierra y edificios, all = tambien aire, buildings = solo edificios),
## si vuela, radio del cuerpo, dano en area y, en hechizos, radio y dano.
const CARDS: Dictionary = {
	"knight": {"cost": 3, "n": 1, "hp": 1450.0, "dmg": 165.0, "hit": 1.2, "range": 0.8, "speed": 1.0, "targets": "ground", "r": 0.5},
	"archers": {"cost": 3, "n": 2, "hp": 260.0, "dmg": 95.0, "hit": 0.9, "range": 5.0, "speed": 1.0, "targets": "all", "r": 0.4},
	"giant": {"cost": 5, "n": 1, "hp": 3400.0, "dmg": 220.0, "hit": 1.5, "range": 0.8, "speed": 0.75, "targets": "buildings", "r": 0.75},
	"minions": {"cost": 3, "n": 3, "hp": 200.0, "dmg": 90.0, "hit": 1.0, "range": 1.8, "speed": 1.5, "targets": "all", "air": true, "r": 0.4},
	"musketeer": {"cost": 4, "n": 1, "hp": 620.0, "dmg": 185.0, "hit": 1.1, "range": 6.0, "speed": 1.0, "targets": "all", "r": 0.45},
	"skeletons": {"cost": 1, "n": 3, "hp": 80.0, "dmg": 80.0, "hit": 1.0, "range": 0.6, "speed": 1.5, "targets": "ground", "r": 0.3},
	"hog": {"cost": 4, "n": 1, "hp": 1450.0, "dmg": 270.0, "hit": 1.6, "range": 0.8, "speed": 1.9, "targets": "buildings", "jump": true, "r": 0.55},
	"valkyrie": {"cost": 4, "n": 1, "hp": 1700.0, "dmg": 230.0, "hit": 1.5, "range": 0.8, "speed": 1.0, "targets": "ground", "splash": 1.6, "r": 0.5},
	"babydragon": {"cost": 4, "n": 1, "hp": 1050.0, "dmg": 135.0, "hit": 1.5, "range": 3.5, "speed": 1.4, "targets": "all", "air": true, "splash": 1.5, "r": 0.6},
	"cannon": {"cost": 3, "n": 1, "hp": 900.0, "dmg": 140.0, "hit": 0.9, "range": 5.5, "speed": 0.0, "targets": "ground", "building": true, "life": 30.0, "r": 0.9},
	"fireball": {"cost": 4, "spell": true, "radius": 2.5, "dmg": 600.0},
	"arrows": {"cost": 3, "spell": true, "radius": 4.0, "dmg": 250.0},
}
const DECK_BASE: Array[String] = ["knight", "archers", "giant", "minions", "musketeer", "skeletons", "arrows", "fireball"]
const TOWER_SPELL: float = 0.35
const TANKS: Array[String] = ["giant", "hog", "knight", "valkyrie"]
const SUPPORT: Array[String] = ["musketeer", "archers", "babydragon", "minions"]


static func card_ok(c: String) -> bool:
	return CARDS.has(c)


static func deck_of(v: Variant, fallback: Array[String]) -> Array[String]:
	var out: Array[String] = []
	if v is Array:
		for c: Variant in v:
			if card_ok(str(c)) and not out.has(str(c)):
				out.append(str(c))
	for c2: String in fallback:
		if out.size() >= 8:
			break
		if not out.has(c2):
			out.append(c2)
	return out.slice(0, 8)


static func seed_of(level: Dictionary) -> int:
	var s: int = int(level.get("seed", 1))
	for r: Variant in level.get("map", []):
		var row: String = str(r)
		if row.begins_with("#") and row.substr(1).is_valid_int():
			s = int(row.substr(1))
	return s


static func new_state(level: Dictionary) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_of(level)
	var st: Dictionary = {"rng": rng, "t": 0.0, "time": clampf(float(level.get("time", 180.0)), 60.0, 300.0), "over": false,
		"winner": -1, "overtime": false, "ents": [], "next_id": 0, "events": [], "crowns": [0, 0], "elixir": [5.0, 5.0],
		"rate": [1.0, clampf(float(level.get("ai_elixir", 1.0)), 0.5, 1.6)], "lvl": [1.0, clampf(float(level.get("ai_level", 1.0)), 0.6, 1.5)],
		"react": [0.5, clampf(float(level.get("ai_react", 1.0)), 0.3, 3.0)], "think_t": [0.0, 0.0], "hands": [[], []], "queues": [[], []],
		"plan": [{}, {}], "played": [0, 0]}
	var decks: Array = [deck_of(level.get("deck", []), DECK_BASE), deck_of(level.get("ai_deck", []), DECK_BASE)]
	for s: int in 2:
		var d: Array = decks[s].duplicate()
		for i: int in range(d.size() - 1, 0, -1):
			var j: int = rng.randi_range(0, i)
			var tmp: Variant = d[i]
			d[i] = d[j]
			d[j] = tmp
		st["hands"][s] = d.slice(0, 4)
		st["queues"][s] = d.slice(4)
	## Torres: princesas y rey de cada lado (en espejo).
	for s2: int in 2:
		for bx: float in BRIDGES:
			_add(st, {"kind": "tower", "side": s2, "p": Vector2(bx, 25.5 if s2 == 0 else 6.5), "hp": 1400.0, "max": 1400.0,
				"dmg": 50.0, "hit": 0.8, "range": 7.5, "r": 1.5, "building": true, "targets": "all", "active": true})
		_add(st, {"kind": "king", "side": s2, "p": Vector2(9.0, 29.5 if s2 == 0 else 2.5), "hp": 2400.0, "max": 2400.0,
			"dmg": 55.0, "hit": 1.0, "range": 7.0, "r": 2.0, "building": true, "targets": "all", "active": false})
	return st


static func _add(st: Dictionary, e: Dictionary) -> Dictionary:
	e["id"] = int(st["next_id"])
	st["next_id"] = int(st["next_id"]) + 1
	e["cd"] = float(e.get("hit", 1.0)) * 0.5
	e["target"] = -1
	e["dead"] = false
	e["deploy"] = float(e.get("deploy", 0.0))
	(st["ents"] as Array).append(e)
	return e


static func _ev(st: Dictionary, kind: String, extra: Dictionary = {}) -> void:
	var e: Dictionary = {"kind": kind}
	e.merge(extra)
	(st["events"] as Array).append(e)


static func ent(st: Dictionary, id: int) -> Dictionary:
	for e: Dictionary in st["ents"]:
		if int(e["id"]) == id:
			return e
	return {}


static func towers(st: Dictionary, side: int) -> Array:
	var out: Array = []
	for e: Dictionary in st["ents"]:
		if int(e["side"]) == side and str(e.get("kind", "")) in ["tower", "king"] and not bool(e["dead"]):
			out.append(e)
	return out


# ------------------------------------------------------------------ cartas

## Donde puede soltar tropas un lado: su mitad (sin el rio); los hechizos, en cualquier sitio.
static func can_drop(side: int, card: String, p: Vector2) -> bool:
	if p.x < 0.5 or p.x > W - 0.5 or p.y < 0.5 or p.y > H - 0.5:
		return false
	if bool((CARDS[card] as Dictionary).get("spell", false)):
		return true
	return p.y >= RIVER_BOT + 0.3 if side == 0 else p.y <= RIVER_TOP - 0.3


## Juega la carta "slot" de la mano en "p". Devuelve true si se ha jugado.
static func play_card(st: Dictionary, side: int, slot: int, p: Vector2) -> bool:
	if bool(st["over"]):
		return false
	var hand: Array = st["hands"][side]
	if slot < 0 or slot >= hand.size():
		return false
	var card: String = str(hand[slot])
	var c: Dictionary = CARDS[card]
	if float(st["elixir"][side]) < float(c["cost"]) or not can_drop(side, card, p):
		return false
	st["elixir"][side] = float(st["elixir"][side]) - float(c["cost"])
	var q: Array = st["queues"][side]
	q.append(card)
	hand[slot] = q.pop_front()
	st["played"][side] = int(st["played"][side]) + 1
	_ev(st, "play", {"side": side, "card": card, "p": p})
	if bool(c.get("spell", false)):
		_spell(st, side, card, p)
		return true
	var lvl: float = float(st["lvl"][side])
	var n: int = int(c["n"])
	for k: int in n:
		var off: Vector2 = Vector2.ZERO if n == 1 else Vector2(cos(TAU * float(k) / float(n)), sin(TAU * float(k) / float(n))) * 0.7
		var u: Dictionary = {"kind": "unit", "card": card, "side": side, "p": p + off, "hp": float(c["hp"]) * lvl, "max": float(c["hp"]) * lvl,
			"dmg": float(c["dmg"]) * lvl, "hit": float(c["hit"]), "range": float(c["range"]), "speed": float(c["speed"]), "r": float(c["r"]),
			"targets": str(c["targets"]), "air": bool(c.get("air", false)), "building": bool(c.get("building", false)),
			"splash": float(c.get("splash", 0.0)), "jump": bool(c.get("jump", false)), "life": float(c.get("life", 0.0)), "deploy": DEPLOY}
		_add(st, u)
	return true


static func _spell(st: Dictionary, side: int, card: String, p: Vector2) -> void:
	var c: Dictionary = CARDS[card]
	var dmg: float = float(c["dmg"]) * float(st["lvl"][side])
	_ev(st, "spell", {"side": side, "card": card, "p": p, "radius": float(c["radius"])})
	for e: Dictionary in st["ents"]:
		if int(e["side"]) == side or bool(e["dead"]):
			continue
		if (e["p"] as Vector2).distance_to(p) <= float(c["radius"]) + float(e["r"]) * 0.5:
			_hurt(st, e, dmg * (TOWER_SPELL if str(e.get("kind", "")) in ["tower", "king"] else 1.0), side)


# ------------------------------------------------------------------ simulacion

static func step(st: Dictionary, dt: float) -> void:
	if bool(st["over"]):
		return
	st["t"] = float(st["t"]) + dt
	var double: bool = float(st["t"]) > float(st["time"]) - 60.0
	for s: int in 2:
		var gain: float = dt / ELIXIR_TIME * float(st["rate"][s]) * (2.0 if double else 1.0)
		st["elixir"][s] = minf(10.0, float(st["elixir"][s]) + gain)
	for e: Dictionary in st["ents"]:
		if bool(e["dead"]):
			continue
		if float(e["deploy"]) > 0.0:
			e["deploy"] = float(e["deploy"]) - dt
			continue
		if bool(e.get("building", false)) and float(e.get("life", 0.0)) > 0.0:
			e["life"] = float(e["life"]) - dt
			if float(e["life"]) <= 0.0:
				e["hp"] = 0.0
				_kill(st, e, -1)
				continue
		if str(e.get("kind", "")) == "king" and not bool(e["active"]):
			continue
		_act(st, e, dt)
	_separate(st)
	st["ents"] = (st["ents"] as Array).filter(func(e2: Dictionary) -> bool: return not bool(e2["dead"]))
	_check_end(st)


static func _can_hit(a: Dictionary, b: Dictionary) -> bool:
	if int(a["side"]) == int(b["side"]) or bool(b["dead"]):
		return false
	match str(a["targets"]):
		"buildings":
			return bool(b.get("building", false))
		"ground":
			return not bool(b.get("air", false))
	return true


static func gap(a: Dictionary, b: Dictionary) -> float:
	return (a["p"] as Vector2).distance_to(b["p"]) - float(a["r"]) - float(b["r"])


static func _act(st: Dictionary, e: Dictionary, dt: float) -> void:
	var tgt: Dictionary = ent(st, int(e["target"])) if int(e["target"]) >= 0 else {}
	var mobile: bool = float(e.get("speed", 0.0)) > 0.0
	## Busca objetivo: el mas cercano que ve y puede atacar (torres y edificios: en su alcance).
	if tgt.is_empty() or bool(tgt["dead"]) or (not mobile and gap(e, tgt) > float(e["range"])) or (mobile and str(tgt.get("kind", "")) in ["tower", "king"]):
		var best: Dictionary = {}
		var bd: float = INF
		var look: float = maxf(SIGHT, float(e["range"])) if mobile else float(e["range"])
		for o: Dictionary in st["ents"]:
			if not _can_hit(e, o):
				continue
			var d: float = gap(e, o)
			if d <= look and d < bd:
				bd = d
				best = o
		if not best.is_empty():
			tgt = best
			e["target"] = int(best["id"])
		elif not tgt.is_empty() and (bool(tgt["dead"]) or not mobile):
			tgt = {}
			e["target"] = -1
	e["cd"] = maxf(0.0, float(e["cd"]) - dt)
	if not tgt.is_empty() and gap(e, tgt) <= float(e["range"]):
		if float(e["cd"]) <= 0.0:
			e["cd"] = float(e["hit"])
			_strike(st, e, tgt)
		return
	if not mobile:
		return
	## Camino: al objetivo, o por su carril a la torre enemiga de ese lado.
	var goal: Vector2
	if not tgt.is_empty():
		goal = tgt["p"]
	else:
		goal = _lane_goal(st, e)
	var wp: Vector2 = _waypoint(e, goal)
	var v: Vector2 = wp - (e["p"] as Vector2)
	var step_len: float = float(e["speed"]) * dt
	if v.length() > 0.001:
		e["p"] = (e["p"] as Vector2) + v.normalized() * minf(step_len, v.length())
		e["face"] = v.normalized()


## Torre enemiga de su carril (o la del rey si ya cayo).
static func _lane_goal(st: Dictionary, e: Dictionary) -> Vector2:
	var foe: int = 1 - int(e["side"])
	var lane_x: float = BRIDGES[0] if (e["p"] as Vector2).x < W * 0.5 else BRIDGES[1]
	var king: Vector2 = Vector2(9.0, 2.5 if foe == 1 else 29.5)
	for t: Dictionary in towers(st, foe):
		if str(t["kind"]) == "tower" and absf((t["p"] as Vector2).x - lane_x) < 1.0:
			return t["p"]
	return king


## Por tierra, el rio solo se cruza por un puente (salvo los que saltan o vuelan).
static func _waypoint(e: Dictionary, goal: Vector2) -> Vector2:
	var p: Vector2 = e["p"]
	if bool(e.get("air", false)) or bool(e.get("jump", false)):
		return goal
	var mid: float = (RIVER_TOP + RIVER_BOT) * 0.5
	var crossing: bool = (p.y > mid) != (goal.y > mid)
	var in_river: bool = p.y > RIVER_TOP - 0.2 and p.y < RIVER_BOT + 0.2
	if not crossing and not in_river:
		return goal
	var bx: float = BRIDGES[0] if absf(p.x - BRIDGES[0]) < absf(p.x - BRIDGES[1]) else BRIDGES[1]
	var exit_y: float = RIVER_TOP - 0.7 if goal.y < mid else RIVER_BOT + 0.7
	if absf(p.x - bx) > 0.45:
		if in_river:
			return Vector2(bx, p.y)
		return Vector2(bx, RIVER_BOT + 0.6 if p.y > mid else RIVER_TOP - 0.6)
	## Alineado con el puente: cruza en recto hasta la otra orilla.
	return Vector2(bx, exit_y)


static func _strike(st: Dictionary, e: Dictionary, tgt: Dictionary) -> void:
	_ev(st, "hit", {"from": int(e["id"]), "to": int(tgt["id"]), "a": e["p"], "b": tgt["p"], "ranged": float(e["range"]) > 1.5, "side": int(e["side"])})
	if float(e.get("splash", 0.0)) > 0.0:
		var center: Vector2 = tgt["p"]
		for o: Dictionary in st["ents"]:
			if _can_hit(e, o) and (o["p"] as Vector2).distance_to(center) <= float(e["splash"]) + float(o["r"]):
				_hurt(st, o, float(e["dmg"]), int(e["side"]))
	else:
		_hurt(st, tgt, float(e["dmg"]), int(e["side"]))


static func _hurt(st: Dictionary, e: Dictionary, dmg: float, by: int) -> void:
	if bool(e["dead"]):
		return
	e["hp"] = float(e["hp"]) - dmg
	if str(e.get("kind", "")) == "king":
		e["active"] = true
	if float(e["hp"]) <= 0.0:
		_kill(st, e, by)


static func _kill(st: Dictionary, e: Dictionary, by: int) -> void:
	e["dead"] = true
	e["hp"] = 0.0
	var kind: String = str(e.get("kind", ""))
	_ev(st, "die", {"id": int(e["id"]), "p": e["p"], "side": int(e["side"]), "kind": kind, "card": str(e.get("card", ""))})
	if kind == "tower" or kind == "king":
		var foe: int = 1 - int(e["side"])
		st["crowns"][foe] = 3 if kind == "king" else mini(3, int(st["crowns"][foe]) + 1)
		_ev(st, "crown", {"side": foe, "crowns": int(st["crowns"][foe]), "kind": kind})
		for k: Dictionary in st["ents"]:
			if str(k.get("kind", "")) == "king" and int(k["side"]) == int(e["side"]):
				k["active"] = true


## Las tropas de tierra no se pisan: se apartan un poco (las torres no se mueven).
static func _separate(st: Dictionary) -> void:
	var ents: Array = st["ents"]
	for i: int in ents.size():
		var a: Dictionary = ents[i]
		if bool(a["dead"]) or str(a.get("kind", "")) != "unit" or bool(a.get("building", false)):
			continue
		for j: int in ents.size():
			if i == j:
				continue
			var b: Dictionary = ents[j]
			if bool(b["dead"]) or bool(a.get("air", false)) != bool(b.get("air", false)):
				continue
			var d: Vector2 = (a["p"] as Vector2) - (b["p"] as Vector2)
			var need: float = float(a["r"]) + float(b["r"])
			var l: float = d.length()
			if l < need and l > 0.0001:
				var push: float = (need - l) * (0.5 if str(b.get("kind", "")) == "unit" and not bool(b.get("building", false)) else 1.0)
				a["p"] = (a["p"] as Vector2) + d / l * push
			elif l <= 0.0001:
				a["p"] = (a["p"] as Vector2) + Vector2(0.05 * float(i % 3 - 1), 0.05)
		a["p"] = Vector2(clampf((a["p"] as Vector2).x, 0.4, W - 0.4), clampf((a["p"] as Vector2).y, 0.4, H - 0.4))


static func _check_end(st: Dictionary) -> void:
	var c: Array = st["crowns"]
	if int(c[0]) >= 3 or int(c[1]) >= 3:
		_end(st, 0 if int(c[0]) >= 3 else 1)
		return
	var t: float = float(st["t"])
	var limit: float = float(st["time"])
	if not bool(st["overtime"]):
		if t >= limit:
			if int(c[0]) != int(c[1]):
				_end(st, 0 if int(c[0]) > int(c[1]) else 1)
			else:
				st["overtime"] = true
				st["time"] = limit + 60.0
				_ev(st, "overtime")
		return
	## Muerte subita: la primera corona gana; al final, la torre mas tocada decide.
	if int(c[0]) != int(c[1]):
		_end(st, 0 if int(c[0]) > int(c[1]) else 1)
	elif t >= limit:
		var low: Array = [INF, INF]
		for e: Dictionary in st["ents"]:
			if str(e.get("kind", "")) in ["tower", "king"]:
				low[int(e["side"])] = minf(float(low[int(e["side"])]), float(e["hp"]))
		_end(st, 0 if float(low[0]) > float(low[1]) else (1 if float(low[1]) > float(low[0]) else 2))


static func _end(st: Dictionary, winner: int) -> void:
	st["over"] = true
	st["winner"] = winner
	_ev(st, "end", {"winner": winner})


# ------------------------------------------------------------------ cabeza (IA rival y bot)

static func _own_half(side: int, y: float) -> bool:
	return y > RIVER_BOT if side == 0 else y < RIVER_TOP


## Hacia mi rey (en y): +1 abajo para el lado 0, -1 para el 1.
static func _home(side: int) -> float:
	return 1.0 if side == 0 else -1.0


static func _affordable(st: Dictionary, side: int) -> Array:
	var out: Array = []
	var hand: Array = st["hands"][side]
	for i: int in hand.size():
		if float(CARDS[str(hand[i])]["cost"]) <= float(st["elixir"][side]):
			out.append(i)
	return out


## Una decision (o nada). La usan la IA rival y el bot: mismas reglas, distinto lado.
static func think(st: Dictionary, side: int) -> Dictionary:
	var hand: Array = st["hands"][side]
	var ok: Array = _affordable(st, side)
	var foe: int = 1 - side
	## 1 - Amenazas en mi mitad (o a punto de cruzar).
	var threats: Array = []
	for e: Dictionary in st["ents"]:
		if int(e["side"]) == foe and str(e.get("kind", "")) == "unit" and not bool(e.get("building", false)):
			var y: float = (e["p"] as Vector2).y
			if _own_half(side, y) or absf(y - 16.0) < 3.5:
				threats.append(e)
	if not threats.is_empty():
		## Hechizo si hay 3 o mas juntos.
		for i: int in ok:
			var c: Dictionary = CARDS[str(hand[i])]
			if bool(c.get("spell", false)):
				var best_p: Vector2 = Vector2.ZERO
				var best_n: int = 0
				for t: Dictionary in threats:
					var n: int = 0
					for t2: Dictionary in threats:
						if (t["p"] as Vector2).distance_to(t2["p"]) <= float(c["radius"]) * 0.8:
							n += 1
					if n > best_n:
						best_n = n
						best_p = t["p"]
				if best_n >= 3:
					return {"slot": i, "p": best_p}
		## Contra la amenaza mas adelantada: la mejor respuesta que pueda pagar.
		threats.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a["p"] as Vector2).y * _home(side) > (b["p"] as Vector2).y * _home(side))
		var th: Dictionary = threats[0]
		var air: bool = bool(th.get("air", false))
		var swarm: int = 0
		for t3: Dictionary in threats:
			if (t3["p"] as Vector2).distance_to(th["p"]) < 3.0:
				swarm += 1
		var mine: int = 0
		for e2: Dictionary in st["ents"]:
			if int(e2["side"]) == side and str(e2.get("kind", "")) == "unit" and (e2["p"] as Vector2).distance_to(th["p"]) < 5.0:
				mine += 1
		if mine < 2:
			var pick: int = -1
			var bscore: float = -INF
			for i2: int in ok:
				var card: String = str(hand[i2])
				var c2: Dictionary = CARDS[card]
				if bool(c2.get("spell", false)):
					continue
				if air and str(c2["targets"]) != "all":
					continue
				var s: float = 10.0 - float(c2["cost"])
				if swarm >= 3 and (float(c2.get("splash", 0.0)) > 0.0):
					s += 8.0
				if str(th["targets"]) == "buildings" and (card == "cannon" or card == "skeletons" or card == "knight" or card == "minions"):
					s += 6.0
				if float(th["hp"]) > 1200.0 and float(c2["dmg"]) / float(c2["hit"]) * float(c2["n"]) > 200.0:
					s += 4.0
				if s > bscore:
					bscore = s
					pick = i2
			if pick >= 0:
				var tp: Vector2 = th["p"]
				var at: Vector2
				if bool(CARDS[str(hand[pick])].get("building", false)):
					at = Vector2(9.0, 21.5 if side == 0 else 10.5)
				else:
					at = tp + Vector2(0, 2.5 * _home(side))
				at.y = clampf(at.y, RIVER_BOT + 0.5, H - 1.0) if side == 0 else clampf(at.y, 1.0, RIVER_TOP - 0.5)
				at.x = clampf(at.x, 1.0, W - 1.0)
				return {"slot": pick, "p": at}
		return {}
	## 2 - Rematar una torre con un hechizo.
	for i3: int in ok:
		var c3: Dictionary = CARDS[str(hand[i3])]
		if bool(c3.get("spell", false)):
			for t4: Dictionary in towers(st, foe):
				if float(t4["hp"]) <= float(c3["dmg"]) * TOWER_SPELL * float(st["lvl"][side]):
					return {"slot": i3, "p": t4["p"]}
	## 3 - Ataque: con elixir de sobra, tanque por el carril mas flojo y apoyo detras.
	var plan: Dictionary = st["plan"][side]
	var lane: float = _weak_lane(st, foe)
	if not plan.is_empty():
		var tank: Dictionary = ent(st, int(plan.get("tank", -1)))
		if tank.is_empty() or bool(tank["dead"]):
			st["plan"][side] = {}
		else:
			for i4: int in ok:
				if str(hand[i4]) in SUPPORT:
					st["plan"][side] = {}
					return {"slot": i4, "p": Vector2((tank["p"] as Vector2).x, clampf((tank["p"] as Vector2).y + 2.0 * _home(side), RIVER_BOT + 0.5 if side == 0 else 1.0, H - 1.0 if side == 0 else RIVER_TOP - 0.5))}
	if float(st["elixir"][side]) >= 8.5:
		for i5: int in ok:
			if str(hand[i5]) in TANKS:
				var back: float = (H - 3.5) if side == 0 else 3.5
				var y2: float = back if str(hand[i5]) == "giant" else (RIVER_BOT + 1.0 if side == 0 else RIVER_TOP - 1.0)
				return {"slot": i5, "p": Vector2(lane, y2), "tank": true}
		## Sin tanque: lo mas barato en el puente para no desperdiciar elixir.
		var cheap: int = -1
		for i6: int in ok:
			if not bool(CARDS[str(hand[i6])].get("spell", false)) and not bool(CARDS[str(hand[i6])].get("building", false)):
				if cheap < 0 or int(CARDS[str(hand[i6])]["cost"]) < int(CARDS[str(hand[cheap])]["cost"]):
					cheap = i6
		if cheap >= 0 and float(st["elixir"][side]) >= 9.8:
			return {"slot": cheap, "p": Vector2(lane, RIVER_BOT + 1.0 if side == 0 else RIVER_TOP - 1.0)}
	return {}


## Carril con la torre enemiga mas tocada (o la de la izquierda).
static func _weak_lane(st: Dictionary, foe: int) -> float:
	var best: float = BRIDGES[0]
	var bh: float = INF
	for t: Dictionary in towers(st, foe):
		if str(t["kind"]) == "tower" and float(t["hp"]) < bh:
			bh = float(t["hp"])
			best = (t["p"] as Vector2).x
	return best


## Turno de pensar de un lado: cada "react" segundos, con algo de azar en el momento.
static func think_step(st: Dictionary, side: int, dt: float) -> void:
	st["think_t"][side] = float(st["think_t"][side]) - dt
	if float(st["think_t"][side]) > 0.0:
		return
	var rng: RandomNumberGenerator = st["rng"]
	st["think_t"][side] = float(st["react"][side]) * (0.75 + 0.5 * rng.randf())
	var m: Dictionary = think(st, side)
	if m.has("slot"):
		var first: int = int(st["next_id"])
		if play_card(st, side, int(m["slot"]), m["p"]) and bool(m.get("tank", false)):
			st["plan"][side] = {"tank": first}


## Partida entera bot contra IA (lo que hace el analizador).
static func sim_match(level: Dictionary, dt: float = 0.1) -> Dictionary:
	var st: Dictionary = new_state(level)
	var guard: int = 0
	while not bool(st["over"]) and guard < 6000:
		think_step(st, 0, dt)
		think_step(st, 1, dt)
		step(st, dt)
		(st["events"] as Array).clear()
		guard += 1
	return {"winner": int(st["winner"]), "crowns": (st["crowns"] as Array).duplicate(), "t": float(st["t"]), "played": (st["played"] as Array).duplicate()}


# ------------------------------------------------------------------ analizador

static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var bad: int = 0
	for key: String in ["deck", "ai_deck"]:
		if level.get(key, []) is Array:
			for c: Variant in level.get(key, []):
				if not card_ok(str(c)):
					bad += 1
	if bad > 0:
		issues.append("clash_bad_card")
	var wins: int = 0
	var crowns: int = 0
	var base: int = seed_of(level)
	for k: int in 3:
		var lv: Dictionary = level.duplicate()
		lv["seed"] = base + k * 97
		lv["map"] = ["arena", "#%d" % (base + k * 97)]
		var r: Dictionary = sim_match(lv)
		if int(r["winner"]) == 0:
			wins += 1
		crowns += int(r["crowns"][0])
	if wins < 2:
		issues.append("clash_too_hard")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": 3, "enemies": 0, "enemy_problems": [],
		"par": int(float(level.get("time", 180.0))), "wins": wins, "crowns": crowns}
