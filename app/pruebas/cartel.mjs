let fallos = 0;
const check = (n, ok, d = "") => { console.log((ok ? "  OK   " : "  FALLO ") + n + (ok ? "" : `  (${d})`)); if (!ok) fallos++; };
const { partirLineas, dibujarCartel, modulosQr, ANCHO } = await import("./.cartel.mjs");
check("parte en líneas sin cortar palabras", JSON.stringify(partirLineas("10 % de descuento en tu próxima compra", 14)) === JSON.stringify(["10 % de", "descuento en", "tu próxima", "compra"]), JSON.stringify(partirLineas("10 % de descuento en tu próxima compra", 14)));
check("palabra larga, sola", partirLineas("supercalifragilistico x", 5).length === 2);
// Lienzo de mentira: cuenta lo que se pinta.
const llamadas = { rect: 0, texto: [] };
const ctx = { set fillStyle(v) {}, set font(v) {}, set textAlign(v) {}, fillRect: () => { llamadas.rect++; }, fillText: (t) => { llamadas.texto.push(t); } };
const qr = { getModuleCount: () => 21, isDark: (r, c) => (r + c) % 2 === 0 };
dibujarCartel(ctx, { titulo: "Pan Saltarín", premio: "Café gratis con tu desayuno", nivel: 3, donde: "Panadería Luna", url: "https://x", qr: modulosQr(qr) });
check("lleva el premio, el nivel y dónde", llamadas.texto.some((t) => t.includes("Café gratis")) && llamadas.texto.some((t) => t.includes("nivel 3")) && llamadas.texto.some((t) => t.includes("Panadería Luna")));
check("pinta el QR", llamadas.rect > 200 && ANCHO === 1240);
console.log(fallos ? `== ${fallos} fallos ==` : "== 0 fallos ==");
if (fallos) process.exit(1);
