"""Agente programador: cuando el taller no sabe hacer un cambio, Claude lo PROGRAMA como un mod.

Un mod es un script pequeno de GDScript que hereda de res://kit/mod_base.gd y solo reacciona a los
eventos de la partida con una API acotada (textos, particulas, temblor, sonidos, monedas, leer
parametros, tocar al heroe...). Asi la IA puede hacer cosas nuevas sin poder romper el kit.

Barreras (en este orden, antes de que el juego llegue a nadie):
	1 - Revision de seguridad del codigo (lista negra, sin load/preload, sin archivos, sin red...).
	2 - Reglas del kit: hereda de la base, tabulaciones, ASCII, sin class_name, tamano maximo.
	3 - Godot compila el script (--check-only).
	4 - Partida de humo con el mod puesto: ni un SCRIPT ERROR.
	5 - Los bots juegan todos los niveles con el mod (cadena.validar_con_bots): sigue siendo ganable.
Si algo falla, los errores vuelven a Claude (hasta 3 rondas). Si no lo consigue, no se cambia nada.

	python -m agente_mods <proyecto> "que el heroe suelte chispas doradas al saltar" [--simulado]
"""

import argparse
import json
import re
import shutil
import sys
from pathlib import Path

import agente_genero
import cadena
import versiones
from director import llm
from cadena import ErrorCadena, evento

