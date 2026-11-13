extends Node2D
## Topos: los enemigos del juego asoman por agujeros y hay que aplastarlos antes de que se escondan.
## 1 - Toca al que asoma: +1. El de pinchos (spiky) necesita dos toques; el volador (flyer) se
##     esconde antes. El heroe tambien asoma: si lo aplastas pierdes un corazon.
## 2 - Ganas al llegar a los golpes del nivel antes de que acabe el tiempo.
## 3 - Pierdes si se acaba el tiempo o te quedas sin corazones.
## 4 - Giro dorado (level.golden): a veces asoma un bicho de oro que se va antes y vale 3 golpes.
## Mapa: filas con "o" (agujero) y "." (nada). Nivel: {"map", "duration", "target", "pop",
##   "interval", "max_up", "friend"} (segundos y proporcion de veces que asoma el heroe).
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const REVIVE_SECS: float = 10.0
const CELL: float = 210.0
const HEARTS: int = 3

var rows: Array[String] = []
var holes: Array[Vector2] = []
var finished: bool = false
var failed: bool = false
var deaths: int = 0
var time_in_level: float = 0.0
var coins: int = 0
var coins_total: int = 0
var fast: bool = false
var auto_retry: bool = false
var result_panel: ResultPanel

var duration: float = 40.0
var target: int = 20
var pop_time: float = 1.2
var interval: float = 0.8
var max_up: int = 2
var friend_ratio: float = 0.15
var golden: bool = false
var golden_hits: int = 0
var time_left: float = 40.0
var hits: int = 0
var hearts: int = HEARTS
var misses: int = 0
var streak: int = 0
## hueco -> {"node", "kind", "hp", "left"}
var up: Dictionary = {}

var _spawn_left: float = 0.5
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _arts: Dictionary = {}
var _board: Node2D
var _camera: Camera2D
var _hit_label: Label
var _time_label: Label
var _hearts_box: HBoxContainer


func _ready() -> void:
	var lv: Dictionary = Kit.current_level()
	for r: Variant in lv.get("map", ["ooo", "ooo", "ooo"]):
		rows.append(str(r))
	duration = float(lv.get("duration", 40.0))
	target = int(lv.get("target", 20))
	pop_time = float(lv.get("pop", 1.2))
	interval = float(lv.get("interval", 0.8))
	max_up = int(lv.get("max_up", 2))
	friend_ratio = float(lv.get("friend", 0.15))
	golden = bool(lv.get("golden", false))
	coins_total = target
	for y: int in rows.size():
		for x: int in rows[y].length():
			if rows[y][x] == "o":
				holes.append((Vector2(x, y) + Vector2(0.5, 0.5)) * CELL)
	RenderingServer.set_default_clear_color(Kit.color("sky", Color("#1b2a41")))
	for t: String in ["walker", "spiky", "flyer"]:
		var id: String = str(Kit.param("art.enemies." + t, ""))
		var entry: Dictionary = Kit.sprite_entry(id) if id != "" else {}
		if entry.is_empty() and id != "":
			entry = Kit.sprite_by_role("enemigo")
		if id != "":
			_arts[t] = entry
	if _arts.is_empty():
		_arts["walker"] = Kit.sprite_by_role("enemigo")
	_arts["friend"] = Kit.sprite_by_role("jugador")
	_board = Node2D.new()
	_board.name = "Board"
	_board.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_board.draw.connect(_draw_board)
	add_child(_board)
	_camera = Camera2D.new()
	add_child(_camera)
	_camera.make_current()
	Juice.register_camera(_camera)
	_fit_camera()
	_build_hud()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "moles", "holes": holes.size(), "target": target})


func bot_script() -> String:
	return "res://qa/moles_bot.gd"


