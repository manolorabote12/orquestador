# Fábrica de Orquestador 1.0

De una **idea escrita** a un **juego de Godot validado, con APK**:

```
idea → directora (Claude) → diseño validado → Biblia + niveles por bloques
     → analizador (Godot) → arte y sonido (ComfyUI) → icono → bots jugando cada nivel
     → música propia → APK + paquete web (jugar en la app) + capturas + informe de costes
```

## Cadena completa

```powershell
cd fabrica
pip install numpy pillow jsonschema
# Sin clave ni GPU (directora y arte simulados):
python -m cadena "un gato ninja rápido que salta por tejados de noche" --simulado --arte-simulado --apk --web --capturas --ficha --clip
# Con tus claves y tu ComfyUI:
$env:ANTHROPIC_API_KEY = "sk-ant-..."
python -m cadena "un gato ninja rápido que salta por tejados de noche" --apk --web --capturas --ficha --clip
```

`--web` exporta `build/web/index.pck` (1-2 MB): el juego listo para abrirse dentro de la app con
**Jugar ya**, sin instalar nada. Necesita las plantillas de exportación Web de Godot 4.6.3.

`--ficha` (con `--capturas`) prepara la **ficha de Google Play** en `fabrica/ficha/ficha.zip`:
icono 512×512 (PNG de 32 bits), gráfico destacado 1024×500 con el héroe, título y lema, capturas
1080×1920 enmarcadas con un mensaje (en español y en inglés) y los textos de la tienda
(`textos_es.txt`, `textos_en.txt`: título ≤30, descripción breve ≤80, completa ≤4000 caracteres),
listos para copiar y pegar en Play Console. También se puede rehacer sola: `python -m ficha <proyecto>`.

`--clip` graba un **clip vertical de 15 s** para TikTok, YouTube Shorts e Instagram Reels: el bot
juega (desde el nivel 2), arriba sale «¿Puedes superarlo?» y al final un cartel con el héroe, el
título y «¡Descárgalo gratis!». Se graba con el Movie Maker de Godot (`qa/clip.tscn`) y ffmpeg lo
deja en MP4 1080×1920, H.264 + AAC (`fabrica/clip/clip_vertical.mp4` + `portada.jpg`). En tower
defense y hordas se salta el principio hasta que hay acción (`generos.py` → `clip_saltar`).
Necesita **ffmpeg** en el PATH (`winget install ffmpeg`). Suelto: `python -m clip <proyecto>`.

### Estudio de marketing con IA (`--marketing`, o desde la app: «Crear 3 vídeos con IA»)

```powershell
python -m marketing.estudio <proyecto>              # guion con Claude (ANTHROPIC_API_KEY)
python -m marketing.estudio <proyecto> --simulado   # sin IA ni coste, para probar
```

1. El bot juega ~30 s (`qa/clip.tscn --raw`) y apunta cada momento: monedas, pisotones, golpes al
   jefe, victorias, oleadas, turbos...
2. Se eligen los 12,5 s con más acción (lo gordo pesa más si llega al final).
3. Claude (modelo barato, céntimos) escribe **3 guiones** —reto, curiosidad y humor— sobre lo que
   pasa en esos segundos: gancho, voz en off de 12 s, subtítulos con tiempos y llamada final. Y el
   **texto para publicar** en español e inglés: título, texto y hashtags. El código rechaza marcas
   de otros, promesas falsas («número 1», «millones»...), emojis y tiempos imposibles.
4. **Voz en off** (`ORQ_VOZ`, automático si no lo pones):
   - `elevenlabs`: `ELEVENLABS_API_KEY` y opcional `ELEVENLABS_VOZ` (id de la voz). La mejor calidad.
   - `piper`: gratis y local. `pip install piper-tts` y `ORQ_PIPER_VOZ=C:\voces\es_ES-davefx-medium.onnx`
     (descarga la voz de huggingface.co/rhasspy/piper-voices, con su `.onnx.json` al lado).
   - Sin ninguna: vídeos con subtítulos y música, sin voz.
5. **Montaje** con ffmpeg: partida en 1080×1920, gancho enorme arriba, subtítulos grandes con la
   fuente del juego, voz con la música del juego bajando cuando habla (ducking), volumen
   normalizado para redes (−14 LUFS) y cartel final con el héroe, el título y la llamada.

