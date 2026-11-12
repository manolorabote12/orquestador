extends Node2D
## RPG por turnos: tu heroe contra oleadas de enemigos del juego, eligiendo cada accion.
## 1 - Te toca: Atacar (al enemigo marcado; toca otro para cambiar), Especial (a todos, cuesta 2
##     de energia), Pocion (+40 % de vida) o Defender (mitad de dano y +1 de energia).
## 2 - Despues atacan los enemigos. El jefe avisa cuando va a cargar un golpe doble: defiendete.
## 3 - Ganas al acabar con todas las oleadas; pierdes si tu vida llega a 0.
## Reglas y numeros: kit/turns/turns_logic.gd. Nivel: {"map" (oleadas), "hero_hp", "hero_atk",
##   "potions", "mult" (fuerza de los enemigos)}.
## Modo equipo (game.json o nivel -> "rpg": ver kit/turns/turns_party.gd): varios heroes con
## habilidades, turnos por velocidad (barra de turnos arriba), elementos, estados y boton AUTO.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

## 13 nov: personajes mas grandes y mas abajo (la critica: «el arquero es pequeno y queda relegado al
## borde; debajo, una franja de suelo vacia»).
const HERO_AT: Vector2 = Vector2(-205.0, 120.0)
const ENEMY_X: float = 175.0
const ACTOR_SCALE: float = 1.3

var rows: Array = []
var finished: bool = false
var failed: bool = false
var deaths: int = 0
var time_in_level: float = 0.0
var coins: int = 0
var coins_total: int = 0
var fast: bool = false
var auto_retry: bool = false
var result_panel: ResultPanel

var state: Dictionary = {}
var selected: int = 0
## "player" (te toca), "busy" (animando) o "end".
var phase: String = "busy"
var hero_hp: float = 100.0
var hero_atk: float = 20.0
var potions: int = 2
var mult: float = 1.0

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _hero: Node2D
var _enemy_nodes: Array[Node2D] = []
var _bars: Node2D
var _camera: Camera2D
var _wave_label: Label
var _btn: Dictionary = {}
var _arts: Dictionary = {}
## Modo equipo.
var party_mode: bool = false
var auto: bool = false
var active: Dictionary = {}
var target_uid: int = -1
var ally_uid: int = -1
var _plevel: Dictionary = {}
var _nodes: Dictionary = {}
var _order: Control
var _skill_btns: Array[Button] = []
var _potion_btn: Button
var _auto_btn: Button
var _who: Label


func _ready() -> void:
	var lv: Dictionary = Kit.current_level()
	if not lv.has("rpg") and Kit.param("rpg", null) is Dictionary:
		lv = lv.duplicate()
		lv["rpg"] = Kit.param("rpg", {})
	if TurnsParty.wanted(lv):
		_party_ready(lv)
		return
	rows = lv.get("map", ["W", "WW"])
	hero_hp = Kit.player_hp(float(lv.get("hero_hp", 100.0))) * (1.0 + 0.1 * float(Save.upgrade_level("heart")))
	hero_atk = float(lv.get("hero_atk", 20.0))
	potions = int(lv.get("potions", 2))
	mult = float(lv.get("mult", 1.0))
	for k: Array in [["W", "walker"], ["S", "spiky"], ["F", "flyer"]]:
		var id: String = str(Kit.param("art.enemies." + str(k[1]), ""))
		var e: Dictionary = Kit.sprite_entry(id) if id != "" else {}
		_arts[k[0]] = e if not e.is_empty() else Kit.sprite_by_role("enemigo")
	var boss: Dictionary = Kit.sprite_by_role("jefe")
	_arts["B"] = boss if not boss.is_empty() else _arts["W"]
	RenderingServer.set_default_clear_color(Kit.color("sky", Color("#1b2a41")))
	## Paisaje de fondo (cielo, montes, arboles y suelo con los colores del juego).
	var ground: Scenery = Scenery.make(Rect2(-900.0, -800.0, 1800.0, 1900.0), 200.0, Kit.level_index + 3)
	ground.name = "Ground"
	## Con fondo pintado por la IA solo se dibuja el suelo (el cielo y los montes los pone el fondo).
	ground.only_ground = Look.has_level_backdrop()
	add_child(ground)
	_hero = _actor(Kit.sprite_by_role("jugador"), 210.0 * ACTOR_SCALE, false)
	_hero.position = HERO_AT
	add_child(_hero)
	_bars = Node2D.new()
	_bars.name = "Bars"
	_bars.z_index = 10
	_bars.draw.connect(_draw_bars)
	add_child(_bars)
	_camera = Camera2D.new()
	add_child(_camera)
	_camera.make_current()
	Juice.register_camera(_camera)
	var vp: Vector2 = get_viewport_rect().size
	_camera.zoom = Vector2.ONE * minf(vp.x / 730.0, 1.6)
	## La accion abajo, cerca de los botones; arriba queda el cielo (y el fondo pintado).
	_camera.position = Vector2(0.0, 120.0 - 0.26 * vp.y / _camera.zoom.y)
	_build_hud()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "turns", "waves": rows.size(), "enemies": coins_total})


func bot_script() -> String:
	return "res://qa/turns_bot.gd"


