extends Node2D
## Cartas coleccionables: toca una carta de tu mano para jugarla (los hechizos con objetivo te piden
## a quien), toca un esbirro tuyo listo y luego a quien ataca. "Fin del turno" y juega el rival,
## accion a accion. Reglas, IA, bot y analizador en ccg_map.gd. Contrato con el kit: finished,
## deaths, time_in_level, fast, auto_retry, bot_script(), bot_state(), retry(), open_pause() y paneles.

const M = preload("res://kit/ccg/ccg_map.gd")
const STEP: float = 0.6
const FX_TXT: Dictionary = {"dmg": "{n} de dano", "heal": "Cura {n}", "draw": "Roba {n}", "buff": "+{n}/+{n}", "aoe": "{n} a todos"}

var level: Dictionary = {}
var st: Dictionary = {}
var finished: bool = false
var failed: bool = false
var deaths: int = 0
var time_in_level: float = 0.0
var coins: int = 0
var coins_total: int = 1
var fast: bool = false
var auto_retry: bool = false
var result_panel: ResultPanel
## Lo elegido: {"card": i} (hechizo que pide objetivo) o {"minion": uid} (esbirro que va a atacar).
var pick: Dictionary = {}

var _view: Control
var _info: Label
var _end_btn: Button
var _hero_tex: Texture2D = null
var _ai_t: float = 0.0
var _floats: Array = []
var _t: float = 0.0
## Para animar: vida y sitio de cada esbirro el fotograma anterior (golpes y bajas).
var _last: Dictionary = {}
var _hits: Array = []


func _ready() -> void:
	level = Kit.current_level()
	RenderingServer.set_default_clear_color(Color("#1f1a17"))
	var hero: Dictionary = Kit.sprite_by_role("jugador")
	if not hero.is_empty():
		var sf: SpriteFrames = SpriteKit.frames_de(hero)
		for anim: String in sf.get_animation_names():
			if sf.get_frame_count(anim) > 0:
				_hero_tex = sf.get_frame_texture(anim, 0)
				break
	_build_hud()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "ccg"})


func wants_grade() -> bool:
	return false


func bot_script() -> String:
	return "res://qa/ccg_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(3.0, 1.5)


func _reset() -> void:
	finished = false
	failed = false
	## Tu mazo propio (si lo has montado y vale) o el del nivel.
	var lv: Dictionary = level.duplicate()
	lv["deck"] = CcgCollection.deck_for(level)
	st = M.new_state(lv)
	coins = 0
	time_in_level = 0.0
	pick = {}
	_floats = []
	_last = {}
	_hits = []
	_ai_t = STEP
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
	safe.add_child(col)
	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top)
	_info = Label.new()
	_info.name = "Info"
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.add_theme_font_size_override("font_size", 26)
	top.add_child(_info)
	_end_btn = UI.make_button(Kit.text("cc_end", "Fin del turno"), true, "")
	_end_btn.name = "BtnEndTurn"
	_end_btn.pressed.connect(end_turn)
	top.add_child(_end_btn)
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


func _refresh() -> void:
	if st.is_empty() or _info == null:
		return
	var mine: bool = int(st["side"]) == 1
	_info.text = Kit.text("cc_turn", "Turno {n}").format({"n": int(st["turn"])}) + "  \u00b7  " + (Kit.text("cc_you", "Tu turno") if mine else Kit.text("cc_ai", "Juega el rival..."))
	_end_btn.disabled = not can_act()
	_view.queue_redraw()


func can_act() -> bool:
	return not finished and is_inside_tree() and not get_tree().paused and int(st["side"]) == 1 and not bool(st["won"]) and not bool(st["lost"])


# ------------------------------------------------------------------ zonas

func _foe_hero() -> Rect2:
	return Rect2(Vector2(_view.size.x * 0.5 - 60, 6), Vector2(120, 120))


func _my_hero() -> Rect2:
	return Rect2(Vector2(_view.size.x * 0.5 - 60, _view.size.y * 0.58), Vector2(120, 120))


func _slot(side: int, k: int, n: int) -> Rect2:
	var w: float = minf(124.0, (_view.size.x - 20.0) / float(M.MAX_BOARD))
	var x0: float = (_view.size.x - w * float(n)) * 0.5
	var y: float = _view.size.y * (0.2 if side == 2 else 0.39)
	return Rect2(Vector2(x0 + w * float(k), y), Vector2(w, w * 1.15)).grow(-5.0)


