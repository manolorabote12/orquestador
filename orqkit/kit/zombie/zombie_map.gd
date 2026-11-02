extends RefCounted
## Shooter 3D de zombis en primera persona (oleadas): sobrevive a todas las oleadas en una arena
## con obstaculos. Reglas, simulacion pura, zombis, bot y analizador.
## 1 - Mapa (game.json -> levels[i].map): casillas de 2 m. "#" muro, "c" caja (tapa), "." suelo,
##     "P" salida, "Z" sitio por donde entran los zombis, "S" escopeta, "R" fusil, "+" botiquin
##     (aparece entre oleadas). Fila "#semilla".
## 2 - Parametros: "waves" (oleadas), "count" (zombis en la primera), "grow" (mas por oleada),
##     "speed" (0-1), "hp" (vida del jugador), "types" (desde que oleada salen corredores y brutos).
## 3 - Cooperativo en directo (hasta 4): cada movil mueve a su jugador y sus disparos; el anfitrion
##     (el de sesion mas baja) mueve los zombis y las oleadas y manda como van 8 veces por segundo.
##     Los zombis persiguen al jugador vivo mas cercano; quien cae vuelve en la oleada siguiente y
##     se pierde si caen todos a la vez. Mensajes: net_pack_me/net_apply_mate (jugadores),
##     net_snapshot/net_apply_snap (zombis), net_hit (un disparo de otro) y "bite" (un mordisco).
## 4 - Plantilla por datos (game.json o nivel -> "fps"): armas ("weapons": dano, cadencia,
##     cargador, recarga, dispersion, perdigones, alcance y "look" pistol/shotgun/rifle), cual se
##     lleva al empezar y cual da cada letra del mapa ("slots": {"start", "S", "R"}) y cambios a los
##     zombis ("kinds": walker, runner, brute). Sin "fps", todo como siempre.
## Coordenadas en casillas; en 3D una casilla mide TILE metros.

const TILE: float = 2.0
const R: float = 0.28
const SPEED: float = 2.3
const ZR: float = 0.32
const WEAPONS: Dictionary = {
	"pistola": {"dmg": 34.0, "rate": 0.26, "mag": 12, "reload": 1.1, "spread": 0.015, "pellets": 1, "range": 14.0},
	"escopeta": {"dmg": 24.0, "rate": 0.75, "mag": 6, "reload": 1.8, "spread": 0.11, "pellets": 6, "range": 7.0},
	"fusil": {"dmg": 28.0, "rate": 0.1, "mag": 30, "reload": 1.6, "spread": 0.035, "pellets": 1, "range": 16.0},
}
const KINDS: Dictionary = {
	"walker": {"hp": 70.0, "speed": 0.85, "dmg": 10.0, "r": 0.32},
	"runner": {"hp": 40.0, "speed": 1.75, "dmg": 7.0, "r": 0.28},
	"brute": {"hp": 260.0, "speed": 0.62, "dmg": 22.0, "r": 0.45},
}


## Armas de serie: como se dibujan.
const LOOKS: Dictionary = {"pistola": "pistol", "escopeta": "shotgun", "fusil": "rifle"}


## Catalogo de la partida: armas, ranuras (start, S, R) y zombis.
static func catalog(level: Dictionary) -> Dictionary:
	var c: Dictionary = {"weapons": WEAPONS.duplicate(true), "kinds": KINDS.duplicate(true), "slots": {"start": "pistola", "S": "escopeta", "R": "fusil"}}
	for k: String in LOOKS:
		c["weapons"][k]["look"] = LOOKS[k]
	var extra: Variant = level.get("fps", {})
	if extra is Dictionary:
		for sec: String in ["weapons", "kinds"]:
			var add: Variant = (extra as Dictionary).get(sec, {})
			if add is Dictionary:
				for k2: Variant in add:
					if add[k2] is Dictionary:
						var base: Dictionary = (c[sec] as Dictionary).get(str(k2), {}).duplicate()
						base.merge(add[k2], true)
						c[sec][str(k2)] = base
		if (extra as Dictionary).get("slots", null) is Dictionary:
			for k3: Variant in extra["slots"]:
				if (c["weapons"] as Dictionary).has(str(extra["slots"][k3])):
					c["slots"][str(k3)] = str(extra["slots"][k3])
	return c


static func rows(level: Dictionary) -> Array:
	var out: Array = []
	for r: Variant in level.get("map", []):
		var t: String = str(r)
		if t.begins_with("#") and t.substr(1).is_valid_int():
			continue
		out.append(t)
	return out


static func cell(st: Dictionary, x: int, y: int) -> String:
	var m: Array = st["map"]
	if y < 0 or y >= m.size() or x < 0 or x >= str(m[y]).length():
		return "#"
	return str(m[y])[x]


static func walkable(st: Dictionary, x: int, y: int) -> bool:
	var c: String = cell(st, x, y)
	return c != "#" and c != "c"


static func center(c: Vector2i) -> Vector2:
	return Vector2(c) + Vector2(0.5, 0.5)


