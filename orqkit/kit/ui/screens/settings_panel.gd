class_name SettingsPanel
extends UiModal
## Ajustes: volumen de musica y efectos, vibracion. Se guarda al cerrar.


static func open(host: Node) -> SettingsPanel:
	var s: SettingsPanel = SettingsPanel.new()
	s.name = "SettingsPanel"
	s.layer = 60
	host.add_child(s)
	return s


func _ready() -> void:
	build_frame(Kit.text("settings", "Ajustes"))
	_slider_row("SliderMusic", "music", "music", 0.8)
	_slider_row("SliderSfx", "sound", "sfx", 1.0)
	var vib: Button = UI.make_button("", false, "vibrate")
	vib.name = "BtnHaptics"
	vib.toggle_mode = true
	vib.button_pressed = bool(Save.get_setting("haptics", true))
	vib.toggled.connect(_on_haptics)
	body.add_child(vib)
	_on_haptics(vib.button_pressed, false)
	## Datos anonimos de partida: solo si el juego los envia (game.json -> telemetry).
	if not Telemetry.config().is_empty():
		var st: Button = UI.make_button("", false, "star")
		st.name = "BtnStats"
		st.toggle_mode = true
		st.button_pressed = bool(Save.get_setting("telemetry", true))
		st.toggled.connect(_on_stats)
		body.add_child(st)
		_on_stats(st.button_pressed, false)
	## Clasificacion online: se puede apagar (y el apodo se borra al apagarla). No existe si el autor
	## la ha quitado o el juego es para ninos.
	if not Telemetry.config().is_empty() and Kit.feature("online") and not Kit.kids():
		var on_btn: Button = UI.make_button("", false, "trophy")
		on_btn.name = "BtnOnline"
		on_btn.toggle_mode = true
		on_btn.button_pressed = bool(Save.get_setting("online", true))
		on_btn.toggled.connect(_on_online)
		body.add_child(on_btn)
		_on_online(on_btn.button_pressed, false)
		## Fantasmas (juegos de plataformas): la sombra del que va por delante.
		if Genres.current() in ["platformer", "runner", "flyer"]:
			var gh: Button = UI.make_button("", false, "play")
			gh.name = "BtnGhosts"
			gh.toggle_mode = true
			gh.button_pressed = bool(Save.get_setting("ghosts", true))
			gh.toggled.connect(_on_ghosts)
			body.add_child(gh)
			_on_ghosts(gh.button_pressed, false)
	## Historia entre niveles: se puede quitar (y al volver a ponerla se ve desde el principio).
	if not Story.config().is_empty():
		var hist: Button = UI.make_button("", false, "play")
		hist.name = "BtnStory"
		hist.toggle_mode = true
		hist.button_pressed = bool(Save.get_setting("story", true))
		hist.toggled.connect(_on_story)
		body.add_child(hist)
		_on_story(hist.button_pressed, false)
	## Idioma (solo si el juego viene traducido).
	if Kit.languages().size() > 1:
		var lg: Button = UI.make_button("     " + Kit.text("language", "Idioma") + ": " + Kit.lang_name(Kit.lang()), false, "share")
		lg.name = "BtnLanguage"
		lg.pressed.connect(_next_language)
		body.add_child(lg)
	## Avisos en el movil (premio diario, misiones, eventos).
	if Notify.available():
		var nt: Button = UI.make_button("", false, "star")
		nt.name = "BtnNotify"
		nt.toggle_mode = true
		nt.button_pressed = Notify.enabled()
		nt.toggled.connect(_on_notify)
		body.add_child(nt)
		_on_notify(nt.button_pressed, false)
	## Pasar a otro movil (guardado en la nube con codigo y PIN).
	if Online.backend() and Kit.feature("nube"):
		var cl: Button = UI.make_button(Kit.text("cloud", "Pasar a otro m\u00f3vil"), false, "share")
		cl.name = "BtnCloud"
		cl.pressed.connect(func() -> void: CloudPanel.open(get_parent()))
		body.add_child(cl)
	## Graficos altos (etalonaje y brillo) o bajos (moviles lentos).
	## Accesibilidad: colores para daltonismo y modo calma (sin sacudidas), en un solo boton.
	var acc: Button = UI.make_button("", false, "grid")
	acc.name = "BtnAccess"
	acc.pressed.connect(_next_access)
	body.add_child(acc)
	_paint_access()
	var gfx: Button = UI.make_button("", false, "star")
	gfx.name = "BtnGraphics"
	gfx.toggle_mode = true
	gfx.button_pressed = bool(Save.get_setting("fx_high", true))
	gfx.toggled.connect(_on_graphics)
	body.add_child(gfx)
	_on_graphics(gfx.button_pressed, false)
	## RGPD: si Google lo pide (Europa), el jugador puede cambiar su consentimiento de anuncios.
	if Ads.privacy_options_required():
		var pv: Button = UI.make_button(Kit.text("ad_privacy", "Privacidad de anuncios"), false, "grid")
		pv.name = "BtnAdPrivacy"
		pv.pressed.connect(func() -> void: Ads.show_privacy_options())
		body.add_child(pv)
	## Estadisticas (kit/stats.gd) y modo clase (kit/classroom.gd), en una fila para no alargar el panel.
	var extra: HBoxContainer = HBoxContainer.new()
	extra.name = "ExtraRow"
	extra.add_theme_constant_override("separation", 12)
	body.add_child(extra)
	var stb: Button = UI.make_button(Kit.text("stat_title", "Estad\u00edsticas"), false, "")
	stb.name = "BtnStats"
	stb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stb.clip_text = true
	stb.add_theme_font_size_override("font_size", 26)
	stb.pressed.connect(func() -> void: StatsPanel.open(get_parent()))
	extra.add_child(stb)
	if Classroom.available():
		var clb: Button = UI.make_button(Kit.text("class_title", "Clase") + ((": " + Classroom.class_name_text()) if Classroom.joined() else ""), false, "")
		clb.name = "BtnClass"
		clb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		clb.clip_text = true
		clb.add_theme_font_size_override("font_size", 26)
		clb.pressed.connect(func() -> void: ClassPanel.open(get_parent()))
		extra.add_child(clb)
	var close_btn: Button = UI.make_button(Kit.text("close", "Cerrar"), true, "close")
	close_btn.name = "BtnClose"
	close_btn.pressed.connect(_on_close)
	body.add_child(close_btn)


