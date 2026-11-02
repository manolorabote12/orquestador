extends Node2D
## Minigolf visto desde arriba.
## 1 - Arrastra hacia atras desde cualquier sitio para apuntar (como un tirachinas) y suelta.
## 2 - Mete la bola en el hoyo. El agua cuesta un golpe y devuelve la bola donde estaba.
##     La arena frena mucho. Una bola muy rapida pasa por encima del hoyo sin entrar.
## 3 - Estrellas: 3 con el par o menos, 2 con un golpe mas, 1 con mas. Con par + 5 golpes se
##     acaba el intento (cuenta como una muerte).
## La fisica es la de golf_map.gd (la misma que usan el bot y el analizador).
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const REVIVE_N: int = 3
const MapRules = preload("res://kit/golf/golf_map.gd")
const CELL: float = 80.0

var rows: Array[String] = []
var finished: bool = false
var failed: bool = false
var deaths: int = 0
var time_in_level: float = 0.0
var fast: bool = false
var auto_retry: bool = false
var result_panel: ResultPanel
var par: int = 3
var strokes: int = 0
var ball: Vector2 = Vector2.ZERO
var vel: Vector2 = Vector2.ZERO
var hole: Vector2 = Vector2.ZERO
var rolling: bool = false
var start: Vector2 = Vector2.ZERO
## Mezcla con el RPG: monstruos vivos (centros, en casillas). El hoyo se abre al derribarlos.
var monsters: Array[Vector2] = []
## Giro viento (casillas/s2).
var wind: Vector2 = Vector2.ZERO

var _last_shot_from: Vector2 = Vector2.ZERO
var _board: Node2D
var _ball_node: Node2D
var _aim: Line2D
var _camera: Camera2D
var _strokes_label: Label
var _drag_from: Vector2 = Vector2.ZERO
var _dragging: bool = false


func _ready() -> void:
	var lv: Dictionary = Kit.current_level()
	rows = MapRules.parse(lv)
	par = int(lv.get("par", 3))
	wind = MapRules.wind_of(lv)
	RenderingServer.set_default_clear_color(Kit.color("sky", Color("#16302b")).darkened(0.2))
	_board = Node2D.new()
	_board.name = "Board"
	_board.draw.connect(_draw_board)
	add_child(_board)
	_aim = Line2D.new()
	_aim.width = 8.0
	_aim.default_color = Color(1, 1, 1, 0.75)
	_aim.z_index = 4
	_aim.visible = false
	add_child(_aim)
	_build_ball()
	_camera = Camera2D.new()
	add_child(_camera)
	_camera.make_current()
	Juice.register_camera(_camera)
	_fit_camera()
	_build_hud()
	hole = MapRules.find(rows, "H")
	start = MapRules.find(rows, "B")
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "golf", "rows": rows.size()})


func bot_script() -> String:
	return "res://qa/golf_bot.gd"


func _fit_camera() -> void:
	var w: float = float(rows[0].length() if not rows.is_empty() else 1) * CELL
	var h: float = float(rows.size()) * CELL
	var vp: Vector2 = get_viewport_rect().size
	var z: float = minf(vp.x / (w + CELL * 0.5), vp.y * 0.8 / (h + CELL))
	_camera.zoom = Vector2.ONE * minf(z, 1.4)
	_camera.position = Vector2(w, h) * 0.5 + Vector2(0.0, CELL * 0.3)


func _build_ball() -> void:
	_ball_node = Node2D.new()
	_ball_node.name = "Ball"
	_ball_node.z_index = 5
	add_child(_ball_node)
	var shadow: Polygon2D = Polygon2D.new()
	shadow.color = Color(0, 0, 0, 0.25)
	shadow.polygon = LevelBuilder._circle(CELL * MapRules.RADIUS * 1.05, 18)
	shadow.position = Vector2(4.0, 5.0)
	_ball_node.add_child(shadow)
	var body: Polygon2D = Polygon2D.new()
	body.color = Color("#fbfbf6")
	body.polygon = LevelBuilder._circle(CELL * MapRules.RADIUS, 18)
	_ball_node.add_child(body)
	var art: Dictionary = Kit.sprite_by_role("jugador")
	if not art.is_empty():
		## El heroe mira desde la bola: la bola lleva su cara.
		var spr: AnimatedSprite2D = SpriteKit.animado(art, CELL * 0.42, "idle", false)
		_ball_node.add_child(spr)
		Skins.apply(spr)


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
	top.add_theme_constant_override("separation", 14)
	col.add_child(top)
	_strokes_label = Label.new()
	_strokes_label.name = "Strokes"
	_strokes_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_strokes_label)
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
	hint.text = Kit.text("golf_hint_monsters", "Derriba a los monstruos con la bola para abrir el hoyo") if not MapRules.monsters_of(rows).is_empty() \
		else Kit.text("golf_hint", "Arrastra hacia atr\u00e1s y suelta para tirar")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", UI.colors["texto_suave"])
	col.add_child(hint)