func _actor(art: Dictionary, h: float, flip: bool) -> Node2D:
	var rig: Node2D = Node2D.new()
	## Sombra suave en el suelo: el personaje pisa el escenario en vez de flotar.
	var shadow: Polygon2D = Polygon2D.new()
	var pts: PackedVector2Array = PackedVector2Array()
	for k: int in 24:
		var a: float = TAU * float(k) / 24.0
		pts.append(Vector2(cos(a) * h * 0.32, sin(a) * h * 0.07))
	shadow.polygon = pts
	shadow.color = Color(0.0, 0.0, 0.0, 0.32)
	shadow.name = "Shadow"
	rig.add_child(shadow)
	if not art.is_empty():
		var spr: AnimatedSprite2D = SpriteKit.animado(art, h, "idle", true)
		spr.flip_h = flip
		rig.add_child(spr)
		if not flip:
			Skins.apply(spr)
	else:
		var body: Polygon2D = Polygon2D.new()
		body.polygon = LevelBuilder._circle(h * 0.3, 20)
		body.position = Vector2(0.0, -h * 0.3)
		body.color = Kit.color("danger", Color("#ff6b5b")) if flip else Kit.color("accent", Color.ORANGE)
		rig.add_child(body)
	return rig


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
	col.add_child(top)
	_wave_label = Label.new()
	_wave_label.name = "Wave"
	_wave_label.theme_type_variation = "HeaderLabel"
	_wave_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_wave_label)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)
	var grow: Control = Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(grow)
	var grid: GridContainer = GridContainer.new()
	grid.name = "Actions"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	col.add_child(grid)
	for a: Array in [["attack", "play"], ["special", "star"], ["heal", "heart"], ["defend", "close"]]:
		var b: Button = UI.make_button("", a[0] == "attack", str(a[1]))
		b.name = "Btn_" + str(a[0])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0.0, 96.0)
		var act_name: String = a[0]
		b.pressed.connect(func() -> void: act(act_name, selected))
		grid.add_child(b)
		_btn[act_name] = b


func _reset() -> void:
	finished = false
	failed = false
	time_in_level = 0.0
	coins = 0
	_rng.seed = 900 + Kit.level_index * 53
	state = TurnsLogic.new_state(rows, hero_hp, hero_atk, potions, mult)
	coins_total = 0
	for w: Variant in rows:
		coins_total += str(w).length()
	_hero.visible = true
	_hero.modulate = Color.WHITE
	TurnsLogic.next_wave(state)
	_spawn_wave()
	phase = "player"
	_update_hud()


func _spawn_wave() -> void:
	for n: Node2D in _enemy_nodes:
		n.queue_free()
	_enemy_nodes.clear()
	var list: Array = state["enemies"]
	for i: int in list.size():
		var e: Dictionary = list[i]
		var big: bool = str(e["kind"]) == "B"
		var n: Node2D = _actor(_arts.get(str(e["kind"]), {}), (250.0 if big else 150.0) * ACTOR_SCALE, true)
		n.name = "Enemy%d" % i
		var y: float = 120.0 if list.size() == 1 else lerpf(-30.0, 170.0, float(i) / float(maxi(list.size() - 1, 1)))
		n.position = Vector2(ENEMY_X - 45.0 + 125.0 * float(i % 2), y)
		n.z_index = int(y / 10.0)
		add_child(n)
		_enemy_nodes.append(n)
		n.modulate = Color(1, 1, 1, 0)
		n.create_tween().tween_property(n, "modulate:a", 1.0, _t(0.3))
	selected = 0
	_select_valid()


func _select_valid() -> void:
	var list: Array = state["enemies"]
	if selected < list.size() and bool(list[selected]["alive"]):
		return
	for i: int in list.size():
		if bool(list[i]["alive"]):
			selected = i
			return


func _t(s: float) -> float:
	return s * (0.15 if fast else 1.0)


func waiting_player() -> bool:
	return phase == "player" and not finished and not failed and not get_tree().paused


## Accion del jugador. Devuelve false si no se puede ahora.
func act(action: String, target: int = -1) -> bool:
	if not waiting_player() or not TurnsLogic.can(state, action):
		return false
	phase = "busy"
	if target >= 0:
		selected = target
	_run_turn(action)
	return true


func _run_turn(action: String) -> void:
	var ev: Array = TurnsLogic.hero_act(state, action, selected, _rng)
	await _show_hero(action, ev)
	if not is_inside_tree():
		return
	if bool(state["lost"]):
		_lose()
		return
	if TurnsLogic.alive(state).is_empty():
		if not TurnsLogic.next_wave(state):
			_finish()
			return
		UI.float_text(self, Vector2(0.0, -200.0), Kit.text("turns_wave", "Oleada {n} de {t}").format({"n": int(state["wave"]) + 1, "t": rows.size()}), Color("#ffe066"), 40)
		_spawn_wave()
		await get_tree().create_timer(_t(0.5)).timeout
		phase = "player"
		_update_hud()
		return
	_select_valid()
	_update_hud()
	await get_tree().create_timer(_t(0.25)).timeout
	var ev2: Array = TurnsLogic.enemies_act(state, _rng)
	await _show_enemies(ev2)
	if not is_inside_tree():
		return
	if bool(state["lost"]):
		_lose()
		return
	phase = "player"
	_update_hud()


