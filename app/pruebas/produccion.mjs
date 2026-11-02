import { proyeccion, respuestasProduccion, temas, textoRacha, textoRespuestas } from "./.produccion.mjs";
let fallos = 0;
const ok = (n, c, extra = "") => { console.log((c ? "  OK   " : "  FALLO ") + n + (extra ? "  " + extra : "")); if (!c) fallos++; };
const pr = (dias, estado = "activo") => ({ n: 0, dias, estado });
const base = { estado: "abierta", objetivo: 12, dias: 14, completados: 0, activos: 0, abandonos: 0, opiniones: [], probadores: [] };
const hoy = new Date("2026-10-26T10:00:00Z");

let p = proyeccion({ ...base, probadores: [pr(5), pr(5), pr(3)] }, hoy);
ok("proyeccion: con pocos probadores hay riesgo y dice cuántos faltan", p.riesgo && p.faltan === 9 && p.fecha === null, JSON.stringify(p));
const doce = Array.from({ length: 12 }, (_, i) => pr(10 - (i % 3)));
p = proyeccion({ ...base, probadores: [...doce, pr(1, "abandonado")] }, hoy);
ok("proyeccion: los abandonos no cuentan; manda el más retrasado de los 12", !p.riesgo && p.dias_restantes === 6 && p.fecha === "2026-11-01", JSON.stringify(p));
p = proyeccion({ ...base, probadores: [...doce, pr(13), pr(13), pr(13), pr(13)] }, hoy);
ok("proyeccion: las reservas adelantan la fecha si van por delante", p.dias_restantes === 5, JSON.stringify(p));
p = proyeccion({ ...base, estado: "lista", probadores: doce }, hoy);
ok("proyeccion: lista = hoy", p.fecha === "2026-10-26" && p.dias_restantes === 0);
ok("racha: textos", textoRacha(0, 14) === "Empieza hoy tu racha" && textoRacha(1, 14) === "Racha de 1 día · quedan 13" && textoRacha(13, 14) === "Racha de 13 días · queda 1" && textoRacha(14, 14) === "Racha completa: 14 días");
ok("temas: palabras repetidas sin las vacías", JSON.stringify(temas(["El salto es lento", "salto raro en la cueva", "la cueva es oscura y el salto"])) === JSON.stringify(["salto", "cueva"]));
const c = { ...base, estado: "lista", completados: 12, abandonos: 3, probadores: [...doce, pr(2, "abandonado"), pr(1, "abandonado"), pr(0, "abandonado")],
  opiniones: [{ probador: 1, nivel: 4, opinion: "El nivel 4 es muy dificil" }, { probador: 2, nivel: 6, opinion: "Me encanta la musica, pero el salto es lento" }, { probador: 3, nivel: 2, opinion: "salto raro" }],
  checkins: 180, nivel_medio: 5.5, nivel_max: 8 };
const rs = respuestasProduccion(c, { titulo: "Bigotes Veloces", tipo: "plataformas", publico: "todos", cambios: ["Que el nivel 4 sea más fácil", "Salto más rápido."] });
ok("respuestas: 8 preguntas con su texto", rs.length === 8 && rs.every((r) => r.pregunta && r.respuesta.length > 20));
const t = textoRespuestas(rs);
ok("respuestas: datos reales (probadores, abandonos, check-ins, nivel)", t.includes("Se unieron 15 probadores; 12 completaron los 14 días y 3 lo dejaron") && t.includes("180 días de juego") && t.includes("nivel 5,5") && t.includes("al 8"));
ok("respuestas: opiniones citadas y temas", t.includes("«Me encanta la musica, pero el salto es lento»") && t.includes("Lo que más se repitió: salto"));
ok("respuestas: cambios hechos", t.includes("Publicamos 2 versiones nuevas durante la prueba: Que el nivel 4 sea más fácil; Salto más rápido."));
ok("respuestas: nunca habla de reseñas pagadas", t.includes("Nadie recibió dinero ni recompensas por reseñas"));
const ni = respuestasProduccion({ ...c, opiniones: [] }, { titulo: "X", tipo: "memoria", publico: "infantil", cambios: [] });
ok("respuestas: infantil y sin opiniones ni cambios", textoRespuestas(ni).includes("pensado para niños") && textoRespuestas(ni).includes("no dejaron comentarios") && textoRespuestas(ni).includes("no hizo falta cambiar"));
console.log(`== ${fallos} fallos ==`);
if (fallos) process.exit(1);
