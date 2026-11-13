// Tuercas: saldo, planes mensuales, anuncio con premio (opcional) y packs de Google Play.
// El móvil nunca se concede nada: el servidor verifica cada anuncio y cada compra con Google.

import type { App } from "../main";
import { type EstadoTienda, type Invitacion, type MisGanancias, type Periodo, type ProductoTienda } from "../api";
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
      h("div", { class: "sheet-head" }, h("h2", {}, "Saldo")),
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
    raiz.replaceChildren(cabecera, seccionPacks(t), seccionPlanes(t), seccionAnuncio(t, saldo), seccionGanancias(), seccionInvitar(),
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
    return h("section", { class: "sheet gratis" },
      h("div", { class: "sheet-head" }, h("h2", {}, "Gratis"), h("span", { class: "tag" }, "hasta 5 al día")),
      h("div", { class: "gratis-fila" }, h("img", { src: "objetos/anuncio.webp", alt: "", loading: "lazy" }), b));
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
    // Como en los juegos grandes: cofres de más pequeño a más grande, el de en medio «más popular».
    const packs = t.productos.filter((x) => x.tipo === "tuercas").sort((a, b) => a.tuercas - b.tuercas);
    const rejilla = h("div", { class: "packs" });
    packs.forEach((p, i) => {
      const juegos = Math.floor(p.tuercas / app.precio);
      const nivel = Math.min(3, Math.round(((i + 1) / Math.max(1, packs.length)) * 3));
      const cinta = packs.length >= 3 && i === Math.floor(packs.length / 2) ? "Más popular" : packs.length >= 2 && i === packs.length - 1 ? "Mejor valor" : "";
      rejilla.append(h("div", { class: "pack-carta" + (cinta ? " destacada" : "") },
        cinta ? h("em", { class: "pack-cinta" }, cinta) : "",
        h("img", { src: `objetos/pack_${nivel}.webp`, alt: "", loading: "lazy" }),
        h("strong", {}, p.tuercas.toLocaleString("es-ES")),
        h("span", { class: "muted small" }, `≈ ${juegos} juego${juegos === 1 ? "" : "s"}`),
        botonCompra(p, `+${p.tuercas} tuercas`)));
    });
    s.append(rejilla);
    return s;
  }

  // Planes mensuales: tuercas cada mes. Lo que se ofrece sale del servidor (tuercas por mes) y los
  // precios de Google Play; aquí solo se explica y se compra.
  // Ganancias de la galería: lo que pagan los anuncios vistos en tus juegos compartidos. Tú eliges:
  // pasarlo a tuercas (con premio) o cobrarlo en dinero por PayPal.
  function seccionGanancias(): HTMLElement {
    const s = h("section", { class: "sheet ganancias" }, h("div", { class: "sheet-head" }, h("h2", {}, "Lo que ganan tus juegos")),
      h("p", { class: "muted small" }, "Cargando..."));
    const euros = (c: number) => (c / 100).toLocaleString("es-ES", { style: "currency", currency: "EUR" });
    async function cargar() {
      let g: MisGanancias;
      try {
        g = await app.api.misGanancias();
      } catch (e) {
        s.replaceChildren(h("div", { class: "sheet-head" }, h("h2", {}, "Lo que ganan tus juegos")), bloqueError(e, "No se pudieron cargar tus ganancias.", () => void cargar()));
        return;
      }
      if (!vivo) return;
      const aTuercas = Math.floor((g.saldo_cent * g.tuercas_por_euro) / 100);
      const pasar = h("button", { class: "btn btn-brass btn-small", type: "button" }, `Pasar a tuercas · ${aTuercas}`);
      pasar.disabled = g.saldo_cent < 10;
      pasar.addEventListener("click", async () => {
        pasar.disabled = true;
        try {
          const r = await app.api.gananciasATuercas(g.saldo_cent);
          app.ponerTuercas(r.credits);
          aviso(`+${r.tuercas} tuercas`);
          await cargar();
        } catch (e) {
          aviso(mensajeError(e, "No se pudo pasar a tuercas."));
          pasar.disabled = false;
        }
      });
      const cobrar = h("button", { class: "btn btn-line btn-small", type: "button" },
        !g.cobro_activo ? "Cobrar en dinero · pronto" : g.saldo_cent < g.cobro_minimo_cent ? `Cobrar en dinero · desde ${euros(g.cobro_minimo_cent)}` : "Cobrar en dinero");
      cobrar.disabled = !g.cobro_activo || g.saldo_cent < g.cobro_minimo_cent;
      const formulario = h("form", { class: "cobro-form", hidden: true });
      const paypal = h("input", { type: "email", placeholder: "Tu correo de PayPal", autocomplete: "email", required: "" }) as HTMLInputElement;
      const nombre = h("input", { type: "text", placeholder: "Tu nombre y apellidos", autocomplete: "name", required: "" }) as HTMLInputElement;
      const mayor = h("input", { type: "checkbox" }) as HTMLInputElement;
      const enviar = h("button", { class: "btn btn-brass btn-small", type: "submit" }, `Pedir ${euros(g.saldo_cent)}`);
      formulario.append(paypal, nombre, h("label", { class: "fila-check small" }, mayor, "Soy mayor de edad y los datos son míos"), enviar,
        h("p", { class: "muted small" }, "Se paga por PayPal en los primeros días del mes siguiente."));
      cobrar.addEventListener("click", () => { formulario.hidden = !formulario.hidden; if (!formulario.hidden) paypal.focus(); });
      formulario.addEventListener("submit", async (e) => {
        e.preventDefault();
        enviar.disabled = true;
        try {
          const r = await app.api.pedirCobro(paypal.value.trim(), nombre.value.trim(), mayor.checked);
          aviso(`Cobro de ${euros(r.cent)} pedido`);
          await cargar();
        } catch (err) {
          aviso(mensajeError(err, "No se pudo pedir el cobro."));
          enviar.disabled = false;
        }
      });
      const nombres: Record<string, string> = { reparto: "Reparto", a_tuercas: "A tuercas", cobro: "Cobro", cobro_devuelto: "Cobro devuelto" };
      s.replaceChildren(
        h("div", { class: "sheet-head" }, h("h2", {}, "Lo que ganan tus juegos"), h("span", { class: "tag" }, `${g.reparto_pct} % de sus anuncios`)),
        h("div", { class: "gan-saldo" }, h("strong", {}, euros(g.saldo_cent)), h("span", { class: "muted small" }, `ganado en total ${euros(g.ganado_cent)}`)),
        h("p", { class: "small" }, g.por_juego.length
          ? `Este mes, ${g.anuncios_mes} anuncio${g.anuncios_mes === 1 ? "" : "s"} vistos en tus juegos. Se reparte a principios del mes siguiente.`
          : "Comparte un juego en la galería (Mis juegos → Compartir): cada anuncio que se vea jugando a él te da una parte."),
        g.por_juego.length ? h("ul", { class: "gan-juegos" }, ...g.por_juego.slice(0, 5).map((x) => h("li", {}, h("span", {}, x.titulo), h("span", { class: "muted" }, `${x.anuncios}`)))) : h("span"),
        h("div", { class: "btn-row" }, pasar, cobrar), formulario,
        h("p", { class: "muted small" }, `En tuercas te llevas ${g.tuercas_por_euro} por cada euro (comprándolas son unas 100).`),
        g.movimientos.length ? h("details", { class: "plegable" }, h("summary", {}, h("h3", {}, "Movimientos")),
          h("ul", { class: "gan-movs" }, ...g.movimientos.map((m) => h("li", {},
            h("span", {}, nombres[m.tipo] ?? m.tipo, m.nota ? h("span", { class: "muted small" }, ` · ${m.nota}`) : ""),
            h("span", { class: m.cent >= 0 ? "ok" : "muted" }, `${m.cent >= 0 ? "+" : ""}${euros(m.cent)}${m.tuercas ? ` → ${m.tuercas} tuercas` : ""}`))))) : h("span"));
    }
    void cargar();
    return s;
  }

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
        h("div", { class: "plan-cabeza" }, h("h3", {}, pro ? "Taller Pro" : "Taller"),
          h("img", { class: "plan-img", src: pro ? "objetos/plan_pro.webp" : "objetos/pack_2.webp", alt: "", loading: "lazy" })),
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
