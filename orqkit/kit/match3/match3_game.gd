extends Node2D
## Genero puzle de combinar 3. Tablero, piezas con forma y color propios (se distinguen sin
## color), especiales, hielo, movimientos limitados y objetivo de puntos con 3 estrellas.
## 1 - Arrastra una pieza hacia su vecina (o toca una y luego la otra) para cambiarlas.
## 2 - Si no es jugada valida, las piezas se sacuden y no gasta movimiento.
## 3 - Ganas al llegar a los puntos (y romper todo el hielo si lo hay); los movimientos que
##     sobran suman extra. Sin movimientos: ventana de reintentar (cuenta como muerte).
## El nivel (game.json -> levels[i]) trae: map, moves, colors y goal_factor (dificultad).

## Puntos por movimiento que saca el bot en el peor 10 % de partidas (calibrado con 40 partidas).
const PER_MOVE: Dictionary = {4: 1700.0, 5: 480.0, 6: 245.0}
const HUES: Array[float] = [0.0, 0.08, 0.15, 0.36, 0.58, 0.79]

var logic: Match3Logic = Match3Logic.new()
var level_map: Array = []
var moves_total: int = 20
var moves_left: int = 20
var target: int = 2000
var finished: bool = false
var busy: bool = false
var deaths: int = 0
var swaps_done: int = 0
var time_in_level: float = 0.0
var auto_retry: bool = false
var cell: float = 96.0
var origin: Vector2 = Vector2.ZERO
var result_panel: ResultPanel

var _pieces: Dictionary = {}
var _ice_nodes: Dictionary = {}
var _board: Node2D
var _fx: Node2D
var _seed: int = 1
var _drag_from: Vector2i = Vector2i(-1, -1)
var _drag_start: Vector2 = Vector2.ZERO
var _selected: Vector2i = Vector2i(-1, -1)
var _moves_label: Label
var _score_label: Label
var _ice_label: Label
var _bar_fill: ColorRect
var _bar_back: ColorRect


func _ready() -> void:
	var lv: Dictionary = Kit.current_level()
	level_map = lv.get("map", [])
	moves_total = int(lv.get("moves", 20))
	var n_colors: int = clampi(int(lv.get("colors", 5)), 4, 6)
	target = goal_for(moves_total, n_colors, float(lv.get("goal_factor", 0.8)))
	_seed = 4242 + Kit.level_index * 101
	RenderingServer.set_default_clear_color(Kit.color("sky", Color("#1b2a41")))
	_board = Node2D.new()
	_board.name = "Board"
	add_child(_board)
	_fx = Node2D.new()
	_fx.name = "Fx"
	add_child(_fx)
	logic.setup(level_map, n_colors, _seed)
	moves_left = moves_total
	_build_hud()
	_layout()
	get_viewport().size_changed.connect(_layout)
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "match3", "moves": moves_total, "target": target})


static func goal_for(moves: int, n_colors: int, factor: float) -> int:
	var raw: float = float(moves) * float(PER_MOVE.get(n_colors, 480.0)) * factor
	return int(round(raw / 50.0) * 50.0)


## Bandera para los bots: este juego se juega con Match3Bot.
func match3_bot_step() -> void:
	pass


func _process(delta: float) -> void:
	if not finished:
		time_in_level += delta


# ------------------------------------------------------------------ dibujo

func _layout() -> void:
	var vs: Vector2 = get_viewport().get_visible_rect().size
	var top: float = 330.0
	cell = floorf(minf((vs.x - 40.0) / float(logic.w), (vs.y - top - 70.0) / float(logic.h)))
	origin = Vector2((vs.x - cell * float(logic.w)) * 0.5, top + (vs.y - top - 70.0 - cell * float(logic.h)) * 0.5)
	_rebuild()


func cell_pos(c: Vector2i) -> Vector2:
	return origin + (Vector2(c) + Vector2(0.5, 0.5)) * cell


