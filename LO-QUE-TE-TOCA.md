# Lo que te toca a ti (y solo a ti)

Todo lo que se podía programar y probar sin tus cuentas está hecho y probado:
- la fábrica: 110 géneros, bots que juegan cada nivel antes de entregarlo y reglas programables;
- la app: taller, «Probar» antes de fabricar, camino a Google Play, Lanzadera y ganancias;
- la nube y el despliegue automático;
- el marketing y las pruebas de seguridad.

Lo que queda necesita **tu tarjeta, tu identidad o tus manos**. Va en orden.

## 1. Cuentas (30 min, una vez)
Lista completa, con qué apuntar de cada una, en `PONER-EN-MARCHA.md`, punto 1:

| Cuenta | Coste |
|---|---|
| GitHub | gratis |
| Supabase | gratis |
| Anthropic (pon un límite mensual) | pago por uso |
| RunPod | recarga de 10 $ |
| Google Play Console | 25 $, un solo pago. **Créala hoy: Google tarda 1-2 días en verificarte** |
| AdMob | gratis, se puede dejar para después |

## 2. Conectar (5 min tuyos + 1 h de espera)
En el PC, con Python, Git y GitHub CLI instalados:

```
python conectar.py            (te pide las claves una a una y lo despliega todo)
python conectar.py --revisar  (cuando acabe: comprueba cada pieza y dice cómo arreglar lo que falle)
```

Guarda la carpeta `.conectar\` en un sitio seguro: la llave de subida y el secreto de cifrado no se
pueden recuperar.

Después del primer despliegue, GitHub fabrica solo las **partidas de muestra** del botón «Probar»:
- son 109 juegos, uno por cada género que tiene muestra; el primero de la lista, el «a medida», no la tiene;
- la primera vez tarda unas horas y gasta algo de GPU en RunPod;
- mientras tanto, el botón solo sale en los géneros que ya tienen la suya.

## 3. Google Play Console (30 min)
Sigue `salida\SIGUIENTES-PASOS.txt`: ya lleva tus datos. Los pasos son crear la app, prueba interna con el `.aab`,
ficha de la tienda, contenido de la aplicación (tabla de seguridad de datos en `LANZAR-APP-LEEME.md`),
productos de tuercas y los dos planes (`plan_taller` y `plan_pro`, con planes base `mensual` y `anual`;
detalles en `LANZAR-APP-LEEME.md`, punto 5).

En **Configuración → Perfil de pagos** pon tus datos fiscales; sin ellos no se cobra nada.

## 4. Los 12 probadores de TU app (14 días)
Orquestador también es una app nueva de una cuenta personal: Google pide **12 probadores durante 14
días seguidos** antes de producción. La Lanzadera no te sirve aquí, porque todavía no hay usuarios.
- Pide ayuda a familia, amigos o compañeros con Android. Cuenta con 15 o 16 por si alguien lo deja.
- Crea un Grupo de Google abierto y añádelo como probadores en Play Console → Prueba cerrada.
- Recuérdales abrirla un rato cada día: Google comprueba que de verdad la usan.
- Al acabar, pide producción en el Panel de Play Console. Las preguntas que hace Google son las mismas
  que la app responde para los juegos de tus usuarios (Lanzadera → Mis campañas → «Respuestas para pedir
  producción»): úsalas de modelo.

## 5. Probarlo de verdad en el móvil (1 tarde)
Nadie lo ha usado aún en un móvil real. `PRUEBA-REAL.md` tiene la lista para hacerlo con dos móviles.

Lo nuevo de estos días que más conviene mirar:
- **«Probar»** en el catálogo;
- **«Camino a Google Play»** en la ficha de un juego;
- **«¿Cuánto podría ganar?»**;
- la **Lanzadera** con dos cuentas: unirse, check-in, aviso de las 19:00 y respuestas de producción;
- el **Reto del día** (pasa el nivel 1 y vuelve al día siguiente para ver la racha) y la barra «Tú contra el rival» en ajedrez, reversi, damas y conecta 4;
- los géneros nuevos: cartas coleccionables, gemas y héroes, batalla automática, estrategia por turnos, Simón dice, hundir la flota, ahorcado con globos, deslizar, buscar objetos, reversi, ajedrez, arquero, cartas locas, dominó, bloques de colores, 2048, tuberías y diferencias.

Si algo se ve mal o falla, apúntalo con una captura y me lo pasas tal cual.

## 6. AdMob (cuando la app ya funcione)
1. Crea la cuenta y la app «Orquestador» en AdMob.
2. Crea un bloque **bonificado** y pega su id cuando `conectar.py` lo pida (o vuelve a lanzarlo).
3. Cada usuario pone **sus** ids en cada juego (Publicar → Anuncios): la app le explica cómo.
4. **Galería (pestaña Jugar)**: crea un bloque **intersticial** llamado «Galería entre partidas» y pon
   su id en GitHub → Settings → Secrets and variables → Actions → **Variables** →
   `ORQ_APP_ADMOB_GALERIA`. Vuelve a lanzar «App Android». Sin él, la galería funciona sin anuncios.

## 6b. Reparto a los creadores (cada mes, 2 minutos)
1. A principios de mes, mira en AdMob → Informes cuánto pagó el bloque «Galería entre partidas» el mes
   anterior.
2. GitHub → Actions → **«Galería: reparto y cobros»** → `repartir`, con el mes (`2026-11`) y esos euros.
   Se reparte el 50 % entre los creadores según los anuncios vistos en sus juegos.
3. **Cobros en dinero** (cuando estés dado de alta para pagar a otros; consúltalo con un gestor):
   pídeme abrirlos (`cobro_dinero_activo = 1`). Cada mes, la acción `estado` te lista a quién pagar
   por PayPal y cuánto; al pagarlo, márcalo con `pagado` y el número del cobro. Si un PayPal está
   mal, `rechazado`: el dinero vuelve a su saldo. Hasta entonces, los creadores pasan su saldo a
   tuercas (1 € = 150 tuercas).

## 7. Marketing (opcional, cuando quieras)
Sin estas claves, esa red simplemente no se usa. Son secretos de GitHub y la lista está en `MARKETING-LEEME.md`:
- Bluesky (contraseña de aplicación);
- Mastodon;
- Telegram (bot, canal y tu chat para los borradores);
- Discord (webhook);
- X;
- Reddit.

Los borradores de respuesta te llegan al Telegram y **los publicas tú**: nunca salen solos.

## Lo que no se puede automatizar (Google no lo permite por su API)
- **Experimentos de ficha** (dos iconos o capturas a la vez): a mano en Play Console → Crecimiento.
- **Pedir el acceso a producción**: es un formulario que rellena el dueño de la cuenta.
- **Responder reseñas**: la app propone la respuesta y tú la envías.

---
Cuando tengas el paso 2 hecho, pásame la salida de `python conectar.py --revisar` y lo dejamos fino.
