extends Node2D
## Batalla automatica: en la fase de compra tocas una carta de la tienda para comprarla, tocas una
## unidad (banquillo o tablero) y luego una casilla de tu mitad para colocarla. "A luchar" y pelean
## solas. Tres iguales se funden en una mejor. Reglas, combate, bot y analizador en autochess_map.gd.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const M = preload("res://kit/autochess/autochess_map.gd")
const STEP: float = 0.1
const COLS: Dictionary = {"warrior": "#e76f51", "archer": "#2a9d8f", "knight": "#8d99ae", "mage": "#9b5de5", "assassin": "#264653", "healer": "#f4a261"}

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
## "shop" (compras y colocas) o "fight" (pelean) o "result" (se ve quien gano).
var phase: String = "shop"
var selected: int = -1

var _view: Control
var _info: Label
var _reroll: Button
var _sell: Button
var _fight: Button
var _fs: Array = []
var _shown: Dictionary = {}
var _acc: float = 0.0
var _fight_t: float = 0.0
var _result_t: float = 0.0
var _floats: Array = []
## Golpes y disparos en vuelo durante la pelea (de quien a quien).
var _shots: Array = []
var _t: float = 0.0


const TYPE_NAMES: Dictionary = {"warrior": "Guerreros", "archer": "Arqueras", "knight": "Caballeros", "mage": "Magos", "assassin": "Asesinas", "healer": "Sanadoras"}
## Velocidad del combate elegida por el jugador.
var speed: int = clampi(int(Save.get_setting("ac_speed", 1)), 1, 3)
var _speed_btn: Button

func _ready() -> void:
	level = Kit.current_level()
	RenderingServer.set_default_clear_color(Color("#1d1b2c"))
	_build_hud()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "autochess", "rounds": coins_total})


func wants_grade() -> bool:
	return false


func bot_script() -> String:
	return "res://qa/autochess_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(3.0, 1.5)


func _reset() -> void:
	finished = false
	failed = false
	st = M.new_state(level)
	coins_total = (st["rounds"] as Array).size()
	coins = 0
	time_in_level = 0.0
	phase = "shop"
	selected = -1
	_fs = []
	_floats = []
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
	_info.add_theme_font_size_override("font_size", 26)
	_info.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_info.add_theme_constant_override("outline_size", 6)
	top.add_child(_info)
	## Velocidad del combate (x1, x2, x3; se recuerda).
	_speed_btn = UI.make_button("x%d" % speed, false, "")
	_speed_btn.name = "BtnSpeed"
	_speed_btn.custom_minimum_size = Vector2(UI.MIN_TOUCH + 8.0, UI.MIN_TOUCH)
	_speed_btn.pressed.connect(cycle_speed)
	top.add_child(_speed_btn)
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
	var bottom: HBoxContainer = HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	col.add_child(bottom)
	_reroll = UI.make_button(Kit.text("ac_reroll", "Rehacer") + " %d" % M.REROLL, false, "")
	_reroll.name = "BtnReroll"
	_reroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reroll.custom_minimum_size = Vector2(0, _reroll.custom_minimum_size.y)
	_reroll.clip_text = true
	_reroll.pressed.connect(func() -> void:
		if can_shop() and M.reroll(st):
			_sfx("click", -8.0)
			_refresh())
	bottom.add_child(_reroll)
	_sell = UI.make_button(Kit.text("ac_sell", "Vender"), false, "")
	_sell.name = "BtnSell"
	_sell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sell.custom_minimum_size = Vector2(0, _sell.custom_minimum_size.y)
	_sell.clip_text = true
	_sell.pressed.connect(func() -> void:
		if can_shop() and selected >= 0 and M.sell(st, selected):
			selected = -1
			_sfx("coin", -8.0)
			_refresh())
	bottom.add_child(_sell)
	_fight = UI.make_button(Kit.text("ac_fight", "Luchar"), true, "")
	_fight.name = "BtnFight"
	_fight.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fight.custom_minimum_size = Vector2(0, _fight.custom_minimum_size.y)
	_fight.clip_text = true
	_fight.pressed.connect(start_fight)
	bottom.add_child(_fight)


func cycle_speed() -> void:
	speed = speed % 3 + 1
	Save.set_setting("ac_speed", speed)
	_speed_btn.text = "x%d" % speed
	_sfx("click", -10.0)


