# Novedades de octubre de 2026

## Noviembre 2026 · Pasada por todos los géneros y bots más listos
- ✅ **Matriz de los 118 juegos del kit:** qué tiene cada uno (continuar, pista, tutorial, «cómo se juega», derrota). Rellenados los huecos más claros:
  - **Continuar con anuncio** en 10 juegos más:
    - **más tiempo:** ciudad (+40 s), reparto, pesca, idle (+20 s);
    - **más intentos:** golf (+3 golpes), billar (+2 tiros), «adivina la palabra» (+1 fila), memoria (+6 intentos), tirachinas (+1 pájaro);
    - **más vidas:** torres (la base recupera vidas).
  - Ya son **39** los juegos que dejan seguir.
  - **«Cómo se juega»** en 5 géneros complejos que no lo tenían (mazo, ciudad, granja, gemas y héroes, torre de poder), en 6 idiomas
- ✅ **Bot de la app mejorado:**
  - recorre también a **320 px** (móviles pequeños);
  - pasa **en inglés** (`ORQ_BOT_LANG=en`);
  - mide el **contraste** de los textos (WCAG) y el **tiempo de arranque** (unos 0,2 s) y de fabricar en la demo;
  - las pestañas se pulsan por posición, así sirve en cualquier idioma, y no pulsa nada que borre o cobre en ninguno de los dos idiomas.
- ✅ **Arreglado gracias al bot:**
  - los textos grises pequeños (etiquetas) no llegaban al contraste mínimo (3,5:1) y ahora pasan de 4,5:1;
  - a 320 px el formulario de la prueba A/B se salía de la pantalla;
  - «taller de juegos» salía cortado en la cabecera;
  - las etiquetas cortas de las secciones plegadas se cortaban.

## Noviembre 2026 · Canjear premios, vista previa del regalo, detalle de la clase y app en inglés
- ✅ **Canjear el premio en la tienda**: escribes el código del cliente y la app dice si vale (y lo marca como usado), si ya se usó y cuándo, o si no existe. Recuento de canjeados en la app
- ✅ **«Ver cómo lo verá»** en el juego regalo: los tres momentos que verá la persona, antes de mandar el enlace
- ✅ **Modo clase**: en qué nivel está cada alumno, aviso de quién se atasca (5 intentos o más) y «Vaciar para otro trimestre» sin cambiar el código
- ✅ **La app en inglés** (Cuenta → Idioma, o sola si el móvil está en inglés):
  - Están traducidas todas las pantallas que recorre el bot (pantallas, botones, tipos de juego, guías de Apple y AdMob, monetización) y el plan de redes, que se escribe en inglés.
  - Siguen en español los nombres e ideas de las 156 plantillas y los mensajes de la fábrica mientras fabrica.

## Noviembre 2026 · Revisión con bots y pulido
- ✅ **Bot que recorre la app entera** (`npm run bot` en `app/`). Con el modo demo:
  - entra en todas las pestañas y fichas a 360 y 412 px;
  - pulsa unos 130 botones;
  - apunta errores, desbordes, botones pequeños, textos cortados e imágenes rotas.
- ✅ **Segundo bot que rellena los formularios** de regalo, premio, clase, evento, AdMob, itch.io y cartel, y comprueba el resultado. Pasa 20 de 20.
- ✅ **Arreglado en la app:**
  - el desplegable del tipo de monetización salía diminuto;
  - el archivo .p8 de Apple salía sin estilo y en inglés («Choose file»);
  - los desplegables del regalo salían cortados;
  - la etiqueta de la Lanzadera se veía mal partida y decía «juego(s)»;
  - los chips y los enlaces eran pequeños para el dedo;
  - en la demo, «Compartir enlace» y el cartel no funcionaban porque faltaba la web.
- ✅ **Arreglado en los juegos (revisado en inglés, alemán, francés y español):**
  - con Clase y Estadísticas, Ajustes no cabía y «Cerrar» se salía de la pantalla;
  - las ventanas de Clase y de «¿Te está gustando?» perdían el título al cambiar de paso;
  - «Premio» sin premio salía vacío.
  - Además, todas las ventanas juntan sus filas solas si no caben.
- ✅ **Continuar con anuncio** también en tiro con arco, canastas, penaltis y bolos (+N intentos)
- ✅ **5 plantillas «Para clase»** (tablas, capitales, vocabulario, palabras y parejas); se abren solas al elegir *Para mi clase*

## Noviembre 2026 · Pistas en los juegos de tablero y más «Continuar»
- ✅ **Cartel para la tienda** del premio real: A4 con el premio y un QR al juego, listo para imprimir
- ✅ **Pista** en ajedrez, damas, reversi, conecta 4, ocho locos, mazo, dominó, parchís y hundir la flota: el bot hace tu jugada. La primera es gratis; luego cuesta un anuncio o monedas
- ✅ **Continuar con anuncio** en serpiente (gira hacia un hueco libre), Simón (una vida más) y escalada (el coche de pie y medio depósito)

## Noviembre 2026 · Maratón sin fin y más segundas oportunidades
- ✅ **¿Para qué es tu juego?** en el taller (publicar, negocio, regalo o clase): el ejemplo, Chispa y el paso final se adaptan y te llevan a la sección que toca
- ✅ **Maratón sin fin**: al acabar el último nivel no se termina. «Vuelta 2» empieza otra vez con un giro difícil en cada nivel y una vida de premio (hasta 5). El récord cuenta todos los niveles seguidos
- ✅ **Continuar con anuncio** también en cruzar la carretera, cortar fruta, caída de bloques, topos y el agujero (+15 s)

## Noviembre 2026 · Más anuncios con premio donde tocan
- ✅ **Una vida más** (sudoku, buscaminas, nonogramas, ahorcado) y **+N movimientos** (deslizar, block jam, puzle de piezas) con anuncio al perder, una vez por nivel
- ✅ **Continuar** también en la hélice y en la torre de bloques
- ✅ **Turbo x2 durante 20 s** con anuncio en el idle

## Noviembre 2026 · Estadísticas y modo experto (todos los géneros)
- ✅ **Estadísticas del jugador** (Ajustes → Estadísticas): partidas, niveles superados y % de acierto, mejor racha, nivel más alto, estrellas, tiempo jugado, días jugando y medallas de experto
- ✅ **Modo experto** en el selector de niveles: vuelves a jugar los niveles con un giro difícil fijo (de los que la fábrica ya prueba con los bots para el reto del día). Cada nivel superado da una **medalla de experto** y el doble de monedas

