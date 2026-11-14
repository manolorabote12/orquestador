extends Node2D
## Arena (vista desde arriba): todos contra todos, el ultimo en pie gana.
## 1 - Te mueves con el joystick (o flechas/WASD). El boton de ataque apunta solo al rival
##     visible mas cercano y lanza una rafaga de 3 balas; tienes 3 cargas que se recargan.
## 2 - Cada impacto carga el super: una onda de balas en todas direcciones.
## 3 - Las cajas se rompen y sueltan cubos de poder (+10 % de vida y dano cada uno). Los
##     rivales eliminados sueltan los suyos.
## 4 - En los arbustos no te ven de lejos (ni tu a ellos). Al disparar te descubres un momento.
## 5 - Si pasas 3 s sin dar ni recibir golpes, te curas. A partir de un momento el gas cierra
##     la arena hacia el centro y quita vida fuera del circulo.
## 6 - Ganas al eliminar a todos los rivales; si te eliminan, repites.
## Mapa: "#" muro, "*" arbusto, "B" caja, "P" tu salida, "R" salida de un rival, "." suelo.
## Modos (nivel "mode"):
##   "showdown" (por defecto): todos contra todos, el ultimo en pie gana.
##   "survival": tu (y tus aliados "A") contra oleadas ("waves") que salen de las "R". Sin gas.
##   "ball": 3 contra 3. "O" el balon, "G" la porteria rival (marcas ahi) y "g" la tuya. Quien lo
##     toca lo lleva; el boton de ataque lo chuta (hacia la porteria si esta a tiro). Gana quien
##     marque 2 o vaya ganando al acabar el tiempo ("time"); con empate, el siguiente gol gana.
##   "turrets": 3 contra 3. "t" la torreta rival, "T" la tuya: dispara sola a quien se acerque.
##     Gana quien derribe la otra; al acabar el tiempo, la que tenga mas vida.
##   En los dos de equipo nadie queda fuera: a los 3 s vuelves a tu salida.
## Personajes: el jugador lleva el elegido (Brawlers.chosen()) y cada bot uno del catalogo, con su
## vida, velocidad, dano, forma de disparar y super (ver brawlers.gd).
## Nivel: {"map", "rival_hp", "rival_dmg", "aim" (error en radianes), "reaction" (s),
##   "gas_start" (s), "gas_time" (s que tarda en cerrarse), "par" (s para la tercera estrella)}.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const TILE: float = 96.0
const WALL_H: float = 30.0
const SHOT_RANGE: float = 560.0
const SHOT_SPEED: float = 1150.0
const SUPER_RANGE: float = 430.0
const BUSH_SEE: float = 170.0
const GAS_DPS: float = 420.0
const REGEN: float = 0.13
const PLAYER_HP: float = 3200.0
const PLAYER_DMG: float = 300.0
## Segundos del principio en los que los rivales abren cajas en vez de buscar pelea.
const FARM_TIME: float = 16.0
const RESPAWN_TIME: float = 3.0
const BALL_GOALS: int = 2
const TURRET_HP: float = 7500.0
const TURRET_RANGE: float = 520.0
const BALL_R: float = 22.0

var rows: Array[String] = []
var finished: bool = false
var failed: bool = false
var deaths: int = 0
var time_in_level: float = 0.0
var fast: bool = false
var auto_retry: bool = false
var result_panel: ResultPanel
var coins: int = 0
var coins_total: int = 0

var rival_hp: float = 2600.0
var rival_dmg: float = 0.8
var aim_error: float = 0.2
var reaction: float = 0.45
var gas_start: float = 40.0
var gas_time: float = 40.0
var par: float = 60.0

var fighters: Array[BrawlFighter] = []
var player: BrawlFighter = null
## Casilla -> vida que le queda a la caja.
var boxes: Dictionary = {}
## {"pos": Vector2, "t": float}
var cubes: Array[Dictionary] = []
## {"pos", "vel", "owner", "dmg", "left", "col"}
var bullets: Array[Dictionary] = []
var gas_center: Vector2 = Vector2.ZERO
var gas_radius: float = 99999.0
var gas_max: float = 99999.0
## El bot de QA mueve al jugador con esto (si no es cero, manda sobre el joystick).
var move_input: Vector2 = Vector2.ZERO
var aim_target: BrawlFighter = null
var kills: int = 0
var placed: int = 1

var _size: Vector2i = Vector2i.ZERO
var _walls: Dictionary = {}
var _bush: Dictionary = {}
var _box_nodes: Dictionary = {}
var _spawns: Array[Vector2] = []
var _start: Vector2 = Vector2.ZERO
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _arts: Array[Dictionary] = []
var _floor: Node2D
var _actors: Node2D
var _bushes: Node2D
var _fx: Node2D
var _gas: Node2D
var _camera: Camera2D
var stick: HordeStick
var _pad_attack: BrawlPad
## Apuntado a mano (arrastrando el boton): direccion mientras apuntas, Vector2.ZERO si no.
var aim_attack: Vector2 = Vector2.ZERO
var aim_super: Vector2 = Vector2.ZERO
var _pad_super: BrawlPad
var _left_label: Label
var _gas_label: Label
var _left_icon: UiIcon
var _flow: Dictionary = {}
## Dano que se va sumando a cada luchador para ensenarlo como un solo numero por rafaga.
var _dmg_acc: Dictionary = {}
## Arena en directo (Online.arena_match): sala, quien soy, jugadores, nivel y cuando empieza.
var online: Dictionary = {}
var net: RealtimeChannel = null
var my_id: String = ""
var host: bool = false
var by_id: Dictionary = {}
var reported: bool = false
var _start_ms: int = 0
var _send_acc: float = 0.0
var _countdown: Label = null
## Cooperativo (sala con amigos en modo "coop"): juntos contra oleadas de bots.
var coop: bool = false
## Modo de juego (ver arriba) y lo que lleva cada uno.
var mode: String = "showdown"
var teams: bool = false
var respawn: bool = false
## Las pruebas (y el bot de QA) pueden dejar que el juego mueva al jugador con la misma IA.
var autopilot: bool = false
var time_limit: float = 150.0
var waves: int = 3
var goals_score: Array[int] = [0, 0]
var overtime: bool = false
## Balon: posicion, velocidad y quien lo lleva.
var ball: Dictionary = {}
## Porterias: casillas de la que defiende cada equipo (0 = la tuya "g", 1 = la rival "G").
var goal_cells: Array[Dictionary] = [{}, {}]
var turrets: Array = [null, null]
var _allies: Array[Vector2] = []
var _ball_start: Vector2 = Vector2.ZERO
var _turret_at: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var _wave_pending: bool = false
var wave: int = 0
const COOP_WAVES: int = 3
const NET_RATE: float = 1.0 / 12.0
const NET_TIMEOUT: float = 6.0


func _ready() -> void:
	online = Online.arena_match.duplicate(true)
	coop = str(online.get("modo", "")) == "coop"
	var lv: Dictionary = Kit.current_level()
	rows = LevelBuilder.normalize(lv.get("map", ["P"]))
	_size = Vector2i(rows[0].length(), rows.size())
	rival_hp = float(lv.get("rival_hp", 2600.0))
	rival_dmg = float(lv.get("rival_dmg", 0.8))
	aim_error = float(lv.get("aim", 0.2))
	reaction = float(lv.get("reaction", 0.45))
	gas_start = float(lv.get("gas_start", 40.0))
	gas_time = float(lv.get("gas_time", 40.0))
	par = float(lv.get("par", 60.0))
	mode = str(lv.get("mode", "showdown"))
	if not mode in ["showdown", "survival", "ball", "turrets"] or not online.is_empty():
		mode = "showdown"
	teams = coop or mode != "showdown"
	respawn = mode in ["ball", "turrets"]
	time_limit = float(lv.get("time", 150.0))
	waves = clampi(int(lv.get("waves", 3)), 1, 8)
	if coop or mode != "showdown":
		gas_start = 99999.0
	RenderingServer.set_default_clear_color(Kit.color("sky", Color("#1b2a41")).darkened(0.35))
	for t: String in ["walker", "spiky", "flyer"]:
		var id: String = str(Kit.param("art.enemies." + t, ""))
		if id != "":
			var entry: Dictionary = Kit.sprite_entry(id)
			if not entry.is_empty():
				_arts.append(entry)
	if _arts.is_empty():
		var e: Dictionary = Kit.sprite_by_role("enemigo")
		if not e.is_empty():
			_arts.append(e)
	_floor = Node2D.new()
	_floor.name = "Floor"
	_floor.draw.connect(_draw_floor)
	add_child(_floor)
	_actors = Node2D.new()
	_actors.name = "Actors"
	_actors.y_sort_enabled = true
	add_child(_actors)
	_bushes = Node2D.new()
	_bushes.name = "Bushes"
	_bushes.z_index = 5
	_bushes.draw.connect(_draw_bushes)
	add_child(_bushes)
	_fx = Node2D.new()
	_fx.name = "Fx"
	_fx.z_index = 6
	_fx.draw.connect(_draw_fx)
	add_child(_fx)
	_gas = Node2D.new()
	_gas.name = "Gas"
	_gas.z_index = 7
	_gas.draw.connect(_draw_gas)
	add_child(_gas)
	_camera = Camera2D.new()
	_camera.name = "Camera"
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 7.0
	add_child(_camera)
	_camera.make_current()
	Juice.register_camera(_camera)
	## El super va con E o L (W y la flecha arriba ya mueven).
	if not InputMap.has_action("super"):
		InputMap.add_action("super")
		for k: Key in [KEY_E, KEY_L]:
			var ev: InputEventKey = InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event("super", ev)
	_build_hud()
	stick = HordeStick.new()
	stick.name = "Stick"
	add_child(stick)
	_reset()
	if not online.is_empty():
		_net_open()
	Audio.play_track("nivel")
	UI.float_text(_fx, player.position + Vector2(0.0, -150.0), Kit.text("coop_hint", "\u00a1Juntos contra {n} oleadas!").format({"n": COOP_WAVES}) if coop
		else _mode_hint(), UI.colors["acento"], 36)
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "brawl", "rivals": _spawns.size()})


func bot_script() -> String:
	return "res://qa/brawl_bot.gd"


func _mode_hint() -> String:
	match mode:
		"survival":
			return Kit.text("brawl_hint_survival", "\u00a1Aguanta {n} oleadas!").format({"n": waves})
		"ball":
			return Kit.text("brawl_hint_ball", "\u00a1Mete el bal\u00f3n en su porter\u00eda!")
		"turrets":
			return Kit.text("brawl_hint_turrets", "\u00a1Derriba su torreta!")
	return Kit.text("brawl_hint", "\u00a1El \u00faltimo en pie gana!")


# ------------------------------------------------------------------ montaje

