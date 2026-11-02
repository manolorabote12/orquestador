# Plantillas de estrategia y carreras: imperio y karts

## Imperio (`kit/empire`, clave `"empire"`)

El imperio (tipo Age of Empires) ya se configura por datos. **Los papeles no cambian**: aldeano,
lancero, arquero, jinete y ariete, con su piedra, papel, tijera. Así la IA rival y el bot siguen
sabiendo jugar. Lo que cambia es todo lo que se ve y se siente:

- `units`: nombre y números de cada tropa (vida, daño, velocidad, alcance, coste, tiempo...).
- `builds`: nombre (y números) de cada edificio, como el alcance y el daño de las torres.
- `ages`: coste de subir a la Edad II y III.
- `res_names`: nombre de los recursos (por ejemplo, energía, metal y cristal).

Antes de jugar, `MapRules.apply(level)` pone el catálogo. Sin datos, todo es como siempre.

| Estilo (giro) | Qué trae |
|---|---|
| `fantasia` | Peones, guardianes, elfas arqueras (más alcance), jinetes de grifo, gólems; ciudadela y torre de mago; maná en vez de oro |
| `galactico` | Drones mineros, marines, francotiradores, motos aéreas y tanques de asedio; base, hangar y torretas; energía, metal y cristal |

La IA puede inventar los nombres y los números de cada juego: un imperio de hormigas con
obreras, soldados y una reina que derriba muros, con azúcar, hojas y miel. Los números se
quedan como mucho un 30-40 % arriba o abajo de los de serie, para no romper el equilibrio.

## Karts (`kit/kart`, clave `"kart"`)

Los objetos de la ruleta son datos. Cada uno tiene un **efecto** que el kit sabe hacer, cuánto
sale según tu puesto (delante, en medio o detrás) y, si hace falta, duración y cargas:

| Efecto | Qué hace |
|---|---|
| `seek` | Sale hacia delante siguiendo la pista y va a por el de delante |
| `trap` | Se queda en la pista detrás de ti |
| `boost` | Acelera durante `dur` segundos |
| `star` | Acelera y nada te para durante `dur` segundos (nuevo) |

`count` da varias cargas (la cáscara triple dispara tres veces). `null` quita uno de los de serie.
El estilo **fiesta** (giro) añade la estrella y la cáscara triple, tipo Mario Kart. La IA puede
inventar los objetos de cada juego: unos karts de cocina con un tomate que persigue, una mancha
de aceite y una guindilla turbo.

En las carreras online los objetos nuevos funcionan igual, porque cada móvil decide los golpes
sobre su propio kart.

## Pruebas

En el kit, `--solo=empire` (incluye el estilo galáctico con el bot conquistando) y
`--solo=kart_items`. En la fábrica, `python -m pruebas.prueba_plantillas`.
