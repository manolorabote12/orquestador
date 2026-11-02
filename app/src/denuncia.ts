// Denunciar contenido sin salir de la app (Google Play lo exige para contenido de IA y de otros
// usuarios). Un enlace discreto que se despliega con los motivos; se envía con un toque.

import { aviso, h } from "./ui";
import { mensajeError } from "./errores";

const MOTIVOS = ["Ofensivo o de odio", "Sexual o inapropiado", "Violencia", "Copia algo con derechos (personaje, marca...)", "Engañoso o spam", "Otro"];

export function botonDenuncia(texto: string, enviar: (motivo: string) => Promise<void>, alEnviar?: () => void): HTMLElement {
  const caja = h("div", { class: "denuncia" });
  const abrir = h("button", { class: "linkish small muted", type: "button" }, texto);
  caja.append(abrir);
  abrir.addEventListener("click", () => {
    const lista = h("div", { class: "chips" });
    for (const m of MOTIVOS) {
      const b = h("button", { class: "chip", type: "button" }, m);
      b.addEventListener("click", async () => {
        for (const x of lista.querySelectorAll("button")) (x as HTMLButtonElement).disabled = true;
        try {
          await enviar(m);
          caja.replaceChildren(h("p", { class: "small muted" }, "Gracias: lo revisaremos."));
          aviso("Denuncia enviada");
          alEnviar?.();
        } catch (e) {
          aviso(mensajeError(e, "No se pudo enviar."));
          for (const x of lista.querySelectorAll("button")) (x as HTMLButtonElement).disabled = false;
        }
      });
      lista.append(b);
    }
    const cancelar = h("button", { class: "linkish small", type: "button", onclick: () => caja.replaceChildren(abrir) }, "Cancelar");
    caja.replaceChildren(h("p", { class: "small" }, "¿Qué pasa con este contenido?"), lista, cancelar);
  });
  return caja;
}
