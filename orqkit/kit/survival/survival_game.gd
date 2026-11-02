extends Node2D
## Supervivencia 2D: una isla vista desde arriba. Recoge madera, piedra, fibra y bayas, bebe en
## la charca, fabrica hacha, lanza y hoguera y aguanta las noches (los lobos no se acercan a la
## luz del fuego). En algunos niveles hay que construir una balsa para escapar.
## Mando: arrastra en cualquier sitio para moverte; USAR hace lo que toca segun lo que tienes al
## lado (recoger, beber, echar lena, golpear); COMER y los botones de fabricar.
## Reglas, bot y analizador en survival_map.gd (simulacion pura, en casillas).
## Vista 3D (game.json -> "view": "3d"): la misma partida dibujada en 3D (survival_view3d.gd).
## Plantilla: el estilo (game.json -> "survival" o levels[i].survival: objetos, recetas, criaturas,
## frio, mochila...) lo lee survival_map.gd; aqui los botones de fabricar salen de sus recetas y
## la partida se guarda al amanecer (si sales, sigues ese dia donde lo dejaste).
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel/FailPanel al acabar.

const M = preload("res://kit/survival/survival_map.gd")
const T: float = 64.0
const NIGHT_TINT: Color = Color(0.2, 0.24, 0.42)
const CRAFTS: Array[String] = ["hacha", "lanza", "hoguera", "balsa"]
const SAVE_KEY: String = "survival_run"

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

var _ground: Node2D
var _props: Node2D
var _actors: Node2D
var _player: Node2D
var _player_art: AnimatedSprite2D = null
var _wolves: Dictionary = {}
var _camera: Camera2D
var _tint: CanvasModulate
var _fire_light: PointLight2D
var _me_light: PointLight2D
var _stick: HordeStick
var _hud: Control
var _bars: Control
var _day_lbl: Label
var _goal_lbl: Label
var _use_btn: Button
var _eat_btn: Button
var _craft_btns: Dictionary = {}
var _big: Label
var _bot: bool = false
var _use_pressed: bool = false
var _eat_pressed: bool = false
var _craft_req: String = ""
var _t: float = 0.0
var _props_dirty: bool = true
var _resumed: bool = false
var view3d: Survival3DView = null


func _ready() -> void:
	level = Kit.current_level()
	par = float(level.get("par", 200))
	_reset()
	RenderingServer.set_default_clear_color(Color("#1c5a8a"))
	_ground = Node2D.new()
	_ground.name = "Ground"
	_ground.draw.connect(_draw_ground)
	add_child(_ground)
	_props = Node2D.new()
	_props.name = "Props"
	_props.draw.connect(_draw_props)
	add_child(_props)
	_actors = Node2D.new()
	_actors.name = "Actors"
	_actors.y_sort_enabled = true
	add_child(_actors)
	_build_player()
	_tint = CanvasModulate.new()
	_tint.name = "Night"
	add_child(_tint)
	_fire_light = _light(Color("#ffb347"), M.FIRE_R * T * 1.15)
	_me_light = _light(Color("#c9d8ff"), T * 1.6)
	_me_light.energy = 0.5
	_camera = Camera2D.new()
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 8.0
	add_child(_camera)
	_camera.make_current()
	Juice.register_camera(_camera)
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = int(float(st["w"]) * T)
	_camera.limit_bottom = int(float(st["h"]) * T)
	_build_hud()
	if str(Kit.param("view", "2d")) == "3d":
		## En 3D el mundo 2D no se dibuja (la interfaz si).
		view3d = Survival3DView.new()
		add_child(view3d)
		view3d.setup(self)
		for n: CanvasItem in [_ground, _props, _actors]:
			n.visible = false
		_tint.visible = false
		_fire_light.visible = false
		_me_light.visible = false
	_sync(1.0)
	_camera.reset_smoothing()
	if _resumed:
		_big_text(Kit.text("sv_resumed", "Sigues donde lo dejaste"), Color("#ffe08a"), 1.2)
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "survival", "goal": str(st["goal"]), "nights": int(st["nights"]),
		"view": "3d" if view3d != null else "2d"})


func bot_script() -> String:
	return "res://qa/survival_bot.gd"


## Fotos de la ficha: una de dia recogiendo y otra de noche junto a la hoguera.
func capture_delays() -> Vector2:
	return Vector2(14.0, maxf(8.0, float(st.get("day", 60.0)) - 14.0 + 8.0))


func _reset() -> void:
	finished = false
	failed = false
	var lv: Dictionary = level.duplicate()
	if deaths > 0:
		var rows: Array = []
		for r: Variant in level.get("map", []):
			if not (str(r).begins_with("#") and str(r).substr(1).is_valid_int()):
				rows.append(r)
		rows.append("#%d" % (int(M.parse(level)["seed"]) + deaths * 131))
		lv["map"] = rows
	if not lv.has("survival") and Kit.param("survival", null) is Dictionary:
		lv["survival"] = Kit.param("survival", {})
	st = M.new_state(lv)
	## Partida guardada de este nivel (al amanecer): se sigue donde se dejo.
	var saved: Variant = Save.get_setting(SAVE_KEY, {})
	if deaths == 0 and saved is Dictionary and str(saved.get("level", "")) == _save_id() and not UI.test_mode:
		var back: Dictionary = M.restore(lv, saved.get("snap", {}))
		if not back.is_empty():
			st = back
			_resumed = true
	time_in_level = 0.0
	coins = 0
	_props_dirty = true
	_use_pressed = false
	_eat_pressed = false
	_craft_req = ""
	for n: Node in _wolves.values():
		(n as Node).queue_free()
	_wolves.clear()


func _light(col: Color, radius_px: float) -> PointLight2D:
	var l: PointLight2D = PointLight2D.new()
	var g: GradientTexture2D = GradientTexture2D.new()
	g.width = 256
	g.height = 256
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.5)
	g.fill_to = Vector2(1.0, 0.5)
	var gr: Gradient = Gradient.new()
	gr.set_color(0, Color(1, 1, 1, 1))
	gr.set_color(1, Color(1, 1, 1, 0))
	g.gradient = gr
	l.texture = g
	l.texture_scale = radius_px * 2.0 / 256.0
	l.color = col
	l.energy = 1.1
	l.enabled = false
	add_child(l)
	return l


func _build_player() -> void:
	_player = Node2D.new()
	_player.name = "Player"
	_actors.add_child(_player)
	var art: Dictionary = Kit.sprite_by_role("jugador")
	if not art.is_empty():
		_player_art = SpriteKit.animado(art, T * 1.1, "idle", false)
		_player_art.position = Vector2(0, -T * 0.25)
		_player.add_child(_player_art)
		Skins.apply(_player_art)
	else:
		var body: Polygon2D = Polygon2D.new()
		body.color = Kit.color("player", Kit.color("accent", Color.ORANGE))
		body.polygon = LevelBuilder._circle(T * 0.3, 20)
		_player.add_child(body)


func _creature_col(kind: String) -> Color:
	var d: Dictionary = (st["cat"]["creatures"] as Dictionary).get(kind, {})
	return Color.from_string(str(d.get("color", "#5b6270")), Color("#5b6270"))


