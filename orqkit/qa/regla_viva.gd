extends "res://kit/rule_base.gd"
## Regla viva de ejemplo (la usa el agente simulado en plataformas, runner, hordas...): cada moneda
## (o cada enemigo vencido) el heroe va un 4 % mas rapido, hasta un 40 %; al recibir dano lo pierde.


func on_start(st: Dictionary) -> void:
	st["say"] = "Cada moneda te acelera"


func on_coin(st: Dictionary, _data: Dictionary) -> void:
	_acelera(st)


func on_stomp(st: Dictionary, _data: Dictionary) -> void:
	_acelera(st)


func on_hurt(st: Dictionary, _data: Dictionary) -> void:
	st["tune"]["speed"] = 1.0


func _acelera(st: Dictionary) -> void:
	var v: float = minf(1.4, float(st["tune"].get("speed", 1.0)) + 0.04)
	if v >= 1.4 and float(st["tune"].get("speed", 1.0)) < 1.4:
		st["say"] = "\u00a1Velocidad maxima!"
	st["tune"]["speed"] = v
