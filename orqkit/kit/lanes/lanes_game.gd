extends Node2D
## Genero corredor 3D: tres carriles, corres solo hacia delante cada vez mas rapido.
## 1 - Desliza a los lados (o flechas) para cambiar de carril, arriba para saltar y abajo
##     para agacharte.
## 2 - Vallas bajas: saltalas. Barras altas: agachate. Trenes: cambia de carril.
## 3 - Chocar quita un corazon (y frena); sin corazones, a repetir. Llegar al final gana.
## 4 - Estrellas segun los choques: ninguno tres, uno dos, mas una.
## La logica va en metros y en 2D (carril, distancia, salto); la vista 3D (lanes_view3d.gd)
## solo la dibuja. Mapa (game.json -> levels[i].map): una fila cada 6 m con 3 carriles:
##   "." libre, "C" moneda, "B" valla baja, "H" barra alta, "W" tren.
## Parametros del nivel: speed (m/s al salir) y ramp (cuanto acelera hasta la meta, 0.25 = +25 %).
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const MapRules = preload("res://kit/lanes/lanes_map.gd")
const ROW: float = 6.0
const LANE_W: float = 2.2
const JUMP_TIME: float = 0.66
const JUMP_H: float = 1.7
const SLIDE_TIME: float = 0.66
const LANE_SPEED: float = 15.0
const INVULN: float = 1.2

var rows: Array[String] = []
var level: Dictionary = {}
var finished: bool = false
var failed: bool = false
var deaths: int = 0
var hits: int = 0
var time_in_level: float = 0.0
var coins: int = 0
var coins_total: int = 0
var fast: bool = false
var auto_retry: bool = false
var result_panel: ResultPanel
## Estado que leen la vista 3D y el bot.
var d: float = 0.0
var lane: int = 1
var lat: float = 0.0
var speed: float = 0.0
var jump_t: float = 0.0
var slide_t: float = 0.0
var invuln: float = 0.0
var stun: float = 0.0
var hp: int = 3
var max_hp: int = 3
var items: Array[Dictionary] = []
var track_len: float = 0.0
var started: bool = false

var view3d: Node3D
var _hearts: HBoxContainer
var _coins_label: Label
var _progress: ProgressBar
var _go_label: Label
var _countdown: float = 1.6
var _swipe_from: Vector2 = Vector2.ZERO
var _swiping: bool = false
var _hint: Label


func _ready() -> void:
	level = Kit.current_level()
	for r: Variant in level.get("map", []):
		rows.append(str(r))
	track_len = float(rows.size()) * ROW + 12.0
	view3d = load("res://kit/lanes/lanes_view3d.gd").new()
	add_child(view3d)
	view3d.call("setup", self)
	_build_hud()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "lanes", "rows": rows.size()})


## Los bots: QaBot juega este genero con el script que devuelve esta funcion.
func bot_script() -> String:
	return "res://qa/lanes_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(4.5, 1.6)


func lane_x(l: int) -> float:
	return float(l - 1) * LANE_W


func height() -> float:
	if jump_t <= 0.0:
		return 0.0
	var k: float = 1.0 - jump_t / JUMP_TIME
	return 4.0 * JUMP_H * k * (1.0 - k)


func target_speed() -> float:
	var base: float = float(level.get("speed", 11.0))
	return base * (1.0 + float(level.get("ramp", 0.25)) * clampf(d / maxf(track_len, 1.0), 0.0, 1.0))


# ------------------------------------------------------------------ montaje

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
	_go_label = Label.new()
	_go_label.name = "Go"
	_go_label.theme_type_variation = "TitleLabel"
	_go_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_go_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_go_label)
	var grow: Control = Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(grow)
	var hint: Label = Label.new()
	_hint = hint
	hint.name = "Hint"
	hint.text = Kit.text("swipe_lanes", "Desliza: lados para cambiar de carril, arriba salta, abajo ag\u00e1chate")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", UI.colors["texto_suave"])
	col.add_child(hint)


func _reset() -> void:
	finished = false
	failed = false
	started = false
	_countdown = 0.0 if fast else 1.6
	if _hint != null:
		_hint.modulate.a = 1.0
	d = 0.0
	lane = 1
	lat = 0.0
	speed = 0.0
	jump_t = 0.0
	slide_t = 0.0
	invuln = 0.0
	stun = 0.0
	hits = 0
	coins = 0
	max_hp = maxi(int(Kit.player_hp(float(Kit.param("player.hp", 3.0)))), 1)
	hp = max_hp
	items.clear()
	coins_total = 0
	for i: int in rows.size():
		for l: int in mini(rows[i].length(), 3):
			var ch: String = rows[i][l]
			if ch == ".":
				continue
			items.append({"kind": ch, "d": (float(i) + 0.5) * ROW, "lane": l, "alive": true})
			if ch == "C":
				coins_total += 1
	view3d.call("rebuild")
	_update_hud()


func _update_hud() -> void:
	for c: Node in _hearts.get_children():
		c.queue_free()
	for i: int in max_hp:
		var full: bool = i < hp
		_hearts.add_child(UiIcon.make("heart" if full else "heart_empty", UI.colors["peligro"] if full else (UI.colors["texto_suave"] as Color), 36.0))
	_coins_label.text = "%d/%d" % [coins, coins_total]
	_progress.max_value = track_len
	_progress.value = d


# ------------------------------------------------------------------ acciones

func move_lane(dir: int) -> bool:
	if finished or failed or not started:
		return false
	var n: int = clampi(lane + dir, 0, 2)
	if n == lane:
		return false
	lane = n
	if not fast:
		Audio.play("click", 0.1, -10.0)
	return true


