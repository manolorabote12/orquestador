extends Node2D
## Battle royale desde arriba: salta del avion (o toca el minimapa para elegir donde caer), coge
## armas, chalecos y curas, y sobrevive dentro de la zona hasta quedar entre los ultimos.
## Mando izquierdo: moverse. Mando derecho: apuntar y disparar (un toque rapido apunta solo al
## rival mas cercano). Reglas, bots y analizador en royale_map.gd.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const MapRules = preload("res://kit/royale/royale_map.gd")
const T: float = 64.0
const RARITY: Array = [Color("#c9ced6"), Color("#c9ced6"), Color("#4fd27a"), Color("#4aa8ff"), Color("#b36bff")]
const ITEM_NAMES: Dictionary = {"punos": "Pu\u00f1os", "pistola": "Pistola", "metralleta": "Metralleta", "escopeta": "Escopeta",
	"fusil": "Fusil", "francotirador": "Francotirador", "chaleco1": "Chaleco ligero", "chaleco2": "Chaleco", "chaleco3": "Chaleco pesado",
	"venda": "Venda", "botiquin": "Botiqu\u00edn"}

var level: Dictionary = {}
var st: Dictionary = {}
var finished: bool = false
var failed: bool = false
var deaths: int = 0
var time_in_level: float = 0.0
var coins: int = 0
var coins_total: int = 0
var fast: bool = false
var auto_retry: bool = false
var result_panel: ResultPanel
var par: float = 0.0

var _font: Font
var _world: Node2D
var _camera: Camera2D
var _hud: Control
var _mini: Control
var _top_lbl: Label
var _zone_lbl: Label
var _jump_btn: Button
var _heal_btn: Button
var _bot: bool = false
var _think: float = 0.0
var _t: float = 0.0
var _move_id: int = -1
var _move_o: Vector2 = Vector2.ZERO
var _move_v: Vector2 = Vector2.ZERO
var _aim_id: int = -1
var _aim_o: Vector2 = Vector2.ZERO
var _aim_v: Vector2 = Vector2.ZERO
var _aim_t: float = 0.0
var _auto_fire: float = 0.0
var _fx: Array = []
var _tracers: Array = []
var _feed: Array = []
var _shake: float = 0.0
var _hurt: float = 0.0
## Vista 3D opcional (game.json -> "view": "3d"): solo dibuja, la logica sigue en 2D.
var view3d: Node3D = null
## En directo (Online.arena_match con modo "royale"): sala, canal y quien mueve los bots.
var online: Dictionary = {}
var host: bool = false
var net: RealtimeChannel = null
var reported: bool = false
var placed: int = 0
var _send_acc: float = 0.0
var _start_ms: int = 0
const NET_RATE: float = 0.125
const NET_TIMEOUT: float = 8.0


func _ready() -> void:
	level = Kit.current_level()
	par = float(level.get("par", 180))
	RenderingServer.set_default_clear_color(Color("#2f7fb8"))
	_font = UI.theme.get_font("font", "Label") if UI.theme != null else ThemeDB.fallback_font
	_world = Node2D.new()
	_world.name = "World"
	_world.draw.connect(_draw_world)
	add_child(_world)
	_camera = Camera2D.new()
	add_child(_camera)
	_camera.make_current()
	if str(Online.arena_match.get("modo", "")) == "royale":
		online = Online.arena_match.duplicate(true)
	_build_hud()
	_reset()
	if str(Kit.param("view", "2d")) == "3d":
		view3d = load("res://kit/royale/royale_view3d.gd").new()
		add_child(view3d)
		view3d.call("setup", self)
		_world.visible = false
	if not online.is_empty():
		_net_open()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "royale", "bots": int(level.get("bots", 15))})


func bot_script() -> String:
	return "res://qa/royale_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(14.0, 3.0)


func wants_backdrop() -> bool:
	return false


func _reset() -> void:
	finished = false
	failed = false
	if online.is_empty():
		st = MapRules.new_state(level)
	else:
		_net_state_setup()
	coins = 0
	coins_total = (st["agents"] as Array).size() - 1
	time_in_level = 0.0
	_feed = []
	_fx = []
	_tracers = []
	_camera.position = MapRules.plane_pos(st)
	_jump_btn.visible = true
	_refresh()


# ------------------------------------------------------------------ interfaz