func _wolf_node(id: int, kind: String = "wolf") -> Node2D:
	var root: Node2D = Node2D.new()
	root.name = "Wolf%d" % id
	var cdef: Dictionary = (st["cat"]["creatures"] as Dictionary).get(kind, {})
	var lk: String = str(cdef.get("look", "wolf"))
	var hostile: bool = bool(cdef.get("hostile", true))
	var id_art: String = str(Kit.param("art.enemies.walker", "")) if hostile else ""
	var entry: Dictionary = Kit.sprite_entry(id_art) if id_art != "" else {}
	if entry.is_empty():
		entry = Kit.sprite_by_role("enemigo" if hostile else "presa")
	if not entry.is_empty():
		var spr: AnimatedSprite2D = SpriteKit.animado(entry, T * 1.0, "run", false)
		spr.position = Vector2(0, -T * 0.2)
		spr.name = "Art"
		root.add_child(spr)
	elif lk == "zombie":
		## Zombi hecho con formas: cuerpo encorvado, brazos por delante y ojos rojos.
		var zc: Color = _creature_col(kind)
		var torso: Polygon2D = Polygon2D.new()
		torso.polygon = PackedVector2Array([Vector2(-12, 14), Vector2(-10, -14), Vector2(10, -16), Vector2(12, 14)])
		torso.color = Color("#5d6b8a")
		root.add_child(torso)
		var zhead: Polygon2D = Polygon2D.new()
		zhead.polygon = LevelBuilder._circle(11.0, 12)
		zhead.position = Vector2(4, -24)
		zhead.color = zc
		root.add_child(zhead)
		for ay: float in [-10.0, -2.0]:
			var arm: Polygon2D = Polygon2D.new()
			arm.polygon = PackedVector2Array([Vector2(6, ay - 3), Vector2(28, ay - 3), Vector2(28, ay + 3), Vector2(6, ay + 3)])
			arm.color = zc.darkened(0.1)
			root.add_child(arm)
		for ex: float in [2.0, 9.0]:
			var zeye: Polygon2D = Polygon2D.new()
			zeye.polygon = LevelBuilder._circle(2.0, 6)
			zeye.position = Vector2(ex, -26)
			zeye.color = Color("#ff5252")
			root.add_child(zeye)
	elif lk == "beast":
		## Bicho de cuatro patas (ciervo, jabali): cuerpo, cabeza y patas.
		var bc: Color = _creature_col(kind)
		for lx: float in [-14.0, -6.0, 8.0, 15.0]:
			var leg: Polygon2D = Polygon2D.new()
			leg.polygon = PackedVector2Array([Vector2(lx - 2, 2), Vector2(lx + 2, 2), Vector2(lx + 2, 18), Vector2(lx - 2, 18)])
			leg.color = bc.darkened(0.3)
			root.add_child(leg)
		var bbody: Polygon2D = Polygon2D.new()
		bbody.polygon = LevelBuilder._circle(16.0, 14)
		bbody.scale = Vector2(1.35, 0.7)
		bbody.color = bc
		root.add_child(bbody)
		var bhead: Polygon2D = Polygon2D.new()
		bhead.polygon = LevelBuilder._circle(8.0, 10)
		bhead.position = Vector2(24, -8)
		bhead.color = bc.lightened(0.1)
		root.add_child(bhead)
		if not hostile:
			## Cuernos de ciervo.
			for hx: float in [20.0, 27.0]:
				var horn: Line2D = Line2D.new()
				horn.points = PackedVector2Array([Vector2(hx, -14), Vector2(hx - 2, -24), Vector2(hx + 3, -28)])
				horn.width = 2.5
				horn.default_color = Color("#d7c4a3")
				root.add_child(horn)
		else:
			var tusk: Polygon2D = Polygon2D.new()
			tusk.polygon = PackedVector2Array([Vector2(30, -6), Vector2(36, -12), Vector2(32, -4)])
			tusk.color = Color("#f5f5f5")
			root.add_child(tusk)
	else:
		## Lobo hecho con formas: cuerpo, cabeza, orejas y ojos que brillan.
		var c: Color = _creature_col(kind) if cdef.has("color") else Color("#5b6270")
		var body: Polygon2D = Polygon2D.new()
		body.polygon = PackedVector2Array([Vector2(-22, -6), Vector2(14, -10), Vector2(22, 0), Vector2(14, 8), Vector2(-22, 6), Vector2(-30, -2)])
		body.color = c
		root.add_child(body)
		var head: Polygon2D = Polygon2D.new()
		head.polygon = PackedVector2Array([Vector2(14, -12), Vector2(32, -4), Vector2(14, 6), Vector2(16, -18), Vector2(20, -12)])
		head.color = c.lightened(0.1)
		root.add_child(head)
		for ey: float in [-6.0]:
			var eye: Polygon2D = Polygon2D.new()
			eye.polygon = LevelBuilder._circle(2.5, 8)
			eye.position = Vector2(24, ey)
			eye.color = Color("#ffe066")
			root.add_child(eye)
	_actors.add_child(root)
	return root


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
	layer.add_child(_hud)
	var safe: MarginContainer = UI.safe_root(_hud, 14.0)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col: VBoxContainer = VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 6)
	safe.add_child(col)
	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top)
	_bars = Control.new()
	_bars.name = "Bars"
	_bars.custom_minimum_size = Vector2(330, 118 + (26 if float(st["cat"]["cold"]) > 0.0 else 0) + (24 if int(st["cat"]["bag"]) > 0 else 0))
	_bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bars.draw.connect(_draw_bars)
	top.add_child(_bars)
	var info: VBoxContainer = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(info)
	_day_lbl = _label(32, Color.WHITE)
	_day_lbl.name = "Day"
	_day_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info.add_child(_day_lbl)
	_goal_lbl = _label(22, Color(1, 1, 1, 0.85))
	_goal_lbl.name = "Goal"
	_goal_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_goal_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(_goal_lbl)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)
	_big = _label(76, Color("#ffd23f"))
	_big.name = "Big"
	_big.theme_type_variation = "TitleLabel"
	_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_big.set_anchors_preset(Control.PRESET_CENTER)
	_big.position = Vector2(-340, -260)
	_big.size = Vector2(680, 200)
	_big.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_big.modulate.a = 0.0
	_hud.add_child(_big)
	## Abajo a la derecha: USAR (grande) y COMER; encima, los de fabricar.
	_use_btn = _btn("BtnUse", Kit.text("sv_use", "Usar"), Vector2(-250, -250), Vector2(220, 150), Color("#ffb347"))
	_use_btn.button_down.connect(func() -> void: _use_pressed = true)
	_eat_btn = _btn("BtnEat", Kit.text("sv_eat", "Comer"), Vector2(-250, -410), Vector2(220, 130), Color("#e05a6a"))
	_eat_btn.add_theme_font_size_override("font_size", 30)
	_eat_btn.button_down.connect(func() -> void: _eat_pressed = true)
	## Fabricar: botones estrechos con el nombre arriba y el coste dibujado (icono y numero) debajo,
	## en la franja de la izquierda (la derecha es de USAR y COMER).
	var ids: Array[String] = craft_ids()
	## Hasta 4 caben en la franja; con mas, una fila que se desliza con el dedo.
	var bw: float = 104.0 if ids.size() > 3 else 132.0
	var x: float = 18.0
	var strip: HBoxContainer = null
	if ids.size() > 4:
		var sc: ScrollContainer = ScrollContainer.new()
		sc.name = "CraftScroll"
		sc.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		sc.offset_left = 18.0
		sc.offset_right = 18.0 + 4.0 * (bw + 6.0)
		sc.offset_top = -176.0
		sc.offset_bottom = -32.0
		sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
		_hud.add_child(sc)
		strip = HBoxContainer.new()
		strip.add_theme_constant_override("separation", 6)
		sc.add_child(strip)
	for id2: String in ids:
		var b: Button = UI.make_button("", false)
		b.name = "Craft_" + id2
		if strip != null:
			b.custom_minimum_size = Vector2(bw, 128.0)
		else:
			b.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
			b.offset_left = x
			b.offset_right = x + bw
			b.offset_top = -168.0
			b.offset_bottom = -40.0
		b.add_theme_font_size_override("font_size", 18)
		## Botones estrechos: margenes laterales pequenos para que quepa el nombre (hoguera, machete...).
		for sname: String in ["normal", "hover", "pressed", "disabled", "focus"]:
			var sb: StyleBox = b.get_theme_stylebox(sname)
			if sb != null:
				var nsb: StyleBox = sb.duplicate()
				nsb.content_margin_left = 6.0
				nsb.content_margin_right = 6.0
				b.add_theme_stylebox_override(sname, nsb)
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.clip_text = true
		b.pressed.connect(func() -> void: _craft_req = id2)
		var cost: Control = Control.new()
		cost.name = "Cost"
		cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cost.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		cost.offset_top = -46.0
		cost.offset_bottom = -6.0
		cost.draw.connect(_draw_cost.bind(cost, id2))
		b.add_child(cost)
		if strip != null:
			strip.add_child(b)
		else:
			_hud.add_child(b)
		_craft_btns[id2] = b
		x += bw + 6.0
	_stick = HordeStick.new()
	_stick.name = "Stick"
	add_child(_stick)


