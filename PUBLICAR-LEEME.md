# Publicar en Google Play desde la app

Lo que hace Orquestador por cada juego, y lo poco que tiene que hacer el usuario.

## Qué hace Orquestador solo

| Pieza | Detalle |
|---|---|
| **.aab firmado** | Compilado con Gradle, apuntando a **Android 16 (API 36)**: lo exige Google desde el 31-08-2026 para apps nuevas y actualizaciones. La versión mínima es Android 7 (API 24). |
| **Llave de subida** | Una por usuario, que vale para todos sus juegos. Se guarda **cifrada** en el bucket privado `llaves`. Google firma la app final con su propia llave (Firma de apps de Google Play). |
| **Icono de la tienda** | 512×512, PNG de 32 bits, a sangre, sin esquinas redondeadas (las pone Google). |
| **Icono del móvil** | Icono adaptativo de Android 8 o superior: fondo, primer plano con el héroe en la zona segura, monocromo para los temas de Android 13 o superior, y el clásico de 192 px. |
| **Gráfico destacado** | 1024×500, sin transparencia. |
| **Capturas** | 1080×1920, de 2 a 8, sin transparencia, con un mensaje encima, en español, inglés, portugués, francés, alemán e italiano. |
| **App Store** | Todo listo para cuando haya Mac en la nube: icono 1024 sin alfa, capturas de iPhone 6,9" (1290×2796) y textos con los límites de Apple. |
| **Textos** | Título (máximo 30), descripción breve (máximo 80) y completa (máximo 4000), en `es-ES`, `en-US`, `pt-BR`, `fr-FR`, `de-DE` e `it-IT`. |
| **Política de privacidad** | Una página pública por juego (bucket `legal`), que dice la verdad sobre lo que recoge el juego. |
| **Respuestas de los formularios** | Contenido de la app, clasificación IARC, seguridad de los datos y público objetivo, según lo que tiene el juego de verdad: anuncios, datos de partida y tipo de violencia. |
| **Subida** | Por la API oficial (`androidpublisher v3`): el .aab va a la pista elegida, y los textos e imágenes en los dos idiomas. Si la app aún es un borrador, se sube como borrador. |
| **Comprobación** | `recursos.py` revisa cada imagen y cada texto contra las reglas antes de subir nada. |

## Lo que hace el usuario (una vez por juego, unos 10 minutos)

En la app, ficha del juego > **Publicar en Google Play**. Cada paso trae los datos con un botón «Copiar».

1. Si no la tiene, crea la cuenta de desarrollador: pago único de 25 $ y verificación de identidad.
2. Crea el juego en Play Console con el nombre que le damos.
3. Invita a la cuenta de servicio de Orquestador en *Usuarios y permisos*, solo para ese juego
   con «Responder a reseñas» (para contestarlas desde la app) y «Ver información financiera» si
   quiere vender dentro del juego.
4. Sube **a mano** el primer .aab a *Prueba interna*. Google lo exige la primera vez.
5. Rellena los formularios de *Contenido de la aplicación* con las respuestas que le damos.
6. Pulsa **«Ya está: subir a prueba cerrada»**.

A partir de ahí, cada versión nueva se publica con **«Subir versión actual»**, en la pista que elija.

**Compras dentro del juego.** Al publicar, Orquestador crea solo los 4 productos de la tienda
(500 monedas 0,99 €, 3000 monedas 4,99 €, pase premium 3,99 € y sin anuncios 2,99 €; Google pone
el precio de cada país) en los idiomas del juego. Para vender hace falta un **perfil de pagos** en
Play Console (*Configuración → Perfil de pagos*); sin él, el juego se publica igual y la app avisa
de qué falta. Lo vendido aparece en la app, en *Jugadores → Ingresos y jugadores*.

Las **cuentas personales nuevas** necesitan 12 probadores durante 14 días seguidos en prueba cerrada antes de pasar a producción. Eso lo resuelve la Lanzadera.

## La Lanzadera (pestaña de la app)

1. **Tu Grupo de Google** (2 minutos): en groups.google.com crea un grupo abierto («Cualquier usuario de la Web puede unirse») y añade su correo `nombre@googlegroups.com` como probadores en Play Console → Prueba cerrada.
2. **Pide probadores**: elige el juego (ya subido a prueba cerrada), pega el enlace del grupo y una frase.
3. **Da para recibir**: tu campaña solo aparece si estás probando al menos 3 juegos de otros (premium sale primero sin esa condición). Los puntos (+1 por día jugado, +5 al cumplir 14 días, −5 por abandonar) ordenan la lista: quien más ayuda, antes recibe.
4. **Cada probador**: se une al grupo, se hace probador desde el enlace de Google Play, instala y hace un check-in diario («he jugado hoy», nivel alcanzado y opinión **privada** para el autor). Dos días sin jugar = abandono.
5. Con 12 probadores de 14 días la campaña pasa a **«lista para producción»**: en Play Console pide el acceso y usa las opiniones para contar qué mejoraste.

