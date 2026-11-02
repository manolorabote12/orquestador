class_name UiTheme
extends RefCounted
## Construye el tema visual de Godot a partir de un PERFIL de estilo y de los colores por rol.
## Perfiles: pixel, cartoon, low_poly, realista. Cada uno fija formas, bordes, relieve,
## sombras, tamanos de letra, tipografia y el tipo de animacion de la interfaz.

const PROFILES: Dictionary = {
	"pixel": {
		"font": "PixelifySans.ttf", "weight": 600, "pixel_font": true,
		"radius": 0, "corner_detail": 1, "aa": false, "border": 4, "bevel": 8, "shadow": 0,
		"pad_x": 28, "pad_y": 12, "font_size": 32, "button_font": 34, "title_size": 78,
		"outline": 8, "panel_alpha": 1.0, "anim": "steps",
	},
	"cartoon": {
		"font": "Fredoka.ttf", "weight": 600, "pixel_font": false,
		"radius": 30, "corner_detail": 8, "aa": true, "border": 6, "bevel": 12, "shadow": 0,
		"pad_x": 30, "pad_y": 14, "font_size": 32, "button_font": 36, "title_size": 86,
		"outline": 10, "panel_alpha": 1.0, "anim": "elastic",
	},
	"low_poly": {
		"font": "ChakraPetch-Bold.ttf", "weight": 700, "pixel_font": false,
		"radius": 22, "corner_detail": 1, "aa": true, "border": 3, "bevel": 9, "shadow": 10,
		"pad_x": 30, "pad_y": 14, "font_size": 30, "button_font": 32, "title_size": 76,
		"outline": 0, "panel_alpha": 0.96, "anim": "back",
	},
	"realista": {
		"font": "Exo2.ttf", "weight": 600, "pixel_font": false,
		"radius": 14, "corner_detail": 8, "aa": true, "border": 1, "bevel": 0, "shadow": 22,
		"pad_x": 32, "pad_y": 16, "font_size": 30, "button_font": 30, "title_size": 70,
		"outline": 0, "panel_alpha": 0.86, "anim": "smooth",
	},
}

const ROLES: Array[String] = ["fondo", "panel", "panel_hi", "borde", "texto", "texto_suave", "acento", "acento_texto", "exito", "peligro"]


static func params(profile: String) -> Dictionary:
	return PROFILES.get(profile, PROFILES["pixel"])


## 1 - Colores por rol: los que manda la fabrica y, si falta alguno, los de la paleta del juego.
static func role_colors(src: Dictionary, fallback: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for role: String in ROLES:
		var value: String = str(src.get(role, ""))
		if value != "":
			out[role] = Color.from_string(value, fallback.get(role, Color.MAGENTA))
		else:
			out[role] = fallback.get(role, Color.MAGENTA)
	return out


## 2 - Contraste WCAG entre dos colores (4.5 o mas = texto legible).
static func contrast(a: Color, b: Color) -> float:
	var la: float = _luminance(a)
	var lb: float = _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


## 3 - Garantiza texto legible (4.5:1) en cualquier paleta: primero prueba texto claro u
## oscuro y, si no basta, oscurece o aclara el fondo poco a poco.
static func ensure_contrast(c: Dictionary) -> Dictionary:
	var out: Dictionary = c.duplicate()
	for bg_role: String in ["fondo", "panel", "panel_hi"]:
		out[bg_role] = _fix_bg(out[bg_role], out["texto"])
	out["texto_suave"] = _fix_text(out["texto_suave"], out["panel"], 3.0)
	if contrast(out["acento_texto"], out["acento"]) < 4.5:
		var dark: Color = Color("#141414")
		var light: Color = Color("#fafafa")
		out["acento_texto"] = dark if contrast(dark, out["acento"]) >= contrast(light, out["acento"]) else light
	out["acento"] = _fix_bg(out["acento"], out["acento_texto"])
	return out


static func _fix_bg(bg: Color, text: Color) -> Color:
	var b: Color = bg
	var text_is_light: bool = _luminance(text) > 0.4
	var guard: int = 0
	while contrast(text, b) < 4.5 and guard < 40:
		b = b.darkened(0.06) if text_is_light else b.lightened(0.06)
		guard += 1
	return b


static func _fix_text(text: Color, bg: Color, target: float) -> Color:
	var t: Color = text
	var bg_is_dark: bool = _luminance(bg) < 0.4
	var guard: int = 0
	while contrast(t, bg) < target and guard < 40:
		t = t.lightened(0.08) if bg_is_dark else t.darkened(0.08)
		guard += 1
	return t


static func _luminance(c: Color) -> float:
	var ch: Array[float] = [c.r, c.g, c.b]
	var lin: Array[float] = []
	for v: float in ch:
		lin.append(v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4))
	return 0.2126 * lin[0] + 0.7152 * lin[1] + 0.0722 * lin[2]


