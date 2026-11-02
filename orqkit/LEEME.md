# OrqKit 1.0: kit base de Orquestador (Godot 4.6.3)

Fase 1 de la fábrica: el núcleo que comparten todos los juegos, el primer género
(plataformas) con feeling comercial y las primeras herramientas de QA automático.

## Abrirlo

1. Descomprime `orqkit` donde quieras.
2. En Godot 4.6.3: **Importar** → elige `orqkit/project.godot`.
3. Pulsa **F5**. Se juega con flechas/A-D/W/espacio o con los botones táctiles
   (con el ratón también, porque *Emulate Touch From Mouse* está activado).

## Exportar a Android

El proyecto ya trae el preset "Android" (arm64, vertical, inmersivo, icono propio).
En Godot: **Proyecto → Exportar → Android**. Necesitas las plantillas de exportación de 4.6.3
y el SDK de Android configurado en Ajustes del Editor (como para Ashen).
Requisito de Godot para Android: compresión de texturas ETC2/ASTC (ya activada).

## Pasar el QA (desde PowerShell, dentro de `orqkit`)

```powershell
& "RUTA\Godot_v4.6.3-stable_win64_console.exe" --headless --path . res://qa/test_runner.tscn --fixed-fps 60 -- --qa
```

Termina con `== Resultado: 205 correctas, 0 fallidas ==` y código de salida 0.
La fábrica usará ese mismo código para decidir si un juego pasa o vuelve al agente.

## Qué hay dentro

```
orqkit/
├─ project.godot          Vertical 720x1280, GL Compatibility, táctil (ver nota sobre emulación)
├─ game.json              TODO lo del juego: paleta, física, textos y niveles (lo que genera la IA)
├─ scenes/               title.tscn (arranque), levels.tscn, main.tscn (juego)
├─ kit/                   Autoloads (sin class_name)
│  ├─ qa.gd               Registro de eventos, fallos y rendimiento para los bots
│  ├─ kit.gd              Carga game.json, acciones de entrada, cambio de escena con fundido
│  ├─ save.gd             Guardado a prueba de cortes y de archivos corruptos
│  ├─ skins.gd            Aspectos del héroe (shader de tono) para la tienda
│  ├─ genres.gd           Registro de géneros: escena, analizador y reglas del validador
│  ├─ telemetry.gd        Autoload: datos anónimos de partida para aprender de los jugadores
│  ├─ juice.gd            Sacudida por trauma, hitstop, destello, estirar/aplastar, vibración
│  ├─ audio.gd            Efectos con variación de tono, música en bucle por pista (menu, nivel, victoria)
│  ├─ ads.gd              Anuncios con reglas que protegen la cuenta (simulador por ahora)
│  ├─ ui/                 Interfaz que se adapta al estilo de cada juego
│  │  ├─ ui.gd            Autoload "UI": tema, botones con feeling, zona segura, navegación, auditoría
│  │  ├─ ui_theme.gd      4 perfiles (pixel, cartoon, low_poly, realista) + contraste garantizado
│  │  ├─ ui_icon.gd       Iconos vectoriales nítidos a cualquier tamaño
│  │  ├─ ui_modal.gd      Base de ventanas (oscurece, centra, funciona en pausa)
│  │  ├─ star_row.gd      Estrellas que se encienden una a una
│  │  ├─ fonts/           PixelifySans, Fredoka, Chakra Petch, Exo 2 (licencia OFL)
│  │  └─ screens/         Título, niveles, pausa, ajustes, resultado
│  └─ platformer/
│     ├─ player_platformer.gd   Controlador con coyote, buffer, salto variable, apex, corazones
│     ├─ enemy.gd               Enemigos: patrulla (E), pinchos (K), volador (F) y jefe final (B)
│     ├─ moving_platform.gd     Plataformas que van y vienen (=) y te llevan encima
│     ├─ level_builder.gd       Nivel desde texto (une bloques en colisiones grandes)
│     ├─ level_analyzer.gd      Detecta niveles imposibles, monedas inalcanzables y enemigos injustos
│     ├─ touch_controls.gd      Botones táctiles multitáctiles (+ botón de fuego si hay disparo)
│     └─ platformer_game.gd     Reglas, cámara con anticipación, HUD, pisotones, golpes, meta
└─ qa/
   ├─ test_runner.gd/.tscn      110 pruebas automáticas (juego, combate, poderes, jefe, música e interfaz)
   ├─ bot.gd                    Bot que juega de verdad: salta, dispara, usa plataformas y pelea con el jefe
   ├─ capturas.gd/.tscn         Galería de la app: título, niveles, juego, resultado y combate con el jefe
   ├─ impossible.txt            Nivel imposible a propósito (el analizador debe pillarlo)
   ├─ shot.gd/.tscn             Capturas automáticas (para la revisión visual por IA)
   ├─ ui_shots.gd/.tscn         Capturas de las 5 pantallas en un perfil (-- --profile=cartoon)
   └─ combat_shots.gd/.tscn     Capturas del combate (pisotón y golpe)
```

