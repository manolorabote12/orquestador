extends "res://kit/rule_base.gd"
## Regla viva de ejemplo (solo velocidad; la usa el agente simulado en los generos de escena):
## tras perder una vida, 3 segundos de camara lenta para recolocarse.


func on_death(st: Dictionary, _data: Dictionary) -> void:
	st["tune"]["game_speed"] = 0.7
	st["data"]["lenta"] = 3.0
	st["say"] = "Camara lenta"


func on_step(st: Dictionary, dt: float) -> void:
	var left: float = float(st["data"].get("lenta", 0.0))
	if left <= 0.0:
		return
	left -= dt
	st["data"]["lenta"] = left
	if left <= 0.0:
		st["tune"]["game_speed"] = 1.0
