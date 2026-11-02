# Géneros nuevos (diferencias a sigilo por turnos) y la calculadora de ganancias

Todos siguen el mismo patrón que el resto del kit: las reglas en `orqkit/kit/<genero>/<genero>_map.gd`
(estado en un diccionario, bot y analizador), la escena en `<genero>_game.gd`, el bot de pruebas en
`orqkit/qa/<genero>_bot.gd` y el generador de niveles en `fabrica/niveles/generador.py`. Todos
admiten **reglas programables** (la IA puede cambiar su mecánica y los bots lo comprueban).

| Género (fábrica) | Kit | Se pide con... | Qué comprueba el analizador |
|---|---|---|---|
| `diferencias` | `spotdiff` | «encuentra las diferencias», «spot the difference» | de 3 a 9 diferencias, separadas, dentro del dibujo y visibles |
| `rompecabezas` | `jigsaw` | «rompecabezas», «jigsaw» | una permutación de verdad, no casi hecha, mínimo de cambios ≥ 3 y margen sobre el límite |
| `pintar` | `paintnum` | «pintar por números», «colorear», «color by number» | tamaño jugable, 2 a 9 colores distintos y todos usados |
| `cuchillos` | `knifehit` | «knife hit», «lanzar cuchillos» | caben todos los cuchillos, nada nace pisado, el tronco gira y el bot lo parte |
| `arquero` | `rogue` | «archero», «roguelite de habilidades» | salas válidas, nadie en la entrada y el bot gana el nivel entero |
| `numeros` | `merge2048` | «2048», «juntar números» | objetivo potencia de 2 que cabe en el tablero y el bot llega |
| `cartas_locas` | `crazy8` | «cartas locas», «tipo uno», «ocho locos» | mazo de cartas válidas y tu bot gana la partida con ese mazo |
| `domino` | `domino` | «dominó» | 28 fichas distintas y tu bot gana con ese mazo |
| `bloques_colores` | `blockjam` | «color block jam», «bloques de colores» | sin solapes, cada color con su puerta, se puede vaciar y hay que pensar el orden |
| `tuberias` | `pipes` | «tuberías», «pipe puzzle» | la solución llena el tablero sin fugas, viene desordenado y los giros alcanzan |
| `ajedrez` | `chess` | «ajedrez», «chess», «jaque mate» | ventaja válida (solo dama, torres, alfiles, caballos o peones) y tu bot da jaque mate a ese rival |
| `reversi` | `reversi` | «reversi», «othello» | tablero de 6 u 8, tu bot gana a ese rival y la partida dura (no vale vaciar al rival en tres jugadas) |
| `buscar` | `hidden` | «buscar objetos», «objetos ocultos», «hidden object» | de 3 a 10 que buscar, cada una la única de su familia (las que se dibujan igual cuentan como la misma), ninguna tapada más de un tercio y tiempo de sobra |
| `deslizar` | `slide` | «puzle de deslizar», «15 puzzle» | una permutación que se puede resolver (paridad), no casi hecha, y la solución de la fábrica la resuelve |
| `ahorcado` | `hangman` | «ahorcado», «hangman» | largo y globos razonables y tu bot adivina la palabra en los 6 idiomas |
| `flota` | `battle` | «hundir la flota», «batalla naval», «battleship» | la flota cabe sin barcos pegados y tu bot hunde la del rival con esa semilla |
| `simon` | `simon` | «Simón dice», «repetir la secuencia» | botones, largo y velocidad que se pueden seguir, y tu bot llega al final |
| `estrategia` | `tactics` | «estrategia por turnos», «advance wars», «wargame» | mapa con los dos cuarteles, unidades en casillas que pisan y tu bot gana la batalla (y no en dos turnos) |
| `autobatalla` | `autochess` | «auto chess», «auto battler», «teamfight tactics» | de 2 a 12 rondas con rivales en su mitad y tu bot (que compra, funde y coloca) las gana |
| `gemas` | `gemrpg` | «puzzle and dragons», «empires and puzzles», «gemas y héroes» | equipo de 1 a 5, oleadas de 1 a 3 monstruos y tu bot (que simula las cadenas) gana todas |
| `coleccionables` | `ccg` | «cartas coleccionables», «hearthstone», «tcg» | mazos de 10 a 30 cartas que existen y tu bot gana el duelo (y no en 3 turnos) |
| `roguelike` | `crawl` | «roguelike por turnos», «pixel dungeon», «mazmorra por turnos» | salida y escalera, mapa grande, la escalera se alcanza y tu bot (que explora, pelea, bebe y espera en los pasillos) baja la mazmorra |
| `bombas` | `bomber` | «bomberman», «poner bombas», «laberinto con bombas» | una sola salida escondida, monstruos lejos de la salida del héroe y tu bot (que calcula por dónde van a pasar las llamas, también en cadena) gana perdiendo como mucho una vida |
| `artilleria` | `artillery` | «worms», «artillería», «bazuca» | dos equipos en su lado y por encima del agua, y tu bot (que calcula el disparo con el viento) gana la batalla y no de un solo tiro |
| `comecocos` | `chomp` | «pacman», «comecocos», «laberinto de puntos» | ningún callejón sin salida, todos los puntos alcanzables y tu bot (que prueba cada giro simulando a los fantasmas) lo limpia perdiendo como mucho una vida |
| `cadena` | `chain` | «zuma», «luxor», «cadena de bolas» | camino largo, el lanzador fuera del camino y tu bot (que prueba cada hueco, disparando como una persona rápida) rompe la cadena antes del agujero |
| `lucha` | `fighter` | «street fighter», «juego de lucha», «uno contra uno» | vida razonable y tu bot (que se cubre a tiempo y castiga) gana el combate a dos asaltos, y no en un suspiro |
| `sandia` | `fruitmerge` | «juego de la sandía», «suika», «fusión de frutas» | la fruta objetivo es más grande que las que te tocan y tu bot (que suelta cada fruta encima de una igual) la consigue sin rebosar |
| `pinball` | `pinball` | «pinball», «petaco», «flipper» | setas dentro de la mesa y tu bot (que golpea con la parte buena de la pala) llega a la puntuación con las bolas que hay |
| `metroidvania` | `metroid` | «metroidvania», «hollow knight», «castlevania» | hay meta, la meta NO se alcanza con lo que tienes al empezar (las puertas importan) y tu bot (que planifica con lo que tiene, va a por cada habilidad y vuelve) la alcanza perdiendo como mucho una vida |
| `sigilo` | `stealth` | «hitman go», «sigilo por turnos», «esquivar guardias» | hay salida y guardias, se puede resolver y los guardias importan (ir por el camino corto sin mirarlos sale mal); el resolutor da el mínimo de movimientos (la estrella) |
| `flechas` | `arrows` | «puzle de flechas», «tap away» | flechas dentro y sin pisarse, se puede vaciar y no más de la mitad libres al empezar |