static func new_state(level: Dictionary) -> Dictionary:
	var m: Array = rows(level)
	var seed_v: int = int(level.get("seed", 1))
	for r: Variant in level.get("map", []):
		var t: String = str(r)
		if t.begins_with("#") and t.substr(1).is_valid_int():
			seed_v = int(t.substr(1))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_v
	var cat: Dictionary = catalog(level)
	var st: Dictionary = {"weapons": cat["weapons"], "kinds": cat["kinds"], "slots": cat["slots"], "map": m, "h": m.size(), "w": str(m[0]).length() if m.size() > 0 else 0, "rng": rng, "t": 0.0,
		"zombies": [], "spawns": [], "pickups": [], "heals": [], "events": [], "won": false, "over": false, "kills": 0,
		"wave": 0, "waves": clampi(int(level.get("waves", 4)), 1, 20), "count": clampi(int(level.get("count", 6)), 1, 60),
		"grow": clampi(int(level.get("grow", 3)), 0, 20), "zspeed": clampf(float(level.get("speed", 0.4)), 0.0, 1.0),
		"types": level.get("types", [3, 4]), "to_spawn": [], "spawn_t": 0.0, "break_t": 2.5, "flow": {}, "flow_t": 0.0,
		"yaw": 0.0, "pitch": 0.0, "hurt_t": 0.0, "zid": 0, "role": "solo", "mates": {}, "my_nid": 0, "net_pending": 0,
		"start": Vector2.ZERO}
	var start: Vector2 = Vector2(1.5, 1.5)
	for y: int in m.size():
		var row: String = str(m[y])
		for x: int in row.length():
			match row[x]:
				"P":
					start = center(Vector2i(x, y))
				"Z":
					(st["spawns"] as Array).append(Vector2i(x, y))
				"S":
					(st["pickups"] as Array).append({"c": Vector2i(x, y), "item": str(st["slots"]["S"]), "got": false})
				"R":
					(st["pickups"] as Array).append({"c": Vector2i(x, y), "item": str(st["slots"]["R"]), "got": false})
				"+":
					(st["heals"] as Array).append({"c": Vector2i(x, y), "on": false})
	var hp: float = clampf(float(level.get("hp", 100.0)), 20.0, 500.0)
	st["start"] = start
	var w0: String = str(st["slots"]["start"])
	st["me"] = {"dead": false, "p": start, "hp": hp, "max_hp": hp, "weapon": w0, "ammo": int(st["weapons"][w0]["mag"]), "cd": 0.0, "reload": 0.0, "guns": [w0]}
	return st


static func _ev(st: Dictionary, kind: String, extra: Dictionary = {}) -> void:
	var e: Dictionary = {"kind": kind}
	e.merge(extra)
	(st["events"] as Array).append(e)


static func _free(st: Dictionary, p: Vector2, r: float) -> bool:
	for off: Vector2 in [Vector2(r, 0), Vector2(-r, 0), Vector2(0, r), Vector2(0, -r), Vector2(r, r) * 0.7, Vector2(-r, r) * 0.7, Vector2(r, -r) * 0.7, Vector2(-r, -r) * 0.7]:
		var q: Vector2 = p + off
		if not walkable(st, floori(q.x), floori(q.y)):
			return false
	return true


## Linea libre de a a b; con "thick" mira tambien dos lineas paralelas (para cuerpos con ancho).
static func sees(st: Dictionary, a: Vector2, b: Vector2, thick: float = 0.0) -> bool:
	var d: float = a.distance_to(b)
	var n: int = maxi(1, ceili(d / 0.1))
	var side: Vector2 = (b - a).normalized().orthogonal() * thick
	for off: Vector2 in ([Vector2.ZERO] if thick <= 0.0 else [Vector2.ZERO, side, -side]):
		for k: int in range(1, n):
			var q: Vector2 = a.lerp(b, float(k) / float(n)) + off
			if not walkable(st, floori(q.x), floori(q.y)):
				return false
	return true


## Mapa de distancias hasta el jugador (los zombis bajan por el).
## Jugadores vivos a los que pueden ir los zombis: tu (nid -1) y, en directo, los demas.
static func targets(st: Dictionary) -> Array:
	var out: Array = []
	var me: Dictionary = st["me"]
	if not bool(me["dead"]):
		out.append({"nid": -1, "p": me["p"]})
	for m: Variant in (st["mates"] as Dictionary).values():
		var md: Dictionary = m
		if bool(md["alive"]):
			out.append({"nid": int(md["nid"]), "p": md["p"]})
	return out


