extends Node2D
## Mazmorras: RPG de accion vista desde arriba (estilo Archero). Datos y salas en dungeon_map.gd.
## 1 - Arrastra el dedo para moverte (joystick donde toques). Al soltar, el heroe dispara solo
##     al monstruo mas cercano: moverse esquiva, pararse ataca.
## 2 - Las puertas se abren al limpiar la sala. Busca al jefe (B) por la planta; el minimapa
##     de arriba ensena lo visitado.
## 3 - Experiencia de cada monstruo: al subir de nivel eliges 1 de 3 habilidades (flechas extra,
##     diagonales, rebote, dano, cadencia, vida, robo de vida, escudo, velocidad).
## 4 - Cofres de las salas de tesoro: equipo (arma, armadura, anillo) de 4 rarezas que se guarda
##     entre niveles y partidas; se equipa solo si es mejor.
## 5 - Monstruos: slime (persigue), murcielago (zigzag, vuela sobre columnas), arquero (dispara
##     desde lejos), golem (golpe en area avisado) y el jefe (anillo de balas, rafagas y embestida).
## 6 - Estrellas: 3 sin morir y antes del par, 2 sin morir, 1 si no.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const MapRules = preload("res://kit/dungeon/dungeon_map.gd")
const T: float = 64.0
const HERO_R: float = 22.0
const ARROW_SPEED: float = 760.0
const SKILL_NAMES: Dictionary = {"multi": "Flecha doble", "diagonal": "Flechas en diagonal", "rebote": "Rebote", "dano": "M\u00e1s da\u00f1o",
	"cadencia": "Disparo r\u00e1pido", "vida": "M\u00e1s vida", "robo": "Robo de vida", "escudo": "Escudo", "rapido": "Botas veloces"}
const SKILL_DESC: Dictionary = {"multi": "Una flecha m\u00e1s hacia delante", "diagonal": "Dos flechas en diagonal", "rebote": "Las flechas rebotan en las paredes",
	"dano": "+25 % de da\u00f1o", "cadencia": "+20 % de velocidad de disparo", "vida": "+25 % de vida y te cura", "robo": "Te curas al matar",
	"escudo": "Para un golpe en cada sala", "rapido": "+15 % de velocidad"}

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
var par: float = 300.0
var power: float = 1.0
var seed_v: int = 1
var floor_i: int = 0

var rooms: Dictionary = {}
var start_cell: Vector2i = Vector2i.ZERO
var boss_cell: Vector2i = Vector2i.ZERO
var cell: Vector2i = Vector2i.ZERO
var tiles: Array[String] = []
var cleared: Dictionary = {}
var visited: Dictionary = {}
var chests: Dictionary = {}
var hero: Dictionary = {}
var skills: Dictionary = {}
var gear: Dictionary = {}
var enemies: Array[Dictionary] = []
var arrows: Array[Dictionary] = []
var bullets: Array[Dictionary] = []
var drops: Array[Dictionary] = []
var choices: Array[String] = []
## Direccion de movimiento (joystick o bot). Cero = quieto (y dispara).
var move_dir: Vector2 = Vector2.ZERO
var kills: int = 0

var _rnd: RandomNumberGenerator = RandomNumberGenerator.new()
var _field: PackedInt32Array = PackedInt32Array()
var _field_t: float = 0.0
var _fx: Array[Dictionary] = []
var _world: Node2D
## Arte de la IA (si el juego lo tiene): heroe y monstruos como sprites encima del dibujo.
var _actors: Node2D
var _hero_art: AnimatedSprite2D
var _camera: Camera2D
var _font: Font
var _hp_bar: ColorRect
var _hp_back: ColorRect
var _hp_label: Label
var _xp_bar: ColorRect
var _xp_back: ColorRect
var _lvl_label: Label
var _coins_label: Label
var _toast: Label
var _toast_t: float = 0.0
var _map_view: Control
var _stick: Control
var _choice_panel: PanelContainer
var _choice_box: VBoxContainer
var _touch_id: int = -1
var _touch_from: Vector2 = Vector2.ZERO
var _touch_at: Vector2 = Vector2.ZERO


func _ready() -> void:
	level = Kit.current_level()
	par = float(level.get("par", 300))
	power = float(level.get("power", 1.0))
	seed_v = int(level.get("seed", 1))
	floor_i = Kit.level_index
	RenderingServer.set_default_clear_color(Color("#0e0b14"))
	_world = Node2D.new()
	_world.name = "World"
	_world.draw.connect(_draw_world)
	add_child(_world)
	_actors = Node2D.new()
	_actors.name = "Actors"
	add_child(_actors)
	var hero_entry: Dictionary = Kit.sprite_by_role("jugador")
	if not hero_entry.is_empty():
		_hero_art = SpriteKit.animado(hero_entry, 84.0, "idle", false)
		_actors.add_child(_hero_art)
		Skins.apply(_hero_art)
	_camera = Camera2D.new()
	add_child(_camera)
	_camera.make_current()
	Juice.register_camera(_camera)
	_font = UI.theme.get_font("font", "Label") if UI.theme != null else ThemeDB.fallback_font
	_build_hud()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "dungeon", "rooms": rooms.size()})


func bot_script() -> String:
	return "res://qa/dungeon_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(6.0, 3.0)


# ------------------------------------------------------------------ montaje

func _reset() -> void:
	finished = false
	failed = false
	time_in_level = 0.0
	var p: Dictionary = MapRules.parse(level)
	rooms = p["rooms"]
	start_cell = p["start"]
	boss_cell = p["boss"]
	cleared.clear()
	visited.clear()
	chests.clear()
	skills.clear()
	kills = 0
	coins = 0
	coins_total = 0
	for c: Variant in rooms:
		if str(rooms[c]) in ["M", "E", "B"]:
			coins_total += 1
	_rnd.seed = seed_v * 7919 + 13
	gear = _load_gear()
	hero = {"pos": Vector2.ZERO, "hp": 0.0, "xp": 0, "lvl": 1, "cd": 0.0, "inv": 0.0, "shield": 0, "face": Vector2.UP}
	hero["hp"] = max_hp()
	choices.clear()
	_hide_choices()
	_enter(start_cell, -1)
	_fit_camera()
	_update_hud()


func _load_gear() -> Dictionary:
	var g: Variant = Save.meta().get("dungeon_gear", {})
	return (g as Dictionary).duplicate(true) if g is Dictionary else {}


func _save_gear() -> void:
	if UI.test_mode or QA.enabled:
		return
	Save.meta()["dungeon_gear"] = gear.duplicate(true)
	Save.save_data()


## Entra en una sala; 'from' = lado por el que se entra (0 arriba ... 3 izquierda, -1 al empezar).
func _enter(c: Vector2i, from: int) -> void:
	_clear_art()
	cell = c
	visited[c] = true
	tiles = MapRules.room_tiles(rooms, c, seed_v)
	enemies.clear()
	arrows.clear()
	bullets.clear()
	drops.clear()
	if from < 0:
		hero["pos"] = Vector2(MapRules.ROOM_W * 0.5, MapRules.ROOM_H - 3.0) * T
	else:
		var d: Vector2i = MapRules.door_tile(from) - MapRules.DIRS[from] * 2
		hero["pos"] = (Vector2(d) + Vector2(0.5, 0.5)) * T
	hero["shield"] = int(skills.get("escudo", 0))
	hero["inv"] = 0.6
	if not cleared.has(c):
		for e: Array in MapRules.room_enemies(rooms, c, seed_v, floor_i):
			_spawn(str(e[0]), (Vector2(e[1]) + Vector2(0.5, 0.5)) * T)
		if enemies.is_empty():
			cleared[c] = true
	if str(rooms[c]) == "T" and not chests.has(c):
		chests[c] = false
	_field_t = 0.0
	if str(rooms[c]) == "B" and not fast:
		_toast_now(Kit.text("dungeon_boss", "\u00a1El jefe de la mazmorra!"))
		Audio.play("hurt", 0.1)


