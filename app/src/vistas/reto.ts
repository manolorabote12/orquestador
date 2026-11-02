// Reto de la semana: un tema para todos; los 3 juegos con más jugadas y me gusta esa semana
// ganan tuercas. Da un motivo para crear algo nuevo cada semana y para compartirlo.

import type { App } from "../main";
import { type PuestoReto, type RetoSemana } from "../api";
import { aviso, h } from "../ui";
import { quedan } from "../cuenta-atras";
import { mensajeError } from "../errores";

const MEDALLAS = ["🥇", "🥈", "🥉"];

/** Sección del taller. alUsarTema pone el tema en el cuadro de la idea. */
export function seccionReto(app: App, alUsarTema: (tema: string) => void): HTMLElement {
  const s = h("section", { class: "sheet reto", "aria-live": "polite" },
    h("div", { class: "sheet-head" }, h("h2", {}, "Reto de la semana")), h("p", { class: "muted small" }, "Cargando..."));
  void (async () => {
    let r: RetoSemana;
    let tabla: PuestoReto[] = [];
    try {
      [r, tabla] = await Promise.all([app.api.retoSemana(), app.api.rankingReto().catch(() => [])]);
    } catch (e) {
      s.replaceChildren(h("div", { class: "sheet-head" }, h("h2", {}, "Reto de la semana")),
        h("p", { class: "muted small" }, mensajeError(e, "No se pudo cargar.")));
      return;
    }
    const usar = h("button", { class: "btn btn-brass", type: "button", onclick: () => alUsarTema(r.tema) }, `Crear un juego de «${r.tema}»`);
    const filas = tabla.slice(0, 5).map((p) => h("li", { class: p.project_id === r.mi_proyecto ? "mio" : "" },
      h("span", { class: "reto-puesto" }, MEDALLAS[p.puesto - 1] ?? String(p.puesto)),
      h("span", { class: "reto-titulo" }, p.titulo, h("span", { class: "muted small" }, ` · ${p.autor}`)),
      h("span", { class: "reto-puntos" }, `${p.puntos} pts`)));
    s.replaceChildren(
      h("div", { class: "sheet-head" }, h("h2", {}, "Reto de la semana"), h("span", { class: "tag" }, `quedan ${quedan(r.termina)}`)),
      h("p", { class: "reto-tema" }, r.tema),
      h("p", { class: "small" }, `Crea un juego con este tema, compártelo y preséntalo desde su pestaña Compartir. Los 3 con más jugadas y me gusta de la semana ganan ${r.premios.join(", ")} tuercas.`),
      r.mi_proyecto ? h("p", { class: "status ok" }, "Ya participas. ¡Comparte el enlace para sumar jugadas!") : "",
      filas.length ? h("ol", { class: "reto-tabla", "aria-label": "Clasificación" }, ...filas)
        : h("p", { class: "muted small" }, `Aún no hay juegos presentados. ${r.participantes ? "" : "¡Sé el primero!"}`),
      r.ganadores_anterior.length ? h("p", { class: "muted small" }, "La semana pasada ganó ",
        h("strong", {}, r.ganadores_anterior[0].titulo), ` de ${r.ganadores_anterior[0].autor}.`) : "",
      usar);
  })();
  return s;
}

/** Botón para presentar un juego (ya compartido) al reto de esta semana. */
export function botonReto(app: App, proyectoId: string): HTMLElement {
  const caja = h("div", { class: "reto-presentar" });
  void app.api.retoSemana().then((r) => {
    if (r.mi_proyecto === proyectoId) {
      caja.replaceChildren(h("p", { class: "status ok" }, `Presentado al reto «${r.tema}» (quedan ${quedan(r.termina)}).`));
      return;
    }
    const b = h("button", { class: "btn btn-line", type: "button" }, `Presentar al reto «${r.tema}»`);
    b.addEventListener("click", async () => {
      b.disabled = true;
      try {
        await app.api.participarReto(proyectoId);
        aviso(r.mi_proyecto ? "Cambiado: ahora participas con este juego" : "¡Presentado! Comparte el enlace para sumar jugadas");
        caja.replaceChildren(h("p", { class: "status ok" }, `Presentado al reto «${r.tema}».`));
      } catch (e) {
        aviso(mensajeError(e, "No se pudo presentar."));
        b.disabled = false;
      }
    });
    caja.replaceChildren(h("p", { class: "muted small" }, r.mi_proyecto ? "Ya participas con otro juego: si presentas este, lo cambias."
      : `Tema de esta semana: ${r.tema}. Premio para los 3 primeros.`), b);
  }).catch(() => caja.remove());
  return caja;
}