func _reset() -> void:
	for c: Node in _actors.get_children():
		_actors.remove_child(c)
		c.queue_free()
	fighters.clear()
	boxes.clear()
	_box_nodes.clear()
	cubes.clear()
	bullets.clear()
	_walls.clear()
	_bush.clear()
	_spawns.clear()
	_allies.clear()
	goal_cells = [{}, {}]
	turrets = [null, null]
	goals_score = [0, 0]
	overtime = false
	ball = {}
	wave = 0
	_wave_pending = false
	_flow.clear()
	_dmg_acc.clear()
	finished = false
	failed = false
	time_in_level = 0.0
	coins = 0
	kills = 0
	placed = 1
	move_input = Vector2.ZERO
	aim_target = null
	_rng.seed = 4242 + Kit.level_index * 131
	for y: int in _size.y:
		for x: int in _size.x:
			var ch: String = rows[y][x]
			var cell: Vector2i = Vector2i(x, y)
			match ch:
				"#":
					_walls[cell] = true
				"*":
					_bush[cell] = true
				"B":
					## En directo no hay cajas (lo que sale de ellas no se podria repartir igual para todos).
					if online.is_empty():
						boxes[cell] = 1300.0
				"P":
					_start = center_of(cell)
				"R":
					_spawns.append(center_of(cell))
				"A":
					_allies.append(center_of(cell))
				"O":
					_ball_start = center_of(cell)
					ball = {"pos": _ball_start, "vel": Vector2.ZERO, "holder": null, "cool": 0.0}
				"g":
					goal_cells[0][cell] = true
				"G":
					goal_cells[1][cell] = true
				"T":
					_turret_at[0] = center_of(cell)
				"t":
					_turret_at[1] = center_of(cell)
	if mode == "ball" and ball.is_empty():
		_ball_start = Vector2(_size) * TILE * 0.5
		ball = {"pos": _ball_start, "vel": Vector2.ZERO, "holder": null, "cool": 0.0}
	coins_total = boxes.size()
	for cell: Vector2i in _walls.keys():
		var w: Node2D = Node2D.new()
		w.position = Vector2(float(cell.x) * TILE, float(cell.y + 1) * TILE)
		w.draw.connect(_draw_wall.bind(w, cell))
		_actors.add_child(w)
	for cell: Vector2i in boxes.keys():
		var b: Node2D = Node2D.new()
		b.position = Vector2(float(cell.x) * TILE, float(cell.y + 1) * TILE)
		b.draw.connect(_draw_box.bind(b, cell))
		_actors.add_child(b)
		_box_nodes[cell] = b
	by_id.clear()
	if online.is_empty():
		player = _make_fighter(true, _start, 0)
		if teams:
			player.team = 0
		for i: int in _allies.size():
			var a: BrawlFighter = _make_fighter(false, _allies[i], 20 + i)
			a.team = 0
			a.name = "Ally%d" % i
			a.bar_color = Color("#4fc3ff")
			a.ai["home"] = _allies[i]
		if mode == "survival":
			spawn_survival(1)
		else:
			for i: int in _spawns.size():
				var r: BrawlFighter = _make_fighter(false, _spawns[i], i)
				if teams:
					r.team = 1
				r.ai["home"] = _spawns[i]
		if mode == "turrets":
			for t: int in 2:
				_make_turret(t)
	else:
		_net_fighters()
	var world: Vector2 = Vector2(_size) * TILE
	gas_center = world * 0.5
	gas_max = world.length() * 0.5 + TILE
	gas_radius = gas_max
	_camera.position = player.position
	_camera.reset_smoothing()
	var vp: Vector2 = get_viewport_rect().size
	_camera.zoom = Vector2.ONE * clampf(vp.x / (TILE * 7.4), 0.5, 1.4)
	_floor.queue_redraw()
	_bushes.queue_redraw()
	if _left_icon != null:
		## En balon y torretas el marcador lleva copa; en el resto, la calavera de rivales que quedan.
		var team_score: bool = mode in ["ball", "turrets"]
		_left_icon.kind = "trophy" if team_score else "skull"
		_left_icon.color = Color("#ffd166") if team_score else Color("#ff8a80")
		_left_icon.queue_redraw()
	_update_hud()


func _make_fighter(is_player: bool, at: Vector2, i: int) -> BrawlFighter:
	var f: BrawlFighter = BrawlFighter.new()
	f.is_player = is_player
	f.position = at
	var b: Dictionary = Brawlers.catalog()[0] if not online.is_empty() else (Brawlers.chosen() if is_player else Brawlers.for_bot(i))
	if is_player:
		f.name = "Player"
		## Mejora de la tienda: +8 % de vida y dano por nivel.
		var up: float = (1.0 + 0.08 * float(Save.upgrade_level("luchador"))) * (Brawlers.power_mult(str(b.get("id", ""))) if online.is_empty() else 1.0)
		f.max_hp = Kit.player_hp(PLAYER_HP) * up * float(b.get("hp", 1.0))
		f.damage = PLAYER_DMG * up * float(b.get("dmg", 1.0))
		f.speed = float(Kit.param("player.brawl_speed", 330.0)) * float(b.get("speed", 1.0))
		f.bar_color = Color("#5fd35f")
		f.setup(Brawlers.sprite_entry(b), Kit.color("accent", Color.ORANGE), 108.0)
		if f.sprite != null:
			Skins.apply(f.sprite)
			if str(b.get("tint", "")) != "":
				f.sprite.self_modulate = Brawlers.tint(b)
	else:
		f.name = "Rival%d" % i
		f.max_hp = rival_hp * float(b.get("hp", 1.0))
		f.damage = PLAYER_DMG * rival_dmg * float(b.get("dmg", 1.0))
		f.speed = 290.0 * float(b.get("speed", 1.0))
		f.reload_time = 1.35
		f.bar_color = Color("#ff5a4f")
		## Los aliados (i >= 20) se ven como tu personaje, tenido; los rivales, con el arte de enemigos.
		var art: Dictionary = Kit.sprite_by_role("jugador") if i >= 20 else (_arts[i % _arts.size()] if not _arts.is_empty() else {})
		f.setup(art, Kit.color("danger", Color("#ff6b5b")), 104.0)
		if f.sprite != null and str(b.get("tint", "")) != "":
			f.sprite.self_modulate = Brawlers.tint(b)
	f.ai = {"think": 0.1 * float(i), "aim": 0.0, "strafe": 1.0 if i % 2 == 0 else -1.0, "flip": 1.5, "goal": at,
		"atk": Brawlers.attack_of(b), "super": str(b.get("super", "ola")), "brawler": str(b.get("id", "")), "home": at}
	f.hp = f.max_hp
	f.remember_base()
	f.facing = Vector2.UP if is_player else Vector2.DOWN
	_actors.add_child(f)
	fighters.append(f)
	return f


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
	var bar: HBoxContainer = HBoxContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_constant_override("separation", 12)
	col.add_child(bar)
	_left_icon = UiIcon.make("skull", Color("#ff8a80"), 44.0)
	bar.add_child(_left_icon)
	_left_label = Label.new()
	_left_label.name = "RivalsLeft"
	_left_label.theme_type_variation = "HeaderLabel"
	bar.add_child(_left_label)
	_gas_label = Label.new()
	_gas_label.name = "GasLabel"
	_gas_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gas_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(_gas_label)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	bar.add_child(pause_btn)
	var grow: Control = Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(grow)
	var pads: HBoxContainer = HBoxContainer.new()
	pads.alignment = BoxContainer.ALIGNMENT_END
	pads.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pads.add_theme_constant_override("separation", 18)
	col.add_child(pads)
	_pad_super = BrawlPad.new()
	_pad_super.name = "PadSuper"
	_pad_super.label = Kit.text("brawl_super", "S\u00faper")
	_pad_super.color = Color("#ffcf3f")
	_pad_super.custom_minimum_size = Vector2(124, 124)
	_pad_super.size_flags_vertical = Control.SIZE_SHRINK_END
	_pad_super.pressed.connect(use_super)
	_pad_super.aim.connect(func(d: Vector2) -> void: aim_super = d)
	_pad_super.aimed.connect(super_toward)
	pads.add_child(_pad_super)
	_pad_attack = BrawlPad.new()
	_pad_attack.name = "PadAttack"
	_pad_attack.label = Kit.text("brawl_attack", "\u00a1Fuego!")
	_pad_attack.color = Color("#ff6b5b")
	_pad_attack.segments = BrawlFighter.AMMO_MAX
	_pad_attack.custom_minimum_size = Vector2(176, 176)
	_pad_attack.pressed.connect(attack)
	_pad_attack.aim.connect(func(d: Vector2) -> void: aim_attack = d)
	_pad_attack.aimed.connect(attack_toward)
	pads.add_child(_pad_attack)
	var pad_gap: Control = Control.new()
	pad_gap.custom_minimum_size = Vector2(0, 30)
	pad_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(pad_gap)


func _update_hud() -> void:
	if _left_label == null:
		return
	_left_label.text = str(rivals_left())
	if mode != "showdown":
		_mode_hud()
	elif time_in_level < gas_start:
		var t: int = int(ceil(gas_start - time_in_level))
		_gas_label.text = Kit.text("brawl_gas_in", "Gas en {t}").format({"t": "%d:%02d" % [t / 60, t % 60]})
		_gas_label.add_theme_color_override("font_color", UI.colors["texto_suave"])
	else:
		_gas_label.text = Kit.text("brawl_gas", "\u00a1Llega el gas!")
		_gas_label.add_theme_color_override("font_color", Color(str(Kit.param("brawl_gas_color", "#73f259"))).lightened(0.3))
	if player != null:
		_pad_attack.fill = player.ammo / float(BrawlFighter.AMMO_MAX)
		_pad_attack.armed = player.ammo >= 1.0
		_pad_super.fill = player.super_charge
		_pad_super.armed = player.super_charge >= 1.0
	if stick != null and _pad_attack.is_inside_tree():
		stick.blocked = [_pad_attack.get_global_rect().grow(16.0), _pad_super.get_global_rect().grow(16.0)]


# ------------------------------------------------------------------ mapa

func center_of(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * TILE


func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / TILE), floori(p.y / TILE))