Sale en `fabrica/marketing/`: `reto.mp4`, `curiosidad.mp4`, `humor.mp4` (+ portadas),
`publicacion.json`, `redes_es.txt`, `redes_en.txt` y `marketing.zip`. El trabajador atiende los
encargos `game_marketing` de la app (20 tuercas, las cobra el servidor).

Requisitos en tu PC: Python 3.11+, Godot 4.6.3 con las **plantillas de exportación** y el
**SDK de Android** configurados en *Editor → Ajustes del editor → Exportar → Android* (Godot
firma el APK de prueba con su clave de depuración). Si `godot` no está en el PATH:
`$env:GODOT = "C:\ruta\Godot_v4.6.3-stable_win64_console.exe"`.

El juego queda en `proyectos/<nombre>/` (proyecto de Godot normal) con `fabrica/diseno.json`,
`fabrica/biblia.json`, `fabrica/informe.json` (tiempos, coste real de la IA, coste estimado del
arte, resultados de los bots) y `build/<nombre>.apk`. Cada paso imprime una línea `@@ {json}`
con el progreso: es lo que Chispa contará en la app.

| Pieza | Qué hace |
|---|---|
| `director/diseno.schema.json` | Lo único que decide la IA: **género (plataformas, runner, volador, hordas, puzle, torres o carreras)**, título, lema, estilo y paleta, héroe, enemigos (1-3 tipos), coleccionable, suelo, sensación de control, dificultad, nombres de niveles, sonido y música; y ahora también **jefe final** (nombre y aspecto), **poderes** (doble salto, imán, velocidad, estrella, corazón), **disparo** y **extras** (puntos de control, plataformas móviles) |
| `director/prompt_director.md` | Instrucciones de la directora (originalidad, nada protegido, descripciones visuales en inglés, textos en español) |
| `director/llm.py` | Llamada a Claude con **salida estructurada forzada**. Router: Haiku → corrección con los errores → Sonnet. Coste real de cada llamada |
| `director/director.py` | Valida el diseño (esquema + reglas: cielo oscuro, enemigos distintos, nombres protegidos...) y lo convierte en Biblia y `game.json` con física y parámetros **probados** |
| `director/simulado.py` | Directora de prueba por palabras clave (gato, espacio, bosque, robot; pixel/cartoon/low poly; fácil/difícil; rápido/pesado; huye/sin parar/runner → runner; vuela/pájaro/un toque → volador; hordas/oleadas/sobrevive/zombis → hordas; puzle/combina/gemas/joyas → puzle; defiende/castillo/torres → torres; carreras/coches/circuito → carreras) |
| `niveles/generador.py` (runner) | `generar_runner`: niveles largos con ritmo obstáculo → respiro (5-7 casillas, lo que recorre un salto a toda velocidad), monedas en fila y en arco, enemigos entre bordillos, sin muros de 3 ni plataformas móviles. 108 de 108 niveles superados por los bots a la primera (3 sensaciones × 3 dificultades × 3 lotes) |
| `niveles/generador.py` (volador) | `generar_volador`: tuberías de 2 de ancho con hueco de 5 (4 en difícil), separadas 6-9 columnas; el hueco sube o baja solo lo que se puede volar; monedas en los huecos, poderes (estrella, imán, corazón) y punto de control entre tuberías. 108 de 108 niveles y otros 159 difíciles superados por los bots sin morir |
| `niveles/generador.py` (hordas) | `generar_horda` + `parametros_horda`: arena cerrada que crece por nivel, rocas sueltas (≤ 12 %, nunca encierran un hueco), claro en la salida; cada nivel dura más (60 s, 80 s, 100 s...) y aprieta más; jefe en el último. 108 de 108 niveles superados por los bots |
| `niveles/generador.py` (torres) | `generar_torres` + `parametros_torres`: mapas de 9x13 con un camino en zigzag de 26 casillas o más, tramos separados por una fila libre (sitio para torres) y algunas rocas; oleadas, densidad, oro y vidas por dificultad. 107-108 de 108 niveles ganados por el bot |
| `niveles/generador.py` (carreras) | `generar_carreras` + `parametros_carreras`: pistas de 160-360 tramos con curvas, conos y coches lentos separados (siempre hay paso), filas de monedas y placas de turbo; velocidad de los rivales por dificultad. 108 de 108 pistas con el bot en el podio |
| `niveles/generador.py` (puzle) | `generar_puzle` + `parametros_puzle`: tableros de 7-8 x 9 con huecos solo en los bordes de columna, hielo desde el nivel 2, 5 o 6 colores y exigencia del objetivo según la dificultad. 108 de 108 tableros superados por el bot (casi todos a la primera) |
| `niveles/generador.py` | Niveles por **bloques probados** con curva de dificultad: llano, escalón, hueco, pinchos, plataforma, patrulla, pinchudo, volador, combo, **poder, punto de control, puente móvil y arena del jefe** (en el último nivel) |
| `arte/musica.py` | **Música propia de cada juego** (menú, nivel y victoria): armonía con progresiones probadas, melodía AABA, bajo y batería; bucle perfecto; sale del ambiente y el tempo de la Biblia. Gratis y al instante |
| `subir_motor.py` | Sube una vez el motor web de Godot (38 MB) al bucket público `motor`; cada juego solo sube su `index.pck` |
| `generos.py` | **Registro de géneros**: lo que admite cada uno (jefe, disparo, poderes, enemigos), textos, generador y frase de tienda. Directora, taller, servidor, cadena y ficha leen de aquí |
| `nuevo_genero.py` | Crea un género nuevo ya conectado (plantilla jugable + analizador + bot + generador) y lo deshace con `--quitar`. Guía: `GENEROS-LEEME.md` |
| `marketing/` | **Estudio de marketing con IA**: graba la partida, elige los 15 s con más acción, Claude escribe 3 guiones (reto, curiosidad, humor) y el texto para cada red, voz en off (Piper o ElevenLabs) y montaje de 3 MP4 verticales |
| `play/` | **Publicar en Google Play**: llave de subida cifrada (`firma.py`), .aab con API 36 (`aab.py`), API oficial (`api.py`), respuestas de formularios y política de privacidad (`cuestionarios.py`) y todo junto (`publicador.py`). Ver `PUBLICAR-LEEME.md` |
| `aprendizaje.py` | La fábrica aprende: calibra la dificultad de los juegos nuevos con datos de jugadores y de sus propias pruebas |
| `agente_genero.py` | Agente de IA que crea un género nuevo sobre la plantilla y lo prueba hasta que funciona |
| `iconos.py` | Icono de tienda a sangre (Play 512 / App Store 1024) e iconos adaptativos de Android |
| `recursos.py` | Comprueba imágenes y textos contra las reglas de Google Play y App Store antes de subir |
| `clip.py` | Clip vertical de 15 s para redes jugado por el bot (Movie Maker de Godot + ffmpeg) |
| `ficha.py` | Ficha de Google Play: icono, gráfico destacado, capturas con mensaje (ES/EN) y textos dentro de los límites de la tienda |
| `cadena.py` | Lo orquesta todo; lo que el analizador o los bots no superan se regenera solo |
| `trabajador.py` | Toma juegos de la cola de Supabase, los fabrica, cuenta el progreso, sube APK, capturas y ficha de la tienda y cobra el coste real (o devuelve si falla) |

