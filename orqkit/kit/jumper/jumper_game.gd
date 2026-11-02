extends Node2D
## Saltos: el heroe rebota solo en las plataformas y tu lo mueves a los lados para subir hasta la
## meta de arriba. Si cae por debajo de la pantalla, vuelve a empezar.
## 1 - Plataformas: "=" normal, "~" se mueve de lado a lado, "x" se rompe al pisarla, "^" muelle
##     (salto enorme). "C" moneda, "E" enemigo (pisarlo desde arriba lo aplasta y rebotas; tocarlo
##     de lado es caer), "G" meta (fila de arriba), "P" salida (abajo).
## 2 - Los lados se tocan: salir por la derecha es entrar por la izquierda.
## 3 - Control: arrastrar el dedo (o inclinar con las flechas) mueve al heroe hacia ese lado.
## 4 - Estrellas: 3 sin caerse y con la mitad de las monedas; 2 con una caida; 1 si no.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel al acabar.

const COLS: int = 9
const COL_W: float = 80.0
const ROW_H: float = 96.0
const GRAVITY: float = 1500.0
const JUMP_V: float = 1000.0
const SPRING_V: float = 1600.0
const MOVE_SPEED: float = 520.0
const PLAT_W: float = 112.0
const PLAT_H: float = 18.0

var rows: Array[String] = []
var finished: bool = false
var failed: bool = false
var deaths: int = 0
var time_in_level: float = 0.0
var coins: int = 0
var coins_total: int = 0
var fast: bool = false
var auto_retry: bool = false
var result_panel: ResultPanel

var pos: Vector2 = Vector2.ZERO
var vel: Vector2 = Vector2.ZERO
## -1 izquierda, 0 nada, 1 derecha (lo pone el control o el bot)
var steer: float = 0.0
var start: Vector2 = Vector2.ZERO
var goal_y: float = 0.0
## Cada plataforma: {"pos": Vector2, "kind": String, "alive": bool, "dir": float, "node": Node2D}
var platforms: Array[Dictionary] = []
var coin_nodes: Dictionary = {}
var enemies: Array[Dictionary] = []
var best_y: float = 0.0
var stomps: int = 0

var _hero: Node2D
var _camera: Camera2D
var _world: Node2D
var _coins_label: Label
var _progress: ColorRect
var _cam_y: float = 0.0
var _drag_from: float = -1.0


func _ready() -> void:
	for r: Variant in Kit.current_level().get("map", []):
		rows.append(str(r))
	RenderingServer.set_default_clear_color(Kit.color("sky", Color("#1b2a41")))
	add_child(_build_backdrop())
	_world = Node2D.new()
	_world.name = "World"
	add_child(_world)
	_build_hero()
	_camera = Camera2D.new()
	add_child(_camera)
	_camera.make_current()
	Juice.register_camera(_camera)
	_build_hud()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "jumper", "rows": rows.size()})


func bot_script() -> String:
	return "res://qa/jumper_bot.gd"


## Cielo que se aclara al subir, con nubes (o estrellas si es de noche) a los lados.
func _build_backdrop() -> Node2D:
	var n: Node2D = Node2D.new()
	n.name = "Backdrop"
	n.z_index = -10
	var sky: Color = Kit.color("sky", Color("#1b2a41"))
	var night: bool = sky.v < 0.3
	var total: float = float(rows.size()) * ROW_H
	var bands: int = 0 if Look.has_level_backdrop() else int(total / ROW_H) + 12
	for i: int in bands:
		var band: Polygon2D = Polygon2D.new()
		var y0: float = -float(i + 1) * ROW_H + ROW_H * 8.0
		band.polygon = PackedVector2Array([Vector2(-200, y0), Vector2(width() + 200, y0), Vector2(width() + 200, y0 + ROW_H + 1.0), Vector2(-200, y0 + ROW_H + 1.0)])
		band.color = sky.lightened(minf(0.4 * float(i) / float(bands), 0.4))
		n.add_child(band)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 99 + Kit.level_index
	for i: int in int(total / 160.0):
		var deco: Polygon2D = Polygon2D.new()
		var y: float = -rng.randf() * total
		if night:
			deco.polygon = LevelBuilder._circle(rng.randf_range(2.0, 4.0), 6)
			deco.color = Color(1, 1, 0.9, rng.randf_range(0.35, 0.8))
		else:
			deco.polygon = LevelBuilder._circle(rng.randf_range(26.0, 48.0), 14)
			deco.scale = Vector2(1.8, 0.7)
			deco.color = Color(1, 1, 1, 0.18)
		deco.position = Vector2(rng.randf() * width(), y)
		n.add_child(deco)
	return n


