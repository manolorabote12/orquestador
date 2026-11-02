extends RefCounted
## Dibujos por datos (los de las diferencias y el rompecabezas): una escena es una lista de figuras
## {"k": figura, "x", "y" (0-1), "s" (tamano 0-1), "c": "#rrggbb", "f": giro}, sobre un fondo y un suelo.


## Fondo, suelo y figuras de una escena en el rectangulo r.
static func draw_scene(ci: CanvasItem, r: Rect2, level: Dictionary, shapes: Array) -> void:
	var bg: Color = Color(str(level.get("bg", "#cfe8ff")))
	ci.draw_rect(r, bg)
	if level.has("ground"):
		ci.draw_rect(Rect2(r.position + Vector2(0, r.size.y * 0.7), Vector2(r.size.x, r.size.y * 0.3)), Color(str(level["ground"])))
	for sh: Variant in shapes:
		if not (sh as Dictionary).is_empty():
			draw_shape(ci, r, sh, bg)


## Una figura del dibujo (por "k").
static func draw_shape(ci: CanvasItem, r: Rect2, sh: Dictionary, bg: Color) -> void:
	var c: Vector2 = r.position + Vector2(float(sh.get("x", 0.5)), float(sh.get("y", 0.5))) * r.size
	var s: float = float(sh.get("s", 0.1)) * r.size.x * 0.5
	var col: Color = Color(str(sh.get("c", "#ffffff")))
	var fx: float = -1.0 if bool(sh.get("f", false)) else 1.0
	var dk: Color = col.darkened(0.3)
	match str(sh.get("k", "circle")):
		"circle", "balloon":
			ci.draw_circle(c, s, col)
			if str(sh.get("k")) == "balloon":
				ci.draw_line(c + Vector2(0, s), c + Vector2(fx * s * 0.3, s * 2.2), Color("#555555"), 2.0)
		"square", "gift":
			ci.draw_rect(Rect2(c - Vector2(s, s), Vector2(s, s) * 2.0), col)
			if str(sh.get("k")) == "gift":
				ci.draw_rect(Rect2(c - Vector2(s * 0.15, s), Vector2(s * 0.3, s * 2.0)), dk)
		"tri", "kite":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(fx * s, s), c + Vector2(-fx * s, s)]), col)
		"star":
			var pts: PackedVector2Array = PackedVector2Array()
			for k: int in 10:
				var a: float = -PI * 0.5 + PI * float(k) / 5.0
				pts.append(c + Vector2(cos(a), sin(a)) * (s if k % 2 == 0 else s * 0.45))
			ci.draw_colored_polygon(pts, col)
		"flower":
			for k2: int in 5:
				var a2: float = TAU * float(k2) / 5.0
				ci.draw_circle(c + Vector2(cos(a2), sin(a2)) * s * 0.55, s * 0.45, col)
			ci.draw_circle(c, s * 0.35, Color("#ffd166"))
		"tree":
			ci.draw_rect(Rect2(c + Vector2(-s * 0.15, 0), Vector2(s * 0.3, s)), Color("#7a4e2d"))
			ci.draw_circle(c + Vector2(0, -s * 0.2), s * 0.7, col)
		"bush":
			for k3: int in 3:
				ci.draw_circle(c + Vector2((float(k3) - 1.0) * s * 0.6, 0), s * 0.5, col)
		"house":
			ci.draw_rect(Rect2(c + Vector2(-s * 0.8, -s * 0.2), Vector2(s * 1.6, s * 1.2)), col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s, -s * 0.2), c + Vector2(0, -s), c + Vector2(s, -s * 0.2)]), dk)
			ci.draw_rect(Rect2(c + Vector2(fx * s * 0.3 - s * 0.15, s * 0.3), Vector2(s * 0.3, s * 0.7)), dk)
		"cloud":
			for k4: int in 3:
				ci.draw_circle(c + Vector2((float(k4) - 1.0) * s * 0.55, (0.15 if k4 != 1 else -0.1) * s), s * 0.45, col)
		"sun":
			ci.draw_circle(c, s * 0.6, col)
			for k5: int in 8:
				var a5: float = TAU * float(k5) / 8.0
				ci.draw_line(c + Vector2(cos(a5), sin(a5)) * s * 0.75, c + Vector2(cos(a5), sin(a5)) * s, col, 3.0)
		"fish":
			ci.draw_circle(c, s * 0.6, col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-fx * s * 0.5, 0), c + Vector2(-fx * s, -s * 0.5), c + Vector2(-fx * s, s * 0.5)]), dk)
			ci.draw_circle(c + Vector2(fx * s * 0.25, -s * 0.15), s * 0.1, Color("#222222"))
		"car":
			ci.draw_rect(Rect2(c + Vector2(-s, -s * 0.1), Vector2(s * 2.0, s * 0.6)), col)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.5 + fx * s * 0.1, -s * 0.5), Vector2(s, s * 0.4)), col.lightened(0.2))
			ci.draw_circle(c + Vector2(-s * 0.55, s * 0.5), s * 0.25, Color("#222222"))
			ci.draw_circle(c + Vector2(s * 0.55, s * 0.5), s * 0.25, Color("#222222"))
		"heart":
			ci.draw_circle(c + Vector2(-s * 0.35, -s * 0.15), s * 0.45, col)
			ci.draw_circle(c + Vector2(s * 0.35, -s * 0.15), s * 0.45, col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.78, 0), c + Vector2(0, s * 0.85), c + Vector2(s * 0.78, 0)]), col)
		"moon":
			ci.draw_circle(c, s * 0.7, col)
			ci.draw_circle(c + Vector2(fx * s * 0.35, -s * 0.15), s * 0.6, bg)
		"mushroom":
			ci.draw_rect(Rect2(c + Vector2(-s * 0.2, 0), Vector2(s * 0.4, s * 0.7)), Color("#f5efe0"))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s, s * 0.05), c + Vector2(-s * 0.6, -s * 0.6), c + Vector2(s * 0.6, -s * 0.6), c + Vector2(s, s * 0.05)]), col)
		"rock":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s, s * 0.5), c + Vector2(-s * 0.6, -s * 0.4), c + Vector2(s * 0.3, -s * 0.6), c + Vector2(s, s * 0.5)]), col)
		"bird":
			ci.draw_line(c + Vector2(-s, -s * 0.3), c, col, 4.0)
			ci.draw_line(c, c + Vector2(s, -s * 0.3), col, 4.0)
		"boat":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s, 0), c + Vector2(s, 0), c + Vector2(s * 0.6, s * 0.5), c + Vector2(-s * 0.6, s * 0.5)]), col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(fx * s * 0.7, -s * 0.1), c + Vector2(0, -s * 0.1)]), Color("#ffffff"))
		"cake":
			ci.draw_rect(Rect2(c + Vector2(-s * 0.8, -s * 0.2), Vector2(s * 1.6, s * 0.9)), col)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.8, -s * 0.35), Vector2(s * 1.6, s * 0.2)), Color("#ffffff"))
			ci.draw_circle(c + Vector2(0, -s * 0.5), s * 0.15, Color("#e74c3c"))
		"cup":
			ci.draw_rect(Rect2(c + Vector2(-s * 0.6, -s * 0.5), Vector2(s * 1.1, s)), col)
			ci.draw_arc(c + Vector2(fx * s * 0.6, 0), s * 0.3, -PI * 0.5, PI * 0.5, 10, col, 4.0)
		"lamp":
			ci.draw_line(c + Vector2(0, -s * 0.2), c + Vector2(0, s), Color("#555555"), 4.0)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.5, -s * 0.2), c + Vector2(-s * 0.25, -s), c + Vector2(s * 0.25, -s), c + Vector2(s * 0.5, -s * 0.2)]), col)
		_:
			ci.draw_circle(c, s, col)