func jump() -> bool:
	if finished or failed or not started or jump_t > 0.0:
		return false
	jump_t = JUMP_TIME
	slide_t = 0.0
	if not fast:
		Audio.play("jump", 0.1, -6.0)
	return true


func slide() -> bool:
	if finished or failed or not started or slide_t > 0.0:
		return false
	slide_t = SLIDE_TIME
	## Agacharse en el aire te baja de golpe (como en los corredores clasicos).
	jump_t = 0.0
	if not fast:
		Audio.play("land", 0.1, -6.0)
	return true


# ------------------------------------------------------------------ bucle

func _physics_process(delta: float) -> void:
	if finished or failed or get_tree().paused:
		return
	time_in_level += delta
	if not started:
		_countdown -= delta
		_go_label.text = str(int(ceil(_countdown))) if _countdown > 0.0 else Kit.text("go", "\u00a1Ya!")
		if _countdown <= 0.0:
			started = true
			_go_label.text = ""
			## La ayuda se va a los pocos segundos de correr (no tapa la via).
			if not fast:
				var tw: Tween = _hint.create_tween()
				tw.tween_interval(3.5)
				tw.tween_property(_hint, "modulate:a", 0.0, 0.6)
		view3d.call("sync")
		return
	invuln = maxf(invuln - delta, 0.0)
	stun = maxf(stun - delta, 0.0)
	jump_t = maxf(jump_t - delta, 0.0)
	slide_t = maxf(slide_t - delta, 0.0)
	var top: float = target_speed() * (0.6 if stun > 0.0 else 1.0)
	speed = move_toward(speed, top, 9.0 * delta)
	d += speed * delta
	lat = move_toward(lat, lane_x(lane), LANE_SPEED * delta)
	_check_items()
	_update_hud()
	view3d.call("sync")
	if d >= track_len:
		_finish()


func _check_items() -> void:
	var h: float = height()
	for it: Dictionary in items:
		if not bool(it["alive"]):
			continue
		var dd: float = float(it["d"]) - d
		if dd > 3.2:
			break
		## Los trenes miden 5.6 m; lo demas, poco mas de un paso.
		var reach: float = 3.0 if it["kind"] == "W" else 1.0
		if absf(dd) > reach:
			continue
		if absf(lane_x(int(it["lane"])) - lat) > LANE_W * 0.55:
			continue
		match str(it["kind"]):
			"C":
				if h < 1.9:
					it["alive"] = false
					coins += 1
					if not fast:
						Audio.play("coin", 0.1, -8.0)
			"B":
				if h < 0.55 and invuln <= 0.0:
					_crash(it)
			"H":
				if slide_t <= 0.0 and invuln <= 0.0:
					_crash(it)
			"W":
				if invuln <= 0.0:
					_crash(it)


func _crash(it: Dictionary) -> void:
	hp -= 1
	hits += 1
	invuln = INVULN
	stun = 0.8
	speed *= 0.5
	QA.log_event("crash", {"kind": it["kind"], "row": int(float(it["d"]) / ROW), "hp": hp})
	if not fast:
		Audio.play("hurt")
		Juice.vibrate(50)
		view3d.call("shake", 0.5)
	if hp <= 0:
		_lose()


# ------------------------------------------------------------------ entrada

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()
		return
	if event.is_action_pressed("move_left"):
		move_lane(-1)
	elif event.is_action_pressed("move_right"):
		move_lane(1)
	elif event.is_action_pressed("jump") or event.is_action_pressed("move_up"):
		jump()
	elif event.is_action_pressed("move_down"):
		slide()
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		var pressed: bool = event.pressed
		var pos: Vector2 = event.position
		if pressed:
			_swipe_from = pos
			_swiping = true
		elif _swiping:
			_swiping = false
			var v: Vector2 = pos - _swipe_from
			if v.length() < 30.0:
				jump()
			elif absf(v.x) > absf(v.y):
				move_lane(1 if v.x > 0.0 else -1)
			elif v.y < 0.0:
				jump()
			else:
				slide()


# ------------------------------------------------------------------ final

func _finish() -> void:
	finished = true
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = coins * 50 + int(d) - hits * 200
	var record: bool = Save.submit_best(level_id, maxi(score, 0))
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "coins": coins, "hits": hits, "deaths": deaths, "stars": stars})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": maxi(score, 0), "record": record})
	await Ads.show_interstitial("level_end")


## Estrellas segun los choques: ninguno tres, uno dos, mas una.
func stars_earned() -> int:
	return clampi(3 - hits, 1, 3)


func _lose() -> void:
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "crash", "deaths": deaths})
	if auto_retry:
		retry()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("lanes_lost", "\u00a1Choque!"), Kit.text("lanes_hint", "Vallas: salta. Barras: ag\u00e1chate. Trenes: cambia de carril"))
	p.closed.connect(retry)


func retry() -> void:
	_reset()

## Segunda oportunidad (anuncio con premio, lo ofrece el panel de derrota): sigue la partida.
func revive() -> void:
	failed = false
	hp = max_hp
	invuln = INVULN * 2.5
	stun = 0.0
	_update_hud()



func open_pause() -> void:
	if finished or get_tree().paused or get_node_or_null("PauseMenu") != null:
		return
	_swiping = false
	PauseMenu.open(self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_inside_tree() and not UI.test_mode:
			open_pause()


func bot_state() -> Dictionary:
	return {"pos": Vector2(lat, d), "deaths": deaths, "coins": coins, "finished": finished, "failed": failed,
		"stomps": 0, "hits": hits, "progress": clampf(d / maxf(track_len, 1.0), 0.0, 1.0)}