func _build_hud() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "Hud"
	layer.layer = 20
	add_child(layer)
	_hud = Control.new()
	_hud.theme = UI.theme
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.draw.connect(_draw_hud)
	layer.add_child(_hud)
	var safe: MarginContainer = UI.safe_root(_hud, 14.0)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col: VBoxContainer = VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(col)
	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top)
	var left: VBoxContainer = VBoxContainer.new()
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(left)
	_top_lbl = _label(30)
	_top_lbl.name = "Info"
	left.add_child(_top_lbl)
	_zone_lbl = _label(22)
	_zone_lbl.name = "Zone"
	left.add_child(_zone_lbl)
	## Que el texto parta linea y no empuje el minimapa ni la pausa fuera de la pantalla.
	for l: Label in [_top_lbl, _zone_lbl]:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mini = Control.new()
	_mini.name = "Minimap"
	_mini.custom_minimum_size = Vector2(190, 190)
	_mini.mouse_filter = Control.MOUSE_FILTER_STOP
	_mini.draw.connect(_draw_mini)
	_mini.gui_input.connect(_mini_input)
	top.add_child(_mini)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(spacer)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	col.add_child(row)
	_jump_btn = UI.make_button(Kit.text("br_jump", "\u00a1Saltar!"), true)
	_jump_btn.name = "BtnJump"
	_jump_btn.custom_minimum_size = Vector2(300, 100)
	_jump_btn.add_theme_font_size_override("font_size", 36)
	_jump_btn.pressed.connect(_jump)
	row.add_child(_jump_btn)
	_heal_btn = UI.make_button(Kit.text("br_heal", "Curar"))
	_heal_btn.name = "BtnHeal"
	_heal_btn.custom_minimum_size = Vector2(200, 84)
	_heal_btn.add_theme_font_size_override("font_size", 26)
	_heal_btn.pressed.connect(_heal)
	row.add_child(_heal_btn)
	var pad: Control = Control.new()
	pad.custom_minimum_size = Vector2(0, 250)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(pad)


func _label(size_px: int) -> Label:
	var l: Label = Label.new()
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 7)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func item_name(id: String) -> String:
	return Kit.text("br_i_" + id, str(ITEM_NAMES.get(id, id)))


func _refresh() -> void:
	if st.is_empty() or _top_lbl == null:
		return
	var me: Dictionary = st["agents"][0]
	coins = int(me["kills"])
	_top_lbl.text = "%s %d   %s %d   %s %d" % [Kit.text("br_left", "Quedan"), MapRules.alive_count(st), Kit.text("br_kills", "Bajas"), int(me["kills"]),
		Kit.text("br_top", "Meta: top"), int(st["top"])]
	var ph: int = int(st["phase"])
	if float(st["time"]) < MapRules.PLANE_T:
		_zone_lbl.text = Kit.text("br_plane", "Toca el mapa para elegir d\u00f3nde caer")
	elif ph >= 0 and ph < MapRules.PHASES.size():
		var wait: float = float(MapRules.PHASES[ph][0]) - float(st["phase_t"])
		_zone_lbl.text = (Kit.text("br_zone_in", "La zona se cierra en %ds") % ceili(wait)) if wait > 0.0 else Kit.text("br_zone_now", "\u00a1La zona se est\u00e1 cerrando!")
	var heals: Dictionary = me["heals"]
	var nh: int = int(heals.get("venda", 0)) + int(heals.get("botiquin", 0))
	_heal_btn.text = "%s (%d)" % [Kit.text("br_heal", "Curar"), nh]
	_heal_btn.disabled = nh == 0 or not bool(me["landed"])
	_heal_btn.visible = bool(me["landed"])
	_jump_btn.visible = not bool(me["landed"])


# ------------------------------------------------------------------ acciones

func can_act() -> bool:
	return not finished and is_inside_tree() and not get_tree().paused


func bot_step() -> void:
	_bot = true


func _jump() -> void:
	if can_act():
		MapRules.drop(st, st["agents"][0])
		_refresh()


func _heal() -> void:
	if can_act() and MapRules.start_heal(st, st["agents"][0]):
		_sfx("powerup")


func _mini_input(ev: InputEvent) -> void:
	## Durante el vuelo, tocar el minimapa elige el sitio donde caer.
	if ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed or ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
		var me: Dictionary = st["agents"][0]
		if bool(me["landed"]):
			return
		var lp: Vector2 = (ev as InputEventScreenTouch).position if ev is InputEventScreenTouch else (ev as InputEventMouseButton).position
		var q: Vector2 = lp / _mini.size * Vector2(int(st["w"]), int(st["h"])) * T
		me["land_at"] = q
		me["glide"] = true
		MapRules.drop(st, me)
		_refresh()


func _sfx(n: String, vol: float = -10.0) -> void:
	if not fast:
		Audio.play(n, 0.1, vol)


# ------------------------------------------------------------------ bucle

