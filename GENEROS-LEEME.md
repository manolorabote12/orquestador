# Cómo añadir un género nuevo

Hoy hay 120 géneros (119 de plantilla y el «a medida») (la lista completa está en `fabrica/generos.py`). Los primeros: plataformas, runner, volador, hordas, puzle de combinar 3, torres, carreras
(2D o 3D), naves (matamarcianos), rompebloques, bloques (encajar piezas), corredor 3D (tres
carriles), serpiente, memoria (parejas), cajas (sokoban), preguntas (trivial con contenido que
escribe la IA), apilar (torre de un toque), topos (aplasta a los que asoman), saltos (sube
rebotando), arena (todos contra todos: el último en pie gana), aldea (asalta bases con tu ejército),
ritmo (notas a tiempo en 4 carriles), clicker (toca y contrata ayudantes), cartas (solitario Golf),
RPG por turnos, laberinto (llaves, puertas y pinchos), minigolf (tirachinas con rebotes, agua y
arena), pesca (anzuelo a tiempo entre peces y medusas), fusión (suelta piezas y junta iguales) tubos
(ordenar colores: pasa colores de un tubo a otro, con solucionador que calcula el par) y burbujas
(bubble shooter: apuntar con rebotes, explotar y hacer caer racimos; el analizador juega con el bot)
e **imperio** (estrategia en tiempo real tipo Age of Empires / Guerras Tribales: aldeanos que
recogen comida, madera y oro, 9 edificios, 3 edades, piedra-papel-tijera entre lanceros, arqueros
y jinetes, arietes, mercado, campana para esconder a los aldeanos y una IA rival con su propia
economía que ataca por oleadas; ver «Imperio» más abajo), **minas** (idle de excavar tipo Idle Miner)
y **mazmorras** (RPG de acción tipo Archero con habilidades y botín), **granja** (cozy tipo Hay Day),
**mazo** (cartas de estrategia tipo Slay the Spire) y **aventura** (historia con decisiones).
En los seis últimos el juego, el bot y el analizador usan **las mismas funciones** de reglas
(`<kit>_map.gd`), y la fábrica tiene una copia exacta en Python para calcular el par del hoyo, el
tiempo de la pesca o la meta de la fusión con lo que el bot consigue de verdad. Añadir el siguiente ya no es tocar 25 archivos. Hay **un registro** en cada lado y **un comando**
que crea el esqueleto conectado en toda la cadena.

| Dónde | Archivo | Qué dice |
|---|---|---|
| Fábrica | `fabrica/generos.py` | Qué admite cada género (jefe, disparo, poderes, enemigos…), sus textos, cómo se pide, su generador de niveles y su frase para Google Play |
| Kit (Godot) | `orqkit/kit/genres.gd` | Qué escena, qué analizador y si el bot debe ganar a la primera |
| Servidor | `supabase/functions/_shared/cambios-datos.ts` | Copia automática del registro (`python sincronizar_servidor.py`) |

La directora, el taller de Chispa, el servidor, la cadena y la ficha de la tienda leen de esos
registros. No hay listas de géneros repetidas por el código.

## 1. Crear el esqueleto (1 minuto)

```powershell
cd fabrica
python -m nuevo_genero laberinto maze `
  --claves laberinto,mazmorra,maze `
  --etiqueta "laberinto: recoge todo sin pincharte" `
  --frase-es "Recorre laberintos y recoge cada moneda sin pisar los pinchos" `
  --frase-en "Explore mazes and grab every coin without touching the spikes" `
  --probar
