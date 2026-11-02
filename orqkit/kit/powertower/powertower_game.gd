extends Node2D
## Torre de poder (tipo los anuncios de Hero Wars): toca las salas en buen orden, vence a los que
## tienen menos poder que tu, suma premios, esquiva trampas y derrota al jefe. Reglas, bot y
## analizador en powertower_map.gd.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel al acabar.

const M = preload("res://kit/powertower/powertower_map.gd")

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
var _power_lbl: Label
var _rects: Dictionary = {}
var _hero_at: Vector2 = Vector2.ZERO
var _hero_to: Vector2 = Vector2.ZERO
var _flash: Dictionary = {}
var _pops: Array = []
var _anim_t: float = 0.0
var _busy: float = 0.0


func _ready() -> void:
	level = Kit.current_level()
	RenderingServer.set_default_clear_color(Color("#87c4ec"))
	_font = UI.theme.get_font("font", "Label") if UI.theme != null else ThemeDB.fallback_font
	_build_hud()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "powertower"})


func bot_script() -> String:
	return "res://qa/powertower_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(2.0, 1.6)


func _reset() -> void:
	finished = false
	failed = false
	st = M.new_state(level)
	time_in_level = 0.0
	_busy = 0.0
	_flash.clear()
	_pops.clear()
	_hero_at = Vector2.ZERO
	_hero_to = Vector2.ZERO
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
	_view = Control.new()
	_view.name = "View"
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.draw.connect(_draw_view)
	_view.gui_input.connect(_on_input)
	root.add_child(_view)
	var safe: MarginContainer = UI.safe_root(root, 14.0)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	safe.add_child(top)
	_power_lbl = Label.new()
	_power_lbl.name = "Power"
	_power_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_power_lbl.add_theme_font_size_override("font_size", 40)
	top.add_child(_power_lbl)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)


func can_act() -> bool:
	return not finished and not failed and is_inside_tree() and not get_tree().paused and not st.is_empty() and _busy <= 0.0


func tap_room(t: int, r: int) -> void:
	if not can_act() or not M.can_pick(st, t, r):
		return
	var out: Dictionary = M.pick(st, t, r)
	if out.is_empty():
		return
	var key: String = "%d:%d" % [t, r]
	if _rects.has(key):
		_hero_to = (_rects[key] as Rect2).get_center()
	_flash[key] = 0.5
	_busy = 0.0 if fast else 0.35
	var diff: int = int(out["after"]) - int(out["before"])
	_pops.append({"t": 0.9, "txt": ("+%d" % diff) if diff >= 0 else str(diff), "good": diff >= 0, "at": _hero_to})
	if bool(out["ok"]):
		_sfx("coin" if diff >= 0 else "hurt", -6.0)
	_refresh()
	if bool(st["won"]):
		_finish()
	elif bool(st["lost"]):
		_lose(int(out["before"]))


func bot_step() -> void:
	if not can_act():
		return
	var m: Array = M.bot_move(st)
	if not m.is_empty():
		tap_room(int(m[0]), int(m[1]))


func _on_input(event: InputEvent) -> void:
	var p: Vector2 = Vector2.INF
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		p = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and not DisplayServer.is_touchscreen_available():
		p = (event as InputEventMouseButton).position
	if p == Vector2.INF:
		return
	for k: Variant in _rects:
		if (_rects[k] as Rect2).has_point(p):
			var parts: PackedStringArray = str(k).split(":")
			tap_room(int(parts[0]), int(parts[1]))
			return


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()


func _sfx(n: String, vol: float = -6.0) -> void:
	if not fast:
		Audio.play(n, 0.1, vol)


func _refresh() -> void:
	if st.is_empty() or _power_lbl == null:
		return
	_power_lbl.text = Kit.text("pw_power", "Poder {n}").format({"n": int(st["p"])})
	_view.queue_redraw()


func _physics_process(delta: float) -> void:
	if st.is_empty() or finished or get_tree().paused:
		return
	_anim_t += delta
	if not failed:
		time_in_level += delta
	_busy = maxf(0.0, _busy - delta)
	if fast and auto_retry:
		for k: int in 4:
			bot_step()
	_hero_at = _hero_at.lerp(_hero_to, minf(1.0, delta * 10.0)) if _hero_at != Vector2.ZERO else _hero_to
	for f: Variant in _flash.keys():
		_flash[f] = float(_flash[f]) - delta
		if float(_flash[f]) <= 0.0:
			_flash.erase(f)
	for p: Variant in _pops:
		p["t"] = float(p["t"]) - delta
	_pops = _pops.filter(func(p: Dictionary) -> bool: return float(p["t"]) > 0.0)
	_view.queue_redraw()


# ------------------------------------------------------------------ dibujo

