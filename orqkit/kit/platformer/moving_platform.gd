class_name MovingPlatform
extends AnimatableBody2D
## Plataforma que va y viene en horizontal (letra = en el mapa). El jugador viaja encima.
## Se mueve con una curva suave: frena en los extremos para que sea facil subir y bajar.

var amplitude: float = 96.0
var period: float = 4.0
var origin: Vector2 = Vector2.ZERO
var width: float = 128.0
var height: float = 64.0
var _t: float = 0.0


func setup(center: Vector2, width_px: float, height_px: float, amp: float, col: Color, tex: Texture2D = null) -> void:
	## Primero sync_to_physics: activarlo despues devolveria la plataforma a la posicion fisica (0, 0).
	sync_to_physics = true
	origin = center
	position = center
	width = width_px
	height = height_px
	amplitude = amp
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(width_px, height_px)
	shape.shape = rect
	shape.one_way_collision = true
	add_child(shape)
	var poly: Polygon2D = Polygon2D.new()
	poly.color = col if tex == null else Color.WHITE
	poly.polygon = PackedVector2Array([Vector2(-width_px * 0.5, -height_px * 0.5), Vector2(width_px * 0.5, -height_px * 0.5),
		Vector2(width_px * 0.5, height_px * 0.5), Vector2(-width_px * 0.5, height_px * 0.5)])
	if tex != null:
		poly.texture = tex
		poly.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		var k: float = float(tex.get_width()) / height_px
		var uv: PackedVector2Array = PackedVector2Array()
		for v: Vector2 in poly.polygon:
			uv.append((v + Vector2(width_px, height_px) * 0.5) * k)
		poly.uv = uv
	add_child(poly)
	var lip: Polygon2D = Polygon2D.new()
	lip.color = Color(1, 1, 1, 0.22)
	lip.polygon = PackedVector2Array([Vector2(-width_px * 0.5, -height_px * 0.5), Vector2(width_px * 0.5, -height_px * 0.5),
		Vector2(width_px * 0.5, -height_px * 0.36), Vector2(-width_px * 0.5, -height_px * 0.36)])
	add_child(lip)


func _physics_process(delta: float) -> void:
	_t += delta
	## Posicion completa en cada paso: con sync_to_physics el cuerpo conserva la "y" del motor
	## de fisica si solo se cambia la "x" (y empezaria en 0).
	position = Vector2(origin.x + sin(_t * TAU / period) * amplitude, origin.y)


func left() -> float:
	return global_position.x - width * 0.5


func right() -> float:
	return global_position.x + width * 0.5


func top() -> float:
	return origin.y - height * 0.5