## Ajustar el feeling sin tocar código (game.json → "player")

| Parámetro | Qué hace | Valor |
|---|---|---|
| `run_speed` | Velocidad máxima | 430 |
| `jump_height` | Altura del salto en píxeles (1 bloque = 64) | 230 |
| `time_to_apex` | Segundos hasta lo más alto (menos = más ágil) | 0.36 |
| `coyote_time` | Margen para saltar tras dejar el borde | 0.1 |
| `jump_buffer` | Margen para pulsar antes de tocar suelo | 0.12 |
| `fall_gravity_mult` | Caída más rápida que la subida | 1.7 |
| `jump_cut_mult` | Cuánto se corta el salto al soltar | 2.6 |
| `apex_gravity_mult` | Flotar un poco en lo más alto | 0.55 |

## Niveles (game.json → "levels" → "map")

`#` bloque · `P` salida · `G` meta · `C` moneda · `^` pinchos · `E` `K` `F` enemigos · `.` vacío

Nuevo en 0.5:

| Letra | Qué es |
|---|---|
| `B` | Jefe final: te persigue, se agacha (aviso) y salta para aplastarte. Hay que pisarlo varias veces; aturdido no hace daño. La meta queda cerrada con barrotes hasta vencerlo. Barra de vida con su nombre arriba |
| `R` | Punto de control: bandera que sube al pasar; si mueres, reapareces ahí |
| `=` | Plataforma móvil: va y viene por el hueco libre (varios `=` seguidos = una más ancha) |
| `H` | Corazón extra · `J` doble salto · `M` imán de monedas · `V` velocidad · `I` estrella (invencible y mata al tocar) |

Los poderes duran `power_seconds` (7 s) y se muestran en el HUD. Disparo: `"player"` → `"shoot": 1.0`
(tecla X/J/K o botón de fuego), las balas se paran en paredes y matan enemigos (al jefe le quitan vida).
El analizador trata `=` como suelo y avisa si el jefe no tiene arena (`boss_arena_small`).

## Enemigos y combate

| Letra | Enemigo | Cómo se vence |
|---|---|---|
| `E` | Patrulla: anda y se gira en paredes, bordes y pinchos | Pisándolo |
| `K` | Con pinchos: igual, pero pisarlo hace daño | Saltándolo |
| `F` | Volador: va y viene con vaivén, sin gravedad | Pisándolo |
| `B` | Jefe: persigue, se agacha y salta; se enfada a media vida | Pisándolo varias veces (o a balazos) |

- **Pisotón**: rebote (más alto si mantienes el salto), parada de impacto, partículas y "+100".
  Encadenar pisotones sin tocar el suelo dobla los puntos (x2, x4, x8).
- **Golpe**: pierdes un corazón, sales despedido, parpadeas y eres invulnerable un momento.
  Sin corazones mueres y reapareces con todos. Los pinchos y las caídas siguen matando de golpe.
- Ajustes en `game.json`: `"player"` → `hp`, `invuln_time`, `knockback_x/y`, `stomp_bounce`;
  `"enemies"` → `walker` / `spiky` / `flyer` → `speed`, `width`, `height`, `points`, `range`, `bob`.
  Arte: el sprite con rol `enemigo` del manifest, o uno por tipo en `"art"` → `"enemies"`.
- El analizador avisa si un enemigo que anda no tiene suelo (`enemy_floating`), si está
  encima de la salida (`enemy_near_spawn`) o si en su patrulla no hay hueco para saltarlo
  (`enemy_unavoidable`). Los bots saltan a los enemigos que tienen delante.

## Géneros: plataformas, runner, volador, hordas, puzle, torres y carreras

