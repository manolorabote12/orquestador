extends Node
## UI: tema visual compartido por todas las pantallas y utilidades con "feeling".
## Autoload "UI" (sin class_name). El perfil y los colores salen de assets/manifest.json -> "ui"
## (la fabrica los deriva de la Biblia) y, si no hay, de la paleta de game.json.

signal navigated(path: String)

const MIN_TOUCH: float = 88.0
const SCREEN_TITLE: String = "res://scenes/title.tscn"
const SCREEN_LEVELS: String = "res://scenes/levels.tscn"
const SCREEN_GAME: String = "res://scenes/main.tscn"
const SCREEN_HORDE: String = "res://scenes/horde.tscn"
const SCREEN_MATCH3: String = "res://scenes/match3.tscn"
const SCREEN_TOWER: String = "res://scenes/tower.tscn"
const SCREEN_RACE: String = "res://scenes/race.tscn"

var theme: Theme
var profile: String = "pixel"
var colors: Dictionary = {}
var font: Font
var test_mode: bool = false
## Piezas de la interfaz dibujada por la IA que se estan usando (vacio = la de siempre).
var skin_used: Array[String] = []
## Iconos dibujados por la IA (heart, star, trophy): UiIcon los usa en vez de los vectoriales.
var icons: Dictionary = {}
var nav_log: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rebuild("")


## 1 - Reconstruye el tema. force_profile permite probar los cuatro estilos.
func rebuild(force_profile: String) -> void:
	var cfg: Dictionary = Kit.assets.get("ui", {})
	profile = force_profile
	if profile == "":
		profile = str(cfg.get("perfil", Kit.param("ui.profile", "pixel")))
	if not UiTheme.PROFILES.has(profile):
		QA.fail("ui_profile_unknown", {"profile": profile})
		profile = "pixel"
	var fallback: Dictionary = {
		"fondo": Kit.color("sky", Color("#16233a")),
		"panel": Kit.color("sky", Color("#16233a")).lightened(0.12),
		"panel_hi": Kit.color("solid", Color("#3e5c84")),
		"borde": Kit.color("sky", Color("#16233a")).darkened(0.55),
		"texto": Color("#f4f6fb"),
		"texto_suave": Color("#a9b4c8"),
		"acento": Kit.color("accent", Color("#e8b04b")),
		"acento_texto": Color("#1a1205"),
		"exito": Color("#8fe3a5"),
		"peligro": Kit.color("danger", Color("#ff6b5b")),
	}
	colors = UiTheme.ensure_contrast(UiTheme.role_colors(cfg.get("colores", {}), fallback))
	font = UiTheme.load_font(profile, str(cfg.get("fuente", "")) if force_profile == "" else "")
	theme = UiTheme.build(profile, colors, font)
	## Interfaz dibujada por la IA si el juego la trae (y se lee bien); si no, la de siempre.
	skin_used = []
	var skin: Variant = cfg.get("skin", {})
	if skin is Dictionary and not (skin as Dictionary).is_empty() and force_profile == "":
		skin_used = UiTheme.apply_skin(theme, skin, colors, UiTheme.params(profile))
	load_icons(cfg.get("iconos", {}) if force_profile == "" else {})


## Carga los iconos del juego (solo los que existen y se pueden leer; los demas, vectoriales).
func load_icons(paths: Variant) -> void:
	icons = {}
	if not paths is Dictionary:
		return
	for k: String in ["heart", "star", "trophy"]:
		var tex: Texture2D = Kit.load_texture(str((paths as Dictionary).get(k, "")))
		if tex != null:
			icons[k] = tex


## Textura del icono (el corazon vacio es el mismo corazon apagado) o null si no hay arte.
func icon_art(kind: String) -> Texture2D:
	return icons.get("heart" if kind == "heart_empty" else kind, null)


func p() -> Dictionary:
	return UiTheme.params(profile)


