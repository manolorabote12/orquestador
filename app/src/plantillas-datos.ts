// GENERADO por fabrica/sincronizar_servidor.py desde fabrica/plantillas.py: no editar a mano.

export interface Plantilla { id: string; nombre: string; genero: string; idea: string; tema: string; por_que: string; infantil: boolean;
  categoria: "accion" | "puzle" | "estrategia" | "relax" | "ninos" | "aula" | "unicas"; giros: string[] }

export const PLANTILLAS: Plantilla[] = [
  {
    "id": "gato_tejados",
    "nombre": "Saltos por los tejados",
    "genero": "plataformas",
    "idea": "Un {tema} ninja que salta por los tejados de noche esquivando guardias y recogiendo monedas",
    "tema": "gato",
    "por_que": "Las plataformas con un héroe con carisma son lo más jugado en móviles: fácil de entender, difícil de dominar.",
    "infantil": false,
    "categoria": "accion",
    "giros": []
  },
  {
    "id": "huida_volcan",
    "nombre": "Huida sin fin",
    "genero": "runner",
    "idea": "Un {tema} que huye corriendo sin parar por un volcán que se derrumba (runner)",
    "tema": "zorro",
    "por_que": "Partidas de 1 minuto con un solo toque: perfectas para el bus o la cola del súper.",
    "infantil": false,
    "categoria": "accion",
    "giros": []
  },
  {
    "id": "tren_ciudad",
    "nombre": "Carriles de neón",
    "genero": "corredor",
    "idea": "Corre por tres carriles esquivando trenes en una ciudad de neón con un {tema} (3D)",
    "tema": "skater",
    "por_que": "El estilo de los corredores de carriles en 3D: reconocible al instante y muy rejugable.",
    "infantil": false,
    "categoria": "accion",
    "giros": []
  },
  {
    "id": "clanes_vikingos",
    "nombre": "Asalto de clanes",
    "genero": "aldea",
    "idea": "Asalta las aldeas de los clanes rivales con tu ejército de {tema} vikingos",
    "tema": "gatos",
    "por_que": "Construir tu aldea y asaltar las de otros engancha durante meses (liga, clanes y guerra semanal incluidos).",
    "infantil": false,
    "categoria": "estrategia",
    "giros": []
  },
  {
    "id": "guerras_tribales",
    "nombre": "Guerras tribales",
    "genero": "imperio",
    "idea": "Levanta tu tribu de {tema}: aldeanos que recogen recursos, casas, cuarteles y un ejército para conquistar las tribus rivales en tiempo real",
    "tema": "bárbaros",
    "por_que": "La estrategia de construir y conquistar engancha durante horas: cada partida es distinta según cómo repartas a tu gente.",
    "infantil": false,
    "categoria": "estrategia",
    "giros": []
  },
  {
    "id": "imperio_medieval",
    "nombre": "Imperio medieval",
    "genero": "imperio",
    "idea": "Haz crecer un reino medieval de {tema}: tres edades, torres, arqueros, caballería y arietes para derribar el castillo enemigo",
    "tema": "caballeros",
    "por_que": "El estilo de los grandes juegos de imperios en el móvil: economía, edades y batallas de piedra, papel o tijera.",
    "infantil": false,
    "categoria": "estrategia",
    "giros": []
  },
  {
    "id": "reinos_desierto",
    "nombre": "Reinos del desierto",
    "genero": "imperio",
    "idea": "Construye un imperio de {tema} entre dunas y oasis: minas de oro, jinetes y arietes contra el faraón rival",
    "tema": "nómadas",
    "por_que": "Un tema exótico con mucha personalidad hace que tu juego de estrategia destaque en la tienda.",
    "infantil": false,
    "categoria": "estrategia",
    "giros": []
  },
  {
    "id": "primer_imperio",
    "nombre": "Mi primer imperio",
    "genero": "imperio",
    "idea": "Un imperio tranquilo de {tema} para aprender a jugar a estrategia: el rival ataca poco y cada nivel enseña algo nuevo",
    "tema": "ositos",
    "por_que": "Mucha gente quiere jugar a estrategia pero se agobia: empezar suave hace que se queden.",
    "infantil": false,
    "categoria": "estrategia",
    "giros": []
  },
  {
    "id": "magnate_minero",
    "nombre": "Magnate minero",
    "genero": "minas",
    "idea": "Un idle de minas donde {tema} excavan pozos cada vez más hondos, suben el mineral en ascensor y lo venden: mejoras y gerentes",
    "tema": "enanos",
    "por_que": "Los idle de minas están entre los más jugados: siempre hay una mejora a la vista y el dinero sube aunque no juegues.",
    "infantil": false,
    "categoria": "relax",
    "giros": []
  },
  {
    "id": "mina_golosinas",
    "nombre": "Mina de golosinas",
    "genero": "minas",
    "idea": "Una mina mágica de {tema} donde unos topitos excavan caramelos de colores y los venden en la tienda de arriba",
    "tema": "chuches",
    "por_que": "Ver crecer tu mina sin presión engancha a los peques: tocar, mejorar y celebrar cada pozo nuevo.",
    "infantil": true,
    "categoria": "ninos",
    "giros": []
  },
  {
    "id": "cripta_arquera",
    "nombre": "Cripta de monstruos",
    "genero": "mazmorras",
    "idea": "Un {tema} arquero limpia criptas sala a sala: dispara al pararse, esquiva al moverse, sube de nivel, elige habilidades y abre cofres con equipo",
    "tema": "elfo",
    "por_que": "El estilo Archero arrasa en móviles: se juega con un dedo, cada partida es distinta y el botín engancha.",
    "infantil": false,
    "categoria": "accion",
    "giros": []
  },
  {
    "id": "mazmorra_dragon",
    "nombre": "La guarida del dragón",
    "genero": "mazmorras",
    "idea": "Baja por la mazmorra de un dragón con tu {tema}: golems, arqueros goblin, salas de tesoro con armas legendarias y el dragón al final",
    "tema": "caballera",
    "por_que": "Un jefe final temible y equipo legendario: la promesa perfecta para un RPG de acción.",
    "infantil": false,
    "categoria": "accion",
    "giros": []
  },
  {
    "id": "granja_cozy",
    "nombre": "Granja cozy",
    "genero": "granja",
    "idea": "Una granja cozy de {tema}: siembra, cosecha, cuida gallinas y vacas, hornea pan y tartas y cumple los pedidos del pueblo",
    "tema": "conejitos",
    "por_que": "Los juegos de granja relajantes tipo Hay Day enganchan a millones: siempre hay algo creciendo y un pedido que cumplir.",
    "infantil": false,
    "categoria": "relax",
    "giros": []
  },
  {
    "id": "granja_valle",
    "nombre": "El valle de las cosechas",
    "genero": "granja",
    "idea": "Hereda una granja en un valle de {tema} y hazla prosperar: cultivos de temporada, animales, quesería, telar y pedidos cada vez más grandes",
    "tema": "montaña",
    "por_que": "El estilo Stardew en píxel con cadenas de producción: profundo pero tranquilo.",
    "infantil": false,
    "categoria": "relax",
    "giros": []
  },
  {
    "id": "torre_cartas",
    "nombre": "La torre de cartas",
    "genero": "mazo",
    "idea": "Un {tema} sube una torre combatiendo con un mazo de cartas: ataques, escudos, venenos y poderes; cada victoria da una carta nueva",
    "tema": "mago",
    "por_que": "Los deckbuilders tipo Slay the Spire son de los juegos de estrategia más rejugables: cada partida, un mazo distinto.",
    "infantil": false,
    "categoria": "estrategia",
    "giros": []
  },
  {
    "id": "cartas_piratas",
    "nombre": "Duelos de piratas",
    "genero": "mazo",
    "idea": "Duelos de cartas entre {tema} en alta mar: lee lo que va a hacer el rival, bloquea a tiempo y acaba con el capitán dragón",
    "tema": "piratas",
    "por_que": "Leer las intenciones del rival y planear el turno perfecto da una satisfacción enorme.",
    "infantil": false,
    "categoria": "estrategia",
    "giros": []
  },
  {
    "id": "isla_misteriosa",
    "nombre": "La isla misteriosa",
    "genero": "aventura",
    "idea": "Una historia con decisiones: una {tema} naufraga en una isla llena de secretos; cada capítulo, decisiones que cambian quién te ayuda y cómo termina",
    "tema": "exploradora",
    "por_que": "Los juegos de historias con decisiones (tipo Choices o Episode) enganchan por saber qué pasa si eliges distinto.",
    "infantil": false,
    "categoria": "unicas",
    "giros": []
  },
  {
    "id": "detective_pueblo",
    "nombre": "Detective del pueblo",
    "genero": "aventura",
    "idea": "Una novela visual de misterio: un {tema} detective resuelve casos en su pueblo hablando con vecinos, buscando pistas y eligiendo a quién creer",
    "tema": "gato",
    "por_que": "El misterio por capítulos con pistas y varios finales hace que la gente vuelva para descubrirlo todo.",
    "infantil": false,
    "categoria": "unicas",
    "giros": []
  },
  {
    "id": "food_truck",
    "nombre": "Mi food truck",
    "genero": "cocina",
    "idea": "Un {tema} abre su food truck: hamburguesas a la plancha, patatas y refrescos para una cola de clientes con prisa; cada día, más platos en el menú",
    "tema": "mapache",
    "por_que": "Los juegos de cocina tipo Cooking Fever enganchan con partidas cortas: cocinar, montar y servir a tiempo.",
    "infantil": false,
    "categoria": "relax",
    "giros": []
  },
  {
    "id": "hamburgueseria_frenetica",
    "nombre": "Hamburguesería frenética",
    "genero": "cocina",
    "idea": "Una hamburguesería de {tema} en hora punta: la carne se quema si te despistas y los clientes se van si tardas; consigue la meta del día",
    "tema": "robots",
    "por_que": "La presión de gestionar el tiempo con muchos pedidos a la vez es pura adrenalina en el móvil.",
    "infantil": false,
    "categoria": "accion",
    "giros": []
  },
  {
    "id": "mahjong_zen",
    "nombre": "Mahjong zen",
    "genero": "mahjong",
    "idea": "Un mahjong solitario relajante en un {tema}: quita parejas de fichas libres hasta vaciar torres y pirámides, sin prisa",
    "tema": "jardín japonés con cerezos",
    "por_que": "El mahjong solitario es de los juegos de relax más jugados: partidas tranquilas y siempre con solución.",
    "infantil": false,
    "categoria": "relax",
    "giros": []
  },
  {
    "id": "mahjong_templo",
    "nombre": "El templo de las fichas",
    "genero": "mahjong",
    "idea": "Mahjong de aventura: cada nivel, un tablero más alto en las salas de un {tema}; mira bien qué fichas destapan a las demás",
    "tema": "templo perdido en la selva",
    "por_que": "Planear qué pareja quitar primero para no quedarse atascado es un reto de lógica que engancha.",
    "infantil": false,
    "categoria": "puzle",
    "giros": []
  },
  {
    "id": "atasco_ciudad",
    "nombre": "Atasco en la ciudad",
    "genero": "aparcamiento",
    "idea": "Un puzle de aparcamiento tipo Parking Jam en una {tema}: cada coche solo va hacia delante; sácalos en el orden justo sin chocar",
    "tema": "ciudad llena de taxis",
    "por_que": "Los puzles de atascos son rapidísimos de entender y piden pensar el orden antes de tocar.",
    "infantil": false,
    "categoria": "puzle",
    "giros": []
  },
  {
    "id": "parking_mascotas",
    "nombre": "El parking de las mascotas",
    "genero": "aparcamiento",
    "idea": "Coches de colores conducidos por {tema} que quieren salir del aparcamiento: toca cada uno cuando tenga el camino libre",
    "tema": "perritos y gatitos",
    "por_que": "Pocas piezas, colores vivos y una regla clara: ideal para peques.",
    "infantil": true,
    "categoria": "ninos",
    "giros": []
  },
  {
    "id": "sopa_animales",
    "nombre": "Sopa de letras salvaje",
    "genero": "sopa",
    "idea": "Una sopa de letras de {tema}: encuentra las palabras escondidas en horizontal, vertical y diagonal",
    "tema": "animales de la selva",
    "por_que": "Las sopas de letras se juegan a diario: relajan y se entienden en cualquier idioma.",
    "infantil": false,
    "categoria": "relax",
    "giros": []
  },
  {
    "id": "sopa_espacial",
    "nombre": "Palabras en órbita",
    "genero": "sopa",
    "idea": "Sopa de letras del {tema}: planetas, cometas y galaxias escondidas, también al revés",
    "tema": "espacio",
    "por_que": "Con palabras al revés y en diagonal, cada nivel es un reto de vista y paciencia.",
    "infantil": false,
    "categoria": "puzle",
    "giros": []
  },
  {
    "id": "pedidos_puerto",
    "nombre": "Café del puerto",
    "genero": "pedidos",
    "idea": "Un juego de fusionar con pedidos en {tema}: junta objetos iguales y atiende a los clientes",
    "tema": "un café junto al mar",
    "por_que": "Tipo Gossip Harbor, de los que más facturan: relaja y siempre hay un pedido más.",
    "infantil": false,
    "categoria": "relax",
    "giros": []
  },
  {
    "id": "poder_caballeros",
    "nombre": "Torres del rey",
    "genero": "poder",
    "idea": "Una torre de poder de {tema}: vence primero a los más débiles para crecer y derrota al jefe",
    "tema": "caballeros contra monstruos",
    "por_que": "El anuncio de Hero Wars convertido en juego: un número, una decisión y enganche total.",
    "infantil": false,
    "categoria": "puzle",
    "giros": []
  },
  {
    "id": "diferencias_mar",
    "nombre": "Ojo de lince",
    "genero": "diferencias",
    "idea": "Un encuentra las diferencias de {tema}: dos dibujos casi iguales y pocas oportunidades de fallar",
    "tema": "parques, mares y ciudades",
    "por_que": "Un clásico para todas las edades: partidas cortas, relajantes y perfectas para anuncios entre nivel y nivel.",
    "infantil": false,
    "categoria": "puzle",
    "giros": []
  },
  {
    "id": "rompecabezas_paisajes",
    "nombre": "Pieza a pieza",
    "genero": "rompecabezas",
    "idea": "Un rompecabezas de {tema}: el héroe del juego en cada dibujo y piezas que se cambian de sitio",
    "tema": "paisajes y aventuras",
    "por_que": "Relajante y sin prisa: perfecto para jugar un rato y para anuncios con recompensa (pistas).",
    "infantil": false,
    "categoria": "puzle",
    "giros": []
  },
  {
    "id": "pintar_pixeles",
    "nombre": "Cuadritos de colores",
    "genero": "pintar",
    "idea": "Un pintar por números de {tema}: dibujos de cuadritos y, de vez en cuando, el héroe del juego para colorear",
    "tema": "animales, comida y aventuras",
    "por_que": "De lo más descargado para relajarse: sin perder nunca, ideal para anuncios con recompensa (cubos).",
    "infantil": false,
    "categoria": "puzle",
    "giros": []
  },
  {
    "id": "cuchillos_ninja",
    "nombre": "Filo giratorio",
    "genero": "cuchillos",
    "idea": "Un lanza cuchillos de {tema}: troncos que giran, frenan y cambian de sentido, y jefes cada cinco niveles",
    "tema": "ninjas en el bosque",
    "por_que": "Un toque, partidas de segundos y el «una más»: el clásico de Ketchapp que engancha.",
    "infantil": false,
    "categoria": "accion",
    "giros": []
  },
  {
    "id": "arquero_templo",
    "nombre": "Flechas del templo",
    "genero": "arquero",
    "idea": "Un archero de {tema}: salas llenas de enemigos, dispara al pararte y elige una habilidad nueva en cada sala",
    "tema": "un templo encantado",
    "por_que": "El bucle de Archero: partidas de minutos, una decisión cada sala y ganas de otra vuelta.",
    "infantil": false,
    "categoria": "accion",
    "giros": []
  },
  {
    "id": "flechas_colores",
    "nombre": "Salida libre",
    "genero": "flechas",
    "idea": "Un puzle de flechas que salen de {tema}: toca cada flecha en el orden justo para vaciar el tablero sin chocar",
    "tema": "un tablero de colores",
    "por_que": "Uno de los puzles más jugados de 2025: se entiende en un segundo y engancha nivel tras nivel.",
    "infantil": false,
    "categoria": "puzle",
    "giros": []
  },
  {
    "id": "numeros_2048",
    "nombre": "Doble o nada",
    "genero": "numeros",
    "idea": "Un 2048 de {tema}: desliza, junta fichas iguales y llega a la ficha objetivo de cada nivel",
    "tema": "fichas de colores",
    "por_que": "El clásico que nunca pasa de moda, con niveles cortos, rocas y deshacer (ideal para anuncios con recompensa).",
    "infantil": false,
    "categoria": "puzle",
    "giros": []
  },
  {
    "id": "cartas_locas_familia",
    "nombre": "Ocho locos",
    "genero": "cartas_locas",
    "idea": "Un juego de cartas locas de {tema}: mismo color o mismo número, +2, saltos, reversas y comodines contra 1 a 3 rivales",
    "tema": "animales del bosque",
    "por_que": "El juego de cartas de toda la vida en el móvil: partidas de 3 minutos, todo el mundo sabe jugar.",
    "infantil": false,
    "categoria": "estrategia",
    "giros": []
  },
  {
    "id": "domino_bar",
    "nombre": "La partida del barrio",
    "genero": "domino",
    "idea": "Un dominó de {tema}: encaja fichas en las puntas, roba del pozo y quédate sin fichas antes que los rivales",
    "tema": "un bar de playa",
    "por_que": "El clásico de mesa de siempre: lo conoce todo el mundo y se juega en 3 minutos.",
    "infantil": false,
    "categoria": "estrategia",
    "giros": []
  },
  {
    "id": "bloques_colores_jam",
    "nombre": "Atasco de colores",
    "genero": "bloques_colores",
    "idea": "Un juego de sacar bloques de colores por su puerta en {tema}: arrastra cada bloque por los huecos hasta la puerta de su color",
    "tema": "una juguetería",
    "por_que": "El puzle de moda (tipo Color Block Jam): se entiende al momento y cada nivel pide pensar el orden.",
    "infantil": false,
    "categoria": "puzle",
    "giros": []
  },
  {
    "id": "tuberias_fontanero",
    "nombre": "Agua para todos",
    "genero": "tuberias",
    "idea": "Un juego de girar tuberías en {tema}: toca cada pieza hasta que el agua del grifo llegue a todas sin fugas",
    "tema": "un jardín sediento",
    "por_que": "Relajante y con solución siempre: perfecto para partidas cortas y anuncios con recompensa.",
    "infantil": false,
    "categoria": "relax",
    "giros": []
  },
  {
    "id": "ajedrez_escuela",
    "nombre": "Escuela de ajedrez",
    "genero": "ajedrez",
    "idea": "Un juego de ajedrez en {tema}: empiezas con ventaja (al rival le faltan piezas) y cada nivel la quita hasta la partida de verdad",
    "tema": "un parque con tableros gigantes",
    "por_que": "El clásico de siempre con una escalera de dificultad: engancha a quien aprende y a quien ya sabe.",
    "infantil": false,
    "categoria": "estrategia",
    "giros": []
  },
  {
    "id": "reversi_jardin",
    "nombre": "Reversi del jardín",
    "genero": "reversi",
    "idea": "Un juego de reversi en {tema}: encierra las fichas del rival para darles la vuelta; primero en un tablero pequeño y luego en el grande",
    "tema": "un jardín japonés de piedras blancas y negras",
    "por_que": "Se aprende en un minuto y engancha años: partidas cortas perfectas para el móvil.",
    "infantil": false,
    "categoria": "estrategia",
    "giros": []
  },
  {
    "id": "buscar_desvan",
    "nombre": "El desván de la abuela",
    "genero": "buscar",
    "idea": "Un juego de buscar objetos en {tema}: cada nivel una escena llena de cosas y una lista de lo que hay que encontrar",
    "tema": "un desván lleno de recuerdos",
    "por_que": "Uno de los géneros favoritos de quien juega en el sofá: tranquilo, visual y muy de anuncios con premio (pistas).",
    "infantil": false,
    "categoria": "relax",
    "giros": []
  },
  {
    "id": "deslizar_museo",
    "nombre": "El cuadro revuelto",
    "genero": "deslizar",
    "idea": "Un puzle de deslizar en {tema}: el cuadro con el héroe en medio está revuelto y hay que deslizar las piezas hasta recomponerlo",
    "tema": "un museo de cuadros mágicos",
    "por_que": "El clásico de 15 con el arte del propio juego: cada nivel es un dibujo nuevo y un tablero más grande.",
    "infantil": false,
    "categoria": "puzle",
    "giros": []
  },
  {
    "id": "ahorcado_globos",
    "nombre": "Globos de letras",
    "genero": "ahorcado",
    "idea": "Un juego del ahorcado en {tema}: el héroe cuelga de un ramo de globos y cada letra que no está revienta uno",
    "tema": "una feria con globos de colores",
    "por_que": "El ahorcado de siempre sin nada triste: aprender palabras jugando, en el idioma de cada niño.",
    "infantil": false,
    "categoria": "ninos",
    "giros": []
  },
  {
    "id": "flota_piratas",
    "nombre": "Flota pirata",
    "genero": "flota",
    "idea": "Un juego de hundir la flota en {tema}: por turnos contra la máquina, encuentra y hunde sus barcos antes de que hunda los tuyos",
    "tema": "un mar de islas piratas",
    "por_que": "El clásico de papel y lápiz en el móvil: partidas de cinco minutos y un rival que aprende a cazar.",
    "infantil": false,
    "categoria": "estrategia",
    "giros": []
  },
  {
    "id": "simon_orquesta",
    "nombre": "La orquesta de colores",
    "genero": "simon",
    "idea": "Un juego de Simón dice en {tema}: los instrumentos se encienden en orden y hay que repetirlos, cada ronda uno más",
    "tema": "un escenario de músicos de colores",
    "por_que": "Memoria y oído en partidas de un minuto: engancha a niños y mayores.",
    "infantil": false,
    "categoria": "ninos",
    "giros": []
  },
  {
    "id": "estrategia_juguetes",
    "nombre": "La guerra de los juguetes",
    "genero": "estrategia",
    "idea": "Un juego de estrategia por turnos en {tema}: soldados, tanques y cañones de juguete; mueve tus tropas, captura ciudades y conquista el cuartel rival",
    "tema": "un cuarto de juegos gigante",
    "por_que": "Estrategia de verdad en partidas cortas: cada nivel un mapa y un rival que piensa.",
    "infantil": false,
    "categoria": "estrategia",
    "giros": []
  },
  {
    "id": "autobatalla_bestias",
    "nombre": "Liga de bestias",
    "genero": "autobatalla",
    "idea": "Un juego de batalla automática en {tema}: compra criaturas, junta tres iguales para hacerlas más fuertes y colócalas antes de cada combate",
    "tema": "un torneo de bestias mágicas",
    "por_que": "El género de Teamfight Tactics: decisiones rápidas, combates que se miran solos y muchísima rejugabilidad.",
    "infantil": false,
    "categoria": "estrategia",
    "giros": []
  },
  {
    "id": "gemas_guardianes",
    "nombre": "Guardianes de las gemas",
    "genero": "gemas",
    "idea": "Un juego de gemas y héroes en {tema}: combina gemas de colores para que tus héroes ataquen a oleadas de monstruos",
    "tema": "un reino de cristal",
    "por_que": "El puzle con combates de Empires & Puzzles: sencillo de tocar y con estrategia de colores y especiales.",
    "infantil": false,
    "categoria": "estrategia",
    "giros": []
  },
  {
    "id": "coleccionables_academia",
    "nombre": "Duelo en la academia",
    "genero": "coleccionables",
    "idea": "Un juego de cartas coleccionables en {tema}: duelos por turnos con esbirros, hechizos y maná contra rivales cada vez más listos",
    "tema": "una academia de magia",
    "por_que": "El duelo de cartas de Hearthstone en partidas de diez minutos: estrategia pura y mucha rejugabilidad.",
    "infantil": false,
    "categoria": "estrategia",
    "giros": []
  },
  {
    "id": "roguelike_cripta",
    "nombre": "La cripta sin fondo",
    "genero": "roguelike",
    "idea": "Un roguelike por turnos en {tema}: baja planta a planta con niebla, monstruos que despiertan, espadas, armaduras y un jefe que guarda la escalera",
    "tema": "una cripta embrujada",
    "por_que": "El enganche de Pixel Dungeon: cada paso cuenta, cada planta es nueva y siempre quieres bajar una mas.",
    "infantil": false,
    "categoria": "accion",
    "giros": []
  },
  {
    "id": "bombas_fabrica",
    "nombre": "Bombas en la fábrica",
    "genero": "bombas",
    "idea": "Un juego de bombas tipo Bomberman en {tema}: rompe cajas, encuentra más bombas y más alcance, atrapa a los monstruos en las llamas y escapa por la salida escondida",
    "tema": "una fábrica de juguetes",
    "por_que": "El clásico de las recreativas: reglas que se entienden en un segundo y partidas de dos minutos en las que siempre quieres una más.",
    "infantil": false,
    "categoria": "accion",
    "giros": []
  },
  {
    "id": "artilleria_patos",
    "nombre": "Patos con bazuca",
    "genero": "artilleria",
    "idea": "Una batalla de artillería por turnos tipo Worms en {tema}: apunta con el dedo, calcula el viento, abre cráteres en el terreno y tira al rival al agua",
    "tema": "una isla de patos piratas",
    "por_que": "El caos divertido de Worms: cada disparo es una apuesta, el terreno cambia y las partidas acaban siempre con risas.",
    "infantil": false,
    "categoria": "estrategia",
    "giros": []
  },
  {
    "id": "comecocos_dulces",
    "nombre": "Ladrón de caramelos",
    "genero": "comecocos",
    "idea": "Un comecocos en {tema}: cómete todos los caramelos del laberinto, esquiva a los guardianes y usa los caramelos gigantes para perseguirlos tú",
    "tema": "una fábrica de caramelos",
    "por_que": "El clásico que todo el mundo entiende en un segundo: tensión constante y la venganza de las píldoras.",
    "infantil": false,
    "categoria": "accion",
    "giros": []
  },
  {
    "id": "cadena_templo",
    "nombre": "El templo de las bolas",
    "genero": "cadena",
    "idea": "Una cadena de bolas tipo Zuma en {tema}: dispara bolas de colores, junta tres iguales y encadena combos antes de que la fila llegue al agujero",
    "tema": "un templo perdido en la selva",
    "por_que": "La tensión de Zuma: la cadena no para, cada disparo cuenta y los combos en cadena son pura satisfacción.",
    "infantil": false,
    "categoria": "puzle",
    "giros": []
  },
  {
    "id": "lucha_torneo",
    "nombre": "Torneo de los puños",
    "genero": "lucha",
    "idea": "Un juego de lucha uno contra uno tipo Street Fighter en {tema}: puños, patadas, cubrirse en el momento justo y un especial que se carga golpeando, contra rivales con su estilo",
    "tema": "un torneo de artes marciales en la azotea",
    "por_que": "La emoción de las recreativas de lucha: aprender a cubrirte y castigar al rival, combates cortos y siempre la revancha.",
    "infantil": false,
    "categoria": "accion",
    "giros": []
  },
  {
    "id": "sandia_huerto",
    "nombre": "El tarro del huerto",
    "genero": "sandia",
    "idea": "Un juego de fusionar frutas tipo sandía en {tema}: suelta frutas en el tarro, junta dos iguales para crear otra más grande y llega a la fruta objetivo sin que rebose",
    "tema": "un huerto de frutas con caras",
    "por_que": "El enganche del juego de la sandía: física que se entiende sola, cadenas de fusiones y siempre una partida más.",
    "infantil": false,
    "categoria": "puzle",
    "giros": []
  },
  {
    "id": "pinball_neon",
    "nombre": "Neón y palas",
    "genero": "pinball",
    "idea": "Un pinball en {tema}: mantén viva la bola con las dos palas, enciende setas, tumba dianas y multiplica la puntuación",
    "tema": "una sala de recreativas de neón",
    "por_que": "La adrenalina de las máquinas de pinball: reflejos, rebotes imposibles y la tensión de cada bola.",
    "infantil": false,
    "categoria": "accion",
    "giros": []
  },
  {
    "id": "metroidvania_ruinas",
    "nombre": "Las ruinas ocultas",
    "genero": "metroidvania",
    "idea": "Un metroidvania en {tema}: explora salas conectadas, consigue el doble salto, el impulso y el martillo, y vuelve a las puertas que antes no podías cruzar",
    "tema": "unas ruinas bajo la montaña",
    "por_que": "La magia de Hollow Knight y Metroid: cada habilidad nueva convierte un muro en un camino y el mapa se abre poco a poco.",
    "infantil": false,
    "categoria": "unicas",
    "giros": []
  },
  {
    "id": "sigilo_museo",
    "nombre": "Golpe en el museo",
    "genero": "sigilo",
    "idea": "Un juego de sigilo por turnos tipo Hitman GO en {tema}: muévete por los caminos, esquiva la mirada de los guardias, déjalos fuera por la espalda y escapa con el maletín",
    "tema": "un museo de noche",
    "por_que": "La elegancia de Hitman GO: cada tablero es un puzle de lógica pura y siempre hay una forma más limpia de resolverlo.",
    "infantil": false,
    "categoria": "puzle",
    "giros": []
  },
  {
    "id": "multitud_vikingos",
    "nombre": "Horda vikinga",
    "genero": "multitud",
    "idea": "Un count masters de {tema}: pasa por las puertas que multiplican tu grupo y llega al jefe con más gente",
    "tema": "vikingos contra trolls",
    "por_que": "El famoso anuncio de Last War convertido en juego: se entiende en un segundo y engancha.",
    "infantil": false,
    "categoria": "accion",
    "giros": []
  },
  {
    "id": "reino_helado",
    "nombre": "Reino helado",
    "genero": "reino",
    "idea": "Un reino tipo Kingshot en {tema}: sube tu ciudad, entrena tropas que no paran de crecer y conquista campamentos",
    "tema": "una tierra helada con yetis",
    "por_que": "Kingshot y Whiteout Survival están entre los que más facturan del mundo: tu ejército crece en tiempo real.",
    "infantil": false,
    "categoria": "estrategia",
    "giros": []
  },
  {
    "id": "tragaperras_piratas",
    "nombre": "Isla del tesoro",
    "genero": "tragaperras",
    "idea": "Un coin master de {tema}: tira en la tragaperras, gana doblones de mentira y construye tu isla",
    "tema": "piratas",
    "por_que": "Tipo Coin Master, de los que más facturan: cada tirada puede ser un premio y siempre hay algo que construir.",
    "infantil": false,
    "categoria": "unicas",
    "giros": []
  },
  {
    "id": "tycoon_dulces",
    "nombre": "Imperio dulce",
    "genero": "tycoon",
    "idea": "Un idle tycoon de {tema}: compra negocios, contrata gerentes y hazte rico mientras trabajan solos",
    "tema": "pastelerías y heladerías",
    "por_que": "Los tycoon idle enganchan durante meses: siempre hay algo que comprar y ganas hasta con el móvil apagado.",
    "infantil": false,
    "categoria": "estrategia",
    "giros": []
  },
  {
    "id": "tycoon_mina",
    "nombre": "Mina de oro",
    "genero": "tycoon",
    "idea": "Un idle miner de {tema}: pozos, ascensor y almacén que mejorar para que nada frene la producción",
    "tema": "enanos excavando gemas",
    "por_que": "Tipo Idle Miner Tycoon, de los más descargados: buscar el cuello de botella es muy adictivo.",
    "infantil": false,
    "categoria": "estrategia",
    "giros": [
      "mina"
    ]
  },
  {
    "id": "palabra_diaria",
    "nombre": "La palabra de hoy",
    "genero": "palabra",
    "idea": "Adivina la palabra de {tema} en seis intentos: cada letra te dice si está y si está en su sitio",
    "tema": "cada día",
    "por_que": "El juego de palabras más compartido del mundo: un ratito al día y vuelves mañana.",
    "infantil": false,
    "categoria": "relax",
    "giros": []
  },
  {
    "id": "letras_viaje",
    "nombre": "Palabras viajeras",
    "genero": "letras",
    "idea": "Une las letras de la rueda para formar palabras y completar crucigramas mientras viajas por {tema}",
    "tema": "las ciudades del mundo",
    "por_que": "Los juegos de rueda de letras están siempre arriba en Play: relajan y enganchan nivel a nivel.",
    "infantil": false,
    "categoria": "puzle",
    "giros": []
  },
  {
    "id": "sudoku_clasico",
    "nombre": "Sudoku zen",
    "genero": "sudoku",
    "idea": "Sudokus que crecen de 4x4 a 9x9 con un ambiente de {tema}: pistas, vidas y solución única siempre",
    "tema": "café tranquilo con lluvia",
    "por_que": "El sudoku es de los puzles más jugados del mundo: partidas cortas para entrenar la mente.",
    "infantil": false,
    "categoria": "puzle",
    "giros": []
  },
  {
    "id": "sudoku_peques",
    "nombre": "Mini sudoku",
    "genero": "sudoku",
    "idea": "Sudokus pequeños de 4x4 y 6x6 con {tema} para aprender a pensar con números",
    "tema": "animalitos del bosque",
    "por_que": "Tableros pequeños y colores alegres: lógica para peques sin agobios.",
    "infantil": true,
    "categoria": "ninos",
    "giros": []
  },
  {
    "id": "pixel_secreto",
    "nombre": "Pixel secreto",
    "genero": "nonograma",
    "idea": "Nonogramas tipo Picross: pinta las casillas que dicen las pistas y descubre dibujos de {tema}",
    "tema": "un museo de pixel art",
    "por_que": "Cada puzle termina con un dibujo: la recompensa perfecta para un juego de lógica.",
    "infantil": false,
    "categoria": "puzle",
    "giros": []
  },
  {
    "id": "fruta_ninja",
    "nombre": "Ninja de la fruta",
    "genero": "cortar",
    "idea": "Un {tema} corta fruta lanzada al aire con su espada: combos, fruta dorada y bombas que hay que esquivar",
    "tema": "ninja panda",
    "por_que": "Deslizar y cortar es de lo más satisfactorio en una pantalla táctil.",
    "infantil": false,
    "categoria": "accion",
    "giros": []
  },
  {
    "id": "tanda_penaltis",
    "nombre": "Rey del penalti",
    "genero": "penaltis",
    "idea": "Tanda de penaltis en un estadio de {tema}: desliza para chutar, lee al portero, supera barreras y acierta en las dianas",
    "tema": "liga de animales",
    "por_que": "El fútbol es el deporte más jugado en móvil, y un penalti se entiende en un segundo.",
    "infantil": false,
    "categoria": "accion",
    "giros": []
  },
  {
    "id": "penaltis_mundial",
    "nombre": "Final del mundial",
    "genero": "penaltis",
    "idea": "Una final por {tema} decidida en los penaltis: porteros cada vez más listos que te engañan",
    "tema": "la copa de las estrellas",
    "por_que": "Porteros que amagan y barreras: cada tiro es una decisión con tensión.",
    "infantil": false,
    "categoria": "unicas",
    "giros": []
  },
  {
    "id": "agujero_ciudad",
    "nombre": "El agujero glotón",
    "genero": "agujero",
    "idea": "Un agujero que se traga una {tema}: empieza con conos y gente, sigue con coches y acaba con los edificios",
    "tema": "ciudad de juguete",
    "por_que": "Los juegos tipo Hole.io enganchan por la sensación de crecer sin parar en partidas de un minuto.",
    "infantil": false,
    "categoria": "accion",
    "giros": []
  },
  {
    "id": "alcalde_isla",
    "nombre": "Alcalde de la isla",
    "genero": "ciudad",
    "idea": "Construye una {tema}: calles, casas, tiendas, fábricas y parques; haz feliz a la gente para que lleguen más",
    "tema": "ciudad en una isla tropical",
    "por_que": "Los constructores de ciudades tipo Pocket City dan horas de juego: planificar y ver crecer tu ciudad.",
    "infantil": false,
    "categoria": "estrategia",
    "giros": []
  },
  {
    "id": "bola_espiral",
    "nombre": "Bola en espiral",
    "genero": "espiral",
    "idea": "Una bola que baja por una {tema} en espiral: gira la torre, cae por los huecos y esquiva las zonas rojas",
    "tema": "torre de caramelo",
    "por_que": "Helix Jump fue de los juegos más descargados: un dedo, una regla y ganas de bajar un piso más.",
    "infantil": false,
    "categoria": "accion",
    "giros": []
  },
  {
    "id": "canasta_callejera",
    "nombre": "Canasta callejera",
    "genero": "canasta",
    "idea": "Tiros a canasta en una {tema}: aros que se mueven, triples desde la esquina y viento que desvía el balón",
    "tema": "cancha del barrio",
    "por_que": "Lanzar deslizando el dedo es muy natural en el móvil y cada tiro es un pequeño reto.",
    "infantil": false,
    "categoria": "accion",
    "giros": []
  },
  {
    "id": "buscaminas_jardin",
    "nombre": "Buscaminas del jardín",
    "genero": "buscaminas",
    "idea": "Un buscaminas en un {tema}: abre casillas con lógica y marca las trampas, sin tener que adivinar nunca",
    "tema": "jardín lleno de topos traviesos",
    "por_que": "El buscaminas es un clásico; sin casillas al azar, cada derrota es culpa tuya y engancha más.",
    "infantil": false,
    "categoria": "puzle",
    "giros": []
  },
  {
    "id": "conecta_duelo",
    "nombre": "Duelo de cuatro",
    "genero": "conecta",
    "idea": "Conecta 4 contra rivales {tema} cada vez más listos: piensa jugadas, bloquea y haz cuatro en raya",
    "tema": "piratas",
    "por_que": "Los juegos de mesa contra la máquina son de lo más descargado: partidas cortas y rivales que aprenden.",
    "infantil": false,
    "categoria": "estrategia",
    "giros": []
  },
  {
    "id": "damas_castillo",
    "nombre": "Damas del castillo",
    "genero": "damas",
    "idea": "Damas contra los {tema}: primero partidas cortas con pocas fichas y luego el tablero entero contra rivales más listos",
    "tema": "caballeros del rey",
    "por_que": "Los juegos de mesa clásicos contra la máquina tienen millones de jugadores fieles.",
    "infantil": false,
    "categoria": "estrategia",
    "giros": []
  },
  {
    "id": "billar_neon",
    "nombre": "Billar neón",
    "genero": "billar",
    "idea": "Retos de billar en un {tema}: mete todas las bolas en pocos tiros calculando ángulo y fuerza",
    "tema": "club de billar con luces de neón",
    "por_que": "El billar en el móvil engancha: cada tiro es física pura y se entiende al momento.",
    "infantil": false,
    "categoria": "accion",
    "giros": []
  },
  {
    "id": "solitario_clasico",
    "nombre": "Solitario de siempre",
    "genero": "solitario",
    "idea": "El solitario clásico con cartas de {tema}: repartos que siempre tienen solución y pistas si te atascas",
    "tema": "un tapete verde y elegante",
    "por_que": "El solitario es de los juegos más jugados del mundo, a cualquier edad.",
    "infantil": false,
    "categoria": "relax",
    "giros": []
  },
  {
    "id": "parchis_familia",
    "nombre": "Parchís de la familia",
    "genero": "parchis",
    "idea": "Parchís contra {tema}: tira el dado, come fichas y llega a casa antes que nadie",
    "tema": "los abuelos del pueblo",
    "por_que": "Ludo y parchís están entre los juegos de mesa más descargados: partidas rápidas y mucha emoción con el dado.",
    "infantil": false,
    "categoria": "relax",
    "giros": []
  },
  {
    "id": "bloques_neon",
    "nombre": "Bloques de neón",
    "genero": "caida",
    "idea": "El clásico de piezas que caen en un {tema}: gira, encaja y borra filas cada vez más rápido",
    "tema": "salón recreativo de neón",
    "por_que": "Las piezas que caen son uno de los juegos más jugados de la historia: reglas que todo el mundo conoce.",
    "infantil": false,
    "categoria": "puzle",
    "giros": []
  },
  {
    "id": "bolos_bolera",
    "nombre": "Noche de bolos",
    "genero": "bolos",
    "idea": "Bolos en una {tema}: desliza con efecto, esquiva el aceite y las barreras y consigue strikes",
    "tema": "bolera retro de los 80",
    "por_que": "Lanzar deslizando con efecto es muy satisfactorio en una pantalla táctil.",
    "infantil": false,
    "categoria": "accion",
    "giros": []
  },
  {
    "id": "mundo_bloques",
    "nombre": "Mundo de bloques",
    "genero": "mundo",
    "idea": "Un mundo abierto de {tema}: pica bloques, fabrica herramientas, baja a las minas y sobrevive a la noche",
    "tema": "islas flotantes y cuevas de cristal",
    "por_que": "Explorar, fabricar y construir a tu manera es lo que más horas engancha en móvil.",
    "infantil": false,
    "categoria": "accion",
    "giros": []
  },
  {
    "id": "royale_isla",
    "nombre": "Isla de los 30",
    "genero": "royale",
    "idea": "Un battle royale desde arriba en una isla de {tema}: salta del avión, busca armas y sé el último en pie",
    "tema": "pueblos de pescadores y bosques",
    "por_que": "El género más jugado en móvil: cada partida es distinta y siempre quieres una más.",
    "infantil": false,
    "categoria": "accion",
    "giros": []
  },
  {
    "id": "cruzar_granja",
    "nombre": "Cruza la granja",
    "genero": "cruzar",
    "idea": "Un juego de cruzar con {tema}: salta carreteras, ríos con troncos y vías de tren hasta la meta",
    "tema": "un pollito valiente que vuelve a su granja",
    "por_que": "Un toque para saltar y siempre «uno más»: de los arcade más jugados en móvil.",
    "infantil": false,
    "categoria": "accion",
    "giros": []
  },
  {
    "id": "arco_bosque",
    "nombre": "Arquera del bosque",
    "genero": "arco",
    "idea": "Tiro con arco en {tema}: dianas que se mueven, viento y globos que dan flechas",
    "tema": "un bosque encantado con luciérnagas",
    "por_que": "Apuntar y soltar es muy satisfactorio: cada diana perfecta engancha.",
    "infantil": false,
    "categoria": "accion",
    "giros": []
  },
  {
    "id": "cubos_islas",
    "nombre": "Islas de cubos",
    "genero": "cubos",
    "idea": "Un mundo de cubos en 3D de {tema}: pica, construye tu casa y fabrica herramientas hasta la corona",
    "tema": "praderas, montañas y cuevas con cristales",
    "por_que": "Construir en 3D a tu manera es de lo que más horas engancha: el mundo se guarda entre partidas.",
    "infantil": false,
    "categoria": "accion",
    "giros": []
  },
  {
    "id": "parkour_cielo",
    "nombre": "Parkour en el cielo",
    "genero": "parkour",
    "idea": "Un parkour 3D entre {tema}: plataformas que se mueven, barras que giran y lava hasta la meta",
    "tema": "islas de colores sobre las nubes",
    "por_que": "Los obby de saltos son de lo más jugado por los jóvenes: retos cortos y «uno más».",
    "infantil": false,
    "categoria": "accion",
    "giros": []
  },
  {
    "id": "tienda_barrio",
    "nombre": "Mi súper",
    "genero": "tienda",
    "idea": "Un simulador de supermercado 3D en {tema}: repone, cobra, contrata ayuda y abre productos nuevos",
    "tema": "un barrio con mucha vida",
    "por_que": "Los simuladores de tienda tipo «idle arcade» están entre los más descargados: progreso constante y relajante.",
    "infantil": false,
    "categoria": "estrategia",
    "giros": []
  },
  {
    "id": "futbol_barrio",
    "nombre": "Fútbol de barrio",
    "genero": "futbol",
    "idea": "Fútbol arcade 3D de {tema}: partidos rápidos de tres contra tres hasta ganar la copa",
    "tema": "equipos de animales en un estadio de colores",
    "por_que": "El deporte es la categoría que más crece en Google Play y el fútbol el más jugado.",
    "infantil": false,
    "categoria": "accion",
    "giros": []
  },
  {
    "id": "terror_mansion",
    "nombre": "La mansión",
    "genero": "terror",
    "idea": "Terror en 3D en {tema}: busca las llaves con la linterna y escapa sin que te atrape",
    "tema": "una mansión abandonada en el bosque",
    "por_que": "El terror es de lo que más se juega y se comparte en vídeos: cada partida da un susto nuevo.",
    "infantil": false,
    "categoria": "unicas",
    "giros": []
  },
  {
    "id": "conduccion_pizzas",
    "nombre": "Pizza exprés",
    "genero": "conduccion",
    "idea": "Conducción 3D por {tema}: recoge las pizzas y entrégalas calientes antes de que se acabe el tiempo",
    "tema": "una ciudad llena de tráfico",
    "por_que": "Los juegos de conducir por la ciudad están entre los simuladores más descargados.",
    "infantil": false,
    "categoria": "accion",
    "giros": []
  },
  {
    "id": "zombis_ciudad",
    "nombre": "Última noche",
    "genero": "zombis",
    "idea": "Shooter 3D de zombis en {tema}: aguanta las oleadas con pistola, escopeta y fusil",
    "tema": "una ciudad en ruinas al atardecer",
    "por_que": "Los shooters de zombis en primera persona están entre los juegos de acción más descargados.",
    "infantil": false,
    "categoria": "accion",
    "giros": []
  },
  {
    "id": "baloncesto_barrio",
    "nombre": "Rey de la pista",
    "genero": "baloncesto",
    "idea": "Baloncesto 3D en {tema}: gana los partidos callejeros de 1 contra 1 a 3 contra 3",
    "tema": "la pista del barrio",
    "por_que": "El baloncesto callejero es de los deportes más jugados en el móvil: partidos cortos y con jugadas que se comparten.",
    "infantil": false,
    "categoria": "accion",
    "giros": []
  },
  {
    "id": "tenis_final",
    "nombre": "La gran final",
    "genero": "tenis",
    "idea": "Tenis 3D en {tema}: gana partido a partido hasta la final",
    "tema": "un torneo de verano en la playa",
    "por_que": "Los juegos de tenis para el móvil tienen millones de jugadores: partidos cortos y fáciles de entender.",
    "infantil": false,
    "categoria": "accion",
    "giros": []
  },
  {
    "id": "karts_volcan",
    "nombre": "Gran Premio",
    "genero": "karts",
    "idea": "Carreras de karts en 3D por {tema}: derrapa en las curvas, coge los turbos y gana a los rivales",
    "tema": "un circuito entre colinas",
    "por_que": "Las carreras de karts son de los juegos de carreras más descargados: partidas cortas y muy rejugables.",
    "infantil": false,
    "categoria": "accion",
    "giros": []
  },
  {
    "id": "arena_robots",
    "nombre": "Todos contra todos",
    "genero": "arena",
    "idea": "Todos contra todos en una arena de {tema} chatarreros: el último en pie gana",
    "tema": "robots",
    "por_que": "Partidas rápidas, online en directo y con amigos: lo que más se comparte.",
    "infantil": false,
    "categoria": "accion",
    "giros": []
  },
  {
    "id": "gemas_bosque",
    "nombre": "Combina 3 mágico",
    "genero": "puzle",
    "idea": "Un puzle de combinar gemas en un bosque mágico de {tema}",
    "tema": "hadas",
    "por_que": "El género que más dinero da en móviles: relajante, para todas las edades y con mucho que mejorar.",
    "infantil": false,
    "categoria": "puzle",
    "giros": []
  },
  {
    "id": "torres_castillo",
    "nombre": "Defiende el castillo",
    "genero": "torres",
    "idea": "Defiende tu castillo de oleadas de {tema} con torres",
    "tema": "monstruos",
    "por_que": "Pensar dónde poner cada torre engancha: cada nivel es un pequeño rompecabezas.",
    "infantil": false,
    "categoria": "estrategia",
    "giros": []
  },
  {
    "id": "imperio_pasteles",
    "nombre": "Imperio que crece",
    "genero": "clicker",
    "idea": "Un clicker idle donde construyes un imperio de {tema}",
    "tema": "pasteles",
    "por_que": "Ver crecer los números es adictivo y se juega a ratos: ideal para anuncios con premio.",
    "infantil": false,
    "categoria": "relax",
    "giros": []
  },
  {
    "id": "solitario_pirata",
    "nombre": "Solitario tranquilo",
    "genero": "cartas",
    "idea": "Un solitario de cartas en un casino {tema}",
    "tema": "pirata",
    "por_que": "Juego de mente para adultos que se juega cada día: muy buena retención.",
    "infantil": false,
    "categoria": "relax",
    "giros": []
  },
  {
    "id": "caballeros_rpg",
    "nombre": "Aventura por turnos",
    "genero": "rpg",
    "idea": "Un rpg por turnos de {tema} contra los monstruos de la cueva",
    "tema": "caballeros",
    "por_que": "Decidir cada golpe y vencer al jefe da mucha satisfacción; encaja con el pase de temporada.",
    "infantil": false,
    "categoria": "estrategia",
    "giros": []
  },
  {
    "id": "ritmo_selva",
    "nombre": "Ritmo salvaje",
    "genero": "ritmo",
    "idea": "Un juego de ritmo musical con tambores en una selva de {tema}",
    "tema": "monos",
    "por_que": "Música y reflejos: se comparte en vídeos cortos y gusta a todas las edades.",
    "infantil": false,
    "categoria": "accion",
    "giros": []
  },
  {
    "id": "granja_peques",
    "nombre": "Memoria para peques",
    "genero": "memoria",
    "idea": "Un juego de memoria con {tema} de la granja para peques",
    "tema": "animales",
    "por_que": "Para niños: sin compras ni nada online, como exige Google para el público infantil.",
    "infantil": true,
    "categoria": "ninos",
    "giros": []
  },
  {
    "id": "topos_huerto",
    "nombre": "Aplasta topos",
    "genero": "topos",
    "idea": "Aplasta a los {tema} traviesos que asoman en el huerto",
    "tema": "topos",
    "por_que": "Reflejos y risas para los más pequeños, en versión segura para niños.",
    "infantil": true,
    "categoria": "ninos",
    "giros": []
  },
  {
    "id": "trivial_planetas",
    "nombre": "Trivial que enseña",
    "genero": "preguntas",
    "idea": "Un trivial de preguntas sobre {tema} para toda la familia",
    "tema": "los planetas",
    "por_que": "Aprender jugando: lo usan familias y colegios, y la IA escribe las preguntas.",
    "infantil": false,
    "categoria": "puzle",
    "giros": []
  },
  {
    "id": "minigolf_playa",
    "nombre": "Minigolf relajado",
    "genero": "golf",
    "idea": "Un minigolf de hoyos locos en una playa de {tema}",
    "tema": "cangrejos",
    "por_que": "Un dedo, partidas de 2 minutos y mucho «uno más»: gusta a todas las edades.",
    "infantil": false,
    "categoria": "relax",
    "giros": []
  },
  {
    "id": "pesca_lago",
    "nombre": "Pesca a tiempo",
    "genero": "pesca",
    "idea": "Un juego de pesca en un lago de montaña con un {tema} pescador",
    "tema": "oso",
    "por_que": "Tranquilo pero con reflejos: perfecto para ratos cortos y para compartir récords.",
    "infantil": false,
    "categoria": "relax",
    "giros": []
  },
  {
    "id": "laberinto_piramide",
    "nombre": "Laberinto de llaves",
    "genero": "laberinto",
    "idea": "Un laberinto dentro de una pirámide con un {tema} explorador que busca llaves y monedas",
    "tema": "gato",
    "por_que": "Pensar el camino engancha y cada nivel se resuelve en un minuto.",
    "infantil": false,
    "categoria": "puzle",
    "giros": []
  },
  {
    "id": "fusion_pociones",
    "nombre": "Fusiona y crece",
    "genero": "fusion",
    "idea": "Un juego de fusionar {tema} iguales hasta crear la más grande",
    "tema": "pociones mágicas",
    "por_que": "El estilo «merge» de las listas de éxitos: sencillo de aprender y muy adictivo.",
    "infantil": false,
    "categoria": "puzle",
    "giros": []
  },
  {
    "id": "pajaro_papel",
    "nombre": "Vuela de un toque",
    "genero": "volador",
    "idea": "Un {tema} de papel que vuela entre columnas con un solo toque",
    "tema": "pájaro",
    "por_que": "Un toque, una regla y el «una más» de siempre: de los formatos más virales en móviles.",
    "infantil": false,
    "categoria": "accion",
    "giros": []
  },
  {
    "id": "rana_nenufares",
    "nombre": "Salta hasta la cima",
    "genero": "saltos",
    "idea": "Una {tema} que sube saltando de nenúfar en nenúfar hasta la cima de una cascada",
    "tema": "rana",
    "por_que": "Subir sin parar inclinando el móvil o con toques: partidas cortas y récords que picar.",
    "infantil": false,
    "categoria": "accion",
    "giros": []
  },
  {
    "id": "karts_desierto",
    "nombre": "Carreras locas",
    "genero": "carreras",
    "idea": "Carreras de karts de {tema} por un desierto con turbos y atajos",
    "tema": "animales",
    "por_que": "Adelantar en la última curva se siente genial; las carreras gustan a todas las edades.",
    "infantil": false,
    "categoria": "accion",
    "giros": []
  },
  {
    "id": "naves_gominola",
    "nombre": "Matamarcianos clásico",
    "genero": "naves",
    "idea": "Tu nave contra una invasión de {tema} de colores",
    "tema": "marcianos de gominola",
    "por_que": "El arcade de toda la vida: se entiende en un segundo y la dificultad sube sola.",
    "infantil": false,
    "categoria": "accion",
    "giros": []
  },
  {
    "id": "hordas_cementerio",
    "nombre": "Sobrevive a la horda",
    "genero": "horda",
    "idea": "Sobrevive a oleadas de {tema} en un cementerio y sube de nivel tus poderes",
    "tema": "zombis",
    "por_que": "Los «survivors» son de lo más descargado: cada partida sube de nivel y nunca es igual.",
    "infantil": false,
    "categoria": "accion",
    "giros": []
  },
  {
    "id": "ladrillos_caramelo",
    "nombre": "Rompe ladrillos",
    "genero": "rompebloques",
    "idea": "Rompe los ladrillos de un castillo de {tema} con una pelota y una pala",
    "tema": "caramelo",
    "por_que": "Romper cosas relaja: un clásico que funciona con cualquier tema.",
    "infantil": false,
    "categoria": "accion",
    "giros": []
  },
  {
    "id": "bloques_jardin",
    "nombre": "Encaja bloques",
    "genero": "bloques",
    "idea": "Encaja bloques de {tema} en un tablero hasta completar filas y columnas",
    "tema": "flores",
    "por_que": "Los puzles de bloques sin prisa son de los más jugados por adultos cada día.",
    "infantil": false,
    "categoria": "puzle",
    "giros": []
  },
  {
    "id": "pociones_tubos",
    "nombre": "Ordena las pociones",
    "genero": "tubos",
    "idea": "Un puzle de ordenar {tema} de colores en tubos hasta que cada tubo tenga un solo color",
    "tema": "pociones",
    "por_que": "El «water sort» está siempre entre los puzles más descargados: relajante, se entiende sin explicar nada.",
    "infantil": false,
    "categoria": "puzle",
    "giros": []
  },
  {
    "id": "burbujas_hadas",
    "nombre": "Lanza burbujas",
    "genero": "burbujas",
    "idea": "Un lanza burbujas de colores en un bosque de {tema}: apunta, junta tres y haz caer los racimos",
    "tema": "hadas",
    "por_que": "El bubble shooter es un clásico que no pasa de moda: apuntar y ver caer medio tablero engancha a todas las edades.",
    "infantil": false,
    "categoria": "puzle",
    "giros": []
  },
  {
    "id": "cajas_regalos",
    "nombre": "Empuja las cajas",
    "genero": "cajas",
    "idea": "Un {tema} que empuja cajas de regalos hasta su sitio en un almacén",
    "tema": "elfo",
    "por_que": "Puzles de pensar con solución comprobada: cada nivel es un pequeño «¡ajá!».",
    "infantil": false,
    "categoria": "puzle",
    "giros": []
  },
  {
    "id": "serpiente_huerto",
    "nombre": "Serpiente golosa",
    "genero": "serpiente",
    "idea": "Una serpiente que come {tema} en un huerto y crece sin chocar con su cola",
    "tema": "fresas",
    "por_que": "El clásico de los móviles de siempre, con niveles y obstáculos nuevos.",
    "infantil": false,
    "categoria": "accion",
    "giros": []
  },
  {
    "id": "tarta_cielo",
    "nombre": "Apila hasta el cielo",
    "genero": "apilar",
    "idea": "Apila pisos de {tema} hasta el cielo sin que se caiga la torre",
    "tema": "tarta",
    "por_que": "Un toque en el momento justo: hipnótico, rápido y perfecto para anuncios con premio.",
    "infantil": false,
    "categoria": "relax",
    "giros": []
  },
  {
    "id": "mazmorra_pixel",
    "nombre": "Mazmorra con reto",
    "genero": "plataformas",
    "idea": "Un {tema} que baja por una mazmorra llena de pinchos y trampas hasta el jefe final",
    "tema": "caballero",
    "por_que": "Para quien busca reto: niveles exigentes pero justos (los bots los superan antes de entregarlos).",
    "infantil": false,
    "categoria": "accion",
    "giros": []
  },
  {
    "id": "runner_espacio",
    "nombre": "Huida espacial",
    "genero": "runner",
    "idea": "Un {tema} astronauta que corre sin parar por una estación espacial esquivando meteoritos",
    "tema": "perro",
    "por_que": "El espacio vende: mismo runner adictivo con otro aire.",
    "infantil": false,
    "categoria": "accion",
    "giros": []
  },
  {
    "id": "puzle_dulces",
    "nombre": "Combina dulces",
    "genero": "puzle",
    "idea": "Un puzle de combinar 3 {tema} en una pastelería",
    "tema": "caramelos",
    "por_que": "El combina 3 de dulces es el formato más reconocible de las tiendas.",
    "infantil": false,
    "categoria": "puzle",
    "giros": []
  },
  {
    "id": "torres_granja",
    "nombre": "Defiende la granja",
    "genero": "torres",
    "idea": "Defiende las zanahorias de la granja de oleadas de {tema} con torres",
    "tema": "conejos glotones",
    "por_que": "Tower defense amable para todos los públicos: estrategia sin agobios.",
    "infantil": false,
    "categoria": "estrategia",
    "giros": []
  },
  {
    "id": "magos_rpg",
    "nombre": "Escuela de magos",
    "genero": "rpg",
    "idea": "Un rpg por turnos de {tema} aprendices contra criaturas del bosque encantado",
    "tema": "magos",
    "por_que": "Combates por turnos con hechizos: estrategia tranquila que se juega con una mano.",
    "infantil": false,
    "categoria": "estrategia",
    "giros": []
  },
  {
    "id": "clicker_espacio",
    "nombre": "Imperio galáctico",
    "genero": "clicker",
    "idea": "Un clicker idle donde construyes una colonia de {tema} en Marte",
    "tema": "robots",
    "por_que": "Progreso aunque no juegues: la gente vuelve cada día a ver cuánto ha crecido.",
    "infantil": false,
    "categoria": "relax",
    "giros": []
  },
  {
    "id": "cartas_noche",
    "nombre": "Solitario nocturno",
    "genero": "cartas",
    "idea": "Un solitario de cartas relajante en una cabaña de {tema} bajo las estrellas",
    "tema": "montaña",
    "por_que": "Para desconectar antes de dormir: el público adulto de los solitarios juega todos los días.",
    "infantil": false,
    "categoria": "relax",
    "giros": []
  },
  {
    "id": "trivial_cine",
    "nombre": "Trivial de cine",
    "genero": "preguntas",
    "idea": "Un trivial de preguntas sobre {tema} para jugar con amigos",
    "tema": "el cine y las series",
    "por_que": "Las preguntas de cultura general se comparten y se juegan en grupo.",
    "infantil": false,
    "categoria": "puzle",
    "giros": []
  },
  {
    "id": "ritmo_espacial",
    "nombre": "Ritmo galáctico",
    "genero": "ritmo",
    "idea": "Un juego de ritmo con notas de neón en una discoteca de {tema} en el espacio",
    "tema": "aliens",
    "por_que": "Música y luces: queda genial en vídeos cortos para redes.",
    "infantil": false,
    "categoria": "accion",
    "giros": []
  },
  {
    "id": "dinos_memoria",
    "nombre": "Memoria de dinosaurios",
    "genero": "memoria",
    "idea": "Un juego de memoria con {tema} simpáticos para peques",
    "tema": "dinosaurios",
    "por_que": "Los dinosaurios encantan a los niños: memoria y atención jugando.",
    "infantil": true,
    "categoria": "ninos",
    "giros": []
  },
  {
    "id": "pesca_peques",
    "nombre": "Pesca para peques",
    "genero": "pesca",
    "idea": "Pesca peces de colores en un estanque con un {tema} amable",
    "tema": "pato",
    "por_que": "Un toque y mucho color: reflejos suaves para los más pequeños.",
    "infantil": true,
    "categoria": "ninos",
    "giros": []
  },
  {
    "id": "golf_peques",
    "nombre": "Minigolf de juguete",
    "genero": "golf",
    "idea": "Un minigolf en un cuarto de {tema} de juguete",
    "tema": "peluches",
    "por_que": "Apuntar y soltar: fácil de aprender para niños y divertido de ver.",
    "infantil": true,
    "categoria": "ninos",
    "giros": []
  },
  {
    "id": "laberinto_serpiente",
    "nombre": "Laberinto serpiente",
    "genero": "laberinto",
    "idea": "Un {tema} que recorre un laberinto donde cada paso cierra el camino detrás de él",
    "tema": "gusano",
    "por_que": "Mezcla de laberinto y serpiente: hay que pensar el camino entero antes de moverse.",
    "infantil": false,
    "categoria": "unicas",
    "giros": [
      "cola"
    ]
  },
  {
    "id": "golf_monstruos",
    "nombre": "Golf de monstruos",
    "genero": "golf",
    "idea": "Un minigolf en un castillo encantado donde derribas {tema} a bolazos para abrir el hoyo",
    "tema": "fantasmas",
    "por_que": "Minigolf con un toque de RPG: cada golpe es un pequeño plan.",
    "infantil": false,
    "categoria": "unicas",
    "giros": [
      "monstruos"
    ]
  },
  {
    "id": "cajas_hielo",
    "nombre": "Cajas sobre hielo",
    "genero": "cajas",
    "idea": "Un {tema} que empuja bloques de hielo que resbalan hasta chocar en una cueva helada",
    "tema": "pingüino",
    "por_que": "El puzle de cajas con suelo de hielo: piensas dónde se va a parar cada bloque.",
    "infantil": false,
    "categoria": "unicas",
    "giros": [
      "hielo"
    ]
  },
  {
    "id": "serpiente_tuneles",
    "nombre": "Serpiente de túneles",
    "genero": "serpiente",
    "idea": "Una serpiente de {tema} que cruza túneles: sale por un borde y entra por el otro",
    "tema": "neón",
    "por_que": "La serpiente de siempre con atajos por los bordes: rutas nuevas en cada nivel.",
    "infantil": false,
    "categoria": "unicas",
    "giros": [
      "tuneles"
    ]
  },
  {
    "id": "memoria_inquieta",
    "nombre": "Cartas traviesas",
    "genero": "memoria",
    "idea": "Un juego de memoria con cartas de {tema} traviesas que se cambian de sitio",
    "tema": "monstruos",
    "por_que": "Memoria con trampa: cada dos fallos dos cartas se cambian a la vista. Hay que estar atento.",
    "infantil": false,
    "categoria": "unicas",
    "giros": [
      "barajar"
    ]
  },
  {
    "id": "topos_oro",
    "nombre": "Mina de oro",
    "genero": "topos",
    "idea": "Aplasta a los {tema} que asoman en una mina; los de oro valen triple",
    "tema": "topos mineros",
    "por_que": "Reflejos con premio gordo: el bicho de oro se va antes pero vale 3 golpes.",
    "infantil": false,
    "categoria": "unicas",
    "giros": [
      "dorado"
    ]
  },
  {
    "id": "pesca_tormenta",
    "nombre": "Pesca en la tormenta",
    "genero": "pesca",
    "idea": "Un {tema} pescando en alta mar durante una tormenta: los peces van cada vez más rápido",
    "tema": "marinero",
    "por_que": "Pesca con tensión creciente: la lluvia acelera a los peces según pasa el tiempo.",
    "infantil": false,
    "categoria": "unicas",
    "giros": [
      "tormenta"
    ]
  },
  {
    "id": "golf_viento",
    "nombre": "Golf con viento",
    "genero": "golf",
    "idea": "Un minigolf en los acantilados de {tema} con viento que empuja la bola",
    "tema": "una isla",
    "por_que": "Cada hoyo con su viento: apuntar contando con él es un reto nuevo.",
    "infantil": false,
    "categoria": "unicas",
    "giros": [
      "viento"
    ]
  },
  {
    "id": "fusion_piedras",
    "nombre": "Fusión entre rocas",
    "genero": "fusion",
    "idea": "Fusiona {tema} iguales en una cantera llena de rocas que se rompen al fusionar al lado",
    "tema": "gemas",
    "por_que": "El merge de siempre con obstáculos: romper las rocas en el momento justo.",
    "infantil": false,
    "categoria": "unicas",
    "giros": [
      "piedras"
    ]
  },
  {
    "id": "tejados_oscuros",
    "nombre": "Saltos a oscuras",
    "genero": "plataformas",
    "idea": "Un {tema} con una linterna que salta por una mina abandonada a oscuras",
    "tema": "minero",
    "por_que": "Solo ves lo que alumbra tu linterna: tensión y sorpresa en cada salto.",
    "infantil": false,
    "categoria": "unicas",
    "giros": [
      "oscuridad"
    ]
  },
  {
    "id": "runner_fantasma",
    "nombre": "Carrera contra ti",
    "genero": "runner",
    "idea": "Un {tema} que corre contra su propio fantasma: la figura repite tu mejor carrera",
    "tema": "zorro",
    "por_que": "Ganarte a ti mismo engancha: siempre hay un récord que batir a la vista.",
    "infantil": false,
    "categoria": "unicas",
    "giros": [
      "fantasma"
    ]
  },
  {
    "id": "laberinto_reloj",
    "nombre": "Laberinto contrarreloj",
    "genero": "laberinto",
    "idea": "Escapa de un laberinto de {tema} antes de que se acabe el tiempo",
    "tema": "hielo",
    "por_que": "Pensar rápido: el reloj convierte cada laberinto en una carrera.",
    "infantil": false,
    "categoria": "unicas",
    "giros": [
      "contrarreloj"
    ]
  },
  {
    "id": "ritmo_ciego",
    "nombre": "Ritmo a ciegas",
    "genero": "ritmo",
    "idea": "Un juego de ritmo en una discoteca de {tema} donde las notas se apagan antes de llegar",
    "tema": "robots",
    "por_que": "Ritmo para expertos: las notas desaparecen y se toca de memoria. Ideal para retar a amigos.",
    "infantil": false,
    "categoria": "unicas",
    "giros": [
      "invisibles"
    ]
  },
  {
    "id": "vuelo_espejo",
    "nombre": "Vuelo al revés",
    "genero": "volador",
    "idea": "Un {tema} que vuela por un mundo espejo donde todo se ve al revés",
    "tema": "murciélago",
    "por_que": "Un toque y el mundo del revés: confunde y engancha a la vez.",
    "infantil": false,
    "categoria": "unicas",
    "giros": [
      "espejo"
    ]
  },
  {
    "id": "aula_tablas",
    "nombre": "Tablas de multiplicar",
    "genero": "preguntas",
    "idea": "Preguntas de las tablas de multiplicar del {tema}: un cohete sube un poco hacia la Luna con cada acierto",
    "tema": "1 al 10",
    "por_que": "Repasar las tablas sin que parezca deberes; con el modo clase ves quién ha llegado al final.",
    "infantil": false,
    "categoria": "aula",
    "giros": []
  },
  {
    "id": "aula_capitales",
    "nombre": "Capitales del mundo",
    "genero": "preguntas",
    "idea": "Un trivial de capitales y banderas de {tema} con un avión que viaja de país en país",
    "tema": "Europa",
    "por_que": "Geografía en partidas de 5 minutos; cada nivel, un grupo de países.",
    "infantil": false,
    "categoria": "aula",
    "giros": []
  },
  {
    "id": "aula_vocabulario",
    "nombre": "Vocabulario en globos",
    "genero": "ahorcado",
    "idea": "Un ahorcado con globos para repasar el vocabulario de {tema}",
    "tema": "los animales en inglés",
    "por_que": "Las palabras de la unidad, una por nivel: se aprenden letra a letra y sin nada triste.",
    "infantil": false,
    "categoria": "aula",
    "giros": []
  },
  {
    "id": "aula_palabras",
    "nombre": "Forma palabras",
    "genero": "letras",
    "idea": "Forma palabras sobre {tema} uniendo letras en un huerto escolar",
    "tema": "la naturaleza",
    "por_que": "Ortografía y vocabulario a la vez; los niveles suben poco a poco de letras.",
    "infantil": false,
    "categoria": "aula",
    "giros": []
  },
  {
    "id": "aula_parejas",
    "nombre": "Parejas de ciencias",
    "genero": "memoria",
    "idea": "Un juego de memoria con parejas de {tema}",
    "tema": "los planetas del sistema solar",
    "por_que": "Memoria visual con el temario: ideal para los primeros minutos de clase.",
    "infantil": false,
    "categoria": "aula",
    "giros": []
  }
];