```

- El primer nombre es el de la fábrica (en español); el segundo, el del kit (en inglés).
- `--claves`: palabras de la idea que eligen este género.
- `--probar`: fabrica un juego de prueba entero (directora y arte simulados) y comprueba que los
  bots lo pasan. Debe terminar con `PRUEBA SUPERADA`.
- `python -m nuevo_genero --quitar laberinto maze` lo deshace todo, byte a byte.

El comando crea:

| Archivo | Para qué |
|---|---|
| `orqkit/kit/<kit>/<kit>_game.gd` | Las reglas del juego. La plantilla ya es un juego completo: cuadrícula vista desde arriba, deslizar para moverse, recoger monedas y evitar pinchos |
| `orqkit/kit/<kit>/<kit>_map.gd` | El analizador: comprueba **sin jugar** que un nivel es justo |
| `orqkit/qa/<kit>_bot.gd` | El bot que juega los niveles con las reglas reales |
| `orqkit/scenes/<kit>.tscn` | La escena |
| `generar_<es>()` al final de `fabrica/niveles/generador.py` | El generador de niveles |

Además, el comando:
- registra el género en `generos.py` y en `genres.gd`;
- lo añade a los dos esquemas de la directora y del taller;
- sincroniza el servidor.

## 2. Cambiar la plantilla por tu género

Hazlo siempre en este orden, y con las pruebas en verde después de cada paso.

1. **Las reglas** (`<kit>_game.gd`). Cambia la mecánica, pero no rompas el contrato con el kit:
   - `finished`, `deaths`, `time_in_level`, `fast`, `auto_retry`;
   - `bot_script()`, `bot_state()`, `retry()`, `open_pause()`;
   - `ResultPanel.open(...)` al ganar y `FailPanel.open(...)` al perder.
   - Así funcionan solos el título, los niveles, las estrellas, el premio diario, la tienda, las capturas, la ficha y el validador.
2. **El analizador** (`<kit>_map.gd`). Escribe lo que hace que un nivel sea injusto o imposible.
   Cada problema que encuentres será una regla del generador.
3. **El bot** (`<kit>_bot.gd`). Debe jugar como una persona normal, no como un dios. Si el bot gana
   con la física real, el nivel es jugable.
4. **El generador** (`generar_<es>`). Construye niveles que el analizador y el bot acepten, con
   dificultad que sube por nivel y por `dificultad`.
5. **El registro** (`generos.py`). Revisa estos campos:
   - `jefe`, `disparo`, `poderes`, `extras`, `enemigos`: qué admite el género.
   - `estricto`: el bot debe ganar a la primera o a la segunda (hazlo así si el género no es de habilidad pura).
   - `parametros`: datos extra por nivel, como tiempo, movimientos u oro.
   - `textos`: textos de la interfaz con tildes.
6. **La directora**. Añade una regla en `director/prompt_director.md` que explique cuándo elegir este
   género, igual que las reglas 18 y 19.

## 3. Calibrar con lotes

Fabrica muchos niveles de golpe y mira cuántos pasa el bot a la primera. Con todos los géneros
apuntamos a 108 de 108, con 3 dificultades, 3 sensaciones y 12 semillas.

```powershell
python -m pruebas.prueba_cadena
python -m pruebas.prueba_taller
python -m pruebas.prueba_genero
godot --headless --fixed-fps 60 res://qa/test_runner.tscn   # dentro de orqkit
```

## 3b. O que lo haga el agente de IA

`python -m agente_genero "sokoban: empujas cajas hasta sus huecos" sokoban sokoban` hace los pasos 1 y 2 solo.
Claude reescribe la plantilla, se revisa la seguridad del código, se prueba con un juego entero y, si
falla, le devuelve los errores (hasta 4 rondas). Detalles en `APRENDIZAJE-LEEME.md`.

## 4. Lo que no hace sola la IA (y por qué)

La IA elige el género y lo decora: personajes, mundo, textos, música y dificultad. **No se inventa
las reglas de un género nuevo en tiempo real**, porque nadie habría probado esas reglas. Cada
género tiene su analizador, su bot y su generador validados por lotes. Eso es lo que garantiza
que ningún juego salga roto ni imposible, y es la diferencia con las herramientas que generan
código y cruzan los dedos.

## Los 4 últimos: qué tienen de especial

- **Ritmo** (`kit/rhythm/`): el mapa es la canción (una fila por corchea, 4 letras). El generador
  compone por frases de 8 pasos que se repiten con variaciones; el analizador limita acordes y
  notas pegadas en un carril. El bot toca con hasta 50 ms de error.
- **Clicker** (`kit/idle/`): el mapa son los ayudantes («coste:ganancia por segundo»). La meta la
  pone una simulación de una persona normal (4 toques/s, compra lo que más renta) en el 70 % del
  tiempo; el analizador repite la simulación (Python y GDScript hacen lo mismo).
- **Cartas** (`kit/cards/`): las reglas están en `cards_logic.gd` (sin dibujo), con un buscador de
  soluciones que usan el analizador y el bot; el generador solo acepta repartos con solución que
  no salgan jugando a ciegas.
- **RPG por turnos** (`kit/turns/`): reglas y política «sensata» en `turns_logic.gd`; el analizador
  juega la partida con daño medio y con mala suerte (−10 % / +10 %) y exige ganar en los dos.

## Ideas de géneros que encajan bien con la plantilla

- Laberinto y mazmorra.
- Sokoban (empujar cajas).
- Serpiente.
- Rompeladrillos.
- Endless de esquivar en carriles.
- Pesca.
- Golf de un toque.


## 5. Detalles que conviene saber
- `nuevo_genero` mete el género nuevo **al principio** de `ORDEN` (generos.py), que decide qué
  género gana cuando una idea encaja con varios. Si sus claves contienen las de otro (p. ej.
  "rompebloques" contiene "bloques"), ordénalo a mano: el más específico primero.
- Las fotos de la ficha: si el género define `capture_delays() -> Vector2` en su escena, las
  capturas se hacen a esos segundos (p. ej. con la oleada en pantalla). Si no, valores por defecto.
- Juegos en 3D (carreras 3D, corredor 3D, plataformas/runner/volador 2.5D): la lógica sigue en
  2D/metros y una vista `*_view3d.gd` la dibuja. Así el analizador y el bot son los mismos y todo lo
  validado sigue valiendo. La de plataformas (`kit/platformer/platformer_view3d.gd`) es un «espejo»
  genérico: crea un gemelo 3D de cada sprite, polígono, texto y partícula 2D y esconde el 2D con
  `canvas_cull_mask`; sirve de modelo para pasar a 3D cualquier género con escena 2D.
- Qué géneros admiten vista 3D y con cuál nacen: `generos.VISTA_3D` (se sincroniza al servidor).
- Probar solo una batería del kit: `godot --headless res://qa/test_runner.tscn --fixed-fps 60 -- --solo=shooter`.