## Noviembre 2026 · Nuevos usos: juegos para negocios y juegos regalo
- ✅ **Premio real para tu negocio**: un cupón de verdad («Café gratis», «10 %») para quien supera el nivel que elijas, con un código distinto para cada jugador y el recuento de ganadores en la app. Se cambia sin publicar otra versión
- ✅ **Juego regalo**: «Para Lucía, de Dani», con un mensaje secreto que aparece al superar un nivel. Se manda con un enlace privado, sin anuncios, y la app avisa cuando lo abren y cuando leen el mensaje
- ✅ **Opinión privada antes que valoración pública**: «¿Te está gustando?». Quien dice que sí va a Google Play; quien dice que no le cuenta al autor qué mejorar (en la app, con un botón para que Chispa lo arregle)
- ✅ **Modo clase para profes**: crean una clase con un código, los alumnos lo escriben en el juego y el profe ve en la app los niveles, estrellas y minutos de cada uno (y descarga las notas en CSV). Sin datos personales
- ✅ **En el ordenador (itch.io)**: descarga tu juego como paquete HTML5 listo para subir a itch.io o a tu web
- Ver NICHOS-LEEME

## Noviembre 2026 · Monetización completa por tipo de juego
- ✅ **Perfil de monetización por tipo de juego** (hipercasual, puzle, arcade, estrategia, idle, tablero, casino e infantil): cada uno con su banner, cadencia de intersticiales, anuncios con premio y compras recomendadas. Ver MONETIZACION-LEEME
- ✅ **Banners de AdMob** (adaptables), con hueco en la interfaz; los 119 géneros revisados con banner en portada, niveles y partida
- ✅ **«Continuar (anuncio)»** al perder en naves, corredor 3D, rompebloques y cuchillos
- ✅ **Anuncio al volver a la app** en los juegos idle
- ✅ **Pack de inicio** (2000 monedas + sin anuncios, 3,99 €) con oferta de bienvenida; ya se crea en Play, lo verifica el servidor y sale en ingresos
- ✅ En la app, la sección de anuncios explica **cómo gana dinero cada juego**, deja elegir otro tipo y pide los bloques de banner y apertura solo si hacen falta
- ✅ **Arreglado:** la portada se ajusta sola si «Jugar» no cabe (banner o móvil bajito)
- ✅ **Arreglado:** la app no compilaba (`npm run build`) por 3 plantillas con una categoría que no existía

## Noviembre 2026 · Tutorial interactivo
- ✅ **Motor de tutoriales**: pasos que señalan un botón o zona con un anillo que late, un texto corto y avanzan solos cuando el jugador hace lo que se pide (pulsar el botón, que pase algo en la partida, que cambie un valor del juego o un toque). No para el juego y se puede saltar. Sale una vez, en el primer nivel
- ✅ **Tutoriales de serie** en torres, táctica, tubos, cajas, sigilo, roguelike, batalla automática y cartas, en los 6 idiomas. En esos géneros sustituye a la ventana «Cómo se juega» (que sigue en el menú de pausa)
- ✅ **La fábrica puede crear el tutorial de cada juego**: el director (IA) escribe los textos con el tema del juego («Toca la arena libre para montar un cañón») y cada uno usa el botón y la forma de avanzar del paso de su género; en los demás géneros escribe pasos que explican. Se traducen con la historia a todos los idiomas del juego

## Noviembre 2026 · «Cómo se juega» en los géneros complejos y capturas que venden el género
- ✅ **Ventana «Cómo se juega»** con 3 reglas cortas en 16 géneros complejos (táctica, imperio, reino, aldea, cartas, batalla automática, lucha, metroidvania, roguelike, mazmorras, torres, supervivencia, duelo de cartas, sigilo, RPG por turnos y tycoon). Sale sola la primera vez que se juega (después del diálogo de historia) y luego está en el menú de pausa. En los 6 idiomas
- ✅ **Capturas de Google Play**: en esos 11 géneros con algo propio, la segunda captura ya no dice «Cada nivel, un reto nuevo» sino lo que los diferencia («Combos: encadena puñetazo, patada y especial», «Gana cartas nuevas y monta tu propio mazo»...), en cada idioma

## Octubre 2026 · Auditoría de la pantalla de juego en los 119 géneros
- ✅ Se fabricó un juego de cada género y se revisó su pantalla de juego a tamaño de móvil (720×1280): botones al alcance del dedo, textos sin cortar y nada fuera de la pantalla. 115 estaban bien; se arreglaron los 4 que no:
  - **Imperio**: la fila de recursos y las pestañas se salían por la derecha
  - **Tycoon**: el botón de gerente era demasiado bajo para el dedo
  - **Ahorcado**: las teclas eran demasiado bajas para el dedo
  - **Flechas**: en los otros idiomas, el botón «Pista» enseñaba el consejo de artillería, que usaba la misma clave de texto
- ✅ **Arreglado: claves de texto repetidas entre géneros**. Además de flechas/artillería, otros 6 pares de géneros compartían clave con distinto significado, así que en los otros idiomas uno de los dos juegos enseñaba el texto del otro (ajedrez «¡Te han pillado!», deslizar el consejo del sigilo, simón «¡El tarro ha rebosado!»...). Cada género tiene ya sus propias claves y sus traducciones
- ✅ **El validador de cada juego fabricado revisa también la pantalla de juego** (nivel 1, móvil de 720×1280), no solo la portada y los niveles: si un botón se sale o un texto no cabe, el juego no se da por bueno
- ✅ Esa revisión encontró 2 fallos más en variantes: en el RPG en modo equipo los botones «Poción» y «AUTO» eran bajos para el dedo, y en supervivencia con giros (zombis, invierno) los botones de fabricar cortaban el nombre («hoguera», «machete»). Por eso la fábrica quitaba esos giros; ya no hace falta
- ✅ En plataformas, un nombre de nivel largo se escribe con letra algo más pequeña para que se lea entero (y si aun así no cabe, termina en «…»)
- ✅ **Prueba nueva** (`fabrica/pruebas/prueba_claves.py`): falla si una clave de texto significa cosas distintas en dos géneros