## Diferencias
Los dibujos no necesitan IA de imagen: son escenas por datos (24 figuras vectoriales: árbol, casa,
pez, coche, globo, tarta...) sobre un fondo temático. Cada diferencia es un cambio de color, una
figura que falta, que cambia de tamaño, que se mueve o que se da la vuelta (solo en las que no son
simétricas). Tocar donde no hay diferencia cuenta como fallo; con demasiados, se repite. Dos pistas
por nivel. Estrellas por fallos y pistas.

## Rompecabezas
El dibujo (una escena con una figura distinta en cada pieza, así ninguna pieza es igual a otra) se
pinta una vez en una textura y el **héroe del juego** va en medio. Se cambian dos piezas tocándolas o
arrastrando una sobre otra; la que cae en su sitio se queda fija. El mínimo de cambios es «piezas
fuera de sitio menos ciclos» y el bot siempre lo consigue. Desde la mitad del juego (salvo en fácil)
hay límite de cambios con margen.

## Pintar por números
12 dibujos de cuadritos de 11 a 15 de lado (corazón, estrella, seta, casa, pez, árbol, gato, cohete,
helado, sol, barco, flor), de menos a más colores. Cada tres niveles el dibujo **es el héroe del
juego**: el kit recorta su primer fotograma, lo reduce a cuadritos y deja 5-7 colores (k-medias);
si no hay arte, se queda el dibujo de la colección. Arrastrando con el color equivocado no se cuenta
fallo; tocando, sí (solo quita estrellas, nunca se pierde). Los cubos pintan de golpe un color.

