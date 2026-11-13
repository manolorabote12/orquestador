// Piezas comunes: construir DOM sin innerHTML con datos del usuario, Chispa, iconos y avisos.

import { Capacitor } from "@capacitor/core";
import { Browser } from "@capacitor/browser";
import { mensajeError } from "./errores";
import { sonar } from "./sonido";

type Hijo = Node | string | null | undefined | false;

/** Crea un elemento. Los textos se insertan como texto, nunca como HTML. */
export function h<K extends keyof HTMLElementTagNameMap>(
  tag: K, attrs: Record<string, string | boolean | ((e: Event) => void)> = {}, ...hijos: Hijo[]
): HTMLElementTagNameMap[K] {
  const el = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) {
    if (typeof v === "function") el.addEventListener(k.replace(/^on/, ""), v);
    else if (v === true) el.setAttribute(k, "");
    else if (v !== false) el.setAttribute(k, v);
  }
  for (const c of hijos) if (c !== null && c !== undefined && c !== false) el.append(c);
  return el;
}

/** SVG fijo de la app (sin datos del usuario). */
export function svg(markup: string): SVGElement {
  const t = document.createElement("template");
  t.innerHTML = markup.trim();
  return t.content.firstElementChild as SVGElement;
}

export const ICONOS = {
  tuerca: `<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 2.5 20.2 7.2v9.6L12 21.5 3.8 16.8V7.2z" fill="#e8b04b" stroke="#9c6b1f" stroke-width="1.4"/><circle cx="12" cy="12" r="3.6" fill="#0a1e36" stroke="#9c6b1f" stroke-width="1.2"/></svg>`,
  taller: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M14.7 6.3a4 4 0 0 0-5.2 5.2L3 18l3 3 6.5-6.5a4 4 0 0 0 5.2-5.2l-2.6 2.6-2.4-.6-.6-2.4z"/></svg>`,
  juegos: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="2.5" y="7" width="19" height="11" rx="5"/><path d="M7 11v3M5.5 12.5h3"/><circle cx="16" cy="11.5" r="1" fill="currentColor"/><circle cx="18" cy="13.5" r="1" fill="currentColor"/></svg>`,
  monedero: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round" aria-hidden="true"><path d="M12 3 19.8 7.5v9L12 21l-7.8-4.5v-9z"/><circle cx="12" cy="12" r="3"/></svg>`,
  cuenta: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" aria-hidden="true"><circle cx="12" cy="8" r="4"/><path d="M4 21c1.5-4 4.5-6 8-6s6.5 2 8 6"/></svg>`,
  descarga: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 4v11M7 10l5 5 5-5M5 20h14"/></svg>`,
  caja: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round" aria-hidden="true"><path d="M3 7.5 12 3l9 4.5v9L12 21l-9-4.5z"/><path d="M3 7.5 12 12l9-4.5M12 12v9"/></svg>`,
  tienda: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M4 11v3a1 1 0 0 0 1 1h2l5 4V6L7 10H5a1 1 0 0 0-1 1zM16 9a4 4 0 0 1 0 6M19 6.5a8 8 0 0 1 0 11"/></svg>`,
  video: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="6" y="2.5" width="12" height="19" rx="2.5"/><path d="M10.5 9.5v5l4-2.5z"/></svg>`,
  jugar: `<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M8 5.5v13l10.5-6.5z" fill="currentColor"/></svg>`,
  galeria: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="9.2"/><path d="M10 8.4v7.2l6-3.6z" fill="currentColor"/></svg>`,
  cohete: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 2.5c3 2 4.5 5.2 4.5 9v4.5h-9V11.5c0-3.8 1.5-7 4.5-9z"/><circle cx="12" cy="9.5" r="1.6"/><path d="M7.5 13.5 5 16v3l2.5-1.5M16.5 13.5 19 16v3l-2.5-1.5M10 19.5l2 2 2-2"/></svg>`,
  abajo: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M5 9l7 7 7-7"/></svg>`,
  atras: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M15 5l-7 7 7 7"/></svg>`,
};