## Octubre 2026 · Mazmorras con equipo y talentos; reino con previsión
- ✅ **Reino: previsión exacta de la batalla**. Junto al poder de cada bando dice si ganarías y cuántas tropas perderías («Ganas: pierdes 4 tropas» / «Aún no: perderías la batalla»), con las mismas cuentas que el ataque
- ✅ **Arreglado:** en reino, el botón «Mejorar» cortaba el texto cuando el coste llevaba dos recursos; ahora la letra se ajusta
- ✅ **Mazmorras: pantalla «Equipo»** en la portada con lo que llevas en arma, armadura y anillo (rareza y bonus) y **talentos para siempre** que se compran con las monedas de la tienda: vida, daño y cadencia, 5 niveles de +5 % cada uno, cada nivel más caro. Los bots y la validación juegan sin talentos

## Octubre 2026 · La ficha de Play vende lo nuevo de cada género
- ✅ La ficha de Google Play de 11 géneros (lucha, cartas, metroidvania, cajas, tubos, sigilo, roguelike, táctica, batalla automática, aventura y torres) añade una línea con lo suyo («Combos: encadena puñetazo, patada y especial», «Gana cartas nuevas y monta tu propio mazo»…) en los 6 idiomas

## Octubre 2026 · Mejoras en géneros complejos (roguelike, táctica, batalla automática, aventura, torres)
- ✅ **Roguelike: botón «Explorar»**. Anda solo hasta el objeto visto más cercano o lo que falta por descubrir y, al acabar, a la escalera. Se para y avisa si aparece un monstruo o te hacen daño; tocar el mapa o el botón lo detiene
- ✅ **Torres: puntería y siguiente oleada**. Al tocar una torre, además de mejorar y vender, se elige a quién dispara: al primero, al más fuerte o al más cercano. El botón de lanzar oleada dice lo que viene («6 normal  3 rápido  2 acorazado»)
- ✅ **Aventura: historial y colección de finales**. Botón «Historial» arriba con todo lo dicho y lo elegido en el capítulo. Al acabar, el panel dice cuántos finales llevas de ese capítulo (1/3, 2/3...) y cuáles te faltan, para volver a jugarlo
- ✅ **Batalla automática: sinergias y velocidad**. Con 2 unidades del mismo tipo en tu tablero ese tipo gana un extra (guerreros +25 % vida, arqueras +25 % velocidad, caballeros +30 % vida, magos y asesinas +30 % daño, sanadoras +50 % curas) y la parte de arriba dice cuáles tienes activas. Botón ×1/×2/×3 para acelerar los combates (se recuerda)
- ✅ **Táctica por turnos: zona de peligro y previsión de daño**. Al tocar una unidad rival se marca en naranja todo lo que puede atacar el turno que viene (la artillería, solo desde donde está). Con una unidad tuya elegida, cada objetivo enseña el daño que harás (con calavera si lo eliminas) y el contraataque que te llevarás, con las mismas cuentas que el ataque real

## Octubre 2026 · Cartas con colección y lucha con combos
- ✅ **Cartas coleccionables: colección y mazo propio**. Empiezas con las cartas del nivel 1 y cada nivel superado te da una carta nueva (lo dice el panel de victoria). En la portada, «Mazo» abre el editor: 20 cartas de tu colección, como mucho 2 de cada y un solo dragón; se ve el coste y lo que hace cada carta. Tu mazo se juega en la campaña; los bots y la validación usan el del nivel
- ✅ **Metroidvania con mapa grande**: botón junto a la pausa que para el juego y dibuja las salas exploradas casilla a casilla, con monedas, habilidades y llaves que quedan, puertas, bloques rompibles, pinchos, dónde estás y la meta
- ✅ **Lucha con combos**: si un golpe conecta, se puede cancelar en otro más fuerte (puñetazo → patada → especial); el golpe pulsado justo antes se recuerda unos instantes. Sale «Combo x2» en pantalla, cada golpe del combo quita un poco menos y los rivales listos también encadenan. El bot sigue ganando a rivales de nivel alto

## Octubre 2026 · Pistas en los puzles
- ✅ **Botón «Pista»** en cajas, tubos de colores y sigilo: el resolvedor exacto calcula el siguiente paso desde cómo está el tablero y lo hace por ti (en cajas, camina hasta la caja y la empuja). La primera de cada nivel es gratis; después, un anuncio con premio o 25 monedas. Si ya no hay salida lo avisa y no cobra

## Octubre 2026 · Clasificaciones y logros de los modos
- ✅ **Clasificación online de contrarreloj** (una por nivel, por tiempo) y **de maratón** (niveles seguidos): los récords se suben solos si el jugador tiene apodo; el panel de victoria en contrarreloj abre la de tiempos y el fin de la maratón tiene botón «Clasificación». El servidor valida que el nivel exista y que la maratón no supere los niveles del juego (migración `20261031000041_marcadores_modos.sql`)
- ✅ **3 logros nuevos**: Fondista (5 niveles seguidos en una maratón), Maratoniano (completar una maratón) y Contra el reloj (mejorar 3 veces un récord), con monedas y en los 6 idiomas

## Octubre 2026 · Contrarreloj
- ✅ **Contrarreloj en todos los géneros**: interruptor «Contrarreloj» en el selector de niveles (tras superar el primero); cada nivel muestra tu mejor tiempo en vez de las estrellas, la partida lleva reloj y récord (en rojo si vas peor) y el panel de victoria celebra el nuevo récord. Estrellas, monedas y desbloqueos van como siempre. La ficha de Google Play lo anuncia en los 6 idiomas

## Octubre 2026 · Modo maratón
- ✅ **Modo maratón en todos los géneros**: botón «Maratón» en la portada cuando ya se han superado 4 niveles; se juegan los niveles seguidos con 3 vidas, un cartel arriba con vidas y niveles superados, récord guardado y resumen final. Durante la maratón no se puede saltar un nivel. La ficha de Google Play lo anuncia en los 6 idiomas (juegos con 5 niveles o más)
- ✅ La portada coloca los modos nuevos (maratón, 2 jugadores) en la columna con menos botones y los encoge un poco si hay muchos, para que «Jugar» nunca se salga de la pantalla

## Octubre 2026 · Modo 2 jugadores
- ✅ **Modo 2 jugadores en el mismo móvil** para ajedrez, reversi, damas y conecta 4: botón «2 jugadores» en la portada, partida justa (sin las ventajas de la campaña), sin tocar estrellas ni logros, cartel de quién gana y revancha. La ficha de Google Play lo anuncia en los 6 idiomas

