extends Node
## Giros: reglas raras que se ponen ENCIMA de cualquier genero (game.json -> "twists": ["id", ...]).
## Autoload "Twist". La fabrica solo pone giros compatibles con el genero y los prueba con los
## bots; si un giro hace un nivel injusto, la fabrica lo quita y aprende (fabrica/giros.py).
## Genericos (este archivo):
## 1 - "oscuridad": solo ves lo que alumbra tu linterna (un circulo alrededor del heroe).
## 2 - "espejo": el mundo se ve al reves (izquierda <-> derecha); los mandos y la interfaz no
##     (capas 10 y 20: el espejo va en la 5 y la oscuridad en la 6).
## 3 - "contrarreloj": cada intento tiene un tiempo (levels[i].time_limit); si se acaba, a empezar.
## 4 - "racha": cada nivel superado sin morir sube el multiplicador de monedas (hasta x3).
## 5 - "fantasma": corres contra tu mejor partida del nivel. Una figura transparente repite el
##     camino de tu mejor tiempo (se guarda al acabar si lo mejoras). Solo se ve, no cambia si el
##     nivel se puede pasar: vale para el reto diario.
## Los giros propios de un genero (las mezclas) los hace el propio juego: Twist.has("cola").
## forced: giros del reto diario (mandan sobre los del juego mientras dura el reto).

const GENERIC: Array[String] = ["oscuridad", "espejo", "contrarreloj", "racha", "fantasma"]
const DAILY_REWARD: int = 50
## Fantasma: una muestra cada GHOST_STEP fotogramas de fisica; como mucho GHOST_MAX muestras (si
## el nivel es mas largo, se queda una de cada dos y el paso se dobla).
const GHOST_STEP: int = 3
const GHOST_MAX: int = 1200

var forced: Array[String] = []
var game: Node = null
var attempt_time: float = 0.0
var streak: int = 0
## Reto del dia: un nivel ya desbloqueado con un giro sorpresa que no cambia si se puede pasar
## (game.json -> "daily_twists", los "seguros" de la fabrica). Premio una vez al dia.
## Si el juego trae niveles nuevos para el reto (game.json -> "daily_levels", validados por los
## bots), el reto es uno de ellos (otro cada dia) en TODOS los generos, en cuanto pasas el nivel 1.
## Racha: superarlo dias seguidos sube el premio (+10 por dia, hasta +60).
var daily_active: bool = false
var daily_level: int = -1
var fake_day: int = -1

var _dark: ColorRect
var _mirror: ColorRect
var _clock: Label
var _layer: CanvasLayer
var ghost_clock: float = 0.0
var _ghost: Node2D
var _ghost_best: PackedVector2Array = PackedVector2Array()
var _ghost_dt: float = 0.0
var _rec: PackedVector2Array = PackedVector2Array()
var _rec_dt: float = 0.05
var _rec_next: float = 0.0


func _ready() -> void:
	QA.logged.connect(_on_logged)


## Giros activos ahora (los del reto diario si hay; si no, los del juego).
func active() -> Array[String]:
	if not forced.is_empty():
		return forced
	var out: Array[String] = []
	for t: Variant in Kit.config.get("twists", []):
		out.append(str(t))
	return out


func has(id: String) -> bool:
	return active().has(id)


func _on_logged(entry: Dictionary) -> void:
	var ev: String = str(entry.get("event", ""))
	Stats.on_event(entry)
	if ev == "level_start":
		if daily_active and Kit.level_index != daily_level:
			daily_active = false
			forced = []
		Expert.prepare(Kit.level_index)
		Marathon.prepare(Kit.level_index)
		_attach(_find_game(get_tree().root))
	elif ev == "death":
		attempt_time = 0.0
		streak = 0
	elif ev == "level_complete":
		_ghost_save()
		_on_complete(entry)
		_daily_complete()


func _find_game(n: Node) -> Node:
	var found: Node = null
	for c: Node in n.get_children():
		if c.has_method("bot_state"):
			found = c
		var deeper: Node = _find_game(c)
		if deeper != null:
			found = deeper
	return found


