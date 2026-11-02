class_name Classroom
extends RefCounted
## Modo clase: el alumno escribe el codigo que le dicta el profesor y su nombre de pila o un apodo
## (Ajustes -> Clase). Su progreso (niveles superados, estrellas y minutos) le llega al profesor en
## la app al superar cada nivel. Sin correos ni datos personales. Necesita servidor;
## game.json -> "clase": false lo quita.


static func available() -> bool:
	return Online.backend() and Kit.config.get("clase", true) != false


static func code() -> String:
	return str(Save.get_setting("clase_codigo", ""))


static func class_name_text() -> String:
	return str(Save.get_setting("clase_nombre", ""))


static func student() -> String:
	return str(Save.get_setting("clase_alias", ""))


static func joined() -> bool:
	return code() != ""


static func clean_code(t: String) -> String:
	var out: String = ""
	for c: String in t.to_upper():
		if "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".contains(c):
			out += c
	return out.left(6)


## Se une a la clase. Devuelve "" si ha ido bien o el motivo para ensenarlo.
static func join(raw_code: String, raw_alias: String) -> String:
	var c: String = clean_code(raw_code)
	if c.length() != 6:
		return Kit.text("class_bad_code", "El c\u00f3digo tiene 6 letras o n\u00fameros")
	var a: String = Online.clean_alias(raw_alias)
	if a == "":
		return Kit.text("alias_bad", "Usa de 3 a 14 letras o numeros, sin palabrotas")
	var r: Variant = await Online.class_join(c, a)
	if not (r is Dictionary):
		return Kit.text("class_not_found", "No existe esa clase. Revisa el c\u00f3digo.")
	Save.set_setting("clase_codigo", c)
	Save.set_setting("clase_alias", a)
	Save.set_setting("clase_nombre", str((r as Dictionary).get("nombre", "")))
	sync()
	return ""


static func leave() -> void:
	Save.set_setting("clase_codigo", "")
	Save.set_setting("clase_nombre", "")


## Manda el progreso al profesor (al superar un nivel, al perder y al unirse).
static func sync() -> void:
	if not joined() or not available():
		return
	var beaten: int = clampi(Save.unlocked_count() - 1, 0, Kit.level_count())
	## El nivel en el que esta (1, 2...) y cuantas veces ha perdido en el: asi el profe ve quien se atasca.
	var current: int = clampi(Save.unlocked_count(), 1, maxi(Kit.level_count(), 1))
	Online.class_sync(code(), beaten, Stats.stars(), Stats.n("secs") / 60, current, Stats.deaths_at(current - 1))
