extends Node
## Pruebas de un juego de creacion libre (fabrica/libre): el juego vive en res://libre/ y empieza en
## res://libre/main.tscn. Lo escribe la IA desde cero, asi que no hay bot del genero: estas pruebas son
## universales y la fabrica (Python) lee lo que se imprime y los SCRIPT ERROR de Godot.
##   godot --path P res://qa/libre.tscn -- --modo=compilar|recorrer|mono|bot [--out=DIR] [--segundos=N]
## compilar: carga cada script y escena de res://libre (y monta la principal un momento).
## recorrer: pulsa todos los botones de todas las pantallas que encuentra (fotos de cada pantalla
##           nueva si hay pantalla), avisa de botones fuera de la pantalla o demasiado pequenos.
## mono:     toques y arrastres al azar durante N segundos, como un nino con el movil.
## bot:      res://libre/bot.gd (static func jugar(tree) -> Dictionary) juega de verdad y dice si gana.

const MAIN: String = "res://libre/main.tscn"


func _ready() -> void:
	var cfg: Dictionary = {"modo": "compilar", "out": "", "segundos": 40.0}
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--modo="):
			cfg["modo"] = a.get_slice("=", 1)
		elif a.begins_with("--out="):
			cfg["out"] = a.get_slice("=", 1)
		elif a.begins_with("--segundos="):
			cfg["segundos"] = float(a.get_slice("=", 1))
	Ads.enabled = false
	Save.reset_all()
	var r: LibreRunner = LibreRunner.new()
	r.name = "LibreRunner"
	r.cfg = cfg
	## El corredor cuelga de la raiz: sobrevive a los cambios de escena del juego.
	get_tree().root.add_child.call_deferred(r)