func _attach(g: Node) -> void:
	_detach()
	game = g
	attempt_time = 0.0
	if g == null or active().is_empty():
		return
	_layer = CanvasLayer.new()
	_layer.name = "TwistLayer"
	_layer.layer = 6
	g.add_child(_layer)
	if has("espejo") and g is Node2D:
		## Lo ya dibujado (el mundo) se copia al reves; la interfaz (capa 20) va despues y no se toca.
		var mirror_layer: CanvasLayer = CanvasLayer.new()
		mirror_layer.name = "TwistMirror"
		mirror_layer.layer = 5
		g.add_child(mirror_layer)
		_mirror = _full_rect(mirror_layer, _shader(
			"shader_type canvas_item;\nuniform sampler2D screen_tex : hint_screen_texture, filter_linear;\n" +
			"void fragment() { COLOR = texture(screen_tex, vec2(1.0 - SCREEN_UV.x, SCREEN_UV.y)); }"))
	if has("oscuridad") and _focus() != Vector2.INF:
		_dark = _full_rect(_layer, _shader(
			"shader_type canvas_item;\nuniform vec2 center = vec2(360.0, 640.0);\nuniform float radius = 220.0;\n" +
			"uniform vec2 screen = vec2(720.0, 1280.0);\n" +
			"void fragment() {\n\tvec2 p = SCREEN_UV * screen;\n\tfloat d = distance(p, center);\n" +
			"\tCOLOR = vec4(0.0, 0.0, 0.03, smoothstep(radius * 0.7, radius, d) * 0.96);\n}"))
	if has("fantasma"):
		_ghost_attach()
	if has("contrarreloj") and _limit() > 0.0:
		_clock = Label.new()
		_clock.name = "TwistClock"
		_clock.theme = UI.theme
		_clock.theme_type_variation = "HeaderLabel"
		_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_clock.set_anchors_preset(Control.PRESET_CENTER_TOP)
		_clock.position = Vector2(-80.0, UI.safe_rect(get_viewport()).position.y + 96.0)
		_clock.size = Vector2(160.0, 60.0)
		_clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var clock_layer: CanvasLayer = CanvasLayer.new()
		clock_layer.layer = 21
		g.add_child(clock_layer)
		clock_layer.add_child(_clock)


func _detach() -> void:
	_dark = null
	_mirror = null
	_clock = null
	_layer = null
	_ghost = null
	ghost_clock = 0.0
	_rec = PackedVector2Array()
	_rec_dt = float(GHOST_STEP) / float(Engine.physics_ticks_per_second)
	_rec_next = 0.0


func _shader(code: String) -> ShaderMaterial:
	var sh: Shader = Shader.new()
	sh.code = code
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = sh
	return m


func _full_rect(parent: Node, mat: ShaderMaterial) -> ColorRect:
	var r: ColorRect = ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.material = mat
	parent.add_child(r)
	return r


## Donde esta el heroe en la pantalla (INF si este genero no tiene un heroe que se mueva).
func _focus() -> Vector2:
	if game == null or not is_instance_valid(game):
		return Vector2.INF
	var node: Node2D = null
	if game.has_method("twist_focus"):
		node = game.call("twist_focus")
	elif game.get("player") is Node2D:
		node = game.get("player")
	else:
		node = game.find_child("Player", true, false) as Node2D
	if node == null or not is_instance_valid(node) or not node.is_inside_tree():
		return Vector2.INF
	return node.get_global_transform_with_canvas().origin


func _limit() -> float:
	return float(Kit.current_level().get("time_limit", 0.0))


func _process(delta: float) -> void:
	if game == null or not is_instance_valid(game):
		return
	if _dark != null:
		var f: Vector2 = _focus()
		if f != Vector2.INF:
			var vp: Vector2 = get_viewport().get_visible_rect().size
			if has("espejo"):
				f.x = vp.x - f.x
			var mat: ShaderMaterial = _dark.material as ShaderMaterial
			mat.set_shader_parameter("center", f)
			mat.set_shader_parameter("screen", vp)
			mat.set_shader_parameter("radius", minf(vp.x, vp.y) * 0.3)
	if _clock != null:
		_tick_clock(delta)


func _tick_clock(delta: float) -> void:
	if bool(game.get("finished")) or bool(game.get("failed")) or get_tree().paused:
		return
	attempt_time += delta
	var left: float = _limit() - attempt_time
	_clock.text = "%d" % ceili(maxf(left, 0.0))
	_clock.add_theme_color_override("font_color", Kit.color("danger", Color("#ff6b5b")) if left < 5.0 else UI.colors["texto"])
	if left <= 0.0 and game.has_method("retry"):
		attempt_time = 0.0
		game.set("deaths", int(game.get("deaths")) + 1)
		QA.log_event("death", {"cause": "twist_time", "deaths": int(game.get("deaths"))})
		Audio.play("hurt")
		toast(Kit.text("twist_time_up", "\u00a1Se acab\u00f3 el tiempo! Otra vez"))
		game.call("retry")