func _show_hero(action: String, ev: Array) -> void:
	if action == "attack" or action == "special":
		var tw: Tween = _hero.create_tween()
		tw.tween_property(_hero, "position", HERO_AT + Vector2(120.0, -10.0), _t(0.12))
		tw.tween_property(_hero, "position", HERO_AT, _t(0.18))
		Audio.play("shoot" if action == "special" else "stomp", 0.1)
	for e: Variant in ev:
		var d: Dictionary = e
		match str(d["type"]):
			"hit":
				var n: Node2D = _enemy_nodes[int(d["target"])]
				Juice.burst(self, n.position + Vector2(0, -80), Color("#ffd447"), 8, 240.0)
				Juice.squash(n, Vector2(1.2, 0.8))
				UI.float_text(self, n.position + Vector2(0, -170), str(int(round(float(d["amount"])))), Color("#ffe066"), 36)
			"ko":
				var n2: Node2D = _enemy_nodes[int(d["target"])]
				coins += 1
				n2.create_tween().tween_property(n2, "modulate:a", 0.0, _t(0.35))
				Audio.play("coin")
			"heal":
				UI.float_text(self, HERO_AT + Vector2(0, -300), "+%d" % int(round(float(d["amount"]))), Color("#5fd35f"), 38)
				Juice.sparkle(self, HERO_AT + Vector2(0, -100), Color("#5fd35f"), 10, 200.0)
				Audio.play("powerup")
			"guard":
				UI.float_text(self, HERO_AT + Vector2(0, -300), Kit.text("turns_guard", "\u00a1En guardia!"), Color("#7fd0ff"), 32)
			"thorns":
				UI.float_text(self, HERO_AT + Vector2(0, -270), "-%d" % int(round(float(d["amount"]))), UI.colors["peligro"], 30)
	_bars.queue_redraw()
	await get_tree().create_timer(_t(0.45)).timeout


func _show_enemies(ev: Array) -> void:
	for e: Variant in ev:
		var d: Dictionary = e
		var n: Node2D = _enemy_nodes[int(d["from"])]
		if str(d["type"]) == "charge":
			UI.float_text(self, n.position + Vector2(0, -260), Kit.text("turns_charge", "\u00a1Va a cargar un golpe doble!"), Color("#ff9f43"), 30)
			continue
		var tw: Tween = n.create_tween()
		tw.tween_property(n, "position", n.position + Vector2(-110.0, 0.0), _t(0.1))
		tw.tween_property(n, "position", n.position, _t(0.15))
		Juice.squash(_hero, Vector2(0.85, 1.12))
		Juice.shake(0.35 if str(d["type"]) == "heavy" else 0.15)
		UI.float_text(self, HERO_AT + Vector2(randf_range(-30.0, 30.0), -220.0), "-%d" % int(round(float(d["amount"]))), UI.colors["peligro"], 34)
		Audio.play("hurt", 0.1, -6.0)
		_bars.queue_redraw()
		await get_tree().create_timer(_t(0.3)).timeout


func _update_hud() -> void:
	_wave_label.text = Kit.text("turns_wave", "Oleada {n} de {t}").format({"n": mini(int(state["wave"]) + 1, rows.size()), "t": rows.size()})
	## Con hueco a la izquierda para el icono (como los botones de Ajustes).
	(_btn["attack"] as Button).text = "    " + Kit.text("turns_attack", "Atacar")
	(_btn["special"] as Button).text = "    " + Kit.text("turns_special", "Especial") + " %d/%d" % [int(state["energy"]), TurnsLogic.ENERGY_MAX]
	(_btn["heal"] as Button).text = "    " + Kit.text("turns_heal", "Poci\u00f3n") + " x%d" % int(state["potions"])
	(_btn["defend"] as Button).text = "    " + Kit.text("turns_defend", "Defender")
	for k: String in _btn.keys():
		(_btn[k] as Button).disabled = phase != "player" or not TurnsLogic.can(state, k)
	_bars.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()
		return
	if UI.test_mode:
		return
	var at: Vector2 = Vector2.INF
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		at = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and not DisplayServer.is_touchscreen_available():
		at = (event as InputEventMouseButton).position
	if at == Vector2.INF:
		return
	var world: Vector2 = get_canvas_transform().affine_inverse() * at
	if party_mode:
		_party_touch(world)
		return
	## Tocar un enemigo lo marca como objetivo.
	var list: Array = state.get("enemies", [])
	for i: int in _enemy_nodes.size():
		if i < list.size() and bool(list[i]["alive"]) and world.distance_to(_enemy_nodes[i].position + Vector2(0, -90)) < 140.0:
			selected = i
			_bars.queue_redraw()
			return


func _process(delta: float) -> void:
	if not finished and not failed and not get_tree().paused:
		time_in_level += delta


func _draw_bars() -> void:
	if state.is_empty():
		return
	if party_mode:
		_draw_party_bars()
		return
	_bar(HERO_AT + Vector2(0, -250.0 * ACTOR_SCALE), float(state["hp"]) / float(state["max_hp"]), Color("#5fd35f"), 200.0)
	var list: Array = state["enemies"]
	for i: int in mini(list.size(), _enemy_nodes.size()):
		var e: Dictionary = list[i]
		if not bool(e["alive"]):
			continue
		var top: float = (-280.0 if str(e["kind"]) == "B" else -185.0) * ACTOR_SCALE
		var p: Vector2 = _enemy_nodes[i].position + Vector2(0, top)
		_bar(p, float(e["hp"]) / float(e["max_hp"]), Color("#ff5a4f"), 150.0)
		if i == selected and phase == "player":
			## Flecha sobre el objetivo marcado.
			_bars.draw_colored_polygon(PackedVector2Array([p + Vector2(-16, -34), p + Vector2(16, -34), p + Vector2(0, -12)]), Color("#ffd447"))


