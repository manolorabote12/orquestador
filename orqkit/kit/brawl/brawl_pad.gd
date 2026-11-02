class_name BrawlPad
extends Control
## Boton redondo de la arena (ataque o super): circulo con aro de carga.
## fill 0..1 llena el aro; armed lo hace brillar. Responde al toque y al raton.

signal pressed

var label: String = ""
var color: Color = Color("#ffb627")
var fill: float = 1.0
var segments: int = 0
var armed: bool = true
var _down: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	var hit: bool = false
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		hit = true
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		hit = true
	if hit:
		accept_event()
		_down = 0.12
		pressed.emit()


func _process(delta: float) -> void:
	_down = maxf(_down - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	var r: float = minf(size.x, size.y) * 0.5
	var c: Vector2 = size * 0.5
	var k: float = 0.92 if _down > 0.0 else 1.0
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
	var fnt: Font = UI.font
	if fnt != null and label != "":
		var fs: int = int(r * 0.42)
		var tw: float = fnt.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var p: Vector2 = c + Vector2(-tw * 0.5, fs * 0.35)
		draw_string_outline(fnt, p, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Color(0.05, 0.05, 0.08))
		draw_string(fnt, p, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
