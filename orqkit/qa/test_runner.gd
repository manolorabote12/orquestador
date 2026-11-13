extends Node
## Bateria de QA del kit. Se ejecuta sin pantalla:
##   godot --headless --path orqkit res://qa/test_runner.tscn --fixed-fps 60 -- --qa
## Termina con codigo 0 si todo pasa y 1 si algo falla (la fabrica usa ese codigo).

const GAME_SCENE: String = "res://scenes/main.tscn"

var passed: int = 0
var failed: int = 0
var base_config: Dictionary = {}


func _ready() -> void:
	base_config = Kit.config.duplicate(true)
	## Los logros dan monedas: en las pruebas solo cuentan donde se prueban (count_in_tests).
	Feats.set_meta("off", true)
	HowTo.enabled = false
	Tutorial.enabled = false
	print("== OrqKit QA ", Kit.VERSION, " ==")
	## 1 - Solo una bateria: -- --solo=shooter ejecuta _test_shooter() (para iterar rapido).
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--solo="):
			var m: String = "_test_" + a.substr(7)
			if has_method(m):
				await call(m)
			print("== Resultado: ", passed, " correctas, ", failed, " fallidas ==")
			get_tree().quit(0 if failed == 0 else 1)
			return
	await _test_analyzer()
	await _test_art()
	await _test_jump_feel()
	await _test_coyote_and_buffer()
	await _test_bots_complete_levels()
	await _test_combat()
	await _test_extras()
	await _test_music()
	await _test_runner()
	await _test_flyer()
	await _test_platformer_3d()
	await _test_horde()
	await _test_horde_template()
	await _test_kart_items()
	await _test_zombie_template()
	await _test_tower()
	await _test_race()
	await _test_shooter()
	await _test_breakout()
	await _test_blocks()
	await _test_lanes()
	await _test_snake()
	await _test_memory()
	await _test_sokoban()
	await _test_quiz()
	await _test_stack()
	await _test_moles()
	await _test_rhythm()
	await _test_idle()
	await _test_cards()
	await _test_turns()
	await _test_turns_party()
	await _test_jumper()
	await _test_brawl()
	await _test_brawl_modes()
	await _test_arena_live()
	await _test_coop()
	await _test_village()
	await _test_replay()
	await _test_meta()
	await _test_mods()
	await _test_online()
	await _test_chat()
	await _test_friends()
	await _test_ghosts()
	await _test_live_event()
	await _test_cloud()
	await _test_season()
	await _test_store()
	await _test_notify()
	await _test_features()
	_test_ab()
	await _test_more_genres()
	await _test_sort()
	await _test_bubble()
	await _test_empire()
	await _test_mine()
	await _test_dungeon()
	await _test_farm()
	await _test_deck()
	await _test_tale()
	await _test_cook()
	await _test_mahjong()
	await _test_parking()
	await _test_words()
	await _test_sudoku()
	await _test_nonogram()
	await _test_slice()
	await _test_penalty()
	await _test_hole()
	await _test_city()
	await _test_helix()
	await _test_hoops()
	await _test_mines()
	await _test_connect()
	await _test_checkers()
	await _test_pool()
	await _test_klondike()
	await _test_ludo()
	await _test_falling()
	await _test_bowling()
	await _test_sandbox()
	await _test_royale()
	await _test_royale_live()
	await _test_royale_3d()
	await _test_voxel()
	await _test_obby()
	await _test_market()
	await _test_soccer()
	await _test_horror()
	await _test_drive()
	await _test_zombie()
	await _test_basket()
	await _test_tennis()
	await _test_kart()
	await _test_kart_live()
	await _test_survival()
	await _test_survival_template()
	await _test_triple()
	await _test_screw()
	await _test_hexa()
	await _test_bus()
	await _test_clash()
	await _test_climb()
	await _test_sling()
	await _test_lawn()
	await _test_wordle()
	await _test_letters()
	await _test_tycoon()
	await _test_slots()
	await _test_realm()
	await _test_crowd()
	await _test_mergeboard()
	await _test_rules_data()
	await _test_marketing_ingame()
	await _test_powertower()
	await _test_spotdiff()
	await _test_jigsaw()
	await _test_paintnum()
	await _test_knifehit()
	await _test_rogue()
	await _test_arrows()
	await _test_merge2048()
	await _test_crazy8()
	await _test_domino()
	await _test_blockjam()
	await _test_pipes()
	await _test_chess()
	await _test_reversi()
	await _test_hidden()
	await _test_slide()
	await _test_hangman()
	await _test_battle()
	await _test_simon()
	await _test_tactics()
	await _test_autochess()
	await _test_gemrpg()
	await _test_ccg()
	await _test_crawl()
	await _test_bomber()
	await _test_artillery()
	await _test_chomp()
	await _test_chain()
	await _test_fighter()
	await _test_fruitmerge()
	await _test_pinball()
	await _test_metroid()
	await _test_stealth()
	await _test_versus()
	await _test_marathon()
	await _test_time_attack()
	await _test_hints()
	await _test_ccg_deck()
	await _test_fighter_combo()
	await _test_metroid_map()
	await _test_crawl_explore()
	await _test_tactics_preview()
	await _test_autochess_synergy()
	await _test_tale_extras()
	await _test_tower_aim()
	await _test_dungeon_gear()
	await _test_realm_forecast()
	await _test_howto()
	await _test_tutorial()
	await _test_monetize()
	await _test_prize()
	await _test_gift()
	await _test_rate()
	await _test_stats_expert()
	await _test_classroom()
	await _test_puzzle_revive()
	await _test_endless()
	await _test_board_hints()
	await _test_live_rules()
	await _test_slots_dice()
	await _test_zombie_live()
	await _test_audio_feel()
	await _test_hopper()
	await _test_archery()
	await _test_lobby_feel()
	await _test_ui_icons()
	await _test_chests()
	await _test_album()
	await _test_twists()
	await _test_torneo()
	await _test_i18n()
	await _test_story()
	await _test_look_skin()
	_test_genres()
	_test_telemetry()
	await _test_match3()
	await _test_monkey()
	_test_save()
	_test_ads()
	await _test_ui_themes()
	await _test_ui_screens()
	await _test_ui_touch()
	await _test_ui_game_flow()
	print("== Resultado: ", passed, " correctas, ", failed, " fallidas ==")
	print("[QA] informe ", JSON.stringify(QA.report()))
	get_tree().quit(0 if failed == 0 else 1)


func check(test_name: String, ok: bool, detail: String = "") -> void:
	if ok:
		passed += 1
		print("  OK   ", test_name, ("  (" + detail + ")") if detail != "" else "")
	else:
		failed += 1
		print("  FAIL ", test_name, ("  (" + detail + ")") if detail != "" else "")


func frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func start_game(config: Dictionary, level: int) -> Node:
	Kit.set_config(config)
	Kit.level_index = level
	var game: Node = (load(UI.game_scene()) as PackedScene).instantiate()
	add_child(game)
	await frames(2)
	return game


func stop_game(game: Node) -> void:
	_release_all()
	game.queue_free()
	Engine.time_scale = 1.0
	await frames(2)


func _release_all() -> void:
	for action: String in ["move_left", "move_right", "jump"]:
		Input.action_release(action)


func test_config(map: Array) -> Dictionary:
	var cfg: Dictionary = base_config.duplicate(true)
	cfg["levels"] = [{"name": "test", "map": map}]
	return cfg


## 1 - Analizador: niveles reales completables y uno imposible detectado.
func _test_analyzer() -> void:
	print("- Analizador de niveles")
	var tile: float = float(base_config.get("tile_size", 64))
	var params: Dictionary = base_config.get("player", {})
	var levels: Array = base_config.get("levels", [])
	for i: int in levels.size():
		var lv: Dictionary = levels[i]
		var r: Dictionary = LevelAnalyzer.analyze(lv.get("map", []), tile, params)
		check("nivel %d completable" % (i + 1), bool(r.get("completable", false)), str(r.get("issues", [])))
		var missing: Array = r.get("coins_unreachable", [])
		check("nivel %d monedas alcanzables" % (i + 1), missing.is_empty(), "%d/%d sin alcanzar" % [missing.size(), int(r.get("coins_total", 0))])
	var imp_text: String = FileAccess.get_file_as_string("res://qa/impossible.txt")
	var imp: Array = JSON.parse_string(imp_text)
	var r2: Dictionary = LevelAnalyzer.analyze(imp, tile, params)
	check("detecta nivel imposible", not bool(r2.get("completable", true)), str(r2.get("issues", [])))
	await frames(1)


## 2 - Altura de salto real frente a la configurada, y salto corto al soltar.
func _test_jump_feel() -> void:
	print("- Feeling del salto")
	var flat: Array = [
		"..............................",
		"..............................",
		"..............................",
		"..............................",
		"..............................",
		"..P........................G..",
		"##############################",
	]
	var game: Node = await start_game(test_config(flat), 0)
	var player: PlayerPlatformer = game.get("player")
	await frames(40)
	check("aterriza al empezar", player.is_on_floor())
	var full: float = await _measure_jump(player, 999)
	var expected: float = float(player.p["jump_height"])
	check("altura de salto completo", absf(full - expected) / expected < 0.15, "%.0f px, esperado %.0f" % [full, expected])
	await frames(20)
	var short: float = await _measure_jump(player, 3)
	check("salto corto al soltar (salto variable)", short < full * 0.7, "%.0f px frente a %.0f" % [short, full])
	await stop_game(game)


func _measure_jump(player: PlayerPlatformer, hold_frames: int) -> float:
	var y0: float = player.global_position.y
	var top: float = y0
	Input.action_press("jump")
	var f: int = 0
	while f < 240:
		await frames(1)
		f += 1
		if f == hold_frames:
			Input.action_release("jump")
		top = minf(top, player.global_position.y)
		if f > 5 and player.is_on_floor():
			break
	Input.action_release("jump")
	await frames(2)
	return y0 - top


## 3 - Coyote time y buffer de salto con la fisica real.
func _test_coyote_and_buffer() -> void:
	print("- Coyote time y buffer de salto")
	var ledge: Array = [
		"..............................",
		"..............................",
		"..............................",
		"..............................",
		"..P...........................",
		"########......................",
		"########......................",
		"########...................G..",
		"##############################",
	]
	var cfg: Dictionary = test_config(ledge)
	var tile: float = float(cfg.get("tile_size", 64))
	var edge_x: float = 8.0 * tile

	for case: Array in [[3, true, "coyote: salta 3 frames despues del borde"], [12, false, "sin coyote: 12 frames despues ya no salta"]]:
		var game: Node = await start_game(cfg, 0)
		var player: PlayerPlatformer = game.get("player")
		await frames(30)
		Input.action_press("move_right")
		var guard: int = 0
		while player.is_on_floor() and guard < 300:
			await frames(1)
			guard += 1
		await frames(int(case[0]) - 1)
		Input.action_press("jump")
		await frames(2)
		var went_up: bool = player.velocity.y < 0.0
		check(str(case[2]), went_up == bool(case[1]), "vel.y=%.0f, x=%.0f borde=%.0f" % [player.velocity.y, player.global_position.x, edge_x])
		await stop_game(game)

	var drop: Array = [
		"............",
		"..P.........",
		"............",
		"............",
		"............",
		"..........G.",
		"############",
	]
	var g2: Node = await start_game(test_config(drop), 0)
	var p2: PlayerPlatformer = g2.get("player")
	var floor_y: float = 6.0 * tile
	var guard2: int = 0
	while floor_y - p2.global_position.y > 40.0 and guard2 < 300:
		await frames(1)
		guard2 += 1
	Input.action_press("jump")
	await frames(1)
	Input.action_release("jump")
	var jumped: bool = false
	for i: int in 20:
		await frames(1)
		if p2.velocity.y < -100.0:
			jumped = true
			break
	check("buffer: salto pulsado antes de aterrizar sale al tocar suelo", jumped)
	await stop_game(g2)


## 4 - Bot "corredor": mantiene derecha y salta ante muros, huecos y pinchos.
## Si completa los niveles con la fisica real, el nivel es jugable de verdad.
func _test_bots_complete_levels() -> void:
	print("- Bots completan los niveles")
	var levels: Array = base_config.get("levels", [])
	for i: int in levels.size():
		QA.clear()
		var game: Node = await start_game(base_config.duplicate(true), i)
		var rows: Array[String] = LevelBuilder.normalize((levels[i] as Dictionary).get("map", []))
		var done: bool = await _run_bot(game, rows, 60 * 90)
		var st: Dictionary = game.call("bot_state")
		var causes: Array[String] = []
		for e: Dictionary in QA.events:
			if e.get("event", "") == "death":
				causes.append("%s@x%d" % [str(e.get("cause", "")), int(e.get("x", 0))])
		check("bot completa nivel %d" % (i + 1), done, "muertes=%d monedas=%d %s" % [int(st["deaths"]), int(st["coins"]), str(causes)])
		check("nivel %d sin fallos de QA" % (i + 1), QA.failures.is_empty(), str(QA.failures))
		check("nivel %d sin sonidos que falten" % (i + 1), QA.count("sfx_missing") == 0, "%d avisos" % QA.count("sfx_missing"))
		await stop_game(game)


func _run_bot(game: Node, _rows: Array[String], max_frames: int) -> bool:
	return await QaBot.run(get_tree(), game, max_frames)


## 5 - Bot aleatorio: 40 segundos de pulsaciones locas. No debe romper nada.
func _test_monkey() -> void:
	print("- Bot aleatorio (estabilidad)")
	QA.clear()
	var game: Node = await start_game(base_config.duplicate(true), 0)
	var player: PlayerPlatformer = game.get("player")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1234
	var bad_pos: bool = false
	for f: int in 60 * 40:
		if f % 12 == 0:
			_release_all()
			var r: float = rng.randf()
			if r < 0.45:
				Input.action_press("move_right")
			elif r < 0.7:
				Input.action_press("move_left")
			if rng.randf() < 0.4:
				Input.action_press("jump")
		await frames(1)
		var pos: Vector2 = player.global_position
		if is_nan(pos.x) or is_nan(pos.y) or pos.x < -200.0:
			bad_pos = true
	check("posicion siempre valida", not bad_pos)
	check("sin fallos de QA", QA.failures.is_empty(), str(QA.failures))
	var rep: Dictionary = QA.report()
	check("informe de rendimiento disponible", int(rep.get("frames", 0)) > 0, "peor frame %.1f ms" % float(rep.get("worst_frame_ms", 0.0)))
	await stop_game(game)


## 6 - Guardado: ida y vuelta, records y recuperacion de archivo corrupto.
func _test_save() -> void:
	print("- Guardado")
	Save.reset_all()
	check("record nuevo", Save.submit_best("0", 500))
	check("peor marca no es record", not Save.submit_best("0", 300))
	Save.set_setting("haptics", false)
	Save.load_data()
	check("ajustes persisten", bool(Save.get_setting("haptics", true)) == false)
	check("records persisten", int((Save.progress().get("best", {}) as Dictionary).get("0", 0)) == 500)
	var f: FileAccess = FileAccess.open(Save.PATH, FileAccess.WRITE)
	f.store_string("{esto no es json")
	f.close()
	Save.load_data()
	check("archivo corrupto se recupera", Save.data.has("progress") and Save.data.has("settings"))
	Save.reset_all()


## 8 - Arte y sonido de la fabrica (assets/manifest.json).
func _test_art() -> void:
	print("- Arte y sonido de la fabrica")
	if Kit.assets.is_empty():
		check("manifest de arte presente", false, "sin assets/manifest.json")
		return
	check("sprite del jugador en el manifest", not Kit.sprite_by_role("jugador").is_empty())
	var flat: Array = [
		"..............................",
		"..............................",
		"..............................",
		"..............................",
		"..P........................G..",
		"##############################",
	]
	var game: Node = await start_game(test_config(flat), 0)
	var player: PlayerPlatformer = game.get("player")
	check("jugador usa sprite animado", player.anim_sprite != null)
	if player.anim_sprite != null:
		var sf: SpriteFrames = player.anim_sprite.sprite_frames
		var missing: Array[String] = []
		for a: String in ["idle", "run", "jump", "fall"]:
			if not sf.has_animation(a) or sf.get_frame_count(a) == 0:
				missing.append(a)
		check("animaciones idle/run/jump/fall con frames", missing.is_empty(), str(missing))
		await frames(30)
		check("animacion idle en reposo", player.anim_sprite.animation == "idle", str(player.anim_sprite.animation))
		Input.action_press("move_right")
		await frames(20)
		check("animacion run al correr", player.anim_sprite.animation == "run", str(player.anim_sprite.animation))
		Input.action_press("jump")
		await frames(6)
		check("animacion jump al saltar", player.anim_sprite.animation == "jump", str(player.anim_sprite.animation))
		_release_all()
	check("textura de tile cargada", Kit.first_tile_texture() != null)
	var missing_sfx: Array[String] = []
	for s: String in ["jump", "coin", "hurt", "land", "win"]:
		if not Audio._streams.has(s):
			missing_sfx.append(s)
	check("efectos de sonido registrados", missing_sfx.is_empty(), str(missing_sfx))
	await stop_game(game)


## 7 - Reglas de anuncios.
func _test_ads() -> void:
	print("- Reglas de anuncios")
	## Sesion nueva: la bateria entera tarda mas que la gracia del principio.
	Ads.set("_session_start_ms", Time.get_ticks_msec())
	Ads.set("_last_interstitial_ms", -1000000)
	Ads.set("_interstitials_shown", 0)
	Ads.set("_showing", false)
	var was_enabled: bool = Ads.enabled
	Ads.enabled = true
	check("sin intersticial al empezar la sesion", not Ads.can_show_interstitial("level_end"))
	Ads.debug_shift_session(120.0)
	check("intersticial en pausa natural", Ads.can_show_interstitial("level_end"))
	check("nunca en mitad de la accion", not Ads.can_show_interstitial("gameplay"))
	Ads.enabled = was_enabled


## 9 - Interfaz: los cuatro perfiles construyen tema, fuente y colores legibles.
func _test_ui_themes() -> void:
	print("- Interfaz: perfiles de estilo")
	UI.test_mode = true
	for prof: String in UiTheme.PROFILES.keys():
		UI.rebuild(prof)
		var fv: FontVariation = UI.font as FontVariation
		check("perfil %s: tema y fuente" % prof, UI.theme != null and fv != null and fv.base_font != null)
		var c: Dictionary = UI.colors
		var worst: float = minf(minf(UiTheme.contrast(c["texto"], c["fondo"]), UiTheme.contrast(c["texto"], c["panel"])),
			minf(UiTheme.contrast(c["texto"], c["panel_hi"]), UiTheme.contrast(c["acento_texto"], c["acento"])))
		check("perfil %s: contraste legible" % prof, worst >= 4.5, "peor %.2f" % worst)
	## 1 - Paleta trampa: todo claro. El tema debe corregirla solo.
	var bad: Dictionary = UiTheme.ensure_contrast(UiTheme.role_colors({
		"fondo": "#f0f0f0", "panel": "#ffffff", "panel_hi": "#eeeeee", "texto": "#ffffff",
		"acento": "#ffff66", "acento_texto": "#ffffff",
	}, UI.colors))
	var fixed: float = minf(UiTheme.contrast(bad["texto"], bad["panel_hi"]), UiTheme.contrast(bad["acento_texto"], bad["acento"]))
	check("paleta ilegible se corrige", fixed >= 4.5, "%.2f" % fixed)
	## 2 - La auditoria tiene que detectar fallos de verdad (boton diminuto y texto cortado).
	var trap: Control = Control.new()
	trap.theme = UI.theme
	trap.size = Vector2(720, 1280)
	add_child(trap)
	var tiny: Button = Button.new()
	tiny.name = "Tiny"
	tiny.text = "x"
	tiny.position = Vector2(100, 100)
	tiny.size = Vector2(40, 40)
	trap.add_child(tiny)
	var cut: Label = Label.new()
	cut.name = "Cut"
	cut.text = "Un texto larguisimo que no cabe de ninguna manera"
	cut.clip_text = true
	cut.position = Vector2(100, 300)
	cut.size = Vector2(120, 50)
	trap.add_child(cut)
	await frames(2)
	var found: Array[String] = UI.audit(trap)
	check("auditoria detecta boton pequeno y texto cortado", found.size() >= 2, str(found))
	trap.queue_free()
	UI.rebuild("")
	await frames(1)


## 10 - Cada pantalla, en cada perfil y en varios tamanos de movil y tableta, pasa la auditoria.
func _test_ui_screens() -> void:
	print("- Interfaz: auditoria de pantallas")
	var sizes: Array[Vector2i] = [Vector2i(720, 1280), Vector2i(720, 1600), Vector2i(960, 1280)]
	Save.reset_all()
	Save.unlock_level(0)
	Save.submit_stars("0", 2)
	for prof: String in UiTheme.PROFILES.keys():
		UI.rebuild(prof)
		var problems: Array[String] = []
		for sz: Vector2i in sizes:
			for screen: String in ["title", "levels", "settings", "pause", "result"]:
				var found: Array[String] = await _audit_screen(screen, sz)
				for f: String in found:
					problems.append("%s %dx%d: %s" % [screen, sz.x, sz.y, f])
		check("perfil %s: 5 pantallas x 3 tamanos sin problemas" % prof, problems.is_empty(), str(problems.slice(0, 4)))
	UI.rebuild("")


func _audit_screen(screen: String, sz: Vector2i) -> Array[String]:
	var vp: SubViewport = SubViewport.new()
	vp.size = sz
	vp.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(vp)
	var host: Control = Control.new()
	host.size = Vector2(sz)
	vp.add_child(host)
	match screen:
		"title":
			host.add_child((load(UI.SCREEN_TITLE) as PackedScene).instantiate())
		"levels":
			host.add_child((load(UI.SCREEN_LEVELS) as PackedScene).instantiate())
		"settings":
			SettingsPanel.open(host)
		"pause":
			var pm: PauseMenu = PauseMenu.new()
			pm.name = "PauseMenu"
			host.add_child(pm)
		"result":
			ResultPanel.open(host, {"stars": 3, "coins": 4, "coins_total": 5, "score": 2950, "record": true})
	await _wait_seconds(2.0)
	var out: Array[String] = UI.audit(host)
	vp.queue_free()
	await frames(1)
	return out


func _wait_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


## 15 - Genero runner: corre solo, cada vez mas rapido, se salta tocando la pantalla,
## barra de recorrido, y el bot lo completa. El analizador vigila muros y piezas que no encajan.
func _test_runner() -> void:
	print("- Runner")
	var tile: float = float(base_config.get("tile_size", 64))
	var map: Array = [
		"............................................................",
		"............................................................",
		"..........................CC................................",
		".............C...CCC........................................",
		"............................................................",
		"..P....................########....^............E.......G...",
		"############...###########################..################",
		"############...###########################..################",
		"############...###########################..################",
	]
	var cfg: Dictionary = test_config(map)
	(cfg["player"] as Dictionary)["auto_run"] = 1.0
	var game: Node = await start_game(cfg, 0)
	var player: PlayerPlatformer = game.get("player")
	var x0: float = player.global_position.x
	await frames(40)
	check("runner: corre solo sin tocar nada", player.global_position.x - x0 > tile * 3.0, "%.0f px" % (player.global_position.x - x0))
	var tap: Node = null
	var left: Node = null
	for c: Node in game.get_children():
		if c is CanvasLayer:
			tap = c.get_node_or_null("tap") if tap == null else tap
			left = c.get_node_or_null("left") if left == null else left
	check("runner: se salta tocando la pantalla y no hay flechas", tap != null and left == null)
	check("runner: barra de recorrido en el HUD", game.find_child("RunBar", true, false) != null)
	await stop_game(game)

	game = await start_game(cfg, 0)
	player = game.get("player")
	var done: bool = await QaBot.run(get_tree(), game, 60 * 40)
	var st: Dictionary = game.call("bot_state")
	check("runner: el bot llega a la meta", done, "muertes=%d progreso=%.2f" % [int(st["deaths"]), float(st["progress"])])
	check("runner: va mas rapido al final", player.speed_mult > 1.15, "x%.2f" % player.speed_mult)
	await stop_game(game)

	var params: Dictionary = (cfg["player"] as Dictionary)
	var ok: Dictionary = LevelAnalyzer.analyze(map, tile, params)
	check("runner: analizador da el nivel por bueno", bool(ok["completable"]) and (ok["issues"] as Array).is_empty(), str(ok["issues"]))
	var wall: Dictionary = LevelAnalyzer.analyze(["........", "....#...", "....#...", ".P..#..G", "########"], tile, params)
	check("runner: muro de 3 bloques detectado", (wall["issues"] as Array).has("runner_wall"), str(wall["issues"]))
	var mov: Dictionary = LevelAnalyzer.analyze(["..........", ".P.......G", "###==#####"], tile, params)
	check("runner: plataforma movil no vale", (mov["issues"] as Array).has("runner_moving_platform"), str(mov["issues"]))
	var plat: Dictionary = LevelAnalyzer.analyze(["........", "....#...", "....#...", ".P..#..G", "########"], tile, base_config.get("player", {}))
	check("plataformas: ese muro no es problema de runner", not (plat["issues"] as Array).has("runner_wall"))


## 16b - Vista 3D (2.5D) de plataformas, runner y volador: la logica es la misma (el bot gana
## igual), el 2D se esconde con la mascara del viewport y cada sprite/poligono tiene su gemelo 3D.
func _test_platformer_3d() -> void:
	print("- Plataformas 3D")
	var map: Array = [
		"..............................",
		"..............C...............",
		".........C...####.............",
		"..P.....####.........E.....G..",
		"#########...==....^.##########",
		"##############################",
	]
	var cfg: Dictionary = test_config(map)
	cfg["view"] = "3d"
	var game: Node = await start_game(cfg, 0)
	var v3: Node = game.get("view3d")
	check("plataformas 3D: vista 3D con camara y bloques", v3 != null and v3.get_node_or_null("Camera3D") != null
		and v3.get_node_or_null("Blocks/Cubes") != null and v3.get_node_or_null("Spikes/Cones") != null)
	if v3 == null:
		await stop_game(game)
		return
	var solids: int = 0
	for r: String in map:
		solids += r.count("#")
	var cubes: MultiMesh = (v3.get_node("Blocks/Cubes") as MultiMeshInstance3D).multimesh
	check("plataformas 3D: un cubo por bloque (y cimientos)", cubes.instance_count == solids + map[map.size() - 1].count("#"), str(cubes.instance_count))
	var hide: int = 1 << 19
	check("plataformas 3D: el 2D del mundo se esconde y el HUD no", (get_viewport().canvas_cull_mask & hide) == 0
		and ((game.get("level") as CanvasItem).visibility_layer & hide) != 0 and ((game.get("player") as CanvasItem).visibility_layer & hide) != 0)
	await frames(3)
	var counts: Dictionary = v3.call("twin_counts")
	check("plataformas 3D: gemelos de jugador, enemigos, monedas y plataforma movil", int(counts.get("poly", 0)) + int(counts.get("anim", 0)) >= 6
		and int(counts.get("platform", 0)) == 1, str(counts))
	var done: bool = await QaBot.run(get_tree(), game, 60 * 40)
	var st: Dictionary = game.call("bot_state")
	check("plataformas 3D: el bot llega a la meta igual que en 2D", done, "muertes=%d" % int(st["deaths"]))
	var cam3: Camera3D = v3.get_node("Camera3D")
	var cam2: Camera2D = game.get("camera")
	var c2: float = cam2.get_screen_center_position().x / float(game.get("tile"))
	check("plataformas 3D: la camara 3D sigue a la del juego", c2 > 8.0 and absf(cam3.position.x + 0.6 - c2) < 1.0, "cam3=%.1f cam2=%.1f" % [cam3.position.x, c2])
	await stop_game(game)
	check("plataformas 3D: al salir el viewport vuelve a pintar el 2D", (get_viewport().canvas_cull_mask & hide) != 0)

	## Runner y volador en 3D: el bot los completa igual.
	var run_cfg: Dictionary = test_config(["......................................", "..P..........C.........^.........G....", "######################################"])
	(run_cfg["player"] as Dictionary)["auto_run"] = 1.0
	run_cfg["view"] = "3d"
	game = await start_game(run_cfg, 0)
	done = await QaBot.run(get_tree(), game, 60 * 30)
	check("runner 3D: el bot llega a la meta", done and game.get("view3d") != null)
	await stop_game(game)
	## Sin "view" sigue siendo 2D de siempre.
	game = await start_game(test_config(map), 0)
	check("plataformas: sin view es 2D", game.get("view3d") == null and (get_viewport().canvas_cull_mask & hide) != 0)
	await stop_game(game)


## 16 - Genero volador (arcade de un toque): espera al primer toque, cae si no tocas,
## chocar con una tuberia es perder, el bot pasa por los huecos y el analizador vigila los huecos.
func _test_flyer() -> void:
	print("- Volador")
	var tile: float = float(base_config.get("tile_size", 64))
	var map: Array = [
		"#.........##......##......##......##.........#",
		"#.........##......##......##......##.........#",
		"#.........##......##......##......##.........#",
		"#.........##......##......##......##.........#",
		"#.........##..............##......##.........#",
		"#.........##..............##.................#",
		"#.................C.......##.................#",
		"#..P..............................C.......G..#",
		"#.........C..................................#",
		"#.................##......C..................#",
		"#.................##..............##.........#",
		"#.........##......##..............##.........#",
		"#.........##......##......##......##.........#",
		"#.........##......##......##......##.........#",
		"##############################################",
		"##############################################",
	]
	var cfg: Dictionary = test_config(map)
	(cfg["player"] as Dictionary)["flap"] = 1.0
	(cfg["player"] as Dictionary)["run_speed"] = 300.0
	var game: Node = await start_game(cfg, 0)
	var player: PlayerPlatformer = game.get("player")
	var p0: Vector2 = player.global_position
	await frames(30)
	check("volador: espera quieto al primer toque", player.global_position.distance_to(p0) < 2.0 and not player.flap_ready)
	Input.action_press("jump")
	await frames(1)
	Input.action_release("jump")
	await frames(150)
	check("volador: sin tocar mas, cae o choca", int(game.get("deaths")) >= 1, "muertes=%d" % int(game.get("deaths")))
	var tap: Node = null
	var jump_btn: Node = null
	for c: Node in game.get_children():
		if c is CanvasLayer and c.get_node_or_null("tap") != null:
			tap = c.get_node("tap")
			jump_btn = c.get_node_or_null("jump")
	check("volador: toda la pantalla es el boton", tap != null and jump_btn == null)
	await stop_game(game)

	game = await start_game(cfg, 0)
	var done: bool = await QaBot.run(get_tree(), game, 60 * 40)
	var st: Dictionary = game.call("bot_state")
	check("volador: el bot cruza todas las tuberias", done, "muertes=%d progreso=%.2f" % [int(st["deaths"]), float(st["progress"])])
	check("volador: coge monedas de los huecos", int(st["coins"]) >= 3, "%d" % int(st["coins"]))
	await stop_game(game)

	var params: Dictionary = cfg["player"]
	var ok: Dictionary = LevelAnalyzer.analyze(map, tile, params)
	check("volador: analizador da el nivel por bueno", bool(ok["completable"]), str(ok["issues"]))
	var narrow: Array = map.duplicate()
	for y: int in [6, 8]:
		narrow[y] = (narrow[y] as String).substr(0, 18) + "##" + (narrow[y] as String).substr(20)
	var r1: Dictionary = LevelAnalyzer.analyze(narrow, tile, params)
	check("volador: hueco estrecho detectado", (r1["issues"] as Array).has("flap_gap_small"), str(r1["issues"]))
	var jump: Array = [
		"#.........##..##.............................#",
		"#.............##.............................#",
		"#.............##.............................#",
		"#..P..........##.............................#",
		"#.............##.............................#",
		"#.............##.............................#",
		"#.........##..##.............................#",
		"#.........##..##..........................G..#",
		"#.........##..##.............................#",
		"#.........##.................................#",
		"#.........##.................................#",
		"#.........##.................................#",
		"#.........##.................................#",
		"#.........##.................................#",
		"##############################################",
		"##############################################",
	]
	var r2: Dictionary = LevelAnalyzer.analyze(jump, tile, params)
	check("volador: cambio de altura imposible detectado", (r2["issues"] as Array).has("flap_gap_jump"), str(r2["issues"]))


## 17 - Genero hordas (vista desde arriba): se mueve con las flechas, salen enemigos, las armas
## disparan solas, al subir de nivel se pausa y se elige mejora, el bot sobrevive y vence al jefe.
func horde_config(secs: float, boss: bool) -> Dictionary:
	var map: Array = [
		"########################",
		"#......................#",
		"#......................#",
		"#......................#",
		"#......................#",
		"#......................#",
		"#....##................#",
		"#......................#",
		"#................#.....#",
		"#................#.....#",
		"#......................#",
		"#......................#",
		"#......................#",
		"#......................#",
		"#......................#",
		"#...........P..........#",
		"#......................#",
		"#......................#",
		"#......................#",
		"#......................#",
		"#..............#.......#",
		"#......................#",
		"#.......##.............#",
		"#......................#",
		"#......................#",
		"#......................#",
		"#......................#",
		"#......................#",
		"#......................#",
		"########################"
	]
	var cfg: Dictionary = base_config.duplicate(true)
	cfg["genre"] = "horde"
	cfg["levels"] = [{"name": "arena", "map": map, "seconds": secs, "density": 0.5, "enemies": ["walker", "flyer", "spiky"], "boss": boss}]
	return cfg


func _test_horde() -> void:
	print("- Hordas")
	var game: Node = await start_game(horde_config(40.0, true), 0)
	check("hordas: escena propia", game.has_method("horde_bot_step"))
	var player: Node2D = game.get("player")
	var x0: float = player.position.x
	Input.action_press("move_right")
	await frames(30)
	Input.action_release("move_right")
	check("hordas: se mueve con las flechas", player.position.x - x0 > 60.0, "%.0f px" % (player.position.x - x0))
	await frames(420)
	check("hordas: llegan enemigos", (game.get("enemies") as Array).size() > 0)
	check("hordas: el arma dispara sola y mata", int(game.get("kills")) > 0 or (game.get("_bullets") as Array).size() > 0)
	game.call("_gain_xp", 6)
	await frames(2)
	var panel: Node = game.get_node_or_null("LevelUpPanel")
	check("hordas: al subir de nivel se pausa y ofrece 3 mejoras", get_tree().paused and panel != null and (game.get("pending") as Array).size() == 3)
	if panel != null:
		var problems: Array[String] = UI.audit(panel.get("root"))
		check("hordas: panel de mejoras sin problemas de interfaz", problems.is_empty(), str(problems.slice(0, 2)))
		var antes: int = (game.get("owned") as Dictionary).size() + int((game.get("owned") as Dictionary).values().reduce(func(a: int, b: int) -> int: return a + b, 0))
		(panel.get_node("Root").find_child("Option0", true, false) as Button).pressed.emit()
		await frames(2)
		var despues: int = (game.get("owned") as Dictionary).size() + int((game.get("owned") as Dictionary).values().reduce(func(a: int, b: int) -> int: return a + b, 0))
		check("hordas: elegir mejora la aplica y sigue el juego", not get_tree().paused and despues > antes)
	get_tree().paused = false
	await stop_game(game)

	game = await start_game(horde_config(40.0, true), 0)
	var done: bool = await QaBot.run(get_tree(), game, 60 * 60)
	var st: Dictionary = game.call("bot_state")
	check("hordas: el bot sobrevive y vence al jefe", done and not bool(st["boss_alive"]), "muertes=%d nivel=%d bajas=%d jefe=%.0f en %s jugador %s t=%.0f" % [int(st["deaths"]), int(st["level"]), int(st["kills"]), float(st["boss_hp"]), str(st["boss_pos"]), str(st["pos"]), float(st["time_left"])])
	check("hordas: sube de nivel varias veces", int(st["level"]) >= 4, str(st["upgrades"]))
	await stop_game(game)

	var ok: Dictionary = HordeArena.analyze(horde_config(10.0, false)["levels"][0]["map"])
	check("hordas: arena buena", bool(ok["completable"]), str(ok["issues"]))
	var pocket: Array = (horde_config(10.0, false)["levels"][0]["map"] as Array).duplicate()
	pocket[3] = "#..###.................#"
	pocket[4] = "#..#.#.................#"
	pocket[5] = "#..###.................#"
	var r1: Dictionary = HordeArena.analyze(pocket)
	check("hordas: hueco encerrado detectado", (r1["issues"] as Array).has("horde_pockets"), str(r1["issues"]))
	var open: Array = (horde_config(10.0, false)["levels"][0]["map"] as Array).duplicate()
	open[10] = "........................"
	var r2: Dictionary = HordeArena.analyze(open)
	check("hordas: borde abierto detectado", (r2["issues"] as Array).has("horde_open_border"), str(r2["issues"]))


## 18 - Puzle de combinar 3: logica (lineas, especiales, hielo, caida, barajar), jugadas validas
## e invalidas en la escena, ventana de sin movimientos, bot y analizador de tableros.
func _m3_board(rows: Array) -> Match3Logic:
	var lg: Match3Logic = Match3Logic.new()
	var shape: Array = []
	for r: Variant in rows:
		shape.append(".".repeat(str(r).length()))
	lg.setup(shape, 6, 1)
	for y: int in rows.size():
		for x: int in str(rows[y]).length():
			var ch: String = str(rows[y])[x]
			lg.color[y * lg.w + x] = int(ch) if ch.is_valid_int() else lg.color[y * lg.w + x]
			lg.special[y * lg.w + x] = 0
	return lg


func _test_match3() -> void:
	print("- Puzle")
	var lg: Match3Logic = Match3Logic.new()
	lg.setup([".......", ".......", ".......", ".......", ".......", ".......", ".......", "......."], 5, 7)
	check("puzle: tablero sin lineas al empezar y con jugadas", lg._runs().is_empty() and lg.has_move())
	## Lineas de 4 (horizontal: rayo de fila), 5 (bomba) y L (onda).
	var four: Match3Logic = _m3_board(["0012345", "1203451", "2340512", "3451023", "4510234"])
	check("puzle: cambio que no forma linea no vale", not four.swap_ok(Vector2i(4, 4), Vector2i(5, 4)))
	four.color[0 * four.w + 3] = 0
	four.color[1 * four.w + 2] = 0
	var ph: Array[Dictionary] = four.apply_swap(Vector2i(2, 0), Vector2i(2, 1))
	var made: Array = ph[0]["created"] if not ph.is_empty() else []
	check("puzle: linea de 4 crea un rayo", made.size() == 1 and int(made[0]["kind"]) == Match3Logic.ROW, str(made))
	var five: Match3Logic = _m3_board(["0010015", "1203451", "2340512", "3451023", "4510234"])
	five.color[1 * five.w + 2] = 0
	ph = five.apply_swap(Vector2i(2, 0), Vector2i(2, 1))
	check("puzle: linea de 5 crea una bomba", not ph.is_empty() and (ph[0]["created"] as Array).size() == 1 and int(ph[0]["created"][0]["kind"]) == Match3Logic.BOMB)
	var ell: Match3Logic = _m3_board(["1203451", "2405123", "3050034", "4512345", "5123451"])
	ph = ell.apply_swap(Vector2i(1, 2), Vector2i(2, 2))
	var kinds: Array = []
	for c: Variant in (ph[0]["created"] if not ph.is_empty() else []):
		kinds.append(int(c["kind"]))
	check("puzle: forma de L crea una onda", kinds.has(Match3Logic.WRAP), str(kinds))
	## Rayo disparado limpia la fila entera; despues no queda ningun hueco vacio.
	var ray: Match3Logic = _m3_board(["1234512", "2345123", "0034501", "3451234", "4512345"])
	ray.special[2 * ray.w + 0] = Match3Logic.ROW
	ray.color[3 * ray.w + 2] = 0
	var before: int = ray.score
	ph = ray.apply_swap(Vector2i(2, 2), Vector2i(2, 3))
	check("puzle: el rayo limpia toda la fila", not ph.is_empty() and (ph[0]["cleared"] as Array).size() >= ray.w, str((ph[0]["cleared"] as Array).size() if not ph.is_empty() else 0))
	check("puzle: tras caer y rellenar no queda nada vacio", not ray.color.has(Match3Logic.EMPTY) and ray.score > before)
	var bomb: Match3Logic = _m3_board(["1234512", "2345123", "3451234", "4512345", "5123451"])
	bomb.special[0] = Match3Logic.BOMB
	var ones: int = 0
	for i: int in bomb.color.size():
		if bomb.color[i] == 2:
			ones += 1
	ph = bomb.apply_swap(Vector2i(0, 0), Vector2i(1, 0))
	check("puzle: la bomba borra todas las de un color", not ph.is_empty() and (ph[0]["cleared"] as Array).size() >= ones, "%d de %d" % [(ph[0]["cleared"] as Array).size() if not ph.is_empty() else 0, ones])
	var icy: Match3Logic = Match3Logic.new()
	icy.setup(["IIIIIII", ".......", ".......", ".......", ".......", "......."], 5, 3)
	var t0: int = icy.ice_left
	for k: int in 12:
		var mv: Array = Match3Bot.best_move(icy)
		icy.apply_swap(mv[0], mv[1])
	check("puzle: el hielo se rompe al combinar encima", icy.ice_left < t0, "%d -> %d" % [t0, icy.ice_left])
	var counts0: Dictionary = {}
	for v: int in lg.color:
		counts0[v] = int(counts0.get(v, 0)) + 1
	lg.shuffle()
	var counts1: Dictionary = {}
	for v: int in lg.color:
		counts1[v] = int(counts1.get(v, 0)) + 1
	check("puzle: barajar conserva las piezas y deja jugada", counts0 == counts1 and lg.has_move() and lg._runs().is_empty())

	var cfg: Dictionary = base_config.duplicate(true)
	cfg["genre"] = "match3"
	cfg["levels"] = [{"name": "t", "map": ["##...##", "#.....#", ".......", "..III..", ".......", ".......", ".......", "......."], "moves": 18, "colors": 5, "goal_factor": 0.75}]
	var game: Node = await start_game(cfg, 0)
	check("puzle: escena propia", game.has_method("match3_bot_step"))
	var glogic: Match3Logic = game.get("logic")
	var moves0: int = int(game.get("moves_left"))
	var bad: bool = await game.call("try_swap", Vector2i(2, 2), Vector2i(2, 2))
	check("puzle: jugada invalida no gasta movimiento", not bad and int(game.get("moves_left")) == moves0)
	var good: Array = glogic.all_moves()[0]
	await game.call("try_swap", good[0], good[1])
	check("puzle: jugada valida gasta un movimiento y suma puntos", int(game.get("moves_left")) == moves0 - 1 and glogic.score > 0)
	var panel: OutOfMovesPanel = OutOfMovesPanel.open(game, 1200, 3)
	await frames(2)
	var probs: Array[String] = UI.audit(panel.root)
	check("puzle: ventana de sin movimientos sin problemas de interfaz", probs.is_empty(), str(probs.slice(0, 2)))
	panel.queue_free()
	await stop_game(game)

	game = await start_game(cfg, 0)
	var done: bool = await QaBot.run(get_tree(), game, 60 * 60)
	var st: Dictionary = game.call("bot_state")
	check("puzle: el bot alcanza el objetivo y rompe el hielo", done and int(st["ice_left"]) == 0, "muertes=%d puntos=%d/%d" % [int(st["deaths"]), int(st["score"]), int(st["target"])])
	await stop_game(game)

	var ok: Dictionary = Match3Logic.analyze(cfg["levels"][0]["map"])
	check("puzle: tablero bueno", bool(ok["completable"]), str(ok["issues"]))
	var hole: Dictionary = Match3Logic.analyze([".......", ".......", "...#...", ".......", ".......", "......."])
	check("puzle: hueco en medio de una columna detectado", (hole["issues"] as Array).has("match3_hole_inside"), str(hole["issues"]))


## 18 - Genero torres: construir, mejorar, vender, oleadas por el camino, derrota si llegan a la
## base, el bot gana y el analizador vigila el camino.
func tower_config() -> Dictionary:
	var map: Array = [
		".S.......",
		".=.......",
		".=======.",
		"....#..=.",
		".......=.",
		".=======.",
		".=.......",
		".=.......",
		".=======.",
		".......=.",
		"#......=.",
		"....====.",
		"....B....",
	]
	var cfg: Dictionary = base_config.duplicate(true)
	cfg["genre"] = "tower"
	cfg["levels"] = [{"name": "camino", "map": map, "waves": 5, "density": 0.5, "enemies": ["walker", "flyer", "spiky"], "boss": true, "gold": 150, "lives": 10}]
	return cfg


func _test_tower() -> void:
	print("- Torres")
	var game: Node = await start_game(tower_config(), 0)
	check("torres: escena propia", game.has_method("tower_bot_step"))
	var gold0: int = int(game.get("gold"))
	check("torres: no se construye en el camino", not bool(game.call("build", Vector2i(1, 1), "rayo")))
	check("torres: construir cuesta oro", bool(game.call("build", Vector2i(2, 1), "rayo")) and int(game.get("gold")) == gold0 - 50)
	game.call("tap", Vector2i(2, 1))
	await frames(1)
	check("torres: tocar una torre ofrece mejorar y vender", game.find_child("BtnUpgrade", true, false) != null and game.find_child("BtnSell", true, false) != null)
	game.set("gold", 500)
	check("torres: mejorar sube el nivel", bool(game.call("upgrade", Vector2i(2, 1))) and int((game.get("towers") as Dictionary)[Vector2i(2, 1)]["level"]) == 2)
	var g1: int = int(game.get("gold"))
	game.call("sell_tower", Vector2i(2, 1))
	check("torres: vender devuelve parte del oro", int(game.get("gold")) > g1 and (game.get("towers") as Dictionary).is_empty())
	game.call("tap", Vector2i(3, 3))
	await frames(1)
	check("torres: casilla libre ofrece las 3 torres", game.find_child("Build_rayo", true, false) != null and game.find_child("Build_canon", true, false) != null and game.find_child("Build_hielo", true, false) != null)
	var problems: Array[String] = UI.audit(game.get_node("Hud").get_child(0))
	check("torres: barra de acciones sin problemas de interfaz", problems.is_empty(), str(problems.slice(0, 2)))
	game.call("tap", Vector2i(3, 3))
	game.call("start_wave")
	await frames(120)
	var es: Array = game.get("enemies")
	check("torres: la oleada sale y avanza por el camino", es.size() > 0 and float((es[0] as Dictionary)["d"]) > 50.0)
	game.set("fast", true)
	game.set("lives", 3)
	for k: int in 60 * 40:
		await get_tree().physics_frame
		if bool(game.get("failed")):
			break
	check("torres: sin torres llegan a la base y se pierde", bool(game.get("failed")) and game.get_node_or_null("FailPanel") != null)
	await stop_game(game)

	game = await start_game(tower_config(), 0)
	var done: bool = await QaBot.run(get_tree(), game, 60 * 60)
	var st: Dictionary = game.call("bot_state")
	check("torres: el bot defiende la base y gana", done and int(st["deaths"]) <= 1, "muertes=%d vidas=%d oleada=%d torres=%d" % [int(st["deaths"]), int(st["lives"]), int(st["wave"]), int(st["towers"])])
	await stop_game(game)

	var ok: Dictionary = TowerMap.analyze(tower_config()["levels"][0]["map"])
	check("torres: camino bueno", bool(ok["completable"]), str(ok["issues"]))
	var broken: Array = (tower_config()["levels"][0]["map"] as Array).duplicate()
	broken[4] = "........."
	check("torres: camino roto detectado", (TowerMap.analyze(broken)["issues"] as Array).has("td_broken_path"))
	var branch: Array = (tower_config()["levels"][0]["map"] as Array).duplicate()
	branch[3] = ".=..#..=."
	branch[4] = ".=.....=."
	check("torres: atajo detectado", (TowerMap.analyze(branch)["issues"] as Array).has("td_branch"))


## 19 - Genero carreras: arranque con cuenta atras, el coche acelera solo, los conos frenan,
## las monedas cargan el turbo, el bot acaba en el podio y el analizador vigila la pista.
func race_track(n: int) -> Array:
	var rows: Array = []
	for i: int in n:
		var curve: String = ["|", "<", "|", ">"][(i / 30) % 4]
		var lanes: Array[String] = [".", ".", ".", "."]
		if i >= 10 and i % 6 == 0:
			lanes[(i / 6) % 4] = "O"
		if i >= 10 and i % 6 == 3:
			lanes[(i / 6 + 2) % 4] = "C"
		if i == 40:
			lanes[1] = "N"
		rows.append(curve + "".join(lanes))
	return rows


func race_config(rival_speed: float) -> Dictionary:
	var cfg: Dictionary = base_config.duplicate(true)
	cfg["genre"] = "race"
	cfg["levels"] = [{"name": "circuito", "map": race_track(150), "rival_speed": rival_speed}]
	return cfg


func _test_race() -> void:
	print("- Carreras")
	var game: Node = await start_game(race_config(0.9), 0)
	check("carreras: escena propia", game.has_method("race_bot_step"))
	await frames(60)
	check("carreras: cuenta atras antes de salir", not bool(game.get("started")) and float(game.get("d")) == 0.0)
	await frames(120)
	check("carreras: acelera solo", bool(game.get("started")) and float(game.get("speed")) > 300.0)
	Input.action_press("move_right")
	var lat0: float = game.get("lat")
	await frames(20)
	Input.action_release("move_right")
	check("carreras: las flechas cambian de carril", float(game.get("lat")) - lat0 > 60.0)
	game.set("d", 9.5 * 96.0)
	game.set("lat", game.call("lane_lat", 2))
	game.set("speed", 600.0)
	game.set("stun_left", 0.0)
	await frames(30)
	check("carreras: chocar con un cono frena", int(game.get("crashes")) >= 1, "choques=%d" % int(game.get("crashes")))
	game.set("nitro", 1.0)
	game.call("use_nitro")
	check("carreras: el turbo se usa con la barra llena", float(game.get("boost_left")) > 2.0 and float(game.get("nitro")) == 0.0)
	await stop_game(game)

	game = await start_game(race_config(0.9), 0)
	var done: bool = await QaBot.run(get_tree(), game, 60 * 60)
	var st: Dictionary = game.call("bot_state")
	check("carreras: el bot acaba en el podio", done and int(st["deaths"]) <= 1, "puesto=%d muertes=%d choques=%d" % [int(st["place"]), int(st["deaths"]), int(st["crashes"])])
	check("carreras: recoge monedas", int(st["coins"]) >= 5, str(st["coins"]))
	await stop_game(game)
	game = await start_game(race_config(1.2), 0)
	game.set("fast", true)
	game.set("bot_lat", 0.0)
	for k: int in 60 * 40:
		await get_tree().physics_frame
		if bool(game.get("failed")):
			break
	check("carreras: llegar cuarto obliga a repetir", bool(game.get("failed")) and game.get_node_or_null("FailPanel") != null, "fallo=%s puesto=%d d=%.0f de %.0f" % [str(game.get("failed")), int(game.get("place")), float(game.get("d")), float(game.get("track_len"))])
	await stop_game(game)

	## 1 - Vista 3D: la misma carrera dibujada en 3D; el bot la gana igual.
	var cfg3: Dictionary = race_config(0.9)
	cfg3["view"] = "3d"
	game = await start_game(cfg3, 0)
	var v3: Node = game.get("view3d")
	check("carreras 3D: vista 3D con camara propia", v3 != null and v3.get_node_or_null("Camera3D") != null and v3.get_node_or_null("Road") != null)
	check("carreras 3D: coches y objetos en 3D", v3 != null and (v3.get("_items") as Array).size() == (game.get("items") as Array).size()
		and (v3.get("_rivals") as Array).size() == 3)
	done = await QaBot.run(get_tree(), game, 60 * 60)
	st = game.call("bot_state")
	check("carreras 3D: el bot acaba en el podio", done and int(st["deaths"]) <= 1, "puesto=%d" % int(st["place"]))
	var car3: Node3D = v3.get("_car")
	check("carreras 3D: el coche 3D sigue al del juego", car3 != null and absf(car3.position.z + float(game.get("d")) * Race3DView.SZ) < 0.5,
		"z=%.1f d=%.1f" % [car3.position.z if car3 != null else 0.0, float(game.get("d"))])
	await stop_game(game)

	var ok: Dictionary = RaceTrack.analyze({"map": race_track(150)})
	check("carreras: pista buena", bool(ok["completable"]), str(ok["issues"]))
	var wall: Array = race_track(150)
	wall[50] = "|OOTO"
	check("carreras: muro de obstaculos detectado", (RaceTrack.analyze({"map": wall})["issues"] as Array).has("race_wall"))
	var zig: Array = race_track(150)
	zig[60] = "|OO.."
	zig[61] = "|.OOO"
	check("carreras: paso imposible detectado", (RaceTrack.analyze({"map": zig})["issues"] as Array).has("race_blocked"))



## Clasificacion online y retos (kit/online.gd): apodos, enlaces, panel de resultado y lista.
## El servidor se sustituye por uno falso en memoria (Online.fake).
## Torneo semanal: nivel de la semana, premio del podio, jugar y subir la marca.
func _test_torneo() -> void:
	print("- Torneo semanal")
	var calls: Array = []
	Online.fake = func(rpc: String, payload: Dictionary) -> Variant:
		calls.append([rpc, payload])
		match rpc:
			"torneo_info":
				return {"semana": "2026-S41", "nivel": 1, "segundos": 200000, "mejor": 0, "premio": 200, "puesto_pasado": 2}
			"torneo_top":
				return [{"posicion": 1, "alias": "Lucia", "puntos": 900, "tuyo": false}]
			"torneo_reclamar":
				return 200
			"torneo_enviar":
				return {"mejor": 3480, "posicion": 4}
		return null
	Save.set_setting("online", true, false)
	Save.set_setting("alias", "Dani", false)
	var cfg: Dictionary = test_config(["..........", "P...C...G.", "##########"])
	(cfg["levels"] as Array).append((cfg["levels"] as Array)[0].duplicate(true))
	Kit.set_config(cfg)
	var host: Control = Control.new()
	add_child(host)
	var tp: TournamentPanel = TournamentPanel.open(host)
	await frames(6)
	check("torneo: muestra el nivel de la semana y lo que queda", (tp.find_child("Status", true, false) as Label).text.contains("2") and not (tp.find_child("BtnPlay", true, false) as Button).disabled)
	var prize: Button = tp.find_child("BtnPrize", true, false) as Button
	var w0: int = Save.wallet()
	check("torneo: premio del podio de la semana pasada", prize != null)
	if prize != null:
		prize.pressed.emit()
		await frames(3)
		check("torneo: cobrar el premio suma monedas una vez", Save.wallet() == w0 + 200)
	var tm: bool = UI.test_mode
	UI.test_mode = true
	tp.play()
	UI.test_mode = tm
	check("torneo: jugar abre el nivel de la semana", Kit.level_index == 1 and not Online.torneo.is_empty())
	host.queue_free()
	var rhost: Control = Control.new()
	add_child(rhost)
	var rp: ResultPanel = ResultPanel.open(rhost, {"stars": 3, "coins": 1, "coins_total": 1, "score": 3480, "record": true})
	await frames(6)
	var sent: bool = false
	for c: Array in calls:
		if c[0] == "torneo_enviar" and int(c[1]["p_puntos"]) == 3480:
			sent = true
	check("torneo: al acabar el nivel sube la marca y dice el puesto", sent and rp.find_child("Torneo", true, false) != null)
	rhost.queue_free()
	Kit.level_index = 0
	Online.torneo = {}
	Online.fake = Callable()
	Save.add_wallet(-200)
	Save.set_setting("alias", "", false)
	get_tree().paused = false
	Kit.set_config(base_config)
	await frames(2)


## Idiomas: texto, nivel e historia traducidos; selector en Ajustes; sin traduccion, el original.
func _test_i18n() -> void:
	print("- Idiomas")
	var cfg: Dictionary = test_config(["..........", "P...C...G.", "##########"])
	cfg["lang"] = "es"
	cfg["texts"] = {"play": "Jugar", "coins": "Tuercas"}
	cfg["i18n"] = {"en": {"play": "Play", "coins": "Nuts", "language": "Language", "_levels": [{"name": "Rooftops"}],
		"_story": [{"intro": [{"who": "heroe", "text": "Here I go!"}], "outro": []}]}, "fr": {"play": "Jouer"}}
	cfg["story"] = {"cast": {"heroe": {"name": "Bigotes"}}, "levels": [{"intro": [{"who": "heroe", "text": "\u00a1All\u00e1 voy!", "voice": "d0_0"}], "outro": []}]}
	(cfg["levels"] as Array)[0]["name"] = "Tejados"
	Kit.set_config(cfg)
	Save.set_setting("lang", "", false)
	check("idiomas: el del juego y sus traducciones", Kit.languages() == ["es", "en", "fr"], str(Kit.languages()))
	Kit.set_lang("en")
	check("idiomas: texto traducido", Kit.text("play", "Jugar") == "Play" and Kit.text("coins", "") == "Nuts")
	check("idiomas: lo que no esta traducido sale en el original", Kit.text("retry", "Repetir") == "Repetir")
	Kit.level_index = 0
	check("idiomas: nombre del nivel traducido (el mapa sigue igual)", Kit.current_level()["name"] == "Rooftops" and (Kit.current_level()["map"] as Array).size() == 3)
	var ls: Array = Story.lines_for(0, "intro")
	check("idiomas: historia traducida y sin la voz grabada en el original", ls.size() == 1 and ls[0]["text"] == "Here I go!" and not (ls[0] as Dictionary).has("voice"))
	Kit.set_lang("xx")
	check("idiomas: un idioma que no existe no se pone", Kit.lang() == "en")
	check("idiomas: se recuerda", str(Save.get_setting("lang", "")) == "en")
	var host: Control = Control.new()
	add_child(host)
	var sp: SettingsPanel = SettingsPanel.open(host)
	await frames(2)
	var lb: Button = sp.body.get_node_or_null("BtnLanguage") as Button
	check("idiomas: selector en Ajustes", lb != null and lb.text.contains("English"))
	if lb != null:
		lb.pressed.emit()
		check("idiomas: el selector pasa al siguiente", Kit.lang() == "fr" and lb.text.contains("Fran"))
	host.queue_free()
	Kit.set_lang("es")
	check("idiomas: vuelta al original", Kit.text("play", "x") == "Jugar" and Story.lines_for(0, "intro")[0]["text"] == "\u00a1All\u00e1 voy!")
	Save.set_setting("lang", "", false)
	Kit.set_config(base_config)
	await frames(2)


## Charla en directo: boton solo si esta activa, respuestas del servidor, respaldo sin red.
func _test_chat() -> void:
	print("- Charla con personajes")
	var sent: Array = []
	Online.set("_chat_active", -1)
	Online.fake = func(rpc: String, payload: Dictionary) -> Variant:
		sent.append([rpc, payload])
		if rpc == "charla_activa":
			return true
		if rpc == "charla":
			return {"texto": "\u00a1Miau! Salta en la tercera chimenea.", "nombre": "Bigotes"}
		return null
	Save.set_setting("online", true, false)
	var cfg: Dictionary = test_config(["..........", "P...C...G.", "##########"])
	cfg["story"] = {"cast": {"heroe": {"name": "Bigotes", "sprite": "heroe"}, "rival": {"name": "Chatarrilla"}, "narrador": {"name": ""}},
		"levels": [{"intro": [{"who": "rival", "text": "Ni lo sue\u00f1es, gatito."}], "outro": []}]}
	Kit.set_config(cfg)
	var host: Control = Control.new()
	add_child(host)
	var pm: PauseMenu = PauseMenu.open(host)
	await frames(4)
	var talk: Button = pm.body.get_node_or_null("BtnChat") as Button
	check("charla: boton en la pausa cuando el autor la activa", talk != null and talk.text.contains("Bigotes"))
	var chat: ChatPanel = ChatPanel.open(pm)
	await frames(2)
	check("charla: heroe y rival (sin narrador)", chat.people.size() == 2 and chat.body.get_node_or_null("Tabs") != null)
	await chat.send("\u00bfAlg\u00fan truco?")
	var last: Array = sent.back()
	check("charla: manda personaje, mensaje y sesion", last[0] == "charla" and last[1]["personaje"] == "heroe" and str(last[1]["sesion"]).length() == 16)
	check("charla: responde el personaje", (chat.history["heroe"] as Array).size() == 2 and str(chat.history["heroe"][1]["texto"]).contains("chimenea"))
	chat.switch_to("rival")
	Online.fake = func(_rpc: String, _payload: Dictionary) -> Variant: return null
	await chat.send("hola")
	check("charla: sin red contesta con sus frases de la historia", str(chat.history["rival"][1]["texto"]).contains("gatito"))
	await chat.send("")
	check("charla: mensaje vacio no se manda", (chat.history["rival"] as Array).size() == 2)
	host.queue_free()
	get_tree().paused = false
	Online.fake = Callable()
	Online.set("_chat_active", -1)
	Kit.set_config(base_config)
	await frames(2)


## Amigos: tu codigo, anadir con el de otro y la clasificacion solo con amigos.
func _test_friends() -> void:
	print("- Amigos")
	var calls: Array = []
	Online.fake = func(rpc: String, payload: Dictionary) -> Variant:
		calls.append([rpc, payload])
		match rpc:
			"marcador_top":
				return [{"posicion": 1, "alias": "Pepe", "puntos": 900, "tuyo": false}]
			"amigo_codigo":
				return "K7F2Q9"
			"amigo_anadir":
				return {"alias": "Lucia"} if str(payload["p_codigo"]) == "ABC234" else null
			"amigos_top":
				return [{"posicion": 1, "alias": "Lucia", "puntos": 500, "tuyo": false}, {"posicion": 2, "alias": "Dani", "puntos": 300, "tuyo": true}]
		return null
	Save.set_setting("online", true, false)
	Save.set_setting("alias", "Dani", false)
	var host: Control = Control.new()
	add_child(host)
	var lb: LeaderboardPanel = LeaderboardPanel.open(host, 0, 0)
	await frames(5)
	check("amigos: pestanas Todos / Amigos", lb.find_child("Tab_friends", true, false) != null)
	(lb.find_child("Tab_friends", true, false) as Button).pressed.emit()
	await frames(5)
	check("amigos: tu codigo para compartir", (lb.find_child("BtnMyCode", true, false) as Button).text.contains("K7F2Q9"))
	check("amigos: clasificacion solo con amigos", lb.find_child("Row2", true, false) != null)
	(lb.find_child("FriendEdit", true, false) as LineEdit).text = "abc234"
	(lb.find_child("BtnAddFriend", true, false) as Button).pressed.emit()
	await frames(4)
	var added: bool = false
	for c: Array in calls:
		if c[0] == "amigo_anadir" and str(c[1]["p_codigo"]) == "ABC234":
			added = true
	check("amigos: anadir con el codigo (en mayusculas)", added)
	host.queue_free()
	Online.fake = Callable()
	Save.set_setting("alias", "", false)
	await frames(2)


## Fantasmas: baja la carrera del que va por delante, corre a la vez que tu y tu recorrido
## se sube al batir tu marca.
func _test_ghosts() -> void:
	print("- Fantasmas")
	var calls: Array = []
	var route: Array = []
	for i: int in 60:
		route.append([200 + i * 20, 300])
	Online.fake = func(rpc: String, payload: Dictionary) -> Variant:
		calls.append([rpc, payload])
		match rpc:
			"fantasma_bajar":
				return {"alias": "Lucia", "puntos": 900, "datos": route}
			"marcador_enviar":
				return {"posicion": 1, "mejor": int(payload["p_puntos"])}
		return null
	Save.set_setting("online", true, false)
	Save.set_setting("alias", "Dani", false)
	var map: Array = [
		"..............................",
		"..P.......................G...",
		"##############################",
	]
	var game: Node = await start_game(test_config(map), 0)
	await frames(30)
	var lvl: Node = game.get("level")
	var g: Node2D = lvl.get_node_or_null("Ghost") as Node2D
	check("fantasmas: aparece la sombra del que va por delante", g != null)
	if g != null:
		var x0: float = g.position.x
		await frames(30)
		check("fantasmas: corre con el reloj del nivel", g.position.x > x0 + 20.0, "%.0f -> %.0f" % [x0, g.position.x])
	check("fantasmas: se graba tu recorrido", (game.get("ghost_points") as Array).size() > 3)
	Online.ghost_pending = {"level": 0, "points": [[1, 2], [3, 4]]}
	await Online.submit(0, 500)
	var up: bool = false
	for c: Array in calls:
		if c[0] == "fantasma_subir" and int(c[1]["p_puntos"]) == 500 and (c[1]["p_datos"] as Array).size() == 2:
			up = true
	check("fantasmas: se sube al batir tu marca", up and Online.ghost_pending.is_empty())
	calls.clear()
	Save.set_setting("ghosts", false, false)
	check("fantasmas: se pueden apagar", (await Online.ghost_download(0)).is_empty() and calls.is_empty())
	Save.set_setting("ghosts", true, false)
	await stop_game(game)
	Online.fake = Callable()
	Save.set_setting("alias", "", false)
	await frames(2)


## Eventos en directo del autor: franja en el titulo, regalo una vez y monedas dobles.
func _test_live_event() -> void:
	print("- Eventos en directo")
	var ev: Array = [{"id": 3, "tipo": "regalo", "titulo": "Fiesta de otono", "regalo": 120, "segundos": 90000, "cobrado": false}]
	var claims: Array = [0]
	Online.fake = func(rpc: String, _payload: Dictionary) -> Variant:
		match rpc:
			"evento_actual":
				return (ev[0] as Dictionary).duplicate()
			"evento_regalo_cobrar":
				claims[0] += 1
				return 120 if claims[0] == 1 else 0
		return null
	Save.set_setting("online", true, false)
	var w0: int = Save.wallet()
	var title: Node = (load(UI.SCREEN_TITLE) as PackedScene).instantiate()
	add_child(title)
	await frames(4)
	var band: Node = title.find_child("EventBand", true, false)
	check("eventos: franja con el evento del autor", band != null and (band.find_child("EventText", true, false) as Label).text.contains("Fiesta de otono"))
	var gift: Button = title.find_child("BtnEventGift", true, false) as Button
	check("eventos: boton de regalo con su cantidad", gift != null and gift.text.contains("120"))
	if gift != null:
		gift.pressed.emit()
		await frames(3)
	check("eventos: el regalo suma monedas una vez", Save.wallet() == w0 + 120 and claims[0] == 1 and title.find_child("BtnEventGift", true, false) == null,
		str(Save.wallet() - w0))
	title.queue_free()
	await frames(1)
	ev[0] = {"id": 4, "tipo": "monedas_x2", "titulo": "Doble finde", "regalo": 0, "segundos": 3600, "cobrado": false}
	await Online.fetch_event()
	check("eventos: monedas dobles activas", Online.coin_multiplier() == 2)
	var w1: int = Save.wallet()
	var rp: ResultPanel = ResultPanel.open(self, {"stars": 2, "coins": 5, "coins_total": 5, "score": 300, "record": false})
	await frames(2)
	check("eventos: el premio del nivel vale doble", Save.wallet() == w1 + 50 and (rp.find_child("Reward", true, false) as Label).text.contains("x2"),
		str(Save.wallet() - w1))
	rp.queue_free()
	Online.live_event = {}
	check("eventos: sin evento, premio normal", Online.coin_multiplier() == 1)
	Online.fake = Callable()
	Save.add_wallet(w0 - Save.wallet())
	await frames(2)


## Pasar a otro movil: subir con codigo y PIN, recuperar sustituye la partida, PIN malo no toca nada.
func _test_cloud() -> void:
	print("- Guardado en la nube")
	var store: Dictionary = {}
	Online.fake = func(rpc: String, payload: Dictionary) -> Variant:
		match rpc:
			"nube_guardar":
				store["datos"] = (payload["p_datos"] as Dictionary).duplicate(true)
				return {"codigo": "K7F2Q9AB", "pin": "123456"}
			"nube_restaurar":
				return store.get("datos", null) if str(payload["p_codigo"]) == "K7F2Q9AB" and str(payload["p_pin"]) == "123456" else null
		return null
	Save.set_setting("online", true, false)
	var w0: int = Save.wallet()
	var host: Control = Control.new()
	add_child(host)
	var cp: CloudPanel = CloudPanel.open(host)
	await frames(2)
	(cp.find_child("BtnCloudSave", true, false) as Button).pressed.emit()
	await frames(3)
	check("nube: guardar ensena codigo y PIN", (cp.find_child("Status", true, false) as Label).text.contains("K7F2Q9AB")
		and (cp.find_child("Status", true, false) as Label).text.contains("123456"))
	check("nube: se sube la partida entera", (store.get("datos", {}) as Dictionary).has("meta") and str(Save.get_setting("cloud_code", "")) == "K7F2Q9AB")
	Save.add_wallet(777)
	(cp.find_child("CodeEdit", true, false) as LineEdit).text = "k7f2q9ab"
	(cp.find_child("PinEdit", true, false) as LineEdit).text = "999999"
	cp.restore()
	await frames(3)
	check("nube: PIN malo no toca la partida", Save.wallet() == w0 + 777 and (cp.find_child("Status", true, false) as Label).text != "")
	(cp.find_child("PinEdit", true, false) as LineEdit).text = "123456"
	cp.restore()
	await frames(3)
	check("nube: recuperar sustituye la partida de este movil", Save.wallet() == w0)
	host.queue_free()
	Online.fake = Callable()
	await frames(2)


## Misiones y pase: se cuentan solas con los eventos de partida, se cobran una vez, el XP sube
## niveles del pase y el premium (comprado) da su premio y el aspecto exclusivo.
func _test_season() -> void:
	print("- Misiones y pase")
	var m: Dictionary = Save.meta()
	m.erase("season")
	var w0: int = Save.wallet()
	Season.fake_day = 20000
	Season.set_meta("count_in_tests", true)
	var daily: Array = Season.missions(false)
	var weekly: Array = Season.missions(true)
	check("misiones: 3 diarias y 3 semanales distintas", daily.size() == 3 and weekly.size() == 3
		and str(daily[0]["kind"]) != str(daily[1]["kind"]) and str(daily[1]["kind"]) != str(daily[2]["kind"]))
	Season.fake_day = 20001
	var other: Array = Season.missions(false)
	var same: bool = true
	for i: int in 3:
		if str(other[i]["kind"]) != str(daily[i]["kind"]) or int(other[i]["goal"]) != int(daily[i]["goal"]):
			same = false
	check("misiones: cambian con el dia", not same)
	## Completar: 30 partidas con 3 estrellas y monedas.
	for i: int in 30:
		QA.log_event("level_start", {"level": 0})
		QA.log_event("level_complete", {"level": 0, "stars": 3, "coins": 10, "kills": 10})
	var all_done: bool = true
	for d: Variant in Season.missions(false) + Season.missions(true):
		if int((d as Dictionary)["have"]) < int((d as Dictionary)["goal"]):
			all_done = false
	check("misiones: se cuentan solas jugando", all_done)
	check("pase: cada estrella da XP", Season.xp() == 30 * 3 * Season.STAR_XP, str(Season.xp()))
	var r: Dictionary = Season.claim_mission(false, 0)
	check("misiones: cobrar da monedas y XP", int(r.get("coins", 0)) == 40 and Save.wallet() == w0 + 40 and Season.xp() == 900 + 100)
	check("misiones: no se cobra dos veces", Season.claim_mission(false, 0).is_empty())
	Season.claim_mission(true, 0)
	check("pase: el XP sube de nivel (500 por nivel)", Season.tier() == 2, str(Season.tier()))
	var w1: int = Save.wallet()
	check("pase: premio gratis del nivel 1", int(Season.claim_tier(1, false).get("coins", 0)) == 25 and Save.wallet() == w1 + 25)
	check("pase: sin premium no se cobra la via premium", Season.claim_tier(1, true).is_empty())
	check("pase: no se cobra un nivel no alcanzado", Season.claim_tier(5, false).is_empty())
	## Premium y aspecto exclusivo del nivel 10.
	Season.unlock_premium()
	var st: Dictionary = Season.state()
	st["xp"] = Season.TIER_XP * 10
	check("pase: premium cobra tambien los niveles ya alcanzados", Season.claimable_tiers().has([1, true]) and Season.claimable_tiers().has([10, true]))
	Season.claim_tier(10, true)
	check("pase: el nivel 10 premium da el aspecto Estelar", Save.owns_skin("estelar"))
	## Panel
	var host: Control = Control.new()
	add_child(host)
	var sp: SeasonPanel = SeasonPanel.open(host)
	await frames(2)
	check("panel: misiones con su boton", sp.find_child("Daily_0", true, false) != null and sp.find_child("Weekly_2", true, false) != null)
	(sp.find_child("Tab_pass", true, false) as Button).pressed.emit()
	await frames(2)
	check("panel: pase con sus 20 niveles", sp.find_child("Free_20", true, false) != null and sp.find_child("Prem_20", true, false) != null
		and (sp.find_child("PassHead", true, false) as Label).text.contains("10"))
	host.queue_free()
	## Nueva temporada (otro mes): empieza de cero.
	Season.fake_day = 20001 + 40
	check("pase: cada mes empieza de cero", Season.xp() == 0 and not Season.premium())
	Season.fake_day = -1
	Season.remove_meta("count_in_tests")
	m = Save.meta()
	m.erase("season")
	var skins: Array = m.get("skins", [])
	skins.erase("estelar")
	Save.add_wallet(w0 - Save.wallet())
	await frames(2)


## Tienda de Google Play (simulada): ofertas en la tienda, comprar da lo comprado solo si el
## servidor lo verifica, "sin anuncios" quita los intersticiales y el pase activa el premium.
func _test_store() -> void:
	print("- Compras dentro del juego")
	var w0: int = Save.wallet()
	Store.fake = true
	var host: Control = Control.new()
	add_child(host)
	var shop: ShopPanel = ShopPanel.open(host)
	await frames(2)
	check("tienda: ofertas con precio", shop.find_child("Iap_monedas_500", true, false) != null
		and (shop.find_child("Iap_monedas_500", true, false) as Button).text.contains("0,99"))
	(shop.find_child("Iap_monedas_500", true, false) as Button).pressed.emit()
	await frames(3)
	check("tienda: comprar 500 monedas", Save.wallet() == w0 + 500)
	Store.fake_verify = func(_id: String, _t: String) -> bool: return false
	var fails: Array = []
	var on_fail: Callable = func(id: String, why: String) -> void: fails.append([id, why])
	Store.failed.connect(on_fail)
	Store.buy("monedas_3000")
	await frames(3)
	check("tienda: si el servidor no la verifica, no se da nada", Save.wallet() == w0 + 500 and fails.size() == 1 and str(fails[0][1]) == "not_verified")
	Store.failed.disconnect(on_fail)
	Store.fake_verify = Callable()
	Store.buy("sin_anuncios")
	await frames(3)
	check("tienda: sin anuncios", Store.no_ads() and not Ads.can_show_interstitial("level_end"))
	Season.fake_day = 20000
	Store.buy("pase_temporada")
	await frames(3)
	check("tienda: el pase activa el premium de la temporada", Season.premium())
	host.queue_free()
	Store.fake = false
	Save.set_setting("no_ads", false)
	var m: Dictionary = Save.meta()
	m.erase("season")
	Season.fake_day = -1
	Save.add_wallet(w0 - Save.wallet())
	check("tienda: sin plugin ni pruebas no hay tienda", not Store.available())
	await frames(2)


## Avisos y buzon: plan de avisos segun la hora, misiones y eventos; apagarlos; buzon con ataques.
func _test_notify() -> void:
	print("- Avisos y buzon")
	Notify.fake = true
	var m: Dictionary = Save.meta()
	m.erase("season")
	Season.fake_day = 20000
	var n: int = Notify.reschedule({"hour": 10, "minute": 0, "second": 0})
	var ids: Array = Notify.scheduled.map(func(x: Variant) -> int: return int((x as Dictionary)["id"]))
	check("avisos: premio diario, misiones de hoy y vuelve", n == 3 and ids.has(101) and ids.has(102) and ids.has(104), str(ids))
	var daily: Dictionary = Notify.scheduled[0]
	check("avisos: el premio diario suena manana a las 18", int(daily["delay"]) == 32 * 3600, str(daily["delay"]))
	Notify.reschedule({"hour": 21, "minute": 0, "second": 0})
	check("avisos: de noche no avisa de misiones de hoy", not Notify.scheduled.any(func(x: Variant) -> bool: return int((x as Dictionary)["id"]) == 102))
	Online.live_event = {"tipo": "regalo", "titulo": "Fiesta", "cobrado": false, "hasta_ms": Time.get_ticks_msec() + 86400000}
	Notify.reschedule({"hour": 10, "minute": 0, "second": 0})
	check("avisos: regalo del evento sin recoger", Notify.scheduled.any(func(x: Variant) -> bool: return int((x as Dictionary)["id"]) == 103))
	Save.set_setting("notifications", false, false)
	check("avisos: apagados no se programa nada", Notify.reschedule() == 0)
	Save.set_setting("notifications", true, false)
	## Buzon
	Online.fake = func(rpc: String, _p: Dictionary) -> Variant:
		match rpc:
			"torneo_info":
				return {"nivel": 0, "premio": 200, "puesto_pasado": 2}
		return null
	Save.set_setting("online", true, false)
	Save.set_setting("inbox_seen", 0, false)
	var items: Array = await Notify.inbox()
	var kinds: Array = items.map(func(x: Variant) -> String: return str((x as Dictionary)["kind"]))
	check("buzon: premio del torneo y regalo del evento", kinds.has("torneo") and kinds.has("evento"), str(kinds))
	var host: Control = Control.new()
	add_child(host)
	var ip: InboxPanel = InboxPanel.open(host, items)
	await frames(2)
	check("buzon: panel con una linea por cosa", ip.find_child("Item1", true, false) != null)
	host.queue_free()
	Online.fake = Callable()
	Online.live_event = {}
	Notify.fake = false
	Season.fake_day = -1
	m = Save.meta()
	m.erase("season")
	await frames(2)


## Repeticiones de la liga: el asalto se graba (paso de fisica, tropa, casilla y desvio), se sube
## al acabar y, al verlo, se vuelve a simular igual: mismas estrellas y misma destruccion.
func _test_replay() -> void:
	print("- Repeticiones de asaltos")
	Save.meta().erase("aldea")
	Save.save_data()
	UI.test_mode = true
	var sent: Array = []
	Online.fake = func(rpc: String, payload: Dictionary) -> Variant:
		match rpc:
			"liga_resultado":
				return {"trofeos": 70}
			"liga_repeticion_subir":
				sent.append((payload["p_datos"] as Dictionary).duplicate(true))
				return true
		return null
	Save.set_setting("online", true, false)
	Online.liga_match = {"ataque": 9, "alias": "Lucia", "mapa": village_base(), "ayto": 2, "trofeos": 55}
	var game: Node = await start_game(village_config(["................", "......H........."], {}), 0)
	var cells: Array = game.call("deploy_cells")
	var plan: Array = [[0, "gigante"], [0, "gigante"], [20, "guerrero"], [20, "guerrero"], [45, "arquera"], [45, "arquera"],
		[70, "guerrero"], [70, "guerrero"], [70, "guerrero"], [90, "arquera"], [90, "arquera"], [90, "arquera"]]
	var at: int = 0
	for i: int in plan.size():
		while at < int(plan[i][0]):
			await get_tree().physics_frame
			at += 1
		game.call("deploy", str(plan[i][1]), cells[(i * 7) % cells.size()])
	var guard: int = 0
	while not bool(game.get("finished")) and guard < 12000:
		await get_tree().physics_frame
		guard += 1
	await frames(4)
	var live_deployed: int = int(game.get("deployed"))
	var live_stars: int = int(game.get("stars"))
	var live_pct: float = float(game.get("destruction"))
	check("repeticion: el asalto se graba y se sube al acabar", sent.size() == 1 and live_deployed >= 6
		and ((sent[0] as Dictionary)["eventos"] as Array).size() == live_deployed, str(live_deployed))
	await stop_game(game)
	if sent.is_empty():
		Online.fake = Callable()
		return
	var data: Dictionary = sent[0]
	data["alias"] = "Lucia"
	var json_rt: Variant = JSON.parse_string(JSON.stringify(data))
	Online.liga_replay = json_rt
	game = await start_game(village_config(["................", "......H........."], {}), 0)
	check("repeticion: sin cartas de tropas (no se toca nada)", not (game.find_child("Cards", true, false) as Control).visible)
	guard = 0
	while not bool(game.get("finished")) and guard < 12000:
		await get_tree().physics_frame
		guard += 1
	await frames(4)
	check("repeticion: mismas estrellas y misma destruccion", int(game.get("stars")) == live_stars and is_equal_approx(float(game.get("destruction")), live_pct),
		"%d/%.2f vs %d/%.2f" % [int(game.get("stars")), float(game.get("destruction")), live_stars, live_pct])
	var rp: LigaPanel = game.get_node_or_null("LigaPanel") as LigaPanel
	check("repeticion: al acabar, ver otra vez o volver", rp != null and rp.find_child("BtnReplayAgain", true, false) != null)
	check("repeticion: no cuenta para la liga ni sube nada", sent.size() == 1 and Online.liga_match.is_empty())
	await stop_game(game)
	Online.fake = Callable()
	Online.liga_replay = {}
	Save.set_setting("alias", "", false)
	await frames(2)


## Cooperativo: dos jugadores en el mismo equipo contra 3 oleadas de bots (los mueve el anfitrion),
## sin fuego amigo; cada oleada sale en los dos juegos y al acabar la ultima ganan los dos.
func _test_coop() -> void:
	print("- Arena cooperativa")
	var calls: Array = []
	Online.fake = func(rpc: String, payload: Dictionary) -> Variant:
		calls.append([rpc, payload])
		if rpc == "arena_resultado":
			return {"trofeos": 40, "delta": 0, "coop": true}
		return null
	Online.fake_net_latency = 0.03
	Save.set_setting("online", true, false)
	var map: Array = ["...............", "...R.......R...", "...............", "...............", "...............",
		"...............", "...............", "...............", ".......P.......", "...............", "...............", "..............."]
	var cfg: Dictionary = brawl_config(map, {"reaction": 99.0})
	var players: Array = [{"sesion": "aaaaaaaaaaaaaaa1", "alias": "Dani", "slot": 0}, {"sesion": "bbbbbbbbbbbbbbb2", "alias": "Lucia", "slot": 1}]
	var base: Dictionary = {"sala": "sala-coop", "jugadores": players, "nivel": 0, "semilla": 1, "start_ms": Time.get_ticks_msec() - 50, "modo": "coop"}
	Online.arena_match = base.duplicate(true)
	Online.arena_match["yo"] = "aaaaaaaaaaaaaaa1"
	var a: Node = await start_game(cfg, 0)
	Online.arena_match = base.duplicate(true)
	Online.arena_match["yo"] = "bbbbbbbbbbbbbbb2"
	var gb: Node = (load(UI.game_scene()) as PackedScene).instantiate()
	add_child(gb)
	await frames(3)
	var pa: BrawlFighter = a.get("player")
	var pb: BrawlFighter = gb.get("player")
	check("coop: los dos en el mismo equipo y sin bots en los huecos", pa.team == 0 and ((a.get("by_id") as Dictionary)["bbbbbbbbbbbbbbb2"] as BrawlFighter).team == 0
		and not (a.get("by_id") as Dictionary).has("bot2"))
	check("coop: oleada 1 con 3 bots en los dos juegos (los mueve el anfitrion)", int(a.call("rivals_left")) == 3 and int(gb.call("rivals_left")) == 3
		and not ((a.get("by_id") as Dictionary)["w1_0"] as BrawlFighter).remote and ((gb.get("by_id") as Dictionary)["w1_0"] as BrawlFighter).remote)
	## Sin fuego amigo
	var hp0: float = pb.hp
	pa.ammo = 3.0
	a.call("shoot", pa, (pb.position - pa.position).normalized())
	for k: int in 40:
		await get_tree().physics_frame
	check("coop: sin fuego amigo", is_equal_approx(pb.hp, hp0))
	check("coop: apunta solo a los bots", a.call("best_target", pa) == null or (a.call("best_target", pa) as BrawlFighter).team == 1)
	## El anfitrion acaba con cada oleada (en su juego); el otro la ve caer y le sale la siguiente.
	for w: int in [1, 2, 3]:
		var targets: Array = (a.get("fighters") as Array).filter(func(x: BrawlFighter) -> bool: return x.alive and x.team == 1)
		for f: BrawlFighter in targets:
			a.call("_hit_fighter", f, 999999.0, pa, Color.WHITE)
		for k: int in 30:
			await get_tree().physics_frame
		if w < 3:
			check("coop: sale la oleada %d en los dos juegos" % (w + 1), int(a.get("wave")) == w + 1 and int(gb.get("wave")) == w + 1
				and int(gb.call("rivals_left")) == 3 + w, "%d/%d" % [int(a.get("wave")), int(gb.get("wave"))])
	await frames(4)
	check("coop: tras la ultima oleada ganan los dos", int(a.get("placed")) == 1 and int(gb.get("placed")) == 1 and bool(a.get("reported")) and bool(gb.get("reported")))
	var ap: ArenaPanel = a.get_node_or_null("ArenaPanel") as ArenaPanel
	check("coop: ventana de victoria en equipo (sin trofeos)", ap != null and (ap.find_child("Info", true, false) as Label).text.contains("3"))
	gb.queue_free()
	await stop_game(a)
	Online.fake = Callable()
	Online.fake_net_latency = -1.0
	Online.arena_match = {}
	await frames(2)


func rhythm_config(extra: Dictionary) -> Dictionary:
	var cfg: Dictionary = base_config.duplicate(true)
	cfg["genre"] = "rhythm"
	var lv: Dictionary = {"name": "r", "map": ["....", "....", "....", "....", ".x..", "....", "x..x", "...x", "x...", ".x..", "....", ".x..", ".x..", "....", "x..x", "x...", "x...", ".x..", "....", ".x..", ".x..", "....", "..x.", "....", "..x.", "....", "..x.", "....", ".x..", "....", "..x.", "....", "..x.", "....", "..x.", "....", "...x", "x...", "....", "....", "...x", "....", "x...", "....", ".x..", "....", "..x.", "...x", "..x.", "x...", "..x.", "....", "....", "....", "..x.", "....", "..x.", "x...", "..xx", "....", "....", "....", "..x.", "....", "..x.", "x...", "...x", "....", "x...", "....", ".x..", "....", "...x", "...x", "...x", "....", "x...", "....", ".x..", "....", "...x", "...x", "...x", "....", "....", "....", "..x.", "....", "...x", "....", "...x", "...x", "....", "....", "..x.", "....", "...x", "....", "...x", "...x", "....", "....", "....", "...."], "bpm": 108, "speed": 902, "target": 0.67, "energy": 11}
	lv.merge(extra, true)
	cfg["levels"] = [lv]
	return cfg


## Ritmo: las notas bajan, tocarlas a tiempo suma, si se escapan baja la energia; el bot gana
## tocando con error humano y el analizador rechaza canciones injustas.
func _test_rhythm() -> void:
	print("- Ritmo")
	var game: Node = await start_game(rhythm_config({}), 0)
	check("ritmo: escena propia con bot y notas", game.has_method("bot_script") and (game.get("notes") as Array).size() >= 16)
	var first: Dictionary = (game.get("notes") as Array)[0]
	check("ritmo: tocar sin nota cerca no castiga", str(game.call("tap", (int(first["lane"]) + 1) % 4)) == "" and int(game.get("energy")) == int(game.get("energy_max")))
	game.set("time_in_level", float(first["t"]) - 0.02)
	check("ritmo: tocar a tiempo es perfecto", str(game.call("tap", int(first["lane"]))) == "perfect" and int(game.get("hits")) == 1)
	var e0: int = int(game.get("energy"))
	game.set("time_in_level", float(((game.get("notes") as Array)[1] as Dictionary)["t"]) + 0.5)
	await frames(2)
	check("ritmo: la nota que se escapa es un fallo y baja la energia", int(game.get("misses")) >= 1 and int(game.get("energy")) < e0)
	game.set("energy", 1)
	game.set("time_in_level", float(((game.get("notes") as Array)[(game.get("notes") as Array).size() - 1] as Dictionary)["t"]) + 0.5)
	await frames(3)
	check("ritmo: sin energia se pierde", bool(game.get("failed")) and game.get_node_or_null("FailPanel") != null)
	await stop_game(game)
	game = await start_game(rhythm_config({}), 0)
	var done: bool = await QaBot.run(get_tree(), game, 60 * 90)
	check("ritmo: el bot gana tocando como una persona", done and float(game.call("accuracy")) > 0.9, str(game.call("bot_state")))
	await stop_game(game)
	var MapRules: GDScript = load("res://kit/rhythm/rhythm_map.gd")
	check("ritmo: analizador acepta una cancion buena", bool(MapRules.analyze(rhythm_config({})["levels"][0])["completable"]),
		str(MapRules.analyze(rhythm_config({})["levels"][0])["issues"]))
	check("ritmo: 3 notas a la vez se rechazan", (MapRules.analyze({"map": ["xxx."].duplicate() + rhythm_config({})["levels"][0]["map"], "bpm": 110})["issues"] as Array).has("rhythm_chord"))
	check("ritmo: notas pegadas en el mismo carril se rechazan", (MapRules.analyze({"map": ["x...", "x..."] + rhythm_config({})["levels"][0]["map"], "bpm": 180})["issues"] as Array).has("rhythm_too_dense"))


func idle_config(extra: Dictionary) -> Dictionary:
	var cfg: Dictionary = base_config.duplicate(true)
	cfg["genre"] = "idle"
	var lv: Dictionary = {"name": "c", "map": ["15:1", "75:4.5", "375:20.2", "1875:91.1"], "duration": 81.0, "tap": 1.0, "target": 780.0}
	lv.merge(extra, true)
	cfg["levels"] = [lv]
	return cfg


## Clicker: tocar suma, los ayudantes ganan solos y cuestan cada vez mas, la moneda de oro da un
## empujon; el bot llega a la meta a tiempo y el analizador rechaza metas imposibles.
func _test_idle() -> void:
	print("- Clicker")
	var game: Node = await start_game(idle_config({}), 0)
	check("clicker: escena propia con bot y ayudantes", game.has_method("bot_script") and (game.get("helpers") as Array).size() >= 3)
	for k: int in 15:
		game.call("tap")
	check("clicker: tocar suma monedas", is_equal_approx(float(game.get("bank")), 15.0))
	var c0: float = float(game.call("helper_cost", 0))
	check("clicker: comprar un ayudante", bool(game.call("buy", 0)) and float(game.call("cps")) > 0.0 and float(game.call("helper_cost", 0)) > c0)
	check("clicker: sin dinero no se compra", not bool(game.call("buy", 2)))
	var e0: float = float(game.get("earned"))
	for k: int in 60:
		await get_tree().physics_frame
	check("clicker: los ayudantes ganan solos", float(game.get("earned")) > e0 + 0.5)
	game.set("time_in_level", float(game.get("duration")) - 0.01)
	await frames(3)
	check("clicker: sin tiempo se pierde", bool(game.get("failed")) and game.get_node_or_null("FailPanel") != null)
	await stop_game(game)
	game = await start_game(idle_config({}), 0)
	var done: bool = await QaBot.run(get_tree(), game, 60 * 200)
	check("clicker: el bot llega a la meta a tiempo", done, str(game.call("bot_state")))
	await stop_game(game)
	var MapRules: GDScript = load("res://kit/idle/idle_map.gd")
	var good: Dictionary = MapRules.analyze(idle_config({})["levels"][0])
	check("clicker: analizador acepta un nivel bueno", bool(good["completable"]), str(good["issues"]) + " " + str(good.get("sim_time")))
	check("clicker: meta imposible detectada", (MapRules.analyze(idle_config({"target": 99999999.0})["levels"][0])["issues"] as Array).has("idle_target_high"))
	check("clicker: meta que se saca solo tocando detectada", (MapRules.analyze(idle_config({"target": 50.0})["levels"][0])["issues"] as Array).has("idle_target_low"))


func cards_config(map: Array) -> Dictionary:
	var cfg: Dictionary = base_config.duplicate(true)
	cfg["genre"] = "cards"
	cfg["levels"] = [{"name": "cartas", "map": map}]
	return cfg


## Solitario: solo se juega una mas o una menos (K y A se tocan), el mazo da la vuelta a otra
## carta, sin jugadas ni mazo se pierde; el bot lo resuelve y el analizador exige solucion.
func _test_cards() -> void:
	print("- Cartas")
	var deal: Array = ["7Q96AT9", "JKQAAK7", "43KJA29", "64738Q8", "S33T664J2T7858255549JKQ"]
	var game: Node = await start_game(cards_config(deal), 0)
	check("cartas: escena propia con bot y 7 columnas", game.has_method("bot_script") and (game.get("cols") as Array).size() == 7)
	var mini: Array = ["2K9", "SAQ5"]
	game.queue_free()
	await frames(2)
	game = await start_game(cards_config(mini), 0)
	check("cartas: una mas que el monton se juega", bool(game.call("play", 0)) and int(game.get("top")) == 2)
	check("cartas: lo que no es vecino no se juega", not bool(game.call("play", 2)) and int(game.get("top")) == 2)
	check("cartas: el mazo da la vuelta a otra carta", bool(game.call("draw_stock")) and int(game.get("top")) == 12)
	check("cartas: la K y el A se tocan (Q -> K)", bool(game.call("play", 1)))
	game.call("draw_stock")
	await frames(2)
	check("cartas: sin mazo ni jugadas se pierde", bool(game.get("failed")) and game.get_node_or_null("FailPanel") != null)
	await stop_game(game)
	game = await start_game(cards_config(deal), 0)
	var done: bool = await QaBot.run(get_tree(), game, 60 * 60)
	check("cartas: el bot limpia la mesa", done and int(game.call("cards_left")) == 0, str(game.call("bot_state")))
	await stop_game(game)
	var MapRules: GDScript = load("res://kit/cards/cards_map.gd")
	var good: Dictionary = MapRules.analyze(cards_config(deal)["levels"][0])
	check("cartas: analizador acepta un reparto con solucion", bool(good["completable"]), str(good["issues"]))
	check("cartas: reparto sin solucion detectado", (MapRules.analyze({"map": ["KKKKKKK", "KKKKKKK", "S5555555555"]})["issues"] as Array).has("cards_unsolvable"))


func turns_config(extra: Dictionary) -> Dictionary:
	var cfg: Dictionary = base_config.duplicate(true)
	cfg["genre"] = "turns"
	var lv: Dictionary = {"name": "r", "map": ["S", "F", "B"], "hero_hp": 100.0, "hero_atk": 20.0, "potions": 2, "mult": 1.17}
	lv.merge(extra, true)
	cfg["levels"] = [lv]
	return cfg


## RPG por turnos: atacar, especial con energia, pocion y defensa; el jefe avisa del golpe doble;
## el bot gana pensando como una persona y el analizador rechaza niveles injustos.
func _test_turns() -> void:
	print("- RPG por turnos")
	var game: Node = await start_game(turns_config({"map": ["WW", "W"]}), 0)
	game.set("fast", true)
	check("rpg: escena propia con bot y su primera oleada", game.has_method("bot_script") and (TurnsLogic.alive(game.get("state")) as Array).size() == 2)
	check("rpg: el especial necesita energia", not bool(game.call("act", "special")))
	var e0: float = float(((game.get("state") as Dictionary)["enemies"] as Array)[0]["hp"])
	check("rpg: atacar", bool(game.call("act", "attack", 0)))
	for k: int in 120:
		await get_tree().physics_frame
		if bool(game.call("waiting_player")):
			break
	var st: Dictionary = game.get("state")
	check("rpg: atacar quita vida, da energia y luego atacan ellos", float((st["enemies"] as Array)[0]["hp"]) < e0 and int(st["energy"]) == 1
		and float(st["hp"]) < float(st["max_hp"]))
	var hp0: float = float(st["hp"])
	check("rpg: la pocion cura", bool(game.call("act", "heal")))
	for k: int in 120:
		await get_tree().physics_frame
		if bool(game.call("waiting_player")):
			break
	check("rpg: (cura mas de lo que le pegan)", float(st["hp"]) > hp0 - 1.0 and int(st["potions"]) == int(game.get("potions")) - 1)
	await stop_game(game)
	## El jefe avisa y defenderse reduce el golpe doble a la mitad.
	var bst: Dictionary = TurnsLogic.new_state(["B"], 100.0, 1.0, 0, 1.0)
	TurnsLogic.next_wave(bst)
	TurnsLogic.hero_act(bst, "attack", 0, null)
	TurnsLogic.enemies_act(bst, null)
	TurnsLogic.hero_act(bst, "attack", 0, null)
	var ev: Array = TurnsLogic.enemies_act(bst, null)
	check("rpg: el jefe avisa del golpe doble", TurnsLogic.heavy_coming(bst) and ev.any(func(x: Dictionary) -> bool: return str(x["type"]) == "charge"))
	var before: float = float(bst["hp"])
	TurnsLogic.hero_act(bst, "defend", -1, null)
	var heavy: Array = TurnsLogic.enemies_act(bst, null)
	check("rpg: defenderse del golpe doble lo deja en la mitad", str(heavy[0]["type"]) == "heavy" and is_equal_approx(before - float(bst["hp"]), 9.0))
	game = await start_game(turns_config({}), 0)
	game.set("fast", true)
	var done: bool = await QaBot.run(get_tree(), game, 60 * 240)
	check("rpg: el bot gana pensando como una persona", done, str(game.call("bot_state")))
	await stop_game(game)
	var MapRules: GDScript = load("res://kit/turns/turns_map.gd")
	var good: Dictionary = MapRules.analyze(turns_config({})["levels"][0])
	check("rpg: analizador acepta un nivel justo", bool(good["completable"]), str(good["issues"]) + str(good.get("sim")))
	check("rpg: nivel imposible detectado", (MapRules.analyze(turns_config({"map": ["BBB", "BBB"], "potions": 0})["levels"][0])["issues"] as Array).has("turns_too_hard"))


## Lo que lleva el juego (game.json -> features / kids): cada parte se apaga de verdad.
func _test_features() -> void:
	print("- Que lleva el juego")
	var keep: Dictionary = Kit.config.duplicate(true)
	Online.fake = func(_r: String, _p: Dictionary) -> Variant: return null
	Save.set_setting("online", true, false)
	Store.fake = true
	Notify.fake = true
	check("funciones: por defecto, todo encendido", Store.enabled() and Notify.available() and Online.available())
	Kit.config["features"] = {"tienda": false, "pase": false, "avisos": false, "nube": true, "online": true}
	check("funciones: sin tienda ni avisos", not Store.available() and not Notify.available() and Online.available())
	var title: Node = (load(UI.SCREEN_TITLE) as PackedScene).instantiate()
	add_child(title)
	await frames(2)
	check("funciones: sin pase no hay boton de misiones", title.find_child("BtnSeason", true, false) == null and title.find_child("BtnTorneo", true, false) != null)
	title.queue_free()
	Kit.config["features"] = {}
	Kit.config["kids"] = true
	check("ninos: sin compras, avisos ni online (pero si nube y eventos)", not Store.available() and not Notify.available()
		and not Online.available() and Online.backend())
	var host: Control = Control.new()
	add_child(host)
	var sp: SettingsPanel = SettingsPanel.open(host)
	await frames(2)
	check("ninos: en Ajustes no sale la clasificacion online", sp.find_child("BtnOnline", true, false) == null)
	host.queue_free()
	Kit.config = keep
	Store.fake = false
	Notify.fake = false
	Online.fake = Callable()
	await frames(2)


func _test_online() -> void:
	print("- Online")
	check("online: apodos validos", Online.clean_alias("  Dani  99 ") == "Dani 99" and Online.clean_alias("Pe\u00f1a") == "Pe\u00f1a")
	check("online: apodos malos", Online.clean_alias("ab") == "" and Online.clean_alias("p0ll4z") == "" and Online.clean_alias("<b>hola") == ""
		and Online.clean_alias("quinceletrasmass") == "")
	var cfg: Dictionary = test_config(["P..C..G", "#######"])
	cfg["levels"] = [cfg["levels"][0], cfg["levels"][0], cfg["levels"][0]]
	cfg["title"] = "Bigotes"
	cfg["share_url"] = "https://play.google.com/store/apps/details?id=com.orq.bigotes"
	Kit.set_config(cfg)
	var ch: Dictionary = Online.parse_challenge("?j=abc&reto=3480&n=2&de=Dani%20R")
	check("online: lee el reto de la URL", int(ch.get("score", 0)) == 3480 and int(ch.get("level", -1)) == 1 and str(ch.get("from", "")) == "Dani R", str(ch))
	check("online: reto de otro nivel no cuenta", Online.challenge_for(0).is_empty() and not Online.challenge_for(1).is_empty())
	check("online: reto con nivel imposible se ignora", Online.parse_challenge("?reto=10&n=9").is_empty() and Online.parse_challenge("?reto=x").is_empty())
	check("online: quita el reto viejo del enlace", Online._strip_challenge("https://a.b/jugar.html?j=1&reto=5&n=1&de=X") == "https://a.b/jugar.html?j=1")
	Save.set_setting("alias", "", false)
	var url: String = Online.share_url(0, 120)
	check("online: enlace del reto", url == "https://play.google.com/store/apps/details?id=com.orq.bigotes&reto=120&n=1", url)
	check("online: texto del reto", Online.challenge_text(0, 120).begins_with("Supera mis 120 puntos en el nivel 1 de Bigotes"), Online.challenge_text(0, 120))

	## Servidor falso: guarda lo enviado y devuelve una lista.
	var sent: Array = []
	Online.fake = func(rpc: String, payload: Dictionary) -> Variant:
		sent.append([rpc, payload])
		if rpc == "marcador_enviar":
			return {"posicion": 2, "mejor": int(payload["p_puntos"])}
		return [{"posicion": 1, "alias": "Lucia", "puntos": 900, "tuyo": false},
			{"posicion": 2, "alias": Online.alias(), "puntos": 500, "tuyo": true}]
	Save.set_setting("online", true, false)
	Online.parse_challenge("?reto=3480&n=2&de=Dani%20R")
	Kit.level_index = 1
	var rp: ResultPanel = ResultPanel.open(self, {"stars": 3, "coins": 1, "coins_total": 1, "score": 500, "record": true, "no_reward": true})
	await frames(3)
	check("online: el resultado muestra clasificacion y retar", rp.find_child("BtnLeaderboard", true, false) != null and rp.find_child("BtnChallenge", true, false) != null)
	var chl: Label = rp.find_child("Challenge", true, false) as Label
	check("online: dice si has superado el reto", chl != null and chl.text.contains("Dani R") and chl.text.contains("2981"), chl.text if chl != null else "sin texto")
	check("online: sin apodo no se envia nada", sent.is_empty())
	(rp.find_child("BtnLeaderboard", true, false) as Button).pressed.emit()
	await frames(3)
	var lb: LeaderboardPanel = find_child("LeaderboardPanel", true, false) as LeaderboardPanel
	check("online: la clasificacion pide apodo la primera vez", lb != null and lb.find_child("AliasEdit", true, false) != null)
	if lb != null:
		(lb.find_child("AliasEdit", true, false) as LineEdit).text = "p0lla"
		(lb.find_child("BtnAlias", true, false) as Button).pressed.emit()
		await frames(2)
		check("online: apodo malo rechazado", Online.alias() == "" and sent.is_empty())
		(lb.find_child("AliasEdit", true, false) as LineEdit).text = "Zorro Rojo"
		(lb.find_child("BtnAlias", true, false) as Button).pressed.emit()
		await frames(4)
		check("online: con apodo sube la marca y carga la lista", Online.alias() == "Zorro Rojo" and sent.size() == 2
			and str(sent[0][0]) == "marcador_enviar" and int((sent[0][1] as Dictionary)["p_puntos"]) == 500 and int((sent[0][1] as Dictionary)["p_nivel"]) == 1
			and str((sent[0][1] as Dictionary)["p_sesion"]).length() == 16, str(sent))
		check("online: la lista se ve con tu fila", lb.find_child("Row1", true, false) != null and lb.find_child("Row2", true, false) != null)
		lb.close()
	rp.queue_free()
	await frames(2)
	sent.clear()
	rp = ResultPanel.open(self, {"stars": 1, "coins": 0, "coins_total": 1, "score": 200, "no_reward": true})
	await frames(3)
	check("online: con apodo, el resultado envia la marca solo", sent.size() == 1 and str(sent[0][0]) == "marcador_enviar", str(sent))
	rp.queue_free()
	## Apagar la clasificacion en Ajustes borra el apodo.
	Kit.config["telemetry"] = {"url": "https://x.supabase.co", "key": "k", "game": "g"}
	Save.set_setting("telemetry", false, false)
	var sp: SettingsPanel = SettingsPanel.open(self)
	await frames(2)
	var tog: Button = sp.find_child("BtnOnline", true, false) as Button
	check("online: interruptor en ajustes", tog != null)
	if tog != null:
		tog.button_pressed = false
		check("online: apagar borra el apodo y no se ofrece", Online.alias() == "" and not Online.available())
	sp.queue_free()
	Kit.config.erase("telemetry")
	Save.set_setting("telemetry", true, false)
	Save.set_setting("online", true, false)
	Online.fake = Callable()
	Online.challenge = {}
	Kit.level_index = 0
	await frames(2)
	check("online: sin servidor en game.json no hay clasificacion", not Online.available())


## Historia entre niveles (kit/story.gd + DialogPanel): intro con el juego en pausa, final
## encima del resultado, una sola vez por nivel, retratos del arte del juego y apagable.
## Pieza falsa: marco claro y centro del color pedido.
func _fake_piece(path: String, w: int, h: int, center: Color) -> void:
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color("#c98a3c"))
	var m: int = int(h * 0.24)
	img.fill_rect(Rect2i(m, m, w - 2 * m, h - 2 * m), center)
	img.save_png(path)


func _test_look_skin() -> void:
	print("- Acabado: fondo de nivel e interfaz dibujada")
	DirAccess.make_dir_recursive_absolute("user://t_skin")
	var old_assets: Dictionary = Kit.assets.duplicate(true)
	## 1 - Fondo ilustrado detras del nivel.
	var bg: Image = Image.create(64, 112, false, Image.FORMAT_RGB8)
	bg.fill(Color("#3a6ea5"))
	bg.save_png("user://t_skin/fondo_nivel.png")
	var ui_cfg: Dictionary = (Kit.assets.get("ui", {}) as Dictionary).duplicate(true)
	ui_cfg["fondo_nivel"] = "user://t_skin/fondo_nivel.png"
	Kit.assets["ui"] = ui_cfg
	var game: Node = await start_game(test_config(["..........", "P...C...G.", "##########"]), 0)
	await frames(4)
	var bd: Node = game.get_node_or_null("LevelBackdrop")
	check("fondo de nivel: se pone detras del juego", bd != null and (bd as CanvasLayer).layer < 0)
	check("fondo de nivel: lleva el arte y el velo", bd != null and (bd.get_node("Art") as TextureRect).texture != null and bd.get_node_or_null("Veil") != null)
	var grade: CanvasLayer = game.get_node_or_null("Grade") as CanvasLayer
	check("etalonaje: encima del juego y debajo del HUD", grade != null and grade.layer > 0 and grade.layer < 20)
	Look.set_high(false)
	await frames(2)
	check("etalonaje: graficos bajos lo quitan al momento", game.get_node_or_null("Grade") == null)
	Look.set_high(true)
	await frames(1)
	check("etalonaje: graficos altos lo vuelven a poner", game.get_node_or_null("Grade") != null)
	## Efectos: un golpe grande trae chispas y onda expansiva.
	var fxp: Node2D = Node2D.new()
	add_child(fxp)
	Juice.burst(fxp, Vector2(100, 100), Color.ORANGE, 16, 300.0)
	check("efectos: trozos, chispas y onda", fxp.get_child_count() == 3 and fxp.get_node_or_null("Sparkle") != null and fxp.get_node_or_null("Shockwave") != null)
	fxp.queue_free()
	await stop_game(game)
	ui_cfg.erase("fondo_nivel")
	Kit.assets["ui"] = ui_cfg
	game = await start_game(test_config(["..........", "P...C...G.", "##########"]), 0)
	await frames(4)
	check("fondo de nivel: sin arte no se pone nada", game.get_node_or_null("LevelBackdrop") == null)
	await stop_game(game)
	## 2 - Piel buena: centros con los colores de la interfaz -> se aplica.
	UI.rebuild("")
	var c: Dictionary = UI.colors
	_fake_piece("user://t_skin/panel.png", 200, 200, c["panel"])
	_fake_piece("user://t_skin/boton.png", 200, 100, c["panel_hi"])
	_fake_piece("user://t_skin/boton_primario.png", 200, 100, c["acento"])
	ui_cfg["skin"] = {"panel": "user://t_skin/panel.png", "boton": "user://t_skin/boton.png",
		"boton_primario": "user://t_skin/boton_primario.png", "margen_panel": 48, "margen_boton": 24}
	Kit.assets["ui"] = ui_cfg
	UI.rebuild("")
	check("piel: se aplican panel y botones", UI.skin_used == ["panel", "boton", "boton_primario"], str(UI.skin_used))
	var sb: StyleBox = UI.theme.get_stylebox("normal", "Button")
	check("piel: el boton usa la textura", sb is StyleBoxTexture)
	if sb is StyleBoxTexture:
		var st: StyleBoxTexture = sb as StyleBoxTexture
		check("piel: el texto va dentro del marco", st.content_margin_left >= st.texture_margin_left and st.content_margin_top >= st.texture_margin_top * 0.7,
			"%.0f/%.0f" % [st.content_margin_left, st.texture_margin_left])
	## 3 - Piel ilegible: el centro del boton es del color del texto -> se rechaza esa pieza.
	_fake_piece("user://t_skin/boton.png", 200, 100, c["texto"])
	UI.rebuild("")
	check("piel: pieza ilegible rechazada, el resto se queda", not UI.skin_used.has("boton") and UI.skin_used.has("panel"), str(UI.skin_used))
	check("piel: el boton rechazado vuelve al de siempre", UI.theme.get_stylebox("normal", "Button") is StyleBoxFlat)
	## 4 - Los perfiles forzados (pruebas de estilo) nunca llevan piel.
	UI.rebuild("pixel")
	check("piel: perfil forzado sin piel", UI.skin_used.is_empty())
	Kit.assets = old_assets
	UI.rebuild("")


func _test_story() -> void:
	print("- Historia")
	var cfg: Dictionary = test_config(["..........", "P...C...G.", "##########"])
	cfg["story"] = {"cast": {"heroe": {"name": "Bigotes", "sprite": "heroe"}, "rival": {"name": "Chatarrilla"}, "narrador": {"name": ""}},
		"levels": [{"intro": [{"who": "narrador", "text": "Era una noche de tormenta en los tejados."},
			{"who": "heroe", "text": "Esta noche recupero mis sardinas!"}, {"who": "rival", "text": "Ni lo sue\u00f1es, gatito."}],
			"outro": [{"who": "heroe", "text": "Primera azotea, conseguida."}]}]}
	Save.set_setting("story_seen", {}, false)
	Save.set_setting("story", true, false)
	Story.force = true
	var game: Node = await start_game(cfg, 0)
	await frames(3)
	var dlg: DialogPanel = Story.current
	check("historia: la intro sale al empezar y el juego espera", dlg != null and get_tree().paused)
	if dlg != null:
		check("historia: el narrador no lleva nombre", (dlg.find_child("Name", true, false) as Label).visible == false)
		dlg.advance()
		await frames(2)
		check("historia: habla el heroe con su nombre", (dlg.find_child("Name", true, false) as Label).text == "Bigotes")
		check("historia: retrato del heroe con su arte", (dlg.find_child("Portrait", true, false) as TextureRect).texture != null,
			str(Kit.sprite_entry("heroe").keys()))
		dlg.advance()
		await frames(2)
		var tx: Label = dlg.find_child("Text", true, false) as Label
		check("historia: el texto se escribe poco a poco", tx.visible_characters >= 0 and tx.visible_characters < tx.get_total_character_count())
		dlg.advance()
		await frames(2)
	check("historia: al acabar se cierra y el juego sigue", Story.current == null and not get_tree().paused)
	await stop_game(game)
	game = await start_game(cfg, 0)
	await frames(3)
	check("historia: la intro no se repite al reintentar", Story.current == null and not get_tree().paused)
	var done: bool = await QaBot.run(get_tree(), game, 60 * 30)
	await frames(3)
	check("historia: el final sale encima del resultado", done and Story.current != null and game.get_node_or_null("ResultPanel") != null)
	if Story.current != null:
		(Story.current.find_child("BtnSkip", true, false) as Button).pressed.emit()
		await frames(2)
	check("historia: saltar lo cierra", Story.current == null)
	await stop_game(game)
	## Apagada en Ajustes: no sale nada; al encenderla de nuevo se ve desde el principio.
	Save.set_setting("story", false, false)
	Story.reset_seen()
	game = await start_game(cfg, 0)
	await frames(3)
	check("historia: apagada no sale", Story.current == null)
	await stop_game(game)
	Save.set_setting("story", true, false)
	Story.force = false
	game = await start_game(cfg, 0)
	await frames(3)
	check("historia: nunca en los bots sin pantalla", Story.current == null and not get_tree().paused)
	await stop_game(game)
	Save.set_setting("story_seen", {}, false)


## Naves: matamarcianos vertical (escena propia, disparo automatico, golpes, jefe y analizador).
func shooter_waves(n: int, with_boss: bool) -> Array:
	var rows: Array = [".......", ".......", "...W..."]
	for i: int in n:
		rows.append(["..EEE..", "Z.....Z", ".T...T.", "...A...", "..C.C.."][i % 5])
		rows.append(".......")
		rows.append(".......")
	if with_boss:
		rows.append("...B...")
	return rows


func shooter_config(rows: Array) -> Dictionary:
	var cfg: Dictionary = base_config.duplicate(true)
	cfg["genre"] = "shooter"
	cfg["levels"] = [{"name": "oleadas", "map": rows, "row_time": 0.8, "enemy_speed": 1.0, "fire_rate": 1.0}]
	return cfg


func _test_shooter() -> void:
	print("- Naves")
	var game: Node = await start_game(shooter_config(shooter_waves(10, false)), 0)
	check("naves: escena propia con bot", game.has_method("bot_script") and str(game.call("bot_script")).ends_with("shooter_bot.gd"))
	await frames(90)
	check("naves: dispara sola", (game.get("shots") as Array).size() > 0)
	check("naves: entran oleadas", int(game.get("next_row")) >= 2, str(game.get("next_row")))
	var hp0: int = game.get("hp")
	game.set("invuln", 0.0)
	game.call("_bullet", Vector2(float(game.get("player_x")), 1000.0), Vector2(0, 1))
	await frames(12)
	check("naves: una bala quita un corazon", int(game.get("hp")) == hp0 - 1, "hp=%d" % int(game.get("hp")))
	check("naves: invulnerable un momento tras el golpe", float(game.get("invuln")) > 0.5)
	game.set("weapon", 1)
	(game.get("pickups") as Array).append({"kind": "W", "pos": Vector2(float(game.get("player_x")), 1040.0), "node": Node2D.new()})
	await frames(3)
	check("naves: la mejora sube el arma", int(game.get("weapon")) == 2)
	await stop_game(game)

	game = await start_game(shooter_config(shooter_waves(12, true)), 0)
	var done: bool = await QaBot.run(get_tree(), game, 60 * 150)
	var st: Dictionary = game.call("bot_state")
	check("naves: el bot derriba al jefe y gana", done and int(st["deaths"]) <= 1, "muertes=%d golpes=%d progreso=%.2f" % [int(st["deaths"]), int(st["hits"]), float(st["progress"])])
	check("naves: derriba enemigos", int(st["stomps"]) >= 10, str(st["stomps"]))
	await stop_game(game)

	var MapRules: GDScript = load("res://kit/shooter/shooter_map.gd")
	var ok: Dictionary = MapRules.call("analyze", {"map": shooter_waves(10, true)})
	check("naves: oleadas buenas", bool(ok["completable"]), str(ok["issues"]))
	var wall: Array = shooter_waves(10, false)
	wall[8] = "AAAAA.."
	check("naves: muro de rocas detectado", (MapRules.call("analyze", {"map": wall})["issues"] as Array).has("shooter_wall"))
	var hell: Array = shooter_waves(10, false)
	hell[5] = "EEE.TT."
	hell[6] = "EE....."
	check("naves: lluvia de balas detectada", (MapRules.call("analyze", {"map": hell})["issues"] as Array).has("shooter_bullet_hell"))
	var hot: Array = shooter_waves(10, false)
	hot[0] = "...E..."
	check("naves: salida en caliente detectada", (MapRules.call("analyze", {"map": hot})["issues"] as Array).has("shooter_hot_start"))
	check("naves: es estricto y pide arte de enemigos", Genres.strict("shooter") and Genres.enemy_art("shooter"))


## Rompebloques: pala, pelota, ladrillos duros, acero, mejoras y analizador.
func breakout_wall() -> Array:
	return ["1.1.1.1.1", ".2.C.2.L.", "1.1.M.1.1", "#.1.1.1.#", "111111111"]


func breakout_config(rows: Array) -> Dictionary:
	var cfg: Dictionary = base_config.duplicate(true)
	cfg["genre"] = "breakout"
	cfg["levels"] = [{"name": "muro", "map": rows, "ball_speed": 1.0}]
	return cfg


func _test_breakout() -> void:
	print("- Rompebloques")
	var game: Node = await start_game(breakout_config(breakout_wall()), 0)
	check("rompebloques: escena propia con bot", game.has_method("bot_script") and str(game.call("bot_script")).ends_with("breakout_bot.gd"))
	check("rompebloques: la pelota espera en la pala", bool(game.get("held")))
	var n0: int = int(game.call("breakable_left"))
	check("rompebloques: cuenta los ladrillos (sin el acero)", n0 == 26, str(n0))
	game.call("launch")
	check("rompebloques: toca y sale hacia arriba", not bool(game.get("held")) and ((game.get("balls") as Array)[0]["vel"] as Vector2).y < 0.0)
	await frames(240)
	check("rompebloques: rompe ladrillos", int(game.call("breakable_left")) < n0, "%d de %d" % [int(game.call("breakable_left")), n0])
	## Perder la pelota quita una vida y deja otra en la pala.
	var l0: int = game.get("lives")
	var una: Array[Dictionary] = [{"pos": Vector2(360.0, 1300.0), "vel": Vector2(0.0, 600.0)}]
	game.set("balls", una)
	game.set("held", false)
	await frames(12)
	check("rompebloques: caer quita una vida", int(game.get("lives")) == l0 - 1 and bool(game.get("held")))
	(game.get("drops") as Array).append({"kind": "L", "pos": Vector2(float(game.get("paddle_x")), 1105.0)})
	await frames(2)
	check("rompebloques: la mejora ensancha la pala", float(game.get("paddle_w")) > 200.0)
	await stop_game(game)

	game = await start_game(breakout_config(breakout_wall()), 0)
	var done: bool = await QaBot.run(get_tree(), game, 60 * 240)
	var st: Dictionary = game.call("bot_state")
	check("rompebloques: el bot rompe todo", done and int(st["deaths"]) == 0, "quedan=%d vidas_perdidas=%d" % [int(st["left"]), int(st["lives_lost"])])
	await stop_game(game)

	var MapRules: GDScript = load("res://kit/breakout/breakout_map.gd")
	check("rompebloques: muro bueno", bool(MapRules.call("analyze", {"map": breakout_wall()})["completable"]))
	var cerrado: Array = ["111111111", "#########", "111111111"]
	check("rompebloques: fila de acero detectada", (MapRules.call("analyze", {"map": cerrado})["issues"] as Array).has("breakout_steel_wall"))
	var encerrado: Array = ["#1#111111", "###111111", "111111111"]
	check("rompebloques: ladrillo encerrado detectado", (MapRules.call("analyze", {"map": encerrado})["issues"] as Array).has("breakout_unreachable"))


## Bloques: encajar piezas, limpiar lineas y gemas, sin hueco = fin, y analizador.
func blocks_config(rows: Array, extra: Dictionary) -> Dictionary:
	var cfg: Dictionary = base_config.duplicate(true)
	cfg["genre"] = "blocks"
	var lv: Dictionary = {"name": "tablero", "map": rows, "seed": 77, "lines": 6, "par": 24, "big": 0.4}
	lv.merge(extra, true)
	cfg["levels"] = [lv]
	return cfg


func _test_blocks() -> void:
	print("- Bloques")
	var vacio: Array = ["........", "........", "........", "........", "........", "........", "........", "........"]
	var game: Node = await start_game(blocks_config(vacio, {}), 0)
	check("bloques: escena propia con bot", game.has_method("bot_script") and str(game.call("bot_script")).ends_with("blocks_bot.gd"))
	var tray: Array = game.get("tray")
	check("bloques: bandeja con 3 piezas", tray.size() == 3 and tray.all(func(t: int) -> bool: return t >= 0))
	## Fila casi llena + una pieza de 1 = linea limpiada.
	var b: Array = game.get("board")
	for x: int in 7:
		b[0][x] = 1
	(game.get("tray") as Array)[0] = 0
	var n: int = game.call("place", 0, Vector2i(7, 0))
	check("bloques: una fila llena se limpia", n == 1 and int(game.get("lines")) == 1 and int(b[0][0]) == 0)
	check("bloques: no se puede poner encima", int(game.call("place", 1, Vector2i(-1, 0))) == -1)
	await stop_game(game)

	var orden_a: Array = []
	game = await start_game(blocks_config(vacio, {}), 0)
	orden_a = (game.get("tray") as Array).duplicate()
	game.call("retry")
	check("bloques: mismas piezas al repetir (justo para todos)", (game.get("tray") as Array) == orden_a)
	await stop_game(game)

	var gemas: Array = ["...G....", "........", "..##....", "......G.", "........", ".G......", "....#...", "........"]
	game = await start_game(blocks_config(gemas, {}), 0)
	check("bloques: cuenta las gemas", int(game.get("gems_left")) == 3)
	var done: bool = await QaBot.run(get_tree(), game, 60 * 60)
	var st: Dictionary = game.call("bot_state")
	check("bloques: el bot libera las gemas", done and int(st["deaths"]) <= 1, "gemas=%d piezas=%d muertes=%d" % [int(st["gems_left"]), int(st["used"]), int(st["deaths"])])
	await stop_game(game)

	game = await start_game(blocks_config(vacio, {"lines": 10}), 0)
	done = await QaBot.run(get_tree(), game, 60 * 60)
	check("bloques: el bot limpia 10 lineas", done and int(game.get("lines")) >= 10, str(game.get("lines")))
	await stop_game(game)

	var MapRules: GDScript = load("res://kit/blocks/blocks_map.gd")
	check("bloques: tablero bueno", bool(MapRules.call("analyze", {"map": gemas, "par": 20})["completable"]))
	var lleno: Array = gemas.duplicate()
	lleno[1] = "########"
	check("bloques: linea llena al empezar detectada", (MapRules.call("analyze", {"map": lleno, "par": 20})["issues"] as Array).has("blocks_full_line"))
	check("bloques: sin objetivo detectado", (MapRules.call("analyze", {"map": vacio, "lines": 0, "par": 20})["issues"] as Array).has("blocks_no_goal"))


## Corredor 3D: carriles, salto, agacharse, trenes, vista 3D y analizador.
func lanes_track(n: int) -> Array:
	var rows: Array = [".....", "...", "...", "...", "..."]
	rows = ["...", "...", "...", "...", "..."]
	var pat: Array = ["WW.", "...", "...", ".B.", "...", "...", "..H", "...", "...", ".CC", ".CC", "...", "W.W", "...", "...", "B..", "...", "..."]
	while rows.size() < n:
		rows.append(pat[rows.size() % pat.size()])
	return rows


func lanes_config(rows: Array) -> Dictionary:
	var cfg: Dictionary = base_config.duplicate(true)
	cfg["genre"] = "lanes"
	cfg["levels"] = [{"name": "via", "map": rows, "speed": 11.0, "ramp": 0.2}]
	return cfg


func _test_lanes() -> void:
	print("- Corredor 3D")
	var game: Node = await start_game(lanes_config(lanes_track(80)), 0)
	var v3: Node = game.get("view3d")
	check("corredor: vista 3D con camara y heroe", v3 != null and v3.get_node_or_null("Camera3D") != null and v3.get_node_or_null("Hero") != null)
	await frames(180)
	check("corredor: corre solo tras la cuenta atras", bool(game.get("started")) and float(game.get("d")) > 3.0)
	check("corredor: cambia de carril", bool(game.call("move_lane", -1)) and int(game.get("lane")) == 0)
	game.call("move_lane", 1)
	check("corredor: salta", bool(game.call("jump")))
	await frames(18)
	check("corredor: en el aire", float(game.call("height")) > 0.8, "%.2f" % float(game.call("height")))
	await stop_game(game)
	## Valla sin saltar = choque.
	var choque: Array = ["...", "...", "...", "...", ".B."]
	while choque.size() < 70:
		choque.append("...")
	game = await start_game(lanes_config(choque), 0)
	for k: int in 60 * 6:
		await get_tree().physics_frame
		if int(game.get("hits")) > 0:
			break
	check("corredor: la valla sin saltar es un choque", int(game.get("hits")) == 1 and int(game.get("hp")) == int(game.get("max_hp")) - 1)
	await stop_game(game)

	game = await start_game(lanes_config(lanes_track(90)), 0)
	var done: bool = await QaBot.run(get_tree(), game, 60 * 120)
	var st: Dictionary = game.call("bot_state")
	check("corredor: el bot llega a la meta sin chocar", done and int(st["hits"]) == 0 and int(st["deaths"]) == 0, "choques=%d muertes=%d progreso=%.2f" % [int(st["hits"]), int(st["deaths"]), float(st["progress"])])
	check("corredor: recoge monedas", int(st["coins"]) >= 6, str(st["coins"]))
	await stop_game(game)

	var MapRules: GDScript = load("res://kit/lanes/lanes_map.gd")
	check("corredor: via buena", bool(MapRules.call("analyze", {"map": lanes_track(90)})["completable"]), str(MapRules.call("analyze", {"map": lanes_track(90)})["issues"]))
	var muro: Array = lanes_track(90)
	muro[30] = "WWW"
	check("corredor: muro de trenes detectado", (MapRules.call("analyze", {"map": muro})["issues"] as Array).has("lanes_wall"))
	var zig: Array = lanes_track(90)
	zig[40] = "WW."
	zig[42] = ".WW"
	zig[41] = "..."
	check("corredor: cambio imposible detectado", (MapRules.call("analyze", {"map": zig})["issues"] as Array).has("lanes_blocked") or (MapRules.call("analyze", {"map": zig})["issues"] as Array).has("lanes_too_close"))


## Serpiente: crecer, girar, chocar, bot seguro y analizador.
func snake_board() -> Array:
	return ["###########", "#.........#", "#.........#", "#..##.##..#", "#....C....#", "#.........#", "#..#####..#",
		"#.........#", "#....C....#", "#.........#", "#.....##..#", "#....S....#", "#.........#", "#.........#", "###########"]


func jumper_config(rows: Array) -> Dictionary:
	var cfg: Dictionary = base_config.duplicate(true)
	cfg["genre"] = "jumper"
	cfg["levels"] = [{"name": "torre", "map": rows}]
	return cfg


## Saltos: rebote, lados que se tocan, plataformas que se rompen, muelle, caida, bot y analizador.
func _test_jumper() -> void:
	print("- Saltos")
	var rows: Array = ["....G....", ".........", "....=....", ".........", "...=.....", "....C....", "....=....", ".........", "....P...."]
	var game: Node = await start_game(jumper_config(rows), 0)
	check("saltos: escena propia con bot", game.has_method("bot_script"))
	var y0: float = (game.get("pos") as Vector2).y
	await frames(20)
	check("saltos: rebota solo hacia arriba", (game.get("pos") as Vector2).y < y0 - 100.0)
	game.set("pos", Vector2(-5.0, (game.get("pos") as Vector2).y))
	await frames(2)
	check("saltos: salir por un lado es entrar por el otro", (game.get("pos") as Vector2).x > 600.0)
	await stop_game(game)
	game = await start_game(jumper_config(rows), 0)
	var done: bool = await QaBot.run(get_tree(), game, 60 * 40)
	check("saltos: el bot llega a la meta", done, str(game.call("bot_state")))
	await stop_game(game)
	## Caer por debajo de la pantalla cuenta como caida y vuelve a empezar.
	game = await start_game(jumper_config(rows), 0)
	game.set("pos", Vector2(360.0, 2000.0))
	game.set("vel", Vector2(0.0, 500.0))
	await frames(3)
	check("saltos: caer es volver a empezar", int(game.get("deaths")) == 1)
	await stop_game(game)
	var MapRules: GDScript = load("res://kit/jumper/jumper_map.gd")
	check("saltos: analizador acepta un nivel bueno", bool(MapRules.analyze({"map": rows})["completable"]))
	var gap: Array = ["....G....", ".........", ".........", ".........", ".........", ".........", "....P...."]
	check("saltos: hueco imposible detectado", (MapRules.analyze({"map": gap})["issues"] as Array).has("jumper_unreachable"))
	var spring: Array = gap.duplicate()
	spring[6] = "....P..^."
	spring[5] = "........."
	check("saltos: el muelle salva huecos grandes", bool(MapRules.analyze({"map": ["....G....", ".........", ".........", ".........", ".........", ".........", ".....^...", "....P...."]})["completable"]))


func moles_config(extra: Dictionary) -> Dictionary:
	var cfg: Dictionary = base_config.duplicate(true)
	cfg["genre"] = "moles"
	var lv: Dictionary = {"name": "huerto", "map": ["ooo", "ooo", "ooo"], "duration": 40.0, "interval": 0.8, "pop": 1.2, "max_up": 2, "friend": 0.15, "target": 18}
	lv.merge(extra, true)
	cfg["levels"] = [lv]
	return cfg


## Topos: golpe, heroe prohibido, tiempo, bot y analizador.
func _test_moles() -> void:
	print("- Topos")
	var game: Node = await start_game(moles_config({"friend": 0.0}), 0)
	check("topos: escena propia con bot", game.has_method("bot_script"))
	for k: int in 120:
		await get_tree().physics_frame
		if not (game.get("up") as Dictionary).is_empty():
			break
	var h: int = int((game.get("up") as Dictionary).keys()[0]) if not (game.get("up") as Dictionary).is_empty() else -1
	var kind: String = str((game.get("up") as Dictionary)[h]["kind"]) if h >= 0 else ""
	if kind == "spiky":
		game.call("bonk", h)
	game.call("bonk", h)
	check("topos: aplastar suma un golpe", h >= 0 and int(game.get("hits")) == 1, kind)
	await stop_game(game)
	game = await start_game(moles_config({"friend": 1.0}), 0)
	for k: int in 120:
		await get_tree().physics_frame
		if not (game.get("up") as Dictionary).is_empty():
			break
	game.call("bonk", int((game.get("up") as Dictionary).keys()[0]))
	check("topos: aplastar al heroe quita un corazon", int(game.get("hearts")) == 2 and int(game.get("hits")) == 0)
	game.set("time_left", 0.01)
	await frames(3)
	check("topos: sin tiempo se pierde", bool(game.get("failed")) and game.get_node_or_null("FailPanel") != null)
	await stop_game(game)
	game = await start_game(moles_config({}), 0)
	var done: bool = await QaBot.run(get_tree(), game, 60 * 60)
	check("topos: el bot gana sin tocar al heroe", done and int(game.get("hearts")) == 3, str(game.call("bot_state")))
	await stop_game(game)
	var MapRules: GDScript = load("res://kit/moles/moles_map.gd")
	check("topos: analizador acepta un nivel bueno", bool(MapRules.analyze(moles_config({})["levels"][0])["completable"]))
	check("topos: objetivo imposible detectado", (MapRules.analyze(moles_config({"target": 80})["levels"][0])["issues"] as Array).has("moles_target_high"))


func brawl_config(map: Array, extra: Dictionary) -> Dictionary:
	var cfg: Dictionary = base_config.duplicate(true)
	cfg["genre"] = "brawl"
	var lv: Dictionary = {"name": "arena", "map": map, "rival_hp": 2200, "rival_dmg": 0.6, "aim": 0.3, "reaction": 0.65,
		"gas_start": 47, "gas_time": 44, "par": 65}
	lv.merge(extra, true)
	cfg["levels"] = [lv]
	return cfg


func brawl_arena() -> Array:
	return [".............", "......R......", ".R...........", ".............", "**.........**", "**B.......B**",
		"**B.......B**", "...#.....#...", "...##...##...", "**.#.....#.**", "**.#.....#.**", ".**.......**.",
		".**.......**.", ".**#.....#**.", "####.....####", ".............", ".............", "......P......", "............."]


## Arena: disparo con apuntado, cajas y cubos, arbustos, gas, derrota, bot y analizador.
func _test_brawl() -> void:
	print("- Arena")
	var duel: Array = [".........", ".........", "....R....", ".........", ".........", ".........", ".........", "....P....", ".........", ".........", "........."]
	var game: Node = await start_game(brawl_config(duel, {"aim": 0.5, "reaction": 5.0}), 0)
	check("arena: escena propia con bot", game.has_method("bot_script") and str(game.call("bot_script")).ends_with("brawl_bot.gd"))
	var me: BrawlFighter = game.get("player")
	var foe: BrawlFighter = (game.get("fighters") as Array)[1]
	await frames(2)
	check("arena: el ataque apunta solo al rival", game.get("aim_target") == foe)
	var hp0: float = foe.hp
	game.call("attack")
	check("arena: atacar gasta una carga", me.ammo < 2.5 and not (game.get("bullets") as Array).is_empty())
	for k: int in 40:
		await get_tree().physics_frame
	check("arena: la rafaga hace dano y carga el super", foe.hp < hp0 and me.super_charge > 0.0, "%.0f -> %.0f" % [hp0, foe.hp])
	me.super_charge = 1.0
	check("arena: el super sale con la carga llena", bool(game.call("use_super")) and me.super_charge == 0.0)
	await stop_game(game)
	## Cajas, cubos y arbusto.
	var boxed: Array = [".........", "....R....", ".........", ".........", ".........", "....B....", ".........", "....P....", ".........", "**.......", "**......."]
	game = await start_game(brawl_config(boxed, {"reaction": 9.0}), 0)
	me = game.get("player")
	var box_cell: Vector2i = Vector2i(4, 5)
	for k: int in 8:
		me.ammo = 3.0
		game.call("shoot", me, Vector2.UP)
		for j: int in 12:
			await get_tree().physics_frame
		if not (game.get("boxes") as Dictionary).has(box_cell):
			break
	check("arena: la caja se rompe y suelta un cubo", not (game.get("boxes") as Dictionary).has(box_cell) and (game.get("cubes") as Array).size() == 1)
	me.position = game.call("center_of", box_cell)
	for k: int in 40:
		await get_tree().physics_frame
	check("arena: el cubo da poder (mas vida y dano)", me.power == 1 and me.damage > 300.0 and int(game.get("coins")) == 1)
	var rv: BrawlFighter = (game.get("fighters") as Array)[1]
	rv.position = game.call("center_of", Vector2i(0, 9))
	rv.reveal = 0.0
	await frames(3)
	check("arena: en el arbusto no se le ve de lejos", rv.in_bush and not bool(game.call("visible_to", me, rv)) and rv.modulate.a < 0.1,
		"%s %s %.2f %.2f" % [rv.in_bush, game.call("visible_to", me, rv), rv.modulate.a, rv.reveal])
	me.position = game.call("center_of", Vector2i(1, 8))
	await frames(3)
	check("arena: de cerca si", bool(game.call("visible_to", me, rv)))
	await stop_game(game)
	## Gas y derrota.
	game = await start_game(brawl_config(duel, {"gas_start": 0.0, "gas_time": 1.0, "reaction": 9.0}), 0)
	me = game.get("player")
	me.position = Vector2(20, 20)
	var hp1: float = me.hp
	await frames(20)
	check("arena: el gas quita vida fuera del circulo", me.hp < hp1)
	me.hit(99999.0)
	game.call("_on_death", me, null)
	await frames(3)
	check("arena: si te eliminan, panel de derrota", bool(game.get("failed")) and game.get_node_or_null("FailPanel") != null and int(game.get("deaths")) == 1)
	await stop_game(game)
	## El bot gana una arena de verdad.
	game = await start_game(brawl_config(brawl_arena(), {}), 0)
	var done: bool = await QaBot.run(get_tree(), game, 60 * 150)
	check("arena: el bot es el ultimo en pie", done and int(game.get("deaths")) == 0, str(game.call("bot_state")))
	await stop_game(game)
	var MapRules: GDScript = load("res://kit/brawl/brawl_map.gd")
	check("arena: analizador acepta la arena", bool(MapRules.analyze(brawl_config(brawl_arena(), {})["levels"][0])["completable"]),
		str(MapRules.analyze(brawl_config(brawl_arena(), {})["levels"][0])["issues"]))
	var walled: Array = brawl_arena().duplicate()
	walled[0] = "R#..........."
	walled[1] = "##....R......"
	check("arena: rival encerrado detectado", (MapRules.analyze(brawl_config(walled, {})["levels"][0])["issues"] as Array).has("brawl_unreachable"))
	check("arena: rivales infalibles detectados", (MapRules.analyze(brawl_config(brawl_arena(), {"aim": 0.0})["levels"][0])["issues"] as Array).has("brawl_aim_perfect"))


func brawl_ball_map() -> Array:
	return ["####.GGG.####", "......R......", "...R.....R...", ".............", "..**.....**..", "..**.###.**..",
		".............", "..#.......#..", "..#...O...#..", "..#.......#..", ".............", "..**.###.**..",
		"..**.....**..", ".............", "...A.....A...", "......P......", "####.ggg.####"]


func brawl_turret_map() -> Array:
	return [".............", "......t......", "...R..R..R...", ".............", "..**.....**..", "..**..#..**..",
		"...#.....#...", ".............", "...#.....#...", "..**..#..**..", "..**.....**..", ".............",
		"...A..P..A...", "......T......", "............."]


## Arena, modos y personajes: catalogo y desbloqueo, formas de disparar, supers, supervivencia,
## balon 3 contra 3, torretas 3 contra 3, reaparecer y analizador.
func _test_brawl_modes() -> void:
	print("- Arena: modos y personajes")
	var cat: Array[Dictionary] = Brawlers.catalog()
	check("personajes: 8 con nombre, disparo y super", cat.size() == 8 and str(cat[2]["attack"]) == "franco" and str(cat[1]["super"]) == "escudo")
	var t0: int = Chests.trophies()
	check("personajes: los dos primeros libres, el resto por trofeos", Brawlers.unlocked(cat[0]) and Brawlers.unlocked(cat[1]) and (t0 >= 1200 or not Brawlers.unlocked(cat[7])))
	check("personajes: no se elige uno bloqueado", t0 >= 1200 or not Brawlers.choose("rey"))
	check("personajes: se elige uno libre", Brawlers.choose("coraza") and str(Brawlers.chosen()["id"]) == "coraza")
	var duel: Array = [".........", ".........", "....R....", ".........", ".........", ".........", ".........", "....P....", ".........", ".........", "........."]
	var game: Node = await start_game(brawl_config(duel, {"reaction": 99.0}), 0)
	var me: BrawlFighter = game.get("player")
	check("personajes: el elegido cambia vida y velocidad", me.max_hp > 3200.0 * 1.3 and me.speed < 330.0, "%.0f %.0f" % [me.max_hp, me.speed])
	game.call("shoot", me, Vector2.UP)
	check("personajes: la escopeta lanza 5 balas", (game.get("bullets") as Array).size() == 5)
	(game.get("bullets") as Array).clear()
	## Escudo: casi sin dano 3 s.
	me.super_charge = 1.0
	game.call("use_super")
	var hp0: float = me.hp
	game.call("_hit_fighter", me, 1000.0, null, Color.WHITE)
	check("super escudo: el golpe hace un cuarto", absf((hp0 - me.hp) - 250.0) < 1.0, "%.0f" % (hp0 - me.hp))
	await stop_game(game)
	## Francotiradora y bomba.
	Save.meta()["brawler"] = "aguja"
	game = await start_game(brawl_config(duel, {"reaction": 99.0}), 0)
	me = game.get("player")
	var foe: BrawlFighter = (game.get("fighters") as Array)[1]
	if str(Brawlers.chosen()["id"]) == "aguja":
		game.call("shoot", me, Vector2.UP)
		check("personajes: la francotiradora lanza 1 bala fuerte", (game.get("bullets") as Array).size() == 1 and float((game.get("bullets") as Array)[0]["dmg"]) > 600.0)
		(game.get("bullets") as Array).clear()
		await frames(2)
		var fh: float = foe.hp
		me.super_charge = 1.0
		game.call("use_super")
		for k: int in 60:
			await get_tree().physics_frame
		check("super bomba: explota donde esta el rival", foe.hp < fh, "%.0f -> %.0f" % [fh, foe.hp])
	await stop_game(game)
	Save.meta()["brawler"] = "tenaza"
	## Supervivencia: oleadas y el bot (piloto automatico) aguanta.
	var surv: Array = [".............", "..R.......R..", ".............", "..**.....**..", ".............", "....#...#....",
		".............", ".............", "..**.....**..", ".............", "...A.......A.", "......P......", "............."]
	game = await start_game(brawl_config(surv, {"mode": "survival", "waves": 2, "rival_hp": 1800}), 0)
	check("supervivencia: primera oleada y aliados", int(game.get("wave")) == 1 and int(game.call("rivals_left")) == 2 and (game.get("fighters") as Array).size() == 5,
		str(game.call("bot_state")))
	var done: bool = await QaBot.run(get_tree(), game, 60 * 120)
	check("supervivencia: el bot aguanta todas las oleadas", done and int(game.get("wave")) == 2, str(game.call("bot_state")))
	await stop_game(game)
	## Balon: chutar a puerta marca.
	game = await start_game(brawl_config(brawl_ball_map(), {"mode": "ball", "reaction": 99.0}), 0)
	me = game.get("player")
	check("balon: 3 contra 3 con balon", (game.get("fighters") as Array).size() == 6 and not (game.get("ball") as Dictionary).is_empty())
	var ball: Dictionary = game.get("ball")
	ball["pos"] = me.position + Vector2(0, -40)
	await frames(3)
	check("balon: quien lo toca lo lleva", (game.get("ball") as Dictionary).get("holder") == me)
	me.position = game.call("center_of", Vector2i(6, 4))
	for o: BrawlFighter in game.get("fighters"):
		if o.team == 1:
			o.position = game.call("center_of", Vector2i(1, 10))
	await frames(1)
	check("balon: el ataque chuta", bool(game.call("attack")))
	for k: int in 60:
		await get_tree().physics_frame
	check("balon: gol en su porteria", (game.get("goals_score") as Array)[0] == 1, str(game.call("bot_state")))
	await stop_game(game)
	game = await start_game(brawl_config(brawl_ball_map(), {"mode": "ball", "time": 150}), 0)
	done = await QaBot.run(get_tree(), game, 60 * 200)
	check("balon: el bot gana el partido", done, str(game.call("bot_state")))
	await stop_game(game)
	## Torretas: reaparecer y ganar.
	game = await start_game(brawl_config(brawl_turret_map(), {"mode": "turrets"}), 0)
	me = game.get("player")
	var turrets: Array = game.get("turrets")
	check("torretas: una por equipo", turrets[0] != null and turrets[1] != null and (turrets[1] as BrawlFighter).team == 1)
	me.hit(99999.0)
	game.call("_on_death", me, null)
	check("torretas: al caer no pierdes", not bool(game.get("failed")))
	for k: int in 200:
		await get_tree().physics_frame
	check("torretas: vuelves a tu salida", me.alive and me.hp == me.max_hp)
	await stop_game(game)
	game = await start_game(brawl_config(brawl_turret_map(), {"mode": "turrets", "time": 180}), 0)
	done = await QaBot.run(get_tree(), game, 60 * 230)
	check("torretas: el bot derriba la torreta rival", done, str(game.call("bot_state")))
	await stop_game(game)
	var MapRules: GDScript = load("res://kit/brawl/brawl_map.gd")
	check("arena: analizador acepta balon y torretas",
		bool(MapRules.analyze(brawl_config(brawl_ball_map(), {"mode": "ball"})["levels"][0])["completable"]) and bool(MapRules.analyze(brawl_config(brawl_turret_map(), {"mode": "turrets"})["levels"][0])["completable"]),
		str(MapRules.analyze(brawl_config(brawl_ball_map(), {"mode": "ball"})["levels"][0])["issues"]) + str(MapRules.analyze(brawl_config(brawl_turret_map(), {"mode": "turrets"})["levels"][0])["issues"]))
	check("arena: balon sin porteria detectado", (MapRules.analyze(brawl_config(duel, {"mode": "ball"})["levels"][0])["issues"] as Array).has("brawl_ball_missing"))


func village_config(map: Array, extra: Dictionary) -> Dictionary:
	var cfg: Dictionary = base_config.duplicate(true)
	cfg["genre"] = "village"
	var lv: Dictionary = {"name": "aldea", "map": map, "army": {"guerrero": 11, "arquera": 9, "gigante": 2}, "seconds": 150,
		"base_hp": 1.0, "def_dmg": 1.0}
	lv.merge(extra, true)
	cfg["levels"] = [lv]
	return cfg


func village_base() -> Array:
	return ["..................", "..................", "..................", ".....K..M.........", "..................",
		"....######.O......", "....#G............", "....#......#......", "....#...H..#A.....", "....#......#......",
		"....#E............", "....#......#.K....", "....######C.......", "...M..C...........", "..................",
		"..................", "..................", ".................."]


## Aldea: despliegue, muros, defensas, estrellas, derrota, bot y analizador.
func _test_village() -> void:
	print("- Aldea")
	## Sin aldea propia (sus ayudas cambiarian el ejercito de las pruebas).
	Save.meta().erase("aldea")
	Save.save_data()
	var tiny: Array = ["................", "................", "................", "................", "................",
		"................", "......H.........", "................", "................", "...........C....", "................",
		"................", "................", "................", "................", "................"]
	var game: Node = await start_game(village_config(tiny, {"army": {"guerrero": 6, "arquera": 2}}), 0)
	check("aldea: escena propia con bot", game.has_method("bot_script") and str(game.call("bot_script")).ends_with("village_bot.gd"))
	check("aldea: no se suelta pegado a un edificio", not bool(game.call("deploy", "guerrero", Vector2i(6, 5))))
	check("aldea: se suelta fuera de la base", bool(game.call("deploy", "guerrero", Vector2i(1, 1))) and int((game.get("left") as Dictionary)["guerrero"]) == 5)
	game.call("deploy", "guerrero", Vector2i(15, 10))
	var defense_fired: bool = false
	for k: int in 60 * 12:
		await get_tree().physics_frame
		if not (game.get("shots") as Array).is_empty():
			defense_fired = true
		if int(game.get("stars")) >= 2 or bool(game.get("finished")):
			break
	var tr0: Dictionary = (game.get("troops") as Array)[0]
	var hall: Dictionary = (game.get("buildings") as Array)[0]
	check("aldea: la tropa va a por un edificio y le pega", float(hall["hp"]) < float(hall["max_hp"]), "%s %s %s" % [tr0["pos"], tr0["alive"], tr0["target"]])
	check("aldea: las defensas disparan", defense_fired)
	await stop_game(game)
	## Muro que corta el paso: se rompe.
	var walled: Array = tiny.duplicate()
	walled[5] = ".....#####......"
	walled[6] = ".....#H..#......"
	walled[7] = ".....#...#......"
	walled[8] = ".....#####......"
	walled[9] = "................"
	walled[12] = "...C............"
	game = await start_game(village_config(walled, {"army": {"guerrero": 6}}), 0)
	var walls0: int = 0
	for b: Dictionary in game.get("buildings"):
		if b["wall"] and b["alive"]:
			walls0 += 1
	for k: int in 3:
		game.call("deploy", "guerrero", Vector2i(7, 1))
	var broke: bool = false
	for k: int in 60 * 30:
		await get_tree().physics_frame
		var alive_walls: int = 0
		for b: Dictionary in game.get("buildings"):
			if b["wall"] and b["alive"]:
				alive_walls += 1
		if alive_walls < walls0:
			broke = true
			break
	check("aldea: un muro cerrado se rompe para pasar", broke)
	await stop_game(game)
	## Sin tropas y sin estrellas: asalto fallido.
	game = await start_game(village_config(tiny, {"army": {"guerrero": 1}}), 0)
	game.call("deploy", "guerrero", Vector2i(15, 15))
	(game.get("troops") as Array)[0]["hp"] = 1.0
	for k: int in 60 * 40:
		await get_tree().physics_frame
		if bool(game.get("failed")):
			break
	check("aldea: sin estrellas, asalto fallido", bool(game.get("failed")) and game.get_node_or_null("FailPanel") != null)
	await stop_game(game)
	## El bot consigue estrellas en una base de verdad.
	game = await start_game(village_config(village_base(), {}), 0)
	var done: bool = await QaBot.run(get_tree(), game, 60 * 200)
	check("aldea: el bot gana el asalto", done and int(game.get("deaths")) == 0, str(game.call("bot_state")))
	await stop_game(game)
	var MapRules: GDScript = load("res://kit/village/village_map.gd")
	var good: Dictionary = MapRules.analyze(village_config(village_base(), {})["levels"][0])
	check("aldea: analizador acepta la base", bool(good["completable"]), str(good["issues"]))
	var bad: Array = village_base().duplicate()
	bad[8] = "....#...HC.#A....."
	check("aldea: edificios solapados detectados", (MapRules.analyze(village_config(bad, {})["levels"][0])["issues"] as Array).has("village_overlap"))
	## Tu aldea: construir, mejorar hasta el ayuntamiento y las ayudas en el asalto.
	var VS: GDScript = load("res://kit/village/village_save.gd")
	var m: Dictionary = Save.meta()
	m.erase("aldea")
	var wallet0: int = Save.wallet()
	Save.add_wallet(5000)
	var home: Node = (load("res://scenes/village_home.tscn") as PackedScene).instantiate()
	add_child(home)
	await frames(3)
	check("mi aldea: empieza con el ayuntamiento", (home.get("buildings") as Array).size() == 1 and int(VS.call("hall")) == 1)
	check("mi aldea: lo que pide ayuntamiento 2 esta bloqueado", int(VS.call("price", "arquera1")) == -1)
	var w1: int = Save.wallet()
	check("mi aldea: construir cuesta monedas y aparece", bool(home.call("do_build", "cuartel1")) and Save.wallet() == w1 - 100 and (home.get("buildings") as Array).size() == 2)
	check("mi aldea: no se mejora por encima del ayuntamiento", int(VS.call("price", "cuartel1")) == -1)
	check("mi aldea: subir el ayuntamiento", bool(home.call("do_build", "hall")) and int(VS.call("hall")) == 2 and int(VS.call("price", "arquera1")) == 250)
	home.call("do_build", "cuartel1")
	home.call("do_build", "elixir1")
	home.call("do_build", "muralla")
	var walls: int = 0
	for b: Dictionary in home.get("buildings"):
		if b["wall"]:
			walls += 1
	check("mi aldea: la muralla rodea el centro", walls == 16, str(walls))
	home.call("tap_cell", Vector2i(7, 12))
	await frames(2)
	var hp: UiModal = home.get("home_panel")
	check("mi aldea: tocar un edificio abre su ventana", hp != null and hp.body.get_node_or_null("BtnUpgrade") != null)
	hp.close()
	home.call("open_build")
	await frames(2)
	hp = home.get("home_panel")
	check("mi aldea: lista de construir con bloqueados", hp != null and hp.find_child("Build_mortero1", true, false) != null and (hp.find_child("Build_mortero1", true, false) as Button).disabled)
	hp.close()
	var bonus: Dictionary = VS.call("bonus")
	check("mi aldea: ayudas (cuartel 2 = +2 tropas, elixir = +4 %)", int(bonus["troops"]) == 2 and is_equal_approx(float(bonus["strength"]), 0.04))
	home.queue_free()
	await frames(2)
	game = await start_game(village_config(village_base(), {"army": {"guerrero": 5, "arquera": 3}}), 0)
	check("mi aldea: el asalto trae las tropas extra", int((game.get("left") as Dictionary)["guerrero"]) == 7 and int((game.get("left") as Dictionary)["arquera"]) == 5)
	await stop_game(game)
	## Liga (por internet, simulada): publicar, rival, asalto con su aldea y trofeos.
	var calls: Array = []
	var clan_state: Dictionary = {}
	Online.fake = func(rpc: String, payload: Dictionary) -> Variant:
		calls.append([rpc, payload])
		match rpc:
			"liga_publicar":
				return {"trofeos": 40, "victorias": 2, "defensas": 1}
			"liga_rival":
				return {"ataque": 77, "alias": "Lucia", "mapa": village_base(), "ayto": 2, "trofeos": 55}
			"liga_resultado":
				return {"trofeos": 62}
			"liga_top":
				return [{"posicion": 1, "alias": "Lucia", "trofeos": 55, "ayto": 2, "tuyo": false}, {"posicion": 2, "alias": "Dani", "trofeos": 40, "ayto": 2, "tuyo": true}]
			"liga_defensas":
				return [{"alias": "Pepe", "estrellas": 1, "destruccion": 55, "trofeos": -4}]
			"clan_info":
				return clan_state.duplicate(true) if not clan_state.is_empty() else null
			"clan_crear":
				clan_state["nombre"] = str(payload["p_nombre"])
				clan_state["codigo"] = "K7F2Q9"
				clan_state["puesto"] = 3
				clan_state["trofeos"] = 40
				clan_state["miembros"] = [{"alias": "Dani", "trofeos": 40, "tuyo": true}]
				return {"codigo": "K7F2Q9", "nombre": clan_state["nombre"]}
			"clan_guerra":
				return {"segundos": 200000, "premio": 150, "puesto_pasado": 2,
					"top": [{"posicion": 1, "nombre": "Osos", "estrellas": 12, "tuyo": false}, {"posicion": 2, "nombre": "Lobos", "estrellas": 7, "tuyo": true}],
					"clan": {"nombre": "Lobos", "puesto": 2, "estrellas": 7, "tus_estrellas": 3}}
			"clan_guerra_cobrar":
				return 150
		return null
	Save.set_setting("online", true, false)
	Save.set_setting("alias", "Dani", false)
	var host2: Node2D = Node2D.new()
	add_child(host2)
	var lp: LigaPanel = LigaPanel.open(host2)
	await frames(6)
	check("liga: publica tu aldea con tu apodo y muestra trofeos", calls.size() >= 1 and calls[0][0] == "liga_publicar" and (calls[0][1]["p_mapa"] as Array).size() == 18
		and (lp.find_child("Trophies", true, false) as Label).text == "40")
	check("liga: ranking y quien te ha atacado", (lp.find_child("Content", true, false) as VBoxContainer).get_child_count() >= 5)
	var ce: LineEdit = lp.find_child("ClanEdit", true, false) as LineEdit
	check("clan: sin clan se puede crear o unirse", ce != null and lp.find_child("BtnClanJoin", true, false) != null)
	if ce != null:
		ce.text = "Lobos"
		(lp.find_child("BtnClanCreate", true, false) as Button).pressed.emit()
		await frames(6)
		check("clan: crear lo muestra con su codigo para invitar", lp.find_child("BtnInvite", true, false) != null
			and (lp.find_child("BtnInvite", true, false) as Button).text.contains("K7F2Q9"))
	var wc: Button = lp.find_child("BtnWarClaim", true, false) as Button
	check("guerra de clanes: top de la semana y premio de la pasada", wc != null and wc.text.contains("150"))
	if wc != null:
		var w0: int = Save.wallet()
		wc.pressed.emit()
		await frames(4)
		check("guerra de clanes: cobrar suma las monedas una vez", Save.wallet() == w0 + 150 and wc.disabled)
	lp.close()
	host2.queue_free()
	Online.liga_match = {"ataque": 77, "alias": "Lucia", "mapa": village_base(), "ayto": 2, "trofeos": 55}
	game = await start_game(village_config(["................", "......H........."], {}), 0)
	check("liga: el asalto es la aldea del rival", (game.get("rows") as Array).size() == 18 and not (game.get("liga") as Dictionary).is_empty())
	var want: int = int((VS.call("liga_army", int(VS.call("hall"))) as Dictionary)["guerrero"]) + int((VS.call("bonus") as Dictionary)["troops"])
	check("liga: ejercito segun tu ayuntamiento (y tus cuarteles)", int((game.get("left") as Dictionary).get("guerrero", 0)) == want, str(want))
	game.set("stars", 2)
	game.set("destruction", 64.0)
	game.call("_end")
	await frames(4)
	var rp: LigaPanel = game.get_node_or_null("LigaPanel") as LigaPanel
	var last: Array = []
	for c: Array in calls:
		if c[0] == "liga_resultado":
			last = c
	check("liga: sube la repeticion del asalto", calls.back()[0] == "liga_repeticion_subir")
	check("liga: manda el resultado de ESE asalto", not last.is_empty() and int(last[1]["p_ataque"]) == 77 and int(last[1]["p_estrellas"]) == 2 and int(last[1]["p_destruccion"]) == 64)
	check("liga: ventana con trofeos nuevos", rp != null and (rp.find_child("Info", true, false) as Label).text.contains("62"))
	check("liga: el asalto se cierra (no se repite)", Online.liga_match.is_empty())
	await stop_game(game)
	Online.fake = Callable()
	Save.set_setting("alias", "", false)
	m.erase("aldea")
	Save.add_wallet(wallet0 - Save.wallet())
	Save.save_data()
	check("aldea: sin defensas detectado", (MapRules.analyze(village_config(tiny.map(func(r: String) -> String: return r.replace("C", ".")), {})["levels"][0])["issues"] as Array).has("village_no_defense"))


## Arena en directo: dos jugadores en el mismo programa por un canal local (con latencia).
func _test_arena_live() -> void:
	print("- Arena en directo")
	var calls: Array = []
	Online.fake = func(rpc: String, payload: Dictionary) -> Variant:
		calls.append([rpc, payload])
		if rpc == "arena_resultado":
			return {"trofeos": 12 if int(payload["p_puesto"]) == 1 else 5, "delta": 12 if int(payload["p_puesto"]) == 1 else 5}
		return null
	Online.fake_net_latency = 0.05
	Save.set_setting("online", true, false)
	var duel: Array = ["...............", "...............", ".......R.......", "...............", "...............",
		"...............", "...............", "...............", ".......P.......", "...............", "...............", "..............."]
	var cfg: Dictionary = brawl_config(duel, {"gas_start": 300, "reaction": 99.0})
	var players: Array = [{"sesion": "aaaaaaaaaaaaaaa1", "alias": "Dani", "slot": 0}, {"sesion": "bbbbbbbbbbbbbbb2", "alias": "Lucia", "slot": 1}]
	var base: Dictionary = {"sala": "sala-prueba", "jugadores": players, "nivel": 0, "semilla": 1, "start_ms": Time.get_ticks_msec() - 50}
	Online.arena_match = base.duplicate(true)
	Online.arena_match["yo"] = "aaaaaaaaaaaaaaa1"
	var a: Node = await start_game(cfg, 0)
	Online.arena_match = base.duplicate(true)
	Online.arena_match["yo"] = "bbbbbbbbbbbbbbb2"
	var gb: Node = (load(UI.game_scene()) as PackedScene).instantiate()
	add_child(gb)
	await frames(3)
	var pa: BrawlFighter = a.get("player")
	var pb: BrawlFighter = gb.get("player")
	check("directo: cada uno es su luchador (y el otro, remoto)", pa != pb and pa.net_id == "aaaaaaaaaaaaaaa1" and pb.net_id == "bbbbbbbbbbbbbbb2"
		and ((a.get("by_id") as Dictionary)["bbbbbbbbbbbbbbb2"] as BrawlFighter).remote)
	check("directo: los huecos los rellenan bots (los mueve el anfitrion)", (a.get("fighters") as Array).size() == 4 and bool(a.get("host")) and not bool(gb.get("host"))
		and ((gb.get("by_id") as Dictionary)["bot2"] as BrawlFighter).remote and not ((a.get("by_id") as Dictionary)["bot2"] as BrawlFighter).remote)
	## Fuera de juego los bots (para que el duelo sea limpio).
	for g: Node in [a, gb]:
		for f: BrawlFighter in g.get("fighters"):
			if f.net_id.begins_with("bot"):
				f.alive = false
				f.visible = false
	for k: int in 40:
		await get_tree().physics_frame
	a.set("move_input", Vector2(1, 0))
	for k: int in 40:
		await get_tree().physics_frame
	a.set("move_input", Vector2(0.001, 0))
	for k: int in 20:
		await get_tree().physics_frame
	var a_in_b: BrawlFighter = (gb.get("by_id") as Dictionary)["aaaaaaaaaaaaaaa1"]
	check("directo: el otro ve como me muevo", a_in_b.position.distance_to(pa.position) < 40.0 and pa.position.x > 7.5 * 96.0 + 100.0,
		"%s vs %s" % [a_in_b.position, pa.position])
	var hp0: float = pb.hp
	pa.ammo = 3.0
	a.call("shoot", pa, (pb.position - pa.position).normalized())
	for k: int in 50:
		await get_tree().physics_frame
	check("directo: mi disparo le quita vida en SU juego (el decide)", pb.hp < hp0, "%.0f -> %.0f" % [hp0, pb.hp])
	var b_in_a: BrawlFighter = (a.get("by_id") as Dictionary)["bbbbbbbbbbbbbbb2"]
	check("directo: y yo veo su vida bajar", b_in_a.hp < hp0 + 1.0 and absf(b_in_a.hp - pb.hp) < 1.0, "%.0f / %.0f" % [b_in_a.hp, pb.hp])
	pb.hp = 1.0
	pa.ammo = 3.0
	a.call("shoot", pa, (pb.position - pa.position).normalized())
	for k: int in 60:
		await get_tree().physics_frame
	check("directo: el que cae queda segundo y el otro gana", bool(gb.get("reported")) and int(gb.get("placed")) == 2 and bool(a.get("reported")) and int(a.get("placed")) == 1)
	var places: Array = []
	for c: Array in calls:
		if c[0] == "arena_resultado":
			places.append(int(c[1]["p_puesto"]))
	places.sort()
	check("directo: cada uno manda su puesto al servidor", places == [1, 2], str(places))
	check("directo: ventana de resultado", a.get_node_or_null("ArenaPanel") != null)
	gb.queue_free()
	await stop_game(a)
	## Sala con amigos: crear, ver el codigo y empezarla quien la creo.
	var started: Array = []
	Online.fake = func(rpc: String, payload: Dictionary) -> Variant:
		match rpc:
			"arena_privada_crear":
				return {"sala": "s-priv", "slot": 0, "codigo": "K7F2Q9"}
			"arena_estado":
				return {"sala": "s-priv", "nivel": 0, "semilla": 1, "empezada": not started.is_empty(), "en": 3.0 if not started.is_empty() else -1,
					"privada": true, "codigo": "K7F2Q9", "jugadores": [{"sesion": Online.device(), "alias": "Dani", "slot": 0}]}
			"arena_empezar":
				started.append(true)
				return null
			"arena_top":
				return []
		return null
	Save.set_setting("alias", "Dani", false)
	var tm: bool = UI.test_mode
	UI.test_mode = true
	var host: Control = Control.new()
	add_child(host)
	var ap: ArenaPanel = ArenaPanel.open(host)
	await frames(3)
	ap.create_private()
	await frames(4)
	check("privada: muestra el codigo para invitar", (ap.find_child("Status", true, false) as Label).text.contains("K7F2Q9") and ap.find_child("BtnShareCode", true, false) != null)
	var sb: Button = ap.find_child("BtnStart", true, false) as Button
	check("privada: quien la crea puede empezarla", sb != null and sb.visible)
	if sb != null:
		sb.pressed.emit()
		for k: int in 90:
			await get_tree().physics_frame
			if not Online.arena_match.is_empty():
				break
	check("privada: al empezar, la partida va con esa sala", started.size() == 1 and str(Online.arena_match.get("sala", "")) == "s-priv")
	host.queue_free()
	UI.test_mode = tm
	Online.arena_match = {}
	Save.set_setting("alias", "", false)
	## Protocolo de Supabase Realtime (Phoenix): respuesta al unirse y mensajes de la sala.
	var ch: RealtimeChannel = RealtimeChannel.new()
	add_child(ch)
	ch.topic = "arena-x"
	var got: Array = []
	ch.received.connect(func(ev: String, pl: Dictionary) -> void: got.append([ev, pl]))
	ch.call("_on_text", JSON.stringify({"topic": "realtime:arena-x", "event": "phx_reply", "ref": "1", "payload": {"status": "ok", "response": {}}}))
	ch.call("_on_text", JSON.stringify({"topic": "realtime:arena-x", "event": "broadcast", "payload": {"type": "broadcast", "event": "st", "payload": {"l": [1]}}}))
	ch.call("_on_text", "no es json")
	check("realtime: se une con la respuesta ok y entrega los mensajes", ch.is_joined and got.size() == 1 and got[0][0] == "st" and (got[0][1]["l"] as Array).size() == 1)
	ch.queue_free()
	Online.fake = Callable()
	Online.fake_net_latency = -1.0
	Online.arena_match = {}


func stack_config(extra: Dictionary) -> Dictionary:
	var cfg: Dictionary = base_config.duplicate(true)
	cfg["genre"] = "stack"
	var lv: Dictionary = {"name": "torre", "map": ["S".repeat(8)], "target": 8, "speed": 240.0, "ramp": 0.02, "width": 360.0, "perfect": 10.0}
	lv.merge(extra, true)
	cfg["levels"] = [lv]
	return cfg


## Apilar: perfecto, corte, fallo, ganar, bot y analizador.
func _test_stack() -> void:
	print("- Apilar")
	var game: Node = await start_game(stack_config({}), 0)
	check("apilar: escena propia con bot", game.has_method("bot_script"))
	game.set("moving_x", 3.0)
	game.call("drop")
	check("apilar: soltar casi encima es perfecto y no corta", int(game.get("perfects")) == 1 and absf(float((game.get("tower") as Array)[1][1]) - 360.0) < 0.1)
	game.set("moving_x", 60.0)
	var w: float = float(game.call("drop"))
	check("apilar: lo que sobresale se corta", absf(w - 300.0) < 0.5, str(w))
	game.set("moving_x", 900.0)
	game.call("drop")
	await frames(2)
	check("apilar: fuera de la torre es caida y repetir", bool(game.get("failed")) and game.get_node_or_null("FailPanel") != null)
	await stop_game(game)
	game = await start_game(stack_config({"target": 5}), 0)
	for k: int in 5:
		game.set("moving_x", float((game.get("tower") as Array)[-1][0]))
		game.call("drop")
	await frames(3)
	check("apilar: llegar arriba gana con 3 estrellas", bool(game.get("finished")) and int(game.call("stars_earned")) == 3)
	await stop_game(game)
	game = await start_game(stack_config({"target": 18, "speed": 330.0, "ramp": 0.025, "width": 300.0, "perfect": 7.0}), 0)
	var done: bool = await QaBot.run(get_tree(), game, 60 * 120)
	check("apilar: el bot llega arriba", done, str(game.call("bot_state")))
	await stop_game(game)
	var MapRules: GDScript = load("res://kit/stack/stack_map.gd")
	check("apilar: analizador acepta un nivel bueno", bool(MapRules.analyze(stack_config({})["levels"][0])["completable"]))
	check("apilar: demasiado rapido detectado", (MapRules.analyze(stack_config({"speed": 700.0, "ramp": 0.05})["levels"][0])["issues"] as Array).has("stack_speed"))


func quiz_config(n: int, pass_n: int) -> Dictionary:
	var cfg: Dictionary = base_config.duplicate(true)
	cfg["genre"] = "quiz"
	var qs: Array = []
	for i: int in n:
		qs.append({"q": "Pregunta %d de prueba?" % i, "a": ["Uno %d" % i, "Dos %d" % i, "Tres %d" % i, "Cuatro %d" % i], "ok": i % 4, "why": "Porque si."})
	cfg["levels"] = [{"name": "quiz", "map": ["Q".repeat(n)], "questions": qs, "time": 10.0, "pass": pass_n}]
	return cfg


## Preguntas: acierto, fallo con explicacion, tiempo agotado, pasar o repetir, bot y analizador.
func _test_quiz() -> void:
	print("- Preguntas")
	var game: Node = await start_game(quiz_config(4, 3), 0)
	check("preguntas: escena propia con bot", game.has_method("bot_script"))
	game.set("fast", true)
	check("preguntas: muestra la primera pregunta", (game.find_child("Question", true, false) as Label).text.begins_with("Pregunta 0"))
	game.call("answer", 0)
	check("preguntas: acierto suma moneda y racha", int(game.get("correct")) == 1 and int(game.get("streak")) == 1)
	await frames(30)
	game.call("answer", 0)
	check("preguntas: fallo explica y marca la buena", int(game.get("correct")) == 1 and (game.find_child("Why", true, false) as Label).text.contains("Porque")
		and (game.find_child("Answer1", true, false) as Button).theme_type_variation == "PrimaryButton")
	await frames(40)
	game.set("time_left", 0.01)
	await frames(3)
	check("preguntas: sin tiempo cuenta como fallo", int(game.get("index")) == 2 and not bool(game.get("answering")))
	await frames(40)
	game.call("answer", 3)
	await frames(40)
	check("preguntas: sin los aciertos minimos se repite", bool(game.get("failed")) and game.get_node_or_null("FailPanel") != null)
	await stop_game(game)
	game = await start_game(quiz_config(5, 3), 0)
	var done: bool = await QaBot.run(get_tree(), game, 60 * 60)
	check("preguntas: el bot pasa el nivel", done and int(game.get("correct")) >= 3, str(game.call("bot_state")))
	await stop_game(game)
	var MapRules: GDScript = load("res://kit/quiz/quiz_map.gd")
	var good: Dictionary = quiz_config(5, 3)["levels"][0]
	check("preguntas: analizador acepta un nivel bueno", bool(MapRules.analyze(good)["completable"]), str(MapRules.analyze(good)["issues"]))
	var rep: Dictionary = good.duplicate(true)
	(rep["questions"][0] as Dictionary)["a"] = ["A", "a", "B", "C"]
	check("preguntas: respuestas repetidas detectadas", (MapRules.analyze(rep)["issues"] as Array).has("quiz_repeated_answers"))
	var many: Dictionary = good.duplicate(true)
	many["pass"] = 9
	check("preguntas: aprobar imposible detectado", (MapRules.analyze(many)["issues"] as Array).has("quiz_pass"))


func sokoban_config(rows: Array, par: int) -> Dictionary:
	var cfg: Dictionary = base_config.duplicate(true)
	cfg["genre"] = "sokoban"
	cfg["levels"] = [{"name": "almacen", "map": rows, "par": par}]
	return cfg


## Cajas (sokoban): empujar, muros, deshacer, cajas atascadas, solucion del bot y analizador.
func _test_sokoban() -> void:
	print("- Cajas")
	var rows: Array = ["#######", "#..P..#", "#..B..#", "#.....#", "#..O..#", "#######"]
	var game: Node = await start_game(sokoban_config(rows, 2), 0)
	check("cajas: escena propia con bot", game.has_method("bot_script"))
	game.set("fast", true)
	check("cajas: el muro no se atraviesa", not bool(game.call("try_move", Vector2i(0, -1))))
	check("cajas: empujar mueve la caja", bool(game.call("try_move", Vector2i(0, 1))) and (game.get("boxes") as Dictionary).has(Vector2i(3, 3))
		and int(game.get("pushes")) == 1, str((game.get("boxes") as Dictionary).keys()))
	await frames(4)
	game.call("undo")
	check("cajas: deshacer devuelve la caja y el empuje", (game.get("boxes") as Dictionary).has(Vector2i(3, 2)) and int(game.get("pushes")) == 0
		and Vector2i(game.get("cell")) == Vector2i(3, 1))
	game.call("try_move", Vector2i(0, 1))
	await frames(4)
	game.call("try_move", Vector2i(0, 1))
	await frames(6)
	check("cajas: todas en su hueco gana con 3 estrellas", bool(game.get("finished")) and int(game.call("stars_earned")) == 3)
	await stop_game(game)
	## Caja contra la esquina: aviso de atascada.
	game = await start_game(sokoban_config(["#######", "#.....#", "#..B..#", "#..P..#", "#.....#", "#..O..#", "#######"], 3), 0)
	game.set("fast", true)
	game.call("try_move", Vector2i(0, -1))
	await frames(5)
	check("cajas: caja contra el muro sin hueco avisa que esta atascada", bool(game.get("stuck")) and (game.find_child("Stuck", true, false) as Label).visible)
	await stop_game(game)
	## El bot resuelve un almacen con tres cajas.
	var three: Array = ["########", "#......#", "#.B.O..#", "#..##..#", "#.B..O.#", "#.P.#..#", "#..B.O.#", "########"]
	game = await start_game(sokoban_config(three, 0), 0)
	var done: bool = await QaBot.run(get_tree(), game, 60 * 60)
	check("cajas: el bot lo resuelve", done, str(game.call("bot_state")))
	await stop_game(game)
	var MapRules: GDScript = load("res://kit/sokoban/sokoban_map.gd")
	check("cajas: analizador acepta un nivel bueno", bool(MapRules.analyze({"map": three})["completable"]))
	check("cajas: caja en rincon detectada", (MapRules.analyze({"map": ["#####", "#B..#", "#.P.#", "#..O#", "#####"]})["issues"] as Array).has("sokoban_dead_box"))
	check("cajas: menos huecos que cajas", (MapRules.analyze({"map": ["######", "#.B..#", "#.PB.#", "#..O.#", "######"]})["issues"] as Array).has("sokoban_goals_mismatch"))
	check("cajas: sin solucion detectado", (MapRules.analyze({"map": ["#######", "#.....#", "#.BB..#", "#.BB..#", "#P.OOOO", "#######"]})["issues"] as Array).size() > 0)


func snake_config(rows: Array, extra: Dictionary) -> Dictionary:
	var cfg: Dictionary = base_config.duplicate(true)
	cfg["genre"] = "snake"
	var lv: Dictionary = {"name": "jardin", "map": rows, "goal": 14, "step": 0.15, "par": 40.0, "seed": 7}
	lv.merge(extra, true)
	cfg["levels"] = [lv]
	return cfg


func _test_snake() -> void:
	print("- Serpiente")
	var game: Node = await start_game(snake_config(snake_board(), {}), 0)
	check("serpiente: escena propia con bot", game.has_method("bot_script"))
	check("serpiente: empieza con 3 casillas", (game.get("body") as Array).size() == 3)
	check("serpiente: no se da la vuelta de golpe", not bool(game.call("turn", Vector2i(0, 1))))
	## Poner la fruta justo delante: crece.
	var head: Vector2i = (game.get("body") as Array)[0]
	game.set("fruit", head + Vector2i(0, -1))
	await frames(70)
	check("serpiente: comer la hace crecer", int(game.get("eaten")) == 1 and (game.get("body") as Array).size() == 4)
	await stop_game(game)
	## Contra la pared: choque.
	game = await start_game(snake_config(snake_board(), {"step": 0.05}), 0)
	game.set("fruit", Vector2i(1, 1))
	for k: int in 60 * 4:
		await get_tree().physics_frame
		if int(game.get("deaths")) > 0:
			break
	check("serpiente: chocar con la pared es repetir", int(game.get("deaths")) >= 1)
	## Segunda oportunidad: mirando a la pared, gira hacia un hueco libre.
	var sb: Array = game.get("body")
	game.set("dir", Vector2i(0, -1))
	game.set("next_dir", Vector2i(0, -1))
	var top: Vector2i = sb[0]
	while not bool(game.call("wall", top + Vector2i(0, -1))):
		top += Vector2i(0, -1)
	var nb: Array[Vector2i] = [top, top + Vector2i(0, 1), top + Vector2i(0, 2)]
	game.set("body", nb)
	game.call("revive")
	var nd: Vector2i = game.get("dir")
	check("serpiente: la segunda oportunidad gira hacia un hueco", not bool(game.call("wall", game.call("next_cell", top, nd))) and not bool(game.get("failed")))
	await stop_game(game)

	game = await start_game(snake_config(snake_board(), {}), 0)
	var done: bool = await QaBot.run(get_tree(), game, 60 * 150)
	var st: Dictionary = game.call("bot_state")
	check("serpiente: el bot come las 14 frutas", done and int(st["deaths"]) == 0, "comidas=%d muertes=%d" % [int(st["eaten"]), int(st["deaths"])])
	await stop_game(game)

	var MapRules: GDScript = load("res://kit/snake/snake_map.gd")
	check("serpiente: tablero bueno", bool(MapRules.call("analyze", {"map": snake_board(), "goal": 14})["completable"]))
	var cerrado: Array = snake_board()
	cerrado[2] = "####......#"
	cerrado[1] = "#.#.......#"
	cerrado[3] = "##.##.##..#"
	check("serpiente: hueco cerrado detectado", (MapRules.call("analyze", {"map": cerrado, "goal": 14})["issues"] as Array).has("snake_disconnected"))
	check("serpiente: objetivo demasiado grande detectado", (MapRules.call("analyze", {"map": snake_board(), "goal": 60})["issues"] as Array).has("snake_goal_too_big"))


## Memoria: parejas, fallos que se tapan, limite de intentos, bot sin trampas y analizador.
func memory_config(rows: Array, extra: Dictionary) -> Dictionary:
	var cfg: Dictionary = base_config.duplicate(true)
	cfg["genre"] = "memory"
	var lv: Dictionary = {"name": "cartas", "map": rows, "seed": 11, "par": 14, "limit": 24}
	lv.merge(extra, true)
	cfg["levels"] = [lv]
	return cfg


func _test_memory() -> void:
	print("- Memoria")
	var tablero: Array = ["....", "....", "....", "...."]
	var game: Node = await start_game(memory_config(tablero, {}), 0)
	var cards: Array = game.get("cards")
	check("memoria: 16 cartas, 8 parejas", cards.size() == 16 and int(game.get("pairs_left")) == 8)
	## Encontrar una pareja a mano.
	var a: int = 0
	var b: int = -1
	for k: int in range(1, cards.size()):
		if int(cards[k]["face"]) == int(cards[0]["face"]):
			b = k
	game.call("flip", a)
	game.call("flip", b)
	check("memoria: una pareja se queda boca arriba", bool(cards[a]["done"]) and int(game.get("pairs_left")) == 7)
	## Un fallo se vuelve a tapar.
	var c: int = -1
	var e: int = -1
	for k: int in cards.size():
		if not bool(cards[k]["done"]):
			if c < 0:
				c = k
			elif int(cards[k]["face"]) != int(cards[c]["face"]):
				e = k
				break
	game.call("flip", c)
	game.call("flip", e)
	check("memoria: no se puede destapar una tercera", not bool(game.call("can_flip", 15 if c != 15 and e != 15 else 14)))
	await frames(70)
	check("memoria: el fallo se tapa", not bool(cards[c]["open"]) and not bool(cards[e]["open"]))
	await stop_game(game)

	game = await start_game(memory_config(["......", "......", "......", "......", "......"], {"par": 24, "limit": 36}), 0)
	var done: bool = await QaBot.run(get_tree(), game, 60 * 60)
	var st: Dictionary = game.call("bot_state")
	check("memoria: el bot encuentra las 15 parejas", done and int(st["deaths"]) == 0, "intentos=%d" % int(st["tries"]))
	check("memoria: el bot no hace trampas (necesita mas de 15 intentos)", int(st["tries"]) > 15)
	await stop_game(game)

	var MapRules: GDScript = load("res://kit/memory/memory_map.gd")
	check("memoria: tablero bueno", bool(MapRules.call("analyze", {"map": tablero, "par": 12, "limit": 20})["completable"]))
	check("memoria: cartas impares detectadas", (MapRules.call("analyze", {"map": ["...", "...", "..."], "par": 12, "limit": 20})["issues"] as Array).has("memory_odd"))
	check("memoria: limite demasiado justo detectado", (MapRules.call("analyze", {"map": tablero, "par": 12, "limit": 10})["issues"] as Array).has("memory_tight_limit"))

## 20 - Progresion comun: cartera, premio diario con racha, tienda de aspectos y el aspecto
## aplicado al heroe en el juego.
func _test_telemetry() -> void:
	print("- Datos anonimos de partida")
	var antes: Dictionary = Kit.config.duplicate()
	Telemetry.queue.clear()
	Kit.config["telemetry"] = {"url": "http://127.0.0.1:9", "key": "anon", "game": "g1", "version": 2}
	Save.set_setting("telemetry", true, false)
	QA.log_event("level_start", {"level": 0})
	QA.log_event("death", {})
	QA.log_event("death", {})
	QA.log_event("level_complete", {"level": 0, "stars": 2})
	QA.log_event("level_start", {"level": 1})
	QA.log_event("level_start", {"level": 1})
	QA.log_event("level_start", {"level": 2})
	var q: Array[Dictionary] = Telemetry.queue
	check("resume cada intento (gana, reintenta, sale)", q.size() == 3 and q[0]["r"] == "gana" and int(q[0]["m"]) == 2
		and int(q[0]["e"]) == 2 and q[1]["r"] == "reintenta" and int(q[1]["n"]) == 1 and q[2]["r"] == "sale", str(q))
	check("sin nombre, cuenta ni ID: solo nivel, resultado, segundos, muertes y estrellas",
		q[0].keys().all(func(k: Variant) -> bool: return ["n", "r", "s", "m", "e"].has(k)), str(q[0].keys()))
	check("la sesion es un numero aleatorio", Telemetry.session.length() == 16)
	Save.set_setting("telemetry", false, false)
	QA.log_event("level_complete", {"level": 2, "stars": 3})
	check("si el jugador lo quita en Ajustes no se apunta nada", Telemetry.queue.size() == 3)
	Kit.config.erase("telemetry")
	Save.set_setting("telemetry", true, false)
	QA.log_event("level_start", {"level": 3})
	check("un juego sin telemetry no apunta nada", Telemetry.queue.size() == 3)
	Telemetry.queue.clear()
	Kit.config = antes


## Prueba A/B de un nivel: la mitad juega la version B y los datos dicen cual va mejor.
func _test_ab() -> void:
	print("- Prueba A/B de un nivel")
	var antes: Dictionary = Kit.config.duplicate(true)
	var idx: int = Kit.level_index
	Kit.config["levels"] = [{"name": "Uno", "map": ["A"]}, {"name": "Dos", "map": ["A1"], "speed": 1.0,
		"variant_b": {"map": ["B1"], "speed": 0.8}}]
	Kit.config["ab"] = {"level": 1, "id": "prueba"}
	Kit.level_index = 1
	Save.set_setting("ab_prueba", "b", false)
	var lv: Dictionary = Kit.current_level()
	check("ab: el grupo b juega la version B", lv["map"] == ["B1"] and is_equal_approx(float(lv["speed"]), 0.8) and not lv.has("variant_b"), str(lv))
	check("ab: el original no se toca", (Kit.config["levels"][1] as Dictionary).has("variant_b") and Kit.config["levels"][1]["map"] == ["A1"])
	Save.set_setting("ab_prueba", "a", false)
	check("ab: el grupo a juega la de siempre", Kit.current_level()["map"] == ["A1"])
	Kit.level_index = 0
	check("ab: los otros niveles igual", Kit.current_level()["map"] == ["A"])
	Save.set_setting("ab_prueba", "", false)
	var g: String = Kit.ab_group()
	check("ab: grupo al azar que se guarda", (g == "a" or g == "b") and Kit.ab_group() == g)
	Kit.ab_force = "b"
	Kit.level_index = 1
	check("ab: los bots pueden forzar la B", Kit.current_level()["map"] == ["B1"])
	Kit.ab_force = ""
	## Telemetria: solo en el nivel que se prueba se apunta la version.
	Telemetry.queue.clear()
	Kit.config["telemetry"] = {"url": "http://127.0.0.1:9", "key": "anon", "game": "g1", "version": 2}
	Save.set_setting("telemetry", true, false)
	QA.log_event("level_start", {"level": 1})
	QA.log_event("level_complete", {"level": 1, "stars": 3})
	QA.log_event("level_start", {"level": 0})
	QA.log_event("level_complete", {"level": 0, "stars": 3})
	var q: Array[Dictionary] = Telemetry.queue
	check("ab: la telemetria lleva la version en el nivel probado", q.size() == 2 and str(q[0].get("g", "")) == g and not q[1].has("g"), str(q))
	Kit.config.erase("ab")
	Kit.level_index = 1
	check("ab: sin prueba no hay grupo ni version B", Kit.ab_group() == "" and Kit.current_level()["map"] == ["A1"])
	Telemetry.queue.clear()
	Save.set_setting("ab_prueba", "", false)
	Kit.config = antes
	Kit.level_index = idx


## Laberinto, minigolf, pesca y fusion: las reglas que comparten juego, bot y analizador.
func _test_more_genres() -> void:
	print("- Laberinto, minigolf, pesca y fusion")
	var Maze: GDScript = load("res://kit/maze/maze_map.gd")
	var ok_maze: Dictionary = Maze.analyze({"map": ["#####", "#C..#", "##D##", "#LC.#", "##P##"]})
	check("laberinto: con la llave a mano se llega a todo", bool(ok_maze["completable"]), str(ok_maze["issues"]))
	var locked: Dictionary = Maze.analyze({"map": ["#####", "#L.C#", "##D##", "#.C.#", "##P##"]})
	check("laberinto: llave detras de su puerta, injusto", (locked["issues"] as Array).has("maze_key_unreachable"))
	check("laberinto: puerta sin llave, injusto", (Maze.analyze({"map": ["###", "#C#", "#D#", "#P#"]})["issues"] as Array).has("maze_bad_key"))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "maze"
	Kit.config["levels"] = [{"name": "L", "map": ["#####", "#C..#", "##D##", "#LC.#", "##P##"]}]
	Kit.level_index = 0
	var mg: Node = (load("res://scenes/maze.tscn") as PackedScene).instantiate()
	add_child(mg)
	await frames(2)
	mg.set("fast", true)
	mg.call("try_move", Vector2i.UP)
	await frames(3)
	check("laberinto: la puerta no se abre sin llave", mg.get("cell") == Vector2i(2, 3) and not mg.call("try_move", Vector2i.UP))
	mg.queue_free()
	var Golf: GDScript = load("res://kit/golf/golf_map.gd")
	var course: Array[String] = ["#####", "#.H.#", "#...#", "#...#", "#...#", "#.B.#", "#####"]
	var hole: Vector2 = Golf.find(course, "H")
	var ball: Vector2 = Golf.find(course, "B")
	check("golf: un tiro recto y suave entra", Golf.simulate(course, ball, Vector2(0.0, -7.5), hole)["state"] == "hoyo")
	check("golf: demasiado fuerte pasa por encima", Golf.simulate(course, ball, Vector2(0.0, -14.0), hole)["state"] != "hoyo"
		or Golf.simulate(course, ball, Vector2(0.0, -14.0), hole)["end"] == hole)
	var wet: Array[String] = ["#####", "#.H.#", "#WWW#", "#...#", "#.B.#", "#####"]
	check("golf: el agua para la bola", Golf.simulate(wet, Golf.find(wet, "B"), Vector2(0.0, -6.0), Golf.find(wet, "H"))["state"] == "agua")
	var g_ok: Dictionary = Golf.analyze({"map": course, "par": 2})
	check("golf: hoyo sencillo justo", bool(g_ok["completable"]) and int(g_ok["strokes"]) >= 1, str(g_ok))
	check("golf: hoyo encerrado, injusto", (Golf.analyze({"map": ["#####", "#.H.#", "#####", "#.B.#", "#####"], "par": 3})["issues"] as Array).has("golf_too_hard"))
	var Fish: GDScript = load("res://kit/fishing/fishing_map.gd")
	var lanes: Array[String] = ["....F.....", "..........", "....X....."]
	var sp: Array[float] = [0.0, 1.0, 0.0]
	check("pesca: el pez de arriba bajo el anzuelo se pesca", str(Fish.drop_result(lanes, sp, 0.0, {})[0]) == "pez")
	var lanes2: Array[String] = ["..........", "..........", "....X....."]
	check("pesca: la medusa corta el sedal", str(Fish.drop_result(lanes2, sp, 0.0, {})[0]) == "medusa")
	check("pesca: si ya esta pescado, no cuenta", str(Fish.drop_result(lanes, sp, 0.0, {Vector2i(4, 0): true})[0]) == "medusa")
	check("pesca: pocos peces para la meta, injusto", (Fish.analyze({"map": lanes, "speeds": [1.0, -1.0, 1.0], "goal": 3, "time": 30.0})["issues"] as Array).has("fishing_not_enough_fish"))
	var Merge: GDScript = load("res://kit/merge/merge_map.gd")
	var b: Array[int] = [0, 0, 0, 0, 0, 0, 1, 0, 0, 2, 1, 0]
	var r: Array = Merge.drop(b, 3, 4, 0, 1)
	check("fusion: dos iguales se juntan y encadenan", (r[0] as Array).count(0) == 10 and Merge.max_value(r[0]) == 3, str(r))
	var full: Array[int] = [1, 2, 3, 4]
	check("fusion: columna llena no admite mas", Merge.drop(full, 1, 4, 0, 1).is_empty())
	var m_ok: Dictionary = Merge.analyze({"map": [".....", ".....", ".....", ".....", ".....", ".....", "....."], "seq": [1, 1, 2, 1, 3, 2], "goal": 5})
	check("fusion: meta alcanzable con la secuencia", bool(m_ok["completable"]), str(m_ok))
	Kit.config = keep
	Kit.level_index = 0


## Burbujas: fisica del disparo, explotar y caer, analizador y bot jugando de verdad.
func _test_bubble() -> void:
	print("- Burbujas")
	var B: GDScript = load("res://kit/bubble/bubble_map.gd")
	var g: Dictionary = B.parse({"map": ["aab....."]})
	var r: Array = B.place(g, Vector2i(1, 0), "a")
	check("burbujas: 3 iguales explotan", int(r[1]) == 3 and not (r[0] as Dictionary).has(Vector2i(0, 0)), str(r))
	var g2: Dictionary = B.parse({"map": ["aa......", "b......"]})
	var r2: Array = B.place(g2, Vector2i(0, 2), "a")
	check("burbujas: lo que queda suelto cae", int(r2[1]) == 3 and int(r2[2]) == 1 and (r2[0] as Dictionary).is_empty(), str(r2))
	var t: Array = B.trace({}, 12, 0.0)
	check("burbujas: disparo recto llega al techo", (t[1] as Vector2i).x == 0, str(t[1]))
	var t2: Array = B.trace({}, 12, 1.2)
	check("burbujas: rebota en la pared", (t2[0] as PackedVector2Array).size() >= 3 and (t2[1] as Vector2i).x == 0, str(t2[1]))
	var lv: Dictionary = {"map": ["aabbccaa", "abbcca.", "ccaabbcc"], "shots": 30, "lose_row": 12, "seed": 5}
	var an: Dictionary = B.analyze(lv)
	check("burbujas: nivel justo (el bot lo vacia)", bool(an["completable"]) and int(an["bot_shots"]) > 0, str(an))
	check("burbujas: sin disparos suficientes, injusto", (B.analyze({"map": lv["map"], "shots": 2, "lose_row": 12, "seed": 5})["issues"] as Array).has("bubble_too_hard"))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "bubble"
	Kit.config["levels"] = [lv]
	Kit.level_index = 0
	var game: Node = (load("res://scenes/bubble.tscn") as PackedScene).instantiate()
	add_child(game)
	await frames(2)
	game.set("fast", true)
	var Bot: GDScript = load("res://qa/bubble_bot.gd")
	var won: bool = await Bot.run(get_tree(), game, 4000)
	check("burbujas: el bot lo vacia jugando de verdad, con los mismos disparos", won and int(game.get("shots")) == int(an["bot_shots"]), str([game.get("shots"), an["bot_shots"]]))
	if game.get("result_panel") != null:
		(game.get("result_panel") as Node).queue_free()
	game.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Puzle de tubos: reglas, solucionador, analizador y el bot jugando de verdad.
func _test_sort() -> void:
	print("- Tubos (ordenar colores)")
	var Sort: GDScript = load("res://kit/sort/sort_map.gd")
	var t: Array[String] = ["ab", "ba", ""]
	check("tubos: se vierte sobre el mismo color o en vacio", Sort.can_pour(t, 0, 2, 2) and not Sort.can_pour(t, 0, 1, 2) and not Sort.can_pour(t, 2, 0, 2))
	var t2: Array[String] = Sort.pour(["aab", "b", ""] as Array[String], 0, 1, 4)
	check("tubos: pasa el bloque de arriba entero", t2 == (["aa", "bb", ""] as Array[String]), str(t2))
	var t3: Array[String] = Sort.pour(["abbb", "abb", ""] as Array[String], 0, 1, 4)
	check("tubos: solo lo que cabe", t3 == (["abb", "abbb", ""] as Array[String]), str(t3))
	check("tubos: resuelto con un color por tubo", Sort.solved(["aaaa", "", "bbbb"] as Array[String], 4) and not Sort.solved(["aaab", "b", "bba"] as Array[String], 4))
	var lv: Dictionary = {"map": ["abab", "baba", ".", "."], "cap": 4}
	var an: Dictionary = Sort.analyze(lv)
	check("tubos: nivel con solucion y su par", bool(an["completable"]) and int(an["par"]) > 0, str(an))
	check("tubos: un color de mas, injusto", (Sort.analyze({"map": ["abab", "bab", ".", "."], "cap": 4})["issues"] as Array).has("sort_color_count"))
	check("tubos: sin hueco no hay solucion", (Sort.analyze({"map": ["abab", "baba"], "cap": 4})["issues"] as Array).has("sort_tubes")
		or (Sort.analyze({"map": ["abab", "baba"], "cap": 4})["issues"] as Array).has("sort_unsolvable"))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "sort"
	Kit.config["levels"] = [{"name": "T", "map": ["abca", "bcbb", "acca", ".", "."], "cap": 4, "par": 9}]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/sort.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	g.set("fast", true)
	check("tubos: no vierte sobre otro color", not bool(g.call("pour", 0, 1)))
	g.call("tap", 0)
	g.call("tap", 3)
	await frames(4)
	check("tubos: tocar dos tubos vierte", (g.get("tubes") as Array)[3] == "a" and int(g.get("moves")) == 1)
	g.call("undo")
	check("tubos: deshacer vuelve atras", (g.get("tubes") as Array)[0] == "abca" and int(g.get("moves")) == 0)
	var Bot: GDScript = load("res://qa/sort_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 3000)
	check("tubos: el bot lo resuelve con el par", won and int(g.get("moves")) == 9 and g.call("stars_earned") == 3, str(g.get("moves")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Imperio (estrategia en tiempo real): reglas, analizador y el bot ganando una partida entera.
## Con ORQ_EMPIRE_BATCH=<json> juega cada nivel del archivo y escribe los tiempos (calibracion).
func _test_empire() -> void:
	print("- Imperio (estrategia en tiempo real)")
	var M: GDScript = load("res://kit/empire/empire_map.gd")
	check("imperio: el lancero gana al jinete", M.hit("lancero", "jinete", 1) > M.hit("lancero", "arquero", 1) * 2.5)
	check("imperio: el arquero apenas hace dano al ariete", M.hit("arquero", "ariete", 1) < M.hit("arquero", "jinete", 1) * 0.3)
	check("imperio: el ariete no ataca tropas y si edificios", M.hit("ariete", "lancero", 1) == 0.0 and M.hit("ariete", "", 1) > M.hit("jinete", "", 1) * 5.0)
	check("imperio: cada edad hace mas fuerte", M.hit("lancero", "lancero", 3) > M.hit("lancero", "lancero", 1))
	var map: Array = ["....................", "....................", ".....BB......OO.....", ".....BB..E...OOO....", ".....B..........T...",
		"....c...........TT..", "..........h.....TTT.", "TTTT.............TTT", "TTTT.............TTT", "TTTT..............TT",
		"....................", "....................", "....................", "~~~~~~~...~~~~~~..~~", "~~..~~~~...~~~~~~~~~",
		"....................", "....................", "....................", "TT..............TTTT", "TTT.............TTTT",
		"TTT.............TTTT", ".T..................", "....OOO.P.....B.....", "...OO.........BB....", "..............BB....",
		"....................", "....................", "...................."]
	var an: Dictionary = M.analyze({"map": map})
	check("imperio: mapa justo", bool(an["completable"]), str(an["issues"]))
	var bad: Array = map.duplicate()
	bad[13] = "~~~~~~~~~~~~~~~~~~~~"
	bad[14] = "~~~~~~~~~~~~~~~~~~~~"
	check("imperio: sin paso al rival no vale", (M.analyze({"map": bad})["issues"] as Array).has("empire_unreachable"))
	var poor: Array = map.duplicate()
	poor[22] = "........P.....B....."
	poor[23] = "..............BB...."
	check("imperio: sin oro cerca no vale", (M.analyze({"map": poor})["issues"] as Array).has("empire_few_gold"))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "empire"
	var lv: Dictionary = {"name": "I", "map": map, "start": {"comida": 200, "madera": 220, "oro": 100}, "villagers": 3,
		"ai": {"income": 0.8, "first_wave": 240, "wave_every": 120, "wave_size": 3, "wave_grow": 1, "age2_at": 300, "age3_at": 600, "max_army": 16}, "par": 660}
	Kit.config["levels"] = [lv]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/empire.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	check("imperio: empiezas con 3 aldeanos y un centro", int(g.call("count_units", "aldeano", 0)) == 3 and g.call("main_center", 0) >= 0)
	check("imperio: entrenar cobra", bool(g.call("train", "aldeano")) and float(((g.get("stock") as Array)[0] as Dictionary)["comida"]) == 150.0)
	check("imperio: sin cuartel no hay lanceros", not bool(g.call("train", "lancero")))
	var spot: Vector2i = g.call("find_spot", "casa")
	check("imperio: hay sitio para una casa y se construye", spot.x >= 0 and bool(g.call("place", "casa", spot)))
	check("imperio: no se construye encima", not bool(g.call("place", "casa", spot)))
	check("imperio: torres solo en la Edad II", not bool(g.call("can_place", "torre", g.call("find_spot", "casa"))))
	check("imperio: sin niebla se ve todo", bool(g.call("visible_at", Vector2(10.5, 4.5))))
	lv["fog"] = true
	g.call("retry")
	check("imperio: con niebla no se ve la base rival y si la tuya", not bool(g.call("explored_at", Vector2(10.5, 4.5)))
		and bool(g.call("visible_at", Vector2(9.5, 23.5))))
	lv.erase("fog")
	g.call("retry")
	g.set("fast", true)
	await frames(60)
	check("imperio: los aldeanos traen recursos", float(((g.get("stock") as Array)[0] as Dictionary)["madera"]) > 190.0 - 30.0 + 5.0
		or float(((g.get("stock") as Array)[0] as Dictionary)["comida"]) > 160.0, str((g.get("stock") as Array)[0]))
	g.call("retry")
	var Bot: GDScript = load("res://qa/empire_bot.gd")
	var t0: int = Time.get_ticks_msec()
	var won: bool = await Bot.run(get_tree(), g, 4000)
	check("imperio: el bot conquista el reino rival", won and int(g.get("deaths")) == 0, "t=%.0f s, %s" % [float(g.get("time_in_level")), str(g.call("bot_state"))])
	print("    (partida de %.0f s de juego en %d ms, %d estrellas)" % [float(g.get("time_in_level")), Time.get_ticks_msec() - t0, int(g.call("stars_earned"))])
	## Plantilla por datos: estilo galactico (nombres y numeros) y una tropa cambiada por el juego.
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	M.apply({"empire": {"preset": "galactico", "units": {"lancero": {"name": "Soldado de plasma", "hp": 70.0}}}})
	check("imperio plantilla: el estilo galactico pone nombres y recursos", str(M.custom_name("aldeano")) == "Dron minero" and str(M.res_names.get("oro", "")) == "cristal"
		and float(M.units["jinete"]["speed"]) == 3.0)
	check("imperio plantilla: lo del juego va encima del estilo", str(M.custom_name("lancero")) == "Soldado de plasma" and float(M.units["lancero"]["hp"]) == 70.0)
	M.apply({})
	check("imperio plantilla: sin datos, todo como siempre", str(M.custom_name("lancero")) == "" and float(M.units["lancero"]["hp"]) == 60.0)
	var lvg: Dictionary = lv.duplicate(true)
	lvg["empire"] = {"preset": "galactico"}
	Kit.config["levels"] = [lvg]
	g = (load("res://scenes/empire.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	check("imperio plantilla: la escena usa los nombres del estilo", str(g.call("_name", "lancero")) == "Marine" and str(g.call("_cost_text", {"oro": 50})) == "50C")
	var won_g: bool = await Bot.run(get_tree(), g, 4000)
	check("imperio plantilla: el bot conquista tambien en el estilo galactico", won_g, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	var batch: String = OS.get_environment("ORQ_EMPIRE_BATCH")
	if batch != "" and FileAccess.file_exists(batch):
		var lvls: Array = JSON.parse_string(FileAccess.get_file_as_string(batch))
		var out: Array = []
		for k: int in lvls.size():
			Kit.config["levels"] = [lvls[k]]
			Kit.level_index = 0
			var g2: Node = (load("res://scenes/empire.tscn") as PackedScene).instantiate()
			add_child(g2)
			await frames(2)
			g2.set("fast", true)
			var ok: bool = false
			if OS.get_environment("ORQ_EMPIRE_DEBUG") != "":
				g2.set("auto_retry", true)
				for fr: int in 1500:
					await get_tree().physics_frame
					if bool(g2.get("finished")) or int(g2.get("deaths")) > 0:
						break
					Bot.step(g2)
					if fr % 50 == 0:
						var st0: Dictionary = (g2.get("stock") as Array)[0]
						print("      t=%d v=%d(%d/%d/%d) ej=%d riv=%d edad=%d pob=%d/%d c=%d m=%d o=%d" % [int(g2.get("time_in_level")), int(g2.call("count_units", "aldeano", 0)),
							int(g2.call("workers", "comida")), int(g2.call("workers", "madera")), int(g2.call("workers", "oro")), int(g2.call("army_count", 0)),
							int(g2.call("army_count", 1)), int((g2.get("age") as Array)[0]), int(g2.call("pop", 0)), int(g2.call("pop_cap", 0)),
							int(st0["comida"]), int(st0["madera"]), int(st0["oro"])] + " esc=%d alm=%d gr=%d at=%d rb=%d" % [int(g2.call("hidden_count")),
							int(g2.call("count_buildings", "almacen", 0)), int(g2.call("count_buildings", "granja", 0)), int(g2.call("attacking", 0)), int(g2.get("coins_total")) - int(g2.get("coins"))])
				ok = bool(g2.get("finished")) and not bool(g2.get("failed"))
			else:
				ok = await Bot.run(get_tree(), g2, 5000)
			out.append({"i": k, "won": ok, "time": snappedf(float(g2.get("time_in_level")), 1.0), "deaths": int(g2.get("deaths")),
				"stars": int(g2.call("stars_earned")), "state": g2.call("bot_state")})
			print("    lote %d: %s" % [k, str(out[-1])])
			if g2.get("result_panel") != null:
				(g2.get("result_panel") as Node).queue_free()
			g2.queue_free()
			await frames(2)
		var f: FileAccess = FileAccess.open(batch + ".out.json", FileAccess.WRITE)
		f.store_string(JSON.stringify(out))
	Kit.config = keep
	Kit.level_index = 0


## Minas (idle de excavar): cadena pozo -> ascensor -> almacen, gerentes, mejoras y el bot.
## Con ORQ_MINE_CALIB=1 escribe cuanto tarda el bot en llegar a varias metas (calibracion).
func _test_mine() -> void:
	print("- Minas (idle de excavar)")
	var M: GDScript = load("res://kit/mine/mine_map.gd")
	if OS.get_environment("ORQ_MINE_CALIB") != "":
		for n: int in [3, 4, 5, 6, 7, 8]:
			var line: String = "    pozos %d:" % n
			for goal: float in [2000.0, 10000.0, 50000.0, 250000.0, 1000000.0, 5000000.0, 25000000.0]:
				var mp: Array = []
				for k: int in n:
					mp.append(M.ORES[k])
				line += " %s=%d" % [str(int(goal)), int(M.bot_time({"map": mp, "goal": goal, "start": 0}, 3000.0))]
			print(line)
		return
	var st: Dictionary = M.new_state({"map": ["c", "h", "o"], "goal": 5000, "start": 0})
	check("minas: empieza con el primer pozo abierto", bool(st["shafts"][0]["open"]) and not bool(st["shafts"][1]["open"]))
	check("minas: sin tocar no pasa nada", (func() -> bool:
		M.step(st, 5.0)
		return float(st["shafts"][0]["box"]) == 0.0).call())
	check("minas: tocar el pozo saca mineral", M.tap(st, "shaft", 0) and (func() -> bool:
		for k: int in 20:
			M.step(st, 0.25)
		return float(st["shafts"][0]["box"]) > 0.0).call())
	M.tap(st, "elev")
	for k: int in 20:
		M.step(st, 0.25)
	check("minas: el ascensor lo sube", float(st["surface"]) > 0.0 and float(st["shafts"][0]["box"]) == 0.0)
	M.tap(st, "ware")
	for k: int in 40:
		M.step(st, 0.25)
	check("minas: el almacen lo vende", float(st["cash"]) > 0.0 and float(st["surface"]) == 0.0, str(st["cash"]))
	st["cash"] = 1000.0
	check("minas: mejorar cobra y sube el nivel", M.upgrade(st, "shaft", 0) and int(st["shafts"][0]["lvl"]) == 2 and float(st["cash"]) < 1000.0)
	check("minas: contratar gerente y trabaja solo", M.hire(st, "elev") and bool(st["elev"]["mgr"]))
	check("minas: impulso solo con gerente", M.boost(st, "elev") and not M.boost(st, "ware"))
	check("minas: cada pozo vale mas", M.dig_amount(2, 1) > M.dig_amount(1, 1) * 5.0)
	var an: Dictionary = M.analyze({"map": ["c", "h", "b", "p"], "goal": 6000, "start": 0})
	check("minas: nivel justo con su par", bool(an["completable"]) and int(an["par"]) > 45, str(an))
	check("minas: una meta imposible no vale", not bool(M.analyze({"map": ["c", "h", "b"], "goal": 1e30, "start": 0})["completable"]))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "mine"
	Kit.config["levels"] = [{"name": "M", "map": ["c", "h", "b", "p"], "goal": 6000, "start": 0, "par": int(an["par"])}]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/mine.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	check("minas: tocar en el mundo elige y trabaja", (func() -> bool:
		g.call("tap_world", Vector2(420, 330 + 105))
		return (g.get("selected") as Array)[0] == "shaft" and bool((g.get("st") as Dictionary)["shafts"][0]["busy"])).call())
	check("minas: formato de cifras", g.call("fmt", 1234567.0) == "1.23M" and g.call("fmt", 950.0) == "950")
	var Bot: GDScript = load("res://qa/mine_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 3000)
	check("minas: el bot llega a la meta", won and int(g.call("stars_earned")) == 3, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Mazmorras (RPG de accion): salas, puertas, combate, habilidades, cofres y el bot venciendo al jefe.
func _test_dungeon() -> void:
	print("- Mazmorras (RPG de accion)")
	var M: GDScript = load("res://kit/dungeon/dungeon_map.gd")
	var lv: Dictionary = {"name": "D", "map": ["#TB", "MEM", "#S#"], "power": 0.9, "seed": 3, "par": 400}
	var an: Dictionary = M.analyze(lv)
	check("mazmorras: planta justa", bool(an["completable"]), str(an["issues"]))
	check("mazmorras: jefe pegado a la salida no vale", (M.analyze({"map": ["SB", "M#", "M#"]})["issues"] as Array).has("dungeon_boss_close"))
	check("mazmorras: sala suelta no vale", (M.analyze({"map": ["S#B", "M#M", "MMM", "#T#"]})["issues"] as Array).is_empty()
		and (M.analyze({"map": ["SMM#B", "#####", "MMMMM"]})["issues"] as Array).has("dungeon_unreachable"))
	var p: Dictionary = M.parse(lv)
	var tl: Array[String] = M.room_tiles(p["rooms"], Vector2i(1, 1), 3)
	check("mazmorras: puertas donde hay vecinas", tl[0][5] == "." and tl[14][5] == "." and tl[7][0] == "." and tl[7][10] == ".", str(tl))
	check("mazmorras: la salida no tiene monstruos y el jefe si", M.room_enemies(p["rooms"], Vector2i(1, 2), 3, 0).is_empty()
		and str(M.room_enemies(p["rooms"], Vector2i(2, 0), 3, 0)[0][0]) == "boss")
	var keep: Dictionary = Kit.config.duplicate(true)
	var keep_gear: Variant = Save.meta().get("dungeon_gear")
	Kit.config["genre"] = "dungeon"
	Kit.config["levels"] = [lv]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/dungeon.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	check("mazmorras: empiezas en la salida con la vida llena", g.get("cell") == Vector2i(1, 2) and float((g.get("hero") as Dictionary)["hp"]) == float(g.call("max_hp")))
	g.set("move_dir", Vector2.UP)
	await frames(240)
	check("mazmorras: andar hacia la puerta abierta cambia de sala", g.get("cell") == Vector2i(1, 1), str(g.get("cell")))
	check("mazmorras: la sala nueva tiene monstruos y las puertas cerradas", int(g.call("alive_enemies")) > 0 and bool(g.call("solid", Vector2i(5, 0))))
	g.set("move_dir", Vector2.ZERO)
	var hp_sum: float = 0.0
	for e: Dictionary in g.get("enemies"):
		hp_sum += float(e["hp"])
	await frames(90)
	var hp_now: float = 0.0
	for e: Dictionary in g.get("enemies"):
		hp_now += maxf(0.0, float(e["hp"]))
	check("mazmorras: quieto dispara solo y hace dano", hp_now < hp_sum, "%d -> %d" % [int(hp_sum), int(hp_now)])
	var h: Dictionary = g.get("hero")
	h["xp"] = int(g.call("xp_need")) - 1
	g.call("_hurt_enemy", (g.get("enemies") as Array)[0], 9999.0, false)
	check("mazmorras: subir de nivel ofrece 3 habilidades", (g.get("choices") as Array).size() == 3)
	var first: String = str((g.get("choices") as Array)[0])
	g.call("choose_skill", 0)
	check("mazmorras: elegir habilidad la suma", int((g.get("skills") as Dictionary).get(first, 0)) == 1 and (g.get("choices") as Array).is_empty())
	(g.get("gear") as Dictionary).clear()
	var d0: float = float(g.call("damage"))
	(g.get("gear") as Dictionary)["arma"] = {"slot": "arma", "rarity": 3, "bonus": 60.0}
	check("mazmorras: el equipo sube el dano", float(g.call("damage")) > d0 * 1.5)
	(g.get("gear") as Dictionary).erase("arma")
	g.call("retry")
	var Bot: GDScript = load("res://qa/dungeon_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 12000)
	check("mazmorras: el bot vence al jefe", won and int(g.get("deaths")) <= 1, str(g.call("bot_state")))
	print("    (%.0f s, muertes %d, nivel %d)" % [float(g.get("time_in_level")), int(g.get("deaths")), int((g.get("hero") as Dictionary)["lvl"])])
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	var batch: String = OS.get_environment("ORQ_DUNGEON_BATCH")
	if batch != "" and FileAccess.file_exists(batch):
		var lvls: Array = JSON.parse_string(FileAccess.get_file_as_string(batch))
		var out: Array = []
		for k: int in lvls.size():
			Kit.config["levels"] = [lvls[k]]
			Kit.level_index = int(str(lvls[k].get("_tag", "x-0")).get_slice("-", 1))
			var g2: Node = (load("res://scenes/dungeon.tscn") as PackedScene).instantiate()
			add_child(g2)
			await frames(2)
			(g2.get("gear") as Dictionary).clear()
			var ok: bool = await Bot.run(get_tree(), g2, 30000)
			out.append({"i": k, "won": ok, "time": snappedf(float(g2.get("time_in_level")), 1.0), "deaths": int(g2.get("deaths")),
				"state": g2.call("bot_state")})
			print("    lote %d %s: %s" % [k, str(lvls[k].get("_tag", "")), str(out[-1])])
			if g2.get("result_panel") != null:
				(g2.get("result_panel") as Node).queue_free()
			g2.queue_free()
			await frames(2)
		var f: FileAccess = FileAccess.open(batch + ".out.json", FileAccess.WRITE)
		f.store_string(JSON.stringify(out))
	if keep_gear == null:
		Save.meta().erase("dungeon_gear")
	else:
		Save.meta()["dungeon_gear"] = keep_gear
	Kit.config = keep
	Kit.level_index = 0


## Granja cozy: cultivos, animales, maquinas, pedidos y el bot cumpliendo la meta.
func _test_farm() -> void:
	print("- Granja cozy")
	var M: GDScript = load("res://kit/farm/farm_map.gd")
	var maps: Array = [
		{"map": [",,....,,", ",,....,,", "h,,,,,,t"], "crops": ["trigo", "maiz"], "goal": 4},
		{"map": [",,....,,", ",,....GM", "h,,,,,P,"], "crops": ["trigo", "maiz"], "goal": 6},
		{"map": ["......,,", "......GM", "h,V,Q,PT"], "crops": ["trigo", "maiz", "fresa"], "goal": 8},
		{"map": ["......,,", "......GM", "hOVJQ,PT"], "crops": ["trigo", "maiz", "zanahoria", "fresa", "calabaza"], "goal": 10},
	]
	if OS.get_environment("ORQ_FARM_CALIB") != "":
		for lv: Dictionary in maps:
			lv["seed"] = 3
			print("    ", lv["goal"], " pedidos, ", M.available(lv), ": ", M.bot_time(lv))
		return
	var lv: Dictionary = {"name": "F", "map": [",,....,,", ",,....GM", "h,,,,,P,"], "crops": ["trigo", "maiz"], "goal": 4, "seed": 5, "coins": 20}
	var st: Dictionary = M.new_state(lv)
	check("granja: tres pedidos en el tablon", (st["orders"] as Array).size() == 3)
	check("granja: sembrar cobra la semilla", M.plant(st, 0, "trigo") and float(st["coins"]) == 19.0 and not M.plant(st, 0, "maiz"))
	check("granja: no se cosecha verde", not M.harvest(st, 0))
	M.step(st, 25.0)
	check("granja: madura y da 2", M.harvest(st, 0) and M.count(st, "trigo") == 2)
	st["inv"] = {"trigo": 4, "maiz": 2}
	var mi: int = -1
	for k: int in (st["machines"] as Array).size():
		if str(st["machines"][k]["key"]) == "M":
			mi = k
	check("granja: el molino hace pienso con trigo y maiz", M.make(st, mi, "pienso") and M.count(st, "trigo") == 2)
	M.step(st, 11.0)
	check("granja: se recoge lo hecho", M.collect(st, mi) == 1 and M.count(st, "pienso") == 3)
	check("granja: la gallina come y luego pone", M.tend(st, 0) and (func() -> bool:
		M.step(st, 31.0)
		return M.tend(st, 0) and M.count(st, "huevo") == 1).call())
	st["orders"][0] = {"items": {"huevo": 1}, "reward": 30, "xp": 1}
	check("granja: entregar cobra y saca otro pedido", M.deliver(st, 0) and int(st["done"]) == 1 and float(st["coins"]) >= 30.0)
	check("granja: rechazar tiene espera", M.reject(st, 1) and not M.reject(st, 2))
	var an: Dictionary = M.analyze(lv)
	check("granja: nivel justo con su par", bool(an["completable"]) and int(an["par"]) > 0, str(an))
	check("granja: sin parcelas no vale", not bool(M.analyze({"map": ["hGM,"], "crops": ["trigo"], "goal": 2})["completable"]))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "farm"
	lv["par"] = int(an["par"])
	Kit.config["levels"] = [lv]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/farm.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	g.call("tap_cell", Vector2i(2, 0))
	check("granja: tocar una parcela vacia siembra", str((g.get("st") as Dictionary)["plots"][0]["crop"]) == "trigo")
	var Bot: GDScript = load("res://qa/farm_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 4000)
	check("granja: el bot cumple los pedidos", won and int(g.call("stars_earned")) >= 2, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Mazo (cartas de estrategia): cartas, intenciones, estados, recompensas y el bot ganando.
func _test_deck() -> void:
	print("- Mazo (cartas de estrategia)")
	var M: GDScript = load("res://kit/deck/deck_map.gd")
	var lv: Dictionary = {"name": "D", "map": ["slime", "bandido", "caballero"], "power": 1.0, "hp": 70, "seed": 4}
	var run: Dictionary = M.new_run(lv)
	check("mazo: empiezas con 5 cartas y 3 de energia", (run["f"]["hand"] as Array).size() == 5 and int(run["f"]["energy"]) == 3)
	var f: Dictionary = run["f"]
	f["hand"] = ["golpe", "defensa", "furia", "golpe_pesado", "veneno"]
	var e0: int = int(f["ehp"])
	check("mazo: golpe quita 6", M.play(run, 0) and int(f["ehp"]) == e0 - 6 and int(f["energy"]) == 2)
	check("mazo: defensa bloquea 5", M.play(run, 0) and int(f["block"]) == 5)
	check("mazo: furia da fuerza para siempre", M.play(run, 0) and int(f["str"]) == 2 and (f["exhaust"] as Array).has("furia"))
	check("mazo: sin energia no se juega", not M.play(run, 0))
	var hp0: int = int(run["hp"])
	var inc: int = M.incoming(run)
	M.end_turn(run)
	check("mazo: el bloqueo para el ataque", int(run["hp"]) == hp0 - maxi(0, inc - 5), "%d %d %d" % [hp0, inc, int(run["hp"])])
	check("mazo: turno nuevo con 5 cartas y el bloqueo a cero", (run["f"]["hand"] as Array).size() == 5 and int(run["f"]["block"]) == 0)
	run["f"]["ehp"] = 1
	run["f"]["hand"] = ["golpe"]
	run["f"]["energy"] = 3
	M.play(run, 0)
	check("mazo: al ganar un combate salen 3 cartas de premio", (run["reward"] as Array).size() == 3)
	var deck_n: int = (run["deck"] as Array).size()
	M.pick_reward(run, 0)
	check("mazo: la carta elegida va al mazo y empieza el siguiente", (run["deck"] as Array).size() == deck_n + 1 and int(run["fight"]) == 1)
	var an: Dictionary = M.analyze(lv)
	check("mazo: nivel justo con su par", bool(an["completable"]) and int(an["par"]) > 0, str(an))
	check("mazo: enemigo raro no vale", not bool(M.analyze({"map": ["slime", "pato"]})["completable"]))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "deck"
	lv["par"] = int(an["par"])
	Kit.config["levels"] = [lv]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/deck.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	check("mazo: la mano se ve con sus cartas", g.find_child("Card_0", true, false) != null and g.find_child("Card_4", true, false) != null)
	var Bot: GDScript = load("res://qa/deck_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 3000)
	check("mazo: el bot gana todos los combates", won and int(g.get("deaths")) == 0, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Aventura (historia con decisiones): requisitos, efectos, finales, analizador y el bot.
func _test_tale() -> void:
	print("- Aventura (historia con decisiones)")
	var M: GDScript = load("res://kit/tale/tale_map.gd")
	var lv: Dictionary = {"name": "C1", "title": "1. La prueba", "map": ["historia"],
		"scenes": [
			{"id": "a", "who": "narrador", "text": "Empieza la aventura.", "options": [
				{"text": "Ser valiente", "to": "b", "fx": {"valor": 1}}, {"text": "Ser amable", "to": "c", "fx": {"amistad": 1, "objeto": "llave"}}]},
			{"id": "b", "who": "heroe", "text": "Una puerta cerrada.", "options": [
				{"text": "Abrirla", "to": "FIN_BUENO", "need": {"objeto": "llave"}}, {"text": "Romperla", "to": "FIN_REGULAR", "need": {"stat": "valor", "min": 1}},
				{"text": "Volver", "to": "a"}]},
			{"id": "c", "who": "aliado", "text": "Toma esta llave.", "options": [{"text": "Ir a la puerta", "to": "b"}, {"text": "Irte a casa", "to": "FIN_MALO"}]}],
		"endings": {"bueno": "Bien.", "regular": "Regular.", "malo": "Mal."}}
	var an: Dictionary = M.analyze(lv)
	check("aventura: capitulo justo con su camino", bool(an["completable"]) and int(an["par"]) == 3, str(an))
	check("aventura: el camino al final bueno pasa por la llave", M.path_to(lv, "bueno") == [1, 0, 0])
	check("aventura: sin la llave no se abre", not M.allowed(lv["scenes"][1]["options"][0], {"valor": 5}, []))
	var r: Array = M.apply({"fx": {"oro": 3, "objeto": "mapa"}}, {"oro": 1}, [])
	check("aventura: los efectos suman y dan objetos", int(r[0]["oro"]) == 4 and (r[1] as Array).has("mapa"))
	var bad: Dictionary = lv.duplicate(true)
	bad["scenes"][0]["options"][0]["to"] = "zzz"
	check("aventura: destino que no existe no vale", (M.analyze(bad)["issues"] as Array).has("tale_target"))
	var dead: Dictionary = lv.duplicate(true)
	dead["scenes"][1]["options"] = [{"text": "Abrirla", "to": "FIN_BUENO", "need": {"objeto": "nada"}}]
	check("aventura: sin final bueno posible no vale", (M.analyze(dead)["issues"] as Array).has("tale_no_good_end"))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "tale"
	Kit.config["levels"] = [lv]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/tale.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	g.call("_reveal")
	await frames(2)
	check("aventura: salen las decisiones", g.find_child("Choice_1", true, false) != null)
	check("aventura: elegir cambia de escena y de estadisticas", bool(g.call("choose", 1)) and str(g.get("scene_id")) == "c"
		and int((g.get("stats") as Dictionary)["amistad"]) == 1)
	g.call("retry")
	var Bot: GDScript = load("res://qa/tale_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 600)
	check("aventura: el bot llega al final bueno", won and int(g.call("stars_earned")) == 3, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Cocina (gestion de tiempo): plancha, quemado, orden de la bandeja, servir, analizador y bot.
func _test_cook() -> void:
	print("- Cocina (gestion de tiempo)")
	var M: GDScript = load("res://kit/cook/cook_map.gd")
	var lv: Dictionary = {"name": "K", "map": ["hamburguesa", "refresco"], "goal": 60, "customers": 10, "patience": 30.0,
		"seconds": 120, "seed": 3}
	var st: Dictionary = M.new_state(lv)
	check("cocina: menu y bandejas listos", (st["menu"] as Array).size() == 2 and (st["trays"] as Array).size() == 2)
	check("cocina: la carne va a la plancha", M.start_cook(st, "carne") and M.cook_state("carne", 0.0) == "raw")
	check("cocina: carne cruda no se coge", M.add(st, 0, "pan") and not M.add(st, 0, "carne"))
	st["grill"]["carne"][0]["t"] = 6.0
	check("cocina: carne hecha si", M.add(st, 0, "carne") and M.add(st, 0, "lechuga") and M.tray_dish(st, st["trays"][0]) == "hamburguesa")
	check("cocina: en otro orden no vale", not M.add(st, 1, "lechuga"))
	check("cocina: la carne se quema si se deja", M.cook_state("carne", 13.0) == "burnt")
	st["seats"][0] = {"order": ["hamburguesa"], "got": [], "patience": 30.0, "max": 30.0}
	var c0: int = int(st["coins"])
	check("cocina: servir cobra con propina", M.serve(st, 0, 0) and int(st["coins"]) == c0 + 12 + 6 and (st["seats"][0] as Dictionary).is_empty())
	check("cocina: sin cliente no se sirve", not M.serve(st, 1, 0))
	var an: Dictionary = M.analyze(lv)
	check("cocina: nivel justo con su par", bool(an["completable"]) and int(an["par"]) > 0, str(an))
	check("cocina: plato raro no vale", not bool(M.analyze({"map": ["pizza_marciana"]})["completable"]))
	check("cocina: meta imposible no vale", not bool(M.analyze({"map": ["refresco"], "goal": 9999, "customers": 5, "seconds": 60})["completable"]))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "cook"
	lv["par"] = int(an["par"])
	Kit.config["levels"] = [lv]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/cook.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	var Bot: GDScript = load("res://qa/cook_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 9000)
	check("cocina: el bot llega a la meta", won and int(g.get("deaths")) == 0, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Mahjong solitario: fichas libres, parejas, reparto con solucion, barajar, analizador y bot.
func _test_mahjong() -> void:
	print("- Mahjong (parejas de fichas)")
	var M: GDScript = load("res://kit/mahjong/mahjong_map.gd")
	var lv: Dictionary = {"name": "M", "map": ["1221", "1331", "1221"], "kinds": 6, "seed": 4, "shuffles": 2}
	var tiles: Array = M.parse(lv)
	check("mahjong: las pilas dan sus fichas", tiles.size() == 20 and int(tiles[tiles.size() - 1]["z"]) == 2)
	var all: Array = []
	all.resize(tiles.size())
	all.fill(true)
	var fr: Array = M.free_tiles(tiles, all)
	var only_ends: bool = true
	for i: int in fr:
		var t: Dictionary = tiles[i]
		if int(t["z"]) == 0 and int(t["x"]) != 0 and int(t["x"]) != 3:
			only_ends = false
	check("mahjong: libres solo las de arriba y las de los extremos", not fr.is_empty() and only_ends, str(fr))
	var st: Dictionary = M.new_state(lv)
	check("mahjong: reparto con solucion", bool(st["ok"]) and (st["order"] as Array).size() == 10)
	var a: int = -1
	var b: int = -1
	for i: int in fr:
		for j: int in fr:
			if i < j and int(st["faces"][i]) != int(st["faces"][j]) and a < 0:
				a = i
				b = j
	check("mahjong: dibujos distintos no casan", a < 0 or not M.match_pair(st, a, b))
	var occ: Dictionary = M.occupancy(st["tiles"], st["alive"])
	var blocked: int = -1
	for i: int in tiles.size():
		if not M.is_free(st["tiles"], occ, i):
			blocked = i
			break
	check("mahjong: una ficha tapada no se quita", blocked >= 0 and not M.match_pair(st, blocked, blocked))
	var p: Array = M.bot_pick(st)
	check("mahjong: la pareja de la solucion se quita", p.size() == 2 and M.match_pair(st, int(p[0]), int(p[1])) and int(st["left"]) == 18)
	check("mahjong: barajar gasta una y deja solucion", M.shuffle(st) and int(st["shuffles"]) == 1 and not M.hint(st).is_empty())
	var stack: Dictionary = {"map": ["11", "2."], "kinds": 2, "seed": 1, "shuffles": 1}
	var s2: Dictionary = M.new_state(stack)
	check("mahjong: tablero repartido aunque haya pilas", bool(s2["ok"]))
	var an: Dictionary = M.analyze(lv)
	check("mahjong: nivel justo con su par", bool(an["completable"]) and int(an["par"]) > 0, str(an))
	check("mahjong: fichas impares no valen", (M.analyze({"map": ["111", "111", "111"]})["issues"] as Array).has("mahjong_odd"))
	check("mahjong: una torre sola no vale", not bool(M.analyze({"map": ["8", "2"]})["completable"]))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "mahjong"
	lv["par"] = int(an["par"])
	Kit.config["levels"] = [lv]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/mahjong.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	var r: Rect2 = g.call("tile_rect", 0)
	check("mahjong: el tablero cabe en pantalla", r.position.x >= 0.0 and r.end.x <= 720.0 and r.position.y > 150.0)
	var Bot: GDScript = load("res://qa/mahjong_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 3000)
	check("mahjong: el bot vacia el tablero", won and int(g.get("deaths")) == 0, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Aparcamiento: coches con morro, salir, chocar, vidas, atascos sin salida y el bot.
func _test_parking() -> void:
	print("- Aparcamiento (Parking Jam)")
	var M: GDScript = load("res://kit/parking/parking_map.gd")
	var lv: Dictionary = {"name": "P", "map": ["aA.b", "...B", "Cc..", "...."], "lives": 2}
	var cars: Dictionary = M.parse(lv)
	check("aparcamiento: tres coches con su direccion", cars.size() == 3 and cars["A"]["dir"] == Vector2i(1, 0)
		and cars["B"]["dir"] == Vector2i(0, 1) and cars["C"]["dir"] == Vector2i(-1, 0))
	var st: Dictionary = M.new_state(lv)
	check("aparcamiento: tapado choca y quita una vida", not M.tap(st, "A") and int(st["bumps"]) == 1)
	check("aparcamiento: libre sale", M.tap(st, "B") and (st["gone"] as Dictionary).has("B"))
	check("aparcamiento: el que estaba tapado ya sale", M.tap(st, "A") and M.tap(st, "C") and M.won(st))
	var st2: Dictionary = M.new_state(lv)
	M.tap(st2, "A")
	M.tap(st2, "A")
	check("aparcamiento: sin vidas se pierde", M.lost(st2))
	check("aparcamiento: nivel justo con su par", bool(M.analyze(lv)["completable"]) and int(M.analyze(lv)["par"]) == 3)
	check("aparcamiento: dos coches que se tapan no valen", (M.analyze({"map": ["aAbB", "....", "...."]})["issues"] as Array).size() == 0
		and (M.analyze({"map": ["aA.Bb", ".....", "....."]})["issues"] as Array).has("parking_deadlock"))
	check("aparcamiento: coche torcido no vale", not bool(M.analyze({"map": ["aA.", ".a.", "..."]})["completable"]))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "parking"
	lv["par"] = 3
	Kit.config["levels"] = [lv]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/parking.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	check("aparcamiento: tocar el coche lo encuentra", str(g.call("car_at", g.call("cell_center", Vector2i(3, 1)))) == "B")
	var Bot: GDScript = load("res://qa/parking_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 3000)
	check("aparcamiento: el bot saca todos sin chocar", won and int(g.get("deaths")) == 0 and int(g.call("stars_earned")) == 3, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Sopa de letras: limpiar palabras, montar la cuadricula, leer lineas, traduccion y el bot.
func _test_words() -> void:
	print("- Sopa de letras")
	var M: GDScript = load("res://kit/words/words_map.gd")
	check("sopa: palabras sin tildes y en mayusculas", M.clean("Le\u00f3n marino") == "LEONMARINO" and M.clean("ping\u00fcino") == "PINGUINO"
		and M.clean("a\u00f1o") == "A\u00d1O")
	var lv: Dictionary = {"name": "S", "map": ["sopa"], "words": ["gato", "perro", "loro", "pez"], "size": 6, "dirs": 3, "seed": 2}
	var st: Dictionary = M.new_state(lv)
	check("sopa: cuadricula del lado pedido", int(st["size"]) == 6 and (st["grid"] as Array).size() == 6)
	var pl: Array = st["place"]["PERRO"]
	var e: Vector2i = (pl[0] as Vector2i) + (pl[1] as Vector2i) * 4
	check("sopa: se lee la palabra al derecho y al reves", M.check(st, pl[0], e) == "PERRO" and M.check(st, e, pl[0]) == "PERRO")
	check("sopa: una linea torcida no vale", M.read_line(st["grid"], Vector2i(0, 0), Vector2i(2, 1)) == "")
	check("sopa: misma semilla, misma sopa", M.build(lv)["grid"] == st["grid"])
	check("sopa: palabra larga agranda la cuadricula", int(M.build({"words": ["ELEFANTE", "OSO", "GATO"], "size": 5})["size"]) >= 8)
	check("sopa: nivel justo", bool(M.analyze(lv)["completable"]))
	check("sopa: con dos palabras no vale", not bool(M.analyze({"words": ["SOL", "MAR"]})["completable"]))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "words"
	lv["par"] = 30
	Kit.config["levels"] = [lv]
	Kit.config["i18n"] = {"en": {"_levels": [{"name": "S", "words": ["cat", "dog", "parrot", "fish"]}]}}
	Kit.level_index = 0
	var en_lv: Dictionary = Kit.current_level() if Kit.has_method("current_level") else lv
	Kit.config.erase("i18n")
	Kit.config["levels"] = [lv]
	check("sopa: hay lista de palabras", en_lv.has("words"))
	var g: Node = (load("res://scenes/words.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	check("sopa: la lista se ve abajo", g.find_child("W_PERRO", true, false) != null)
	var Bot: GDScript = load("res://qa/words_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 3000)
	check("sopa: el bot encuentra todas", won and int(g.get("coins")) == 4, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Sudoku: casillas, fallos, solucion unica, pista, analizador y el bot.
func _test_sudoku() -> void:
	print("- Sudoku")
	var M: GDScript = load("res://kit/sudoku/sudoku_map.gd")
	var lv: Dictionary = {"name": "S", "map": ["321.", "41..", "1.2.", "2..1"], "lives": 2}
	var st: Dictionary = M.new_state(lv)
	check("sudoku: 4x4 con su solucion", int(st["n"]) == 4 and (st["sol"] as Array).size() == 4 and int(st["sol"][0][3]) == 4)
	check("sudoku: numero equivocado es fallo y no se pone", not M.put(st, 3, 0, 1) and int(st["mistakes"]) == 1 and int(st["grid"][0][3]) == 0)
	check("sudoku: el bueno se pone", M.put(st, 3, 0, 4) and int(st["grid"][0][3]) == 4)
	check("sudoku: una pista dada no se cambia", not M.put(st, 0, 0, 3))
	check("sudoku: con dos fallos se pierde", not M.put(st, 2, 1, 1) and M.lost(st))
	check("sudoku: nivel justo con solucion unica", bool(M.analyze(lv)["completable"]))
	check("sudoku: tablero vacio no tiene solucion unica", (M.analyze({"map": ["....", "....", "....", "...."]})["issues"] as Array).has("sudoku_not_unique"))
	check("sudoku: numeros repetidos no valen", (M.analyze({"map": ["11..", "....", "....", "...."]})["issues"] as Array).has("sudoku_clash"))
	check("sudoku: 9x9 se resuelve", bool(M.analyze({"map": ["8...1.76.", ".9478.21.", ".7.3294..", "385.74...", "........8", "2416.89..", "..3....9.", ".....31.6", "..719...."]})["completable"]))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "sudoku"
	lv["par"] = 30
	Kit.config["levels"] = [lv]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/sudoku.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	check("sudoku: teclado con 4 numeros", g.find_child("Num_4", true, false) != null and g.find_child("Num_5", true, false) == null)
	var Bot: GDScript = load("res://qa/sudoku_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 3000)
	check("sudoku: el bot lo resuelve sin fallos", won and int(g.call("stars_earned")) == 3, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Nonograma: pistas, pintar, cruz, fallos, logica de lineas y el bot.
func _test_nonogram() -> void:
	print("- Nonograma")
	var M: GDScript = load("res://kit/nonogram/nonogram_map.gd")
	var lv: Dictionary = {"name": "N", "map": [".#.#.", "#####", "#####", ".###.", "..#.."], "lives": 2}
	var st: Dictionary = M.new_state(lv)
	check("nonograma: pistas de filas y columnas", st["clues"]["rows"][0] == [1, 1] and st["clues"]["rows"][1] == [5] and st["clues"]["cols"][0] == [2])
	check("nonograma: pintar bien suma", M.mark(st, 1, 0, 1) == "ok" and int(st["painted"]) == 1)
	check("nonograma: pintar mal es fallo y deja cruz", M.mark(st, 0, 0, 1) == "mistake" and int(st["cells"][0][0]) == 2)
	check("nonograma: cruz en vacia no es fallo", M.mark(st, 4, 4, 2) == "ok" and int(st["mistakes"]) == 1)
	check("nonograma: linea se resuelve sola", M.line_solve([-1, -1, -1, -1, -1], [4]) == [-1, 1, 1, 1, -1])
	check("nonograma: dibujo con logica vale", bool(M.analyze(lv)["completable"]))
	check("nonograma: diagonal ambigua no vale", (M.analyze({"map": ["#...", ".#..", "..#.", "...#"]})["issues"] as Array).has("nonogram_guess"))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "nonogram"
	lv["par"] = 30
	Kit.config["levels"] = [lv]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/nonogram.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	var Bot: GDScript = load("res://qa/nonogram_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 3000)
	check("nonograma: el bot pinta el dibujo", won and int(g.call("stars_earned")) == 3, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Cortar fruta: oleadas, cortar, bombas, fruta que cae, analizador y el bot.
func _test_slice() -> void:
	print("- Cortar fruta")
	var M: GDScript = load("res://kit/slice/slice_map.gd")
	var lv: Dictionary = {"name": "C", "map": ["F", "FF", "FBF", "FFG"], "lives": 3, "speed": 1.0, "gap": 1.4, "seed": 2}
	var st: Dictionary = M.new_state(lv)
	check("cortar: oleadas y frutas contadas", (st["waves"] as Array).size() == 4 and int(st["fruits"]) == 8)
	for k: int in 40:
		M.step(st, 1.0 / 30.0)
	var it: Dictionary = st["items"][0]
	var p: Vector2 = it["p"]
	check("cortar: la fruta sube", p.y < M.FLOOR - 100.0)
	check("cortar: un corte por encima la parte", M.slice(st, p - Vector2(40, 0), p + Vector2(40, 0)).size() == 1 and int(st["cut"]) == 1)
	var st2: Dictionary = M.new_state(lv)
	for k: int in 30 * 6:
		M.step(st2, 1.0 / 30.0)
	check("cortar: la fruta que cae entera quita vida", int(st2["missed"]) >= 1)
	var st3: Dictionary = M.new_state({"map": ["B", "F", "F"], "seed": 1})
	for k: int in 40:
		M.step(st3, 1.0 / 30.0)
	var b: Vector2 = st3["items"][0]["p"]
	M.slice(st3, b - Vector2(30, 0), b + Vector2(30, 0))
	check("cortar: cortar la bomba pierde", M.lost(st3))
	check("cortar: nivel que el bot gana", bool(M.analyze(lv)["completable"]))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "slice"
	lv["par"] = 20
	Kit.config["levels"] = [lv]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/slice.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	var Bot: GDScript = load("res://qa/slice_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 6000)
	check("cortar: el bot corta todas sin bombas", won and int(g.get("deaths")) == 0, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Penaltis: porteria, portero, barrera, diana, analizador y el bot.
func _test_penalty() -> void:
	print("- Penaltis")
	var M: GDScript = load("res://kit/penalty/penalty_map.gd")
	var lv: Dictionary = {"name": "P", "map": ["..W.T"], "goal": 3, "bluff": 0.1, "seed": 4}
	var st: Dictionary = M.new_state(lv)
	check("penaltis: cinco tiros", (st["shots"] as Array).size() == 5)
	check("penaltis: fuera de la porteria es fuera", M.judge(st, Vector2(1.2, 0.5)) == "out" and M.judge(st, Vector2(0, 1.1)) == "out")
	st["dive"] = 1
	check("penaltis: al lado del portero es parada", M.judge(st, Vector2(0.62, 0.35)) == "saved")
	check("penaltis: al otro lado arriba es gol", M.judge(st, Vector2(-0.8, 0.8)) == "goal")
	st["i"] = 2
	check("penaltis: la barrera para el tiro bajo al centro", M.judge(st, Vector2(0.1, 0.2)) == "wall")
	st["i"] = 4
	st["target"] = Vector2(-0.6, 0.7)
	check("penaltis: en la diana vale doble", M.judge(st, Vector2(-0.6, 0.7)) == "double")
	check("penaltis: nivel que el bot gana", bool(M.analyze(lv)["completable"]))
	check("penaltis: meta imposible no vale", not bool(M.analyze({"map": ["..."], "goal": 9})["completable"]))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "penalty"
	lv["par"] = 5
	Kit.config["levels"] = [lv]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/penalty.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	var Bot: GDScript = load("res://qa/penalty_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 6000)
	check("penaltis: el bot marca los goles", won and int(g.get("deaths")) == 0, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Agujero: tragar lo que cabe, crecer, meta, analizador y el bot.
func _test_hole() -> void:
	print("- Agujero (Hole.io)")
	var M: GDScript = load("res://kit/hole/hole_map.gd")
	var lv: Dictionary = {"name": "A", "map": ["cccccccc", "cpcpcpcp", "..S.....", "cccccccc", "pbpbpbpb", "tttttttt", "aaaaaaaa", "hhhhhhhh"],
		"goal": 0.4, "seconds": 90}
	var st: Dictionary = M.new_state(lv)
	check("agujero: empieza pequeno", is_equal_approx(float(st["r"]), M.R0) and (st["objs"] as Array).size() == 56)
	var car: Dictionary = {}
	for o: Dictionary in st["objs"]:
		if o["k"] == "a":
			car = o
			break
	check("agujero: un coche no cabe al principio", not M.fits(st, car))
	var r0: float = float(st["r"])
	var eaten: Array = []
	for k: int in 12:
		eaten.append_array(M.step(st, Vector2(0, -1), 0.03))
	check("agujero: se traga lo pequeno y crece", not eaten.is_empty() and float(st["r"]) > r0 and int(st["eaten"]) > 0)
	check("agujero: el bot llega a la meta", bool(M.bot_play(lv)["won"]))
	check("agujero: ciudad vacia no vale", not bool(M.analyze({"map": ["........", "...S....", "........", "........", "........", "........", "........", "........"]})["completable"]))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "hole"
	lv["par"] = 60
	Kit.config["levels"] = [lv]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/hole.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	var Bot: GDScript = load("res://qa/hole_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 6000)
	check("agujero: el bot gana jugando", won and int(g.get("deaths")) == 0, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Ciudad: construir junto a la carretera, gente, trabajo, felicidad, pisos y el bot.
func _test_city() -> void:
	print("- Ciudad (constructor)")
	var M: GDScript = load("res://kit/city/city_map.gd")
	var lv: Dictionary = {"name": "C", "map": ["........", "........", "...^....", "........", "....=...", "..=====.", "....=...", "....T...", "........"],
		"goal": 30, "seconds": 400, "money": 400}
	var st: Dictionary = M.new_state(lv)
	check("ciudad: ayuntamiento y carreteras", st["hall"] == Vector2i(4, 7) and M.road_net(st).size() >= 7)
	check("ciudad: lejos de la carretera no funciona", not M.on_road(st, Vector2i(0, 0), M.road_net(st)))
	check("ciudad: casa junto a la carretera", M.build(st, "house", Vector2i(3, 4)) and int(st["money"]) == 350)
	check("ciudad: calle que no sale de la red no vale", not M.build(st, "road", Vector2i(0, 8)))
	M.build(st, "shop", Vector2i(5, 4))
	for k: int in 30:
		M.step(st, 1.0)
	check("ciudad: la casa se llena y paga impuestos", float(st["pop"]) > 4.0 and int(st["jobs"]) == M.SHOP_JOBS)
	var h0: float = M.happiness(st, Vector2i(3, 4))
	M.build(st, "factory", Vector2i(3, 6))
	check("ciudad: una fabrica al lado quita felicidad", h0 == 1.0 and M.happiness(st, Vector2i(3, 4)) < 1.0)
	check("ciudad: el bot llega a la meta", bool(M.bot_play(lv)["won"]))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "city"
	lv["par"] = 200
	Kit.config["levels"] = [lv]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/city.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	check("ciudad: barra de herramientas", g.find_child("Tool_house", true, false) != null and g.find_child("Tool_park", true, false) != null)
	var Bot: GDScript = load("res://qa/city_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 9000)
	check("ciudad: el bot gana jugando", won and int(g.get("deaths")) == 0, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Torre en espiral: casilla bajo la bola, rebote, hueco, rojo, bola en llamas y el bot.
func _test_helix() -> void:
	print("- Torre en espiral (Helix Jump)")
	var M: GDScript = load("res://kit/helix/helix_map.gd")
	var rows: Array = ["....ooo.....", "x.....ooo...", ".......ooo..", "........ooo.", "ooo.........", "...ooo......"]
	var lv: Dictionary = {"name": "H", "map": rows, "bounce": 0.6, "spin": 5.0}
	var st: Dictionary = M.new_state(lv)
	st["rot"] = M.rot_for(1)
	check("torre: la casilla bajo la bola", M.slot_under(st) == 1)
	st["next"] = 0.0
	check("torre: sobre suelo rebota", M.step(st, 0.01) == "bounce" and int(st["floor"]) == 0)
	st["rot"] = M.rot_for(5)
	st["next"] = 0.0
	check("torre: sobre hueco baja", M.step(st, 0.01) == "pass" and int(st["floor"]) == 1)
	st["rot"] = M.rot_for(0)
	st["next"] = 0.0
	check("torre: sobre rojo se pierde", M.step(st, 0.01) == "dead")
	var st2: Dictionary = M.new_state(lv)
	st2["floor"] = 1
	st2["streak"] = 3
	st2["rot"] = M.rot_for(0)
	st2["next"] = 0.0
	check("torre: en llamas rompe hasta el rojo", M.step(st2, 0.01) == "pass" and (st2["smashed"] as Dictionary).has(1))
	check("torre: el bot llega abajo", bool(M.analyze(lv)["completable"]))
	check("torre: piso sin hueco no vale", (M.analyze({"map": ["............", "....ooo.....", "....ooo.....", "....ooo.....", "....ooo....."]})["issues"] as Array).has("helix_no_gap"))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "helix"
	lv["par"] = 10
	Kit.config["levels"] = [lv]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/helix.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	var Bot: GDScript = load("res://qa/helix_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 6000)
	check("torre: el bot gana jugando", won and int(g.get("deaths")) == 0, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Canasta: vuelo, aro, triple, aro que se mueve, analizador y el bot.
func _test_hoops() -> void:
	print("- Canasta")
	var M: GDScript = load("res://kit/hoops/hoops_map.gd")
	var lv: Dictionary = {"name": "B", "map": [".f.m."], "goal": 3, "seed": 2}
	var st: Dictionary = M.new_state(lv)
	check("canasta: tiro recto y fuerte entra", str(M.fly(st, Vector2(0, -2100), 0.0)["res"]) == "in")
	check("canasta: tiro flojo se queda corto", M.fly(st, Vector2(0, -1200), 0.0).has("short"))
	check("canasta: tiro torcido fuera", str(M.fly(st, Vector2(500, -2100), 0.0)["res"]) == "miss")
	var r: Dictionary = M.shoot(st, Vector2(0, -2100))
	check("canasta: canasta cuenta", str(r["res"]) == "in" and int(st["made"]) == 1 and int(st["points"]) == 2)
	check("canasta: el triple sale de la esquina", M.current(st) == "f" and M.start_of(st).x != 360.0)
	st["i"] = 3
	check("canasta: el aro se mueve", M.hoop_x(st, 0.0) != M.hoop_x(st, 1.0))
	check("canasta: nivel justo", bool(M.analyze(lv)["completable"]))
	check("canasta: meta imposible no vale", not bool(M.analyze({"map": ["..."], "goal": 5})["completable"]))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "hoops"
	lv["par"] = 5
	Kit.config["levels"] = [lv]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/hoops.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	var Bot: GDScript = load("res://qa/hoops_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 6000)
	check("canasta: el bot gana jugando", won and int(g.get("deaths")) == 0, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Buscaminas: numeros, abrir en cascada, minas, banderas, resolutor logico y el bot.
func _test_mines() -> void:
	print("- Buscaminas")
	var M: GDScript = load("res://kit/mines/mines_map.gd")
	var lv: Dictionary = {"name": "B", "map": ["......", ".....*", "......", "......", "...S..", ".....*", "*.....", "...**."], "lives": 1}
	var st: Dictionary = M.new_state(lv)
	check("buscaminas: la salida abre en cascada", (st["open"] as Dictionary).size() > 9 and not bool(st["won"]))
	check("buscaminas: los numeros cuentan las minas", M.count(st, Vector2i(3, 6)) == 2 and M.count(st, Vector2i(3, 4)) == 0)
	check("buscaminas: abrir una mina es boom", M.reveal(st, Vector2i(0, 6)) == "mine" and M.lost(st))
	var st2: Dictionary = M.new_state(lv)
	var d: Dictionary = M.deduce(st2)
	check("buscaminas: la logica ve algo seguro", not (d["mines"] as Array).is_empty() or not (d["safe"] as Array).is_empty())
	check("buscaminas: tablero justo sin adivinar", bool(M.analyze(lv)["completable"]))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "mines"
	lv["par"] = 30
	Kit.config["levels"] = [lv]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/mines.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	var Bot: GDScript = load("res://qa/mines_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 3000)
	check("buscaminas: el bot lo limpia sin boom", won and int(g.call("stars_earned")) == 3, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Conecta 4: caer, 4 en raya, rival que no deja escapar una victoria, analizador y el bot.
func _test_connect() -> void:
	print("- Conecta 4")
	var M: GDScript = load("res://kit/connect/connect_map.gd")
	var empty: Array = [".......", ".......", ".......", ".......", ".......", "......."]
	var lv: Dictionary = {"name": "C", "map": empty, "depth": 1, "mistake": 0.3, "first": "player", "seed": 2}
	var st: Dictionary = M.new_state(lv)
	check("conecta: la ficha cae abajo", M.play(st, 3) and str(st["g"][5][3]) == "R" and str(st["turn"]) == "Y")
	var st2: Dictionary = M.new_state({"map": [".......", ".......", ".......", ".......", ".......", "RRR...."]})
	check("conecta: cuatro en raya gana", M.play(st2, 3) and str(st2["winner"]) == "R" and (st2["line"] as Array).size() == 4)
	var st3: Dictionary = M.new_state({"map": [".......", ".......", ".......", ".......", ".......", "YYY...."], "first": "ai", "mistake": 1.0})
	check("conecta: el rival no deja escapar su victoria", M.ai_move(st3) == 3)
	check("conecta: no se juega en columna llena", M.drop_row(M.new_state({"map": ["R......", "Y......", "R......", "Y......", "R......", "Y......"]})["g"], 0) == -1)
	check("conecta: rival flojo, el bot gana", bool(M.analyze(lv)["completable"]))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "connect"
	lv["par"] = 21
	Kit.config["levels"] = [lv]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/connect.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	var Bot: GDScript = load("res://qa/connect_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 6000)
	check("conecta: el bot gana la partida", won and int(g.get("deaths")) == 0, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Damas: mover, comer obligatorio, saltos encadenados, coronar, rival, analizador y el bot.
func _test_checkers() -> void:
	print("- Damas")
	var M: GDScript = load("res://kit/checkers/checkers_map.gd")
	var st: Dictionary = M.new_state({"map": ["........", "........", "........", "........", "...b....", "....w...", "........", "........"]})
	var moves: Array = M.moves_of(st["g"], "w")
	check("damas: comer es obligatorio", moves.size() == 1 and (moves[0]["eat"] as Array).size() == 1)
	M.play(st, moves[0])
	check("damas: la ficha comida desaparece", str(st["g"][4][3]) == "." and str(st["g"][3][2]) == "w" and str(st["winner"]) == "w")
	var st2: Dictionary = M.new_state({"map": ["........", "........", "...b....", "........", ".b......", "w.......", "........", "........"]})
	var mv2: Array = M.moves_of(st2["g"], "w")
	check("damas: salto encadenado de una vez", mv2.size() == 1 and (mv2[0]["eat"] as Array).size() == 2)
	var st3: Dictionary = M.new_state({"map": ["........", "...w....", "........", "........", "........", "........", "......b.", "........"]})
	M.play(st3, {"path": [Vector2i(3, 1), Vector2i(2, 0)], "eat": []})
	check("damas: al llegar arriba corona", str(st3["g"][0][2]) == "W")
	var lv: Dictionary = {"name": "D", "map": ["........", "..b.b...", "...b....", "........", "........", "..w.w...", ".w...w..", "........"],
		"depth": 1, "mistake": 0.3, "seed": 2}
	check("damas: rival flojo, el bot gana", bool(M.analyze(lv)["completable"]))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "checkers"
	lv["par"] = 40
	Kit.config["levels"] = [lv]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/checkers.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	var Bot: GDScript = load("res://qa/checkers_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 6000)
	check("damas: el bot gana la partida", won and int(g.get("deaths")) == 0, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Billar: fisica, troneras, falta de la blanca, analizador y el bot.
func _test_pool() -> void:
	print("- Billar")
	var M: GDScript = load("res://kit/pool/pool_map.gd")
	var rows: Array = []
	for y: int in 15:
		rows.append(".........")
	rows[2] = "....o...."
	rows[12] = "....C...."
	var lv: Dictionary = {"name": "P", "map": rows, "shots": 4}
	var st: Dictionary = M.new_state(lv)
	check("billar: blanca y una bola", (st["balls"] as Array).size() == 2 and int(st["total"]) == 1)
	var sim: Dictionary = M.copy_state(st)
	var r: Dictionary = M.shoot(sim, Vector2(0, -1), 0.6)
	check("billar: la blanca empuja la bola y todo se para", not M.moving(sim) and (sim["balls"][1]["p"] as Vector2).y < 150.0 or int(sim["potted"]) == 1)
	var st2: Dictionary = M.new_state(lv)
	st2["balls"][0]["p"] = Vector2(40, 40)
	var r2: Dictionary = M.shoot(st2, Vector2(-1, -1), 0.5)
	check("billar: meter la blanca es falta y vuelve", bool(r2["foul"]) and not bool(st2["balls"][0]["in"]) and int(st2["fouls"]) == 1)
	check("billar: el bot mete la bola", bool(M.analyze(lv)["completable"]))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "pool"
	lv["par"] = 2
	Kit.config["levels"] = [lv]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/pool.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	var Bot: GDScript = load("res://qa/pool_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 6000)
	check("billar: el bot gana jugando", won and int(g.get("deaths")) == 0, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Solitario clasico: reparto, reglas de bajar y subir, buscador de solucion y el bot.
func _test_klondike() -> void:
	print("- Solitario clasico")
	var M: GDScript = load("res://kit/klondike/klondike_map.gd")
	var lv: Dictionary = {"name": "K", "map": ["klondike"], "seed": 2, "passes": 0}
	var st: Dictionary = M.new_state(lv)
	var n: int = (st["stock"] as Array).size()
	for col: Array in st["cols"]:
		n += col.size()
	check("solitario: 52 cartas, 7 columnas y la ultima boca arriba", n == 52 and (st["cols"][6] as Array).size() == 7 and bool(st["cols"][6][6][2]))
	check("solitario: misma semilla, mismo reparto", M.new_state(lv)["stock"] == st["stock"])
	check("solitario: As a la base", M.can_found(st, [0, 1]) and not M.can_found(st, [0, 2]))
	check("solitario: rojo sobre negro, uno menos", M.can_stack([[0, 9, true]], [1, 8]) and not M.can_stack([[0, 9, true]], [3, 8]))
	check("solitario: hueco vacio solo para un Rey", M.can_stack([], [2, 13]) and not M.can_stack([], [2, 12]))
	check("solitario: este reparto tiene solucion", bool(M.analyze(lv)["completable"]))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "klondike"
	lv["par"] = 330
	Kit.config["levels"] = [lv]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/klondike.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	var Bot: GDScript = load("res://qa/klondike_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 9000)
	check("solitario: el bot lo termina", won and int(g.get("deaths")) == 0, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Parchis: salir con 6, comer, casillas seguras, meta justa, analizador y el bot.
func _test_ludo() -> void:
	print("- Parchis")
	var M: GDScript = load("res://kit/ludo/ludo_map.gd")
	var lv: Dictionary = {"name": "L", "map": ["ludo:0"], "rivals": 1, "tokens": 2, "skill": 0.3, "seed": 0}
	var st: Dictionary = M.new_state(lv)
	check("parchis: todas en casa y solo se sale con 6", M.legal(st, 0, 5).is_empty() and M.legal(st, 0, 6).size() == 2)
	M.move(st, 0, 0, 6)
	check("parchis: al salir va a su casilla de salida", int(st["players"][0]["tokens"][0]) == 0 and M.board_cell(st, 0, 0) == 0)
	st["players"][1]["tokens"][0] = 50
	var rival_cell: int = M.board_cell(st, 1, 50)
	st["players"][0]["tokens"][1] = (rival_cell - 0 + 52) % 52 - 3
	var r: Dictionary = M.move(st, 0, 1, 3)
	check("parchis: caer encima de un rival lo manda a casa", int(r["capture"]) == 1 and int(st["players"][1]["tokens"][0]) == -1
		or M.SAFE.has(rival_cell))
	st["players"][0]["tokens"][0] = M.GOAL - 2
	check("parchis: a la meta con el numero justo", not M.can_move(st, 0, 0, 3) and M.can_move(st, 0, 0, 2))
	check("parchis: con esta semilla el bot gana", bool(M.analyze(lv)["completable"]))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "ludo"
	lv["par"] = 60
	Kit.config["levels"] = [lv]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/ludo.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	var Bot: GDScript = load("res://qa/ludo_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 12000)
	check("parchis: el bot gana jugando", won and int(g.get("deaths")) == 0, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Bloques que caen: piezas, giro, filas que se borran, perder arriba, analizador y el bot.
func _test_falling() -> void:
	print("- Bloques que caen")
	var M: GDScript = load("res://kit/falling/falling_map.gd")
	var lv: Dictionary = {"name": "F", "map": ["##########".substr(0, 9) + "."], "lines": 4, "speed": 1.5, "seed": 3}
	var st: Dictionary = M.new_state(lv)
	check("caida: hay pieza y siguiente", not (st["piece"] as Dictionary).is_empty() and str(st["next"]) != "")
	check("caida: la I tumbada y de pie", M.cells("I", 0).size() == 4 and M.cells("I", 1)[0].x == M.cells("I", 1)[3].x)
	var x0: int = (st["piece"]["pos"] as Vector2i).x
	check("caida: se mueve a los lados", M.try_move(st, -1, 0) and (st["piece"]["pos"] as Vector2i).x == x0 - 1)
	## Una I de pie en el hueco de la derecha borra la fila de abajo.
	st["piece"] = {"kind": "I", "rot": 1, "pos": Vector2i(7, 10)}
	var lines: int = M.hard_drop(st)
	check("caida: una fila llena se borra", lines == 1 and int(st["lines"]) == 1)
	var st2: Dictionary = M.new_state({"map": [], "lines": 10, "seed": 1})
	for y: int in M.H:
		for x: int in M.W - 1:
			st2["grid"][y][x] = "G"
	M.spawn(st2)
	check("caida: si no cabe arriba se pierde", bool(st2["over"]))
	check("caida: el bot borra las filas", bool(M.analyze(lv)["completable"]))
	## Reglas: una regla (piezas de agua) cambia la mecanica y el analizador juega con ella.
	var lw: Dictionary = {"map": ["#########."], "lines": 8, "speed": 2.0, "seed": 5, "rules": ["res://qa/regla_agua.gd"]}
	var sw: Dictionary = M.new_state(lw)
	var water: int = 0
	for k: int in 30 * 60:
		if bool(sw["won"]) or bool(sw["over"]):
			break
		if k % 4 == 0:
			if int(sw["pieces"]) != int(sw.get("_bp", -1)):
				sw["_bp"] = int(sw["pieces"])
				sw["_bt"] = M.best_place(sw)
			M.bot_act(sw, sw["_bt"])
		M.step(sw, 1.0 / 30.0)
		for row: Array in sw["grid"]:
			water = maxi(water, row.count("W"))
	check("reglas: la regla se carga y hay agua en el pozo", (sw["rules"] as Array).size() == 1 and water > 0)
	check("reglas: con agua el bot sigue ganando", bool(M.analyze(lw)["completable"]))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "falling"
	lv["par"] = 30
	Kit.config["levels"] = [lv]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/falling.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	var Bot: GDScript = load("res://qa/falling_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 9000)
	check("caida: el bot gana jugando", won and int(g.get("deaths")) == 0, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Bolos: bolos en triangulo, tirar, dos bolas por tirada, canal, analizador y el bot.
func _test_bowling() -> void:
	print("- Bolos")
	var M: GDScript = load("res://kit/bowling/bowling_map.gd")
	var lv: Dictionary = {"name": "B", "map": [".", ".", "."], "goal": 12, "seed": 2}
	var st: Dictionary = M.new_state(lv)
	check("bolos: diez bolos y tres tiradas", (st["pins"] as Array).size() == 10 and (st["frames"] as Array).size() == 3)
	var s1: Dictionary = M.copy_state(st)
	check("bolos: recto al bolo de delante tira muchos", M.roll(s1, 230.0, 0.0, 0.0) >= 7)
	var s2: Dictionary = M.copy_state(st)
	check("bolos: por el canal no tira ninguno", M.roll(s2, 20.0, -0.2, 0.0) == 0)
	var n: int = M.throw_ball(st, 100.0, 0.0, 0.0)
	check("bolos: tras una bola floja se tira la segunda", n < 10 and int(st["ball"]) == 1)
	M.throw_ball(st, 230.0, 0.0, 0.0)
	check("bolos: tras la segunda, tirada nueva con diez bolos", int(st["f"]) == 1 and int(st["ball"]) == 0)
	check("bolos: el bot llega a la meta", bool(M.analyze(lv)["completable"]))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "bowling"
	lv["par"] = 20
	Kit.config["levels"] = [lv]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/bowling.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	var Bot: GDScript = load("res://qa/bowling_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 9000)
	check("bolos: el bot gana jugando", won and int(g.get("deaths")) == 0, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Mundo abierto: mundo con semilla, picar con la herramienta justa, fabricar, poner, guardar y el bot.
func _test_sandbox() -> void:
	print("- Mundo abierto")
	var M: GDScript = load("res://kit/sandbox/sandbox_map.gd")
	var lv: Dictionary = {"name": "S", "map": ["lbm"], "seed": 4, "goal_item": "pico_madera", "goal_n": 1, "mobs": 2, "day": 120, "night": 60}
	var st: Dictionary = M.new_state(lv)
	var st_b: Dictionary = M.new_state(lv)
	check("mundo: la misma semilla da el mismo mundo", st["grid"] == st_b["grid"] and int(st["w"]) == 96)
	check("mundo: hay arboles y minerales", M.count_blocks(st, M.LOG) > 8 and M.count_blocks(st, M.COAL) > 10 and M.count_blocks(st, M.CRYSTAL) > 0)
	var f: Vector2i = M.feet(st)
	check("mundo: se empieza de pie sobre el suelo", M.solid(st, f.x, f.y + 1) and not M.solid(st, f.x, f.y))
	## Sin pico la piedra no se rompe; con pico de madera si.
	var stone: Vector2i = Vector2i(f.x, f.y + 8)
	check("mundo: sin pico no se pica piedra", M.at(st, stone.x, stone.y) != M.STONE or not M.can_mine(st, stone))
	st["inv"] = {"tronco": 2}
	check("mundo: tablas con un tronco", M.craft(st, "tablas") and M.have(st, "tablas") == 4)
	check("mundo: la mesa necesita 4 tablas y el pico la mesa", M.craft(st, "mesa") and not M.can_craft(st, "pico_madera"))
	## Picar un bloque de tierra a mano: se rompe con el tiempo y da tierra.
	var dirt: Vector2i = Vector2i(f.x + 1, f.y + 1)
	var before: int = M.have(st, "tierra")
	st["mine_target"] = dirt
	for k: int in 40:
		M.step(st, {"x": 0.0, "jump": false}, 1.0 / 30.0)
	check("mundo: picar da el bloque", M.at(st, dirt.x, dirt.y) == M.AIR and M.have(st, "tierra") == before + 1)
	st["mine_target"] = Vector2i(-1, -1)
	check("mundo: poner un bloque en un hueco", M.place(st, dirt, "tierra") and M.at(st, dirt.x, dirt.y) == M.DIRT)
	## Guardado: los cambios y el inventario vuelven.
	var saved: Dictionary = JSON.parse_string(JSON.stringify(M.save_data(st)))
	var st3: Dictionary = M.new_state(lv)
	check("mundo: se guarda y se recupera", M.load_into(st3, saved) and M.have(st3, "mesa") == 1 and M.at(st3, dirt.x, dirt.y) == M.DIRT)
	check("mundo: otro mundo no carga la partida", not M.load_into(M.new_state({"map": ["ddd"], "seed": 4}), saved))
	## De noche salen monstruos si estas fuera.
	var st4: Dictionary = M.new_state(lv)
	st4["clock"] = 125.0
	st4["mob_cd"] = 0.0
	M.step(st4, {"x": 0.0, "jump": false}, 1.0 / 30.0)
	check("mundo: de noche sale un monstruo", M.is_night(st4) and (st4["mobs"] as Array).size() == 1)
	check("mundo: el bot cumple la meta", bool(M.analyze(lv)["completable"]))
	var lv2: Dictionary = lv.duplicate()
	lv2["goal_item"] = "lingote_hierro"
	lv2["goal_n"] = 2
	check("mundo: el bot llega al hierro", bool(M.analyze(lv2)["completable"]))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "sandbox"
	lv["par"] = 60
	Kit.config["levels"] = [lv]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/sandbox.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	var Bot: GDScript = load("res://qa/sandbox_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 12000)
	check("mundo: el bot gana jugando", won and int(g.get("deaths")) == 0, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Conduccion 3D: acelerar, girar, paredes de edificios, recoger y entregar, trafico, bot y juego.
func _test_drive() -> void:
	print("- Conduccion 3D")
	var M: GDScript = load("res://kit/drive/drive_map.gd")
	var city: Array = [".........", ".###.###.", ".###.###.", ".###.###.", ".........", ".###.###.", ".###.###.", ".###.###.", "S........", "#5"]
	var lv: Dictionary = {"name": "C", "map": city, "jobs": [[8, 8, 8, 0], [0, 0, 4, 4]], "time": 70, "traffic": 3, "speed": 0.3}
	var st: Dictionary = M.new_state(lv)
	check("conduccion: ciudad, repartos y trafico", (st["jobs"] as Array).size() == 2 and (st["traffic"] as Array).size() == 3 and M.road(st, 0, 8) and not M.road(st, 1, 1))
	var car: Dictionary = st["car"]
	var p0: Vector2 = car["p"]
	for k: int in 30:
		M.step(st, {"steer": 0.0, "gas": 1.0}, 1.0 / 30.0)
	check("conduccion: acelerar mueve el coche", (car["p"] as Vector2).distance_to(p0) > 4.0 and float(car["v"]) > 6.0)
	var a0: float = float(car["a"])
	for k2: int in 15:
		M.step(st, {"steer": 1.0, "gas": 0.5}, 1.0 / 30.0)
	check("conduccion: girar cambia el rumbo", absf(wrapf(float(car["a"]) - a0, -PI, PI)) > 0.3)
	## Contra un edificio no se pasa.
	var st2: Dictionary = M.new_state(lv)
	(st2["car"] as Dictionary)["p"] = M.tcenter(Vector2i(0, 4))
	(st2["car"] as Dictionary)["a"] = -PI * 0.5
	(st2["traffic"] as Array).clear()
	for k3: int in 90:
		M.step(st2, {"steer": 0.0, "gas": 1.0}, 1.0 / 30.0)
	(st2["car"] as Dictionary)["a"] = 0.0
	(st2["car"] as Dictionary)["p"] = M.tcenter(Vector2i(4, 4))
	for k4: int in 60:
		M.step(st2, {"steer": 0.0, "gas": 1.0}, 1.0 / 30.0)
	check("conduccion: los edificios no se atraviesan", M.road(st2, M.tile_of(st2["car"]["p"]).x, M.tile_of(st2["car"]["p"]).y))
	## Recoger y entregar.
	var st3: Dictionary = M.new_state(lv)
	(st3["car"] as Dictionary)["p"] = M.tcenter(Vector2i(8, 8))
	M.step(st3, {"steer": 0.0, "gas": 0.0}, 1.0 / 30.0)
	(st3["car"] as Dictionary)["p"] = M.tcenter(Vector2i(8, 0))
	M.step(st3, {"steer": 0.0, "gas": 0.0}, 1.0 / 30.0)
	check("conduccion: recoger y entregar cuenta un reparto", int(st3["done"]) == 1 and not bool(st3["carrying"]) and int(st3["job"]) == 1)
	var r: Dictionary = M.bot_play(lv)
	check("conduccion: el bot hace los repartos a tiempo", bool(r["won"]), str(r))
	check("conduccion: el analizador lo acepta", bool(M.analyze(lv)["completable"]))
	var tight: Dictionary = lv.duplicate()
	tight["time"] = 15
	check("conduccion: con poco tiempo se rechaza", not bool(M.analyze(tight)["completable"]))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "drive"
	Kit.config["levels"] = [lv]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/drive.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	check("conduccion: ciudad, coche y baliza en 3D", g is Node3D and g.get_node_or_null("Car") != null and g.get_node_or_null("Beacon") != null)
	var Bot: GDScript = load("res://qa/drive_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 20000)
	check("conduccion: el bot gana jugando", won, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0

## Shooter de zombis 3D: moverse, disparar (la pared para la bala), recargar, mordiscos, oleadas,
## armas y botiquines, el bot y el analizador.
func _test_zombie() -> void:
	print("- Zombis 3D")
	var M: GDScript = load("res://kit/zombie/zombie_map.gd")
	var arena: Array = ["#########", "#Z.....Z#", "#.......#", "#..c....#", "#...P...#", "#.....S.#", "#.+.....#", "#Z.....Z#", "#########", "#4"]
	var lv: Dictionary = {"name": "Z", "map": arena, "waves": 2, "count": 3, "grow": 1, "speed": 0.3, "hp": 100, "types": [9, 9]}
	var st: Dictionary = M.new_state(lv)
	check("zombis: arena, entradas, armas y botiquines", (st["spawns"] as Array).size() == 4 and (st["pickups"] as Array).size() == 1 and (st["heals"] as Array).size() == 1 and str(st["me"]["weapon"]) == "pistola")
	var p0: Vector2 = st["me"]["p"]
	for k: int in 15:
		M.step(st, {"move": Vector2(0, 1)}, 1.0 / 30.0)
	check("zombis: andar hacia delante va hacia donde miras", (st["me"]["p"] as Vector2).y < p0.y - 0.5 and absf((st["me"]["p"] as Vector2).x - p0.x) < 0.05)
	## Un zombi delante: el disparo le quita vida; detras de las cajas no.
	var st2: Dictionary = M.new_state(lv)
	st2["break_t"] = 999.0
	var z: Dictionary = {"id": 0, "kind": "walker", "p": Vector2(4.5, 2.0), "hp": 70.0, "max": 70.0, "speed": 0.0, "r": 0.32, "dmg": 10.0, "atk": 0.0, "hit_t": 0.0, "slow": 0.0, "dir": Vector2(0, 1), "dead_t": 0.0}
	(st2["zombies"] as Array).append(z)
	M.step(st2, {"fire": true}, 1.0 / 30.0)
	check("zombis: el disparo acierta y gasta una bala", float(z["hp"]) < 70.0 and int(st2["me"]["ammo"]) == 11)
	st2["me"]["p"] = Vector2(3.5, 4.5)
	z["p"] = Vector2(3.5, 2.2)
	z["hp"] = 70.0
	st2["me"]["cd"] = 0.0
	M.step(st2, {"fire": true}, 1.0 / 30.0)
	check("zombis: las cajas paran las balas", float(z["hp"]) == 70.0)
	## Cargador vacio: recarga sola.
	st2["me"]["ammo"] = 1
	st2["me"]["cd"] = 0.0
	M.step(st2, {"fire": true}, 1.0 / 30.0)
	var reloading: bool = float(st2["me"]["reload"]) > 0.0
	for k2: int in 45:
		M.step(st2, {}, 1.0 / 30.0)
	check("zombis: al vaciar el cargador se recarga", reloading and int(st2["me"]["ammo"]) == 12)
	## Mordisco.
	var st3: Dictionary = M.new_state(lv)
	st3["break_t"] = 999.0
	var z3: Dictionary = z.duplicate()
	z3["p"] = (st3["me"]["p"] as Vector2) + Vector2(0.7, 0)
	z3["hp"] = 70.0
	z3["speed"] = 1.0
	(st3["zombies"] as Array).append(z3)
	for k3: int in 20:
		M.step(st3, {}, 1.0 / 30.0)
	check("zombis: si te alcanza te muerde", float(st3["me"]["hp"]) < 100.0)
	## Armas y botiquines.
	var st4: Dictionary = M.new_state(lv)
	st4["me"]["p"] = Vector2(6.5, 5.5)
	M.step(st4, {}, 1.0 / 30.0)
	check("zombis: coger la escopeta la equipa", str(st4["me"]["weapon"]) == "escopeta" and int(st4["me"]["ammo"]) == 6)
	(st4["heals"] as Array)[0]["on"] = true
	st4["me"]["hp"] = 30.0
	st4["me"]["p"] = Vector2(2.5, 6.5)
	M.step(st4, {}, 1.0 / 30.0)
	check("zombis: el botiquin cura", float(st4["me"]["hp"]) > 70.0 and not bool((st4["heals"] as Array)[0]["on"]))
	## Oleadas y victoria con el bot.
	var r: Dictionary = M.bot_play(lv)
	check("zombis: el bot aguanta todas las oleadas", bool(r["won"]) and int(r["wave"]) == 2 and int(r["kills"]) == 7, str(r))
	check("zombis: el analizador lo acepta", bool(M.analyze(lv)["completable"]))
	var hard: Dictionary = lv.duplicate()
	hard["hp"] = 20
	hard["count"] = 30
	hard["speed"] = 1.0
	hard["types"] = [1, 1]
	check("zombis: una horda imposible se rechaza", not bool(M.analyze(hard)["completable"]))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "zombie"
	Kit.config["levels"] = [lv]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/zombie.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	check("zombis: arena 3D, arma y botones", g is Node3D and g.find_child("BtnFire", true, false) != null and g.find_child("Walls", true, false) != null)
	var Bot: GDScript = load("res://qa/zombie_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 20000)
	check("zombis: el bot gana jugando", won, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0

## Baloncesto 3D: saque, tiro con barra (perfecto mejor que a destiempo), triple, rebote con
## regla de sacar fuera, robo, tapon, reloj de posesion, el bot y el analizador.
func _test_basket() -> void:
	print("- Baloncesto 3D")
	var M: GDScript = load("res://kit/basket/basket_map.gd")
	var lv: Dictionary = {"name": "B", "map": ["pista", "#9"], "players": 2, "skill": 0.3, "mates": 0.6, "points": 11, "time": 150}
	var st: Dictionary = M.new_state(lv)
	check("baloncesto: 2 contra 2 y sacas tu desde arriba", (st["players"] as Array).size() == 4 and int(st["owner"]) == 0 and int(st["poss"]) == 0)
	var me: Dictionary = st["players"][0]
	var good: float = M.shot_chance(st, me, Vector2(7.5, 3.0), M.PERFECT)
	var bad: float = M.shot_chance(st, me, Vector2(7.5, 3.0), 0.2)
	var far: float = M.shot_chance(st, me, Vector2(7.5, 8.2), M.PERFECT)
	check("baloncesto: soltar en la zona verde y cerca del aro mete mas", good > bad + 0.3 and good > far)
	## Tiro con la barra: mantener y soltar.
	st["pause_t"] = 0.0
	for p2: Dictionary in st["players"]:
		if int(p2["team"]) == 1:
			p2["p"] = Vector2(1.0, 13.0)
	me["p"] = Vector2(7.5, 9.0)
	for k: int in 21:
		M.step(st, {"move": Vector2.ZERO, "shoot": true}, 1.0 / 30.0)
	M.step(st, {"move": Vector2.ZERO, "shoot": false}, 1.0 / 30.0)
	check("baloncesto: mantener y soltar lanza un triple", str(st["ball"]["mode"]) == "shot" and int(st["ball"]["pts"]) == 3)
	## Canasta: suma y saca el otro equipo.
	st["ball"]["made"] = true
	for k2: int in 60:
		M.step(st, {}, 1.0 / 30.0)
	check("baloncesto: la canasta suma 3 y saca el rival", int(st["score"][0]) == 3 and int(st["poss"]) == 1)
	## Rebote defensivo: hay que sacar el balon fuera del triple antes de tirar.
	var st2: Dictionary = M.new_state(lv)
	st2["pause_t"] = 0.0
	var rival: Dictionary = st2["players"][2]
	rival["p"] = Vector2(7.5, 4.0)
	st2["ball"]["mode"] = "loose"
	st2["ball"]["from"] = Vector2(7.5, 4.0)
	st2["ball"]["to"] = Vector2(7.5, 4.0)
	st2["ball"]["p"] = Vector2(7.5, 4.0)
	st2["ball"]["fh"] = 1.0
	st2["ball"]["th"] = 1.0
	st2["ball"]["t"] = 0.0
	st2["owner"] = -1
	for p3: Dictionary in st2["players"]:
		if int(p3["i"]) != 2:
			p3["p"] = Vector2(1.0, 12.0)
	M.step(st2, {}, 1.0 / 30.0)
	check("baloncesto: rebote del rival y tiene que sacarlo fuera", int(st2["owner"]) == 2 and int(st2["poss"]) == 1 and bool(st2["clear"]))
	M.shoot_ball(st2, rival, M.PERFECT)
	check("baloncesto: sin sacarlo fuera no puede tirar", str(st2["ball"]["mode"]) == "held")
	## Robo y tapon.
	var st3: Dictionary = M.new_state(lv)
	st3["pause_t"] = 0.0
	var thief: Dictionary = st3["players"][2]
	thief["skill"] = 1.0
	(st3["players"][0] as Dictionary)["skill"] = 0.0
	var got: bool = false
	for k3: int in 40:
		thief["p"] = (st3["players"][0]["p"] as Vector2) + Vector2(0.6, 0)
		thief["steal_cd"] = 0.0
		M._steal(st3, thief)
		if int(st3["owner"]) == 2:
			got = true
			break
	check("baloncesto: robar el balon funciona a veces", got)
	var st4: Dictionary = M.new_state(lv)
	st4["pause_t"] = 0.0
	var blocker: Dictionary = st4["players"][2]
	blocker["skill"] = 1.0
	var blocked: bool = false
	for k4: int in 40:
		st4["ball"]["mode"] = "held"
		st4["owner"] = 0
		st4["clear"] = false
		blocker["p"] = (st4["players"][0]["p"] as Vector2) + Vector2(0, -0.6)
		blocker["jump"] = 0.4
		M.shoot_ball(st4, st4["players"][0], M.PERFECT)
		if bool(st4["ball"].get("blocked", false)):
			blocked = true
			break
	check("baloncesto: saltar pegado al tirador tapona", blocked)
	## Reloj de posesion.
	var st5: Dictionary = M.new_state(lv)
	st5["pause_t"] = 0.0
	st5["clock"] = 0.02
	M.step(st5, {"move": Vector2.ZERO}, 1.0 / 30.0)
	check("baloncesto: si se acaba la posesion el balon es del rival", int(st5["poss"]) == 1)
	var r: Dictionary = M.bot_play(lv)
	check("baloncesto: el bot gana el partido", bool(r["won"]), str(r))
	check("baloncesto: el analizador lo acepta", bool(M.analyze(lv)["completable"]))
	var hard: Dictionary = lv.duplicate()
	hard["skill"] = 1.0
	hard["mates"] = 0.0
	hard["players"] = 3
	hard["points"] = 21
	check("baloncesto: un rival imposible se rechaza", not bool(M.analyze(hard)["completable"]))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "basket"
	Kit.config["levels"] = [lv]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/basket.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	check("baloncesto: pista 3D, canasta, jugadores y botones", g is Node3D and g.find_child("Rim", true, false) != null and g.find_child("Player3", true, false) != null and g.find_child("BtnShoot", true, false) != null)
	var Bot: GDScript = load("res://qa/basket_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 30000)
	check("baloncesto: el bot gana jugando", won, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0

## Tenis 3D: saque al cuadro cruzado, golpe al alcance, red, fuera, doble bote, tanteo con
## iguales y ventaja, el bot y el analizador.
func _test_tennis() -> void:
	print("- Tenis 3D")
	var M: GDScript = load("res://kit/tennis/tennis_map.gd")
	var lv: Dictionary = {"name": "T", "map": ["pista", "#5"], "skill": 0.3, "games": 1, "speed": 0.4}
	var st: Dictionary = M.new_state(lv)
	check("tenis: sacas tu desde tu linea de fondo", str(st["phase"]) == "serve" and int(st["server"]) == 0 and (st["players"][0]["p"] as Vector2).y > M.HL)
	st["pause_t"] = 0.0
	M.step(st, {"move": Vector2.ZERO, "hit": true}, 1.0 / 30.0)
	var land: Vector2 = st["ball"]["landed"]
	check("tenis: el saque va al cuadro cruzado", str(st["phase"]) == "rally" and land.y < 0.0 and land.y > -M.SERVICE and land.x < 0.0)
	## Golpe: con la pelota a tu alcance sale solo; con GOLPE a tiempo es perfecto.
	var st2: Dictionary = M.new_state(lv)
	st2["phase"] = "rally"
	st2["pause_t"] = 0.0
	var b: Dictionary = st2["ball"]
	var me: Dictionary = st2["players"][0]
	me["p"] = Vector2(0, 9.0)
	b["p"] = Vector2(0, 8.6)
	b["h"] = 1.0
	b["v"] = Vector2(0, 8.0)
	b["vh"] = 0.0
	b["bounces"] = 1
	b["last"] = 1
	b["live"] = true
	st2["events"] = []
	M.step(st2, {"move": Vector2.ZERO, "hit": true}, 1.0 / 30.0)
	var perfect: bool = false
	for e: Dictionary in st2["events"]:
		if str(e["kind"]) == "hit" and int(e["i"]) == 0:
			perfect = bool(e["perfect"])
	check("tenis: la pelota a tu alcance se golpea (perfecto si pulsas)", int(st2["ball"]["last"]) == 0 and perfect and (st2["ball"]["v"] as Vector2).y < 0.0)
	## Red: una pelota baja choca con la red y el punto es del otro.
	var st3: Dictionary = M.new_state(lv)
	st3["phase"] = "rally"
	st3["pause_t"] = 0.0
	var b3: Dictionary = st3["ball"]
	b3["p"] = Vector2(0, 0.3)
	b3["h"] = 0.4
	b3["v"] = Vector2(0, -10.0)
	b3["vh"] = 0.0
	b3["bounces"] = 0
	b3["last"] = 0
	b3["live"] = true
	for k: int in 3:
		M.step(st3, {"move": Vector2.ZERO}, 1.0 / 30.0)
	check("tenis: a la red es punto para el rival", int(st3["points"][1]) == 1)
	## Fuera: bota fuera de la pista del rival.
	var st4: Dictionary = M.new_state(lv)
	st4["phase"] = "rally"
	st4["pause_t"] = 0.0
	var b4: Dictionary = st4["ball"]
	b4["p"] = Vector2(M.HW + 1.0, -5.0)
	b4["h"] = 0.05
	b4["v"] = Vector2(0, -3.0)
	b4["vh"] = -3.0
	b4["bounces"] = 0
	b4["last"] = 0
	b4["live"] = true
	(st4["players"][1] as Dictionary)["p"] = Vector2(-3.0, -12.0)
	M.step(st4, {"move": Vector2.ZERO}, 1.0 / 30.0)
	check("tenis: si bota fuera el punto es del otro", int(st4["points"][1]) == 1)
	## Tanteo: iguales, ventaja y juego.
	var st5: Dictionary = M.new_state(lv)
	st5["points"] = [3, 3]
	check("tenis: 40 iguales", M.score_text(st5, 0) == "40" and M.score_text(st5, 1) == "40")
	M._point(st5, 0, "test")
	check("tenis: ventaja", M.score_text(st5, 0) == "AD")
	M._point(st5, 0, "test")
	check("tenis: juego y partido", int(st5["games"][0]) == 1 and bool(st5["over"]) and bool(st5["won"]))
	var r: Dictionary = M.bot_play(lv)
	check("tenis: el bot gana el partido", bool(r["won"]), str(r))
	check("tenis: el analizador lo acepta", bool(M.analyze(lv)["completable"]))
	var hard: Dictionary = lv.duplicate()
	hard["skill"] = 1.0
	hard["games"] = 3
	hard["speed"] = 1.0
	check("tenis: un rival imposible se rechaza", not bool(M.analyze(hard)["completable"]))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "tennis"
	Kit.config["levels"] = [lv]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/tennis.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	check("tenis: pista 3D, red, jugadores y botones", g is Node3D and g.find_child("Net", true, false) != null and g.find_child("Player1", true, false) != null and g.find_child("BtnHit", true, false) != null)
	var Bot: GDScript = load("res://qa/tennis_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 30000)
	check("tenis: el bot gana jugando", won, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0

## Karts 3D: circuito, cuenta atras, acelerar y girar, hierba que frena, derrape con turbo,
## placa de turbo, vueltas y puesto, el bot y el analizador.
func _test_kart() -> void:
	print("- Karts 3D")
	var M: GDScript = load("res://kit/kart/kart_map.gd")
	var ring: Array = []
	for k: int in 12:
		var a: float = TAU * float(k) / 12.0
		ring.append("%.1f,%.1f" % [cos(a) * 70.0, sin(a) * 45.0])
	ring.append("B,3")
	ring.append("#7")
	var lv: Dictionary = {"name": "K", "map": ring, "laps": 2, "skill": 0.2, "need": 3, "rivals": 5, "width": 12}
	var st: Dictionary = M.new_state(lv)
	check("karts: circuito, 6 karts y una placa de turbo", (st["karts"] as Array).size() == 6 and (st["pads"] as Array).size() == 1 and float(st["track"]["length"]) > 300.0 and M.track_issues(st).is_empty())
	var me: Dictionary = st["karts"][0]
	var p0: Vector2 = me["p"]
	M.step(st, {"steer": 0.0}, 1.0)
	check("karts: en la cuenta atras nadie se mueve", (me["p"] as Vector2) == p0)
	var solo: Dictionary = lv.duplicate()
	solo["rivals"] = 1
	st = M.new_state(solo)
	me = st["karts"][0]
	st["go_t"] = 0.0
	for k2: int in 30:
		M.step(st, {"steer": 0.0, "gas": 1.0}, 1.0 / 30.0)
	check("karts: acelera solo", float(me["v"]) > 12.0)
	var a0: float = float(me["a"])
	for k3: int in 15:
		M.step(st, {"steer": 1.0, "gas": 1.0}, 1.0 / 30.0)
	check("karts: girar cambia el rumbo", absf(wrapf(float(me["a"]) - a0, -PI, PI)) > 0.3)
	## Hierba: fuera de la pista se va despacio.
	var st2: Dictionary = M.new_state(lv)
	st2["go_t"] = 0.0
	var k2d: Dictionary = st2["karts"][0]
	var nrm: Vector2 = (st2["track"]["tan"][int(k2d["idx"])] as Vector2).orthogonal()
	k2d["p"] = (k2d["p"] as Vector2) + nrm * 9.0
	k2d["v"] = 20.0
	for k4: int in 45:
		M.step(st2, {"steer": 0.0, "gas": 1.0}, 1.0 / 30.0)
		k2d["a"] = (st2["track"]["tan"][int(k2d["idx"])] as Vector2).angle()
	check("karts: la hierba frena", bool(k2d["off"]) and float(k2d["v"]) <= M.GRASS_V + 0.5)
	## Derrape: mantener girando carga el turbo; al soltar sale disparado.
	var st3: Dictionary = M.new_state(lv)
	st3["go_t"] = 0.0
	var k3d: Dictionary = st3["karts"][0]
	k3d["v"] = 20.0
	for k5: int in 45:
		M.step(st3, {"steer": 1.0, "drift": true, "gas": 1.0}, 1.0 / 30.0)
		k3d["p"] = st3["track"]["line"][int(k3d["idx"])]
	var lvl: int = M.drift_level(k3d)
	st3["events"] = []
	M.step(st3, {"steer": 0.0, "drift": false, "gas": 1.0}, 1.0 / 30.0)
	var turbo: bool = false
	for e: Dictionary in st3["events"]:
		if str(e["kind"]) == "mini_turbo" and int(e["i"]) == 0:
			turbo = true
	check("karts: el derrape largo da turbo al soltar", lvl >= 2 and turbo and float(k3d["boost_t"]) > 0.0)
	## Vueltas y puesto: con el bot.
	var r: Dictionary = M.bot_play(lv)
	check("karts: el bot termina la carrera en puesto", bool(r["won"]) and int(r["place"]) <= 3, str(r))
	check("karts: el analizador lo acepta", bool(M.analyze(lv)["completable"]))
	var bad: Dictionary = lv.duplicate()
	bad["map"] = ["0,0", "60,0", "60,40", "0,-40", "-60,40", "-60,0", "#3"]
	check("karts: un circuito que se cruza se rechaza", not bool(M.analyze(bad)["completable"]))
	var hard: Dictionary = lv.duplicate()
	hard["skill"] = 1.0
	hard["need"] = 1
	hard["rivals"] = 7
	hard["laps"] = 1
	check("karts: ganar a 7 rivales perfectos saliendo el ultimo se rechaza", not bool(M.analyze(hard)["completable"]))
	## Objetos: cajas, platano, cascara, escudo y turbo.
	var sti: Dictionary = M.new_state(lv)
	sti["go_t"] = 0.0
	check("karts: dos filas de tres cajas de objetos", (sti["boxes"] as Array).size() == 6)
	var off: Dictionary = lv.duplicate()
	off["items"] = false
	check("karts: sin objetos no hay cajas", (M.new_state(off)["boxes"] as Array).is_empty())
	var mi: Dictionary = sti["karts"][0]
	mi["p"] = sti["boxes"][0]["p"]
	mi["idx"] = int(sti["boxes"][0]["i"])
	M.step(sti, {"steer": 0.0, "gas": 0.0}, 1.0 / 30.0)
	var got: bool = false
	for e2: Dictionary in sti["events"]:
		if str(e2["kind"]) == "item_get" and int(e2["i"]) == 0:
			got = true
	check("karts: pasar por una caja da un objeto", got and str(mi["item"]) in M.ITEM_KINDS and float(sti["boxes"][0]["cd"]) > 0.0, str(mi["item"]))
	var sth: Dictionary = M.new_state(solo)
	sth["go_t"] = 0.0
	var mh: Dictionary = sth["karts"][0]
	var fwd: Vector2 = Vector2.from_angle(float(mh["a"]))
	M.add_shot(sth, {"id": "9:1", "n": 1, "owner": 9, "kind": "platano", "p": (mh["p"] as Vector2) + fwd * 0.6, "d": fwd, "v": 0.0, "ttl": 20.0, "age": 5.0, "idx": int(mh["idx"])})
	M.step(sth, {"steer": 0.0, "gas": 1.0}, 1.0 / 30.0)
	check("karts: pisar un platano hace trompear y lo gasta", float(mh["stun"]) > 0.0 and (sth["shots"] as Array).is_empty())
	var vs: float = float(mh["v"])
	for k6: int in 10:
		M.step(sth, {"steer": 1.0, "gas": 1.0}, 1.0 / 30.0)
	check("karts: en el trompo no hay mando y frena", float(mh["v"]) <= vs and float(mh["steer"]) == 0.0)
	var stc: Dictionary = M.new_state(solo)
	stc["go_t"] = 0.0
	var mc: Dictionary = stc["karts"][0]
	var rv: Dictionary = stc["karts"][1]
	var lnc: Array = stc["track"]["line"]
	mc["idx"] = 10
	mc["p"] = lnc[10]
	mc["a"] = (stc["track"]["tan"][10] as Vector2).angle()
	rv["idx"] = 18
	rv["p"] = lnc[18]
	rv["v"] = 0.0
	mc["item"] = "cascara"
	var shot: Dictionary = M.use_item(stc, mc)
	var hit_rv: bool = false
	for k7: int in 60:
		M.step(stc, {"steer": 0.0, "gas": 0.0}, 1.0 / 30.0)
		if float(rv["stun"]) > 0.0:
			hit_rv = true
	check("karts: la cascara sale hacia delante y da al de delante", str(shot.get("kind", "")) == "cascara" and hit_rv and str(mc["item"]) == "")
	mc["item"] = "platano"
	mc["stun"] = 0.0
	M.hit(stc, mc, "cascara", "x")
	check("karts: llevar un objeto en la mano para una cascara", float(mc["stun"]) == 0.0 and str(mc["item"]) == "")
	mc["item"] = "turbo"
	mc["boost_t"] = 0.0
	M.use_item(stc, mc)
	check("karts: el turbo acelera ya", float(mc["boost_t"]) > 1.0 and (stc["shots"] as Array).size() == 0)
	## Karts de la red: no los mueve la simulacion; llegan con net_apply y se suavizan.
	var stn: Dictionary = M.new_state(solo)
	stn["go_t"] = 0.0
	var rk: Dictionary = stn["karts"][1]
	rk["remote"] = true
	var rp: Vector2 = rk["p"]
	for k8: int in 20:
		M.step(stn, {"steer": 0.0, "gas": 1.0}, 1.0 / 30.0)
	var still: bool = (rk["p"] as Vector2) == rp
	var sent: Dictionary = M.net_state(stn["karts"][0])
	M.net_apply(stn, rk, sent)
	check("karts: un kart de la red no lo mueve la simulacion y llega con su estado", still and (rk["p"] as Vector2).distance_to(stn["karts"][0]["p"]) < 0.05 and int(rk["lap"]) == int(stn["karts"][0]["lap"]))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "kart"
	Kit.config["levels"] = [lv]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/kart.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	check("karts: pista 3D, karts y botones", g is Node3D and g.find_child("Road", true, false) != null and g.find_child("Kart5", true, false) != null and g.find_child("BtnDrift", true, false) != null)
	check("karts: cajas de objetos en la pista y boton de objeto", g.find_child("ItemBox5", true, false) != null and g.find_child("BtnItem", true, false) != null)
	var gst: Dictionary = g.get("st")
	gst["go_t"] = 0.0
	gst["karts"][0]["item"] = "cascara"
	g.set("_use_pressed", true)
	await frames(3)
	check("karts: el boton de objeto lanza la cascara y se ve en la pista", str(gst["karts"][0]["item"]) == "" and g.find_children("Shot_*", "", true, false).size() >= 1)
	var Bot: GDScript = load("res://qa/kart_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 30000)
	check("karts: el bot gana jugando", won, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0

## Triple de fichas: capas, fichas tapadas, reparto en trios, bandeja, ayudas, bot y escena.
func _test_triple() -> void:
	print("- Triple de fichas")
	var M: GDScript = load("res://kit/triple/triple_map.gd")
	var lv: Dictionary = {"name": "T", "map": ["=0", "XXXX", "XXXX", "XXXX", "=1", "XXX", "XXX", "=2", ".XX", "#9"], "kinds": 4, "undo": 2, "shuffle": 1}
	var info: Dictionary = M.parse(lv)
	var tiles: Array = info["tiles"]
	check("triple: capas desplazadas media ficha y fichas multiplo de 3", tiles.size() == 18 and float(tiles[12]["x"]) == 0.5 and float(tiles[12]["y"]) == 0.5 and int(tiles[12]["z"]) == 1)
	var st: Dictionary = M.new_state(lv)
	var by: Dictionary = {}
	for t: Dictionary in st["tiles"]:
		by[int(t["kind"])] = int(by.get(int(t["kind"]), 0)) + 1
	var trios: bool = true
	for k: int in by:
		if k < 0 or int(by[k]) % 3 != 0:
			trios = false
	check("triple: cada dibujo sale de tres en tres", trios and by.size() >= 3, str(by))
	check("triple: la ficha de abajo tapada no se puede coger", not M.is_free(st, 5) and not M.pick(st, 5) and M.free_tiles(st).size() >= 2)
	## Bandeja: tres iguales desaparecen; las de un dibujo van juntas.
	st = M.new_state(lv)
	for t2: Dictionary in st["tiles"]:
		t2["kind"] = int(t2["id"]) / 3
		t2["gone"] = int(t2["z"]) > 0
	M.pick(st, 0)
	M.pick(st, 3)
	M.pick(st, 1)
	var tray_ok: bool = int(st["tray"][0]["kind"]) == 0 and int(st["tray"][1]["kind"]) == 0 and int(st["tray"][2]["kind"]) == 1
	M.pick(st, 2)
	check("triple: en la bandeja van juntas las iguales y tres iguales desaparecen", tray_ok and (st["tray"] as Array).size() == 1 and int(st["cleared"]) == 3)
	check("triple: deshacer devuelve la ultima ficha a su sitio", M.undo(st) and (st["tray"] as Array).is_empty() and not bool(st["tiles"][3]["gone"]))
	## Bandeja llena sin trio: se pierde.
	var stf: Dictionary = M.new_state(lv)
	for t3: Dictionary in stf["tiles"]:
		t3["kind"] = int(t3["id"]) % 6
		t3["gone"] = int(t3["z"]) > 0
	for id: int in [0, 1, 2, 3, 4, 5, 6]:
		M.pick(stf, id)
	check("triple: con la bandeja llena se pierde", bool(stf["over"]) and not bool(stf["won"]))
	## Barajar a mitad: sigue habiendo forma de ganar contando lo de la bandeja.
	var wins: int = 0
	for sd: int in 6:
		var lvs: Dictionary = lv.duplicate()
		lvs["map"] = ["=0", "XXXX", "XXXX", "XXXX", "=1", "XXX", "XXX", "=2", ".XX", "#%d" % (40 + sd)]
		var s2: Dictionary = M.new_state(lvs)
		M.pick(s2, (M.free_tiles(s2)[0] as Dictionary)["id"])
		M.pick(s2, (M.free_tiles(s2)[0] as Dictionary)["id"])
		M.shuffle(s2)
		var counts: Dictionary = {}
		for t4: Dictionary in s2["tiles"]:
			counts[int(t4["kind"])] = int(counts.get(int(t4["kind"]), 0)) + 1
		var guard: int = 0
		while not bool(s2["over"]) and guard < 200:
			M.bot_step(s2)
			guard += 1
		if bool(s2["won"]):
			wins += 1
	check("triple: barajar a mitad deja la partida ganable", wins >= 5, "%d/6" % wins)
	var r: Dictionary = M.bot_play(lv)
	check("triple: el bot vacia el monton", bool(r["won"]), str(r))
	check("triple: el analizador lo acepta", bool(M.analyze(lv)["completable"]))
	check("triple: un monton de 3 fichas se rechaza", not bool(M.analyze({"map": ["=0", "XXX"]})["completable"]) or M.parse({"map": ["=0", "XXX"]})["tiles"].size() >= 6)
	## La escena.
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "triple"
	Kit.config["levels"] = [lv]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/triple.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	check("triple: monton, bandeja y botones de ayuda", g.find_child("World", true, false) != null and g.find_child("BtnUndo", true, false) != null and g.find_child("BtnShuffle", true, false) != null)
	var gst: Dictionary = g.get("st")
	var free0: Dictionary = M.free_tiles(gst)[0]
	g.call("tap", (g.call("tile_rect", free0) as Rect2).get_center())
	check("triple: tocar una ficha libre la lleva a la bandeja", (gst["tray"] as Array).size() == 1 and bool(free0["gone"]))
	var Bot: GDScript = load("res://qa/triple_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 6000)
	check("triple: el bot gana jugando", won, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0

## Plantas contra zombis: soles, plantar, recarga, disparos, comer, nuez, patatamina, cereza,
## cortacesped, final, bot, analizador y escena.
func _test_lawn() -> void:
	print("- Plantas contra zombis")
	var M: GDScript = load("res://kit/lawn/lawn_map.gd")
	var lv: Dictionary = {"name": "J", "map": ["jardin", "#5"], "plants": ["sunflower", "peashooter", "wallnut", "potatomine", "cherrybomb"],
		"waves": [{"t": 5.0, "z": ["normal"]}, {"t": 25.0, "z": ["normal", "cone"]}], "sun": 150}
	var st: Dictionary = M.new_state(lv)
	check("plantas: soles al empezar y cartas listas (las bombas tardan)", int(st["sun"]) == 150 and M.can_plant(st, "peashooter", Vector2i(0, 7)) and not M.can_afford(st, "cherrybomb"))
	check("plantas: plantar cuesta soles y pone la carta a recargar", M.plant(st, "peashooter", Vector2i(2, 7)) and int(st["sun"]) == 50 and not M.can_plant(st, "peashooter", Vector2i(3, 7)))
	check("plantas: no se planta encima de otra", not M.plant(st, "sunflower", Vector2i(2, 7)))
	## Soles: caen del cielo, se cogen y caducan.
	for k: int in 50:
		M.step(st, 0.1)
	var got: bool = false
	if not (st["suns"] as Array).is_empty():
		var before: int = int(st["sun"])
		got = M.collect(st, int(st["suns"][0]["id"])) and int(st["sun"]) == before + 25
	check("plantas: los soles del cielo se cogen (+25)", got)
	## El tirador dispara al zombi de su carril y lo mata.
	var sh: Dictionary = M.new_state({"map": ["jardin", "#1"], "waves": [{"t": 0.1, "z": ["normal"]}], "sun": 500})
	M.step(sh, 0.2)
	var lane: int = int(sh["zombies"][0]["lane"])
	M.plant(sh, "peashooter", Vector2i(lane, 8))
	sh["ready"]["peashooter"] = 0.0
	M.plant(sh, "peashooter", Vector2i(lane, 7))
	for k2: int in 600:
		M.step(sh, 0.1)
		if bool(sh["over"]):
			break
	check("plantas: los tiradores acaban con el zombi y se gana", bool(sh["won"]) and int(sh["killed"]) == 1, str(sh["zombies"]))
	## Comer: un zombi se come lo que tiene delante; la nuez aguanta mucho mas.
	var ea: Dictionary = M.new_state({"map": ["jardin", "#1"], "waves": [{"t": 0.1, "z": ["normal"]}], "sun": 500})
	M.step(ea, 0.2)
	var ln: int = int(ea["zombies"][0]["lane"])
	ea["zombies"][0]["y"] = 2.5
	M.plant(ea, "sunflower", Vector2i(ln, 3))
	for k3: int in 40:
		M.step(ea, 0.1)
	check("plantas: el zombi se come el girasol", not (ea["plants"] as Dictionary).has(Vector2i(ln, 3)))
	ea["ready"]["wallnut"] = 0.0
	M.plant(ea, "wallnut", Vector2i(ln, 4))
	for k4: int in 100:
		M.step(ea, 0.1)
	check("plantas: la nuez aguanta (frena al zombi)", (ea["plants"] as Dictionary).has(Vector2i(ln, 4)) and float(ea["zombies"][0]["y"]) < 4.6)
	## Cereza: revienta en 3x3.
	ea["sun"] = 500
	ea["ready"]["cherrybomb"] = 0.0
	ea["cards"].append("cherrybomb")
	M.plant(ea, "cherrybomb", Vector2i(clampi(ln + 1, 0, 4) if ln < 4 else ln - 1, 4))
	for k5: int in 20:
		M.step(ea, 0.1)
	check("plantas: la cereza revienta a los de alrededor", int(ea["killed"]) == 1)
	## Cortacesped: salva una vez; la segunda, se pierde.
	var mw: Dictionary = M.new_state({"map": ["jardin", "#1"], "waves": [{"t": 0.1, "z": ["runner"]}, {"t": 0.2, "z": ["normal"]}, {"t": 99.0, "z": ["normal"]}], "sun": 0})
	M.step(mw, 0.3)
	for z: Dictionary in mw["zombies"]:
		z["lane"] = 0
	mw["zombies"][0]["y"] = 8.95
	M.step(mw, 0.5)
	check("plantas: el cortacesped limpia el carril y se gasta", not bool(mw["mowers"][0]) and (mw["zombies"] as Array).is_empty() and not bool(mw["over"]))
	(mw["zombies"] as Array).append({"id": 99, "kind": "normal", "lane": 0, "y": 8.95, "hp": 190.0, "max": 190.0, "speed": 0.2, "slow": 0.0, "eating": false})
	M.step(mw, 0.5)
	check("plantas: sin cortacesped, el zombi entra y se pierde", bool(mw["over"]) and not bool(mw["won"]))
	var r: Dictionary = M.bot_play(lv)
	check("plantas: el bot gana", bool(r["won"]), str(r))
	check("plantas: el analizador lo acepta", bool(M.analyze(lv)["completable"]))
	## La escena.
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "lawn"
	Kit.config["levels"] = [lv]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/lawn.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	check("plantas: jardin, soles, oleadas y cartas", g.find_child("World", true, false) != null and g.find_child("Sun", true, false) != null and g.find_child("Card_peashooter", true, false) != null)
	g.set("sel", "sunflower")
	var gst: Dictionary = g.get("st")
	g.call("tap", (g.call("cell_rect", Vector2i(1, 8)) as Rect2).get_center())
	check("plantas: tocar carta y casilla planta", (gst["plants"] as Dictionary).has(Vector2i(1, 8)))
	var Bot: GDScript = load("res://qa/lawn_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 6000)
	check("plantas: el bot gana jugando", won, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0

## Tirachinas: lectura del mapa (tablones, postes, cerdos), balistica, analizador, escena con
## fisica real, golpes que rompen, poderes, explosion y bot.
func _test_sling() -> void:
	print("- Tirachinas")
	var M: GDScript = load("res://kit/sling/sling_map.gd")
	var lv: Dictionary = {"name": "S", "birds": ["red", "yellow", "black", "blue"], "map": [".P....SWS", "===...SPS", "|P|.P.SSS", "WWW.WW###", "#3"]}
	var info: Dictionary = M.parse(lv)
	var planks: int = 0
	var posts: int = 0
	for p: Dictionary in info["pieces"]:
		if str(p["mat"]) == "=":
			planks += 1
			check("tirachinas: un tablon de tres casillas es una sola pieza", absf((p["rect"] as Rect2).size.x - M.CELL * 3.0) < 0.1)
		elif str(p["mat"]) == "|":
			posts += 1
	check("tirachinas: postes, cerdos y rocas", planks == 1 and posts == 2 and (info["pigs"] as Array).size() == 4)
	## Balistica: el angulo calculado lleva el tiro al punto.
	var to: Vector2 = Vector2(800, -120)
	var ang: Array[float] = M.aim_angles(M.SLING, to, M.max_speed() * 0.95)
	var v: Vector2 = M.launch_velocity(M.pull_for(ang[0], M.max_speed() * 0.95))
	var t_hit: float = (to.x - M.SLING.x) / v.x
	check("tirachinas: el tiro calculado pasa por el blanco (tenso y en parabola)", ang.size() == 2 and M.at_time(M.SLING, v, t_hit).distance_to(to) < 2.0)
	check("tirachinas: fuera de alcance no hay angulo", M.aim_angles(M.SLING, Vector2(4000, -100), M.max_speed()).is_empty())
	check("tirachinas: el analizador acepta una estructura apoyada", bool(M.analyze(lv)["completable"]), str(M.analyze(lv)["issues"]))
	check("tirachinas: un bloque en el aire se rechaza", "sling_floating" in M.analyze({"map": ["W..", "...", "WWW"]})["issues"])
	check("tirachinas: sin cerdos se rechaza", "sling_no_pigs" in M.analyze({"map": ["WWW"]})["issues"])
	## La escena con fisica de verdad.
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "sling"
	Kit.config["levels"] = [lv]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/sling.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(100)
	check("tirachinas: la estructura se queda en pie sola", (g.call("pigs_alive") as Array).size() == 4 and int(g.get("score")) == 0, str(g.call("bot_state")))
	## Un tiro directo al cerdo de la izquierda lo mata.
	var pig: Node2D = (g.call("pigs_alive") as Array)[0]
	var a2: Array[float] = M.aim_angles(M.SLING, pig.position, M.max_speed() * 0.98)
	check("tirachinas: soltar lanza al pajaro", bool(g.call("shoot", M.pull_for(a2[0], M.max_speed() * 0.98))) and str(g.get("_state")) == "flying")
	await frames(90)
	check("tirachinas: el golpe acaba con el cerdo y da puntos", not is_instance_valid(pig) or bool(pig.get("dead")) or int(g.get("score")) >= 5000, str(g.call("bot_state")))
	## Explosion: rompe y empuja lo que hay cerca.
	var before: int = int(g.get("score"))
	g.call("_explode", Vector2(M.STRUCT_X + 7.0 * M.CELL, -1.5 * M.CELL), 170.0, 400.0)
	await frames(2)
	check("tirachinas: la explosion rompe lo que pilla", int(g.get("score")) > before)
	g.queue_free()
	await frames(2)
	## El bot gana jugando.
	var g2: Node = (load("res://scenes/sling.tscn") as PackedScene).instantiate()
	add_child(g2)
	var Bot: GDScript = load("res://qa/sling_bot.gd")
	var won: bool = await Bot.run(get_tree(), g2, 60 * 90)
	check("tirachinas: el bot gana jugando", won, str(g2.call("bot_state")))
	if g2.get("result_panel") != null:
		(g2.get("result_panel") as Node).queue_free()
	g2.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0

## Escalada: suelo suave, suspension, gas y freno, vuelco, gasolina, bidones, mejoras, bot,
## analizador y escena.
func _climb_level(hs: Array, extra: Dictionary = {}) -> Dictionary:
	var rows: Array = ["T:" + ",".join(hs.map(func(v: float) -> String: return str(v)))]
	rows.append_array(extra.get("rows", []))
	rows.append("#3")
	var lv: Dictionary = {"name": "C", "map": rows}
	for k: String in extra:
		if k != "rows":
			lv[k] = extra[k]
	return lv

func _test_climb() -> void:
	print("- Escalada")
	var M: GDScript = load("res://kit/climb/climb_map.gd")
	var flat: Array = []
	for k: int in 60:
		flat.append(0.0)
	var lv: Dictionary = _climb_level(flat, {"rows": ["F:100", "C:20,22,24"], "goal": 180})
	var st: Dictionary = M.new_state(lv)
	for k2: int in 240:
		M.step(st, false, false)
	check("escalada: el coche se posa sobre las dos ruedas y se queda quieto", bool(st["touch"][0]) and bool(st["touch"][1]) and absf(float(st["a"])) < 0.05 and (st["v"] as Vector2).length() < 0.3)
	var x0: float = (st["p"] as Vector2).x
	for k3: int in 240:
		M.step(st, true, false)
	check("escalada: con gas avanza", (st["p"] as Vector2).x > x0 + 8.0, str((st["p"] as Vector2).x - x0))
	var vx: float = (st["v"] as Vector2).x
	for k4: int in 120:
		M.step(st, false, true)
	check("escalada: el freno frena", (st["v"] as Vector2).x < vx * 0.5, "%f %f" % [vx, (st["v"] as Vector2).x])
	check("escalada: las monedas se recogen al pasar", (st["coins_got"] as Array).size() == 3)
	## Gasolina: se gasta; el bidon la llena; sin ella el coche se para y se acaba.
	var sf: Dictionary = M.new_state(_climb_level(flat, {"goal": 180}))
	sf["fuel"] = 1.0
	for k5: int in 8000:
		M.step(sf, true, false)
		if bool(sf["over"]):
			break
	check("escalada: sin gasolina se para y se acaba", bool(sf["over"]) and str(sf["cause"]) == "fuel", str(sf["cause"]))
	var sb: Dictionary = M.new_state(lv)
	sb["fuel"] = 30.0
	for k6: int in 2400:
		M.step(sb, true, false)
		if (sb["fuel_got"] as Array).size() > 0 or bool(sb["over"]):
			break
	check("escalada: el bidon llena el deposito", (sb["fuel_got"] as Array).size() == 1 and float(sb["fuel"]) > 99.0)
	## Vuelco: boca abajo, la cabeza toca el suelo.
	var sv: Dictionary = M.new_state(lv)
	sv["a"] = PI
	sv["p"] = Vector2(10.0, 1.4)
	for k7: int in 120:
		M.step(sv, false, false)
		if bool(sv["over"]):
			break
	check("escalada: si la cabeza toca el suelo, vuelco", bool(sv["over"]) and str(sv["cause"]) == "crash")
	## En el aire el gas levanta el morro.
	var sa: Dictionary = M.new_state(lv)
	sa["p"] = Vector2(20.0, 30.0)
	for k8: int in 40:
		M.step(sa, true, false)
	check("escalada: en el aire el gas levanta el morro", float(sa["a"]) > 0.15, str(sa["a"]))
	## Llegar a la meta.
	var sg: Dictionary = M.new_state(lv)
	for k9: int in 6000:
		M.step(sg, true, false)
		if bool(sg["over"]):
			break
	check("escalada: llegar a la meta gana", bool(sg["won"]))
	## Mejoras: el motor da mas fuerza y el deposito mas gasolina.
	var su: Dictionary = M.new_state(lv, {"motor": 2, "deposito": 1})
	check("escalada: mejoras de motor y deposito", float(su["engine"]) > float(M.new_state(lv)["engine"]) and float(su["tank"]) == 125.0)
	## Suelo suave: sin escalones entre puntos (la pendiente no da saltos).
	var hill: Array = []
	for k10: int in 60:
		hill.append(float(k10) * 2.0)
	var info: Dictionary = M.parse(_climb_level(hill))
	var s1: float = M.ground(info, 41.0) - M.ground(info, 40.0)
	var s2: float = M.ground(info, 42.0) - M.ground(info, 41.0)
	check("escalada: el suelo es una curva suave (sin escalones)", absf(s1 - s2) < 0.05 and absf(s1 - 0.5) < 0.05, "%f %f" % [s1, s2])
	check("escalada: un muro se rechaza", "climb_wall" in M.analyze(_climb_level([0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 9.0, 9.0, 9.0, 9.0, 9.0, 9.0, 9.0, 9.0, 9.0, 9.0, 9.0, 9.0, 9.0, 9.0, 9.0, 9.0]))["issues"])
	var waves: Array = []
	for k11: int in 140:
		waves.append(sin(float(k11) * 0.25) * 3.0 * clampf(float(k11 - 8) / 20.0, 0.0, 1.0))
	var lw: Dictionary = _climb_level(waves, {"rows": ["F:250"], "goal": 500})
	var r: Dictionary = M.bot_play(lw)
	check("escalada: el bot llega a la meta por colinas", bool(r["won"]), str(r))
	check("escalada: el analizador lo acepta", bool(M.analyze(lw)["completable"]))
	## La escena.
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "climb"
	Kit.config["levels"] = [lw]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/climb.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	check("escalada: pedales de gas y freno, gasolina y distancia", g.find_child("BtnGas", true, false) != null and g.find_child("BtnBrake", true, false) != null and g.find_child("Fuel", true, false) != null and g.find_child("Distance", true, false) != null)
	var gst: Dictionary = g.get("st")
	var gx0: float = (gst["p"] as Vector2).x
	(g.find_child("BtnGas", true, false) as Button).button_down.emit()
	await frames(40)
	(g.find_child("BtnGas", true, false) as Button).button_up.emit()
	check("escalada: pisar el gas mueve el coche", (gst["p"] as Vector2).x > gx0 + 0.5, str((gst["p"] as Vector2).x - gx0))
	var Bot: GDScript = load("res://qa/climb_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 6000)
	check("escalada: el bot gana jugando", won, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0

## Duelo de cartas: torres, elixir, mano y mazo, donde se puede soltar, puentes, combate,
## coronas, hechizos, final por tiempo, IA contra bot, analizador y escena en 3D.
func _test_clash() -> void:
	print("- Duelo de cartas")
	var M: GDScript = load("res://kit/clash/clash_map.gd")
	var lv: Dictionary = {"name": "D", "map": ["arena", "#11"], "ai_elixir": 0.75, "ai_level": 0.85, "ai_react": 1.5}
	var st: Dictionary = M.new_state(lv)
	check("duelo: 3 torres por lado, 4 cartas en la mano y 4 en el mazo", M.towers(st, 0).size() == 3 and M.towers(st, 1).size() == 3
		and (st["hands"][0] as Array).size() == 4 and (st["queues"][0] as Array).size() == 4)
	for k: int in 28:
		M.step(st, 0.1)
	check("duelo: el elixir sube 1 cada 2,8 s", absf(float(st["elixir"][0]) - 6.0) < 0.05, str(st["elixir"][0]))
	check("duelo: no se sueltan tropas en el lado rival ni en el rio", not M.can_drop(0, "knight", Vector2(5, 10)) and not M.can_drop(0, "knight", Vector2(5, 16)) and M.can_drop(0, "knight", Vector2(5, 22)) and M.can_drop(0, "fireball", Vector2(5, 6)))
	## Jugar: cuesta elixir y la carta vuelve al final del mazo.
	st = M.new_state(lv)
	st["hands"][0] = ["knight", "archers", "giant", "arrows"]
	st["queues"][0] = ["minions", "musketeer", "skeletons", "fireball"]
	st["elixir"][0] = 2.0
	check("duelo: sin elixir no se juega", not M.play_card(st, 0, 2, Vector2(4, 24)) and float(st["elixir"][0]) == 2.0)
	st["elixir"][0] = 10.0
	check("duelo: jugar gasta elixir y la siguiente entra en la mano", M.play_card(st, 0, 0, Vector2(3.5, 22)) and float(st["elixir"][0]) == 7.0
		and str(st["hands"][0][0]) == "minions" and str((st["queues"][0] as Array).back()) == "knight")
	var kn: Dictionary = {}
	for e: Dictionary in st["ents"]:
		if str(e.get("card", "")) == "knight":
			kn = e
	for k2: int in 120:
		M.step(st, 0.1)
	check("duelo: el caballero cruza por el puente hacia la torre de su carril", not kn.is_empty() and (kn["p"] as Vector2).y < 15.0 and absf((kn["p"] as Vector2).x - 3.5) < 2.5, str(kn.get("p")))
	## Combate: llega a la torre y la golpea; al caer, corona y el rey despierta.
	var tw: Dictionary = {}
	for t: Dictionary in M.towers(st, 1):
		if str(t["kind"]) == "tower" and (t["p"] as Vector2).x < 9.0:
			tw = t
	tw["hp"] = 100.0
	for k3: int in 200:
		M.step(st, 0.1)
		if bool(tw["dead"]):
			break
	var king: Dictionary = {}
	for t2: Dictionary in M.towers(st, 1):
		if str(t2["kind"]) == "king":
			king = t2
	check("duelo: torre caida da corona y despierta al rey", bool(tw["dead"]) and int(st["crowns"][0]) == 1 and bool(king.get("active", false)), "%s %s" % [tw["dead"], st["crowns"]])
	## Hechizo: dana a las tropas en su circulo y menos a las torres.
	var sp: Dictionary = M.new_state(lv)
	sp["elixir"][0] = 10.0
	sp["hands"][0] = ["fireball", "arrows", "knight", "giant"]
	sp["elixir"][1] = 10.0
	sp["hands"][1] = ["skeletons", "archers", "knight", "giant"]
	M.play_card(sp, 1, 0, Vector2(9, 12))
	var tower_hp: float = float(M.towers(sp, 1)[0]["hp"])
	M.play_card(sp, 0, 0, Vector2(9, 12))
	var skel: int = 0
	for e2: Dictionary in sp["ents"]:
		if str(e2.get("card", "")) == "skeletons" and not bool(e2["dead"]):
			skel += 1
	check("duelo: la bola de fuego acaba con los esqueletos", skel == 0)
	## Fin por tiempo: con mas coronas gana; con empate, prorroga.
	var tt: Dictionary = M.new_state({"map": ["arena", "#3"], "time": 60})
	tt["crowns"] = [1, 0]
	tt["t"] = 59.95
	M.step(tt, 0.1)
	check("duelo: al acabar el tiempo gana quien tiene mas coronas", bool(tt["over"]) and int(tt["winner"]) == 0)
	var ot: Dictionary = M.new_state({"map": ["arena", "#3"], "time": 60})
	ot["t"] = 59.95
	M.step(ot, 0.1)
	check("duelo: con empate hay muerte subita", bool(ot["overtime"]) and not bool(ot["over"]))
	## Partida entera: bot contra la IA facil (y el analizador).
	var r: Dictionary = M.sim_match(lv)
	check("duelo: el bot gana a la IA facil", int(r["winner"]) == 0, str(r))
	check("duelo: la partida se juega de verdad (cartas de los dos lados)", int(r["played"][0]) >= 5 and int(r["played"][1]) >= 3, str(r["played"]))
	check("duelo: el analizador lo acepta", bool(M.analyze(lv)["completable"]))
	check("duelo: cartas que no existen se rechazan", "clash_bad_card" in M.analyze({"map": ["arena", "#1"], "deck": ["dragon_legendario"]})["issues"])
	## La escena en 3D.
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "clash"
	Kit.config["view"] = "3d"
	Kit.config["levels"] = [lv]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/clash.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(3)
	check("duelo: arena 3D, mano de 4 cartas y elixir", g.get("view3d") != null and g.find_child("Card_3", true, false) != null and g.find_child("Elixir", true, false) != null and g.find_child("Ground", true, false) != null)
	var gst: Dictionary = g.get("st")
	gst["elixir"][0] = 10.0
	var vw: Node = g.get("view3d")
	var spot: Vector2 = vw.call("screen_pos", Vector2(4.0, 23.0), 0.0)
	var back: Vector2 = g.call("screen_to_arena", spot)
	check("duelo: tocar la pantalla da el punto de la arena (rayo de la camara)", back.distance_to(Vector2(4.0, 23.0)) < 0.2, str(back))
	var n0: int = (gst["ents"] as Array).size()
	check("duelo: soltar una carta en tu lado saca la tropa", bool(g.call("deploy", 0, back)) and (gst["ents"] as Array).size() > n0 or str(M.CARDS[str(gst["queues"][0].back())].get("spell", false)) == "true")
	var Bot: GDScript = load("res://qa/clash_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 6000)
	check("duelo: el bot gana jugando", won, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0

## Bus jam: caminos a la salida, reparto en trios, autobus, parada, VIP, bot, analizador y escena.
const BJ_MAP: Array = ["..P.P", "PP#PP", "PPPPP", "P#P.P", "#5"]

func _test_bus() -> void:
	print("- Bus jam")
	var M: GDScript = load("res://kit/bus/bus_map.gd")
	var lv: Dictionary = {"name": "B", "map": BJ_MAP, "kinds": 3, "buses": 1, "hold": 4, "vip": 1}
	var info: Dictionary = M.parse(lv)
	check("autobus: pasajeros, paredes y multiplo de 3", (info["people"] as Array).size() == 12 and (info["walls"] as Dictionary).size() == 2, "%d" % (info["people"] as Array).size())
	var st: Dictionary = M.new_state(lv)
	var by: Dictionary = {}
	for p: Dictionary in st["people"]:
		by[int(p["color"])] = int(by.get(int(p["color"]), 0)) + 1
	var trios: bool = true
	for k: int in by:
		if k < 0 or int(by[k]) % 3 != 0:
			trios = false
	check("autobus: cada color de tres en tres y un autobus por trio", trios and (st["queue"] as Array).size() + 1 == 4, str(by))
	var occ: Dictionary = M.occupied(st)
	var id_top: int = int(occ[Vector2i(2, 0)])
	var id_deep: int = int(occ[Vector2i(2, 2)])
	check("autobus: el de arriba sale y el encerrado no", M.can_leave(st, id_top) and not M.can_leave(st, id_deep))
	check("autobus: el camino va por huecos libres hasta arriba", M.path_out(st, Vector2i(3, 3), occ).is_empty() and M.path_out(st, Vector2i(0, 1), occ).size() == 2)
	## Colores a mano: autobus rojo (0); azul (1) va a la parada; al llenarse el rojo llega el azul
	## y se lleva al que esperaba.
	st = M.new_state(lv)
	for p2: Dictionary in st["people"]:
		p2["color"] = 1 if int(p2["id"]) == id_top else 0
	st["buses"] = [{"color": 0, "ids": []}]
	st["queue"] = [1]
	M.pick(st, id_top)
	check("autobus: sin autobus de su color espera en la parada", (st["hold"] as Array).size() == 1)
	var reds: int = 0
	for p3: Dictionary in M.free_people(st):
		if reds < 3 and int(p3["color"]) == 0:
			M.pick(st, int(p3["id"]))
			reds += 1
	check("autobus: lleno se va, llega el siguiente y recoge al que esperaba", int(st["buses"][0]["color"]) == 1 and (st["buses"][0]["ids"] as Array).size() == 1 and (st["hold"] as Array).is_empty() and int(st["boarded"]) == 3, str(st["buses"]))
	## Parada llena sin jugada: con VIP atascado; el VIP saca a cualquiera; sin el, se pierde.
	var sf: Dictionary = M.new_state(lv)
	for p4: Dictionary in sf["people"]:
		p4["color"] = 0 if int(p4["id"]) == id_deep else 2
	sf["buses"] = [{"color": 0, "ids": []}]
	sf["queue"] = []
	sf["hold_max"] = 3
	for p5: Dictionary in [sf["people"][int(occ[Vector2i(2, 0)])], sf["people"][int(occ[Vector2i(4, 0)])], sf["people"][int(occ[Vector2i(0, 1)])]]:
		M.pick(sf, int(p5["id"]))
	check("autobus: parada llena con VIP: atascado pero no perdido", bool(sf["stuck"]) and not bool(sf["over"]), "%s %s" % [sf["stuck"], sf["over"]])
	var sv: Dictionary = M.new_state(lv)
	sv["buses"] = [{"color": int(sv["people"][id_deep]["color"]), "ids": []}]
	check("autobus: el VIP saca a uno encerrado", M.pick(sv, id_deep, true) and bool(sv["people"][id_deep]["gone"]) and int(sv["vip"]) == 0)
	sf["vip"] = 0
	M._check_end(sf)
	check("autobus: sin sitio ni VIP se pierde", bool(sf["over"]) and not bool(sf["won"]), str(sf["over"]))
	var wins: int = 0
	for sd: int in 8:
		var lvs: Dictionary = lv.duplicate()
		lvs["map"] = BJ_MAP.slice(0, 4) + ["#%d" % (40 + sd)]
		if bool(M.bot_play(lvs)["won"]):
			wins += 1
	check("autobus: el bot gana casi siempre", wins >= 7, "%d/8" % wins)
	check("autobus: el analizador lo acepta", bool(M.analyze(lv)["completable"]))
	check("autobus: pasajeros encerrados por paredes se rechazan", "bus_trapped" in M.analyze({"map": ["PPP", "###", "PPP", "PPP"]})["issues"])
	## La escena.
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "bus"
	Kit.config["levels"] = [lv]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/bus.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	check("autobus: estacion, autobus, parada y boton VIP", g.find_child("World", true, false) != null and g.find_child("BtnVip", true, false) != null)
	var gst: Dictionary = g.get("st")
	var f0: Dictionary = M.free_people(gst)[0]
	g.call("tap", g.call("person_pos", int(f0["id"])))
	check("autobus: tocar a un pasajero con camino lo saca", bool(f0["gone"]))
	var Bot: GDScript = load("res://qa/bus_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 6000)
	check("autobus: el bot gana jugando", won, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0

## Hexa sort: tablero de hexagonos, pilas ofrecidas, fusion en cadena, limpiar 10, martillo,
## tablero lleno, bot, analizador y escena.
const HX_MAP: Array = [" ..... ", ".......", "..#.#..", ".......", ".......", " ..... ", "#21"]

func _test_hexa() -> void:
	print("- Hexa sort")
	var M: GDScript = load("res://kit/hexa/hexa_map.gd")
	var lv: Dictionary = {"name": "H", "map": HX_MAP, "kinds": 3, "goal": 40, "hammer": 1}
	var info: Dictionary = M.parse(lv)
	check("hexa: casillas, piedras y fuera del tablero", (info["cells"] as Dictionary).size() == 36 and (info["stones"] as Array).size() == 2, "%d" % (info["cells"] as Dictionary).size())
	var st: Dictionary = M.new_state(lv)
	check("hexa: 3 pilas para elegir de 2 a 6 fichas", (st["offer"] as Array).size() == 3 and (st["offer"][0] as Array).size() >= 2 and (st["offer"][0] as Array).size() <= 6)
	var n6: Array = M.nbrs(st, Vector2i(3, 4))
	check("hexa: cada casilla de dentro tiene 6 vecinas (filas impares desplazadas)", n6.size() == 6 and n6.has(Vector2i(2, 3)) and n6.has(Vector2i(3, 5)) and not n6.has(Vector2i(4, 3)), str(n6))
	## Fusion en cadena: al poner [0,0,0] en (3,1) se lleva los 0 de (2,1); lo destapado en (2,1)
	## recoge los 1 de su vecina (1,1), que se queda vacia.
	st = M.new_state(lv)
	st["cells"][Vector2i(2, 1)] = [1, 1, 0, 0]
	st["cells"][Vector2i(1, 1)] = [1, 1, 1]
	st["offer"] = [[0, 0, 0], null, null]
	M.place(st, 0, Vector2i(3, 1))
	check("hexa: la pila puesta se lleva lo de su color de las vecinas", (st["cells"][Vector2i(3, 1)] as Array) == [0, 0, 0, 0, 0], str(st["cells"][Vector2i(3, 1)]))
	check("hexa: y sigue en cadena con lo destapado", (st["cells"][Vector2i(2, 1)] as Array) == [1, 1, 1, 1, 1] and (st["cells"][Vector2i(1, 1)] as Array).is_empty(), str(st["cells"][Vector2i(2, 1)]))
	check("hexa: al gastar las 3 pilas llegan otras 3", st["offer"][0] != null and st["offer"][1] != null)
	## Limpiar: 10 iguales arriba desaparecen y cuentan para la meta.
	st = M.new_state(lv)
	st["cells"][Vector2i(1, 3)] = [2, 0, 0, 0, 0, 0, 0, 0]
	st["offer"] = [[1, 0, 0, 0], null, null]
	M.place(st, 0, Vector2i(2, 3))
	check("hexa: 10 del mismo color arriba se limpian", int(st["cleared"]) == 10 and (st["cells"][Vector2i(2, 3)] as Array) == [1] and (st["cells"][Vector2i(1, 3)] as Array) == [2], str(st["cells"][Vector2i(2, 3)]) + str(st["cells"][Vector2i(1, 3)]))
	## Tablero lleno: con martillo, atascado; el martillo rompe una pila; sin el, se pierde.
	var sf: Dictionary = M.new_state(lv)
	var k: int = 0
	for c: Vector2i in sf["cells"]:
		sf["cells"][c] = [k % 3, (k + 1) % 3] if k > 0 else []
		k += 1
	var last: Vector2i = M.empty_cells(sf)[0]
	sf["offer"] = [[2, 0], null, null]
	for n: Vector2i in M.nbrs(sf, last):
		sf["cells"][n] = [1, 1]
	M.place(sf, 0, last)
	check("hexa: tablero lleno con martillo: atascado pero no perdido", bool(sf["stuck"]) and not bool(sf["over"]), str(sf["stuck"]))
	check("hexa: el martillo rompe una pila y deja hueco", M.hammer(sf, last) and M.empty_cells(sf).size() == 1 and not bool(sf["stuck"]))
	sf["offer"] = [[2, 0], null, null]
	M.place(sf, 0, M.empty_cells(sf)[0])
	check("hexa: lleno y sin martillo se pierde", bool(sf["over"]) and not bool(sf["won"]))
	var r: Dictionary = M.bot_play(lv)
	check("hexa: el bot llega a la meta", bool(r["won"]), str(r))
	check("hexa: el analizador lo acepta", bool(M.analyze(lv)["completable"]))
	check("hexa: un tablero diminuto se rechaza", not bool(M.analyze({"map": ["...", "..."]})["completable"]))
	## La escena.
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "hexa"
	Kit.config["levels"] = [lv]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/hexa.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	check("hexa: tablero, meta y boton de martillo", g.find_child("World", true, false) != null and g.find_child("BtnHammer", true, false) != null and g.find_child("GoalBar", true, false) != null)
	var gst: Dictionary = g.get("st")
	g.call("tap", g.call("offer_pos", 0))
	var target: Vector2i = M.empty_cells(gst)[0]
	g.call("tap", g.call("cell_pos", target))
	check("hexa: tocar una pila y luego una casilla la pone", not (gst["cells"][target] as Array).is_empty() or int(gst["moves"]) == 1)
	var Bot: GDScript = load("res://qa/hexa_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 8000)
	check("hexa: el bot gana jugando", won, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0

## Tornillos: placas por capas, tornillos tapados, colores de tres en tres, cajas, espera,
## placas que caen, hueco extra, bot, analizador y escena.
const SC_MAP: Array = ["0,1,7,2:0,1;6,1;3,2", "1,0,2,5:1,0;2,4", "4,0,2,5:5,0;4,4", "2,3,3,2:2,3;4,3;3,4", "#7"]

func _test_screw() -> void:
	print("- Tornillos")
	var M: GDScript = load("res://kit/screw/screw_map.gd")
	var lv: Dictionary = {"name": "S", "map": SC_MAP, "kinds": 3, "boxes": 2, "hold": 4, "extra": 1}
	var info: Dictionary = M.parse(lv)
	check("tornillos: placas y tornillos (multiplo de 3)", (info["plates"] as Array).size() == 4 and (info["screws"] as Array).size() == 9, "%d %d" % [(info["plates"] as Array).size(), (info["screws"] as Array).size()])
	check("tornillos: lineas mal escritas o tornillos fuera de su placa no cuentan", (M.parse({"map": ["0,0,2,2:5,5", "x", "0,0,3,1:0,0;1,0;2,0"]})["plates"] as Array).size() == 1)
	var st: Dictionary = M.new_state(lv)
	var by: Dictionary = {}
	for s: Dictionary in st["screws"]:
		by[int(s["color"])] = int(by.get(int(s["color"]), 0)) + 1
	var trios: bool = true
	for k: int in by:
		if k < 0 or int(by[k]) % 3 != 0:
			trios = false
	check("tornillos: cada color sale de tres en tres y hay una caja por trio", trios and (st["queue"] as Array).size() + (st["boxes"] as Array).size() == 3, str(by))
	var covered: int = -1
	for s2: Dictionary in st["screws"]:
		if s2["cell"] == Vector2i(2, 4):
			covered = int(s2["id"])
	check("tornillos: el tapado por una placa de encima no se puede quitar", covered >= 0 and not M.is_free(st, covered) and not M.pick(st, covered))
	## Colores a mano: caja, espera, placa que cae y caja que se llena y se lleva lo que espera.
	st = M.new_state(lv)
	var ids: Array = []
	for s3: Dictionary in st["screws"]:
		ids.append(int(s3["id"]))
		s3["color"] = 0 if int(s3["plate"]) == 3 else 1
	st["boxes"] = [{"color": 1, "ids": []}, {"color": 2, "ids": []}]
	st["queue"] = [0, 1]
	var top: Array = []
	for s4: Dictionary in st["screws"]:
		if int(s4["plate"]) == 3:
			top.append(int(s4["id"]))
	M.pick(st, int(top[0]))
	check("tornillos: sin caja de su color va a la espera", (st["hold"] as Array).size() == 1)
	M.pick(st, int(top[1]))
	check("tornillos: la placa sin tornillos cae y destapa los de abajo", bool(st["plates"][3]["gone"]) and M.is_free(st, covered))
	var reds: Array = []
	for s5: Dictionary in st["screws"]:
		if int(s5["color"]) == 1 and M.is_free(st, int(s5["id"])):
			reds.append(int(s5["id"]))
	for r: int in 3:
		M.pick(st, int(reds[r]))
	check("tornillos: caja llena se va, llega la siguiente y se lleva los que esperaban", int(st["boxes"][0]["color"]) == 0 and (st["boxes"][0]["ids"] as Array).size() == 2 and (st["hold"] as Array).is_empty() and int(st["cleared"]) == 3, str(st["boxes"]))
	## Espera llena sin jugada: con hueco extra se sigue; sin el, se pierde.
	var sf: Dictionary = M.new_state(lv)
	for s6: Dictionary in sf["screws"]:
		s6["color"] = 2
	sf["boxes"] = [{"color": 0, "ids": []}]
	sf["queue"] = []
	sf["hold_max"] = 3
	for g2: int in 3:
		M.pick(sf, int((M.free_screws(sf)[0] as Dictionary)["id"]))
	check("tornillos: espera llena con hueco extra: atascado pero no perdido", bool(sf["stuck"]) and not bool(sf["over"]))
	check("tornillos: el hueco extra da un hueco mas", M.use_extra(sf) and int(sf["hold_max"]) == 4 and not bool(sf["stuck"]))
	M.pick(sf, int((M.free_screws(sf)[0] as Dictionary)["id"]))
	check("tornillos: sin hueco ni ayuda se pierde", bool(sf["over"]) and not bool(sf["won"]))
	var wins: int = 0
	for sd: int in 8:
		var lvs: Dictionary = lv.duplicate()
		lvs["map"] = SC_MAP.slice(0, 4) + ["#%d" % (30 + sd)]
		if bool(M.bot_play(lvs)["won"]):
			wins += 1
	check("tornillos: el bot gana casi siempre", wins >= 7, "%d/8" % wins)
	check("tornillos: el analizador lo acepta", bool(M.analyze(lv)["completable"]), str(M.analyze(lv)))
	check("tornillos: un tablero de 3 tornillos se rechaza", not bool(M.analyze({"map": ["0,0,3,1:0,0;1,0;2,0"]})["completable"]))
	## La escena.
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "screw"
	Kit.config["levels"] = [lv]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/screw.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	check("tornillos: placas, cajas, espera y boton de hueco extra", g.find_child("World", true, false) != null and g.find_child("BtnExtra", true, false) != null)
	var gst: Dictionary = g.get("st")
	var free0: Dictionary = M.free_screws(gst)[0]
	g.call("tap", g.call("screw_pos", int(free0["id"])))
	check("tornillos: tocar un tornillo libre lo quita", bool(free0["gone"]))
	var Bot: GDScript = load("res://qa/screw_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 6000)
	check("tornillos: el bot gana jugando", won, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0

## Supervivencia: recoger, beber, comer, fabricar, hoguera, lobos de noche, metas, analizador y bot.
const SV_MAP: Array = ["~~~~~~~~~~~~~~~~", "~,,,,,,,,,,,,,,~", "~,.T..R...T...,~", "~,..G...B..G..,~", "~,.T..WW...T..,~",
	"~,..R.WW..B...,~", "~,......P.....,~", "~,.T..G...R...,~", "~,..B....T....,~", "~,.G....R...T.,~", "~,..T.........,~",
	"~,..........GD,~", "~,,,,,,,,,,,,,,~", "~~~~~~~~~~~~~~~~", "#5"]

func _test_survival() -> void:
	print("- Supervivencia")
	var M: GDScript = load("res://kit/survival/survival_map.gd")
	var lv: Dictionary = {"name": "S", "map": SV_MAP, "goal": "noches", "nights": 1, "day": 30, "night": 20, "wolves": 1, "hunger": 0.5, "thirst": 0.8}
	var st: Dictionary = M.new_state(lv)
	var me: Dictionary = st["me"]
	check("supervivencia: isla, salida, charca, guarida y recursos", st["start"] == Vector2i(8, 6) and (st["ponds"] as Array).size() == 4
		and (st["dens"] as Array).size() == 1 and (st["res"] as Dictionary).size() == 20 and M.map_issues(st).is_empty(), "%s %d %d %d %s" % [st["start"], (st["ponds"] as Array).size(), (st["dens"] as Array).size(), (st["res"] as Dictionary).size(), M.map_issues(st)])
	for k: int in 200:
		M.step(st, {}, 0.05)
	check("supervivencia: el hambre y la sed bajan solas", absf(float(me["food"]) - 95.0) < 0.2 and absf(float(me["water"]) - 92.0) < 0.2, "%f %f" % [me["food"], me["water"]])
	## Recoger: pegado al arbol (3,2), USAR una vez y sigue solo hasta agotarlo.
	st = M.new_state(lv)
	me = st["me"]
	me["p"] = M.center(Vector2i(4, 2))
	me["face"] = Vector2.LEFT
	M.step(st, {"use": true, "want": {"what": "gather", "cell": Vector2i(3, 2)}}, 0.05)
	for k2: int in 30:
		M.step(st, {}, 0.05)
	var w1: int = int(me["inv"]["wood"])
	for k3: int in 100:
		M.step(st, {}, 0.05)
	check("supervivencia: recoger sigue solo y el arbol se agota (queda suelo)", w1 == 1 and int(me["inv"]["wood"]) == 4 and M.tile(st, Vector2i(3, 2)) == "." and M.walkable(st, Vector2i(3, 2)), "%d %d" % [w1, int(me["inv"]["wood"])])
	me["inv"]["stone"] = 2
	me["inv"]["fiber"] = 2
	check("supervivencia: con 3 madera, 2 piedra y 2 fibra se fabrica el hacha (una vez)", M.craft(st, "hacha") and not M.can_craft(st, "hacha") and int(me["inv"]["wood"]) == 1)
	me["p"] = M.center(Vector2i(10, 3))
	M.step(st, {"use": true, "want": {"what": "gather", "cell": Vector2i(10, 2)}}, 0.05)
	for k4: int in 12:
		M.step(st, {}, 0.05)
	check("supervivencia: con hacha la madera sale el doble de rapido", int(me["inv"]["wood"]) == 2, str(me["inv"]["wood"]))
	## Beber y comer.
	me["water"] = 30.0
	me["p"] = M.center(Vector2i(5, 4))
	M.step(st, {"use": true}, 0.05)
	check("supervivencia: junto a la charca, USAR bebe (primero que recoger)", float(me["water"]) > 99.0)
	me["inv"]["berry"] = 1
	me["food"] = 50.0
	M.step(st, {"eat": true}, 0.05)
	check("supervivencia: una baya da de comer", absf(float(me["food"]) - 72.0) < 0.2 and int(me["inv"]["berry"]) == 0)
	## Hoguera: se enciende, se gasta y la lena la alarga.
	me["inv"]["wood"] = 6
	me["inv"]["stone"] = 3
	me["p"] = M.center(Vector2i(8, 6))
	M.step(st, {"craft": "hoguera"}, 0.05)
	var f0: float = float(st["fire"]["fuel"])
	M.step(st, {"use": true}, 0.05)
	check("supervivencia: hoguera encendida y con lena dura mas", M.fire_on(st) and float(st["fire"]["fuel"]) > f0 + 30.0 and int(me["inv"]["wood"]) == 1)
	## Noche: salen lobos de la guarida, no entran en la luz y amanece.
	st = M.new_state(lv)
	me = st["me"]
	me["inv"] = {"wood": 4, "stone": 3, "fiber": 0, "berry": 0}
	me["p"] = M.center(Vector2i(11, 9))
	M.step(st, {"craft": "hoguera"}, 0.05)
	st["t"] = 29.97
	M.step(st, {}, 0.05)
	check("supervivencia: al caer la noche salen lobos de la guarida", bool(st["is_night"]) and (st["wolves_list"] as Array).size() == 1)
	var closest: float = INF
	var hp0: float = float(me["hp"])
	for k5: int in 300:
		M.step(st, {}, 0.05)
		for wf: Dictionary in st["wolves_list"]:
			closest = minf(closest, (wf["p"] as Vector2).distance_to(st["fire"]["p"]))
	check("supervivencia: a la luz de la hoguera los lobos no se acercan", closest >= M.FIRE_R - 0.2 and float(me["hp"]) >= hp0, "%f" % closest)
	for k6: int in 120:
		M.step(st, {}, 0.05)
	check("supervivencia: amanece, los lobos se van y una noche superada gana el nivel", bool(st["over"]) and bool(st["won"]) and str(st["cause"]) == "noches")
	## Sin hoguera: los lobos muerden; con lanza caen en dos golpes.
	st = M.new_state(lv)
	me = st["me"]
	me["p"] = M.center(Vector2i(12, 10))
	st["t"] = 29.95
	M.step(st, {}, 0.05)
	for k7: int in 80:
		M.step(st, {}, 0.05)
	check("supervivencia: sin fuego, el lobo muerde", float(me["hp"]) < 100.0)
	me["tools"]["lanza"] = true
	var wolf: Dictionary = st["wolves_list"][0]
	wolf["p"] = (me["p"] as Vector2) + Vector2(0.8, 0.0)
	wolf["stun"] = 5.0
	M.step(st, {"use": true}, 0.05)
	me["hit_cd"] = 0.0
	wolf["p"] = (me["p"] as Vector2) + Vector2(0.8, 0.0)
	M.step(st, {"use": true}, 0.05)
	check("supervivencia: con lanza, el lobo cae en dos golpes", (st["wolves_list"] as Array).is_empty())
	## Sed: sin agua se pierde vida y se pierde la partida.
	st = M.new_state(lv)
	st["me"]["water"] = 0.0
	st["me"]["hp"] = 5.0
	for k8: int in 60:
		M.step(st, {}, 0.05)
	check("supervivencia: sin agua se pierde (causa: sed)", bool(st["over"]) and not bool(st["won"]) and str(st["cause"]) == "sed")
	## Balsa: si es la meta, fabricarla gana.
	var lvb: Dictionary = lv.duplicate()
	lvb["goal"] = "balsa"
	lvb["raft"] = [5, 3]
	st = M.new_state(lvb)
	st["me"]["inv"]["wood"] = 5
	st["me"]["inv"]["fiber"] = 3
	check("supervivencia: en las noches no hay balsa", not M.can_craft(M.new_state(lv), "balsa"))
	M.step(st, {"craft": "balsa"}, 0.05)
	check("supervivencia: construir la balsa es escapar (gana)", bool(st["won"]) and str(st["cause"]) == "balsa")
	## Analizador y bot.
	var r: Dictionary = M.bot_play(lv)
	check("supervivencia: el bot aguanta la noche", bool(r["won"]), str(r))
	var r2: Dictionary = M.bot_play(lvb)
	check("supervivencia: el bot construye la balsa", bool(r2["won"]) and str(r2["cause"]) == "balsa", str(r2))
	check("supervivencia: el analizador lo acepta", bool(M.analyze(lv)["completable"]), str(M.analyze(lv)))
	var dry: Dictionary = lv.duplicate()
	dry["map"] = (SV_MAP as Array).map(func(row: Variant) -> String: return str(row).replace("W", "."))
	check("supervivencia: sin agua dulce se rechaza", "survival_no_water" in M.analyze(dry)["issues"])
	var den: Dictionary = lv.duplicate()
	den["map"] = (SV_MAP as Array).map(func(row: Variant) -> String: return str(row).replace("GD", "G.").replace("~,......P.....,~", "~,......PD....,~"))
	check("supervivencia: una guarida junto a la salida se rechaza", "survival_den_near" in M.analyze(den)["issues"])
	## La escena.
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "survival"
	Kit.config["levels"] = [lv]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/survival.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	check("supervivencia: isla, jugador, hoguera por fabricar, USAR y mando", g.find_child("Ground", true, false) != null and g.find_child("Player", true, false) != null
		and g.find_child("Craft_hoguera", true, false) != null and g.find_child("BtnUse", true, false) != null and g.find_child("Stick", true, false) != null)
	var gst: Dictionary = g.get("st")
	gst["me"]["p"] = M.center(Vector2i(5, 4))
	gst["me"]["water"] = 40.0
	g.set("_use_pressed", true)
	await frames(2)
	check("supervivencia: el boton USAR bebe en la charca", float(gst["me"]["water"]) > 95.0)
	var Bot: GDScript = load("res://qa/survival_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 20000)
	check("supervivencia: el bot gana jugando", won, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	## Vista 3D: la misma partida dibujada en 3D (isla, objetos, hoguera con luz) y el bot gana igual.
	Kit.config["view"] = "3d"
	var g3: Node = (load("res://scenes/survival.tscn") as PackedScene).instantiate()
	add_child(g3)
	await frames(2)
	check("supervivencia 3D: isla, arboles, jugador y camara 3D (el 2D escondido)", g3.find_child("View3D", true, false) != null and g3.find_child("Island", true, false) != null
		and g3.find_child("Trunks", true, false) != null and g3.find_child("Player3D", true, false) != null and not (g3.find_child("Ground", true, false) as CanvasItem).visible)
	var won3: bool = await Bot.run(get_tree(), g3, 20000)
	var v3: Node = g3.find_child("View3D", true, false)
	check("supervivencia 3D: el bot gana jugando y la hoguera se ve", won3 and v3 != null and (v3.find_child("Fire3D", true, false) as Node3D).visible, str(g3.call("bot_state")))
	if g3.get("result_panel") != null:
		(g3.get("result_panel") as Node).queue_free()
	g3.queue_free()
	Kit.config.erase("view")
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0

## Plantilla de supervivencia: estilos (zombis, invierno), saqueo, mochila, herramientas que se
## gastan, construir, cocinar, enfermar, frio y guardar la partida.
func _test_survival_template() -> void:
	print("- Supervivencia: plantilla")
	var M: GDScript = load("res://kit/survival/survival_map.gd")
	var base: Dictionary = {"name": "S", "map": SV_MAP, "goal": "noches", "nights": 1, "day": 30, "night": 20, "wolves": 1, "hunger": 0.5, "thirst": 0.8}
	var st0: Dictionary = M.new_state(base)
	check("plantilla: sin estilo, las recetas de siempre", M.recipe_ids(st0) == ["hacha", "lanza", "hoguera"] and M.fire_recipe(st0) == "hoguera"
		and (st0["wolves_list"] as Array).is_empty(), str(M.recipe_ids(st0)))
	var zmap: Array = (SV_MAP as Array).map(func(row: Variant) -> String: return str(row).replace("GD", "GZ").replace("~,..B....T....,~", "~,..B....T..H.,~").replace("~,..T.........,~", "~,..T.....A...,~").replace("~,.G....R...T.,~", "~,.G.C..R...T.,~"))
	var lz: Dictionary = base.duplicate()
	lz["map"] = zmap
	lz["survival"] = {"preset": "zombis"}
	var st: Dictionary = M.new_state(lz)
	var me: Dictionary = st["me"]
	var kinds: Array = (st["wolves_list"] as Array).map(func(w: Dictionary) -> String: return str(w["kind"]))
	check("plantilla zombis: recetas del estilo (machete en vez de lanza, muro, venda, radio)", "machete" in M.recipe_ids(st) and not "lanza" in M.recipe_ids(st)
		and M.win_recipe(st) == "radio" and int(st["cat"]["bag"]) == 30, str(M.recipe_ids(st)))
	check("plantilla zombis: al empezar ya hay un zombi y un ciervo pastando", kinds.has("zombie") and kinds.has("deer"), str(kinds))
	## Saquear la casa (12,8): tres veces y se queda (vacia, no se pisa). El zombi, quieto.
	for zw: Dictionary in st["wolves_list"]:
		if str(zw["kind"]) == "zombie":
			zw["stun"] = 1000.0
	me["p"] = M.center(Vector2i(11, 8))
	M.step(st, {"use": true, "want": {"what": "gather", "cell": Vector2i(12, 8)}}, 0.05)
	for k: int in 100:
		M.step(st, {}, 0.05)
	check("plantilla zombis: la casa se saquea (lata, tela y chatarra) y queda en pie", int(me["inv"]["scrap"]) == 3 and int(me["inv"]["can"]) == 3
		and M.tile(st, Vector2i(12, 8)) == "H" and not (st["res"] as Dictionary).has(Vector2i(12, 8)) and not M.walkable(st, Vector2i(12, 8)), str(me["inv"]))
	## Comer: la lata alimenta y quita sed.
	me["food"] = 40.0
	me["water"] = 40.0
	check("plantilla zombis: la lata da comida y algo de agua", M.eat(st, "can") and absf(float(me["food"]) - 70.0) < 0.5 and float(me["water"]) > 49.0)
	## Machete con usos: se gasta y se rompe.
	me["inv"]["wood"] = 2
	me["inv"]["fiber"] = 1
	check("plantilla zombis: machete fabricado con 40 usos", M.craft(st, "machete") and int(me["tools"]["machete"]) == 40)
	me["tools"]["machete"] = 1
	var z: Dictionary = {}
	for w: Dictionary in st["wolves_list"]:
		if str(w["kind"]) == "zombie":
			z = w
	z["p"] = (me["p"] as Vector2) + Vector2(0.8, 0.0)
	z["stun"] = 3.0
	M.step(st, {"use": true}, 0.05)
	var broke: bool = not (me["tools"] as Dictionary).has("machete")
	check("plantilla zombis: el zombi cae de un machetazo (y suelta tela) y el machete se rompe al gastarse", broke and not (st["wolves_list"] as Array).has(z)
		and int(me["inv"]["cloth"]) == 4, "%s %s" % [me["tools"], me["inv"]])
	## Mochila: no cabe mas de 30; tirar hace sitio.
	me["inv"]["wood"] = 30 - M.carried(st) + int(me["inv"]["wood"])
	check("plantilla zombis: mochila llena", M.bag_full(st) and M.give(st, "stone", 2) == 0)
	M.step(st, {"drop": "wood", "drop_n": 3}, 0.05)
	check("plantilla zombis: tirar hace sitio", not M.bag_full(st) and M.give(st, "stone", 5) == 3, str(M.carried(st)))
	## Construir un muro delante: no lo cruza nadie.
	me["face"] = Vector2.LEFT
	var wc: Vector2i = M.build_cell(st)
	check("plantilla zombis: el muro se levanta en la casilla de delante", wc == Vector2i(10, 8) and M.craft(st, "muro") and not M.walkable(st, wc)
		and not M.creature_walkable(st, wc) and str(st["built"][wc]) == "muro", str(wc))
	## Ciervo: huye, se caza y da carne cruda; cruda enferma; en la hoguera se asa.
	var deer: Dictionary = {}
	for w2: Dictionary in st["wolves_list"]:
		if str(w2["kind"]) == "deer":
			deer = w2
	var d0: Vector2 = deer["p"]
	me["p"] = d0 + Vector2(0.0, 1.0)
	for k2: int in 10:
		M.step(st, {}, 0.05)
	check("plantilla: el ciervo huye si te acercas", (deer["p"] as Vector2).distance_to(me["p"]) > 1.0 + 0.1, "%s %s" % [deer["p"], me["p"]])
	deer["p"] = (me["p"] as Vector2) + Vector2(0.8, 0.0)
	deer["stun"] = 3.0
	for k3: int in 3:
		me["hit_cd"] = 0.0
		deer["p"] = (me["p"] as Vector2) + Vector2(0.8, 0.0)
		M.step(st, {"use": true}, 0.05)
	check("plantilla: cazar el ciervo da carne", int(me["inv"]["meat"]) == 2 and not (st["wolves_list"] as Array).has(deer), str(me["inv"]))
	me["food"] = 30.0
	M.eat(st, "meat")
	check("plantilla: la carne cruda enferma", float(me["sick"]) > 0.0)
	me["inv"]["wood"] = 4
	me["inv"]["stone"] = 3
	me["p"] = M.center(Vector2i(8, 6))
	M.step(st, {"craft": "hoguera"}, 0.05)
	M.step(st, {"use": true}, 0.05)
	M.step(st, {"use": true}, 0.05)
	check("plantilla: en la hoguera la carne se asa", int(me["inv"]["cooked"]) == 1 and int(me["inv"]["meat"]) == 0, str(me["inv"]))
	me["inv"]["cloth"] = 2
	M.craft(st, "venda")
	var hp0: float = float(me["hp"])
	M.eat(st, "venda")
	check("plantilla: la venda cura y quita lo enfermo", float(me["sick"]) == 0.0 and float(me["hp"]) > hp0, "%f %f" % [me["hp"], hp0])
	## Los zombis no temen al fuego.
	var lz2: Dictionary = lz.duplicate()
	var st2: Dictionary = M.new_state(lz2)
	st2["me"]["p"] = M.center(Vector2i(8, 6))
	st2["me"]["inv"]["wood"] = 4
	st2["me"]["inv"]["stone"] = 3
	M.step(st2, {"craft": "hoguera"}, 0.05)
	var closest: float = INF
	for k4: int in 400:
		M.step(st2, {}, 0.05)
		for w3: Dictionary in st2["wolves_list"]:
			if str(w3["kind"]) == "zombie":
				closest = minf(closest, (w3["p"] as Vector2).distance_to(st2["fire"]["p"]))
	check("plantilla zombis: el zombi entra en la luz de la hoguera", closest < M.FIRE_R - 1.0, str(closest))
	## Meta por receta: arreglar la radio gana.
	var lr: Dictionary = lz.duplicate()
	lr["goal"] = "receta"
	var st3: Dictionary = M.new_state(lr)
	st3["me"]["inv"]["scrap"] = 5
	st3["me"]["inv"]["cloth"] = 2
	st3["me"]["inv"]["wood"] = 3
	M.step(st3, {"craft": "radio"}, 0.05)
	check("plantilla zombis: arreglar la radio es escapar (gana)", bool(st3["won"]) and str(st3["cause"]) == "radio")
	## Invierno: de noche hace frio lejos del fuego; el abrigo lo reduce.
	var li: Dictionary = base.duplicate()
	li["survival"] = {"preset": "invierno"}
	li["wolves"] = 0
	var st4: Dictionary = M.new_state(li)
	st4["t"] = 30.5
	for k5: int in 100:
		M.step(st4, {}, 0.05)
	var cold1: float = 100.0 - float(st4["me"]["warm"])
	var st5: Dictionary = M.new_state(li)
	st5["me"]["tools"]["abrigo"] = true
	st5["t"] = 30.5
	for k6: int in 100:
		M.step(st5, {}, 0.05)
	var cold2: float = 100.0 - float(st5["me"]["warm"])
	check("plantilla invierno: de noche el frio baja el calor y el abrigo lo reduce", cold1 > 8.0 and cold2 < cold1 * 0.5, "%f %f" % [cold1, cold2])
	st4["me"]["warm"] = 0.0
	st4["me"]["hp"] = 4.0
	for k7: int in 60:
		M.step(st4, {}, 0.05)
	check("plantilla invierno: congelarse mata (causa: frio)", bool(st4["over"]) and str(st4["cause"]) == "frio", str(st4["cause"]))
	## Guardar la partida: foto en JSON y vuelta, igual que estaba.
	var st6: Dictionary = M.new_state(lz)
	for k8: int in 200:
		M.step(st6, M.bot_control(st6, 0.05), 0.05)
	var snap: Dictionary = JSON.parse_string(JSON.stringify(M.snapshot(st6)))
	var st7: Dictionary = M.restore(lz, snap)
	check("plantilla: la partida guardada vuelve igual (sitio, mochila, recursos, bichos)", not st7.is_empty() and (st7["me"]["p"] as Vector2).distance_to(st6["me"]["p"]) < 0.02
		and st7["me"]["inv"] == st6["me"]["inv"] and (st7["res"] as Dictionary).size() == (st6["res"] as Dictionary).size()
		and (st7["wolves_list"] as Array).size() == (st6["wolves_list"] as Array).size() and absf(float(st7["t"]) - float(st6["t"])) < 0.01)
	## El bot sabe jugar los estilos.
	var rz: Dictionary = M.bot_play(lz)
	check("plantilla zombis: el bot aguanta la noche", bool(rz["won"]), str(rz))
	var ri: Dictionary = M.bot_play(li)
	check("plantilla invierno: el bot aguanta la noche (sin congelarse)", bool(ri["won"]), str(ri))
	## La escena con el estilo en game.json: botones de sus recetas (en fila deslizable).
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "survival"
	Kit.config["survival"] = {"preset": "zombis"}
	Kit.config["levels"] = [lr]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/survival.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(3)
	check("plantilla zombis: la escena trae machete, muro, venda y radio (en fila deslizable)", g.find_child("Craft_machete", true, false) != null
		and g.find_child("Craft_muro", true, false) != null and g.find_child("Craft_radio", true, false) != null and g.find_child("CraftScroll", true, false) != null
		and g.find_child("Craft_lanza", true, false) == null)
	var Bot: GDScript = load("res://qa/survival_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 30000)
	check("plantilla zombis: el bot arregla la radio jugando", won, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## RPG de equipo (plantilla por datos): turnos por velocidad, elementos, estados, esperas,
## provocar, criaturas uno contra uno, analizador y la escena con el boton AUTO.
func _test_turns_party() -> void:
	print("- RPG de equipo")
	var eq: Dictionary = TurnsParty.catalog({"rpg": {"preset": "equipo"}})
	check("rpg equipo: el estilo equipo trae cuatro heroes y enemigos nuevos", (eq["party"] as Array).size() == 4 and (eq["enemies"] as Dictionary).has("L"))
	var lv: Dictionary = {"map": ["WW", "B"], "rpg": {"preset": "equipo"}, "mult": 1.0, "potions": 2, "hero_level": 1}
	var st: Dictionary = TurnsParty.new_state(lv)
	TurnsParty.next_wave(st)
	var order: Array = TurnsParty.preview_order(st, 3)
	check("rpg equipo: el mas rapido (arquero) actua primero", str(order[0]["id"]) == "arquero", str(order.map(func(u: Dictionary) -> String: return str(u["id"]))))
	check("rpg equipo: fuego le gana a planta y pierde contra agua", TurnsParty.elem_mult("fire", "nature") == 1.3 and TurnsParty.elem_mult("fire", "water") == 0.8)
	var war: Dictionary = st["heroes"][0]
	var gob: Dictionary = st["enemies"][0]
	TurnsParty.use_skill(st, war, "provocar", {}, null)
	var tg: Array = TurnsParty.targets_for(st, gob, "mordisco", st["heroes"][1])
	check("rpg equipo: con provocar, los golpes van al guerrero", tg.size() == 1 and tg[0] == war)
	check("rpg equipo: provocar queda en espera 3 turnos", int(war["cd"]["provocar"]) == 4)
	TurnsParty.end_turn(st, war)
	check("rpg equipo: la espera baja al acabar su turno", int(war["cd"]["provocar"]) == 3 and (war["status"] as Dictionary).has("taunt"))
	var hp0: float = float(gob["hp"])
	gob["status"]["poison"] = {"turns": 2, "value": 0.0}
	gob["status"]["stun"] = {"turns": 1, "value": 0.0}
	var s1: Dictionary = TurnsParty.start_turn(st, gob)
	check("rpg equipo: el veneno quita un 6 % y aturdido pierde el turno", bool(s1["skip"]) and absf(hp0 - float(gob["hp"]) - float(gob["max_hp"]) * 0.06) < 0.01)
	for h: Dictionary in st["heroes"]:
		h["hp"] = float(h["max_hp"]) * 0.5
	TurnsParty.use_skill(st, st["heroes"][2], "curar", {}, null)
	check("rpg equipo: curar sana a todo el equipo un 25 %", (st["heroes"] as Array).all(func(h: Dictionary) -> bool: return absf(float(h["hp"]) - float(h["max_hp"]) * 0.75) < 0.01))
	var a: Array = TurnsParty.think(st, st["heroes"][2])
	check("rpg equipo: la cabeza no repite la cura en espera", str(a[1]) != "curar", str(a))
	var lc: Dictionary = {"map": ["FS"], "rpg": {"preset": "criaturas"}, "mult": 1.0, "hero_level": 1}
	var sc: Dictionary = TurnsParty.new_state(lc)
	TurnsParty.next_wave(sc)
	check("rpg criaturas: uno contra uno (pelea el primero de cada lado)", TurnsParty.fighters(sc, sc["heroes"]).size() == 1 and TurnsParty.fighters(sc, sc["enemies"]).size() == 1)
	sc["enemies"][0]["hp"] = 0.0
	sc["enemies"][0]["alive"] = false
	check("rpg criaturas: al caer, sale el siguiente", TurnsParty.fighters(sc, sc["enemies"])[0] == sc["enemies"][1])
	var r: Dictionary = TurnsParty.simulate({"map": ["W", "WW", "WF"], "rpg": {}, "mult": 1.0, "potions": 2, "hero_level": 1})
	check("rpg equipo: la simulacion de siempre da lo mismo que la fabrica (20 turnos, 89,7 %)", bool(r["won"]) and int(r["turns"]) == 20 and absf(float(r["hp_left"]) - 0.8970484) < 0.0001, str(r))
	var M: GDScript = load("res://kit/turns/turns_map.gd")
	check("rpg equipo: el analizador acepta un nivel justo", bool(M.analyze(lv)["completable"]), str(M.analyze(lv)))
	var hard: Dictionary = lv.duplicate()
	hard["mult"] = 3.0
	check("rpg equipo: y rechaza uno imposible", "turns_too_hard" in M.analyze(hard)["issues"])
	var bad: Dictionary = lv.duplicate()
	bad["map"] = ["WQ"]
	check("rpg equipo: un enemigo que no existe se rechaza", "turns_bad_enemy" in M.analyze(bad)["issues"])
	## La escena: equipo, barra de turnos, habilidades y AUTO.
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "turns"
	Kit.config["rpg"] = {"preset": "equipo"}
	Kit.config["levels"] = [{"map": ["WW", "WF"], "mult": 1.0, "potions": 2, "hero_level": 1}]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/turns.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(3)
	check("rpg equipo: escena con 4 heroes, barra de turnos, habilidades y AUTO", bool(g.get("party_mode")) and g.find_child("Hero4", true, false) != null
		and g.find_child("Order", true, false) != null and g.find_child("Btn_skill_0", true, false) != null and g.find_child("Btn_auto", true, false) != null)
	g.set("fast", true)
	for k: int in 600:
		if bool(g.call("waiting_player")):
			break
		await frames(1)
	var gst: Dictionary = g.get("state")
	var before: float = 0.0
	for e: Dictionary in gst["enemies"]:
		before += float(e["hp"])
	check("rpg equipo: te toca con un heroe y su habilidad pega", bool(g.call("act_skill", 0)))
	await frames(40)
	var after: float = 0.0
	for e2: Dictionary in gst["enemies"]:
		after += float(e2["hp"])
	check("rpg equipo: el enemigo pierde vida", after < before, "%f %f" % [before, after])
	check("rpg equipo: los nombres de serie salen traducidos y los inventados tal cual", str(g.call("_skill_name", "golpe")) == Kit.text("rpg_golpe", "Golpe")
		and str(g.call("_unit_name", {"side": "enemy", "id": "W"})) == "goblin")
	var Bot: GDScript = load("res://qa/turns_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 20000)
	check("rpg equipo: el bot (AUTO) gana jugando", won, str(g.call("bot_state")) if is_instance_valid(g) else "sin escena")
	if is_instance_valid(g):
		if g.get("result_panel") != null:
			(g.get("result_panel") as Node).queue_free()
		g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Plantilla de hordas: estilos (survivor, vampiros), armas nuevas (rayo en cadena, bombas, onda,
## latigo), evoluciones y armas inventadas por el juego.
func _test_horde_template() -> void:
	print("- Hordas: plantilla")
	var G: GDScript = load("res://kit/horde/horde_game.gd")
	var c0: Dictionary = G.catalog({})
	check("plantilla hordas: sin estilo, las armas de siempre", str(c0["start"]) == "rayo" and (c0["weapons"] as Dictionary).size() == 4)
	var cs: Dictionary = G.catalog({"horde": {"preset": "survivor"}})
	check("plantilla hordas: survivor trae kunai, rayos, drones y evoluciones", str(cs["start"]) == "kunai" and (cs["weapons"] as Dictionary).has("relampago")
		and not (cs["weapons"] as Dictionary).has("rayo") and (cs["evolutions"] as Array).size() == 3)
	## Evolucion: kunai al maximo + prisa = tormenta de kunais (se ofrece la primera).
	var cfg: Dictionary = horde_config(40.0, false)
	cfg["horde"] = {"preset": "survivor"}
	var game: Node = await start_game(cfg, 0)
	game.set("auto_pick", true)
	game.set("owned", {"kunai": 5, "prisa": 1})
	game.call("_level_up")
	await frames(2)
	var own: Dictionary = game.get("owned")
	check("plantilla hordas: la evolucion sale y cambia el arma", own.has("tormenta_kunai") and not own.has("kunai"), str(own))
	## Cada forma de atacar hace dano.
	for pat: Array in [["relampago", "chain"], ["drones", "bomb"], ["onda", "nova"], ["guardian", "orbit"]]:
		game.set("owned", {str(pat[0]): 3})
		var k0: int = int(game.get("kills"))
		for e: Variant in game.get("enemies"):
			(e as HordeEnemy).queue_free()
		(game.get("enemies") as Array).clear()
		for j: int in 6:
			var p: Vector2 = (game.get("player") as Node2D).position + Vector2.from_angle(float(j)) * 140.0
			var en: HordeEnemy = game.call("_spawn_one", "walker", p)
			en.hp = 1.0
		await frames(150)
		check("plantilla hordas: %s (%s) mata enemigos" % [pat[0], pat[1]], int(game.get("kills")) > k0, "%d" % (int(game.get("kills")) - k0))
	await stop_game(game)
	## Arma inventada por el juego (un latigo de algas) y el bot jugando cada estilo.
	for st_name: Variant in ["survivor", "vampiros", {"start": "alga", "weapons": {"alga": {"name": "Latigo de algas", "desc": "Azota a los lados", "pattern": "whip",
			"cd": [1.2, 1.1, 1.0, 0.9, 0.8], "count": [1, 2, 2, 2, 2], "dmg": [3.0, 3.5, 4.0, 4.5, 5.0], "radius": 160, "color": "#26a69a"}}}]:
		var cf: Dictionary = horde_config(40.0, true)
		cf["horde"] = st_name if st_name is Dictionary else {"preset": st_name}
		var g2: Node = await start_game(cf, 0)
		var done: bool = await QaBot.run(get_tree(), g2, 60 * 60)
		var bst: Dictionary = g2.call("bot_state")
		var label: String = str(st_name) if st_name is String else "inventada"
		check("plantilla hordas: el bot gana con el estilo %s" % label, done and not bool(bst["boss_alive"]), "muertes=%d nivel=%d %s" % [int(bst["deaths"]), int(bst["level"]), str(bst["upgrades"])])
		if label == "inventada":
			check("plantilla hordas: el nombre inventado sale tal cual", str(g2.call("item_name", "alga")) == "Latigo de algas")
		await stop_game(g2)


## Shooter de zombis por datos: armas inventadas, que da cada letra del mapa y zombis cambiados.
func _test_zombie_template() -> void:
	print("- Zombis 3D: plantilla")
	var M: GDScript = load("res://kit/zombie/zombie_map.gd")
	var arena: Array = ["#########", "#Z.....Z#", "#.......#", "#..c....#", "#...P...#", "#.....S.#", "#.+...R.#", "#Z.....Z#", "#########", "#4"]
	var fps: Dictionary = {"weapons": {"ballesta": {"name": "Ballesta", "dmg": 60.0, "rate": 0.6, "mag": 5, "reload": 1.4, "spread": 0.01, "pellets": 1, "range": 18.0, "look": "rifle"},
		"trabuco": {"name": "Trabuco", "dmg": 20.0, "rate": 0.9, "mag": 4, "reload": 2.0, "spread": 0.14, "pellets": 8, "range": 6.0, "look": "shotgun"}},
		"slots": {"start": "ballesta", "S": "trabuco"}, "kinds": {"walker": {"hp": 90.0}}}
	var lv: Dictionary = {"name": "Z", "map": arena, "waves": 2, "count": 3, "grow": 1, "speed": 0.3, "hp": 100, "types": [9, 9], "fps": fps}
	var st: Dictionary = M.new_state(lv)
	check("zombis plantilla: empiezas con el arma inventada y su cargador", str(st["me"]["weapon"]) == "ballesta" and int(st["me"]["ammo"]) == 5)
	var items: Array = (st["pickups"] as Array).map(func(p: Dictionary) -> String: return str(p["item"]))
	check("zombis plantilla: la S da el trabuco y la R sigue dando el fusil", items.has("trabuco") and items.has("fusil"), str(items))
	check("zombis plantilla: los zombis cambiados (90 de vida) y los de serie igual", float(st["kinds"]["walker"]["hp"]) == 90.0 and float(st["kinds"]["brute"]["hp"]) == 260.0)
	check("zombis plantilla: sin datos, todo como siempre", str(M.new_state({"map": arena})["me"]["weapon"]) == "pistola")
	var r: Dictionary = M.analyze(lv)
	check("zombis plantilla: el analizador juega con las armas inventadas y lo acepta", bool(r["completable"]), str(r))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "zombie"
	Kit.config["fps"] = fps
	Kit.config["levels"] = [{"name": "Z", "map": arena, "waves": 1, "count": 2, "grow": 0, "speed": 0.3, "hp": 100, "types": [9, 9]}]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/zombie.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(3)
	check("zombis plantilla: la escena lleva la ballesta en la mano y su nombre", str((g.get("st") as Dictionary)["me"]["weapon"]) == "ballesta"
		and str(g.call("_wname", "ballesta")) == "Ballesta" and (g.get("_gun_models") as Dictionary).has("trabuco"))
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Objetos de los karts por datos: estilo fiesta (estrella y cascara triple) y un objeto inventado.
func _test_kart_items() -> void:
	print("- Karts: objetos por datos")
	var M: GDScript = load("res://kit/kart/kart_map.gd")
	var pts: Array = []
	for k0: int in 12:
		var a0: float = TAU * float(k0) / 12.0
		pts.append("%.1f,%.1f" % [cos(a0) * 70.0, sin(a0) * 45.0])
	pts.append("#7")
	var base: Dictionary = {"map": pts, "laps": 2, "skill": 0.2, "need": 3, "rivals": 5, "width": 12}
	var st0: Dictionary = M.new_state(base)
	check("karts objetos: sin datos, los tres de siempre", (st0["items"] as Dictionary).size() == 3 and M.effect(st0, "platano") == "trap")
	var lf: Dictionary = base.duplicate()
	lf["kart"] = {"preset": "fiesta", "items": {"bomba_agua": {"name": "Globo de agua", "effect": "trap", "weights": [0.2, 0.1, 0.0]}, "turbo": null}}
	var st: Dictionary = M.new_state(lf)
	check("karts objetos: fiesta trae la estrella y la cascara triple; lo del juego quita y anade", (st["items"] as Dictionary).has("estrella")
		and (st["items"] as Dictionary).has("bomba_agua") and not (st["items"] as Dictionary).has("turbo"))
	var me: Dictionary = st["karts"][0]
	me["item"] = "estrella"
	M.use_item(st, me)
	check("karts objetos: la estrella dura y nada te para", float(me["star_t"]) > 3.0)
	M.hit(st, me, "cascara", "x")
	check("karts objetos: con la estrella la cascara no te trompea", float(me["stun"]) == 0.0)
	me["star_t"] = 0.0
	me["item"] = "supercascara"
	for k: int in 3:
		M.use_item(st, me)
	check("karts objetos: la cascara triple dispara tres veces", (st["shots"] as Array).size() == 3 and str(me["item"]) == "", str((st["shots"] as Array).size()))
	var seen: Dictionary = {}
	for k2: int in 400:
		seen[M.roll_item(st, st["karts"][1])] = true
	check("karts objetos: la ruleta reparte los objetos del catalogo", seen.has("bomba_agua") or seen.has("platano"), str(seen.keys()))
	var r: Dictionary = M.analyze(lf)
	check("karts objetos: el analizador lo acepta con objetos nuevos", bool(r["completable"]), str(r))

## Karts en directo: dos moviles en la misma carrera; misma parrilla, se ven el uno al otro, el
## anfitrion mueve los bots, las cascaras cruzan la red y cada uno acaba con su puesto.
func _test_kart_live() -> void:
	print("- Karts en directo")
	var M: GDScript = load("res://kit/kart/kart_map.gd")
	var keep: Dictionary = Kit.config.duplicate(true)
	var ring: Array = []
	for k: int in 12:
		var a: float = TAU * float(k) / 12.0
		ring.append("%.1f,%.1f" % [cos(a) * 70.0, sin(a) * 45.0])
	ring.append("#7")
	var lv: Dictionary = {"name": "K", "map": ring, "laps": 1, "skill": 0.2, "need": 3, "rivals": 5, "width": 12}
	Kit.config["genre"] = "kart"
	Kit.config["levels"] = [lv]
	Kit.level_index = 0
	Online.fake_net_latency = 0.05
	Save.set_setting("online", true, false)
	var players: Array = [{"sesion": "aaaaaaaaaaaaaaa1", "alias": "Dani", "slot": 0}, {"sesion": "bbbbbbbbbbbbbbb2", "alias": "Lucia", "slot": 1}]
	var base: Dictionary = {"sala": "sala-karts", "jugadores": players, "nivel": 0, "semilla": 77, "start_ms": Time.get_ticks_msec() - 50, "modo": "todos"}
	Online.arena_match = base.duplicate(true)
	Online.arena_match["yo"] = "aaaaaaaaaaaaaaa1"
	var ga: Node = (load("res://scenes/kart.tscn") as PackedScene).instantiate()
	add_child(ga)
	Online.arena_match = base.duplicate(true)
	Online.arena_match["yo"] = "bbbbbbbbbbbbbbb2"
	var gb: Node = (load("res://scenes/kart.tscn") as PackedScene).instantiate()
	add_child(gb)
	await frames(2)
	var sa: Dictionary = ga.get("st")
	var sb: Dictionary = gb.get("st")
	var lb_a: Dictionary = M.kart_by_sid(sa, "bbbbbbbbbbbbbbb2")
	var bot_a: Dictionary = M.kart_by_sid(sa, "bot0")
	var bot_b: Dictionary = M.kart_by_sid(sb, "bot0")
	check("karts online: el primero mueve los bots y en el otro llegan por la red", bool(ga.get("host")) and not bool(gb.get("host")) and not bool(bot_a["remote"]) and bool(bot_b["remote"]) and bool(lb_a["remote"]))
	check("karts online: la misma parrilla en los dos moviles", (lb_a["p"] as Vector2).distance_to(sb["karts"][0]["p"]) < 0.01 and (bot_a["p"] as Vector2).distance_to(bot_b["p"]) < 0.01 and (sa["karts"] as Array).size() == 6)
	check("karts online: el nombre del otro piloto encima de su kart", ga.find_child("Name", true, false) != null and str(lb_a["name"]) == "Lucia")
	ga.call("bot_step")
	gb.call("bot_step")
	for f: int in 60 * 7:
		await get_tree().physics_frame
	var me_b: Dictionary = sb["karts"][0]
	check("karts online: cada uno ve al otro donde va", float(me_b["v"]) > 8.0 and (lb_a["p"] as Vector2).distance_to(me_b["p"]) < 4.0, "%s / %s" % [lb_a["p"], me_b["p"]])
	check("karts online: los bots del anfitrion llegan al otro movil", float(bot_a["v"]) > 5.0 and (bot_b["p"] as Vector2).distance_to(bot_a["p"]) < 4.0, "%s / %s" % [bot_b["p"], bot_a["p"]])
	## Una cascara del invitado aparece en el anfitrion; si le da, se borra tambien en el invitado.
	me_b["item"] = "cascara"
	var shot: Dictionary = M.use_item(sb, me_b)
	var sid: String = str(shot.get("id", ""))
	var seen: Dictionary = {}
	for f2: int in 12:
		await get_tree().physics_frame
		for s2: Dictionary in sa["shots"]:
			if str(s2["id"]) == sid:
				seen = s2
		if not seen.is_empty():
			break
	check("karts online: la cascara del otro aparece en tu pista", sid.begins_with("bbbbbbbbbbbbbbb2:") and not seen.is_empty() and str(seen["kind"]) == "cascara", sid)
	var me_a: Dictionary = sa["karts"][0]
	if not seen.is_empty():
		seen["p"] = me_a["p"]
		seen["age"] = 2.0
	me_a["item"] = ""
	for f3: int in 12:
		await get_tree().physics_frame
	var gone_b: bool = true
	for s3: Dictionary in sb["shots"]:
		if str(s3["id"]) == sid:
			gone_b = false
	check("karts online: te da a ti, trompeas y desaparece en los dos", float(me_a["stun"]) > 0.0 or bool(me_a["done"]), str(me_a["stun"]))
	check("karts online: el disparo gastado se borra en el otro movil", gone_b)
	check("karts online: sin pausa en directo", ga.call("open_pause") == null and ga.get_node_or_null("PauseMenu") == null)
	for f4: int in 60 * 90:
		await get_tree().physics_frame
		if bool(ga.get("reported")) and bool(gb.get("reported")):
			break
	await frames(20)
	var pa: int = M.human_place(sa)
	var pb: int = M.human_place(sb)
	check("karts online: los dos llegan a meta y cada uno con su puesto entre personas", bool(ga.get("reported")) and bool(gb.get("reported")) and pa + pb == 3 and bool(M.kart_by_sid(sa, "bbbbbbbbbbbbbbb2")["done"]),
		"%s %s %d %d" % [ga.get("reported"), gb.get("reported"), pa, pb])
	check("karts online: el resultado de la carrera en directo", ga.find_child("ArenaPanel", true, false) != null or get_tree().root.find_child("ArenaPanel", true, false) != null)
	## Si el anfitrion se va, el otro pasa a mover los bots.
	var st2: Dictionary = M.new_state(lv)
	M.setup_online(st2, players, "bbbbbbbbbbbbbbb2", false)
	var b2: Dictionary = M.kart_by_sid(st2, "bot1")
	var was: bool = bool(b2["remote"])
	M.make_host(st2)
	check("karts online: sin anfitrion, el que queda mueve los bots", was and not bool(b2["remote"]) and bool(st2["host"]) and bool(M.kart_by_sid(st2, "aaaaaaaaaaaaaaa1")["remote"]))
	ga.queue_free()
	gb.queue_free()
	await frames(3)
	for n: Node in get_children():
		if n is ArenaPanel:
			n.queue_free()
	Online.fake_net_latency = -1.0
	Online.arena_match = {}
	Kit.config = keep
	Kit.level_index = 0
	await frames(2)

## Zombis cooperativo en directo: dos moviles en la misma arena, el anfitrion mueve los zombis, los
## disparos y mordiscos cruzan la red, se ven el uno al otro y acaban juntos.
func _test_zombie_live() -> void:
	print("- Zombis cooperativo en directo")
	var M: GDScript = load("res://kit/zombie/zombie_map.gd")
	var keep: Dictionary = Kit.config.duplicate(true)
	var arena: Array = ["###########", "#Z.......Z#", "#.........#", "#...c.....#", "#....P....#", "#.........#", "#.....c...#", "#Z.......Z#", "###########", "#4"]
	var lv: Dictionary = {"name": "Z", "map": arena, "waves": 2, "count": 3, "grow": 1, "speed": 0.3, "hp": 100, "types": [9, 9]}
	Kit.config["genre"] = "zombie"
	Kit.config["levels"] = [lv]
	Kit.level_index = 0
	Online.fake_net_latency = 0.05
	Save.set_setting("online", true, false)
	var players: Array = [{"sesion": "aaaaaaaaaaaaaaa1", "alias": "Dani", "slot": 0}, {"sesion": "bbbbbbbbbbbbbbb2", "alias": "Lucia", "slot": 1}]
	var base: Dictionary = {"sala": "sala-zombis", "jugadores": players, "nivel": 0, "semilla": 55, "start_ms": Time.get_ticks_msec() - 50, "modo": "coop"}
	Online.arena_match = base.duplicate(true)
	Online.arena_match["yo"] = "aaaaaaaaaaaaaaa1"
	var ga: Node = (load("res://scenes/zombie.tscn") as PackedScene).instantiate()
	add_child(ga)
	Online.arena_match = base.duplicate(true)
	Online.arena_match["yo"] = "bbbbbbbbbbbbbbb2"
	var gb: Node = (load("res://scenes/zombie.tscn") as PackedScene).instantiate()
	add_child(gb)
	await frames(2)
	var sa: Dictionary = ga.get("st")
	var sb: Dictionary = gb.get("st")
	check("coop: el primero mueve los zombis y el otro los sigue", bool(ga.get("host")) and not bool(gb.get("host")) and str(sa["role"]) == "host" and str(sb["role"]) == "client")
	check("coop: misma arena, mas zombis por ser dos y cada uno ve al otro", int(sa["count"]) == 5 and int(sb["count"]) == 5 and (sa["mates"] as Dictionary).has(1) and (sb["mates"] as Dictionary).has(0) and ga.find_child("Mate1", true, false) != null)
	ga.call("bot_step")
	gb.call("bot_step")
	for k: int in 360:
		await get_tree().physics_frame
	var za: int = 0
	for z: Dictionary in sa["zombies"]:
		if float(z["hp"]) > 0.0:
			za += 1
	var zb: int = 0
	for z2: Dictionary in sb["zombies"]:
		if float(z2["hp"]) > 0.0:
			zb += 1
	check("coop: los zombis llegan al otro movil", int(sb["wave"]) == int(sa["wave"]) and int(sa["wave"]) >= 1 and absi(za - zb) <= 2, "%d/%d w%d/%d" % [za, zb, int(sa["wave"]), int(sb["wave"])])
	var mate_b: Dictionary = (sa["mates"] as Dictionary)[1]
	check("coop: el anfitrion ve donde esta el otro", (mate_b["p"] as Vector2).distance_to(sb["me"]["p"]) < 1.5, "%s / %s" % [mate_b["p"], sb["me"]["p"]])
	## Un disparo del invitado le quita vida al zombi del anfitrion.
	var target: Dictionary = {}
	for z3: Dictionary in sa["zombies"]:
		if float(z3["hp"]) > 30.0:
			target = z3
			break
	if not target.is_empty():
		var hp0: float = float(target["hp"])
		(gb.get("net") as RealtimeChannel).send("hit", {"id": int(target["id"]), "d": 20.0})
		for k2: int in 12:
			await get_tree().physics_frame
		check("coop: el disparo del otro cuenta en el anfitrion", float(target["hp"]) <= hp0 - 19.0, "%f -> %f" % [hp0, float(target["hp"])])
	else:
		check("coop: el disparo del otro cuenta en el anfitrion", true)
	## Un mordisco del anfitrion le llega al invitado.
	var hpb: float = float(sb["me"]["hp"])
	(ga.get("net") as RealtimeChannel).send("bite", {"n": 1, "d": 7.0})
	for k3: int in 12:
		await get_tree().physics_frame
	check("coop: el mordisco llega al otro movil", float(sb["me"]["hp"]) < hpb or bool(gb.get("finished")))
	## Quien cae vuelve en la oleada siguiente; acaban juntos.
	for k4: int in 60 * 120:
		await get_tree().physics_frame
		if bool(ga.get("reported")) and bool(gb.get("reported")):
			break
	check("coop: los dos acaban la partida a la vez y ganan juntos", bool(ga.get("reported")) and bool(gb.get("reported")) and bool(sa["won"]) and bool(sb["won"]),
		"%s %s %s %s" % [ga.get("reported"), gb.get("reported"), sa["won"], sb["won"]])
	check("coop: sin pausa en directo", (ga.call("open_pause") == null) and ga.get_node_or_null("PauseMenu") == null)
	## Si el anfitrion se va, el otro pasa a mover los zombis.
	var st2: Dictionary = M.new_state(lv)
	M.setup_online(st2, ["Dani", "Lucia"], 1, false)
	st2["t"] = 20.0
	st2["host_t"] = 1.0
	(st2["mates"][0] as Dictionary)["t"] = 1.0
	M.net_timeouts(st2, 8.0)
	check("coop: sin noticias del anfitrion, su companero sale como caido", bool(st2["mates"][0]["gone"]))
	M.make_host(st2)
	check("coop: y el que queda pasa a anfitrion", str(st2["role"]) == "host")
	ga.queue_free()
	gb.queue_free()
	await frames(3)
	for n: Node in get_children():
		if n is ArenaPanel:
			n.queue_free()
	Online.fake_net_latency = -1.0
	Online.arena_match = {}
	Kit.config = keep
	Kit.level_index = 0
	await frames(2)


## Terror 3D: llaves, puerta que se abre, el monstruo ve y persigue, armario, vidas y el bot.
func _test_horror() -> void:
	print("- Terror 3D")
	var M: GDScript = load("res://kit/horror/horror_map.gd")
	var lv: Dictionary = {"name": "H", "map": ["#####X#####", "#k........#", "#.###.###.#", "#.#H....#.#", "#.#.###.#.#", "#...#M#...#",
		"#.#.#.#.#.#", "#.#.....#k#", "#.###.###.#", "#P.......H#", "###########", "#21"], "lives": 3, "speed": 0.3, "sight": 7.0}
	var st: Dictionary = M.new_state(lv)
	check("terror: llaves, armarios, salida y monstruo", (st["keys"] as Array).size() == 2 and (st["hides"] as Array).size() == 2
		and (st["exit"] as Vector2i) == Vector2i(5, 0) and not bool(st["open"]))
	## La puerta cerrada no deja pasar; con las dos llaves se abre.
	for k: Dictionary in st["keys"]:
		st["p"] = M.center(k["c"])
		M.step(st, {"move": Vector2.ZERO}, 0.05)
	check("terror: con todas las llaves se abre la puerta", int(st["got"]) == 2 and bool(st["open"]))
	## El monstruo ve en linea recta pero no a traves de paredes.
	var st2: Dictionary = M.new_state(lv)
	check("terror: las paredes tapan la vista", M.sees(st2, Vector2(1.5, 9.5), Vector2(8.5, 9.5)) and not M.sees(st2, Vector2(1.5, 9.5), Vector2(5.5, 5.5)))
	## Te persigue si te ve, y en el armario te pierde.
	var mon: Dictionary = st2["mon"]
	mon["p"] = Vector2(3.5, 9.5)
	mon["dir"] = Vector2(1, 0)
	st2["p"] = Vector2(6.0, 9.5)
	M.step(st2, {"move": Vector2.ZERO}, 0.05)
	check("terror: si te ve, te persigue", str(mon["state"]) == "chase")
	var st3: Dictionary = M.new_state(lv)
	st3["p"] = M.center(Vector2i(9, 9)) + Vector2(-1.0, 0)
	M.step(st3, {"move": Vector2.ZERO, "hide": true}, 0.05)
	check("terror: escondido en el armario", bool(st3["hidden"]) and (st3["p"] as Vector2) == M.center(Vector2i(9, 9)))
	var st4: Dictionary = M.new_state(lv)
	(st4["mon"] as Dictionary)["p"] = st4["p"]
	M.step(st4, {"move": Vector2.ZERO}, 0.05)
	check("terror: si te pilla pierdes una vida y vuelves a la entrada", int(st4["lives"]) == 2 and (st4["p"] as Vector2) == (st4["start"] as Vector2))
	var r: Dictionary = M.bot_play(lv)
	check("terror: el bot escapa", bool(r["won"]) and int(r["caught"]) <= 1, str(r))
	check("terror: el analizador lo acepta", bool(M.analyze(lv)["completable"]))
	var bad: Dictionary = {"map": ["#####X#####", "#k#.......#", "###.......#", "#........P#", "#M........#", "###########"]}
	check("terror: una llave encerrada se rechaza", (M.analyze(bad)["issues"] as Array).has("horror_unreachable"))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "horror"
	Kit.config["levels"] = [lv]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/horror.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	check("terror: la casa en 3D con monstruo y puerta", g is Node3D and g.get_node_or_null("Walls") != null and g.get_node_or_null("Monster") != null
		and g.get_node_or_null("ExitDoor") != null)
	var Bot: GDScript = load("res://qa/horror_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 20000)
	check("terror: el bot gana jugando", won, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Futbol 3D: saque, controlar, tirar a gol, el portero para, robar, la IA marca y el juego en 3D.
func _test_soccer() -> void:
	print("- Futbol 3D")
	var M: GDScript = load("res://kit/soccer/soccer_map.gd")
	var lv: Dictionary = {"name": "F", "map": ["campo", "#11"], "players": 3, "skill": 0.15, "mates": 0.65, "time": 60}
	var st: Dictionary = M.new_state(lv)
	check("futbol: dos equipos con portero", (st["players"] as Array).size() == 6 and str(st["players"][0]["role"]) == "gk" and str(st["players"][3]["role"]) == "gk")
	## Tu delantero solo ante la porteria: el tiro entra.
	var st2: Dictionary = M.new_state(lv)
	st2["pause_t"] = 0.0
	var me: Dictionary = st2["players"][2]
	for pl: Dictionary in st2["players"]:
		if pl != me:
			pl["p"] = Vector2(1.0 + float(pl["i"]), float(st2["l"]) - 1.0)
	me["p"] = Vector2(float(st2["w"]) * 0.5, 6.0)
	st2["owner"] = 2
	M.step(st2, {"move": Vector2.ZERO, "shoot": true}, 1.0 / 30.0)
	for k: int in 60:
		M.step(st2, {"move": Vector2.ZERO}, 1.0 / 30.0)
	check("futbol: un tiro a porteria vacia es gol", int(st2["score"][0]) == 1)
	## El portero para un tiro flojo al centro.
	var st3: Dictionary = M.new_state(lv)
	st3["pause_t"] = 0.0
	var shooter: Dictionary = st3["players"][5]
	shooter["p"] = Vector2(float(st3["w"]) * 0.5, float(st3["l"]) - 9.0)
	st3["owner"] = 5
	M.kick(st3, shooter, Vector2(0, 1), 9.0, 0.0)
	var saved: bool = false
	for k2: int in 90:
		M.step(st3, {"move": Vector2.ZERO}, 1.0 / 30.0)
		if int(st3["owner"]) == 0:
			saved = true
			break
	check("futbol: el portero para un tiro flojo", saved and int(st3["score"][1]) == 0)
	## Mando: el jugador que manejas se mueve.
	var st4: Dictionary = M.new_state(lv)
	st4["pause_t"] = 0.0
	for k3: int in 5:
		M.step(st4, {"move": Vector2(1, 0)}, 1.0 / 30.0)
	var c: Dictionary = st4["players"][int(st4["ctrl"])]
	check("futbol: el que manejas obedece al mando", int(st4["ctrl"]) > 0 and (c["v"] as Vector2).x > 2.0)
	var r: Dictionary = M.bot_play(lv)
	check("futbol: el bot gana a un rival flojo", bool(r["won"]), str(r))
	check("futbol: el analizador acepta un rival flojo", bool(M.analyze(lv)["completable"]))
	var hard: Dictionary = lv.duplicate()
	hard["skill"] = 1.0
	hard["mates"] = 0.0
	hard["need"] = 4
	check("futbol: un rival imposible se rechaza", not bool(M.analyze(hard)["completable"]))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "soccer"
	Kit.config["levels"] = [lv]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/soccer.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	check("futbol: estadio, porterias, jugadores y balon en 3D", g is Node3D and g.get_node_or_null("Ball") != null and g.get_node_or_null("Player0") != null
		and g.get_node_or_null("Crowd") != null)
	var Bot: GDScript = load("res://qa/soccer_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 20000)
	check("futbol: el bot gana jugando", won, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Tienda 3D: coger de la caja, reponer, clientes que compran y pagan, abrir productos pagando,
## guardado entre niveles, el bot y el juego en 3D.
func _test_market() -> void:
	print("- Tienda 3D")
	var M: GDScript = load("res://kit/market/market_map.gd")
	var lv: Dictionary = {"name": "T", "map": ["#########", "#1.2.3.4#", "#.......#", "#.......#", "#a.b.c.d#", "#.......#", "#......U#",
		"#.......#", "#..K.S..#", "#.......#", "#R......#", "#.......#", "#.......#", "####E####", "#77"], "goal": 60, "products": 1,
		"costs": [0, 40, 120, 260], "hire": [150, 240], "upgrade": 60, "spawn": 5.0, "seed": 7}
	var st: Dictionary = M.new_state(lv)
	check("tienda: un producto abierto, cajas, caja registradora y puerta", M.open_ids(st) == [0] and (st["prods"] as Array).size() == 4
		and (st["register"] as Vector2i) == Vector2i(1, 10) and int(st["h"]) == 14)
	## Ir a la caja de la fruta: se carga hasta el tope.
	var me: Dictionary = st["me"]
	me["p"] = M.stand_at(st, M.prod(st, 0)["crate"])
	for k: int in 40:
		M.step(st, 0.05)
	check("tienda: se carga en la caja", (me["carry"] as Array).size() == int(me["cap"]))
	me["p"] = M.stand_at(st, M.prod(st, 0)["shelf"])
	var before: int = int(M.prod(st, 0)["items"])
	for k2: int in 40:
		M.step(st, 0.05)
	check("tienda: se repone la estanteria", int(M.prod(st, 0)["items"]) > before)
	## Pagar para abrir el pan.
	st["money"] = 100
	me["p"] = M.stand_at(st, M.prod(st, 1)["shelf"])
	for k3: int in 60:
		M.step(st, 0.05)
	check("tienda: pagando se abre otro producto", bool(M.prod(st, 1)["open"]) and int(st["money"]) == 60)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(M.save_data(st, lv)))
	var st2: Dictionary = M.new_state(lv)
	check("tienda: lo abierto y el dinero siguen en el nivel siguiente", M.load_into(st2, lv, saved) and bool(M.prod(st2, 1)["open"]) and int(st2["money"]) == 60)
	## Clientes: con alguien en la caja pagan y el dinero queda junto a la caja.
	var st3: Dictionary = M.new_state(lv)
	(st3["me"] as Dictionary)["p"] = M.cashier_pos(st3)
	for k4: int in 1200:
		M.step(st3, 0.05)
	check("tienda: los clientes compran y pagan en la caja", int(st3["served"]) >= 3 and int(st3["pile"]) > 0)
	var r: Dictionary = M.bot_play(lv)
	check("tienda: el bot llega a la meta", bool(r["won"]), str(r))
	check("tienda: el analizador lo acepta", bool(M.analyze(lv)["completable"]))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "market"
	lv["par"] = 200
	Kit.config["levels"] = [lv]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/market.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	check("tienda: la tienda se ve en 3D", g is Node3D and g.get_node_or_null("Register") != null and g.get_node_or_null("Shelf0") != null and g.get_node_or_null("Me") != null)
	var Bot: GDScript = load("res://qa/market_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 20000)
	check("tienda: el bot gana jugando", won, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Parkour 3D: piezas, fisica (saltar, plataformas que llevan, lava, barras), el bot que planifica
## los saltos y el juego en 3D ganado por el bot.
func _test_obby() -> void:
	print("- Parkour 3D")
	var M: GDScript = load("res://kit/obby/obby_map.gd")
	var lv: Dictionary = {"name": "O", "map": ["P 0 -0.5 0 5 1 5", "P 0 -0.5 -6 2.5 1 2.5", "O 0 1.8 -3.5",
		"M 0 -0.3 -11 2.5 0.6 2.5 1.8 0 0 3 0", "C 0 -0.5 -15.5 3 1 3", "F 0 -0.3 -19.5 2.2 0.6 2.2 2.8 0.1",
		"P 0 -0.5 -27 3 1 8", "S 0 0.55 -27 2.8 1.6", "J 0 -0.3 -33 2.5 0.6 2.5", "P 0 3.5 -38 3 1 3", "G 0 3.5 -44 5 1 5"]}
	var st: Dictionary = M.new_state(lv)
	check("parkour: piezas y monedas", (st["pieces"] as Array).size() == 11 and int(st["coins_total"]) == 1)
	for k: int in 10:
		M.step(st, {"move": Vector2.ZERO, "jump": false}, 1.0 / 30.0)
	check("parkour: de pie en la salida", bool(st["on_floor"]) and int(st["ground"]) == 0 and absf((st["p"] as Vector3).y) < 0.01)
	M.step(st, {"move": Vector2.ZERO, "jump": true}, 1.0 / 30.0)
	check("parkour: saltar sube", (st["v"] as Vector3).y > 5.0 and not bool(st["on_floor"]))
	var st2: Dictionary = M.new_state(lv)
	st2["yaw"] = 0.0
	for k2: int in 60:
		M.step(st2, {"move": Vector2(0, 1), "jump": false}, 1.0 / 30.0)
		if bool(st2["dead"]):
			break
	check("parkour: andar fuera de la plataforma es caer", bool(st2["dead"]))
	M.respawn(st2)
	check("parkour: se vuelve a la salida y cuenta la caida", int(st2["deaths"]) == 1 and (st2["p"] as Vector3).distance_to(Vector3.ZERO) < 0.01)
	var pc_m: Dictionary = st["pieces"][3]
	check("parkour: la plataforma movil se mueve", M.center_at(pc_m, 0.75).distance_to(M.center_at(pc_m, 0.0)) > 1.0)
	var pc_f: Dictionary = st["pieces"][5]
	var on_t: int = 0
	for k3: int in 28:
		if M.solid_at(pc_f, float(k3) * 0.1):
			on_t += 1
	check("parkour: la fugaz aparece y desaparece", on_t > 10 and on_t < 22)
	var bar: Dictionary = st["pieces"][7]
	var hits: int = 0
	for k4: int in 40:
		if M.spinner_hits(bar, Vector3(0, 0, -27.8), float(k4) * 0.1):
			hits += 1
	check("parkour: la barra barre y se puede saltar", hits > 0 and hits < 40 and not M.spinner_hits(bar, Vector3(0, 1.2, -27.8), 0.0))
	var r: Dictionary = M.bot_play(lv)
	check("parkour: el bot llega a la meta", bool(r["won"]) and int(r["deaths"]) == 0, str(r))
	check("parkour: el analizador lo acepta", bool(M.analyze(lv)["completable"]))
	var bad: Dictionary = {"map": ["P 0 -0.5 0 5 1 5", "P 0 -0.5 -14 2 1 2", "G 0 -0.5 -20 5 1 5"]}
	check("parkour: un salto imposible se rechaza", (M.analyze(bad)["issues"] as Array).has("obby_too_hard"))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "obby"
	lv["par"] = 60
	Kit.config["levels"] = [lv]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/obby.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	check("parkour: el recorrido se ve en 3D", g is Node3D and g.get_node_or_null("Piece0") != null and g.get_node_or_null("Hero") != null)
	var Bot: GDScript = load("res://qa/obby_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 12000)
	check("parkour: el bot gana jugando", won, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Mundo de cubos 3D: semilla, picar y poner, rayo, guardado, el bot y el juego en 3D de verdad.
func _test_voxel() -> void:
	print("- Mundo de cubos 3D")
	var M: GDScript = load("res://kit/voxel/voxel_map.gd")
	var S: GDScript = load("res://kit/sandbox/sandbox_map.gd")
	var lv: Dictionary = {"name": "V", "map": ["bllm", "#7"], "seed": 7, "goal_item": "mesa", "goal_n": 1}
	var st: Dictionary = M.new_state(lv)
	check("cubos: la misma semilla da el mismo mundo", st["grid"] == M.new_state(lv)["grid"])
	check("cubos: hay arboles y minerales", M.count_blocks(st, S.LOG) > 12 and M.count_blocks(st, S.IRON) > 10 and M.count_blocks(st, S.CRYSTAL) > 2)
	for k: int in 30:
		M.step(st, {"move": Vector2.ZERO, "jump": false}, 1.0 / 30.0)
	var f: Vector3i = M.feet(st)
	check("cubos: se empieza de pie sobre el suelo", bool(st["on_floor"]) and M.solid(st, f.x, f.y - 1, f.z) and not M.solid(st, f.x, f.y, f.z))
	## Mirar al suelo: el rayo da en el cubo de debajo, con la cara de arriba.
	var hit: Dictionary = M.raycast(st, M.eye(st), Vector3(0.05, -1.0, 0.02))
	check("cubos: el rayo da en el suelo", not hit.is_empty() and (hit["cell"] as Vector3i).y == f.y - 1 and hit["normal"] == Vector3i(0, 1, 0))
	var under: Vector3i = hit["cell"]
	var id0: int = M.at(st, under.x, under.y, under.z)
	st["mine_target"] = under
	for k2: int in 60:
		M.step(st, {"move": Vector2.ZERO, "jump": false}, 1.0 / 30.0)
		if M.at(st, under.x, under.y, under.z) == S.AIR:
			break
	check("cubos: picar da el cubo", M.at(st, under.x, under.y, under.z) == S.AIR and M.have(st, str(S.BLOCKS[id0]["drop"])) >= 1)
	st["mine_target"] = Vector3i(-1, -1, -1)
	for k3: int in 30:
		M.step(st, {"move": Vector2.ZERO, "jump": false}, 1.0 / 30.0)
	## Poner un cubo al lado (no dentro del jugador).
	var f2: Vector3i = M.feet(st)
	var side: Vector3i = f2 + Vector3i(2, 0, 0)
	if M.at(st, side.x, side.y, side.z) != S.AIR:
		side = f2 + Vector3i(2, 1, 0)
	st["inv"]["tierra"] = 3
	check("cubos: no se pone un cubo dentro de ti", not M.can_place(st, f2, "tierra"))
	check("cubos: se pone un cubo en un hueco", M.at(st, side.x, side.y, side.z) != S.AIR or M.place(st, side, "tierra"))
	## Andar mueve al jugador (en alguna de las cuatro direcciones, segun el relieve).
	var walked: float = 0.0
	for yaw: float in [0.0, PI * 0.5, PI, -PI * 0.5]:
		var sw: Dictionary = M.new_state(lv)
		sw["yaw"] = yaw
		for k4: int in 40:
			M.step(sw, {"move": Vector2(0, 1), "jump": false}, 1.0 / 30.0)
		walked = maxf(walked, Vector2((sw["p"] as Vector3).x - (sw["spawn"] as Vector3).x, (sw["p"] as Vector3).z - (sw["spawn"] as Vector3).z).length())
	check("cubos: andar mueve", walked > 2.0, str(walked))
	var saved: Dictionary = JSON.parse_string(JSON.stringify(M.save_data(st)))
	var st2: Dictionary = M.new_state(lv)
	check("cubos: se guarda y se recupera", M.load_into(st2, saved) and M.at(st2, under.x, under.y, under.z) == S.AIR and M.have(st2, "tierra") == M.have(st, "tierra"))
	check("cubos: otro mundo no carga la partida", not M.load_into(M.new_state({"map": ["dddd"], "seed": 3}), saved))
	check("cubos: el bot hace la mesa", bool(M.analyze(lv)["completable"]))
	var lv2: Dictionary = lv.duplicate()
	lv2["goal_item"] = "lingote_hierro"
	check("cubos: el bot llega al hierro", bool(M.analyze(lv2)["completable"]))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "voxel"
	lv["par"] = 60
	Kit.config["levels"] = [lv]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/voxel.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	check("cubos: el mundo se ve en 3D", g is Node3D and g.get_node_or_null("Chunk_1_1") != null and (g.get_node("Chunk_1_1") as MeshInstance3D).mesh != null)
	var Bot: GDScript = load("res://qa/voxel_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 12000)
	check("cubos: el bot gana jugando", won and int(g.get("deaths")) == 0, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


func _royale_level() -> Dictionary:
	return {"name": "R", "map": ["~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~", "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~", "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~", "~~~~~~~~~~~~~~~,,,~~~~~~~~~~~~~~~~~~~~~~~~", "~~~~~~~~~~~~~,,,,,,,~~~~~~~~~~~~~~~~~~~~~~", "~~~~~~~~~~~~,,,....,,~~~~~~~~~~~~~~~~~~~~~", "~~~~~~~~~~,,,,......,,~~~~~~~~~~~~~~~~~~~~", "~~~~~~~~~,,,.t.t.....,,~~~~~~~~~~~~~~~~~~~", "~~~~~~~~,,,....t......,,,,,,,,,,~~~~~~~~~~", "~~~~~~~,,,t.t#####.....,,,,....,,~~~~~~~~~", "~~~~~~~,,..tt#___#.......r......,,~~~~~~~~", "~~~~~~~,,....____#...............,,~~~~~~~", "~~~~~~~,.tt.t#___#...............,,~~~~~~~", "~~~~~~~,..tt.##_##tt..............,,~~~~~~", "~~~~~~~,,.....t.t.t.....#####.....,,,~~~~~", "~~~~~~~,,...............#___#......,,~~~~~", "~~~~~~~,,...............#___#.....tt,,~~~~", "~~~~~~~,,.###_##.####...____#..####.,,~~~~", "~~~~~~,,..#____#.#__#...#___#..#__#..,,~~~", "~~~~~~,,..#____#.___#...##_##..___#.t,,~~~", "~~~~~,,...######.#__#..........##_#tt,,~~~", "~~~~~,,..........##_#...............,,~~~~", "~~~~~,t.............................,,~~~~", "~~~~~,.......................####...,,~~~~", "~~~~~,,......................#__#.r,,~~~~~", "~~~~~~,,...##_##.............___#..,,~~~~~", "~~~~~~~,,.r#___#.............##_#..,,~~~~~", "~~~~~~~~,,.#___#..####.............,,~~~~~", "~~~~~~~~,,.#####..#__#.............,,~~~~~", "~~~~~~~~~,........#__#............,,~~~~~~", "~~~~~~~~~,,.......___#..........,,,,~~~~~~", "~~~~~~~~~,,.......#__#....,,,,,,,,~~~~~~~~", "~~~~~~~~~,,.......##_#...,,~~~~~~~~~~~~~~~", "~~~~~~~~~~,..............,~~~~~~~~~~~~~~~~", "~~~~~~~~~~,,............,,~~~~~~~~~~~~~~~~", "~~~~~~~~~~,,,.......r...,~~~~~~~~~~~~~~~~~", "~~~~~~~~~~~,,,,,......,,,~~~~~~~~~~~~~~~~~", "~~~~~~~~~~~~~,,,,,,,,,,,~~~~~~~~~~~~~~~~~~", "~~~~~~~~~~~~~~~~~,,,,,~~~~~~~~~~~~~~~~~~~~", "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~", "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~", "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"], "bots": 11, "skill": 0.25, "top": 5, "seed": 1026}


## Battle royale en 3D: la misma partida dibujada en 3D (isla, soldados, zona) y el bot la juega.
func _test_royale_3d() -> void:
	print("- Battle royale en 3D")
	var keep: Dictionary = Kit.config.duplicate(true)
	var lv: Dictionary = _royale_level()
	Kit.config["genre"] = "royale"
	Kit.config["view"] = "3d"
	lv["par"] = 120
	Kit.config["levels"] = [lv]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/royale.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	var v: Node = g.get_node_or_null("View3D")
	check("royale 3D: isla, muros y soldados en 3D", v != null and v.get_node_or_null("Island") != null and v.get_node_or_null("Walls") != null
		and v.get_node_or_null("Agent0") != null and not (g.get_node("World") as CanvasItem).visible)
	var Bot: GDScript = load("res://qa/royale_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 30000)
	check("royale 3D: el bot gana jugando en 3D", won, str(g.call("bot_state")))
	check("royale 3D: los fogonazos y chispas no se acumulan", (g.get("_tracers") as Array).size() < 64 and (g.get("_fx") as Array).size() < 300)
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Battle royale en directo: dos moviles en la misma isla (canales locales con retraso): los
## mismos bots (los mueve el anfitrion), el mismo botin y la misma zona, posiciones que llegan y
## una caida que se cuenta en los dos.
func _test_royale_live() -> void:
	print("- Battle royale en directo")
	var M: GDScript = load("res://kit/royale/royale_map.gd")
	var keep: Dictionary = Kit.config.duplicate(true)
	var lv: Dictionary = _royale_level()
	lv["bots"] = 6
	Kit.config["genre"] = "royale"
	Kit.config["levels"] = [lv]
	Kit.level_index = 0
	Online.fake_net_latency = 0.05
	Save.set_setting("online", true, false)
	var players: Array = [{"sesion": "aaaaaaaaaaaaaaa1", "alias": "Dani", "slot": 0}, {"sesion": "bbbbbbbbbbbbbbb2", "alias": "Lucia", "slot": 1}]
	var base: Dictionary = {"sala": "sala-royale", "jugadores": players, "nivel": 0, "semilla": 77, "start_ms": Time.get_ticks_msec() - 50, "modo": "royale"}
	Online.arena_match = base.duplicate(true)
	Online.arena_match["yo"] = "aaaaaaaaaaaaaaa1"
	var ga: Node = (load("res://scenes/royale.tscn") as PackedScene).instantiate()
	add_child(ga)
	Online.arena_match = base.duplicate(true)
	Online.arena_match["yo"] = "bbbbbbbbbbbbbbb2"
	var gb: Node = (load("res://scenes/royale.tscn") as PackedScene).instantiate()
	add_child(gb)
	await frames(2)
	var sa: Dictionary = ga.get("st")
	var sb: Dictionary = gb.get("st")
	var aa: Array = sa["agents"]
	var ab: Array = sb["agents"]
	check("directo: misma isla y mismos jugadores", aa.size() == ab.size() and aa.size() == 7 and (sa["loot"] as Array).size() == (sb["loot"] as Array).size())
	check("directo: cada uno es el primero en su movil", int(aa[0]["nid"]) == 0 and int(ab[0]["nid"]) == 1 and str(ab[1]["name"]) == "Dani" and str(aa[1]["name"]) == "Lucia")
	check("directo: el anfitrion mueve los bots", bool(ga.get("host")) and not bool(gb.get("host")) and not bool(aa[3]["remote"]) and bool(ab[3]["remote"]) and bool(aa[1]["remote"]))
	ga.call("bot_step")
	gb.call("bot_step")
	for k: int in int((M.PLANE_T + 6.0) * 60.0):
		await get_tree().physics_frame
		if bool(ga.get("finished")) or bool(gb.get("finished")):
			break
	var me_a: Dictionary = aa[0]
	var seen_a: Dictionary = M.by_nid(sb, 0)
	check("directo: lo que hace uno lo ve el otro", bool(seen_a["landed"]) and (seen_a["p"] as Vector2).distance_to(me_a["p"]) < 90.0,
		"%s / %s" % [me_a["p"], seen_a["p"]])
	var bot_a: Dictionary = M.by_nid(sa, 4)
	var bot_b: Dictionary = M.by_nid(sb, 4)
	check("directo: los bots van igual en los dos", not bool(bot_a["alive"]) or (bot_a["p"] as Vector2).distance_to(bot_b["p"]) < 90.0)
	check("directo: la zona se cierra igual", (sa["to_c"] as Vector2).distance_to(sb["to_c"]) < 1.0 and is_equal_approx(float(sa["to_r"]), float(sb["to_r"])) and int(sa["phase"]) >= 0)
	var ids_a: Dictionary = {}
	for it: Dictionary in sa["loot"]:
		ids_a[str(it["id"])] = true
	var diff: int = 0
	for it2: Dictionary in sb["loot"]:
		if not ids_a.has(str(it2["id"])):
			diff += 1
	check("directo: el botin que coge uno desaparece en el otro", diff <= 2 and absi((sa["loot"] as Array).size() - (sb["loot"] as Array).size()) <= 2, str(diff))
	## Lucia cae ante Dani en su movil: los dos lo cuentan.
	if not bool(gb.get("finished")) and bool(ab[0]["alive"]):
		var k0: int = int(aa[0]["kills"])
		M._hurt(sb, ab[0], 999.0, int(M.by_nid(sb, 0)["id"]))
		for k2: int in 30:
			await get_tree().physics_frame
		check("directo: la caida llega al otro movil", not bool(M.by_nid(sa, 1)["alive"]) and int(aa[0]["kills"]) == k0 + 1 and bool(gb.get("reported")),
			"%s %d" % [M.by_nid(sa, 1)["alive"], int(aa[0]["kills"])])
	else:
		check("directo: la caida llega al otro movil", true)
	check("directo: sin pausa en directo", ga.get_node_or_null("PauseMenu") == null and (ga.call("open_pause") == null) and ga.get_node_or_null("PauseMenu") == null)
	ga.queue_free()
	gb.queue_free()
	await frames(3)
	for n: Node in get_children():
		if n is ArenaPanel:
			n.queue_free()
	Online.fake_net_latency = -1.0
	Online.arena_match = {}
	Kit.config = keep
	Kit.level_index = 0
	await frames(2)


## Battle royale: isla, botin, armas, zona que se cierra, puesto final, analizador y el bot.
func _test_royale() -> void:
	print("- Battle royale")
	var M: GDScript = load("res://kit/royale/royale_map.gd")
	var lv: Dictionary = _royale_level()
	var st: Dictionary = M.new_state(lv)
	check("royale: rivales y botin", (st["agents"] as Array).size() == int(lv["bots"]) + 1 and (st["loot"] as Array).size() > 10)
	var a: Dictionary = st["agents"][1]
	check("royale: un arma mejor se coge y la peor no", M.wants(a, "pistola") and M.take(a, "fusil") == "" and not M.wants(a, "pistola"))
	M.drop(st, a)
	check("royale: al saltar se cae en tierra", bool(a["landed"]) and not M.blocks_move(st, a["p"]))
	var b: Dictionary = st["agents"][2]
	b["landed"] = true
	b["p"] = (a["p"] as Vector2) + Vector2(120, 0)
	var hp0: float = float(b["hp"])
	a["aim"] = Vector2.RIGHT
	a["skill"] = 1.0
	if M.sight(st, a["p"], b["p"]):
		for k: int in 20:
			M.shoot(st, a)
			M._bullets_step(st, 1.0 / 30.0)
			M._bullets_step(st, 1.0 / 30.0)
		check("royale: las balas hacen dano", float(b["hp"]) < hp0)
	else:
		check("royale: las balas hacen dano", true)
	## La zona: tras el avion empieza la primera fase y fuera se pierde vida.
	var st2: Dictionary = M.new_state(lv)
	for k2: int in int((M.PLANE_T + 30.0) * 10.0):
		M.step(st2, 0.1)
		if bool(st2["over"]):
			break
	check("royale: la zona se cierra", int(st2["phase"]) >= 0 and float(st2["zone_r"]) < float(st2["from_r"]) + 1.0)
	check("royale: el bot queda entre los mejores", bool(M.analyze(lv)["completable"]))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "royale"
	lv["par"] = 120
	Kit.config["levels"] = [lv]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/royale.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	var Bot: GDScript = load("res://qa/royale_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 30000)
	check("royale: el bot gana jugando", won, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Musica que respira: intensidad (filtro) y pausa tras un cristal.
func _test_audio_feel() -> void:
	print("- Musica que respira")
	Audio.set_intensity(1.0)
	await get_tree().create_timer(1.0).timeout
	var open_hz: float = Audio.cutoff()
	Audio.set_intensity(0.0)
	await get_tree().create_timer(1.0).timeout
	var calm_hz: float = Audio.cutoff()
	check("musica: en calma suena mas apagada", calm_hz < open_hz * 0.3, "%d -> %d Hz" % [int(open_hz), int(calm_hz)])
	Audio.set_intensity(1.0)
	Audio.muffle(true)
	await get_tree().create_timer(0.5).timeout
	check("musica: en pausa, tras un cristal", Audio.cutoff() < 800.0, str(int(Audio.cutoff())))
	Audio.muffle(false)
	await get_tree().create_timer(1.0).timeout
	check("musica: al seguir vuelve a sonar abierta", Audio.cutoff() > 15000.0, str(int(Audio.cutoff())))


## Cruzar: coches, rio con troncos, tren, monedas, plan del bot y partida.
func _test_hopper() -> void:
	print("- Cruzar")
	var M: GDScript = load("res://kit/hopper/hopper_map.gd")
	var lv: Dictionary = {"name": "H", "map": ["g:....c....", "r>2.0:..c....c.....", "g:..t......", "w<1.2:LLL...LLL...", "t>18:6", "g:.........", "F"]}
	var st: Dictionary = M.new_state(lv)
	check("cruzar: carriles y una moneda", (st["rows"] as Array).size() == 7 and int(st["coins_total"]) == 1)
	var s1: Dictionary = M.new_state(lv)
	M.hop(s1, Vector2i(1, 0))
	M.hop(s1, Vector2i(-1, 0))
	check("cruzar: no se sale del borde ni atraviesa arboles", M.new_state(lv)["x"] == 4.0 and float(s1["x"]) == 4.0)
	## Coche encima: muerto.
	var s2: Dictionary = M.new_state(lv)
	var row: Dictionary = s2["rows"][1]
	var hit: bool = false
	for k: int in 200:
		var probe: Dictionary = M.copy_state(s2)
		probe["t"] = float(k) * 0.05
		M.hop(probe, Vector2i(0, 1))
		if bool(probe["dead"]) and str(probe["cause"]) == "car":
			hit = true
			break
	check("cruzar: un coche te pilla", hit)
	var s3: Dictionary = M.new_state({"map": ["g:.........", "w>1.0:............", "F"]})
	M.hop(s3, Vector2i(0, 1))
	check("cruzar: al agua sin tronco", bool(s3["dead"]) and str(s3["cause"]) == "water")
	check("cruzar: el tren avisa antes de pasar", M.train_warning(st["rows"][4], 6.0 - (9.0 + 8.0) / 18.0 - 0.5))
	check("cruzar: el bot encuentra el camino", bool(M.analyze(lv)["completable"]))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "hopper"
	lv["par"] = 20
	Kit.config["levels"] = [lv]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/hopper.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	var Bot: GDScript = load("res://qa/hopper_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 9000)
	check("cruzar: el bot gana jugando", won and int(g.get("deaths")) == 0, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Tiro con arco: vuelo con gravedad y viento, anillos de la diana, globos, bot y partida.
func _test_archery() -> void:
	print("- Tiro con arco")
	var M: GDScript = load("res://kit/archery/archery_map.gd")
	var lv: Dictionary = {"name": "A", "map": ["t:25,1.5,0.8,0,0", "g:20,6", "w:0.5"], "arrows": 4, "goal": 20, "seed": 3}
	var st: Dictionary = M.new_state(lv)
	check("arco: diana, globo y viento", (st["targets"] as Array).size() == 1 and (st["balloons"] as Array).size() == 1 and float(st["wind"]) == 0.5)
	var low: Dictionary = M.fly(st, 0.0, 0.2, 0.0)
	check("arco: un tiro flojo cae al suelo", int(low["points"]) == 0 and (low["end"] as Vector2).y <= 0.05)
	var aim: Vector2 = M.bot_aim(st)
	var r: Dictionary = M.fly(st, aim.x, aim.y, 0.0)
	check("arco: el bot clava cerca del centro", int(r["points"]) >= 7, str(r["points"]))
	var calm: Dictionary = M.new_state({"map": ["t:25,1.5,0.8,0,0"]})
	var windy: Dictionary = M.new_state({"map": ["t:25,1.5,0.8,0,0", "w:-4"]})
	check("arco: el viento cambia el tiro", (M.fly(calm, 0.2, 0.6, 0.0)["end"] as Vector2).distance_to(M.fly(windy, 0.2, 0.6, 0.0)["end"]) > 0.5)
	var n0: int = int(st["arrows"])
	M.shoot(st, aim.x, aim.y)
	check("arco: tirar gasta una flecha y suma", int(st["arrows"]) == n0 - 1 and int(st["score"]) >= 7)
	check("arco: el bot llega a la meta", bool(M.analyze(lv)["completable"]))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "archery"
	lv["par"] = 30
	Kit.config["levels"] = [lv]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/archery.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	var Bot: GDScript = load("res://qa/archery_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 9000)
	check("arco: el bot gana jugando", won and int(g.get("deaths")) == 0, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Adivina la palabra: diccionarios de 6 idiomas, pistas con letras repetidas, modo dificil y bot.
func _test_wordle() -> void:
	print("- Adivina la palabra")
	var D: GDScript = load("res://kit/words/words_dict.gd")
	var M: GDScript = load("res://kit/wordle/wordle_map.gd")
	var all_ok: bool = true
	for l: String in D.LANGS:
		var d: Dictionary = D.load_lang(l)
		all_ok = all_ok and (d["valid"] as Dictionary).size() > 15000 and ((d["targets"] as Dictionary).get(5, []) as Array).size() > 500
	check("palabra: diccionarios de los 6 idiomas con soluciones", all_ok)
	check("palabra: el espanol tiene la \u00d1", D.is_word("es", "A\u00d1O") and D.alphabet("es").contains("\u00d1"))
	check("palabra: pistas con letras repetidas", M.score("ALLAS", "SALAS") == "Y.GGG" and M.score("PAPEL", "PAPAS") == "GGG..", M.score("ALLAS", "SALAS") + " " + M.score("PAPEL", "PAPAS"))
	var lv: Dictionary = {"len": 5, "tries": 6, "rank": 0.1, "map": ["palabra", "#77"]}
	check("palabra: misma semilla, misma palabra", M.target(lv, "es") == M.target(lv, "es") and M.target(lv, "es").length() == 5)
	check("palabra: otro intento, otra palabra", M.target(lv, "es", 1) != M.target(lv, "es") or M.target(lv, "es", 2) != M.target(lv, "es"))
	var st: Dictionary = M.new_state(lv, "es")
	check("palabra: solo valen palabras del diccionario", M.why_not(st, "QXZWK") == "word" and M.why_not(st, "ABC") == "short")
	var hard: Dictionary = M.new_state({"len": 5, "hard": true, "seed": 5}, "en")
	var w: String = str(hard["word"])
	var probe: String = M.bot_guess(hard)
	M.guess(hard, probe)
	var green_at: int = str(hard["marks"][0]).find("G")
	var ok_hard: bool = true
	if green_at >= 0 and not bool(hard["over"]):
		for cand: Variant in (D.load_lang("en")["targets"] as Dictionary).get(5, []):
			if str(cand)[green_at] != probe[green_at]:
				ok_hard = M.why_not(hard, str(cand)) == "hard"
				break
	check("palabra: el modo dificil obliga a usar las pistas", ok_hard, w + " " + probe)
	var h: Array = M.hint(st)
	check("palabra: la pista descubre una letra", int(h[0]) >= 0 and str(st["word"])[int(h[0])] == str(h[1]) and M.hint(st)[0] == -1)
	var a: Dictionary = M.analyze({"len": 6, "tries": 7, "rank": 0.5, "seed": 9})
	check("palabra: el bot acierta en los 6 idiomas", bool(a["completable"]) and int(a["worst"]) <= 7, str(a))
	check("palabra: largo imposible no vale", not bool(M.analyze({"len": 9})["completable"]))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "wordle"
	Kit.config["levels"] = [{"name": "W", "len": 5, "tries": 6, "rank": 0.1, "map": ["palabra", "#12"], "par": 60}]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/wordle.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	g.call("press", "Q")
	check("palabra: el teclado escribe", str(g.get("typed")) == "Q")
	g.call("press", "DEL")
	var Bot: GDScript = load("res://qa/wordle_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 4000)
	check("palabra: el bot gana jugando", won and int(g.get("deaths")) == 0, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Palabras con letras: rueda, crucigrama que se cruza bien, extras, pistas y bot.
func _test_letters() -> void:
	print("- Palabras con letras")
	var M: GDScript = load("res://kit/letters/letters_map.gd")
	var lv: Dictionary = {"len": 5, "words": 5, "rank": 0.1, "map": ["letras", "#31"]}
	var b: Dictionary = M.build(lv, "es")
	check("letras: el crucigrama tiene sus palabras", not b.is_empty() and (b["place"] as Dictionary).size() == 5, str(b.get("words", [])))
	var ok_fit: bool = true
	for w: Variant in b.get("words", []):
		ok_fit = ok_fit and M.fits(str(w), M.counts(str(b["root"])))
	check("letras: todas salen de la rueda", ok_fit and (b["letters"] as Array).size() == 5)
	var ok_grid: bool = true
	for w2: Variant in b.get("words", []):
		var pl: Array = b["place"][w2]
		for i: int in str(w2).length():
			ok_grid = ok_grid and str(b["grid"][(pl[0] as Vector2i) + (pl[1] as Vector2i) * i]) == str(w2)[i]
	check("letras: el crucigrama cuadra letra a letra", ok_grid)
	var st: Dictionary = M.new_state(lv, "es")
	var first: String = str(st["b"]["words"][0])
	check("letras: una palabra del crucigrama entra", M.submit(st, first) == "word" and M.submit(st, first) == "again")
	var extra: String = ""
	for e: Variant in st["b"]["extra"]:
		if not (st["b"]["place"] as Dictionary).has(e):
			extra = str(e)
			break
	check("letras: una palabra que existe pero no esta es extra", extra == "" or M.submit(st, extra) == "bonus", extra)
	check("letras: con letras que no estan no vale", M.submit(st, "ZZZZ") == "")
	var c: Vector2i = M.hint(st)
	check("letras: la pista descubre una letra", c != Vector2i(-999, -999) and M.shown(st).has(c) and int(st["hints"]) == 2)
	check("letras: el crucigrama sale en los 6 idiomas", bool(M.analyze({"len": 6, "words": 7, "rank": 0.4, "seed": 3})["completable"]), str(M.analyze({"len": 6, "words": 7, "rank": 0.4, "seed": 3})))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "letters"
	Kit.config["levels"] = [{"name": "L", "len": 4, "words": 4, "rank": 0.1, "map": ["letras", "#8"], "par": 60}]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/letters.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	var Bot: GDScript = load("res://qa/letters_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 4000)
	check("letras: el bot gana jugando", won and int(g.get("deaths")) == 0, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Tycoon: negocios e hitos, mina con cuello de botella, gerentes, sin conexion, analizador y bot.
func _test_tycoon() -> void:
	print("- Tycoon")
	var M: GDScript = load("res://kit/tycoon/tycoon_map.gd")
	var lv: Dictionary = {"open": 3, "par": 60, "target": 2000}
	var st: Dictionary = M.new_state(lv)
	check("tycoon: tres negocios, el primero ya comprado", (st["order"] as Array).size() == 3 and int(st["stations"]["limonada"]["n"]) == 1 and int(st["stations"]["periodicos"]["n"]) == 0)
	check("tycoon: cada unidad cuesta un poco mas", is_equal_approx(M.cost(st, "limonada", 1), 4.0 * 1.07) and M.cost(st, "limonada", 10) > 10.0 * M.cost(st, "limonada", 1))
	check("tycoon: sin tocar no trabaja", M.step(st, 2.0).is_empty() and float(st["money"]) == 0.0)
	M.tap(st, "limonada")
	M.step(st, 0.7)
	check("tycoon: al tocar trabaja un ciclo y se para", float(st["money"]) == 1.0 and not bool(st["stations"]["limonada"]["run"]))
	st["money"] = 1e6
	var t0: float = M.cycle_time(st, "limonada")
	M.buy(st, "limonada", 24)
	check("tycoon: a las 25 unidades va el doble de rapido", is_equal_approx(M.cycle_time(st, "limonada"), t0 * 0.5), str(M.cycle_time(st, "limonada")))
	check("tycoon: comprar MAX no pasa del dinero", M.cost(st, "limonada", M.max_count(st, "limonada")) <= float(st["money"]) and M.cost(st, "limonada", M.max_count(st, "limonada") + 1) > float(st["money"]))
	M.hire(st, "limonada")
	var m0: float = float(st["money"])
	M.step(st, 3.0)
	check("tycoon: con gerente trabaja solo", float(st["money"]) > m0 + 100.0 and bool(st["stations"]["limonada"]["mgr"]))
	check("tycoon: sin conexion gana lo que tiene gerente (y tiene tope)", M.offline_gain(st, 100.0) > 0.0 and is_equal_approx(M.offline_gain(st, 99999.0), M.offline_gain(st, 7200.0)))
	var up: Dictionary = M.pending_upgrades(st)[0]
	var a0: float = M.amount(st, str(up["target"]) if str(up["target"]) != "all" else "limonada")
	M.buy_upgrade(st, str(up["id"]))
	check("tycoon: las mejoras multiplican", is_equal_approx(M.amount(st, str(up["target"]) if str(up["target"]) != "all" else "limonada"), a0 * float(up["mult"])))
	check("tycoon: numeros cortos", M.fmt(1234.0) == "1.23K" and M.fmt(5.6e9) == "5.60B" and M.fmt(999.0) == "999" and M.fmt(1e18).length() <= 6, M.fmt(1e18))
	## Mina: el pozo llena su caja, el ascensor la sube y el almacen vende; manda el mas lento.
	var ms: Dictionary = M.new_state({"open": 2, "tycoon": {"preset": "mina"}})
	check("tycoon mina: almacen, ascensor y pozos", (ms["order"] as Array) == ["store", "lift", "carbon", "hierro"], str(ms["order"]))
	M.tap(ms, "carbon")
	M.step(ms, 3.0)
	check("tycoon mina: el pozo llena su caja", float(ms["stations"]["carbon"]["box"]) > 0.0 and float(ms["money"]) == 0.0)
	M.tap(ms, "lift")
	M.step(ms, 3.0)
	M.tap(ms, "store")
	M.step(ms, 3.0)
	check("tycoon mina: el ascensor sube y el almacen vende", float(ms["money"]) > 0.0 and float(ms["stations"]["carbon"]["box"]) == 0.0)
	ms["money"] = 1e9
	M.buy(ms, "carbon", 40)
	check("tycoon mina: el ascensor lento frena todo", M.rate(ms) <= M.amount(ms, "lift") / M.cycle_time(ms, "lift") + 0.001 and M.rate(ms) < 0.5 * M.amount(ms, "carbon") / M.cycle_time(ms, "carbon"))
	check("tycoon mina: el bot ve que subir el ascensor es lo mejor", str(M.best_buy(ms).get("id", "")) in ["lift", "store"], str(M.best_buy(ms)))
	## Datos: un tycoon inventado (nombres del tema) y numeros propios.
	var custom: Dictionary = M.new_state({"open": 2, "tycoon": {"cur": "G", "biz": {"limonada": {"name": "Churros", "look": "donut"}, "periodicos": {"name": "Chocolate", "profit": 80}}}})
	check("tycoon: nombres y numeros por datos", M.name_of(custom, "limonada") == "Churros" and M.look_of(custom, "limonada") == "donut" and is_equal_approx(float(M.info(custom, "periodicos")["profit"]), 80.0))
	var a: Dictionary = M.analyze({"open": 3, "par": 90, "target": 20000})
	check("tycoon: el analizador ve la meta a tiempo", bool(a["completable"]), str(a))
	check("tycoon: meta imposible no vale", not bool(M.analyze({"open": 2, "par": 60, "target": 1e15})["completable"]))
	check("tycoon: meta regalada no vale", not bool(M.analyze({"open": 2, "par": 60, "target": 5})["completable"]))
	check("tycoon mina: el analizador ve la meta", bool(M.analyze({"open": 3, "par": 90, "target": 2000, "tycoon": {"preset": "mina"}})["completable"]))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "tycoon"
	Kit.config["levels"] = [{"name": "T", "open": 2, "par": 30, "target": 60, "start": 10, "map": ["tycoon"]}]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/tycoon.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	check("tycoon: una tarjeta por negocio", (g.get("_cards") as Dictionary).size() == 2)
	g.call("press_buy", "limonada")
	check("tycoon: el boton de comprar compra", int(g.get("st")["stations"]["limonada"]["n"]) == 2)
	g.call("cycle_step")
	check("tycoon: x1, x10...", int(g.get("buy_step")) == 10)
	var Bot: GDScript = load("res://qa/tycoon_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 60 * 90)
	check("tycoon: el bot gana jugando", won and int(g.get("deaths")) == 0, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Tragaperras con aldea: tiradas, premios, bonus, aldea, recarga, analizador y bot.
func _test_slots() -> void:
	print("- Tragaperras")
	var M: GDScript = load("res://kit/slots/slots_map.gd")
	var st: Dictionary = M.new_state({"seed": 7, "spins": 20, "regen": 10, "scale": 1.0})
	check("tragaperras: 7 simbolos y 5 edificios", (st["syms"] as Array).size() == 7 and (st["builds"] as Array).size() == 5)
	st["bet"] = 2
	var r: Dictionary = M.spin(st)
	check("tragaperras: tirar gasta la apuesta y saca 3", int(st["spins"]) == 18 + int(r.get("spins", 0)) and (r["reels"] as Array).size() == 3)
	var same: Dictionary = M.new_state({"seed": 7, "spins": 20})
	same["bet"] = 2
	check("tragaperras: misma semilla, misma tirada", M.spin(same)["reels"] == r["reels"])
	## Tres iguales: se fuerza el resultado con un catalogo de un solo simbolo.
	var one: Dictionary = M.new_state({"seed": 1, "spins": 10, "slots": {"symbols": {"bag": null, "star": null, "chest": null, "energy": null, "hammer": null, "pig": null}}})
	var r1: Dictionary = M.spin(one)
	check("tragaperras: tres monedas pagan su premio por la apuesta", float(r1["coins"]) == 200.0 and float(one["coins"]) == 200.0, str(r1))
	var pk: Dictionary = M.new_state({"seed": 1, "spins": 10, "slots": {"symbols": {"coin": null, "bag": null, "star": null, "chest": null, "energy": null, "pig": null}}})
	M.spin(pk)
	check("tragaperras: tres martillos abren los cofres y no deja tirar", str(pk["bonus"].get("kind", "")) == "pick" and M.spin(pk).is_empty())
	var won: float = M.pick(pk, 1)
	check("tragaperras: un cofre paga x1, x2 o x4", [500.0, 1000.0, 2000.0].has(won) and (pk["bonus"] as Dictionary).is_empty())
	var rd: Dictionary = M.new_state({"seed": 2, "spins": 10, "slots": {"symbols": {"coin": null, "bag": null, "star": null, "chest": null, "energy": null, "hammer": null}}})
	M.spin(rd)
	var dug: float = M.dig(rd, 0) + M.dig(rd, 1) + M.dig(rd, 2)
	check("tragaperras: el asalto excava 3 hoyos y se acaba", (rd["bonus"] as Dictionary).is_empty() and dug >= 0.0 and M.dig(rd, 3) == -1.0)
	var fs: Dictionary = M.new_state({"seed": 3, "spins": 5, "slots": {"symbols": {"coin": null, "bag": null, "star": null, "chest": null, "hammer": null, "pig": null}}})
	M.spin(fs)
	check("tragaperras: tres rayos dan tiradas", int(fs["spins"]) == 4 + 8)
	st["coins"] = 100000.0
	var nb: Array = M.next_build(st)
	check("tragaperras: se construye lo mas barato", M.build(st, int(nb[0])) and int(st["builds"][int(nb[0])]["stage"]) == 1)
	for k: int in 20:
		var n2: Array = M.next_build(st)
		if int(n2[0]) >= 0:
			M.build(st, int(n2[0]))
	check("tragaperras: la aldea entera gana", bool(st["won"]) and M.village_cost(st) == 0.0)
	var rg: Dictionary = M.new_state({"seed": 1, "spins": 10, "regen": 10})
	M.tick(rg, 35.0)
	check("tragaperras: las tiradas se recargan con el tiempo", int(rg["spins"]) == 13 and M.offline_spins(rg, 100000.0) == M.MAX_SPINS - 13)
	check("tragaperras: valor medio de una tirada", M.expected(st) > 20.0 and M.expected(st) < 80.0, str(M.expected(st)))
	var a: Dictionary = M.analyze({"par": 240, "spins": 40, "regen": 15, "scale": 0.75, "seed": 3})
	check("tragaperras: el analizador ve la aldea a tiempo", bool(a["completable"]), str(a))
	check("tragaperras: una aldea carisima no vale", not bool(M.analyze({"par": 120, "spins": 20, "regen": 30, "scale": 20.0})["completable"]))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "slots"
	Kit.config["levels"] = [{"name": "S", "par": 120, "spins": 40, "regen": 10, "scale": 0.3, "seed": 4, "map": ["slots"]}]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/slots.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	g.call("cycle_bet")
	check("tragaperras: la apuesta cambia", int(g.get("st")["bet"]) == 2)
	g.call("press_spin")
	check("tragaperras: el boton tira", int(g.get("st")["spun"]) == 1 and bool(g.call("rolling")))
	await frames(70)
	check("tragaperras: los rodillos paran", not bool(g.call("rolling")))
	var Bot: GDScript = load("res://qa/slots_bot.gd")
	var w: bool = await Bot.run(get_tree(), g, 60 * 60)
	check("tragaperras: el bot gana jugando", w and int(g.get("deaths")) == 0, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Reino: ciudad, produccion, entrenamiento en tiempo real, obras, batallas y bot.
func _test_realm() -> void:
	print("- Reino")
	var M: GDScript = load("res://kit/realm/realm_map.gd")
	var st: Dictionary = M.new_state({"par": 200}, false)
	check("reino: castillo, produccion y primer cuartel al empezar", int(st["lv"]["castillo"]) == 1 and int(st["lv"]["granja"]) == 1 and int(st["lv"]["cuartel"]) == 1 and int(st["lv"]["establo"]) == 0)
	var f0: float = float(st["res"]["food"])
	M.step(st, 10.0)
	check("reino: el cuartel entrena solo gastando comida", float(st["army"]["infantry"]) > 2.0 and float(st["res"]["wood"]) > 150.0, str(st["army"]))
	check("reino: ningun edificio pasa del castillo", M.why_not(st, "granja") == "center")
	check("reino: mejorar el castillo cuesta y tarda", M.upgrade(st, "castillo") and M.why_not(st, "granja") == "busy" and not (st["queue"] as Dictionary).is_empty())
	var left: float = float(st["queue"]["left"])
	check("reino: la ayuda acelera la obra", M.help(st) and float(st["queue"]["left"]) < left and not M.help(st))
	M.step(st, 30.0)
	check("reino: la obra termina", int(st["lv"]["castillo"]) == 2 and (st["queue"] as Dictionary).is_empty())
	var cat: Dictionary = M.catalog({})
	var r1: Dictionary = M.battle(cat, {"infantry": 30, "cavalry": 0, "archer": 0}, [], {"infantry": 0, "cavalry": 30, "archer": 0})
	var r2: Dictionary = M.battle(cat, {"infantry": 30, "cavalry": 0, "archer": 0}, [], {"infantry": 0, "cavalry": 0, "archer": 30})
	check("reino: piedra, papel, tijera (lanceros ganan a jinetes y pierden con arqueros)", bool(r1["win"]) and not bool(r2["win"]))
	var r3: Dictionary = M.battle(cat, {"infantry": 30, "cavalry": 0, "archer": 0}, ["amadea"], {"infantry": 30, "cavalry": 0, "archer": 0})
	check("reino: un heroe desempata", bool(r3["win"]))
	var lv: Dictionary = {"par": 240, "cap": 5, "camps": [{"at": 0.2, "str": 0.6, "mix": [1, 0, 0], "hero": "amadea"}, {"at": 0.5, "str": 0.7, "mix": [1, 1, 0]}, {"at": 0.8, "str": 0.9, "mix": [1, 1, 1]}]}
	var s2: Dictionary = M.new_state(lv)
	check("reino: campamentos que crecen y el ultimo es el jefe", (s2["camps"] as Array).size() == 3 and M.total_army({"army": s2["camps"][2]["army"]}) > M.total_army({"army": s2["camps"][0]["army"]}) and bool(s2["camps"][2]["boss"]))
	s2["army"] = {"infantry": 500.0, "cavalry": 500.0, "archer": 500.0}
	var w0: float = float(s2["res"]["wood"])
	var ra: Dictionary = M.attack(s2)
	check("reino: ganar da recursos y el heroe", bool(ra["win"]) and float(s2["res"]["wood"]) > w0 and (s2["heroes"] as Array).has("amadea"))
	var a: Dictionary = M.analyze(lv)
	check("reino: el analizador ve al bot conquistar a tiempo", bool(a["completable"]), str(a))
	var hard: Dictionary = lv.duplicate(true)
	hard["camps"][2]["str"] = 3.0
	check("reino: un jefe imposible no vale", not bool(M.analyze(hard)["completable"]))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "realm"
	Kit.config["levels"] = [{"name": "R", "par": 150, "cap": 4, "map": ["reino"], "camps": [{"at": 0.3, "str": 0.6, "mix": [1, 0, 0]}, {"at": 0.7, "str": 0.8, "mix": [1, 1, 1]}]}]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/realm.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	g.call("select", "granja")
	check("reino: tocar un edificio lo elige", str(g.get("selected")) == "granja")
	var Bot: GDScript = load("res://qa/realm_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 60 * 60)
	check("reino: el bot gana jugando", won and int(g.get("deaths")) == 0, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Tragaperras estilo dados (tipo Monopoly Go): ficha, salida, casillas, valor medio y bot.
func _test_slots_dice() -> void:
	print("- Tragaperras con dados")
	var M: GDScript = load("res://kit/slots/slots_map.gd")
	var lv: Dictionary = {"seed": 5, "spins": 30, "regen": 10, "slots": {"preset": "dados"}}
	var st: Dictionary = M.new_state(lv)
	check("dados: tablero de 20 casillas", bool(st["dice_mode"]) and (st["cat"]["board"] as Array).size() == 20)
	var r: Dictionary = M.spin(st)
	check("dados: la ficha avanza lo que suman los dados", int(st["pos"]) == (int(r["dice"][0]) + int(r["dice"][1])) % 20 and str(r["tile"]) == str(st["cat"]["board"][int(st["pos"])]))
	st["pos"] = 18
	st["coins"] = 0.0
	var r2: Dictionary = M.spin(st)
	check("dados: pasar por la salida paga", bool(r2.get("passed", false)) and float(st["coins"]) >= 0.0)
	var tax: Dictionary = M.new_state({"seed": 1, "spins": 30, "slots": {"preset": "dados", "board": ["go", "tax", "tax", "tax", "tax", "tax", "tax", "tax", "tax", "tax", "tax", "tax", "tax", "tax", "tax", "tax", "tax", "tax", "tax", "tax"], "pass": 0}})
	M.spin(tax)
	check("dados: el impuesto no deja en negativo", float(tax["coins"]) == 0.0)
	## (las tiradas de las casillas de tiradas valen otra tirada: sin contarlas, el 70 % del valor)
	var ev: float = M.expected(st)
	var emp: Dictionary = M.new_state({"seed": 11, "spins": 50, "slots": {"preset": "dados"}})
	var units: int = 0
	for k: int in 40000:
		emp["spins"] = 50
		emp["bet"] = 1
		M.spin(emp)
		units += 1
		var b: Dictionary = emp["bonus"]
		if str(b.get("kind", "")) == "pick":
			M.pick(emp, k % 3)
		elif str(b.get("kind", "")) == "raid":
			M.dig(emp, 0)
			M.dig(emp, 1)
			M.dig(emp, 2)
	var real: float = float(emp["coins"]) / float(units)
	check("dados: el valor medio calculado cuadra con el jugado", absf(real - ev * 0.7) < ev * 0.7 * 0.15, "%.1f vs %.1f" % [real, ev])
	var a: Dictionary = M.analyze({"par": 240, "spins": 40, "regen": 15, "scale": 0.7, "seed": 3, "slots": {"preset": "dados"}})
	check("dados: el analizador ve la aldea a tiempo", bool(a["completable"]), str(a))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "slots"
	Kit.config["levels"] = [{"name": "D", "par": 120, "spins": 40, "regen": 10, "scale": 0.3, "seed": 4, "map": ["tragaperras"], "slots": {"preset": "dados"}}]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/slots.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	var Bot: GDScript = load("res://qa/slots_bot.gd")
	var w: bool = await Bot.run(get_tree(), g, 60 * 60)
	check("dados: el bot gana jugando", w, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Multitud: puertas, enemigos, trampas, jefe, mejor camino, analizador y bot.
func _test_crowd() -> void:
	print("- Multitud")
	var M: GDScript = load("res://kit/crowd/crowd_map.gd")
	check("multitud: puertas que suman, restan, multiplican y dividen", M.apply(10, "+5") == 15 and M.apply(10, "-15") == 0 and M.apply(10, "x3") == 30 and M.apply(10, "/3") == 3)
	var lv: Dictionary = {"start": 5, "speed": 10, "track": [{"d": 10, "t": "gate", "l": "+5", "r": "x3"}, {"d": 20, "t": "trap", "lane": "r", "k": 4},
		{"d": 30, "t": "enemy", "n": 6}, {"d": 40, "t": "gate", "l": "/2", "r": "+10"}, {"d": 50, "t": "boss", "n": 12}]}
	var b: Dictionary = M.best(lv)
	check("multitud: el mejor camino (x3, esquivar, +10)", int(b["end"]) == 5 * 3 - 6 + 10 and b["lanes"][0] == "r" and b["lanes"][1] == "l" and int(b["boss"]) == 12, str(b))
	check("multitud: el peor camino pierde", M.worst(lv) == 0)
	check("multitud: el analizador acepta un nivel justo", bool(M.analyze(lv)["completable"]))
	var hard: Dictionary = lv.duplicate(true)
	hard["track"][4]["n"] = 40
	check("multitud: jefe imposible no vale", not bool(M.analyze(hard)["completable"]))
	var st: Dictionary = M.new_state(lv)
	st["x"] = 0.5
	M.step(st, 1.05)
	check("multitud: pasar por la puerta de la derecha", int(st["n"]) == 15)
	st["x"] = -0.5
	M.step(st, 1.0)
	M.step(st, 1.0)
	check("multitud: esquivar la trampa y luchar con el grupo", int(st["n"]) == 9)
	st["x"] = -0.5
	M.step(st, 1.0)
	M.step(st, 1.0)
	check("multitud: el jefe gana si llegas con menos", bool(st["lost"]) and int(st["n"]) == 0)
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "crowd"
	Kit.config["levels"] = [lv.merged({"name": "C", "map": ["multitud", "#1"]})]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/crowd.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	var Bot: GDScript = load("res://qa/crowd_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 60 * 30)
	check("multitud: el bot gana jugando", won and int(g.get("deaths")) == 0, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Fusion con pedidos: generadores, fusionar, mover, entregar, energia, analizador y bot.
func _test_mergeboard() -> void:
	print("- Fusion con pedidos")
	var M: GDScript = load("res://kit/mergeboard/mergeboard_map.gd")
	var lv: Dictionary = {"starter": false, "chains": ["bread", "tea"], "energy": 6, "regen": 5, "par": 120, "orders": [{"who": "A", "need": [["bread", 2]], "reward": 10}, {"who": "B", "need": [["tea", 1], ["bread", 1]], "reward": 5}]}
	var st: Dictionary = M.new_state(lv)
	check("pedidos: dos generadores abajo", (st["grid"] as Dictionary).size() == 2 and (st["grid"][Vector2i(0, 8)] as Dictionary).get("gen", "") == "bread")
	var a: Vector2i = M.tap(st, Vector2i(0, 8))
	var b: Vector2i = M.tap(st, Vector2i(0, 8))
	check("pedidos: tocar el generador saca objetos y gasta energia", a.x >= 0 and b.x >= 0 and a != b and int(st["energy"]) == 4)
	check("pedidos: dos iguales se fusionan", M.drag(st, a, b) == "merge" and int(st["grid"][b]["l"]) == 2 and not (st["grid"] as Dictionary).has(a))
	check("pedidos: un generador no se arrastra y lo distinto no se fusiona", M.drag(st, Vector2i(0, 8), Vector2i(3, 3)) == "" and M.drag(st, b, Vector2i(1, 8)) == "")
	check("pedidos: a una casilla libre se mueve", M.drag(st, b, Vector2i(5, 1)) == "move")
	check("pedidos: entregar el pedido", M.deliver(st, 0) and bool(st["orders"][0]["done"]) and not (st["grid"] as Dictionary).has(Vector2i(5, 1)))
	check("pedidos: sin los objetos no se entrega", not M.deliver(st, 1))
	M.tap(st, Vector2i(1, 8))
	M.tap(st, Vector2i(0, 8))
	check("pedidos: el ultimo pedido gana", M.deliver(st, 1) and bool(st["won"]))
	var e: Dictionary = M.new_state({"starter": false, "chains": ["bread"], "energy": 0, "regen": 5, "orders": [{"need": [["bread", 1]]}]})
	check("pedidos: sin energia no saca nada", M.tap(e, Vector2i(0, 8)).x < 0)
	M.tick(e, 11.0)
	check("pedidos: la energia se recarga", int(e["energy"]) == 2)
	check("pedidos: energia necesaria (nivel L = 2^(L-1))", M.energy_needed({"orders": [{"need": [["bread", 3], ["tea", 1]]}]}) == 5)
	var big: Dictionary = {"chains": ["bread", "tea", "flower"], "energy": 30, "regen": 4, "par": 200, "orders": [{"who": "A", "need": [["bread", 4]]}, {"who": "B", "need": [["tea", 3], ["flower", 2]]}, {"who": "C", "need": [["flower", 4], ["bread", 3]]}]}
	var an: Dictionary = M.analyze(big)
	check("pedidos: el analizador ve los pedidos a tiempo", bool(an["completable"]), str(an))
	var slow: Dictionary = big.duplicate(true)
	slow["regen"] = 60
	slow["energy"] = 2
	check("pedidos: sin energia suficiente no vale", not bool(M.analyze(slow)["completable"]))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "mergeboard"
	Kit.config["levels"] = [big.merged({"name": "P", "map": ["pedidos", "#1"]})]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/mergeboard.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	g.call("tap_cell", Vector2i(0, 8))
	check("pedidos: tocar el horno en el juego", int(g.get("st")["taps"]) == 1)
	var Bot: GDScript = load("res://qa/mergeboard_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 60 * 60)
	check("pedidos: el bot gana jugando", won, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Reglas programables en los generos por datos: cada simulacion llama a sus ganchos.
func _test_rules_data() -> void:
	print("- Reglas en los generos por datos")
	var R: Array = ["res://qa/rule_probe.gd"]
	var TY: GDScript = load("res://kit/tycoon/tycoon_map.gd")
	var t: Dictionary = TY.new_state({"open": 2, "rules": R})
	t["money"] = 100.0
	TY.buy(t, "limonada", 1)
	TY.tap(t, "limonada")
	TY.step(t, 1.0)
	check("reglas tycoon: on_start, on_buy, on_cycle y on_step", _probe(t, ["on_start", "on_buy", "on_cycle", "on_step"]), str(t.get("probe", {})))
	var SL: GDScript = load("res://kit/slots/slots_map.gd")
	var s: Dictionary = SL.new_state({"seed": 1, "rules": R})
	SL.spin(s)
	s["coins"] = 1e6
	SL.build(s, 0)
	SL.tick(s, 1.0)
	check("reglas tragaperras: on_spin, on_build y on_step", _probe(s, ["on_start", "on_spin", "on_build", "on_step"]), str(s.get("probe", {})))
	var RE: GDScript = load("res://kit/realm/realm_map.gd")
	var r: Dictionary = RE.new_state({"par": 120, "rules": R, "camps": [{"at": 0.5, "str": 0.1, "mix": [1, 0, 0]}]})
	RE.upgrade(r, "castillo")
	RE.step(r, 20.0)
	r["army"]["infantry"] = 500.0
	RE.attack(r)
	check("reglas reino: on_upgrade, on_battle y on_step", _probe(r, ["on_start", "on_upgrade", "on_battle", "on_step"]), str(r.get("probe", {})))
	var CR: GDScript = load("res://kit/crowd/crowd_map.gd")
	var c: Dictionary = CR.new_state({"start": 5, "rules": R, "track": [{"d": 1, "t": "gate", "l": "+5", "r": "+5"}, {"d": 2, "t": "boss", "n": 3}]})
	CR.step(c, 0.5)
	check("reglas multitud: on_event cambia la gente", _probe(c, ["on_start", "on_event"]) and int(c["n"]) == 8, str(c["n"]))
	var MB: GDScript = load("res://kit/mergeboard/mergeboard_map.gd")
	var m: Dictionary = MB.new_state({"chains": ["bread"], "energy": 5, "rules": R, "orders": [{"need": [["bread", 2]]}]})
	var a1: Vector2i = MB.tap(m, Vector2i(0, 8))
	var a2: Vector2i = MB.tap(m, Vector2i(0, 8))
	MB.drag(m, a1, a2)
	MB.deliver(m, 0)
	MB.tick(m, 1.0)
	check("reglas pedidos: on_tap, on_merge, on_deliver y on_step", _probe(m, ["on_start", "on_tap", "on_merge", "on_deliver", "on_step"]), str(m.get("probe", {})))
	var WD: GDScript = load("res://kit/wordle/wordle_map.gd")
	var w: Dictionary = WD.new_state({"len": 5, "seed": 3, "rules": R}, "es")
	WD.guess(w, WD.bot_guess(w))
	check("reglas palabra: on_guess", _probe(w, ["on_start", "on_guess"]))
	var LT: GDScript = load("res://kit/letters/letters_map.gd")
	var l: Dictionary = LT.new_state({"len": 4, "words": 3, "seed": 3, "rules": R}, "es")
	LT.submit(l, str(l["b"]["words"][0]))
	check("reglas letras: on_word", _probe(l, ["on_start", "on_word"]))


func _probe(st: Dictionary, keys: Array) -> bool:
	var p: Dictionary = st.get("probe", {})
	for k: Variant in keys:
		if int(p.get(str(k), 0)) <= 0:
			return false
	return true


## Marketing dentro del juego: promocion cruzada y avisos de vuelta propios de cada genero.
func _test_marketing_ingame() -> void:
	print("- Promocion cruzada y avisos de vuelta")
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["cross"] = [{"title": "Imperio Dulce", "url": "https://play.google.com/store/apps/details?id=a"}, {"title": "Malo", "url": "http://x"}, {"title": "", "url": "https://y"}]
	check("cruzada: solo enlaces seguros y con nombre", CrossPanel.games().size() == 1)
	var p: CrossPanel = CrossPanel.open(self)
	await frames(2)
	var b: Button = p.find_child("BtnCross", true, false) as Button
	check("cruzada: un boton por juego", b != null)
	QA.events.clear()
	b.emit_signal("pressed")
	check("cruzada: cada toque se apunta (sin abrir nada en las pruebas)", QA.events.any(func(e: Dictionary) -> bool: return str(e.get("event", "")) == "cross_click"))
	p.queue_free()
	Kit.config.erase("cross")
	check("cruzada: sin juegos, no hay boton", CrossPanel.games().is_empty())
	Kit.config = keep
	Notify.game_reminder = {"content": "Tiradas llenas", "delay": 3600}
	var plan: Array = Notify.plan()
	check("avisos: el aviso propio del juego entra en el plan", plan.any(func(n: Dictionary) -> bool: return int(n["id"]) == 105 and str(n["content"]) == "Tiradas llenas"))
	Notify.game_reminder = {"content": "x", "delay": 30}
	check("avisos: nada de avisos a los pocos segundos", not Notify.plan().any(func(n: Dictionary) -> bool: return int(n["id"]) == 105))
	Notify.game_reminder = {}


## Torre de poder: vencer al mas debil, premios, trampas, perder contra el fuerte, analizador y bot.
func _test_powertower() -> void:
	print("- Torre de poder")
	var M: GDScript = load("res://kit/powertower/powertower_map.gd")
	var lv: Dictionary = {"start": 5, "towers": [[{"t": "enemy", "p": 8}, {"t": "enemy", "p": 3}, {"t": "bonus", "op": "+2"}],
		[{"t": "trap", "op": "-4"}, {"t": "bonus", "op": "x2"}, {"t": "enemy", "p": 20}, {"t": "boss", "p": 30}]]}
	var st: Dictionary = M.new_state(lv)
	check("poder: la segunda torre se abre al limpiar la primera", not M.can_pick(st, 1, 0) and M.can_pick(st, 0, 0))
	var o: Dictionary = M.pick(st, 0, 1)
	check("poder: vencer a uno mas debil suma su poder", bool(o["ok"]) and int(st["p"]) == 8)
	var lose: Dictionary = M.new_state(lv)
	check("poder: contra uno igual o mas fuerte se pierde", not bool(M.pick(lose, 0, 0)["ok"]) and bool(lose["lost"]))
	M.pick(st, 0, 2)
	M.pick(st, 0, 0)
	check("poder: premios y la torre siguiente", int(st["p"]) == 18 and M.can_pick(st, 1, 0))
	var b: Dictionary = M.bot_play(lv)
	check("poder: el bot gana (multiplica cuando hace falta)", bool(b["won"]), str(b))
	check("poder: el analizador acepta un nivel que pide pensar", bool(M.analyze(lv)["completable"]), str(M.analyze(lv)))
	var easy: Dictionary = {"start": 50, "towers": [[{"t": "enemy", "p": 1}, {"t": "boss", "p": 2}]]}
	check("poder: subir sin pensar no puede ganar", not bool(M.analyze(easy)["completable"]))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "powertower"
	Kit.config["levels"] = [lv.merged({"name": "P", "map": ["poder", "#1"]})]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/powertower.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	g.call("tap_room", 0, 1)
	check("poder: tocar una sala en el juego", int(g.get("st")["p"]) == 8)
	g.call("retry")
	var Bot: GDScript = load("res://qa/powertower_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 60 * 20)
	check("poder: el bot gana jugando", won and int(g.get("deaths")) == 0, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Encuentra las diferencias: acertar, fallar, repetir, pista, analizador y bot.
func _test_spotdiff() -> void:
	print("- Diferencias")
	var M: GDScript = load("res://kit/spotdiff/spotdiff_map.gd")
	var scene: Array = []
	for k: int in 9:
		scene.append({"k": "circle", "x": 0.15 + 0.35 * (k % 3), "y": 0.15 + 0.35 * (k / 3), "s": 0.08, "c": "#ff0000"})
	var lv: Dictionary = {"scene": scene, "mistakes": 2, "diffs": [{"i": 0, "how": "color", "v": "#00ff00"},
		{"i": 4, "how": "gone"}, {"i": 8, "how": "move", "v": [-0.06, 0.0]}]}
	var st: Dictionary = M.new_state(lv)
	check("diferencias: la figura cambiada en el dibujo de abajo", str(M.shape_after(lv, 0)["c"]) == "#00ff00" and M.shape_after(lv, 4).is_empty())
	check("diferencias: tocar una diferencia la encuentra", M.tap(st, Vector2(0.16, 0.15)) == 0)
	check("diferencias: tocarla otra vez no cuenta como fallo", M.tap(st, Vector2(0.15, 0.15)) == -2 and int(st["mistakes"]) == 0)
	check("diferencias: tocar donde no hay nada es un fallo", M.tap(st, Vector2(0.5, 0.15)) == -1 and int(st["mistakes"]) == 1)
	check("diferencias: la pista marca una sin encontrar", M.hint(st) == 1 and int(st["hints"]) == 1)
	M.tap(st, Vector2(0.5, 0.15))
	check("diferencias: con los fallos maximos se pierde", bool(st["lost"]))
	check("diferencias: el analizador acepta un buen nivel", bool(M.analyze(lv)["completable"]), str(M.analyze(lv)))
	var bad: Dictionary = {"scene": scene, "diffs": [{"i": 0, "how": "gone"}, {"i": 1, "how": "gone"}, {"i": 1, "how": "flip"}]}
	check("diferencias: el analizador rechaza diferencias repetidas o pegadas", not bool(M.analyze(bad)["completable"]))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "spotdiff"
	Kit.config["levels"] = [lv.merged({"name": "D", "map": ["diferencias", "#1"], "mistakes": 5})]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/spotdiff.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	g.call("tap_at", Vector2(0.15, 0.15))
	check("diferencias: tocar en el juego", int(g.get("coins")) == 1)
	g.call("retry")
	var Bot: GDScript = load("res://qa/spotdiff_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 60 * 20)
	check("diferencias: el bot gana jugando", won and int(g.get("deaths")) == 0, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Rompecabezas: cambiar piezas, piezas fijas, limite de cambios, minimo de cambios, analizador y bot.
func _test_jigsaw() -> void:
	print("- Rompecabezas")
	var M: GDScript = load("res://kit/jigsaw/jigsaw_map.gd")
	var lv: Dictionary = {"size": 3, "order": [1, 0, 2, 4, 5, 3, 8, 6, 7], "moves": 0, "scene": [], "bg": "#cfe8ff", "hero": false}
	check("rompecabezas: minimo de cambios por ciclos", M.min_swaps(lv["order"]) == 5)
	var st: Dictionary = M.new_state(lv)
	check("rompecabezas: una pieza ya en su sitio no se mueve", M.swap(st, 2, 0) == -1 and int(st["moves"]) == 0)
	check("rompecabezas: cambiar dos piezas que se ordenan", M.swap(st, 0, 1) == 2 and M.placed_count(st) == 3)
	var tight: Dictionary = lv.merged({"moves": 2}, true)
	var st2: Dictionary = M.new_state(tight)
	M.swap(st2, 3, 4)
	M.swap(st2, 6, 7)
	check("rompecabezas: sin cambios se pierde", bool(st2["lost"]))
	check("rompecabezas: el analizador acepta un buen nivel", bool(M.analyze(lv)["completable"]), str(M.analyze(lv)))
	check("rompecabezas: el analizador pide margen sobre el minimo", not bool(M.analyze(lv.merged({"moves": 5}, true))["completable"]))
	check("rompecabezas: el analizador rechaza un nivel casi hecho", not bool(M.analyze({"size": 3, "order": [0, 1, 2, 3, 4, 5, 6, 8, 7]})["completable"]))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "jigsaw"
	Kit.config["levels"] = [lv.merged({"name": "J", "map": ["rompecabezas", "#1"]})]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/jigsaw.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	g.call("tap_slot", 0)
	g.call("tap_slot", 1)
	check("rompecabezas: tocar dos piezas las cambia", int(g.get("coins")) == 3)
	g.call("use_hint")
	check("rompecabezas: la pista coloca una pieza", int(g.get("coins")) >= 4 and int(g.get("hints")) == 1)
	g.call("retry")
	var Bot: GDScript = load("res://qa/jigsaw_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 60 * 20)
	check("rompecabezas: el bot gana con el minimo de cambios", won and int(g.get("st")["moves"]) == 5, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Pintar por numeros: pintar, fallos (solo al tocar), cubo, dibujo desde una imagen, analizador y bot.
func _test_paintnum() -> void:
	print("- Pintar por numeros")
	var M: GDScript = load("res://kit/paintnum/paintnum_map.gd")
	var lv: Dictionary = {"cells": ["11111", "12221", "12321", "12221", "11111"], "palette": ["#3498db", "#f1c40f", "#e74c3c"], "fills": 1}
	var st: Dictionary = M.new_state(lv)
	check("pintar: cuadritos por pintar", int(st["left"]) == 25 and M.remaining(st, 2) == 8)
	check("pintar: el color bueno pinta", M.paint(st, 0, 0) == 1 and int(st["left"]) == 24)
	check("pintar: el color equivocado es un fallo", M.paint(st, 2, 2) == -1 and int(st["mistakes"]) == 1)
	check("pintar: arrastrando, el equivocado no cuenta", M.paint(st, 2, 2, false) == -1 and int(st["mistakes"]) == 1)
	M.select(st, 2)
	check("pintar: el cubo pinta todo un color", M.fill(st) == 8 and M.remaining(st, 2) == 0 and int(st["fills"]) == 0)
	check("pintar: el analizador acepta un buen dibujo", bool(M.analyze(lv)["completable"]), str(M.analyze(lv)))
	check("pintar: el analizador rechaza colores sin usar", not bool(M.analyze({"cells": lv["cells"], "palette": ["#000000", "#ffffff", "#ff0000", "#00ff00"]})["completable"]))
	var img: Image = Image.create(20, 20, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	img.fill_rect(Rect2i(4, 4, 12, 12), Color("#e74c3c"))
	img.fill_rect(Rect2i(8, 8, 4, 4), Color("#2ecc71"))
	var pic: Dictionary = M.from_image(img, 12, 4)
	check("pintar: dibujo desde una imagen (recorta y cuenta colores)", (pic["palette"] as Array).size() == 2 and (pic["cells"] as Array).size() == 12, str(pic))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "paintnum"
	Kit.config["levels"] = [lv.merged({"name": "P", "map": ["pintar", "#1"]})]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/paintnum.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	g.call("paint_cell", 0, 0)
	check("pintar: pintar en el juego", int(g.get("coins")) == 1)
	g.call("retry")
	var Bot: GDScript = load("res://qa/paintnum_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 60 * 20)
	check("pintar: el bot pinta el dibujo sin fallos", won and int(g.get("st")["mistakes"]) == 0, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Lanza cuchillos: giro por tramos, clavar, chocar, manzanas, analizador y bot.
func _test_knifehit() -> void:
	print("- Lanza cuchillos")
	var M: GDScript = load("res://kit/knifehit/knifehit_map.gd")
	var lv: Dictionary = {"knives": 3, "stuck": [], "apples": [], "spin": [{"v": 90.0, "d": 1.0}, {"v": -90.0, "d": 1.0}]}
	var st: Dictionary = M.new_state(lv)
	var s: Array = M.spin_after(st, 1.5)
	check("cuchillos: el giro sigue sus tramos (ida y vuelta)", is_equal_approx(float(s[0]), 45.0) and int(s[1]) == 1, str(s))
	M.throw(st)
	for k: int in 7:
		M.step(st, 1.0 / 60.0)
	check("cuchillos: el cuchillo se clava abajo", (st["knives"] as Array).size() == 1 and int(st["thrown"]) == 1, str(st["knives"]))
	M.throw(st)
	for k2: int in 7:
		M.step(st, 1.0 / 60.0)
	check("cuchillos: pegado a otro, choca y se pierde", bool(st["lost"]))
	var la: Dictionary = {"knives": 1, "stuck": [], "apples": [90.0], "spin": [{"v": 0.0, "d": 1.0}, {"v": 60.0, "d": 1.0}]}
	var st2: Dictionary = M.new_state(la)
	M.throw(st2)
	for k3: int in 7:
		M.step(st2, 1.0 / 60.0)
	check("cuchillos: dar a una manzana", int(st2["got"]) == 1 and bool(st2["won"]))
	check("cuchillos: el analizador acepta un tronco que gira", bool(M.analyze(lv)["completable"]), str(M.analyze(lv)))
	check("cuchillos: el analizador rechaza demasiados cuchillos", not bool(M.analyze({"knives": 20, "stuck": [0, 30, 60], "spin": [{"v": 100.0, "d": 1.0}]})["completable"]))
	check("cuchillos: el analizador rechaza un tronco quieto", not bool(M.analyze({"knives": 3, "spin": [{"v": 0.0, "d": 1.0}]})["completable"]))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "knifehit"
	Kit.config["levels"] = [{"name": "K", "map": ["cuchillos", "#1"], "knives": 6, "stuck": [0.0, 180.0], "apples": [45.0], "spin": [{"v": 140.0, "d": 1.0}, {"v": -70.0, "d": 0.8}]}]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/knifehit.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	check("cuchillos: tocar lanza", bool(g.call("throw_knife")))
	g.call("retry")
	var Bot: GDScript = load("res://qa/knifehit_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 60 * 30)
	check("cuchillos: el bot parte el tronco sin chocar", won and int(g.get("deaths")) == 0, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Arquero: disparar quieto, moverse sin disparar, golpes, habilidades, salas, analizador y bot.
func _test_rogue() -> void:
	print("- Arquero")
	var M: GDScript = load("res://kit/rogue/rogue_map.gd")
	var lv: Dictionary = {"seed": 7, "rooms": [{"enemies": [{"k": "slime", "x": 4.5, "y": 6.0}]}, {"enemies": [{"k": "archer", "x": 2.0, "y": 3.0}, {"k": "bat", "x": 7.0, "y": 3.0}]}]}
	var st: Dictionary = M.new_state(lv)
	for k0: int in 13:
		M.step(st, 1.0 / 30.0, Vector2.ZERO)
	check("arquero: quieto, dispara al mas cercano", (st["arrows"] as Array).size() == 1, str((st["arrows"] as Array).size()))
	var st2: Dictionary = M.new_state(lv)
	M.step(st2, 0.5, Vector2(1, 0))
	check("arquero: moviendose no dispara", (st2["arrows"] as Array).is_empty() and (st2["hero"]["p"] as Vector2).x > 4.5)
	for k: int in 120:
		M.step(st, 1.0 / 30.0, Vector2.ZERO)
	check("arquero: limpiar la sala da a elegir 3 habilidades", str(st["phase"]) == "pick" and (st["offer"] as Array).size() == 3, str(st["phase"]))
	var sk: String = str(st["offer"][0])
	check("arquero: elegir habilidad abre la sala siguiente", M.pick(st, sk) and int(st["room"]) == 1 and M.lvl(st, sk) == 1 and (st["enemies"] as Array).size() == 2)
	var st3: Dictionary = M.new_state({"rooms": [{"enemies": [{"k": "slime", "x": 4.5, "y": 12.0}]}]})
	M.step(st3, 1.0 / 30.0, Vector2.ZERO)
	check("arquero: tocar a un enemigo quita vida", float(st3["hero"]["hp"]) < 100.0)
	var st4: Dictionary = M.new_state({"rooms": [{"enemies": [{"k": "archer", "x": 4.5, "y": 2.0}]}]})
	st4["skills"] = {"doble": 1, "diagonal": 1}
	st4["hero"]["cd"] = 0.0
	M.step(st4, 1.0 / 30.0, Vector2.ZERO)
	check("arquero: flecha doble y diagonales", (st4["arrows"] as Array).size() == 4, str((st4["arrows"] as Array).size()))
	check("arquero: el analizador acepta un nivel que el bot gana", bool(M.analyze(lv)["completable"]), str(M.analyze(lv)))
	check("arquero: el analizador rechaza enemigos en la entrada", not bool(M.analyze({"rooms": [{"enemies": [{"k": "slime", "x": 4.5, "y": 12.0}]}]})["completable"]))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "rogue"
	Kit.config["levels"] = [lv.merged({"name": "R", "map": ["arquero", "#1"]})]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/rogue.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	var Bot: GDScript = load("res://qa/rogue_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 60 * 60)
	check("arquero: el bot gana jugando (elige habilidades solo)", won and int(g.get("deaths")) == 0, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Flechas: salir con el camino libre, chocar, vidas, analizador y bot.
func _test_arrows() -> void:
	print("- Flechas")
	var M: GDScript = load("res://kit/arrows/arrows_map.gd")
	## La 0 apunta a la derecha y la 1 (vertical, en su camino) apunta arriba: primero la 1.
	var lv: Dictionary = {"w": 5, "h": 5, "lives": 2, "arrows": [{"x": 1, "y": 2, "d": "r", "n": 2}, {"x": 3, "y": 1, "d": "u", "n": 3},
		{"x": 4, "y": 4, "d": "d", "n": 1}, {"x": 0, "y": 4, "d": "l", "n": 1}]}
	var st: Dictionary = M.new_state(lv)
	check("flechas: el cuerpo va detras de la punta", M.cells_of(st["arrows"][1]) == [Vector2i(3, 1), Vector2i(3, 2), Vector2i(3, 3)])
	check("flechas: otra en el camino la bloquea", M.blocker(st, 0) == 1)
	var r: Dictionary = M.tap(st, 0)
	check("flechas: chocar cuesta una vida", not bool(r["ok"]) and int(st["mistakes"]) == 1 and not bool(st["lost"]))
	check("flechas: con el camino libre sale", bool(M.tap(st, 1)["ok"]) and bool(M.tap(st, 0)["ok"]) and int(st["left"]) == 2)
	var st2: Dictionary = M.new_state(lv)
	M.tap(st2, 0)
	M.tap(st2, 0)
	check("flechas: sin vidas se pierde", bool(st2["lost"]))
	check("flechas: el analizador acepta un tablero con solucion", bool(M.analyze(lv)["completable"]), str(M.analyze(lv)))
	var cyc: Dictionary = {"w": 4, "h": 4, "arrows": [{"x": 1, "y": 0, "d": "d", "n": 1}, {"x": 1, "y": 3, "d": "u", "n": 1},
		{"x": 3, "y": 3, "d": "r", "n": 1}, {"x": 0, "y": 0, "d": "l", "n": 1}]}
	check("flechas: el analizador rechaza flechas que se tapan entre si", not bool(M.analyze(cyc)["completable"]))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "arrows"
	Kit.config["levels"] = [lv.merged({"name": "F", "map": ["flechas", "#1"]})]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/arrows.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	g.call("tap_arrow", 1)
	check("flechas: tocar en el juego", int(g.get("coins")) == 1)
	g.call("retry")
	var Bot: GDScript = load("res://qa/arrows_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 60 * 20)
	check("flechas: el bot vacia el tablero sin chocar", won and int(g.get("st")["mistakes"]) == 0, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## 2048: deslizar y sumar, rocas que cortan, deshacer con el mismo azar, perder, analizador y bot.
func _test_merge2048() -> void:
	print("- 2048")
	var M: GDScript = load("res://kit/merge2048/merge2048_map.gd")
	var lv: Dictionary = {"size": 4, "target": 16, "seed": 5, "start": [[0, 0, 2], [1, 0, 2], [2, 0, 4], [3, 0, 4]]}
	var st: Dictionary = M.new_state(lv)
	var r: Dictionary = M.move(st, "l")
	check("2048: iguales que chocan se suman (2+2, 4+4)", int(st["b"][0]) == 4 and int(st["b"][1]) == 8 and int(r["gain"]) == 12, str(st["b"]))
	check("2048: tras mover sale una ficha nueva", int(r["spawn"]) >= 0)
	var b_after: Array = (st["b"] as Array).duplicate()
	check("2048: deshacer vuelve atras", M.undo(st) and int(st["b"][0]) == 2 and int(st["undo"]) == 1)
	M.move(st, "l")
	check("2048: tras deshacer, la misma ficha nueva (el azar tambien vuelve)", st["b"] == b_after)
	var rk: Dictionary = M.new_state({"size": 4, "target": 64, "seed": 1, "rocks": [[1, 0]], "start": [[0, 0, 2], [3, 0, 2]]})
	M.move(rk, "l")
	check("2048: la roca corta la fila", int(rk["b"][0]) == 2 and int(rk["b"][1]) == M.ROCK and int(rk["b"][2]) == 2, str(rk["b"]))
	var full: Dictionary = M.new_state({"size": 3, "target": 64, "seed": 1, "start": [[0, 0, 2], [1, 0, 4], [2, 0, 8], [0, 1, 16], [1, 1, 32], [2, 1, 2], [0, 2, 4], [1, 2, 8], [2, 2, 16]]})
	check("2048: sin movimientos no se puede mover", not M.can_move(full) and M.move(full, "l").is_empty())
	check("2048: el analizador acepta un objetivo alcanzable", bool(M.analyze({"size": 4, "target": 64, "seed": 3})["completable"]))
	check("2048: el analizador rechaza un objetivo que no cabe", not bool(M.analyze({"size": 3, "target": 2048, "seed": 3, "rocks": [[1, 1], [0, 1], [2, 1]]})["completable"]))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "merge2048"
	Kit.config["levels"] = [{"name": "N", "map": ["numeros", "#1"], "size": 4, "target": 64, "seed": 9}]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/merge2048.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	var moved: bool = bool(g.call("slide", "l")) or bool(g.call("slide", "r"))
	check("2048: deslizar en el juego", moved and int(g.get("st")["moves"]) == 1)
	g.call("retry")
	var Bot: GDScript = load("res://qa/merge2048_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 60 * 30)
	check("2048: el bot llega a la ficha objetivo", won, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Cartas locas: reparto, cartas que valen, efectos (+2, salta, reversa, comodin), robar y bot.
func _test_crazy8() -> void:
	print("- Cartas locas")
	var M: GDScript = load("res://kit/crazy8/crazy8_map.gd")
	check("cartas locas: mazo de 108", M.full_deck().size() == 108)
	## Mazo fijo: reparto alterno (tu: r1 r2 r3, rival: g1 g2 g3), la de la mesa r5, y para robar b9 y4.
	var deck: Array = ["r1", "g1", "r2", "g2", "rD", "g3", "r5", "b9", "y4"]
	var lv: Dictionary = {"players": 2, "hand": 3, "deck": deck}
	var st: Dictionary = M.new_state(lv)
	check("cartas locas: reparto en orden y carta en la mesa", (st["hands"][0] as Array) == ["r1", "r2", "rD"] and M.top(st) == "r5" and str(st["color"]) == "r", str(st["hands"]))
	check("cartas locas: vale el mismo color, no otro", M.playable(st, "r1") and not M.playable(st, "g1") and M.playable(st, "W"))
	check("cartas locas: +2 hace robar 2 y repites turno con 2 jugadores", M.play(st, 2) and (st["hands"][1] as Array).size() == 5 and int(st["turn"]) == 0)
	M.play(st, 0)
	check("cartas locas: el turno pasa al rival", int(st["turn"]) == 1)
	var st2: Dictionary = M.new_state({"players": 3, "hand": 3, "deck": ["rR", "g1", "b1", "rS", "g2", "b2", "r1", "g3", "b3", "r5", "y1", "y2"]})
	M.play(st2, 0)
	check("cartas locas: reversa cambia el sentido", int(st2["dir"]) == -1 and int(st2["turn"]) == 2)
	var st3: Dictionary = M.new_state({"players": 2, "hand": 3, "deck": ["g1", "r1", "g2", "r2", "g3", "r3", "y5", "b7"]})
	var c: String = M.draw_card(st3)
	check("cartas locas: si la robada no vale, pasa el turno", c == "b7" and int(st3["turn"]) == 1 and (st3["hands"][0] as Array).size() == 4, c)
	var r: Dictionary = M.bot_play({"players": 2, "hand": 7, "deck": M.full_deck()})
	check("cartas locas: la partida termina con un ganador", int(r["winner"]) >= 0, str(r))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "crazy8"
	var good: Dictionary = {}
	var full: Array = M.full_deck()
	for k: int in 40:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 100 + k
		var d: Array = full.duplicate()
		for i: int in range(d.size() - 1, 0, -1):
			var j: int = rng.randi_range(0, i)
			var t: Variant = d[i]
			d[i] = d[j]
			d[j] = t
		if bool(M.analyze({"players": 2, "hand": 7, "deck": d})["completable"]):
			good = {"players": 2, "hand": 7, "deck": d}
			break
	check("cartas locas: hay mazos con los que el bot gana", not good.is_empty())
	Kit.config["levels"] = [good.merged({"name": "C", "map": ["cartas_locas", "#1"]})]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/crazy8.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	var Bot: GDScript = load("res://qa/crazy8_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 60 * 30)
	check("cartas locas: el bot gana la partida", won, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Reglas vivas (capa 2 en los generos de escena): mandos que el juego lee, eventos contados y bots.
func _test_live_rules() -> void:
	print("- Reglas vivas (plataformas, hordas, torres, carreras...)")
	var cfg: Dictionary = test_config(["..........", "..P.C.C..G", "##########"])
	cfg["rules"] = ["res://qa/rule_live_probe.gd"]
	var game: Node = await start_game(cfg, 0)
	await frames(3)
	check("reglas vivas: arrancan en plataformas", not Mods.live.is_empty() and str(Mods.live.get("genre", "")) == "platformer")
	check("reglas vivas: on_start pone un mando", is_equal_approx(Mods.tune("jump"), 1.15) and is_equal_approx(Mods.tune("speed"), 1.0))
	check("reglas vivas: un mando desconocido se quita", not (Mods.live["tune"] as Dictionary).has("no_existe"))
	check("reglas vivas: on_step en cada fotograma", int((Mods.live["data"] as Dictionary).get("pasos", 0)) > 0)
	QA.log_event("coin", {})
	check("reglas vivas: los eventos llegan (on_coin) y se cuentan", is_equal_approx(Mods.tune("speed"), 1.1) and int(Mods.live["stats"].get("coin", 0)) >= 1)
	QA.log_event("probe_limite", {})
	check("reglas vivas: los mandos no pasan de su limite", is_equal_approx(Mods.tune("enemy_speed"), 2.5))
	var player: Node = game.get("player")
	var j0: float = float(player.get("jump_velocity"))
	player.call("_do_jump")
	check("reglas vivas: el heroe salta con el mando", is_equal_approx(float(player.get("velocity").y), j0 * 1.15))
	await stop_game(game)
	game = await start_game(cfg, 0)
	var done: bool = await QaBot.run(get_tree(), game, 60 * 30)
	check("reglas vivas: el bot sigue ganando con la regla puesta", done)
	await stop_game(game)
	Mods.live = {}
	var plain: Dictionary = test_config(["..........", "..P......G", "##########"])
	game = await start_game(plain, 0)
	await frames(2)
	check("reglas vivas: sin reglas, todo a 1", Mods.live.is_empty() and Mods.tune("speed") == 1.0)
	await stop_game(game)
	Kit.set_config(base_config)
	## Generos sin mandos propios: solo la velocidad de la partida (y la serpiente sigue jugandose).
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "snake"
	Kit.config["rules"] = ["res://qa/rule_speed_probe.gd"]
	Kit.config["levels"] = [{"name": "S", "map": ["S"], "w": 10, "h": 14, "goal": 3, "speed": 6.0, "seed": 3}]
	Kit.level_index = 0
	QA.log_event("level_start", {"level": 0, "genre": "snake"})
	check("reglas vivas: la serpiente (sin mandos propios) solo cambia la velocidad", not Mods.live.is_empty() and is_equal_approx(Engine.time_scale, 0.8)
		and is_equal_approx(Mods.tune("jump"), 1.3))
	QA.log_event("level_complete", {"level": 0})
	check("reglas vivas: al acabar el nivel, velocidad normal", Mods.live.is_empty() and is_equal_approx(Engine.time_scale, 1.0))
	Kit.config["genre"] = "tycoon"
	QA.log_event("level_start", {"level": 0, "genre": "tycoon"})
	check("reglas vivas: los generos con simulacion propia no las duplican", Mods.live.is_empty())
	Kit.config = keep
	Kit.set_config(base_config)


## Domino: reparto, salida con el doble mas alto, encajar en las puntas, robar, cierre y bot.
func _test_domino() -> void:
	print("- Domino")
	var M: GDScript = load("res://kit/domino/domino_map.gd")
	check("domino: 28 fichas", M.full_set().size() == 28)
	## Tu: 6-6 1-2 0-3; rival: 5-5 6-1 2-2; pozo: 4-4 3-4 ...
	var deck: Array = [[6, 6], [5, 5], [1, 2], [6, 1], [0, 3], [2, 2], [4, 4], [3, 4], [0, 0], [0, 1], [0, 2], [1, 1], [1, 3], [1, 4], [1, 5], [1, 6], [2, 3], [2, 4], [2, 5], [2, 6], [3, 3], [3, 5], [3, 6], [4, 5], [4, 6], [5, 6], [0, 4], [0, 5]]
	var st: Dictionary = M.new_state({"players": 2, "hand": 3, "deck": deck})
	check("domino: sale el doble mas alto (6-6, tuyo) y le toca al rival", (st["chain"] as Array) == [[6, 6]] and int(st["turn"]) == 1 and (st["hands"][0] as Array).size() == 2, str(st["chain"]))
	check("domino: encaja por la punta", M.fits(st, [6, 1]) == ["l", "r"] and M.fits(st, [5, 5]).is_empty())
	check("domino: el rival juega 6-1 y la punta queda en 1", M.play(st, 1, "r") and int(st["right"]) == 1 and int(st["left"]) == 6)
	check("domino: tu 1-2 casa por la derecha", M.fits(st, [1, 2]) == ["r"])
	M.play(st, 0, "r")
	check("domino: punta nueva 2", int(st["right"]) == 2 and int(st["turn"]) == 1)
	check("domino: no se puede robar si puedes jugar", not M.draw(st) and M.play(st, 1, "r"))
	var r: Dictionary = M.bot_play({"players": 3, "hand": 7, "deck": M.full_set()})
	check("domino: la partida acaba con un ganador", int(r["winner"]) >= 0, str(r))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "domino"
	var good: Dictionary = {}
	var full: Array = M.full_set()
	for k: int in 60:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 300 + k
		var d: Array = full.duplicate(true)
		for i: int in range(d.size() - 1, 0, -1):
			var j: int = rng.randi_range(0, i)
			var t: Variant = d[i]
			d[i] = d[j]
			d[j] = t
		if bool(M.analyze({"players": 2, "hand": 7, "deck": d})["completable"]):
			good = {"players": 2, "hand": 7, "deck": d}
			break
	check("domino: hay mazos con los que el bot gana", not good.is_empty())
	Kit.config["levels"] = [good.merged({"name": "D", "map": ["domino", "#1"]})]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/domino.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	var Bot: GDScript = load("res://qa/domino_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 60 * 30)
	check("domino: el bot gana la partida", won, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Bloques de colores: moverse por los huecos, salir por la puerta de su color si cabe, analizador y bot.
func _test_blockjam() -> void:
	print("- Bloques de colores")
	var M: GDScript = load("res://kit/blockjam/blockjam_map.gd")
	## Rojo (0) 1x1 en (0,2) con puerta roja arriba en x=0; azul (1) 2x1 en (1,0) tapa? no: azul sale a la derecha.
	var lv: Dictionary = {"w": 4, "h": 4, "colors": ["#ff0000", "#0000ff"], "walls": [[2, 2]],
		"doors": [{"side": "t", "at": 0, "len": 1, "c": 0}, {"side": "r", "at": 0, "len": 1, "c": 1}],
		"blocks": [{"c": 0, "x": 0, "y": 2, "cells": [[0, 0]]}, {"c": 1, "x": 0, "y": 0, "cells": [[0, 0], [1, 0]]}, {"c": 0, "x": 3, "y": 3, "cells": [[0, 0]]}]}
	var st: Dictionary = M.new_state(lv)
	check("bloques: no atraviesa a otro bloque", M.step(st, 0, "r") == "move" and M.step(st, 0, "u") == "move" and M.step(st, 0, "u") == "")
	check("bloques: no atraviesa muros", M.step(st, 2, "u") == "move" and M.step(st, 2, "l") == "")
	var st2: Dictionary = M.new_state(lv)
	check("bloques: el rojo no sale mientras el azul tapa la columna", M.path_out(st2, 0).is_empty())
	check("bloques: el azul sale por la derecha", M.path_out(st2, 1).size() == 3)
	M.step(st2, 1, "r")
	M.step(st2, 1, "r")
	check("bloques: sale por su puerta y deja hueco", M.step(st2, 1, "r") == "out" and int(st2["left"]) == 2 and not M.path_out(st2, 0).is_empty())
	var wide: Dictionary = {"w": 4, "h": 4, "doors": [{"side": "t", "at": 0, "len": 1, "c": 0}],
		"blocks": [{"c": 0, "x": 0, "y": 0, "cells": [[0, 0], [1, 0]]}, {"c": 0, "x": 2, "y": 2, "cells": [[0, 0]]}, {"c": 0, "x": 3, "y": 3, "cells": [[0, 0]]}]}
	check("bloques: si no cabe por la puerta, no sale", M.path_out(M.new_state(wide), 0).is_empty() and not bool(M.analyze(wide)["completable"]))
	check("bloques: el analizador acepta un tablero con solucion", bool(M.analyze(lv)["completable"]), str(M.analyze(lv)))
	check("bloques: el analizador pide pasos suficientes", not bool(M.analyze(lv.merged({"moves": 3}, true))["completable"]))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "blockjam"
	Kit.config["levels"] = [lv.merged({"name": "B", "map": ["bloques_colores", "#1"]})]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/blockjam.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	check("bloques: mover en el juego", str(g.call("move_block", 1, "r")) == "move")
	g.call("retry")
	var Bot: GDScript = load("res://qa/blockjam_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 60 * 20)
	check("bloques: el bot vacia el tablero", won, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Tuberias: girar, el agua llega por tuberias que casan, fugas, analizador y bot.
func _test_pipes() -> void:
	print("- Tuberias")
	var M: GDScript = load("res://kit/pipes/pipes_map.gd")
	check("tuberias: girar 90 grados (arriba -> derecha, recta -> recta)", M.rot(1) == 2 and M.rot(8) == 1 and M.rot(M.rot(5)) == 5)
	## 2x2: grifo arriba-izquierda; solucion: (0,0) derecha+abajo, (1,0) izquierda+abajo, (0,1) arriba, (1,1) arriba.
	var sol: Array = [6, 12, 1, 1]
	var lv: Dictionary = {"w": 2, "h": 2, "src": [0, 0], "sol": sol, "tiles": [3, 12, 4, 2], "taps": 0}
	var st: Dictionary = M.new_state(lv)
	check("tuberias: desordenado no llega a todas", not bool(st["won"]) and (st["wet"] as Dictionary).size() < 4)
	check("tuberias: minimo de giros", M.min_taps(lv) == 1 + 0 + 2 + 3, str(M.min_taps(lv)))
	var c: Vector2i = M.bot_move(st, sol)
	while c.x >= 0 and not bool(st["won"]):
		M.tap(st, c)
		c = M.bot_move(st, sol)
	check("tuberias: con la solucion, el agua llega a todas sin fugas", bool(st["won"]) and int(st["taps"]) == 6)
	var leak: Dictionary = M.new_state({"w": 2, "h": 2, "src": [0, 0], "tiles": [7, 12, 1, 1]})
	check("tuberias: una tuberia abierta al borde es una fuga", not bool(leak["won"]))
	check("tuberias: el analizador acepta un tablero con solucion", bool(M.analyze(lv)["completable"]), str(M.analyze(lv)))
	check("tuberias: el analizador pide giros suficientes", not bool(M.analyze(lv.merged({"taps": 6}, true))["completable"]))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "pipes"
	Kit.config["levels"] = [lv.merged({"name": "T", "map": ["tuberias", "#1"]})]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/pipes.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	g.call("tap_cell", Vector2i(0, 0))
	check("tuberias: tocar gira la pieza en el juego", int(g.get("st")["tiles"][0]) == 6)
	g.call("retry")
	var Bot: GDScript = load("res://qa/pipes_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 60 * 20)
	check("tuberias: el bot conecta todo", won, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Ajedrez: movimientos legales, jaque, mate, coronar, ventaja, analizador y bot en el juego.
func _test_chess() -> void:
	print("- Ajedrez")
	var M: GDScript = load("res://kit/chess/chess_map.gd")
	var st: Dictionary = M.new_state({})
	check("ajedrez: 20 jugadas legales al empezar", M.legal_moves(st["b"], true).size() == 20)
	## Mate del pastor: e4 e5 Ac4 Cc6 Dh5 Cf6 Dxf7#
	var seq: Array = [[52, 36], [12, 28], [61, 34], [1, 18], [59, 31], [6, 21], [31, 13]]
	for m: Variant in seq:
		M.play(st, m)
	check("ajedrez: mate del pastor = ganas", bool(st["won"]) and not bool(st["lost"]) and int(st["plies"]) == 7)
	var st2: Dictionary = M.new_state({})
	check("ajedrez: una jugada ilegal no se hace", not M.play(st2, [52, 28]) and int(st2["plies"]) == 0)
	## Rey blanco clavado: no puede ponerse en jaque.
	var b: Array = []
	b.resize(64)
	b.fill("")
	b[60] = "K"
	b[4] = "k"
	b[3] = "r"
	var km: Array = []
	for m2: Variant in M.legal_moves(b, true):
		km.append(int(m2[1]))
	check("ajedrez: el rey no entra en jaque", not km.has(59) and not km.has(51) and km.has(61))
	## Coronar: el peon que llega arriba es dama.
	var b2: Array = b.duplicate()
	b2[3] = ""
	b2[8] = "P"
	check("ajedrez: el peon corona dama", M.apply(b2, [8, 0])[0] == "Q")
	var hc: Dictionary = M.new_state({"quitar": ["q", "r"]})
	check("ajedrez: ventaja quita piezas al rival", not (hc["b"] as Array).has("q") and (hc["b"] as Array).count("r") == 1 and (hc["b"] as Array).has("k"))
	var lv: Dictionary = {"rival": 1, "quitar": ["q", "r"], "seed": 3, "mistake": 0.2}
	check("ajedrez: el analizador acepta un rival que se puede ganar", bool(M.analyze(lv)["completable"]), str(M.analyze(lv)))
	check("ajedrez: el analizador rechaza ventajas raras", not bool(M.analyze({"rival": 1, "quitar": ["k"]})["completable"]))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "chess"
	Kit.config["levels"] = [lv.merged({"name": "T", "map": ["ajedrez", "#1"]})]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/chess.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	g.call("tap_cell", Vector2i(4, 6))
	g.call("tap_cell", Vector2i(4, 4))
	check("ajedrez: tocar pieza y casilla mueve", str(g.get("st")["b"][36]) == "P" and not bool(g.get("st")["white"]))
	g.call("retry")
	var Bot: GDScript = load("res://qa/chess_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 60 * 60)
	check("ajedrez: el bot da jaque mate", won, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Reversi: jugadas de salida, dar la vuelta, pasar, final, ventaja, analizador y bot en el juego.
func _test_reversi() -> void:
	print("- Reversi")
	var M: GDScript = load("res://kit/reversi/reversi_map.gd")
	var st: Dictionary = M.new_state({})
	check("reversi: 4 jugadas al empezar", M.moves(st["b"], 8, 1).size() == 4)
	check("reversi: casilla que no encierra nada no vale", not M.play(st, 0) and int(st["plies"]) == 0)
	check("reversi: poner da la vuelta a la encerrada", M.play(st, 19) and int(st["b"][27]) == 1 and M.count(st["b"], 1) == 4 and int(st["turn"]) == 2)
	## Pasar: el rival no tiene jugada y vuelves a jugar tu.
	var b: Array = []
	b.resize(36)
	b.fill(0)
	b[0] = 1
	b[1] = 2
	b[3] = 2
	b[4] = 1
	var ps: Dictionary = M.new_state({"size": 6})
	ps["b"] = b
	check("reversi: si ninguno puede, se acaba y gana quien tiene mas", M.play(ps, 2) and bool(ps["won"]) and M.count(ps["b"], 1) == 5)
	var bonus: Dictionary = M.new_state({"size": 6, "bonus": 2})
	check("reversi: ventaja = esquinas tuyas", int(bonus["b"][0]) == 1 and int(bonus["b"][35]) == 1 and int(bonus["n"]) == 6)
	var lv: Dictionary = {"size": 6, "rival": 1, "mistake": 0.3, "seed": 3}
	check("reversi: el analizador acepta un rival que se puede ganar", bool(M.analyze(lv)["completable"]), str(M.analyze(lv)))
	check("reversi: el analizador rechaza tableros raros", not bool(M.analyze({"size": 7})["completable"]))
	check("reversi: el analizador rechaza partidas que acaban enseguida", (M.analyze({"size": 6, "rival": 1, "mistake": 0.3, "bonus": 1, "seed": 3})["issues"] as Array).has("reversi_too_short"))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "reversi"
	Kit.config["levels"] = [lv.merged({"name": "T", "map": ["reversi", "#1"]})]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/reversi.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	g.call("tap_cell", Vector2i(2, 1))
	check("reversi: tocar una casilla marcada pone ficha", int(g.get("st")["plies"]) == 1 and int(g.get("st")["b"][8]) == 1)
	g.call("retry")
	var Bot: GDScript = load("res://qa/reversi_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 60 * 60)
	check("reversi: el bot gana la partida", won, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	## Reto del dia con un nivel nuevo: se juega igual y no deja estrellas en el progreso.
	Kit.extra_level = lv.merged({"seed": 5, "name": "R"})
	Kit.extra_index = 1
	Kit.level_index = 1
	var stars_before: int = Save.stars_for("1")
	Save.progress().get("stars", {}).erase("1")
	var g2: Node = (load("res://scenes/reversi.tscn") as PackedScene).instantiate()
	add_child(g2)
	await frames(2)
	var won2: bool = await Bot.run(get_tree(), g2, 60 * 60)
	check("reto del dia: una partida de verdad con el nivel extra, sin estrellas guardadas", won2 and int(g2.get("st")["n"]) == 6
		and Save.stars_for("1") == 0, str(g2.call("bot_state")))
	if stars_before > 0:
		Save.progress()["stars"]["1"] = stars_before
	if g2.get("result_panel") != null:
		(g2.get("result_panel") as Node).queue_free()
	g2.queue_free()
	await frames(2)
	Kit.extra_level = {}
	Kit.extra_index = -1
	Kit.config = keep
	Kit.level_index = 0


## Buscar objetos: tocar encuentra, fallar cuenta, tiempo, pistas, gemelas, tapadas, bot en el juego.
func _test_hidden() -> void:
	print("- Buscar objetos")
	var M: GDScript = load("res://kit/hidden/hidden_map.gd")
	var shapes: Array = [{"k": "tree", "x": 0.2, "y": 0.2, "s": 0.12, "c": "#2ecc71"}, {"k": "fish", "x": 0.7, "y": 0.3, "s": 0.1, "c": "#3498db"},
		{"k": "cup", "x": 0.4, "y": 0.7, "s": 0.1, "c": "#e74c3c"}, {"k": "star", "x": 0.8, "y": 0.8, "s": 0.1, "c": "#f1c40f"},
		{"k": "rock", "x": 0.2, "y": 0.2, "s": 0.06, "c": "#888888"}]
	var lv: Dictionary = {"shapes": shapes, "targets": [1, 2, 3], "time": 0, "misses": 3, "hints": 1}
	var st: Dictionary = M.new_state(lv)
	check("buscar: tocar una de la lista la encuentra", M.tap(st, Vector2(0.71, 0.31)) == "found" and (st["found"] as Array) == [1])
	check("buscar: tocar otra cosa es un fallo", M.tap(st, Vector2(0.2, 0.2)) == "miss" and int(st["misses"]) == 1)
	check("buscar: la pista senala una que falta", M.use_hint(st) == 2 and int(st["hints"]) == 0 and M.use_hint(st) == -1)
	M.tap(st, Vector2(0.4, 0.7))
	M.tap(st, Vector2(0.8, 0.8))
	check("buscar: encontrar todas gana", bool(st["won"]))
	var st2: Dictionary = M.new_state(lv)
	for k: int in 3:
		M.tap(st2, Vector2(0.05, 0.95))
	check("buscar: demasiados fallos pierde", bool(st2["lost"]))
	var st3: Dictionary = M.new_state(lv.merged({"time": 20}, true))
	M.step(st3, 21.0)
	check("buscar: se acaba el tiempo", bool(st3["lost"]))
	check("buscar: el analizador acepta una escena justa", bool(M.analyze(lv)["completable"]), str(M.analyze(lv)))
	var twin: Dictionary = lv.duplicate(true)
	(twin["shapes"] as Array).append({"k": "fish", "x": 0.1, "y": 0.9, "s": 0.1})
	check("buscar: no puede haber dos de la que se busca", (M.analyze(twin)["issues"] as Array).has("hidden_not_unique"))
	var lookalike: Dictionary = lv.duplicate(true)
	(lookalike["shapes"] as Array)[3] = {"k": "tri", "x": 0.8, "y": 0.8, "s": 0.1}
	(lookalike["shapes"] as Array).append({"k": "kite", "x": 0.1, "y": 0.9, "s": 0.1})
	check("buscar: ni una que se dibuja igual (triangulo y cometa)", (M.analyze(lookalike)["issues"] as Array).has("hidden_not_unique"))
	var hidden: Dictionary = lv.duplicate(true)
	(hidden["shapes"] as Array).append({"k": "house", "x": 0.7, "y": 0.3, "s": 0.2})
	check("buscar: ni una tapada por otra", (M.analyze(hidden)["issues"] as Array).has("hidden_covered"))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "hidden"
	Kit.config["levels"] = [lv.merged({"name": "T", "map": ["buscar", "#1"]})]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/hidden.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	g.call("tap_at", Vector2(0.4, 0.7))
	check("buscar: tocar en el juego encuentra", int(g.get("coins")) == 1)
	g.call("retry")
	var Bot: GDScript = load("res://qa/hidden_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 60 * 20)
	check("buscar: el bot las encuentra todas", won, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Puzle de deslizar: deslizar una y varias, tocar fuera de linea, paridad, solucion, limite y bot.
func _test_slide() -> void:
	print("- Puzle de deslizar")
	var M: GDScript = load("res://kit/slide/slide_map.gd")
	## 3x3 resuelto salvo los dos ultimos: hueco en 6, piezas 6 y 7 corridas.
	var lv: Dictionary = {"n": 3, "tiles": [0, 1, 2, 3, 4, 5, 8, 6, 7], "sol": [7, 8], "moves": 0}
	var st: Dictionary = M.new_state(lv)
	check("deslizar: tocar fuera de la fila o columna del hueco no hace nada", M.tap(st, 4) == 0 and int(st["moves"]) == 0)
	check("deslizar: tocar en linea mueve varias de golpe", M.tap(st, 8) == 2 and bool(st["won"]) and int(st["moves"]) == 2)
	check("deslizar: paridad (un cambio suelto no tiene solucion)", not M.solvable([1, 0, 2, 3, 4, 5, 6, 7, 8], 3) and M.solvable([0, 1, 2, 3, 4, 5, 6, 8, 7], 3))
	check("deslizar: paridad en 4x4", M.solvable([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 15, 14], 4) and not M.solvable([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 12, 14, 15], 4))
	check("deslizar: el analizador acepta un tablero con solucion", bool(M.analyze({"n": 3, "tiles": [8, 0, 2, 3, 1, 5, 6, 4, 7], "sol": [1, 4, 7, 8]})["completable"]),
		str(M.analyze({"n": 3, "tiles": [8, 0, 2, 3, 1, 5, 6, 4, 7], "sol": [1, 4, 7, 8]})))
	check("deslizar: el analizador rechaza tableros imposibles", (M.analyze({"n": 3, "tiles": [1, 0, 2, 3, 4, 5, 6, 7, 8], "sol": []})["issues"] as Array).has("slide_unsolvable"))
	var lim: Dictionary = M.new_state({"n": 3, "tiles": [8, 0, 2, 3, 1, 5, 6, 4, 7], "moves": 2})
	M.tap(lim, 3)
	M.tap(lim, 0)
	check("deslizar: sin movimientos se pierde", bool(lim["lost"]))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "slide"
	Kit.config["levels"] = [{"name": "T", "n": 3, "tiles": [8, 0, 2, 3, 1, 5, 6, 4, 7], "sol": [1, 4, 7, 8], "moves": 0, "map": ["deslizar", "#1"]}]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/slide.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	g.call("tap_slot", 1)
	check("deslizar: tocar en el juego desliza", int(g.get("st")["tiles"][0]) == 0 and int(g.get("st")["moves"]) == 1)
	g.call("retry")
	var Bot: GDScript = load("res://qa/slide_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 60 * 20)
	check("deslizar: el bot recompone el dibujo", won, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Ahorcado con globos: acertar, fallar, repetir, pista, perder, idiomas, analizador y bot en el juego.
func _test_hangman() -> void:
	print("- Ahorcado")
	var M: GDScript = load("res://kit/hangman/hangman_map.gd")
	var lv: Dictionary = {"len": 5, "lives": 6, "rank": 0.2, "hint": 1, "map": ["ahorcado", "#11"]}
	var st: Dictionary = M.new_state(lv, "es")
	var w: String = str(st["word"])
	check("ahorcado: palabra del diccionario y del largo pedido", w.length() == 5 and M.shown(st) == "_____")
	check("ahorcado: la misma semilla da la misma palabra", str(M.new_state(lv, "es")["word"]) == w and str(M.new_state(lv, "es", 1)["word"]) != w)
	var hit: String = w[0]
	check("ahorcado: acertar destapa todas las de esa letra", M.guess(st, hit) == "hit" and M.shown(st).count(hit) == w.count(hit))
	check("ahorcado: repetir una letra no cuenta", M.guess(st, hit) == "")
	var miss: String = ""
	for ch: String in "ZXQWKJVY":
		if not w.contains(ch):
			miss = ch
			break
	check("ahorcado: fallar revienta un globo", M.guess(st, miss) == "miss" and int(st["misses"]) == 1)
	var h: String = M.use_hint(st)
	check("ahorcado: la pista destapa una que falta", h != "" and w.contains(h) and int(st["hints"]) == 0)
	var st2: Dictionary = M.new_state(lv.merged({"lives": 3}, true), "es")
	var k: int = 0
	for ch2: String in "ZXQWKJVYHF":
		if not str(st2["word"]).contains(ch2):
			M.guess(st2, ch2)
			k += 1
		if k >= 3:
			break
	check("ahorcado: sin globos se pierde", bool(st2["lost"]))
	check("ahorcado: palabra distinta en cada idioma", str(M.new_state(lv, "en")["word"]) != w and str(M.new_state(lv, "de")["word"]).length() == 5)
	check("ahorcado: el analizador lo prueba en los 6 idiomas", M.analyze(lv).has("worst"), str(M.analyze(lv)))
	check("ahorcado: el analizador rechaza largos raros", not bool(M.analyze({"len": 12})["completable"]))
	var ok_lv: Dictionary = lv
	for s: int in 30:
		var cand: Dictionary = lv.merged({"map": ["ahorcado", "#%d" % (40 + s)]}, true)
		if bool(M.analyze(cand)["completable"]):
			ok_lv = cand
			break
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "hangman"
	Kit.config["levels"] = [ok_lv.merged({"name": "T"})]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/hangman.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	var word2: String = str(g.get("st")["word"])
	g.call("press", word2[0])
	check("ahorcado: tocar una tecla juega la letra", (g.get("st")["guessed"] as Dictionary).has(word2[0]))
	g.call("retry")
	var Bot: GDScript = load("res://qa/hangman_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 60 * 20)
	check("ahorcado: el bot adivina la palabra", won, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Hundir la flota: flotas sin tocarse, agua/tocado/hundido, repetir al tocar, turnos, cazador, analizador y bot.
func _test_battle() -> void:
	print("- Hundir la flota")
	var M: GDScript = load("res://kit/battle/battle_map.gd")
	var lv: Dictionary = {"n": 7, "ships": [3, 2, 2], "rival": 0, "mistake": 0.0, "seed": 9}
	var st: Dictionary = M.new_state(lv)
	var theirs: Array = st["theirs"]
	var cells: int = 0
	var touching: bool = false
	for i: int in 49:
		if int(theirs[i]) > 0:
			cells += 1
			for d: int in [1, 7]:
				var j: int = i + d
				if j < 49 and (d == 7 or j / 7 == i / 7) and int(theirs[j]) > 0 and int(theirs[j]) != int(theirs[i]):
					touching = true
	check("buques: la flota completa y sin barcos pegados", cells == 7 and not touching and (st["mine"] as Array).count(0) == 42)
	var water: int = theirs.find(0)
	check("buques: agua pasa el turno", M.fire(st, water) == "water" and int(st["turn"]) == 2)
	check("buques: no se dispara dos veces al mismo sitio", M.fire(st, (st["mine"] as Array).find(0)) == "water" and int(st["turn"]) == 1 and M.fire(st, water) == "")
	var ship2: Array = []
	for i2: int in 49:
		if int(theirs[i2]) == 2:
			ship2.append(i2)
	check("buques: tocado repite turno", M.fire(st, int(ship2[0])) == "hit" and int(st["turn"]) == 1)
	check("buques: hundido al dar a todo el barco", M.fire(st, int(ship2[1])) == "sunk" and M.fleet_left(theirs, st["shots_mine"], st["ships"]) == 2)
	var h: Dictionary = M.new_state(lv)
	var t3: Array = []
	for i3: int in 49:
		if int(h["theirs"][i3]) == 1:
			t3.append(i3)
	M.fire(h, int(t3[0]))
	var next: int = M.bot_shot(h)
	check("buques: el cazador dispara al lado de lo tocado", absi(next - int(t3[0])) == 1 or absi(next - int(t3[0])) == 7)
	check("buques: el analizador acepta un rival al que se gana", bool(M.analyze(lv)["completable"]), str(M.analyze(lv)))
	check("buques: el analizador rechaza flotas que no caben", not bool(M.analyze({"n": 5, "ships": [4, 4, 4]})["completable"]))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "battle"
	Kit.config["levels"] = [lv.merged({"name": "T", "map": ["flota", "#1"]})]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/battle.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	g.call("shoot", 0)
	check("buques: tocar el mar del rival dispara", (g.get("st")["shots_mine"] as Dictionary).has(0))
	g.call("retry")
	var Bot: GDScript = load("res://qa/battle_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 60 * 60)
	check("buques: el bot hunde la flota del rival", won, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Simon dice: secuencia fija por semilla, acertar, ronda, fallo que repite, perder, analizador y bot.
func _test_simon() -> void:
	print("- Simon dice")
	var M: GDScript = load("res://kit/simon/simon_map.gd")
	var lv: Dictionary = {"pads": 4, "goal": 3, "lives": 1, "speed": 0.5, "seed": 5}
	var st: Dictionary = M.new_state(lv)
	var seq: Array = st["seq"]
	check("simon: secuencia del largo objetivo y la misma con la misma semilla", seq.size() == 3 and (M.new_state(lv)["seq"] as Array) == seq)
	check("simon: ronda 1 es una luz", M.current(st).size() == 1 and M.press(st, int(seq[0])) == "round" and int(st["round"]) == 2)
	var wrong: int = (int(seq[0]) + 1) % 4
	check("simon: fallar repite la ronda (si quedan fallos)", M.press(st, wrong) == "miss" and int(st["pos"]) == 0 and int(st["round"]) == 2)
	M.press(st, int(seq[0]))
	M.press(st, int(seq[1]))
	M.press(st, int(seq[0]))
	M.press(st, int(seq[1]))
	check("simon: llegar al objetivo gana", M.press(st, int(seq[2])) == "won" and bool(st["won"]))
	var st2: Dictionary = M.new_state(lv)
	M.press(st2, (int(seq[0]) + 1) % 4)
	check("simon: sin fallos que perdonar se pierde", M.press(st2, (int(seq[0]) + 1) % 4) == "lost" and bool(st2["lost"]))
	check("simon: nunca tres iguales seguidos", (func() -> bool:
		var long: Array = M.new_state({"pads": 3, "goal": 20, "seed": 77})["seq"]
		for k: int in range(2, long.size()):
			if long[k] == long[k - 1] and long[k] == long[k - 2]:
				return false
		return true).call())
	check("simon: el analizador acepta un nivel normal y rechaza luces demasiado rapidas", bool(M.analyze(lv)["completable"]) and not bool(M.analyze(lv.merged({"speed": 0.1}, true))["completable"]))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "simon"
	Kit.config["levels"] = [lv.merged({"name": "T", "map": ["simon", "#1"]})]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/simon.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	check("simon: empieza ensenando la secuencia (no se puede tocar)", str(g.get("phase")) == "show" and not bool(g.call("can_act")))
	var Bot: GDScript = load("res://qa/simon_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 60 * 30)
	check("simon: el bot repite todas las rondas", won, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Estrategia por turnos: movimiento por terreno, ataque y contraataque, artilleria, captura en 2 turnos,
## curas en ciudades, IA, analizador y bot jugando el nivel entero en la escena.
func _test_tactics() -> void:
	print("- Estrategia por turnos")
	var M: GDScript = load("res://kit/tactics/tactics_map.gd")
	var lv: Dictionary = {"tiles": ["..h..", ".....", ".fm..", ".....", "..H.."], "turns": 20, "ai": 0.3,
		"units": [{"t": "inf", "x": 1, "y": 4, "side": 1}, {"t": "tank", "x": 3, "y": 4, "side": 1}, {"t": "art", "x": 2, "y": 3, "side": 1},
			{"t": "inf", "x": 2, "y": 1, "side": 2}, {"t": "tank", "x": 0, "y": 0, "side": 2}, {"t": "inf", "x": 4, "y": 0, "side": 2}]}
	var st: Dictionary = M.new_state(lv)
	var inf: Dictionary = M.unit_by_id(st, 1)
	var r: Dictionary = M.reach(st, inf)
	check("estrategia: el bosque cuesta y la infanteria no llega mas alla de su movimiento", r.has(Vector2i(1, 2)) and not r.has(Vector2i(1, 0)) and M.reach(st, inf).size() > 4)
	var tank: Dictionary = M.unit_by_id(st, 2)
	check("estrategia: el tanque no sube montanas", not M.reach(st, tank).has(Vector2i(2, 2)))
	check("estrategia: no se mueve una unidad del rival ni dos veces", not M.move(st, 4, Vector2i(2, 0)) and M.move(st, 2, Vector2i(3, 1)) and not M.move(st, 2, Vector2i(3, 3)))
	var art: Dictionary = M.unit_by_id(st, 3)
	var foe: Dictionary = M.unit_by_id(st, 4)
	check("estrategia: la artilleria dispara de lejos sin moverse y no hay contraataque", M.attack(st, 3, 4) and int(foe["hp"]) < 10 and int(art["hp"]) == 10)
	var hp_t: int = int(tank["hp"])
	M.attack(st, 2, 4)
	check("estrategia: cuerpo a cuerpo, contraataque si sobrevive", int(foe["hp"]) <= 0 or int(tank["hp"]) < hp_t)
	var st2: Dictionary = M.new_state({"tiles": ["..h..", ".....", ".....", ".....", "..H.."], "turns": 20,
		"units": [{"t": "inf", "x": 2, "y": 0, "side": 1}, {"t": "tank", "x": 0, "y": 4, "side": 2}]})
	M.end_turn(st2)
	check("estrategia: capturar el cuartel cuesta dos turnos", not bool(st2["won"]) and int((st2["caps"] as Dictionary)[Vector2i(2, 0)]["pts"]) == 10)
	M.end_turn(st2)
	M.end_turn(st2)
	check("estrategia: al segundo turno, cuartel capturado = victoria", bool(st2["won"]))
	var st3: Dictionary = M.new_state({"tiles": ["..h..", ".....", "..c..", ".....", "..H.."], "turns": 20,
		"units": [{"t": "inf", "x": 2, "y": 2, "side": 1}, {"t": "tank", "x": 0, "y": 0, "side": 2}]})
	(st3["owner"] as Dictionary)[Vector2i(2, 2)] = 1
	M.unit_by_id(st3, 1)["hp"] = 5
	M.end_turn(st3)
	M.end_turn(st3)
	check("estrategia: las ciudades propias curan", int(M.unit_by_id(st3, 1)["hp"]) == 7)
	check("estrategia: el analizador acepta un mapa en el que se gana", bool(M.analyze(lv)["completable"]), str(M.analyze(lv)))
	check("estrategia: el analizador pide cuarteles", (M.analyze({"tiles": [".....", ".....", ".....", ".....", "....."], "units": []})["issues"] as Array).has("tactics_no_hq"))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "tactics"
	Kit.config["levels"] = [lv.merged({"name": "T", "map": ["estrategia"]})]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/tactics.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	g.call("tap_cell", Vector2i(1, 4))
	check("estrategia: tocar una unidad la elige y ensena sus casillas", int(g.get("selected")) == 1 and not (g.get("_reach") as Dictionary).is_empty())
	g.call("tap_cell", Vector2i(1, 3))
	check("estrategia: tocar una casilla azul la mueve", int(M.unit_by_id(g.get("st"), 1)["y"]) == 3)
	g.call("retry")
	var Bot: GDScript = load("res://qa/tactics_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 60 * 90)
	check("estrategia: el bot gana la batalla en la escena", won, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Batalla automatica: tienda, compra, fundir tres iguales, colocar, huecos, vender, combate y bot.
func _test_autochess() -> void:
	print("- Batalla automatica")
	var M: GDScript = load("res://kit/autochess/autochess_map.gd")
	var lv: Dictionary = {"rounds": [[{"t": "warrior", "s": 1, "x": 2, "y": 3}], [{"t": "warrior", "s": 1, "x": 2, "y": 3}, {"t": "archer", "s": 1, "x": 3, "y": 0}]],
		"lives": 3, "gold": 6, "slots": 3, "seed": 4}
	var st: Dictionary = M.new_state(lv)
	check("auto: oro de la primera ronda y 5 en la tienda", int(st["gold"]) == 6 and (st["shop"] as Array).size() == 5)
	st["shop"] = ["warrior", "warrior", "warrior", "archer", "knight"]
	st["gold"] = 20
	M.buy(st, 0)
	M.buy(st, 1)
	check("auto: comprar va al banquillo y cuesta", (st["bench"] as Array).size() == 2 and int(st["gold"]) == 18)
	M.buy(st, 2)
	check("auto: tres iguales se funden en una de 2 estrellas", (st["bench"] as Array).size() == 1 and int(st["bench"][0]["s"]) == 2)
	var id: int = int(st["bench"][0]["id"])
	check("auto: solo se coloca en tu mitad", not M.place(st, id, Vector2i(2, 1)) and M.place(st, id, Vector2i(2, 5)) and (st["board"] as Array).size() == 1)
	M.buy(st, 3)
	M.buy(st, 4)
	var ids: Array = []
	for u: Variant in st["bench"]:
		ids.append(int(u["id"]))
	M.place(st, int(ids[0]), Vector2i(1, 7))
	M.place(st, int(ids[1]), Vector2i(3, 4))
	st["shop"] = ["mage", "", "", "", ""]
	M.buy(st, 0)
	check("auto: no caben mas que los huecos del tablero", not M.place(st, int(st["bench"][0]["id"]), Vector2i(4, 6)))
	var g0: int = int(st["gold"])
	check("auto: vender devuelve el oro", M.sell(st, int(st["bench"][0]["id"])) and int(st["gold"]) == g0 + 2)
	var fs: Array = M.fighters(st)
	check("auto: combate con tus unidades y las del rival", fs.size() == 4 and M.simulate(fs) == 1)
	check("auto: el analizador acepta un nivel que se gana", bool(M.analyze(lv)["completable"]), str(M.analyze(lv)))
	check("auto: el analizador rechaza rivales en tu mitad", (M.analyze({"rounds": [[{"t": "warrior", "x": 0, "y": 6}], []]})["issues"] as Array).has("autochess_bad_enemy"))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "autochess"
	Kit.config["levels"] = [lv.merged({"name": "T", "map": ["autobatalla", "#1"]})]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/autochess.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	var gold0: int = int(g.get("st")["gold"])
	var first: String = str(g.get("st")["shop"][0])
	g.call("buy", 0)
	check("auto: tocar una carta de la tienda la compra", (g.get("st")["bench"] as Array).size() == 1 and int(g.get("st")["gold"]) == gold0 - int(M.TYPES[first]["cost"]))
	g.call("retry")
	var Bot: GDScript = load("res://qa/autochess_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 60 * 90)
	check("auto: el bot gana todas las rondas en la escena", won, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Gemas y heroes: sin lineas al empezar, cambio sin linea no vale, romper y caer, ataque con ventaja
## de color, curas, cuenta atras del monstruo, especiales, oleadas, analizador y bot en la escena.
func _test_gemrpg() -> void:
	print("- Gemas y heroes")
	var M: GDScript = load("res://kit/gemrpg/gemrpg_map.gd")
	var lv: Dictionary = {"team": [{"c": 0, "atk": 12, "skill": "blast"}, {"c": 1, "atk": 10, "skill": "heal"}, {"c": 2, "atk": 11, "skill": "stun"}],
		"hp": 200, "seed": 7, "waves": [[{"c": 2, "hp": 60, "atk": 10, "every": 2}], [{"c": 0, "hp": 80, "atk": 12, "every": 3}, {"c": 1, "hp": 50, "atk": 8, "every": 2}]]}
	var st: Dictionary = M.new_state(lv)
	check("gemas: el tablero empieza sin lineas", M.matches(st["board"]).is_empty() and (st["board"] as Array).size() == 49)
	check("gemas: ventaja de color (fuego gana a naturaleza)", M.advantage(0, 2) > 1.0 and M.advantage(2, 0) < 1.0 and M.advantage(3, 4) > 1.0)
	var moves: Array = M.valid_swaps(st["board"])
	check("gemas: hay jugadas posibles", not moves.is_empty())
	var bad: Array = []
	for i: int in 48:
		if i % 7 == 6:
			continue
		if not moves.has([i, i + 1]):
			bad = [i, i + 1]
			break
	var b0: Array = (st["board"] as Array).duplicate()
	check("gemas: un cambio sin linea no vale y se deshace", bad.is_empty() or (M.swap(st, int(bad[0]), int(bad[1])).is_empty() and (st["board"] as Array) == b0))
	var hp_e: int = int(st["enemies"][0]["hp"])
	var r: Dictionary = {}
	for m: Variant in moves:
		var sim: Dictionary = M.new_state(lv)
		var rr: Dictionary = M.swap(sim, int(m[0]), int(m[1]))
		if int(rr["counts"][0]) > 0:
			st = sim
			r = rr
			break
	check("gemas: romper fuego hace atacar al heroe de fuego (y el tablero se rellena)", not r.is_empty() and (int(st["wave"]) > 0 or int(st["enemies"][0]["hp"]) < hp_e) and (r["hits"] as Array).size() > 0 and M.matches(st["board"]).is_empty()
		and not (st["board"] as Array).has(-1))
	var st2: Dictionary = M.new_state(lv)
	st2["team"][0]["charge"] = M.CHARGE
	check("gemas: especial de golpe con la carga llena", M.use_skill(st2, 0) and int(st2["team"][0]["charge"]) == 0 and int(st2["wave"]) == 1)
	st2["hp"] = 50
	st2["team"][1]["charge"] = M.CHARGE
	M.use_skill(st2, 1)
	check("gemas: especial de cura", int(st2["hp"]) == 130)
	check("gemas: sin carga no hay especial", not M.use_skill(st2, 2))
	check("gemas: el analizador acepta una batalla que se gana", bool(M.analyze(lv)["completable"]), str(M.analyze(lv)))
	check("gemas: el analizador pide oleadas", (M.analyze({"team": lv["team"], "waves": []})["issues"] as Array).has("gemrpg_no_waves"))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "gemrpg"
	Kit.config["levels"] = [lv.merged({"name": "T", "map": ["gemas", "#1"]})]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/gemrpg.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	var mv: Array = M.valid_swaps(g.get("st")["board"])
	g.call("try_swap", int(mv[0][0]), int(mv[0][1]))
	check("gemas: cambiar en la escena juega el turno", int(g.get("st")["moves"]) == 1)
	g.call("retry")
	var Bot: GDScript = load("res://qa/gemrpg_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 60 * 60)
	check("gemas: el bot gana todas las oleadas en la escena", won, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Cartas coleccionables: mana, robar, jugar esbirros, carga, provocar, escudo, hechizos con objetivo,
## atacar y contraataque, fatiga, IA, analizador y bot en la escena.
func _test_ccg() -> void:
	print("- Cartas coleccionables")
	var M: GDScript = load("res://kit/ccg/ccg_map.gd")
	var deck: Array = ["recluta", "recluta", "lobo", "escudero", "arquera", "arquera", "guardia", "jinete", "paladin", "ogro", "chispa", "chispa", "bola_fuego", "pocion", "estudio", "bendicion", "muro", "tormenta", "jinete", "ogro"]
	var lv: Dictionary = {"deck": deck, "foe_deck": deck, "hp": 25, "foe_hp": 15, "ai": 0.3, "seed": 11}
	var st: Dictionary = M.new_state(lv)
	check("cartas: mano inicial y 1 de mana el primer turno", (st["p"][1]["hand"] as Array).size() == 4 and int(st["p"][1]["mana"]) == 1 and int(st["side"]) == 1)
	st["p"][1]["hand"] = ["lobo", "recluta", "chispa", "escudero"]
	check("cartas: no se juega lo que no se puede pagar", not M.play(st, 3))
	check("cartas: el lobo (carga) ataca el mismo turno", M.play(st, 0) and M.attack(st, int(st["p"][1]["board"][0]["uid"]), {"hero": true}) and int(st["p"][2]["hp"]) == 13)
	M.end_turn(st)
	check("cartas: el turno del rival sube su mana", int(st["side"]) == 2 and int(st["p"][2]["max_mana"]) == 1)
	st["p"][2]["board"] = [{"uid": 900, "id": "escudero", "atk": 1, "hp": 3, "max": 3, "kw": "taunt", "ready": false, "shield": false}]
	M.end_turn(st)
	st["p"][1]["board"][0]["ready"] = true
	check("cartas: provocar obliga a atacarle", not M.attack(st, int(st["p"][1]["board"][0]["uid"]), {"hero": true}) and (M.attack_targets(st, 1) as Array).size() == 1)
	var lobo: Dictionary = st["p"][1]["board"][0]
	M.attack(st, int(lobo["uid"]), st["p"][2]["board"][0])
	check("cartas: atacar a un esbirro, y el contraataque", int(st["p"][2]["board"][0]["hp"]) == 1 and (st["p"][1]["board"] as Array).is_empty())
	st["p"][1]["hand"] = ["chispa"]
	st["p"][1]["mana"] = 2
	check("cartas: hechizo de dano con objetivo", M.play(st, 0, st["p"][2]["board"][0]) and (st["p"][2]["board"] as Array).is_empty())
	var sh: Dictionary = {"uid": 901, "id": "paladin", "atk": 3, "hp": 4, "max": 4, "kw": "shield", "ready": false, "shield": true}
	st["p"][2]["board"] = [sh]
	st["p"][1]["hand"] = ["chispa"]
	st["p"][1]["mana"] = 2
	M.play(st, 0, sh)
	check("cartas: el escudo anula el primer golpe", int(sh["hp"]) == 4 and not bool(sh["shield"]))
	var fat: Dictionary = M.new_state(lv)
	fat["p"][1]["deck"] = []
	var hp0: int = int(fat["p"][1]["hp"])
	M.draw(fat, 1)
	M.draw(fat, 1)
	check("cartas: sin mazo, la fatiga hace dano creciente", int(fat["p"][1]["hp"]) == hp0 - 3)
	check("cartas: el analizador acepta un duelo que se gana", bool(M.analyze(lv)["completable"]), str(M.analyze(lv)))
	check("cartas: el analizador pide mazos de 10 a 30", (M.analyze({"deck": ["lobo"], "foe_deck": deck})["issues"] as Array).has("ccg_deck_size"))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "ccg"
	Kit.config["levels"] = [lv.merged({"name": "T", "map": ["cartas_heroes", "#1"]})]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/ccg.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	g.get("st")["p"][1]["hand"] = ["recluta"]
	g.call("tap", (g.call("_card", 0, 1) as Rect2).get_center())
	check("cartas: tocar una carta en la escena la juega", (g.get("st")["p"][1]["board"] as Array).size() == 1)
	g.call("retry")
	var Bot: GDScript = load("res://qa/ccg_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 60 * 120)
	check("cartas: el bot gana el duelo en la escena", won, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Roguelike por turnos: leer el mapa, niebla, chocar ataca, monstruos que despiertan y pegan,
## objetos, pociones, regeneracion, jefe que guarda la escalera, analizador y bot en la escena.
func _test_crawl() -> void:
	print("- Roguelike por turnos")
	var M: GDScript = load("res://kit/crawl/crawl_map.gd")
	var map: Array = ["##########", "#P.!.....#", "#.##.###.#", "#.#r..#..#", "#.#...#/.#", "#.####...#", "#.....]..#", "######.###", "#....B>..#", "##########"]
	var lv: Dictionary = {"map": map, "hp": 60, "atk": 6, "def": 0, "sight": 5, "potions": 1}
	var st: Dictionary = M.new_state(lv)
	check("roguelike: salida, escalera, monstruos y objetos leidos del mapa", st["p"] == Vector2i(1, 1) and st["stairs"] == Vector2i(6, 8)
		and (st["mons"] as Array).size() == 2 and (st["items"] as Dictionary).size() == 3)
	check("roguelike: niebla (se ve lo cercano, no lo de detras de los muros)", (st["seen"] as Dictionary).has(Vector2i(3, 1)) and not (st["seen"] as Dictionary).has(Vector2i(6, 8)))
	check("roguelike: un muro no se atraviesa", not M.step(st, Vector2i(0, -1)))
	M.step(st, Vector2i(1, 0))
	M.step(st, Vector2i(1, 0))
	check("roguelike: pisar una pocion la recoge", int(st["potions"]) == 2 and not (st["items"] as Dictionary).has(Vector2i(3, 1)))
	var st2: Dictionary = M.new_state({"map": ["#######", "#P.r..#", "#######", "#.....#", "#>....#", "#######"], "hp": 10, "atk": 3})
	M.step(st2, Vector2i(1, 0))
	check("roguelike: el monstruo despierto viene y pega", int(st2["hp"]) < 10 and bool(st2["mons"][0]["awake"]))
	M.step(st2, Vector2i(1, 0))
	check("roguelike: chocar con un monstruo le ataca (y muere)", int(st2["mons"][0]["hp"]) <= 0 and int(st2["xp"]) == 1)
	st2["hp"] = 5
	for k: int in 8:
		M.rest(st2)
	check("roguelike: se recupera vida poco a poco", int(st2["hp"]) == 6)
	check("roguelike: la pocion cura", M.drink(st2) == false or int(st2["hp"]) > 6)
	var boss: Dictionary = M.new_state({"map": ["#######", "#P>..B#", "#######"], "hp": 99, "atk": 30})
	M.step(boss, Vector2i(1, 0))
	check("roguelike: con el jefe vivo la escalera no vale", boss["p"] == Vector2i(2, 1) and not bool(boss["won"]))
	for k2: int in 6:
		if not M.mon_at(boss, boss["p"] + Vector2i(1, 0)).is_empty():
			M.step(boss, Vector2i(1, 0))
		else:
			M.rest(boss)
	M.step(boss, Vector2i(-1, 0))
	M.step(boss, Vector2i(1, 0))
	check("roguelike: vencido el jefe, la escalera gana", bool(boss["won"]), str(boss["p"]))
	check("roguelike: el analizador acepta una mazmorra que se puede bajar", bool(M.analyze(lv)["completable"]), str(M.analyze(lv)))
	check("roguelike: el analizador pide escalera", (M.analyze({"map": ["##########"].duplicate() + ["#P.......#"].duplicate() + ["#........#", "#........#", "#........#", "#........#", "#........#", "##########"]})["issues"] as Array).has("crawl_no_stairs"))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "crawl"
	Kit.config["levels"] = [lv.merged({"name": "T"})]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/crawl.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	g.call("tap_cell", Vector2i(1, 1))
	check("roguelike: tocar a tu heroe espera un turno", int(g.get("st")["turn"]) == 1)
	g.call("retry")
	var Bot: GDScript = load("res://qa/crawl_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 60 * 60)
	check("roguelike: el bot baja la escalera en la escena", won, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Bombas: leer el mapa, poner bomba, explosion en cruz que rompe la primera caja y destapa,
## reaccion en cadena, monstruos que mueren en las llamas, vidas y escudo, salida cerrada hasta
## vencer a todos, analizador y bot en la escena.
func _test_bomber() -> void:
	print("- Bombas")
	var M: GDScript = load("res://kit/bomber/bomber_map.gd")
	var st: Dictionary = M.new_state({"map": ["#######", "#P..+X#", "#.#.#.#", "#.....#", "#######"], "range": 2})
	check("bombas: salida, cajas y salida escondida leidas del mapa", st["p"] == Vector2i(1, 1) and M.cell(st, Vector2i(5, 1)) == "+"
		and (st["hidden"] as Dictionary).get(Vector2i(5, 1), "") == "X")
	st["p"] = Vector2i(3, 1)
	M.tick(st, Vector2i.ZERO, true)
	check("bombas: poner una bomba", (st["bombs"] as Array).size() == 1)
	M.tick(st, Vector2i.ZERO, true)
	check("bombas: no mas bombas que las que llevas", (st["bombs"] as Array).size() == 1)
	M.tick(st, Vector2i(0, 1), false)
	M.tick(st, Vector2i(0, 1), false)
	M.tick(st, Vector2i(0, 1), false)
	M.tick(st, Vector2i(0, 1), false)
	M.tick(st, Vector2i(1, 0), false)
	M.tick(st, Vector2i(1, 0), false)
	M.tick(st, Vector2i(1, 0), false)
	M.tick(st, Vector2i(1, 0), false)
	check("bombas: el heroe anda y no atraviesa bloques", st["p"] == Vector2i(4, 3), str(st["p"]))
	while not (st["bombs"] as Array).is_empty():
		M.tick(st, Vector2i.ZERO, false)
	check("bombas: la explosion rompe la primera caja (y no la de detras)", M.cell(st, Vector2i(4, 1)) == "." and M.cell(st, Vector2i(5, 1)) == "+")
	check("bombas: las llamas van en cruz y no pasan los bloques", (st["flames"] as Dictionary).has(Vector2i(1, 1)) and (st["flames"] as Dictionary).has(Vector2i(3, 3)) and not (st["flames"] as Dictionary).has(Vector2i(5, 1)))
	check("bombas: tras una esquina no te pasa nada", not bool(st["lost"]) and int(st["lives"]) == 3)
	var ch: Dictionary = M.new_state({"map": ["#########", "#P......#", "#########"], "range": 3})
	ch["bombs"] = [{"p": Vector2i(2, 1), "t": 1, "r": 3}, {"p": Vector2i(5, 1), "t": 20, "r": 1}]
	ch["p"] = Vector2i(7, 1)
	M.tick(ch, Vector2i.ZERO, false)
	check("bombas: una explosion hace estallar otras bombas (cadena)", (ch["bombs"] as Array).is_empty() and (ch["flames"] as Dictionary).has(Vector2i(6, 1)))
	var en: Dictionary = M.new_state({"map": ["#########", "#P....e.#", "#########"], "range": 3, "lives": 2})
	en["bombs"] = [{"p": Vector2i(5, 1), "t": 1, "r": 3}]
	en["enemies"][0]["cd"] = 99
	M.tick(en, Vector2i.ZERO, false)
	check("bombas: el monstruo muere en las llamas", M.enemies_left(en) == 0 and int(en["kills"]) == 1)
	var dd: Dictionary = M.new_state({"map": ["#######", "#P.e..#", "#######"], "lives": 2})
	dd["enemies"][0]["cd"] = 99
	M.tick(dd, Vector2i(1, 0), false)
	M.tick(dd, Vector2i(1, 0), false)
	M.tick(dd, Vector2i(1, 0), false)
	M.tick(dd, Vector2i(1, 0), false)
	check("bombas: tocar un monstruo quita una vida y vuelves a la salida con escudo", int(dd["lives"]) == 1 and dd["p"] == Vector2i(1, 1) and int(dd["shield"]) > 0, str(dd["p"]))
	var ex: Dictionary = M.new_state({"map": ["#######", "#P.X.e#", "#######"], "range": 1})
	ex["enemies"][0]["cd"] = 999
	ex["bombs"] = [{"p": Vector2i(2, 1), "t": 1, "r": 1}]
	ex["p"] = Vector2i(1, 1)
	ex["shield"] = 99
	M.tick(ex, Vector2i.ZERO, false)
	check("bombas: la salida aparece al romper su caja", ex["exit"] == Vector2i(3, 1))
	for k2: int in 8:
		M.tick(ex, Vector2i.ZERO, false)
	for k3: int in 5:
		M.tick(ex, Vector2i(1, 0), false)
	check("bombas: con monstruos vivos la salida no vale", not bool(ex["won"]) and ex["p"] == Vector2i(3, 1))
	ex["enemies"][0]["alive"] = false
	M.tick(ex, Vector2i.ZERO, false)
	check("bombas: sin monstruos, pisar la salida gana", bool(ex["won"]))
	var lv: Dictionary = {"map": ["###########", "#P..+.+...#", "#.#.#+#.#.#", "#..+..+..+#", "#.#.#.#+#.#", "#+..e+..X.#", "#.#+#.#.#.#",
		"#...+..+.e#", "###########"], "range": 2, "bombs": 1, "par": 80}
	check("bombas: el analizador acepta un nivel que el bot gana", bool(M.analyze(lv)["completable"]), str(M.analyze(lv)))
	check("bombas: el analizador pide una salida", (M.analyze({"map": ["#######", "#P...e#", "#.#.#.#", "#.....#", "#.#.#.#", "#.....#", "#.#.#.#", "#######"]})["issues"] as Array).has("bomber_exit"))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "bomber"
	Kit.config["levels"] = [lv.merged({"name": "T"})]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/bomber.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	g.call("drop_bomb")
	await frames(10)
	check("bombas: el boton pone la bomba en la escena", (g.get("st")["bombs"] as Array).size() == 1)
	g.call("retry")
	var Bot: GDScript = load("res://qa/bomber_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 60 * 60)
	check("bombas: el bot gana el nivel en la escena", won, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Artilleria: terreno y soldados del nivel, trayectoria con gravedad y viento, crater que baja el
## suelo, dano por distancia (tambien a los tuyos), ahogarse, andar con limite, turnos alternos,
## IA que apunta, analizador y bot en la escena.
func _test_artillery() -> void:
	print("- Artilleria")
	var M: GDScript = load("res://kit/artillery/artillery_map.gd")
	var flat: Array = []
	for x: int in M.W:
		flat.append(40)
	var lv: Dictionary = {"ground": flat, "team": [20, 30], "foes": [90, 100], "hp": 100, "foe_hp": 60, "wind": 0.0, "ai": 0.3, "seed": 3}
	var st: Dictionary = M.new_state(lv)
	check("artilleria: dos equipos de pie en el suelo y empieza el tuyo", M.alive(st, 1).size() == 2 and M.alive(st, 2).size() == 2
		and int(st["side"]) == 1 and M.unit_pos(st, M.active_unit(st)) == Vector2(20.5, 40.0))
	var s1: Dictionary = M.simulate(st, Vector2(20.5, 40), 45.0, 0.6, 0.0)
	var s2: Dictionary = M.simulate(st, Vector2(20.5, 40), 45.0, 0.6, 15.0)
	check("artilleria: el disparo cae por la gravedad y el viento lo lleva", str(s1["hit"]) == "ground" and (s2["end"] as Vector2).x > (s1["end"] as Vector2).x + 3.0)
	var g0: float = float(st["ground"][60])
	M.fire(st, 45.0, sqrt(40.0 * M.GRAV) / M.VMAX)
	check("artilleria: la explosion hace un crater", float(st["ground"][60]) < g0 or float(st["ground"][59]) < g0 or float(st["ground"][61]) < g0, str(st["ground"].slice(55, 66)))
	check("artilleria: despues dispara el rival", int(st["side"]) == 2)
	var dm: Dictionary = M.blast_damage(st, M.unit_pos(st, st["units"][2]) + Vector2(0, 2))
	check("artilleria: un impacto directo quita mucha vida y lejos nada", int(dm.get(2, 0)) >= 50 and not dm.has(0))
	var self_st: Dictionary = M.new_state(lv)
	var hp0: int = int(self_st["units"][0]["hp"])
	M.fire(self_st, 90.0, 0.3)
	check("artilleria: tu propio disparo tambien te hace dano", int(self_st["units"][0]["hp"]) < hp0)
	var w: Dictionary = M.new_state(lv)
	var walked: int = 0
	for k: int in 40:
		if M.walk(w, -1):
			walked += 1
	check("artilleria: se anda poco en cada turno", walked == M.WALK and int(w["units"][0]["x"]) == 20 - M.WALK, str(w["units"][0]["x"]))
	var cliff: Array = flat.duplicate()
	cliff[21] = 60
	var c: Dictionary = M.new_state(lv.merged({"ground": cliff}, true))
	check("artilleria: un muro alto no se sube andando", not M.walk(c, 1))
	var pit: Array = flat.duplicate()
	for x2: int in range(26, 35):
		pit[x2] = 6
	var dr: Dictionary = M.new_state(lv.merged({"ground": pit}, true))
	M._crater(dr, Vector2(30.5, 6.0))
	M._settle(dr)
	check("artilleria: si el suelo cae al agua, el soldado se ahoga", not bool(dr["units"][1]["alive"]) and bool(dr["units"][0]["alive"]), str(dr["ground"].slice(26, 35)))
	var ai: Dictionary = M.new_state(lv.merged({"ai": 1.0}, true))
	ai["side"] = 2
	ai["active"] = 2
	var b: Dictionary = M.best_shot(ai)
	var r: Dictionary = M.fire(ai, float(b["angle"]), float(b["power"]))
	check("artilleria: la IA sabe apuntar a tus soldados", not (r["hits"] as Dictionary).is_empty() and ((r["hits"] as Dictionary).has(0) or (r["hits"] as Dictionary).has(1)), str(r["hits"]))
	check("artilleria: el analizador acepta una batalla que el bot gana", bool(M.analyze(lv)["completable"]), str(M.analyze(lv)))
	check("artilleria: el analizador rechaza soldados en el agua", (M.analyze(lv.merged({"ground": pit, "team": [30]}, true))["issues"] as Array).has("artillery_unit_in_water"))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "artillery"
	Kit.config["levels"] = [lv.merged({"name": "T"})]
	Kit.level_index = 0
	var gm: Node = (load("res://scenes/artillery.tscn") as PackedScene).instantiate()
	add_child(gm)
	await frames(50)
	gm.call("walk", 1)
	check("artilleria: las flechas mueven a tu soldado", int(gm.get("st")["units"][0]["x"]) == 21)
	gm.call("shoot", 50.0, 0.7)
	check("artilleria: disparar pasa el turno al rival", int(gm.get("st")["side"]) == 2)
	gm.call("retry")
	var Bot: GDScript = load("res://qa/artillery_bot.gd")
	var won: bool = await Bot.run(get_tree(), gm, 60 * 60)
	check("artilleria: el bot gana la batalla en la escena", won, str(gm.call("bot_state")))
	if gm.get("result_panel") != null:
		(gm.get("result_panel") as Node).queue_free()
	gm.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Comecocos: leer el mapa, girar cuando se puede (y recordarlo), comer puntos, tunel de lado a
## lado, fantasmas que salen y persiguen, pildora que los asusta y se comen, vidas, ganar,
## analizador (sin callejones) y bot en la escena.
func _test_chomp() -> void:
	print("- Comecocos")
	var M: GDScript = load("res://kit/chomp/chomp_map.gd")
	var map: Array = ["#########", "#o.....o#", "#.##.##.#", "#.......#", "#.##G##.#", "#.P.....#", "#########"]
	var st: Dictionary = M.new_state({"map": map, "speed": 0.5, "ghost_speed": 0.4})
	check("comecocos: puntos, pildoras, salida y casa del fantasma leidos del mapa", st["p"] == Vector2i(2, 5) and (st["dots"] as Dictionary).size() == 25
		and (st["ghosts"] as Array).size() == 1)
	M.tick(st, Vector2i(0, -1))
	M.tick(st, Vector2i.ZERO)
	check("comecocos: contra un muro no se mueve (y se recuerda el giro)", st["p"] == Vector2i(2, 5) and st["want"] == Vector2i(0, -1))
	M.tick(st, Vector2i(1, 0))
	M.tick(st, Vector2i.ZERO)
	check("comecocos: andar se come el punto", st["p"] == Vector2i(3, 5) and not (st["dots"] as Dictionary).has(Vector2i(3, 5)) and int(st["score"]) == 10)
	var tn: Dictionary = M.new_state({"map": ["#####", "#.G.#", "#####", "P....", "#####"], "speed": 1.0, "ghost_speed": 0.0})
	M.tick(tn, Vector2i(-1, 0))
	check("comecocos: el tunel lleva al otro lado", tn["p"] == Vector2i(4, 3), str(tn["p"]))
	var ch: Dictionary = M.new_state({"map": ["#########", "#.......#", "#.#####.#", "#G.....P#", "#########"], "speed": 0.0001, "ghost_speed": 1.0})
	for k: int in 160:
		M.tick(ch, Vector2i.ZERO)
		if int(ch["deaths"]) > 0:
			break
	check("comecocos: el fantasma te persigue y te quita una vida", int(ch["lives"]) == 2 and ch["p"] == ch["start"] and int(ch["shield"]) > 0)
	var pw: Dictionary = M.new_state({"map": ["#########", "#.......#", "#.#####.#", "#G....oP#", "#########"], "speed": 1.0, "ghost_speed": 0.5, "fright": 40})
	M.tick(pw, Vector2i(-1, 0))
	check("comecocos: la pildora asusta a los fantasmas", int(pw["fright"]) > 0 and M.frightened(pw, pw["ghosts"][0]))
	for k2: int in 12:
		M.tick(pw, Vector2i(-1, 0))
	check("comecocos: un fantasma asustado se come y vuelve a casa", int(pw["lives"]) == 3 and int(pw["score"]) >= 200, str(pw["score"]))
	var win: Dictionary = M.new_state({"map": ["#####", "#P..#", "#####"], "speed": 1.0, "ghost_speed": 0.0})
	M.tick(win, Vector2i(1, 0))
	M.tick(win, Vector2i(1, 0))
	check("comecocos: sin puntos, ganas", bool(win["won"]))
	var lv: Dictionary = {"map": ["###############", "#o...........o#", "#.###.#.#.###.#", "#...#.....#...#", "#.#.#.#.#.#.#.#", "#.............#",
		"#.###########.#", "#.............#", "#####.#.#.#####", "#....GG.G....#", "#.#.###.###.#.#", "#.............#", "#.###.#.#.###.#",
		"#.#.........#.#", "#.#.#.#.#.#.#.#", "#...#..P..#...#", "#.#.#.#.#.#.#.#", "#o...........o#", "###############"], "speed": 0.5, "ghost_speed": 0.38}
	lv["map"][9] = "#....GG.G.....#"
	check("comecocos: el analizador acepta un laberinto que el bot limpia", bool(M.analyze(lv)["completable"]), str(M.analyze(lv)))
	check("comecocos: el analizador rechaza callejones sin salida", (M.analyze({"map": ["#######", "#P....#", "#.###.#", "#.#G..#", "#######"]})["issues"] as Array).has("chomp_dead_end"))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "chomp"
	Kit.config["levels"] = [lv.merged({"name": "T"})]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/chomp.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	g.call("steer", Vector2i(1, 0))
	await frames(20)
	check("comecocos: deslizar mueve al heroe en la escena", (g.get("st")["p"] as Vector2i).x > 7, str(g.get("st")["p"]))
	g.call("retry")
	var Bot: GDScript = load("res://qa/chomp_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 60 * 60)
	check("comecocos: el bot limpia el laberinto en la escena", won, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Cadena de bolas: leer el nivel, la cadena avanza por el camino, meter una bola entre otras,
## tres del mismo color explotan, el hueco se cierra (y si se juntan iguales, vuelve atras y
## encadena), llegar al agujero pierde, cambiar de bola, analizador y bot en la escena.
func _test_chain() -> void:
	print("- Cadena de bolas")
	var M: GDScript = load("res://kit/chain/chain_map.gd")
	var path: Array = [50, 100, 550, 100, 550, 300, 50, 300, 50, 500, 550, 500, 550, 700, 50, 700]
	var lv: Dictionary = {"path": path, "shooter": [300, 400], "balls": [0, 0, 1, 1, 2, 2, 0, 1, 2, 0, 1, 1, 2, 0, 0, 1, 2, 2, 0, 1], "colors": 3, "speed": 0.7, "intro": 0.0, "seed": 1}
	var st: Dictionary = M.new_state(lv)
	check("cadena: camino, bolas y lanzador leidos del nivel", is_equal_approx(float(st["len"]), 2600.0) and M.balls_left(st) == 20)
	M.tick(st)
	check("cadena: la cadena avanza por el camino", float(st["segs"][0]["s"]) > 0.0)
	var s2: Dictionary = M.new_state(lv.merged({"balls": [2, 1, 1, 2, 2, 0]}, true))
	s2["segs"][0]["s"] = 700.0
	var b1: Vector2 = M.at(s2, 700.0 - M.D * 1.0)
	s2["cur"] = 1
	var r: Dictionary = M.fire(s2, b1 - (s2["shooter"] as Vector2))
	check("cadena: tres del mismo color explotan", int(r["popped"]) == 3 and M.balls_left(s2) == 4, str(s2["segs"]))
	check("cadena: el hueco deja dos trozos", (s2["segs"] as Array).size() == 2)
	for k: int in 120:
		M.tick(s2)
		if (s2["segs"] as Array).size() == 1 or bool(s2["won"]):
			break
	check("cadena: con iguales frente a frente, la de delante vuelve y encadena", M.balls_left(s2) == 1 and int(s2["popped"]) == 6, str(s2["segs"]))
	var s3: Dictionary = M.new_state(lv.merged({"balls": [0, 1, 2, 0, 1, 2]}, true))
	s3["segs"][0]["s"] = 700.0
	s3["cur"] = 2
	var b2: Vector2 = M.at(s3, 700.0 - M.D * 3.0)
	M.fire(s3, b2 - (s3["shooter"] as Vector2))
	check("cadena: meter una bola que no junta tres la deja en la cadena", M.balls_left(s3) == 7)
	s3["cur"] = 0
	s3["next"] = 2
	M.swap(s3)
	check("cadena: se puede cambiar la bola por la siguiente", int(s3["cur"]) == 2 and int(s3["next"]) == 0)
	var s4: Dictionary = M.new_state(lv)
	s4["segs"][0]["s"] = float(s4["len"]) - 1.0
	s4["speed"] = 5.0
	s4["intro"] = 0.0
	M.tick(s4)
	check("cadena: si llega al agujero, pierdes", bool(s4["lost"]))
	var gen: Dictionary = {"path": [], "shooter": [300, 470], "balls": [], "colors": 3, "speed": 0.7, "seed": 3}
	for i: int in 161:
		var a: float = float(i) / 160.0 * 1.4 * TAU
		gen["path"].append(300.0 + (270.0 - 140.0 * float(i) / 160.0) * cos(a))
		gen["path"].append(470.0 + (400.0 - 210.0 * float(i) / 160.0) * sin(a))
	for j: int in 30:
		gen["balls"].append([0, 0, 1, 2, 2, 1, 0, 1, 1, 2][j % 10])
	check("cadena: el analizador acepta un nivel que el bot gana", bool(M.analyze(gen)["completable"]), str(M.analyze(gen)))
	check("cadena: el analizador no deja el lanzador encima del camino", (M.analyze(gen.merged({"shooter": [570, 470]}, true))["issues"] as Array).has("chain_shooter_on_path"))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "chain"
	Kit.config["levels"] = [gen.merged({"name": "T"})]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/chain.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(30)
	var shots0: int = int(g.get("st")["shots"])
	g.call("shoot_at", Vector2(300, 50))
	check("cadena: tocar dispara la bola en la escena", int(g.get("st")["shots"]) == shots0 + 1)
	g.call("retry")
	var Bot: GDScript = load("res://qa/chain_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 60 * 60)
	check("cadena: el bot gana el nivel en la escena", won, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Lucha: dos luchadores mirandose, andar sin atravesarse, punetazo que pega a su alcance y no mas
## lejos, cubrirse quita casi todo el dano, el especial gasta barra y lanza una bola, asaltos y
## combate a dos ganados, IA, analizador y bot en la escena.
func _test_fighter() -> void:
	print("- Lucha")
	var M: GDScript = load("res://kit/fighter/fighter_map.gd")
	var lv: Dictionary = {"hp": 100, "foe_hp": 80, "ai": 0.3, "round_time": 60, "foe_style": "rusher", "seed": 2}
	var none: Dictionary = {"dir": 0, "jump": false, "block": false, "attack": ""}
	var st: Dictionary = M.new_state(lv)
	st["pause"] = 0
	check("lucha: dos luchadores mirandose con su vida", int(st["f"][0]["face"]) == 1 and int(st["f"][1]["face"]) == -1 and int(st["f"][1]["hp"]) == 80)
	for k: int in 60:
		M.tick(st, {"dir": 1, "jump": false, "block": false, "attack": ""}, none)
	check("lucha: andar acerca pero no se atraviesan", float(st["f"][0]["x"]) < float(st["f"][1]["x"]) and float(st["f"][1]["x"]) - float(st["f"][0]["x"]) >= M.BODY - 0.01)
	var far: Dictionary = M.new_state(lv)
	far["pause"] = 0
	M.tick(far, none.merged({"attack": "punch"}, true), none)
	for k2: int in 10:
		M.tick(far, none, none)
	check("lucha: de lejos el punetazo no llega", int(far["f"][1]["hp"]) == 80)
	var near: Dictionary = M.new_state(lv)
	near["pause"] = 0
	near["f"][0]["x"] = 50.0
	near["f"][1]["x"] = 57.0
	M.tick(near, none.merged({"attack": "punch"}, true), none)
	for k3: int in 6:
		M.tick(near, none, none)
	check("lucha: el punetazo pega, aturde y carga la barra", int(near["f"][1]["hp"]) == 74 and int(near["f"][0]["meter"]) > 0)
	var bl: Dictionary = M.new_state(lv)
	bl["pause"] = 0
	bl["f"][0]["x"] = 50.0
	bl["f"][1]["x"] = 60.0
	M.tick(bl, none.merged({"attack": "kick"}, true), none.merged({"block": true}, true))
	for k4: int in 8:
		M.tick(bl, none, none.merged({"block": true}, true))
	check("lucha: cubrirse quita casi todo el dano", int(bl["f"][1]["hp"]) >= 77 and int(bl["f"][1]["hp"]) < 80, str(bl["f"][1]["hp"]))
	var sp: Dictionary = M.new_state(lv)
	sp["pause"] = 0
	sp["f"][0]["meter"] = 60
	M.tick(sp, none.merged({"attack": "special"}, true), none)
	for k5: int in 12:
		M.tick(sp, none, none)
	check("lucha: el especial gasta media barra y lanza una bola", int(sp["f"][0]["meter"]) == 10 and ((sp["shots"] as Array).size() == 1 or int(sp["f"][1]["hp"]) < 80))
	var nometer: Dictionary = M.new_state(lv)
	nometer["pause"] = 0
	M.tick(nometer, none.merged({"attack": "special"}, true), none)
	check("lucha: sin barra no hay especial", str(nometer["f"][0]["state"]) != "attack")
	var rd: Dictionary = M.new_state(lv)
	rd["pause"] = 0
	rd["f"][1]["hp"] = 0
	M.tick(rd, none, none)
	check("lucha: dejar al rival sin vida gana el asalto y empieza otro", int(rd["wins"][0]) == 1 and int(rd["round"]) == 2 and int(rd["f"][1]["hp"]) == 80)
	rd["pause"] = 0
	rd["f"][1]["hp"] = 0
	M.tick(rd, none, none)
	check("lucha: dos asaltos ganados ganan el combate", bool(rd["won"]))
	var tm: Dictionary = M.new_state(lv)
	tm["pause"] = 0
	tm["time"] = 1
	tm["f"][1]["hp"] = 10
	M.tick(tm, none, none)
	check("lucha: al acabar el tiempo gana quien tiene mas vida", int(tm["wins"][0]) == 1)
	check("lucha: el analizador acepta un combate que el bot gana", bool(M.analyze(lv)["completable"]), str(M.analyze(lv)))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "fighter"
	Kit.config["levels"] = [lv.merged({"name": "T"})]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/fighter.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	g.get("st")["pause"] = 0
	(g.get("hold") as Dictionary)["right"] = true
	await frames(30)
	(g.get("hold") as Dictionary)["right"] = false
	check("lucha: el boton de la flecha mueve a tu luchador", float(g.get("st")["f"][0]["x"]) > 31.0, str(g.get("st")["f"][0]["x"]))
	g.call("retry")
	var Bot: GDScript = load("res://qa/fighter_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 60 * 60)
	check("lucha: el bot gana el combate en la escena", won, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Fusion de frutas: soltar, caer con fisica y quedarse en el tarro, dos iguales se juntan en la
## siguiente, distintas no, conseguir la objetivo gana, rebosar pierde, analizador y bot en la escena.
func _test_fruitmerge() -> void:
	print("- Fusion de frutas")
	var M: GDScript = load("res://kit/fruitmerge/fruitmerge_map.gd")
	var lv: Dictionary = {"goal": 5, "drop_max": 4, "width": 360, "seed": 3}
	var st: Dictionary = M.new_state(lv)
	check("frutas: empiezas con una fruta pequena en la mano y la siguiente", int(st["cur"]) < 4 and int(st["next"]) < 4)
	st["cur"] = 2
	M.drop(st, 100.0)
	for k: int in 90:
		M.tick(st)
	var f: Dictionary = st["fruits"][0]
	check("frutas: la fruta cae y se queda en el fondo del tarro", absf((f["p"] as Vector2).y - (M.H - M.RADII[2])) < 2.0 and absf((f["p"] as Vector2).x - 100.0) < 1.0)
	check("frutas: no se puede soltar otra al momento", M.drop(st, 100.0) == true and M.drop(st, 100.0) == false)
	var mg: Dictionary = M.new_state(lv)
	mg["fruits"] = [{"id": 1, "t": 1, "p": Vector2(100, 540), "v": Vector2.ZERO, "age": 60}, {"id": 2, "t": 1, "p": Vector2(130, 540), "v": Vector2.ZERO, "age": 60}]
	M.tick(mg)
	check("frutas: dos iguales que se tocan se juntan en la siguiente", (mg["fruits"] as Array).size() == 1 and int(mg["fruits"][0]["t"]) == 2 and int(mg["merges"]) == 1)
	var df: Dictionary = M.new_state(lv)
	df["fruits"] = [{"id": 1, "t": 1, "p": Vector2(100, 540), "v": Vector2.ZERO, "age": 60}, {"id": 2, "t": 2, "p": Vector2(130, 540), "v": Vector2.ZERO, "age": 60}]
	for k2: int in 30:
		M.tick(df)
	check("frutas: distintas no se juntan y no se pisan", (df["fruits"] as Array).size() == 2 and ((df["fruits"][0]["p"] as Vector2).distance_to(df["fruits"][1]["p"]) >= M.RADII[1] + M.RADII[2] - 1.0))
	var gw: Dictionary = M.new_state(lv)
	gw["fruits"] = [{"id": 1, "t": 4, "p": Vector2(100, 520), "v": Vector2.ZERO, "age": 60}, {"id": 2, "t": 4, "p": Vector2(160, 520), "v": Vector2.ZERO, "age": 60}]
	M.tick(gw)
	check("frutas: conseguir la fruta objetivo gana", bool(gw["won"]))
	var ov: Dictionary = M.new_state(lv.merged({"goal": 10, "width": 130}, true))
	var stack: Array = []
	for i: int in 8:
		stack.append({"id": i + 1, "t": [6, 7][i % 2], "p": Vector2(65.0, 500.0 - float(i) * 105.0), "v": Vector2.ZERO, "age": 60})
	ov["fruits"] = stack
	for k3: int in 200:
		M.tick(ov)
		if bool(ov["lost"]):
			break
	check("frutas: si el tarro rebosa, pierdes", bool(ov["lost"]))
	check("frutas: el analizador acepta un nivel que el bot gana", bool(M.analyze(lv)["completable"]), str(M.analyze(lv)))
	check("frutas: el analizador no deja que salgan frutas tan grandes como la objetivo", (M.analyze({"goal": 4, "drop_max": 4})["issues"] as Array).has("fruit_drop_max"))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "fruitmerge"
	Kit.config["levels"] = [lv.merged({"name": "T"})]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/fruitmerge.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	g.call("drop_at", 200.0)
	check("frutas: soltar en la escena pone la fruta en el tarro", (g.get("st")["fruits"] as Array).size() == 1)
	g.call("retry")
	var Bot: GDScript = load("res://qa/fruitmerge_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 60 * 60)
	check("frutas: el bot consigue la fruta objetivo en la escena", won, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Pinball: la bola sale sola por el carril, cae con la gravedad, la pala levantada la devuelve
## hacia arriba, las setas rebotan y puntuan, las dianas se tumban, colarse quita una bola,
## llegar al objetivo gana, analizador y bot en la escena.
func _test_pinball() -> void:
	print("- Pinball")
	var M: GDScript = load("res://kit/pinball/pinball_map.gd")
	var lv: Dictionary = {"bumpers": [[160, 220], [320, 220], [240, 330]], "targets": [[200, 450], [240, 450], [280, 450]], "goal": 3000, "balls": 3, "gravity": 600, "seed": 2}
	var st: Dictionary = M.new_state(lv)
	for k: int in 40:
		M.tick(st, false, false)
	check("pinball: la bola sale sola por el carril hacia arriba", not (st["ball"] as Dictionary).is_empty() and (st["ball"]["v"] as Vector2).y < 0.0)
	var fl: Dictionary = M.new_state(lv)
	fl["wait"] = 999
	fl["ball"] = {"p": Vector2(200, 650), "v": Vector2(0, 200)}
	var hit_up: bool = false
	for k2: int in 30:
		M.tick(fl, true, false)
		if not (fl["ball"] as Dictionary).is_empty() and (fl["ball"]["v"] as Vector2).y < -300.0:
			hit_up = true
	check("pinball: la pala levantada devuelve la bola hacia arriba", hit_up)
	var dr: Dictionary = M.new_state(lv)
	dr["wait"] = 999
	dr["ball"] = {"p": Vector2(240, 760), "v": Vector2(0, 300)}
	for k3: int in 30:
		M.tick(dr, false, false)
	check("pinball: si se cuela por el medio, pierdes una bola", int(dr["balls"]) == 2 and int(dr["drained"]) == 1)
	var bu: Dictionary = M.new_state(lv)
	bu["wait"] = 999
	bu["ball"] = {"p": Vector2(160, 180), "v": Vector2(0, 300)}
	for k4: int in 10:
		M.tick(bu, false, false)
	check("pinball: la seta rebota la bola y da puntos", int(bu["score"]) >= 100 and (bu["ball"]["v"] as Vector2).y < 0.0)
	var tg: Dictionary = M.new_state(lv)
	tg["wait"] = 999
	tg["ball"] = {"p": Vector2(200, 420), "v": Vector2(0, 400)}
	for k5: int in 10:
		M.tick(tg, false, false)
	check("pinball: tocar una diana la tumba", bool(tg["targets"][0]["down"]) and int(tg["score"]) >= 250)
	var go: Dictionary = M.new_state(lv)
	go["score"] = 2990
	go["wait"] = 999
	go["ball"] = {"p": Vector2(160, 180), "v": Vector2(0, 300)}
	for k6: int in 10:
		M.tick(go, false, false)
	check("pinball: llegar al objetivo gana", bool(go["won"]))
	check("pinball: el analizador acepta una mesa que el bot supera", bool(M.analyze(lv)["completable"]), str(M.analyze(lv)))
	check("pinball: el analizador no deja setas fuera de la mesa", (M.analyze(lv.merged({"bumpers": [[30, 700]]}, true))["issues"] as Array).has("pinball_bumper_out"))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "pinball"
	Kit.config["levels"] = [lv.merged({"name": "T"})]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/pinball.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	g.set("hold_left", true)
	await frames(6)
	check("pinball: tocar a la izquierda levanta la pala izquierda", float(g.get("st")["flip"][0]) < M.FLIP_REST and float(g.get("st")["flip"][1]) == M.FLIP_REST)
	g.set("hold_left", false)
	g.call("retry")
	var Bot: GDScript = load("res://qa/pinball_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 60 * 60)
	check("pinball: el bot llega al objetivo en la escena", won, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Metroidvania: leer el mundo, andar y caer por casillas, saltar 4 y el doble salto otras 4,
## el impulso cruza 4 casillas, el martillo rompe bloques, la llave abre la puerta, los pinchos
## quitan vida y devuelven al suelo seguro, los enemigos se golpean, el planificador encuentra
## caminos, analizador (la meta no se alcanza al empezar) y bot en la escena.
func _test_metroid() -> void:
	print("- Metroidvania")
	var M: GDScript = load("res://kit/metroid/metroid_map.gd")
	var none: Array = [0, false, false, false]
	var st: Dictionary = M.new_state({"map": ["##########", "#........#", "#........#", "#........#", "#........#", "#........#", "#P..J.D.G#", "##########"]})
	check("metroid: salida, meta y habilidades leidas del mapa", st["p"] == Vector2i(1, 6) and st["goal"] == Vector2i(8, 6) and (st["items"] as Dictionary).size() == 2)
	M.tick(st, 1, false, false, false)
	check("metroid: andar avanza una casilla", st["p"] == Vector2i(2, 6))
	M.tick(st, 0, true, false, false)
	M.tick(st, 0, false, false, false)
	M.tick(st, 0, false, false, false)
	M.tick(st, 0, false, false, false)
	check("metroid: saltar sube cuatro casillas", st["p"] == Vector2i(2, 2), str(st["p"]))
	M.tick(st, 0, true, false, false)
	check("metroid: sin doble salto no se salta en el aire", int(st["rise"]) == 0)
	for k: int in 6:
		M.tick(st, 0, false, false, false)
	M.tick(st, 1, false, false, false)
	M.tick(st, 1, false, false, false)
	check("metroid: coger la habilidad del doble salto", bool(st["abil"]["J"]))
	M.tick(st, 0, true, false, false)
	for k2: int in 3:
		M.tick(st, 0, false, false, false)
	M.tick(st, 0, true, false, false)
	check("metroid: con doble salto se vuelve a saltar en el aire", int(st["rise"]) > 0 and (st["p"] as Vector2i).y < 2, str(st["p"]))
	var ds: Dictionary = M.new_state({"map": ["############", "#..........#", "#..........#", "#P^^^.....G#", "############"]})
	ds["abil"]["D"] = true
	M.tick(ds, 1, false, true, false)
	check("metroid: el impulso cruza cuatro casillas de golpe", ds["p"] == Vector2i(5, 3) and int(ds["hp"]) == 3, str(ds["p"]))
	var sp: Dictionary = M.new_state({"map": ["#######", "#.....#", "#P^...#", "#######"]})
	M.tick(sp, 1, false, false, false)
	check("metroid: los pinchos quitan una vida y devuelven al suelo seguro", int(sp["hp"]) == 2 and sp["p"] == Vector2i(1, 2))
	var br: Dictionary = M.new_state({"map": ["######", "#....#", "#P%.G#", "######"]})
	M.tick(br, 1, false, false, true)
	check("metroid: sin martillo el bloque no se rompe", M.cell(br, Vector2i(2, 2)) == "%")
	br["abil"]["B"] = true
	M.tick(br, 1, false, false, true)
	check("metroid: con martillo se rompe", M.cell(br, Vector2i(2, 2)) == ".")
	var dr: Dictionary = M.new_state({"map": ["######", "#....#", "#PKLG#", "######"]})
	M.tick(dr, 1, false, false, false)
	M.tick(dr, 1, false, false, false)
	M.tick(dr, 1, false, false, false)
	check("metroid: la llave abre la puerta y se llega a la meta", bool(dr["won"]) and int(dr["keys"]) == 0)
	var en: Dictionary = M.new_state({"map": ["########", "#......#", "#P.E...#", "########"]})
	M.tick(en, 0, false, false, true)
	check("metroid: el golpe derrota al enemigo de delante", not bool(en["enemies"][0]["alive"]))
	var lv: Dictionary = {"map": ["##########", "#........#", "#........#", "#........#", "#........#", "#....J...#", "#...###..#", "#........#", "#P.......#", "##########"]}
	var pl: Dictionary = M.new_state(lv)
	check("metroid: el planificador encuentra el camino a la habilidad", not M.plan(pl, {Vector2i(5, 5): true}).is_empty())
	var gate: Dictionary = {"map": ["#############################", "#.............#.............#", "#.............#.............#", "#.............#.............#",
		"#.............#.............#", "#.............#.............#", "#.............#.............#", "#.............#.............#", "#.............#.............#",
		"#P.......J....%......G......#", "#############################"]}
	gate["map"][9] = "#P.....B.....%%......G......#"
	gate["map"][8] = "#.............%..............#".substr(0, 29)
	gate["map"][7] = "#.............%..............#".substr(0, 29)
	check("metroid: el analizador acepta un mundo con puerta que el bot abre", bool(M.analyze(gate)["completable"]), str(M.analyze(gate)))
	var open_lv: Dictionary = {"map": ["##########", "#........#", "#........#", "#........#", "#........#", "#........#", "#........#", "#........#",
		"#........#", "#P......G#", "##########", "##########", "##########", "##########", "##########", "##########"]}
	open_lv["map"] = (open_lv["map"] as Array).map(func(r: String) -> String: return r + "##########################")
	check("metroid: el analizador pide que la meta no se alcance al empezar", (M.analyze(open_lv)["issues"] as Array).has("metroid_no_gates"), str(M.analyze(open_lv)))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "metroid"
	Kit.config["levels"] = [gate.merged({"name": "T"})]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/metroid.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	(g.get("hold") as Dictionary)["right"] = true
	await frames(20)
	(g.get("hold") as Dictionary)["right"] = false
	check("metroid: la flecha mueve al heroe en la escena", (g.get("st")["p"] as Vector2i).x > 1)
	g.call("retry")
	var Bot: GDScript = load("res://qa/metroid_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 60 * 60)
	check("metroid: el bot llega a la meta en la escena", won, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Sigilo: leer el tablero, moverse solo por caminos, eliminar a un guardia llegando por un lado,
## que te pille si acabas en el punto que mira, patrulla y giro, maletin, resolutor, analizador
## (los guardias tienen que importar) y bot en la escena.
func _test_stealth() -> void:
	print("- Sigilo")
	var M: GDScript = load("res://kit/stealth/stealth_map.gd")
	var st: Dictionary = M.new_state({"map": ["X-.-.", "| | |", ".-W .", "|   |", "P-.-C"]})
	check("sigilo: salida, heroe, guardia, maletin y caminos leidos", st["p"] == Vector2i(0, 2) and st["exit"] == Vector2i(0, 0) and (st["guards"] as Array).size() == 1
		and st["item"] == Vector2i(2, 2))
	check("sigilo: solo se va por los caminos", not M.move(st, Vector2i(1, 1)) and M.move(st, Vector2i(1, 2)))
	var sd: Dictionary = M.new_state({"map": ["X-.-.", "| | |", ".-W .", "|   |", "P-.-C"]})
	M.move(sd, Vector2i(0, 1))
	check("sigilo: acabar en el punto que mira un guardia te delata", bool(sd["lost"]))
	var kl: Dictionary = M.new_state({"map": ["X-.-.", "| | |", ".-W .", "|   |", "P-.-C"]})
	for q: Vector2i in [Vector2i(1, 2), Vector2i(2, 2), Vector2i(2, 1), Vector2i(2, 0), Vector2i(1, 0), Vector2i(1, 1)]:
		M.move(kl, q)
	check("sigilo: llegar a un guardia por un lado lo elimina", int(kl["kills"]) == 1 and not bool(kl["lost"]), str(kl["p"]))
	var pt: Dictionary = M.new_state({"map": [".-.-e-.-X", "|       |", "P-------."]})
	var g0: Vector2i = pt["guards"][0]["p"]
	M.move(pt, Vector2i(0, 0))
	check("sigilo: el que patrulla avanza un punto por turno", pt["guards"][0]["p"] == g0 + Vector2i(1, 0))
	var rt: Dictionary = M.new_state({"map": [". .", "| |", ".-R", "| |", "P X"]})
	var d0: String = str(rt["guards"][0]["d"])
	M.move(rt, Vector2i(0, 1))
	check("sigilo: el que gira cambia de direccion cada turno", str(rt["guards"][0]["d"]) != d0)
	var it: Dictionary = M.new_state({"map": ["X-C", "| |", "P-."]})
	M.move(it, Vector2i(1, 1))
	M.move(it, Vector2i(1, 0))
	check("sigilo: pasar por el maletin lo coge", bool(it["has_item"]))
	M.move(it, Vector2i(0, 0))
	check("sigilo: llegar a la salida gana", bool(it["won"]))
	var lv: Dictionary = {"map": ["X-.-.", "| | |", ".-W .", "|   |", "P-.-C"], "par": 8}
	check("sigilo: el resolutor encuentra el camino con el maletin", not M.solve(M.new_state(lv), true).is_empty())
	check("sigilo: el analizador acepta un tablero donde el guardia importa", bool(M.analyze(lv)["completable"]), str(M.analyze(lv)))
	check("sigilo: el analizador rechaza un tablero donde los guardias no estorban", (M.analyze({"map": ["X-.-S", "|    ", "P    "]})["issues"] as Array).has("stealth_trivial"))
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "stealth"
	Kit.config["levels"] = [lv.merged({"name": "T"})]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/stealth.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	g.call("go", Vector2i(1, 2))
	g.call("undo")
	check("sigilo: deshacer vuelve al punto anterior", g.get("st")["p"] == Vector2i(0, 2) and int(g.get("st")["moves"]) == 0)
	var Bot: GDScript = load("res://qa/stealth_bot.gd")
	var won: bool = await Bot.run(get_tree(), g, 60 * 60)
	check("sigilo: el bot llega a la salida en la escena", won, str(g.call("bot_state")))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Pantalla principal de juego grande, sonidos de interfaz e idiomas de cualquier escritura.
## Cofres y ruta de trofeos: ganar, abrir con tiempo, acelerar, premios y la ruta.
func _test_chests() -> void:
	print("- Cofres y trofeos")
	Save.meta().erase("chests")
	var w: Dictionary = Chests.on_level_won("0", 3)
	check("cofres: superar un nivel da cofre y 30 trofeos", str(w["chest"]) == "madera" and int(w["trophies"]) == 30 and Chests.slots().size() == 1)
	var w2: Dictionary = Chests.on_level_won("0", 3)
	check("cofres: repetir sin estrellas nuevas no da trofeos", int(w2["trophies"]) == 0 and Chests.trophies() == 30)
	for k: int in 4:
		Chests.on_level_won(str(k + 1), 1)
	check("cofres: como mucho 4 huecos", Chests.slots().size() == 4 and bool(Chests.on_level_won("9", 1)["full"]))
	check("cofres: se abre uno a la vez", Chests.start(0) and not Chests.start(1) and Chests.unlocking() == 0)
	check("cofres: aun no esta listo", not Chests.ready(0) and Chests.open(0).is_empty())
	Chests.slots()[0]["start"] = Chests.now() - 400
	var w0: int = Save.wallet()
	var r: Dictionary = Chests.open(0)
	check("cofres: al pasar el tiempo se abre y da monedas", int(r.get("coins", 0)) >= 20 and Save.wallet() == w0 + int(r["coins"]) and Chests.slots().size() == 3)
	Save.add_wallet(500)
	var cost: int = Chests.skip_cost(0)
	var w1: int = Save.wallet()
	check("cofres: abrir ya cuesta monedas", Chests.speed_up(0, false) and Chests.ready(0) and Save.wallet() == w1 - cost)
	Save.meta()["chests"]["trophies"] = 120
	check("ruta: dos premios por cobrar", Chests.road_claimable() == [1, 2])
	var rw: Dictionary = Chests.claim_road(1)
	check("ruta: se cobra una vez", str(rw.get("kind", "")) == "coins" and Chests.road_claimed(1) and Chests.claim_road(1).is_empty())
	var host: Control = Control.new()
	add_child(host)
	var p: ChestPanel = ChestPanel.open_slot(host, 0)
	await frames(3)
	var ob: Button = p.find_child("BtnOpenChest", true, false) as Button
	check("cofres: la ventana ofrece abrir el que esta listo", ob != null)
	ob.pressed.emit()
	await _wait_seconds(1.6)
	check("cofres: la animacion abre el cofre y da el premio", Chests.slots().size() == 2 and (p.find_child("ChestInfo", true, false) as Label).text.begins_with("+"))
	var road: TrophyRoad = TrophyRoad.open(host)
	await frames(3)
	check("ruta: la ventana ensena el premio por cobrar", road.find_child("BtnClaim2", true, false) != null)
	host.queue_free()
	Save.meta().erase("chests")
	await frames(2)


## Album: cartas de los cofres, subir de nivel con repetidas y monedas, bonus de monedas.
func _test_album() -> void:
	print("- Album de personajes")
	var old_album: Variant = Kit.config.get("album", null)
	Kit.config["album"] = [{"sprite": "heroe", "name": "Remache", "rarity": "raro"},
		{"sprite": "chatarrilla", "name": "Chatarrilla", "rarity": "comun"}, {"sprite": "moneda", "name": "Tuerca", "rarity": "comun"},
		{"sprite": "no_existe", "name": "Fantasma", "rarity": "epico"}]
	Save.meta().erase("album")
	check("album: solo las cartas con sprite", Album.cards().size() == 3 and Album.available())
	check("album: el heroe se tiene desde el principio", Album.owned("heroe") and not Album.owned("moneda") and Album.count_owned() == 1)
	check("album: precios y copias por nivel", Album.need(1) == 2 and Album.cost(1) == 50 and Album.need(Album.MAX_LEVEL) == -1)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var got: Array[String] = Album.drop(rng, 40)
	check("album: los cofres dan cartas y descubren las nuevas", got.size() == 40 and Album.count_owned() == 3)
	var b0: float = Album.bonus()
	check("album completo: +5 % de monedas", is_equal_approx(b0, 0.05))
	Save.add_wallet(2000)
	var w: int = Save.wallet()
	var lvl0: int = int(Album.entry("chatarrilla")["lvl"])
	check("album: subir con repetidas cuesta monedas", Album.upgrade("chatarrilla") and int(Album.entry("chatarrilla")["lvl"]) == lvl0 + 1 and Save.wallet() == w - Album.cost(lvl0))
	check("album: cada nivel da +1 % de monedas", is_equal_approx(Album.bonus(), b0 + 0.01) and Save.with_fortune(100) == 106)
	Save.meta()["album"]["moneda"] = {"n": 0, "lvl": 1}
	check("album: sin repetidas no se sube", not Album.can_upgrade("moneda") and not Album.upgrade("moneda"))
	var host: Control = Control.new()
	add_child(host)
	var p: AlbumPanel = AlbumPanel.open(host)
	await frames(3)
	check("album: la ventana ensena las cartas", p.find_child("Card_heroe", true, false) != null and p.find_child("Card_moneda", true, false) != null
		and p.find_child("Card_no_existe", true, false) == null)
	host.queue_free()
	Save.meta().erase("album")
	if old_album == null:
		Kit.config.erase("album")
	else:
		Kit.config["album"] = old_album
	await frames(2)


## Iconos de interfaz dibujados por la IA: se cargan los que existen y UiIcon los usa.
func _test_ui_icons() -> void:
	print("- Iconos de interfaz con arte")
	var img: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 0.2, 0.3, 1))
	img.save_png("user://qa_icon_heart.png")
	UI.load_icons({"heart": "user://qa_icon_heart.png", "star": "res://no/existe.png"})
	check("iconos: se cargan los que existen y los demas siguen vectoriales", UI.icons.has("heart") and not UI.icons.has("star") and UI.icon_art("star") == null)
	check("iconos: la vida perdida usa el mismo corazon", UI.icon_art("heart_empty") == UI.icon_art("heart") and UI.icon_art("heart") != null)
	var box: Control = Control.new()
	add_child(box)
	var full: UiIcon = UiIcon.make("heart", Color.RED, 64.0)
	var empty: UiIcon = UiIcon.make("heart_empty", Color.GRAY, 64.0)
	box.add_child(full)
	box.add_child(empty)
	var row: StarRow = StarRow.make(3, 1, 48.0)
	box.add_child(row)
	await frames(2)
	check("iconos: la fila de estrellas apaga las no ganadas", not (row.get_child(0) as UiIcon).dim and (row.get_child(2) as UiIcon).dim)
	check("iconos: se dibujan sin errores", is_instance_valid(full) and is_instance_valid(empty))
	UI.load_icons("no es un diccionario")
	check("iconos: una configuracion rara deja los vectoriales", UI.icons.is_empty())
	box.queue_free()
	await frames(1)

func _test_lobby_feel() -> void:
	print("- Lobby, sonidos e idiomas")
	for n: String in ["ui_tap", "ui_big", "ui_open", "ui_close", "ui_coin", "ui_reward", "ui_swoosh", "ui_tick"]:
		var st: AudioStream = Audio.get("_streams").get(n, null)
		if not (st is AudioStreamWAV) or (st as AudioStreamWAV).get_length() <= 0.01:
			check("sonido de interfaz " + n, false)
			return
	check("sonidos de interfaz hechos por el kit (toque, abrir, monedas, premio...)", true)
	var title: Node = (load(UI.SCREEN_TITLE) as PackedScene).instantiate()
	add_child(title)
	await _wait_seconds(1.0)
	var play: Button = title.find_child("BtnPlay", true, false) as Button
	check("lobby: JUGAR grande", play != null and play.size.y >= 130.0 and play.size.x >= 440.0, str(play.size if play else Vector2.ZERO))
	check("lobby: nivel del jugador y monedas arriba", title.find_child("LevelChip", true, false) != null and title.find_child("BtnWallet", true, false) != null)
	var hero: Node2D = title.find_child("HeroRoot", true, false) as Node2D
	var spot: Control = title.find_child("HeroSpot", true, false) as Control
	check("lobby: el heroe esta en el hueco del centro", hero != null and spot != null and spot.get_global_rect().grow(60.0).has_point(hero.global_position))
	var y0: float = hero.position.y
	var ev: InputEventMouseButton = InputEventMouseButton.new()
	ev.pressed = true
	ev.button_index = MOUSE_BUTTON_LEFT
	title.call("_hero_input", ev)
	await _wait_seconds(0.15)
	check("lobby: el heroe salta al tocarlo", hero.position.y < y0 - 20.0)
	await _wait_seconds(0.8)
	check("lobby: todo dentro de pantalla y legible", UI.audit(title).is_empty(), str(UI.audit(title).slice(0, 3)))
	title.queue_free()
	await frames(2)
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["i18n"] = {"ja": {"_name": "\u65e5\u672c\u8a9e", "play": "\u30d7\u30ec\u30a4"}}
	check("idiomas: un idioma nuevo con su nombre en el selector", Kit.languages().has("ja") and Kit.lang_name("ja") == "\u65e5\u672c\u8a9e")
	var ff: Font = UI.font
	var base: Font = (ff as FontVariation).base_font if ff is FontVariation else ff
	check("idiomas: letras de cualquier escritura con las fuentes del movil", base != null and base.fallbacks.size() >= 1 and base.fallbacks[0] is SystemFont)
	Kit.config = keep


## Giros: reglas raras encima de cualquier genero, y las mezclas (laberinto+serpiente, golf+RPG).
func _test_twists() -> void:
	print("- Giros y mezclas")
	var keep: Dictionary = Kit.config.duplicate(true)
	var idx: int = Kit.level_index
	var wallet0: int = Save.wallet()
	Kit.config["genre"] = "maze"
	Kit.config["levels"] = [{"name": "L", "map": ["#####", "#C.C#", "#...#", "#...#", "##P##"], "time_limit": 0.4}]
	Kit.level_index = 0
	Twist.forced = ["oscuridad", "espejo", "contrarreloj"]
	var g: Node = (load("res://scenes/maze.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(3)
	check("giros: el juego se engancha solo", Twist.game == g)
	check("giros: espejo y oscuridad montados", g.find_child("TwistMirror", true, false) != null and g.find_child("TwistLayer", true, false) != null
		and (g.find_child("TwistLayer", true, false) as Node).get_child_count() > 0)
	check("giros: la linterna sigue al heroe", Twist._focus() != Vector2.INF)
	g.set("fast", true)
	g.call("try_move", Vector2i.UP)
	await frames(45)
	check("contrarreloj: se acaba el tiempo y vuelve a empezar", int(g.get("deaths")) >= 1 and g.get("cell") == Vector2i(2, 4))
	g.queue_free()
	await frames(2)
	Twist.forced = ["racha"]
	Twist.streak = 0
	QA.log_event("level_complete", {"level": 0, "coins": 10, "deaths": 0})
	QA.log_event("level_complete", {"level": 1, "coins": 10, "deaths": 0})
	check("racha: dos niveles sin morir dan monedas extra", Save.wallet() == wallet0 + 10 + 20, str(Save.wallet() - wallet0))
	QA.log_event("level_complete", {"level": 2, "coins": 10, "deaths": 1})
	check("racha: morir la corta", Twist.streak == 0)
	Twist.forced = []
	## Reto del dia: nivel desbloqueado y giro seguro segun la fecha; premio una vez.
	Kit.config["levels"] = [{"name": "A", "map": ["P.C"]}, {"name": "B", "map": ["P.C"]}]
	Kit.config["daily_twists"] = ["oscuridad", "espejo"]
	Twist.fake_day = 20000
	Save.set_setting("reto_dia", -1, false)
	var reto: Dictionary = Twist.daily_today()
	check("reto: nivel desbloqueado y giro de la lista", int(reto["level"]) < maxi(1, Save.unlocked_count()) and ["oscuridad", "espejo"].has(str(reto["twist"])))
	var w1: int = Save.wallet()
	check("reto: empieza con su giro", Twist.start_daily() and Twist.active() == [str(reto["twist"])] and Kit.level_index == int(reto["level"]))
	QA.log_event("level_complete", {"level": Kit.level_index, "coins": 0, "deaths": 0})
	check("reto: premio y el giro se va", Save.wallet() == w1 + Twist.DAILY_REWARD and Twist.daily_done() and Twist.active().is_empty())
	Twist.start_daily()
	QA.log_event("level_complete", {"level": Kit.level_index, "coins": 0, "deaths": 0})
	check("reto: una vez al dia", Save.wallet() == w1 + Twist.DAILY_REWARD)
	Twist.fake_day = 20001
	check("reto: al dia siguiente, otro", not Twist.daily_done())
	Twist.fake_day = -1
	Save.set_setting("reto_dia", -1, false)
	Kit.config.erase("daily_twists")
	check("reto: sin giros seguros no hay reto", Twist.daily_today().is_empty())
	## Reto con niveles nuevos (game.json -> "daily_levels"): en cualquier genero, sin tocar el progreso.
	Kit.config["daily_levels"] = [{"name": "X", "map": ["P..C"]}, {"name": "Y", "map": ["P...C"]}]
	var unl0: int = Save.unlocked_count()
	Save.unlock_level(1)
	var unl: int = Save.unlocked_count()
	Twist.fake_day = 30000
	var fr: Dictionary = Twist.daily_today()
	check("reto nuevo: un nivel extra despues del ultimo", fr.has("fresh") and int(fr["level"]) == Kit.level_count() and str(fr["twist"]) == "")
	var w2: int = Save.wallet()
	check("reto nuevo: se juega el nivel del dia", Twist.start_daily() and Kit.is_extra() and Twist.active().is_empty()
		and str(Kit.current_level().get("map", [""])[0]).begins_with("P.") and str(Kit.current_level()["name"]) != "X")
	Save.unlock_level(Kit.level_index + 1)
	check("reto nuevo: no guarda estrellas ni desbloquea", not Save.submit_stars(str(Kit.level_index), 3) and not Save.submit_best(str(Kit.level_index), 99)
		and Save.unlocked_count() == unl)
	QA.log_event("level_complete", {"level": Kit.level_index, "coins": 0, "deaths": 0})
	check("reto nuevo: premio el primer dia", Save.wallet() == w2 + Twist.DAILY_REWARD and Twist.daily_done() and Twist.daily_streak() == 1)
	Twist.fake_day = 30001
	var other: int = int(Twist.daily_today()["fresh"])
	check("reto nuevo: al dia siguiente, otro nivel", other != int(fr["fresh"]))
	var w3: int = Save.wallet()
	Twist.start_daily()
	QA.log_event("level_complete", {"level": Kit.level_index, "coins": 0, "deaths": 0})
	check("reto nuevo: racha de 2 dias, mas premio", Save.wallet() == w3 + Twist.DAILY_REWARD + 10 and Twist.daily_streak() == 2)
	var aviso: String = str((Notify.plan({"hour": 10, "minute": 0})[0] as Dictionary)["content"])
	check("reto nuevo: el aviso de manana recuerda la racha", aviso.contains("2"), aviso)
	Twist.fake_day = 30003
	check("reto nuevo: saltarse un dia corta la racha", Twist.daily_streak() == 0)
	Kit.level_index = 0
	check("reto nuevo: fuera del reto, los niveles de siempre", not Kit.is_extra() and str(Kit.current_level()["name"]) == "A")
	Twist.fake_day = -1
	Save.set_setting("reto_dia", -1, false)
	Save.set_setting("reto_racha", 0, false)
	Kit.config.erase("daily_levels")
	Kit.extra_level = {}
	Kit.extra_index = -1
	if unl0 < 2:
		var prog: Dictionary = Save.progress()
		prog["unlocked"] = unl0
	## Laberinto + serpiente: las casillas que dejas se cierran.
	var Maze: GDScript = load("res://kit/maze/maze_map.gd")
	var ok_cola: Dictionary = Maze.analyze({"map": ["#####", "#C.C#", "#.#.#", "#...#", "##P##"], "cola": true})
	check("cola: hay camino sin repetir casillas", bool(ok_cola["completable"]), str(ok_cola["issues"]))
	var bad_cola: Dictionary = Maze.analyze({"map": ["#######", "#C#.#C#", "#.#.#.#", "#.....#", "###P###"], "cola": true})
	check("cola: dos callejones con moneda, imposible", (bad_cola["issues"] as Array).has("maze_cola_impossible"))
	check("cola: sin el giro ese mismo nivel vale", bool(Maze.analyze({"map": ["#######", "#C#.#C#", "#.#.#.#", "#.....#", "###P###"]})["completable"]))
	Kit.config["levels"] = [{"name": "L", "map": ["#####", "#C.C#", "#.#.#", "#...#", "##P##"], "cola": true}]
	var mg: Node = (load("res://scenes/maze.tscn") as PackedScene).instantiate()
	add_child(mg)
	await frames(2)
	mg.set("fast", true)
	mg.call("try_move", Vector2i.UP)
	await frames(4)
	check("cola: no se puede volver a la casilla de antes", not bool(mg.call("try_move", Vector2i.DOWN)))
	mg.queue_free()
	## Golf + RPG: monstruos que se derriban con la bola; el hoyo se abre al final.
	var Golf: GDScript = load("res://kit/golf/golf_map.gd")
	var course: Array[String] = ["#####", "#.H.#", "#...#", "#.M.#", "#...#", "#.B.#", "#####"]
	var mons: Array[Vector2] = Golf.monsters_of(course)
	var hole: Vector2 = Golf.find(course, "H")
	var r: Dictionary = Golf.simulate(course, Golf.find(course, "B"), Vector2(0.0, -7.5), hole, mons)
	check("monstruos: la bola derriba al que pilla", (r["hits"] as Array).size() == 1)
	var open_course: Array[String] = ["#####", "#.H.#", "#...#", "#...#", "#.B.#", "#####"]
	var far: Array[Vector2] = [Vector2(1.5, 3.5)]
	var closed: Dictionary = Golf.simulate(open_course, Vector2(2.5, 4.5), Vector2(0.0, -6.5), Vector2(2.5, 1.5), far)
	check("monstruos: con monstruos vivos el hoyo no se abre", closed["state"] != "hoyo")
	var ga: Dictionary = Golf.analyze({"map": course, "par": 3})
	check("monstruos: hoyo con monstruo justo", bool(ga["completable"]), str(ga))
	## Viento (golf): empuja la bola; la misma fisica para el juego, el bot y el analizador.
	var calm: Dictionary = Golf.simulate(open_course, Vector2(2.5, 4.5), Vector2(0.0, -3.0), Vector2(2.5, 1.5), [] as Array[Vector2])
	var windy: Dictionary = Golf.simulate(open_course, Vector2(2.5, 4.5), Vector2(0.0, -3.0), Vector2(2.5, 1.5), [] as Array[Vector2], Vector2(0.9, 0.0))
	check("viento: desvia la bola hacia donde sopla", (windy["end"] as Vector2).x > (calm["end"] as Vector2).x + 0.2, str([calm["end"], windy["end"]]))
	check("viento: la bola acaba parando", windy["state"] != "rueda")
	var gw: Dictionary = Golf.analyze({"map": course, "par": 3, "wind": [0.6, 0.0]})
	check("viento: hoyo con viento justo", bool(gw["completable"]), str(gw))
	## Tormenta (pesca): las franjas aceleran.
	var Fish: GDScript = load("res://kit/fishing/fishing_map.gd")
	check("tormenta: mas lejos con tormenta", Fish.pos_at(0, 1.0, 10.0, 100, 0.01) > Fish.pos_at(0, 1.0, 10.0, 100) + 0.5)
	## Piedras (fusion): se rompen con una fusion al lado.
	var Merge: GDScript = load("res://kit/merge/merge_map.gd")
	var board: Array[int] = [0, 0, 0, 0, 0, 0, -1, 1, 0]
	var mr: Array = Merge.drop(board, 3, 3, 1, 1)
	check("piedras: la fusion de al lado la rompe", int(mr[3]) == 1 and not (mr[0] as Array).has(-1), str(mr))
	var still: Array = Merge.drop(board, 3, 3, 2, 2)
	check("piedras: sin fusion sigue ahi", (still[0] as Array).has(-1))
	var sa: Dictionary = Merge.analyze({"map": ["....", "....", "....", "....", "#..#"], "seq": [1, 1, 2, 1, 3], "goal": 5})
	check("piedras: nivel con piedras justo", bool(sa["completable"]), str(sa))
	## Hielo (cajas): la caja resbala hasta chocar; el par y la solucion cuentan con ello.
	var Sok: GDScript = load("res://kit/sokoban/sokoban_map.gd")
	var ice_a: Array[String] = ["######", "#P...#", "#.B..#", "#....#", "#.O..#", "######"]
	var ice_b: Array[String] = ["######", "#P...#", "#.B..#", "#.O..#", "#....#", "######"]
	var sm: Dictionary = Sok.parse(ice_a)
	check("hielo: la caja resbala hasta el muro", Sok.slide_end(sm["walls"], {}, Vector2i(2, 2), Vector2i(0, 1), true) == Vector2i(2, 4))
	check("hielo: sin hielo avanza una casilla", Sok.slide_end(sm["walls"], {}, Vector2i(2, 2), Vector2i(0, 1), false) == Vector2i(2, 3))
	check("hielo: la resuelve resbalando (1 empuje)", Sok.solve(ice_a, true).size() == 1 and Sok.solve(ice_a).size() == 2)
	check("hielo: si el hueco no tiene tope, imposible", (Sok.analyze({"map": ice_b, "ice": true})["issues"] as Array).has("sokoban_unsolvable")
		and bool(Sok.analyze({"map": ice_b})["completable"]))
	check("hielo: rincon sin hueco = caja perdida", Sok.dead_box(sm["walls"], sm["goals"], {Vector2i(1, 1): true}, true))
	## Tuneles (serpiente): por los huecos del borde se sale por el lado contrario.
	var Snk: GDScript = load("res://kit/snake/snake_map.gd")
	check("tuneles: salir por la izquierda es entrar por la derecha", Snk.step(Vector2i(0, 3), Vector2i(-1, 0), 9, 10, true) == Vector2i(8, 3)
		and Snk.step(Vector2i(0, 3), Vector2i(-1, 0), 9, 10, false) == Vector2i(-1, 3))
	var tun: Array = ["#########", "#.......#", "#.......#", ".........", "#.......#", "#.......#", "#.......#", "#...S...#", "#.......#", "#.......#", "#########"]
	check("tuneles: con el giro el borde abierto vale", bool(Snk.analyze({"map": tun, "goal": 6, "wrap": true})["completable"]))
	check("tuneles: sin el giro es un callejon", (Snk.analyze({"map": tun, "goal": 6})["issues"] as Array).has("snake_dead_end"))
	## Barajar (memoria): cada 2 fallos dos cartas tapadas se cambian de sitio.
	Kit.config["genre"] = "memory"
	Kit.config["levels"] = [{"name": "M", "map": ["....", "....", "...."], "seed": 5, "par": 9, "limit": 30, "shuffle": true}]
	Kit.level_index = 0
	Twist.forced = []
	var mem: Node = (load("res://scenes/memory.tscn") as PackedScene).instantiate()
	add_child(mem)
	await frames(2)
	mem.set("fast", true)
	var faces0: Array = []
	for c: Dictionary in mem.get("cards"):
		faces0.append(int(c["face"]))
	for attempt: int in 2:
		var cs: Array = mem.get("cards")
		var a1: int = -1
		var b1: int = -1
		for p: int in cs.size():
			for q: int in range(p + 1, cs.size()):
				if a1 < 0 and int(cs[p]["face"]) != int(cs[q]["face"]):
					a1 = p
					b1 = q
		mem.call("flip", a1)
		mem.call("flip", b1)
		await frames(8)
	var faces1: Array = []
	for c2: Dictionary in mem.get("cards"):
		faces1.append(int(c2["face"]))
	var sw: Vector2i = mem.get("last_swap")
	check("barajar: tras 2 fallos, dos cartas se cambian", int(mem.get("swaps")) == 1 and faces1[sw.x] == faces0[sw.y] and faces1[sw.y] == faces0[sw.x],
		str([mem.get("swaps"), sw]))
	faces0.sort()
	faces1.sort()
	check("barajar: siguen siendo las mismas parejas", faces0 == faces1)
	mem.queue_free()
	await frames(2)
	## Accesibilidad: colores para daltonismo y modo calma, desde Ajustes.
	var stp: SettingsPanel = SettingsPanel.open(self)
	await frames(2)
	var acc: Button = stp.find_child("BtnAccess", true, false) as Button
	check("accesibilidad: boton en Ajustes", acc != null)
	acc.pressed.emit()
	check("accesibilidad: colores enciende el filtro", Look.assist != null and Look.assist.visible and bool(Save.get_setting("color_assist", false)))
	acc.pressed.emit()
	Juice.trauma = 0.0
	Juice.shake(0.5)
	check("accesibilidad: calma quita las sacudidas", Juice.trauma == 0.0 and not Look.assist.visible)
	acc.pressed.emit()
	acc.pressed.emit()
	Juice.shake(0.2)
	check("accesibilidad: vuelve a no (y las sacudidas vuelven)", not bool(Save.get_setting("calm", true)) and Juice.trauma > 0.0 and not Look.assist.visible)
	Juice.trauma = 0.0
	var probl2: Array[String] = UI.audit(stp.get("root"))
	check("accesibilidad: Ajustes sin problemas de interfaz", probl2.is_empty(), str(probl2.slice(0, 2)))
	stp.queue_free()
	await frames(2)
	## Invisibles (ritmo): las notas se apagan antes de la linea.
	Kit.config["genre"] = "rhythm"
	var song: Array = []
	for k: int in 40:
		song.append("x..." if k % 2 == 0 else "..x.")
	Kit.config["levels"] = [{"name": "R", "map": song, "bpm": 100, "speed": 800, "target": 0.6, "energy": 12, "hidden": true}]
	Kit.level_index = 0
	var rit: Node = (load("res://scenes/rhythm.tscn") as PackedScene).instantiate()
	add_child(rit)
	await frames(3)
	var t0: float = float(rit.call("now"))
	var lejos: Node2D = null
	var cerca: Node2D = null
	for n: Dictionary in rit.get("notes"):
		var dt: float = float(n["t"]) - t0
		if dt > 1.2 and dt < 2.5 and lejos == null:
			lejos = n["node"]
		if dt > 0.05 and dt < 0.4 and cerca == null:
			cerca = n["node"]
	await get_tree().physics_frame
	check("invisibles: arriba se ven y cerca de la linea no", lejos != null and lejos.modulate.a > 0.9 and (cerca == null or cerca.modulate.a < 0.05),
		str([lejos.modulate.a if lejos else -1.0, cerca.modulate.a if cerca else -1.0]))
	rit.queue_free()
	await frames(2)
	## Dorado (topos): el bicho de oro vale 3 golpes.
	Kit.config["genre"] = "moles"
	Kit.config["levels"] = [{"name": "T", "map": ["ooo", "ooo"], "duration": 30.0, "target": 10, "pop": 1.2, "interval": 0.8, "max_up": 2, "friend": 0.0, "golden": true}]
	Kit.level_index = 0
	var mol: Node = (load("res://scenes/moles.tscn") as PackedScene).instantiate()
	add_child(mol)
	await frames(2)
	var nodo: Node2D = Node2D.new()
	mol.add_child(nodo)
	(mol.get("up") as Dictionary).clear()
	(mol.get("up") as Dictionary)[0] = {"node": nodo, "kind": "walker", "hp": 1, "left": 1.0, "age": 1.0, "gold": true}
	var h0: int = int(mol.get("hits"))
	mol.call("bonk", 0)
	check("dorado: el de oro vale 3 golpes", int(mol.get("hits")) == h0 + 3 and bool(mol.get("golden")), str(mol.get("hits")))
	mol.queue_free()
	await frames(2)
	## Logros: se cuentan con los eventos de cualquier genero y se cobran una vez.
	var feats_antes: Variant = Save.meta().get("feats", {})
	var m0: Dictionary = Save.meta()
	m0["feats"] = {}
	Save.data["meta"] = m0
	var w0: int = Save.wallet()
	Feats.set_meta("count_in_tests", true)
	var lv_antes: Variant = Kit.config.get("levels", [])
	Kit.config["levels"] = [{"name": "A"}, {"name": "B"}, {"name": "C"}, {"name": "D"}, {"name": "E"}]
	QA.log_event("level_start", {"level": 0})
	QA.log_event("level_complete", {"level": 0, "deaths": 0, "stars": 3})
	check("logros: primer nivel, impecable y tres estrellas", Feats.done("first_win") and Feats.done("flawless") and Feats.done("stars_3"))
	check("logros: se cobran (20 + 30 + 30 monedas)", Save.wallet() == w0 + 80, str(Save.wallet() - w0))
	QA.log_event("level_complete", {"level": 0, "deaths": 0, "stars": 3})
	check("logros: no se cobran dos veces", Save.wallet() == w0 + 80)
	QA.log_event("level_start", {"level": 1})
	for k: int in 3:
		QA.log_event("death", {"cause": "test"})
	QA.log_event("level_complete", {"level": 1, "deaths": 3, "stars": 1})
	check("logros: nunca te rindas (gana tras 3 derrotas) y la racha se corta", Feats.done("comeback") and int(Feats.state().get("streak", -1)) == 0)
	check("logros: progreso de los largos", Feats.progress("levels_10") == 3 and Feats.progress("play_20") == 2 and not Feats.done("levels_10"))
	## Logros de los modos: maraton (5 seguidos y completa) y records de contrarreloj.
	Marathon.start()
	for k: int in 5:
		Kit.level_index = k
		Marathon.on_win(10)
	check("logros: maraton de 5 niveles completa", Feats.done("marathon_5") and Feats.done("marathon_all"))
	Marathon.stop()
	Kit.level_index = 0
	TimeAttack.on_win(4, 50.0)
	TimeAttack.on_win(4, 40.0)
	TimeAttack.on_win(4, 45.0)
	check("logros: el primer tiempo no cuenta, mejorar si; uno peor no", Feats.progress("record_3") == 1)
	TimeAttack.on_win(4, 30.0)
	TimeAttack.on_win(4, 20.0)
	check("logros: tres records mejorados", Feats.done("record_3"))
	Save.set_setting("crono_4", 0.0)
	var spf: SeasonPanel = SeasonPanel.open(self, "feats")
	await frames(3)
	check("logros: pestana con cada logro", spf.find_child("Feat_comeback", true, false) != null and spf.find_child("FeatsHead", true, false) != null)
	var probl: Array[String] = UI.audit(spf.get("root"))
	check("logros: ventana sin problemas de interfaz", probl.is_empty(), str(probl.slice(0, 2)))
	spf.queue_free()
	Feats.remove_meta("count_in_tests")
	Kit.config["levels"] = lv_antes
	var m1: Dictionary = Save.meta()
	m1["feats"] = feats_antes
	m1["wallet"] = w0
	Save.data["meta"] = m1
	await frames(2)
	## Fantasma: la mejor partida se guarda y luego una figura repite ese camino.
	Kit.level_index = 0
	Save.set_setting("fantasma_0", {}, false)
	Twist.forced = ["fantasma"]
	var fake: Node2D = (load("res://qa/fake_hero_game.gd") as GDScript).new()
	add_child(fake)
	QA.log_event("level_start", {"level": 0})
	var hero: Node2D = fake.get("player")
	for k: int in 30:
		hero.position = Vector2(10.0 * float(k), 0.0)
		await get_tree().physics_frame
	check("fantasma: sin partida guardada no hay figura", fake.find_child("TwistGhost", true, false) == null)
	QA.log_event("level_complete", {"level": 0, "coins": 0, "deaths": 0})
	var best: Dictionary = Twist.ghost_best()
	check("fantasma: se guarda la partida al acabar", (best.get("p", []) as Array).size() >= 10 and float(best.get("t", 0.0)) > 0.3, str(best.get("t")))
	fake.queue_free()
	await frames(2)
	var fake2: Node2D = (load("res://qa/fake_hero_game.gd") as GDScript).new()
	add_child(fake2)
	QA.log_event("level_start", {"level": 0})
	var ghost: Node2D = fake2.find_child("TwistGhost", true, false) as Node2D
	check("fantasma: aparece la figura de la mejor partida", ghost != null)
	for k: int in 20:
		await get_tree().physics_frame
	check("fantasma: la figura repite el camino", ghost != null and ghost.global_position.x > 100.0, str(ghost.global_position if ghost != null else Vector2.ZERO))
	## Mas lento que el fantasma: no se guarda.
	for k: int in 40:
		await get_tree().physics_frame
	QA.log_event("level_complete", {"level": 0, "coins": 0, "deaths": 0})
	check("fantasma: una partida mas lenta no lo cambia", is_equal_approx(float(Twist.ghost_best().get("t", 0.0)), float(best.get("t", -1.0))))
	fake2.queue_free()
	await frames(2)
	Save.set_setting("fantasma_0", {}, false)
	Twist.forced = []
	## Saltar nivel: tras 3 derrotas se ofrece (con anuncio); tras 5, gratis.
	Kit.config["genre"] = "maze"
	Kit.config["levels"] = [{"name": "A", "map": ["###", "#C#", "#X#", "#P#", "###"]}, {"name": "B", "map": ["###", "#C#", "#.#", "#P#", "###"]}]
	Kit.level_index = 0
	var sk: Node = (load("res://scenes/maze.tscn") as PackedScene).instantiate()
	add_child(sk)
	await frames(2)
	sk.set("deaths", 1)
	var fp1: FailPanel = FailPanel.open(sk, "x", "y")
	await frames(2)
	check("saltar: con pocas derrotas no se ofrece", fp1.find_child("BtnSkip", true, false) == null)
	fp1.queue_free()
	sk.set("deaths", 5)
	var fp2: FailPanel = FailPanel.open(sk, "x", "y")
	await frames(2)
	check("saltar: tras 5 derrotas se puede, gratis", fp2.find_child("BtnSkip", true, false) != null and fp2.free_skip())
	fp2.skip_level()
	check("saltar: abre el siguiente nivel", Kit.level_index == 1 and Save.unlocked_count() >= 2)
	get_tree().paused = false
	sk.queue_free()
	Kit.config = keep
	Kit.level_index = idx


func _test_genres() -> void:
	print("- Registro de generos")
	var ok: bool = true
	var bad: String = ""
	for g: String in Genres.LIST:
		var sc: PackedScene = load(Genres.scene(g))
		if sc == null:
			ok = false
			bad += g + " "
	check("cada genero del registro tiene una escena que carga", ok, bad)
	check("puzle, torres y carreras son estrictos; plataformas no", Genres.strict("match3") and Genres.strict("tower")
		and Genres.strict("race") and not Genres.strict("platformer"))
	check("genero desconocido = plataformas", Genres.scene("no_existe") == "res://scenes/main.tscn")
	var r: Dictionary = Genres.analyze("race", {"map": ["|...."]}, 64.0, {})
	check("el registro analiza con el analizador de cada genero", (r["issues"] as Array).has("race_short"), str(r))


func _test_meta() -> void:
	print("- Progresion: cartera, premio diario y tienda")
	Save.reset_all()
	check("cartera empieza vacia", Save.wallet() == 0)
	var host: Control = Control.new()
	add_child(host)
	ResultPanel.open(host, {"stars": 3, "coins": 12, "coins_total": 20, "score": 100, "record": false})
	await frames(2)
	check("ganar un nivel llena la cartera (10 por estrella + monedas)", Save.wallet() == 42, str(Save.wallet()))
	## Bonificado opcional: duplicar el premio viendo un anuncio (simulador).
	var dbl: Button = host.find_child("BtnDouble", true, false) as Button
	check("ofrece duplicar el premio con un anuncio", dbl != null)
	if dbl != null:
		dbl.pressed.emit()
		await _wait_seconds(Ads.simulate_seconds + 0.3)
		check("el anuncio visto duplica el premio", Save.wallet() == 84, str(Save.wallet()))
		check("el boton desaparece tras usarlo", host.find_child("BtnDouble", true, false) == null)
	check("sin plugin nativo, los anuncios son simulados", not Ads.is_real())
	host.queue_free()
	Save.reset_all()
	Save.add_wallet(42)
	var day: int = 20000
	check("premio diario: primer dia 20", Save.claim_daily(day) == 20 and Save.wallet() == 62)
	check("premio diario: no se cobra dos veces el mismo dia", Save.claim_daily(day) == 0)
	check("premio diario: racha al dia siguiente", Save.claim_daily(day + 1) == 30 and Save.streak() == 2)
	check("premio diario: saltarse un dia reinicia la racha", Save.daily_pending(day + 3) == 20)
	check("tienda: sin monedas no se compra", not Save.buy_skin("neon", 300))
	Save.add_wallet(500)
	var antes: int = Save.wallet()
	check("tienda: compra con monedas", Save.buy_skin("hielo", 150) and Save.wallet() == antes - 150 and str(Save.meta()["skin"]) == "hielo")
	check("tienda: el aspecto equipado es el comprado", Skins.current()["id"] == "hielo")
	var game: Node = await start_game(test_config(["..........", "..P......G", "##########"]), 0)
	var pl: PlayerPlatformer = game.get("player")
	var mat: ShaderMaterial = pl.visual.material as ShaderMaterial
	check("tienda: el heroe sale recoloreado en el juego", mat != null and is_equal_approx(float(mat.get_shader_parameter("hue")), 0.5))
	await stop_game(game)
	check("tienda: equipar uno comprado", Save.equip_skin("original") and Skins.current()["id"] == "original")
	## Mejoras permanentes: corazon extra (+1 vida).
	Save.add_wallet(1000)
	var w0: int = Save.wallet()
	check("mejora: comprar corazon extra", Save.buy_upgrade("heart") and Save.upgrade_level("heart") == 1 and Save.wallet() == w0 - 300)
	check("mejora: el siguiente nivel cuesta mas", Save.upgrade_price("heart") == 700)
	var g2: Node = await start_game(test_config(["..........", "..P......G", "##########"]), 0)
	var pl2: PlayerPlatformer = g2.get("player")
	check("mejora: el heroe empieza con una vida mas", pl2.max_hp == 4, str(pl2.max_hp))
	await stop_game(g2)
	Save.add_wallet(1000)
	Save.buy_upgrade("heart")
	check("mejora: tope de 2", Save.upgrade_price("heart") == -1 and not Save.buy_upgrade("heart"))
	var host2: Control = Control.new()
	host2.size = Vector2(720, 1280)
	add_child(host2)
	var shop: ShopPanel = ShopPanel.open(host2)
	await _wait_seconds(1.0)
	var problems: Array[String] = UI.audit(shop.root)
	check("tienda: ventana sin problemas de interfaz", problems.is_empty(), str(problems.slice(0, 2)))
	check("tienda: un boton por aspecto", shop.find_child("Skin_neon", true, false) != null and shop.find_child("Skin_original", true, false) != null)
	var daily: DailyPanel = DailyPanel.open(host2, 40)
	await _wait_seconds(1.0)
	var p2: Array[String] = UI.audit(daily.root)
	check("premio diario: ventana sin problemas de interfaz", p2.is_empty(), str(p2.slice(0, 2)))
	host2.queue_free()
	Save.reset_all()


## 12 - Musica del juego: el titulo pone la pista "menu" en bucle; la victoria no repite.
func _test_music() -> void:
	print("- Musica")
	var tracks: Dictionary = Kit.assets.get("musica", {})
	check("manifiesto con menu, nivel y victoria", tracks.has("menu") and tracks.has("nivel") and tracks.has("victoria"), str(tracks.keys()))
	var title: Node = (load(UI.SCREEN_TITLE) as PackedScene).instantiate()
	add_child(title)
	await frames(3)
	var m: AudioStream = Audio.current_music()
	var looped: bool = m is AudioStreamWAV and (m as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD
	check("el titulo suena con la pista menu en bucle", looped, str(m))
	title.queue_free()
	Audio.play_track("victoria", false)
	await frames(2)
	var v: AudioStream = Audio.current_music()
	check("victoria suena una vez", v is AudioStreamWAV and (v as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_DISABLED)
	Audio.play_track("no_existe")
	await frames(1)
	check("una pista que no existe no rompe nada", Audio.current_music() != null)
	## Musica con IA: llega en OGG y tambien debe ir en bucle.
	tracks["prueba_ogg"] = "res://qa/tono.ogg"
	Audio.play_track("prueba_ogg")
	await frames(2)
	var o: AudioStream = Audio.current_music()
	check("musica OGG (IA) suena en bucle", o is AudioStreamOggVorbis and (o as AudioStreamOggVorbis).loop, str(o))
	Audio.play_track("prueba_ogg", false)
	await frames(2)
	var o2: AudioStream = Audio.current_music()
	check("musica OGG sin bucle cuando se pide", o2 is AudioStreamOggVorbis and not (o2 as AudioStreamOggVorbis).loop)
	tracks.erase("prueba_ogg")
	## Fondo ilustrado en la pantalla de titulo (si la fabrica lo genero).
	var ui_cfg: Dictionary = Kit.assets.get("ui", {}) as Dictionary
	var had_bg: bool = ui_cfg.has("fondo")
	ui_cfg["fondo"] = "res://qa/fondo_prueba.jpg"
	Kit.assets["ui"] = ui_cfg
	var title2: Node = (load(UI.SCREEN_TITLE) as PackedScene).instantiate()
	add_child(title2)
	await frames(2)
	var bd: TextureRect = title2.find_child("Backdrop", true, false) as TextureRect
	check("pantalla de titulo con fondo ilustrado", bd != null and bd.texture != null)
	check("titulo legible sobre el fondo", UI.audit(title2).is_empty(), str(UI.audit(title2).slice(0, 2)))
	title2.queue_free()
	if not had_bg:
		ui_cfg.erase("fondo")
	## Voz del heroe: suena en victoria, derrota e inicio (si el juego tiene voces).
	var had_voices: bool = Kit.assets.has("voces")
	var old_voices: Variant = Kit.assets.get("voces", {})
	Kit.assets["voces"] = {"victoria": "res://qa/voz_prueba.wav", "derrota": "res://qa/voz_prueba.wav", "inicio": "res://qa/voz_prueba.wav"}
	Audio.last_voice = ""
	Audio.play_voice("victoria")
	check("la voz de victoria suena", Audio.last_voice == "victoria")
	Audio.play_voice("no_existe")
	check("una voz que no existe no rompe nada", Audio.last_voice == "victoria")
	var host_v: Control = Control.new()
	add_child(host_v)
	FailPanel.open(host_v, "Uy", "")
	await frames(2)
	check("al perder, el heroe dice su frase", Audio.last_voice == "derrota")
	host_v.queue_free()
	if had_voices:
		Kit.assets["voces"] = old_voices
	else:
		Kit.assets.erase("voces")


## 11 - Un toque real de pantalla debe pulsar los botones. Los Button de Godot solo
## reaccionan al raton, por eso el proyecto necesita emulate_mouse_from_touch=true.
func _test_ui_touch() -> void:
	print("- Interfaz: toques tactiles")
	check("emulacion de raton desde toque activa", bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch")))
	UI.nav_log.clear()
	var title: Node = (load(UI.SCREEN_TITLE) as PackedScene).instantiate()
	add_child(title)
	await _wait_seconds(1.2)
	var play: Button = title.find_child("BtnPlay", true, false) as Button
	await _tap(get_viewport().get_final_transform() * play.get_global_rect().get_center())
	check("toque en Jugar abre niveles", UI.nav_log.has(UI.SCREEN_LEVELS), str(UI.nav_log))
	title.queue_free()
	await frames(2)


func _tap(window_pos: Vector2) -> void:
	var down: InputEventScreenTouch = InputEventScreenTouch.new()
	down.index = 0
	down.position = window_pos
	down.pressed = true
	Input.parse_input_event(down)
	await get_tree().process_frame
	var up: InputEventScreenTouch = down.duplicate() as InputEventScreenTouch
	up.pressed = false
	Input.parse_input_event(up)
	for i: int in 3:
		await get_tree().process_frame


## 12 - Flujo completo: titulo -> niveles -> juego -> pausa -> meta -> resultado y estrellas.
func _test_ui_game_flow() -> void:
	print("- Interfaz: flujo de juego")
	UI.nav_log.clear()
	var title: Node = (load(UI.SCREEN_TITLE) as PackedScene).instantiate()
	add_child(title)
	await frames(2)
	(title.find_child("BtnPlay", true, false) as Button).pressed.emit()
	check("titulo -> niveles", UI.nav_log.back() == UI.SCREEN_LEVELS)
	title.queue_free()
	Save.reset_all()
	var levels: Node = (load(UI.SCREEN_LEVELS) as PackedScene).instantiate()
	add_child(levels)
	await frames(2)
	var l2: Button = levels.find_child("Level2", true, false) as Button
	check("nivel 2 bloqueado al empezar", l2 != null and l2.disabled and l2.find_child("Lock", false, false) != null)
	(levels.find_child("Level1", true, false) as Button).pressed.emit()
	check("niveles -> juego", UI.nav_log.back() == UI.game_scene() and Kit.level_index == 0)
	levels.queue_free()
	await frames(1)
	## Mundos: con 7 niveles o mas, grupos de 5 con cabecera; los de despues, cerrados.
	var keep_lv: Array = Kit.config.get("levels", [])
	var many: Array = []
	for k: int in 12:
		many.append({"name": "L%d" % k, "map": ["P.C"]})
	Kit.config["levels"] = many
	var worlds: Node = (load(UI.SCREEN_LEVELS) as PackedScene).instantiate()
	add_child(worlds)
	await frames(2)
	var w3: Node = worlds.find_child("World3", true, false)
	check("mundos: 12 niveles en 3 mundos (5, 5 y 2)", worlds.find_child("WorldHeader3", true, false) != null and w3 != null and w3.get_child_count() == 2
		and worlds.find_child("WorldHeader4", true, false) == null)
	var h2: Label = (worlds.find_child("WorldHeader2", true, false) as Node).find_child("*", true, false) as Label
	check("mundos: el segundo, cerrado al empezar", (worlds.find_child("WorldHeader2", true, false) as Control).modulate.a < 1.0, str(h2))
	worlds.queue_free()
	Kit.config["levels"] = keep_lv
	await frames(1)

	var flat: Array = [
		"..............",
		"..............",
		"..P..C......G.",
		"##############",
	]
	var game: Node = await start_game(test_config(flat), 0)
	await frames(30)
	game.call("open_pause")
	await frames(2)
	var pm: PauseMenu = game.get_node_or_null("PauseMenu") as PauseMenu
	check("pausa congela el juego", pm != null and get_tree().paused)
	var player: PlayerPlatformer = game.get("player")
	var y0: Vector2 = player.global_position
	await frames(20)
	check("con pausa no se mueve nada", player.global_position == y0)
	(pm.find_child("BtnResume", true, false) as Button).pressed.emit()
	await frames(2)
	check("continuar quita la pausa", not get_tree().paused and game.get_node_or_null("PauseMenu") == null)
	Input.action_press("move_right")
	var f: int = 0
	while f < 600 and not bool(game.get("finished")):
		await frames(1)
		f += 1
	_release_all()
	check("llega a la meta", bool(game.get("finished")))
	var rp: ResultPanel = game.get("result_panel")
	check("aparece el resultado", rp != null and is_instance_valid(rp))
	await _wait_seconds(2.2)
	if rp != null:
		check("se encienden 3 estrellas", rp.stars.lit == 3, "lit=%d" % rp.stars.lit)
		check("coin count-up termina", (rp.find_child("CoinsValue", true, false) as Label).text == "1/1")
		var probs: Array[String] = UI.audit(rp.root)
		check("resultado pasa la auditoria", probs.is_empty(), str(probs))
		(rp.find_child("BtnRetry", true, false) as Button).pressed.emit()
		check("repetir vuelve al juego", UI.nav_log.back() == UI.game_scene())
	check("estrellas guardadas", Save.stars_for("0") == 3 and Save.unlocked_count() >= 2)
	await stop_game(game)
	Save.reset_all()


## 13 - Combate: pisoton, dano con retroceso e invulnerabilidad, pinchos encima, patrullas,
## voladores, combos, corazones del HUD y el analizador de enemigos.
func _test_combat() -> void:
	print("- Enemigos y combate")
	var still: Dictionary = {"walker": {"speed": 0.0}, "spiky": {"speed": 0.0}, "flyer": {"speed": 0.0, "bob": 0.0}}

	var cfg: Dictionary = test_config([
		"..........", "....P.....", "..........", "..........", "..........",
		"....E....G", "##########",
	])
	cfg["enemies"] = still
	var game: Node = await start_game(cfg, 0)
	var player: PlayerPlatformer = game.get("player")
	var bounced: bool = false
	for f: int in 90:
		await frames(1)
		if int(game.get("stomps")) > 0 and player.velocity.y < -200.0:
			bounced = true
	var list: Array[Enemy] = game.get("enemies")
	check("pisoton derrota al enemigo", int(game.get("stomps")) == 1 and (not is_instance_valid(list[0]) or not list[0].alive))
	check("pisoton hace rebotar", bounced)
	check("pisoton no quita vida", player.hp == player.max_hp, "hp=%d" % player.hp)
	check("pisoton da puntos", int(game.get("bonus")) == 100, str(game.get("bonus")))
	await stop_game(game)

	cfg = test_config(["...........", "...........", "..P.....E.G", "###########"])
	game = await start_game(cfg, 0)
	player = game.get("player")
	var hit_frame: int = -1
	var knock_left: bool = false
	for f: int in 300:
		await frames(1)
		if hit_frame < 0 and player.hp < player.max_hp:
			hit_frame = f
			await frames(1)
			knock_left = player.velocity.x < -100.0 and player.velocity.y < 0.0
			break
	check("contacto lateral quita un corazon", player.hp == player.max_hp - 1, "hp=%d" % player.hp)
	check("el golpe empuja hacia atras", knock_left)
	check("tras el golpe es invulnerable", player.invuln_left > 0.5)
	var hearts: HBoxContainer = game.find_child("Hearts", true, false) as HBoxContainer
	var full: int = 0
	for h: Node in hearts.get_children():
		if (h as UiIcon).kind == "heart":
			full += 1
	check("HUD muestra los corazones que quedan", full == player.hp, "%d llenos, hp %d" % [full, player.hp])
	var died: bool = false
	for f: int in 60 * 12:
		await frames(1)
		if int(game.get("deaths")) > 0:
			died = true
			break
	check("sin corazones se muere", died)
	await frames(40)
	check("al reaparecer recupera los corazones", player.hp == player.max_hp and player.alive)
	await stop_game(game)

	cfg = test_config(["..........", "....P.....", "..........", "..........", "..........", "....K....G", "##########"])
	cfg["enemies"] = still
	game = await start_game(cfg, 0)
	player = game.get("player")
	await frames(90)
	list = game.get("enemies")
	check("pisar al de pinchos hace dano", player.hp == player.max_hp - 1 and list[0].alive, "hp=%d" % player.hp)
	await stop_game(game)

	cfg = test_config([
		"..............", "..P...........", "##............", "..............",
		".....E........", "....####......", "..............", ".............G", "##############",
	])
	game = await start_game(cfg, 0)
	list = game.get("enemies")
	var e: Enemy = list[0]
	var y0: float = e.global_position.y
	var flips: int = 0
	var last_dir: float = e.dir
	var max_dy: float = 0.0
	await frames(10)
	y0 = e.global_position.y
	for f: int in 60 * 6:
		await frames(1)
		max_dy = maxf(max_dy, absf(e.global_position.y - y0))
		if e.dir != last_dir:
			flips += 1
			last_dir = e.dir
	check("patrulla sin caerse de la plataforma", max_dy < 2.0, "dy=%.1f" % max_dy)
	check("patrulla se da la vuelta en los bordes", flips >= 2, "%d giros" % flips)
	await stop_game(game)

	cfg = test_config(["..............", "..P...........", "##............", ".......F......", "..............", ".............G", "##############"])
	game = await start_game(cfg, 0)
	list = game.get("enemies")
	e = list[0]
	var tile: float = float(cfg.get("tile_size", 64))
	var max_dx: float = 0.0
	var moved: float = 0.0
	var lx: float = e.position.x
	for f: int in 60 * 6:
		await frames(1)
		max_dx = maxf(max_dx, absf(e.position.x - e.home.x))
		moved += absf(e.position.x - lx)
		lx = e.position.x
	check("volador se queda en su zona", max_dx <= 2.5 * tile + 4.0, "%.0f px" % max_dx)
	check("volador patrulla", moved > tile * 4.0, "%.0f px recorridos" % moved)
	await stop_game(game)

	cfg = test_config(["..............", "..P...........", "..............", "..............", "..............", "..............", ".......E.E...G", "##############"])
	cfg["enemies"] = still
	game = await start_game(cfg, 0)
	list = game.get("enemies")
	game.call("_stomp", list[0])
	game.call("_stomp", list[1])
	check("combo en el aire dobla los puntos", int(game.get("bonus")) == 300 and int(game.get("combo")) == 2, "bonus=%d" % int(game.get("bonus")))
	await stop_game(game)

	var params: Dictionary = base_config.get("player", {})
	var r1: Dictionary = LevelAnalyzer.analyze(["..P.....", "..E....G", "........", "########"], tile, params)
	check("analizador: enemigo sin suelo", (r1["issues"] as Array).has("enemy_floating"), str(r1["issues"]))
	var r2: Dictionary = LevelAnalyzer.analyze(["..........", "..P.E....G", "##########"], tile, params)
	check("analizador: enemigo encima de la salida", (r2["issues"] as Array).has("enemy_near_spawn"), str(r2["issues"]))
	var r3: Dictionary = LevelAnalyzer.analyze([
		"..........", "..........", "..........", "......#####", "P.....K...G", "##########",
	], tile, params)
	check("analizador: enemigo sin hueco para saltarlo", (r3["issues"] as Array).has("enemy_unavoidable"), str(r3["issues"]))


## 14 - Piezas nuevas: poderes, doble salto, estrella, iman, puntos de control, disparo,
## plataformas moviles y jefe final con su puerta.
func _test_extras() -> void:
	print("- Poderes, disparo, plataformas y jefe")
	var tile: float = float(base_config.get("tile_size", 64))
	var still: Dictionary = {"walker": {"speed": 0.0}, "spiky": {"speed": 0.0}, "flyer": {"speed": 0.0, "bob": 0.0}}

	## Poderes en fila: los coge todos andando.
	var cfg: Dictionary = test_config(["#................#", "#................#", "#.P.H.J.M.V.I...G#", "##################"])
	var game: Node = await start_game(cfg, 0)
	var player: PlayerPlatformer = game.get("player")
	Input.action_press("move_right")
	await frames(130)
	Input.action_release("move_right")
	check("coge los 5 poderes", int(game.get("powers_taken")) == 5, str(game.get("powers_taken")))
	check("doble salto activo", player.air_jumps == 1)
	check("velocidad: corre mas rapido", player.speed_left > 0.0)
	await stop_game(game)

	## Doble salto de verdad: un segundo impulso en el aire.
	game = await start_game(test_config(["#..........#", "#..........#", "#..........#", "#..........#", "#..........#", "#.P......G.#", "############"]), 0)
	player = game.get("player")
	await frames(20)
	player.give_power("doble_salto")
	Input.action_press("jump")
	await frames(14)
	Input.action_release("jump")
	await frames(6)
	var cayendo: bool = player.velocity.y > 0.0 and not player.is_on_floor()
	Input.action_press("jump")
	var subio: bool = false
	for i: int in 4:
		await frames(1)
		if player.velocity.y < -800.0:
			subio = true
	Input.action_release("jump")
	await frames(30)
	check("doble salto en el aire", cayendo and subio, "segundo impulso tras empezar a caer")
	await stop_game(game)

	## Estrella: tocar a un enemigo lo derriba sin perder vida.
	cfg = test_config(["#..........#", "#..........#", "#.P...E...G#", "############"])
	cfg["enemies"] = still
	game = await start_game(cfg, 0)
	player = game.get("player")
	await frames(10)
	player.give_power("estrella")
	Input.action_press("move_right")
	await frames(60)
	Input.action_release("move_right")
	var list: Array[Enemy] = game.get("enemies")
	check("estrella derriba al enemigo sin dano", (not is_instance_valid(list[0]) or not list[0].alive) and player.hp == player.max_hp)
	await stop_game(game)

	## Iman: una moneda inalcanzable se acerca sola.
	game = await start_game(test_config(["#.........#", "#.........#", "#....C....#", "#.........#", "#.........#", "#....P...G#", "###########"]), 0)
	player = game.get("player")
	await frames(10)
	player.give_power("iman")
	await frames(90)
	check("iman atrae monedas", int(game.get("coins_taken")) == 1)
	await stop_game(game)

	## Punto de control: al morir despues, reaparece ahi.
	game = await start_game(test_config(["#................#", "#................#", "#.P....R....^...G#", "##################"]), 0)
	player = game.get("player")
	Input.action_press("move_right")
	var guard: int = 0
	while int(game.get("deaths")) == 0 and guard < 300:
		await frames(1)
		guard += 1
	Input.action_release("move_right")
	await frames(40)
	check("reaparece en el punto de control", int(game.get("checkpoints_reached")) == 1 and absf(player.global_position.x - 7.5 * tile) < tile, "x=%.0f" % player.global_position.x)
	await stop_game(game)

	## Disparo: derriba a distancia.
	cfg = test_config(["#................#", "#................#", "#.P.......E.....G#", "##################"])
	cfg["enemies"] = still
	cfg["player"] = (cfg.get("player", {}) as Dictionary).duplicate()
	cfg["player"]["shoot"] = 1.0
	game = await start_game(cfg, 0)
	player = game.get("player")
	await frames(10)
	check("con disparo hay boton de fuego", game.find_child("fire", true, false) != null)
	Input.action_press("shoot")
	await frames(40)
	Input.action_release("shoot")
	list = game.get("enemies")
	check("el disparo derriba al enemigo", int(game.get("shots_hit")) >= 1 and (not is_instance_valid(list[0]) or not list[0].alive))
	await stop_game(game)

	## Plataforma movil: te lleva encima y el bot cruza el hueco con ella.
	var puente: Array = [
		"#....................#", "#....................#", "#....................#",
		"#.P................G.#", "######...==...########", "######........########",
	]
	game = await start_game(test_config(puente), 0)
	var plats: Array[MovingPlatform] = game.get("platforms")
	check("plataforma movil creada", plats.size() == 1)
	var x0: float = plats[0].global_position.x
	await frames(40)
	check("la plataforma se mueve", absf(plats[0].global_position.x - x0) > 10.0)
	var cruzo: bool = await _run_bot(game, [], 60 * 30)
	check("el bot cruza con la plataforma movil", cruzo, "muertes=%d" % int(game.get("deaths")))
	await stop_game(game)
	var r_p: Dictionary = LevelAnalyzer.analyze(puente, tile, base_config.get("player", {}))
	check("analizador: hueco con plataforma movil es completable", bool(r_p["completable"]), str(r_p["issues"]))

	## Jefe: la meta esta cerrada hasta vencerlo y el bot lo vence.
	var arena: Array = [
		"#...........................#", "#...........................#", "#...........................#",
		"#...........................#", "#...........................#", "#...........................#",
		"#.P...R..#.......B.......#..G#", "#############################",
	]
	game = await start_game(test_config(arena), 0)
	check("hay jefe y la meta esta cerrada", game.get("boss") != null and not bool(game.get("_goal_open")))
	check("barra de vida del jefe en el HUD", game.find_child("BossBar", true, false) != null)
	var vencio: bool = await _run_bot(game, [], 60 * 90)
	var st: Dictionary = game.call("bot_state")
	check("el bot vence al jefe y termina", vencio and not bool(st["boss_alive"]), "muertes=%d vida jefe=%d" % [int(st["deaths"]), int(st["boss_hp"])])
	await stop_game(game)
	var r_a: Dictionary = LevelAnalyzer.analyze(["#............#", "#............#", "#.P..#..B.#G.#", "##############"], tile, base_config.get("player", {}))
	check("analizador: arena del jefe demasiado pequena", (r_a["issues"] as Array).has("boss_arena_small"), str(r_a["issues"]))


## 30 - Mods del agente programador: cargan si heredan de la base y reciben los eventos de la partida.
func _test_mods() -> void:
	print("- Mods")
	check("un mod que no hereda de la base se rechaza", Mods.add_mod("res://qa/mod_malo.gd") == null)
	check("un mod fuera de mods/ se rechaza", Mods.add_mod("res://kit/mod_base.gd") == null)
	var m: Node = Mods.add_mod("res://qa/mod_prueba.gd")
	check("el mod de prueba carga", m != null)
	var game: Node = await start_game(test_config(["..........", "..P......G", "##########"]), 0)
	await frames(5)
	check("el mod se entera de que empieza el nivel", int(m.get("starts")) == 1 and m.get("game") == game, str(m.get("starts")))
	check("el mod recibe cada fotograma", int(m.get("ticks")) > 0)
	QA.log_event("death", {"cause": "prueba"})
	check("el mod recibe los eventos (muerte)", int(m.get("deaths")) == 1)
	check("el mod ve al heroe", (m.call("player") as Node2D) != null)
	await stop_game(game)
	Mods.remove_all()
	await frames(2)
	check("sin mods no queda nada", Mods.mods.is_empty())


## Modo 2 jugadores (Versus): partida justa como nivel extra, el segundo jugador mueve en el turno
## del rival (sin IA), cartel de quien gana y al volver a la portada se apaga.
func _test_versus() -> void:
	print("- Modo 2 jugadores")
	var keep: Dictionary = Kit.config.duplicate(true)
	check("versus: solo en juegos de tablero por turnos", Versus.supported("chess") and Versus.supported("connect") and not Versus.supported("platformer"))
	Kit.config["genre"] = "connect"
	Kit.config["levels"] = [{"name": "T", "depth": 2, "mistake": 0.1, "seed": 3}]
	Versus.start()
	check("versus: entra como nivel extra (no toca estrellas)", Kit.versus and Kit.is_extra())
	var g: Node = (load("res://scenes/connect.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(3)
	g.call("drop", 3)
	await frames(40)
	check("versus: tras el jugador 1 no juega la IA, le toca al jugador 2", str(g.get("st")["turn"]) == "Y" and g.call("can_act"), str(g.get("st")["turn"]))
	g.call("drop", 4)
	await frames(40)
	check("versus: el jugador 2 pone su ficha", str(g.get("st")["turn"]) == "R" and int(g.get("st")["moves"]) == 2, str(g.get("st")))
	for x: int in [3, 4, 3, 4, 3]:
		g.call("drop", x)
		await frames(40)
	check("versus: cuatro en raya del jugador 1 acaba con su cartel", bool(g.get("finished")) and g.find_child("FailPanel", true, false) != null)
	g.queue_free()
	await frames(2)
	Kit.config["genre"] = "chess"
	Kit.config["levels"] = [{"name": "T", "rival": 1, "quitar": ["q"], "mistake": 0.3, "seed": 3, "max_plies": 200}]
	Versus.start()
	check("versus: en ajedrez la partida es justa (sin piezas quitadas)", (Kit.current_level()["quitar"] as Array).is_empty())
	var c: Node = (load("res://scenes/chess.tscn") as PackedScene).instantiate()
	add_child(c)
	await frames(3)
	c.call("tap_cell", Vector2i(4, 6))
	c.call("tap_cell", Vector2i(4, 4))
	await frames(30)
	c.call("tap_cell", Vector2i(4, 1))
	c.call("tap_cell", Vector2i(4, 3))
	await frames(30)
	check("versus: en ajedrez mueven las negras a mano", str(c.get("st")["b"][3 * 8 + 4]) == "p" and str(c.get("st")["b"][1 * 8 + 4]) == "", str(c.get("st")["b"]))
	c.queue_free()
	await frames(2)
	Versus.stop()
	check("versus: al volver se apaga", not Kit.versus and not Kit.is_extra())
	Kit.config = keep
	Kit.level_index = 0


## Modo maraton: se abre tras unos niveles, suma al ganar, quita vidas al perder (sin saltar
## niveles), sin vidas se acaba con resumen y record, y al volver se apaga.
func _test_marathon() -> void:
	print("- Modo maraton")
	var keep: Dictionary = Kit.config.duplicate(true)
	Save.reset_all()
	Kit.config["levels"] = [{"name": "1"}, {"name": "2"}, {"name": "3"}, {"name": "4"}, {"name": "5"}]
	check("maraton: cerrada al principio", not Marathon.available())
	for i: int in 6:
		Save.unlock_level(i)
	check("maraton: abierta tras superar unos niveles", Marathon.available())
	Marathon.start()
	check("maraton: empieza en el nivel 1 con 3 vidas", Marathon.active() and Kit.level_index == 0 and Marathon.lives() == 3)
	var host: Node = Node.new()
	add_child(host)
	var r: ResultPanel = ResultPanel.open(host, {"stars": 3, "coins": 1, "coins_total": 1, "score": 500, "record": false})
	await frames(2)
	check("maraton: ganar un nivel suma", Marathon.cleared() == 1 and r.find_child("Marathon", true, false) != null)
	r.queue_free()
	var f: FailPanel = FailPanel.open(host, "X", "Y")
	await frames(2)
	check("maraton: perder quita una vida y no deja saltar el nivel", Marathon.lives() == 2 and f.find_child("BtnSkip", true, false) == null and f.find_child("BtnRetry", true, false) != null)
	f.queue_free()
	FailPanel.open(host, "X", "Y").queue_free()
	var last: FailPanel = FailPanel.open(host, "X", "Y")
	await frames(2)
	check("maraton: sin vidas se acaba con el resumen y solo volver", Marathon.lives() == 0 and last.marathon_over and last.find_child("BtnMarathonBack", true, false) != null
		and last.find_child("BtnRetry", true, false) == null)
	check("maraton: guarda el record", Marathon.record() == 1)
	host.queue_free()
	Marathon.stop()
	check("maraton: al volver se apaga", not Marathon.active())
	## Portada llena (pase, torneo online, reto, maraton): el boton de jugar sigue dentro.
	var real: Array = (keep.get("levels", []) as Array).duplicate(true)
	while not real.is_empty() and real.size() < 5:
		real.append(real[0])
	Kit.config["levels"] = real
	Kit.config["daily_twists"] = ["espejo"]
	var feats: Dictionary = (Kit.config.get("features", {}) as Dictionary).duplicate()
	feats["pase"] = true
	feats["online"] = true
	Kit.config["features"] = feats
	var keep_fake: Callable = Online.fake
	Online.fake = func(_a: Variant = null, _b: Variant = null) -> Variant: return {}
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(720, 1280)
	add_child(vp)
	var box: Control = Control.new()
	box.size = Vector2(720, 1280)
	vp.add_child(box)
	box.add_child((load(UI.SCREEN_TITLE) as PackedScene).instantiate())
	await frames(6)
	var probs: Array[String] = UI.audit(box)
	check("maraton: portada llena sin botones fuera de la pantalla " + str(probs), box.find_child("BtnMarathon", true, false) != null
		and not probs.any(func(p: String) -> bool: return p.contains("zona segura")))
	vp.queue_free()
	Online.fake = keep_fake
	Marathon.stop()
	Kit.config = keep
	Kit.level_index = 0
	Save.reset_all()


func _test_time_attack() -> void:
	print("- Modo contrarreloj")
	var keep: Dictionary = Kit.config.duplicate(true)
	Save.reset_all()
	TimeAttack.stop()
	check("contrarreloj: cerrado sin niveles superados", not TimeAttack.available())
	Save.unlock_level(1)
	check("contrarreloj: abierto tras superar un nivel", TimeAttack.available())
	check("contrarreloj: formato del tiempo", TimeAttack.fmt(41.25) == "0:41.2" or TimeAttack.fmt(41.25) == "0:41.3")
	check("contrarreloj: sin tiempo aun", TimeAttack.fmt(TimeAttack.best(0)) == "--:--")
	## Selector: el interruptor cambia estrellas por tiempos.
	var ls: Control = (load(UI.SCREEN_LEVELS) as PackedScene).instantiate() as Control
	add_child(ls)
	await frames(3)
	var btn: Button = ls.find_child("BtnTimeAttack", true, false) as Button
	var lv1: Node = ls.find_child("Level1", true, false)
	check("contrarreloj: interruptor en el selector", btn != null and lv1 != null and (lv1.get_node("Stars") as CanvasItem).visible)
	if btn != null:
		btn.button_pressed = true
		await frames(1)
	check("contrarreloj: encendido muestra los tiempos", TimeAttack.active() and lv1 != null and (lv1.get_node("Best") as CanvasItem).visible
		and not (lv1.get_node("Stars") as CanvasItem).visible)
	ls.queue_free()
	## Al ganar se guarda el record y solo si es mejor.
	var host: Node = Node.new()
	add_child(host)
	Kit.level_index = 0
	var info: Dictionary = TimeAttack.on_win(0, 30.0)
	check("contrarreloj: primer tiempo es record", bool(info["record"]) and is_equal_approx(TimeAttack.best(0), 30.0))
	info = TimeAttack.on_win(0, 35.0)
	check("contrarreloj: un tiempo peor no cambia el record", not bool(info["record"]) and is_equal_approx(TimeAttack.best(0), 30.0))
	var r: ResultPanel = ResultPanel.open(host, {"stars": 3, "coins": 1, "coins_total": 1, "score": 10, "record": false})
	await frames(2)
	check("contrarreloj: el panel de victoria ensena el tiempo", r.find_child("TimeAttack", true, false) != null)
	r.queue_free()
	host.queue_free()
	## Online: cada record sube a su tablero (1000 + nivel, puntos = 1 h - ms) y la maraton al 2000.
	var sent: Array = []
	var keep_fake: Callable = Online.fake
	var keep_feats: Dictionary = (Kit.config.get("features", {}) as Dictionary).duplicate()
	var feats_on: Dictionary = keep_feats.duplicate()
	feats_on["online"] = true
	Kit.config["features"] = feats_on
	Online.fake = func(n: String, payload: Dictionary) -> Variant:
		if n == "marcador_enviar":
			sent.append([int(payload["p_nivel"]), int(payload["p_puntos"])])
		return {"posicion": 1, "mejor": int(payload.get("p_puntos", 0))}
	Online.set_alias("Dani")
	TimeAttack.on_win(2, 12.5)
	await frames(2)
	check("contrarreloj: el record sube a su clasificacion " + str(sent), sent.has([1002, 3600000 - 12500]))
	Kit.config["levels"] = [{"name": "1"}, {"name": "2"}, {"name": "3"}, {"name": "4"}, {"name": "5"}]
	Marathon.start()
	Marathon.on_win(5)
	await frames(2)
	check("maraton: el record sube a su clasificacion " + str(sent), sent.has([2000, 1]))
	Marathon.stop()
	check("contrarreloj: tableros con su nombre y el tiempo legible", LeaderboardPanel.board_value(1002, 3600000 - 12500) == "0:12.5"
		and LeaderboardPanel.board_value(2000, 7) == "7" and LeaderboardPanel.board_value(3, 900) == "900"
		and LeaderboardPanel.board_title(2000).contains(Kit.text("mar_short", "Marat\u00f3n")))
	Online.fake = keep_fake
	Kit.config["features"] = keep_feats
	## La franja del reloj se pone en la partida y la portada lo apaga.
	var tb: CanvasLayer = TimeAttack.make_banner()
	add_child(tb)
	await frames(1)
	check("contrarreloj: franja con el reloj", tb.name == "TimeBanner" and (tb.get_node("Text") as Label).text.contains(":"))
	tb.queue_free()
	var title: Node = (load(UI.SCREEN_TITLE) as PackedScene).instantiate()
	add_child(title)
	await frames(2)
	check("contrarreloj: la portada lo apaga", not TimeAttack.active())
	title.queue_free()
	await frames(1)
	Kit.config = keep
	Kit.level_index = 0
	Save.reset_all()


## Pistas en los puzles con resolvedor: la primera gratis, luego monedas (sin anuncios) y
## pulsando solo la pista se termina el nivel.
func _test_hints() -> void:
	print("- Pistas")
	var keep: Dictionary = Kit.config.duplicate(true)
	var keep_ads: bool = Ads.enabled
	Ads.enabled = false
	Save.reset_all()
	Save.add_wallet(1000)
	var cases: Array = [
		["sort", {"name": "T", "map": ["abca", "bcbb", "acca", ".", "."], "cap": 4, "par": 9}],
		["sokoban", {"name": "T", "map": ["#######", "#..P..#", "#..B..#", "#.....#", "#..O..#", "#######"], "par": 2}],
		["stealth", {"name": "T", "map": ["X-.-.", "| | |", ".-W .", "|   |", "P-.-C"], "par": 8}],
	]
	for c: Array in cases:
		var genre: String = c[0]
		Kit.config["genre"] = genre
		Kit.config["levels"] = [c[1]]
		Kit.level_index = 0
		var g: Node = (load("res://scenes/%s.tscn" % genre) as PackedScene).instantiate()
		add_child(g)
		await frames(2)
		g.set("fast", true)
		var btn: Button = g.find_child("BtnHint", true, false) as Button
		check("pistas %s: boton de pista" % genre, btn != null)
		var used: int = 0
		var charged: Array[int] = []
		for k: int in 40:
			if bool(g.get("finished")):
				break
			var before: int = Save.wallet()
			await g.call("use_hint")
			if charged.size() < 2:
				charged.append(before - Save.wallet())
			used += 1
			for f: int in 30:
				await get_tree().physics_frame
				if bool(g.get("finished")) or (g.has_method("can_move") and bool(g.call("can_move")) and (g.get("_hint_steps") == null or (g.get("_hint_steps") as Array).is_empty())):
					break
		check("pistas %s: solo con pistas se gana (%d)" % [genre, used], bool(g.get("finished")))
		check("pistas %s: la primera gratis y la siguiente a %d monedas" % [genre, Hint.COST], charged.size() == 2 and charged[0] == 0 and charged[1] == Hint.COST
			and int(g.get_meta("hints_used", 0)) == used, str(charged))
		if g.get("result_panel") != null:
			(g.get("result_panel") as Node).queue_free()
		g.queue_free()
		await frames(2)
	## Sin monedas ni anuncios no hay pista (y no se cobra).
	Kit.config["genre"] = "sort"
	Kit.config["levels"] = [cases[0][1]]
	var g2: Node = (load("res://scenes/sort.tscn") as PackedScene).instantiate()
	add_child(g2)
	await frames(2)
	g2.set_meta("hints_used", 1)
	Save.add_wallet(-Save.wallet())
	await g2.call("use_hint")
	check("pistas: sin monedas no se da", int(g2.get("moves")) == 0 and Hint.price(g2) == "")
	g2.queue_free()
	await frames(2)
	Ads.enabled = keep_ads
	Kit.config = keep
	Kit.level_index = 0
	Save.reset_all()


## Cartas coleccionables: coleccion, premio por nivel, mazo propio y su editor.
func _test_ccg_deck() -> void:
	print("- Coleccion y mazo de cartas")
	var keep: Dictionary = Kit.config.duplicate(true)
	Save.reset_all()
	var base: Array = ["recluta", "recluta", "lobo", "escudero", "arquera", "arquera", "guardia", "jinete", "paladin", "ogro",
		"chispa", "chispa", "bola_fuego", "pocion", "estudio", "bendicion", "muro", "tormenta", "jinete", "ogro"]
	Kit.config["genre"] = "ccg"
	Kit.config["levels"] = [{"name": "A", "deck": base, "foe_deck": base, "hp": 30, "foe_hp": 15, "seed": 3}, {"name": "B", "deck": base, "foe_deck": base}]
	Kit.level_index = 0
	var have: Dictionary = CcgCollection.owned()
	check("cartas: empiezas con el mazo del nivel 1", CcgCollection.total(have) == 20 and int(have.get("recluta", 0)) == 2 and not have.has("dragon"))
	var c1: String = CcgCollection.reward(0)
	check("cartas: superar un nivel da una carta", c1 == "bola_fuego" and int(CcgCollection.owned()["bola_fuego"]) == 2)
	check("cartas: el mismo nivel no la da dos veces", CcgCollection.reward(0) == "")
	check("cartas: otro nivel da la siguiente", CcgCollection.reward(1) == "paladin")
	var mine: Array = base.duplicate()
	mine[0] = "bola_fuego"
	check("cartas: mazo valido con tus cartas", CcgCollection.valid(mine))
	var two_dragons: Array = base.duplicate()
	two_dragons[0] = "dragon"
	two_dragons[1] = "dragon"
	check("cartas: no vale lo que no tienes ni de mas", not CcgCollection.valid(two_dragons) and not CcgCollection.valid(base.slice(0, 19)))
	check("cartas: guardar solo un mazo valido", not CcgCollection.save_deck(two_dragons) and CcgCollection.save_deck(mine))
	var lv0: Dictionary = Kit.config["levels"][0]
	check("cartas: la campana usa tu mazo", CcgCollection.deck_for(lv0, true) == mine)
	var tm: bool = UI.test_mode
	UI.test_mode = true
	check("cartas: bots y pruebas usan el del nivel", CcgCollection.deck_for(lv0) == base)
	UI.test_mode = tm
	## Editor: quitar deja 19 (no se puede guardar), poner vuelve a 20.
	var p: CcgDeckPanel = CcgDeckPanel.open(self)
	await frames(2)
	var cnt: Label = p.find_child("DeckCount", true, false) as Label
	var save_b: Button = p.find_child("BtnDeckSave", true, false) as Button
	check("cartas: el editor abre con tu mazo (20/20)", cnt != null and cnt.text.contains("20/20") and not save_b.disabled)
	var row: Node = p.find_child("Card_recluta", true, false)
	(row.get_node("Minus") as Button).pressed.emit()
	check("cartas: con 19 no se guarda", cnt.text.contains("19/20") and save_b.disabled)
	var row2: Node = p.find_child("Card_paladin", true, false)
	(row2.get_node("Plus") as Button).pressed.emit()
	check("cartas: poner otra carta tuya", cnt.text.contains("20/20") and not save_b.disabled)
	var probl: Array[String] = UI.audit(p.get("root"))
	check("cartas: editor sin problemas de interfaz", probl.is_empty(), str(probl.slice(0, 3)))
	save_b.pressed.emit()
	await frames(1)
	check("cartas: se guarda el mazo nuevo", CcgCollection.deck().count("paladin") == 2 and CcgCollection.deck().count("recluta") == 0)
	var title: Node = (load(UI.SCREEN_TITLE) as PackedScene).instantiate()
	add_child(title)
	await frames(2)
	check("cartas: boton Mazo en la portada", title.find_child("BtnDeck", true, false) != null)
	title.queue_free()
	await frames(1)
	Kit.config = keep
	Kit.level_index = 0
	Save.reset_all()


## Lucha: combos (cancelar el golpe que conecta en uno mas fuerte) y el bot sigue ganando.
func _test_fighter_combo() -> void:
	print("- Combos de lucha")
	var M: GDScript = load("res://kit/fighter/fighter_map.gd")
	var lv: Dictionary = {"hp": 100, "foe_hp": 80, "ai": 0.0, "round_time": 60, "foe_style": "rusher", "seed": 2}
	var none: Dictionary = {"dir": 0, "jump": false, "block": false, "attack": ""}
	var st: Dictionary = M.new_state(lv)
	st["pause"] = 0
	st["f"][0]["x"] = 50.0
	st["f"][1]["x"] = 57.0
	M.tick(st, none.merged({"attack": "punch"}, true), none)
	M.tick(st, none, none)
	M.tick(st, none.merged({"attack": "kick"}, true), none)
	for k: int in 14:
		M.tick(st, none, none)
	var combos: Array = (st["log"] as Array).filter(func(e: Dictionary) -> bool: return str(e["k"]) == "combo")
	check("combos: punetazo y patada encadenados", combos.size() == 1 and int(combos[0]["n"]) == 2 and int(st["best_combo"]) == 2, str(st["log"]))
	check("combos: el segundo golpe pega algo menos (6 + 9)", int(st["f"][1]["hp"]) == 80 - 6 - 9, str(st["f"][1]["hp"]))
	## Sin conectar no se cancela: patada al aire tras un punetazo que falla.
	var miss: Dictionary = M.new_state(lv)
	miss["pause"] = 0
	M.tick(miss, none.merged({"attack": "punch"}, true), none)
	M.tick(miss, none.merged({"attack": "kick"}, true), none)
	check("combos: si no conecta no hay cancelacion", str(miss["f"][0]["move"]) == "punch")
	check("combos: no se cancela hacia uno mas flojo", not M.can_chain({"state": "attack", "hit_done": true, "y": 0.0, "move": "kick", "meter": 0}, "punch")
		and not M.can_chain({"state": "attack", "hit_done": true, "y": 0.0, "move": "kick", "meter": 10}, "special")
		and M.can_chain({"state": "attack", "hit_done": true, "y": 0.0, "move": "kick", "meter": 60}, "special"))
	var won: int = 0
	var best: int = 0
	for sd: int in 6:
		var r: Dictionary = M.bot_play({"hp": 100, "foe_hp": 100, "ai": 0.6, "round_time": 60, "foe_style": ["rusher", "zoner", "counter"][sd % 3], "seed": sd + 1})
		if bool(r["won"]):
			won += 1
	check("combos: el bot sigue ganando a rivales listos (%d/6)" % won, won >= 5)
	await frames(1)


## Metroidvania: mapa grande con las salas visitadas (pausa el juego y lo devuelve al cerrar).
func _test_metroid_map() -> void:
	print("- Mapa del metroidvania")
	var M: GDScript = load("res://kit/metroid/metroid_map.gd")
	var rows: Array = []
	for y: int in 21:
		var r: String = ""
		for x: int in 29:
			r += "#" if y == 0 or y == 20 or x == 0 or x == 28 or y == 10 and x < 20 else "."
		rows.append(r)
	rows[9] = rows[9].substr(0, 2) + "P" + rows[9].substr(3, 10) + "$" + rows[9].substr(14)
	rows[19] = rows[19].substr(0, 26) + "G" + rows[19].substr(27)
	var st: Dictionary = M.new_state({"map": rows, "hp": 3})
	var host: Node = Node.new()
	add_child(host)
	var p: MetroidMapPanel = MetroidMapPanel.open(host, st)
	await frames(2)
	check("mapa: abre en pausa con las salas exploradas", get_tree().paused and (p.find_child("MapInfo", true, false) as Label).text.contains("/4"))
	var m: Control = p.find_child("Map", true, false) as Control
	check("mapa: el dibujo cabe en la pantalla", m != null and m.size.x <= 620.0 and m.size.x > 200.0)
	var probl: Array[String] = UI.audit(p.get("root"))
	check("mapa: sin problemas de interfaz", probl.is_empty(), str(probl.slice(0, 3)))
	p.close()
	await frames(1)
	check("mapa: al cerrar sigue el juego", not get_tree().paused)
	host.queue_free()
	await frames(1)


## Roguelike: explorar solo recoge lo que ve, termina en la escalera y se para con monstruos.
func _test_crawl_explore() -> void:
	print("- Explorar en el roguelike")
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "crawl"
	Kit.config["levels"] = [{"name": "T", "map": ["##########", "#P...!...#", "#.######.#", "#.#$...#.#", "#.#.##.#.#", "#...#..#>#", "##########"], "hp": 10, "atk": 3, "def": 0, "sight": 4}]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/crawl.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	g.set("fast", true)
	check("explorar: boton en la partida", g.find_child("BtnExplore", true, false) != null)
	g.call("explore")
	check("explorar: se pone en marcha", bool(g.get("exploring")))
	for f: int in 900:
		await get_tree().physics_frame
		if bool(g.get("finished")) or not bool(g.get("exploring")):
			break
	var st: Dictionary = g.get("st")
	check("explorar: coge todo y baja la escalera", bool(g.get("finished")) and (st["items"] as Dictionary).is_empty(), str(st["items"]))
	if g.get("result_panel") != null:
		(g.get("result_panel") as Node).queue_free()
	g.queue_free()
	await frames(2)
	## Con un monstruo despierto a la vista no arranca.
	var M: GDScript = load("res://kit/crawl/crawl_map.gd")
	var st2: Dictionary = M.new_state({"map": ["#######", "#P..g.#", "#######"], "hp": 10, "atk": 3, "sight": 5})
	for m: Variant in st2["mons"]:
		(m as Dictionary)["awake"] = true
	check("explorar: con peligro a la vista no se mueve", M.danger(st2) and M.explore_path(st2).is_empty())
	Kit.config = keep
	Kit.level_index = 0


## Tactica: la prevision de dano coincide con el ataque real y la zona de peligro del rival.
func _test_tactics_preview() -> void:
	print("- Tactica: prevision y peligro")
	var M: GDScript = load("res://kit/tactics/tactics_map.gd")
	var lv: Dictionary = {"map": ["H.....", "......", ".f....", ".....h"], "turns": 20,
		"units": [{"t": "inf", "x": 1, "y": 1, "side": 1}, {"t": "inf", "x": 2, "y": 1, "side": 2}, {"t": "art", "x": 5, "y": 2, "side": 2}, {"t": "tank", "x": 0, "y": 3, "side": 1}]}
	var st: Dictionary = M.new_state(lv)
	var me: Dictionary = M.unit_at(st, Vector2i(1, 1))
	var foe: Dictionary = M.unit_at(st, Vector2i(2, 1))
	var pv: Array = M.preview(st, me, foe)
	var hp_foe: int = int(foe["hp"])
	var hp_me: int = int(me["hp"])
	M.move(st, int(me["id"]), Vector2i(1, 1))
	M.attack(st, int(me["id"]), int(foe["id"]))
	check("tactica: la prevision acierta dano y contraataque " + str(pv), hp_foe - int(foe["hp"]) == int(pv[0]) and hp_me - int(me["hp"]) == int(pv[1]) and int(pv[1]) > 0)
	var art: Dictionary = M.unit_at(st, Vector2i(5, 2))
	var z: Dictionary = M.threat(st, art)
	check("tactica: la artilleria amenaza de 2 a 3 casillas sin moverse", z.has(Vector2i(3, 2)) and z.has(Vector2i(5, 0)) and not z.has(Vector2i(4, 2)) and not z.has(Vector2i(1, 2)))
	var st2: Dictionary = M.new_state(lv)
	var z2: Dictionary = M.threat(st2, M.unit_at(st2, Vector2i(2, 1)))
	check("tactica: la infanteria amenaza donde llega y una mas", z2.has(Vector2i(5, 1)) and z2.has(Vector2i(2, 3)) and not z2.has(Vector2i(5, 3)))
	await frames(1)


## Batalla automatica: sinergias de tu ejercito y velocidad del combate.
func _test_autochess_synergy() -> void:
	print("- Sinergias de la batalla automatica")
	var M: GDScript = load("res://kit/autochess/autochess_map.gd")
	var st: Dictionary = M.new_state({"rounds": [[{"t": "warrior", "x": 2, "y": 1}]], "lives": 3, "gold": 10, "seed": 1, "slots": 5})
	st["board"] = [{"id": 1, "t": "warrior", "s": 1, "x": 1, "y": 6}]
	check("sinergias: con uno no hay", M.synergies(st).is_empty())
	st["board"].append({"id": 2, "t": "warrior", "s": 1, "x": 2, "y": 6})
	st["board"].append({"id": 3, "t": "archer", "s": 1, "x": 3, "y": 7})
	var fs: Array = M.fighters(st)
	var w: Dictionary = fs[0]
	var a: Dictionary = fs[2]
	var foe: Dictionary = fs[3]
	check("sinergias: dos guerreros ganan vida", M.synergies(st) == ["warrior"] and is_equal_approx(float(w["max"]), 60.0 * 1.25) and is_equal_approx(float(foe["max"]), 60.0))
	check("sinergias: la arquera sola no cambia", not a.has("rate"))
	check("sinergias: texto corto", M.synergy_text("warrior").contains("25") and M.synergy_text("archer").contains("25"))
	st["board"].append({"id": 4, "t": "archer", "s": 1, "x": 4, "y": 7})
	var fs2: Array = M.fighters(st)
	check("sinergias: dos arqueras disparan mas rapido", is_equal_approx(float(fs2[2].get("rate", 1.0)), 0.8))
	## Velocidad: el boton cambia x1 -> x2 -> x3 -> x1 y se recuerda.
	var keep: Dictionary = Kit.config.duplicate(true)
	Save.set_setting("ac_speed", 1)
	Kit.config["genre"] = "autochess"
	Kit.config["levels"] = [{"name": "T", "rounds": [[{"t": "warrior", "x": 2, "y": 1}]], "lives": 3, "gold": 10, "seed": 1, "slots": 5}]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/autochess.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	var sb: Button = g.find_child("BtnSpeed", true, false) as Button
	sb.pressed.emit()
	check("velocidad: x2 y se guarda", int(g.get("speed")) == 2 and sb.text == "x2" and int(Save.get_setting("ac_speed", 0)) == 2)
	sb.pressed.emit()
	sb.pressed.emit()
	check("velocidad: vuelve a x1", int(g.get("speed")) == 1)
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0
	Save.set_setting("ac_speed", 1)


## Aventura: historial de lo dicho y elegido, y coleccion de finales por capitulo.
func _test_tale_extras() -> void:
	print("- Aventura: historial y finales")
	var keep: Dictionary = Kit.config.duplicate(true)
	Save.reset_all()
	var lv: Dictionary = {"name": "C1", "title": "1. La prueba", "map": ["historia"],
		"scenes": [
			{"id": "a", "who": "narrador", "text": "Empieza la aventura.", "options": [{"text": "Ser valiente", "to": "b", "fx": {"valor": 1}}, {"text": "Irte", "to": "FIN_MALO"}]},
			{"id": "b", "who": "heroe", "text": "Una puerta cerrada.", "options": [{"text": "Romperla", "to": "FIN_BUENO", "need": {"stat": "valor", "min": 1}}, {"text": "Volver", "to": "FIN_REGULAR"}]}],
		"endings": {"bueno": "Bien.", "regular": "Regular.", "malo": "Mal."}}
	Kit.config["genre"] = "tale"
	Kit.config["levels"] = [lv]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/tale.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	g.set("fast", true)
	g.call("_reveal")
	g.call("choose", 0)
	g.call("_reveal")
	var h: Array = g.get("history")
	check("historial: guarda lo dicho y lo elegido", h.size() == 3 and str(h[1].get("choice", "")) == "Ser valiente" and str(h[2]["text"]) == "Una puerta cerrada.", str(h))
	g.call("open_history")
	await frames(2)
	var lp: Node = g.get_node_or_null("TaleLogPanel")
	check("historial: se abre con las lineas", lp != null and (lp.find_child("Lines", true, false) as Node).get_child_count() == 3)
	var probl: Array[String] = UI.audit(lp.get("root")) if lp != null else []
	check("historial: sin problemas de interfaz", probl.is_empty(), str(probl.slice(0, 3)))
	if lp != null:
		lp.queue_free()
	await frames(1)
	g.call("choose", 0)
	for f: int in 20:
		await frames(1)
		if g.get("result_panel") != null:
			break
	var rp: Node = g.get("result_panel")
	check("finales: el panel cuenta el final descubierto", rp != null and rp.find_child("Endings", true, false) != null
		and str((rp.find_child("Endings", true, false) as Label).text).contains("1/3"))
	var TG: GDScript = load("res://kit/tale/tale_game.gd")
	check("finales: no se repiten y se suman", TG.endings_found(0) == ["bueno"] and not TG.record_ending(0, "bueno") and TG.record_ending(0, "malo") and TG.endings_found(0).size() == 2)
	if rp != null:
		rp.queue_free()
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0
	Save.reset_all()


## Torres: punteria de cada torre y aviso de la siguiente oleada.
func _test_tower_aim() -> void:
	print("- Torres: punteria y siguiente oleada")
	var game: Node = await start_game(tower_config(), 0)
	game.set("gold", 500)
	game.call("build", Vector2i(2, 1), "rayo")
	game.call("tap", Vector2i(2, 1))
	await frames(1)
	var aim: Button = game.find_child("BtnAim", true, false) as Button
	check("punteria: boton al tocar la torre", aim != null)
	var problems: Array[String] = UI.audit(game.get_node("Hud").get_child(0))
	check("punteria: la barra con 3 botones cabe", problems.is_empty(), str(problems.slice(0, 2)))
	game.call("cycle_aim", Vector2i(2, 1))
	check("punteria: cambia a la de mas vida", str((game.get("towers") as Dictionary)[Vector2i(2, 1)]["aim"]) == "strong")
	var near: Node2D = Node2D.new()
	var far: Node2D = Node2D.new()
	var from: Vector2 = game.call("cell_pos", Vector2i(2, 1))
	near.position = from + Vector2(10, 0)
	far.position = from + Vector2(40, 0)
	var es: Array = game.get("enemies")
	es.clear()
	es.append({"node": near, "kind": "walker", "hp": 3.0, "max": 6.0, "d": 90.0, "slow": 0.0})
	es.append({"node": far, "kind": "spiky", "hp": 14.0, "max": 16.0, "d": 40.0, "slow": 0.0})
	var t: Dictionary = (game.get("towers") as Dictionary)[Vector2i(2, 1)]
	check("punteria: fuerte elige al de mas vida", str(game.call("pick_target", t, from, 500.0)["kind"]) == "spiky")
	t["aim"] = "first"
	check("punteria: primero elige al mas adelantado", str(game.call("pick_target", t, from, 500.0)["kind"]) == "walker")
	t["aim"] = "close"
	far.position = from + Vector2(5, 0)
	check("punteria: cerca elige al mas cercano", str(game.call("pick_target", t, from, 500.0)["kind"]) == "spiky")
	es.clear()
	near.free()
	far.free()
	var pv: String = game.call("wave_preview", 0)
	check("siguiente oleada: dice cuantos vienen " + pv, pv != "" and pv.contains(str((game.call("wave_plan", 0) as Array).size())))
	game.set("selected", Vector2i(-1, -1))
	game.call("_refresh_actions")
	await frames(1)
	var nb: Button = game.find_child("BtnNextWave", true, false) as Button
	check("siguiente oleada: en el boton de lanzar", nb != null and nb.text.contains(pv))
	await stop_game(game)


## Mazmorras: pantalla de equipo y talentos comprados con monedas.
func _test_dungeon_gear() -> void:
	print("- Mazmorras: equipo y talentos")
	var keep: Dictionary = Kit.config.duplicate(true)
	Save.reset_all()
	Save.add_wallet(200)
	Save.meta()["dungeon_gear"] = {"arma": {"slot": "arma", "rarity": 2, "bonus": 38.0}}
	check("talentos: empiezan a cero y cuestan monedas", DungeonGearPanel.level_of("vida") == 0 and DungeonGearPanel.cost("vida") == DungeonGearPanel.BASE_COST)
	check("talentos: comprar sube el nivel y gasta", DungeonGearPanel.buy("vida") and DungeonGearPanel.level_of("vida") == 1 and Save.wallet() == 200 - DungeonGearPanel.BASE_COST)
	check("talentos: el siguiente cuesta mas", DungeonGearPanel.cost("vida") == DungeonGearPanel.BASE_COST * 2)
	check("talentos: sin monedas no se compra", DungeonGearPanel.buy("vida") and not DungeonGearPanel.buy("vida") and DungeonGearPanel.level_of("vida") == 2)
	var tm: bool = UI.test_mode
	UI.test_mode = false
	var qa_on: bool = QA.enabled
	QA.enabled = false
	var m: float = DungeonGearPanel.mult("vida")
	QA.enabled = qa_on
	UI.test_mode = true
	check("talentos: dan su extra, pero no a bots y pruebas", is_equal_approx(m, 1.1) and is_equal_approx(DungeonGearPanel.mult("vida"), 1.0))
	UI.test_mode = tm
	var p: DungeonGearPanel = DungeonGearPanel.open(self)
	await frames(2)
	var arma: Label = p.find_child("Slot_arma", true, false) as Label
	check("equipo: ensena lo que llevas y lo que falta", arma != null and arma.text.contains("38") and (p.find_child("Slot_anillo", true, false) as Label).text != "")
	var probl: Array[String] = UI.audit(p.get("root"))
	check("equipo: sin problemas de interfaz", probl.is_empty(), str(probl.slice(0, 3)))
	p.queue_free()
	Kit.config["genre"] = "dungeon"
	var title: Node = (load(UI.SCREEN_TITLE) as PackedScene).instantiate()
	add_child(title)
	await frames(2)
	check("equipo: boton en la portada", title.find_child("BtnGear", true, false) != null)
	title.queue_free()
	await frames(1)
	Kit.config = keep
	Save.reset_all()


## Reino: la prevision de la batalla coincide con lo que pasa al atacar.
func _test_realm_forecast() -> void:
	print("- Reino: prevision de batalla")
	var M: GDScript = load("res://kit/realm/realm_map.gd")
	var st: Dictionary = M.new_state({"par": 240, "cap": 5, "camps": [{"at": 0.2, "str": 0.6, "mix": [1, 0, 0]}, {"at": 0.5, "str": 0.7, "mix": [1, 1, 0]}, {"at": 0.8, "str": 0.9, "mix": [1, 1, 1]}]})
	var ok: int = 0
	var cases: int = 0
	for k: int in 6:
		for t: String in M.TYPES:
			st["army"][t] = 4.0 + 9.0 * float(k)
		var fc: Dictionary = M.forecast(st)
		var before: float = M.total_army(st)
		var r: Dictionary = M.attack(st)
		if r.is_empty():
			break
		cases += 1
		if bool(fc["win"]) == bool(r["win"]) and int(fc["lost"]) == int(ceil(before - M.total_army(st) - 0.0001)):
			ok += 1
	check("reino: la prevision acierta ganar o perder y las bajas (%d/%d)" % [ok, cases], cases >= 2 and ok == cases)
	await frames(1)


## Como se juega: reglas de los generos complejos, su ventana y el boton del menu de pausa.
func _test_howto() -> void:
	print("- Como se juega")
	var keep: Dictionary = Kit.config.duplicate(true)
	var all_three: bool = true
	for k: Variant in HowTo.RULES:
		if HowTo.lines(str(k)).size() != 3:
			all_three = false
	check("como se juega: tres reglas en cada genero", all_three and HowTo.RULES.size() >= 16 and HowTo.has("tactics") and not HowTo.has("platformer"))
	Save.reset_all()
	Kit.config["genre"] = "tactics"
	var host: Node = Node.new()
	add_child(host)
	var tm: bool = UI.test_mode
	UI.test_mode = true
	HowTo.maybe_show(host)
	await frames(2)
	check("como se juega: no sale con los bots ni en las pruebas", host.get_node_or_null("HowToPanel") == null and not HowTo.seen("tactics"))
	UI.test_mode = false
	HowTo.enabled = true
	var qa_on2: bool = QA.enabled
	QA.enabled = false
	HowTo.maybe_show(host)
	await frames(2)
	QA.enabled = qa_on2
	var auto: Node = host.get_node_or_null("HowToPanel")
	check("como se juega: la primera vez sale sola y queda vista", auto != null and HowTo.seen("tactics"))
	if auto != null:
		(auto as HowToPanel).close()
		await frames(1)
	UI.test_mode = tm
	HowTo.enabled = false
	var p: HowToPanel = HowToPanel.open(host)
	await frames(2)
	check("como se juega: ventana con las 3 reglas y en pausa", p.find_child("Rule3", true, false) != null and get_tree().paused)
	var probl: Array[String] = UI.audit(p.get("root"))
	check("como se juega: sin problemas de interfaz", probl.is_empty(), str(probl.slice(0, 3)))
	p.close()
	await frames(1)
	check("como se juega: al cerrar sigue el juego", not get_tree().paused)
	var pm: PauseMenu = PauseMenu.open(host)
	await frames(2)
	check("como se juega: boton en el menu de pausa", pm.find_child("BtnHowTo", true, false) != null)
	pm.queue_free()
	get_tree().paused = false
	host.queue_free()
	await frames(1)
	Kit.config = keep
	Save.reset_all()


## Tutorial interactivo: avanza con lo que hace el jugador (cambios, botones, eventos y toques).
func _test_tutorial() -> void:
	print("- Tutorial interactivo")
	var keep: Dictionary = Kit.config.duplicate(true)
	check("tutorial: pasos de su genero", Tutorial.steps_for("tower").size() == 4 and Tutorial.steps_for("platformer").is_empty())
	Kit.config["tutorial"] = [{"text": "Hola", "target": "", "until": "tap"}]
	check("tutorial: un juego puede traer el suyo", Tutorial.steps_for("tower").size() == 1 and str(Tutorial.steps_for("tower")[0]["text"]) == "Hola")
	Kit.config["tutorial"] = [{"text": "Toca la arena"}, {"text": "Elige un canon"}]
	var own: Array = Tutorial.steps_for("tower")
	check("tutorial: textos propios con los pasos del genero", own.size() == 2 and str(own[1]["target"]) == "Build_rayo" and str(own[1]["until"]) == "event:tower_build")
	var keep_i18n: Variant = Kit.config.get("i18n", {})
	Kit.config["i18n"] = {Kit.lang(): {"_tutorial": ["Tap the sand", "Pick a cannon"]}}
	check("tutorial: con su traduccion", str(Tutorial.steps_for("tower")[0]["text"]) == "Tap the sand")
	Kit.config["i18n"] = keep_i18n
	Kit.config.erase("tutorial")
	check("tutorial: no sale con bots ni en las pruebas", not Tutorial.will_run("tower"))
	## Tubos: tocar un tubo (cambia selected), verter (cambia moves) y un toque final.
	Kit.config["genre"] = "sort"
	Kit.config["levels"] = [{"name": "T", "map": ["abca", "bcbb", "acca", ".", "."], "cap": 4, "par": 9}]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/sort.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	g.set("fast", true)
	var t: Tutorial = Tutorial.new()
	t.game = g
	t.steps = Tutorial.steps_for("sort")
	g.add_child(t)
	await frames(1)
	check("tutorial: empieza en el paso 1 con su texto", t.index == 0 and (t.find_child("Text", true, false) as Label).text != "")
	g.call("tap", 0)
	await frames(2)
	check("tutorial: elegir un tubo pasa al paso 2", t.index == 1)
	g.call("tap", 3)
	await frames(2)
	check("tutorial: verter pasa al paso 3 (senala Deshacer)", t.index == 2 and t._target != null and t._target.name == "BtnUndo")
	t._armed = 0.0
	var ev: InputEventMouseButton = InputEventMouseButton.new()
	ev.pressed = true
	t._input(ev)
	await frames(2)
	check("tutorial: un toque lo termina", not is_instance_valid(t) or t.is_queued_for_deletion())
	## Boton y evento.
	var t2: Tutorial = Tutorial.new()
	t2.game = g
	t2.steps = [{"text": "Deshaz", "target": "BtnUndo", "until": "press"}, {"text": "Evento", "target": "", "until": "event:prueba_tut"}]
	g.add_child(t2)
	await frames(1)
	(g.find_child("BtnUndo", true, false) as Button).pressed.emit()
	await frames(1)
	check("tutorial: pulsar el boton senalado avanza", t2.index == 1)
	QA.log_event("prueba_tut", {})
	await frames(2)
	check("tutorial: un evento de la partida avanza", not is_instance_valid(t2) or t2.is_queued_for_deletion())
	g.queue_free()
	await frames(2)
	Kit.config = keep
	Kit.level_index = 0


## Monetizacion: perfil por tipo de juego, banner con su hueco, cadencia de intersticiales,
## segunda oportunidad con anuncio y pack de inicio.
func _test_monetize() -> void:
	print("- Monetizacion")
	var keep: Dictionary = Kit.config.duplicate(true)
	var keep_enabled: bool = Ads.enabled
	var keep_sim: float = Ads.simulate_seconds
	check("monetizacion: perfil por genero", Monetize.profile_of("tower") == "estrategia" and Monetize.profile_of("match3") == "puzle"
		and Monetize.profile_of("chess") == "tablero" and Monetize.profile_of("nada") == "arcade")
	Kit.config["genre"] = "match3"
	check("monetizacion: puzle con banner en partida e intersticial cada 2", Monetize.profile_name() == "puzle" and bool(Monetize.p("banner_game")) and int(Monetize.p("inter_every")) == 2)
	Kit.config["monetization"] = {"profile": "estrategia", "inter_max": 2}
	check("monetizacion: el juego puede cambiar perfil y valores", Monetize.profile_name() == "estrategia" and int(Monetize.p("inter_max")) == 2 and not bool(Monetize.p("banner_menu")))
	Kit.config.erase("monetization")
	Kit.config["ads"] = {"child_directed": true}
	check("monetizacion: los peques sin intersticial ni banner", Monetize.profile_name() == "infantil" and int(Monetize.p("inter_every")) == 0 and not bool(Monetize.p("banner_menu")))
	Kit.config.erase("ads")
	## Banner: hueco solo donde toca (y no en capturas ni pruebas, salvo el validador).
	Ads.enabled = true
	Ads.banner_kind = "game"
	Ads.audit_banner = false
	var tm: bool = UI.test_mode
	UI.test_mode = true
	check("banner: sin hueco en pruebas y capturas", Ads.banner_space(get_viewport()) == 0.0)
	UI.test_mode = tm
	Ads.audit_banner = true
	check("banner: el validador cuenta su hueco en un puzle", Ads.banner_space(get_viewport()) > 50.0 and UI.safe_insets(get_viewport())["bottom"] > 50.0)
	Kit.config["ads"] = {"android": {"interstitial": "a", "rewarded": "b", "banner": ""}}
	check("banner: sin bloque propio en la tienda, no hay banner", not Ads.has_unit("banner") and Ads.banner_space(get_viewport()) == 0.0)
	Kit.config.erase("ads")
	Kit.config["genre"] = "tower"
	check("banner: la estrategia no lleva banner", Ads.banner_space(get_viewport()) == 0.0)
	Ads.audit_banner = false
	## Intersticial cada 3 niveles en estrategia.
	Ads.debug_shift_session(1000.0)
	var shown: Array[bool] = []
	for k: int in 3:
		Ads._level_ends = k
		shown.append(Ads.can_show_interstitial("level_end"))
	check("intersticial: en estrategia uno de cada 3 niveles", shown == [true, false, false], str(shown))
	## Segunda oportunidad.
	Kit.config["genre"] = "shooter"
	Ads.simulate_seconds = 0.01
	var host: Node2D = Node2D.new()
	host.set_script(load("res://qa/revive_dummy.gd"))
	add_child(host)
	var fp: FailPanel = FailPanel.open(host, "X", "Y")
	await frames(2)
	var rv: Button = fp.find_child("BtnRevive", true, false) as Button
	check("segunda oportunidad: boton en la derrota de un arcade", rv != null)
	if rv != null:
		rv.pressed.emit()
		for f: int in 30:
			await frames(1)
			if bool(host.get("revived")):
				break
	check("segunda oportunidad: el anuncio lo revive y el panel se cierra", bool(host.get("revived")) and not is_instance_valid(fp) or (is_instance_valid(fp) and fp.is_queued_for_deletion()))
	var fp2: FailPanel = FailPanel.open(host, "X", "Y")
	await frames(2)
	check("segunda oportunidad: solo una vez por nivel", fp2.find_child("BtnRevive", true, false) == null)
	fp2.queue_free()
	host.queue_free()
	## Pack de inicio: monedas y sin anuncios; al reinstalar, sin volver a dar monedas.
	Save.reset_all()
	var w0: int = Save.wallet()
	Store._grant("pack_inicio")
	check("pack de inicio: monedas y sin anuncios", Save.wallet() == w0 + 2000 and Store.no_ads() and Store.owns("pack_inicio"))
	Save.reset_all()
	Store._verify_and_grant({"product_ids": ["pack_inicio"], "purchase_state": 1, "purchase_token": "t", "is_acknowledged": true})
	check("pack de inicio: al reinstalar vuelve sin anuncios, no las monedas", Store.no_ads() and Save.wallet() == 0)
	Save.reset_all()
	Ads.enabled = keep_enabled
	Ads.simulate_seconds = keep_sim
	Ads.banner_kind = "menu"
	Kit.config = keep
	await frames(1)


## Premio real para negocios (kit/prize.gd): sin servidor (game.json) y con servidor (codigo personal).
func _test_prize() -> void:
	print("- Premio real")
	var keep: Dictionary = Kit.config.duplicate(true)
	var keep_level: int = Kit.level_index
	Save.reset_all()
	Kit.config["premio"] = {"texto": "10 % en tu proxima compra", "codigo": "pan10", "tras_nivel": 2, "donde": "Panaderia Luna"}
	check("premio: sin servidor sale el de game.json", Prize.info().get("texto", "") == "10 % en tu proxima compra" and Prize.visible() and not Prize.has_won())
	check("premio: se gana al superar el nivel que dice el autor", not Prize.earned_now(0) and Prize.earned_now(1) and Prize.earned_now(4))
	Kit.config["premio"]["caduca"] = "2000-01-01"
	check("premio: caducado ya no sale", Prize.info().is_empty() and not Prize.visible())
	Kit.config["premio"].erase("caduca")
	Kit.level_index = 1
	var rp: ResultPanel = ResultPanel.open(self, {"stars": 2, "coins": 1, "coins_total": 1, "score": 100, "record": false})
	await frames(2)
	var btn: Button = rp.find_child("BtnPrize", true, false) as Button
	check("premio: boton en la pantalla de nivel superado", btn != null)
	if btn != null:
		btn.pressed.emit()
	await frames(3)
	var pp: Node = get_tree().root.find_child("PrizePanel", true, false)
	var code: Label = pp.find_child("Code", true, false) as Label if pp != null else null
	check("premio: muestra el codigo para ensenarlo al pagar", code != null and code.text == "PAN10" and Prize.has_won(), str(code.text if code else "-"))
	check("premio: el panel cabe y se lee", pp == null or UI.audit(pp).is_empty(), str(UI.audit(pp).slice(0, 3)) if pp else "")
	check("premio: no se vuelve a ganar", not Prize.earned_now(3))
	if pp != null:
		pp.queue_free()
	rp.queue_free()
	await frames(1)
	## Con servidor: la portada lo guarda; al ganarlo, el servidor da un codigo personal.
	Save.reset_all()
	Kit.config.erase("premio")
	var asked: Array[String] = []
	var remote: Dictionary = {"r": null}
	remote["r"] = {"texto": "Cafe gratis", "tras_nivel": 3, "donde": "", "web": "https://cafe.es", "caduca": null, "ganado": false}
	Online.fake = func(rpc: String, payload: Dictionary) -> Variant:
		asked.append(rpc)
		if rpc == "premio_actual":
			return remote["r"]
		if rpc == "premio_ganado":
			return {"texto": "Cafe gratis", "codigo": "CAFE-7F3A", "donde": "", "web": "https://cafe.es", "caduca": "2099-12-31"} if int(payload["p_nivel"]) >= 3 else null
		return null
	await Online.fetch_prize()
	check("premio online: la portada lo guarda para la proxima vez", Prize.info().get("texto", "") == "Cafe gratis" and Prize.goal_text().contains("3"))
	var title: Node = (load(UI.SCREEN_TITLE) as PackedScene).instantiate()
	add_child(title)
	await _wait_seconds(0.5)
	check("premio online: boton Premio en la portada", title.find_child("BtnPrizeMenu", true, false) != null)
	title.queue_free()
	await frames(1)
	var got: Dictionary = await Prize.claim(2)
	check("premio online: codigo personal del servidor", got.get("codigo", "") == "CAFE-7F3A" and Prize.has_won() and asked.has("premio_ganado"))
	check("premio online: fecha de caducidad legible", Prize.expiry_text(got).contains("31/12/2099"))
	remote["r"] = null
	await Online.fetch_prize()
	check("premio online: el autor lo quita y deja de ofrecerse (el ganado se conserva)", Prize.info().is_empty() and Prize.has_won())
	Online.fake = Callable()
	Save.reset_all()
	Kit.level_index = keep_level
	Kit.config = keep
	await frames(1)


## Juego regalo (kit/gift.gd): presentacion, mensaje secreto al superar el nivel y sin anuncios.
func _test_gift() -> void:
	print("- Juego regalo")
	var keep: Dictionary = Kit.config.duplicate(true)
	var keep_level: int = Kit.level_index
	var keep_enabled: bool = Ads.enabled
	Save.reset_all()
	check("regalo: sin regalo no hay nada", not Gift.active() and not Gift.reveal_now(99))
	Kit.config["regalo"] = {"para": "Lucia", "de": "Dani", "mensaje": "Feliz cumple, hermana", "tras_nivel": 2}
	if Kit.level_count() < 3:
		Kit.config["levels"] = [{}, {}, {}]
	check("regalo: presentacion la primera vez", Gift.active() and Gift.should_intro() and Gift.headline().contains("Lucia") and Gift.headline().contains("Dani"))
	var intro: GiftPanel = GiftPanel.open(self, "intro")
	await frames(2)
	check("regalo: la presentacion no ensena el mensaje", intro.find_child("Message", true, false) == null and not Gift.should_intro())
	intro.queue_free()
	check("regalo: el mensaje sale al superar el nivel elegido", not Gift.reveal_now(0) and Gift.reveal_now(1))
	Ads.enabled = true
	Ads.debug_shift_session(1000.0)
	check("regalo: sin intersticiales ni banner", not Ads.can_show_interstitial("level_end") and not Ads.banner_allowed("menu"))
	Ads.enabled = keep_enabled
	Kit.level_index = 1
	var rp: ResultPanel = ResultPanel.open(self, {"stars": 3, "coins": 1, "coins_total": 1, "score": 100, "record": false})
	await frames(3)
	var gp: Node = get_tree().root.find_child("GiftPanel", true, false)
	var msg: Label = gp.find_child("Message", true, false) as Label if gp != null else null
	check("regalo: al ganar el nivel se abre el mensaje", msg != null and msg.text == "Feliz cumple, hermana" and Gift.revealed())
	check("regalo: el mensaje cabe y se lee", gp == null or UI.audit(gp).is_empty(), str(UI.audit(gp).slice(0, 3)) if gp else "")
	check("regalo: solo una vez", not Gift.reveal_now(3))
	if gp != null:
		gp.queue_free()
	rp.queue_free()
	await frames(1)
	## Con servidor: lo lee del servidor y avisa al autor al leerlo.
	Save.reset_all()
	Kit.config.erase("regalo")
	var asked: Array[String] = []
	Online.fake = func(rpc: String, _payload: Dictionary) -> Variant:
		asked.append(rpc)
		if rpc == "regalo_juego":
			return {"para": "Ana", "de": "Leo", "mensaje": "Te quiero", "tras_nivel": 0}
		return null
	await Online.fetch_gift()
	check("regalo online: lo guarda y sale al acabar el ultimo nivel", Gift.active() and Gift.goal_level() == maxi(Kit.level_count(), 1))
	Gift.mark_revealed()
	await frames(2)
	check("regalo online: avisa al autor de que lo ha leido", asked.has("regalo_leido"))
	Online.fake = Callable()
	Save.reset_all()
	Kit.level_index = keep_level
	Kit.config = keep
	await frames(1)


## Opinion privada (kit/rate.gd): cuando preguntar, el si lleva a la tienda y el no va al autor.
func _test_rate() -> void:
	print("- Opinion privada")
	var keep: Dictionary = Kit.config.duplicate(true)
	var tm: bool = UI.test_mode
	UI.test_mode = false
	Save.reset_all()
	Kit.config["share_url"] = "https://play.google.com/store/apps/details?id=com.estudio.bigotes&hl=es"
	check("valorar: no pregunta al principio", not RatePrompt.should_ask(3))
	for k: int in 6:
		Save.unlock_level(k)
	check("valorar: pregunta tras unos niveles con buenas estrellas", RatePrompt.should_ask(3) and not RatePrompt.should_ask(1))
	Kit.config["ads"] = {"child_directed": true}
	check("valorar: nunca en juegos para peques", not RatePrompt.should_ask(3))
	Kit.config.erase("ads")
	Kit.config["regalo"] = {"para": "A", "de": "B", "mensaje": "C"}
	check("valorar: nunca en un juego regalo", not RatePrompt.should_ask(3))
	Kit.config.erase("regalo")
	var sent: Array = []
	Online.fake = func(rpc: String, payload: Dictionary) -> Variant:
		if rpc == "opinion_enviar":
			sent.append(payload)
		return null
	var rp: RatePanel = RatePanel.open(self)
	await frames(2)
	check("valorar: \"Ahora no\" lo aplaza", not RatePrompt.should_ask(3))
	check("valorar: el panel cabe y se lee", UI.audit(rp).is_empty(), str(UI.audit(rp).slice(0, 3)))
	(rp.find_child("BtnRateNo", true, false) as Button).pressed.emit()
	await frames(2)
	var box: LineEdit = rp.find_child("RateText", true, false) as LineEdit
	check("valorar: con un no pide que mejorar", box != null)
	if box != null:
		box.text = "El nivel 4 es muy dificil"
		(rp.find_child("BtnRateSend", true, false) as Button).pressed.emit()
	await frames(3)
	check("valorar: el no le llega al autor, no a la tienda", sent.size() == 1 and sent[0]["p_gusta"] == false and str(sent[0]["p_texto"]).contains("nivel 4"))
	check("valorar: ya no vuelve a preguntar", not RatePrompt.should_ask(3))
	rp.queue_free()
	Save.reset_all()
	for k: int in 6:
		Save.unlock_level(k)
	var rp2: RatePanel = RatePanel.open(self)
	await frames(2)
	(rp2.find_child("BtnRateYes", true, false) as Button).pressed.emit()
	await frames(2)
	check("valorar: con un si lleva a la ficha de la tienda", rp2.find_child("BtnRateStore", true, false) != null and sent.size() == 2 and sent[1]["p_gusta"] == true)
	check("valorar: enlace de la tienda", RatePrompt.store_url().contains("com.estudio.bigotes"))
	rp2.queue_free()
	Online.fake = Callable()
	UI.test_mode = tm
	Save.reset_all()
	Kit.config = keep
	await frames(1)


## Estadisticas (kit/stats.gd) y modo experto (kit/expert.gd).
func _test_stats_expert() -> void:
	print("- Estadisticas y experto")
	var keep: Dictionary = Kit.config.duplicate(true)
	var keep_level: int = Kit.level_index
	Save.reset_all()
	QA.log_event("level_start", {"level": 0})
	QA.log_event("death", {})
	QA.log_event("level_start", {"level": 0})
	QA.log_event("level_complete", {"level": 0, "stars": 3})
	QA.log_event("level_start", {"level": 1})
	QA.log_event("level_complete", {"level": 1, "stars": 2})
	check("estadisticas: partidas, victorias y derrotas", Stats.n("plays") == 3 and Stats.n("wins") == 2 and Stats.n("deaths") == 1 and Stats.win_rate() == 67,
		"%d %d %d %d" % [Stats.n("plays"), Stats.n("wins"), Stats.n("deaths"), Stats.win_rate()])
	check("estadisticas: racha y dias", Stats.n("best_streak") == 2 and Stats.n("days") == 1)
	var sp: StatsPanel = StatsPanel.open(self)
	await frames(2)
	check("estadisticas: el panel cabe y se lee", UI.audit(sp).is_empty() and (sp.find_child("Rows", true, false) as GridContainer).get_child_count() >= 14, str(UI.audit(sp).slice(0, 3)))
	sp.queue_free()
	var setp: SettingsPanel = SettingsPanel.open(self)
	await frames(2)
	check("estadisticas: boton en ajustes", setp.find_child("BtnStats", true, false) != null)
	setp.queue_free()
	## Experto.
	Save.reset_all()
	Kit.config["daily_twists"] = ["espejo", "oscuridad"]
	if Kit.level_count() < 3:
		Kit.config["levels"] = [{}, {}, {}]
	check("experto: no sale hasta tener 2 niveles", not Expert.available())
	Save.unlock_level(0)
	Save.unlock_level(1)
	Save.unlock_level(2)
	check("experto: disponible con giros seguros", Expert.available())
	var ls: Node = (load(UI.SCREEN_LEVELS) as PackedScene).instantiate()
	add_child(ls)
	await frames(3)
	var eb: Button = ls.find_child("BtnExpert", true, false) as Button
	check("experto: interruptor en el selector de niveles", eb != null)
	if eb != null:
		TimeAttack.start()
		eb.button_pressed = true
		await frames(1)
	check("experto: enciende el modo y apaga el contrarreloj", Expert.active() and not TimeAttack.active())
	var medal: CanvasItem = ls.find_child("Medal", true, false) as CanvasItem
	check("experto: se ven las medallas", medal != null and medal.visible)
	check("experto: el selector cabe", UI.audit(ls).is_empty(), str(UI.audit(ls).slice(0, 3)))
	ls.queue_free()
	Expert.prepare(1)
	check("experto: cada nivel con su giro", Twist.forced == [Expert.twist_for(1)] and Expert.twist_for(1) != "")
	Kit.level_index = 1
	var w0: int = Save.wallet()
	var rp: ResultPanel = ResultPanel.open(self, {"stars": 3, "coins": 0, "coins_total": 0, "score": 10, "record": false})
	await frames(2)
	check("experto: medalla y doble de monedas", rp.find_child("ExpertMedal", true, false) != null and Expert.has_medal(1) and Save.wallet() - w0 >= 60, str(Save.wallet() - w0))
	rp.queue_free()
	Expert.stop()
	check("experto: al apagarlo se quita el giro", Twist.forced.is_empty() and not Expert.active())
	await frames(1)
	Save.reset_all()
	Kit.level_index = keep_level
	Kit.config = keep
	await frames(1)


## Modo clase (kit/classroom.gd): unirse con el codigo y mandar el progreso al profesor.
func _test_classroom() -> void:
	print("- Modo clase")
	var keep: Dictionary = Kit.config.duplicate(true)
	Save.reset_all()
	check("clase: sin servidor no sale", not Classroom.available())
	var calls: Array = []
	Online.fake = func(rpc: String, payload: Dictionary) -> Variant:
		calls.append([rpc, payload])
		if rpc == "clase_unirse":
			return {"nombre": "3B", "codigo": payload["p_codigo"]} if payload["p_codigo"] == "ABC234" else null
		return null
	check("clase: con servidor sale", Classroom.available())
	check("clase: codigo limpio (sin O ni I, en mayusculas)", Classroom.clean_code(" abc-234 ") == "ABC234")
	var cp: ClassPanel = ClassPanel.open(self)
	await frames(2)
	check("clase: el panel cabe y se lee", UI.audit(cp).is_empty(), str(UI.audit(cp).slice(0, 3)))
	(cp.find_child("ClassCode", true, false) as LineEdit).text = "zzz999"
	(cp.find_child("ClassAlias", true, false) as LineEdit).text = "Lucia"
	(cp.find_child("BtnClassJoin", true, false) as Button).pressed.emit()
	await frames(3)
	check("clase: codigo que no existe, se dice", not Classroom.joined() and (cp.find_child("Msg", true, false) as Label).text != "")
	(cp.find_child("ClassCode", true, false) as LineEdit).text = "abc234"
	(cp.find_child("BtnClassJoin", true, false) as Button).pressed.emit()
	await frames(4)
	check("clase: se une y ve su clase", Classroom.joined() and Classroom.class_name_text() == "3B" and cp.find_child("BtnClassLeave", true, false) != null)
	cp.queue_free()
	Save.unlock_level(0)
	Save.unlock_level(1)
	calls.clear()
	Classroom.sync()
	await frames(2)
	check("clase: dice en que nivel esta y cuantas veces ha perdido", int(calls[0][1].get("p_nivel_actual", 0)) >= 1 and calls[0][1].has("p_intentos"), str(calls))
	check("clase: manda los niveles superados al profe", calls.size() == 1 and calls[0][0] == "clase_progreso" and int(calls[0][1]["p_niveles"]) == clampi(Save.unlocked_count() - 1, 0, Kit.level_count()) and int(calls[0][1]["p_niveles"]) >= 1, str(calls))
	var setp: SettingsPanel = SettingsPanel.open(self)
	await frames(2)
	check("clase: boton en ajustes con el nombre", setp.find_child("BtnClass", true, false) != null and (setp.find_child("BtnClass", true, false) as Button).text.contains("3B"))
	setp.queue_free()
	Classroom.leave()
	check("clase: salir", not Classroom.joined())
	Online.fake = Callable()
	Save.reset_all()
	Kit.config = keep
	await frames(1)


## Segunda oportunidad en los puzles: una vida mas o +N movimientos con un anuncio.
func _test_puzzle_revive() -> void:
	print("- Segunda oportunidad en puzles")
	for k: String in ["sudoku", "mines", "nonogram", "hangman", "slide", "blockjam", "jigsaw", "helix", "stack", "hopper", "slice", "hole", "falling", "moles", "snake", "simon", "climb", "archery", "hoops", "penalty", "bowling", "city", "drive", "fishing", "idle", "golf", "tower", "sling", "pool", "wordle", "memory"]:
		var sc: GDScript = load("res://kit/%s/%s_game.gd" % [k, k])
		var n: Node = sc.new()
		check("segunda oportunidad: " + k + " sabe seguir", n.has_method("revive") and (n.has_method("revive_text") or k in ["helix", "stack", "hopper", "slice", "falling", "moles", "snake", "climb"]))
		n.free()
	var FM: GDScript = load("res://kit/falling/falling_map.gd")
	var fst: Dictionary = FM.new_state({"map": ["##########", "#########."], "lines": 5, "seed": 3})
	for y: int in 20:
		for x: int in 9:
			fst["grid"][y][x] = "G"
	FM.clear_top(fst, 6)
	FM.spawn(fst)
	check("caida: la segunda oportunidad vacia arriba y cabe otra pieza", (fst["grid"][0] as Array).all(func(c: Variant) -> bool: return str(c) == "") and not bool(fst["over"]))
	var keep: Dictionary = Kit.config.duplicate(true)
	var keep_enabled: bool = Ads.enabled
	var keep_sim: float = Ads.simulate_seconds
	Ads.enabled = true
	Ads.simulate_seconds = 0.01
	Kit.config["genre"] = "sudoku"
	Kit.config["levels"] = [{"name": "S", "map": ["321.", "41..", "1.2.", "2..1"], "lives": 2, "par": 30}]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/sudoku.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(2)
	var st: Dictionary = g.get("st")
	st["mistakes"] = 2
	g.call("_lose")
	await frames(2)
	var fp: Node = g.get_node_or_null("FailPanel")
	var rv: Button = fp.find_child("BtnRevive", true, false) as Button if fp != null else null
	check("segunda oportunidad: el sudoku ofrece una vida mas", rv != null and rv.text.contains("vida"), rv.text if rv else "-")
	if rv != null:
		rv.pressed.emit()
		for f: int in 30:
			await frames(1)
			if not bool(g.get("failed")):
				break
	check("segunda oportunidad: sigue con un fallo menos", not bool(g.get("failed")) and not bool(g.get("finished")) and int((g.get("st") as Dictionary)["mistakes"]) == 1)
	get_tree().paused = false
	g.queue_free()
	await frames(1)
	## Idle: turbo x2 con anuncio, una vez por intento.
	Kit.config["genre"] = "idle"
	Kit.config["levels"] = [{"name": "I", "target": 1000000, "duration": 90, "map": ["10:5", "100:40"]}]
	var ig: Node = (load("res://scenes/idle.tscn") as PackedScene).instantiate()
	add_child(ig)
	await frames(3)
	var helpers: Array = ig.get("helpers")
	if not helpers.is_empty():
		(helpers[0] as Dictionary)["owned"] = 2
	var bb: Button = ig.find_child("BtnBoost", true, false) as Button
	ig.call("_update_hud")
	check("idle: boton de turbo con anuncio", bb != null and bb.visible)
	if bb != null:
		bb.pressed.emit()
		for f: int in 30:
			await frames(1)
			if float(ig.get("boost_left")) > 0.0:
				break
	check("idle: el turbo dobla lo que ganas", float(ig.call("boost_mult")) == 2.0 and bool(ig.get("boost_used")))
	ig.call("_update_hud")
	check("idle: solo una vez", not bool(ig.call("can_boost")))
	ig.queue_free()
	Ads.enabled = keep_enabled
	Ads.simulate_seconds = keep_sim
	Kit.config = keep
	await frames(2)


## Maraton sin fin: al acabar el ultimo nivel, otra vuelta con giros y una vida mas.
func _test_endless() -> void:
	print("- Maraton sin fin")
	var keep: Dictionary = Kit.config.duplicate(true)
	var keep_level: int = Kit.level_index
	Save.reset_all()
	Kit.config["levels"] = [{}, {}, {}, {}, {}]
	Kit.config.erase("daily_twists")
	Marathon.start()
	Kit.level_index = 4
	Marathon.on_win(100)
	check("sin fin: sin giros seguros la maraton acaba", Marathon.done() and not Marathon.lap_ready())
	Marathon.stop()
	Kit.config["daily_twists"] = ["espejo", "oscuridad"]
	Marathon.start()
	Kit.marathon["lives"] = 2
	Kit.level_index = 4
	Marathon.on_win(100)
	check("sin fin: con giros, la vuelta queda lista", Marathon.lap_ready() and not Marathon.done())
	var rp: ResultPanel = ResultPanel.open(self, {"stars": 3, "coins": 0, "coins_total": 0, "score": 100, "record": false})
	await frames(2)
	check("sin fin: boton de la vuelta siguiente", rp.find_child("BtnNextLap", true, false) != null)
	check("sin fin: el panel cabe", UI.audit(rp).is_empty(), str(UI.audit(rp).slice(0, 3)))
	rp.queue_free()
	Marathon.next_lap()
	Marathon.prepare(Kit.level_index)
	check("sin fin: vuelta 2 desde el nivel 1 con una vida mas", Marathon.lap() == 2 and Kit.level_index == 0 and Marathon.lives() == 3)
	check("sin fin: cada nivel con giro", Twist.forced.size() == 1 and Marathon.banner_text().contains("2"))
	Marathon.stop()
	check("sin fin: al salir se quita el giro", Twist.forced.is_empty() and not Marathon.active())
	await frames(1)
	Save.reset_all()
	Kit.level_index = keep_level
	Kit.config = keep
	await frames(1)


## Pistas en los juegos de tablero: el bot juega por ti (gratis la primera).
func _test_board_hints() -> void:
	print("- Pistas en tablero")
	var keep: Dictionary = Kit.config.duplicate(true)
	Kit.config["genre"] = "connect"
	Kit.config["levels"] = [{"name": "C", "map": [".......", ".......", ".......", ".......", ".......", "......."], "depth": 2}]
	Kit.level_index = 0
	var g: Node = (load("res://scenes/connect.tscn") as PackedScene).instantiate()
	add_child(g)
	await frames(3)
	var hb: Button = g.find_child("BtnHint", true, false) as Button
	check("tablero: boton de pista", hb != null)
	var before: int = int((g.get("st") as Dictionary)["moves"])
	var st0: String = str((g.get("st") as Dictionary)["turn"])
	if hb != null and bool(g.call("can_act")):
		hb.pressed.emit()
		await frames(3)
	check("tablero: la pista juega por ti (gratis la primera)", int((g.get("st") as Dictionary)["moves"]) > before and Hint.used(g) == 1, st0)
	check("tablero: el marcador cabe con la pista", UI.audit(g.find_child("Hud", true, false) if g.find_child("Hud", true, false) else g).is_empty())
	g.queue_free()
	Kit.config = keep
	await frames(2)
