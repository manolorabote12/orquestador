extends Node2D
## Apilar: un bloque va y viene encima de la torre; toca para soltarlo. Lo que sobresale se cae
## y el bloque siguiente es igual de ancho que lo que quedo. Si no tocas la torre, pierdes.
## 1 - "Perfecto" (casi exacto): no se corta nada, el bloque crece un poco y suma racha.
## 2 - Ganas al llegar a la altura del nivel (game.json -> levels[i].target).
## 3 - Cada bloque va un poco mas rapido (speed y ramp del nivel).
## 4 - Estrellas por lo ancho que llegas arriba (y los perfectos).
## Nivel: {"map": ["SSSS..."], "target", "speed", "ramp", "width", "perfect"} (px de juego).
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const BLOCK_H: float = 56.0
const AREA_W: float = 640.0

var finished: bool = false
var failed: bool = false
var deaths: int = 0
var time_in_level: float = 0.0
var coins: int = 0
var coins_total: int = 0
var fast: bool = false
var auto_retry: bool = false
var result_panel: ResultPanel

var target: int = 15
var speed: float = 260.0
var ramp: float = 0.03
var start_width: float = 360.0
var perfect_px: float = 9.0
## Torre: lista de [x_centro, ancho]
var tower: Array = []
var moving_x: float = 0.0
var moving_w: float = 0.0
var moving_dir: float = 1.0
var streak: int = 0
var perfects: int = 0
var drops: int = 0

var _camera: Camera2D
var _blocks: Node2D
var _mover: Polygon2D
var _hero: Node2D
var _count_label: Label
var _streak_label: Label
var _cam_y: float = 0.0


func _ready() -> void:
	var lv: Dictionary = Kit.current_level()
	target = clampi(int(lv.get("target", 15)), 3, 60)
	speed = float(lv.get("speed", 260.0))
	ramp = float(lv.get("ramp", 0.03))
	start_width = float(lv.get("width", 360.0))
	perfect_px = float(lv.get("perfect", 9.0))
	coins_total = target
	RenderingServer.set_default_clear_color(Kit.color("sky", Color("#1b2a41")))
	add_child(_build_backdrop())
	_blocks = Node2D.new()
	_blocks.name = "Blocks"
	add_child(_blocks)
	_mover = Polygon2D.new()
	_mover.name = "Mover"
	_mover.z_index = 3
	add_child(_mover)
	_build_hero()
	_camera = Camera2D.new()
	add_child(_camera)
	_camera.make_current()
	Juice.register_camera(_camera)
	_build_hud()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "stack", "target": target})


func bot_script() -> String:
	return "res://qa/stack_bot.gd"


# ------------------------------------------------------------------ montaje

func _build_backdrop() -> Node2D:
	var n: Node2D = Node2D.new()
	n.name = "Backdrop"
	n.z_index = -10
	## Cielo en franjas que se aclaran hacia arriba: se nota la altura al subir.
	var sky: Color = Kit.color("sky", Color("#1b2a41"))
	## Con fondo ilustrado de la IA no se pinta el cielo a franjas (solo el suelo).
	var bands: int = 0 if Look.has_level_backdrop() else 30
	for i: int in bands:
		var band: Polygon2D = Polygon2D.new()
		var y0: float = -float(i + 1) * BLOCK_H * 4.0
		band.polygon = PackedVector2Array([Vector2(-900, y0), Vector2(900, y0), Vector2(900, y0 + BLOCK_H * 4.0), Vector2(-900, y0 + BLOCK_H * 4.0)])
		band.color = sky.lightened(minf(0.02 * float(i), 0.45))
		n.add_child(band)
	var ground: Polygon2D = Polygon2D.new()
	ground.polygon = PackedVector2Array([Vector2(-900, 0), Vector2(900, 0), Vector2(900, 900), Vector2(-900, 900)])
	ground.color = Kit.color("solid", Color("#3e5c84")).darkened(0.4)
	n.add_child(ground)
	return n


func _build_hero() -> void:
	_hero = Node2D.new()
	_hero.name = "Hero"
	_hero.z_index = 5
	add_child(_hero)
	var art: Dictionary = Kit.sprite_by_role("jugador")
	if not art.is_empty():
		var spr: AnimatedSprite2D = SpriteKit.animado(art, 96.0, "idle", true)
		_hero.add_child(spr)
		Skins.apply(spr)
	else:
		var body: Polygon2D = Polygon2D.new()
		body.color = Kit.color("accent", Color.ORANGE)
		body.polygon = LevelBuilder._circle(30.0, 18)
		body.position = Vector2(0, -30)
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
	top.add_child(UiIcon.make("star", Kit.color("coin", UI.colors["acento"]), 40.0))
	_count_label = Label.new()
	_count_label.name = "Count"
	top.add_child(_count_label)
	_streak_label = Label.new()
	_streak_label.name = "Streak"
	_streak_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_streak_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_streak_label.add_theme_color_override("font_color", UI.colors["acento"])
	top.add_child(_streak_label)
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
	hint.text = Kit.text("stack_hint", "Toca para soltar el bloque")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", UI.colors["texto_suave"])
	col.add_child(hint)