El mismo kit hace siete géneros, todos dados de alta en `kit/genres.gd` (escena, analizador y si
el bot debe ganar a la primera). Para añadir otro: `python -m nuevo_genero` en la fábrica (ver
`GENEROS-LEEME.md`); la escena nueva solo tiene que devolver su bot en `bot_script()`. Con `"player": {"auto_run": 1}` el juego es un **runner**:
- El héroe corre solo hacia la derecha; tú solo saltas (o disparas).
- Cada vez más rápido: la velocidad sube con el recorrido (`"runner_ramp"`, 0.22 = +22 % al final).
- Sin flechas: se salta tocando cualquier parte de la pantalla (menos la columna de botones).
- Barra de recorrido en el HUD, cámara que deja mucho sitio delante y aviso "¡Toca para saltar!".
- El analizador vigila lo que en un runner es injusto: muros de 3 bloques (`runner_wall`),
  plataformas móviles (`runner_moving_platform`) y jefe (`runner_boss`). El bot mira más lejos
  cuanto más rápido va.

Con `"player": {"flap": 1}` es un **volador** (arcade de un toque):
- Flota quieto hasta el primer toque; luego avanza solo, cae y cada toque le da un impulso
  (`flap_impulse`, `flap_gravity`, `flap_max_fall`). Se inclina al subir y bajar.
- Tocar un bloque es chocar (se reaparece en el último punto de control). Techo invisible arriba.
- Toda la pantalla es el botón; la cámara deja ver el hueco entero; la meta es una línea de llegada.
- Mapas: columnas de `#` (tuberías) con un hueco. El analizador (`flap_analyze`) exige huecos de
  4 o más (`flap_gap_small`) y que el hueco no cambie de altura más de lo que se puede volar
  (`flap_gap_jump`). El bot planifica toques 0,8 s por delante con la física real.

Con `"genre": "horde"` es un juego de **hordas** visto desde arriba (escena `scenes/horde.tscn`,
código en `kit/horde/`):
- Te mueves con un joystick que aparece donde pones el dedo (o flechas/WASD). Las armas disparan
  solas: Chispazo (al más cercano y siempre uno al jefe), Orbes, Aura y Abanico.
- Oleadas cada vez más densas y duras, y un cerco cada 30 s. Los enemigos sueltan gemas (el
  coleccionable del juego); al llenar la barra subes de nivel y eliges 1 de 3 mejoras (armas
  nuevas o más fuertes, Botas, Corazón, Imán, Fuerza, Prisa). Varias subidas a la vez se eligen
  una detrás de otra.
- Cada nivel trae `seconds`, `density`, `enemies` y `boss`. Al acabarse el tiempo la horda se
  deshace en gemas; si hay jefe (embiste tras avisar), el reloj espera a que lo derrotes.
- Analizador de arenas (`HordeArena`): claro de 5x5 en la salida, rocas ≤ 18 %, borde cerrado y
  todo el suelo conectado. Bot propio (`HordeBot`): rodea las amenazas, recoge gemas, se aleja de
  los bordes y elige mejoras por prioridad.

Con `"genre": "match3"` es un **puzle de combinar 3** (escena `scenes/match3.tscn`, código en
`kit/match3/`):
- Arrastras una pieza hacia su vecina (o tocas una y luego otra). Cada color tiene su forma
  (círculo, rombo, cuadrado, triángulo, estrella, hexágono): se juega aunque no distingas colores.
- Línea de 4: rayo que limpia su fila o columna. Línea de 5: bomba de color. Forma de L o T:
  onda que explota en 3x3. Cascadas con multiplicador, hielo que se rompe al combinar encima,
  y si no quedan jugadas el tablero se baraja.
- Cada nivel: `map` (`.` casilla, `#` hueco solo en los bordes de columna, `I` hielo), `moves`,
  `colors` (5 o 6) y `goal_factor`. El objetivo de puntos lo calcula el kit con lo que saca el
  bot en el peor 10 % de partidas. Los movimientos sobrantes suman extra; sin movimientos sale
  la ventana de reintentar.
- Lógica pura en `Match3Logic` (la usan juego, bot y pruebas). El bot prueba cada jugada en una
  copia del tablero; el validador exige que pase el nivel a la primera o a la segunda.

Con `"genre": "tower"` es un **tower defense** (escena `scenes/tower.tscn`, código en `kit/tower/`):
- Mapa de casillas: `.` construible, `=` camino, `S` entrada, `B` base (aparece el héroe), `#` roca.
- Toca una casilla libre y elige torre: **Rayo** (rápida, un objetivo), **Cañón** (lenta, daño en
  área) o **Hielo** (frena). Toca una torre para mejorarla (hasta nivel 3) o venderla (60 %).
