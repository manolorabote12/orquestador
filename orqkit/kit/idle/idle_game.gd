extends Node2D
## Clicker: toca para ganar monedas, contrata ayudantes que ganan solos y llega a la meta a tiempo.
## 1 - Tocar al heroe da el valor del toque. "Mejor toque" lo duplica (cada vez cuesta el doble).
## 2 - Cada ayudante gana por segundo; cada uno que compras del mismo tipo cuesta un 15 % mas.
## 3 - A veces cae una moneda de oro: tocarla da 10 s de lo que ganas por segundo (y cuenta como
##     moneda del nivel).
## 4 - Ganas al juntar la meta antes de que acabe el tiempo; si no, pierdes.
## Mapa: una fila por ayudante, "coste:ganancia por segundo" (p. ej. "15:1"). Nivel: {"map",
##   "target", "duration", "tap" (monedas por toque)}.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const REVIVE_SECS: float = 20.0
const GROWTH: float = 1.15
const GOLD_EVERY: float = 18.0
const GOLD_LIFE: float = 6.0
const TAP_UP_BASE: float = 40.0
## Turbo con anuncio (perfil idle, "boost"): todo x2 durante BOOST_SECS, una vez por intento.
const BOOST_SECS: float = 20.0

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

var target: float = 1000.0
var duration: float = 90.0
var tap_base: float = 1.0
## Ayudantes: {"cost", "cps", "owned"}
var helpers: Array[Dictionary] = []
var bank: float = 0.0
var earned: float = 0.0
var tap_value: float = 1.0
var tap_level: int = 0
var taps: int = 0
var gold_up: bool = false

var _gold_t: float = 0.0
var _gold_left: float = 0.0
var _gold: Node2D = null
var _hero: Node2D = null
var _camera: Camera2D
var _bank_label: Label
var _cps_label: Label
var _time_label: Label
var _goal_bar: ProgressBar
var _shop: VBoxContainer
var _shop_dirty: bool = true
var boost_left: float = 0.0
var boost_used: bool = false
var _boost_btn: Button


func _ready() -> void:
	var lv: Dictionary = Kit.current_level()
	for r: Variant in lv.get("map", ["15:1"]):
		rows.append(str(r))
	target = float(lv.get("target", 1000.0))
	duration = float(lv.get("duration", 90.0))
	tap_base = float(lv.get("tap", 1.0))
	RenderingServer.set_default_clear_color(Kit.color("sky", Color("#1b2a41")))
	var stage: Node2D = Node2D.new()
	stage.name = "Stage"
	stage.draw.connect(func() -> void:
		var c: Color = Kit.color("accent", Color("#ffb14a"))
		for k: int in 6:
			stage.draw_circle(Vector2.ZERO, 300.0 - 40.0 * float(k), Color(c, 0.05 + 0.02 * float(k)))
		stage.draw_set_transform(Vector2(0, 150), 0.0, Vector2(1.0, 0.25))
		stage.draw_circle(Vector2.ZERO, 170.0, Color(0, 0, 0, 0.3))
		stage.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE))
	add_child(stage)
	_hero = Node2D.new()
	_hero.name = "Hero"
	var art: Dictionary = Kit.sprite_by_role("jugador")
	if not art.is_empty():
		var spr: AnimatedSprite2D = SpriteKit.animado(art, 260.0, "idle", false)
		Skins.apply(spr)
		_hero.add_child(spr)
	else:
		var body: Polygon2D = Polygon2D.new()
		body.polygon = LevelBuilder._circle(110.0, 32)
		body.color = Kit.color("accent", Color.ORANGE)
		_hero.add_child(body)
	stage.add_child(_hero)
	_camera = Camera2D.new()
	add_child(_camera)
	_camera.make_current()
	Juice.register_camera(_camera)
	var vp: Vector2 = get_viewport_rect().size
	_camera.zoom = Vector2.ONE * minf(vp.x / 760.0, 1.4)
	## El heroe arriba; la tienda de ayudantes ocupa la mitad de abajo.
	_camera.position = Vector2(0.0, vp.y / _camera.zoom.y * 0.18)
	_build_hud()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "idle", "target": target, "helpers": helpers.size()})


