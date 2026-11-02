# Nichos: juegos para negocios y juegos regalo

**Desde el taller:** encima de la idea hay que elegir **¿Para qué es?**: *Para publicar*, *Para mi negocio*, *Para regalar* o *Para mi clase*. Cada opción cambia el ejemplo y lo que dice Chispa. Al terminar el juego, el botón lleva directo a su sección: el premio, la dedicatoria o la clase.

Estos son usos que no cubren las otras apps de crear juegos. Los dos se configuran desde la app **sin publicar otra versión**: el juego lo lee del servidor al abrirse.

## 1. Premio real para tu negocio

Un cupón de verdad para quien supera el nivel que elijas: «Café gratis con tu desayuno», «10 % en tu próxima compra»... El juego sirve como escaparate del negocio y trae clientes a la tienda.

**En la app:** juego → pestaña *Jugadores* → *Premio real para tu negocio*.
- Hay ideas por tipo de negocio (cafetería, tienda, restaurante, peluquería, gimnasio, tienda online). Se elige una y se cambia a gusto.
- Campos: premio, código (3 a 16 letras o números), nivel, dónde canjearlo, web (opcional, `https://`) y caducidad (opcional).
- Arriba se ve cuántos jugadores lo han ganado y cuántos lo han canjeado.
- **Canjear en la tienda**: el dependiente escribe el código del cliente (CAFE-7F3A) y la app dice al momento «Válido» (y lo marca como usado), «Ya se usó el 3 nov» o «No existe». Así cada código vale una sola vez.
- **Cartel para la tienda**: un PNG en A4 con «¡Juega y gana!», el premio, el nivel y un QR al juego (a Google Play o al enlace del escaparate) para imprimirlo y pegarlo en el mostrador.

**En el juego:**
- La portada tiene el botón **Premio**. Antes de ganarlo dice qué hay que hacer («Supera el nivel 3 y consigue...»).
- Al superar ese nivel sale **«¡Has ganado un premio!»** en la pantalla de nivel superado.
- El panel muestra el código grande, dónde canjearlo, la caducidad y los botones *Copiar código* e *Ir a la web*.
- Cada jugador recibe **su propio código**: el del negocio + 4 letras (`CAFE-7F3A`). Así la tienda puede apuntar los que ya se han usado.
- Se gana una vez por móvil. Si caduca o el autor lo quita, deja de ofrecerse, pero el código ya ganado se sigue viendo.

**Sin servidor:** `game.json -> "premio": {"texto", "codigo", "tras_nivel", "donde", "web", "caduca"}`. En ese caso el código es el mismo para todos.

**Técnico:**
- Servidor: migración `20261101000044_premio_real.sql`.
  - El autor usa `premio_guardar` y `premio_autor`.
  - El juego usa `premio_actual` y `premio_ganado`; `premio_ganado` comprueba el nivel en el servidor.
  - Prueba: `pruebas/premio_real.sql`.
- Kit: `kit/prize.gd` y `kit/ui/screens/prize_panel.gd`.
- App: `src/premio.ts`, con prueba en `pruebas/premio.mjs`.

## 2. Juego regalo

Un juego hecho para una persona: al abrirlo ve **«Para Lucía, de Dani»**. Dentro hay un **mensaje secreto** que aparece al superar el nivel elegido, o al acabar el último. Sirve para cumpleaños, aniversarios, San Valentín, Navidad o para pedir algo especial.

**En la app:** juego → pestaña *Compartir* → *Juego regalo*.
- Se elige la ocasión (trae un mensaje de ejemplo), para quién, de quién, el mensaje (hasta 400 letras) y cuándo aparece.
- **Ver cómo lo verá** enseña antes de mandarlo los tres momentos: la página del enlace, la presentación al abrir el juego y el mensaje al superar el nivel.
- **Mandar el enlace privado** crea un enlace que no sale en el escaparate y lo comparte o copia.
- La app dice si la persona **ya lo ha abierto** y si **ya ha leído el mensaje**.
- *Ya no es un regalo* lo quita y borra el enlace (salvo que el juego también esté en el escaparate).

**En el juego:**
- La primera vez, una presentación: para quién, de quién y que hay un mensaje escondido.
- Al superar el nivel elegido se abre el mensaje. Después, el botón **Mensaje** de la portada lo vuelve a enseñar.
- Un juego regalo **no lleva anuncios** (ni banner ni intersticiales) **ni la oferta de bienvenida**.

**En la web:** el enlace `jugar.html?j=<id>` muestra «🎁 Para Lucía» y el botón *Abrir el regalo*. La página nunca muestra el mensaje: solo lo enseña el juego.

**Sin servidor:** `game.json -> "regalo": {"para", "de", "mensaje", "tras_nivel"}`.

**Técnico:**
- Servidor: migración `20261101000045_juego_regalo.sql`.
  - El autor usa `regalo_guardar` y `regalo_autor`.
  - La web usa `regalo_ficha` y `regalo_abierto`.
  - El juego usa `regalo_juego` y `regalo_leido`.
  - Prueba: `pruebas/juego_regalo.sql`.
  - La función `escaparate` tiene las acciones `regalo` y `regalo_retirar`.
