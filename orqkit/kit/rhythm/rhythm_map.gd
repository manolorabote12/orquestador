extends RefCounted
## Analizador de ritmo: comprueba SIN jugar que una cancion es justa.
## 1 - Filas de 4 letras ("x" nota, "." nada); entre 16 y 400 notas.
## 2 - Como mucho 2 notas a la vez (dos pulgares).
## 3 - En un mismo carril, al menos 0,2 s entre notas (da tiempo a levantar el dedo).
## 4 - Tempo entre 70 y 190, velocidad de caida razonable y aciertos pedidos de 50 % a 90 %.


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var map: Array = level.get("map", [])
	var bpm: float = float(level.get("bpm", 110.0))
	var step: float = 30.0 / maxf(bpm, 1.0)
	var notes: int = 0
	var last: Array[int] = [-99, -99, -99, -99]
	for i: int in map.size():
		var r: String = str(map[i])
		if r.length() != 4 or not _only(r, "x."):
			if not issues.has("rhythm_bad_rows"):
				issues.append("rhythm_bad_rows")
			continue
		var n_row: int = r.count("x")
		notes += n_row
		if n_row > 2 and not issues.has("rhythm_chord"):
			issues.append("rhythm_chord")
		for l: int in 4:
			if r[l] == "x":
				if float(i - last[l]) * step < 0.2 and not issues.has("rhythm_too_dense"):
					issues.append("rhythm_too_dense")
				last[l] = i
	if notes < 16:
		issues.append("rhythm_short")
	if notes > 400:
		issues.append("rhythm_long")
	if bpm < 70.0 or bpm > 190.0:
		issues.append("rhythm_bpm")
	var speed: float = float(level.get("speed", 900.0))
	if speed < 450.0 or speed > 1700.0:
		issues.append("rhythm_speed")
	var t: float = float(level.get("target", 0.7))
	if t < 0.5 or t > 0.9:
		issues.append("rhythm_target")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": notes, "enemies": 0, "enemy_problems": []}


static func _only(s: String, allowed: String) -> bool:
	for c: String in s:
		if not allowed.contains(c):
			return false
	return true
