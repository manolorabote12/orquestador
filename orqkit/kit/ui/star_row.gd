class_name StarRow
extends HBoxContainer
## Fila de estrellas (1 a 3) para niveles y resultados.

var _stars: Array[UiIcon] = []
var lit: int = 0


static func make(total: int, filled: int, px: float) -> StarRow:
	var row: StarRow = StarRow.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", int(px * 0.15))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i: int in total:
		var icon: UiIcon = UiIcon.make("star", UI.colors["acento"] if i < filled else (UI.colors["borde"] as Color).lightened(0.25), px)
		icon.dim = i >= filled
		row.add_child(icon)
		row._stars.append(icon)
		if i < filled:
			row.lit += 1
	return row


## 1 - Rellena las estrellas una a una, con sonido y rebote (pantalla de resultado).
func animate_fill(count: int, first_delay: float = 0.3) -> void:
	lit = 0
	for i: int in _stars.size():
		_stars[i].color = (UI.colors["borde"] as Color).lightened(0.25)
		_stars[i].dim = true
		_stars[i].queue_redraw()
	for i: int in mini(count, _stars.size()):
		var icon: UiIcon = _stars[i]
		var tw: Tween = icon.create_tween()
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_interval(first_delay + 0.35 * float(i))
		tw.tween_callback(_light.bind(icon, i))
		tw.tween_property(icon, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _light(icon: UiIcon, i: int) -> void:
	icon.color = UI.colors["acento"]
	icon.dim = false
	icon.queue_redraw()
	icon.pivot_offset = icon.size * 0.5
	icon.scale = Vector2(1.6, 1.6)
	lit += 1
	## Cada estrella suena mas aguda (como en los juegos grandes).
	Audio.play("ui_coin", 0.0, -4.0 + float(i), 1.0 + 0.18 * float(i))
	Juice.vibrate(14 + 8 * i)
