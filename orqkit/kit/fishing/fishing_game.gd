extends Node2D
## Pesca: el barco esta arriba y el anzuelo baja por el centro.
## 1 - Toca para soltar el anzuelo. Coge el primer pez que toque y sube con el.
## 2 - Las medusas cortan el sedal: el anzuelo vuelve sin nada y tarda un poco en estar listo.
## 3 - Pesca 'goal' peces antes de que se acabe el tiempo. Estrellas segun el tiempo que sobra.
## Las reglas del tiempo estan en fishing_map.gd (las mismas que usan el bot y el analizador):
## las franjas se mueven segun el reloj del nivel, no fotograma a fotograma.
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const REVIVE_SECS: float = 20.0
const MapRules = preload("res://kit/fishing/fishing_map.gd")
const CELL: float = 72.0
const LANE_H: float = 96.0
const TOP: float = 150.0

var rows: Array[String] = []
var speeds: Array[float] = []
var goal: int = 5
## Giro tormenta: las franjas aceleran con el tiempo.
var storm: float = 0.0
var time_limit: float = 60.0
var finished: bool = false
var failed: bool = false
var deaths: int = 0
var time_in_level: float = 0.0
var clock: float = 0.0
var fast: bool = false
var auto_retry: bool = false
var result_panel: ResultPanel
var caught: int = 0
var stings: int = 0
var taken: Dictionary = {}
## Anzuelo: "listo", "baja", "sube" o "pica" (medusa). Lo que va a pasar se sabe al soltar.
var hook_state: String = "listo"
var hook_depth: float = 0.0
var _plan: Array = []
var _drop_t: float = 0.0
var _free_at: float = 0.0
var _hooked_fish: bool = false

var _board: Node2D
var _camera: Camera2D
var _goal_label: Label
var _time_label: Label
var _boat: Node2D


func _ready() -> void:
	var lv: Dictionary = Kit.current_level()
	rows = MapRules.parse(lv)
	speeds = MapRules.speeds_of(lv, rows.size())
	goal = int(lv.get("goal", 5))
	time_limit = float(lv.get("time", 60.0))
	storm = float(lv.get("storm", 0.0))
	RenderingServer.set_default_clear_color(Kit.color("sky", Color("#9fd3ff")))
	_board = Node2D.new()
	_board.name = "Board"
	_board.draw.connect(_draw_board)
	add_child(_board)
	_build_boat()
	_camera = Camera2D.new()
	add_child(_camera)
	_camera.make_current()
	Juice.register_camera(_camera)
	_fit_camera()
	_build_hud()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "fishing", "rows": rows.size()})


func bot_script() -> String:
	return "res://qa/fishing_bot.gd"


func _width() -> float:
	return float(rows[0].length() if not rows.is_empty() else 8) * CELL


func _fit_camera() -> void:
	var w: float = _width()
	var h: float = TOP + float(rows.size()) * LANE_H + 40.0
	var vp: Vector2 = get_viewport_rect().size
	var z: float = minf(vp.x / w, vp.y * 0.85 / h)
	_camera.zoom = Vector2.ONE * minf(z, 1.3)
	_camera.position = Vector2(w * 0.5, h * 0.5 - 10.0)


func _build_boat() -> void:
	_boat = Node2D.new()
	_boat.name = "Boat"
	_boat.z_index = 4
	add_child(_boat)
	var hull: Polygon2D = Polygon2D.new()
	hull.color = Kit.color("accent", Color("#c0643c"))
	hull.polygon = PackedVector2Array([Vector2(-90, -10), Vector2(90, -10), Vector2(60, 26), Vector2(-60, 26)])
	_boat.add_child(hull)
	var art: Dictionary = Kit.sprite_by_role("jugador")
	if not art.is_empty():
		var spr: AnimatedSprite2D = SpriteKit.animado(art, 96.0, "idle", false)
		spr.position = Vector2(-20.0, -52.0)
		_boat.add_child(spr)
		Skins.apply(spr)


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
	top.add_child(UiIcon.make("coin", Kit.color("coin", UI.colors["acento"]), 40.0))
	_goal_label = Label.new()
	_goal_label.name = "Goal"
	_goal_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_goal_label)
	_time_label = Label.new()
	_time_label.name = "Time"
	top.add_child(_time_label)
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
	hint.text = Kit.text("fishing_hint", "Toca para soltar el anzuelo. \u00a1Cuidado con las medusas!")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", UI.colors["texto_suave"])
	col.add_child(hint)


