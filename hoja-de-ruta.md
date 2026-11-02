# Hoja de ruta de Orquestador

Se construye módulo a módulo, cada uno probado. Al final: prueba completa con las APIs
oficiales (todo en la nube: GitHub, RunPod y Supabase; en el PC no corre nada) para "ver la magia".

Estado: ✅ hecho y probado · 🔧 en curso · ⬜ pendiente

## Base
- ✅ App móvil (Capacitor) con identidad "taller de inventor" y Chispa (prototipo web)
- ✅ Backend Supabase: cuentas, tuercas, trabajos con coste real, límites, presupuesto, anuncios verificados por Google
- ✅ Decisiones: motor Godot, generadores, agente programador, memoria, aprendizaje continuo

## Kit de Godot (OrqKit)
- ✅ Núcleo: config, juice, guardado, audio, anuncios con reglas, registro QA
- ✅ Plataformas con feeling comercial + analizador de niveles + bots (APK probado)
- ✅ Arte de la fábrica integrado (sprites animados, tiles, sonidos)
- ✅ Interfaz profesional: 4 perfiles (pixel, cartoon, low-poly, realista), título, niveles con estrellas, pausa, ajustes, resultado, HUD, auditoría automática (APK 0.3)
- ✅ Enemigos y combate: patrulla, pinchos y volador; pisotón con rebote y combos; corazones, retroceso e invulnerabilidad; el analizador y los bots los entienden (APK 0.4)
- ✅ Contenido de juego completo: jefe final con barra de vida y meta cerrada, 5 poderes (corazón, doble salto, imán, velocidad, estrella), disparo con botón de fuego, puntos de control, plataformas móviles, música en bucle por pantalla; los bots lo juegan todo (110 pruebas, APK 0.5)
- ✅ Progresión: estrellas, recompensa diaria, tienda de aspectos y mejoras (corazón extra en plataformas y hordas)
- ✅ Mundos: el selector agrupa los niveles de 5 en 5 con cabecera, estrellas, color propio y candado hasta alcanzarlos
- ✅ Segundo género: **runner** (corre solo, cada vez más rápido, toque para saltar, barra de recorrido); la directora elige el género según la idea y el taller cambia de uno a otro
- ✅ Tercer género: **volador** (arcade de un toque: tocas para volar entre columnas); bot que planifica los toques con la física real
- ✅ Cuarto género: **hordas** (vista desde arriba, armas automáticas, gemas, subir de nivel eligiendo mejoras, cercos y jefe que embiste)
- ✅ Quinto género: **puzle de combinar 3** (rayos, bombas de color, ondas, cascadas, hielo, movimientos limitados y 3 estrellas; objetivo calibrado con el bot)
- ✅ Sexto género: **tower defense** (3 torres con mejoras y venta, oleadas con los enemigos del juego, jefe, oro y vidas)
- ✅ Séptimo género: **carreras** (vista desde arriba, curvas, 3 rivales, tráfico, monedas, turbo y podio)
- ✅ Más géneros: estrategia por turnos (tipo Advance Wars), batalla automática (Auto Chess), gemas y héroes (Puzzle & Dragons), cartas coleccionables (Hearthstone) roguelike por turnos (Pixel Dungeon) bombas (Bomberman) artillería (Worms) comecocos (Pac-Man) cadena de bolas (Zuma), lucha (Street Fighter) fusión de frutas (juego de la sandía), pinball, metroidvania y sigilo por turnos (Hitman GO), con IA rival y bots que juegan cada nivel
- ✅ Metroidvania: mundo de salas conectadas con habilidades que abren zonas (doble salto, impulso, martillo, llaves) y minimapa. El bot planifica en anchura sobre el estado del héroe (casilla, subida, saltos e impulso) y vuelve atrás a por cada habilidad
- ✅ Primer juego en 3D: carreras 3D low-poly (carretera con curvas, coches con faros, ciudad de neón de noche o bosque de día según la paleta, cámara de persecución). Misma lógica, analizador y bot que las carreras 2D; «hazlo en 3D/2D» en el taller
- ✅ Corredor 3D (tres carriles, trenes, vallas y barras; ciudad de neón o bosque)
- ✅ Naves (matamarcianos vertical con jefe), rompebloques, bloques (encajar piezas), serpiente y memoria (parejas): 13 géneros, todos con analizador, bot y calibración
- ✅ Editor manual de niveles en la app (plataformas, runner, volador, rompebloques y cajas): pintar, deshacer, alargar, zoom; 2 tuercas por nivel; los bots lo prueban y, si no vale, explica por qué y devuelve
- ✅ Géneros 16, 17 y 18: **apilar** (torre de bloques de un toque con perfectos y cortes), **topos** (tus enemigos asoman por agujeros; el héroe también, y no hay que tocarlo) y **saltos** (sube rebotando: plataformas móviles, que se rompen, muelles y enemigos que se aplastan desde arriba; los lados se tocan)
- ✅ Géneros 14 y 15: **cajas** (sokoban generado al revés, siempre resoluble, con deshacer y estrellas por empujes) y **preguntas** (trivial: la IA escribe las preguntas sobre el tema, con explicación; contra el reloj; el taller las cambia)
- ✅ Historia entre niveles: la directora escribe una mini aventura (intro de cada nivel y gran final) con héroe, rival, jefe y narrador; frases con voz (Chatterbox, tono de cada personaje), retrato con su sprite y texto que se escribe solo. Una vez por nivel, apagable en Ajustes, en todos los géneros. Taller: «ponle una historia» / «quita los diálogos» (4 tuercas)
- ✅ Clasificación online por nivel (apodo opcional y filtrado, mejor marca por dispositivo, límites en el servidor) y retos entre amigos: «Retar» comparte un enlace; en la web el juego abre el nivel retado y dice si lo has superado. El autor ve la clasificación en la app y oculta apodos feos
- ✅ Plataformas, runner y volador en 3D (2.5D): cubos con la textura del juego, pinchos, plataformas móviles y fondo con colinas y árboles de día o ciudad con ventanas de noche; el jugador, los enemigos, monedas y textos se reflejan desde el 2D, así que el bot y el analizador son los mismos. La directora lo elige si la idea pide 3D o low poly; «ponlo en 3D / vuelve a 2D» en el taller (3 tuercas, mismos niveles)
- ✅ Género 19: **arena** (todos contra todos al estilo Brawl Stars: joystick, botón de fuego con apuntado automático y 3 cargas, súper, arbustos para esconderse, cajas con cubos de poder, curación al estar tranquilo y gas que cierra la arena; rivales con IA que abren cajas, pelean entre ellos y nunca se juntan más de dos contra el mismo; generador de arenas simétricas, analizador y bot calibrados)
- ✅ Género 20: **aldea** (asalto a bases al estilo Clash of Clans en vista isométrica: eliges guerreros, arqueras o gigantes y los sueltas fuera de la base; van solos al edificio más cercano y rompen los muros que les cortan el paso; cañones, torres arqueras con un guardián del juego y morteros con daño en área; 1 a 3 estrellas por 50 %, ayuntamiento y 100 %; el botín va al monedero). Bases generadas con muralla, analizador, bot y calibración (17 de 18 a la primera, con 1, 2 y 3 estrellas). **Mi aldea**: entre asaltos construyes y mejoras tu propia aldea con el botín (ayuntamiento hasta nivel 3, cuarteles = más tropas, elixir = tropas más fuertes, oro = más botín, defensas y muralla), con insignias de nivel y celebración al construir
- ✅ **Online 1 · Liga de aldeas** (PvP por turnos, como Clash): tu aldea se sube a la liga con tu apodo; el servidor te busca un rival con trofeos parecidos, asaltas su aldea con el ejército de tu ayuntamiento y ganas o pierdes trofeos (también el defensor). Ranking del juego, «te han atacado», límite de asaltos por hora, cada asalto se cierra una sola vez y en 15 minutos; el autor ve la liga en la app y oculta apodos feos
- ✅ **Online 2 · Torneo semanal** en todos los juegos: cada semana un nivel destacado (el mismo para todos, sale del juego y la semana) con su propia clasificación que se reinicia el lunes; botón en el título, la marca se sube sola al acabar ese nivel y el podio de la semana pasada cobra premio en monedas (300/200/100, una vez)
- ✅ **Online 3 · Arena en directo** (multijugador en tiempo real): «Arena online» en el título de los juegos de arena; el servidor junta hasta 4 jugadores en una sala (12 s de espera, cuenta atrás de 3 s, mismo nivel para todos) y lo que falte lo rellenan bots que mueve el anfitrión. La partida va por el canal en directo de Supabase (WebSocket): cada móvil manda en su luchador 12 veces por segundo, los disparos se ven en todos y **la vida la decide quien recibe el golpe** (nadie puede quitar vida de mentira a otro); quien se desconecta 6 s cae. Puesto final → trofeos de arena (+12/+5/−2/−6) y ranking. Probado con dos jugadores en el mismo programa con latencia
- ✅ **Online 4 · Clanes** en la liga de aldeas: creas un clan con nombre limpio y un código de 6 letras para invitar (se comparte por WhatsApp), hasta 20 miembros que suman sus trofeos, ranking de clanes y tu puesto; un clan vacío desaparece
- ✅ **Online 5 · Amigos** en todos los juegos: cada jugador tiene un código por juego (se comparte), añades amigos con su código y la clasificación de cada nivel tiene pestaña «Amigos» (tú y los tuyos)
- ✅ **Online 6 · Salas privadas de arena**: «Sala con amigos» crea una sala con código de 6 letras (se comparte), tus amigos entran con el código y quien la creó pulsa «Empezar»; los huecos los rellenan bots. Las partidas públicas nunca caen en una sala privada
- ✅ **Online 7 · Fantasmas** en plataformas, runner y volador: al jugar un nivel corre a tu lado la sombra (con su apodo) del jugador que va justo por delante en la clasificación, con su recorrido real; al batir tu marca se sube el tuyo (como mucho 3000 puntos, cada 0,1 s). Se apaga en Ajustes
- ✅ **Online 8 · Guerra de clanes semanal**: cada estrella que ganas asaltando aldeas suma para tu clan esa semana (se apunta al cerrar el asalto: cambiarte de clan no se lleva las estrellas). Clasificación de clanes y tus estrellas en la liga; los que aportaron a uno de los 3 primeros cobran 250/150/80 monedas el lunes, una vez
- ✅ **Online 9 · Eventos en directo** (live ops del autor): desde la app (Jugadores → Eventos en directo) programas **monedas dobles** o un **regalo de monedas** para todos, con título, día de inicio y duración (1 h a 14 días, sin solaparse, hasta 5 pendientes). El juego lo ve al abrirse —franja en el título, botón «Recoger» y premio x2 al acabar cada nivel— **sin publicar otra versión**. El autor ve cuántos lo han recogido y puede terminarlo antes
- ✅ **Online 10 · Pasar a otro móvil** (guardado en la nube sin cuentas): Ajustes → «Pasar a otro móvil» sube la partida entera y da un código de 8 letras y un PIN de 6 cifras; en el móvil nuevo se escriben y vuelve todo (monedas, niveles, aldea, apodo, amigos). PIN nuevo cada vez, 5 fallos por hora y código, y se borra a los 180 días sin uso
- ✅ **Misiones diarias y semanales** (3 + 3, elegidas por fecha y por género: partidas, niveles, estrellas, perfectos, monedas, enemigos), se cuentan solas jugando y se cobran con un toque (monedas + XP)
- ✅ **Pase de temporada** mensual: 20 niveles de 500 XP con premio gratis y premium; el premium da más monedas y dos aspectos exclusivos (Estelar y Aurora). Botón «Misiones» en el título con el número de premios por cobrar
- ✅ **Compras dentro del juego** (Google Play Billing, plugin oficial compilado en la fábrica): 500 y 3000 monedas, pase premium y sin anuncios. Cada compra la comprueba el servidor con Google (`juego-compra`) antes de darla, y se consume o reconoce allí; «sin anuncios» quita los intersticiales para siempre (se recupera al reinstalar). La fábrica crea los 4 productos en Play Console al publicar
- ✅ **Avisos en el móvil** (notificaciones locales): premio diario, misiones de hoy sin terminar, regalo o final de un evento y «vuelve» a los 3 días; el permiso se pide tras el primer nivel y se apagan en Ajustes. **Buzón «Mientras no estabas»** al abrir: ataques a tu aldea, premio del torneo o de la guerra de clanes, regalo del evento y misiones por cobrar
- ✅ **Panel de ingresos y jugadores** en la app: jugadores por día, cuántos vuelven al día siguiente y a los 7 días, ventas por día y por producto y lo que le queda al autor (85 %)
- ✅ **Online 11 · Repeticiones de asaltos**: el asalto de liga se graba (cuándo y dónde cae cada tropa) y el defensor lo ve otra vez en su móvil, simulado igual, desde «Te han atacado → Ver repetición»
- ✅ **Online 12 · Arena cooperativa**: en «Sala con amigos» se elige «cooperativo»: los jugadores juntos (sin fuego amigo) contra 3 oleadas de bots que mueve el anfitrión; si cae uno, mira a su equipo. No da ni quita trofeos
- ✅ **4 géneros nuevos (24 en total)**: **ritmo** (notas en 4 carriles, perfecto/bien/fallo, energía y combo), **clicker** (toca, contrata ayudantes, monedas de oro, meta a tiempo), **cartas** (solitario Golf con reparto siempre resoluble) y **RPG por turnos** (atacar, especial, poción, defender; jefe que avisa del golpe doble). Cada uno con su analizador, su bot y su generador validados en la cadena completa
- ✅ Mejoras en la tienda por género: tropas más fuertes (aldea) y luchador más fuerte (arena)
- ✅ **Charla en directo con los personajes** (lo único en que Rosebud aún iba por delante): desde la pausa hablas con el héroe, el rival o el jefe; responde la IA con su personalidad, filtrada a la entrada y a la salida, apta para todas las edades y sin guardar datos de nadie. La paga el autor por paquetes (40 tuercas = 500 mensajes) desde la app; sin cupo o sin red, contestan con sus frases de la historia
- ✅ **Juegos en 6 idiomas** (español, inglés, portugués, francés, alemán e italiano): la interfaz sale de un catálogo traducido a mano y lo propio de cada juego (coleccionable, lema, niveles, historia y preguntas del trivial) lo traduce la IA una vez, comprobado y guardado; el juego coge el idioma del móvil y se cambia en Ajustes. La ficha de Google Play también sale en los 6 idiomas (textos y capturas con su mensaje) y se sube sola
- ✅ Acabado de estudio: fondo ilustrado por la IA detrás de cada nivel 2D, piezas con la textura del juego, **interfaz dibujada por la IA** (marcos de paneles y botones en el material del juego, con contraste comprobado: si una pieza no se lee, vuelve la de siempre), **título como logotipo** (degradado, contorno grueso, sombra, brillo que cruza y entrada letra a letra) y efectos nuevos (chispas aditivas, ondas expansivas, trozos que encogen, números de daño con rebote)
- ✅ AdMob real en los juegos (plugin poing-studios, consentimiento UMP, intersticial y con premio «x2 viendo un anuncio»)
- ✅ Mods: el kit carga código extra probado (API de eventos segura)

