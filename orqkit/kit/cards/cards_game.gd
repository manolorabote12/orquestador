extends Node2D
## Cartas (solitario Golf): limpia la mesa jugando cartas una arriba o una abajo.
## 1 - Toca la carta de abajo de una columna: si es una mas o una menos que la del monton (la K y
##     el A se tocan), pasa al monton. Cada carta jugada seguida suma combo.
## 2 - Sin jugada, toca el mazo: su siguiente carta pasa al monton.
## 3 - Ganas al limpiar la mesa; pierdes si se acaba el mazo y no queda jugada.
## Mapa y reglas: kit/cards/cards_logic.gd. Nivel: {"map"}.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const CW: float = 118.0
const CH: float = 166.0
const GAP: float = 10.0
const STEP_Y: float = 54.0
const SUITS: int = 4

var rows: Array = []
var finished: bool = false
var failed: bool = false
var deaths: int = 0
var time_in_level: float = 0.0
var coins: int = 0
var coins_total: int = 0
var fast: bool = false
var auto_retry: bool = false
var result_panel: ResultPanel

## Mesa: columnas de {"rank", "suit", "node"}; mazo: rangos por sacar; monton: la de arriba.
var cols: Array = []
var stock: Array[int] = []
var next_stock: int = 1
var top: int = 1
var top_suit: int = 0
var combo: int = 0
var best_combo: int = 0
var plays: int = 0
var score: int = 0

var _deal: Dictionary = {}
var _table: Node2D
var _waste: Node2D
var _stock_node: Node2D
var _camera: Camera2D
var _left_label: Label
var _stock_label: Label
var _accent: Color


func _ready() -> void:
	var lv: Dictionary = Kit.current_level()
	rows = lv.get("map", [])
	_deal = CardsLogic.parse(rows)
	_accent = Kit.color("accent", Color("#ffb14a"))
	RenderingServer.set_default_clear_color(Color("#1f5a3a").lerp(Kit.color("sky", Color("#1b2a41")), 0.35))
	var felt: Node2D = Node2D.new()
	felt.name = "Felt"
	felt.draw.connect(func() -> void:
		var w: float = _table_width()
		felt.draw_rect(Rect2(Vector2(-60.0, -80.0), Vector2(w + 120.0, 1500.0)), Color(0, 0, 0, 0.12))
		felt.draw_rect(Rect2(Vector2(-60.0, -80.0), Vector2(w + 120.0, 1500.0)), Color(1, 1, 1, 0.08), false, 4.0))
	add_child(felt)
	_table = Node2D.new()
	_table.name = "Table"
	add_child(_table)
	_waste = Node2D.new()
	_waste.name = "Waste"
	add_child(_waste)
	_stock_node = Node2D.new()
	_stock_node.name = "Stock"
	add_child(_stock_node)
	_camera = Camera2D.new()
	add_child(_camera)
	_camera.make_current()
	Juice.register_camera(_camera)
	var vp: Vector2 = get_viewport_rect().size
	_camera.zoom = Vector2.ONE * minf(vp.x / (_table_width() + 80.0), 1.5)
	_camera.position = Vector2(_table_width() * 0.5, 560.0)
	_build_hud()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "cards", "cards": cards_left(), "stock": stock.size()})


func bot_script() -> String:
	return "res://qa/cards_bot.gd"


func _table_width() -> float:
	var n: int = maxi((_deal.get("cols", []) as Array).size(), 7)
	return float(n) * (CW + GAP) - GAP


