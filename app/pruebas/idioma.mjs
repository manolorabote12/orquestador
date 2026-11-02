// Idioma: el diccionario y las reglas traducen lo que deben y no tocan lo demás.
let fallos = 0;
const check = (n, ok, d = "") => { console.log((ok ? "  OK   " : "  FALLO ") + n + (ok ? "" : `  (${d})`)); if (!ok) fallos++; };
globalThis.localStorage = { getItem: () => "en", setItem: () => {} };
Object.defineProperty(globalThis, "navigator", { configurable: true, get: () => ({ language: "en-US" }) });
const { traducirTexto, idioma } = await import("./.idioma.mjs");
check("idioma guardado", idioma() === "en");
check("texto exacto", traducirTexto("Fabricar juego") === "Make game");
check("conserva los espacios", traducirTexto("  Mis juegos ") === "  My games ");
check("con número al final", traducirTexto("Acción 45") === "Action 45");
check("con número entre paréntesis", traducirTexto("O elige un tipo de juego (119)") === "Or pick a game type (119)");
check("regla con número", traducirTexto("Al superar el nivel 3") === "After beating level 3");
check("regla que traduce dentro", traducirTexto("Recomendado: Arcade y acción") === "Recommended: Arcade and action");
check("lo que no conoce se queda igual", traducirTexto("Bigotes Veloces") === "Bigotes Veloces");
check("monetización", traducirTexto("Anuncios con premio: Continuar tras perder, Premio doble al acabar.") === "Rewarded ads: Continue after losing, Double reward at the end.");
console.log(fallos ? `== ${fallos} fallos ==` : "== 0 fallos ==");
if (fallos) process.exit(1);
