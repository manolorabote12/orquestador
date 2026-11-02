class_name TurnsLogic
extends RefCounted
## Reglas del RPG por turnos sin dibujo: las usan el juego, el analizador y el bot.
## Heroe: vida, ataque, energia (0-3) y pociones. Acciones:
##   attack (a un enemigo, +1 energia), special (a todos, 70 % del ataque, cuesta 2 de energia),
##   heal (pocion: +40 % de la vida maxima) y defend (+1 energia y la mitad de dano este turno).
## Enemigos: W normal, S pinchos (si le pegas, te pinchas 4), F rapido (pega mas, aguanta menos)
## y B jefe (cada 3 turnos carga un golpe doble y lo avisa el turno antes).
## Tras cada oleada el heroe recupera un 10 %. Variacion de dano +-10 % (0 en el analizador).
## Mapa: una fila por oleada con sus enemigos ("WW", "WSF", "B").

const ENEMIES: Dictionary = {
	"W": {"hp": 40.0, "atk": 8.0, "thorns": 0.0},
	"S": {"hp": 34.0, "atk": 6.0, "thorns": 4.0},
	"F": {"hp": 24.0, "atk": 11.0, "thorns": 0.0},
	"B": {"hp": 120.0, "atk": 9.0, "thorns": 0.0},
}
const ENERGY_MAX: int = 3
const SPECIAL_COST: int = 2


static func new_state(waves: Array, hero_hp: float, hero_atk: float, potions: int, mult: float) -> Dictionary:
	return {"waves": waves, "wave": -1, "hp": hero_hp, "max_hp": hero_hp, "atk": hero_atk, "energy": 0, "potions": potions,
		"mult": mult, "enemies": [], "guard": false, "turn": 0, "won": false, "lost": false}


## Saca la siguiente oleada. Devuelve false si no quedan (ganaste).
static func next_wave(st: Dictionary) -> bool:
	st["wave"] = int(st["wave"]) + 1
	var waves: Array = st["waves"]
	if int(st["wave"]) >= waves.size():
		st["won"] = true
		return false
	if int(st["wave"]) > 0:
		st["hp"] = minf(float(st["max_hp"]), float(st["hp"]) + float(st["max_hp"]) * 0.1)
	var list: Array = []
	var row: String = str(waves[int(st["wave"])])
	for i: int in row.length():
		var k: String = row[i]
		if not ENEMIES.has(k):
			continue
		var e: Dictionary = ENEMIES[k]
		var m: float = float(st["mult"])
		list.append({"kind": k, "hp": float(e["hp"]) * m, "max_hp": float(e["hp"]) * m, "atk": float(e["atk"]) * m,
			"thorns": float(e["thorns"]), "alive": true, "charge": 0})
	st["enemies"] = list
	return true


static func alive(st: Dictionary) -> Array:
	return (st["enemies"] as Array).filter(func(e: Dictionary) -> bool: return bool(e["alive"]))


static func can(st: Dictionary, action: String) -> bool:
	match action:
		"special":
			return int(st["energy"]) >= SPECIAL_COST
		"heal":
			return int(st["potions"]) > 0 and float(st["hp"]) < float(st["max_hp"])
	return true


## Accion del heroe. rng: variacion de dano (o null para el valor medio). Devuelve lo que paso:
## [{"type": "hit"|"heal"|"guard"|"thorns"|"ko", "target": indice, "amount"}].
static func hero_act(st: Dictionary, action: String, target: int, rng: RandomNumberGenerator) -> Array:
	var ev: Array = []
	var enemies: Array = st["enemies"]
	st["guard"] = false
	match action:
		"special":
			st["energy"] = int(st["energy"]) - SPECIAL_COST
			for i: int in enemies.size():
				if bool(enemies[i]["alive"]):
					ev.append_array(_damage(st, i, float(st["atk"]) * 0.7 * _var(rng)))
		"heal":
			st["potions"] = int(st["potions"]) - 1
			var before: float = float(st["hp"])
			st["hp"] = minf(float(st["max_hp"]), before + float(st["max_hp"]) * 0.4)
			ev.append({"type": "heal", "target": -1, "amount": float(st["hp"]) - before})
		"defend":
			st["energy"] = mini(int(st["energy"]) + 1, ENERGY_MAX)
			st["guard"] = true
			ev.append({"type": "guard", "target": -1, "amount": 0.0})
		_:
			if target < 0 or target >= enemies.size() or not bool(enemies[target]["alive"]):
				var al: Array = alive(st)
				if al.is_empty():
					return ev
				target = enemies.find(al[0])
			st["energy"] = mini(int(st["energy"]) + 1, ENERGY_MAX)
			ev.append_array(_damage(st, target, float(st["atk"]) * _var(rng)))
			var th: float = float(enemies[target]["thorns"])
			if th > 0.0:
				st["hp"] = float(st["hp"]) - th
				ev.append({"type": "thorns", "target": -1, "amount": th})
	if float(st["hp"]) <= 0.0:
		st["lost"] = true
	return ev


