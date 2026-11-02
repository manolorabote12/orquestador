extends Node
## Clasificacion online y retos entre amigos (autoload "Online").
## 1 - Usa el mismo servidor que los datos de partida (game.json -> "telemetry": {url, key, game}).
## 2 - No se envia nada hasta que el jugador elige un apodo: es lo unico que ven los demas
##     (nada de nombres reales). Se puede apagar en Ajustes y borrar el apodo cuando quiera.
## 3 - Cada dispositivo guarda su mejor marca por nivel (numero aleatorio, no es un ID de publicidad).
## 4 - Retos: "supera mis N puntos en el nivel X" con un enlace. En la version web el juego lee el
##     reto de la URL (?reto=N&n=X&de=Apodo) y al acabar el nivel dice si lo has superado.

const ALIAS_MIN: int = 3
const ALIAS_MAX: int = 14
## Palabras que no pueden ir en un apodo (el servidor tiene su propia lista).
const BANNED: Array[String] = ["puta", "puto", "mierda", "polla", "co\u00f1o", "cabron", "maricon", "nazi", "hitler",
	"fuck", "shit", "bitch", "nigger", "nigga", "cunt", "admin", "orquestador"]

var challenge: Dictionary = {}
## Para las pruebas: Callable(rpc: String, payload: Dictionary) -> Variant en lugar de la red.
var fake: Callable = Callable()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("web"):
		var q: Variant = JavaScriptBridge.eval("location.search", true)
		if q is String and not parse_challenge(q as String).is_empty():
			## El nivel del reto se abre aunque aun no hayas llegado (si no, no podrias aceptarlo).
			Save.unlock_level(int(challenge["level"]))


func config() -> Dictionary:
	var c: Variant = Kit.config.get("telemetry", {})
	return c if c is Dictionary else {}


## El juego tiene servidor (sin mirar lo que elija el jugador): nube y eventos del autor.
func backend() -> bool:
	var c: Dictionary = config()
	if fake.is_valid():
		return true
	return str(c.get("url", "")) != "" and str(c.get("key", "")) != "" and str(c.get("game", "")) != "" and not UI.test_mode


## Lo online entre jugadores (clasificaciones, liga, clanes, arena, charla...): hay servidor, el
## autor no lo ha apagado (ni es un juego para ninos) y el jugador tampoco.
func available() -> bool:
	return backend() and Kit.feature("online") and not Kit.kids() and bool(Save.get_setting("online", true))


func alias() -> String:
	return str(Save.get_setting("alias", ""))


## Guarda el apodo. Devuelve "" si vale o el motivo si no.
func set_alias(text: String) -> String:
	var clean: String = clean_alias(text)
	if clean == "":
		return Kit.text("alias_bad", "Usa de 3 a 14 letras o numeros, sin palabrotas")
	Save.set_setting("alias", clean)
	return ""


static func clean_alias(text: String) -> String:
	var t: String = " ".join(text.strip_edges().split(" ", false))
	if t.length() < ALIAS_MIN or t.length() > ALIAS_MAX:
		return ""
	for i: int in t.length():
		var ch: String = t[i]
		var code: int = t.unicode_at(i)
		var letter: bool = ch.to_lower() != ch.to_upper() or (code >= 48 and code <= 57)
		if not letter and not ch in [" ", "_", "-", "."]:
			return ""
	var low: String = t.to_lower().replace(" ", "").replace("_", "").replace("-", "").replace(".", "")
	low = low.replace("0", "o").replace("1", "i").replace("3", "e").replace("4", "a").replace("5", "s")
	for w: String in BANNED:
		if low.contains(w):
			return ""
	return t


func device() -> String:
	var d: String = str(Save.get_setting("device", ""))
	if d.length() != 16:
		d = "%08x%08x" % [randi(), randi()]
		Save.set_setting("device", d)
	return d


