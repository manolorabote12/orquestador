// Tuercas: saldo, planes mensuales, anuncio con premio (opcional) y packs de Google Play.
// El móvil nunca se concede nada: el servidor verifica cada anuncio y cada compra con Google.

import type { App } from "../main";
import { type EstadoTienda, type Invitacion, type Periodo, type ProductoTienda } from "../api";
import { compartirEnlace } from "../compartir";
import { ICONOS, aviso, bloqueError, h, svg, type VistaHecha } from "../ui";
import { mensajeError } from "../errores";

export function vistaTuercas(app: App): VistaHecha {
  const raiz = h("div", { class: "wrap-inner" });
  let vivo = true;
  let periodo: Periodo = "mensual";

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
    if (t.plan) cabecera.querySelector(".sheet-head")?.append(h("span", { class: "pill done" }, t.plan === "pro" ? "Taller Pro" : "Plan Taller"));
    raiz.replaceChildren(cabecera, seccionPlanes(t), seccionAnuncio(t, saldo), seccionInvitar(), seccionPacks(t),
      h("p", { class: "muted small", style: "text-align:center" },
        "Los pagos los gestiona Google Play. Las tuercas de los packs no caducan. ¿Una compra no te llegó? Cierra y abre la app: se recupera sola."));
  }

  // Invita a un amigo: los dos ganan tuercas cuando el amigo hace su primera compra (lo da el
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
        h("p", { class: "muted small" }, `Cuando tu amigo haga su primera compra, los dos ganáis ${inv.por_amigo} tuercas.`),
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
            aviso(`¡Listo! Con tu primera compra, ganaréis ${inv.por_amigo} tuercas cada uno`);
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
    const b = h("button", { class: "btn btn-line", style: "width:100%" }, "Ver un anuncio (+3 tuercas)");
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
        aviso(r.visto ? "+3 tuercas" : "Para ganar las tuercas hay que ver el anuncio entero");
      } catch (e) {
        aviso(mensajeError(e, "No hay anuncios disponibles ahora. Prueba en un rato."));
      } finally {
        b.disabled = false;
        b.textContent = "Ver un anuncio (+3 tuercas)";
      }
    });
    return h("section", { class: "sheet" },
      h("div", { class: "sheet-head" }, h("h2", {}, "Gratis"), h("span", { class: "tag" }, "hasta 5 al día")), b);
  }

  function botonCompra(p: ProductoTienda, texto: string, etiqueta?: string): HTMLButtonElement {
    const precio = p.tipo === "plan" ? p.precios?.[periodo] ?? "" : p.precio;
    const b = h("button", { class: "btn btn-brass btn-small" }, etiqueta ?? (precio || "—"));
    if (!precio) b.disabled = true;
    b.addEventListener("click", async () => {
      b.disabled = true;
      try {
        const r = await app.api.comprar(p.id, periodo);
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

  // Planes mensuales: tuercas cada mes. Lo que se ofrece sale del servidor (tuercas por mes) y los
  // precios de Google Play; aquí solo se explica y se compra.
  function seccionPlanes(t: EstadoTienda): HTMLElement {
    const planes = t.productos.filter((x) => x.tipo === "plan").sort((a, b) => (a.tuercasMes ?? 0) - (b.tuercasMes ?? 0));
    const s = h("section", { class: "sheet planes" }, h("div", { class: "sheet-head" }, h("h2", {}, "Planes"),
      h("span", { class: "tag" }, "tuercas cada mes")));
    if (!planes.length) return h("span");
    const fecha = (iso: string | null) => iso ? new Date(iso).toLocaleDateString("es-ES", { day: "numeric", month: "long" }) : "";
    if (t.plan) {
      s.append(h("p", { class: "small" }, `Tienes el plan ${t.plan === "pro" ? "Taller Pro" : "Taller"}. `
        + (t.planEntrega ? `Tus próximas tuercas llegan el ${fecha(t.planEntrega)}.` : "")));
    } else {
      s.append(h("p", { class: "muted small" }, "Fabrica cada mes sin pensar en el saldo. Cancela cuando quieras desde Google Play."));
    }
    // Mensual o anual (el anual sale a 10 meses: 2 gratis).
    const seg = h("div", { class: "segmento", role: "radiogroup", "aria-label": "Forma de pago" });
    for (const [k, txt] of [["mensual", "Cada mes"], ["anual", "Cada año · 2 meses gratis"]] as [Periodo, string][]) {
      const b = h("button", { type: "button", role: "radio", "aria-checked": String(periodo === k), class: periodo === k ? "activo" : "" }, txt);
      b.addEventListener("click", () => { periodo = k; s.replaceWith(seccionPlanes(t)); });
      seg.append(b);
    }
    if (!t.plan) s.append(seg);
    const rango = (p?: string | null) => p === "pro" ? 2 : p === "taller" ? 1 : 0;
    const tarjetas = h("div", { class: "planes-grid" });
    for (const p of planes) {
      const mes = p.tuercasMes ?? 0;
      const juegos = Math.floor(mes / app.precio);
      const pro = p.plan === "pro";
      const mio = t.plan === p.plan;
      const ventajas = [
        `${mes.toLocaleString("es-ES")} tuercas cada mes (≈ ${juegos} juego${juegos === 1 ? "" : "s"})`,
        "Tus juegos se fabrican antes que la cola gratis",
        "Tu juego sale primero en la Lanzadera",
        ...(pro ? [`+${t.bonusPro} % de tuercas en cada pack`] : []),
      ];
      const precio = p.precios?.[periodo] ?? "";
      const pie: HTMLElement[] = [];
      if (mio) {
        const g = h("button", { class: "btn btn-line btn-small", type: "button" }, "Cambiar o cancelar");
        g.addEventListener("click", async () => {
          try { await app.api.gestionarPlan(); await pintar(); } catch (e) { aviso(mensajeError(e, "No se pudo abrir Google Play.")); }
        });
        pie.push(h("span", { class: "pill done" }, "Tu plan"), g);
      } else if (rango(p.plan) > rango(t.plan) || !t.plan) {
        pie.push(botonCompra(p, pro ? "¡Taller Pro activado!" : "¡Plan Taller activado!",
          precio ? `${t.plan ? "Pasar a Pro" : "Elegir"} · ${precio}${periodo === "anual" ? "/año" : "/mes"}` : undefined));
      }
      tarjetas.append(h("article", { class: "plan-card" + (pro ? " destacado" : "") + (mio ? " mio" : "") },
        h("h3", {}, pro ? "Taller Pro" : "Taller"),
        h("p", { class: "plan-precio" }, precio ? h("strong", {}, precio) : h("span", { class: "muted" }, "—"),
          h("span", { class: "muted small" }, precio ? (periodo === "anual" ? " al año" : " al mes") : "")),
        h("ul", { class: "plan-lista" }, ...ventajas.map((v) => h("li", {}, v))),
        h("div", { class: "plan-pie" }, ...pie)));
    }
    s.append(tarjetas, h("p", { class: "muted small" },
      `Las tuercas del plan se acumulan hasta ${t.topeMeses} meses. Se renueva sola; cancélala cuando quieras en Google Play y sigue activa hasta el final del periodo pagado.`));
    return s;
  }

  void pintar();
  return { el: raiz, limpiar: () => { vivo = false; } };
}
