extends Node2D
## Genero rompebloques: pala, pelota y ladrillos.
## 1 - Arrastra el dedo (o flechas) para mover la pala. Toca para lanzar la pelota.
## 2 - La pelota rebota segun donde toque la pala (en el borde sale mas inclinada).
## 3 - Rompe todos los ladrillos que se pueden romper para ganar. Si caen todas las pelotas,
##     pierdes una vida; sin vidas, a repetir.
## 4 - Algunos ladrillos sueltan monedas, una pala mas ancha o pelotas extra.
## 5 - Estrellas segun las vidas perdidas: ninguna tres, una dos, mas una.
## Mapa (game.json -> levels[i].map): filas de 9 columnas, de arriba abajo:
##   "." hueco, "1" ladrillo, "2" aguanta 2, "3" aguanta 3, "#" acero (no se rompe),
##   "C" suelta moneda, "L" suelta pala ancha, "M" suelta pelota extra.
## Parametros del nivel: ball_speed (x1.0).
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const MapRules = preload("res://kit/breakout/breakout_map.gd")
const W: float = 720.0
const H: float = 1280.0
const COLS: int = 9
const BRICK: Vector2 = Vector2(76.0, 36.0)
const GAP: float = 4.0
const TOP: float = 230.0
const PADDLE_Y: float = 1110.0
const PADDLE_H: float = 26.0
const BALL_R: float = 12.0
const BASE_SPEED: float = 620.0
const MAX_SPEED: float = 980.0

var rows: Array[String] = []
var level: Dictionary = {}
var finished: bool = false
var failed: bool = false
var deaths: int = 0
var lives_lost: int = 0
var time_in_level: float = 0.0
var coins: int = 0
var coins_total: int = 0
var broken: int = 0
var fast: bool = false
var auto_retry: bool = false
var result_panel: ResultPanel
## Estado que lee el bot.
var paddle_x: float = W * 0.5
var paddle_w: float = 150.0
var bot_x: float = INF
var lives: int = 3
var max_lives: int = 3
var balls: Array[Dictionary] = []
var bricks: Array[Dictionary] = []
var drops: Array[Dictionary] = []
var held: bool = true
var wide_left: float = 0.0

var _board: Node2D
var _paddle: Node2D
var _hearts: HBoxContainer
var _coins_label: Label
var _bricks_label: Label
var _hint: Label
var _hold_timer: float = 0.0
var _dragging: bool = false
var _since_brick: float = 0.0
var _sparks: Array[Dictionary] = []


func _ready() -> void:
	level = Kit.current_level()
	for r: Variant in level.get("map", []):
		rows.append(str(r))
	RenderingServer.set_default_clear_color(Kit.color("sky", Color("#1b2a41")))
	_board = Node2D.new()
	_board.name = "Board"
	_board.draw.connect(_draw_board)
	add_child(_board)
	_build_paddle()
	var cam: Camera2D = Camera2D.new()
	cam.position = Vector2(W, H) * 0.5
	add_child(cam)
	cam.make_current()
	Juice.register_camera(cam)
	_build_hud()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "breakout", "rows": rows.size()})


## Los bots: QaBot juega este genero con el script que devuelve esta funcion.
func bot_script() -> String:
	return "res://qa/breakout_bot.gd"


## Fotos de la tienda: con la pelota en juego y varios ladrillos rotos.
func capture_delays() -> Vector2:
	return Vector2(5.0, 2.5)


func ball_speed() -> float:
	return BASE_SPEED * float(level.get("ball_speed", 1.0))


func brick_rect(c: int, r: int) -> Rect2:
	var left: float = (W - float(COLS) * (BRICK.x + GAP) + GAP) * 0.5
	return Rect2(Vector2(left + float(c) * (BRICK.x + GAP), TOP + float(r) * (BRICK.y + GAP)), BRICK)


# ------------------------------------------------------------------ montaje

func _build_paddle() -> void:
	_paddle = Node2D.new()
	_paddle.name = "Paddle"
	_paddle.z_index = 5
	add_child(_paddle)
	var bar: Polygon2D = Polygon2D.new()
	bar.name = "Bar"
	bar.color = Skins.recolor(Kit.color("accent", Color.ORANGE))
	_paddle.add_child(bar)
	## El heroe del juego va subido a la pala.
	var art: Dictionary = Kit.sprite_by_role("jugador")
	if not art.is_empty():
		var spr: AnimatedSprite2D = SpriteKit.animado(art, 64.0, "idle", true)
		spr.position.y -= PADDLE_H * 0.5
		_paddle.add_child(spr)
		Skins.apply(spr)


