extends Node2D
## Genero hordas (vista desde arriba): sobrevive hasta que acabe el tiempo.
## 1 - Te mueves con el joystick virtual (o flechas/WASD); las armas disparan solas.
## 2 - Los enemigos llegan por oleadas, cada vez mas y mas duros; cada 30 s, un cerco.
## 3 - Al morir sueltan gemas (el coleccionable del juego): al llenar la barra subes de nivel
##     y eliges 1 de 3 mejoras (armas nuevas o mas fuertes, botas, vida, iman, fuerza, prisa).
## 4 - En el ultimo nivel puede salir el jefe: el reloj espera a que lo derrotes. Al acabar
##     el tiempo, el resto de la horda se deshace en gemas.
## 5 - Si pierdes todos los corazones, reapareces con la vida llena (cuenta como muerte).
## El nivel (game.json -> levels[i]) trae: map (rocas #), seconds, density (0..1), enemies y boss.
## 6 - Plantilla por datos (game.json o nivel -> "horde"; kit/horde/horde_catalog.json): armas con
##     su forma de atacar (shot, fan, orbit, aura, nova, chain, bomb, whip) y numeros por nivel,
##     mejoras, evoluciones (arma al maximo + su mejora = arma nueva) y enemigos. Estilos hechos
##     ("preset"): survivor (tipo Survivor.io) y vampiros (tipo Vampire Survivors).

const TILE: float = 64.0
const WEAPONS: Array[String] = ["rayo", "orbes", "aura", "abanico"]
const PASSIVES: Array[String] = ["botas", "vida", "iman", "fuerza", "prisa"]
const MAX_LEVEL: int = 5
const NAMES: Dictionary = {
	"rayo": ["Chispazo", "Dispara al enemigo mas cercano"],
	"orbes": ["Orbes", "Giran a tu alrededor"],
	"aura": ["Aura", "Hiere a todo lo que se acerca"],
	"abanico": ["Abanico", "Lanza cuchillas hacia delante"],
	"botas": ["Botas", "Te mueves mas rapido"],
	"vida": ["Corazon", "Un corazon mas y te curas"],
	"iman": ["Iman", "Atraes las gemas desde mas lejos"],
	"fuerza": ["Fuerza", "Todas tus armas hacen mas dano"],
	"prisa": ["Prisa", "Tus armas disparan mas a menudo"],
}
const BOT_PRIORITY: Array[String] = ["orbes", "aura", "vida", "rayo", "fuerza", "abanico", "prisa", "botas", "iman"]

var rows: Array[String] = []
var arena: Vector2 = Vector2.ZERO
var seconds: float = 90.0
var density: float = 0.5
var time_in_level: float = 0.0
var time_left: float = 90.0
var finished: bool = false
var deaths: int = 0
var kills: int = 0
var coins_taken: int = 0
var coins_total: int = 0
var level_ups: int = 0
var player_level: int = 1
var xp: int = 0
var xp_need: int = 4
var max_hp: int = 3
var hp: int = 3
var invuln_left: float = 0.0
var speed: float = 260.0
var facing: Vector2 = Vector2.RIGHT
var owned: Dictionary = {"rayo": 1}
## Catalogo de armas, mejoras y evoluciones de esta partida.
var cat: Dictionary = {}
var _orb_sets: Dictionary = {}
var _auras: Dictionary = {}
var _fx: Array[Dictionary] = []
var _whip_hits: int = 0
const CATALOG_PATH: String = "res://kit/horde/horde_catalog.json"
static var _data: Dictionary = {}
var enemies: Array[HordeEnemy] = []
var boss: HordeEnemy = null
var boss_spawned: bool = false
var pending: Array[Dictionary] = []
var auto_pick: bool = false
var _queued_ups: int = 0
var bot_dir: Vector2 = Vector2.ZERO
var player: Node2D
var player_sprite: AnimatedSprite2D = null
var camera: Camera2D
var stick: HordeStick
var result_panel: ResultPanel

var _gems: Array[Dictionary] = []
var _bullets: Array[Dictionary] = []
var _orbs: Array[Node2D] = []
var _orb_angle: float = 0.0
var _orb_hits: Dictionary = {}
var _aura: Polygon2D
var _cooldowns: Dictionary = {}
var _spawn_acc: float = 0.0
var _next_ring: float = 30.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _start: Vector2 = Vector2(TILE * 2.0, TILE * 2.0)
var _world: Node2D
var _enemy_types: Array = ["walker"]
var _sfx_gap: float = 0.0
var _hud: CanvasLayer
var _hearts: HBoxContainer
var _timer_label: Label
var _kills_label: Label
var _xp_fill: ColorRect
var _lvl_label: Label
var _boss_box: VBoxContainer
var _boss_fill: ColorRect


func _ready() -> void:
	var lv: Dictionary = Kit.current_level()
	rows = LevelBuilder.normalize(lv.get("map", ["P"]))
	arena = Vector2(float(rows[0].length()), float(rows.size())) * TILE
	seconds = float(lv.get("seconds", 90.0))
	time_left = seconds
	density = clampf(float(lv.get("density", 0.5)), 0.0, 1.0)
	cat = catalog(lv if lv.has("horde") else {"horde": Kit.param("horde", {})})
	owned = {str(cat["start"]): 1}
	_enemy_types = lv.get("enemies", ["walker"])
	if _enemy_types.is_empty():
		_enemy_types = ["walker"]
	_rng.seed = 1000 + Kit.level_index * 77
	max_hp = maxi(int(Kit.player_hp(float(Kit.param("player.hp", 3.0)))), 1)
	hp = max_hp
	speed = float(Kit.param("player.horde_speed", 260.0))
	RenderingServer.set_default_clear_color(Kit.color("sky", Color("#1b2a41")).darkened(0.3))
	_world = Node2D.new()
	_world.name = "World"
	add_child(_world)
	_build_arena()
	_build_player()
	_build_camera()
	_build_hud()
	stick = HordeStick.new()
	stick.name = "Stick"
	add_child(stick)
	Audio.play_track("nivel")
	UI.float_text(_world, player.position + Vector2(0.0, -110.0), Kit.text("move_hint", "Arrastra para moverte"), UI.colors["acento"], 34)
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "horde", "seconds": seconds})


