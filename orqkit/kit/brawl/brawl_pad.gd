class_name BrawlPad
extends Control
## Boton redondo de la arena (ataque o super): circulo con aro de carga.
## fill 0..1 llena el aro; armed lo hace brillar. Responde al toque y al raton.
## Como en los juegos de arena: tocar y soltar dispara solo al mas cercano (pressed); arrastrar
## apunta a mano (aim con la direccion mientras arrastras) y al soltar dispara hacia ahi (aimed).
## Arrastrar y volver al centro cancela.

signal pressed
signal aim(dir: Vector2)
signal aimed(dir: Vector2)

const DRAG_MIN: float = 22.0
var _touching: bool = false
var _start: Vector2 = Vector2.ZERO
var _drag: Vector2 = Vector2.ZERO
var _aiming: bool = false
var _touch_index: int = -1

var label: String = ""
## Icono en lugar de texto (como los juegos de arena): "attack" (mira) o "super" (estrella).
var glyph: String = ""
var color: Color = Color("#ffb627")
var fill: float = 1.0
var segments: int = 0
var armed: bool = true
var _down: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	var down: int = -1  # 1 apretar, 0 soltar
	var pos: Vector2 = Vector2.ZERO
	if event is InputEventScreenTouch:
		var t: InputEventScreenTouch = event
		if t.pressed and _touching:
			return
		if not t.pressed and t.index != _touch_index:
			return
		down = 1 if t.pressed else 0
		pos = t.position
		_touch_index = t.index
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		down = 1 if (event as InputEventMouseButton).pressed else 0
		pos = (event as InputEventMouseButton).position
	elif event is InputEventScreenDrag and _touching and (event as InputEventScreenDrag).index == _touch_index:
		_move((event as InputEventScreenDrag).position)
		accept_event()
		return
	elif event is InputEventMouseMotion and _touching:
		_move((event as InputEventMouseMotion).position)
		accept_event()
		return
	if down == 1:
		accept_event()
		_touching = true
		_start = pos
		_drag = Vector2.ZERO
		_aiming = false
		_down = 0.12
	elif down == 0 and _touching:
		accept_event()
		_touching = false
		_touch_index = -1
		if _aiming:
			_aiming = false
			aim.emit(Vector2.ZERO)
			if _drag.length() >= DRAG_MIN:
				aimed.emit(_drag.normalized())
		else:
			pressed.emit()


func _move(pos: Vector2) -> void:
	_drag = pos - _start
	if _drag.length() >= DRAG_MIN:
		_aiming = true
		aim.emit(_drag.normalized())
	elif _aiming:
		## Vuelto al centro: se cancela (no dispara al soltar).
		aim.emit(Vector2.ZERO)


## Las pruebas (sin pantalla) simulan arrastrar y soltar.
func simulate_aim(dir: Vector2) -> void:
	aim.emit(dir.normalized())
	aim.emit(Vector2.ZERO)
	aimed.emit(dir.normalized())


func _process(delta: float) -> void:
	_down = maxf(_down - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	var r: float = minf(size.x, size.y) * 0.5
	var c: Vector2 = size * 0.5
	var k: float = 0.92 if _down > 0.0 or _touching else 1.0
	## Mientras apuntas, el boton se desplaza un poco hacia donde arrastras.
	if _aiming:
		c += _drag.limit_length(r * 0.45)
	draw_circle(c + Vector2(0, 5), r * k, Color(0, 0, 0, 0.35))
	draw_circle(c, r * k, Color(0.06, 0.06, 0.1, 0.55))
	var inner: Color = color if armed else color.darkened(0.55)
	draw_circle(c, r * 0.72 * k, inner)
	draw_circle(c + Vector2(-r * 0.18, -r * 0.2), r * 0.3 * k, Color(1, 1, 1, 0.22 if armed else 0.08))
	## Aro de carga (por tramos para la municion).
	if segments > 0:
		var gap: float = 0.16
		var span: float = TAU / float(segments)
		for i: int in segments:
			var f: float = clampf(fill * float(segments) - float(i), 0.0, 1.0)
			var a0: float = -PI * 0.5 + span * float(i) + gap * 0.5
			draw_arc(c, r * 0.87 * k, a0, a0 + (span - gap), 16, Color(1, 1, 1, 0.18), r * 0.12, true)
			if f > 0.0:
				draw_arc(c, r * 0.87 * k, a0, a0 + (span - gap) * f, 16, color.lightened(0.25) if f >= 1.0 else color.darkened(0.2), r * 0.12, true)
	else:
		draw_arc(c, r * 0.87 * k, 0.0, TAU, 40, Color(1, 1, 1, 0.18), r * 0.12, true)
		if fill > 0.0:
			draw_arc(c, r * 0.87 * k, -PI * 0.5, -PI * 0.5 + TAU * clampf(fill, 0.0, 1.0), 40, color.lightened(0.3), r * 0.12, true)
	if glyph != "" and not (glyph == "attack" and label != "" and label != Kit.text("brawl_attack", "\u00a1Fuego!")):
		_draw_glyph(c, r * 0.4 * k)
		return
	var fnt: Font = UI.font
	if fnt != null and label != "":
		var fs: int = int(r * 0.42)
		var tw: float = fnt.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var p: Vector2 = c + Vector2(-tw * 0.5, fs * 0.35)
		draw_string_outline(fnt, p, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Color(0.05, 0.05, 0.08))
		draw_string(fnt, p, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


func _draw_glyph(c: Vector2, s: float) -> void:
	var ink: Color = Color(1, 1, 1, 0.95 if armed else 0.5)
	var dark: Color = Color(0.05, 0.05, 0.08, 0.55)
	if glyph == "super":
		## Estrella de cinco puntas con sombra.
		var pts: PackedVector2Array = PackedVector2Array()
		for i: int in 10:
			var a: float = -PI * 0.5 + TAU * float(i) / 10.0
			pts.append(c + Vector2.RIGHT.rotated(a) * (s if i % 2 == 0 else s * 0.45))
		var sh: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in pts:
			sh.append(p + Vector2(0, 4))
		draw_colored_polygon(sh, dark)
		draw_colored_polygon(pts, ink)
		return
	## Mira: aro, cruz y punto.
	draw_arc(c + Vector2(0, 3), s * 0.75, 0.0, TAU, 32, dark, s * 0.18, true)
	draw_arc(c, s * 0.75, 0.0, TAU, 32, ink, s * 0.16, true)
	for d: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_line(c + d * s * 0.45, c + d * s * 1.15, ink, s * 0.16, true)
	draw_circle(c, s * 0.14, ink)
