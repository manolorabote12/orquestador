extends Control
## Pantalla principal con aspecto de juego grande (estilo "lobby"): tu nivel y tus monedas arriba,
## el heroe en un pedestal con luces en el centro (se toca y reacciona), botones redondos con aviso
## a los lados y un JUGAR enorme que late y brilla. Se monta con las piezas del propio juego: su
## heroe, su paleta, su nombre y su fondo. Asi nunca parece de otro juego.

var _title: Control
var _hero: AnimatedSprite2D
var _hero_root: Node2D
var _pedestal: Node2D
var _coin: AnimatedSprite2D
var _rays: Control
var _wallet: Label
var _level_chip: Control
var _play: Button
var _side: Array[Control] = []
var _left: VBoxContainer
var _right: VBoxContainer
var _shine: float = -1.0
var _t: float = 0.0
var _hero_busy: bool = false
var _chest_row: HBoxContainer
var _chest_tick: float = 0.0

static var _inbox_shown: bool = false
## Una partida de muestra empieza a jugar sola (una vez: al volver al menu se queda en el titulo).
static var _sample_started: bool = false


func _ready() -> void:
	Versus.stop()
	Marathon.stop()
	TimeAttack.stop()
	Expert.stop()
	## Oferta de bienvenida (una vez, tras unos niveles, si el perfil la recomienda).
	if Gift.should_intro() and not UI.test_mode:
		(func() -> void: GiftPanel.open(self, "intro")).call_deferred()
	elif StarterPanel.should_offer():
		(func() -> void: StarterPanel.open(self)).call_deferred()
	theme = UI.theme
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg: ColorRect = ColorRect.new()
	bg.color = UI.colors["fondo"]
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_build_backdrop()
	## 1 - Rayos de luz que giran despacio detras del heroe.
	_rays = Control.new()
	_rays.name = "Rays"
	_rays.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rays.draw.connect(_draw_rays)
	add_child(_rays)
	_build_scene_art()

	var root: MarginContainer = UI.safe_root(self, 22.0)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	root.add_child(col)
	## 2 - Barra de arriba: tu nivel (con su barra) a la izquierda, monedas a la derecha.
	var top: HBoxContainer = HBoxContainer.new()
	top.name = "TopBar"
	top.add_theme_constant_override("separation", 12)
	col.add_child(top)
	_level_chip = Control.new()
	_level_chip.name = "LevelChip"
	_level_chip.custom_minimum_size = Vector2(230, 92)
	_level_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_level_chip.draw.connect(_draw_level_chip)
	top.add_child(_level_chip)
	var gap: Control = Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(gap)
	var pill: Button = UI.make_button("", false, "")
	pill.name = "BtnWallet"
	pill.custom_minimum_size = Vector2(230, 92)
	pill.pressed.connect(_open_shop)
	top.add_child(pill)
	var pill_row: HBoxContainer = HBoxContainer.new()
	pill_row.set_anchors_preset(Control.PRESET_FULL_RECT)
	pill_row.alignment = BoxContainer.ALIGNMENT_CENTER
	pill_row.add_theme_constant_override("separation", 8)
	pill_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(pill_row)
	var coin_icon: UiIcon = UiIcon.make("coin", Kit.color("coin", UI.colors["acento"]).lightened(0.15), 46.0)
	coin_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill_row.add_child(coin_icon)
	_wallet = Label.new()
	_wallet.name = "Wallet"
	_wallet.text = str(Save.wallet())
	_wallet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill_row.add_child(_wallet)
	var plus: Label = Label.new()
	plus.text = "+"
	plus.add_theme_color_override("font_color", UI.colors["exito"])
	plus.add_theme_font_size_override("font_size", 40)
	plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill_row.add_child(plus)

	## Titulo con aspecto de logotipo (degradado, contorno grueso, sombra y rebote).
	var logo: LogoTitle = LogoTitle.new()
	logo.name = "Title"
	logo.font = UI.font
	logo.max_size = int(UiTheme.params(UI.profile)["title_size"])
	logo.use_palette(UI.colors)
	logo.text = str(Kit.config["muestra"]) if Kit.config.has("muestra") else Kit.text("title", str(Kit.config.get("title", "")))
	_title = logo
	col.add_child(_title)
	var sub: Label = Label.new()
	sub.name = "Tagline"
	sub.theme_type_variation = "SubtleLabel"
	sub.text = Kit.text("tagline", "")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(sub)

	## 3 - En medio: botones redondos a los lados; el hueco del centro es para el heroe.
	var mid: HBoxContainer = HBoxContainer.new()
	mid.name = "Middle"
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(mid)
	var left: VBoxContainer = VBoxContainer.new()
	left.name = "Left"
	left.add_theme_constant_override("separation", 10)
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_child(left)
	var hole: Control = Control.new()
	hole.name = "HeroSpot"
	hole.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hole.mouse_filter = Control.MOUSE_FILTER_STOP
	hole.gui_input.connect(_hero_input)
	mid.add_child(hole)
	var right: VBoxContainer = VBoxContainer.new()
	right.name = "Right"
	right.add_theme_constant_override("separation", 10)
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_child(right)
	## Misiones y pase de temporada (con el numero de premios por cobrar).
	if Kit.feature("pase"):
		var ms: Button = _side_button(left, "BtnSeason", Kit.text("missions", "Misiones"), "star")
		_season_badge(ms)
		ms.pressed.connect(func() -> void:
			var sp: SeasonPanel = SeasonPanel.open(self)
			sp.closed.connect(func() -> void:
				_season_badge(ms)
				_refresh_meta()))
	## Torneo semanal (si el juego tiene servidor y el jugador no ha apagado lo online).
	if Online.available():
		var tor: Button = _side_button(left, "BtnTorneo", Kit.text("torneo_short", "Torneo"), "trophy")
		tor.pressed.connect(func() -> void: TournamentPanel.open(self))
	## Reto del dia: un nivel con un giro sorpresa (premio una vez al dia).
	if not Twist.daily_today().is_empty():
		var reto: Button = _side_button(left, "BtnDaily", Kit.text("daily_challenge", "Reto"), "trophy")
		if Twist.daily_done():
			reto.modulate = Color(1, 1, 1, 0.6)
		else:
			_dot(reto)
		reto.pressed.connect(func() -> void:
			if Twist.start_daily():
				UI.goto(UI.game_scene()))
	var shop: Button = _side_button(right, "BtnShop", Kit.text("shop", "Tienda"), "coin")
	shop.pressed.connect(_open_shop)
	## Arena: partidas en directo contra otros jugadores.
	if Genres.current() in ["brawl", "royale", "zombie", "kart"] and Online.available():
		var live: Button = _side_button(right, "BtnArenaLive", Kit.text("arena_short", "Online"), "share")
		live.pressed.connect(func() -> void: ArenaPanel.open(self))
	## Mazmorras: equipo de los cofres y talentos para siempre.
	if Genres.current() == "dungeon":
		var eq: Button = _side_button(right, "BtnGear", Kit.text("dungeon_gear", "Equipo"), "star")
		eq.pressed.connect(func() -> void: DungeonGearPanel.open(self))
	## Cartas coleccionables: tu coleccion y tu mazo.
	if Genres.current() == "ccg":
		var dk: Button = _side_button(right, "BtnDeck", Kit.text("cc_deck_short", "Mazo"), "grid")
		dk.pressed.connect(func() -> void: CcgDeckPanel.open(self))
	## Aldea: tu propia aldea entre asaltos.
	if Genres.current() == "village":
		var home: Button = _side_button(right, "BtnHome", Kit.text("village_home", "Mi aldea"), "grid")
		home.pressed.connect(func() -> void: UI.goto("res://scenes/village_home.tscn"))
	## Promocion cruzada: los otros juegos del mismo creador.
	if not CrossPanel.games().is_empty():
		var more: Button = _side_button(right, "BtnCross", Kit.text("cross_short", "M\u00e1s juegos"), "play")
		more.pressed.connect(func() -> void: CrossPanel.open(self))
	var settings: Button = _side_button(right, "BtnSettings", Kit.text("settings", "Ajustes"), "gear")
	settings.pressed.connect(func() -> void: SettingsPanel.open(self))
	## Modos de juego (en la columna con menos botones para no empujar el boton de jugar).
	## Maraton: todos los niveles seguidos con 3 vidas (cuando ya has jugado unos cuantos).
	if Marathon.available():
		var mar: Button = _side_button(_shorter(left, right), "BtnMarathon", Kit.text("mar_short", "Marat\u00f3n"), "star")
		mar.pressed.connect(func() -> void:
			Marathon.start()
			UI.goto(UI.game_scene()))
	## Juegos de tablero: 2 jugadores en el mismo movil.
	if Versus.supported(Genres.current()):
		var two: Button = _side_button(_shorter(left, right), "BtnVersus", Kit.text("vs_two", "2 jugadores"), "play")
		two.pressed.connect(func() -> void:
			Versus.start()
			UI.goto(UI.game_scene()))

	## Ruta de trofeos (premios cada 50 trofeos).
	var road: Button = _side_button(left, "BtnRoad", Kit.text("trophies", "Trofeos"), "trophy")
	if not Chests.road_claimable().is_empty():
		_dot(road)
	road.pressed.connect(func() -> void:
		var tr: TrophyRoad = TrophyRoad.open(self)
		tr.closed.connect(_rebuild_chests)
		tr.closed.connect(_refresh_meta))
	## Juego regalo: el mensaje secreto (o cuando aparece).
	if Gift.active():
		var gm: Button = _side_button(_shorter(left, right), "BtnGiftMenu", Kit.text("gift_short", "Mensaje"), "heart")
		gm.pressed.connect(func() -> void: GiftPanel.open(self))
	## Premio real del autor: lo que hay que hacer para ganarlo o el codigo ya ganado.
	if Prize.visible():
		var pz: Button = _side_button(_shorter(left, right), "BtnPrizeMenu", Kit.text("prize_short", "Premio"), "trophy")
		pz.pressed.connect(func() -> void: PrizePanel.open(self))
	_compact_sides(left, right)
	_left = left
	_right = right
	## 3b - Cofres: cuatro huecos sobre el boton de jugar (se ganan superando niveles).
	_chest_row = HBoxContainer.new()
	_chest_row.name = "Chests"
	_chest_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_chest_row.add_theme_constant_override("separation", 12)
	col.add_child(_chest_row)
	_rebuild_chests()

	## 4 - Abajo: por donde vas y un JUGAR enorme que late y brilla.
	var where: Label = Label.new()
	where.name = "Progress"
	where.text = Kit.text("level_n", "Nivel %d") % mini(Save.unlocked_count(), maxi(1, (Kit.config.get("levels", []) as Array).size()))
	where.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	where.theme_type_variation = "SubtleLabel"
	col.add_child(where)
	_play = UI.make_button(Kit.text("play", "Jugar"), true, "play")
	_play.name = "BtnPlay"
	_play.custom_minimum_size = Vector2(460, 138)
	_play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_play.add_theme_font_size_override("font_size", int(float(UiTheme.params(UI.profile)["button_font"]) * 1.45))
	_play.pressed.connect(func() -> void: UI.goto(UI.SCREEN_LEVELS))
	col.add_child(_play)
	var shine: Control = Control.new()
	shine.name = "Shine"
	shine.set_anchors_preset(Control.PRESET_FULL_RECT)
	shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shine.clip_contents = true
	shine.draw.connect(_draw_shine.bind(shine))
	_play.add_child(shine)
	var foot: Control = Control.new()
	foot.custom_minimum_size = Vector2(0, 8)
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(foot)

	## 5 - Evento en directo del autor (monedas dobles o regalo): una franja bajo el titulo.
	if Online.backend():
		_load_event.call_deferred(col, sub.get_index() + 1)
		Online.fetch_prize.call_deferred()
		Online.fetch_gift.call_deferred()
	Audio.play_track("menu")
	## Partida de muestra ("Probar" en el taller de la app): directo al nivel 1, sin premio diario.
	if Kit.config.has("muestra"):
		if not UI.test_mode and not _sample_started:
			_sample_started = true
			_start_sample.call_deferred()
	## Premio diario al entrar (una vez al dia; en las pruebas no sale solo).
	elif not UI.test_mode and Save.daily_pending(Save.today()) > 0:
		_open_daily.call_deferred()
	elif not UI.test_mode:
		open_inbox.call_deferred()
	resized.connect(_layout_art)
	_layout_art.call_deferred()
	_fit_height.call_deferred()
	_intro.call_deferred()