## Géneros con contenido de la IA (preguntas)

El juego de preguntas es el primero cuyo contenido escribe la directora: `diseno.preguntas`
(de 3 a 8 por nivel, de fácil a difícil, 4 opciones, la correcta y una explicación). El generador
reparte las preguntas por niveles (`reparto_preguntas`) y `parametros_preguntas` las baraja siempre
igual, pone el tiempo por pregunta y los aciertos para pasar. El taller tiene la operación
`preguntas` para cambiarlas. Para géneros así: valida el contenido en `director.validar` (y en
`plan-logica.ts`), y que el analizador del kit compruebe el formato.

## Editor manual de niveles

`generos.EDITOR` dice qué géneros se pueden dibujar a mano en la app (letras, obligatorias y
tamaño). Hoy: plataformas, runner, volador, rompebloques y cajas. Para añadir uno: su entrada en
`EDITOR`, sus piezas en `app/src/editor.ts` (`PIEZAS` y `REGLAS`) y, si hace falta, cómo
dibujarlas en `vistas/editor.ts`. Los niveles a mano no se rehacen: si el analizador o el bot no
los superan, el cambio falla con la explicación (`cadena.PROBLEMAS_NIVEL`) y se devuelven las tuercas.



## Imperio (estrategia en tiempo real)

El género más complejo del kit. Archivos: `orqkit/kit/empire/empire_map.gd` (tablas y reglas:
edificios, tropas, costes, edades, mercado, analizador y mapa de distancias),
`empire_game.gd` (simulación, interfaz y dibujo) y `qa/empire_bot.gd` (el bot que juega como una
persona que sabe). La fábrica tiene `generar_imperio`, `parametros_imperio` y
`comprobar_imperio` en `niveles/generador.py`.

- **Mapa** (20×28, vista desde arriba): tu centro urbano abajo y el rival arriba; los recursos
  van en espejo (girando 180°) para que sea justo. Tres minas de oro por lado (una cerca, otra
  más lejos para la Edad II y otra en el centro, más expuesta), bosques, bayas y un centro con
  río y vados, rocas o un bosque con huecos.
- **Economía**: aldeanos que recogen y llevan al centro o a un almacén; granjas cuando se acaban
  las bayas; mercado en la Edad II (100 de comida o madera por 40 de oro).
- **Edades**: la II desbloquea arquería, establo y torres; la III el taller de arietes; cada
  edad hace a las tropas un 15 % más fuertes.
- **Combate**: lancero > jinete > arquero > lancero; el ariete solo ataca edificios y apenas
  nota las flechas. Las torres y los centros disparan; cada aldeano escondido dentro (campana)
  añade flechas.
- **Rival**: ingresos propios (`ai.income`), entrena en sus edificios (si los destruyes deja de
  sacar esas tropas), sube de edad a su hora y ataca por oleadas que crecen.
- **Dificultad**: la fábrica sube con el avance los ingresos del rival, adelanta oleadas y le
  pone más edificios, torres y empalizada.
- **Calibración**: con `ORQ_EMPIRE_BATCH=<json> godot ... --solo=empire` el bot juega cada nivel
  del archivo (y `ORQ_EMPIRE_DEBUG=1` saca el estado cada 30 s). Última pasada: 60 niveles
  (fácil, normal y difícil, 10 de cada con 2 semillas); 59 ganados a la primera y el otro
  (difícil, último nivel) a la segunda.


## Minas (idle de excavar)

`orqkit/kit/mine/mine_map.gd` tiene toda la economía como simulación pura (la usan el juego, el bot
y el analizador): pozos con mineros, ascensor que baja cargando pozo a pozo, transportista que
vende en el almacén. Cada pozo más hondo vale 10 veces más. Mejoras con coste que crece más que la
producción, un trabajador más cada 10 niveles, gerentes (la estación trabaja sola) e impulso x2.
El analizador juega la partida entera con el bot (`bot_time`) y devuelve el par; la fábrica pone
una meta de dinero que crece x2,4 por nivel. Si el jugador sale a mitad, la mina se guarda y al
volver cobra lo que han hecho los gerentes (hasta 2 horas, a mitad de ritmo).

## Mazmorras (RPG de acción)

