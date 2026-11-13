// Efectos de la app (13 nov): que se sienta como un juego top, sin estorbar.
// 1 - Al cambiar de pestaña, la pantalla entra deslizándose desde el lado de la pestaña tocada.
// 2 - Deslizar el dedo a izquierda o derecha cambia de pestaña (salvo encima de algo que ya se
//     desliza solo: carruseles, chips, campos de texto).
// 3 - Al tocar un botón: onda de luz; en los botones dorados, además, chispas de latón.
// Todo se apaga con «reducir movimiento» del sistema.

const quieto = (): boolean => window.matchMedia?.("(prefers-reduced-motion: reduce)").matches ?? false;

/** Entrada de una pantalla: dir 1 = viene de la derecha, -1 = de la izquierda, 0 = aparece. */
export function entrarPantalla(el: HTMLElement, dir: number): void {
  if (quieto() || !el.animate) return;
  el.animate(
    [{ opacity: 0, transform: `translateX(${dir * 36}px) scale(${dir ? 1 : 0.985})` }, { opacity: 1, transform: "none" }],
    { duration: 280, easing: "cubic-bezier(.2,.8,.2,1)" },
  );
  // Las tarjetas y carteles caen en cascada, una tras otra.
  const hijos = [...el.querySelectorAll<HTMLElement>(":scope > .cartel-chispa, :scope > * > .sheet, :scope > * > section")].slice(0, 6);
  hijos.forEach((h, i) => h.animate(
    [{ opacity: 0, transform: "translateY(14px)" }, { opacity: 1, transform: "none" }],
    { duration: 320, delay: 60 + i * 55, easing: "cubic-bezier(.2,.8,.2,1)", fill: "backwards" },
  ));
}

const NO_DESLIZAR = ".carrusel, .desliza, .chips, .tipos-rapidos, .gal-rejilla, input, textarea, select, .player, .tabla-desliza, [data-sin-deslizar]";

/** Deslizar con el dedo cambia de pestaña. */
export function deslizarPestanas(zona: HTMLElement, cambiar: (dir: 1 | -1) => void): void {
  let x0 = 0, y0 = 0, t0 = 0, vale = false;
  zona.addEventListener("touchstart", (e) => {
    const t = e.touches[0];
    vale = e.touches.length === 1 && !(e.target as HTMLElement).closest?.(NO_DESLIZAR) && !document.querySelector(".player, .modal-fondo");
    x0 = t.clientX; y0 = t.clientY; t0 = performance.now();
  }, { passive: true });
  zona.addEventListener("touchend", (e) => {
    if (!vale) return;
    const t = e.changedTouches[0];
    const dx = t.clientX - x0, dy = t.clientY - y0;
    if (Math.abs(dx) > 80 && Math.abs(dy) < 50 && Math.abs(dx) > Math.abs(dy) * 2 && performance.now() - t0 < 600) {
      cambiar(dx < 0 ? 1 : -1);
    }
  }, { passive: true });
}

/** Onda y chispas al tocar botones. */
export function activarToques(): void {
  document.addEventListener("pointerdown", (ev) => {
    if (quieto()) return;
    const b = (ev.target as HTMLElement | null)?.closest?.<HTMLElement>(".btn, .tab, .chip, .carrusel-item, .genero, .tipo-rapido");
    if (!b || (b as HTMLButtonElement).disabled) return;
    const r = b.getBoundingClientRect();
    const onda = document.createElement("span");
    onda.className = "onda";
    const lado = Math.max(r.width, r.height) * 2;
    onda.style.cssText = `width:${lado}px;height:${lado}px;left:${ev.clientX - r.left - lado / 2}px;top:${ev.clientY - r.top - lado / 2}px`;
    if (getComputedStyle(b).position === "static") b.style.position = "relative";
    b.classList.add("con-onda");
    b.append(onda);
    setTimeout(() => onda.remove(), 650);
    if (b.classList.contains("btn-brass")) chispas(ev.clientX, ev.clientY, 12);
  }, { passive: true });
}

/** Chispas de latón que saltan desde un punto (también para celebrar). */
export function chispas(x: number, y: number, n = 14, colores = ["#f6cf7a", "#e8b04b", "#fff3c4", "#6ee6ff"]): void {
  if (quieto()) return;
  const capa = document.createElement("div");
  capa.className = "chispas";
  document.body.append(capa);
  for (let i = 0; i < n; i++) {
    const p = document.createElement("i");
    const ang = (Math.PI * 2 * i) / n + Math.random() * 0.5;
    const dist = 40 + Math.random() * 60;
    p.style.cssText = `left:${x}px;top:${y}px;background:${colores[i % colores.length]}`;
    capa.append(p);
    p.animate([
      { transform: "translate(-50%,-50%) scale(1)", opacity: 1 },
      { transform: `translate(calc(-50% + ${Math.cos(ang) * dist}px), calc(-50% + ${Math.sin(ang) * dist + 20}px)) scale(0.2)`, opacity: 0 },
    ], { duration: 520 + Math.random() * 260, easing: "cubic-bezier(.1,.7,.3,1)", fill: "forwards" });
  }
  setTimeout(() => capa.remove(), 900);
}
