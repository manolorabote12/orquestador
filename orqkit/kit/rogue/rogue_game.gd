extends Node2D
## Arquero: arena vista desde arriba. Arrastra para mover al heroe (un joystick aparece donde tocas);
## al soltar se queda quieto y dispara solo al enemigo mas cercano. Al limpiar una sala, elige 1 de 3
## habilidades. Reglas, bot y analizador en rogue_map.gd.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel al acabar.

const M = preload("res://kit/rogue/rogue_map.gd")
const SIM_DT: float = 1.0 / 60.0
## Con prisa (bots) se juega con el paso del analizador: el mismo resultado que comprobo.
const BOT_DT: float = 1.0 / 30.0
const SKILL_TEXT: Dictionary = {
	"doble": ["Flecha doble", "Una flecha m\u00e1s de frente"], "rapido": ["Tiro r\u00e1pido", "Dispara un 25 % m\u00e1s deprisa"],
	"fuerza": ["Fuerza", "Cada flecha hace un 30 % m\u00e1s de da\u00f1o"], "diagonal": ["Flechas en diagonal", "Dos flechas m\u00e1s, en \u00e1ngulo"],
	"vida": ["M\u00e1s vida", "+25 de vida m\u00e1xima y curas 45"], "escudo": ["Escudo", "Recibes un 20 % menos de da\u00f1o"],
}

var level: Dictionary = {}
var st: Dictionary = {}
var finished: bool = false
var failed: bool = false
var deaths: int = 0
var time_in_level: float = 0.0
var coins: int = 0
var coins_total: int = 0
var fast: bool = false
var auto_retry: bool = false
var result_panel: ResultPanel

var _view: Control
var _info: Label
var _hp_bar: ProgressBar
var _hero_spr: AnimatedSprite2D
var _hero_base: Vector2 = Vector2.ONE
var _pick_layer: Control
var _touch_origin: Vector2 = Vector2.INF
var _touch_dir: Vector2 = Vector2.ZERO
var _acc: float = 0.0
var _anim_t: float = 0.0
var _tile: Texture2D


func _ready() -> void:
	level = Kit.current_level()
	RenderingServer.set_default_clear_color(Color("#141821"))
	_tile = Kit.first_tile_texture()
	_build_hud()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "rogue", "rooms": (level.get("rooms", []) as Array).size()})


func bot_script() -> String:
	return "res://qa/rogue_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(2.5, 1.6)


func _reset() -> void:
	finished = false
	failed = false
	st = M.new_state(level)
	coins_total = 0
	for r: Variant in st["rooms"]:
		coins_total += ((r as Dictionary).get("enemies", []) as Array).size()
	coins = 0
	time_in_level = 0.0
	_acc = 0.0
	_touch_origin = Vector2.INF
	_touch_dir = Vector2.ZERO
	if _pick_layer != null:
		_pick_layer.visible = false
	_refresh()


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
	var safe: MarginContainer = UI.safe_root(root, 14.0)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col: VBoxContainer = VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 8)
	safe.add_child(col)
	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top)
	var left: VBoxContainer = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(left)
	_info = Label.new()
	_info.name = "Info"
	_info.clip_text = true
	_info.add_theme_font_size_override("font_size", 26)
	left.add_child(_info)
	_hp_bar = ProgressBar.new()
	_hp_bar.name = "Hp"
	_hp_bar.show_percentage = false
	_hp_bar.custom_minimum_size = Vector2(0, 18)
	left.add_child(_hp_bar)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)
	_view = Control.new()
	_view.name = "View"
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.clip_contents = true
	_view.draw.connect(_draw_view)
	_view.gui_input.connect(_on_input)
	col.add_child(_view)
	var art: Dictionary = Kit.sprite_by_role("jugador")
	if not art.is_empty():
		var anims: Dictionary = art.get("animaciones", {})
		_hero_spr = SpriteKit.animado(art, 64.0, "idle" if anims.has("idle") else "run", false)
		Skins.apply(_hero_spr)
		_hero_base = _hero_spr.scale
		_view.add_child(_hero_spr)
	_pick_layer = _build_pick(root)


