# Orquestador: backend real (con economía blindada)

Qué se monta: cuentas de usuario, saldo de créditos que la app **no puede falsear**,
proyectos con historial de versiones, denuncias de contenido, y un sistema de
trabajos de pago que hace imposible gastar más de lo que se cobra en cualquier
acción: diseño con IA, cambios, imágenes, música, voces y compilación.

## Archivos (cópialos dentro de tu proyecto `orquestador/`)

```
supabase/
├─ migrations/
│  ├─ 20261005000001_init.sql          # Tablas base y seguridad por filas
│  ├─ 20261008000001_economia.sql      # Precios, límites, presupuesto, anuncios, margen
│  ├─ 20261008000002_fabrica_juegos.sql # Juegos completos: cola, progreso, archivos
│  ├─ 20261008000003_tiempo_real.sql    # Progreso en vivo
│  ├─ 20261008000004_taller_cambios.sql # Cambios por instrucciones y versiones
│  └─ 20261008000005_motor_web.sql      # Bucket público "motor" para jugar dentro de la app
└─ functions/
   ├─ _shared/
   │  ├─ http.ts                       # CORS, respuestas y sesión
   │  ├─ jobs.ts                       # Reservar / cerrar / fallar trabajos de pago
   │  ├─ llm.ts                        # IA de texto con coste real
   │  ├─ admob-ssv.ts                  # Verificación de firma de Google AdMob
   │  ├─ validate.ts                   # Validador del JSON del juego
   │  └─ designer-prompt.ts            # Prompt del diseñador + ejemplo
   ├─ create-design/index.ts           # Crear juego y cambios por chat
   ├─ create-game/index.ts             # Encargar un juego completo a la fábrica
   ├─ plan-change/index.ts             # Chispa propone un cambio (gratis) y el servidor fija su coste
   ├─ apply-change/index.ts            # Aplicar la propuesta (cobra exactamente ese coste)
   ├─ restore-version/index.ts         # Volver a una versión (gratis)
   └─ admob-reward/index.ts            # Créditos por anuncio bonificado
```

## Cómo se protege tu dinero

| Riesgo | Protección |
|---|---|
| Una acción cuesta más de lo que cobra | Cada acción tiene precio propio en créditos y se guarda su **coste real**. La vista `v_margin_by_kind` te enseña ingreso frente a coste |
| Alguien provoca fallos para usar la IA gratis | Máximo **3 devoluciones al día** por usuario; a partir de ahí, el fallo no se devuelve |
| Uso masivo de una cuenta | Máximo **4 trabajos por minuto** y un **tope diario por acción** (15 diseños, 60 cambios...) |
| Pico de usuarios o ataque | **Presupuesto diario global** (20 $ por defecto): si se alcanza, se rechazan trabajos nuevos **sin cobrar** |
| Cuentas falsas para créditos gratis | Bienvenida de **40 créditos solo con cuenta verificada** (correo confirmado o Google), una única vez |
| Créditos falsos por anuncios | Solo se dan si **Google firma** que el anuncio se vio. Sin duplicados, máximo 5 al día, 5 créditos cada uno |
| La función se cae a mitad | Los trabajos colgados más de 10 minutos se cierran solos con la misma regla de devolución |
| Imágenes, música, voces o compilación sin terminar | Están **desactivadas** en la tabla de precios hasta que exista su trabajador; no se pueden pedir |

Todo esto vive en la base de datos, en una sola transacción, y lo he probado en un
Postgres real: límites, presupuesto, devoluciones, bienvenida, anuncios y los
intentos de trampa como usuario normal (cambiar precios, darse créditos, ver ajustes,
forzar devoluciones). Todo bloqueado.

## Precios y ajustes (se cambian sin tocar código)

En Supabase, **Table Editor**:

- `pricing`: créditos, tope diario y coste estimado de cada acción, y si está activa.
- `settings`: presupuesto diario, créditos de bienvenida, tope de devoluciones, créditos
  por anuncio y valor neto de un crédito.

Valores iniciales (1 crédito ≈ 0,7 céntimos netos con un pack de 2,99 € = 300 créditos):

