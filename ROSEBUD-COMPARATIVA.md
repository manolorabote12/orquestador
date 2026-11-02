# Orquestador frente a Rosebud AI (octubre 2026)

Rosebud genera juegos de navegador en JavaScript/Three.js a partir de un chat («vibe coding»).
Esta tabla resume dónde estamos y qué queda.

| | Rosebud AI | Orquestador |
|---|---|---|
| Primer juego jugable | segundos/minutos | **boceto jugable ~20 s**, juego completo con arte propio en minutos |
| Calidad | lo que salga del código generado | **bots juegan cada nivel antes de entregarlo**; analizador de niveles; revisión visual con IA |
| Acabado visual | el de la plantilla de código | **interfaz dibujada por la IA en el material de cada juego** (marcos de paneles y botones, con contraste comprobado), fondo ilustrado detrás de cada nivel, **título como logotipo** animado y efectos de estudio (chispas, ondas, números de daño) |
| Arte y sonido | texturas y sprites básicos | personajes y fondos (FLUX.2/Z-Image), música (ACE-Step), efectos (Stable Audio), voz del héroe (Chatterbox) |
| Géneros | cualquiera (con fallos a partir de ~2.500 líneas) | **28 géneros** probados con bots (plataformas, runner, volador, hordas, puzle, torres, carreras, naves, rompebloques, bloques, corredor 3D, serpiente, memoria, cajas, preguntas con contenido de la IA, apilar, topos, saltos, arena todos contra todos, aldea de asaltos estilo Clash, ritmo, clicker, cartas, RPG por turnos, laberinto, minigolf, pesca y fusión) + agente de géneros + **agente programador** |
| Empezar sin ideas | plantillas de código | **18 plantillas de éxito** (los juegos que más funcionan en móvil): cambias el tema y la fábrica mantiene lo que las hace funcionar |
| Tu propio personaje | subir imágenes como textura | **tu dibujo, tu mascota o un juguete como protagonista**: la IA lo revisa (nada de fotos de personas ni personajes de marcas) y lo redibuja con el estilo del juego y todas sus animaciones |
| Originalidad | lo que escribas en el chat | **giros y mezclas de géneros** probados por bots (a oscuras, espejo, contrarreloj, laberinto serpiente, golf de monstruos...) y **3 ganchos originales** propuestos por la IA para cada idea; la fábrica **aprende de cada fallo** y nunca entrega un juego roto |
| Después de publicar | nada | **asesor «Qué hacer ahora»**, **pruebas A/B de niveles** con jugadores reales, **respuestas a reseñas de Google Play** (la IA propone, tú envías) e invitaciones con premio |
| 3D | básico (Three.js) | **carreras 3D, corredor 3D y plataformas/runner/volador en 2.5D** (bloques de verdad, ciudad de neón o colinas, cámara con perspectiva); «ponlo en 3D» en el taller sin rehacer niveles |
| Personajes que hablan | NPC con chat de IA (a veces se salen del guion) | **charla en directo** con el héroe, el rival y el jefe (personalidad del diseño guardado en el servidor, filtros a la entrada y a la salida, apta para todas las edades, sin datos personales, límite por dispositivo y frases de respaldo sin red) **+ historia entre niveles con voz** escrita por la IA y editable en el taller |
| Idiomas | inglés | **6 idiomas por juego** (es, en, pt, fr, de, it): interfaz traducida a mano y lo propio del juego traducido por la IA una sola vez; coge el idioma del móvil. **Ficha de Google Play en los 6 idiomas** |
| Compartir | enlace web | **enlace web** + escaparate + remix |
| Comunidad | galería y remix | escaparate, me gusta, remix con crédito, **Lanzadera** de probadores, **clasificación online por nivel y retos entre amigos** (enlace «supera mis N puntos») |
| Móvil nativo | no | **APK y .aab firmados para Google Play** e iPhone (TestFlight) |
| Publicar en tiendas | no | ficha, capturas, cuestionarios, subida por la API, guía paso a paso |
| Ganar dinero | difícil (solo web) | **AdMob** en el juego (consentimiento incluido), vídeos y tráiler para redes, YouTube |
| Propiedad | página alojada; código en el plan Pro | **proyecto Godot descargable** siempre |
| Edición a mano | editor de código | **editor de niveles en la app**: dibujas casilla a casilla (bloques, monedas, pinchos, enemigos, salida, meta, cajas...) y los bots lo prueban antes de guardar; si no se puede jugar, te dice por qué y no cobra |
| Cambios | chat sobre el código | taller con presupuesto antes de cobrar, versiones y volver atrás gratis |
| Desde dónde | navegador | Android **y** navegador del PC |

## Lo que aún nos falta para ganar en todo
Nada de lo que ofrece Rosebud queda por delante. Multijugador: **arena en directo** (hasta 4 jugadores, bots de relleno), **liga de aldeas** por turnos y **torneo semanal** en todos los juegos **clanes** y **amigos** con código. Y **salas privadas de arena** con código para jugar con tus amigos, y **fantasmas**: en los juegos de plataformas corres contra la sombra del que va justo por delante. Y **guerra de clanes semanal** con premios. Y **eventos en directo** que el autor programa desde el móvil (monedas dobles, regalos) sin publicar versión nueva. Y además, lo que convierte un juego en un negocio y que Rosebud no tiene: **compras dentro del juego** verificadas en el servidor, **pase de temporada** con misiones, **avisos** en el móvil, **guardado en la nube**, **repeticiones** de asaltos, **arena cooperativa** y un **panel de ingresos y retención** para el autor. Y 28 géneros (ritmo, clicker, cartas, RPG por turnos, laberinto, minigolf, pesca y fusión incluidos), cada uno con niveles comprobados por bots. Lo único que no se puede automatizar: los **experimentos de ficha de Google Play** (probar dos iconos o capturas a la vez) no están en la API de Google; se hacen a mano en Play Console.

Fuentes: [Rosebud AI Review 2026 – The AI Picks](https://theaipicks.com/rosebud-ai-review-2026/),
[Is Rosebud AI worth it – Summer Engine](https://www.summerengine.com/blog/is-rosebud-ai-worth-it).
