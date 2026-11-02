class_name DailyPanel
extends UiModal
## Premio diario: 7 casillas (la de hoy resaltada) y boton de recoger. La racha sube si vuelves
## al dia siguiente; si fallas un dia, empieza de nuevo.

var amount: int = 0


static func open(host: Node, reward: int) -> DailyPanel:
	var p: DailyPanel = DailyPanel.new()
	p.name = "DailyPanel"
	p.amount = reward
	host.add_child(p)
	return p


func _ready() -> void:
	build_frame(Kit.text("daily_title", "Premio diario"))
	var day: int = Save.DAILY.find(amount)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(grid)
	for i: int in Save.DAILY.size():
		var cellbox: PanelContainer = PanelContainer.new()
		cellbox.custom_minimum_size = Vector2(104.0, 92.0)
		var today: bool = i == day
		if today:
			var sb: StyleBoxFlat = StyleBoxFlat.new()
			sb.bg_color = UI.colors["acento"]
			sb.set_corner_radius_all(18)
			cellbox.add_theme_stylebox_override("panel", sb)
		elif i < day:
			cellbox.modulate.a = 0.55
		grid.add_child(cellbox)
		var v: VBoxContainer = VBoxContainer.new()
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		cellbox.add_child(v)
		var d: Label = Label.new()
		d.text = Kit.text("day", "Dia") + " %d" % (i + 1)
		d.theme_type_variation = "SubtleLabel"
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if today:
			d.add_theme_color_override("font_color", UI.colors["acento_texto"])
		v.add_child(d)
		var a: Label = Label.new()
		a.text = str(Save.DAILY[i])
		a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if today:
			a.add_theme_color_override("font_color", UI.colors["acento_texto"])
		v.add_child(a)
	var claim: Button = UI.make_button(Kit.text("claim", "Recoger") + " %d" % amount, true, "coin")
	claim.name = "BtnClaim"
	claim.pressed.connect(_claim)
	body.add_child(claim)


func _claim() -> void:
	var got: int = Save.claim_daily(Save.today())
	if got > 0:
		Audio.play("ui_reward", 0.0, -4.0)
		Juice.vibrate(30)
	closed.emit()
	queue_free()
