// Plan de redes: 7 días distintos, textos que caben en cualquier red y con el enlace correcto.
import { planRedes } from "./.redes.mjs";

let fallos = 0;
const check = (n, ok, d = "") => { console.log((ok ? "  OK   " : "  FALLO ") + n + (ok ? "" : `  (${d})`)); if (!ok) fallos++; };

const p = planRedes({ titulo: "Bigotes Veloces", genero: "plataformas", generoNombre: "Plataformas", giros: ["A oscuras"], jugar: "https://x.github.io/w/jugar.html?j=1", niveles: 5 });
check("7 días con objetivos distintos", p.length === 7 && new Set(p.map((d) => d.objetivo)).size === 7);
check("todos los textos caben (≤ 300)", p.every((d) => d.texto.length <= 300), p.map((d) => d.texto.length).join(","));
check("sin tienda, enlaza al juego en el navegador", p[0].texto.includes("https://x.github.io/w/jugar.html?j=1") && p[0].texto.includes("navegador"));
check("menciona el giro y etiquetas del género", p[0].texto.includes("a oscuras") && p[0].texto.includes("#plataformas"));
const t = planRedes({ titulo: "X", genero: "golf", jugar: "https://a", tienda: "https://play.google.com/store/apps/details?id=a.b" });
check("con tienda, enlaza a Google Play", t[0].texto.includes("play.google.com") && !t[0].texto.includes("https://a "));
const largo = planRedes({ titulo: "T".repeat(250), genero: "puzle" });
check("título larguísimo: se recorta sin pasar de 300", largo.every((d) => d.texto.length <= 300));
const en = planRedes({ titulo: "Gato", genero: "runner", jugar: "https://x/j", niveles: 4, idioma: "en" });
check("plan en inglés: 7 días y el enlace", en.length === 7 && en[0].texto.startsWith("Meet «Gato»") && en[0].texto.includes("https://x/j") && en.every((d) => d.texto.length <= 300));
console.log(`== ${fallos} fallos ==`);
process.exit(fallos ? 1 : 0);
