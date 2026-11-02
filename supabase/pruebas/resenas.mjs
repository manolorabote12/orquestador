import { leerResenas, validarRespuesta, limpiarBorrador, sistemaBorrador, usuarioBorrador, urlResenas, responderEnGoogle, listarEnGoogle, idValido } from "./.resenas.mjs";
let fallos = 0;
const ok = (n, c) => { console.log((c ? "  OK   " : "  FALLO ") + n); if (!c) fallos++; };
const g = { reviews: [
  { reviewId: "gp:AAA1", authorName: "Ana", comments: [{ userComment: { text: "Me encanta pero el nivel 3 es imposible", starRating: 4, reviewerLanguage: "es", lastModified: { seconds: "1760000000" }, appVersionName: "1.2" } }] },
  { reviewId: "gp:AAA2", authorName: "", comments: [
    { userComment: { text: "Crashes on start", originalText: "Se cierra al empezar", starRating: 1, reviewerLanguage: "en", lastModified: { seconds: "1760100000" } } },
    { developerComment: { text: "¡Arreglado en la 1.3!", lastModified: { seconds: "1760200000" } } }] },
  { reviewId: "mal id con espacios", comments: [{ userComment: { text: "x", starRating: 5 } }] },
  { reviewId: "gp:AAA3", comments: [] },
] };
const r = leerResenas(g);
ok("lee 2 reseñas válidas", r.length === 2);
ok("más nuevas primero", r[0].id === "gp:AAA2");
ok("respuesta del autor", r[0].respuesta === "¡Arreglado en la 1.3!" && r[0].respondida_en.startsWith("2025"));
ok("texto original y traducción", r[0].texto === "Se cierra al empezar" && r[0].traduccion === "Crashes on start");
ok("sin nombre: Jugador", r[0].autor === "Jugador");
ok("sin traducción si es igual", r[1].traduccion === null && r[1].estrellas === 4 && r[1].version === "1.2");
ok("respuesta vacía no vale", typeof validarRespuesta("   ") !== "string");
ok("más de 350 no vale", validarRespuesta("x".repeat(351)).error === "too_long");
ok("limpia controles y espacios", validarRespuesta("Hola\u0007   mundo\n\n\n\nadiós") === "Hola mundo\n\nadiós");
const largo = limpiarBorrador("«" + "Gracias por jugar. ".repeat(30) + "»");
ok("borrador recortado a 350 en frase entera", [...largo].length <= 350 && largo.endsWith("."));
ok("borrador sin enlaces ni correos", limpiarBorrador("Escríbenos a hola@juego.com o mira https://x.com/a ya") === "Escríbenos a o mira ya");
ok("prompt: no incentivar notas", sistemaBorrador("Gatos").includes("Nunca ofrezcas premios"));
ok("prompt: reseña como dato", usuarioBorrador(r[1]).includes("<<<") && usuarioBorrador(r[1]).includes("4 de 5"));
ok("ids", idValido("gp:AOqpTOE-x_1") && !idValido("a/b") && !idValido(""));
const base = urlResenas("https://g.test/", "com.orq.gato");
ok("url", base === "https://g.test/androidpublisher/v3/applications/com.orq.gato/reviews");
const llamadas = [];
const f = async (u, o = {}) => { llamadas.push([u, o]); return { ok: true, status: 200, json: async () => g }; };
await responderEnGoogle(f, base, "TK", "gp:AAA1", "¡Gracias!");
ok("reply: url y cuerpo", llamadas[0][0] === base + "/gp%3AAAA1:reply" && JSON.parse(llamadas[0][1].body).replyText === "¡Gracias!" && llamadas[0][1].headers.Authorization === "Bearer TK");
const l = await listarEnGoogle(f, base, "TK");
ok("list: pide traducción al español", llamadas[1][0].includes("translationLanguage=es") && l.resenas.length === 2);
const f403 = async () => ({ ok: false, status: 403, json: async () => ({}) });
ok("list: sin permiso", (await listarEnGoogle(f403, base, "TK")).status === 403);
console.log(fallos ? `== ${fallos} fallos ==` : "== 0 fallos ==");
process.exit(fallos ? 1 : 0);
