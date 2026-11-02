extends "res://kit/rule_base.gd"
## Regla viva de prueba (generos de escena): al empezar salta un poco mas y avisa; cada moneda
## acelera al heroe; pide un mando que no existe (se ignora) y uno fuera de limites (se recorta).


func on_start(st: Dictionary) -> void:
	st["tune"]["jump"] = 1.15
	st["tune"]["no_existe"] = 9.0
	st["say"] = "Supersalto"


func on_coin(st: Dictionary, _data: Dictionary) -> void:
	st["tune"]["speed"] = float(st["tune"]["speed"]) + 0.1


func on_event(st: Dictionary, ev: String, _data: Dictionary) -> void:
	if ev == "probe_limite":
		st["tune"]["enemy_speed"] = 99.0


func on_step(st: Dictionary, _dt: float) -> void:
	st["data"]["pasos"] = int(st["data"].get("pasos", 0)) + 1