| Acción | Créditos | Tope diario | Estado |
|---|---|---|---|
| Crear juego | 20 | 15 | activa |
| Cambio por chat | 5 | 60 | activa |
| Arte completo | 60 | 5 | desactivada |
| Regenerar una imagen | 10 | 30 | desactivada |
| Música a medida | 40 | 5 | desactivada |
| Locución corta | 5 | 30 | desactivada |
| Compilar .aab | 100 | 3 | desactivada |
| **Juego completo** (fábrica) | **60** | 5 | activa |

Para ver si ganas o pierdes con cada acción, en **SQL Editor**:

```sql
select * from v_margin_by_kind;
```

`ingreso_eur` es lo que te queda de los créditos cobrados; `coste_usd`, lo que te
costaron los proveedores. Si una acción se acerca, súbele el precio en `pricing`.

## 1. Crear el proyecto en Supabase

1. Entra en https://supabase.com, crea una cuenta y pulsa **New project**.
2. Región: **Central EU (Frankfurt)**.
3. Guarda la contraseña de la base de datos.
4. En **Project Settings > API** apunta la **Project URL**, la **anon public key** y el
   **Project Reference** (el `xxxx` de la URL). La service_role key no se copia en ningún sitio.
5. En **Authentication > Sign In / Providers > Email**, deja activado **Confirm email**.
   Es lo que impide crear cuentas falsas para conseguir créditos.

## 2. Clave de la IA (Anthropic)

1. En https://console.anthropic.com añade un método de pago y crea una **API key**.
2. En **Limits**, pon un **límite de gasto mensual** bajo. Es la última red de seguridad.

## 3. Subir todo

**Lo normal: lo hace GitHub Actions** (`NUBE-LEEME.md`): migraciones, funciones y secretos del
servidor en cada `git push`, sin abrir una terminal. A mano, solo si lo necesitas:


```powershell
npm install -D supabase
npx supabase login
npx supabase init
```

Si `init` pregunta si sobrescribir algo, responde que **no**. Luego:

```powershell
npx supabase link --project-ref TU_PROJECT_REF
npx supabase db push
npx supabase secrets set ANTHROPIC_API_KEY=sk-ant-TU_CLAVE
npx supabase functions deploy create-design
npx supabase functions deploy create-game
npx supabase functions deploy plan-change
npx supabase functions deploy apply-change
npx supabase functions deploy restore-version
npx supabase functions deploy create-marketing
npx supabase functions deploy play-setup
npx supabase functions deploy publish-game
npx supabase functions deploy admob-reward --no-verify-jwt
npx supabase functions deploy charla
npx supabase functions deploy juego-compra --no-verify-jwt
npx supabase functions deploy play-resenas
npx supabase functions deploy heroe-dibujo
npx supabase functions deploy ganchos
```

**Online de los juegos** (migraciones `…13_liga_aldeas` a `…26_arena_coop`: liga, torneo, arena, clanes,
amigos, salas privadas, fantasmas, guerra de clanes, eventos en directo, guardado en la nube,
compras, panel de ingresos, repeticiones y arena cooperativa): todo funciona solo con la base de datos y el
canal en directo de Supabase. En el panel de Supabase, **Realtime → Settings**, deja permitido el
acceso público a los canales (la arena usa canales `arena-<sala>` de tipo *broadcast*; no guardan
nada). El trabajador limpia las salas viejas (`arena_limpiar`) y las partidas en la nube sin tocar
en 180 días (`nube_limpiar`) cada vez que despierta.

**Lo nuevo de las migraciones 27 a 33** (todas probadas en `supabase/pruebas/`):

- `…27_resenas`: reseñas de Google Play. `play-resenas` lee las reseñas con texto de los últimos 7
  días (es lo que da la API de Google; las más antiguas siguen en Play Console), la IA propone una
  respuesta en el idioma de quien escribió y **el autor la revisa y la envía**: nunca se contesta
  sola. Cupo de 60 borradores al día por usuario. La cuenta de servicio necesita en cada juego el
  permiso **«Responder a reseñas»** (además de «Publicar» y «Ver información financiera»).
- `…28_prueba_ab`: pruebas A/B de un nivel. El juego apunta en cada intento del nivel probado si
  jugó la versión A o la B; `prueba_ab_informe` lo resume para la app.
- `…29_invitaciones_ranking`: invita a un amigo (código de 7 letras; los dos ganan 30 tuercas
  cuando el invitado **fabrica su primer juego**; tope de 20 al mes) y «Top de la semana» del
  Escaparate (los me gusta pesan más que las jugadas).