const ART_KIND: Dictionary = {"slime": "walker", "golem": "walker", "archer": "spiky", "bat": "flyer", "boss": "boss"}
const ART_TINT: Dictionary = {"slime": Color(1, 1, 1), "golem": Color(0.72, 0.74, 0.82), "archer": Color(0.8, 1.0, 0.8), "bat": Color(0.85, 0.72, 1.0), "boss": Color(1, 1, 1)}


func _art_entry(kind: String) -> Dictionary:
	var id: String = str(Kit.param("art.enemies." + str(ART_KIND.get(kind, "walker")), ""))
	var entry: Dictionary = Kit.sprite_entry(id) if id != "" else {}
	if entry.is_empty() and kind != "boss":
		entry = Kit.sprite_by_role("enemigo")
	return entry


func _clear_art() -> void:
	for e: Dictionary in enemies:
		if e.has("art") and is_instance_valid(e["art"]):
			(e["art"] as Node).queue_free()
		e.erase("art")


func _sync_art() -> void:
	if _hero_art != null and not hero.is_empty():
		_hero_art.position = (hero["pos"] as Vector2) + Vector2(0, -10)
		if absf((hero["face"] as Vector2).x) > 0.2:
			_hero_art.flip_h = (hero["face"] as Vector2).x < 0.0
		var anim: String = "run" if move_dir.length() > 0.1 and _hero_art.sprite_frames.has_animation("run") else "idle"
		if _hero_art.sprite_frames.has_animation(anim) and _hero_art.animation != anim:
			_hero_art.play(anim)
		_hero_art.modulate.a = 0.4 if float(hero["inv"]) > 0.0 and int(time_in_level * 20.0) % 2 == 0 else 1.0
	for e: Dictionary in enemies:
		if not e.has("art"):
			continue
		var n: Node2D = e["art"]
		if not is_instance_valid(n):
			continue
		if not e["alive"]:
			n.queue_free()
			e.erase("art")
			continue
		n.position = (e["pos"] as Vector2) + Vector2(0, -6)
		var dx: float = (hero["pos"] as Vector2).x - (e["pos"] as Vector2).x
		if n is AnimatedSprite2D and absf(dx) > 4.0:
			(n as AnimatedSprite2D).flip_h = dx < 0.0
		## Golpe recibido: parpadea en blanco.
		n.modulate = (ART_TINT.get(str(e["kind"]), Color.WHITE) as Color) if float(e.get("flash", 0.0)) <= 0.0 else Color(2.0, 2.0, 2.0)


func _spawn(kind: String, at: Vector2) -> void:
	var info: Dictionary = MapRules.ENEMIES[kind]
	var mx: float = float(info["hp"]) * power * (1.0 + 0.08 * float(floor_i))
	var e: Dictionary = {"kind": kind, "pos": at, "hp": mx, "max": mx, "cd": 1.0 + _rnd.randf(), "t": _rnd.randf() * 6.0,
		"alive": true, "tele": 0.0, "dash": Vector2.ZERO, "dash_t": 0.0, "phase": 0, "summoned": false, "flash": 0.0}
	var entry: Dictionary = _art_entry(kind)
	if not entry.is_empty():
		var size_px: float = float(info["r"]) * (2.9 if kind != "boss" else 2.6)
		var spr: AnimatedSprite2D = SpriteKit.animado(entry, size_px, "run", false)
		spr.modulate = ART_TINT.get(kind, Color.WHITE)
		_actors.add_child(spr)
		e["art"] = spr
	enemies.append(e)


func _fit_camera() -> void:
	var vp: Vector2 = get_viewport_rect().size
	var room: Vector2 = Vector2(MapRules.ROOM_W, MapRules.ROOM_H) * T
	var z: float = minf(vp.x / (room.x + 16.0), (vp.y - 300.0) / room.y)
	_camera.zoom = Vector2.ONE * z
	_camera.position = room * 0.5 + Vector2(0, -40.0 / z)


# ------------------------------------------------------------------ estadisticas

func gear_bonus(slot: String) -> float:
	return float((gear.get(slot, {}) as Dictionary).get("bonus", 0.0))


func max_hp() -> float:
	return (140.0 * (1.0 + 0.25 * float(skills.get("vida", 0))) + gear_bonus("armadura")) * DungeonGearPanel.mult("vida")


func damage() -> float:
	return 12.0 * (1.0 + 0.25 * float(skills.get("dano", 0))) * (1.0 + gear_bonus("arma") / 100.0) * DungeonGearPanel.mult("dano")


func fire_rate() -> float:
	return 1.7 * (1.0 + 0.2 * float(skills.get("cadencia", 0))) * DungeonGearPanel.mult("cadencia")


func hero_speed() -> float:
	return 240.0 * (1.0 + 0.15 * float(skills.get("rapido", 0)))


func alive_enemies() -> int:
	var n: int = 0
	for e: Dictionary in enemies:
		if e["alive"]:
			n += 1
	return n


func room_clear() -> bool:
	return cleared.has(cell)


# ------------------------------------------------------------------ interfaz

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
	_stick = Control.new()
	_stick.name = "Stick"
	_stick.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stick.draw.connect(_draw_stick)
	root.add_child(_stick)
	var safe: MarginContainer = UI.safe_root(root, 16.0)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col: VBoxContainer = VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 6)
	safe.add_child(col)
	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 10)
	col.add_child(top)
	var bars: VBoxContainer = VBoxContainer.new()
	bars.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(bars)
	var hp: Control = Control.new()
	hp.custom_minimum_size = Vector2(0, 40)
	hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bars.add_child(hp)
	_hp_back = _rect(hp, Color(0, 0, 0, 0.6), true)
	_hp_bar = _rect(hp, Color("#e0404a"), false)
	_hp_label = _bar_label(hp)
	var xp: Control = Control.new()
	xp.custom_minimum_size = Vector2(0, 26)
	xp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bars.add_child(xp)
	_xp_back = _rect(xp, Color(0, 0, 0, 0.6), true)
	_xp_bar = _rect(xp, Color("#4aa3ff"), false)
	_lvl_label = _bar_label(xp)
	_lvl_label.add_theme_font_size_override("font_size", 18)
	var cbox: HBoxContainer = HBoxContainer.new()
	cbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cbox.add_theme_constant_override("separation", 4)
	bars.add_child(cbox)
	cbox.add_child(UiIcon.make("coin", Kit.color("coin", Color("#ffd23f")), 30.0))
	_coins_label = Label.new()
	_coins_label.name = "Coins"
	_coins_label.add_theme_font_size_override("font_size", 24)
	cbox.add_child(_coins_label)
	_map_view = Control.new()
	_map_view.name = "Minimap"
	_map_view.custom_minimum_size = Vector2(120, 110)
	_map_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_view.draw.connect(_draw_minimap)
	top.add_child(_map_view)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)
	_toast = Label.new()
	_toast.name = "Toast"
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.add_theme_color_override("font_color", Kit.color("accent", Color("#ffd23f")))
	_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_toast.add_theme_constant_override("outline_size", 8)
	col.add_child(_toast)
	var grow: Control = Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(grow)
	var hint: Label = Label.new()
	hint.name = "Hint"
	hint.text = Kit.text("dungeon_hint", "Arrastra para moverte; suelta y disparas solo")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", UI.colors["texto_suave"])
	col.add_child(hint)
	## Eleccion de habilidad (sale al subir de nivel).
	_choice_panel = PanelContainer.new()
	_choice_panel.name = "Skills"
	_choice_panel.set_anchors_preset(Control.PRESET_CENTER)
	_choice_panel.visible = false
	root.add_child(_choice_panel)
	_choice_box = VBoxContainer.new()
	_choice_box.add_theme_constant_override("separation", 12)
	_choice_panel.add_child(_choice_box)


