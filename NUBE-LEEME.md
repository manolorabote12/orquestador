# Orquestador 100 % en la nube (RunPod + GitHub + Supabase)

Tu PC no ejecuta nada. Cada pieza vive en un sitio:

- **Claude** (tu clave de Anthropic) es la mente: diseña cada juego, habla como Chispa en el taller y escribe los géneros nuevos.
- **GitHub** construye el código y lo despliega.
- **RunPod** pone las máquinas. Se alquilan por segundos y se apagan solas.
- **Supabase** guarda las cuentas, las tuercas y los juegos.

Tú pegas las claves una vez y pulsas un botón.

```
App (móvil) ──► Supabase (funciones) ──► cola de trabajos
                     │ despierta
                     ▼
         RunPod «orq-fabrica» (CPU, por segundo)
         Godot 4.6.3 · Android SDK 36 · ffmpeg · voz
         fabrica el juego, compila APK/AAB, vídeos, ficha
                     │ pide cada imagen
                     ▼
         RunPod «orq-imagenes» (GPU, por segundo)
         ComfyUI + Z-Image-Turbo · FLUX.2 klein 4B · Qwen-Image-Edit 2511
         + música ACE-Step 1.5 XL
                     │ y la voz de los vídeos
                     ▼
         RunPod «orq-voces» (GPU, por segundo)
         Chatterbox Multilingual (español con emoción)

         Modelos en un volumen de red compartido
```

## Qué modelos usa (y por qué)

Todos tienen licencia abierta que permite uso comercial (Apache 2.0 o MIT), así que puedes vender
los juegos. Antes de publicar, revisa el archivo de licencia de la versión exacta que se descarga.

| Uso | Modelo | Para qué es bueno |
|---|---|---|
| Crear desde texto | **Z-Image-Turbo** (6B, 8 pasos) | Cualquier estilo: pixel art, cartoon, realista, anime, low-poly, texto legible. Cuesta unos 2 s por imagen en una RTX 4090 |
| Editar desde la ficha (por defecto) | **FLUX.2 [klein] 4B** (4 pasos) | Poses del mismo personaje sin perder su diseño. Muy rápido |
| Editar con más fidelidad | **Qwen-Image-Edit 2511** + Lightning 4 pasos | Cambios difíciles (ropa, ángulo, varias referencias). Se activa con `ORQ_EDITAR=qwen` y la descarga de los modelos opcionales |
| Música | **ACE-Step 1.5 XL turbo** con el modelo de lenguaje de 4B (la máxima calidad del modelo) | Bandas sonoras completas, en cualquier estilo, a partir del ambiente, tempo, tonalidad e instrumentos de la Biblia: menú, nivel (en bucle sin salto) y victoria |
| Voces de los vídeos | **Chatterbox Multilingual** (MIT, Resemble AI) | Voz natural en español (y 22 idiomas más) con emoción por estilo: reto, curiosidad, humor. Lleva una marca de agua inaudible que identifica la voz como sintética |

Los cuatro flujos de ComfyUI (`fabrica/plantillas/runpod/*.json`) se han validado con un ComfyUI real 0.39.

Si la música con IA falla, el juego lleva la procedural de siempre. Si la voz con IA falla, se usa
Piper (dentro de la fábrica). Nunca sale un juego mudo ni un vídeo sin voz por un fallo de la GPU.

## Lo que cuesta

Son estimaciones con los precios de RunPod de octubre de 2026. Compruébalas en tu panel.

| Concepto | Precio |
|---|---|
| GPU RTX 4090 (24 GB), solo mientras dibuja | 1,10 $/hora → unos 0,0003 $/s |
| Arte de un juego (40-70 imágenes de 2-3 s, más el arranque) | 0,03-0,08 $ |
| Música (3 pistas con ACE-Step 1.5 XL) | unos 0,01-0,03 $ |
| Voces de los 3 vídeos (GPU L4, 0,69 $/h) | menos de 0,01 $ |
| Fábrica en CPU (diseño, niveles, bots, APK/AAB, vídeos) | 0,02-0,07 $ |
| Directora (Claude) | 0,02-0,05 $ |
| **Total por juego** | **unos 0,12-0,25 $** |
| Volumen de red con los modelos (100 GB) | unos 7 $/mes |
| Sin trabajo | 0 $ (las máquinas se apagan) |

