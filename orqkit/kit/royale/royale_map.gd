extends RefCounted
## Battle royale (vista desde arriba): isla, salto desde el avion, botin, armas por rareza, zona
## que se cierra y rivales con cabeza propia. Reglas, simulacion pura, bots y analizador (lo usan
## el juego, el bot y el analizador: todo lo que decide esta aqui).
## 1 - Mapa (game.json -> levels[i].map): la isla en filas de igual ancho (32-64): "." hierba,
##     "," arena, "~" agua (no se cruza), "#" muro, "_" suelo de casa (mas botin), "t" arbol y
##     "r" roca (los tres ultimos tapan balas y paso).
## 2 - Parametros: "bots" (rivales, 5-39), "skill" (0-1, punteria y reflejos de los rivales),
##     "top" (gana quien quede entre los "top" ultimos vivos; 1 = el ultimo en pie) y "seed".
## 3 - El botin y las salidas salen de la semilla. La zona se cierra en fases y quita vida fuera.
## 4 - En directo (setup_online): todos simulan la misma isla con la misma semilla. Cada movil
##     manda en su jugador (y el anfitrion en los bots): los demas son "remote" y se mueven con lo
##     que llega por la red (net_*). El dano lo decide quien es dueno de la victima, la zona usa
##     su propio azar (igual en todos) y el botin tiene ids para quitarlo a la vez en todos.

const Rules = preload("res://kit/rules.gd")
const TILE: float = 64.0
const R: float = 18.0
const SPEED: float = 270.0
const MAX_HP: float = 100.0
const PLANE_T: float = 9.0
const SOLID_MOVE: String = "~#tr"
const SOLID_SHOT: String = "#tr"
## Armas: dano, cadencia (s), alcance (px), dispersion (rad), perdigones, rareza.
const WEAPONS: Dictionary = {
	"punos": {"dmg": 12.0, "rate": 0.5, "range": 70.0, "spread": 0.0, "pellets": 1, "tier": 0},
	"pistola": {"dmg": 14.0, "rate": 0.36, "range": 560.0, "spread": 0.05, "pellets": 1, "tier": 1},
	"metralleta": {"dmg": 9.0, "rate": 0.11, "range": 500.0, "spread": 0.11, "pellets": 1, "tier": 2},
	"escopeta": {"dmg": 11.0, "rate": 0.8, "range": 330.0, "spread": 0.3, "pellets": 6, "tier": 2},
	"fusil": {"dmg": 13.0, "rate": 0.17, "range": 760.0, "spread": 0.045, "pellets": 1, "tier": 3},
	"francotirador": {"dmg": 75.0, "rate": 1.3, "range": 1150.0, "spread": 0.008, "pellets": 1, "tier": 4},
}
const ARMORS: Dictionary = {"chaleco1": 25.0, "chaleco2": 50.0, "chaleco3": 75.0}
const HEALS: Dictionary = {"venda": [15.0, 2.0], "botiquin": [100.0, 5.0]}
## Fases de la zona: espera, cierre (s), radio final (fraccion del anterior) y dano por segundo.
const PHASES: Array = [[22.0, 18.0, 0.62, 2.0], [18.0, 16.0, 0.56, 4.0], [15.0, 14.0, 0.5, 7.0], [12.0, 12.0, 0.42, 11.0],
	[10.0, 10.0, 0.0, 16.0]]
const NAMES: Array[String] = ["Lobo", "Rayo", "Nube", "Tigre", "Pixel", "Sombra", "Chispa", "Trueno", "Coco", "Halcon", "Nieve",
	"Bruma", "Luna", "Roca", "Kiwi", "Turbo", "Zafiro", "Mango", "Eco", "Ninja", "Faro", "Duna", "Ascua", "Brisa", "Cobra",
	"Delta", "Lince", "Orca", "Piston", "Quark", "Rubi", "Salsa", "Tango", "Vasco", "Yeti", "Zorro", "Atlas", "Bongo", "Ciclon", "Dardo"]


static func rows(level: Dictionary) -> Array:
	var out: Array = []
	for r: Variant in level.get("map", []):
		out.append(str(r))
	return out


