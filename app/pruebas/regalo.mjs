// Juego regalo: las reglas de la app son las del servidor y el autor sabe qué ha pasado.
let fallos = 0;
const check = (n, ok, d = "") => { console.log((ok ? "  OK   " : "  FALLO ") + n + (ok ? "" : `  (${d})`)); if (!ok) fallos++; };
const { validarRegalo, mensajeRegalo, OCASIONES, estadoRegalo } = await import("./.regalo.mjs");

const base = { para: "Lucía", de: "Dani", mensaje: "Feliz cumple", tras_nivel: 0 };
check("regalo normal: vale", validarRegalo(base) === "");
check("sin nombre: no", validarRegalo({ ...base, de: " " }) === mensajeRegalo("bad_name"));
check("nombre largo: no", validarRegalo({ ...base, para: "x".repeat(21) }) === mensajeRegalo("bad_name"));
check("mensaje con etiquetas: no", validarRegalo({ ...base, mensaje: "<script>" }) === mensajeRegalo("bad_message"));
check("mensaje de 400 sí, de 401 no", validarRegalo({ ...base, mensaje: "a".repeat(400) }) === "" && validarRegalo({ ...base, mensaje: "a".repeat(401) }) !== "");
check("nivel 0 a 50", validarRegalo({ ...base, tras_nivel: 50 }) === "" && validarRegalo({ ...base, tras_nivel: 51 }) !== "");
check("todas las ocasiones valen", OCASIONES.every((o) => validarRegalo({ ...base, mensaje: o.mensaje }) === ""));
const ahora = new Date("2026-11-03T12:00:00Z");
check("estado: sin abrir", estadoRegalo(base, ahora).includes("Aún no lo ha abierto"));
check("estado: abierto ayer", estadoRegalo({ ...base, abierto_en: "2026-11-02T10:00:00Z" }, ahora).includes("ayer"));
check("estado: leído", estadoRegalo({ ...base, abierto_en: "2026-11-01T10:00:00Z", leido_en: "2026-11-01T11:00:00Z" }, ahora).includes("ya ha leído"));
console.log(fallos ? `== ${fallos} fallos ==` : "== 0 fallos ==");
if (fallos) process.exit(1);