- El coste real de GPU se apunta en cada trabajo: `executionTime` de RunPod × precio por segundo. Se ve en `v_margin_by_kind`.
- El precio en tuercas lo pone **solo el servidor**.

## Puesta en marcha (una vez, desde el navegador)

> **Lo más fácil:** `python conectar.py` (ver `PONER-EN-MARCHA.md`) hace los pasos 2, 3 y 5 por ti.

### 1. Cuentas

- **RunPod**
  - Crea la cuenta y añade saldo (con 10 $ hay para muchas pruebas).
  - En **Settings → API Keys** crea una clave con permiso de lectura y escritura.
- **Supabase**
  - Crea el proyecto. Los pasos están en `SETUP-backend.md`, apartado 1.
  - Apunta **Project URL**, **anon key**, **service_role key**, **Project ref** y la **contraseña de la base de datos**.
  - En **Account → Access Tokens** crea un token para la CLI.
- **Anthropic**: crea la clave y ponle un límite de gasto mensual.
- **GitHub**
  - Crea un repositorio privado y sube el contenido de `orquestador-completo.zip`.
  - Si no quieres usar el PC para esto: **Code → Codespaces → Create**, arrastra el zip y escribe:
    ```bash
    unzip orquestador-completo.zip && rm orquestador-completo.zip
    git add . && git commit -m "Orquestador" && git push
    ```
  - En **Settings (tu perfil) → Developer settings → Personal access tokens (classic)** crea un token con solo `read:packages`. Es el que usa RunPod para bajar tus imágenes privadas.

### 2. Pegar los secretos

En el repositorio: **Settings → Secrets and variables → Actions → New repository secret**.

| Secreto | Valor |
|---|---|
| `RUNPOD_API_KEY` | Clave de RunPod |
| `GHCR_TOKEN` | Token de GitHub con `read:packages` |
| `SUPABASE_URL` | `https://TU_REF.supabase.co` |
| `SUPABASE_ANON_KEY` | anon key |
| `SUPABASE_SERVICE_ROLE_KEY` | service_role key (solo aquí, **nunca** en la app) |
| `SUPABASE_PROJECT_REF` | el `TU_REF` |
| `SUPABASE_ACCESS_TOKEN` | token de la CLI de Supabase |
| `SUPABASE_DB_PASSWORD` | contraseña de la base de datos |
| `ANTHROPIC_API_KEY` | clave de Claude |
| `ORQ_LLAVES_SECRETO` | 40 letras y números al azar (cifra las llaves de firma de los usuarios). **Guárdalo**: si lo pierdes, no se pueden actualizar los juegos ya publicados |
| `ORQ_PLAY_CUENTA` *(opcional)* | JSON de la cuenta de servicio de Google Play |
| `ORQ_PLAY_CUENTA_CORREO` *(opcional)* | correo de esa cuenta de servicio |
| `ELEVENLABS_API_KEY` *(opcional)* | no hace falta: las voces van en RunPod. Solo si algún día quieres ElevenLabs (`ORQ_VOZ=elevenlabs`) |
| `HF_TOKEN` *(opcional)* | token de Hugging Face, solo si alguna descarga lo pide |

Variables opcionales (pestaña **Variables**):

- `ORQ_RUNPOD_DC`: centro de datos. Por defecto `EU-RO-1`.
- `ORQ_GPU`: lista de GPUs. Por defecto 4090, L4, A5000 y 3090.
- `ORQ_GPU_USD_HORA`: precio de la primera GPU.
- `ADMOB_REWARDED_AD_UNIT`.

