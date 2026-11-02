extends RefCounted
## Carreras 3D en circuito (karts): circuito cerrado, 6 karts, vueltas, derrapes que cargan un
## turbo, placas de turbo, hierba que frena y posiciones en directo. Reglas, simulacion pura, IA
## de los rivales, bot y analizador.
## Coordenadas en metros sobre el suelo (x, y); en 3D y es la z.
## 1 - Mapa (game.json -> levels[i].map): los puntos de control del circuito, uno por fila "x,y"
##     (en orden, cerrado); "B,k" pone una placa de turbo en el punto de control k; "#semilla".
## 2 - Parametros: "laps" (vueltas, 1-5), "skill" (0-1, rivales), "need" (puesto para ganar,
##     1-3), "width" (ancho de la pista en metros), "rivals" (1-7).
## 3 - Derrape: mantener DERRAPE girando a buena velocidad; cuanto mas dura, mas turbo al soltar
##     (azul, naranja y morado).
## 4 - Objetos ("items": true por defecto): cajas en la pista; al pasar te dan un objeto segun tu
##     puesto (el primero, platanos; los de atras, turbos). Cascara: sale hacia delante siguiendo
##     la pista y busca al de delante. Platano: se queda en el suelo detras. Turbo: acelera ya.
##     Quien recibe un golpe trompea un momento (frena y pierde el turbo y el derrape).
## 4b - Plantilla de objetos (game.json o nivel -> "kart": {"items": {id: {"name", "effect", "weights":
##     [delante, en medio, detras], "dur"}}}): cada objeto hace uno de estos efectos: seek (va a
##     por el de delante), trap (se queda detras), boost (acelera) o star (acelera y nada te para
##     durante "dur" segundos). null quita uno de los de serie. Estilo "fiesta": mas objetos.
## 5 - En directo (kart_game.gd): los karts "remote" no se simulan aqui, llegan por la red
##     (net_apply); cada uno decide los golpes sobre su propio kart.

const MAX_V: float = 24.0
const ACCEL: float = 16.0
const KR: float = 0.9
const GRASS_V: float = 9.0
const DRIFT_MIN: float = 11.0
const BOOST_V: float = 8.0
const ITEM_KINDS: Array[String] = ["cascara", "platano", "turbo"]
const BOX_R: float = 1.9
const BOX_RESPAWN: float = 3.0
const HIT_R: float = 1.5
const STUN_T: float = 1.1
## Tu kart se recupera antes (los objetos no deben decidir la carrera por si solos).
const STUN_ME: float = 0.8
## Con objetos, los rivales van un pelin mas flojos (compensa los golpes que te llevas).
const ITEM_SKILL: float = 0.05
const SHELL_V: float = 34.0
const SHELL_TTL: float = 3.5
const BANANA_TTL: float = 25.0
const MAX_SHOTS: int = 40


## Objetos de serie (los de siempre): efecto y cuanto sale delante, en medio y detras.
const ITEMS: Dictionary = {"cascara": {"effect": "seek", "weights": [0.3, 0.45, 0.4]},
	"platano": {"effect": "trap", "weights": [0.6, 0.25, 0.1]}, "turbo": {"effect": "boost", "weights": [0.1, 0.3, 0.5]}}
const ITEM_PRESETS: Dictionary = {"fiesta": {"estrella": {"name": "Estrella", "effect": "star", "dur": 4.0, "weights": [0.0, 0.08, 0.2]},
	"supercascara": {"name": "Cascara triple", "effect": "seek", "count": 3, "weights": [0.05, 0.12, 0.1]}}}


## Objetos de la carrera: los de serie, el estilo y lo del juego encima.
static func item_catalog(level: Dictionary) -> Dictionary:
	var c: Dictionary = ITEMS.duplicate(true)
	var extra: Variant = level.get("kart", {})
	if not (extra is Dictionary):
		return c
	var pr: Variant = (extra as Dictionary).get("preset", "")
	for p: Variant in (pr if pr is Array else [pr]):
		if ITEM_PRESETS.has(str(p)):
			for k: String in ITEM_PRESETS[str(p)]:
				c[k] = (ITEM_PRESETS[str(p)][k] as Dictionary).duplicate(true)
	var add: Variant = (extra as Dictionary).get("items", {})
	if add is Dictionary:
		for k2: Variant in add:
			if add[k2] == null:
				c.erase(str(k2))
			elif add[k2] is Dictionary:
				var base: Dictionary = (c.get(str(k2), {}) as Dictionary).duplicate()
				base.merge(add[k2], true)
				c[str(k2)] = base
	if c.is_empty():
		c = ITEMS.duplicate(true)
	return c


## Que hace un objeto (seek, trap, boost, star).
static func effect(st: Dictionary, kind: String) -> String:
	return str((st.get("items", ITEMS) as Dictionary).get(kind, {}).get("effect", "seek" if kind == "cascara" else ("trap" if kind == "platano" else "boost")))


static func parse(level: Dictionary) -> Dictionary:
	var pts: Array[Vector2] = []
	var pads: Array[int] = []
	var seed_v: int = int(level.get("seed", 1))
	for r: Variant in level.get("map", []):
		var t: String = str(r)
		if t.begins_with("#") and t.substr(1).is_valid_int():
			seed_v = int(t.substr(1))
		elif t.begins_with("B,"):
			pads.append(int(t.substr(2)))
		elif t.contains(","):
			var parts: PackedStringArray = t.split(",")
			if parts.size() >= 2 and parts[0].is_valid_float() and parts[1].is_valid_float():
				pts.append(Vector2(float(parts[0]), float(parts[1])))
	if pts.size() < 4:
		pts = [Vector2(-40, -25), Vector2(40, -25), Vector2(55, 0), Vector2(40, 25), Vector2(-40, 25), Vector2(-55, 0)]
	return {"pts": pts, "pads": pads, "seed": seed_v}


