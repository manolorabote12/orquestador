class_name CloudPanel
extends UiModal
## Pasar a otro movil (guardado en la nube sin cuentas).
## 1 - "Guardar en la nube": sube la partida y ensena el codigo (8 letras) y el PIN (6 cifras).
## 2 - En el movil nuevo: escribe codigo y PIN y "Recuperar": la partida de este movil se sustituye.
## 3 - Sin internet o con codigo/PIN malos, lo dice y no toca nada.

signal restored

var _status: Label
var _code_edit: LineEdit
var _pin_edit: LineEdit


static func open(host: Node) -> CloudPanel:
	var p: CloudPanel = CloudPanel.new()
	p.name = "CloudPanel"
	p.layer = 70
	host.add_child(p)
	return p


func _ready() -> void:
	build_frame(Kit.text("cloud", "Pasar a otro m\u00f3vil"), 600.0)
	_status = Label.new()
	_status.name = "Status"
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.text = Kit.text("cloud_info", "Guarda tu partida y ap\u00fantate el c\u00f3digo y el PIN para seguir en otro m\u00f3vil.")
	body.add_child(_status)
	var code: String = str(Save.get_setting("cloud_code", ""))
	if code != "":
		_status.text = _code_text(code, str(Save.get_setting("cloud_pin", "")))
	var up: Button = UI.make_button(Kit.text("cloud_save", "Guardar en la nube"), true, "share")
	up.name = "BtnCloudSave"
	up.pressed.connect(func() -> void:
		up.disabled = true
		var r: Dictionary = await Online.cloud_save()
		if not is_inside_tree():
			return
		up.disabled = false
		if r.is_empty():
			_status.text = Kit.text("liga_error", "No se pudo conectar. Int\u00e9ntalo m\u00e1s tarde.")
			return
		_status.text = _code_text(str(r["codigo"]), str(r["pin"]))
		Audio.play("coin"))
	body.add_child(up)
	var sub: Label = Label.new()
	sub.theme_type_variation = "SubtleLabel"
	sub.text = Kit.text("cloud_restore_info", "\u00bfVienes de otro m\u00f3vil? Escribe su c\u00f3digo y PIN:")
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(sub)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	body.add_child(row)
	_code_edit = LineEdit.new()
	_code_edit.name = "CodeEdit"
	_code_edit.max_length = 8
	_code_edit.placeholder_text = Kit.text("arena_code", "C\u00f3digo")
	_code_edit.custom_minimum_size = Vector2(0.0, UI.MIN_TOUCH)
	_code_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_code_edit)
	_pin_edit = LineEdit.new()
	_pin_edit.name = "PinEdit"
	_pin_edit.max_length = 6
	_pin_edit.placeholder_text = "PIN"
	_pin_edit.custom_minimum_size = Vector2(150.0, UI.MIN_TOUCH)
	row.add_child(_pin_edit)
	var down: Button = UI.make_button(Kit.text("cloud_restore", "Recuperar partida"), false, "play")
	down.name = "BtnCloudRestore"
	down.pressed.connect(restore)
	body.add_child(down)
	var close_btn: Button = UI.make_button(Kit.text("close", "Cerrar"), false, "close")
	close_btn.name = "BtnClose"
	close_btn.pressed.connect(close)
	body.add_child(close_btn)


func _code_text(code: String, pin: String) -> String:
	return Kit.text("cloud_code", "C\u00f3digo: {code}   PIN: {pin}").format({"code": code, "pin": pin})


func restore() -> void:
	if _code_edit.text.strip_edges().length() < 8 or _pin_edit.text.strip_edges().length() != 6:
		_status.text = Kit.text("cloud_bad", "C\u00f3digo o PIN incorrectos")
		return
	var ok: bool = await Online.cloud_restore(_code_edit.text, _pin_edit.text)
	if not is_inside_tree():
		return
	if not ok:
		_status.text = Kit.text("cloud_bad", "C\u00f3digo o PIN incorrectos")
		return
	_status.text = Kit.text("cloud_done", "\u00a1Partida recuperada!")
	restored.emit()
	if not UI.test_mode:
		await get_tree().create_timer(0.8).timeout
		UI.goto(UI.SCREEN_TITLE)
