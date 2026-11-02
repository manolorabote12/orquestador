extends "res://kit/village/village_game.gd"
## Tu aldea (pantalla entre asaltos, estilo juegos de clanes).
## 1 - Se dibuja con lo que has construido (village_save.gd), con el mismo motor isometrico.
## 2 - "Construir": lista de huecos libres con su precio en monedas del botin; los que pide un
##     ayuntamiento mayor salen bloqueados. Tocar un edificio: su nivel, para que sirve y "Mejorar".
## 3 - Lo construido ayuda en los asaltos (mas tropas, mas fuerza, mas botin).
## 4 - "Atacar" lleva a los niveles (cada nivel es una base enemiga).

const NAMES: Dictionary = {"H": "Ayuntamiento", "G": "Almac\u00e9n de oro", "E": "Almac\u00e9n de elixir", "M": "Mina",
	"K": "Cuartel", "C": "Ca\u00f1\u00f3n", "A": "Torre arquera", "O": "Mortero", "#": "Muralla"}
const HELP: Dictionary = {"H": "Desbloquea edificios y deja subirlos de nivel.",
	"G": "+10 % de bot\u00edn por nivel en cada asalto.", "E": "Tropas un 4 % m\u00e1s fuertes por nivel.",
	"K": "+1 guerrero y +1 arquera por nivel en cada asalto.", "M": "Produce oro para tu aldea.",
	"C": "Defiende tu aldea.", "A": "Defiende tu aldea desde lejos.", "O": "Defensa de \u00e1rea.", "#": "Protege el centro."}

var home_panel: UiModal = null
var _wallet_l: Label
var _bonus_l: Label
var _hall_l: Label


func _ready() -> void:
	rows = VSave.rows()
	_hero_art = Kit.sprite_by_role("jugador")
	var gid: String = str(Kit.param("art.enemies.walker", ""))
	_guard_art = Kit.sprite_entry(gid) if gid != "" else {}
	if _guard_art.is_empty():
		_guard_art = Kit.sprite_by_role("enemigo")
	RenderingServer.set_default_clear_color(Kit.color("sky", Color("#1b2a41")).lerp(Color("#2f5a2a"), 0.6).darkened(0.35))
	_setup_layers()
	_build_home_hud()
	_reset()
	_apply_levels()
	_zone_flash = 0.0
	Audio.play_track("menu")
	QA.log_event("village_home", {"hall": VSave.hall()})


## Mas cerca que en los asaltos: la aldea esta en el centro.
func _fit_camera() -> void:
	super._fit_camera()
	_camera.zoom *= 1.3


func _apply_levels() -> void:
	levels_by_cell.clear()
	levels_by_cell[Vector2i(7, 7)] = VSave.hall()
	for s: Dictionary in VSave.SLOTS:
		if s["key"] != "#" and VSave.level(s["id"]) > 0:
			levels_by_cell[s["cell"]] = VSave.level(s["id"])
	for b: Dictionary in buildings:
		var lv: int = int(levels_by_cell.get(b["cell"], 1))
		b["h"] = float(b["h"]) * (1.0 + 0.18 * float(lv - 1))
		(b["node"] as Node2D).queue_redraw()
	_refresh_hud()


func _build_home_hud() -> void:
	var hud: CanvasLayer = CanvasLayer.new()
	hud.name = "Hud"
	hud.layer = 20
	add_child(hud)
	var root: Control = Control.new()
	root.theme = UI.theme
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(root)
	var safe: MarginContainer = UI.safe_root(root, 20.0)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col: VBoxContainer = VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(col)
	var bar: HBoxContainer = HBoxContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_constant_override("separation", 10)
	col.add_child(bar)
	var back: Button = UI.make_icon_button("back")
	back.name = "BtnBack"
	back.pressed.connect(func() -> void: UI.goto(UI.SCREEN_TITLE))
	bar.add_child(back)
	_hall_l = Label.new()
	_hall_l.name = "Hall"
	_hall_l.theme_type_variation = "HeaderLabel"
	_hall_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hall_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(_hall_l)
	bar.add_child(UiIcon.make("coin", Kit.color("coin", UI.colors["acento"]), 40.0))
	_wallet_l = Label.new()
	_wallet_l.name = "Wallet"
	bar.add_child(_wallet_l)
	_bonus_l = Label.new()
	_bonus_l.name = "Bonus"
	_bonus_l.theme_type_variation = "SubtleLabel"
	_bonus_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bonus_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_bonus_l)
	var grow: Control = Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(grow)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	col.add_child(row)
	var build_b: Button = UI.make_button(Kit.text("village_build", "Construir"), false, "grid")
	build_b.name = "BtnBuild"
	build_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	build_b.pressed.connect(open_build)
	row.add_child(build_b)
	var liga_b: Button = UI.make_button(Kit.text("liga_short", "Liga"), false, "trophy")
	liga_b.name = "BtnLiga"
	liga_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	liga_b.pressed.connect(func() -> void: home_panel = LigaPanel.open(self))
	row.add_child(liga_b)
	var attack: Button = UI.make_button(Kit.text("village_attack", "\u00a1Atacar!"), true, "play")
	attack.name = "BtnAttack"
	attack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	attack.pressed.connect(func() -> void: UI.goto(UI.SCREEN_LEVELS))
	row.add_child(attack)


