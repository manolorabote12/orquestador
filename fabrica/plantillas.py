"""Plantillas de exito: juegos de ejemplo ya probados que el usuario personaliza en un minuto.

Cada plantilla fija lo que hace que funcione (genero, dificultad, sensacion, estilo, publico, giros
y lo que lleva el juego) y deja libre el tema: «{tema}» se cambia por lo que escriba el usuario.
La app manda la idea con una marca al principio: «[plantilla:id] idea...». El servidor comprueba
que el id existe (lista sincronizada en cambios-datos.ts) y la fabrica (director.disenar) la lee,
se la pasa a la directora como obligatoria y la vuelve a fijar en el diseno.

Las plantillas se fabrican enteras en la prueba (pruebas/prueba_plantillas.py): todas superan
la cadena con sus bots.
"""

import re

PLANTILLAS: dict[str, dict] = {
	"gato_tejados": {
		"categoria": "accion", "nombre": "Saltos por los tejados", "genero": "plataformas", "dificultad": "normal", "sensacion": "agil", "familia": "pixel_art",
		"idea": "Un {tema} ninja que salta por los tejados de noche esquivando guardias y recogiendo monedas",
		"tema": "gato", "por_que": "Las plataformas con un héroe con carisma son lo más jugado en móviles: fácil de entender, difícil de dominar.",
	},
	"huida_volcan": {
		"categoria": "accion", "nombre": "Huida sin fin", "genero": "runner", "dificultad": "normal", "sensacion": "agil", "familia": "cartoon",
		"idea": "Un {tema} que huye corriendo sin parar por un volcán que se derrumba (runner)",
		"tema": "zorro", "por_que": "Partidas de 1 minuto con un solo toque: perfectas para el bus o la cola del súper.",
	},
	"tren_ciudad": {
		"categoria": "accion", "nombre": "Carriles de neón", "genero": "corredor", "dificultad": "normal", "sensacion": "agil", "familia": "low_poly",
		"idea": "Corre por tres carriles esquivando trenes en una ciudad de neón con un {tema} (3D)",
		"tema": "skater", "por_que": "El estilo de los corredores de carriles en 3D: reconocible al instante y muy rejugable.",
	},
	"clanes_vikingos": {
		"categoria": "estrategia", "nombre": "Asalto de clanes", "genero": "aldea", "dificultad": "normal", "sensacion": "normal", "familia": "cartoon",
		"idea": "Asalta las aldeas de los clanes rivales con tu ejército de {tema} vikingos",
		"tema": "gatos", "por_que": "Construir tu aldea y asaltar las de otros engancha durante meses (liga, clanes y guerra semanal incluidos).",
	},
	"guerras_tribales": {
		"categoria": "estrategia", "nombre": "Guerras tribales", "genero": "imperio", "dificultad": "normal", "sensacion": "normal", "familia": "cartoon",
		"idea": "Levanta tu tribu de {tema}: aldeanos que recogen recursos, casas, cuarteles y un ejército para conquistar las tribus rivales en tiempo real",
		"tema": "bárbaros", "por_que": "La estrategia de construir y conquistar engancha durante horas: cada partida es distinta según cómo repartas a tu gente.",
	},
	"imperio_medieval": {
		"categoria": "estrategia", "nombre": "Imperio medieval", "genero": "imperio", "dificultad": "dificil", "sensacion": "normal", "familia": "cartoon",
		"idea": "Haz crecer un reino medieval de {tema}: tres edades, torres, arqueros, caballería y arietes para derribar el castillo enemigo",
		"tema": "caballeros", "por_que": "El estilo de los grandes juegos de imperios en el móvil: economía, edades y batallas de piedra, papel o tijera.",
	},
	"reinos_desierto": {
		"categoria": "estrategia", "nombre": "Reinos del desierto", "genero": "imperio", "dificultad": "normal", "sensacion": "normal", "familia": "cartoon",
		"idea": "Construye un imperio de {tema} entre dunas y oasis: minas de oro, jinetes y arietes contra el faraón rival",
		"tema": "nómadas", "por_que": "Un tema exótico con mucha personalidad hace que tu juego de estrategia destaque en la tienda.",
	},
	"primer_imperio": {
		"categoria": "estrategia", "nombre": "Mi primer imperio", "genero": "imperio", "dificultad": "facil", "sensacion": "normal", "familia": "cartoon",
		"idea": "Un imperio tranquilo de {tema} para aprender a jugar a estrategia: el rival ataca poco y cada nivel enseña algo nuevo",
		"tema": "ositos", "por_que": "Mucha gente quiere jugar a estrategia pero se agobia: empezar suave hace que se queden.",
	},
	"magnate_minero": {
		"categoria": "relax", "nombre": "Magnate minero", "genero": "minas", "dificultad": "normal", "sensacion": "normal", "familia": "cartoon",
		"idea": "Un idle de minas donde {tema} excavan pozos cada vez más hondos, suben el mineral en ascensor y lo venden: mejoras y gerentes",
		"tema": "enanos", "por_que": "Los idle de minas están entre los más jugados: siempre hay una mejora a la vista y el dinero sube aunque no juegues.",
	},
	"mina_golosinas": {
		"categoria": "ninos", "nombre": "Mina de golosinas", "genero": "minas", "dificultad": "facil", "sensacion": "normal", "familia": "cartoon",
		"publico": "infantil",
		"idea": "Una mina mágica de {tema} donde unos topitos excavan caramelos de colores y los venden en la tienda de arriba",
		"tema": "chuches", "por_que": "Ver crecer tu mina sin presión engancha a los peques: tocar, mejorar y celebrar cada pozo nuevo.",
	},
	"cripta_arquera": {
		"categoria": "accion", "nombre": "Cripta de monstruos", "genero": "mazmorras", "dificultad": "normal", "sensacion": "agil", "familia": "pixel_art",
		"idea": "Un {tema} arquero limpia criptas sala a sala: dispara al pararse, esquiva al moverse, sube de nivel, elige habilidades y abre cofres con equipo",
		"tema": "elfo", "por_que": "El estilo Archero arrasa en móviles: se juega con un dedo, cada partida es distinta y el botín engancha.",
	},
	"mazmorra_dragon": {
		"categoria": "accion", "nombre": "La guarida del dragón", "genero": "mazmorras", "dificultad": "dificil", "sensacion": "agil", "familia": "cartoon",
		"idea": "Baja por la mazmorra de un dragón con tu {tema}: golems, arqueros goblin, salas de tesoro con armas legendarias y el dragón al final",
		"tema": "caballera", "por_que": "Un jefe final temible y equipo legendario: la promesa perfecta para un RPG de acción.",
	},
	"granja_cozy": {
		"categoria": "relax", "nombre": "Granja cozy", "genero": "granja", "dificultad": "facil", "sensacion": "normal", "familia": "cartoon",
		"idea": "Una granja cozy de {tema}: siembra, cosecha, cuida gallinas y vacas, hornea pan y tartas y cumple los pedidos del pueblo",
		"tema": "conejitos", "por_que": "Los juegos de granja relajantes tipo Hay Day enganchan a millones: siempre hay algo creciendo y un pedido que cumplir.",
	},
	"granja_valle": {
		"categoria": "relax", "nombre": "El valle de las cosechas", "genero": "granja", "dificultad": "normal", "sensacion": "normal", "familia": "pixel_art",
		"idea": "Hereda una granja en un valle de {tema} y hazla prosperar: cultivos de temporada, animales, quesería, telar y pedidos cada vez más grandes",
		"tema": "montaña", "por_que": "El estilo Stardew en píxel con cadenas de producción: profundo pero tranquilo.",
	},
	"torre_cartas": {
		"categoria": "estrategia", "nombre": "La torre de cartas", "genero": "mazo", "dificultad": "normal", "sensacion": "normal", "familia": "cartoon",
		"idea": "Un {tema} sube una torre combatiendo con un mazo de cartas: ataques, escudos, venenos y poderes; cada victoria da una carta nueva",
		"tema": "mago", "por_que": "Los deckbuilders tipo Slay the Spire son de los juegos de estrategia más rejugables: cada partida, un mazo distinto.",
	},
	"cartas_piratas": {
		"categoria": "estrategia", "nombre": "Duelos de piratas", "genero": "mazo", "dificultad": "dificil", "sensacion": "normal", "familia": "pixel_art",
		"idea": "Duelos de cartas entre {tema} en alta mar: lee lo que va a hacer el rival, bloquea a tiempo y acaba con el capitán dragón",
		"tema": "piratas", "por_que": "Leer las intenciones del rival y planear el turno perfecto da una satisfacción enorme.",
	},
	"isla_misteriosa": {
		"categoria": "unicas", "nombre": "La isla misteriosa", "genero": "aventura", "dificultad": "normal", "sensacion": "normal", "familia": "cartoon",
		"idea": "Una historia con decisiones: una {tema} naufraga en una isla llena de secretos; cada capítulo, decisiones que cambian quién te ayuda y cómo termina",
		"tema": "exploradora", "por_que": "Los juegos de historias con decisiones (tipo Choices o Episode) enganchan por saber qué pasa si eliges distinto.",
	},
	"detective_pueblo": {
		"categoria": "unicas", "nombre": "Detective del pueblo", "genero": "aventura", "dificultad": "normal", "sensacion": "normal", "familia": "pixel_art",
		"idea": "Una novela visual de misterio: un {tema} detective resuelve casos en su pueblo hablando con vecinos, buscando pistas y eligiendo a quién creer",
		"tema": "gato", "por_que": "El misterio por capítulos con pistas y varios finales hace que la gente vuelva para descubrirlo todo.",
	},
	"food_truck": {
		"categoria": "relax", "nombre": "Mi food truck", "genero": "cocina", "dificultad": "facil", "sensacion": "normal", "familia": "cartoon",
		"idea": "Un {tema} abre su food truck: hamburguesas a la plancha, patatas y refrescos para una cola de clientes con prisa; cada día, más platos en el menú",
		"tema": "mapache", "por_que": "Los juegos de cocina tipo Cooking Fever enganchan con partidas cortas: cocinar, montar y servir a tiempo.",
	},
	"hamburgueseria_frenetica": {
		"categoria": "accion", "nombre": "Hamburguesería frenética", "genero": "cocina", "dificultad": "dificil", "sensacion": "agil", "familia": "pixel_art",
		"idea": "Una hamburguesería de {tema} en hora punta: la carne se quema si te despistas y los clientes se van si tardas; consigue la meta del día",
		"tema": "robots", "por_que": "La presión de gestionar el tiempo con muchos pedidos a la vez es pura adrenalina en el móvil.",
	},
	"mahjong_zen": {
		"categoria": "relax", "nombre": "Mahjong zen", "genero": "mahjong", "dificultad": "facil", "sensacion": "normal", "familia": "cartoon",
		"idea": "Un mahjong solitario relajante en un {tema}: quita parejas de fichas libres hasta vaciar torres y pirámides, sin prisa",
		"tema": "jardín japonés con cerezos", "por_que": "El mahjong solitario es de los juegos de relax más jugados: partidas tranquilas y siempre con solución.",
	},
	"mahjong_templo": {
		"categoria": "puzle", "nombre": "El templo de las fichas", "genero": "mahjong", "dificultad": "dificil", "sensacion": "normal", "familia": "pixel_art",
		"idea": "Mahjong de aventura: cada nivel, un tablero más alto en las salas de un {tema}; mira bien qué fichas destapan a las demás",
		"tema": "templo perdido en la selva", "por_que": "Planear qué pareja quitar primero para no quedarse atascado es un reto de lógica que engancha.",
	},
	"atasco_ciudad": {
		"categoria": "puzle", "nombre": "Atasco en la ciudad", "genero": "aparcamiento", "dificultad": "normal", "sensacion": "normal", "familia": "cartoon",
		"idea": "Un puzle de aparcamiento tipo Parking Jam en una {tema}: cada coche solo va hacia delante; sácalos en el orden justo sin chocar",
		"tema": "ciudad llena de taxis", "por_que": "Los puzles de atascos son rapidísimos de entender y piden pensar el orden antes de tocar.",
	},
	"parking_mascotas": {
		"categoria": "ninos", "publico": "infantil", "nombre": "El parking de las mascotas", "genero": "aparcamiento", "dificultad": "facil", "sensacion": "normal", "familia": "cartoon",
		"idea": "Coches de colores conducidos por {tema} que quieren salir del aparcamiento: toca cada uno cuando tenga el camino libre",
		"tema": "perritos y gatitos", "por_que": "Pocas piezas, colores vivos y una regla clara: ideal para peques.",
	},
	"sopa_animales": {
		"categoria": "relax", "nombre": "Sopa de letras salvaje", "genero": "sopa", "dificultad": "facil", "sensacion": "normal", "familia": "cartoon",
		"idea": "Una sopa de letras de {tema}: encuentra las palabras escondidas en horizontal, vertical y diagonal",
		"tema": "animales de la selva", "por_que": "Las sopas de letras se juegan a diario: relajan y se entienden en cualquier idioma.",
	},
	"sopa_espacial": {
		"categoria": "puzle", "nombre": "Palabras en órbita", "genero": "sopa", "dificultad": "dificil", "sensacion": "normal", "familia": "pixel_art",
		"idea": "Sopa de letras del {tema}: planetas, cometas y galaxias escondidas, también al revés",
		"tema": "espacio", "por_que": "Con palabras al revés y en diagonal, cada nivel es un reto de vista y paciencia.",
	},
	"pedidos_puerto": {
		"categoria": "relax", "nombre": "Café del puerto", "genero": "pedidos", "dificultad": "facil", "sensacion": "normal", "familia": "cartoon",
		"idea": "Un juego de fusionar con pedidos en {tema}: junta objetos iguales y atiende a los clientes",
		"tema": "un café junto al mar", "por_que": "Tipo Gossip Harbor, de los que más facturan: relaja y siempre hay un pedido más.",
	},
	"poder_caballeros": {
		"categoria": "puzle", "nombre": "Torres del rey", "genero": "poder", "dificultad": "normal", "sensacion": "normal", "familia": "cartoon",
		"idea": "Una torre de poder de {tema}: vence primero a los más débiles para crecer y derrota al jefe",
		"tema": "caballeros contra monstruos", "por_que": "El anuncio de Hero Wars convertido en juego: un número, una decisión y enganche total.",
	},
	"diferencias_mar": {
		"categoria": "puzle", "nombre": "Ojo de lince", "genero": "diferencias", "dificultad": "facil", "sensacion": "normal", "familia": "cartoon",
		"idea": "Un encuentra las diferencias de {tema}: dos dibujos casi iguales y pocas oportunidades de fallar",
		"tema": "parques, mares y ciudades", "por_que": "Un clásico para todas las edades: partidas cortas, relajantes y perfectas para anuncios entre nivel y nivel.",
	},
	"rompecabezas_paisajes": {
		"categoria": "puzle", "nombre": "Pieza a pieza", "genero": "rompecabezas", "dificultad": "facil", "sensacion": "normal", "familia": "cartoon",
		"idea": "Un rompecabezas de {tema}: el héroe del juego en cada dibujo y piezas que se cambian de sitio",
		"tema": "paisajes y aventuras", "por_que": "Relajante y sin prisa: perfecto para jugar un rato y para anuncios con recompensa (pistas).",
	},
	"pintar_pixeles": {
		"categoria": "puzle", "nombre": "Cuadritos de colores", "genero": "pintar", "dificultad": "facil", "sensacion": "normal", "familia": "pixel_art",
		"idea": "Un pintar por números de {tema}: dibujos de cuadritos y, de vez en cuando, el héroe del juego para colorear",
		"tema": "animales, comida y aventuras", "por_que": "De lo más descargado para relajarse: sin perder nunca, ideal para anuncios con recompensa (cubos).",
	},
	"cuchillos_ninja": {
		"categoria": "accion", "nombre": "Filo giratorio", "genero": "cuchillos", "dificultad": "normal", "sensacion": "agil", "familia": "cartoon",
		"idea": "Un lanza cuchillos de {tema}: troncos que giran, frenan y cambian de sentido, y jefes cada cinco niveles",
		"tema": "ninjas en el bosque", "por_que": "Un toque, partidas de segundos y el «una más»: el clásico de Ketchapp que engancha.",
	},
	"arquero_templo": {
		"categoria": "accion", "nombre": "Flechas del templo", "genero": "arquero", "dificultad": "normal", "sensacion": "agil", "familia": "cartoon",
		"idea": "Un archero de {tema}: salas llenas de enemigos, dispara al pararte y elige una habilidad nueva en cada sala",
		"tema": "un templo encantado", "por_que": "El bucle de Archero: partidas de minutos, una decisión cada sala y ganas de otra vuelta.",
	},
	"flechas_colores": {
		"categoria": "puzle", "nombre": "Salida libre", "genero": "flechas", "dificultad": "normal", "sensacion": "normal", "familia": "cartoon",
		"idea": "Un puzle de flechas que salen de {tema}: toca cada flecha en el orden justo para vaciar el tablero sin chocar",
		"tema": "un tablero de colores", "por_que": "Uno de los puzles más jugados de 2025: se entiende en un segundo y engancha nivel tras nivel.",
	},
	"numeros_2048": {
		"categoria": "puzle", "nombre": "Doble o nada", "genero": "numeros", "dificultad": "normal", "sensacion": "normal", "familia": "cartoon",
		"idea": "Un 2048 de {tema}: desliza, junta fichas iguales y llega a la ficha objetivo de cada nivel",
		"tema": "fichas de colores", "por_que": "El clásico que nunca pasa de moda, con niveles cortos, rocas y deshacer (ideal para anuncios con recompensa).",
	},
	"cartas_locas_familia": {
		"categoria": "estrategia", "nombre": "Ocho locos", "genero": "cartas_locas", "dificultad": "normal", "sensacion": "normal", "familia": "cartoon",
		"idea": "Un juego de cartas locas de {tema}: mismo color o mismo número, +2, saltos, reversas y comodines contra 1 a 3 rivales",
		"tema": "animales del bosque", "por_que": "El juego de cartas de toda la vida en el móvil: partidas de 3 minutos, todo el mundo sabe jugar.",
	},
	"domino_bar": {
		"categoria": "estrategia", "nombre": "La partida del barrio", "genero": "domino", "dificultad": "normal", "sensacion": "normal", "familia": "cartoon",
		"idea": "Un dominó de {tema}: encaja fichas en las puntas, roba del pozo y quédate sin fichas antes que los rivales",
		"tema": "un bar de playa", "por_que": "El clásico de mesa de siempre: lo conoce todo el mundo y se juega en 3 minutos.",
	},
	"bloques_colores_jam": {
		"categoria": "puzle", "nombre": "Atasco de colores", "genero": "bloques_colores", "dificultad": "normal", "sensacion": "normal", "familia": "cartoon",
		"idea": "Un juego de sacar bloques de colores por su puerta en {tema}: arrastra cada bloque por los huecos hasta la puerta de su color",
		"tema": "una juguetería", "por_que": "El puzle de moda (tipo Color Block Jam): se entiende al momento y cada nivel pide pensar el orden.",
	},
	"tuberias_fontanero": {
		"categoria": "relax", "nombre": "Agua para todos", "genero": "tuberias", "dificultad": "facil", "sensacion": "normal", "familia": "cartoon",
		"idea": "Un juego de girar tuberías en {tema}: toca cada pieza hasta que el agua del grifo llegue a todas sin fugas",
		"tema": "un jardín sediento", "por_que": "Relajante y con solución siempre: perfecto para partidas cortas y anuncios con recompensa.",
	},
	"ajedrez_escuela": {
		"categoria": "estrategia", "nombre": "Escuela de ajedrez", "genero": "ajedrez", "dificultad": "facil", "sensacion": "normal", "familia": "cartoon",
		"idea": "Un juego de ajedrez en {tema}: empiezas con ventaja (al rival le faltan piezas) y cada nivel la quita hasta la partida de verdad",
		"tema": "un parque con tableros gigantes", "por_que": "El clásico de siempre con una escalera de dificultad: engancha a quien aprende y a quien ya sabe.",
	},
	"reversi_jardin": {
		"categoria": "estrategia", "nombre": "Reversi del jardín", "genero": "reversi", "dificultad": "facil", "sensacion": "normal", "familia": "cartoon",
		"idea": "Un juego de reversi en {tema}: encierra las fichas del rival para darles la vuelta; primero en un tablero pequeño y luego en el grande",
		"tema": "un jardín japonés de piedras blancas y negras", "por_que": "Se aprende en un minuto y engancha años: partidas cortas perfectas para el móvil.",
	},
	"buscar_desvan": {
		"categoria": "relax", "nombre": "El desván de la abuela", "genero": "buscar", "dificultad": "facil", "sensacion": "normal", "familia": "cartoon",
		"idea": "Un juego de buscar objetos en {tema}: cada nivel una escena llena de cosas y una lista de lo que hay que encontrar",
		"tema": "un desván lleno de recuerdos", "por_que": "Uno de los géneros favoritos de quien juega en el sofá: tranquilo, visual y muy de anuncios con premio (pistas).",
	},
	"deslizar_museo": {
		"categoria": "puzle", "nombre": "El cuadro revuelto", "genero": "deslizar", "dificultad": "normal", "sensacion": "normal", "familia": "cartoon",
		"idea": "Un puzle de deslizar en {tema}: el cuadro con el héroe en medio está revuelto y hay que deslizar las piezas hasta recomponerlo",
		"tema": "un museo de cuadros mágicos", "por_que": "El clásico de 15 con el arte del propio juego: cada nivel es un dibujo nuevo y un tablero más grande.",
	},
	"ahorcado_globos": {
		"categoria": "ninos", "nombre": "Globos de letras", "genero": "ahorcado", "dificultad": "facil", "sensacion": "normal", "familia": "cartoon",
		"idea": "Un juego del ahorcado en {tema}: el héroe cuelga de un ramo de globos y cada letra que no está revienta uno",
		"tema": "una feria con globos de colores", "por_que": "El ahorcado de siempre sin nada triste: aprender palabras jugando, en el idioma de cada niño.",
	},
	"flota_piratas": {
		"categoria": "estrategia", "nombre": "Flota pirata", "genero": "flota", "dificultad": "normal", "sensacion": "normal", "familia": "cartoon",
		"idea": "Un juego de hundir la flota en {tema}: por turnos contra la máquina, encuentra y hunde sus barcos antes de que hunda los tuyos",
		"tema": "un mar de islas piratas", "por_que": "El clásico de papel y lápiz en el móvil: partidas de cinco minutos y un rival que aprende a cazar.",
	},
	"simon_orquesta": {
		"categoria": "ninos", "nombre": "La orquesta de colores", "genero": "simon", "dificultad": "facil", "sensacion": "normal", "familia": "cartoon",
		"idea": "Un juego de Simón dice en {tema}: los instrumentos se encienden en orden y hay que repetirlos, cada ronda uno más",
		"tema": "un escenario de músicos de colores", "por_que": "Memoria y oído en partidas de un minuto: engancha a niños y mayores.",
	},
	"estrategia_juguetes": {
		"categoria": "estrategia", "nombre": "La guerra de los juguetes", "genero": "estrategia", "dificultad": "normal", "sensacion": "normal", "familia": "cartoon",
		"idea": "Un juego de estrategia por turnos en {tema}: soldados, tanques y cañones de juguete; mueve tus tropas, captura ciudades y conquista el cuartel rival",
		"tema": "un cuarto de juegos gigante", "por_que": "Estrategia de verdad en partidas cortas: cada nivel un mapa y un rival que piensa.",
	},
	"autobatalla_bestias": {
		"categoria": "estrategia", "nombre": "Liga de bestias", "genero": "autobatalla", "dificultad": "normal", "sensacion": "normal", "familia": "cartoon",
		"idea": "Un juego de batalla automática en {tema}: compra criaturas, junta tres iguales para hacerlas más fuertes y colócalas antes de cada combate",
		"tema": "un torneo de bestias mágicas", "por_que": "El género de Teamfight Tactics: decisiones rápidas, combates que se miran solos y muchísima rejugabilidad.",
	},
	"gemas_guardianes": {
		"categoria": "estrategia", "nombre": "Guardianes de las gemas", "genero": "gemas", "dificultad": "normal", "sensacion": "normal", "familia": "cartoon",
		"idea": "Un juego de gemas y héroes en {tema}: combina gemas de colores para que tus héroes ataquen a oleadas de monstruos",
		"tema": "un reino de cristal", "por_que": "El puzle con combates de Empires & Puzzles: sencillo de tocar y con estrategia de colores y especiales.",
	},
	"coleccionables_academia": {
		"categoria": "estrategia", "nombre": "Duelo en la academia", "genero": "coleccionables", "dificultad": "normal", "sensacion": "normal", "familia": "cartoon",
		"idea": "Un juego de cartas coleccionables en {tema}: duelos por turnos con esbirros, hechizos y maná contra rivales cada vez más listos",
		"tema": "una academia de magia", "por_que": "El duelo de cartas de Hearthstone en partidas de diez minutos: estrategia pura y mucha rejugabilidad.",
	},
	"roguelike_cripta": {
		"categoria": "accion", "nombre": "La cripta sin fondo", "genero": "roguelike", "dificultad": "normal", "sensacion": "normal", "familia": "pixel_art",
		"idea": "Un roguelike por turnos en {tema}: baja planta a planta con niebla, monstruos que despiertan, espadas, armaduras y un jefe que guarda la escalera",
		"tema": "una cripta embrujada", "por_que": "El enganche de Pixel Dungeon: cada paso cuenta, cada planta es nueva y siempre quieres bajar una mas.",
	},
	"bombas_fabrica": {
		"categoria": "accion", "nombre": "Bombas en la fábrica", "genero": "bombas", "dificultad": "normal", "sensacion": "normal", "familia": "cartoon",
		"idea": "Un juego de bombas tipo Bomberman en {tema}: rompe cajas, encuentra más bombas y más alcance, atrapa a los monstruos en las llamas y escapa por la salida escondida",
		"tema": "una fábrica de juguetes", "por_que": "El clásico de las recreativas: reglas que se entienden en un segundo y partidas de dos minutos en las que siempre quieres una más.",
	},
	"artilleria_patos": {
		"categoria": "estrategia", "nombre": "Patos con bazuca", "genero": "artilleria", "dificultad": "normal", "sensacion": "normal", "familia": "cartoon",
		"idea": "Una batalla de artillería por turnos tipo Worms en {tema}: apunta con el dedo, calcula el viento, abre cráteres en el terreno y tira al rival al agua",
		"tema": "una isla de patos piratas", "por_que": "El caos divertido de Worms: cada disparo es una apuesta, el terreno cambia y las partidas acaban siempre con risas.",
	},
	"comecocos_dulces": {
		"categoria": "accion", "nombre": "Ladrón de caramelos", "genero": "comecocos", "dificultad": "normal", "sensacion": "normal", "familia": "cartoon",
		"idea": "Un comecocos en {tema}: cómete todos los caramelos del laberinto, esquiva a los guardianes y usa los caramelos gigantes para perseguirlos tú",
		"tema": "una fábrica de caramelos", "por_que": "El clásico que todo el mundo entiende en un segundo: tensión constante y la venganza de las píldoras.",
	},
	"cadena_templo": {
		"categoria": "puzle", "nombre": "El templo de las bolas", "genero": "cadena", "dificultad": "normal", "sensacion": "normal", "familia": "cartoon",
		"idea": "Una cadena de bolas tipo Zuma en {tema}: dispara bolas de colores, junta tres iguales y encadena combos antes de que la fila llegue al agujero",
		"tema": "un templo perdido en la selva", "por_que": "La tensión de Zuma: la cadena no para, cada disparo cuenta y los combos en cadena son pura satisfacción.",
	},
	"lucha_torneo": {
		"categoria": "accion", "nombre": "Torneo de los puños", "genero": "lucha", "dificultad": "normal", "sensacion": "normal", "familia": "cartoon",
		"idea": "Un juego de lucha uno contra uno tipo Street Fighter en {tema}: puños, patadas, cubrirse en el momento justo y un especial que se carga golpeando, contra rivales con su estilo",
		"tema": "un torneo de artes marciales en la azotea", "por_que": "La emoción de las recreativas de lucha: aprender a cubrirte y castigar al rival, combates cortos y siempre la revancha.",
	},
	"sandia_huerto": {
		"categoria": "puzle", "nombre": "El tarro del huerto", "genero": "sandia", "dificultad": "normal", "sensacion": "normal", "familia": "cartoon",
		"idea": "Un juego de fusionar frutas tipo sandía en {tema}: suelta frutas en el tarro, junta dos iguales para crear otra más grande y llega a la fruta objetivo sin que rebose",
		"tema": "un huerto de frutas con caras", "por_que": "El enganche del juego de la sandía: física que se entiende sola, cadenas de fusiones y siempre una partida más.",
	},
	"pinball_neon": {
		"categoria": "accion", "nombre": "Neón y palas", "genero": "pinball", "dificultad": "normal", "sensacion": "agil", "familia": "cartoon",
		"idea": "Un pinball en {tema}: mantén viva la bola con las dos palas, enciende setas, tumba dianas y multiplica la puntuación",
		"tema": "una sala de recreativas de neón", "por_que": "La adrenalina de las máquinas de pinball: reflejos, rebotes imposibles y la tensión de cada bola.",
	},
	"metroidvania_ruinas": {
		"categoria": "unicas", "nombre": "Las ruinas ocultas", "genero": "metroidvania", "dificultad": "normal", "sensacion": "normal", "familia": "pixel_art",
		"idea": "Un metroidvania en {tema}: explora salas conectadas, consigue el doble salto, el impulso y el martillo, y vuelve a las puertas que antes no podías cruzar",
		"tema": "unas ruinas bajo la montaña", "por_que": "La magia de Hollow Knight y Metroid: cada habilidad nueva convierte un muro en un camino y el mapa se abre poco a poco.",
	},
	"sigilo_museo": {
		"categoria": "puzle", "nombre": "Golpe en el museo", "genero": "sigilo", "dificultad": "normal", "sensacion": "normal", "familia": "cartoon",
		"idea": "Un juego de sigilo por turnos tipo Hitman GO en {tema}: muévete por los caminos, esquiva la mirada de los guardias, déjalos fuera por la espalda y escapa con el maletín",
		"tema": "un museo de noche", "por_que": "La elegancia de Hitman GO: cada tablero es un puzle de lógica pura y siempre hay una forma más limpia de resolverlo.",
	},
	"multitud_vikingos": {
		"categoria": "accion", "nombre": "Horda vikinga", "genero": "multitud", "dificultad": "normal", "sensacion": "normal", "familia": "cartoon",
		"idea": "Un count masters de {tema}: pasa por las puertas que multiplican tu grupo y llega al jefe con más gente",
		"tema": "vikingos contra trolls", "por_que": "El famoso anuncio de Last War convertido en juego: se entiende en un segundo y engancha.",
	},
	"reino_helado": {
		"categoria": "estrategia", "nombre": "Reino helado", "genero": "reino", "dificultad": "normal", "sensacion": "normal", "familia": "cartoon",
		"idea": "Un reino tipo Kingshot en {tema}: sube tu ciudad, entrena tropas que no paran de crecer y conquista campamentos",
		"tema": "una tierra helada con yetis", "por_que": "Kingshot y Whiteout Survival están entre los que más facturan del mundo: tu ejército crece en tiempo real.",
	},
	"tragaperras_piratas": {
		"categoria": "unicas", "nombre": "Isla del tesoro", "genero": "tragaperras", "dificultad": "normal", "sensacion": "normal", "familia": "cartoon",
		"idea": "Un coin master de {tema}: tira en la tragaperras, gana doblones de mentira y construye tu isla",
		"tema": "piratas", "por_que": "Tipo Coin Master, de los que más facturan: cada tirada puede ser un premio y siempre hay algo que construir.",
	},
	"tycoon_dulces": {
		"categoria": "estrategia", "nombre": "Imperio dulce", "genero": "tycoon", "dificultad": "normal", "sensacion": "normal", "familia": "cartoon",
		"idea": "Un idle tycoon de {tema}: compra negocios, contrata gerentes y hazte rico mientras trabajan solos",
		"tema": "pastelerías y heladerías", "por_que": "Los tycoon idle enganchan durante meses: siempre hay algo que comprar y ganas hasta con el móvil apagado.",
	},
	"tycoon_mina": {
		"categoria": "estrategia", "nombre": "Mina de oro", "genero": "tycoon", "dificultad": "normal", "sensacion": "normal", "familia": "pixel_art",
		"idea": "Un idle miner de {tema}: pozos, ascensor y almacén que mejorar para que nada frene la producción",
		"tema": "enanos excavando gemas", "por_que": "Tipo Idle Miner Tycoon, de los más descargados: buscar el cuello de botella es muy adictivo.",
		"giros": ["mina"],
	},
	"palabra_diaria": {
		"categoria": "relax", "nombre": "La palabra de hoy", "genero": "palabra", "dificultad": "normal", "sensacion": "normal", "familia": "cartoon",
		"idea": "Adivina la palabra de {tema} en seis intentos: cada letra te dice si está y si está en su sitio",
		"tema": "cada día", "por_que": "El juego de palabras más compartido del mundo: un ratito al día y vuelves mañana.",
	},
	"letras_viaje": {
		"categoria": "puzle", "nombre": "Palabras viajeras", "genero": "letras", "dificultad": "normal", "sensacion": "normal", "familia": "pintado",
		"idea": "Une las letras de la rueda para formar palabras y completar crucigramas mientras viajas por {tema}",
		"tema": "las ciudades del mundo", "por_que": "Los juegos de rueda de letras están siempre arriba en Play: relajan y enganchan nivel a nivel.",
	},
	"sudoku_clasico": {
		"categoria": "puzle", "nombre": "Sudoku zen", "genero": "sudoku", "dificultad": "normal", "sensacion": "normal", "familia": "cartoon",
		"idea": "Sudokus que crecen de 4x4 a 9x9 con un ambiente de {tema}: pistas, vidas y solución única siempre",
		"tema": "café tranquilo con lluvia", "por_que": "El sudoku es de los puzles más jugados del mundo: partidas cortas para entrenar la mente.",
	},
	"sudoku_peques": {
		"categoria": "ninos", "publico": "infantil", "nombre": "Mini sudoku", "genero": "sudoku", "dificultad": "facil", "sensacion": "normal", "familia": "cartoon",
		"idea": "Sudokus pequeños de 4x4 y 6x6 con {tema} para aprender a pensar con números",
		"tema": "animalitos del bosque", "por_que": "Tableros pequeños y colores alegres: lógica para peques sin agobios.",
	},
	"pixel_secreto": {
		"categoria": "puzle", "nombre": "Pixel secreto", "genero": "nonograma", "dificultad": "normal", "sensacion": "normal", "familia": "pixel_art",
		"idea": "Nonogramas tipo Picross: pinta las casillas que dicen las pistas y descubre dibujos de {tema}",
		"tema": "un museo de pixel art", "por_que": "Cada puzle termina con un dibujo: la recompensa perfecta para un juego de lógica.",
	},
	"fruta_ninja": {
		"categoria": "accion", "nombre": "Ninja de la fruta", "genero": "cortar", "dificultad": "normal", "sensacion": "agil", "familia": "cartoon",
		"idea": "Un {tema} corta fruta lanzada al aire con su espada: combos, fruta dorada y bombas que hay que esquivar",
		"tema": "ninja panda", "por_que": "Deslizar y cortar es de lo más satisfactorio en una pantalla táctil.",
	},
	"tanda_penaltis": {
		"categoria": "accion", "nombre": "Rey del penalti", "genero": "penaltis", "dificultad": "normal", "sensacion": "normal", "familia": "cartoon",
		"idea": "Tanda de penaltis en un estadio de {tema}: desliza para chutar, lee al portero, supera barreras y acierta en las dianas",
		"tema": "liga de animales", "por_que": "El fútbol es el deporte más jugado en móvil, y un penalti se entiende en un segundo.",
	},
	"penaltis_mundial": {
		"categoria": "unicas", "nombre": "Final del mundial", "genero": "penaltis", "dificultad": "dificil", "sensacion": "normal", "familia": "pixel_art",
		"idea": "Una final por {tema} decidida en los penaltis: porteros cada vez más listos que te engañan",
		"tema": "la copa de las estrellas", "por_que": "Porteros que amagan y barreras: cada tiro es una decisión con tensión.",
	},
	"agujero_ciudad": {
		"categoria": "accion", "nombre": "El agujero glotón", "genero": "agujero", "dificultad": "normal", "sensacion": "agil", "familia": "cartoon",
		"idea": "Un agujero que se traga una {tema}: empieza con conos y gente, sigue con coches y acaba con los edificios",
		"tema": "ciudad de juguete", "por_que": "Los juegos tipo Hole.io enganchan por la sensación de crecer sin parar en partidas de un minuto.",
	},
	"alcalde_isla": {
		"categoria": "estrategia", "nombre": "Alcalde de la isla", "genero": "ciudad", "dificultad": "normal", "sensacion": "normal", "familia": "cartoon",
		"idea": "Construye una {tema}: calles, casas, tiendas, fábricas y parques; haz feliz a la gente para que lleguen más",
		"tema": "ciudad en una isla tropical", "por_que": "Los constructores de ciudades tipo Pocket City dan horas de juego: planificar y ver crecer tu ciudad.",
	},
	"bola_espiral": {
		"categoria": "accion", "nombre": "Bola en espiral", "genero": "espiral", "dificultad": "normal", "sensacion": "agil", "familia": "cartoon",
		"idea": "Una bola que baja por una {tema} en espiral: gira la torre, cae por los huecos y esquiva las zonas rojas",
		"tema": "torre de caramelo", "por_que": "Helix Jump fue de los juegos más descargados: un dedo, una regla y ganas de bajar un piso más.",
	},
	"canasta_callejera": {
		"categoria": "accion", "nombre": "Canasta callejera", "genero": "canasta", "dificultad": "normal", "sensacion": "normal", "familia": "cartoon",
		"idea": "Tiros a canasta en una {tema}: aros que se mueven, triples desde la esquina y viento que desvía el balón",
		"tema": "cancha del barrio", "por_que": "Lanzar deslizando el dedo es muy natural en el móvil y cada tiro es un pequeño reto.",
	},
	"buscaminas_jardin": {
		"categoria": "puzle", "nombre": "Buscaminas del jardín", "genero": "buscaminas", "dificultad": "normal", "sensacion": "normal", "familia": "cartoon",
		"idea": "Un buscaminas en un {tema}: abre casillas con lógica y marca las trampas, sin tener que adivinar nunca",
		"tema": "jardín lleno de topos traviesos", "por_que": "El buscaminas es un clásico; sin casillas al azar, cada derrota es culpa tuya y engancha más.",
	},
	"conecta_duelo": {
		"categoria": "estrategia", "nombre": "Duelo de cuatro", "genero": "conecta", "dificultad": "normal", "sensacion": "normal", "familia": "cartoon",
		"idea": "Conecta 4 contra rivales {tema} cada vez más listos: piensa jugadas, bloquea y haz cuatro en raya",
		"tema": "piratas", "por_que": "Los juegos de mesa contra la máquina son de lo más descargado: partidas cortas y rivales que aprenden.",
	},
	"damas_castillo": {
		"categoria": "estrategia", "nombre": "Damas del castillo", "genero": "damas", "dificultad": "normal", "sensacion": "normal", "familia": "cartoon",
		"idea": "Damas contra los {tema}: primero partidas cortas con pocas fichas y luego el tablero entero contra rivales más listos",
		"tema": "caballeros del rey", "por_que": "Los juegos de mesa clásicos contra la máquina tienen millones de jugadores fieles.",
	},
	"billar_neon": {
		"categoria": "accion", "nombre": "Billar neón", "genero": "billar", "dificultad": "normal", "sensacion": "normal", "familia": "cartoon",
		"idea": "Retos de billar en un {tema}: mete todas las bolas en pocos tiros calculando ángulo y fuerza",
		"tema": "club de billar con luces de neón", "por_que": "El billar en el móvil engancha: cada tiro es física pura y se entiende al momento.",
	},
	"solitario_clasico": {
		"categoria": "relax", "nombre": "Solitario de siempre", "genero": "solitario", "dificultad": "normal", "sensacion": "normal", "familia": "cartoon",
		"idea": "El solitario clásico con cartas de {tema}: repartos que siempre tienen solución y pistas si te atascas",
		"tema": "un tapete verde y elegante", "por_que": "El solitario es de los juegos más jugados del mundo, a cualquier edad.",
	},
	"parchis_familia": {
		"categoria": "relax", "nombre": "Parchís de la familia", "genero": "parchis", "dificultad": "normal", "sensacion": "normal", "familia": "cartoon",
		"idea": "Parchís contra {tema}: tira el dado, come fichas y llega a casa antes que nadie",
		"tema": "los abuelos del pueblo", "por_que": "Ludo y parchís están entre los juegos de mesa más descargados: partidas rápidas y mucha emoción con el dado.",
	},
	"bloques_neon": {
		"categoria": "puzle", "nombre": "Bloques de neón", "genero": "caida", "dificultad": "normal", "sensacion": "agil", "familia": "pixel_art",
		"idea": "El clásico de piezas que caen en un {tema}: gira, encaja y borra filas cada vez más rápido",
		"tema": "salón recreativo de neón", "por_que": "Las piezas que caen son uno de los juegos más jugados de la historia: reglas que todo el mundo conoce.",
	},
	"bolos_bolera": {
		"categoria": "accion", "nombre": "Noche de bolos", "genero": "bolos", "dificultad": "normal", "sensacion": "normal", "familia": "cartoon",
		"idea": "Bolos en una {tema}: desliza con efecto, esquiva el aceite y las barreras y consigue strikes",
		"tema": "bolera retro de los 80", "por_que": "Lanzar deslizando con efecto es muy satisfactorio en una pantalla táctil.",
	},
	"mundo_bloques": {
		"categoria": "accion", "nombre": "Mundo de bloques", "genero": "mundo", "dificultad": "normal", "sensacion": "normal", "familia": "pixel_art",
		"idea": "Un mundo abierto de {tema}: pica bloques, fabrica herramientas, baja a las minas y sobrevive a la noche",
		"tema": "islas flotantes y cuevas de cristal", "por_que": "Explorar, fabricar y construir a tu manera es lo que más horas engancha en móvil.",
	},
	"royale_isla": {
		"categoria": "accion", "nombre": "Isla de los 30", "genero": "royale", "dificultad": "normal", "sensacion": "agil", "familia": "cartoon",
		"idea": "Un battle royale desde arriba en una isla de {tema}: salta del avión, busca armas y sé el último en pie",
		"tema": "pueblos de pescadores y bosques", "por_que": "El género más jugado en móvil: cada partida es distinta y siempre quieres una más.",
	},
	"cruzar_granja": {
		"categoria": "accion", "nombre": "Cruza la granja", "genero": "cruzar", "dificultad": "normal", "sensacion": "agil", "familia": "cartoon",
		"idea": "Un juego de cruzar con {tema}: salta carreteras, ríos con troncos y vías de tren hasta la meta",
		"tema": "un pollito valiente que vuelve a su granja", "por_que": "Un toque para saltar y siempre «uno más»: de los arcade más jugados en móvil.",
	},
	"arco_bosque": {
		"categoria": "accion", "nombre": "Arquera del bosque", "genero": "arco", "dificultad": "normal", "sensacion": "normal", "familia": "pintado",
		"idea": "Tiro con arco en {tema}: dianas que se mueven, viento y globos que dan flechas",
		"tema": "un bosque encantado con luciérnagas", "por_que": "Apuntar y soltar es muy satisfactorio: cada diana perfecta engancha.",
	},
	"cubos_islas": {
		"categoria": "accion", "nombre": "Islas de cubos", "genero": "cubos", "dificultad": "normal", "sensacion": "normal", "familia": "pixel_art",
		"idea": "Un mundo de cubos en 3D de {tema}: pica, construye tu casa y fabrica herramientas hasta la corona",
		"tema": "praderas, montañas y cuevas con cristales", "por_que": "Construir en 3D a tu manera es de lo que más horas engancha: el mundo se guarda entre partidas.",
	},
	"parkour_cielo": {
		"categoria": "accion", "nombre": "Parkour en el cielo", "genero": "parkour", "dificultad": "normal", "sensacion": "agil", "familia": "cartoon",
		"idea": "Un parkour 3D entre {tema}: plataformas que se mueven, barras que giran y lava hasta la meta",
		"tema": "islas de colores sobre las nubes", "por_que": "Los obby de saltos son de lo más jugado por los jóvenes: retos cortos y «uno más».",
	},
	"tienda_barrio": {
		"categoria": "estrategia", "nombre": "Mi súper", "genero": "tienda", "dificultad": "normal", "sensacion": "normal", "familia": "cartoon",
		"idea": "Un simulador de supermercado 3D en {tema}: repone, cobra, contrata ayuda y abre productos nuevos",
		"tema": "un barrio con mucha vida", "por_que": "Los simuladores de tienda tipo «idle arcade» están entre los más descargados: progreso constante y relajante.",
	},
	"futbol_barrio": {
		"categoria": "accion", "nombre": "Fútbol de barrio", "genero": "futbol", "dificultad": "normal", "sensacion": "agil", "familia": "cartoon",
		"idea": "Fútbol arcade 3D de {tema}: partidos rápidos de tres contra tres hasta ganar la copa",
		"tema": "equipos de animales en un estadio de colores", "por_que": "El deporte es la categoría que más crece en Google Play y el fútbol el más jugado.",
	},
	"terror_mansion": {
		"categoria": "unicas", "nombre": "La mansión", "genero": "terror", "dificultad": "normal", "sensacion": "normal", "familia": "pintado",
		"idea": "Terror en 3D en {tema}: busca las llaves con la linterna y escapa sin que te atrape",
		"tema": "una mansión abandonada en el bosque", "por_que": "El terror es de lo que más se juega y se comparte en vídeos: cada partida da un susto nuevo.",
	},
	"conduccion_pizzas": {
		"categoria": "accion", "nombre": "Pizza exprés", "genero": "conduccion", "dificultad": "normal", "sensacion": "agil", "familia": "cartoon",
		"idea": "Conducción 3D por {tema}: recoge las pizzas y entrégalas calientes antes de que se acabe el tiempo",
		"tema": "una ciudad llena de tráfico", "por_que": "Los juegos de conducir por la ciudad están entre los simuladores más descargados.",
	},
	"zombis_ciudad": {
		"categoria": "accion", "nombre": "Última noche", "genero": "zombis", "dificultad": "normal", "sensacion": "agil", "familia": "pintado",
		"idea": "Shooter 3D de zombis en {tema}: aguanta las oleadas con pistola, escopeta y fusil",
		"tema": "una ciudad en ruinas al atardecer", "por_que": "Los shooters de zombis en primera persona están entre los juegos de acción más descargados.",
	},
	"baloncesto_barrio": {
		"categoria": "accion", "nombre": "Rey de la pista", "genero": "baloncesto", "dificultad": "normal", "sensacion": "agil", "familia": "cartoon",
		"idea": "Baloncesto 3D en {tema}: gana los partidos callejeros de 1 contra 1 a 3 contra 3",
		"tema": "la pista del barrio", "por_que": "El baloncesto callejero es de los deportes más jugados en el móvil: partidos cortos y con jugadas que se comparten.",
	},
	"tenis_final": {
		"categoria": "accion", "nombre": "La gran final", "genero": "tenis", "dificultad": "normal", "sensacion": "agil", "familia": "cartoon",
		"idea": "Tenis 3D en {tema}: gana partido a partido hasta la final",
		"tema": "un torneo de verano en la playa", "por_que": "Los juegos de tenis para el móvil tienen millones de jugadores: partidos cortos y fáciles de entender.",
	},
	"karts_volcan": {
		"categoria": "accion", "nombre": "Gran Premio", "genero": "karts", "dificultad": "normal", "sensacion": "agil", "familia": "cartoon",
		"idea": "Carreras de karts en 3D por {tema}: derrapa en las curvas, coge los turbos y gana a los rivales",
		"tema": "un circuito entre colinas", "por_que": "Las carreras de karts son de los juegos de carreras más descargados: partidas cortas y muy rejugables.",
	},
	"arena_robots": {
		"categoria": "accion", "nombre": "Todos contra todos", "genero": "arena", "dificultad": "normal", "sensacion": "normal", "familia": "cartoon",
		"idea": "Todos contra todos en una arena de {tema} chatarreros: el último en pie gana",
		"tema": "robots", "por_que": "Partidas rápidas, online en directo y con amigos: lo que más se comparte.",
	},
	"gemas_bosque": {
		"categoria": "puzle", "nombre": "Combina 3 mágico", "genero": "puzle", "dificultad": "facil", "sensacion": "normal", "familia": "pintado",
		"idea": "Un puzle de combinar gemas en un bosque mágico de {tema}",
		"tema": "hadas", "por_que": "El género que más dinero da en móviles: relajante, para todas las edades y con mucho que mejorar.",
	},
	"torres_castillo": {
		"categoria": "estrategia", "nombre": "Defiende el castillo", "genero": "torres", "dificultad": "normal", "sensacion": "normal", "familia": "cartoon",
		"idea": "Defiende tu castillo de oleadas de {tema} con torres",
		"tema": "monstruos", "por_que": "Pensar dónde poner cada torre engancha: cada nivel es un pequeño rompecabezas.",
	},
	"imperio_pasteles": {
		"categoria": "relax", "nombre": "Imperio que crece", "genero": "clicker", "dificultad": "facil", "sensacion": "normal", "familia": "cartoon",
		"idea": "Un clicker idle donde construyes un imperio de {tema}",
		"tema": "pasteles", "por_que": "Ver crecer los números es adictivo y se juega a ratos: ideal para anuncios con premio.",
	},
	"solitario_pirata": {
		"categoria": "relax", "nombre": "Solitario tranquilo", "genero": "cartas", "dificultad": "normal", "sensacion": "normal", "familia": "pintado",
		"idea": "Un solitario de cartas en un casino {tema}",
		"tema": "pirata", "por_que": "Juego de mente para adultos que se juega cada día: muy buena retención.",
	},
	"caballeros_rpg": {
		"categoria": "estrategia", "nombre": "Aventura por turnos", "genero": "rpg", "dificultad": "normal", "sensacion": "normal", "familia": "pixel_art",
		"idea": "Un rpg por turnos de {tema} contra los monstruos de la cueva",
		"tema": "caballeros", "por_que": "Decidir cada golpe y vencer al jefe da mucha satisfacción; encaja con el pase de temporada.",
	},
	"ritmo_selva": {
		"categoria": "accion", "nombre": "Ritmo salvaje", "genero": "ritmo", "dificultad": "facil", "sensacion": "normal", "familia": "cartoon",
		"idea": "Un juego de ritmo musical con tambores en una selva de {tema}",
		"tema": "monos", "por_que": "Música y reflejos: se comparte en vídeos cortos y gusta a todas las edades.",
	},
	"granja_peques": {
		"categoria": "ninos", "nombre": "Memoria para peques", "genero": "memoria", "dificultad": "facil", "sensacion": "normal", "familia": "cartoon",
		"publico": "infantil",
		"idea": "Un juego de memoria con {tema} de la granja para peques",
		"tema": "animales", "por_que": "Para niños: sin compras ni nada online, como exige Google para el público infantil.",
	},
	"topos_huerto": {
		"categoria": "ninos", "nombre": "Aplasta topos", "genero": "topos", "dificultad": "facil", "sensacion": "normal", "familia": "cartoon",
		"publico": "infantil",
		"idea": "Aplasta a los {tema} traviesos que asoman en el huerto",
		"tema": "topos", "por_que": "Reflejos y risas para los más pequeños, en versión segura para niños.",
	},
	"trivial_planetas": {
		"categoria": "puzle", "nombre": "Trivial que enseña", "genero": "preguntas", "dificultad": "facil", "sensacion": "normal", "familia": "cartoon",
		"idea": "Un trivial de preguntas sobre {tema} para toda la familia",
		"tema": "los planetas", "por_que": "Aprender jugando: lo usan familias y colegios, y la IA escribe las preguntas.",
	},
	"minigolf_playa": {
		"categoria": "relax", "nombre": "Minigolf relajado", "genero": "golf", "dificultad": "facil", "sensacion": "normal", "familia": "cartoon",
		"idea": "Un minigolf de hoyos locos en una playa de {tema}",
		"tema": "cangrejos", "por_que": "Un dedo, partidas de 2 minutos y mucho «uno más»: gusta a todas las edades.",
	},
	"pesca_lago": {
		"categoria": "relax", "nombre": "Pesca a tiempo", "genero": "pesca", "dificultad": "facil", "sensacion": "normal", "familia": "pintado",
		"idea": "Un juego de pesca en un lago de montaña con un {tema} pescador",
		"tema": "oso", "por_que": "Tranquilo pero con reflejos: perfecto para ratos cortos y para compartir récords.",
	},
	"laberinto_piramide": {
		"categoria": "puzle", "nombre": "Laberinto de llaves", "genero": "laberinto", "dificultad": "facil", "sensacion": "normal", "familia": "pixel_art",
		"idea": "Un laberinto dentro de una pirámide con un {tema} explorador que busca llaves y monedas",
		"tema": "gato", "por_que": "Pensar el camino engancha y cada nivel se resuelve en un minuto.",
	},
	"fusion_pociones": {
		"categoria": "puzle", "nombre": "Fusiona y crece", "genero": "fusion", "dificultad": "normal", "sensacion": "normal", "familia": "cartoon",
		"idea": "Un juego de fusionar {tema} iguales hasta crear la más grande",
		"tema": "pociones mágicas", "por_que": "El estilo «merge» de las listas de éxitos: sencillo de aprender y muy adictivo.",
	},
	# ---- Generos que faltaban
	"pajaro_papel": {
		"categoria": "accion", "nombre": "Vuela de un toque", "genero": "volador", "dificultad": "normal", "sensacion": "agil", "familia": "cartoon",
		"idea": "Un {tema} de papel que vuela entre columnas con un solo toque",
		"tema": "pájaro", "por_que": "Un toque, una regla y el «una más» de siempre: de los formatos más virales en móviles.",
	},
	"rana_nenufares": {
		"categoria": "accion", "nombre": "Salta hasta la cima", "genero": "saltos", "dificultad": "normal", "sensacion": "agil", "familia": "cartoon",
		"idea": "Una {tema} que sube saltando de nenúfar en nenúfar hasta la cima de una cascada",
		"tema": "rana", "por_que": "Subir sin parar inclinando el móvil o con toques: partidas cortas y récords que picar.",
	},
	"karts_desierto": {
		"categoria": "accion", "nombre": "Carreras locas", "genero": "carreras", "dificultad": "normal", "sensacion": "agil", "familia": "cartoon",
		"idea": "Carreras de karts de {tema} por un desierto con turbos y atajos",
		"tema": "animales", "por_que": "Adelantar en la última curva se siente genial; las carreras gustan a todas las edades.",
	},
	"naves_gominola": {
		"categoria": "accion", "nombre": "Matamarcianos clásico", "genero": "naves", "dificultad": "normal", "sensacion": "agil", "familia": "pixel_art",
		"idea": "Tu nave contra una invasión de {tema} de colores",
		"tema": "marcianos de gominola", "por_que": "El arcade de toda la vida: se entiende en un segundo y la dificultad sube sola.",
	},
	"hordas_cementerio": {
		"categoria": "accion", "nombre": "Sobrevive a la horda", "genero": "horda", "dificultad": "normal", "sensacion": "normal", "familia": "pixel_art",
		"idea": "Sobrevive a oleadas de {tema} en un cementerio y sube de nivel tus poderes",
		"tema": "zombis", "por_que": "Los «survivors» son de lo más descargado: cada partida sube de nivel y nunca es igual.",
	},
	"ladrillos_caramelo": {
		"categoria": "accion", "nombre": "Rompe ladrillos", "genero": "rompebloques", "dificultad": "normal", "sensacion": "normal", "familia": "cartoon",
		"idea": "Rompe los ladrillos de un castillo de {tema} con una pelota y una pala",
		"tema": "caramelo", "por_que": "Romper cosas relaja: un clásico que funciona con cualquier tema.",
	},
	"bloques_jardin": {
		"categoria": "puzle", "nombre": "Encaja bloques", "genero": "bloques", "dificultad": "facil", "sensacion": "normal", "familia": "pintado",
		"idea": "Encaja bloques de {tema} en un tablero hasta completar filas y columnas",
		"tema": "flores", "por_que": "Los puzles de bloques sin prisa son de los más jugados por adultos cada día.",
	},
	"pociones_tubos": {
		"categoria": "puzle", "nombre": "Ordena las pociones", "genero": "tubos", "dificultad": "normal", "sensacion": "normal", "familia": "cartoon",
		"idea": "Un puzle de ordenar {tema} de colores en tubos hasta que cada tubo tenga un solo color",
		"tema": "pociones", "por_que": "El «water sort» está siempre entre los puzles más descargados: relajante, se entiende sin explicar nada.",
	},
	"burbujas_hadas": {
		"categoria": "puzle", "nombre": "Lanza burbujas", "genero": "burbujas", "dificultad": "normal", "sensacion": "normal", "familia": "cartoon",
		"idea": "Un lanza burbujas de colores en un bosque de {tema}: apunta, junta tres y haz caer los racimos",
		"tema": "hadas", "por_que": "El bubble shooter es un clásico que no pasa de moda: apuntar y ver caer medio tablero engancha a todas las edades.",
	},
	"cajas_regalos": {
		"categoria": "puzle", "nombre": "Empuja las cajas", "genero": "cajas", "dificultad": "normal", "sensacion": "normal", "familia": "pixel_art",
		"idea": "Un {tema} que empuja cajas de regalos hasta su sitio en un almacén",
		"tema": "elfo", "por_que": "Puzles de pensar con solución comprobada: cada nivel es un pequeño «¡ajá!».",
	},
	"serpiente_huerto": {
		"categoria": "accion", "nombre": "Serpiente golosa", "genero": "serpiente", "dificultad": "normal", "sensacion": "normal", "familia": "pixel_art",
		"idea": "Una serpiente que come {tema} en un huerto y crece sin chocar con su cola",
		"tema": "fresas", "por_que": "El clásico de los móviles de siempre, con niveles y obstáculos nuevos.",
	},
	"tarta_cielo": {
		"categoria": "relax", "nombre": "Apila hasta el cielo", "genero": "apilar", "dificultad": "facil", "sensacion": "normal", "familia": "cartoon",
		"idea": "Apila pisos de {tema} hasta el cielo sin que se caiga la torre",
		"tema": "tarta", "por_que": "Un toque en el momento justo: hipnótico, rápido y perfecto para anuncios con premio.",
	},
	# ---- Mas variedad en los generos que mas se juegan
	"mazmorra_pixel": {
		"categoria": "accion", "nombre": "Mazmorra con reto", "genero": "plataformas", "dificultad": "dificil", "sensacion": "agil", "familia": "pixel_art",
		"idea": "Un {tema} que baja por una mazmorra llena de pinchos y trampas hasta el jefe final",
		"tema": "caballero", "por_que": "Para quien busca reto: niveles exigentes pero justos (los bots los superan antes de entregarlos).",
	},
	"runner_espacio": {
		"categoria": "accion", "nombre": "Huida espacial", "genero": "runner", "dificultad": "normal", "sensacion": "agil", "familia": "low_poly",
		"idea": "Un {tema} astronauta que corre sin parar por una estación espacial esquivando meteoritos",
		"tema": "perro", "por_que": "El espacio vende: mismo runner adictivo con otro aire.",
	},
	"puzle_dulces": {
		"categoria": "puzle", "nombre": "Combina dulces", "genero": "puzle", "dificultad": "facil", "sensacion": "normal", "familia": "cartoon",
		"idea": "Un puzle de combinar 3 {tema} en una pastelería",
		"tema": "caramelos", "por_que": "El combina 3 de dulces es el formato más reconocible de las tiendas.",
	},
	"torres_granja": {
		"categoria": "estrategia", "nombre": "Defiende la granja", "genero": "torres", "dificultad": "facil", "sensacion": "normal", "familia": "cartoon",
		"idea": "Defiende las zanahorias de la granja de oleadas de {tema} con torres",
		"tema": "conejos glotones", "por_que": "Tower defense amable para todos los públicos: estrategia sin agobios.",
	},
	"magos_rpg": {
		"categoria": "estrategia", "nombre": "Escuela de magos", "genero": "rpg", "dificultad": "normal", "sensacion": "normal", "familia": "pintado",
		"idea": "Un rpg por turnos de {tema} aprendices contra criaturas del bosque encantado",
		"tema": "magos", "por_que": "Combates por turnos con hechizos: estrategia tranquila que se juega con una mano.",
	},
	"clicker_espacio": {
		"categoria": "relax", "nombre": "Imperio galáctico", "genero": "clicker", "dificultad": "facil", "sensacion": "normal", "familia": "low_poly",
		"idea": "Un clicker idle donde construyes una colonia de {tema} en Marte",
		"tema": "robots", "por_que": "Progreso aunque no juegues: la gente vuelve cada día a ver cuánto ha crecido.",
	},
	"cartas_noche": {
		"categoria": "relax", "nombre": "Solitario nocturno", "genero": "cartas", "dificultad": "facil", "sensacion": "normal", "familia": "pintado",
		"idea": "Un solitario de cartas relajante en una cabaña de {tema} bajo las estrellas",
		"tema": "montaña", "por_que": "Para desconectar antes de dormir: el público adulto de los solitarios juega todos los días.",
	},
	"trivial_cine": {
		"categoria": "puzle", "nombre": "Trivial de cine", "genero": "preguntas", "dificultad": "normal", "sensacion": "normal", "familia": "cartoon",
		"idea": "Un trivial de preguntas sobre {tema} para jugar con amigos",
		"tema": "el cine y las series", "por_que": "Las preguntas de cultura general se comparten y se juegan en grupo.",
	},
	"ritmo_espacial": {
		"categoria": "accion", "nombre": "Ritmo galáctico", "genero": "ritmo", "dificultad": "normal", "sensacion": "agil", "familia": "low_poly",
		"idea": "Un juego de ritmo con notas de neón en una discoteca de {tema} en el espacio",
		"tema": "aliens", "por_que": "Música y luces: queda genial en vídeos cortos para redes.",
	},
	# ---- Para peques (sin compras ni online, como pide Google)
	"dinos_memoria": {
		"categoria": "ninos", "nombre": "Memoria de dinosaurios", "genero": "memoria", "dificultad": "facil", "sensacion": "normal", "familia": "cartoon",
		"publico": "infantil",
		"idea": "Un juego de memoria con {tema} simpáticos para peques",
		"tema": "dinosaurios", "por_que": "Los dinosaurios encantan a los niños: memoria y atención jugando.",
	},
	"pesca_peques": {
		"categoria": "ninos", "nombre": "Pesca para peques", "genero": "pesca", "dificultad": "facil", "sensacion": "normal", "familia": "cartoon",
		"publico": "infantil",
		"idea": "Pesca peces de colores en un estanque con un {tema} amable",
		"tema": "pato", "por_que": "Un toque y mucho color: reflejos suaves para los más pequeños.",
	},
	"golf_peques": {
		"categoria": "ninos", "nombre": "Minigolf de juguete", "genero": "golf", "dificultad": "facil", "sensacion": "normal", "familia": "cartoon",
		"publico": "infantil",
		"idea": "Un minigolf en un cuarto de {tema} de juguete",
		"tema": "peluches", "por_que": "Apuntar y soltar: fácil de aprender para niños y divertido de ver.",
	},
	# ---- Unicas: giros y mezclas que no tiene nadie (probados por los bots)
	"laberinto_serpiente": {
		"categoria": "unicas", "nombre": "Laberinto serpiente", "genero": "laberinto", "dificultad": "normal", "sensacion": "normal", "familia": "pixel_art",
		"giros": ["cola"],
		"idea": "Un {tema} que recorre un laberinto donde cada paso cierra el camino detrás de él",
		"tema": "gusano", "por_que": "Mezcla de laberinto y serpiente: hay que pensar el camino entero antes de moverse.",
	},
	"golf_monstruos": {
		"categoria": "unicas", "nombre": "Golf de monstruos", "genero": "golf", "dificultad": "normal", "sensacion": "normal", "familia": "cartoon",
		"giros": ["monstruos"],
		"idea": "Un minigolf en un castillo encantado donde derribas {tema} a bolazos para abrir el hoyo",
		"tema": "fantasmas", "por_que": "Minigolf con un toque de RPG: cada golpe es un pequeño plan.",
	},
	"cajas_hielo": {
		"categoria": "unicas", "nombre": "Cajas sobre hielo", "genero": "cajas", "dificultad": "normal", "sensacion": "normal", "familia": "pixel_art",
		"giros": ["hielo"],
		"idea": "Un {tema} que empuja bloques de hielo que resbalan hasta chocar en una cueva helada",
		"tema": "pingüino", "por_que": "El puzle de cajas con suelo de hielo: piensas dónde se va a parar cada bloque.",
	},
	"serpiente_tuneles": {
		"categoria": "unicas", "nombre": "Serpiente de túneles", "genero": "serpiente", "dificultad": "normal", "sensacion": "normal", "familia": "pixel_art",
		"giros": ["tuneles"],
		"idea": "Una serpiente de {tema} que cruza túneles: sale por un borde y entra por el otro",
		"tema": "neón", "por_que": "La serpiente de siempre con atajos por los bordes: rutas nuevas en cada nivel.",
	},
	"memoria_inquieta": {
		"categoria": "unicas", "nombre": "Cartas traviesas", "genero": "memoria", "dificultad": "normal", "sensacion": "normal", "familia": "cartoon",
		"giros": ["barajar"],
		"idea": "Un juego de memoria con cartas de {tema} traviesas que se cambian de sitio",
		"tema": "monstruos", "por_que": "Memoria con trampa: cada dos fallos dos cartas se cambian a la vista. Hay que estar atento.",
	},
	"topos_oro": {
		"categoria": "unicas", "nombre": "Mina de oro", "genero": "topos", "dificultad": "normal", "sensacion": "agil", "familia": "cartoon",
		"giros": ["dorado"],
		"idea": "Aplasta a los {tema} que asoman en una mina; los de oro valen triple",
		"tema": "topos mineros", "por_que": "Reflejos con premio gordo: el bicho de oro se va antes pero vale 3 golpes.",
	},
	"pesca_tormenta": {
		"categoria": "unicas", "nombre": "Pesca en la tormenta", "genero": "pesca", "dificultad": "normal", "sensacion": "agil", "familia": "pintado",
		"giros": ["tormenta"],
		"idea": "Un {tema} pescando en alta mar durante una tormenta: los peces van cada vez más rápido",
		"tema": "marinero", "por_que": "Pesca con tensión creciente: la lluvia acelera a los peces según pasa el tiempo.",
	},
	"golf_viento": {
		"categoria": "unicas", "nombre": "Golf con viento", "genero": "golf", "dificultad": "normal", "sensacion": "normal", "familia": "cartoon",
		"giros": ["viento"],
		"idea": "Un minigolf en los acantilados de {tema} con viento que empuja la bola",
		"tema": "una isla", "por_que": "Cada hoyo con su viento: apuntar contando con él es un reto nuevo.",
	},
	"fusion_piedras": {
		"categoria": "unicas", "nombre": "Fusión entre rocas", "genero": "fusion", "dificultad": "normal", "sensacion": "normal", "familia": "cartoon",
		"giros": ["piedras"],
		"idea": "Fusiona {tema} iguales en una cantera llena de rocas que se rompen al fusionar al lado",
		"tema": "gemas", "por_que": "El merge de siempre con obstáculos: romper las rocas en el momento justo.",
	},
	"tejados_oscuros": {
		"categoria": "unicas", "nombre": "Saltos a oscuras", "genero": "plataformas", "dificultad": "normal", "sensacion": "agil", "familia": "pixel_art",
		"giros": ["oscuridad"],
		"idea": "Un {tema} con una linterna que salta por una mina abandonada a oscuras",
		"tema": "minero", "por_que": "Solo ves lo que alumbra tu linterna: tensión y sorpresa en cada salto.",
	},
	"runner_fantasma": {
		"categoria": "unicas", "nombre": "Carrera contra ti", "genero": "runner", "dificultad": "normal", "sensacion": "agil", "familia": "cartoon",
		"giros": ["fantasma"],
		"idea": "Un {tema} que corre contra su propio fantasma: la figura repite tu mejor carrera",
		"tema": "zorro", "por_que": "Ganarte a ti mismo engancha: siempre hay un récord que batir a la vista.",
	},
	"laberinto_reloj": {
		"categoria": "unicas", "nombre": "Laberinto contrarreloj", "genero": "laberinto", "dificultad": "normal", "sensacion": "agil", "familia": "pixel_art",
		"giros": ["contrarreloj"],
		"idea": "Escapa de un laberinto de {tema} antes de que se acabe el tiempo",
		"tema": "hielo", "por_que": "Pensar rápido: el reloj convierte cada laberinto en una carrera.",
	},
	"ritmo_ciego": {
		"categoria": "unicas", "nombre": "Ritmo a ciegas", "genero": "ritmo", "dificultad": "normal", "sensacion": "normal", "familia": "low_poly",
		"giros": ["invisibles"],
		"idea": "Un juego de ritmo en una discoteca de {tema} donde las notas se apagan antes de llegar",
		"tema": "robots", "por_que": "Ritmo para expertos: las notas desaparecen y se toca de memoria. Ideal para retar a amigos.",
	},
	"vuelo_espejo": {
		"categoria": "unicas", "nombre": "Vuelo al revés", "genero": "volador", "dificultad": "normal", "sensacion": "agil", "familia": "cartoon",
		"giros": ["espejo"],
		"idea": "Un {tema} que vuela por un mundo espejo donde todo se ve al revés",
		"tema": "murciélago", "por_que": "Un toque y el mundo del revés: confunde y engancha a la vez.",
	},
	## Para clase: juegos de repaso que el profe usa con el modo clase (codigo y progreso de cada alumno).
	"aula_tablas": {
		"categoria": "aula", "nombre": "Tablas de multiplicar", "genero": "preguntas", "dificultad": "facil", "sensacion": "normal", "familia": "cartoon",
		"idea": "Preguntas de las tablas de multiplicar del {tema}: un cohete sube un poco hacia la Luna con cada acierto",
		"tema": "1 al 10", "por_que": "Repasar las tablas sin que parezca deberes; con el modo clase ves quién ha llegado al final.",
	},
	"aula_capitales": {
		"categoria": "aula", "nombre": "Capitales del mundo", "genero": "preguntas", "dificultad": "normal", "sensacion": "normal", "familia": "cartoon",
		"idea": "Un trivial de capitales y banderas de {tema} con un avión que viaja de país en país",
		"tema": "Europa", "por_que": "Geografía en partidas de 5 minutos; cada nivel, un grupo de países.",
	},
	"aula_vocabulario": {
		"categoria": "aula", "nombre": "Vocabulario en globos", "genero": "ahorcado", "dificultad": "facil", "sensacion": "normal", "familia": "cartoon",
		"idea": "Un ahorcado con globos para repasar el vocabulario de {tema}",
		"tema": "los animales en inglés", "por_que": "Las palabras de la unidad, una por nivel: se aprenden letra a letra y sin nada triste.",
	},
	"aula_palabras": {
		"categoria": "aula", "nombre": "Forma palabras", "genero": "letras", "dificultad": "facil", "sensacion": "normal", "familia": "pintado",
		"idea": "Forma palabras sobre {tema} uniendo letras en un huerto escolar",
		"tema": "la naturaleza", "por_que": "Ortografía y vocabulario a la vez; los niveles suben poco a poco de letras.",
	},
	"aula_parejas": {
		"categoria": "aula", "nombre": "Parejas de ciencias", "genero": "memoria", "dificultad": "facil", "sensacion": "normal", "familia": "cartoon",
		"idea": "Un juego de memoria con parejas de {tema}",
		"tema": "los planetas del sistema solar", "por_que": "Memoria visual con el temario: ideal para los primeros minutos de clase.",
	},
}