static func _flow(st: Dictionary) -> void:
	var dist: Dictionary = {}
	var q: Array[Vector2i] = []
	for tg: Dictionary in targets(st):
		var tp: Vector2 = tg["p"]
		var s: Vector2i = Vector2i(floori(tp.x), floori(tp.y))
		if not dist.has(s):
			dist[s] = 0
			q.append(s)
	var i: int = 0
	while i < q.size():
		var c: Vector2i = q[i]
		i += 1
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
			var n: Vector2i = c + d
			if dist.has(n) or not walkable(st, n.x, n.y):
				continue
			if d.x != 0 and d.y != 0 and (not walkable(st, c.x + d.x, c.y) or not walkable(st, c.x, c.y + d.y)):
				continue
			dist[n] = int(dist[c]) + 1
			q.append(n)
	st["flow"] = dist


# ------------------------------------------------------------------ paso

## inp = {"move": Vector2 (relativo a la mirada), "fire": bool}; la mirada es st.yaw.
static func step(st: Dictionary, inp: Dictionary, dt: float) -> void:
	if bool(st["over"]):
		return
	st["t"] = float(st["t"]) + dt
	st["hurt_t"] = maxf(0.0, float(st["hurt_t"]) - dt)
	var me: Dictionary = st["me"]
	if bool(me["dead"]):
		_world(st, dt)
		return
	var p: Vector2 = me["p"]
	var mv: Vector2 = inp.get("move", Vector2.ZERO)
	if mv.length() > 1.0:
		mv = mv.normalized()
	var yaw: float = float(st["yaw"])
	var fwd: Vector2 = Vector2(-sin(yaw), -cos(yaw))
	var right: Vector2 = Vector2(cos(yaw), -sin(yaw))
	var d: Vector2 = (right * mv.x + fwd * mv.y) * SPEED * dt
	for axis: int in 2:
		var np: Vector2 = p
		np[axis] += d[axis]
		if _free(st, np, R):
			p = np
	me["p"] = p
	## Armas: cadencia, cargador y recarga (sola al vaciarse).
	me["cd"] = maxf(0.0, float(me["cd"]) - dt)
	if float(me["reload"]) > 0.0:
		me["reload"] = float(me["reload"]) - dt
		if float(me["reload"]) <= 0.0:
			me["ammo"] = int(st["weapons"][str(me["weapon"])]["mag"])
			_ev(st, "reloaded")
	elif bool(inp.get("fire", false)) and float(me["cd"]) <= 0.0:
		_shoot(st)
	if bool(inp.get("reload", false)) and float(me["reload"]) <= 0.0 and int(me["ammo"]) < int(st["weapons"][str(me["weapon"])]["mag"]):
		me["reload"] = float(st["weapons"][str(me["weapon"])]["reload"])
		_ev(st, "reload")
	## Coger armas y botiquines.
	for pk: Dictionary in st["pickups"]:
		if not bool(pk["got"]) and p.distance_to(center(pk["c"])) < 0.6:
			pk["got"] = true
			var item: String = pk["item"]
			if not (me["guns"] as Array).has(item):
				(me["guns"] as Array).append(item)
			me["weapon"] = item
			me["ammo"] = int(st["weapons"][item]["mag"])
			me["reload"] = 0.0
			_ev(st, "weapon", {"item": item})
	for hl: Dictionary in st["heals"]:
		if bool(hl["on"]) and p.distance_to(center(hl["c"])) < 0.6 and float(me["hp"]) < float(me["max_hp"]):
			hl["on"] = false
			me["hp"] = minf(float(me["max_hp"]), float(me["hp"]) + float(me["max_hp"]) * 0.5)
			_ev(st, "heal")
	_world(st, dt)


## Zombis y oleadas: los mueve este movil (solo o anfitrion) o los sigue (invitado).
static func _world(st: Dictionary, dt: float) -> void:
	if str(st["role"]) == "client":
		_net_follow(st, dt)
		return
	_waves(st, dt)
	if bool(st["over"]):
		return
	st["flow_t"] = float(st["flow_t"]) - dt
	if float(st["flow_t"]) <= 0.0:
		st["flow_t"] = 0.4
		_flow(st)
	_zombies(st, dt)
	## En directo se pierde cuando caen todos a la vez.
	if str(st["role"]) == "host" and targets(st).is_empty() and not bool(st["over"]):
		st["over"] = true
		st["won"] = false
		_ev(st, "team_lost")