## Centro de la casilla (x, y) del mapa en el mundo (la fila 0 es la de arriba).
func cell_pos(x: int, y: int) -> Vector2:
	return Vector2((float(x) + 0.5) * COL_W, (float(y) + 0.5) * ROW_H - float(rows.size()) * ROW_H)


func width() -> float:
	return float(COLS) * COL_W


func _build_hero() -> void:
	_hero = Node2D.new()
	_hero.name = "Hero"
	_hero.z_index = 5
	add_child(_hero)
	var art: Dictionary = Kit.sprite_by_role("jugador")
	if not art.is_empty():
		var spr: AnimatedSprite2D = SpriteKit.animado(art, 72.0, "idle", true)
		_hero.add_child(spr)
		Skins.apply(spr)
	else:
		var body: Polygon2D = Polygon2D.new()
		body.color = Kit.color("accent", Color.ORANGE)
		body.polygon = LevelBuilder._circle(26.0, 16)
		body.position = Vector2(0, -26)
		_hero.add_child(body)


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
	top.add_child(UiIcon.make("coin", Kit.color("coin", UI.colors["acento"]), 40.0))
	_coins_label = Label.new()
	_coins_label.name = "Coins"
	top.add_child(_coins_label)
	var bar: ColorRect = ColorRect.new()
	bar.custom_minimum_size = Vector2(0.0, 12.0)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.color = UI.colors["borde"]
	top.add_child(bar)
	_progress = ColorRect.new()
	_progress.name = "Progress"
	_progress.color = UI.colors["acento"]
	bar.add_child(_progress)
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
	hint.text = Kit.text("jumper_hint", "Arrastra a los lados para subir")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", UI.colors["texto_suave"])
	col.add_child(hint)


func _reset() -> void:
	finished = false
	failed = false
	coins = 0
	stomps = 0
	for c: Node in _world.get_children():
		c.queue_free()
	platforms.clear()
	coin_nodes.clear()
	enemies.clear()
	goal_y = -float(rows.size()) * ROW_H
	for y: int in rows.size():
		for x: int in rows[y].length():
			var ch: String = rows[y][x]
			var p: Vector2 = cell_pos(x, y)
			match ch:
				"=", "~", "x", "^":
					_add_platform(p, ch)
				"G":
					goal_y = p.y
					_add_platform(p, "G")
				"C":
					var c: Node2D = Node2D.new()
					c.position = p
					var art: Dictionary = Kit.sprite_entry(str(Kit.param("art.coin", "moneda")))
					if not art.is_empty():
						c.add_child(SpriteKit.animado(art, 46.0, "spin", false))
					else:
						var poly: Polygon2D = Polygon2D.new()
						poly.color = Kit.color("coin", Color.YELLOW)
						poly.polygon = LevelBuilder._circle(16.0, 14)
						c.add_child(poly)
					_world.add_child(c)
					coin_nodes[Vector2i(x, y)] = c
				"E":
					_add_platform(p + Vector2(0.0, ROW_H * 0.35), "=")
					platforms[platforms.size() - 1]["enemy"] = true
					var e: Node2D = Node2D.new()
					e.position = p + Vector2(0.0, ROW_H * 0.35 - PLAT_H * 0.5)
					var eart: Dictionary = Kit.sprite_by_role("enemigo")
					if not eart.is_empty():
						e.add_child(SpriteKit.animado(eart, 64.0, "run", true))
					else:
						var ep: Polygon2D = Polygon2D.new()
						ep.color = Kit.color("enemy", Color("#d9774a"))
						ep.polygon = LevelBuilder._circle(24.0, 14)
						ep.position = Vector2(0, -24)
						e.add_child(ep)
					_world.add_child(e)
					enemies.append({"node": e, "alive": true})
				"P":
					start = p + Vector2(0.0, ROW_H * 0.35)
					_add_platform(start, "=")
	coins_total = coin_nodes.size()
	pos = start - Vector2(0.0, PLAT_H)
	vel = Vector2(0.0, -JUMP_V)
	best_y = pos.y
	_cam_y = pos.y - 300.0
	_hero.position = pos
	_camera.position = Vector2(width() * 0.5, _cam_y)
	_update_hud()