## Octubre 2026 · Sigilo por turnos
- ✅ **Sigilo por turnos** (tipo Hitman GO): guardias quietos, que patrullan y que giran, conos de visión, deshacer, maletín y estrellas por movimientos; cada tablero resuelto de forma exacta. Ya hay **120 géneros**
- ✅ El RPG por turnos dibuja suelo y paisaje de reserva solo si la IA no ha pintado el fondo del nivel

## Octubre 2026 · Metroidvania
- ✅ **Metroidvania**: mundo de salas conectadas, doble salto, impulso, martillo y llaves que abren caminos, minimapa y un bot que planifica con vuelta atrás. Ya hay **119 géneros**
- ✅ **Cartas coleccionables más vistosas**: cada carta con su dibujo (lobo, dragón, bola de fuego...), marco del color de su coste, tapete en la mesa, chispazos con el daño y humo al caer un esbirro
- ✅ **Batalla automática**: flechas y bolas mágicas que vuelan, tajos en el cuerpo a cuerpo y piezas más grandes

## Octubre 2026 · Pinball
- ✅ **Pinball** de neón: física propia, palas que empujan según su giro, setas, tirachinas, dianas, pasillos y multiplicador. Ya hay **118 géneros**

## Octubre 2026 · Lucha y fusión de frutas
- ✅ **Lucha** (tipo Street Fighter): puño, patada, cubrirse, especial con barra, asaltos y rivales con estilo propio
- ✅ **Fusión de frutas** (tipo juego de la sandía): física de verdad, frutas que se juntan de la cereza a la sandía y tarro que no debe rebosar. Ya hay **117 géneros**

## Octubre 2026 · Auditoría de todos los géneros
- ✅ Se fabricó un juego de cada género con los bots jugando todos los niveles y se revisaron las capturas a ojo
- ✅ **Arreglado:** en 19 géneros (escalada, tornillos, fútbol, karts, zombis, plantas, duelo...) el validador se paraba tras el nivel 1 porque esos juegos no cuentan «pisotones»; ahora juega todos los niveles (y esos juegos ya tienen reto del día)
- ✅ **Arreglado:** el laberinto decía «Desliza para empujar las cajas» en los otros idiomas (compartía el texto con las cajas)
- ✅ **Arreglado:** la plantilla del roguelike por turnos tenía un estilo de dibujo mal escrito

## Octubre 2026 · Cadena de bolas
- ✅ **Cadena de bolas** (tipo Zuma): caminos en espiral o zigzag, bolas que se meten donde das, explosiones de tres, huecos que se cierran y combos en cadena. Ya hay **115 géneros**

## Octubre 2026 · Comecocos
- ✅ **Comecocos** (tipo Pac-Man): laberintos simétricos sin callejones, cuatro fantasmas con su forma de perseguir, píldoras que los asustan, túnel y tres vidas. Ya hay **114 géneros**

## Octubre 2026 · Artillería
- ✅ **Artillería** (tipo Worms): apuntar arrastrando, viento que cambia cada turno, cráteres en el terreno, caídas al agua, daño a los tuyos y una IA que calcula sus disparos. Ya hay **113 géneros**

## Octubre 2026 · Bombas
- ✅ **Bombas** (tipo Bomberman): explosiones en cruz y en cadena, cajas con premios, salida escondida, monstruos que vagan, persiguen o corren, joystick y tres vidas. Ya hay **112 géneros**

## Octubre 2026 · Roguelike por turnos
- ✅ **Roguelike por turnos** (tipo Pixel Dungeon): niebla, monstruos que despiertan y te persiguen, jefe que guarda la escalera, espadas, armaduras, pociones, subida de nivel y caminar tocando. Ya hay **111 géneros**

## Octubre 2026 · Cartas coleccionables
- ✅ **Cartas coleccionables** (tipo Hearthstone): maná, esbirros con provocar, carga y escudo, hechizos con objetivo, contraataques, fatiga y un rival que remata cuando puede. Ya hay **110 géneros**

## Octubre 2026 · Gemas y héroes
- ✅ **Gemas y héroes** (tipo Puzzle & Dragons): combinas gemas y tus héroes de ese color atacan, con ventaja de colores, cadenas, corazones que curan, especiales que se cargan y monstruos con cuenta atrás. Ya hay **109 géneros**

## Octubre 2026 · Batalla automática
- ✅ **Batalla automática** (tipo Auto Chess): tienda, oro, fundir tres iguales en estrellas, colocar delante y detrás, y combates que se juegan solos contra ejércitos que crecen ronda a ronda. Ya hay **108 géneros**
- ✅ Arreglado: el ahorcado fallaba al fabricarse desde una plantilla

## Octubre 2026 · Estrategia por turnos, mundos y buscador
- ✅ **Estrategia por turnos** (tipo Advance Wars): infantería, tanques y artillería en mapas con terreno, ciudades y cuarteles; capturas en dos turnos, curas, contraataques y un rival que planea cada unidad. Con la barra «Tú contra el rival»
- ✅ **Mundos** en el selector de niveles: de 5 en 5, con su cabecera, sus estrellas y su color; los que aún no has alcanzado, cerrados
- ✅ **Buscador en el catálogo** del taller (sin tildes y por familias: «cartas», «coches», «niños»...) y marca «Nuevo» en los últimos géneros
- ✅ El aviso de las 18:00 recuerda el **reto del día y tu racha**. Ya hay **107 géneros**

## Octubre 2026 · Cuatro clásicos: deslizar, ahorcado, hundir la flota y Simón dice
- ✅ **Deslizar** (el puzle de 15) con el dibujo del juego y el héroe en medio: siempre con solución
- ✅ **Ahorcado con globos**: cada letra que no está revienta un globo; palabra en el idioma de cada jugador (probada en los 6)
- ✅ **Hundir la flota** contra un rival que aprende a cazar, con la barra «Tú contra el rival»
- ✅ **Simón dice**: luces y notas que repetir, cada ronda una más
- ✅ Arreglado: el reto del día borraba el tiempo por nivel del giro «contrarreloj»; ahora sus niveles también llevan su tiempo. Ya hay **106 géneros**