func _physics_process(delta: float) -> void:
	_t += delta
	_shake = maxf(0.0, _shake - delta * 2.0)
	_hurt = maxf(0.0, _hurt - delta)
	if finished:
		_world.queue_redraw()
		return
	if fast and auto_retry:
		_bot = true
	## En directo: todos empiezan a la vez (cuenta atras de la sala).
	if not online.is_empty() and Time.get_ticks_msec() < _start_ms:
		_zone_lbl.text = Kit.text("arena_starts", "Empieza en {s} s").format({"s": ceili(float(_start_ms - Time.get_ticks_msec()) / 1000.0)})
		if view3d != null:
			view3d.call("sync", delta)
		_world.queue_redraw()
		return
	var steps: int = 4 if fast and online.is_empty() else 1
	var me: Dictionary = st["agents"][0]
	for k: int in steps:
		if finished or get_tree().paused:
			break
		if _bot:
			me["skill"] = 1.0
			me["cautious"] = true
			me["glide"] = true
			if not bool(me["landed"]):
				MapRules.bot_me(st)
			else:
				_think -= delta
				if _think <= 0.0:
					_think = 0.25
					MapRules.think(st, me)
		else:
			_human(me, delta)
		MapRules.step(st, delta)
		time_in_level += delta
		if net != null:
			MapRules.net_timeouts(st, NET_TIMEOUT)
			_net_send(delta)
		_events()
		if bool(st["over"]):
			_end()
			break
	_refresh()
	## Musica: sube cuando quedan pocos, cuando estas fuera de la zona o hay tiros cerca.
	var left: float = float(MapRules.alive_count(st)) / float(maxi(1, (st["agents"] as Array).size()))
	var outside: bool = (me["p"] as Vector2).distance_to(st["zone_c"]) > float(st["zone_r"])
	Audio.set_intensity(1.0 if outside or _hurt > 0.0 or int(me["target"]) >= 0 else lerpf(1.0, 0.5, left))
	var target: Vector2 = me["p"] if bool(me["landed"]) else MapRules.plane_pos(st)
	_camera.position = _camera.position.lerp(target, minf(1.0, delta * 8.0)) if not fast else target
	_camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake * 14.0
	if view3d != null:
		view3d.call("sync", delta)
	else:
		_world.queue_redraw()
	_hud.queue_redraw()
	_mini.queue_redraw()


func _human(me: Dictionary, delta: float) -> void:
	var kb: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	me["move"] = _move_v if _move_v != Vector2.ZERO else kb
	_auto_fire = maxf(0.0, _auto_fire - delta)
	if _aim_id >= 0 and _aim_v.length() > 0.25:
		me["aim"] = _aim_v.normalized()
		me["fire"] = true
	elif _auto_fire > 0.0:
		var e: int = MapRules.visible_enemy(st, me, float(MapRules.WEAPONS[str(me["weapon"])]["range"]))
		if e >= 0:
			me["aim"] = ((st["agents"][e]["p"] as Vector2) - (me["p"] as Vector2)).normalized()
			me["fire"] = true
		else:
			me["fire"] = false
	else:
		me["fire"] = false
		if _move_v.length() > 0.2:
			me["aim"] = _move_v.normalized()


func _events() -> void:
	var cam: Vector2 = _camera.position
	for e: Dictionary in st["events"]:
		if net != null:
			_net_event(e)
		var near: bool = (e["p"] as Vector2).distance_to(cam) < 900.0
		match str(e["kind"]):
			"shot":
				if near and not fast:
					var a: Dictionary = st["agents"][int(e["id"])]
					_tracers.append({"a": e["p"], "b": (e["p"] as Vector2) + (a["aim"] as Vector2) * 70.0, "t": 0.06})
					if int(e["id"]) == 0 or (e["p"] as Vector2).distance_to(cam) < 500.0:
						_sfx("shoot", -14.0 if int(e["id"]) == 0 else -22.0)
			"hit":
				if int(e["id"]) == 0:
					_hurt = 0.25
					_shake = maxf(_shake, 0.4)
					Juice.vibrate(20)
				if near and not fast and (int(e["id"]) == 0 or int(e.get("by", -1)) == 0):
					UI.float_text(_world, (e["p"] as Vector2) - Vector2(0, 40), str(int(e["dmg"])), Color("#ffe14d") if int(e["id"]) != 0 else Color("#ff5a5a"), 26)
			"dead":
				var by: int = int(e.get("by", -1))
				_feed.append({"t": 4.0, "text": "%s  >  %s" % [_who(by), _who(int(e["id"]))], "me": by == 0 or int(e["id"]) == 0})
				if near and not fast:
					for n: int in 10:
						_fx.append({"p": e["p"], "v": Vector2.from_angle(randf() * TAU) * randf_range(60, 240), "t": 0.5, "c": Color("#ff7a5a")})
				if by == 0:
					_sfx("stomp")
					Juice.vibrate(40)
					if not fast:
						UI.float_text(_world, (e["p"] as Vector2) - Vector2(0, 70), Kit.text("br_down", "\u00a1Eliminado!"), Color("#ffd54a"), 34)
			"pick":
				if int(e["id"]) == 0:
					_sfx("coin", -12.0)
					if not fast:
						var it: String = str(e["item"])
						UI.float_text(_world, (e["p"] as Vector2) - Vector2(0, 60), item_name(it), _rarity_col(it), 28)
			"land":
				if int(e["id"]) == 0:
					_sfx("land")
			"healed":
				if int(e["id"]) == 0:
					_sfx("powerup")
	(st["events"] as Array).clear()