func _reset() -> void:
	finished = false
	failed = false
	strokes = 0
	ball = start
	monsters = MapRules.monsters_of(rows)
	_board.queue_redraw()
	_last_shot_from = start
	vel = Vector2.ZERO
	rolling = false
	_ball_node.position = ball * CELL
	_ball_node.scale = Vector2.ONE
	_ball_node.modulate.a = 1.0
	_aim.visible = false
	_update_hud()


func _update_hud() -> void:
	var w: String = ""
	if wind != Vector2.ZERO:
		## Flecha de viento (texto): hacia donde empuja y fuerza.
		var arrows: Array[String] = ["\u2192", "\u2198", "\u2193", "\u2199", "\u2190", "\u2196", "\u2191", "\u2197"]
		var k: int = int(roundf(fposmod(wind.angle(), TAU) / (TAU / 8.0))) % 8
		w = "   " + Kit.text("golf_wind", "Viento") + " " + arrows[k] + " " + str(roundi(wind.length() * 10.0))
	_strokes_label.text = Kit.text("golf_strokes", "Golpes: {n}  \u00b7  Par {p}").replace("{n}", str(strokes)).replace("{p}", str(par)) + w


# ------------------------------------------------------------------ reglas

func can_shoot() -> bool:
	return not finished and not failed and not rolling and not get_tree().paused


## Tira con esta velocidad (casillas/s). El bot llama aqui con lo que ha planeado.
func shoot(v: Vector2) -> bool:
	if not can_shoot() or v.length() < 0.5:
		return false
	vel = v.limit_length(MapRules.MAX_SPEED)
	_last_shot_from = ball
	strokes += 1
	rolling = true
	Audio.play("click", 0.05, -2.0, 0.8 + 0.4 * vel.length() / MapRules.MAX_SPEED)
	_update_hud()
	return true


func _physics_process(delta: float) -> void:
	if finished:
		return
	time_in_level += delta
	if not rolling or get_tree().paused:
		return
	for i: int in (6 if fast else 1):
		var r: Array = MapRules.step(rows, ball, vel, hole, monsters.is_empty(), wind)
		var bounced: bool = signf(vel.x) != signf((r[1] as Vector2).x) and absf(vel.x) > 2.0 \
			or signf(vel.y) != signf((r[1] as Vector2).y) and absf(vel.y) > 2.0
		ball = r[0]
		vel = r[1]
		_hit_monsters()
		var state: String = str(r[2])
		if bounced and state == "rueda":
			Audio.play("land", 0.1, -10.0)
		if state != "rueda":
			rolling = false
			_ball_node.position = ball * CELL
			_on_stop(state)
			return
	_ball_node.position = ball * CELL


func _hit_monsters() -> void:
	for k: int in range(monsters.size() - 1, -1, -1):
		if ball.distance_to(monsters[k]) < MapRules.MONSTER_R:
			var at: Vector2 = monsters[k] * CELL
			monsters.remove_at(k)
			Audio.play("stomp", 0.1, -2.0)
			Juice.shake(0.12)
			Juice.burst(self, at, Kit.color("danger", Color("#b55cff")), 12, 220.0)
			if monsters.is_empty():
				Audio.play("powerup", 0.05, -4.0)
				UI.float_text(self, hole * CELL + Vector2(0.0, -CELL), Kit.text("golf_open", "\u00a1Hoyo abierto!"), UI.colors["acento"], 30)
			_board.queue_redraw()


func twist_focus() -> Node2D:
	return _ball_node


func _on_stop(state: String) -> void:
	if state == "hoyo":
		var tw: Tween = create_tween()
		tw.tween_property(_ball_node, "scale", Vector2.ONE * 0.2, 0.12 if fast else 0.3)
		Audio.play("coin", 0.0, -2.0)
		Juice.shake(0.15)
		_finish()
		return
	if state == "agua":
		Audio.play("hurt", 0.05, -6.0)
		strokes += 1
		ball = _last_shot_from
		_ball_node.position = ball * CELL
		_update_hud()
	if strokes >= par + 5:
		_lose()


func _unhandled_input(event: InputEvent) -> void:
	if UI.test_mode:
		return
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event is InputEventMouseButton and (event as InputEventMouseButton).button_index != MOUSE_BUTTON_LEFT:
			return
		var pressed: bool = event.pressed
		var pos: Vector2 = event.position
		if pressed and can_shoot():
			_drag_from = pos
			_dragging = true
		elif not pressed and _dragging:
			_dragging = false
			_aim.visible = false
			var v: Vector2 = _shot_from_drag(pos)
			if v.length() > 1.0:
				shoot(v)
	elif (event is InputEventScreenDrag or event is InputEventMouseMotion) and _dragging:
		var v2: Vector2 = _shot_from_drag(event.position)
		_aim.visible = v2.length() > 1.0
		_aim.points = PackedVector2Array([ball * CELL, ball * CELL + v2 / MapRules.MAX_SPEED * CELL * 3.0])
		_aim.default_color = Color(1, 1, 1, 0.5).lerp(Kit.color("danger", Color("#ff6b5b")), v2.length() / MapRules.MAX_SPEED)


