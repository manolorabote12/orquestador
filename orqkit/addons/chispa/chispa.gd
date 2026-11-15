@tool
extends EditorPlugin
## Chispa en el editor de Godot (modo experto de Orquestador).
## 1 - Codigo de enlace: se crea en la app (Mis juegos > tu juego > Modo experto) y se pega aqui una vez.
## 2 - Preguntar: Chispa contesta sabiendo como es el proyecto (y el script que tengas abierto).
## 3 - Subir a la fabrica: empaqueta lo que se puede cambiar (scenes, mods, assets, kit y game.json),
##     lo sube y encarga la version nueva: bots, APK y version (se puede volver atras en la app).
## Habla con la funcion «experto» de Orquestador; la direccion sale de fabrica/telemetria.json.

const CARPETAS: Array[String] = ["scenes", "mods", "assets", "kit"]
const SUELTOS: Array[String] = ["game.json", "project.godot"]

var _dock: VBoxContainer
var _code: LineEdit
var _ask: TextEdit
var _answer: RichTextLabel
var _state: Label
var _btn_ask: Button
var _btn_up: Button
var _url: String = ""
var _key: String = ""


func _enter_tree() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_leer_servidor()
	_dock = VBoxContainer.new()
	_dock.name = "Chispa"
	_dock.add_theme_constant_override("separation", 8)
	var head: Label = Label.new()
	head.text = "Chispa · modo experto"
	head.add_theme_font_size_override("font_size", 18)
	_dock.add_child(head)
	var help: Label = Label.new()
	help.text = "Pega el código de enlace de la app (Mis juegos > tu juego > Modo experto)."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dock.add_child(help)
	_code = LineEdit.new()
	_code.placeholder_text = "Código de enlace"
	_code.secret = true
	_code.text = str(EditorInterface.get_editor_settings().get_project_metadata("chispa", "codigo", ""))
	_code.text_changed.connect(func(t: String) -> void:
		EditorInterface.get_editor_settings().set_project_metadata("chispa", "codigo", t.strip_edges()))
	_dock.add_child(_code)
	_ask = TextEdit.new()
	_ask.placeholder_text = "Pregúntale a Chispa: «¿cómo hago que el jefe dispare el doble?»"
	_ask.custom_minimum_size = Vector2(0, 90)
	_ask.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_dock.add_child(_ask)
	_btn_ask = Button.new()
	_btn_ask.text = "Preguntar (con el script abierto)"
	_btn_ask.pressed.connect(_preguntar)
	_dock.add_child(_btn_ask)
	_answer = RichTextLabel.new()
	_answer.fit_content = false
	_answer.selection_enabled = true
	_answer.custom_minimum_size = Vector2(0, 220)
	_answer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dock.add_child(_answer)
	_btn_up = Button.new()
	_btn_up.text = "Subir a la fábrica (bots, APK y versión nueva)"
	_btn_up.pressed.connect(_subir)
	_dock.add_child(_btn_up)
	_state = Label.new()
	_state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dock.add_child(_state)
	if _url == "":
		_state.text = "No encuentro fabrica/telemetria.json: baja otra vez el proyecto desde la app."
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)


func _exit_tree() -> void:
	if _dock != null:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null


func _leer_servidor() -> void:
	var f: FileAccess = FileAccess.open("res://fabrica/telemetria.json", FileAccess.READ)
	if f == null:
		return
	var d: Variant = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		_url = str(d.get("url", "")).trim_suffix("/")
		_key = str(d.get("key", ""))