static func new_state(level: Dictionary) -> Dictionary:
	var m: Array = rows(level)
	var h: int = m.size()
	var w: int = str(m[0]).length() if h > 0 else 0
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(level.get("seed", 1))
	var land: Array[Vector2i] = []
	var loot: Array = []
	for y: int in h:
		for x: int in w:
			var c: String = str(m[y])[x]
			if not SOLID_MOVE.contains(c):
				land.append(Vector2i(x, y))
				## Botin: mucho en las casas y algo suelto por el campo.
				var p: float = 0.3 if c == "_" else 0.03
				if rng.randf() < p:
					loot.append({"p": (Vector2(x, y) + Vector2(rng.randf_range(0.25, 0.75), rng.randf_range(0.25, 0.75))) * TILE,
						"item": _roll_item(rng, c == "_"), "id": "i%d" % loot.size()})
	var size: Vector2 = Vector2(w, h) * TILE
	var st: Dictionary = {"map": m, "w": w, "h": h, "rng": rng, "time": 0.0, "agents": [], "bullets": [], "loot": loot,
		"zone_c": size * 0.5, "zone_r": size.length() * 0.55, "from_c": size * 0.5, "from_r": size.length() * 0.55,
		"to_c": size * 0.5, "to_r": size.length() * 0.55, "phase": -1, "phase_t": 0.0, "zone_dmg": 1.0,
		"top": maxi(1, int(level.get("top", 1))), "over": false, "won": false, "place": 0, "feed": [], "events": [],
		"plane_a": Vector2.ZERO, "plane_b": Vector2.ZERO, "land": land, "seed": int(level.get("seed", 1))}
	## Avion: cruza la isla en linea recta.
	var ang: float = rng.randf() * TAU
	var half: float = size.length() * 0.45
	st["plane_a"] = size * 0.5 - Vector2(cos(ang), sin(ang)) * half
	st["plane_b"] = size * 0.5 + Vector2(cos(ang), sin(ang)) * half
	var n: int = clampi(int(level.get("bots", 15)), 1, 39)
	var skill: float = clampf(float(level.get("skill", 0.4)), 0.0, 1.0)
	for i: int in n + 1:
		var a: Dictionary = {"id": i, "name": "" if i == 0 else NAMES[(i * 7 + int(level.get("seed", 1))) % NAMES.size()],
			"p": Vector2.ZERO, "v": Vector2.ZERO, "hp": MAX_HP, "armor": 0.0, "weapon": "punos", "cd": 0.0, "heals": {},
			"alive": true, "landed": false, "drop_t": rng.randf_range(1.0, PLANE_T) if i > 0 else PLANE_T, "kills": 0,
			"bot": i > 0, "skill": clampf(skill + rng.randf_range(-0.15, 0.15), 0.0, 1.0), "think": rng.randf() * 0.25,
			"target": -1, "seen_t": 0.0, "path": [], "goal": Vector2.ZERO, "aim": Vector2.RIGHT, "heal_t": 0.0, "heal_item": "",
			"strafe": 1.0, "strafe_t": 0.0, "place": 0, "fire": false, "move": Vector2.ZERO, "hit_t": 0.0,
			"nid": i, "remote": false, "net_p": Vector2.ZERO, "seen": 0.0}
		(st["agents"] as Array).append(a)
	st["rules"] = Rules.load_rules(level)
	Rules.hook(st, "on_start")
	return st


static func _roll_item(rng: RandomNumberGenerator, house: bool) -> String:
	var r: float = rng.randf() + (0.12 if house else 0.0)
	if r < 0.22:
		return "venda"
	if r < 0.3:
		return "botiquin"
	if r < 0.42:
		return "chaleco1"
	if r < 0.5:
		return "chaleco2"
	if r < 0.54:
		return "chaleco3"
	if r < 0.72:
		return "pistola"
	if r < 0.82:
		return "metralleta"
	if r < 0.9:
		return "escopeta"
	if r < 1.04:
		return "fusil"
	return "francotirador"


static func cell(st: Dictionary, x: int, y: int) -> String:
	if x < 0 or y < 0 or x >= int(st["w"]) or y >= int(st["h"]):
		return "~"
	return str(st["map"][y])[x]


static func blocks_move(st: Dictionary, p: Vector2) -> bool:
	return SOLID_MOVE.contains(cell(st, floori(p.x / TILE), floori(p.y / TILE)))


static func blocks_shot(st: Dictionary, p: Vector2) -> bool:
	return SOLID_SHOT.contains(cell(st, floori(p.x / TILE), floori(p.y / TILE)))


## Linea de vista entre dos puntos (muros, arboles y rocas tapan).
static func sight(st: Dictionary, a: Vector2, b: Vector2) -> bool:
	var d: float = a.distance_to(b)
	var n: int = maxi(1, int(d / (TILE * 0.35)))
	for k: int in range(1, n):
		if blocks_shot(st, a.lerp(b, float(k) / float(n))):
			return false
	return true


static func alive_count(st: Dictionary) -> int:
	var n: int = 0
	for a: Dictionary in st["agents"]:
		if bool(a["alive"]):
			n += 1
	return n


static func plane_pos(st: Dictionary) -> Vector2:
	return (st["plane_a"] as Vector2).lerp(st["plane_b"], clampf(float(st["time"]) / PLANE_T, 0.0, 1.0))


## Saltar del avion: cae en la tierra mas cercana al punto del avion.
static func drop(st: Dictionary, a: Dictionary) -> void:
	if bool(a["landed"]):
		return
	var rng: RandomNumberGenerator = st["rng"]
	var p: Vector2 = plane_pos(st) + Vector2(rng.randf_range(-1.5, 1.5), rng.randf_range(-1.5, 1.5)) * TILE
	## Con paracaidas se planea: los rivales eligen su sitio (casi siempre un pueblo) y van hasta alli.
	if a.has("land_at"):
		p = a["land_at"]
	elif bool(a["bot"]) or bool(a.get("glide", false)):
		var land: Array = st["land"]
		var best_v: float = -INF
		for k: int in (16 if bool(a.get("glide", false)) else 4):
			var c: Vector2i = land[rng.randi_range(0, land.size() - 1)]
			var q: Vector2 = (Vector2(c) + Vector2(0.5, 0.5)) * TILE
			## Lejos de los que ya han caido y, si se puede, en una casa.
			var near: float = INF
			for o: Dictionary in st["agents"]:
				if bool(o["landed"]) and bool(o["alive"]):
					near = minf(near, (o["p"] as Vector2).distance_to(q))
			var v: float = minf(near, TILE * 12.0) + (TILE * 3.0 if cell(st, c.x, c.y) == "_" else 0.0)
			if v > best_v:
				best_v = v
				p = q
	var best: Vector2i = Vector2i(-1, -1)
	var bd: float = INF
	var fx: int = floori(p.x / TILE)
	var fy: int = floori(p.y / TILE)
	for c: Vector2i in st["land"]:
		var d: float = float(absi(c.x - fx) + absi(c.y - fy))
		if d < bd:
			bd = d
			best = c
	a["p"] = (Vector2(best) + Vector2(0.5, 0.5)) * TILE
	a["landed"] = true
	_event(st, "land", a)


