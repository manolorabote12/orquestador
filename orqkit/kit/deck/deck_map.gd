extends RefCounted
## Mazo (combates de cartas estilo Slay the Spire): cartas, enemigos, simulacion pura, bot y
## analizador. El juego solo dibuja y toca; todo lo que decide esta aqui.
## 1 - Cada turno: 3 de energia y 5 cartas. Ataques quitan vida (el bloqueo enemigo para primero),
##     habilidades bloquean o hacen cosas, poderes duran todo el combate. El bloqueo se pierde
##     al empezar tu turno siguiente.
## 2 - El enemigo ensena su intencion (atacar X, bloquear, fortalecerse, envenenar, debilitar).
## 3 - Estados: fuerza (+dano por golpe), veneno (quita al empezar su turno y baja 1), debil
##     (hace un 25 % menos), espinas (devuelve dano al recibir un golpe este turno).
## 4 - Tras cada combate (menos el ultimo): eliges 1 de 3 cartas nuevas para el mazo y te curas 8.
## Mapa (game.json -> levels[i].map): un enemigo por combate, en orden: "slime", "bandido",
##   "caballero", "bruja", "golem", "dragon" (jefe). Parametros: "power" (vida y dano enemigo),
##   "hp" (tu vida), "seed" (barajas y recompensas) y "par" (turnos para la tercera estrella).
## Analizador: 2-7 combates de enemigos validos y el bot gana con el mismo azar (devuelve turnos).

## Cartas: coste, tipo (attack/skill/power), efectos y si se agota (exhaust) al usarla.
const CARDS: Dictionary = {
	"golpe": {"cost": 1, "type": "attack", "dmg": 6, "hits": 1},
	"defensa": {"cost": 1, "type": "skill", "block": 5},
	"tajo_doble": {"cost": 1, "type": "attack", "dmg": 4, "hits": 2},
	"golpe_pesado": {"cost": 2, "type": "attack", "dmg": 14, "hits": 1},
	"rafaga": {"cost": 2, "type": "attack", "dmg": 3, "hits": 4},
	"muro": {"cost": 2, "type": "skill", "block": 12},
	"espinas": {"cost": 1, "type": "skill", "block": 6, "thorns": 3},
	"veneno": {"cost": 1, "type": "skill", "poison": 5},
	"nube_toxica": {"cost": 2, "type": "skill", "poison": 9, "exhaust": true},
	"debilitar": {"cost": 1, "type": "skill", "weak": 2, "block": 3},
	"concentracion": {"cost": 0, "type": "skill", "draw": 2},
	"curar": {"cost": 1, "type": "skill", "heal": 7, "exhaust": true},
	"energia": {"cost": 0, "type": "skill", "energy": 1, "exhaust": true},
	"furia": {"cost": 1, "type": "power", "strength": 2},
	"armadura": {"cost": 1, "type": "power", "plating": 3},
	"tajo_vampiro": {"cost": 2, "type": "attack", "dmg": 10, "hits": 1, "lifesteal": true},
}
const STARTER: Array[String] = ["golpe", "golpe", "golpe", "golpe", "golpe", "defensa", "defensa", "defensa", "defensa", "tajo_doble"]
const REWARD_POOL: Array[String] = ["tajo_doble", "golpe_pesado", "rafaga", "muro", "espinas", "veneno", "nube_toxica", "debilitar",
	"concentracion", "curar", "energia", "furia", "armadura", "tajo_vampiro"]

## Enemigos: vida y su ciclo de intenciones [tipo, valor, veces].
const ENEMIES: Dictionary = {
	"slime": {"hp": 24, "pattern": [["atk", 6, 1], ["atk", 7, 1], ["block", 5, 0]]},
	"bandido": {"hp": 32, "pattern": [["atk", 8, 1], ["atk", 4, 2], ["str", 2, 0]]},
	"caballero": {"hp": 44, "pattern": [["blockatk", 10, 6], ["atk", 13, 1], ["atk", 5, 2]]},
	"bruja": {"hp": 36, "pattern": [["poison", 3, 0], ["atk", 8, 1], ["weak", 2, 0], ["atk", 10, 1]]},
	"golem": {"hp": 64, "pattern": [["block", 12, 0], ["atk", 17, 1], ["atk", 7, 1]]},
	"dragon": {"hp": 110, "pattern": [["atk", 10, 1], ["blockstr", 12, 2], ["atk", 5, 3], ["poison", 3, 0], ["atk", 14, 1]]},
}
const MAX_TURNS: int = 400


static func rng(seed: int, n: int) -> RandomNumberGenerator:
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.seed = seed * 7919 + n * 104729 + 17
	return r


