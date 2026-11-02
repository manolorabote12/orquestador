extends Node
## Avisos en el movil (notificaciones locales) y buzon "Mientras no estabas". Autoload "Notify".
## 1 - Con el plugin NotificationSchedulerPlugin (Android) se programan, al salir del juego:
##     premio diario de manana, misiones de hoy sin terminar, regalo o final de un evento y un
##     "te echamos de menos" a los 3 dias. Cada vez se borran y se vuelven a poner (nunca se acumulan).
## 2 - El permiso (Android 13+) se pide despues de superar el primer nivel, no al abrir el juego.
##     En Ajustes: "Avisos: Si/No".
## 3 - Buzon: al abrir el titulo, lo que ha pasado desde la ultima vez (te han atacado la aldea,
##     premios del torneo, de la guerra de clanes, del evento, misiones por cobrar). Sin red, solo
##     lo local. En las pruebas, fake = true guarda los avisos en "scheduled" en vez de programarlos.

const PLUGIN: String = "NotificationSchedulerPlugin"
const CHANNEL: String = "orq_avisos"
const IDS: Array[int] = [101, 102, 103, 104, 105]

var fake: bool = false
## Aviso propio del juego (lo pone la escena al salir): tiradas llenas, energia llena, gerentes con la
## caja llena, obra terminada... {"content", "delay"} o {} si no hay.
var game_reminder: Dictionary = {}
var scheduled: Array = []
var _plugin: Object = null
var _asked: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if Engine.has_singleton(PLUGIN):
		_plugin = Engine.get_singleton(PLUGIN)
		_plugin.call("initialize")
		_plugin.call("create_notification_channel", {"channel_id": CHANNEL, "channel_name": str(Kit.config.get("title", "Avisos")),
			"channel_description": Kit.text("notify_channel", "Premios y eventos del juego"), "channel_importance": 3, "badge_enabled": true})
	QA.logged.connect(_on_event)


func enabled() -> bool:
	return bool(Save.get_setting("notifications", true))


func available() -> bool:
	return (fake or _plugin != null) and Kit.feature("avisos") and not Kit.kids()


## Al salir del juego (o pasar a segundo plano) se programan los avisos.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		reschedule()


func _on_event(e: Dictionary) -> void:
	## Pedir permiso tras el primer nivel superado (cuando el jugador ya sabe de que va el juego).
	if str(e.get("event", "")) == "level_complete" and not _asked and _plugin != null and enabled():
		_asked = true
		if not bool(_plugin.call("has_post_notifications_permission")):
			_plugin.call("request_post_notifications_permission")


## Segundos hasta la proxima vez que el reloj del movil marque esa hora (hoy o manana).
static func seconds_until(hour: int, now: Dictionary, tomorrow: bool) -> int:
	var secs_now: int = int(now["hour"]) * 3600 + int(now["minute"]) * 60 + int(now.get("second", 0))
	var target: int = hour * 3600 + (86400 if tomorrow else 0)
	if not tomorrow and target <= secs_now:
		return -1
	return target - secs_now