static func _damage(st: Dictionary, i: int, amount: float) -> Array:
	var e: Dictionary = (st["enemies"] as Array)[i]
	e["hp"] = float(e["hp"]) - amount
	var ev: Array = [{"type": "hit", "target": i, "amount": amount}]
	if float(e["hp"]) <= 0.0:
		e["hp"] = 0.0
		e["alive"] = false
		ev.append({"type": "ko", "target": i, "amount": 0.0})
	return ev


## Turno de los enemigos. Devuelve [{"type": "attack"|"heavy"|"charge", "from", "amount"}].
static func enemies_act(st: Dictionary, rng: RandomNumberGenerator) -> Array:
	var ev: Array = []
	var enemies: Array = st["enemies"]
	st["turn"] = int(st["turn"]) + 1
	for i: int in enemies.size():
		var e: Dictionary = enemies[i]
		if not bool(e["alive"]):
			continue
		var dmg: float = float(e["atk"]) * _var(rng) * float(st.get("enemy_boost", 1.0))
		var kind: String = "attack"
		if str(e["kind"]) == "B":
			e["charge"] = int(e["charge"]) + 1
			if int(e["charge"]) % 3 == 0:
				dmg *= 2.0
				kind = "heavy"
		if bool(st["guard"]):
			dmg *= 0.5
		st["hp"] = float(st["hp"]) - dmg
		ev.append({"type": kind, "from": i, "amount": dmg})
		if str(e["kind"]) == "B" and int(e["charge"]) % 3 == 2:
			ev.append({"type": "charge", "from": i, "amount": 0.0})
	st["guard"] = false
	if float(st["hp"]) <= 0.0:
		st["hp"] = 0.0
		st["lost"] = true
	return ev


## El jefe avisa: su proximo golpe es doble.
static func heavy_coming(st: Dictionary) -> bool:
	for e: Variant in alive(st):
		if str((e as Dictionary)["kind"]) == "B" and int((e as Dictionary)["charge"]) % 3 == 2:
			return true
	return false


## Lo que haria una persona sensata: curarse con poca vida, defenderse del golpe doble del jefe,
## el especial si hay varios y, si no, pegar al que menos vida tiene.
static func policy(st: Dictionary) -> Array:
	var al: Array = alive(st)
	if float(st["hp"]) < float(st["max_hp"]) * 0.35 and can(st, "heal"):
		return ["heal", -1]
	if heavy_coming(st):
		return ["defend", -1]
	if al.size() >= 2 and can(st, "special"):
		return ["special", -1]
	var best: int = -1
	var low: float = 1e9
	for i: int in (st["enemies"] as Array).size():
		var e: Dictionary = (st["enemies"] as Array)[i]
		if bool(e["alive"]) and float(e["hp"]) < low:
			low = float(e["hp"])
			best = i
	return ["attack", best]


## Partida entera con la politica y dano medio: {"won", "hp_left" (proporcion), "turns"}.
## pessimistic: el caso de mala suerte (tu pegas un 10 % menos y ellos un 10 % mas).
static func simulate(waves: Array, hero_hp: float, hero_atk: float, potions: int, mult: float, pessimistic: bool = false) -> Dictionary:
	var st: Dictionary = new_state(waves, hero_hp, hero_atk * (0.9 if pessimistic else 1.0), potions, mult)
	if pessimistic:
		st["enemy_boost"] = 1.1
	next_wave(st)
	var turns: int = 0
	while not bool(st["won"]) and not bool(st["lost"]) and turns < 400:
		var a: Array = policy(st)
		hero_act(st, str(a[0]), int(a[1]), null)
		turns += 1
		if bool(st["lost"]):
			break
		if alive(st).is_empty():
			next_wave(st)
			continue
		enemies_act(st, null)
	return {"won": bool(st["won"]), "hp_left": float(st["hp"]) / float(st["max_hp"]), "turns": turns}


static func _var(rng: RandomNumberGenerator) -> float:
	return 1.0 if rng == null else rng.randf_range(0.9, 1.1)