## Estado de una partida (todos los combates del nivel).
static func new_run(level: Dictionary) -> Dictionary:
	var fights: Array[String] = []
	for f: Variant in level.get("map", []):
		fights.append(str(f).strip_edges())
	var hp: int = int(level.get("hp", 70))
	var run: Dictionary = {"fights": fights, "fight": 0, "deck": STARTER.duplicate(), "hp": hp, "max_hp": hp,
		"power": float(level.get("power", 1.0)), "seed": int(level.get("seed", 1)), "turns": 0, "won": false, "lost": false,
		"reward": [], "rolls": 0}
	start_fight(run)
	return run


static func start_fight(run: Dictionary) -> void:
	var kind: String = run["fights"][run["fight"]]
	var info: Dictionary = ENEMIES[kind]
	var grow: float = 0.0 if kind == "dragon" else 0.06 * float(run["fight"])
	var mhp: int = int(round(float(info["hp"]) * float(run["power"]) * (1.0 + grow)))
	var r: RandomNumberGenerator = rng(int(run["seed"]), int(run["fight"]) * 31 + int(run["rolls"]))
	var draw: Array = (run["deck"] as Array).duplicate()
	_shuffle(draw, r)
	run["f"] = {"enemy": kind, "ehp": mhp, "emax": mhp, "eblock": 0, "estr": 0, "epoison": 0, "eweak": 0, "intent": 0,
		"block": 0, "str": 0, "poison": 0, "weak": 0, "thorns": 0, "plating": 0, "energy": 3, "draw": draw, "hand": [],
		"discard": [], "exhaust": [], "turn": 0, "rng": r.seed}
	_start_turn(run)


static func _shuffle(a: Array, r: RandomNumberGenerator) -> void:
	for i: int in range(a.size() - 1, 0, -1):
		var j: int = r.randi_range(0, i)
		var t: Variant = a[i]
		a[i] = a[j]
		a[j] = t


static func _draw(run: Dictionary, n: int) -> void:
	var f: Dictionary = run["f"]
	for k: int in n:
		if (f["draw"] as Array).is_empty():
			if (f["discard"] as Array).is_empty():
				return
			f["draw"] = (f["discard"] as Array).duplicate()
			f["discard"] = []
			var r: RandomNumberGenerator = RandomNumberGenerator.new()
			r.seed = int(f["rng"]) + int(f["turn"]) * 13
			_shuffle(f["draw"], r)
		if (f["hand"] as Array).size() >= 10:
			return
		(f["hand"] as Array).append((f["draw"] as Array).pop_back())


static func _start_turn(run: Dictionary) -> void:
	var f: Dictionary = run["f"]
	f["turn"] = int(f["turn"]) + 1
	run["turns"] = int(run["turns"]) + 1
	f["block"] = int(f["plating"])
	f["thorns"] = 0
	f["energy"] = 3
	## Tu veneno te hace dano al empezar tu turno.
	if int(f["poison"]) > 0:
		run["hp"] = int(run["hp"]) - int(f["poison"])
		f["poison"] = int(f["poison"]) - 1
		if int(run["hp"]) <= 0:
			run["lost"] = true
			return
	_draw(run, 5)


## Lo que va a hacer el enemigo: [tipo, valor, veces] con su fuerza y debilidad aplicadas.
static func intent(run: Dictionary) -> Array:
	var f: Dictionary = run["f"]
	var pat: Array = ENEMIES[f["enemy"]]["pattern"]
	var it: Array = (pat[int(f["intent"]) % pat.size()] as Array).duplicate()
	var p: float = float(run["power"])
	match str(it[0]):
		"atk":
			it[1] = _enemy_hit(run, int(round(float(it[1]) * p)))
		"blockatk":
			it[2] = _enemy_hit(run, int(round(float(it[2]) * p)))
	return it


static func _enemy_hit(run: Dictionary, base: int) -> int:
	var f: Dictionary = run["f"]
	var d: float = float(base + int(f["estr"]))
	if int(f["eweak"]) > 0:
		d *= 0.75
	return maxi(0, int(floor(d)))


## Dano que hara el enemigo este turno (para la interfaz y el bot).
static func incoming(run: Dictionary) -> int:
	var it: Array = intent(run)
	match str(it[0]):
		"atk":
			return int(it[1]) * int(it[2])
		"blockatk":
			return int(it[2])
	return 0


static func can_play(run: Dictionary, i: int) -> bool:
	var f: Dictionary = run["f"]
	if i < 0 or i >= (f["hand"] as Array).size() or run["won"] or run["lost"]:
		return false
	return int(CARDS[f["hand"][i]]["cost"]) <= int(f["energy"])