func _card(i: int, n: int) -> Rect2:
	var w: float = minf(132.0, (_view.size.x - 12.0) / float(maxi(n, 1)))
	var x0: float = (_view.size.x - w * float(n)) * 0.5
	var h: float = minf(_view.size.y * 0.21, w * 1.45)
	var y: float = _view.size.y - h - 6.0
	return Rect2(Vector2(x0 + w * float(i), y), Vector2(w, h)).grow(-4.0)


# ------------------------------------------------------------------ acciones

func tap(p: Vector2) -> void:
	if not can_act():
		return
	var me: Dictionary = st["p"][1]
	var foe: Dictionary = st["p"][2]
	var mb: Array = me["board"]
	var fb: Array = foe["board"]
	## Con algo elegido: el objetivo.
	if not pick.is_empty():
		var target: Dictionary = {}
		if _foe_hero().has_point(p):
			target = {"hero": true}
		elif _my_hero().has_point(p) and pick.has("card"):
			target = {"hero": true, "mine": true}
		for k: int in fb.size():
			if _slot(2, k, fb.size()).has_point(p):
				target = fb[k]
		for k2: int in mb.size():
			if _slot(1, k2, mb.size()).has_point(p) and pick.has("card"):
				target = mb[k2]
		if not target.is_empty():
			if pick.has("card"):
				var hp_before: int = int(foe["hp"])
				if M.play(st, int(pick["card"]), target):
					_after_action(hp_before)
					pick = {}
					return
			else:
				var hp_b: int = int(foe["hp"])
				if M.attack(st, int(pick["minion"]), target):
					_after_action(hp_b)
					pick = {}
					return
		pick = {}
	## Una carta de la mano.
	var hand: Array = me["hand"]
	for i: int in hand.size():
		if _card(i, hand.size()).has_point(p):
			var id: String = hand[i]
			if int(M.CARDS[id]["cost"]) > int(me["mana"]):
				_sfx("hurt", -16.0)
				return
			if M.needs_target(id):
				pick = {"card": i}
			else:
				var hb: int = int(foe["hp"])
				if M.play(st, i, {}):
					_after_action(hb)
			_refresh()
			return
	## Un esbirro tuyo listo para atacar.
	for k3: int in mb.size():
		if _slot(1, k3, mb.size()).has_point(p) and bool(mb[k3]["ready"]) and int(mb[k3]["atk"]) > 0:
			pick = {"minion": int(mb[k3]["uid"])}
			_sfx("click", -12.0)
			_refresh()
			return
	_refresh()


func _after_action(foe_hp_before: int) -> void:
	var lost: int = foe_hp_before - int(st["p"][2]["hp"])
	if lost > 0:
		_floats.append({"txt": "-%d" % lost, "at": "foe", "t": 0.0})
	_sfx("coin", -8.0)
	_refresh()
	_check()


func end_turn() -> void:
	if not can_act():
		return
	pick = {}
	M.end_turn(st)
	_ai_t = STEP
	_refresh()
	_check()


func _check() -> void:
	if bool(st["won"]):
		_finish()
	elif bool(st["lost"]):
		_lose()


## Bot: la misma IA que el analizador (prudencia maxima), una accion por paso.
func bot_step() -> void:
	if not can_act():
		return
	var hb: int = int(st["p"][2]["hp"])
	if M._ai_step(st, 1, M.BOT_SMART):
		_after_action(hb)
	else:
		end_turn()


var _ai_steps: int = 0


func _physics_process(delta: float) -> void:
	if st.is_empty() or get_tree().paused:
		return
	_t += delta
	if not finished:
		time_in_level += delta
		if int(st["side"]) == 2 and not bool(st["won"]) and not bool(st["lost"]):
			_ai_t -= delta * (30.0 if fast else 1.0)
			if _ai_t <= 0.0:
				_ai_t = STEP
				var my_hp: int = int(st["p"][1]["hp"])
				_ai_steps += 1
				if _ai_steps <= 30 and M._ai_step(st, 2, float(level.get("ai", 0.6))):
					if int(st["p"][1]["hp"]) < my_hp:
						_floats.append({"txt": "-%d" % (my_hp - int(st["p"][1]["hp"])), "at": "me", "t": 0.0})
						_sfx("hurt", -8.0)
				else:
					_ai_steps = 0
					M.end_turn(st)
				_refresh()
				_check()
		elif fast and auto_retry:
			bot_step()
	for f: Variant in _floats:
		(f as Dictionary)["t"] = float((f as Dictionary)["t"]) + delta
	_floats = _floats.filter(func(f: Dictionary) -> bool: return float(f["t"]) < 1.0)
	if not fast:
		_track_board()
	for h: Variant in _hits:
		(h as Dictionary)["t"] = float((h as Dictionary)["t"]) + delta
	_hits = _hits.filter(func(h: Dictionary) -> bool: return float(h["t"]) < 0.8)
	_view.queue_redraw()


