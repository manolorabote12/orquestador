extends Node
## Base de los mods del juego (los escribe el agente programador de Orquestador).
## Un mod reacciona a lo que pasa en la partida y usa SOLO esta API (la fabrica lo comprueba):
##   on_level_start()                 empieza un nivel (game ya apunta a la escena de juego)
##   on_event(name, data)             level_complete, death, coin, hit, hurt, stomp, power, boss_spawn,
##                                    boss_hit, boss_defeated, wave_start, wave_clear, checkpoint...
##   on_tick(delta)                   cada fotograma mientras se juega (no en pausa)
## Ayudas: player(), toast(), burst(), shake(), flash_screen(), play_sound(), add_wallet(), param(), level().

var game: Node = null
var _layer: CanvasLayer = null


func on_level_start() -> void:
	pass


func on_event(_event_name: String, _data: Dictionary) -> void:
	pass


func on_tick(_delta: float) -> void:
	pass


## 1 - El heroe de la partida (o null).
func player() -> Node2D:
	if game == null or not is_instance_valid(game):
		return null
	var p: Variant = game.get("player")
	return p as Node2D if p is Node2D else null


## 2 - Texto grande que sube y se desvanece (sobre la pantalla, no sobre el mundo).
func toast(text: String, col: Color = Color.WHITE) -> void:
	if _layer == null or not is_instance_valid(_layer):
		_layer = CanvasLayer.new()
		_layer.layer = 50
		add_child(_layer)
	var size: Vector2 = get_viewport().get_visible_rect().size
	UI.float_text(_layer, Vector2(size.x * 0.5, size.y * 0.32), text.left(40), col, 44)


## 3 - Particulas en el mundo, temblor de camara y destello de pantalla.
func burst(at: Vector2, col: Color, amount: int = 14) -> void:
	if game != null and is_instance_valid(game):
		Juice.burst(game, at, col, clampi(amount, 1, 60))


func shake(amount: float = 6.0) -> void:
	Juice.shake(clampf(amount, 0.0, 20.0))


func flash_screen(col: Color = Color(1, 1, 1, 0.5), seconds: float = 0.15) -> void:
	if _layer == null or not is_instance_valid(_layer):
		_layer = CanvasLayer.new()
		_layer.layer = 50
		add_child(_layer)
	var r: ColorRect = ColorRect.new()
	r.color = col
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(r)
	var tw: Tween = r.create_tween()
	tw.tween_property(r, "color:a", 0.0, clampf(seconds, 0.05, 1.0))
	tw.tween_callback(r.queue_free)


func play_sound(sound_name: String, pitch: float = 1.0) -> void:
	Audio.play(sound_name, 0.05, 0.0, clampf(pitch, 0.5, 2.0))


## 4 - Monedas para la tienda (como mucho 50 de golpe).
func add_wallet(amount: int) -> void:
	Save.add_wallet(clampi(amount, 0, 50))


func param(path: String, fallback: Variant) -> Variant:
	return Kit.param(path, fallback)


func level() -> int:
	return Kit.level_index
