class_name StatsPanel
extends UiModal
## Estadisticas del jugador (kit/stats.gd), en filas nombre - valor.


static func open(host: Node) -> StatsPanel:
	var p: StatsPanel = StatsPanel.new()
	p.name = "StatsPanel"
	p.layer = 64
	host.add_child(p)
	return p


func _ready() -> void:
	build_frame(Kit.text("stat_title", "Estad\u00edsticas"), 600.0)
	var grid: GridContainer = GridContainer.new()
	grid.name = "Rows"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 12)
	body.add_child(grid)
	for r: Variant in Stats.rows():
		var row: Array = r
		var k: Label = Label.new()
		k.text = str(row[0])
		k.add_theme_color_override("font_color", UI.colors["texto_suave"])
		grid.add_child(k)
		var v: Label = Label.new()
		v.text = str(row[1])
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_color_override("font_color", UI.colors["acento"])
		grid.add_child(v)
	var ok: Button = UI.make_button(Kit.text("close", "Cerrar"), true, "close")
	ok.name = "BtnStatsClose"
	ok.pressed.connect(close)
	body.add_child(ok)