func _draw_view() -> void:
	if st.is_empty():
		return
	var sz: Vector2 = _view.size
	_view.draw_rect(Rect2(Vector2(0, sz.y * 0.86), Vector2(sz.x, sz.y * 0.14)), Color("#5aa04a"))
	var towers: Array = st["towers"]
	var n: int = towers.size()
	var open: int = M.open_tower(st)
	var tw_w: float = minf(170.0, (sz.x - 40.0) / float(maxi(1, n)))
	var max_rooms: int = 1
	for t: Variant in towers:
		max_rooms = maxi(max_rooms, (t as Array).size())
	var room_h: float = minf(120.0, (sz.y * 0.72) / float(max_rooms))
	var ground: float = sz.y * 0.86
	_rects.clear()
	for ti: int in n:
		var x0: float = 20.0 + float(ti) * tw_w + (sz.x - 40.0 - tw_w * float(n)) * 0.5
		var rooms: Array = towers[ti]
		var locked: bool = open >= 0 and ti > open
		## Tejado de la torre.
		var top_y: float = ground - room_h * float(rooms.size())
		_view.draw_colored_polygon(PackedVector2Array([Vector2(x0 + 4, top_y), Vector2(x0 + tw_w * 0.5, top_y - 50), Vector2(x0 + tw_w - 4, top_y)]),
			Color("#9b3d3d") if not locked else Color("#6a6a74"))
		for ri: int in rooms.size():
			var room: Dictionary = rooms[ri]
			var r: Rect2 = Rect2(Vector2(x0 + 4, ground - room_h * float(ri + 1)), Vector2(tw_w - 8, room_h - 4))
			_rects["%d:%d" % [ti, ri]] = r
			var grow: float = float(_flash.get("%d:%d" % [ti, ri], 0.0)) * 10.0
			_view.draw_rect(r.grow(grow), Color("#d9c3a0") if not locked else Color("#9a9aa4"))
			_view.draw_rect(r, Color("#7a5a3a"), false, 4.0)
			if bool(room["done"]):
				continue
			var c: Vector2 = r.get_center()
			var kind: String = str(room["t"])
			var txt: String = ""
			var col: Color = Color.WHITE
			match kind:
				"enemy", "boss":
					var s: float = room_h * (0.22 if kind == "enemy" else 0.3)
					_view.draw_circle(c + Vector2(0, -6), s, Color("#c0392b") if kind == "enemy" else Color("#5b2a86"))
					_view.draw_circle(c + Vector2(-s * 0.35, -s * 0.3 - 6), s * 0.16, Color.WHITE)
					_view.draw_circle(c + Vector2(s * 0.35, -s * 0.3 - 6), s * 0.16, Color.WHITE)
					if kind == "boss":
						_view.draw_colored_polygon(PackedVector2Array([c + Vector2(-s, -s - 6), c + Vector2(-s * 0.5, -s * 1.6), c + Vector2(0, -s - 6),
							c + Vector2(s * 0.5, -s * 1.6), c + Vector2(s, -s - 6)]), Color("#ffd166"))
					txt = str(int(room["p"]))
					col = Color("#ff6b6b") if int(st["p"]) <= int(room["p"]) else Color("#ffffff")
				"bonus":
					_view.draw_circle(c + Vector2(0, -6), room_h * 0.2, Color("#5bd17a"))
					txt = str(room.get("op", ""))
				_:
					for k: int in 4:
						_view.draw_colored_polygon(PackedVector2Array([c + Vector2(-30 + 16 * k, 10), c + Vector2(-22 + 16 * k, -16), c + Vector2(-14 + 16 * k, 10)]), Color("#8e44ad"))
					txt = str(room.get("op", ""))
			var tw2: float = _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
			_view.draw_string_outline(_font, Vector2(c.x - tw2 * 0.5, r.end.y - 10), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, 6, Color(0, 0, 0, 0.7))
			_view.draw_string(_font, Vector2(c.x - tw2 * 0.5, r.end.y - 10), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, col)
	## El heroe (en el suelo hasta que entra en una sala).
	var h: Vector2 = _hero_at if _hero_at != Vector2.ZERO else Vector2(sz.x * 0.5, ground + 40)
	var bob: float = sin(_anim_t * 6.0) * 3.0
	_view.draw_circle(h + Vector2(0, -10 + bob), 22.0, Color("#3f6fb5"))
	_view.draw_circle(h + Vector2(0, -38 + bob), 13.0, Color("#f1c27d"))
	var pt: String = str(int(st["p"]))
	var pw: float = _font.get_string_size(pt, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
	_view.draw_string_outline(_font, h + Vector2(-pw * 0.5, -58 + bob), pt, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, 8, Color(0, 0, 0, 0.8))
	_view.draw_string(_font, h + Vector2(-pw * 0.5, -58 + bob), pt, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color("#ffd166"))
	for p: Variant in _pops:
		var at: Vector2 = (p["at"] as Vector2) + Vector2(30, -40 - (0.9 - float(p["t"])) * 60.0)
		_view.draw_string(_font, at, str(p["txt"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color("#5bd17a") if bool(p["good"]) else Color("#ff6b6b"))


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = int(st["p"])
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "power": int(st["p"]), "time": snappedf(time_in_level, 0.1)})
	Audio.play("win")
	Audio.play_track("victoria", false)
	coins = stars
	coins_total = 3
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


## Estrellas: a la primera, 3; al segundo intento, 2; despues, 1.
func stars_earned() -> int:
	return 3 if deaths == 0 else (2 if deaths == 1 else 1)


func _lose(had: int) -> void:
	if failed:
		return
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "powertower", "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("pw_lost", "\u00a1Era m\u00e1s fuerte!"),
		Kit.text("pw_lost_hint", "Solo puedes con quien tiene menos poder que tu ({n}). Vence primero a los d\u00e9biles y suma premios.").format({"n": had}))
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
	return {"deaths": deaths, "coins": coins, "finished": finished, "failed": failed, "stomps": 0, "time": time_in_level,
		"power": int(st.get("p", 0)), "moves": int(st.get("moves", 0))}
