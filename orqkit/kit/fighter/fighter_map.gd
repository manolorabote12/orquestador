extends RefCounted
## Lucha 1 contra 1 (tipo Street Fighter): dos luchadores en un escenario plano. Andar, saltar,
## cubrirse, punetazo (rapido y corto), patada (lenta y larga) y especial (bola de energia que gasta
## media barra). Al golpear se carga la barra. Gana el combate quien gana dos asaltos; en cada
## asalto, quien deja al otro sin vida o tiene mas al acabar el tiempo. Todo va por ticks (20 por
## segundo) para que el bot, la IA rival y la escena jueguen igual.
## Nivel: "hp", "foe_hp", "ai" (0..1: reflejos, defensa y agresividad del rival), "round_time" (s),
## "foe_style" (rusher, zoner o counter), "seed".
## Combos: si un golpe conecta, su recuperacion se cancela en otro mas fuerte (punetazo -> patada ->
## especial). El golpe pulsado durante el ataque se guarda unos ticks (BUFFER). Cada golpe del combo
## hace un poco menos (COMBO_SCALE, como minimo COMBO_MIN) y el juego lo canta ("Combo x3").

const Rules = preload("res://kit/rules.gd")
const TPS: int = 20
const STAGE: float = 100.0
const WALK: float = 0.9
const JUMP_V: float = 3.2
const GRAV: float = 0.34
const BODY: float = 6.0
const FIREBALL_V: float = 2.0
const BUFFER: int = 6
const COMBO_SCALE: float = 0.15
const COMBO_MIN: float = 0.6
const CHAIN: Dictionary = {"punch": 1, "kick": 2, "special": 3}
## Ataques: arranque, activos, recuperacion (ticks), alcance, dano, aturdimiento, empuje, barra.
const MOVES: Dictionary = {
	"punch": {"start": 2, "active": 2, "recover": 5, "reach": 10.0, "dmg": 6, "stun": 7, "push": 1.5, "meter": 8},
	"kick": {"start": 5, "active": 2, "recover": 9, "reach": 14.0, "dmg": 11, "stun": 10, "push": 3.0, "meter": 12},
	"air": {"start": 2, "active": 4, "recover": 2, "reach": 11.0, "dmg": 9, "stun": 9, "push": 2.0, "meter": 10},
	"special": {"start": 8, "active": 1, "recover": 12, "reach": 0.0, "dmg": 14, "stun": 12, "push": 4.0, "meter": 0},
}


static func new_state(level: Dictionary) -> Dictionary:
	var st: Dictionary = {"f": [_fighter(30.0, 1, int(level.get("hp", 100))), _fighter(70.0, -1, int(level.get("foe_hp", 100)))],
		"shots": [], "round": 1, "wins": [0, 0], "time": int(level.get("round_time", 60)) * TPS, "round_time": int(level.get("round_time", 60)) * TPS,
		"tick": 0, "pause": 30, "won": false, "lost": false, "log": [], "ai": float(level.get("ai", 0.5)),
		"style": str(level.get("foe_style", "rusher")), "rng": int(level.get("seed", 7)) * 7919 + 13, "ai_wait": 0, "ai_plan": "",
		"hits": 0, "perfect": true, "hp0": [int(level.get("hp", 100)), int(level.get("foe_hp", 100))], "best_combo": 0}
	st["rules"] = Rules.load_rules(level)
	Rules.hook(st, "on_start")
	return st


static func _fighter(x: float, face: int, hp: int) -> Dictionary:
	return {"x": x, "y": 0.0, "vx": 0.0, "vy": 0.0, "face": face, "hp": hp, "max": hp, "meter": 0, "state": "idle",
		"move": "", "frame": 0, "stun": 0, "block": false, "hit_done": false, "anim": 0, "buf": "", "buf_t": 0, "combo": 0}


