class_name Marathon
extends RefCounted
## Modo maraton (todos los generos): todos los niveles seguidos con 3 vidas para toda la partida.
## 1 - Se abre en la portada cuando has superado 4 niveles. Empieza en el nivel 1.
## 2 - Cada nivel superado suma (niveles y puntos) y sigue con el boton de siguiente de siempre.
## 3 - Cada derrota quita una vida y se repite el nivel; sin vidas se acaba: cartel con los
##     niveles superados y el record. Superar el ultimo nivel completa la maraton.
## 4 - En la partida se ve una franja con el nivel de la maraton y las vidas (Look la pone).
## 5 - Sin fin: si el juego tiene giros seguros (daily_twists), al acabar el ultimo nivel no se
##     termina: "Vuelta 2" vuelve al nivel 1 con un giro dificil en cada nivel (+1 vida, hasta 5).
##     El record cuenta todos los niveles seguidos de todas las vueltas.
## El estado vive en Kit.marathon (sobrevive al cambiar de escena); al volver a la portada o a
## los niveles se apaga.

const LIVES: int = 3
const NEED: int = 4
## Clasificacion online de la maraton (puntos = niveles seguidos).
const LB_LEVEL: int = 2000
const MAX_LIVES: int = 5


static func available() -> bool:
	return Kit.level_count() >= NEED and Save.unlocked_count() > NEED


static func active() -> bool:
	return not Kit.marathon.is_empty()


static func start() -> void:
	Kit.marathon = {"lives": LIVES, "cleared": 0, "score": 0, "done": false}
	Kit.level_index = 0
	QA.log_event("marathon_start", {"levels": Kit.level_count()})


static func stop() -> void:
	if lap() >= 2 and not Twist.daily_active:
		Twist.forced.clear()
	Kit.marathon = {}


static func lives() -> int:
	return int(Kit.marathon.get("lives", 0))


static func cleared() -> int:
	return int(Kit.marathon.get("cleared", 0))


static func record() -> int:
	return int(Save.get_setting("maraton_record", 0))


## Nivel superado: suma y, si era el ultimo, la maraton esta completa.
static func on_win(score: int) -> void:
	if not active():
		return
	Kit.marathon["cleared"] = cleared() + 1
	Kit.marathon["score"] = int(Kit.marathon.get("score", 0)) + score
	if Kit.level_index + 1 >= Kit.level_count():
		if can_loop():
			Kit.marathon["lap_ready"] = true
		else:
			Kit.marathon["done"] = true
	_save_record()
	Feats.mode_event("marathon_5", cleared())
	if done():
		Feats.mode_event("marathon_all", 1)


## Derrota: una vida menos. Devuelve las que quedan.
static func on_fail() -> int:
	if not active():
		return 0
	Kit.marathon["lives"] = lives() - 1
	_save_record()
	return lives()


## Sin fin: hay giros seguros para las vueltas siguientes.
static func can_loop() -> bool:
	return not Twist.daily_options().is_empty()


static func lap() -> int:
	return int(Kit.marathon.get("lap", 1))


static func lap_ready() -> bool:
	return bool(Kit.marathon.get("lap_ready", false))


## Empieza la vuelta siguiente desde el nivel 1, con una vida de premio.
static func next_lap() -> void:
	Kit.marathon["lap"] = lap() + 1
	Kit.marathon["lap_ready"] = false
	Kit.marathon["lives"] = mini(lives() + 1, MAX_LIVES)
	Kit.level_index = 0
	QA.log_event("marathon_lap", {"lap": lap()})


## En las vueltas 2+, cada nivel lleva su giro (cambia con la vuelta).
static func prepare(i: int) -> void:
	if not active() or lap() < 2 or Twist.daily_active:
		return
	var opts: Array[String] = Twist.daily_options()
	if opts.is_empty():
		return
	Twist.forced.clear()
	Twist.forced.append(opts[(i * 7 + lap() * 3) % opts.size()])


static func done() -> bool:
	return bool(Kit.marathon.get("done", false))


static func _save_record() -> void:
	if cleared() > record():
		Save.set_setting("maraton_record", cleared())
		if Online.available() and Online.alias() != "":
			Online.submit(LB_LEVEL, cleared())


static func hearts() -> String:
	return "\u2665 %d" % maxi(0, lives())


static func banner_text() -> String:
	var lap_txt: String = ("  \u00b7  " + Kit.text("mar_lap", "vuelta {n}").format({"n": lap()})) if lap() >= 2 else ""
	return Kit.text("mar_banner", "Marat\u00f3n \u00b7 nivel {n}/{t}").format({"n": Kit.level_index + 1, "t": Kit.level_count()}) + lap_txt + "   " + hearts()


static func summary() -> String:
	return Kit.text("mar_summary", "Has superado {n} niveles seguidos. Tu r\u00e9cord: {r}.").format({"n": cleared(), "r": record()})


## Franja de la maraton encima del juego.
static func make_banner() -> CanvasLayer:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "MarathonBanner"
	layer.layer = 25
	var lbl: Label = Label.new()
	lbl.name = "Text"
	lbl.text = banner_text()
	lbl.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	lbl.position = Vector2(-220, -46)
	lbl.size = Vector2(440, 40)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", Color("#ffd166"))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(lbl)
	return layer