## Bandera para los bots: este juego se juega con HordeBot.
func horde_bot_step() -> void:
	pass


# ------------------------------------------------------------------ montaje

func _build_arena() -> void:
	var tex: Texture2D = Kit.first_tile_texture()
	## 6 - Suelo liso a cuadros grandes (2x2 casillas) con el color del cielo: las rocas, con la
	## textura del juego, se distinguen a la primera.
	var sky: Color = Kit.color("sky", Color("#1b2a41"))
	var img: Image = Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.set_pixel(0, 0, sky.lightened(0.10))
	img.set_pixel(1, 1, sky.lightened(0.10))
	img.set_pixel(1, 0, sky.lightened(0.05))
	img.set_pixel(0, 1, sky.lightened(0.05))
	var floor_poly: Polygon2D = Polygon2D.new()
	floor_poly.name = "Floor"
	floor_poly.polygon = PackedVector2Array([Vector2.ZERO, Vector2(arena.x, 0.0), arena, Vector2(0.0, arena.y)])
	floor_poly.texture = ImageTexture.create_from_image(img)
	floor_poly.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	floor_poly.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var cells: Vector2 = arena / (TILE * 2.0)
	floor_poly.uv = PackedVector2Array([Vector2.ZERO, Vector2(cells.x, 0.0), cells, Vector2(0.0, cells.y)])
	_world.add_child(floor_poly)
	for y: int in rows.size():
		for x: int in rows[y].length():
			if rows[y][x] == "P":
				_start = Vector2((x + 0.5) * TILE, (y + 0.5) * TILE)
			if rows[y][x] != "#":
				continue
			var rock: Polygon2D = Polygon2D.new()
			var o: Vector2 = Vector2(x, y) * TILE
			rock.polygon = PackedVector2Array([o, o + Vector2(TILE, 0.0), o + Vector2(TILE, TILE), o + Vector2(0.0, TILE)])
			if tex != null:
				rock.texture = tex
				var k2: float = float(tex.get_width()) / TILE
				rock.uv = PackedVector2Array([Vector2.ZERO, Vector2(TILE, 0.0) * k2, Vector2(TILE, TILE) * k2, Vector2(0.0, TILE) * k2])
			else:
				rock.color = Kit.color("solid", Color("#e8f0fa"))
			_world.add_child(rock)


func _build_player() -> void:
	player = Node2D.new()
	player.name = "Player"
	player.position = _start
	_world.add_child(player)
	var art: Dictionary = Kit.sprite_by_role("jugador")
	if not art.is_empty():
		player_sprite = SpriteKit.animado(art, 72.0, "idle", false)
		player.add_child(player_sprite)
		Skins.apply(player_sprite)
	else:
		var body: Polygon2D = Polygon2D.new()
		body.color = Kit.color("accent", Color.ORANGE)
		body.polygon = LevelBuilder._circle(26.0, 20)
		player.add_child(body)
	_aura = Polygon2D.new()
	_aura.name = "Aura"
	_aura.color = Color(Kit.color("accent", Color.ORANGE), 0.16)
	_aura.visible = false
	player.add_child(_aura)
	_aura.z_index = -1
	_auras["aura"] = _aura


func _build_camera() -> void:
	camera = Camera2D.new()
	camera.name = "Camera"
	camera.zoom = Vector2(0.8, 0.8)
	camera.limit_left = int(-TILE)
	camera.limit_top = int(-TILE * 3.0)
	camera.limit_right = int(arena.x + TILE)
	camera.limit_bottom = int(arena.y + TILE * 3.0)
	camera.position = player.position
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	_world.add_child(camera)
	camera.make_current()
	Juice.register_camera(camera)


func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.name = "Hud"
	_hud.layer = 20
	add_child(_hud)
	var root: Control = Control.new()
	root.theme = UI.theme
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(root)
	var safe: MarginContainer = UI.safe_root(root, 20.0)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col: VBoxContainer = VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 8)
	safe.add_child(col)
	var bar: HBoxContainer = HBoxContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_constant_override("separation", 14)
	col.add_child(bar)
	_hearts = HBoxContainer.new()
	_hearts.name = "Hearts"
	_hearts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(_hearts)
	_timer_label = Label.new()
	_timer_label.name = "Timer"
	_timer_label.theme_type_variation = "HeaderLabel"
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(_timer_label)
	_kills_label = Label.new()
	_kills_label.name = "Kills"
	_kills_label.theme_type_variation = "SubtleLabel"
	bar.add_child(_kills_label)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	bar.add_child(pause_btn)
	var xp_row: HBoxContainer = HBoxContainer.new()
	xp_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xp_row.add_theme_constant_override("separation", 10)
	col.add_child(xp_row)
	_lvl_label = Label.new()
	_lvl_label.name = "PlayerLevel"
	_lvl_label.theme_type_variation = "SubtleLabel"
	xp_row.add_child(_lvl_label)
	var back: ColorRect = ColorRect.new()
	back.name = "XpBar"
	back.color = (UI.colors["borde"] as Color)
	back.custom_minimum_size = Vector2(0.0, 14.0)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xp_row.add_child(back)
	_xp_fill = ColorRect.new()
	_xp_fill.color = Kit.color("coin", UI.colors["acento"])
	_xp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(_xp_fill)
	_boss_box = VBoxContainer.new()
	_boss_box.name = "BossBar"
	_boss_box.visible = false
	_boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_boss_box)
	var bname: Label = Label.new()
	bname.text = str(Kit.param("boss_name", Kit.text("boss", "Jefe")))
	bname.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_box.add_child(bname)
	var bback: ColorRect = ColorRect.new()
	bback.color = (UI.colors["borde"] as Color)
	bback.custom_minimum_size = Vector2(360.0, 18.0)
	bback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_box.add_child(bback)
	_boss_fill = ColorRect.new()
	_boss_fill.color = UI.colors["peligro"]
	_boss_fill.size = Vector2(360.0, 18.0)
	bback.add_child(_boss_fill)
	_update_hearts()
	_update_hud()


