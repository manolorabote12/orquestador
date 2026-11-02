extends Node
## Datos anonimos de partida para que el juego aprenda de la gente que lo juega (autoload "Telemetry").
## 1 - Escucha los eventos de QA y resume cada intento de nivel: gana, muere o sale, en cuantos
##     segundos y con cuantas muertes. Nada mas: ni nombre, ni cuenta, ni ID de publicidad.
## 2 - La sesion es un numero aleatorio nuevo en cada arranque: no se puede seguir a nadie.
## 3 - Se envia por lotes al servidor (game.json -> "telemetry": {url, key, game, version}) y lo
##     que no se pudo enviar se guarda para el siguiente arranque (como mucho 200 intentos).
## 4 - Apagado si el juego no trae "telemetry", en las pruebas, o si el jugador lo quita en Ajustes.

signal sent(count: int)

const MAX_QUEUE: int = 200
const BATCH: int = 20
const FLUSH_SECONDS: float = 45.0
const QUEUE_PATH: String = "user://telemetry_queue.json"

var queue: Array[Dictionary] = []
var session: String = ""
var send_enabled: bool = true
var _open_level: int = -1
var _open_ms: int = 0
var _open_deaths: int = 0
var _timer: float = 0.0
var _sending: bool = false
var _http: HTTPRequest


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	session = "%08x%08x" % [randi(), randi()]
	_load_queue()
	QA.logged.connect(_on_event)
	_http = HTTPRequest.new()
	_http.timeout = 15.0
	add_child(_http)
	_http.request_completed.connect(_on_sent)


func config() -> Dictionary:
	var c: Variant = Kit.config.get("telemetry", {})
	return c if c is Dictionary else {}


func active() -> bool:
	var c: Dictionary = config()
	return not c.is_empty() and str(c.get("url", "")) != "" and bool(Save.get_setting("telemetry", true))


func _on_event(e: Dictionary) -> void:
	if not active():
		return
	var ev: String = str(e.get("event", ""))
	var now: int = Time.get_ticks_msec()
	match ev:
		"level_start":
			var lv: int = int(e.get("level", Kit.level_index))
			if _open_level >= 0:
				_close("reintenta" if lv == _open_level else "sale", {})
			_open_level = lv
			_open_ms = now
			_open_deaths = 0
		"death":
			_open_deaths += 1
		"level_complete":
			if _open_level < 0:
				_open_level = int(e.get("level", Kit.level_index))
				_open_ms = now
			_close("gana", {"e": int(e.get("stars", 0))})


func _close(result: String, extra: Dictionary) -> void:
	var item: Dictionary = {"n": _open_level, "r": result, "s": snappedf(float(Time.get_ticks_msec() - _open_ms) / 1000.0, 0.1),
		"m": _open_deaths}
	item.merge(extra)
	## Prueba A/B: en el nivel que se prueba, que version jugo (para comparar A y B).
	if _open_level == Kit.ab_level() and Kit.ab_group() != "":
		item["g"] = Kit.ab_group()
	queue.append(item)
	while queue.size() > MAX_QUEUE:
		queue.pop_front()
	_open_level = -1
	_open_deaths = 0
	if queue.size() >= BATCH:
		flush()


func _process(delta: float) -> void:
	_timer += delta
	if _timer >= FLUSH_SECONDS:
		_timer = 0.0
		flush()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if _open_level >= 0 and active():
			_close("sale", {})
		_save_queue()
		flush()


## 5 - Envia hasta BATCH intentos. Si falla, se quedan en la cola.
func flush() -> void:
	if _sending or queue.is_empty() or not active() or not send_enabled or UI.test_mode:
		return
	## Los bots de la fabrica juegan sin pantalla: sus partidas nunca cuentan como de jugadores.
	if DisplayServer.get_name() == "headless" and not OS.get_cmdline_user_args().has("--telemetria-prueba"):
		return
	var c: Dictionary = config()
	var batch: Array = queue.slice(0, BATCH)
	var body: String = JSON.stringify({"p_juego": str(c.get("game", "")), "p_version": int(c.get("version", 1)),
		"p_sesion": session, "p_eventos": batch})
	var headers: PackedStringArray = ["Content-Type: application/json", "apikey: " + str(c.get("key", "")),
		"Authorization: Bearer " + str(c.get("key", ""))]
	_sending = true
	var err: int = _http.request(str(c["url"]).trim_suffix("/") + "/rest/v1/rpc/registrar_partida", headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		_sending = false


func _on_sent(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	_sending = false
	if result == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300:
		var n: int = mini(BATCH, queue.size())
		queue = queue.slice(n)
		_save_queue()
		sent.emit(n)


func _load_queue() -> void:
	if not FileAccess.file_exists(QUEUE_PATH):
		return
	var f: FileAccess = FileAccess.open(QUEUE_PATH, FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if data is Array:
		for d: Variant in data:
			if d is Dictionary:
				queue.append(d)


func _save_queue() -> void:
	var f: FileAccess = FileAccess.open(QUEUE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(queue.slice(maxi(0, queue.size() - MAX_QUEUE))))