- ✅ **Géneros complejos (33 en total)**: **Imperio** (estrategia en tiempo real tipo Age of Empires / Guerras Tribales: aldeanos, 9 edificios, 3 edades, piedra-papel-tijera, arietes, mercado, campana y una IA rival con economía y oleadas; giro **niebla de guerra**), **Minas** (idle tipo Idle Miner: pozos, ascensor y almacén, gerentes, impulsos, minerales cada vez más valiosos y ganancias mientras no juegas) y **Mazmorras** (RPG de acción tipo Archero: salas con puertas, slimes, murciélagos, arqueros, golems y jefe con fases; habilidades al subir de nivel y cofres con equipo de 4 rarezas que se guarda). Cada uno con bot calibrado en 60 niveles (fácil, normal y difícil) y plantillas propias

- ✅ **Más géneros de Google Play (36 en total)**: **Granja cozy** (tipo Hay Day: cultivos, animales, máquinas en cadena y pedidos), **Mazo** (cartas de estrategia tipo Slay the Spire: intenciones del rival, venenos, fuerza, premios tras cada combate y dragón final) y **Aventura** (historia con decisiones tipo Choices: capítulos escritos por la IA, estadísticas y objetos que se arrastran, tres finales, traducida a 6 idiomas). Cada uno con bot y analizador que juegan la partida entera, y dos plantillas

