extends Node2D
## Rompecabezas: el dibujo (escena por datos y, si hay arte, el heroe del juego en medio) partido en
## cuadrados y desordenado. Toca dos piezas (o arrastra una sobre otra) para cambiarlas; las que caen
## en su sitio se quedan fijas. Abajo, el dibujo entero en pequeno como guia.
## Reglas, bot y analizador en jigsaw_map.gd.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel al acabar.

const M = preload("res://kit/jigsaw/jigsaw_map.gd")
const SceneDraw = preload("res://kit/spotdiff/scene_draw.gd")
const PIC: int = 512

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
var need: int = 0
var hints: int = 2

var _view: Control
var _info: Label
var _hint_btn: Button
var _vp: SubViewport
var _pic: Node2D
var _sel: int = -1
var _drag_from: int = -1
var _drag_pos: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _flash: Dictionary = {}
var _anim_t: float = 0.0


func _ready() -> void:
	level = Kit.current_level()
	RenderingServer.set_default_clear_color(Color("#23263a"))
	_build_picture()
	_build_hud()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "jigsaw", "pieces": coins_total, "min_swaps": need})


func bot_script() -> String:
	return "res://qa/jigsaw_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(2.2, 1.6)


## El dibujo se pinta una vez en una textura (SubViewport) y las piezas son trozos de ella.
func _build_picture() -> void:
	_vp = SubViewport.new()
	_vp.name = "Picture"
	_vp.size = Vector2i(PIC, PIC)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.transparent_bg = false
	add_child(_vp)
	_pic = Node2D.new()
	_pic.draw.connect(func() -> void: SceneDraw.draw_scene(_pic, Rect2(0, 0, PIC, PIC), level, level.get("scene", [])))
	_vp.add_child(_pic)
	if bool(level.get("hero", true)):
		var art: Dictionary = Kit.sprite_by_role("jugador")
		if not art.is_empty():
			var anims: Dictionary = art.get("animaciones", {})
			var spr: AnimatedSprite2D = SpriteKit.animado(art, PIC * 0.42, "idle" if anims.has("idle") else "run", false)
			spr.position = Vector2(PIC * 0.5, PIC * 0.52)
			Skins.apply(spr)
			_vp.add_child(spr)


func _reset() -> void:
	finished = false
	failed = false
	st = M.new_state(level)
	coins_total = (st["slots"] as Array).size()
	need = M.min_swaps(st["slots"])
	coins = M.placed_count(st)
	hints = 2
	time_in_level = 0.0
	_sel = -1
	_drag_from = -1
	_dragging = false
	_flash.clear()
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
	_info = Label.new()
	_info.name = "Info"
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.clip_text = true
	_info.add_theme_font_size_override("font_size", 26)
	top.add_child(_info)
	_hint_btn = UI.make_button("", false, "star")
	_hint_btn.name = "BtnHint"
	_hint_btn.pressed.connect(use_hint)
	top.add_child(_hint_btn)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)
	_view = Control.new()
	_view.name = "View"
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.draw.connect(_draw_view)
	_view.gui_input.connect(_on_input)
	col.add_child(_view)


func can_act() -> bool:
	return not finished and not failed and is_inside_tree() and not get_tree().paused and not st.is_empty()


## Tablero (cuadrado, arriba) y guia (el dibujo entero en pequeno, debajo).
func _board() -> Rect2:
	var sz: Vector2 = _view.size
	var side: float = minf(sz.x - 8.0, sz.y * 0.68)
	return Rect2(Vector2((sz.x - side) * 0.5, 0.0), Vector2(side, side))


func _guide() -> Rect2:
	var b: Rect2 = _board()
	var side: float = clampf(_view.size.y - b.size.y - 24.0, 0.0, b.size.x * 0.42)
	return Rect2(Vector2((_view.size.x - side) * 0.5, b.end.y + 16.0), Vector2(side, side))


func _slot_at(p: Vector2) -> int:
	var b: Rect2 = _board()
	if not b.has_point(p):
		return -1
	var n: int = int(st["n"])
	var q: Vector2 = (p - b.position) / b.size * float(n)
	return clampi(int(q.y), 0, n - 1) * n + clampi(int(q.x), 0, n - 1)


