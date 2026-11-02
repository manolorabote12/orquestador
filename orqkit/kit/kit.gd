extends Node
## Kit: configuracion del juego (game.json), acciones de entrada y cambio de escena con fundido.
## Autoload "Kit". Sin class_name (regla: nunca class_name + Autoload).

const VERSION: String = "0.1.0"
const CONFIG_PATH: String = "res://game.json"
const ASSETS_PATH: String = "res://assets/manifest.json"

signal config_changed

var config: Dictionary = {}
var assets: Dictionary = {}
var level_index: int = 0

var _fade_layer: CanvasLayer
var _fade_rect: ColorRect

const DEFAULT_CONFIG: Dictionary = {
	"title": "Mi juego",
	"tile_size": 64,
	"palette": {"sky": "#1b2a41", "solid": "#e8f0fa", "accent": "#e8b04b", "danger": "#ff6b5b", "coin": "#f6cf7a"},
	"player": {},
	"levels": [],
	"texts": {},
}

const ACTIONS: Dictionary = {
	"move_left": [KEY_LEFT, KEY_A],
	"move_right": [KEY_RIGHT, KEY_D],
	"move_up": [KEY_UP, KEY_W],
	"move_down": [KEY_DOWN, KEY_S],
	"jump": [KEY_SPACE, KEY_UP, KEY_W],
	"pause": [KEY_ESCAPE, KEY_P],
	"shoot": [KEY_X, KEY_J, KEY_K],
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_actions()
	load_config(CONFIG_PATH)
	load_assets(ASSETS_PATH)
	_build_fade()


## 1 - Carga game.json y lo mezcla con los valores por defecto.
func load_config(path: String) -> void:
	var loaded: Dictionary = {}
	if FileAccess.file_exists(path):
		var text: String = FileAccess.get_file_as_string(path)
		var parsed: Variant = JSON.parse_string(text)
		if parsed is Dictionary:
			loaded = parsed
		else:
			push_error("Kit: game.json no es un objeto JSON valido")
			QA.fail("config_invalid", {"path": path})
	set_config(loaded)


## 5 - Arte y sonidos generados por la fabrica. Sin manifest, el juego usa formas simples.
func load_assets(path: String) -> void:
	assets = {}
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		assets = parsed
	else:
		QA.fail("assets_manifest_invalid", {"path": path})


func sprite_entry(id: String) -> Dictionary:
	var sprites: Dictionary = assets.get("sprites", {})
	return sprites.get(id, {})


func sprite_by_role(role: String) -> Dictionary:
	var sprites: Dictionary = assets.get("sprites", {})
	for id: String in sprites.keys():
		var entry: Dictionary = sprites[id]
		if str(entry.get("rol", "")) == role:
			return entry
	return {}


## Pone la textura de casilla de la IA a un poligono (se repite a su escala, tenida con su color).
## px: cuantos pixeles de juego ocupa una repeticion de la textura.
func texture_polygon(poly: Polygon2D, px: float = 64.0) -> bool:
	var tex: Texture2D = first_tile_texture()
	if tex == null:
		return false
	poly.texture = tex
	poly.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var k: float = float(tex.get_width()) / maxf(px, 1.0)
	var uv: PackedVector2Array = PackedVector2Array()
	for v: Vector2 in poly.polygon:
		uv.append(v * k)
	poly.uv = uv
	return true


## Se guarda: las llamadas draw_* no retienen la textura y, si nadie la retiene, se dibuja en blanco.
var _tile_cache: Texture2D = null
var _tile_cache_path: String = ""


func first_tile_texture() -> Texture2D:
	var tiles: Dictionary = assets.get("tiles", {})
	for id: String in tiles.keys():
		var path: String = str(tiles[id])
		if path == _tile_cache_path and _tile_cache != null:
			return _tile_cache
		var tex: Texture2D = load(path) as Texture2D
		if tex != null:
			_tile_cache = tex
			_tile_cache_path = path
			return tex
	return null


## Textura de una ruta del manifiesto: res:// importada o, en las pruebas, un png de user://.
func load_texture(path: String) -> Texture2D:
	if path == "":
		return null
	if path.begins_with("user://"):
		if not FileAccess.file_exists(path):
			return null
		var img: Image = Image.load_from_file(path)
		return ImageTexture.create_from_image(img) if img != null else null
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


## 2 - Permite a los tests y al agente inyectar una configuracion completa.
## Lo que lleva el juego (game.json -> "features"; lo elige el autor en la app). Por defecto, si.
func feature(name: String) -> bool:
	var f: Variant = config.get("features", {})
	return bool((f as Dictionary).get(name, true)) if f is Dictionary else true


## Juego para ninos (menores de 13): sin compras, avisos ni nada online (normas de Google Play).
func kids() -> bool:
	return bool(config.get("kids", false))


func set_config(data: Dictionary) -> void:
	_lang = ""
	config = DEFAULT_CONFIG.duplicate(true)
	for key: String in data.keys():
		config[key] = data[key]
	config_changed.emit()


## 3 - Lee un valor anidado: Kit.param("player.run_speed", 420.0)
func param(path: String, fallback: Variant) -> Variant:
	var node: Variant = config
	for part: String in path.split("."):
		if node is Dictionary and (node as Dictionary).has(part):
			node = (node as Dictionary)[part]
		else:
			return fallback
	return node


## 3b - Idiomas: game.json -> "lang" (el del juego, "es") e "i18n": {"en": {clave: texto, "_levels": [...],
## "_story": [...]}, ...}. Se usa el que eligio el jugador en Ajustes, si no el del movil, si no el del juego.
var _lang: String = ""


func base_lang() -> String:
	return str(config.get("lang", "es"))


func languages() -> Array[String]:
	var out: Array[String] = [base_lang()]
	var i18n: Variant = config.get("i18n", {})
	if i18n is Dictionary:
		for l: String in (i18n as Dictionary).keys():
			if not out.has(l):
				out.append(l)
	return out


func lang() -> String:
	if _lang == "":
		## Hasta que el guardado este listo no se decide (y no se guarda la decision).
		if not Save.is_node_ready():
			return base_lang()
		var langs: Array[String] = languages()
		var saved: String = str(Save.get_setting("lang", ""))
		var device: String = OS.get_locale_language()
		_lang = saved if langs.has(saved) else (device if langs.has(device) else base_lang())
	return _lang


func set_lang(l: String) -> void:
	if not languages().has(l):
		return
	_lang = l
	Save.set_setting("lang", l)
	config_changed.emit()


func _tr() -> Dictionary:
	if lang() == base_lang():
		return {}
	var i18n: Variant = config.get("i18n", {})
	var t: Variant = (i18n as Dictionary).get(_lang, {}) if i18n is Dictionary else {}
	return t if t is Dictionary else {}


func text(key: String, fallback: String) -> String:
	var tr: Dictionary = _tr()
	if tr.has(key):
		return str(tr[key])
	var texts: Dictionary = config.get("texts", {})
	return str(texts.get(key, fallback))


## Nombre del idioma para el selector de Ajustes.
func lang_name(l: String) -> String:
	var names: Dictionary = {"es": "Espa\u00f1ol", "en": "English", "pt": "Portugu\u00eas", "fr": "Fran\u00e7ais", "de": "Deutsch", "it": "Italiano"}
	if names.has(l):
		return str(names[l])
	## Los demas idiomas traen su nombre en su tabla (la fabrica lo pone en "_name").
	var i18n: Variant = config.get("i18n", {})
	if i18n is Dictionary and (i18n as Dictionary).get(l, {}) is Dictionary:
		return str(((i18n as Dictionary)[l] as Dictionary).get("_name", l))
	return l


func color(key: String, fallback: Color) -> Color:
	var pal: Dictionary = config.get("palette", {})
	var value: String = str(pal.get(key, ""))
	if value.is_empty():
		return fallback
	return Color.from_string(value, fallback)


## Nivel extra (reto del dia con niveles nuevos, game.json -> "daily_levels"): se juega con
## level_index = extra_index (uno despues del ultimo), asi no toca estrellas ni desbloqueos.
var extra_level: Dictionary = {}
var extra_index: int = -1
## Modo 2 jugadores en el mismo movil (Versus): el rival lo mueve una persona.
var versus: bool = false
## Modo maraton (Marathon): vidas, niveles superados y puntos de la partida en curso.
var marathon: Dictionary = {}
## Contrarreloj encendido (kit/time_attack.gd).
var time_attack: bool = false
## Modo experto encendido (kit/expert.gd).
var expert: bool = false


func is_extra() -> bool:
	return extra_index >= 0 and level_index == extra_index and not extra_level.is_empty()


func current_level() -> Dictionary:
	if is_extra():
		return extra_level.duplicate(true)
	var levels: Array = config.get("levels", [])
	if levels.is_empty():
		return {}
	var i: int = clampi(level_index, 0, levels.size() - 1)
	var lv: Dictionary = levels[i]
	## Prueba A/B: la mitad de los jugadores (grupo "b") juega la otra version de este nivel.
	if ab_level() == i and ab_group() == "b" and lv.get("variant_b") is Dictionary:
		lv = lv.duplicate()
		lv.merge(lv["variant_b"], true)
		lv.erase("variant_b")
	## Traduccion del nivel (nombre, preguntas...) encima del original.
	var over: Variant = _tr().get("_levels", [])
	if over is Array and i < (over as Array).size() and (over as Array)[i] is Dictionary:
		lv = lv.duplicate()
		lv.merge((over as Array)[i], true)
	return lv


## 3b - Prueba A/B de un nivel (config "ab": {"level", "id"}). El grupo es una moneda al aire que
## se guarda en el movil la primera vez: no identifica a nadie y no cambia entre partidas.
## ab_force lo usan los bots para probar la version B.
var ab_force: String = ""


func ab_level() -> int:
	var ab: Variant = config.get("ab", {})
	if not (ab is Dictionary) or not (ab as Dictionary).has("level"):
		return -1
	return int((ab as Dictionary)["level"])


func ab_group() -> String:
	if ab_force != "":
		return ab_force
	var ab: Variant = config.get("ab", {})
	if not (ab is Dictionary) or ab_level() < 0:
		return ""
	var key: String = "ab_" + str((ab as Dictionary).get("id", "x"))
	var g: String = str(Save.get_setting(key, ""))
	if g != "a" and g != "b":
		g = "a" if randi() % 2 == 0 else "b"
		Save.set_setting(key, g)
	return g


func level_count() -> int:
	var levels: Array = config.get("levels", [])
	return levels.size()


## 4 - Cambio de escena con fundido a negro.
func change_scene(path: String, seconds: float = 0.25) -> void:
	var tween: Tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_fade_rect, "color:a", 1.0, seconds)
	await tween.finished
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	var back: Tween = create_tween()
	back.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	back.tween_property(_fade_rect, "color:a", 0.0, seconds)


func reload_scene(seconds: float = 0.25) -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	await change_scene(scene.scene_file_path, seconds)


func _ensure_actions() -> void:
	for action: String in ACTIONS.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		for code: int in ACTIONS[action]:
			var ev: InputEventKey = InputEventKey.new()
			ev.physical_keycode = code as Key
			if not InputMap.action_has_event(action, ev):
				InputMap.action_add_event(action, ev)


func _build_fade() -> void:
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 100
	add_child(_fade_layer)
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_layer.add_child(_fade_rect)


## Vidas del jugador con las mejoras compradas en la tienda (los bots validan sin mejoras).
func player_hp(base: float) -> float:
	return base + float(Save.upgrade_level("heart"))