RAIZ = Path(__file__).resolve().parent
BASE_API = (cadena.KIT / "kit" / "mod_base.gd").read_text(encoding="utf-8")
REGLA_API = (cadena.KIT / "kit" / "rule_base.gd").read_text(encoding="utf-8")
## Generos cuya simulacion llama a las reglas (rule_base.gd): ahi la IA puede cambiar la mecanica.
GENEROS_REGLAS = {
	"falling": "st: grid (Array de filas de 10, '' vacio o letra), piece {kind, rot, pos}, pieces, lines, goal, score, rng, busy (casillas de la pieza que cae).",
	"sandbox": "st: grid (PackedByteArray w*80; para cambiar una casilla: var g = st['grid']; g[y*w+x] = id; st['grid'] = g), w, inv (objeto -> cantidad), got, hp, p (pies del jugador), mobs, clock, rng.",
	"royale": "st: agents (Array de {id, p, hp, armor, weapon, alive, kills, heals}), loot (Array de {p, item}), zone_c, zone_r, time, rng. agents[0] es el jugador.",
	"tycoon": "st: mode (biz o mine), money, earned, target, t, stations (id -> {kind: biz/shaft/lift/store, n: unidades o nivel, mgr, run, prog 0-1, box}), order (ids), ups, upgrades, stock, bonus (multiplicador global). Ganchos on_cycle(st, id, cantidad) y on_buy(st, id, cuantas).",
	"slots": "st: coins, spins, bet, builds (Array de {id, stage, costs}), bonus ({} o pick/raid), last (los 3 simbolos), pos y dice (estilo dados), t, rng. Ganchos on_spin(st, resultado {reels, coins, spins, bonus}) y on_build(st, i).",
	"realm": "st: res (food/wood/stone), lv (edificio -> nivel), queue, army (infantry/cavalry/archer), heroes, camps (Array de {name, army, reward, hero, boss, done}), t, help_t. Ganchos on_upgrade(st, edificio) y on_battle(st, resultado {win, att, def, lost, camp}).",
	"crowd": "st: n (gente), x (-1 a 1), d (metros), i, track (Array de {d, t: gate/enemy/trap/boss, l, r, n, lane, k}), speed, won, lost, rng. Gancho on_event(st, info {e, lane, before, after}): cambia st['n'].",
	"mergeboard": "st: grid (Vector2i -> {c, l} o {gen}), chains, orders (Array de {who, need, reward, done}), energy, regen, t, coins, rng. Ganchos on_tap(st, generador, celda), on_merge(st, celda) y on_deliver(st, i).",
	"wordle": "st: word, len, tries, hard, rows (intentos), marks (pistas G/Y/.), keys, won, over, hint_left, rng. Gancho on_guess(st, intento, pistas).",
	"letters": "st: b ({root, letters, words, place, grid}), found, bonus, revealed, hints, won, misses, rng. Gancho on_word(st, palabra, resultado: word/bonus/again/'').",
	"powertower": "st: p (poder del heroe), towers (Array de torres; cada una Array de salas {t: enemy/bonus/trap/boss, p, op, done}), moves, won, lost, rng. Gancho on_pick(st, out) con out {ok, before, after, kind, tower, room}: p. ej. que cada trampa vencida de un escudo o que el jefe crezca.",
	"spotdiff": "st: found (indices de diferencias halladas), spots (Array de Vector2 0-1), mistakes, max_mistakes, hints, won, lost, rng. Gancho on_tap(st, punto, resultado) (resultado: indice hallado o -1 si fallo): p. ej. dar una pista extra cada 3 aciertos o perdonar el primer fallo.",
	"jigsaw": "st: n (lado), slots (que pieza hay en cada hueco; en su sitio si slots[i] == i), moves, max_moves, won, lost, rng. Gancho on_swap(st, a, b, colocadas): p. ej. dar un cambio extra cada vez que se colocan dos piezas a la vez.",
	"paintnum": "st: w, h, cells (PackedByteArray: numero de color o 0 fondo), painted (1 pintado), palette, sel, mistakes, fills, left, won, rng. Gancho on_paint(st, x, y, resultado) (1 pintado, -1 fallo): p. ej. un cubo extra al terminar cada color o perdonar los fallos del primer minuto.",
	"knifehit": "st: rot (giro del tronco en grados), t, spin (tramos {v, d}), knives (angulos clavados), apples, got, to_throw, thrown, flying, won, lost, rng. Ganchos on_hit(st, out) con out {ok, angle, apple} y on_step(st, dt): p. ej. que cada manzana de un cuchillo menos o que el tronco acelere con cada acierto.",
	"rogue": "st: hero {p (Vector2 en la arena de 9x14), hp, max_hp, cd, inv}, enemies (Array de {k, p, hp, max}), arrows, bullets, skills (nombre -> nivel), room, phase (fight/pick/won/lost), power, t, kills, won, lost, rng. Ganchos on_kill(st, enemigo), on_hurt(st, dano), on_pick(st, habilidad) y on_step(st, dt): p. ej. curar 5 por cada baja o que cada sala empiece con escudo.",
	"arrows": "st: w, h, arrows (Array de {x, y (punta), d: u/d/l/r, n: largo, out}), left, lives, mistakes, moves, won, lost, rng. Gancho on_tap(st, out) con out {ok, by (la que estorba), i}: p. ej. que la primera colision no cueste vida o una vida extra cada 10 flechas.",
	"merge2048": "st: n, b (Array n*n: 0 vacio, -1 roca, o el valor), target, score, moves, best, undo, won, lost, rng (no usar para la jugada: es el azar de las fichas). Gancho on_move(st, dir, r) con r {moved, gain, anim, spawn}: p. ej. un deshacer extra al hacer 128 o puntos dobles en las fusiones de 4 en 4.",
	"crazy8": "st: n (jugadores; 0 eres tu), hands (Array de manos), draw (mazo, se roba del final), discard (mesa), color, turn, dir, drew, turns, winner, won, lost, rng. Gancho on_play(st, jugador, carta): p. ej. que los 7 hagan robar 1 al siguiente o que jugar dos cartas iguales seguidas te deje volver a jugar.",
	"domino": "st: n (jugadores; 0 eres tu), hands (Array de manos; ficha = [a, b]), pool (pozo), chain (la mesa), left, right (puntas), turn, passes, turns, winner, won, lost, rng. Gancho on_play(st, jugador, ficha, lado): p. ej. que un doble te deje volver a jugar o que el 5-5 haga robar al siguiente.",
	"blockjam": "st: w, h, walls (Vector2i -> true), blocks (Array de {c, p: Vector2i, cells, out}), doors (Array de {side, at, len, c}), moves, max_moves, left, won, lost, rng. Ganchos on_move(st, i, dir) y on_exit(st, i): p. ej. que al salir un bloque se abra una puerta nueva o que cada salida de pasos extra.",
	"pipes": "st: w, h, tiles (mascara de cada casilla: 1 arriba, 2 derecha, 4 abajo, 8 izquierda), src (Vector2i del grifo), wet (casillas con agua), taps, max_taps, won, lost, rng. Gancho on_tap(st, casilla): p. ej. que girar una pieza con agua de un giro extra.",
	"chess": "st: b (Array de 64 casillas, 0 = a8 ... 63 = h1; \"\" vacia, mayuscula tuyas/blancas, minuscula del rival), white (le toca a las blancas), plies, max_plies, rival, mistake, last, won, lost, draw, rng. Gancho on_move(st, [desde, hasta], comida): p. ej. que cada pieza comida de un peon de regalo.",
	"reversi": "st: b (Array de n*n: 0 vacia, 1 tuya, 2 del rival), n (lado), turn (1 o 2), plies, passes, rival, mistake, last, flipped (las que se dieron la vuelta), won, lost, draw, rng. Gancho on_place(st, casilla, vueltas, quien): p. ej. que dar la vuelta a 5 o mas de golpe de una ficha extra.",
	"hidden": "st: shapes (figuras {k, x, y, s, c}), targets (indices que hay que encontrar), found, misses, max_misses, time, elapsed, hints, hinted, won, lost. Ganchos on_found(st, indice) y on_miss(st, punto): p. ej. que encontrar dos seguidas sin fallar de segundos extra.",
	"slide": "st: n (lado), tiles (pieza en cada casilla; la n*n-1 es el hueco), moves, max_moves, last (movimientos del ultimo toque), won, lost. Gancho on_slide(st, casilla, cuantas): p. ej. que mover 3 de golpe regale un movimiento.",
	"hangman": "st: word (la palabra), lang, guessed (letras probadas), misses, lives (globos), hints, last, won, lost. Ganchos on_hit(st, letra) y on_miss(st, letra): p. ej. que acertar una vocal a la primera de un globo extra (sube lives).",
	"battle": "st: n, ships (largos), mine y theirs (tableros: numero de barco o 0), shots_mine y shots_theirs (casilla -> x tocado / o agua), turn (1 tu, 2 rival), rival, mistake, last, last_result, shots, won, lost, rng. Gancho on_shot(st, casilla, resultado, tuyo): p. ej. que hundir un barco destape una casilla de otro.",
	"simon": "st: pads, goal, seq (la secuencia entera), round, pos (por donde vas), lives, speed, mistakes, won, lost. Ganchos on_round(st, ronda) y on_miss(st, boton): p. ej. que cada 3 rondas sin fallar las luces vayan un poco mas lentas (baja speed).",
	"tactics": "st: map (filas de terreno), w, h, units (Array de {id, t: inf/tank/art, x, y, side 1 tu 2 rival, hp, moved, done}), owner (casilla -> bando de ciudades y cuarteles), caps (capturas en curso), side, turn, max_turns, won, lost, rng. Ganchos on_move(st, unidad, desde, hasta), on_attack(st, atacante, defensor, dano) y on_capture(st, unidad, casilla): p. ej. que cada ciudad capturada cure 3 a todas tus unidades.",
	"autochess": "st: round, rounds (ejercitos rivales), lives, gold, income, slots, board y bench (unidades {id, t, s estrellas, x, y}), shop, wins, last (win/loss), won, lost, rng. Ganchos on_buy(st, tipo), on_merge(st, tipo, estrellas) y on_round_end(st, ganador): p. ej. que fundir una unidad de 2 oro extra.",
	"gemrpg": "st: board (49 gemas: 0 fuego, 1 agua, 2 naturaleza, 3 luz, 4 sombra, 5 corazon), team ({c, atk, skill, charge}), hp, max_hp, waves, wave, enemies ({c, hp, max, atk, every, cd}), moves, stun, won, lost, rng. Ganchos on_swap(st, resultado) y on_skill(st, heroe): p. ej. que un combo de 3 o mas cargue un poco a todo el equipo.",
	"ccg": "st: side (1 tu, 2 rival), turn, p[1] y p[2] = {hp, max_hp, deck, hand (ids), board (esbirros {uid, id, atk, hp, max, kw, ready, shield}), mana, max_mana, fatigue}, won, lost, rng. Ganchos on_play(st, bando, carta) y on_attack(st, bando, atacante, objetivo): p. ej. que cada esbirro que juegas cure 1 a tu heroe.",
	"crawl": "st: p (casilla del heroe), hp, max_hp, atk, def, potions, gold, xp, sight, turn, mons (lista de {k, p, hp, max, atk, def, awake}; k: r rata, g goblin, o orco, s esqueleto, B jefe), items ({casilla: letra}), seen, stairs, won, lost. Ganchos on_start(st), on_kill(st, letra_del_monstruo) y on_item(st, letra_del_objeto): p. ej. que cada monstruo que matas te cure 2.",
	"bomber": "st: p (casilla del heroe), lives, shield, max_bombs, range, speed (ticks por paso), bombs (lista de {p, t, r}), flames ({casilla: ticks}), enemies (lista de {k, p, dir, alive}; k: e globo, c perseguidor, f rapido), items, hidden, exit, kills, crates, tick (10 por segundo), won, lost. Ganchos on_start(st), on_kill(st, letra_del_monstruo) y on_item(st, letra_del_premio): p. ej. que cada monstruo vencido de una bomba mas.",
	"artillery": "st: ground (altura de cada una de las 120 columnas), units (lista de {team 1 tu o 2 rival, x, hp, max, alive}), side (a quien le toca), active (indice del soldado), wind, water, walk_left, turn, won, lost. Ganchos on_start(st), on_fire(st, equipo) y on_kill(st, equipo_del_caido): p. ej. que cada baja del rival cure 20 a tus soldados.",
	"chomp": "st: p (casilla del heroe), dir, want, speed, ghost_speed, dots ({casilla: \".\" punto u \"o\" pildora}), ghosts (lista de {k: chase, ambush, shy o fickle, p, home, eaten}), fright (ticks de susto que quedan), fright_len, combo, score, lives, tick (10 por segundo), won, lost. Ganchos on_start(st), on_eat(st, \".\" u \"o\") y on_ghost(st, tipo): p. ej. que cada fantasma comido alargue el susto 20 ticks.",
	"chain": "st: segs (trozos de la cadena de delante a atras, cada uno {s: distancia de su primera bola por el camino, b: colores}), len (largo del camino), speed, cur y next (bola que disparas y la siguiente), colors, score, combo, shots, popped, tick (20 por segundo), won, lost. Ganchos on_start(st) y on_pop(st, cuantas): p. ej. que cada combo de 5 o mas frene la cadena (st[\"speed\"] baja).",
	"fighter": "st: f (los dos luchadores: 0 tu y 1 el rival, cada uno {x, y, face, hp, max, meter, state: idle, walk, jump, block, attack, stun o ko, move}), shots (bolas de energia), round, wins, time (ticks que quedan del asalto), ai, style, tick (20 por segundo), won, lost. Ganchos on_start(st) y on_hit(st, quien_recibe, dano): p. ej. que cada golpe que das te cure 1.",
	"fruitmerge": "st: fruits (lista de {id, t: tipo 0 cereza .. 10 sandia, p: posicion, v: velocidad}), cur y next (tipos que vas a soltar), goal (tipo a conseguir), drop_max, w (ancho del tarro), score, merges, drops, over (ticks por encima de la linea), tick (30 por segundo), won, lost. Ganchos on_start(st) y on_merge(st, tipo_nuevo): p. ej. que cada fusion de tipo 5 o mas quite la fruta mas pequena del tarro.",
	"pinball": "st: ball ({p, v} o vacio entre bolas), balls (bolas que quedan), score, goal, mult (multiplicador 1..4), bumpers (lista de {p, flash}), targets (lista de {p, down}), lanes (tres pasillos de arriba), flip (angulo de cada pala), gravity, tick (60 por segundo), won, lost. Ganchos on_start(st) y on_score(st, que, puntos) con que: bumper, sling, target, bank, lane o lanes; p. ej. que cada seta valga el doble.",
	"metroid": "st: p (casilla del heroe), rise, abil ({J doble salto, D impulso, B martillo}: true o false), keys, items ({casilla: letra}), enemies (lista de {p, dir, alive}), hp, max_hp, coins, goal, seen (salas visitadas), tick (10 por segundo), won, lost. Ganchos on_start(st), on_item(st, letra) y on_kill(st): p. ej. que empieces ya con el doble salto (st[\"abil\"][\"J\"] = true en on_start).",
	"stealth": "st: p (punto del heroe), nodes, edges, exit, item (maletin), has_item, guards (lista de {p, d: N S E W, kind: stand patrol o rotate, alive}), moves, par, kills, won, lost. Ganchos on_start(st) y on_kill(st, tipo): p. ej. que cada guardia eliminado te devuelva un movimiento (st[\"moves\"] -= 1)."
}
## Reglas vivas: los generos de escena (kit/mods.gd -> LIVE_GENRES) no tienen simulacion en un
## diccionario; la regla recibe los eventos de la partida y mueve unos mandos que el juego lee.
GENEROS_VIVOS = ("platformer", "runner", "flyer", "horde", "tower", "race")
_VIVA = ("REGLA VIVA. st: tune (mandos que el juego lee en cada fotograma; multiplicadores, 1 = normal, con limites: "
	"speed 0.5-2 velocidad del heroe, jump 0.75-1.5 salto, gravity 0.6-1.5, enemy_speed 0.3-2.5, damage 0.3-4 dano del heroe, "
	"fire_rate 0.3-4 cadencia de disparo), stats (cuantas veces ha pasado cada evento), data (Dictionary libre), "
	"say (texto corto que el juego muestra una vez), t (segundos), level, rng. Ganchos: on_start(st), on_step(st, dt), "
	"on_event(st, nombre, datos) y on_<evento>(st, datos) con los eventos de este genero: {eventos}. "
	"P. ej. cada 5 monedas corre un 10 % mas, o tras un golpe los enemigos van mas lentos unos segundos.")