## Lanza cuchillos
El giro del tronco son tramos `{"v": grados/s, "d": segundos}` que se repiten (0 = se para, negativo
= al revés), así que todo es determinista: el bot lanza cuando, al llegar el cuchillo, abajo hay
hueco. Al principio el giro es constante; luego cambia de velocidad y de sentido. Cada quinto nivel,
un jefe con más cuchillos. Las manzanas dan monedas y estrellas.

## Arquero
Arena de 9 × 14 vista desde arriba: babosas que persiguen, arqueros que disparan, murciélagos rápidos
y un jefe que dispara en abanico cada cuarto nivel. El héroe dispara solo al más cercano cuando está
quieto. Al limpiar una sala se elige 1 de 3 habilidades (flecha doble, tiro rápido, fuerza, flechas
en diagonal, más vida, escudo). El analizador juega el nivel entero con el bot (esquiva balas, se
aleja de quien se acerca y se para a disparar); en las pruebas con 7 semillas gana 111 de 112
niveles y la fábrica rehace el que no. Con prisa (validación), la partida usa el mismo paso que el
analizador: el resultado es idéntico.

## Flechas
Tableros de 5×6 a 9×12 llenos de flechas rectas de 1 a 4 casillas. Tocar una la saca volando en la
dirección de su punta si ninguna otra se cruza en el camino hasta el borde; si choca, cuesta una
vida (3, o 2 en los niveles difíciles). Siempre hay solución: el generador pone cada flecha nueva
con su camino libre respecto a las anteriores (y casi siempre encima del camino de una ya puesta,
para taparla), así que quitarlas en orden inverso funciona; y como quitar una flecha nunca bloquea a
otra, el bot que toca cualquier flecha libre siempre vacía el tablero. Dos pistas por nivel.

## 2048
Tableros de 4×4 y, desde la mitad, de 5×5 con rocas que no se mueven y cortan la fila. Objetivo de 64
a 512 (partidas de 1 a 5 minutos). Las fichas nuevas salen de una semilla, así que con las mismas
jugadas sale lo mismo: «deshacer» también devuelve el azar (no se puede pescar otra ficha) y el bot
puede mirar dos jugadas por delante. Estrellas por no usar los deshacer.

## Cartas locas
Mazo de 108 cartas (cuatro colores, 0-9, salta, reversa, +2, comodín y comodín +4) contra 1 a 3
rivales. El nivel lleva el mazo en orden: sin azar, la partida es siempre la misma para las mismas
jugadas. El generador de la fábrica es una copia exacta de las reglas del kit en Python (comprobada
partida a partida: mismos turnos y mismo ganador) y baraja hasta encontrar un mazo con el que tu bot
gana; desde el tercer nivel, uno con el que jugar «la primera que valga» no gana. Si se acaba el
mazo, se rehace con la mesa en su orden. Los rivales juegan la primera carta que vale.

## Dominó
Doble seis a robar, de 2 a 4 jugadores (con 4 no queda pozo). Sale quien tiene el doble más alto.
Si no puedes jugar, robas hasta poder o pasas; si nadie puede (cierre), gana quien suma menos. Como en
cartas locas, el nivel lleva las 28 fichas en orden y el generador de la fábrica es una copia exacta
de las reglas del kit (mismos turnos y mismo ganador en 72 de 72 partidas de prueba).

