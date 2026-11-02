extends Node2D
## Genero naves: matamarcianos vertical para el movil.
## 1 - Tu nave dispara sola. Arrastra el dedo (o flechas) para moverla de lado a lado.
## 2 - Cada fila del mapa entra por arriba: enemigos, rocas, monedas y mejoras de arma.
## 3 - Los enemigos bajan y algunos disparan balas lentas que se esquivan. Chocar o recibir
##     una bala quita un corazon (y un momento de invulnerabilidad).
## 4 - Al final puede venir el jefe: se mueve de lado y dispara abanicos. Hay que derribarlo.
## 5 - Estrellas segun los golpes recibidos: 0-1 tres, 2-3 dos, mas una.
## Mapa (game.json -> levels[i].map): una fila por oleada, 7 columnas:
##   "." nada, "E" caza (dispara apuntando), "Z" zigzag (no dispara), "T" tanque (aguanta 4 y
##   dispara en abanico), "A" roca (aguanta 6, no dispara), "C" moneda, "W" mejora de arma,
##   "B" jefe (solo en la ultima fila).
## Parametros del nivel: row_time (segundos entre filas), enemy_speed y fire_rate (x1.0).
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const MapRules = preload("res://kit/shooter/shooter_map.gd")
const W: float = 720.0
const H: float = 1280.0
const COLS: int = 7
const PLAYER_Y: float = 1040.0
const PLAYER_R: float = 22.0
const SHOT_SPEED: float = 1150.0
const SHOT_EVERY: float = 0.15
const BULLET_SPEED: float = 300.0
const INVULN: float = 1.3
const KINDS: Dictionary = {
	"E": {"hp": 1, "r": 34.0, "speed": 1.0, "art": "walker", "score": 10},
	"Z": {"hp": 1, "r": 30.0, "speed": 1.15, "art": "flyer", "score": 12},
	"T": {"hp": 4, "r": 44.0, "speed": 0.7, "art": "spiky", "score": 30},
	"A": {"hp": 6, "r": 40.0, "speed": 0.8, "art": "", "score": 5},
}

var rows: Array[String] = []
var level: Dictionary = {}
var finished: bool = false
var failed: bool = false
var deaths: int = 0
var hits: int = 0
var time_in_level: float = 0.0
var coins: int = 0
var coins_total: int = 0
var kills: int = 0
var fast: bool = false
var auto_retry: bool = false
var result_panel: ResultPanel
## Estado que lee el bot.
var player_x: float = W * 0.5
var bot_x: float = INF
var hp: int = 3
var max_hp: int = 3
var weapon: int = 1
var invuln: float = 0.0
var enemies: Array[Dictionary] = []
var bullets: Array[Dictionary] = []
var pickups: Array[Dictionary] = []
var shots: Array[Vector2] = []
var boss: Dictionary = {}
var next_row: int = 0

var _row_timer: float = 0.0
var _shot_timer: float = 0.0
var _player: Node2D
var _world: Node2D
var _fx: Node2D
var _sky: Node2D
var _stars: Array[Vector3] = []
var _hearts: HBoxContainer
var _coins_label: Label
var _progress: ProgressBar
var _boss_bar: ProgressBar
var _drag_from: float = 0.0
var _drag_x: float = 0.0
var _dragging: bool = false
var _sparks: Array[Dictionary] = []


func _ready() -> void:
	level = Kit.current_level()
	for r: Variant in level.get("map", []):
		rows.append(str(r))
	RenderingServer.set_default_clear_color(Kit.color("sky", Color("#0b0f1a")))
	_sky = Node2D.new()
	_sky.name = "Sky"
	_sky.draw.connect(_draw_sky)
	add_child(_sky)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 99 + Kit.level_index
	for i: int in 90:
		_stars.append(Vector3(rng.randf() * W, rng.randf() * H, rng.randf_range(0.2, 1.0)))
	_world = Node2D.new()
	_world.name = "World"
	add_child(_world)
	_fx = Node2D.new()
	_fx.name = "Fx"
	_fx.z_index = 8
	_fx.draw.connect(_draw_fx)
	add_child(_fx)
	_build_player()
	var cam: Camera2D = Camera2D.new()
	cam.position = Vector2(W, H) * 0.5
	add_child(cam)
	cam.make_current()
	Juice.register_camera(cam)
	_build_hud()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "shooter", "rows": rows.size()})