## Se puede cancelar el golpe que acaba de conectar en "to"? (solo hacia uno mas fuerte, en el suelo)
static func can_chain(f: Dictionary, to: String) -> bool:
	if str(f["state"]) != "attack" or not bool(f["hit_done"]) or float(f["y"]) > 0.0:
		return false
	var from: String = str(f["move"])
	if not CHAIN.has(from) or not CHAIN.has(to) or int(CHAIN[to]) <= int(CHAIN[from]):
		return false
	return to != "special" or int(f["meter"]) >= 50


static func _start_attack(st: Dictionary, i: int, f: Dictionary, atk: String, air: bool) -> void:
	if atk == "special":
		f["meter"] = int(f["meter"]) - 50
	f["state"] = "attack"
	f["move"] = atk
	f["frame"] = 0
	f["hit_done"] = false
	f["buf"] = ""
	f["buf_t"] = 0
	if not air:
		f["vx"] = 0.0
	(st["log"] as Array).append({"k": "swing", "who": i, "move": atk})


static func _rand(st: Dictionary) -> float:
	st["rng"] = (int(st["rng"]) * 1103515245 + 12345) % 2147483648
	return float(int(st["rng"]) % 100000) / 100000.0


static func busy(f: Dictionary) -> bool:
	return str(f["state"]) in ["attack", "stun", "ko"]


## Ordenes de un luchador para este tick: {"dir": -1/0/1, "jump", "block", "attack": "" o el golpe}.
static func tick(st: Dictionary, cmd0: Dictionary, cmd1: Dictionary) -> void:
	if bool(st["won"]) or bool(st["lost"]):
		return
	st["tick"] = int(st["tick"]) + 1
	if int(st["pause"]) > 0:
		st["pause"] = int(st["pause"]) - 1
		return
	st["time"] = int(st["time"]) - 1
	var cmds: Array = [cmd0, cmd1]
	for i: int in 2:
		_act(st, i, cmds[i])
	for i2: int in 2:
		_physics(st, i2)
	_shots(st)
	for i3: int in 2:
		_hits(st, i3)
	_round_end(st)


static func _act(st: Dictionary, i: int, c: Dictionary) -> void:
	var f: Dictionary = st["f"][i]
	var o: Dictionary = st["f"][1 - i]
	f["block"] = false
	if str(f["state"]) == "ko":
		return
	if str(f["state"]) == "stun":
		f["stun"] = int(f["stun"]) - 1
		if int(f["stun"]) <= 0:
			f["state"] = "idle"
		return
	if str(f["state"]) == "attack":
		## Golpe pulsado durante el ataque: se guarda unos ticks por si el actual conecta.
		var want: String = str(c.get("attack", ""))
		if want != "":
			f["buf"] = want
			f["buf_t"] = BUFFER
		elif int(f["buf_t"]) > 0:
			f["buf_t"] = int(f["buf_t"]) - 1
		if int(f["buf_t"]) > 0 and can_chain(f, str(f["buf"])):
			(st["log"] as Array).append({"k": "cancel", "who": i, "move": str(f["buf"])})
			_start_attack(st, i, f, str(f["buf"]), false)
			return
		var mv: Dictionary = MOVES[str(f["move"])]
		f["frame"] = int(f["frame"]) + 1
		if str(f["move"]) == "special" and int(f["frame"]) == int(mv["start"]):
			(st["shots"] as Array).append({"x": float(f["x"]) + float(f["face"]) * 6.0, "y": 8.0, "dir": int(f["face"]), "owner": i})
			(st["log"] as Array).append({"k": "special", "who": i})
		if int(f["frame"]) >= int(mv["start"]) + int(mv["active"]) + int(mv["recover"]):
			f["state"] = "idle" if float(f["y"]) <= 0.0 else "jump"
			f["move"] = ""
		return
	## Mirar siempre al rival (en el suelo).
	if float(f["y"]) <= 0.0:
		f["face"] = 1 if float(o["x"]) > float(f["x"]) else -1
	var air: bool = float(f["y"]) > 0.0
	var atk: String = str(c.get("attack", ""))
	if atk != "":
		if air:
			atk = "air"
		elif atk == "air":
			atk = "punch"
		if atk == "special" and int(f["meter"]) < 50:
			atk = ""
		if atk != "":
			_start_attack(st, i, f, atk, air)
			return
	if air:
		return
	if bool(c.get("block", false)):
		f["block"] = true
		f["state"] = "block"
		f["vx"] = 0.0
		return
	if bool(c.get("jump", false)):
		f["vy"] = JUMP_V
		f["vx"] = float(int(c.get("dir", 0))) * 1.1
		f["y"] = 0.01
		f["state"] = "jump"
		return
	var d: int = int(c.get("dir", 0))
	f["vx"] = float(d) * WALK
	f["state"] = "walk" if d != 0 else "idle"