func _rect(parent: Control, c: Color, full: bool) -> ColorRect:
	var r: ColorRect = ColorRect.new()
	r.color = c
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if full:
		r.set_anchors_preset(Control.PRESET_FULL_RECT)
	else:
		r.position = Vector2(3, 3)
	parent.add_child(r)
	return r


func _bar_label(parent: Control) -> Label:
	var l: Label = Label.new()
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	parent.add_child(l)
	return l


func _update_hud() -> void:
	if _hp_bar == null or hero.is_empty():
		return
	var f: float = clampf(float(hero["hp"]) / max_hp(), 0.0, 1.0)
	_hp_bar.size = Vector2(maxf(0.0, (_hp_back.size.x - 6.0) * f), _hp_back.size.y - 6.0)
	_hp_label.text = "%d / %d" % [int(ceil(float(hero["hp"]))), int(max_hp())]
	var need: int = xp_need()
	_xp_bar.size = Vector2(maxf(0.0, (_xp_back.size.x - 6.0) * clampf(float(hero["xp"]) / float(need), 0.0, 1.0)), _xp_back.size.y - 6.0)
	_lvl_label.text = Kit.text("dungeon_level", "Nivel {n}").format({"n": int(hero["lvl"])})
	_coins_label.text = "%d" % coins
	_map_view.queue_redraw()


func xp_need() -> int:
	return 20 + 15 * (int(hero["lvl"]) - 1)


func _toast_now(t: String, col: Color = Color(0, 0, 0, 0)) -> void:
	if _toast == null:
		return
	_toast.text = t
	_toast.add_theme_color_override("font_color", col if col.a > 0.0 else Kit.color("accent", Color("#ffd23f")))
	_toast_t = 3.0


func _skill_name(id: String) -> String:
	return Kit.text("dungeon_skill_" + id, str(SKILL_NAMES[id]))


func _show_choices() -> void:
	for c: Node in _choice_box.get_children():
		_choice_box.remove_child(c)
		c.queue_free()
	var title: Label = Label.new()
	title.text = Kit.text("dungeon_level_up", "\u00a1Subes de nivel! Elige una habilidad")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size = Vector2(520, 0)
	_choice_box.add_child(title)
	for i: int in choices.size():
		var id: String = choices[i]
		var b: Button = UI.make_button(_skill_name(id), i == 0, "")
		b.name = "Skill_%d" % i
		b.custom_minimum_size = Vector2(520, 110)
		b.pressed.connect(choose_skill.bind(i))
		_choice_box.add_child(b)
		var d: Label = Label.new()
		d.text = Kit.text("dungeon_desc_" + id, str(SKILL_DESC[id]))
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.add_theme_font_size_override("font_size", 22)
		d.add_theme_color_override("font_color", UI.colors["texto_suave"])
		_choice_box.add_child(d)
	_choice_panel.visible = true
	_choice_panel.reset_size()
	_choice_panel.position = (get_viewport_rect().size - _choice_panel.size) * 0.5


func _hide_choices() -> void:
	if _choice_panel != null:
		_choice_panel.visible = false


func choose_skill(i: int) -> void:
	if i < 0 or i >= choices.size():
		return
	var id: String = choices[i]
	skills[id] = int(skills.get(id, 0)) + 1
	if id == "vida":
		hero["hp"] = minf(max_hp(), float(hero["hp"]) + max_hp() * 0.4)
	if id == "escudo":
		hero["shield"] = int(hero["shield"]) + 1
	choices.clear()
	_hide_choices()
	if not fast:
		Audio.play("powerup")
	_update_hud()


# ------------------------------------------------------------------ simulacion

func can_act() -> bool:
	return not finished and is_inside_tree() and not get_tree().paused


func _physics_process(delta: float) -> void:
	if finished:
		return
	if not choices.is_empty():
		_world.queue_redraw()
		return
	var steps: int = 3 if fast else 1
	for k: int in steps:
		_tick(1.0 / 60.0 if fast else delta)
		if finished or not choices.is_empty():
			break
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0:
			_toast.text = ""
	_sync_art()
	_world.queue_redraw()
	_stick.queue_redraw()


func _tick(dt: float) -> void:
	time_in_level += dt
	hero["inv"] = maxf(0.0, float(hero["inv"]) - dt)
	_field_t -= dt
	if _field_t <= 0.0:
		_field_t = 0.3
		_field = _flow_to(_tile_of(hero["pos"]))
	_move_hero(dt)
	_step_enemies(dt)
	_step_arrows(dt)
	_step_bullets(dt)
	_step_drops(dt)
	for f: Dictionary in _fx:
		f["t"] = float(f["t"]) - dt
	var keep: Array[Dictionary] = []
	for f: Dictionary in _fx:
		if float(f["t"]) > 0.0:
			keep.append(f)
	_fx = keep
	if not room_clear() and alive_enemies() == 0:
		cleared[cell] = true
		if not fast:
			Audio.play("coin")
			_toast_now(Kit.text("dungeon_clear", "\u00a1Sala limpia! Las puertas se abren"))
		if cell == boss_cell:
			_win()
			return
	_check_door()


func _tile_of(p: Vector2) -> Vector2i:
	return Vector2i(clampi(int(p.x / T), 0, MapRules.ROOM_W - 1), clampi(int(p.y / T), 0, MapRules.ROOM_H - 1))


func solid(c: Vector2i, flying: bool = false) -> bool:
	if c.x < 0 or c.y < 0 or c.x >= MapRules.ROOM_W or c.y >= MapRules.ROOM_H:
		return not room_clear() or flying
	if tiles[c.y][c.x] == "#":
		## Los murcielagos vuelan por encima de las columnas, no de las paredes.
		return not flying or c.x == 0 or c.y == 0 or c.x == MapRules.ROOM_W - 1 or c.y == MapRules.ROOM_H - 1
	## Puertas cerradas mientras quedan monstruos.
	if (c.x == 0 or c.y == 0 or c.x == MapRules.ROOM_W - 1 or c.y == MapRules.ROOM_H - 1) and not room_clear():
		return true
	return false


## Mueve un circulo resbalando por las paredes (primero x, luego y).
func _slide(p: Vector2, d: Vector2, r: float, flying: bool = false) -> Vector2:
	var n: Vector2 = Vector2(p.x + d.x, p.y)
	if _hits(n, r, flying):
		n.x = p.x
	n.y += d.y
	if _hits(n, r, flying):
		n.y = p.y
	return n


func _hits(p: Vector2, r: float, flying: bool) -> bool:
	var a: Vector2i = Vector2i(int(floor((p.x - r) / T)), int(floor((p.y - r) / T)))
	var b: Vector2i = Vector2i(int(floor((p.x + r) / T)), int(floor((p.y + r) / T)))
	for y: int in range(a.y, b.y + 1):
		for x: int in range(a.x, b.x + 1):
			if not solid(Vector2i(x, y), flying):
				continue
			var q: Vector2 = Vector2(clampf(p.x, float(x) * T, float(x + 1) * T), clampf(p.y, float(y) * T, float(y + 1) * T))
			if q.distance_to(p) < r:
				return true
	return false