func _reset() -> void:
	finished = false
	failed = false
	coins = 0
	streak = 0
	perfects = 0
	drops = 0
	for c: Node in _blocks.get_children():
		c.queue_free()
	tower = [[0.0, start_width]]
	_add_block_node(0, 0.0, start_width)
	_next_mover()
	_cam_y = _top_y()
	_camera.position = Vector2(0.0, _cam_y - 200.0)
	_update_hud()


func _top_y() -> float:
	return -float(tower.size()) * BLOCK_H


## Color de cada piso: la paleta del juego con el tono girando poco a poco.
func layer_color(i: int) -> Color:
	var base: Color = Kit.color("accent", Color("#e8b04b"))
	return Color.from_hsv(fposmod(base.h + float(i) * 0.035, 1.0), clampf(base.s * 0.85, 0.35, 0.85), clampf(base.v, 0.55, 0.95))


func _block_poly(w: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(-w * 0.5, -BLOCK_H), Vector2(w * 0.5, -BLOCK_H), Vector2(w * 0.5, 0.0), Vector2(-w * 0.5, 0.0)])


func _add_block_node(i: int, x: float, w: float) -> Node2D:
	var n: Node2D = Node2D.new()
	n.position = Vector2(x, -float(i) * BLOCK_H)
	var face: Polygon2D = Polygon2D.new()
	face.polygon = _block_poly(w)
	face.color = layer_color(i)
	## Con la textura de la IA, cada piso es de ese material tenido con su color.
	if Kit.texture_polygon(face, BLOCK_H):
		face.color = layer_color(i).lerp(Color.WHITE, 0.3)
	n.add_child(face)
	var lip: Polygon2D = Polygon2D.new()
	lip.polygon = PackedVector2Array([Vector2(-w * 0.5, -BLOCK_H), Vector2(w * 0.5, -BLOCK_H), Vector2(w * 0.5, -BLOCK_H + 10.0), Vector2(-w * 0.5, -BLOCK_H + 10.0)])
	lip.color = layer_color(i).lightened(0.3)
	n.add_child(lip)
	_blocks.add_child(n)
	return n


func _next_mover() -> void:
	var top: Array = tower[tower.size() - 1]
	moving_w = float(top[1])
	moving_dir = 1.0 if tower.size() % 2 == 0 else -1.0
	moving_x = -moving_dir * (AREA_W * 0.5 + moving_w * 0.2)
	_mover.polygon = _block_poly(moving_w)
	_mover.color = layer_color(tower.size())
	if Kit.texture_polygon(_mover, BLOCK_H):
		_mover.color = layer_color(tower.size()).lerp(Color.WHITE, 0.45)
	_mover.position = Vector2(moving_x, _top_y())
	_hero.position = Vector2(float(top[0]), _top_y() + BLOCK_H)


func current_speed() -> float:
	return speed * (1.0 + ramp * float(tower.size() - 1)) * (1.0 if not fast else 1.0)


func _update_hud() -> void:
	_count_label.text = "%d/%d" % [tower.size() - 1, target]
	_streak_label.text = ("%s x%d" % [Kit.text("stack_perfect", "\u00a1Perfecto!"), streak]) if streak >= 2 else ""


# ------------------------------------------------------------------ reglas

func can_drop() -> bool:
	return not finished and not failed and not get_tree().paused


