"""Evaluacion de la directora: ¿elige bien el genero (y el publico) a partir de la idea?

	python -m pruebas.eval_director            (directora simulada, sin IA: palabras clave)
	python -m pruebas.eval_director --real     (directora de verdad con la IA; necesita ANTHROPIC_API_KEY
	                                            y cuesta unos centimos por idea)

Las ideas estan escritas como las escribiria la gente (con faltas, mezclas e ideas ambiguas).
Si una idea admite dos generos razonables, se aceptan los dos.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from director import director, llm, simulado  # noqa: E402

CASOS: list[tuple[str, tuple[str, ...]]] = [
	("un gato ninja que salta por los tejados", ("plataformas",)),
	("mario pero con un perro salchicha", ("plataformas",)),
	("un zorro que corre sin parar y salta troncos", ("runner",)),
	("endless runner de un mono en la selva", ("runner",)),
	("un pajaro que vuela entre tuberias tocando la pantalla", ("volador",)),
	("flappy con un dragon bebé", ("volador",)),
	("una rana que salta hacia arriba de nenufar en nenufar", ("saltos",)),
	("doodle jump de un astronauta", ("saltos",)),
	("carreras de coches en la luna", ("carreras",)),
	## Desde que hay karts 3D, "karts" va a su genero; "carreras" (2D) tambien vale.
	("karts de animales en una playa", ("karts", "carreras")),
	("naves espaciales disparando a marcianos", ("naves",)),
	("un matamarcianos retro", ("naves",)),
	("sobrevivir a hordas de zombis", ("horda",)),
	("vampire survivors con gatos", ("horda",)),
	("defender el castillo poniendo torres", ("torres",)),
	("tower defense de hormigas", ("torres",)),
	("romper ladrillos con una pelota", ("rompebloques",)),
	("arkanoid de chuches", ("rompebloques",)),
	("combinar 3 caramelos iguales", ("puzle",)),
	("candy crush de frutas tropicales", ("puzle",)),
	("tetris de bloques de colores", ("caida",)),
	("encajar piezas en un tablero 8x8", ("bloques",)),
	("empujar cajas hasta su sitio en un almacen", ("cajas",)),
	("sokoban de pingüinos", ("cajas",)),
	("la serpiente que come manzanas y crece", ("serpiente",)),
	("snake en el espacio", ("serpiente",)),
	("parejas de cartas de animales para peques", ("memoria",)),
	("juego de memoria de dinosaurios", ("memoria",)),
	("preguntas de historia de españa", ("preguntas",)),
	("un quiz de futbol", ("preguntas",)),
	("apilar pisos de una tarta lo mas alto posible", ("apilar",)),
	("stack de bloques hasta las nubes", ("apilar",)),
	("aplastar topos en un jardin", ("topos",)),
	("whack a mole de ratones", ("topos",)),
	("subway surfers con un skater en tokio", ("corredor",)),
	("correr por carriles esquivando trenes", ("corredor",)),
	("battle royale de robots en una arena", ("arena", "royale")),
	("un minecraft de piratas con islas", ("cubos",)),
	("un juego de supervivencia en una isla desierta", ("supervivencia",)),
	("sobrevivir a hordas de zombis en un cementerio", ("horda",)),
	("un tile match de frutas", ("triple",)),
	("un screw jam de colores", ("tornillos",)),
	("un hexa sort de gemas", ("hexas",)),
	("un gossip harbor en un puerto", ("pedidos",)),
	("un merge mansion para restaurar una casa con pedidos", ("pedidos",)),
	("una torre de poder donde el heroe absorbe a los enemigos mas debiles", ("poder",)),
	("un hero wars de caballeros en torres", ("poder",)),
	("un juego de encontrar las diferencias en el fondo del mar", ("diferencias",)),
	("spot the difference con dibujos de cocina", ("diferencias",)),
	("un rompecabezas con el dibujo de mi heroe", ("rompecabezas",)),
	("un jigsaw de paisajes para relajarse", ("rompecabezas",)),
	("un juego de pintar por numeros de animales", ("pintar",)),
	("colorear dibujos de pixel art para relajarse", ("pintar",)),
	("un knife hit de piratas", ("cuchillos",)),
	("un juego de lanzar cuchillos a un tronco que gira", ("cuchillos",)),
	("un archero de ninjas en un templo", ("arquero",)),
	("un roguelite de habilidades con salas de enemigos", ("arquero",)),
	("un puzle de flechas que salen del tablero", ("flechas",)),
	("un tap away de colores", ("flechas",)),
	("un 2048 con fichas de gatos", ("numeros",)),
	("un juego de juntar numeros iguales deslizando hasta 2048", ("numeros",)),
	("un juego de cartas locas tipo uno con piratas", ("cartas_locas",)),
	("cartas de colores como el uno contra la maquina", ("cartas_locas",)),
	("un domino contra la maquina en un bar de playa", ("domino",)),
	("una partida de domino con amigos del barrio", ("domino",)),
	("un color block jam de juguetes", ("bloques_colores",)),
	("saca los bloques de colores por las puertas de su color", ("bloques_colores",)),
	("un juego de girar tuberias para que llegue el agua", ("tuberias",)),
	("un pipe puzzle de fontanero", ("tuberias",)),
	("un juego de ajedrez contra la maquina", ("ajedrez",)),
	("un chess para aprender a dar jaque mate", ("ajedrez",)),
	("un juego de reversi contra la maquina", ("reversi",)),
	("un othello de fichas que se dan la vuelta", ("reversi",)),
	("un juego de buscar objetos escondidos", ("buscar",)),
	("un hidden object en una casa encantada", ("buscar",)),
	("un puzle de deslizar piezas", ("deslizar",)),
	("un 15 puzzle con el dibujo de mi gato", ("deslizar",)),
	("un juego del ahorcado", ("ahorcado",)),
	("un hangman para aprender palabras", ("ahorcado",)),
	("un juego de hundir la flota", ("flota",)),
	("una batalla naval contra la maquina", ("flota",)),
	("un juego de simon dice", ("simon",)),
	("un juego de repetir la secuencia de colores", ("simon",)),
	("un juego de estrategia por turnos con tanques", ("estrategia",)),
	("un advance wars de animales", ("estrategia",)),
	("un auto chess de animales", ("autobatalla",)),
	("un juego de batalla automatica tipo teamfight tactics", ("autobatalla",)),
	("un puzzle and dragons de piratas", ("gemas",)),
	("un juego de gemas y heroes contra monstruos", ("gemas",)),
	("un juego de cartas coleccionables tipo hearthstone", ("coleccionables",)),
	("un tcg de dragones por turnos", ("coleccionables",)),
	("un roguelike por turnos tipo pixel dungeon", ("roguelike",)),
	("un dungeon crawler por turnos con niebla", ("roguelike",)),
	("un bomberman de robots", ("bombas",)),
	("un juego de poner bombas en un laberinto de cajas", ("bombas",)),
	("un worms de patos con bazucas", ("artilleria",)),
	("un juego de artilleria por turnos con viento", ("artilleria",)),
	("un pacman de gatos", ("comecocos",)),
	("un comecocos con fantasmas en una nave", ("comecocos",)),
	("un zuma con una rana en la selva", ("cadena",)),
	("un juego de disparar bolas a una cadena de colores", ("cadena",)),
	("un juego de lucha tipo street fighter con robots", ("lucha",)),
	("un juego de peleas uno contra uno de ninjas", ("lucha",)),
	("un juego de la sandia con frutas que se juntan", ("sandia",)),
	("un suika de planetas", ("sandia",)),
	("un pinball de neon con robots", ("pinball",)),
	("una maquina de pinball del espacio", ("pinball",)),
	("un metroidvania de un caballero en un castillo", ("metroidvania",)),
	("un juego tipo hollow knight de explorar y conseguir habilidades", ("metroidvania",)),
	("un juego tipo hitman go de espias", ("sigilo",)),
	("un puzle de sigilo por turnos para colarse en un museo", ("sigilo",)),
	("un count masters de vikingos", ("multitud",)),
	("pasar por puertas que multiplican a tu ejercito como en el anuncio de last war", ("multitud",)),
	("un juego tipo kingshot de un reino medieval", ("reino",)),
	("estrategia tipo whiteout survival: ciudad, tropas y conquistar", ("reino",)),
	("un coin master de piratas", ("tragaperras",)),
	("una tragaperras para construir una aldea vikinga", ("tragaperras",)),
	("un idle tycoon de negocios con gerentes", ("tycoon",)),
	("un adventure capitalist de comida rápida", ("tycoon",)),
	("un wordle de animales", ("palabra",)),
	("adivina la palabra del día en seis intentos", ("palabra",)),
	("un wordscapes de viajes por el mundo", ("letras",)),
	("formar palabras con una rueda de letras y un crucigrama", ("letras",)),
	("un plants vs zombies en una granja", ("plantas",)),
	("plantas contra zombis en el jardín de la abuela", ("plantas",)),
	("un angry birds con gatos que tiran castillos", ("tirachinas",)),
	("lanzar pájaros con un tirachinas contra torres", ("tirachinas",)),
	("un hill climb racing con un tractor", ("escalada",)),
	("subir colinas en coche sin volcar con gasolina", ("escalada",)),
	("un clash royale de piratas", ("duelo",)),
	("un duelo de cartas en tiempo real con caballeros y dragones", ("duelo",)),
	("un clash of clans de vikingos", ("aldea",)),
	("un bus jam de pasajeros en una estación", ("autobus",)),
	("subir a los pasajeros al autobús de su color", ("autobus",)),
	("ordenar pilas de hexágonos de colores en un jardín", ("hexas",)),
	("quitar tornillos de placas de madera", ("tornillos",)),
	("un puzle de tuercas y tornillos en un taller", ("tornillos",)),
	("un mahjong solitario en un templo", ("mahjong",)),
	("un obby de saltos con lava y plataformas que se mueven", ("parkour",)),
	("parkour en 3d por los tejados", ("parkour",)),
	("un simulador de supermercado de frutas", ("tienda",)),
	("un juego de futbol con robots", ("futbol",)),
	("partidos de futbol tres contra tres", ("futbol",)),
	("un juego de terror en una mansion", ("terror",)),
	("escapa de la casa encantada de la abuela", ("terror",)),
	("un juego de repartos de pizza conduciendo por la ciudad", ("conduccion",)),
	("un taxi que lleva pasajeros", ("conduccion",)),
	("un fps de zombis con escopetas", ("zombis",)),
	("un juego de zombis en primera persona", ("zombis",)),
	("un shooter 3d contra muertos vivientes", ("zombis",)),
	("un partido de baloncesto en la calle", ("baloncesto",)),
	("streetball 3 contra 3", ("baloncesto",)),
	("un juego de tenis con raqueta", ("tenis",)),
	("partidos de padel en la playa", ("tenis",)),
	("carreras de karts con derrapes", ("karts",)),
	("un juego de carreras 3d en circuito", ("karts",)),
	("carreras de coches en el desierto", ("carreras",)),
	("supermarket simulator en la playa", ("tienda",)),
	("un mundo de cubos 3d para construir castillos", ("cubos",)),
	("un terraria de cuevas y monstruos", ("mundo",)),
	("brawl de magos todos contra todos online", ("arena",)),
	("construir mi aldea y atacar otras como clash", ("aldea",)),
	("asaltar bases enemigas con mi ejercito de vikingos", ("aldea",)),
	("un juego de ritmo tocando tambores al compas", ("ritmo",)),
	("guitar hero de canciones pop", ("ritmo",)),
	("un clicker de galletas", ("clicker",)),
	("idle tycoon de una pizzeria", ("tycoon",)),
	("un solitario de cartas en un barco pirata", ("cartas",)),
	("juego de baraja tranquilo", ("cartas",)),
	("rpg por turnos de caballeros", ("rpg",)),
	("combates por turnos con monstruos como pokemon", ("rpg",)),
	("un laberinto con llaves y puertas", ("laberinto",)),
	("escapar de un laberinto en una piramide", ("laberinto",)),
	("minigolf en la luna", ("golf",)),
	("golf con una bola que rebota en las paredes", ("golf",)),
	("pescar peces en un lago con un oso", ("pesca",)),
	("un pescador que lanza la caña en el mar", ("pesca",)),
	("juntar numeros iguales tipo 2048", ("numeros",)),
	("merge de pociones magicas", ("fusion",)),
	## Ambiguas: dos respuestas razonables.
	("un caballero que salta y lucha contra un dragon", ("plataformas", "rpg")),
	("un juego de coches que esquivan trafico", ("carreras", "corredor")),
	("un pez que salta por plataformas", ("plataformas",)),
	("un juego de memoria con peces", ("memoria",)),
]

## Giros que la idea pide (ademas del genero).
GIROS_CASOS: list[tuple[str, str]] = [
	("un gato ninja que salta por tejados a oscuras con una linterna", "oscuridad"),
	("un laberinto donde tu cola de serpiente te va encerrando", "cola"),
	("un minigolf contra monstruos en un castillo", "monstruos"),
	("un sokoban de regalos a contrarreloj", "contrarreloj"),
	("un mundo espejo donde todo esta al reves, de plataformas", "espejo"),
	("supervivencia tipo last day on earth: saquear casas y aguantar a los zombis", "apocalipsis"),
	("sobrevivir en una isla nevada en pleno invierno con una hoguera", "invierno"),
	("naufrago en una isla que tiene que cazar ciervos y cocinar la carne en la hoguera", "caza"),
	("un rpg por turnos tipo raid shadow legends con un equipo de heroes", "equipo"),
	("un rpg de criaturas por turnos tipo pokemon con un entrenador", "criaturas"),
	("hordas tipo survivor.io con kunais y drones", "survivor"),
	("sobrevivir a hordas tipo vampire survivors con un latigo", "vampiros"),
	("un age of empires galactico con marines en otro planeta", "galactico"),
	("karts de animales tipo mario kart con muchos objetos y estrella", "fiesta"),
	("un idle miner de enanos que excavan pozos de gemas", "mina"),
	("un monopoly go de piratas con dados y tablero", "dados"),
]

NINOS = ["un juego para mi hija de 4 años con animales", "algo para peques de la granja", "juego infantil de colores para niños pequeños"]


def elegir_simulado(idea: str) -> dict:
	return simulado.disenar(idea)


def elegir_simulado_con_giros(idea: str) -> dict:
	return director.disenar(idea, True, None)[0]


def elegir_real(idea: str, gasto: llm.Gasto) -> dict:
	return director.disenar(idea, False, gasto)[0]


def main() -> int:
	real = "--real" in sys.argv
	gasto = llm.Gasto()
	aciertos = 0
	fallos: list[str] = []
	for idea, buenos in CASOS:
		d = elegir_real(idea, gasto) if real else elegir_simulado(idea)
		if d["genero"] in buenos:
			aciertos += 1
		else:
			fallos.append(f"{idea!r}: {d['genero']} (esperado {' o '.join(buenos)})")
	giros_ok = 0
	for idea, giro in GIROS_CASOS:
		d = elegir_real(idea, gasto) if real else elegir_simulado_con_giros(idea)
		if giro in (d.get("giros") or []):
			giros_ok += 1
		else:
			fallos.append(f"{idea!r}: giros {d.get('giros')} (esperado {giro})")
	ninos = 0
	for idea in NINOS:
		d = elegir_real(idea, gasto) if real else elegir_simulado(idea)
		ninos += d.get("publico") == "infantil" or d.get("dificultad") == "facil"
	print(f"Directora {'real' if real else 'simulada'}: genero acertado {aciertos}/{len(CASOS)} ({aciertos / len(CASOS):.0%}); "
		f"giros pedidos {giros_ok}/{len(GIROS_CASOS)}; ideas para ninos tratadas como tales {ninos}/{len(NINOS)}" + (f"; coste {gasto.usd:.3f} USD" if real else ""))
	for f in fallos:
		print("  FALLO", f)
	## La simulada es la red de seguridad sin IA: tiene que acertar al menos el 90 %.
	minimo = 0.9 if not real else 0.95
	return 0 if aciertos / len(CASOS) >= minimo else 1


if __name__ == "__main__":
	sys.exit(main())