## Panel de elegir habilidad (3 botones que se rellenan al limpiar cada sala).
func _build_pick(root: Control) -> Control:
	var shade: ColorRect = ColorRect.new()
	shade.name = "Pick"
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.visible = false
	root.add_child(shade)
	var box: VBoxContainer = VBoxContainer.new()
	box.name = "Box"
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(560, 0)
	box.position = Vector2(-280, -260)
	box.add_theme_constant_override("separation", 16)
	shade.add_child(box)
	var title: Label = Label.new()
	title.name = "Title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	box.add_child(title)
	for k: int in 3:
		var b: Button = UI.make_button("", k == 0)
		b.name = "Skill%d" % k
		b.custom_minimum_size = Vector2(560, 120)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(_on_pick.bind(k))
		box.add_child(b)
	return shade


func _show_pick() -> void:
	var box: Node = _pick_layer.get_node("Box")
	(box.get_node("Title") as Label).text = Kit.text("rg_pick", "Elige una habilidad")
	var offer: Array = st["offer"]
	for k: int in 3:
		var b: Button = box.get_node("Skill%d" % k)
		var s: String = str(offer[k]) if k < offer.size() else ""
		b.visible = s != ""
		var tx: Array = SKILL_TEXT.get(s, [s, ""])
		b.text = Kit.text("rg_" + s, str(tx[0])) + "\n" + Kit.text("rg_" + s + "_d", str(tx[1]))
	_pick_layer.visible = true


func _on_pick(k: int) -> void:
	var offer: Array = st["offer"]
	if k < offer.size():
		choose_skill(str(offer[k]))


func choose_skill(s: String) -> bool:
	if M.pick(st, s):
		_pick_layer.visible = false
		_sfx("powerup", -6.0)
		_refresh()
		return true
	return false


func can_act() -> bool:
	return not finished and not failed and is_inside_tree() and not get_tree().paused and not st.is_empty()


func _on_input(event: InputEvent) -> void:
	var touch: bool = DisplayServer.is_touchscreen_available()
	var state: int = 0
	var pos: Vector2 = Vector2.ZERO
	if event is InputEventScreenTouch:
		state = 1 if (event as InputEventScreenTouch).pressed else -1
		pos = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton and not touch and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		state = 1 if (event as InputEventMouseButton).pressed else -1
		pos = (event as InputEventMouseButton).position
	elif event is InputEventScreenDrag:
		state = 2
		pos = (event as InputEventScreenDrag).position
	elif event is InputEventMouseMotion and not touch:
		state = 2
		pos = (event as InputEventMouseMotion).position
	if state == 1:
		_touch_origin = pos
		_touch_dir = Vector2.ZERO
	elif state == -1:
		_touch_origin = Vector2.INF
		_touch_dir = Vector2.ZERO
	elif state == 2 and _touch_origin != Vector2.INF:
		var d: Vector2 = pos - _touch_origin
		_touch_dir = d / 70.0 if d.length() > 10.0 else Vector2.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()


func _sfx(n: String, vol: float = -6.0) -> void:
	if not fast:
		Audio.play(n, 0.1, vol)


func _refresh() -> void:
	if st.is_empty() or _info == null:
		return
	_info.text = Kit.text("rg_room", "Sala {a}/{b}").format({"a": int(st["room"]) + 1, "b": (st["rooms"] as Array).size()})
	_hp_bar.max_value = float(st["hero"]["max_hp"])
	_hp_bar.value = float(st["hero"]["hp"])


