class_name RatePrompt
extends RefCounted
## Opinion privada antes que valoracion publica. Tras unos niveles superados (con buenas estrellas)
## el juego pregunta "Te esta gustando?":
##   - Si: gracias y a valorarlo en Google Play (game.json -> share_url es la ficha de la tienda).
##   - No: "Que mejorarias?" y se lo manda al autor (opinion_enviar), no a la tienda.
## Pregunta como mucho 2 veces ("Ahora no" la aplaza 5 niveles). Nunca en juegos para peques,
## juegos regalo, pruebas ni capturas. game.json -> "rate": false la apaga.

const FIRST_AT: int = 5
const LATER: int = 5
const MAX_ASKS: int = 2


static func enabled() -> bool:
	return Kit.config.get("rate", true) != false and not Kit.kids() and Monetize.profile_name() != "infantil" and not Gift.active() and not UI.test_mode


static func should_ask(stars: int) -> bool:
	if not enabled() or Kit.is_extra() or stars < 2:
		return false
	if bool(Save.get_setting("rate_done", false)) or int(Save.get_setting("rate_asks", 0)) >= MAX_ASKS:
		return false
	return Save.unlocked_count() >= int(Save.get_setting("rate_next", FIRST_AT))


static func asked() -> void:
	Save.set_setting("rate_asks", int(Save.get_setting("rate_asks", 0)) + 1)
	Save.set_setting("rate_next", Save.unlocked_count() + LATER)


## La ficha de la tienda: market:// en Android (abre la app de Play), si no la web.
static func store_url() -> String:
	var url: String = str(Kit.config.get("share_url", ""))
	var i: int = url.find("id=")
	if OS.has_feature("android") and i >= 0:
		return "market://details?id=" + url.substr(i + 3).get_slice("&", 0)
	return url


static func answer(likes: bool, text: String = "") -> void:
	Save.set_setting("rate_done", true)
	QA.log_event("rate_answer", {"likes": likes})
	Online.send_opinion(likes, text.strip_edges().left(300), Kit.level_index + 1)