func _shape_paddle() -> void:
	var bar: Polygon2D = _paddle.get_node("Bar")
	var hw: float = paddle_w * 0.5
	var hh: float = PADDLE_H * 0.5
	bar.polygon = PackedVector2Array([Vector2(-hw + 10, -hh), Vector2(hw - 10, -hh), Vector2(hw, 0), Vector2(hw - 10, hh),
		Vector2(-hw + 10, hh), Vector2(-hw, 0)])


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
	_hearts = HBoxContainer.new()
	_hearts.name = "Hearts"
	_hearts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_hearts)
	top.add_child(UiIcon.make("coin", Kit.color("coin", UI.colors["acento"]), 36.0))
	_coins_label = Label.new()
	_coins_label.name = "Coins"
	top.add_child(_coins_label)
	_bricks_label = Label.new()
	_bricks_label.name = "Bricks"
	_bricks_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bricks_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bricks_label.add_theme_color_override("font_color", UI.colors["texto_suave"])
	top.add_child(_bricks_label)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)
	var grow: Control = Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(grow)
	_hint = Label.new()
	_hint.name = "Hint"
	_hint.text = Kit.text("tap_to_launch", "Toca para lanzar \u00b7 arrastra para mover")
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_color_override("font_color", UI.colors["texto_suave"])
	col.add_child(_hint)


func _reset() -> void:
	finished = false
	failed = false
	lives_lost = 0
	coins = 0
	broken = 0
	drops.clear()
	_sparks.clear()
	bricks.clear()
	coins_total = 0
	for r: int in rows.size():
		for c: int in mini(rows[r].length(), COLS):
			var ch: String = rows[r][c]
			if ch == ".":
				continue
			var hp: int = 99 if ch == "#" else (int(ch) if ch in ["1", "2", "3"] else 1)
			bricks.append({"c": c, "r": r, "kind": ch, "hp": hp, "max": hp, "rect": brick_rect(c, r)})
			if ch == "C":
				coins_total += 1
	max_lives = maxi(int(Kit.player_hp(float(Kit.param("player.hp", 3.0)))), 1)
	lives = max_lives
	paddle_w = 150.0
	wide_left = 0.0
	paddle_x = W * 0.5
	_new_ball()
	_shape_paddle()
	_place()
	_update_hud()
	_board.queue_redraw()


func _new_ball() -> void:
	balls.clear()
	balls.append({"pos": Vector2(paddle_x, PADDLE_Y - PADDLE_H * 0.5 - BALL_R - 1.0), "vel": Vector2.ZERO})
	held = true
	_hold_timer = 0.0
	_since_brick = 0.0


func breakable_left() -> int:
	var n: int = 0
	for b: Dictionary in bricks:
		if b["kind"] != "#":
			n += 1
	return n


func _update_hud() -> void:
	for c: Node in _hearts.get_children():
		c.queue_free()
	for i: int in max_lives:
		var full: bool = i < lives
		_hearts.add_child(UiIcon.make("heart" if full else "heart_empty", UI.colors["peligro"] if full else (UI.colors["texto_suave"] as Color), 36.0))
	_coins_label.text = "%d/%d" % [coins, coins_total]
	_bricks_label.text = Kit.text("bricks_left", "Quedan %d") % breakable_left()
	_hint.visible = held


# ------------------------------------------------------------------ bucle

func launch() -> void:
	if not held or finished or failed:
		return
	held = false
	## Sale hacia arriba con un poco de angulo (nunca vertical: aburre).
	var a: float = -0.35 if paddle_x > W * 0.5 else 0.35
	balls[0]["vel"] = Vector2(sin(a), -cos(a)) * ball_speed()
	_update_hud()