func cell_at(p: Vector2) -> Vector2i:
	var q: Vector2 = (p - origin) / cell
	var c: Vector2i = Vector2i(int(floor(q.x)), int(floor(q.y)))
	return c if logic.playable(c) else Vector2i(-1, -1)


func _rebuild() -> void:
	for n: Node in _board.get_children():
		n.queue_free()
	_pieces.clear()
	_ice_nodes.clear()
	var sky: Color = Kit.color("sky", Color("#1b2a41"))
	## Marco del tablero: un panel con borde y sombra detras de las casillas.
	var tl: Vector2 = cell_pos(Vector2i(0, 0)) - Vector2(cell, cell) * 0.5
	var br: Vector2 = cell_pos(Vector2i(logic.w - 1, logic.h - 1)) + Vector2(cell, cell) * 0.5
	for k: int in 3:
		var pan: Polygon2D = Polygon2D.new()
		var grow: float = [cell * 0.32, cell * 0.22, cell * 0.12][k]
		var hs: Vector2 = (br - tl) * 0.5 + Vector2(grow, grow)
		pan.polygon = PackedVector2Array([Vector2(-hs.x, -hs.y), Vector2(hs.x, -hs.y), Vector2(hs.x, hs.y), Vector2(-hs.x, hs.y)])
		pan.position = (tl + br) * 0.5 + (Vector2(0, cell * 0.12) if k == 0 else Vector2.ZERO)
		pan.color = [Color(0, 0, 0, 0.35), Kit.color("accent", Color("#e8b04b")).darkened(0.35), sky.darkened(0.35)][k]
		_board.add_child(pan)
	for y: int in logic.h:
		for x: int in logic.w:
			var c: Vector2i = Vector2i(x, y)
			if not logic.playable(c):
				continue
			var bg: Polygon2D = Polygon2D.new()
			bg.polygon = _rounded(cell * 0.47, cell * 0.12)
			bg.color = sky.lightened(0.12 if (x + y) % 2 == 0 else 0.08)
			bg.position = cell_pos(c)
			_board.add_child(bg)
			if logic.ice[logic.idx(c)] == 1:
				var ice_n: Polygon2D = Polygon2D.new()
				ice_n.polygon = _rounded(cell * 0.45, cell * 0.12)
				ice_n.color = Color(0.75, 0.9, 1.0, 0.55)
				ice_n.position = cell_pos(c)
				ice_n.z_index = 1
				_board.add_child(ice_n)
				_ice_nodes[logic.idx(c)] = ice_n
	for y: int in logic.h:
		for x: int in logic.w:
			var c2: Vector2i = Vector2i(x, y)
			if logic.playable(c2) and logic.color[logic.idx(c2)] >= 0:
				_put_piece(c2, cell_pos(c2))
	_update_hud()


func _put_piece(c: Vector2i, at: Vector2) -> Node2D:
	var i: int = logic.idx(c)
	var node: Node2D = make_piece(logic.color[i], logic.special[i], cell)
	node.position = at
	node.z_index = 2
	_board.add_child(node)
	_pieces[i] = node
	return node


## Pieza vectorial: cada color tiene su forma (circulo, rombo, cuadrado, triangulo, estrella,
## hexagono) para que se distingan tambien sin ver colores.
static var _piece_tex: Dictionary = {}


## Pieza dibujada por la fabrica (pieza_0..pieza_5) o null si el juego no la tiene.
static func piece_texture(k: int) -> Texture2D:
	var key: int = k % 6
	if not _piece_tex.has(key):
		var tex: Texture2D = null
		var entry: Dictionary = Kit.sprite_entry("pieza_%d" % key)
		if not entry.is_empty():
			var sf: SpriteFrames = SpriteKit.frames_de(entry)
			for an: String in sf.get_animation_names():
				if sf.get_frame_count(an) > 0:
					tex = sf.get_frame_texture(an, 0)
					break
		_piece_tex[key] = tex
	return _piece_tex[key] as Texture2D