static func _event(st: Dictionary, kind: String, a: Dictionary, extra: Dictionary = {}) -> void:
	var e: Dictionary = {"kind": kind, "id": int(a["id"]), "p": a["p"]}
	e.merge(extra)
	(st["events"] as Array).append(e)


# ------------------------------------------------------------------ paso

static func step(st: Dictionary, dt: float) -> void:
	if bool(st["over"]):
		return
	st["time"] = float(st["time"]) + dt
	Rules.hook(st, "on_step", [dt])
	_zone_step(st, dt)
	var agents: Array = st["agents"]
	for a: Dictionary in agents:
		if not bool(a["alive"]):
			continue
		if bool(a["remote"]):
			_follow_net(a, dt)
			continue
		if not bool(a["landed"]):
			if float(st["time"]) >= float(a["drop_t"]):
				drop(st, a)
			continue
		if bool(a["bot"]):
			a["think"] = float(a["think"]) - dt
			if float(a["think"]) <= 0.0:
				a["think"] = 0.25
				think(st, a)
		_act(st, a, dt)
	_bullets_step(st, dt)
	## Fuera de la zona se pierde vida.
	for a2: Dictionary in agents:
		if bool(a2["alive"]) and bool(a2["landed"]) and not bool(a2["remote"]) and (a2["p"] as Vector2).distance_to(st["zone_c"]) > float(st["zone_r"]):
			_hurt(st, a2, float(st["zone_dmg"]) * dt, -1)
	_check_end(st)


static func _zone_step(st: Dictionary, dt: float) -> void:
	if float(st["time"]) < PLANE_T:
		return
	st["phase_t"] = float(st["phase_t"]) + dt
	var ph: int = int(st["phase"])
	if ph < 0 or (ph < PHASES.size() and float(st["phase_t"]) >= float(PHASES[ph][0]) + float(PHASES[ph][1])):
		ph += 1
		if ph >= PHASES.size():
			return
		st["phase"] = ph
		st["phase_t"] = 0.0
		st["from_c"] = st["zone_c"]
		st["from_r"] = st["zone_r"]
		var nr: float = float(st["zone_r"]) * float(PHASES[ph][2])
		if ph == 0:
			nr = minf(float(int(st["w"]) * TILE), float(int(st["h"]) * TILE)) * 0.42
		## El nuevo centro cae dentro del circulo de ahora, en tierra (en directo, con un azar propio).
		var rng: RandomNumberGenerator = st.get("zrng", st["rng"])
		var c: Vector2 = st["zone_c"]
		for k: int in 20:
			var cand: Vector2 = (st["zone_c"] as Vector2) + Vector2.from_angle(rng.randf() * TAU) * rng.randf() * maxf(0.0, float(st["zone_r"]) - nr) * 0.8
			if not blocks_move(st, cand):
				c = cand
				break
		st["to_c"] = c
		st["to_r"] = nr
		st["zone_dmg"] = float(PHASES[ph][3])
	var p: Array = PHASES[mini(ph, PHASES.size() - 1)]
	var f: float = clampf((float(st["phase_t"]) - float(p[0])) / float(p[1]), 0.0, 1.0)
	st["zone_c"] = (st["from_c"] as Vector2).lerp(st["to_c"], f)
	st["zone_r"] = lerpf(float(st["from_r"]), float(st["to_r"]), f)


## Lo que hace un jugador en este paso: a["move"] (direccion), a["fire"] y a["aim"].
static func _act(st: Dictionary, a: Dictionary, dt: float) -> void:
	a["cd"] = maxf(0.0, float(a["cd"]) - dt)
	a["hit_t"] = maxf(0.0, float(a["hit_t"]) - dt)
	## Curarse: quieto un rato.
	if float(a["heal_t"]) > 0.0:
		a["heal_t"] = float(a["heal_t"]) - dt
		if float(a["heal_t"]) <= 0.0:
			var h: Array = HEALS[str(a["heal_item"])]
			a["hp"] = minf(MAX_HP, float(a["hp"]) + float(h[0]))
			_event(st, "healed", a)
		return
	var mv: Vector2 = a["move"]
	if mv.length() > 1.0:
		mv = mv.normalized()
	## Atascado contra una esquina: un empujon de lado y camino nuevo.
	if float(a.get("nudge_t", 0.0)) > 0.0:
		a["nudge_t"] = float(a["nudge_t"]) - dt
		mv = a["nudge"]
	elif mv.length() > 0.3:
		a["stuck_t"] = float(a.get("stuck_t", 0.0)) + dt
		if float(a["stuck_t"]) > 0.6:
			a["stuck_t"] = 0.0
			if (a["p"] as Vector2).distance_to(a.get("stuck_p", Vector2.INF)) < 12.0:
				var rng: RandomNumberGenerator = st["rng"]
				a["nudge"] = mv.rotated(PI * 0.5 * (1.0 if rng.randf() < 0.5 else -1.0))
				a["nudge_t"] = 0.4
				a["path"] = []
			a["stuck_p"] = a["p"]
	var speed: float = SPEED * (0.75 if bool(a["fire"]) else 1.0)
	var before: Vector2 = a["p"]
	_move(st, a, mv * speed * dt)
	a["v"] = ((a["p"] as Vector2) - before) / maxf(dt, 0.0001)
	if bool(a["fire"]) and float(a["cd"]) <= 0.0:
		shoot(st, a)
	## Botin: se coge solo lo que mejora.
	var loot: Array = st["loot"]
	var k: int = loot.size() - 1
	while k >= 0:
		var it: Dictionary = loot[k]
		if (it["p"] as Vector2).distance_to(a["p"]) < R + 22.0 and wants(a, str(it["item"])):
			var old: String = take(a, str(it["item"]))
			loot.remove_at(k)
			if old != "":
				loot.append({"p": (a["p"] as Vector2) + Vector2(0, 30), "item": old, "id": str(it.get("id", "")) + "o"})
			_event(st, "pick", a, {"item": str(it["item"]), "lid": str(it.get("id", ""))})
			Rules.hook(st, "on_pick", [a, str(it["item"])])
		k -= 1


