// «Ver cómo lo verá»: la dedicatoria del juego regalo en tres pasos, como la verá quien lo recibe
// (el enlace, al abrir el juego y al superar el nivel), antes de mandarlo.
import type { RegaloJuego } from "../regalo";
import { h } from "../ui";

export function abrirVistaRegalo(r: RegaloJuego, titulo: string, niveles: number): void {
  const nivel = r.tras_nivel > 0 ? Math.min(r.tras_nivel, Math.max(niveles, 1)) : Math.max(niveles, 1);
  const pantalla = h("div", { class: "rv-pantalla", "aria-live": "polite" });
  const paso = h("p", { class: "rv-paso" });
  const siguiente = h("button", { class: "btn btn-brass", type: "button" }) as HTMLButtonElement;
  const cerrar = h("button", { class: "player-close", type: "button", "aria-label": "Cerrar la vista previa" }, "✕");
  const capa = h("div", { class: "player rv", role: "dialog", "aria-modal": "true", "aria-label": "Vista previa del regalo" },
    h("div", { class: "player-bar" }, h("strong", {}, `Así lo verá ${r.para}`), cerrar),
    h("div", { class: "rv-cuerpo" }, paso, h("div", { class: "rv-movil" }, pantalla), siguiente));
  let n = 0;
  const pasos: (() => void)[] = [
    () => {
      paso.textContent = "1 de 3 · Al abrir tu enlace";
      pantalla.replaceChildren(h("div", { class: "rv-web" }, h("h2", {}, `🎁 Para ${r.para}`),
        h("p", {}, `Un juego hecho para ti por ${r.de}. Hay un mensaje escondido dentro.`), h("span", { class: "rv-boton" }, "Abrir el regalo")));
      siguiente.textContent = "Siguiente";
    },
    () => {
      paso.textContent = "2 de 3 · La primera vez que abre el juego";
      pantalla.replaceChildren(h("div", { class: "rv-titulo" }, titulo), h("div", { class: "rv-panel" }, h("h3", {}, "Un regalo para ti"),
        h("p", { class: "rv-dorado" }, `Para ${r.para}`, h("br"), `de ${r.de}`),
        h("p", {}, `Hay un mensaje escondido: aparece al superar el nivel ${nivel}.`), h("span", { class: "rv-boton" }, "¡A jugar!")));
      siguiente.textContent = "Siguiente";
    },
    () => {
      paso.textContent = `3 de 3 · Al superar el nivel ${nivel}`;
      pantalla.replaceChildren(h("div", { class: "rv-titulo" }, titulo), h("div", { class: "rv-panel" }, h("h3", {}, "Tu mensaje"),
        h("p", { class: "rv-dorado" }, `Para ${r.para}`, h("br"), `de ${r.de}`),
        h("p", { class: "rv-mensaje" }, r.mensaje), h("span", { class: "rv-boton rv-boton-gris" }, "Cerrar")));
      siguiente.textContent = "Volver a empezar";
    },
  ];
  const ir = (i: number) => { n = i; pasos[i](); };
  siguiente.addEventListener("click", () => ir((n + 1) % pasos.length));
  const salir = () => { capa.remove(); document.removeEventListener("keydown", tecla); };
  const tecla = (e: KeyboardEvent) => { if (e.key === "Escape") salir(); };
  cerrar.addEventListener("click", salir);
  document.addEventListener("keydown", tecla);
  ir(0);
  document.body.append(capa);
  siguiente.focus();
}