class LibreRunner extends Node:
	var cfg: Dictionary = {}
	var _shots: int = 0
	var _seen: Dictionary = {}
	var _pressed: Dictionary = {}

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		match str(cfg["modo"]):
			"compilar":
				await _compilar()
			"recorrer":
				await _recorrer()
			"mono":
				await _mono()
			"bot":
				await _bot()
			_:
				print("[LIBRE_ERR] modo desconocido")
		get_tree().quit()

	func _scripts(dir: String, out: Array[String]) -> void:
		var d: DirAccess = DirAccess.open(dir)
		if d == null:
			return
		for f: String in d.get_files():
			if f.ends_with(".gd") or f.ends_with(".tscn"):
				out.append(dir.path_join(f))
		for s: String in d.get_directories():
			if not s.begins_with("."):
				_scripts(dir.path_join(s), out)

	func _compilar() -> void:
		var files: Array[String] = []
		_scripts("res://libre", files)
		var bad: int = 0
		for f: String in files:
			var res: Resource = ResourceLoader.load(f, "", ResourceLoader.CACHE_MODE_IGNORE)
			if res == null:
				print("[LIBRE_ERR] no carga: ", f)
				bad += 1
			elif res is Script and not (res as Script).can_instantiate() and not (res as GDScript).source_code.contains("static func"):
				print("[LIBRE_AVISO] script sin instanciar: ", f)
		if not ResourceLoader.exists(MAIN):
			print("[LIBRE_ERR] falta ", MAIN)
			return
		await _abrir()
		await _esperar(1.5)
		print("[LIBRE_COMPILA] archivos=%d malos=%d" % [files.size(), bad])

	func _abrir() -> void:
		get_tree().change_scene_to_file(MAIN)
		await get_tree().process_frame
		await get_tree().process_frame

	func _esperar(s: float) -> void:
		await get_tree().create_timer(s, true, false, true).timeout

	func _botones() -> Array[BaseButton]:
		var out: Array[BaseButton] = []
		var root: Node = get_tree().root
		for n: Node in root.find_children("*", "BaseButton", true, false):
			var b: BaseButton = n as BaseButton
			if b == null or b.is_queued_for_deletion() or not b.is_visible_in_tree() or b.disabled:
				continue
			if b.get_viewport() != get_viewport():
				continue
			out.append(b)
		return out

	func _firma() -> String:
		var cs: Node = get_tree().current_scene
		var nombre: String = cs.scene_file_path if cs != null else "?"
		var textos: Array[String] = []
		for b: BaseButton in _botones():
			textos.append(_nombre_boton(b))
		textos.sort()
		return nombre + "|" + str(textos.size()) + "|" + str(hash(",".join(textos)))

	func _nombre_boton(b: BaseButton) -> String:
		var t: String = ""
		if b is Button:
			t = (b as Button).text
		return (t if t != "" else str(b.name)).strip_edges().left(30)

	func _foto(nombre: String) -> void:
		if str(cfg["out"]) == "" or DisplayServer.get_name() == "headless" or _shots >= 14:
			return
		await RenderingServer.frame_post_draw
		_shots += 1
		DirAccess.make_dir_recursive_absolute(str(cfg["out"]))
		get_viewport().get_texture().get_image().save_png(str(cfg["out"]).path_join("%02d_%s.png" % [_shots, nombre.validate_filename().left(40)]))

	func _revisar_pantalla() -> void:
		var vp: Rect2 = get_viewport().get_visible_rect()
		for b: BaseButton in _botones():
			var r: Rect2 = b.get_global_rect()
			if not vp.grow(4.0).encloses(r):
				print("[LIBRE_FUERA] boton fuera de la pantalla: ", _nombre_boton(b), " ", r)
			elif r.size.x < 60.0 or r.size.y < 60.0:
				print("[LIBRE_PEQUENO] boton muy pequeno para un dedo: ", _nombre_boton(b), " ", r.size)
		## Personajes y piezas que se pisan (15 nov, El Farero: los monstruos encima de los heroes). Se miran
		## las imagenes visibles que no son fondo (menos del 55% de la pantalla).
		var piezas: Array[Rect2] = []
		var nombres: Array[String] = []
		var texs: Array[Texture2D] = []
		for n: Node in get_tree().root.find_children("*", "TextureRect", true, false):
			var t: TextureRect = n as TextureRect
			if t == null or not t.is_visible_in_tree() or t.texture == null or t.get_viewport() != get_viewport():
				continue
			var r: Rect2 = t.get_global_rect()
			if r.get_area() < 2500.0 or r.get_area() > vp.get_area() * 0.55:
				continue
			piezas.append(r)
			texs.append(t.texture)
			nombres.append(str(t.name) + "(" + t.texture.resource_path.get_file() + ")")
		var avisos: int = 0
		for i: int in piezas.size():
			for j: int in range(i + 1, piezas.size()):
				## La misma imagen repetida (bancos de niebla, nubes, adornos) se puede pisar a proposito.
				if texs[i] == texs[j]:
					continue
				var x: Rect2 = piezas[i].intersection(piezas[j])
				var menor: float = minf(piezas[i].get_area(), piezas[j].get_area())
				if x.get_area() > menor * 0.3 and not piezas[i].encloses(piezas[j]) and not piezas[j].encloses(piezas[i]) and avisos < 6:
					avisos += 1
					print("[LIBRE_SOLAPE] se pisan ", nombres[i], " y ", nombres[j], " (", int(100.0 * x.get_area() / menor), "%)")

	func _recorrer() -> void:
		await _abrir()
		await _esperar(1.2)
		var pasos: int = 0
		var sin_nuevo: int = 0
		while pasos < 70 and sin_nuevo < 14:
			pasos += 1
			var f: String = _firma()
			if not _seen.has(f):
				_seen[f] = true
				sin_nuevo = 0
				var cs: Node = get_tree().current_scene
				print("[LIBRE_PANTALLA] ", cs.scene_file_path if cs != null else "?", " botones=", _botones().size())
				_revisar_pantalla()
				await _foto(str(cs.name) if cs != null else "pantalla")
			else:
				sin_nuevo += 1
			var bs: Array[BaseButton] = _botones()
			var elegido: BaseButton = null
			for b: BaseButton in bs:
				var k: String = f + ">" + _nombre_boton(b)
				if not _pressed.has(k):
					_pressed[k] = true
					elegido = b
					break
			if elegido == null:
				## Todo lo de esta pantalla probado: se vuelve al principio para seguir por otra rama.
				if bs.is_empty() or sin_nuevo > 6:
					await _abrir()
					await _esperar(0.8)
					continue
				elegido = bs[randi() % bs.size()]
			print("[LIBRE_BOTON] ", _nombre_boton(elegido))
			if elegido.toggle_mode:
				elegido.button_pressed = not elegido.button_pressed
			else:
				elegido.pressed.emit()
			await _esperar(0.6)
			if get_tree().paused:
				get_tree().paused = false
		## Las escenas a las que no se llego pulsando botones se abren directamente: todas salen en foto.
		var vistas: Dictionary = {}
		for f: String in _seen.keys():
			vistas[f.get_slice("|", 0)] = true
		var escenas: Array[String] = []
		_scripts("res://libre", escenas)
		for e: String in escenas:
			if not e.ends_with(".tscn") or vistas.has(e) or e == MAIN:
				continue
			get_tree().change_scene_to_file(e)
			await get_tree().process_frame
			await _esperar(1.2)
			var cs: Node = get_tree().current_scene
			if cs == null:
				continue
			print("[LIBRE_PANTALLA] ", e, " (abierta directamente) botones=", _botones().size())
			_revisar_pantalla()
			await _foto(str(cs.name))
		print("[LIBRE_RECORRIDO] pantallas=%d pulsados=%d" % [_seen.size(), _pressed.size()])

	func _mono() -> void:
		await _abrir()
		await _esperar(1.0)
		var t0: int = Time.get_ticks_msec()
		var n: int = 0
		var vp: Vector2 = get_viewport().get_visible_rect().size
		while float(Time.get_ticks_msec() - t0) / 1000.0 < float(cfg["segundos"]):
			n += 1
			var p: Vector2 = Vector2(randf() * vp.x, randf() * vp.y)
			var r: float = randf()
			if r < 0.15:
				var bs: Array[BaseButton] = _botones()
				if not bs.is_empty():
					var b: BaseButton = bs[randi() % bs.size()]
					if not b.toggle_mode:
						b.pressed.emit()
			elif r < 0.65:
				_toque(p, true)
				await get_tree().process_frame
				_toque(p, false)
			else:
				var q: Vector2 = p + Vector2(randf_range(-260, 260), randf_range(-260, 260))
				_toque(p, true)
				for k: int in 5:
					var m: InputEventMouseMotion = InputEventMouseMotion.new()
					m.position = p.lerp(q, float(k + 1) / 5.0)
					m.button_mask = MOUSE_BUTTON_MASK_LEFT
					Input.parse_input_event(m)
					await get_tree().process_frame
				_toque(q, false)
			if get_tree().paused and randf() < 0.3:
				get_tree().paused = false
			await _esperar(0.1)
		print("[LIBRE_MONO] acciones=%d" % n)

	func _toque(p: Vector2, abajo: bool) -> void:
		var e: InputEventMouseButton = InputEventMouseButton.new()
		e.position = p
		e.global_position = p
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = abajo
		Input.parse_input_event(e)

	func _bot() -> void:
		if not ResourceLoader.exists("res://libre/bot.gd"):
			print("[LIBRE_ERR] falta res://libre/bot.gd")
			return
		var bot: GDScript = load("res://libre/bot.gd") as GDScript
		if bot == null:
			print("[LIBRE_ERR] res://libre/bot.gd no carga")
			return
		await _abrir()
		await _esperar(0.5)
		var t0: int = Time.get_ticks_msec()
		var r: Variant = await bot.call("jugar", get_tree())
		var d: Dictionary = r if r is Dictionary else {"ok": false, "detalle": "jugar() no devolvio un diccionario"}
		d["segundos"] = round(float(Time.get_ticks_msec() - t0) / 100.0) / 10.0
		print("[LIBRE_BOT] ", JSON.stringify(d))