func can_shop() -> bool:
	return not finished and is_inside_tree() and not get_tree().paused and phase == "shop" and not bool(st["won"]) and not bool(st["lost"])


func _refresh() -> void:
	if st.is_empty() or _info == null:
		return
	var txt: String = Kit.text("ac_round", "Ronda {a}/{b}").format({"a": mini(int(st["round"]) + 1, coins_total), "b": coins_total})
	txt += "   " + Kit.text("ac_gold", "Oro {n}").format({"n": int(st["gold"])}) + "   \u2665 " + str(int(st["lives"]))
	txt += "\n" + Kit.text("ac_slots", "En el tablero {a}/{b}").format({"a": (st["board"] as Array).size(), "b": int(st["slots"])})
	## Sinergias activas (2 del mismo tipo en el tablero).
	var syn: Array = M.synergies(st)
	if not syn.is_empty():
		var parts: Array[String] = []
		for t: Variant in syn:
			parts.append(Kit.text("ac_t_" + str(t), str(TYPE_NAMES.get(t, t))) + " " + M.synergy_text(str(t)))
		txt += "\n\u2605 " + ", ".join(parts)
	_info.text = txt
	_reroll.disabled = not can_shop() or int(st["gold"]) < M.REROLL
	_sell.disabled = not can_shop() or selected < 0
	_fight.disabled = not can_shop() or (st["board"] as Array).is_empty()
	_view.queue_redraw()


# ------------------------------------------------------------------ rejilla de la pantalla

func _cell() -> float:
	return minf((_view.size.x - 8.0) / float(M.W), (_view.size.y - 8.0) / (float(M.H) + 3.4))


func _board() -> Rect2:
	var cs: float = _cell()
	var w: float = cs * float(M.W)
	return Rect2(Vector2((_view.size.x - w) * 0.5, 0.0), Vector2(w, cs * float(M.H)))


func _bench_rect(i: int) -> Rect2:
	var b: Rect2 = _board()
	var cs: float = _cell()
	return Rect2(Vector2(b.position.x + cs * float(i), b.end.y + cs * 0.15), Vector2(cs, cs))


func _shop_rect(i: int) -> Rect2:
	var b: Rect2 = _board()
	var w: float = b.size.x / float(M.SHOP)
	var cs: float = _cell()
	return Rect2(Vector2(b.position.x + w * float(i), b.end.y + cs * 1.3), Vector2(w, cs * 1.9)).grow(-4.0)


# ------------------------------------------------------------------ acciones

func buy(i: int) -> void:
	if can_shop() and M.buy(st, i):
		_sfx("coin", -8.0)
		_refresh()


func tap_board(c: Vector2i) -> void:
	if not can_shop():
		return
	if selected >= 0 and M.place(st, selected, c):
		selected = -1
		_sfx("click", -10.0)
		_refresh()
		return
	for u: Variant in st["board"]:
		if int(u["x"]) == c.x and int(u["y"]) == c.y:
			selected = int(u["id"])
			_refresh()
			return
	selected = -1
	_refresh()


func tap_bench(i: int) -> void:
	if not can_shop():
		return
	var bench: Array = st["bench"]
	if i < bench.size():
		selected = int(bench[i]["id"])
	elif selected >= 0:
		M.unplace(st, selected)
		selected = -1
	_refresh()


func start_fight() -> void:
	if not can_shop() or (st["board"] as Array).is_empty():
		return
	selected = -1
	_fs = M.fighters(st)
	_shown.clear()
	for f: Variant in _fs:
		_shown[int(f["id"])] = f["pos"]
	_acc = 0.0
	_fight_t = 0.0
	phase = "fight"
	_sfx("powerup", -8.0)
	_refresh()


func _end_fight(w: int) -> void:
	phase = "result"
	_result_t = 1.2
	M.finish_round(st, w)
	coins = int(st["round"]) if not bool(st["won"]) else coins_total
	_sfx("win" if w == 1 else "hurt", -6.0)
	_refresh()


func bot_step() -> void:
	if can_shop():
		M.bot_shop(st)
		_refresh()
		start_fight()


# ------------------------------------------------------------------ bucle