## Linea central suave (Catmull-Rom) cada ~1,5 m, con distancia acumulada, tangente y curvatura.
static func build_track(pts: Array[Vector2]) -> Dictionary:
	var line: Array[Vector2] = []
	var owner: Array[int] = []
	var n: int = pts.size()
	for k: int in n:
		var p0: Vector2 = pts[(k - 1 + n) % n]
		var p1: Vector2 = pts[k]
		var p2: Vector2 = pts[(k + 1) % n]
		var p3: Vector2 = pts[(k + 2) % n]
		var steps: int = maxi(2, int(p1.distance_to(p2) / 1.5))
		for s: int in steps:
			var t: float = float(s) / float(steps)
			var t2: float = t * t
			var t3: float = t2 * t
			line.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
			owner.append(k)
	var m: int = line.size()
	var dist: Array[float] = []
	var tan: Array[Vector2] = []
	var curv: Array[float] = []
	var acc: float = 0.0
	for i: int in m:
		dist.append(acc)
		acc += line[i].distance_to(line[(i + 1) % m])
		tan.append((line[(i + 1) % m] - line[(i - 1 + m) % m]).normalized())
	for i2: int in m:
		var a: Vector2 = tan[(i2 - 2 + m) % m]
		var b: Vector2 = tan[(i2 + 2) % m]
		curv.append(absf(a.angle_to(b)) / maxf(0.5, line[(i2 - 2 + m) % m].distance_to(line[(i2 + 2) % m])))
	return {"line": line, "dist": dist, "tan": tan, "curv": curv, "length": acc, "owner": owner}


static func new_state(level: Dictionary) -> Dictionary:
	var info: Dictionary = parse(level)
	var tr: Dictionary = build_track(info["pts"])
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(info["seed"])
	var line: Array = tr["line"]
	var owner: Array = tr["owner"]
	var pads: Array = []
	for k: int in (info["pads"] as Array):
		for i: int in line.size():
			if int(owner[i]) == k:
				pads.append(i)
				break
	var st: Dictionary = {"track": tr, "pads": pads, "rng": rng, "t": 0.0, "go_t": 3.0, "over": false, "won": false, "events": [],
		"laps": clampi(int(level.get("laps", 3)), 1, 5), "skill": clampf(float(level.get("skill", 0.4)), 0.0, 1.0),
		"need": clampi(int(level.get("need", 1)), 1, 3), "width": clampf(float(level.get("width", 11.0)), 7.0, 18.0), "karts": [],
		"finish_order": [], "items_on": bool(level.get("items", true)), "boxes": [], "shots": [], "shot_n": 0,
		"items": item_catalog(level)}
	var nr: int = clampi(int(level.get("rivals", 5)), 1, 7)
	## Parrilla: tu kart el ultimo (hay que remontar), los rivales delante en dos filas.
	var m: int = line.size()
	for k2: int in nr + 1:
		var row: int = k2 / 2
		var back: int = (m - 3 - row * 4) % m
		var i0: int = (back + m) % m
		var side: float = -1.0 if k2 % 2 == 0 else 1.0
		var nrm: Vector2 = (tr["tan"][i0] as Vector2).orthogonal()
		var me: bool = k2 == nr
		var sk: float = 0.82 if me else clampf(float(st["skill"]) + rng.randf_range(-0.12, 0.12) - (ITEM_SKILL if bool(st["items_on"]) else 0.0), 0.0, 1.0)
		(st["karts"] as Array).append({"i": k2, "me": me, "p": (line[i0] as Vector2) + nrm * side * 2.4, "a": (tr["tan"][i0] as Vector2).angle(),
			"v": 0.0, "skill": sk, "idx": i0, "lap": 0, "prog": 0.0, "passed_half": false, "drift": 0, "drift_t": 0.0, "boost_t": 0.0,
			"done": false, "finish_t": 0.0, "lane": rng.randf_range(-0.35, 0.35), "steer": 0.0, "pad_cd": 0.0, "off": false,
			"item": "", "item_t": 0.0, "stun": 0.0, "remote": false, "sid": "", "name": "", "star_t": 0.0, "ammo": 0})
	## El jugador es el ultimo de la lista; para que "karts[0]" sea siempre el tuyo, se ordena.
	var ks: Array = st["karts"]
	var mine: Dictionary = ks.pop_back()
	ks.push_front(mine)
	for k3: int in ks.size():
		ks[k3]["i"] = k3
	## Cajas de objetos: dos filas de tres, al 30 % y al 72 % de la vuelta.
	if bool(st["items_on"]):
		var L: float = float(tr["length"])
		for frac: float in [0.3, 0.72]:
			var bi: int = 0
			for i3: int in m:
				if float(tr["dist"][i3]) >= L * frac:
					bi = i3
					break
			for side2: float in [-0.32, 0.0, 0.32]:
				(st["boxes"] as Array).append({"i": bi, "side": side2, "cd": 0.0,
					"p": (line[bi] as Vector2) + (tr["tan"][bi] as Vector2).orthogonal() * side2 * float(st["width"])})
	_progress_all(st)
	return st


static func _ev(st: Dictionary, kind: String, extra: Dictionary = {}) -> void:
	var e: Dictionary = {"kind": kind}
	e.merge(extra)
	(st["events"] as Array).append(e)


## Punto de la linea mas cercano (buscando cerca del ultimo conocido).
static func nearest(st: Dictionary, p: Vector2, hint: int) -> int:
	var line: Array = st["track"]["line"]
	var m: int = line.size()
	var best: int = hint
	var bd: float = INF
	for d: int in range(-12, 25):
		var i: int = (hint + d + m) % m
		var dd: float = (line[i] as Vector2).distance_squared_to(p)
		if dd < bd:
			bd = dd
			best = i
	return best


