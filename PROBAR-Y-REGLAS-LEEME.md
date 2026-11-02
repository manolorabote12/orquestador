# «Probar» antes de fabricar y reglas en todos los géneros

## 1. Probar un género antes de fabricar

En el taller, cada tipo de juego del catálogo («O elige un tipo de juego») lleva un botón **▶ Probar**.
Abre al instante una partida de muestra de ese género, con el mismo reproductor que «Jugar ya»
(el motor web común y un paquete de unos 7 MB). Así, quien no sabe qué es un «tower defense», un
«merge» o un «Archero» lo juega un minuto antes de gastar tuercas.

- **La partida empieza a jugar sola**: entra directamente en el nivel 1, sin pantalla de título, premio diario
  ni historia. Arriba pone «Muestra: <género>». Al volver al menú se queda en el título.
- **Las muestras son juegos de verdad**: cada una se fabrica con la plantilla de éxito de su género
  (o con su marca de género), pasa la misma validación con bots y se exporta solo para web. Con la
  directora simulada no cuesta nada de IA; el arte es el de la GPU de RunPod.
- **Dónde viven**: en el bucket público `motor`:
  - `motor/muestras/<genero>.pck` (el paquete)
  - `motor/muestras/indice.json` (`{"<genero>": {"titulo", "v", "mb"}}`)

  La app solo enseña «Probar» en los géneros que están en el índice, y pide el paquete con `?v=` para que una
  muestra rehecha no salga de la caché. La migración `20261026000038_muestras.sql` deja subir el
  índice en JSON.
- **Cuándo se fabrican**: en cada despliegue, el trabajo «muestras» de GitHub Actions hace las que faltan
  (los géneros nuevos). Corre después de Supabase y, si falla, no frena el resto. Para rehacerlas todas
  después de cambiar mucho el kit: Actions → Desplegar → Run workflow → muestras = `todas`. Cada
  llamada a RunPod para antes de su límite de tiempo y se repite mientras falten.
- **A mano**:

  ```
  cd fabrica
  python -m muestras --solo diferencias,arquero        (los .pck quedan en ./muestras_web)
  python -m muestras --faltan --subir --arte-real      (necesita SUPABASE_URL y la clave de servicio)
  ```

Código: `fabrica/muestras.py`, la tarea `muestras` de `fabrica/runpod_handler.py`, `--muestras` y
`--muestras-en` de `nube/desplegar.py`, el catálogo de `app/src/vistas/taller.ts`, y `muestra` en
game.json (lo leen `kit/ui/screens/title_screen.gd` y `kit/story.gd`).
Pruebas: `fabrica/pruebas/prueba_muestras.py`, `nube/prueba_desplegar.py` y
`supabase/pruebas/muestras.sql`.

## 2. Reglas en los géneros clásicos («reglas vivas»)

La IA ya podía cambiar la mecánica (capa 2) en los géneros cuya simulación es un diccionario. Ahora
también puede en **plataformas, runner, volador, hordas, torres y carreras**, que son juegos de escena con
física. La regla no toca nodos: recibe lo que pasa en la partida y mueve unos **mandos** que el juego
lee en cada fotograma.

| Mando | Qué cambia | Límites |
|---|---|---|
| `speed` | velocidad del héroe (o del coche) | 0,5 – 2 |
| `jump` | fuerza del salto (y del aleteo del volador) | 0,75 – 1,5 |
| `gravity` | gravedad del héroe | 0,6 – 1,5 |
| `enemy_speed` | velocidad de los enemigos (y de las oleadas de torres) | 0,3 – 2,5 |
| `damage` | daño del héroe y de las torres | 0,3 – 4 |
| `fire_rate` | cadencia de disparo (hordas y torres) | 0,3 – 4 |

La regla, además, recibe `st["stats"]` (cuántas veces ha pasado cada evento), `st["data"]` (para guardar lo
que quiera) y `st["say"]` (un aviso corto que el juego enseña una vez). Ganchos disponibles:
- `on_start` y `on_step`;
- `on_event(st, nombre, datos)`;
- `on_<evento>` (`coin`, `death`, `hurt`, `stomp`, `wave_start`, `tower_build`, `nitro`...).