static func _physics(st: Dictionary, i: int) -> void:
	var f: Dictionary = st["f"][i]
	var o: Dictionary = st["f"][1 - i]
	if float(f["y"]) > 0.0 or float(f["vy"]) > 0.0:
		f["vy"] = float(f["vy"]) - GRAV
		f["y"] = float(f["y"]) + float(f["vy"])
		if float(f["y"]) <= 0.0:
			f["y"] = 0.0
			f["vy"] = 0.0
			if str(f["state"]) == "jump" or (str(f["state"]) == "attack" and str(f["move"]) == "air"):
				f["state"] = "idle"
				f["move"] = ""
			f["vx"] = 0.0
	var nx: float = clampf(float(f["x"]) + float(f["vx"]), 4.0, STAGE - 4.0)
	## No se atraviesan (salvo por encima).
	if absf(float(o["y"]) - float(f["y"])) < 10.0 and absf(nx - float(o["x"])) < BODY and absf(nx - float(o["x"])) < absf(float(f["x"]) - float(o["x"])):
		nx = float(f["x"])
	f["x"] = nx
	if str(f["state"]) == "stun" or str(f["state"]) == "block":
		f["vx"] = float(f["vx"]) * 0.7


static func _hit(st: Dictionary, victim: int, dmg: int, stun: int, push: float, from_x: float, meter_to: int, meter: int) -> void:
	var v: Dictionary = st["f"][victim]
	## Combo: golpear a quien sigue aturdido por tu golpe anterior suma y pega algo menos.
	var was_stunned: bool = str(v["state"]) == "stun"
	if meter_to >= 0:
		var at: Dictionary = st["f"][meter_to]
		at["combo"] = int(at["combo"]) + 1 if was_stunned else 1
		if int(at["combo"]) >= 2:
			dmg = maxi(1, int(round(float(dmg) * maxf(COMBO_MIN, 1.0 - COMBO_SCALE * float(int(at["combo"]) - 1)))))
	var front: bool = signf(from_x - float(v["x"])) == float(v["face"])
	var blocked: bool = bool(v["block"]) and front and float(v["y"]) <= 0.0
	var dir: float = signf(float(v["x"]) - from_x)
	if blocked:
		v["hp"] = maxi(0, int(v["hp"]) - maxi(1, dmg / 5))
		v["vx"] = dir * push * 0.6
		(st["log"] as Array).append({"k": "block", "who": victim})
	else:
		v["hp"] = maxi(0, int(v["hp"]) - dmg)
		v["state"] = "stun"
		v["stun"] = stun
		v["move"] = ""
		v["vx"] = dir * push
		if float(v["y"]) > 0.0:
			v["vy"] = maxf(float(v["vy"]), 1.2)
		(st["log"] as Array).append({"k": "hit", "who": victim, "n": dmg})
		if meter_to >= 0 and int((st["f"][meter_to] as Dictionary)["combo"]) >= 2:
			var cn: int = int((st["f"][meter_to] as Dictionary)["combo"])
			(st["log"] as Array).append({"k": "combo", "who": meter_to, "n": cn})
			if meter_to == 0:
				st["best_combo"] = maxi(int(st["best_combo"]), cn)
		if meter_to >= 0:
			var a: Dictionary = st["f"][meter_to]
			a["meter"] = mini(100, int(a["meter"]) + meter)
		v["meter"] = mini(100, int(v["meter"]) + 4)
		if victim == 0:
			st["perfect"] = false
		else:
			st["hits"] = int(st["hits"]) + 1
		Rules.hook(st, "on_hit", [victim, dmg])
	if int(v["hp"]) <= 0:
		v["state"] = "ko"