static func off_center(st: Dictionary, k: Dictionary) -> float:
	var tr: Dictionary = st["track"]
	var i: int = int(k["idx"])
	var nrm: Vector2 = (tr["tan"][i] as Vector2).orthogonal()
	return ((k["p"] as Vector2) - (tr["line"][i] as Vector2)).dot(nrm)


# ------------------------------------------------------------------ paso

## inp (tu kart): {"steer": -1..1, "drift": bool (mantener), "gas": 0..1 (1 por defecto)}.
static func step(st: Dictionary, inp: Dictionary, dt: float) -> void:
	if bool(st["over"]):
		return
	st["t"] = float(st["t"]) + dt
	if float(st["go_t"]) > 0.0:
		var before: int = ceili(float(st["go_t"]))
		st["go_t"] = float(st["go_t"]) - dt
		if ceili(float(st["go_t"])) != before:
			_ev(st, "count", {"n": maxi(0, ceili(float(st["go_t"])))})
		return
	for k: Dictionary in st["karts"]:
		if bool(k["remote"]):
			continue
		var c: Dictionary
		var human: bool = bool(k["me"]) and not inp.is_empty()
		if human:
			c = inp
		else:
			c = ai_control(st, k)
		if bool(st["items_on"]) and str(k["item"]) != "" and not bool(k["done"]) and float(k["stun"]) <= 0.0:
			k["item_t"] = float(k["item_t"]) + dt
			if (bool(c.get("use", false)) if human else ai_item(st, k)):
				use_item(st, k)
		_drive(st, k, c, dt)
	_collide(st)
	if bool(st["items_on"]):
		_boxes(st, dt)
		_shots(st, dt)
	_progress_all(st)


static func _drive(st: Dictionary, k: Dictionary, c: Dictionary, dt: float) -> void:
	var tr: Dictionary = st["track"]
	var steer: float = clampf(float(c.get("steer", 0.0)), -1.0, 1.0)
	var gas: float = clampf(float(c.get("gas", 1.0)), -0.6, 1.0)
	var want_drift: bool = bool(c.get("drift", false))
	if bool(k["done"]):
		gas = 0.3
		want_drift = false
	var v: float = float(k["v"])
	## Trompo tras un golpe: sin mando, sin turbo ni derrape, frenando.
	if float(k["stun"]) > 0.0:
		k["stun"] = maxf(0.0, float(k["stun"]) - dt)
		k["drift"] = 0
		k["drift_t"] = 0.0
		k["boost_t"] = 0.0
		k["steer"] = 0.0
		v = move_toward(v, 0.0, 30.0 * dt)
		k["v"] = v
		var p0: Vector2 = (k["p"] as Vector2) + Vector2.from_angle(float(k["a"])) * v * dt
		k["p"] = p0
		k["idx"] = nearest(st, p0, int(k["idx"]))
		return
	k["steer"] = lerpf(float(k["steer"]), steer, minf(1.0, dt * 10.0))
	var off: bool = absf(off_center(st, k)) > float(st["width"]) * 0.5 + 0.6
	k["off"] = off
	var top: float = MAX_V * (0.86 + 0.14 * float(k["skill"])) if not bool(k["me"]) else MAX_V
	if off:
		top = GRASS_V
	k["boost_t"] = maxf(0.0, float(k["boost_t"]) - dt)
	k["star_t"] = maxf(0.0, float(k.get("star_t", 0.0)) - dt)
	if float(k["star_t"]) > 0.0:
		k["boost_t"] = maxf(float(k["boost_t"]), 0.1)
		if off:
			top = MAX_V
	if float(k["boost_t"]) > 0.0:
		top += BOOST_V
		v = maxf(v, top - 2.0)
	## Placas de turbo.
	k["pad_cd"] = maxf(0.0, float(k["pad_cd"]) - dt)
	for pi: int in (st["pads"] as Array):
		if float(k["pad_cd"]) <= 0.0 and (k["p"] as Vector2).distance_to(tr["line"][pi]) < 3.2:
			k["boost_t"] = 1.2
			k["pad_cd"] = 1.5
			_ev(st, "pad", {"i": int(k["i"])})
	if gas >= 0.0:
		v = move_toward(v, top * gas, (ACCEL if v < top else 22.0) * dt)
	else:
		v = move_toward(v, -6.0, 30.0 * dt)
	## Derrape: gira mas cerrado, se carga el turbo; al soltar, turbo segun lo cargado.
	var drifting: bool = int(k["drift"]) != 0
	if want_drift and not drifting and v > DRIFT_MIN and absf(steer) > 0.3:
		k["drift"] = 1 if steer > 0.0 else -1
		k["drift_t"] = 0.0
		_ev(st, "drift", {"i": int(k["i"])})
	elif drifting and (not want_drift or v < DRIFT_MIN * 0.7 or off):
		var lvl: int = drift_level(k)
		if lvl > 0 and not off:
			k["boost_t"] = [0.0, 0.7, 1.2, 1.8][lvl]
			_ev(st, "mini_turbo", {"i": int(k["i"]), "level": lvl})
		k["drift"] = 0
		k["drift_t"] = 0.0
	var turn: float = float(k["steer"])
	if int(k["drift"]) != 0:
		k["drift_t"] = float(k["drift_t"]) + dt
		## Dentro del derrape el mando abre o cierra, pero siempre hacia su lado.
		turn = float(k["drift"]) * (0.75 + 0.55 * turn * float(k["drift"]))
		v *= 1.0 - 0.08 * dt
	var grip: float = clampf(v / 6.0, 0.0, 1.0) * (1.0 - clampf((v - 18.0) / 30.0, 0.0, 0.35))
	var rate: float = (2.3 if int(k["drift"]) == 0 else 2.9) * grip
	k["a"] = float(k["a"]) + turn * rate * dt * (1.0 if v >= 0.0 else -1.0)
	var dir: Vector2 = Vector2.from_angle(float(k["a"]))
	var p: Vector2 = (k["p"] as Vector2) + dir * v * dt
	## Valla: no se sale de la pista mas alla de la hierba.
	k["p"] = p
	k["idx"] = nearest(st, p, int(k["idx"]))
	var oc: float = off_center(st, k)
	var lim: float = float(st["width"]) * 0.5 + 4.0
	if absf(oc) > lim:
		var i: int = int(k["idx"])
		var nrm: Vector2 = (tr["tan"][i] as Vector2).orthogonal()
		k["p"] = (tr["line"][i] as Vector2) + nrm * signf(oc) * lim
		v *= 0.6
		if not bool(k.get("hit_wall", false)):
			_ev(st, "wall", {"i": int(k["i"])})
		k["hit_wall"] = true
	else:
		k["hit_wall"] = false
	k["v"] = v


