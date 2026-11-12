extends Node2D
## Escena de juego de plataformas: monta el nivel desde game.json, el jugador, la camara,
## el HUD, los controles tactiles y las reglas (monedas, pinchos, enemigos, caidas, meta, anuncios),
## poderes, puntos de control, disparos, plataformas moviles y jefe final con su puerta.
## Genero runner (player -> auto_run): se corre solo, cada vez mas rapido, con barra de recorrido.
## Genero volador (player -> flap): arcade de un toque; la camara fija la altura y el techo para.

const TouchControls: GDScript = preload("res://kit/platformer/touch_controls.gd")

var tile: float = 64.0
var level: Node2D
var info: Dictionary = {}
var player: PlayerPlatformer
var camera: Camera2D

var coins_total: int = 0
var coins_taken: int = 0
var deaths: int = 0
var time_in_level: float = 0.0
var finished: bool = false
var result_panel: ResultPanel
var enemies: Array[Enemy] = []
var rows: Array[String] = []
var bonus: int = 0
var stomps: int = 0
var combo: int = 0
var boss: Enemy = null
var platforms: Array[MovingPlatform] = []
var powers_taken: int = 0
var checkpoints_reached: int = 0
var shots_hit: int = 0
var _bullets: Array[Dictionary] = []
var _goal_open: bool = true
var runner: bool = false
var flyer_mode: bool = false
var progress: float = 0.0
var _run_fill: ColorRect
## Vista 3D opcional (game.json -> "view": "3d"): solo dibuja, la logica sigue en 2D.
var view3d: Node3D = null

const POWER_NAMES: Dictionary = {"corazon": "+1 corazon", "doble_salto": "Doble salto", "iman": "Iman",
	"velocidad": "Velocidad", "estrella": "Estrella"}

var _hud: CanvasLayer
var _coins_label: Label
var _level_label: Label
var _hearts: HBoxContainer
var _powers_label: Label
var _boss_box: VBoxContainer
var _boss_fill: ColorRect


## Fantasma: recorrido propio y el de quien va por delante (online).
var ghost_points: Array = []
var ghost: GhostRunner = null
var _ghost_acc: float = 0.0


func _load_ghost() -> void:
	var d: Dictionary = await Online.ghost_download(Kit.level_index)
	if d.is_empty() or not is_inside_tree() or finished:
		return
	ghost = GhostRunner.make(d, self, Kit.sprite_by_role("jugador"), float(player.p["height"]) * 1.15)
	level.add_child(ghost)
	QA.log_event("ghost", {"alias": str(d.get("alias", "")), "points": ghost.points.size()})


func _ready() -> void:
	tile = float(Kit.param("tile_size", 64.0))
	RenderingServer.set_default_clear_color(Kit.color("sky", Color("#1b2a41")))
	_build_level()
	_build_player()
	runner = player.auto_run
	flyer_mode = player.flap
	_build_camera()
	if str(Kit.param("view", "2d")) == "3d":
		view3d = load("res://kit/platformer/platformer_view3d.gd").new()
		add_child(view3d)
		view3d.call("setup", self)
	_build_hud()
	add_child(TouchControls.new())
	Audio.play_track("nivel")
	if flyer_mode:
		UI.float_text(level, player.global_position + Vector2(tile * 2.0, -tile * 2.0), Kit.text("tap_to_fly", "Toca para volar"), UI.colors["acento"], 34)
	elif runner:
		UI.float_text(level, player.global_position + Vector2(tile * 2.0, -tile * 2.5), Kit.text("tap_to_jump", "Toca para saltar"), UI.colors["acento"], 34)
	QA.log_event("level_start", {"level": Kit.level_index, "coins": coins_total, "enemies": enemies.size(), "boss": boss != null, "view": "3d" if view3d != null else "2d"})
	_load_ghost.call_deferred()