- `…30_referencias`: tu dibujo como protagonista. Bucket privado `referencias` (cada usuario solo su
  carpeta, 4 MB, PNG/JPG/WEBP). `heroe-dibujo` revisa la imagen con la IA (nada de fotos de
  personas, personajes de marcas ni contenido no apto) antes de que el taller la acepte.
- `…31_giros_ganchos`: la fábrica apunta cada giro que prueba (`giro_anotar`) y aprende de todas
  las máquinas a la vez (`giros_estadisticas`); la función `ganchos` propone 3 juegos originales
  por idea (20 al día por usuario) sin ofrecer giros que fallan. Ver `GIROS-LEEME.md`.
- `…32_reto_semana`: reto de la semana. Un tema por semana (sale de la fecha, 52 temas); cada
  persona presenta uno de sus juegos ya compartidos en el Escaparate y ganan los 3 con más
  jugadas y me gusta de esa semana (150, 100 y 50 tuercas, en `settings`). Lo premia el reloj
  (`reto_premiar_anterior`, idempotente: nunca paga dos veces).
- `…33_perfil_creador`: `perfil_creador()` resume lo tuyo (juegos, partidas, me gusta, remix,
  juegos en Google Play y podios del reto) para el nivel y las insignias de la app.

`juego-compra` comprueba las compras dentro de los juegos (monedas, sin anuncios, pase). La llama
el juego con la clave pública, sin sesión (por eso `--no-verify-jwt`): verifica el token con Google
usando `ORQ_PLAY_CUENTA` (la misma cuenta de servicio que publica), lo anota una sola vez
(`juego_compras`) y lo consume o reconoce en Google. Para que Google le deje ver las compras, en
la invitación de cada juego la cuenta de servicio necesita además el permiso **«Ver información
financiera»** (*Usuarios y permisos* de Play Console).

`charla` es la charla en directo con los personajes de los juegos: la llama el juego con la
clave pública (anon) y solo responde si el autor ha comprado un paquete de mensajes
(`charla_activar`, 40 tuercas = 500 mensajes, precio en `pricing`). Usa la misma
`ANTHROPIC_API_KEY` (modelo barato), filtra lo que escribe el jugador y lo que contesta la IA,
y limita 30 mensajes al día por dispositivo (`settings.charla_por_sesion_dia`).

`admob-reward` va sin verificación de sesión porque la llama Google, no la app. Está
protegida por la firma de Google.

## Juegos completos (create-game + trabajador)

La migración `20261008000002_fabrica_juegos.sql` añade:

- Precio `game`: **60 tuercas** (diseño, niveles, arte, sonido y APK), máximo 5 al día.
  Coste estimado prudente 0,30 $; el real se guarda al terminar y se ve en `v_margin_by_kind`.
- Bienvenida: **90 tuercas = el primer juego gratis y un par de cambios** (migración del taller). El presupuesto diario global sigue
  limitando cuánto puede costar eso en total.
- Cola de trabajos: `queue_game` (cobra y encola), `claim_game_job` (el trabajador toma el
  siguiente), `job_progress` (progreso en vivo), `complete_game_job` (crea el proyecto y guarda
  los archivos) y `fail_job` (devuelve). Todo solo para el servidor.
- Caducidad: un juego en marcha más de 30 minutos se da por fallido y se devuelve; uno en cola
  más de 3 horas (sin trabajador encendido) se cancela y se devuelve **siempre**, sin gastar
  las devoluciones diarias del usuario.
- Almacén privado `juegos`: `<usuario>/<trabajo>/...` con APK, capturas, icono, informe y el
  proyecto de Godot en .zip. Cada usuario solo puede leer lo suyo.

La app llama a `create-game` con `{ "idea": "..." }` y recibe `job_id`. Luego lee su fila de
`jobs` (`status`, `progress`, `result`) y descarga los archivos con URLs firmadas.
La fábrica corre en RunPod y se despierta sola al encolar (`_shared/fabrica.ts`, secretos
`RUNPOD_API_KEY` y `RUNPOD_FABRICA_ENDPOINT`, que pone el despliegue). Ver `NUBE-LEEME.md`.

## Taller por instrucciones (plan-change, apply-change, restore-version)