static func _shoot(st: Dictionary) -> void:
	var me: Dictionary = st["me"]
	var wname: String = me["weapon"]
	var w: Dictionary = st["weapons"][wname]
	if int(me["ammo"]) <= 0:
		me["reload"] = float(w["reload"])
		_ev(st, "reload")
		return
	me["ammo"] = int(me["ammo"]) - 1
	me["cd"] = float(w["rate"])
	var rng: RandomNumberGenerator = st["rng"]
	var p: Vector2 = me["p"]
	var hits: Array = []
	var dmgs: Array = []
	for k: int in int(w["pellets"]):
		var a: float = float(st["yaw"]) + rng.randfn(0.0, float(w["spread"]))
		var dir: Vector2 = Vector2(-sin(a), -cos(a))
		var best: Dictionary = {}
		var bd: float = float(w["range"])
		for z: Dictionary in st["zombies"]:
			if float(z["hp"]) <= 0.0:
				continue
			var to: Vector2 = (z["p"] as Vector2) - p
			var along: float = to.dot(dir)
			if along <= 0.0 or along > bd:
				continue
			var off: float = (to - dir * along).length()
			if off < float(z["r"]):
				bd = along
				best = z
		## La pared para la bala antes.
		var wall: float = _wall_dist(st, p, dir, bd)
		if not best.is_empty() and wall >= bd:
			best["hp"] = float(best["hp"]) - float(w["dmg"])
			best["hit_t"] = 0.12
			best["slow"] = 0.25
			hits.append(int(best["id"]))
			dmgs.append(float(w["dmg"]))
			if float(best["hp"]) <= 0.0:
				st["kills"] = int(st["kills"]) + 1
				_ev(st, "kill", {"id": int(best["id"]), "p": best["p"]})
	_ev(st, "shot", {"weapon": wname, "hits": hits, "dmgs": dmgs})
	if int(me["ammo"]) <= 0:
		me["reload"] = float(w["reload"])
		_ev(st, "reload")


static func _wall_dist(st: Dictionary, p: Vector2, dir: Vector2, maxd: float) -> float:
	var t: float = 0.0
	while t < maxd:
		var q: Vector2 = p + dir * t
		if cell(st, floori(q.x), floori(q.y)) == "#" or cell(st, floori(q.x), floori(q.y)) == "c":
			return t
		t += 0.12
	return maxd


## Oleadas: cuando no quedan zombis, descanso, botiquines y la siguiente (mas y mas duros).
static func _waves(st: Dictionary, dt: float) -> void:
	var alive: int = 0
	for z: Dictionary in st["zombies"]:
		if float(z["hp"]) > 0.0:
			alive += 1
	var pending: Array = st["to_spawn"]
	if alive == 0 and pending.is_empty():
		if int(st["wave"]) >= int(st["waves"]):
			st["won"] = true
			st["over"] = true
			_ev(st, "win")
			return
		st["break_t"] = float(st["break_t"]) - dt
		if float(st["break_t"]) <= 0.0:
			st["wave"] = int(st["wave"]) + 1
			var wv: int = int(st["wave"])
			var n: int = int(st["count"]) + int(st["grow"]) * (wv - 1)
			var rng: RandomNumberGenerator = st["rng"]
			var types: Array = st["types"]
			for k: int in n:
				var kind: String = "walker"
				if types.size() > 0 and wv >= int(types[0]) and rng.randf() < 0.3:
					kind = "runner"
				if types.size() > 1 and wv >= int(types[1]) and k % 6 == 5:
					kind = "brute"
				pending.append(kind)
			st["spawn_t"] = 0.0
			st["break_t"] = 4.0
			(st["zombies"] as Array).clear()
			_wave_started(st, wv)
		return
	if pending.is_empty():
		return
	st["spawn_t"] = float(st["spawn_t"]) - dt
	if float(st["spawn_t"]) > 0.0:
		return
	## Cada oleada salen mas deprisa y en grupos (por sitios distintos), y aguantan mas tiros.
	var wv2: int = int(st["wave"])
	st["spawn_t"] = lerpf(1.0, 0.45, float(st["zspeed"])) * maxf(0.5, 1.0 - 0.06 * float(wv2 - 1))
	var rng2: RandomNumberGenerator = st["rng"]
	var sp: Array = st["spawns"]
	if sp.is_empty():
		pending.clear()
		return
	var me_p: Vector2 = st["me"]["p"]
	var used: Array = []
	for g: int in (1 if wv2 < 3 else 2):
		if pending.is_empty():
			break
		## Por un sitio lejos del jugador.
		var tries: int = 0
		var c: Vector2i = sp[rng2.randi_range(0, sp.size() - 1)]
		while (center(c).distance_to(me_p) < 5.0 or used.has(c)) and tries < 10:
			c = sp[rng2.randi_range(0, sp.size() - 1)]
			tries += 1
		used.append(c)
		var kind2: String = pending.pop_front()
		var kd: Dictionary = st["kinds"][kind2]
		var spd: float = float(kd["speed"]) * (0.85 + 0.35 * float(st["zspeed"]))
		var hp: float = float(kd["hp"]) * (1.0 + 0.1 * float(wv2 - 1))
		(st["zombies"] as Array).append({"id": int(st["zid"]), "kind": kind2, "p": center(c), "hp": hp, "max": hp,
			"speed": spd * rng2.randf_range(0.9, 1.1), "r": float(kd["r"]), "dmg": float(kd["dmg"]), "atk": 0.0, "hit_t": 0.0, "slow": 0.0,
			"dir": Vector2(0, 1), "dead_t": 0.0})
		st["zid"] = int(st["zid"]) + 1
		_ev(st, "spawn", {"kind": kind2})


