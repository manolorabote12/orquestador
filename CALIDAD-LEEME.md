# Calidad de los juegos: cómo se mira y qué se ha aprendido

Los bots dicen si un juego **se puede jugar**. No dicen si **se ve bien**. Hasta el 11 de noviembre de
2026 nadie había mirado un juego real salido de la fábrica; al mirarlos salieron fallos graves que
ningún control automático veía. Este documento recoge cómo se revisa ahora y cada lección.

## Cómo se revisa un juego real

1. **Crítica visual automática** (`fabrica/arte/critica.py`). Al terminar, la IA mira las capturas
   reales (título y partida), pone **nota de 1 a 10** y lista los problemas por tipo
   (`personaje_con_fondo`, `personaje_pequeno`, `interfaz_rota`, `suelo_recargado`, `nivel_vacio`...).
   Queda en `informe.json` (`critica_visual`) y en el progreso del trabajo (paso `critica`).
   No frena la entrega. Cuesta menos de un céntimo.
2. **Juegos de muestra** (workflow «Escaparate: juegos de muestra»). Fabrica ideas variadas de una en
   una con la cuenta «Equipo Orquestador». Solo se publican los que sacan **6 o más** en la crítica.
3. **Mirarlos a mano** cuando haga falta: acción `capturas` del mismo workflow. Deja en la rama
   `revision` el icono, el informe y el proyecto de Godot de cada juego, y el diseño de los fallidos
   en `_fallidos/` para reproducir el fallo fuera del servidor.
4. **Estado** (acción `estado`): pasos del juego en marcha, avisos y nota del último terminado, y el
   error completo de los fallidos (con archivo y línea si es un fallo de programa).

## Lecciones (qué pasó, por qué y qué se cambió)

| Qué se veía | Causa | Arreglo |
|---|---|---|
| Personajes, jefe y moneda dentro de un cuadro con luna y tejados | Cada dibujo se pedía con la descripción de la **escena** delante | Los sprites llevan solo el **estilo de dibujo** (`prompts.estilo_dibujo`) + «isolated sprite»; control gratis de fondo libre (<30 % → otra semilla); la revisión con IA rechaza escenarios |
| Botones y paneles con un rectángulo granate | La IA no pintó el fondo del color pedido y el recorte por color no quitó nada | `post.quitar_fondo_borde`: quita el fondo por el color del borde; si no se puede, la pieza se repite |
| Personajes borrosos y pixelados sin ser pixel art | Arte no pixelado a 64 px sin suavizado | Celdas de 128 y reducción con suavizado (`sprite_kit.gd`) |
| Héroe diminuto en plataformas | Cámara a tamaño real | Cámara ×1,25 (volador y corredor no) |
| Suelo como una losa plana y ruidosa | Textura muy detallada repetida igual en todas las casillas | Suelos con poco detalle; relleno más oscuro, remate y sombra donde se pisa |
| Torres de defensa como triángulo, círculo y rombo | El arte solo dibujaba héroe, enemigos, moneda y suelo | Las tres torres se dibujan con el tema del juego (`torre_rayo`, `torre_canon`, `torre_hielo`) |
| Juegos de 3-4 niveles que se acaban en dos minutos | La directora pedía «entre 3 y 6» | «Entre 6 y 8» |
| Oscuridad que tapaba casi toda la pantalla | Círculo de luz pequeño y negro al 96 % | Luz más grande y exterior al 86 % |
| Juegos sin capturas, sin ficha y sin clip | Al servidor le faltaban librerías de X11/Mesa | Añadidas al `Dockerfile` de la fábrica; reintento con pantalla virtual y motivo en el aviso |
| Juego terminado que falla al final por un texto 8 px más ancho | La validación trataba un texto cortado como fallo total | La letra se ajusta sola; si lo único mal es un texto cortado, se entrega con aviso |
| «can only concatenate list (not "str") to list» | Una traducción de la IA con un texto donde iba una lista | La traducción mal formada se descarta; ese idioma usa la interfaz base |
| El guardián paró la fábrica al encargar 10 juegos | Sumaba el coste **estimado** de toda la cola | Los juegos de muestra van de uno en uno |
| Juego perdido a los 30 minutos | El arte de verdad tarda 22-28 min | Tiempo máximo por juego: 45 min |
| Nadie podía compartir juegos con arte de verdad | El Escaparate admitía 20 MB por juego | 50 MB |
| Un reintento volvía a pagar el arte | El reintento pedía un diseño nuevo | Reusa el diseño del intento que ya tenía el arte (sale de la caché) |
| Una nave que esquiva asteroides salió como juego de plataformas | El diseño lo hacía el modelo barato y las pistas de género tomaban la primera coincidencia | El diseño lo hace el modelo superior; gana el género con más palabras clave acertadas |
| «'str' object has no attribute 'get'» en el diseño | El modelo superior escribió frases de la historia como texto | Lo mal formado se descarta; cualquier forma rara vuelve a la IA como error para corregirla |
| Héroe y enemigos se ven pequeños (crítica 5/10 repetida) | El dibujo medía lo mismo que la caja de choque | El dibujo va un 35-40 % más grande que la caja de choque |
| Jefe dentro de un cuadrado azul | La IA pintó el fondo de otro color | Si el recorte por color casi no quita nada, se recorta por el color del borde |
| Defensa de torres sosa: enemigos diminutos y disparos que no se notan | El kit de torres no tenía efectos de impacto | Enemigos más grandes, rayo con brillo, destello blanco al golpear, estallido y «+oro» flotante al matar, temblor con el jefe |
| La lluvia de tuercas seguía al cambiar de pantalla | Se añadía al documento y nadie la quitaba | Al cambiar de vista se borra |
| Naves: héroe de 25 px y fondo vacío (crítica 5/10) | Nave dibujada a 96 px y cielo con solo estrellas | Nave a 132 px, enemigos un 25 % más grandes, nebulosas suaves y un planeta lejano; chispas en cada impacto, «+puntos» flotantes, explosión grande del jefe, la nave se ladea al moverse |

## Reglas para no repetirlo

- Un cambio en el arte o en un kit **no está hecho** hasta ver un juego real fabricado con él.
- Después de un despliegue, esperar unos minutos antes de encargar: un trabajador que ya estaba
  encendido puede seguir con la versión anterior.
- Lo que la crítica visual repite en varios juegos es lo siguiente que hay que arreglar.
- Cada género nuevo que se toque necesita su juego de muestra visto antes de darlo por bueno.