## Fotos de la tienda: con la segunda oleada en pantalla y luego en plena accion.
func capture_delays() -> Vector2:
	return Vector2(row_time() * 9.0, 2.2)


## Los bots: QaBot juega este genero con el script que devuelve esta funcion.
func bot_script() -> String:
	return "res://qa/shooter_bot.gd"


func col_x(c: int) -> float:
	return (float(c) + 0.5) * W / float(COLS)


func row_time() -> float:
	return float(level.get("row_time", 0.85))


func enemy_speed() -> float:
	return 150.0 * float(level.get("enemy_speed", 1.0))


func fire_rate() -> float:
	return float(level.get("fire_rate", 1.0))


# ------------------------------------------------------------------ montaje

func _build_player() -> void:
	_player = Node2D.new()
	_player.name = "Player"
	_player.z_index = 6
	add_child(_player)
	var art: Dictionary = Kit.sprite_by_role("jugador")
	if not art.is_empty():
		var spr: AnimatedSprite2D = SpriteKit.animado(art, 96.0, "idle", false)
		_player.add_child(spr)
		Skins.apply(spr)
	else:
		var body: Polygon2D = Polygon2D.new()
		body.color = Skins.recolor(Kit.color("accent", Color.ORANGE))
		body.polygon = PackedVector2Array([Vector2(0, -44), Vector2(30, 26), Vector2(0, 12), Vector2(-30, 26)])
		_player.add_child(body)
	## Llama del motor debajo de la nave.
	var flame: Polygon2D = Polygon2D.new()
	flame.name = "Flame"
	flame.color = Color(1.0, 0.75, 0.3, 0.85)
	flame.polygon = PackedVector2Array([Vector2(-12, 38), Vector2(12, 38), Vector2(0, 74)])
	flame.z_index = -1
	_player.add_child(flame)


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
	col.add_theme_constant_override("separation", 8)
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
	_coins_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_coins_label)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)
	_progress = ProgressBar.new()
	_progress.name = "Progress"
	_progress.show_percentage = false
	_progress.custom_minimum_size = Vector2(0.0, 10.0)
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_progress)
	_boss_bar = ProgressBar.new()
	_boss_bar.name = "BossBar"
	_boss_bar.show_percentage = false
	_boss_bar.custom_minimum_size = Vector2(0.0, 18.0)
	_boss_bar.visible = false
	_boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = Kit.color("danger", Color("#ff6b5b"))
	fill.set_corner_radius_all(6)
	_boss_bar.add_theme_stylebox_override("fill", fill)
	col.add_child(_boss_bar)
	var grow: Control = Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(grow)
	var hint: Label = Label.new()
	hint.name = "Hint"
	hint.text = Kit.text("drag_to_move", "Arrastra para mover la nave")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", UI.colors["texto_suave"])
	col.add_child(hint)


func _reset() -> void:
	for n: Node in _world.get_children():
		n.queue_free()
	finished = false
	failed = false
	hits = 0
	kills = 0
	coins = 0
	weapon = 1
	invuln = 0.0
	enemies.clear()
	bullets.clear()
	pickups.clear()
	shots.clear()
	_sparks.clear()
	boss = {}
	next_row = 0
	_row_timer = 0.6 if not fast else 0.0
	_shot_timer = 0.0
	player_x = W * 0.5
	_drag_x = player_x
	max_hp = maxi(int(Kit.player_hp(float(Kit.param("player.hp", 3.0)))), 1)
	hp = max_hp
	coins_total = 0
	for r: String in rows:
		coins_total += r.count("C")
	_boss_bar.visible = false
	_place_player()
	_update_hud()


func _update_hud() -> void:
	for c: Node in _hearts.get_children():
		c.queue_free()
	for i: int in max_hp:
		var full: bool = i < hp
		_hearts.add_child(UiIcon.make("heart" if full else "heart_empty", UI.colors["peligro"] if full else (UI.colors["texto_suave"] as Color), 36.0))
	_coins_label.text = "%d/%d" % [coins, coins_total]
	_progress.max_value = maxf(float(rows.size()), 1.0)
	_progress.value = float(next_row)
	if not boss.is_empty():
		_boss_bar.visible = true
		_boss_bar.max_value = float(boss["max_hp"])
		_boss_bar.value = float(boss["hp"])


# ------------------------------------------------------------------ oleadas