## Fantasma pendiente de subir: {"level", "points"} (lo deja el juego al acabar el nivel).
var ghost_pending: Dictionary = {}


## 3 - Envia la marca del nivel (solo si hay apodo). Devuelve {"ok", "rank", "best"}.
## Si es tu mejor marca y hay recorrido pendiente de ese nivel, sube tambien tu fantasma.
func submit(level: int, score: int) -> Dictionary:
	if not available() or alias() == "" or score <= 0:
		return {"ok": false}
	var r: Variant = await _rpc("marcador_enviar", {"p_juego": str(config().get("game", "")), "p_nivel": level,
		"p_sesion": device(), "p_alias": alias(), "p_puntos": score})
	if r is Dictionary:
		var d: Dictionary = r
		if int(ghost_pending.get("level", -1)) == level and int(d.get("mejor", -1)) == score:
			await _rpc("fantasma_subir", {"p_juego": str(config().get("game", "")), "p_nivel": level, "p_sesion": device(),
				"p_puntos": score, "p_datos": ghost_pending.get("points", [])})
		ghost_pending = {}
		return {"ok": true, "rank": int(d.get("posicion", 0)), "best": int(d.get("mejor", score))}
	return {"ok": false}


## Amigos: tu codigo para compartir, anadir/quitar con el codigo de otro y la clasificacion entre amigos.
func friend_code() -> String:
	if not available():
		return ""
	var r: Variant = await _rpc("amigo_codigo", {"p_juego": str(config().get("game", "")), "p_sesion": device()})
	return str(r) if r is String else ""


func friend_add(code: String) -> Dictionary:
	if not available():
		return {}
	var r: Variant = await _rpc("amigo_anadir", {"p_juego": str(config().get("game", "")), "p_sesion": device(), "p_codigo": code.strip_edges().to_upper()})
	return r if r is Dictionary else {}


func friends_top(level: int) -> Array:
	if not available():
		return []
	var r: Variant = await _rpc("amigos_top", {"p_juego": str(config().get("game", "")), "p_sesion": device(), "p_nivel": level})
	return r if r is Array else []


## Guardado en la nube: sube toda la partida y devuelve {"codigo", "pin"} (vacio sin red).
## El codigo es fijo para este movil; el PIN cambia cada vez que se sube.
func cloud_save() -> Dictionary:
	if not backend() or not Kit.feature("nube"):
		return {}
	var r: Variant = await _rpc("nube_guardar", {"p_juego": str(config().get("game", "")), "p_sesion": device(),
		"p_datos": Save.data.duplicate(true)})
	if r is Dictionary and (r as Dictionary).has("codigo"):
		Save.set_setting("cloud_code", str((r as Dictionary)["codigo"]), false)
		Save.set_setting("cloud_pin", str((r as Dictionary)["pin"]))
		return r
	return {}


## Recupera la partida de otro movil con su codigo y PIN. Sustituye la de este movil.
func cloud_restore(code: String, pin: String) -> bool:
	if not backend() or not Kit.feature("nube"):
		return false
	var r: Variant = await _rpc("nube_restaurar", {"p_juego": str(config().get("game", "")),
		"p_codigo": code.strip_edges().to_upper(), "p_pin": pin.strip_edges()})
	if not (r is Dictionary) or (r as Dictionary).is_empty():
		return false
	Save.data = Save.defaults()
	Save._merge(Save.data, r as Dictionary)
	Save.data["schema"] = Save.SCHEMA
	Save.save_data()
	QA.log_event("cloud_restore")
	return true


## Evento en directo del juego (lo programa el autor): {"tipo", "titulo", "regalo", "segundos", "cobrado"}.
var live_event: Dictionary = {}


func fetch_event() -> Dictionary:
	if not backend():
		live_event = {}
		return {}
	var r: Variant = await _rpc("evento_actual", {"p_juego": str(config().get("game", "")), "p_sesion": device()})
	live_event = r if r is Dictionary else {}
	if not live_event.is_empty():
		live_event["hasta_ms"] = Time.get_ticks_msec() + int(live_event.get("segundos", 0)) * 1000
	return live_event