## Fábrica
- ✅ Biblia del juego v1
- ✅ Cadena de arte 2D coherente (ComfyUI, postprocesado, QA, exportación a Godot)
- ✅ Efectos de sonido procedurales
- ✅ Interfaz en la Biblia (perfil, colores por rol con contraste garantizado, tipografía)
- ✅ Fondos de portada generados (vertical para el título, horizontal para el gráfico destacado)
- ✅ Arte de interfaz generado: marcos 9-slice de panel y botones (normal y principal) con el estilo de la Biblia, recortados, comprobados (sólidos, simétricos, centro tranquilo) y con el centro fundido al color de la interfaz para que el texto se lea siempre
- ⬜ Iconos de interfaz generados
- ✅ Música propia de cada juego (procedural: menú, nivel y victoria en bucle perfecto, según ambiente y tempo)
- ✅ Música con IA: ACE-Step 1.5 XL en la GPU de RunPod (menú, nivel en bucle sin salto y victoria, con control de calidad y respaldo procedural)
- ✅ Voces con IA en los vídeos: Chatterbox Multilingual en RunPod (español con emoción; respaldo Piper)
- ✅ Efectos de sonido con IA (Stable Audio 3 Medium, respaldo procedural por efecto)
- ✅ Voz del héroe dentro del juego (inicio, victoria, derrota) con tono según el personaje
- ⬜ 3D: TRELLIS.2 + UniRig + animaciones CC0
- ✅ Revisión visual con IA (Claude Haiku mira cada personaje: parecido con personajes protegidos o fallos → se regenera)
- ✅ Directora de juego: idea → diseño validado (Claude con salida estructurada, router Haiku → Sonnet, red de seguridad contra contenido protegido)
- ✅ Generador de niveles por bloques probados con curva de dificultad y reglas de justicia
- ✅ Cadena completa: idea → proyecto Godot → niveles validados → arte → icono → bots → APK → capturas → informe de costes
- ✅ Trabajador conectado a Supabase: cola, progreso en vivo, subida de APK/capturas/proyecto, cobro real o devolución
- ✅ Taller: poner/quitar jefe, poderes, disparo, música (ambiente y tempo), puntos de control y plataformas móviles; misma validación y precios en fábrica y servidor
- ✅ Aprende de los jugadores: datos anónimos de partida, informe por nivel en la app y consejos que Chispa aplica con el taller
- ✅ La fábrica aprende de todos los juegos: calibración de dificultad por género, dificultad y tramo con datos de jugadores y de sus propias pruebas
- ✅ Agente de géneros: la IA escribe un género nuevo sobre la plantilla, se revisa por seguridad y se prueba con bots hasta que funciona (circuito probado; falta la primera prueba con Claude real)
- ✅ Agente programador: lo que el taller no sabe hacer, Claude lo programa como mod (lista negra, compilación, humo y bots; hasta 3 rondas; si falla se devuelven las tuercas). Botón «Que Chispa lo programe» en el taller
- ✅ Todo en la nube: fábrica en RunPod CPU y arte en RunPod GPU (Z-Image-Turbo, FLUX.2 klein 4B, Qwen-Image-Edit 2511), por segundos y a cero sin trabajo; se despierta al encolar; despliegue automático con GitHub Actions (probado con RunPod simulado y ComfyUI real; falta el primer despliegue real)