static func load_font(profile: String, override_file: String) -> Font:
	var p: Dictionary = params(profile)
	var file: String = override_file if override_file != "" else str(p["font"])
	var ff: FontFile = load("res://kit/ui/fonts/" + file) as FontFile
	if ff == null:
		QA.fail("ui_font_missing", {"file": file})
		return ThemeDB.fallback_font
	if bool(p["pixel_font"]):
		ff.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		ff.hinting = TextServer.HINTING_NONE
		ff.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	## Japones, chino, arabe, ruso, hindi...: lo que no tiene la letra del juego sale con las fuentes
	## del propio movil (sin pesar nada en el juego).
	var sys: SystemFont = SystemFont.new()
	sys.font_names = PackedStringArray(["sans-serif", "Noto Sans", "Noto Sans CJK JP", "Noto Sans Arabic", "Droid Sans Fallback", "Roboto"])
	ff.fallbacks = [sys]
	var fv: FontVariation = FontVariation.new()
	fv.base_font = ff
	var ts: TextServer = TextServerManager.get_primary_interface()
	fv.variation_opentype = {ts.name_to_tag("wght"): int(p["weight"])}
	return fv


static func build(profile: String, c: Dictionary, font: Font) -> Theme:
	var p: Dictionary = params(profile)
	var t: Theme = Theme.new()
	t.default_font = font
	t.default_font_size = int(p["font_size"])

	## 3 - Botones: relieve inferior que desaparece al pulsar (el texto baja con el dedo).
	t.set_stylebox("normal", "Button", _box(c["panel_hi"], c["borde"], p, false))
	t.set_stylebox("hover", "Button", _box((c["panel_hi"] as Color).lightened(0.08), c["borde"], p, false))
	t.set_stylebox("pressed", "Button", _box((c["panel_hi"] as Color).darkened(0.06), c["borde"], p, true))
	t.set_stylebox("disabled", "Button", _box((c["panel"] as Color).darkened(0.15), (c["borde"] as Color), p, false))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", c["texto"])
	t.set_color("font_hover_color", "Button", c["texto"])
	t.set_color("font_pressed_color", "Button", c["texto"])
	t.set_color("font_focus_color", "Button", c["texto"])
	t.set_color("font_disabled_color", "Button", c["texto_suave"])
	t.set_font_size("font_size", "Button", int(p["button_font"]))
	_outline(t, "Button", c, p, 0.5)

	t.set_type_variation("PrimaryButton", "Button")
	t.set_stylebox("normal", "PrimaryButton", _box(c["acento"], c["borde"], p, false))
	t.set_stylebox("hover", "PrimaryButton", _box((c["acento"] as Color).lightened(0.08), c["borde"], p, false))
	t.set_stylebox("pressed", "PrimaryButton", _box((c["acento"] as Color).darkened(0.08), c["borde"], p, true))
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(key, "PrimaryButton", c["acento_texto"])
	t.set_constant("outline_size", "PrimaryButton", 0)

	## 4 - Paneles.
	var panel: StyleBoxFlat = _box(c["panel"], c["borde"], p, false)
	panel.bg_color.a = float(p["panel_alpha"])
	panel.border_width_bottom = int(p["border"]) + int(int(p["bevel"]) * 0.6)
	panel.set_content_margin_all(float(p["pad_x"]) + 8.0)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)

	## 5 - Textos: normal, titulo y secundario.
	t.set_color("font_color", "Label", c["texto"])
	_outline(t, "Label", c, p, 0.5)
	t.set_type_variation("TitleLabel", "Label")
	t.set_font_size("font_size", "TitleLabel", int(p["title_size"]))
	_outline(t, "TitleLabel", c, p, 1.0)
	t.set_type_variation("HeaderLabel", "Label")
	t.set_font_size("font_size", "HeaderLabel", int(int(p["title_size"]) * 0.62))
	t.set_type_variation("SubtleLabel", "Label")
	t.set_color("font_color", "SubtleLabel", c["texto_suave"])
	t.set_font_size("font_size", "SubtleLabel", int(int(p["font_size"]) * 0.8))

	## 6 - Deslizadores e interruptores de los ajustes.
	var track: StyleBoxFlat = _box((c["borde"] as Color), c["borde"], p, false)
	track.set_border_width_all(0)
	track.shadow_size = 0
	track.content_margin_top = 10.0
	track.content_margin_bottom = 10.0
	t.set_stylebox("slider", "HSlider", track)
	var fill: StyleBoxFlat = track.duplicate() as StyleBoxFlat
	fill.bg_color = c["acento"]
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	## Barras de progreso (energia, misiones, pase): fondo oscuro y relleno del color de acento.
	var bar_bg: StyleBoxFlat = track.duplicate() as StyleBoxFlat
	bar_bg.bg_color = (c["fondo"] as Color).darkened(0.35)
	bar_bg.set_border_width_all(2)
	bar_bg.border_color = c["borde"]
	bar_bg.content_margin_top = 0.0
	bar_bg.content_margin_bottom = 0.0
	t.set_stylebox("background", "ProgressBar", bar_bg)
	var bar_fill: StyleBoxFlat = fill.duplicate() as StyleBoxFlat
	bar_fill.content_margin_top = 0.0
	bar_fill.content_margin_bottom = 0.0
	t.set_stylebox("fill", "ProgressBar", bar_fill)
	t.set_color("font_color", "CheckButton", c["texto"])
	t.set_font_size("font_size", "CheckButton", int(p["font_size"]))
	return t


