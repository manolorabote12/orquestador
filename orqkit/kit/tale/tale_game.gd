extends Node2D
## Aventura: historia con decisiones (estilo novela visual). Reglas y analizador en tale_map.gd.
## 1 - Cada escena: quien habla (con su retrato) y su texto, que va saliendo letra a letra
##     (tocar lo completa). Despues salen las decisiones.
## 2 - Las decisiones cambian valor, amistad y oro o dan objetos; algunas piden un minimo o un
##     objeto (salen apagadas diciendo lo que falta). Todo sigue de un capitulo al siguiente.
## 3 - Cada capitulo acaba en un final bueno (3 estrellas), regular (2) o malo (1).
## Contrato con el kit: finished, deaths, time_in_level, fast, auto_retry, bot_script(),
## bot_state(), retry(), open_pause() y ResultPanel al acabar.

const MapRules = preload("res://kit/tale/tale_map.gd")
const CHAR_SPEED: float = 45.0

var level: Dictionary = {}
var finished: bool = false
var failed: bool = false
var deaths: int = 0
var time_in_level: float = 0.0
var coins: int = 0
var coins_total: int = 3
var fast: bool = false
var auto_retry: bool = false
var result_panel: ResultPanel
var scene_id: String = ""
var stats: Dictionary = {}
var items: Array = []
var ending: String = ""
var steps: int = 0
## Historial del capitulo: [{"who", "text"}] y [{"choice"}] (boton Historial).
var history: Array = []

var _by_id: Dictionary = {}
var _cast: Dictionary = {}
var _font: Font
var _world: Node2D
var _camera: Camera2D
var _title: Label
var _stats_label: Label
var _name: Label
var _text: Label
var _choices: VBoxContainer
var _box: PanelContainer
var _portrait: TextureRect
var _shown: float = 0.0
var _t: float = 0.0
var _fade: float = 0.0


func _ready() -> void:
	level = Kit.current_level()
	_by_id = MapRules.scenes_by_id(level)
	_cast = Story.cast()
	RenderingServer.set_default_clear_color(Color("#1a1626"))
	_font = UI.theme.get_font("font", "Label") if UI.theme != null else ThemeDB.fallback_font
	_world = Node2D.new()
	_world.name = "World"
	_world.draw.connect(_draw_world)
	add_child(_world)
	_camera = Camera2D.new()
	add_child(_camera)
	_camera.make_current()
	_camera.position = Vector2(360, 640)
	_build_hud()
	_reset()
	Audio.play_track("nivel")
	QA.log_event("level_start", {"level": Kit.level_index, "genre": "tale", "scenes": _by_id.size()})


func bot_script() -> String:
	return "res://qa/tale_bot.gd"


func capture_delays() -> Vector2:
	return Vector2(3.0, 2.5)


## Estadisticas y objetos que vienen del capitulo anterior (a cero en el primero).
func _carried() -> Array:
	var all: Variant = Save.meta().get("tale", {})
	var key: String = str(Kit.config.get("title", ""))
	if Kit.level_index == 0 or not all is Dictionary or not (all as Dictionary).has(key) or UI.test_mode or QA.enabled:
		return [{"valor": 0, "amistad": 0, "oro": 0}, []]
	var d: Dictionary = (all as Dictionary)[key]
	var s: Dictionary = {}
	for k: String in MapRules.STATS:
		s[k] = maxi(0, int((d.get("stats", {}) as Dictionary).get(k, 0)))
	return [s, (d.get("items", []) as Array).duplicate()]


func _reset() -> void:
	finished = false
	failed = false
	time_in_level = 0.0
	ending = ""
	steps = 0
	history = []
	var c: Array = _carried()
	stats = c[0]
	items = c[1]
	_go(MapRules.first_id(level))


func who_name(who: String) -> String:
	var p: Dictionary = _cast.get(who, {})
	var n: String = str(p.get("name", ""))
	if n == "":
		n = str((level.get("cast", {}) as Dictionary).get(who, ""))
	if n == "" and who != "narrador":
		n = Kit.text("tale_who_" + who, {"heroe": "T\u00fa", "rival": "Rival", "jefe": "Jefe", "aliado": "Aliado"}.get(who, ""))
	return n


