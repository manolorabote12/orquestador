# Géneros 3D: cómo están hechos

Complemento de `GENEROS-LEEME.md` para los géneros 3D. Hoy hay **71 géneros**; los 3D de verdad son
cubos, parkour, tienda, fútbol, terror, conducción, zombis, baloncesto, tenis, karts y
supervivencia (más el battle royale, que nace en 3D).

Todos siguen la misma receta: **la lógica es una simulación pura** (`<kit>_map.gd`, sin nodos) que
usan el juego, el bot y el analizador; el juego (`<kit>_game.gd`, un `Node3D`) solo dibuja y lee el
mando. Así el bot gana con las mismas reglas que el jugador y el analizador rechaza lo injusto.

## Zombis 3D (`kit/zombie`, género «zombis»)
- Arena en casillas de 2 m: «#» muro, «c» cajas (tapan y paran las balas), «Z» entradas de zombis
  en el borde, «P» salida en el centro, «S» escopeta, «R» fusil, «+» botiquín (sale entre oleadas).
- Oleadas: cada una con más zombis, que salen más deprisa y en grupos por entradas distintas y
  aguantan más tiros; desde cierta oleada hay corredores (rápidos, poca vida) y brutos (lentos,
  mucha vida). Los zombis bajan por un mapa de distancias al jugador y van directos si te ven.
- Armas con disparo instantáneo, dispersión, cargador y recarga; las cajas y muros paran la bala.
- Primera persona: mando a la izquierda, arrastrar a la derecha para mirar, ayuda de puntería
  suave, radar de zombis cercanos fuera de la vista, botones Disparar, Recargar y Cambiar arma.
- Bot: apunta girando como una persona (con tiempo de reacción), prefiere el que tiene delante,
  retrocede hacia el hueco más libre si se acercan y va a por armas y botiquines.
- Calibrado: 40 de 40 arenas; en las últimas el bot acaba con poca vida o cae (la fábrica las
  suaviza). Prueba: `--solo=zombie`.
- Se pide con «fps», «juego de zombis», «shooter 3D»… «zombi» a secas sigue en «horda» (2D).
- **Cooperativo en directo** (botón Online de la portada; salas públicas o con código, hasta 4):
  cada móvil mueve a su jugador y sus disparos; el anfitrión (sesión más baja) mueve zombis y
  oleadas y manda una foto 8 veces por segundo («zs»); los demás mandan cómo van («st»), sus
  aciertos («hit», los aplica el anfitrión) y reciben los mordiscos («bite»). Los zombis van al
  jugador vivo más cercano (mapa de distancias desde todos); +2 zombis por oleada por cada
  jugador más; quien cae vuelve en la oleada siguiente con media vida y se pierde si caen todos.
  Si el anfitrión calla 8 s, el siguiente por orden de sala pasa a mover los zombis. Sin pausa y
  sin trofeos (migración 36: las salas de juegos de zombis son siempre «coop»).
  Prueba: `--solo=zombie_live` y `pruebas/zombis_coop.sql`.

## Karts 3D (`kit/kart`, género «karts»)
- Mapa: puntos de control «x,y» del circuito (cerrado); «B,k» placa de turbo; «#semilla». La línea
  central es una curva suave (Catmull-Rom) cada 1,5 m con distancia, tangente y curvatura.
- Generador: vuelta alrededor del centro con el radio cambiando; se descartan circuitos que se
  pisan (tramos no vecinos a menos de ancho + 8 m), esquinas de más de 140° o cortos.
- Kart arcade: acelera solo, giro que depende de la velocidad, hierba que frena, barrera de
  neumáticos, choques entre karts. Derrape: mantener girando a buena velocidad; al soltar, turbo
  según lo que ha durado (azul 0,5 s, naranja 1,1 s, morado 1,9 s).
- IA: mira un punto por delante, toma la curva por dentro (sin pasarse del borde), frena según el
  radio de la curva que viene (el kart traza v / 1,8 m con el giro máximo) y derrapa en las largas.
- Sales el último de la parrilla; el nivel pide acabar 3.º, 2.º o 1.º. Vueltas y puesto en
  directo; la vuelta cuenta al cruzar la meta habiendo pasado por la mitad.
- Analizador: el circuito no se pisa y el bot llega en el puesto en 2 de 3 carreras.
  Calibrado: 38 de 48 circuitos a la primera. Prueba: `--solo=kart`.
