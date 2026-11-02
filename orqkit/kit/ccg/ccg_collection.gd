class_name CcgCollection
extends RefCounted
## Coleccion y mazo propio de las cartas coleccionables.
## 1 - Empiezas con las cartas del mazo del nivel 1. Cada nivel superado por primera vez da una
##     carta nueva (en el orden de REWARDS, saltando las que ya tienes al maximo).
## 2 - En la portada, "Mazo" abre el editor: DECK_SIZE cartas de tu coleccion (como mucho
##     MAX_COPIES de cada una y un solo dragon).
## 3 - Tu mazo se usa en la campana si esta completo; si no, el del nivel. Los bots, las pruebas,
##     el reto del dia y las partidas de 2 jugadores usan siempre el del nivel.

const M = preload("res://kit/ccg/ccg_map.gd")
const DECK_SIZE: int = 20
const MAX_COPIES: int = 2
const LEGENDARY: Array[String] = ["dragon"]
const REWARDS: Array[String] = ["bola_fuego", "paladin", "dragon", "tormenta", "muro", "lobo", "jinete", "guardia",
	"estudio", "pocion", "bendicion", "ogro", "chispa", "arquera", "escudero", "recluta"]


static func max_copies(id: String) -> int:
	return 1 if id in LEGENDARY else MAX_COPIES


## Cartas que tienes: id -> copias.
static func owned() -> Dictionary:
	var v: Variant = Save.get_setting("ccg_coll", {})
	if v is Dictionary and not (v as Dictionary).is_empty():
		return v
	var start: Dictionary = {}
	var levels: Array = Kit.config.get("levels", [])
	var first: Array = (levels[0] as Dictionary).get("deck", []) if not levels.is_empty() else []
	for c: Variant in first:
		var id: String = str(c)
		if M.CARDS.has(id):
			start[id] = mini(int(start.get(id, 0)) + 1, max_copies(id))
	return start


static func _save_owned(d: Dictionary) -> void:
	Save.set_setting("ccg_coll", d)


static func total(d: Dictionary) -> int:
	var n: int = 0
	for k: Variant in d:
		n += int(d[k])
	return n


## Premio por superar un nivel por primera vez: la carta ganada ("" si ya lo tienes todo).
static func reward(level_index: int) -> String:
	## Guardado como texto: el JSON del guardado vuelve los numeros decimales.
	var got: Array = Save.get_setting("ccg_rewarded", [])
	if got.has(str(level_index)):
		return ""
	var have: Dictionary = owned()
	for id: String in REWARDS:
		if int(have.get(id, 0)) < max_copies(id):
			have[id] = int(have.get(id, 0)) + 1
			_save_owned(have)
			got.append(str(level_index))
			Save.set_setting("ccg_rewarded", got)
			QA.log_event("ccg_card", {"level": level_index, "card": id})
			return id
	return ""


## Tu mazo guardado (vacio = el del nivel).
static func deck() -> Array:
	var v: Variant = Save.get_setting("ccg_deck", [])
	return (v as Array).duplicate() if v is Array else []


## Un mazo vale si tiene DECK_SIZE cartas y todas son tuyas.
static func valid(d: Array) -> bool:
	if d.size() != DECK_SIZE:
		return false
	var have: Dictionary = owned()
	var count: Dictionary = {}
	for c: Variant in d:
		var id: String = str(c)
		count[id] = int(count.get(id, 0)) + 1
		if not M.CARDS.has(id) or int(count[id]) > mini(int(have.get(id, 0)), max_copies(id)):
			return false
	return true


static func save_deck(d: Array) -> bool:
	if not d.is_empty() and not valid(d):
		return false
	Save.set_setting("ccg_deck", d.duplicate())
	return true


## El mazo que se juega en este nivel.
static func deck_for(level: Dictionary, in_tests: bool = false) -> Array:
	var mine: Array = deck()
	if ((UI.test_mode or QA.enabled) and not in_tests) or Kit.is_extra() or Kit.versus or not valid(mine):
		return level.get("deck", [])
	return mine


static func card_name(id: String) -> String:
	return Kit.text("cc_" + id, id.capitalize())