func blocked(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= _size.x or cell.y >= _size.y:
		return true
	return _walls.has(cell) or boxes.has(cell)


func in_bush(p: Vector2) -> bool:
	return _bush.has(cell_of(p))


## Un circulo cabe en p sin tocar muros ni cajas.
func free_at(p: Vector2, r: float) -> bool:
	var a: Vector2i = cell_of(p - Vector2(r, r))
	var b: Vector2i = cell_of(p + Vector2(r, r))
	for y: int in range(a.y, b.y + 1):
		for x: int in range(a.x, b.x + 1):
			var c: Vector2i = Vector2i(x, y)
			if not blocked(c):
				continue
			var rect: Rect2 = Rect2(Vector2(c) * TILE, Vector2(TILE, TILE))
			var q: Vector2 = Vector2(clampf(p.x, rect.position.x, rect.end.x), clampf(p.y, rect.position.y, rect.end.y))
			if q.distance_squared_to(p) < r * r:
				return false
	return true


## Linea sin muros ni cajas entre a y b (con un margen r a los lados si r > 0).
func line_clear(a: Vector2, b: Vector2, r: float = 0.0) -> bool:
	var d: float = a.distance_to(b)
	var steps: int = maxi(1, int(d / 24.0))
	for i: int in range(1, steps):
		var p: Vector2 = a.lerp(b, float(i) / float(steps))
		if r > 0.0:
			if not free_at(p, r):
				return false
		elif blocked(cell_of(p)):
			return false
	return true


## Mapa de distancias (en casillas) hasta una casilla; se guarda unos instantes.
func flow_to(target: Vector2i) -> Dictionary:
	var key: Vector2i = target
	var cached: Variant = _flow.get(key)
	if cached != null and time_in_level - float((cached as Dictionary)["t"]) < 0.5:
		return (cached as Dictionary)["d"]
	var dist: Dictionary = {target: 0}
	var queue: Array[Vector2i] = [target]
	var head: int = 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		for n: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nc: Vector2i = c + n
			if dist.has(nc) or blocked(nc):
				continue
			dist[nc] = int(dist[c]) + 1
			queue.append(nc)
	_flow[key] = {"t": time_in_level, "d": dist}
	return dist


## Siguiente punto hacia goal esquivando muros (en linea recta si se puede).
func next_step(from: Vector2, goal: Vector2) -> Vector2:
	if line_clear(from, goal, BrawlFighter.RADIUS * 0.8):
		return goal
	var gc: Vector2i = cell_of(goal)
	if blocked(gc):
		gc = nearest_open(gc)
	var dist: Dictionary = flow_to(gc)
	var here: Vector2i = cell_of(from)
	var best: Vector2i = here
	var best_d: int = int(dist.get(here, 9999))
	for n: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		var nc: Vector2i = here + n
		if not dist.has(nc):
			continue
		## En diagonal solo si las dos casillas de al lado estan libres (no se corta la esquina).
		if n.x != 0 and n.y != 0 and (blocked(here + Vector2i(n.x, 0)) or blocked(here + Vector2i(0, n.y))):
			continue
		var d: int = int(dist[nc])
		if d < best_d:
			best_d = d
			best = nc
	return center_of(best)


func nearest_open(c: Vector2i) -> Vector2i:
	for r: int in range(1, 6):
		for y: int in range(-r, r + 1):
			for x: int in range(-r, r + 1):
				var nc: Vector2i = c + Vector2i(x, y)
				if not blocked(nc):
					return nc
	return c


# ------------------------------------------------------------------ bucle

func _physics_process(delta: float) -> void:
	if finished or failed or player == null:
		return
	if not online.is_empty():
		## En directo no se pausa el mundo (los demas siguen jugando) y el reloj es el de la sala.
		var t: float = float(Time.get_ticks_msec() - _start_ms) / 1000.0
		if t < 0.0:
			_show_countdown(t)
			return
		_show_countdown(t)
		time_in_level = t
	elif get_tree().paused:
		return
	else:
		time_in_level += delta
	if time_in_level >= gas_start:
		var t: float = clampf((time_in_level - gas_start) / maxf(gas_time, 1.0), 0.0, 1.0)
		gas_radius = lerpf(gas_max, TILE * 2.4, t)
	if respawn:
		_respawns(delta)
		if time_in_level >= time_limit and not overtime:
			_time_up()
			if finished or failed:
				return
	for f: BrawlFighter in fighters:
		if not f.alive:
			continue
		if f.ai.has("turret"):
			_turret_think(f, delta)
			_tick(f, delta)
			continue
		if f.is_player and autopilot:
			_think(f, delta)
			aim_target = best_target(f)
		elif f.is_player:
			_control_player(delta)
		elif f.remote:
			_net_follow(f, delta)
			_tick(f, delta)
			continue
		else:
			_think(f, delta)
		_move(f, delta)
		_tick(f, delta)
	if not online.is_empty():
		_net_step(delta)
	_move_bullets(delta)
	_flush_damage(delta)
	_pickups(delta)
	if mode == "ball" and not ball.is_empty():
		_ball_step(delta)
	if finished or failed:
		return
	if Input.is_action_just_pressed("shoot"):
		attack()
	if Input.is_action_just_pressed("super"):
		use_super()
	_camera.position = player.position
	if (coop or respawn) and not player.alive:
		for o: BrawlFighter in fighters:
			if o.alive and o.team == 0 and not o.ai.has("turret"):
				_camera.position = o.position
				break
	_fx.queue_redraw()
	_gas.queue_redraw()
	_bushes.modulate.a = 0.5 if player.in_bush else 1.0
	_update_hud()


func _control_player(_delta: float) -> void:
	var v: Vector2 = move_input
	if v == Vector2.ZERO and stick != null:
		v = stick.vector
	if v == Vector2.ZERO:
		v = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	player.velocity = v.limit_length(1.0) * player.speed
	aim_target = best_target(player)


func _move(f: BrawlFighter, delta: float) -> void:
	var step: Vector2 = f.velocity * delta
	var r: float = BrawlFighter.RADIUS * 0.8
	var p: Vector2 = f.position
	if free_at(p + Vector2(step.x, 0.0), r):
		p.x += step.x
	if free_at(p + Vector2(0.0, step.y), r):
		p.y += step.y
	f.position = p
	var moving: bool = step.length() > 0.5
	if moving:
		f.facing = f.velocity.normalized()
	f.animate(moving)
	var bushed: bool = in_bush(p)
	if bushed != f.in_bush:
		f.in_bush = bushed


func _tick(f: BrawlFighter, delta: float) -> void:
	if f.remote:
		## Su vida y su gas los lleva su dispositivo: aqui solo si se ve o no.
		var hid: bool = not visible_to(player, f)
		f.modulate.a = 0.0 if hid else 1.0
		f.queue_redraw()
		return
	f.ammo = minf(float(BrawlFighter.AMMO_MAX), f.ammo + delta / f.reload_time)
	f.reveal = maxf(f.reveal - delta, 0.0)
	f.calm += delta
	if f.ai.has("shield"):
		f.ai["shield"] = float(f.ai["shield"]) - delta
		if float(f.ai["shield"]) <= 0.0:
			f.ai.erase("shield")
	if f.ai.has("turret"):
		f.queue_redraw()
		return
	if f.calm > 3.0 and f.hp < f.max_hp:
		f.hp = minf(f.max_hp, f.hp + f.max_hp * REGEN * delta)
	if f.position.distance_to(gas_center) > gas_radius:
		f.hp -= GAS_DPS * delta
		f.calm = 0.0
		if f.hp <= 0.0:
			f.hp = 0.0
			f.alive = false
			_on_death(f, null)
			return
	## Oculto en el arbusto: el jugador se ve medio transparente; los rivales, nada (si estas lejos).
	var hidden: bool = not f.is_player and not visible_to(player, f)
	f.modulate.a = 0.5 if f.in_bush and f.is_player else (0.0 if hidden else 1.0)
	f.queue_redraw()


func visible_to(viewer: BrawlFighter, target: BrawlFighter) -> bool:
	if viewer == null or not target.in_bush or target.reveal > 0.0:
		return true
	return viewer.position.distance_to(target.position) < BUSH_SEE


func rivals_left() -> int:
	var n: int = 0
	for f: BrawlFighter in fighters:
		if f.alive and not f.is_player and (not teams or f.team == 1) and not f.ai.has("turret"):
			n += 1
	return n


## Enemigos: en el cooperativo y los modos de equipo, solo los del otro equipo (sin fuego amigo).
func foes(a: BrawlFighter, b: BrawlFighter) -> bool:
	return a != b and (not teams or a.team != b.team)


## Alcance de los disparos de cada uno (segun su forma de disparar).
func range_of(f: BrawlFighter) -> float:
	var atk: Dictionary = f.ai.get("atk", {})
	return SHOT_RANGE * float(atk.get("range", 1.0))


func humans_alive() -> int:
	var n: int = 0
	for f: BrawlFighter in fighters:
		if f.alive and f.team == 0:
			n += 1
	return n


func best_target(f: BrawlFighter) -> BrawlFighter:
	var best: BrawlFighter = null
	var best_d: float = range_of(f) * 1.05
	for o: BrawlFighter in fighters:
		if not foes(f, o) or not o.alive or not visible_to(f, o):
			continue
		var d: float = o.position.distance_to(f.position)
		## Las torretas solo si no hay nadie mas cerca (primero los que se mueven).
		if o.ai.has("turret"):
			d += 160.0
		if d < best_d and line_clear(f.position, o.position):
			best_d = d
			best = o
	return best


## Caja a tiro (para abrirla si no hay nadie cerca).
func box_in_range(f: BrawlFighter) -> Vector2i:
	var best: Vector2i = Vector2i(-1, -1)
	var best_d: float = SHOT_RANGE * 0.95
	for c: Vector2i in boxes.keys():
		var p: Vector2 = center_of(c)
		var d: float = p.distance_to(f.position)
		if d < best_d and _line_to_box(f.position, c):
			best_d = d
			best = c
	return best


func _line_to_box(a: Vector2, c: Vector2i) -> bool:
	var b: Vector2 = center_of(c)
	var d: float = a.distance_to(b)
	var steps: int = maxi(1, int(d / 24.0))
	for i: int in range(1, steps):
		var cc: Vector2i = cell_of(a.lerp(b, float(i) / float(steps)))
		if cc == c:
			return true
		if blocked(cc):
			return false
	return true


# ------------------------------------------------------------------ disparos

func attack() -> bool:
	if finished or failed or player == null or not player.alive:
		return false
	var dir: Vector2 = player.facing
	if mode == "ball" and ball.get("holder") == player:
		return kick(player)
	if aim_target != null and aim_target.alive:
		## Apunta a donde esta (sin adelantarse): moviendose de lado se pueden esquivar las balas.
		dir = (aim_target.position - player.position).normalized()
	else:
		var bc: Vector2i = box_in_range(player)
		if bc.x >= 0:
			dir = (center_of(bc) - player.position).normalized()
	return shoot(player, dir)


func use_super() -> bool:
	if finished or failed or player == null or not player.alive:
		return false
	return fire_super(player)


## Disparo apuntado a mano (arrastrar el boton y soltar).
func attack_toward(dir: Vector2) -> bool:
	if finished or failed or player == null or not player.alive or dir == Vector2.ZERO:
		return false
	if mode == "ball" and ball.get("holder") == player:
		player.facing = dir
		return kick(player, dir)
	return shoot(player, dir.normalized())


## Super apuntado a mano: la bomba cae a donde apuntas y la embestida va hacia ahi.
func super_toward(dir: Vector2) -> bool:
	if finished or failed or player == null or not player.alive or dir == Vector2.ZERO:
		return false
	player.ai["super_dir"] = dir.normalized()
	var ok: bool = fire_super(player)
	player.ai.erase("super_dir")
	return ok


func _lead(f: BrawlFighter, t: BrawlFighter) -> Vector2:
	var to: Vector2 = t.position - f.position
	var time: float = to.length() / SHOT_SPEED
	return (to + t.velocity * time * 0.8).normalized()


func shoot(f: BrawlFighter, dir: Vector2) -> bool:
	if f.ammo < 1.0 or dir == Vector2.ZERO:
		return false
	f.ammo -= 1.0
	_spawn_shot(f, f.position, dir)
	if net != null and not f.remote:
		net.send("sh", {"id": f.net_id, "o": [f.position.x, f.position.y], "d": [dir.x, dir.y], "s": false})
	if f.is_player or f.position.distance_to(player.position) < 700.0:
		Audio.play("shoot", 0.1, -6.0 if f.is_player else -12.0)
	if f.rig != null:
		Juice.squash(f.rig, Vector2(1.12, 0.9), 0.1)
	return true


## Balas de una rafaga (propia o de otro jugador en directo).
func _spawn_shot(f: BrawlFighter, origin: Vector2, dir: Vector2) -> void:
	f.reveal = 1.0
	f.facing = dir
	var col: Color = Kit.color("accent", Color("#ffb627")) if f.is_player else (Color("#4fc3ff") if teams and f.team == 0 else Color("#ff6b5b"))
	var atk: Dictionary = f.ai.get("atk", {})
	var n: int = int(atk.get("n", 3))
	var spread: float = float(atk.get("spread", 0.07))
	var w: float = 14.0 if n == 1 else 9.0
	for k: int in n:
		var d: Vector2 = dir.rotated((float(k) - float(n - 1) * 0.5) * spread)
		bullets.append({"pos": origin + d * 30.0 + Vector2(0, -26), "vel": d * SHOT_SPEED * float(atk.get("speed", 1.0)), "owner": f,
			"dmg": f.damage * float(atk.get("dmg", 1.0)), "left": range_of(f), "col": col, "w": w})


func fire_super(f: BrawlFighter) -> bool:
	if f.super_charge < 1.0:
		return false
	f.super_charge = 0.0
	_spawn_super(f, f.position)
	if net != null and not f.remote:
		net.send("sh", {"id": f.net_id, "o": [f.position.x, f.position.y], "d": [0.0, 0.0], "s": true})
	return true


func _spawn_super(f: BrawlFighter, origin: Vector2) -> void:
	f.reveal = 1.0
	var col: Color = Color("#ffe066") if f.is_player else Color("#ff9a3c")
	match str(f.ai.get("super", "ola")):
		"escudo":
			f.ai["shield"] = 3.0
			Juice.ring(_fx, origin + Vector2(0, -30), Color("#7fe7ff"), 90.0, 0.35)
			Audio.play("powerup")
			QA.log_event("super", {"player": f.is_player, "kind": "escudo"})
			return
		"cura":
			for o: BrawlFighter in fighters:
				if o.alive and not o.ai.has("turret") and (o == f or (teams and o.team == f.team)) and o.position.distance_to(origin) < 330.0:
					o.hp = minf(o.max_hp, o.hp + o.max_hp * 0.4)
					Juice.sparkle(_fx, o.position + Vector2(0, -40), Color("#7dff9a"), 10, 200.0)
					o.queue_redraw()
			Juice.ring(_fx, origin + Vector2(0, -26), Color("#7dff9a"), 330.0, 0.4)
			Audio.play("powerup")
			QA.log_event("super", {"player": f.is_player, "kind": "cura"})
			return
		"dash":
			_dash(f, col)
			return
		"bomba":
			var t: BrawlFighter = best_target(f)
			var to: Vector2 = t.position if t != null else origin + f.facing * 300.0
			if f.ai.has("super_dir"):
				to = origin + (f.ai["super_dir"] as Vector2) * SUPER_RANGE
			if to.distance_to(origin) > SUPER_RANGE * 1.2:
				to = origin + (to - origin).normalized() * SUPER_RANGE * 1.2
			var dist: float = maxf(origin.distance_to(to), 1.0)
			bullets.append({"pos": origin + Vector2(0, -26), "vel": (to - origin).normalized() * 700.0, "owner": f, "dmg": f.damage * 2.6,
				"left": dist, "col": Color("#ff7a2f"), "w": 18.0, "bomb": true})
			Audio.play("shoot", 0.1, -4.0)
			QA.log_event("super", {"player": f.is_player, "kind": "bomba"})
			return
	for k: int in 16:
		var d: Vector2 = Vector2.RIGHT.rotated(TAU * float(k) / 16.0)
		bullets.append({"pos": origin + Vector2(0, -26), "vel": d * SHOT_SPEED * 0.85, "owner": f, "dmg": f.damage * 1.5, "left": SUPER_RANGE, "col": col, "w": 13.0})
	Juice.ring(_fx, origin + Vector2(0, -26), col, SUPER_RANGE * 0.6, 0.35)
	Juice.shake(0.3)
	Audio.play("powerup")
	QA.log_event("super", {"player": f.is_player})


func _move_bullets(delta: float) -> void:
	var i: int = bullets.size() - 1
	while i >= 0:
		var b: Dictionary = bullets[i]
		var step: Vector2 = (b["vel"] as Vector2) * delta
		var p: Vector2 = (b["pos"] as Vector2) + step
		b["pos"] = p
		b["left"] = float(b["left"]) - step.length()
		var dead: bool = float(b["left"]) <= 0.0
		## La bomba va por el aire (salta muros) y explota al llegar.
		if b.has("bomb"):
			if dead:
				_explode(p + Vector2(0, 26), float(b["dmg"]), b["owner"] as BrawlFighter)
				bullets.remove_at(i)
			i -= 1
			continue
		var feet: Vector2 = p + Vector2(0, 26)
		var cell: Vector2i = cell_of(feet)
		if not dead and boxes.has(cell):
			dead = true
			_hit_box(cell, float(b["dmg"]), b["owner"] as BrawlFighter)
		elif not dead and blocked(cell):
			dead = true
			Juice.burst(_fx, p, Color(1, 1, 1, 0.8), 4, 120.0)
		if not dead:
			for f: BrawlFighter in fighters:
				if not f.alive or f == b["owner"]:
					continue
				if teams and is_instance_valid(b["owner"]) and (b["owner"] as BrawlFighter).team == f.team:
					continue
				if f.position.distance_to(feet) < BrawlFighter.RADIUS + 10.0:
					dead = true
					if f.remote:
						## Lo decide su dispositivo; aqui solo se ve el golpe (y carga el super del que dispara).
						var by: BrawlFighter = b["owner"] as BrawlFighter
						if by != null and is_instance_valid(by) and not by.remote:
							by.super_charge = minf(1.0, by.super_charge + 0.07)
						Juice.burst(_fx, f.position + Vector2(0, -30), b["col"] as Color, 5, 160.0)
					else:
						_hit_fighter(f, float(b["dmg"]), b["owner"] as BrawlFighter, b["col"] as Color)
					break
		if dead:
			bullets.remove_at(i)
		i -= 1


func _hit_fighter(f: BrawlFighter, dmg: float, by: BrawlFighter, col: Color) -> void:
	if f.ai.has("shield"):
		dmg *= 0.25
	var killed: bool = f.hit(dmg)
	## Quien lleva el balon lo suelta al recibir un golpe fuerte.
	if mode == "ball" and ball.get("holder") == f and dmg > f.max_hp * 0.12:
		_drop_ball(f)
	if by != null and is_instance_valid(by) and by.alive:
		by.super_charge = minf(1.0, by.super_charge + 0.07)
		by.calm = 0.0
	if f.sprite != null:
		Juice.flash(f.sprite, Color(3, 3, 3, 1), 0.07)
	if f.is_player or (by != null and is_instance_valid(by) and by.is_player):
		var acc: Dictionary = _dmg_acc.get(f, {"amount": 0.0, "t": 0.0})
		acc["amount"] = float(acc["amount"]) + dmg
		acc["t"] = 0.0
		_dmg_acc[f] = acc
	if f.is_player:
		Juice.shake(0.12)
		Juice.vibrate(20)
	Juice.burst(_fx, f.position + Vector2(0, -30), col, 5, 160.0)
	if killed:
		_on_death(f, by)


func _flush_damage(delta: float) -> void:
	for f: BrawlFighter in _dmg_acc.keys():
		var acc: Dictionary = _dmg_acc[f]
		acc["t"] = float(acc["t"]) + delta
		if float(acc["t"]) < 0.1:
			continue
		_dmg_acc.erase(f)
		if is_instance_valid(f):
			UI.float_text(_fx, f.position + Vector2(_rng.randf_range(-24, 24), -128), str(int(acc["amount"])),
				Color("#ff8a80") if f.is_player else Color.WHITE, 30)


func _hit_box(cell: Vector2i, dmg: float, by: BrawlFighter) -> void:
	boxes[cell] = float(boxes[cell]) - dmg
	var node: Node2D = _box_nodes.get(cell)
	if node != null:
		node.queue_redraw()
	if float(boxes[cell]) > 0.0:
		return
	boxes.erase(cell)
	_flow.clear()
	if node != null:
		node.queue_free()
	_box_nodes.erase(cell)
	var at: Vector2 = center_of(cell)
	Juice.burst(_fx, at, Color("#c98a3c"), 16, 300.0)
	cubes.append({"pos": at, "t": 0.0})
	Audio.play("stomp")
	if by != null and is_instance_valid(by) and by.is_player:
		Juice.shake(0.15)


func _on_death(f: BrawlFighter, by: BrawlFighter) -> void:
	f.alive = false
	f.visible = false
	if net != null and not f.remote:
		net.send("ko", {"id": f.net_id, "by": by.net_id if by != null and is_instance_valid(by) else ""})
	Juice.burst(_fx, f.position + Vector2(0, -30), Color("#ff6b5b") if not f.is_player else Color("#5fd35f"), 24, 380.0)
	Juice.shake(0.35)
	for k: int in 1 + f.power / 2:
		var off: Vector2 = Vector2.RIGHT.rotated(_rng.randf() * TAU) * _rng.randf_range(0.0, 50.0)
		var p: Vector2 = f.position + off
		if free_at(p, 10.0):
			cubes.append({"pos": p, "t": 0.0})
	if coop:
		_coop_death(f, by)
		return
	if mode == "ball" and ball.get("holder") == f:
		_drop_ball(f)
	if f.ai.has("turret"):
		_turret_down(f)
		return
	if respawn:
		f.ai["respawn"] = RESPAWN_TIME
		if by != null and is_instance_valid(by) and by.is_player:
			kills += 1
			UI.float_text(_fx, f.position + Vector2(0, -140), Kit.text("brawl_ko", "\u00a1Eliminado!"), Color("#ffe066"), 40)
		if f.is_player:
			UI.float_text(_fx, f.position + Vector2(0, -140), Kit.text("brawl_respawn", "Vuelves en 3 s"), UI.colors["peligro"], 34)
		Audio.play("hurt", 0.1, -6.0)
		return
	if mode == "survival":
		if f.is_player:
			_lose()
			return
		if f.team == 0:
			return
		if by != null and is_instance_valid(by) and by.is_player:
			kills += 1
			UI.float_text(_fx, f.position + Vector2(0, -140), Kit.text("brawl_ko", "\u00a1Eliminado!"), Color("#ffe066"), 40)
		Audio.play("hurt", 0.1, -6.0)
		if rivals_left() == 0:
			_survival_cleared()
		return
	if f.is_player:
		placed = rivals_left() + 1
		if OS.has_environment("ARENA_DEBUG"):
			var info: Array = []
			for o: BrawlFighter in fighters:
				if o.alive:
					info.append("%d/%d@%d" % [int(o.hp), int(o.max_hp), int(o.position.distance_to(f.position))])
			print("MUERTE t=%.1f gas=%s fuera=%s por=%s vivos=%s" % [time_in_level, int(gas_radius), f.position.distance_to(gas_center) > gas_radius, by.name if by != null else "gas", info])
		_lose()
		return
	if by != null and is_instance_valid(by) and by.is_player:
		kills += 1
		UI.float_text(_fx, f.position + Vector2(0, -140), Kit.text("brawl_ko", "\u00a1Eliminado!"), Color("#ffe066"), 40)
		Juice.hitstop(0.08)
	Audio.play("hurt", 0.1, -6.0)
	QA.log_event("rival_out", {"by_player": by != null and is_instance_valid(by) and by.is_player, "left": rivals_left()})
	if rivals_left() == 0:
		_win()


func _pickups(delta: float) -> void:
	var i: int = cubes.size() - 1
	while i >= 0:
		var c: Dictionary = cubes[i]
		c["t"] = float(c["t"]) + delta
		var taken: bool = false
		if float(c["t"]) > 0.4:
			for f: BrawlFighter in fighters:
				## Los rivales se hacen fuertes hasta +30 % (si no, el que gana una pelea se vuelve imparable).
				if f.alive and not f.ai.has("turret") and f.position.distance_to(c["pos"] as Vector2) < 56.0 and (f.is_player or f.power < 3):
					f.add_power()
					taken = true
					if f.is_player:
						coins += 1
						Audio.play("coin")
						UI.float_text(_fx, f.position + Vector2(0, -150), "+1", Color("#d59bff"), 32)
						Juice.sparkle(_fx, f.position + Vector2(0, -40), Color("#d59bff"), 8, 220.0)
					break
		if taken:
			cubes.remove_at(i)
		i -= 1


# ------------------------------------------------------------------ IA de los rivales

func _think(f: BrawlFighter, delta: float) -> void:
	var ai: Dictionary = f.ai
	ai["think"] = float(ai["think"]) - delta
	ai["flip"] = float(ai["flip"]) - delta
	if float(ai["flip"]) <= 0.0:
		ai["flip"] = _rng.randf_range(1.0, 2.2)
		ai["strafe"] = -float(ai["strafe"])
	var target: BrawlFighter = ai.get("target") as BrawlFighter if ai.get("target") != null and is_instance_valid(ai.get("target")) else null
	if float(ai["think"]) <= 0.0:
		ai["think"] = 0.25
		target = _pick_target(f)
		ai["target"] = target
		ai["goal"] = _pick_goal(f, target)
	if target != null and not target.alive:
		target = null
	var goal: Vector2 = ai["goal"]
	var to: Vector2 = next_step(f.position, goal) - f.position
	f.velocity = to.normalized() * f.speed if to.length() > 12.0 else Vector2.ZERO
	## Con el balon: chuta en cuanto ve la porteria a tiro.
	if mode == "ball" and ball.get("holder") == f:
		var gp: Vector2 = goal_center(1 - f.team)
		if f.position.distance_to(gp) < SHOT_RANGE * 0.9 and line_clear(f.position, gp):
			kick(f)
		return
	## Disparar: tarda "reaction" en apuntar y falla un poco ("aim"). En piloto automatico, el
	## jugador apunta como una persona que juega bien (algo mejor que los bots).
	var react: float = reaction * (0.6 if f.is_player else 1.0)
	var err: float = aim_error * (0.5 if f.is_player else 1.0)
	if target != null and visible_to(f, target):
		var d: float = f.position.distance_to(target.position)
		if d < range_of(f) * 0.92 and line_clear(f.position, target.position):
			ai["aim"] = float(ai["aim"]) + delta
			if f.super_charge >= 1.0 and _super_ready(f, target, d):
				fire_super(f)
			elif float(ai["aim"]) >= react and f.ammo >= 1.0:
				ai["aim"] = react * 0.35
				shoot(f, _lead(f, target).rotated(_rng.randf_range(-err, err)))
			return
	ai["aim"] = maxf(float(ai["aim"]) - delta, 0.0)
	## Sin nadie a tiro: abre cajas.
	if f.ammo >= 2.0:
		var bc: Vector2i = box_in_range(f)
		if bc.x >= 0 and f.position.distance_to(center_of(bc)) < SHOT_RANGE * 0.7:
			shoot(f, (center_of(bc) - f.position).normalized())


func _pick_target(f: BrawlFighter) -> BrawlFighter:
	var best: BrawlFighter = null
	## En el balon, a por quien lo lleve si es del otro equipo.
	if mode == "ball":
		var h: Variant = ball.get("holder")
		if h != null and is_instance_valid(h) and foes(f, h as BrawlFighter) and (h as BrawlFighter).alive:
			return h as BrawlFighter
	## Al principio se dedican a abrir cajas (como en los juegos de arena): solo pelean si alguien se acerca.
	var farming: bool = mode == "showdown" and time_in_level < FARM_TIME and (not boxes.is_empty() or not cubes.is_empty())
	var best_d: float = 420.0 if farming else 650.0
	## Torretas: pelean con quien se cruce, pero sin dejar de empujar hacia la torreta.
	if mode == "turrets":
		best_d = 460.0
	for o: BrawlFighter in fighters:
		if not foes(f, o) or not o.alive or not visible_to(f, o):
			continue
		var d: float = o.position.distance_to(f.position)
		## Nunca mas de dos a por el mismo (todos contra todos de verdad, sin encerronas).
		if not teams and _hunters(o, f) >= 2:
			d += 400.0
		if o.ai.has("turret"):
			d += 220.0
		if d < best_d:
			best_d = d
			best = o
	return best


func _hunters(target: BrawlFighter, except: BrawlFighter) -> int:
	var n: int = 0
	for o: BrawlFighter in fighters:
		if o != except and o.alive and not o.is_player and o.ai.get("target") == target:
			n += 1
	return n


func _pick_goal(f: BrawlFighter, target: BrawlFighter) -> Vector2:
	if mode == "ball":
		var g: Vector2 = _ball_goal(f, target)
		if g != Vector2.INF:
			return g
	elif mode == "turrets" and (target == null or target.ai.has("turret")):
		## Sin nadie cerca: a por la torreta rival (a su distancia de tiro).
		var tt: Variant = turrets[1 - f.team] if f.team >= 0 else null
		if tt != null and is_instance_valid(tt) and (tt as BrawlFighter).alive:
			var tp: Vector2 = (tt as BrawlFighter).position
			if f.position.distance_to(tp) > range_of(f) * 0.8 or not line_clear(f.position, tp):
				return tp
			return f.position + (tp - f.position).normalized().orthogonal() * 120.0 * float(f.ai["strafe"])
	## 1 - El gas manda: hacia el centro.
	if time_in_level >= gas_start and f.position.distance_to(gas_center) > gas_radius - TILE * 1.6:
		return gas_center
	## 2 - Con poca vida, se aleja y espera a curarse.
	if target != null and f.hp < f.max_hp * 0.3:
		var away: Vector2 = f.position + (f.position - target.position).normalized() * 260.0
		return away if free_at(away, 30.0) else f.position + (f.position - target.position).normalized().rotated(1.2) * 200.0
	## 3 - Con objetivo: a su distancia, de lado.
	if target != null:
		var d: float = f.position.distance_to(target.position)
		var dir: Vector2 = (target.position - f.position).normalized()
		if d > 430.0 or not line_clear(f.position, target.position):
			return target.position
		if d < 240.0:
			return f.position - dir * 160.0
		return f.position + dir.orthogonal() * 140.0 * float(f.ai["strafe"])
	## 4 - Supervivencia: las oleadas van a por tu equipo; tus aliados no se separan de ti.
	if mode == "survival" or respawn:
		if f.team == 1:
			var near: BrawlFighter = _nearest_foe(f, true)
			if near != null:
				return near.position
		elif not f.is_player and player != null and player.alive:
			return player.position + Vector2(140.0 * float(f.ai["strafe"]), 90.0)
	## 5 - Cubos sueltos, cajas o hacia el centro.
	var best: Vector2 = gas_center
	var best_d: float = 99999.0
	for c: Dictionary in cubes:
		var d: float = (c["pos"] as Vector2).distance_to(f.position)
		if d < best_d:
			best_d = d
			best = c["pos"]
	if best_d < 99999.0:
		return best
	for c: Vector2i in boxes.keys():
		var d: float = center_of(c).distance_to(f.position)
		if d < best_d:
			best_d = d
			best = center_of(c) + (f.position - center_of(c)).normalized() * 260.0
	return best


# ------------------------------------------------------------------ cooperativo

## Oleada n: 2 + n bots del equipo contrario, mas fuertes cada vez. Los mueve el anfitrion;
## los demas la crean igual (mismos ids) cuando ven caer el ultimo bot de la anterior.
func spawn_wave(n: int) -> void:
	wave = n
	var spots: Array[Vector2] = _spawns.duplicate()
	if spots.is_empty():
		spots.append(gas_center)
	for k: int in 2 + n:
		var at: Vector2 = spots[k % spots.size()] + Vector2(float(k / spots.size()) * 60.0, 0.0)
		var f: BrawlFighter = _make_fighter(false, at, 10 + k)
		f.team = 1
		f.max_hp = rival_hp * (0.7 + 0.2 * float(n))
		f.hp = f.max_hp
		f.net_id = "w%d_%d" % [n, k]
		f.fighter_name = Kit.text("bot", "Bot")
		f.remote = not host
		f.net_pos = at
		f.last_seen = time_in_level
		by_id[f.net_id] = f
	if player != null:
		UI.float_text(_fx, player.position + Vector2(0, -170), Kit.text("coop_wave", "Oleada {n} de {max}").format({"n": n, "max": COOP_WAVES}), Color("#ffe066"), 42)
	QA.log_event("coop_wave", {"wave": n})


func _coop_death(f: BrawlFighter, by: BrawlFighter) -> void:
	if f.team == 1:
		if by != null and is_instance_valid(by) and by.is_player:
			kills += 1
			UI.float_text(_fx, f.position + Vector2(0, -140), Kit.text("brawl_ko", "\u00a1Eliminado!"), Color("#ffe066"), 40)
		if rivals_left() == 0:
			if wave >= COOP_WAVES:
				_net_end(1)
			else:
				spawn_wave(wave + 1)
		return
	## Cae un jugador: si queda alguien del equipo, se sigue mirando; si no, derrota.
	if f.is_player:
		UI.float_text(_fx, f.position + Vector2(0, -140), Kit.text("coop_down", "\u00a1Te han eliminado! Anima a tu equipo"), UI.colors["peligro"], 34)
	if humans_alive() == 0:
		_net_end(2)


## Guia de apuntado: por donde iran las balas (o el balon) y donde caera el super.
func _draw_aim() -> void:
	if player == null or not player.alive:
		return
	var o: Vector2 = player.position + Vector2(0, -26)
	if aim_attack != Vector2.ZERO:
		player.facing = aim_attack
		var holding: bool = mode == "ball" and ball.get("holder") == player
		var atk: Dictionary = player.ai.get("atk", {})
		var n: int = 1 if holding else int(atk.get("n", 3))
		var spread: float = 0.0 if holding else float(atk.get("spread", 0.07))
		var reach: float = SHOT_RANGE * 0.9 if holding else range_of(player)
		var col: Color = Color(1, 1, 1, 0.32) if player.ammo >= 1.0 or holding else Color(1, 0.4, 0.4, 0.3)
		if n == 1:
			var end: Vector2 = o + aim_attack * reach
			_fx.draw_line(o, end, col, 14.0, true)
			_fx.draw_circle(end, 9.0, col)
		else:
			var half: float = spread * float(n - 1) * 0.5 + 0.035
			var pts: PackedVector2Array = PackedVector2Array([o])
			for k: int in 13:
				pts.append(o + aim_attack.rotated(lerpf(-half, half, float(k) / 12.0)) * reach)
			_fx.draw_colored_polygon(pts, col)
	if aim_super != Vector2.ZERO and player.super_charge >= 1.0:
		var gold: Color = Color(1.0, 0.85, 0.25, 0.4)
		match str(player.ai.get("super", "ola")):
			"bomba":
				var at: Vector2 = player.position + aim_super * SUPER_RANGE
				_fx.draw_dashed_line(o, at + Vector2(0, -26), gold, 5.0, 16.0)
				_fx.draw_circle(at, 165.0, Color(1.0, 0.5, 0.2, 0.18))
				_fx.draw_arc(at, 165.0, 0.0, TAU, 40, Color(1.0, 0.6, 0.2, 0.7), 4.0, true)
			"dash":
				_fx.draw_line(o, o + aim_super * 320.0, gold, 40.0, true)
			_:
				var rad: float = 330.0 if str(player.ai.get("super", "")) == "cura" else SUPER_RANGE
				_fx.draw_arc(player.position, rad, 0.0, TAU, 48, gold, 5.0, true)


# ------------------------------------------------------------------ modos

func _nearest_foe(f: BrawlFighter, movers_only: bool) -> BrawlFighter:
	var best: BrawlFighter = null
	var best_d: float = 1e9
	for o: BrawlFighter in fighters:
		if not o.alive or not foes(f, o) or (movers_only and o.ai.has("turret")):
			continue
		var d: float = o.position.distance_to(f.position)
		if d < best_d:
			best_d = d
			best = o
	return best


## Cuando conviene usar el super (la IA y el piloto automatico).
func _super_ready(f: BrawlFighter, target: BrawlFighter, d: float) -> bool:
	match str(f.ai.get("super", "ola")):
		"escudo":
			return f.hp < f.max_hp * 0.65 and d < 420.0
		"cura":
			return f.hp < f.max_hp * 0.55
		"dash":
			return d < 330.0 and not target.ai.has("turret")
		"bomba":
			return d < SUPER_RANGE * 1.15
	return d < SUPER_RANGE * 0.85


## Embestida: sale disparado hacia el rival (sin atravesar muros) y golpea a todos al llegar.
func _dash(f: BrawlFighter, col: Color) -> void:
	var t: BrawlFighter = best_target(f)
	var dir: Vector2 = (t.position - f.position).normalized() if t != null else f.facing
	if f.ai.has("super_dir"):
		dir = f.ai["super_dir"]
	var p: Vector2 = f.position
	var moved: float = 0.0
	while moved < 320.0:
		var np: Vector2 = p + dir * 12.0
		if not free_at(np, BrawlFighter.RADIUS * 0.8):
			break
		p = np
		moved += 12.0
		if int(moved) % 48 == 0:
			Juice.burst(_fx, p + Vector2(0, -30), Color(col, 0.6), 2, 60.0)
	f.position = p
	f.facing = dir
	for o: BrawlFighter in fighters.duplicate():
		if o.alive and foes(f, o) and o.position.distance_to(p) < 140.0:
			_hit_fighter(o, f.damage * 2.2, f, col)
			var push: Vector2 = o.position + dir * 70.0
			if o.alive and not o.ai.has("turret") and free_at(push, BrawlFighter.RADIUS * 0.8):
				o.position = push
	Juice.ring(_fx, p + Vector2(0, -26), col, 140.0, 0.3)
	Juice.shake(0.3)
	Audio.play("stomp")
	QA.log_event("super", {"player": f.is_player, "kind": "dash"})


## Explosion de la bomba: dana a los rivales y rompe cajas alrededor.
func _explode(at: Vector2, dmg: float, by: BrawlFighter) -> void:
	var owner_ok: bool = by != null and is_instance_valid(by)
	Juice.ring(_fx, at + Vector2(0, -26), Color("#ff7a2f"), 170.0, 0.35)
	Juice.burst(_fx, at + Vector2(0, -26), Color("#ffb347"), 22, 360.0)
	Juice.shake(0.35)
	Audio.play("stomp")
	for o: BrawlFighter in fighters.duplicate():
		if o.alive and o.position.distance_to(at) < 165.0 and (not owner_ok or foes(by, o)):
			_hit_fighter(o, dmg, by if owner_ok else null, Color("#ff7a2f"))
	for c: Vector2i in boxes.keys():
		if center_of(c).distance_to(at) < 150.0:
			_hit_box(c, dmg, by if owner_ok else null)
	QA.log_event("super", {"player": owner_ok and by.is_player, "kind": "bomba"})


## Supervivencia: oleada n (mas rivales y mas fuertes cada vez) desde las salidas "R".
func spawn_survival(n: int) -> void:
	wave = n
	_wave_pending = false
	var spots: Array[Vector2] = _spawns.duplicate()
	if spots.is_empty():
		spots.append(gas_center)
	var count: int = clampi(1 + n, 2, 6)
	for k: int in count:
		var at: Vector2 = spots[k % spots.size()] + Vector2(float(k / spots.size()) * 60.0, 0.0)
		var f: BrawlFighter = _make_fighter(false, at, k + n)
		f.name = "Wave%d_%d" % [n, k]
		f.team = 1
		f.max_hp *= 0.7 + 0.12 * float(n)
		f.hp = f.max_hp
		f.remember_base()
		f.ai["think"] = 0.5 + 0.1 * float(k)
	if player != null and n > 1:
		UI.float_text(_fx, player.position + Vector2(0, -170), Kit.text("coop_wave", "Oleada {n} de {max}").format({"n": n, "max": waves}), Color("#ffe066"), 42)
		Audio.play("powerup")
	QA.log_event("survival_wave", {"wave": n})


func _survival_cleared() -> void:
	if _wave_pending or finished or failed:
		return
	if wave >= waves:
		_win()
		return
	_wave_pending = true
	spawn_survival.call_deferred(wave + 1)


## Equipos: los eliminados vuelven a su salida a los 3 s, enteros y sin cubos.
func _respawns(delta: float) -> void:
	for f: BrawlFighter in fighters:
		if f.alive or not f.ai.has("respawn"):
			continue
		f.ai["respawn"] = float(f.ai["respawn"]) - delta
		if float(f.ai["respawn"]) > 0.0:
			continue
		f.ai.erase("respawn")
		f.position = f.ai.get("home", _start)
		f.power = 0
		f.max_hp = float(f.ai.get("base_hp", f.max_hp))
		f.damage = float(f.ai.get("base_dmg", f.damage))
		f.hp = f.max_hp
		f.ammo = float(BrawlFighter.AMMO_MAX)
		f.alive = true
		f.visible = true
		f.velocity = Vector2.ZERO
		Juice.sparkle(_fx, f.position + Vector2(0, -40), f.bar_color, 10, 200.0)


func _time_up() -> void:
	var a: float = 0.0
	var b: float = 0.0
	if mode == "ball":
		a = float(goals_score[0])
		b = float(goals_score[1])
	elif mode == "turrets":
		for t: int in 2:
			var tt: Variant = turrets[t]
			var v: float = (tt as BrawlFighter).hp / (tt as BrawlFighter).max_hp if tt != null and is_instance_valid(tt) else 0.0
			if t == 0:
				a = v
			else:
				b = v
	if absf(a - b) < 0.001:
		overtime = true
		UI.float_text(_fx, player.position + Vector2(0, -170), Kit.text("brawl_overtime", "\u00a1Pr\u00f3rroga! El siguiente golpe gana"), Color("#ffe066"), 40)
		QA.log_event("overtime", {"mode": mode})
		return
	if a > b:
		_win()
	else:
		_lose()


func _mode_hud() -> void:
	match mode:
		"survival":
			_left_label.text = str(rivals_left())
			_gas_label.text = Kit.text("coop_wave", "Oleada {n} de {max}").format({"n": wave, "max": waves})
			_gas_label.add_theme_color_override("font_color", Color("#ffe066"))
			return
		"ball":
			_left_label.text = "%d - %d" % [goals_score[0], goals_score[1]]
		"turrets":
			var pc: Array[int] = [0, 0]
			for t: int in 2:
				var tt: Variant = turrets[t]
				if tt != null and is_instance_valid(tt):
					pc[t] = int(ceil(100.0 * (tt as BrawlFighter).hp / (tt as BrawlFighter).max_hp))
			_left_label.text = "%d%% - %d%%" % [pc[0], pc[1]]
	if overtime:
		_gas_label.text = Kit.text("brawl_overtime_short", "\u00a1Pr\u00f3rroga!")
		_gas_label.add_theme_color_override("font_color", Color("#ff8a5c"))
	else:
		var t: int = int(ceil(maxf(time_limit - time_in_level, 0.0)))
		_gas_label.text = "%d:%02d" % [t / 60, t % 60]
		_gas_label.add_theme_color_override("font_color", UI.colors["texto"] if t > 20 else Color("#ff8a5c"))
	if player != null and _pad_attack != null:
		var want: String = Kit.text("brawl_kick", "\u00a1Chuta!") if mode == "ball" and ball.get("holder") == player else Kit.text("brawl_attack", "\u00a1Fuego!")
		if _pad_attack.label != want:
			_pad_attack.label = want
			_pad_attack.queue_redraw()


# --- torretas

func _make_turret(t: int) -> void:
	var at: Vector2 = _turret_at[t]
	if at == Vector2.ZERO:
		at = _start + Vector2(0.0, -TILE) if t == 0 else (_spawns[0] + Vector2(0.0, TILE) if not _spawns.is_empty() else gas_center)
	var f: BrawlFighter = BrawlFighter.new()
	f.name = "Turret%d" % t
	f.position = at
	f.team = t
	f.max_hp = TURRET_HP
	f.damage = PLAYER_DMG * 0.9
	f.speed = 0.0
	f.reload_time = 0.9
	f.bar_color = Color("#4fc3ff") if t == 0 else Color("#ff5a4f")
	f.setup({}, Color("#8fa3c0") if t == 0 else Color("#c08f8f"), 0.0)
	if f.body != null:
		f.body.polygon = LevelBuilder._circle(46.0, 8)
		f.body.position = Vector2(0.0, -34.0)
		f.body.color = Color("#5d6b82") if t == 0 else Color("#82625d")
		var ring: Polygon2D = Polygon2D.new()
		ring.color = f.body.color.lightened(0.25)
		ring.polygon = LevelBuilder._circle(36.0, 8)
		ring.position = Vector2(0.0, -40.0)
		f.rig.add_child(ring)
		## Canon que gira hacia a quien apunta.
		var barrel: Polygon2D = Polygon2D.new()
		barrel.name = "Barrel"
		barrel.color = Color("#2b2d42")
		barrel.polygon = PackedVector2Array([Vector2(0, -9), Vector2(54, -7), Vector2(54, 7), Vector2(0, 9)])
		barrel.position = Vector2(0.0, -58.0)
		barrel.rotation = PI * 0.5 if t == 0 else -PI * 0.5
		f.rig.add_child(barrel)
		var top: Polygon2D = Polygon2D.new()
		top.color = f.bar_color
		top.polygon = LevelBuilder._circle(24.0, 10)
		top.position = Vector2(0.0, -58.0)
		f.rig.add_child(top)
		var shine: Polygon2D = Polygon2D.new()
		shine.color = Color(1, 1, 1, 0.35)
		shine.polygon = LevelBuilder._circle(8.0, 8)
		shine.position = Vector2(-8.0, -66.0)
		f.rig.add_child(shine)
	f.ai = {"turret": true, "atk": {"n": 1, "spread": 0.0, "range": TURRET_RANGE / SHOT_RANGE, "speed": 1.0, "dmg": 1.0},
		"cool": 1.0, "think": 0.0, "aim": 0.0, "strafe": 1.0, "flip": 1.0, "goal": at, "home": at}
	f.hp = f.max_hp
	f.remember_base()
	f.facing = Vector2.DOWN if t == 0 else Vector2.UP
	_actors.add_child(f)
	fighters.append(f)
	turrets[t] = f


func _turret_think(f: BrawlFighter, delta: float) -> void:
	f.velocity = Vector2.ZERO
	f.ai["cool"] = float(f.ai["cool"]) - delta
	if float(f.ai["cool"]) > 0.0:
		return
	var target: BrawlFighter = null
	var best_d: float = TURRET_RANGE
	for o: BrawlFighter in fighters:
		if not o.alive or not foes(f, o) or o.ai.has("turret") or not visible_to(f, o):
			continue
		var d: float = o.position.distance_to(f.position)
		if d < best_d and line_clear(f.position, o.position):
			best_d = d
			target = o
	if target == null:
		return
	f.ai["cool"] = 0.85
	f.ammo = float(BrawlFighter.AMMO_MAX)
	var barrel: Node2D = f.rig.get_node_or_null("Barrel") as Node2D if f.rig != null else null
	if barrel != null:
		barrel.rotation = (target.position - f.position).angle()
	shoot(f, _lead(f, target).rotated(_rng.randf_range(-0.05, 0.05)))


func _turret_down(f: BrawlFighter) -> void:
	Juice.burst(_fx, f.position + Vector2(0, -40), Color("#ffb347"), 40, 460.0)
	Juice.ring(_fx, f.position + Vector2(0, -40), Color("#ff7a2f"), 220.0, 0.45)
	Juice.shake(0.5)
	Audio.play("stomp")
	QA.log_event("turret_down", {"team": f.team})
	if f.team == 1:
		_win()
	else:
		_lose()


# --- balon

func goal_center(t: int) -> Vector2:
	var cells: Dictionary = goal_cells[t]
	if cells.is_empty():
		var w: Vector2 = Vector2(_size) * TILE
		return Vector2(w.x * 0.5, w.y - TILE * 0.5) if t == 0 else Vector2(w.x * 0.5, TILE * 0.5)
	var sum: Vector2 = Vector2.ZERO
	for c: Vector2i in cells.keys():
		sum += center_of(c)
	return sum / float(cells.size())


func _closest_to_ball(team: int) -> BrawlFighter:
	var best: BrawlFighter = null
	var best_d: float = 1e9
	var bp: Vector2 = ball["pos"]
	for f: BrawlFighter in fighters:
		if not f.alive or f.team != team or f.ai.has("turret") or (f.is_player and not autopilot):
			continue
		var d: float = f.position.distance_to(bp)
		if d < best_d:
			best_d = d
			best = f
	return best


## Meta de la IA en el balon (Vector2.INF = la normal: pelear con su objetivo).
func _ball_goal(f: BrawlFighter, target: BrawlFighter) -> Vector2:
	var h: Variant = ball.get("holder")
	var holder: BrawlFighter = h as BrawlFighter if h != null and is_instance_valid(h) else null
	if holder == f:
		return goal_center(1 - f.team)
	if holder == null:
		var bp: Vector2 = ball["pos"]
		if _closest_to_ball(f.team) == f or f.position.distance_to(bp) < 260.0:
			return bp
		if target != null:
			return Vector2.INF
		return bp.lerp(goal_center(f.team), 0.45)
	if foes(f, holder):
		return Vector2.INF
	## Un companero lo lleva: le abre camino por delante.
	if target != null and f.position.distance_to(target.position) < 420.0:
		return Vector2.INF
	return holder.position + (goal_center(1 - f.team) - holder.position).normalized() * 220.0


func kick(f: BrawlFighter, aimed: Vector2 = Vector2.ZERO) -> bool:
	if ball.get("holder") != f:
		return false
	var gp: Vector2 = goal_center(1 - f.team)
	var dir: Vector2 = f.facing
	if aimed != Vector2.ZERO:
		dir = aimed.normalized()
	elif f.position.distance_to(gp) < SHOT_RANGE * 1.1 or not f.is_player:
		dir = (gp - f.position).normalized().rotated(_rng.randf_range(-0.06, 0.06))
	ball["holder"] = null
	ball["kicker"] = f
	ball["cool"] = 0.4
	ball["pos"] = f.position + dir * 44.0
	ball["vel"] = dir * 1250.0
	Audio.play("jump", 0.1)
	if f.rig != null:
		Juice.squash(f.rig, Vector2(1.15, 0.88), 0.1)
	QA.log_event("kick", {"player": f.is_player, "team": f.team})
	return true


func _drop_ball(f: BrawlFighter) -> void:
	ball["holder"] = null
	ball["kicker"] = f
	ball["cool"] = 0.5
	ball["vel"] = Vector2.RIGHT.rotated(_rng.randf() * TAU) * 260.0
	ball["pos"] = f.position


func _ball_step(delta: float) -> void:
	ball["cool"] = float(ball.get("cool", 0.0)) - delta
	var h: Variant = ball.get("holder")
	if h != null:
		var holder: BrawlFighter = h as BrawlFighter
		if not is_instance_valid(holder) or not holder.alive:
			ball["holder"] = null
		else:
			ball["pos"] = holder.position + holder.facing * 34.0
			_check_goal()
			return
	var v: Vector2 = ball["vel"]
	var p: Vector2 = ball["pos"]
	var nx: Vector2 = p + Vector2(v.x * delta, 0.0)
	if blocked(cell_of(nx)) or boxes.has(cell_of(nx)):
		v.x = -v.x * 0.7
	else:
		p = nx
	var ny: Vector2 = p + Vector2(0.0, v.y * delta)
	if blocked(cell_of(ny)) or boxes.has(cell_of(ny)):
		v.y = -v.y * 0.7
	else:
		p = ny
	v *= pow(0.35, delta)
	if v.length() < 8.0:
		v = Vector2.ZERO
	ball["vel"] = v
	ball["pos"] = p
	if _check_goal():
		return
	## Lo coge quien lo toque (el que lo acaba de chutar espera un momento).
	for f: BrawlFighter in fighters:
		if not f.alive or f.ai.has("turret"):
			continue
		if f == ball.get("kicker") and float(ball["cool"]) > 0.0:
			continue
		if f.position.distance_to(p) < BrawlFighter.RADIUS + BALL_R + 6.0:
			ball["holder"] = f
			ball["vel"] = Vector2.ZERO
			if f.is_player:
				Audio.play("coin", 0.1, -4.0)
			break


func _check_goal() -> bool:
	var c: Vector2i = cell_of(ball["pos"] as Vector2)
	for t: int in 2:
		if goal_cells[t].has(c):
			_goal_scored(1 - t)
			return true
	return false


func _goal_scored(team: int) -> void:
	goals_score[team] += 1
	var bp: Vector2 = ball["pos"]
	Juice.burst(_fx, bp, Color("#ffe066"), 36, 420.0)
	Juice.shake(0.4)
	Audio.play("win" if team == 0 else "hurt")
	UI.float_text(_fx, player.position + Vector2(0, -170), Kit.text("brawl_goal", "\u00a1GOL!") if team == 0 else Kit.text("brawl_goal_them", "\u00a1Gol de ellos!"),
		Color("#ffe066") if team == 0 else UI.colors["peligro"], 52)
	QA.log_event("goal", {"team": team, "score": goals_score.duplicate()})
	if goals_score[team] >= BALL_GOALS or overtime:
		if team == 0:
			_win()
		else:
			_lose()
		return
	## Saque: todos a su salida y el balon al centro.
	for f: BrawlFighter in fighters:
		if f.ai.has("turret"):
			continue
		f.position = f.ai.get("home", _start)
		f.velocity = Vector2.ZERO
		if not f.alive and f.ai.has("respawn"):
			f.ai["respawn"] = 0.0
	ball = {"pos": _ball_start, "vel": Vector2.ZERO, "holder": null, "cool": 0.6}
	bullets.clear()


func _draw_ball() -> void:
	var p: Vector2 = ball["pos"]
	var lift: float = 22.0 if ball.get("holder") != null else 14.0
	_fx.draw_set_transform(p + Vector2(0, 6), 0.0, Vector2(1.0, 0.42))
	_fx.draw_circle(Vector2.ZERO, BALL_R, Color(0, 0, 0, 0.3))
	_fx.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var c: Vector2 = p + Vector2(0, -lift)
	_fx.draw_circle(c, BALL_R + 3.0, Color(0.05, 0.05, 0.08))
	_fx.draw_circle(c, BALL_R, Color("#fdfdfd"))
	var spin: float = time_in_level * (6.0 if (ball["vel"] as Vector2).length() > 30.0 else 0.0)
	for k: int in 5:
		var d: Vector2 = Vector2.RIGHT.rotated(spin + TAU * float(k) / 5.0) * BALL_R * 0.62
		_fx.draw_circle(c + d, 5.0, Color("#2b2d42"))
	_fx.draw_circle(c, 6.0, Color("#2b2d42"))
	if ball.get("holder") == null:
		_fx.draw_arc(p + Vector2(0, 2), BALL_R + 10.0 + sin(time_in_level * 6.0) * 3.0, 0.0, TAU, 28, Color(1, 1, 1, 0.5), 3.0, true)


# ------------------------------------------------------------------ final

func _win() -> void:
	if not online.is_empty():
		_net_end(1)
		return
	finished = true
	placed = 1
	move_input = Vector2.ZERO
	if stick != null:
		stick.release()
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = kills * 500 + coins * 100 + int(player.hp) + maxi(0, int(par - time_in_level)) * 20
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "kills": kills, "cubes": coins, "hp": int(player.hp), "time": snappedf(time_in_level, 0.1), "stars": stars})
	Audio.play("win")
	Audio.play_track("victoria", false)
	UI.float_text(_fx, player.position + Vector2(0, -170), Kit.text("brawl_win", "\u00a1\u00daltimo en pie!"), Color("#ffe066"), 44)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": maxi(coins_total, coins), "score": score, "record": record})
	await Ads.show_interstitial("level_end")