## Una regla es pura: ni nodos, ni escena, ni azar del motor (rompe la comprobacion con bots).
NEGRA_REGLA = [r"\bget_tree\b", r"\bget_node", r"\badd_child\b", r"\bInput\b", r"\brandf\(", r"\brandi\(", r"\brandf_range\(",
	r"\brandi_range\(", r"\brandomize\(", r"\bNode2D\b", r"\bTween\b", r"\bTimer\b", r"\bAudio\.", r"\bUI\.", r"\bJuice\.",
	r"\bSave\.", r"\bKit\."]
MAX_CHARS = 6000
## Ademas de la lista negra de los generos: nada de archivos, escenas, reinicios ni tocar otros sistemas.
NEGRA_MOD = agente_genero.NEGRA_GD + [r"\bFileAccess\b", r"\bload\(", r"\bpreload\(", r"\bchange_scene", r"\bquit\(",
	r"\bSave\.(reset_all|data|save_data|spend)", r"\bMods\.", r"\bset_script\b", r"\bOS\.", r"\bEngine\.", r"\bQA\.",
	r"\bTelemetry\.", r"\bAds\.", r"\bKit\.(set_config|config\s*=)", r"\bget_tree\(\)\.(root|quit|reload)",
	r"\bProjectSettings\b", r"\bInput\.(parse_input_event|action_press)"]