func _build_hud() -> void:
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
	var top_row: HBoxContainer = HBoxContainer.new()
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_theme_constant_override("separation", 12)
	col.add_child(top_row)
	_left_label = Label.new()
	_left_label.name = "Left"
	_left_label.theme_type_variation = "HeaderLabel"
	_left_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(_left_label)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top_row.add_child(pause_btn)
	var grow: Control = Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(grow)
	_stock_label = Label.new()
	_stock_label.name = "StockLeft"
	_stock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stock_label.add_theme_color_override("font_color", UI.colors["texto_suave"])
	col.add_child(_stock_label)
	var hint: Label = Label.new()
	hint.name = "Hint"
	hint.text = Kit.text("cards_hint", "Juega una carta m\u00e1s o una menos que la del mont\u00f3n")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", UI.colors["texto_suave"])
	col.add_child(hint)


func _reset() -> void:
	finished = false
	failed = false
	time_in_level = 0.0
	combo = 0
	best_combo = 0
	plays = 0
	score = 0
	coins = 0
	for n: Node in _table.get_children() + _waste.get_children() + _stock_node.get_children():
		n.queue_free()
	cols.clear()
	stock.clear()
	if _deal.is_empty():
		return
	for x: int in (_deal["cols"] as Array).size():
		var c: Array = []
		var src: Array = _deal["cols"][x]
		for y: int in src.size():
			var card: Dictionary = {"rank": int(src[y]), "suit": (x * 3 + y) % SUITS}
			card["node"] = _card_node(card, Vector2(float(x) * (CW + GAP) + CW * 0.5, float(y) * STEP_Y + CH * 0.5), _table)
			c.append(card)
		cols.append(c)
	for k: Variant in _deal["stock"]:
		stock.append(int(k))
	top = stock[0]
	top_suit = 1
	next_stock = 1
	coins_total = 3
	_redraw_piles()
	_update_hud()


func cards_left() -> int:
	var n: int = 0
	for c: Variant in cols:
		n += (c as Array).size()
	return n


func stock_left() -> int:
	return stock.size() - next_stock


func playable(col: int) -> bool:
	if col < 0 or col >= cols.size() or (cols[col] as Array).is_empty():
		return false
	return CardsLogic.adjacent(int(((cols[col] as Array).back() as Dictionary)["rank"]), top)


func any_move() -> bool:
	for i: int in cols.size():
		if playable(i):
			return true
	return false


## Juega la carta de abajo de la columna. Devuelve true si se pudo.
func play(col: int) -> bool:
	if finished or failed or get_tree().paused or not playable(col):
		if col >= 0 and col < cols.size() and not (cols[col] as Array).is_empty() and not finished and not failed:
			Juice.shake(0.08)
			Audio.play("land", 0.1, -8.0)
		return false
	var card: Dictionary = (cols[col] as Array).pop_back()
	top = int(card["rank"])
	top_suit = int(card["suit"])
	plays += 1
	combo += 1
	best_combo = maxi(best_combo, combo)
	score += 100 * combo
	var node: Node2D = card["node"]
	var dest: Vector2 = _waste_pos()
	node.z_index = 50
	var tw: Tween = node.create_tween()
	tw.tween_property(node, "position", dest, 0.18 * (0.3 if fast else 1.0)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		node.queue_free()
		_redraw_piles())
	if combo >= 3:
		UI.float_text(self, dest + Vector2(0, -CH * 0.7), Kit.text("cards_combo", "Combo x{n}").format({"n": combo}), Color("#ffe066"), 30)
	Audio.play("coin", 0.0, -6.0, 1.0 + 0.05 * float(mini(combo, 10)))
	_update_hud()
	if cards_left() == 0:
		_finish()
	elif not any_move() and stock_left() <= 0:
		_lose()
	return true


## Da la vuelta a la siguiente carta del mazo.
func draw_stock() -> bool:
	if finished or failed or get_tree().paused or stock_left() <= 0:
		return false
	top = stock[next_stock]
	top_suit = (next_stock * 7) % SUITS
	next_stock += 1
	combo = 0
	Audio.play("jump", 0.05, -8.0)
	_redraw_piles()
	_update_hud()
	if not any_move() and stock_left() <= 0:
		_lose()
	return true