const CHISPA_SVG = `
<svg class="chispa" viewBox="0 0 120 140" role="img" aria-label="Chispa, el ayudante del taller">
  <defs>
    <linearGradient id="brass" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#f6cf7a"/><stop offset="0.6" stop-color="#e8b04b"/><stop offset="1" stop-color="#9c6b1f"/></linearGradient>
    <radialGradient id="glow"><stop offset="0" stop-color="#fff6d8"/><stop offset="1" stop-color="#f6cf7a" stop-opacity="0"/></radialGradient>
  </defs>
  <g class="bob">
    <ellipse cx="60" cy="134" rx="30" ry="4" fill="#000" opacity="0.25"/>
    <line x1="60" y1="31" x2="60" y2="14" stroke="#e8f0fa" stroke-width="3" stroke-linecap="round"/>
    <g class="spark"><circle cx="60" cy="9" r="11" fill="url(#glow)"/><path d="M62 1 55 10h5l-2 8 7-10h-5z" fill="#f6cf7a" stroke="#9c6b1f" stroke-width="1"/></g>
    <g class="key"><rect x="97" y="69" width="9" height="6" rx="1.5" fill="#d9774a"/><path d="M104 72c0-7 10-7 10 0s-10 7-10 0zm0 0c0 7 10 7 10 0" fill="none" stroke="#d9774a" stroke-width="3.5"/></g>
    <rect x="36" y="96" width="48" height="28" rx="9" fill="#d9774a" stroke="#0a1e36" stroke-width="2.5"/>
    <path d="M60 103l6 3.5v7L60 117l-6-3.5v-7z" fill="#f6cf7a" stroke="#0a1e36" stroke-width="1.6"/>
    <rect x="40" y="122" width="12" height="7" rx="2.5" fill="#0a1e36"/><rect x="68" y="122" width="12" height="7" rx="2.5" fill="#0a1e36"/>
    <rect x="22" y="30" width="76" height="66" rx="24" fill="url(#brass)" stroke="#0a1e36" stroke-width="2.5"/>
    <circle cx="30" cy="40" r="2" fill="#9c6b1f"/><circle cx="90" cy="40" r="2" fill="#9c6b1f"/>
    <rect x="32" y="43" width="56" height="38" rx="15" fill="#0a1e36"/>
    <circle cx="41" cy="74" r="3.5" fill="#d9774a" opacity="0.8"/><circle cx="79" cy="74" r="3.5" fill="#d9774a" opacity="0.8"/>
    <g class="eye-open"><circle cx="60" cy="61" r="12.5" fill="#e8f0fa"/><circle class="pupil" cx="60" cy="62" r="5.5" fill="#0a1e36"/><circle cx="63" cy="58" r="1.8" fill="#e8f0fa"/></g>
    <rect class="lid" x="47" y="48" width="26" height="26" rx="13" fill="#0a1e36"/>
    <path class="eye-happy" d="M48 66q12-15 24 0" fill="none" stroke="#e8f0fa" stroke-width="4" stroke-linecap="round"/>
    <g class="eye-err" stroke="#ff8a7a" stroke-width="4" stroke-linecap="round"><path d="M52 53l16 16M68 53 52 69"/></g>
  </g>
</svg>`;

export type Humor = "" | "thinking" | "happy" | "error" | "queued";

export interface Chispa {
  el: HTMLElement;
  decir(texto: string, humor?: Humor, pose?: Pose): void;
}

/** Chispa con su bocadillo. El texto siempre se pone como texto. */
// Chispa en 3D (13 nov, hecha con IA en RunPod: fabrica/arte_app.py): una pose por estado de animo.
export type Pose = "hola" | "pensando" | "trabajando" | "celebrando" | "triste" | "jugando" | "tuercas" | "cohete" | "durmiendo" | "ganando";
const POSE_DE: Record<string, Pose> = { "": "hola", thinking: "pensando", happy: "celebrando", error: "triste", queued: "trabajando" };

export function imagenChispa(pose: Pose, clase = "chispa-3d"): HTMLImageElement {
  const img = h("img", { class: clase, src: `mascota/${pose}.webp`, alt: "", decoding: "async", "data-pose": pose }) as HTMLImageElement;
  return img;
}

