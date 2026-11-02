class_name ChestPanel
extends UiModal
## Ventana de un cofre: si esta listo, se abre con su animacion (tiembla, salta la tapa, luz y
## premios que salen volando); si no, ensena cuanto falta y deja acelerarlo con un anuncio o con
## monedas. El dibujo del cofre (draw_chest) lo usan tambien los huecos de la pantalla principal.

signal opened(reward: Dictionary)

var index: int = -1
var _art: Control
var _phase: float = 0.0
var _lid: float = 0.0
var _shake: float = 0.0
var _glow: float = 0.0
var _info: Label
var _type: String = "madera"


static func open_slot(host: Node, i: int) -> ChestPanel:
	var p: ChestPanel = ChestPanel.new()
	p.name = "ChestPanel"
	p.index = i
	host.add_child(p)
	return p


func _ready() -> void:
	var s: Array = Chests.slots()
	_type = str(s[index]["type"]) if index >= 0 and index < s.size() else "madera"
	build_frame(Kit.text("chest_" + _type, chest_name(_type)), 560.0)
	_art = Control.new()
	_art.name = "ChestArt"
	_art.custom_minimum_size = Vector2(0, 300)
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.draw.connect(_draw_art)
	body.add_child(_art)
	_info = Label.new()
	_info.name = "ChestInfo"
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_info)
	_build_buttons()


func _build_buttons() -> void:
	for c: Node in body.get_children():
		if c is Button or c is HBoxContainer:
			c.queue_free()
	if Chests.ready(index):
		_info.text = Kit.text("chest_ready", "\u00a1Listo para abrir!")
		var op: Button = UI.make_button(Kit.text("chest_open", "Abrir"), true, "star")
		op.name = "BtnOpenChest"
		op.pressed.connect(_open)
		body.add_child(op)
	else:
		var left: int = Chests.seconds_left(index)
		var unlocking: bool = Chests.unlocking() == index
		_info.text = (Kit.text("chest_left", "Se abre en %s") % Chests.fmt_time(left)) if unlocking else \
			(Kit.text("chest_takes", "Tarda %s en abrirse") % Chests.fmt_time(left))
		if not unlocking and Chests.unlocking() < 0:
			var st: Button = UI.make_button(Kit.text("chest_start", "Empezar a abrir"), true, "play")
			st.name = "BtnStartChest"
			st.pressed.connect(func() -> void:
				Chests.start(index)
				Audio.play("ui_big", 0.05, -4.0)
				_build_buttons())
			body.add_child(st)
		if Ads.rewarded_available():
			var ad: Button = UI.make_button(Kit.text("chest_ad", "-30 min con un anuncio"), false, "play")
			ad.name = "BtnChestAd"
			ad.pressed.connect(_ad)
			body.add_child(ad)
		var cost: int = Chests.skip_cost(index)
		var now_b: Button = UI.make_button(Kit.text("chest_now", "Abrir ya") + "  %d" % cost, false, "coin")
		now_b.name = "BtnChestNow"
		now_b.disabled = Save.wallet() < cost
		now_b.pressed.connect(func() -> void:
			if Chests.speed_up(index, false):
				Audio.play("ui_coin", 0.05, -6.0)
				_build_buttons())
		body.add_child(now_b)
	var close_b: Button = UI.make_button(Kit.text("close", "Cerrar"), false, "close")
	close_b.name = "BtnCloseChest"
	close_b.pressed.connect(close)
	body.add_child(close_b)


func _ad() -> void:
	var done: Callable = func(placement: String) -> void:
		if placement == "chest":
			Chests.speed_up(index, true)
			_build_buttons()
	Ads.reward_earned.connect(done, CONNECT_ONE_SHOT)
	Ads.show_rewarded("chest")