## Bloques de colores
Bloques de 1 a 4 casillas y de 3 a 6 colores en un tablero con algún muro y puertas de colores en
los bordes. Un bloque sale por una puerta de su color si cabe (su ancho no pasa del de la puerta).
Sacar un bloque solo deja más hueco, así que el analizador saca el primero que tenga camino (búsqueda
en anchura) y repite: si vacía el tablero, tiene solución. El generador de la fábrica hace lo mismo
en Python (mismos pasos que el kit) y busca tableros en los que, al empezar, no todos los bloques
tienen camino. Los bloques se arrastran con el dedo casilla a casilla.

## Tuberías
Tableros de 4×5 a 7×9 con un grifo. La fábrica traza un árbol al azar desde el grifo que pasa por
todas las casillas (esa es la solución) y gira cada pieza. Se gana cuando el agua llega a todas sin
ninguna tubería abierta (vale cualquier solución, no solo la de la fábrica). En la segunda mitad,
giros contados con margen sobre el mínimo.

## Ajedrez
Contra la máquina, con blancas. Reglas de siempre salvo el enroque y la captura al paso; el peón que
llega al final corona dama. Tocas una pieza y se iluminan sus casillas; el rey en jaque se marca en
rojo. Cada nivel sube una **escalera de ventaja**: al principio al rival le faltan la dama y las dos
torres, piensa una jugada y se equivoca a menudo; al final, partida completa contra un rival que
piensa dos jugadas. Tablas (ahogado o 200 jugadas) cuentan como no ganada. La fábrica comprueba cada
nivel jugándolo entero: tu bot (que piensa dos jugadas) tiene que dar mate a ese rival con esa semilla;
si no, se fabrica otra.

## Reversi
Contra la máquina, con negras. Pones una ficha que encierre fichas del rival en línea y se dan la
vuelta (con su media vuelta animada); las casillas donde puedes poner se marcan. Si no tienes
jugada, pasas; cuando nadie puede, gana quien tenga más. Los primeros niveles son en 6×6 contra un
rival despistado; los últimos, en 8×8 contra uno que piensa dos jugadas. La fábrica juega cada nivel
entero: tu bot (que piensa tres) tiene que ganar y la partida tiene que durar de verdad.

## Buscar objetos
Una escena temática llena de figuras (de 16 a más de 50, más pequeñas según avanza) y, abajo, la tira
de lo que hay que encontrar: se tacha al tocarlo. Pistas con el botón (marcan una que falta), y en la
segunda mitad tiempo y fallos contados. La fábrica pone cada objeto buscado donde casi no lo tapan
y nunca deja una «gemela»: el triángulo y la cometa, el círculo y el globo, el cuadrado y el
regalo, y la nube y el arbusto cuentan como la misma figura.

## Deslizar (el puzle de 15)
El dibujo del juego (con el héroe en medio, como el rompecabezas) en piezas con un hueco. Tocas una
pieza de la fila o columna del hueco y se desliza (varias de golpe si están en línea); abajo, el
dibujo entero como guía. La fábrica lo desordena moviendo el hueco desde el dibujo resuelto (así
siempre tiene solución) y guarda el camino de vuelta. De 3×3 a 5×5; movimientos contados al final.

## Ahorcado con globos
Versión amable: el héroe cuelga de un ramo de globos y cada letra que no está revienta uno; si se
acaban, cae. Teclado en pantalla (con Ñ en español), pista que destapa una letra. La palabra sale del
diccionario del idioma del jugador y la fábrica comprueba que el bot la adivina en los 6 idiomas.

## Hundir la flota
Arriba, en pequeño, tu flota y los disparos del rival; abajo, el mar del rival donde tocas para
disparar (si tocas, repites). Barcos sin pegarse. El rival empieza disparando al azar, luego caza
alrededor de lo tocado y al final dispara en damero. Con la barra «Tú contra el rival».

## Simón dice
Botones de colores en círculo, cada uno con su nota: se encienden en secuencia y hay que repetirla;
cada ronda una luz más. De 4 a 6 botones, más rápido y con menos fallos perdonados según avanza.

