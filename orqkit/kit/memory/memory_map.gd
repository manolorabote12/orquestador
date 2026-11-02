extends RefCounted
## Analizador de memoria: comprueba SIN jugar que un nivel es justo.
## 1 - Todas las filas miden lo mismo, entre 3 y 7 columnas y como mucho 7 filas; solo ".#".
## 2 - Numero par de cartas, entre 6 y 36.
## 3 - Intentos: el limite deja margen sobre lo que necesita alguien con buena memoria
##     (al menos 2 por pareja) y el par es alcanzable (al menos 1.3 por pareja).


static func analyze(level: Dictionary) -> Dictionary:
	var rows: Array[String] = []
	for r: Variant in level.get("map", []):
		rows.append(str(r))
	var issues: Array[String] = []
	var n: int = 0
	if rows.is_empty() or rows.size() > 7:
		issues.append("memory_bad_size")
	for r: String in rows:
		if r.length() != rows[0].length() or r.length() < 3 or r.length() > 7:
			if not issues.has("memory_bad_size"):
				issues.append("memory_bad_size")
		for ch: String in r:
			if not ".#".contains(ch) and not issues.has("memory_bad_char"):
				issues.append("memory_bad_char")
			if ch == ".":
				n += 1
	if n % 2 != 0:
		issues.append("memory_odd")
	if n < 6 or n > 36:
		issues.append("memory_count")
	var pairs: float = float(n) / 2.0
	if float(level.get("limit", 0)) < pairs * 2.0:
		issues.append("memory_tight_limit")
	if float(level.get("par", 0)) < pairs * 1.3:
		issues.append("memory_par_too_low")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": int(pairs), "enemies": 0, "enemy_problems": []}