func _start_sample() -> void:
	Kit.level_index = 0
	UI.goto(UI.game_scene())


func _load_event(col: VBoxContainer, at: int) -> void:
	var ev: Dictionary = await Online.fetch_event()
	if ev.is_empty() or not is_inside_tree():
		return
	var band: PanelContainer = PanelContainer.new()
	band.name = "EventBand"
	band.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(band)
	col.move_child(band, at)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	band.add_child(row)
	row.add_child(UiIcon.make("star", UI.colors["acento"], 40.0))
	var secs: int = int(ev.get("segundos", 0))
	var left: String = Kit.text("ends_in", "acaba en {d} d {h} h").format({"d": secs / 86400, "h": (secs % 86400) / 3600})
	var info: Label = Label.new()
	info.name = "EventText"
	var what: String = Kit.text("event_x2", "Monedas dobles") if str(ev.get("tipo", "")) == "monedas_x2" else Kit.text("event_gift", "Regalo")
	info.text = "%s \u00b7 %s\n%s" % [str(ev.get("titulo", "")), what, left]
	row.add_child(info)
	if str(ev.get("tipo", "")) == "regalo" and not bool(ev.get("cobrado", false)):
		var gift: Button = UI.make_button(Kit.text("event_claim", "Recoger {n}").format({"n": int(ev.get("regalo", 0))}), true, "coin")
		gift.name = "BtnEventGift"
		gift.pressed.connect(func() -> void:
			gift.disabled = true
			var got: int = await Online.event_gift_claim()
			if got > 0:
				UI.float_text(gift, gift.size * 0.5, "+%d" % got, UI.colors["acento"])
				Audio.play("coin")
				_refresh_meta()
			gift.queue_free())
		row.add_child(gift)
	UI.pop_in(band, 0.1)


