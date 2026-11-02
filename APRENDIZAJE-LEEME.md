# Cómo aprende Orquestador

Tres capas, de lo más inmediato a lo más ambicioso. Todas están probadas con datos de prueba; la segunda y la tercera mejoran solas cuanta más gente juegue.

## 1. Aprende de la gente que juega cada juego

| Pieza | Qué hace |
|---|---|
| `orqkit/kit/telemetry.gd` (autoload `Telemetry`) | Resume cada intento de nivel: **gana**, **sale** (lo deja a medias) o **reintenta**, con segundos, muertes y estrellas. **Nada más**: no envía nombre, cuenta, ID de publicidad ni ubicación. La sesión es un número aleatorio nuevo en cada arranque. Envía por lotes y guarda lo pendiente si no hay conexión. Las partidas de los bots (sin pantalla) **nunca** se envían. |
| Ajustes del juego | El botón «Datos anónimos: Sí/No» aparece solo si el juego envía datos. |
| `registrar_partida` (Supabase, clave pública) | Valida cada intento: si no tiene la forma exacta, se ignora. Pone límites por sesión y hora y por juego y día, y solo acepta juegos que existen. |
| `informe_jugadores` (solo el autor) | Por versión y nivel: intentos, jugadores, victorias, abandonos, muertes, tiempo y estrellas. |
| App > ficha del juego > **Cómo lo juega la gente** | Barras por nivel, cuánta gente llega a cada nivel y consejos claros. Por ejemplo: «En el nivel 3 se rinde el 46 %». Con **«Que Chispa lo arregle»** el arreglo pasa al taller y ahí ves el precio antes de aplicarlo. |

**Reglas de los consejos** (`app/src/aprendizaje.ts`). Solo se opina con al menos 15 intentos por nivel:
- **Abandono:** más del 40 % lo deja a medias y menos del 50 % lo pasa → nivel más fácil.
- **Demasiado difícil:** lo pasa menos del 35 % (el último nivel, menos del 25 %) con 2 muertes o más de media → nivel más fácil.
- **Sin reto:** un nivel intermedio que pasa más del 95 % casi sin morir → nivel más difícil.
- **Embudo:** del nivel N al N+1 sigue menos del 40 % de la gente → el nivel N más fácil.
- **Todo difícil:** si el 60 % de los niveles se atraganta → todo el juego más fácil.

**Privacidad y Google Play:** si el juego envía datos, la política de privacidad y las respuestas de «Seguridad de los datos» lo declaran solas (en `play/cuestionarios.py`). Se declaran como datos anónimos de actividad en la app, solo para analíticas y sin compartir con nadie.

## 2. La fábrica aprende de todos los juegos

`fabrica/aprendizaje.py`:

- **De sus propias pruebas.** De cada juego fabricado apunta, nivel a nivel, cuántas veces hubo que rehacerlo hasta que el analizador y los bots lo aceptaron. Se guarda en `datos/fabrica.jsonl`.
- **De los jugadores de todos los juegos.** Usa `estadisticas_globales()`, agrupado por género, dificultad y tramo del juego (0 = primer nivel, 4 = último).
  - Solo cuentan juegos con al menos 20 intentos.
  - Solo se aprende con al menos 3 juegos y 200 intentos, para que un juego raro no lo tuerza.
- **Calibración** (`datos/calibracion.json`): un ajuste entre −0,3 y +0,3 por género, dificultad y tramo. El generador lo aplica a los **juegos nuevos**, para acercarse a esta curva de victoria:

  | Tramo | 0 | 1 | 2 | 3 | 4 |
  |---|---|---|---|---|---|
  | Victoria objetivo | 85 % | 75 % | 65 % | 55 % | 45 % |

  - Si la gente abandona mucho, se suaviza aunque gane.
  - Lo que pida el usuario en el taller se suma encima, con un tope de ±0,6.
- El trabajador recalcula cada 6 horas. Para verlo: `python -m aprendizaje informe`. Para apagarlo: `ORQ_APRENDER=0`.