## Estrategia por turnos
Tipo Advance Wars. Mapa en espejo con llanos, bosques (+1 defensa, cuestan 2), montañas (+2, solo
infantería), ríos con puentes, ciudades y un cuartel por bando. Tres unidades: **infantería**
(captura), **tanque** (fuerte, no sube montañas) y **artillería** (dispara a 2-3 casillas, no puede
moverse y disparar en el mismo turno). Daño sin azar según vida, tipo y terreno, con contraataque
cuerpo a cuerpo. Capturar cuesta dos turnos con infantería encima; las ciudades propias curan.
Ganas capturando el cuartel rival o sin unidades rivales. El rival planea cada unidad (rematar a
los heridos, no quedarse al descubierto, ir en grupo, cortar capturas) y, en los primeros niveles,
se equivoca y tú tienes refuerzos. La fábrica juega cada batalla entera con el bot.

## Batalla automática
Tipo Auto Chess / Teamfight Tactics. Cada ronda cobras oro (más con racha de victorias), compras en
una tienda de 5 (se rehace por 2), colocas en tu mitad del tablero (un hueco más cada dos rondas) y
pelean solas. Seis tipos: guerrero, caballero (tanque), arquero, mago (daño en área), asesina
(salta a la retaguardia) y sanadora. **Tres iguales se funden** en una de 2 estrellas, y tres de 2
en una de 3. Ves el ejército rival antes de luchar. Pierdes una vida por ronda perdida (3 vidas).
El combate es sin azar, en pasos de 0,1 s, igual en el juego que en el analizador.

## Gemas y héroes
Tipo Puzzle & Dragons / Empires & Puzzles. Tablero de 7×7 con gemas de 5 colores (cada una con su
forma, para distinguirlas sin color) y corazones. Cambias dos vecinas (tocando o arrastrando); las
líneas de 3 o más se rompen y caen otras (las cadenas multiplican). Cada color hace atacar a los
héroes de ese color al monstruo de delante, con ventaja de color (fuego > naturaleza > agua > fuego;
luz y sombra se ganan entre sí); los corazones curan. Cada héroe carga su especial (golpe a todos,
cura del 40 % o aturdir 2 turnos) y se lanza tocando su retrato. Los monstruos atacan cuando su
cuenta atrás llega a 0. El primer héroe lleva el arte del héroe del juego.

## Cartas coleccionables
Tipo Hearthstone, contra la máquina. Cada turno sube el maná (hasta 10) y robas una carta. Diez
esbirros (con **Provocar**, **Carga** o **Escudo**) y seis hechizos (daño con objetivo, curar, robar,
+2/+2 y daño a todos). Los esbirros atacan desde el turno siguiente (los de carga, ya) a esbirros
(que contraatacan) o al héroe; los de provocar hay que atacarlos antes. Sin mazo, la fatiga hace
daño creciente. La IA rival gasta su maná, hace cambios que le salen a cuenta y remata cuando
puede; con los niveles su mazo lleva más cartas fuertes y piensa mejor. Tu héroe lleva el arte del
juego.

## Roguelike por turnos
Tipo Pixel Dungeon: la mazmorra va casilla a casilla y cada paso tuyo es un turno de los
monstruos. Hay niebla (solo ves lo cercano y lo que ya exploraste queda en penumbra) y luz de
antorcha. Monstruos: rata, goblin, orco (con defensa), esqueleto y el jefe, que guarda la escalera
(hay que vencerle para bajar). Duermen hasta que te ven y luego te persiguen por el camino más
corto. Objetos: pociones (curan 10), espadas (+2 de ataque), armaduras (+1 de defensa) y oro. Con la
experiencia subes de nivel (más vida y, cada dos, más ataque) y recuperas vida poco a poco. Se juega
tocando: una casilla y el héroe va andando (se para si aparece un monstruo despierto), un monstruo
al lado para atacarle y tu héroe para esperar un turno. Estrellas: con todo recogido y media vida,
3. El generador hace salas unidas por pasillos que crecen con la dificultad. «Roguelike» a secas
sigue eligiendo el de acción (`mazmorras`).

