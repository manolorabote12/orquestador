class_name ShopPanel
extends UiModal
## Tienda: mejoras permanentes (vida extra, en los generos con vidas) y aspectos del heroe.
## Todo se compra con las monedas de la cartera. Cada aspecto se ve sobre el propio heroe.
## Arriba, si el juego tiene tienda de Google Play (Store): monedas, quitar anuncios y el pase.

signal changed

var _wallet: Label
var _list: VBoxContainer


static func open(host: Node) -> ShopPanel:
	var p: ShopPanel = ShopPanel.new()
	p.name = "ShopPanel"
	host.add_child(p)
	return p


func _ready() -> void:
	build_frame(Kit.text("shop", "Tienda"), 600.0)
	var top: HBoxContainer = HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 10)
	body.add_child(top)
	top.add_child(UiIcon.make("coin", Kit.color("coin", UI.colors["acento"]), 40.0))
	_wallet = Label.new()
	_wallet.name = "Wallet"
	top.add_child(_wallet)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0.0, 640.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 12)
	scroll.add_child(_list)
	var close: Button = UI.make_button(Kit.text("close", "Cerrar"), false, "close")
	close.name = "BtnClose"
	close.pressed.connect(func() -> void:
		closed.emit()
		queue_free())
	body.add_child(close)
	Store.purchased.connect(_on_purchased)
	Store.products_ready.connect(_refresh)
	_refresh()


func _on_purchased(_id: String) -> void:
	Audio.play("powerup")
	changed.emit()
	_refresh()


func _refresh() -> void:
	_wallet.text = str(Save.wallet())
	for c: Node in _list.get_children():
		c.queue_free()
	if Store.available():
		if not Store.no_ads() and not Store.owns("pack_inicio") and (Monetize.p("iap") as Array).has("pack_inicio"):
			_offer_row("pack_inicio", Kit.text("starter_short", "Pack de inicio: {n} monedas + sin anuncios").format({"n": 2000}), "star")
		_offer_row("monedas_500", Kit.text("iap_coins", "{n} monedas").format({"n": 500}), "coin")
		_offer_row("monedas_3000", Kit.text("iap_coins", "{n} monedas").format({"n": 3000}), "coin")
		if not Store.no_ads():
			_offer_row("sin_anuncios", Kit.text("iap_no_ads", "Sin anuncios"), "close")
		if not Season.premium() and Kit.feature("pase"):
			_offer_row("pase_temporada", Kit.text("pass_premium", "Pase premium"), "star")
	if ["platformer", "horde"].has(Genres.current()):
		_upgrade_row("heart", Kit.text("upgrade_heart", "Corazon extra"))
	if Genres.current() == "village":
		_upgrade_row("tropas", Kit.text("upgrade_tropas", "Tropas m\u00e1s fuertes"), "trophy")
	if Genres.current() == "brawl":
		_upgrade_row("luchador", Kit.text("upgrade_luchador", "Luchador m\u00e1s fuerte"), "cube")
	if Genres.current() == "climb":
		_upgrade_row("motor", Kit.text("upgrade_motor", "Motor"), "gear")
		_upgrade_row("suspension", Kit.text("upgrade_suspension", "Suspensi\u00f3n"), "gear")
		_upgrade_row("ruedas", Kit.text("upgrade_ruedas", "Ruedas"), "gear")
		_upgrade_row("deposito", Kit.text("upgrade_deposito", "Dep\u00f3sito"), "gear")
	var hero: Dictionary = Kit.sprite_by_role("jugador")
	var equipped: String = str(Save.meta().get("skin", "original"))
	for s: Dictionary in Skins.LIST:
		if int(s["price"]) < 0 and not Save.owns_skin(str(s["id"])):
			continue
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		_list.add_child(row)
		var pic: Control = Control.new()
		pic.custom_minimum_size = Vector2(96.0, 96.0)
		row.add_child(pic)
		if not hero.is_empty():
			var spr: AnimatedSprite2D = SpriteKit.animado(hero, 80.0, "idle", false)
			spr.position = Vector2(48.0, 48.0)
			Skins.apply(spr, s)
			pic.add_child(spr)
		else:
			var dot: Polygon2D = Polygon2D.new()
			dot.color = Skins.recolor(Kit.color("accent", Color.ORANGE), s)
			dot.polygon = LevelBuilder._circle(34.0, 20)
			dot.position = Vector2(48.0, 48.0)
			pic.add_child(dot)
		var name_l: Label = Label.new()
		name_l.text = Skins.display_name(s)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_l)
		var id: String = s["id"]
		var b: Button
		if equipped == id:
			b = UI.make_button(Kit.text("equipped", "Puesto"), false, "")
			b.disabled = true
		elif Save.owns_skin(id):
			b = UI.make_button(Kit.text("equip", "Usar"), false, "")
			b.pressed.connect(func() -> void:
				Save.equip_skin(id)
				changed.emit()
				_refresh())
		else:
			b = UI.make_button("%d" % int(s["price"]), true, "coin")
			b.disabled = Save.wallet() < int(s["price"])
			b.pressed.connect(func() -> void:
				if Save.buy_skin(id, int(s["price"])):
					Audio.play("powerup")
					changed.emit()
				_refresh())
		b.name = "Skin_" + id
		b.custom_minimum_size = Vector2(190.0, 96.0)
		row.add_child(b)


func _upgrade_row(id: String, label: String, icon: String = "heart") -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_list.add_child(row)
	row.add_child(UiIcon.make(icon, UI.colors["peligro"] if icon == "heart" else Kit.color("coin", UI.colors["acento"]), 72.0))
	var lvl: int = Save.upgrade_level(id)
	var max_lvl: int = int(Save.UPGRADES[id]["max"])
	var name_l: Label = Label.new()
	name_l.text = "%s  %d/%d" % [label, lvl, max_lvl]
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_l)
	var price: int = Save.upgrade_price(id)
	var b: Button
	if price < 0:
		b = UI.make_button(Kit.text("maxed", "Al maximo"), false, "")
		b.disabled = true
	else:
		b = UI.make_button("%d" % price, true, "coin")
		b.disabled = Save.wallet() < price
		b.pressed.connect(func() -> void:
			if Save.buy_upgrade(id):
				Audio.play("powerup")
				changed.emit()
			_refresh())
	b.name = "Upgrade_" + id
	b.custom_minimum_size = Vector2(190.0, 96.0)
	row.add_child(b)


func _offer_row(id: String, label: String, icon: String) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_list.add_child(row)
	row.add_child(UiIcon.make(icon, Kit.color("coin", UI.colors["acento"]), 72.0))
	var name_l: Label = Label.new()
	name_l.text = label
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_l)
	var b: Button = UI.make_button(Store.price(id), true, "")
	b.name = "Iap_" + id
	b.custom_minimum_size = Vector2(190.0, 96.0)
	b.pressed.connect(func() -> void: Store.buy(id))
	row.add_child(b)