### 3. Desplegar

**Actions → Desplegar → Run workflow**, marca **Primera vez** y pulsa **Run**. Tarda unos 30-60 minutos la primera vez, y hace esto:

1. Construye las tres imágenes a la vez, cada una en su máquina de GitHub: `orq-fabrica` (CPU), `orq-imagenes` (GPU: imágenes y música) y `orq-voces` (GPU).
   - Antes de publicar, la de la fábrica pasa su prueba: si algo falla, no se publica.
2. Crea en RunPod el volumen `orq-modelos` y los endpoints `orq-imagenes`, `orq-voces` y `orq-fabrica`, que escalan a 0.
3. Descarga los modelos al volumen (unos 45 GB). Una vez.
4. Sube el motor web de Godot, para que «Jugar ya» funcione en la app.
5. Sube a Supabase las migraciones y las funciones, y guarda en el servidor los secretos `RUNPOD_API_KEY`, `RUNPOD_FABRICA_ENDPOINT` y `ANTHROPIC_API_KEY`.

A partir de ahí, cada `git push` a `main` vuelve a desplegar solo lo que cambie. No duplica nada.

### 4. Reloj (automático)

`.github/workflows/reloj.yml` corre gratis en GitHub:

- **Cada 15 minutos:** si queda algo en la cola (por ejemplo, porque se perdió un aviso), despierta la fábrica.
- **Cada 6 horas:** la fábrica recalibra la dificultad con las partidas reales.

### 5. La app Orquestador (también en GitHub)

`.github/workflows/app.yml` compila la app con cada cambio en `app/`, sin Android Studio:
- siempre: un **APK de prueba** para instalar en tu móvil;
- y, si existe la llave de subida, el **.aab firmado** para Google Play.

Los dos se descargan en **Actions → App Android → Artifacts**. La app solo lleva la clave
pública (`SUPABASE_ANON_KEY`).

La llave de subida de la app se crea una vez en Codespaces y se guarda como secreto:

```bash
keytool -genkeypair -keystore subida.jks -alias subida -keyalg RSA -keysize 4096 -validity 10000 \
  -storepass "UNA_CLAVE_LARGA" -keypass "UNA_CLAVE_LARGA" -dname "CN=Orquestador"
base64 -w0 subida.jks   # copia la salida en el secreto ORQ_APP_KEYSTORE_B64
rm subida.jks
```

`ORQ_APP_KEYSTORE_PASS` = la misma clave. Antes de borrar el `.jks`, guarda una copia en un
gestor de contraseñas: con la firma de apps de Google Play se puede recuperar, pero es un trámite.

## Cómo funciona por dentro

| Archivo | Qué hace |
|---|---|
| `supabase/functions/_shared/fabrica.ts` | Tras encolar un trabajo, llama a `POST /v2/<fábrica>/run`. Sin secretos de RunPod no hace nada (modo trabajador propio) |
| `fabrica/runpod_handler.py` | Entrada de la fábrica en RunPod. Vacía la cola con el mismo código que el trabajador (`trabajador.vaciar_cola`) y se apaga. También tiene las tareas `aprender` y `motor` |
| `fabrica/arte/runpod.py` | `--comfy runpod://<endpoint>`. Manda el workflow y las referencias en base64, espera el arranque en frío, apunta el coste por segundo de GPU y cancela lo que se cuelga |
| `nube/imagenes/handler.py` | Endpoint de imágenes: ComfyUI dentro del contenedor, con la misma API que `runpod/worker-comfyui`. Rechaza nombres de archivo peligrosos. Tiene la tarea `descargar_modelos`, que escribe en `.part` y solo da el modelo por bueno si llega completo |
| `nube/imagenes/modelos.json` | Lista de modelos con su URL y licencia. Los de Qwen son opcionales |
| `fabrica/arte/musica_ia.py` | Música con ACE-Step: etiquetas desde la Biblia, control de calidad (silencio, pista cortada, saturación), bucle sin salto, volumen igualado y OGG para Godot |
| `nube/voces/handler.py` | Endpoint de voces: Chatterbox frase a frase, emoción y ritmo limitados, muestra de voz opcional que se borra al terminar. Tarea `descargar_modelos` |
| `fabrica/marketing/voz.py` | Elige la voz: RunPod (por defecto si hay endpoint), ElevenLabs, Piper o ninguna |
| `nube/fabrica/Dockerfile` | Ubuntu 24.04, Godot 4.6.3 con plantillas, JDK 17, Android SDK 36 con NDK, ffmpeg, Xvfb, Python y la voz Piper en español |
| `nube/imagenes/Dockerfile` | CUDA 12.8, PyTorch y ComfyUI. Fija `COMFY_REF` a un commit probado cuando lo tengas |
| `nube/voces/Dockerfile` | CUDA 12.4 y Chatterbox (imagen aparte: fija su propia versión de PyTorch) |
| `nube/desplegar.py` | API REST de RunPod: crea o actualiza por nombre. Es idempotente |
| `.github/workflows/desplegar.yml`, `reloj.yml`, `app.yml` | Despliegue, reloj y compilación de la app |