## Bombas
Tipo Bomberman, en un laberinto de bloques fijos y cajas. Arrastras el dedo para moverte (el
joystick sale donde toques) y pulsas el botón de la bomba. La explosión va en cruz: se para en los
bloques, rompe la primera caja que encuentra y hace estallar otras bombas (cadena). Bajo las cajas
hay premios (una bomba más, más alcance y más velocidad) y la salida, que solo vale cuando no
quedan monstruos. Monstruos: el globo va a su aire, el perseguidor te sigue si estás cerca y el
rápido corre. Tres vidas por nivel (vuelves a la salida con un escudo un momento). Estrellas: sin
perder vidas y a tiempo, 3. Todo va por ticks (10 por segundo), así el bot juega exactamente lo
mismo que tú.

## Artillería
Tipo Worms, por turnos contra la máquina. En tu turno mueves al soldado que toca con las flechas
(unos pasos; los muros altos no se suben y caer mucho hace daño) y apuntas arrastrando hacia atrás,
como un tirachinas: la dirección y la fuerza salen del arrastre y al soltar dispara. En los primeros
niveles una guía de puntos enseña el principio de la trayectoria (sin viento); con la dificultad se
acorta. El viento cambia cada turno. La explosión abre un cráter (el terreno baja) y quita vida
según la distancia, también a los tuyos; quien se queda sin suelo cae al agua. Desde el turno 24 el
agua sube. La IA rival busca el mejor disparo y falla según su puntería, que mejora con los niveles.
Estrellas: sin bajas, 3.

## Comecocos
Tipo Pac-Man. Deslizas el dedo hacia donde quieres ir y el giro se recuerda hasta que se puede.
Los fantasmas salen de casa uno a uno y cada uno persigue a su manera (directo, por delante de ti,
tímido y caprichoso), con ratos en los que se dispersan a las esquinas. Las cuatro píldoras los
asustan: se vuelven azules, huyen y se pueden comer (100, 200, 400...); al acabar el susto
parpadean. Hay túnel de lado a lado en los niveles altos. Tres vidas. Los laberintos son
simétricos y sin callejones (cada pasillo da la vuelta), y con la dificultad hay más fantasmas,
más rápidos y con menos susto.

## Cadena de bolas
Tipo Zuma. Una fila de bolas de colores avanza por un camino (espiral alrededor del lanzador o
zigzag con el lanzador abajo) hacia un agujero. Tocas donde quieres disparar y la bola se mete en
la cadena justo donde da; si junta tres o más del mismo color, explotan. El hueco se cierra solo:
si quedan dos colores iguales frente a frente, la parte de delante vuelve atrás y puede encadenar
otra explosión (combos x2, x3...). Tocando el lanzador cambias la bola por la siguiente. Las bolas
que te tocan siempre son de colores que siguen en la cadena. Con la dificultad hay más bolas, más
colores y la cadena va más rápida. Estrellas según las bolas por disparo.

## Lucha
Tipo Street Fighter, contra la máquina. Flechas para andar y saltar; botones de puño (rápido y
corto), patada (lenta y larga), cubrirse (mantener) y especial (una bola de energía que gasta
media barra; la barra se carga golpeando y recibiendo). Cubrirse a tiempo quita casi todo el
daño; después de un golpe hay que recuperarse y ahí te pueden castigar. Gana quien gane dos
asaltos (K.O. o más vida al acabar el tiempo). El rival tiene estilo (agresivo, a distancia o al
contraataque) y con los niveles tiene más vida, mejores reflejos y se cubre más. La cámara sigue
la pelea; los luchadores se dibujan por partes con la cara del héroe y del rival del juego.

## Fusión de frutas
Tipo juego de la sandía. Mueves el dedo para colocar la fruta y al soltar cae al tarro, con física
de verdad (rueda, se apila y empuja). Dos frutas iguales que se tocan se juntan en la siguiente,
de la cereza a la sandía. Hay que conseguir la fruta objetivo antes de que el tarro rebose (una
fruta quieta por encima de la línea un par de segundos). Arriba ves el objetivo y la siguiente
fruta. Con la dificultad el objetivo es más grande, salen frutas más variadas y el tarro es más
estrecho. Estrellas según lo vacío que queda el tarro.

