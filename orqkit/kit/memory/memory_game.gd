extends Node2D
## Genero memoria: encuentra las parejas.
## 1 - Toca una carta para darle la vuelta y luego otra. Si son iguales, se quedan boca arriba.
##     Si no, se vuelven a tapar.
## 2 - Encuentra todas las parejas antes de gastar los intentos del nivel.
## 3 - Estrellas segun los intentos frente al par del nivel.
## 4 - Giro barajar (level.shuffle): cada 2 fallos, dos cartas tapadas se cambian de sitio a la
##     vista (se iluminan y se ve el cambio). last_swap y swaps lo cuentan (el bot lo ve igual).
## Los dibujos de las cartas salen del propio juego (el heroe, los enemigos, la moneda) y de
## figuras con los colores del juego. El orden de las cartas sale de la semilla del nivel.
## Mapa (game.json -> levels[i].map): "." hueco con carta, "#" sin carta (formas de tablero).
## Parametros: seed, par (intentos para 3 estrellas) y limit (intentos maximos).
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const REVIVE_N: int = 6
const MapRules = preload("res://kit/memory/memory_map.gd")
const SHAPES: Array[String] = ["circle", "star", "triangle", "heart", "diamond", "square", "hex", "moon", "cross", "drop", "bolt", "ring"]

var rows: Array[String] = []
var level: Dictionary = {}
var finished: bool = false
var failed: bool = false
var deaths: int = 0
var time_in_level: float = 0.0
var coins: int = 0
var coins_total: int = 0
var fast: bool = false
var auto_retry: bool = false
var result_panel: ResultPanel
## Estado que lee el bot: cards = [{"face": int, "pos": Vector2, "open": bool, "done": bool}].
var cards: Array[Dictionary] = []
var tries: int = 0
## Intentos de mas por la segunda oportunidad (se pierden al reintentar).
var extra_tries: int = 0
var pairs_left: int = 0
var first: int = -1
var busy: float = 0.0
var shuffle: bool = false
var misses: int = 0
var swaps: int = 0
var last_swap: Vector2i = Vector2i(-1, -1)
var _swap_glow: float = 0.0
var _swap_rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _view: Node2D
var _faces: Array[Dictionary] = []
var _goal_label: Label
var _tries_label: Label
var _card: Vector2 = Vector2(120, 150)
var _second: int = -1
var _flip_anim: Dictionary = {}


func _ready() -> void:
	level = Kit.current_level()
	shuffle = bool(level.get("shuffle", false))
	for r: Variant in level.get("map", []):
		rows.append(str(r))
	RenderingServer.set_default_clear_color(Kit.color("sky", Color("#1b2a41")))
	_view = Node2D.new()
	_view.name = "Board"
	_view.draw.connect(_draw_view)
	add_child(_view)
	var cam: Camera2D = Camera2D.new()
	cam.position = Vector2(360.0, 640.0)
	add_child(cam)
	cam.make_current()
	Juice.register_camera(cam)
	_build_hud()
	_build_faces()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "memory", "pairs": pairs_left})


## Los bots: QaBot juega este genero con el script que devuelve esta funcion.
func bot_script() -> String:
	return "res://qa/memory_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(3.0, 2.0)


func par() -> int:
	return int(level.get("par", 12))


func limit() -> int:
	return int(level.get("limit", 30)) + extra_tries


# ------------------------------------------------------------------ montaje

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
	_goal_label = Label.new()
	_goal_label.name = "Goal"
	_goal_label.theme_type_variation = "HeaderLabel"
	_goal_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_goal_label)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)
	_tries_label = Label.new()
	_tries_label.name = "Tries"
	_tries_label.add_theme_color_override("font_color", UI.colors["texto_suave"])
	col.add_child(_tries_label)


## Caras posibles: primero los dibujos del juego, despues figuras con sus colores.
func _build_faces() -> void:
	_faces.clear()
	var hero: Dictionary = Kit.sprite_by_role("jugador")
	if not hero.is_empty():
		_faces.append({"art": hero})
	for k: String in ["walker", "spiky", "flyer", "boss"]:
		var e: Dictionary = Kit.sprite_entry(str(Kit.param("art.enemies." + k, "")))
		if not e.is_empty():
			_faces.append({"art": e})
	var coin: Dictionary = Kit.sprite_entry(str(Kit.param("art.coin", "moneda")))
	if not coin.is_empty():
		_faces.append({"art": coin})
	var cols: Array[Color] = [Kit.color("accent", Color("#e8b04b")), Kit.color("danger", Color("#ff6b5b")),
		Kit.color("enemy", Color("#d9774a")), Kit.color("solid", Color("#4f6787")).lightened(0.3), Kit.color("coin", Color("#f6cf7a"))]
	for i: int in SHAPES.size():
		_faces.append({"shape": SHAPES[i], "col": cols[i % cols.size()]})


