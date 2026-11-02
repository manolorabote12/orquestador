# Publicar Orquestador en Google Play

Todo lo que hace falta para subir la propia app (no los juegos de los usuarios: eso lo hace la fábrica).

## 0. Lo que ya está hecho
| Qué | Dónde |
|---|---|
| Icono adaptativo + splash (claro/oscuro) | `app/assets/` (se regeneran con `npm run marca`; CI los aplica con `@capacitor/assets`) |
| Icono 512 y gráfico destacado 1024x500 | `app/assets/play/` |
| 7 capturas 1080x1920 con titular | `app/tienda/capturas/` (`python3 tienda/capturas.py` tras `npm run build:demo`) |
| Textos de la ficha es-ES / en-US | `app/tienda/ficha.json` (validados: título ≤30, corta ≤80, larga ≤4000) |
| Web pública: portada, privacidad, términos, borrar cuenta | `web/` → GitHub Pages (`.github/workflows/web.yml`) |
| Borrar cuenta dentro de la app | Cuenta → Borrar mi cuenta (función `delete-account`) |
| Cuenta para el revisor de Google | función `review-login` + secreto `ORQ_REVISOR` |
| AAB firmado, versionCode automático, API 36 | `.github/workflows/app.yml` |

## 1. Configuración (una vez)
Variables del repositorio (Settings → Secrets and variables → Actions → **Variables**):

| Variable | Ejemplo |
|---|---|
| `SUPABASE_URL`, `SUPABASE_ANON_KEY` | las públicas del proyecto (la web comprueba que la clave sea `anon`) |
| `ORQ_WEB` | `https://<usuario>.github.io/<repo>` |
| `ORQ_CORREO` | correo de contacto público |
| `ORQ_RESPONSABLE` | tu nombre o el de tu empresa (aparece en privacidad y términos) |
| `ORQ_PLAY_URL` | `https://play.google.com/store/apps/details?id=com.orquestador.app` (cuando exista) |
| `ORQ_APP_ADMOB_APP_ID`, `ORQ_APP_ADMOB_PREMIO` | app y bloque "con premio" de AdMob de Orquestador |

Secretos: `ORQ_APP_KEYSTORE_B64`, `ORQ_APP_KEYSTORE_PASS` (llave de subida, alias `subida`) y
`ORQ_REVISOR` = `revision@tudominio.com:483920` (correo y código de 6 cifras para Google).

Activa GitHub Pages: Settings → Pages → Source: **GitHub Actions**, y lanza el workflow **web**.

> Por qué GitHub Pages: Supabase Storage sirve los `.html` como texto plano (salvo plan Pro con
> dominio propio). Con `ORQ_WEB` puesto, la política de privacidad de cada juego publicado pasa a
> ser `ORQ_WEB/privacidad.html?j=<id>` y se ve como página.

## 2. Play Console → Crear app
- Nombre: **Orquestador: crea tu juego** · Idioma: español (España) · App · Gratis.
- Paquete: `com.orquestador.app`.

## 3. Ficha de Play Store
Copia de `ficha.json`. Categoría: **Entretenimiento**. Icono, gráfico y capturas de `assets/play/` y `tienda/capturas/`.
Correo, web (`ORQ_WEB`) y política de privacidad (`ORQ_WEB/privacidad.html`).

## 4. Contenido de la aplicación
- **Política de privacidad**: `ORQ_WEB/privacidad.html`.
- **Acceso a la aplicación**: "Toda o parte de la funcionalidad está restringida" →
  instrucciones: *"Escribe el correo `<correo de ORQ_REVISOR>`, pulsa Enviarme el código y escribe el código `<código>`."*
- **Anuncios**: Sí (anuncios con premio de AdMob, opcionales).
- **Clasificación de contenido (IARC)**: categoría "Todas las demás app" → herramienta/creatividad.
  Contenido generado por usuarios: **sí** (los juegos y la Lanzadera); se puede denunciar contenido
  (tabla `content_reports`) y hay moderación de prompts. Compras digitales: sí.
- **Público objetivo**: 16 años o más (no dirigida a menores).
- **Seguridad de los datos**:

| Dato | ¿Se recoge? | ¿Se comparte? | Para qué | Opcional |
|---|---|---|---|---|
| Correo electrónico | Sí | No | Gestión de cuenta | No |
| ID de usuario | Sí | No | Gestión de cuenta, funcionalidad | No |
| Historial de compras | Sí | No | Funcionalidad (tuercas, premium) | Sí |
| Otro contenido generado por el usuario (ideas, juegos) | Sí | No* | Funcionalidad | No |
| ID de publicidad / interacciones con anuncios | Sí (SDK de AdMob) | Sí (Google) | Publicidad | Sí (solo si ve anuncios) |
| Registros de fallos / diagnóstico | Sí (SDK de AdMob) | No | Análisis | — |

\* Los proveedores que procesan por nuestra cuenta (Anthropic, RunPod, Supabase) son *encargados*, no "compartir" según Google.
Cifrado en tránsito: **sí**. Se puede pedir el borrado: **sí** → URL `ORQ_WEB/borrar-cuenta.html`.

- **Funciones financieras / salud / gobierno**: no.
- **Permisos**: solo Internet y los de AdMob/Billing (`AD_ID`: declararlo como "Publicidad").

## 5. Productos (Monetizar → Productos)
Productos integrados (consumibles): `tuercas_300`, `tuercas_1100`, `tuercas_3600`.
Suscripción: `premium_mensual` (plan base mensual, renovación automática).
Los ids deben coincidir con `store_products`; los precios los pones aquí.
Da a la cuenta de servicio `ORQ_PLAY_TIENDA_CUENTA` el permiso "Ver datos financieros" y
"Gestionar pedidos y suscripciones".

## 6. Subir
1. Lanza **app** en GitHub Actions → descarga el `.aab` del artefacto.
2. Prueba interna → sube el `.aab` → revisa.
3. Cuentas personales nuevas: prueba cerrada con 12 probadores 14 días antes de producción.
4. Producción.

## 7. Comprobaciones antes de enviar
- [ ] `ORQ_WEB/privacidad.html`, `/terminos.html` y `/borrar-cuenta.html` abren y muestran tu correo.
- [ ] Entras con la cuenta del revisor en la app instalada.
- [ ] Cuenta → Privacidad abre las páginas; en el EEE aparece "Consentimiento de anuncios".
- [ ] Comprar `tuercas_300` con una cuenta de prueba de licencias suma tuercas y se consume.
- [ ] Borrar una cuenta de prueba la deja fuera y sus archivos desaparecen del almacén.
