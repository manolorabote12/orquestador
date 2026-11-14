class_name SummonPanel
extends UiModal
## Invocar heroes (kit/turns/heroes.gd): 1 o 10 con la moneda del juego, las probabilidades a la
## vista y cuantas faltan para el legendario seguro. Cada heroe sale con el color de su rareza.

signal changed

var _info: Label
var _reveal: HFlowContainer
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _one: Button
var _ten: Button


static func open(host: Node) -> SummonPanel:
	var p: SummonPanel = SummonPanel.new()
	p.name = "SummonPanel"
	p.layer = 64
	host.add_child(p)
	return p


func _ready() -> void:
	_rng.randomize()
	if UI.test_mode:
		_rng.seed = 4242
	build_frame(Kit.text("summon", "Invocar"), 640.0)
	var odds: Label = Label.new()
	odds.name = "Odds"
	odds.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	odds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	odds.add_theme_font_size_override("font_size", 17)
	var parts: Array[String] = []
	for r: String in ["legendario", "epico", "raro", "comun"]:
		parts.append("%s %s %%" % [Kit.text("rarity_" + r, r.capitalize()), str(Heroes.RATES[r]).replace(".0", "")])
	odds.text = Kit.text("summon_odds", "Probabilidades") + ": " + "  \u00b7  ".join(parts)
	body.add_child(odds)
	_info = Label.new()
	_info.name = "Pity"
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.add_theme_color_override("font_color", Color("#ffc94d"))
	body.add_child(_info)
	_reveal = HFlowContainer.new()
	_reveal.name = "Reveal"
	_reveal.custom_minimum_size = Vector2(0.0, 300.0)
	_reveal.alignment = FlowContainer.ALIGNMENT_CENTER
	_reveal.add_theme_constant_override("h_separation", 8)
	_reveal.add_theme_constant_override("v_separation", 8)
	body.add_child(_reveal)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	body.add_child(row)
	_one = UI.make_button("x1  \u00b7  %d" % Heroes.COST_ONE, true, Store.currency_icon())
	_one.name = "BtnSummon1"
	_one.pressed.connect(func() -> void: _do(1))
	row.add_child(_one)
	_ten = UI.make_button("x10  \u00b7  %d" % Heroes.COST_TEN, true, Store.currency_icon())
	_ten.name = "BtnSummon10"
	_ten.pressed.connect(func() -> void: _do(10))
	row.add_child(_ten)
	var close_b: Button = UI.make_button(Kit.text("close", "Cerrar"), false, "close")
	close_b.name = "BtnClose"
	close_b.pressed.connect(func() -> void: close())
	body.add_child(close_b)
	_update()


func _update() -> void:
	_info.text = Kit.text("summon_pity", "Legendario seguro en {n} invocaciones").format({"n": Heroes.PITY - Heroes.pity()}) \
		+ "   \u00b7   " + "%d %s" % [Save.wallet(), Store.currency_name()]
	_one.disabled = Save.wallet() < Heroes.COST_ONE
	_ten.disabled = Save.wallet() < Heroes.COST_TEN


func _do(n: int) -> void:
	var res: Array = Heroes.summon(n, _rng)
	if res.is_empty():
		Audio.play("hurt", 0.0, -8.0)
		return
	for c: Node in _reveal.get_children():
		c.queue_free()
	var best: int = 0
	for i: int in res.size():
		var r: Dictionary = res[i]
		best = maxi(best, Heroes.RARITIES.find(str(r["rarity"])))
		_reveal.add_child(_tile(r, i))
	Audio.play("powerup" if best >= 2 else "coin")
	if best >= 3:
		Juice.confetti(self, get_viewport().get_visible_rect().size * 0.5, 60)
	changed.emit()
	_update()


func _tile(r: Dictionary, i: int) -> Control:
	var id: String = str(r["id"])
	var rc: Color = Color(str(Heroes.RARITY_COL.get(str(r["rarity"]), "#b0bec5")))
	var p: PanelContainer = PanelContainer.new()
	p.name = "Got_%d" % i
	p.custom_minimum_size = Vector2(108.0, 140.0)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = rc.darkened(0.6)
	sb.border_color = rc
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(12)
	p.add_theme_stylebox_override("panel", sb)
	var v: VBoxContainer = VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	var pic: Control = Control.new()
	pic.custom_minimum_size = Vector2(0.0, 84.0)
	v.add_child(pic)
	var fig: Node2D = Heroes.figure(id, 76.0)
	fig.position = Vector2(50.0, 82.0)
	pic.add_child(fig)
	var l: Label = Label.new()
	l.text = str(Heroes.hero(id).get("name", id)) + ("\n" + Kit.text("summon_new", "\u00a1Nuevo!") if bool(r["new"]) else "\n" + "\u2605".repeat(int(r["stars"])))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 15)
	v.add_child(l)
	## Aparecen uno detras de otro (la emocion de la invocacion).
	p.modulate.a = 0.0
	p.scale = Vector2(0.6, 0.6)
	var tw: Tween = p.create_tween()
	tw.tween_interval(0.08 * float(i))
	tw.tween_property(p, "modulate:a", 1.0, 0.18)
	tw.parallel().tween_property(p, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return p
