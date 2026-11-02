# Orquestador: Paso 1 (versión móvil)

App Android (Play Store) que crea juegos 2D con IA en la nube, los compila y ayuda a publicarlos.
Stack: Vite + TypeScript, empaquetado con Capacitor. Backend: Supabase + trabajadores en la nube.

## 1. Requisitos en Windows (una sola vez)

PowerShell **como administrador**:

```powershell
winget install OpenJS.NodeJS.LTS
winget install Google.AndroidStudio
```

Abre Android Studio una vez y deja que instale el **Android SDK** y un emulador
(More Actions > Virtual Device Manager > crea un Pixel con Android reciente).
Android Studio ya trae su propio JDK.

Cierra y reabre la terminal y comprueba:

```powershell
node -v
npm -v
```

## 2. Crear el proyecto

```powershell
cd C:\dev
npm create vite@latest orquestador -- --template vanilla-ts
cd orquestador
npm install
```

Si el asistente te hace alguna pregunta, deja las opciones por defecto; si ofrece
arrancar el servidor ahora, responde que no.

Limpia los archivos de ejemplo de la plantilla:

```powershell
del src\counter.ts, src\style.css, src\typescript.svg
```

Copia los archivos que te entrego:

- `index.html`  (raíz del proyecto, sustituye al existente)
- `src/styles.css`  (nuevo)
- `src/main.ts`  (sustituye al existente)

Prueba en el navegador (F12 > icono de móvil para verlo en vertical):

```powershell
npm run dev
```

## 3. Añadir Capacitor y Android

```powershell
npm install @capacitor/core
npm install -D @capacitor/cli
npx cap init "Orquestador" com.daniel.orquestador --web-dir dist
npm install @capacitor/android
npm run build
npx cap add android
npx cap sync
npx cap open android
```

En Android Studio pulsa **Run** para abrirla en el emulador o en tu móvil
(con depuración USB activada).

Ciclo de trabajo diario: cambias código, `npm run build`, `npx cap sync`, Run.
Para el día a día, `npm run dev` en el navegador es lo más rápido.

## 4. Dependencias de los siguientes pasos (aún no)

```powershell
npm install @supabase/supabase-js                 # Cuentas, créditos, proyectos
npm install @capacitor-community/admob            # Anuncios bonificados = créditos gratis
npm install @capacitor/preferences                # Ajustes locales
# Google Play Billing: plugin de compras integradas (paso Créditos)
```

## 5. Estructura objetivo

```
orquestador/
├─ index.html
├─ package.json
├─ vite.config.ts
├─ capacitor.config.ts
├─ src/                          # App móvil (Vite + TS)
│  ├─ main.ts                    # Arranque, router y vistas (paso 1: todo aquí)
│  ├─ styles.css                 # Tokens de diseño + componentes
│  ├─ views/                     # (paso 2) se separan las vistas
│  │  ├─ factoria.ts
│  │  ├─ lanzadera.ts
│  │  └─ ajustes.ts
│  ├─ services/
│  │  ├─ api.ts                  # Crear trabajos y consultar su estado
│  │  ├─ credits.ts              # Saldo, compras, anuncios bonificados
│  │  └─ supabase.ts             # Cliente Supabase
│  └─ state/
│     └─ store.ts                # Estado global (usuario, proyecto, saldo)
├─ android/                      # Generado por Capacitor (no editar a mano)
├─ supabase/                     # Backend
│  ├─ migrations/                # Tablas: usuarios, proyectos, créditos, trabajos, denuncias
│  └─ functions/
│     ├─ create-job/             # Cobra créditos ANTES y encola el trabajo
│     ├─ billing-webhook/        # Confirma compras de Google Play
│     └─ report-content/         # Denuncias de contenido IA (exigido por Google)
├─ workers/                      # Trabajadores en la nube (Docker)
│  ├─ gen-design/                # LLM: prompt -> JSON del juego
│  ├─ gen-media/                 # GPU bajo demanda: arte, música, voces
│  └─ build-godot/               # Godot sin pantalla + SDK Android -> .aab firmado
└─ templates/                    # Plantillas Godot por género (leen el JSON)
   ├─ arcade/
   ├─ plataformas/
   └─ puzle/
```

## Reglas de oro

1. La app nunca guarda claves de API: todo pasa por funciones de Supabase.
2. Los créditos se cobran en el servidor **antes** de ejecutar un trabajo, nunca en la app.
3. Cada acción cuesta entre 3 y 5 veces su coste real, más la comisión de Google.
4. Solo modelos con licencia comercial (revisar antes de integrar cualquiera).
5. Botón de denunciar contenido generado desde el primer día.