static func make_piece(k: int, s: int, size: float) -> Node2D:
	var root: Node2D = Node2D.new()
	root.set_meta("k", k)
	root.set_meta("s", s)
	var r: float = size * 0.36
	var art: Texture2D = piece_texture(k) if s != Match3Logic.BOMB else null
	if art != null:
		## Con arte: la pieza dibujada sobre su sombra; las especiales llevan sus marcas encima.
		var sh: Polygon2D = Polygon2D.new()
		sh.polygon = LevelBuilder._circle(r * 0.95, 20)
		sh.scale = Vector2(1.0, 0.45)
		sh.position = Vector2(0, r * 0.95)
		sh.color = Color(0, 0, 0, 0.28)
		root.add_child(sh)
		var spr: Sprite2D = Sprite2D.new()
		spr.texture = art
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var side: float = maxf(1.0, float(maxi(art.get_width(), art.get_height())))
		spr.scale = Vector2.ONE * (r * 2.35 / side)
		root.add_child(spr)
		_special_marks(root, s, r, size)
		return root
	var col: Color = Color.from_hsv(HUES[k % HUES.size()], 0.68, 0.96)
	var shape: PackedVector2Array = _shape(k, r)
	if s == Match3Logic.BOMB:
		col = Color(0.12, 0.12, 0.16)
		shape = LevelBuilder._circle(r, 24)
	## Aspecto de gema (12 nov: eran formas planas): sombra debajo, cuerpo, faceta clara arriba y brillo.
	var shadow: Polygon2D = Polygon2D.new()
	shadow.polygon = shape
	shadow.color = Color(0, 0, 0, 0.32)
	shadow.position = Vector2(0, r * 0.14)
	root.add_child(shadow)
	var body: Polygon2D = Polygon2D.new()
	body.polygon = shape
	body.color = col
	root.add_child(body)
	if s != Match3Logic.BOMB:
		var low: Polygon2D = Polygon2D.new()
		low.polygon = shape
		low.color = col.darkened(0.22)
		low.scale = Vector2(0.86, 0.86)
		low.position = Vector2(0, r * 0.1)
		root.add_child(low)
		var facet: Polygon2D = Polygon2D.new()
		facet.polygon = shape
		facet.color = col.lightened(0.22)
		facet.scale = Vector2(0.66, 0.66)
		facet.position = Vector2(0, -r * 0.1)
		root.add_child(facet)
	var edge: Line2D = Line2D.new()
	var pts: PackedVector2Array = shape.duplicate()
	pts.append(shape[0])
	edge.points = pts
	edge.width = maxf(3.0, size * 0.04)
	edge.default_color = col.darkened(0.45)
	root.add_child(edge)
	var shine: Polygon2D = Polygon2D.new()
	shine.polygon = LevelBuilder._circle(r * 0.22, 12)
	shine.scale = Vector2(1.5, 0.8)
	shine.rotation = -0.6
	shine.position = Vector2(-r * 0.32, -r * 0.42)
	shine.color = Color(1, 1, 1, 0.6)
	root.add_child(shine)
	var dot2: Polygon2D = Polygon2D.new()
	dot2.polygon = LevelBuilder._circle(r * 0.07, 8)
	dot2.position = Vector2(r * 0.05, -r * 0.62)
	dot2.color = Color(1, 1, 1, 0.8)
	root.add_child(dot2)
	_special_marks(root, s, r, size)
	return root


