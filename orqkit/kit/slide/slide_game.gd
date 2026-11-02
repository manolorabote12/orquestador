extends Node2D
## Puzle de deslizar: el dibujo (escena por datos y el heroe del juego en medio, como el
## rompecabezas) en piezas con un hueco. Toca una pieza de la fila o columna del hueco para
## deslizarla. Abajo, el dibujo entero en pequeno como guia. Reglas, bot y analizador en slide_map.gd.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const M = preload("res://kit/slide/slide_map.gd")
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

var _view: Control
var _info: Label
var _vp: SubViewport
var _pic: Node2D
var _slide: Dictionary = {}
var _slide_t: float = 1.0
var _t: float = 0.0


func _ready() -> void:
	level = Kit.current_level()
	RenderingServer.set_default_clear_color(Color("#1f2233"))
	_build_picture()
	_build_hud()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "slide", "n": int(st["n"])})


func bot_script() -> String:
	return "res://qa/slide_bot.gd"


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
	coins_total = int(st["n"]) * int(st["n"]) - 1
	coins = M.placed_count(st)
	time_in_level = 0.0
	_slide = {}
	_slide_t = 1.0
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
	_info.add_theme_font_size_override("font_size", 28)
	top.add_child(_info)
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


func _board() -> Rect2:
	var sz: Vector2 = _view.size
	var side: float = minf(sz.x - 8.0, sz.y * 0.68)
	return Rect2(Vector2((sz.x - side) * 0.5, 0.0), Vector2(side, side))


func _guide() -> Rect2:
	var b: Rect2 = _board()
	var side: float = clampf(_view.size.y - b.size.y - 24.0, 0.0, b.size.x * 0.42)
	return Rect2(Vector2((_view.size.x - side) * 0.5, b.end.y + 16.0), Vector2(side, side))


func tap_slot(s: int) -> void:
	if not can_act():
		return
	var moved: int = M.tap(st, s)
	if moved == 0:
		return
	_slide = {}
	for m: Variant in st["last"]:
		_slide[int(m[1])] = int(m[0])
	_slide_t = 0.0
	coins = M.placed_count(st)
	_sfx("click", -8.0)
	_refresh()
	if bool(st["won"]):
		_finish()
	elif bool(st["lost"]):
		_lose()


func bot_step() -> void:
	if can_act() and _slide_t >= 1.0:
		var s: int = M.bot_move(st, level.get("sol", []))
		if s >= 0:
			tap_slot(s)


func _on_input(event: InputEvent) -> void:
	var p: Vector2 = Vector2.INF
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		p = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and not DisplayServer.is_touchscreen_available():
		p = (event as InputEventMouseButton).position
	if p == Vector2.INF:
		return
	var b: Rect2 = _board()
	if not b.has_point(p):
		return
	var n: int = int(st["n"])
	var q: Vector2 = (p - b.position) / b.size * float(n)
	tap_slot(clampi(int(q.y), 0, n - 1) * n + clampi(int(q.x), 0, n - 1))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()


func _sfx(nm: String, vol: float = -6.0) -> void:
	if not fast:
		Audio.play(nm, 0.1, vol)


func _refresh() -> void:
	if st.is_empty() or _info == null:
		return
	var txt: String = Kit.text("sl_placed", "En su sitio {a}/{b}").format({"a": coins, "b": coins_total})
	if int(st["max_moves"]) > 0:
		txt += "\n" + Kit.text("sl_moves", "Movimientos {a}/{b}").format({"a": int(st["moves"]), "b": int(st["max_moves"])})
	else:
		txt += "\n" + Kit.text("sl_count", "Movimientos {a}").format({"a": int(st["moves"])})
	_info.text = txt
	_view.queue_redraw()


func _physics_process(delta: float) -> void:
	if st.is_empty() or get_tree().paused:
		return
	_t += delta
	if _slide_t < 1.0:
		_slide_t = minf(1.0, _slide_t + delta * (40.0 if fast else 9.0))
	if not finished and not failed:
		time_in_level += delta
		if fast and auto_retry:
			bot_step()
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
	var blank: int = n * n - 1
	_view.draw_rect(b.grow(6.0), Color("#0e1019"))
	var tiles: Array = st["tiles"]
	for s: int in n * n:
		var p: int = int(tiles[s])
		if p == blank and not finished:
			continue
		var pos: Vector2 = b.position + Vector2(s % n, s / n) * ts
		if _slide.has(s) and _slide_t < 1.0:
			var from: int = int(_slide[s])
			pos = (b.position + Vector2(from % n, from / n) * ts).lerp(pos, ease(_slide_t, 0.5))
		var dst: Rect2 = Rect2(pos, Vector2(ts, ts))
		var src: Rect2 = Rect2(Vector2(p % n, p / n) * cs, Vector2(cs, cs))
		_view.draw_texture_rect_region(tex, dst.grow(-2.0) if not finished else dst, src)
		if not finished:
			_view.draw_rect(dst.grow(-2.0), Color(1, 1, 1, 0.18) if p == s else Color(0, 0, 0, 0.5), false, 3.0)
	## Las piezas que se pueden tocar ahora, con un brillo suave.
	if can_act() and not finished:
		for s2: int in n * n:
			if not M.slide_path(tiles, n, s2).is_empty() and M.slide_path(tiles, n, s2).size() == 1:
				var r: Rect2 = Rect2(b.position + Vector2(s2 % n, s2 / n) * ts, Vector2(ts, ts)).grow(-5.0)
				_view.draw_rect(r, Color(1.0, 0.85, 0.3, 0.25 + 0.2 * sin(_t * 5.0)), false, 4.0)
	var g: Rect2 = _guide()
	if g.size.x > 40.0:
		_view.draw_texture_rect(tex, g, false)
		_view.draw_rect(g, Color.WHITE, false, 3.0)


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = maxi(1, coins_total * 60 - maxi(0, int(st["moves"]) - (level.get("sol", []) as Array).size()) * 5)
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "moves": int(st["moves"]), "time": snappedf(time_in_level, 0.1)})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins_total, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


## Estrellas por movimientos frente a la solucion de la fabrica: igual o menos, 3; hasta el doble, 2.
func stars_earned() -> int:
	var need: int = maxi(1, (level.get("sol", []) as Array).size())
	var used: int = int(st["moves"])
	return 3 if used <= need else (2 if used <= need * 2 else 1)


func _lose() -> void:
	if failed:
		return
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "slide", "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("sl_lost", "Sin movimientos"),
		Kit.text("sl_hint", "Coloca primero la fila de arriba y la columna de la izquierda: el resto se ordena en un trozo mas pequeno."))
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
		"moves": int(st.get("moves", 0))}
