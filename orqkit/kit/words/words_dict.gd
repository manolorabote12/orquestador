extends RefCounted
## Diccionarios de los juegos de palabras (kit/words/dicts/<idioma>.txt, los hace
## fabrica/textos/diccionarios.py): palabras de 3 a 8 letras en mayusculas y sin tildes (la N con
## virgulilla se queda), de mas a menos usadas; una "*" al final marca las que pueden ser solucion.
## Idiomas: es, en, pt, fr, de, it. Para los demas se usa el ingles.

const LANGS: Array[String] = ["es", "en", "pt", "fr", "de", "it"]
static var _cache: Dictionary = {}


## Idioma con diccionario (el pedido o, si no hay, ingles).
static func pick(lang: String) -> String:
	var l: String = lang.substr(0, 2).to_lower()
	return l if LANGS.has(l) else "en"


## {"valid": {palabra: rango}, "targets": {largo: [palabras]}, "lang"}.
static func load_lang(lang: String) -> Dictionary:
	var l: String = pick(lang)
	if _cache.has(l):
		return _cache[l]
	var valid: Dictionary = {}
	var targets: Dictionary = {}
	var by_len: Dictionary = {}
	var f: FileAccess = FileAccess.open("res://kit/words/dicts/%s.txt" % l, FileAccess.READ)
	var rank: int = 0
	if f != null:
		while not f.eof_reached():
			var line: String = f.get_line().strip_edges()
			if line == "" or line.begins_with("#"):
				continue
			var sol: bool = line.ends_with("*")
			var w: String = line.trim_suffix("*")
			valid[w] = rank
			var n: int = w.length()
			if not by_len.has(n):
				by_len[n] = []
			(by_len[n] as Array).append(w)
			if sol:
				if not targets.has(n):
					targets[n] = []
				(targets[n] as Array).append(w)
			rank += 1
	var d: Dictionary = {"valid": valid, "targets": targets, "by_len": by_len, "lang": l}
	_cache[l] = d
	return d


static func is_word(lang: String, w: String) -> bool:
	return (load_lang(lang)["valid"] as Dictionary).has(w)


## Letras del teclado de un idioma (con la N con virgulilla en espanol).
static func alphabet(lang: String) -> String:
	return "ABCDEFGHIJKLMNOPQRSTUVWXYZ" + ("\u00d1" if pick(lang) == "es" else "")
