class_name TimeBanner
extends CanvasLayer
## Franja del contrarreloj: reloj del nivel y record (en rojo si ya vas peor que tu record).

var label: Label
var best: float = 0.0


func _ready() -> void:
	layer = 25
	best = TimeAttack.best(Kit.level_index)
	label = Label.new()
	label.name = "Text"
	label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	label.position = Vector2(-220, -46)
	label.size = Vector2(440, 40)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	_update()


func _process(_delta: float) -> void:
	_update()


func _update() -> void:
	var t: float = TimeAttack.game_time(get_parent()) if get_parent() != null else 0.0
	var s: String = Kit.text("ta_short", "Contrarreloj") + "  " + TimeAttack.fmt(maxf(t, 0.01))
	if best > 0.0:
		s += "   " + Kit.text("ta_best", "R\u00e9cord {b}").format({"b": TimeAttack.fmt(best)})
	label.text = s
	label.add_theme_color_override("font_color", Color("#ff6b6b") if best > 0.0 and t > best else Color("#7ee8fa"))