static func _special_marks(root: Node2D, s: int, r: float, size: float) -> void:
	match s:
		Match3Logic.ROW, Match3Logic.COL:
			for off: float in [-0.28, 0.28]:
				var st: Polygon2D = Polygon2D.new()
				var half: Vector2 = Vector2(r * 0.95, r * 0.09) if s == Match3Logic.ROW else Vector2(r * 0.09, r * 0.95)
				var o: Vector2 = Vector2(0.0, off * r) if s == Match3Logic.ROW else Vector2(off * r, 0.0)
				st.polygon = PackedVector2Array([o - half, o + Vector2(half.x, -half.y), o + half, o + Vector2(-half.x, half.y)])
				st.color = Color(1, 1, 1, 0.9)
				root.add_child(st)
		Match3Logic.WRAP:
			var ring: Line2D = Line2D.new()
			var circ: PackedVector2Array = LevelBuilder._circle(r * 1.12, 28)
			circ.append(circ[0])
			ring.points = circ
			ring.width = maxf(4.0, size * 0.05)
			ring.default_color = Color(1, 1, 1, 0.9)
			root.add_child(ring)
		Match3Logic.BOMB:
			for j: int in 6:
				var dot: Polygon2D = Polygon2D.new()
				dot.polygon = LevelBuilder._circle(r * 0.16, 8)
				var a: float = TAU * float(j) / 6.0
				dot.position = Vector2(cos(a), sin(a)) * r * 0.55
				dot.color = Color.from_hsv(HUES[j], 0.7, 1.0)
				root.add_child(dot)


static func _shape(k: int, r: float) -> PackedVector2Array:
	match k % 6:
		0:
			return LevelBuilder._circle(r, 24)
		1:
			return PackedVector2Array([Vector2(0, -r * 1.1), Vector2(r * 0.9, 0), Vector2(0, r * 1.1), Vector2(-r * 0.9, 0)])
		2:
			return _rounded(r * 0.92, r * 0.25)
		3:
			return PackedVector2Array([Vector2(0, -r * 1.05), Vector2(r * 1.05, r * 0.8), Vector2(-r * 1.05, r * 0.8)])
		4:
			var star: PackedVector2Array = PackedVector2Array()
			for i: int in 10:
				var a: float = -PI * 0.5 + PI * float(i) / 5.0
				var rr: float = r * (1.1 if i % 2 == 0 else 0.5)
				star.append(Vector2(cos(a), sin(a)) * rr)
			return star
	var hexa: PackedVector2Array = PackedVector2Array()
	for i2: int in 6:
		var a2: float = PI / 6.0 + TAU * float(i2) / 6.0
		hexa.append(Vector2(cos(a2), sin(a2)) * r)
	return hexa


static func _rounded(half: float, rad: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for corner: Vector2 in [Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1)]:
		var c: Vector2 = corner * (half - rad)
		var start: float = atan2(corner.y, corner.x) - PI * 0.25
		for j: int in 5:
			var a: float = start + PI * 0.5 * float(j) / 4.0
			pts.append(c + Vector2(cos(a), sin(a)) * rad)
	return pts


# ------------------------------------------------------------------ HUD

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
	col.add_theme_constant_override("separation", 10)
	safe.add_child(col)
	var bar: HBoxContainer = HBoxContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_constant_override("separation", 16)
	col.add_child(bar)
	var mv: VBoxContainer = VBoxContainer.new()
	mv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(mv)
	var mv_t: Label = Label.new()
	mv_t.text = Kit.text("moves", "Movimientos")
	mv_t.theme_type_variation = "SubtleLabel"
	mv.add_child(mv_t)
	_moves_label = Label.new()
	_moves_label.name = "Moves"
	_moves_label.theme_type_variation = "TitleLabel"
	mv.add_child(_moves_label)
	var mid: VBoxContainer = VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(mid)
	var name_l: Label = Label.new()
	name_l.text = str(Kit.current_level().get("name", ""))
	name_l.theme_type_variation = "SubtleLabel"
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.clip_text = true
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	mid.add_child(name_l)
	_score_label = Label.new()
	_score_label.name = "Score"
	_score_label.theme_type_variation = "HeaderLabel"
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(_score_label)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	bar.add_child(pause_btn)
	## Barra de puntos con las 3 estrellas (objetivo, x1.35 y x1.7).
	_bar_back = ColorRect.new()
	_bar_back.name = "GoalBar"
	_bar_back.color = (UI.colors["borde"] as Color)
	_bar_back.custom_minimum_size = Vector2(0.0, 18.0)
	_bar_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_bar_back)
	_bar_fill = ColorRect.new()
	_bar_fill.color = UI.colors["acento"]
	_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_back.add_child(_bar_fill)
	for m: float in [1.0, 1.35]:
		var tick: ColorRect = ColorRect.new()
		tick.color = UI.colors["texto"]
		tick.size = Vector2(4.0, 18.0)
		tick.set_meta("at", m / 1.7)
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bar_back.add_child(tick)
	_bar_back.resized.connect(_update_hud)
	_ice_label = Label.new()
	_ice_label.name = "Ice"
	_ice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ice_label.visible = logic.ice_total > 0
	col.add_child(_ice_label)


