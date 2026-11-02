# Monetización de los juegos

Cada juego se monetiza según su **tipo**. El perfil sale solo del género. El autor puede cambiarlo en la app, en la sección «Anuncios (AdMob)», y la fábrica lo explica en `fabrica/monetizacion.json` de cada juego.

| Perfil | Géneros (ejemplos) | Banner | Intersticial | Anuncios con premio | Compras que destaca |
|---|---|---|---|---|---|
| Hipercasual | corredor, apilar, espiral, cuchillos, serpiente | solo menús | cada nivel (45 s entre uno y otro, máx. 10) | continuar, premio doble, saltar nivel | sin anuncios, monedas |
| Puzle | puzle, tubos, cajas, sopa, sudoku, mahjong, tuberías | menús y partida | cada 2 niveles | pista, movimientos extra, premio doble, saltar | sin anuncios, **pack de inicio**, monedas |
| Arcade y acción | plataformas, naves, karts, lucha, metroidvania | solo menús | cada nivel (90 s, máx. 6) | continuar, premio doble, cofre | sin anuncios, monedas, pase |
| Estrategia y midcore | torres, táctica, imperio, reino, cartas, mazmorras | no | cada 3 niveles (máx. 3) | acabar obra, cofre, energía, premio doble | **pack de inicio**, pase, monedas |
| Idle y gestión | clicker, tycoon, granja, ciudad | menús y partida | cada 3 niveles + **anuncio al volver a la app** | doblar lo ganado, turbo, premio doble | pase, monedas, pack |
| Tablero y clásicos | ajedrez, damas, solitario, parchís | menús y partida | al acabar cada partida | pista, premio doble | sin anuncios |
| Casino | tragaperras | solo menús | cada 2 | tiradas gratis | monedas, pack |
| Infantil | todo juego «para peques» | no | **no** | solo premio doble | — |

## Lo que lleva el kit
- **Banner adaptable de AdMob** abajo. La interfaz deja su hueco y el validador comprueba que todo cabe con él. Los 119 géneros se auditaron así.
- **Intersticial** solo en pausas naturales, con la cadencia del perfil.
- **Segunda oportunidad con anuncio** al perder, una vez por nivel. Lo tiene cualquier juego con `revive()`, y `revive_text()` cambia el texto del botón:
  - **«Continuar»** en naves, corredor 3D, rompebloques, cuchillos, hélice, torre de bloques, cruzar la carretera, cortar fruta (quita las bombas), caída de bloques (vacía las filas de arriba) topos (más tiempo o un corazón), serpiente (gira hacia un hueco libre) y escalada (el coche de pie y medio depósito). En Simón, «una vida más».
  - **«+15 segundos»** en el agujero.
  - **«+N intentos»** en tiro con arco (+3 flechas), canastas y penaltis (+2 tiros) y bolos (+1 tirada).
  - **«Una vida más»** en sudoku, buscaminas, nonogramas y ahorcado.
  - **«+N movimientos»** en deslizar, block jam y puzle de piezas.
  - En los puzles cuenta como anuncio «extra_moves».
- **Pista en los juegos de tablero y cartas** (ajedrez, damas, reversi, conecta 4, ocho locos, mazo, dominó, parchís y hundir la flota; el solitario ya la tenía): el bot hace tu jugada. La primera es gratis; las siguientes cuestan un anuncio o monedas.
- **Turbo x2 durante 20 s** con anuncio en el idle (una vez por intento) y **x2 de lo ganado fuera** en el tycoon.
- **Anuncio al volver a la app** (idle).
- **Pack de inicio** (2000 monedas + sin anuncios, 3,99 €, una vez): oferta de bienvenida tras el nivel 3 y en la tienda. Al reinstalar, devuelve «sin anuncios» pero no las monedas.
- «Sin anuncios» quita el banner, el intersticial y el anuncio al volver. Los anuncios con premio siguen, porque los pide el jugador.

## Qué tiene que crear el autor
- **En AdMob**: una app y sus bloques. Intersticial y bonificado siempre. **Banner** y **Apertura de app** solo si su perfil los lleva (la app lo dice). Sin bloque propio, ese formato no se usa: nunca anuncios de prueba en la tienda.
- **En Google Play**: los productos se crean solos al publicar (ahora 5, con el pack de inicio).
