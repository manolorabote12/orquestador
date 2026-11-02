# Prueba en real: de la nube a dos móviles

Todo lo de Orquestador está probado con servidores simulados (más de 600 pruebas en verde). Esta
lista es para comprobarlo **con tus cuentas de verdad**, en este orden. Cada bloque dice qué
mirar para saber que funciona. Si algo falla, copia el mensaje de error y me lo pasas.

Tiempo total: unas 2 horas la primera vez (casi todo esperando a que algo se suba o se compile).

## 1. Supabase (20 min)

1. En la carpeta del proyecto: `npx supabase link --project-ref TU_PROYECTO` y luego
   `npx supabase db push`. Tienen que aplicarse las 26 migraciones sin error.
2. Despliega las funciones (lista completa en `SETUP-backend.md`). Las nuevas:
   `npx supabase functions deploy juego-compra --no-verify-jwt`, `play-resenas`, `heroe-dibujo` y `ganchos`.
3. Panel de Supabase → **Realtime → Settings**: deja permitido el acceso público a los canales.
4. Comprueba: en *Database → Tables* existen `nube_partidas`, `juego_compras`, `juego_eventos`,
   `liga_ataques` (con la columna `repeticion`) y `arena_salas` (con la columna `modo`).

## 2. Secretos (10 min)

En Supabase (*Edge Functions → Secrets*) y en GitHub (*Settings → Secrets*), los de `SETUP.md`.
Los imprescindibles para hoy: `ANTHROPIC_API_KEY`, `RUNPOD_API_KEY`, `ORQ_PLAY_CUENTA` y la clave
`service_role` (solo en el trabajador, nunca en la app).

## 3. La fábrica en RunPod (30 min, casi todo esperando)

1. GitHub → *Actions* → «desplegar» → *Run workflow*. Construye la imagen de la fábrica.
2. En el registro de la construcción busca estas tres líneas:
   - `AdMob Android: listo`
   - `Compras (Google Play Billing): listo`
   - `Avisos (NotificationScheduler): listo`
   Si alguna dice `AVISO`, los juegos salen sin esa parte (no se rompen), pero pásame el registro.
3. Desde la app, crea un juego cualquiera (por ejemplo «Un solitario de cartas en un casino
   pirata»). Debe terminar en «está listo» y abrirse en el navegador de la app.

## 4. Google Play (30 min)

1. Play Console → el juego → *Usuarios y permisos*: la cuenta de servicio de Orquestador con
   «Publicar», **«Ver información financiera»** (para comprobar compras) y **«Responder a
   reseñas»** (para contestar desde la app).
2. *Configuración → Perfil de pagos*: créalo si quieres vender dentro del juego.
3. Desde la app: *Publicar en Google Play → Subir*. Al terminar, en Play Console →
   *Monetizar → Productos → Productos de compra única* deben aparecer los 4 productos (500
   monedas, 3000 monedas, Pase premium, Sin anuncios).
4. *Pruebas → Prueba interna*: añade tu correo y el de otro móvil como probadores y
   **también en «Testers con licencia»** (*Configuración → Pruebas de licencias*): así las compras
   de prueba no cobran.

## 5. Dos móviles (40 min)

Instala el juego desde el enlace de prueba interna en **dos móviles** (A y B). Usa un juego de
**arena** para el punto 5.3 y uno de **aldea** para el 5.4 (o fabrica uno de cada).

1. **Avisos**: en A, supera el primer nivel. Debe pedir permiso de notificaciones. Acepta, cierra
   el juego y cambia la hora del móvil a mañana a las 18:05: debe llegar «¡Tu premio diario te
   espera!».
2. **Pasar a otro móvil**: en A, gana monedas, ve a *Ajustes → Pasar a otro móvil → Guardar en la
   nube*. Apunta el código y el PIN. En B, *Ajustes → Pasar a otro móvil*: escríbelos y pulsa
   «Recuperar». B debe tener las monedas y los niveles de A.
