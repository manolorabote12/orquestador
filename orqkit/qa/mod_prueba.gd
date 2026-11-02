extends "res://kit/mod_base.gd"
## Mod de prueba: cuenta eventos y, al empezar un nivel, muestra un texto y suelta particulas.

var starts: int = 0
var deaths: int = 0
var ticks: int = 0


func on_level_start() -> void:
	starts += 1
	toast("Mod activo")
	var p: Node2D = player()
	if p != null:
		burst(p.global_position, Color(1.0, 0.8, 0.2))


func on_event(event_name: String, _data: Dictionary) -> void:
	if event_name == "death":
		deaths += 1
		shake(8.0)
		flash_screen()


func on_tick(_delta: float) -> void:
	ticks += 1