func _fit_camera() -> void:
	var w: float = float(rows[0].length() if not rows.is_empty() else 3) * CELL
	var h: float = float(rows.size()) * CELL
	var vp: Vector2 = get_viewport_rect().size
	var z: float = minf(vp.x / (w + 40.0), vp.y * 0.7 / (h + 40.0))
	_camera.zoom = Vector2.ONE * minf(z, 1.4)
	_camera.position = Vector2(w, h) * 0.5 + Vector2(0.0, -CELL * 0.1)


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
	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 12)
	col.add_child(top)
	_hearts_box = HBoxContainer.new()
	_hearts_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_hearts_box)
	_hit_label = Label.new()
	_hit_label.name = "Hits"
	_hit_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_hit_label)
	_time_label = Label.new()
	_time_label.name = "Time"
	_time_label.add_theme_color_override("font_color", UI.colors["acento"])
	top.add_child(_time_label)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)
	var grow: Control = Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(grow)
	var hint: Label = Label.new()
	hint.name = "Hint"
	hint.text = Kit.text("moles_hint", "Toca a los que asoman. \u00a1Al h\u00e9roe no!")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", UI.colors["texto_suave"])
	col.add_child(hint)


func _reset() -> void:
	finished = false
	failed = false
	hits = 0
	coins = 0
	misses = 0
	streak = 0
	hearts = HEARTS
	time_left = duration
	_spawn_left = 0.6
	_rng.seed = 1000 + Kit.level_index * 77
	for h: int in up.keys():
		(up[h]["node"] as Node2D).queue_free()
	up.clear()
	_update_hud()


func _update_hud() -> void:
	_hit_label.text = "%d/%d" % [hits, target]
	_time_label.text = "%d s" % ceili(maxf(time_left, 0.0))
	for c: Node in _hearts_box.get_children():
		c.queue_free()
	for i: int in HEARTS:
		_hearts_box.add_child(UiIcon.make("heart" if i < hearts else "heart_empty", UI.colors["peligro"], 38.0))


# ------------------------------------------------------------------ bichos