## Octubre 2026 · Reto del día para todos, «Tú contra el rival» y buscar objetos
- ✅ **Reto del día en todos los géneros**: la fábrica hace 7 niveles nuevos (más difíciles que el principio) y los juegan los bots; cada día el juego ofrece uno distinto en cuanto pasas el nivel 1. No toca estrellas ni desbloqueos. **Racha**: superarlo días seguidos sube el premio (de 50 a 110 monedas). Cada versión nueva del taller lo rehace y lo vuelve a probar
- ✅ **«Tú contra el rival»** en ajedrez, reversi, damas y conecta 4: el héroe del juego (con su arte) frente a la máquina, el marcador y el brillo en el lado al que le toca
- ✅ **Buscar objetos**: escenas llenas de cosas y la lista de lo que hay que encontrar, con pistas, tiempo y fallos contados en los niveles altos. Ninguna buscada está tapada ni tiene «gemela». Ya hay **102 géneros**
- ✅ Arreglado: la descripción del reversi pasaba del límite de 80 letras de Google Play

## Octubre 2026 · Reversi
- ✅ **Reversi contra la máquina** (el clásico de fichas blancas y negras): encierra y da la vuelta, con las jugadas posibles marcadas y la media vuelta animada. De 6×6 contra un rival despistado a 8×8 contra uno que piensa dos jugadas; la fábrica comprueba que cada nivel se gana y que la partida dura de verdad
- ✅ Con reglas programables y botón «Probar». Ya hay **101 géneros**

## Octubre 2026 · Ajedrez: el género 100
- ✅ **Ajedrez contra la máquina**: tocas una pieza y se iluminan sus casillas; jaque en rojo y el peón corona dama (sin enroque ni captura al paso). Cada nivel sube una escalera de ventaja: al principio al rival le faltan la dama y las torres y se equivoca a menudo; al final, partida completa contra un rival que piensa dos jugadas. La fábrica juega cada nivel entero y solo lo da por bueno si tu bot da jaque mate
- ✅ Con reglas programables y botón «Probar». Ya hay **100 géneros**

## Octubre 2026 · Reglas programables en todos los géneros
- ✅ **Los 98 géneros de plantilla admiten reglas**: los que no tenían ni simulación propia ni mandos (serpiente, memoria, puzles, shooters, RPG...) ganan el mando **velocidad de la partida** (cámara lenta o rápida, de 0,5 a 1,5). Ejemplo: «al perder una vida, 3 segundos de cámara lenta». Los bots vuelven a jugar el juego con la regla puesta antes de darlo por bueno
- ✅ Arreglado: los golpes de efecto (pausa corta al chocar) ya no deshacen la cámara lenta de una regla

## Octubre 2026 · Camino a Google Play y Lanzadera más fuerte
- ✅ **Camino a Google Play** en la ficha de cada juego: 7 pasos (jugarlo, anuncios, preparar, prueba cerrada, probadores, 14 días, producción), cuál toca ahora y su botón. Al terminar el primer juego, el taller lleva directo ahí
- ✅ **Lanzadera**: plazas de reserva (12 + 6), fecha estimada para pedir producción y aviso si estás en riesgo; racha y **recordatorio a las 19:00** para los probadores; y las **respuestas al cuestionario de producción de Google** escritas con los datos reales de la prueba (probadores, días, niveles, opiniones y versiones), listas para copiar
- ✅ **Probar con amigos**: prueba interna de Google Play (hasta 100, sin revisión) con su enlace para compartir
- ✅ **Blindaje**: auditoría automática de la base de datos (todas las tablas con seguridad por filas, funciones con ruta fija y solo lo público ejecutable sin cuenta), disparadores sin permiso para nadie, y todos los scripts del kit en ASCII y con tabuladores. Lo que queda para ti, en `LO-QUE-TE-TOCA.md`

## Octubre 2026 · Dominó, bloques de colores y tuberías
- ✅ **Dominó** (doble seis, a robar) contra 1 a 3 rivales: tocas una ficha y, si encaja por las dos puntas, eliges cuál. Como en cartas locas, la fábrica simula la partida (copia exacta en Python) y solo usa mazos con los que se puede ganar
- ✅ **Bloques de colores** (tipo Color Block Jam): arrastra cada bloque por los huecos hasta la puerta de su color; sale si cabe. Tableros que siempre se pueden vaciar y en los que hay que pensar el orden; pasos contados en la segunda mitad
- ✅ **Tuberías**: gira las piezas hasta que el agua del grifo llegue a todas sin fugas. Cada tablero sale de una solución completa, así que siempre se puede
- ✅ Los tres con reglas programables. Ya hay **99 géneros** (28 con reglas)

## Octubre 2026 · «Probar» antes de fabricar y reglas en los géneros clásicos
- ✅ **Probar** en cada tipo de juego del taller: abre al instante una partida de muestra de ese género (sin instalar nada, directa al nivel 1). Las muestras se fabrican y suben solas en cada despliegue (solo las que faltan)
- ✅ **Reglas programables en plataformas, runner, volador, hordas, torres y carreras** («reglas vivas»): la IA cambia la velocidad, el salto, la gravedad, la velocidad de los enemigos, el daño o la cadencia según lo que pasa en la partida, y los bots lo vuelven a comprobar. Ya son **25 géneros con reglas**. Todo en `PROBAR-Y-REGLAS-LEEME.md`
- ✅ Arreglado: los ganchos originales de géneros con guion bajo (`cartas_locas`) no se reconocían

## Octubre 2026 · 2048 y cartas locas
- ✅ **2048**: desliza y junta números hasta la ficha objetivo de cada nivel (de 64 a 512), tableros de 5×5 con rocas que cortan las filas y dos «deshacer» (el azar también vuelve atrás). El bot mira dos jugadas por delante
- ✅ **Cartas locas** (el juego de cartas de colores de toda la vida, con nombres propios): mismo color o número, +2, salta, reversa, comodín y comodín +4 contra 1 a 3 rivales. El mazo de cada nivel viene ordenado: la fábrica simula la partida (copia exacta del kit en Python) y solo usa mazos con los que se puede ganar
- ✅ Pintar por números: números de los cuadritos con letra más clara. Ya hay **96 géneros**