1. **Proponer** (`plan-change`, gratis, hasta 80 al día): la IA traduce la instrucción a un plan;
   el servidor lo valida, **calcula el coste con la tabla compartida** y lo guarda (`change_plans`).
   La app enseña el resumen, lo que no se puede hacer y el precio.
2. **Aplicar** (`apply-change`): `queue_change` cobra exactamente el coste guardado, marca el plan
   como usado (no se puede reutilizar), comprueba que el juego no se está fabricando ya y lo encola.
   Un plan caduca a los 30 minutos.
3. **Volver** (`restore-version`): gratis, hasta 15 al día; queda como versión nueva.
4. El trabajador baja la última versión, aplica el plan, la valida con bots y sube la versión
   nueva (`complete_change_job`). Si falla, devuelve exactamente lo cobrado.

`supabase/functions/_shared/cambios-datos.ts` se genera con `python fabrica/sincronizar_servidor.py`:
así la fábrica y el servidor usan el mismo esquema, los mismos precios y el mismo prompt.

## Vídeos para redes (create-marketing)

La migración `20261009000001_marketing.sql` añade el precio `game_marketing` (**20 tuercas**, hasta
6 al día, coste estimado 0,15 $), `queue_marketing` (cobra y encola), `complete_marketing_job`
(guarda los 3 vídeos y los textos en `projects.files.marketing` y en la versión actual, sin crear
versión nueva) y amplía `claim_game_job` y la caducidad a este tipo de trabajo.

La app llama a `create-marketing` con `{ "project_id": "..." }`. El trabajador baja la versión
actual, ejecuta el estudio (`fabrica/marketing`) y sube `vN/marketing/{reto,curiosidad,humor}.mp4`,
sus portadas y `marketing.zip`. Voz en off: en el PC del trabajador, `ELEVENLABS_API_KEY` o
`ORQ_PIPER_VOZ` (ver `fabrica/LEEME.md`). La clave de ElevenLabs **nunca** va en la app.

## Publicar en Google Play (play-setup, publish-game)

La migración `20261009000002_publicar.sql` añade `play_cuentas` (estudio y correo de cada
usuario), `projects.play` (paquete, versión, pista, estado), el precio `game_publish` (gratis,
10 al día), `queue_publish` / `complete_publish_job`, el bucket **público** `legal` (políticas de
privacidad, solo HTML) y el bucket **privado** `llaves` (llaves de subida cifradas; sin política de
lectura: solo la clave de servicio). Todo el detalle y la puesta en marcha: `PUBLICAR-LEEME.md`.

`supabase/pruebas/` aplica todas las migraciones en un PostgreSQL local y recorre los flujos
de juego, vídeos y publicación (`flujo.sql` termina con FLUJO OK).

## Aprender de los jugadores (registrar_partida, informe_jugadores)

La migración `20261009000003_aprendizaje.sql` añade `projects.telemetria_id`, la tabla `partidas`
(sin acceso directo: solo por funciones), `registrar_partida` (la llaman los juegos con la clave
**anon**: valida y limita), `informe_jugadores` (solo el autor, con su sesión) y
`estadisticas_globales` (solo el trabajador). Para que los juegos nuevos envíen datos, el trabajador
necesita también `SUPABASE_ANON_KEY` (la clave pública). Todo en `APRENDIZAJE-LEEME.md`.

## Jugar dentro de la app (bucket "motor")

La migración `20261008000005_motor_web.sql` crea el bucket **público** `motor` (solo lectura;
nadie puede escribir salvo la clave de servicio). Ahí va, una sola vez por versión de Godot, el
motor web común (`index.js` + `index.wasm`, ~38 MB, el navegador lo guarda en caché):

```powershell
cd fabrica
& $env:GODOT --headless --path ..\orqkit --export-release "Web" build/web/index.html
python -m subir_motor ..\orqkit\build\web       # imprime la VITE_MOTOR_URL para la app
```

Cada versión de cada juego sube solo su paquete (`files.web` = `.../vN/web/index.pck`, 1-2 MB) al
bucket privado `juegos`; la app lo abre con una URL firmada de 1 hora. Coste de almacenamiento y
tráfico mínimo: el motor se descarga una vez por móvil, y cada juego pesa como una foto.

## 4. Cierre automático de trabajos colgados