## Mapa de distancias hasta una casilla (para monstruos y el bot).
func _flow_to(goal: Vector2i) -> PackedInt32Array:
	var w: int = MapRules.ROOM_W
	var h: int = MapRules.ROOM_H
	var d: PackedInt32Array = PackedInt32Array()
	d.resize(w * h)
	d.fill(-1)
	if goal.x < 0 or goal.y < 0 or goal.x >= w or goal.y >= h:
		return d
	d[goal.y * w + goal.x] = 0
	var q: Array[Vector2i] = [goal]
	var head: int = 0
	while head < q.size():
		var c: Vector2i = q[head]
		head += 1
		for dir: Vector2i in MapRules.DIRS:
			var n: Vector2i = c + dir
			if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h or d[n.y * w + n.x] >= 0 or tiles[n.y][n.x] == "#":
				continue
			d[n.y * w + n.x] = d[c.y * w + c.x] + 1
			q.append(n)
	return d


## Direccion para ir hacia donde marca un mapa de distancias.
func flow_dir(from: Vector2, f: PackedInt32Array) -> Vector2:
	var c: Vector2i = _tile_of(from)
	var w: int = MapRules.ROOM_W
	var best: Vector2i = c
	var bv: int = f[c.y * w + c.x] if f[c.y * w + c.x] >= 0 else 9999
	for dir: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
		var n: Vector2i = c + dir
		if n.x < 0 or n.y < 0 or n.x >= w or n.y >= MapRules.ROOM_H:
			continue
		var v: int = f[n.y * w + n.x]
		if v < 0 or v >= bv:
			continue
		if dir.x != 0 and dir.y != 0 and (tiles[c.y][n.x] == "#" or tiles[n.y][c.x] == "#"):
			continue
		bv = v
		best = n
	if best == c:
		## Ya en la casilla buscada: hacia su centro.
		var cc: Vector2 = (Vector2(c) + Vector2(0.5, 0.5)) * T - from
		return cc.normalized() if cc.length() > 2.0 else Vector2.ZERO
	var target: Vector2 = (Vector2(best) + Vector2(0.5, 0.5)) * T
	## Centrarse en el eje que no se recorre para no engancharse en las esquinas.
	var mid: Vector2 = (Vector2(c) + Vector2(0.5, 0.5)) * T
	var dd: Vector2 = target - from
	if best.x == c.x:
		dd.x = (mid.x - from.x) * 2.0
	elif best.y == c.y:
		dd.y = (mid.y - from.y) * 2.0
	return dd.normalized() if dd.length() > 1.0 else Vector2.ZERO


func path_to_tile(goal: Vector2i) -> Vector2:
	return flow_dir(hero["pos"], _flow_to(goal))


func _move_hero(dt: float) -> void:
	var dir: Vector2 = move_dir.limit_length(1.0)
	if dir.length() > 0.1:
		hero["face"] = dir.normalized()
		hero["pos"] = _slide(hero["pos"], dir * hero_speed() * dt, HERO_R)
		hero["cd"] = maxf(float(hero["cd"]), 0.12)
	hero["cd"] = float(hero["cd"]) - dt
	## Quieto: dispara al mas cercano (mejor si se le ve).
	if dir.length() <= 0.1 and float(hero["cd"]) <= 0.0:
		var tgt: Dictionary = _target()
		if not tgt.is_empty():
			hero["cd"] = 1.0 / fire_rate()
			var aim: Vector2 = ((tgt["pos"] as Vector2) - (hero["pos"] as Vector2)).normalized()
			hero["face"] = aim
			_shoot(aim)


func _target() -> Dictionary:
	var best: Dictionary = {}
	var bd: float = INF
	var p: Vector2 = hero["pos"]
	for e: Dictionary in enemies:
		if not e["alive"]:
			continue
		var d: float = (e["pos"] as Vector2).distance_to(p)
		if not line_clear(p, e["pos"]):
			d += 600.0
		if d < bd:
			bd = d
			best = e
	return best


## Hay linea limpia para una flecha? (muestras finas y un poco a cada lado: si rozaria una
## esquina, cuenta como tapada).
func line_clear(a: Vector2, b: Vector2) -> bool:
	var n: int = int(a.distance_to(b) / (T * 0.12)) + 1
	var side: Vector2 = (b - a).normalized().orthogonal() * 7.0
	for k: int in range(1, n):
		var q: Vector2 = a.lerp(b, float(k) / float(n))
		for o: Vector2 in [Vector2.ZERO, side, -side]:
			var c: Vector2i = _tile_of(q + o)
			if tiles[c.y][c.x] == "#":
				return false
	return true


func _shoot(aim: Vector2) -> void:
	var dmg: float = damage()
	var multi: int = 1 + int(skills.get("multi", 0))
	var side: Vector2 = aim.orthogonal()
	for k: int in multi:
		var off: float = (float(k) - float(multi - 1) * 0.5) * 16.0
		_arrow((hero["pos"] as Vector2) + side * off, aim, dmg)
	for k: int in int(skills.get("diagonal", 0)):
		_arrow(hero["pos"], aim.rotated(0.5), dmg * 0.8)
		_arrow(hero["pos"], aim.rotated(-0.5), dmg * 0.8)
	if not fast:
		Audio.play("jump", 0.15, -14.0)


func _arrow(at: Vector2, dir: Vector2, dmg: float) -> void:
	arrows.append({"pos": at, "vel": dir * ARROW_SPEED, "dmg": dmg, "bounce": int(skills.get("rebote", 0)), "alive": true})


func _step_arrows(dt: float) -> void:
	var crit: float = gear_bonus("anillo") / 100.0
	for a: Dictionary in arrows:
		if not a["alive"]:
			continue
		var p: Vector2 = a["pos"]
		var n: Vector2 = p + (a["vel"] as Vector2) * dt
		var c: Vector2i = Vector2i(int(floor(n.x / T)), int(floor(n.y / T)))
		if c.x < 0 or c.y < 0 or c.x >= MapRules.ROOM_W or c.y >= MapRules.ROOM_H or tiles[c.y][c.x] == "#":
			if int(a["bounce"]) > 0:
				a["bounce"] = int(a["bounce"]) - 1
				var cx: Vector2i = Vector2i(int(floor(n.x / T)), int(floor(p.y / T)))
				var v: Vector2 = a["vel"]
				if cx.x < 0 or cx.x >= MapRules.ROOM_W or tiles[clampi(cx.y, 0, MapRules.ROOM_H - 1)][clampi(cx.x, 0, MapRules.ROOM_W - 1)] == "#":
					v.x = -v.x
				else:
					v.y = -v.y
				a["vel"] = v
				continue
			a["alive"] = false
			_fx.append({"type": "spark", "at": p, "t": 0.15})
			continue
		a["pos"] = n
		for e: Dictionary in enemies:
			if not e["alive"]:
				continue
			var r: float = float(MapRules.ENEMIES[e["kind"]]["r"])
			if (e["pos"] as Vector2).distance_to(n) <= r + 6.0:
				var dmg: float = float(a["dmg"])
				var is_crit: bool = _rnd.randf() < crit
				if is_crit:
					dmg *= 2.0
				_hurt_enemy(e, dmg, is_crit)
				a["alive"] = false
				break
	var keep: Array[Dictionary] = []
	for a: Dictionary in arrows:
		if a["alive"]:
			keep.append(a)
	arrows = keep


