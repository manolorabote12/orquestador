extends RefCounted
## Adivina la palabra (estilo Wordle): reglas, eleccion de la palabra, bot y analizador.
## 1 - Nivel (game.json -> levels[i]): "len" (letras, 4-7), "tries" (intentos, 4-8), "rank"
##     (lo comun que es la palabra: 0 = de las mas usadas, 1 = rara), "hard" (modo dificil: hay
##     que usar las pistas) y "seed". El mapa es ["palabra"]: la palabra sale del diccionario del
##     idioma del jugador (kit/words/dicts), asi el mismo nivel vale en todos los idiomas.
## 2 - Cada intento tiene que ser una palabra del diccionario. Cada letra se pinta: verde (en su
##     sitio), amarilla (esta, pero en otro sitio) o gris (no esta). Con letras repetidas, cada
##     letra de la palabra solo da una pista.
## 3 - Se gana al acertar; se pierde al acabar los intentos. Pista: descubre una letra (una por
##     nivel gratis).

const D = preload("res://kit/words/words_dict.gd")
const Rules = preload("res://kit/rules.gd")


## Semilla del nivel: "seed" o la fila "#n" del mapa (la pone la fabrica).
static func seed_of(level: Dictionary) -> int:
	if level.has("seed"):
		return int(level["seed"])
	for r: Variant in level.get("map", []):
		var t: String = str(r)
		if t.begins_with("#") and t.substr(1).is_valid_int():
			return int(t.substr(1))
	return 1
const GREEN: String = "G"
const YELLOW: String = "Y"
const GRAY: String = "."


## La palabra de un nivel en un idioma (siempre la misma para la misma semilla).
static func target(level: Dictionary, lang: String, retry: int = 0) -> String:
	var n: int = clampi(int(level.get("len", 5)), 4, 7)
	var pool: Array = (D.load_lang(lang)["targets"] as Dictionary).get(n, [])
	if pool.is_empty():
		return ""
	var rank: float = clampf(float(level.get("rank", 0.2)), 0.0, 1.0)
	## Las mas usadas primero: la "rank" decide hasta donde se mira (minimo 300 palabras).
	var top: int = clampi(int(300.0 + rank * float(pool.size() - 300)), mini(300, pool.size()), pool.size())
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_of(level) * 7919 + retry * 104729 + n
	return str(pool[rng.randi_range(0, top - 1)])


static func new_state(level: Dictionary, lang: String, retry: int = 0) -> Dictionary:
	var w: String = target(level, lang, retry)
	var st: Dictionary = {"word": w, "len": w.length(), "tries": clampi(int(level.get("tries", 6)), 4, 8), "hard": bool(level.get("hard", false)),
		"lang": D.pick(lang), "rows": [], "marks": [], "keys": {}, "won": false, "over": false, "hints": [], "hint_left": 1, "rng": RandomNumberGenerator.new()}
	(st["rng"] as RandomNumberGenerator).seed = seed_of(level) + retry
	st["rules"] = Rules.load_rules(level)
	Rules.hook(st, "on_start")
	return st


## Pistas de un intento contra la palabra: una letra por posicion (G, Y o .).
static func score(guess: String, word: String) -> String:
	var n: int = word.length()
	var res: Array[String] = []
	res.resize(n)
	var left: Dictionary = {}
	for i: int in n:
		if guess[i] == word[i]:
			res[i] = GREEN
		else:
			res[i] = GRAY
			left[word[i]] = int(left.get(word[i], 0)) + 1
	for i2: int in n:
		if res[i2] == GRAY and int(left.get(guess[i2], 0)) > 0:
			res[i2] = YELLOW
			left[guess[i2]] = int(left[guess[i2]]) - 1
	return "".join(res)


## Por que no vale un intento ("" si vale): largo, no es palabra, o en modo dificil no usa una pista.
static func why_not(st: Dictionary, guess: String) -> String:
	if guess.length() != int(st["len"]):
		return "short"
	if not D.is_word(str(st["lang"]), guess):
		return "word"
	if bool(st["hard"]):
		for k: int in (st["rows"] as Array).size():
			var g: String = st["rows"][k]
			var m: String = st["marks"][k]
			for i: int in g.length():
				if m[i] == GREEN and guess[i] != g[i]:
					return "hard"
				if m[i] == YELLOW and not guess.contains(g[i]):
					return "hard"
	return ""


