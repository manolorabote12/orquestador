class_name OutOfMovesPanel
extends UiModal
## Sin movimientos: cuanto falto, reintentar (mismo nivel, tablero nuevo) o volver a niveles.

var missing: int = 0
var ice_left: int = 0


static func open(host: Node, points_missing: int, ice: int) -> OutOfMovesPanel:
	var p: OutOfMovesPanel = OutOfMovesPanel.new()
	p.name = "OutOfMovesPanel"
	p.missing = points_missing
	p.ice_left = ice
	host.add_child(p)
	return p


func _ready() -> void:
	build_frame(Kit.text("out_of_moves", "Sin movimientos"))
	var info: Label = Label.new()
	info.name = "Missing"
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var parts: Array[String] = []
	if missing > 0:
		parts.append(Kit.text("missing_points", "Te faltaron %d puntos") % missing)
	if ice_left > 0:
		parts.append(Kit.text("missing_ice", "Quedan %d de hielo") % ice_left)
	info.text = "\n".join(parts)
	body.add_child(info)
	var retry: Button = UI.make_button(Kit.text("retry", "Repetir"), true, "retry")
	retry.name = "BtnRetry"
	retry.pressed.connect(_retry)
	body.add_child(retry)
	var levels: Button = UI.make_button(Kit.text("levels", "Niveles"), false, "grid")
	levels.name = "BtnLevels"
	levels.pressed.connect(func() -> void:
		get_tree().paused = false
		UI.goto(UI.SCREEN_LEVELS))
	body.add_child(levels)


func _retry() -> void:
	closed.emit()
	queue_free()
