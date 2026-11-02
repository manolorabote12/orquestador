let fallos = 0;
const check = (n, ok, d = "") => { console.log((ok ? "  OK   " : "  FALLO ") + n + (ok ? "" : `  (${d})`)); if (!ok) fallos++; };
const { USOS, infoUso } = await import("./.usos.mjs");
check("cuatro usos, publicar primero", USOS.length === 4 && USOS[0].id === "publicar");
check("cada uso lleva a su sección", infoUso("negocio").seccion === "premio" && infoUso("regalo").seccion === "regalo" && infoUso("clase").seccion === "clase");
check("uso desconocido: publicar", infoUso("x").id === "publicar" && infoUso(null).id === "publicar");
check("ejemplos de más de 15 letras (lo mínimo para fabricar)", USOS.every((u) => u.ejemplo.replace(/^Ej\.: /, "").length >= 15));
console.log(fallos ? `== ${fallos} fallos ==` : "== 0 fallos ==");
if (fallos) process.exit(1);