// Giros y mezclas (fabrica/giros.py): la app los ofrece en el taller de cada juego.
export interface Giro { id: string; nombre: string; que: string; generos: string[] | "*"; mezcla: boolean }

export const GIROS: Giro[] = [
  {
    "id": "oscuridad",
    "nombre": "A oscuras",
    "que": "Solo ves lo que alumbra tu linterna",
    "generos": [
      "plataformas",
      "runner",
      "volador",
      "horda",
      "naves",
      "cajas",
      "laberinto",
      "golf"
    ],
    "mezcla": false
  },
  {
    "id": "espejo",
    "nombre": "Mundo espejo",
    "que": "El mundo se ve al revés: izquierda y derecha se cambian",
    "generos": [
      "plataformas",
      "runner",
      "volador",
      "horda",
      "cajas",
      "laberinto",
      "golf",
      "serpiente"
    ],
    "mezcla": false
  },
  {
    "id": "contrarreloj",
    "nombre": "Contrarreloj",
    "que": "Cada intento tiene un tiempo; si se acaba, a empezar",
    "generos": [
      "laberinto",
      "golf",
      "cajas",
      "serpiente",
      "bloques",
      "memoria",
      "rompebloques",
      "saltos",
      "apilar",
      "cartas"
    ],
    "mezcla": false
  },
  {
    "id": "racha",
    "nombre": "Racha",
    "que": "Cada nivel sin morir sube el multiplicador de monedas (hasta x3)",
    "generos": "*",
    "mezcla": false
  },
  {
    "id": "fantasma",
    "nombre": "Fantasma",
    "que": "Corres contra tu mejor partida: una figura transparente repite tu mejor camino",
    "generos": [
      "plataformas",
      "runner",
      "volador",
      "horda"
    ],
    "mezcla": false
  },
  {
    "id": "cola",
    "nombre": "Laberinto serpiente",
    "que": "Mezcla con la serpiente: las casillas que dejas atrás se cierran",
    "generos": [
      "laberinto"
    ],
    "mezcla": true
  },
  {
    "id": "niebla",
    "nombre": "Niebla de guerra",
    "que": "Solo ves lo que tienen cerca tus aldeanos, tropas y edificios: hay que explorar para encontrar al rival",
    "generos": [
      "imperio"
    ],
    "mezcla": true
  },
  {
    "id": "viento",
    "nombre": "Viento",
    "que": "El viento empuja la bola mientras rueda: hay que apuntar contando con él",
    "generos": [
      "golf"
    ],
    "mezcla": false
  },
  {
    "id": "tormenta",
    "nombre": "Tormenta",
    "que": "Llueve y los peces nadan cada vez más rápido",
    "generos": [
      "pesca"
    ],
    "mezcla": false
  },
  {
    "id": "piedras",
    "nombre": "Piedras",
    "que": "Piedras que estorban hasta que una fusión al lado las rompe",
    "generos": [
      "fusion"
    ],
    "mezcla": false
  },
  {
    "id": "hielo",
    "nombre": "Suelo de hielo",
    "que": "Las cajas resbalan hasta chocar con algo: hay que pensar dónde se paran",
    "generos": [
      "cajas"
    ],
    "mezcla": false
  },
  {
    "id": "tuneles",
    "nombre": "Túneles",
    "que": "Huecos en el borde: sales por un lado y entras por el contrario",
    "generos": [
      "serpiente"
    ],
    "mezcla": false
  },
  {
    "id": "barajar",
    "nombre": "Cartas inquietas",
    "que": "Cada 2 fallos, dos cartas tapadas se cambian de sitio (se ve el cambio)",
    "generos": [
      "memoria"
    ],
    "mezcla": false
  },
  {
    "id": "dorado",
    "nombre": "Bichos de oro",
    "que": "A veces asoma uno de oro: se va antes, pero vale 3 golpes",
    "generos": [
      "topos"
    ],
    "mezcla": false
  },
  {
    "id": "invisibles",
    "nombre": "Notas invisibles",
    "que": "Las notas se apagan antes de llegar: hay que tocar de memoria y al ritmo",
    "generos": [
      "ritmo"
    ],
    "mezcla": false
  },
  {
    "id": "apocalipsis",
    "nombre": "Apocalipsis zombi",
    "que": "Supervivencia tras el fin del mundo: saquea casas y coches, zombis que no temen al fuego, muros y una radio para pedir rescate",
    "generos": [
      "supervivencia"
    ],
    "mezcla": true
  },
  {
    "id": "invierno",
    "nombre": "Invierno",
    "que": "Hace frío de noche: hoguera, cama o un abrigo de piel de ciervo para no congelarte",
    "generos": [
      "supervivencia"
    ],
    "mezcla": true
  },
  {
    "id": "caza",
    "nombre": "Caza",
    "que": "Ciervos que huyen y jabalíes que embisten: caza, cocina la carne en la hoguera (cruda enferma)",
    "generos": [
      "supervivencia"
    ],
    "mezcla": true
  },
  {
    "id": "equipo",
    "nombre": "Equipo de héroes",
    "que": "RPG de equipo tipo Raid o Summoners War: cuatro héroes con habilidades, elementos, estados, turnos por velocidad y botón AUTO",
    "generos": [
      "rpg"
    ],
    "mezcla": true
  },
  {
    "id": "criaturas",
    "nombre": "Criaturas",
    "que": "Combates uno contra uno de criaturas de fuego, agua y planta con cuatro movimientos (al caer una, sale la siguiente)",
    "generos": [
      "rpg"
    ],
    "mezcla": true
  },
  {
    "id": "survivor",
    "nombre": "Estilo Survivor",
    "que": "Hordas tipo Survivor.io: kunais, drones, rayos que saltan, escudos que giran y evoluciones de armas",
    "generos": [
      "horda"
    ],
    "mezcla": true
  },
  {
    "id": "vampiros",
    "nombre": "Estilo Vampiros",
    "que": "Hordas tipo Vampire Survivors: latigo, ajo, agua bendita, libro que gira y evoluciones",
    "generos": [
      "horda"
    ],
    "mezcla": true
  },
  {
    "id": "fantasia",
    "nombre": "Imperio de fantasía",
    "que": "El imperio con guardianes, elfas arqueras, jinetes de grifo, gólems y torres de mago",
    "generos": [
      "imperio"
    ],
    "mezcla": false
  },
  {
    "id": "galactico",
    "nombre": "Imperio galáctico",
    "que": "Estrategia espacial: drones mineros, marines, francotiradores, motos aéreas y tanques de asedio",
    "generos": [
      "imperio"
    ],
    "mezcla": false
  },
  {
    "id": "fiesta",
    "nombre": "Karts de fiesta",
    "que": "Mas objetos en la ruleta: la estrella (nada te para) y la cascara triple",
    "generos": [
      "karts"
    ],
    "mezcla": false
  },
  {
    "id": "dados",
    "nombre": "Tablero de dados",
    "que": "Tipo Monopoly Go: en vez de rodillos, dos dados y una ficha que da la vuelta a un tablero con premios",
    "generos": [
      "tragaperras"
    ],
    "mezcla": false
  },
  {
    "id": "mina",
    "nombre": "Tycoon de mina",
    "que": "Tipo Idle Miner: pozos que sacan mineral, ascensor que lo sube y almacen que lo vende (manda el mas lento)",
    "generos": [
      "tycoon"
    ],
    "mezcla": false
  },
  {
    "id": "monstruos",
    "nombre": "Golf de monstruos",
    "que": "Mezcla con el RPG: derriba monstruos con la bola para abrir el hoyo",
    "generos": [
      "golf"
    ],
    "mezcla": true
  }
];