## Textos largos (p. ej. "Einstellungen") en media anchura: se encoge la letra hasta que quepan
## junto al icono (como mucho al 60 %).
static func _fit_text(b: Button) -> void:
	b.remove_theme_font_size_override("font_size")
	var f: Font = b.get_theme_font("font")
	var fs: int = b.get_theme_font_size("font_size")
	var sb: StyleBox = b.get_theme_stylebox("normal")
	var room: float = b.size.x - sb.get_margin(SIDE_LEFT) - sb.get_margin(SIDE_RIGHT) - 56.0
	var w: float = f.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if w > room and room > 0.0:
		b.add_theme_font_size_override("font_size", maxi(int(float(fs) * room / w), int(float(fs) * 0.6)))


## Premios por cobrar: un circulo con el numero en la esquina del boton (no cambia el texto).
func _season_badge(b: Button) -> void:
	var old: Node = b.get_node_or_null("Badge")
	if old != null:
		old.queue_free()
	var n: int = Season.pending()
	if n <= 0:
		return
	var badge: Label = Label.new()
	badge.name = "Badge"
	badge.text = str(mini(n, 99))
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 24)
	badge.add_theme_color_override("font_color", Color.WHITE)
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = UI.colors["peligro"]
	bg.set_corner_radius_all(20)
	badge.add_theme_stylebox_override("normal", bg)
	badge.custom_minimum_size = Vector2(40.0, 40.0)
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.position = Vector2(-30.0, -12.0)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(badge)