## Empieza una oleada: botiquines y, en directo, vuelven los que habian caido.
static func _wave_started(st: Dictionary, wv: int) -> void:
	_ev(st, "wave", {"n": wv})
	for hl: Dictionary in st["heals"]:
		if wv > 1:
			hl["on"] = true
	var me: Dictionary = st["me"]
	if bool(me["dead"]):
		me["dead"] = false
		me["hp"] = float(me["max_hp"]) * 0.5
		me["p"] = st["start"]
		_ev(st, "respawn")


static func _zombies(st: Dictionary, dt: float) -> void:
	var me: Dictionary = st["me"]
	var flow: Dictionary = st["flow"]
	var zs: Array = st["zombies"]
	var tgs: Array = targets(st)
	for z: Dictionary in zs:
		if float(z["hp"]) <= 0.0:
			z["dead_t"] = float(z["dead_t"]) + dt
			continue
		if tgs.is_empty():
			continue
		## Al jugador vivo mas cercano.
		var tg: Dictionary = tgs[0]
		for t2: Dictionary in tgs:
			if (t2["p"] as Vector2).distance_to(z["p"]) < (tg["p"] as Vector2).distance_to(z["p"]):
				tg = t2
		var p: Vector2 = tg["p"]
		z["hit_t"] = maxf(0.0, float(z["hit_t"]) - dt)
		z["slow"] = maxf(0.0, float(z["slow"]) - dt)
		var zp: Vector2 = z["p"]
		var goal: Vector2 = p
		## Si no te ve directo, baja por el mapa de distancias.
		var zd: float = zp.distance_to(p)
		if zd > 1.0 and (zd > 6.0 or not sees(st, zp, p, 0.32)):
			var c: Vector2i = Vector2i(floori(zp.x), floori(zp.y))
			var best: Vector2i = c
			var bd: int = int(flow.get(c, 9999))
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
				var n: Vector2i = c + d
				if d.x != 0 and d.y != 0 and (not walkable(st, c.x + d.x, c.y) or not walkable(st, c.x, c.y + d.y)):
					continue
				if int(flow.get(n, 9999)) < bd:
					bd = int(flow[n])
					best = n
			goal = center(best)
		var to: Vector2 = goal - zp
		var spd: float = float(z["speed"]) * (0.4 if float(z["slow"]) > 0.0 else 1.0)
		if to.length() > 0.01:
			z["dir"] = to.normalized()
		var reach: float = R + float(z["r"]) + 0.1
		if zp.distance_to(p) > reach:
			var step_v: Vector2 = (z["dir"] as Vector2) * spd * dt
			## Se apartan entre ellos.
			for o: Dictionary in zs:
				if o != z and float(o["hp"]) > 0.0:
					var dd: Vector2 = zp - (o["p"] as Vector2)
					var minr: float = float(z["r"]) + float(o["r"])
					if dd.length() < minr and dd.length() > 0.001:
						step_v += dd.normalized() * (minr - dd.length()) * 0.5
			for axis: int in 2:
				var np: Vector2 = zp
				np[axis] += step_v[axis]
				if _free(st, np, minf(0.3, float(z["r"]) * 0.8)):
					zp = np
			## Si se queda atascado contra una esquina, vuelve al centro de su casilla.
			if zp.distance_to(z["p"]) < spd * dt * 0.2:
				z["stuck"] = float(z.get("stuck", 0.0)) + dt
				if float(z["stuck"]) > 0.6:
					zp = zp.move_toward(center(Vector2i(floori(zp.x), floori(zp.y))), spd * dt)
			else:
				z["stuck"] = 0.0
			z["p"] = zp
		## Mordisco.
		z["atk"] = maxf(0.0, float(z["atk"]) - dt)
		if zp.distance_to(p) <= reach + 0.05 and float(z["atk"]) <= 0.0:
			z["atk"] = 0.8
			if int(tg["nid"]) >= 0:
				## Muerde a otro jugador: se lo dice el juego a su movil.
				_ev(st, "bite", {"nid": int(tg["nid"]), "dmg": float(z["dmg"])})
				continue
			if hurt_me(st, float(z["dmg"])):
				tgs = targets(st)
				if bool(st["over"]):
					return


## Dano a tu jugador (de un zombi de este movil o de un mordisco que llega por la red).
## Devuelve true si has caido. Solo: fin de partida; en directo: esperas a la oleada siguiente.
static func hurt_me(st: Dictionary, dmg: float) -> bool:
	var me: Dictionary = st["me"]
	if bool(me["dead"]) or bool(st["over"]):
		return false
	me["hp"] = float(me["hp"]) - dmg
	st["hurt_t"] = 0.3
	_ev(st, "hurt", {"dmg": dmg})
	if float(me["hp"]) > 0.0:
		return false
	me["hp"] = 0.0
	if str(st["role"]) == "solo":
		st["over"] = true
		_ev(st, "dead")
	else:
		me["dead"] = true
		_ev(st, "down")
	return true


static func alive_count(st: Dictionary) -> int:
	if str(st["role"]) == "client":
		var c: int = int(st["net_pending"])
		for z0: Dictionary in st["zombies"]:
			if float(z0["hp"]) > 0.0:
				c += 1
		return c
	var n: int = (st["to_spawn"] as Array).size()
	for z: Dictionary in st["zombies"]:
		if float(z["hp"]) > 0.0:
			n += 1
	return n


