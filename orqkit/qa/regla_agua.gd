extends "res://kit/rule_base.gd"
## Regla de ejemplo (caida): una de cada tres piezas es de AGUA. Al fijarse se derrama: cae por
## los huecos y se reparte a los lados hasta quedarse quieta. Rellena agujeros, asi que ayuda a
## borrar filas, pero hay que pensar donde soltarla.

const W: int = 10
const H: int = 20


func on_lock(st: Dictionary, cells: Array) -> void:
	if int(st["pieces"]) % 3 != 0:
		return
	for c: Vector2i in cells:
		st["grid"][c.y][c.x] = "W"


func on_step(st: Dictionary, dt: float) -> void:
	st["water_t"] = float(st.get("water_t", 0.0)) + dt
	if float(st["water_t"]) < 0.06:
		return
	st["water_t"] = 0.0
	var grid: Array = st["grid"]
	var busy: Array = st.get("busy", [])
	var y: int = H - 2
	while y >= 0:
		for x: int in W:
			if str(grid[y][x]) != "W":
				continue
			if _free(grid, busy, x, y + 1):
				grid[y + 1][x] = "W"
				grid[y][x] = ""
				continue
			var dir: int = 1 if rnd(st) < 0.5 else -1
			for d: int in [dir, -dir]:
				if _free(grid, busy, x + d, y) and _free(grid, busy, x + d, y + 1):
					grid[y][x + d] = "W"
					grid[y][x] = ""
					break
		y -= 1


func _free(grid: Array, busy: Array, x: int, y: int) -> bool:
	if x < 0 or x >= W or y < 0 or y >= H:
		return false
	return str(grid[y][x]) == "" and not busy.has(Vector2i(x, y))


func colors() -> Dictionary:
	return {"W": Color(0.25, 0.6, 1.0, 0.85)}
