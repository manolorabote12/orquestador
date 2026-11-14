class_name ArenaShowcase
extends Control
## Cabecera de fin de partida de la arena (como los juegos de arena): tu personaje grande bajo un
## foco, el resultado en letras enormes (VICTORIA / DERROTA / #2) y debajo el detalle (marcador,
## eliminaciones...). Lo usan ResultPanel y FailPanel cuando el juego les pasa "arena".

var title_text: String = ""
var sub_text: String = ""
var victory: bool = true
var brawler: Dictionary = {}
var _t: float = 0.0
var _spr: AnimatedSprite2D


static func make(b: Dictionary, title: String, sub: String, won: bool) -> ArenaShowcase:
	var a: ArenaShowcase = ArenaShowcase.new()
	a.name = "ArenaShowcase"
	a.brawler = b
	a.title_text = title
	a.sub_text = sub
	a.victory = won
	a.custom_minimum_size = Vector2(480.0, 400.0)
	a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return a


func _ready() -> void:
	var entry: Dictionary = Brawlers.sprite_entry(brawler) if not brawler.is_empty() else Kit.sprite_by_role("jugador")
	if not entry.is_empty():
		_spr = SpriteKit.animado(entry, 200.0, "idle", true)
		_spr.self_modulate = Brawlers.tint(brawler) if not brawler.is_empty() else Color.WHITE
		_spr.position = Vector2(240.0, 250.0)
		if not victory:
			_spr.modulate = Color(0.75, 0.75, 0.85)
		add_child(_spr)
	var t: Label = Label.new()
	t.name = "BigResult"
	t.text = title_text
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.position = Vector2(0.0, 290.0)
	t.size = Vector2(480.0, 70.0)
	t.add_theme_font_size_override("font_size", 62)
	t.add_theme_color_override("font_color", Color("#ffd447") if victory else Color("#ff6b6b"))
	t.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.12))
	t.add_theme_constant_override("outline_size", 14)
	add_child(t)
	var s: Label = Label.new()
	s.name = "SubResult"
	s.text = sub_text
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.position = Vector2(0.0, 356.0)
	s.size = Vector2(480.0, 40.0)
	s.add_theme_font_size_override("font_size", 26)
	s.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.12))
	s.add_theme_constant_override("outline_size", 8)
	add_child(s)
	## Entrada: el titulo cae y rebota; el personaje salta si has ganado.
	t.pivot_offset = Vector2(240.0, 35.0)
	t.scale = Vector2(2.2, 2.2)
	t.modulate.a = 0.0
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(t, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(t, "modulate:a", 1.0, 0.2)
	if victory and not UI.test_mode:
		Juice.confetti(self, Vector2(240.0, 120.0), 40)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _spr != null and victory:
		_spr.position.y = 250.0 - absf(sin(_t * 3.2)) * 14.0


func _draw() -> void:
	## Foco: rayos que giran detras y un disco de luz en el suelo.
	var c: Vector2 = Vector2(240.0, 160.0)
	var col: Color = Color("#ffd447") if victory else Color("#7d8cff")
	for i: int in 12:
		var a: float = _t * 0.35 + TAU * float(i) / 12.0
		var p1: Vector2 = c + Vector2(cos(a - 0.09), sin(a - 0.09)) * 230.0
		var p2: Vector2 = c + Vector2(cos(a + 0.09), sin(a + 0.09)) * 230.0
		draw_colored_polygon(PackedVector2Array([c, p1, p2]), Color(col.r, col.g, col.b, 0.13))
	draw_circle(c, 120.0, Color(col.r, col.g, col.b, 0.16))
	draw_set_transform(Vector2(240.0, 252.0), 0.0, Vector2(1.0, 0.28))
	draw_circle(Vector2.ZERO, 110.0, Color(col.r, col.g, col.b, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