- **Objetos** («items», activos por defecto; `"items": false` en el nivel los quita): dos filas de 3
  cajas (al 30 % y al 72 % de la vuelta) que reaparecen a los 3 s. El objeto depende del puesto:
  el primero recibe sobre todo plátanos, los del medio cáscaras y los últimos turbos.
  - Cáscara: sale a 34 m/s siguiendo la pista y va a por el kart que tenga delante (3,5 s).
  - Plátano: se queda detrás 25 s. Turbo: 1,6 s de acelerón en el acto.
  - Golpe: trompo (sin mando, sin turbo ni derrape, frenando): 1,1 s los rivales y 0,8 s tú.
  - Escudo: un plátano o una cáscara sin usar paran una cáscara (se rompe el objeto).
  - IA: esquiva los plátanos de su línea (mejor cuanto más hábil); el líder guarda el plátano de
    escudo; los rivales flojos tardan más en usar lo que cogen; con objetos van 0,05 más flojos.
  - Calibrado (60 circuitos de la fábrica, 8 carreras cada uno): el bot gana el 93 % en fácil, el
    86 % en normal y el 81 % en difícil (sin objetos: 98 / 87 / 80). El analizador acepta 54 de 60
    (55 sin objetos). Botón OBJETO encima de DERRAPE (tecla E en el ordenador).
- **Carreras online** (botón Online de la portada; salas públicas o con código, hasta 4 pilotos):
  - Parrilla común: bots delante («bot0», «bot1»...), personas detrás por orden de sala; misma
    semilla de la sala en todos los móviles (`setup_online`).
  - Cada móvil mueve su kart y lo manda 10 veces por segundo («k»: posición, rumbo, velocidad,
    derrape, turbo, trompo, vuelta, progreso y meta). Los demás se suavizan con un poco de
    predicción (`net_follow`) y llevan su nombre encima.
  - El anfitrión (sesión más baja) mueve los bots y los manda en el mismo mensaje. Si calla 3 s,
    pasa a moverlos la sesión más baja de las que siguen (`make_host`).
  - Objetos en la red: quien lanza manda «it» (id = sesión del dueño + número); cada móvil decide
    los golpes sobre sus propios karts y manda «hx» para que el disparo desaparezca en todos.
  - Al cruzar la meta: tu puesto entre las personas (1-4, `human_place`) va al servidor (trofeos de
    la arena: +12, +5, −2, −6) y la carrera sigue de fondo. Sin pausa.
  - Servidor: migración 37 (`_arena_niveles` acepta el género «karts»).
    Pruebas: `--solo=kart_live` y `pruebas/karts_online.sql`.

## Supervivencia 3D (`kit/survival`, género «supervivencia»)
- La simulación es la de la supervivencia 2D (`survival_map.gd`, en casillas); el 3D solo dibuja
  (`survival_view3d.gd`), así que el analizador y el bot son los mismos. Detalles de las reglas en
  `GENEROS-LEEME.md` («Supervivencia»).
- Isla en bloques bajos (una casilla = 1 m) con lados donde la vecina está más baja; mar hasta el
  horizonte; árboles, rocas, hierba, arbustos con bayas y guaridas con MultiMesh (se rehacen solo
  cuando algo cambia: recoger, agotarse o volver a salir una baya).
- Personaje y lobos: el arte de la fábrica como `AnimatedSprite3D` con billboard en Y (o formas si
  no hay arte). Noche: sol y ambiente bajan, cielo azul noche y `OmniLight3D` naranja en la hoguera.
- Prueba: `--solo=survival` (incluye una partida entera del bot en 3D).

## Baloncesto 3D (`kit/basket`, género «baloncesto»)
- Media pista de la calle: los dos equipos atacan la misma canasta, de 1 contra 1 a 3 contra 3.
- Tiro con barra: se mantiene TIRO y se suelta en la zona verde; la probabilidad depende de la
  distancia, del tiempo de la barra, del defensor encima y de la destreza. 2 puntos o triple.
- Reglas de la calle: tras canasta saca el otro desde arriba; tras rebote defensivo o robo hay
  que sacar el balón fuera del triple antes de tirar. Reloj de posesión de 12 s.
- En defensa los botones son Saltar (tapón si estás pegado al tirador) y Robar.
- IA: con balón tira si está solo, pasa al compañero más libre o penetra por el lado libre; sin
  balón va a esquinas y alas libres; en defensa cada uno a su par, entre él y la canasta.
- Analizador: 3 partidos con el bot, debe ganar 2. Prueba: `--solo=basket`.
- «baloncesto» a secas sigue yendo a «canasta» (tiros); este género se pide con «partido de
  baloncesto», «baloncesto 3D», «streetball»…

## Tenis 3D (`kit/tennis`, género «tenis»)
- Pista de individuales de verdad (23,77 × 8,23 m), red de 0,95 m, gradas con público y juez.
- Pelota con gravedad y botes; cada golpe se calcula para caer donde se apunta pasando la red.
- Golpe automático cuando la pelota está a tu alcance (tras el primer bote o de volea); el mando
  decide el lado; GOLPE justo antes (0,3 s) da un tiro perfecto, más rápido y preciso; GLOBO alto
  al fondo. Aro amarillo donde botará la pelota que te llega.