func _slider_row(node_name: String, icon_kind: String, key: String, fallback: float) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	body.add_child(row)
	row.add_child(UiIcon.make(icon_kind, UI.colors["texto"], 52.0))
	var s: HSlider = HSlider.new()
	s.name = node_name
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = float(Save.get_setting(key, fallback))
	s.custom_minimum_size = Vector2(0.0, UI.MIN_TOUCH)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.value_changed.connect(_on_slider.bind(key))
	row.add_child(s)


## 1 - Se aplica al momento para que el jugador oiga el cambio; se escribe al cerrar.
func _on_slider(value: float, key: String) -> void:
	Save.set_setting(key, value, false)
	if key == "music":
		Audio.apply_music_volume()
	else:
		Audio.play("click", 0.0)


func _on_haptics(on: bool, feedback: bool = true) -> void:
	var b: Button = body.get_node("BtnHaptics") as Button
	var label: String = Kit.text("vibration", "Vibracion")
	b.text = "     " + label + ": " + (Kit.text("on", "Si") if on else Kit.text("off", "No"))
	b.theme_type_variation = "PrimaryButton" if on else ""
	var icon: UiIcon = b.get_child(0) as UiIcon
	icon.color = UI.colors["acento_texto"] if on else UI.colors["texto"]
	icon.queue_redraw()
	if feedback:
		Save.set_setting("haptics", on, false)
		Juice.vibrate(30)


func _on_stats(on: bool, feedback: bool = true) -> void:
	var b: Button = body.get_node("BtnStats") as Button
	b.text = "     " + Kit.text("anon_stats", "Datos an\u00f3nimos") + ": " + (Kit.text("on", "Si") if on else Kit.text("off", "No"))
	b.theme_type_variation = "PrimaryButton" if on else ""
	var icon: UiIcon = b.get_child(0) as UiIcon
	icon.color = UI.colors["acento_texto"] if on else UI.colors["texto"]
	icon.queue_redraw()
	if feedback:
		Save.set_setting("telemetry", on, false)


func _on_online(on: bool, feedback: bool = true) -> void:
	var b: Button = body.get_node("BtnOnline") as Button
	b.text = "     " + Kit.text("leaderboard", "Clasificaci\u00f3n") + ": " + (Kit.text("on", "Si") if on else Kit.text("off", "No"))
	b.theme_type_variation = "PrimaryButton" if on else ""
	var icon: UiIcon = b.get_child(0) as UiIcon
	icon.color = UI.colors["acento_texto"] if on else UI.colors["texto"]
	icon.queue_redraw()
	if feedback:
		Save.set_setting("online", on, false)
		if not on:
			Save.set_setting("alias", "", false)