## Recetas con boton: todas menos las metas que no tocan en este nivel (la balsa si no es la meta).
func craft_ids() -> Array[String]:
	var out: Array[String] = []
	for id: String in M.recipe_ids(st):
		if bool(M.recipe_def(st, id).get("win", false)) and str(st["goal"]) == "noches":
			continue
		out.append(id)
	return out


func _save_id() -> String:
	return "%d:%s" % [Kit.level_index, str(level.get("name", ""))]


func _label(size_px: int, col: Color) -> Label:
	var l: Label = Label.new()
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", maxi(6, size_px / 5))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _btn(nm: String, text: String, off: Vector2, sz: Vector2, tint: Color) -> Button:
	var b: Button = UI.make_button(text, true)
	b.name = nm
	b.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	b.offset_left = off.x
	b.offset_top = off.y
	b.offset_right = off.x + sz.x
	b.offset_bottom = off.y + sz.y
	b.add_theme_font_size_override("font_size", 40)
	b.self_modulate = tint.lerp(Color.WHITE, 0.25)
	_hud.add_child(b)
	return b


func item_name(id: String) -> String:
	## Lo que nombra el propio juego (contenido inventado) manda sobre los nombres de siempre.
	var nm: Variant = (st.get("cat", {}) as Dictionary).get("names", {}).get(id, null) if not st.is_empty() else null
	if nm != null:
		return str(nm)
	var known: String = _known_name(id)
	if known != "":
		return known
	return Kit.text("sv_" + id, NAMES.get(id, id))


## Nombres de lo que traen los estilos (el texto sv_<id> del juego manda si existe).
const NAMES: Dictionary = {"meat": "carne", "cooked": "asado", "scrap": "chatarra", "cloth": "tela", "can": "lata", "venda": "Venda",
	"machete": "Machete", "muro": "Muro", "puerta": "Puerta", "mesa": "Mesa", "cama": "Cama", "radio": "Radio", "fur": "piel",
	"abrigo": "Abrigo", "zombie": "zombis", "boar": "jabal\u00edes", "deer": "ciervos"}


static func _known_name(id: String) -> String:
	match id:
		"wood":
			return Kit.text("sv_wood", "madera")
		"stone":
			return Kit.text("sv_stone", "piedra")
		"fiber":
			return Kit.text("sv_fiber", "fibra")
		"berry":
			return Kit.text("sv_berry", "bayas")
		"hacha":
			return Kit.text("sv_axe", "Hacha")
		"lanza":
			return Kit.text("sv_spear", "Lanza")
		"hoguera":
			return Kit.text("sv_fire", "Hoguera")
		"balsa":
			return Kit.text("sv_raft", "Balsa")
	return ""


const ITEM_COL: Dictionary = {"wood": Color("#a86b3c"), "stone": Color("#9aa3ad"), "fiber": Color("#9ccc65"), "berry": Color("#e05a6a"),
	"meat": Color("#e57373"), "cooked": Color("#b5652e"), "scrap": Color("#90a4ae"), "cloth": Color("#d7ccc8"), "can": Color("#cfd8dc"),
	"venda": Color("#ffffff"), "fur": Color("#a1785a")}


static func item_col(id: String) -> Color:
	if ITEM_COL.has(id):
		return ITEM_COL[id]
	return Color.from_hsv(float(hash(id) % 360) / 360.0, 0.45, 0.9)


## Lo que se ve en la mochila: lo que piden las recetas y lo demas que llevas (hasta 6).
func shown_items() -> Array[String]:
	var out: Array[String] = []
	var inv: Dictionary = st["me"]["inv"]
	for id: String in craft_ids():
		for it: String in M.recipe(st, id):
			if not out.has(it) and (int(inv.get(it, 0)) > 0 or out.size() < 4):
				out.append(it)
	for it2: String in inv:
		if int(inv[it2]) > 0 and not out.has(it2):
			out.append(it2)
	var food: String = M.best_food(st)
	if food != "" and not out.has(food):
		out.append(food)
	return out.slice(0, 6)