**Por qué la IA no dibuja los niveles:** los modelos de lenguaje se equivocan con las
cuadrículas. La IA decide el contenido y el gusto; los niveles los montan bloques con reglas de
justicia (los enemigos que andan van entre bordillos, nunca hay un hueco tras una bajada, siempre
hay sitio para aterrizar tras un salto, los voladores no van sobre huecos...). Con 36 niveles al
azar, 35 salen bien a la primera y el que falla se rehace solo.

## Taller por instrucciones (cambiar un juego ya fabricado)

La idea crea la versión 1. A partir de ahí se trabaja con instrucciones, como en una
conversación, y cada una crea una versión nueva:

```powershell
python -m cambio proyectos/bigotes_veloces "haz al gato negro" --solo-plan     # qué haría y cuánto cuesta
python -m cambio proyectos/bigotes_veloces "haz al gato negro" --apk
python -m cambio proyectos/bigotes_veloces "añade un nivel de nieve después del 2" --apk
python -m cambio proyectos/bigotes_veloces --volver 2                          # volver a la v2 (gratis)
```

- **Chispa traduce la instrucción** a operaciones de una lista cerrada
  (`director/cambios.schema.json`): textos, ajustes (dificultad, sensación, vidas, velocidad de
  enemigos), redibujar un personaje u objeto, paleta, estilo, añadir/quitar enemigo,
  añadir/quitar/rehacer nivel, **poner o quitar el jefe final, poderes, disparo, música
  (ambiente y tempo) y extras** (puntos de control, plataformas móviles). Si pides algo que aún no
  sabe hacer (multijugador, tienda, diálogos), lo dice y hace lo demás. **Cambiar de género**
  ("conviértelo en runner", "que vuele de un toque", "pásalo a plataformas") rehace todos los
  niveles (13 tuercas); runner y volador nunca llevan jefe ni plataformas móviles, y el volador
  tampoco disparo ni enemigos: Chispa lo explica si se los pides y no cobra. "Conviértelo en
  hordas" también vale; en hordas no se piden disparo, poderes ni extras (las armas disparan
  solas y las mejoras se eligen al subir de nivel). "Conviértelo en puzle" también: sin jefe,
  disparo, poderes ni enemigos. "Conviértelo en tower defense" (sin disparo, poderes ni extras:
  disparan las torres) y "hazlo de carreras" (sin jefe, disparo, poderes ni extras; siempre 3
  rivales). Si ya está así, no cobra.
  Si no entiende, pregunta.