static func _move(st: Dictionary, a: Dictionary, d: Vector2) -> void:
	var p: Vector2 = a["p"]
	for axis: int in 2:
		var np: Vector2 = p + (Vector2(d.x, 0) if axis == 0 else Vector2(0, d.y))
		var ok: bool = true
		for off: Vector2 in [Vector2(R, 0), Vector2(-R, 0), Vector2(0, R), Vector2(0, -R), Vector2(R, R) * 0.7, Vector2(-R, R) * 0.7, Vector2(R, -R) * 0.7, Vector2(-R, -R) * 0.7]:
			if blocks_move(st, np + off):
				ok = false
				break
		if ok:
			p = np
	a["p"] = p


## Si un objeto mejora lo que lleva.
static func wants(a: Dictionary, item: String) -> bool:
	if WEAPONS.has(item):
		return int(WEAPONS[item]["tier"]) > int(WEAPONS[str(a["weapon"])]["tier"])
	if ARMORS.has(item):
		return float(ARMORS[item]) > float(a["armor"])
	if HEALS.has(item):
		return int((a["heals"] as Dictionary).get(item, 0)) < (5 if item == "venda" else 2)
	return false


## Coge un objeto; devuelve el arma que suelta (o "").
static func take(a: Dictionary, item: String) -> String:
	if WEAPONS.has(item):
		var old: String = str(a["weapon"])
		a["weapon"] = item
		return old if old != "punos" else ""
	if ARMORS.has(item):
		a["armor"] = float(ARMORS[item])
		return ""
	var h: Dictionary = a["heals"]
	h[item] = int(h.get(item, 0)) + 1
	return ""


static func start_heal(st: Dictionary, a: Dictionary) -> bool:
	if float(a["heal_t"]) > 0.0 or float(a["hp"]) >= MAX_HP:
		return false
	var h: Dictionary = a["heals"]
	var item: String = "botiquin" if int(h.get("botiquin", 0)) > 0 and float(a["hp"]) < 45.0 else ("venda" if int(h.get("venda", 0)) > 0 else ("botiquin" if int(h.get("botiquin", 0)) > 0 else ""))
	if item == "":
		return false
	h[item] = int(h[item]) - 1
	a["heal_item"] = item
	a["heal_t"] = float(HEALS[item][1])
	return true


static func shoot(st: Dictionary, a: Dictionary) -> void:
	var w: Dictionary = WEAPONS[str(a["weapon"])]
	a["cd"] = float(w["rate"])
	var rng: RandomNumberGenerator = st["rng"]
	var aim: Vector2 = (a["aim"] as Vector2).normalized()
	if aim == Vector2.ZERO:
		aim = Vector2.RIGHT
	if str(a["weapon"]) == "punos":
		## Punetazo: al que este justo delante.
		for b: Dictionary in st["agents"]:
			if b != a and bool(b["alive"]) and bool(b["landed"]) and (b["p"] as Vector2).distance_to((a["p"] as Vector2) + aim * 34.0) < R + 26.0:
				if bool(b["remote"]):
					## En directo: el golpe lo aplica el dueno de la victima.
					_event(st, "melee", a, {"target": int(b["id"]), "dmg": float(w["dmg"])})
				else:
					_hurt(st, b, float(w["dmg"]), int(a["id"]))
				break
		_event(st, "punch", a)
		return
	var sent: Array = []
	for k: int in int(w["pellets"]):
		var dir: Vector2 = aim.rotated(rng.randfn(0.0, float(w["spread"])))
		(st["bullets"] as Array).append({"p": (a["p"] as Vector2) + dir * (R + 6.0), "v": dir * 1700.0, "dmg": float(w["dmg"]),
			"owner": int(a["id"]), "left": float(w["range"])})
		sent.append([snappedf(dir.x, 0.001), snappedf(dir.y, 0.001)])
	_event(st, "shot", a, {"weapon": str(a["weapon"]), "dirs": sent})