static func _hits(st: Dictionary, i: int) -> void:
	var f: Dictionary = st["f"][i]
	if str(f["state"]) != "attack" or bool(f["hit_done"]) or str(f["move"]) == "special":
		return
	var mv: Dictionary = MOVES[str(f["move"])]
	var fr: int = int(f["frame"])
	if fr < int(mv["start"]) or fr >= int(mv["start"]) + int(mv["active"]):
		return
	var o: Dictionary = st["f"][1 - i]
	if str(o["state"]) == "ko":
		return
	var dx: float = (float(o["x"]) - float(f["x"])) * float(f["face"])
	var dy: float = absf(float(o["y"]) - float(f["y"]))
	if dx > 0.0 and dx <= float(mv["reach"]) and dy < 12.0:
		f["hit_done"] = true
		_hit(st, 1 - i, int(mv["dmg"]), int(mv["stun"]), float(mv["push"]), float(f["x"]), i, int(mv["meter"]))


static func _shots(st: Dictionary) -> void:
	var keep: Array = []
	for s: Variant in st["shots"]:
		var sd: Dictionary = s
		sd["x"] = float(sd["x"]) + float(sd["dir"]) * FIREBALL_V
		var victim: int = 1 - int(sd["owner"])
		var v: Dictionary = st["f"][victim]
		if absf(float(v["x"]) - float(sd["x"])) < 4.0 and float(v["y"]) < 14.0 and str(v["state"]) != "ko":
			var mv: Dictionary = MOVES["special"]
			_hit(st, victim, int(mv["dmg"]), int(mv["stun"]), float(mv["push"]), float(sd["x"]) - float(sd["dir"]) * 3.0, int(sd["owner"]), 0)
			continue
		if float(sd["x"]) < -5.0 or float(sd["x"]) > STAGE + 5.0:
			continue
		keep.append(sd)
	## Dos bolas que chocan se anulan.
	if keep.size() == 2 and int(keep[0]["owner"]) != int(keep[1]["owner"]) and absf(float(keep[0]["x"]) - float(keep[1]["x"])) < 4.0:
		keep = []
	st["shots"] = keep


static func _round_end(st: Dictionary) -> void:
	var a: Dictionary = st["f"][0]
	var b: Dictionary = st["f"][1]
	var winner: int = -1
	if int(a["hp"]) <= 0 or int(b["hp"]) <= 0:
		winner = 0 if int(b["hp"]) <= 0 and int(a["hp"]) > 0 else (1 if int(a["hp"]) <= 0 and int(b["hp"]) > 0 else -2)
	elif int(st["time"]) <= 0:
		var ra: float = float(a["hp"]) / float(a["max"])
		var rb: float = float(b["hp"]) / float(b["max"])
		winner = 0 if ra > rb else (1 if rb > ra else -2)
	if winner == -1:
		return
	if winner >= 0:
		st["wins"][winner] = int(st["wins"][winner]) + 1
	(st["log"] as Array).append({"k": "round", "winner": winner, "round": int(st["round"])})
	if int(st["wins"][0]) >= 2:
		st["won"] = true
		return
	if int(st["wins"][1]) >= 2:
		st["lost"] = true
		return
	if int(st["round"]) >= 5:
		## Empates sin fin: decide la vida.
		st["won"] = int(st["wins"][0]) >= int(st["wins"][1])
		st["lost"] = not bool(st["won"])
		return
	st["round"] = int(st["round"]) + 1
	var hp0: Array = st["hp0"]
	st["f"] = [_fighter(30.0, 1, int(hp0[0])), _fighter(70.0, -1, int(hp0[1]))]
	(st["f"][0] as Dictionary)["meter"] = int(a["meter"])
	(st["f"][1] as Dictionary)["meter"] = int(b["meter"])
	st["shots"] = []
	st["time"] = st["round_time"]
	st["pause"] = 40