func _on_notify(on: bool, feedback: bool = true) -> void:
	var b: Button = body.get_node("BtnNotify") as Button
	b.text = "     " + Kit.text("notifications", "Avisos") + ": " + (Kit.text("on", "Si") if on else Kit.text("off", "No"))
	b.theme_type_variation = "PrimaryButton" if on else ""
	var icon: UiIcon = b.get_child(0) as UiIcon
	icon.color = UI.colors["acento_texto"] if on else UI.colors["texto"]
	icon.queue_redraw()
	if feedback:
		Save.set_setting("notifications", on, false)
		Notify.reschedule()


func _on_ghosts(on: bool, feedback: bool = true) -> void:
	var b: Button = body.get_node("BtnGhosts") as Button
	b.text = "     " + Kit.text("ghosts", "Fantasmas") + ": " + (Kit.text("on", "Si") if on else Kit.text("off", "No"))
	b.theme_type_variation = "PrimaryButton" if on else ""
	var icon: UiIcon = b.get_child(0) as UiIcon
	icon.color = UI.colors["acento_texto"] if on else UI.colors["texto"]
	icon.queue_redraw()
	if feedback:
		Save.set_setting("ghosts", on, false)


## Pasa al siguiente idioma. En los menus se ve al momento; dentro de un nivel, al salir.
func _next_language() -> void:
	var langs: Array[String] = Kit.languages()
	var next: String = langs[(langs.find(Kit.lang()) + 1) % langs.size()]
	Kit.set_lang(next)
	var b: Button = body.get_node("BtnLanguage") as Button
	b.text = "     " + Kit.text("language", "Idioma") + ": " + Kit.lang_name(next)
	var scene: Node = get_tree().current_scene
	if scene is Control and not UI.test_mode:
		get_tree().reload_current_scene()


func _on_graphics(on: bool, feedback: bool = true) -> void:
	var b: Button = body.get_node("BtnGraphics") as Button
	b.text = "     " + Kit.text("graphics", "Gr\u00e1ficos") + ": " + (Kit.text("gfx_high", "Altos") if on else Kit.text("gfx_low", "Bajos"))
	b.theme_type_variation = "PrimaryButton" if on else ""
	var icon: UiIcon = b.get_child(0) as UiIcon
	icon.color = UI.colors["acento_texto"] if on else UI.colors["texto"]
	icon.queue_redraw()
	if feedback:
		Look.set_high(on)


## Orden: no -> colores -> calma -> los dos -> no.
func _access_mode() -> int:
	return (1 if bool(Save.get_setting("color_assist", false)) else 0) + (2 if bool(Save.get_setting("calm", false)) else 0)


func _next_access() -> void:
	var order: Array[int] = [0, 1, 2, 3]
	var nxt: int = order[(order.find(_access_mode()) + 1) % order.size()]
	Look.set_color_assist(nxt % 2 == 1)
	Save.set_setting("calm", nxt >= 2)
	_paint_access()


func _paint_access() -> void:
	var b: Button = body.get_node("BtnAccess") as Button
	var names: Array[String] = [Kit.text("acc_off", "No"), Kit.text("acc_colors", "Colores"), Kit.text("acc_calm", "Calma"),
		Kit.text("acc_both", "Colores y calma")]
	var mode: int = _access_mode()
	b.text = "     " + Kit.text("accessibility", "Accesibilidad") + ": " + names[mode]
	b.theme_type_variation = "PrimaryButton" if mode > 0 else ""
	var icon: UiIcon = b.get_child(0) as UiIcon
	icon.color = UI.colors["acento_texto"] if mode > 0 else UI.colors["texto"]
	icon.queue_redraw()


func _on_story(on: bool, feedback: bool = true) -> void:
	var b: Button = body.get_node("BtnStory") as Button
	b.text = "     " + Kit.text("story", "Historia") + ": " + (Kit.text("on", "Si") if on else Kit.text("off", "No"))
	b.theme_type_variation = "PrimaryButton" if on else ""
	var icon: UiIcon = b.get_child(0) as UiIcon
	icon.color = UI.colors["acento_texto"] if on else UI.colors["texto"]
	icon.queue_redraw()
	if feedback:
		Save.set_setting("story", on, false)
		if on:
			Story.reset_seen()


func _on_close() -> void:
	Save.save_data()
	close()