## Compara los tableros con el fotograma anterior: dano encajado y esbirros que caen.
func _track_board() -> void:
	var now: Dictionary = {}
	for side: int in [1, 2]:
		var b: Array = st["p"][side]["board"]
		for k: int in b.size():
			var m: Dictionary = b[k]
			now[int(m["uid"])] = {"hp": int(m["hp"]), "r": _slot(side, k, b.size()), "id": str(m["id"])}
	for uid: Variant in _last:
		var old: Dictionary = _last[uid]
		if not now.has(uid):
			_hits.append({"k": "die", "at": (old["r"] as Rect2).get_center(), "t": 0.0, "id": old["id"]})
		elif int(now[uid]["hp"]) < int(old["hp"]):
			_hits.append({"k": "hit", "at": (now[uid]["r"] as Rect2).get_center(), "t": 0.0, "n": int(old["hp"]) - int(now[uid]["hp"])})
	_last = now


func _on_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		tap((event as InputEventScreenTouch).position)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and not DisplayServer.is_touchscreen_available():
		tap((event as InputEventMouseButton).position)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()


func _sfx(nm: String, vol: float = -6.0) -> void:
	if not fast:
		Audio.play(nm, 0.1, vol)


# ------------------------------------------------------------------ dibujo

func _text(p: Vector2, s: String, size: int, col: Color, w: float = -1, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var font: Font = _view.get_theme_font("font", "Label")
	_view.draw_string_outline(font, p, s, align, w, size, 5, Color(0, 0, 0, 0.85))
	_view.draw_string(font, p, s, align, w, size, col)


func _stats(r: Rect2, atk: int, hp: int, hurt: bool) -> void:
	var a: Vector2 = Vector2(r.position.x + 16, r.end.y - 14)
	var h: Vector2 = Vector2(r.end.x - 16, r.end.y - 14)
	_view.draw_circle(a, 17, Color("#f4a261"))
	_view.draw_circle(h, 17, Color("#e63946"))
	_text(a + Vector2(-17, 8), str(atk), 22, Color.WHITE, 34, HORIZONTAL_ALIGNMENT_CENTER)
	_text(h + Vector2(-17, 8), str(hp), 22, Color("#ffd166") if hurt else Color.WHITE, 34, HORIZONTAL_ALIGNMENT_CENTER)


## Dibujo de cada carta (sin imagenes: formas sencillas y reconocibles).
func _art(c: Vector2, s: float, id: String) -> void:
	var dk: Color = Color("#22223b")
	match id:
		"recluta":
			_view.draw_line(c + Vector2(-s * 0.5, s * 0.5), c + Vector2(s * 0.45, -s * 0.45), Color("#cfd8dc"), s * 0.14)
			_view.draw_line(c + Vector2(-s * 0.35, s * 0.15), c + Vector2(-s * 0.1, s * 0.4), Color("#8d6e63"), s * 0.16)
		"lobo":
			_view.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.5, -s * 0.1), c + Vector2(-s * 0.3, -s * 0.55), c + Vector2(-s * 0.05, -s * 0.2),
				c + Vector2(s * 0.5, -s * 0.05), c + Vector2(s * 0.3, s * 0.35), c + Vector2(-s * 0.35, s * 0.3)]), Color("#90a4ae"))
			_view.draw_circle(c + Vector2(-s * 0.15, -s * 0.12), s * 0.07, dk)
		"escudero", "guardia":
			var col: Color = Color("#4895ef") if id == "escudero" else Color("#adb5bd")
			_view.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.45, -s * 0.5), c + Vector2(s * 0.45, -s * 0.5), c + Vector2(s * 0.45, s * 0.05),
				c + Vector2(0, s * 0.55), c + Vector2(-s * 0.45, s * 0.05)]), col)
			_view.draw_line(c + Vector2(0, -s * 0.45), c + Vector2(0, s * 0.45), col.darkened(0.3), s * 0.1)
		"arquera":
			_view.draw_arc(c + Vector2(-s * 0.15, 0), s * 0.5, -1.2, 1.2, 12, Color("#8d6e63"), s * 0.1)
			_view.draw_line(c + Vector2(-s * 0.15 + s * 0.18, -s * 0.47), c + Vector2(-s * 0.15 + s * 0.18, s * 0.47), Color("#eeeeee"), 2.0)
			_view.draw_line(c + Vector2(-s * 0.4, 0), c + Vector2(s * 0.55, 0), Color("#cfd8dc"), s * 0.07)
		"jinete":
			_view.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.4, s * 0.5), c + Vector2(-s * 0.3, -s * 0.2), c + Vector2(0, -s * 0.55),
				c + Vector2(s * 0.45, -s * 0.2), c + Vector2(s * 0.35, s * 0.0), c + Vector2(0, -s * 0.05), c + Vector2(s * 0.1, s * 0.5)]), Color("#a1683a"))
			_view.draw_circle(c + Vector2(s * 0.12, -s * 0.28), s * 0.06, dk)
		"paladin":
			_view.draw_rect(Rect2(c + Vector2(-s * 0.1, -s * 0.5), Vector2(s * 0.2, s * 1.0)), Color("#ffd166"))
			_view.draw_rect(Rect2(c + Vector2(-s * 0.4, -s * 0.2), Vector2(s * 0.8, s * 0.2)), Color("#ffd166"))
		"ogro":
			_view.draw_circle(c, s * 0.5, Color("#6a994e"))
			_view.draw_circle(c + Vector2(-s * 0.18, -s * 0.1), s * 0.08, dk)
			_view.draw_circle(c + Vector2(s * 0.18, -s * 0.1), s * 0.08, dk)
			_view.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.2, s * 0.15), c + Vector2(-s * 0.12, s * 0.35), c + Vector2(-s * 0.04, s * 0.15)]), Color.WHITE)
			_view.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.2, s * 0.15), c + Vector2(s * 0.12, s * 0.35), c + Vector2(s * 0.04, s * 0.15)]), Color.WHITE)
		"muro":
			for row: int in 3:
				for b: int in 3:
					var off: float = 0.5 if row % 2 == 1 else 0.0
					_view.draw_rect(Rect2(c + Vector2(s * (-0.6 + (float(b) + off) * 0.4), s * (-0.45 + float(row) * 0.32)), Vector2(s * 0.36, s * 0.28)), Color("#9c6644"))
		"dragon":
			_view.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.6, s * 0.1), c + Vector2(-s * 0.15, -s * 0.55), c + Vector2(0, -s * 0.05),
				c + Vector2(s * 0.15, -s * 0.55), c + Vector2(s * 0.6, s * 0.1), c + Vector2(0, s * 0.45)]), Color("#d00000"))
			_view.draw_circle(c + Vector2(0, -s * 0.05), s * 0.18, Color("#ff8800"))
		"chispa", "tormenta":
			var col2: Color = Color("#ffd60a") if id == "chispa" else Color("#90e0ef")
			_view.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.1, -s * 0.55), c + Vector2(-s * 0.3, s * 0.05), c + Vector2(-s * 0.02, s * 0.05),
				c + Vector2(-s * 0.15, s * 0.55), c + Vector2(s * 0.3, -s * 0.08), c + Vector2(s * 0.02, -s * 0.08)]), col2)
		"bola_fuego":
			_view.draw_circle(c + Vector2(s * 0.1, s * 0.1), s * 0.35, Color("#f77f00"))
			_view.draw_circle(c + Vector2(s * 0.15, s * 0.12), s * 0.2, Color("#ffd60a"))
			_view.draw_line(c + Vector2(-s * 0.55, -s * 0.5), c + Vector2(-s * 0.1, -s * 0.1), Color(1, 0.5, 0.1, 0.7), s * 0.15)
		"pocion":
			_view.draw_circle(c + Vector2(0, s * 0.15), s * 0.38, Color("#ef476f"))
			_view.draw_rect(Rect2(c + Vector2(-s * 0.1, -s * 0.5), Vector2(s * 0.2, s * 0.35)), Color("#cfd8dc"))
		"estudio":
			_view.draw_rect(Rect2(c + Vector2(-s * 0.5, -s * 0.35), Vector2(s * 0.48, s * 0.7)), Color("#f1faee"))
			_view.draw_rect(Rect2(c + Vector2(s * 0.02, -s * 0.35), Vector2(s * 0.48, s * 0.7)), Color("#e9edc9"))
			_view.draw_line(c + Vector2(0, -s * 0.35), c + Vector2(0, s * 0.35), Color("#8d6e63"), 3.0)
		"bendicion":
			var pts: PackedVector2Array = PackedVector2Array()
			for i: int in 10:
				var a: float = -PI * 0.5 + TAU * float(i) / 10.0
				pts.append(c + Vector2(cos(a), sin(a)) * s * (0.55 if i % 2 == 0 else 0.22))
			_view.draw_colored_polygon(pts, Color("#ffd166"))