func _reset() -> void:
	finished = false
	failed = false
	tries = 0
	extra_tries = 0
	misses = 0
	swaps = 0
	last_swap = Vector2i(-1, -1)
	_swap_glow = 0.0
	_swap_rng.seed = int(level.get("seed", 3)) * 31 + 7
	first = -1
	_second = -1
	busy = 0.0
	coins = 0
	cards.clear()
	var slots: Array[Vector2i] = []
	for y: int in rows.size():
		for x: int in rows[y].length():
			if rows[y][x] == ".":
				slots.append(Vector2i(x, y))
	var cols_n: int = rows[0].length() if not rows.is_empty() else 4
	var gap: float = 14.0
	var w: float = minf((680.0 - gap * float(cols_n - 1)) / float(cols_n), 150.0)
	_card = Vector2(w, w * 1.25)
	var total_w: float = float(cols_n) * w + float(cols_n - 1) * gap
	var total_h: float = float(rows.size()) * _card.y + float(rows.size() - 1) * gap
	var origin: Vector2 = Vector2((720.0 - total_w) * 0.5, 230.0 + maxf(0.0, (880.0 - total_h) * 0.5))
	_rng.seed = int(level.get("seed", 3))
	var faces: Array[int] = []
	for i: int in slots.size() / 2:
		faces.append(i % _faces.size())
		faces.append(i % _faces.size())
	## Barajar con la semilla del nivel (Fisher-Yates).
	for i: int in range(faces.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var t: int = faces[i]
		faces[i] = faces[j]
		faces[j] = t
	for k: int in faces.size():
		var s: Vector2i = slots[k]
		cards.append({"face": faces[k], "pos": origin + Vector2(float(s.x) * (w + gap), float(s.y) * (_card.y + gap)), "open": false, "done": false})
	pairs_left = faces.size() / 2
	coins_total = pairs_left
	_update_hud()
	_view.queue_redraw()


func _update_hud() -> void:
	_goal_label.text = Kit.text("pairs_left", "Parejas: %d") % pairs_left
	_tries_label.text = Kit.text("tries", "Intentos: %d de %d \u00b7 par %d") % [tries, limit(), par()]


# ------------------------------------------------------------------ reglas

func can_flip(i: int) -> bool:
	return not finished and not failed and busy <= 0.0 and i >= 0 and i < cards.size() and not bool(cards[i]["open"]) and not bool(cards[i]["done"])


## Da la vuelta a una carta. Devuelve false si no se puede ahora.
func flip(i: int) -> bool:
	if not can_flip(i):
		return false
	cards[i]["open"] = true
	_flip_anim[i] = 0.18
	if not fast:
		Audio.play("click", 0.1, -6.0)
	if first < 0:
		first = i
	else:
		_second = i
		tries += 1
		if int(cards[first]["face"]) == int(cards[i]["face"]):
			cards[first]["done"] = true
			cards[i]["done"] = true
			pairs_left -= 1
			coins += 1
			first = -1
			_second = -1
			if not fast:
				Audio.play("coin", 0.05, -4.0)
				Juice.vibrate(15)
			if pairs_left == 0:
				_update_hud()
				_finish()
				return true
		else:
			busy = 0.05 if fast else 0.75
			if not fast:
				Audio.play("land", 0.1, -8.0)
		if tries >= limit() and pairs_left > 0 and busy > 0.0:
			_update_hud()
			_lose()
			return true
	_update_hud()
	_view.queue_redraw()
	return true


func _process(delta: float) -> void:
	if not finished:
		time_in_level += delta
	if busy > 0.0:
		busy -= delta
		if busy <= 0.0 and first >= 0 and _second >= 0:
			cards[first]["open"] = false
			cards[_second]["open"] = false
			_flip_anim[first] = 0.18
			_flip_anim[_second] = 0.18
			first = -1
			_second = -1
			misses += 1
			if shuffle and misses % 2 == 0:
				_swap_two()
		_view.queue_redraw()
	if _swap_glow > 0.0:
		_swap_glow -= delta
		_view.queue_redraw()
	if not _flip_anim.is_empty():
		for k: Variant in _flip_anim.keys():
			_flip_anim[k] = float(_flip_anim[k]) - delta
			if float(_flip_anim[k]) <= 0.0:
				_flip_anim.erase(k)
		_view.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = get_canvas_transform().affine_inverse() * (event as InputEventMouseButton).position
		for i: int in cards.size():
			if Rect2(cards[i]["pos"], _card).has_point(p):
				flip(i)
				break


# ------------------------------------------------------------------ final

func _finish() -> void:
	finished = true
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = maxi(0, (limit() - tries) * 50) + coins * 20
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "tries": tries, "deaths": deaths, "stars": stars})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


