class_name VersusBar
extends Control
## Barra "Tu contra el rival" para los juegos de mesa a dos (ajedrez, reversi, damas, conecta 4).
## Izquierda: el heroe del juego (su propio arte, si lo hay) con "Tu" y tu marcador; derecha: la
## maquina con el suyo. El lado al que le toca brilla. Colores del perfil de la interfaz.
## Uso: var vs: VersusBar = VersusBar.make(); col.add_child(vs); vs.set_state(mis, suyos, me_toca)

var mine: int = 0
var theirs: int = 0
var my_turn: bool = true
var show_scores: bool = true
var _hero: Texture2D = null
var _t: float = 0.0


static func make(scores: bool = true) -> VersusBar:
	var v: VersusBar = VersusBar.new()
	v.name = "Versus"
	v.show_scores = scores
	v.custom_minimum_size = Vector2(0, 112)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v


func _ready() -> void:
	var hero: Dictionary = Kit.sprite_by_role("jugador")
	if not hero.is_empty():
		var sf: SpriteFrames = SpriteKit.frames_de(hero)
		for anim: String in sf.get_animation_names():
			if sf.get_frame_count(anim) > 0:
				_hero = sf.get_frame_texture(anim, 0)
				break
	resized.connect(queue_redraw)


func set_state(me: int, them: int, turn_mine: bool) -> void:
	if me == mine and them == theirs and turn_mine == my_turn:
		return
	mine = me
	theirs = them
	my_turn = turn_mine
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _col(k: String, fb: Color) -> Color:
	return UI.colors.get(k, fb) if UI.colors.has(k) else fb


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	var panel: Color = _col("panel", Color("#22262e"))
	var edge: Color = _col("borde", Color("#0c0d10"))
	var accent: Color = _col("acento", Color("#f2b33d"))
	var danger: Color = _col("peligro", Color("#e5484d"))
	var text: Color = _col("texto", Color.WHITE)
	var font: Font = get_theme_font("font", "Label")
	var r: float = h * 0.36
	var cy: float = h * 0.5
	var lx: float = r + 10.0
	var rx: float = w - r - 10.0
	draw_rect(Rect2(Vector2(r * 0.6, cy - h * 0.3), Vector2(w - r * 1.2, h * 0.6)), panel.lerp(Color.BLACK, 0.15))
	var pulse: float = 0.5 + 0.5 * sin(_t * 4.0)
	## Brillo en el lado al que le toca.
	var gx: float = lx if my_turn else rx
	var gc: Color = accent if my_turn else danger
	draw_circle(Vector2(gx, cy), r + 7.0 + pulse * 4.0, Color(gc.r, gc.g, gc.b, 0.35))
	## Tu: retrato del heroe.
	draw_circle(Vector2(lx, cy), r + 4.0, edge)
	draw_circle(Vector2(lx, cy), r, accent.lerp(panel, 0.35))
	if _hero != null:
		var ts: Vector2 = _hero.get_size()
		var k: float = (r * 1.7) / maxf(ts.x, ts.y)
		var sz: Vector2 = ts * k
		draw_texture_rect(_hero, Rect2(Vector2(lx, cy) - sz * 0.5 + Vector2(0, -2), sz), false)
	else:
		draw_circle(Vector2(lx, cy - r * 0.15), r * 0.38, text)
		draw_circle(Vector2(lx, cy + r * 0.7), r * 0.62, text)
	## El rival: la maquina (cara de pantalla con dos ojos).
	draw_circle(Vector2(rx, cy), r + 4.0, edge)
	draw_circle(Vector2(rx, cy), r, danger.lerp(panel, 0.35))
	var face: Rect2 = Rect2(Vector2(rx - r * 0.6, cy - r * 0.45), Vector2(r * 1.2, r * 0.9))
	draw_rect(face, edge)
	var blink: bool = fmod(_t, 3.2) < 0.12
	for ex: float in [-0.25, 0.25]:
		if blink:
			draw_line(Vector2(rx + ex * r - 6.0, cy - 2.0), Vector2(rx + ex * r + 6.0, cy - 2.0), danger.lightened(0.4), 3.0)
		else:
			draw_circle(Vector2(rx + ex * r, cy - 2.0), r * 0.12, danger.lightened(0.4))
	draw_line(Vector2(rx - r * 0.2, cy + r * 0.22), Vector2(rx + r * 0.2, cy + r * 0.22), danger.lightened(0.4), 3.0)
	## Nombres y marcadores.
	var fs: int = 26
	var name_me: String = Kit.text("vs_you", "T\u00fa")
	var name_ai: String = Kit.text("vs_ai", "Rival")
	draw_string_outline(font, Vector2(lx + r + 14.0, cy - 8.0), name_me, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, edge)
	draw_string(font, Vector2(lx + r + 14.0, cy - 8.0), name_me, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text)
	draw_string_outline(font, Vector2(rx - r - 214.0, cy - 8.0), name_ai, HORIZONTAL_ALIGNMENT_RIGHT, 200, fs, 6, edge)
	draw_string(font, Vector2(rx - r - 214.0, cy - 8.0), name_ai, HORIZONTAL_ALIGNMENT_RIGHT, 200, fs, text)
	if show_scores:
		draw_string_outline(font, Vector2(lx + r + 14.0, cy + 32.0), str(mine), HORIZONTAL_ALIGNMENT_LEFT, -1, 38, 7, edge)
		draw_string(font, Vector2(lx + r + 14.0, cy + 32.0), str(mine), HORIZONTAL_ALIGNMENT_LEFT, -1, 38, accent)
		draw_string_outline(font, Vector2(rx - r - 214.0, cy + 32.0), str(theirs), HORIZONTAL_ALIGNMENT_RIGHT, 200, 38, 7, edge)
		draw_string(font, Vector2(rx - r - 214.0, cy + 32.0), str(theirs), HORIZONTAL_ALIGNMENT_RIGHT, 200, 38, danger.lightened(0.2))
	var vs: String = "VS"
	draw_string_outline(font, Vector2(w * 0.5 - 60.0, cy + 14.0), vs, HORIZONTAL_ALIGNMENT_CENTER, 120, 40, 8, edge)
	draw_string(font, Vector2(w * 0.5 - 60.0, cy + 14.0), vs, HORIZONTAL_ALIGNMENT_CENTER, 120, 40, accent)