func _add_platform(p: Vector2, kind: String) -> void:
	var n: Node2D = Node2D.new()
	n.position = p
	var w: float = width() + 40.0 if kind == "G" else PLAT_W
	var col: Color = Kit.color("solid", Color("#3e5c84")).lightened(0.15)
	match kind:
		"~":
			col = Kit.color("accent", Color("#e8b04b"))
		"x":
			col = Kit.color("solid", Color("#3e5c84")).darkened(0.25)
		"^":
			col = Kit.color("solid", Color("#3e5c84")).lightened(0.15)
		"G":
			col = Kit.color("coin", Color("#f6cf7a"))
	var body: Polygon2D = Polygon2D.new()
	body.polygon = PackedVector2Array([Vector2(-w * 0.5, -PLAT_H * 0.5), Vector2(w * 0.5, -PLAT_H * 0.5), Vector2(w * 0.5 - 6.0, PLAT_H * 0.5), Vector2(-w * 0.5 + 6.0, PLAT_H * 0.5)])
	body.color = col
	if Kit.texture_polygon(body, 48.0):
		body.color = col.lerp(Color.WHITE, 0.5)
	n.add_child(body)
	if kind == "x":
		var crack: Line2D = Line2D.new()
		crack.points = PackedVector2Array([Vector2(-10, -8), Vector2(2, 0), Vector2(-4, 8)])
		crack.width = 3.0
		crack.default_color = col.darkened(0.5)
		n.add_child(crack)
	if kind == "^":
		var spring: Polygon2D = Polygon2D.new()
		spring.polygon = PackedVector2Array([Vector2(-14, -PLAT_H * 0.5), Vector2(14, -PLAT_H * 0.5), Vector2(10, -PLAT_H * 0.5 - 18), Vector2(-10, -PLAT_H * 0.5 - 18)])
		spring.color = Kit.color("danger", Color("#ff6b5b"))
		n.add_child(spring)
	_world.add_child(n)
	platforms.append({"pos": p, "kind": kind, "alive": true, "dir": 1.0 if int(p.x) % 2 == 0 else -1.0, "node": n})


func _update_hud() -> void:
	_coins_label.text = "%d/%d" % [coins, coins_total]
	var total: float = start.y - goal_y
	var done: float = clampf((start.y - best_y) / maxf(total, 1.0), 0.0, 1.0)
	_progress.size = Vector2((_progress.get_parent() as Control).size.x * done, 12.0)


# ------------------------------------------------------------------ fisica

func _physics_process(delta: float) -> void:
	if finished or failed or get_tree().paused:
		return
	time_in_level += delta
	if not UI.test_mode:
		var key: float = Input.get_axis("move_left", "move_right")
		if key != 0.0:
			steer = key
	## 1 - Plataformas que se mueven.
	for pl: Dictionary in platforms:
		if pl["kind"] == "~" and bool(pl["alive"]):
			var p: Vector2 = pl["pos"]
			p.x += float(pl["dir"]) * 110.0 * delta
			if p.x < PLAT_W * 0.5 or p.x > width() - PLAT_W * 0.5:
				pl["dir"] = -float(pl["dir"])
				p.x = clampf(p.x, PLAT_W * 0.5, width() - PLAT_W * 0.5)
			pl["pos"] = p
			(pl["node"] as Node2D).position = p
	## 2 - Heroe: lado a lado con inercia y caida con gravedad.
	vel.x = move_toward(vel.x, steer * MOVE_SPEED, 2600.0 * delta)
	var prev_y: float = pos.y
	vel.y += GRAVITY * delta
	pos += vel * delta
	pos.x = fposmod(pos.x, width())
	## 3 - Rebote al caer sobre una plataforma (solo bajando y cruzando su borde de arriba).
	if vel.y > 0.0:
		for pl: Dictionary in platforms:
			if not bool(pl["alive"]):
				continue
			var p2: Vector2 = pl["pos"]
			var half: float = (width() * 0.5 + 20.0) if pl["kind"] == "G" else PLAT_W * 0.5
			var top: float = p2.y - PLAT_H * 0.5
			if prev_y <= top + 2.0 and pos.y >= top and absf(_wrap_dx(pos.x, p2.x)) <= half + 10.0:
				_land(pl, top)
				break
	## 4 - Monedas y enemigos.
	for k: Vector2i in coin_nodes.keys():
		var c: Node2D = coin_nodes[k]
		if c.position.distance_to(pos + Vector2(0, -30)) < 48.0:
			coin_nodes.erase(k)
			c.queue_free()
			coins += 1
			Audio.play("coin", 0.1)
	for e: Dictionary in enemies:
		if not bool(e["alive"]):
			continue
		var en: Node2D = e["node"]
		var d: Vector2 = (pos + Vector2(0, -30)) - (en.position + Vector2(0, -30))
		if absf(_wrap_dx(pos.x, en.position.x)) < 40.0 and absf(d.y) < 46.0:
			if vel.y > 0.0 and d.y < -10.0:
				e["alive"] = false
				stomps += 1
				en.queue_free()
				vel.y = -JUMP_V * 1.1
				Audio.play("stomp")
				Juice.burst(self, en.position, Kit.color("enemy", Color.ORANGE), 12, 240.0)
			else:
				_fall("enemy")
				return
	best_y = minf(best_y, pos.y)
	_hero.position = pos
	if absf(vel.x) > 30.0 and _hero.get_child_count() > 0 and _hero.get_child(0) is AnimatedSprite2D:
		(_hero.get_child(0) as AnimatedSprite2D).flip_h = vel.x < 0.0
	## 5 - Camara: solo sube. Caer por debajo de la pantalla es empezar otra vez.
	_cam_y = minf(_cam_y, pos.y - 200.0)
	_camera.position = Vector2(width() * 0.5, _cam_y)
	if pos.y > _cam_y + get_viewport_rect().size.y * 0.55 / _camera.zoom.y + 60.0:
		_fall("fall")
		return
	if int(time_in_level * 6.0) != int((time_in_level - delta) * 6.0):
		_update_hud()