- Oleadas con los enemigos del juego (walker normal, flyer rápido, spiky acorazado) cada vez más
  grandes y duras; el jefe en la última oleada del último nivel. Las bajas dan oro; lanzar la
  oleada antes de tiempo, también. Cada enemigo que llega quita vidas; sin vidas, reintentar.
- Estrellas por vidas que te quedan. Cada nivel trae `waves`, `density`, `enemies`, `boss`,
  `gold` y `lives`. Analizador `TowerMap` (camino único de S a B, largo, sin atajos, sitio para
  torres) y bot `TowerBot` (construye donde más camino cubre, mejora y lanza oleadas).

Con `"genre": "race"` son **carreras** (escena `scenes/race.tscn`, código en `kit/race/`):
- Carretera vista desde arriba con curvas, 4 carriles y 3 rivales (con los nombres de los enemigos
  del juego). El coche acelera solo; arrastras el dedo (o flechas) para cambiar de carril.
- Conos y coches lentos frenan mucho; salirse del asfalto frena; las curvas empujan hacia fuera.
  Las monedas cargan el turbo y las placas de turbo lo dan al momento. Cuenta atrás de salida.
- Puesto al cruzar la meta: 1.º tres estrellas, 2.º dos, 3.º una; cuarto, reintentar.
- Cada fila del mapa es un tramo: curva (`<` `>` `|`) y 4 carriles (`.` `C` moneda, `N` turbo,
  `O` cono, `T` coche lento). Analizador `RaceTrack` (nunca un muro, siempre paso cambiando un
  carril por tramo) y bot `RaceBot` (elige carril mirando 9 tramos por delante, usa el turbo).

Puzle, torres y carreras se validan exigiendo que el bot gane a la primera o a la segunda.

Con `"genre": "village"` es la **aldea** (escena `scenes/village.tscn`, código en `kit/village/`):
- Asalto a una base en vista isométrica. Eliges tropa abajo (guerrero, arquera, gigante) y tocas
  fuera de la base para soltarla (mantener suelta varias; arrastrar mueve la cámara).
- Las tropas van solas al edificio más cercano (el gigante solo a las defensas); si un muro les
  corta el paso y no hay hueco cerca, lo rompen. Arqueras disparan por encima de los muros.
- Defensas: cañón (`C`), torre arquera con un guardián del juego (`A`) y mortero de área (`O`).
  Estrellas: 50 %, ayuntamiento (`H`) y 100 %; con una se gana. El botín de oro (`G`), elixir
  (`E`) y minas (`M`) va al monedero; `K` son casas y `#` muros. Cada edificio se marca con su
  letra arriba a la izquierda y su huella (2x2, 3x3) va en `.`.
- Nivel: `army`, `seconds`, `base_hp`, `def_dmg`. Analizador `village_map.gd`, bot `qa/village_bot.gd`.
- **Mi aldea** (`scenes/village_home.tscn`, botón en el título): tu aldea entre asaltos, guardada en
  `Save.meta()["aldea"]` (`village_save.gd`). Huecos fijos que se construyen y mejoran con monedas
  del botín; nada sube por encima del ayuntamiento (nivel 3 como mucho). Cuarteles: +1 guerrero y +1
  arquera por nivel en cada asalto; elixir: +4 % de fuerza por nivel; oro: +10 % de botín por nivel.
- **Liga** (botón en Mi aldea, `liga_panel.gd`): sube tu aldea (`Online.liga_publish`), pide rival al
  servidor (`liga_rival`) y empieza un asalto con `Online.liga_match` relleno: la escena de la aldea
  usa el mapa del rival y el ejército de tu ayuntamiento, y al acabar manda `liga_resultado` y abre
  la ventana de trofeos. Tablas y reglas en `supabase/migrations/20261010000013_liga_aldeas.sql`.
- **Clanes y guerra de clanes** (mismo panel): crear/unirse con código (`Online.clan_*`). Cada semana
  las estrellas de los asaltos suman para el clan del atacante (`Online.clan_war`, top de clanes y tus
  estrellas); quien aportó estrellas a uno de los 3 primeros de la semana pasada cobra 250/150/80
  monedas una vez (`Online.clan_war_claim`). Servidor: `…16_clanes.sql` y `…20_guerra_clanes.sql`.

Con `"genre": "brawl"` es la **arena** (escena `scenes/brawl.tscn`, código en `kit/brawl/`):
- Todos contra todos vista desde arriba: el último en pie gana. Joystick para moverte; el botón
  **¡Fuego!** apunta solo al rival visible más cercano (rafaga de 3 balas, 3 cargas que se
  recargan) y **Súper** lanza una onda de balas cuando se llena con tus impactos.