Los mandos siempre se recortan a sus límites y un mando que no existe se borra. Como los bots juegan con la
regla puesta, el validador vuelve a comprobar el juego entero. Ejemplo que usa el agente simulado:
«cada moneda o enemigo vencido te acelera un 4 % (hasta un 40 %); un golpe te devuelve a tu velocidad».

### Y en todos los demás: la velocidad de la partida
El resto de géneros de escena (serpiente, memoria, puzles, shooters, RPG, supervivencia...) tienen un
mando más, que vale para **todos los géneros sin simulación propia**:

| Mando | Qué cambia | Límites |
|---|---|---|
| `game_speed` | velocidad de toda la partida (cámara lenta o rápida) | 0,5 – 1,5 |

Ejemplos que ya se pueden pedir: «al perder una vida, 3 segundos de cámara lenta para recolocarte»,
«cada 10 monedas el juego va un poco más rápido». Al acabar o perder el nivel la velocidad vuelve a 1, y
los golpes de efecto (la pausa corta al chocar) respetan la velocidad que haya puesto la regla.

Los géneros que llevan la partida en un diccionario (caída, sandbox, battle royale, tycoon, tragaperras,
reino, multitud, fusión, palabras, letras, torre de poder, diferencias, rompecabezas, pintar, cuchillos,
arquero, flechas, 2048, cartas locas, dominó, bloques de colores, tuberías, ajedrez, reversi, buscar objetos, deslizar, ahorcado, hundir la flota, Simón dice, estrategia por turnos, batalla automática, gemas y héroes, cartas coleccionables y el «a medida») ya llamaban a
las reglas desde su propia simulación, con más poder que los mandos.

**Resultado: los 109 géneros de plantilla admiten reglas programables**: 34 desde su simulación, 6 con
todos los mandos y el resto con la velocidad de la partida (y los eventos de siempre: monedas, golpes,
muertes...).

Código: `kit/mods.gd` (`LIVE_GENRES`, `SIM_RULES`, `tune()`), `kit/juice.gd`, los juegos de
`kit/platformer`, `kit/horde`, `kit/tower` y `kit/race`, y `GENEROS_VIVOS` / `GENEROS_SIM` en
`fabrica/agente_mods.py`.


## Modo 2 jugadores
En ajedrez, reversi, damas y conecta 4 la portada tiene «2 jugadores»: el segundo jugador mueve en el turno del rival (sin IA) en el mismo móvil. Es una partida justa (el primer nivel sin ventajas) que va como nivel extra: no cambia estrellas, desbloqueos ni logros. Código en `orqkit/kit/versus.gd`; para añadir otro juego de tablero hay que dejar jugar al segundo en el turno del rival, apagar la IA con `Kit.versus` y llamar a `Versus.finish(juego, ganador)`.

## Modo maratón
En cualquier género, cuando el jugador ha desbloqueado más de 4 niveles, la portada muestra «Maratón»: los niveles se juegan uno tras otro desde el 1 con 3 vidas (cada derrota quita una y se reintenta el mismo nivel). Al perder la última vida sale «Fin de la maratón» con los niveles superados y el récord (`maraton_record`). Código en `orqkit/kit/marathon.gd`; los paneles de victoria y derrota y el cartel superior (`MarathonBanner`) ya lo tienen en cuenta.

## Contrarreloj
En el selector de niveles, cuando ya se ha superado el nivel 1, sale el interruptor «Contrarreloj». Encendido, cada nivel enseña tu mejor tiempo y al jugarlo aparece abajo el reloj con el récord; al ganar se guarda el tiempo si es mejor (`crono_<nivel>`). El reto del día, la maratón y las partidas de 2 jugadores no guardan tiempos; la portada lo apaga. Código en `orqkit/kit/time_attack.gd` y `orqkit/kit/ui/time_banner.gd`.