static func _bullets_step(st: Dictionary, dt: float) -> void:
	var bl: Array = st["bullets"]
	var agents: Array = st["agents"]
	var k: int = bl.size() - 1
	while k >= 0:
		var b: Dictionary = bl[k]
		var v: Vector2 = b["v"]
		var dist: float = v.length() * dt
		var n: int = maxi(1, ceili(dist / 16.0))
		var gone: bool = false
		for s: int in n:
			var p: Vector2 = (b["p"] as Vector2) + v * dt / float(n)
			b["p"] = p
			b["left"] = float(b["left"]) - dist / float(n)
			if float(b["left"]) <= 0.0 or blocks_shot(st, p):
				gone = true
				break
			for a: Dictionary in agents:
				if int(a["id"]) != int(b["owner"]) and bool(a["alive"]) and bool(a["landed"]) and (a["p"] as Vector2).distance_squared_to(p) < R * R:
					## A un jugador de otro movil la bala solo se le para: el dano lo cuenta su dueno.
					if not bool(a["remote"]):
						_hurt(st, a, float(b["dmg"]), int(b["owner"]))
					gone = true
					break
			if gone:
				break
		if gone:
			bl.remove_at(k)
		k -= 1


static func _hurt(st: Dictionary, a: Dictionary, dmg: float, by: int) -> void:
	if not bool(a["alive"]):
		return
	if by >= 0 and float(a["armor"]) > 0.0:
		var soak: float = minf(float(a["armor"]), dmg * 0.6)
		a["armor"] = float(a["armor"]) - soak
		dmg -= soak
	a["hp"] = float(a["hp"]) - dmg
	a["heal_t"] = 0.0 if by >= 0 else float(a["heal_t"])
	if by >= 0:
		a["hit_t"] = 0.15
		a["last_by"] = by
		_event(st, "hit", a, {"dmg": dmg, "by": by})
	if float(a["hp"]) <= 0.0:
		_die(st, a, by if by >= 0 else int(a.get("last_by", -1)), by < 0)


## Cae un jugador: puesto, eliminacion para quien le gano, aviso y lo que suelta.
static func _die(st: Dictionary, a: Dictionary, killer: int, by_zone: bool = false) -> void:
	if not bool(a["alive"]) and int(a["place"]) > 0:
		return
	a["alive"] = false
	a["hp"] = minf(float(a["hp"]), 0.0)
	a["place"] = alive_count(st) + 1
	if killer >= 0 and killer < (st["agents"] as Array).size():
		st["agents"][killer]["kills"] = int(st["agents"][killer]["kills"]) + 1
	(st["feed"] as Array).append([killer, int(a["id"]), by_zone])
	_event(st, "dead", a, {"by": killer})
	Rules.hook(st, "on_kill", [killer, int(a["id"])])
	## Suelta su arma y lo que llevaba (con ids iguales en todos los moviles).
	var nid: int = int(a["nid"])
	if str(a["weapon"]) != "punos":
		(st["loot"] as Array).append({"p": a["p"], "item": str(a["weapon"]), "id": "d%dw" % nid})
	if float(a["armor"]) >= 25.0:
		(st["loot"] as Array).append({"p": (a["p"] as Vector2) + Vector2(24, 10), "item": "chaleco1" if float(a["armor"]) < 50.0 else "chaleco2", "id": "d%da" % nid})
	if int((a["heals"] as Dictionary).get("venda", 0)) > 0:
		(st["loot"] as Array).append({"p": (a["p"] as Vector2) + Vector2(-24, 10), "item": "venda", "id": "d%dh" % nid})


static func _check_end(st: Dictionary) -> void:
	var me: Dictionary = st["agents"][0]
	var left: int = alive_count(st)
	if not bool(me["alive"]):
		st["over"] = true
		st["won"] = int(me["place"]) <= int(st["top"])
		st["place"] = int(me["place"])
	elif left <= int(st["top"]):
		st["over"] = true
		st["won"] = true
		st["place"] = left



# ------------------------------------------------------------------ en directo

## Prepara la partida en directo: humanos en los primeros puestos (por orden de sala), el resto
## bots; "me" pasa a ser el 0 (cambiandolo con el 0 de la sala, asi el resto del juego no cambia)
## y se marca que es de otro movil. La zona usa un azar propio para cerrarse igual en todos.
static func setup_online(st: Dictionary, aliases: Array, me: int, host: bool) -> void:
	var agents: Array = st["agents"]
	var humans: int = mini(aliases.size(), agents.size())
	for k: int in agents.size():
		var a: Dictionary = agents[k]
		if k < humans:
			a["bot"] = false
			a["name"] = str(aliases[k])
			a["drop_t"] = PLANE_T
			a["remote"] = k != me
		else:
			a["remote"] = not host
	var mine: Dictionary = agents[me]
	agents[me] = agents[0]
	agents[0] = mine
	for i: int in agents.size():
		agents[i]["id"] = i
	var zr: RandomNumberGenerator = RandomNumberGenerator.new()
	zr.seed = int(st["seed"]) * 31 + 7
	st["zrng"] = zr
	st["top"] = 1
	st["online"] = true


## Puesto local de un jugador por su numero de sala (nid).
static func by_nid(st: Dictionary, nid: int) -> Dictionary:
	for a: Dictionary in st["agents"]:
		if int(a["nid"]) == nid:
			return a
	return {}


## Lo que se manda de un jugador (corto: va 8 veces por segundo).
static func net_pack(a: Dictionary) -> Array:
	var p: Vector2 = a["p"]
	var v: Vector2 = a["v"]
	var aim: Vector2 = a["aim"]
	return [int(a["nid"]), snappedf(p.x, 0.1), snappedf(p.y, 0.1), snappedf(v.x, 0.1), snappedf(v.y, 0.1), snappedf(float(a["hp"]), 0.1),
		snappedf(float(a["armor"]), 0.1), str(a["weapon"]), 1 if bool(a["landed"]) else 0, snappedf(aim.x, 0.01), snappedf(aim.y, 0.01),
		1 if float(a["heal_t"]) > 0.0 else 0]