func _physics_process(delta: float) -> void:
	if st.is_empty() or get_tree().paused:
		return
	_t += delta
	if not finished:
		time_in_level += delta
	if phase == "fight":
		_acc += delta * (40.0 if fast else float(speed))
		while _acc >= STEP and phase == "fight":
			_acc -= STEP
			_fight_t += STEP
			for e: Variant in M.battle_step(_fs, STEP):
				if not fast:
					_floats.append({"id": int(e["b"]), "n": int(e["n"]), "heal": str(e["k"]) == "heal", "t": 0.0})
					_shots.append({"a": int(e["a"]), "b": int(e["b"]), "heal": str(e["k"]) == "heal", "t": 0.0})
			var w: int = M.winner(_fs)
			if w == 0 and _fight_t >= 39.95:
				w = M.hp_winner(_fs)
			if w != 0:
				_end_fight(w)
	elif phase == "result":
		_result_t -= delta * (20.0 if fast else float(speed))
		if _result_t <= 0.0:
			if bool(st["won"]):
				_finish()
			elif bool(st["lost"]):
				_lose()
			else:
				phase = "shop"
				_fs = []
				_refresh()
	elif fast and auto_retry and not finished:
		bot_step()
	for f: Variant in _fs:
		var id: int = int(f["id"])
		_shown[id] = (_shown.get(id, f["pos"]) as Vector2).lerp(f["pos"], minf(1.0, delta * 12.0))
	for fl: Variant in _floats:
		(fl as Dictionary)["t"] = float((fl as Dictionary)["t"]) + delta
	_floats = _floats.filter(func(fl: Dictionary) -> bool: return float(fl["t"]) < 0.8)
	for sh: Variant in _shots:
		(sh as Dictionary)["t"] = float((sh as Dictionary)["t"]) + delta
	_shots = _shots.filter(func(sh: Dictionary) -> bool: return float(sh["t"]) < 0.3)
	_view.queue_redraw()


func _on_input(event: InputEvent) -> void:
	var p: Vector2 = Vector2.INF
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		p = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and not DisplayServer.is_touchscreen_available():
		p = (event as InputEventMouseButton).position
	if p == Vector2.INF:
		return
	var b: Rect2 = _board()
	if b.has_point(p):
		var q: Vector2 = (p - b.position) / _cell()
		tap_board(Vector2i(int(q.x), int(q.y)))
		return
	for i: int in M.BENCH:
		if _bench_rect(i).has_point(p):
			tap_bench(i)
			return
	for k: int in M.SHOP:
		if _shop_rect(k).has_point(p):
			buy(k)
			return


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()


func _sfx(nm: String, vol: float = -6.0) -> void:
	if not fast:
		Audio.play(nm, 0.1, vol)


# ------------------------------------------------------------------ dibujo

func _icon(c: Vector2, t: String, r: float, ink: Color) -> void:
	match t:
		"warrior":
			_view.draw_line(c + Vector2(-r * 0.4, r * 0.4), c + Vector2(r * 0.4, -r * 0.4), ink, r * 0.18)
			_view.draw_line(c + Vector2(-r * 0.15, r * 0.05), c + Vector2(r * 0.05, r * 0.25), ink, r * 0.14)
		"archer":
			_view.draw_arc(c + Vector2(-r * 0.15, 0), r * 0.45, -PI * 0.45, PI * 0.45, 12, ink, r * 0.12)
			_view.draw_line(c + Vector2(-r * 0.2, 0), c + Vector2(r * 0.45, 0), ink, r * 0.08)
		"knight":
			_view.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.35, -r * 0.4), c + Vector2(r * 0.35, -r * 0.4), c + Vector2(r * 0.35, r * 0.05),
				c + Vector2(0, r * 0.45), c + Vector2(-r * 0.35, r * 0.05)]), ink)
		"mage":
			var pts: PackedVector2Array = PackedVector2Array()
			for k: int in 10:
				var a: float = -PI * 0.5 + PI * float(k) / 5.0
				pts.append(c + Vector2(cos(a), sin(a)) * (r * 0.45 if k % 2 == 0 else r * 0.2))
			_view.draw_colored_polygon(pts, ink)
		"assassin":
			_view.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 0.5), c + Vector2(r * 0.15, r * 0.25), c + Vector2(-r * 0.15, r * 0.25)]), ink)
			_view.draw_line(c + Vector2(-r * 0.3, r * 0.25), c + Vector2(r * 0.3, r * 0.25), ink, r * 0.1)
		"healer":
			_view.draw_rect(Rect2(c - Vector2(r * 0.12, r * 0.42), Vector2(r * 0.24, r * 0.84)), ink)
			_view.draw_rect(Rect2(c - Vector2(r * 0.42, r * 0.12), Vector2(r * 0.84, r * 0.24)), ink)


