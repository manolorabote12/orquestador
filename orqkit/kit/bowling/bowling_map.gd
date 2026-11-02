extends RefCounted
## Bolos: fisica de bola y bolos, bot y analizador.
## 1 - Mapa (game.json -> levels[i].map): una fila por tirada (frame): "10" bolos en triangulo o
##     una letra de reto: "." normal, "o" con aceite (la bola se tuerce mas), "b" con un bolo
##     tapado por una barrera en el centro.
## 2 - Cada tirada son dos bolas: la primera contra los 10 bolos y la segunda contra los que
##     queden. Se lanza deslizando: de donde sale, hacia donde va y cuanto se curva.
## 3 - Se gana sumando "goal" bolos tirados en todas las tiradas.

const LANE_W: float = 420.0
const LANE_L: float = 1500.0
const BALL_R: float = 22.0
const PIN_R: float = 11.0
const DT: float = 1.0 / 120.0


static func frames_of(level: Dictionary) -> Array:
	var out: Array = []
	for r: Variant in level.get("map", []):
		var s: String = str(r).strip_edges()
		if s in [".", "o", "b"]:
			out.append(s)
	return out


static func pins_start() -> Array:
	var out: Array = []
	var gap: float = 52.0
	for row: int in 4:
		for k: int in row + 1:
			out.append({"p": Vector2(LANE_W * 0.5 + (float(k) - float(row) * 0.5) * gap, 260.0 - float(row) * gap * 0.87), "v": Vector2.ZERO,
				"down": false, "out": false})
	return out


static func new_state(level: Dictionary) -> Dictionary:
	return {"frames": frames_of(level), "f": 0, "ball": 0, "pins": pins_start(), "score": 0, "goal": int(level.get("goal", 30)),
		"seed": int(level.get("seed", 1)), "rolls": [], "done": false, "strikes": 0}


static func current(st: Dictionary) -> String:
	return str(st["frames"][int(st["f"])]) if int(st["f"]) < (st["frames"] as Array).size() else "."


## Simula una bola: sale de x0 (abajo del carril) con angulo y efecto (-1..1). Devuelve los bolos
## tirados y la trayectoria (para dibujarla).
static func roll(st: Dictionary, x0: float, angle: float, spin: float, path: Array = []) -> int:
	var pins: Array = st["pins"]
	var oil: float = 1.8 if current(st) == "o" else 1.0
	var p: Vector2 = Vector2(x0, LANE_L - 60.0)
	var v: Vector2 = Vector2(sin(angle), -cos(angle)) * 900.0
	var wall: bool = current(st) == "b"
	var t: float = 0.0
	var before: int = 0
	for pin: Dictionary in pins:
		if pin["down"]:
			before += 1
	while t < 6.0:
		t += DT
		## Efecto: la bola se curva mas hacia el final del carril.
		if p.y < LANE_L * 0.6:
			v = v.rotated(spin * 0.6 * oil * DT)
		p += v * DT
		if path.size() < 400 and p.y > -40.0 and int(t / DT) % 4 == 0:
			path.append(p)
		if p.x < BALL_R * 0.5 or p.x > LANE_W - BALL_R * 0.5:
			## Al canal: sigue recto sin tocar bolos.
			p.x = clampf(p.x, -40.0, LANE_W + 40.0)
			v = Vector2(0, v.y)
		if wall and absf(p.x - LANE_W * 0.5) < 30.0 and p.y < 420.0 and p.y > 400.0:
			v = Vector2(v.x, -v.y) * 0.3
		for pin2: Dictionary in pins:
			if pin2["out"]:
				continue
			var d: Vector2 = (pin2["p"] as Vector2) - p
			if d.length() < BALL_R + PIN_R and p.x > 0.0 and p.x < LANE_W:
				var n: Vector2 = d.normalized()
				pin2["v"] = (pin2["v"] as Vector2) + n * maxf(0.0, v.dot(n)) * 1.1 + v * 0.15
				v -= n * maxf(0.0, v.dot(n)) * 0.2
				pin2["down"] = true
		_pin_step(pins)
		if p.y < -60.0 and _pins_still(pins):
			break
	for k: int in 240:
		_pin_step(pins)
	var after: int = 0
	for pin3: Dictionary in pins:
		if pin3["down"]:
			pin3["out"] = true
			after += 1
	return after - before