func _reset() -> void:
	finished = false
	failed = false
	clock = 0.0
	caught = 0
	stings = 0
	taken.clear()
	hook_state = "listo"
	hook_depth = 0.0
	_free_at = 0.0
	_boat.position = Vector2(_width() * 0.5, TOP - 30.0)
	_update_hud()
	_board.queue_redraw()


func _update_hud() -> void:
	_goal_label.text = "%d/%d" % [caught, goal]
	_time_label.text = "%d s" % ceili(maxf(0.0, time_limit - clock))


# ------------------------------------------------------------------ reglas

func can_drop() -> bool:
	return not finished and not failed and hook_state == "listo" and clock >= _free_at and not get_tree().paused


## Suelta el anzuelo ahora. Lo que pescara ya se sabe (drop_result); se anima hasta llegar.
func drop() -> bool:
	if not can_drop():
		return false
	_drop_t = clock
	_plan = MapRules.drop_result(rows, speeds, clock, taken, storm)
	hook_state = "baja"
	_hooked_fish = false
	Audio.play("click", 0.05, -4.0)
	return true


## Lo que pasaria si se soltara ahora (el bot lo mira antes de tocar).
func preview() -> String:
	return str(MapRules.drop_result(rows, speeds, clock, taken, storm)[0])


func _physics_process(delta: float) -> void:
	if finished or failed or get_tree().paused:
		return
	time_in_level += delta
	clock += delta
	match hook_state:
		"baja":
			hook_depth = (clock - _drop_t) * MapRules.DESCEND
			var stop_t: float = float(_plan[3])
			if clock >= stop_t:
				hook_depth = float(int(_plan[1])) + 0.5
				_on_reach()
		"sube", "pica":
			hook_depth = maxf(0.0, hook_depth - delta * MapRules.RISE)
			if hook_depth <= 0.0:
				hook_state = "listo"
				if _hooked_fish:
					_hooked_fish = false
					caught += 1
					Audio.play("coin", 0.1, -2.0)
					Juice.shake(0.08)
					if caught >= goal:
						_finish()
						return
	if clock >= time_limit and not finished:
		_lose()
		return
	_update_hud()
	_board.queue_redraw()


func _on_reach() -> void:
	var what: String = str(_plan[0])
	if what == "pez":
		taken[Vector2i(int(_plan[2]), int(_plan[1]))] = true
		_hooked_fish = true
		hook_state = "sube"
		_free_at = MapRules.back_at(int(_plan[1]), float(_plan[3]))
		Audio.play("powerup", 0.1, -6.0)
	elif what == "medusa":
		stings += 1
		hook_state = "pica"
		_free_at = MapRules.back_at(int(_plan[1]), float(_plan[3])) + MapRules.STING_PENALTY
		Audio.play("hurt", 0.05, -4.0)
		Juice.shake(0.2)
	else:
		hook_state = "sube"
		_free_at = MapRules.back_at(int(_plan[1]), float(_plan[3]))


func _unhandled_input(event: InputEvent) -> void:
	if UI.test_mode:
		return
	if (event is InputEventScreenTouch or event is InputEventMouseButton) and event.pressed:
		drop()
	elif event.is_action_pressed("ui_accept"):
		drop()


# ------------------------------------------------------------------ final

func _finish() -> void:
	finished = true
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = caught * 150 + int(maxf(0.0, time_limit - clock) * 20.0) - stings * 50
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "caught": caught, "stings": stings, "deaths": deaths, "stars": stars})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": caught, "coins_total": goal, "score": maxi(score, 0), "record": record})
	await Ads.show_interstitial("level_end")


func stars_earned() -> int:
	var left: float = (time_limit - clock) / time_limit
	if left >= 0.4 and stings == 0:
		return 3
	return 2 if left >= 0.2 else 1


