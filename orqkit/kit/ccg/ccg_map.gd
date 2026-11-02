extends RefCounted
## Cartas coleccionables (tipo Hearthstone) contra la maquina. Cada turno sube el mana (hasta 10) y
## robas una carta. Los esbirros van a tu mesa (hasta MAX_BOARD) y atacan desde el turno siguiente
## ("charge": ya); "taunt" obliga a atacarles antes; "shield" anula el primer golpe. Los hechizos
## danan, curan, roban, mejoran o golpean a todos. Gana quien deja al heroe rival a 0. Sin cartas en
## el mazo, cada robo hace dano (fatiga).
## Nivel: "deck" y "foe_deck" (ids de CARDS), "hp" y "foe_hp", "seed", "first" (quien empieza).

const Rules = preload("res://kit/rules.gd")
const MAX_BOARD: int = 5
const MAX_HAND: int = 7
## Cartas: id -> {cost, kind: minion|spell, atk, hp, kw, fx (dmg|heal|draw|buff|aoe|face), n}.
const CARDS: Dictionary = {
	"recluta": {"cost": 1, "kind": "minion", "atk": 1, "hp": 2},
	"lobo": {"cost": 1, "kind": "minion", "atk": 2, "hp": 1, "kw": "charge"},
	"escudero": {"cost": 2, "kind": "minion", "atk": 1, "hp": 3, "kw": "taunt"},
	"arquera": {"cost": 2, "kind": "minion", "atk": 3, "hp": 2},
	"guardia": {"cost": 3, "kind": "minion", "atk": 2, "hp": 4, "kw": "taunt"},
	"jinete": {"cost": 3, "kind": "minion", "atk": 3, "hp": 2, "kw": "charge"},
	"paladin": {"cost": 4, "kind": "minion", "atk": 3, "hp": 4, "kw": "shield"},
	"ogro": {"cost": 5, "kind": "minion", "atk": 5, "hp": 5},
	"muro": {"cost": 5, "kind": "minion", "atk": 2, "hp": 7, "kw": "taunt"},
	"dragon": {"cost": 7, "kind": "minion", "atk": 7, "hp": 7, "kw": "shield"},
	"chispa": {"cost": 1, "kind": "spell", "fx": "dmg", "n": 2},
	"bola_fuego": {"cost": 4, "kind": "spell", "fx": "dmg", "n": 6},
	"pocion": {"cost": 2, "kind": "spell", "fx": "heal", "n": 6},
	"estudio": {"cost": 3, "kind": "spell", "fx": "draw", "n": 2},
	"bendicion": {"cost": 2, "kind": "spell", "fx": "buff", "n": 2},
	"tormenta": {"cost": 5, "kind": "spell", "fx": "aoe", "n": 2},
}


static func new_state(level: Dictionary) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(level.get("seed", 1))
	var st: Dictionary = {"rng": rng, "turn": 0, "side": 1, "won": false, "lost": false, "uid": 0, "log": [],
		"p": [{}, _player(level.get("deck", []), int(level.get("hp", 25)), rng), _player(level.get("foe_deck", []), int(level.get("foe_hp", 25)), rng)]}
	for k: int in 3:
		draw(st, 1)
		draw(st, 2)
	draw(st, 2)
	st["rules"] = Rules.load_rules(level)
	Rules.hook(st, "on_start")
	st["side"] = 2 if str(level.get("first", "player")) == "foe" else 1
	begin_turn(st)
	return st