func _open_daily() -> void:
	var p: DailyPanel = DailyPanel.open(self, Save.daily_pending(Save.today()))
	p.closed.connect(_refresh_meta)
	p.closed.connect(open_inbox)


## Buzon "Mientras no estabas" (una vez por sesion y solo si hay algo).
func open_inbox() -> void:
	if _inbox_shown or not is_inside_tree():
		return
	_inbox_shown = true
	var items: Array = await Notify.inbox()
	if items.is_empty() or not is_inside_tree():
		return
	var p: InboxPanel = InboxPanel.open(self, items)
	p.closed.connect(_refresh_meta)


## Huecos de cofre: vacio, cerrado (con lo que tarda), abriendose (cuenta atras) o listo (salta).
func _rebuild_chests() -> void:
	if _chest_row == null:
		return
	for c: Node in _chest_row.get_children():
		c.queue_free()
	var s: Array = Chests.slots()
	for i: int in Chests.SLOTS:
		var b: Button = Button.new()
		b.name = "Chest%d" % i
		b.custom_minimum_size = Vector2(128, 120)
		b.focus_mode = Control.FOCUS_NONE
		var idx: int = i
		b.draw.connect(_draw_slot.bind(b, idx))
		if i < s.size():
			b.pressed.connect(func() -> void:
				Audio.play("ui_tap", 0.05, -4.0)
				Juice.vibrate(12)
				var p: ChestPanel = ChestPanel.open_slot(self, idx)
				p.closed.connect(_rebuild_chests)
				p.closed.connect(_refresh_meta))
		else:
			b.disabled = true
		_chest_row.add_child(b)


