# Plantilla de shooters: hordas y zombis 3D

Los dos shooters del kit ya son plantillas por datos: las armas, las mejoras y los enemigos se
describen en `game.json` (o en cada nivel) y el juego, los bots y el analizador los leen. Sin
datos, todo es como siempre. Se copian **mecánicas** de los juegos más jugados, nunca nombres,
dibujos ni textos.

## Hordas (`kit/horde`, clave `"horde"`)

Catálogo de serie y estilos en `kit/horde/horde_catalog.json`.

- **Armas**: cada una con su forma de atacar y sus números, fijos o uno por nivel (hasta 5):

  | Forma | Qué hace |
  |---|---|
  | `shot` | proyectiles al enemigo más cercano (y siempre uno al jefe si está a tiro) |
  | `fan` | abanico hacia donde miras |
  | `orbit` | objetos que giran a tu alrededor |
  | `aura` | halo que hiere a lo que se acerca |
  | `nova` | anillo en todas las direcciones |
  | `chain` | rayo que salta de enemigo en enemigo |
  | `bomb` | explosión donde hay más enemigos juntos |
  | `whip` | latigazo a los lados (puede curar cada X bajas) |

  Números: `cd`, `count`, `dmg`, `pierce`, `range`, `radius`, `spread`, `spin`, `gap`, `color`.
- **Mejoras**: `speed`, `hp`, `magnet`, `power`, `haste`, `area` (alcance y tamaño de todo) y
  `count` (un proyectil más en cada arma).
- **Evoluciones**: arma al máximo + su mejora = un arma nueva más fuerte. Cuando está lista, sale
  la primera al subir de nivel.
- **Enemigos**: cambios de vida, velocidad y daño a los de serie (walker, spiky, flyer, boss).
- **Bot**: lista de prioridad del estilo; las evoluciones, siempre primero.

### Estilos hechos (giros de la fábrica)

| Estilo | Inspirado en | Qué trae |
|---|---|---|
| `survivor` | Survivor.io | Kunai, drones que bombardean, relámpago en cadena, guardianes que giran, onda; mejoras de cargador y zona; 3 evoluciones |
| `vampiros` | Vampire Survivors | Látigo, ajo, agua bendita, libro que gira y varita; látigo sangriento (cura) y biblia eterna |

## Zombis 3D en primera persona (`kit/zombie`, clave `"fps"`)

- **Armas**: `dmg`, `rate` (segundos entre disparos), `mag`, `reload`, `spread`, `pellets`,
  `range` y `look` (cómo se dibuja: pistol, shotgun o rifle).
- **Ranuras**: `slots` dice con qué arma empiezas (`start`) y qué arma dan las letras `S` y `R`
  del mapa.
- **Zombis**: cambios de vida, velocidad y daño a walker, runner y brute.
- El analizador juega cada nivel con las armas del juego, así que lo inventado también se prueba.

## Contenido inventado por la IA

Como en el RPG y la supervivencia, la directora puede inventar las armas, mejoras, evoluciones y
enemigos de cada juego (un gato astronauta con pistola láser y satélites; cazadores de monstruos
con ballesta y trabuco). `fabrica/contenido.py` comprueba formas, márgenes y referencias; los
bots juegan cada nivel; si no sale, la fábrica vuelve al estilo probado y apunta la lección.

Pruebas: kit `--solo=horde_template` y `--solo=zombie_template`; fábrica
`python -m pruebas.prueba_plantillas` y la cadena entera en `prueba_giros`.