- Punto por red, fuera o doble bote; tanteo 15-30-40, iguales y ventaja; cambia el saque cada juego.
- IA: tarda en reaccionar y calcula peor con menos destreza; apunta lejos del rival (más abierto
  y corto cuanto mejor es). Analizador: 3 partidos con el bot, debe ganar 2. Prueba: `--solo=tennis`.

## Fútbol 3D (`kit/soccer`, género «futbol»)
- Campo cerrado de 26×40 m con paredes, porterías de 6 m, 2-5 por equipo (el primero portero).
- IA de los dos equipos: con balón tira a la esquina lejos del portero (la puntería depende de
  «skill»), pasa al compañero libre (mira espacio y línea de pase) o regatea; sin balón presiona el
  más cercano y el resto cierra entre balón y portería; el portero cierra el ángulo y se tira.
- Tú manejas al de tu equipo más cercano al balón; botones Tiro (sin balón: entrada) y Pase.
- Analizador: el bot (tu equipo con buena cabeza) juega 3 partidos y debe ganar 2. La semilla del
  partido va en el mapa (`#semilla`), así al rehacer un nivel cambian los partidos.
- En el orden de géneros va detrás de «penaltis» y de «preguntas» («un quiz de fútbol» es trivial).
- Prueba: `--solo=soccer`.

## Terror 3D (`kit/horror`, género «terror»)
- Casa en casillas de 2 m: laberinto con atajos y salas, llaves lejos de la entrada, armarios en
  los rincones, puerta de salida que se abre con todas las llaves.
- Monstruo: patrulla, ve en un cono si no hay pared (`sees`), persigue más despacio que tú, pierde
  tu rastro a los 3 s y va a donde te vio; en el armario no te ve (salvo si te vio entrar).
- Vidas: si te pilla vuelves a la entrada con las llaves que tenías; susto en pantalla.
- Primera persona a oscuras con linterna, texturas hechas en el código (papel pintado y tablas),
  latido en la música según lo cerca que esté.
- Bot: camino con coste cerca del monstruo, se esconde si le persigue de cerca y sale cuando se va.
  Calibrado: 43 de 45 casas generadas a la primera (el resto las rehace la fábrica).
- Prueba: `--solo=horror`.

## Conducción 3D (`kit/drive`, género «conduccion»)
- Ciudad en casillas de 10 m (calles en cuadrícula, manzanas y parques), repartos de recoger y
  entregar con tiempo por reparto (sale del camino más largo a la velocidad de una persona).
- Coche arcade (acelerar, frenar, marcha atrás, giro que depende de la velocidad, choques que
  frenan) y tráfico por su carril derecho que gira al azar en los cruces.
- Paciencia en los dos lados: un coche que espera al jugador sigue tras 1,2 s, y el bot rodea a un
  coche parado (sin esto se bloqueaban mutuamente).
- Cámara de persecución, flecha al destino con los metros, baliza amarilla (recoger) o verde
  (entregar), pedales de gas y freno y botones de giro.
- Calibrado: 36 de 36 ciudades. Prueba: `--solo=drive`.

## Parkour 3D, tienda 3D, cubos y battle royale 3D
Sus reglas están explicadas en la cabecera de su código: `kit/obby/obby_game.gd` (parkour),
`kit/market/` (tienda), `kit/voxel/` (mundo de cubos) y `kit/royale/` (battle royale).

## Lecciones del 3D en el móvil
- En `gl_compatibility` la luz rinde más: sol 0,4-0,5 y ambiente 0,2-0,3; sin niebla.
- Con colores por vértice o MultiMesh con colores: `vertex_color_is_srgb = true`.
- Fondo: siempre algo detrás (gradas, edificios, nubes); el vacío negro o gris se ve a medio hacer.
- Botones en pantalla: comprobar en una captura que no se pisan a 720 px de ancho.
- En vertical, para primera persona y pistas anchas: `keep_aspect = KEEP_WIDTH` (el ángulo se
  mide a lo ancho; si no, en el móvil se ve todo por un tubo).
- Las líneas de las pistas se pintan en una imagen hecha en el código (sin archivos); a 16-28
  píxeles por metro basta y se genera en un momento.
- Choques con esquinas: un mapa de distancias en 8 direcciones no debe cortar esquinas, y ver «en
  línea recta» a alguien con cuerpo ancho necesita tres líneas paralelas (si no, se atascan).
- Pistas con curvas: se hacen con una banda de triángulos a lo largo de la línea central
  (SurfaceTool), y las barreras y árboles con MultiMesh.
- Objetos que añaden azar (cajas, disparos): medir con muchas carreras por circuito (8 o más) y
  no con las 3 del analizador, que con azar solo mide ruido. Los eventos de la simulación no
  pueden reutilizar la clave «kind» para otra cosa (`merge` no la sobrescribe y se pierde).
- En directo con dos escenas en el mismo programa (`Online.fake_net_latency`) se prueba todo el
  camino de la red sin servidor; comprobar lo que llega unos fotogramas después, no en el mismo.
