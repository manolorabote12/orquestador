extends Node2D
## Ritmo: las notas bajan por 4 carriles y se tocan justo cuando cruzan la linea.
## 1 - Toca el carril cuando la nota llega a la linea: "Perfecto" (+300) o "Bien" (+100). Si se
##     escapa, "Fallo": baja la energia y se rompe el combo. Tocar sin nota no castiga.
## 2 - Ganas si acaba la cancion con los aciertos del nivel (p. ej. 70 % de las notas).
## 3 - Pierdes si la energia llega a 0 o si acaba sin llegar a los aciertos.
## Mapa: una fila por paso (corchea) en orden de tiempo, 4 letras: "x" nota, "." nada.
## Nivel: {"map", "bpm", "speed" (px/s), "target" (proporcion de aciertos), "energy"}.
## Giro invisibles (level.hidden): las notas se desvanecen al acercarse a la linea; se toca de
## memoria y al ritmo (el tiempo de cada nota no cambia).
## Teclado: D F J K (o las flechas). Movil: toca la columna del carril.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const LANES: int = 4
const LANE_W: float = 170.0
const HIT_Y: float = 0.0
const PERFECT: float = 0.07
const GOOD: float = 0.16
const LEAD: float = 2.0
const KEYS: Array[Key] = [KEY_D, KEY_F, KEY_J, KEY_K]
const ARROWS: Array[Key] = [KEY_LEFT, KEY_DOWN, KEY_UP, KEY_RIGHT]

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

var bpm: float = 110.0
var speed: float = 900.0
var hidden_notes: bool = false
var target: float = 0.7
var energy_max: int = 10
var step: float = 0.27
## Notas: {"lane", "t", "state" (0 por tocar, 1 tocada, 2 fallada), "node"}
var notes: Array[Dictionary] = []
var hits: int = 0
var perfects: int = 0
var misses: int = 0
var combo: int = 0
var best_combo: int = 0
var energy: int = 10
var score: int = 0
var song_end: float = 0.0

var _next: Array[int] = [0, 0, 0, 0]
var _colors: Array[Color] = []
var _lanes: Node2D
var _notes_layer: Node2D
var _camera: Camera2D
var _hero: Node2D = null
## Por carril, los indices de sus notas en orden.
var _lane_index: Array = [[], [], [], []]
var _flash: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _beat_glow: float = 0.0
var _last_beat: int = -1
var _score_label: Label
var _combo_label: Label
var _energy_bar: ProgressBar


func _ready() -> void:
	var lv: Dictionary = Kit.current_level()
	for r: Variant in lv.get("map", []):
		rows.append(str(r))
	bpm = clampf(float(lv.get("bpm", 110.0)), 60.0, 200.0)
	speed = float(lv.get("speed", 900.0))
	hidden_notes = bool(lv.get("hidden", false))
	target = float(lv.get("target", 0.7))
	energy_max = int(lv.get("energy", 10))
	step = 30.0 / bpm
	var accent: Color = Kit.color("accent", Color("#ffb14a"))
	for i: int in LANES:
		_colors.append(Color.from_hsv(fposmod(accent.h + 0.17 * float(i), 1.0), clampf(accent.s, 0.55, 0.85), 1.0))
	RenderingServer.set_default_clear_color(Kit.color("sky", Color("#1b2a41")).darkened(0.25))
	_lanes = Node2D.new()
	_lanes.name = "Lanes"
	_lanes.draw.connect(_draw_lanes)
	add_child(_lanes)
	_notes_layer = Node2D.new()
	_notes_layer.name = "Notes"
	_notes_layer.z_index = 2
	add_child(_notes_layer)
	var hero_art: Dictionary = Kit.sprite_by_role("jugador")
	if not hero_art.is_empty():
		## El heroe baila debajo de la linea (se aplasta un "rig", no el sprite: asi no pierde su escala).
		_hero = Node2D.new()
		_hero.name = "Hero"
		_hero.position = Vector2(LANE_W * LANES * 0.5, HIT_Y + 250.0)
		_hero.z_index = 3
		var spr: AnimatedSprite2D = SpriteKit.animado(hero_art, 150.0, "idle", true)
		Skins.apply(spr)
		_hero.add_child(spr)
		add_child(_hero)
	_camera = Camera2D.new()
	add_child(_camera)
	_camera.make_current()
	Juice.register_camera(_camera)
	_fit_camera()
	_build_hud()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "rhythm", "notes": notes.size(), "bpm": bpm})