func _update_hearts() -> void:
	for c: Node in _hearts.get_children():
		c.queue_free()
	for i: int in max_hp:
		var full: bool = i < hp
		_hearts.add_child(UiIcon.make("heart" if full else "heart_empty", UI.colors["peligro"] if full else (UI.colors["texto_suave"] as Color), 40.0))


func _update_hud() -> void:
	var t: int = int(ceil(time_left))
	_timer_label.text = "%d:%02d" % [floori(t / 60.0), t % 60] if time_left > 0.0 or boss == null else Kit.text("beat_boss", "Derrota al jefe")
	_kills_label.text = str(kills)
	_lvl_label.text = "Nv %d" % player_level
	var back: Control = _xp_fill.get_parent() as Control
	_xp_fill.size = Vector2(back.size.x * clampf(float(xp) / float(xp_need), 0.0, 1.0), back.size.y)


# ------------------------------------------------------------------ bucle

func _physics_process(delta: float) -> void:
	if finished or get_tree().paused:
		return
	time_in_level += delta
	var was_running: bool = time_left > 0.0
	time_left = maxf(time_left - delta, 0.0)
	## Al acabarse el tiempo, la horda se deshace en gemas (si hay jefe, os quedais solos).
	if was_running and time_left <= 0.0:
		for e: HordeEnemy in enemies.duplicate():
			if e.kind != "boss":
				_kill(e)
		Juice.shake(0.35)
	_sfx_gap = maxf(_sfx_gap - delta, 0.0)
	_move_player(delta)
	_spawn(delta)
	_move_enemies(delta)
	_weapons(delta)
	_move_bullets(delta)
	_pickup_gems(delta)
	_touch_damage(delta)
	if boss != null and is_instance_valid(boss) and boss.alive:
		_boss_box.visible = true
		_boss_fill.size.x = 360.0 * maxf(boss.hp, 0.0) / boss.max_hp
	_update_hud()
	if time_left <= 0.0 and (boss == null or not boss.alive) and (boss_spawned or not _boss_level()):
		_win()


func _boss_level() -> bool:
	return bool(Kit.current_level().get("boss", false))


func _input_dir() -> Vector2:
	if bot_dir != Vector2.ZERO:
		return bot_dir.limit_length(1.0)
	var v: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if v == Vector2.ZERO and stick != null:
		v = stick.vector
	return v.limit_length(1.0)


func _move_player(delta: float) -> void:
	var dir: Vector2 = _input_dir()
	var v: float = speed * (1.0 + _stat("speed")) * Mods.tune("speed")
	var move: Vector2 = dir * v * delta
	var nx: Vector2 = player.position + Vector2(move.x, 0.0)
	if not solid_at(nx, 22.0):
		player.position = nx
	var ny: Vector2 = player.position + Vector2(0.0, move.y)
	if not solid_at(ny, 22.0):
		player.position = ny
	if dir.length() > 0.2:
		facing = dir.normalized()
		if absf(dir.x) > 0.1:
			player.scale.x = signf(dir.x)
	if player_sprite != null:
		var want: String = "run" if dir.length() > 0.2 else "idle"
		if player_sprite.sprite_frames.has_animation(want) and player_sprite.animation != want:
			player_sprite.play(want)
	if invuln_left > 0.0:
		invuln_left = maxf(invuln_left - delta, 0.0)
		player.modulate.a = 0.4 if int(invuln_left * 14.0) % 2 == 0 else 1.0
		if invuln_left == 0.0:
			player.modulate.a = 1.0


## Roca o fuera de la arena en cualquiera de los 4 lados de un circulo de radio r.
func solid_at(pos: Vector2, r: float) -> bool:
	for off: Vector2 in [Vector2(-r, 0.0), Vector2(r, 0.0), Vector2(0.0, -r), Vector2(0.0, r)]:
		var c: Vector2 = pos + off
		var cx: int = int(floor(c.x / TILE))
		var cy: int = int(floor(c.y / TILE))
		if cy < 0 or cy >= rows.size() or cx < 0 or cx >= rows[0].length() or rows[cy][cx] == "#":
			return true
	return false


# ------------------------------------------------------------------ enemigos

func _spawn(delta: float) -> void:
	var k: float = time_in_level / maxf(seconds, 1.0)
	var rate: float = (0.5 + 0.9 * density) * (1.0 + 1.8 * minf(k, 1.0))
	var cap: int = int(40.0 + 60.0 * density)
	## Acabado el tiempo ya no llegan mas: solo queda el jefe.
	if time_left > 0.0:
		_spawn_acc += rate * delta
	while _spawn_acc >= 1.0:
		_spawn_acc -= 1.0
		if enemies.size() < cap:
			_spawn_one(_pick_type(k), _edge_point())
	## Cerco cada 30 s: un anillo de enemigos alrededor del jugador.
	if time_in_level >= _next_ring and time_left > 5.0:
		_next_ring += 30.0
		var n: int = int(10.0 + 8.0 * density)
		for i: int in n:
			var a: float = TAU * float(i) / float(n)
			var p: Vector2 = player.position + Vector2(cos(a), sin(a)) * 520.0
			if not solid_at(p, 20.0):
				_spawn_one("walker", p)
	if _boss_level() and not boss_spawned and k >= 0.65:
		boss_spawned = true
		var bp: Vector2 = _edge_point().clamp(Vector2(TILE * 3.0, TILE * 3.0), arena - Vector2(TILE * 3.0, TILE * 3.0))
		boss = _spawn_one("boss", bp)
		QA.log_event("boss_spawn", {"t": snappedf(time_in_level, 0.1)})
		UI.float_text(_world, player.position + Vector2(0.0, -140.0), Kit.text("boss_comes", "Llega el jefe"), UI.colors["peligro"], 40)
		Juice.shake(0.4)


func _pick_type(k: float) -> String:
	var choices: Array[String] = []
	var weights: Array[float] = []
	for t: Variant in _enemy_types:
		var w: float = 1.0
		if t == "flyer":
			w = 0.6 if k > 0.2 else 0.0
		elif t == "spiky":
			w = 0.45 if k > 0.35 else 0.0
		if w > 0.0:
			choices.append(str(t))
			weights.append(w)
	if choices.is_empty():
		return str(_enemy_types[0])
	var total: float = 0.0
	for w: float in weights:
		total += w
	var r: float = _rng.randf() * total
	for i: int in choices.size():
		r -= weights[i]
		if r <= 0.0:
			return choices[i]
	return choices[0]