// Nombre corto de cada genero (fabrica/generos.py) para las tarjetas de la app.
export const GENERO_NOMBRE: Record<string, string> = {
  "plataformas": "Plataformas",
  "runner": "Runner",
  "volador": "Arcade de un toque",
  "horda": "Hordas",
  "puzle": "Puzle de combinar 3",
  "torres": "Tower defense",
  "carreras": "Carreras contra 3 rivales",
  "naves": "Naves",
  "rompebloques": "Rompebloques",
  "bloques": "Bloques",
  "corredor": "Corredor 3D",
  "serpiente": "Serpiente",
  "memoria": "Memoria",
  "cajas": "Cajas",
  "preguntas": "Preguntas",
  "apilar": "Apilar",
  "topos": "Topos",
  "saltos": "Saltos",
  "arena": "Arena",
  "aldea": "Aldea",
  "ritmo": "Ritmo",
  "clicker": "Clicker",
  "cartas": "Cartas",
  "rpg": "Rpg",
  "laberinto": "Laberinto",
  "golf": "Golf",
  "pesca": "Pesca",
  "fusion": "Fusión",
  "tubos": "Tubos",
  "burbujas": "Burbujas",
  "imperio": "Imperio",
  "minas": "Minas",
  "mazmorras": "Mazmorras",
  "granja": "Granja",
  "mazo": "Mazo",
  "aventura": "Aventura",
  "cocina": "Cocina",
  "mahjong": "Mahjong",
  "aparcamiento": "Aparcamiento",
  "sopa": "Sopa",
  "sudoku": "Sudoku",
  "nonograma": "Nonograma",
  "cortar": "Cortar",
  "penaltis": "Penaltis",
  "agujero": "Agujero",
  "ciudad": "Ciudad",
  "canasta": "Canasta",
  "espiral": "Espiral",
  "buscaminas": "Buscaminas",
  "conecta": "Conecta",
  "damas": "Damas",
  "billar": "Billar",
  "solitario": "Solitario",
  "parchis": "Parchis",
  "caida": "Caída",
  "bolos": "Bolos",
  "mundo": "Mundo",
  "royale": "Royale",
  "cruzar": "Cruzar",
  "arco": "Arco",
  "cubos": "Cubos 3D",
  "parkour": "Parkour 3D",
  "tienda": "Tienda 3D",
  "futbol": "Fútbol 3D",
  "terror": "Terror 3D",
  "conduccion": "Conducción 3D",
  "zombis": "Zombis 3D",
  "baloncesto": "Baloncesto 3D",
  "tenis": "Tenis 3D",
  "karts": "Karts 3D",
  "supervivencia": "Supervivencia",
  "triple": "Triple",
  "tornillos": "Tornillos",
  "hexas": "Hexas",
  "autobus": "Autobus",
  "duelo": "Duelo",
  "escalada": "Escalada",
  "tirachinas": "Tirachinas",
  "plantas": "Plantas",
  "palabra": "Palabra",
  "letras": "Letras",
  "tycoon": "Tycoon",
  "tragaperras": "Tragaperras",
  "reino": "Reino",
  "multitud": "Multitud",
  "pedidos": "Pedidos",
  "a_medida": "A medida",
  "poder": "Poder",
  "diferencias": "Diferencias",
  "rompecabezas": "Rompecabezas",
  "pintar": "Pintar",
  "cuchillos": "Cuchillos",
  "arquero": "Arquero",
  "flechas": "Flechas",
  "numeros": "2048",
  "cartas_locas": "Cartas locas",
  "domino": "Dominó",
  "bloques_colores": "Bloques de colores",
  "tuberias": "Tuberías",
  "ajedrez": "Ajedrez",
  "reversi": "Reversi",
  "buscar": "Buscar objetos",
  "deslizar": "Deslizar",
  "ahorcado": "Ahorcado",
  "flota": "Hundir la flota",
  "simon": "Simón dice",
  "estrategia": "Estrategia por turnos",
  "autobatalla": "Batalla automática",
  "gemas": "Gemas y héroes",
  "coleccionables": "Cartas coleccionables",
  "roguelike": "Roguelike por turnos",
  "bombas": "Bombas",
  "artilleria": "Artillería",
  "comecocos": "Comecocos",
  "cadena": "Cadena de bolas",
  "lucha": "Lucha",
  "sandia": "Fusión de frutas",
  "pinball": "Pinball",
  "metroidvania": "Metroidvania",
  "sigilo": "Sigilo por turnos"
};

