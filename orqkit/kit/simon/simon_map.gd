extends RefCounted
## Simon dice: los botones de colores se encienden en una secuencia y hay que repetirla; cada ronda
## anade uno. Gana quien llega a la ronda objetivo.
## Nivel: "pads" (4 a 6 botones), "goal" (largo final de la secuencia, 3 a 20), "lives" (fallos que
## se perdonan: repites la secuencia), "speed" (segundos por luz) y "seed" (la secuencia).

const Rules = preload("res://kit/rules.gd")


static func new_state(level: Dictionary) -> Dictionary:
	var pads: int = clampi(int(level.get("pads", 4)), 3, 6)
	var goal: int = clampi(int(level.get("goal", 6)), 2, 24)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(level.get("seed", 1))
	var seq: Array = []
	for k: int in goal:
		var p: int = rng.randi_range(0, pads - 1)
		## Nunca tres iguales seguidos (se confunde con un solo toque largo).
		if k >= 2 and p == int(seq[k - 1]) and p == int(seq[k - 2]):
			p = (p + 1 + rng.randi_range(0, pads - 2)) % pads
		seq.append(p)
	var st: Dictionary = {"pads": pads, "goal": goal, "seq": seq, "round": 1, "pos": 0, "lives": clampi(int(level.get("lives", 2)), 0, 5),
		"speed": clampf(float(level.get("speed", 0.6)), 0.25, 1.2), "mistakes": 0, "won": false, "lost": false}
	st["rules"] = Rules.load_rules(level)
	Rules.hook(st, "on_start")
	return st


## Lo que hay que repetir en esta ronda.
static func current(st: Dictionary) -> Array:
	return (st["seq"] as Array).slice(0, int(st["round"]))


## Toca el boton p: "ok", "round" (ronda completa), "won", "miss" (repite la ronda) o "lost".
static func press(st: Dictionary, p: int) -> String:
	if bool(st["won"]) or bool(st["lost"]):
		return ""
	var want: int = int((st["seq"] as Array)[int(st["pos"])])
	if p != want:
		st["mistakes"] = int(st["mistakes"]) + 1
		st["pos"] = 0
		Rules.hook(st, "on_miss", [p])
		if int(st["mistakes"]) > int(st["lives"]):
			st["lost"] = true
			return "lost"
		return "miss"
	st["pos"] = int(st["pos"]) + 1
	if int(st["pos"]) < int(st["round"]):
		return "ok"
	Rules.hook(st, "on_round", [int(st["round"])])
	if int(st["round"]) >= int(st["goal"]):
		st["won"] = true
		return "won"
	st["round"] = int(st["round"]) + 1
	st["pos"] = 0
	return "round"


static func bot_press(st: Dictionary) -> int:
	return int((st["seq"] as Array)[int(st["pos"])])


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var pads: int = int(level.get("pads", 4))
	var goal: int = int(level.get("goal", 6))
	if pads < 3 or pads > 6:
		issues.append("simon_pads")
	if goal < 3 or goal > 20:
		issues.append("simon_goal")
	if float(level.get("speed", 0.6)) < 0.3:
		issues.append("simon_too_fast")
	if issues.is_empty():
		var st: Dictionary = new_state(level)
		var guard: int = 0
		while not bool(st["won"]) and not bool(st["lost"]) and guard < 500:
			guard += 1
			press(st, bot_press(st))
		if not bool(st["won"]):
			issues.append("simon_bot_failed")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": goal, "enemies": 0, "enemy_problems": []}
