// «¿Cuánto podría ganar?»: la calculadora de ganancias en la ficha del juego (pestaña Publicar).
// La cuenta está en ../ganancias.ts; aquí solo los campos y el resultado.

import type { Proyecto } from "../api";
import { NOMBRE_MERCADO, consejosGanancias, estimar, tipoDeGenero, type EntradaGanancias, type Mercado } from "../ganancias";
import { h } from "../ui";

// ¿Cuánto podría ganar? Descargas al día, cuánta gente vuelve y dónde juega -> horquilla al mes.
// Si el juego ya tiene jugadores, se rellena con sus datos reales de vuelta (D1 y D7).
export function seccionGanancias(p: Pick<Proyecto, "genero" | "publico" | "funciones" | "admob">,
  datos: Promise<{ jugadores_total: number; d1: number | null; d7: number | null }>): HTMLElement {
  const tipo = tipoDeGenero(p.genero);
  const infantil = p.publico === "infantil";
  const num = (valor: string, min: string, max: string, etiqueta: string) =>
    h("input", { type: "number", inputmode: "numeric", min, max, value: valor, "aria-label": etiqueta }) as HTMLInputElement;
  const descargas = num("100", "0", "1000000", "Descargas al día");
  const d1 = num(tipo === "idle" ? "40" : "35", "1", "95", "Vuelven al día siguiente (%)");
  const d7 = num(tipo === "idle" ? "15" : "10", "0", "90", "Siguen a los 7 días (%)");
  const mercado = h("select", { "aria-label": "Dónde juega la mayoría" },
    ...(Object.keys(NOMBRE_MERCADO) as Mercado[]).map((m) => h("option", { value: m }, NOMBRE_MERCADO[m]))) as HTMLSelectElement;
  const origen = h("p", { class: "muted small" }, "Vuelta de jugadores: media de juegos parecidos.");
  const resultado = h("div", { "aria-live": "polite" });
  const fila = (texto: string, campo: HTMLElement, ancha = false) =>
    h("label", { class: "fila-g" + (ancha ? " ancha" : "") }, h("span", {}, texto), campo);
  const euros0 = (n: number) => n.toLocaleString("es-ES", { style: "currency", currency: "EUR", minimumFractionDigits: n < 10 ? 2 : 0, maximumFractionDigits: n < 10 ? 2 : 0 });
  const pintar = () => {
    const e: EntradaGanancias = {
      descargasDia: Math.max(0, Number(descargas.value) || 0), d1: Math.min(95, Math.max(1, Number(d1.value) || 1)),
      d7: Math.min(90, Math.max(0, Number(d7.value) || 0)), mercado: mercado.value as Mercado, tipo, infantil,
      tienda: Boolean(p.funciones?.tienda),
    };
    const g = estimar(e);
    const dato = (valor: string, etiqueta: string) => h("div", { class: "dato" }, h("strong", {}, valor), h("span", { class: "muted small" }, etiqueta));
    resultado.replaceChildren(
      h("div", { class: "datos" },
        dato(`${euros0(g.totalMes.min)} – ${euros0(g.totalMes.max)}`, "al mes (lo más probable: " + euros0(g.totalMes.med) + ")"),
        dato(g.jugadoresDia.toLocaleString("es-ES"), "jugadores al día tras un mes"),
        dato(euros0(g.anunciosMes.med), "de anuncios al mes"),
        dato(g.porDescarga.toLocaleString("es-ES", { style: "currency", currency: "EUR", maximumFractionDigits: 3 }), "deja cada descarga")),
      ...consejosGanancias(e, g).map((c) => h("p", { class: "small" }, c)));
  };
  for (const x of [descargas, d1, d7, mercado]) x.addEventListener("input", pintar);
  const atajos = h("div", { class: "chips" }, ...[10, 50, 200, 1000, 5000].map((n) => h("button", { class: "chip", type: "button",
    onclick: () => { descargas.value = String(n); pintar(); } }, `${n.toLocaleString("es-ES")}/día`)));
  pintar();
  void datos.then((r) => {
    if (r.jugadores_total >= 50 && r.d1 !== null) {
      d1.value = String(r.d1);
      if (r.d7 !== null) d7.value = String(r.d7);
      origen.textContent = `Vuelta de jugadores: la real de tu juego (${r.jugadores_total.toLocaleString("es-ES")} jugadores).`;
      pintar();
    }
  }).catch(() => { /* sin datos: se queda la media */ });
  return h("section", { class: "sheet" },
    h("div", { class: "sheet-head" }, h("h2", {}, "¿Cuánto podría ganar?"), h("span", { class: "tag" }, "estimación")),
    h("p", { class: "muted small" }, "Mueve las descargas y mira la horquilla. Cuenta los anuncios tal y como los pone tu juego" +
      (infantil ? " (para niños: sin personalizar, pagan menos y no hay tienda)" : "") + (p.admob ? "." : ", con los anuncios ya activados (arriba).")),
    h("div", { class: "calc-g" }, fila("Descargas al día", descargas), atajos, fila("Vuelven al día siguiente (%)", d1),
      fila("Siguen a los 7 días (%)", d7), fila("Dónde juega la mayoría", mercado, true)),
    origen, resultado,
    h("p", { class: "muted small" }, "Son medias del sector (lo que paga AdMob por cada 1000 anuncios en cada zona); lo real lo verás en la consola de AdMob y puede variar mucho."));
}