## 3 estrellas ganando rapido y entero; 2 si llegas con vida de sobra o a tiempo; 1 por ganar.
func stars_earned() -> int:
	var n: int = 1
	if mode == "ball":
		n += 1 if goals_score[1] == 0 else 0
		n += 1 if time_in_level <= par else 0
		return n
	if mode == "turrets":
		var mine: Variant = turrets[0]
		n += 1 if mine != null and (mine as BrawlFighter).hp >= (mine as BrawlFighter).max_hp * 0.5 else 0
		n += 1 if time_in_level <= par else 0
		return n
	if player.hp >= player.max_hp * 0.4:
		n += 1
	if time_in_level <= par:
		n += 1
	return n


func _lose() -> void:
	if not online.is_empty():
		_net_end(placed)
		return
	failed = true
	deaths += 1
	move_input = Vector2.ZERO
	if stick != null:
		stick.release()
	QA.log_event("death", {"cause": "brawl", "place": placed, "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var title: String = Kit.text("brawl_lose", "\u00a1Te han eliminado!")
	var sub: String = Kit.text("brawl_place", "Has quedado en el puesto {n}. \u00a1Otra vez!").format({"n": placed})
	match mode:
		"ball":
			title = Kit.text("brawl_lose_ball", "\u00a1Han ganado ellos!")
			sub = Kit.text("brawl_lose_ball_sub", "{a} a {b}. \u00a1La revancha!").format({"a": goals_score[0], "b": goals_score[1]})
		"turrets":
			title = Kit.text("brawl_lose_turrets", "\u00a1Han derribado tu torreta!")
			sub = Kit.text("brawl_lose_turrets_sub", "Protege la tuya y ataca la suya. \u00a1Otra vez!")
		"survival":
			sub = Kit.text("brawl_lose_survival", "Has llegado a la oleada {n} de {max}. \u00a1Otra vez!").format({"n": wave, "max": waves})
	var p: FailPanel = FailPanel.open(self, title, sub)
	p.closed.connect(retry)


func retry() -> void:
	_reset()


# ------------------------------------------------------------------ arena en directo

## Luchadores por puesto de salida: los jugadores de la sala y bots en los huecos (los mueve el anfitrion).
func _net_fighters() -> void:
	my_id = str(online.get("yo", ""))
	var spots: Array[Vector2] = [_start]
	spots.append_array(_spawns)
	var humans: Dictionary = {}
	var ids: Array[String] = []
	for j: Variant in online.get("jugadores", []):
		if j is Dictionary:
			humans[int((j as Dictionary).get("slot", 0))] = j
			ids.append(str((j as Dictionary).get("sesion", "")))
	ids.sort()
	host = not ids.is_empty() and ids[0] == my_id
	for slot: int in 4:
		var at: Vector2 = spots[slot % spots.size()]
		var f: BrawlFighter
		if humans.has(slot):
			var j: Dictionary = humans[slot]
			var mine: bool = str(j.get("sesion", "")) == my_id
			if mine:
				f = _make_fighter(true, at, slot)
				player = f
			else:
				f = _make_fighter(false, at, slot)
				f.remote = true
				f.max_hp = PLAYER_HP
				f.hp = PLAYER_HP
				f.damage = PLAYER_DMG
				f.bar_color = Color("#ffb14a")
			f.net_id = str(j.get("sesion", ""))
			f.fighter_name = str(j.get("alias", ""))
		elif coop:
			continue
		else:
			f = _make_fighter(false, at, slot)
			f.net_id = "bot%d" % slot
			f.fighter_name = Kit.text("bot", "Bot")
			f.remote = not host
		if coop:
			f.team = 0
			if f.remote:
				f.bar_color = Color("#4fc3ff")
		f.net_pos = at
		f.last_seen = 0.0
		by_id[f.net_id] = f
	_start_ms = int(online.get("start_ms", Time.get_ticks_msec()))
	if coop:
		spawn_wave(1)


func _net_open() -> void:
	net = Online.arena_channel(str(online.get("sala", "")))
	add_child(net)
	net.received.connect(_on_net)
	QA.log_event("arena_live_start", {"sala": str(online.get("sala", "")), "host": host, "players": (online.get("jugadores", []) as Array).size()})


func owned(f: BrawlFighter) -> bool:
	return not f.remote


func _net_state(f: BrawlFighter) -> Dictionary:
	return {"id": f.net_id, "p": [snappedf(f.position.x, 0.1), snappedf(f.position.y, 0.1)], "v": [snappedf(f.velocity.x, 0.1), snappedf(f.velocity.y, 0.1)],
		"hp": snappedf(f.hp, 1.0), "mhp": snappedf(f.max_hp, 1.0), "a": f.alive, "f": [snappedf(f.facing.x, 0.01), snappedf(f.facing.y, 0.01)],
		"ib": f.in_bush, "rv": snappedf(f.reveal, 0.1)}


## Manda el estado de lo que es mio 12 veces por segundo y da por ido a quien lleva 6 s sin dar senales.
func _net_step(delta: float) -> void:
	_send_acc += delta
	if _send_acc >= NET_RATE and net != null:
		_send_acc = 0.0
		var l: Array = []
		for f: BrawlFighter in fighters:
			if owned(f) and f.alive:
				l.append(_net_state(f))
		if not l.is_empty():
			net.send("st", {"l": l})
	for f: BrawlFighter in fighters:
		if f.remote and f.alive and time_in_level > 3.0 and time_in_level - f.last_seen > NET_TIMEOUT:
			f.hp = 0.0
			_on_death(f, null)


func _net_follow(f: BrawlFighter, delta: float) -> void:
	## Prediccion corta con su velocidad y acercamiento suave a lo ultimo que se supo.
	f.net_pos += f.velocity * delta
	f.position = f.position.lerp(f.net_pos, clampf(delta * 12.0, 0.0, 1.0))
	f.animate(f.velocity.length() > 5.0)
	var bushed: bool = in_bush(f.position)
	f.in_bush = bushed


func _on_net(event: String, d: Dictionary) -> void:
	if finished or failed:
		return
	match event:
		"st":
			for s: Variant in d.get("l", []):
				if not s is Dictionary:
					continue
				var sd: Dictionary = s
				var f: BrawlFighter = by_id.get(str(sd.get("id", ""))) as BrawlFighter
				if f == null or not f.remote or not f.alive:
					continue
				var p: Array = sd.get("p", [0, 0])
				var v: Array = sd.get("v", [0, 0])
				f.net_pos = Vector2(float(p[0]), float(p[1]))
				f.velocity = Vector2(float(v[0]), float(v[1]))
				f.max_hp = maxf(float(sd.get("mhp", f.max_hp)), 1.0)
				f.hp = float(sd.get("hp", f.hp))
				var fc: Array = sd.get("f", [0, 1])
				f.facing = Vector2(float(fc[0]), float(fc[1]))
				f.reveal = float(sd.get("rv", 0.0))
				f.last_seen = time_in_level
				f.queue_redraw()
		"sh":
			var f2: BrawlFighter = by_id.get(str(d.get("id", ""))) as BrawlFighter
			if f2 == null or not f2.remote or not f2.alive:
				return
			var o: Array = d.get("o", [0, 0])
			var origin: Vector2 = Vector2(float(o[0]), float(o[1]))
			if bool(d.get("s", false)):
				_spawn_super(f2, origin)
			else:
				var dd: Array = d.get("d", [0, 1])
				_spawn_shot(f2, origin, Vector2(float(dd[0]), float(dd[1])).normalized())
			f2.last_seen = time_in_level
		"ko":
			var f3: BrawlFighter = by_id.get(str(d.get("id", ""))) as BrawlFighter
			if f3 != null and f3.remote and f3.alive:
				f3.hp = 0.0
				var killer: BrawlFighter = by_id.get(str(d.get("by", ""))) as BrawlFighter
				_on_death(f3, killer)


func _show_countdown(t: float) -> void:
	if _countdown == null:
		_countdown = Label.new()
		_countdown.name = "Countdown"
		_countdown.theme_type_variation = "TitleLabel"
		_countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_countdown.set_anchors_preset(Control.PRESET_CENTER)
		_countdown.position = get_viewport_rect().size * 0.5 - Vector2(200, 100)
		_countdown.size = Vector2(400, 200)
		($Hud as CanvasLayer).add_child(_countdown)
	if t < 0.0:
		_countdown.text = str(int(ceil(-t)))
	elif t < 1.0:
		_countdown.text = Kit.text("go", "\u00a1Ya!")
	else:
		_countdown.visible = false


## Fin en directo: tu puesto al servidor (trofeos) y la ventana de resultado.
func _net_end(place: int) -> void:
	if reported:
		return
	reported = true
	placed = place
	if place == 1:
		finished = true
		Audio.play("win")
		UI.float_text(_fx, player.position + Vector2(0, -170), Kit.text("coop_win", "\u00a1Victoria en equipo!") if coop
			else Kit.text("brawl_win", "\u00a1\u00daltimo en pie!"), Color("#ffe066"), 44)
	else:
		failed = true
		Audio.play("hurt")
	move_input = Vector2.ZERO
	if stick != null:
		stick.release()
	QA.log_event("arena_live_end", {"place": place, "kills": kills})
	var sala: String = str(online.get("sala", ""))
	Online.arena_match = {}
	var r: Dictionary = await Online.arena_result(sala, place)
	if not is_inside_tree():
		return
	ArenaPanel.open_result(self, place, kills, r, coop, wave)


func open_pause() -> void:
	if not online.is_empty():
		return
	if finished or get_tree().paused or get_node_or_null("PauseMenu") != null:
		return
	if stick != null:
		stick.release()
	PauseMenu.open(self)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_inside_tree() and not UI.test_mode:
			open_pause()


func bot_state() -> Dictionary:
	return {"deaths": deaths, "coins": coins, "finished": finished, "failed": failed, "stomps": kills, "kills": kills,
		"hp": player.hp if player != null else 0.0, "rivals_left": rivals_left(), "time": time_in_level, "place": placed,
		"mode": mode, "score": goals_score.duplicate(), "wave": wave}


func capture_delays() -> Vector2:
	return Vector2(5.0, 1.5)


# ------------------------------------------------------------------ dibujo

func _floor_colors() -> Array[Color]:
	var base: Color = Kit.color("sky", Color("#1b2a41")).lerp(Color("#d8c49a"), 0.62)
	return [base, base.darkened(0.035)]


func _draw_floor() -> void:
	var cols: Array[Color] = _floor_colors()
	var w: Vector2 = Vector2(_size) * TILE
	## Borde de la arena: agua oscura alrededor.
	_floor.draw_rect(Rect2(Vector2(-TILE * 6.0, -TILE * 6.0), w + Vector2(TILE * 12.0, TILE * 12.0)), Kit.color("sky", Color("#1b2a41")).darkened(0.25))
	_floor.draw_rect(Rect2(Vector2(-10, -10), w + Vector2(20, 20)), cols[1].darkened(0.4))
	for y: int in _size.y:
		for x: int in _size.x:
			var r: Rect2 = Rect2(Vector2(x, y) * TILE, Vector2(TILE, TILE))
			_floor.draw_rect(r, cols[(x + y) % 2])
			## Losas con bisel: luz arriba a la izquierda y sombra abajo a la derecha.
			_floor.draw_rect(Rect2(r.position, Vector2(TILE, 3.0)), Color(1, 1, 1, 0.1))
			_floor.draw_rect(Rect2(r.position, Vector2(3.0, TILE)), Color(1, 1, 1, 0.07))
			_floor.draw_rect(Rect2(r.position + Vector2(0.0, TILE - 3.0), Vector2(TILE, 3.0)), Color(0, 0, 0, 0.08))
	## Suelo limpio (la critica visual lo veia ruidoso con texturas encima): solo un oscurecido suave
	## hacia los bordes para que los personajes resalten en el centro.
	for k: int in 6:
		var g: float = TILE * 0.35 * float(k)
		_floor.draw_rect(Rect2(Vector2(g, g), w - Vector2(g, g) * 2.0), Color(0, 0, 0, 0.035), false, TILE * 0.35)
	## Lineas de pista finas (dan sensacion de campo de juego).
	_floor.draw_rect(Rect2(Vector2(TILE * 0.5, TILE * 0.5), w - Vector2(TILE, TILE)), Color(1, 1, 1, 0.14), false, 4.0)
	_floor.draw_arc(w * 0.5, TILE * 1.6, 0.0, TAU, 48, Color(1, 1, 1, 0.14), 4.0, true)
	## Porterias: la tuya azul, la suya roja, con red.
	for t: int in 2:
		var gc: Color = Color("#4fc3ff") if t == 0 else Color("#ff5a4f")
		for cell: Vector2i in goal_cells[t].keys():
			var r: Rect2 = Rect2(Vector2(cell) * TILE, Vector2(TILE, TILE))
			_floor.draw_rect(r, Color(gc, 0.35))
			for k: int in 5:
				var x: float = r.position.x + TILE * float(k) / 4.0
				_floor.draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color(1, 1, 1, 0.35), 2.0)
				var y: float = r.position.y + TILE * float(k) / 4.0
				_floor.draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(1, 1, 1, 0.35), 2.0)
			_floor.draw_rect(r, gc, false, 5.0)