static func drift_level(k: Dictionary) -> int:
	var t: float = float(k["drift_t"])
	return 3 if t > 1.9 else (2 if t > 1.1 else (1 if t > 0.5 else 0))


static func _collide(st: Dictionary) -> void:
	var ks: Array = st["karts"]
	for a: int in ks.size():
		for b: int in range(a + 1, ks.size()):
			var d: Vector2 = (ks[a]["p"] as Vector2) - (ks[b]["p"] as Vector2)
			var l: float = d.length()
			if l < KR * 2.0 and l > 0.001:
				var ra: bool = bool(ks[a]["remote"])
				var rb: bool = bool(ks[b]["remote"])
				if ra and rb:
					continue
				## Contra un kart de la red solo se aparta el propio (el otro lo mueve su dueno).
				var share: float = 1.0 if ra or rb else 0.5
				var push: Vector2 = d / l * (KR * 2.0 - l) * share
				var va: float = float(ks[a]["v"])
				var vb: float = float(ks[b]["v"])
				if not ra:
					ks[a]["p"] = (ks[a]["p"] as Vector2) + push
					ks[a]["v"] = lerpf(va, vb, 0.3)
				if not rb:
					ks[b]["p"] = (ks[b]["p"] as Vector2) - push
					ks[b]["v"] = lerpf(vb, va, 0.3)
				if l < KR * 1.6:
					_ev(st, "bump", {"a": a, "b": b})


## Vueltas y posiciones: la vuelta cuenta al cruzar la meta habiendo pasado por la mitad.
static func _progress_all(st: Dictionary) -> void:
	var tr: Dictionary = st["track"]
	var L: float = float(tr["length"])
	for k: Dictionary in st["karts"]:
		if bool(k["remote"]):
			continue
		var d: float = float(tr["dist"][int(k["idx"])])
		var prev: float = float(k["prog"])
		if d > L * 0.4 and d < L * 0.6:
			k["passed_half"] = true
		if prev > L * 0.8 and d < L * 0.2 and bool(k["passed_half"]):
			k["lap"] = int(k["lap"]) + 1
			k["passed_half"] = false
			if not bool(k["done"]):
				if int(k["lap"]) >= int(st["laps"]):
					k["done"] = true
					k["finish_t"] = float(st["t"])
					(st["finish_order"] as Array).append(int(k["i"]))
					_ev(st, "finish", {"i": int(k["i"]), "pos": (st["finish_order"] as Array).size()})
					if bool(k["me"]):
						var pos: int = (st["finish_order"] as Array).size()
						## En directo la carrera sigue (ves llegar a los demas y el anfitrion mueve los bots).
						st["over"] = not bool(st.get("keep_running", false))
						st["ended"] = true
						st["won"] = pos <= int(st["need"])
						st["place"] = pos
						_ev(st, "end", {"pos": pos})
				elif bool(k["me"]):
					_ev(st, "lap", {"n": int(k["lap"]) + 1})
		k["prog"] = d
	## Si la carrera se alarga demasiado (te has quedado atascado), acaba con tu puesto actual.
	if float(st["t"]) > 60.0 + float(int(st["laps"])) * L / 6.0 and not bool(st.get("ended", false)):
		st["over"] = not bool(st.get("keep_running", false))
		st["ended"] = true
		st["place"] = position(st, 0)
		st["won"] = false
		_ev(st, "end", {"pos": int(st["place"])})


static func race_dist(st: Dictionary, k: Dictionary) -> float:
	var L: float = float(st["track"]["length"])
	var d: float = float(k["prog"])
	## Antes de cruzar la meta la primera vez (parrilla detras de la linea) cuenta como negativo.
	var lap: int = int(k["lap"])
	if lap == 0 and d > L * 0.8 and not bool(k["passed_half"]):
		d -= L
	return float(lap) * L + d


static func position(st: Dictionary, i: int) -> int:
	var ks: Array = st["karts"]
	var me: Dictionary = ks[i]
	if bool(me["done"]):
		return (st["finish_order"] as Array).find(i) + 1
	var pos: int = 1 + (st["finish_order"] as Array).size()
	var md: float = race_dist(st, me)
	for k: Dictionary in ks:
		if k != me and not bool(k["done"]) and race_dist(st, k) > md:
			pos += 1
	return pos


# ------------------------------------------------------------------ IA