## Pinball
Mesa de neón con física propia (60 pasos por segundo). La bola sale sola por el carril de la
derecha. Tocas la mitad izquierda de la pantalla para la pala izquierda y la derecha para la
derecha (mantener la deja arriba); la pala empuja con la velocidad de su giro, así que da más fuerte
con la punta. Setas que rebotan (100), tirachinas sobre las palas, tres dianas que se tumban
(todas: premio y multiplicador) y tres pasillos arriba que, encendidos, suben el multiplicador
(hasta x4; se pierde al colarse la bola). Llega a la puntuación objetivo antes de perder las tres
bolas. El generador coloca setas y dianas distintas en cada mesa; con la dificultad sube el
objetivo y la gravedad. Estrellas según las bolas perdidas.

## Metroidvania
Un mundo de salas conectadas (de 3 x 3 a 5 x 3) en el que las habilidades abren caminos. Todo va
por casillas y ticks: andar es una casilla por tick, saltar sube 4, el **doble salto** otras 4 en
el aire, el **impulso** cruza 4 casillas de golpe (una vez por salto) y el **martillo** rompe los
bloques agrietados; las **llaves** abren puertas. El generador hace un árbol de salas y, en el
camino a la meta, pone puertas: muro alto (doble salto), foso de pinchos con techo bajo (impulso),
bloques (martillo) y puerta (llave). Cada habilidad está antes de su puerta y, si puede, en una
rama lateral: hay que desviarse y volver. Las salas de arriba y abajo se unen con escaleras de
plataformas que se suben con el salto normal. Hay enemigos que patrullan (un golpe y fuera),
pinchos (quitan una vida y te devuelven al último suelo seguro), monedas, corazones y un
minimapa con las salas visitadas. El bot busca en anchura sobre el estado del héroe (casilla,
subida, doble salto e impulso disponibles): planifica de verdad, y si algo le saca del plan (un
golpe) vuelve a planificar. Estrellas: todas las monedas sin perder vidas, 3.

## Sigilo por turnos
Tipo Hitman GO: un tablero de puntos unidos por caminos. Tocas un punto vecino y vas; si allí hay
un guardia, lo dejas fuera. Después mueven los guardias: si acabas en el punto que vigila uno
(se ve en rojo, con su cono de visión), te pilla. Hay guardias quietos, que patrullan (avanzan y
dan media vuelta al final) y que giran. Siempre se puede deshacer y reiniciar. Estrellas: llegar a
la salida, coger el maletín y hacerlo en el mínimo de movimientos más dos. El generador (con las
mismas reglas en Python) solo da tableros con solución, en los que los guardias obligan a pensar,
y el resolutor en anchura del kit calcula el objetivo de movimientos.

## Calculadora de ganancias (app)
En la ficha de cada juego, pestaña **Publicar**, debajo de los anuncios: «¿Cuánto podría ganar?».
Con las descargas al día, cuánta gente vuelve (D1 y D7) y dónde juega la mayoría calcula los
jugadores al día tras un mes (curva de retención por D1 y D7), los anuncios por jugador tal y como
los pone el kit (nada el primer minuto, 90 s entre intersticiales, 6 por sesión, bonificados según el
tipo de juego) y el eCPM medio de AdMob en cada zona. Da una horquilla y la cifra más probable, lo
que deja cada descarga y cuántas descargas harían falta para 100 € al mes. Si el juego ya tiene
jugadores, usa su D1 y D7 reales. Para niños aplica anuncios sin personalizar y sin tienda. Es una
estimación orientativa: lo real está en la consola de AdMob. Código en `app/src/ganancias.ts` (con
sus pruebas en `app/pruebas/ganancias.mjs`) y `app/src/vistas/ganancias.ts`.
