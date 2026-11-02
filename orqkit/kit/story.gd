extends Node
## Historia del juego (autoload "Story"): dialogos cortos entre niveles que escribe la directora
## con la personalidad de cada personaje (game.json -> "story").
## 1 - Al empezar un nivel por primera vez sale su "intro" (el juego espera en pausa).
## 2 - Al superarlo, su "outro" sale encima del resultado.
## 3 - Funciona con todos los generos: escucha los eventos level_start / level_complete de QA.
## 4 - Nunca en los bots ni en las capturas; el jugador puede quitarla en Ajustes.
##
## game.json -> "story": {"cast": {"heroe": {"name", "sprite"}, "rival": {...}, "jefe": {...},
##   "narrador": {"name": ""}}, "levels": [{"intro": [{"who", "text", "voice"}], "outro": [...]}]}
## "sprite" es el id del manifest; si no esta, el retrato se busca por rol (jugador / enemigo).

signal dialog_finished(kind: String)

## Para las pruebas: con force la historia sale aunque no haya pantalla.
var force: bool = false
var current: DialogPanel = null
var _paused_by_us: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	QA.logged.connect(_on_event)


func config() -> Dictionary:
	var s: Variant = Kit.config.get("story", {})
	return s if s is Dictionary else {}


func enabled() -> bool:
	if config().is_empty() or not bool(Save.get_setting("story", true)):
		return false
	## En una partida de muestra ("Probar" en la app) se juega directamente, sin historia.
	if Kit.config.has("muestra") and not force:
		return false
	if force:
		return true
	return not UI.test_mode and DisplayServer.get_name() != "headless"


func lines_for(level: int, kind: String) -> Array:
	var levels: Variant = config().get("levels", [])
	## En otro idioma: las frases traducidas (sin voz, que esta grabada en el idioma del juego).
	if Kit.lang() != Kit.base_lang():
		var i18n: Variant = Kit.config.get("i18n", {})
		var tr: Variant = (i18n as Dictionary).get(Kit.lang(), {}).get("_story", []) if i18n is Dictionary else []
		if tr is Array and level < (tr as Array).size() and (tr as Array)[level] is Dictionary:
			var out: Array = []
			for l: Variant in ((tr as Array)[level] as Dictionary).get(kind, []):
				if l is Dictionary:
					var c: Dictionary = (l as Dictionary).duplicate()
					c.erase("voice")
					out.append(c)
			if not out.is_empty():
				return out
	if not levels is Array or level < 0 or level >= (levels as Array).size():
		return []
	var lv: Variant = (levels as Array)[level]
	if not lv is Dictionary:
		return []
	var out: Variant = (lv as Dictionary).get(kind, [])
	return out if out is Array else []


## Reparto con su retrato resuelto (entrada del manifest).
func cast() -> Dictionary:
	var c: Dictionary = {}
	var raw: Variant = config().get("cast", {})
	if not raw is Dictionary:
		return c
	for who: String in (raw as Dictionary).keys():
		var p: Dictionary = (raw as Dictionary)[who] if (raw as Dictionary)[who] is Dictionary else {}
		var entry: Dictionary = Kit.sprite_entry(str(p.get("sprite", "")))
		if entry.is_empty():
			entry = Kit.sprite_by_role({"heroe": "jugador", "rival": "enemigo", "jefe": "jefe"}.get(who, "-"))
		c[who] = {"name": str(p.get("name", "")), "sprite": entry}
	return c


func seen(level: int, kind: String) -> bool:
	var s: Dictionary = Save.get_setting("story_seen", {})
	return bool(s.get("%d_%s" % [level, kind], false))


func _mark(level: int, kind: String) -> void:
	var s: Dictionary = Save.get_setting("story_seen", {})
	s["%d_%s" % [level, kind]] = true
	Save.set_setting("story_seen", s)


func _on_event(e: Dictionary) -> void:
	var ev: String = str(e.get("event", ""))
	if ev != "level_start" and ev != "level_complete":
		return
	if not enabled() or current != null:
		return
	var level: int = int(e.get("level", Kit.level_index))
	var kind: String = "intro" if ev == "level_start" else "outro"
	if seen(level, kind):
		return
	var lines: Array = lines_for(level, kind)
	if lines.is_empty():
		return
	_show.call_deferred(level, kind, lines)


func _show(level: int, kind: String, lines: Array) -> void:
	if current != null:
		return
	var host: Node = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	_mark(level, kind)
	## La intro congela el nivel hasta acabar de leer; el final ya esta parado en el resultado.
	if kind == "intro" and not get_tree().paused:
		get_tree().paused = true
		_paused_by_us = true
	current = DialogPanel.open(host, lines, cast())
	current.finished.connect(_on_finished.bind(kind))
	QA.log_event("dialog_open", {"level": level, "kind": kind, "lines": lines.size()})


func _on_finished(kind: String) -> void:
	current = null
	if _paused_by_us:
		get_tree().paused = false
		_paused_by_us = false
	dialog_finished.emit(kind)


## Para volver a ver la historia (boton en Ajustes).
func reset_seen() -> void:
	Save.set_setting("story_seen", {})
