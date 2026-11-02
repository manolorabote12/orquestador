class_name UiIcon
extends Control
## Iconos vectoriales dibujados en codigo: nitidos en cualquier tamano y en cualquier perfil.
## Tipos: star, lock, pause, gear, back, play, close, coin, music, sound, vibrate, retry, grid, heart, heart_empty, trophy, share, skull, cube.
## Si el juego trae iconos dibujados por la IA (UI.icons: heart, star, trophy), se usan esos.

@export var kind: String = "star"
@export var color: Color = Color.WHITE
@export var fill: float = 1.0

## Apagado: estrella sin ganar o vida perdida (con arte, se dibuja oscuro y medio transparente).
var dim: bool = false
var outline_color: Color = Color(0, 0, 0, 0.0)
var outline_px: float = 0.0


static func make(icon_kind: String, icon_color: Color, px: float) -> UiIcon:
	var icon: UiIcon = UiIcon.new()
	icon.kind = icon_kind
	icon.color = icon_color
	icon.custom_minimum_size = Vector2(px, px)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _ready() -> void:
	resized.connect(queue_redraw)
	pivot_offset = size * 0.5


func _draw() -> void:
	var s: float = minf(size.x, size.y)
	var o: Vector2 = (size - Vector2(s, s)) * 0.5
	var c: Vector2 = o + Vector2(s, s) * 0.5
	var art: Texture2D = UI.icon_art(kind)
	if art != null:
		var off: bool = dim or kind == "heart_empty"
		draw_texture_rect(art, Rect2(o + Vector2(s, s) * 0.03, Vector2(s, s) * 0.94), false, Color(0.25, 0.25, 0.32, 0.6) if off else Color.WHITE)
		return
	match kind:
		"star":
			_poly(_star(c, s * 0.48, s * 0.2), color)
		"lock":
			draw_arc(c + Vector2(0, -s * 0.08), s * 0.2, PI, TAU, 16, color, s * 0.09)
			_poly(_rect(o + Vector2(s * 0.2, s * 0.38), Vector2(s * 0.6, s * 0.46)), color)
		"pause":
			_poly(_rect(o + Vector2(s * 0.26, s * 0.22), Vector2(s * 0.16, s * 0.56)), color)
			_poly(_rect(o + Vector2(s * 0.58, s * 0.22), Vector2(s * 0.16, s * 0.56)), color)
		"play":
			_poly(PackedVector2Array([o + Vector2(s * 0.3, s * 0.2), o + Vector2(s * 0.8, s * 0.5), o + Vector2(s * 0.3, s * 0.8)]), color)
		"back":
			_poly(PackedVector2Array([o + Vector2(s * 0.2, s * 0.5), o + Vector2(s * 0.55, s * 0.2), o + Vector2(s * 0.55, s * 0.38),
				o + Vector2(s * 0.82, s * 0.38), o + Vector2(s * 0.82, s * 0.62), o + Vector2(s * 0.55, s * 0.62), o + Vector2(s * 0.55, s * 0.8)]), color)
		"close":
			draw_line(o + Vector2(s * 0.25, s * 0.25), o + Vector2(s * 0.75, s * 0.75), color, s * 0.12)
			draw_line(o + Vector2(s * 0.75, s * 0.25), o + Vector2(s * 0.25, s * 0.75), color, s * 0.12)
		"gear":
			for i: int in 8:
				var a: float = TAU * float(i) / 8.0
				var d: Vector2 = Vector2(cos(a), sin(a))
				_poly(_rot_rect(c + d * s * 0.34, Vector2(s * 0.16, s * 0.16), a), color)
			draw_circle(c, s * 0.3, color)
			draw_circle(c, s * 0.12, color.darkened(0.6))
		"coin":
			draw_circle(c, s * 0.44, color)
			draw_circle(c, s * 0.24, color.darkened(0.35))
		"music":
			draw_circle(o + Vector2(s * 0.32, s * 0.72), s * 0.13, color)
			draw_line(o + Vector2(s * 0.43, s * 0.72), o + Vector2(s * 0.43, s * 0.2), color, s * 0.08)
			draw_line(o + Vector2(s * 0.43, s * 0.22), o + Vector2(s * 0.72, s * 0.32), color, s * 0.1)
		"sound":
			_poly(PackedVector2Array([o + Vector2(s * 0.18, s * 0.4), o + Vector2(s * 0.34, s * 0.4), o + Vector2(s * 0.52, s * 0.22),
				o + Vector2(s * 0.52, s * 0.78), o + Vector2(s * 0.34, s * 0.6), o + Vector2(s * 0.18, s * 0.6)]), color)
			draw_arc(o + Vector2(s * 0.52, s * 0.5), s * 0.16, -0.8, 0.8, 8, color, s * 0.06)
			draw_arc(o + Vector2(s * 0.52, s * 0.5), s * 0.28, -0.8, 0.8, 10, color, s * 0.06)
		"heart", "heart_empty":
			var pts: PackedVector2Array = _heart(c + Vector2(0, s * 0.04), s * 0.44)
			if kind == "heart":
				_poly(pts, color)
				draw_circle(c + Vector2(-s * 0.16, -s * 0.12), s * 0.07, Color(1, 1, 1, 0.45))
			else:
				var closed: PackedVector2Array = pts.duplicate()
				closed.append(pts[0])
				draw_polyline(closed, color, maxf(2.0, s * 0.08), true)
		"retry":
			draw_arc(c, s * 0.28, -PI * 0.35, PI * 1.45, 24, color, s * 0.1)
			var tip: Vector2 = c + Vector2(cos(-PI * 0.35), sin(-PI * 0.35)) * s * 0.28
			_poly(PackedVector2Array([tip + Vector2(-s * 0.04, -s * 0.16), tip + Vector2(s * 0.16, s * 0.02), tip + Vector2(-s * 0.1, s * 0.12)]), color)
		"grid":
			for gy: int in 2:
				for gx: int in 2:
					_poly(_rect(o + Vector2(s * (0.2 + 0.32 * float(gx)), s * (0.2 + 0.32 * float(gy))), Vector2(s * 0.26, s * 0.26)), color)
		"trophy":
			_poly(PackedVector2Array([o + Vector2(s * 0.26, s * 0.18), o + Vector2(s * 0.74, s * 0.18), o + Vector2(s * 0.68, s * 0.46),
				o + Vector2(s * 0.56, s * 0.56), o + Vector2(s * 0.44, s * 0.56), o + Vector2(s * 0.32, s * 0.46)]), color)
			draw_arc(o + Vector2(s * 0.26, s * 0.32), s * 0.1, PI * 0.5, PI * 1.5, 10, color, s * 0.06)
			draw_arc(o + Vector2(s * 0.74, s * 0.32), s * 0.1, -PI * 0.5, PI * 0.5, 10, color, s * 0.06)
			_poly(_rect(o + Vector2(s * 0.45, s * 0.54), Vector2(s * 0.1, s * 0.16)), color)
			_poly(_rect(o + Vector2(s * 0.3, s * 0.7), Vector2(s * 0.4, s * 0.1)), color)
		"share":
			draw_line(o + Vector2(s * 0.3, s * 0.5), o + Vector2(s * 0.7, s * 0.27), color, s * 0.07)
			draw_line(o + Vector2(s * 0.3, s * 0.5), o + Vector2(s * 0.7, s * 0.73), color, s * 0.07)
			draw_circle(o + Vector2(s * 0.3, s * 0.5), s * 0.12, color)
			draw_circle(o + Vector2(s * 0.7, s * 0.27), s * 0.12, color)
			draw_circle(o + Vector2(s * 0.7, s * 0.73), s * 0.12, color)
		"skull":
			draw_circle(c + Vector2(0, -s * 0.06), s * 0.32, color)
			_poly(_rect(o + Vector2(s * 0.32, s * 0.5), Vector2(s * 0.36, s * 0.26)), color)
			draw_circle(c + Vector2(-s * 0.12, -s * 0.06), s * 0.09, color.darkened(0.75))
			draw_circle(c + Vector2(s * 0.12, -s * 0.06), s * 0.09, color.darkened(0.75))
			for k: int in 3:
				_poly(_rect(o + Vector2(s * (0.37 + 0.1 * float(k)), s * 0.66), Vector2(s * 0.05, s * 0.12)), color.darkened(0.75))
		"cube":
			var top: PackedVector2Array = PackedVector2Array([c + Vector2(0, -s * 0.4), c + Vector2(s * 0.36, -s * 0.2), c + Vector2(0, 0), c + Vector2(-s * 0.36, -s * 0.2)])
			_poly(top, color.lightened(0.35))
			_poly(PackedVector2Array([c + Vector2(-s * 0.36, -s * 0.2), c, c + Vector2(0, s * 0.42), c + Vector2(-s * 0.36, s * 0.2)]), color)
			_poly(PackedVector2Array([c, c + Vector2(s * 0.36, -s * 0.2), c + Vector2(s * 0.36, s * 0.2), c + Vector2(0, s * 0.42)]), color.darkened(0.3))
		"vibrate":
			_poly(_rect(o + Vector2(s * 0.34, s * 0.18), Vector2(s * 0.32, s * 0.64)), color)
			draw_line(o + Vector2(s * 0.2, s * 0.35), o + Vector2(s * 0.2, s * 0.65), color, s * 0.06)
			draw_line(o + Vector2(s * 0.8, s * 0.35), o + Vector2(s * 0.8, s * 0.65), color, s * 0.06)


func _poly(points: PackedVector2Array, col: Color) -> void:
	if outline_px > 0.0:
		var closed: PackedVector2Array = points.duplicate()
		closed.append(points[0])
		draw_polyline(closed, outline_color, outline_px * 2.0)
	draw_colored_polygon(points, col)


func _heart(c: Vector2, r: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in 32:
		var t: float = TAU * float(i) / 32.0
		var x: float = 16.0 * pow(sin(t), 3.0)
		var y: float = 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
		pts.append(c + Vector2(x, -y) * (r / 16.0))
	return pts


func _star(c: Vector2, r_out: float, r_in: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in 10:
		var a: float = -PI * 0.5 + PI * float(i) / 5.0
		var r: float = r_out if i % 2 == 0 else r_in
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


func _rect(pos: Vector2, sz: Vector2) -> PackedVector2Array:
	return PackedVector2Array([pos, pos + Vector2(sz.x, 0), pos + sz, pos + Vector2(0, sz.y)])


func _rot_rect(center: Vector2, sz: Vector2, angle: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for v: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		pts.append(center + (v * sz * 0.5).rotated(angle))
	return pts
