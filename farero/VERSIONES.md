# El Farero de la Niebla

- v1 (15 nov): primer juego del Estudio libre (7 noches, 6 heroes). 6,12 $ de API.
- v2 (21 nov): combate arreglado (sprites a 512x640 por el orden expand_mode/size), bordes magenta, textos.
- v3 (21 nov, hecho con Claude en sesion, sin API): 5 mareas x 12 noches, 14 heroes con talentos,
  21 monstruos + 5 jefes con rasgos, 16 reliquias, faro por plantas (9 salas), modos Niebla eterna,
  Cacerias (10 rangos por jefe) y Reto del dia. Arte nuevo: 56 dibujos con RunPod (~0,10 $).
  Bot (60 noches, sin farmear): 77 noches jugadas, 17 derrotas (1 en la 18, 5 en el jefe de la 36,
  11 en el jefe final). Guardia final ~nv 22, 16 reliquias.
- v4 (21 nov): 17 sucesos del dia con decisiones y riesgo (efectos: recursos, faro, reliquia, nivel,
  luz/escudo/noche dura para la noche siguiente); animacion por cuerpo entero (respirar, flotar,
  impulso y estiramiento al atacar, retroceso al recibir, caida al morir, salto al lanzar habilidad);
  9 musicas con ACE-Step (menu, dia, una por marea, jefe, victoria; ~10 s de GPU cada una);
  dificultad en rampa dentro de cada marea y jefes suavizados. Bot: 60 noches en 62 intentos
  (perdio la 20 y la 36), sin muros.
- v5 (21 nov): anuncios con recompensa (botin x2, segunda oportunidad, hora extra), consejos la primera
  vez, ajustes (musica, efectos, vibracion, idioma, privacidad), titulo con haz giratorio y lluvia,
  icono, ingles completo (libre/en.json, Idioma), musica a q2 y texturas con perdida (WebP 0,85).
- v6 (21 nov): Arena de los Fareros (duelos asincronos de verdad con Supabase; sin conexion, 8 fareros
  rivales de la historia marcados como personajes), amigos por codigo (asaltar su faro), Taberna del
  Ahogado (6 heroes nuevos, insignias y estrellas +12%), definitivas (energia: a 100 la habilidad sale
  gratis y x2,2), tienda (packs de ambar, sin anuncios), portugues, equipos remotos validados.
  Dificultad: vida 1+0,22(n-1), ataque 1+0,125(n-1), jefes x1,22, regeneracion de jefe 3%.
  Bot: 60 noches en 64 intentos (perdio la 18 una vez y la 47 tres), modos reto y eterna superados.
- v7 (22 nov): chispazos de impacto al golpear y al recibir golpes (tamaño según el daño).
- v8 (22 nov): arranque más rápido (Alba llega en la noche 1, Koji 3, Tumo 5, Nerea 7; arena desde la 4; 4 de ámbar al empezar para la taberna). Bot 20 noches sin perder.
- v9 (22 nov): integración: sombra de contacto bajo cada héroe y monstruo, luz de cada marea sobre los sprites, selección como círculo de luz a los pies (no caja), bordes de todos los sprites oscurecidos y suavizados, retratos cortados fundidos por abajo con la niebla.
- v9.1 (23 nov): pantallas altas sin franjas (fondos al tamaño real). Diseño de la v2 en claude/FARERO-V2-DISENO.md.
- v10 (23 nov): El Farero v2. Historia con 10 escenas ilustradas y decisiones (Esperanza, Niebla y Deuda
  abren y cierran opciones), 3 finales y Libro de la Marea; 4 acciones por héroe (atacar, habilidad,
  técnica de su elemento a 2 luz y definitiva con la técnica gratis) con efectos pintados; los 20 héroes
  animados con Wan 2.2 (quietos y atacando); La Torre del Faro (50 pisos con reglas, jefe cada 10);
  portada con haz que gira de verdad, mar que se mueve, rompientes y sonido de olas; botones de madera
  y latón y láminas de pergamino; textos nuevos en inglés y portugués.
  Bot: 60 noches en 62 intentos (perdió la 46 dos veces), torre pisos 1 y 10 ganados.
- v7 (23 nov): los 25 monstruos y jefes respiran y atacan con animación propia (Wan 2.2 local en RunPod);
  arreglado el Leviatán, que salía dentro de un cuadro rosa. Hojas en paleta de 256 colores: 5 veces menos peso.
  Bot: noches 1-3 ganadas.
- v8 (23 nov): las 10 escenas y los 3 finales narrados con voz de farero viejo (Qwen3-TTS); muertes con juice
  (destello, el cuerpo se deshace en niebla que sube; los jefes caen a cámara lenta con tres estallidos).
  Bot: 60 noches en 61 intentos, reto, eterna y torre.