## Cambia las piezas de dos huecos (lo usan el toque, el arrastre, la pista y el bot).
func swap_slots(a: int, b: int) -> bool:
	if not can_act():
		return false
	var got: int = M.swap(st, a, b)
	if got < 0:
		_sfx("hurt", -14.0)
		return false
	coins = M.placed_count(st)
	for s: int in [a, b]:
		if M.placed(st, s):
			_flash[s] = 0.6
	_sfx("coin" if got > 0 else "click", -6.0 if got > 0 else -10.0)
	_refresh()
	if bool(st["won"]):
		_finish()
	elif bool(st["lost"]):
		_lose()
	return true


## Toque en un hueco: el primero se selecciona; el segundo cambia los dos.
func tap_slot(s: int) -> void:
	if not can_act() or s < 0 or M.placed(st, s):
		_sel = -1
		_view.queue_redraw()
		return
	if _sel < 0 or _sel == s:
		_sel = -1 if _sel == s else s
		_sfx("click", -14.0)
		_view.queue_redraw()
		return
	var a: int = _sel
	_sel = -1
	swap_slots(a, s)


func use_hint() -> void:
	if not can_act() or hints <= 0:
		return
	var m: Array = M.bot_move(st)
	if m.is_empty():
		return
	hints -= 1
	_sel = -1
	_sfx("powerup", -8.0)
	swap_slots(int(m[0]), int(m[1]))


func bot_step() -> void:
	if can_act():
		var m: Array = M.bot_move(st)
		if not m.is_empty():
			swap_slots(int(m[0]), int(m[1]))


func _on_input(event: InputEvent) -> void:
	var touch: bool = DisplayServer.is_touchscreen_available()
	var pressed: int = 0
	var pos: Vector2 = Vector2.ZERO
	if event is InputEventScreenTouch:
		pressed = 1 if (event as InputEventScreenTouch).pressed else -1
		pos = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton and not touch and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		pressed = 1 if (event as InputEventMouseButton).pressed else -1
		pos = (event as InputEventMouseButton).position
	elif event is InputEventScreenDrag or (event is InputEventMouseMotion and not touch):
		if _drag_from >= 0:
			_drag_pos = (event as InputEventScreenDrag).position if event is InputEventScreenDrag else (event as InputEventMouseMotion).position
			_dragging = _dragging or _drag_pos.distance_to(_slot_center(_drag_from)) > _board().size.x / float(int(st["n"])) * 0.35
			_view.queue_redraw()
		return
	if pressed == 1:
		var s: int = _slot_at(pos)
		_drag_from = s if s >= 0 and not M.placed(st, s) and can_act() else -1
		_drag_pos = pos
		_dragging = false
	elif pressed == -1:
		var to: int = _slot_at(pos)
		var from: int = _drag_from
		var was_drag: bool = _dragging
		_drag_from = -1
		_dragging = false
		if was_drag and from >= 0:
			_sel = -1
			if to >= 0 and to != from:
				swap_slots(from, to)
			_view.queue_redraw()
		elif to >= 0:
			tap_slot(to)


func _slot_center(s: int) -> Vector2:
	var b: Rect2 = _board()
	var n: int = int(st["n"])
	var ts: float = b.size.x / float(n)
	return b.position + Vector2(float(s % n) + 0.5, float(s / n) + 0.5) * ts


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
	var mv: String = Kit.text("jg_moves", "Cambios {a}").format({"a": int(st["moves"])})
	if int(st["max_moves"]) > 0:
		mv += " / %d" % int(st["max_moves"])
	_info.text = Kit.text("jg_pieces", "{a}/{b} piezas").format({"a": coins, "b": coins_total}) + "\n" + mv
	_hint_btn.text = "     " + Kit.text("jg_hint", "Pista") + " %d" % hints
	_hint_btn.disabled = hints <= 0
	_view.queue_redraw()


