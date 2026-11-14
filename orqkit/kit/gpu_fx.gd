class_name GpuFx
extends RefCounted
## Sombreadores de GPU del kit (14 nov, «calidad de GPU, no dibujos de codigo»):
## 1 - outline(): contorno oscuro y luz de borde en los personajes (se leen sobre cualquier suelo).
## 2 - water(): mar animado alrededor de la arena (olas, brillos y espuma en la orilla).
## 3 - caustics(): reflejos de luz del agua moviendose sobre el suelo (temas de mar y playa).
## Todo corre en la GPU; si un movil no puede, Godot pinta el nodo sin el efecto.

static var _cache: Dictionary = {}

const OUTLINE: String = """
shader_type canvas_item;
uniform vec4 line_color : source_color = vec4(0.05, 0.04, 0.12, 1.0);
uniform float width = 2.5;
uniform vec4 rim_color : source_color = vec4(1.0, 0.96, 0.85, 1.0);
uniform float rim = 0.22;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 px = TEXTURE_PIXEL_SIZE * width;
	float a = 0.0;
	for (int i = 0; i < 8; i++) {
		float ang = float(i) * 0.785398;
		a = max(a, texture(TEXTURE, UV + vec2(cos(ang), sin(ang)) * px).a);
	}
	float up = texture(TEXTURE, UV + vec2(0.0, -px.y * 2.0)).a;
	vec3 lit = mix(c.rgb, rim_color.rgb, rim * c.a * (1.0 - up));
	vec4 body = vec4(lit, c.a);
	vec4 edge = vec4(line_color.rgb, line_color.a * a);
	COLOR = mix(edge, body, c.a) * COLOR;
}
"""

const WATER: String = """
shader_type canvas_item;
uniform vec4 deep : source_color = vec4(0.02, 0.22, 0.42, 1.0);
uniform vec4 shallow : source_color = vec4(0.09, 0.55, 0.72, 1.0);
uniform vec4 foam : source_color = vec4(0.9, 0.98, 1.0, 1.0);
uniform vec2 arena_min = vec2(0.0);
uniform vec2 arena_max = vec2(1000.0);
varying vec2 world;
void vertex() { world = VERTEX; }
float waves(vec2 p, float t) {
	return sin(p.x * 0.012 + t * 1.1) * 0.5 + sin(p.y * 0.017 - t * 0.8) * 0.5 + sin((p.x + p.y) * 0.008 + t * 0.6) * 0.5;
}
void fragment() {
	float t = TIME;
	vec2 q = clamp(world, arena_min, arena_max);
	float d = length(world - q);
	float w = waves(world, t);
	vec3 col = mix(shallow.rgb, deep.rgb, clamp(d / 520.0 + w * 0.08, 0.0, 1.0));
	float spark = pow(max(0.0, sin(world.x * 0.05 + t * 2.0) * sin(world.y * 0.045 - t * 1.6)), 12.0);
	col += vec3(spark) * 0.35;
	float shore = smoothstep(70.0, 0.0, d + sin(world.x * 0.03 + world.y * 0.02 + t * 2.4) * 18.0);
	col = mix(col, foam.rgb, shore * 0.85);
	COLOR = vec4(col, 1.0);
}
"""

const CAUSTICS: String = """
shader_type canvas_item;
render_mode blend_add;
uniform float strength = 0.10;
varying vec2 world;
void vertex() { world = VERTEX; }
void fragment() {
	vec2 p = world * 0.006;
	float t = TIME * 0.45;
	float c = 0.0;
	for (int i = 1; i < 4; i++) {
		float fi = float(i);
		p += vec2(sin(p.y * fi + t * fi), cos(p.x * fi - t * 0.7 * fi)) * 0.35;
		c += abs(sin(p.x + p.y));
	}
	c = pow(1.0 - clamp(c / 3.0, 0.0, 1.0), 6.0);
	COLOR = vec4(vec3(c * strength * 1.6, c * strength * 1.8, c * strength * 1.6), 1.0);
}
"""


static func _mat(key: String, code: String) -> ShaderMaterial:
	if not _cache.has(key):
		var s: Shader = Shader.new()
		s.code = code
		_cache[key] = s
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = _cache[key]
	return m


static func outline(line: Color = Color(0.05, 0.04, 0.12), width: float = 2.5) -> ShaderMaterial:
	var m: ShaderMaterial = _mat("outline", OUTLINE)
	m.set_shader_parameter("line_color", line)
	m.set_shader_parameter("width", width)
	return m


static func water(arena: Rect2, deep: Color, shallow: Color) -> ShaderMaterial:
	var m: ShaderMaterial = _mat("water", WATER)
	m.set_shader_parameter("arena_min", arena.position)
	m.set_shader_parameter("arena_max", arena.end)
	m.set_shader_parameter("deep", deep)
	m.set_shader_parameter("shallow", shallow)
	return m


static func caustics(strength: float = 0.1) -> ShaderMaterial:
	var m: ShaderMaterial = _mat("caustics", CAUSTICS)
	m.set_shader_parameter("strength", strength)
	return m


## Tema de mar o playa (agua alrededor y reflejos en el suelo)?
static func sea_theme() -> bool:
	var g: Color = Color(str(Kit.param("brawl_gas_color", "#73f259")))
	var words: String = (str(Kit.param("biome", "")) + " " + str(Kit.config.get("title", ""))).to_lower()
	return (g.b > g.r and g.b > g.g * 0.9) or words.contains("mar") or words.contains("playa") or words.contains("ocean") or words.contains("sea")
