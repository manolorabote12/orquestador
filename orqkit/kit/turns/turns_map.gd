extends RefCounted
## Analizador del RPG por turnos: comprueba SIN jugar que el nivel es justo.
## 1 - De 2 a 7 oleadas, de 1 a 3 enemigos cada una (W, S, F o B).
## 2 - Juega la partida con la politica de una persona sensata (TurnsLogic.policy): con dano medio
##     tiene que ganar con al menos un 20 % de vida, y tambien con mala suerte (pegando un 10 %
##     menos y recibiendo un 10 % mas).


static func analyze(level: Dictionary) -> Dictionary:
	## Modo equipo (plantilla por datos): su propio analizador.
	if TurnsParty.wanted(level):
		return TurnsParty.analyze(level)
	var issues: Array[String] = []
	var waves: Array = level.get("map", [])
	var enemies: int = 0
	if waves.size() < 2 or waves.size() > 7:
		issues.append("turns_waves")
	for w: Variant in waves:
		var row: String = str(w)
		if row.length() < 1 or row.length() > 3:
			if not issues.has("turns_wave_size"):
				issues.append("turns_wave_size")
		for c: String in row:
			if not TurnsLogic.ENEMIES.has(c) and not issues.has("turns_bad_enemy"):
				issues.append("turns_bad_enemy")
		enemies += row.length()
	var sim: Dictionary = {}
	if issues.is_empty():
		sim = TurnsLogic.simulate(waves, float(level.get("hero_hp", 100.0)), float(level.get("hero_atk", 20.0)),
			int(level.get("potions", 2)), float(level.get("mult", 1.0)))
		var bad: Dictionary = TurnsLogic.simulate(waves, float(level.get("hero_hp", 100.0)), float(level.get("hero_atk", 20.0)),
			int(level.get("potions", 2)), float(level.get("mult", 1.0)), true)
		if not bool(sim["won"]) or float(sim["hp_left"]) < 0.2 or not bool(bad["won"]):
			issues.append("turns_too_hard")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": enemies, "enemies": enemies,
		"enemy_problems": [], "sim": sim}
