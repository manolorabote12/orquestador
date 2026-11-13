// Lanzadera: probadores reales para la prueba cerrada de Google Play (12 personas, 14 días).
// Intercambio justo: pruebas juegos de otros y la comunidad prueba el tuyo. Las opiniones son
// privadas para el autor; nunca se piden ni se premian reseñas en Google Play.

import type { App } from "../main";
import type { CampanaLz, MiCampanaLz, PanelLz, PruebaLz } from "../api";
import { botonDenuncia } from "../denuncia";
import { ICONOS, abrir, aviso, avisoError, bloqueError, h, svg, type VistaHecha } from "../ui";
import { recordarPruebas } from "../comodidad";
import { proyeccion, respuestasProduccion, textoRacha, textoRespuestas } from "../produccion";
import { GENERO_NOMBRE } from "../plantillas-datos";

export function vistaLanzadera(app: App): VistaHecha {
  const raiz = h("div", { class: "wrap-inner" });
  let vivo = true;

  async function pintar() {
    raiz.replaceChildren(h("section", { class: "sheet" }, h("p", { class: "muted" }, "Cargando la Lanzadera...")));
    try {
      const [panel, pruebas, lista, publicables] = await Promise.all([
        app.api.lzPanel(), app.api.lzPruebas(), app.api.lzLista(), app.api.lzPublicables()]);
      if (!vivo) return;
      // Recordatorio diario (19:00) para no perder la racha: 2 días sin jugar = abandono.
      void recordarPruebas(pruebas.filter((p) => p.estado === "activo"));
      raiz.replaceChildren(
        cabecera(panel),
        seccionPruebas(pruebas),
        seccionLista(lista),
        seccionMias(panel, publicables),
        normas());
    } catch (e) {
      if (!vivo) return;
      raiz.replaceChildren(h("section", { class: "sheet" }, bloqueError(e, "No se pudo cargar la Lanzadera.", () => void pintar())));
    }
  }

  async function hacer(boton: HTMLButtonElement, accion: () => Promise<unknown>, ok: string) {
    boton.disabled = true;
    try {
      await accion();
      aviso(ok);
      await pintar();
    } catch (e) {
      avisoError(e, "No se pudo hacer. Inténtalo de nuevo.");
      boton.disabled = false;
    }
  }

  function cabecera(panel: PanelLz): HTMLElement {
    const demo = app.api as unknown as { lzSiguienteDia?: () => Promise<void> };
    const visible = panel.visible_si_pruebas;
    return h("section", { class: "sheet" },
      h("div", { class: "stats" },
        h("div", { class: "stat" }, h("strong", {}, String(panel.puntos)), h("span", {}, "puntos")),
        h("div", { class: "stat" }, h("strong", {}, String(panel.probando)), h("span", {}, "probando")),
        h("div", { class: "stat" }, h("strong", {}, "12"), h("span", {}, "probadores que pide Google"))),
      h("details", { class: "como" }, h("summary", {}, "¿Cómo funciona?"),
        h("p", { class: "muted" }, "Google pide a las cuentas nuevas 12 probadores jugando 14 días seguidos antes de publicar. " +
          "Aquí os ayudáis: pruebas juegos de otros y la comunidad prueba el tuyo.")),
      h("p", { class: "small" }, visible
        ? h("span", { class: "pill done" }, panel.premium ? "Premium: tu campaña sale primero" : "Tu campaña se ve en la Lanzadera")
        : h("span", { class: "pill queued" }, (() => { const n = panel.minimo_probando - panel.probando; return `Prueba ${n} ${n === 1 ? "juego" : "juegos"} más y tu campaña saldrá aquí`; })())),
      demo.lzSiguienteDia
        ? h("button", { class: "linkish", onclick: async () => { await demo.lzSiguienteDia!(); aviso("Ha pasado un día (demo)"); await pintar(); } },
          "Pasar al día siguiente (solo en la demostración)")
        : "");
  }

  function barra(valor: number, total: number): HTMLElement {
    const pct = Math.max(0, Math.min(100, Math.round((100 * valor) / Math.max(1, total))));
    return h("div", { class: "nivel-dato" }, h("div", { class: "barra", role: "progressbar", "aria-valuenow": String(valor),
      "aria-valuemin": "0", "aria-valuemax": String(total) }, h("i", { style: `width:${pct}%` })));
  }

  function seccionPruebas(pruebas: PruebaLz[]): HTMLElement {
    const s = h("section", { class: "sheet" }, h("div", { class: "sheet-head" }, h("h2", {}, "Lo que estoy probando"),
      h("span", { class: "tag" }, `${pruebas.filter((p) => p.estado === "activo").length} activos`)));
    if (!pruebas.length) {
      s.append(h("p", { class: "muted" }, "Aún nada. Elige un juego de la lista de abajo: cada día que juegas sumas 1 punto, y 5 más al cumplir 14 días."));
      return s;
    }
    for (const p of pruebas) s.append(tarjetaPrueba(p));
    return s;
  }

  function tarjetaPrueba(p: PruebaLz): HTMLElement {
    const caja = h("div", { class: "paso" });
    const estado = p.estado === "completado" ? h("span", { class: "pill done" }, "completado")
      : p.estado === "abandonado" ? h("span", { class: "pill failed" }, "abandonado")
      : p.hecho_hoy ? h("span", { class: "pill done" }, "hoy hecho") : h("span", { class: "pill running" }, "juega hoy");
    caja.append(h("p", {}, h("strong", {}, p.titulo), " ", estado), barra(Math.min(p.dias, p.objetivo), p.objetivo),
      h("p", { class: "muted small" }, p.estado === "activo" ? textoRacha(p.dias, p.objetivo) : `Día ${Math.min(p.dias, p.objetivo)} de ${p.objetivo}`));
    if (p.estado === "abandonado") return caja;
    if (p.dias === 0) {
      caja.append(h("p", { class: "small" }, "Para entrar en la prueba, con la misma cuenta de Google que usas en Play Store:"),
        h("div", { class: "btn-row" },
          h("button", { class: "btn btn-line btn-small", onclick: () => void abrir(p.enlace_grupo) }, "1. Unirme al grupo"),
          h("button", { class: "btn btn-line btn-small", onclick: () => void abrir(p.enlace_prueba) }, "2. Ser probador e instalar")));
    } else {
      caja.append(h("button", { class: "linkish", onclick: () => void abrir(p.enlace_prueba) }, "Abrir en Google Play"));
    }
    if (!p.hecho_hoy) {
      const nivel = h("input", { type: "text", inputmode: "numeric", maxlength: "3", placeholder: "Nivel al que llegaste", "aria-label": "Nivel al que llegaste" });
      const opinion = h("textarea", { rows: "2", maxlength: "500", placeholder: "Opinión para el autor (opcional, solo la ve él)", "aria-label": "Opinión privada para el autor" });
      const boton = h("button", { class: "btn btn-brass" }, "He jugado hoy");
      boton.addEventListener("click", () => {
        const n = Number.parseInt(nivel.value, 10);
        void hacer(boton, async () => {
          const r = await app.api.lzCheckin(p.campana, Number.isFinite(n) ? n : 0, opinion.value.trim());
          if (r.completado) aviso("¡14 días cumplidos! +5 puntos");
        }, "+1 punto. ¡Gracias por probar!");
      });
      caja.append(h("div", { class: "form-col" }, nivel, opinion, boton));
    } else {
      caja.append(h("p", { class: "muted small" }, p.estado === "completado"
        ? "¡Cumplido! Si te gusta, sigue jugando: al autor le ayuda."
        : "Vuelve mañana. Si pasas 2 días sin jugar, la prueba se da por abandonada."));
    }
    return caja;
  }

  /** Cuantos probadores tiene de los 12 que pide Google: barra + texto (el texto es lo que se lee). */
  function barraProbadores(tiene: number, faltan: number): HTMLElement {
    const meta = 12;
    const n = Math.max(0, Math.min(meta, faltan > 0 ? meta - faltan : Math.max(tiene, meta)));
    const barra = h("div", { class: "lz-barra", role: "img", "aria-label": `${n} de ${meta} probadores` },
      h("span", { style: `width:${Math.round((n / meta) * 100)}%` }));
    return h("div", { class: "lz-prog" }, barra,
      h("p", { class: "small" }, faltan > 0 ? `${n} de ${meta} probadores · le faltan ${faltan}` : "Ya tiene 12; los de más le cubren si alguien abandona"));
  }

  function seccionLista(lista: CampanaLz[]): HTMLElement {
    const s = h("section", { class: "sheet" }, h("div", { class: "sheet-head" }, h("h2", {}, "Juegos que buscan probadores"),
      h("span", { class: "tag" }, String(lista.length))));
    if (!lista.length) {
      s.append(h("p", { class: "muted" }, "Ahora mismo no hay juegos nuevos que probar. Vuelve más tarde."));
      return s;
    }
    for (const c of lista) {
      const unirme = h("button", { class: "btn btn-brass btn-small" }, "Probarlo");
      unirme.addEventListener("click", () => void hacer(unirme, () => app.api.lzUnirme(c.campana), `Te has unido a «${c.titulo}». Sigue los 2 pasos de arriba.`));
      const tarjeta = h("div", { class: "paso" },
        h("p", {}, h("strong", {}, c.titulo), " ", c.premium ? h("span", { class: "tag" }, "destacado") : ""),
        c.nota ? h("p", { class: "muted small" }, c.nota) : "",
        barraProbadores(c.probadores, c.faltan),
        unirme);
      // 1 - Denunciar sin salir de la app: deja de verla al momento; con 3 denuncias se oculta para todos.
      tarjeta.append(botonDenuncia("Denunciar", (m) => app.api.denunciar({ campana: c.campana }, m), () => setTimeout(() => tarjeta.remove(), 1500)));
      s.append(tarjeta);
    }
    return s;
  }

  function seccionMias(panel: PanelLz, publicables: { id: string; titulo: string }[]): HTMLElement {
    const s = h("section", { class: "sheet" }, h("div", { class: "sheet-head" }, h("h2", {}, "Mis campañas")));
    for (const c of panel.campanas) s.append(tarjetaCampana(c));
    const libres = publicables.filter((p) => !panel.campanas.some((c) => c.project_id === p.id));
    if (!libres.length) {
      s.append(h("p", { class: "muted" }, panel.campanas.length ? "" :
        "Cuando subas un juego a la prueba cerrada de Google Play (en «Mis juegos»), podrás pedir probadores aquí."));
      return s;
    }
    const sel = h("select", { "aria-label": "Juego" });
    for (const p of libres) sel.append(h("option", { value: p.id }, p.titulo));
    const grupo = h("input", { type: "text", maxlength: "120", placeholder: "https://groups.google.com/g/tu-grupo", "aria-label": "Enlace de tu Grupo de Google" });
    const nota = h("input", { type: "text", maxlength: "300", placeholder: "Una frase para animar a probarlo (opcional)", "aria-label": "Nota para los probadores" });
    const abrirCampana = h("button", { class: "btn btn-brass" }, svg(ICONOS.cohete), "Pedir probadores");
    abrirCampana.addEventListener("click", () => void hacer(abrirCampana, () => app.api.lzAbrir(sel.value, grupo.value.trim(), nota.value.trim()), "Campaña abierta"));
    s.append(
      h("details", { class: "paso" }, h("summary", {}, h("span", {}, "Antes: crea tu Grupo de Google (2 minutos)")),
        h("p", {}, "1. En groups.google.com pulsa «Crear grupo». Ponle el nombre de tu juego."),
        h("p", {}, "2. En «Quién puede unirse», elige «Cualquier usuario de la Web»."),
        h("p", {}, "3. En Play Console → Prueba cerrada → Probadores, añade el correo del grupo (nombre@googlegroups.com) y guarda."),
        h("p", {}, "4. Copia aquí la dirección del grupo (https://groups.google.com/g/...).")),
      h("div", { class: "form-col" }, h("div", { class: "chat-input" }, sel), grupo, nota, abrirCampana));
    return s;
  }

  function tarjetaCampana(c: MiCampanaLz): HTMLElement {
    const caja = h("div", { class: "paso" });
    caja.append(h("p", {}, h("strong", {}, c.titulo), " ",
      c.estado === "lista" ? h("span", { class: "pill done" }, "¡lista para producción!") : h("span", { class: "pill running" }, "buscando probadores")),
      barra(c.completados, c.objetivo),
      h("p", { class: "small" }, `${c.completados} de ${c.objetivo} han cumplido ${c.dias} días · ${c.activos} jugando · ${c.abandonos} abandonos`));
    // Cuándo podrá pedir producción, contando las reservas (las campañas admiten hasta 18).
    const pr = proyeccion(c);
    if (c.estado !== "lista") {
      caja.append(h("p", { class: pr.riesgo ? "consejo" : "small" }, pr.riesgo
        ? `Con los que siguen jugando no llegas a ${c.objetivo}: faltan ${pr.faltan}. Comparte tu campaña o prueba más juegos para que salga antes en la lista.`
        : `Si siguen jugando, podrás pedir producción en ${pr.dias_restantes} día${pr.dias_restantes === 1 ? "" : "s"} (hacia el ${new Date(pr.fecha + "T12:00:00").toLocaleDateString("es-ES", { day: "numeric", month: "long" })}).`));
    }
    if (c.estado === "lista") {
      caja.append(h("p", { class: "consejo" }, "Ya tienes 12 probadores con 14 días. En Play Console → Panel → «Solicitar acceso a producción» " +
        "Google te hace unas preguntas: abajo las tienes respondidas con los datos de tu prueba."));
    }
    caja.append(seccionRespuestas(c));
    if (c.probadores.length) {
      const chips = h("div", { class: "chips" });
      for (const p of c.probadores) {
        chips.append(h("span", { class: "chip" + (p.estado === "completado" ? " on" : ""), title: p.estado },
          `P${p.n}: ${p.dias}d${p.estado === "abandonado" ? " ✕" : ""}`));
      }
      caja.append(chips);
    }
    if (c.opiniones.length) {
      const ops = h("details", {}, h("summary", {}, `Opiniones privadas (${c.opiniones.length})`));
      for (const o of c.opiniones) ops.append(h("p", { class: "small" }, h("strong", {}, `Probador ${o.probador} · nivel ${o.nivel}: `), o.opinion));
      caja.append(ops);
    }
    const cerrar = h("button", { class: "linkish" }, "Cerrar campaña");
    cerrar.addEventListener("click", () => {
      if (confirm(`¿Cerrar la campaña de «${c.titulo}»? Los probadores dejarán de verla.`)) void hacer(cerrar, () => app.api.lzCerrar(c.id), "Campaña cerrada");
    });
    caja.append(h("div", { class: "btn-row" },
      h("button", { class: "linkish", onclick: () => void abrir(c.enlace_grupo) }, "Ver mi grupo"), cerrar));
    return caja;
  }

  /** Respuestas para el cuestionario de producción de Google, con los datos reales de la campaña. */
  function seccionRespuestas(c: MiCampanaLz): HTMLElement {
    const cuerpo = h("div", {});
    const caja = h("details", { class: "paso" }, h("summary", {}, h("span", {}, "Respuestas para pedir producción")), cuerpo);
    let hecho = false;
    caja.addEventListener("toggle", () => {
      if (!caja.open || hecho) return;
      hecho = true;
      cuerpo.replaceChildren(h("p", { class: "muted small" }, "Preparando..."));
      void app.api.proyecto(c.project_id).then((p) => {
        const desde = c.creada ? new Date(c.creada).getTime() : 0;
        const cambios = p.versiones.filter((v) => new Date(v.created_at).getTime() >= desde && v.version > 1).map((v) => v.prompt);
        const rs = respuestasProduccion(c, { titulo: p.titulo, tipo: (GENERO_NOMBRE[p.genero ?? ""] ?? "juego").toLowerCase(),
          publico: p.publico ?? "todos", cambios });
        cuerpo.replaceChildren(
          h("p", { class: "muted small" }, "Salen de tu prueba real (probadores, días jugados, opiniones y versiones). Léelas y cambia lo que quieras antes de pegarlas en Play Console."),
          ...rs.map((r) => h("div", { class: "campo" }, h("span", { class: "muted small" }, r.pregunta), h("p", { class: "small" }, r.respuesta),
            h("button", { class: "linkish", onclick: () => void copiar(r.respuesta) }, "Copiar"))),
          h("button", { class: "btn btn-line btn-small", onclick: () => void copiar(textoRespuestas(rs)) }, "Copiar todas"));
      }).catch((e) => { hecho = false; cuerpo.replaceChildren(bloqueError(e, "No se pudieron preparar las respuestas.")); });
    });
    return caja;
  }

  async function copiar(texto: string): Promise<void> {
    try {
      await navigator.clipboard.writeText(texto);
      aviso("Copiado");
    } catch {
      aviso("No se pudo copiar: mantén pulsado el texto para seleccionarlo.");
    }
  }

  function normas(): HTMLElement {
    return h("section", { class: "sheet" },
      h("div", { class: "sheet-head" }, h("h2", {}, "Normas")),
      h("p", { class: "small" }, "• Juega de verdad cada día: Google comprueba que los probadores usan el juego."),
      h("p", { class: "small" }, "• No pidas ni dejes reseñas en Google Play a cambio de puntos: va contra las normas de Google. Tu opinión va solo al autor, aquí dentro."),
      h("p", { class: "small" }, "• Los puntos solo sirven para que tu campaña salga antes. No se compran ni se cambian por tuercas."),
      h("p", { class: "small" }, "• Nadie ve tu correo: te unes al grupo de cada juego con tu cuenta de Google."));
  }

  void pintar();
  return { el: raiz, limpiar: () => { vivo = false; } };
}
