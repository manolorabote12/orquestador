class_name Skins
extends RefCounted
## Aspectos del heroe que se compran en la tienda con las monedas ganadas en cualquier nivel.
## Recolorean el arte del propio juego (giro de tono, saturacion y brillo con un shader): valen
## para todos los generos sin dibujar nada nuevo.

const LIST: Array[Dictionary] = [
	{"id": "original", "name": "Original", "price": 0, "hue": 0.0, "sat": 1.0, "val": 1.0},
	{"id": "oro", "name": "Oro", "price": 120, "hue": 0.12, "sat": 1.15, "val": 1.15},
	{"id": "hielo", "name": "Hielo", "price": 150, "hue": 0.5, "sat": 0.8, "val": 1.15},
	{"id": "fuego", "name": "Fuego", "price": 150, "hue": 0.95, "sat": 1.3, "val": 1.05},
	{"id": "menta", "name": "Menta", "price": 200, "hue": 0.3, "sat": 0.9, "val": 1.1},
	{"id": "sombra", "name": "Sombra", "price": 200, "hue": 0.0, "sat": 0.25, "val": 0.6},
	{"id": "neon", "name": "Neon", "price": 300, "hue": 0.78, "sat": 1.4, "val": 1.2},
	## Solo del pase de temporada (price -1: no se venden; la tienda los ensena si ya son tuyos).
	{"id": "estelar", "name": "Estelar", "price": -1, "hue": 0.62, "sat": 1.35, "val": 1.25},
	{"id": "aurora", "name": "Aurora", "price": -1, "hue": 0.42, "sat": 1.5, "val": 1.3},
]

const SHADER: String = """
shader_type canvas_item;
uniform float hue = 0.0;
uniform float sat = 1.0;
uniform float val = 1.0;
vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1.0e-10)), d / (q.x + 1.0e-10), q.x);
}
vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}
void fragment() {
	vec4 col = texture(TEXTURE, UV) * COLOR;
	vec3 h = rgb2hsv(col.rgb);
	h.x = fract(h.x + hue);
	h.y = clamp(h.y * sat, 0.0, 1.0);
	h.z = clamp(h.z * val, 0.0, 1.0);
	COLOR = vec4(hsv2rgb(h), col.a);
}
"""

static var _shader: Shader = null


static func find(id: String) -> Dictionary:
	for s: Dictionary in LIST:
		if s["id"] == id:
			return s
	return LIST[0]


static func current() -> Dictionary:
	return find(str(Save.meta().get("skin", "original")))


static func display_name(s: Dictionary) -> String:
	return Kit.text("skin_" + str(s["id"]), str(s["name"]))


## Material que recolorea un nodo (y sus hijos que usen el material del padre).
static func material_for(s: Dictionary) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("hue", float(s["hue"]))
	m.set_shader_parameter("sat", float(s["sat"]))
	m.set_shader_parameter("val", float(s["val"]))
	return m


## Aplica el aspecto a un nodo y a todos sus hijos dibujables. Original = sin material.
static func apply(node: CanvasItem, s: Dictionary = {}) -> void:
	if s.is_empty():
		s = current()
	var mat: ShaderMaterial = null if s["id"] == "original" else material_for(s)
	node.material = mat
	for c: Node in node.get_children():
		if c is CanvasItem and not (c is Control):
			(c as CanvasItem).use_parent_material = true
			apply_children(c as CanvasItem)


static func apply_children(node: CanvasItem) -> void:
	for c: Node in node.get_children():
		if c is CanvasItem and not (c is Control):
			(c as CanvasItem).use_parent_material = true
			apply_children(c as CanvasItem)


## Mismo recolor en un color suelto (coches de las carreras, sin textura).
static func recolor(c: Color, s: Dictionary = {}) -> Color:
	if s.is_empty():
		s = current()
	return Color.from_hsv(fposmod(c.h + float(s["hue"]), 1.0), clampf(c.s * float(s["sat"]), 0.0, 1.0), clampf(c.v * float(s["val"]), 0.0, 1.0), c.a)