func _draw_slot(b: Button, i: int) -> void:
	var s: Array = Chests.slots()
	var r: Rect2 = Rect2(Vector2.ZERO, b.size)
	if i >= s.size():
		## Hueco libre: silueta de cofre en sombra y «Libre» (13 nov: la critica veia «cuadros vacios
		## sin contenido» bajo el personaje).
		b.draw_rect(r.grow(-6.0), Color(0, 0, 0, 0.22))
		b.draw_rect(r.grow(-6.0), Color(1, 1, 1, 0.22), false, 3.0)
		var g: Color = Color(1, 1, 1, 0.2)
		var cx: float = b.size.x * 0.5
		b.draw_rect(Rect2(Vector2(cx - 34.0, 40.0), Vector2(68.0, 34.0)), g, false, 3.0)
		b.draw_rect(Rect2(Vector2(cx - 36.0, 24.0), Vector2(72.0, 16.0)), g, false, 3.0)
		b.draw_rect(Rect2(Vector2(cx - 6.0, 34.0), Vector2(12.0, 14.0)), g)
		var f0: Font = UI.font
		b.draw_string(f0, Vector2(0, b.size.y - 14.0), Kit.text("chest_slot_free", "Libre"), HORIZONTAL_ALIGNMENT_CENTER, b.size.x, 19, Color(1, 1, 1, 0.45))
		return
	var typ: String = str(s[i]["type"])
	var ready: bool = Chests.ready(i)
	var bounce: float = absf(sin(_t * 5.0)) * 10.0 if ready else 0.0
	ChestPanel.draw_chest(b, Rect2(Vector2(20, 12 - bounce), Vector2(88, 64)), ChestPanel.type_color(typ), 0.0)
	var f: Font = UI.font
	var txt: String = Kit.text("chest_open", "Abrir") + "!" if ready else (Chests.fmt_time(Chests.seconds_left(i)) if Chests.unlocking() == i else Chests.fmt_time(int(Chests.TYPES[typ]["secs"])))
	var col: Color = UI.colors["exito"] if ready else (UI.colors["acento"] if Chests.unlocking() == i else UI.colors["texto"])
	b.draw_string_outline(f, Vector2(0, b.size.y - 12.0), txt, HORIZONTAL_ALIGNMENT_CENTER, b.size.x, 22, 6, Color(0, 0, 0, 0.8))
	b.draw_string(f, Vector2(0, b.size.y - 12.0), txt, HORIZONTAL_ALIGNMENT_CENTER, b.size.x, 22, col)


## La columna lateral con menos botones (los modos nuevos van ahi). A la izquierda aun falta
## el boton de trofeos, que se pone al final.
func _shorter(left: VBoxContainer, right: VBoxContainer) -> VBoxContainer:
	return right if right.get_child_count() <= left.get_child_count() + 1 else left


## Con muchos botones en una columna se hacen algo mas pequenos para que quepa todo.
func _compact_sides(left: VBoxContainer, right: VBoxContainer, force: bool = false) -> void:
	var n: int = maxi(left.get_child_count(), right.get_child_count())
	if n < 5 and not force:
		return
	var side: float = UI.MIN_TOUCH
	for col: VBoxContainer in [left, right]:
		col.add_theme_constant_override("separation", 4 if n == 5 else 0)
	for box: Control in _side:
		for ch: Node in box.get_children():
			if ch is Button:
				(ch as Button).custom_minimum_size = Vector2(side, side)
			elif ch is Label:
				(ch as Label).add_theme_font_size_override("font_size", 19)
				(ch as Label).custom_minimum_size = Vector2(maxf(side, 104.0), 0)


## Si "Jugar" no cabe (banner abajo o movil bajito): botones de los lados compactos, logo mas
## pequeno y, si aun no, sin la fila de cofres (siguen en la ruta de trofeos).
func _fit_height() -> void:
	for step: int in 3:
		await get_tree().process_frame
		await get_tree().process_frame
		if not is_inside_tree() or _play == null or not is_instance_valid(_play):
			return
		if _play.get_global_rect().end.y <= UI.safe_rect(get_viewport()).end.y + 1.0:
			return
		match step:
			0:
				_compact_sides(_left, _right, true)
			1:
				var logo: LogoTitle = _title as LogoTitle
				if logo != null:
					logo.max_size = int(float(logo.max_size) * 0.7)
					logo._relayout()
			2:
				if _chest_row != null:
					_chest_row.visible = false