## Punto fuera de la vista de la camara (con margen), dentro de la arena y sin roca.
func _edge_point() -> Vector2:
	var half: Vector2 = get_viewport().get_visible_rect().size * 0.5 / camera.zoom + Vector2(80.0, 80.0)
	for i: int in 8:
		var side: int = _rng.randi() % 4
		var p: Vector2 = player.position
		match side:
			0:
				p += Vector2(_rng.randf_range(-half.x, half.x), -half.y)
			1:
				p += Vector2(_rng.randf_range(-half.x, half.x), half.y)
			2:
				p += Vector2(-half.x, _rng.randf_range(-half.y, half.y))
			_:
				p += Vector2(half.x, _rng.randf_range(-half.y, half.y))
		p = p.clamp(Vector2(TILE * 1.5, TILE * 1.5), arena - Vector2(TILE * 1.5, TILE * 1.5))
		if not solid_at(p, 24.0) and p.distance_to(player.position) > 380.0:
			return p
	return Vector2(_rng.randf_range(TILE * 2.0, arena.x - TILE * 2.0), TILE * 2.0)


func _spawn_one(kind: String, at: Vector2) -> HordeEnemy:
	var k: float = minf(time_in_level / maxf(seconds, 1.0), 1.0)
	var e: HordeEnemy = HordeEnemy.new()
	var hp_mult: float = (1.0 + 1.0 * k) * (0.85 + 0.4 * density)
	if kind == "boss":
		hp_mult = 0.6 + 0.6 * density
	e.setup(kind, hp_mult, 1.0 + 0.15 * density, (cat.get("enemies", {}) as Dictionary).get(kind, {}))
	e.position = at
	_world.add_child(e)
	enemies.append(e)
	return e


func _move_enemies(delta: float) -> void:
	var solid: Callable = Callable(self, "solid_at")
	var n: int = enemies.size()
	for i: int in n:
		var e: HordeEnemy = enemies[i]
		e.step(delta, player.position, solid)
		## Empuje barato con un vecino (no se amontonan en un punto).
		if n > 1:
			var o: HordeEnemy = enemies[(i * 7 + 3) % n]
			if o != e:
				var d: Vector2 = e.position - o.position
				var need: float = e.radius + o.radius
				var dist: float = d.length()
				if dist > 0.01 and dist < need:
					var push: Vector2 = d / dist * (need - dist) * 0.5
					## El empuje nunca mete a nadie en una roca ni mueve al jefe.
					if e.kind != "boss" and not solid_at(e.position + push, e.radius * 0.5):
						e.position += push
					if o.kind != "boss" and not solid_at(o.position - push, o.radius * 0.5):
						o.position -= push


func _touch_damage(_delta: float) -> void:
	if invuln_left > 0.0:
		return
	for e: HordeEnemy in enemies:
		if e.alive and e.position.distance_to(player.position) < e.radius + 20.0:
			_hurt(e.damage)
			return


func _hurt(amount: int) -> void:
	hp -= amount
	invuln_left = 1.0
	Audio.play("hurt")
	Juice.shake(0.3)
	Juice.vibrate(30)
	QA.log_event("hurt", {"hp": hp})
	if hp <= 0:
		_on_death()
	_update_hearts()


## 5 - Muerte: cuenta, aparta a los enemigos cercanos y sigue con la vida llena.
func _on_death() -> void:
	deaths += 1
	QA.log_event("death", {"deaths": deaths, "t": snappedf(time_in_level, 0.1)})
	Juice.flash(player)
	Juice.hitstop(0.08)
	hp = max_hp
	invuln_left = 2.0
	for e: HordeEnemy in enemies:
		if e.kind != "boss" and e.position.distance_to(player.position) < 340.0:
			e.position = player.position + (e.position - player.position).normalized() * 340.0


func _kill(e: HordeEnemy) -> void:
	kills += 1
	enemies.erase(e)
	if _sfx_gap <= 0.0:
		Audio.play("stomp", 0.15, -6.0)
		_sfx_gap = 0.05
	Juice.burst(_world, e.position, Kit.color("enemy", Color("#d9774a")), 6, 160.0)
	_drop_gem(e.position, e.xp)
	if _rng.randf() < 0.012 and e.kind != "boss":
		_drop_gem(e.position + Vector2(18.0, 0.0), 0, true)
	if e == boss:
		Juice.shake(0.6)
		_boss_box.visible = false
		QA.log_event("boss_defeated", {"t": snappedf(time_in_level, 0.1)})
	e.queue_free()


# ------------------------------------------------------------------ gemas y niveles

func _drop_gem(at: Vector2, value: int, heart: bool = false) -> void:
	## Con muchas gemas en el suelo, la nueva se suma a una que ya existe (rendimiento).
	if not heart and _gems.size() > 220:
		var g: Dictionary = _gems[_rng.randi() % _gems.size()]
		if not bool(g["heart"]):
			g["value"] = int(g["value"]) + value
			coins_total += value
			return
	var node: Node2D = Node2D.new()
	node.position = at
	if heart:
		node.add_child(UiIcon.make("heart", UI.colors["peligro"], 36.0))
		(node.get_child(0) as Control).position = Vector2(-18.0, -18.0)
	else:
		coins_total += value
		var entry: Dictionary = Kit.sprite_entry(str(Kit.param("art.coin", "moneda")))
		if not entry.is_empty():
			node.add_child(SpriteKit.animado(entry, 34.0, "spin", false))
		else:
			var g: Polygon2D = Polygon2D.new()
			g.color = Kit.color("coin", Color("#f6cf7a"))
			g.polygon = PackedVector2Array([Vector2(0, -12), Vector2(9, 0), Vector2(0, 12), Vector2(-9, 0)])
			node.add_child(g)
	_world.add_child(node)
	_gems.append({"node": node, "value": value, "heart": heart})


