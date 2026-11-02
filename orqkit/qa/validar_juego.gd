extends Node
## Validador de un juego fabricado. Lo usa la cadena de la fabrica:
##   godot --headless --path <proyecto> res://qa/validar_juego.tscn --fixed-fps 60 -- [--solo-niveles]
## Imprime una linea "[VALIDACION] {json}" y sale con 0 si el juego esta listo o 1 si no.
## 1 - Niveles: analizador (completable, monedas, enemigos justos; en hordas, la arena).
## 2 - Bots: cada nivel se juega de verdad con la fisica real (salvo --solo-niveles).
## 3 - Arte y sonido: sprites del jugador y enemigos, tile y efectos presentes.
## 4 - Interfaz: auditoria del titulo y del selector de niveles en dos tamanos de movil, y de la
##     pantalla de juego (nivel 1) en un movil de 720x1280.

var report: Dictionary = {"ok": true, "niveles": [], "arte": {}, "interfaz": [], "fallos_qa": []}


func _ready() -> void:
	var only_levels: bool = OS.get_cmdline_user_args().has("--solo-niveles")
	UI.test_mode = true
	Ads.enabled = false
	## La interfaz se revisa con el hueco del banner si el perfil del juego lo lleva.
	Ads.audit_banner = true
	var cfg: Dictionary = Kit.config
	var levels: Array = cfg.get("levels", [])
	var tile: float = float(cfg.get("tile_size", 64))
	var params: Dictionary = cfg.get("player", {})
	if levels.is_empty():
		_bad("sin niveles")
	## Prueba A/B: la version B del nivel se valida como un nivel mas (indice = total de niveles).
	var tests: Array = []
	for i: int in levels.size():
		tests.append([i, levels[i]])
	var ab: int = Kit.ab_level()
	if ab >= 0 and ab < levels.size() and (levels[ab] as Dictionary).get("variant_b") is Dictionary:
		var vb: Dictionary = (levels[ab] as Dictionary).duplicate()
		vb.merge(vb["variant_b"], true)
		vb.erase("variant_b")
		tests.append([ab, vb])
	for t: int in tests.size():
		var i: int = t
		var genre: String = str(cfg.get("genre", ""))
		var r: Dictionary = Genres.analyze(genre, tests[t][1], tile, params)
		var entry: Dictionary = {
			"nivel": i, "completable": bool(r.get("completable", false)), "problemas": r.get("issues", []),
			"monedas": int(r.get("coins_total", 0)), "enemigos": int(r.get("enemies", 0)),
			"detalle": r.get("enemy_problems", []),
		}
		if not entry["completable"] or not (entry["problemas"] as Array).is_empty():
			report["ok"] = false
		(report["niveles"] as Array).append(entry)
	if not only_levels:
		await _play_levels(tests)
		_check_art(levels)
		await _check_ui()
	report["fallos_qa"] = QA.failures
	if not QA.failures.is_empty():
		report["ok"] = false
	print("[VALIDACION] ", JSON.stringify(report))
	get_tree().quit(0 if bool(report["ok"]) else 1)


func _bad(msg: String) -> void:
	report["ok"] = false
	(report["fallos_qa"] as Array).append(msg)


func _play_levels(tests: Array) -> void:
	for i: int in tests.size():
		QA.clear()
		Kit.level_index = int(tests[i][0])
		Kit.ab_force = "b" if i >= Kit.level_count() else ""
		var game: Node = (load(UI.game_scene()) as PackedScene).instantiate()
		add_child(game)
		for k: int in 2:
			await get_tree().physics_frame
		var done: bool = await QaBot.run(get_tree(), game, 60 * 150)
		var st: Dictionary = game.call("bot_state")
		var entry: Dictionary = (report["niveles"] as Array)[i]
		## Puzle, torres y carreras: el bot debe pasarlo a la primera o a la segunda; si no, es injusto.
		if Genres.strict(Genres.current()) and int(st.get("deaths", 0)) > 1:
			done = false
		entry["bot_completa"] = done
		## No todos los generos cuentan monedas o pisotones: lo que falte, a cero (antes un genero sin
		## "stomps" rompia la validacion y el resto de niveles se quedaba sin jugar).
		entry["bot_muertes"] = int(st.get("deaths", 0))
		entry["bot_monedas"] = int(st.get("coins", 0))
		entry["bot_pisotones"] = int(st.get("stomps", 0))
		entry["bot_segundos"] = snappedf(float(game.get("time_in_level")), 0.1)
		entry["sonidos_que_faltan"] = QA.count("sfx_missing")
		if not done:
			report["ok"] = false
		QaBot.release_all()
		game.queue_free()
		Engine.time_scale = 1.0
		await get_tree().physics_frame
		await get_tree().physics_frame
	Kit.ab_force = ""