func _spawn_row(i: int) -> void:
	var r: String = rows[i]
	for c: int in mini(r.length(), COLS):
		var ch: String = r[c]
		var at: Vector2 = Vector2(col_x(c), -60.0)
		match ch:
			"E", "Z", "T", "A":
				_spawn_enemy(ch, at)
			"C", "W":
				var n: Node2D = _make_pickup(ch)
				_world.add_child(n)
				n.position = at
				pickups.append({"kind": ch, "pos": at, "node": n})
			"B":
				_spawn_boss()


func _spawn_enemy(kind: String, at: Vector2) -> void:
	var k: Dictionary = KINDS[kind]
	var n: Node2D = Node2D.new()
	_world.add_child(n)
	n.position = at
	var art_id: String = str(Kit.param("art.enemies." + str(k["art"]), "")) if str(k["art"]) != "" else ""
	var entry: Dictionary = Kit.sprite_entry(art_id) if art_id != "" else {}
	if not entry.is_empty():
		var spr: AnimatedSprite2D = SpriteKit.animado(entry, float(k["r"]) * 2.3, "run", false)
		spr.flip_v = false
		n.add_child(spr)
	elif kind == "A":
		var rock: Polygon2D = Polygon2D.new()
		rock.color = Kit.color("solid", Color("#4f6787"))
		var pts: PackedVector2Array = PackedVector2Array()
		for j: int in 9:
			var a: float = TAU * float(j) / 9.0
			pts.append(Vector2(cos(a), sin(a)) * float(k["r"]) * (0.82 + 0.18 * sin(float(j) * 2.7)))
		rock.polygon = pts
		n.add_child(rock)
	else:
		var body: Polygon2D = Polygon2D.new()
		body.color = Kit.color("enemy", Color("#d9774a"))
		var r: float = float(k["r"])
		body.polygon = PackedVector2Array([Vector2(0, r), Vector2(r, -r * 0.4), Vector2(0, -r * 0.1), Vector2(-r, -r * 0.4)])
		n.add_child(body)
	enemies.append({"kind": kind, "pos": at, "hp": int(k["hp"]), "r": float(k["r"]), "node": n, "t": 0.0,
		"fire": 1.2 + 0.37 * float(enemies.size() % 5), "x0": at.x})


func _spawn_boss() -> void:
	var n: Node2D = Node2D.new()
	_world.add_child(n)
	var entry: Dictionary = Kit.sprite_entry(str(Kit.param("art.enemies.boss", "")))
	if not entry.is_empty():
		n.add_child(SpriteKit.animado(entry, 210.0, "run", false))
	else:
		var body: Polygon2D = Polygon2D.new()
		body.color = Kit.color("danger", Color("#ff6b5b"))
		body.polygon = PackedVector2Array([Vector2(-110, -40), Vector2(110, -40), Vector2(70, 60), Vector2(-70, 60)])
		n.add_child(body)
	var mhp: int = int(round(float(Kit.param("enemies.boss.hp", 6.0)) * 7.0))
	boss = {"pos": Vector2(W * 0.5, -140.0), "hp": mhp, "max_hp": mhp, "r": 95.0, "node": n, "t": 0.0, "fire": 2.0, "aim": 3.2}
	QA.log_event("boss_spawn", {"hp": mhp})


func _make_pickup(kind: String) -> Node2D:
	var n: Node2D = Node2D.new()
	if kind == "C":
		var entry: Dictionary = Kit.sprite_entry(str(Kit.param("art.coin", "moneda")))
		if not entry.is_empty():
			n.add_child(SpriteKit.animado(entry, 46.0, "spin", false))
		else:
			var c: Polygon2D = Polygon2D.new()
			c.color = Kit.color("coin", Color("#e8b04b"))
			c.polygon = LevelBuilder._circle(18.0, 14)
			n.add_child(c)
	else:
		var box: Polygon2D = Polygon2D.new()
		box.color = Color(0.35, 0.85, 1.0)
		box.polygon = PackedVector2Array([Vector2(0, -26), Vector2(24, 0), Vector2(0, 26), Vector2(-24, 0)])
		n.add_child(box)
		var l: Label = Label.new()
		l.text = "W"
		l.add_theme_font_size_override("font_size", 26)
		l.position = Vector2(-10, -20)
		n.add_child(l)
	return n


# ------------------------------------------------------------------ bucle