func _physics_process(delta: float) -> void:
	if st.is_empty() or finished or get_tree().paused:
		return
	_anim_t += delta
	if not failed:
		time_in_level += delta
	if fast and auto_retry:
		bot_step()
	for k: Variant in _flash.keys():
		_flash[k] = float(_flash[k]) - delta
		if float(_flash[k]) <= 0.0:
			_flash.erase(k)
	_view.queue_redraw()


# ------------------------------------------------------------------ dibujo

func _draw_view() -> void:
	if st.is_empty():
		return
	var tex: Texture2D = _vp.get_texture()
	var b: Rect2 = _board()
	var n: int = int(st["n"])
	var ts: float = b.size.x / float(n)
	var cs: float = float(PIC) / float(n)
	_view.draw_rect(b.grow(6.0), Color("#11131f"))
	for s: int in n * n:
		var p: int = int(st["slots"][s])
		if s == _drag_from and _dragging:
			_view.draw_rect(Rect2(b.position + Vector2(s % n, s / n) * ts, Vector2(ts, ts)).grow(-2.0), Color("#3a3f5c"))
			continue
		var dst: Rect2 = Rect2(b.position + Vector2(s % n, s / n) * ts, Vector2(ts, ts))
		var src: Rect2 = Rect2(Vector2(p % n, p / n) * cs, Vector2(cs, cs))
		var fixed: bool = p == s
		_view.draw_texture_rect_region(tex, dst if fixed else dst.grow(-2.0), src)
		if not fixed:
			_view.draw_rect(dst.grow(-2.0), Color(0, 0, 0, 0.55), false, 3.0)
		if _flash.has(s):
			_view.draw_rect(dst, Color(0.55, 1.0, 0.6, float(_flash[s]) * 0.6))
		if s == _sel:
			_view.draw_rect(dst.grow(-4.0), Color("#ffd166"), false, 6.0 + 2.0 * sin(_anim_t * 8.0))
	if _drag_from >= 0 and _dragging:
		var p2: int = int(st["slots"][_drag_from])
		var src2: Rect2 = Rect2(Vector2(p2 % n, p2 / n) * cs, Vector2(cs, cs))
		var d2: Rect2 = Rect2(_drag_pos - Vector2(ts, ts) * 0.55, Vector2(ts, ts) * 1.1)
		_view.draw_texture_rect_region(tex, d2, src2)
		_view.draw_rect(d2, Color("#ffd166"), false, 4.0)
	var g: Rect2 = _guide()
	if g.size.x > 40.0:
		_view.draw_texture_rect(tex, g, false)
		_view.draw_rect(g, Color.WHITE, false, 3.0)


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	_sel = -1
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = maxi(1, coins_total * 100 + maxi(0, need * 3 - int(st["moves"])) * 40 + hints * 60)
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "moves": int(st["moves"]), "min_swaps": need, "time": snappedf(time_in_level, 0.1)})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


## Estrellas: con el minimo de cambios y sin pistas, 3; con poco de mas, 2; si no, 1.
func stars_earned() -> int:
	var extra: int = int(st["moves"]) - need + (2 - hints)
	return 3 if extra <= 0 else (2 if extra <= maxi(2, need / 3) else 1)


func _lose() -> void:
	if failed:
		return
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "jigsaw", "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("jg_lost", "Sin cambios"), Kit.text("jg_lost_hint", "Mira el dibujo peque\u00f1o: cada cambio deber\u00eda dejar al menos una pieza en su sitio."))
	p.closed.connect(retry)


## Segunda oportunidad (FailPanel, con anuncio): unos movimientos mas y se sigue donde ibas.
func revive() -> void:
	st["max_moves"] = int(st["max_moves"]) + extra_moves()
	failed = false
	_refresh()


func extra_moves() -> int:
	return maxi(3, int(st.get("max_moves", 0)) / 4)


func revive_text() -> String:
	return Kit.text("revive_moves", "+{n} movimientos").format({"n": extra_moves()})


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
	return {"deaths": deaths, "coins": coins, "finished": finished, "failed": failed, "stomps": 0, "time": time_in_level,
		"moves": int(st.get("moves", 0)), "min_swaps": need}