## 2 - Boton con feeling: se hunde al tocarlo, rebota al soltar, suena y vibra.
func make_button(text: String, primary: bool = false, icon_kind: String = "") -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(MIN_TOUCH, 96.0)
	if primary:
		b.theme_type_variation = "PrimaryButton"
	if icon_kind != "":
		var col: Color = colors["acento_texto"] if primary else colors["texto"]
		## La moneda siempre con su color (en negro parece un agujero).
		if icon_kind == "coin":
			col = Kit.color("coin", colors["acento"]).lightened(0.15)
		var icon: UiIcon = UiIcon.make(icon_kind, col, 44.0)
		icon.set_anchors_preset(Control.PRESET_CENTER_LEFT)
		icon.position = Vector2(22.0, -22.0)
		b.add_child(icon)
		if text != "":
			b.text = "     " + text
	b.resized.connect(func() -> void: b.pivot_offset = b.size * 0.5)
	b.ready.connect(_add_shine.bind(b))
	b.button_down.connect(_press.bind(b))
	b.button_up.connect(_release.bind(b))
	b.pressed.connect(_click.bind(primary))
	return b


## Brillo arriba del boton (13 nov: «botones planos, interfaz sosa» en casi todas las criticas). Solo con
## esquinas redondeadas: el pixel art se queda con su boton plano.
func _add_shine(b: Button) -> void:
	if not is_instance_valid(b) or b.get_node_or_null("Shine") != null:
		return
	var box: StyleBox = b.get_theme_stylebox("normal")
	if not (box is StyleBoxFlat):
		return
	var flat: StyleBoxFlat = box as StyleBoxFlat
	var r: int = flat.corner_radius_top_left
	if r < 6:
		return
	var shine: Panel = Panel.new()
	shine.name = "Shine"
	shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st: StyleBoxFlat = StyleBoxFlat.new()
	st.bg_color = Color(1, 1, 1, 0.13)
	st.corner_radius_top_left = maxi(2, r - 4)
	st.corner_radius_top_right = maxi(2, r - 4)
	st.corner_radius_bottom_left = 4
	st.corner_radius_bottom_right = 4
	st.anti_aliasing = flat.anti_aliasing
	shine.add_theme_stylebox_override("panel", st)
	shine.anchor_right = 1.0
	shine.anchor_bottom = 0.42
	var m: float = float(flat.border_width_left) + 4.0
	shine.offset_left = m
	shine.offset_right = -m
	shine.offset_top = float(flat.border_width_top) + 3.0
	b.add_child(shine)
	b.move_child(shine, 0)


## Toque: el boton principal suena con mas cuerpo y vibra mas.
func _click(primary: bool = false) -> void:
	Audio.play("ui_big" if primary else "ui_tap", 0.05, -2.0 if primary else -4.0)
	Juice.vibrate(22 if primary else 12)


func make_icon_button(icon_kind: String) -> Button:
	var b: Button = make_button("", false, "")
	b.custom_minimum_size = Vector2(MIN_TOUCH + 8.0, MIN_TOUCH + 8.0)
	var icon: UiIcon = UiIcon.make(icon_kind, colors["texto"], 52.0)
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.add_child(icon)
	return b


func _press(b: Button) -> void:
	_scale(b, Vector2(0.92, 0.92), 0.06)


func _release(b: Button) -> void:
	_scale(b, Vector2.ONE, 0.22)


func _scale(c: Control, target: Vector2, seconds: float) -> void:
	var tw: Tween = c.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_curve(tw)
	if str(p()["anim"]) == "steps":
		tw.tween_property(c, "scale", target, seconds * 0.5).set_trans(Tween.TRANS_LINEAR)
	else:
		tw.tween_property(c, "scale", target, seconds)


func _curve(tw: Tween) -> void:
	match str(p()["anim"]):
		"elastic":
			tw.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		"back":
			tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		"smooth":
			tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_:
			tw.set_trans(Tween.TRANS_LINEAR)


## 3 - Entrada de un elemento (panel, boton, titulo) con el estilo del perfil.
func pop_in(c: Control, delay: float = 0.0) -> void:
	c.pivot_offset = c.size * 0.5
	c.scale = Vector2(0.6, 0.6)
	c.modulate.a = 0.0
	var tw: Tween = c.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_interval(delay)
	var dur: float = 0.12 if str(p()["anim"]) == "steps" else 0.38
	_curve(tw)
	tw.set_parallel(true)
	tw.tween_property(c, "scale", Vector2.ONE, dur)
	tw.tween_property(c, "modulate:a", 1.0, dur * 0.6)