func _spawn() -> void:
	var free: Array[int] = []
	for i: int in holes.size():
		if not up.has(i):
			free.append(i)
	if free.is_empty() or up.size() >= max_up:
		return
	var h: int = free[_rng.randi() % free.size()]
	var kind: String = "friend" if _rng.randf() < friend_ratio else _arts.keys().filter(func(k: String) -> bool: return k != "friend")[_rng.randi() % maxi(_arts.size() - 1, 1)]
	var n: Node2D = Node2D.new()
	n.z_index = 2
	n.position = holes[h] + Vector2(0.0, CELL * 0.18)
	var art: Dictionary = _arts.get(kind, {})
	if not art.is_empty():
		var spr: AnimatedSprite2D = SpriteKit.animado(art, CELL * 0.8, "idle", true)
		n.add_child(spr)
		if kind == "friend":
			Skins.apply(spr)
	else:
		var body: Polygon2D = Polygon2D.new()
		body.color = Kit.color("accent", Color.ORANGE) if kind == "friend" else Kit.color("enemy", Color("#d9774a"))
		body.polygon = LevelBuilder._circle(CELL * 0.26, 18)
		body.position = Vector2(0.0, -CELL * 0.26)
		n.add_child(body)
	## Sale de abajo: empieza escondido y sube.
	n.scale = Vector2(1.0, 0.1)
	add_child(n)
	var tw: Tween = n.create_tween()
	tw.tween_property(n, "scale", Vector2.ONE, 0.12 * (0.3 if fast else 1.0)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var stay: float = pop_time * (0.7 if kind == "flyer" else 1.0)
	var gold: bool = golden and kind != "friend" and _rng.randf() < 0.12
	if gold:
		## De oro: brilla, se va antes y vale 3 golpes de un toque.
		n.modulate = Color(1.0, 0.86, 0.3)
		var ring: Polygon2D = Polygon2D.new()
		ring.color = Color(1.0, 0.85, 0.2, 0.35)
		ring.polygon = LevelBuilder._circle(CELL * 0.4, 20)
		ring.position = Vector2(0.0, -CELL * 0.26)
		ring.z_index = -1
		n.add_child(ring)
		stay *= 0.75
	up[h] = {"node": n, "kind": kind, "hp": 1 if gold else (2 if kind == "spiky" else 1), "left": stay, "age": 0.0, "gold": gold}
	QA.log_event("mole_up", {"hole": h, "kind": kind})


func _hide(h: int, bonked: bool) -> void:
	var e: Dictionary = up[h]
	up.erase(h)
	var n: Node2D = e["node"]
	var tw: Tween = n.create_tween()
	if bonked:
		tw.tween_property(n, "scale", Vector2(1.3, 0.2), 0.12)
	else:
		tw.tween_property(n, "scale", Vector2(1.0, 0.05), 0.15)
	tw.tween_callback(n.queue_free)


## Golpe en el agujero h (lo que haya). Devuelve lo que habia ("" si nada).
func bonk(h: int) -> String:
	if finished or failed or get_tree().paused or not up.has(h):
		return ""
	var e: Dictionary = up[h]
	var kind: String = e["kind"]
	if kind == "friend":
		hearts -= 1
		streak = 0
		Audio.play("hurt")
		Juice.shake(0.35)
		UI.float_text(self, holes[h] + Vector2(0.0, -CELL * 0.5), Kit.text("moles_friend", "\u00a1Ay, que soy yo!"), UI.colors["peligro"], 32)
		_hide(h, true)
		_update_hud()
		if hearts <= 0:
			_lose("hearts")
		return kind
	e["hp"] = int(e["hp"]) - 1
	Juice.squash(e["node"] as Node2D, Vector2(1.25, 0.75))
	if int(e["hp"]) > 0:
		Audio.play("land", 0.1)
		return kind
	var worth: int = 3 if bool(e.get("gold", false)) else 1
	if worth > 1:
		golden_hits += 1
		UI.float_text(self, holes[h] + Vector2(0.0, -CELL * 0.55), "x3", Kit.color("coin", Color.YELLOW), 40)
	hits = mini(hits + worth, target)
	coins = hits
	streak += 1
	Audio.play("stomp", 0.1, 0.0, 1.0 + 0.04 * float(mini(streak, 8)))
	Juice.burst(self, holes[h] + Vector2(0.0, -CELL * 0.2), Kit.color("coin", Color.YELLOW), 10, 240.0)
	_hide(h, true)
	_update_hud()
	if hits >= target:
		_finish()
	return kind


func hole_at(world: Vector2) -> int:
	for i: int in holes.size():
		if world.distance_to(holes[i] + Vector2(0.0, -CELL * 0.15)) < CELL * 0.45:
			return i
	return -1


func _process(delta: float) -> void:
	if finished or failed or get_tree().paused:
		return
	time_in_level += delta
	time_left -= delta
	_spawn_left -= delta
	if _spawn_left <= 0.0:
		_spawn()
		_spawn_left = interval * _rng.randf_range(0.7, 1.3)
	for h: int in up.keys():
		var e: Dictionary = up[h]
		e["left"] = float(e["left"]) - delta
		e["age"] = float(e["age"]) + delta
		if float(e["left"]) <= 0.0:
			if e["kind"] != "friend":
				misses += 1
				streak = 0
			_hide(h, false)
	if int(time_in_level * 4.0) != int((time_in_level - delta) * 4.0):
		_update_hud()
	if time_left <= 0.0:
		_lose("time")


func _unhandled_input(event: InputEvent) -> void:
	if UI.test_mode:
		return
	var pressed: bool = (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed) \
		or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed)
	if pressed:
		var world: Vector2 = get_canvas_transform().affine_inverse() * (event as InputEventFromWindow).position
		var h: int = hole_at(world)
		if h >= 0:
			bonk(h)


# ------------------------------------------------------------------ final