func bot_script() -> String:
	return "res://qa/idle_bot.gd"


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
	top.add_child(UiIcon.make("coin", Kit.color("coin", UI.colors["acento"]), 44.0))
	_bank_label = Label.new()
	_bank_label.name = "Bank"
	_bank_label.theme_type_variation = "HeaderLabel"
	_bank_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_bank_label)
	_time_label = Label.new()
	_time_label.name = "Time"
	_time_label.add_theme_color_override("font_color", UI.colors["acento"])
	top.add_child(_time_label)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)
	_goal_bar = ProgressBar.new()
	_goal_bar.name = "Goal"
	_goal_bar.show_percentage = false
	_goal_bar.custom_minimum_size = Vector2(0.0, 22.0)
	_goal_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_goal_bar)
	_cps_label = Label.new()
	_cps_label.name = "Cps"
	_cps_label.theme_type_variation = "SubtleLabel"
	_cps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_cps_label)
	_boost_btn = UI.make_button(Kit.text("idle_boost", "x2 durante {s} s").format({"s": int(BOOST_SECS)}) + "  (" + Kit.text("ad_short", "anuncio") + ")", true, "play")
	_boost_btn.name = "BtnBoost"
	_boost_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_boost_btn.visible = false
	_boost_btn.pressed.connect(_on_boost)
	col.add_child(_boost_btn)
	var grow: Control = Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(grow)
	var panel: PanelContainer = PanelContainer.new()
	col.add_child(panel)
	_shop = VBoxContainer.new()
	_shop.name = "Shop"
	_shop.add_theme_constant_override("separation", 8)
	panel.add_child(_shop)


func _reset() -> void:
	finished = false
	failed = false
	time_in_level = 0.0
	bank = 0.0
	earned = 0.0
	taps = 0
	coins = 0
	tap_level = 0
	tap_value = tap_base
	gold_up = false
	boost_left = 0.0
	boost_used = false
	_gold_t = GOLD_EVERY * 0.6
	if _gold != null:
		_gold.queue_free()
		_gold = null
	helpers.clear()
	for r: String in rows:
		var parts: PackedStringArray = r.split(":")
		if parts.size() == 2:
			helpers.append({"cost": float(parts[0]), "cps": float(parts[1]), "owned": 0})
	coins_total = maxi(1, int(duration / GOLD_EVERY))
	_shop_dirty = true
	_update_hud()


func cps() -> float:
	var t: float = 0.0
	for h: Dictionary in helpers:
		t += float(h["cps"]) * float(h["owned"])
	return t


func helper_cost(i: int) -> float:
	var h: Dictionary = helpers[i]
	return ceilf(float(h["cost"]) * pow(GROWTH, float(h["owned"])))


func tap_cost() -> float:
	return ceilf(TAP_UP_BASE * tap_base * pow(2.5, float(tap_level)))


func helper_name(i: int) -> String:
	return Kit.text("idle_helper_%d" % (i + 1), ["Ayudante", "Taller", "M\u00e1quina", "F\u00e1brica", "Imperio", "Galaxia"][mini(i, 5)])


func _gain(v: float) -> void:
	bank += v
	earned += v
	if earned >= target and not finished:
		_finish()


## Un toque al heroe.
func tap() -> void:
	if finished or failed or get_tree().paused:
		return
	taps += 1
	_gain(tap_value)
	if _hero != null:
		Juice.squash(_hero, Vector2(1.12, 0.9))
	if taps % 3 == 0:
		UI.float_text(self, Vector2(randf_range(-80.0, 80.0), -200.0), "+%s" % _fmt(tap_value), Kit.color("coin", Color("#ffd447")), 30)
	Audio.play("coin", 0.08, -10.0)
	_update_hud()


func buy(i: int) -> bool:
	if finished or failed or i < 0 or i >= helpers.size() or bank < helper_cost(i):
		return false
	bank -= helper_cost(i)
	helpers[i]["owned"] = int(helpers[i]["owned"]) + 1
	Audio.play("powerup", 0.05)
	_shop_dirty = true
	_update_hud()
	return true


