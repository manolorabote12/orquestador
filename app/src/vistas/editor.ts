// Editor manual de niveles: dibujas el nivel casilla a casilla (bloques, monedas, pinchos,
// enemigos, salida y meta) y al guardar los bots lo prueban antes de crear la versión nueva.
// Si no se puede jugar, la fábrica explica por qué y no cobra.

import type { App } from "../main";
import { type Propuesta, type Proyecto } from "../api";
import { avisos, ancho, editable, operaciones, piezas, pintar, type NivelesJuego, type Pieza } from "../editor";
import { aviso, h } from "../ui";
import { mensajeError } from "../errores";

const ZOOMS = [14, 18, 24, 30];

export async function abrirEditor(app: App, p: Proyecto, alListo: (prop: Propuesta) => void): Promise<void> {
  let datos: NivelesJuego | null;
  try {
    datos = await app.api.nivelesJuego(p);
  } catch (e) {
    aviso(mensajeError(e, "No se pudieron abrir los niveles."));
    return;
  }
  if (!datos) {
    aviso("Esta versión es anterior al editor. Haz cualquier cambio pequeño con Chispa y ya podrás editar los niveles a mano.");
    return;
  }
  if (!editable(datos.genero)) {
    aviso("Los niveles de este tipo de juego aún no se pueden editar a mano. Pídele los cambios a Chispa.");
    return;
  }
  const n = datos;
  const original = n.mapas.map((m) => [...m]);
  const mapas = n.mapas.map((m) => [...m]);
  const historial: string[][][] = [];
  const lista = piezas(n);
  let nivel = 0;
  let pieza: Pieza = lista[0];
  let zoom = window.innerWidth < 500 ? 1 : 2;
  let pintando = false;

  const previo = document.activeElement as HTMLElement | null;
  const cerrar = () => {
    document.removeEventListener("keydown", tecla);
    capa.remove();
    previo?.focus();
  };
  const salir = h("button", { class: "player-close", "aria-label": "Cerrar el editor", onclick: () => {
    if (operaciones(original, mapas).length && !confirm("¿Salir sin guardar tus cambios?")) return;
    cerrar();
  } }, "✕");
  const pestanas = h("div", { class: "chips desliza", role: "tablist", "aria-label": "Nivel" });
  n.nombres.forEach((nombre, i) => {
    pestanas.append(h("button", { class: "chip", type: "button", role: "tab", onclick: () => { nivel = i; dibujar(); } }, `${i + 1}. ${nombre}`));
  });
  const lienzo = h("canvas", { class: "editor-lienzo", "aria-label": "Nivel: toca o arrastra para poner la pieza elegida" });
  const marco = h("div", { class: "editor-marco" }, lienzo);
  const paleta = h("div", { class: "editor-paleta", role: "radiogroup", "aria-label": "Pieza" });
  for (const pz of lista) {
    const b = h("button", { type: "button", class: "editor-pieza", role: "radio", "aria-checked": "false", title: pz.nombre },
      h("i", { style: `background:${pz.color}`, class: pz.letra === "." ? "borrar" : "" }), pz.nombre);
    b.addEventListener("click", () => { pieza = pz; marcarPaleta(); });
    paleta.append(b);
  }
  const deshacer = h("button", { class: "chip", type: "button" }, "↶ Deshacer");
  const masAncho = h("button", { class: "chip", type: "button", "aria-label": "Alargar el nivel" }, "+10 de largo");
  const menosAncho = h("button", { class: "chip", type: "button", "aria-label": "Acortar el nivel" }, "−10 de largo");
  const lupa = h("button", { class: "chip", type: "button", "aria-label": "Cambiar el zoom" }, "Zoom");
  const fijo = n.genero === "rompebloques";
  const herramientas = h("div", { class: "chips editor-herr" }, deshacer, fijo ? null : menosAncho, fijo ? null : masAncho, lupa);
  const estado = h("p", { class: "small editor-estado", "aria-live": "polite" });
  const guardar = h("button", { class: "btn btn-brass", type: "button" }, "Probar y guardar");
  const pie = h("div", { class: "editor-pie" }, estado, guardar);
  const capa = h("div", { class: "player editor", role: "dialog", "aria-modal": "true", "aria-label": "Editor de niveles" },
    h("div", { class: "player-bar" }, h("strong", {}, "Editor de niveles"), salir),
    h("div", { class: "editor-cuerpo" }, pestanas, marco, paleta, herramientas), pie);

  function marcarPaleta() {
    paleta.querySelectorAll("button").forEach((b, i) => b.setAttribute("aria-checked", String(lista[i] === pieza)));
  }

  function guardarPaso() {
    historial.push(mapas.map((m) => [...m]));
    if (historial.length > 60) historial.shift();
  }

  function dibujar() {
    pestanas.querySelectorAll("button").forEach((b, i) => b.setAttribute("aria-selected", String(i === nivel)));
    const mapa = mapas[nivel];
    const c = ZOOMS[zoom];
    const w = mapa[0].length;
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    lienzo.width = w * c * dpr;
    lienzo.height = mapa.length * c * dpr;
    lienzo.style.width = `${w * c}px`;
    lienzo.style.height = `${mapa.length * c}px`;
    const g = lienzo.getContext("2d");
    if (!g) return;
    g.setTransform(dpr, 0, 0, dpr, 0, 0);
    g.fillStyle = "#0b1a2e";
    g.fillRect(0, 0, w * c, mapa.length * c);
    g.strokeStyle = "rgba(232,240,250,0.06)";
    g.lineWidth = 1;
    for (let x = 0; x <= w; x++) { g.beginPath(); g.moveTo(x * c + 0.5, 0); g.lineTo(x * c + 0.5, mapa.length * c); g.stroke(); }
    for (let y = 0; y <= mapa.length; y++) { g.beginPath(); g.moveTo(0, y * c + 0.5); g.lineTo(w * c, y * c + 0.5); g.stroke(); }
    const color = new Map(lista.map((pz) => [pz.letra, pz.color]));
    g.font = `700 ${Math.round(c * 0.55)}px "IBM Plex Mono", monospace`;
    g.textAlign = "center";
    g.textBaseline = "middle";
    mapa.forEach((fila, y) => {
      for (let x = 0; x < fila.length; x++) {
        const ch = fila[x];
        if (ch === ".") continue;
        const col = color.get(ch) ?? "#ff00ff";
        const px = x * c, py = y * c;
        if (ch === "#" || /[123]/.test(ch) || (n.genero === "rompebloques" && "CLM".includes(ch))) {
          g.fillStyle = col;
          g.fillRect(px + 1, py + 1, c - 2, c - 2);
          if (ch === "#" && (y === 0 || mapa[y - 1][x] !== "#")) { g.fillStyle = "rgba(255,255,255,0.35)"; g.fillRect(px + 1, py + 1, c - 2, Math.max(2, c * 0.18)); }
          if (n.genero === "rompebloques" && ch !== "#") { g.fillStyle = "#0b1a2e"; g.fillText(ch, px + c / 2, py + c / 2 + 1); }
        } else if (ch === "^") {
          g.fillStyle = col;
          g.beginPath(); g.moveTo(px + 2, py + c - 2); g.lineTo(px + c / 2, py + c * 0.3); g.lineTo(px + c - 2, py + c - 2); g.fill();
        } else if (ch === "C") {
          g.fillStyle = col;
          g.beginPath(); g.arc(px + c / 2, py + c / 2, c * 0.28, 0, Math.PI * 2); g.fill();
        } else if (ch === "=") {
          g.fillStyle = col;
          g.fillRect(px + 1, py + c * 0.35, c - 2, c * 0.3);
        } else {
          g.fillStyle = col;
          g.beginPath(); g.roundRect(px + 2, py + 2, c - 4, c - 4, c * 0.25); g.fill();
          g.fillStyle = "#0b1a2e";
          g.fillText(ch === "P" ? "▶" : ch === "G" ? "⚑" : ch, px + c / 2, py + c / 2 + 1);
        }
      }
    });
    const av = avisos(n, mapa);
    const cambios = operaciones(original, mapas).length;
    estado.textContent = av.length ? av.join(" ") : cambios ? `${cambios} nivel${cambios > 1 ? "es" : ""} cambiado${cambios > 1 ? "s" : ""}. Los bots lo probarán antes de guardar.` : "Toca una pieza abajo y dibuja en el nivel.";
    estado.classList.toggle("error", av.length > 0);
    guardar.disabled = av.length > 0 || cambios === 0 || mapas.some((m) => avisos(n, m).length > 0);
    deshacer.disabled = historial.length === 0;
  }

  function celda(e: PointerEvent): [number, number] {
    const r = lienzo.getBoundingClientRect();
    const c = ZOOMS[zoom];
    return [Math.floor((e.clientX - r.left) / c), Math.floor((e.clientY - r.top) / c)];
  }

  function poner(e: PointerEvent) {
    const [x, y] = celda(e);
    const nuevo = pintar(mapas[nivel], x, y, pieza.letra, n.genero);
    if (nuevo !== mapas[nivel]) {
      mapas[nivel] = nuevo;
      dibujar();
    }
  }

  lienzo.addEventListener("pointerdown", (e) => {
    pintando = true;
    lienzo.setPointerCapture(e.pointerId);
    guardarPaso();
    poner(e);
    e.preventDefault();
  });
  lienzo.addEventListener("pointermove", (e) => { if (pintando && !pieza.unica) poner(e); });
  const soltar = () => { pintando = false; };
  lienzo.addEventListener("pointerup", soltar);
  lienzo.addEventListener("pointercancel", soltar);
  deshacer.addEventListener("click", () => {
    const antes = historial.pop();
    if (antes) antes.forEach((m, i) => { mapas[i] = m; });
    dibujar();
  });
  masAncho.addEventListener("click", () => { guardarPaso(); mapas[nivel] = ancho(mapas[nivel], mapas[nivel][0].length + 10); dibujar(); });
  menosAncho.addEventListener("click", () => { guardarPaso(); mapas[nivel] = ancho(mapas[nivel], mapas[nivel][0].length - 10); dibujar(); });
  lupa.addEventListener("click", () => { zoom = (zoom + 1) % ZOOMS.length; dibujar(); });
  guardar.addEventListener("click", async () => {
    guardar.disabled = true;
    estado.textContent = "Preparando la versión...";
    try {
      const prop = await app.api.planManual(p.id, operaciones(original, mapas));
      cerrar();
      alListo(prop);
    } catch (e) {
      estado.textContent = mensajeError(e, "No se pudieron guardar tus cambios.");
      estado.classList.add("error");
      guardar.disabled = false;
    }
  });
  function tecla(e: KeyboardEvent) {
    if (e.key === "Escape") salir.click();
    if ((e.ctrlKey || e.metaKey) && e.key === "z") { e.preventDefault(); deshacer.click(); }
  }
  document.addEventListener("keydown", tecla);
  document.body.append(capa);
  marcarPaleta();
  dibujar();
  salir.focus();
}