func _build_level() -> void:
	level = Node2D.new()
	level.name = "Level"
	add_child(level)
	var palette: Dictionary = {
		"solid": Kit.color("solid", Color.WHITE),
		"danger": Kit.color("danger", Color.RED),
		"coin": Kit.color("coin", Color.YELLOW),
		"accent": Kit.color("accent", Color.ORANGE),
	}
	var data: Dictionary = Kit.current_level()
	var map: Array = data.get("map", [])
	if map.is_empty():
		QA.fail("level_empty", {"level": Kit.level_index})
		map = ["P......G", "########"]
	var art: Dictionary = {
		"tile": Kit.first_tile_texture(),
		"coin": Kit.sprite_entry(str(Kit.param("art.coin", "moneda"))),
	}
	info = LevelBuilder.build(level, map, tile, palette, art)
	var coins: Array[Area2D] = info["coins"]
	coins_total = coins.size()
	for coin: Area2D in coins:
		coin.body_entered.connect(_on_coin.bind(coin))
	rows = LevelBuilder.normalize(map)
	_spawn_enemies(info["enemy_spawns"])
	var spikes: Array[Area2D] = info["spikes"]
	for spike: Area2D in spikes:
		spike.body_entered.connect(_on_spike)
	var goal: Variant = info["goal_area"]
	if goal is Area2D:
		(goal as Area2D).body_entered.connect(_on_goal)
	else:
		QA.fail("level_without_goal", {"level": Kit.level_index})
	for pk: Dictionary in info["pickups"]:
		(pk["area"] as Area2D).body_entered.connect(_on_pickup.bind(pk["area"]))
	var flags: Array[Area2D] = info["checkpoints"]
	for flag: Area2D in flags:
		flag.body_entered.connect(_on_checkpoint.bind(flag))
	platforms = info["platforms"]
	## 7 - Con jefe, la meta esta cerrada con barrotes hasta vencerlo.
	if boss != null and goal is Area2D:
		_close_goal(goal as Area2D)


## 5 - Enemigos: parametros en game.json -> "enemies" -> <tipo>; arte por tipo en
## "art" -> "enemies" -> <tipo> (id del manifest) o, si no, el sprite con rol "enemigo".
func _spawn_enemies(spawns: Array) -> void:
	var col: Color = Kit.color("enemy", Kit.color("danger", Color.RED))
	var any_art: Dictionary = Kit.sprite_by_role("enemigo")
	for sp: Dictionary in spawns:
		var kind: String = str(sp["kind"])
		var art_id: String = str(Kit.param("art.enemies." + kind, ""))
		var art: Dictionary = Kit.sprite_entry(art_id) if art_id != "" else any_art
		var e: Enemy = Enemy.new()
		e.name = "Enemy_" + kind
		e.position = sp["pos"]
		level.add_child(e)
		e.setup(kind, Kit.param("enemies." + kind, {}), rows, tile, col.darkened(0.2) if kind == "boss" else col, art)
		enemies.append(e)
		if kind == "boss":
			boss = e
			e.defeated.connect(_on_boss_defeated)
			e.damaged.connect(func(_hp: int) -> void: _update_boss_bar())


func _build_player() -> void:
	player = PlayerPlatformer.new()
	player.name = "Player"
	var pcfg: Dictionary = (Kit.param("player", {}) as Dictionary).duplicate()
	pcfg["hp"] = Kit.player_hp(float(pcfg.get("hp", 3.0)))
	player.setup(pcfg, Kit.color("accent", Color.ORANGE), Kit.color("sky", Color.BLACK), Kit.sprite_by_role("jugador"))
	player.spawn_point = info["spawn"]
	player.global_position = info["spawn"]
	player.died.connect(_on_player_died)
	player.hurt_taken.connect(func(_hp: int) -> void: _update_hearts(true))
	player.jumped.connect(func() -> void: Audio.play("jump"))
	player.landed.connect(func(_speed: float) -> void: Audio.play("land", 0.1, -4.0))
	player.shot.connect(_on_shot)
	player.power_changed.connect(_update_powers)
	add_child(player)
	if boss != null:
		boss.target = player


