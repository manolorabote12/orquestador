// Tuercas: saldo, anuncio con premio (opcional), packs y premium de Google Play.
// El móvil nunca se concede nada: el servidor verifica cada anuncio y cada compra con Google.

import type { App } from "../main";
import { type EstadoTienda, type Invitacion, type ProductoTienda } from "../api";
import { compartirEnlace } from "../compartir";
import { ICONOS, aviso, bloqueError, h, svg, type VistaHecha } from "../ui";
import { mensajeError } from "../errores";

export function vistaTuercas(app: App): VistaHecha {
  const raiz = h("div", { class: "wrap-inner" });
  let vivo = true;

  async function pintar() {
    const saldo = h("strong", {}, String(app.tuercas));
    const juegos = Math.floor(app.tuercas / app.precio);
    const cabecera = h("section", { class: "sheet" },
      h("div", { class: "sheet-head" }, h("h2", {}, "Tus tuercas")),
      h("div", { class: "balance" }, svg(ICONOS.tuerca), saldo),
      h("p", { class: "muted", style: "text-align:center" },
        `Un juego completo cuesta ${app.precio} tuercas. ` + (juegos > 0 ? `Te llega para ${juegos}.` : "Aún no te llega para uno.")));
    raiz.replaceChildren(cabecera, h("section", { class: "sheet" }, h("p", { class: "muted" }, "Cargando la tienda...")));
    let t: EstadoTienda;
    try {
      t = await app.api.tienda();
    } catch (e) {
      if (vivo) raiz.replaceChildren(cabecera, h("section", { class: "sheet" }, bloqueError(e, "No se pudo cargar la tienda.", () => void pintar())));
      return;
    }
    if (!vivo) return;
    raiz.replaceChildren(cabecera, seccionAnuncio(t, saldo), seccionInvitar(), seccionPacks(t), seccionPremium(t),
      h("p", { class: "muted small", style: "text-align:center" },
        "Los pagos los gestiona Google Play. Las tuercas no caducan. ¿Una compra no te llegó? Cierra y abre la app: se recupera sola."));
  }

  // Invita a un amigo: los dos ganan tuercas cuando el amigo fabrica su primer juego (lo da el
  // servidor; aquí solo se enseña el código y se apunta el de quien te invitó).
  function seccionInvitar(): HTMLElement {
    const cuerpo = h("div", { "aria-live": "polite" }, h("p", { class: "muted small" }, "Cargando tu código..."));
    const sec = h("section", { class: "sheet" }, h("div", { class: "sheet-head" }, h("h2", {}, "Invita a tus amigos")), cuerpo);
    void app.api.miInvitacion().then((inv: Invitacion) => {
      const web = (import.meta.env.VITE_WEB as string | undefined)?.replace(/\/$/, "");
      const texto = `Crea tus propios juegos con Orquestador. Entra con mi código ${inv.codigo} y ganamos ${inv.por_amigo} tuercas cada uno.`;
      const compartirB = h("button", { class: "btn btn-line btn-small", type: "button" }, "Compartir mi código");
      compartirB.addEventListener("click", async () => {
        const url = web ? `${web}/?invita=${inv.codigo}` : "";
        if (url) aviso((await compartirEnlace(url, texto)) === "copiado" ? "Enlace copiado" : "¡Compartido!");
        else {
          try { await navigator.clipboard.writeText(texto); aviso("Texto copiado"); } catch { aviso(inv.codigo); }
        }
      });
      const partes: (HTMLElement | string)[] = [
        h("p", { class: "muted small" }, `Cuando tu amigo fabrique su primer juego, los dos ganáis ${inv.por_amigo} tuercas.`),
        h("div", { class: "codigo-invita", "aria-label": "Tu código" }, inv.codigo),
        h("div", { class: "fila-botones" }, compartirB),
        h("p", { class: "muted small" }, inv.invitados
          ? `Has invitado a ${inv.invitados} ${inv.invitados === 1 ? "persona" : "personas"}; ${inv.pagados} ya ${inv.pagados === 1 ? "ha fabricado" : "han fabricado"} su juego (+${inv.ganadas} tuercas).`
          : "Aún no has invitado a nadie."),
      ];
      if (!inv.me_invito) {
        const campo = h("input", { type: "text", maxlength: "7", placeholder: "Código de quien te invitó", "aria-label": "Código de quien te invitó",
          autocapitalize: "characters", style: "text-transform:uppercase" }) as HTMLInputElement;
        const usar = h("button", { class: "btn btn-line btn-small", type: "button" }, "Usar código") as HTMLButtonElement;
        usar.addEventListener("click", async () => {
          usar.disabled = true;
          try {
            await app.api.usarInvitacion(campo.value);
            aviso(`¡Listo! Cuando fabriques tu primer juego, ganaréis ${inv.por_amigo} tuercas cada uno`);
            campo.closest(".invitado")?.remove();
          } catch (e) {
            aviso(mensajeError(e, "No se pudo usar el código."));
            usar.disabled = false;
          }
        });
        partes.push(h("div", { class: "invitado" }, h("p", { class: "small" }, "¿Te ha invitado alguien?"), h("div", { class: "chat-input" }, campo, usar)));
      }
      cuerpo.replaceChildren(...partes);
    }).catch(() => cuerpo.replaceChildren(h("p", { class: "muted small" }, "No se pudo cargar tu código.")));
    return sec;
  }

  function seccionAnuncio(t: EstadoTienda, saldo: HTMLElement): HTMLElement {
    const b = h("button", { class: "btn btn-line", style: "width:100%" }, "Ver un anuncio (+5 tuercas)");
    if (!t.anuncios) {
      b.disabled = true;
      b.textContent = "Anuncios con premio: en la app de Android";
    }
    b.addEventListener("click", async () => {
      b.disabled = true;
      b.textContent = "Cargando anuncio...";
      try {
        const r = await app.api.verAnuncio();
        app.ponerTuercas(r.tuercas);
        saldo.textContent = String(r.tuercas);
        aviso(r.visto ? "+5 tuercas" : "Para ganar las tuercas hay que ver el anuncio entero");
      } catch (e) {
        aviso(mensajeError(e, "No hay anuncios disponibles ahora. Prueba en un rato."));
      } finally {
        b.disabled = false;
        b.textContent = "Ver un anuncio (+5 tuercas)";
      }
    });
    return h("section", { class: "sheet" },
      h("div", { class: "sheet-head" }, h("h2", {}, "Gratis"), h("span", { class: "tag" }, "hasta 5 al día")), b);
  }

  function botonCompra(p: ProductoTienda, texto: string): HTMLButtonElement {
    const b = h("button", { class: "btn btn-brass btn-small" }, p.precio || "—");
    if (!p.precio) b.disabled = true;
    b.addEventListener("click", async () => {
      b.disabled = true;
      try {
        const r = await app.api.comprar(p.id);
        app.ponerTuercas(r.tuercas);
        aviso(texto);
        await pintar();
      } catch (e) {
        aviso(mensajeError(e, "No se pudo completar la compra."));
        b.disabled = false;
      }
    });
    return b;
  }

  function seccionPacks(t: EstadoTienda): HTMLElement {
    const s = h("section", { class: "sheet" }, h("div", { class: "sheet-head" }, h("h2", {}, "Packs")));
    if (t.aviso) s.append(h("p", { class: "muted small" }, t.aviso));
    for (const p of t.productos.filter((x) => x.tipo === "tuercas")) {
      const juegos = Math.floor(p.tuercas / app.precio);
      s.append(h("div", { class: "pack" },
        h("span", {}, svg(ICONOS.tuerca), ` ${p.tuercas.toLocaleString("es-ES")} tuercas`,
          h("small", { class: "muted" }, `  ≈ ${juegos} juego${juegos === 1 ? "" : "s"}`)),
        botonCompra(p, `+${p.tuercas} tuercas`)));
    }
    return s;
  }

  function seccionPremium(t: EstadoTienda): HTMLElement {
    const p = t.productos.find((x) => x.tipo === "premium");
    const s = h("section", { class: "sheet" }, h("div", { class: "sheet-head" }, h("h2", {}, "Premium"),
      t.premium ? h("span", { class: "pill done" }, "activo") : h("span", { class: "tag" }, "mensual")));
    s.append(h("p", { class: "small" }, "• Tu juego sale el primero en la Lanzadera (consigue sus 12 probadores antes)."),
      h("p", { class: "small" }, "• Sin tener que probar juegos de otros para que se vea el tuyo."),
      h("p", { class: "muted small" }, "Se renueva cada mes; puedes cancelarla cuando quieras desde Google Play."));
    if (t.premium && t.premiumHasta) {
      s.append(h("p", { class: "small" }, `Activo hasta el ${new Date(t.premiumHasta).toLocaleDateString("es-ES", { day: "numeric", month: "long" })}.`));
    } else if (p) {
      s.append(botonCompra(p, "¡Premium activado!"));
    }
    return s;
  }

  void pintar();
  return { el: raiz, limpiar: () => { vivo = false; } };
}