- **Solo se rehace lo afectado**: cambiar el título no redibuja nada; "el gato negro" redibuja
  solo al gato (conservando bufanda, ojos...); un nivel nuevo genera solo ese nivel.
- **El coste lo calcula el código**, nunca la IA (`director/precios_cambios.json`, el mismo
  archivo que usa el servidor). Ejemplos: título 4 tuercas, dificultad 6, redibujar 15,
  nivel nuevo 9, todo el estilo 48, jefe final 21 (quitarlo 5), disparo 7, música 8, poderes 9.
- **Memoria del proyecto** (`fabrica/memoria.json`): cada instrucción y lo que se hizo. La IA la
  lee en cada cambio para no olvidar el contexto.
- **Versiones** (`fabrica/versiones/vN/`): instantánea de cada versión. Volver atrás se registra
  como versión nueva: nunca se pierde nada. El APK de cada versión sube su código de versión y
  conserva el paquete, así se instala encima del anterior.
- Tras tocar el esquema, los precios o el prompt de cambios: `python sincronizar_servidor.py`
  (copia esos datos a la función del servidor; `--comprobar` verifica que coinciden).

Prueba: `python -m pruebas.prueba_taller` (11 instrucciones seguidas: color, título, nivel, vidas,
quitar y poner jefe, disparo, música, plataformas, algo imposible; volver atrás y validación).

## Trabajador (la fábrica conectada a la app)

**En producción corre en RunPod** (`runpod_handler.py`, CPU serverless por segundos): la funcion
del servidor lo despierta al encolar, vacía la cola y se apaga. Despliegue y secretos en
`NUBE-LEEME.md`; nada se ejecuta en tu PC.

El mismo código funciona como trabajador permanente en cualquier máquina (útil para depurar):

```bash
export SUPABASE_URL=https://TU_REF.supabase.co
export SUPABASE_SERVICE_ROLE_KEY=...      # secreto: solo en el servidor
export ANTHROPIC_API_KEY=sk-ant-...
export RUNPOD_API_KEY=...                 # las imagenes se dibujan en la GPU de RunPod
python -m trabajador --comfy runpod://ID_ENDPOINT_IMAGENES --apk --web --capturas --ficha --clip
```

Atiende juegos nuevos, cambios, vueltas atrás, vídeos y publicaciones. Para un cambio baja la
última versión, aplica el plan ya aprobado (sin volver a llamar a la IA ni cobrar más) y sube la
versión nueva. Varios trabajadores a la vez no se pisan. Si se cae a mitad, el trabajo caduca y
se devuelve solo. Tareas extra del handler: `{"tarea": "aprender"}` y `{"tarea": "motor"}` (sube
el motor web común de Godot; lo hace el despliegue la primera vez).

## Arte

Convierte la **Biblia del juego** en arte y sonido coherentes y los mete en el kit de Godot.

```
Biblia → prompts → ComfyUI (crear ficha, editar frames) → postprocesado → QA → Godot
                                                        ↘ efectos de sonido procedurales
```

## Qué hace cada pieza