## 4 - Numero que cuenta hacia arriba (monedas, puntos).
func count_up(label: Label, to: int, fmt: String, seconds: float = 0.8) -> void:
	var tw: Tween = label.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	var last: Array = [-1]
	var paint: Callable = func(v: float) -> void:
		label.text = fmt % int(v)
		## Tic de contador (unos 20 en todo el recorrido) que sube de tono al acercarse.
		var step: int = int(v * 20.0 / maxf(1.0, float(to)))
		if step != int(last[0]) and to > 0:
			last[0] = step
			Audio.play("ui_tick", 0.15, -14.0, 0.9 + 0.4 * v / maxf(1.0, float(to)))
	tw.tween_method(paint, 0.0, float(to), seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var done: Callable = func() -> void:
		if to > 0:
			Audio.play("ui_coin", 0.05, -8.0)
	tw.tween_callback(done)


## 4b - Texto flotante en el mundo ("+200", "x2"): sube y se desvanece.
func float_text(parent: Node, at: Vector2, text: String, col: Color, size_px: int = 34) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", col.lerp(Color.WHITE, 0.15))
	## Acabado de juego de movil: contorno grueso y sombra solida debajo.
	var border: Color = (colors["borde"] as Color).darkened(0.3)
	l.add_theme_constant_override("outline_size", maxi(8, int(float(size_px) * 0.3)))
	l.add_theme_color_override("font_outline_color", border)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", maxi(3, size_px / 9))
	l.add_theme_constant_override("shadow_outline_size", maxi(8, int(float(size_px) * 0.3)))
	l.z_index = 60
	## Efecto pasajero (crece, gira y se apaga): la auditoria de la interfaz no lo mide.
	l.set_meta("ui_ignore", true)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	l.reset_size()
	l.position = at - l.size * 0.5
	l.pivot_offset = l.size * 0.5
	l.scale = Vector2(0.3, 0.3)
	l.rotation = randf_range(-0.12, 0.12)
	var tw: Tween = l.create_tween()
	tw.set_parallel(true)
	## Rebote: crece de mas y vuelve; luego sube, se endereza y se apaga.
	tw.tween_property(l, "scale", Vector2(1.25, 1.25), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "scale", Vector2.ONE, 0.16).set_delay(0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "rotation", 0.0, 0.3).set_delay(0.1)
	tw.tween_property(l, "position:y", l.position.y - 80.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.25).set_delay(0.58)
	tw.chain().tween_callback(l.queue_free)
	return l


## 5 - Contenedor con margenes que respeta la zona segura (notch, barra de gestos).
func safe_root(parent: Control, pad: float = 32.0) -> MarginContainer:
	var m: MarginContainer = MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	var ins: Dictionary = safe_insets(parent.get_viewport())
	m.add_theme_constant_override("margin_left", int(pad + float(ins["left"])))
	m.add_theme_constant_override("margin_right", int(pad + float(ins["right"])))
	m.add_theme_constant_override("margin_top", int(pad + float(ins["top"])))
	m.add_theme_constant_override("margin_bottom", int(pad + float(ins["bottom"])))
	parent.add_child(m)
	return m


func safe_insets(vp: Viewport) -> Dictionary:
	var out: Dictionary = {"left": 0.0, "right": 0.0, "top": 0.0, "bottom": Ads.banner_space(vp)}
	if not OS.has_feature("mobile"):
		return out
	var screen: Vector2 = Vector2(DisplayServer.screen_get_size())
	var safe: Rect2 = Rect2(DisplayServer.get_display_safe_area())
	if screen.x <= 0.0 or screen.y <= 0.0:
		return out
	var k: Vector2 = vp.get_visible_rect().size / screen
	out["left"] = safe.position.x * k.x
	out["top"] = safe.position.y * k.y
	out["right"] = (screen.x - safe.end.x) * k.x
	out["bottom"] = (screen.y - safe.end.y) * k.y + Ads.banner_space(vp)
	return out


func safe_rect(vp: Viewport) -> Rect2:
	var r: Rect2 = vp.get_visible_rect()
	var ins: Dictionary = safe_insets(vp)
	return Rect2(r.position + Vector2(float(ins["left"]), float(ins["top"])),
		r.size - Vector2(float(ins["left"]) + float(ins["right"]), float(ins["top"]) + float(ins["bottom"])))


## 6 - Navegacion entre pantallas (en modo prueba solo se anota).
## 4 - Escena de juego segun el genero (game.json -> genre), del registro Genres.
func game_scene() -> String:
	return Genres.scene(Genres.current())


func goto(path: String) -> void:
	nav_log.append(path)
	## Banner segun la pantalla que viene (antes de montarla, para que deje su hueco).
	Ads.set_banner("menu" if path == SCREEN_TITLE or path == SCREEN_LEVELS else ("game" if path == game_scene() else ""))
	navigated.emit(path)
	## Cada pantalla empieza con la musica abierta (los juegos la ajustan despues).
	Audio.set_intensity(1.0)
	## Al entrar a jugar, el heroe dice su frase de inicio (si el juego tiene voz).
	if path == game_scene():
		Audio.play_voice("inicio")
	if test_mode:
		return
	get_tree().paused = false
	## Transicion de juego grande: un circulo que se cierra, cambio de escena y se vuelve a abrir.
	await _iris(0.0, 0.2)
	Kit.change_scene(path)
	await get_tree().process_frame
	_iris(1.0, 0.32)


var _iris_layer: CanvasLayer
var _iris_rect: ColorRect
const IRIS_SHADER: String = """shader_type canvas_item;
uniform float open_r = 1.5;
uniform vec4 tint : source_color = vec4(0.04, 0.05, 0.09, 1.0);
uniform float aspect = 0.5625;
void fragment() {
	vec2 p = (UV - vec2(0.5)) * vec2(1.0, 1.0 / aspect);
	float d = length(p) - open_r;
	COLOR = vec4(tint.rgb, smoothstep(-0.01, 0.01, d));
}"""


## Abre (to = 1) o cierra (to = 0) el circulo que tapa la pantalla.
func _iris(to: float, seconds: float) -> void:
	if _iris_layer == null:
		_iris_layer = CanvasLayer.new()
		_iris_layer.layer = 120
		add_child(_iris_layer)
		_iris_rect = ColorRect.new()
		_iris_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_iris_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sh: Shader = Shader.new()
		sh.code = IRIS_SHADER
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = sh
		_iris_rect.material = mat
		_iris_layer.add_child(_iris_rect)
	var sz: Vector2 = get_viewport().get_visible_rect().size
	var mat2: ShaderMaterial = _iris_rect.material as ShaderMaterial
	mat2.set_shader_parameter("aspect", sz.x / maxf(1.0, sz.y))
	mat2.set_shader_parameter("tint", colors.get("fondo", Color(0.04, 0.05, 0.09)) as Color)
	_iris_rect.visible = true
	_iris_rect.mouse_filter = Control.MOUSE_FILTER_STOP if to < 0.5 else Control.MOUSE_FILTER_IGNORE
	if to < 0.5:
		Audio.play("ui_swoosh", 0.05, -10.0)
	var tw: Tween = create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_method(func(r: float) -> void: mat2.set_shader_parameter("open_r", r), 1.3 if to < 0.5 else 0.0, 0.0 if to < 0.5 else 1.3, seconds) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN if to < 0.5 else Tween.EASE_OUT)
	await tw.finished
	if to >= 0.5:
		_iris_rect.visible = false