func _go(id: String) -> void:
	scene_id = id
	var sc: Dictionary = _by_id.get(id, {})
	var who: String = str(sc.get("who", "narrador"))
	_name.text = who_name(who)
	_name.visible = _name.text != "" and who != "narrador"
	_name.add_theme_color_override("font_color", UI.colors["peligro"] if who in ["rival", "jefe"] else UI.colors["acento"])
	_text.text = str(sc.get("text", ""))
	history.append({"who": _name.text if _name.visible else "", "text": _text.text})
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if who == "narrador" else HORIZONTAL_ALIGNMENT_LEFT
	_text.visible_characters = 0
	_shown = 0.0
	_fade = 0.35
	var tex: Texture2D = null
	if who != "narrador":
		var p: Dictionary = _cast.get(who, {})
		var entry: Variant = p.get("sprite", {})
		if (entry as Dictionary).is_empty():
			entry = Kit.sprite_by_role({"heroe": "jugador", "rival": "enemigo", "jefe": "jefe", "aliado": "jugador"}.get(who, "-"))
		tex = DialogPanel.portrait_of(entry)
	_portrait.texture = tex
	_portrait.visible = tex != null
	_portrait.flip_h = who in ["rival", "jefe"]
	_clear_choices()
	_refresh_stats()
	if fast:
		_reveal()


func _reveal() -> void:
	_text.visible_characters = -1
	_shown = 9999.0
	_show_choices()


func _clear_choices() -> void:
	for c: Node in _choices.get_children():
		_choices.remove_child(c)
		c.queue_free()


func _need_text(need: Dictionary) -> String:
	if need.has("objeto"):
		return Kit.text("tale_need_item", "Necesitas: {o}").format({"o": str(need["objeto"])})
	return Kit.text("tale_need_stat", "Necesitas {s} {n}").format({"s": stat_name(str(need.get("stat", ""))), "n": int(need.get("min", 0))})


func stat_name(s: String) -> String:
	return Kit.text("tale_stat_" + s, {"valor": "Valor", "amistad": "Amistad", "oro": "Oro"}.get(s, s))


func _show_choices() -> void:
	if _choices.get_child_count() > 0:
		return
	var sc: Dictionary = _by_id.get(scene_id, {})
	var opts: Array = sc.get("options", [])
	for i: int in opts.size():
		var o: Dictionary = opts[i]
		var ok: bool = MapRules.allowed(o, stats, items)
		var txt: String = str(o.get("text", ""))
		if not ok:
			txt += "  (" + _need_text(o.get("need", {})) + ")"
		var b: Button = UI.make_button(txt, i == 0 and ok, "")
		b.name = "Choice_%d" % i
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(0, UI.MIN_TOUCH)
		b.disabled = not ok
		b.pressed.connect(choose.bind(i))
		_choices.add_child(b)
		if not fast:
			UI.pop_in(b, 0.06 * float(i))


func choose(i: int) -> bool:
	if not can_act() or _shown < float(_text.text.length()):
		return false
	var sc: Dictionary = _by_id.get(scene_id, {})
	var opts: Array = sc.get("options", [])
	if i < 0 or i >= opts.size() or not MapRules.allowed(opts[i], stats, items):
		return false
	var o: Dictionary = opts[i]
	history.append({"choice": str(o.get("text", ""))})
	var r: Array = MapRules.apply(o, stats, items)
	var before: Dictionary = stats.duplicate()
	stats = r[0]
	var got: Array = []
	for it: Variant in r[1]:
		if not items.has(it):
			got.append(it)
	items = r[1]
	steps += 1
	if not fast:
		Audio.play("click", 0.05)
		for k: String in MapRules.STATS:
			var dlt: int = int(stats.get(k, 0)) - int(before.get(k, 0))
			if dlt != 0:
				UI.float_text(_box, Vector2(_box.size.x * 0.5, -20.0), "%s %+d" % [stat_name(k), dlt], Color("#9ff0a8") if dlt > 0 else Color("#ff8a7a"))
		for it: Variant in got:
			UI.float_text(_box, Vector2(_box.size.x * 0.5, -60.0), "+ " + str(it), Color("#ffd23f"))
	var to: String = str(o.get("to", ""))
	if MapRules.ENDS.has(to):
		_end(str(MapRules.ENDS[to]))
	else:
		_go(to)
	return true


func can_act() -> bool:
	return not finished and is_inside_tree() and not get_tree().paused


## Lo que elegiria el bot: el camino al final bueno con lo que se lleva.
func bot_choice() -> int:
	var path: Array = MapRules.path_to(_level_from_here(), "bueno", stats, items)
	return int(path[0]) if not path.is_empty() else -1


func _level_from_here() -> Dictionary:
	## Mismo capitulo pero empezando en la escena actual.
	var sc: Array = (level.get("scenes", []) as Array).duplicate()
	for i: int in sc.size():
		if str((sc[i] as Dictionary).get("id", "")) == scene_id:
			var cur: Variant = sc[i]
			sc.remove_at(i)
			sc.insert(0, cur)
			break
	return {"scenes": sc}


func bot_step() -> void:
	if finished:
		return
	_reveal()
	var c: int = bot_choice()
	if c < 0:
		## Sin camino al final bueno: la primera opcion que se pueda.
		var opts: Array = (_by_id.get(scene_id, {}) as Dictionary).get("options", [])
		for i: int in opts.size():
			if MapRules.allowed(opts[i], stats, items):
				c = i
				break
	choose(c)


