class_name Tutorial
extends CanvasLayer
## Tutorial interactivo: pasos que senalan un boton o zona y avanzan cuando el jugador lo hace.
## 1 - Cada paso: texto, objetivo (nombre de un nodo de la interfaz; "" = sin senalar) y cuando
##     avanza ("until"):
##       "press"           el jugador pulsa el boton del objetivo
##       "tap"             un toque en cualquier sitio (pasos que solo explican)
##       "event:<nombre>"  pasa un evento de la partida (QA.log_event), p. ej. "event:wave_start"
##       "change:<ruta>"   cambia un valor del juego: "moves", "selected", "st.gold", "st.p.1.mana"
##       "wait:<s>"        pasan unos segundos
## 2 - Por defecto, el de su genero (STEPS, textos tut_<kit>_<n>). Un juego puede traer el suyo en
##     game.json -> "tutorial": [{"text", "target", "until"}] (lo escribe la fabrica o la IA).
## 3 - Sale una vez, en el primer nivel (no con bots, pruebas, retos ni partidas de 2 jugadores).
##     No para el juego; "Saltar" lo cierra. Cuando hay tutorial, la ventana "Como se juega" no
##     sale sola (sigue en el menu de pausa).

signal finished_tutorial

## Las pruebas del kit lo apagan.
static var enabled: bool = true

const STEPS: Dictionary = {
	"tower": [["Toca una casilla libre del c\u00e9sped para construir.", "", "change:selected"], ["Elige una torre: el rayo es barata y r\u00e1pida.", "Build_rayo", "event:tower_build"], ["Cuando est\u00e9s listo, lanza la oleada.", "BtnNextWave", "event:wave_start"], ["Toca una torre para mejorarla o elegir a qui\u00e9n dispara. \u00a1Suerte!", "", "tap"]],
	"tactics": [["Toca una de tus unidades azules.", "", "change:selected"], ["Las casillas azules son ad\u00f3nde puede ir: toca una.", "", "change:st.units"], ["Toca un rival en rojo para atacar, o pulsa Esperar.", "BtnWait", "change:st.units"], ["Cuando muevas tus unidades, pulsa Fin del turno.", "BtnEndTurn", "press"]],
	"sort": [["Toca un tubo para coger el color de arriba.", "", "change:selected"], ["Ahora toca otro: se vierte si arriba hay el mismo color o est\u00e1 vac\u00edo.", "", "change:moves"], ["Un color por tubo y ganas. Si te l\u00edas, deshaz.", "BtnUndo", "tap"]],
	"sokoban": [["Desliza el dedo para andar.", "", "change:cell"], ["Empuja las cajas hasta las marcas.", "", "change:pushes"], ["Si una caja se atasca, deshaz o reinicia.", "BtnUndo", "tap"]],
	"stealth": [["Toca un punto unido al tuyo para moverte.", "", "change:st.p"], ["Los guardias se mueven despu\u00e9s de ti: no acabes donde vigilan (rojo).", "", "tap"], ["Llega a la salida. Si te equivocas, deshaz.", "BtnUndo", "tap"]],
	"crawl": [["Toca una casilla para andar hasta ella.", "", "change:st.p"], ["O pulsa Explorar y el h\u00e9roe anda solo.", "BtnExplore", "tap"], ["Chocar con un monstruo es atacarle; la poci\u00f3n te cura.", "BtnPotion", "tap"]],
	"autochess": [["Toca una carta de la tienda para comprar una unidad.", "", "change:st.gold"], ["Toca tu unidad y luego una casilla de tu mitad para colocarla.", "", "change:st.board"], ["Pulsa Luchar: pelean solas.", "BtnFight", "press"]],
	"ccg": [["Toca una carta de tu mano para jugarla; cuesta man\u00e1.", "", "change:st.p.1.mana"], ["Tus esbirros atacan desde el turno siguiente: t\u00f3calos y luego a un rival.", "", "tap"], ["Cuando acabes, pulsa Fin del turno.", "BtnEndTurn", "press"]],
}

