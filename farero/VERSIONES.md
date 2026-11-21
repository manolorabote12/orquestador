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