## Premio real del autor (ver kit/prize.gd): lo guarda para la proxima vez que se abra el juego.
func fetch_prize() -> void:
	if not backend():
		return
	var r: Variant = await _rpc("premio_actual", {"p_juego": str(config().get("game", "")), "p_sesion": device()})
	## null es "no hay premio"; si falla la red (no contesta) se deja lo que habia.
	if r is Dictionary or _last_ok:
		Prize.store_remote(r)


## Modo clase (kit/classroom.gd): unirse con el codigo del profesor y mandarle el progreso.
func class_join(code: String, student: String) -> Variant:
	if not backend():
		return null
	return await _rpc("clase_unirse", {"p_juego": str(config().get("game", "")), "p_codigo": code, "p_sesion": device(), "p_alias": student})


func class_sync(code: String, levels: int, stars: int, minutes: int, current: int = 0, tries: int = 0) -> void:
	if backend():
		await _rpc("clase_progreso", {"p_juego": str(config().get("game", "")), "p_codigo": code, "p_sesion": device(),
			"p_niveles": levels, "p_estrellas": stars, "p_minutos": minutes, "p_nivel_actual": current, "p_intentos": tries})


## Opinion privada para el autor (ver kit/rate.gd). Sin servidor no se manda a ningun sitio.
func send_opinion(likes: bool, text: String, level: int) -> void:
	if not backend():
		return
	await _rpc("opinion_enviar", {"p_juego": str(config().get("game", "")), "p_sesion": device(), "p_gusta": likes,
		"p_texto": text, "p_nivel": level, "p_version": int(config().get("version", 1))})


## Juego regalo (ver kit/gift.gd): para quien es y el mensaje secreto.
func fetch_gift() -> void:
	if not backend():
		return
	var r: Variant = await _rpc("regalo_juego", {"p_juego": str(config().get("game", ""))})
	if r is Dictionary or _last_ok:
		Gift.store_remote(r)


## Avisa al autor de que ya han leido el mensaje.
func gift_read() -> void:
	if backend():
		await _rpc("regalo_leido", {"p_juego": str(config().get("game", ""))})


## Cobra el premio real al superar el nivel (1, 2...): el codigo personal del jugador.
func claim_prize(level: int) -> Variant:
	if not backend():
		return null
	return await _rpc("premio_ganado", {"p_juego": str(config().get("game", "")), "p_sesion": device(), "p_nivel": level})


## Monedas dobles mientras dura un evento "monedas_x2".
func coin_multiplier() -> int:
	if str(live_event.get("tipo", "")) == "monedas_x2" and Time.get_ticks_msec() < int(live_event.get("hasta_ms", 0)):
		return 2
	return 1


## Recoge el regalo del evento (una vez por jugador); suma las monedas y las devuelve.
func event_gift_claim() -> int:
	if not backend():
		return 0
	var r: Variant = await _rpc("evento_regalo_cobrar", {"p_juego": str(config().get("game", "")), "p_sesion": device()})
	var n: int = int(r) if (r is int or r is float) else 0
	if n > 0:
		Save.add_wallet(n)
	live_event["cobrado"] = true
	return n


## Fantasma del que va justo por delante en este nivel: {"alias", "puntos", "datos"} o {}.
func ghost_download(level: int) -> Dictionary:
	if not available() or not bool(Save.get_setting("ghosts", true)):
		return {}
	var r: Variant = await _rpc("fantasma_bajar", {"p_juego": str(config().get("game", "")), "p_nivel": level, "p_sesion": device()})
	return r if r is Dictionary and (r as Dictionary).has("datos") else {}