## 7 - Interfaz dibujada por la IA (assets/ui/panel.png, boton.png, boton_primario.png).
## Solo se usa si el texto se lee sobre el centro de cada pieza; si no, se queda la de siempre.
## Devuelve la lista de piezas aplicadas.
static func apply_skin(t: Theme, skin: Dictionary, c: Dictionary, p: Dictionary) -> Array[String]:
	var used: Array[String] = []
	var checks: Array = [["panel", "panel", c["texto"]], ["boton", "boton", c["texto"]], ["boton_primario", "boton_primario", c["acento_texto"]]]
	var tex: Dictionary = {}
	for chk: Array in checks:
		var path: String = str(skin.get(chk[1], ""))
		var tx: Texture2D = _scaled(Kit.load_texture(path), SKIN_SCALE)
		if tx == null:
			continue
		var center: Color = _center_color(tx)
		if contrast(chk[2], center) < 4.0:
			QA.log_event("ui_skin_rejected", {"piece": chk[0], "contrast": contrast(chk[2], center)})
			continue
		tex[chk[0]] = tx
	if tex.has("panel"):
		var m: float = roundf(float(skin.get("margen_panel", 64)) * SKIN_SCALE)
		var sb: StyleBoxTexture = _tex_box(tex["panel"], m, float(p["pad_x"]) + 18.0)
		t.set_stylebox("panel", "PanelContainer", sb)
		t.set_stylebox("panel", "Panel", sb)
		used.append("panel")
	if tex.has("boton"):
		var mb: float = roundf(float(skin.get("margen_boton", 40)) * SKIN_SCALE)
		t.set_stylebox("normal", "Button", _tex_box(tex["boton"], mb, float(p["pad_x"]), Color.WHITE))
		t.set_stylebox("hover", "Button", _tex_box(tex["boton"], mb, float(p["pad_x"]), Color(1.1, 1.1, 1.1)))
		t.set_stylebox("pressed", "Button", _tex_box(tex["boton"], mb, float(p["pad_x"]), Color(0.82, 0.82, 0.86), 4.0))
		t.set_stylebox("disabled", "Button", _tex_box(tex["boton"], mb, float(p["pad_x"]), Color(0.6, 0.6, 0.65, 0.75)))
		used.append("boton")
	if tex.has("boton_primario"):
		var mp: float = roundf(float(skin.get("margen_boton", 40)) * SKIN_SCALE)
		t.set_stylebox("normal", "PrimaryButton", _tex_box(tex["boton_primario"], mp, float(p["pad_x"]), Color.WHITE))
		t.set_stylebox("hover", "PrimaryButton", _tex_box(tex["boton_primario"], mp, float(p["pad_x"]), Color(1.1, 1.1, 1.1)))
		t.set_stylebox("pressed", "PrimaryButton", _tex_box(tex["boton_primario"], mp, float(p["pad_x"]), Color(0.82, 0.82, 0.86), 4.0))
		used.append("boton_primario")
	return used