func _hurt_enemy(e: Dictionary, dmg: float, crit: bool) -> void:
	e["hp"] = float(e["hp"]) - dmg
	e["flash"] = 0.08
	_fx.append({"type": "num", "at": (e["pos"] as Vector2) + Vector2(0, -30), "t": 0.6, "text": str(int(dmg)), "crit": crit})
	if float(e["hp"]) <= 0.0:
		e["alive"] = false
		kills += 1
		var info: Dictionary = MapRules.ENEMIES[e["kind"]]
		_fx.append({"type": "puff", "at": e["pos"], "t": 0.4, "r": float(info["r"])})
		hero["xp"] = int(hero["xp"]) + int(info["xp"])
		var heal: float = 3.0 * float(skills.get("robo", 0))
		if heal > 0.0:
			hero["hp"] = minf(max_hp(), float(hero["hp"]) + heal)
		for k: int in (1 if str(e["kind"]) != "boss" else 12):
			drops.append({"pos": (e["pos"] as Vector2) + Vector2(_rnd.randf_range(-18, 18), _rnd.randf_range(-18, 18)), "kind": "coin", "t": 0.0})
		if _rnd.randf() < 0.08:
			drops.append({"pos": e["pos"], "kind": "heart", "t": 0.0})
		if not fast:
			Audio.play("stomp", 0.1, -6.0)
		if int(hero["xp"]) >= xp_need():
			hero["xp"] = int(hero["xp"]) - xp_need()
			hero["lvl"] = int(hero["lvl"]) + 1
			_offer_skills()
		_update_hud()
	elif not fast:
		Audio.play("click", 0.2, -14.0)


func _offer_skills() -> void:
	var pool: Array[String] = MapRules.SKILLS.duplicate()
	choices.clear()
	for k: int in 3:
		var i: int = _rnd.randi_range(0, pool.size() - 1)
		choices.append(pool[i])
		pool.remove_at(i)
	if not fast:
		Audio.play("powerup")
	_show_choices()


func _hurt_hero(dmg: float, from: Vector2) -> void:
	if float(hero["inv"]) > 0.0 or finished:
		return
	if int(hero["shield"]) > 0:
		hero["shield"] = int(hero["shield"]) - 1
		hero["inv"] = 0.5
		_fx.append({"type": "shield", "at": hero["pos"], "t": 0.4})
		return
	hero["hp"] = float(hero["hp"]) - dmg
	hero["inv"] = 0.8
	hero["pos"] = _slide(hero["pos"], ((hero["pos"] as Vector2) - from).normalized() * 18.0, HERO_R)
	if not fast:
		Audio.play("hurt", 0.1, -4.0)
		Juice.shake(0.12)
		Juice.vibrate(20)
	_update_hud()
	if float(hero["hp"]) <= 0.0:
		_lose()


func _step_enemies(dt: float) -> void:
	var hp: Vector2 = hero["pos"]
	for e: Dictionary in enemies:
		if not e["alive"]:
			continue
		var info: Dictionary = MapRules.ENEMIES[e["kind"]]
		var p: Vector2 = e["pos"]
		var r: float = float(info["r"])
		## Para chocar con las paredes todos caben por un pasillo de una casilla.
		var cr: float = minf(r, 24.0)
		var sp: float = float(info["speed"])
		var dmg: float = float(info["dmg"]) * power * (1.0 + 0.06 * float(floor_i))
		e["t"] = float(e["t"]) + dt
		e["cd"] = float(e["cd"]) - dt
		e["flash"] = maxf(0.0, float(e.get("flash", 0.0)) - dt)
		var to_hero: Vector2 = hp - p
		var dist: float = to_hero.length()
		match str(info["ai"]):
			"chase":
				e["pos"] = _slide(p, flow_dir(p, _field) * sp * dt if dist > T else to_hero.normalized() * sp * dt, cr)
			"zigzag":
				## Se lanza en zigzag y cada poco se aparta para volver a lanzarse.
				var away: bool = fmod(float(e["t"]), 3.4) > 2.2
				var z: Vector2 = to_hero.normalized() * (-0.8 if away else 1.0) + to_hero.normalized().orthogonal() * sin(float(e["t"]) * 5.0) * 0.9
				e["pos"] = _slide(p, z.normalized() * sp * dt, cr, true)
			"shoot":
				var mv: Vector2 = Vector2.ZERO
				if dist < 240.0:
					mv = -to_hero.normalized()
				elif dist > 440.0 or not line_clear(p, hp):
					mv = flow_dir(p, _field)
				e["pos"] = _slide(p, mv * sp * dt, cr)
				if float(e["cd"]) <= 0.0 and dist < 700.0 and line_clear(p, hp):
					e["cd"] = float(info["rate"])
					_bullet(p, to_hero.normalized() * 330.0, dmg)
			"slam":
				if float(e["tele"]) > 0.0:
					e["tele"] = float(e["tele"]) - dt
					if float(e["tele"]) <= 0.0:
						_fx.append({"type": "ring", "at": p, "t": 0.3, "r": 130.0})
						if dist <= 130.0 + HERO_R:
							_hurt_hero(dmg, p)
						if not fast:
							Juice.shake(0.15)
				else:
					e["pos"] = _slide(p, flow_dir(p, _field) * sp * dt if dist > T else to_hero.normalized() * sp * dt, cr)
					if dist < 150.0 and float(e["cd"]) <= 0.0:
						e["cd"] = float(info["rate"])
						e["tele"] = 0.9
			"boss":
				_step_boss(e, dt, dmg, to_hero)
		## Contacto.
		if (e["pos"] as Vector2).distance_to(hero["pos"]) < r + HERO_R - 4.0:
			_hurt_hero(dmg, e["pos"])


func _step_boss(e: Dictionary, dt: float, dmg: float, to_hero: Vector2) -> void:
	var info: Dictionary = MapRules.ENEMIES["boss"]
	var p: Vector2 = e["pos"]
	if float(e["dash_t"]) > 0.0:
		e["dash_t"] = float(e["dash_t"]) - dt
		e["pos"] = _slide(p, (e["dash"] as Vector2) * dt, float(info["r"]))
		return
	e["pos"] = _slide(p, to_hero.normalized() * float(info["speed"]) * 0.5 * dt, float(info["r"]))
	## A la mitad de vida llama a dos slimes (una vez).
	if not e["summoned"] and float(e["hp"]) < float(e["max"]) * 0.5:
		e["summoned"] = true
		_spawn("slime", free_near(p + Vector2(-90, 40)))
		_spawn("slime", free_near(p + Vector2(90, 40)))
	if float(e["cd"]) > 0.0:
		return
	e["cd"] = float(info["rate"]) * (0.75 if float(e["hp"]) < float(e["max"]) * 0.5 else 1.0)
	var phase: int = int(e["phase"]) % 3
	e["phase"] = int(e["phase"]) + 1
	match phase:
		0:
			for k: int in 12:
				_bullet(p, Vector2.RIGHT.rotated(TAU * float(k) / 12.0 + float(e["phase"]) * 0.2) * 250.0, dmg)
		1:
			for k: int in 3:
				_bullet(p, to_hero.normalized().rotated((float(k) - 1.0) * 0.2) * 360.0, dmg)
		2:
			e["dash"] = to_hero.normalized() * 420.0
			e["dash_t"] = 0.6
			_fx.append({"type": "ring", "at": p, "t": 0.3, "r": 70.0})