HERRAMIENTA = {
	"name": "escribir_mod",
	"description": "Entrega el mod completo.",
	"input_schema": {
		"type": "object", "additionalProperties": False,
		"required": ["nombre", "codigo", "resumen"],
		"properties": {
			"tipo": {"type": "string", "enum": ["mod", "regla"], "description": "mod (efectos y eventos) o regla (cambia la mecanica; solo en los generos que lo permiten)"},
			"nombre": {"type": "string", "pattern": "^[a-z][a-z0-9_]{2,30}$", "description": "nombre_del_archivo (sin .gd)"},
			"codigo": {"type": "string", "description": "GDScript completo; primera linea: extends \"res://kit/mod_base.gd\" (mod) o extends \"res://kit/rule_base.gd\" (regla)"},
			"resumen": {"type": "string", "maxLength": 300, "description": "Lo que hace, en espanol, para el usuario"},
		},
	},
}

PROMPT = """Eres programador senior de Godot 4.6 (GDScript) en la fabrica de juegos Orquestador.
Escribes MODS: un script que hereda de res://kit/mod_base.gd y anade una mecanica o efecto al juego
reaccionando a sus eventos. Esta es la API completa de la base (no hay otra):

{api}

Reglas obligatorias (si no se cumplen, el mod se rechaza):
- Primera linea exacta: extends "res://kit/mod_base.gd". Sin class_name.
- Tipos explicitos en variables y funciones. Sangria con TABULACIONES. Solo ASCII (textos con \\u00e1 etc.).
- Solo la API de la base y nodos/recursos que crees en codigo (Node2D, Polygon2D, Label, Timer, Tween...).
- Prohibido: load/preload, archivos, red, OS, Engine, ProjectSettings, cambiar de escena, tocar Save salvo
  add_wallet, tocar Ads/QA/Telemetry/Mods, simular entradas del jugador.
- El juego tiene que seguir siendo ganable y justo: no quites vidas sin motivo ni bloquees la meta.
- Ligero: nada de bucles pesados en on_tick; limpia los nodos que crees (queue_free).
- Si el heroe existe: player() devuelve su Node2D (position, velocity si es CharacterBody2D).
{reglas}
Juego: {juego}
Genero (kit): {genero}
Eventos que emite este juego: {eventos}
Mods que ya tiene: {mods}
"""