## Piloto: mira un punto por delante (mas lejos cuanto mas rapido), frena antes de las curvas
## cerradas y derrapa en las largas. "lane" le da su linea (no van todos en fila).
static func ai_control(st: Dictionary, k: Dictionary) -> Dictionary:
	var tr: Dictionary = st["track"]
	var line: Array = tr["line"]
	var m: int = line.size()
	var i: int = int(k["idx"])
	var v: float = float(k["v"])
	var sk: float = float(k["skill"])
	var ahead: int = 3 + int(v * 0.25)
	var j: int = (i + ahead) % m
	var nrm: Vector2 = (tr["tan"][j] as Vector2).orthogonal()
	var w: float = float(st["width"])
	## En la curva, por el interior (como haria un buen piloto).
	var bend: float = (tr["tan"][i] as Vector2).angle_to(tr["tan"][(i + 14) % m])
	var lane: float = float(k["lane"]) * (1.0 - sk * 0.5) - signf(bend) * clampf(absf(bend) * 0.4, 0.0, 0.15) * sk
	## Cerca del borde, la mira vuelve hacia el centro (al cortar la curva el kart se mete por dentro).
	var oc: float = off_center(st, k) / (w * 0.5)
	if absf(oc) > 0.6:
		lane = -signf(oc) * 0.3
	lane = clampf(lane, -0.55, 0.55)
	var target: Vector2 = (line[j] as Vector2) + nrm * lane * w * 0.5
	## Platanos por delante en su linea: se aparta hacia el otro lado (mejor cuanto mas sabe).
	var fdir: Vector2 = Vector2.from_angle(float(k["a"]))
	for s: Dictionary in st.get("shots", []):
		if effect(st, str(s["kind"])) != "trap":
			continue
		var rel: Vector2 = (s["p"] as Vector2) - (k["p"] as Vector2)
		var fwd: float = rel.dot(fdir)
		if fwd > 0.5 and fwd < 6.0 + float(k["v"]) * 0.9:
			var lat: float = rel.dot(fdir.orthogonal())
			if absf(lat) < 2.8:
				var away: float = -signf(lat) if absf(lat) > 0.05 else (1.0 if float(k["lane"]) >= 0.0 else -1.0)
				target += fdir.orthogonal() * away * (4.5 - absf(lat)) * (0.6 + 0.8 * sk)
	var to: Vector2 = target - (k["p"] as Vector2)
	var err: float = wrapf(to.angle() - float(k["a"]), -PI, PI)
	var steer: float = clampf(err * 2.4, -1.0, 1.0)
	## Velocidad segun lo cerrada que viene la curva.
	var worst: float = 0.0
	for d: int in range(4, 4 + int(v * 0.9)):
		worst = maxf(worst, float(tr["curv"][(i + d) % m]))
	## Con el giro maximo el kart traza un radio de v / 1,8 m: la curva marca la velocidad.
	var safe: float = clampf(1.8 / maxf(worst, 0.001) * (0.8 + 0.25 * sk), 8.0, MAX_V + 4.0)
	var gas: float = 1.0 if v < safe else (0.0 if v < safe + 3.0 else -0.4)
	var drift: bool = false
	var near_bend: float = (tr["tan"][i] as Vector2).angle_to(tr["tan"][(i + 8) % m])
	var long_bend: float = (tr["tan"][i] as Vector2).angle_to(tr["tan"][(i + 26) % m])
	if int(k["drift"]) != 0:
		## Sigue derrapando mientras la curva dure (y suelta para coger el turbo al salir).
		drift = (signf(near_bend) == float(k["drift"]) and absf(near_bend) > 0.12 and absf(err) < 1.2) or float(k["drift_t"]) < 0.6
		## Si se va hacia el borde, suelta el derrape.
		if absf(off_center(st, k)) > w * 0.38:
			drift = false
		steer = clampf(err * 2.0, -1.0, 1.0)
	elif absf(long_bend) > 0.9 and absf(near_bend) > 0.3 and signf(near_bend) == signf(long_bend) and v > DRIFT_MIN + 2.0 and (st["rng"] as RandomNumberGenerator).randf() < 0.1 + 0.4 * sk:
		drift = true
		steer = signf(long_bend)
	## Si se ha ido a la hierba o esta casi parado, vuelve hacia el centro.
	if bool(k["off"]):
		var back: Vector2 = (line[(i + 3) % m] as Vector2) - (k["p"] as Vector2)
		steer = clampf(wrapf(back.angle() - float(k["a"]), -PI, PI) * 2.5, -1.0, 1.0)
	## Rivales: un pelin de goma (los de atras aprietan un poco, los de delante no se escapan).
	if not bool(k["me"]):
		var me: Dictionary = st["karts"][0]
		var gap: float = race_dist(st, k) - race_dist(st, me)
		if gap > 40.0:
			gas = minf(gas, 0.9)
	return {"steer": steer, "gas": gas, "drift": drift}


# ------------------------------------------------------------------ objetos

## Objeto segun el puesto (pesos de cada objeto: delante, en medio, detras). Con los de serie:
## delante, sobre todo platanos; atras, turbos y cascaras.
static func roll_item(st: Dictionary, k: Dictionary) -> String:
	var n: int = (st["karts"] as Array).size()
	var pos: int = position(st, int(k["i"]))
	var r: float = (st["rng"] as RandomNumberGenerator).randf()
	var col: int = 0 if pos == 1 else (2 if pos > n - maxi(1, n / 3) else 1)
	var cat: Dictionary = st.get("items", ITEMS)
	var total: float = 0.0
	for id: String in cat:
		total += float((cat[id].get("weights", [1.0, 1.0, 1.0]) as Array)[col])
	if total <= 0.0:
		return str(cat.keys()[0])
	var acc: float = 0.0
	for id2: String in cat:
		acc += float((cat[id2].get("weights", [1.0, 1.0, 1.0]) as Array)[col]) / total
		if r < acc:
			return id2
	return str(cat.keys()[cat.size() - 1])