func _physics_process(delta: float) -> void:
	if finished or failed or get_tree().paused:
		return
	time_in_level += delta
	_move_paddle(delta)
	if wide_left > 0.0:
		wide_left -= delta
		if wide_left <= 0.0:
			paddle_w = 150.0
			_shape_paddle()
	if held:
		balls[0]["pos"] = Vector2(paddle_x, PADDLE_Y - PADDLE_H * 0.5 - BALL_R - 1.0)
		_hold_timer += delta
		## Sin tocar, sale sola a los 3 segundos (y el bot no tiene que tocar).
		if _hold_timer > (0.4 if fast else 3.0):
			launch()
	else:
		## 2 sub-pasos: la pelota nunca atraviesa un ladrillo.
		for k: int in 2:
			_step_balls(delta * 0.5)
	_since_brick += delta
	if _since_brick > 12.0 and not held:
		## Pelota atascada en un bucle: un empujon al angulo.
		_since_brick = 0.0
		for b: Dictionary in balls:
			b["vel"] = (b["vel"] as Vector2).rotated(randf_range(-0.4, 0.4))
	_move_drops(delta)
	_place()
	_board.queue_redraw()
	if breakable_left() == 0:
		_finish()


func steer_input() -> float:
	return Input.get_axis("move_left", "move_right")


func _move_paddle(delta: float) -> void:
	var target: float = paddle_x
	if bot_x != INF:
		target = bot_x
	elif not _dragging:
		target = paddle_x + steer_input() * 1000.0 * delta
	if _dragging:
		return
	paddle_x = clampf(move_toward(paddle_x, target, 1600.0 * delta), paddle_w * 0.5, W - paddle_w * 0.5)


func _step_balls(dt: float) -> void:
	var keep: Array[Dictionary] = []
	for b: Dictionary in balls:
		var p: Vector2 = b["pos"]
		var v: Vector2 = b["vel"]
		p += v * dt
		## Paredes y techo.
		if p.x < BALL_R:
			p.x = BALL_R
			v.x = absf(v.x)
		elif p.x > W - BALL_R:
			p.x = W - BALL_R
			v.x = -absf(v.x)
		if p.y < 150.0 + BALL_R:
			p.y = 150.0 + BALL_R
			v.y = absf(v.y)
		## Pala: el angulo depende de donde toca.
		if v.y > 0.0 and p.y + BALL_R >= PADDLE_Y - PADDLE_H * 0.5 and p.y < PADDLE_Y + PADDLE_H and absf(p.x - paddle_x) <= paddle_w * 0.5 + BALL_R:
			var off: float = clampf((p.x - paddle_x) / (paddle_w * 0.5), -1.0, 1.0)
			var a: float = off * 1.05
			var sp: float = minf(v.length() * 1.01, MAX_SPEED * float(level.get("ball_speed", 1.0)))
			v = Vector2(sin(a), -cos(a)) * sp
			p.y = PADDLE_Y - PADDLE_H * 0.5 - BALL_R
			if not fast:
				Audio.play("jump", 0.1, -10.0)
		## Ladrillos: se rebota por el lado de menor penetracion.
		for br: Dictionary in bricks:
			var rc: Rect2 = br["rect"]
			var q: Vector2 = Vector2(clampf(p.x, rc.position.x, rc.end.x), clampf(p.y, rc.position.y, rc.end.y))
			if q.distance_to(p) > BALL_R:
				continue
			var pen_x: float = minf(p.x + BALL_R - rc.position.x, rc.end.x - (p.x - BALL_R))
			var pen_y: float = minf(p.y + BALL_R - rc.position.y, rc.end.y - (p.y - BALL_R))
			if pen_x < pen_y:
				v.x = -v.x if (p.x < rc.get_center().x) == (v.x > 0.0) else v.x
				p.x += (-pen_x if p.x < rc.get_center().x else pen_x)
			else:
				v.y = -v.y if (p.y < rc.get_center().y) == (v.y > 0.0) else v.y
				p.y += (-pen_y if p.y < rc.get_center().y else pen_y)
			_hit_brick(br)
			break
		## Nunca casi horizontal (bucles eternos).
		var s: float = v.length()
		if s > 0.0 and absf(v.y) < s * 0.3:
			v.y = signf(v.y if v.y != 0.0 else -1.0) * s * 0.3
			v = v.normalized() * s
		b["pos"] = p
		b["vel"] = v
		if p.y < H + 40.0:
			keep.append(b)
	balls = keep
	if balls.is_empty():
		_lose_life()