func _update_hud() -> void:
	if _moves_label == null:
		return
	_moves_label.text = str(moves_left)
	_score_label.text = "%d / %d" % [logic.score, target]
	var k: float = clampf(float(logic.score) / (float(target) * 1.7), 0.0, 1.0)
	_bar_fill.size = Vector2(_bar_back.size.x * k, _bar_back.size.y)
	for t: Node in _bar_back.get_children():
		if t.has_meta("at"):
			(t as ColorRect).position = Vector2(_bar_back.size.x * float(t.get_meta("at")) - 2.0, 0.0)
	_ice_label.text = Kit.text("ice", "Hielo") + ": %d" % logic.ice_left


# ------------------------------------------------------------------ entrada

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()
		return
	if finished or busy or get_tree().paused:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed:
			_drag_from = cell_at(mb.position)
			_drag_start = mb.position
		else:
			var c: Vector2i = cell_at(mb.position)
			if _drag_from != Vector2i(-1, -1) and c == _drag_from:
				_tap(c)
			_drag_from = Vector2i(-1, -1)
	elif event is InputEventMouseMotion and _drag_from != Vector2i(-1, -1):
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		var d: Vector2 = mm.position - _drag_start
		if d.length() > cell * 0.35:
			var dir: Vector2i = Vector2i(int(signf(d.x)), 0) if absf(d.x) > absf(d.y) else Vector2i(0, int(signf(d.y)))
			var from: Vector2i = _drag_from
			_drag_from = Vector2i(-1, -1)
			_select(Vector2i(-1, -1))
			try_swap(from, from + dir)


func _tap(c: Vector2i) -> void:
	if _selected == Vector2i(-1, -1):
		_select(c)
	elif logic.adjacent(_selected, c):
		var a: Vector2i = _selected
		_select(Vector2i(-1, -1))
		try_swap(a, c)
	else:
		_select(c if c != _selected else Vector2i(-1, -1))


func _select(c: Vector2i) -> void:
	if _selected != Vector2i(-1, -1) and _pieces.has(logic.idx(_selected)):
		(_pieces[logic.idx(_selected)] as Node2D).scale = Vector2.ONE
	_selected = c
	if c != Vector2i(-1, -1) and _pieces.has(logic.idx(c)):
		(_pieces[logic.idx(c)] as Node2D).scale = Vector2(1.15, 1.15)


# ------------------------------------------------------------------ jugadas

func _fast() -> bool:
	return UI.test_mode


## 1/2 - Intenta un cambio. Devuelve true si era jugada valida.
func try_swap(a: Vector2i, b: Vector2i) -> bool:
	if busy or finished:
		return false
	if not logic.swap_ok(a, b):
		_wiggle(a)
		_wiggle(b)
		Audio.play("land", 0.05, -6.0)
		return false
	busy = true
	swaps_done += 1
	Audio.play("click", 0.05)
	if not _fast():
		await _anim_swap(a, b)
	var phases: Array[Dictionary] = logic.apply_swap(a, b)
	moves_left -= 1
	if _fast():
		_rebuild()
	else:
		await _play(phases)
	_update_hud()
	await _after_move()
	busy = false
	return true