func _physics_process(delta: float) -> void:
	if finished or failed or get_tree().paused:
		return
	time_in_level += delta
	invuln = maxf(invuln - delta, 0.0)
	_move_player(delta)
	## 1 - Filas que entran.
	_row_timer -= delta
	while _row_timer <= 0.0 and next_row < rows.size():
		_spawn_row(next_row)
		next_row += 1
		_row_timer += row_time()
		_update_hud()
	## 2 - Disparo automatico.
	_shot_timer -= delta
	if _shot_timer <= 0.0:
		_shot_timer = SHOT_EVERY
		_fire()
	_move_shots(delta)
	_move_enemies(delta)
	_move_boss(delta)
	_move_bullets(delta)
	_move_pickups(delta)
	_place_player()
	if not fast:
		_sky.queue_redraw()
	_fx.queue_redraw()
	## 3 - Fin: todas las filas fuera, sin enemigos vivos y sin jefe.
	if next_row >= rows.size() and enemies.is_empty() and boss.is_empty():
		_finish()


func steer_input() -> float:
	return Input.get_axis("move_left", "move_right")


func _move_player(delta: float) -> void:
	var target: float = player_x
	if bot_x != INF:
		target = bot_x
	elif _dragging:
		target = _drag_x
	else:
		target = player_x + steer_input() * 900.0 * delta
	player_x = clampf(move_toward(player_x, target, 1300.0 * delta), 40.0, W - 40.0)


func _place_player() -> void:
	_player.position = Vector2(player_x, PLAYER_Y)
	_player.modulate.a = 0.45 if invuln > 0.0 and int(invuln * 12.0) % 2 == 0 else 1.0
	var flame: Node2D = _player.get_node_or_null("Flame")
	if flame != null:
		flame.scale.y = 0.8 + 0.3 * sin(time_in_level * 30.0)


func _fire() -> void:
	var p: Vector2 = Vector2(player_x, PLAYER_Y - 50.0)
	shots.append(p)
	if weapon >= 2:
		shots.append(p + Vector2(-22.0, 10.0))
		shots.append(p + Vector2(22.0, 10.0))
	if weapon >= 3:
		shots.append(p + Vector2(-44.0, 22.0))
		shots.append(p + Vector2(44.0, 22.0))
	if not fast and Engine.get_physics_frames() % 3 == 0:
		Audio.play("shoot", 0.1, -16.0)


func _move_shots(delta: float) -> void:
	var keep: Array[Vector2] = []
	for s: Vector2 in shots:
		var n: Vector2 = s + Vector2(0.0, -SHOT_SPEED * delta)
		var hit: bool = false
		for e: Dictionary in enemies:
			if (e["pos"] as Vector2).distance_to(n) < float(e["r"]) + 8.0:
				_damage_enemy(e, 1)
				hit = true
				break
		if not hit and not boss.is_empty() and (boss["pos"] as Vector2).distance_to(n) < float(boss["r"]) and float((boss["pos"] as Vector2).y) > 40.0:
			_damage_boss(1)
			hit = true
		if not hit and n.y > -40.0:
			keep.append(n)
	shots = keep
	## Los enemigos derribados salen de la lista al final del fotograma.
	enemies = enemies.filter(func(e: Dictionary) -> bool: return int(e["hp"]) > 0 and float((e["pos"] as Vector2).y) < H + 80.0)


func _damage_enemy(e: Dictionary, dmg: int) -> void:
	e["hp"] = int(e["hp"]) - dmg
	if int(e["hp"]) <= 0:
		kills += 1
		(e["node"] as Node2D).queue_free()
		_burst(e["pos"], Kit.color("enemy", Color("#d9774a")), 14)
		if not fast:
			Audio.play("stomp", 0.1, -6.0)
	elif not fast:
		(e["node"] as Node2D).modulate = Color(2, 2, 2)
		var tw: Tween = (e["node"] as Node2D).create_tween()
		tw.tween_property(e["node"], "modulate", Color.WHITE, 0.12)


func _damage_boss(dmg: int) -> void:
	boss["hp"] = int(boss["hp"]) - dmg
	_update_hud()
	if int(boss["hp"]) <= 0:
		_burst(boss["pos"], Kit.color("danger", Color("#ff6b5b")), 40)
		(boss["node"] as Node2D).queue_free()
		QA.log_event("boss_defeated", {})
		if not fast:
			Audio.play("win", 0.0, -4.0)
			Juice.shake(0.6)
		boss = {}
		_boss_bar.visible = false