func _pickup_gems(delta: float) -> void:
	var reach: float = 110.0 * (1.0 + _stat("magnet"))
	var i: int = _gems.size() - 1
	while i >= 0:
		var g: Dictionary = _gems[i]
		var node: Node2D = g["node"]
		var d: float = node.position.distance_to(player.position)
		if d < reach:
			node.position = node.position.move_toward(player.position, (420.0 + (reach - d) * 6.0) * delta)
		if d < 28.0:
			if bool(g["heart"]):
				hp = mini(hp + 1, max_hp)
				_update_hearts()
				Audio.play("powerup")
			else:
				coins_taken += int(g["value"])
				_gain_xp(int(g["value"]))
				if _sfx_gap <= 0.0:
					Audio.play("coin", 0.1, -8.0)
					_sfx_gap = 0.04
			node.queue_free()
			_gems.remove_at(i)
		i -= 1


func _gain_xp(v: int) -> void:
	xp += v
	while xp >= xp_need:
		xp -= xp_need
		player_level += 1
		xp_need = 4 + 3 * (player_level - 1)
		_queued_ups += 1
	## Varias subidas a la vez: se eligen una detras de otra, nunca dos ventanas juntas.
	if pending.is_empty() and _queued_ups > 0:
		_level_up()


## 3 - Subir de nivel: 3 opciones al azar entre armas y mejoras que aun pueden subir. Si un arma
##     esta al maximo y tienes su mejora, su evolucion sale siempre la primera.
func _level_up() -> void:
	_queued_ups = maxi(_queued_ups - 1, 0)
	level_ups += 1
	Audio.play("powerup")
	var opts: Array[Dictionary] = []
	for ev: Dictionary in evolutions_ready():
		opts.append({"id": "evo:" + str(ev["into"]), "title": Kit.text("evolution", "Evoluciona") + ": " + item_name(str(ev["into"])),
			"desc": item_desc(str(ev["into"]))})
		if opts.size() >= 1:
			break
	var pool: Array[String] = []
	for w: String in weapon_ids() + passive_ids():
		if int(owned.get(w, 0)) < max_level(w):
			pool.append(w)
	while opts.size() < 3 and not pool.is_empty():
		var id: String = pool[_rng.randi() % pool.size()]
		pool.erase(id)
		var lvl: int = int(owned.get(id, 0))
		var title: String = item_name(id)
		if lvl == 0 and weapon_ids().has(id):
			title = Kit.text("new_weapon", "Nueva") + ": " + title
		elif lvl > 0:
			title += " " + str(lvl + 1)
		opts.append({"id": id, "title": title, "desc": item_desc(id)})
	if opts.is_empty():
		hp = mini(hp + 1, max_hp)
		_update_hearts()
		if _queued_ups > 0:
			_level_up()
		return
	pending = opts
	if auto_pick:
		choose(best_choice())
		return
	get_tree().paused = true
	var panel: LevelUpPanel = LevelUpPanel.open(self, opts)
	panel.chosen.connect(func(i: int) -> void:
		get_tree().paused = false
		choose(i))


func best_choice() -> int:
	for i0: int in pending.size():
		if str(pending[i0]["id"]).begins_with("evo:"):
			return i0
	for id: Variant in cat.get("bot", []):
		for i: int in pending.size():
			if str(pending[i]["id"]) == str(id):
				return i
	## Sin lista: armas que ya llevas, despues armas nuevas (hasta 4) y mejoras.
	var best: int = 0
	var bs: float = -1.0
	for i2: int in pending.size():
		var pid: String = str(pending[i2]["id"])
		var sc: float = 1.0
		if weapon_ids().has(pid):
			sc = 4.0 if owned.has(pid) else (3.0 if _weapon_count() < 4 else 0.5)
		elif str(passive(pid).get("stat", "")) in ["hp", "power"]:
			sc = 2.5
		if sc > bs:
			bs = sc
			best = i2
	return best


func choose(i: int) -> void:
	if pending.is_empty():
		return
	var id: String = str(pending[clampi(i, 0, pending.size() - 1)]["id"])
	pending = []
	if id.begins_with("evo:"):
		var into: String = id.substr(4)
		for ev: Dictionary in cat.get("evolutions", []):
			if str(ev["into"]) == into:
				owned.erase(str(ev["weapon"]))
				_drop_weapon_fx(str(ev["weapon"]))
		owned[into] = 1
		Juice.shake(0.3)
		UI.float_text(_world, player.position + Vector2(0.0, -120.0), item_name(into), Color("#ffe066"), 40)
		QA.log_event("evolution", {"id": into})
	else:
		owned[id] = int(owned.get(id, 0)) + 1
		if str(passive(id).get("stat", "")) == "hp":
			max_hp += 1
			hp = mini(hp + 2, max_hp)
			_update_hearts()
		QA.log_event("upgrade", {"id": id, "level": owned[id]})
	if _queued_ups > 0:
		_level_up.call_deferred()


# ------------------------------------------------------------------ catalogo

static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
		_data = parsed if parsed is Dictionary else {"default": {"start": "rayo", "max_level": 5, "weapons": {}, "passives": {}, "evolutions": [], "enemies": {}, "bot": []}, "presets": {}}
	return _data


## Catalogo de la partida: el de serie, los estilos ("preset") y lo que traiga el juego encima.
static func catalog(level: Dictionary) -> Dictionary:
	var c: Dictionary = (data()["default"] as Dictionary).duplicate(true)
	var extra: Variant = level.get("horde", {})
	if extra is Dictionary:
		var pr: Variant = (extra as Dictionary).get("preset", "")
		for p: Variant in (pr if pr is Array else [pr]):
			if (data()["presets"] as Dictionary).has(str(p)):
				_merge(c, data()["presets"][str(p)])
		_merge(c, extra)
	return c


static func _merge(c: Dictionary, extra: Dictionary) -> void:
	for sec: String in ["weapons", "passives", "enemies"]:
		var add: Variant = extra.get(sec, {})
		if add is Dictionary:
			for k: Variant in add:
				if add[k] is Dictionary:
					c[sec][str(k)] = (add[k] as Dictionary).duplicate(true)
				elif add[k] == null:
					(c[sec] as Dictionary).erase(str(k))
	for k2: String in ["start", "max_level"]:
		if extra.has(k2):
			c[k2] = extra[k2]
	for k3: String in ["evolutions", "bot"]:
		if extra.get(k3, null) is Array:
			c[k3] = (extra[k3] as Array).duplicate(true)