## Barras de vida, comida y agua (con su icono) y la mochila debajo.
func _draw_bars() -> void:
	if st.is_empty():
		return
	var me: Dictionary = st["me"]
	var rows: Array = [["hp", Color("#ef5350"), float(me["hp"])], ["food", Color("#ffa726"), float(me["food"])], ["water", Color("#42a5f5"), float(me["water"])]]
	if float(st["cat"]["cold"]) > 0.0:
		rows.append(["warm", Color("#80deea"), float(me["warm"])])
	for k: int in rows.size():
		var y: float = 6.0 + float(k) * 26.0
		var c: Color = rows[k][1]
		var v: float = clampf(float(rows[k][2]) / 100.0, 0.0, 1.0)
		_icon(_bars, str(rows[k][0]), Vector2(12, y + 9), c)
		_bars.draw_rect(Rect2(30, y, 200, 18), Color(0, 0, 0, 0.55))
		var low: bool = v < 0.25 and int(_t * 4.0) % 2 == 0
		_bars.draw_rect(Rect2(32, y + 2, 196.0 * v, 14), c.lightened(0.35) if low else c)
	var x: float = 4.0
	var inv: Dictionary = me["inv"]
	var f: Font = UI.font
	var items: Array[String] = shown_items()
	var step: float = minf(78.0, 326.0 / float(maxi(1, items.size())))
	var iy: float = 96.0 + (26.0 if rows.size() > 3 else 0.0)
	for item: String in items:
		_icon(_bars, item, Vector2(x + 12, iy), item_col(item))
		_bars.draw_string_outline(f, Vector2(x + 26, iy + 10), str(int(inv.get(item, 0))), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, 6, Color(0, 0, 0, 0.8))
		_bars.draw_string(f, Vector2(x + 26, iy + 10), str(int(inv.get(item, 0))), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
		x += step
	## Mochila: cuanto llevas de cuanto cabe (en rojo si esta llena).
	if int(st["cat"]["bag"]) > 0:
		var bag_t: String = "%d/%d" % [M.carried(st), int(st["cat"]["bag"])]
		var full: bool = M.bag_full(st)
		_bars.draw_string_outline(f, Vector2(240, iy + 10 + 26), bag_t, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 5, Color(0, 0, 0, 0.8))
		_bars.draw_string(f, Vector2(240, iy + 10 + 26), bag_t, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#ff8a80") if full else Color("#e0e0e0"))
	var tools: Dictionary = me["tools"]
	var tx: float = 240.0
	for tool: String in tools:
		_icon(_bars, tool, Vector2(tx + 12, 18), Color("#ffd23f"))
		if tools[tool] is int:
			## Usos que le quedan.
			_bars.draw_string_outline(f, Vector2(tx + 2, 42), str(int(tools[tool])), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color(0, 0, 0, 0.8))
			_bars.draw_string(f, Vector2(tx + 2, 42), str(int(tools[tool])), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
		tx += 30.0
	if float(me["sick"]) > 0.0:
		_icon(_bars, "sick", Vector2(tx + 12, 18), Color("#aed581"))


## Coste de una receta: icono y numero de cada cosa (en rojo lo que falta).
func _draw_cost(c: Control, id: String) -> void:
	if st.is_empty():
		return
	var have_tool: bool = M.is_tool_recipe(st, id) and (st["me"]["tools"] as Dictionary).has(id)
	var f: Font = UI.font
	if have_tool:
		c.draw_string(f, Vector2(0, 28), Kit.text("sv_have", "Hecha"), HORIZONTAL_ALIGNMENT_CENTER, c.size.x, 18, Color("#9ccc65"))
		return
	var cost: Dictionary = M.recipe(st, id)
	var n: int = cost.size()
	var cw: float = c.size.x / float(maxi(1, n))
	var k: int = 0
	for item: String in cost:
		var x0: float = cw * float(k) + cw * 0.5
		var ok: bool = int(st["me"]["inv"].get(item, 0)) >= int(cost[item])
		_icon(c, item, Vector2(x0 - 12.0, 20.0), item_col(item))
		c.draw_string(f, Vector2(x0 + 5.0, 30.0), str(int(cost[item])), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE if ok else Color("#ff8a80"))
		k += 1


## Iconos pequenos dibujados (sin archivos).
static func _icon(ci: CanvasItem, kind: String, at: Vector2, c: Color) -> void:
	match kind:
		"hp":
			ci.draw_circle(at + Vector2(-4, -2), 5, c)
			ci.draw_circle(at + Vector2(4, -2), 5, c)
			ci.draw_colored_polygon(PackedVector2Array([at + Vector2(-9, 0), at + Vector2(9, 0), at + Vector2(0, 9)]), c)
		"food", "berry":
			ci.draw_circle(at + Vector2(-3, 2), 6, c)
			ci.draw_circle(at + Vector2(4, -1), 5, c.darkened(0.15))
			ci.draw_line(at + Vector2(1, -6), at + Vector2(4, -10), Color("#5d8a3a"), 2.0)
		"water":
			ci.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -10), at + Vector2(7, 2), at + Vector2(-7, 2)]), c)
			ci.draw_circle(at + Vector2(0, 3), 7, c)
		"wood":
			ci.draw_rect(Rect2(at + Vector2(-10, -5), Vector2(20, 10)), c)
			ci.draw_circle(at + Vector2(10, 0), 5, c.lightened(0.3))
		"stone":
			ci.draw_colored_polygon(PackedVector2Array([at + Vector2(-9, 5), at + Vector2(-6, -5), at + Vector2(4, -8), at + Vector2(10, 2), at + Vector2(5, 7)]), c)
		"fiber":
			for k: int in 3:
				ci.draw_line(at + Vector2(-5 + k * 5, 8), at + Vector2(-8 + k * 8, -9), c, 3.0)
		"hacha":
			ci.draw_line(at + Vector2(-6, 9), at + Vector2(5, -8), Color("#a86b3c"), 3.0)
			ci.draw_colored_polygon(PackedVector2Array([at + Vector2(2, -10), at + Vector2(11, -6), at + Vector2(6, 0)]), c)
		"lanza":
			ci.draw_line(at + Vector2(-8, 9), at + Vector2(6, -6), Color("#a86b3c"), 3.0)
			ci.draw_colored_polygon(PackedVector2Array([at + Vector2(4, -4), at + Vector2(10, -11), at + Vector2(8, -2)]), c)
		"machete":
			ci.draw_line(at + Vector2(-8, 9), at + Vector2(-3, 4), Color("#5d4037"), 4.0)
			ci.draw_colored_polygon(PackedVector2Array([at + Vector2(-4, 3), at + Vector2(9, -10), at + Vector2(11, -6), at + Vector2(-1, 6)]), Color("#cfd8dc"))
		"abrigo":
			ci.draw_colored_polygon(PackedVector2Array([at + Vector2(-9, -6), at + Vector2(-3, -9), at + Vector2(3, -9), at + Vector2(9, -6), at + Vector2(7, 9), at + Vector2(-7, 9)]), Color("#a1785a"))
		"warm":
			ci.draw_circle(at, 4.0, c)
			for k2: int in 6:
				ci.draw_line(at + Vector2.from_angle(float(k2) * TAU / 6.0) * 5.0, at + Vector2.from_angle(float(k2) * TAU / 6.0) * 9.0, c, 2.0)
		"sick":
			ci.draw_circle(at, 8.0, c)
			ci.draw_circle(at + Vector2(-3, -2), 1.8, Color.BLACK)
			ci.draw_circle(at + Vector2(3, -2), 1.8, Color.BLACK)
			ci.draw_arc(at + Vector2(0, 5), 3.0, PI * 1.1, PI * 1.9, 6, Color.BLACK, 1.5)
		"meat", "cooked":
			ci.draw_circle(at + Vector2(2, -1), 7.0, c)
			ci.draw_line(at + Vector2(-3, 4), at + Vector2(-9, 9), Color("#f5f5f5"), 3.0)
		"can":
			ci.draw_rect(Rect2(at + Vector2(-6, -8), Vector2(12, 16)), c)
			ci.draw_rect(Rect2(at + Vector2(-6, -3), Vector2(12, 6)), Color("#e57373"))
		"venda":
			ci.draw_rect(Rect2(at + Vector2(-9, -9), Vector2(18, 18)), Color.WHITE)
			ci.draw_rect(Rect2(at + Vector2(-2, -6), Vector2(4, 12)), Color("#e53935"))
			ci.draw_rect(Rect2(at + Vector2(-6, -2), Vector2(12, 4)), Color("#e53935"))
		"scrap":
			ci.draw_colored_polygon(PackedVector2Array([at + Vector2(-9, 6), at + Vector2(-4, -7), at + Vector2(9, -3), at + Vector2(5, 8)]), c)
			ci.draw_circle(at + Vector2(1, 0), 2.5, c.darkened(0.4))
		"cloth", "fur":
			ci.draw_colored_polygon(PackedVector2Array([at + Vector2(-9, -6), at + Vector2(9, -8), at + Vector2(8, 7), at + Vector2(-8, 8)]), c)
			ci.draw_line(at + Vector2(-6, 0), at + Vector2(6, -1), c.darkened(0.3), 2.0)
		"muro", "puerta":
			for k3: int in 3:
				ci.draw_rect(Rect2(at + Vector2(-9 + k3 * 6, -8), Vector2(5, 16)), Color("#8d6e63"))
		"radio":
			ci.draw_rect(Rect2(at + Vector2(-9, -4), Vector2(18, 12)), Color("#546e7a"))
			ci.draw_line(at + Vector2(4, -4), at + Vector2(8, -11), Color("#cfd8dc"), 2.0)
			ci.draw_circle(at + Vector2(-3, 2), 3.0, Color("#263238"))
		_:
			if kind not in ["hoguera", "balsa"]:
				ci.draw_circle(at, 7.0, c)


