extends RefCounted
## Analizador de topos: comprueba SIN jugar que un nivel es justo.
## 1 - Entre 3 y 12 agujeros ("o"), filas del mismo ancho.
## 2 - Da tiempo a reaccionar: cada bicho se queda al menos 0,6 s fuera.
## 3 - Salen de sobra: los enemigos esperados en el tiempo del nivel son al menos 1,4 veces los
##     golpes que pide (los voladores y el heroe no cuentan entero).


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var map: Array = level.get("map", [])
	var holes: int = 0
	for r: Variant in map:
		holes += str(r).count("o")
		if str(r).length() != str(map[0]).length() and not issues.has("moles_bad_rows"):
			issues.append("moles_bad_rows")
	if holes < 3 or holes > 12:
		issues.append("moles_holes")
	if float(level.get("pop", 0.0)) < 0.6:
		issues.append("moles_too_fast")
	var interval: float = maxf(float(level.get("interval", 1.0)), 0.1)
	var expected: float = float(level.get("duration", 0.0)) / interval * (1.0 - float(level.get("friend", 0.0))) * 0.9
	if expected < float(level.get("target", 0)) * 1.4:
		issues.append("moles_target_high")
	if int(level.get("target", 0)) < 5:
		issues.append("moles_target_low")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": int(level.get("target", 0)), "enemies": 0, "enemy_problems": []}
