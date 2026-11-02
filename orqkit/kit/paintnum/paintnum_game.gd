extends Node2D
## Pintar por numeros: arriba el dibujo de cuadritos con numeros, abajo la paleta. Elige un color y
## toca o arrastra por sus cuadritos (arrastrando, el color equivocado no cuenta como fallo). El cubo
## pinta de golpe todo un color. Si el nivel lo pide y hay arte, el dibujo es el heroe del juego.
## Reglas, bot y analizador en paintnum_map.gd.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel al acabar.

const M = preload("res://kit/paintnum/paintnum_map.gd")

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

var _font: Font
var _view: Control
var _info: Label
var _fill_btn: Button
var _painting: bool = false
var _last_cell: Vector2i = Vector2i(-1, -1)
var _miss: Array = []
var _anim_t: float = 0.0
var _done_t: float = 0.0


func _ready() -> void:
	level = Kit.current_level().duplicate(true)
	if bool(level.get("from_art", false)):
		var pic: Dictionary = _hero_picture()
		if not pic.is_empty() and bool(M.analyze(level.merged(pic, true))["completable"]):
			level.merge(pic, true)
	RenderingServer.set_default_clear_color(Color("#2a2438"))
	_font = UI.theme.get_font("font", "Label") if UI.theme != null else ThemeDB.fallback_font
	_build_hud()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "paintnum", "cells": coins_total})


func bot_script() -> String:
	return "res://qa/paintnum_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(2.2, 1.6)


## El primer fotograma del heroe convertido en dibujo de cuadritos ({} si no hay arte).
func _hero_picture() -> Dictionary:
	var art: Dictionary = Kit.sprite_by_role("jugador")
	var anims: Dictionary = art.get("animaciones", {})
	var an: Dictionary = anims.get("idle", anims.get("run", {}))
	var tex: Texture2D = Kit.load_texture(str(an.get("sheet", "")))
	if tex == null:
		return {}
	var img: Image = tex.get_image()
	if img == null or img.is_empty():
		return {}
	var frames: int = maxi(1, int(an.get("frames", 1)))
	var fw: int = img.get_width() / frames
	var frame: Image = img.get_region(Rect2i(0, 0, fw, img.get_height()))
	return M.from_image(frame, int(level.get("art_size", 16)), int(level.get("art_colors", 6)))


func _reset() -> void:
	finished = false
	failed = false
	st = M.new_state(level)
	coins_total = int(st["left"])
	coins = 0
	time_in_level = 0.0
	_miss.clear()
	_done_t = 0.0
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
	_fill_btn = UI.make_button("", false, "star")
	_fill_btn.name = "BtnFill"
	_fill_btn.pressed.connect(use_fill)
	top.add_child(_fill_btn)
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


const PAL_H: float = 120.0


## Rejilla del dibujo (encima de la paleta), con cuadritos cuadrados.
func _grid() -> Rect2:
	var sz: Vector2 = _view.size
	var w: int = maxi(1, int(st["w"]))
	var h: int = maxi(1, int(st["h"]))
	var cell: float = minf((sz.x - 8.0) / float(w), (sz.y - PAL_H - 24.0) / float(h))
	var gs: Vector2 = Vector2(w, h) * cell
	return Rect2(Vector2((sz.x - gs.x) * 0.5, maxf(0.0, (sz.y - PAL_H - 24.0 - gs.y) * 0.5)), gs)


## Circulo de cada color de la paleta: [centro, radio].
func _swatch(c: int) -> Array:
	var n: int = (st["palette"] as Array).size()
	var r: float = minf(48.0, (_view.size.x - 16.0) / float(maxi(1, n)) * 0.42)
	var step: float = (_view.size.x - 16.0) / float(maxi(1, n))
	return [Vector2(8.0 + step * (float(c - 1) + 0.5), _view.size.y - PAL_H * 0.5), r]


func _cell_at(p: Vector2) -> Vector2i:
	var g: Rect2 = _grid()
	if not g.has_point(p):
		return Vector2i(-1, -1)
	var q: Vector2 = (p - g.position) / g.size * Vector2(int(st["w"]), int(st["h"]))
	return Vector2i(int(q.x), int(q.y))


func choose(c: int) -> void:
	if can_act() and M.select(st, c):
		_sfx("click", -12.0)
		_refresh()


## Pinta el cuadrito (x, y) con el color elegido (lo usan el toque, el arrastre y el bot).
func paint_cell(x: int, y: int, count_miss: bool = true) -> int:
	if not can_act():
		return 0
	var r: int = M.paint(st, x, y, count_miss)
	if r == 1:
		coins = coins_total - int(st["left"])
		_sfx("coin", -16.0)
		_auto_next()
	elif r == -1 and count_miss:
		_miss.append({"c": Vector2i(x, y), "t": 0.5})
		_sfx("hurt", -12.0)
	_refresh()
	if bool(st["won"]):
		_finish()
	return r


## Si el color elegido ya esta terminado, salta al siguiente que quede.
func _auto_next() -> void:
	if M.remaining(st, int(st["sel"])) > 0:
		return
	for c: int in range(1, (st["palette"] as Array).size() + 1):
		if M.remaining(st, c) > 0:
			st["sel"] = c
			return


func use_fill() -> void:
	if not can_act():
		return
	var n: int = M.fill(st)
	if n > 0:
		coins = coins_total - int(st["left"])
		_sfx("powerup", -8.0)
		_auto_next()
		_refresh()
		if bool(st["won"]):
			_finish()