## 4c - Monedas que vuelan de un punto de la pantalla al contador (al cobrar un premio).
func fly_coins(parent: Node, from: Vector2, to: Vector2, amount: int) -> void:
	var n: int = clampi(amount / 10, 3, 12)
	var col: Color = Kit.color("coin", colors.get("acento", Color.GOLD)).lightened(0.15)
	for i: int in n:
		var c: UiIcon = UiIcon.make("coin", col, 40.0)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.z_index = 80
		parent.add_child(c)
		c.position = from + Vector2(randf_range(-50, 50), randf_range(-40, 40))
		var mid: Vector2 = c.position.lerp(to, 0.4) + Vector2(randf_range(-120, 120), -140.0)
		var tw: Tween = c.create_tween()
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_interval(0.04 * float(i))
		var start: Vector2 = c.position
		tw.tween_method(func(t: float) -> void: c.position = start.lerp(mid, t).lerp(mid.lerp(to, t), t), 0.0, 1.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_callback(func() -> void:
			Audio.play("ui_tick", 0.2, -10.0, 1.2)
			c.queue_free())


## 7 - Auditoria de una pantalla: botones del tamano del dedo, textos sin cortar,
## todo dentro de la zona segura y contraste legible. Devuelve los problemas encontrados.
func audit(root: Node) -> Array[String]:
	var out: Array[String] = []
	var vp: Viewport = root.get_viewport()
	var safe: Rect2 = safe_rect(vp).grow(1.0)
	for n: Node in _controls(root):
		var c: Control = n as Control
		if not c.is_visible_in_tree() or c.has_meta("ui_ignore") or _scrolled_out(c):
			continue
		var r: Rect2 = c.get_global_rect()
		if c is Button:
			if r.size.x < MIN_TOUCH - 0.5 or r.size.y < MIN_TOUCH - 0.5:
				out.append("boton pequeno '%s' %s" % [c.name, str(r.size)])
		if c is Button or c is Label:
			if not safe.encloses(r):
				out.append("fuera de la zona segura '%s'" % c.name)
			var txt: String = (c as Button).text if c is Button else (c as Label).text
			var autowrap: bool = c is Label and (c as Label).autowrap_mode != TextServer.AUTOWRAP_OFF
			if txt.strip_edges() != "" and not autowrap:
				var f: Font = c.get_theme_font("font")
				var fs: int = c.get_theme_font_size("font_size")
				## Con saltos de linea manda la linea mas larga.
				var w: float = 0.0
				for line: String in txt.split("\n"):
					w = maxf(w, f.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
				var room: float = r.size.x
				if c is Button:
					var sb: StyleBox = c.get_theme_stylebox("normal")
					room -= sb.get_margin(SIDE_LEFT) + sb.get_margin(SIDE_RIGHT)
				## Una etiqueta que se recorta con "..." a proposito (nombres largos) no es un fallo.
				var trims: bool = c is Label and (c as Label).text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING
				if w > room + 2.0 and not trims:
					out.append("texto cortado '%s' (%d > %d)" % [c.name, int(w), int(room)])
	return out


## 7b - Legibilidad (solo informa: la usa la galeria para revisar la interfaz de cada genero):
## letra por debajo de MIN_FONT y textos casi transparentes sin contorno.
const MIN_FONT: int = 18


func legibility(root: Node) -> Array[String]:
	var out: Array[String] = []
	for n: Node in _controls(root):
		var c: Control = n as Control
		if not (c is Label or c is Button) or not c.is_visible_in_tree() or c.has_meta("ui_ignore") or _scrolled_out(c):
			continue
		var txt: String = (c as Button).text if c is Button else (c as Label).text
		if txt.strip_edges() == "":
			continue
		var fs: int = c.get_theme_font_size("font_size")
		if fs < MIN_FONT:
			out.append("letra pequena '%s' (%dpx): %s" % [c.name, fs, txt.left(30)])
		var col: Color = c.get_theme_color("font_color")
		var a: float = col.a * c.modulate.a * c.self_modulate.a
		if c is Label and a < 0.55 and c.get_theme_constant("outline_size") <= 0:
			out.append("texto apagado '%s' (%d%%): %s" % [c.name, int(a * 100.0), txt.left(30)])
	return out


## Lo que queda fuera de un ScrollContainer no esta en pantalla: se ve al desplazar.
func _scrolled_out(c: Control) -> bool:
	var n: Node = c.get_parent()
	while n != null:
		if n is ScrollContainer:
			return not (n as Control).get_global_rect().grow(1.0).encloses(c.get_global_rect())
		n = n.get_parent()
	return false


func _controls(root: Node) -> Array[Node]:
	var out: Array[Node] = []
	if root is Control:
		out.append(root)
	for ch: Node in root.get_children():
		out.append_array(_controls(ch))
	return out
