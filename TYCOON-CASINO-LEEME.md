# Tycoon y casino social

## Tycoon (`tycoon`, kit `tycoon`)

Tipo AdVenture Capitalist o Idle Miner Tycoon: se compran negocios que dan dinero cada pocos
segundos, se contratan gerentes para que trabajen solos y se junta la meta de dinero del nivel.

- **Negocios** (por defecto): cada unidad que compras sube lo que da el negocio y cuesta un poco
  más; a las 25, 50, 100... unidades va el doble de rápido. Botón x1, x10, x100 y MAX.
- **Mina** (giro `mina`, tipo Idle Miner): los pozos sacan mineral a su caja, el ascensor lo sube y
  el almacén lo vende. Cada parte sube de nivel y **la más lenta frena a las demás**: buscar el
  cuello de botella es el juego.
- Sin gerente, cada negocio trabaja un ciclo cuando lo tocas; con gerente trabaja solo.
- **Mejoras** que multiplican lo que da un negocio (o todo). La compra que más conviene sale con
  borde dorado (ayuda a quien empieza).
- **Ganancias sin conexión**: lo que tiene gerente sigue ganando con la app cerrada (hasta 2 horas)
  y al volver se recoge… o se dobla viendo un anuncio. La partida del nivel se guarda sola.
- **Inversores**: cada estrella ganada es un inversor que da un 2 % más en los niveles siguientes.

Todo es por datos (`kit/tycoon/tycoon_catalog.json`): la IA puede inventar los negocios de cada
juego (un imperio repostero con churrería, cafetería y fábrica de chocolate) con sus dibujos, y
cambiar los números un 30-40 % como mucho. La meta de cada nivel la calcula la fábrica con una
copia exacta de la simulación (`fabrica/niveles/tycoon.py`): el bot llega en un 80 % del tiempo de
3 estrellas, y el analizador del juego lo vuelve a comprobar.

## Tragaperras con aldea (`tragaperras`, kit `slots`) · casino social, +18

Tipo Coin Master: cada tirada da monedas **de mentira**, tiradas gratis o bonus (elegir un cofre
x1/x2/x4 o un asalto en el que se excavan 3 de 9 hoyos). Con las monedas se construye la aldea
(5 edificios con 3 mejoras cada uno); al terminarla se gana el nivel.

- Apuesta x1, x2, x3 o x5 (gasta más tiradas y paga más).
- Las tiradas se recargan con el tiempo (también con la app cerrada) y con un anuncio (+15):
  es lo que más ingresos da en este tipo de juegos.
- Las monedas del casino **no se compran ni se cambian por nada**: el juego lo dice en pantalla.
- La fábrica nunca lo hace infantil y en Play Console lo declara como **simulación de apuestas**
  con público de 18 o más (Google lo exige).
- La IA puede inventar los símbolos y la aldea del tema (isla pirata con doblones, loros, puerto y
  fortaleza). El tamaño de la aldea lo calcula la fábrica con lo que da de media una tirada, y el
  analizador juega 10 partidas para comprobar que se termina a tiempo pese a la suerte.

## Estilo dados (giro `dados`, tipo Monopoly Go)

En vez de rodillos, dos dados y una ficha que da la vuelta a un tablero de 20 casillas: monedas,
sacos, cofres, asaltos, tiradas extra e impuestos; pasar por la salida paga. Misma aldea, tiradas,
apuestas y anuncios. El tablero también es por datos (`board`, `tiles` y `pass` en el catálogo).