func _who(id: int) -> String:
	if id < 0:
		return Kit.text("br_zone", "La zona")
	if id == 0:
		return Kit.text("br_you", "T\u00fa")
	return str(st["agents"][id]["name"])


func _rarity_col(item: String) -> Color:
	if MapRules.WEAPONS.has(item):
		return RARITY[int(MapRules.WEAPONS[item]["tier"])]
	if item.begins_with("chaleco"):
		return RARITY[int(item.substr(7)) + 1]
	return Color("#ff8fa0")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()
		return
	if not can_act():
		return
	var size: Vector2 = get_viewport().get_visible_rect().size
	if event is InputEventScreenTouch:
		var te: InputEventScreenTouch = event
		if te.pressed:
			_bot = false
			if te.position.x < size.x * 0.5 and _move_id < 0:
				_move_id = te.index
				_move_o = te.position
				_move_v = Vector2.ZERO
			elif te.position.x >= size.x * 0.5 and _aim_id < 0:
				_aim_id = te.index
				_aim_o = te.position
				_aim_v = Vector2.ZERO
				_aim_t = _t
		else:
			if te.index == _move_id:
				_move_id = -1
				_move_v = Vector2.ZERO
			elif te.index == _aim_id:
				_aim_id = -1
				## Toque rapido: apuntado automatico un momento.
				if _t - _aim_t < 0.25 and _aim_v.length() < 0.25:
					_auto_fire = 0.6
				_aim_v = Vector2.ZERO
	elif event is InputEventScreenDrag:
		var dr: InputEventScreenDrag = event
		if dr.index == _move_id:
			_move_v = ((dr.position - _move_o) / 110.0).limit_length(1.0)
		elif dr.index == _aim_id:
			_aim_v = ((dr.position - _aim_o) / 90.0).limit_length(1.0)


# ------------------------------------------------------------------ final

func _end() -> void:
	if not online.is_empty():
		_net_end(int(st["place"]))
		return
	if bool(st["won"]):
		_finish()
	else:
		_lose()


func _finish() -> void:
	if finished:
		return
	finished = true
	var me: Dictionary = st["agents"][0]
	coins = int(me["kills"])
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = 1000 * maxi(1, coins_total + 1 - int(st["place"])) + 250 * int(me["kills"])
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "time": snappedf(time_in_level, 0.1), "deaths": deaths, "place": int(st["place"])})
	Audio.play("win")
	Audio.play_track("victoria", false)
	if not fast:
		UI.float_text(_world, (me["p"] as Vector2) - Vector2(0, 120), Kit.text("br_win", "\u00a1Top %d!") % int(st["place"]), Color("#ffd54a"), 48)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


func stars_earned() -> int:
	if int(st.get("place", 99)) == 1:
		return 3
	return 2 if deaths == 0 else 1


func _lose() -> void:
	if finished:
		return
	finished = true
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "royale", "place": int(st["place"]), "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry.call_deferred()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("br_lost", "Has quedado el n\u00famero %d") % int(st["place"]),
		Kit.text("br_fail_hint", "Coge un arma antes de pelear, cura detr\u00e1s de un muro y no te quedes fuera de la zona."))
	p.closed.connect(retry)


func retry() -> void:
	if not online.is_empty():
		return
	_reset()


func open_pause() -> void:
	if not online.is_empty():
		return
	if finished or get_tree().paused or get_node_or_null("PauseMenu") != null:
		return
	PauseMenu.open(self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_inside_tree() and not UI.test_mode:
			open_pause()


func bot_state() -> Dictionary:
	var me: Dictionary = st["agents"][0] if not st.is_empty() else {}
	return {"pos": me.get("p", Vector2.ZERO), "deaths": deaths, "coins": coins, "finished": finished, "failed": failed,
		"stomps": int(me.get("kills", 0)), "time": time_in_level, "place": int(st.get("place", 0)), "alive": MapRules.alive_count(st) if not st.is_empty() else 0,
		"online": not online.is_empty(), "host": host, "placed": placed}


# ------------------------------------------------------------------ en directo

## La isla de la sala (misma semilla para todos), los humanos por orden de sala y "yo" el primero.
func _net_state_setup() -> void:
	var lv: Dictionary = level.duplicate(true)
	lv["seed"] = int(online.get("semilla", 1))
	var players: Array = []
	for j: Variant in online.get("jugadores", []):
		if j is Dictionary:
			players.append(j)
	players.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return int(x.get("slot", 0)) < int(y.get("slot", 0)))
	lv["bots"] = clampi(maxi(int(level.get("bots", 15)), players.size() - 1), 1, 39)
	st = MapRules.new_state(lv)
	var my_id: String = str(online.get("yo", ""))
	var aliases: Array = []
	var ids: Array[String] = []
	var me: int = 0
	for k: int in players.size():
		aliases.append(str(players[k].get("alias", "")))
		ids.append(str(players[k].get("sesion", "")))
		if str(players[k].get("sesion", "")) == my_id:
			me = k
	var sorted_ids: Array[String] = ids.duplicate()
	sorted_ids.sort()
	host = not sorted_ids.is_empty() and sorted_ids[0] == my_id
	MapRules.setup_online(st, aliases, me, host)
	_start_ms = int(online.get("start_ms", Time.get_ticks_msec()))