## App y publicación
- ✅ App real conectada al backend: código por correo, tuercas, fabricar, progreso en vivo de Chispa, mis juegos con capturas y descarga del APK (y modo demostración)
- ✅ «Jugar ya»: el juego se abre dentro de la app sin instalar nada (motor web común en caché + paquete de 1-2 MB por versión), probado en Chromium
- ✅ Taller por instrucciones: cambios por chat con Chispa sobre un juego ya fabricado (propuesta con coste, solo se rehace lo afectado, memoria del proyecto, versiones y volver atrás)
- ✅ Publicar en Google Play desde la app: .aab firmado (API 36) con llave de subida cifrada por usuario, iconos adaptativos, ficha validada contra las reglas de Google, política de privacidad pública, guía con respuestas de los formularios y subida por la API oficial (probado contra un servidor que imita a Google; falta la primera prueba real)
- ✅ Apple App Store: Mac de GitHub (macos-15) compila con firma automática y sube a TestFlight con la clave .p8 cifrada del usuario (falta la primera prueba real)
- ✅ Lanzadera: intercambio justo de probadores para la prueba cerrada (12 × 14 días): campañas con Grupo de Google, check-in diario con opinión privada, puntos que solo dan visibilidad, reciprocidad obligatoria (o premium), abandonos automáticos y aviso de «lista para producción»; sin reseñas a cambio de nada
- ✅ Ficha de Google Play automática por juego: icono 512, gráfico destacado 1024×500, capturas con mensaje en español e inglés y textos dentro de los límites (botón en «Mis juegos»)
- ✅ Progresión que hace volver: premio diario con racha, monedero y tienda de 7 aspectos del héroe en todos los géneros
- ✅ 28 géneros (nuevos: laberinto, minigolf, pesca y fusión)
- ✅ Géneros enchufables: registro único (fábrica, kit y servidor) y `nuevo_genero` crea un género jugable y validado en un minuto
- ✅ Clip vertical de 15 s por juego para TikTok, Shorts y Reels, jugado por el bot (gancho + cartel final), con visor y descarga en la app
- ✅ Estudio de marketing con IA: 3 vídeos por juego (reto, curiosidad, humor) con mejores momentos, guion, subtítulos, voz en off (Piper/ElevenLabs), música con ducking y textos por red; compartir desde la app
- ✅ Tráiler horizontal 1920×1080 y subida directa a YouTube (OAuth, marcado como contenido sintético)
- ✅ Monetización de la app: anuncio con premio verificado en servidor, packs de tuercas y premium con Google Play Billing verificado en servidor y reembolsos revisados

