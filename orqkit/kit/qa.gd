extends Node
## QA: registro de eventos, fallos y rendimiento para los bots de la fabrica.
## Autoload "QA". Se activa con: godot --headless ... -- --qa
## Los bots leen QA.report() para decidir si una version del juego pasa o vuelve al agente.

signal logged(entry: Dictionary)

var enabled: bool = false
var events: Array[Dictionary] = []
var failures: Array[Dictionary] = []

var _frames: int = 0
var _slow_frames: int = 0
var _worst_ms: float = 0.0
var _last_us: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	enabled = OS.get_cmdline_user_args().has("--qa")
	_last_us = Time.get_ticks_usec()


func log_event(event_name: String, payload: Dictionary = {}) -> void:
	var entry: Dictionary = {"t": Time.get_ticks_msec(), "event": event_name}
	entry.merge(payload)
	events.append(entry)
	## Solo se guardan los ultimos 2000 (una partida larga en el movil no crece sin fin).
	if events.size() > 2000:
		events = events.slice(events.size() - 1500)
	if enabled:
		print("[QA] ", JSON.stringify(entry))
	logged.emit(entry)


## 1 - Un fallo de juego (nivel imposible, jugador fuera del mundo...). Los bots lo cuentan.
func fail(reason: String, payload: Dictionary = {}) -> void:
	var entry: Dictionary = {"t": Time.get_ticks_msec(), "reason": reason}
	entry.merge(payload)
	failures.append(entry)
	push_warning("[QA] fallo: " + JSON.stringify(entry))


func count(event_name: String) -> int:
	var n: int = 0
	for e: Dictionary in events:
		if e.get("event", "") == event_name:
			n += 1
	return n


func clear() -> void:
	events.clear()
	failures.clear()
	_frames = 0
	_slow_frames = 0
	_worst_ms = 0.0


func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	var ms: float = float(now - _last_us) / 1000.0
	_last_us = now
	_frames += 1
	if _frames > 30:
		_worst_ms = maxf(_worst_ms, ms)
		if ms > 33.4:
			_slow_frames += 1


func report() -> Dictionary:
	return {
		"frames": _frames,
		"slow_frames": _slow_frames,
		"worst_frame_ms": snappedf(_worst_ms, 0.1),
		"events": events.size(),
		"failures": failures.duplicate(true),
	}