static func net_apply(st: Dictionary, a: Dictionary, d: Array) -> void:
	if d.size() < 12 or not bool(a["remote"]) or not bool(a["alive"]):
		return
	var np: Vector2 = Vector2(float(d[1]), float(d[2]))
	if blocks_move(st, np) and bool(a["landed"]):
		return
	a["net_p"] = np
	a["v"] = Vector2(float(d[3]), float(d[4]))
	a["hp"] = clampf(float(d[5]), 0.0, MAX_HP)
	a["armor"] = clampf(float(d[6]), 0.0, 75.0)
	if WEAPONS.has(str(d[7])):
		a["weapon"] = str(d[7])
	a["aim"] = Vector2(float(d[9]), float(d[10]))
	a["heal_t"] = 1.0 if int(d[11]) == 1 else 0.0
	a["seen"] = float(st["time"])
	if int(d[8]) == 1 and not bool(a["landed"]):
		a["landed"] = true
		a["p"] = np
		_event(st, "land", a)


## Un jugador de otro movil: sigue lo ultimo que se supo (con su velocidad, sin tirones).
static func _follow_net(a: Dictionary, dt: float) -> void:
	if not bool(a["landed"]):
		return
	a["net_p"] = (a["net_p"] as Vector2) + (a["v"] as Vector2) * dt
	a["p"] = (a["p"] as Vector2).lerp(a["net_p"], clampf(dt * 12.0, 0.0, 1.0))


## Disparo de otro movil: las mismas balas (las paran los muros y hacen dano a lo que es tuyo).
static func net_shot(st: Dictionary, a: Dictionary, dirs: Array) -> void:
	if not bool(a["alive"]) or not WEAPONS.has(str(a["weapon"])):
		return
	var w: Dictionary = WEAPONS[str(a["weapon"])]
	for dv: Variant in dirs.slice(0, 12):
		if not dv is Array or (dv as Array).size() < 2:
			continue
		var dir: Vector2 = Vector2(float(dv[0]), float(dv[1])).normalized()
		(st["bullets"] as Array).append({"p": (a["p"] as Vector2) + dir * (R + 6.0), "v": dir * 1700.0, "dmg": float(w["dmg"]),
			"owner": int(a["id"]), "left": float(w["range"])})
	_event(st, "shot", a, {"weapon": str(a["weapon"]), "dirs": []})


## Otro movil cogio algo: se quita del suelo en todos (y deja lo que solto).
static func net_pick(st: Dictionary, a: Dictionary, lid: String, item: String) -> void:
	var loot: Array = st["loot"]
	for k: int in loot.size():
		if str((loot[k] as Dictionary).get("id", "")) == lid:
			loot.remove_at(k)
			break
	if WEAPONS.has(item) or ARMORS.has(item) or HEALS.has(item):
		var old: String = take(a, item)
		if old != "":
			loot.append({"p": (a["p"] as Vector2) + Vector2(0, 30), "item": old, "id": lid + "o"})


## Golpe de otro movil a algo tuyo (los punos).
static func net_melee(st: Dictionary, target: Dictionary, dmg: float, by: int) -> void:
	if not bool(target["remote"]) and bool(target["alive"]):
		_hurt(st, target, clampf(dmg, 0.0, 40.0), by)


## Otro movil dice que su jugador (o su bot) ha caido.
static func net_dead(st: Dictionary, a: Dictionary, killer: int) -> void:
	if bool(a["remote"]) and bool(a["alive"]):
		_die(st, a, killer, killer < 0)


## Quien lleva mucho sin dar senales (se fue de la partida) cae.
static func net_timeouts(st: Dictionary, limit: float) -> void:
	for a: Dictionary in st["agents"]:
		if bool(a["remote"]) and bool(a["alive"]) and float(st["time"]) > PLANE_T + limit and float(st["time"]) - float(a["seen"]) > limit:
			_die(st, a, -1, true)


# ------------------------------------------------------------------ cabeza de los jugadores

static func visible_enemy(st: Dictionary, a: Dictionary, reach: float) -> int:
	var best: int = -1
	var bd: float = reach
	for b: Dictionary in st["agents"]:
		if b == a or not bool(b["alive"]) or not bool(b["landed"]):
			continue
		var d: float = (b["p"] as Vector2).distance_to(a["p"])
		if d < bd and sight(st, a["p"], b["p"]):
			bd = d
			best = int(b["id"])
	return best


