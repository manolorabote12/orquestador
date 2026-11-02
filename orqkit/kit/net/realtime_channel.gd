class_name RealtimeChannel
extends Node
## Canal en directo (Supabase Realtime, "broadcast"): mensajes cortos entre los jugadores de una sala.
## 1 - Se conecta por WebSocket a <url>/realtime/v1/websocket con la clave publica (anon) y se une
##     al tema "realtime:<topic>" (protocolo Phoenix: phx_join, heartbeat cada 25 s, broadcast).
## 2 - send(evento, datos) manda a los demas (a uno mismo no); received(evento, datos) al llegar.
## 3 - Modo local (pruebas): varios canales con el mismo tema en el mismo programa se hablan
##     entre ellos sin red, con un retraso opcional para simular la latencia.

signal received(event: String, payload: Dictionary)
signal joined
signal closed

const HEARTBEAT_S: float = 25.0

static var _hub: Dictionary = {}

var topic: String = ""
var local: bool = false
var latency: float = 0.0
var is_joined: bool = false
var sent: int = 0
var _ws: WebSocketPeer = null
var _ref: int = 1
var _beat: float = 0.0
var _key: String = ""
var _queue: Array[Array] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Canal de prueba sin red (mismo tema = misma sala).
func open_local(t: String, delay: float = 0.0) -> void:
	topic = t
	local = true
	latency = delay
	var peers: Array = _hub.get(t, [])
	peers.append(self)
	_hub[t] = peers
	is_joined = true
	joined.emit.call_deferred()


func open(url: String, key: String, t: String) -> bool:
	topic = t
	_key = key
	var ws_url: String = url.trim_suffix("/").replace("https://", "wss://").replace("http://", "ws://") \
		+ "/realtime/v1/websocket?apikey=" + key.uri_encode() + "&vsn=1.0.0"
	_ws = WebSocketPeer.new()
	return _ws.connect_to_url(ws_url) == OK


func send(event: String, payload: Dictionary) -> void:
	sent += 1
	if local:
		for p: Variant in _hub.get(topic, []):
			if p != self and is_instance_valid(p):
				var peer: RealtimeChannel = p
				if latency > 0.0:
					get_tree().create_timer(latency, true, false, true).timeout.connect(peer._deliver.bind(event, payload.duplicate(true)))
				else:
					peer._deliver.call_deferred(event, payload.duplicate(true))
		return
	if not is_joined:
		return
	_raw({"topic": "realtime:" + topic, "event": "broadcast", "join_ref": "1",
		"payload": {"type": "broadcast", "event": event, "payload": payload}})


func _deliver(event: String, payload: Dictionary) -> void:
	if is_inside_tree():
		received.emit(event, payload)


func _raw(msg: Dictionary) -> void:
	_ref += 1
	msg["ref"] = str(_ref)
	if _ws != null and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.send_text(JSON.stringify(msg))


func _process(delta: float) -> void:
	if local or _ws == null:
		return
	_ws.poll()
	var st: int = _ws.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN:
		if not is_joined and _ref == 1:
			_ref = 1
			_ws.send_text(JSON.stringify({"topic": "realtime:" + topic, "event": "phx_join", "ref": "1", "join_ref": "1",
				"payload": {"config": {"broadcast": {"self": false, "ack": false}, "presence": {"key": ""}, "postgres_changes": [], "private": false},
					"access_token": _key}}))
			_ref = 2
		_beat += delta
		if _beat >= HEARTBEAT_S:
			_beat = 0.0
			_raw({"topic": "phoenix", "event": "heartbeat", "payload": {}})
		while _ws.get_available_packet_count() > 0:
			_on_text(_ws.get_packet().get_string_from_utf8())
	elif st == WebSocketPeer.STATE_CLOSED:
		_ws = null
		is_joined = false
		closed.emit()


func _on_text(text: String) -> void:
	var js: JSON = JSON.new()
	if js.parse(text) != OK or not js.data is Dictionary:
		return
	var m: Variant = js.data
	var d: Dictionary = m
	var ev: String = str(d.get("event", ""))
	var pl: Variant = d.get("payload", {})
	if ev == "phx_reply" and str(d.get("ref", "")) == "1":
		if pl is Dictionary and str((pl as Dictionary).get("status", "")) == "ok":
			is_joined = true
			joined.emit()
		return
	if ev == "broadcast" and pl is Dictionary:
		var inner: Variant = (pl as Dictionary).get("payload", {})
		received.emit(str((pl as Dictionary).get("event", "")), inner if inner is Dictionary else {})


func close() -> void:
	if local:
		var peers: Array = _hub.get(topic, [])
		peers.erase(self)
		_hub[topic] = peers
	elif _ws != null:
		_raw({"topic": "realtime:" + topic, "event": "phx_leave", "payload": {}})
		_ws.close()
	is_joined = false


func _exit_tree() -> void:
	close()