En Supabase: **Database > Extensions**, activa **pg_cron**. Después, en **SQL Editor**:

```sql
select cron.schedule('expirar-trabajos', '*/5 * * * *', 'select public.expire_stuck_jobs()');
```

## 5. Probarlo desde PowerShell

En **Authentication > Users > Add user**, crea `prueba@tucorreo.com` con contraseña y
marca **Auto Confirm User**. Recibe 90 créditos (un juego completo y un par de cambios).

```powershell
$URL  = "https://TU_REF.supabase.co"
$ANON = "TU_ANON_KEY"

$login = @{ email = "prueba@tucorreo.com"; password = "TU_CONTRASEÑA" } | ConvertTo-Json
$s = Invoke-RestMethod -Method Post -Uri "$URL/auth/v1/token?grant_type=password" `
     -Headers @{ apikey = $ANON } -ContentType "application/json" -Body $login
$h = @{ Authorization = "Bearer $($s.access_token)"; apikey = $ANON }

# Crear un juego (20 créditos)
$body = @{ idea = "Un ninja esquiva shurikens en los tejados de noche y recoge monedas" } | ConvertTo-Json
$r = Invoke-RestMethod -Method Post -Uri "$URL/functions/v1/create-design" -Headers $h `
     -ContentType "application/json; charset=utf-8" -Body ([Text.Encoding]::UTF8.GetBytes($body))
$r.spec.meta.title
$r.credits          # 20

# Pedir un cambio (5 créditos)
$body = @{ project_id = $r.project_id; change = "más difícil y con 5 vidas" } | ConvertTo-Json
$r2 = Invoke-RestMethod -Method Post -Uri "$URL/functions/v1/create-design" -Headers $h `
      -ContentType "application/json; charset=utf-8" -Body ([Text.Encoding]::UTF8.GetBytes($body))
$r2.version         # 2

# Encargar un juego completo (60 créditos; necesita el trabajador encendido)
$body = @{ idea = "Un gato ninja rápido que salta por tejados de noche" } | ConvertTo-Json
$g = Invoke-RestMethod -Method Post -Uri "$URL/functions/v1/create-game" -Headers $h `
     -ContentType "application/json; charset=utf-8" -Body ([Text.Encoding]::UTF8.GetBytes($body))
# Ver el progreso (repite cada pocos segundos)
Invoke-RestMethod -Uri "$URL/rest/v1/jobs?id=eq.$($g.job_id)&select=status,progress,result" -Headers $h
```

Después mira el coste real en **SQL Editor**: `select kind, provider_cost_usd, tokens_in, tokens_out from jobs;`

## 6. Anuncios bonificados (cuando tengas AdMob)

1. En la consola de AdMob, en tu bloque de anuncios bonificado, activa
   **Server-side verification** y pon como URL:
   `https://TU_REF.supabase.co/functions/v1/admob-reward`
2. Opcional, para aceptar solo tu bloque de anuncios:
   `npx supabase secrets set ADMOB_REWARDED_AD_UNIT=1234567890` (el número final del id).
3. En la app, al cargar el anuncio se configura la verificación con
   `user_id` = id del usuario en Supabase (lo haremos al conectar la app).

## Respuestas de create-design

| Código | Significado | Qué hace la app |
|---|---|---|
| 200 | Juego creado o cambiado | Carga `spec` y actualiza el saldo con `credits` |
| 400 | Idea o cambio con longitud no válida | Muestra `message` |
| 401 | Sin sesión | Manda a iniciar sesión |
| 402 | Sin créditos | Ofrece anuncio o comprar créditos |
| 404 | El proyecto no existe o no es tuyo | Vuelve a la lista |
| 429 | Demasiado rápido o tope diario alcanzado | Muestra `message` |
| 502 | Falló la IA; `refunded` dice si se devolvió | Muestra `message` |
| 503 | Presupuesto del día agotado o función no disponible | Muestra `message` (no se cobró) |

## Para añadir imágenes, música, voces o compilación

Cada trabajador nuevo sigue el mismo patrón de `create-design`:
`reserveJob` → trabajo → `finishJob` con su coste real (o `failJob`). Al terminarlo,
se activa su fila en `pricing` (`enabled = true`) y se ajusta `est_cost_usd` con los
primeros costes reales.