## 5 - Racha: monedas extra al terminar un nivel sin morir (x1.5, x2, x2.5, x3).
func _on_complete(entry: Dictionary) -> void:
	if not has("racha"):
		return
	if int(entry.get("deaths", 0)) > 0:
		streak = 0
		return
	streak += 1
	var mult: float = minf(3.0, 1.0 + 0.5 * float(streak))
	var bonus: int = int(float(10 + mini(int(entry.get("coins", 0)), 40)) * (mult - 1.0))
	if bonus > 0:
		Save.add_wallet(bonus)
		toast(Kit.text("twist_streak", "Racha x{m}: +{n}").replace("{m}", str(mult)).replace("{n}", str(bonus)), UI.colors["acento"])


func toast(text: String, col: Color = Color.WHITE) -> void:
	if game == null or not is_instance_valid(game) or UI.test_mode:
		return
	var size: Vector2 = get_viewport().get_visible_rect().size
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 50
	game.add_child(layer)
	UI.float_text(layer, Vector2(size.x * 0.5, size.y * 0.3), text.left(40), col, 40)


# ------------------------------------------------------------------ fantasma

## El nodo del heroe en el mundo (null si este genero no tiene uno).
func _hero() -> Node2D:
	if game == null or not is_instance_valid(game):
		return null
	var node: Node2D = null
	if game.has_method("twist_focus"):
		node = game.call("twist_focus")
	elif game.get("player") is Node2D:
		node = game.get("player")
	if node == null or not is_instance_valid(node) or not node.is_inside_tree():
		return null
	return node


func _ghost_key() -> String:
	return "fantasma_%d" % Kit.level_index


## Mejor partida guardada: {"t": segundos, "dt": paso, "p": [x0, y0, x1, y1, ...]} o {}.
func ghost_best() -> Dictionary:
	var g: Variant = Save.get_setting(_ghost_key(), {})
	return g if g is Dictionary else {}


func _ghost_attach() -> void:
	var hero: Node2D = _hero()
	if hero == null or hero.get_parent() == null:
		return
	var best: Dictionary = ghost_best()
	_ghost_best = PackedVector2Array()
	var raw: Array = best.get("p", [])
	for k: int in range(0, raw.size() - 1, 2):
		_ghost_best.append(Vector2(float(raw[k]), float(raw[k + 1])))
	_ghost_dt = float(best.get("dt", 0.05))
	if _ghost_best.size() < 2:
		return
	_ghost = Node2D.new()
	_ghost.name = "TwistGhost"
	_ghost.z_index = hero.z_index - 1
	_ghost.modulate = Color(0.55, 0.9, 1.0, 0.4)
	var look: Node = _first_sprite(hero)
	if look != null:
		var copy: Node = look.duplicate()
		_ghost.add_child(copy)
		if copy is Node2D:
			(copy as Node2D).position = (look as Node2D).position
	else:
		var dot: Polygon2D = Polygon2D.new()
		var pts: PackedVector2Array = PackedVector2Array()
		for k: int in 16:
			pts.append(Vector2.from_angle(TAU * float(k) / 16.0) * 28.0)
		dot.polygon = pts
		_ghost.add_child(dot)
	hero.get_parent().add_child(_ghost)
	_ghost.global_position = _ghost_best[0]


func _first_sprite(n: Node) -> Node:
	for c: Node in n.get_children():
		if c is Sprite2D or c is AnimatedSprite2D:
			return c
		var deeper: Node = _first_sprite(c)
		if deeper != null:
			return deeper
	return null


func _physics_process(delta: float) -> void:
	if game == null or not is_instance_valid(game) or not has("fantasma"):
		return
	if bool(game.get("finished")) or bool(game.get("failed")):
		return
	ghost_clock += delta
	var hero: Node2D = _hero()
	if hero != null and ghost_clock >= _rec_next:
		_rec.append(hero.global_position)
		_rec_next += _rec_dt
		if _rec.size() > GHOST_MAX:
			var half: PackedVector2Array = PackedVector2Array()
			for k: int in range(0, _rec.size(), 2):
				half.append(_rec[k])
			_rec = half
			_rec_dt *= 2.0
			_rec_next = _rec_dt * float(_rec.size())
	if _ghost != null and is_instance_valid(_ghost) and _ghost_dt > 0.0:
		var f: float = ghost_clock / _ghost_dt
		var i: int = mini(int(f), _ghost_best.size() - 1)
		var j: int = mini(i + 1, _ghost_best.size() - 1)
		## La ruta se guardo en coordenadas del mundo.
		_ghost.global_position = _ghost_best[i].lerp(_ghost_best[j], clampf(f - float(i), 0.0, 1.0))