func bot_script() -> String:
	return "res://qa/rhythm_bot.gd"


func _fit_camera() -> void:
	var vp: Vector2 = get_viewport_rect().size
	var w: float = LANE_W * LANES + 80.0
	_camera.zoom = Vector2.ONE * minf(vp.x / w, 1.6)
	## La linea de golpeo, abajo (al 75 % de la pantalla).
	_camera.position = Vector2(LANE_W * LANES * 0.5, HIT_Y - vp.y / _camera.zoom.y * 0.25)


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
	top.add_theme_constant_override("separation", 12)
	col.add_child(top)
	_energy_bar = ProgressBar.new()
	_energy_bar.name = "Energy"
	_energy_bar.show_percentage = false
	_energy_bar.custom_minimum_size = Vector2(200.0, 26.0)
	_energy_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_energy_bar)
	_score_label = Label.new()
	_score_label.name = "Score"
	_score_label.theme_type_variation = "HeaderLabel"
	_score_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_score_label)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)
	_combo_label = Label.new()
	_combo_label.name = "Combo"
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combo_label.add_theme_color_override("font_color", UI.colors["acento"])
	col.add_child(_combo_label)
	var grow: Control = Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(grow)
	var hint: Label = Label.new()
	hint.name = "Hint"
	hint.text = Kit.text("rhythm_hint", "Toca cada carril cuando la nota llegue a la l\u00ednea")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", UI.colors["texto_suave"])
	col.add_child(hint)


func _reset() -> void:
	finished = false
	failed = false
	time_in_level = 0.0
	hits = 0
	perfects = 0
	misses = 0
	combo = 0
	best_combo = 0
	score = 0
	coins = 0
	energy = energy_max
	_last_beat = -1
	_next = [0, 0, 0, 0]
	for c: Node in _notes_layer.get_children():
		c.queue_free()
	notes.clear()
	var lane_notes: Array = [[], [], [], []]
	for i: int in rows.size():
		var r: String = rows[i]
		for l: int in mini(LANES, r.length()):
			if r[l] == "x":
				var n: Dictionary = {"lane": l, "t": LEAD + float(i) * step, "state": 0, "node": _make_note(l)}
				notes.append(n)
				(lane_notes[l] as Array).append(notes.size() - 1)
	coins_total = notes.size()
	song_end = LEAD + float(rows.size()) * step + 1.0
	_lane_index = lane_notes
	_update_hud()



func _make_note(lane: int) -> Node2D:
	var n: Node2D = Node2D.new()
	n.position = Vector2(-9999.0, -9999.0)
	var col: Color = _colors[lane]
	n.draw.connect(func() -> void:
		var r: float = LANE_W * 0.34
		n.draw_circle(Vector2(0, 6), r, Color(0, 0, 0, 0.35))
		n.draw_circle(Vector2.ZERO, r, col.darkened(0.35))
		n.draw_circle(Vector2(0, -3), r * 0.82, col)
		n.draw_circle(Vector2(-r * 0.3, -r * 0.35), r * 0.22, Color(1, 1, 1, 0.55)))
	_notes_layer.add_child(n)
	return n


func _update_hud() -> void:
	_score_label.text = str(score)
	_combo_label.text = Kit.text("rhythm_combo", "Combo x{n}").format({"n": combo}) if combo >= 4 else ""
	_energy_bar.max_value = float(energy_max)
	_energy_bar.value = float(energy)


func now() -> float:
	return time_in_level