# ------------------------------------------------------------------ interfaz

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
	var safe: MarginContainer = UI.safe_root(root, 16.0)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col: VBoxContainer = VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 8)
	safe.add_child(col)
	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top)
	var tv: VBoxContainer = VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(tv)
	_title = Label.new()
	_title.name = "Chapter"
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_title.add_theme_constant_override("outline_size", 7)
	tv.add_child(_title)
	_stats_label = Label.new()
	_stats_label.name = "Stats"
	_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stats_label.add_theme_font_size_override("font_size", 22)
	_stats_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_stats_label.add_theme_constant_override("outline_size", 6)
	tv.add_child(_stats_label)
	var log_btn: Button = UI.make_button(Kit.text("tale_log", "Historial"), false, "")
	log_btn.name = "BtnHistory"
	log_btn.pressed.connect(open_history)
	top.add_child(log_btn)
	var pause_btn: Button = UI.make_icon_button("pause")
	pause_btn.name = "BtnPause"
	pause_btn.pressed.connect(open_pause)
	top.add_child(pause_btn)
	var grow: Control = Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(grow)
	_portrait = TextureRect.new()
	_portrait.name = "Portrait"
	_portrait.custom_minimum_size = Vector2(0, 300)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_portrait)
	_box = PanelContainer.new()
	_box.name = "TextBox"
	col.add_child(_box)
	var bv: VBoxContainer = VBoxContainer.new()
	bv.add_theme_constant_override("separation", 10)
	_box.add_child(bv)
	_name = Label.new()
	_name.name = "Name"
	bv.add_child(_name)
	_text = Label.new()
	_text.name = "Text"
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(0, 150)
	bv.add_child(_text)
	_choices = VBoxContainer.new()
	_choices.name = "Choices"
	_choices.add_theme_constant_override("separation", 10)
	col.add_child(_choices)
	_box.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed:
			_reveal())


func _refresh_stats() -> void:
	_title.text = str(level.get("title", level.get("name", "")))
	var parts: Array[String] = []
	for k: String in MapRules.STATS:
		parts.append("%s %d" % [stat_name(k), int(stats.get(k, 0))])
	var line: String = "   ".join(parts)
	if not items.is_empty():
		line += "   \u00b7  " + ", ".join(items.map(func(x: Variant) -> String: return str(x)))
	_stats_label.text = line


# ------------------------------------------------------------------ bucle

func _process(delta: float) -> void:
	if finished:
		return
	time_in_level += delta
	_t += delta
	_fade = maxf(0.0, _fade - delta)
	if _shown < float(_text.text.length()):
		_shown += delta * CHAR_SPEED
		_text.visible_characters = int(_shown)
		if _shown >= float(_text.text.length()):
			_text.visible_characters = -1
			_show_choices()
	_world.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()
		return
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed and _shown < float(_text.text.length()):
		_reveal()


# ------------------------------------------------------------------ final

func _end(kind: String) -> void:
	ending = kind
	_clear_choices()
	var titles: Dictionary = {"bueno": Kit.text("tale_end_good", "Final bueno"), "regular": Kit.text("tale_end_ok", "Final regular"),
		"malo": Kit.text("tale_end_bad", "Final malo")}
	_name.text = str(titles[kind])
	_name.visible = true
	_text.text = str((level.get("endings", {}) as Dictionary).get(kind, ""))
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.visible_characters = -1
	_shown = 9999.0
	_portrait.visible = false
	## Lo ganado sigue al capitulo siguiente.
	if not (UI.test_mode or QA.enabled):
		var all: Dictionary = Save.meta().get("tale", {}) if Save.meta().get("tale") is Dictionary else {}
		all[str(Kit.config.get("title", ""))] = {"stats": stats.duplicate(), "items": items.duplicate()}
		Save.meta()["tale"] = all
		Save.save_data()
	_finish()


func open_history() -> void:
	if get_tree().paused or get_node_or_null("TaleLogPanel") != null:
		return
	TaleLogPanel.open(self, history)


## Finales descubiertos de cada capitulo (para volver a jugarlo y encontrar los que faltan).
static func endings_found(i: int) -> Array:
	var all: Variant = Save.get_setting("tale_endings", {})
	var v: Variant = (all as Dictionary).get(str(i), []) if all is Dictionary else []
	return (v as Array).duplicate() if v is Array else []


static func record_ending(i: int, kind: String) -> bool:
	var all: Variant = Save.get_setting("tale_endings", {})
	var d: Dictionary = (all as Dictionary).duplicate(true) if all is Dictionary else {}
	var got: Array = endings_found(i)
	if got.has(kind):
		return false
	got.append(kind)
	d[str(i)] = got
	Save.set_setting("tale_endings", d)
	return true