var game: Node
var steps: Array = []
var index: int = -1
var _base: String = ""
var _target: Control
var _text: Label
var _box: PanelContainer
var _ring: Control
var _t: float = 0.0
var _armed: float = 0.0
var _hooked: Node


## Pasos de este juego: los suyos (game.json) o los de su genero.
static func steps_for(kit: String) -> Array:
	var own: Variant = Kit.config.get("tutorial", [])
	var out: Array = []
	var base: Array = STEPS.get(kit, [])
	if own is Array and not (own as Array).is_empty():
		## Textos propios del juego (con su traduccion si la hay); cada uno usa el boton y la forma de
		## avanzar del paso de su genero en la misma posicion, salvo que traiga los suyos.
		var tr: Array = []
		var i18n: Variant = Kit.config.get("i18n", {})
		if i18n is Dictionary and (i18n as Dictionary).get(Kit.lang()) is Dictionary:
			var v: Variant = ((i18n as Dictionary)[Kit.lang()] as Dictionary).get("_tutorial", [])
			tr = v if v is Array else []
		var n: int = 0
		for s: Variant in own:
			if not s is Dictionary or str((s as Dictionary).get("text", "")) == "":
				continue
			var d: Dictionary = s
			var gen: Array = base[n] if n < base.size() else ["", "", "tap"]
			var txt: String = str(tr[n]) if n < tr.size() and str(tr[n]) != "" else str(d["text"])
			out.append({"text": txt, "target": str(d.get("target", gen[1])), "until": str(d.get("until", gen[2]))})
			n += 1
		return out
	for i: int in base.size():
		var s2: Array = base[i]
		out.append({"text": Kit.text("tut_%s_%d" % [kit, i + 1], str(s2[0])), "target": str(s2[1]), "until": str(s2[2])})
	return out


static func seen(kit: String) -> bool:
	return bool(Save.get_setting("tut_" + kit, false))


## Hay tutorial para la partida que empieza ahora?
static func will_run(kit: String) -> bool:
	return enabled and not UI.test_mode and not QA.enabled and not Kit.is_extra() and not Kit.versus \
		and not Marathon.active() and Kit.level_index == 0 and not seen(kit) and not steps_for(kit).is_empty()


static func maybe_start(game_node: Node) -> void:
	var kit: String = Genres.current()
	if not will_run(kit):
		return
	Save.set_setting("tut_" + kit, true)
	## Espera a que se cierre lo que haya en pausa delante (dialogo de historia).
	for i: int in 60:
		if not is_instance_valid(game_node) or not game_node.is_inside_tree():
			return
		if not game_node.get_tree().paused:
			break
		await game_node.get_tree().create_timer(0.3, true, false, true).timeout
	if not is_instance_valid(game_node) or not game_node.is_inside_tree() or game_node.get_node_or_null("Tutorial") != null:
		return
	var t: Tutorial = Tutorial.new()
	t.name = "Tutorial"
	t.game = game_node
	t.steps = steps_for(kit)
	game_node.add_child(t)


func _ready() -> void:
	layer = 58
	var root: Control = Control.new()
	root.theme = UI.theme
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_ring = Control.new()
	_ring.name = "Ring"
	_ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.draw.connect(_draw_ring)
	root.add_child(_ring)
	_box = PanelContainer.new()
	_box.name = "TutorialBox"
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_box.offset_left = 40.0
	_box.offset_right = -40.0
	root.add_child(_box)
	var col: VBoxContainer = VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 6)
	_box.add_child(col)
	_text = Label.new()
	_text.name = "Text"
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_text)
	var skip: Button = UI.make_button(Kit.text("tut_skip", "Saltar tutorial"), false, "")
	skip.name = "BtnSkipTutorial"
	skip.size_flags_horizontal = Control.SIZE_SHRINK_END
	skip.add_theme_font_size_override("font_size", 20)
	skip.pressed.connect(finish)
	col.add_child(skip)
	QA.logged.connect(_on_event)
	QA.log_event("tutorial_start", {"steps": steps.size()})
	_go(0)


