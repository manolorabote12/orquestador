class_name Versus
extends RefCounted
## Modo 2 jugadores en el mismo movil (pasar y jugar) para los juegos de tablero por turnos.
## 1 - Se entra desde la portada ("2 jugadores"): partida justa (sin ventajas del modo campana)
##     como nivel extra, asi no toca estrellas, desbloqueos ni logros.
## 2 - Cada juego deja jugar al segundo jugador en el turno del rival (sin IA) y al acabar llama
##     a Versus.finish(...): cartel de quien gana y revancha.
## 3 - Al volver a la portada o a los niveles se apaga.

const GENRES: Array[String] = ["chess", "reversi", "checkers", "connect"]
const INDEX: int = 9000


static func supported(genre: String) -> bool:
	return GENRES.has(genre)


static func on() -> bool:
	return Kit.versus


## Partida justa: sin piezas quitadas, tablero grande y el primer nivel como base.
static func fair_level() -> Dictionary:
	var levels: Array = Kit.config.get("levels", [])
	var lv: Dictionary = (levels[0] as Dictionary).duplicate(true) if not levels.is_empty() else {}
	match Genres.current():
		"chess":
			lv["quitar"] = []
			lv["max_plies"] = 300
		"reversi":
			lv["size"] = 8
	lv["name"] = Kit.text("vs_two", "2 jugadores")
	return lv


static func start() -> void:
	Kit.versus = true
	Kit.extra_level = fair_level()
	Kit.extra_index = INDEX
	Kit.level_index = INDEX
	QA.log_event("versus_start", {"genre": Genres.current()})


static func stop() -> void:
	if not Kit.versus:
		return
	Kit.versus = false
	if Kit.extra_index == INDEX:
		Kit.extra_index = -1
		Kit.extra_level = {}
		Kit.level_index = 0


static func turn_text(player: int) -> String:
	return Kit.text("vs_turn", "Turno del jugador {n}").format({"n": player})


## Final de la partida: 0 empate, 1 o 2 el que gana. Revancha al cerrar el cartel.
static func finish(game: Node, winner: int) -> void:
	QA.log_event("versus_end", {"genre": Genres.current(), "winner": winner})
	Audio.play("win")
	var title: String = Kit.text("vs_draw", "\u00a1Empate!") if winner == 0 else Kit.text("vs_wins", "\u00a1Gana el jugador {n}!").format({"n": winner})
	var p: FailPanel = FailPanel.open(game, title, Kit.text("vs_again", "Toca para la revancha"))
	p.closed.connect(func() -> void: game.call("retry"))