## Boton redondo de un lado (icono grande) con su nombre debajo.
func _side_button(parent: VBoxContainer, node_name: String, label: String, icon: String) -> Button:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(box)
	var b: Button = UI.make_icon_button(icon)
	b.name = node_name
	b.custom_minimum_size = Vector2(112, 112)
	## Iconos con su color (moneda dorada, estrella y trofeo del acento), como en los juegos grandes.
	var tint: Color = Kit.color("coin", UI.colors["acento"]).lightened(0.15) if icon == "coin" else (UI.colors["acento"] if icon in ["star", "trophy"] else UI.colors["texto"])
	## Medallon de color propio por boton (antes todos eran iconos genericos sobre el mismo cuadrado:
	## critica «interfaz_sosa» repetida, 12 nov). Va dentro del marco, asi respeta la piel del juego.
	var tonos: Dictionary = {"BtnSeason": 0.78, "BtnDaily": 0.02, "BtnTorneo": 0.02, "BtnRoad": 0.12, "BtnShop": 0.36,
		"BtnCross": 0.58, "BtnSettings": -1.0, "BtnArenaLive": 0.92, "BtnGear": 0.08, "BtnDeck": 0.68, "BtnHome": 0.3,
		"BtnMarathon": 0.5, "BtnVersus": 0.95, "BtnGiftMenu": 0.9, "BtnPrizeMenu": 0.14}
	var h: float = float(tonos.get(node_name, -1.0))
	if h >= 0.0:
		var medal: Control = Control.new()
		medal.name = "Medal"
		medal.mouse_filter = Control.MOUSE_FILTER_IGNORE
		medal.set_anchors_preset(Control.PRESET_FULL_RECT)
		var base: Color = Color.from_hsv(h, 0.62, 0.78)
		medal.draw.connect(func() -> void:
			var c: Vector2 = medal.size * 0.5
			var r: float = minf(medal.size.x, medal.size.y) * 0.36
			medal.draw_circle(c + Vector2(0, r * 0.08), r, base.darkened(0.45))
			medal.draw_circle(c, r, base)
			medal.draw_circle(c + Vector2(0, -r * 0.18), r * 0.78, base.lightened(0.12))
			medal.draw_arc(c, r, 0.0, TAU, 40, base.lightened(0.45), 3.0, true))
		b.add_child(medal)
		b.move_child(medal, 0)
		tint = Color(1, 1, 1) if icon != "coin" else Kit.color("coin", UI.colors["acento"]).lightened(0.3)
	for ch: Node in b.get_children():
		if ch is UiIcon:
			(ch as UiIcon).color = tint
			if h >= 0.0:
				## El icono dentro del medallon, con aire alrededor.
				var ic: UiIcon = ch as UiIcon
				ic.offset_left = 32.0
				ic.offset_top = 32.0
				ic.offset_right = -32.0
				ic.offset_bottom = -32.0
			(ch as UiIcon).queue_redraw()
	box.add_child(b)
	var l: Label = Label.new()
	l.text = label
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	## Textos largos (idiomas, nombres del juego): la letra baja hasta que cabe y, si aun asi no,
	## puntos suspensivos. Antes un rotulo de 120 px en 112 tumbaba el juego entero en la validacion.
	var fs: int = 22
	var fnt: Font = l.get_theme_font("font")
	while fs > 15 and fnt != null and fnt.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > 108.0:
		fs -= 1
	l.add_theme_font_size_override("font_size", fs)
	l.custom_minimum_size = Vector2(112, 0)
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(l)
	_side.append(box)
	return b


## Puntito rojo de aviso en la esquina (hay algo nuevo).
func _dot(b: Button) -> void:
	var d: Panel = Panel.new()
	d.name = "Dot"
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = UI.colors["peligro"]
	sb.set_corner_radius_all(14)
	sb.border_color = Color.WHITE
	sb.set_border_width_all(3)
	d.add_theme_stylebox_override("panel", sb)
	d.size = Vector2(28, 28)
	d.position = Vector2(84, -4)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(d)


func _open_shop() -> void:
	var p: ShopPanel = ShopPanel.open(self)
	p.changed.connect(_refresh_meta)
	p.closed.connect(_refresh_meta)


func _refresh_meta() -> void:
	var before: int = int(_wallet.text) if _wallet.text.is_valid_int() else 0
	var now: int = Save.wallet()
	if now > before and not UI.test_mode:
		UI.count_up(_wallet, now, "%d", 0.6)
	else:
		_wallet.text = str(now)
	if _hero != null:
		Skins.apply(_hero)
	if _level_chip != null:
		_level_chip.queue_redraw()


