extends CanvasLayer
## Controles tactiles: izquierda y derecha abajo a la izquierda, salto abajo a la derecha.
## Usan TouchScreenButton con accion: multitactil real y se puede deslizar el dedo entre botones.
## Runner: sin flechas (se corre solo); se salta tocando cualquier parte de la mitad de abajo.

var color_idle: Color = Color(1, 1, 1, 0.16)
var color_down: Color = Color(1, 1, 1, 0.34)

var _buttons: Array[TouchScreenButton] = []
var _flyer: bool = false


func _ready() -> void:
	layer = 10
	var runner: bool = float(Kit.param("player.auto_run", 0.0)) > 0.5
	_flyer = float(Kit.param("player.flap", 0.0)) > 0.5
	if runner or _flyer:
		_make_tap_zone()
	else:
		_make_button("move_left", "left")
		_make_button("move_right", "right")
	## Volador: toda la pantalla es el boton (sin boton de salto).
	if not _flyer:
		_make_button("jump", "jump")
	## Boton de disparo solo si el juego lo usa.
	if float(Kit.param("player.shoot", 0.0)) > 0.5:
		_make_button("shoot", "fire")
	get_viewport().size_changed.connect(_layout)
	_layout()


func _make_button(action: String, kind: String) -> void:
	var b: TouchScreenButton = TouchScreenButton.new()
	b.name = kind
	b.action = action
	b.passby_press = true
	b.visibility_mode = TouchScreenButton.VISIBILITY_ALWAYS
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = 78.0
	b.shape = shape
	b.shape_centered = true
	b.shape_visible = false
	var look: Polygon2D = Polygon2D.new()
	look.name = "Look"
	look.color = color_idle
	look.polygon = _circle(70.0, 28)
	b.add_child(look)
	var icon: Polygon2D = Polygon2D.new()
	icon.color = Color(1, 1, 1, 0.75)
	if kind == "left":
		icon.polygon = PackedVector2Array([Vector2(-22, 0), Vector2(14, -24), Vector2(14, 24)])
	elif kind == "right":
		icon.polygon = PackedVector2Array([Vector2(22, 0), Vector2(-14, -24), Vector2(-14, 24)])
	elif kind == "fire":
		icon.polygon = LevelBuilder._circle(16.0, 12)
		icon.color = Color(1.0, 0.85, 0.5, 0.85)
	else:
		icon.polygon = PackedVector2Array([Vector2(0, -26), Vector2(26, 14), Vector2(-26, 14)])
	b.add_child(icon)
	b.pressed.connect(func() -> void: look.color = color_down)
	b.released.connect(func() -> void: look.color = color_idle)
	add_child(b)
	_buttons.append(b)


## 1 - Zona invisible de salto: de la franja del HUD hacia abajo, todo menos la columna de botones.
func _make_tap_zone() -> void:
	var z: TouchScreenButton = TouchScreenButton.new()
	z.name = "tap"
	z.action = "jump"
	z.visibility_mode = TouchScreenButton.VISIBILITY_ALWAYS
	z.shape = RectangleShape2D.new()
	z.shape_centered = false
	z.shape_visible = false
	add_child(z)
	_buttons.append(z)


func _layout() -> void:
	var size: Vector2 = get_viewport().get_visible_rect().size
	var y: float = size.y - 130.0
	for b: TouchScreenButton in _buttons:
		if b.name == "tap":
			var top: float = 240.0
			## 2 - La columna derecha queda para los botones de salto y fuego.
			var room: float = 250.0 if not _flyer or float(Kit.param("player.shoot", 0.0)) > 0.5 else 0.0
			(b.shape as RectangleShape2D).size = Vector2(size.x - room, size.y - top)
			b.position = Vector2(0.0, top)
			continue
		if b.name == "left":
			b.position = Vector2(110.0, y)
		elif b.name == "right":
			b.position = Vector2(290.0, y)
		elif b.name == "fire":
			b.position = Vector2(size.x - 120.0, y - 170.0)
		else:
			b.position = Vector2(size.x - 120.0, y)


func _circle(radius: float, points: int) -> PackedVector2Array:
	var arr: PackedVector2Array = PackedVector2Array()
	for i: int in points:
		var a: float = TAU * float(i) / float(points)
		arr.append(Vector2(cos(a), sin(a)) * radius)
	return arr