// Monetizacion (fabrica/monetizacion.py, la misma que orqkit/kit/monetize.gd): perfil de cada genero y
// lo que lleva cada perfil, para explicarselo al autor en la seccion de anuncios.
export interface InformeMonetizacion { perfil: string; nombre: string; por_que: string; banner: string; intersticial: string;
  anuncio_al_volver: boolean; premios: string[]; compras: string[]; bloques_admob: string[] }

export const PERFIL_GENERO: Record<string, string> = {
  "plataformas": "arcade",
  "runner": "arcade",
  "volador": "arcade",
  "horda": "arcade",
  "puzle": "puzle",
  "torres": "estrategia",
  "carreras": "arcade",
  "naves": "arcade",
  "rompebloques": "arcade",
  "bloques": "puzle",
  "corredor": "hipercasual",
  "serpiente": "hipercasual",
  "memoria": "puzle",
  "cajas": "puzle",
  "preguntas": "puzle",
  "apilar": "hipercasual",
  "topos": "hipercasual",
  "saltos": "hipercasual",
  "arena": "arcade",
  "aldea": "estrategia",
  "ritmo": "arcade",
  "clicker": "idle",
  "cartas": "tablero",
  "rpg": "estrategia",
  "laberinto": "puzle",
  "golf": "arcade",
  "pesca": "arcade",
  "fusion": "puzle",
  "tubos": "puzle",
  "burbujas": "puzle",
  "imperio": "estrategia",
  "minas": "puzle",
  "mazmorras": "estrategia",
  "granja": "idle",
  "mazo": "tablero",
  "aventura": "puzle",
  "cocina": "puzle",
  "mahjong": "puzle",
  "aparcamiento": "puzle",
  "sopa": "puzle",
  "sudoku": "puzle",
  "nonograma": "puzle",
  "cortar": "hipercasual",
  "penaltis": "hipercasual",
  "agujero": "hipercasual",
  "ciudad": "idle",
  "canasta": "hipercasual",
  "espiral": "hipercasual",
  "buscaminas": "puzle",
  "conecta": "tablero",
  "damas": "tablero",
  "billar": "arcade",
  "solitario": "tablero",
  "parchis": "tablero",
  "caida": "hipercasual",
  "bolos": "hipercasual",
  "mundo": "arcade",
  "royale": "arcade",
  "cruzar": "hipercasual",
  "arco": "hipercasual",
  "cubos": "arcade",
  "parkour": "hipercasual",
  "tienda": "idle",
  "futbol": "arcade",
  "terror": "arcade",
  "conduccion": "arcade",
  "zombis": "arcade",
  "baloncesto": "hipercasual",
  "tenis": "arcade",
  "karts": "arcade",
  "supervivencia": "estrategia",
  "triple": "puzle",
  "tornillos": "puzle",
  "hexas": "puzle",
  "autobus": "puzle",
  "duelo": "estrategia",
  "escalada": "hipercasual",
  "tirachinas": "arcade",
  "plantas": "estrategia",
  "palabra": "puzle",
  "letras": "puzle",
  "tycoon": "idle",
  "tragaperras": "casino",
  "reino": "estrategia",
  "multitud": "hipercasual",
  "pedidos": "puzle",
  "a_medida": "arcade",
  "poder": "estrategia",
  "diferencias": "puzle",
  "rompecabezas": "puzle",
  "pintar": "puzle",
  "cuchillos": "hipercasual",
  "arquero": "arcade",
  "flechas": "puzle",
  "numeros": "puzle",
  "cartas_locas": "tablero",
  "domino": "tablero",
  "bloques_colores": "puzle",
  "tuberias": "puzle",
  "ajedrez": "tablero",
  "reversi": "tablero",
  "buscar": "puzle",
  "deslizar": "puzle",
  "ahorcado": "puzle",
  "flota": "tablero",
  "simon": "hipercasual",
  "estrategia": "estrategia",
  "autobatalla": "estrategia",
  "gemas": "puzle",
  "coleccionables": "estrategia",
  "roguelike": "estrategia",
  "bombas": "arcade",
  "artilleria": "arcade",
  "comecocos": "arcade",
  "cadena": "puzle",
  "lucha": "arcade",
  "sandia": "puzle",
  "pinball": "arcade",
  "metroidvania": "arcade",
  "sigilo": "puzle"
};

