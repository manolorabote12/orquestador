// Idioma de la app: español (el original) o inglés. Los textos se escriben en español en todo el
// código y, en inglés, se traducen al vuelo en la página (textos, placeholder, aria-label y title)
// con el diccionario de idioma-en.ts y unas reglas para los textos con números. Lo que no está en
// el diccionario se queda en español (fase 1: lo que más se ve).
import { EN as EN1 } from "./idioma-en";
import { EN2 } from "./idioma-en2";

const EN: Record<string, string> = { ...EN1, ...EN2 };

export type Idioma = "es" | "en";
const CLAVE = "orq_idioma";

export function idioma(): Idioma {
  let guardado: string | null = null;
  try { guardado = localStorage.getItem(CLAVE); } catch { /* sin almacenamiento */ }
  if (guardado === "es" || guardado === "en") return guardado;
  const nav = (typeof navigator !== "undefined" ? navigator.language : "es") || "es";
  return nav.toLowerCase().startsWith("es") ? "es" : "en";
}

export function ponerIdioma(i: Idioma): void {
  try { localStorage.setItem(CLAVE, i); } catch { /* sin almacenamiento */ }
}

/** Reglas para textos que llevan números o nombres: [patrón, cómo queda]. */
const REGLAS: [RegExp, (m: RegExpMatchArray) => string][] = [
  [/^(.+?) \((\d+)\)$/, (m) => `${t(m[1])} (${m[2]})`],
  [/^(.+?) (\d+)$/, (m) => (EN[m[1]] ? `${EN[m[1]]} ${m[2]}` : m[0])],
  [/^Tu tema para (.+)$/, (m) => `Your theme for ${m[1]}`],
  [/^Probar una partida de (.+)$/, (m) => `Play a sample of ${m[1]}`],
  [/^Jugar a (.+)$/, (m) => `Play ${m[1]}`],
  [/^Empieza con una plantilla de éxito$/, () => "Start from a proven template"],
  [/^O elige un tipo de juego$/, () => "Or pick a game type"],
  [/^Al superar el nivel (\d+)$/, (m) => `After beating level ${m[1]}`],
  [/^Día (\d+)$/, (m) => `Day ${m[1]}`],
  [/^(\d+) de (\d+) probadores$/, (m) => `${m[1]} of ${m[2]} testers`],
  [/^(\d+) de (\d+) probadores · le faltan (\d+)$/, (m) => `${m[1]} of ${m[2]} testers · ${m[3]} to go`],
  [/^(\d+) puntos$/, (m) => `${m[1]} points`],
  [/^(\d+) activos$/, (m) => `${m[1]} active`],
  [/^(\d+) tuercas$/, (m) => `${m[1]} bolts`],
  [/^Elegir · (.+)\/(mes|año)$/, (m) => `Choose · ${m[1]}/${m[2] === "mes" ? "month" : "year"}`],
  [/^Pasar a Pro · (.+)\/(mes|año)$/, (m) => `Upgrade to Pro · ${m[1]}/${m[2] === "mes" ? "month" : "year"}`],
  [/^([\d.]+) tuercas cada mes \(≈ (\d+) juegos?\)$/, (m) => `${m[1].replace(".", ",")} bolts every month (≈ ${m[2]} game${m[2] === "1" ? "" : "s"})`],
  [/^\+(\d+) % de tuercas en cada pack$/, (m) => `+${m[1]}% bolts on every pack`],
  [/^Tienes el plan (Taller Pro|Taller)\. (?:Tus próximas tuercas llegan el (.+)\.)?$/, (m) => `You have the ${m[1] === "Taller Pro" ? "Workshop Pro" : "Workshop"} plan.` + (m[2] ? ` Your next bolts arrive on ${m[2]}.` : "")],
  [/^Las tuercas del plan se acumulan hasta (\d+) meses\..*$/, (m) => `Plan bolts stack up to ${m[1]} months. It renews automatically; cancel anytime in Google Play and it stays active until the end of the paid period.`],
  [/^≈ (\d+) juegos$/, (m) => `≈ ${m[1]} games`],
  [/^versión (\d+)$/, (m) => `version ${m[1]}`],
  [/^(\d+) versión(es)?$/, (m) => `${m[1]} version${m[1] === "1" ? "" : "s"}`],
  [/^(\d+) de (\d+) pasos hechos$/, (m) => `${m[1]} of ${m[2]} steps done`],
  [/^Prueba (\d+) juegos? más y tu campaña saldrá aquí$/, (m) => `Test ${m[1]} more game${m[1] === "1" ? "" : "s"} and your campaign will show here`],
  [/^Te faltan (\d+) tuercas\. Consíguelas en la pestaña Tuercas\.$/, (m) => `You need ${m[1]} more bolts. Get them in the Bolts tab.`],
  [/^Un juego completo cuesta (\d+) tuercas\. (.*)$/, (m) => `A full game costs ${m[1]} bolts.` + (m[2].startsWith("Aún") ? " You don't have enough for one yet." : "")],
  [/^Activar · (\d+) tuercas \((\d+) mensajes\)$/, (m) => `Activate · ${m[1]} bolts (${m[2]} messages)`],
  [/^Crear 3 vídeos con IA · (\d+) tuercas$/, (m) => `Make 3 AI videos · ${m[1]} bolts`],
  [/^Así lo verá (.+)$/, (m) => `How ${m[1]} will see it`],
  [/^Clase creada: código (.+)$/, (m) => `Class created: code ${m[1]}`],
  [/^Idea: (.+)$/, (m) => `Idea: ${m[1]}`],
  [/^¡Listo! «(.+)» ha superado todas las pruebas\. Descárgalo y juega\.$/, (m) => `Done! «${m[1]}» passed every test. Download it and play.`],
  [/^Has invitado a (\d+) personas?; (\d+) ya ha fabricado su juego \(\+(\d+) tuercas\)\.$/, (m) => `You've invited ${m[1]} people; ${m[2]} already made their game (+${m[3]} bolts).`],
  [/^Crear un juego de «(.+)»$/, (m) => `Make a «${m[1]}» game`],
  [/^hazlo único, originalidad (\d+)%$/, (m) => `make it unique, originality ${m[1]}%`],
  [/^hazlo único$/, () => "make it unique"],
  [/^Banner: (.+)\. Intersticial: (.+)\.( Anuncio al volver a la app\.)?$/, (m) => `Banner: ${t(m[1])}. Interstitial: ${m[2].replace(/^cada nivel/, "every level").replace(/^cada (\d+) niveles/, "every $1 levels").replace(/como mucho (\d+) por sesión/, "at most $1 per session")}.${m[3] ? " Ad when returning to the app." : ""}`],
  [/^Anuncios con premio: (.+)\.$/, (m) => `Rewarded ads: ${m[1].split(", ").map(t).join(", ")}.`],
  [/^Bloques que necesitas en AdMob: (.+)\.$/, (m) => `Units you need in AdMob: ${m[1].replace("Intersticial", "Interstitial").replace("Bonificado", "Rewarded").replace("Apertura de app", "App open")}.`],
  [/^Compras que destaca: (.+)\.$/, (m) => `Featured purchases: ${m[1].replace(/Sin anuncios/g, "No ads").replace(/monedas/g, "coins").replace(/Pase premium/g, "Premium pass").replace(/Pack de inicio/g, "Starter pack").replace(/ \+ sin anuncios/g, " + no ads")}.`],
  [/^de (.+)\.$/, (m) => `by ${m[1]}.`],
  [/^Qué grabar: (.+)$/, (m) => `What to film: ${t(m[1])}`],
  [/^(\d+)\/día$/, (m) => `${m[1]}/day`],
  [/^al mes \(lo más probable: (.+)\)$/, (m) => `per month (most likely: ${m[1]})`],
  [/^Para unos (.+) al mes harían falta unas (\d+) descargas al día\.$/, (m) => `About ${m[2]} downloads a day would bring in around ${m[1]} a month.`],
  [/^· nivel (\d+) · (.+)$/, (m) => `· level ${m[1]} · ${m[2]}`],
  [/^(\d+) juegos · (\d+) partidas · (\d+) me gusta$/, (m) => `${m[1]} games · ${m[2]} plays · ${m[3]} likes`],
  [/^Faltan (\d+) puntos para (.+)$/, (m) => `${m[1]} points to ${t(m[2])}`],
  [/^Te faltan (\d+) puntos para (.+?)\. .*$/, (m) => `${m[1]} more points to ${t(m[2])}. Your games, plays, likes, remixes and challenges all count.`],
  [/^(\d+) pts$/, (m) => `${m[1]} pts`],
  [/^quedan (.+)$/, (m) => `${m[1]} left`],
  [/^Recomendado: (.+)$/, (m) => `Recommended: ${t(m[1])}`],
  [/^Para (.+)$/, (m) => (EN["Para " + m[1]] ? EN["Para " + m[1]] : m[0])],
];