func _draw_wall(n: Node2D, cell: Vector2i) -> void:
	var tex: Texture2D = Kit.first_tile_texture()
	var top_col: Color = Kit.color("solid", Color("#7c8aa5"))
	var top: Rect2 = Rect2(Vector2(0.0, -TILE - WALL_H), Vector2(TILE, TILE))
	if not _walls.has(cell + Vector2i(0, 1)):
		## Cara de delante (mas oscura) y sombra en el suelo.
		n.draw_rect(Rect2(Vector2(0.0, 0.0), Vector2(TILE, 16.0)), Color(0, 0, 0, 0.22))
		n.draw_rect(Rect2(Vector2(0.0, -WALL_H), Vector2(TILE, WALL_H)), top_col.darkened(0.45))
		n.draw_rect(Rect2(Vector2(0.0, -WALL_H), Vector2(TILE, 4.0)), top_col.darkened(0.25))
	if tex != null:
		n.draw_texture_rect(tex, top, false, Color.WHITE.lerp(top_col, 0.25))
	else:
		n.draw_rect(top, top_col)
	## Bordes de la cara de arriba donde acaba el muro (se lee el volumen).
	var edge: Color = top_col.lightened(0.35)
	var dark: Color = top_col.darkened(0.55)
	if not _walls.has(cell + Vector2i(0, -1)):
		n.draw_rect(Rect2(top.position, Vector2(TILE, 5.0)), edge)
	if not _walls.has(cell + Vector2i(-1, 0)):
		n.draw_rect(Rect2(top.position, Vector2(5.0, TILE)), edge.lerp(top_col, 0.5))
	if not _walls.has(cell + Vector2i(1, 0)):
		n.draw_rect(Rect2(top.position + Vector2(TILE - 5.0, 0.0), Vector2(5.0, TILE)), dark)