3. **Arena cooperativa**: en A, *Arena online → Modo: cooperativo → Sala con amigos*. En B, escribe
   el código y «Unirme». A pulsa «Empezar». Los dos en el mismo equipo contra 3 oleadas: vuestros
   disparos no se hacen daño entre vosotros y la oleada siguiente sale en los dos a la vez.
4. **Repeticiones**: en A y B, *Mi aldea → Liga* (las dos aldeas se suben solas). A busca rival
   hasta que le toque la aldea de B y la asalta. En B, *Liga → Te han atacado → Ver repetición*:
   debe verse el mismo asalto con el mismo resultado.
5. **Compras**: en A, *Tienda → 500 monedas*. Sale la ventana de Google (como probador con
   licencia, «tarjeta de prueba»). Al pagar, las monedas suben **unos segundos después** (el
   servidor la comprueba). En la app, *Jugadores → Ingresos y jugadores* debe contar la venta
   (al día siguiente sale en la gráfica).
6. **Misiones y pase**: juega 3 o 4 niveles. El botón «Misiones» del título muestra premios por
   cobrar.
7. **Eventos**: en la app, *Jugadores → Eventos en directo → Regalo de monedas → Programar*.
   Cierra y abre el juego: franja en el título y botón «Recoger». En el móvil B también (una vez).

## 6. Lo nuevo de la app (15 min)

1. **Plantillas**: en *Taller → Empieza con una plantilla de éxito*, cambia el tema de
   «Saltos por los tejados» y pulsa «Usar». Fabrica: el juego sale de plataformas aunque cambies
   el tema.
2. **Tu dibujo**: en un juego, *Taller → Tu dibujo como protagonista*, haz una foto a un dibujo
   (no a una persona). Chispa la revisa y propone el cambio; al aplicarlo, el héroe nuevo se
   parece a tu dibujo. Prueba también con una foto tuya: tiene que decir que no.
3. **Prueba A/B**: *Jugadores → Prueba A/B de un nivel*, elige un nivel y «Más fácil». Sube esa
   versión a prueba interna: la mitad de los móviles jugará la B. Con 30 jugadores en cada una la
   app dice cuál va mejor.
4. **Reseñas**: cuando alguien escriba una reseña con texto, *Jugadores → Reseñas de Google
   Play → Que Chispa la proponga → Enviar respuesta*. Debe verse en la ficha de Google Play.
5. **Ganchos y giros**: escribe «un pulpo cocinero» y pulsa «Proponme 3 ideas originales». Elige
   una y fabrícala: el juego trae su mezcla o su giro (por ejemplo, golf de monstruos). En un
   juego ya hecho, *Taller → Giros y mezclas*, enciende «A oscuras» y guarda. En el título del
   juego aparece «Reto»: nivel con giro sorpresa y 50 monedas una vez al día.
6. **Invitar**: *Tuercas → Invita a tus amigos*. Con otra cuenta nueva, escribe el código y
   fabrica un juego: las dos cuentas suben 30 tuercas.

## 7. Si algo falla

- *Las compras se quedan «pendientes» o no suben las monedas*: casi siempre falta el permiso
  «Ver información financiera» (paso 4.1) o el paquete del juego no coincide.
- *No llegan avisos*: el móvil tiene el ahorro de batería agresivo; prueba con el juego fuera
  de la optimización de batería.
- *La arena no empieza o se corta*: revisa el paso 1.3 (Realtime) y que los dos móviles tengan
  internet. Con mala red, a los 6 s sin señal un jugador cuenta como desconectado.
- *La repetición no sale*: solo se guarda si el asalto terminó con internet.
- *Las reseñas dicen «Falta el permiso»*: añade «Responder a reseñas» a la cuenta de servicio
  (paso 4.1). Google solo enseña las reseñas con texto de los últimos 7 días.
- *El dibujo no sube*: tiene que ser PNG, JPG o WEBP de menos de 4 MB (la app lo reduce sola).