func _build_camera() -> void:
	camera = Camera2D.new()
	camera.name = "Camera"
	var size: Vector2 = info["size"]
	camera.limit_left = 0
	## 4 - Margen inferior para que el suelo quede por encima de los botones tactiles.
	camera.limit_top = -int(tile * 2.0)
	camera.limit_right = int(size.x)
	camera.limit_bottom = int(size.y + tile * 4.0)
	camera.position = player.global_position
	## 4b - Mas cerca: a tamano real el heroe se veia diminuto en el movil (48 px de 720; con 1.25 aun 62 px).
	## El volador y el corredor no: necesitan ver todo el hueco y lo que viene.
	if not flyer_mode and not runner:
		camera.zoom = Vector2(1.5, 1.5)
	elif runner:
		## Corredor: algo mas cerca tambien (heroe diminuto y media pantalla de cielo, 12 nov); sigue
		## viendo de sobra lo que viene porque la camara va adelantada.
		camera.zoom = Vector2(1.4, 1.4)  ## 12 nov: a 1,2 el pinguino seguia siendo pequeno (critica 6/10)
	add_child(camera)
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
	## 1 - Barra superior: monedas, nombre del nivel y pausa (arriba a la derecha, lejos de los controles).
	var bar: HBoxContainer = HBoxContainer.new()
	bar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_constant_override("separation", 14)
	safe.add_child(bar)
	_hearts = HBoxContainer.new()
	_hearts.name = "Hearts"
	_hearts.add_theme_constant_override("separation", 2)
	_hearts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(_hearts)
	for i: int in player.max_hp:
		_hearts.add_child(UiIcon.make("heart", UI.colors["peligro"], 44.0))
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(8.0, 0.0)
	bar.add_child(gap)
	bar.add_child(UiIcon.make("coin", Kit.color("coin", UI.colors["acento"]), 46.0))
	_coins_label = Label.new()
	_coins_label.name = "Coins"
	bar.add_child(_coins_label)
	_level_label = Label.new()
	_level_label.name = "LevelName"
	_level_label.theme_type_variation = "SubtleLabel"
	## Encima del cielo del nivel: claro y con contorno para leerse con cualquier fondo.
	_level_label.add_theme_color_override("font_color", (UI.colors["texto_suave"] as Color).lightened(0.35))
	_level_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	_level_label.add_theme_constant_override("outline_size", 6)
	_level_label.text = str(Kit.current_level().get("name", ""))
	_level_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_level_label.clip_text = true
	bar.add_child(_level_label)
	_fit_level_name.call_deferred()
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	bar.add_child(pause_btn)
	## 8 - Debajo: poderes activos y, si lo hay, la vida del jefe.
	var col_box: VBoxContainer = VBoxContainer.new()
	col_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col_box.add_theme_constant_override("separation", 6)
	bar.get_parent().remove_child(bar)
	safe.add_child(col_box)
	col_box.add_child(bar)
	_powers_label = Label.new()
	_powers_label.name = "Powers"
	_powers_label.theme_type_variation = "SubtleLabel"
	_powers_label.add_theme_color_override("font_color", UI.colors["acento"])
	col_box.add_child(_powers_label)
	if runner:
		var run_back: ColorRect = ColorRect.new()
		run_back.name = "RunBar"
		run_back.color = (UI.colors["borde"] as Color)
		run_back.custom_minimum_size = Vector2(0.0, 12.0)
		run_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col_box.add_child(run_back)
		_run_fill = ColorRect.new()
		_run_fill.color = UI.colors["acento"]
		_run_fill.size = Vector2(0.0, 12.0)
		_run_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		run_back.add_child(_run_fill)
	if boss != null:
		_boss_box = VBoxContainer.new()
		_boss_box.name = "BossBar"
		_boss_box.visible = false
		_boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_boss_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col_box.add_child(_boss_box)
		var name_l: Label = Label.new()
		name_l.text = str(Kit.param("boss_name", Kit.text("boss", "Jefe")))
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_boss_box.add_child(name_l)
		var back: ColorRect = ColorRect.new()
		back.color = (UI.colors["borde"] as Color)
		back.custom_minimum_size = Vector2(360.0, 18.0)
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_boss_box.add_child(back)
		_boss_fill = ColorRect.new()
		_boss_fill.color = UI.colors["peligro"]
		_boss_fill.size = Vector2(360.0, 18.0)
		back.add_child(_boss_fill)
	_update_hud()
	_update_powers()