static func _player(deck: Array, hp: int, rng: RandomNumberGenerator) -> Dictionary:
	var d: Array = []
	for c: Variant in deck:
		if CARDS.has(str(c)):
			d.append(str(c))
	## Barajar con la semilla (Fisher-Yates).
	for i: int in range(d.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var t: String = d[i]
		d[i] = d[j]
		d[j] = t
	return {"hp": hp, "max_hp": hp, "deck": d, "hand": [], "board": [], "mana": 0, "max_mana": 0, "fatigue": 0}


static func draw(st: Dictionary, side: int) -> void:
	var p: Dictionary = st["p"][side]
	if (p["deck"] as Array).is_empty():
		p["fatigue"] = int(p["fatigue"]) + 1
		p["hp"] = int(p["hp"]) - int(p["fatigue"])
		_check(st)
		return
	var c: String = (p["deck"] as Array).pop_back()
	if (p["hand"] as Array).size() < MAX_HAND:
		(p["hand"] as Array).append(c)


static func begin_turn(st: Dictionary) -> void:
	var side: int = int(st["side"])
	var p: Dictionary = st["p"][side]
	if side == 1:
		st["turn"] = int(st["turn"]) + 1
	p["max_mana"] = mini(10, int(p["max_mana"]) + 1)
	p["mana"] = int(p["max_mana"])
	for m: Variant in p["board"]:
		m["ready"] = true
	draw(st, side)


static func end_turn(st: Dictionary) -> void:
	if bool(st["won"]) or bool(st["lost"]):
		return
	st["side"] = 2 if int(st["side"]) == 1 else 1
	begin_turn(st)
	if int(st["turn"]) > 40:
		st["lost"] = true


static func _check(st: Dictionary) -> void:
	if int(st["p"][2]["hp"]) <= 0:
		st["won"] = true
	elif int(st["p"][1]["hp"]) <= 0:
		st["lost"] = true


static func foe_of(side: int) -> int:
	return 2 if side == 1 else 1


## Objetivos validos para atacar con un esbirro: si el rival tiene "taunt", solo esos.
static func attack_targets(st: Dictionary, side: int) -> Array:
	var foe: Dictionary = st["p"][foe_of(side)]
	var taunts: Array = (foe["board"] as Array).filter(func(m: Dictionary) -> bool: return str(m.get("kw", "")) == "taunt")
	if not taunts.is_empty():
		return taunts
	var out: Array = (foe["board"] as Array).duplicate()
	out.append({"hero": true})
	return out


## Juega la carta i de la mano del bando que tiene el turno. target: {} , {"hero": side} o un esbirro.
static func play(st: Dictionary, i: int, target: Dictionary = {}) -> bool:
	if bool(st["won"]) or bool(st["lost"]):
		return false
	var side: int = int(st["side"])
	var p: Dictionary = st["p"][side]
	var hand: Array = p["hand"]
	if i < 0 or i >= hand.size():
		return false
	var id: String = hand[i]
	var c: Dictionary = CARDS[id]
	if int(c["cost"]) > int(p["mana"]):
		return false
	if str(c["kind"]) == "minion":
		if (p["board"] as Array).size() >= MAX_BOARD:
			return false
		st["uid"] = int(st["uid"]) + 1
		(p["board"] as Array).append({"uid": int(st["uid"]), "id": id, "atk": int(c["atk"]), "hp": int(c["hp"]), "max": int(c["hp"]),
			"kw": str(c.get("kw", "")), "ready": str(c.get("kw", "")) == "charge", "shield": str(c.get("kw", "")) == "shield"})
	else:
		if not _cast(st, side, str(c["fx"]), int(c["n"]), target):
			return false
	p["mana"] = int(p["mana"]) - int(c["cost"])
	hand.remove_at(i)
	(st["log"] as Array).append({"side": side, "play": id})
	Rules.hook(st, "on_play", [side, id])
	_cleanup(st)
	return true


## Hechizos que piden objetivo: dmg (esbirro o heroe rival), heal (tu heroe o un esbirro tuyo), buff (esbirro tuyo).
static func needs_target(id: String) -> bool:
	var c: Dictionary = CARDS[id]
	return str(c["kind"]) == "spell" and ["dmg", "heal", "buff"].has(str(c["fx"]))


static func _cast(st: Dictionary, side: int, fx: String, n: int, target: Dictionary) -> bool:
	var me: Dictionary = st["p"][side]
	var foe: Dictionary = st["p"][foe_of(side)]
	match fx:
		"dmg":
			if target.has("hero"):
				foe["hp"] = int(foe["hp"]) - n
			elif (foe["board"] as Array).has(target):
				_hurt(target, n)
			else:
				return false
		"heal":
			if target.has("hero") or target.is_empty():
				me["hp"] = mini(int(me["max_hp"]), int(me["hp"]) + n)
			elif (me["board"] as Array).has(target):
				target["hp"] = mini(int(target["max"]), int(target["hp"]) + n)
			else:
				return false
		"buff":
			if not (me["board"] as Array).has(target):
				return false
			target["atk"] = int(target["atk"]) + n
			target["hp"] = int(target["hp"]) + n
			target["max"] = int(target["max"]) + n
		"draw":
			for k: int in n:
				draw(st, side)
		"aoe":
			for m: Variant in (foe["board"] as Array).duplicate():
				_hurt(m, n)
	_check(st)
	return true


static func _hurt(m: Dictionary, n: int) -> void:
	if n <= 0:
		return
	if bool(m.get("shield", false)):
		m["shield"] = false
		return
	m["hp"] = int(m["hp"]) - n


static func _cleanup(st: Dictionary) -> void:
	for s: int in [1, 2]:
		var b: Array = st["p"][s]["board"]
		for k: int in range(b.size() - 1, -1, -1):
			if int(b[k]["hp"]) <= 0:
				b.remove_at(k)
	_check(st)


## El esbirro uid (del bando que juega) ataca a target (esbirro rival o {"hero": true}).
static func attack(st: Dictionary, uid: int, target: Dictionary) -> bool:
	if bool(st["won"]) or bool(st["lost"]):
		return false
	var side: int = int(st["side"])
	var a: Dictionary = {}
	for m: Variant in st["p"][side]["board"]:
		if int(m["uid"]) == uid:
			a = m
	if a.is_empty() or not bool(a["ready"]) or int(a["atk"]) <= 0:
		return false
	var valid: bool = false
	for t: Variant in attack_targets(st, side):
		if (t.has("hero") and target.has("hero")) or (not target.has("hero") and t.has("uid") and int(t["uid"]) == int(target.get("uid", -1))):
			valid = true
	if not valid:
		return false
	if target.has("hero"):
		var foe: Dictionary = st["p"][foe_of(side)]
		foe["hp"] = int(foe["hp"]) - int(a["atk"])
	else:
		_hurt(target, int(a["atk"]))
		_hurt(a, int(target["atk"]))
	a["ready"] = false
	(st["log"] as Array).append({"side": side, "attack": uid})
	Rules.hook(st, "on_attack", [side, a, target])
	_cleanup(st)
	return true


# ------------------------------------------------------------------ IA (rival y tu bot)

static func _minion_value(m: Dictionary) -> float:
	var v: float = float(int(m["atk"])) * 1.2 + float(int(m["hp"]))
	if str(m.get("kw", "")) == "taunt":
		v += 1.5
	if bool(m.get("shield", false)):
		v += float(int(m["atk"]))
	return v


## Un turno entero de la IA del bando que juega. smart: 0 a 1 (con 1 busca el golpe final y cambios buenos).
static func ai_turn(st: Dictionary, smart: float) -> void:
	var side: int = int(st["side"])
	var guard: int = 0
	while guard < 30 and not bool(st["won"]) and not bool(st["lost"]):
		guard += 1
		if not _ai_step(st, side, smart):
			break
	end_turn(st)


## Una accion de la IA (jugar una carta o atacar). false si ya no hace nada mas.
static func _ai_step(st: Dictionary, side: int, smart: float) -> bool:
	var me: Dictionary = st["p"][side]
	var foe: Dictionary = st["p"][foe_of(side)]
	## 1 - Golpe final: si el dano directo alcanza, a la cara.
	if smart > 0.5:
		var reach: int = 0
		var taunt: bool = (foe["board"] as Array).any(func(m: Dictionary) -> bool: return str(m.get("kw", "")) == "taunt")
		if not taunt:
			for m: Variant in me["board"]:
				if bool(m["ready"]):
					reach += int(m["atk"])
		if reach >= int(foe["hp"]):
			for m2: Variant in me["board"]:
				if bool(m2["ready"]):
					return attack(st, int(m2["uid"]), {"hero": true})
	## 2 - Jugar la carta mas cara que quepa (con su mejor objetivo).
	var hand: Array = me["hand"]
	var best_i: int = -1
	var best_t: Dictionary = {}
	var best_v: float = 0.0
	for i: int in hand.size():
		var c: Dictionary = CARDS[str(hand[i])]
		if int(c["cost"]) > int(me["mana"]):
			continue
		var v: float = float(int(c["cost"])) + 0.5
		var tgt: Dictionary = {}
		if str(c["kind"]) == "minion":
			if (me["board"] as Array).size() >= MAX_BOARD:
				continue
		else:
			match str(c["fx"]):
				"dmg":
					var n: int = int(c["n"])
					var kill: Dictionary = {}
					for m3: Variant in foe["board"]:
						if int(m3["hp"]) <= n and not bool(m3.get("shield", false)) and (kill.is_empty() or _minion_value(m3) > _minion_value(kill)):
							kill = m3
					if not kill.is_empty():
						tgt = kill
						v += _minion_value(kill) * 0.5
					elif int(foe["hp"]) <= n or smart < 0.5:
						tgt = {"hero": true}
					else:
						continue
				"heal":
					if int(me["hp"]) > int(me["max_hp"]) - int(c["n"]) + 1:
						continue
					tgt = {"hero": true}
				"buff":
					if (me["board"] as Array).is_empty():
						continue
					tgt = me["board"][0]
				"aoe":
					var hits: int = 0
					for m4: Variant in foe["board"]:
						if int(m4["hp"]) <= int(c["n"]):
							hits += 1
					if hits < 2:
						continue
					v += float(hits)
				"draw":
					if (hand as Array).size() > 4:
						continue
		if v > best_v:
			best_v = v
			best_i = i
			best_t = tgt
	if best_i >= 0:
		return play(st, best_i, best_t)
	## 3 - Atacar: cambios buenos (matar sin morir) o a la cara.
	for m5: Variant in me["board"]:
		if not bool(m5["ready"]) or int(m5["atk"]) <= 0:
			continue
		var targets: Array = attack_targets(st, side)
		var pick: Dictionary = {}
		var pv: float = -1e9
		for t: Variant in targets:
			var s: float = 0.0
			if t.has("hero"):
				s = float(int(m5["atk"])) * (0.6 + 0.6 * smart)
			else:
				var kills: bool = int(m5["atk"]) >= int(t["hp"]) and not bool(t.get("shield", false))
				var dies: bool = int(t["atk"]) >= int(m5["hp"]) and not bool(m5.get("shield", false))
				s = (_minion_value(t) if kills else 0.0) - (_minion_value(m5) if dies else 0.0) * smart + (2.0 if str(t.get("kw", "")) == "taunt" else 0.0)
			if s > pv:
				pv = s
				pick = t
		if not pick.is_empty():
			return attack(st, int(m5["uid"]), pick)
	return false


const BOT_SMART: float = 1.0


static func bot_play(level: Dictionary) -> Dictionary:
	var st: Dictionary = new_state(level)
	var guard: int = 0
	while not bool(st["won"]) and not bool(st["lost"]) and guard < 200:
		guard += 1
		ai_turn(st, BOT_SMART if int(st["side"]) == 1 else float(level.get("ai", 0.6)))
	return {"won": bool(st["won"]), "turns": int(st["turn"]), "hp": int(st["p"][1]["hp"])}


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	for key: String in ["deck", "foe_deck"]:
		var d: Array = level.get(key, [])
		if d.size() < 10 or d.size() > 30:
			issues.append("ccg_deck_size")
		for c: Variant in d:
			if not CARDS.has(str(c)):
				issues.append("ccg_unknown_card")
	var r: Dictionary = {"won": false, "turns": 0}
	if issues.is_empty():
		r = bot_play(level)
		if not bool(r["won"]):
			issues.append("ccg_unbeatable")
		elif int(r["turns"]) < 4:
			issues.append("ccg_too_short")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": 0, "enemies": 0, "enemy_problems": [], "bot_turns": r.get("turns", 0)}