EVENTOS = {
	"platformer": "level_start, level_complete, death, coin, hit, hurt, stomp, power, checkpoint, boss_spawn, boss_hit, boss_defeated",
	"runner": "level_start, level_complete, death, coin, hit, hurt, power",
	"flyer": "level_start, level_complete, death, coin, hit",
	"horde": "level_start, level_complete, death, hurt, upgrade, wave_start, wave_clear, boss_spawn, boss_defeated",
	"match3": "level_start, level_complete, defeat",
	"tower": "level_start, level_complete, defeat, tower_build, wave_start, leak, boss_spawn",
	"race": "level_start, level_complete, defeat, coin, nitro, crash",
}

## Generos que llaman a las reglas desde su propia simulacion (kit/mods.gd -> SIM_RULES).
GENEROS_SIM = tuple(sorted(GENEROS_REGLAS)) + ("custom",)
for _g in GENEROS_VIVOS:
	GENEROS_REGLAS[_g] = _VIVA.format(eventos=EVENTOS.get(_g, EVENTOS["platformer"]))
## El resto de generos (de escena, sin simulacion en un diccionario): regla viva con un solo mando,
## la velocidad de toda la partida (camara lenta o rapida), y los eventos de siempre.
_VELOCIDAD = ("REGLA VIVA (solo velocidad). st: tune con un unico mando, game_speed (velocidad de toda la partida, "
	"0.5-1.5; 1 = normal), stats (cuantas veces ha pasado cada evento), data (Dictionary libre), say (aviso corto que se "
	"muestra una vez), t, level, rng. Ganchos: on_start(st), on_step(st, dt), on_event(st, nombre, datos) y on_<evento>(st, datos) "
	"con los eventos: level_start, level_complete, death y los propios del genero. P. ej. camara lenta 3 segundos tras perder "
	"una vida, o que el juego acelere un poco cada vez que aciertas.")


