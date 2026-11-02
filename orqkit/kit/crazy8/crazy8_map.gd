extends RefCounted
## Cartas locas (tipo UNO, con nombres propios): juega una carta del mismo color o del mismo numero o
## simbolo que la de la mesa; si no puedes, robas una. Salta, Reversa y +2 cambian el turno; el
## Comodin cambia de color y el Comodin +4 ademas hace robar 4. Gana quien se queda sin cartas.
## Nivel: "players" (2-4: tu y los rivales), "hand" (cartas al empezar) y "deck" (el mazo en orden,
## la primera la de arriba): asi todo es determinista y la fabrica elige mazos donde se puede ganar.
## Cartas: color (r, g, b, y) + valor (0-9, S salta, R reversa, D +2); comodines "W" y "F" (+4).
## Si se acaba el mazo, se rehace con las de la mesa en su orden (sin azar).

const Rules = preload("res://kit/rules.gd")
const COLORS: Array[String] = ["r", "g", "b", "y"]


## El mazo completo (108 cartas) en orden fijo.
static func full_deck() -> Array:
	var out: Array = []
	for c: String in COLORS:
		out.append(c + "0")
		for k: int in 2:
			for v: String in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "S", "R", "D"]:
				out.append(c + v)
	for k2: int in 4:
		out.append("W")
		out.append("F")
	return out


static func is_wild(card: String) -> bool:
	return card == "W" or card == "F"


static func value_of(card: String) -> String:
	return card if is_wild(card) else card.substr(1)


static func new_state(level: Dictionary) -> Dictionary:
	var n: int = clampi(int(level.get("players", 2)), 2, 4)
	var draw: Array = []
	for c: Variant in level.get("deck", full_deck()):
		draw.append(str(c))
	draw.reverse()
	var hands: Array = []
	for p: int in n:
		hands.append([])
	for k: int in clampi(int(level.get("hand", 7)), 3, 10):
		for p2: int in n:
			if not draw.is_empty():
				(hands[p2] as Array).append(draw.pop_back())
	## La primera de la mesa no puede ser comodin: se pasa al fondo del mazo.
	var guard: int = 0
	while not draw.is_empty() and is_wild(str(draw.back())) and guard < 20:
		draw.push_front(draw.pop_back())
		guard += 1
	var top: String = str(draw.pop_back()) if not draw.is_empty() else "r0"
	var st: Dictionary = {"n": n, "hands": hands, "draw": draw, "discard": [top], "color": top.substr(0, 1), "turn": 0, "dir": 1,
		"drew": "", "won": false, "lost": false, "winner": -1, "turns": 0, "rng": RandomNumberGenerator.new()}
	st["rules"] = Rules.load_rules(level)
	Rules.hook(st, "on_start")
	return st


static func top(st: Dictionary) -> String:
	return str((st["discard"] as Array).back())


static func playable(st: Dictionary, card: String) -> bool:
	if is_wild(card):
		return true
	if card.substr(0, 1) == str(st["color"]):
		return true
	var t: String = top(st)
	return not is_wild(t) and value_of(card) == value_of(t)


static func next_player(st: Dictionary, steps: int = 1) -> int:
	var n: int = int(st["n"])
	return posmod(int(st["turn"]) + int(st["dir"]) * steps, n)


## Roba una carta para el jugador p (rehace el mazo con la mesa si hace falta). "" si no quedan.
static func _take(st: Dictionary, p: int) -> String:
	var draw: Array = st["draw"]
	if draw.is_empty():
		var disc: Array = st["discard"]
		var keep: String = str(disc.pop_back())
		disc.reverse()
		for c: Variant in disc:
			draw.append(c)
		st["discard"] = [keep]
	if draw.is_empty():
		return ""
	var card: String = str(draw.pop_back())
	(st["hands"][p] as Array).append(card)
	return card


## El jugador del turno roba una. Despues solo puede jugar esa (si vale) o pasar.
static func draw_card(st: Dictionary) -> String:
	if bool(st["won"]) or bool(st["lost"]) or str(st["drew"]) != "":
		return ""
	var c: String = _take(st, int(st["turn"]))
	st["drew"] = c if c != "" else "-"
	if c == "" or not playable(st, c):
		pass_turn(st)
	return c


static func pass_turn(st: Dictionary) -> void:
	st["drew"] = ""
	st["turn"] = next_player(st)
	st["turns"] = int(st["turns"]) + 1