`orqkit/kit/dungeon/dungeon_map.gd` (planta, salas, monstruos, habilidades y equipo),
`dungeon_game.gd` (combate, joystick, cofres, minimapa) y `qa/dungeon_bot.gd`.

- **Planta**: S salida, M monstruos, E élite (golem con escolta), T tesoro, B jefe. Las salas por
  dentro (columnas) y dónde salen los monstruos dependen de la semilla.
- **Combate estilo Archero**: moverse esquiva y pararse dispara solo al más cercano que se vea.
- **Monstruos**: slime (persigue), murciélago (zigzag que se aparta y vuelve, vuela sobre
  columnas), arquero (mantiene distancia y dispara), golem (golpe en área avisado) y jefe con tres
  ataques (anillo de balas, ráfaga y embestida) que llama a dos slimes a mitad de vida.
- **Progreso**: experiencia → elegir 1 de 3 habilidades (flechas extra, diagonales, rebote, daño,
  cadencia, vida, robo de vida, escudo, velocidad). Cofres con arma, armadura o anillo de 4
  rarezas que se guardan entre partidas.
- **Arte**: si el juego tiene sprites de la IA, el héroe y los monstruos los usan (cada tipo con su
  tinte); si no, se dibujan con formas.
- **Calibración**: `ORQ_DUNGEON_BATCH=<json>`; última pasada 60 de 60 niveles ganados sin morir.


## Granja cozy (estilo Hay Day)

`orqkit/kit/farm/farm_map.gd`: parcelas (5 cultivos), corrales (gallinas, vacas, ovejas que
comen pienso), máquinas con cola de 3 encargos (molino de pienso, panadería, quesería,
pastelería, telar) y un tablón con 3 pedidos (se puede cambiar uno cada 20 s). El valor de cada
producto sale de lo que cuesta hacerlo; los pedidos piden solo lo que se puede fabricar en ese
nivel. La fábrica desbloquea edificios y cultivos según avanza el juego. El bot y el analizador
comparten `bot_turn` (recoge, entrega, fabrica, alimenta y siembra lo que más falta).

## Mazo (cartas de estrategia)

`orqkit/kit/deck/deck_map.gd`: 16 cartas (ataques, bloqueos, veneno, debilidad, espinas, fuerza,
armadura, robo de vida, robar cartas, energía), 3 de energía y 5 cartas por turno, enemigos con
intenciones a la vista (atacar, bloquear, fortalecerse, envenenar, debilitar) y un dragón jefe.
Tras cada combate eliges 1 de 3 cartas. Todo el azar sale de la semilla del nivel, así el
analizador juega exactamente la misma partida que el jugador vería y comprueba que se gana.
Calibrado: 20 semillas por combinación; con fuerza 1,0 se ganan 5 combates seguidos el 100 %.

## Aventura (historia con decisiones)

`orqkit/kit/tale/tale_map.gd` + `tale_game.gd`: cada nivel es un capítulo con escenas (quién
habla, texto que sale letra a letra y retrato del personaje), 1 a 3 decisiones que cambian valor,
amistad y oro o dan objetos, decisiones que piden un mínimo o un objeto, y tres finales (bueno 3
estrellas, regular 2, malo 1). Lo ganado pasa al capítulo siguiente. La directora escribe los
capítulos (`aventura` en el diseño); si alguno no cumple las reglas (destinos, callejones, final
bueno alcanzable empezando a cero) entra uno de reserva de `director/banco_aventuras.py`. Las
escenas se traducen a los 6 idiomas junto con el resto del juego.

## Supervivencia (isla, hambre y sed)

