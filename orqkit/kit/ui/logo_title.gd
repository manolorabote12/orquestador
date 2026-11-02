class_name LogoTitle
extends Control
## Titulo con aspecto de logotipo de juego de estudio (no un texto plano):
## 1 - Relleno en degradado vertical con un brillo que cruza de vez en cuando.
## 2 - Contorno grueso oscuro y sombra solida debajo (como las letras de los juegos de movil).
## 3 - Entrada letra a letra con rebote y luego un balanceo suave, cada letra con su fase.
## Si no cabe en una linea se parte por palabras y se reduce el tamano hasta que quepa.

const SHADER: String = """
shader_type canvas_item;
uniform vec4 top_color : source_color = vec4(1.0);
uniform vec4 bottom_color : source_color = vec4(1.0, 0.7, 0.2, 1.0);
uniform float y_top = 0.0;
uniform float y_bottom = 100.0;
uniform float shine_speed = 0.35;
varying vec4 vcol;
varying vec2 local;
void vertex() {
	vcol = COLOR;
	local = VERTEX;
}
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (vcol.r > 0.99 && vcol.g > 0.99 && vcol.b > 0.99) {
		float t = clamp((local.y - y_top) / max(1.0, y_bottom - y_top), 0.0, 1.0);
		vec3 c = mix(top_color.rgb, bottom_color.rgb, smoothstep(0.0, 1.0, t));
		float band = fract(TIME * shine_speed) * 3.0 - 1.0;
		float d = abs(((FRAGCOORD.x + FRAGCOORD.y * 0.4) / 900.0) - band);
		c += vec3(0.55) * smoothstep(0.06, 0.0, d);
		COLOR = vec4(c, tex.a * vcol.a);
	} else {
		COLOR = tex * vcol;
	}
}
"""

var text: String = "":
	set(v):
		text = v
		_relayout()
var font: Font = null
var max_size: int = 96
var min_size: int = 40
var fill_top: Color = Color.WHITE
var fill_bottom: Color = Color("#ffb627")
var outline_color: Color = Color("#1a1030")
var shadow_color: Color = Color(0, 0, 0, 0.55)

var font_size: int = 96
var lines: Array[String] = []
var _t: float = 0.0
var _intro_t: float = -1.0
var _line_h: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _ready() -> void:
	var sh: Shader = Shader.new()
	sh.code = SHADER
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = sh
	material = mat
	resized.connect(_relayout)
	_relayout()


## 1 - Colores a partir de la paleta de la interfaz.
func use_palette(c: Dictionary) -> void:
	var acc: Color = c.get("acento", fill_bottom)
	fill_top = acc.lerp(Color.WHITE, 0.72)
	fill_bottom = acc
	if acc.get_luminance() < 0.35:
		fill_bottom = acc.lightened(0.25)
	var dark: Color = c.get("borde", outline_color)
	outline_color = dark.darkened(0.35)
	outline_color.a = 1.0
	_relayout()


func play_intro() -> void:
	_intro_t = 0.0


func outline_px() -> int:
	return maxi(4, int(float(font_size) * 0.15))


## 2 - Reparte en lineas y elige el tamano mayor que cabe en el ancho.
func _relayout() -> void:
	if font == null or text == "":
		lines = []
		custom_minimum_size = Vector2(0, 0)
		queue_redraw()
		return
	var avail: float = size.x if size.x > 10.0 else 640.0
	avail -= 24.0
	font_size = max_size
	while font_size > min_size:
		lines = _wrap(avail, font_size)
		var fits: bool = lines.size() <= 2
		for l: String in lines:
			if _width(l, font_size) > avail:
				fits = false
		if fits:
			break
		font_size -= 4
	lines = _wrap(avail, font_size)
	_line_h = float(font_size) * 1.08
	custom_minimum_size = Vector2(0, _line_h * float(lines.size()) + float(outline_px()) * 2.0 + 14.0)
	var mat: ShaderMaterial = material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("top_color", fill_top)
		mat.set_shader_parameter("bottom_color", fill_bottom)
	queue_redraw()


func _width(s: String, fs: int) -> float:
	return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + float(maxi(4, int(float(fs) * 0.15))) * 2.0


func _wrap(avail: float, fs: int) -> Array[String]:
	var out: Array[String] = []
	var cur: String = ""
	for w: String in text.split(" ", false):
		var probe: String = w if cur == "" else cur + " " + w
		if cur != "" and _width(probe, fs) > avail:
			out.append(cur)
			cur = w
		else:
			cur = probe
	if cur != "":
		out.append(cur)
	return out


func _process(delta: float) -> void:
	_t += delta
	if _intro_t >= 0.0:
		_intro_t += delta
		if _intro_t > 3.0:
			_intro_t = -1.0
	if is_visible_in_tree():
		queue_redraw()


## 3 - Escala de cada letra en la entrada (rebote) y desplazamiento del balanceo.
func letter_scale(i: int) -> float:
	if _intro_t < 0.0:
		return 1.0
	var t: float = clampf((_intro_t - 0.045 * float(i)) / 0.42, 0.0, 1.0)
	if t <= 0.0:
		return 0.0
	if t >= 1.0:
		return 1.0
	## Rebote: se pasa un poco y vuelve (curva "back").
	var u: float = t - 1.0
	return 1.0 + 2.70158 * u * u * u + 1.70158 * u * u


func _draw() -> void:
	if font == null or lines.is_empty():
		return
	var ol: int = outline_px()
	var mat: ShaderMaterial = material as ShaderMaterial
	var total_h: float = _line_h * float(lines.size())
	var y0: float = (size.y - total_h) * 0.5
	## Cada letra se dibuja en su propio espacio (centro de la letra): el degradado va de arriba a abajo de cada una.
	if mat != null:
		mat.set_shader_parameter("y_top", -float(font_size) * 0.38)
		mat.set_shader_parameter("y_bottom", float(font_size) * 0.3)
	var idx: int = 0
	for li: int in range(lines.size()):
		var line: String = lines[li]
		var lw: float = font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var x: float = (size.x - lw) * 0.5
		var base_y: float = y0 + _line_h * float(li) + float(font_size) * 0.86
		for ch: String in line:
			var cw: float = font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			var k: float = letter_scale(idx)
			var bob: float = sin(_t * 2.2 + float(idx) * 0.55) * 3.0
			if k > 0.0 and ch != " ":
				var center: Vector2 = Vector2(x + cw * 0.5, base_y - float(font_size) * 0.35 + bob)
				draw_set_transform(center, sin(float(idx) * 1.7) * 0.03, Vector2(k, k))
				var p: Vector2 = Vector2(-cw * 0.5, float(font_size) * 0.35)
				## Sombra solida (un poco por debajo) y contorno.
				draw_string_outline(font, p + Vector2(0, float(ol) * 0.9), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ol * 2, shadow_color)
				draw_string_outline(font, p, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ol * 2, outline_color)
				## Relleno: el blanco puro lo convierte el shader en el degradado.
				draw_string(font, p, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			x += cw
			idx += 1