## Toque en el carril. Devuelve "perfect", "good" o "" (sin nota cerca: no castiga).
func tap(lane: int) -> String:
	if finished or failed or get_tree().paused or lane < 0 or lane >= LANES:
		return ""
	_flash[lane] = 0.18
	var idx: Array = _lane_index[lane]
	var k: int = _next[lane]
	while k < idx.size() and int((notes[idx[k]] as Dictionary)["state"]) != 0:
		k += 1
	_next[lane] = k
	if k >= idx.size():
		return ""
	var n: Dictionary = notes[idx[k]]
	var dt: float = absf(float(n["t"]) - now())
	if dt > GOOD:
		return ""
	n["state"] = 1
	_next[lane] = k + 1
	hits += 1
	combo += 1
	best_combo = maxi(best_combo, combo)
	energy = mini(energy + 1, energy_max)
	var perfect: bool = dt <= PERFECT
	if perfect:
		perfects += 1
		coins = perfects
	score += (300 if perfect else 100) * (1 + mini(combo, 40) / 10)
	var node: Node2D = n["node"]
	var at: Vector2 = Vector2(lane_x(lane), HIT_Y)
	Juice.burst(_notes_layer, at, _colors[lane], 10 if perfect else 6, 260.0)
	UI.float_text(_notes_layer, at + Vector2(0, -90), Kit.text("rhythm_perfect", "\u00a1Perfecto!") if perfect else Kit.text("rhythm_good", "Bien"),
		_colors[lane] if perfect else UI.colors["texto"], 30)
	node.queue_free()
	Audio.play("coin", 0.0, -6.0, 0.9 + 0.12 * float(lane))
	if _hero != null:
		Juice.squash(_hero, Vector2(1.15, 0.88))
	_update_hud()
	return "perfect" if perfect else "good"


func lane_x(lane: int) -> float:
	return (float(lane) + 0.5) * LANE_W


func _physics_process(delta: float) -> void:
	if finished or failed or get_tree().paused:
		return
	time_in_level += delta
	var t: float = now()
	## Pulso en cada negra (el escenario late con la musica del nivel).
	var beat: int = int(floor((t - LEAD) / (step * 2.0)))
	if beat != _last_beat and t >= LEAD:
		_last_beat = beat
		_beat_glow = 1.0
	_beat_glow = maxf(_beat_glow - delta * 4.0, 0.0)
	for i: int in LANES:
		_flash[i] = maxf(_flash[i] - delta, 0.0)
	for n: Dictionary in notes:
		if int(n["state"]) != 0:
			continue
		var dt: float = float(n["t"]) - t
		if dt > 3.0:
			continue
		var nd: Node2D = n["node"]
		nd.position = Vector2(lane_x(int(n["lane"])), HIT_Y - dt * speed)
		if hidden_notes:
			## Visible arriba; se apaga entre 0,9 s y 0,45 s antes de la linea.
			nd.modulate.a = clampf((dt - 0.45) / 0.45, 0.0, 1.0)
		if dt < -GOOD:
			_miss(n)
			if failed:
				return
	_lanes.queue_redraw()
	if t >= song_end:
		if float(hits) >= ceil(target * float(notes.size())):
			_finish()
		else:
			_lose("score")


func _miss(n: Dictionary) -> void:
	n["state"] = 2
	misses += 1
	combo = 0
	energy -= 2
	var node: Node2D = n["node"]
	node.modulate = Color(1, 1, 1, 0.35)
	var tw: Tween = node.create_tween()
	tw.tween_property(node, "position:y", node.position.y + 120.0, 0.25)
	tw.tween_callback(node.queue_free)
	UI.float_text(_notes_layer, Vector2(lane_x(int(n["lane"])), HIT_Y - 60.0), Kit.text("rhythm_miss", "Fallo"), UI.colors["peligro"], 26)
	_update_hud()
	if energy <= 0:
		_lose("energy")


