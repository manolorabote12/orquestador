// Errores: el mensaje que ve la persona (claro, sin texto técnico), sin conexión reconocido aunque
// venga envuelto, y los fallos no previstos avisados (no se pierden en silencio).
let fallos = 0;
const check = (n, ok, d = "") => { console.log((ok ? "  OK   " : "  FALLO ") + n + (ok ? "" : `  (${d})`)); if (!ok) fallos++; };

// Un "window" mínimo para vigilarErrores (Node no tiene navegador).
const oyentes = {};
globalThis.window = {
  addEventListener: (t, f) => { (oyentes[t] ??= []).push(f); },
  removeEventListener: (t, f) => { oyentes[t] = (oyentes[t] ?? []).filter((x) => x !== f); },
};
let enLinea = true;
Object.defineProperty(globalThis, "navigator", { configurable: true, get: () => ({ onLine: enLinea }) });

const { ErrorApp, SIN_CONEXION, esSinConexion, mensajeError, vigilarErrores } = await import("./.errores.mjs");

check("ErrorApp: se muestra su mensaje", mensajeError(new ErrorApp("Código incorrecto o caducado."), "x") === "Código incorrecto o caducado.");
check("error técnico: nunca se enseña, va el texto por defecto", mensajeError(new Error("Cannot read properties of undefined (reading 'id')"), "No se pudo abrir.") === "No se pudo abrir.");
check("cosas raras (texto, null): el texto por defecto", mensajeError("boom", "Por defecto") === "Por defecto" && mensajeError(null, "Por defecto") === "Por defecto");
check("fetch sin red (Chrome/Android): sin conexión", mensajeError(new TypeError("Failed to fetch"), "x") === SIN_CONEXION);
check("fetch sin red (Safari/iOS): sin conexión", mensajeError(new TypeError("Load failed"), "x") === SIN_CONEXION);
const f = new Error("Failed to send a request to the Edge Function");
f.name = "FunctionsFetchError";
check("función del servidor inalcanzable: sin conexión", esSinConexion(f) && mensajeError(f, "x") === SIN_CONEXION);
check("un error de servidor normal no es sin conexión", !esSinConexion(new Error("permission denied for table jobs")));
enLinea = false;
check("móvil sin red: sin conexión aunque la capa de datos lo envolviera en ErrorApp",
  mensajeError(new ErrorApp("No se pudieron cargar tus juegos."), "x") === SIN_CONEXION);
enLinea = true;

// Fallos no previstos: se avisan con texto claro y quedan en la consola.
const avisos = [];
const consola = [];
const dejar = vigilarErrores((t) => avisos.push(t), { error: (...a) => consola.push(a) });
oyentes.unhandledrejection.forEach((h) => h({ reason: new ErrorApp("No se pudo guardar.") }));
oyentes.unhandledrejection.forEach((h) => h({ reason: new Error("x is not a function") }));
oyentes.error.forEach((h) => h({ error: new TypeError("Failed to fetch") }));
oyentes.error.forEach((h) => h({ error: null, message: "Script error." }));
check("promesa sin catch con ErrorApp: su mensaje", avisos[0] === "No se pudo guardar.");
check("promesa sin catch con error técnico: texto claro, no el técnico", avisos[1] === "Algo ha fallado. Inténtalo de nuevo.", avisos[1]);
check("error de código por la red: sin conexión", avisos[2] === SIN_CONEXION);
check("errores sin objeto (imágenes, scripts de fuera): no molestan", avisos.length === 3, String(avisos.length));
check("todo queda en la consola para depurar", consola.length === 3);
dejar();
check("se puede dejar de vigilar", (oyentes.unhandledrejection ?? []).length === 0 && (oyentes.error ?? []).length === 0);

console.log(`== ${fallos} fallos ==`);
process.exit(fallos ? 1 : 0);