## Octubre 2026 · Seis géneros nuevos y calculadora de ganancias
- ✅ **Diferencias**: dos dibujos casi iguales (parque, mar, espacio, cocina, ciudad) hechos con figuras por datos; colores, cosas que faltan, que crecen, se mueven o se dan la vuelta; pistas y fallos contados
- ✅ **Rompecabezas**: el dibujo, con el **héroe del juego en medio**, partido en piezas desordenadas; se cambian tocando o arrastrando, las que encajan se quedan fijas y el analizador calcula el mínimo de cambios exacto
- ✅ **Pintar por números**: 12 dibujos de cuadritos y, cada tres niveles, **el héroe del juego convertido en dibujo para colorear**; cubos que pintan todo un color
- ✅ **Lanza cuchillos** (tipo Knife Hit): troncos que giran, frenan y cambian de sentido, manzanas y jefes cada cinco niveles
- ✅ **Arquero** (tipo Archero): salas de enemigos, el héroe dispara solo cuando se para y eliges 1 de 3 habilidades por sala; el bot juega cada nivel entero antes de darlo por bueno
- ✅ **Flechas** (tipo Arrows / Tap Away): un tablero lleno de flechas; cada una sale volando si nadie le corta el paso. Siempre con solución y con pocas libres al empezar
- ✅ Los seis con **reglas programables** (capa 2). Ya hay **94 géneros**
- ✅ App: **«¿Cuánto podría ganar?»** en la pestaña Publicar de cada juego: descargas al día, cuánta gente vuelve y dónde juega → horquilla de euros al mes (anuncios y tienda), con los datos reales de tu juego cuando los hay. Todo en `NUEVOS-GENEROS-LEEME.md`

## Octubre 2026 · Marketing que promociona solo y torre de poder
- ✅ **Web que crece sola en Google**: una página por tipo de juego en español e inglés y una por cada juego del escaparate (datos VideoGame para Google), sitemap y robots, rehecha cada día
- ✅ **Una publicación al día** de Orquestador en Bluesky, Mastodon, Telegram, Discord, X y Reddit con sus APIs oficiales y límites anti-spam; **borradores de respuesta** a conversaciones donde ayudamos (te llegan al Telegram; nunca se publican solos); **creadores** de YouTube con correo listo; **plan de Google Ads** con CSV para el Editor
- ✅ En cada juego: **promoción cruzada** («Más juegos» del mismo creador) y **avisos de vuelta propios** (tiradas llenas, energía llena, caja de los gerentes llena, obra terminada). Todo en `MARKETING-LEEME.md`
- ✅ **Torre de poder** (tipo los anuncios de Hero Wars): vence a quien tiene menos poder, absorbe el suyo, suma premios y derrota al jefe. Ya hay **88 géneros**

## Octubre 2026 · Géneros hechos a medida (capa 3)
- ✅ Si la idea no encaja en ningún género, en el taller se marca «Inventar un género nuevo solo para este juego (beta)»: Claude programa las reglas, el analizador, el generador de niveles y el bot de ESE juego, la fábrica lo revisa por seguridad, genera los niveles y los bots lo juegan entero; si algo falla, le pasa los errores y lo corrige (hasta 3 rondas). Si no sale, el juego usa la plantilla probada: nunca un juego roto
- ✅ Todo en GDScript dentro del proyecto del juego (no toca el kit de todos ni ejecuta Python escrito por la IA). Detalles en `A-MEDIDA-LEEME.md`

## Octubre 2026 · Multitud, fusión con pedidos y reglas en más géneros
- ✅ **Multitud** (tipo Count Masters y el anuncio de Last War): puertas que suman o multiplican, trampas, grupos enemigos y jefe final; el jefe se calcula contra el mejor camino posible
- ✅ **Fusión con pedidos** (tipo Gossip Harbor / Merge Mansion): generadores, objetos que se fusionan, clientes con encargos y energía que se recarga (o con anuncio)
- ✅ **Reglas programables** (capa 2) en tycoon, tragaperras, reino, multitud, pedidos, palabra y letras: la IA puede cambiar la mecánica de esos juegos y los bots la comprueban. Ya hay **86 géneros**. Todo en `POPULARES-LEEME.md`

## Octubre 2026 · Reino tipo Kingshot y tablero tipo Monopoly Go
- ✅ **Reino** (estrategia tipo Kingshot / Whiteout Survival): ciudad con castillo, producción y cuarteles que **entrenan tropas solas en tiempo real**, un constructor con ayuda gratis y «terminar ya» con anuncio, piedra-papel-tijera de tropas, héroes y campamentos hasta el jefe. Cada campamento se mide contra tu ejército de ese momento: 24 de 24 niveles justos
- ✅ **Tragaperras estilo dados** (giro `dados`, tipo Monopoly Go): dos dados, una ficha que da la vuelta al tablero, salida que paga, impuestos, cofres y asaltos
- ✅ La IA inventa el reino de cada juego (un reino helado con trineos de lobos y yetis). Ya hay **84 géneros**. Todo en `REINO-LEEME.md`

## Octubre 2026 · Tycoon y casino social
- ✅ **Tycoon** tipo AdVenture Capitalist: negocios, gerentes, mejoras, el doble de rápido a las 25 unidades, ganancias sin conexión (x2 con anuncio) e inversores entre niveles
- ✅ Estilo **mina** tipo Idle Miner: pozos, ascensor y almacén con cuello de botella
- ✅ **Tragaperras con aldea** tipo Coin Master: tiradas que se recargan, bonus de cofres y de asalto, aldea que construir. Monedas de mentira, nunca infantil y declarada en Play como simulación de apuestas (+18)
- ✅ La IA inventa los negocios, los símbolos y la aldea de cada juego; la fábrica calibra cada nivel con la simulación. Ya hay **83 géneros**. Todo en `TYCOON-CASINO-LEEME.md`

## Octubre 2026 · Juegos de palabras
- ✅ **Adivina la palabra** (tipo Wordle): letras verdes, amarillas y grises, teclado con pistas, modo difícil y una pista por nivel
- ✅ **Palabras con letras** (tipo Wordscapes): rueda de letras para deslizar el dedo, crucigrama que se monta solo, palabras extra que dan monedas, barajar y pistas
- ✅ Los dos en **6 idiomas a la vez** con diccionarios propios (30.000 palabras por idioma, sin nombres propios ni palabrotas): cada jugador juega en el suyo. Ya hay **81 géneros**. Todo en `JUEGOS-PALABRAS-LEEME.md`

