// Escaparate: juegos de la comunidad para jugar al momento, dar me gusta y remezclar.
// Un remix copia el juego a "Mis juegos" y a partir de ahí se cambia en el taller como cualquier otro.

import type { App } from "../main";
import { type JuegoEscaparate } from "../api";
import { botonDenuncia } from "../denuncia";
import { abrirJugador } from "../jugador";
import { aviso, bloqueError, h } from "../ui";
import { mensajeError } from "../errores";

const GENERO: Record<string, string> = { plataformas: "Plataformas", runner: "Runner", volador: "Volador", horda: "Hordas",
  puzle: "Puzle", torres: "Torres", carreras: "Carreras", naves: "Naves", rompebloques: "Rompebloques", bloques: "Bloques",
  corredor: "Corredor 3D", serpiente: "Serpiente", memoria: "Memoria", cajas: "Cajas", preguntas: "Preguntas", apilar: "Apilar", topos: "Topos", saltos: "Saltos", arena: "Arena", aldea: "Aldea",
  ritmo: "Ritmo", clicker: "Clicker", cartas: "Cartas", rpg: "RPG por turnos",
  laberinto: "Laberinto", golf: "Minigolf", pesca: "Pesca", fusion: "Fusión", tubos: "Tubos", burbujas: "Burbujas" };

export function seccionEscaparate(app: App): HTMLElement {
  const lista = h("div", { class: "escaparate" }, h("p", { class: "muted small" }, "Cargando..."));
  const top = h("button", { class: "chip activo", type: "button" }, "Lo mejor");
  const nuevos = h("button", { class: "chip", type: "button" }, "Lo nuevo");
  const semana = h("button", { class: "chip", type: "button" }, "Top de la semana");
  const s = h("section", { class: "sheet" },
    h("div", { class: "sheet-head" }, h("h2", {}, "Juegos de la comunidad")),
    h("p", { class: "muted small" }, "Juégalos al momento. Si te gusta uno, haz un remix y cámbialo a tu manera en el taller."),
    h("div", { class: "chips" }, top, semana, nuevos), lista);

  async function cargar(orden: "top" | "nuevos" | "semana") {
    top.classList.toggle("activo", orden === "top");
    nuevos.classList.toggle("activo", orden === "nuevos");
    semana.classList.toggle("activo", orden === "semana");
    try {
      const juegos = await app.api.escaparate(orden);
      // En el top de la semana, la posición va delante (los 3 primeros con medalla).
      const tarjetas = juegos.map((j, i) => {
        const t = tarjeta(j);
        if (orden === "semana") t.prepend(h("span", { class: "puesto" + (i < 3 ? ` medalla-${i + 1}` : ""), "aria-label": `Puesto ${i + 1}` }, String(i + 1)));
        return t;
      });
      const vacio = orden === "semana" ? "Esta semana aún nadie ha jugado. ¡Comparte tu juego y estrena el ranking!" : "Aún no hay juegos. ¡Comparte el tuyo!";
      lista.replaceChildren(...(tarjetas.length ? tarjetas : [h("p", { class: "muted small" }, vacio)]));
    } catch (e) {
      lista.replaceChildren(bloqueError(e, "No se pudo cargar el escaparate.", () => void cargar(orden)));
    }
  }
  top.addEventListener("click", () => void cargar("top"));
  nuevos.addEventListener("click", () => void cargar("nuevos"));
  semana.addEventListener("click", () => void cargar("semana"));

  function tarjeta(j: JuegoEscaparate): HTMLElement {
    const f = app.api.archivosEscaparate(j);
    const icono = h("img", { class: "esc-icono", alt: "", loading: "lazy", src: f.icono });
    icono.addEventListener("error", () => { icono.style.visibility = "hidden"; });
    const jugar = h("button", { class: "esc-jugar", type: "button", "aria-label": `Jugar a ${j.titulo}` }, icono,
      h("strong", {}, j.titulo), h("span", { class: "muted small" }, [GENERO[j.genero] ?? "", j.autor].filter(Boolean).join(" · ")),
      h("span", { class: "small" }, `▶ ${j.jugadas}`));
    jugar.addEventListener("click", () => {
      const motor = app.api.motor();
      abrirJugador({ motor, pck: motor ? f.pck : null, titulo: j.titulo, portada: f.portada });
      void app.api.jugada(j.project_id).catch(() => undefined);
    });
    const corazon = h("button", { class: "btn btn-line btn-small", type: "button", "aria-label": "Me gusta" }, `♥ ${j.megusta}`);
    corazon.addEventListener("click", async () => {
      corazon.disabled = true;
      try {
        corazon.textContent = `♥ ${await app.api.meGusta(j.project_id)}`;
        corazon.classList.toggle("activo");
      } catch (e) {
        aviso(mensajeError(e, "No se pudo."));
      }
      corazon.disabled = false;
    });
    const remix = h("button", { class: "btn btn-brass btn-small", type: "button" }, "Remix");
    remix.addEventListener("click", async () => {
      remix.disabled = true;
      try {
        const r = await app.api.remix(j.project_id);
        aviso(`«${j.titulo}» ya está en Mis juegos: cámbialo en su taller`);
        app.ir("juegos", r.project_id);
      } catch (e) {
        aviso(mensajeError(e, "No se pudo hacer el remix."));
        remix.disabled = false;
      }
    });
    const t = h("div", { class: "esc-tarjeta" }, jugar, h("div", { class: "btn-row" }, corazon, remix));
    t.append(botonDenuncia("Denunciar", (m) => app.api.denunciar({ proyecto: j.project_id }, m), () => setTimeout(() => t.remove(), 1500)));
    return t;
  }

  void cargar("top");
  return s;
}

/** Primera vez en la app (aún sin juegos): el mejor juego de la comunidad, grande y para jugar en
 *  un toque. Ver uno terminado antes de escribir nada es lo que explica la app. null si no hay. */
export async function tarjetaBienvenida(app: App): Promise<HTMLElement | null> {
  let j: JuegoEscaparate | undefined;
  try {
    j = (await app.api.escaparate("top"))[0];
  } catch {
    return null;
  }
  if (!j) return null;
  const juego = j;
  const f = app.api.archivosEscaparate(juego);
  const img = h("img", { class: "bienvenida-portada", alt: `Captura de ${juego.titulo}`, src: f.portada });
  img.addEventListener("error", () => { img.src = f.icono; });
  const jugar = h("button", { class: "btn btn-brass", type: "button" }, "▶ Jugar ahora");
  const caja = h("section", { class: "sheet bienvenida", "aria-label": "Prueba un juego hecho con Orquestador" },
    h("div", { class: "sheet-head" }, h("h2", {}, "Juega antes de crear")),
    h("div", { class: "bienvenida-cuerpo" }, img,
      h("div", {},
        h("strong", {}, juego.titulo),
        h("p", { class: "muted small" }, [GENERO[juego.genero] ?? "", juego.autor].filter(Boolean).join(" · ")),
        h("p", { class: "small" }, "Lo creó alguien como tú escribiendo una idea. Pruébalo y luego haz el tuyo."),
        jugar)));
  jugar.addEventListener("click", () => {
    const motor = app.api.motor();
    abrirJugador({ motor, pck: motor ? f.pck : null, titulo: juego.titulo, portada: f.portada });
    void app.api.jugada(juego.project_id).catch(() => undefined);
  });
  return caja;
}