func _draw_box(n: Node2D, cell: Vector2i) -> void:
	if not boxes.has(cell):
		return
	var wood: Color = Color("#b8793a")
	var m: float = 10.0
	var body: Rect2 = Rect2(Vector2(m, -TILE - WALL_H * 0.6 + m), Vector2(TILE - 2.0 * m, TILE - 2.0 * m))
	n.draw_rect(Rect2(Vector2(m, -8.0), Vector2(TILE - 2.0 * m, 14.0)), Color(0, 0, 0, 0.22))
	n.draw_rect(Rect2(Vector2(m, -WALL_H * 0.6 - m), Vector2(TILE - 2.0 * m, WALL_H * 0.6)), wood.darkened(0.45))
	n.draw_rect(body, wood)
	n.draw_rect(body.grow(-8.0), wood.darkened(0.12))
	n.draw_line(body.position + Vector2(8, 8), body.end - Vector2(8, 8), wood.lightened(0.15), 8.0)
	n.draw_rect(body, wood.darkened(0.5), false, 4.0)
	## Grietas segun el dano.
	var dmg: float = 1.0 - float(boxes[cell]) / 1300.0
	if dmg > 0.3:
		n.draw_line(body.position + Vector2(14, 20), body.position + Vector2(34, 44), Color(0, 0, 0, 0.5), 3.0)
	if dmg > 0.6:
		n.draw_line(body.end - Vector2(14, 16), body.end - Vector2(40, 36), Color(0, 0, 0, 0.5), 3.0)
	## Cubo de poder dibujado en la tapa.
	var c: Vector2 = body.get_center()
	n.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -12), c + Vector2(11, -6), c + Vector2(0, 0), c + Vector2(-11, -6)]), Color("#e2b8ff"))
	n.draw_colored_polygon(PackedVector2Array([c + Vector2(-11, -6), c, c + Vector2(0, 13), c + Vector2(-11, 6)]), Color("#b05cff"))
	n.draw_colored_polygon(PackedVector2Array([c, c + Vector2(11, -6), c + Vector2(11, 6), c + Vector2(0, 13)]), Color("#7a2fcf"))