def _generos_kit() -> list[str]:
	import generos
	return sorted({str(g.get("kit", "")) for g in generos.GENEROS.values() if g.get("kit")})


for _g in _generos_kit():
	if _g not in GENEROS_REGLAS and _g != "custom":
		GENEROS_REGLAS[_g] = _VELOCIDAD


PROMPT_REGLAS = """En este genero tambien puedes escribir una REGLA (tipo "regla"): cambia el corazon de la
mecanica (piezas nuevas, casillas que se mueven, objetos que hacen cosas...). La simulacion la llama
en sus ganchos y el analizador y los bots juegan con ella, asi que el juego se vuelve a comprobar
entero. Usala cuando el cambio toque las reglas; para efectos y avisos, un mod. API de las reglas:

{api}

Estado de este genero: {estado}
Reglas de la regla: primera linea extends "res://kit/rule_base.gd"; determinista (azar solo con rnd(st));
sin nodos, escena, Input, Audio ni UI; ligera (se llama en cada paso); el juego sigue siendo ganable.
Si necesitas una casilla nueva, usa una letra libre y da su color en colors()."""


def revisar(nombre: str, codigo: str, tipo: str = "mod") -> list[str]:
	errores = []
	if not re.fullmatch(r"[a-z][a-z0-9_]{2,30}", nombre or ""):
		errores.append("nombre: solo minusculas, numeros y _ (3 a 31 caracteres)")
	base = "rule_base.gd" if tipo == "regla" else "mod_base.gd"
	if not codigo.startswith(f'extends "res://kit/{base}"'):
		errores.append(f'la primera linea debe ser: extends "res://kit/{base}"')
	if len(codigo) > MAX_CHARS:
		errores.append(f"demasiado largo ({len(codigo)} caracteres; maximo {MAX_CHARS})")
	sin_comentarios = "\n".join(ln.split("#", 1)[0] if not ln.lstrip().startswith("##") else "" for ln in codigo.splitlines())
	for patron in NEGRA_MOD + (NEGRA_REGLA if tipo == "regla" else []):
		m = re.search(patron, sin_comentarios)
		if m:
			errores.append(f"no se permite '{m.group(0)}' " + ("(una regla es pura y determinista)" if patron in NEGRA_REGLA else "(seguridad)"))
	errores += [e.replace("mod_gd: ", "") for e in agente_genero.revisar({"mod_gd": codigo, "generador_py": "def generar_x(): pass"})
		if e.startswith("mod_gd")]
	return errores


def compilar(proyecto: Path, ruta_res: str, tipo: str = "mod") -> list[str]:
	"""Godot carga el mod con los autoloads del kit (qa/compilar_mod.tscn) y dice si compila."""
	for f in ("compilar_mod.gd", "compilar_mod.tscn"):
		shutil.copy2(cadena.KIT / "qa" / f, proyecto / "qa" / f)
	for f in ("rule_base.gd", "rules.gd"):
		if not (proyecto / "kit" / f).exists():
			shutil.copy2(cadena.KIT / "kit" / f, proyecto / "kit" / f)
	r = cadena.godot(proyecto, "res://qa/compilar_mod.tscn", "--", f"--{'rule' if tipo == 'regla' else 'mod'}={ruta_res}", timeout=120)
	salida = (r.stdout or "") + (r.stderr or "")
	if "[MOD_OK]" in salida:
		return []
	errores = [ln.strip() for ln in salida.splitlines() if ("SCRIPT ERROR" in ln or "Compile Error" in ln or "Parse Error" in ln)]
	return (errores or [salida.strip()[-300:] or "Godot no pudo compilar el mod"])[:6]