func _physics_process(delta: float) -> void:
	if st.is_empty() or get_tree().paused:
		return
	_anim_t += delta
	if finished or failed:
		_view.queue_redraw()
		return
	time_in_level += delta
	if str(st["phase"]) == "pick":
		if fast and auto_retry:
			choose_skill(M.bot_pick(st))
		elif not _pick_layer.visible:
			_show_pick()
		_view.queue_redraw()
		return
	var hp0: float = float(st["hero"]["hp"])
	var kills0: int = int(st["kills"])
	var ndt: float = BOT_DT if fast else SIM_DT
	_acc += delta
	var guard: int = 0
	while _acc >= ndt and str(st["phase"]) == "fight" and guard < 8:
		guard += 1
		_acc -= ndt
		var move: Vector2 = M.bot_move(st) if fast and auto_retry else _player_move()
		M.step(st, ndt, move)
	if int(st["kills"]) > kills0:
		coins = int(st["kills"])
		_sfx("stomp", -6.0)
	if float(st["hero"]["hp"]) < hp0:
		_sfx("hurt", -8.0)
		Juice.vibrate(20)
	_refresh()
	if bool(st["lost"]):
		_lose()
	elif bool(st["won"]):
		_finish()
	_view.queue_redraw()


func _player_move() -> Vector2:
	var k: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if k.length() > 0.1:
		return k
	return _touch_dir.limit_length(1.0)


# ------------------------------------------------------------------ dibujo

func _arena() -> Rect2:
	var sz: Vector2 = _view.size
	var s: float = minf(sz.x / M.ARENA.x, sz.y / M.ARENA.y)
	var a: Vector2 = M.ARENA * s
	return Rect2((sz - a) * 0.5, a)


func _to_view(p: Vector2) -> Vector2:
	var r: Rect2 = _arena()
	return r.position + p / M.ARENA * r.size