## Centro de la casilla libre mas cercana (para que nada aparezca dentro de una pared).
func free_near(p: Vector2) -> Vector2:
	var c: Vector2i = _tile_of(p)
	for r: int in range(0, 6):
		for dy: int in range(-r, r + 1):
			for dx: int in range(-r, r + 1):
				var n: Vector2i = c + Vector2i(dx, dy)
				if n.x > 0 and n.y > 0 and n.x < MapRules.ROOM_W - 1 and n.y < MapRules.ROOM_H - 1 and tiles[n.y][n.x] == ".":
					return (Vector2(n) + Vector2(0.5, 0.5)) * T
	return p


func _bullet(at: Vector2, vel: Vector2, dmg: float) -> void:
	bullets.append({"pos": at, "vel": vel, "dmg": dmg, "alive": true})


func _step_bullets(dt: float) -> void:
	for b: Dictionary in bullets:
		var n: Vector2 = (b["pos"] as Vector2) + (b["vel"] as Vector2) * dt
		var c: Vector2i = Vector2i(int(floor(n.x / T)), int(floor(n.y / T)))
		if c.x < 0 or c.y < 0 or c.x >= MapRules.ROOM_W or c.y >= MapRules.ROOM_H or tiles[c.y][c.x] == "#":
			b["alive"] = false
			continue
		b["pos"] = n
		if n.distance_to(hero["pos"]) < HERO_R + 8.0:
			b["alive"] = false
			_hurt_hero(float(b["dmg"]), n)
	var keep: Array[Dictionary] = []
	for b: Dictionary in bullets:
		if b["alive"]:
			keep.append(b)
	bullets = keep


func _step_drops(dt: float) -> void:
	var hp: Vector2 = hero["pos"]
	var keep: Array[Dictionary] = []
	for d: Dictionary in drops:
		d["t"] = float(d["t"]) + dt
		var p: Vector2 = d["pos"]
		## Con la sala limpia (o muy cerca) las monedas vuelan hacia el heroe.
		if room_clear() or p.distance_to(hp) < 90.0:
			d["pos"] = p.move_toward(hp, 700.0 * dt)
		if (d["pos"] as Vector2).distance_to(hp) < HERO_R + 10.0:
			if str(d["kind"]) == "coin":
				coins += 1
				if not fast and coins % 3 == 0:
					Audio.play("coin", 0.1, -10.0)
			else:
				hero["hp"] = minf(max_hp(), float(hero["hp"]) + max_hp() * 0.2)
				if not fast:
					Audio.play("powerup", 0.1, -6.0)
			_update_hud()
			continue
		keep.append(d)
	drops = keep
	## Cofre: se abre al tocarlo con la sala limpia.
	if chests.has(cell) and not bool(chests[cell]) and room_clear():
		if hp.distance_to(chest_pos()) < 60.0:
			open_chest()


func chest_pos() -> Vector2:
	return Vector2(MapRules.ROOM_W * 0.5, MapRules.ROOM_H * 0.45) * T


func open_chest() -> void:
	chests[cell] = true
	var g: Dictionary = MapRules.roll_gear(_rnd, floor_i)
	var slot: String = str(g["slot"])
	var names: Dictionary = {"arma": Kit.text("dungeon_weapon", "Arma"), "armadura": Kit.text("dungeon_armor", "Armadura"), "anillo": Kit.text("dungeon_ring", "Anillo")}
	var rar: Array[String] = [Kit.text("dungeon_common", "com\u00fan"), Kit.text("dungeon_rare", "rara"), Kit.text("dungeon_epic", "\u00e9pica"), Kit.text("dungeon_legend", "legendaria")]
	var r: int = int(g["rarity"])
	var better: bool = float(g["bonus"]) > gear_bonus(slot)
	if better:
		var old_max: float = max_hp()
		gear[slot] = g
		if slot == "armadura":
			hero["hp"] = float(hero["hp"]) + (max_hp() - old_max)
		_save_gear()
		_toast_now("%s %s! %s" % [str(names[slot]), rar[r], Kit.text("dungeon_equipped", "Equipada")], MapRules.RARITY_COLORS[r])
	else:
		coins += 10 * (r + 1)
		_toast_now("%s %s: +%d" % [str(names[slot]), rar[r], 10 * (r + 1)], MapRules.RARITY_COLORS[r])
	_fx.append({"type": "chest", "at": chest_pos(), "t": 1.2, "col": MapRules.RARITY_COLORS[r]})
	if not fast:
		Audio.play("powerup")
		Juice.vibrate(30)
	_update_hud()


func _check_door() -> void:
	if not room_clear():
		return
	var p: Vector2 = hero["pos"]
	var side: int = -1
	if p.y < T * 0.35:
		side = 0
	elif p.x > (float(MapRules.ROOM_W) - 0.35) * T:
		side = 1
	elif p.y > (float(MapRules.ROOM_H) - 0.35) * T:
		side = 2
	elif p.x < T * 0.35:
		side = 3
	if side < 0:
		return
	var n: Vector2i = cell + MapRules.DIRS[side]
	if rooms.has(n):
		_enter(n, (side + 2) % 4)
		_update_hud()


# ------------------------------------------------------------------ entrada

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()
		return
	if event is InputEventScreenTouch:
		var t: InputEventScreenTouch = event
		if t.pressed and _touch_id < 0:
			_touch_id = t.index
			_touch_from = t.position
			_touch_at = t.position
		elif not t.pressed and t.index == _touch_id:
			_touch_id = -1
			move_dir = Vector2.ZERO
	elif event is InputEventScreenDrag:
		var d: InputEventScreenDrag = event
		if d.index == _touch_id:
			_touch_at = d.position
			var v: Vector2 = _touch_at - _touch_from
			## El joystick sigue al dedo si se aleja mucho.
			if v.length() > 110.0:
				_touch_from = _touch_at - v.normalized() * 110.0
				v = _touch_at - _touch_from
			move_dir = v / 90.0 if v.length() > 12.0 else Vector2.ZERO


func _draw_stick() -> void:
	if _touch_id < 0:
		return
	_stick.draw_circle(_touch_from, 90.0, Color(1, 1, 1, 0.12))
	_stick.draw_arc(_touch_from, 90.0, 0.0, TAU, 32, Color(1, 1, 1, 0.35), 3.0)
	_stick.draw_circle(_touch_from + (_touch_at - _touch_from).limit_length(90.0), 38.0, Color(1, 1, 1, 0.45))


# ------------------------------------------------------------------ final

func _win() -> void:
	if finished:
		return
	finished = true
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = maxi(0, 20000 - int(time_in_level) * 20) + kills * 50 + coins * 10
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "time": snappedf(time_in_level, 0.1), "deaths": deaths,
		"kills": kills, "hero_level": int(hero["lvl"])})
	Audio.play("win")
	Audio.play_track("victoria", false)
	Juice.burst(self, (hero["pos"] as Vector2), Kit.color("coin", Color.YELLOW), 30, 400.0)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": mini(coins, 99), "coins_total": maxi(coins, 1), "score": score, "record": record})
	await Ads.show_interstitial("level_end")


func stars_earned() -> int:
	if deaths > 0:
		return 1
	return 3 if par <= 0.0 or time_in_level <= par else 2


func _lose() -> void:
	if finished:
		return
	finished = true
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "dungeon", "room": str(cell), "time": snappedf(time_in_level, 0.1), "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("dungeon_lost", "\u00a1Has ca\u00eddo en la mazmorra!"),
		Kit.text("dungeon_fail_hint", "Mu\u00e9vete para esquivar y p\u00e1rate para disparar. El equipo de los cofres se queda contigo."))
	p.closed.connect(retry)