func _minion(r: Rect2, m: Dictionary, side: int, glow: bool) -> void:
	var base: Color = Color("#5c4d7d") if side == 1 else Color("#7d4d4d")
	if str(m.get("kw", "")) == "taunt":
		_view.draw_rect(r.grow(4.0), Color("#adb5bd"))
	if glow:
		_view.draw_rect(r.grow(7.0 + 2.0 * sin(_t * 7.0)), Color(0.4, 1.0, 0.5, 0.7))
	_view.draw_rect(Rect2(r.position + Vector2(0, 4), r.size), Color(0, 0, 0, 0.35))
	_view.draw_rect(r, base)
	## Retrato con el dibujo de la carta.
	var pc: Vector2 = r.position + Vector2(r.size.x * 0.5, r.size.y * 0.42)
	_view.draw_circle(pc, r.size.x * 0.36, base.lightened(0.25))
	_art(pc, r.size.x * 0.4, str(m["id"]))
	if bool(m.get("shield", false)):
		_view.draw_arc(pc, r.size.x * 0.42 + 2.0 * sin(_t * 5.0), 0.0, TAU, 24, Color("#ffd166"), 4.0)
	_text(Vector2(r.position.x, r.position.y + 20), Kit.text("cc_" + str(m["id"]), str(m["id"]).capitalize()), 15, Color.WHITE, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	_stats(r, int(m["atk"]), int(m["hp"]), int(m["hp"]) < int(m["max"]))


func _hero(r: Rect2, side: int, glow: bool) -> void:
	var p: Dictionary = st["p"][side]
	var c: Vector2 = r.get_center()
	if glow:
		_view.draw_circle(c, r.size.x * 0.56 + 2.0 * sin(_t * 7.0), Color(1.0, 0.35, 0.3, 0.7))
	_view.draw_circle(c, r.size.x * 0.5, Color("#3a86ff") if side == 1 else Color("#e63946"))
	_view.draw_circle(c, r.size.x * 0.44, Color("#22223b"))
	if side == 1 and _hero_tex != null:
		var ts: Vector2 = _hero_tex.get_size()
		var k: float = r.size.x * 0.75 / maxf(ts.x, ts.y)
		_view.draw_texture_rect(_hero_tex, Rect2(c - ts * k * 0.5, ts * k), false)
	elif side == 2:
		_view.draw_rect(Rect2(c - Vector2(30, 20), Vector2(60, 40)), Color("#0d0d12"))
		_view.draw_circle(c + Vector2(-13, -2), 6, Color("#ff6b6b"))
		_view.draw_circle(c + Vector2(13, -2), 6, Color("#ff6b6b"))
	_view.draw_circle(r.end - Vector2(14, 14), 22, Color("#e63946"))
	_text(r.end - Vector2(36, 6), str(int(p["hp"])), 24, Color.WHITE, 44, HORIZONTAL_ALIGNMENT_CENTER)
	## Mana.
	for k2: int in int(p["max_mana"]):
		var mp: Vector2 = Vector2(r.end.x + 22 + float(k2 % 5) * 26, r.position.y + 30 + float(k2 / 5) * 28)
		_view.draw_circle(mp, 10, Color("#4cc9f0") if k2 < int(p["mana"]) else Color("#33415c"))


func _draw_view() -> void:
	if st.is_empty():
		return
	var me: Dictionary = st["p"][1]
	var foe: Dictionary = st["p"][2]
	## Mesa de madera con tapete.
	var table: Rect2 = Rect2(Vector2(0, _view.size.y * 0.18), Vector2(_view.size.x, _view.size.y * 0.38))
	_view.draw_rect(table, Color("#4a3728"))
	for k0: int in 9:
		_view.draw_line(Vector2(0, table.position.y + table.size.y * float(k0) / 8.0), Vector2(_view.size.x, table.position.y + table.size.y * float(k0) / 8.0 + 6.0), Color(0, 0, 0, 0.12), 2.0)
	_view.draw_rect(table.grow(-10.0), Color("#2d6a4f"))
	_view.draw_rect(table.grow(-10.0), Color("#b08968"), false, 4.0)
	_view.draw_line(Vector2(30, _view.size.y * 0.375), Vector2(_view.size.x - 30, _view.size.y * 0.375), Color(1, 1, 1, 0.18), 2.0)
	## Objetivos validos de lo elegido, para iluminarlos.
	var tg_foe: Array = []
	var tg_foe_hero: bool = false
	var tg_mine: Array = []
	var tg_my_hero: bool = false
	if pick.has("minion"):
		for t: Variant in M.attack_targets(st, 1):
			if t.has("hero"):
				tg_foe_hero = true
			else:
				tg_foe.append(int(t["uid"]))
	elif pick.has("card"):
		var fx: String = str(M.CARDS[str(me["hand"][int(pick["card"])])]["fx"])
		if fx == "dmg":
			tg_foe_hero = true
			for m: Variant in foe["board"]:
				tg_foe.append(int(m["uid"]))
		else:
			tg_my_hero = fx == "heal"
			for m2: Variant in me["board"]:
				tg_mine.append(int(m2["uid"]))
	_hero(_foe_hero(), 2, tg_foe_hero)
	## Mano del rival (dorsos).
	for k: int in (foe["hand"] as Array).size():
		_view.draw_rect(Rect2(Vector2(14 + float(k) * 22, 20), Vector2(34, 48)), Color("#6c4f3d"))
		_view.draw_rect(Rect2(Vector2(14 + float(k) * 22, 20), Vector2(34, 48)), Color("#2b1d14"), false, 2.0)
	var fb: Array = foe["board"]
	for k3: int in fb.size():
		_minion(_slot(2, k3, fb.size()), fb[k3], 2, tg_foe.has(int(fb[k3]["uid"])))
	var mb: Array = me["board"]
	for k4: int in mb.size():
		var m3: Dictionary = mb[k4]
		var chosen: bool = pick.has("minion") and int(pick["minion"]) == int(m3["uid"])
		var r4: Rect2 = _slot(1, k4, mb.size())
		_minion(r4, m3, 1, tg_mine.has(int(m3["uid"])) or (can_act() and pick.is_empty() and bool(m3["ready"]) and int(m3["atk"]) > 0))
		if chosen:
			_view.draw_rect(r4.grow(9.0), Color("#ffd166"), false, 5.0)
	_hero(_my_hero(), 1, tg_my_hero)
	## Tu mano.
	var hand: Array = me["hand"]
	for i: int in hand.size():
		var cr: Rect2 = _card(i, hand.size())
		var id: String = hand[i]
		var c: Dictionary = M.CARDS[id]
		var can: bool = can_act() and int(c["cost"]) <= int(me["mana"])
		if pick.has("card") and int(pick["card"]) == i:
			cr = cr.grow(6.0)
			cr.position.y -= 18.0
		var tier: Color = Color("#adb5bd") if int(c["cost"]) <= 2 else (Color("#4895ef") if int(c["cost"]) <= 4 else (Color("#9d4edd") if int(c["cost"]) <= 6 else Color("#ffb703")))
		_view.draw_rect(Rect2(cr.position + Vector2(0, 5), cr.size), Color(0, 0, 0, 0.35))
		_view.draw_rect(cr, Color("#e9d8a6") if can else Color("#8d8370"))
		_view.draw_rect(cr, tier, false, 4.0)
		var ac: Vector2 = cr.position + Vector2(cr.size.x * 0.5, cr.size.y * 0.3)
		_view.draw_rect(Rect2(ac - Vector2(cr.size.x * 0.38, cr.size.y * 0.17), Vector2(cr.size.x * 0.76, cr.size.y * 0.34)), Color("#3d405b") if str(c["kind"]) == "minion" else Color("#5a189a"))
		_art(ac, cr.size.x * 0.28, id)
		_view.draw_circle(cr.position + Vector2(18, 18), 17, Color("#4cc9f0"))
		_text(cr.position + Vector2(1, 26), str(int(c["cost"])), 22, Color.WHITE, 34, HORIZONTAL_ALIGNMENT_CENTER)
		_text(Vector2(cr.position.x, cr.position.y + cr.size.y * 0.6), Kit.text("cc_" + id, id.capitalize()), 16, Color("#22223b"), cr.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		if str(c["kind"]) == "minion":
			var kw: String = str(c.get("kw", ""))
			if kw != "":
				_text(Vector2(cr.position.x, cr.position.y + cr.size.y * 0.75), Kit.text("cc_kw_" + kw, {"taunt": "Provocar", "charge": "Carga", "shield": "Escudo"}[kw]), 15,
					Color("#6a040f"), cr.size.x, HORIZONTAL_ALIGNMENT_CENTER)
			_stats(cr, int(c["atk"]), int(c["hp"]), false)
		else:
			var fx: String = str(c["fx"])
			_text(Vector2(cr.position.x, cr.position.y + cr.size.y * 0.82), Kit.text("cc_fx_" + fx, str(FX_TXT[fx])).format({"n": int(c["n"])}), 17,
				Color("#3c096c"), cr.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	for h: Variant in _hits:
		var hd: Dictionary = h
		var tt: float = float(hd["t"]) / 0.8
		if str(hd["k"]) == "hit":
			for a: int in 8:
				var an: float = TAU * float(a) / 8.0
				_view.draw_line(hd["at"], (hd["at"] as Vector2) + Vector2(cos(an), sin(an)) * (14.0 + 40.0 * tt), Color(1, 0.85, 0.3, 1.0 - tt), 4.0)
			_text((hd["at"] as Vector2) + Vector2(-16, -20.0 - 40.0 * tt), "-%d" % int(hd["n"]), 30, Color("#ff6b6b"))
		else:
			for a2: int in 10:
				var an2: float = TAU * float(a2) / 10.0
				_view.draw_circle((hd["at"] as Vector2) + Vector2(cos(an2), sin(an2)) * (10.0 + 60.0 * tt), 9.0 * (1.0 - tt), Color(0.8, 0.8, 0.8, 1.0 - tt))
	for f: Variant in _floats:
		var fd: Dictionary = f
		var at: Rect2 = _foe_hero() if str(fd["at"]) == "foe" else _my_hero()
		_text(at.get_center() + Vector2(50, -float(fd["t"]) * 40.0), str(fd["txt"]), 34, Color("#ffd166") if str(fd["at"]) == "foe" else Color("#ff6b6b"))


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	coins = 1
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = 500 + int(st["p"][1]["hp"]) * 30 + maxi(0, 20 - int(st["turn"])) * 20
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "turns": int(st["turn"]), "time": snappedf(time_in_level, 0.1)})
	Audio.play("win")
	Audio.play_track("victoria", false)
	var card: String = CcgCollection.reward(Kit.level_index)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": 1, "coins_total": 1, "score": score, "record": record})
	## Carta nueva para tu coleccion (se pone en el mazo desde la portada).
	if card != "" and result_panel.body != null:
		var nc: Label = Label.new()
		nc.name = "NewCard"
		nc.text = Kit.text("cc_new_card", "\u00a1Carta nueva: {c}! M\u00e9tela en tu mazo desde la portada.").format({"c": CcgCollection.card_name(card)})
		nc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nc.add_theme_color_override("font_color", Color("#ffd166"))
		result_panel.body.add_child(nc)
		result_panel.body.move_child(nc, mini(2, result_panel.body.get_child_count() - 1))
	await Ads.show_interstitial("level_end")


## Estrellas por la vida que te queda.
func stars_earned() -> int:
	var f: float = float(st["p"][1]["hp"]) / float(st["p"][1]["max_hp"])
	return 3 if f >= 0.6 else (2 if f >= 0.3 else 1)


func _lose() -> void:
	if failed:
		return
	finished = true
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "ccg", "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("cc_lost", "\u00a1Derrota!"),
		Kit.text("cc_hint", "Gasta todo tu mana cada turno, cambia esbirros cuando ganes el cambio y guarda el dano directo para rematar."))
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
		"turn": int(st.get("turn", 0))}
