extends RefCounted
## Penaltis (estilo Football Strike / Penalty Kick): reglas, portero, bot y analizador.
## 1 - Mapa (game.json -> levels[i].map): una letra por tiro, en una o varias filas:
##     "." tiro normal, "W" barrera (para los tiros bajos al centro), "T" diana dorada (marcar
##     dentro de ella vale doble).
## 2 - Porteria en coordenadas: x de -1 (poste izquierdo) a 1 (derecho), y de 0 (suelo) a 1
##     (larguero). Fuera de eso, el tiro se va fuera.
## 3 - El portero decide antes de cada tiro: quieto o estirarse a un lado. Se le nota hacia donde
##     se inclina, pero a veces engana ("bluff" = probabilidad de enganar).
## 4 - Se gana con "goal" goles (las dianas cuentan dos) en los tiros del nivel.

const DIVE_X: float = 0.62
const DIVE_Y: float = 0.35
const REACH_DIVE: float = 0.5
const STAND_REACH: float = 0.42
const STAND_Y: float = 0.45


static func shots_of(level: Dictionary) -> Array:
	var out: Array = []
	for r: Variant in level.get("map", []):
		var s: String = str(r)
		for i: int in s.length():
			if s[i] in [".", "W", "T"]:
				out.append(s[i])
	return out


static func new_state(level: Dictionary) -> Dictionary:
	var st: Dictionary = {"shots": shots_of(level), "i": 0, "goals": 0, "points": 0, "need": int(level.get("goal", 3)),
		"bluff": float(level.get("bluff", 0.2)), "seed": int(level.get("seed", 1)), "results": [], "done": false}
	_plan(st)
	return st


## 1 - Que hara el portero en el tiro actual (-1 izquierda, 0 quieto, 1 derecha), hacia donde se
##     inclina (lo que se ve) y donde esta la diana si la hay.
static func _plan(st: Dictionary) -> void:
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.seed = int(st["seed"]) * 7919 + int(st["i"]) * 104729
	var dive: int = [-1, 1, -1, 1, 0][r.randi_range(0, 4)]
	var lean: int = dive
	if r.randf() < float(st["bluff"]):
		lean = -dive if dive != 0 else [-1, 1][r.randi_range(0, 1)]
	st["dive"] = dive
	st["lean"] = lean
	st["target"] = Vector2(r.randf_range(-0.7, 0.7), r.randf_range(0.25, 0.8))


static func current(st: Dictionary) -> String:
	return str(st["shots"][int(st["i"])]) if int(st["i"]) < (st["shots"] as Array).size() else ""


## Resultado de chutar a "aim": "goal", "double", "saved", "wall" o "out".
static func judge(st: Dictionary, aim: Vector2) -> String:
	if absf(aim.x) > 0.97 or aim.y > 0.97 or aim.y < -0.05:
		return "out"
	var kind: String = current(st)
	if kind == "W" and aim.y < 0.45 and absf(aim.x) < 0.5:
		return "wall"
	var dive: int = int(st["dive"])
	var saved: bool
	if dive == 0:
		saved = aim.distance_to(Vector2(0, STAND_Y)) < STAND_REACH
	else:
		saved = aim.distance_to(Vector2(DIVE_X * float(dive), DIVE_Y)) < REACH_DIVE or aim.distance_to(Vector2(0, STAND_Y)) < 0.22
	if saved:
		return "saved"
	if kind == "T" and aim.distance_to(st["target"]) < 0.18:
		return "double"
	return "goal"


static func shoot(st: Dictionary, aim: Vector2) -> String:
	if bool(st["done"]):
		return ""
	var res: String = judge(st, aim)
	if res == "goal":
		st["goals"] = int(st["goals"]) + 1
		st["points"] = int(st["points"]) + 1
	elif res == "double":
		st["goals"] = int(st["goals"]) + 1
		st["points"] = int(st["points"]) + 2
	(st["results"] as Array).append(res)
	st["i"] = int(st["i"]) + 1
	if int(st["i"]) >= (st["shots"] as Array).size() or won(st) or _cant_win(st):
		st["done"] = true
	else:
		_plan(st)
	return res


static func won(st: Dictionary) -> bool:
	return int(st["points"]) >= int(st["need"])


static func _cant_win(st: Dictionary) -> bool:
	var left: int = (st["shots"] as Array).size() - int(st["i"])
	return int(st["points"]) + left * 2 < int(st["need"])


static func lost(st: Dictionary) -> bool:
	return bool(st["done"]) and not won(st)


## El bot chuta lejos de donde se inclina el portero, arriba; con diana, a la diana si esta
## lejos del portero.
static func bot_aim(st: Dictionary) -> Vector2:
	var lean: int = int(st["lean"])
	var side: float = -float(lean) if lean != 0 else 1.0
	var aim: Vector2 = Vector2(0.82 * side, 0.82)
	if current(st) == "T":
		var t: Vector2 = st["target"]
		var keeper: Vector2 = Vector2(DIVE_X * float(lean), DIVE_Y) if lean != 0 else Vector2(0, STAND_Y)
		if t.distance_to(keeper) > REACH_DIVE + 0.1:
			aim = t
	return aim


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var shots: Array = shots_of(level)
	if shots.size() < 3 or shots.size() > 15:
		issues.append("penalty_shots")
	var need: int = int(level.get("goal", 3))
	if need < 1 or need > shots.size() * 2:
		issues.append("penalty_goal")
	var par: int = 0
	if issues.is_empty():
		var st: Dictionary = new_state(level)
		while not bool(st["done"]):
			shoot(st, bot_aim(st))
		if not won(st):
			issues.append("penalty_too_hard")
		par = int(st["i"])
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": need, "enemies": 0, "enemy_problems": [], "par": par}