func _go(i: int) -> void:
	if _hooked != null and is_instance_valid(_hooked) and _hooked.is_connected("pressed", _next):
		_hooked.disconnect("pressed", _next)
	_hooked = null
	index = i
	if index >= steps.size():
		finish()
		return
	var s: Dictionary = steps[index]
	_text.text = str(s["text"])
	_target = _find(str(s["target"]))
	_base = str(_read(str(s["until"]).trim_prefix("change:"))) if str(s["until"]).begins_with("change:") else ""
	_t = 0.0
	_armed = 0.4
	if str(s["until"]) == "press" and _target is BaseButton:
		_hooked = _target
		_target.connect("pressed", _next)
	_place_box()
	if is_instance_valid(_box):
		UI.pop_in(_box, 0.0)


func _next() -> void:
	_go(index + 1)


func finish() -> void:
	if is_queued_for_deletion():
		return
	QA.log_event("tutorial_done", {"step": index, "steps": steps.size()})
	finished_tutorial.emit()
	queue_free()


func _find(target: String) -> Control:
	if target == "" or game == null:
		return null
	return game.find_child(target, true, false) as Control


## Valor del juego por ruta: "moves", "st.gold", "st.p.1.mana".
func _read(path: String) -> Variant:
	var v: Variant = game
	for part: String in path.split("."):
		if v is Object:
			v = (v as Object).get(part)
		elif v is Dictionary:
			v = (v as Dictionary).get(part, (v as Dictionary).get(int(part)) if part.is_valid_int() else null)
		elif v is Array and part.is_valid_int() and int(part) < (v as Array).size():
			v = (v as Array)[int(part)]
		else:
			return null
	return var_to_str(v)


func _on_event(e: Dictionary) -> void:
	if index < 0 or index >= steps.size():
		return
	var u: String = str(steps[index]["until"])
	if u.begins_with("event:") and str(e.get("event", "")) == u.trim_prefix("event:"):
		_next.call_deferred()
	elif str(e.get("event", "")) == "level_complete" or str(e.get("event", "")) == "death":
		## La partida acaba: el tutorial ya no hace falta.
		finish.call_deferred()


func _process(delta: float) -> void:
	if game == null or not is_instance_valid(game) or index >= steps.size():
		return
	_t += delta
	_armed -= delta
	var s: Dictionary = steps[index]
	## El boton objetivo puede rehacerse (barras que cambian): se busca otra vez por su nombre.
	if str(s["target"]) != "" and (_target == null or not is_instance_valid(_target) or _target.is_queued_for_deletion()):
		_target = _find(str(s["target"]))
		if str(s["until"]) == "press" and _target is BaseButton and _hooked != _target:
			_hooked = _target
			_target.connect("pressed", _next)
	var u: String = str(s["until"])
	if u.begins_with("change:") and str(_read(u.trim_prefix("change:"))) != _base:
		_next()
	elif u.begins_with("wait:") and _t >= float(u.trim_prefix("wait:")):
		_next()
	_ring.queue_redraw()


func _input(event: InputEvent) -> void:
	if index < 0 or index >= steps.size() or str(steps[index]["until"]) != "tap" or _armed > 0.0:
		return
	var pressed: bool = (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed) \
		or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed)
	if pressed:
		_next.call_deferred()


## Caja de texto arriba, o abajo si lo senalado esta arriba.
func _place_box() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size if get_viewport() != null else Vector2(720, 1280)
	var up: bool = _target != null and is_instance_valid(_target) and _target.get_global_rect().get_center().y < vp.y * 0.45
	if up:
		_box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		_box.offset_top = -330.0
		_box.offset_bottom = -200.0
	else:
		_box.set_anchors_preset(Control.PRESET_TOP_WIDE)
		_box.offset_top = 190.0
		_box.offset_bottom = 320.0
	_box.offset_left = 40.0
	_box.offset_right = -40.0


## Anillo que late alrededor de lo que hay que tocar.
func _draw_ring() -> void:
	if _target == null or not is_instance_valid(_target) or not _target.is_visible_in_tree():
		return
	var r: Rect2 = _target.get_global_rect().grow(10.0 + 6.0 * sin(_t * 6.0))
	var col: Color = UI.colors["acento"]
	_ring.draw_rect(r, Color(col, 0.18), true)
	_ring.draw_rect(r, col, false, 6.0)