## Los mejores del nivel: [{"alias", "puntos", "posicion", "tuyo"}] (vacio si no hay red).
func top(level: int, limit: int = 10) -> Array:
	if not available():
		return []
	var r: Variant = await _rpc("marcador_top", {"p_juego": str(config().get("game", "")), "p_nivel": level,
		"p_sesion": device(), "p_limite": limit})
	return r if r is Array else []


## La ultima llamada llego al servidor (para distinguir "contesto null" de "sin red").
var _last_ok: bool = false


func _rpc(name: String, payload: Dictionary) -> Variant:
	_last_ok = false
	if fake.is_valid():
		_last_ok = true
		return fake.call(name, payload)
	var c: Dictionary = config()
	var http: HTTPRequest = HTTPRequest.new()
	http.timeout = 12.0
	add_child(http)
	var headers: PackedStringArray = ["Content-Type: application/json", "apikey: " + str(c.get("key", "")),
		"Authorization: Bearer " + str(c.get("key", ""))]
	var err: int = http.request(str(c["url"]).trim_suffix("/") + "/rest/v1/rpc/" + name, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		http.queue_free()
		return null
	var res: Array = await http.request_completed
	http.queue_free()
	if int(res[0]) != HTTPRequest.RESULT_SUCCESS or int(res[1]) >= 300:
		return null
	_last_ok = true
	return JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())


# ------------------------------------------------------------------ arena en directo (genero arena)

## Partida en directo que va a empezar: {"sala", "yo", "jugadores", "nivel", "semilla", "start_ms"}.
var arena_match: Dictionary = {}
## Pruebas: canales locales (sin red) con este retraso en segundos (< 0 = red de verdad).
var fake_net_latency: float = -1.0


func arena_find() -> Dictionary:
	if not available() or alias() == "":
		return {}
	var r: Variant = await _rpc("arena_buscar", {"p_juego": str(config().get("game", "")), "p_sesion": device(), "p_alias": alias()})
	return r if r is Dictionary and (r as Dictionary).has("sala") else {}


## Salas privadas: crear (te da el codigo), unirse con el codigo y empezar (solo quien la creo).
## mode: "todos" (todos contra todos) o "coop" (juntos contra oleadas de bots, sin trofeos).
func arena_private_create(mode: String = "todos") -> Dictionary:
	if not available() or alias() == "":
		return {}
	var r: Variant = await _rpc("arena_privada_crear", {"p_juego": str(config().get("game", "")), "p_sesion": device(), "p_alias": alias(),
		"p_modo": "coop" if mode == "coop" else "todos"})
	return r if r is Dictionary and (r as Dictionary).has("sala") else {}


func arena_private_join(code: String) -> Dictionary:
	if not available() or alias() == "":
		return {}
	var r: Variant = await _rpc("arena_privada_unir", {"p_juego": str(config().get("game", "")), "p_sesion": device(), "p_alias": alias(),
		"p_codigo": code.strip_edges().to_upper()})
	return r if r is Dictionary and (r as Dictionary).has("sala") else {}


func arena_start(room: String) -> void:
	if available():
		await _rpc("arena_empezar", {"p_sala": room, "p_sesion": device()})


func arena_state(room: String) -> Dictionary:
	if not available():
		return {}
	var r: Variant = await _rpc("arena_estado", {"p_sala": room, "p_sesion": device()})
	return r if r is Dictionary and (r as Dictionary).has("jugadores") else {}


func arena_result(room: String, place: int) -> Dictionary:
	if not available():
		return {}
	var r: Variant = await _rpc("arena_resultado", {"p_sala": room, "p_sesion": device(), "p_puesto": place})
	return r if r is Dictionary else {}


func arena_top(limit: int = 10) -> Array:
	if not available():
		return []
	var r: Variant = await _rpc("arena_top", {"p_juego": str(config().get("game", "")), "p_sesion": device(), "p_limite": limit})
	return r if r is Array else []


