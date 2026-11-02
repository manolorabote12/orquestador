extends RefCounted
## Agujero (estilo Hole.io): reglas, simulacion pura, bot y analizador.
## 1 - Mapa (game.json -> levels[i].map): la ciudad vista desde arriba, una casilla = 64 px.
##     "." suelo, y objetos de menor a mayor: "c" cono, "p" persona, "b" banco, "f" farola,
##     "t" arbol, "a" coche, "k" kiosco, "h" casa, "E" edificio. "S" = donde empieza el agujero.
## 2 - El agujero se mueve con el dedo. Se traga lo que cabe (objeto mas pequeno que el agujero)
##     y crece con cada cosa que se come (por area).
## 3 - Se gana al tragar "goal" (de 0 a 1, parte del valor total de la ciudad) antes de "seconds".

const CELL: float = 64.0
const KINDS: Dictionary = {
	"c": {"r": 9.0, "v": 1}, "p": {"r": 11.0, "v": 2}, "b": {"r": 16.0, "v": 3}, "f": {"r": 14.0, "v": 3},
	"t": {"r": 22.0, "v": 5}, "a": {"r": 28.0, "v": 8}, "k": {"r": 36.0, "v": 12}, "h": {"r": 52.0, "v": 25}, "E": {"r": 74.0, "v": 50},
}
const R0: float = 20.0
const SPEED: float = 190.0


static func new_state(level: Dictionary) -> Dictionary:
	var rows: Array = level.get("map", [])
	var objs: Array = []
	var start: Vector2 = Vector2.ZERO
	var w: int = 0
	var total: int = 0
	for y: int in rows.size():
		var row: String = str(rows[y])
		w = maxi(w, row.length())
		for x: int in row.length():
			var ch: String = row[x]
			var c: Vector2 = (Vector2(x, y) + Vector2(0.5, 0.5)) * CELL
			if ch == "S":
				start = c
			elif KINDS.has(ch):
				objs.append({"k": ch, "p": c, "r": float(KINDS[ch]["r"]), "v": int(KINDS[ch]["v"]), "eaten": false})
				total += int(KINDS[ch]["v"])
	if start == Vector2.ZERO:
		start = Vector2(float(w), float(rows.size())) * CELL * 0.5
	return {"objs": objs, "pos": start, "r": R0, "eaten": 0, "total": total, "time": 0.0, "seconds": float(level.get("seconds", 90)),
		"goal": float(level.get("goal", 0.6)), "size": Vector2(float(w), float(rows.size())) * CELL, "won": false, "over": false, "falling": []}


static func fits(st: Dictionary, o: Dictionary) -> bool:
	return float(o["r"]) < float(st["r"]) * 0.92


static func progress(st: Dictionary) -> float:
	return float(st["eaten"]) / maxf(1.0, float(st["total"]))


## Mueve el agujero hacia "dir" (largo 0-1) y se traga lo que tenga dentro.
static func step(st: Dictionary, dir: Vector2, dt: float) -> Array:
	var eaten_now: Array = []
	if st["won"] or st["over"]:
		return eaten_now
	st["time"] = float(st["time"]) + dt
	var r: float = float(st["r"])
	var sp: float = SPEED + r * 0.6
	var p: Vector2 = (st["pos"] as Vector2) + dir.limit_length(1.0) * sp * dt
	var size: Vector2 = st["size"]
	p.x = clampf(p.x, r * 0.5, size.x - r * 0.5)
	p.y = clampf(p.y, r * 0.5, size.y - r * 0.5)
	st["pos"] = p
	for o: Dictionary in st["objs"]:
		if o["eaten"]:
			continue
		if fits(st, o) and p.distance_to(o["p"]) + float(o["r"]) * 0.5 < float(st["r"]):
			o["eaten"] = true
			eaten_now.append(o)
			st["eaten"] = int(st["eaten"]) + int(o["v"])
			## Crece por area: la del objeto se suma (a medias) a la del agujero.
			st["r"] = sqrt(float(st["r"]) * float(st["r"]) + float(o["r"]) * float(o["r"]) * 0.12)
	if progress(st) >= float(st["goal"]):
		st["won"] = true
	elif float(st["time"]) >= float(st["seconds"]):
		st["over"] = true
	return eaten_now


## El bot va a por lo que mas renta: valor del objeto que cabe dividido por lo lejos que esta.
static func bot_dir(st: Dictionary) -> Vector2:
	var p: Vector2 = st["pos"]
	var best: Vector2 = Vector2.ZERO
	var best_s: float = -1.0
	for o: Dictionary in st["objs"]:
		if o["eaten"] or not fits(st, o):
			continue
		var d: float = p.distance_to(o["p"])
		var s: float = float(o["v"]) / (d + 60.0)
		if s > best_s:
			best_s = s
			best = o["p"]
	if best_s < 0.0:
		return Vector2.ZERO
	var v: Vector2 = best - p
	return v / maxf(v.length(), 1.0) if v.length() > 4.0 else Vector2.ZERO


static func bot_play(level: Dictionary) -> Dictionary:
	var st: Dictionary = new_state(level)
	var dt: float = 1.0 / 20.0
	## Una persona tarda un poco en cambiar de rumbo: el bot decide cada 0,3 s.
	var dir: Vector2 = Vector2.ZERO
	var cd: float = 0.0
	while not st["won"] and not st["over"]:
		cd -= dt
		if cd <= 0.0:
			dir = bot_dir(st) * 0.9
			cd = 0.3
		step(st, dir, dt)
	return {"won": bool(st["won"]), "time": float(st["time"]), "progress": progress(st), "r": float(st["r"])}


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var rows: Array = level.get("map", [])
	if rows.size() < 8 or rows.size() > 40:
		issues.append("hole_size")
	var st: Dictionary = new_state(level)
	if (st["objs"] as Array).size() < 10:
		issues.append("hole_empty")
	var small: int = 0
	for o: Dictionary in st["objs"]:
		if fits(st, o):
			small += 1
	if small < 5:
		issues.append("hole_no_start")
	var par: int = 0
	if issues.is_empty():
		var r: Dictionary = bot_play(level)
		if not bool(r["won"]):
			issues.append("hole_too_hard")
		par = int(r["time"])
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": 100, "enemies": 0, "enemy_problems": [], "par": par}