## 3. Aprende géneros nuevos (agente de IA)

`fabrica/agente_genero.py` es una herramienta para quien mantiene Orquestador, no para los usuarios:

```powershell
python -m agente_genero "sokoban: empujas cajas hasta sus huecos sin quedarte atascado" sokoban sokoban --claves sokoban,cajas
```

1. Crea el esqueleto del género con `nuevo_genero`: plantilla jugable, analizador, bot y generador, ya conectado en todo.
2. Claude reescribe esas cuatro piezas para el género pedido, cumpliendo el contrato del kit.
3. **Antes de ejecutar nada**, el agente rechaza:
   - el código que use el sistema, la red o ficheros fuera de `user://`, o que cargue scripts de fuera;
   - el código que no cumpla las reglas del kit: tabulaciones, ASCII y sin `class_name`.
4. Lo prueba de verdad: fabrica un juego entero y comprueba que su bot gana todos los niveles.
5. Si falla, le devuelve los errores a Claude y vuelve a intentarlo, hasta 4 rondas. Si no lo consigue, deshace todo.
6. Deja un informe en `datos/agente/<género>.json`. Antes de activarlo para los usuarios, revísalo y calíbralo por lotes (ver `GENEROS-LEEME.md`).

## Entrenar a la directora y calibrar por lotes

- `python -m pruebas.eval_director`: 60 ideas escritas como las escribe la gente (con faltas,
  marcas, mezclas y alguna ambigua con dos respuestas válidas) y 3 ideas para niños. Mide si la
  directora elige bien el género. La directora sin IA (la red de seguridad) acierta 60/60.
  Con `--real` usa la directora de verdad (Claude); cuesta unos céntimos y pide un 95 %.
- La guía de la directora (`director/prompt_director.md`) lleva reglas por género y ejemplos
  «idea → género» distintos de los de la prueba, para no hacer trampa.
- `python -m pruebas.lote_calibracion`: fabrica con la cadena entera un juego de cada uno de los
  28 géneros en normal y en difícil. Cada fabricación apunta cuántas veces hubo que rehacer cada
  nivel; al terminar recalcula la calibración y deja el resumen en `datos/lote_calibracion.json`
  (qué salió, si eligió bien el género y la dificultad, muertes del bot por juego). Se puede
  limitar: `python -m pruebas.lote_calibracion golf,pesca facil,normal`.
- Los 4 géneros nuevos calculan su dificultad con lo que el bot consigue de verdad: el par de cada
  hoyo de minigolf, el tiempo de la pesca (tiempo del bot × margen para personas) y la meta de la
  fusión (lo más alto que el bot logra en pocas jugadas).

## Aprender de los errores con los giros

Ver `GIROS-LEEME.md`: si un giro rompe un juego se quita y se rehace sin él, cada fallo queda como
lección para la directora y lo que falla mucho en un género deja de ofrecerse allí. Todas las
máquinas de la fábrica aprenden de lo mismo (servidor: `giro_anotar` / `giros_estadisticas`).
`python -m giros informe` enseña la tabla.

## Pruebas

- `python -m pruebas.prueba_telemetria`: un juego fabricado, jugado por el bot en Godot, envía su lote con la forma exacta de `registrar_partida`. Sin el permiso de prueba, el bot no envía nada.
- `python -m pruebas.prueba_aprendizaje`: la calibración, sus límites y que el generador la use y se pueda apagar.
- `python -m pruebas.prueba_agente`: una IA falsa se equivoca dos veces (código peligroso, error de sintaxis) y acierta a la tercera.
- `cd app && npm test`: las reglas de los consejos.
- `supabase/pruebas/aprendizaje.sql`: registro, validación, límites, informe solo para el autor y estadísticas globales sobre PostgreSQL de verdad.
- Kit: 5 pruebas de `Telemetry` en `qa/test_runner.gd`.

**No probado aquí:** el agente con Claude de verdad (en este entorno no hay clave de la API). El circuito completo sí está probado con la IA falsa.