## Decide cada 0,25 s: luchar, volver a la zona, curarse, buscar botin o pasear.
static func think(st: Dictionary, a: Dictionary) -> void:
	var w: Dictionary = WEAPONS[str(a["weapon"])]
	var skill: float = float(a["skill"])
	var rng: RandomNumberGenerator = st["rng"]
	a["fire"] = false
	a["move"] = Vector2.ZERO
	if float(a["heal_t"]) > 0.0:
		return
	var reach: float = maxf(float(w["range"]), 420.0) * 1.05
	var e: int = visible_enemy(st, a, reach)
	var zc: Vector2 = st["zone_c"]
	var zr: float = float(st["zone_r"])
	var p: Vector2 = a["p"]
	var outside: bool = p.distance_to(zc) > zr - TILE * 0.5
	## Va a quedar fuera del circulo que viene: hay que moverse ya.
	var next_out: bool = int(st["phase"]) >= 0 and p.distance_to(st["to_c"]) > float(st["to_r"]) - TILE and float(st["phase_t"]) > float(PHASES[mini(int(st["phase"]), PHASES.size() - 1)][0]) * 0.5
	if e >= 0:
		var be: Dictionary = st["agents"][e]
		var de: float = (be["p"] as Vector2).distance_to(p)
		## Sin arma no se busca pelea; con poca vida (o con prudencia) se evita al que no te busca.
		var hunted: bool = int(be["target"]) == int(a["id"]) or de < 170.0
		if str(a["weapon"]) == "punos" and de > 160.0:
			e = -1
			## Sin arma y alguien armado te busca: huir (hacia el botin si hay).
			if hunted or de < 320.0:
				var away: Vector2 = (p - (be["p"] as Vector2)).normalized()
				a["move"] = (away + _loot_dir(st, a) * 0.8).normalized()
				a["target"] = -1
				return
		elif bool(a.get("cautious", false)) and not hunted and de > float(w["range"]) * 0.8:
			e = -1
		elif float(a["hp"]) < (55.0 if bool(a.get("cautious", false)) else 35.0) and de > 220.0 and int((a["heals"] as Dictionary).get("venda", 0)) + int((a["heals"] as Dictionary).get("botiquin", 0)) > 0:
			a["move"] = (p - (be["p"] as Vector2)).normalized()
			a["target"] = -1
			return
	if e >= 0 and not (outside and float(a["hp"]) < 40.0):
		var b: Dictionary = st["agents"][e]
		var bp: Vector2 = b["p"]
		var d: float = bp.distance_to(p)
		if int(a["target"]) != e:
			a["target"] = e
			a["seen_t"] = 0.0
		a["seen_t"] = float(a["seen_t"]) + 0.25
		## Punteria: error segun la habilidad, y un momento para reaccionar.
		var err: float = lerpf(0.45, 0.05, skill)
		a["aim"] = (bp + (b["move"] as Vector2) * SPEED * 0.12 - p).normalized().rotated(rng.randfn(0.0, err))
		a["fire"] = float(a["seen_t"]) >= lerpf(1.2, 0.25, skill) and d <= float(w["range"]) * 0.98 and rng.randf() < lerpf(0.45, 0.95, skill)
		## Moverse: de lado, acercarse o alejarse segun el arma.
		a["strafe_t"] = float(a["strafe_t"]) - 0.25
		if float(a["strafe_t"]) <= 0.0:
			a["strafe_t"] = rng.randf_range(0.8, 1.6)
			a["strafe"] = -float(a["strafe"])
		var to: Vector2 = (bp - p).normalized()
		var mv: Vector2 = to.orthogonal() * float(a["strafe"]) * 0.8
		if d > float(w["range"]) * 0.75:
			mv += to
		elif d < float(w["range"]) * 0.35 and str(a["weapon"]) != "escopeta" and str(a["weapon"]) != "punos":
			mv -= to * 0.6
		if outside:
			mv += (zc - p).normalized()
		a["move"] = mv
		a["path"] = []
		return
	a["target"] = -1
	if outside or next_out:
		_go(st, a, st["to_c"] if next_out and not outside else zc)
		return
	if float(a["hp"]) < (85.0 if bool(a.get("cautious", false)) else 65.0) and start_heal(st, a):
		return
	## Botin cercano que mejora lo que llevo.
	var best: Vector2 = Vector2.INF
	var bd: float = TILE * 11.0
	for it: Dictionary in st["loot"]:
		var ip: Vector2 = it["p"]
		var d2: float = ip.distance_to(p)
		if d2 < bd and wants(a, str(it["item"])) and ip.distance_to(zc) < zr and not (bool(a.get("cautious", false)) and _watched(st, a, ip)):
			bd = d2
			best = ip
	if best != Vector2.INF:
		_go(st, a, best)
		return
	## Pasear hacia dentro de la zona (los mas valientes, hacia el centro).
	if (a["path"] as Array).is_empty() or (a["goal"] as Vector2).distance_to(zc) > zr:
		var g: Vector2 = zc + Vector2.from_angle(rng.randf() * TAU) * rng.randf() * zr * lerpf(0.7, 0.35, skill)
		_go(st, a, g)
	else:
		_follow(st, a)


## Si algun rival cercano ve ese punto (el prudente no va alli).
static func _watched(st: Dictionary, a: Dictionary, q: Vector2) -> bool:
	for b: Dictionary in st["agents"]:
		if b != a and bool(b["alive"]) and bool(b["landed"]) and (b["p"] as Vector2).distance_to(q) < 380.0 and sight(st, b["p"], q):
			return true
	return false


## Hacia el botin util mas cercano (o nada).
static func _loot_dir(st: Dictionary, a: Dictionary) -> Vector2:
	var p: Vector2 = a["p"]
	var best: Vector2 = Vector2.ZERO
	var bd: float = TILE * 8.0
	for it: Dictionary in st["loot"]:
		var d: float = (it["p"] as Vector2).distance_to(p)
		if d < bd and wants(a, str(it["item"])) and sight(st, p, it["p"]):
			bd = d
			best = ((it["p"] as Vector2) - p).normalized()
	return best


static func _go(st: Dictionary, a: Dictionary, g: Vector2) -> void:
	if (a["goal"] as Vector2).distance_to(g) > TILE * 1.5 or (a["path"] as Array).is_empty():
		a["goal"] = g
		a["path"] = find_path(st, a["p"], g)
	_follow(st, a)