func bot_step() -> void:
	if can_act():
		var m: Array = M.bot_move(st)
		if not m.is_empty():
			M.select(st, int(m[0]))
			paint_cell(int(m[1]), int(m[2]))


func _on_input(event: InputEvent) -> void:
	var touch: bool = DisplayServer.is_touchscreen_available()
	var pos: Vector2 = Vector2.INF
	var state: int = 0
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
	if state == 0:
		return
	if state == -1:
		_painting = false
		_last_cell = Vector2i(-1, -1)
		return
	if state == 1:
		for c: int in range(1, (st["palette"] as Array).size() + 1):
			var sw: Array = _swatch(c)
			if pos.distance_to(sw[0]) <= float(sw[1]) + 10.0:
				choose(c)
				return
		_painting = true
	if not _painting:
		return
	var cell: Vector2i = _cell_at(pos)
	if cell.x < 0 or cell == _last_cell:
		return
	paint_cell(cell.x, cell.y, state == 1)
	_last_cell = cell


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
	var pct: int = int(round(100.0 * float(coins) / float(maxi(1, coins_total))))
	_info.text = "%d%%" % pct + "\n" + Kit.text("pn_mistakes", "Fallos {n}").format({"n": int(st["mistakes"])})
	_fill_btn.text = "     " + Kit.text("pn_fill", "Cubo") + " %d" % int(st["fills"])
	_fill_btn.disabled = int(st["fills"]) <= 0
	_view.queue_redraw()


func _physics_process(delta: float) -> void:
	if st.is_empty() or get_tree().paused:
		return
	_anim_t += delta
	if finished:
		_done_t += delta
		_view.queue_redraw()
		return
	if not failed:
		time_in_level += delta
	if fast and auto_retry:
		for k: int in 4:
			bot_step()
	for m: Variant in _miss:
		m["t"] = float(m["t"]) - delta
	_miss = _miss.filter(func(m: Dictionary) -> bool: return float(m["t"]) > 0.0)
	_view.queue_redraw()


# ------------------------------------------------------------------ dibujo

func _draw_view() -> void:
	if st.is_empty():
		return
	var g: Rect2 = _grid()
	var w: int = int(st["w"])
	var h: int = int(st["h"])
	var cs: float = g.size.x / float(maxi(1, w))
	var pal: Array = st["palette"]
	var cells: PackedByteArray = st["cells"]
	var painted: PackedByteArray = st["painted"]
	var sel: int = int(st["sel"])
	var fs: int = int(clampf(cs * 0.55, 8.0, 28.0))
	_view.draw_rect(g.grow(6.0), Color("#fbfaf7"))
	for y: int in h:
		for x: int in w:
			var i: int = y * w + x
			var r: Rect2 = Rect2(g.position + Vector2(x, y) * cs, Vector2(cs, cs))
			var v: int = cells[i]
			if v == 0:
				continue
			if painted[i] == 1:
				_view.draw_rect(r, Color(str(pal[v - 1])))
				continue
			var base: Color = Color("#c9d3ff") if v == sel else (Color("#eeeeee") if (x + y) % 2 == 0 else Color("#e4e4e4"))
			_view.draw_rect(r, base)
			if not finished:
				_view.draw_rect(r, Color(0, 0, 0, 0.08), false, 1.0)
				if cs >= 14.0:
					_view.draw_string(ThemeDB.fallback_font, r.position + Vector2(0, cs * 0.5 + float(fs) * 0.35), str(v), HORIZONTAL_ALIGNMENT_CENTER, cs, fs,
						Color("#3d3d55") if v == sel else Color("#8a8a99"))
	for m: Variant in _miss:
		var mc: Vector2i = m["c"]
		_view.draw_rect(Rect2(g.position + Vector2(mc) * cs, Vector2(cs, cs)), Color(0.9, 0.2, 0.2, float(m["t"])))
	if finished:
		var k: float = clampf(_done_t * 2.0, 0.0, 1.0)
		_view.draw_rect(g.grow(6.0), Color(1, 1, 1, 0.6 * (1.0 - k)), false, 8.0)
	for c: int in range(1, pal.size() + 1):
		var sw: Array = _swatch(c)
		var ctr: Vector2 = sw[0]
		var rad: float = sw[1]
		var left: int = M.remaining(st, c)
		if c == sel:
			_view.draw_circle(ctr, rad + 8.0, Color("#ffd166"))
		_view.draw_circle(ctr, rad, Color(str(pal[c - 1])))
		var col: Color = Color(str(pal[c - 1]))
		var tc: Color = Color("#1d1d29") if col.get_luminance() > 0.55 else Color.WHITE
		_view.draw_string(ThemeDB.fallback_font, ctr + Vector2(-rad, rad * 0.3), "OK" if left == 0 else str(c), HORIZONTAL_ALIGNMENT_CENTER, rad * 2.0, int(rad * 0.8), tc)


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = maxi(1, coins_total * 10 - int(st["mistakes"]) * 20 + int(st["fills"]) * 50)
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "mistakes": int(st["mistakes"]), "time": snappedf(time_in_level, 0.1)})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


## Estrellas: hasta 2 fallos, 3; hasta 6, 2; si no, 1.
func stars_earned() -> int:
	var m: int = int(st["mistakes"])
	return 3 if m <= 2 else (2 if m <= 6 else 1)


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
		"mistakes": int(st.get("mistakes", 0))}
