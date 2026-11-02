// Errores de la app: un solo sitio que decide qué ve la persona cuando algo falla.
// 1 - ErrorApp: error ya explicado para la persona (lo lanza la capa de datos con su mensaje).
// 2 - Sin conexión: se reconoce aunque venga envuelto (Supabase, fetch, Capacitor) y se dice igual.
// 3 - Lo demás (fallos no previstos): el texto por defecto de cada sitio, nunca el error técnico.

export class ErrorApp extends Error {}

export const SIN_CONEXION = "Sin conexión: revisa tu red e inténtalo de nuevo.";

/** Algo falló por la red (sin conexión, servidor inalcanzable o petición cortada). */
export function esSinConexion(e: unknown): boolean {
  if (typeof navigator !== "undefined" && navigator.onLine === false) return true;
  const nombre = e instanceof Error ? e.name : "";
  const texto = e instanceof Error ? e.message : typeof e === "string" ? e : "";
  return nombre === "FunctionsFetchError" || /failed to fetch|networkerror|load failed|network request failed|err_internet_disconnected/i.test(texto);
}

/** Texto para la persona: el del ErrorApp, el de sin conexión o el que se da por defecto. */
export function mensajeError(e: unknown, porDefecto: string): string {
  // Sin red, cualquier fallo es por la red (aunque la capa de datos lo haya envuelto en ErrorApp).
  if (typeof navigator !== "undefined" && navigator.onLine === false) return SIN_CONEXION;
  if (e instanceof ErrorApp) return e.message;
  if (esSinConexion(e)) return SIN_CONEXION;
  return porDefecto;
}

/** Fallo no previsto (promesa sin catch o error de código): se avisa y se deja rastro en la consola. */
export function vigilarErrores(avisar: (texto: string) => void, consola: Pick<Console, "error"> = console): () => void {
  const promesa = (ev: PromiseRejectionEvent) => {
    consola.error("[orquestador] promesa sin atender:", ev.reason);
    avisar(mensajeError(ev.reason, "Algo ha fallado. Inténtalo de nuevo."));
  };
  const codigo = (ev: ErrorEvent) => {
    // Solo errores de código (los de imágenes o scripts que no cargan no llegan con ev.error).
    if (!(ev.error instanceof Error)) return;
    consola.error("[orquestador] error:", ev.error);
    avisar(mensajeError(ev.error, "Algo ha fallado. Si se repite, cierra y vuelve a abrir la app."));
  };
  window.addEventListener("unhandledrejection", promesa);
  window.addEventListener("error", codigo);
  return () => {
    window.removeEventListener("unhandledrejection", promesa);
    window.removeEventListener("error", codigo);
  };
}