## La apertura: tiembla, salta la tapa con luz, y salen las monedas (y el aspecto si toca).
func _open() -> void:
	for c: Node in body.get_children():
		if c is Button:
			(c as Button).disabled = true
	var tw: Tween = create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_method(_set_shake, 0.0, 1.0, 0.7)
	await tw.finished
	var r: Dictionary = Chests.open(index)
	if r.is_empty():
		close()
		return
	_shake = 0.0
	Audio.play("ui_reward", 0.0, -2.0)
	Audio.play("powerup", 0.05, -8.0)
	Juice.vibrate(60)
	Juice.burst(root, _art.get_global_rect().get_center(), type_color(_type), 36)
	var tw2: Tween = create_tween()
	tw2.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw2.tween_method(_set_lid, 0.0, 1.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw2.finished
	_info.text = "+%d " % int(r["coins"]) + Kit.text("coins_word", "monedas")
	UI.pop_in(_info)
	var size: Vector2 = root.get_viewport().get_visible_rect().size
	UI.fly_coins(root, _art.get_global_rect().get_center(), Vector2(size.x - 140.0, 60.0), int(r["coins"]))
	if str(r["skin"]) != "":
		var sk: Label = Label.new()
		sk.name = "ChestSkin"
		sk.text = Kit.text("chest_skin", "\u00a1Aspecto nuevo: %s!") % Skins.display_name(Skins.find(str(r["skin"])))
		sk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sk.add_theme_color_override("font_color", UI.colors["acento"])
		body.add_child(sk)
		body.move_child(sk, _info.get_index() + 1)
		UI.pop_in(sk, 0.3)
	opened.emit(r)
	for c2: Node in body.get_children():
		if c2 is Button and c2.name == "BtnCloseChest":
			(c2 as Button).disabled = false


func _set_shake(v: float) -> void:
	## Tiembla cada vez mas y suena un tic en cada sacudida.
	if int(v * 8.0) != int(_shake * 8.0):
		Audio.play("ui_tick", 0.3, -8.0, 0.8 + v * 0.6)
	_shake = v


func _set_lid(v: float) -> void:
	_lid = v
	_glow = v


static func type_color(t: String) -> Color:
	return Chests.TYPES.get(t, Chests.TYPES["madera"])["color"]


static func chest_name(t: String) -> String:
	return {"madera": "Cofre de madera", "plata": "Cofre de plata", "oro": "Cofre de oro", "magico": "Cofre m\u00e1gico"}.get(t, t)


func _process(delta: float) -> void:
	_phase += delta
	if _art != null:
		_art.queue_redraw()


func _draw_art() -> void:
	var c: Vector2 = _art.size * 0.5 + Vector2(0, 30)
	var col: Color = type_color(_type)
	## Rayos de luz detras (mas fuertes al abrir).
	for k: int in 12:
		var a: float = _phase * 0.4 + TAU * float(k) / 12.0
		var g: Color = col.lightened(0.3)
		g.a = 0.08 + 0.25 * _glow
		_art.draw_colored_polygon(PackedVector2Array([c, c + Vector2.from_angle(a) * 260.0, c + Vector2.from_angle(a + 0.14) * 260.0]), g)
	var jitter: Vector2 = Vector2(sin(_phase * 60.0) * 8.0, cos(_phase * 47.0) * 3.0) * _shake
	var bob: float = 0.0 if _lid > 0.0 else sin(_phase * 3.0) * 6.0
	draw_chest(_art, Rect2(c + jitter + Vector2(-110, -80 + bob), Vector2(220, 170)), col, _lid)


## Dibuja un cofre en cualquier CanvasItem (huecos de la pantalla principal y esta ventana).
## lid: 0 cerrado, 1 tapa abierta con luz.
static func draw_chest(ci: CanvasItem, r: Rect2, col: Color, lid: float = 0.0) -> void:
	var dark: Color = col.darkened(0.45)
	var body_r: Rect2 = Rect2(r.position + Vector2(0, r.size.y * 0.38), Vector2(r.size.x, r.size.y * 0.62))
	ci.draw_rect(Rect2(body_r.position + Vector2(0, body_r.size.y - 8.0), Vector2(body_r.size.x, 12.0)), Color(0, 0, 0, 0.25))
	ci.draw_rect(body_r, col)
	ci.draw_rect(Rect2(body_r.position, Vector2(body_r.size.x, body_r.size.y * 0.18)), col.lightened(0.2))
	ci.draw_rect(body_r, dark, false, 5.0)
	## Bandas metalicas y cerradura.
	var band: Color = Color("#ffd54a") if col.v < 0.95 else Color("#8a6a2a")
	ci.draw_rect(Rect2(body_r.position + Vector2(body_r.size.x * 0.14, 0), Vector2(body_r.size.x * 0.1, body_r.size.y)), band)
	ci.draw_rect(Rect2(body_r.position + Vector2(body_r.size.x * 0.76, 0), Vector2(body_r.size.x * 0.1, body_r.size.y)), band)
	if lid > 0.0:
		var glow: Color = Color(1, 0.95, 0.6, 0.85 * lid)
		ci.draw_rect(Rect2(body_r.position + Vector2(8, -10), Vector2(body_r.size.x - 16, 18)), glow)
	## Tapa: sube y se inclina al abrir.
	var lid_r: Rect2 = Rect2(r.position + Vector2(-4, r.size.y * 0.06 - lid * r.size.y * 0.45), Vector2(r.size.x + 8, r.size.y * 0.36))
	ci.draw_set_transform(lid_r.position + Vector2(0, lid_r.size.y), -0.5 * lid, Vector2.ONE)
	var lr: Rect2 = Rect2(Vector2(0, -lid_r.size.y), lid_r.size)
	ci.draw_rect(lr, col.lightened(0.08))
	ci.draw_rect(Rect2(lr.position, Vector2(lr.size.x, lr.size.y * 0.3)), col.lightened(0.3))
	ci.draw_rect(lr, dark, false, 5.0)
	ci.draw_rect(Rect2(lr.position + Vector2(lr.size.x * 0.14, 0), Vector2(lr.size.x * 0.1, lr.size.y)), band)
	ci.draw_rect(Rect2(lr.position + Vector2(lr.size.x * 0.76, 0), Vector2(lr.size.x * 0.1, lr.size.y)), band)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if lid <= 0.0:
		var lock: Vector2 = Vector2(r.get_center().x, body_r.position.y + 6.0)
		ci.draw_rect(Rect2(lock - Vector2(14, 4), Vector2(28, 30)), band.darkened(0.2))
		ci.draw_circle(lock + Vector2(0, 8), 5.0, dark)