## Canal en directo de la sala (lo anade quien lo pide a su escena).
func arena_channel(room: String) -> RealtimeChannel:
	var ch: RealtimeChannel = RealtimeChannel.new()
	ch.name = "Net"
	if fake_net_latency >= 0.0:
		ch.open_local("arena-" + room, fake_net_latency)
	else:
		var c: Dictionary = config()
		ch.open(str(c.get("url", "")), str(c.get("key", "")), "arena-" + room)
	return ch


# ------------------------------------------------------------------ torneo semanal

## Torneo que se esta jugando: {"semana", "nivel", ...} de torneo_info (vacio si no).
var torneo: Dictionary = {}


func torneo_info() -> Dictionary:
	if not available():
		return {}
	var r: Variant = await _rpc("torneo_info", {"p_juego": str(config().get("game", "")), "p_sesion": device()})
	return r if r is Dictionary and (r as Dictionary).has("nivel") else {}


## Marca del torneo (si el nivel jugado es el de la semana). Devuelve {"mejor", "posicion"} o {}.
func torneo_submit(level: int, score: int) -> Dictionary:
	if torneo.is_empty() or int(torneo.get("nivel", -1)) != level or alias() == "" or score <= 0 or not available():
		return {}
	var r: Variant = await _rpc("torneo_enviar", {"p_juego": str(config().get("game", "")), "p_sesion": device(),
		"p_alias": alias(), "p_puntos": score})
	return r if r is Dictionary else {}


func torneo_top(limit: int = 10) -> Array:
	if not available():
		return []
	var r: Variant = await _rpc("torneo_top", {"p_juego": str(config().get("game", "")), "p_sesion": device(), "p_limite": limit})
	return r if r is Array else []


## Cobra el premio del podio de la semana pasada (monedas para la tienda). Devuelve lo cobrado.
func torneo_claim() -> int:
	if not available():
		return 0
	var r: Variant = await _rpc("torneo_reclamar", {"p_juego": str(config().get("game", "")), "p_sesion": device()})
	var n: int = int(r) if (r is int or r is float) else 0
	if n > 0:
		Save.add_wallet(n)
	return n


# ------------------------------------------------------------------ liga de aldeas (genero aldea)

## Asalto de liga en curso: {"ataque", "alias", "mapa", "ayto", "trofeos"} (vacio si no hay).
var liga_match: Dictionary = {}


func liga_publish(rows: Array, hall: int) -> Dictionary:
	if not available() or alias() == "":
		return {}
	var r: Variant = await _rpc("liga_publicar", {"p_juego": str(config().get("game", "")), "p_sesion": device(),
		"p_alias": alias(), "p_mapa": rows, "p_ayto": hall})
	return r if r is Dictionary else {}


func liga_rival() -> Dictionary:
	if not available():
		return {}
	var r: Variant = await _rpc("liga_rival", {"p_juego": str(config().get("game", "")), "p_sesion": device()})
	return r if r is Dictionary and (r as Dictionary).has("ataque") else {}


func liga_result(attack: int, stars: int, pct: int) -> Dictionary:
	if not available():
		return {}
	var r: Variant = await _rpc("liga_resultado", {"p_juego": str(config().get("game", "")), "p_sesion": device(),
		"p_ataque": attack, "p_estrellas": stars, "p_destruccion": pct})
	return r if r is Dictionary else {}


## Clanes de la liga: crear (nombre), unirse (codigo), salir, tu clan y el ranking de clanes.
func clan_create(clan_name: String) -> Dictionary:
	if not available():
		return {}
	var r: Variant = await _rpc("clan_crear", {"p_juego": str(config().get("game", "")), "p_sesion": device(), "p_nombre": clan_name})
	return r if r is Dictionary else {}


func clan_join(code: String) -> Dictionary:
	if not available():
		return {}
	var r: Variant = await _rpc("clan_unir", {"p_juego": str(config().get("game", "")), "p_sesion": device(), "p_codigo": code.strip_edges().to_upper()})
	return r if r is Dictionary else {}


