extends Node2D
## Fusion: suelta piezas en columnas y junta las iguales.
## 1 - Toca una columna para soltar la pieza que toca (abajo ves la siguiente).
## 2 - Las piezas iguales que se tocan se juntan en una mayor (2+2 = 4, 4+4 = 8...), en cadena.
## 3 - Consigue la pieza meta. Si no cabe la pieza en ninguna columna, se acaba (una muerte).
## 4 - Estrellas segun las jugadas comparadas con las del bot (par_moves).
## Las reglas estan en merge_map.gd (las mismas que usan el bot y el analizador).
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const MapRules = preload("res://kit/merge/merge_map.gd")
const CELL: float = 120.0

var w: int = 5
var h: int = 7
var start_cells: Array[int] = []
var cells: Array[int] = []
var seq: Array[int] = []
var goal: int = 6
var par_moves: int = 30
var moves: int = 0
var finished: bool = false
var failed: bool = false
var deaths: int = 0
var time_in_level: float = 0.0
var fast: bool = false
var auto_retry: bool = false
var result_panel: ResultPanel

var _board: Node2D
var _camera: Camera2D
var _goal_label: Label
var _next_label: Label
var _pop: Dictionary = {}
var _busy: float = 0.0


func _ready() -> void:
	var lv: Dictionary = Kit.current_level()
	var p: Array = MapRules.parse(lv)
	w = int(p[0])
	h = int(p[1])
	start_cells = p[2]
	seq = MapRules.seq_of(lv)
	goal = int(lv.get("goal", 6))
	par_moves = int(lv.get("par_moves", 30))
	RenderingServer.set_default_clear_color(Kit.color("sky", Color("#20203a")))
	_board = Node2D.new()
	_board.name = "Board"
	_board.draw.connect(_draw_board)
	add_child(_board)
	_camera = Camera2D.new()
	add_child(_camera)
	_camera.make_current()
	Juice.register_camera(_camera)
	_fit_camera()
	_build_hud()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "merge", "rows": h})


func bot_script() -> String:
	return "res://qa/merge_bot.gd"


## Fotos de la tienda: con el tablero a medio llenar (el bot gana el primer nivel muy rapido).
func capture_delays() -> Vector2:
	return Vector2(0.5, 0.35)


func _fit_camera() -> void:
	var bw: float = float(w) * CELL
	var bh: float = float(h + 1) * CELL
	var vp: Vector2 = get_viewport_rect().size
	var z: float = minf(vp.x / (bw + CELL * 0.4), vp.y * 0.78 / (bh + CELL))
	_camera.zoom = Vector2.ONE * minf(z, 1.2)
	_camera.position = Vector2(bw * 0.5, bh * 0.5)


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
	_goal_label = Label.new()
	_goal_label.name = "Goal"
	_goal_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_goal_label)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)
	var grow: Control = Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(grow)
	_next_label = Label.new()
	_next_label.name = "Next"
	_next_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_next_label.add_theme_color_override("font_color", UI.colors["texto_suave"])
	col.add_child(_next_label)


func _reset() -> void:
	finished = false
	failed = false
	cells = start_cells.duplicate()
	moves = 0
	_pop.clear()
	_update_hud()
	_board.queue_redraw()


static func label_of(v: int) -> String:
	return str(1 << v)


func current_piece() -> int:
	return seq[moves % seq.size()]


func next_piece() -> int:
	return seq[(moves + 1) % seq.size()]


func _update_hud() -> void:
	_goal_label.text = Kit.text("merge_goal", "Meta: {g}").replace("{g}", label_of(goal))
	_next_label.text = Kit.text("merge_next", "Siguiente: {n}").replace("{n}", label_of(next_piece()))


# ------------------------------------------------------------------ reglas

func can_drop() -> bool:
	return not finished and not failed and _busy <= 0.0 and not get_tree().paused


## Suelta la pieza actual en la columna 'col'. false si esa columna esta llena.
func drop_in(col: int) -> bool:
	if not can_drop() or col < 0 or col >= w:
		return false
	var before: int = MapRules.max_value(cells)
	var r: Array = MapRules.drop(cells, w, h, col, current_piece())
	if r.is_empty():
		Juice.shake(0.1)
		return false
	cells = r[0]
	moves += 1
	_busy = 0.03 if fast else 0.12
	var merges: int = int(r[1])
	_pop = {int(r[2]): 0.25}
	if r.size() > 3 and int(r[3]) > 0:
		Audio.play("stomp", 0.1, -4.0)
		Juice.shake(0.15)
	if merges > 0:
		Audio.play("coin", 0.05, -6.0, 1.0 + 0.08 * float(mini(merges, 6)))
		Juice.shake(0.05 * float(mini(merges, 4)))
	else:
		Audio.play("land", 0.1, -8.0)
	if MapRules.max_value(cells) > before and MapRules.max_value(cells) >= 4:
		Audio.play("powerup", 0.05, -6.0)
	_update_hud()
	_board.queue_redraw()
	if MapRules.max_value(cells) >= goal:
		_finish()
		return true
	var any: bool = false
	for c: int in w:
		if MapRules.top_free(cells, w, h, c) >= 0:
			any = true
			break
	if not any:
		_lose()
	return true


func _physics_process(delta: float) -> void:
	if finished:
		return
	time_in_level += delta
	_busy -= delta
	if not _pop.is_empty():
		for k: Variant in _pop.keys():
			_pop[k] = float(_pop[k]) - delta
			if float(_pop[k]) <= 0.0:
				_pop.erase(k)
		_board.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if UI.test_mode:
		return
	if (event is InputEventScreenTouch or event is InputEventMouseButton) and event.pressed:
		var world: Vector2 = get_canvas_transform().affine_inverse() * (event.position as Vector2)
		drop_in(int(floorf(world.x / CELL)))