## Prueba un intento: devuelve las pistas ("" si no vale).
static func guess(st: Dictionary, g: String) -> String:
	if bool(st["over"]) or why_not(st, g) != "":
		return ""
	var m: String = score(g, str(st["word"]))
	(st["rows"] as Array).append(g)
	(st["marks"] as Array).append(m)
	## Teclado: cada letra con su mejor pista.
	var keys: Dictionary = st["keys"]
	for i: int in g.length():
		var best: String = str(keys.get(g[i], ""))
		if m[i] == GREEN or (m[i] == YELLOW and best != GREEN) or best == "":
			keys[g[i]] = m[i]
	Rules.hook(st, "on_guess", [g, m])
	if g == str(st["word"]):
		st["won"] = true
		st["over"] = true
	elif (st["rows"] as Array).size() >= int(st["tries"]):
		st["over"] = true
	return m


## Pista: una letra de la palabra que aun no esta en verde (posicion, letra). [-1, ""] si no quedan.
static func hint(st: Dictionary) -> Array:
	if int(st["hint_left"]) <= 0:
		return [-1, ""]
	var w: String = st["word"]
	for i: int in w.length():
		var known: bool = (st["hints"] as Array).has(i)
		for k: int in (st["marks"] as Array).size():
			known = known or (str(st["marks"][k])[i] == GREEN)
		if not known:
			(st["hints"] as Array).append(i)
			st["hint_left"] = int(st["hint_left"]) - 1
			return [i, w[i]]
	return [-1, ""]


# ------------------------------------------------------------------ bot y analizador

## La cabeza del bot: entre las palabras posibles que encajan con todo lo visto, la que mas
## letras distintas y frecuentes tiene (asi descarta mas).
static func bot_guess(st: Dictionary) -> String:
	var n: int = int(st["len"])
	var pool: Array = (D.load_lang(str(st["lang"]))["targets"] as Dictionary).get(n, [])
	var cands: Array = []
	for w: Variant in pool:
		var ok: bool = true
		for k: int in (st["rows"] as Array).size():
			if score(str(st["rows"][k]), str(w)) != str(st["marks"][k]):
				ok = false
				break
		if ok:
			cands.append(w)
		if cands.size() >= 2000:
			break
	if cands.is_empty():
		return str(st["word"])
	if cands.size() == 1:
		return str(cands[0])
	var freq: Dictionary = {}
	for w2: Variant in cands:
		var seen: Dictionary = {}
		for ch: String in str(w2):
			if not seen.has(ch):
				seen[ch] = true
				freq[ch] = int(freq.get(ch, 0)) + 1
	var best: String = str(cands[0])
	var bs: float = -1.0
	for w3: Variant in cands.slice(0, 400):
		var seen2: Dictionary = {}
		var s: float = 0.0
		for ch2: String in str(w3):
			if not seen2.has(ch2):
				seen2[ch2] = true
				s += float(freq.get(ch2, 0))
		if s > bs:
			bs = s
			best = str(w3)
	return best


static func bot_play(level: Dictionary, lang: String) -> Dictionary:
	var st: Dictionary = new_state(level, lang)
	if str(st["word"]) == "":
		return {"won": false, "tries": 0}
	while not bool(st["over"]):
		var g: String = bot_guess(st)
		if guess(st, g) == "":
			break
	return {"won": bool(st["won"]), "tries": (st["rows"] as Array).size()}


## Analizador: el nivel tiene palabra en los 6 idiomas y el bot la acierta en todos.
static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var n: int = int(level.get("len", 5))
	if n < 4 or n > 7:
		issues.append("wordle_len")
	if int(level.get("tries", 6)) < 4 or int(level.get("tries", 6)) > 8:
		issues.append("wordle_tries")
	var worst: int = 0
	if issues.is_empty():
		for l: String in D.LANGS:
			var r: Dictionary = bot_play(level, l)
			worst = maxi(worst, int(r["tries"]))
			if not bool(r["won"]):
				issues.append("wordle_too_hard_" + l)
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": 1, "enemies": 0, "enemy_problems": [], "worst": worst}