func _draw_bushes() -> void:
	var leaf: Color = Kit.color("solid", Color("#3e5c84")).lerp(Color("#3fae49"), 0.7)
	var t: float = time_in_level
	for cell: Vector2i in _bush.keys():
		var o: Vector2 = Vector2(cell) * TILE
		var seed_v: int = cell.x * 31 + cell.y * 17
		for k: int in 5:
			var a: float = float((seed_v + k * 13) % 17) / 17.0
			var p: Vector2 = o + Vector2(TILE * (0.22 + 0.56 * fposmod(a * 3.1 + float(k) * 0.37, 1.0)), TILE * (0.25 + 0.5 * fposmod(a * 1.7 + float(k) * 0.53, 1.0)))
			p.x += sin(t * 1.8 + float(seed_v + k)) * 3.0
			var r: float = TILE * (0.3 + 0.08 * a)
			_bushes.draw_circle(p + Vector2(0, 8), r, leaf.darkened(0.45))
			_bushes.draw_circle(p, r, leaf)
			_bushes.draw_circle(p + Vector2(-r * 0.25, -r * 0.3), r * 0.45, leaf.lightened(0.18))


func _draw_fx() -> void:
	## Cubos de poder sueltos (flotan y brillan).
	for c: Dictionary in cubes:
		var p: Vector2 = (c["pos"] as Vector2) + Vector2(0, -24.0 + sin(float(c["t"]) * 4.0) * 6.0)
		_fx.draw_set_transform(c["pos"] as Vector2 + Vector2(0, 6), 0.0, Vector2(1.0, 0.4))
		_fx.draw_circle(Vector2.ZERO, 20.0, Color(0, 0, 0, 0.25))
		_fx.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_fx.draw_circle(p, 30.0, Color(0.75, 0.4, 1.0, 0.18))
		_fx.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -20), p + Vector2(18, -10), p + Vector2(0, 0), p + Vector2(-18, -10)]), Color("#e2b8ff"))
		_fx.draw_colored_polygon(PackedVector2Array([p + Vector2(-18, -10), p, p + Vector2(0, 21), p + Vector2(-18, 10)]), Color("#b05cff"))
		_fx.draw_colored_polygon(PackedVector2Array([p, p + Vector2(18, -10), p + Vector2(18, 10), p + Vector2(0, 21)]), Color("#7a2fcf"))
	## Aro bajo el objetivo al que apuntas.
	if aim_target != null and aim_target.alive and player != null and player.alive and not finished:
		_fx.draw_set_transform(aim_target.position + Vector2(0, 4), 0.0, Vector2(1.0, 0.42))
		_fx.draw_arc(Vector2.ZERO, 50.0 + sin(time_in_level * 8.0) * 4.0, 0.0, TAU, 32, Color(1.0, 0.85, 0.3, 0.9), 6.0, true)
		_fx.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	## Balas: estela suave y nucleo brillante.
	for b: Dictionary in bullets:
		var p: Vector2 = b["pos"]
		var v: Vector2 = (b["vel"] as Vector2).normalized()
		var col: Color = b["col"]
		var w: float = float(b["w"])
		_fx.draw_line(p - v * 46.0, p, Color(col, 0.28), w * 1.6, true)
		_fx.draw_line(p - v * 22.0, p, col, w, true)
		_fx.draw_circle(p, w * 0.7, col.lerp(Color.WHITE, 0.6))
	_draw_aim()
	## Escudos.
	for f: BrawlFighter in fighters:
		if f.alive and f.ai.has("shield"):
			var a: float = clampf(float(f.ai["shield"]), 0.0, 1.0)
			_fx.draw_circle(f.position + Vector2(0, -34), 62.0, Color(0.5, 0.9, 1.0, 0.16 * a))
			_fx.draw_arc(f.position + Vector2(0, -34), 62.0, 0.0, TAU, 40, Color(0.6, 0.95, 1.0, 0.8 * a), 4.0, true)
	if mode == "ball" and not ball.is_empty():
		_draw_ball()
	## Vida, cubos y municion por encima de todo.
	for f: BrawlFighter in fighters:
		f.draw_overlay(_fx)


func _draw_gas() -> void:
	if time_in_level < gas_start or gas_radius >= gas_max:
		return
	var thick: float = 4000.0
	## Color de lo que cierra la arena (game.json "brawl_gas_color": marea azul, lava...); de serie, gas verde.
	var base: Color = Color(str(Kit.param("brawl_gas_color", "#73f259")))
	_gas.draw_arc(gas_center, gas_radius + thick * 0.5, 0.0, TAU, 96, Color(base, 0.34), thick)
	## Borde con oleaje: un aro que ondula y otro mas claro.
	var pts: PackedVector2Array = PackedVector2Array()
	for k: int in 97:
		var a: float = TAU * float(k) / 96.0
		pts.append(gas_center + Vector2.RIGHT.rotated(a) * (gas_radius + sin(a * 14.0 + time_in_level * 3.0) * 8.0))
	_gas.draw_polyline(pts, Color(base.lightened(0.45), 0.85), 7.0, true)
