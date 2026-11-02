extends Node
## Clip vertical para redes (TikTok, Shorts, Reels) jugado por el bot. Se graba con el
## Movie Maker de Godot y la fabrica lo recorta y lo pasa a MP4 (fabrica/clip.py):
##   godot --path <proyecto> --resolution 720x1280 --write-movie clip.avi --fixed-fps 30 \
##     res://qa/clip.tscn -- --skip=0.5 --seconds=15
## 1 - Juega el bot desde el nivel 2 (o el unico); al ganar pasa al siguiente sin parar.
## 2 - Gancho arriba los 3 primeros segundos visibles ("Puedes superarlo?").
## 3 - Ultimos 2.5 s: cartel final con el heroe, el titulo y "Descargalo gratis".
## skip = segundos del principio que se cortan (p. ej. torres: esperar a que haya accion).
## Modo --raw (estudio de marketing): sin gancho ni cartel, y guarda en --events=<ruta.json>
## los momentos de la partida (monedas, pisotones, jefe, victoria...) con su segundo exacto
## para que la fabrica elija los mejores 15 s y monte encima subtitulos y voz.

var skip: float = 0.5
var seconds: float = 15.0
var t: float = 0.0
var game: Node
var _layer: CanvasLayer
var _hook: Label
var _end: Control
var _end_shown: bool = false
var _advancing: bool = false
var raw: bool = false
var events_path: String = ""
var moments: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--skip="):
			skip = float(a.get_slice("=", 1))
		elif a.begins_with("--seconds="):
			seconds = float(a.get_slice("=", 1))
		elif a == "--raw":
			raw = true
		elif a.begins_with("--events="):
			events_path = a.get_slice("=", 1)
	UI.test_mode = true
	Ads.enabled = false
	QA.logged.connect(_on_qa)
	Save.reset_all()
	Kit.level_index = mini(1, Kit.level_count() - 1)
	_build_overlay()
	_play_level()


func _play_level() -> void:
	if is_instance_valid(game):
		game.queue_free()
	QaBot.release_all()
	game = (load(UI.game_scene()) as PackedScene).instantiate()
	add_child(game)
	move_child(game, 0)
	await get_tree().physics_frame
	## 5 - Puzle: el bot resolveria al instante; aqui juega una jugada cada 0.8 s.
	if game.has_method("match3_bot_step"):
		_play_match3(game)
		return
	QaBot.run(get_tree(), game, 60 * 60 * 5)
	await get_tree().physics_frame
	## 6 - Plataformas, runner y volador: camara mas cerca, que en vertical se vea la accion.
	var cam: Variant = game.get("camera")
	if game.get("player") is PlayerPlatformer and cam is Camera2D:
		(cam as Camera2D).zoom = Vector2(1.35, 1.35)
	## 4 - Torres, carreras y generos nuevos: con efectos (el bot los quita para ir rapido).
	if game.has_method("tower_bot_step") or game.has_method("race_bot_step") or game.has_method("bot_script"):
		game.set("fast", false)


func _play_match3(g: Node) -> void:
	while is_instance_valid(g) and not bool(g.get("finished")) and not _end_shown:
		await get_tree().create_timer(0.8, true, false, true).timeout
		if not is_instance_valid(g) or bool(g.get("finished")):
			return
		var m: Array = (load("res://qa/match3_bot.gd") as GDScript).call("best_move", g.get("logic"))
		if m.is_empty():
			return
		await g.call("try_swap", m[0], m[1])


func _process(delta: float) -> void:
	t += delta
	var visible_t: float = t - skip
	_hook.visible = not raw and visible_t >= 0.0 and visible_t < 3.0
	if not raw and visible_t >= seconds - 2.5 and not _end_shown:
		_end_shown = true
		_show_end()
	if t >= skip + seconds + 0.2:
		_save_moments()
		get_tree().quit()
		return
	if is_instance_valid(game) and bool(game.get("finished")) and not _end_shown:
		_next_after_win()


func _next_after_win() -> void:
	if _advancing:
		return
	_advancing = true
	await get_tree().create_timer(1.6, true, false, true).timeout
	if Kit.level_index < Kit.level_count() - 1:
		Kit.level_index += 1
	_play_level()
	_advancing = false


## 7 - Momentos: lo que el juego apunta en QA, con el segundo de la grabacion (tiempo de juego).
func _on_qa(e: Dictionary) -> void:
	moments.append({"t": snappedf(t, 0.01), "event": str(e.get("event", ""))})


func _save_moments() -> void:
	if events_path == "":
		return
	var f: FileAccess = FileAccess.open(events_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"seconds": t, "skip": skip, "moments": moments}))
		f.close()


func _build_overlay() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 90
	add_child(_layer)
	var root: Control = Control.new()
	root.theme = UI.theme
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(root)
	_hook = Label.new()
	_hook.text = Kit.text("clip_hook", "\u00bfPuedes superarlo?")
	_hook.theme_type_variation = "TitleLabel"
	_hook.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hook.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hook.add_theme_font_size_override("font_size", 64)
	_hook.add_theme_color_override("font_color", Color.WHITE)
	_hook.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	_hook.add_theme_constant_override("outline_size", 18)
	_hook.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hook.offset_top = 170.0
	_hook.offset_left = 40.0
	_hook.offset_right = -40.0
	root.add_child(_hook)
	_end = Control.new()
	_end.set_anchors_preset(Control.PRESET_FULL_RECT)
	_end.visible = false
	root.add_child(_end)


func _show_end() -> void:
	QaBot.release_all()
	get_tree().paused = false
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(Kit.color("sky", Color("#1b2a41")), 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_end.add_child(bg)
	var col: VBoxContainer = VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 26)
	_end.add_child(col)
	var hero_box: Control = Control.new()
	hero_box.custom_minimum_size = Vector2(0.0, 300.0)
	col.add_child(hero_box)
	var art: Dictionary = Kit.sprite_by_role("jugador")
	if not art.is_empty():
		var spr: AnimatedSprite2D = SpriteKit.animado(art, 260.0, "idle", false)
		spr.position = Vector2(360.0, 150.0)
		hero_box.add_child(spr)
		## Proyectos anteriores a la tienda de aspectos no tienen kit/skins.gd.
		if ResourceLoader.exists("res://kit/skins.gd"):
			(load("res://kit/skins.gd") as GDScript).call("apply", spr)
	var title: Label = Label.new()
	title.text = str(Kit.config.get("title", ""))
	title.theme_type_variation = "TitleLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 76)
	col.add_child(title)
	var cta: Label = Label.new()
	cta.text = Kit.text("clip_cta", "\u00a1Desc\u00e1rgalo gratis!")
	cta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cta.add_theme_font_size_override("font_size", 48)
	cta.add_theme_color_override("font_color", UI.colors["acento"])
	col.add_child(cta)
	_end.visible = true
	_end.modulate.a = 0.0
	var tw: Tween = create_tween()
	tw.tween_property(_end, "modulate:a", 1.0, 0.35)
	UI.pop_in(title, 0.1)
	UI.pop_in(cta, 0.3)
