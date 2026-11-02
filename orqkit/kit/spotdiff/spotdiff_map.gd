extends RefCounted
## Encuentra las diferencias: dos dibujos casi iguales, uno encima de otro; toca donde cambian.
## El dibujo es una escena de figuras por datos (asi no hace falta IA de imagen y cada nivel es
## distinto): level["scene"] = [{"k": figura, "x", "y" (0-1), "s" (tamano 0-1), "c": "#rrggbb", "f": giro}],
## level["diffs"] = [{"i": indice de la figura, "how": "color"|"gone"|"size"|"move"|"flip", "v": valor}].
## Fallos: tocar donde no hay diferencia cuenta; con "mistakes" fallos se pierde. Pista: marca una.

const Rules = preload("res://kit/rules.gd")
const KINDS: Array[String] = ["circle", "square", "tri", "star", "flower", "tree", "house", "cloud", "sun", "fish", "car", "balloon",
	"heart", "moon", "mushroom", "bush", "rock", "bird", "boat", "cake", "cup", "lamp", "gift", "kite"]
## Radio (en unidades del dibujo, 0-1) dentro del que un toque acierta una diferencia.
const HIT_R: float = 0.075


## La figura i en el dibujo de abajo (con su diferencia, si la tiene). {} si desaparece.
static func shape_after(level: Dictionary, i: int) -> Dictionary:
	var sh: Dictionary = ((level.get("scene", []) as Array)[i] as Dictionary).duplicate()
	for d: Variant in level.get("diffs", []):
		if int(d.get("i", -1)) != i:
			continue
		match str(d.get("how", "")):
			"color":
				sh["c"] = str(d.get("v", "#ff00ff"))
			"gone":
				return {}
			"size":
				sh["s"] = float(sh.get("s", 0.1)) * float(d.get("v", 1.5))
			"move":
				var v: Array = d.get("v", [0.0, 0.0])
				sh["x"] = float(sh.get("x", 0.5)) + float(v[0])
				sh["y"] = float(sh.get("y", 0.5)) + float(v[1])
			"flip":
				sh["f"] = not bool(sh.get("f", false))
	return sh


## Donde esta cada diferencia (centro en el dibujo, 0-1): la figura original (o su sitio nuevo si se mueve).
static func diff_spots(level: Dictionary) -> Array:
	var out: Array = []
	for d: Variant in level.get("diffs", []):
		var sh: Dictionary = (level.get("scene", []) as Array)[int(d.get("i", 0))]
		var p: Vector2 = Vector2(float(sh.get("x", 0.5)), float(sh.get("y", 0.5)))
		if str(d.get("how", "")) == "move":
			var v: Array = d.get("v", [0.0, 0.0])
			p += Vector2(float(v[0]), float(v[1])) * 0.5
		out.append(p)
	return out


static func new_state(level: Dictionary) -> Dictionary:
	var st: Dictionary = {"found": [], "mistakes": 0, "max_mistakes": clampi(int(level.get("mistakes", 5)), 1, 20), "hints": 2,
		"spots": diff_spots(level), "won": false, "lost": false, "rng": RandomNumberGenerator.new()}
	st["rules"] = Rules.load_rules(level)
	Rules.hook(st, "on_start")
	return st


## Tocar en el punto p (0-1 del dibujo). Devuelve el indice de la diferencia encontrada, -1 si fallo
## y -2 si ya estaba encontrada (no cuenta como fallo).
static func tap(st: Dictionary, p: Vector2) -> int:
	if bool(st["won"]) or bool(st["lost"]):
		return -2
	var best: int = -1
	var bd: float = HIT_R
	for i: int in (st["spots"] as Array).size():
		var dd: float = (st["spots"][i] as Vector2).distance_to(p)
		if dd <= bd:
			bd = dd
			best = i
	if best >= 0 and (st["found"] as Array).has(best):
		return -2
	if best < 0:
		st["mistakes"] = int(st["mistakes"]) + 1
		if int(st["mistakes"]) >= int(st["max_mistakes"]):
			st["lost"] = true
	else:
		(st["found"] as Array).append(best)
		if (st["found"] as Array).size() >= (st["spots"] as Array).size():
			st["won"] = true
	Rules.hook(st, "on_tap", [p, best])
	return best


static func hint(st: Dictionary) -> int:
	if int(st["hints"]) <= 0:
		return -1
	for i: int in (st["spots"] as Array).size():
		if not (st["found"] as Array).has(i):
			st["hints"] = int(st["hints"]) - 1
			return i
	return -1


static func bot_tap(st: Dictionary) -> Vector2:
	for i: int in (st["spots"] as Array).size():
		if not (st["found"] as Array).has(i):
			return st["spots"][i]
	return Vector2(-1, -1)


## Analizador: de 3 a 9 diferencias, separadas entre si, dentro del dibujo y que se vean (no una
## figura diminuta ni un color casi igual).
static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var scene: Array = level.get("scene", [])
	var diffs: Array = level.get("diffs", [])
	if scene.size() < 6:
		issues.append("diff_scene_small")
	if diffs.size() < 3 or diffs.size() > 9:
		issues.append("diff_count")
	var spots: Array = diff_spots(level)
	var used: Dictionary = {}
	for k: int in diffs.size():
		var d: Dictionary = diffs[k]
		var i: int = int(d.get("i", -1))
		if i < 0 or i >= scene.size() or used.has(i):
			issues.append("diff_bad_index")
			continue
		used[i] = true
		var sh: Dictionary = scene[i]
		if float(sh.get("s", 0.0)) < 0.05:
			issues.append("diff_too_small")
		if str(d.get("how", "")) == "color" and Color(str(sh.get("c", "#000000"))).to_rgba32() == Color(str(d.get("v", "#000000"))).to_rgba32():
			issues.append("diff_same_color")
		var p: Vector2 = spots[k]
		if p.x < 0.05 or p.x > 0.95 or p.y < 0.05 or p.y > 0.95:
			issues.append("diff_outside")
		for k2: int in range(k + 1, spots.size()):
			if p.distance_to(spots[k2]) < HIT_R * 2.0:
				issues.append("diff_too_close")
	var ok: bool = issues.is_empty()
	return {"completable": ok, "issues": issues, "coins_total": diffs.size(), "enemies": 0, "enemy_problems": []}