export const MONETIZACION: Record<string, InformeMonetizacion> = {
  "hipercasual": {
    "perfil": "hipercasual",
    "nombre": "Hipercasual",
    "por_que": "Partidas de segundos: el dinero viene del volumen de intersticiales y de quien paga por quitarlos.",
    "banner": "solo en menús",
    "intersticial": "cada nivel, como mucho 10 por sesión",
    "anuncio_al_volver": false,
    "premios": [
      "Continuar tras perder",
      "Premio doble al acabar",
      "Saltar un nivel"
    ],
    "compras": [
      "Sin anuncios (2,99 €)",
      "500 monedas (0,99 €)"
    ],
    "bloques_admob": [
      "Intersticial",
      "Bonificado",
      "Banner"
    ]
  },
  "puzle": {
    "perfil": "puzle",
    "nombre": "Puzle",
    "por_que": "Ritmo tranquilo: el banner no molesta y las pistas o movimientos extra son el anuncio con premio que más se ve.",
    "banner": "en menús y partida",
    "intersticial": "cada 2 niveles, como mucho 6 por sesión",
    "anuncio_al_volver": false,
    "premios": [
      "Pista",
      "Movimientos extra",
      "Premio doble al acabar",
      "Saltar un nivel"
    ],
    "compras": [
      "Sin anuncios (2,99 €)",
      "Pack de inicio: 2000 monedas + sin anuncios (3,99 €)",
      "500 monedas (0,99 €)",
      "3000 monedas (4,99 €)"
    ],
    "bloques_admob": [
      "Intersticial",
      "Bonificado",
      "Banner"
    ]
  },
  "arcade": {
    "perfil": "arcade",
    "nombre": "Arcade y acción",
    "por_que": "Acción: nada que tape la pantalla mientras juegas; segunda oportunidad y premio doble al acabar.",
    "banner": "solo en menús",
    "intersticial": "cada nivel, como mucho 6 por sesión",
    "anuncio_al_volver": false,
    "premios": [
      "Continuar tras perder",
      "Premio doble al acabar",
      "Abrir cofre ya"
    ],
    "compras": [
      "Sin anuncios (2,99 €)",
      "500 monedas (0,99 €)",
      "Pase premium (3,99 €)"
    ],
    "bloques_admob": [
      "Intersticial",
      "Bonificado",
      "Banner"
    ]
  },
  "estrategia": {
    "perfil": "estrategia",
    "nombre": "Estrategia y midcore",
    "por_que": "Sesiones largas y jugadores que gastan: pocos intersticiales, acelerar y cofres con anuncio, y compras.",
    "banner": "no",
    "intersticial": "cada 3 niveles, como mucho 3 por sesión",
    "anuncio_al_volver": false,
    "premios": [
      "Acabar una obra ya",
      "Abrir cofre ya",
      "Energía",
      "Premio doble al acabar"
    ],
    "compras": [
      "Pack de inicio: 2000 monedas + sin anuncios (3,99 €)",
      "Pase premium (3,99 €)",
      "3000 monedas (4,99 €)",
      "Sin anuncios (2,99 €)"
    ],
    "bloques_admob": [
      "Intersticial",
      "Bonificado"
    ]
  },
  "idle": {
    "perfil": "idle",
    "nombre": "Idle y gestión",
    "por_que": "Se vuelve muchas veces al día: anuncio al volver, doblar lo ganado y banner en la pantalla de juego.",
    "banner": "en menús y partida",
    "intersticial": "cada 3 niveles, como mucho 4 por sesión",
    "anuncio_al_volver": true,
    "premios": [
      "Doblar lo ganado fuera",
      "Turbo un rato",
      "Premio doble al acabar"
    ],
    "compras": [
      "Pase premium (3,99 €)",
      "3000 monedas (4,99 €)",
      "Pack de inicio: 2000 monedas + sin anuncios (3,99 €)"
    ],
    "bloques_admob": [
      "Intersticial",
      "Bonificado",
      "Banner",
      "Apertura de app"
    ]
  },
  "tablero": {
    "perfil": "tablero",
    "nombre": "Tablero y clásicos",
    "por_que": "Partidas pausadas: banner fijo, un intersticial al acabar cada partida y quitar anuncios como compra.",
    "banner": "en menús y partida",
    "intersticial": "cada nivel, como mucho 5 por sesión",
    "anuncio_al_volver": false,
    "premios": [
      "Pista",
      "Premio doble al acabar"
    ],
    "compras": [
      "Sin anuncios (2,99 €)"
    ],
    "bloques_admob": [
      "Intersticial",
      "Bonificado",
      "Banner"
    ]
  },
  "casino": {
    "perfil": "casino",
    "nombre": "Casino",
    "por_que": "Tiradas gratis con anuncio y paquetes de monedas.",
    "banner": "solo en menús",
    "intersticial": "cada 2 niveles, como mucho 5 por sesión",
    "anuncio_al_volver": false,
    "premios": [
      "Tiradas gratis",
      "Premio doble al acabar"
    ],
    "compras": [
      "3000 monedas (4,99 €)",
      "Pack de inicio: 2000 monedas + sin anuncios (3,99 €)"
    ],
    "bloques_admob": [
      "Intersticial",
      "Bonificado",
      "Banner"
    ]
  },
  "infantil": {
    "perfil": "infantil",
    "nombre": "Infantil (familias)",
    "por_que": "Política de familias de Google: sin intersticiales ni banners; solo premios que pide el jugador.",
    "banner": "no",
    "intersticial": "no",
    "anuncio_al_volver": false,
    "premios": [
      "Premio doble al acabar"
    ],
    "compras": [],
    "bloques_admob": [
      "Bonificado"
    ]
  }
};