func _waste_pos() -> Vector2:
	return Vector2(_table_width() * 0.5 + CW * 0.7, 5.0 * STEP_Y + CH * 2.6)


func _stock_pos() -> Vector2:
	return Vector2(_table_width() * 0.5 - CW * 0.9, 5.0 * STEP_Y + CH * 2.6)


func _redraw_piles() -> void:
	for n: Node in _waste.get_children() + _stock_node.get_children():
		n.queue_free()
	_card_node({"rank": top, "suit": top_suit}, _waste_pos(), _waste)
	var left: int = stock_left()
	for k: int in mini(left, 4):
		_card_node({"back": true}, _stock_pos() + Vector2(-3.0 * float(k), -3.0 * float(k)), _stock_node)


func _refresh_glow() -> void:
	for i: int in cols.size():
		var c: Array = cols[i]
		for k: int in c.size():
			var node: Node2D = (c[k] as Dictionary)["node"]
			var g: bool = k == c.size() - 1 and playable(i)
			if bool(node.get_meta("glow", false)) != g:
				node.set_meta("glow", g)
				node.queue_redraw()


func _update_hud() -> void:
	_refresh_glow()
	_left_label.text = Kit.text("cards_left", "Quedan {n} cartas").format({"n": cards_left()})
	_stock_label.text = Kit.text("cards_stock", "Mazo: {n}").format({"n": stock_left()})
	## Estrellas en juego: monedas = estrellas que llevas asegurado (por cartas de mazo de sobra).
	coins = stars_for(stock_left()) if cards_left() == 0 else 0


func column_at(world: Vector2) -> int:
	if world.distance_to(_stock_pos()) < CW * 0.7:
		return -1
	var x: int = int(floor(world.x / (CW + GAP)))
	if x < 0 or x >= cols.size():
		return -2
	if world.y < -20.0 or world.y > float((cols[x] as Array).size()) * STEP_Y + CH:
		return -2
	return x


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()
		return
	if UI.test_mode:
		return
	var at: Vector2 = Vector2.INF
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		at = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and not DisplayServer.is_touchscreen_available():
		at = (event as InputEventMouseButton).position
	if at == Vector2.INF:
		return
	var c: int = column_at(get_canvas_transform().affine_inverse() * at)
	if c == -1:
		draw_stock()
	elif c >= 0:
		play(c)


func _process(delta: float) -> void:
	if not finished and not failed and not get_tree().paused:
		time_in_level += delta


# ------------------------------------------------------------------ dibujo de cartas

func _card_node(card: Dictionary, at: Vector2, parent: Node2D) -> Node2D:
	var n: Node2D = Node2D.new()
	n.position = at
	var back: bool = bool(card.get("back", false))
	var rank: int = int(card.get("rank", 1))
	var suit: int = int(card.get("suit", 0))
	n.draw.connect(func() -> void:
		var r: Rect2 = Rect2(Vector2(-CW, -CH) * 0.5, Vector2(CW, CH))
		var shadow: StyleBoxFlat = StyleBoxFlat.new()
		shadow.bg_color = Color(0, 0, 0, 0.3)
		shadow.set_corner_radius_all(12)
		n.draw_style_box(shadow, Rect2(r.position + Vector2(0, 5), r.size))
		var face: StyleBoxFlat = StyleBoxFlat.new()
		face.set_corner_radius_all(12)
		face.set_border_width_all(3)
		if back:
			face.bg_color = _accent.darkened(0.25)
			face.border_color = Color(1, 1, 1, 0.85)
			n.draw_style_box(face, r)
			for k: int in 3:
				n.draw_rect(Rect2(r.position + Vector2(14, 14) + Vector2(k, k) * 10.0, r.size - Vector2(28, 28) - Vector2(k, k) * 20.0), Color(1, 1, 1, 0.25), false, 3.0)
			return
		face.bg_color = Color("#fbf7ee")
		face.border_color = Color("#d8cfbf")
		## Carta que se puede jugar ahora: borde del color del juego.
		if bool(n.get_meta("glow", false)):
			face.border_color = Color("#ffd447")
			face.set_border_width_all(6)
		n.draw_style_box(face, r)
		var red: bool = suit == 1 or suit == 2
		var ink: Color = Color("#c8323c") if red else Color("#1e2433")
		var txt: String = "10" if rank == 10 else CardsLogic.rank_char(rank)
		n.draw_string(UI.font, r.position + Vector2(12, 40), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, ink)
		_draw_suit(n, suit, Vector2(0, 16), 30.0, ink)
		_draw_suit(n, suit, r.position + Vector2(CW - 26, 30), 13.0, ink))
	parent.add_child(n)
	return n


