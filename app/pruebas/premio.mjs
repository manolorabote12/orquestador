// Premio real para negocios: las reglas de la app son las del servidor.
let fallos = 0;
const check = (n, ok, d = "") => { console.log((ok ? "  OK   " : "  FALLO ") + n + (ok ? "" : `  (${d})`)); if (!ok) fallos++; };
const { validarPremio, mensajePremio, IDEAS_PREMIO, resumenPremio } = await import("./.premio.mjs");

const base = { texto: "10 % en tu próxima compra", codigo: "pan10", tras_nivel: 3, donde: "Panadería Luna", web: "", caduca: null };
const hoy = new Date("2026-11-01T12:00:00Z");
check("premio normal: vale", validarPremio(base, hoy) === "");
check("código con espacios o símbolos: no", validarPremio({ ...base, codigo: "pan 10!" }, hoy) === mensajePremio("bad_code"));
check("texto con etiquetas: no", validarPremio({ ...base, texto: "<b>gratis</b>" }, hoy) === mensajePremio("bad_text"));
check("web sin https: no", validarPremio({ ...base, web: "http://pan.es" }, hoy) === mensajePremio("bad_web"));
check("nivel fuera de 1-50: no", validarPremio({ ...base, tras_nivel: 0 }, hoy) !== "" && validarPremio({ ...base, tras_nivel: 51 }, hoy) !== "");
check("caducado: no", validarPremio({ ...base, caduca: "2026-10-31" }, hoy) === mensajePremio("bad_date") && validarPremio({ ...base, caduca: "2026-11-01" }, hoy) === "");
check("todas las ideas cumplen las reglas", IDEAS_PREMIO.every((i) => validarPremio({ ...base, texto: i.texto, codigo: i.codigo, tras_nivel: i.nivel }, hoy) === ""));
check("resumen para el autor", resumenPremio({ ...base, codigo: "PAN10", caduca: "2026-12-31", ganados: 4 }).includes("31/12/2026") && resumenPremio(null).startsWith("Sin premio"));
check("cada error del servidor tiene su frase", ["bad_text", "bad_place", "bad_code", "bad_level", "bad_web", "bad_date"].every((k) => mensajePremio(k) !== mensajePremio("x")));
const { limpiarCodigo, codigoValido, textoCanje } = await import("./.premio.mjs");
check("canje: el código se limpia", limpiarCodigo(" cafe-7f3a ") === "CAFE-7F3A" && codigoValido("cafe-7f3a") && !codigoValido("CAFE") && !codigoValido("CAFE-ZZZZ"));
check("canje: frases para el dependiente", textoCanje({ estado: "ok" }).ok && !textoCanje({ estado: "ya_usado", canjeado_en: "2026-11-01T10:00:00Z" }).ok
  && textoCanje({ estado: "ya_usado", canjeado_en: "2026-11-01T10:00:00Z" }).texto.includes("Ya se usó") && textoCanje({ estado: "no_existe" }).texto.includes("no existe"));
console.log(fallos ? `== ${fallos} fallos ==` : "== 0 fallos ==");
if (fallos) process.exit(1);