func lane_at(world: Vector2) -> int:
	var l: int = int(floor(world.x / LANE_W))
	return l if l >= 0 and l < LANES else -1


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()
		return
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var key: Key = (event as InputEventKey).physical_keycode
		var l: int = KEYS.find(key)
		if l < 0:
			l = ARROWS.find(key)
		if l >= 0:
			tap(l)
		return
	if UI.test_mode:
		return
	## Toques (varios dedos a la vez); el raton solo si no hay pantalla tactil.
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		tap(lane_at(get_canvas_transform().affine_inverse() * (event as InputEventScreenTouch).position))
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and not DisplayServer.is_touchscreen_available():
		tap(lane_at(get_canvas_transform().affine_inverse() * (event as InputEventMouseButton).position))


# ------------------------------------------------------------------ final

func accuracy() -> float:
	return float(hits) / float(maxi(notes.size(), 1))


func _finish() -> void:
	finished = true
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "hits": hits, "perfects": perfects, "misses": misses,
		"combo": best_combo, "accuracy": snappedf(accuracy(), 0.01), "coins": perfects, "stars": stars})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


## 3 estrellas con el 95 % de las notas, 2 con el 85 %, 1 por pasar.
func stars_earned() -> int:
	var a: float = accuracy()
	if a >= 0.95:
		return 3
	if a >= 0.85:
		return 2
	return 1


func _lose(cause: String) -> void:
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": cause, "hits": hits, "misses": misses, "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry()
		return
	var title: String = Kit.text("rhythm_energy", "\u00a1Sin energ\u00eda!") if cause == "energy" else Kit.text("rhythm_short", "\u00a1Casi!")
	var p: FailPanel = FailPanel.open(self, title, Kit.text("rhythm_fail_hint", "Has tocado {n} de {t} notas (necesitas {need}). \u00a1Otra vez!").format(
		{"n": hits, "t": notes.size(), "need": int(ceil(target * float(notes.size())))}))
	p.closed.connect(retry)


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
	return {"deaths": deaths, "coins": coins, "finished": finished, "failed": failed, "stomps": 0,
		"hits": hits, "misses": misses, "perfects": perfects, "accuracy": accuracy(), "energy": energy}


func capture_delays() -> Vector2:
	return Vector2(5.0, 1.0)


# ------------------------------------------------------------------ dibujo

func _draw_lanes() -> void:
	var w: float = LANE_W * LANES
	var top: float = HIT_Y - 2600.0
	var bg: Color = Kit.color("solid", Color("#2a3a5a")).darkened(0.45)
	_lanes.draw_rect(Rect2(Vector2(-40.0, top), Vector2(w + 80.0, 3200.0)), bg)
	for i: int in LANES:
		var x: float = float(i) * LANE_W
		var c: Color = _colors[i]
		_lanes.draw_rect(Rect2(Vector2(x + 6.0, top), Vector2(LANE_W - 12.0, 2600.0)), c.darkened(0.82).lerp(c, 0.06 + 0.08 * _beat_glow))
		if _flash[i] > 0.0:
			_lanes.draw_rect(Rect2(Vector2(x + 6.0, HIT_Y - 420.0), Vector2(LANE_W - 12.0, 420.0)), Color(c, 0.35 * _flash[i] / 0.18))
	## Linea de golpeo con un aro por carril.
	_lanes.draw_line(Vector2(-20.0, HIT_Y), Vector2(w + 20.0, HIT_Y), Color(1, 1, 1, 0.5 + 0.4 * _beat_glow), 6.0)
	for i: int in LANES:
		var c2: Color = _colors[i]
		var r: float = LANE_W * 0.36 * (1.0 + 0.12 * _flash[i] / 0.18)
		_lanes.draw_arc(Vector2(lane_x(i), HIT_Y), r, 0.0, TAU, 40, c2, 7.0, true)
		_lanes.draw_circle(Vector2(lane_x(i), HIT_Y), r * 0.55, Color(c2, 0.18 + 0.4 * _flash[i] / 0.18))