## Al acabar: si es el mejor tiempo del nivel, esta partida pasa a ser el fantasma.
func _ghost_save() -> void:
	if not has("fantasma") or _rec.size() < 2:
		return
	var best: Dictionary = ghost_best()
	if not best.is_empty() and float(best.get("t", INF)) <= ghost_clock:
		return
	var flat: Array = []
	for v: Vector2 in _rec:
		flat.append(snappedf(v.x, 0.1))
		flat.append(snappedf(v.y, 0.1))
	Save.set_setting(_ghost_key(), {"t": snappedf(ghost_clock, 0.01), "dt": _rec_dt, "p": flat})
	if not best.is_empty():
		toast(Kit.text("twist_ghost_beaten", "\u00a1Le ganaste a tu fantasma!"), UI.colors["acento"])


# ------------------------------------------------------------------ reto del dia

func _day() -> int:
	return fake_day if fake_day >= 0 else Save.today()


func daily_options() -> Array[String]:
	var out: Array[String] = []
	for t: Variant in Kit.config.get("daily_twists", []):
		out.append(str(t))
	return out


func daily_levels() -> Array:
	var v: Variant = Kit.config.get("daily_levels", [])
	return v if v is Array else []


## El reto de hoy: {"level", "twist"} o, con niveles del reto, {"level", "fresh", "twist": ""}
## ({} si no hay reto).
func daily_today() -> Dictionary:
	var fresh: Array = daily_levels()
	if not fresh.is_empty() and Kit.level_count() > 0 and Save.unlocked_count() >= 2:
		return {"level": Kit.level_count(), "fresh": (_day() * 5 + 1) % fresh.size(), "twist": ""}
	var opts: Array[String] = daily_options()
	if opts.is_empty() or Kit.level_count() == 0:
		return {}
	var d: int = _day()
	var levels: int = clampi(Save.unlocked_count(), 1, Kit.level_count())
	return {"level": (d * 7 + 3) % levels, "twist": opts[(d * 13 + 5) % opts.size()]}


func daily_done() -> bool:
	return int(Save.get_setting("reto_dia", -1)) == _day()


func start_daily() -> bool:
	var r: Dictionary = daily_today()
	if r.is_empty():
		return false
	if r.has("fresh"):
		var lv: Dictionary = (daily_levels()[int(r["fresh"])] as Dictionary).duplicate(true)
		lv["name"] = Kit.text("daily_level_name", "Reto del d\u00eda")
		Kit.extra_level = lv
		Kit.extra_index = int(r["level"])
		forced = []
	else:
		forced = [str(r["twist"])]
	daily_level = int(r["level"])
	daily_active = true
	Kit.level_index = daily_level
	return true


func _daily_complete() -> void:
	if not daily_active:
		return
	daily_active = false
	forced = []
	if daily_done():
		return
	var run: int = daily_streak() + 1 if int(Save.get_setting("reto_dia", -1)) == _day() - 1 else 1
	Save.set_setting("reto_dia", _day())
	Save.set_setting("reto_racha", run)
	var reward: int = daily_reward(run)
	Save.add_wallet(reward)
	var txt: String = Kit.text("daily_challenge_done", "\u00a1Reto del d\u00eda superado! +{n}").replace("{n}", str(reward))
	if run >= 2:
		txt += "  " + Kit.text("daily_streak", "Racha {n}").replace("{n}", str(run))
	toast(txt, UI.colors["acento"])


## Dias seguidos superando el reto (0 si ayer no se hizo ni hoy tampoco).
func daily_streak() -> int:
	var last: int = int(Save.get_setting("reto_dia", -1))
	if last != _day() and last != _day() - 1:
		return 0
	return int(Save.get_setting("reto_racha", 1 if last >= 0 else 0))


static func daily_reward(run: int) -> int:
	return DAILY_REWARD + 10 * clampi(run - 1, 0, 6)