static func _pin_step(pins: Array) -> void:
	for a: Dictionary in pins:
		if a["out"]:
			continue
		var v: Vector2 = a["v"]
		if v.length_squared() > 1.0:
			a["p"] = (a["p"] as Vector2) + v * DT
			a["v"] = v * 0.985
			for b: Dictionary in pins:
				if b == a or b["out"] or b["down"] and (b["v"] as Vector2).length_squared() > 1.0:
					continue
				var d: Vector2 = (b["p"] as Vector2) - (a["p"] as Vector2)
				if d.length() < PIN_R * 2.0 and v.length() > 60.0:
					b["v"] = (b["v"] as Vector2) + d.normalized() * v.length() * 0.7
					b["down"] = true
					a["v"] = v * 0.5


static func _pins_still(pins: Array) -> bool:
	for a: Dictionary in pins:
		if not a["out"] and (a["v"] as Vector2).length_squared() > 25.0:
			return false
	return true


## Lanza una bola y pasa de bola / tirada. Devuelve los bolos tirados.
static func throw_ball(st: Dictionary, x0: float, angle: float, spin: float) -> int:
	if bool(st["done"]):
		return 0
	var n: int = roll(st, x0, angle, spin)
	st["score"] = int(st["score"]) + n
	(st["rolls"] as Array).append(n)
	var standing: int = 0
	for pin: Dictionary in st["pins"]:
		if not pin["out"]:
			standing += 1
	if int(st["ball"]) == 0 and standing == 0:
		st["strikes"] = int(st["strikes"]) + 1
	if int(st["ball"]) == 1 or standing == 0:
		st["f"] = int(st["f"]) + 1
		st["ball"] = 0
		st["pins"] = pins_start()
		if int(st["f"]) >= (st["frames"] as Array).size():
			st["done"] = true
	else:
		st["ball"] = 1
	return n


static func won(st: Dictionary) -> bool:
	return int(st["score"]) >= int(st["goal"])


static func copy_state(st: Dictionary) -> Dictionary:
	var c: Dictionary = st.duplicate()
	var pins: Array = []
	for pin: Dictionary in st["pins"]:
		pins.append(pin.duplicate())
	c["pins"] = pins
	return c


## El bot prueba unas cuantas salidas, angulos y efectos y se queda con la que mas tira; luego le
## pone un poco de pulso humano (sale de la semilla).
static func bot_throw(st: Dictionary) -> Array:
	var best: Array = [LANE_W * 0.5, 0.0, 0.0]
	var best_n: int = -1
	for x0: float in [LANE_W * 0.3, LANE_W * 0.5, LANE_W * 0.7]:
		for ang: float in [-0.08, -0.04, 0.0, 0.04, 0.08]:
			for spin: float in [-0.5, 0.0, 0.5]:
				var sim: Dictionary = copy_state(st)
				var n: int = roll(sim, x0, ang, spin)
				if n > best_n:
					best_n = n
					best = [x0, ang, spin]
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.seed = int(st["seed"]) * 7919 + int(st["f"]) * 31 + int(st["ball"])
	return [float(best[0]) + r.randfn(0.0, 6.0), float(best[1]) + r.randfn(0.0, 0.006), float(best[2])]


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var frames: Array = frames_of(level)
	if frames.size() < 2 or frames.size() > 10:
		issues.append("bowling_frames")
	var goal: int = int(level.get("goal", 10))
	if goal < 1 or goal > frames.size() * 10:
		issues.append("bowling_goal")
	var par: int = 0
	if issues.is_empty():
		var st: Dictionary = new_state(level)
		while not bool(st["done"]):
			var t: Array = bot_throw(st)
			throw_ball(st, t[0], t[1], t[2])
		if not won(st):
			issues.append("bowling_too_hard")
		par = int(st["score"])
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": goal, "enemies": 0, "enemy_problems": [], "par": par}