- Arbustos (`*`): no te ven de lejos (ni tú a ellos); disparar te descubre un momento. Cajas
  (`B`): se rompen y sueltan un cubo de poder (+10 % de vida y daño). Tres segundos sin golpes y
  te curas. Desde `gas_start` el gas cierra la arena y quita vida fuera del círculo.
- Rivales (`R`) con el arte de los enemigos: al principio abren cajas, pelean también entre ellos,
  nunca van más de dos a por el mismo y huyen con poca vida. Nivel: `rival_hp`, `rival_dmg`,
  `aim` (error de puntería), `reaction`, `gas_start`, `gas_time` y `par` (segundos para la
  tercera estrella). Analizador `brawl_map.gd` y bot `qa/brawl_bot.gd`.

### Laberinto, minigolf, pesca y fusión

Cuatro géneros más, cada uno en su carpeta con `*_game.gd` (la escena), `*_map.gd` (las reglas y el
analizador) y su bot en `qa/`. El juego, el bot y el analizador llaman a **las mismas funciones**
de reglas, así que lo que el bot prueba es exactamente lo que pasa al jugar:

- `"genre": "maze"` (`kit/maze/`): cuadrícula vista desde arriba; deslizas una casilla. Monedas,
  pinchos, una llave (`L`) y puertas (`D`) que solo abre esa llave.
- `"genre": "golf"` (`kit/golf/`): tirachinas (arrastras hacia atrás). Muros que rebotan, agua
  (`W`, golpe de castigo) y arena (`S`, frena). `"par"` del nivel = golpes para 3 estrellas.
  `golf_map.gd` tiene la física (`step`) y el plan del bot (`plan_shot`).
- `"genre": "fishing"` (`kit/fishing/`): franjas de agua que se mueven a su velocidad
  (`"speeds"`); tocas para soltar el anzuelo. Peces (`F`) y medusas (`X`). `"goal"` y `"time"`.
  Todo va con el reloj del nivel, así que el bot sabe qué pescará antes de tocar.
- `"genre": "merge"` (`kit/merge/`): sueltas piezas en columnas y las iguales se juntan (2+2=4...)
  en cadena. `"seq"` (piezas que salen), `"goal"` (pieza meta, en potencias de 2) y `"par_moves"`.

### Giros y reto del día

Autoload `Twist` (`kit/twist.gd`): `game.json -> "twists"` pone reglas encima de cualquier género
(oscuridad, espejo, contrarreloj con `levels[i].time_limit`, racha) y las mezclas las hace cada
juego con `Twist.has(...)` (laberinto `cola`, golf con monstruos `M`). Genéricos: `oscuridad`, `espejo`, `contrarreloj`, `racha` y
`fantasma` (guarda la mejor partida del nivel en `Save` -> `fantasma_<nivel>` y la repite con una copia
transparente del heroe). Propios: `viento` (golf), `tormenta` (pesca), `piedras` (fusión) e `ice`
(cajas: `sokoban_map.slide_end`), `wrap` (serpiente: `snake_map.step`) y `shuffle` (memoria: cartas
que se cambian; `swaps` y `last_swap` para el bot). `"daily_twists"` son los giros
que no cambian si un nivel se puede pasar: el botón «Reto» del título los usa (un nivel y un giro
según la fecha, 50 monedas una vez al día). Más en `GIROS-LEEME.md`.

### Saltar nivel

`FailPanel` ofrece «Saltar nivel» tras 3 derrotas en el mismo nivel (anuncio con premio; gratis
tras 5 o sin anuncios). Desbloquea el siguiente y lo abre; queda en QA como `level_skip`.

### Prueba A/B de un nivel

Si `game.json` trae `"ab": {"level": i, "id": "..."}` y ese nivel lleva `"variant_b"`, la mitad
de los jugadores (una moneda al aire guardada en el móvil, `Kit.ab_group()`) juega la versión B.
`Kit.current_level()` ya devuelve la que toca y la telemetría apunta `"g": "a"|"b"` solo en ese
nivel. El validador de la fábrica prueba la B con los bots como si fuera un nivel más.

## Progresión: premio diario, monedero y tienda de aspectos

Todos los géneros comparten una capa de "volver mañana" (en `kit/save.gd`, bloque `meta`):
- **Monedero**: al ganar un nivel se suman estrellas×10 + las monedas recogidas (máx. 40).
- **Premio diario** (`DailyPanel`): 7 días con premios crecientes (20 → 120); si te saltas un día,
  la racha vuelve a empezar. Sale solo al abrir el juego si hay premio pendiente.