func _hit_brick(br: Dictionary) -> void:
	_since_brick = 0.0
	if br["kind"] == "#":
		if not fast:
			Audio.play("land", 0.1, -10.0)
		return
	br["hp"] = int(br["hp"]) - 1
	if int(br["hp"]) > 0:
		if not fast:
			Audio.play("land", 0.1, -6.0)
		return
	bricks.erase(br)
	broken += 1
	var rc: Rect2 = br["rect"]
	_burst(rc.get_center(), _brick_color(br), 10)
	if br["kind"] in ["C", "L", "M"]:
		drops.append({"kind": br["kind"], "pos": rc.get_center()})
	if not fast:
		Audio.play("stomp", 0.12, -6.0)
		Juice.vibrate(12)
	_update_hud()


func _move_drops(delta: float) -> void:
	var keep: Array[Dictionary] = []
	for d: Dictionary in drops:
		var p: Vector2 = (d["pos"] as Vector2) + Vector2(0.0, 300.0 * delta)
		if absf(p.y - PADDLE_Y) < PADDLE_H + 14.0 and absf(p.x - paddle_x) < paddle_w * 0.5 + 18.0:
			match str(d["kind"]):
				"C":
					coins += 1
					if not fast:
						Audio.play("coin", 0.1, -6.0)
				"L":
					paddle_w = 230.0
					wide_left = 14.0
					_shape_paddle()
					if not fast:
						Audio.play("powerup", 0.05, -4.0)
				"M":
					if not balls.is_empty() and not held:
						var b0: Dictionary = balls[0]
						for a: float in [-0.45, 0.45]:
							balls.append({"pos": b0["pos"], "vel": (b0["vel"] as Vector2).rotated(a)})
					if not fast:
						Audio.play("powerup", 0.05, -4.0)
			QA.log_event("pickup", {"kind": d["kind"]})
			_update_hud()
			continue
		if p.y < H + 30.0:
			d["pos"] = p
			keep.append(d)
	drops = keep


func _lose_life() -> void:
	lives -= 1
	lives_lost += 1
	QA.log_event("ball_lost", {"lives": lives})
	if not fast:
		Audio.play("hurt")
		Juice.shake(0.3)
	if lives <= 0:
		_lose()
		return
	_new_ball()
	_update_hud()


func _place() -> void:
	_paddle.position = Vector2(paddle_x, PADDLE_Y)


func _burst(at: Vector2, col: Color, n: int) -> void:
	if fast:
		return
	for i: int in n:
		var a: float = TAU * float(i) / float(n) + randf() * 0.3
		_sparks.append({"pos": at, "vel": Vector2(cos(a), sin(a)) * randf_range(100.0, 280.0), "life": 0.45, "col": col})


# ------------------------------------------------------------------ entrada

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()
		return
	if event.is_action_pressed("jump") or event.is_action_pressed("shoot"):
		launch()
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		_dragging = mb.pressed and mb.position.y > 160.0
		if mb.pressed and held:
			launch()
		if _dragging:
			_follow(mb.position.x)
	elif event is InputEventMouseMotion and _dragging:
		_follow((event as InputEventMouseMotion).position.x)


## La pala va donde esta el dedo (en coordenadas del juego).
func _follow(screen_x: float) -> void:
	var vp_w: float = get_viewport_rect().size.x
	var x: float = W * 0.5 + (screen_x - vp_w * 0.5) * W / maxf(vp_w, 1.0)
	paddle_x = clampf(x, paddle_w * 0.5, W - paddle_w * 0.5)


# ------------------------------------------------------------------ final

func _finish() -> void:
	finished = true
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = broken * 20 + coins * 50 - lives_lost * 150
	var record: bool = Save.submit_best(level_id, maxi(score, 0))
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "coins": coins, "broken": broken, "lives_lost": lives_lost, "deaths": deaths, "stars": stars})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": maxi(score, 0), "record": record})
	await Ads.show_interstitial("level_end")


## Estrellas segun las vidas perdidas: ninguna tres, una dos, mas una.
func stars_earned() -> int:
	return clampi(3 - lives_lost, 1, 3)


