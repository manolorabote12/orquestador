extends Node
## Acabado visual comun a todos los generos (autoload "Look").
## 1 - Fondo ilustrado de nivel (assets/ui/fondo_nivel.jpg, lo dibuja la IA): detras de cada nivel
##     2D, con un velo del color del cielo para que el juego destaque y un vaiven lento.
## 2 - Los generos con vista 3D tienen su propio cielo: ahi no se pone.
## 3 - Un genero puede pedir no llevarlo con wants_backdrop() -> false.
## 4 - Etalonaje de cine encima del juego (debajo del HUD): un poco de brillo en lo luminoso,
##     color mas vivo, contraste y vineta suave. Se apaga en Ajustes (Graficos: bajos).
## 5 - Ayuda para daltonismo (Ajustes -> Accesibilidad: Colores): corrige los colores de toda la
##     pantalla (rojo/verde, el mas comun) para que lo que se distingue por color se distinga.
##     Va por encima de todo y persiste entre pantallas.

const GRADE_SHADER: String = """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float vignette = 0.3;
uniform float bloom = 0.35;
uniform float saturation = 1.12;
uniform float contrast = 1.06;
void fragment() {
	vec3 c = textureLod(screen_tex, SCREEN_UV, 0.0).rgb;
	vec3 b = textureLod(screen_tex, SCREEN_UV, 3.0).rgb;
	c += max(b - vec3(0.62), vec3(0.0)) * 2.2 * bloom;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation);
	c = (c - 0.5) * contrast + 0.5;
	vec2 d = (SCREEN_UV - 0.5) * vec2(1.0, 0.8);
	c *= 1.0 - vignette * smoothstep(0.32, 0.78, length(d) * 1.35);
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
"""

const ASSIST_SHADER: String = """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float L = 17.8824 * c.r + 43.5161 * c.g + 4.11935 * c.b;
	float M = 3.45565 * c.r + 27.1554 * c.g + 3.86714 * c.b;
	float S = 0.0299566 * c.r + 0.184309 * c.g + 1.46709 * c.b;
	float m = 0.494207 * L + 1.24827 * S;
	vec3 sim = vec3(0.0809444479 * L - 0.130504409 * m + 0.116721066 * S,
		-0.0102485335 * L + 0.0540193266 * m - 0.113614708 * S,
		-0.000365296938 * L - 0.00412161469 * m + 0.693511405 * S);
	vec3 e = c - sim;
	COLOR = vec4(clamp(c + vec3(0.0, e.r * 0.7 + e.g, e.r * 0.7 + e.b), 0.0, 1.0), 1.0);
}
"""

var backdrop: CanvasLayer = null
var assist: CanvasLayer = null
var _cache: Texture2D = null
var _cache_path: String = ""


## Fondo desenfocado: la imagen reducida a 1/6 y agrandada otra vez con suavizado (una vez, al cargar).
## 13 nov: «fondo_distrae» salia en casi todas las criticas (profundidad de campo).
static func soft_texture(tex: Texture2D) -> Texture2D:
	var img: Image = tex.get_image()
	if img == null or img.is_empty():
		return tex
	img = img.duplicate()
	if img.is_compressed():
		if img.decompress() != OK:
			return tex
	var w: int = img.get_width()
	var h: int = img.get_height()
	img.resize(maxi(8, w / 6), maxi(8, h / 6), Image.INTERPOLATE_BILINEAR)
	## Se vuelve a agrandar aqui (suave): en pantalla no depende del filtro del proyecto (pixel art = nearest).
	img.resize(mini(w, 1024), mini(h, 1820), Image.INTERPOLATE_BILINEAR)
	## Algo menos de color: la partida (personajes y objetos) se queda con los colores vivos.
	img.adjust_bcs(1.0, 1.0, 0.8)
	return ImageTexture.create_from_image(img)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	QA.logged.connect(_on_event)
	set_color_assist(bool(Save.get_setting("color_assist", false)), false)


## Ayuda para daltonismo encendida o apagada (y se guarda si persist).
func set_color_assist(on: bool, persist: bool = true) -> void:
	if persist:
		Save.set_setting("color_assist", on)
	if on and assist == null:
		assist = CanvasLayer.new()
		assist.name = "ColorAssist"
		assist.layer = 120
		var r: ColorRect = ColorRect.new()
		r.set_anchors_preset(Control.PRESET_FULL_RECT)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sh: Shader = Shader.new()
		sh.code = ASSIST_SHADER
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = sh
		r.material = mat
		assist.add_child(r)
		add_child(assist)
	if assist != null:
		assist.visible = on


func level_texture() -> Texture2D:
	var ui_cfg: Dictionary = Kit.assets.get("ui", {}) as Dictionary
	var path: String = str(ui_cfg.get("fondo_nivel", ""))
	if path != _cache_path:
		_cache_path = path
		_cache = Kit.load_texture(path)
	return _cache


## Si el nivel lleva fondo ilustrado (los generos que pintan su cielo lo dejan de pintar).
func has_level_backdrop() -> bool:
	return level_texture() != null


func _on_event(e: Dictionary) -> void:
	if str(e.get("event", "")) == "level_start":
		_dress.call_deferred()


func _find_game() -> Node:
	var root: Node = get_tree().current_scene
	if root == null:
		return null
	## Todos los generos tienen time_in_level (contrato del kit).
	if "time_in_level" in root:
		return root
	for c: Node in root.get_children():
		## Saltando el juego anterior que se esta borrando (en las capturas del jefe el fondo iba a parar a ese).
		if "time_in_level" in c and not c.is_queued_for_deletion():
			return c
	return null


