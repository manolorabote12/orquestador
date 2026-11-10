# Poner Orquestador en marcha (de cero a Google Play)

El código ya está terminado y probado. Ahora hay que conectarlo a **tus** cuentas y subirlo a
Google Play. Casi todo lo hace un solo programa, `conectar.py`. A ti te quedan dos cosas que
nadie puede hacer por ti: crear las cuentas (con tu tarjeta) y rellenar Play Console.

Tiempo: 1 hora de tu parte y otra hora de espera mientras se despliega.

## 1. Crea las cuentas (30 min)

| Cuenta | Para qué | Coste | Qué apuntar |
|---|---|---|---|
| [GitHub](https://github.com) | Guarda el código, compila la app y lo despliega todo | Gratis | — |
| [Supabase](https://supabase.com) → New project (región Frankfurt) | Usuarios, tuercas y juegos | Gratis para empezar | Project URL, anon key, service_role key y contraseña de la base de datos. En **Account → Access Tokens**, un token (`sbp_…`) |
| [Anthropic](https://console.anthropic.com) | La IA que diseña los juegos | Pago por uso | API key (`sk-ant-…`). En **Limits**, pon un límite mensual (por ejemplo 20 $) |
| [RunPod](https://runpod.io) | La fábrica y las GPUs, que se apagan solas si no hay trabajo | Recarga 10 $ | API key, con permiso de lectura y escritura |
| Token de GitHub | Para que RunPod descargue tus imágenes privadas | Gratis | **Settings → Developer settings → Tokens (classic)**. Marca **solo** `read:packages` |
| [Google Play Console](https://play.google.com/console) | Publicar la app | 25 $, un solo pago | Tarda 1 o 2 días en verificar tu identidad: **créala ya** |
| [AdMob](https://admob.google.com) (opcional) | Anuncios con premio | Gratis | Se puede dejar para después |

## 2. Instala tres programas en el PC (10 min)

- [Python](https://www.python.org/downloads/): al instalar, marca **Add python.exe to PATH**.
- [Git](https://git-scm.com/downloads).
- [GitHub CLI](https://cli.github.com).

Después abre **PowerShell** y escribe:

```powershell
gh auth login
```

Elige GitHub.com → HTTPS → **Login with a web browser**.

## 3. Lanza `conectar.py` (5 min tuyos, luego espera)

1. Descomprime `orquestador-completo.zip` en una carpeta, por ejemplo `Documentos\orquestador`.
2. En PowerShell:

```powershell
cd $HOME\Documents\orquestador
python conectar.py
```

Te va pidiendo las claves una a una y te dice dónde está cada una. Después hace esto solo:

- **Comprueba cada clave contra su servicio** antes de tocar nada. Si una está mal pegada (por
  ejemplo, la clave secreta en lugar de la pública), te lo dice y para.
- **Crea lo que no tiene que darte nadie:**
  - la llave de subida de la app para Google Play;
  - el secreto que cifra las llaves de tus usuarios;
  - la cuenta para el revisor de Google.
- **Crea tu repositorio privado en GitHub** y guarda ahí todos los secretos. Nunca van en el
  código ni en la app.
- **Publica la web obligatoria** (privacidad, términos y borrar cuenta). Con una cuenta gratis
  de GitHub va en un repositorio público aparte que **solo** contiene la web.
- **Configura el correo de Supabase** para que mande el código de 6 cifras con el que se entra
  en la app.
- **Sube el código.** GitHub despliega la nube: imágenes, RunPod, modelos, base de datos y
  funciones. Tarda 30-60 minutos la primera vez.
- **Compila la app** y deja el `.aab` firmado en `salida\`, junto con
  `salida\SIGUIENTES-PASOS.txt`.

Si se corta o cierras la ventana, vuelve a lanzarlo: sigue donde se quedó y no duplica nada.
Las claves quedan en `conectar.env` y lo generado en la carpeta `.conectar\`. Las dos están fuera
de git.

> **Importante:** copia la carpeta `.conectar\` a un sitio seguro (un gestor de contraseñas o
> un USB). La llave de subida y `ORQ_LLAVES_SECRETO` no se pueden recuperar. El archivo
> `.conectar\GUARDA-ESTO.txt` explica qué es cada cosa.

## 3b. Comprueba que todo funciona

Cuando termine el despliegue, lanza:

```powershell
python conectar.py --revisar
```

Revisa de punta a punta sin cambiar nada:

- los secretos de GitHub y el resultado de cada despliegue;
- la web publicada con tus datos;
- la base de datos, las funciones y el motor web de Godot;
- el correo con el código;
- que el revisor de Google puede entrar;
- los tres endpoints de RunPod.

Cada fallo dice cómo arreglarlo. Si un despliegue falló, guarda el final de su registro en
`salida\fallo-<nombre>.txt` para que me lo pases tal cual. Además, si algún secreto está mal
pegado, el despliegue se para en el primer minuto y dice cuál es, en lugar de fallar a los 40
minutos.

## 4. Google Play Console (30 min)

Sigue `salida\SIGUIENTES-PASOS.txt`. Ya lleva tus datos: la URL de privacidad y el correo y el
código del revisor. Es esto:

1. **Crear app.** Nombre: «Orquestador: creador de juegos». Gratis.
2. **Prueba interna.** Sube el `.aab` y acepta la firma de apps de Google Play.
3. **Ficha de la tienda.** Textos de `app\tienda\ficha.json` e imágenes de `app\assets\play\` y
   `app\tienda\capturas\`.
4. **Contenido de la aplicación.** Privacidad, acceso para el revisor, anuncios, público de 16
   años o más y seguridad de los datos (la tabla está en `LANZAR-APP-LEEME.md`).
5. **Productos.** `tuercas_300`, `tuercas_1100`, `tuercas_3600` y la suscripción
   `premium_mensual`.
6. **Cuentas personales nuevas.** Google exige una prueba cerrada con 12 probadores durante 14
   días antes de pasar a producción.

## 5. Probarlo de verdad

Instala el APK de prueba de `salida\` en tu móvil (o entra desde la prueba interna), crea una
cuenta con tu correo y encarga un juego. `PRUEBA-REAL.md` tiene la lista completa para probarlo
con dos móviles.

## Si algo falla

- `python conectar.py --revisar` te dice qué parte falla y guarda el registro del error.
- `conectar.py` siempre explica qué falla y cómo arreglarlo. Corrige `conectar.env` y vuelve a
  lanzarlo.
- Si falla algo en GitHub (pestaña **Actions** del repositorio), abre la ejecución en rojo,
  copia el final del registro y pásamelo.
- Para cambiar una clave más adelante, edítala en `conectar.env` y vuelve a lanzar
  `python conectar.py`.
