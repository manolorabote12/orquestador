// Comodidades de app grande: boton atras de Android, vibracion suave, aviso sin conexion,
// notificacion cuando el juego termina de fabricarse y pedir valoracion en Google Play una vez.
// Todo es opcional: en la web (o si un permiso se niega) la app funciona igual sin ello.

import { esNativo } from "./nativo";

// ---------------------------------------------------------------- 1 - boton atras

/** Engancha el boton atras de Android: primero cierra lo abierto (un desplegable o una ventana),
 *  luego vuelve a la pestana anterior y, en la primera, sale de la app (sin cerrarla del todo). */
export async function engancharAtras(volver: () => boolean): Promise<void> {
  if (!esNativo()) return;
  const { App } = await import("@capacitor/app");
  await App.addListener("backButton", () => {
    const abierto = document.querySelector<HTMLElement>("dialog[open], .modal:not([hidden]), details[open].cerrable");
    if (abierto) {
      if (abierto instanceof HTMLDialogElement) abierto.close();
      else if (abierto instanceof HTMLDetailsElement) abierto.open = false;
      else abierto.hidden = true;
      return;
    }
    if (!volver()) void App.minimizeApp();
  });
}

// ---------------------------------------------------------------- 2 - vibracion

let hapticos: typeof import("@capacitor/haptics") | null = null;

/** Un toque muy corto al pulsar botones y pestanas (solo en el movil). */
export async function activarVibracion(): Promise<void> {
  if (!esNativo()) return;
  hapticos = await import("@capacitor/haptics");
  document.addEventListener("click", (e) => {
    const t = (e.target as HTMLElement | null)?.closest?.("button, .tab, .chip");
    if (t && !(t as HTMLButtonElement).disabled) vibrar("suave");
  }, { capture: true, passive: true });
}

export function vibrar(tipo: "suave" | "exito" | "error"): void {
  if (!hapticos) return;
  const { Haptics, ImpactStyle, NotificationType } = hapticos;
  if (tipo === "suave") void Haptics.impact({ style: ImpactStyle.Light }).catch(() => undefined);
  else void Haptics.notification({ type: tipo === "exito" ? NotificationType.Success : NotificationType.Error }).catch(() => undefined);
}

// ---------------------------------------------------------------- 3 - sin conexion

/** Banda fija arriba cuando no hay red; desaparece sola al volver. */
export async function vigilarConexion(banda: HTMLElement): Promise<void> {
  const poner = (en: boolean) => { banda.hidden = en; };
  if (esNativo()) {
    const { Network } = await import("@capacitor/network");
    poner((await Network.getStatus()).connected);
    await Network.addListener("networkStatusChange", (s) => poner(s.connected));
    return;
  }
  poner(navigator.onLine);
  window.addEventListener("online", () => poner(true));
  window.addEventListener("offline", () => poner(false));
}

// ---------------------------------------------------------------- 4 - aviso de juego listo

let permisoPedido = false;

/** Al empezar a fabricar: pide permiso para avisar (una vez; Android 13+ lo pregunta). */
export async function prepararAvisos(): Promise<void> {
  if (!esNativo() || permisoPedido) return;
  permisoPedido = true;
  try {
    const { LocalNotifications } = await import("@capacitor/local-notifications");
    const p = await LocalNotifications.checkPermissions();
    if (p.display === "prompt" || p.display === "prompt-with-rationale") await LocalNotifications.requestPermissions();
  } catch {
    /* sin avisos: no pasa nada */
  }
}

/** Si la app esta en segundo plano, avisa en el movil de que el juego esta listo. */
export async function avisarJuegoListo(titulo: string): Promise<void> {
  if (!esNativo() || !document.hidden) return;
  try {
    const { LocalNotifications } = await import("@capacitor/local-notifications");
    await LocalNotifications.schedule({ notifications: [{
      id: Math.floor(Date.now() / 1000) % 2147483647,
      title: "¡Tu juego está listo!",
      body: `«${titulo}» ya se puede jugar y publicar.`,
    }] });
  } catch {
    /* permiso negado */
  }
}