## Prueba final ("la magia")
- ✅ La propia app lista para la tienda: icono y splash, ficha es/en, 7 capturas automáticas, web pública (privacidad, términos, borrar cuenta) en GitHub Pages, borrar cuenta en la app, denunciar contenido (IA y Lanzadera), cuenta para el revisor de Google
- ✅ Compartir con un enlace: cualquiera juega en el navegador sin instalar nada (web/jugar.html), con «Hecho con Orquestador» y botón para crear el tuyo
- ✅ Escaparate de la comunidad (lo mejor / lo nuevo), me gusta, remix a «Mis juegos» con crédito al original y denuncias que ocultan solo
- ✅ Boceto jugable a los ~20 s de empezar: se juega mientras se dibuja el arte de verdad
- ✅ Plantillas de éxito: 18 juegos probados (uno por género que más funciona) que el usuario personaliza cambiando el tema; la plantilla fija lo que lo hace funcionar y las 18 se fabrican y superan los bots
- ✅ «Qué hacer ahora»: asesor de lanzamiento con las 3 acciones que más ayudan a cada juego (publicar, primeros jugadores, arreglar el nivel que atasca, avisos, misiones, tienda, eventos, online...), cada una con su botón; nunca propone compras ni online a un juego para niños
- ✅ Reseñas de Google Play en la app: la IA propone la respuesta en el idioma del jugador y el autor la revisa y la envía (nunca premios a cambio de notas)
- ✅ Pruebas A/B de un nivel: la mitad de los jugadores juega una versión B (más fácil, más difícil o distinta), validada por los bots como un nivel más; la app dice cuál superan más (prueba estadística) y con un toque se queda la ganadora
- ✅ Tu dibujo (o tu mascota o un juguete) como protagonista: la IA lo revisa y la fábrica lo convierte en el héroe con el estilo del juego y todas sus animaciones
- ✅ Invita a un amigo (30 tuercas cada uno cuando fabrica su primer juego) y «Top de la semana» del Escaparate
- ✅ Editor de niveles a mano también para laberinto y minigolf
- ✅ Directora entrenada: 60 ideas de prueba (100 % de géneros acertados sin IA), ejemplos en su guía y lote de calibración de los 28 géneros
- ✅ Giros encima de cualquier género (a oscuras, mundo espejo, contrarreloj, racha) y mezclas de géneros (laberinto serpiente, golf de monstruos), todo probado por los bots
- ✅ Ganchos originales: la IA propone 3 juegos distintos (género + giros) para tu idea; el código valida cada propuesta y solo ofrece lo que la fábrica sabe hacer
- ✅ La fábrica aprende de sus errores: si un giro rompe un juego se quita y se entrega sin él; cada fallo queda como lección para la directora y lo que falla mucho en un género deja de ofrecerse allí
- ✅ Reto del día con giro sorpresa (premio una vez al día)
- ✅ Giros propios de los géneros nuevos: viento (minigolf), tormenta (pesca) y piedras (fusión), con la física compartida por juego, bot y fábrica
- ✅ Hielo en el puzle de cajas (las cajas resbalan hasta chocar; generador al revés y solucionador con hielo, el mismo en juego, bot y fábrica)
- ✅ Fantasma: corres contra tu mejor partida del nivel (plataformas, runner, volador y horda)
- ✅ Túneles en la serpiente (sales por un borde y entras por el contrario) y cartas inquietas en memoria (cada 2 fallos dos cartas tapadas se cambian de sitio a la vista; el bot las sigue igual que una persona)
- ✅ Saltar nivel tras 3 derrotas (con anuncio con premio; gratis tras 5): menos abandonos
- ⬜ Experimentos de ficha de Google Play (dos iconos o capturas a la vez): Google no los ofrece por la API, solo a mano en Play Console
- ✅ La app también en el navegador del PC (web/app), además de Android
- ✅ Pulido visual de la app: tipografías de la marca incluidas (sin depender de internet), ficha de cada juego en pestañas (Taller, Publicar, Compartir, Jugadores), ideas de ejemplo deslizables, descargas compactas
- ⬜ Claves oficiales: Anthropic, RunPod, Supabase, AdMob, Google Play
- ✅ Bichos de oro en topos (valen 3 golpes); «Mis juegos» con la captura de cada juego, su tipo y sus giros; taller de cada juego con secciones plegables
- ✅ 53 plantillas de éxito (ahora 54) (todos los géneros, 13 «únicas» con giros y mezclas, 5 para niños), con filtro por tipo en la app; todas fabricadas y superadas por los bots
- ✅ «Juega antes de crear»: la primera vez, el mejor juego de la comunidad para jugar en un toque antes de escribir la idea
- ✅ Notas invisibles en ritmo (se toca de memoria) y su plantilla «Ritmo a ciegas»: 54 plantillas
- ✅ Perfil de creador en Cuenta: nivel (de Aprendiz a Leyenda) por lo que haces y lo que consigue tu trabajo, y 9 insignias
- ✅ Género 30: burbujas (bubble shooter con rebotes, racimos que caen, trayectoria al apuntar y marcas por color para daltonismo); el analizador juega cada nivel con el bot y su plantilla «Lanza burbujas»
- ✅ Género 29: tubos (ordenar colores, el «water sort»), con solucionador del mínimo de movimientos, bot, generador con par y plantilla «Ordena las pociones»
- ✅ Reto de la semana: un tema para todos, clasificación en directo y tuercas para los 3 primeros (lo paga el reloj, una sola vez)
- ✅ Compartir: código QR del enlace y plan de 7 días para redes (qué grabar y texto listo para pegar cada día)
- ✅ Accesibilidad en todos los juegos: colores para daltonismo y modo calma (sin sacudidas), en Ajustes
- ✅ Logros en todos los juegos: 12 retos a largo plazo con aviso y premio en monedas (pestaña «Logros» de Misiones)
- ✅ `conectar.py`: conecta todo con tus cuentas de una vez (comprueba las claves, crea la llave de subida y los secretos, repositorio privado, web pública, correo con código, despliegue y .aab firmado) y deja los pasos de Play Console con tus datos
- ⬜ De una idea escrita en el móvil a un juego publicado en prueba cerrada