func _net_open() -> void:
	net = Online.arena_channel(str(online.get("sala", "")))
	add_child(net)
	net.received.connect(_on_net)
	QA.log_event("royale_live_start", {"sala": str(online.get("sala", "")), "host": host, "players": (online.get("jugadores", []) as Array).size()})


## Manda 8 veces por segundo como van los jugadores que son de este movil.
func _net_send(delta: float) -> void:
	_send_acc += delta
	if _send_acc < NET_RATE:
		return
	_send_acc = 0.0
	var l: Array = []
	for a: Dictionary in st["agents"]:
		if not bool(a["remote"]) and bool(a["alive"]) and (bool(a["landed"]) or int(a["nid"]) < (online.get("jugadores", []) as Array).size()):
			l.append(MapRules.net_pack(a))
	if not l.is_empty():
		net.send("st", {"l": l})


## Lo que pasa a algo de este movil se cuenta a los demas: disparos, botin, golpes y caidas.
func _net_event(e: Dictionary) -> void:
	var id: int = int(e.get("id", -1))
	if id < 0 or id >= (st["agents"] as Array).size():
		return
	var a: Dictionary = st["agents"][id]
	if bool(a["remote"]):
		return
	var nid: int = int(a["nid"])
	match str(e["kind"]):
		"shot":
			if not (e.get("dirs", []) as Array).is_empty():
				net.send("sh", {"i": nid, "d": e["dirs"]})
		"pick":
			net.send("pk", {"i": nid, "l": str(e.get("lid", "")), "it": str(e.get("item", ""))})
		"melee":
			var t: int = int(e.get("target", -1))
			if t >= 0 and t < (st["agents"] as Array).size():
				net.send("me", {"i": nid, "t": int(st["agents"][t]["nid"]), "d": float(e.get("dmg", 0.0))})
		"dead":
			var by: int = int(e.get("by", -1))
			net.send("ko", {"i": nid, "by": int(st["agents"][by]["nid"]) if by >= 0 and by < (st["agents"] as Array).size() else -1})


func _on_net(event: String, d: Dictionary) -> void:
	## Aunque ya hayas caido, la partida de los demas sigue contandose (marcador y bajas).
	if st.is_empty():
		return
	match event:
		"st":
			for v: Variant in d.get("l", []):
				if v is Array and (v as Array).size() >= 12:
					var a: Dictionary = MapRules.by_nid(st, int(v[0]))
					if not a.is_empty():
						MapRules.net_apply(st, a, v)
		"sh":
			var a2: Dictionary = MapRules.by_nid(st, int(d.get("i", -1)))
			if not a2.is_empty() and bool(a2["remote"]):
				MapRules.net_shot(st, a2, d.get("d", []))
		"pk":
			var a3: Dictionary = MapRules.by_nid(st, int(d.get("i", -1)))
			if not a3.is_empty() and bool(a3["remote"]):
				MapRules.net_pick(st, a3, str(d.get("l", "")), str(d.get("it", "")))
		"me":
			var t: Dictionary = MapRules.by_nid(st, int(d.get("t", -1)))
			var by: Dictionary = MapRules.by_nid(st, int(d.get("i", -1)))
			if not t.is_empty() and not by.is_empty() and bool(by["remote"]):
				MapRules.net_melee(st, t, float(d.get("d", 0.0)), int(by["id"]))
		"ko":
			var a4: Dictionary = MapRules.by_nid(st, int(d.get("i", -1)))
			var k: Dictionary = MapRules.by_nid(st, int(d.get("by", -1)))
			if not a4.is_empty():
				MapRules.net_dead(st, a4, int(k["id"]) if not k.is_empty() else -1)


## Fin en directo: tu puesto al servidor (trofeos) y la ventana de resultado.
func _net_end(place: int) -> void:
	if reported:
		return
	reported = true
	placed = place
	coins = int(st["agents"][0]["kills"])
	if place == 1:
		finished = true
		Audio.play("win")
		Audio.play_track("victoria", false)
		UI.float_text(_world, (st["agents"][0]["p"] as Vector2) - Vector2(0, 120), Kit.text("br_win_live", "\u00a1N\u00famero 1!"), Color("#ffd54a"), 48)
	else:
		finished = true
		failed = true
		Audio.play("hurt")
	QA.log_event("royale_live_end", {"place": place, "kills": coins})
	var sala: String = str(online.get("sala", ""))
	Online.arena_match = {}
	var r: Dictionary = await Online.arena_result(sala, place)
	if not is_inside_tree():
		return
	ArenaPanel.open_result(self, place, coins, r)