function t(s: string): string {
  const e = EN[s];
  if (e) return e;
  for (const [re, f] of REGLAS) {
    const m = s.match(re);
    if (!m) continue;
    const r = f(m);
    if (r !== s) return r;
  }
  return s;
}

/** Traduce un texto (con sus espacios de alrededor). */
export function traducirTexto(s: string): string {
  const limpio = s.trim();
  if (!limpio) return s;
  const r = t(limpio);
  return r === limpio ? s : s.replace(limpio, r);
}

const ATRIBUTOS = ["placeholder", "aria-label", "title"];

function traducirNodo(n: Node): void {
  if (n.nodeType === Node.TEXT_NODE) {
    const v = n.nodeValue ?? "";
    const r = traducirTexto(v);
    if (r !== v) n.nodeValue = r;
    return;
  }
  if (n.nodeType !== Node.ELEMENT_NODE) return;
  const el = n as Element;
  if (el.tagName === "SCRIPT" || el.tagName === "STYLE") return;
  for (const a of ATRIBUTOS) {
    const v = el.getAttribute(a);
    if (v) {
      const r = traducirTexto(v);
      if (r !== v) el.setAttribute(a, r);
    }
  }
  // El texto que escribe la persona no se toca.
  if (el.tagName === "TEXTAREA") return;
  for (const c of Array.from(el.childNodes)) traducirNodo(c);
}

/** En inglés, traduce la página y todo lo que se añada después. */
export function iniciarIdioma(): void {
  const i = idioma();
  document.documentElement.lang = i;
  if (i === "es") return;
  traducirNodo(document.body);
  new MutationObserver((ms) => {
    for (const m of ms) {
      if (m.type === "characterData") traducirNodo(m.target);
      else if (m.type === "attributes") traducirNodo(m.target);
      else for (const n of Array.from(m.addedNodes)) traducirNodo(n);
    }
  }).observe(document.body, { childList: true, subtree: true, characterData: true, attributes: true, attributeFilter: ATRIBUTOS });
}