func _token(c: Vector2, t: String, stars: int, side: int, r: float, hp: float, sel: bool) -> void:
	var ring: Color = Color("#3a86ff") if side == 1 else Color("#e63946")
	if sel:
		_view.draw_circle(c, r + 7.0 + 2.0 * sin(_t * 8.0), Color(1, 0.9, 0.3, 0.85))
	_view.draw_circle(c + Vector2(2, 4), r, Color(0, 0, 0, 0.35))
	_view.draw_circle(c, r, ring)
	_view.draw_circle(c, r * 0.84, Color(str(COLS.get(t, "#888888"))))
	_icon(c, t, r, Color("#fdfdfd"))
	for s: int in stars:
		var sx: float = (float(s) - float(stars - 1) * 0.5) * r * 0.42
		_view.draw_circle(c + Vector2(sx, -r * 1.05), r * 0.17, Color("#ffd166"))
	if hp >= 0.0 and hp < 1.0:
		var bw: float = r * 1.8
		_view.draw_rect(Rect2(c + Vector2(-bw * 0.5, r * 1.02), Vector2(bw, 6)), Color(0, 0, 0, 0.6))
		_view.draw_rect(Rect2(c + Vector2(-bw * 0.5, r * 1.02), Vector2(bw * maxf(0.0, hp), 6)), Color("#06d6a0") if side == 1 else Color("#ef476f"))


