let fallos = 0;
const check = (n, ok, d = "") => { console.log((ok ? "  OK   " : "  FALLO ") + n + (ok ? "" : `  (${d})`)); if (!ok) fallos++; };
const { mensajeClase, haceCuanto, resumenClase, csvClase } = await import("./.clase.mjs");
const ahora = new Date("2026-11-01T12:00:00Z");
check("hace minutos, horas y días", haceCuanto("2026-11-01T11:55:00Z", ahora) === "hace 5 min" && haceCuanto("2026-11-01T09:00:00Z", ahora) === "hace 3 h" && haceCuanto("2026-10-30T12:00:00Z", ahora) === "hace 2 días");
const c = { codigo: "ABC234", nombre: "3º B", creada: "", alumnos: [
  { alias: "Lucia", niveles: 10, estrellas: 25, minutos: 40, visto: "2026-11-01T10:00:00Z" },
  { alias: "Marcos", niveles: 4, estrellas: 8, minutos: 12, visto: "2026-10-31T10:00:00Z" }] };
check("resumen", resumenClase(c, 10) === "2 alumnos · media 7.0 niveles · 1 lo han terminado", resumenClase(c, 10));
check("clase vacía", resumenClase({ ...c, alumnos: [] }, 10).startsWith("Aún"));
const csv = csvClase({ ...c, alumnos: [...c.alumnos, { alias: 'Ana;"B"', niveles: 1, estrellas: 1, minutos: 1, visto: "2026-10-01T00:00:00Z" }] });
check("csv para la hoja de notas", csv.split("\n").length === 4 && csv.includes('"Ana;""B"""') && csv.startsWith("Alumno;Niveles"));
check("errores con frase", mensajeClase("bad_name") !== mensajeClase("too_many"));
const { atasco } = await import("./.clase.mjs");
check("atasco: 5 intentos o más en su nivel", atasco({ alias: "A", niveles: 3, estrellas: 0, minutos: 0, visto: "", nivel_actual: 4, intentos: 7 }, 10) === "Atascado en el nivel 4 (7 intentos)"
  && atasco({ alias: "A", niveles: 3, estrellas: 0, minutos: 0, visto: "", nivel_actual: 4, intentos: 2 }, 10) === ""
  && atasco({ alias: "A", niveles: 10, estrellas: 0, minutos: 0, visto: "", nivel_actual: 10, intentos: 9 }, 10) === "");
check("resumen cuenta los atascados", resumenClase({ ...c, alumnos: [...c.alumnos, { alias: "X", niveles: 1, estrellas: 0, minutos: 1, visto: "", nivel_actual: 2, intentos: 6 }] }, 10).includes("1 atascado"));
console.log(fallos ? `== ${fallos} fallos ==` : "== 0 fallos ==");
if (fallos) process.exit(1);