func _anim_swap(a: Vector2i, b: Vector2i) -> void:
	var na: Node2D = _pieces.get(logic.idx(a))
	var nb: Node2D = _pieces.get(logic.idx(b))
	if na == null or nb == null:
		return
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(na, "position", cell_pos(b), 0.13)
	tw.tween_property(nb, "position", cell_pos(a), 0.13)
	await tw.finished
	_pieces[logic.idx(a)] = nb
	_pieces[logic.idx(b)] = na


func _wiggle(c: Vector2i) -> void:
	var n: Node2D = _pieces.get(logic.idx(c)) if logic.inside(c) else null
	if n == null or _fast():
		return
	var base: Vector2 = cell_pos(c)
	var tw: Tween = create_tween()
	for k: int in 3:
		tw.tween_property(n, "position", base + Vector2(8.0, 0.0), 0.04)
		tw.tween_property(n, "position", base - Vector2(8.0, 0.0), 0.04)
	tw.tween_property(n, "position", base, 0.04)


func _play(phases: Array[Dictionary]) -> void:
	for ph: Dictionary in phases:
		var cleared: Array = ph["cleared"]
		var center: Vector2 = Vector2.ZERO
		for c: Vector2i in cleared:
			var i: int = logic.idx(c)
			center += cell_pos(c)
			if _pieces.has(i):
				var n: Node2D = _pieces[i]
				_pieces.erase(i)
				Juice.burst(_fx, n.position, Color.from_hsv(HUES[int(n.get_meta("k")) % 6], 0.6, 1.0), 5, 180.0)
				var tw: Tween = n.create_tween()
				tw.tween_property(n, "scale", Vector2.ZERO, 0.12)
				tw.tween_callback(n.queue_free)
		for cr: Dictionary in ph["created"]:
			var cc: Vector2i = cr["cell"]
			var old: Variant = _pieces.get(logic.idx(cc))
			if old != null:
				(old as Node2D).queue_free()
			var nn: Node2D = make_piece(int(cr["color"]), int(cr["kind"]), cell)
			nn.position = cell_pos(cc)
			nn.z_index = 2
			_board.add_child(nn)
			_pieces[logic.idx(cc)] = nn
			Juice.squash(nn, Vector2(1.4, 1.4), 0.25)
			Audio.play("powerup", 0.05, -4.0)
		for i2: int in _ice_nodes.keys():
			if logic.ice[i2] == 0:
				(_ice_nodes[i2] as Node2D).queue_free()
				_ice_nodes.erase(i2)
		if not cleared.is_empty():
			center /= float(cleared.size())
			var combo: int = int(ph["combo"])
			UI.float_text(_fx, center, "+%d" % int(ph["points"]) + (("  x%d" % combo) if combo > 1 else ""), UI.colors["acento"], 34 + 4 * mini(combo, 4))
			Audio.play("coin", 0.1, -4.0, 1.0 + 0.08 * float(combo - 1))
			if combo >= 3:
				Juice.shake(0.15)
		await get_tree().create_timer(0.14).timeout
		var tw2: Tween = create_tween().set_parallel(true)
		var moved_any: bool = false
		var new_map: Dictionary = {}
		for mvd: Dictionary in ph["moved"]:
			var fi: int = logic.idx(mvd["from"])
			if _pieces.has(fi):
				var mn: Node2D = _pieces[fi]
				_pieces.erase(fi)
				new_map[logic.idx(mvd["to"])] = mn
				tw2.tween_property(mn, "position", cell_pos(mvd["to"]), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				moved_any = true
		for k2: int in new_map.keys():
			_pieces[k2] = new_map[k2]
		for sp: Dictionary in ph["spawned"]:
			var sc: Vector2i = sp["cell"]
			var start: Vector2 = cell_pos(sc) - Vector2(0.0, cell * float(int(sp["drop"])))
			var sn: Node2D = make_piece(int(sp["color"]), Match3Logic.NONE, cell)
			sn.position = start
			sn.z_index = 2
			_board.add_child(sn)
			_pieces[logic.idx(sc)] = sn
			tw2.tween_property(sn, "position", cell_pos(sc), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			moved_any = true
		if moved_any:
			await tw2.finished
		else:
			tw2.kill()
		_update_hud()
	_check_sync()


## Seguro: si alguna pieza dibujada no coincide con la logica, se rehace todo el tablero.
func _check_sync() -> void:
	for y: int in logic.h:
		for x: int in logic.w:
			var c: Vector2i = Vector2i(x, y)
			if not logic.playable(c):
				continue
			var i: int = logic.idx(c)
			var n: Variant = _pieces.get(i)
			if n == null or not is_instance_valid(n) or int((n as Node2D).get_meta("k")) != logic.color[i] or int((n as Node2D).get_meta("s")) != logic.special[i]:
				QA.log_event("match3_resync", {"cell": [x, y]})
				_rebuild()
				return


func _after_move() -> void:
	if logic.score >= target and logic.ice_left <= 0:
		_win()
		return
	if moves_left <= 0:
		await _lose()
		return
	if not logic.has_move():
		logic.shuffle()
		if not _fast():
			UI.float_text(_fx, origin + Vector2(cell * logic.w * 0.5, cell * logic.h * 0.5), Kit.text("shuffle", "Barajando"), UI.colors["acento"], 40)
		_rebuild()


func _win() -> void:
	finished = true
	## 3 - Los movimientos que sobran suman puntos.
	var bonus: int = moves_left * 60
	logic.score += bonus
	_update_hud()
	var stars: int = stars_earned()
	var level_id: String = str(Kit.level_index)
	var record: bool = Save.submit_best(level_id, logic.score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "score": logic.score, "target": target, "moves_left": moves_left,
		"deaths": deaths, "stars": stars, "specials": logic.specials_made})
	if bonus > 0 and not _fast():
		UI.float_text(_fx, origin + Vector2(cell * logic.w * 0.5, -20.0), Kit.text("extra_moves", "Movimientos extra") + " +%d" % bonus, UI.colors["exito"], 38)
	Audio.play("win")
	Audio.play_track("victoria", false)
	var shown: int = logic.ice_total - logic.ice_left if logic.ice_total > 0 else moves_left
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": shown, "coins_total": logic.ice_total if logic.ice_total > 0 else moves_total,
		"score": logic.score, "record": record})
	await Ads.show_interstitial("level_end")