func _bar(c: Vector2, f: float, col: Color, w: float) -> void:
	_bars.draw_rect(Rect2(c - Vector2(w * 0.5 + 3.0, 3.0), Vector2(w + 6.0, 20.0)), Color(0, 0, 0, 0.6))
	_bars.draw_rect(Rect2(c - Vector2(w * 0.5, 0.0), Vector2(w * clampf(f, 0.0, 1.0), 14.0)), col)


# ------------------------------------------------------------------ final

func stars_earned() -> int:
	var left: float = _hp_ratio()
	if left >= 0.6:
		return 3
	if left >= 0.3:
		return 2
	return 1


func _finish() -> void:
	finished = true
	phase = "end"
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = coins * 150 + int(_hp_now()) * 10 + int(state["potions"]) * 200
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "hp": int(_hp_now()), "potions": int(state["potions"]),
		"kills": coins, "coins": coins, "stars": stars})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


func _lose() -> void:
	failed = true
	phase = "end"
	deaths += 1
	if _hero != null:
		_hero.create_tween().tween_property(_hero, "modulate:a", 0.3, _t(0.4))
	QA.log_event("death", {"cause": "turns", "wave": int(state["wave"]), "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("turns_lose", "\u00a1Derrota!"),
		Kit.text("turns_fail_hint", "Caiste en la oleada {n}. Usa las pociones y defi\u00e9ndete del jefe. \u00a1Otra vez!").format({"n": int(state["wave"]) + 1}))
	p.closed.connect(retry)


func retry() -> void:
	if party_mode:
		_party_reset()
		return
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
	return {"deaths": deaths, "coins": coins, "finished": finished, "failed": failed, "stomps": coins,
		"hp": _hp_now() if not state.is_empty() else 0.0, "wave": int(state.get("wave", 0)), "potions": int(state.get("potions", 0)), "party": party_mode}


func capture_delays() -> Vector2:
	return Vector2(3.0, 1.0)


# ------------------------------------------------------------------ modo equipo

const ELEM_COL: Dictionary = {"fire": Color("#ff7043"), "water": Color("#42a5f5"), "nature": Color("#66bb6a"),
	"light": Color("#ffe082"), "dark": Color("#9575cd"), "": Color("#b0bec5")}
const STATUS_COL: Dictionary = {"poison": Color("#9ccc65"), "burn": Color("#ff7043"), "regen": Color("#81c784"), "stun": Color("#ffee58"),
	"taunt": Color("#ef5350"), "atk_up": Color("#ffa726"), "atk_down": Color("#8d6e63"), "def_up": Color("#42a5f5"), "def_down": Color("#ab47bc")}
const STATUS_NAME: Dictionary = {"poison": "Veneno", "burn": "Quemado", "regen": "Regenera", "stun": "Aturdido", "taunt": "Provoca",
	"atk_up": "Ataque +", "atk_down": "Ataque -", "def_up": "Defensa +", "def_down": "Defensa -"}


func _hp_now() -> float:
	if not party_mode:
		return float(state["hp"])
	var t: float = 0.0
	for h: Dictionary in state["heroes"]:
		t += float(h["hp"])
	return t


func _hp_ratio() -> float:
	if not party_mode:
		return float(state["hp"]) / float(state["max_hp"])
	var mx: float = 0.0
	for h: Dictionary in state["heroes"]:
		mx += float(h["max_hp"])
	return _hp_now() / maxf(1.0, mx)


func _party_ready(lv: Dictionary) -> void:
	party_mode = true
	_plevel = lv
	rows = lv.get("map", ["W"])
	for k: Array in [["W", "walker"], ["S", "spiky"], ["F", "flyer"]]:
		var id: String = str(Kit.param("art.enemies." + str(k[1]), ""))
		var e: Dictionary = Kit.sprite_entry(id) if id != "" else {}
		_arts[k[0]] = e if not e.is_empty() else Kit.sprite_by_role("enemigo")
	var boss: Dictionary = Kit.sprite_by_role("jefe")
	_arts["B"] = boss if not boss.is_empty() else _arts["W"]
	RenderingServer.set_default_clear_color(Kit.color("sky", Color("#1b2a41")))
	var ground: Scenery = Scenery.make(Rect2(-900.0, -800.0, 1800.0, 2000.0), 300.0, Kit.level_index + 3)
	ground.name = "Ground"
	ground.only_ground = Look.has_level_backdrop()
	add_child(ground)
	_bars = Node2D.new()
	_bars.name = "Bars"
	_bars.z_index = 50
	_bars.draw.connect(_draw_bars)
	add_child(_bars)
	_camera = Camera2D.new()
	add_child(_camera)
	_camera.make_current()
	Juice.register_camera(_camera)
	var vp: Vector2 = get_viewport_rect().size
	_camera.zoom = Vector2.ONE * minf(vp.x / 820.0, 1.5)
	_camera.position = Vector2(0.0, 20.0)
	_build_party_hud()
	_party_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "turns", "waves": rows.size(), "enemies": coins_total, "party": (state["heroes"] as Array).size()})


