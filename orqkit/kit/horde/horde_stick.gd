class_name HordeStick
extends CanvasLayer
## Joystick virtual: pon el dedo en cualquier sitio por debajo del HUD y arrastra.
## La base aparece donde tocas; vector = direccion y fuerza (0..1). Multitactil: solo
## cuenta el primer dedo que lo activa.

const RADIUS: float = 96.0
const TOP: float = 220.0

var vector: Vector2 = Vector2.ZERO
## Zonas de pantalla donde no nace el joystick (botones de ataque de la arena, por ejemplo).
var blocked: Array[Rect2] = []
var _finger: int = -1
var _origin: Vector2 = Vector2.ZERO
var _base: Polygon2D
var _knob: Polygon2D


func _ready() -> void:
	layer = 10
	_base = Polygon2D.new()
	_base.polygon = LevelBuilder._circle(RADIUS, 32)
	_base.color = Color(1, 1, 1, 0.12)
	_base.visible = false
	add_child(_base)
	_knob = Polygon2D.new()
	_knob.polygon = LevelBuilder._circle(44.0, 24)
	_knob.color = Color(1, 1, 1, 0.32)
	_knob.visible = false
	add_child(_knob)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t: InputEventScreenTouch = event as InputEventScreenTouch
		if t.pressed and _finger < 0 and t.position.y > TOP and not _is_blocked(t.position):
			_finger = t.index
			_origin = t.position
			_show(t.position)
		elif not t.pressed and t.index == _finger:
			release()
	elif event is InputEventScreenDrag:
		var d: InputEventScreenDrag = event as InputEventScreenDrag
		if d.index == _finger:
			_show(d.position)


func _is_blocked(at: Vector2) -> bool:
	for r: Rect2 in blocked:
		if r.has_point(at):
			return true
	return false


func _show(at: Vector2) -> void:
	var off: Vector2 = (at - _origin).limit_length(RADIUS)
	vector = off / RADIUS
	_base.position = _origin
	_knob.position = _origin + off
	_base.visible = true
	_knob.visible = true


func release() -> void:
	_finger = -1
	vector = Vector2.ZERO
	_base.visible = false
	_knob.visible = false