static func card_damage(run: Dictionary, card: String) -> int:
	var c: Dictionary = CARDS[card]
	var f: Dictionary = run["f"]
	var d: float = float(int(c.get("dmg", 0)) + int(f["str"]))
	if int(f["weak"]) > 0:
		d *= 0.75
	return maxi(0, int(floor(d)))


static func play(run: Dictionary, i: int) -> bool:
	if not can_play(run, i):
		return false
	var f: Dictionary = run["f"]
	var card: String = (f["hand"] as Array).pop_at(i)
	var c: Dictionary = CARDS[card]
	f["energy"] = int(f["energy"]) - int(c["cost"])
	if c.has("dmg"):
		for k: int in int(c.get("hits", 1)):
			var d: int = card_damage(run, card)
			var through: int = maxi(0, d - int(f["eblock"]))
			f["eblock"] = maxi(0, int(f["eblock"]) - d)
			f["ehp"] = int(f["ehp"]) - through
			if bool(c.get("lifesteal", false)):
				run["hp"] = mini(int(run["max_hp"]), int(run["hp"]) + through)
	f["block"] = int(f["block"]) + int(c.get("block", 0))
	f["thorns"] = int(f["thorns"]) + int(c.get("thorns", 0))
	f["epoison"] = int(f["epoison"]) + int(c.get("poison", 0))
	f["eweak"] = int(f["eweak"]) + int(c.get("weak", 0))
	f["str"] = int(f["str"]) + int(c.get("strength", 0))
	f["plating"] = int(f["plating"]) + int(c.get("plating", 0))
	f["energy"] = int(f["energy"]) + int(c.get("energy", 0))
	run["hp"] = mini(int(run["max_hp"]), int(run["hp"]) + int(c.get("heal", 0)))
	if c.has("draw"):
		_draw(run, int(c["draw"]))
	if bool(c.get("exhaust", false)) or str(c["type"]) == "power":
		(f["exhaust"] as Array).append(card)
	else:
		(f["discard"] as Array).append(card)
	_check_end(run)
	return true


static func _check_end(run: Dictionary) -> void:
	var f: Dictionary = run["f"]
	if int(f["ehp"]) > 0:
		return
	if int(run["fight"]) >= (run["fights"] as Array).size() - 1:
		run["won"] = true
		return
	## Recompensa: 3 cartas para elegir (o saltar).
	var r: RandomNumberGenerator = rng(int(run["seed"]), 900 + int(run["fight"]))
	var pool: Array = REWARD_POOL.duplicate()
	_shuffle(pool, r)
	run["reward"] = pool.slice(0, 3)


## Termina tu turno: el enemigo hace lo suyo y empieza otro turno.
static func end_turn(run: Dictionary) -> void:
	if run["won"] or run["lost"] or not (run["reward"] as Array).is_empty():
		return
	var f: Dictionary = run["f"]
	for card: Variant in f["hand"]:
		(f["discard"] as Array).append(card)
	f["hand"] = []
	## Veneno del enemigo.
	if int(f["epoison"]) > 0:
		f["ehp"] = int(f["ehp"]) - int(f["epoison"])
		f["epoison"] = int(f["epoison"]) - 1
		_check_end(run)
		if run["won"] or not (run["reward"] as Array).is_empty():
			return
	f["eblock"] = 0
	var it: Array = intent(run)
	match str(it[0]):
		"atk":
			for k: int in int(it[2]):
				_hit_player(run, int(it[1]))
		"block":
			f["eblock"] = int(round(float(it[1]) * float(run["power"])))
		"blockatk":
			f["eblock"] = int(round(float(it[1]) * float(run["power"])))
			_hit_player(run, int(it[2]))
		"str":
			f["estr"] = int(f["estr"]) + int(it[1])
		"blockstr":
			f["eblock"] = int(round(float(it[1]) * float(run["power"])))
			f["estr"] = int(f["estr"]) + int(it[2])
		"poison":
			f["poison"] = int(f["poison"]) + int(it[1])
		"weak":
			f["weak"] = int(f["weak"]) + int(it[1])
	f["intent"] = int(f["intent"]) + 1
	f["eweak"] = maxi(0, int(f["eweak"]) - 1)
	f["weak"] = maxi(0, int(f["weak"]) - 1)
	if int(run["hp"]) <= 0:
		run["lost"] = true
		return
	_check_end(run)
	if run["won"] or not (run["reward"] as Array).is_empty():
		return
	_start_turn(run)


