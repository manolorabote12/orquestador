extends RefCounted
## Palabras con letras (estilo Wordscapes / crucigrama de letras): con las letras de la rueda se
## forman palabras que rellenan un crucigrama. Reglas, construccion del crucigrama, bot y analizador.
## 1 - Nivel (game.json -> levels[i]): "len" (letras de la rueda, 4-7), "words" (palabras del
##     crucigrama, 3-9), "rank" (0 = palabras muy usadas, 1 = mas raras) y "seed". El mapa es
##     ["letras"]: el crucigrama se monta con el diccionario del idioma del jugador (kit/words), asi
##     el mismo nivel vale en todos los idiomas.
## 2 - Una palabra de la rueda (cada letra una vez) que esta en el crucigrama se escribe en el;
##     si no esta pero existe, es una palabra extra (+1 moneda). Se gana al completar el crucigrama.
## 3 - Pista: descubre una letra (3 por nivel). Barajar: cambia el orden de la rueda.

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
const POOL: int = 14000


## Cuantas veces sale cada letra.
static func counts(w: String) -> Dictionary:
	var c: Dictionary = {}
	for ch: String in w:
		c[ch] = int(c.get(ch, 0)) + 1
	return c


static func fits(w: String, have: Dictionary) -> bool:
	var c: Dictionary = {}
	for ch: String in w:
		c[ch] = int(c.get(ch, 0)) + 1
		if int(c[ch]) > int(have.get(ch, 0)):
			return false
	return true


## Palabras (3 letras o mas) que se forman con las letras de root, las comunes primero.
static func subwords(d: Dictionary, root: String) -> Array:
	var have: Dictionary = counts(root)
	var out: Array = []
	var valid: Dictionary = d["valid"]
	for n: int in range(3, root.length() + 1):
		for w: Variant in (d["by_len"] as Dictionary).get(n, []):
			if int(valid[w]) > POOL:
				break
			if fits(str(w), have):
				out.append(w)
	return out


## Crucigrama: coloca las palabras cruzandose (sin tocarse de lado). {celda: letra}, y por
## palabra [inicio, direccion].
static func layout(words: Array) -> Dictionary:
	var grid: Dictionary = {}
	var place: Dictionary = {}
	if words.is_empty():
		return {"grid": grid, "place": place}
	var first: String = words[0]
	for i: int in first.length():
		grid[Vector2i(i, 0)] = first[i]
	place[first] = [Vector2i(0, 0), Vector2i(1, 0)]
	for k: int in range(1, words.size()):
		var w: String = words[k]
		var best: Array = []
		var bs: float = -INF
		for cell: Vector2i in grid.keys():
			for i2: int in w.length():
				if w[i2] != str(grid[cell]):
					continue
				for dir: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
					var start: Vector2i = cell - dir * i2
					var cross: int = _try(grid, w, start, dir)
					if cross <= 0:
						continue
					## Mejor: mas cruces y crucigrama compacto (cerca del centro).
					var c0: Vector2 = Vector2(start) + Vector2(dir) * float(w.length()) * 0.5
					var sc: float = float(cross) * 10.0 - c0.length() * 0.3
					if sc > bs:
						bs = sc
						best = [start, dir]
		if best.is_empty():
			continue
		for i3: int in w.length():
			grid[(best[0] as Vector2i) + (best[1] as Vector2i) * i3] = w[i3]
		place[w] = best
	return {"grid": grid, "place": place}


## Cuantas letras cruza la palabra en ese sitio (-1 si no cabe).
static func _try(grid: Dictionary, w: String, start: Vector2i, dir: Vector2i) -> int:
	var side: Vector2i = Vector2i(dir.y, dir.x)
	if grid.has(start - dir) or grid.has(start + dir * w.length()):
		return -1
	var cross: int = 0
	for i: int in w.length():
		var c: Vector2i = start + dir * i
		if grid.has(c):
			if str(grid[c]) != w[i]:
				return -1
			cross += 1
		elif grid.has(c + side) or grid.has(c - side):
			return -1
	if cross == w.length():
		return -1
	return cross


