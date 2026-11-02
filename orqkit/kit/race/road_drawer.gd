class_name RoadDrawer
extends Node2D
## Dibuja solo el tramo de carretera que se ve: cesped a rayas, asfalto, bordillos rojos y
## blancos, lineas de carril discontinuas, salida y meta a cuadros.

var game: Node2D


func _draw() -> void:
	if game == null:
		return
	var cam_y: float = -float(game.get("d")) - 330.0
	var consts: Dictionary = (game.get_script() as Script).get_script_constant_map()
	var row: float = consts["ROW"]
	var lane: float = consts["LANE_W"]
	var half: float = lane * 2.0
	var n_rows: int = (game.get("rows") as Array).size()
	var first: int = maxi(int(floor((-cam_y - 900.0) / row)), -4)
	var last: int = mini(int(ceil((-cam_y + 900.0) / row)), n_rows + 8)
	var grass: Color = Kit.color("sky", Color("#1b2a41")).lightened(0.18)
	var asphalt: Color = Color(0.2, 0.21, 0.24)
	for i: int in range(first, last):
		var d0: float = float(i) * row
		var d1: float = d0 + row
		var c0: float = game.call("center_at", d0)
		var c1: float = game.call("center_at", d1)
		var y0: float = -d0
		var y1: float = -d1
		draw_rect(Rect2(c0 - 1200.0, y1, 2400.0, row), grass if i % 2 == 0 else grass.darkened(0.06))
		draw_colored_polygon(PackedVector2Array([Vector2(c0 - half, y0), Vector2(c0 + half, y0), Vector2(c1 + half, y1), Vector2(c1 - half, y1)]), asphalt)
		var kerb: Color = Color(0.9, 0.2, 0.2) if i % 2 == 0 else Color(0.95, 0.95, 0.95)
		for s: float in [-1.0, 1.0]:
			draw_colored_polygon(PackedVector2Array([Vector2(c0 + s * half, y0), Vector2(c0 + s * (half + 16.0), y0), Vector2(c1 + s * (half + 16.0), y1), Vector2(c1 + s * half, y1)]), kerb)
		for k: int in [-1, 0, 1]:
			var x0: float = c0 + float(k) * lane
			var x1: float = lerpf(c0, c1, 0.5) + float(k) * lane
			draw_line(Vector2(x0, y0), Vector2(x1, y0 - row * 0.5), Color(1, 1, 1, 0.55), 5.0)
		if i == 0 or i == n_rows:
			for q: int in 16:
				var col: Color = Color.WHITE if (q + (0 if i == 0 else 1)) % 2 == 0 else Color.BLACK
				draw_rect(Rect2(c0 - half + float(q) * half / 8.0, y0 - 14.0, half / 8.0, 14.0), col)