# ------------------------------------------------------------------ dibujo

func _hash(x: int, y: int) -> int:
	return absi((x * 73856093) ^ (y * 19349663)) % 1000


func _draw_world() -> void:
	if st.is_empty():
		return
	var cam: Vector2 = _camera.position
	var view: Rect2 = Rect2(cam - Vector2(420, 720), Vector2(840, 1440))
	var x0: int = maxi(-2, floori(view.position.x / T))
	var x1: int = floori(view.end.x / T)
	var y0: int = maxi(-2, floori(view.position.y / T))
	var y1: int = floori(view.end.y / T)
	var trees: Array[Vector2] = []
	## 1 - Suelo.
	for y: int in range(y0, y1 + 1):
		for x: int in range(x0, x1 + 1):
			var c: String = MapRules.cell(st, x, y)
			var r: Rect2 = Rect2(Vector2(x, y) * T, Vector2(T, T))
			var h: int = _hash(x, y)
			match c:
				"~":
					_world.draw_rect(r, Color("#2f7fb8"))
					var wv: float = sin(_t * 1.6 + float(x) * 0.7 + float(y) * 0.4)
					_world.draw_line(r.position + Vector2(10, 30 + wv * 4.0), r.position + Vector2(40, 30 + wv * 4.0), Color(1, 1, 1, 0.12), 3.0)
				",":
					_world.draw_rect(r, Color("#e8d39a"))
				"_":
					_world.draw_rect(r, Color("#a8794c"))
					_world.draw_line(r.position + Vector2(0, 21), r.position + Vector2(T, 21), Color("#8d6238"), 2.0)
					_world.draw_line(r.position + Vector2(0, 43), r.position + Vector2(T, 43), Color("#8d6238"), 2.0)
				"#":
					_world.draw_rect(r, Color("#5b5f6b"))
					_world.draw_rect(r.grow(-6.0), Color("#757a88"))
				_:
					_world.draw_rect(r, Color("#6cbf4f") if h % 7 != 0 else Color("#64b548"))
					if h % 11 == 0:
						_world.draw_circle(r.position + Vector2(float(h % 50) + 7.0, float(h % 37) + 12.0), 4.0, Color("#f4e36a"))
					if c == "r":
						_world.draw_circle(r.get_center() + Vector2(0, 6), T * 0.42, Color(0, 0, 0, 0.18))
						_world.draw_circle(r.get_center(), T * 0.42, Color("#8e939c"))
						_world.draw_circle(r.get_center() + Vector2(-8, -8), T * 0.18, Color("#a9aeb6"))
					elif c == "t":
						trees.append(r.get_center())
						_world.draw_circle(r.get_center(), T * 0.16, Color("#6b4a2b"))
	## 2 - Botin.
	for it: Dictionary in st["loot"]:
		var ip: Vector2 = it["p"]
		if not view.has_point(ip):
			continue
		var col: Color = _rarity_col(str(it["item"]))
		_world.draw_circle(ip, 22.0 + 2.0 * sin(_t * 4.0 + ip.x), Color(col.r, col.g, col.b, 0.25))
		_draw_item(str(it["item"]), ip, col)
	## 3 - Jugadores.
	for a: Dictionary in st["agents"]:
		if not bool(a["alive"]) or not bool(a["landed"]):
			continue
		var p: Vector2 = a["p"]
		if not view.grow(40).has_point(p):
			continue
		var me: bool = int(a["id"]) == 0
		var body: Color = Kit.color("player", Color("#3fa7ff")) if me else Color.from_hsv(fmod(float(a["id"]) * 0.137, 1.0) * 0.25, 0.65, 0.95)
		if float(a["hit_t"]) > 0.0:
			body = Color.WHITE
		var aim: Vector2 = (a["aim"] as Vector2).normalized()
		_world.draw_circle(p + Vector2(0, 6), MapRules.R, Color(0, 0, 0, 0.25))
		if str(a["weapon"]) != "punos":
			_world.draw_line(p + aim * 8.0, p + aim * 40.0, Color("#2a2d33"), 9.0)
		_world.draw_circle(p, MapRules.R, body)
		_world.draw_circle(p + aim * 14.0 + aim.orthogonal() * 10.0, 6.0, Color("#f2c49b"))
		_world.draw_circle(p + aim * 14.0 - aim.orthogonal() * 10.0, 6.0, Color("#f2c49b"))
		if float(a["armor"]) > 0.0:
			_world.draw_arc(p, MapRules.R + 3.0, 0, TAU, 20, Color("#4aa8ff"), 3.0)
		if float(a["heal_t"]) > 0.0:
			_world.draw_arc(p, MapRules.R + 9.0, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - float(a["heal_t"]) / float(MapRules.HEALS[str(a["heal_item"])][1])), 24, Color("#5aff8a"), 4.0)
		if not me and float(a["hp"]) < MapRules.MAX_HP:
			var hb: Rect2 = Rect2(p + Vector2(-24, -36), Vector2(48, 6))
			_world.draw_rect(hb, Color(0, 0, 0, 0.5))
			_world.draw_rect(Rect2(hb.position, Vector2(48.0 * float(a["hp"]) / MapRules.MAX_HP, 6)), Color("#ff5a5a"))
	## 4 - Balas, copas de los arboles (tapan) y efectos.
	for b: Dictionary in st["bullets"]:
		var bp: Vector2 = b["p"]
		_world.draw_line(bp, bp - (b["v"] as Vector2).normalized() * 22.0, Color("#fff3a0"), 3.0)
	for tc: Vector2 in trees:
		_world.draw_circle(tc + Vector2(6, 8), T * 0.62, Color(0, 0, 0, 0.18))
		_world.draw_circle(tc, T * 0.62, Color(0.18, 0.55, 0.25, 0.92))
		_world.draw_circle(tc + Vector2(-10, -10), T * 0.32, Color(0.3, 0.68, 0.33, 0.9))
	var dt: float = get_physics_process_delta_time()
	var k: int = _tracers.size() - 1
	while k >= 0:
		var tr: Dictionary = _tracers[k]
		_world.draw_line(tr["a"], tr["b"], Color(1, 0.9, 0.5, 0.8), 4.0)
		tr["t"] = float(tr["t"]) - dt
		if float(tr["t"]) <= 0.0:
			_tracers.remove_at(k)
		k -= 1
	k = _fx.size() - 1
	while k >= 0:
		var f: Dictionary = _fx[k]
		f["p"] = (f["p"] as Vector2) + (f["v"] as Vector2) * dt
		f["t"] = float(f["t"]) - dt
		var fc: Color = f["c"]
		fc.a = clampf(float(f["t"]) * 2.0, 0.0, 1.0)
		_world.draw_circle(f["p"], 5.0, fc)
		if float(f["t"]) <= 0.0:
			_fx.remove_at(k)
		k -= 1
	## 5 - La zona: fuera, todo azulado; el circulo siguiente en blanco.
	var zc: Vector2 = st["zone_c"]
	var zr: float = float(st["zone_r"])
	_world.draw_arc(zc, zr + 1500.0, 0, TAU, 96, Color(0.25, 0.35, 1.0, 0.28), 3000.0)
	_world.draw_arc(zc, zr, 0, TAU, 96, Color(0.5, 0.65, 1.0, 0.9), 6.0)
	if int(st["phase"]) >= 0:
		_world.draw_arc(st["to_c"], float(st["to_r"]), 0, TAU, 96, Color(1, 1, 1, 0.7), 3.0)
	## 6 - Avion y paracaidas.
	if float(st["time"]) < MapRules.PLANE_T + 0.5:
		var pp: Vector2 = MapRules.plane_pos(st)
		var dir: Vector2 = ((st["plane_b"] as Vector2) - (st["plane_a"] as Vector2)).normalized()
		_world.draw_set_transform(pp, dir.angle(), Vector2.ONE)
		_world.draw_rect(Rect2(Vector2(-70, -14), Vector2(140, 28)), Color("#e6e9ee"))
		_world.draw_rect(Rect2(Vector2(-14, -80), Vector2(34, 160)), Color("#cfd4dc"))
		_world.draw_rect(Rect2(Vector2(-70, -40), Vector2(18, 80)), Color("#cfd4dc"))
		_world.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		for a2: Dictionary in st["agents"]:
			if bool(a2["landed"]) and float(st["time"]) - float(a2["drop_t"]) < 1.0 and view.has_point(a2["p"]):
				_world.draw_arc((a2["p"] as Vector2) - Vector2(0, 50), 34.0, PI, TAU, 12, Color("#ff7a5a"), 8.0)
	if _hurt > 0.0:
		_world.draw_rect(view, Color(1, 0, 0, _hurt * 0.6))