- **Tienda** (`ShopPanel`, botón de la estrella en el título): 7 aspectos para el héroe (original,
  oro, hielo, fuego, menta, sombra, neón) que se compran con el monedero y se equipan al momento.
  Son un shader de cambio de tono (`Skins`), así sirven para cualquier arte que genere la fábrica:
  el héroe de plataformas, el de hordas, el coche de carreras y el guardián de la base en torres.
- **Misiones y pase** (autoload `Season`, `SeasonPanel`): 3 misiones diarias y 3 semanales elegidas
  por fecha (solo de los tipos que tienen sentido en el género) que se cuentan escuchando
  `level_start` / `level_complete`; se cobran con un toque (monedas + XP). El pase dura un mes:
  20 niveles de 500 XP (cada estrella da 10), premio gratis y premium (monedas y los aspectos
  exclusivos Estelar y Aurora, `price: -1` en `Skins`). Todo en `Save.meta()["season"]`.
- **Logros** (autoload `Feats`, pestaña «Logros» de `SeasonPanel`): 12 retos a largo plazo que valen
  para todos los géneros (primer nivel, sin morir, 3 estrellas, nunca te rindas, racha de 5, 10
  niveles, 30 estrellas, 3 días, reto del día, todo el juego y todo con 3 estrellas). Se cuentan con
  `level_start` / `death` / `level_complete` y dan monedas una sola vez. En las pruebas y con
  `--qa` no cuentan (salvo `Feats.set_meta("count_in_tests", true)`). Todo en `Save.meta()["feats"]`.
- **Compras** (autoload `Store`): `monedas_500`, `monedas_3000`, `pase_temporada` y `sin_anuncios`.
  Con el plugin `GodotGooglePlayBilling` (lo compila la imagen de la fábrica) compra, pide al
  servidor que la verifique (`functions/v1/juego-compra`) y solo entonces la da. `Store.fake` en
  las pruebas. `game.json -> "iap": false` la apaga. «Sin anuncios» corta `Ads.can_show_interstitial`.
- **Avisos y buzón** (autoload `Notify`): con el plugin `NotificationSchedulerPlugin` programa al
  salir del juego el premio diario, las misiones de hoy, el evento y un «vuelve»; pide permiso tras
  el primer nivel. `Notify.inbox()` junta lo que ha pasado (ataques, premios, regalos) y el título
  lo enseña una vez por sesión (`InboxPanel`).
- **Pasar a otro móvil** (`CloudPanel`, `Online.cloud_save` / `cloud_restore`): código + PIN.

## Datos anónimos de partida (aprender de los jugadores)

Si `game.json` trae `"telemetry": {"url", "key", "game", "version"}` (lo pone la fábrica), el
autoload `Telemetry` resume cada intento de nivel (gana / sale / reintenta, segundos, muertes,
estrellas) y lo envía por lotes a `registrar_partida`. Sin nombre, cuenta ni ID de publicidad; la
sesión es aleatoria en cada arranque; los bots (sin pantalla) nunca envían. En Ajustes aparece
«Datos anónimos: Sí/No». Detalles en `APRENDIZAJE-LEEME.md`.

## Clasificación online y retos entre amigos

El autoload `Online` (`kit/online.gd`) usa el mismo servidor que los datos de partida. Al superar
un nivel, el resultado muestra «Clasificación» (top 10 del nivel y tu puesto, `LeaderboardPanel`)
y «Retar», que comparte «Supera mis N puntos en el nivel X de …» con un enlace
(`game.json -> share_url`, la ficha de la tienda; en la web, la misma página con `?reto=N&n=X&de=Apodo`).
Nada se envía hasta que el jugador elige un apodo (3-14 letras o números, sin palabrotas; el
servidor vuelve a comprobarlo). Cada dispositivo guarda su mejor marca con un número aleatorio
del juego. En Ajustes, «Clasificación: Sí/No» (apagarla borra el apodo). En la web, el juego lee
el reto de la URL, abre ese nivel y al acabar dice si lo has superado. Servidor:
`supabase/migrations/20261010000011_marcadores.sql`; el autor ve y oculta apodos desde la app.

### Fantasmas (plataformas, runner y volador)