# ------------------------------------------------------------------ en directo

const KIND_CODE: Array[String] = ["walker", "runner", "brute"]


static func setup_online(st: Dictionary, players: Array, me_index: int, host: bool) -> void:
	st["role"] = "host" if host else "client"
	st["my_nid"] = me_index
	var mates: Dictionary = {}
	for k: int in players.size():
		if k == me_index:
			continue
		## Cada uno empieza a un lado de la salida.
		mates[k] = {"nid": k, "alias": str(players[k]), "p": (st["start"] as Vector2) + Vector2(0.6 * (float(k) - 1.5), 0.0), "yaw": 0.0, "hp": 100.0, "alive": true,
			"w": str(st["slots"]["start"]), "t": 0.0, "shot_t": 0.0, "gone": false}
	st["mates"] = mates
	st["me"]["p"] = (st["start"] as Vector2) + Vector2(0.6 * (float(me_index) - 1.5), 0.0)


static func net_pack_me(st: Dictionary) -> Array:
	var me: Dictionary = st["me"]
	var p: Vector2 = me["p"]
	return [int(st["my_nid"]), snappedf(p.x, 0.01), snappedf(p.y, 0.01), snappedf(float(st["yaw"]), 0.01), int(me["hp"]),
		0 if bool(me["dead"]) else 1, str(me["weapon"]), int(st["kills"])]


static func net_apply_mate(st: Dictionary, v: Array) -> void:
	if v.size() < 7:
		return
	var nid: int = int(v[0])
	var mates: Dictionary = st["mates"]
	if nid == int(st["my_nid"]) or not mates.has(nid):
		return
	var m: Dictionary = mates[nid]
	m["np"] = Vector2(float(v[1]), float(v[2]))
	if not m.has("p_set"):
		m["p"] = m["np"]
		m["p_set"] = true
	m["yaw"] = float(v[3])
	m["hp"] = float(v[4])
	m["alive"] = int(v[5]) == 1
	m["w"] = str(v[6])
	m["kills"] = int(v[7]) if v.size() > 7 else 0
	m["t"] = float(st["t"])
	m["gone"] = false


## Lo que manda el anfitrion: oleada, cuantos faltan por salir y los zombis.
static func net_snapshot(st: Dictionary) -> Dictionary:
	var zl: Array = []
	for z: Dictionary in st["zombies"]:
		if float(z["hp"]) > 0.0 or float(z["dead_t"]) < 2.0:
			zl.append([int(z["id"]), KIND_CODE.find(str(z["kind"])), snappedf((z["p"] as Vector2).x, 0.01), snappedf((z["p"] as Vector2).y, 0.01), int(ceilf(float(z["hp"]))), int(z["max"])])
	return {"w": int(st["wave"]), "n": (st["to_spawn"] as Array).size() if str(st["role"]) != "client" else int(st["net_pending"]), "z": zl}


static func net_apply_snap(st: Dictionary, d: Dictionary) -> void:
	var wv: int = int(d.get("w", 0))
	if wv > int(st["wave"]):
		st["wave"] = wv
		_wave_started(st, wv)
	st["net_pending"] = int(d.get("n", 0))
	st["host_t"] = float(st["t"])
	var old: Dictionary = {}
	for z: Dictionary in st["zombies"]:
		old[int(z["id"])] = z
	var out: Array = []
	for v: Variant in d.get("z", []):
		if not (v is Array) or (v as Array).size() < 6:
			continue
		var a: Array = v
		var id: int = int(a[0])
		var np: Vector2 = Vector2(float(a[2]), float(a[3]))
		var z: Dictionary
		if old.has(id):
			z = old[id]
			## Si lo has matado tu y el anfitrion aun no lo sabe, sigue muerto.
			z["hp"] = minf(float(z["hp"]), float(a[4]))
		else:
			var kind: String = KIND_CODE[clampi(int(a[1]), 0, 2)]
			var kd: Dictionary = st["kinds"][kind]
			z = {"id": id, "kind": kind, "p": np, "hp": float(a[4]), "max": float(a[5]), "speed": float(kd["speed"]), "r": float(kd["r"]),
				"dmg": float(kd["dmg"]), "atk": 0.0, "hit_t": 0.0, "slow": 0.0, "dir": Vector2(0, 1), "dead_t": 0.0}
		z["np"] = np
		out.append(z)
	st["zombies"] = out


## Invitado: los zombis van hacia donde dice el anfitrion (suave).
static func _net_follow(st: Dictionary, dt: float) -> void:
	for z: Dictionary in st["zombies"]:
		if float(z["hp"]) <= 0.0:
			z["dead_t"] = float(z["dead_t"]) + dt
			continue
		z["hit_t"] = maxf(0.0, float(z["hit_t"]) - dt)
		var np: Vector2 = z.get("np", z["p"])
		var to: Vector2 = np - (z["p"] as Vector2)
		if to.length() > 0.02:
			z["dir"] = to.normalized()
		z["p"] = (z["p"] as Vector2).lerp(np, minf(1.0, dt * 8.0)) if to.length() < 3.0 else np