func _build_party_hud() -> void:
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
	col.add_theme_constant_override("separation", 10)
	safe.add_child(col)
	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top)
	_wave_label = Label.new()
	_wave_label.name = "Wave"
	_wave_label.theme_type_variation = "HeaderLabel"
	_wave_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_wave_label)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)
	## Barra de turnos: quien va a actuar (el primero, el de ahora).
	_order = Control.new()
	_order.name = "Order"
	_order.custom_minimum_size = Vector2(0.0, 64.0)
	_order.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_order.draw.connect(_draw_order)
	col.add_child(_order)
	var grow: Control = Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(grow)
	_who = Label.new()
	_who.name = "Who"
	_who.add_theme_font_size_override("font_size", 30)
	_who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_who)
	var grid: GridContainer = GridContainer.new()
	grid.name = "Skills"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	col.add_child(grid)
	for k: int in 4:
		var b: Button = UI.make_button("", k == 0)
		b.name = "Btn_skill_%d" % k
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0.0, 92.0)
		b.add_theme_font_size_override("font_size", 26)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var kk: int = k
		b.pressed.connect(func() -> void: act_skill(kk))
		grid.add_child(b)
		_skill_btns.append(b)
	var low: HBoxContainer = HBoxContainer.new()
	low.add_theme_constant_override("separation", 12)
	col.add_child(low)
	_potion_btn = UI.make_button("", false, "heart")
	_potion_btn.name = "Btn_potion"
	_potion_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_potion_btn.custom_minimum_size = Vector2(0.0, UI.MIN_TOUCH)
	_potion_btn.pressed.connect(act_potion)
	low.add_child(_potion_btn)
	_auto_btn = UI.make_button("AUTO", false, "play")
	_auto_btn.name = "Btn_auto"
	_auto_btn.toggle_mode = true
	_auto_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_auto_btn.custom_minimum_size = Vector2(0.0, UI.MIN_TOUCH)
	_auto_btn.toggled.connect(func(on: bool) -> void:
		auto = on
		if on and waiting_player():
			_auto_turn())
	low.add_child(_auto_btn)


func _party_reset() -> void:
	finished = false
	failed = false
	time_in_level = 0.0
	coins = 0
	_rng.seed = 900 + Kit.level_index * 53
	state = TurnsParty.new_state(_plevel)
	coins_total = 0
	for w: Variant in rows:
		coins_total += str(w).length()
	for n: Variant in _nodes.values():
		(n as Node).queue_free()
	_nodes.clear()
	TurnsParty.next_wave(state)
	_spawn_party()
	active = {}
	phase = "busy"
	_party_hud()
	_party_loop.call_deferred()


func _unit_name(u: Dictionary) -> String:
	var d: Dictionary = (state["cat"]["heroes" if str(u["side"]) == "hero" else "enemies"] as Dictionary).get(str(u["id"]), {})
	var nm: String = str(d.get("name", u["id"]))
	return Kit.text("rpg_" + str(u["id"]), nm) if str(u["side"]) == "hero" and _stock_name("heroes", str(u["id"]), nm) else nm


func _skill_name(sid: String) -> String:
	var nm: String = str(TurnsParty.skill(state, sid).get("name", sid))
	return Kit.text("rpg_" + sid, nm) if _stock_name("skills", sid, nm) else nm


## El nombre es el de serie (tiene traduccion) o lo invento el juego (se usa tal cual)?
func _stock_name(sec: String, id: String, nm: String) -> bool:
	var data: Dictionary = TurnsParty.data()
	if str((data["default"][sec] as Dictionary).get(id, {}).get("name", "")) == nm:
		return true
	for p: Dictionary in (data["presets"] as Dictionary).values():
		if str((p.get(sec, {}) as Dictionary).get(id, {}).get("name", "")) == nm:
			return true
	return false


func _spawn_party() -> void:
	for u: Dictionary in (state["heroes"] as Array) + (state["enemies"] as Array):
		var uid: int = int(u["uid"])
		if _nodes.has(uid):
			continue
		var n: Node2D = _party_actor(u)
		n.name = ("Hero%d" if str(u["side"]) == "hero" else "Enemy%d") % uid
		add_child(n)
		_nodes[uid] = n
		if str(u["side"]) == "enemy":
			n.modulate = Color(1, 1, 1, 0)
			n.create_tween().tween_property(n, "modulate:a", 1.0, _t(0.3))
	_layout_party(true)


## Sitio de cada uno: tus heroes a la izquierda, los enemigos a la derecha (con lineup, el que
## pelea delante y los demas esperando detras, mas pequenos).
func _layout_party(instant: bool = false) -> void:
	for sd: String in ["hero", "enemy"]:
		var arr: Array = TurnsParty.side(state, sd)
		var front: Array = TurnsParty.fighters(state, arr)
		var bench: Array = TurnsParty.living(arr).filter(func(x: Dictionary) -> bool: return not front.has(x))
		var sx: float = -1.0 if sd == "hero" else 1.0
		for i: int in front.size():
			var y: float = 160.0 if front.size() == 1 else lerpf(-200.0, 270.0, float(i) / float(front.size() - 1))
			_place(front[i], Vector2(sx * (190.0 + 90.0 * float(i % 2)), y), 1.0, instant)
		for j: int in bench.size():
			_place(bench[j], Vector2(sx * 320.0, -160.0 + 110.0 * float(j)), 0.6, instant)
	_bars.queue_redraw()