## Lista de avisos para ahora mismo: [{"id", "title", "content", "delay"}].
func plan(now: Dictionary = {}) -> Array:
	if now.is_empty():
		now = Time.get_datetime_dict_from_system()
	var title: String = str(Kit.config.get("title", ""))
	var out: Array = []
	## Manana a las 18:00: premio diario y, si el juego tiene reto del dia, el reto (y la racha que se pierde).
	var daily_txt: String = Kit.text("notify_daily", "\u00a1Tu premio diario te espera!")
	if not Twist.daily_levels().is_empty() and Save.unlocked_count() >= 2:
		var run: int = Twist.daily_streak()
		daily_txt = Kit.text("notify_streak", "\u00a1Nuevo reto del d\u00eda! No pierdas tu racha de {n} d\u00edas").format({"n": run}) if run >= 2 \
			else Kit.text("notify_challenge", "\u00a1Hay un reto del d\u00eda nuevo esper\u00e1ndote!")
	out.append({"id": IDS[0], "title": title, "content": daily_txt, "delay": seconds_until(18, now, true)})
	var left: int = 0
	for m: Variant in Season.missions(false):
		if int((m as Dictionary)["have"]) < int((m as Dictionary)["goal"]):
			left += 1
	var at7: int = seconds_until(19, now, false)
	if left > 0 and at7 > 0:
		out.append({"id": IDS[1], "title": title, "content": Kit.text("notify_missions", "Te quedan {n} misiones de hoy").format({"n": left}),
			"delay": at7})
	var ev: Dictionary = Online.live_event
	if not ev.is_empty():
		var ev_left: int = int((int(ev.get("hasta_ms", 0)) - Time.get_ticks_msec()) / 1000)
		if str(ev.get("tipo", "")) == "regalo" and not bool(ev.get("cobrado", false)) and ev_left > 7200:
			out.append({"id": IDS[2], "title": str(ev.get("titulo", title)), "content": Kit.text("notify_gift", "Tienes un regalo sin recoger"),
				"delay": 7200})
		elif ev_left > 4 * 3600:
			out.append({"id": IDS[2], "title": str(ev.get("titulo", title)), "content": Kit.text("notify_event_end", "\u00daltimas horas del evento"),
				"delay": ev_left - 3 * 3600})
	out.append({"id": IDS[3], "title": title, "content": Kit.text("notify_miss", "\u00a1Vuelve! Hay niveles esper\u00e1ndote"),
		"delay": 3 * 86400})
	if not game_reminder.is_empty() and int(game_reminder.get("delay", 0)) >= 600:
		out.append({"id": IDS[4], "title": title, "content": str(game_reminder.get("content", "")), "delay": mini(int(game_reminder["delay"]), 2 * 86400)})
	return out


func reschedule(now: Dictionary = {}) -> int:
	if not available():
		return 0
	scheduled.clear()
	for id: int in IDS:
		if _plugin != null:
			_plugin.call("cancel", id)
	if not enabled():
		return 0
	for n: Variant in plan(now):
		var d: Dictionary = n
		scheduled.append(d)
		if _plugin != null:
			_plugin.call("schedule", {"notification_id": int(d["id"]), "channel_id": CHANNEL, "title": str(d["title"]),
				"content": str(d["content"]), "small_icon_name": "ic_default_notification", "delay": int(d["delay"])})
	return scheduled.size()


# ------------------------------------------------------------------ buzon

## Lo que ha pasado mientras no estabas: [{"text", "kind"}]. Guarda cuando lo viste por ultima vez.
func inbox() -> Array:
	var items: Array = []
	var since: int = int(Save.get_setting("inbox_seen", 0))
	var now: int = int(Time.get_unix_time_from_system())
	var pend: int = Season.pending() if Kit.feature("pase") else 0
	if pend > 0:
		items.append({"kind": "season", "text": Kit.text("inbox_season", "Tienes {n} premios de misiones y del pase por cobrar").format({"n": pend})})
	if Online.available():
		var tor: Dictionary = await Online.torneo_info()
		if int(tor.get("premio", 0)) > 0:
			items.append({"kind": "torneo", "text": Kit.text("inbox_torneo", "Quedaste {n}.\u00ba en el torneo: \u00a1recoge {c} monedas!").format(
				{"n": int(tor.get("puesto_pasado", 0)), "c": int(tor.get("premio", 0))})})
		if Genres.current() == "village":
			var defs: Array = await Online.liga_defenses()
			var n: int = 0
			var lost: int = 0
			for d: Variant in defs:
				if d is Dictionary and _unix(str((d as Dictionary).get("fecha", ""))) > since:
					n += 1
					lost += mini(int((d as Dictionary).get("trofeos", 0)), 0)
			if n > 0:
				items.append({"kind": "liga", "text": Kit.text("inbox_attacks", "Te han atacado la aldea {n} veces ({t} trofeos)").format({"n": n, "t": lost})})
			var war: Dictionary = await Online.clan_war()
			if int(war.get("premio", 0)) > 0:
				items.append({"kind": "guerra", "text": Kit.text("inbox_war", "Premio de la guerra de clanes: {c} monedas").format({"c": int(war.get("premio", 0))})})
		var ev: Dictionary = Online.live_event
		if str(ev.get("tipo", "")) == "regalo" and not bool(ev.get("cobrado", false)):
			items.append({"kind": "evento", "text": Kit.text("inbox_gift", "Regalo del evento {name}").format({"name": str(ev.get("titulo", ""))})})
	Save.set_setting("inbox_seen", now)
	return items


static func _unix(iso: String) -> int:
	if iso.length() < 19:
		return 0
	return int(Time.get_unix_time_from_datetime_string(iso.substr(0, 19)))