## La pieza llega grande (para que no se pixele); el marco se dibuja a esta escala.
const SKIN_SCALE: float = 0.55


static func _scaled(tx: Texture2D, k: float) -> Texture2D:
	if tx == null:
		return null
	var img: Image = tx.get_image()
	if img == null:
		return tx
	if img.is_compressed():
		img.decompress()
	img.resize(maxi(8, int(img.get_width() * k)), maxi(8, int(img.get_height() * k)), Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(img)


static func _tex_box(tx: Texture2D, margin: float, pad: float, mod: Color = Color.WHITE, push: float = 0.0) -> StyleBoxTexture:
	var sb: StyleBoxTexture = StyleBoxTexture.new()
	sb.texture = tx
	sb.set_texture_margin_all(margin)
	sb.modulate_color = mod
	sb.set_expand_margin_all(0.0)
	## El texto va dentro del marco, nunca encima.
	sb.content_margin_left = maxf(pad, margin * 1.05)
	sb.content_margin_right = maxf(pad, margin * 1.05)
	sb.content_margin_top = maxf(10.0, margin * 0.8) + push
	sb.content_margin_bottom = maxf(10.0, margin * 0.8) - push * 0.5
	return sb


## Color medio del centro de la pieza (donde va el texto).
static func _center_color(tx: Texture2D) -> Color:
	var img: Image = tx.get_image()
	if img == null:
		return Color.BLACK
	if img.is_compressed():
		img.decompress()
	var w: int = img.get_width()
	var h: int = img.get_height()
	var acc: Color = Color(0, 0, 0, 0)
	var n: int = 0
	for y: int in range(int(h * 0.4), int(h * 0.6), maxi(1, h / 40)):
		for x: int in range(int(w * 0.35), int(w * 0.65), maxi(1, w / 40)):
			acc += img.get_pixel(x, y)
			n += 1
	return Color(acc.r / n, acc.g / n, acc.b / n) if n > 0 else Color.BLACK


static func _box(bg: Color, border: Color, p: Dictionary, pressed: bool) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_corner_radius_all(int(p["radius"]))
	s.corner_detail = int(p["corner_detail"])
	s.anti_aliasing = bool(p["aa"])
	s.set_border_width_all(int(p["border"]))
	var bevel: int = int(p["bevel"])
	s.border_width_bottom = int(p["border"]) + (0 if pressed else bevel)
	s.content_margin_left = float(p["pad_x"])
	s.content_margin_right = float(p["pad_x"])
	s.content_margin_top = float(p["pad_y"]) + (float(bevel) if pressed else 0.0)
	s.content_margin_bottom = float(p["pad_y"])
	var shadow: int = int(p["shadow"])
	if shadow > 0 and not pressed:
		s.shadow_size = shadow
		s.shadow_color = Color(0, 0, 0, 0.32)
		s.shadow_offset = Vector2(0.0, float(shadow) * 0.4)
	return s


static func _outline(t: Theme, type_name: String, c: Dictionary, p: Dictionary, k: float) -> void:
	var size: int = int(float(int(p["outline"])) * k)
	if size <= 0:
		return
	t.set_constant("outline_size", type_name, size)
	t.set_color("font_outline_color", type_name, c["borde"])