## Estrellas: dentro del par tres, hasta un 40 % mas dos, mas una.
func stars_earned() -> int:
	return 3 if tries <= par() else (2 if float(tries) <= float(par()) * 1.4 else 1)


func _lose() -> void:
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "tries", "deaths": deaths})
	if auto_retry:
		retry()
		return
	Audio.play("hurt")
	var p: FailPanel = FailPanel.open(self, Kit.text("memory_lost", "\u00a1Sin intentos!"), Kit.text("memory_hint", "F\u00edjate bien en cada carta que se destapa"))
	p.closed.connect(retry)


## Segunda oportunidad (FailPanel, con anuncio): unos intentos mas para encontrar las parejas.
func revive() -> void:
	extra_tries += REVIVE_N
	failed = false
	_update_hud()


func revive_text() -> String:
	return Kit.text("revive_tries", "+{n} intentos").format({"n": REVIVE_N})


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
	return {"pos": Vector2(float(tries), float(pairs_left)), "deaths": deaths, "coins": coins, "finished": finished,
		"failed": failed, "stomps": coins, "tries": tries, "pairs_left": pairs_left}


# ------------------------------------------------------------------ dibujo

func _shape_points(shape: String, c: Vector2, r: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	match shape:
		"circle", "ring", "drop", "moon":
			for i: int in 24:
				var a: float = TAU * float(i) / 24.0
				var p: Vector2 = Vector2(cos(a), sin(a)) * r
				if shape == "drop" and sin(a) < 0.0:
					p = Vector2(cos(a) * r * (1.0 + sin(a)), sin(a) * r * 1.5)
				pts.append(c + p)
		"star":
			for i: int in 10:
				var a: float = TAU * float(i) / 10.0 - PI * 0.5
				pts.append(c + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
		"triangle":
			pts = PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.95, r * 0.7), c + Vector2(-r * 0.95, r * 0.7)])
		"heart":
			for i: int in 32:
				var t: float = TAU * float(i) / 32.0
				pts.append(c + Vector2(16.0 * pow(sin(t), 3), -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))) * r / 17.0)
		"diamond":
			pts = PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.75, 0), c + Vector2(0, r), c + Vector2(-r * 0.75, 0)])
		"square":
			pts = PackedVector2Array([c + Vector2(-0.8, -0.8) * r, c + Vector2(0.8, -0.8) * r, c + Vector2(0.8, 0.8) * r, c + Vector2(-0.8, 0.8) * r])
		"hex":
			for i: int in 6:
				var a2: float = TAU * float(i) / 6.0
				pts.append(c + Vector2(cos(a2), sin(a2)) * r)
		"cross":
			var k: float = r * 0.35
			pts = PackedVector2Array([c + Vector2(-k, -r), c + Vector2(k, -r), c + Vector2(k, -k), c + Vector2(r, -k), c + Vector2(r, k), c + Vector2(k, k),
				c + Vector2(k, r), c + Vector2(-k, r), c + Vector2(-k, k), c + Vector2(-r, k), c + Vector2(-r, -k), c + Vector2(-k, -k)])
		"bolt":
			pts = PackedVector2Array([c + Vector2(0.2, -1.0) * r, c + Vector2(-0.55, 0.15) * r, c + Vector2(-0.05, 0.15) * r, c + Vector2(-0.25, 1.0) * r,
				c + Vector2(0.6, -0.2) * r, c + Vector2(0.1, -0.2) * r])
	return pts