func _move_enemies(delta: float) -> void:
	var v: float = enemy_speed()
	for e: Dictionary in enemies:
		e["t"] = float(e["t"]) + delta
		var k: Dictionary = KINDS[e["kind"]]
		var p: Vector2 = e["pos"]
		p.y += v * float(k["speed"]) * delta
		if e["kind"] == "Z":
			p.x = clampf(float(e["x0"]) + sin(float(e["t"]) * 2.6) * 90.0, 40.0, W - 40.0)
		e["pos"] = p
		(e["node"] as Node2D).position = p
		if e["kind"] == "A":
			(e["node"] as Node2D).rotation += delta * 0.8
		## Disparo: los cazas apuntan, los tanques abren abanico. Solo dentro de la pantalla.
		if (e["kind"] == "E" or e["kind"] == "T") and p.y > 60.0 and p.y < PLAYER_Y - 260.0:
			e["fire"] = float(e["fire"]) - delta * fire_rate()
			if float(e["fire"]) <= 0.0:
				if e["kind"] == "E":
					e["fire"] = 2.4
					_bullet(p, (Vector2(player_x, PLAYER_Y) - p).normalized())
				else:
					e["fire"] = 2.8
					for a: float in [-0.35, 0.0, 0.35]:
						_bullet(p, Vector2(0, 1).rotated(a))
		## Choque con la nave.
		if invuln <= 0.0 and p.distance_to(Vector2(player_x, PLAYER_Y)) < float(e["r"]) + PLAYER_R:
			_hurt("crash")
			if e["kind"] != "A":
				_damage_enemy(e, 99)


func _move_boss(delta: float) -> void:
	if boss.is_empty():
		return
	boss["t"] = float(boss["t"]) + delta
	var p: Vector2 = boss["pos"]
	if p.y < 230.0:
		p.y += 140.0 * delta
	else:
		p.x = W * 0.5 + sin(float(boss["t"]) * 0.9) * 210.0
		boss["fire"] = float(boss["fire"]) - delta * fire_rate()
		boss["aim"] = float(boss["aim"]) - delta * fire_rate()
		if float(boss["fire"]) <= 0.0:
			boss["fire"] = 2.2
			for i: int in 5:
				_bullet(p + Vector2(0, 60), Vector2(0, 1).rotated(-0.6 + 0.3 * float(i)))
		if float(boss["aim"]) <= 0.0:
			boss["aim"] = 3.4
			_bullet(p + Vector2(0, 60), (Vector2(player_x, PLAYER_Y) - p).normalized())
	boss["pos"] = p
	(boss["node"] as Node2D).position = p
	if invuln <= 0.0 and p.distance_to(Vector2(player_x, PLAYER_Y)) < float(boss["r"]) + PLAYER_R:
		_hurt("boss")


func _bullet(at: Vector2, dir: Vector2) -> void:
	bullets.append({"pos": at, "vel": dir * BULLET_SPEED * (0.85 + 0.15 * fire_rate())})


func _move_bullets(delta: float) -> void:
	var keep: Array[Dictionary] = []
	for b: Dictionary in bullets:
		var p: Vector2 = (b["pos"] as Vector2) + (b["vel"] as Vector2) * delta
		if invuln <= 0.0 and p.distance_to(Vector2(player_x, PLAYER_Y)) < PLAYER_R + 9.0:
			_hurt("bullet")
			continue
		if p.y < H + 30.0 and p.x > -30.0 and p.x < W + 30.0:
			b["pos"] = p
			keep.append(b)
	bullets = keep


func _move_pickups(delta: float) -> void:
	var keep: Array[Dictionary] = []
	for it: Dictionary in pickups:
		var p: Vector2 = (it["pos"] as Vector2) + Vector2(0.0, enemy_speed() * 0.9 * delta)
		if p.distance_to(Vector2(player_x, PLAYER_Y)) < 60.0:
			(it["node"] as Node2D).queue_free()
			if it["kind"] == "C":
				coins += 1
				if not fast:
					Audio.play("coin", 0.1, -6.0)
			else:
				weapon = mini(weapon + 1, 3)
				QA.log_event("weapon_up", {"level": weapon})
				if not fast:
					Audio.play("powerup", 0.05, -4.0)
			_update_hud()
			continue
		if p.y > H + 40.0:
			(it["node"] as Node2D).queue_free()
			continue
		it["pos"] = p
		(it["node"] as Node2D).position = p
		keep.append(it)
	pickups = keep