func _check_art(levels: Array) -> void:
	var art: Dictionary = report["arte"]
	art["jugador"] = not Kit.sprite_by_role("jugador").is_empty()
	art["tile"] = Kit.first_tile_texture() != null
	var uses_enemies: bool = false
	## En las cartas las letras son rangos (la K es el rey), en la pesca la F es un pez y en el imperio
	## la E es el centro rival y en las mazmorras la sala elite (se dibujan con formas): no son enemigos con dibujo.
	for lv: Variant in ([] if Genres.current() in ["cards", "fishing", "empire", "dungeon", "parking", "penalty", "slice", "hole", "city", "helix", "hoops", "mines", "connect", "checkers", "pool", "klondike", "ludo", "falling", "bowling", "sandbox", "royale", "hopper", "archery", "voxel", "obby", "market", "soccer", "horror", "drive", "zombie", "basket", "tennis", "kart", "climb"] else levels):
		for row: Variant in (lv as Dictionary).get("map", []):
			var s: String = str(row)
			if s.contains("E") or s.contains("K") or s.contains("F"):
				uses_enemies = true
	if Genres.enemy_art(Genres.current()):
		uses_enemies = true
	art["enemigos"] = (not uses_enemies) or not Kit.sprite_by_role("enemigo").is_empty()
	var sfx: Dictionary = Kit.assets.get("sfx", {})
	var missing: Array[String] = []
	for need: String in ["jump", "coin", "hurt", "land", "win", "click", "stomp"]:
		if not sfx.has(need):
			missing.append(need)
	art["sonidos_que_faltan"] = missing
	if not bool(art["jugador"]) or not bool(art["tile"]) or not bool(art["enemigos"]) or not missing.is_empty():
		report["ok"] = false


func _check_ui() -> void:
	for sz: Vector2i in [Vector2i(720, 1280), Vector2i(720, 1600)]:
		for path: String in [UI.SCREEN_TITLE, UI.SCREEN_LEVELS]:
			_banner_for("menu")
			var vp: SubViewport = SubViewport.new()
			vp.size = sz
			add_child(vp)
			var host: Control = Control.new()
			host.size = Vector2(sz)
			vp.add_child(host)
			host.add_child((load(path) as PackedScene).instantiate())
			await get_tree().create_timer(1.6, true, false, true).timeout
			for problem: String in UI.audit(host):
				(report["interfaz"] as Array).append("%s %dx%d: %s" % [path.get_file(), sz.x, sz.y, problem])
			vp.queue_free()
			await get_tree().process_frame
	await _check_game_ui()
	if not (report["interfaz"] as Array).is_empty():
		report["ok"] = false



## Pantalla de juego del nivel 1 a 720x1280: botones del tamano del dedo, textos que caben y
## nada fuera de la pantalla (los dialogos de historia se cierran antes de mirar).
func _check_game_ui() -> void:
	var keep: int = Kit.level_index
	Kit.level_index = 0
	_banner_for("game")
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(720, 1280)
	add_child(vp)
	var g: Node = (load(UI.game_scene()) as PackedScene).instantiate()
	vp.add_child(g)
	await get_tree().create_timer(1.2, true, false, true).timeout
	for n: Node in get_tree().root.find_children("*", "DialogPanel", true, false):
		n.queue_free()
	get_tree().paused = false
	await get_tree().create_timer(0.8, true, false, true).timeout
	for problem: String in UI.audit(g):
		(report["interfaz"] as Array).append("partida 720x1280: %s" % problem)
	vp.queue_free()
	await get_tree().process_frame
	get_tree().paused = false
	Kit.level_index = keep


## Hueco del banner como en el movil: el validador apaga los anuncios, pero la interfaz tiene que
## caber con el banner si el perfil del juego lo pone en esa pantalla.
func _banner_for(kind: String) -> void:
	Ads.banner_kind = kind
	Ads.enabled = bool(Monetize.p("banner_menu" if kind == "menu" else "banner_game"))
	Ads.audit_banner = Ads.enabled