func stars_earned() -> int:
	var n: int = 1
	if logic.score >= int(float(target) * 1.35):
		n += 1
	if logic.score >= int(float(target) * 1.7):
		n += 1
	return n


func _lose() -> void:
	deaths += 1
	QA.log_event("death", {"cause": "out_of_moves", "score": logic.score, "target": target, "deaths": deaths})
	Audio.play("hurt")
	if auto_retry or _fast():
		restart()
		return
	var panel: OutOfMovesPanel = OutOfMovesPanel.open(self, maxi(target - logic.score, 0), logic.ice_left)
	get_tree().paused = true
	await panel.closed
	get_tree().paused = false
	restart()


func restart() -> void:
	logic.setup(level_map, logic.colors, _seed + deaths * 13)
	moves_left = moves_total
	swaps_done = 0
	_rebuild()


func open_pause() -> void:
	if finished or get_tree().paused or get_node_or_null("PauseMenu") != null:
		return
	PauseMenu.open(self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_inside_tree() and not UI.test_mode:
			open_pause()


func bot_state() -> Dictionary:
	return {"finished": finished, "deaths": deaths, "coins": logic.ice_total - logic.ice_left, "stomps": logic.specials_made,
		"score": logic.score, "target": target, "moves_left": moves_left, "ice_left": logic.ice_left, "paused": get_tree().paused,
		"progress": clampf(float(logic.score) / float(maxi(target, 1)), 0.0, 1.0)}