`PlatformerGame` graba tu recorrido (`[x, y]` cada 0,1 s, hasta 3000 puntos). Al acabar el nivel
lo deja en `Online.ghost_pending`; `Online.submit` lo sube (`fantasma_subir`) solo si esa marca es
tu mejor. Al empezar un nivel, `Online.ghost_download` baja la del que va justo por delante
(`fantasma_bajar`) y `GhostRunner` (`kit/platformer/ghost_runner.gd`) la pinta semitransparente con
su apodo, al ritmo de `time_in_level`. En Ajustes, «Fantasmas: Sí/No» (`ghosts`). Servidor:
`20261010000019_fantasmas.sql`.

### Eventos en directo

El título pide `Online.fetch_event()` (`evento_actual`): si el autor tiene un evento en marcha sale la
franja `EventBand` con su título y lo que queda. `"regalo"` → botón «Recoger N» (`Online.event_gift_claim`,
una vez por jugador). `"monedas_x2"` → `Online.coin_multiplier()` vale 2 y `ResultPanel` dobla el premio
del nivel. Servidor: `20261010000021_eventos.sql` (el autor los programa desde la app).

## Historia entre niveles

Si `game.json` trae `"story"` (lo escribe la directora), el autoload `Story` (`kit/story.gd`)
muestra la `intro` de cada nivel la primera vez que se juega (con el nivel en pausa) y su
`outro` encima del resultado. Funciona en todos los géneros porque escucha los eventos
`level_start` / `level_complete`. `DialogPanel` pinta el retrato (primer frame del sprite del
personaje), el nombre, el texto letra a letra y su voz si existe (`assets/voces/d<nivel>_<i>.wav`).
Tocar completa la frase o pasa; «Omitir» cierra. Nunca sale en bots ni capturas; en Ajustes,
«Historia: Sí/No» (al encenderla otra vez se ve desde el principio).

## Clip para redes

`qa/clip.tscn` graba 15 s del juego jugado por el bot, en vertical, con un gancho arriba los
3 primeros segundos (`texts.clip_hook`) y un cartel final con el héroe y la llamada
(`texts.clip_cta`). Se lanza con el Movie Maker de Godot; la fábrica lo pasa a MP4 (`fabrica/clip.py`):

```
godot --path . --resolution 720x1280 --write-movie clip.avi --fixed-fps 30 res://qa/clip.tscn -- --skip=0.5 --seconds=15
```

## Música

`assets/manifest.json` → `"musica"`: `menu`, `nivel` y `victoria` (.wav). La fábrica las compone para
cada juego (chiptune procedural, bucle perfecto). El título pone `menu`, el nivel `nivel` y al ganar
suena `victoria` una vez. Si falta una pista no pasa nada.

## Jugar en el navegador (dentro de la app)

Preset **Web** (sin hilos, para que funcione en cualquier móvil sin cabeceras especiales).
La fábrica exporta solo el paquete del juego: `--export-pack "Web" build/web/index.pck` (~1-2 MB).
El motor (`index.js` + `index.wasm`, ~38 MB) es común y se sube una vez con `fabrica/subir_motor.py`.

## Interfaz

El estilo sale de `assets/manifest.json` → `"ui"`, que escribe la fábrica a partir de la Biblia:
`perfil` (por defecto según la familia de estilo), `colores` por rol (fondo, panel, botón,
texto, acento...) y `fuente` opcional. Si no hay manifest, usa la paleta de `game.json`.
Sea cual sea la paleta, el texto siempre queda legible (contraste WCAG 4.5:1 o más).

## Idiomas

`game.json` → `"lang"` (el del juego) e `"i18n"`: `{"en": {clave: texto, "_levels": [{"name",
"questions"}], "_story": [...]}, "pt": {...}}`. `Kit.text()` usa el idioma elegido en Ajustes, si
no el del móvil, si no el del juego; lo que no está traducido sale en el original. Los niveles y
la historia traducidos se ponen encima de los originales (los mapas no cambian) y en otro idioma
la historia va sin la voz grabada. La fábrica lo rellena con `fabrica/textos/traducir.py`.

## Arena en directo

«Arena online» (juegos de arena, `kit/brawl/arena_panel.gd`): `arena_buscar` mete al jugador en una
sala y `arena_estado` dice quién hay y cuándo empieza; al empezar, `Online.arena_match` lleva la
sala, quién eres, los jugadores por puesto de salida y la hora de inicio. La escena de la arena
abre un `RealtimeChannel` (`kit/net/realtime_channel.gd`, Supabase Realtime por WebSocket) y:
cada uno manda en su luchador (`st` 12 veces por segundo), los disparos se mandan (`sh`) y se ven
en todos, la vida la decide el dispositivo del que recibe el golpe y las caídas se avisan (`ko`).
Los bots de relleno los mueve el anfitrión (el id más bajo). Sin cajas en directo. Para probarlo
sin red: `Online.fake_net_latency` (canales locales en el mismo programa).

