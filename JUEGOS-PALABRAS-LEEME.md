# Juegos de palabras: adivina la palabra y palabras con letras

Dos géneros nuevos de los que más se juegan en Google Play. Los dos funcionan en **los 6 idiomas
del juego** (español, inglés, portugués, francés, alemán e italiano) sin traducir nada: cada
jugador recibe las palabras de su idioma.

## Adivina la palabra (`palabra`, kit `wordle`)

Tipo Wordle: hay que acertar una palabra oculta en pocos intentos. Cada letra se pinta de verde
(en su sitio), amarillo (está, pero en otro sitio) o gris (no está). El teclado recuerda las
pistas. Cada intento tiene que ser una palabra de verdad.

- Por nivel: `len` (4 a 7 letras), `tries` (intentos), `rank` (lo rara que es la palabra) y
  `hard` (modo difícil: obliga a usar las pistas). La fábrica los sube poco a poco.
- Una **pista** gratis por nivel (descubre una letra). Estrellas según los intentos usados.
- Si pierdes, te enseña la palabra y al reintentar sale **otra** (si no, ya te la sabrías).
- El analizador juega cada nivel en los 6 idiomas con un bot que razona como una persona
  (prueba palabras que encajan con todo lo visto): en las pruebas acierta siempre en 5 intentos o menos.

## Palabras con letras (`letras`, kit `letters`)

Tipo Wordscapes: una rueda de letras y un crucigrama. Se desliza el dedo por las letras para
formar palabras; las del crucigrama se escriben en él y las que existen pero no están dan una
moneda extra.

- Por nivel: `len` (letras de la rueda, 4 a 7), `words` (palabras del crucigrama, 3 a 9) y `rank`.
- El crucigrama lo monta el juego: palabras que se cruzan sin tocarse de lado, de las más
  conocidas primero. Botones de **barajar** y **pista** (3 por nivel).
- El analizador comprueba que el crucigrama sale completo en los 6 idiomas.

## Los diccionarios

Están en `orqkit/kit/words/dicts/` (unas 30.000 palabras por idioma, 9.000 de ellas pueden ser
solución). Salen de las listas de frecuencia de **wordfreq** sin nombres propios ni palabrotas.
Su licencia es **CC BY-SA 4.0** (atribución en `dicts/LICENCIA.txt`): afecta solo a las listas,
no al juego. Se rehacen con `python -m textos.diccionarios` (solo quien mantiene el Orquestador).

El nivel no guarda palabras, solo una semilla (`"#1234"` en el mapa): así el mismo nivel vale en
todos los idiomas y el juego pesa poco. Los diccionarios entran en la APK (`export_presets.cfg`).

## Arreglos de paso

- El traductor de los juegos se liaba con «palabras con letras» (allí `words` es un número).
- Los diccionarios no habrían entrado en la APK: ya se exportan.