### Cambiar de modelo o de GPU

- **Editar con Qwen:**
  1. Lanza **Desplegar** con **Primera vez** después de quitar `"opcional": true` en `modelos.json`.
  2. Pon `ORQ_EDITAR=qwen` en el entorno de `orq-fabrica`.
- **Música procedural** en vez de IA (más barato): `ORQ_MUSICA=procedural` en `orq-fabrica`.
- **Más memoria** (por ejemplo, para Qwen en bf16): `ORQ_GPU=NVIDIA RTX A6000,NVIDIA L40S` y `ORQ_GPU_USD_HORA=1.22`.
- **Un modelo nuevo de ComfyUI:**
  1. Exporta su flujo en formato API con los títulos `PROMPT`, `SEED`, `ANCHO`, `REF1` y `SALIDA`.
  2. Guárdalo en `fabrica/plantillas/runpod/`.
  3. Añade sus archivos a `modelos.json`.

## Pruebas (sin GPU, sin cuenta)

```bash
cd fabrica
python -m pruebas.prueba_runpod              # arte entero contra la API de RunPod simulada
python -m pruebas.prueba_fabrica_runpod      # handler de la fábrica: cola, coste, motor web
python -m pruebas.prueba_imagenes_runpod     # fábrica → RunPod → handler de imágenes → ComfyUI
python -m pruebas.prueba_imagenes_runpod http://127.0.0.1:8189   # igual, con un ComfyUI de verdad
python -m pruebas.prueba_voces_runpod       # voz: fábrica → RunPod → handler de voces
python ../nube/prueba_desplegar.py           # despliegue idempotente contra la API REST simulada
```

**Probado:**

- Toda la cadena con RunPod simulado, incluidos los errores: clave mala, FAILED por memoria, trabajo colgado que se cancela y descarga cortada.
- El handler de imágenes contra un ComfyUI real: la referencia llega y se procesa, y un modelo que falta da un error claro.
- Los cuatro flujos (incluida la música) los valida ComfyUI 0.39, y el audio sale de un ComfyUI real como FLAC y llega entero.
- Música: menú, nivel y victoria en OGG, bucle sin salto, control de calidad y coste por segundo.
- Voces: frase a frase, emoción por estilo, errores claros y respaldo con Piper.

**Sin probar todavía** (no hay salida a internet desde aquí):

- La construcción real de las imágenes Docker.
- La API real de RunPod.
- Las descargas de Hugging Face y la calidad real de ACE-Step y Chatterbox en GPU (aquí se prueban con simuladores que siguen su mismo contrato).
- El primer despliegue en GitHub.

Es lo primero que se comprueba en la prueba final. Si algo falla, el registro de **Actions** dice en qué paso y por qué.