MARCA = re.compile(r"^\s*\[plantilla:([a-z0-9_]{2,40})\]\s*")


def separar(idea: str) -> tuple[str, dict | None]:
	"""«[plantilla:id] idea» -> (idea sin la marca, plantilla o None)."""
	m = MARCA.match(idea)
	if not m:
		return idea, None
	p = PLANTILLAS.get(m.group(1))
	return idea[m.end():].strip(), (dict(p, id=m.group(1)) if p else None)


def idea_de(pid: str, tema: str = "") -> str:
	"""La idea completa que manda la app (con la marca)."""
	p = PLANTILLAS[pid]
	return f"[plantilla:{pid}] " + p["idea"].replace("{tema}", (tema or p["tema"]).strip()[:60])


def guia(p: dict) -> str:
	"""Lo que la directora tiene que respetar (va con la idea, como datos)."""
	return (f"Plantilla de exito «{p['nombre']}»: genero {p['genero']} obligatorio, dificultad {p['dificultad']}, "
		f"sensacion {p['sensacion']}, estilo {p['familia']}" + (f", giros {', '.join(p['giros'])}" if p.get("giros") else "") + (", juego para ninos (todo apto para todas las edades)" if p.get("publico") == "infantil" else "") + ".")


def fijar(d: dict, p: dict) -> dict:
	"""Vuelve a poner en el diseno lo que la plantilla fija."""
	d["genero"] = p["genero"]
	d["dificultad"] = p["dificultad"]
	d["sensacion"] = p["sensacion"]
	d["estilo"]["familia"] = p["familia"]
	if p.get("publico"):
		d["publico"] = p["publico"]
	if p.get("giros"):
		d["giros"] = list(p["giros"])
	d["plantilla"] = p["id"]
	return d
