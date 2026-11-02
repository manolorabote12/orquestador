class_name Gift
extends RefCounted
## Juego regalo: un juego hecho para una persona ("Para Lucia, de Dani") con un mensaje secreto.
## 1 - Con servidor: la portada pide el regalo (regalo_juego) y lo guarda en "regalo_info". Sin el:
##     game.json -> "regalo": {"para", "de", "mensaje", "tras_nivel"} (0 = al acabar el ultimo nivel).
## 2 - La primera vez, la portada lo presenta: para quien es, de quien, y que hay un mensaje dentro.
## 3 - Al superar el nivel elegido se abre el mensaje (y el servidor avisa al autor de que lo ha leido).
## 4 - Despues, el boton "Mensaje" de la portada lo vuelve a ensenar.


static func _clean(d: Variant) -> Dictionary:
	if not (d is Dictionary):
		return {}
	var src: Dictionary = d
	var para: String = str(src.get("para", "")).strip_edges().left(20)
	var msg: String = str(src.get("mensaje", "")).strip_edges().left(400)
	if para == "" or msg == "":
		return {}
	return {"para": para, "de": str(src.get("de", "")).strip_edges().left(20), "mensaje": msg,
		"tras_nivel": clampi(int(src.get("tras_nivel", 0)), 0, 50)}


static func info() -> Dictionary:
	if Online.backend():
		var cached: Dictionary = _clean(Save.get_setting("regalo_info", {}))
		if not cached.is_empty():
			return cached
	return _clean(Kit.config.get("regalo", {}))


static func store_remote(r: Variant) -> void:
	Save.set_setting("regalo_info", _clean(r))


static func active() -> bool:
	return not info().is_empty()


## Nivel (1, 2...) que hay que superar para ver el mensaje: el elegido o el ultimo.
static func goal_level() -> int:
	var n: int = int(info().get("tras_nivel", 0))
	var last: int = maxi(Kit.level_count(), 1)
	return last if n <= 0 else mini(n, last)


static func revealed() -> bool:
	return bool(Save.get_setting("regalo_leido", false))


static func reveal_now(level_index: int) -> bool:
	return active() and not revealed() and not Kit.is_extra() and level_index + 1 >= goal_level()


static func mark_revealed() -> void:
	if revealed():
		return
	Save.set_setting("regalo_leido", true)
	QA.log_event("gift_read", {})
	if Online.backend():
		Online.gift_read()


static func should_intro() -> bool:
	return active() and not bool(Save.get_setting("regalo_intro", false))


static func headline() -> String:
	var d: Dictionary = info()
	var s: String = Kit.text("gift_for", "Para {p}").format({"p": str(d.get("para", ""))})
	if str(d.get("de", "")) != "":
		s += "\n" + Kit.text("gift_from", "de {d}").format({"d": str(d["de"])})
	return s