func _update_powers() -> void:
	if _powers_label == null:
		return
	var parts: Array[String] = []
	if player.air_jumps > 0:
		parts.append("Doble salto")
	if player.speed_left > 0.0:
		parts.append("Velocidad %d" % ceili(player.speed_left))
	if player.star_left > 0.0:
		parts.append("Estrella %d" % ceili(player.star_left))
	if player.magnet_left > 0.0:
		parts.append("Iman %d" % ceili(player.magnet_left))
	if player.can_shoot:
		parts.append("Disparo")
	_powers_label.text = "  \u00b7  ".join(parts)


func _update_boss_bar() -> void:
	if _boss_fill == null or boss == null or not is_instance_valid(boss):
		return
	var k: float = clampf(float(boss.hp) / float(boss.max_hp), 0.0, 1.0)
	var tw: Tween = _boss_fill.create_tween()
	tw.tween_property(_boss_fill, "size:x", 360.0 * k, 0.25).set_trans(Tween.TRANS_QUAD)


func _update_hud() -> void:
	_coins_label.text = "%d/%d" % [coins_taken, coins_total]
	_coins_label.pivot_offset = _coins_label.size * 0.5


## 3 - Corazones: los perdidos quedan en hueco; el que se pierde salta y parpadea.
func _update_hearts(animate: bool) -> void:
	if _hearts == null:
		return
	for i: int in _hearts.get_child_count():
		var icon: UiIcon = _hearts.get_child(i) as UiIcon
		var full: bool = i < player.hp
		var was_full: bool = icon.kind == "heart"
		icon.kind = "heart" if full else "heart_empty"
		icon.color = UI.colors["peligro"] if full else (UI.colors["texto_suave"] as Color)
		icon.queue_redraw()
		if animate and was_full and not full:
			icon.pivot_offset = icon.size * 0.5
			icon.scale = Vector2(1.7, 1.7)
			var tw: Tween = icon.create_tween()
			tw.tween_property(icon, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 2 - Pausa: boton, tecla o al salir de la app (llamada, cambiar de app).
func open_pause() -> void:
	if finished or get_tree().paused or get_node_or_null("PauseMenu") != null:
		return
	_release_inputs()
	PauseMenu.open(self)


func _release_inputs() -> void:
	for action: String in ["move_left", "move_right", "jump", "shoot"]:
		Input.action_release(action)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_inside_tree() and not UI.test_mode:
			open_pause()


func _physics_process(delta: float) -> void:
	if finished:
		return
	time_in_level += delta
	## Tu recorrido (por si es tu mejor marca: sera el fantasma que ven los demas).
	_ghost_acc += delta
	if _ghost_acc >= GhostRunner.STEP and ghost_points.size() < 3000:
		_ghost_acc -= GhostRunner.STEP
		ghost_points.append([roundi(player.global_position.x), roundi(player.global_position.y)])
	## 1 - Camara con anticipacion: mira hacia donde vas. Un poco por DEBAJO del heroe: el suelo queda por
	## encima de los botones tactiles y no media pantalla de cielo vacio (capturas del 12 nov).
	var ahead: Vector2 = Vector2(player.facing * tile * 1.6 + player.velocity.x * 0.12, tile * 0.6)
	if runner:
		## 9 - Runner: la camara deja mucho sitio delante para ver lo que viene.
		ahead = Vector2(tile * 3.2, tile * 0.3)
		_update_run(delta)
	if flyer_mode:
		## 11 - Volador: altura de camara fija (se ve todo el hueco) y techo invisible arriba.
		ahead.y = (info["size"] as Vector2).y * 0.5 + tile * 1.5 - player.global_position.y
		if player.global_position.y < tile * 1.2:
			player.global_position.y = tile * 1.2
			player.velocity.y = maxf(player.velocity.y, 0.0)
		## 12 - La meta es una linea de llegada: cruzarla a cualquier altura cuenta.
		if player.alive and player.global_position.x >= (info["goal"] as Vector2).x - tile * 0.5:
			_on_goal(player)
			return
	var target: Vector2 = player.global_position + ahead
	camera.position = camera.position.lerp(target, 1.0 - exp(-7.0 * delta))
	if player.is_on_floor():
		combo = 0
	_check_enemies()
	_move_bullets(delta)
	if player.magnet_left > 0.0:
		_pull_coins(delta)
	if int(time_in_level * 4.0) != int((time_in_level - delta) * 4.0):
		_update_powers()
	if _boss_box != null and boss != null and is_instance_valid(boss) and boss.alive:
		_boss_box.visible = absf(boss.global_position.x - player.global_position.x) < tile * 11.0
	## 2 - Caer fuera del mundo cuenta como muerte.
	if player.alive and player.global_position.y > float(info["bottom"]) + tile * 2.0:
		player.kill("fall")


## 10 - Runner: recorrido hecho y velocidad que sube con el (game.json -> runner_ramp).
func _update_run(_delta: float) -> void:
	var start_x: float = (info["spawn"] as Vector2).x
	var goal_x: float = (info["goal"] as Vector2).x
	progress = clampf((player.global_position.x - start_x) / maxf(goal_x - start_x, 1.0), 0.0, 1.0)
	player.speed_mult = 1.0 + float(Kit.param("runner_ramp", 0.22)) * progress
	if _run_fill != null:
		var back: Control = _run_fill.get_parent() as Control
		_run_fill.size = Vector2(back.size.x * progress, back.size.y)


func _on_coin(body: Node2D, coin: Area2D) -> void:
	if body != player or not is_instance_valid(coin) or coin.has_meta("taken"):
		return
	coin.set_meta("taken", true)
	coins_taken += 1
	_update_hud()
	_coins_label.scale = Vector2(1.35, 1.35)
	var pulse: Tween = _coins_label.create_tween()
	pulse.tween_property(_coins_label, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Audio.play("coin", 0.12)
	Juice.shake(0.05)
	## Chispas doradas y un aro al recoger (critica «efectos_pobres», 12 nov).
	Juice.sparkle(level, coin.global_position, Kit.color("coin", Color("#ffd23f")).lightened(0.3), 7, 220.0)
	Juice.ring(level, coin.global_position, Kit.color("coin", Color("#ffd23f")), tile * 0.7, 0.22)
	QA.log_event("coin", {"taken": coins_taken})
	var tween: Tween = coin.create_tween()
	tween.set_parallel(true)
	tween.tween_property(coin, "scale", Vector2(1.8, 1.8), 0.12)
	tween.tween_property(coin, "modulate:a", 0.0, 0.12)
	tween.chain().tween_callback(coin.queue_free)


## 6 - Contacto con enemigos. Pisoton si caes sobre la mitad de arriba de uno pisable;
## si no, dano. El margen es generoso a proposito: el jugador siente que "lo ha pisado".
func _check_enemies() -> void:
	if not player.alive:
		return
	var pr: Rect2 = player.hitbox()
	for v: Variant in enemies:
		if not is_instance_valid(v):
			continue
		var e: Enemy = v as Enemy
		if not e.alive:
			continue
		var er: Rect2 = e.hitbox()
		if not pr.intersects(er):
			continue
		if player.invincible():
			## 9 - Con la estrella, tocar a un enemigo lo derriba (al jefe le quita 1).
			_defeat(e, 1, "estrella")
			continue
		if e.stompable() and player.velocity.y > 40.0 and pr.end.y <= er.position.y + er.size.y * 0.55:
			_stomp(e)
		elif e.harmful():
			_hit_by(e)
			return


func _stomp(e: Enemy) -> void:
	combo += 1
	stomps += 1
	var top: Vector2 = Vector2(e.hitbox().get_center().x, e.hitbox().position.y)
	player.bounce()
	if e.kind == "boss":
		## 10 - Al jefe se le pisa varias veces: rebote extra alto para salir de encima.
		player.velocity.y = player.jump_velocity * 1.1
		e.damage(2)
		Audio.play("stomp", 0.02, 2.0, 0.7)
		Juice.hitstop(0.08)
		Juice.shake(0.4)
		Juice.vibrate(40)
		Juice.burst(level, top, Kit.color("enemy", Kit.color("danger", Color.RED)).lightened(0.3), 20)
		QA.log_event("boss_hit", {"by": "stomp", "hp": e.hp})
		return
	var gained: int = e.points() * int(pow(2.0, float(mini(combo - 1, 3))))
	bonus += gained
	e.die()
	Audio.play("stomp", 0.04, 0.0, 1.0 + 0.12 * float(mini(combo - 1, 4)))
	Juice.hitstop(0.045)
	Juice.shake(0.16 + 0.04 * float(combo))
	Juice.vibrate(25)
	Juice.burst(level, top, Kit.color("enemy", Kit.color("danger", Color.RED)).lightened(0.3), 14)
	var txt: String = "+%d" % gained if combo < 2 else "x%d  +%d" % [combo, gained]
	UI.float_text(level, top + Vector2(0.0, -24.0), txt, UI.colors["acento"] if combo < 2 else UI.colors["exito"])
	QA.log_event("stomp", {"kind": e.kind, "combo": combo, "points": gained})


## 11 - Derribo por disparo o estrella (no cuenta para el combo de pisotones).
func _defeat(e: Enemy, dmg: int, by: String) -> void:
	var at: Vector2 = e.hitbox().get_center()
	var killed: bool = e.damage(dmg)
	if e.kind == "boss":
		QA.log_event("boss_hit", {"by": by, "hp": e.hp})
		Juice.shake(0.2)
		return
	if not killed:
		return
	var gained: int = e.points()
	bonus += gained
	Audio.play("stomp", 0.05, -2.0, 1.2)
	Juice.burst(level, at, Kit.color("enemy", Kit.color("danger", Color.RED)).lightened(0.3), 10)
	UI.float_text(level, at + Vector2(0.0, -30.0), "+%d" % gained, UI.colors["acento"])
	QA.log_event("defeat", {"kind": e.kind, "by": by})


func _on_shot(origin: Vector2, direction: float) -> void:
	var b: Node2D = Node2D.new()
	b.position = origin
	var core: Polygon2D = Polygon2D.new()
	core.color = Kit.color("accent", Color.ORANGE).lightened(0.35)
	core.polygon = LevelBuilder._circle(9.0, 10)
	b.add_child(core)
	var glow: Polygon2D = Polygon2D.new()
	glow.color = Color(core.color.r, core.color.g, core.color.b, 0.3)
	glow.polygon = LevelBuilder._circle(16.0, 12)
	b.add_child(glow)
	level.add_child(b)
	_bullets.append({"node": b, "dir": direction, "life": 0.7})
	Audio.play("shoot", 0.08, -3.0)
	Juice.shake(0.03)


## 12 - Proyectiles: avanzan, se paran en paredes y derriban al primer enemigo que tocan.
func _move_bullets(delta: float) -> void:
	for i: int in range(_bullets.size() - 1, -1, -1):
		var bd: Dictionary = _bullets[i]
		var b: Node2D = bd["node"]
		b.position.x += float(bd["dir"]) * 900.0 * delta
		bd["life"] = float(bd["life"]) - delta
		var cx: int = int(floor(b.position.x / tile))
		var cy: int = int(floor(b.position.y / tile))
		var gone: bool = float(bd["life"]) <= 0.0 or LevelAnalyzer.is_solid(rows, cx, cy)
		if not gone:
			for v: Variant in enemies:
				if not is_instance_valid(v):
					continue
				var e: Enemy = v as Enemy
				if e.alive and e.hitbox().grow(10.0).has_point(b.position):
					shots_hit += 1
					_defeat(e, 1, "disparo")
					gone = true
					break
		if gone:
			Juice.burst(level, b.position, Color.WHITE, 5, 120.0)
			b.queue_free()
			_bullets.remove_at(i)


func _pull_coins(delta: float) -> void:
	var coins: Array[Area2D] = info["coins"]
	for c: Area2D in coins:
		if not is_instance_valid(c) or c.has_meta("taken"):
			continue
		var d: Vector2 = player.global_position + Vector2(0.0, -28.0) - c.global_position
		if d.length() < tile * 3.5:
			c.global_position += d.normalized() * minf(d.length(), 700.0 * delta)


func _on_pickup(body: Node2D, area: Area2D) -> void:
	if body != player or not is_instance_valid(area) or area.has_meta("taken"):
		return
	area.set_meta("taken", true)
	var kind: String = str(area.get_meta("kind"))
	player.give_power(kind)
	powers_taken += 1
	_update_hearts(false)
	_update_powers()
	Audio.play("powerup", 0.03)
	Juice.vibrate(20)
	Juice.burst(level, area.global_position, Color.WHITE, 12, 220.0)
	UI.float_text(level, area.global_position + Vector2(0.0, -40.0), POWER_NAMES.get(kind, kind), UI.colors["exito"], 30)
	QA.log_event("power", {"kind": kind})
	var tw: Tween = area.create_tween()
	tw.set_parallel(true)
	tw.tween_property(area, "scale", Vector2(1.8, 1.8), 0.15)
	tw.tween_property(area, "modulate:a", 0.0, 0.15)
	tw.chain().tween_callback(area.queue_free)


func _on_checkpoint(body: Node2D, flag: Area2D) -> void:
	if body != player or flag.has_meta("on"):
		return
	flag.set_meta("on", true)
	checkpoints_reached += 1
	player.spawn_point = flag.global_position + Vector2(0.0, tile * 0.5)
	var f: Polygon2D = flag.get_node("Flag") as Polygon2D
	var tw: Tween = flag.create_tween()
	tw.set_parallel(true)
	tw.tween_property(f, "position:y", -tile * 0.5, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(f, "color", Kit.color("accent", Color.ORANGE), 0.35)
	Audio.play("coin", 0.0, 0.0, 1.5)
	UI.float_text(level, flag.global_position + Vector2(0.0, -60.0), Kit.text("checkpoint", "Punto de control"), UI.colors["texto"], 28)
	QA.log_event("checkpoint", {"x": int(flag.global_position.x / tile)})


func _close_goal(goal: Area2D) -> void:
	_goal_open = false
	goal.set_deferred("monitoring", false)
	var bars: Node2D = Node2D.new()
	bars.name = "Bars"
	for i: int in 4:
		var bar_p: Polygon2D = Polygon2D.new()
		bar_p.color = Color(0.75, 0.78, 0.86)
		bar_p.polygon = LevelBuilder._rect(Vector2(-tile * 0.45 + float(i) * tile * 0.28, -tile * 0.55), Vector2(8.0, tile * 1.1))
		bars.add_child(bar_p)
	goal.add_child(bars)


func _on_boss_defeated(e: Enemy) -> void:
	bonus += e.points()
	QA.log_event("boss_defeated", {"time": snappedf(time_in_level, 0.1)})
	Juice.hitstop(0.15, 0.02)
	Juice.shake(0.7)
	Juice.vibrate(80)
	Juice.burst(level, e.hitbox().get_center(), Kit.color("accent", Color.ORANGE), 30, 420.0)
	UI.float_text(level, e.hitbox().get_center() + Vector2(0.0, -60.0), "+%d" % e.points(), UI.colors["acento"], 44)
	if _boss_box != null:
		_boss_box.visible = false
	var goal: Variant = info["goal_area"]
	if goal is Area2D:
		_goal_open = true
		(goal as Area2D).set_deferred("monitoring", true)
		var bars: Node2D = (goal as Area2D).get_node_or_null("Bars") as Node2D
		if bars != null:
			var tw: Tween = bars.create_tween()
			tw.tween_property(bars, "position:y", -tile * 1.4, 0.6).set_trans(Tween.TRANS_BACK)
			tw.parallel().tween_property(bars, "modulate:a", 0.0, 0.6)
		UI.float_text(level, (goal as Area2D).global_position + Vector2(0.0, -80.0), Kit.text("door_open", "\u00a1Camino libre!"), UI.colors["exito"], 34)
	Audio.play("powerup", 0.0, 0.0, 0.8)


func _hit_by(e: Enemy) -> void:
	if not player.hurt(e.global_position.x):
		return
	QA.log_event("hit", {"kind": e.kind, "hp": player.hp})
	if player.hp <= 0:
		return
	Audio.play("hurt")
	Juice.flash(player.visual)
	Juice.shake(0.32)
	Juice.vibrate(45)
	Juice.hitstop(0.07)
	Juice.burst(level, player.global_position + Vector2(0.0, -28.0), Color.WHITE, 8, 200.0)


func _on_spike(body: Node2D) -> void:
	if body == player:
		player.kill("spike")


func _on_player_died(cause: String) -> void:
	deaths += 1
	QA.log_event("death", {"cause": cause, "deaths": deaths, "x": int(player.global_position.x / tile)})
	Audio.play("hurt")
	Juice.flash(player.visual)
	Juice.shake(0.45)
	Juice.vibrate(40)
	Juice.hitstop(0.08)
	## Muerte con gesto: el heroe sale despedido girando y se desvanece (antes desaparecia sin mas).
	Juice.burst(level, player.global_position + Vector2(0.0, -28.0), Kit.color("accent", Color.ORANGE), 18, 340.0)
	var tw: Tween = player.visual.create_tween().set_parallel(true)
	tw.tween_property(player.visual, "rotation", TAU * 1.5, 0.5)
	tw.tween_property(player.visual, "position:y", player.visual.position.y - 90.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(player.visual, "scale", Vector2(0.2, 0.2), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(player.visual, "modulate:a", 0.0, 0.5)
	var base_y: float = player.visual.position.y
	await get_tree().create_timer(0.55, true, false, true).timeout
	if is_instance_valid(player):
		tw.kill()
		player.visual.position.y = base_y
		player.visual.modulate.a = 1.0
		player.respawn()
		Juice.ring(level, player.global_position + Vector2(0.0, -28.0), Color(1, 1, 1, 0.9), 70.0)
		_update_hearts(false)


func _on_goal(body: Node2D) -> void:
	if body != player or finished:
		return
	finished = true
	player.alive = false
	_release_inputs()
	Online.ghost_pending = {"level": Kit.level_index, "points": ghost_points.duplicate()}
	var level_id: String = str(Kit.level_index)
	var score: int = coins_taken * 100 + bonus + maxi(0, 3000 - int(time_in_level * 20.0)) - deaths * 50
	var stars: int = stars_earned()
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {
		"level": Kit.level_index, "time": snappedf(time_in_level, 0.01),
		"coins": coins_taken, "deaths": deaths, "score": score, "record": record, "stars": stars,
		"stomps": stomps, "powers": powers_taken, "checkpoints": checkpoints_reached, "shots_hit": shots_hit,
	})
	Audio.play("win")
	Audio.play_track("victoria", false)
	Juice.shake(0.2)
	Juice.confetti(level, player.global_position + Vector2(0.0, -40.0))
	result_panel = ResultPanel.open(self, {
		"stars": stars, "coins": coins_taken, "coins_total": coins_total, "score": score, "record": record,
	})
	await Ads.show_interstitial("level_end")


## 3 - Estrellas: una por terminar, otra por todas las monedas y otra por no morir.
func stars_earned() -> int:
	var n: int = 1
	if coins_taken >= coins_total:
		n += 1
	if deaths == 0:
		n += 1
	return n


func enemies_alive() -> int:
	var n: int = 0
	for v: Variant in enemies:
		if is_instance_valid(v) and (v as Enemy).alive:
			n += 1
	return n


## 4 - Estado para los bots de QA.
func bot_state() -> Dictionary:
	return {
		"pos": player.global_position,
		"vel": player.velocity,
		"on_floor": player.is_on_floor(),
		"alive": player.alive,
		"coins": coins_taken,
		"deaths": deaths,
		"finished": finished,
		"paused": get_tree().paused,
		"hp": player.hp,
		"stomps": stomps,
		"enemies_alive": enemies_alive(),
		"boss_hp": boss.hp if boss != null and is_instance_valid(boss) else 0,
		"boss_alive": boss != null and is_instance_valid(boss) and boss.alive,
		"powers": powers_taken,
		"checkpoints": checkpoints_reached,
		"goal": info["goal"],
		"runner": runner,
		"progress": progress,
	}


## Nombre de nivel largo: letra algo mas pequena para que se lea entero (si aun no cabe, "...").
func _fit_level_name() -> void:
	if _level_label == null or not is_instance_valid(_level_label):
		return
	var f: Font = _level_label.get_theme_font("font")
	var fs: int = _level_label.get_theme_font_size("font_size")
	var w: float = f.get_string_size(_level_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var room: float = _level_label.size.x - 4.0
	if room > 0.0 and w > room:
		_level_label.add_theme_font_size_override("font_size", maxi(int(float(fs) * room / w), int(float(fs) * 0.75)))