## El nivel montado en un idioma: rueda, palabras del crucigrama y donde va cada una.
static func build(level: Dictionary, lang: String, retry: int = 0) -> Dictionary:
	var d: Dictionary = D.load_lang(lang)
	var n: int = clampi(int(level.get("len", 5)), 4, 7)
	var need: int = clampi(int(level.get("words", 5)), 3, 9)
	var rank: float = clampf(float(level.get("rank", 0.2)), 0.0, 1.0)
	var pool: Array = (d["targets"] as Dictionary).get(n, [])
	if pool.is_empty():
		return {}
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_of(level) * 6007 + retry * 911 + n
	var top: int = clampi(int(200.0 + rank * 2500.0), 1, pool.size())
	var targets_set: Dictionary = {}
	for tw: Variant in (d["targets"] as Dictionary).get(3, []) + (d["targets"] as Dictionary).get(4, []) + (d["targets"] as Dictionary).get(5, []) + (d["targets"] as Dictionary).get(6, []) + (d["targets"] as Dictionary).get(7, []):
		targets_set[tw] = true
	for attempt: int in 60:
		var root: String = pool[rng.randi_range(0, top - 1)]
		var subs: Array = subwords(d, root)
		## Las mas usadas primero (de cualquier largo): asi salen palabras que todo el mundo conoce.
		var valid: Dictionary = d["valid"]
		subs.sort_custom(func(a: String, b2: String) -> bool: return int(valid[a]) < int(valid[b2]))
		## Las del crucigrama: la raiz y las mas comunes que pueden ser solucion (las raras, extra).
		var chosen: Array = [root]
		for w: Variant in subs:
			if chosen.size() >= need + 3:
				break
			if str(w) != root and targets_set.has(w):
				chosen.append(w)
		if chosen.size() < need:
			continue
		chosen.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
		var lay: Dictionary = layout(chosen)
		var placed: Array = []
		for w2: Variant in chosen:
			if (lay["place"] as Dictionary).has(w2):
				placed.append(w2)
		if placed.size() < need:
			continue
		placed = placed.slice(0, need)
		lay = layout(placed)
		if (lay["place"] as Dictionary).size() < need:
			continue
		var letters: Array = []
		for ch: String in root:
			letters.append(ch)
		## Rueda barajada (que la raiz no se lea de corrido).
		for i: int in range(letters.size() - 1, 0, -1):
			var j: int = rng.randi_range(0, i)
			var tmp: Variant = letters[i]
			letters[i] = letters[j]
			letters[j] = tmp
		return {"root": root, "letters": letters, "words": lay["place"].keys(), "place": lay["place"], "grid": lay["grid"], "extra": subs}
	return {}


static func new_state(level: Dictionary, lang: String, retry: int = 0) -> Dictionary:
	var b: Dictionary = build(level, lang, retry)
	var st: Dictionary = {"b": b, "lang": D.pick(lang), "found": {}, "bonus": {}, "revealed": {}, "hints": 3, "won": false, "misses": 0,
		"rng": RandomNumberGenerator.new()}
	(st["rng"] as RandomNumberGenerator).seed = seed_of(level) + retry
	st["rules"] = Rules.load_rules(level)
	Rules.hook(st, "on_start")
	return st


## Envia una palabra: "word" (del crucigrama), "bonus" (extra nueva), "again" (ya estaba) o "".
static func submit(st: Dictionary, w: String) -> String:
	var r: String = _submit(st, w)
	Rules.hook(st, "on_word", [w, r])
	return r


static func _submit(st: Dictionary, w: String) -> String:
	var b: Dictionary = st["b"]
	if b.is_empty() or w.length() < 3 or not fits(w, counts(str(b["root"]))):
		st["misses"] = int(st["misses"]) + 1
		return ""
	if (b["place"] as Dictionary).has(w):
		if (st["found"] as Dictionary).has(w):
			return "again"
		st["found"][w] = true
		if (st["found"] as Dictionary).size() >= (b["place"] as Dictionary).size():
			st["won"] = true
		return "word"
	if D.is_word(str(st["lang"]), w):
		if (st["bonus"] as Dictionary).has(w):
			return "again"
		st["bonus"][w] = true
		return "bonus"
	st["misses"] = int(st["misses"]) + 1
	return ""


## Celdas visibles: las de palabras encontradas y las descubiertas con pistas.
static func shown(st: Dictionary) -> Dictionary:
	var out: Dictionary = (st["revealed"] as Dictionary).duplicate()
	var b: Dictionary = st["b"]
	for w: Variant in st["found"]:
		var pl: Array = b["place"][w]
		for i: int in str(w).length():
			out[(pl[0] as Vector2i) + (pl[1] as Vector2i) * i] = true
	return out


## Pista: descubre la primera letra que falte de la primera palabra sin encontrar.
static func hint(st: Dictionary) -> Vector2i:
	if int(st["hints"]) <= 0:
		return Vector2i(-999, -999)
	var b: Dictionary = st["b"]
	var vis: Dictionary = shown(st)
	for w: Variant in b["words"]:
		if (st["found"] as Dictionary).has(w):
			continue
		var pl: Array = b["place"][w]
		for i: int in str(w).length():
			var c: Vector2i = (pl[0] as Vector2i) + (pl[1] as Vector2i) * i
			if not vis.has(c):
				st["revealed"][c] = true
				st["hints"] = int(st["hints"]) - 1
				return c
	return Vector2i(-999, -999)


## Lo que haria el bot: la siguiente palabra del crucigrama sin encontrar.
static func bot_word(st: Dictionary) -> String:
	for w: Variant in st["b"]["words"]:
		if not (st["found"] as Dictionary).has(w):
			return str(w)
	return ""


## Analizador: el crucigrama se monta en los 6 idiomas con todas sus palabras.
static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var n: int = int(level.get("len", 5))
	if n < 4 or n > 7:
		issues.append("letters_len")
	var need: int = int(level.get("words", 5))
	if need < 3 or need > 9:
		issues.append("letters_words")
	if issues.is_empty():
		for l: String in D.LANGS:
			var b: Dictionary = build(level, l)
			if b.is_empty() or (b["place"] as Dictionary).size() < need:
				issues.append("letters_no_puzzle_" + l)
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": need, "enemies": 0, "enemy_problems": []}
