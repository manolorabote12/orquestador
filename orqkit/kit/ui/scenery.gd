class_name Scenery
extends Node2D
## Decorado de reserva (si la IA no ha pintado fondo de nivel) para escenas de combate y de vista lateral: cielo en degradado, sol o luna,
## tres capas de montes, arboles en el horizonte, nubes que pasan y suelo con vetas. Usa los
## colores del juego (sky, ground, solid) y una semilla para que cada juego tenga su paisaje.
##   var s: Scenery = Scenery.make(Rect2(-700, -600, 1400, 1500), 200.0, 7)

var area: Rect2 = Rect2(-700, -600, 1400, 1500)
var ground_y: float = 200.0
var seed_n: int = 1
## Con fondo ilustrado (Look) solo hace falta el suelo: el resto lo pinta la IA.
var only_ground: bool = false
var _t: float = 0.0
var _hills: Array = []


static func make(rect: Rect2, ground: float, seed_value: int = 1) -> Scenery:
	var s: Scenery = Scenery.new()
	s.name = "Scenery"
	s.area = rect
	s.ground_y = ground
	s.seed_n = seed_value
	s.z_index = -10
	return s


func _ready() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_n
	for layer: int in 3:
		var pts: Array = []
		var n: int = 9 + layer * 3
		for i: int in n + 1:
			pts.append(rng.randf_range(0.25, 1.0))
		_hills.append(pts)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var sky: Color = Kit.color("sky", Color("#7ec8e3"))
	var ground: Color = Kit.color("ground", Kit.color("solid", Color("#4f6d3a")))
	var top: Color = sky.darkened(0.25)
	var low: Color = sky.lightened(0.25)
	if only_ground:
		draw_rect(Rect2(Vector2(area.position.x, ground_y), Vector2(area.size.x, area.end.y - ground_y)), ground.darkened(0.15))
		draw_rect(Rect2(Vector2(area.position.x, ground_y), Vector2(area.size.x, 14.0)), ground.lightened(0.18))
		return
	## Cielo.
	var bands: int = 12
	var h: float = ground_y - area.position.y
	for i: int in bands:
		var y0: float = area.position.y + h * float(i) / float(bands)
		draw_rect(Rect2(Vector2(area.position.x, y0), Vector2(area.size.x, h / float(bands) + 1.0)), top.lerp(low, float(i) / float(bands - 1)))
	## Sol (o luna si el cielo es oscuro).
	var night: bool = sky.get_luminance() < 0.3
	var sun: Vector2 = Vector2(area.position.x + area.size.x * 0.72, area.position.y + h * 0.28)
	draw_circle(sun, 90.0, Color(1, 1, 0.85, 0.12))
	draw_circle(sun, 56.0, Color("#fff3c4") if not night else Color("#e8eef7"))
	## Nubes.
	for c: int in 4:
		var cx: float = fmod(float(c) * 410.0 + _t * (12.0 + float(c) * 4.0), area.size.x + 400.0) + area.position.x - 200.0
		var cy: float = area.position.y + h * (0.15 + 0.12 * float(c % 2))
		var cc: Color = Color(1, 1, 1, 0.55 if not night else 0.15)
		draw_circle(Vector2(cx, cy), 34.0, cc)
		draw_circle(Vector2(cx + 38.0, cy + 6.0), 28.0, cc)
		draw_circle(Vector2(cx - 36.0, cy + 8.0), 24.0, cc)
	## Montes en tres capas (los de lejos mas claros).
	for layer: int in _hills.size():
		var pts: Array = _hills[layer]
		var col: Color = ground.lerp(low, 0.65 - 0.22 * float(layer)).darkened(0.05 * float(layer))
		var amp: float = h * (0.42 - 0.1 * float(layer))
		var poly: PackedVector2Array = PackedVector2Array([Vector2(area.position.x, ground_y)])
		for i2: int in pts.size():
			var x: float = area.position.x + area.size.x * float(i2) / float(pts.size() - 1)
			poly.append(Vector2(x, ground_y - amp * float(pts[i2])))
		poly.append(Vector2(area.end.x, ground_y))
		draw_colored_polygon(poly, col)
	## Arboles en el horizonte.
	var tree: Color = ground.darkened(0.35)
	for t: int in 16:
		var tx: float = area.position.x + 40.0 + float(t) * area.size.x / 16.0 + sin(float(t) * 7.3) * 30.0
		var th: float = 50.0 + 30.0 * absf(sin(float(t) * 3.1))
		draw_rect(Rect2(Vector2(tx - 4.0, ground_y - th * 0.4), Vector2(8.0, th * 0.4)), tree.darkened(0.2))
		draw_colored_polygon(PackedVector2Array([Vector2(tx - th * 0.32, ground_y - th * 0.3), Vector2(tx, ground_y - th), Vector2(tx + th * 0.32, ground_y - th * 0.3)]), tree)
	## Suelo.
	draw_rect(Rect2(Vector2(area.position.x, ground_y), Vector2(area.size.x, area.end.y - ground_y)), ground.darkened(0.15))
	draw_rect(Rect2(Vector2(area.position.x, ground_y), Vector2(area.size.x, 14.0)), ground.lightened(0.18))
	for v: int in 18:
		var vy: float = ground_y + 30.0 + float(v % 6) * 45.0
		var vx: float = area.position.x + fmod(float(v) * 233.0, area.size.x)
		draw_line(Vector2(vx, vy), Vector2(vx + 60.0, vy), ground.darkened(0.3), 4.0)