## Suelta el bloque donde esta. Devuelve lo que se ha quedado de ancho (0 = fallo).
func drop() -> float:
	if not can_drop():
		return -1.0
	var top: Array = tower[tower.size() - 1]
	var tx: float = float(top[0])
	var tw: float = float(top[1])
	var dx: float = moving_x - tx
	drops += 1
	if absf(dx) <= perfect_px:
		## 1 - Perfecto: encaja justo encima y crece un poco (hasta el ancho inicial).
		var w: float = minf(tw + 6.0, start_width)
		tower.append([tx, w])
		_add_block_node(tower.size() - 1, tx, w)
		streak += 1
		perfects += 1
		coins += 1
		Audio.play("coin", 0.05, 0.0, 1.0 + 0.06 * float(mini(streak, 10)))
		Juice.burst(self, Vector2(tx, _top_y() + BLOCK_H * 0.5), Kit.color("coin", Color.YELLOW), 14, 260.0)
		UI.float_text(self, Vector2(tx, _top_y() - 30.0), Kit.text("stack_perfect", "\u00a1Perfecto!"), UI.colors["acento"], 34)
	else:
		var left: float = maxf(moving_x - moving_w * 0.5, tx - tw * 0.5)
		var right: float = minf(moving_x + moving_w * 0.5, tx + tw * 0.5)
		var keep: float = right - left
		if keep <= 4.0:
			_fall_piece(moving_x, moving_w, tower.size())
			_lose()
			return 0.0
		var cx: float = (left + right) * 0.5
		tower.append([cx, keep])
		_add_block_node(tower.size() - 1, cx, keep)
		## 2 - Lo que sobresale cae girando.
		var cut_w: float = moving_w - keep
		var cut_x: float = (right + cut_w * 0.5) if dx > 0.0 else (left - cut_w * 0.5)
		_fall_piece(cut_x, cut_w, tower.size() - 1)
		streak = 0
		Audio.play("land", 0.1)
	Juice.shake(0.08)
	QA.log_event("stack_drop", {"height": tower.size() - 1, "dx": dx, "width": float(tower[tower.size() - 1][1])})
	_update_hud()
	if tower.size() - 1 >= target:
		_finish()
	else:
		_next_mover()
	return float(tower[tower.size() - 1][1])


func _fall_piece(x: float, w: float, layer: int) -> void:
	var piece: Polygon2D = Polygon2D.new()
	piece.polygon = _block_poly(w)
	piece.color = layer_color(layer).darkened(0.15)
	if Kit.texture_polygon(piece, BLOCK_H):
		piece.color = layer_color(layer).lerp(Color.WHITE, 0.3)
	piece.position = Vector2(x, -float(layer) * BLOCK_H)
	piece.z_index = 2
	add_child(piece)
	var tw: Tween = piece.create_tween()
	tw.set_parallel(true)
	tw.tween_property(piece, "position:y", piece.position.y + 900.0, 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(piece, "rotation", signf(x) * 1.4, 1.1)
	tw.tween_property(piece, "modulate:a", 0.0, 1.1)
	tw.chain().tween_callback(piece.queue_free)


func _process(delta: float) -> void:
	if finished or get_tree().paused:
		return
	time_in_level += delta
	if not failed:
		moving_x += moving_dir * current_speed() * delta
		var limit: float = AREA_W * 0.5 + moving_w * 0.2
		if absf(moving_x) > limit:
			moving_x = clampf(moving_x, -limit, limit)
			moving_dir = -moving_dir
		_mover.position = Vector2(moving_x, _top_y())
	## La camara sube con la torre.
	_cam_y = lerpf(_cam_y, _top_y(), 1.0 - exp(-4.0 * delta))
	_camera.position = Vector2(0.0, _cam_y - 160.0)


func _unhandled_input(event: InputEvent) -> void:
	if UI.test_mode:
		return
	var tap: bool = (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed) \
		or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) \
		or event.is_action_pressed("jump")
	if tap:
		drop()


# ------------------------------------------------------------------ final

func _finish() -> void:
	finished = true
	_mover.visible = false
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = target * 100 + perfects * 150 + int(float(tower[tower.size() - 1][1]))
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "perfects": perfects, "width": float(tower[tower.size() - 1][1]), "stars": stars})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


## 3 estrellas si llegas arriba con mas de la mitad del ancho (o la mitad de perfectos).
func stars_earned() -> int:
	var ratio: float = float(tower[tower.size() - 1][1]) / start_width
	if ratio >= 0.5 or perfects * 2 >= target:
		return 3
	if ratio >= 0.25 or perfects * 4 >= target:
		return 2
	return 1


func _lose() -> void:
	failed = true
	deaths += 1
	_mover.visible = false
	Audio.play("hurt")
	Juice.shake(0.4)
	QA.log_event("death", {"cause": "missed", "height": tower.size() - 1, "deaths": deaths})
	if auto_retry:
		retry()
		_mover.visible = true
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("stack_lost", "\u00a1Se cay\u00f3!"),
		Kit.text("stack_fail_hint", "Has llegado a {n} de {t}. Suelta cuando est\u00e9 encima").format({"n": tower.size() - 1, "t": target}))
	p.closed.connect(func() -> void:
		retry()
		_mover.visible = true)


## Segunda oportunidad (FailPanel, con anuncio): otro bloque sobre la torre que ya tenias.
func revive() -> void:
	failed = false
	finished = false
	_mover.visible = true
	_next_mover()
	_update_hud()


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
		"height": tower.size() - 1, "width": float(tower[tower.size() - 1][1]), "perfects": perfects}


func capture_delays() -> Vector2:
	return Vector2(5.0, 1.5)