# ------------------------------------------------------------------ IA y bot

## Que hara el golpe del rival: ticks que faltan para que pegue (o -1 si no amenaza).
static func _threat(st: Dictionary, me: int) -> int:
	var o: Dictionary = st["f"][1 - me]
	var f: Dictionary = st["f"][me]
	if str(o["state"]) == "attack" and str(o["move"]) != "special":
		var mv: Dictionary = MOVES[str(o["move"])]
		var dx: float = (float(f["x"]) - float(o["x"])) * float(o["face"])
		if dx > 0.0 and dx <= float(mv["reach"]) + 3.0 and int(o["frame"]) < int(mv["start"]) + int(mv["active"]):
			return maxi(0, int(mv["start"]) - int(o["frame"]))
	for s: Variant in st["shots"]:
		if int(s["owner"]) != me:
			var dist: float = (float(f["x"]) - float(s["x"])) * float(s["dir"])
			if dist > 0.0 and dist < 22.0:
				return int(dist / FIREBALL_V)
	return -1


## Ticks de recuperacion que le quedan al rival tras su golpe (para castigar).
static func _recovering(st: Dictionary, me: int) -> int:
	var o: Dictionary = st["f"][1 - me]
	if str(o["state"]) == "stun":
		return int(o["stun"])
	if str(o["state"]) != "attack":
		return 0
	var mv: Dictionary = MOVES[str(o["move"])]
	var end: int = int(mv["start"]) + int(mv["active"]) + int(mv["recover"])
	if int(o["frame"]) >= int(mv["start"]) + int(mv["active"]):
		return end - int(o["frame"])
	return 0


static func _dist(st: Dictionary) -> float:
	return absf(float(st["f"][0]["x"]) - float(st["f"][1]["x"]))


## Bot del jugador (validar): se cubre a tiempo, castiga la recuperacion y busca la distancia de patada.
static func bot_cmd(st: Dictionary, me: int = 0) -> Dictionary:
	var f: Dictionary = st["f"][me]
	var o: Dictionary = st["f"][1 - me]
	var toward: int = 1 if float(o["x"]) > float(f["x"]) else -1
	var d: float = _dist(st)
	var c: Dictionary = {"dir": 0, "jump": false, "block": false, "attack": ""}
	## Combo: si el punetazo conecto, sigue con patada (y con especial si hay barra).
	if can_chain(f, "special") and str(f["move"]) == "kick":
		c["attack"] = "special"
		return c
	if can_chain(f, "kick") and d <= float(MOVES["kick"]["reach"]) + 1.0:
		c["attack"] = "kick"
		return c
	if busy(f) or float(f["y"]) > 0.0:
		if float(f["y"]) > 0.0 and d < 12.0 and str(f["state"]) == "jump":
			c["attack"] = "air"
		return c
	var th: int = _threat(st, me)
	var rec: int = _recovering(st, me)
	if rec >= 3 and d <= MOVES["kick"]["reach"] - 1.0 and rec >= int(MOVES["kick"]["start"]):
		c["attack"] = "kick"
		return c
	if rec >= 2 and d <= MOVES["punch"]["reach"] - 0.5:
		c["attack"] = "punch"
		return c
	if th >= 0:
		## Una bola de lejos: saltarla; un golpe: cubrirse.
		if str(o["state"]) != "attack" and th > 4 and th < 10:
			c["jump"] = true
			c["dir"] = toward
		else:
			c["block"] = true
		return c
	if int(f["meter"]) >= 50 and d > 30.0:
		c["attack"] = "special"
		return c
	if d > 13.0:
		c["dir"] = toward
	elif d < 9.0 and float(f["x"]) > 10.0 and float(f["x"]) < STAGE - 10.0:
		c["dir"] = -toward
	elif str(o["state"]) in ["idle", "walk", "block"] and d <= 13.5:
		c["attack"] = "kick" if str(o["state"]) != "block" else ""
		if c["attack"] == "":
			c["dir"] = -toward
	return c