## Octubre 2026 · Estrategia y carreras por datos
- ✅ **Imperio**: tropas, edificios, edades y recursos por datos, con los papeles de siempre para que la IA rival y el bot sigan jugando bien. Estilos **fantasía** (elfas arqueras, jinetes de grifo, gólems) y **galáctico** (marines, motos aéreas, tanques de asedio)
- ✅ **Karts**: objetos de la ruleta por datos con 4 efectos (perseguir, trampa, turbo y la nueva **estrella**) y cargas. Estilo **fiesta** tipo Mario Kart con estrella y cáscara triple
- ✅ La IA puede inventar los nombres y números del imperio y los objetos de los karts de cada juego. Todo en `PLANTILLA-ESTRATEGIA-CARRERAS-LEEME.md`

## Octubre 2026 · Shooters por datos: hordas tipo Survivor.io y Vampire Survivors
- ✅ **Las hordas son una plantilla**: 8 formas de atacar (disparo, abanico, órbita, halo, anillo, rayo en cadena, bombas y látigo), mejoras de área y de proyectiles extra y **evoluciones de armas** (arma al máximo + su mejora)
- ✅ **Dos estilos** (giros): **survivor** (kunai, drones, relámpago, guardianes) y **vampiros** (látigo, ajo, agua bendita, libro)
- ✅ **Zombis 3D**: armas, arma de inicio, armas que se recogen y zombis por datos
- ✅ La IA puede inventar las armas de cada shooter, igual que el contenido del RPG y la supervivencia. Todo en `PLANTILLA-SHOOTERS-LEEME.md`

## Octubre 2026 · La IA inventa el contenido de cada juego
- ✅ En el RPG y la supervivencia, la directora puede **inventar el contenido de cada juego**: héroes, habilidades y enemigos, u objetos, recursos, recetas y criaturas, con nombres del tema (una tripulación pirata, un planeta de cristal...). Así dos juegos del mismo género ya no tienen por qué parecerse
- ✅ Es solo datos con márgenes: se comprueba, los bots juegan cada nivel con ello y, si no sale justo, la fábrica vuelve al estilo probado y apunta la lección para la próxima vez
- ✅ Primer paso hacia «cualquier juego»: después vendrán las reglas programables en todos los géneros y los géneros nuevos que la IA escribe sola

## Octubre 2026 · RPG de equipo y de criaturas
- ✅ **El RPG por turnos tiene modo equipo** (plantilla por datos): hasta 4 héroes con habilidades y esperas, turnos por velocidad con la barra de quién actúa, elementos (fuego, agua, planta, luz y oscuridad), estados (veneno, quemadura, aturdir, provocar, mejoras), escudos, pociones y botón **AUTO**
- ✅ **Dos estilos** (giros de la fábrica): **equipo** (tipo Raid / Summoners War / AFK Arena: guerrero, maga, sanadora y arquero) y **criaturas** (tipo Pokémon: uno contra uno con tres criaturas de fuego, agua y planta y cuatro movimientos)
- ✅ La fábrica comprueba cada nivel con una copia exacta de las reglas en Python y ajusta las oleadas hasta que la dificultad es la que toca. Calibrado: 72 de 72 niveles por estilo
- ✅ El RPG de un héroe de siempre sigue igual. Todo en `PLANTILLA-RPG-LEEME.md`

## Octubre 2026 · Plantilla de supervivencia: cualquier juego de supervivencia de móvil
- ✅ **La supervivencia ahora es una plantilla de datos**: objetos, casillas del mapa, recetas, criaturas, frío, mochila y herramientas que se gastan se describen en `game.json`; el juego, el bot y el analizador los leen. Sin datos, la isla de siempre, igual que antes
- ✅ **Tres estilos hechos** (giros de la fábrica, se pueden juntar dos): **apocalipsis** (tipo Last Day on Earth: saquear casas y coches, zombis que no temen al fuego, machete, muros, vendas y una radio para escapar), **invierno** (frío de noche; hoguera, cama o abrigo de piel) y **caza** (ciervos que huyen, jabalíes que embisten, carne cruda que enferma y se asa en la hoguera)
- ✅ Mecánicas nuevas: cocinar, enfermar y curarse, mochila con límite (y tirar cosas), herramientas con usos que se rompen, construir muros que ningún bicho cruza, metas por receta y **partida guardada al amanecer** (si sales, sigues ese día donde lo dejaste)
- ✅ En 2D y en 3D: casas, coches, zombis, ciervos, jabalíes, muros, nieve y selva; botones de fabricar sacados de las recetas (en fila deslizable si hay más de 4)
- ✅ Calibrado: 48 de 48 niveles en cada estilo y en zombis + invierno. Arreglo de paso: junto a la hoguera el bot echaba leña en vez de beber; la isla de siempre pasa de 42 a 48 de 48
- ✅ Textos nuevos en los 5 idiomas del catálogo. Todo en `PLANTILLA-SUPERVIVENCIA-LEEME.md`

## Octubre 2026 · Los más jugados: duelo de cartas, escalada, tirachinas, plantas y bus jam
- ✅ **Género 75: bus jam** (pasajeros que salen al autobús de su color, parada de espera y VIP). Calibrado: 288 de 288 niveles
- ✅ **Género 76: duelo de cartas en 3D** (tipo Clash Royale): arena con río y puentes, torres, elixir, 12 cartas, rival con IA y mazo que crece. Calibrado: 192 de 192
- ✅ **Género 77: escalada** (tipo Hill Climb Racing): coche con suspensión y física propia, gasolina, vueltas en el aire y taller de mejoras. Calibrado: 144 de 144
- ✅ **Género 78: tirachinas** (tipo Angry Birds): derrumbes con física real, 4 pájaros con poderes, TNT. El bot gana 94 de 96 niveles
- ✅ **Género 79: plantas contra zombis** en vertical: soles, 7 plantas, 4 zombis y cortacéspedes. Calibrado: 141 de 144
- ✅ **79 géneros** en total

## Octubre 2026 · Hexa sort e iconos dibujados por la IA
- ✅ **Género 74: hexa sort** (tipo Hexa Sort): tablero de panal en diagonal, 3 pilas de hexágonos para elegir (se arrastran o se toca y se toca), las vecinas del mismo color se juntan en cadena con las fichas saltando en arco de una pila a otra, torres de 10 que estallan, piedras, pilas ya puestas y martillo para romper una pila. Calibrado: 240 de 240 niveles generados aceptados; textos en los 5 idiomas y miniatura en la app
- ✅ **Iconos de interfaz con el arte de cada juego**: vidas, estrellas y trofeos dibujados por la IA en el estilo del juego, revisados uno a uno (silueta clara y simétrica). El que no pasa el control sigue siendo el de siempre; los de mando (pausa, atrás…) no cambian para que se entiendan siempre
- ✅ **74 géneros** en total

