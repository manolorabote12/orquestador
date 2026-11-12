# Modo estudio: más creatividad y más pulido (13 nov 2026)

El modo de siempre hace un juego en ~10 minutos y por ~0,35 $. El **modo estudio** gasta más IA
y más tiempo en el mismo juego para que salga más original y más pulido. Se pide con `[estudio]`
delante de la idea (por ahora desde el Escaparate → `encargar_idea`; en la app irá como opción
premium).

## Qué cambia

| Fase | Modo normal | Modo estudio |
|---|---|---|
| Diseño | Una pasada de la directora | **Directora creativa**: 3 conceptos distintos, autocrítica (gancho, claridad, retención, originalidad, encaje), elige y mejora el mejor; el diseño lo sigue |
| Género a medida | 3 rondas, tope 3 $ | 8 rondas, tope 6 $, con memoria de lo que ya falló |
| Género | Uno de los 120 de plantilla | Si ninguno encaja, la directora creativa pide un **género a medida** (Claude lo programa) |
| Crítica visual | Modelo barato | Modelo superior (decide qué se queda en el pulido) |
| Pulido | — | Hasta 3 rondas: capturas → crítica visual → arreglo → otra crítica. Se queda solo si los bots siguen ganando y la nota no baja |

Variables (las pone el modo estudio solo para ese juego): `ORQ_CONCEPTOS=1`,
`ORQ_A_MEDIDA_AUTO=1`, `ORQ_MODELO_CRITICA`, `ORQ_A_MEDIDA_RONDAS`, `ORQ_A_MEDIDA_USD`, `ORQ_PULIR_RONDAS`, `ORQ_PULIR_USD` y
`ORQ_MODELO_PROGRAMADOR` (modelo para programar; por defecto el superior).

## Resultado del laboratorio (13 nov, 8 ideas, juez a ciegas)

La directora creativa gana **8 de 8**. Media sobre 50: 27,9 → 37,1. Gancho 5,2 → 7,6; retención
4,9 → 7,2; originalidad 3,5 → 7,1; encaje con la idea 7,5 → 8,4; claridad igual (6,8). Coste del
laboratorio: 1,74 $.

## Piezas

- `fabrica/director/conceptos.py`: la directora creativa. Si falla por lo que sea, el juego sigue
  como siempre.
- `fabrica/pulir.py`: el bucle de pulido.
  - En los géneros de plantilla arregla con un **mod cosmético** (partículas, temblor, destellos y
    textos en los eventos reales del género).
  - En un **género a medida**, Claude mejora `custom_game.gd` viendo las capturas y el bot lo
    vuelve a jugar entero.
- `fabrica/laboratorio.py` + workflow **«Laboratorio de prompts»**: prueba A/B a ciegas.
  - Modo `ab`: diseño normal contra diseño con la directora creativa; un juez puntúa los dos sin
    saber cuál es cuál.
  - Modo `generos`: comprueba que la directora creativa no empeora la elección de género.
  - El informe va a la rama `laboratorio`. Una mejora de prompt solo se enciende para todos si
    gana aquí.

## Arreglos que salieron de la prueba de fuego (reino tipo Kingshot)

- «Al estilo Kingshot» salió como **RPG por turnos**. Causas y arreglos:
  - El diseño de Sonnet se cortaba a ~2.700 tokens (límite 3.000) y caía a Haiku. Ahora hay 8.000
    tokens y un reintento con el doble si se corta.
  - Los errores de validación quedan en el informe (`errores_diseno`).
  - Los juegos famosos nombrados en la idea (kingshot, flappy, clash royale, 2048, angry birds...)
    fijan su género (`director.famoso`).
  - Una paleta sin colores oscuros se arregla sola en vez de tumbar el diseño.
- **Reino**: los 7 edificios se dibujan con el arte y el mundo del juego (`edif_<look>`), con
  partículas al terminar obras y al ganar.
- **RPG**: personajes un 30 % más grandes, más abajo y con sombra; sin franja de suelo vacía.
- **Reto del día**: niveles de reserva (con las piezas nuevas del runner se quedaba sin reto).