## 6 - Entrada orquestada: logo letra a letra, botones de los lados en cascada y JUGAR con rebote.
func _intro() -> void:
	(_title as LogoTitle).play_intro()
	var i: int = 0
	for b: Control in _side:
		UI.pop_in(b, 0.2 + 0.06 * float(i))
		i += 1
	UI.pop_in(_play, 0.35 + 0.06 * float(i))


func _process(delta: float) -> void:
	_t += delta
	if _rays != null:
		_rays.queue_redraw()
	## JUGAR late suave y cada 3 s le cruza un brillo.
	if _play != null and not _play.is_pressed() and _play.scale.x > 0.97:
		var k: float = 1.0 + 0.035 * maxf(0.0, sin(_t * 3.2))
		_play.pivot_offset = _play.size * 0.5
		_play.scale = Vector2(k, k)
	var ph: float = fmod(_t, 3.0)
	_shine = ph / 0.6 if ph < 0.6 else -1.0
	var sh: Node = _play.get_node_or_null("Shine") if _play != null else null
	if sh != null:
		(sh as Control).queue_redraw()
	## Los cofres cuentan el tiempo y saltan cuando estan listos.
	_chest_tick -= delta
	if _chest_row != null and _chest_tick <= 0.0:
		_chest_tick = 0.1
		for c: Node in _chest_row.get_children():
			(c as Control).queue_redraw()
	## El heroe respira en su pedestal (y sigue al hueco del centro si la pantalla cambia).
	if _hero_root != null and not _hero_busy:
		_layout_art()
		_hero_root.scale = Vector2(1.0 + 0.02 * sin(_t * 2.4), 1.0 - 0.02 * sin(_t * 2.4))


func _draw_shine(c: Control) -> void:
	if _shine < 0.0:
		return
	var w: float = c.size.x
	var x: float = lerpf(-120.0, w + 120.0, _shine)
	c.draw_colored_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + 50.0, 0), Vector2(x + 10.0, c.size.y), Vector2(x - 40.0, c.size.y)]), Color(1, 1, 1, 0.35))


func _draw_rays() -> void:
	if _hero_root == null:
		return
	var c: Vector2 = _hero_root.position + Vector2(0, -110)
	var col: Color = (UI.colors["acento"] as Color)
	for k: int in 12:
		var a: float = _t * 0.15 + TAU * float(k) / 12.0
		var a2: float = a + 0.13
		col.a = 0.07 if k % 2 == 0 else 0.035
		_rays.draw_colored_polygon(PackedVector2Array([c, c + Vector2.from_angle(a) * 700.0, c + Vector2.from_angle(a2) * 700.0]), col)
	for k2: int in 4:
		_rays.draw_circle(c, 190.0 - float(k2) * 40.0, Color(col.r, col.g, col.b, 0.05))


## Tu nivel de jugador (sale de la experiencia del pase) con su barra.
func _draw_level_chip() -> void:
	var s: Vector2 = _level_chip.size
	var xp: int = Season.xp()
	var lvl: int = 1 + xp / 500
	var frac: float = float(xp % 500) / 500.0
	var bg: Color = (UI.colors["panel"] as Color)
	var r: float = s.y * 0.5 - 4.0
	var c: Vector2 = Vector2(r + 4.0, s.y * 0.5)
	_level_chip.draw_rect(Rect2(Vector2(c.x, 14), Vector2(s.x - c.x - 6.0, s.y - 28.0)), bg.darkened(0.2))
	_level_chip.draw_rect(Rect2(Vector2(c.x, s.y - 30.0), Vector2((s.x - c.x - 6.0) * frac, 14.0)), UI.colors["exito"])
	_level_chip.draw_circle(c, r, UI.colors["borde"])
	_level_chip.draw_circle(c, r - 5.0, UI.colors["acento"])
	_level_chip.draw_arc(c, r - 2.0, -PI * 0.5, -PI * 0.5 + TAU * frac, 32, UI.colors["exito"], 5.0)
	var f: Font = UI.font
	_level_chip.draw_string(f, c + Vector2(-r, 13), str(lvl), HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 38, UI.colors["acento_texto"])
	_level_chip.draw_string(f, Vector2(c.x + r + 10.0, 42), Kit.text("player_level", "Nivel %d") % lvl, HORIZONTAL_ALIGNMENT_LEFT, s.x - c.x - r - 12.0, 26, UI.colors["texto"])