func _place(u: Dictionary, at: Vector2, sc: float, instant: bool) -> void:
	var n: Node2D = _nodes.get(int(u["uid"])) as Node2D
	if n == null:
		return
	n.z_index = int(at.y / 10.0) + 30
	if instant:
		n.position = at
		n.scale = Vector2.ONE * sc
	else:
		var tw: Tween = n.create_tween().set_parallel(true)
		tw.tween_property(n, "position", at, _t(0.25))
		tw.tween_property(n, "scale", Vector2.ONE * sc, _t(0.25))


func _party_actor(u: Dictionary) -> Node2D:
	var enemy: bool = str(u["side"]) == "enemy"
	var h: float = (220.0 if bool(u["boss"]) else 130.0) if enemy else 140.0
	var art: Dictionary = {}
	if enemy:
		art = _arts.get(str(u["id"]), _arts.get("W", {}))
	elif int(u["uid"]) == 1 and str(u["look"]) != "beast":
		art = Kit.sprite_by_role("jugador")
	if not art.is_empty():
		var rig: Node2D = _actor(art, h, enemy)
		if enemy and not ["W", "S", "F", "B"].has(str(u["id"])):
			rig.modulate = Color.WHITE.lerp(ELEM_COL.get(str(u["element"]), Color.WHITE), 0.45)
		return rig
	## Dibujado con formas: cuerpo del color de su elemento y su arma (o bicho con orejas).
	var fig: Node2D = Node2D.new()
	var col: Color = ELEM_COL.get(str(u["element"]), Color("#b0bec5"))
	var lk: String = str(u["look"]) if not enemy else "beast"
	var flip: float = -1.0 if enemy else 1.0
	fig.draw.connect(func() -> void:
		var s: float = h / 140.0
		if lk == "beast":
			fig.draw_circle(Vector2(0, -40) * s, 40.0 * s, col)
			fig.draw_colored_polygon(PackedVector2Array([Vector2(-30, -62) * s, Vector2(-18, -100) * s, Vector2(-8, -70) * s]), col.darkened(0.2))
			fig.draw_colored_polygon(PackedVector2Array([Vector2(30, -62) * s, Vector2(18, -100) * s, Vector2(8, -70) * s]), col.darkened(0.2))
			fig.draw_circle(Vector2(14 * flip, -48) * s, 7.0 * s, Color.WHITE)
			fig.draw_circle(Vector2(16 * flip, -48) * s, 3.5 * s, Color.BLACK)
			fig.draw_circle(Vector2(-6 * flip, -48) * s, 7.0 * s, Color.WHITE)
			fig.draw_circle(Vector2(-4 * flip, -48) * s, 3.5 * s, Color.BLACK)
			return
		fig.draw_rect(Rect2(Vector2(-22, -78) * s, Vector2(44, 70) * s), col)
		fig.draw_rect(Rect2(Vector2(-18, -10) * s, Vector2(14, 10) * s), col.darkened(0.4))
		fig.draw_rect(Rect2(Vector2(4, -10) * s, Vector2(14, 10) * s), col.darkened(0.4))
		fig.draw_circle(Vector2(0, -100) * s, 24.0 * s, Color("#ffd7b5"))
		fig.draw_circle(Vector2(8, -102) * s, 3.5 * s, Color.BLACK)
		match lk:
			"sword":
				fig.draw_line(Vector2(30, -40) * s, Vector2(52, -110) * s, Color("#e0e0e0"), 7.0 * s)
				fig.draw_line(Vector2(22, -50) * s, Vector2(40, -44) * s, Color("#8d6e63"), 6.0 * s)
			"staff":
				fig.draw_line(Vector2(32, 0) * s, Vector2(40, -120) * s, Color("#8d6e63"), 6.0 * s)
				fig.draw_circle(Vector2(40, -126) * s, 12.0 * s, col.lightened(0.4))
			"cross":
				fig.draw_rect(Rect2(Vector2(28, -86) * s, Vector2(10, 40) * s), Color("#fff8e1"))
				fig.draw_rect(Rect2(Vector2(18, -74) * s, Vector2(30, 10) * s), Color("#fff8e1"))
			"bow":
				fig.draw_arc(Vector2(26, -60) * s, 40.0 * s, -PI * 0.45, PI * 0.45, 12, Color("#8d6e63"), 6.0 * s)
				fig.draw_line(Vector2(26 + 40 * cos(PI * 0.45), -60 - 40 * sin(PI * 0.45)) * s, Vector2(26 + 40 * cos(PI * 0.45), -60 + 40 * sin(PI * 0.45)) * s, Color.WHITE, 2.0 * s)
		fig.draw_colored_polygon(PackedVector2Array([Vector2(-26, -112) * s, Vector2(0, -136) * s, Vector2(26, -112) * s]), col.darkened(0.25)))
	return fig


func _party_hud() -> void:
	if state.is_empty() or _wave_label == null:
		return
	_wave_label.text = Kit.text("turns_wave", "Oleada {n} de {t}").format({"n": mini(int(state["wave"]) + 1, rows.size()), "t": rows.size()})
	var mine: bool = phase == "player" and not active.is_empty()
	_who.text = Kit.text("rpg_turn", "Turno de {x}").format({"x": _unit_name(active)}) if mine else ""
	if not mine:
		_who.text = "AUTO" if auto else ""
	var sk: Array = active.get("skills", []) if mine else []
	(_skill_btns[0].get_parent() as Control).visible = mine
	for k: int in _skill_btns.size():
		var b: Button = _skill_btns[k]
		b.visible = k < sk.size()
		if k < sk.size():
			var sid: String = str(sk[k])
			var cd: int = int(active["cd"].get(sid, 0))
			b.text = _skill_name(sid) + (" (%d)" % cd if cd > 0 else "")
			b.disabled = cd > 0
		else:
			b.text = ""
			b.disabled = true
	_potion_btn.text = "    " + Kit.text("turns_heal", "Poci\u00f3n") + " x%d" % int(state["potions"])
	_potion_btn.disabled = not mine or int(state["potions"]) <= 0
	_order.queue_redraw()
	_bars.queue_redraw()


