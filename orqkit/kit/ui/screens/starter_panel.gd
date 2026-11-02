class_name StarterPanel
extends UiModal
## Oferta de bienvenida (una vez): el pack de inicio (monedas + sin anuncios) a mejor precio que
## quitar los anuncios solo. Sale en la portada despues de unos niveles si el perfil del juego
## lo recomienda, hay tienda y el jugador no ha quitado ya los anuncios.

const AFTER_LEVELS: int = 3


static func should_offer() -> bool:
	return Store.available() and not Store.no_ads() and not Gift.active() and not Store.owns("pack_inicio") and not UI.test_mode \
		and (Monetize.p("iap") as Array).has("pack_inicio") and Save.unlocked_count() > AFTER_LEVELS \
		and not bool(Save.get_setting("pack_inicio_visto", false))


static func open(host: Node) -> StarterPanel:
	var p: StarterPanel = StarterPanel.new()
	p.name = "StarterPanel"
	p.layer = 62
	host.add_child(p)
	return p


func _ready() -> void:
	Save.set_setting("pack_inicio_visto", true)
	build_frame(Kit.text("starter_title", "\u00a1Oferta de bienvenida!"), 600.0)
	var what: Label = Label.new()
	what.name = "What"
	what.text = Kit.text("starter_what", "{n} monedas + sin anuncios para siempre").format({"n": int(Store.PRODUCTS["pack_inicio"]["coins"])})
	what.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	what.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	what.theme_type_variation = "HeaderLabel"
	body.add_child(what)
	var note: Label = Label.new()
	note.text = Kit.text("starter_note", "Solo una vez y solo ahora")
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_color_override("font_color", UI.colors["acento"])
	body.add_child(note)
	var buy: Button = UI.make_button(Store.price("pack_inicio"), true, "coin")
	buy.name = "BtnStarterBuy"
	buy.pressed.connect(func() -> void:
		Store.buy("pack_inicio")
		close())
	body.add_child(buy)
	var later: Button = UI.make_button(Kit.text("not_now", "Ahora no"), false, "")
	later.name = "BtnStarterLater"
	later.pressed.connect(close)
	body.add_child(later)
	QA.log_event("starter_offer", {})