func _lose() -> void:
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "time", "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("fishing_lost", "\u00a1Se acab\u00f3 el tiempo!"),
		Kit.text("fishing_fail_hint", "Has pescado {n} de {t}. Suelta justo antes de que pase el pez.").replace("{n}", str(caught)).replace("{t}", str(goal)))
	p.closed.connect(retry)


## Segunda oportunidad (FailPanel, con anuncio): un rato mas de pesca.
func revive() -> void:
	time_limit += REVIVE_SECS
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
	return {"pos": Vector2(0.0, hook_depth), "deaths": deaths, "coins": caught, "finished": finished, "failed": failed, "stomps": 0}


# ------------------------------------------------------------------ dibujo

func _lane_y(lane: float) -> float:
	return TOP + lane * LANE_H


func _draw_board() -> void:
	var w: float = _width()
	var water: Color = Kit.color("solid", Color("#2d6fb3"))
	var fish_c: Color = Kit.color("coin", Color("#f2a541"))
	var jelly: Color = Kit.color("danger", Color("#ff7ab8"))
	for lane: int in rows.size():
		var y: float = _lane_y(float(lane))
		_board.draw_rect(Rect2(0.0, y, w, LANE_H), water.darkened(0.08 * float(lane)))
		var n: int = rows[lane].length()
		for x: int in n:
			var ch: String = rows[lane][x]
			if ch == "." or taken.has(Vector2i(x, lane)):
				continue
			var p: float = MapRules.pos_at(x, speeds[lane], clock, n, storm) * CELL + CELL * 0.5
			for wrap: float in [0.0, -w, w]:
				var c: Vector2 = Vector2(p + wrap, y + LANE_H * 0.5)
				if c.x < -CELL or c.x > w + CELL:
					continue
				if ch == "F":
					var dir: float = signf(speeds[lane])
					_board.draw_colored_polygon(_ellipse(c, CELL * 0.42, CELL * 0.24), fish_c)
					_board.draw_colored_polygon(PackedVector2Array([c - Vector2(dir * CELL * 0.35, 0.0), c - Vector2(dir * CELL * 0.62, -CELL * 0.2),
						c - Vector2(dir * CELL * 0.62, CELL * 0.2)]), fish_c.darkened(0.2))
					_board.draw_circle(c + Vector2(dir * CELL * 0.22, -CELL * 0.05), 5.0, Color("#1a1a1a"))
				else:
					_board.draw_colored_polygon(_ellipse(c - Vector2(0.0, 8.0), CELL * 0.34, CELL * 0.26), jelly)
					for k: int in 4:
						var tx: float = c.x - CELL * 0.24 + float(k) * CELL * 0.16
						_board.draw_line(Vector2(tx, c.y + 8.0), Vector2(tx + sin(clock * 4.0 + float(k)) * 6.0, c.y + 34.0), jelly, 3.0)
	_board.draw_rect(Rect2(0.0, TOP - 6.0, w, 8.0), water.lightened(0.35))
	if storm > 0.0:
		## Lluvia: lineas que caen (mas cuanto mas avanza la tormenta).
		var drops: int = 10 + mini(30, int(clock))
		for k: int in drops:
			var rx: float = fposmod(float(k) * 97.0 + clock * 140.0, w)
			var ry: float = fposmod(float(k) * 53.0 + clock * 520.0, TOP + float(rows.size()) * LANE_H)
			_board.draw_line(Vector2(rx, ry), Vector2(rx - 6.0, ry + 18.0), Color(0.8, 0.9, 1.0, 0.45), 2.0)
	var hx: float = w * 0.5
	var hy: float = TOP + hook_depth * LANE_H
	_board.draw_line(Vector2(hx, TOP - 40.0), Vector2(hx, hy), Color(1, 1, 1, 0.8), 2.0)
	_board.draw_arc(Vector2(hx + 8.0, hy), 10.0, 0.0, PI, 10, Color("#d9d9d9"), 4.0)
	if _hooked_fish:
		_board.draw_colored_polygon(_ellipse(Vector2(hx, hy + 22.0), CELL * 0.24, CELL * 0.4), fish_c)


func _ellipse(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in 16:
		var a: float = TAU * float(i) / 16.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts
