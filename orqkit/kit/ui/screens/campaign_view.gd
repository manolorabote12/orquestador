class_name CampaignView
extends Control
## Campana de la casa propia (game_hub.gd). layout "descenso": las etapas bajan por la pantalla (cada
## una mas honda y mas oscura), unidas por cadena o camino; "ascenso": suben. Arriba, el botin que se
## llena solo mientras no juegas (Heroes.idle_*), con su nombre propio; abajo, el boton para jugar la
## etapa que toca. Cada boss_every etapas, un jefe.

const GAP: float = 190.0
const NODE: float = 76.0

var hub: GameHub
var cfg: Dictionary = {}
var _scroll: ScrollContainer
var _canvas: Control
var _points: Array[Vector2] = []
var _cur: int = 0
var _idle_bar: Control
var _idle_label: Label
var _t: float = 0.0


func _ready() -> void:
	_cur = clampi(Save.unlocked_count() - 1, 0, maxi(Kit.level_count() - 1, 0))
	_backdrop()
	_scroll = ScrollContainer.new()
	_scroll.name = "Descent"
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.offset_top = 300.0
	_scroll.offset_bottom = -130.0
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_canvas = Control.new()
	_canvas.name = "Path"
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.custom_minimum_size = Vector2(0, GAP * float(Kit.level_count()) + 120.0)
	_canvas.draw.connect(_draw_path)
	_canvas.resized.connect(_place)
	_scroll.add_child(_canvas)
	for i: int in Kit.level_count():
		_canvas.add_child(_node(i))
	add_child(_idle_card())
	add_child(_go_button())
	_place.call_deferred()


func _process(delta: float) -> void:
	_t += delta
	if _canvas != null:
		_canvas.queue_redraw()


func _descending() -> bool:
	return str(cfg.get("layout", "descenso")) != "ascenso"


## Fondo del juego arriba que se hunde en el color de lo hondo.
func _backdrop() -> void:
	var ui_cfg: Dictionary = Kit.assets.get("ui", {}) as Dictionary
	var path: String = str(cfg.get("fondo", ui_cfg.get("fondo", "")))
	if path != "" and ResourceLoader.exists(path):
		var tr: TextureRect = TextureRect.new()
		tr.name = "Backdrop"
		tr.texture = load(path) as Texture2D
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tr)
	var deep: Color = Color(str(cfg.get("hondo", UI.colors["panel_hi"].darkened(0.55).to_html(false))))
	## Degradado suave (sin franjas): lo de arriba se ve, lo hondo se hunde en su color.
	var gr: Gradient = Gradient.new()
	if _descending():
		gr.offsets = PackedFloat32Array([0.0, 0.18, 0.62, 1.0])
		gr.colors = PackedColorArray([Color(deep, 0.0), Color(deep, 0.05), Color(deep, 0.55), Color(deep, 0.95)])
	else:
		gr.offsets = PackedFloat32Array([0.0, 0.38, 0.82, 1.0])
		gr.colors = PackedColorArray([Color(deep, 0.95), Color(deep, 0.55), Color(deep, 0.05), Color(deep, 0.0)])
	var gt: GradientTexture2D = GradientTexture2D.new()
	gt.gradient = gr
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 256
	var veil: TextureRect = TextureRect.new()
	veil.name = "Depth"
	veil.texture = gt
	veil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	veil.stretch_mode = TextureRect.STRETCH_SCALE
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)


func _boss(i: int) -> bool:
	var every: int = int(cfg.get("boss_every", 5))
	return i == Kit.level_count() - 1 or (every > 0 and (i + 1) % every == 0)


func _node(i: int) -> Control:
	var open: bool = i <= _cur
	var b: Button = Button.new()
	b.name = "Level%d" % (i + 1)
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.disabled = not open
	var big: float = NODE * (1.35 if _boss(i) else (1.2 if i == _cur else 1.0))
	b.custom_minimum_size = Vector2(big, big)
	b.size = b.custom_minimum_size
	var face: Control = Control.new()
	face.set_anchors_preset(Control.PRESET_FULL_RECT)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var acc: Color = UI.colors["acento"]
	var boss: bool = _boss(i)
	var done: bool = Save.stars_for(str(i)) > 0
	face.draw.connect(func() -> void:
		var c: Vector2 = face.size * 0.5
		var r: float = face.size.x * 0.5 - 4.0
		face.draw_circle(c + Vector2(0, 5), r, Color(0, 0, 0, 0.4))
		var fill: Color = Color("#6b1d2a") if boss else (Color("#3f7f4c") if done else (Color("#e9d8b0") if open else Color("#3a3640")))
		face.draw_circle(c, r, fill)
		face.draw_circle(c + Vector2(-r * 0.2, -r * 0.22), r * 0.62, fill.lightened(0.12))
		## Medallon pintado por la GPU (etapa o jefe): ocupa el disco; lo cerrado, apagado.
		var art: Texture2D = GameHub.tex(str(cfg.get("boss_art" if boss else "node_art", "")))
		if art != null:
			var ar: float = r * (1.25 if boss else 1.15)
			var tint: Color = Color.WHITE if open else Color(0.35, 0.33, 0.4)
			if done and not boss:
				tint = Color(0.85, 1.0, 0.85)
			face.draw_texture_rect(art, Rect2(c - Vector2(ar, ar * 1.05), Vector2(ar, ar * 1.05) * 2.0), false, tint)
			if i == _cur:
				face.draw_arc(c, r + 3.0, 0.0, TAU, 40, acc, 5.0, true)
			return
		face.draw_arc(c, r, 0.0, TAU, 40, acc if i == _cur else (Color("#e63946") if boss else Color("#2a1a33")), 5.0 if i == _cur else 3.5, true))
	b.add_child(face)
	var has_art: bool = GameHub.tex(str(cfg.get("boss_art" if boss else "node_art", ""))) != null
	if boss and has_art:
		pass
	elif boss:
		var sk: UiIcon = UiIcon.make("skull", Color("#ffd5d8") if open else Color(1, 1, 1, 0.3), big * 0.5)
		sk.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		sk.offset_left = -big * 0.25
		sk.offset_right = big * 0.25
		sk.offset_top = -big * 0.25
		sk.offset_bottom = big * 0.25
		b.add_child(sk)
	else:
		var n: Label = Label.new()
		n.text = str(i + 1) if open else ""
		n.set_anchors_preset(Control.PRESET_FULL_RECT)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		n.add_theme_font_size_override("font_size", 30)
		n.add_theme_color_override("font_color", Color("#2a1a33") if open and not done else Color.WHITE)
		b.add_child(n)
		if not open:
			var lock: UiIcon = UiIcon.make("lock", Color(1, 1, 1, 0.45), big * 0.42)
			lock.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
			lock.offset_left = -big * 0.21
			lock.offset_right = big * 0.21
			lock.offset_top = -big * 0.21
			lock.offset_bottom = big * 0.21
			b.add_child(lock)
	b.pressed.connect(_play.bind(i))
	return b


func _place() -> void:
	var n: int = Kit.level_count()
	var w: float = _canvas.size.x
	var h: float = _canvas.custom_minimum_size.y
	_points.clear()
	for i: int in n:
		var x: float = w * 0.5 + sin(float(i) * 1.15 + 0.6) * w * 0.27
		var y: float = 70.0 + GAP * float(i) if _descending() else h - 70.0 - GAP * float(i)
		_points.append(Vector2(x, y))
		var b: Control = _canvas.get_node_or_null("Level%d" % (i + 1)) as Control
		if b != null:
			b.position = Vector2(x, y) - b.size * 0.5
	## El equipo, de pie junto a la etapa que toca, y su cartel.
	var old: Node = _canvas.get_node_or_null("Team")
	if old != null:
		old.queue_free()
	if _cur < _points.size():
		var team: Node2D = Node2D.new()
		team.name = "Team"
		var p: Vector2 = _points[_cur]
		var side: float = -1.0 if p.x > w * 0.5 else 1.0
		var ids: Array = Heroes.team() if Heroes.enabled() else []
		for k: int in mini(ids.size(), 4):
			var f: Node2D = Heroes.figure(str(ids[k]), 92.0)
			f.position = Vector2(side * (96.0 + 34.0 * float(k)), 34.0 - 6.0 * float(k % 2))
			team.add_child(f)
		team.position = p
		_canvas.add_child(team)
		var plate: Label = _canvas.get_node_or_null("StagePlate") as Label
		if plate == null:
			plate = Label.new()
			plate.name = "StagePlate"
			plate.add_theme_font_size_override("font_size", 22)
			plate.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
			plate.add_theme_constant_override("outline_size", 7)
			_canvas.add_child(plate)
		plate.text = _stage_name(_cur)
		plate.size = plate.get_combined_minimum_size()
		plate.position = p + Vector2(-plate.size.x * 0.5, NODE * 0.62 + 6.0)
		_scroll.scroll_vertical = int(maxf(0.0, p.y - _scroll.size.y * 0.45))


func _stage_name(i: int) -> String:
	var levels: Array = Kit.config.get("levels", [])
	var nm: String = str((levels[i] as Dictionary).get("name", "")) if i < levels.size() and levels[i] is Dictionary else ""
	var word: String = str(cfg.get("stage", Kit.text("stage", "etapa")))
	return ("%s %d" % [word.capitalize(), i + 1]) + (" · " + nm if nm != "" else "")


## Camino entre etapas: eslabones de cadena (connector "cadena") o un camino de puntos.
func _draw_path() -> void:
	if _points.size() < 2:
		return
	var pts: PackedVector2Array = PackedVector2Array()
	for k: int in range(_points.size() - 1):
		var a: Vector2 = _points[k]
		var b: Vector2 = _points[k + 1]
		var mid: Vector2 = (a + b) * 0.5 + Vector2(0, 0)
		var c1: Vector2 = Vector2(a.x, mid.y)
		var c2: Vector2 = Vector2(b.x, mid.y)
		for s: int in 20:
			var t: float = float(s) / 20.0
			var u: float = 1.0 - t
			pts.append(a * u * u * u + c1 * 3.0 * u * u * t + c2 * 3.0 * u * t * t + b * t * t * t)
	pts.append(_points[_points.size() - 1])
	var metal: Color = hub.metal() if hub != null else Color("#8d8597")
	var chain: bool = hub != null and hub._connector() == "cadena"
	var reach: int = mini(_cur, _points.size() - 1) * 20
	if chain:
		## Eslabones a lo largo del camino: de frente y de canto, alternos. Lo ya bajado brilla.
		var acc: float = 0.0
		var k2: int = 0
		for j: int in range(1, pts.size()):
			var seg: Vector2 = pts[j] - pts[j - 1]
			acc += seg.length()
			if acc < 22.0:
				continue
			acc = 0.0
			var dir: Vector2 = seg.normalized()
			var lit: bool = j <= reach
			var col: Color = metal.lightened(0.2) if lit else metal.darkened(0.35)
			if k2 % 2 == 0:
				var ring: PackedVector2Array = PackedVector2Array()
				for q: int in 21:
					var ang: float = TAU * float(q) / 20.0
					ring.append(pts[j] + dir * cos(ang) * 14.0 + dir.orthogonal() * sin(ang) * 8.0)
				_canvas.draw_polyline(ring, Color(0, 0, 0, 0.45), 8.0, true)
				_canvas.draw_polyline(ring, col, 4.5, true)
			else:
				_canvas.draw_line(pts[j] - dir * 12.0, pts[j] + dir * 12.0, Color(0, 0, 0, 0.45), 8.0, true)
				_canvas.draw_line(pts[j] - dir * 12.0, pts[j] + dir * 12.0, col, 4.5, true)
			k2 += 1
	else:
		_canvas.draw_polyline(pts, Color(0, 0, 0, 0.4), 24.0, true)
		_canvas.draw_polyline(pts, Color("#a07d50"), 16.0, true)
		for j2: int in range(0, pts.size(), 4):
			_canvas.draw_circle(pts[j2], 3.5, Color("#f3e3b5", 0.9 if j2 <= reach else 0.2))
	if _cur < _points.size():
		var k3: float = 0.5 + 0.5 * sin(_t * 3.0)
		_canvas.draw_arc(_points[_cur], NODE * 0.6 + 8.0 + 8.0 * k3, 0.0, TAU, 48, Color(UI.colors["acento"], 0.7 - 0.5 * k3), 4.0, true)


# ------------------------------------------------------------------ botin que se llena solo

func _idle_card() -> Control:
	var idle: Dictionary = cfg.get("idle", {})
	var card: PanelContainer = PanelContainer.new()
	card.name = "IdleCard"
	card.set_anchors_preset(Control.PRESET_TOP_WIDE)
	card.offset_left = 22.0
	card.offset_right = -22.0
	card.offset_top = 132.0
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(str(idle.get("papel", "#efe1c0")))
	sb.border_color = Color(str(idle.get("borde", "#7a5b2e")))
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(22)
	sb.corner_radius_bottom_left = 6
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 6)
	sb.content_margin_left = 16.0
	sb.content_margin_right = 16.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 12.0
	card.add_theme_stylebox_override("panel", sb)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)
	var pot: Control = Control.new()
	pot.custom_minimum_size = Vector2(96, 96)
	var glow: Color = UI.colors["panel_hi"]
	var pot_art: Texture2D = GameHub.tex(str(idle.get("art", "")))
	pot.draw.connect(func() -> void:
		if pot_art != null:
			## El dibujo de la GPU (caldero, cofre...), que respira un poco; lleno, brilla.
			var k0: float = 0.5 + 0.5 * sin(_t * 2.5)
			var sz: Vector2 = pot.size * (1.12 + 0.03 * k0)
			if _fill() >= 0.5:
				pot.draw_circle(pot.size * 0.5, pot.size.x * 0.55, Color(glow, 0.18 + 0.15 * k0))
			pot.draw_texture_rect(pot_art, Rect2((pot.size - sz) * 0.5 - Vector2(0, 4), sz), false)
			return
		var c: Vector2 = pot.size * 0.5 + Vector2(0, 8)
		pot.draw_circle(c, 40.0, Color("#3b2b25"))
		pot.draw_rect(Rect2(c.x - 42, c.y - 30, 84, 14), Color("#2a1a33"))
		var f: float = _fill()
		var k: float = 0.5 + 0.5 * sin(_t * 2.5)
		pot.draw_circle(Vector2(c.x, c.y - 26), 32.0, glow.lightened(0.15 + 0.15 * k) if f > 0.05 else glow.darkened(0.5))
		for i: int in 4:
			var bx: float = c.x - 18.0 + 12.0 * float(i)
			var by: float = c.y - 34.0 - fmod(_t * 18.0 + 13.0 * float(i), 34.0)
			pot.draw_circle(Vector2(bx, by), 4.0 + float(i % 2) * 2.0, Color(glow.lightened(0.5), 0.75 * f)))
	row.add_child(pot)
	var v: VBoxContainer = VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(v)
	var t1: Label = Label.new()
	t1.text = str(idle.get("name", Kit.text("idle_loot", "Botín")))
	t1.add_theme_font_size_override("font_size", 28)
	t1.add_theme_color_override("font_color", Color("#2a1a33"))
	v.add_child(t1)
	_idle_label = Label.new()
	_idle_label.add_theme_font_size_override("font_size", 19)
	_idle_label.add_theme_color_override("font_color", Color("#5a4a3a"))
	v.add_child(_idle_label)
	_idle_bar = Control.new()
	_idle_bar.custom_minimum_size = Vector2(0, 16)
	_idle_bar.draw.connect(func() -> void:
		var r: Rect2 = Rect2(Vector2.ZERO, _idle_bar.size)
		_idle_bar.draw_rect(r, Color("#c9b48a"))
		_idle_bar.draw_rect(Rect2(r.position, Vector2(r.size.x * _fill(), r.size.y)), glow))
	v.add_child(_idle_bar)
	var claim: Button = GameHub.styled_button(str(idle.get("verb", Kit.text("idle_claim", "Recoger"))), false)
	claim.name = "BtnIdle"
	claim.custom_minimum_size = Vector2(170, 76)
	claim.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	claim.pressed.connect(func() -> void:
		var n: int = Heroes.idle_claim() if Heroes.enabled() else 0
		if n > 0:
			Audio.play("coin")
			Juice.burst(self, claim.get_global_rect().get_center(), Kit.color("coin", UI.colors["acento"]), 26)
		UI.float_text(self, claim.get_global_rect().get_center() + Vector2(-200.0, 60.0), Kit.text("idle_got", "+{n} mientras no jugabas").format({"n": n}) if n > 0 \
			else Kit.text("idle_empty", "Vuelve más tarde: se llena solo"), UI.colors["acento"], 28)
		if hub != null:
			hub.refresh()
		_update_idle())
	row.add_child(claim)
	_update_idle()
	var tm: Timer = Timer.new()
	tm.wait_time = 1.0
	tm.autostart = true
	tm.timeout.connect(_update_idle)
	card.add_child(tm)
	return card


func _fill() -> float:
	if not Heroes.enabled():
		return 0.0
	return clampf(float(Heroes.idle_pending()) / maxf(1.0, float(Heroes.idle_rate()) * Heroes.IDLE_CAP_H), 0.0, 1.0)


func _update_idle() -> void:
	if _idle_label == null:
		return
	var n: int = Heroes.idle_pending() if Heroes.enabled() else 0
	var left_h: float = (1.0 - _fill()) * Heroes.IDLE_CAP_H
	_idle_label.text = Kit.text("idle_info", "{n} esperando · lleno en {h} h {m} min").format(
		{"n": n, "h": int(left_h), "m": int(fmod(left_h, 1.0) * 60.0)}) if _fill() < 1.0 else Kit.text("idle_full", "{n} esperando · ¡lleno!").format({"n": n})
	if _idle_bar != null:
		_idle_bar.queue_redraw()


func _go_button() -> Control:
	var b: Button = GameHub.styled_button("", true)
	b.name = "BtnGo"
	b.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	b.offset_left = -250.0
	b.offset_right = 250.0
	b.offset_top = -122.0
	b.offset_bottom = -20.0
	b.text = "%s %s %d" % [str(cfg.get("verb", Kit.text("play", "Jugar"))), str(cfg.get("stage", Kit.text("stage", "etapa"))), _cur + 1]
	b.add_theme_font_size_override("font_size", 34)
	b.pressed.connect(_play.bind(_cur))
	return b


func _play(i: int) -> void:
	if i > _cur:
		return
	Audio.play("click")
	RpgModes.stop()
	Kit.level_index = i
	UI.goto(UI.game_scene())
