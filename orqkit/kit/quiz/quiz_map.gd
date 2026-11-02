extends RefCounted
## Analizador del juego de preguntas: comprueba SIN jugar que un nivel es justo.
## 1 - Entre 3 y 12 preguntas, una Q en el mapa por pregunta.
## 2 - Cada pregunta tiene texto, 4 respuestas distintas y la buena entre ellas.
## 3 - Los aciertos para pasar no superan el numero de preguntas; el tiempo da para leer.


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var qs: Variant = level.get("questions", [])
	var questions: Array = qs if qs is Array else []
	var map: Array = level.get("map", [])
	var qcount: int = str(map[0]).count("Q") if not map.is_empty() else 0
	if questions.size() < 3 or questions.size() > 12:
		issues.append("quiz_count")
	if qcount != questions.size():
		issues.append("quiz_map_mismatch")
	for q: Variant in questions:
		if not q is Dictionary:
			issues.append("quiz_bad_question")
			break
		var d: Dictionary = q
		var a: Variant = d.get("a", [])
		if str(d.get("q", "")).length() < 4 or not a is Array or (a as Array).size() != 4:
			issues.append("quiz_bad_question")
			break
		var seen: Dictionary = {}
		for o: Variant in a:
			seen[str(o).strip_edges().to_lower()] = true
		if seen.size() != 4 or str(a[0]).strip_edges() == "":
			issues.append("quiz_repeated_answers")
			break
		var ok: int = int(d.get("ok", -1))
		if ok < 0 or ok > 3:
			issues.append("quiz_bad_answer")
			break
	if int(level.get("pass", 1)) > questions.size() or int(level.get("pass", 1)) < 1:
		issues.append("quiz_pass")
	if float(level.get("time", 20.0)) < 6.0:
		issues.append("quiz_time")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": questions.size(), "enemies": 0, "enemy_problems": []}