| Archivo | Qué hace |
|---|---|
| `biblia.schema.json` | El contrato de la Biblia (estilo, paleta, personajes, animaciones, escenarios, música, voces, sonido) |
| `ejemplos/biblia_salto.json` | Biblia de ejemplo: robot de latón en pixel art y su enemigo, Chatarrilla |
| `arte/prompts.py` | Encargos y prompts. Cada personaje tiene **una ficha**; sus frames se piden **editando la ficha**, con una biblioteca de poses (idle, run, jump, fall, hurt, attack, spin) |
| `arte/comfy.py` | Habla con ComfyUI rellenando los nodos **por su título** (sirve para cualquier modelo) |
| `arte/post.py` | Quita el fondo, misma escala para todos los frames, pies alineados, pixel art, **paleta forzada**, contorno, tiles sin costura |
| `arte/qa_arte.py` | Rechaza frames: tamaño, restos de fondo, semitransparencias, deriva de estilo, altura, silueta y colores distintos a la ficha |
| `arte/sfx.py` | Efectos de sonido procedurales con el timbre de la Biblia (retro, suave, metálico), pisotón incluido |
| `arte/interfaz.py` | Deduce la interfaz de la Biblia: perfil según el estilo y colores por rol desde la paleta (fondo = familia de tono dominante, acento = color vivo que no sea el de peligro), con contraste garantizado |
| `arte/godot_export.py` | Escribe hojas de sprites, tiles, sonidos y `assets/manifest.json` (con `"ui"`) en el kit |
| `arte/cli.py` | Lo orquesta todo; lo que el QA rechaza se regenera con otra semilla (hasta 3 veces) |
| `pruebas/` | ComfyUI simulado, prueba del arte (`prueba_completa`) y de la cadena con 3 ideas (`prueba_cadena`) |

## Probarlo sin GPU (simulador)

```powershell
cd fabrica
pip install numpy pillow jsonschema
python -m pruebas.prueba_completa ..\orqkit
```

## Arte real: GPU de RunPod por segundos

`--comfy runpod://<endpoint>` manda cada imagen al endpoint `orq-imagenes` (ComfyUI en una RTX
4090 alquilada por segundos, a cero cuando no hay trabajo). Los flujos por defecto están en
`plantillas/runpod/` y se validaron con un ComfyUI real:

| Flujo | Modelo | Variable |
|---|---|---|
| `crear_zimage.json` | Z-Image-Turbo (8 pasos) | `ORQ_CREAR=zimage` (por defecto) |
| `editar_klein.json` | FLUX.2 [klein] 4B (4 pasos, con la ficha como referencia) | `ORQ_EDITAR=klein` (por defecto) |
| `editar_qwen.json` | Qwen-Image-Edit 2511 + Lightning (4 pasos) | `ORQ_EDITAR=qwen` |

El coste de cada juego sale del tiempo real de GPU que devuelve RunPod
(`ORQ_RUNPOD_USD_SEG`, lo pone el despliegue según la GPU). `ORQ_COMFY` fija el destino por defecto.

**Música**: `musica_acestep.json` (ACE-Step 1.5 XL turbo con el modelo de lenguaje de 4B) compone
menú, nivel y victoria a partir de la Biblia (`arte/musica_ia.py`). Es automática cuando el arte va
a RunPod; `ORQ_MUSICA=procedural` la apaga y `ORQ_MUSICA=acestep` la fuerza. Si falla, la procedural.

Si algún día quieres usar un ComfyUI propio, sirve igual: `--comfy http://host:8188` con los
mismos flujos (o los tuyos exportados en formato API con los títulos `PROMPT`, `NEGATIVO`,
`SEED`, `ANCHO`/`ALTO`, `REF1` y `SALIDA`).

```bash
python -m arte.cli --biblia ejemplos/biblia_salto.json --comfy runpod://ID_ENDPOINT \
  --crear plantillas/runpod/crear_zimage.json --editar plantillas/runpod/editar_klein.json --godot ../orqkit
```

## Licencias de los modelos

Z-Image-Turbo, FLUX.2 [klein] **4B** y Qwen-Image-Edit 2511 (con su LoRA Lightning) son Apache 2.0 (uso comercial).
**No** uses FLUX.2 [klein] 9B ni FLUX [dev]: no son comerciales.
Antes de usar cualquier modelo, revisa el archivo de licencia de la versión exacta que descargas.

## Pendiente (siguientes pasos)

- Efectos de sonido con IA y voces de personajes dentro del juego.
- Fondos con parallax; arte de interfaz generado (marcos 9-slice, iconos, logo).
- Revisión visual con IA (comparar cada frame con la ficha).