func _draw_order() -> void:
	if state.is_empty():
		return
	var list: Array = TurnsParty.preview_order(state, 8)
	if phase == "player" and not active.is_empty():
		list.push_front(active)
	var x: float = 0.0
	var f: Font = UI.font
	for k: int in mini(list.size(), 8):
		var u: Dictionary = list[k]
		var r: float = 26.0 if k == 0 else 20.0
		var c: Vector2 = Vector2(x + r, 32.0)
		_order.draw_circle(c, r + 3.0, Color("#5fd35f") if str(u["side"]) == "hero" else Color("#ff5a4f"))
		_order.draw_circle(c, r, ELEM_COL.get(str(u["element"]), Color.GRAY).darkened(0.2))
		var ini: String = _unit_name(u).substr(0, 1).to_upper()
		_order.draw_string(f, c + Vector2(-r, 9.0), ini, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 24, Color.WHITE)
		x += r * 2.0 + 10.0


func _draw_party_bars() -> void:
	for u: Dictionary in (state["heroes"] as Array) + (state["enemies"] as Array):
		var n: Node2D = _nodes.get(int(u["uid"])) as Node2D
		if n == null or not bool(u["alive"]):
			continue
		var big: bool = bool(u["boss"])
		var w: float = (150.0 if big else 120.0) * n.scale.x
		var p: Vector2 = n.position + Vector2(0.0, (-260.0 if big else -175.0) * n.scale.y)
		var enemy: bool = str(u["side"]) == "enemy"
		_bar(p, float(u["hp"]) / float(u["max_hp"]), Color("#ff5a4f") if enemy else Color("#5fd35f"), w)
		if float(u["shield"]) > 0.0:
			_bars.draw_rect(Rect2(p - Vector2(w * 0.5, 0.0), Vector2(w * clampf(float(u["shield"]) / float(u["max_hp"]), 0.0, 1.0), 6.0)), Color("#90caf9"))
		_bars.draw_circle(p + Vector2(-w * 0.5 - 16.0, 7.0), 10.0, ELEM_COL.get(str(u["element"]), Color.GRAY))
		var sx: float = -w * 0.5
		for s: String in u["status"]:
			_bars.draw_rect(Rect2(p + Vector2(sx, 22.0), Vector2(16.0, 16.0)), STATUS_COL.get(s, Color.WHITE))
			sx += 20.0
		if str(u["warn"]) != "":
			_bars.draw_string(UI.font, p + Vector2(-w * 0.5, -14.0), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color("#ff9f43"))
		if phase == "player" and not active.is_empty() and int(u["uid"]) == int(active["uid"]):
			_bars.draw_colored_polygon(PackedVector2Array([p + Vector2(-16, -40), p + Vector2(16, -40), p + Vector2(0, -16)]), Color("#ffd447"))
		if phase == "player" and enemy and int(u["uid"]) == _target().get("uid", -1):
			_bars.draw_arc(n.position + Vector2(0, 6), 60.0 * n.scale.x, 0.0, TAU, 32, Color("#ff5a4f"), 5.0)


func _target() -> Dictionary:
	var al: Array = TurnsParty.fighters(state, state["enemies"])
	for e: Dictionary in al:
		if int(e["uid"]) == target_uid:
			return e
	return TurnsParty.lowest(al) if not al.is_empty() else {}


func _ally() -> Dictionary:
	for h: Dictionary in TurnsParty.fighters(state, state["heroes"]):
		if int(h["uid"]) == ally_uid:
			return h
	return {}


func _party_touch(world: Vector2) -> void:
	for u: Dictionary in (state["heroes"] as Array) + (state["enemies"] as Array):
		var n: Node2D = _nodes.get(int(u["uid"])) as Node2D
		if n != null and bool(u["alive"]) and world.distance_to(n.position + Vector2(0, -70)) < 100.0:
			if str(u["side"]) == "enemy":
				target_uid = int(u["uid"])
			else:
				ally_uid = int(u["uid"])
			_bars.queue_redraw()
			return


## El bucle de la batalla: actua quien llega antes; si es tuyo (y no hay AUTO), espera.
func _party_loop() -> void:
	while is_inside_tree() and not finished and not failed:
		if bool(state["lost"]):
			_lose()
			return
		if bool(state["won"]):
			_finish()
			return
		var u: Dictionary = TurnsParty.next_actor(state)
		if u.is_empty():
			return
		var s: Dictionary = TurnsParty.start_turn(state, u)
		await _show_party(s["events"])
		if not is_inside_tree():
			return
		if bool(s["skip"]):
			await _end_party_turn(u)
			continue
		if str(u["side"]) == "hero" and not auto:
			active = u
			phase = "player"
			_party_hud()
			return
		await get_tree().create_timer(_t(0.3)).timeout
		if not is_inside_tree():
			return
		await _do_party(u, TurnsParty.think(state, u))


