# Géneros hechos a medida (capa 3 de «cualquier juego»)

Las plantillas cubren los 86 géneros que más se juegan; para lo que no encaja en ninguno, la
fábrica ya puede **programar un género nuevo solo para ese juego**.

## Cómo se pide

En el taller, marca «Inventar un género nuevo solo para este juego (beta)». La app envía la idea con
`[a_medida]` delante. Sin esa marca, la directora nunca elige este camino (cuesta más IA y tarda más).

## Qué hace la fábrica

1. Diseña el juego como siempre (título, héroe, arte, música...) con el género `a_medida`.
2. Copia la plantilla de género (`kit/custom`: un juego de cuadrícula que ya funciona) **dentro del
   proyecto de ese juego**, no en el kit de todos.
3. Claude reescribe tres archivos GDScript: las reglas y la pantalla (`custom_game.gd`), el
   analizador **y el generador de niveles** (`custom_map.gd`, con `generate(i, n, d, semilla)`) y el
   bot (`custom_bot.gd`). Todo en GDScript: no se ejecuta Python escrito por la IA.
4. Antes de ejecutar nada, la revisión de seguridad rechaza sistema, red, archivos, cargar scripts
   de fuera, autoloads en el analizador, espacios en vez de tabulaciones o caracteres no ASCII.
5. Godot genera 4 variantes de cada nivel con su generador, el analizador las comprueba y los bots
   juegan el juego entero. Si algo falla, Claude recibe los errores y lo corrige (hasta 3 rondas).
6. Si no lo consigue, el juego sale con la plantilla probada y un aviso: nunca un juego roto.

Las variantes de cada nivel se guardan en el diseño (`a_medida_mapas`): si el bot no supera un
nivel, la fábrica prueba otra variante, igual que con los géneros de siempre.

## Pruebas

`fabrica/pruebas/prueba_a_medida.py`: revisión de seguridad, generador del proyecto llamado desde
la fábrica y un juego entero fabricado con `[a_medida]` y superado por su bot.