func _refresh_hud() -> void:
	if _wallet_l == null:
		return
	_wallet_l.text = str(Save.wallet())
	_hall_l.text = Kit.text("village_home", "Mi aldea") + " \u00b7 " + Kit.text("village_hall_lv", "Nv {n}").format({"n": VSave.hall()})
	var b: Dictionary = VSave.bonus()
	_bonus_l.text = Kit.text("village_bonus", "Ej\u00e9rcito +{t} \u00b7 Fuerza +{s} % \u00b7 Bot\u00edn +{l} %").format(
		{"t": int(b["troops"]), "s": int(round(float(b["strength"]) * 100.0)), "l": int(round(float(b["loot"]) * 100.0))})


## Sin batalla: solo se ve la aldea (y los efectos al construir).
func _physics_process(delta: float) -> void:
	time_in_level += delta
	_fx.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if home_panel != null and is_instance_valid(home_panel):
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var m: InputEventMouseButton = event as InputEventMouseButton
		if m.pressed:
			_press = {"at": m.position, "t": 0.0, "moved": false}
		elif not _press.is_empty():
			if not bool(_press["moved"]):
				tap_cell(_screen_cell(m.position))
			_press = {}
	elif event is InputEventMouseMotion and not _press.is_empty():
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		if mm.position.distance_to(_press["at"]) > 18.0:
			_press["moved"] = true
		if bool(_press["moved"]):
			_pan(mm.relative)


## Tocar una casilla: si hay un edificio, su ventana.
func tap_cell(cell: Vector2i) -> void:
	var i: int = int(_occ.get(cell, -1))
	if i < 0:
		return
	var b: Dictionary = buildings[i]
	if b["key"] == "H":
		open_building("hall")
		return
	for s: Dictionary in VSave.SLOTS:
		if s["key"] == "#" and b["key"] == "#":
			open_building(s["id"])
			return
		if s["cell"] == b["cell"]:
			open_building(s["id"])
			return


func _new_panel(title: String) -> UiModal:
	var p: UiModal = UiModal.new()
	p.name = "HomePanel"
	p.layer = 60
	add_child(p)
	p.build_frame(title, 600.0)
	home_panel = p
	return p


func open_building(id: String) -> void:
	var key: String = "H" if id == "hall" else str(VSave.slot(id)["key"])
	var lv: int = VSave.hall() if id == "hall" else VSave.level(id)
	var p: UiModal = _new_panel(Kit.text("village_b_" + key, str(NAMES[key])))
	var info: Label = Label.new()
	info.text = Kit.text("village_lv", "Nivel {n}").format({"n": lv}) + "\n" + Kit.text("village_help_" + key, str(HELP[key]))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.body.add_child(info)
	var price: int = VSave.price(id)
	var b: Button
	if price < 0:
		var msg: String = Kit.text("maxed", "Al m\u00e1ximo") if lv >= VSave.MAX_LEVEL or id == "hall" else Kit.text("village_need_hall", "Sube el ayuntamiento")
		b = UI.make_button(msg, false, "")
		b.disabled = true
	else:
		b = UI.make_button(Kit.text("upgrade", "Mejorar") + " \u00b7 %d" % price, true, "coin")
		b.disabled = Save.wallet() < price
		b.pressed.connect(func() -> void:
			p.close()
			do_build(id))
	b.name = "BtnUpgrade"
	p.body.add_child(b)
	var close_b: Button = UI.make_button(Kit.text("close", "Cerrar"), false, "close")
	close_b.pressed.connect(p.close)
	p.body.add_child(close_b)


func open_build() -> void:
	var p: UiModal = _new_panel(Kit.text("village_build", "Construir"))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 640)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.body.add_child(scroll)
	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	scroll.add_child(list)
	var any: bool = false
	for s: Dictionary in VSave.SLOTS:
		if VSave.level(s["id"]) > 0:
			continue
		any = true
		var key: String = s["key"]
		var price: int = VSave.price(s["id"])
		var locked: bool = VSave.hall() < int(s["hall"])
		var text: String = Kit.text("village_b_" + key, str(NAMES[key]))
		text += "  \u00b7  " + (Kit.text("village_hall_lv", "Nv {n}").format({"n": int(s["hall"])}) if locked else "%d" % price)
		var b: Button = UI.make_button(text, not locked, "lock" if locked else "coin")
		b.name = "Build_" + str(s["id"])
		b.disabled = locked or Save.wallet() < price
		var sid: String = s["id"]
		b.pressed.connect(func() -> void:
			p.close()
			do_build(sid))
		list.add_child(b)
	if not any:
		var done: Label = Label.new()
		done.text = Kit.text("village_all_built", "\u00a1Lo has construido todo! Mejora tus edificios toc\u00e1ndolos.")
		done.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list.add_child(done)
	var close_b: Button = UI.make_button(Kit.text("close", "Cerrar"), false, "close")
	close_b.pressed.connect(p.close)
	p.body.add_child(close_b)


## Construye o mejora y lo celebra (polvo, rebote y sonido).
func do_build(id: String) -> bool:
	if not VSave.build(id):
		return false
	rows = VSave.rows()
	_reset()
	_apply_levels()
	var cell: Vector2i = Vector2i(7, 7) if id == "hall" else VSave.slot(id)["cell"]
	var at: Vector2 = iso(Vector2(cell) + Vector2.ONE)
	Juice.burst(_fx, at, Color("#e8d8b0"), 18, 260.0)
	Juice.ring(_fx, at, Kit.color("coin", Color("#ffcf3f")), 90.0, 0.4)
	var i: int = int(_occ.get(cell, -1))
	if i >= 0:
		var n: Node2D = buildings[i]["node"]
		Juice.squash(n, Vector2(1.15, 0.8), 0.3)
	Audio.play("powerup")
	return true