func _big_text(text: String, col: Color, hold: float = 0.9) -> void:
	if fast or _big == null:
		return
	_big.text = text
	_big.add_theme_color_override("font_color", col)
	_big.modulate.a = 1.0
	var tw: Tween = _big.create_tween()
	tw.tween_interval(hold)
	tw.tween_property(_big, "modulate:a", 0.0, 0.4)


func _update_hud() -> void:
	var night: bool = bool(st["is_night"])
	var n: int = int(st["night_i"]) if night else int(st["survived"]) + 1
	var left: float = M.to_dawn(st) if night else M.to_night(st)
	_day_lbl.text = (Kit.text("sv_night", "Noche {n}") if night else Kit.text("sv_day", "D\u00eda {n}")).format({"n": n}) + "  %d s" % int(ceil(left))
	_day_lbl.add_theme_color_override("font_color", Color("#9fb4ff") if night else Color("#ffe08a"))
	if str(st["goal"]) == "balsa":
		var r: Dictionary = st["raft"]
		_goal_lbl.text = Kit.text("sv_goal_raft", "Construye la balsa: {w} madera y {f} fibra").format({"w": int(r["wood"]), "f": int(r["fiber"])})
	elif str(st["goal"]) == "receta":
		var wid: String = M.win_recipe(st)
		_goal_lbl.text = Kit.text("sv_goal_recipe", "Para escapar, fabrica: {x}").format({"x": item_name(wid)})
	else:
		if int(st["nights"]) == 1:
			_goal_lbl.text = Kit.text("sv_goal_night1", "Aguanta hasta el amanecer")
		else:
			_goal_lbl.text = Kit.text("sv_goal_nights", "Aguanta {n} noches: {d}/{n}").format({"n": int(st["nights"]), "d": int(st["survived"])})
	var tg: Dictionary = M.use_target(st)
	var what: String = str(tg.get("what", ""))
	_use_btn.text = {"hit": Kit.text("sv_hit", "Golpear"), "drink": Kit.text("sv_drink", "Beber"), "fuel": Kit.text("sv_fuel", "Le\u00f1a"),
		"gather": Kit.text("sv_gather", "Recoger"), "cook": Kit.text("sv_cook", "Cocinar")}.get(what, Kit.text("sv_use", "Usar"))
	_use_btn.disabled = what == "" and (st["me"]["job"] as Dictionary).is_empty()
	var berries: int = 0
	for it: String in st["me"]["inv"]:
		var d: Dictionary = M.item_def(st, it)
		if float(d.get("food", 0.0)) + float(d.get("heal", 0.0)) > 0.0:
			berries += int(st["me"]["inv"][it])
	_eat_btn.text = Kit.text("sv_eat", "Comer") + " (%d)" % berries
	_eat_btn.disabled = berries <= 0
	for id: String in _craft_btns:
		var b: Button = _craft_btns[id]
		b.text = item_name(id)
		b.disabled = not M.can_craft(st, id)
		(b.get_node("Cost") as Control).queue_redraw()
	for b2: Control in [_use_btn, _eat_btn]:
		b2.visible = not _bot
	for b3: Control in _craft_btns.values():
		b3.visible = not _bot
	## El mando no nace encima de los botones.
	if _stick != null:
		var bl: Array[Rect2] = []
		for b4: Control in [_use_btn, _eat_btn] + _craft_btns.values():
			if b4.visible:
				bl.append(b4.get_global_rect().grow(8.0))
		_stick.blocked = bl
	_bars.queue_redraw()


# ------------------------------------------------------------------ bucle

func can_act() -> bool:
	return not finished and is_inside_tree() and not get_tree().paused


func bot_step() -> void:
	_bot = true


func _sfx(n: String, vol: float = -10.0, pitch: float = 1.0) -> void:
	if not fast:
		Audio.play(n, 0.05, vol, pitch)


func _physics_process(delta: float) -> void:
	_t += delta
	if finished:
		return
	if fast and auto_retry:
		_bot = true
	var steps: int = 4 if fast else 1
	for k: int in steps:
		if finished or get_tree().paused:
			break
		var inp: Dictionary
		if _bot:
			inp = M.bot_control(st, delta)
		else:
			var mv: Vector2 = _stick.vector if _stick != null else Vector2.ZERO
			var keys: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
			if keys.length() > 0.1:
				mv = keys
			inp = {"move": mv, "use": _use_pressed or Input.is_action_just_pressed("jump"), "eat": _eat_pressed, "craft": _craft_req}
			_use_pressed = false
			_eat_pressed = false
			_craft_req = ""
		M.step(st, inp, delta)
		time_in_level += delta
		_events()
		if bool(st["over"]):
			_end()
			break
	_sync(delta)