## Un disparo de otro jugador acierta (lo aplica el anfitrion; los demas lo ven en la foto).
static func net_hit(st: Dictionary, id: int, dmg: float) -> void:
	for z: Dictionary in st["zombies"]:
		if int(z["id"]) == id and float(z["hp"]) > 0.0:
			z["hp"] = float(z["hp"]) - clampf(dmg, 0.0, 60.0)
			z["hit_t"] = 0.12
			z["slow"] = 0.25
			if float(z["hp"]) <= 0.0:
				_ev(st, "kill_mate", {"id": id, "p": z["p"]})
			return


static func net_end(st: Dictionary, won: bool) -> void:
	if bool(st["over"]):
		return
	st["over"] = true
	st["won"] = won
	_ev(st, "win" if won else "team_lost")


## Los mudos tanto tiempo (se han ido) dejan de contar; si era el anfitrion, lo es el siguiente.
static func net_timeouts(st: Dictionary, limit: float) -> Array:
	var gone: Array = []
	for m: Variant in (st["mates"] as Dictionary).values():
		var md: Dictionary = m
		if not bool(md["gone"]) and float(st["t"]) - float(md["t"]) > limit and float(st["t"]) > limit:
			md["gone"] = true
			md["alive"] = false
			gone.append(int(md["nid"]))
	return gone


## Este movil pasa a mover los zombis (se ha ido el anfitrion): lo que faltaba por salir, a pie.
static func make_host(st: Dictionary) -> void:
	if str(st["role"]) == "host":
		return
	st["role"] = "host"
	var pending: Array = []
	for k: int in int(st["net_pending"]):
		pending.append("walker")
	st["to_spawn"] = pending
	for z: Dictionary in st["zombies"]:
		z["speed"] = float(st["kinds"][str(z["kind"])]["speed"]) * (0.85 + 0.35 * float(st["zspeed"]))
	st["flow_t"] = 0.0
	_ev(st, "new_host")


static func move_mates(st: Dictionary, dt: float) -> void:
	for m: Variant in (st["mates"] as Dictionary).values():
		var md: Dictionary = m
		if md.has("np"):
			md["p"] = (md["p"] as Vector2).lerp(md["np"], minf(1.0, dt * 10.0))


# ------------------------------------------------------------------ bot

## El bot: apunta al zombi visible mas cercano (girando como una persona) y dispara cuando lo
## tiene en la mira; se aleja si se le acercan (hacia la casilla libre mas lejana de ellos), va a
## por armas y botiquines entre oleadas.
static func bot_control(st: Dictionary, dt: float) -> Dictionary:
	var me: Dictionary = st["me"]
	var p: Vector2 = me["p"]
	var bot: Dictionary = st.get("bot", {})
	st["bot"] = bot
	var yaw: float = float(st["yaw"])
	var target: Dictionary = {}
	var td: float = INF
	var tv: float = INF
	for z: Dictionary in st["zombies"]:
		if float(z["hp"]) <= 0.0:
			continue
		var d: float = (z["p"] as Vector2).distance_to(p)
		if d > float(st["weapons"][str(me["weapon"])]["range"]) + 2.0 or not sees(st, p, z["p"], 0.12):
			continue
		## Prefiere el que tiene delante y cerca (una persona no se gira por el de atras si no se acerca).
		var to0: Vector2 = (z["p"] as Vector2) - p
		var e0: float = absf(wrapf(atan2(-to0.x, -to0.y) - yaw, -PI, PI))
		var v0: float = d + e0 * 3.0 - (4.0 if int(z["id"]) == int(bot.get("tid", -1)) else 0.0)
		if v0 < tv:
			tv = v0
			td = d
			target = z
	var fire: bool = false
	var mv: Vector2 = Vector2.ZERO
	bot["react"] = maxf(0.0, float(bot.get("react", 0.0)) - dt)
	if not target.is_empty():
		if int(target["id"]) != int(bot.get("tid", -1)):
			bot["tid"] = int(target["id"])
			bot["react"] = 0.22
		var to: Vector2 = (target["p"] as Vector2) - p
		var want: float = atan2(-to.x, -to.y)
		var err: float = wrapf(want - yaw, -PI, PI)
		yaw += clampf(err, -4.0 * dt, 4.0 * dt)
		fire = float(bot["react"]) <= 0.0 and absf(wrapf(want - yaw, -PI, PI)) < 0.04 + float(target["r"]) / maxf(td, 0.5) * 0.8 and td < float(st["weapons"][str(me["weapon"])]["range"])
	## Huir: si alguno esta cerca, alejarse por donde haya sitio.
	var nearest: float = INF
	var push: Vector2 = Vector2.ZERO
	for z2: Dictionary in st["zombies"]:
		if float(z2["hp"]) <= 0.0:
			continue
		var dz: Vector2 = p - (z2["p"] as Vector2)
		nearest = minf(nearest, dz.length())
		if dz.length() < 3.5:
			push += dz.normalized() * (3.5 - dz.length())
	var goal_dir: Vector2 = Vector2.ZERO
	if push.length() > 0.05:
		goal_dir = _escape(st, p, push.normalized())
	elif alive_count(st) == 0 or nearest > 6.0 or target.is_empty():
		## Recoger cosas.
		var want_p: Vector2 = Vector2.INF
		for pk: Dictionary in st["pickups"]:
			if not bool(pk["got"]):
				want_p = center(pk["c"])
				break
		if want_p == Vector2.INF and float(me["hp"]) < float(me["max_hp"]) * 0.7:
			for hl: Dictionary in st["heals"]:
				if bool(hl["on"]):
					want_p = center(hl["c"])
					break
		## Si no ve a ninguno, va a buscar al mas cercano.
		if want_p == Vector2.INF and target.is_empty():
			var bz: float = INF
			for z3: Dictionary in st["zombies"]:
				if float(z3["hp"]) > 0.0 and (z3["p"] as Vector2).distance_to(p) < bz:
					bz = (z3["p"] as Vector2).distance_to(p)
					want_p = z3["p"]
		if want_p != Vector2.INF:
			var nx: Vector2 = _next_step(st, p, want_p)
			goal_dir = (nx - p).normalized()
			if target.is_empty():
				yaw += clampf(wrapf(atan2(-goal_dir.x, -goal_dir.y) - yaw, -PI, PI), -3.0 * dt, 3.0 * dt)
	if goal_dir.length() > 0.1:
		## Pasar la direccion del mundo a la del mando (relativa a la mirada).
		var fwd: Vector2 = Vector2(-sin(yaw), -cos(yaw))
		var right: Vector2 = Vector2(cos(yaw), -sin(yaw))
		mv = Vector2(goal_dir.dot(right), goal_dir.dot(fwd))
	st["yaw"] = yaw
	var reload: bool = target.is_empty() and int(me["ammo"]) < int(st["weapons"][str(me["weapon"])]["mag"]) / 2
	return {"move": mv, "fire": fire, "reload": reload}