## IA del rival: lo mismo que el bot pero con reflejos y defensa segun "ai" y su estilo.
static func ai_cmd(st: Dictionary) -> Dictionary:
	var me: int = 1
	var f: Dictionary = st["f"][me]
	var o: Dictionary = st["f"][0]
	var ai: float = clampf(float(st["ai"]), 0.0, 1.0)
	var toward: int = 1 if float(o["x"]) > float(f["x"]) else -1
	var d: float = _dist(st)
	var c: Dictionary = {"dir": 0, "jump": false, "block": false, "attack": ""}
	## Rivales listos (ai > 0.4) encadenan a veces el punetazo que conecta con una patada.
	if ai > 0.4 and can_chain(f, "kick") and _rand(st) < ai - 0.4:
		c["attack"] = "kick"
		return c
	if busy(f) or float(f["y"]) > 0.0:
		if float(f["y"]) > 0.0 and d < 12.0 and str(f["state"]) == "jump" and _rand(st) < 0.3:
			c["attack"] = "air"
		return c
	## Se lo piensa: cada cierto tiempo decide un plan y lo mantiene.
	st["ai_wait"] = int(st["ai_wait"]) - 1
	var th: int = _threat(st, me)
	if th >= 0 and _rand(st) < 0.12 + 0.6 * ai:
		if str(o["state"]) != "attack" and th > 4 and _rand(st) < 0.5:
			c["jump"] = true
			c["dir"] = -toward if _rand(st) < 0.5 else toward
		else:
			c["block"] = true
		return c
	var rec: int = _recovering(st, me)
	if rec >= 2 and d <= 9.5 and _rand(st) < 0.15 + 0.6 * ai:
		c["attack"] = "punch"
		return c
	if int(st["ai_wait"]) > 0:
		return _follow(st, c, toward, d)
	st["ai_wait"] = int(10 - 7 * ai) + int(_rand(st) * 6.0)
	var style: String = str(st["style"])
	var r: float = _rand(st)
	if int(f["meter"]) >= 50 and d > 25.0 and r < (0.6 if style == "zoner" else 0.3):
		c["attack"] = "special"
		return c
	if style == "rusher":
		st["ai_plan"] = "in" if r < 0.75 else "wait"
	elif style == "zoner":
		st["ai_plan"] = "out" if d < 30.0 and r < 0.6 else ("in" if r < 0.8 else "wait")
	else:
		st["ai_plan"] = "wait" if r < 0.5 else "in"
	if d <= 13.0 and r < 0.35 + 0.4 * ai:
		c["attack"] = "kick" if d > 9.0 or r < 0.3 else "punch"
		return c
	if d > 20.0 and r < 0.06:
		c["jump"] = true
		c["dir"] = toward
		return c
	return _follow(st, c, toward, d)


static func _follow(st: Dictionary, c: Dictionary, toward: int, d: float) -> Dictionary:
	match str(st["ai_plan"]):
		"in":
			if d > 11.0:
				c["dir"] = toward
		"out":
			c["dir"] = -toward
	return c


static func bot_play(level: Dictionary, max_ticks: int = 20000) -> Dictionary:
	var st: Dictionary = new_state(level)
	while not bool(st["won"]) and not bool(st["lost"]) and int(st["tick"]) < max_ticks:
		tick(st, bot_cmd(st), ai_cmd(st))
	return {"won": bool(st["won"]), "ticks": int(st["tick"]), "wins": st["wins"], "rounds": int(st["round"])}


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	if int(level.get("hp", 100)) < 30 or int(level.get("foe_hp", 100)) < 30:
		issues.append("fighter_hp")
	var r: Dictionary = bot_play(level)
	if not bool(r["won"]):
		issues.append("fighter_bot_failed")
	elif int(r["ticks"]) < 20 * 20:
		issues.append("fighter_too_short")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": 0, "enemies": 1, "enemy_problems": [], "bot": r}