export function crearChispa(saludo: string, pose: Pose = "hola"): Chispa {
  // Respaldo: si la imagen no carga (no deberia), el dibujo de siempre.
  const figura = h("div", { class: "chispa-figura" }, imagenChispa(pose));
  (figura.firstChild as HTMLImageElement).addEventListener("error", () => { figura.replaceChildren(svg(CHISPA_SVG)); }, { once: true });
  const bocadillo = h("p", { class: "bubble", "aria-live": "polite" }, saludo);
  const el = h("section", { class: "chispa-row" }, figura, bocadillo);
  return {
    el,
    decir(texto: string, humor: Humor = "", otra?: Pose) {
      bocadillo.textContent = texto;
      const img = figura.querySelector("img");
      const nueva = otra ?? POSE_DE[humor] ?? "hola";
      if (img && img.dataset.pose !== nueva) {
        img.dataset.pose = nueva;
        img.src = `mascota/${nueva}.webp`;
        img.classList.remove("cambia");
        void img.offsetWidth;
        img.classList.add("cambia");
      }
      figura.setAttribute("class", "chispa-figura " + humor);
      const s2 = figura.querySelector("svg");
      if (s2) s2.setAttribute("class", "chispa " + humor);
    },
  };
}

let avisoActual: HTMLElement | null = null;
/** Aviso breve abajo. Con accion (p. ej. Reintentar) lleva un boton y dura mas. */
export function aviso(texto: string, accion?: { texto: string; hacer: () => void }): void {
  avisoActual?.remove();
  const t = h("div", { class: "toast", role: accion ? "alert" : "status" }, texto);
  if (accion) {
    t.append(h("button", { class: "toast-action", onclick: () => { t.remove(); accion.hacer(); } }, accion.texto));
  }
  document.body.append(t);
  avisoActual = t;
  sonar(accion ? "error" : "aviso");
  setTimeout(() => t.remove(), accion ? 6500 : 3200);
}

/** Aviso de un fallo: el mensaje que toca (ErrorApp, sin conexion o el de por defecto) y,
 *  si se puede repetir, el boton Reintentar. */
export function avisoError(e: unknown, porDefecto: string, reintentar?: () => void): void {
  aviso(mensajeError(e, porDefecto), reintentar ? { texto: "Reintentar", hacer: reintentar } : undefined);
}

/** Bloque para una pantalla que no ha podido cargar: que ha pasado y, si se puede, Reintentar. */
export function bloqueError(e: unknown, porDefecto: string, reintentar?: () => void): HTMLElement {
  const caja = h("div", { class: "load-error", role: "alert" }, h("p", { class: "status err" }, mensajeError(e, porDefecto)));
  if (reintentar) caja.append(h("button", { class: "btn btn-line btn-small", onclick: reintentar }, "Reintentar"));
  return caja;
}

/** Abre una URL: en la app instalada con el navegador del sistema (descarga e instala APKs). */
export async function abrir(url: string): Promise<void> {
  if (Capacitor.isNativePlatform()) await Browser.open({ url });
  else window.open(url, "_blank", "noopener");
}

export function hace(fechaIso: string): string {
  const s = (Date.now() - new Date(fechaIso).getTime()) / 1000;
  if (s < 60) return "ahora mismo";
  if (s < 3600) return `hace ${Math.floor(s / 60)} min`;
  if (s < 86400) return `hace ${Math.floor(s / 3600)} h`;
  return new Date(fechaIso).toLocaleDateString("es-ES", { day: "numeric", month: "short" });
}

export interface VistaHecha {
  el: HTMLElement;
  limpiar?: () => void;
}

// Portada ilustrada del tipo de juego (public/generos_arte, hecha con IA: fabrica/arte_app.py); si
// falta, la captura de partida de siempre.
export function fotoGenero(id: string, attrs: Record<string, string> = {}): HTMLImageElement {
  const img = h("img", { src: `generos_arte/${id}.webp`, alt: "", loading: "lazy", decoding: "async", ...attrs }) as HTMLImageElement;
  img.addEventListener("error", () => { if (!img.src.includes("/generos/")) img.src = `generos/${id}.webp`; }, { once: true });
  return img;
}

/** Cartel de arriba de una pestaña: fondo ilustrado, título, una frase y Chispa en su pose. */
export function cartelChispa(titulo: string, texto: string, pose: Pose): HTMLElement {
  return h("header", { class: "cartel-chispa" },
    h("div", { class: "cartel-texto" }, h("h1", {}, titulo), h("p", {}, texto)),
    imagenChispa(pose, "cartel-mascota"));
}
