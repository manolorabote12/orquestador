class_name CcgDeckPanel
extends UiModal
## Editor del mazo de las cartas coleccionables: tus cartas con su coste y lo que hacen, cuantas
## llevas en el mazo y botones para quitar y poner. Se guarda cuando tiene DECK_SIZE cartas.

const M = preload("res://kit/ccg/ccg_map.gd")
const KW: Dictionary = {"taunt": "Provocar", "charge": "Carga", "shield": "Escudo"}
const FX: Dictionary = {"dmg": "{n} de da\u00f1o", "heal": "Cura {n}", "draw": "Roba {n}", "buff": "+{n}/+{n}", "aoe": "{n} a todos"}

var picked: Dictionary = {}
var _count_label: Label
var _save_btn: Button
var _rows: Dictionary = {}


static func open(host: Node) -> CcgDeckPanel:
	var p: CcgDeckPanel = CcgDeckPanel.new()
	p.name = "CcgDeckPanel"
	p.layer = 60
	host.add_child(p)
	return p


func _ready() -> void:
	build_frame(Kit.text("cc_deck", "Tu mazo"), 660.0)
	var start: Array = CcgCollection.deck()
	if not CcgCollection.valid(start):
		var levels: Array = Kit.config.get("levels", [])
		start = (levels[0] as Dictionary).get("deck", []) if not levels.is_empty() else []
	for c: Variant in start:
		picked[str(c)] = int(picked.get(str(c), 0)) + 1
	_count_label = Label.new()
	_count_label.name = "DeckCount"
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_count_label)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.custom_minimum_size = Vector2(0.0, minf(760.0, root.get_viewport().get_visible_rect().size.y - 560.0))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var list: VBoxContainer = VBoxContainer.new()
	list.name = "Cards"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	var have: Dictionary = CcgCollection.owned()
	var ids: Array = M.CARDS.keys()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool:
		var ca: int = int(M.CARDS[a]["cost"])
		var cb: int = int(M.CARDS[b]["cost"])
		return ca < cb or (ca == cb and str(a) < str(b)))
	for id: Variant in ids:
		if int(have.get(id, 0)) > 0:
			list.add_child(_row(str(id), mini(int(have[id]), CcgCollection.max_copies(str(id)))))
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	body.add_child(buttons)
	var reset: Button = UI.make_button(Kit.text("cc_deck_level", "El del nivel"), false, "retry")
	reset.name = "BtnDeckLevel"
	reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset.pressed.connect(func() -> void:
		CcgCollection.save_deck([])
		close())
	buttons.add_child(reset)
	_save_btn = UI.make_button(Kit.text("save", "Guardar"), true, "")
	_save_btn.name = "BtnDeckSave"
	_save_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_save_btn.pressed.connect(func() -> void:
		if CcgCollection.save_deck(current()):
			close())
	buttons.add_child(_save_btn)
	_update()


## El mazo tal como esta ahora en el editor.
func current() -> Array:
	var out: Array = []
	for id: Variant in picked:
		for k: int in int(picked[id]):
			out.append(str(id))
	return out


func _row(id: String, have: int) -> Control:
	var c: Dictionary = M.CARDS[id]
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Card_" + id
	row.add_theme_constant_override("separation", 10)
	var cost: Label = Label.new()
	cost.text = str(int(c["cost"]))
	cost.custom_minimum_size = Vector2(44.0, 0.0)
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost.add_theme_color_override("font_color", Color("#7ee8fa"))
	row.add_child(cost)
	var info: VBoxContainer = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 0)
	row.add_child(info)
	var nm: Label = Label.new()
	nm.text = CcgCollection.card_name(id)
	nm.clip_text = true
	info.add_child(nm)
	var what: Label = Label.new()
	what.text = describe(id)
	what.clip_text = true
	what.add_theme_font_size_override("font_size", 20)
	what.add_theme_color_override("font_color", UI.colors["texto_suave"])
	info.add_child(what)
	var minus: Button = UI.make_button("-", false, "")
	minus.name = "Minus"
	minus.custom_minimum_size = Vector2(UI.MIN_TOUCH, UI.MIN_TOUCH)
	minus.pressed.connect(_change.bind(id, -1, have))
	row.add_child(minus)
	var n: Label = Label.new()
	n.name = "N"
	n.custom_minimum_size = Vector2(60.0, 0.0)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(n)
	var plus: Button = UI.make_button("+", false, "")
	plus.name = "Plus"
	plus.custom_minimum_size = Vector2(UI.MIN_TOUCH, UI.MIN_TOUCH)
	plus.pressed.connect(_change.bind(id, 1, have))
	row.add_child(plus)
	_rows[id] = [n, minus, plus, have]
	return row


## Lo que hace la carta en pocas palabras.
static func describe(id: String) -> String:
	var c: Dictionary = M.CARDS[id]
	if str(c["kind"]) == "minion":
		var kw: String = str(c.get("kw", ""))
		return "%d/%d" % [int(c["atk"]), int(c["hp"])] + ("  " + Kit.text("cc_kw_" + kw, str(KW[kw])) if KW.has(kw) else "")
	var fx: String = str(c["fx"])
	return Kit.text("cc_fx_" + fx, str(FX.get(fx, fx))).format({"n": int(c["n"])})


func _change(id: String, d: int, have: int) -> void:
	var now: int = int(picked.get(id, 0)) + d
	if now < 0 or now > have or (d > 0 and current().size() >= CcgCollection.DECK_SIZE):
		return
	picked[id] = now
	Audio.play("click", 0.1, -8.0)
	_update()


func _update() -> void:
	var n: int = current().size()
	_count_label.text = Kit.text("cc_deck_count", "Cartas en el mazo: {n}/{t}").format({"n": n, "t": CcgCollection.DECK_SIZE})
	_count_label.add_theme_color_override("font_color", UI.colors["texto"] if n == CcgCollection.DECK_SIZE else UI.colors["acento"])
	_save_btn.disabled = n != CcgCollection.DECK_SIZE
	for id: Variant in _rows:
		var r: Array = _rows[id]
		var k: int = int(picked.get(id, 0))
		(r[0] as Label).text = "%d/%d" % [k, int(r[3])]
		(r[1] as Button).disabled = k <= 0
		(r[2] as Button).disabled = k >= int(r[3]) or n >= CcgCollection.DECK_SIZE