func _lose() -> void:
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "balls", "deaths": deaths})
	if auto_retry:
		retry()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("breakout_lost", "\u00a1Se te escap\u00f3 la pelota!"), Kit.text("breakout_hint", "Golpea con el borde de la pala para inclinar el tiro"))
	p.closed.connect(retry)


func retry() -> void:
	_reset()

## Segunda oportunidad (anuncio con premio, lo ofrece el panel de derrota): sigue la partida.
func revive() -> void:
	failed = false
	lives = 1
	_new_ball()
	_update_hud()



func open_pause() -> void:
	if finished or get_tree().paused or get_node_or_null("PauseMenu") != null:
		return
	_dragging = false
	PauseMenu.open(self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_inside_tree() and not UI.test_mode:
			open_pause()


func bot_state() -> Dictionary:
	return {"pos": Vector2(paddle_x, PADDLE_Y), "deaths": deaths, "coins": coins, "finished": finished, "failed": failed,
		"stomps": broken, "lives_lost": lives_lost, "left": breakable_left()}


# ------------------------------------------------------------------ dibujo

func _brick_color(br: Dictionary) -> Color:
	match str(br["kind"]):
		"#":
			return Color(0.62, 0.66, 0.72)
		"C":
			return Kit.color("coin", Color("#e8b04b"))
		"L", "M":
			return Color(0.35, 0.85, 1.0)
	var base: Color = Kit.color("solid", Color("#4f6787"))
	var accent: Color = Kit.color("enemy", Color("#d9774a"))
	## Cada fila un tono entre el solido y el color de enemigo; los duros, mas oscuros.
	var t: float = float(int(br["r"]) % 6) / 5.0
	var col: Color = base.lerp(accent, t).lightened(0.15)
	return col.darkened(0.18 * float(int(br["max"]) - 1))


func _draw_board() -> void:
	var sky: Color = Kit.color("sky", Color("#1b2a41"))
	## Marco del campo.
	_board.draw_rect(Rect2(0, 150, W, H - 150), Color(sky.lightened(0.04), 0.45 if Look.has_level_backdrop() else 1.0))
	_board.draw_line(Vector2(0, 150), Vector2(W, 150), sky.lightened(0.25), 4.0)
	for br: Dictionary in bricks:
		var rc: Rect2 = br["rect"]
		var col: Color = _brick_color(br)
		_board.draw_rect(rc, col)
		_board.draw_rect(Rect2(rc.position, Vector2(rc.size.x, 6.0)), col.lightened(0.3))
		_board.draw_rect(Rect2(rc.position + Vector2(0, rc.size.y - 6.0), Vector2(rc.size.x, 6.0)), col.darkened(0.3))
		if int(br["hp"]) < int(br["max"]):
			## Grietas en los ladrillos golpeados.
			_board.draw_line(rc.position + Vector2(18, 8), rc.get_center(), col.darkened(0.55), 3.0)
			_board.draw_line(rc.get_center(), rc.end - Vector2(14, 6), col.darkened(0.55), 3.0)
		if br["kind"] == "L" or br["kind"] == "M":
			_board.draw_string(ThemeDB.fallback_font, rc.position + Vector2(rc.size.x * 0.5 - 8.0, 27.0), str(br["kind"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.05, 0.1, 0.2))
	for d: Dictionary in drops:
		var dc: Color = Kit.color("coin", Color("#e8b04b")) if d["kind"] == "C" else Color(0.35, 0.85, 1.0)
		_board.draw_circle(d["pos"], 16.0, dc)
		_board.draw_circle(d["pos"] + Vector2(-4, -5), 5.0, dc.lightened(0.5))
	for b: Dictionary in balls:
		_board.draw_circle(b["pos"], BALL_R + 6.0, Color(1, 1, 1, 0.12))
		_board.draw_circle(b["pos"], BALL_R, Color(1, 1, 1))
	var keep: Array[Dictionary] = []
	for sp: Dictionary in _sparks:
		sp["life"] = float(sp["life"]) - get_physics_process_delta_time()
		if float(sp["life"]) <= 0.0:
			continue
		sp["pos"] = (sp["pos"] as Vector2) + (sp["vel"] as Vector2) * get_physics_process_delta_time()
		_board.draw_rect(Rect2(sp["pos"], Vector2(6, 6)), Color(sp["col"], float(sp["life"]) * 2.0))
		keep.append(sp)
	_sparks = keep