func _draw_view() -> void:
	if st.is_empty():
		return
	var r: Rect2 = _arena()
	var u: float = r.size.x / M.ARENA.x
	_view.draw_rect(r, Color("#3b4a3f"))
	if _tile != null:
		_view.draw_texture_rect(_tile, r, true, Color(1, 1, 1, 0.35))
	for y: int in int(M.ARENA.y):
		for x: int in int(M.ARENA.x):
			if (x + y) % 2 == 0:
				_view.draw_rect(Rect2(r.position + Vector2(x, y) * u, Vector2(u, u)), Color(1, 1, 1, 0.04))
	var open: bool = (st["enemies"] as Array).is_empty()
	_view.draw_rect(Rect2(r.position + Vector2(M.ARENA.x * 0.5 - 1.0, -0.15) * u, Vector2(2.0, 0.3) * u), Color("#7bed9f") if open else Color("#57606f"))
	_view.draw_rect(r, Color("#0b0e14"), false, 6.0)
	for a: Variant in st["arrows"]:
		var ap: Vector2 = _to_view(a["p"])
		var av: Vector2 = (a["v"] as Vector2).normalized()
		_view.draw_line(ap - av * u * 0.45, ap, Color("#f1f2f6"), 4.0)
	for e: Variant in st["enemies"]:
		var info: Dictionary = M.KINDS[e["k"]]
		var ep: Vector2 = _to_view(e["p"])
		var er: float = float(info["r"]) * u
		var col: Color = {"slime": Color("#2ed573"), "bat": Color("#a55eea"), "archer": Color("#ff7f50"), "boss": Color("#ff4757")}.get(str(e["k"]), Color.WHITE)
		if float(e["hit"]) > 0.0:
			col = Color.WHITE
		match str(e["k"]):
			"bat":
				var flap: float = sin(_anim_t * 18.0) * er * 0.5
				_view.draw_colored_polygon(PackedVector2Array([ep, ep + Vector2(-er * 1.6, -er * 0.4 + flap), ep + Vector2(-er * 0.6, er * 0.4)]), col.darkened(0.2))
				_view.draw_colored_polygon(PackedVector2Array([ep, ep + Vector2(er * 1.6, -er * 0.4 + flap), ep + Vector2(er * 0.6, er * 0.4)]), col.darkened(0.2))
				_view.draw_circle(ep, er * 0.7, col)
			"archer":
				_view.draw_rect(Rect2(ep - Vector2(er, er), Vector2(er, er) * 2.0), col)
				_view.draw_arc(ep + Vector2(er * 0.9, 0), er * 0.8, -1.2, 1.2, 10, Color("#8e5a3c"), 3.0)
			_:
				_view.draw_circle(ep + Vector2(0, er * 0.15), er, col.darkened(0.25))
				_view.draw_circle(ep, er, col)
		_view.draw_circle(ep + Vector2(-er * 0.35, -er * 0.15), er * 0.18, Color.WHITE)
		_view.draw_circle(ep + Vector2(er * 0.35, -er * 0.15), er * 0.18, Color.WHITE)
		_view.draw_circle(ep + Vector2(-er * 0.35, -er * 0.12), er * 0.08, Color.BLACK)
		_view.draw_circle(ep + Vector2(er * 0.35, -er * 0.12), er * 0.08, Color.BLACK)
		if float(e["hp"]) < float(e["max"]):
			var w: float = er * 2.0
			_view.draw_rect(Rect2(ep + Vector2(-er, -er - 12.0), Vector2(w, 6.0)), Color(0, 0, 0, 0.6))
			_view.draw_rect(Rect2(ep + Vector2(-er, -er - 12.0), Vector2(w * float(e["hp"]) / float(e["max"]), 6.0)), Color("#ff6b81"))
	for b: Variant in st["bullets"]:
		var bp: Vector2 = _to_view(b["p"])
		_view.draw_circle(bp, u * 0.16, Color("#ff4757"))
		_view.draw_circle(bp, u * 0.08, Color("#ffeaa7"))
	var hero: Dictionary = st["hero"]
	var hpv: Vector2 = _to_view(hero["p"])
	var blink: bool = float(hero["inv"]) > 0.0 and int(_anim_t * 20.0) % 2 == 0
	if _hero_spr != null:
		_hero_spr.position = hpv
		_hero_spr.visible = not blink
		_hero_spr.scale = _hero_base * (u * 1.4 / 64.0)
	elif not blink:
		_view.draw_circle(hpv, M.HERO_R * u, Color("#70a1ff"))
	_view.draw_arc(hpv + Vector2(0, M.HERO_R * u * 0.9), M.HERO_R * u, 0.0, TAU, 20, Color(0, 0, 0, 0.3), 3.0)
	if _touch_origin != Vector2.INF:
		_view.draw_arc(_touch_origin, 70.0, 0.0, TAU, 32, Color(1, 1, 1, 0.35), 4.0)
		_view.draw_circle(_touch_origin + _touch_dir.limit_length(1.0) * 70.0, 26.0, Color(1, 1, 1, 0.45))


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = maxi(1, int(st["kills"]) * 100 + int(float(st["hero"]["hp"])) * 10)
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "hp": float(st["hero"]["hp"]), "time": snappedf(time_in_level, 0.1)})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


## Estrellas por la vida que queda: mas de la mitad, 3; mas de un cuarto, 2; si no, 1.
func stars_earned() -> int:
	var f: float = float(st["hero"]["hp"]) / maxf(1.0, float(st["hero"]["max_hp"]))
	return 3 if f > 0.5 else (2 if f > 0.25 else 1)


func _lose() -> void:
	if failed:
		return
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "rogue", "deaths": deaths, "room": int(st["room"])})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("rg_lost", "Te han vencido"), Kit.text("rg_lost_hint", "Mu\u00e9vete para esquivar y p\u00e1rate para disparar: el h\u00e9roe solo dispara cuando est\u00e1 quieto."))
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
	return {"deaths": deaths, "coins": coins, "finished": finished, "failed": failed, "stomps": coins, "time": time_in_level,
		"room": int(st.get("room", 0)), "hp": float((st.get("hero", {}) as Dictionary).get("hp", 0.0))}