func buy_tap() -> bool:
	if finished or failed or bank < tap_cost():
		return false
	bank -= tap_cost()
	tap_level += 1
	tap_value = tap_base * pow(2.0, float(tap_level))
	Audio.play("powerup", 0.05)
	_shop_dirty = true
	_update_hud()
	return true


func grab_gold() -> bool:
	if _gold == null or finished or failed:
		return false
	var bonus: float = maxf(cps() * 10.0, tap_value * 20.0)
	_gain(bonus)
	coins += 1
	UI.float_text(self, _gold.position + Vector2(0, -60), "+%s" % _fmt(bonus), Color("#ffe066"), 38)
	Juice.burst(self, _gold.position, Color("#ffd447"), 14, 300.0)
	Audio.play("powerup")
	_gold.queue_free()
	_gold = null
	gold_up = false
	_update_hud()
	return true


func _spawn_gold() -> void:
	_gold = Node2D.new()
	_gold.name = "Gold"
	_gold.z_index = 5
	_gold.position = Vector2(randf_range(-260.0, 260.0), randf_range(-330.0, -120.0))
	var coin_art: Dictionary = Kit.sprite_entry(str(Kit.param("art.coin", "moneda")))
	if not coin_art.is_empty():
		var spr: AnimatedSprite2D = SpriteKit.animado(coin_art, 90.0, "spin", false)
		spr.modulate = Color(1.2, 1.1, 0.6)
		_gold.add_child(spr)
	else:
		_gold.draw.connect(func() -> void:
			_gold.draw_circle(Vector2.ZERO, 40.0, Color("#ffd447"))
			_gold.draw_circle(Vector2.ZERO, 28.0, Color("#ffb300")))
	add_child(_gold)
	_gold.scale = Vector2(0.2, 0.2)
	_gold.create_tween().tween_property(_gold, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	gold_up = true
	_gold_left = GOLD_LIFE


func _process(delta: float) -> void:
	if finished or failed or get_tree().paused:
		return
	time_in_level += delta
	if boost_left > 0.0:
		boost_left = maxf(0.0, boost_left - delta)
	_gain(cps() * delta * boost_mult())
	if finished:
		return
	_gold_t -= delta
	if _gold == null and _gold_t <= 0.0:
		_gold_t = GOLD_EVERY
		_spawn_gold()
	if _gold != null:
		_gold_left -= delta
		_gold.rotation = sin(time_in_level * 4.0) * 0.15
		if _gold_left <= 0.0:
			_gold.queue_free()
			_gold = null
			gold_up = false
	if int(time_in_level * 5.0) != int((time_in_level - delta) * 5.0):
		_update_hud()
	if time_in_level >= duration:
		_lose()


func boost_mult() -> float:
	return 2.0 if boost_left > 0.0 else 1.0


func can_boost() -> bool:
	return not boost_used and not finished and not failed and Monetize.rewarded_on("boost") and Ads.rewarded_available()


func _on_boost() -> void:
	if not can_boost():
		return
	_boost_btn.disabled = true
	var ok: Array[bool] = [false]
	var on_ok: Callable = func(pl: String) -> void:
		if pl == "boost":
			ok[0] = true
	Ads.reward_earned.connect(on_ok)
	await Ads.show_rewarded("boost")
	Ads.reward_earned.disconnect(on_ok)
	_boost_btn.disabled = false
	if ok[0]:
		boost_used = true
		boost_left = BOOST_SECS
		QA.log_event("boost", {"level": Kit.level_index})
		Audio.play("powerup")
	_update_hud()


func _update_hud() -> void:
	_bank_label.text = _fmt(bank)
	if _boost_btn != null:
		_boost_btn.visible = can_boost() or boost_left > 0.0
		_boost_btn.disabled = boost_left > 0.0
		if boost_left > 0.0:
			_boost_btn.text = Kit.text("idle_boosting", "x2 \u00b7 {s} s").format({"s": ceili(boost_left)})
	_time_label.text = "%d s" % ceili(maxf(duration - time_in_level, 0.0))
	_goal_bar.max_value = target
	_goal_bar.value = minf(earned, target)
	_cps_label.text = Kit.text("idle_goal", "Meta: {t}  \u00b7  {c}/s").format({"t": _fmt(target), "c": _rate(cps())})
	if _shop_dirty:
		_shop_dirty = false
		_rebuild_shop()
	for c: Node in _shop.get_children():
		var b: Button = c.get_node_or_null("Buy") as Button
		if b != null:
			var i: int = int(c.get_meta("helper", -1))
			b.disabled = bank < (tap_cost() if i < 0 else helper_cost(i))


func _rebuild_shop() -> void:
	for c: Node in _shop.get_children():
		_shop.remove_child(c)
		c.queue_free()
	_shop_row(-1, Kit.text("idle_tap", "Mejor toque") + "  x%s" % _fmt(tap_value * 2.0), tap_cost(), "star")
	for i: int in helpers.size():
		var h: Dictionary = helpers[i]
		_shop_row(i, "%s  (%d)  +%s/s" % [helper_name(i), int(h["owned"]), _rate(float(h["cps"]))], helper_cost(i), "grid")


func _shop_row(i: int, label: String, price: float, icon: String) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Tap" if i < 0 else "Helper%d" % i
	row.set_meta("helper", i)
	row.add_theme_constant_override("separation", 10)
	_shop.add_child(row)
	row.add_child(UiIcon.make(icon, UI.colors["acento"], 36.0))
	var l: Label = Label.new()
	l.text = label
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.clip_text = true
	row.add_child(l)
	var b: Button = UI.make_button(_fmt(price), true, "coin")
	b.name = "Buy"
	b.custom_minimum_size = Vector2(180.0, UI.MIN_TOUCH)
	b.pressed.connect(func() -> void:
		if i < 0:
			buy_tap()
		else:
			buy(i))
	row.add_child(b)


## Ganancia por segundo: con un decimal si es pequena y no entera (4,5/s).
static func _rate(v: float) -> String:
	if v < 100.0 and absf(v - roundf(v)) > 0.05:
		return "%.1f" % v
	return _fmt(v)


static func _fmt(v: float) -> String:
	if v >= 1000000.0:
		return "%.1fM" % (v / 1000000.0)
	if v >= 10000.0:
		return "%.1fK" % (v / 1000.0)
	return str(int(floor(v)))


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
	if _gold != null and world.distance_to(_gold.position) < 80.0:
		grab_gold()
	elif world.distance_to(Vector2.ZERO) < 230.0:
		tap()


# ------------------------------------------------------------------ final

func _finish() -> void:
	finished = true
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = int(earned) + int(maxf(duration - time_in_level, 0.0)) * 50
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "time": snappedf(time_in_level, 0.1), "taps": taps,
		"cps": snappedf(cps(), 0.1), "coins": coins, "stars": stars})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


## 3 estrellas llegando con el 40 % del tiempo de sobra, 2 con el 20 %, 1 por llegar.
func stars_earned() -> int:
	var left: float = (duration - time_in_level) / maxf(duration, 1.0)
	if left >= 0.4:
		return 3
	if left >= 0.2:
		return 2
	return 1


func _lose() -> void:
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "time", "earned": int(earned), "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("idle_time", "\u00a1Se acab\u00f3 el tiempo!"),
		Kit.text("idle_fail_hint", "Has juntado {n} de {t}. Contrata ayudantes antes. \u00a1Otra vez!").format({"n": _fmt(earned), "t": _fmt(target)}))
	p.closed.connect(retry)


## Segunda oportunidad (FailPanel, con anuncio): un rato mas para llegar a la meta.
func revive() -> void:
	duration += REVIVE_SECS
	failed = false
	_update_hud()


func revive_text() -> String:
	return Kit.text("revive_secs", "+{n} segundos").format({"n": int(REVIVE_SECS)})


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
		"earned": earned, "bank": bank, "cps": cps(), "taps": taps, "time": time_in_level}


func capture_delays() -> Vector2:
	return Vector2(14.0, 1.0)