static func _boxes(st: Dictionary, dt: float) -> void:
	for b: Dictionary in st["boxes"]:
		if float(b["cd"]) > 0.0:
			b["cd"] = maxf(0.0, float(b["cd"]) - dt)
			continue
		for k: Dictionary in st["karts"]:
			if bool(k["remote"]) or bool(k["done"]):
				continue
			if (k["p"] as Vector2).distance_to(b["p"]) < BOX_R:
				b["cd"] = BOX_RESPAWN
				if str(k["item"]) == "":
					k["item"] = roll_item(st, k)
					k["item_t"] = 0.0
					_ev(st, "item_get", {"i": int(k["i"]), "item": str(k["item"])})
				break


## Usa el objeto que lleva. Devuelve el disparo creado (vacio con el turbo).
static func use_item(st: Dictionary, k: Dictionary) -> Dictionary:
	var kind: String = str(k["item"])
	if kind == "":
		return {}
	var fx: String = effect(st, kind)
	## Objetos con varias cargas (cascara triple): se gastan de una en una.
	var count: int = int((st.get("items", ITEMS) as Dictionary).get(kind, {}).get("count", 1))
	if count > 1 and int(k.get("ammo", 0)) <= 0:
		k["ammo"] = count
	k["ammo"] = maxi(0, int(k.get("ammo", 0)) - 1)
	if int(k["ammo"]) <= 0:
		k["item"] = ""
	k["item_t"] = 0.0
	if fx == "boost":
		k["boost_t"] = maxf(float(k["boost_t"]), float((st.get("items", ITEMS) as Dictionary).get(kind, {}).get("dur", 1.6)))
		_ev(st, "item_use", {"i": int(k["i"]), "item": kind})
		return {}
	if fx == "star":
		k["star_t"] = float((st.get("items", ITEMS) as Dictionary).get(kind, {}).get("dur", 4.0))
		_ev(st, "item_use", {"i": int(k["i"]), "item": kind})
		return {}
	var dir: Vector2 = Vector2.from_angle(float(k["a"]))
	var n: int = int(st["shot_n"]) + 1
	st["shot_n"] = n
	var shot: Dictionary
	if fx == "seek":
		shot = {"kind": kind, "p": (k["p"] as Vector2) + dir * 2.2, "d": dir, "v": maxf(SHELL_V, float(k["v"]) + 12.0), "ttl": SHELL_TTL}
	else:
		shot = {"kind": kind, "p": (k["p"] as Vector2) - dir * 2.0, "d": dir, "v": 0.0, "ttl": BANANA_TTL}
	## En directo el id lleva la sesion del dueno (el mismo en todos los moviles).
	shot["id"] = ("%s:%d" % [str(k["sid"]), n]) if str(k["sid"]) != "" else ("%d:%d" % [int(k["i"]), n])
	shot["n"] = n
	shot["owner"] = int(k["i"])
	shot["age"] = 0.0
	shot["idx"] = int(k["idx"])
	add_shot(st, shot)
	_ev(st, "item_use", {"i": int(k["i"]), "item": kind, "shot": shot})
	return shot


static func add_shot(st: Dictionary, shot: Dictionary) -> void:
	var shots: Array = st["shots"]
	for s: Dictionary in shots:
		if str(s["id"]) == str(shot["id"]):
			return
	shots.append(shot)
	while shots.size() > MAX_SHOTS:
		shots.pop_front()


static func remove_shot(st: Dictionary, id: String) -> bool:
	var shots: Array = st["shots"]
	for j: int in shots.size():
		if str(shots[j]["id"]) == id:
			shots.remove_at(j)
			return true
	return false


## Cascaras: siguen la pista y, si hay un kart cerca por delante, van a por el. Platanos: quietos.
## Solo se golpea a los karts propios (los de la red los decide su dueno).
static func _shots(st: Dictionary, dt: float) -> void:
	var tr: Dictionary = st["track"]
	var line: Array = tr["line"]
	var m: int = line.size()
	var ks: Array = st["karts"]
	var gone: Array[String] = []
	for s: Dictionary in st["shots"]:
		s["ttl"] = float(s["ttl"]) - dt
		s["age"] = float(s["age"]) + dt
		if float(s["ttl"]) <= 0.0:
			gone.append(str(s["id"]))
			continue
		if effect(st, str(s["kind"])) == "seek":
			var i: int = nearest(st, s["p"], int(s["idx"]))
			s["idx"] = i
			var want: Vector2 = ((line[(i + 6) % m] as Vector2) - (s["p"] as Vector2)).normalized()
			var best: float = 22.0
			for k: Dictionary in ks:
				if int(k["i"]) == int(s["owner"]) or bool(k["done"]):
					continue
				var to: Vector2 = (k["p"] as Vector2) - (s["p"] as Vector2)
				var dist: float = to.length()
				if dist < best and absf((s["d"] as Vector2).angle_to(to)) < 0.8:
					best = dist
					want = to / maxf(dist, 0.001)
			s["d"] = ((s["d"] as Vector2).lerp(want, minf(1.0, dt * 6.0))).normalized()
			s["p"] = (s["p"] as Vector2) + (s["d"] as Vector2) * float(s["v"]) * dt
		for k2: Dictionary in ks:
			if bool(k2["remote"]) or bool(k2["done"]):
				continue
			## El que lo suelta no se lo come nada mas soltarlo.
			if int(k2["i"]) == int(s["owner"]) and float(s["age"]) < 0.6:
				continue
			if (k2["p"] as Vector2).distance_to(s["p"]) < HIT_R:
				hit(st, k2, str(s["kind"]), str(s["id"]))
				gone.append(str(s["id"]))
				break
	for id: String in gone:
		remove_shot(st, id)