func _draw_face(i: int, rect: Rect2) -> void:
	var f: Dictionary = _faces[int(cards[i]["face"])]
	var c: Vector2 = rect.get_center()
	var r: float = minf(rect.size.x, rect.size.y) * 0.32
	if f.has("art"):
		var sf: SpriteFrames = SpriteKit.frames_de(f["art"])
		var anim: String = "idle" if sf.has_animation("idle") else (sf.get_animation_names()[0] if not sf.get_animation_names().is_empty() else "")
		if anim != "" and sf.get_frame_count(anim) > 0:
			var tex: Texture2D = sf.get_frame_texture(anim, 0)
			var sz: Vector2 = tex.get_size()
			var k: float = minf(rect.size.x * 0.78 / sz.x, rect.size.y * 0.7 / sz.y)
			_view.draw_texture_rect(tex, Rect2(c - sz * k * 0.5, sz * k), false)
			return
	var shape: String = str(f.get("shape", "circle"))
	var col: Color = f.get("col", Color.ORANGE)
	var pts: PackedVector2Array = _shape_points(shape, c, r)
	if pts.size() >= 3:
		_view.draw_colored_polygon(pts, col)
	if shape == "ring":
		_view.draw_circle(c, r * 0.5, Color(0.97, 0.96, 0.93))
	elif shape == "moon":
		_view.draw_circle(c + Vector2(r * 0.4, -r * 0.2), r * 0.85, Color(0.97, 0.96, 0.93))


func _card_box(bg: Color, border: Color, bw: int) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(14)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 4)
	return sb


## Barajar: dos cartas tapadas (sin pareja hecha) se cambian el dibujo, a la vista.
func _swap_two() -> void:
	var hidden: Array[int] = []
	for k: int in cards.size():
		if not bool(cards[k]["done"]) and not bool(cards[k]["open"]):
			hidden.append(k)
	if hidden.size() < 3:
		return
	var a: int = hidden[_swap_rng.randi_range(0, hidden.size() - 1)]
	var b: int = a
	while b == a:
		b = hidden[_swap_rng.randi_range(0, hidden.size() - 1)]
	var f: int = int(cards[a]["face"])
	cards[a]["face"] = cards[b]["face"]
	cards[b]["face"] = f
	last_swap = Vector2i(a, b)
	swaps += 1
	_swap_glow = 0.15 if fast else 0.9
	if not fast:
		Audio.play("powerup", 0.1, -8.0)
	QA.log_event("memory_swap", {"a": a, "b": b})


func _draw_view() -> void:
	var back: Color = Kit.color("solid", Color("#4f6787"))
	var accent: Color = Kit.color("accent", Color("#e8b04b"))
	var face_bg: Color = Color(0.97, 0.96, 0.93)
	var box_back: StyleBoxFlat = _card_box(back, back.lightened(0.18), 3)
	var box_open: StyleBoxFlat = _card_box(face_bg, Color(0.8, 0.8, 0.8), 3)
	var box_done: StyleBoxFlat = _card_box(face_bg, accent, 5)
	for i: int in cards.size():
		var c: Dictionary = cards[i]
		var rect: Rect2 = Rect2(c["pos"], _card)
		## Media vuelta: la carta se estrecha y se ensancha.
		if _flip_anim.has(i):
			var t: float = absf(float(_flip_anim[i]) / 0.18 - 0.5) * 2.0
			rect = Rect2(rect.position + Vector2(rect.size.x * (1.0 - t) * 0.5, 0), Vector2(maxf(rect.size.x * t, 2.0), rect.size.y))
		if bool(c["open"]) or bool(c["done"]):
			(box_done if bool(c["done"]) else box_open).draw(_view.get_canvas_item(), rect)
			_draw_face(i, rect.grow(-8.0))
		else:
			box_back.draw(_view.get_canvas_item(), rect)
			var cc: Vector2 = rect.get_center()
			_view.draw_colored_polygon(_shape_points("diamond", cc, minf(rect.size.x, rect.size.y) * 0.2), accent.darkened(0.1))
			_view.draw_circle(cc, minf(rect.size.x, rect.size.y) * 0.05, back.lightened(0.3))
		if _swap_glow > 0.0 and (i == last_swap.x or i == last_swap.y):
			_view.draw_rect(rect.grow(6.0), Color(0.45, 0.95, 0.85, clampf(_swap_glow, 0.0, 0.9)), false, 6.0)
	if _swap_glow > 0.0 and last_swap.x >= 0:
		var pa: Vector2 = (cards[last_swap.x]["pos"] as Vector2) + _card * 0.5
		var pb: Vector2 = (cards[last_swap.y]["pos"] as Vector2) + _card * 0.5
		_view.draw_line(pa, pb, Color(0.45, 0.95, 0.85, clampf(_swap_glow, 0.0, 0.8)), 5.0)
