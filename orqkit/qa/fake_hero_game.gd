extends Node2D
## Juego minimo para probar giros genericos (fantasma): un heroe que se mueve y el contrato basico.

var player: Node2D
var finished: bool = false
var failed: bool = false
var deaths: int = 0


func _ready() -> void:
	player = Node2D.new()
	player.name = "Player"
	var spr: Sprite2D = Sprite2D.new()
	spr.texture = PlaceholderTexture2D.new()
	player.add_child(spr)
	add_child(player)


func bot_state() -> Dictionary:
	return {"pos": player.global_position, "deaths": deaths, "finished": finished, "failed": failed}