## Tirachinas: cuanto mas lejos arrastras, mas fuerte; la bola sale hacia el lado contrario.
func _shot_from_drag(to: Vector2) -> Vector2:
	var d: Vector2 = (_drag_from - to) / _camera.zoom.x
	var power: float = clampf(d.length() / (CELL * 3.0), 0.0, 1.0)
	return d.normalized() * power * MapRules.MAX_SPEED


# ------------------------------------------------------------------ final

func _finish() -> void:
	finished = true
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = maxi(0, 1000 + (par - strokes) * 250 - deaths * 200)
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "strokes": strokes, "par": par, "deaths": deaths, "stars": stars})
	Audio.play("win")
	Audio.play_track("victoria", false)
	if is_inside_tree():
		await get_tree().create_timer(0.1 if fast else 0.45).timeout
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": 0, "coins_total": 0, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


func stars_earned() -> int:
	if strokes <= par:
		return 3
	return 2 if strokes == par + 1 else 1


func _lose() -> void:
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "strokes", "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("golf_lost", "\u00a1Demasiados golpes!"),
		Kit.text("golf_fail_hint", "Este hoyo es de par {p}. Apunta a las paredes para rebotar.").replace("{p}", str(par)))
	p.closed.connect(retry)


## Segunda oportunidad (FailPanel, con anuncio): tres golpes mas antes de perder el hoyo.
func revive() -> void:
	strokes = maxi(0, strokes - REVIVE_N)
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
	return {"pos": ball, "deaths": deaths, "coins": 0, "finished": finished, "failed": failed, "stomps": 0, "strokes": strokes}


# ------------------------------------------------------------------ dibujo

func _draw_board() -> void:
	## El cesped es siempre verde (es minigolf); los muros, del color del juego.
	var grass_a: Color = Color("#3f9a52").lerp(Kit.color("solid", Color("#3f8f4f")), 0.15)
	var grass_b: Color = grass_a.lightened(0.06)
	var wall: Color = Kit.color("solid", Color("#8a5a3b")).darkened(0.25)
	var water: Color = Color("#3d8bd9")
	var sand: Color = Color("#e6cf8b")
	for y: int in rows.size():
		for x: int in rows[y].length():
			var r: Rect2 = Rect2(Vector2(x, y) * CELL, Vector2(CELL, CELL))
			var ch: String = rows[y][x]
			if ch == "#":
				_board.draw_rect(r, wall)
				_board.draw_rect(Rect2(r.position + Vector2(0.0, CELL - 10.0), Vector2(CELL, 10.0)), wall.darkened(0.35))
				continue
			_board.draw_rect(r, grass_a if (x + y) % 2 == 0 else grass_b)
			if ch == "W":
				_board.draw_rect(r.grow(-2.0), water)
				_board.draw_line(r.position + Vector2(14.0, CELL * 0.45), r.position + Vector2(CELL - 14.0, CELL * 0.45), water.lightened(0.35), 4.0)
			elif ch == "S":
				_board.draw_rect(r.grow(-2.0), sand)
				for k: int in 4:
					_board.draw_circle(r.position + Vector2(16.0 + float(k % 2) * 40.0, 18.0 + float(k / 2) * 40.0), 3.0, sand.darkened(0.2))
	var monster: Color = Kit.color("danger", Color("#b55cff"))
	for m: Vector2 in monsters:
		var mc: Vector2 = m * CELL
		_board.draw_circle(mc + Vector2(0.0, 6.0), CELL * 0.34, monster.darkened(0.3))
		_board.draw_circle(mc, CELL * 0.32, monster)
		for ex: float in [-0.12, 0.12]:
			_board.draw_circle(mc + Vector2(ex * CELL, -CELL * 0.06), CELL * 0.08, Color.WHITE)
			_board.draw_circle(mc + Vector2(ex * CELL, -CELL * 0.05), CELL * 0.04, Color("#1a1a1a"))
		_board.draw_line(mc + Vector2(-CELL * 0.12, CELL * 0.12), mc + Vector2(CELL * 0.12, CELL * 0.12), Color("#1a1a1a"), 3.0)
	var hc: Vector2 = hole * CELL
	_board.draw_circle(hc, CELL * MapRules.HOLE_R, Color("#142016"))
	if not monsters.is_empty():
		## Hoyo cerrado con una rejilla hasta derribar a todos los monstruos.
		for k: int in 3:
			var off: float = (float(k) - 1.0) * CELL * 0.16
			_board.draw_line(hc + Vector2(off, -CELL * 0.26), hc + Vector2(off, CELL * 0.26), Color("#9aa4b2"), 4.0)
	_board.draw_line(hc, hc + Vector2(0.0, -CELL * 0.9), Color("#f2f2f2"), 4.0)
	_board.draw_colored_polygon(PackedVector2Array([hc + Vector2(2.0, -CELL * 0.9), hc + Vector2(CELL * 0.45, -CELL * 0.75),
		hc + Vector2(2.0, -CELL * 0.6)]), Kit.color("danger", Color("#ff6b5b")))
