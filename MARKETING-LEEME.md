# Marketing que promociona solo (sin spam)

Dos frentes: que **Orquestador** se conozca fuera y que **cada juego** gane jugadores y dinero.

## Orquestador, fuera de la app

| Qué | Dónde | Cómo |
|---|---|---|
| Web que crece sola en Google | `nube/seo.py`, `web.yml` (cada día) | Una página por tipo de juego en español e inglés («Crea tu imperio de negocios: crea este juego sin programar»), una por cada juego del escaparate con datos `VideoGame` para Google, sitemap y robots. Cada juego nuevo del escaparate suma una página |
| Una publicación al día | `marketing/promo_orquestador.py`, `promocion.yml` | Juego de la semana, un tipo de juego que se puede crear o un consejo; el domingo descansa. Bluesky, Mastodon, Telegram, Discord, X y Reddit (solo los subreddits que apuntes), con sus APIs oficiales |
| Conversaciones donde ayudamos | `marketing/comunidad.py` | Busca en Bluesky y Reddit preguntas como «¿cómo hago un juego sin programar?», descarta anuncios, lo viejo y los subreddits que no quieren promoción, y redacta una respuesta útil que dice que es del equipo. Te llega al Telegram privado: la revisas y la publicas tú. **Nunca responde sola** |
| Creadores y streamers | `marketing/creadores.py` | Canales de YouTube medianos (1.000-300.000), activos, con correo público: un correo personal con su vídeo y la opción de no volver a escribir. Lo envías tú (enlace mailto listo) |
| Campañas de pago | `marketing/campanas.py` | Plan de campaña de aplicaciones de Google Ads: titulares de 30, descripciones de 90, países por grupos (primero los baratos para aprender), presupuesto con tope y reglas de prudencia; CSV para Google Ads Editor |

### Reglas anti-spam (las pone el difusor, no se pueden saltar)
Límite de publicaciones por red y día, intervalo mínimo entre dos, nunca el mismo texto dos veces,
Reddit solo en subreddits apuntados y como mucho una vez por semana en cada uno, Discord sin
menciones y todo apuntado en un registro.

### Claves (secretos de GitHub; sin ellas esa red simplemente no se usa)
`ORQ_BSKY_USUARIO` y `ORQ_BSKY_CLAVE_APP` (contraseña de aplicación de Bluesky), `ORQ_MASTODON_TOKEN`
(+ variable `ORQ_MASTODON_INSTANCIA`), `ORQ_TELEGRAM_TOKEN` (+ variable `ORQ_TELEGRAM_CANAL`) y
`ORQ_TELEGRAM_ADMIN` (tu chat privado para los borradores), `ORQ_DISCORD_WEBHOOK`, `ORQ_X_TOKEN`,
`ORQ_REDDIT_CLIENTE`/`SECRETO`/`REFRESH` (+ variable `ORQ_REDDIT_SUBS`).

## Cada juego, dentro

- **Promoción cruzada**: botón «Más juegos» en la portada con los otros juegos del mismo creador
  (los de Google Play o, si no, los del escaparate para jugar en la web). Cada toque se mide.
- **Avisos de vuelta propios de cada género**: tiradas llenas (tragaperras), energía llena (pedidos),
  gerentes con la caja llena (tycoon), obra terminada o ejército listo (reino); además de los de
  siempre (premio diario, misiones, eventos, «te echamos de menos»).
- **Anuncios con premio donde más rinden** en cada género nuevo: x2 de lo ganado sin conexión,
  +15 tiradas, +25 de energía, terminar la obra ya.