**Cooperativo** (sala con amigos en modo «coop», `arena_match["modo"] == "coop"`): todos los
jugadores en el equipo 0 (`BrawlFighter.team`), sin fuego amigo ni objetivos aliados (`foes()`),
sin gas, y 3 oleadas de bots (`spawn_wave`, ids `w<oleada>_<n>`) que mueve el anfitrión; los demás
crean la siguiente al ver caer el último bot. Gana el equipo al acabar la tercera; si cae uno, la
cámara sigue a un compañero.

**Repeticiones de la liga** (`village_game.gd`): `deploy()` graba `[paso de física, tropa, x, y,
desvío]` (desvío redondeado para que se reproduzca exacto) y `_end_liga` sube `replay_data()`
(`liga_repeticion_subir`). Con `Online.liga_replay` la escena vuelve a soltar cada tropa en su paso
de física: misma simulación, mismo resultado (lo comprueba `_test_replay`).

## Torneo semanal

Botón «Torneo semanal» en el título (si hay servidor y lo online está encendido). `TournamentPanel`
pide `torneo_info` (nivel de la semana, tiempo que queda, tu mejor y premio del podio pasado),
`Online.torneo` marca que se juega el torneo y `ResultPanel` sube la marca con `torneo_enviar` al
acabar ese nivel. Reglas en `supabase/migrations/20261010000014_torneo.sql`.

## Charla con los personajes

En la pausa sale «Hablar con …» si el autor ha activado la charla (`Online.chat_active()`).
`ChatPanel` manda el mensaje a la función `charla` del servidor (clave anon) con el número
aleatorio del dispositivo; el personaje sale del diseño guardado allí, nunca del juego. Sin red
o sin cupo, contesta con sus frases de la historia.

**Interfaz dibujada por la IA**: si el manifest trae `ui.skin` (`panel`, `boton`,
`boton_primario` y sus márgenes), paneles y botones usan esos marcos 9-slice. Cada pieza se
comprueba al cargar: si el texto no se lee sobre su centro (contraste < 4), esa pieza se descarta
y se queda la de siempre (queda en `UI.skin_used` y en el registro QA). El título es un
`LogoTitle` (degradado, contorno grueso, sombra, brillo y entrada letra a letra) y `Look` pone el
fondo ilustrado (`ui.fondo_nivel`) detrás de cada nivel 2D.

El QA audita cada pantalla en los 4 perfiles y en 3 tamaños (móvil, móvil alargado, tableta):
botones de al menos 88 px, ningún texto cortado y todo dentro de la zona segura (notch).

**Nota táctil**: este proyecto usa `emulate_mouse_from_touch = true` (en Ashen está en false).
Los `Button` de Godot solo reaccionan al ratón: con la emulación apagada, menús y deslizadores
no responden al dedo. Lo comprueba una prueba que simula un toque real. Los controles del
juego usan `TouchScreenButton`, que solo escucha toques reales, así que nada se dispara dos veces.

## Lo que el QA ya ha pillado de verdad

Durante el desarrollo, las pruebas encontraron fallos reales en mi propio trabajo:

1. Con salto de 200 px el jugador subía 191 px y **no llegaba** a plataformas de 3 bloques.
2. Una plataforma encima de un precipicio hacía que, al saltar desde el suelo,
   el jugador **se diera en la cabeza y cayera** al hueco (trampa injusta).
3. La misma trampa con otra plataforma, al subir la altura del salto.

4. La parada de impacto contaba con el reloj del sistema: si el juego iba más rápido o
   daba un tirón, **se quedaba en cámara lenta para siempre** tras un golpe. Ahora cuenta frames.
5. Con la emulación de ratón apagada, **ningún botón de menú respondía al dedo** en el móvil.
6. Niveles con **pinchos justo después de un hueco** o de un puente móvil: imposibles de esquivar.
   El generador ya no los pone (regla 7b) y el analizador los pilla.
7. La plataforma móvil se quedaba corta del borde: el bot esperaba para siempre. Ahora el
   recorrido se calcula con el hueco libre real.

Ese es justo el papel del QA en la fábrica: lo que el agente fabrique pasará por aquí
antes de llegar al jugador.

## Reglas de código

Tabs, ASCII en el código, tipos explícitos, nunca class_name junto a un autoload,
comentarios numerados "1 -". Los textos del jugador están en game.json para poder traducirlos.