Normas que la mantienen dentro de las reglas de Google: nunca se piden ni se premian reseñas en Google Play, los puntos no se compran ni se cambian por tuercas, y no se guarda el correo de nadie. Servidor: migración `20261010000001_lanzadera.sql` (prueba `supabase/pruebas/lanzadera.sql`); el reloj de GitHub llama a `lz_revisar` cada 15 minutos.

### Mejoras para llegar a producción
- **Reservas**: cada campaña admite 12 + 6 probadores (`lz_margen`), para que un par de abandonos no obliguen a empezar.
- **Proyección**: en «Mis campañas», la fecha estimada para pedir producción y un aviso si, con los que siguen jugando, no se llega a 12.
- **Racha y recordatorio**: el probador ve su racha y la app le avisa a las 19:00 si ese día aún no ha jugado (2 días sin jugar = abandono).
- **Respuestas para pedir producción**: Google hace un cuestionario al solicitar el acceso. La app lo responde con los datos reales: cómo se captaron los probadores, cuántos completaron, días jugados, nivel medio, temas y citas de las opiniones, versiones publicadas durante la prueba... El autor lo revisa y lo copia. Código en `app/src/produccion.ts` y migración `20261026000039_lanzadera_produccion.sql`.
- **Probar con amigos** (Publicar → Google Play): sube a la prueba interna (hasta 100 personas por correo, sin revisión) y comparte su enlace. No cuenta para los 12 de la prueba cerrada.

## Puesta en marcha (tú, una vez)

1. **Cuenta de servicio de Orquestador**
   - En Google Cloud Console: crea un proyecto y activa la API *Google Play Android Developer API*.
   - En *IAM > Cuentas de servicio*: crea una y descarga su clave JSON.
   - No hace falta vincularla a tu Play Console. Cada usuario la invita en la suya.
2. **Trabajador.** Tiene que tener estas variables de entorno:
   - `ORQ_PLAY_CUENTA`: la ruta al JSON de la clave, o el JSON entero.
   - `ORQ_LLAVES_SECRETO`: 32 caracteres aleatorios o más. **Guárdalo bien**: sin él no se pueden abrir las llaves de los usuarios.
   - Plantillas de Godot 4.6.3 completas: traen `android_source.zip`.
   - SDK de Android con la *platform 36* y *build-tools 36*, y JDK 17 o superior.
3. **Supabase**

   ```powershell
   npx supabase db push
   npx supabase functions deploy play-setup
   npx supabase functions deploy publish-game
   npx supabase secrets set ORQ_PLAY_CUENTA_CORREO=orquestador-publicador@TU-PROYECTO.iam.gserviceaccount.com
   ```

4. **Prueba en tu PC**, sin la app:

   ```powershell
   cd fabrica
   python -m play.publicador ..\proyectos\mi_juego --estudio "Daniel Studio" --correo tu@correo.com --modo primer_aab
   ```

   Sale `build\<juego>.aab`, `fabrica\play\guia.json` y `fabrica\play\privacidad.html`.

## Pruebas

- `python -m pruebas.prueba_play`: la API de Google contra un servidor falso. Cubre el JWT, el orden de una edición, el paso a borrador, las imágenes en dos idiomas y la traducción de los errores.
- `python -m pruebas.prueba_trabajador`: el trabajador con un Supabase falso. Cubre la primera vez, la subida, la llave cifrada que se reutiliza y la política pública.
- `supabase/pruebas/flujo.sql`: las funciones de la base de datos sobre un PostgreSQL de verdad.

**Lo que no se ha podido probar aquí** (no hay acceso a Gradle ni a Google):
- la compilación real del .aab;
- la subida a los servidores de Google.

Las dos primeras veces, mira bien el resultado en Play Console.

## Apple App Store (siguiente fase)

- Hace falta la cuenta de Apple Developer (99 $ al año) **a nombre del usuario**. Apple solo acepta juegos hechos con generadores si los envía el propio autor (regla 4.2.6).
- Compilar requiere macOS y Xcode: un Mac en la nube, como los de GitHub Actions o Codemagic.
- La subida se hará con la API de App Store Connect, con una clave .p8 del usuario.
- Las imágenes y los textos ya salen hechos: carpeta `ficha/appstore/`.