## Una llamada a la funcion «experto». Devuelve el JSON de respuesta o {"error": texto}.
func _llamar(body: Dictionary) -> Dictionary:
	var http: HTTPRequest = HTTPRequest.new()
	http.timeout = 90.0
	add_child(http)
	var headers: PackedStringArray = ["Content-Type: application/json", "apikey: " + _key, "Authorization: Bearer " + _key]
	body["codigo"] = _code.text.strip_edges()
	var err: int = http.request(_url + "/functions/v1/experto", headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		http.queue_free()
		return {"error": "No se pudo conectar (%d)" % err}
	var r: Array = await http.request_completed
	http.queue_free()
	var txt: String = (r[3] as PackedByteArray).get_string_from_utf8()
	var d: Variant = JSON.parse_string(txt)
	if not d is Dictionary:
		return {"error": "Respuesta rara del servidor (%d)" % int(r[1])}
	if int(r[1]) >= 400:
		return {"error": str((d as Dictionary).get("message", (d as Dictionary).get("error", "Error %d" % int(r[1]))))}
	return d


func _listo() -> bool:
	if _url == "":
		_state.text = "Falta fabrica/telemetria.json: baja otra vez el proyecto desde la app."
		return false
	if _code.text.strip_edges().length() < 8:
		_state.text = "Pega primero el código de enlace de la app."
		return false
	return true


func _preguntar() -> void:
	if not _listo() or _ask.text.strip_edges().length() < 3:
		return
	_btn_ask.disabled = true
	_state.text = "Chispa está pensando..."
	var body: Dictionary = {"accion": "preguntar", "pregunta": _ask.text.strip_edges()}
	var ed: ScriptEditor = EditorInterface.get_script_editor()
	var sc: Script = ed.get_current_script() if ed != null else null
	if sc != null:
		body["archivo"] = sc.resource_path
		body["texto"] = sc.source_code.substr(0, 12000)
	var d: Dictionary = await _llamar(body)
	_btn_ask.disabled = false
	if d.has("error"):
		_state.text = str(d["error"])
		return
	_state.text = ""
	_answer.text = str(d.get("texto", ""))


## Zip con lo que la fabrica acepta (lo demas lo ignora igualmente).
func _empaquetar(destino: String) -> int:
	var zp: ZIPPacker = ZIPPacker.new()
	if zp.open(destino) != OK:
		return -1
	var n: int = 0
	for s: String in SUELTOS:
		if FileAccess.file_exists("res://" + s):
			n += _meter(zp, s)
	for c: String in CARPETAS:
		n += _meter_carpeta(zp, c)
	zp.close()
	return n


func _meter_carpeta(zp: ZIPPacker, rel: String) -> int:
	var d: DirAccess = DirAccess.open("res://" + rel)
	if d == null:
		return 0
	var n: int = 0
	d.include_hidden = false
	for f: String in d.get_files():
		if f.ends_with(".import"):
			continue
		n += _meter(zp, rel + "/" + f)
	for s: String in d.get_directories():
		n += _meter_carpeta(zp, rel + "/" + s)
	return n


func _meter(zp: ZIPPacker, rel: String) -> int:
	var datos: PackedByteArray = FileAccess.get_file_as_bytes("res://" + rel)
	zp.start_file("juego/" + rel)
	zp.write_file(datos)
	zp.close_file()
	return 1


func _subir() -> void:
	if not _listo():
		return
	_btn_up.disabled = true
	EditorInterface.save_all_scenes()
	_state.text = "Empaquetando tu juego..."
	var zip_path: String = OS.get_user_data_dir().path_join("chispa_subida.zip")
	var n: int = _empaquetar(zip_path)
	if n <= 0:
		_state.text = "No se pudo empaquetar el proyecto."
		_btn_up.disabled = false
		return
	var u: Dictionary = await _llamar({"accion": "subir_url"})
	if u.has("error"):
		_state.text = str(u["error"])
		_btn_up.disabled = false
		return
	_state.text = "Subiendo %d archivos..." % n
	var http: HTTPRequest = HTTPRequest.new()
	http.timeout = 600.0
	add_child(http)
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(zip_path)
	var err: int = http.request_raw(str(u["url"]), ["Content-Type: application/zip", "x-upsert: true"], HTTPClient.METHOD_PUT, bytes)
	if err != OK:
		http.queue_free()
		_state.text = "No se pudo subir (%d)." % err
		_btn_up.disabled = false
		return
	var r: Array = await http.request_completed
	http.queue_free()
	if int(r[1]) >= 300:
		_state.text = "La subida ha fallado (%d)." % int(r[1])
		_btn_up.disabled = false
		return
	var q: Dictionary = await _llamar({"accion": "subir", "ruta": str(u["ruta"])})
	_btn_up.disabled = false
	if q.has("error"):
		_state.text = str(q["error"])
		return
	_state.text = "¡Subido! La fábrica lo está probando (%d tuercas). Mira el progreso en la app: si los bots lo superan, tendrás la versión nueva con su APK." % int(q.get("cost", 0))