static func _hit_player(run: Dictionary, d: int) -> void:
	var f: Dictionary = run["f"]
	var through: int = maxi(0, d - int(f["block"]))
	f["block"] = maxi(0, int(f["block"]) - d)
	run["hp"] = int(run["hp"]) - through
	if int(f["thorns"]) > 0:
		f["ehp"] = int(f["ehp"]) - int(f["thorns"])


## Elegir recompensa (indice) o -1 para saltar; despues empieza el siguiente combate.
static func pick_reward(run: Dictionary, i: int) -> void:
	var rw: Array = run["reward"]
	if rw.is_empty():
		return
	if i >= 0 and i < rw.size():
		(run["deck"] as Array).append(rw[i])
	run["reward"] = []
	run["hp"] = mini(int(run["max_hp"]), int(run["hp"]) + 8)
	run["fight"] = int(run["fight"]) + 1
	start_fight(run)


# ------------------------------------------------------------------ bot

const PICK_ORDER: Array[String] = ["furia", "armadura", "golpe_pesado", "nube_toxica", "tajo_vampiro", "veneno", "muro", "rafaga",
	"debilitar", "espinas", "concentracion", "energia", "curar", "tajo_doble"]


## Elige la siguiente carta a jugar (indice) o -1 para terminar el turno.
static func bot_choice(run: Dictionary) -> int:
	var f: Dictionary = run["f"]
	var hand: Array = f["hand"]
	var need_block: int = incoming(run) - int(f["block"])
	var lethal: bool = false
	var best: int = -1
	var best_v: float = 0.0
	## Dano que se puede hacer con lo que hay: si basta para matar, a por ello.
	var dmg_left: int = 0
	var en: int = int(f["energy"])
	for card: Variant in hand:
		if CARDS[card].has("dmg") and int(CARDS[card]["cost"]) <= en:
			dmg_left += card_damage(run, str(card)) * int(CARDS[card].get("hits", 1))
	lethal = dmg_left >= int(f["ehp"]) + int(f["eblock"])
	for i: int in hand.size():
		if not can_play(run, i):
			continue
		var c: Dictionary = CARDS[hand[i]]
		var cost: float = maxf(float(c["cost"]), 0.5)
		var v: float = 0.0
		if int(c["cost"]) == 0:
			v += 50.0
		if str(c["type"]) == "power":
			v += 40.0 if int(f["turn"]) <= 3 else 8.0
		if c.has("dmg"):
			v += float(card_damage(run, str(hand[i])) * int(c.get("hits", 1))) * (3.0 if lethal else 1.0)
		if c.has("block"):
			v += float(mini(int(c["block"]), maxi(need_block, 0))) * 1.6 + (0.0 if need_block > 0 else 0.5)
		if c.has("poison"):
			v += float(c["poison"]) * (2.0 if int(f["ehp"]) > 20 else 0.6)
		if c.has("weak"):
			v += 6.0 if incoming(run) > 0 else 1.0
		if c.has("heal"):
			v += 9.0 if int(run["hp"]) < int(run["max_hp"]) - 10 else 0.5
		if c.has("thorns"):
			v += 3.0
		v /= cost
		if v > best_v:
			best_v = v
			best = i
	return best


static func bot_pick(run: Dictionary) -> int:
	var rw: Array = run["reward"]
	var best: int = -1
	var bp: int = 99
	for i: int in rw.size():
		var p: int = PICK_ORDER.find(str(rw[i]))
		if p >= 0 and p < bp:
			bp = p
			best = i
	return best


## Partida entera del bot: turnos usados o -1 si pierde.
static func bot_run(level: Dictionary) -> Dictionary:
	var run: Dictionary = new_run(level)
	var guard: int = 0
	while not run["won"] and not run["lost"] and guard < 5000:
		guard += 1
		if not (run["reward"] as Array).is_empty():
			pick_reward(run, bot_pick(run))
			continue
		var c: int = bot_choice(run)
		if c >= 0:
			play(run, c)
		else:
			end_turn(run)
		if int(run["turns"]) > MAX_TURNS:
			break
	return {"won": bool(run["won"]), "turns": int(run["turns"]), "hp": int(run["hp"])}


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var fights: Array = level.get("map", [])
	if fights.size() < 2 or fights.size() > 7:
		issues.append("deck_fights")
	for f: Variant in fights:
		if not ENEMIES.has(str(f).strip_edges()):
			issues.append("deck_enemy")
			break
	var par: int = 0
	if issues.is_empty():
		var r: Dictionary = bot_run(level)
		if not bool(r["won"]):
			issues.append("deck_too_hard")
		par = int(r["turns"])
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": fights.size(), "enemies": fights.size(),
		"enemy_problems": [], "par": par}
