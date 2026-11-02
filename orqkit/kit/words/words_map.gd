extends RefCounted
## Sopa de letras (estilo Word Search): reglas, construccion de la cuadricula, bot y analizador.
## 1 - Nivel (game.json -> levels[i]): "words" (palabras a buscar, ya en el idioma del juego),
##     "size" (lado de la cuadricula, 6-10), "dirs" (1 = derecha y abajo, 2 = + diagonales,
##     3 = + al reves) y "seed". El mapa es solo ["sopa"]: la cuadricula se monta al jugar, asi
##     sirve en cualquier idioma (las palabras se traducen y se vuelven a colocar).
## 2 - Se arrastra en linea recta (8 direcciones) por encima de una palabra; si coincide (al
##     derecho o al reves), queda marcada. Se gana al encontrar todas.

const ALL_DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1),
	Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1), Vector2i(-1, 1)]
const FILL: String = "AEIOUSRNLTDCMPB"


## Palabra lista para la cuadricula: mayusculas, sin tildes (la \u00d1 se queda) ni espacios.
static func clean(w: String) -> String:
	var s: String = w.strip_edges().to_upper()
	var out: String = ""
	var from: String = "\u00c1\u00c0\u00c4\u00c2\u00c9\u00c8\u00cb\u00ca\u00cd\u00cc\u00cf\u00ce\u00d3\u00d2\u00d6\u00d4\u00da\u00d9\u00dc\u00db\u00c7"
	var to: String = "AAAAEEEEIIIIOOOOUUUUC"
	for i: int in s.length():
		var ch: String = s[i]
		var k: int = from.find(ch)
		if k >= 0:
			ch = to[k]
		if ch == "\u00df":
			ch = "SS"
		if ch != " " and ch != "-" and ch != "'" and ch != "." and ch != "\u2019":
			out += ch
	return out


static func dirs_for(level: int) -> Array[Vector2i]:
	var n: int = 2 if level <= 1 else (4 if level == 2 else 8)
	return ALL_DIRS.slice(0, n)


## Monta la cuadricula: {"grid": [String por fila], "size": n, "place": {palabra: [inicio, dir]}}.
## Si no caben, agranda el lado. Siempre igual con la misma semilla.
static func build(level: Dictionary) -> Dictionary:
	var words: Array[String] = []
	for w: Variant in level.get("words", []):
		var c: String = clean(str(w))
		if c.length() >= 2 and c.length() <= 12 and not words.has(c):
			words.append(c)
	words.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	var longest: int = words[0].length() if not words.is_empty() else 3
	var n: int = clampi(maxi(int(level.get("size", 8)), longest), 4, 14)
	var dirs: Array[Vector2i] = dirs_for(int(level.get("dirs", 2)))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	for grow: int in 6:
		var size: int = mini(14, n + grow)
		for attempt: int in 30:
			rng.seed = int(level.get("seed", 1)) * 7919 + attempt * 104729 + grow
			var cells: Dictionary = {}
			var place: Dictionary = {}
			var ok: bool = true
			for w: String in words:
				var done: bool = false
				for t: int in 200:
					var d: Vector2i = dirs[rng.randi_range(0, dirs.size() - 1)]
					var s: Vector2i = Vector2i(rng.randi_range(0, size - 1), rng.randi_range(0, size - 1))
					var e: Vector2i = s + d * (w.length() - 1)
					if e.x < 0 or e.y < 0 or e.x >= size or e.y >= size:
						continue
					var fits: bool = true
					for k: int in w.length():
						var p: Vector2i = s + d * k
						if cells.has(p) and cells[p] != w[k]:
							fits = false
							break
					if not fits:
						continue
					for k: int in w.length():
						cells[s + d * k] = w[k]
					place[w] = [s, d]
					done = true
					break
				if not done:
					ok = false
					break
			if ok:
				var letters: String = FILL
				for w: String in words:
					letters += w
				var grid: Array[String] = []
				for y: int in size:
					var row: String = ""
					for x: int in size:
						var p2: Vector2i = Vector2i(x, y)
						row += str(cells[p2]) if cells.has(p2) else letters[rng.randi_range(0, letters.length() - 1)]
					grid.append(row)
				return {"grid": grid, "size": size, "place": place, "words": words}
	return {"grid": [], "size": 0, "place": {}, "words": words}


## La palabra que hay en la linea de a a b (recta en 8 direcciones), o "" si no es recta.
static func read_line(grid: Array, a: Vector2i, b: Vector2i) -> String:
	var d: Vector2i = b - a
	if not (d.x == 0 or d.y == 0 or absi(d.x) == absi(d.y)):
		return ""
	var steps: int = maxi(absi(d.x), absi(d.y))
	var u: Vector2i = Vector2i(signi(d.x), signi(d.y))
	var out: String = ""
	for k: int in steps + 1:
		var p: Vector2i = a + u * k
		if p.y < 0 or p.y >= grid.size() or p.x < 0 or p.x >= str(grid[p.y]).length():
			return ""
		out += str(grid[p.y])[p.x]
	return out


## Que palabra (sin encontrar) se forma con la linea, al derecho o al reves; "" si ninguna.
static func check(st: Dictionary, a: Vector2i, b: Vector2i) -> String:
	var s: String = read_line(st["grid"], a, b)
	if s.length() < 2:
		return ""
	for w: Variant in st["words"]:
		if (st["found"] as Dictionary).has(w):
			continue
		if s == w or s.reverse() == w:
			return str(w)
	return ""


static func new_state(level: Dictionary) -> Dictionary:
	var b: Dictionary = build(level)
	b["found"] = {}
	b["misses"] = 0
	return b


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var words: Array = level.get("words", [])
	if words.size() < 3 or words.size() > 14:
		issues.append("words_count")
	var b: Dictionary = build(level)
	if (b["words"] as Array).size() != words.size():
		issues.append("words_dupe")
	for w: Variant in b["words"]:
		if str(w).length() > 12:
			issues.append("words_long")
			break
	if issues.is_empty():
		if int(b["size"]) == 0:
			issues.append("words_no_fit")
		else:
			## El bot encuentra cada palabra en su sitio.
			var st: Dictionary = b
			st["found"] = {}
			for w: Variant in b["place"]:
				var pl: Array = b["place"][w]
				var e: Vector2i = (pl[0] as Vector2i) + (pl[1] as Vector2i) * (str(w).length() - 1)
				if check(st, pl[0], e) != str(w):
					issues.append("words_misplaced")
					break
				st["found"][w] = true
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": words.size(), "enemies": 0, "enemy_problems": [],
		"par": 8 + words.size() * 7}