func weapon(id: String) -> Dictionary:
	return (cat["weapons"] as Dictionary).get(id, {})


func passive(id: String) -> Dictionary:
	return (cat["passives"] as Dictionary).get(id, {})


## Armas que se pueden ofrecer (no las evolucionadas).
func weapon_ids() -> Array[String]:
	var out: Array[String] = []
	for k: String in cat["weapons"]:
		if not bool(cat["weapons"][k].get("evolved", false)):
			out.append(k)
	return out


func passive_ids() -> Array[String]:
	var out: Array[String] = []
	for k: String in cat["passives"]:
		out.append(k)
	return out


func max_level(id: String) -> int:
	if (cat["passives"] as Dictionary).has(id):
		return int(passive(id).get("max", cat.get("max_level", MAX_LEVEL)))
	return int(cat.get("max_level", MAX_LEVEL))


func _weapon_count() -> int:
	var n: int = 0
	for k: String in owned:
		if (cat["weapons"] as Dictionary).has(k):
			n += 1
	return n


## Evoluciones listas: arma al maximo y su mejora en la mochila.
func evolutions_ready() -> Array:
	var out: Array = []
	for ev: Dictionary in cat.get("evolutions", []):
		var w: String = str(ev["weapon"])
		if int(owned.get(w, 0)) >= max_level(w) and int(owned.get(str(ev["passive"]), 0)) >= 1 and not owned.has(str(ev["into"])) and (cat["weapons"] as Dictionary).has(str(ev["into"])):
			out.append(ev)
	return out


## Nombre de un arma o mejora: los de serie, traducidos; los inventados, tal cual.
func item_name(id: String) -> String:
	var d: Dictionary = weapon(id) if (cat["weapons"] as Dictionary).has(id) else passive(id)
	var nm: String = str(d.get("name", id))
	var stock: Dictionary = (data()["default"]["weapons"] as Dictionary).get(id, (data()["default"]["passives"] as Dictionary).get(id, {}))
	return Kit.text("up_" + id, nm) if str(stock.get("name", "")) == nm else nm


func item_desc(id: String) -> String:
	var d: Dictionary = weapon(id) if (cat["weapons"] as Dictionary).has(id) else passive(id)
	var ds: String = str(d.get("desc", ""))
	var stock: Dictionary = (data()["default"]["weapons"] as Dictionary).get(id, (data()["default"]["passives"] as Dictionary).get(id, {}))
	return Kit.text("up_" + id + "_desc", ds) if str(stock.get("desc", "")) == ds else ds


## Lo que suman las mejoras de un tipo (speed, magnet, power, haste, area, count).
func _stat(kind: String) -> float:
	var t: float = 0.0
	for k: String in owned:
		var p: Dictionary = passive(k)
		if str(p.get("stat", "")) == kind:
			t += float(p.get("per", 0.0)) * float(owned[k])
	return t


## Un numero del arma a su nivel (numero o lista por nivel).
func ws(id: String, key: String, fallback: float) -> float:
	var v: Variant = weapon(id).get(key, fallback)
	if v is Array:
		var arr: Array = v
		if arr.is_empty():
			return fallback
		return float(arr[clampi(int(owned.get(id, 1)) - 1, 0, arr.size() - 1)])
	return float(v)


func _wcol(id: String) -> Color:
	var c: String = str(weapon(id).get("color", "accent"))
	if c.begins_with("#"):
		return Color.from_string(c, Color.WHITE)
	return Kit.color(c, Color.ORANGE)


# ------------------------------------------------------------------ armas

func _dmg() -> float:
	return (1.0 + _stat("power")) * Mods.tune("damage")


func _cd(base: float) -> float:
	return base * maxf(0.3, 1.0 - _stat("haste")) / Mods.tune("fire_rate")


func _ready_weapon(id: String, base_cd: float, delta: float) -> bool:
	var left: float = float(_cooldowns.get(id, 0.0)) - delta
	if left <= 0.0:
		_cooldowns[id] = _cd(base_cd)
		return true
	_cooldowns[id] = left
	return false


func _weapons(delta: float) -> void:
	var extra_n: int = int(_stat("count"))
	var area: float = 1.0 + _stat("area")
	for id: String in owned.keys():
		if not (cat["weapons"] as Dictionary).has(id):
			continue
		match str(weapon(id).get("pattern", "shot")):
			"shot":
				if _ready_weapon(id, ws(id, "cd", 0.7), delta):
					var shots: int = int(ws(id, "count", 1.0)) + extra_n
					var rng: float = ws(id, "range", 720.0) * area
					var targets: Array[HordeEnemy] = _nearest(shots, rng)
					## Con el jefe a tiro, siempre va un disparo para el.
					if boss != null and is_instance_valid(boss) and boss.alive and boss.position.distance_to(player.position) < rng and not targets.has(boss):
						if targets.size() >= shots:
							targets.pop_back()
						targets.append(boss)
					for t: HordeEnemy in targets:
						_fire(player.position, (t.position - player.position).normalized(), ws(id, "dmg", 2.0), int(ws(id, "pierce", 1.0)), _wcol(id))
			"fan":
				if _ready_weapon(id, ws(id, "cd", 1.4), delta):
					var n: int = int(ws(id, "count", 3.0)) + extra_n
					var spread: float = ws(id, "spread", 0.22)
					for k: int in n:
						var a: float = (float(k) - float(n - 1) * 0.5) * spread
						_fire(player.position, facing.rotated(a), ws(id, "dmg", 2.0), int(ws(id, "pierce", 2.0)), _wcol(id))
			"nova":
				if _ready_weapon(id, ws(id, "cd", 2.0), delta):
					var n2: int = int(ws(id, "count", 8.0)) + extra_n * 2
					for k2: int in n2:
						_fire(player.position, Vector2.from_angle(TAU * float(k2) / float(n2)), ws(id, "dmg", 2.0), int(ws(id, "pierce", 1.0)), _wcol(id))
			"chain":
				if _ready_weapon(id, ws(id, "cd", 1.5), delta):
					_chain(id, int(ws(id, "count", 3.0)) + extra_n, ws(id, "range", 520.0) * area)
			"bomb":
				if _ready_weapon(id, ws(id, "cd", 2.0), delta):
					for k3: int in int(ws(id, "count", 1.0)) + extra_n:
						_bomb(id, ws(id, "range", 600.0) * area, ws(id, "radius", 70.0) * area)
			"whip":
				if _ready_weapon(id, ws(id, "cd", 1.2), delta):
					_whip(id, int(ws(id, "count", 1.0)) + extra_n, ws(id, "radius", 150.0) * area)
			"orbit":
				_update_orbit(id, delta, area, extra_n)
			"aura":
				_update_aura(id, delta, area)
	_update_fx(delta)