func _events() -> void:
	var me: Dictionary = st["me"]
	var at: Vector2 = (me["p"] as Vector2) * T + Vector2(0, -T * 0.8)
	for e: Dictionary in st["events"]:
		match str(e["kind"]):
			"gather":
				_props_dirty = true
				var it: String = str(e["item"])
				if it == "crate":
					var loot: Dictionary = M.tile_def(st, M.tile(st, e["cell"])).get("loot", {})
					var parts: PackedStringArray = []
					for k: String in loot:
						parts.append("+%d %s" % [int(loot[k]), item_name(k)])
					_float("  ".join(parts), at, Color("#ffd23f"))
					_sfx("coin", -6.0)
				else:
					_float("+1 " + item_name(it), at, ITEM_COL.get(it, Color.WHITE))
					_sfx("click", -14.0, 0.9 + randf() * 0.2)
			"depleted", "regrow":
				_props_dirty = true
			"drink":
				_float(Kit.text("sv_drank", "\u00a1Agua!"), at, Color("#42a5f5"))
				_sfx("powerup", -12.0, 1.4)
			"eat":
				_float("+%d" % int(e.get("food", M.BERRY_FOOD)), at, Color("#ffa726"))
				_sfx("coin", -12.0, 1.3)
			"fuel":
				_float("+%d s" % int(M.WOOD_FUEL), at, Color("#ffb347"))
				_sfx("click", -10.0, 0.7)
			"cook":
				_float("+1 " + item_name(str(e["item"])), at, Color("#ffb347"))
				_sfx("powerup", -12.0, 0.9)
			"sick":
				_float(Kit.text("sv_sick", "\u00a1Crudo! Te sienta mal"), at, Color("#aed581"))
			"tool_broke":
				_float(Kit.text("sv_broke", "Se ha roto: {x}").format({"x": item_name(str(e["item"]))}), at, Color("#ff8a80"))
				_sfx("hurt", -12.0, 1.3)
			"bag_full":
				_float(Kit.text("sv_bag_full", "Mochila llena"), at, Color("#ff8a80"))
			"need_tool":
				_float(Kit.text("sv_need", "Necesitas: {x}").format({"x": item_name(str(e["item"]))}), at, Color("#ff8a80"))
			"loot":
				var parts2: PackedStringArray = []
				for k4: String in e["items"]:
					parts2.append("+%d %s" % [int(e["items"][k4]), item_name(k4)])
				_float("  ".join(parts2), at + Vector2(0, -30), Color("#ffd23f"))
			"build":
				_props_dirty = true
				_sfx("click", -6.0, 0.6)
			"craft":
				var id: String = str(e["item"])
				_big_text("\u00a1" + item_name(id) + "!", Color("#ffd23f"), 0.5)
				_sfx("powerup", -6.0)
				_props_dirty = true
			"night":
				_big_text(Kit.text("sv_dusk", "Cae la noche"), Color("#9fb4ff"), 1.0)
				_sfx("ui_big", -6.0, 0.8)
			"dawn":
				_big_text(Kit.text("sv_dawn", "Amanece: noche {n} superada").format({"n": int(e["n"])}), Color("#ffe08a"), 1.0)
				_sfx("win", -10.0)
				coins += 2
				_autosave()
			"bite":
				_sfx("hurt", -6.0)
				Juice.shake(0.25)
				Juice.vibrate(40)
				if _player_art != null:
					Juice.flash(_player_art, Color(3, 0.6, 0.6, 1))
			"hit_wolf":
				_sfx("stomp", -8.0)
				var wn: Node2D = _wolves.get(int(e["id"])) as Node2D
				if wn != null:
					Juice.flash(wn)
					if bool(e["dead"]):
						Juice.burst(self, wn.position, _creature_col(str(e.get("kind", "wolf"))), 10)
						coins += 1
			"fire_out":
				_float(Kit.text("sv_fire_out", "La hoguera se ha apagado"), at, Color("#ffb347"))
				_props_dirty = true
	(st["events"] as Array).clear()


func _float(text: String, at: Vector2, col: Color) -> void:
	if fast:
		return
	if view3d != null:
		## En 3D, el texto sale en la interfaz encima del jugador.
		UI.float_text(_hud, view3d.screen_pos(st["me"]["p"]), text, col, 26)
		return
	UI.float_text(self, at, text, col, 26)


func _sync(delta: float) -> void:
	var me: Dictionary = st["me"]
	var mp: Vector2 = (me["p"] as Vector2) * T
	_player.position = mp
	if _player_art != null:
		var moving: bool = (_stick != null and _stick.vector.length() > 0.15) or (_bot and (me["job"] as Dictionary).is_empty())
		var anim: String = "run" if moving and _player_art.sprite_frames.has_animation("run") else "idle"
		if _player_art.sprite_frames.has_animation(anim) and _player_art.animation != anim:
			_player_art.play(anim)
		var face: Vector2 = me["face"]
		if absf(face.x) > 0.2:
			_player_art.flip_h = face.x < 0.0
		## Recogiendo: un golpecito ritmico.
		_player_art.rotation = sin(_t * 18.0) * 0.12 if not (me["job"] as Dictionary).is_empty() else 0.0
	_camera.position = mp
	## Lobos.
	var alive: Dictionary = {}
	for wf: Dictionary in st["wolves_list"]:
		var id: int = int(wf["id"])
		alive[id] = true
		var n: Node2D = _wolves.get(id) as Node2D
		if n == null:
			n = _wolf_node(id, str(wf.get("kind", "wolf")))
			_wolves[id] = n
			n.position = (wf["p"] as Vector2) * T
		var np: Vector2 = (wf["p"] as Vector2) * T
		var dx: float = np.x - n.position.x
		n.position = np
		if absf(dx) > 0.5:
			n.scale.x = -1.0 if dx < 0.0 else 1.0
		n.modulate.a = 0.5 if bool(wf["leaving"]) else 1.0
	for id2: int in _wolves.keys():
		if not alive.has(id2):
			(_wolves[id2] as Node).queue_free()
			_wolves.erase(id2)
	## Dia y noche: se oscurece poco a poco y la hoguera alumbra.
	var cyc: float = float(st["day"]) + float(st["night"])
	var f: float = fmod(float(st["t"]), cyc)
	var dark: float = 0.0
	if f >= float(st["day"]):
		dark = clampf((f - float(st["day"])) / 4.0, 0.0, 1.0) * clampf((cyc - f) / 4.0, 0.0, 1.0)
	elif float(st["day"]) - f < 8.0:
		dark = (8.0 - (float(st["day"]) - f)) / 8.0 * 0.35
	_tint.color = Color.WHITE.lerp(NIGHT_TINT, dark)
	_me_light.enabled = dark > 0.05
	_me_light.position = mp
	var on: bool = M.fire_on(st)
	_fire_light.enabled = on and dark > 0.05
	if on:
		_fire_light.position = (st["fire"]["p"] as Vector2) * T
		_fire_light.energy = 1.1 + sin(_t * 9.0) * 0.08 + sin(_t * 23.0) * 0.05
	if view3d != null:
		if _props_dirty:
			_props_dirty = false
			view3d.rebuild_props()
		view3d.sync(delta)
	elif _props_dirty or int(_t * 6.0) != int((_t - delta) * 6.0):
		_props_dirty = false
		_props.queue_redraw()
	_update_hud()


# ------------------------------------------------------------------ dibujo