func _do_party(u: Dictionary, a: Array) -> void:
	if a.is_empty():
		await _end_party_turn(u)
		return
	var ev: Array = TurnsParty.use_potion(state, u, a[2]) if str(a[0]) == "potion" else TurnsParty.use_skill(state, u, str(a[1]), a[2], _rng)
	await _show_party(ev)
	if is_inside_tree():
		await _end_party_turn(u)


func _end_party_turn(u: Dictionary) -> void:
	await _show_party(TurnsParty.end_turn(state, u))
	if not is_inside_tree() or bool(state["lost"]):
		return
	if TurnsParty.wave_clear(state):
		if TurnsParty.next_wave(state):
			UI.float_text(self, Vector2(0.0, -200.0), Kit.text("turns_wave", "Oleada {n} de {t}").format({"n": int(state["wave"]) + 1, "t": rows.size()}), Color("#ffe066"), 40)
			_spawn_party()
			await get_tree().create_timer(_t(0.5)).timeout
	else:
		_layout_party()
	_party_hud()


## Tu heroe usa la habilidad k de su lista (al enemigo marcado o al aliado tocado).
func act_skill(k: int) -> bool:
	if not party_mode or not waiting_player() or active.is_empty() or k >= (active["skills"] as Array).size():
		return false
	var sid: String = str(active["skills"][k])
	if int(active["cd"].get(sid, 0)) > 0:
		return false
	var tg: Dictionary = _ally() if str(TurnsParty.skill(state, sid).get("target", "enemy")) == "ally" else _target()
	_player_does(["skill", sid, tg])
	return true


func act_potion() -> bool:
	if not party_mode or not waiting_player() or int(state["potions"]) <= 0:
		return false
	var low: Dictionary = _ally()
	_player_does(["potion", "", low if not low.is_empty() else TurnsParty.lowest(TurnsParty.living(state["heroes"]))])
	return true


func _auto_turn() -> void:
	if waiting_player() and not active.is_empty():
		_player_does(TurnsParty.think(state, active))


func _player_does(a: Array) -> void:
	var u: Dictionary = active
	phase = "busy"
	active = {}
	_party_hud()
	await _do_party(u, a)
	if is_inside_tree():
		_party_loop()


func _show_party(ev: Array) -> void:
	if ev.is_empty():
		return
	for e: Variant in ev:
		var d: Dictionary = e
		var u: Dictionary = d.get("unit", {})
		var n: Node2D = _nodes.get(int(u.get("uid", -1))) as Node2D if not u.is_empty() else null
		var at: Vector2 = (n.position if n != null else Vector2.ZERO) + Vector2(randf_range(-20.0, 20.0), -200.0 * (n.scale.y if n != null else 1.0))
		match str(d["type"]):
			"skill":
				UI.float_text(self, at + Vector2(0, -40), _skill_name(str(d["skill"])), Color("#ffe066"), 30)
				if n != null:
					var dir: float = 1.0 if str(u["side"]) == "hero" else -1.0
					var home: Vector2 = n.position
					var tw: Tween = n.create_tween()
					tw.tween_property(n, "position", home + Vector2(70.0 * dir, -6.0), _t(0.1))
					tw.tween_property(n, "position", home, _t(0.15))
				Audio.play("shoot", 0.1, -8.0)
				await get_tree().create_timer(_t(0.2)).timeout
			"hit", "poison", "burn", "thorns":
				var col: Color = {"poison": Color("#9ccc65"), "burn": Color("#ff7043"), "thorns": Color("#ef9a9a")}.get(str(d["type"]), Color("#ff5a4f"))
				UI.float_text(self, at, "-%d" % int(round(float(d["amount"]))), col, 34)
				if n != null:
					Juice.squash(n, Vector2(1.15, 0.85))
				if str(d["type"]) == "hit":
					Audio.play("stomp", 0.1, -6.0)
					Juice.shake(0.12)
			"heal":
				if float(d["amount"]) >= 1.0:
					UI.float_text(self, at, "+%d" % int(round(float(d["amount"]))), Color("#5fd35f"), 32)
					if n != null:
						Juice.sparkle(self, n.position + Vector2(0, -80), Color("#5fd35f"), 6, 160.0)
			"shield":
				UI.float_text(self, at, Kit.text("rpg_shield", "Escudo"), Color("#90caf9"), 28)
			"status":
				var st_id: String = str(d["status"])
				UI.float_text(self, at + Vector2(0, 40), Kit.text("rpg_st_" + st_id, STATUS_NAME.get(st_id, st_id)), STATUS_COL.get(st_id, Color.WHITE), 26)
			"stunned":
				UI.float_text(self, at, Kit.text("rpg_st_stun", "Aturdido"), STATUS_COL["stun"], 28)
			"warn":
				UI.float_text(self, at + Vector2(0, -60), Kit.text("rpg_warn", "\u00a1Prepara {x}!").format({"x": _skill_name(str(d["skill"]))}), Color("#ff9f43"), 30)
			"potion":
				Audio.play("powerup")
			"ko":
				if n != null:
					n.create_tween().tween_property(n, "modulate:a", 0.0, _t(0.35))
				if str(u["side"]) == "enemy":
					coins += 1
					Audio.play("coin")
		_bars.queue_redraw()
	await get_tree().create_timer(_t(0.35)).timeout