`kit/survival`, género «supervivencia» (tipo Don't Starve / Last Day on Earth), vista desde arriba.
Reglas, IA de los lobos, bot y analizador en `survival_map.gd` (simulación pura en casillas).
- **Mapa**: «~» mar, «.» hierba, «,» arena, «T» árbol (4 madera), «R» roca (3 piedra), «G» hierba
  alta (2 fibra), «B» arbusto (3 bayas que vuelven a salir), «W» charca de agua dulce, «D» guarida
  de lobos, «X» restos del naufragio (botín), «P» salida; «#semilla».
- **Necesidades**: vida, hambre y sed. Sin comida o sin agua se pierde vida; con las dos por
  encima de 40 se recupera. Una baya da 22 de comida; beber llena el agua.
- **USAR** hace lo que toca según lo que tienes al lado (golpear al lobo, beber, echar leña,
  recoger). Recoger sigue solo hasta agotar el recurso o hasta que te mueves; con hacha, la
  madera y la piedra salen el doble de rápido. Un árbol o una roca agotados dejan suelo.
- **Fabricar**: hacha y lanza (una vez), hoguera (70 s de fuego, +35 s por leño, hasta 150 s)
  y, si la meta es escapar, la balsa.
- **Noche**: salen lobos de cada guarida; persiguen por un mapa de distancias, muerden (10) y no
  entran en la luz de una hoguera encendida (radio 3,6). Con lanza caen en dos golpes; a puñetazos,
  en cinco. Al amanecer vuelven a su guarida.
- **Metas** (parámetros por nivel): aguantar 1-4 noches o, cada tercer nivel, construir la balsa.
  Más guaridas, más lobos, noches más largas y más hambre y sed según avanza.
- **Bot** (el mismo para el analizador y QA): bebe y come antes de ir mal y antes de la noche,
  monta el campamento junto a la charca, pasa la noche a la luz y recoge lo que falta para la meta.
- **Analizador**: agua y 2 arbustos al alcance, recursos de sobra, ninguna guarida a menos de 7
  casillas de la salida y el bot gana 2 de 3 partidas.
- **Calibrado**: 48 de 48 islas generadas aceptadas (antes de arreglar beber junto a la hoguera, 42).
- **Lecciones**: el bot se quedaba clavado junto a un recurso cuando el empujón para centrarse era
  menor que la zona muerta del mando (la simulación ignora movimientos por debajo de 0,15): nunca
  mandar movimientos que no mueven. Y USAR debe poder recibir lo que se quiere hacer: el bot llegaba
  a la charca muerto de sed y se ponía a picar la roca de al lado.
- Se pide con «supervivencia», «sobrevivir», «survival», «náufrago», «isla desierta», «hambre y
  sed»… Va justo después de «mundo» en el orden: «supervivencia de bloques» y «minecraft» siguen
  en «mundo» y «cubos». Prueba: `--solo=survival`.
- **Nace en 3D** (`generos.VISTA_3D`; «ponlo en 2D» en el taller): `survival_view3d.gd` dibuja la
  misma partida con la isla en bloques bajos, árboles, rocas, arbustos y guaridas en low-poly
  (MultiMesh), el jugador y los lobos con el arte del juego como figuras que miran a la cámara,
  el sol que baja al anochecer y una luz de verdad en la hoguera; cámara alta en diagonal. Los
  textos que flotan van a la interfaz, encima del jugador. Al rehacer los objetos, los viejos se
  sacan del árbol antes de borrarlos (si no, los nuevos no pueden llevar el mismo nombre).
- **Plantilla por datos** (`survival` en `game.json` o en cada nivel): objetos, casillas, recetas,
  criaturas, frío, mochila y herramientas que se gastan se describen como datos, y el juego, el bot
  y el analizador los leen. Tres estilos hechos (`preset`): `zombis` (tipo Last Day on Earth),
  `invierno` y `caza`; en la fábrica son los giros `apocalipsis`, `invierno` y `caza`. La partida se
  guarda al amanecer. Calibrado: 48 de 48 niveles por estilo. Todo en
  `PLANTILLA-SUPERVIVENCIA-LEEME.md`. Prueba: `--solo=survival_template`.
- **Lección**: junto a la hoguera, USAR echaba leña en vez de beber y el bot moría de sed al lado
  de la charca; ahora, si se va a beber, beber manda (la isla pasó de 42 a 48 de 48 niveles).

## Triple de fichas (tipo Tile Master / Triple Tile)

`kit/triple`, género «triple». Reglas, reparto, bot y analizador en `triple_map.gd` (lógica pura).
- **Mapa**: capas separadas por «=»; en cada capa «X» es una ficha. Las capas impares van media
  ficha desplazadas, así que una ficha de arriba tapa hasta cuatro de la de abajo. «#semilla».
- **Jugar**: una ficha está libre si ninguna de una capa más alta la pisa. Al tocarla va a la
  bandeja (7 huecos), al lado de las de su dibujo; tres iguales desaparecen. Bandeja llena sin
  trío = se pierde; montón vacío = se gana.
- **Reparto con solución**: desde el montón lleno se busca un orden de jugadas cogiendo fichas
  libres de tres en tres, y cada tres reciben el mismo dibujo. **Barajar** sigue otro orden así y
  da los dibujos que quedan completando primero lo que hay en la bandeja: siempre queda ganable.
- **Deshacer**: la última ficha vuelve a su sitio (las que ya hicieron trío, no).
- **Dibujos**: 12 tipos con forma y color distintos (manzana, estrella, corazón, diamante,
  hoja, luna, gota, flor, rayo, seta, pez y corona); se juega aunque no distingas colores.
- **Bot**: cierra tríos, junta parejas si hay sitio, valora lo que destapa, nunca llena la
  bandeja con sueltas y tira de las ayudas en un apuro. El analizador exige que gane 2 de 3
  repartos. Calibrado: 54 de 60 montones a la primera (los rechazados son de más de 120 fichas).
- **Generador**: capas simétricas que se estrechan hacia arriba, más capas y más dibujos según
  avanza; siempre un número de fichas múltiplo de 3.
- «tile match» es de este género (en la Play Store es el triple de bandeja); el mahjong se pide
  con «mahjong» o «parejas de fichas». Prueba: `--solo=triple`.

## Puzle de tornillos (tipo Screw Jam / Wood Nuts)

`kit/screw`, género «tornillos». Reglas, reparto, bot y analizador en `screw_map.gd` (lógica pura).
- **Mapa**: una línea por placa, de abajo arriba: «x,y,w,h:sx,sy;sx,sy» (placa de w×h casillas
  en un tablero de 7×9 y las casillas de sus tornillos, dentro de la placa). «#semilla» al final.
- **Jugar**: un tornillo está libre si ninguna placa más alta pisa su casilla. Al tocarlo va a la
  caja abierta de su color o, si no hay, a los huecos de espera. Una placa sin tornillos cae;
  una caja con 3 se va y llega la siguiente, que se lleva los de su color que esperaban.
  Se gana al quitar todos; huecos llenos sin jugada = se pierde.
- **Ayuda**: HUECO EXTRA (un hueco de espera más). Si te atascas y te queda, el botón parpadea en
  vez de perder.
- **Reparto con solución**: se quitan tornillos libres al azar hasta vaciar (las placas caen igual
  que al jugar); cada tres seguidos reciben un color y las cajas llegan en ese orden.
- **Se ve**: placas de colores translúcidas (se intuye lo que tapan), tornillos con marca distinta
  por color (cruz o punto), cajas arriba con la cola de las siguientes y la espera abajo, que se
  pone roja con un hueco libre. Las placas caen girando.
- **Bot**: llena primero la caja casi llena, suelta placas, mira una jugada por delante y solo usa
  la espera para el color que llega antes. El analizador exige que gane 2 de 3 repartos.
  Calibrado: 960 de 960 niveles generados aceptados.
- **Generador**: placas por parejas simétricas sobre una base ancha, alguna barra central encima;
  más placas, colores y menos espera según avanza. Prueba: `--solo=screw`.

## Hexa sort (pilas de hexágonos)

`kit/hexa`, género «hexas». Reglas, reparto, bot y analizador en `hexa_map.gd` (lógica pura).
- **Mapa**: filas de casillas hexagonales (las impares, media casilla a la derecha): «.» libre,
  «#» piedra, « » fuera del tablero y «a»..«h» una pila ya puesta con ese color arriba. «#semilla».
- **Jugar**: hay 3 pilas para elegir (de 2 a 6 fichas, de 1 a 3 colores); se arrastran (o se toca
  la pila y luego la casilla). Las vecinas con el mismo color arriba le pasan esas fichas y la
  cadena sigue con lo que queda destapado; 10 o más iguales arriba se limpian. Al gastar las 3
  llegan otras 3. Meta: limpiar «goal» fichas; tablero lleno = se pierde.
- **Ayuda**: MARTILLO (rompe una pila entera). Con el tablero lleno y martillo, el botón parpadea
  en vez de perder.
- **La cadena siempre acaba**: cada movimiento junta dos tramos del mismo color en uno.
- **Se ve paso a paso**: la vista va un poco por detrás del estado; cada movimiento de fichas
  salta en arco de una pila a otra y cada torre limpiada estalla. El número de cada pila es lo
  que tiene seguido del color de arriba. Tablero en diagonal (hexágonos aplastados en vertical).
- **Bot**: prueba cada pila en los huecos que juntan su color y en los 5 más apartados, y se queda
  con la que más limpia y menos revuelve el tablero (pocos tramos, huecos libres, pocos colores
  distintos alrededor de cada hueco). El analizador exige que gane 2 de 3 repartos.
- **Calibrado**: el bot aguanta 400 jugadas con 3-6 colores en tableros normales; con 7-8 colores
  en el tablero pequeño se atasca, así que los colores van de 3 a 6. Meta de 90 a 280 fichas;
  240 de 240 niveles generados aceptados (0,6 s por nivel en el analizador).
- **Generador**: rectángulo de 5-7 × 6-8 con esquinas recortadas, piedras y pilas puestas en
  espejo. Prueba: `--solo=hexa`.

## Bus jam (pasajeros al autobús de su color)

`kit/bus`, género «autobus». Reglas, reparto, bot y analizador en `bus_map.gd` (lógica pura).
- **Mapa**: «P» pasajero, «.» hueco, «#» pared; la salida es el borde de arriba. «#semilla».
- **Jugar**: tocas a un pasajero con camino libre hasta arriba (por huecos, sin diagonales) y sale
  andando por ese camino: sube al autobús si es de su color y queda sitio, o espera en la parada.
  Autobús con 3 se va y llega el siguiente (los de su color que esperaban suben solos). Cada
  pasajero que sale deja hueco y abre camino a otros. Parada llena sin jugada = se pierde.
- **Ayuda**: VIP (saca a cualquiera aunque esté encerrado). Atascado con VIP: el botón parpadea.
- **Reparto con solución**: se sacan pasajeros con camino al azar hasta vaciar; cada tres seguidos
  reciben un color y los autobuses llegan en ese orden.
- **Se ve**: estación a cuadros con paredes, flechas de salida arriba, pasajeros con marca por color
  (que dan saltitos si pueden salir y se ven apagados si no), carretera con el autobús (llega por la
  derecha y se va por la izquierda) y la cola de los siguientes; la parada se pone roja al llenarse.
- **Bot**: nota rápida a cada pasajero libre (llena antes el autobús, guarda la parada para el color
  que llega antes) y mira una jugada por delante solo a los 6 mejores.
- **Calibrado**: 288 de 288 niveles generados aceptados (0,9 s por nivel en el analizador).
- **Generador**: estación de 6-8 × 7-10 casi llena, paredes en espejo y nunca nadie encerrado para
  siempre (`_bus_sale_todo`). Prueba: `--solo=bus`.

## Duelo de cartas en 3D (tipo Clash Royale)

`kit/clash`, género «duelo». Nace en 3D (`generos.VISTA_3D`); en 2D se ve desde arriba con las
mismas reglas. Simulación pura, IA rival, bot y analizador en `clash_map.gd`; la vista 3D en
`clash_view3d.gd` (sin `class_name`, se carga con `preload`).
- **Arena**: 18 × 32 casillas; tu lado abajo, el rival arriba; río con dos puentes (lo de tierra
  solo cruza por ellos; el montapuercos salta el río y lo que vuela, también).
- **Torres**: dos de princesa (1400) y la del rey (2400) por lado; el rey despierta cuando le dan o
  cae una de las suyas. Cada torre caída es una corona; la del rey, las tres.
- **Elixir**: empieza en 5, +1 cada 2,8 s (el doble el último minuto), hasta 10. Mazo de 8 y mano
  de 4; la carta jugada vuelve al final.
- **12 cartas**: caballero, arqueras, gigante, esbirros, mosquetera, esqueletos, montapuercos,
  valquiria, dragón bebé, cañón (edificio de 30 s), bola de fuego y flechas (a las torres les hacen
  el 35 %). Cada una con vida, daño, ritmo, alcance, velocidad, a qué ataca (tierra, todo o solo
  edificios), si vuela y daño en área.
- **Tropas**: van a por el enemigo más cercano que ven (5,5 casillas); si no hay, por su carril a la
  torre de ese lado. No se pisan entre ellas.
- **Tiempo**: 3 minutos (el primer nivel, 2); con empate, 1 minuto de muerte súbita; si sigue,
  gana quien tenga su torre más tocada con más vida.
- **IA rival y bot** (la misma cabeza, `think`): con amenazas en su mitad, hechizo si hay 3 o más
  juntas o la mejor respuesta que pueda pagar (contra aire, algo que dispare al aire; contra
  enjambres, daño en área; contra lo que va a por torres, distracciones); remata torres con
  hechizos; con 8,5 de elixir ataca con un tanque por el carril más flojo y apoyo detrás.
- **Dificultad**: el rival lleva menos elixir, tropas algo más flojas y piensa más despacio al
  principio (`ai_elixir` 0,72→0,86, `ai_level` 0,84→0,92, `ai_react` 1,6→1,2 s). Calibrado: con el
  rival más duro el bot gana 4 de cada 5; 192 de 192 niveles generados aceptados (0,5 s por nivel).
- **Tu mazo crece**: cada dos niveles entra una carta nueva (montapuercos, valquiria, dragón bebé y
  cañón) en lugar de una de las de inicio.
- **Se juega**: arrastras una carta de la mano a la arena (o tocas carta y luego arena); al
  arrastrar se ve en rojo la mitad donde no se puede soltar y, en los hechizos, su círculo. En 3D
  el punto de la arena sale del rayo de la cámara contra el suelo.
- Se pide con «clash royale», «duelo de cartas», «elixir»… («clash of clans» sigue siendo la
  aldea). Prueba: `--solo=clash`.

## Escalada (tipo Hill Climb Racing)

`kit/climb`, género «escalada». Física propia del coche (no la de Godot), bot y analizador en
`climb_map.gd`: el juego, el bot y el analizador hacen exactamente lo mismo con los mismos mandos.
- **Mapa**: «T:» alturas del suelo cada 4 m (varias filas se encadenan), «F:» bidones, «C:»
  monedas y «#semilla». El suelo es una curva de Catmull-Rom por esos puntos.
- **Coche**: chasis rígido con dos ruedas de suspensión (muelle y amortiguador por rayo), tracción a
  las dos ruedas limitada por el agarre, y la carrocería tampoco atraviesa el suelo. El gas empuja
  menos cuanto más rápido va y el freno da marcha atrás parado. Con ruedas en el suelo el motor tira
  del chasis hacia atrás; en el aire el gas levanta el morro y el freno lo baja. Paso fijo de 1/120 s.
- **Se pierde** si la cabeza del conductor toca el suelo (vuelco) o si se acaba la gasolina y el
  coche se para. Se gana al llegar a la meta. Vueltas en el aire (+5 monedas) y tiempo en el aire
  (+2). Estrellas por tiempo (`par`, sale del bot).
- **Taller** (tienda, solo en este género): motor, suspensión, ruedas y depósito, 4 niveles cada
  uno (`Save.UPGRADES`). El analizador juega sin mejoras: todo se pasa sin comprar nada.
- **Bot**: gas casi siempre; suelta en los caballitos (sin frenar salvo que vaya a volcar); en
  bajadas rápidas frena solo con las dos ruedas en el suelo; en el aire iguala el ángulo con la
  pendiente donde va a caer. El analizador prueba tres conductores (más o menos atrevidos) y exige
  que lleguen dos.
- **Lección**: con interpolación por coseno el suelo hacía escalones (pendiente cero en cada punto)
  y el coche se quedaba clavado o volcaba; con Catmull-Rom pasaron de 31 a 48 de 48 niveles.
- **Generador**: arranque llano, colinas que crecen en los primeros 100 m, pendiente y cambio de
  pendiente limitados (sin muros ni esquinas que lancen el coche), bidones cada 260-380 m y monedas
  en grupos de 5. Calibrado: 144 de 144 niveles aceptados. Prueba: `--solo=climb`.

## Tirachinas (tipo Angry Birds)

`kit/sling`, género «tirachinas». Aquí los derrumbes son física de verdad (cuerpos rígidos de
Godot) en `sling_game.gd`; `sling_map.gd` lee el nivel, calcula la balística y analiza.
- **Mapa** (de arriba abajo, apoyado en el suelo, casillas de 64 px): «W» madera, «S» piedra,
  «I» hielo, «=» tablón (los seguidos en una fila son una pieza, ocupa lo de abajo de su casilla y
  lo que va encima se apoya más abajo), «|» poste (los seguidos en una columna, una pieza), «P»
  cerdo, «K» cerdo rey, «T» TNT, «#» roca fija. «#semilla».
- **Pájaros** («birds»): rojo; amarillo (toca en el aire: acelera); azul (se parte en tres); negro
  (explota al tocar o al chocar). Salen del centro del tirachinas sin rozamiento del aire, así que
  vuelan justo por los puntos que se ven al apuntar.
- **Daño**: por cambio brusco de velocidad (lo nota igual quien recibe y quien choca, aunque
  estuviera dormido) o por empujón fuerte de un contacto, descontando lo que aguanta quieto. Lo
  apilado empieza dormido y los primeros 1,5 s no hay daño: las torres no se caen solas.
- **Lecciones**: el impulso de contacto no llega cuando el cuerpo golpeado estaba dormido (el
  cerdo recibía el pájaro y no se enteraba); el frenado por aire del proyecto (0,1) hacía que todos
  los tiros se quedaran cortos frente a la parábola calculada.
- **Bot**: apunta al cerdo más cercano buscando un tiro (tenso o en parábola, con distinta fuerza)
  cuyo camino no toque ninguna pieza; si no hay, parábola alta. Usa el poder antes de llegar. Juega
  en la escena real (género estricto). Calibrado: 94 de 96 niveles ganados (92 a la primera).
- **Analizador**: cerdos al alcance, todo apoyado y suficientes pájaros.
- **Generador**: de 1 a 3 construcciones (casita con tablón sobre postes, torre, búnker, pirámide
  con TNT, pedestal del rey) separadas y como mucho 9 casillas de ancho; pájaros según el material
  (negro si hay piedra, azul si hay hielo). Prueba: `--solo=sling`.

## Plantas contra zombis (defensa por carriles, en vertical)

`kit/lawn`, género «plantas». Simulación pura, bot y analizador en `lawn_map.gd`. Para el móvil en
vertical: 5 carriles hacia abajo, los zombis bajan hacia la casa y las cartas quedan al pulgar.
- **Soles**: caen del cielo cada 9 s y los dan los girasoles (cada 12 s); se tocan para cogerlos
  (duran 10 s). Cada planta cuesta soles y se recarga.
- **Plantas**: girasol, lanzaguisantes, guisante de hielo (frena a la mitad), nuez (4000 de vida),
  patatamina (se arma en 12 s), cereza bomba (3×3) y repetidor. Una nueva por nivel.
- **Zombis**: normal, con cono, con cubo y corredor; se comen lo que tienen delante.
- **Cortacésped** por carril: salva una vez; la segunda vez que llega uno, se pierde. Estrellas
  por cortacéspedes que quedan.
- **Bot** (el del analizador): coge todos los soles, cereza donde se juntan 3, tirador en cada
  carril con zombis (más si llegan fuertes), nuez delante de conos y cubos, patatamina delante del
  primero y girasoles abajo hasta 8.
- **Generador**: oleadas que crecen con la última más gorda y tipos según el nivel. Calibrado:
  141 de 144 niveles aceptados (0,25 s por nivel). Prueba: `--solo=lawn`.