func _dress() -> void:
	var game: Node = _find_game()
	if game == null:
		return
	## Maraton: franja con el nivel y las vidas.
	var old: Node = game.get_node_or_null("MarathonBanner")
	if old != null:
		old.queue_free()
	if Marathon.active():
		game.add_child(Marathon.make_banner())
	## Primera partida: tutorial interactivo si el genero (o el juego) lo tiene; si no, "Como se juega".
	if Tutorial.will_run(Genres.current()):
		Save.set_setting("howto_" + Genres.current(), true)
		Tutorial.maybe_start(game)
	else:
		HowTo.maybe_show(game)
	## Contrarreloj: reloj y record del nivel.
	var old_t: Node = game.get_node_or_null("TimeBanner")
	if old_t != null:
		old_t.queue_free()
	if TimeAttack.active() and not Marathon.active() and not Kit.is_extra():
		game.add_child(TimeAttack.make_banner())
	var opt_out: bool = game.has_method("wants_grade") and not bool(game.call("wants_grade"))
	if wants_grade() and not opt_out and game.get_node_or_null("Grade") == null:
		game.add_child(make_grade())
	## Motas de luz flotando detras de la partida (13 nov: «efectos_pobres, poca vida» en casi todas las
	## criticas). Solo con graficos altos, en 2D y si el juego no lo rechaza (wants_ambient).
	var no_amb: bool = game.has_method("wants_ambient") and not bool(game.call("wants_ambient"))
	if wants_grade() and not no_amb and game.get_node_or_null("Ambient") == null and game.get_viewport().get_camera_3d() == null:
		game.add_child(make_ambient())
	if game.get_node_or_null("LevelBackdrop") != null:
		return
	if game.has_method("wants_backdrop") and not bool(game.call("wants_backdrop")):
		return
	if game.get_viewport().get_camera_3d() != null:
		return
	var tex: Texture2D = level_texture()
	if tex == null:
		return
	backdrop = make_backdrop(tex)
	game.add_child(backdrop)
	game.move_child(backdrop, 0)


func wants_grade() -> bool:
	return bool(Save.get_setting("fx_high", true))


static func make_grade() -> CanvasLayer:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "Grade"
	layer.layer = 15
	var rect: ColorRect = ColorRect.new()
	rect.name = "Pass"
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh: Shader = Shader.new()
	sh.code = GRADE_SHADER
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = sh
	rect.material = mat
	layer.add_child(rect)
	return layer


## Ajustes: graficos altos (con etalonaje) o bajos. Cambia al momento si hay un nivel en marcha.
func set_high(on: bool) -> void:
	Save.set_setting("fx_high", on, false)
	var game: Node = _find_game()
	if game == null:
		return
	var g: Node = game.get_node_or_null("Grade")
	if game.has_method("wants_grade") and not bool(game.call("wants_grade")):
		return
	if on and g == null:
		game.add_child(make_grade())
	elif not on and g != null:
		g.queue_free()


static func make_ambient() -> CanvasLayer:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "Ambient"
	## Por encima de la partida y por debajo del HUD (si fuera detras, el suelo de muchos juegos las taparia).
	layer.layer = 5
	var fx: CPUParticles2D = CPUParticles2D.new()
	fx.name = "Motes"
	fx.position = Vector2(360.0, 1380.0)
	fx.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	fx.emission_rect_extents = Vector2(520.0, 60.0)
	fx.amount = 36
	fx.lifetime = 11.0
	## Ya flotando desde el primer fotograma (tambien en las capturas de la tienda).
	fx.preprocess = 11.0
	fx.direction = Vector2(0.0, -1.0)
	fx.spread = 18.0
	fx.gravity = Vector2(0.0, 0.0)
	fx.initial_velocity_min = 70.0
	fx.initial_velocity_max = 150.0
	fx.angular_velocity_min = -40.0
	fx.angular_velocity_max = 40.0
	## Punto de luz suave (degradado redondo), no un cuadrado.
	var glow: GradientTexture2D = GradientTexture2D.new()
	glow.width = 64
	glow.height = 64
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(0.5, 0.5)
	glow.fill_to = Vector2(1.0, 0.5)
	var g: Gradient = Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	glow.gradient = g
	fx.texture = glow
	fx.scale_amount_min = 0.25
	fx.scale_amount_max = 0.6
	var tint: Color = Kit.color("accent", Color("#ffd166")).lightened(0.35)
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, Color(tint, 0.0))
	ramp.set_color(1, Color(tint, 0.0))
	ramp.add_point(0.2, Color(tint, 0.55))
	ramp.add_point(0.8, Color(tint, 0.4))
	fx.color_ramp = ramp
	layer.add_child(fx)
	return layer


static func make_backdrop(tex: Texture2D) -> CanvasLayer:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "LevelBackdrop"
	layer.layer = -50
	var tr: TextureRect = TextureRect.new()
	tr.name = "Art"
	tr.texture = soft_texture(tex)
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	## Desenfoque suave y algo menos de color (profundidad de campo): el fondo no compite con la
	## partida (13 nov: «fondo_distrae» salia en casi todas las criticas).
	## Un poco mas grande que la pantalla para el vaiven.
	tr.scale = Vector2(1.06, 1.06)
	tr.pivot_offset = Vector2(360, 640)
	layer.add_child(tr)
	var sky: Color = Kit.color("sky", Color("#1b2a41"))
	var veil: ColorRect = ColorRect.new()
	veil.name = "Veil"
	veil.color = Color(sky, 0.5 if sky.v < 0.3 else 0.32)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(veil)
	var tw: Tween = tr.create_tween().set_loops()
	tw.tween_property(tr, "position", Vector2(-14.0, -8.0), 9.0).set_trans(Tween.TRANS_SINE)
	tw.tween_property(tr, "position", Vector2(14.0, 6.0), 9.0).set_trans(Tween.TRANS_SINE)
	return layer
