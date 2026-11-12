// Jugar: la galería de juegos de la comunidad, al estilo de los portales de juegos.
// Se juega al momento dentro de la app; «Siguiente» encadena partidas sin salir. Entre partidas sale
// un anuncio de Orquestador (solo en la app instalada, como mucho uno cada 2 juegos y 90 s) y cada
// anuncio cuenta para el reparto mensual a quien creó ese juego.

import type { App } from "../main";
import { type JuegoEscaparate } from "../api";
import { abrirJugador } from "../jugador";
import { intersticialDisponible, mostrarIntersticial } from "../nativo";
import { aviso, bloqueError, h, type VistaHecha } from "../ui";
import { mensajeError } from "../errores";
import { GENERO } from "./escaparate";

type Orden = "top" | "semana" | "nuevos";

/** Cada cuántas partidas y segundos como mínimo puede salir un anuncio entre partidas. */
const PARTIDAS_ENTRE_ANUNCIOS = 2;
const SEGUNDOS_ENTRE_ANUNCIOS = 90;

export function vistaGaleria(app: App): VistaHecha {
  let orden: Orden = "top";
  let genero = "";
  let busca = "";
  let juegos: JuegoEscaparate[] = [];
  let vivo = true;
  let partidas = 0;
  let ultimoAnuncio = 0;

  const buscar = h("input", { type: "search", class: "gal-buscar", placeholder: "Busca un juego", "aria-label": "Buscar un juego", enterkeyhint: "search" }) as HTMLInputElement;
  const ordenes = h("div", { class: "chips", role: "tablist", "aria-label": "Orden" });
  const generos = h("div", { class: "chips desliza", role: "tablist", "aria-label": "Tipo de juego" });
  const destacado = h("div");
  const rejilla = h("div", { class: "gal-rejilla" }, h("p", { class: "muted small" }, "Cargando..."));

  const cabeza = h("header", { class: "gal-cabeza" },
    h("h1", {}, "Juega gratis"),
    h("p", {}, "Juegos que la comunidad ha fabricado con Orquestador. Toca uno y juega al momento, sin instalar nada."),
    buscar);
  const creadores = h("section", { class: "sheet gal-creadores" },
    h("h2", {}, "¿Quieres ver tu juego aquí?"),
    h("p", { class: "muted small" }, "Compártelo desde Mis juegos. Cada anuncio que se vea jugando a tu juego te da una parte de lo que paga: la ves en Tuercas y la pasas a tuercas o la cobras."),
    h("button", { class: "btn btn-line", type: "button", onclick: () => app.ir("juegos") }, "Ir a Mis juegos"));

  for (const [k, txt] of [["top", "Lo mejor"], ["semana", "Top de la semana"], ["nuevos", "Lo nuevo"]] as [Orden, string][]) {
    const b = h("button", { class: "chip" + (k === orden ? " activo" : ""), type: "button", role: "tab", "aria-selected": String(k === orden) }, txt);
    b.addEventListener("click", () => {
      orden = k;
      for (const x of ordenes.children) { x.classList.toggle("activo", x === b); x.setAttribute("aria-selected", String(x === b)); }
      void cargar();
    });
    ordenes.append(b);
  }
  buscar.addEventListener("input", () => { busca = buscar.value.trim().toLowerCase(); pintar(); });

  function visibles(): JuegoEscaparate[] {
    if (!busca) return juegos;
    return juegos.filter((j) => `${j.titulo} ${j.autor} ${GENERO[j.genero] ?? j.genero} ${j.resumen}`.toLowerCase().includes(busca));
  }

  /** Tras cada partida: quizás un anuncio, que cuenta para el creador del juego que se acaba de jugar. */
  async function entrePartidas(jugado: JuegoEscaparate): Promise<void> {
    partidas++;
    if (!intersticialDisponible()) return;
    const ahora = Date.now() / 1000;
    if (partidas % PARTIDAS_ENTRE_ANUNCIOS !== 0 || ahora - ultimoAnuncio < SEGUNDOS_ENTRE_ANUNCIOS) return;
    if (await mostrarIntersticial()) {
      ultimoAnuncio = ahora;
      void app.api.anuncioGaleria(jugado.project_id, "intersticial").catch(() => undefined);
    }
  }

  function jugar(j: JuegoEscaparate): void {
    const f = app.api.archivosEscaparate(j);
    const motor = app.api.motor();
    const lista = visibles();
    const i = lista.findIndex((x) => x.project_id === j.project_id);
    const otro = lista.length > 1 ? lista[(i + 1) % lista.length] : null;
    let siguiente = false;
    abrirJugador({
      motor, pck: motor ? f.pck : null, titulo: j.titulo, portada: f.portada,
      siguiente: otro ? () => { siguiente = true; } : undefined,
      alCerrar: () => {
        void entrePartidas(j).finally(() => { if (siguiente && otro && vivo) jugar(otro); });
      },
    });
    void app.api.jugada(j.project_id).catch(() => undefined);
  }

  function poster(j: JuegoEscaparate, grande = false): HTMLElement {
    const f = app.api.archivosEscaparate(j);
    const img = h("img", { class: "gal-portada", alt: "", loading: "lazy", src: f.portada });
    img.addEventListener("error", () => { img.src = f.icono; img.classList.add("solo-icono"); });
    const corazon = h("button", { class: "gal-megusta", type: "button", "aria-label": `Me gusta (${j.megusta})` }, `♥ ${j.megusta}`);
    corazon.addEventListener("click", async (e) => {
      e.stopPropagation();
      corazon.disabled = true;
      try {
        const n = await app.api.meGusta(j.project_id);
        corazon.textContent = `♥ ${n}`;
        corazon.classList.toggle("activo");
      } catch (err) {
        aviso(mensajeError(err, "No se pudo."));
      }
      corazon.disabled = false;
    });
    const tarjeta = h("article", { class: "gal-poster" + (grande ? " grande" : "") },
      h("button", { class: "gal-tocar", type: "button", "aria-label": `Jugar a ${j.titulo}`, onclick: () => jugar(j) },
        img,
        h("span", { class: "gal-pie" },
          h("strong", {}, j.titulo),
          h("span", { class: "small" }, [GENERO[j.genero] ?? "", j.autor].filter(Boolean).join(" · ")),
          grande ? h("span", { class: "gal-jugar" }, "▶ Jugar") : null)),
      h("span", { class: "gal-jugadas", "aria-label": `${j.jugadas} partidas` }, `▶ ${j.jugadas}`),
      corazon);
    return tarjeta;
  }

  function pintarGeneros(): void {
    const presentes = [...new Set(juegos.map((j) => j.genero))].filter(Boolean);
    if (genero && !presentes.includes(genero)) presentes.unshift(genero);
    generos.replaceChildren(...[["", "Todos"] as [string, string], ...presentes.map((g) => [g, GENERO[g] ?? g] as [string, string])].map(([g, txt]) => {
      const b = h("button", { class: "chip" + (g === genero ? " activo" : ""), type: "button", role: "tab", "aria-selected": String(g === genero) }, txt);
      b.addEventListener("click", () => { genero = g; void cargar(); });
      return b;
    }));
  }

  function pintar(): void {
    const lista = visibles();
    if (!lista.length) {
      destacado.replaceChildren();
      rejilla.replaceChildren(h("p", { class: "muted gal-vacio" }, busca ? "Ningún juego coincide con tu búsqueda." : "Aún no hay juegos de este tipo. ¡Fabrica el primero en el Taller!"));
      return;
    }
    const [primero, ...resto] = lista;
    destacado.replaceChildren(busca ? h("span") : poster(primero, true));
    rejilla.replaceChildren(...(busca ? lista : resto).map((j) => poster(j)));
  }

  async function cargar(): Promise<void> {
    rejilla.replaceChildren(h("p", { class: "muted small" }, "Cargando..."));
    try {
      juegos = await app.api.escaparate(orden, genero || undefined);
    } catch (e) {
      rejilla.replaceChildren(bloqueError(e, "No se pudo cargar la galería.", () => void cargar()));
      return;
    }
    if (!vivo) return;
    if (!genero) pintarGeneros(); else for (const b of generos.children) b.classList.toggle("activo", b.textContent === (GENERO[genero] ?? genero));
    pintar();
  }

  void cargar();
  return {
    el: h("div", { class: "galeria" }, cabeza, ordenes, generos, destacado, rejilla, creadores),
    limpiar: () => { vivo = false; },
  };
}