## Octubre 2026 · Puzle de tornillos, triple de fichas y repaso de interfaces
- ✅ **Género 72: triple de fichas** (tipo Tile Master): montón por capas, bandeja de 7, tres iguales desaparecen, deshacer y barajar que siempre deja la partida ganable; 12 dibujos con forma y color distintos
- ✅ **Género 73: puzle de tornillos** (tipo Screw Jam): placas de colores atornilladas unas sobre otras, tornillos que van a la caja de su color o a la espera, placas que caen girando, cajas de tres en tres y ayuda de hueco extra. Calibrado: 960 de 960 niveles generados aceptados; textos en los 5 idiomas y miniatura en la app
- ✅ **Repaso de la interfaz de los 72 juegos** con una auditoría automática en cada captura (botones pequeños, textos cortados, fuera de la zona segura, letra de menos de 18 px y textos apagados). Arreglado: el botón de derrape de los karts se salía por la derecha, la barra de arriba del battle royale empujaba la pausa fuera de la pantalla, el botón de pista del sudoku era pequeño para el dedo, las cartas del mazo (título que pisaba el coste y descripción diminuta), el nombre del nivel en plataformas y runner (apagado sobre el cielo) y la letra de fabricar en supervivencia

## Octubre 2026 · Supervivencia en 3D y 2D
- ✅ **Género 71: supervivencia** (tipo Don't Starve / Last Day on Earth): una isla con hambre y sed, recoger madera, piedra, fibra y bayas, fabricar hacha, lanza y hoguera, noches con lobos que no se acercan al fuego y niveles en los que hay que construir una balsa para escapar
- ✅ Nace en **3D** (isla low-poly, sol que baja, luz real de la hoguera) y se puede pasar a 2D en el taller; mismas reglas, bot y analizador en las dos vistas
- ✅ Calibrado: 55 de 60 islas generadas aceptadas a la primera (fácil 20/20, normal 20/20, difícil 15/20); textos en los 5 idiomas del catálogo y miniatura en la app

## Octubre 2026 · App más sólida: errores claros, datos por áreas y arranque más rápido
- ✅ **Errores claros en toda la app**: un solo sitio decide el mensaje (nunca el texto técnico), «Sin conexión» se reconoce aunque venga envuelto, botón **Reintentar** en las pantallas que no cargan y en avisos que se pueden repetir, y los fallos no previstos ya no se pierden en silencio
- ✅ **Capa de datos por áreas** (cuenta, comunidad, juegos, publicar, jugadores, tienda, lanzadera) en lugar de un archivo de 1.200 líneas; comprobado que los 79 métodos hacen exactamente las mismas peticiones que antes
- ✅ **Arranque más ligero**: cada pestaña se carga al abrirla (las demás se adelantan en segundo plano); el código que baja al abrir la app pasa de 136 KB a 74 KB comprimido

## Octubre 2026 · Karts con objetos y carreras online
- ✅ **Objetos en los karts**: cajas en la pista con cáscara (va a por el de delante), plátano (trampa detrás) y turbo; quien recibe trompea un momento y llevar un objeto en la mano te protege de una cáscara. El objeto depende del puesto (los de atrás, más turbos) y la IA esquiva plátanos
- ✅ Calibrado: con objetos el bot sigue ganando casi lo mismo (93 / 86 / 81 % en fácil, normal y difícil frente a 98 / 87 / 80 % sin objetos)
- ✅ **Karts online con amigos**: hasta 4 pilotos en directo (salas públicas o con código), misma parrilla en todos los móviles, nombre encima de cada kart, cáscaras y plátanos que cruzan la red, bots del anfitrión en los huecos (si se va, otro los coge) y trofeos por tu puesto entre personas
- ✅ Servidor: los juegos de karts tienen salas en directo (migración 37, con su prueba)

## Octubre 2026 · Karts 3D y zombis en cooperativo online
- ✅ **Karts 3D**: circuitos generados (rectas, curvas abiertas y horquillas, sin cruces), 6 karts, vueltas y posición en directo, derrape que carga un turbo azul, naranja o morado, placas de turbo, hierba que frena, barreras de neumáticos, gradas y minimapa; el kart acelera solo (izquierda, derecha y DERRAPE)
- ✅ **Zombis 3D en cooperativo online**: hasta 4 amigos en la misma arena contra las oleadas (salas públicas o con código); más zombis cuantos más sois, quien cae vuelve en la oleada siguiente y se pierde si caen todos a la vez; si el anfitrión se va, otro sigue moviendo los zombis
- ✅ Servidor: las salas de los juegos de zombis son siempre cooperativas y sin trofeos (migración 36, con su prueba)
- ✅ **70 géneros** en total

## Octubre 2026 · Shooter de zombis, baloncesto y tenis en 3D
- ✅ **Zombis 3D en primera persona**: oleadas, pistola, escopeta y fusil, recarga, botiquines, corredores y brutos
- ✅ **Baloncesto 3D callejero**: de 1 contra 1 a 3 contra 3, tiro con barra, robos, tapones, triples y reglas de la calle
- ✅ **Tenis 3D**: saque, globos, voleas y tanteo de verdad

## Octubre 2026 · Más 3D: deportes, terror y conducción
- ✅ **Fútbol 3D**, **terror 3D** (tipo Granny / DOORS) y **conducción 3D** con repartos por la ciudad

## Octubre 2026 · Los 3D que más se juegan
- ✅ **Parkour 3D (obby)**, **battle royale en 3D** y **tienda 3D (tipo My Mini Mart)**

## Octubre 2026 · 3D, cofres y battle royale en directo
- ✅ **Mundo de cubos en 3D**, **battle royale en directo** (hasta 8), **cofres y ruta de trofeos**, **pantalla tipo lobby**, **34 idiomas**

## Octubre 2026 · Juegos grandes y originalidad
- ✅ Mundo abierto 2D, battle royale, cruzar, tiro con arco, reglas programables, originalidad, música que respira, catálogo con capturas reales, entrar con Google y más

## Siguiente
- ⬜ Reglas vivas también en naves, rompebloques y el resto de géneros con escena
- ⬜ Karts: más objetos (estrella, rayo) y circuitos con saltos