func _draw_view() -> void:
	if st.is_empty():
		return
	var b: Rect2 = _board()
	var cs: float = _cell()
	var font: Font = _view.get_theme_font("font", "Label")
	for y: int in M.H:
		for x: int in M.W:
			var mine: bool = y >= M.H / 2
			var base: Color = Color("#3d405b") if mine else Color("#4a2f3d")
			if (x + y) % 2 == 0:
				base = base.lightened(0.06)
			_view.draw_rect(Rect2(b.position + Vector2(x, y) * cs, Vector2(cs, cs)), base)
	_view.draw_line(b.position + Vector2(0, cs * float(M.H / 2)), b.position + Vector2(b.size.x, cs * float(M.H / 2)), Color(1, 1, 1, 0.3), 3.0)
	var r: float = cs * 0.4
	if phase == "shop":
		## Rival de esta ronda (en gris claro: lo que te espera).
		var rounds: Array = st["rounds"]
		if int(st["round"]) < rounds.size():
			for e: Variant in rounds[int(st["round"])]:
				var ec: Vector2 = b.position + (Vector2(int(e["x"]), int(e["y"])) + Vector2(0.5, 0.5)) * cs
				_token(ec, str(e["t"]), int(e.get("s", 1)), 2, r, -1.0, false)
		for u: Variant in st["board"]:
			var c: Vector2 = b.position + (Vector2(int(u["x"]), int(u["y"])) + Vector2(0.5, 0.5)) * cs
			_token(c, str(u["t"]), int(u["s"]), 1, r, -1.0, int(u["id"]) == selected)
	else:
		for f: Variant in _fs:
			if float(f["hp"]) <= 0.0:
				continue
			var pos: Vector2 = b.position + (_shown.get(int(f["id"]), f["pos"]) as Vector2) * cs
			_token(pos, str(f["t"]), int(f["s"]), int(f["side"]), r, float(f["hp"]) / float(f["max"]), false)
			if float(f["hit"]) > 0.0:
				_view.draw_circle(pos, r, Color(1, 1, 1, float(f["hit"]) * 2.5))
		## Disparos (arqueras, magos y curanderos) y tajos (cuerpo a cuerpo).
		var where: Dictionary = {}
		for f3: Variant in _fs:
			where[int(f3["id"])] = [b.position + (_shown.get(int(f3["id"]), f3["pos"]) as Vector2) * cs, str(f3["t"]), int(f3["side"])]
		for sh: Variant in _shots:
			var sd: Dictionary = sh
			if not where.has(int(sd["a"])) or not where.has(int(sd["b"])):
				continue
			var pa: Vector2 = where[int(sd["a"])][0]
			var pb: Vector2 = where[int(sd["b"])][0]
			var kind: String = str(where[int(sd["a"])][1])
			var tt: float = float(sd["t"]) / 0.3
			if bool(sd["heal"]):
				_view.draw_circle(pb, r * (0.6 + tt), Color(0.4, 1.0, 0.6, 0.5 * (1.0 - tt)))
			elif kind in ["archer", "mage"]:
				var pp: Vector2 = pa.lerp(pb, tt)
				var pc: Color = Color("#ffd166") if kind == "archer" else Color("#b388ff")
				_view.draw_line(pp - (pb - pa).normalized() * r * 0.6, pp, pc, 5.0)
				_view.draw_circle(pp, 6.0 if kind == "mage" else 3.0, pc)
			else:
				var dir: Vector2 = (pb - pa).normalized()
				_view.draw_arc(pb - dir * r * 0.4, r * 0.8, dir.angle() - 1.0, dir.angle() + 1.0, 10, Color(1, 1, 1, 1.0 - tt), 5.0)
		for fl: Variant in _floats:
			var fd: Dictionary = fl
			for f2: Variant in _fs:
				if int(f2["id"]) == int(fd["id"]):
					var fp: Vector2 = b.position + (_shown.get(int(f2["id"]), f2["pos"]) as Vector2) * cs + Vector2(r * 0.5, -r - float(fd["t"]) * 40.0)
					_view.draw_string(font, fp, ("+" if bool(fd["heal"]) else "-") + str(int(fd["n"])), HORIZONTAL_ALIGNMENT_LEFT, -1, 22,
						Color("#06d6a0") if bool(fd["heal"]) else Color("#ffd166"))
		if phase == "result":
			var won_r: bool = str(st["last"]) == "win"
			var msg: String = Kit.text("ac_won", "\u00a1Ronda ganada!") if won_r else Kit.text("ac_lost_round", "Ronda perdida: -1 vida")
			_view.draw_string_outline(font, Vector2(b.position.x, b.get_center().y), msg, HORIZONTAL_ALIGNMENT_CENTER, b.size.x, 44, 10, Color.BLACK)
			_view.draw_string(font, Vector2(b.position.x, b.get_center().y), msg, HORIZONTAL_ALIGNMENT_CENTER, b.size.x, 44,
				Color("#06d6a0") if won_r else Color("#ef476f"))
	## Banquillo.
	var bench: Array = st["bench"]
	for i: int in M.BENCH:
		var br: Rect2 = _bench_rect(i)
		_view.draw_rect(br.grow(-3.0), Color(1, 1, 1, 0.08))
		if i < bench.size():
			var bu: Dictionary = bench[i]
			_token(br.get_center(), str(bu["t"]), int(bu["s"]), 1, r * 0.85, -1.0, int(bu["id"]) == selected)
	## Tienda.
	var shop: Array = st["shop"]
	for k: int in shop.size():
		var sr: Rect2 = _shop_rect(k)
		var t: String = str(shop[k])
		if t == "":
			_view.draw_rect(sr, Color(1, 1, 1, 0.05))
			continue
		var cost: int = int(M.TYPES[t]["cost"])
		var can: bool = int(st["gold"]) >= cost and phase == "shop"
		_view.draw_rect(sr, Color("#2b2d42") if can else Color("#2b2d42").darkened(0.4))
		_view.draw_rect(sr, Color("#ffd166") if M._count(st, t, 1) >= 2 else Color(1, 1, 1, 0.25), false, 3.0)
		_token(sr.get_center() - Vector2(0, sr.size.y * 0.12), t, 1, 1, sr.size.x * 0.3, -1.0, false)
		_view.draw_string(font, Vector2(sr.position.x, sr.end.y - 10.0), "%d" % cost, HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, 26,
			Color("#ffd166") if can else Color(1, 1, 1, 0.4))


# ------------------------------------------------------------------ final

func _finish() -> void:
	if finished:
		return
	finished = true
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = 500 + int(st["lives"]) * 300 + int(st["gold"]) * 10
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "lives": int(st["lives"]), "time": snappedf(time_in_level, 0.1)})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins_total, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


## Estrellas por las vidas que te quedan.
func stars_earned() -> int:
	return clampi(int(st["lives"]), 1, 3)


func _lose() -> void:
	if failed:
		return
	finished = true
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "autochess", "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("ac_lost", "\u00a1Sin vidas!"),
		Kit.text("ac_hint", "Compra copias de lo que ya tienes para fundirlas, pon tanques delante y arqueros y magos detras."))
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
		"round": int(st.get("round", 0)), "lives": int(st.get("lives", 0))}