## Rayo que salta: al mas cercano y de ahi al siguiente que no ha tocado.
func _chain(id: String, jumps: int, rng: float) -> void:
	var first: Array[HordeEnemy] = _nearest(1, rng)
	if first.is_empty():
		return
	var at: Vector2 = player.position
	var hit: Array = []
	var cur: HordeEnemy = first[0]
	for k: int in jumps:
		if cur == null:
			break
		hit.append(cur)
		_fx.append({"kind": "line", "a": at, "b": cur.position, "t": 0.15, "col": _wcol(id)})
		at = cur.position
		if cur.hit(ws(id, "dmg", 2.0) * _dmg()):
			_kill(cur)
		var nxt: HordeEnemy = null
		var bd: float = 240.0
		for e: HordeEnemy in enemies:
			if e.alive and not hit.has(e) and e.position.distance_to(at) < bd:
				bd = e.position.distance_to(at)
				nxt = e
		cur = nxt
	if _sfx_gap <= 0.0:
		Audio.play("shoot", 0.2, -8.0)
		_sfx_gap = 0.05


## Bomba donde mas enemigos hay cerca (de entre unos cuantos a tiro).
func _bomb(id: String, rng: float, r: float) -> void:
	var cands: Array[HordeEnemy] = _nearest(8, rng)
	if cands.is_empty():
		return
	var best: Vector2 = cands[_rng.randi() % cands.size()].position
	var bn: int = -1
	for c: HordeEnemy in cands:
		var n: int = 0
		for e: HordeEnemy in enemies:
			if e.alive and e.position.distance_to(c.position) < r:
				n += 1
		if n > bn:
			bn = n
			best = c.position
	for e2: HordeEnemy in enemies.duplicate():
		if e2.alive and e2.position.distance_to(best) < r + e2.radius * 0.5:
			if e2.hit(ws(id, "dmg", 3.0) * _dmg()):
				_kill(e2)
	_fx.append({"kind": "ring", "a": best, "r": r, "t": 0.3, "col": _wcol(id)})
	if _sfx_gap <= 0.0:
		Audio.play("stomp", 0.2, -4.0)
		_sfx_gap = 0.05


## Latigazo a los lados (uno a cada lado con 2 o mas).
func _whip(id: String, n: int, reach: float) -> void:
	var dirs: Array[float] = [1.0 if facing.x >= 0.0 else -1.0]
	if n >= 2:
		dirs.append(-dirs[0])
	for sx: float in dirs:
		var c: Vector2 = player.position + Vector2(sx * reach * 0.5, 0.0)
		for e: HordeEnemy in enemies.duplicate():
			if e.alive and absf(e.position.x - c.x) < reach * 0.5 + e.radius and absf(e.position.y - c.y) < 80.0 + e.radius:
				if e.hit(ws(id, "dmg", 3.0) * _dmg()):
					_kill(e)
					_whip_hits += 1
					var every: int = int(ws(id, "heal_every", 0.0))
					if every > 0 and _whip_hits % every == 0:
						hp = mini(hp + 1, max_hp)
						_update_hearts()
		_fx.append({"kind": "rect", "a": c, "w": reach, "t": 0.15, "col": _wcol(id)})
	if _sfx_gap <= 0.0:
		Audio.play("shoot", 0.1, -8.0)
		_sfx_gap = 0.05


func _update_aura(id: String, delta: float, area: float) -> void:
	var node: Polygon2D = _auras.get(id) as Polygon2D
	if node == null:
		node = Polygon2D.new()
		node.name = "Aura_" + id
		node.color = Color(_wcol(id), 0.16)
		node.z_index = -1
		player.add_child(node)
		_auras[id] = node
	var r: float = ws(id, "radius", 108.0) * area
	node.visible = true
	node.polygon = LevelBuilder._circle(r, 40)
	node.color.a = 0.12 + 0.06 * sin(time_in_level * 6.0)
	if _ready_weapon(id, ws(id, "cd", 0.6), delta):
		for e: HordeEnemy in enemies.duplicate():
			if e.alive and e.position.distance_to(player.position) < r + e.radius * 0.5:
				if e.hit(ws(id, "dmg", 1.0) * _dmg()):
					_kill(e)


func _update_orbit(id: String, delta: float, area: float, extra_n: int) -> void:
	if not _orb_sets.has(id):
		_orb_sets[id] = {"nodes": [], "angle": 0.0, "hits": {}}
	var oset: Dictionary = _orb_sets[id]
	var nodes: Array = oset["nodes"]
	var want: int = int(ws(id, "count", 2.0)) + extra_n
	while nodes.size() < want:
		var o: Polygon2D = Polygon2D.new()
		o.color = _wcol(id)
		o.polygon = LevelBuilder._circle(14.0, 14)
		_world.add_child(o)
		nodes.append(o)
	oset["angle"] = float(oset["angle"]) + delta * ws(id, "spin", 3.2)
	var r: float = ws(id, "radius", 116.0) * area
	var dmg: float = ws(id, "dmg", 1.6) * _dmg()
	var gap: float = ws(id, "gap", 0.4)
	var hits: Dictionary = oset["hits"]
	for k: int in nodes.size():
		var a: float = float(oset["angle"]) + TAU * float(k) / float(nodes.size())
		(nodes[k] as Node2D).position = player.position + Vector2(cos(a), sin(a)) * r
		for e: HordeEnemy in enemies.duplicate():
			if not e.alive or e.position.distance_to((nodes[k] as Node2D).position) > e.radius + 16.0:
				continue
			var key: int = e.get_instance_id()
			if time_in_level - float(hits.get(key, -9.0)) < gap:
				continue
			hits[key] = time_in_level
			if e.hit(dmg):
				_kill(e)