func clan_leave() -> void:
	if available():
		await _rpc("clan_salir", {"p_juego": str(config().get("game", "")), "p_sesion": device()})


func clan_info() -> Dictionary:
	if not available():
		return {}
	var r: Variant = await _rpc("clan_info", {"p_juego": str(config().get("game", "")), "p_sesion": device()})
	return r if r is Dictionary else {}


func clan_top(limit: int = 10) -> Array:
	if not available():
		return []
	var r: Variant = await _rpc("clan_top", {"p_juego": str(config().get("game", "")), "p_limite": limit})
	return r if r is Array else []


## Guerra de clanes semanal: {"segundos", "top", "clan", "premio", "puesto_pasado"} (vacio sin red).
func clan_war() -> Dictionary:
	if not available():
		return {}
	var r: Variant = await _rpc("clan_guerra", {"p_juego": str(config().get("game", "")), "p_sesion": device()})
	return r if r is Dictionary else {}


## Cobra el premio de la guerra de la semana pasada (una vez); suma las monedas y las devuelve.
func clan_war_claim() -> int:
	if not available():
		return 0
	var r: Variant = await _rpc("clan_guerra_cobrar", {"p_juego": str(config().get("game", "")), "p_sesion": device()})
	var n: int = int(r) if (r is int or r is float) else 0
	if n > 0:
		Save.add_wallet(n)
	return n


## Repeticion que hay que ver (la deja el panel de la liga antes de abrir la aldea).
var liga_replay: Dictionary = {}


func liga_replay_upload(attack: int, data: Dictionary) -> bool:
	if not available():
		return false
	var r: Variant = await _rpc("liga_repeticion_subir", {"p_juego": str(config().get("game", "")), "p_sesion": device(),
		"p_ataque": attack, "p_datos": data})
	return r == true


func liga_replay_get(attack: int) -> Dictionary:
	if not available():
		return {}
	var r: Variant = await _rpc("liga_repeticion", {"p_juego": str(config().get("game", "")), "p_sesion": device(), "p_ataque": attack})
	return r if r is Dictionary and (r as Dictionary).has("eventos") else {}


func liga_top(limit: int = 10) -> Array:
	if not available():
		return []
	var r: Variant = await _rpc("liga_top", {"p_juego": str(config().get("game", "")), "p_sesion": device(), "p_limite": limit})
	return r if r is Array else []


func liga_defenses() -> Array:
	if not available():
		return []
	var r: Variant = await _rpc("liga_defensas", {"p_juego": str(config().get("game", "")), "p_sesion": device()})
	return r if r is Array else []


# ------------------------------------------------------------------ charla con personajes

var _chat_active: int = -1


## El autor ha activado la charla en directo (se pregunta una vez por partida).
func chat_active() -> bool:
	if _chat_active >= 0:
		return _chat_active == 1
	if not available():
		return false
	var r: Variant = await _rpc("charla_activa", {"p_juego": str(config().get("game", ""))})
	_chat_active = 1 if r == true else 0
	return _chat_active == 1