func _finish() -> void:
	if finished:
		return
	finished = true
	var level_id: String = str(Kit.level_index)
	var stars: int = stars_earned()
	coins = stars
	var score: int = stars * 1000 + int(stats.get("oro", 0)) * 10 + int(stats.get("amistad", 0)) * 50 + int(stats.get("valor", 0)) * 50
	var record: bool = Save.submit_best(level_id, score)
	Save.submit_stars(level_id, stars)
	Save.unlock_level(Kit.level_index + 1)
	QA.log_event("level_complete", {"level": Kit.level_index, "stars": stars, "ending": ending, "steps": steps, "deaths": 0})
	Audio.play("win" if ending != "malo" else "hurt")
	if not fast:
		await get_tree().create_timer(2.2).timeout
	if not is_inside_tree():
		return
	Audio.play_track("victoria", false)
	var is_new: bool = record_ending(Kit.level_index, ending)
	result_panel = ResultPanel.open(self, {"stars": stars, "coins": coins, "coins_total": coins_total, "score": score, "record": record})
	## Coleccion de finales: cuantos llevas y que te falta.
	if result_panel.body != null and ending != "":
		var found: Array = endings_found(Kit.level_index)
		var names: Dictionary = {"bueno": Kit.text("tale_end_good", "Final bueno"), "regular": Kit.text("tale_end_ok", "Final regular"), "malo": Kit.text("tale_end_bad", "Final malo")}
		var missing: Array[String] = []
		for k: String in ["bueno", "regular", "malo"]:
			if not found.has(k):
				missing.append(str(names[k]))
		var el: Label = Label.new()
		el.name = "Endings"
		el.text = Kit.text("tale_endings", "Finales descubiertos: {n}/3").format({"n": found.size()}) + ("  \u2728" if is_new else "")
		if not missing.is_empty():
			el.text += "\n" + Kit.text("tale_missing", "Te falta: {l}").format({"l": ", ".join(missing)})
		el.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		el.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		el.add_theme_color_override("font_color", Color("#ffd166"))
		result_panel.body.add_child(el)
		result_panel.body.move_child(el, mini(2, result_panel.body.get_child_count() - 1))
	await Ads.show_interstitial("level_end")


func stars_earned() -> int:
	return {"bueno": 3, "regular": 2, "malo": 1}.get(ending, 1)


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
	return {"pos": Vector2(float(steps), 0.0), "deaths": 0, "coins": coins, "finished": finished, "failed": failed, "stomps": 0,
		"time": time_in_level, "ending": ending, "steps": steps, "scene": scene_id}


# ------------------------------------------------------------------ dibujo (si no hay fondo de la IA)

func _draw_world() -> void:
	if Look.has_level_backdrop():
		if _fade > 0.0:
			_world.draw_rect(Rect2(-100, -100, 920, 1480), Color(0, 0, 0, _fade))
		return
	var top: Color = Kit.color("sky", Color("#2a2550"))
	var low: Color = top.lerp(Color("#f2a65a"), 0.45)
	for k: int in 20:
		var f: float = float(k) / 19.0
		_world.draw_rect(Rect2(-100, -100.0 + f * 900.0, 920, 48), top.lerp(low, f))
	_world.draw_circle(Vector2(520, 380), 70.0, Color("#ffe7b0"))
	for k: int in 3:
		var y: float = 620.0 + float(k) * 70.0
		var col: Color = Color("#2a2140").lerp(Color("#140f22"), float(k) / 3.0)
		var pts: PackedVector2Array = PackedVector2Array([Vector2(-100, 1400)])
		for x: int in range(-100, 900, 40):
			pts.append(Vector2(float(x), y + sin(float(x) * 0.01 + float(k) * 2.0) * 40.0))
		pts.append(Vector2(900, 1400))
		_world.draw_colored_polygon(pts, col)
	## Castillo lejano.
	var c: Vector2 = Vector2(180, 640)
	_world.draw_rect(Rect2(c + Vector2(-40, -80), Vector2(80, 80)), Color("#1a1430"))
	for k: int in 3:
		_world.draw_rect(Rect2(c + Vector2(-50 + k * 40, -120), Vector2(20, 50)), Color("#1a1430"))
	_world.draw_rect(Rect2(c + Vector2(-6, -60), Vector2(12, 16)), Color("#ffd23f"))
	for k: int in 30:
		var sp: Vector2 = Vector2(fmod(float(k * 97), 720.0), fmod(float(k * 53), 380.0))
		_world.draw_circle(sp, 1.5 + sin(_t * 2.0 + float(k)) * 0.8, Color(1, 1, 1, 0.7))
	if _fade > 0.0:
		_world.draw_rect(Rect2(-100, -100, 920, 1480), Color(0, 0, 0, _fade))