### Clasificaciones de los modos
Usan la tabla de marcadores de siempre con números de nivel reservados: `1000 + n` es el contrarreloj del nivel n (puntos = 3.600.000 − milisegundos, así más es mejor) y `2000` la maratón (puntos = niveles seguidos). Para probarlo: pon apodo, enciende el contrarreloj, mejora un tiempo y pulsa «Clasificación» en el panel de victoria.

## Pistas
En cajas, tubos y sigilo hay «Pista» junto a Deshacer y Reiniciar. Precio en `orqkit/kit/hint.gd` (`FREE` gratis por nivel, `COST` monedas; con anuncios activos se ofrece un bonificado). Para añadirla a otro puzle con resolvedor: `Hint.make_button(self, use_hint)` en la barra, `Hint.reset(self)` al empezar, y en `use_hint` calcular el paso, `await Hint.pay(self)` y hacerlo.

## Cartas: colección y mazo
Código en `orqkit/kit/ccg/ccg_collection.gd` (colección `ccg_coll`, mazo `ccg_deck`, premios por nivel `ccg_rewarded`) y el editor en `ccg_deck_panel.gd`. Tamaño del mazo `DECK_SIZE` (20), copias `MAX_COPIES` (2) y legendarias (`dragon`, 1). Orden de premios en `REWARDS`.

## Lucha: combos
En `orqkit/kit/fighter/fighter_map.gd`: `CHAIN` (orden de cancelación), `BUFFER` (ticks que se recuerda el botón), `COMBO_SCALE` y `COMBO_MIN` (cuánto baja el daño). Para probarlo: pega un puñetazo de cerca y pulsa patada enseguida.

## Metroidvania: mapa
Botón de cuadrícula junto a la pausa (`orqkit/kit/metroid/metroid_map_panel.gd`). Solo enseña las salas ya visitadas; el juego queda en pausa hasta cerrarlo.

## Roguelike: explorar
`explore_path()` y `danger()` en `orqkit/kit/crawl/crawl_map.gd`; el botón «Explorar» del juego encadena tramos hasta que no queda nada o hay peligro.

## Táctica: previsión y peligro
`preview(st, a, b)` devuelve [daño, contraataque] y `threat(st, u)` la zona de peligro, en `orqkit/kit/tactics/tactics_map.gd`. Toca un rival para ver su zona (otra vez para quitarla).

## Batalla automática: sinergias
`SYNERGY` y `SYNERGY_NEED` en `orqkit/kit/autochess/autochess_map.gd` (solo para el ejército del jugador, así los niveles validados siguen siendo superables). La velocidad elegida se guarda en `ac_speed`.

## Aventura: historial y finales
El historial vive en `history` de `orqkit/kit/tale/tale_game.gd` (se ve en `tale_log_panel.gd`). Los finales descubiertos se guardan por capítulo en `tale_endings` (`endings_found(i)`, `record_ending(i, final)`).

## Torres: puntería
`AIMS` y `pick_target()` en `orqkit/kit/tower/tower_game.gd`; cada torre guarda su `aim` (first, strong, close). `wave_preview(k)` arma el texto de la siguiente oleada con `wave_plan(k)`.

## Mazmorras: talentos
`orqkit/kit/dungeon/dungeon_gear_panel.gd`: `TALENTS`, `MAX_LEVEL` (5), `STEP` (+5 %) y `BASE_COST` (60 monedas el primer nivel, luego 120, 180...). Se guardan en `dungeon_talents` y se aplican en `max_hp()`, `damage()` y `fire_rate()`.

## Reino: previsión
`forecast(st)` en `orqkit/kit/realm/realm_map.gd` simula la batalla contra el siguiente campamento (no hay azar) y devuelve si ganas y las bajas netas.

## Claves de texto
Cada género usa su propio prefijo en `Kit.text(...)` (flechas `ar_`, artillería `atl_`, comecocos `cm_`, roguelike `rl_`, sigilo `st_`, sandía `fm_`, autobús `bu_`, tirachinas `sg_`...). `fabrica/pruebas/prueba_claves.py` falla si una clave significa cosas distintas en dos géneros. Al crear un género nuevo, elige un prefijo que no exista.