def humo(proyecto: Path) -> list[str]:
	"""Partida corta con el mod: los SCRIPT ERROR del mod aparecen aqui."""
	r = cadena.godot(proyecto, "--fixed-fps", "60", "--quit-after", "600", "res://qa/clip.tscn", "--", "--seconds=6", "--raw",
		timeout=300, display=False)
	salida = (r.stdout or "") + (r.stderr or "")
	return [ln.strip() for ln in salida.splitlines() if "SCRIPT ERROR" in ln or ("mods/" in ln and "ERROR" in ln)][:6]


def _mensajes(instruccion: str, intento: dict | None, errores: list[str]) -> list[dict]:
	mensajes = [{"role": "user", "content": f"Programa este cambio como un mod: {instruccion}"}]
	if intento:
		mensajes += [
			{"role": "assistant", "content": [{"type": "tool_use", "id": "m1", "name": "escribir_mod", "input": intento}]},
			{"role": "user", "content": [{"type": "tool_result", "tool_use_id": "m1", "is_error": True,
				"content": "El mod no pasa las comprobaciones. Corrige SOLO esto y vuelve a entregarlo completo:\n- " + "\n- ".join(errores[:10])}]},
		]
	return mensajes


def simulado_regla(instruccion: str) -> dict:
	"""Regla de ejemplo sin IA (caida): piezas de agua que se derraman."""
	codigo = (cadena.KIT / "qa" / "regla_agua.gd").read_text(encoding="utf-8")
	return {"tipo": "regla", "nombre": "piezas_de_agua", "codigo": codigo,
		"resumen": "Una de cada tres piezas es de agua: al caer se derrama y rellena los huecos."}


def simulado_regla_viva(instruccion: str) -> dict:
	"""Regla viva de ejemplo sin IA (plataformas, hordas...): cada moneda acelera al heroe."""
	codigo = (cadena.KIT / "qa" / "regla_viva.gd").read_text(encoding="utf-8")
	return {"tipo": "regla", "nombre": "monedas_turbo", "codigo": codigo,
		"resumen": "Cada moneda o enemigo vencido te acelera un poco (hasta un 40 %); un golpe te devuelve a tu velocidad."}


def simulado_regla_lenta(instruccion: str) -> dict:
	"""Regla viva de ejemplo sin IA (generos de escena con solo velocidad): camara lenta tras un golpe."""
	codigo = (cadena.KIT / "qa" / "regla_lenta.gd").read_text(encoding="utf-8")
	return {"tipo": "regla", "nombre": "camara_lenta", "codigo": codigo,
		"resumen": "Al perder una vida, 3 segundos de cámara lenta para recolocarte."}


def simulado(instruccion: str) -> dict:
	"""Mod de ejemplo sin IA (para probar el circuito): chispas doradas y un texto al empezar."""
	return {"nombre": "chispas_doradas", "resumen": "Al empezar cada nivel salen chispas doradas y un aviso; al morir, la pantalla destella.",
		"codigo": 'extends "res://kit/mod_base.gd"\n## Mod simulado: ' + re.sub(r"[^ -~]", "?", instruccion)[:60] + '\n\n'
		'func on_level_start() -> void:\n\ttoast("\\u00a1A por todas!")\n\tvar p: Node2D = player()\n\tif p != null:\n'
		'\t\tburst(p.global_position, Color(1.0, 0.85, 0.2), 24)\n\n\n'
		'func on_event(event_name: String, _data: Dictionary) -> void:\n\tif event_name == "death":\n\t\tflash_screen(Color(1, 0.3, 0.2, 0.4))\n'}