# ------------------------------------------------------------------ final

func _finish() -> void:
	finished = true
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var score: int = maxi(0, (1 << goal) * 10 - moves * 15)
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "moves": moves, "deaths": deaths, "stars": stars})
	Audio.play("win")
	Audio.play_track("victoria", false)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": 0, "coins_total": 0, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


func stars_earned() -> int:
	if moves <= int(float(par_moves) * 1.3) + 2:
		return 3
	return 2 if moves <= int(float(par_moves) * 1.8) + 4 else 1


func _lose() -> void:
	failed = true
	deaths += 1
	QA.log_event("death", {"cause": "full", "deaths": deaths})
	Audio.play("hurt")
	if auto_retry:
		retry()
		return
	var p: FailPanel = FailPanel.open(self, Kit.text("merge_lost", "\u00a1No caben m\u00e1s!"),
		Kit.text("merge_fail_hint", "Junta las piezas grandes abajo y deja sitio arriba."))
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
	return {"pos": Vector2(float(moves), 0.0), "deaths": deaths, "coins": 0, "finished": finished, "failed": failed, "stomps": 0}


# ------------------------------------------------------------------ dibujo

## Color de cada valor: de la paleta del juego hacia tonos mas vivos segun sube.
func _color_of(v: int) -> Color:
	var a: Color = Kit.color("accent", Color("#f2a541"))
	var b: Color = Kit.color("danger", Color("#e8485f"))
	var c: Color = Kit.color("solid", Color("#4b7bd6"))
	var t: float = float((v - 1) % 6) / 5.0
	var base: Color = c.lerp(a, t) if v <= 6 else a.lerp(b, float(v - 6) / 4.0)
	return base


var _tier_tex: Dictionary = {}


## Objeto dibujado por la fabrica para el valor v (fusion_1..fusion_8) o null.
func tier_texture(v: int) -> Texture2D:
	if v < 1 or v > 8:
		return null
	if not _tier_tex.has(v):
		var tex: Texture2D = null
		var entry: Dictionary = Kit.sprite_entry("fusion_%d" % v)
		if not entry.is_empty():
			var sf: SpriteFrames = SpriteKit.frames_de(entry)
			for an: String in sf.get_animation_names():
				if sf.get_frame_count(an) > 0:
					tex = sf.get_frame_texture(an, 0)
					break
		_tier_tex[v] = tex
	return _tier_tex[v] as Texture2D


func _draw_board() -> void:
	var font: Font = UI.theme.default_font if UI.theme and UI.theme.default_font else ThemeDB.fallback_font
	var cell_bg: Color = Kit.color("sky", Color("#20203a")).lightened(0.08)
	var top: float = CELL
	## Pieza que toca ahora, encima del tablero.
	var now: int = current_piece()
	var nc: Vector2 = Vector2(float(w) * CELL * 0.5, CELL * 0.5)
	_board.draw_circle(nc, CELL * 0.36, _color_of(now))
	var now_art: Texture2D = tier_texture(now)
	if now_art != null:
		_board.draw_texture_rect(now_art, Rect2(nc - Vector2.ONE * CELL * 0.3, Vector2.ONE * CELL * 0.6), false)
	else:
		_board.draw_string(font, nc + Vector2(-CELL * 0.35, 14.0), label_of(now), HORIZONTAL_ALIGNMENT_CENTER, CELL * 0.7, 38, Color.WHITE)
	for y: int in h:
		for x: int in w:
			var r: Rect2 = Rect2(Vector2(float(x) * CELL, top + float(y) * CELL), Vector2(CELL, CELL)).grow(-5.0)
			_board.draw_rect(r, cell_bg)
			var v: int = cells[y * w + x]
			if v == -1:
				## Piedra: se rompe con una fusion al lado.
				var sr: Rect2 = r.grow(-4.0)
				_board.draw_rect(sr, Color("#6b6f7a"))
				_board.draw_line(sr.position + Vector2(sr.size.x * 0.2, sr.size.y * 0.3), sr.get_center(), Color("#4a4d55"), 4.0)
				_board.draw_line(sr.get_center(), sr.position + Vector2(sr.size.x * 0.75, sr.size.y * 0.8), Color("#4a4d55"), 4.0)
				continue
			if v <= 0:
				continue
			var grow_by: float = 6.0 if _pop.has(y * w + x) else 0.0
			var pr: Rect2 = r.grow(grow_by - 4.0)
			_board.draw_rect(pr, _color_of(v))
			_board.draw_rect(Rect2(pr.position, Vector2(pr.size.x, 8.0)), _color_of(v).lightened(0.25))
			var art: Texture2D = tier_texture(v)
			if art != null:
				## Con arte: el objeto dibujado y su valor pequeno en la esquina.
				var side: float = pr.size.x * 0.86
				var asp: float = float(art.get_width()) / maxf(1.0, float(art.get_height()))
				var sz2: Vector2 = Vector2(side, side / asp) if asp >= 1.0 else Vector2(side * asp, side)
				_board.draw_texture_rect(art, Rect2(pr.get_center() - sz2 * 0.5, sz2), false)
				_board.draw_string(font, pr.position + Vector2(6, pr.size.y - 8), label_of(v), HORIZONTAL_ALIGNMENT_LEFT, pr.size.x - 8, 20, Color(1, 1, 1, 0.9))
			else:
				var size: int = 44 if v < 7 else (36 if v < 10 else 28)
				_board.draw_string(font, Vector2(pr.position.x, pr.get_center().y + float(size) * 0.36), label_of(v),
					HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, size, Color.WHITE)
			if v >= goal:
				_board.draw_rect(pr, Color("#ffffff"), false, 4.0)
