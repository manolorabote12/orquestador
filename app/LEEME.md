# Orquestador: la app (1.2)

La app móvil de verdad: entrar con un código por correo, escribir la idea, ver a Chispa
fabricar el juego paso a paso, **jugarlo al instante dentro de la app** y descargar el APK,
las capturas y el proyecto de Godot.

| Pestaña | Qué hace |
|---|---|
| **Taller** | Idea (con ejemplos de los 7 géneros: plataformas, runner, volador, hordas, puzle, torres y carreras) → «Fabricar juego» (60 tuercas). Banco de pruebas en vivo: diseño, niveles, arte y sonido, pruebas con bots, APK, guardado. Si cierras la app a mitad, al volver retoma el seguimiento |
| **Mis juegos** | Lista con icono y versión. Ficha con capturas, **«Jugar ya»** (el juego se abre a pantalla completa dentro de la app, sin instalar nada), «Descargar APK», **«Ficha para Google Play (.zip)»** (icono, gráfico destacado, capturas con mensaje y textos ES/EN listos para Play Console), **«Clip para TikTok, Shorts y Reels»** (visor en bucle y descarga del MP4 vertical), **Cómo lo juega la gente** (por nivel: cuántos lo pasan, abandonan y llegan, con consejos que Chispa aplica con un toque), **Publicar en Google Play** (guía paso a paso con cada dato para copiar, descarga del primer .aab y luego «Subir versión actual» a la pista elegida), **Vídeos para redes con IA** (3 vídeos con guion, subtítulos y voz; botones Compartir —menú del sistema con el vídeo— y Copiar texto de TikTok, Reels o Shorts, en español o inglés), «Proyecto de Godot (.zip)» y el **taller de ese juego**: le escribes a Chispa lo que quieres cambiar, te dice qué hará y cuánto cuesta, lo aplicas y ves el progreso. Cada cambio es una versión y puedes volver a cualquiera gratis |
| **Tuercas** | Saldo y lo que te llega. Anuncios con premio y packs: preparados, se activan con AdMob y Google Play |
| **Cuenta** | Correo, conexión y cerrar sesión |

Sin datos de Supabase arranca en **modo demostración** (todo simulado y marcado con una franja).

## Probarla en el navegador del PC

```powershell
cd app
npm install
npm run dev            # abre la URL que muestra (modo demostración)
```

## Conectarla a tu backend

1. Sube el backend (`SETUP-backend.md`): todas las migraciones y las funciones `create-game`,
   `plan-change`, `apply-change` y `restore-version`.
2. Copia `.env.example` como `.env` y pon tu `VITE_SUPABASE_URL` y `VITE_SUPABASE_ANON_KEY`.
   Para «Jugar ya», sube el motor web una vez (`python -m subir_motor`, ver `fabrica/LEEME.md`)
   y pon `VITE_MOTOR_URL` con la URL que imprime. El trabajador debe ir con `--web`
   (y con `--capturas --ficha --clip` para la ficha de Google Play y el clip para redes).
3. **Código por correo** (`conectar.py` lo hace solo): en Supabase, *Authentication → Email
   Templates*, en **Confirm signup** (usuarios nuevos) y en **Magic Link** (los que ya tienen
   cuenta), pon un cuerpo que incluya el código, por ejemplo:
   `Tu código para entrar en Orquestador es: {{ .Token }}`
4. Enciende el trabajador (ver `fabrica/LEEME.md`). Sin él, los juegos se quedan en cola y,
   pasadas 3 horas, se cancelan y se devuelven solos.
5. `npm run dev` y entra con tu correo: recibes 90 tuercas (un juego y un par de cambios).

## Instalarla en tu móvil Android

Necesitas Android Studio (trae el SDK y Java).

```powershell
cd app
npx cap add android        # solo la primera vez
npm run android            # compila, copia a Android y abre Android Studio
```

En Android Studio, con el móvil conectado por USB (depuración USB activada), pulsa ▶ Run.
Para descargar los APK de tus juegos desde la app, Android pedirá permitir instalar apps
desde esa fuente la primera vez.

## Cómo está hecha

```
src/
├─ api/            Capa de datos, un archivo por área (tipos, contrato y servidor de cada una):
│  ├─ index.ts     Backend (la suma de las áreas) y crearBackend: Supabase real o demostración
│  ├─ conexion.ts  Cliente de Supabase y lo común (llamar a una función, quién ha entrado)
│  ├─ cuenta.ts    Entrar (código por correo o Google), salir, borrar cuenta, invitaciones
│  ├─ comunidad.ts Escaparate, me gusta, remix, reto de la semana, ideas de Chispa, denuncias
│  ├─ juegos.ts    Encargar, seguir el trabajo en tiempo real (+ consulta cada 4 s), versiones,
│  │               cambios con Chispa, URLs firmadas
│  ├─ publicar.ts  Google Play, App Store, AdMob y vídeos para redes
│  ├─ jugadores.ts Informe, clasificaciones, liga, ingresos, eventos, A/B, reseñas y charla
│  ├─ tienda.ts    Tuercas, tienda de Google Play, compras y anuncios con premio
│  └─ lanzadera.ts Probadores para la prueba cerrada de Google Play
├─ errores.ts      Un solo sitio para los errores: el mensaje para la persona (nunca el técnico),
│                  «sin conexión» reconocido aunque venga envuelto, y los fallos no previstos avisados
├─ demo.ts         La misma interfaz simulada, con el juego de ejemplo que fabricó la cadena
├─ jugador.ts      «Jugar ya»: motor de Godot (público, en caché) + paquete del juego (URL firmada)
│                  dentro de un iframe; al cerrar se libera todo (memoria, audio, WebGL)
├─ ui.ts           DOM seguro (los textos del usuario nunca se insertan como HTML), Chispa, iconos
├─ main.ts         Barra, tuercas, pestañas y entrada (y el enlace ?invita=CÓDIGO); cada pestaña se
│                  carga al abrirla y las demás se adelantan en segundo plano
├─ asesor.ts       «Qué hacer ahora»: las 3 acciones que más ayudan a un juego (reglas puras, con pruebas)
├─ ab.ts           Veredicto de las pruebas A/B (prueba de dos proporciones, mínimo 30 por versión)
├─ plantillas-datos.ts  Plantillas de éxito (GENERADO por fabrica/sincronizar_servidor.py)
└─ vistas/         entrar, taller, juegos, tuercas, cuenta
```

`npm test` prueba los consejos de los jugadores, el editor de niveles, el asesor, las pruebas A/B
y los errores (mensajes claros, sin conexión, fallos no previstos).

Errores en las vistas: `mensajeError(e, "texto por defecto")` para el texto, `avisoError(e, texto,
reintentar?)` para un aviso (con botón Reintentar si se puede repetir) y `bloqueError(...)` para una
pantalla que no ha podido cargar. Nunca `e.message` directamente: puede ser un texto técnico.

La clave `anon` de Supabase es pública por diseño: los permisos los pone la seguridad por
filas (cada usuario solo ve sus juegos, su saldo y sus archivos). La clave de servicio y la de
Anthropic **nunca** van en la app: solo en las funciones del servidor y en el trabajador.
