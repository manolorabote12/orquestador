class_name TavernPanel
extends UiModal
## Seccion de "lo demas" de la casa propia (game_hub.gd): misiones, reto del dia, tienda, trofeos,
## album y ajustes, con el nombre que le de el juego («Taberna», «Puerto», «Refugio»...). Cada boton
## abre el sistema del kit de siempre.


static func open(host: Node, d: Dictionary) -> TavernPanel:
	var p: TavernPanel = TavernPanel.new()
	p.name = "TavernPanel"
	p.set_meta("cfg", d)
	host.add_child(p)
	return p


func _ready() -> void:
	var d: Dictionary = get_meta("cfg", {})
	build_frame(str(d.get("name", Kit.text("more", "Más"))), 640.0)
	var grid: GridContainer = GridContainer.new()
	grid.name = "Items"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	body.add_child(grid)
	var host: Node = get_parent()
	if Kit.feature("pase"):
		grid.add_child(_item("BtnSeason", Kit.text("missions", "Misiones"), "star", func() -> void: SeasonPanel.open(host)))
	if not Twist.daily_today().is_empty():
		grid.add_child(_item("BtnDaily", Kit.text("daily_challenge", "Reto"), "trophy", func() -> void:
			if Twist.start_daily():
				UI.goto(UI.game_scene())))
	grid.add_child(_item("BtnShop", Kit.text("shop", "Tienda"), "coin", func() -> void: ShopPanel.open(host)))
	grid.add_child(_item("BtnRoad", Kit.text("trophies", "Trofeos"), "trophy", func() -> void: TrophyRoad.open(host)))
	if Album.available():
		grid.add_child(_item("BtnAlbum", Kit.text("album", "Álbum"), "grid", func() -> void: AlbumPanel.open(host)))
	if not CrossPanel.games().is_empty():
		grid.add_child(_item("BtnCross", Kit.text("cross_short", "Más juegos"), "play", func() -> void: CrossPanel.open(host)))
	grid.add_child(_item("BtnSettings", Kit.text("settings", "Ajustes"), "gear", func() -> void: SettingsPanel.open(host)))
	var close_b: Button = UI.make_button(Kit.text("close", "Cerrar"), false, "close")
	close_b.name = "BtnClose"
	close_b.pressed.connect(func() -> void: close())
	body.add_child(close_b)


func _item(node_name: String, label: String, icon: String, action: Callable) -> Button:
	var b: Button = UI.make_button(label, false, icon)
	b.name = node_name
	b.custom_minimum_size = Vector2(290, 110)
	b.pressed.connect(func() -> void:
		Audio.play("click")
		close()
		action.call())
	return b