## Cómo se juega
Las reglas de cada género están en `RULES` de `orqkit/kit/howto.gd` (claves `howto_<kit>_<n>`, traducidas en el catálogo). Para añadir un género: tres frases cortas en `RULES` y sus traducciones. Se marca como vista en `howto_<kit>`; con los bots y en las pruebas no sale.

## Tutorial interactivo
`orqkit/kit/tutorial.gd`. Pasos: `text`, `target` (nombre del nodo a señalar, p. ej. `BtnNextWave`) y `until`: `press`, `tap`, `event:<evento>` (de `QA.log_event`), `change:<ruta>` (`moves`, `st.gold`, `st.p.1.mana`) o `wait:<segundos>`. Los de cada género en `STEPS`; un juego puede traer los suyos en `game.json -> tutorial` (la fábrica los pone desde `diseno.tutorial`). Se marca como visto en `tut_<kit>`.

## Monetización
Perfiles en `orqkit/kit/monetize.gd` y la misma tabla en `fabrica/monetizacion.py` (`pruebas/prueba_monetizacion.py` comprueba que coinciden). Un juego cambia perfil o valores en `game.json -> monetization`. Para que un género ofrezca «Continuar», basta con añadirle `revive()`. Ver MONETIZACION-LEEME.

## Premio real y juego regalo
`kit/prize.gd` y `kit/gift.gd`. Los dos leen primero el servidor (lo guardan en `premio_info` y `regalo_info`) y, si no hay servidor, `game.json -> premio` y `game.json -> regalo`. Pruebas del kit: `--solo=prize`, `--solo=gift` y `--solo=rate` (opinión privada, `kit/rate.gd`). Ver NICHOS-LEEME.

## Estadísticas y experto
- **Estadísticas:** `kit/stats.gd` cuenta con los eventos `level_start`, `level_complete` y `death` (Twist se los pasa). Se guardan en `st_*` y se ven en `StatsPanel`.
- **Experto:** `kit/expert.gd` usa `game.json -> daily_twists`, con un giro por nivel (`twist_for`). La medalla se guarda en `experto_<nivel>`. No se puede usar a la vez que el contrarreloj.
- Prueba: `--solo=stats_expert`.

## Modo clase
`kit/classroom.gd`: el código y el apodo se guardan en `clase_codigo` y `clase_alias`. `ResultPanel` llama a `Classroom.sync()` al superar cada nivel. Prueba: `--solo=classroom`. Ver NICHOS-LEEME.

## Maratón sin fin
Si el juego tiene `daily_twists`, `Marathon.on_win` en el último nivel marca `lap_ready` en lugar de `done`. `next_lap()` vuelve al nivel 1 con una vida más (hasta 5) y `prepare()` pone el giro de cada nivel. La fila de botones cambia «Repetir» por «Vuelta N». Prueba: `--solo=endless`.

## Bots de la app
En `app/`: `npm run bot`. Hace el build de la demo y pasa dos bots:
- `pruebas/bot-recorre.cjs` recorre todas las vistas a 320, 360 y 412 px y pulsa los botones. Deja el informe y las capturas en la carpeta temporal `orq-bot`. El informe incluye contraste, desbordes, textos cortados, botones pequeños y tiempos. Con `ORQ_BOT_LANG=en` lo hace en inglés.
- `pruebas/bot-flujos.cjs` rellena los formularios y comprueba lo que pasa.

Hay que pasarlo antes de cada entrega que toque la app.

## Idioma de la app
La app se escribe en español. En inglés, `src/idioma.ts` traduce en la página los textos y los atributos `placeholder`, `aria-label` y `title`:
- usa los diccionarios `src/idioma-en.ts` e `idioma-en2.ts`;
- usa las reglas de `REGLAS` para los textos con números.

Al añadir un texto nuevo a la app, añádelo también al diccionario. Para ver qué queda en español: `node pruebas/bot-textos-en.cjs` (después de `npm run build:demo`; también cuenta los textos de las plantillas, que siguen en español). La prueba es `pruebas/idioma.mjs`.