func _draw_ground() -> void:
	var sea: Color = M.pal(st, "sea", Color("#1f6fa8"))
	var sand: Color = M.pal(st, "sand", Color("#e8d39a"))
	var grass: Color = Kit.color("ground", Color("#6fae4f"))
	if grass.get_luminance() < 0.25 or grass.s < 0.2:
		grass = Color("#6fae4f")
	grass = M.pal(st, "ground", grass)
	var w: int = int(st["w"])
	var h: int = int(st["h"])
	for y: int in h:
		for x: int in w:
			var c: Vector2i = Vector2i(x, y)
			var r: Rect2 = Rect2(Vector2(x, y) * T, Vector2(T, T))
			var ch: String = str(st["grid"][y][x])
			if ch == "~":
				_ground.draw_rect(r, sea if (x + y) % 2 == 0 else sea.lightened(0.04))
				continue
			var base: Color = sand if ch == "," else grass
			var noise: float = float((x * 73 + y * 151) % 7) / 7.0
			_ground.draw_rect(r, base.lightened(noise * 0.06))
			if bool(M.tile_def(st, ch).get("water", false)):
				_ground.draw_rect(r.grow(-2.0), Color("#3fa7e0"))
				_ground.draw_rect(Rect2(r.position + Vector2(10, 14), Vector2(22, 4)), Color(1, 1, 1, 0.5))
			## Orilla: espuma donde la arena toca el mar.
			for d: Vector2i in M.DIRS:
				if M.tile(st, c + d) == "~":
					var e: Rect2 = Rect2(r.position + Vector2(maxf(0, d.x) * (T - 6), maxf(0, d.y) * (T - 6)), Vector2(T if d.x == 0 else 6.0, T if d.y == 0 else 6.0))
					_ground.draw_rect(e, Color(1, 1, 1, 0.55))


func _draw_props() -> void:
	var w: int = int(st["w"])
	var h: int = int(st["h"])
	for y: int in h:
		for x: int in w:
			var c: Vector2i = Vector2i(x, y)
			var ctr: Vector2 = M.center(c) * T
			var ch: String = str(st["grid"][y][x])
			match M.look(st, ch):
				"T":
					var left: int = int(st["res"][c]["left"]) if st["res"].has(c) else 1
					_props.draw_circle(ctr + Vector2(4, 10), T * 0.42, Color(0, 0, 0, 0.18))
					_props.draw_rect(Rect2(ctr + Vector2(-6, -4), Vector2(12, 22)), Color("#7a4b2a"))
					var g: Color = M.tint(st, ch, Color("#2f7d32")).lerp(M.tint(st, ch, Color("#4caf50")).lightened(0.15), float((x * 31 + y * 17) % 5) / 5.0)
					var s: float = 0.75 + 0.25 * float(left) / float(M.tile_yield(st, ch))
					_props.draw_circle(ctr + Vector2(0, -12), T * 0.36 * s, g.darkened(0.15))
					_props.draw_circle(ctr + Vector2(-8, -18), T * 0.26 * s, g)
					_props.draw_circle(ctr + Vector2(8, -20), T * 0.22 * s, g.lightened(0.12))
				"R":
					_props.draw_colored_polygon(PackedVector2Array([ctr + Vector2(-24, 16), ctr + Vector2(-18, -8), ctr + Vector2(0, -20), ctr + Vector2(20, -10), ctr + Vector2(24, 14)]), Color("#8d96a0"))
					_props.draw_colored_polygon(PackedVector2Array([ctr + Vector2(-10, -6), ctr + Vector2(0, -16), ctr + Vector2(12, -8)]), Color("#b4bcc5"))
				"G":
					for k: int in 5:
						var bx: float = -16.0 + float(k) * 8.0
						_props.draw_line(ctr + Vector2(bx, 14), ctr + Vector2(bx + (float(k) - 2.0) * 3.0, -14 - float(k % 2) * 6.0), Color("#8bc34a"), 4.0)
				"B":
					var n_b: int = int(st["res"][c]["left"]) if st["res"].has(c) else 0
					_props.draw_circle(ctr + Vector2(2, 8), T * 0.36, Color(0, 0, 0, 0.15))
					_props.draw_circle(ctr, T * 0.34, M.tint(st, ch, Color("#3e8e41")))
					_props.draw_circle(ctr + Vector2(-8, -6), T * 0.2, M.tint(st, ch, Color("#4caf50")).lightened(0.12))
					for k2: int in n_b:
						_props.draw_circle(ctr + Vector2(-10 + k2 * 10, -2 + (k2 % 2) * 10), 6.0, Color("#e53950"))
				"D":
					_props.draw_circle(ctr + Vector2(0, 6), T * 0.46, M.tint(st, ch, Color("#4e4036")))
					_props.draw_circle(ctr + Vector2(0, 10), T * 0.3, Color("#151010"))
					_props.draw_circle(ctr + Vector2(-7, 6), 3.0, Color("#ffe066") if bool(st["is_night"]) else Color(0, 0, 0, 0))
					_props.draw_circle(ctr + Vector2(7, 6), 3.0, Color("#ffe066") if bool(st["is_night"]) else Color(0, 0, 0, 0))
				"X":
					_props.draw_rect(Rect2(ctr + Vector2(-20, -14), Vector2(40, 28)), Color("#a8743f"))
					_props.draw_rect(Rect2(ctr + Vector2(-20, -3), Vector2(40, 5)), Color("#6d4422"))
					_props.draw_rect(Rect2(ctr + Vector2(-3, -14), Vector2(6, 28)), Color("#6d4422"))
				"H":
					## Casa en ruinas: paredes, tejado roto y una puerta oscura (gris si ya esta saqueada).
					var done: bool = not st["res"].has(c)
					var wall: Color = Color("#b7a58c") if not done else Color("#8a8178")
					_props.draw_rect(Rect2(ctr + Vector2(-26, -10), Vector2(52, 34)), wall)
					_props.draw_colored_polygon(PackedVector2Array([ctr + Vector2(-30, -8), ctr + Vector2(0, -30), ctr + Vector2(22, -14), ctr + Vector2(30, -8)]), Color("#7b3f2e"))
					_props.draw_rect(Rect2(ctr + Vector2(-6, 4), Vector2(12, 20)), Color("#2b2320"))
					_props.draw_rect(Rect2(ctr + Vector2(10, -2), Vector2(10, 9)), Color("#cfe8ff") if not done else Color("#3a3a3a"))
				"C":
					## Coche abandonado.
					var car: Color = Color("#c0543c") if st["res"].has(c) else Color("#7d6e66")
					_props.draw_rect(Rect2(ctr + Vector2(-28, -6), Vector2(56, 20)), car)
					_props.draw_rect(Rect2(ctr + Vector2(-16, -18), Vector2(30, 14)), car.lightened(0.1))
					_props.draw_rect(Rect2(ctr + Vector2(-12, -15), Vector2(22, 9)), Color("#9fb8c8"))
					_props.draw_circle(ctr + Vector2(-17, 15), 7.0, Color("#222222"))
					_props.draw_circle(ctr + Vector2(17, 15), 7.0, Color("#222222"))
	## Construcciones: muros, puertas, mesa y cama.
	for bc: Vector2i in st["built"]:
		var bctr: Vector2 = M.center(bc) * T
		match str(st["built"][bc]):
			"muro":
				_props.draw_rect(Rect2(bctr - Vector2(T, T) * 0.5, Vector2(T, T)), Color("#8d6e63"))
				for k4: int in 4:
					_props.draw_line(bctr + Vector2(-T * 0.5 + float(k4) * T * 0.25 + 8, -T * 0.5), bctr + Vector2(-T * 0.5 + float(k4) * T * 0.25 + 8, T * 0.5), Color("#5d4037"), 3.0)
			"puerta":
				_props.draw_rect(Rect2(bctr - Vector2(T, T) * 0.5, Vector2(T, T)), Color("#a1887f"))
				_props.draw_rect(Rect2(bctr - Vector2(T * 0.3, T * 0.4), Vector2(T * 0.6, T * 0.8)), Color("#5d4037"))
			"mesa":
				_props.draw_rect(Rect2(bctr - Vector2(24, 14), Vector2(48, 28)), Color("#a1887f"))
			"cama":
				_props.draw_rect(Rect2(bctr - Vector2(18, 26), Vector2(36, 52)), Color("#90a4ae"))
				_props.draw_rect(Rect2(bctr - Vector2(18, 26), Vector2(36, 14)), Color.WHITE)
	## Hoguera: piedras en corro, lenos y llama que baila (o cenizas si se apago).
	var fire: Dictionary = st["fire"]
	if not fire.is_empty():
		var fp: Vector2 = (fire["p"] as Vector2) * T
		for k3: int in 8:
			_props.draw_circle(fp + Vector2.from_angle(TAU * float(k3) / 8.0) * 20.0, 6.0, Color("#8d96a0"))
		_props.draw_line(fp + Vector2(-12, 8), fp + Vector2(12, -4), Color("#6d4422"), 6.0)
		_props.draw_line(fp + Vector2(-12, -4), fp + Vector2(12, 8), Color("#6d4422"), 6.0)
		if M.fire_on(st):
			var fl: float = 1.0 + sin(_t * 14.0) * 0.12
			_props.draw_colored_polygon(PackedVector2Array([fp + Vector2(-12, 4), fp + Vector2(0, -30 * fl), fp + Vector2(12, 4)]), Color("#ff7a1a"))
			_props.draw_colored_polygon(PackedVector2Array([fp + Vector2(-6, 4), fp + Vector2(0, -16 * fl), fp + Vector2(6, 4)]), Color("#ffe066"))
			## Lo que le queda de lena: un arco.
			var frac: float = clampf(float(fire["fuel"]) / M.FIRE_MAX, 0.0, 1.0)
			_props.draw_arc(fp, 30.0, -PI * 0.5, -PI * 0.5 + TAU * frac, 24, Color(1.0, 0.75, 0.3, 0.8), 4.0)


