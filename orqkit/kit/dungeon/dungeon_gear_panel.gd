class_name DungeonGearPanel
extends UiModal
## Equipo y talentos de las mazmorras (boton "Equipo" de la portada).
## 1 - Equipo: lo que llevas en cada hueco (se consigue en los cofres) con su rareza y su bonus.
## 2 - Talentos: mejoras para siempre que se compran con las monedas de la tienda (vida, dano y
##     cadencia; MAX_LEVEL niveles de STEP cada uno, cada nivel mas caro).

const MapRules = preload("res://kit/dungeon/dungeon_map.gd")
const TALENTS: Array[String] = ["vida", "dano", "cadencia"]
const TALENT_TXT: Dictionary = {"vida": "Vida", "dano": "Da\u00f1o", "cadencia": "Cadencia"}
const MAX_LEVEL: int = 5
const STEP: float = 0.05
const BASE_COST: int = 60

var _rows: Dictionary = {}
var _wallet: Label


static func open(host: Node) -> DungeonGearPanel:
	var p: DungeonGearPanel = DungeonGearPanel.new()
	p.name = "DungeonGearPanel"
	p.layer = 60
	host.add_child(p)
	return p


## Nivel de un talento (0..MAX_LEVEL).
static func level_of(id: String) -> int:
	var v: Variant = Save.meta().get("dungeon_talents", {})
	return clampi(int((v as Dictionary).get(id, 0)) if v is Dictionary else 0, 0, MAX_LEVEL)


## Multiplicador que da un talento (1.0 sin mejorar). Los bots y las pruebas juegan sin talentos.
static func mult(id: String) -> float:
	if UI.test_mode or QA.enabled:
		return 1.0
	return 1.0 + STEP * float(level_of(id))


static func cost(id: String) -> int:
	return BASE_COST * (level_of(id) + 1)


static func buy(id: String) -> bool:
	if level_of(id) >= MAX_LEVEL or not Save.spend(cost(id)):
		return false
	var m: Dictionary = Save.meta()
	var t: Dictionary = (m.get("dungeon_talents", {}) as Dictionary).duplicate() if m.get("dungeon_talents") is Dictionary else {}
	t[id] = level_of(id) + 1
	m["dungeon_talents"] = t
	Save.data["meta"] = m
	Save.save_data()
	QA.log_event("dungeon_talent", {"id": id, "level": int(t[id])})
	return true


func _ready() -> void:
	build_frame(Kit.text("dungeon_gear", "Equipo"), 640.0)
	var gear: Dictionary = Save.meta().get("dungeon_gear", {}) if Save.meta().get("dungeon_gear") is Dictionary else {}
	var names: Dictionary = {"arma": Kit.text("dungeon_weapon", "Arma"), "armadura": Kit.text("dungeon_armor", "Armadura"), "anillo": Kit.text("dungeon_ring", "Anillo")}
	var what: Dictionary = {"arma": Kit.text("dungeon_gear_dmg", "+{n}% da\u00f1o"), "armadura": Kit.text("dungeon_gear_hp", "+{n} vida"), "anillo": Kit.text("dungeon_gear_crit", "+{n}% cr\u00edtico")}
	var rar: Array[String] = [Kit.text("dungeon_common", "com\u00fan"), Kit.text("dungeon_rare", "rara"), Kit.text("dungeon_epic", "\u00e9pica"), Kit.text("dungeon_legend", "legendaria")]
	for slot: String in ["arma", "armadura", "anillo"]:
		var l: Label = Label.new()
		l.name = "Slot_" + slot
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var g: Dictionary = gear.get(slot, {})
		if g.is_empty():
			l.text = str(names[slot]) + ": " + Kit.text("dungeon_gear_none", "nada todav\u00eda (sale en los cofres)")
			l.add_theme_color_override("font_color", UI.colors["texto_suave"])
		else:
			var r: int = clampi(int(g.get("rarity", 0)), 0, 3)
			l.text = "%s %s: %s" % [str(names[slot]), rar[r], str(what[slot]).format({"n": int(float(g.get("bonus", 0.0)))})]
			l.add_theme_color_override("font_color", MapRules.RARITY_COLORS[r])
		body.add_child(l)
	var head: Label = Label.new()
	head.text = Kit.text("dungeon_talents", "Talentos (para siempre)")
	head.theme_type_variation = "HeaderLabel"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(head)
	_wallet = Label.new()
	_wallet.name = "Wallet"
	_wallet.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wallet.add_theme_color_override("font_color", Kit.color("coin", UI.colors["acento"]))
	body.add_child(_wallet)
	for id: String in TALENTS:
		var row: HBoxContainer = HBoxContainer.new()
		row.name = "Talent_" + id
		row.add_theme_constant_override("separation", 12)
		var l2: Label = Label.new()
		l2.name = "Info"
		l2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l2.clip_text = true
		row.add_child(l2)
		var b: Button = UI.make_button("", true, "coin")
		b.name = "Buy"
		b.custom_minimum_size = Vector2(190.0, UI.MIN_TOUCH)
		b.pressed.connect(func() -> void:
			if buy(id):
				Audio.play("powerup", 0.05, -6.0)
				_update())
		row.add_child(b)
		_rows[id] = [l2, b]
		body.add_child(row)
	var close_btn: Button = UI.make_button(Kit.text("close", "Cerrar"), false, "close")
	close_btn.name = "BtnClose"
	close_btn.pressed.connect(close)
	body.add_child(close_btn)
	_update()


func _update() -> void:
	_wallet.text = Kit.text("dungeon_wallet", "Monedas: {n}").format({"n": Save.wallet()})
	for id: Variant in _rows:
		var r: Array = _rows[id]
		var lv: int = level_of(str(id))
		(r[0] as Label).text = "%s %d/%d  (+%d%%)" % [Kit.text("dungeon_t_" + str(id), str(TALENT_TXT[id])), lv, MAX_LEVEL, int(round(STEP * 100.0 * float(lv)))]
		var b: Button = r[1]
		b.text = "     " + (str(cost(str(id))) if lv < MAX_LEVEL else Kit.text("max", "Al m\u00e1ximo"))
		b.disabled = lv >= MAX_LEVEL or Save.wallet() < cost(str(id))
