extends RefCounted
## Base de las REGLAS de un juego (las escribe el agente programador de Orquestador).
## Una regla cambia el corazon de la mecanica, no solo los efectos: la simulacion del genero la
## llama en sus ganchos y le pasa el estado de la partida (st, un Dictionary). Como el analizador y
## los bots usan la MISMA simulacion, cada nivel se vuelve a comprobar con la regla puesta.
## Reglas de oro: determinista (para azar, usa rnd(st), nunca randf), sin nodos ni archivos,
## rapida (se llama en cada paso) y el juego tiene que seguir siendo ganable.
## Ganchos (cada genero llama los suyos; los demas se ignoran):
##   on_start(st)                       al crear la partida
##   on_step(st, dt)                    en cada paso de la simulacion
##   caida (falling):  on_lock(st, cells)  pieza fijada (cells: Array de Vector2i)
##                     on_clear(st, n)     se han borrado n filas
##   mundo (sandbox):  on_break(st, cell, id)  bloque roto - on_craft(st, item)  algo fabricado
##   royale (royale):  on_kill(st, killer_id, victim_id) - on_pick(st, agent, item)
##   tycoon:           on_cycle(st, id, cantidad) un ciclo acabado - on_buy(st, id, cuantas)
##   tragaperras (slots): on_spin(st, resultado) tras cada tirada - on_build(st, edificio)
##   reino (realm):    on_upgrade(st, edificio) obra terminada - on_battle(st, resultado)
##   multitud (crowd): on_event(st, info) tras cada puerta, trampa o grupo (cambia st["n"])
##   pedidos (mergeboard): on_tap(st, generador, celda) - on_merge(st, celda) - on_deliver(st, i)
##   palabra (wordle): on_guess(st, intento, pistas) - letras (letters): on_word(st, palabra, resultado)
##   poder (powertower): on_pick(st, out) - diferencias (spotdiff): on_tap(st, punto, resultado)
##   rompecabezas (jigsaw): on_swap(st, a, b, colocadas) - pintar (paintnum): on_paint(st, x, y, resultado)
##   cuchillos (knifehit): on_hit(st, out) - arquero (rogue): on_kill(st, e), on_hurt(st, dano), on_pick(st, s)
##   flechas (arrows): on_tap(st, out) - 2048 (merge2048): on_move(st, dir, r) - cartas (crazy8): on_play(st, p, carta)
##   REGLAS VIVAS (plataformas, runner, volador, hordas, torres y carreras; kit/mods.gd): st["tune"] son
##     mandos que el juego lee en cada fotograma (speed, jump, gravity, enemy_speed, damage, fire_rate;
##     multiplicadores con limites), st["stats"] cuenta los eventos, st["data"] es libre y st["say"]
##     muestra un aviso. Ganchos: on_event(st, nombre, datos) y on_<evento>(st, datos) (coin, death,
##     hurt, stomp, wave_start...), ademas de on_start y on_step.
##   colors() -> Dictionary             colores de casillas nuevas que use la regla (letra -> Color)


func on_start(_st: Dictionary) -> void:
	pass


func on_step(_st: Dictionary, _dt: float) -> void:
	pass


func colors() -> Dictionary:
	return {}


## Azar determinista de la partida (cada genero guarda su generador en st["rng"]).
func rnd(st: Dictionary) -> float:
	var r: Variant = st.get("rng", null)
	if r is RandomNumberGenerator:
		return (r as RandomNumberGenerator).randf()
	return 0.5