func _draw_item(item: String, p: Vector2, col: Color) -> void:
	if MapRules.WEAPONS.has(item):
		var ln: float = 14.0 + 6.0 * float(MapRules.WEAPONS[item]["tier"])
		_world.draw_line(p - Vector2(ln, 0), p + Vector2(ln, 0), Color("#2a2d33"), 9.0)
		_world.draw_line(p - Vector2(ln, 0), p + Vector2(ln * 0.3, 0), col, 5.0)
		_world.draw_line(p + Vector2(-ln * 0.4, 0), p + Vector2(-ln * 0.4, 12), Color("#2a2d33"), 7.0)
	elif item.begins_with("chaleco"):
		_world.draw_rect(Rect2(p - Vector2(13, 14), Vector2(26, 28)), col)
		_world.draw_rect(Rect2(p - Vector2(5, 14), Vector2(10, 8)), Color("#2a2d33"))
	else:
		_world.draw_rect(Rect2(p - Vector2(14, 10), Vector2(28, 20)), Color.WHITE)
		_world.draw_rect(Rect2(p - Vector2(3, 8), Vector2(6, 16)), Color("#ff4d5e"))
		_world.draw_rect(Rect2(p - Vector2(8, 3), Vector2(16, 6)), Color("#ff4d5e"))