# ------------------------------------------------------------------ toques y final

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()
		return
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		_bot = false
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		match (event as InputEventKey).keycode:
			KEY_E, KEY_SPACE:
				_use_pressed = true
			KEY_Q:
				_eat_pressed = true
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
				var ids: Array[String] = craft_ids()
				var k: int = int((event as InputEventKey).keycode) - int(KEY_1)
				if k < ids.size():
					_craft_req = ids[k]


func _end() -> void:
	if bool(st["won"]):
		_finish()
	else:
		_lose()


## Guarda la partida al amanecer (la de este nivel; al ganar o perder se borra).
func _autosave() -> void:
	if UI.test_mode or _bot:
		return
	Save.set_setting(SAVE_KEY, {"level": _save_id(), "snap": M.snapshot(st)})


func _clear_save() -> void:
	var saved: Variant = Save.get_setting(SAVE_KEY, {})
	if saved is Dictionary and not (saved as Dictionary).is_empty():
		Save.set_setting(SAVE_KEY, {})


func _finish() -> void:
	if finished:
		return
	finished = true
	_clear_save()
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	var hp: float = float(st["me"]["hp"])
	var score: int = maxi(1, int(st["survived"]) * 800 + int(hp) * 20 + maxi(0, int(par - time_in_level)) * 5 + (1500 if str(st["goal"]) == "balsa" else 0))
	coins = maxi(coins, 3) + (4 if str(st["goal"]) == "balsa" else 0)
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "time": snappedf(time_in_level, 0.1), "hp": int(hp), "goal": str(st["goal"])})
	Audio.play("win")
	Audio.play_track("victoria", false)
	if str(st["goal"]) == "balsa":
		_big_text(Kit.text("sv_escaped", "\u00a1Escapas de la isla!"), Color("#ffd23f"), 1.2)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	await Ads.show_interstitial("level_end")


func stars_earned() -> int:
	var hp: float = float(st["me"]["hp"])
	return 3 if hp >= 70.0 else (2 if hp >= 35.0 else 1)


func _lose() -> void:
	if finished:
		return
	finished = true
	failed = true
	deaths += 1
	_clear_save()
	var cause: String = str(st["cause"])
	QA.log_event("death", {"cause": cause, "t": snappedf(time_in_level, 0.1), "night": int(st["night_i"])})
	Audio.play("hurt")
	Juice.shake(0.4)
	if auto_retry:
		retry.call_deferred()
		return
	var title: String = {"sed": Kit.text("sv_lost_thirst", "Te has quedado sin agua"), "hambre": Kit.text("sv_lost_hunger", "Te has quedado sin comida"),
		"lobos": Kit.text("sv_lost_wolves", "Los lobos te han pillado"), "frio": Kit.text("sv_lost_cold", "Te has congelado"),
		"enfermo": Kit.text("sv_lost_sick", "La comida cruda te ha sentado fatal")}.get(cause, "")
	if title == "" and cause in (st["cat"]["creatures"] as Dictionary):
		title = Kit.text("sv_lost_beast", "Te han pillado los {x}").format({"x": item_name(cause)})
	if title == "":
		title = Kit.text("survival_lost", "No has sobrevivido")
	var hint: String = Kit.text("survival_hint", "Bebe y come antes de la noche, enciende la hoguera junto a la charca y qu\u00e9date a su luz: los lobos no se acercan al fuego.")
	var p: FailPanel = FailPanel.open(self, title, hint)
	p.closed.connect(retry)


func retry() -> void:
	_reset()
	finished = false
	failed = false
	if view3d != null:
		view3d.queue_free()
		view3d = Survival3DView.new()
		add_child(view3d)
		view3d.setup(self)
	if _ground != null:
		_ground.queue_redraw()
		_props.queue_redraw()
		_sync(1.0)
		_camera.reset_smoothing()


func open_pause() -> void:
	if finished or get_tree().paused or get_node_or_null("PauseMenu") != null:
		return
	PauseMenu.open(self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_inside_tree() and not UI.test_mode:
			open_pause()


func bot_state() -> Dictionary:
	if st.is_empty():
		return {}
	var me: Dictionary = st["me"]
	return {"deaths": deaths, "coins": coins, "finished": finished, "failed": failed, "time": time_in_level,
		"hp": float(me["hp"]), "food": float(me["food"]), "water": float(me["water"]), "survived": int(st["survived"]), "goal": str(st["goal"])}
