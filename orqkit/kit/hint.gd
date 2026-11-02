class_name Hint
extends RefCounted
## Pistas en los puzles con solucion exacta (cajas, tubos de colores y sigilo).
## 1 - El juego calcula el siguiente paso con su resolvedor desde como esta el tablero ahora.
##     Si no hay salida desde ahi, lo dice y no cobra nada (hay que deshacer o reiniciar).
## 2 - Precio: la primera pista de cada nivel es gratis; despues, un anuncio con premio (si hay)
##     o COST monedas de la tienda.
## 3 - La pista hace el paso por el jugador (cuenta como un movimiento normal).

const FREE: int = 1
const COST: int = 25


static func used(game: Node) -> int:
	return int(game.get_meta("hints_used", 0))


static func reset(game: Node) -> void:
	game.set_meta("hints_used", 0)


## Como se paga la siguiente: "free", "ad", "coins" o "" (no se puede).
static func price(game: Node) -> String:
	if used(game) < FREE:
		return "free"
	if Ads.rewarded_available():
		return "ad"
	if Save.wallet() >= COST:
		return "coins"
	return ""


## Texto corto (cabe junto a Deshacer y Reiniciar): con monedas lleva el precio.
static func label(game: Node) -> String:
	return Kit.text("hint", "Pista") + (" %d" % COST if price(game) == "coins" else "")


## Cobra la pista. Devuelve true si se puede dar.
static func pay(game: Node) -> bool:
	var p: String = price(game)
	if p == "":
		return false
	if p == "ad":
		var placement: String = "hint"
		var ok: Array[bool] = [false]
		var on_ok: Callable = func(pl: String) -> void:
			if pl == placement:
				ok[0] = true
		Ads.reward_earned.connect(on_ok)
		await Ads.show_rewarded(placement)
		Ads.reward_earned.disconnect(on_ok)
		if not ok[0]:
			return false
	elif p == "coins" and not Save.spend(COST):
		return false
	game.set_meta("hints_used", used(game) + 1)
	QA.log_event("hint", {"level": Kit.level_index, "paid": p})
	return true


## Boton de pista para la barra de abajo del juego.
static func make_button(game: Node, on_press: Callable) -> Button:
	## Sin icono: comparte fila con Deshacer y Reiniciar y asi el texto cabe entero.
	var b: Button = UI.make_button(label(game), false, "")
	b.name = "BtnHint"
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(on_press)
	return b


## Aviso corto encima del tablero (sin salida, sin monedas...).
static func say(game: Node, text: String) -> void:
	var vp: Viewport = game.get_viewport()
	if vp == null:
		return
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 30
	game.add_child(layer)
	var size: Vector2 = vp.get_visible_rect().size
	UI.float_text(layer, Vector2(size.x * 0.5, size.y * 0.3), text, UI.colors["acento"], 30)