func _hurt(cause: String) -> void:
	hp -= 1
	hits += 1
	invuln = INVULN
	QA.log_event("hit", {"cause": cause, "hp": hp})
	_update_hud()
	if not fast:
		Audio.play("hurt")
		Juice.shake(0.35)
		Juice.vibrate(40)
	if hp <= 0:
		_lose()


func _burst(at: Vector2, col: Color, n: int) -> void:
	if fast:
		return
	for i: int in n:
		var a: float = TAU * float(i) / float(n)
		_sparks.append({"pos": at, "vel": Vector2(cos(a), sin(a)) * randf_range(120.0, 320.0), "life": 0.5, "col": col})


# ------------------------------------------------------------------ entrada

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		_dragging = mb.pressed and mb.position.y > 160.0
		_drag_from = mb.position.x
		_drag_x = player_x
	elif event is InputEventMouseMotion and _dragging:
		## El dedo arrastra la nave en relativo (no tapa la nave con el dedo).
		var vp_w: float = get_viewport_rect().size.x
		_drag_x = clampf(_drag_x + ((event as InputEventMouseMotion).position.x - _drag_from) * W / maxf(vp_w, 1.0) * 1.2, 40.0, W - 40.0)
		_drag_from = (event as InputEventMouseMotion).position.x


# ------------------------------------------------------------------ final

func _finish() -> void:
	finished = true
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = kills * 10 + coins * 50 - hits * 100
	var record: bool = Save.submit_best(level_id, maxi(score, 0))
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "coins": coins, "kills": kills, "hits": hits, "deaths": deaths, "stars": stars})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": maxi(score, 0), "record": record})
	await Ads.show_interstitial("level_end")


## Estrellas segun los golpes: 0-1 tres, 2-3 dos, mas una.
func stars_earned() -> int:
	return 3 if hits <= 1 else (2 if hits <= 3 else 1)


func _lose() -> void:
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "ship", "deaths": deaths})
	if auto_retry:
		retry()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("shooter_lost", "\u00a1Te han derribado!"), Kit.text("shooter_hint", "Esquiva las balas y recoge las mejoras de arma"))
	p.closed.connect(retry)


func retry() -> void:
	_reset()

## Segunda oportunidad (anuncio con premio, lo ofrece el panel de derrota): sigue la partida.
func revive() -> void:
	failed = false
	hp = max_hp
	invuln = INVULN * 2.0
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
	return {"pos": Vector2(player_x, PLAYER_Y), "deaths": deaths, "coins": coins, "finished": finished, "failed": failed,
		"stomps": kills, "hits": hits, "progress": float(next_row) / maxf(float(rows.size()), 1.0)}


# ------------------------------------------------------------------ dibujo

## Cielo: estrellas en tres capas que bajan a distinta velocidad (sensacion de avanzar).
func _draw_sky() -> void:
	var base: Color = Kit.color("sky", Color("#0b0f1a"))
	var star: Color = base.lightened(0.75)
	for i: int in _stars.size():
		var s: Vector3 = _stars[i]
		var y: float = fposmod(s.y + time_in_level * 220.0 * s.z, H)
		_sky.draw_rect(Rect2(Vector2(s.x, y), Vector2(2.0, 2.0 + 6.0 * s.z)), Color(star, 0.25 + 0.6 * s.z))


func _draw_fx() -> void:
	var shot_col: Color = Kit.color("accent", Color("#e8b04b")).lightened(0.3)
	for s: Vector2 in shots:
		_fx.draw_rect(Rect2(s + Vector2(-3.0, -14.0), Vector2(6.0, 22.0)), shot_col)
	var danger: Color = Kit.color("danger", Color("#ff6b5b"))
	for b: Dictionary in bullets:
		_fx.draw_circle(b["pos"], 10.0, Color(danger, 0.35))
		_fx.draw_circle(b["pos"], 6.0, danger.lightened(0.35))
	var keep: Array[Dictionary] = []
	for sp: Dictionary in _sparks:
		sp["life"] = float(sp["life"]) - get_physics_process_delta_time()
		if float(sp["life"]) <= 0.0:
			continue
		sp["pos"] = (sp["pos"] as Vector2) + (sp["vel"] as Vector2) * get_physics_process_delta_time()
		_fx.draw_circle(sp["pos"], 4.0 * float(sp["life"]) * 2.0, Color(sp["col"], float(sp["life"]) * 2.0))
		keep.append(sp)
	_sparks = keep
