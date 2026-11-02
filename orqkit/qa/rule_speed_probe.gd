extends "res://kit/rule_base.gd"
## Regla viva de prueba (solo velocidad): todo va mas lento al empezar; un mando que no existe se ignora.


func on_start(st: Dictionary) -> void:
	st["tune"]["game_speed"] = 0.8
	st["tune"]["jump"] = 1.3