/** Aviso de respaldo: si el sistema cierra la app mientras se fabrica, el móvil avisa igual a los
 *  ~35 minutos (lo que tarda un juego). Se cancela en cuanto la app ve el juego terminado. */
function idEspera(jobId: string): number {
  let n = 0;
  for (const c of jobId) n = (n * 31 + c.charCodeAt(0)) % 1000000;
  return 8000000 + n;
}

export async function programarAvisoEspera(jobId: string, minutos = 35): Promise<void> {
  if (!esNativo()) return;
  try {
    const { LocalNotifications } = await import("@capacitor/local-notifications");
    await LocalNotifications.schedule({ notifications: [{
      id: idEspera(jobId),
      title: "Tu juego ya debería estar listo",
      body: "Entra a verlo: si algo hubiera fallado, ya tienes tus tuercas de vuelta.",
      schedule: { at: new Date(Date.now() + minutos * 60000), allowWhileIdle: true },
    }] });
  } catch {
    /* sin permiso: la app avisa al volver */
  }
}

export async function cancelarAvisoEspera(jobId: string): Promise<void> {
  if (!esNativo()) return;
  try {
    const { LocalNotifications } = await import("@capacitor/local-notifications");
    await LocalNotifications.cancel({ notifications: [{ id: idEspera(jobId) }] });
  } catch {
    /* nada que cancelar */
  }
}

// ---------------------------------------------------------------- 4b - recordatorio de la Lanzadera

const ID_LANZADERA = 7101;

/** Probadores: un aviso a las 19:00 si hoy aún no has jugado a algún juego que pruebas (o mañana a
 *  la misma hora si ya lo hiciste). Dos días sin jugar cuentan como abandono, y esto lo evita. */
export async function recordarPruebas(pruebas: { titulo: string; dias: number; objetivo: number; hecho_hoy: boolean }[]): Promise<void> {
  if (!esNativo()) return;
  try {
    const { LocalNotifications } = await import("@capacitor/local-notifications");
    await LocalNotifications.cancel({ notifications: [{ id: ID_LANZADERA }] });
    if (!pruebas.length) return;
    const pendientes = pruebas.filter((p) => !p.hecho_hoy);
    const cuando = new Date();
    cuando.setHours(19, 0, 0, 0);
    if (!pendientes.length || cuando.getTime() <= Date.now()) cuando.setDate(cuando.getDate() + 1);
    const lista = pendientes.length ? pendientes : pruebas;
    const p0 = lista[0];
    await LocalNotifications.schedule({ notifications: [{
      id: ID_LANZADERA,
      title: lista.length > 1 ? `Hoy te toca probar ${lista.length} juegos` : `Hoy te toca probar «${p0.titulo}»`,
      body: `Juega un rato y pulsa «He jugado hoy» (día ${Math.min(p0.dias + 1, p0.objetivo)} de ${p0.objetivo}). Dos días sin jugar cuentan como abandono.`,
      schedule: { at: cuando, allowWhileIdle: true },
    }] });
  } catch {
    /* sin permiso de avisos */
  }
}

// ---------------------------------------------------------------- 5 - valoracion

const CLAVE_VALORAR = "orq-valorado";

/** Tras el primer juego fabricado (una sola vez), la ventanita de Google Play para valorar. */
export async function pedirValoracion(): Promise<void> {
  if (!esNativo()) return;
  try {
    if (localStorage.getItem(CLAVE_VALORAR)) return;
    localStorage.setItem(CLAVE_VALORAR, "1");
  } catch {
    return;
  }
  try {
    const { InAppReview } = await import("@capacitor-community/in-app-review");
    await InAppReview.requestReview();
  } catch {
    /* Google decide si la muestra: no hay nada que hacer si no */
  }
}

// ---------------------------------------------------------------- 6 - ultima pestana

const CLAVE_VISTA = "orq-vista";

export function ultimaVista<T extends string>(validas: readonly T[], defecto: T): T {
  try {
    const v = localStorage.getItem(CLAVE_VISTA) as T | null;
    return v && validas.includes(v) ? v : defecto;
  } catch {
    return defecto;
  }
}

export function recordarVista(v: string): void {
  try {
    localStorage.setItem(CLAVE_VISTA, v);
  } catch {
    /* sin almacenamiento */
  }
}
