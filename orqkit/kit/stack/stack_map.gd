extends RefCounted
## Analizador de apilar: comprueba SIN jugar que un nivel es justo.
## 1 - Altura entre 5 y 40 bloques (una S por bloque en el mapa).
## 2 - Bloque inicial entre 160 y 480 px y margen de "perfecto" entre 5 y 20 px.
## 3 - La velocidad final (con la subida por piso) no pasa de 820 px/s: se puede reaccionar.


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var target: int = int(level.get("target", 0))
	var map: Array = level.get("map", [])
	if target < 5 or target > 40:
		issues.append("stack_target")
	if map.is_empty() or str(map[0]).count("S") != target:
		issues.append("stack_map_mismatch")
	var w: float = float(level.get("width", 0.0))
	if w < 160.0 or w > 480.0:
		issues.append("stack_width")
	var p: float = float(level.get("perfect", 0.0))
	if p < 5.0 or p > 20.0:
		issues.append("stack_perfect")
	var top_speed: float = float(level.get("speed", 0.0)) * (1.0 + float(level.get("ramp", 0.0)) * float(target))
	if float(level.get("speed", 0.0)) < 120.0 or top_speed > 820.0:
		issues.append("stack_speed")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": target, "enemies": 0, "enemy_problems": []}
