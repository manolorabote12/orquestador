extends Node
## Captura de pantalla: el bot corre por el nivel 1 y se guardan varias capturas.
func _ready() -> void:
	var game: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(game)
	var player: PlayerPlatformer = game.get("player")
	await get_tree().create_timer(0.6).timeout
	Input.action_press("move_right")
	var shots: Array[float] = [1.1, 2.05, 4.3]
	var t: float = 0.0
	var idx: int = 0
	while idx < shots.size():
		await get_tree().process_frame
		t += get_process_delta_time()
		if player.is_on_floor() and int(t * 10.0) % 9 == 0:
			Input.action_press("jump")
		elif int(t * 10.0) % 9 == 4:
			Input.action_release("jump")
		if t >= shots[idx]:
			var img: Image = get_viewport().get_texture().get_image()
			img.save_png("user://shot_%d.png" % idx)
			idx += 1
	get_tree().quit()