- Kit: `kit/gift.gd` y `kit/ui/screens/gift_panel.gd`.
- App: `src/regalo.ts`, con prueba en `pruebas/regalo.mjs`.

## 3. Opinión privada antes que valoración pública

Tras unos niveles superados con buenas estrellas (a partir del 5), el juego pregunta **«¿Te está gustando?»**:
- **Sí:** da las gracias y lleva a valorarlo en Google Play (`market://` en Android, a partir de `game.json -> share_url`).
- **No mucho:** pregunta qué mejoraría y se lo manda **al autor**, no a la tienda. Así hay menos notas malas en Play y más ideas para mejorar.
- **Ahora no:** lo aplaza 5 niveles. Pregunta como mucho 2 veces.
- Nunca pregunta en juegos para peques ni en juegos regalo. `game.json -> "rate": false` lo apaga.

**En la app:** pestaña *Jugadores* → *Lo que opinan en privado*. Se ve el % de jugadores a los que les gusta y los últimos comentarios con su nivel. El botón *Arreglarlo* pasa el comentario a Chispa como cambio.

**Técnico:**
- Servidor: migración `20261101000046_opiniones.sql`, con `opinion_enviar` (anónima) y `opiniones_autor`. Prueba: `pruebas/opiniones.sql`.
- Kit: `kit/rate.gd` y `kit/ui/screens/rate_panel.gd`. Prueba del kit: `--solo=rate`.

## 4. Modo clase (para profes)

Un profe crea un juego (por ejemplo de palabras, de preguntas o de cálculo), crea una **clase** en la app y dicta el **código de 6 letras**. Cada alumno lo escribe en el juego con su nombre de pila o un apodo, y el profe ve cómo va cada uno.

**En la app:** pestaña *Jugadores* → *Modo clase*.
- *Crear clase* (por ejemplo «3º B») genera un código sin letras que se confundan: ni O ni 0, ni I ni 1.
- Cada clase muestra una tabla con alumno, niveles superados, estrellas, minutos y última vez, y un resumen (media de niveles y cuántos lo han terminado).
- **Quién se atasca**: la tabla dice en qué nivel está cada alumno y avisa (en naranja) si lleva 5 intentos o más en el mismo.
- **Descargar notas (CSV)** para pasarlo a la hoja de notas (con nivel actual e intentos).
- **Vaciar para otro trimestre**: borra los alumnos y mantiene el código (pide confirmación).
- *Cerrar clase* borra la clase y sus alumnos.
- Hasta 10 clases por juego y 60 alumnos por clase.

**En el juego:** *Ajustes → Clase*. El alumno escribe el código y su nombre. Al superar cada nivel, el profe recibe los niveles, estrellas y minutos.

**Plantillas «Para clase»** en el taller: tablas de multiplicar, capitales del mundo, vocabulario en globos, forma palabras y parejas de ciencias. Al elegir *Para mi clase* se abren solas. Las cinco se fabrican y los bots las superan.

**Privacidad:** no se piden correos ni ningún dato personal, solo el apodo que escribe el alumno. Este apodo pasa el mismo filtro de palabrotas que las clasificaciones. `game.json -> "clase": false` quita la opción.

**Técnico:**
- Servidor: migración `20261101000047_modo_clase.sql`.
  - El profe usa `clase_crear`, `clase_cerrar` y `clases_autor`.
  - El juego usa `clase_unirse` y `clase_progreso`. El progreso nunca baja.
  - Prueba: `pruebas/modo_clase.sql`.
- Kit: `kit/classroom.gd` y `kit/ui/screens/class_panel.gd`. Prueba del kit: `--solo=classroom`.
- App: `src/clase.ts`, con prueba en `pruebas/clase.mjs`.

## 5. En el ordenador: itch.io

Cualquier juego con versión para el navegador se puede descargar como **paquete HTML5** (un .zip con `index.html`, el motor y el juego) y subirlo a **itch.io**, la tienda de juegos indie para PC, o a tu propia web.

**En la app:** pestaña *Compartir* → *En el ordenador (itch.io)* → **Descargar para itch.io**. El enlace de descarga dura 1 día. Los pasos en itch.io:
1. Crea una cuenta y pulsa *Upload new project*.
2. En *Kind of project* elige **HTML** y sube el .zip.
3. Marca *This file will be played in the browser* y pon el tamaño 405 × 720 o *Mobile friendly*.
4. Elige el precio: gratis, de pago o con donativos.

El paquete usa el motor sin hilos, así que **no necesita cabeceras especiales** y funciona en itch.io tal cual. Lo hemos comprobado arrancando un juego real en Chromium.

**Técnico:**
- Función `paquete-itch`: junta el motor del bucket `motor` (`ORQ_MOTOR`, por defecto `godot/4.6.3`) y el `index.pck` de la última versión, sube el zip a `juegos/<usuario>/itch/` y devuelve un enlace firmado.
- Lógica en `_shared/itch.ts` (zip sin dependencias). Prueba: `pruebas/itch.mjs`, que abre el zip con `unzip`.