static func _draw_suit(n: Node2D, suit: int, c: Vector2, s: float, ink: Color) -> void:
	match suit:
		1:
			## Corazon
			n.draw_circle(c + Vector2(-s * 0.45, -s * 0.2), s * 0.5, ink)
			n.draw_circle(c + Vector2(s * 0.45, -s * 0.2), s * 0.5, ink)
			n.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.93, -s * 0.05), c + Vector2(s * 0.93, -s * 0.05), c + Vector2(0, s * 0.95)]), ink)
		2:
			## Diamante
			n.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.7, 0), c + Vector2(0, s), c + Vector2(-s * 0.7, 0)]), ink)
		3:
			## Trebol
			n.draw_circle(c + Vector2(0, -s * 0.45), s * 0.42, ink)
			n.draw_circle(c + Vector2(-s * 0.45, s * 0.1), s * 0.42, ink)
			n.draw_circle(c + Vector2(s * 0.45, s * 0.1), s * 0.42, ink)
			n.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.15, 0), c + Vector2(s * 0.15, 0), c + Vector2(s * 0.3, s), c + Vector2(-s * 0.3, s)]), ink)
		_:
			## Pica
			n.draw_circle(c + Vector2(-s * 0.42, s * 0.15), s * 0.45, ink)
			n.draw_circle(c + Vector2(s * 0.42, s * 0.15), s * 0.45, ink)
			n.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.85, s * 0.05), c + Vector2(s * 0.85, s * 0.05), c + Vector2(0, -s * 0.95)]), ink)
			n.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.12, s * 0.2), c + Vector2(s * 0.12, s * 0.2), c + Vector2(s * 0.3, s), c + Vector2(-s * 0.3, s)]), ink)


# ------------------------------------------------------------------ final

## Estrellas segun las cartas de mazo que sobran: 3 con 5 o mas, 2 con 2 o mas, 1 por limpiar.
static func stars_for(left: int) -> int:
	if left >= 5:
		return 3
	if left >= 2:
		return 2
	return 1


func stars_earned() -> int:
	return stars_for(stock_left())


func _finish() -> void:
	finished = true
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	coins = stars
	score += stock_left() * 250
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stock_left": stock_left(), "combo": best_combo, "coins": coins, "stars": stars})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


func _lose() -> void:
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "no_moves", "left": cards_left(), "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("cards_stuck", "\u00a1Sin jugadas!"),
		Kit.text("cards_fail_hint", "Quedaban {n} cartas. Piensa antes de tirar del mazo. \u00a1Otra vez!").format({"n": cards_left()}))
	p.closed.connect(retry)


func retry() -> void:
	_reset()


func open_pause() -> void:
	if finished or get_tree().paused or get_node_or_null("PauseMenu") != null:
		return
	PauseMenu.open(self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_inside_tree() and not UI.test_mode:
			open_pause()


func bot_state() -> Dictionary:
	return {"deaths": deaths, "coins": coins, "finished": finished, "failed": failed, "stomps": 0,
		"left": cards_left(), "stock_left": stock_left(), "plays": plays}


func capture_delays() -> Vector2:
	return Vector2(3.0, 1.0)