## Direccion libre para escapar (la mejor de 16 que se alejan y no chocan con un muro enseguida).
static func _escape(st: Dictionary, p: Vector2, away: Vector2) -> Vector2:
	var best: Vector2 = away
	var bv: float = -INF
	for k: int in 16:
		var d: Vector2 = Vector2.from_angle(TAU * float(k) / 16.0)
		var free: float = 0.0
		while free < 3.0 and _free(st, p + d * (free + 0.3), R):
			free += 0.3
		var danger: float = 0.0
		for z: Dictionary in st["zombies"]:
			if float(z["hp"]) > 0.0:
				var q: Vector2 = p + d * minf(free, 1.5)
				danger += 1.0 / maxf(0.3, q.distance_to(z["p"]))
		var v: float = d.dot(away) * 1.2 + free * 0.8 - danger * 3.0
		if v > bv:
			bv = v
			best = d
	return best


static func _next_step(st: Dictionary, from: Vector2, to: Vector2) -> Vector2:
	var s: Vector2i = Vector2i(floori(from.x), floori(from.y))
	var t: Vector2i = Vector2i(floori(to.x), floori(to.y))
	if s == t:
		return to
	var came: Dictionary = {s: s}
	var q: Array[Vector2i] = [s]
	var i: int = 0
	while i < q.size():
		var c: Vector2i = q[i]
		i += 1
		if c == t:
			break
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if not came.has(n) and walkable(st, n.x, n.y):
				came[n] = c
				q.append(n)
	if not came.has(t):
		return to
	var c2: Vector2i = t
	while came[c2] != s:
		c2 = came[c2]
	return center(c2)


static func bot_play(level: Dictionary, dt: float = 1.0 / 30.0, limit: float = 900.0) -> Dictionary:
	var st: Dictionary = new_state(level)
	while not bool(st["over"]) and float(st["t"]) < limit:
		step(st, bot_control(st, dt), dt)
		(st["events"] as Array).clear()
	return {"won": bool(st["won"]), "time": float(st["t"]), "hp": float(st["me"]["hp"]), "kills": int(st["kills"]), "wave": int(st["wave"])}


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var st: Dictionary = new_state(level)
	if (st["spawns"] as Array).is_empty():
		issues.append("zombie_spawns")
	var par: int = 0
	if issues.is_empty():
		var r: Dictionary = bot_play(level)
		if not bool(r["won"]) or float(r["hp"]) < float(st["me"]["max_hp"]) * 0.15:
			issues.append("zombie_too_hard")
		par = int(float(r["time"]) * 1.3) + 10
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": 0, "enemies": int(level.get("count", 6)), "enemy_problems": [], "par": par}
