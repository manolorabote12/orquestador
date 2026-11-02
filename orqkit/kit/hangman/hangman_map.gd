extends RefCounted
## Ahorcado (en version amable): adivina la palabra letra a letra. El heroe cuelga de un ramo de
## globos y cada letra que no esta revienta uno; si se acaban, cae. La palabra sale del diccionario
## del idioma del jugador (kit/words), asi el mismo nivel vale en todos los idiomas.
## Nivel: "len" (4 a 8 letras), "lives" (globos, 4 a 8), "rank" (lo rara que es: 0 comun, 1 rara),
## "hint" (letras que se pueden destapar con la pista) y la semilla en el mapa ("#n").

const Rules = preload("res://kit/rules.gd")
const D = preload("res://kit/words/words_dict.gd")


static func seed_of(level: Dictionary) -> int:
	if level.has("seed"):
		return int(level["seed"])
	for r: Variant in level.get("map", []):
		var t: String = str(r)
		if t.begins_with("#") and t.substr(1).is_valid_int():
			return int(t.substr(1))
	return 1


## La palabra de un nivel en un idioma (siempre la misma para la misma semilla e intento).
static func target(level: Dictionary, lang: String, retry: int = 0) -> String:
	var n: int = clampi(int(level.get("len", 5)), 4, 8)
	var pool: Array = (D.load_lang(lang)["targets"] as Dictionary).get(n, [])
	if pool.is_empty():
		pool = (D.load_lang(lang)["by_len"] as Dictionary).get(n, [])
	if pool.is_empty():
		return ""
	var rank: float = clampf(float(level.get("rank", 0.2)), 0.0, 1.0)
	var top: int = clampi(int(200.0 + rank * float(pool.size() - 200)), mini(200, pool.size()), pool.size())
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_of(level) * 6151 + retry * 99991 + n
	return str(pool[rng.randi_range(0, top - 1)])


static func new_state(level: Dictionary, lang: String, retry: int = 0) -> Dictionary:
	var st: Dictionary = {"word": target(level, lang, retry), "lang": D.pick(lang), "guessed": {}, "misses": 0,
		"lives": clampi(int(level.get("lives", 6)), 3, 9), "hints": int(level.get("hint", 1)), "won": false, "lost": false, "last": ""}
	st["rules"] = Rules.load_rules(level)
	Rules.hook(st, "on_start")
	return st


static func shown(st: Dictionary) -> String:
	var out: String = ""
	for ch: String in str(st["word"]):
		out += ch if (st["guessed"] as Dictionary).has(ch) else "_"
	return out


## Prueba una letra: "hit", "miss" o "" (repetida o partida acabada).
static func guess(st: Dictionary, ch: String) -> String:
	ch = ch.to_upper()
	if bool(st["won"]) or bool(st["lost"]) or ch.length() != 1 or (st["guessed"] as Dictionary).has(ch):
		return ""
	(st["guessed"] as Dictionary)[ch] = true
	st["last"] = ch
	var hit: bool = str(st["word"]).contains(ch)
	if hit:
		Rules.hook(st, "on_hit", [ch])
		if not shown(st).contains("_"):
			st["won"] = true
		return "hit"
	st["misses"] = int(st["misses"]) + 1
	Rules.hook(st, "on_miss", [ch])
	if int(st["misses"]) >= int(st["lives"]):
		st["lost"] = true
	return "miss"


## Pista: destapa una letra que falta (la primera de la palabra). Devuelve la letra o "".
static func use_hint(st: Dictionary) -> String:
	if int(st["hints"]) <= 0 or bool(st["won"]) or bool(st["lost"]):
		return ""
	for ch: String in str(st["word"]):
		if not (st["guessed"] as Dictionary).has(ch):
			st["hints"] = int(st["hints"]) - 1
			(st["guessed"] as Dictionary)[ch] = true
			if not shown(st).contains("_"):
				st["won"] = true
			return ch
	return ""


## Bot: la letra que mas palabras posibles tiene (de las del diccionario que encajan con lo que se ve).
static func bot_letter(st: Dictionary) -> String:
	var pattern: String = shown(st)
	var n: int = pattern.length()
	var guessed: Dictionary = st["guessed"]
	var pool: Array = (D.load_lang(str(st["lang"]))["targets"] as Dictionary).get(n, [])
	var counts: Dictionary = {}
	for w: Variant in pool:
		var word: String = str(w)
		var ok: bool = true
		for k: int in n:
			var c: String = word[k]
			var p: String = pattern[k]
			if (p != "_" and c != p) or (p == "_" and guessed.has(c)):
				ok = false
				break
		if not ok:
			continue
		var seen: Dictionary = {}
		for k2: int in n:
			var c2: String = word[k2]
			if not guessed.has(c2) and not seen.has(c2):
				seen[c2] = true
				counts[c2] = int(counts.get(c2, 0)) + 1
	var best: String = ""
	var bc: int = -1
	for ch: String in D.alphabet(str(st["lang"])):
		if not guessed.has(ch) and int(counts.get(ch, 0)) > bc:
			bc = int(counts.get(ch, 0))
			best = ch
	return best


static func bot_play(level: Dictionary, lang: String) -> Dictionary:
	var st: Dictionary = new_state(level, lang)
	var guard: int = 0
	while not bool(st["won"]) and not bool(st["lost"]) and guard < 40:
		guard += 1
		var ch: String = bot_letter(st)
		if ch == "" or guess(st, ch) == "":
			break
	return {"won": bool(st["won"]), "misses": int(st["misses"]), "word": str(st["word"])}


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var n: int = int(level.get("len", 5))
	if n < 4 or n > 8:
		issues.append("hangman_len")
	if int(level.get("lives", 6)) < 4 or int(level.get("lives", 6)) > 8:
		issues.append("hangman_lives")
	var worst: int = 0
	if issues.is_empty():
		for l: String in D.LANGS:
			if target(level, l) == "":
				issues.append("hangman_no_word_" + l)
				continue
			var r: Dictionary = bot_play(level, l)
			worst = maxi(worst, int(r["misses"]))
			if not bool(r["won"]):
				issues.append("hangman_too_hard_" + l)
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": 1, "enemies": 0, "enemy_problems": [], "worst": worst}
