# Plantilla de RPG por turnos: equipos de héroes y criaturas

El género «rpg» (`orqkit/kit/turns`) tiene dos modos:

- **Clásico** (como siempre): un héroe con Atacar, Especial, Poción y Defender (`turns_logic.gd`).
- **Equipo** (nuevo, plantilla por datos): se activa con `"rpg"` en `game.json` o en el nivel.
  Reglas en `turns_party.gd`, datos en `kit/turns/party_catalog.json`.

Se copian **mecánicas** de los RPG de móvil más jugados, nunca nombres, dibujos ni textos.

## Qué tiene el modo equipo

- **Equipo** de 1 a 4 héroes contra oleadas (una fila del mapa por oleada, una letra por enemigo).
- **Turnos por velocidad** (la barra de turno de Raid o Summoners War): cada tic todos suman su
  velocidad y el primero que llega a 1000 actúa. Arriba se ve quién va a actuar.
- **Habilidades** por héroe (hasta 4), con espera en turnos:

  | Campo | Para qué |
  |---|---|
  | `target` | a uno (`enemy`), a todos (`all_enemies`), a un aliado (`ally`), a todo el equipo (`all_allies`) o a sí mismo (`self`) |
  | `power`, `hits`, `drain` | cuánto pega (por el ataque), cuántas veces, cuánto recupera de lo que pega |
  | `heal`, `shield`, `cleanse` | cura, escudo y quitar estados malos |
  | `effects` | estados con duración (y probabilidad si se quiere) |
  | `cooldown`, `telegraph` | espera y aviso un turno antes |

- **Estados**: veneno, quemadura, regeneración, aturdido (pierde el turno), provocar (le pegan a
  él), ataque y defensa más o menos.
- **Elementos**: fuego > planta > agua > fuego (x1,3; al revés x0,8); luz y oscuridad x1,3 entre sí.
- **Uno contra uno** (`lineup`): solo pelea el primero de cada lado; al caer, sale el siguiente.
- **Pociones** (curan un 40 % a un héroe) y botón **AUTO**: juega la misma cabeza que el bot.
- El equipo sube un 6 % por nivel del juego (`hero_level`); los enemigos, con `mult`.

## Estilos hechos (`"rpg": {"preset": "equipo"}`)

| Estilo | Inspirado en | Qué trae |
|---|---|---|
| `equipo` | Raid, Summoners War, AFK Arena | Guerrero (provoca), maga (aturde y golpea a todos), sanadora (cura y bendice) y arquero (veneno); enemigos de todos los elementos |
| `criaturas` | Pokémon, Temtem | Tres criaturas de fuego, agua y planta con cuatro movimientos cada una, uno contra uno, rivales de los mismos elementos y un líder |

En la fábrica son los giros `equipo` y `criaturas` del RPG; la directora los elige si la idea habla
de héroes, gacha o Raid, o de criaturas, entrenadores o Pokémon.

## Un estilo propio

Todo va encima del catálogo: héroes, enemigos (por letra), habilidades, `party` y `lineup`; `null`
quita algo.

```json
"rpg": {
  "party": ["caballero", "bruja"],
  "heroes": {"caballero": {"name": "Caballero", "hp": 180, "atk": 17, "def": 40, "spd": 90, "element": "light", "look": "sword", "skills": ["golpe", "escudo_sagrado"]},
             "bruja": {"name": "Bruja", "hp": 95, "atk": 26, "def": 8, "spd": 110, "element": "dark", "look": "staff", "skills": ["chispa", "maldicion"]}},
  "skills": {"escudo_sagrado": {"name": "Escudo sagrado", "target": "all_allies", "shield": 0.2, "cooldown": 3},
             "maldicion": {"name": "Maldición", "target": "all_enemies", "power": 0.4, "effects": [{"status": "def_down", "turns": 2}], "cooldown": 3}},
  "enemies": {"G": {"name": "gárgola", "hp": 120, "atk": 15, "def": 40, "spd": 70, "element": "dark", "skills": ["mordisco"]}}
}
```

## Bot, analizador y generador

- **Una sola cabeza** (`TurnsParty.think`) para los enemigos, el bot de QA y el botón AUTO:
  puntúa cada habilidad lista por lo que consigue (daño, rematar, curar a quien lo necesita,
  aturdir al jefe, provocar cuando hay peligro, venenos, mejoras) y usa una poción si alguien
  está muy bajo y nadie puede curar.
- **Analizador**: oleadas válidas, enemigos y habilidades que existen, y la partida se gana con
  daño medio (con al menos un 25 % de vida del equipo) y con mala suerte (pegando un 10 % menos
  y recibiendo un 10 % más).
- **Generador** (`generar_rpg` con `estilos_rpg`): oleadas que crecen y el jefe al final; juega
  cada nivel con la copia en Python (`fabrica/niveles/rpg_equipo.py`, lee el mismo catálogo y da
  exactamente lo mismo que el kit) y quita o añade enemigos hasta que la vida que queda está
  entre el 75 % (fácil) y el 35 % (difícil).
- **Calibrado**: 72 de 72 niveles aceptados en cada estilo.
- Pruebas: `--solo=turns_party` en el kit y `python -m pruebas.prueba_plantillas` en la fábrica.

## Contenido inventado por la IA (cada juego, el suyo)

Además de elegir estilo, la directora puede **inventar el contenido de cada juego** en el campo
`contenido` del diseño: héroes, habilidades y enemigos (rpg) u objetos, recursos, recetas y
criaturas (supervivencia), con nombres del tema. Por ejemplo, una tripulación pirata con capitana,
artillera y cocinero, o un planeta con cristales en vez de roca, frutos luminosos y sombras de noche.

- Son **datos, nunca código**: `fabrica/contenido.py` comprueba forma, márgenes de cada número,
  que todo lo que se nombra exista y que cada héroe y enemigo tenga un ataque básico.
- Va a cada nivel encima del estilo, y el generador, el analizador y los bots juegan con él.
- Si no pasa el control, se quita en el diseño. Si con él no salen niveles justos, la cadena lo
  quita, rehace los niveles con el estilo probado y **apunta la lección**, que la directora lee
  la próxima vez. Si falla mucho en un género (menos del 70 % en 5 o más intentos), deja de
  pedirse hasta que vuelva a ir bien.
- Los nombres inventados se usan tal cual; los de serie siguen saliendo traducidos.
- Pruebas: `python -m pruebas.prueba_plantillas` y la cadena entera en `prueba_giros` (una
  tripulación pirata que pasa y un contenido imposible que se quita solo).