static func _follow(st: Dictionary, a: Dictionary) -> void:
	var path: Array = a["path"]
	var p: Vector2 = a["p"]
	while not path.is_empty() and (path[0] as Vector2).distance_to(p) < TILE * 0.45:
		path.pop_front()
	if path.is_empty():
		a["move"] = ((a["goal"] as Vector2) - p).normalized() if (a["goal"] as Vector2).distance_to(p) > 8.0 else Vector2.ZERO
		return
	a["move"] = ((path[0] as Vector2) - p).normalized()


## Camino por casillas (8 direcciones sin cortar esquinas) hasta la casilla libre mas cercana a g.
static func find_path(st: Dictionary, from: Vector2, g: Vector2) -> Array:
	var w: int = int(st["w"])
	var h: int = int(st["h"])
	var s: Vector2i = Vector2i(floori(from.x / TILE), floori(from.y / TILE))
	var t: Vector2i = Vector2i(clampi(floori(g.x / TILE), 0, w - 1), clampi(floori(g.y / TILE), 0, h - 1))
	var came: Dictionary = {s: s}
	var cost: Dictionary = {s: 0.0}
	var open: Array = [[0.0, s]]
	var best: Vector2i = s
	var bh: float = INF
	var n: int = 0
	while not open.is_empty() and n < 2500:
		n += 1
		var bi: int = 0
		for i: int in open.size():
			if float(open[i][0]) < float(open[bi][0]):
				bi = i
		var cur: Vector2i = open[bi][1]
		open.remove_at(bi)
		var hh: float = Vector2(cur).distance_to(Vector2(t))
		if hh < bh:
			bh = hh
			best = cur
		if cur == t:
			break
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
			var nn: Vector2i = cur + d
			if SOLID_MOVE.contains(cell(st, nn.x, nn.y)):
				continue
			if d.x != 0 and d.y != 0 and (SOLID_MOVE.contains(cell(st, cur.x + d.x, cur.y)) or SOLID_MOVE.contains(cell(st, cur.x, cur.y + d.y))):
				continue
			var nc: float = float(cost[cur]) + (1.41 if d.x != 0 and d.y != 0 else 1.0)
			if nc < float(cost.get(nn, INF)):
				cost[nn] = nc
				came[nn] = cur
				open.append([nc + Vector2(nn).distance_to(Vector2(t)), nn])
	var out: Array = []
	var c: Vector2i = best
	while c != s:
		out.push_front((Vector2(c) + Vector2(0.5, 0.5)) * TILE)
		c = came[c]
	return out


## El jugador manejado por el bot (el de QA y el analizador): misma cabeza, mejor punteria.
static func bot_me(st: Dictionary) -> void:
	var me: Dictionary = st["agents"][0]
	if not bool(me["alive"]):
		return
	if not bool(me["landed"]):
		## Salta cuando el avion pasa cerca del centro de la isla.
		var size: Vector2 = Vector2(int(st["w"]), int(st["h"])) * TILE
		if plane_pos(st).distance_to(size * 0.5) < TILE * 4.0 or float(st["time"]) > PLANE_T * 0.8:
			drop(st, me)
		return
	me["think"] = float(me["think"]) - 1.0
	if float(me["think"]) <= 0.0:
		me["think"] = 6.0
		think(st, me)


static func bot_play(level: Dictionary, dt: float = 1.0 / 30.0) -> Dictionary:
	var st: Dictionary = new_state(level)
	var me: Dictionary = st["agents"][0]
	me["skill"] = 1.0
	me["cautious"] = true
	me["glide"] = true
	var guard: int = 0
	while not bool(st["over"]) and guard < int(600.0 / dt):
		guard += 1
		## El bot "piensa" cada 0,25 s como los demas.
		if not bool(me["landed"]):
			bot_me(st)
		elif guard % maxi(1, int(0.25 / dt)) == 0:
			think(st, me)
		step(st, dt)
		(st["events"] as Array).clear()
	return {"won": bool(st["won"]), "place": int(st["place"]), "time": float(st["time"]), "kills": int(me["kills"])}


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var m: Array = rows(level)
	var h: int = m.size()
	var w: int = str(m[0]).length() if h > 0 else 0
	if w < 24 or w > 64 or h < 24 or h > 64:
		issues.append("royale_size")
	for r: Variant in m:
		if str(r).length() != w:
			issues.append("royale_rows")
			break
	var land: int = 0
	var floors: int = 0
	for r2: Variant in m:
		for c: String in str(r2):
			if not SOLID_MOVE.contains(c):
				land += 1
			if c == "_":
				floors += 1
	if land < 300:
		issues.append("royale_small_island")
	if floors < 20:
		issues.append("royale_no_houses")
	var top: int = int(level.get("top", 1))
	if top < 1 or top > int(level.get("bots", 15)):
		issues.append("royale_top")
	var par: int = 0
	if issues.is_empty():
		## Tiene que salir en 2 de 3 partidas (la suerte cuenta en un battle royale).
		var wins: int = 0
		var tsum: float = 0.0
		for k: int in 3:
			var lv: Dictionary = level.duplicate()
			lv["seed"] = int(level.get("seed", 1)) + k * 101
			var r: Dictionary = bot_play(lv, 1.0 / 15.0)
			if bool(r["won"]):
				wins += 1
				tsum += float(r["time"])
		if wins < 2:
			issues.append("royale_too_hard")
		else:
			par = int(tsum / float(wins) * 1.3)
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": top, "enemies": int(level.get("bots", 15)),
		"enemy_problems": [], "par": par}