func retry() -> void:
	_reset()


func open_pause() -> void:
	if finished or get_tree().paused or get_node_or_null("PauseMenu") != null:
		return
	_touch_id = -1
	move_dir = Vector2.ZERO
	PauseMenu.open(self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_inside_tree() and not UI.test_mode:
			open_pause()


func bot_state() -> Dictionary:
	return {"pos": hero.get("pos", Vector2.ZERO), "deaths": deaths, "coins": coins, "finished": finished, "failed": failed,
		"stomps": kills, "time": time_in_level, "hp": float(hero.get("hp", 0.0)), "room": cell, "rooms_clear": cleared.size(),
		"hero_level": int(hero.get("lvl", 1))}


# ------------------------------------------------------------------ dibujo

func _draw_world() -> void:
	if tiles.is_empty():
		return
	## Piedra de mazmorra con un toque del color del juego.
	var floor1: Color = Color("#3a3346").lerp(Kit.color("solid", Color("#3a3346")), 0.2)
	var floor2: Color = floor1.lightened(0.06)
	var wall: Color = Color("#5a5068")
	var wall_top: Color = Color("#7d7290")
	var t: float = time_in_level
	for y: int in MapRules.ROOM_H:
		for x: int in MapRules.ROOM_W:
			var r: Rect2 = Rect2(Vector2(x, y) * T, Vector2(T, T))
			var ch: String = tiles[y][x]
			var edge: bool = x == 0 or y == 0 or x == MapRules.ROOM_W - 1 or y == MapRules.ROOM_H - 1
			if ch == "#":
				_world.draw_rect(r, wall)
				_world.draw_rect(Rect2(r.position, Vector2(T, T * 0.55)), wall_top)
				_world.draw_line(r.position + Vector2(0, T * 0.55), r.position + Vector2(T, T * 0.55), wall.darkened(0.3), 2.0)
				if not edge:
					_world.draw_rect(Rect2(r.position + Vector2(6, T - 8.0), Vector2(T - 12.0, 10.0)), Color(0, 0, 0, 0.3))
				continue
			_world.draw_rect(r, floor1 if (x + y) % 2 == 0 else floor2)
			if edge:
				## Puerta: rejas si esta cerrada, luz si esta abierta.
				if room_clear():
					_world.draw_rect(r.grow(-6.0), Color(1.0, 0.85, 0.4, 0.25 + 0.15 * sin(t * 4.0)))
				else:
					for k: int in 4:
						var bx: float = r.position.x + 8.0 + float(k) * 14.0
						_world.draw_line(Vector2(bx, r.position.y + 4.0), Vector2(bx, r.end.y - 4.0), Color("#8a8f9a"), 4.0)
	## Antorchas en las paredes.
	for p: Vector2 in [Vector2(2.5, 0.6), Vector2(8.5, 0.6), Vector2(0.5, 4.5), Vector2(10.5, 10.5)]:
		var q: Vector2 = p * T
		_world.draw_circle(q, 26.0 + sin(t * 9.0 + p.x) * 3.0, Color(1.0, 0.6, 0.2, 0.18))
		_world.draw_circle(q, 7.0, Color("#ffcf5a"))
	if chests.has(cell):
		var cp: Vector2 = chest_pos()
		var opened: bool = bool(chests[cell])
		_world.draw_rect(Rect2(cp - Vector2(30, 18), Vector2(60, 40)), Color("#8a5a2b"))
		_world.draw_rect(Rect2(cp - Vector2(30, 30 if not opened else 40), Vector2(60, 14)), Color("#b07a3c"))
		_world.draw_rect(Rect2(cp - Vector2(6, 10), Vector2(12, 12)), Color("#ffd23f"))
		if not opened and room_clear():
			_world.draw_arc(cp, 46.0 + sin(t * 5.0) * 4.0, 0.0, TAU, 24, Color(1, 0.85, 0.3, 0.6), 3.0)
	for d: Dictionary in drops:
		var dp: Vector2 = d["pos"]
		if str(d["kind"]) == "coin":
			_world.draw_circle(dp, 8.0, Color("#ffd23f"))
			_world.draw_circle(dp, 4.0, Color("#fff1a6"))
		else:
			_world.draw_circle(dp + Vector2(-5, -2), 7.0, Color("#ff5d6c"))
			_world.draw_circle(dp + Vector2(5, -2), 7.0, Color("#ff5d6c"))
			_world.draw_colored_polygon(PackedVector2Array([dp + Vector2(-12, 0), dp + Vector2(12, 0), dp + Vector2(0, 12)]), Color("#ff5d6c"))
	for e: Dictionary in enemies:
		if e["alive"]:
			_draw_enemy(e, t)
	_draw_hero(t)
	for a: Dictionary in arrows:
		var ap: Vector2 = a["pos"]
		var v: Vector2 = (a["vel"] as Vector2).normalized()
		_world.draw_line(ap - v * 22.0, ap, Color("#f3e3b5"), 4.0)
		_world.draw_circle(ap, 3.5, Color("#ffffff"))
	for b: Dictionary in bullets:
		_world.draw_circle(b["pos"], 10.0, Color(1.0, 0.3, 0.5, 0.35))
		_world.draw_circle(b["pos"], 6.0, Color("#ff4d7a"))
	for f: Dictionary in _fx:
		var fp: Vector2 = f["at"]
		match str(f["type"]):
			"num":
				var col: Color = Color("#ffd23f") if bool(f["crit"]) else Color.WHITE
				_text(fp + Vector2(0, -40.0 * (0.6 - float(f["t"]))), str(f["text"]) + ("!" if bool(f["crit"]) else ""), 26 if bool(f["crit"]) else 20, col)
			"puff":
				_world.draw_circle(fp, float(f["r"]) * (1.6 - float(f["t"])), Color(0.8, 0.8, 0.9, float(f["t"])))
			"spark":
				_world.draw_circle(fp, 6.0, Color(1, 1, 0.7, float(f["t"]) * 5.0))
			"ring":
				_world.draw_arc(fp, float(f["r"]), 0.0, TAU, 32, Color(1.0, 0.5, 0.2, float(f["t"]) * 3.0), 8.0)
			"shield":
				_world.draw_arc(fp, 36.0, 0.0, TAU, 24, Color(0.5, 0.8, 1.0, float(f["t"]) * 2.0), 6.0)
			"chest":
				var cc: Color = f["col"]
				_world.draw_circle(fp + Vector2(0, -20), 60.0 * (1.2 - float(f["t"])), Color(cc, float(f["t"]) * 0.5))


func _text(at: Vector2, s: String, size: int, col: Color) -> void:
	var wd: float = _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p: Vector2 = at - Vector2(wd * 0.5, 0.0)
	for o: Vector2 in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)]:
		_world.draw_string(_font, p + o, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.85))
	_world.draw_string(_font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _draw_hero(t: float) -> void:
	var p: Vector2 = hero["pos"]
	var f: Vector2 = hero["face"]
	var blink: bool = float(hero["inv"]) > 0.0 and int(t * 20.0) % 2 == 0
	_world.draw_circle(p + Vector2(0, 18), 20.0, Color(0, 0, 0, 0.3))
	if int(hero["shield"]) > 0:
		_world.draw_arc(p, 32.0, 0.0, TAU, 24, Color(0.5, 0.8, 1.0, 0.6), 3.0)
	var body: Color = Kit.color("accent", Color("#3f8cff"))
	if blink:
		body = body.lightened(0.6)
	if _hero_art != null:
		var bow2: Vector2 = p + f * 34.0
		_world.draw_arc(bow2, 14.0, f.angle() - 1.2, f.angle() + 1.2, 10, Color("#8a5a2b"), 4.0)
		return
	_world.draw_circle(p, HERO_R, body)
	_world.draw_circle(p + Vector2(0, -6), 13.0, Color("#f1c9a0"))
	_world.draw_arc(p + Vector2(0, -8), 14.0, PI, TAU, 12, body.darkened(0.35), 5.0)
	_world.draw_circle(p + Vector2(f.x * 5.0 - 4.0, -6.0 + f.y * 3.0), 2.5, Color("#1a1a1a"))
	_world.draw_circle(p + Vector2(f.x * 5.0 + 4.0, -6.0 + f.y * 3.0), 2.5, Color("#1a1a1a"))
	## Arco en la direccion de la mirada.
	var bow: Vector2 = p + f * 26.0
	_world.draw_arc(bow, 14.0, f.angle() - 1.2, f.angle() + 1.2, 10, Color("#8a5a2b"), 4.0)


func _draw_enemy(e: Dictionary, t: float) -> void:
	var p: Vector2 = e["pos"]
	var kind: String = str(e["kind"])
	var r: float = float(MapRules.ENEMIES[kind]["r"])
	var ec: Color = Kit.color("enemy", Color("#ff7a3c"))
	_world.draw_circle(p + Vector2(0, r * 0.7), r * 0.9, Color(0, 0, 0, 0.3))
	if kind == "golem" and float(e["tele"]) > 0.0:
		_world.draw_circle(p, 130.0, Color(1.0, 0.3, 0.2, 0.18 + 0.2 * (0.9 - float(e["tele"]))))
		_world.draw_arc(p, 130.0, 0.0, TAU, 32, Color(1.0, 0.3, 0.2, 0.7), 3.0)
	match kind if not e.has("art") else "":
		"slime":
			var sq: float = 1.0 + sin(t * 8.0 + float(e["t"])) * 0.12
			_world.draw_set_transform(p, 0.0, Vector2(sq, 2.0 - sq))
			_world.draw_circle(Vector2.ZERO, r, Color("#5ad16a"))
			_world.draw_circle(Vector2(-8, -6), 4.0, Color("#1a1a1a"))
			_world.draw_circle(Vector2(8, -6), 4.0, Color("#1a1a1a"))
			_world.draw_circle(Vector2(-8, -12), 6.0, Color(1, 1, 1, 0.4))
			_world.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"bat":
			var flap: float = sin(t * 20.0) * 10.0
			_world.draw_colored_polygon(PackedVector2Array([p, p + Vector2(-26, -8 + flap), p + Vector2(-14, 6)]), Color("#6a4a8a"))
			_world.draw_colored_polygon(PackedVector2Array([p, p + Vector2(26, -8 + flap), p + Vector2(14, 6)]), Color("#6a4a8a"))
			_world.draw_circle(p, r * 0.7, Color("#4a3a6a"))
			_world.draw_circle(p + Vector2(-4, -2), 2.5, Color("#ff4d4d"))
			_world.draw_circle(p + Vector2(4, -2), 2.5, Color("#ff4d4d"))
		"archer":
			_world.draw_circle(p, r, Color("#8a6a3a"))
			_world.draw_circle(p + Vector2(0, -6), 12.0, Color("#9adf6a"))
			_world.draw_colored_polygon(PackedVector2Array([p + Vector2(-14, -12), p + Vector2(0, -32), p + Vector2(14, -12)]), Color("#5a3a20"))
			_world.draw_circle(p + Vector2(-4, -6), 2.5, Color("#1a1a1a"))
			_world.draw_circle(p + Vector2(4, -6), 2.5, Color("#1a1a1a"))
		"golem":
			_world.draw_rect(Rect2(p - Vector2(r, r * 0.9), Vector2(r * 2.0, r * 1.8)), Color("#7d7f86"))
			_world.draw_rect(Rect2(p - Vector2(r, r * 0.9), Vector2(r * 2.0, r * 0.5)), Color("#9a9ca3"))
			_world.draw_circle(p + Vector2(-10, -8), 5.0, Color("#ffb03a"))
			_world.draw_circle(p + Vector2(10, -8), 5.0, Color("#ffb03a"))
		"boss":
			var pulse: float = 1.0 + sin(t * 3.0) * 0.04
			_world.draw_circle(p, r * pulse, ec.darkened(0.3))
			_world.draw_circle(p, r * 0.8 * pulse, ec)
			for k: int in 5:
				var a: float = -PI * 0.5 + (float(k) - 2.0) * 0.35
				_world.draw_colored_polygon(PackedVector2Array([p + Vector2(cos(a), sin(a)) * r * 0.8, p + Vector2(cos(a), sin(a)) * r * 1.35,
					p + Vector2(cos(a + 0.12), sin(a + 0.12)) * r * 0.85]), Color("#ffd23f"))
			_world.draw_circle(p + Vector2(-16, -6), 8.0, Color("#fff1a6"))
			_world.draw_circle(p + Vector2(16, -6), 8.0, Color("#fff1a6"))
			_world.draw_circle(p + Vector2(-16, -6), 4.0, Color("#1a1a1a"))
			_world.draw_circle(p + Vector2(16, -6), 4.0, Color("#1a1a1a"))
	if float(e["hp"]) < float(e["max"]):
		var wd: float = maxf(40.0, r * 1.8)
		var bar: Rect2 = Rect2(p + Vector2(-wd * 0.5, -r * (1.7 if e.has("art") else 1.0) - 16.0), Vector2(wd, 7.0))
		_world.draw_rect(bar, Color(0, 0, 0, 0.6))
		_world.draw_rect(Rect2(bar.position, Vector2(wd * clampf(float(e["hp"]) / float(e["max"]), 0.0, 1.0), 7.0)), Color("#ff5d5d"))


func _draw_minimap() -> void:
	if rooms.is_empty():
		return
	var minc: Vector2i = Vector2i(999, 999)
	var maxc: Vector2i = Vector2i(-999, -999)
	for c: Variant in rooms:
		var v: Vector2i = c
		minc = Vector2i(mini(minc.x, v.x), mini(minc.y, v.y))
		maxc = Vector2i(maxi(maxc.x, v.x), maxi(maxc.y, v.y))
	var span: Vector2 = Vector2(maxc - minc + Vector2i.ONE)
	var cs: float = minf(_map_view.size.x / span.x, _map_view.size.y / span.y)
	_map_view.draw_rect(Rect2(Vector2.ZERO, span * cs), Color(0, 0, 0, 0.45))
	for c: Variant in rooms:
		var v: Vector2i = c
		var near: bool = visited.has(v)
		for dir: Vector2i in MapRules.DIRS:
			if visited.has(v + dir):
				near = true
		if not near:
			continue
		var r: Rect2 = Rect2(Vector2(v - minc) * cs, Vector2(cs, cs)).grow(-3.0)
		var col: Color = Color(1, 1, 1, 0.25)
		if visited.has(v):
			col = Color(1, 1, 1, 0.6)
		if str(rooms[v]) == "B":
			col = Color("#ff5d5d")
		elif str(rooms[v]) == "T" and not bool(chests.get(v, false)):
			col = Color("#ffd23f")
		if v == cell:
			col = Kit.color("accent", Color("#3f8cff"))
		_map_view.draw_rect(r, col)