func _wrap_dx(a: float, b: float) -> float:
	var d: float = fposmod(a - b + width() * 0.5, width()) - width() * 0.5
	return d


func _land(pl: Dictionary, top: float) -> void:
	pos.y = top
	match str(pl["kind"]):
		"^":
			vel.y = -SPRING_V
			Audio.play("powerup", 0.1)
		"x":
			vel.y = -JUMP_V
			pl["alive"] = false
			var n: Node2D = pl["node"]
			var tw: Tween = n.create_tween()
			tw.set_parallel(true)
			tw.tween_property(n, "position:y", n.position.y + 400.0, 0.6)
			tw.tween_property(n, "modulate:a", 0.0, 0.6)
			Audio.play("land", 0.1)
		"G":
			_finish()
			return
		_:
			vel.y = -JUMP_V
			Audio.play("jump", 0.1, -6.0)
	if _hero.get_child_count() > 0 and _hero.get_child(0) is Node2D:
		Juice.squash(_hero.get_child(0) as Node2D, Vector2(1.25, 0.8))


func _unhandled_input(event: InputEvent) -> void:
	if UI.test_mode:
		return
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		var pressed: bool = event.pressed
		if pressed:
			var x: float = (event as InputEventFromWindow).position.x
			steer = -1.0 if x < get_viewport_rect().size.x * 0.5 else 1.0
		else:
			steer = 0.0
	elif event is InputEventScreenDrag:
		var x2: float = (event as InputEventScreenDrag).position.x
		steer = -1.0 if x2 < get_viewport_rect().size.x * 0.5 else 1.0


# ------------------------------------------------------------------ final

func _finish() -> void:
	finished = true
	vel = Vector2.ZERO
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = coins * 100 + stomps * 150 + maxi(0, 3000 - int(time_in_level * 20.0)) - deaths * 300
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "coins": coins, "deaths": deaths, "stars": stars})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": maxi(score, 0), "record": record})
	await Ads.show_interstitial("level_end")


func stars_earned() -> int:
	if deaths == 0 and coins * 2 >= coins_total:
		return 3
	if deaths <= 1:
		return 2
	return 1


func _fall(cause: String) -> void:
	deaths += 1
	QA.log_event("death", {"cause": cause, "deaths": deaths, "height": start.y - best_y})
	Audio.play("hurt")
	Juice.shake(0.3)
	## Se vuelve a empezar desde abajo (el nivel es corto); las monedas cogidas se quedan.
	var kept: int = coins
	var keep_nodes: Dictionary = coin_nodes.duplicate()
	_reset_hero()
	coins = kept
	coin_nodes = keep_nodes
	_update_hud()


func _reset_hero() -> void:
	pos = start - Vector2(0.0, PLAT_H)
	vel = Vector2(0.0, -JUMP_V)
	steer = 0.0
	_cam_y = pos.y - 300.0
	_hero.position = pos
	for pl: Dictionary in platforms:
		if pl["kind"] == "x" and not bool(pl["alive"]):
			pl["alive"] = true
			var n: Node2D = pl["node"]
			n.position = pl["pos"]
			n.modulate.a = 1.0


func retry() -> void:
	deaths = 0
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
	return {"pos": pos, "deaths": deaths, "coins": coins, "finished": finished, "failed": failed, "stomps": stomps,
		"height": start.y - best_y}