static func hit(st: Dictionary, k: Dictionary, kind: String, id: String = "") -> void:
	## Con la estrella nada te para.
	if float(k.get("star_t", 0.0)) > 0.0:
		_ev(st, "block", {"i": int(k["i"]), "id": id})
		return
	## Escudo: un platano o una cascara sin usar paran una cascara (se rompe el objeto).
	if effect(st, kind) == "seek" and str(k["item"]) != "" and effect(st, str(k["item"])) in ["trap", "seek"]:
		k["item"] = ""
		k["item_t"] = 0.0
		_ev(st, "block", {"i": int(k["i"]), "id": id})
		return
	k["stun"] = STUN_ME if bool(k["me"]) else STUN_T
	k["drift"] = 0
	k["drift_t"] = 0.0
	k["boost_t"] = 0.0
	_ev(st, "hit", {"i": int(k["i"]), "item": kind, "id": id})


## Cuando usa el objeto un piloto de la maquina (rivales y bot).
static func ai_item(st: Dictionary, k: Dictionary) -> bool:
	var kind: String = str(k["item"])
	var held: float = float(k["item_t"])
	## Los rivales flojos tardan mas en usarlo (y a veces se lo comen con el tiempo).
	var wait: float = 0.4 if bool(k["me"]) else 0.4 + (1.0 - float(k["skill"])) * 1.5
	if held < wait:
		return false
	var fx: String = effect(st, kind)
	var leader: bool = fx == "trap" and position(st, int(k["i"])) == 1
	if held > (25.0 if leader else 7.0):
		return true
	var tr: Dictionary = st["track"]
	var m: int = (tr["line"] as Array).size()
	var i: int = int(k["idx"])
	match fx:
		"star":
			return true
		"boost":
			var bend: float = absf((tr["tan"][i] as Vector2).angle_to(tr["tan"][(i + 20) % m]))
			return bend < 0.35 and not bool(k["off"])
		"seek":
			var me_d: float = race_dist(st, k)
			for o: Dictionary in st["karts"]:
				if o == k or bool(o["done"]):
					continue
				var gap: float = race_dist(st, o) - me_d
				if gap > 3.0 and gap < 28.0:
					return true
		"trap":
			## En cabeza se guarda de escudo (para las cascaras de los de atras).
			if leader:
				return false
			var me_d2: float = race_dist(st, k)
			for o2: Dictionary in st["karts"]:
				if o2 == k or bool(o2["done"]):
					continue
				var gap2: float = me_d2 - race_dist(st, o2)
				if gap2 > 6.0 and gap2 < 16.0:
					return true
	return false


# ------------------------------------------------------------------ en directo

## Parrilla comun para todos los moviles: los bots delante ("bot0", "bot1"...) y las personas
## detras por orden de sala. players: [{"sesion", "alias"}] ya ordenados por puesto en la sala.
## En cada movil el kart 0 es el suyo; los demas pilotos son "remote" y los bots solo los mueve
## el anfitrion (en los demas tambien son "remote").
static func setup_online(st: Dictionary, players: Array, my_sid: String, is_host: bool) -> void:
	var ks: Array = st["karts"]
	var n: int = ks.size()
	var h: int = mini(players.size(), n)
	## Puestos de salida tal y como los hizo new_state (el kart 0 era el ultimo de la parrilla).
	var grid: Array = []
	for g: int in n:
		var src: Dictionary = ks[g + 1] if g < n - 1 else ks[0]
		grid.append({"p": src["p"], "a": src["a"], "idx": src["idx"], "lane": src["lane"], "skill": src["skill"]})
	var mine: int = 0
	for j: int in h:
		if str((players[j] as Dictionary).get("sesion", "")) == my_sid:
			mine = j
	## Orden en este movil: tu, los demas pilotos y los bots.
	var order: Array = [{"g": n - h + mine, "sid": my_sid, "name": str((players[mine] as Dictionary).get("alias", "")), "human": true, "me": true}]
	for j2: int in h:
		if j2 != mine:
			order.append({"g": n - h + j2, "sid": str((players[j2] as Dictionary).get("sesion", "")), "name": str((players[j2] as Dictionary).get("alias", "")), "human": true, "me": false})
	for b: int in n - h:
		order.append({"g": b, "sid": "bot%d" % b, "name": "", "human": false, "me": false})
	for i: int in n:
		var k: Dictionary = ks[i]
		var o: Dictionary = order[i]
		var gd: Dictionary = grid[int(o["g"])]
		k["i"] = i
		k["p"] = gd["p"]
		k["a"] = gd["a"]
		k["idx"] = gd["idx"]
		k["lane"] = gd["lane"]
		k["skill"] = 0.82 if bool(o["human"]) else float(gd["skill"])
		k["sid"] = o["sid"]
		k["name"] = o["name"]
		k["me"] = bool(o["me"])
		k["human"] = bool(o["human"])
		k["remote"] = (bool(o["human"]) and not bool(o["me"])) or (not bool(o["human"]) and not is_host)
		k["prog"] = 0.0
		k["passed_half"] = false
	st["online"] = true
	st["keep_running"] = true
	st["host"] = is_host
	_progress_all(st)


## El anfitrion se ha ido: este movil pasa a mover los bots desde donde estaban.
static func make_host(st: Dictionary) -> void:
	st["host"] = true
	for k: Dictionary in st["karts"]:
		if not bool(k.get("human", true)):
			k["remote"] = false
			k.erase("net_p")


static func kart_by_sid(st: Dictionary, sid: String) -> Dictionary:
	for k: Dictionary in st["karts"]:
		if str(k["sid"]) == sid:
			return k
	return {}