func _finish() -> void:
	finished = true
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = hits * 100 + int(time_left) * 20 + hearts * 200
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "hits": hits, "time_left": time_left, "hearts": hearts, "stars": stars})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


## 3 estrellas sin perder corazones y con tiempo de sobra; 2 con un fallo; 1 si llegas justo.
func stars_earned() -> int:
	if hearts >= HEARTS and time_left >= duration * 0.15:
		return 3
	if hearts >= HEARTS - 1:
		return 2
	return 1


func _lose(cause: String) -> void:
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": cause, "hits": hits, "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry()
		return
	var title: String = Kit.text("moles_time", "\u00a1Se acab\u00f3 el tiempo!") if cause == "time" else Kit.text("moles_hearts", "\u00a1Sin corazones!")
	var p: FailPanel = FailPanel.open(self, title, Kit.text("moles_fail_hint", "Has aplastado {n} de {t}. \u00a1Otra vez!").format({"n": hits, "t": target}))
	p.closed.connect(retry)


## Segunda oportunidad (FailPanel, con anuncio): mas tiempo o un corazon, segun como perdiste.
func revive() -> void:
	if time_left <= 0.0:
		time_left = REVIVE_SECS
	else:
		hearts = maxi(hearts, 1)
	failed = false
	_update_hud()


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
	return {"deaths": deaths, "coins": coins, "finished": finished, "failed": failed, "stomps": hits,
		"hits": hits, "hearts": hearts, "time_left": time_left, "misses": misses}


func capture_delays() -> Vector2:
	return Vector2(4.0, 1.2)


# ------------------------------------------------------------------ dibujo

func _draw_board() -> void:
	## Cesped: el color solido del juego tirando a verde, a cuadros; agujeros con monticulo de tierra.
	var grass: Color = Kit.color("solid", Color("#3e5c84")).lerp(Color("#4e8a3a"), 0.75)
	var dirt: Color = Color("#6b4a32")
	var w: float = float(rows[0].length()) * CELL
	var h: float = float(rows.size()) * CELL
	var ltex: Texture2D = Kit.first_tile_texture()
	if ltex != null:
		## El suelo del mundo del juego (lo dibuja la IA), muy tenido de cesped: la losa de muchos juegos
		## es un muro de ladrillo y llenaba la pantalla (13 nov: «fondo_distrae»).
		## Una repeticion de la textura por casilla (a su tamano se veria diminuta).
		var k: float = CELL / maxf(float(ltex.get_width()), 1.0)
		_board.draw_rect(Rect2(Vector2(-CELL * 3.0, -CELL * 4.0), Vector2(w + CELL * 6.0, h + CELL * 8.0)), grass.darkened(0.08))
		_board.draw_set_transform(Vector2.ZERO, 0.0, Vector2(k, k))
		_board.draw_texture_rect(ltex, Rect2(Vector2(-CELL * 3.0, -CELL * 4.0) / k, Vector2(w + CELL * 6.0, h + CELL * 8.0) / k), true, Color(1, 1, 1, 0.2))
		_board.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		_board.draw_rect(Rect2(Vector2(-CELL * 3.0, -CELL * 4.0), Vector2(w + CELL * 6.0, h + CELL * 8.0)), grass.darkened(0.12))
	for y: int in range(-4, rows.size() + 4):
		for x: int in range(-3, rows[0].length() + 3):
			if (x + y) % 2 == 0:
				_board.draw_rect(Rect2(Vector2(x, y) * CELL, Vector2(CELL, CELL)), Color(0, 0, 0, 0.06) if ltex != null else grass.darkened(0.04))
	for p: Vector2 in holes:
		_board.draw_set_transform(p + Vector2(0.0, CELL * 0.2), 0.0, Vector2(1.0, 0.42))
		_board.draw_circle(Vector2.ZERO, CELL * 0.43, dirt)
		_board.draw_circle(Vector2(0.0, -CELL * 0.03), CELL * 0.34, dirt.darkened(0.6))
		_board.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