func _draw_hud() -> void:
	if st.is_empty():
		return
	var size: Vector2 = _hud.size
	var me: Dictionary = st["agents"][0]
	## Vida, chaleco y arma (abajo en el centro).
	var bx: float = size.x * 0.5 - 120.0
	var by: float = size.y - 225.0
	_hud.draw_rect(Rect2(bx, by, 240, 20), Color(0, 0, 0, 0.5))
	_hud.draw_rect(Rect2(bx, by, 240.0 * clampf(float(me["hp"]) / MapRules.MAX_HP, 0.0, 1.0), 20), Color("#5aff8a") if float(me["hp"]) > 35.0 else Color("#ff5a5a"))
	if float(me["armor"]) > 0.0:
		_hud.draw_rect(Rect2(bx, by - 11, 240.0 * float(me["armor"]) / 75.0, 7), Color("#4aa8ff"))
	var w: String = str(me["weapon"])
	_hud.draw_string(_font, Vector2(bx, by + 50), item_name(w), HORIZONTAL_ALIGNMENT_CENTER, 240, 28, _rarity_col(w))
	## Mandos virtuales.
	if _move_id >= 0:
		_hud.draw_circle(_move_o, 100.0, Color(1, 1, 1, 0.12))
		_hud.draw_circle(_move_o + _move_v * 100.0, 44.0, Color(1, 1, 1, 0.35))
	else:
		_hud.draw_circle(Vector2(150, size.y - 150), 90.0, Color(1, 1, 1, 0.08))
	if _aim_id >= 0:
		_hud.draw_circle(_aim_o, 90.0, Color(1, 0.4, 0.3, 0.14))
		_hud.draw_circle(_aim_o + _aim_v * 90.0, 40.0, Color(1, 0.4, 0.3, 0.4))
	else:
		_hud.draw_circle(Vector2(size.x - 150, size.y - 150), 80.0, Color(1, 0.4, 0.3, 0.1))
	## Lista de bajas (arriba a la izquierda, bajo los textos).
	var dt: float = get_physics_process_delta_time()
	var y: float = 170.0
	var k: int = _feed.size() - 1
	var shown: int = 0
	while k >= 0 and shown < 4:
		var f: Dictionary = _feed[k]
		f["t"] = float(f["t"]) - dt
		_hud.draw_string(_font, Vector2(20, y), str(f["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#ffd54a") if bool(f["me"]) else Color(1, 1, 1, 0.8))
		y += 30.0
		shown += 1
		k -= 1
	while not _feed.is_empty() and float(_feed[0]["t"]) <= 0.0:
		_feed.pop_front()


func _draw_mini() -> void:
	if st.is_empty():
		return
	var s: Vector2 = _mini.size
	var cs: Vector2 = s / Vector2(int(st["w"]), int(st["h"]))
	_mini.draw_rect(Rect2(Vector2.ZERO, s), Color("#2f7fb8"))
	for y: int in int(st["h"]):
		var row: String = st["map"][y]
		for x: int in int(st["w"]):
			var c: String = row[x]
			if c != "~":
				_mini.draw_rect(Rect2(Vector2(x, y) * cs, cs + Vector2(0.5, 0.5)), Color("#5a9f44") if c != "#" and c != "_" else Color("#9a7a5a"))
	var k: float = s.x / (float(int(st["w"])) * T)
	_mini.draw_arc((st["zone_c"] as Vector2) * k, float(st["zone_r"]) * k, 0, TAU, 48, Color(0.6, 0.75, 1.0), 2.0)
	if int(st["phase"]) >= 0:
		_mini.draw_arc((st["to_c"] as Vector2) * k, float(st["to_r"]) * k, 0, TAU, 48, Color.WHITE, 1.5)
	var me: Dictionary = st["agents"][0]
	if bool(me["landed"]):
		_mini.draw_circle((me["p"] as Vector2) * k, 5.0, Color("#ffd54a"))
	else:
		_mini.draw_line((st["plane_a"] as Vector2) * k, (st["plane_b"] as Vector2) * k, Color(1, 1, 1, 0.5), 2.0)
		_mini.draw_circle(MapRules.plane_pos(st) * k, 5.0, Color.WHITE)
	_mini.draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.6), false, 3.0)