## Al evolucionar, lo que dibujaba el arma vieja se quita.
func _drop_weapon_fx(id: String) -> void:
	if _orb_sets.has(id):
		for n: Variant in _orb_sets[id]["nodes"]:
			(n as Node).queue_free()
		_orb_sets.erase(id)
	if _auras.has(id):
		(_auras[id] as Node).visible = false


## Efectos breves: rayos, explosiones y latigazos (se dibujan en un nodo del mundo).
func _update_fx(delta: float) -> void:
	var fx_node: Node2D = _world.get_node_or_null("WeaponFx") as Node2D
	if fx_node == null:
		fx_node = Node2D.new()
		fx_node.name = "WeaponFx"
		fx_node.z_index = 5
		fx_node.draw.connect(_draw_fx.bind(fx_node))
		_world.add_child(fx_node)
	var i: int = _fx.size() - 1
	while i >= 0:
		_fx[i]["t"] = float(_fx[i]["t"]) - delta
		if float(_fx[i]["t"]) <= 0.0:
			_fx.remove_at(i)
		i -= 1
	fx_node.queue_redraw()


func _draw_fx(fx_node: Node2D) -> void:
	for f: Dictionary in _fx:
		var col: Color = Color(f["col"], clampf(float(f["t"]) * 5.0, 0.0, 1.0))
		match str(f["kind"]):
			"line":
				fx_node.draw_line(f["a"], f["b"], col, 5.0)
			"ring":
				fx_node.draw_circle(f["a"], float(f["r"]), Color(col, col.a * 0.35))
				fx_node.draw_arc(f["a"], float(f["r"]), 0.0, TAU, 32, col, 4.0)
			"rect":
				fx_node.draw_rect(Rect2(Vector2(f["a"]) - Vector2(float(f["w"]) * 0.5, 80.0), Vector2(float(f["w"]), 160.0)), Color(col, col.a * 0.5))


func _nearest(count: int, max_d: float) -> Array[HordeEnemy]:
	var best: Array[HordeEnemy] = []
	var sorted: Array = []
	for e: HordeEnemy in enemies:
		if not e.alive:
			continue
		var d: float = e.position.distance_squared_to(player.position)
		if d < max_d * max_d:
			sorted.append([d, e])
	sorted.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for i: int in mini(count, sorted.size()):
		best.append(sorted[i][1])
	return best


func _fire(from: Vector2, dir: Vector2, damage: float, pierce: int, col: Color) -> void:
	var node: Polygon2D = Polygon2D.new()
	node.color = col
	node.polygon = PackedVector2Array([Vector2(-12, -4), Vector2(12, -4), Vector2(12, 4), Vector2(-12, 4)])
	node.rotation = dir.angle()
	node.position = from
	_world.add_child(node)
	_bullets.append({"node": node, "vel": dir * 760.0, "dmg": damage * _dmg(), "life": 0.9, "pierce": pierce, "hit": []})
	if _sfx_gap <= 0.0:
		Audio.play("shoot", 0.1, -10.0)
		_sfx_gap = 0.05


func _move_bullets(delta: float) -> void:
	var i: int = _bullets.size() - 1
	while i >= 0:
		var b: Dictionary = _bullets[i]
		var node: Polygon2D = b["node"]
		node.position += (b["vel"] as Vector2) * delta
		b["life"] = float(b["life"]) - delta
		var dead: bool = float(b["life"]) <= 0.0 or solid_at(node.position, 2.0)
		if not dead:
			for e: HordeEnemy in enemies.duplicate():
				if e.alive and not (b["hit"] as Array).has(e) and e.position.distance_to(node.position) < e.radius + 8.0:
					(b["hit"] as Array).append(e)
					if e.hit(float(b["dmg"])):
						_kill(e)
					b["pierce"] = int(b["pierce"]) - 1
					if int(b["pierce"]) <= 0:
						dead = true
						break
		if dead:
			node.queue_free()
			_bullets.remove_at(i)
		i -= 1


# ------------------------------------------------------------------ pausa y final

func open_pause() -> void:
	if finished or get_tree().paused or get_node_or_null("PauseMenu") != null:
		return
	_release_inputs()
	PauseMenu.open(self)


func _release_inputs() -> void:
	for action: String in ["move_left", "move_right", "move_up", "move_down", "jump", "shoot"]:
		Input.action_release(action)
	if stick != null:
		stick.release()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_inside_tree() and not UI.test_mode:
			open_pause()


func _win() -> void:
	finished = true
	_release_inputs()
	var level_id: String = str(Kit.level_index)
	var score: int = kills * 10 + coins_taken * 5 + player_level * 100 - deaths * 200
	var stars: int = stars_earned()
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "kills": kills, "deaths": deaths, "player_level": player_level,
		"coins": coins_taken, "stars": stars, "time": snappedf(time_in_level, 0.1)})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins_taken, "coins_total": coins_total, "score": maxi(score, 0), "record": record})
	await Ads.show_interstitial("level_end")


## Estrellas: una por sobrevivir, otra por no caer nunca y otra por recoger el 70 % de las gemas.
func stars_earned() -> int:
	var n: int = 1
	if deaths == 0:
		n += 1
	if coins_total > 0 and float(coins_taken) >= 0.7 * float(coins_total):
		n += 1
	return n


func gems() -> Array[Dictionary]:
	return _gems


func bot_state() -> Dictionary:
	return {
		"pos": player.position, "deaths": deaths, "coins": coins_taken, "finished": finished,
		"paused": get_tree().paused, "hp": hp, "stomps": kills, "kills": kills, "level": player_level,
		"time_left": time_left, "enemies_alive": enemies.size(), "boss_alive": boss != null and is_instance_valid(boss) and boss.alive, "boss_hp": boss.hp if boss != null and is_instance_valid(boss) else 0.0,
		"boss_pos": boss.position if boss != null and is_instance_valid(boss) else Vector2.ZERO,
		"progress": clampf(time_in_level / maxf(seconds, 1.0), 0.0, 1.0), "upgrades": owned.duplicate(),
	}