def programar(proyecto: Path, instruccion: str, simulado_: bool, gasto: llm.Gasto, rondas: int = 3,
		llamar=None) -> dict:
	"""Escribe, comprueba y deja puesto el mod. Devuelve {nombre, resumen, ruta, rondas}. Lanza ErrorCadena si no sale."""
	game = json.loads((proyecto / "game.json").read_text(encoding="utf-8"))
	diseno = json.loads((proyecto / "fabrica" / "diseno.json").read_text(encoding="utf-8"))
	genero = str(game.get("genre", "platformer"))
	ya = sorted(m.stem for m in (proyecto / "mods").glob("*.gd")) if (proyecto / "mods").exists() else []
	reglas = PROMPT_REGLAS.format(api=REGLA_API, estado=GENEROS_REGLAS[genero]) if genero in GENEROS_REGLAS else \
		"En este genero solo se pueden escribir mods (tipo \"mod\")."
	sistema = PROMPT.format(api=BASE_API, juego=json.dumps({"titulo": diseno.get("titulo"), "heroe": diseno.get("heroe", {}).get("nombre"),
		"resumen": diseno.get("resumen")}, ensure_ascii=False), genero=genero, eventos=EVENTOS.get(genero, EVENTOS["platformer"]),
		mods=", ".join(ya) or "ninguno", reglas=reglas)
	intento: dict | None = None
	errores: list[str] = []
	for ronda in range(1, rondas + 1):
		evento("programar", "inicio", "Chispa está programando el cambio..." if ronda == 1 else f"Corrigiendo (intento {ronda})...")
		if simulado_:
			pide_regla = re.search(r"agua|regla|mecanica|mec\u00e1nica|r[aá]pid|velocidad|lent", instruccion.lower())
			intento = simulado_regla(instruccion) if genero == "falling" and pide_regla else \
				simulado_regla_viva(instruccion) if genero in GENEROS_VIVOS and pide_regla else \
				simulado_regla_lenta(instruccion) if genero in GENEROS_REGLAS and genero not in GENEROS_SIM and pide_regla else simulado(instruccion)
		elif llamar is not None:
			intento = llamar(sistema, _mensajes(instruccion, intento, errores))
		else:
			intento = llm.llamar_herramienta(llm.MODELOS[-1], sistema, _mensajes(instruccion, intento, errores), HERRAMIENTA,
				gasto, "agente_mods", max_tokens=4000)
		nombre, codigo = str(intento.get("nombre", "")), str(intento.get("codigo", ""))
		tipo = "regla" if str(intento.get("tipo", "mod")) == "regla" else "mod"
		if tipo == "regla" and genero not in GENEROS_REGLAS:
			errores = [f"este genero ({genero}) no admite reglas: escribe un mod"]
			continue
		errores = revisar(nombre, codigo, tipo)
		if errores:
			continue
		lista = "rules" if tipo == "regla" else "mods"
		mods = proyecto / "mods"
		mods.mkdir(exist_ok=True)
		ruta = mods / f"{nombre}.gd"
		previo = ruta.read_text(encoding="utf-8") if ruta.exists() else None
		ruta.write_text(codigo, encoding="utf-8")
		game[lista] = sorted(set(game.get(lista, [])) | {f"res://mods/{nombre}.gd"})
		(proyecto / "game.json").write_text(json.dumps(game, indent=1, ensure_ascii=False), encoding="utf-8")
		cadena.godot(proyecto, "--import", timeout=600)
		errores = compilar(proyecto, f"res://mods/{nombre}.gd", tipo) or humo(proyecto)
		if not errores:
			evento("programar", "ok", intento.get("resumen", "Cambio programado"))
			return {"nombre": nombre, "resumen": str(intento.get("resumen", "")), "ruta": str(ruta), "rondas": ronda, "tipo": tipo}
		## Se deshace antes de reintentar: el proyecto nunca se queda con un mod roto.
		if previo is None:
			ruta.unlink()
			game[lista] = [m for m in game[lista] if m != f"res://mods/{nombre}.gd"]
			(proyecto / "game.json").write_text(json.dumps(game, indent=1, ensure_ascii=False), encoding="utf-8")
		else:
			ruta.write_text(previo, encoding="utf-8")
	raise ErrorCadena("No he conseguido programarlo sin romper el juego: " + "; ".join(errores[:3]))


def main(argv: list[str] | None = None) -> int:
	p = argparse.ArgumentParser(description="Agente programador: un cambio nuevo como mod probado")
	p.add_argument("proyecto")
	p.add_argument("instruccion")
	p.add_argument("--simulado", action="store_true")
	a = p.parse_args(argv)
	gasto = llm.Gasto()
	try:
		r = programar(Path(a.proyecto), a.instruccion, a.simulado, gasto)
	except (ErrorCadena, llm.ErrorIA) as e:
		print("ERROR:", e, file=sys.stderr)
		return 1
	print(json.dumps({**r, "usd": gasto.usd, "version": versiones.memoria(Path(a.proyecto)).get("version")}, ensure_ascii=False))
	return 0


if __name__ == "__main__":
	sys.exit(main())
