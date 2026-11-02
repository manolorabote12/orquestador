// Reglas del plan de cambio en el servidor (las mismas que el taller de la fabrica): vista 3D.
import { costePlan, girosDe, problemasMapa, reglaGenero, validarPlan, vistaDe, PRECIOS_CAMBIO } from "./.plan.mjs";

let fallos = 0;
const check = (n, ok, d = "") => { console.log((ok ? "  OK   " : "  FALLO ") + n + (ok ? "" : "  " + d)); if (!ok) fallos++; };
const sinEsquema = () => [];
const diseno = (genero, extra = {}) => ({ titulo: "T", niveles: ["a", "b", "c"], enemigos: [{ tipo: "walker", nombre: "W", descripcion: "w" }], genero, ...extra });
const plan = (...operaciones) => ({ resumen: "r", operaciones });

check("carreras nace en 3D", vistaDe(diseno("carreras"), "carreras") === "3d");
check("plataformas nace en 2D", vistaDe(diseno("plataformas"), "plataformas") === "2d");
check("hordas siempre 2D", vistaDe(diseno("horda", { vista: "3d" }), "horda") === "2d");
check("vista 3D vale en plataformas, runner y volador", ["plataformas", "runner", "volador", "carreras"].every((g) => reglaGenero(g, { op: "vista", vista: "3d" }) === ""));
check("vista 3D no vale en hordas", reglaGenero("horda", { op: "vista", vista: "3d" }).includes("solo existe en"));
check("pasar plataformas a 3D es valido", validarPlan(plan({ op: "vista", vista: "3d" }), diseno("plataformas"), sinEsquema).length === 0);
const repe = validarPlan(plan({ op: "vista", vista: "2d" }), diseno("plataformas"), sinEsquema);
check("pedir 2D a un juego 2D: ya esta asi", repe.some((e) => e.includes("ya esta asi")), JSON.stringify(repe));
const repe3 = validarPlan(plan({ op: "vista", vista: "3d" }), diseno("carreras"), sinEsquema);
check("pedir 3D a unas carreras: ya esta asi", repe3.some((e) => e.includes("ya esta asi")), JSON.stringify(repe3));
const h = { niveles: [{ intro: [{ quien: "heroe", texto: "¡Allá voy!" }] }] };
check("historia nueva valida", validarPlan(plan({ op: "historia", historia: h }), diseno("plataformas"), sinEsquema).length === 0);
check("quitar historia que no hay", validarPlan(plan({ op: "historia", activo: false }), diseno("plataformas"), sinEsquema).some((e) => e.includes("no tiene historia")));
check("historia sin frases", validarPlan(plan({ op: "historia" }), diseno("plataformas"), sinEsquema).some((e) => e.includes("necesita")));
const prot = validarPlan(plan({ op: "historia", historia: { niveles: [{ intro: [{ quien: "heroe", texto: "Soy Mario y salto" }] }] } }), diseno("plataformas"), sinEsquema);
check("historia con nombres protegidos", prot.some((e) => e.includes("protegido")), JSON.stringify(prot));
const fila = (s) => s.padEnd(20, ".");
const bueno = [fila(""), fila(""), fila(""), fila(""), fila(""), fila(""), fila("P.....C......G"), "#".repeat(20)];
check("mapa a mano valido", validarPlan(plan({ op: "mapa", indice: 0, mapa: bueno }), diseno("plataformas"), sinEsquema).length === 0);
check("mapa sin meta", problemasMapa("plataformas", bueno.map((f) => f.replace("G", "."))).some((e) => e.includes("meta")));
check("mapa con letras raras", problemasMapa("plataformas", bueno.map((f) => f.replace("C", "Z"))).some((e) => e.includes("Z")));
check("enemigo que el juego no tiene", validarPlan(plan({ op: "mapa", indice: 0, mapa: bueno.map((f) => f.replace("C", "K")) }), diseno("plataformas"), sinEsquema)
  .some((e) => e.includes("spiky")));
check("jefe sin jefe", validarPlan(plan({ op: "mapa", indice: 0, mapa: bueno.map((f) => f.replace("C", "B")) }), diseno("plataformas"), sinEsquema)
  .some((e) => e.includes("jefe")));
check("hordas no se editan a mano", problemasMapa("horda", bueno).some((e) => e.includes("no se pueden editar")));
const q = (i) => ({ pregunta: `¿Pregunta número ${i}?`, opciones: ["a", "b", "c", "d"], correcta: 0, explicacion: "porque" });
check("convertir a preguntas sin preguntas no vale", validarPlan(plan({ op: "genero", genero: "preguntas" }), diseno("plataformas"), sinEsquema).some((e) => e.includes("al menos 3")));
check("convertir a preguntas con preguntas vale", validarPlan(plan({ op: "genero", genero: "preguntas" }, { op: "preguntas", preguntas: [0, 1, 2, 3, 4, 5, 6, 7, 8].map(q) }), diseno("plataformas"), sinEsquema).length === 0);
check("preguntas en un juego de plataformas no", validarPlan(plan({ op: "preguntas", preguntas: [0, 1, 2].map(q) }), diseno("plataformas"), sinEsquema).length > 0);
const ab = { op: "prueba_ab", indice: 1, hacia: "mas_facil" };
check("prueba A/B: empezar vale y cuesta como rehacer un nivel", validarPlan(plan(ab), diseno("plataformas"), sinEsquema).length === 0
  && costePlan(plan(ab)) === PRECIOS_CAMBIO.base + PRECIOS_CAMBIO.prueba_ab);
check("prueba A/B: terminar sin prueba no vale", validarPlan(plan({ op: "prueba_ab", ganadora: "b" }), diseno("plataformas"), sinEsquema).length > 0);
const conAb = { ...diseno("plataformas"), prueba_ab: { nivel: 1, hacia: "mas_facil", id: "n1m3" } };
check("prueba A/B: terminar vale y cuesta poco", validarPlan(plan({ op: "prueba_ab", ganadora: "b" }), conAb, sinEsquema).length === 0
  && costePlan(plan({ op: "prueba_ab", ganadora: "b" })) === PRECIOS_CAMBIO.base + PRECIOS_CAMBIO.prueba_ab_fin);
check("prueba A/B: dos a la vez no", validarPlan(plan(ab), conAb, sinEsquema).length > 0);
check("prueba A/B: no con anadir niveles", validarPlan(plan(ab, { op: "anadir_nivel", nombre: "Otro" }), diseno("plataformas"), sinEsquema).length > 0);
const dib = { op: "redibujar", que: "heroe", descripcion: "a round orange cat", referencia: "dibujo" };
check("dibujo: vale para el heroe", validarPlan(plan(dib), diseno("plataformas"), sinEsquema).length === 0);
check("dibujo: no para la moneda", validarPlan(plan({ ...dib, que: "moneda" }), diseno("plataformas"), sinEsquema).length > 0);
check("giros: oscuridad vale en plataformas", validarPlan(plan({ op: "giros", giros: ["oscuridad", "racha"] }), diseno("plataformas"), sinEsquema).length === 0);
check("giros: cola solo en laberinto", validarPlan(plan({ op: "giros", giros: ["cola"] }), diseno("plataformas"), sinEsquema).length > 0 && girosDe("laberinto").includes("cola"));
check("giros: precio", costePlan(plan({ op: "giros", giros: ["racha"] })) === PRECIOS_CAMBIO.base + PRECIOS_CAMBIO.giros);
console.log(`== ${fallos} fallos ==`);
process.exit(fallos ? 1 : 0);
