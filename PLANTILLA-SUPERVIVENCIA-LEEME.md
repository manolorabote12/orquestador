# Plantilla de supervivencia: copiar la mecánica de cualquier juego de móvil

El género «supervivencia» (`orqkit/kit/survival`) ya no es una isla fija: **todo lo que define un
juego de supervivencia son datos**. Con un diccionario `survival` (en `game.json` para todo el juego
o en `levels[i].survival` para un nivel) se describen los objetos, las casillas del mapa, las
recetas, las criaturas, el frío y la mochila. Sin `survival`, el juego es la isla de siempre,
exactamente igual que antes.

Se copian **mecánicas** (cómo se juega), nunca nombres, dibujos ni textos de otros juegos.

## Qué se puede describir

| Pieza | Qué es | Campos |
|---|---|---|
| `items` | Lo que se lleva en la mochila | `food`, `water`, `heal` (al comerlo), `fuel` (segundos de hoguera), `cook` (en qué se convierte en la hoguera), `sick` (segundos enfermo si se come así) |
| `tiles` | Qué es cada letra del mapa | `walk`, `item` + `yield` + `time`, `tool` (herramienta que lo acelera), `needs` (herramienta sin la que no se puede), `regrow` (vuelve a salir), `loot` (`{objeto: n}` al saquearlo), `keep` (se queda al vaciarse: casas, coches), `water`, `den` (criatura que sale de ahí), `herd` (presas que pastan ahí), `look` y `tint` (cómo se dibuja) |
| `recipes` | Lo que se fabrica | `cost`, y lo que da: `tool` (`gather`, `dmg`, `warm`), `fire`, `build` (muro, puerta, mesa, cama delante de ti), `item`, `win` (gana la partida); `station` (`"fire"` o una construcción cerca) |
| `creatures` | Bichos | `hp`, `dmg`, `speed`, `when` (`night` o `always`), `hostile`, `fear_fire`, `flee`, `drops`, `look` (`wolf`, `zombie`, `beast`) y `color` |
| sueltos | Reglas generales | `cold` (frío por segundo de noche), `bag` (huecos de la mochila, 0 = sin límite), `tool_uses` (usos de cada herramienta, 0 = no se gastan), `palette` (`ground`, `sand`, `sea`), `names` (nombre de lo nuevo si no tiene texto `sv_<id>`) |

Cada sección se mezcla por clave con la de por defecto: lo que no se dice, se queda. `null` quita
una receta, un objeto o una criatura (p. ej. `"recipes": {"lanza": null}`).

## Estilos ya hechos (`"preset"`)

`"survival": {"preset": "zombis"}` o varios a la vez: `{"preset": ["zombis", "invierno"]}`.
Lo que traiga el nivel va encima del estilo.

| Estilo | Inspirado en | Qué añade |
|---|---|---|
| `zombis` | Last Day on Earth, Dawn of Zombies | Casas «H» y coches «C» que se saquean (lata, tela, chatarra) y se quedan en pie; zombis «Z» que salen siempre, no temen al fuego y sueltan tela; ciervos «A»; machete (en vez de lanza), venda, muro; mochila de 30; herramientas con 40 usos; meta: arreglar la radio |
| `invierno` | Frostborn, Whiteout Survival | Frío de noche (la hoguera, la cama o un abrigo de piel te calientan); ciervos «A» que dan carne y piel; bayas escasas; nieve y pinos |
| `caza` | Survival Island, Ark mobile | Ciervos «A» que huyen y jabalíes «J» que embisten de noche; la carne cruda enferma, asada alimenta el doble; selva |

En la fábrica son **giros** de la supervivencia: `apocalipsis`, `invierno` y `caza` (se pueden
juntar dos). La directora los elige si la idea habla de zombis y saquear, de frío y nieve o de
cazar y cocinar; el generador pone las letras que tocan (guaridas «Z» o «J», casas, coches y
prados) y comprueba que hay chatarra y tela de sobra.

## Ejemplo: un juego propio sin estilo

```json
"survival": {
  "items": {"coco": {"food": 18, "water": 15}, "concha": {}},
  "tiles": {"K": {"item": "coco", "yield": 2, "time": 0.6, "regrow": 40, "look": "B", "tint": "#8d6e3f"},
            "Q": {"item": "concha", "yield": 2, "time": 0.5, "walk": false, "look": "R", "tint": "#f3e5d8"}},
  "recipes": {"collar": {"cost": {"concha": 6, "fiber": 2}, "win": true},
              "cama": {"cost": {"wood": 5, "fiber": 4}, "build": "cama"}},
  "cold": 0.8,
  "names": {"coco": "coco", "concha": "concha", "collar": "Collar"}
}
```

Con `"goal": "receta"` en el nivel, fabricar el collar gana.

## Reglas que cambian con la plantilla

- **USAR** hace por orden: golpear lo que tengas al lado (bicho o presa), echar al fuego algo que
  arda, cocinar lo crudo en la hoguera encendida, beber y recoger o saquear. Si se va a beber,
  beber manda (antes el bot se moría de sed junto a la hoguera).
- **COMER** come lo mejor que lleves: lo que más alimenta sin enfermar. Lo crudo enferma (pierde
  vida mientras dure); la venda cura y quita lo enfermo.
- **Mochila**: lo que no cabe se pierde; el botón de fabricar sigue igual y el bot tira lo que le
  sobra para hacer sitio.
- **Construir**: el muro, la puerta, la mesa o la cama van a la casilla de delante. Ningún bicho
  cruza muros ni puertas; tú pasas por la puerta.
- **Guardar la partida**: al amanecer se guarda sola; si sales, al volver sigues ese día donde lo
  dejaste. Al ganar o perder se borra.
- Con más de 4 recetas, los botones de fabricar van en una fila que se desliza con el dedo.

## Bot y analizador (los mismos para todos los estilos)

El bot lee las recetas: fabrica la meta y las herramientas útiles (las armas solo si hay bichos
que atacan), se cura si está enfermo, cocina antes de comer crudo, va a la hoguera si tiene frío,
caza cuando lo que falta solo lo dan las presas (piel, carne), lucha contra lo que no teme al
fuego y no acapara leña. El analizador cuenta lo que dan las casillas, los saqueos y las presas
contra lo que piden la hoguera, las herramientas, la meta y la leña de todas las noches.

**Calibrado** (48 niveles por estilo, 3 dificultades): isla 48/48, zombis 48/48, invierno 48/48,
caza 48/48 y zombis + invierno 48/48. Antes, la isla sola aceptaba 42 de 48; el arreglo de beber
junto a la hoguera subió todo.

Pruebas: `--solo=survival` (las de siempre) y `--solo=survival_template` (estilos, saqueo,
mochila, herramientas que se rompen, muros, cocinar, enfermar, frío, guardar y el bot arreglando
la radio en la escena).

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

## Lo siguiente

La misma idea (reglas como datos + estilos + bot que lee los datos) para RPG por turnos, shooters
y los demás géneros complejos.