## Tocar al heroe: salta, gira, suelta chispas y suena (siempre apetece tocarlo).
func _hero_input(ev: InputEvent) -> void:
	var tap: bool = (ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed) or (ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed)
	if not tap or _hero_root == null or _hero_busy:
		return
	_hero_busy = true
	Audio.play("jump", 0.1, -6.0)
	Audio.play("ui_pop", 0.1, -10.0)
	Juice.vibrate(18)
	Juice.burst(self, _hero_root.position + Vector2(0, -90), UI.colors["acento"], 18)
	var tw: Tween = _hero_root.create_tween()
	tw.tween_property(_hero_root, "scale", Vector2(1.2, 0.8), 0.07)
	tw.tween_property(_hero_root, "scale", Vector2(0.9, 1.15), 0.08)
	tw.parallel().tween_property(_hero_root, "position:y", _hero_root.position.y - 90.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_hero_root, "rotation", TAU, 0.42)
	tw.tween_property(_hero_root, "position:y", _hero_root.position.y, 0.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(_hero_root, "scale", Vector2.ONE, 0.12)
	tw.tween_callback(func() -> void:
		_hero_root.rotation = 0.0
		_hero_busy = false)



## 2 - Fondo ilustrado de la fabrica (assets/ui/fondo_titulo.jpg), con un velo para que se lea el titulo.
func _build_backdrop() -> void:
	var ui_cfg: Dictionary = Kit.assets.get("ui", {}) as Dictionary
	var path: String = str(ui_cfg.get("fondo", ""))
	if path == "":
		return
	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		return
	var tr: TextureRect = TextureRect.new()
	tr.name = "Backdrop"
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tr)
	var veil: ColorRect = ColorRect.new()
	veil.name = "Veil"
	veil.color = Color(UI.colors["fondo"], 0.35)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)


func _build_scene_art() -> void:
	var art: Node2D = Node2D.new()
	art.name = "Art"
	add_child(art)
	## Pedestal: un disco con el suelo del juego y su canto.
	_pedestal = Node2D.new()
	_pedestal.name = "Pedestal"
	art.add_child(_pedestal)
	var rim: Polygon2D = Polygon2D.new()
	rim.polygon = _ellipse(170.0, 46.0, 40)
	rim.position = Vector2(0, 22)
	rim.color = (UI.colors["borde"] as Color)
	_pedestal.add_child(rim)
	var top: Polygon2D = Polygon2D.new()
	top.polygon = _ellipse(170.0, 46.0, 40)
	var tex: Texture2D = Kit.first_tile_texture()
	if tex != null:
		top.texture = tex
		top.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		var uv: PackedVector2Array = PackedVector2Array()
		for v: Vector2 in top.polygon:
			uv.append(v + Vector2(170, 46))
		top.uv = uv
	else:
		top.color = UI.colors["panel_hi"]
	_pedestal.add_child(top)
	var glow: Polygon2D = Polygon2D.new()
	glow.polygon = _ellipse(120.0, 28.0, 32)
	glow.color = Color(1, 1, 1, 0.12)
	_pedestal.add_child(glow)
	_hero_root = Node2D.new()
	_hero_root.name = "HeroRoot"
	art.add_child(_hero_root)
	var hero_art: Dictionary = Kit.sprite_by_role("jugador")
	if not hero_art.is_empty():
		var anims: Dictionary = hero_art.get("animaciones", {})
		_hero = SpriteKit.animado(hero_art, 220.0, "idle" if anims.has("idle") else "run", true)
		Skins.apply(_hero)
		_hero_root.add_child(_hero)
	var coin_art: Dictionary = Kit.sprite_entry(str(Kit.param("art.coin", "moneda")))
	if not coin_art.is_empty():
		_coin = SpriteKit.animado(coin_art, 56.0, "spin", false)
		art.add_child(_coin)


func _ellipse(rx: float, ry: float, n: int) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for i: int in n:
		var a: float = TAU * float(i) / float(n)
		out.append(Vector2(cos(a) * rx, sin(a) * ry))
	return out


func _layout_art() -> void:
	var w: float = size.x
	var h: float = size.y
	var mid: Control = find_child("HeroSpot", true, false) as Control
	var base: Vector2 = Vector2(w * 0.5, h * 0.62)
	if mid != null and mid.size.y > 10.0:
		var r: Rect2 = mid.get_global_rect()
		base = Vector2(r.get_center().x, r.end.y - 40.0) - get_global_rect().position
	_pedestal.position = base
	if not _hero_busy:
		_hero_root.position = base
	if _coin != null:
		_coin.position = base + Vector2(150.0, -230.0)

