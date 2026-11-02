extends Node
## Mods: pequenos scripts que el agente programador anade a un juego (game.json -> "mods").
## Autoload "Mods". Cada mod hereda de res://kit/mod_base.gd y solo recibe eventos de la partida.
## Si un mod no carga o no hereda de la base, se ignora (el juego sigue igual).

const BASE: String = "res://kit/mod_base.gd"
const Rules = preload("res://kit/rules.gd")
## Reglas vivas (capa 2 en los generos que no tienen la partida en un diccionario): la regla recibe
## un estado con lo que pasa (eventos contados) y unos mandos que el juego lee en cada fotograma
## (st["tune"]). Los bots juegan con la regla puesta, asi que el validador vuelve a comprobar el juego.
## LIVE_GENRES leen todos los mandos; el resto de generos sin simulacion propia, solo game_speed
## (la velocidad de toda la partida: camara lenta o rapida). Los generos de SIM_RULES llaman a las
## reglas desde su propia simulacion y aqui no se tocan.
const LIVE_GENRES: Array[String] = ["platformer", "runner", "flyer", "horde", "tower", "race"]
const SIM_RULES: Array[String] = ["falling", "sandbox", "royale", "tycoon", "slots", "realm", "crowd", "mergeboard", "wordle",
	"letters", "powertower", "spotdiff", "jigsaw", "paintnum", "knifehit", "rogue", "arrows", "merge2048", "crazy8", "domino",
	"blockjam", "pipes", "chess", "reversi", "hidden", "slide", "hangman", "battle", "simon", "tactics", "autochess", "gemrpg", "ccg", "crawl", "bomber", "artillery", "chomp", "chain", "fighter", "fruitmerge", "pinball", "metroid", "stealth", "custom"]
## Mandos y sus limites (multiplicadores; 1 = como esta el juego).
const TUNE_LIMITS: Dictionary = {"speed": [0.5, 2.0], "jump": [0.75, 1.5], "gravity": [0.6, 1.5], "enemy_speed": [0.3, 2.5],
	"damage": [0.3, 4.0], "fire_rate": [0.3, 4.0], "game_speed": [0.5, 1.5]}

var mods: Array[Node] = []
var active_game: Node = null
## Estado de las reglas vivas de la partida ({} si el juego no tiene reglas vivas).
var live: Dictionary = {}
var _say_layer: CanvasLayer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	for path_v: Variant in Kit.param("mods", []) as Array:
		add_mod(str(path_v))
	QA.logged.connect(_on_logged)


func add_mod(path: String) -> Node:
	if not path.begins_with("res://mods/") and not path.begins_with("res://qa/"):
		QA.log_event("mod_rejected", {"path": path, "why": "ruta"})
		return null
	var script: GDScript = load(path) as GDScript
	if script == null or not _extends_base(script):
		QA.log_event("mod_rejected", {"path": path, "why": "base"})
		return null
	var m: Node = script.new() as Node
	m.name = path.get_file().get_basename()
	add_child(m)
	mods.append(m)
	return m


func remove_all() -> void:
	for m: Node in mods:
		m.queue_free()
	mods.clear()


func _extends_base(script: Script) -> bool:
	var s: Script = script.get_base_script()
	while s != null:
		if s.resource_path == BASE:
			return true
		s = s.get_base_script()
	return false


func _on_logged(entry: Dictionary) -> void:
	var ev0: String = str(entry.get("event", ""))
	if ev0 == "level_start":
		_start_live()
	if not live.is_empty():
		_live_event(ev0, entry)
	if mods.is_empty():
		return
	var ev: String = str(entry.get("event", ""))
	if ev == "level_start":
		active_game = _find_game(get_tree().root)
		for m: Node in mods:
			m.set("game", active_game)
			m.call("on_level_start")
	for m: Node in mods:
		m.call("on_event", ev, entry)


## La escena de juego cumple el contrato del kit (bot_state), sea del genero que sea.
func _find_game(n: Node) -> Node:
	var found: Node = null
	for c: Node in n.get_children():
		if c.has_method("bot_state"):
			found = c
		var deeper: Node = _find_game(c)
		if deeper != null:
			found = deeper
	return found


## Velocidad de toda la partida (sin pisar un paron de impacto de Juice en marcha).
func _set_speed(v: float) -> void:
	if Juice.get("_hitstop_left") != null and float(Juice.get("_hitstop_left")) > 0.0:
		return
	if not is_equal_approx(Engine.time_scale, v):
		Engine.time_scale = v


## Mando de una regla viva (multiplicador; 1.0 si no hay reglas). Lo leen los juegos cada fotograma.
func tune(key: String) -> float:
	if live.is_empty():
		return 1.0
	return float((live["tune"] as Dictionary).get(key, 1.0))


func _start_live() -> void:
	if not live.is_empty():
		_set_speed(1.0)
	live = {}
	if SIM_RULES.has(str(Kit.config.get("genre", "platformer"))):
		return
	var rules: Array = Rules.load_rules(Kit.current_level())
	if rules.is_empty():
		return
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1000 + Kit.level_index
	var tune0: Dictionary = {}
	for k: String in TUNE_LIMITS:
		tune0[k] = 1.0
	live = {"rules": rules, "rng": rng, "t": 0.0, "level": Kit.level_index, "genre": str(Kit.config.get("genre", "platformer")),
		"stats": {}, "tune": tune0, "data": {}, "say": ""}
	Rules.hook(live, "on_start")
	_after_live()


func _live_event(ev: String, entry: Dictionary) -> void:
	if ev == "level_start" or ev.begins_with("mod_") or ev.begins_with("dialog_"):
		return
	var stats: Dictionary = live["stats"]
	stats[ev] = int(stats.get(ev, 0)) + 1
	Rules.hook(live, "on_event", [ev, entry])
	Rules.hook(live, "on_" + ev, [entry])
	_after_live()
	if ev == "level_complete" or ev == "level_failed":
		live = {}
		_set_speed(1.0)
		return


## Tras cada gancho: mandos dentro de sus limites y, si la regla quiere decir algo, un aviso.
func _after_live() -> void:
	if live.is_empty():
		return
	var t: Dictionary = live["tune"]
	for k: Variant in t.keys():
		if not TUNE_LIMITS.has(str(k)):
			t.erase(k)
			continue
		var lim: Array = TUNE_LIMITS[str(k)]
		t[k] = clampf(float(t[k]), float(lim[0]), float(lim[1]))
	_set_speed(float(t.get("game_speed", 1.0)))
	var say: String = str(live.get("say", ""))
	if say != "":
		live["say"] = ""
		if _say_layer == null or not is_instance_valid(_say_layer):
			_say_layer = CanvasLayer.new()
			_say_layer.layer = 50
			add_child(_say_layer)
		var size: Vector2 = get_viewport().get_visible_rect().size
		UI.float_text(_say_layer, Vector2(size.x * 0.5, size.y * 0.3), say.left(40), Color.WHITE, 40)


func _process(delta: float) -> void:
	if not live.is_empty() and not get_tree().paused:
		live["t"] = float(live["t"]) + delta
		Rules.hook(live, "on_step", [delta])
		_after_live()
	if mods.is_empty() or active_game == null or not is_instance_valid(active_game):
		return
	for m: Node in mods:
		m.call("on_tick", delta)