## El jugador del turno juega la carta idx de su mano (color: el que elige si es comodin).
static func play(st: Dictionary, idx: int, color: String = "") -> bool:
	if bool(st["won"]) or bool(st["lost"]):
		return false
	var p: int = int(st["turn"])
	var hand: Array = st["hands"][p]
	if idx < 0 or idx >= hand.size():
		return false
	var card: String = str(hand[idx])
	if not playable(st, card):
		return false
	if str(st["drew"]) != "" and str(st["drew"]) != "-" and card != str(st["drew"]):
		return false
	hand.remove_at(idx)
	(st["discard"] as Array).append(card)
	st["color"] = (color if COLORS.has(color) else best_color(hand)) if is_wild(card) else card.substr(0, 1)
	st["drew"] = ""
	Rules.hook(st, "on_play", [p, card])
	if hand.is_empty():
		st["winner"] = p
		st["won"] = p == 0
		st["lost"] = p != 0
		return true
	var v: String = value_of(card)
	var skip: int = 1
	if v == "R":
		st["dir"] = -int(st["dir"])
		if int(st["n"]) == 2:
			skip = 2
	elif v == "S":
		skip = 2
	elif v == "D" or v == "F":
		var victim: int = next_player(st)
		for k: int in (2 if v == "D" else 4):
			_take(st, victim)
		skip = 2
	st["turn"] = next_player(st, skip)
	st["turns"] = int(st["turns"]) + 1
	return true


## El color que mas se repite en una mano (empate: el orden r, g, b, y).
static func best_color(hand: Array) -> String:
	var best: String = "r"
	var bn: int = -1
	for c: String in COLORS:
		var k: int = 0
		for h: Variant in hand:
			k += 1 if str(h).substr(0, 1) == c and not is_wild(str(h)) else 0
		if k > bn:
			bn = k
			best = c
	return best


## Rival: la primera carta que vale de su mano; si no, roba (y juega la robada si vale).
static func rival_move(st: Dictionary) -> int:
	var hand: Array = st["hands"][int(st["turn"])]
	if str(st["drew"]) != "" and str(st["drew"]) != "-":
		return hand.size() - 1
	for i: int in hand.size():
		if playable(st, str(hand[i])):
			return i
	return -1


## Tu bot: si el siguiente esta a punto de ganar, castiga (+4, +2, salta, reversa); si no, prefiere
## cartas de color con numero alto y guarda los comodines para el final.
static func bot_move(st: Dictionary) -> int:
	var hand: Array = st["hands"][int(st["turn"])]
	if str(st["drew"]) != "" and str(st["drew"]) != "-":
		return hand.size() - 1
	var nxt: int = (st["hands"][next_player(st)] as Array).size()
	var best: int = -1
	var bs: float = -INF
	for i: int in hand.size():
		var c: String = str(hand[i])
		if not playable(st, c):
			continue
		var v: String = value_of(c)
		var s: float = 0.0
		if is_wild(c):
			s = -20.0 + (30.0 if nxt <= 2 and c == "F" else 0.0)
		elif v == "D" or v == "S" or v == "R":
			s = 5.0 + (25.0 if nxt <= 2 else 0.0)
		else:
			s = float(int(v))
		var same: int = 0
		for h: Variant in hand:
			same += 1 if str(h).substr(0, 1) == c.substr(0, 1) else 0
		s += float(same) * 0.5
		if s > bs:
			bs = s
			best = i
	return best


## Una jugada del jugador del turno con su politica (bot o rival). Devuelve false si el juego acabo.
static func auto_turn(st: Dictionary, smart: bool) -> bool:
	if bool(st["won"]) or bool(st["lost"]):
		return false
	var i: int = bot_move(st) if smart else rival_move(st)
	if i >= 0:
		play(st, i, best_color(st["hands"][int(st["turn"])]))
	elif str(st["drew"]) == "":
		draw_card(st)
	else:
		pass_turn(st)
	return true


static func bot_play(level: Dictionary, max_turns: int = 600) -> Dictionary:
	var st: Dictionary = new_state(level)
	while not bool(st["won"]) and not bool(st["lost"]) and int(st["turns"]) < max_turns:
		auto_turn(st, int(st["turn"]) == 0)
	return {"won": bool(st["won"]), "turns": int(st["turns"]), "winner": int(st["winner"])}


## Analizador: mazo de cartas validas y suficientes, y tu bot gana la partida con ese mazo.
static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var deck: Array = level.get("deck", [])
	var n: int = int(level.get("players", 2))
	if n < 2 or n > 4:
		issues.append("c8_players")
	if deck.size() < n * int(level.get("hand", 7)) + 20:
		issues.append("c8_small_deck")
	for c: Variant in deck:
		var s: String = str(c)
		if not is_wild(s) and (s.length() != 2 or not COLORS.has(s.substr(0, 1)) or not "0123456789SRD".contains(s.substr(1))):
			issues.append("c8_bad_card")
			break
	var r: Dictionary = {"won": false, "turns": 0}
	if issues.is_empty():
		r = bot_play(level)
		if not bool(r["won"]):
			issues.append("c8_unbeatable")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": 0, "enemies": 0, "enemy_problems": [], "bot_turns": r.get("turns", 0)}