## Manda un mensaje a un personaje ("heroe", "rival" o "jefe"). Devuelve {"texto", "offline"} o {} sin red.
## history: [{"de": "jugador"|"personaje", "texto"}] (los ultimos).
func chat(who: String, message: String, history: Array) -> Dictionary:
	if not available():
		return {}
	var payload: Dictionary = {"juego": str(config().get("game", "")), "sesion": device(), "personaje": who,
		"mensaje": message.strip_edges().left(200), "historial": history.slice(maxi(history.size() - 6, 0))}
	if fake.is_valid():
		var f: Variant = fake.call("charla", payload)
		return f if f is Dictionary else {}
	var c: Dictionary = config()
	var http: HTTPRequest = HTTPRequest.new()
	http.timeout = 20.0
	add_child(http)
	var headers: PackedStringArray = ["Content-Type: application/json", "apikey: " + str(c.get("key", "")),
		"Authorization: Bearer " + str(c.get("key", ""))]
	var err: int = http.request(str(c["url"]).trim_suffix("/") + "/functions/v1/charla", headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		http.queue_free()
		return {}
	var res: Array = await http.request_completed
	http.queue_free()
	if int(res[0]) != HTTPRequest.RESULT_SUCCESS:
		return {}
	var d: Variant = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	return d if d is Dictionary and (d as Dictionary).has("texto") else {}


# ------------------------------------------------------------------ retos

## Lee un reto de la URL: ?reto=3480&n=2&de=Dani (nivel contado desde 1).
func parse_challenge(query: String) -> Dictionary:
	challenge = {}
	var q: String = query.trim_prefix("?")
	var vals: Dictionary = {}
	for part: String in q.split("&", false):
		var kv: PackedStringArray = part.split("=", true, 1)
		if kv.size() == 2:
			vals[kv[0]] = kv[1].uri_decode()
	var score: String = str(vals.get("reto", ""))
	var lv: String = str(vals.get("n", "1"))
	if not score.is_valid_int() or not lv.is_valid_int():
		return challenge
	var who: String = clean_alias(str(vals.get("de", "")))
	var level: int = int(lv) - 1
	if int(score) <= 0 or int(score) > 10000000 or level < 0 or level >= maxi(Kit.level_count(), 1):
		return challenge
	challenge = {"score": int(score), "level": level, "from": who if who != "" else Kit.text("a_friend", "un amigo")}
	return challenge


func challenge_for(level: int) -> Dictionary:
	if not challenge.is_empty() and int(challenge["level"]) == level:
		return challenge
	return {}


## Enlace del reto: en la web, la misma pagina; en el movil, la ficha de la tienda (game.json -> share_url).
func share_url(level: int, score: int) -> String:
	var base: String = str(Kit.config.get("share_url", ""))
	if OS.has_feature("web"):
		var href: Variant = JavaScriptBridge.eval("location.origin + location.pathname + location.search", true)
		if href is String:
			base = _strip_challenge(href as String)
	if base == "":
		return ""
	var who: String = alias() if alias() != "" else ""
	var extra: String = "reto=%d&n=%d" % [score, level + 1] + ("&de=" + who.uri_encode() if who != "" else "")
	return base + ("&" if base.contains("?") else "?") + extra


static func _strip_challenge(url: String) -> String:
	var parts: PackedStringArray = url.split("?", true, 1)
	if parts.size() < 2:
		return url
	var keep: Array[String] = []
	for p: String in parts[1].split("&", false):
		var k: String = p.get_slice("=", 0)
		if not k in ["reto", "n", "de"]:
			keep.append(p)
	return parts[0] + ("?" + "&".join(keep) if not keep.is_empty() else "")


func challenge_text(level: int, score: int) -> String:
	var title: String = str(Kit.config.get("title", ""))
	var t: String = Kit.text("challenge_share", "Supera mis {score} puntos en el nivel {level} de {game}").format(
		{"score": score, "level": level + 1, "game": title})
	var url: String = share_url(level, score)
	return t + (" " + url if url != "" else "")


## Comparte el texto: menu de compartir en la web (o portapapeles); en el movil, portapapeles.
## Devuelve lo que hay que decirle al jugador.
func share(text: String) -> String:
	if OS.has_feature("web"):
		var js: String = "(navigator.share ? navigator.share({text: %s}) : navigator.clipboard.writeText(%s)), 1" % [JSON.stringify(text), JSON.stringify(text)]
		JavaScriptBridge.eval(js, true)
		return Kit.text("shared", "Listo para compartir")
	DisplayServer.clipboard_set(text)
	return Kit.text("copied", "Copiado: pegalo en WhatsApp o donde quieras")