## Tu puesto entre las personas de la sala (lo que se anota en el servidor: 1-4).
static func human_place(st: Dictionary) -> int:
	var me: Dictionary = st["karts"][0]
	var fo: Array = st["finish_order"]
	var place: int = 1
	for k: Dictionary in st["karts"]:
		if k == me or not bool(k.get("human", false)):
			continue
		if bool(me["done"]):
			if bool(k["done"]) and fo.find(int(k["i"])) < fo.find(0):
				place += 1
		elif bool(k["done"]) or race_dist(st, k) > race_dist(st, me):
			place += 1
	return place

## Lo que se manda de un kart propio (corto: va 10 veces por segundo).
static func net_state(k: Dictionary) -> Dictionary:
	var p: Vector2 = k["p"]
	return {"p": [snappedf(p.x, 0.01), snappedf(p.y, 0.01)], "a": snappedf(float(k["a"]), 0.001), "v": snappedf(float(k["v"]), 0.01),
		"d": int(k["drift"]), "dt": snappedf(float(k["drift_t"]), 0.01), "b": snappedf(float(k["boost_t"]), 0.01),
		"s": snappedf(float(k["stun"]), 0.01), "st": snappedf(float(k["steer"]), 0.01), "l": int(k["lap"]), "pr": snappedf(float(k["prog"]), 0.1),
		"h": bool(k["passed_half"]), "i": int(k["idx"]), "dn": bool(k["done"]), "ft": snappedf(float(k["finish_t"]), 0.01), "o": bool(k["off"])}


## Aplica lo recibido de un kart de la red. La posicion queda en "net_p" (el juego la suaviza).
static func net_apply(st: Dictionary, k: Dictionary, s: Dictionary) -> void:
	var p: Array = s.get("p", [0.0, 0.0])
	k["net_p"] = Vector2(float(p[0]), float(p[1]))
	if not k.has("net_seen"):
		k["p"] = k["net_p"]
		k["a"] = float(s.get("a", k["a"]))
	k["net_seen"] = float(st["t"])
	k["net_a"] = float(s.get("a", k["a"]))
	k["v"] = float(s.get("v", 0.0))
	k["drift"] = int(s.get("d", 0))
	k["drift_t"] = float(s.get("dt", 0.0))
	k["boost_t"] = float(s.get("b", 0.0))
	k["stun"] = float(s.get("s", 0.0))
	k["steer"] = float(s.get("st", 0.0))
	k["lap"] = int(s.get("l", 0))
	k["prog"] = float(s.get("pr", 0.0))
	k["passed_half"] = bool(s.get("h", false))
	k["idx"] = clampi(int(s.get("i", 0)), 0, (st["track"]["line"] as Array).size() - 1)
	k["off"] = bool(s.get("o", false))
	if bool(s.get("dn", false)) and not bool(k["done"]):
		k["done"] = true
		k["finish_t"] = float(s.get("ft", st["t"]))
		var fo: Array = st["finish_order"]
		if not fo.has(int(k["i"])):
			fo.append(int(k["i"]))
			_ev(st, "finish", {"i": int(k["i"]), "pos": fo.size()})


## Acerca los karts de la red a lo ultimo que se supo (con un poco de prediccion).
static func net_follow(st: Dictionary, dt: float) -> void:
	for k: Dictionary in st["karts"]:
		if not bool(k["remote"]) or not k.has("net_p"):
			continue
		var dir: Vector2 = Vector2.from_angle(float(k["net_a"]))
		k["net_p"] = (k["net_p"] as Vector2) + dir * float(k["v"]) * dt
		k["p"] = (k["p"] as Vector2).lerp(k["net_p"], clampf(dt * 10.0, 0.0, 1.0))
		k["a"] = lerp_angle(float(k["a"]), float(k["net_a"]), clampf(dt * 10.0, 0.0, 1.0))


# ------------------------------------------------------------------ bot y analizador

static func bot_play(level: Dictionary, dt: float = 1.0 / 30.0) -> Dictionary:
	var st: Dictionary = new_state(level)
	while not bool(st["over"]):
		step(st, {}, dt)
		(st["events"] as Array).clear()
	return {"won": bool(st["won"]), "place": int(st.get("place", 9)), "time": float(st["t"])}


## Circuito valido: sin cruces de la pista consigo misma y con curvas que se pueden tomar.
static func track_issues(st: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var tr: Dictionary = st["track"]
	var line: Array = tr["line"]
	var m: int = line.size()
	var w: float = float(st["width"])
	var cross: bool = false
	for a: int in range(0, m, 3):
		for b: int in range(0, m, 3):
			var da: float = absf(float(tr["dist"][a]) - float(tr["dist"][b]))
			da = minf(da, float(tr["length"]) - da)
			if da > w * 3.0 and (line[a] as Vector2).distance_to(line[b]) < w + 4.0:
				cross = true
				break
		if cross:
			break
	if cross:
		out.append("kart_track_overlap")
	if float(tr["length"]) < 180.0:
		out.append("kart_track_short")
	return out


static func analyze(level: Dictionary) -> Dictionary:
	var st0: Dictionary = new_state(level)
	var issues: Array[String] = track_issues(st0)
	var wins: int = 0
	var tsum: float = 0.0
	if issues.is_empty():
		var base: int = int(parse(level)["seed"])
		for k: int in 3:
			var lv: Dictionary = level.duplicate()
			var rows: Array = []
			for r: Variant in level.get("map", []):
				if not (str(r).begins_with("#") and str(r).substr(1).is_valid_int()):
					rows.append(r)
			rows.append("#%d" % (base + k * 97))
			lv["map"] = rows
			var r2: Dictionary = bot_play(lv)
			tsum += float(r2["time"])
			if bool(r2["won"]):
				wins += 1
		if wins < 2:
			issues.append("kart_too_hard")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": 0, "enemies": int(level.get("rivals", 5)), "enemy_problems": [],
		"par": int(tsum / 3.0 * 1.1) + 5}
