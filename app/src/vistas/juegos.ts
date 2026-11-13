// Mis juegos: lista y ficha de cada juego con su taller por instrucciones.
// En la ficha hablas con Chispa: le das una instrucción, te dice qué hará y cuánto cuesta, la
// aplicas y ves el progreso. Cada cambio es una versión y puedes volver a cualquiera.

import { abrirEditor } from "./editor";
import { botonDenuncia } from "../denuncia";
import type { App } from "../main";
import { type Funcion, type CuentaPlay, type ModoYoutube, type Entrada, type Marketing, type PasoGuia, type Propuesta, type Proyecto, type Resena, type Trabajo } from "../api";
import { compartir, compartirEnlace, enlaceConTarjeta } from "../compartir";
import { diagnosticar, MIN_INTENTOS } from "../aprendizaje";
import { aconsejar, type Accion } from "../asesor";
import { veredictoAb } from "../ab";
import { GENERO_NOMBRE, GIROS, MONETIZACION, PERFIL_GENERO } from "../plantillas-datos";
import { planRedes } from "../redes";
import { pasosLanzamiento, siguientePaso, type AccionPaso } from "../lanzamiento";
import { seccionGanancias } from "./ganancias";
import { botonReto } from "./reto";
import qrcode from "qrcode-generator";
import { ICONOS, abrir, aviso, avisoError, bloqueError, h, hace, svg, type VistaHecha, fotoGenero } from "../ui";
import { abrirClip, abrirJugador } from "../jugador";
import { mensajeError } from "../errores";
import { ALTO, ANCHO, dibujarCartel, modulosQr } from "../cartel";
import { atasco, csvClase, haceCuanto, resumenClase, type Clase } from "../clase";
import { abrirVistaRegalo } from "./regalo-vista";
import { idioma } from "../idioma";
import { OCASIONES, estadoRegalo, validarRegalo, type RegaloJuego } from "../regalo";
import { IDEAS_PREMIO, codigoValido, resumenPremio, textoCanje, validarPremio, type PremioReal } from "../premio";

// Pantalla vacía: el plano de un móvil a medio dibujar (líneas de trazos que avanzan).

const ESTADOS: Record<Trabajo["status"], string> = {
  queued: "en cola", running: "fabricando", done: "listo", failed: "no salió",
};

const SUGERENCIAS = ["Pon un jefe final", "Ponlo en 3D", "Ponle una historia con diálogos", "Conviértelo en hordas", "Conviértelo en tower defense", "Hazlo de carreras", "Conviértelo en puzle", "Conviértelo en runner", "Que dispare bolas de fuego", "Música más épica", "Añade un nivel",
  "Que vuele de un toque", "Haz al héroe de otro color", "Más difícil"];


export type PestanaJuego = "taller" | "publicar" | "compartir" | "jugadores";
/** La última pestaña abierta en la ficha de un juego (se recuerda al cambiar de juego). */
let pestanaJuego: PestanaJuego = "taller";
/** Sección a la que bajar al abrir la ficha (data-seccion), p. ej. al venir del taller. */
let seccionPendiente = "";

/** La próxima ficha que se abra lo hará en esa pestaña y bajará a esa sección. */
export function abrirSeccion(pestana: PestanaJuego, seccion = ""): void {
  pestanaJuego = pestana;
  seccionPendiente = seccion;
}

export function vistaJuegos(app: App, detalle?: string): VistaHecha {
  const raiz = h("div", { class: "wrap-inner" });
  let vivo = true;
  let dejarDeSeguir: (() => void) | null = null;

  function parar() {
    dejarDeSeguir?.();
    dejarDeSeguir = null;
  }

  function icono(ruta?: string, clase = "game-icon") {
    const img = h("img", { class: clase, alt: "" });
    if (ruta) void app.api.url(ruta).then((u) => { img.src = u; }).catch(() => undefined);
    return img;
  }

  async function verClip(p: Proyecto) {
    if (!p.files?.clip) return aviso("Esta versión aún no tiene clip. El próximo cambio lo grabará.");
    try {
      abrirClip(await app.api.url(p.files.clip), p.titulo);
    } catch (e) {
      aviso(mensajeError(e, "No se pudo abrir el clip."));
    }
  }

  function etiqueta<T extends HTMLElement>(el: T, texto: string): T {
    el.setAttribute("aria-label", texto);
    el.title = texto;
    return el;
  }

  function botonArchivo(clase: string, ico: string, texto: string, ruta?: string) {
    return h("button", {
      class: clase,
      style: "width:100%",
      onclick: async () => {
        if (!ruta) return aviso("Este archivo no está disponible en esta versión.");
        try {
          await abrir(await app.api.url(ruta));
        } catch (e) {
          aviso(mensajeError(e, "No se pudo abrir."));
        }
      },
    }, svg(ico), texto);
  }

  // ------------------------------------------------------------------ lista

  async function lista(): Promise<void> {
    cartel(true);
    parar();
    raiz.replaceChildren(h("section", { class: "sheet" }, h("div", { class: "sheet-head" }, h("h2", {}, "Mis juegos")), h("p", { class: "muted" }, "Cargando...")));
    let entradas: Entrada[];
    try {
      entradas = await app.api.juegos();
    } catch (e) {
      raiz.replaceChildren(h("section", { class: "sheet" }, bloqueError(e, "No se pudieron cargar tus juegos.", () => void lista())));
      return;
    }
    if (!vivo) return;
    if (detalle) {
      const id = detalle;
      detalle = undefined;
      return ficha(id);
    }
    const tarjetas = h("div", { class: "games" });
    for (const e of entradas) {
      if (e.tipo === "proyecto") {
        // 1 - Tarjeta con la captura del juego en marcha (si la hay), su tipo y sus giros.
        const giros = (e.giros ?? []).map((id) => GIROS.find((g) => g.id === id)?.nombre ?? id).slice(0, 2);
        const portada = e.portada ? icono(e.portada, "game-cover") : icono(e.icono);
        tarjetas.append(h("button", { class: "game-card" + (e.portada ? " con-portada" : ""), onclick: () => void ficha(e.id),
          "data-buscar": `${e.titulo} ${GENERO_NOMBRE[e.genero ?? ""] ?? e.genero ?? ""}`.toLowerCase(), "data-genero": e.genero ?? "" },
          portada,
          h("div", { class: "game-card-txt" },
            h("h3", {}, e.titulo),
            e.genero ? h("p", { class: "game-genero" }, GENERO_NOMBRE[e.genero] ?? e.genero) : "",
            giros.length ? h("div", { class: "game-giros" }, ...giros.map((g) => h("span", { class: "giro-chip" }, g))) : "",
            h("div", {},
              h("span", { class: "pill " + (e.ocupado ? "running" : "done") }, e.ocupado ? "cambiando" : `versión ${e.version}`), " ",
              h("span", { class: "tag" }, hace(e.fecha))))));
      } else {
        const t = e.trabajo;
        tarjetas.append(h("button", { class: "game-card", onclick: () => t.status === "failed" ? aviso(t.refunded ? "No salió y te devolvimos las tuercas." : "No salió.") : app.ir("taller"),
          "data-buscar": `${t.titulo ?? ""} ${t.idea}`.toLowerCase(), "data-genero": "" },
          icono(undefined),
          h("div", {},
            h("h3", {}, t.titulo ?? "Juego nuevo"),
            h("p", {}, t.idea),
            h("span", { class: "pill " + t.status }, ESTADOS[t.status]), " ",
            h("span", { class: "tag" }, hace(t.created_at)))));
      }
    }
    const cuerpo = entradas.length ? tarjetas : h("div", { class: "empty" },
      h("p", {}, "Todavía no has fabricado ningún juego."),
      h("div", { class: "vacio-ideas", "aria-hidden": "true" }, ...["plataformas", "puzle", "horda"].map((id) => fotoGenero(id, { width: "96", height: "170" }))),
      h("div", { style: "height:12px" }),
      h("button", { class: "btn btn-brass", onclick: () => app.ir("taller") }, "Ir al taller"));
    // 2 - Con juegos ya hechos: invitar al siguiente (lo que más hace volver a la app).
    const siguiente = entradas.length ? h("section", { class: "sheet siguiente" },
      h("div", { class: "sheet-head" }, h("h2", {}, "Tu próximo juego")),
      h("p", { class: "muted small" }, "Cada juego que publicas es una oportunidad más de dar con el que triunfa. Pide a Chispa tres ideas originales a partir de una palabra."),
      h("button", { class: "btn btn-line", style: "width:100%", onclick: () => app.ir("taller") }, "Ir al taller")) : "";
    raiz.replaceChildren(h("section", { class: "sheet" },
      h("div", { class: "sheet-head" }, h("h2", {}, "Mis juegos"), h("span", { class: "tag" }, String(entradas.length))),
      entradas.length > 4 ? buscador(tarjetas) : "", cuerpo), siguiente);
  }

  /** 3 - Con muchos juegos: buscar por nombre o idea y filtrar por tipo de juego. */
  function buscador(tarjetas: HTMLElement): HTMLElement {
    const q = h("input", { type: "search", placeholder: "Buscar en mis juegos", "aria-label": "Buscar en mis juegos", class: "buscar" });
    const generos = [...new Set([...tarjetas.querySelectorAll<HTMLElement>("[data-genero]")].map((c) => c.dataset.genero ?? "").filter(Boolean))];
    let genero = "";
    const chips = h("div", { class: "chips desliza", role: "list", "aria-label": "Filtrar por tipo" });
    const vacio = h("p", { class: "muted small", hidden: true }, "Ningún juego coincide.");
    const aplicar = () => {
      const t = q.value.trim().toLowerCase();
      let vistos = 0;
      for (const c of tarjetas.querySelectorAll<HTMLElement>("[data-buscar]")) {
        const ok = (!t || (c.dataset.buscar ?? "").includes(t)) && (!genero || c.dataset.genero === genero);
        c.hidden = !ok;
        if (ok) vistos++;
      }
      vacio.hidden = vistos > 0;
      for (const b of chips.querySelectorAll<HTMLButtonElement>(".chip")) b.classList.toggle("on", (b.dataset.g ?? "") === genero);
    };
    const chip = (g: string, nombre: string) => h("button", { class: "chip" + (g === genero ? " on" : ""), type: "button", "data-g": g,
      onclick: () => { genero = g; aplicar(); } }, nombre);
    if (generos.length > 1) chips.append(chip("", "Todos"), ...generos.map((g) => chip(g, GENERO_NOMBRE[g] ?? g)));
    q.addEventListener("input", aplicar);
    return h("div", { class: "buscador" }, q, generos.length > 1 ? chips : "", vacio);
  }

  // ------------------------------------------------------------------ jugar sin instalar

  async function jugar(p: Proyecto): Promise<void> {
    const motor = app.api.motor();
    let pck: string | null = null;
    let portada: string | undefined;
    try {
      if (motor && p.files?.web) pck = await app.api.url(p.files.web);
      const captura = p.files?.capturas?.[2] ?? p.files?.capturas?.[0];
      if (!pck && captura) portada = await app.api.url(captura);
    } catch (e) {
      if (motor) return aviso(mensajeError(e, "No se pudo abrir el juego."));
    }
    try { localStorage.setItem(`orq-jugado-${p.id}`, "1"); } catch { /* sin almacenamiento */ }
    abrirJugador({ motor, pck, titulo: p.titulo, portada });
  }

  // ------------------------------------------------------------------ centro de lanzamiento

  /** De «recién fabricado» a «en producción»: qué paso toca ahora (con su botón) y todos los demás. */
  function seccionLanzamiento(p: Proyecto, hacer: (a: AccionPaso) => void): HTMLElement {
    const sec = h("section", { class: "sheet lanzamiento" });
    let jugado = false;
    try { jugado = localStorage.getItem(`orq-jugado-${p.id}`) === "1"; } catch { /* sin almacenamiento */ }
    const pintarCon = (campana: "abierta" | "lista" | null) => {
      const pasos = pasosLanzamiento({ jugado, anuncios: Boolean(p.admob), infantil: p.publico === "infantil",
        play: p.play?.estado ?? null, pista: p.play?.pista ?? null, campana });
      const sig = siguientePaso(pasos);
      const hechos = pasos.filter((x) => x.hecho).length;
      const puntos = h("ol", { class: "lz-camino", "aria-label": `${hechos} de ${pasos.length} pasos hechos` },
        ...pasos.map((x) => h("li", { class: x.hecho ? "hecho" : x === sig ? "ahora" : "", title: x.titulo })));
      const lista = h("details", {}, h("summary", { class: "small" }, "Ver todos los pasos"),
        ...pasos.map((x) => h("p", { class: "small" + (x.hecho ? " muted" : "") }, `${x.hecho ? "✓" : x === sig ? "→" : "·"} ${x.titulo}`)));
      sec.replaceChildren(
        h("div", { class: "sheet-head" }, h("h2", {}, "Camino a Google Play"), h("span", { class: "tag" }, `${hechos}/${pasos.length}`)),
        puntos,
        sig ? h("div", { class: "lz-siguiente" }, h("strong", {}, sig.titulo), h("p", { class: "muted small" }, sig.ayuda),
          h("button", { class: "btn btn-brass btn-small", type: "button", onclick: () => hacer(sig.accion) }, sig.boton))
          : h("p", { class: "small" }, "¡Publicado en Google Play! Ahora, a por jugadores: mira la pestaña Compartir."),
        lista);
    };
    pintarCon(null);
    void app.api.lzPanel().then((panel) => {
      const c = panel.campanas.find((x) => x.project_id === p.id);
      if (c) pintarCon(c.estado);
    }).catch(() => { /* sin Lanzadera: se queda sin campaña */ });
    return sec;
  }

  // ------------------------------------------------------------------ vídeos para redes

  function seccionVideos(p: Proyecto, precio: number, encargar: () => void): HTMLElement {
    const m = p.files?.marketing;
    const cab = h("div", { class: "sheet-head" }, h("h2", {}, "Vídeos para redes"), h("span", { class: "tag" }, "TikTok · Shorts · Reels"));
    if (!m) {
      return h("section", { class: "sheet" }, cab,
        h("p", { class: "muted" }, "Chispa graba los mejores momentos jugando, escribe 3 guiones (reto, curiosidad y humor) y monta 3 vídeos verticales con subtítulos, voz en off y la música de tu juego. Con el texto y los hashtags para publicar."),
        bloqueYoutube(),
        h("button", { class: "btn btn-brass", style: "width:100%", onclick: () => encargar() }, svg(ICONOS.video), `Crear 3 vídeos con IA · ${precio} tuercas`));
    }
    const nombres: Record<string, string> = { reto: "Reto", curiosidad: "Curiosidad", humor: "Humor" };
    const tarjetas = h("div", { class: "mk-grid" });
    for (const v of m.videos) {
      const img = h("img", { alt: "", loading: "lazy" });
      void app.api.url(v.portada).then((u) => { img.src = u; }).catch(() => img.remove());
      const ver = async () => {
        try {
          const [u, portada] = await Promise.all([app.api.url(v.mp4), app.api.url(v.portada).catch(() => undefined)]);
          abrirClip(u, `${p.titulo} · ${nombres[v.estilo] ?? v.estilo}`, portada);
        } catch (e) {
          aviso(mensajeError(e, "No se pudo abrir el vídeo."));
        }
      };
      tarjetas.append(h("div", { class: "mk-card" },
        h("button", { class: "mk-thumb", onclick: () => void ver(), "aria-label": `Ver el vídeo ${v.gancho}` }, img, svg(ICONOS.jugar)),
        h("span", { class: "tag" }, nombres[v.estilo] ?? v.estilo),
        h("strong", {}, v.gancho),
        h("button", { class: "btn btn-line btn-small", onclick: () => void compartirVideo(v.mp4, v.estilo, m, idioma) }, "Compartir")));
    }
    let idioma: "es" | "en" = "es";
    const bEs = h("button", { class: "chip on", type: "button" }, "Español");
    const bEn = h("button", { class: "chip", type: "button" }, "English");
    const cambiar = (i: "es" | "en") => {
      idioma = i;
      bEs.classList.toggle("on", i === "es");
      bEn.classList.toggle("on", i === "en");
    };
    bEs.addEventListener("click", () => cambiar("es"));
    bEn.addEventListener("click", () => cambiar("en"));
    const copiar = (cual: "tiktok" | "reels" | "shorts") => {
      const r = m.redes[idioma];
      const t = cual === "shorts" ? `${r.shorts_titulo}\n\n${r.shorts_descripcion}` : r[cual];
      void copiarTexto(t);
    };
    return h("section", { class: "sheet" }, cab, tarjetas,
      h("div", { class: "chips" }, bEs, bEn),
      h("div", { class: "mk-copy" },
        h("button", { class: "btn btn-line btn-small", onclick: () => copiar("tiktok") }, "Copiar texto TikTok"),
        h("button", { class: "btn btn-line btn-small", onclick: () => copiar("reels") }, "Copiar texto Reels"),
        h("button", { class: "btn btn-line btn-small", onclick: () => copiar("shorts") }, "Copiar título Shorts")),
      h("div", { style: "height:10px" }),
      botonArchivo("btn btn-line", ICONOS.caja, "Todo junto (.zip)", m.zip),
      h("div", { style: "height:8px" }),
      m.trailer ? h("div", { style: "height:8px" }) : null,
      m.trailer ? h("button", { class: "btn btn-line", style: "width:100%", onclick: () => void verTrailer(m.trailer!) }, svg(ICONOS.video), "Ver tráiler horizontal (Google Play / YouTube)") : null,
      m.youtube?.videos.length ? h("p", { class: "small" }, h("span", { class: "pill done" }, "en YouTube"), ` ${m.youtube.videos.length} vídeos `,
        h("button", { class: "linkish", onclick: () => void abrir(m.youtube!.videos[0].url) }, "Ver en YouTube")) : null,
      m.youtube?.error ? h("p", { class: "muted small" }, `YouTube: ${m.youtube.error}`) : null,
      h("div", { style: "height:8px" }),
      bloqueYoutube(),
      h("button", { class: "linkish", onclick: () => encargar() }, `Hacer otros 3 vídeos (${precio} tuercas)`),
      m.voz === "ninguna" ? h("p", { class: "muted small" }, "Sin voz en off: la fábrica no tiene voz configurada (Piper o ElevenLabs).") : null);
  }

  async function verTrailer(ruta: string) {
    try {
      abrirClip(await app.api.url(ruta), "Tráiler");
    } catch {
      aviso("No se pudo abrir el tráiler.");
    }
  }

  /** YouTube: conectar el canal una vez y elegir si los vídeos nuevos se suben solos. */
  function modoYoutube(): ModoYoutube {
    try {
      const v = localStorage.getItem("orq-yt-modo");
      return v === "oculto" || v === "publico" ? v : "no";
    } catch {
      return "no";
    }
  }

  function bloqueYoutube(): HTMLElement {
    const caja = h("div", { class: "paso" }, h("p", { class: "muted small" }, "Comprobando YouTube..."));
    void app.api.youtubeEstado().then((e) => {
      if (!e.conectado) {
        const b = h("button", { class: "btn btn-line btn-small" }, "Conectar mi canal de YouTube");
        b.addEventListener("click", async () => {
          try {
            const url = await app.api.youtubeConectar();
            if (url) await abrir(url);
            else caja.replaceWith(bloqueYoutube());
          } catch (err) {
            aviso(mensajeError(err, "No se pudo conectar con YouTube."));
          }
        });
        caja.replaceChildren(h("p", { class: "small" }, "Sube los Shorts y el tráiler a tu canal sin hacer nada más."), b);
        return;
      }
      const sel = h("select", { "aria-label": "Subir a YouTube" },
        ...([["no", "No subir a YouTube"], ["oculto", "Subir ocultos (los revisas tú)"], ["publico", "Subir públicos"]] as const)
          .map(([v, t]) => { const o = h("option", { value: v }, t); if (v === modoYoutube()) o.selected = true; return o; }));
      sel.addEventListener("change", () => { try { localStorage.setItem("orq-yt-modo", sel.value); } catch { /* sin almacenamiento */ } });
      caja.replaceChildren(h("p", { class: "small" }, h("span", { class: "pill done" }, "YouTube"), ` ${e.canal ?? ""}`),
        h("div", { class: "chat-input" }, sel),
        h("button", { class: "linkish", onclick: async () => { await app.api.youtubeDesconectar(); caja.replaceWith(bloqueYoutube()); } }, "Desconectar"));
    }).catch(() => caja.remove());
    return caja;
  }

  // ------------------------------------------------------------------ aprender de los jugadores

  function seccionJugadores(p: Proyecto, arreglar: (instruccion: string) => void): HTMLElement {
    const cuerpo = h("div", {}, h("p", { class: "muted small" }, "Leyendo cómo lo juega la gente..."));
    const sec = h("section", { class: "sheet" },
      h("div", { class: "sheet-head" }, h("h2", {}, "Cómo lo juega la gente"), h("span", { class: "tag" }, "datos anónimos")), cuerpo);
    void app.api.informe(p.id).then((filas) => {
      const d = diagnosticar(filas, p.niveles);
      if (!d.suficiente) {
        cuerpo.replaceChildren(h("p", { class: "muted" }, p.play?.estado === "subido"
          ? `Aún hay pocos datos (${d.jugadores} jugadores). Hacen falta ${MIN_INTENTOS} intentos por nivel para sacar conclusiones.`
          : "Cuando publiques el juego verás aquí dónde se atasca la gente, qué nivel abandona y cuál es demasiado fácil. Chispa te propondrá el arreglo."));
        return;
      }
      const filasNivel = h("div", { class: "niveles-datos" });
      for (const n of d.niveles) {
        const barra = h("span", { class: "barra" }, h("i", { style: `width:${Math.round(n.victoria * 100)}%` }));
        filasNivel.append(h("div", { class: "nivel-dato" + (d.consejos.some((c) => c.nivel === n.nivel && c.tipo !== "facil") ? " aviso" : "") },
          h("strong", {}, `${n.nivel + 1}. ${n.nombre}`),
          barra,
          h("span", { class: "muted small" }, `lo pasa ${Math.round(n.victoria * 100)} % · abandona ${Math.round(n.abandono * 100)} % · ${n.muertes.toFixed(1)} muertes` +
            (n.llegan !== null && n.nivel > 0 ? ` · llega ${Math.round(n.llegan * 100)} %` : ""))));
      }
      const consejos = h("div", { class: "consejos" });
      for (const c of d.consejos) {
        consejos.append(h("div", { class: "consejo" }, h("p", {}, c.texto),
          h("button", { class: "btn btn-line btn-small", onclick: () => arreglar(c.instruccion) }, "Que Chispa lo arregle")));
      }
      if (!d.consejos.length) consejos.append(h("p", { class: "muted" }, "Todo en su punto: ningún nivel se atraganta ni aburre."));
      cuerpo.replaceChildren(h("p", { class: "muted small" }, `Versión ${d.version} · ${d.jugadores} jugadores`), filasNivel, consejos);
    }).catch(() => cuerpo.replaceChildren(h("p", { class: "muted small" }, "No se pudieron leer los datos de los jugadores.")));
    return sec;
  }

  // ------------------------------------------------------------------ clasificación online

  // Los mejores de cada nivel (la gente que juega elige un apodo). El autor puede ocultar apodos feos.
  function seccionClasificacion(p: Proyecto): HTMLElement {
    const lista = h("ol", { class: "clasif", "aria-live": "polite" });
    const niveles = h("div", { class: "chips desliza", role: "tablist", "aria-label": "Nivel" });
    const sec = h("section", { class: "sheet" },
      h("div", { class: "sheet-head" }, h("h2", {}, "Clasificación"), h("span", { class: "tag" }, "online")),
      h("p", { class: "muted small" }, "Los jugadores salen con el apodo que eligen. Pulsa «Ocultar» si alguno no es apropiado."),
      niveles, lista);
    let actual = 0;
    const cargar = (nivel: number): void => {
      actual = nivel;
      niveles.querySelectorAll("button").forEach((b, i) => b.setAttribute("aria-selected", String(i === nivel)));
      lista.replaceChildren(h("li", { class: "muted small" }, "Cargando..."));
      void app.api.clasificacion(p.id, nivel).then((filas) => {
        if (nivel !== actual) return;
        if (!filas.length) {
          lista.replaceChildren(h("li", { class: "muted" }, p.play?.estado === "subido"
            ? "Nadie ha entrado aún en la clasificación de este nivel."
            : "Cuando publiques el juego, aquí verás a los mejores de cada nivel. Los jugadores también pueden retar a sus amigos con un enlace."));
          return;
        }
        lista.replaceChildren(...filas.map((f) => {
          const boton = h("button", { class: "btn btn-line btn-small", type: "button" }, f.oculta ? "Mostrar" : "Ocultar");
          const fila = h("li", { class: "clasif-fila" + (f.oculta ? " oculta" : "") },
            h("span", { class: "clasif-pos" }, String(f.posicion)), h("span", { class: "clasif-alias" }, f.alias),
            h("span", { class: "clasif-pts" }, f.puntos.toLocaleString("es-ES")), boton);
          boton.addEventListener("click", () => {
            boton.disabled = true;
            void app.api.ocultarMarcador(f.id, !f.oculta).then(() => cargar(actual))
              .catch((e) => { boton.disabled = false; aviso(mensajeError(e, "No se pudo cambiar.")); });
          });
          return fila;
        }));
      }).catch(() => lista.replaceChildren(h("li", { class: "muted small" }, "No se pudo leer la clasificación.")));
    };
    p.niveles.forEach((nombre, i) => {
      niveles.append(h("button", { class: "chip", type: "button", role: "tab", onclick: () => cargar(i) }, `${i + 1}. ${nombre}`));
    });
    if (p.niveles.length) cargar(0);
    return sec;
  }

  // ------------------------------------------------------------------ liga de aldeas

  // Juegos de aldea: los jugadores se asaltan las aldeas entre ellos. El autor ve la liga y oculta apodos feos.
  function seccionLiga(p: Proyecto): HTMLElement {
    const lista = h("ol", { class: "clasif", "aria-live": "polite" }, h("li", { class: "muted small" }, "Cargando..."));
    const sec = h("section", { class: "sheet" },
      h("div", { class: "sheet-head" }, h("h2", {}, "Liga de aldeas"), h("span", { class: "tag" }, "online")),
      h("p", { class: "muted small" }, "Quien juega sube su aldea y asalta las de los demás para ganar trofeos. Pulsa «Ocultar» si algún apodo no es apropiado."),
      lista);
    const cargar = (): void => {
      void app.api.liga(p.id).then((filas) => {
        if (!filas.length) {
          lista.replaceChildren(h("li", { class: "muted" }, "Cuando la gente juegue, aquí verás las aldeas de la liga."));
          return;
        }
        lista.replaceChildren(...filas.map((f, i) => {
          const boton = h("button", { class: "btn btn-line btn-small", type: "button" }, f.oculta ? "Mostrar" : "Ocultar");
          boton.addEventListener("click", () => {
            boton.disabled = true;
            void app.api.ocultarLiga(f.id, !f.oculta).then(cargar)
              .catch((e) => { boton.disabled = false; aviso(mensajeError(e, "No se pudo cambiar.")); });
          });
          return h("li", { class: "clasif-fila" + (f.oculta ? " oculta" : "") },
            h("span", { class: "clasif-pos" }, String(i + 1)), h("span", { class: "clasif-alias" }, `${f.alias} · ayto ${f.ayto}`),
            h("span", { class: "clasif-pts" }, `${f.trofeos} 🏆`), boton);
        }));
      }).catch(() => lista.replaceChildren(h("li", { class: "muted small" }, "No se pudo leer la liga.")));
    };
    cargar();
    return sec;
  }

  // ------------------------------------------------------------------ charla con personajes

  // Los jugadores hablan con el héroe, el rival y el jefe (responde la IA con su personalidad).
  // Lo paga el autor por paquetes de mensajes; el botón «Hablar» sale en la pausa del juego.
  function seccionCharla(p: Proyecto): HTMLElement {
    const estado = h("p", { class: "small", "aria-live": "polite" }, "Cargando...");
    const comprar = h("button", { class: "btn", type: "button" }, "Activar");
    const pausar = h("button", { class: "btn btn-line btn-small", type: "button", hidden: true }, "Pausar");
    const sec = h("section", { class: "sheet" },
      h("div", { class: "sheet-head" }, h("h2", {}, "Charla con personajes"), h("span", { class: "tag" }, "IA")),
      h("p", { class: "muted small" }, "Quien juega puede hablar con tus personajes desde la pausa. Responden con su personalidad, solo del juego y aptos para todas las edades; no se guardan datos de nadie."),
      estado, h("div", { class: "fila-botones" }, comprar, pausar));
    let activa = false;
    const pintar = (): void => {
      void app.api.charlaEstado(p.id).then((e) => {
        activa = e.activa && e.mensajes > 0;
        estado.textContent = e.mensajes > 0
          ? `${e.activa ? "Activa" : "En pausa"}: quedan ${e.mensajes.toLocaleString("es-ES")} mensajes · hoy ${e.hoy}`
          : "Sin activar. Sin ella, los personajes contestan con frases de la historia.";
        comprar.textContent = e.mensajes > 0 ? `Añadir ${e.por_paquete} mensajes · ${e.precio} tuercas` : `Activar · ${e.precio} tuercas (${e.por_paquete} mensajes)`;
        pausar.hidden = e.mensajes <= 0;
        pausar.textContent = e.activa ? "Pausar" : "Reanudar";
      }).catch(() => { estado.textContent = "No se pudo leer la charla."; });
    };
    comprar.addEventListener("click", () => {
      comprar.disabled = true;
      void app.api.charlaActivar(p.id).then((r) => { app.ponerTuercas(r.tuercas); aviso("Charla activada"); pintar(); })
        .catch((e) => aviso(mensajeError(e, "No se pudo activar.")))
        .finally(() => { comprar.disabled = false; });
    });
    pausar.addEventListener("click", () => {
      pausar.disabled = true;
      void app.api.charlaPausar(p.id, !activa).then(pintar)
        .catch((e) => aviso(mensajeError(e, "No se pudo cambiar.")))
        .finally(() => { pausar.disabled = false; });
    });
    pintar();
    return sec;
  }

  // ------------------------------------------------------------------ qué lleva el juego

  const FUNCIONES: [Funcion, string, string][] = [
    ["tienda", "Tienda", "Compras dentro del juego: monedas, pase premium y quitar anuncios."],
    ["pase", "Misiones y pase", "Misiones diarias y semanales y pase de temporada con premios."],
    ["avisos", "Avisos", "Recordatorios en el móvil: premio diario, misiones y eventos."],
    ["nube", "Pasar a otro móvil", "Guardar la partida con un código y un PIN."],
    ["online", "Online", "Clasificaciones, liga, clanes, amigos, arena y charla con personajes."],
  ];
  const SOLO_MAYORES: Funcion[] = ["tienda", "avisos", "online"];

  /** Interruptores de lo que lleva el juego publicado. Para niños, Google exige quitar compras,
   *  avisos y lo online: se apagan y se bloquean. Se guarda como un cambio del taller (versión nueva). */
  function seccionFunciones(p: Proyecto, alListo: (prop: Propuesta) => void): HTMLElement {
    const inicial: Record<Funcion, boolean> = { tienda: true, pase: true, avisos: true, nube: true, online: true };
    for (const [k] of FUNCIONES) if (p.funciones && k in p.funciones) inicial[k] = Boolean(p.funciones[k]);
    let ninos = p.publico === "infantil";
    const estado = { ...inicial };
    const casillas = new Map<Funcion, HTMLInputElement>();
    const nino = h("input", { type: "checkbox", role: "switch" }) as HTMLInputElement;
    nino.checked = ninos;
    const guardar = h("button", { class: "btn btn-brass", type: "button", disabled: true }, "Guardar cambios") as HTMLButtonElement;
    const aviso_ninos = h("p", { class: "small aviso-ninos", hidden: !ninos },
      "Para niños, Google Play no permite compras, avisos ni nada online: van apagados.");
    const pintar = (): void => {
      for (const [k, c] of casillas) {
        const bloqueado = ninos && SOLO_MAYORES.includes(k);
        c.disabled = bloqueado;
        c.checked = bloqueado ? false : estado[k];
      }
      aviso_ninos.hidden = !ninos;
      guardar.disabled = ninos === (p.publico === "infantil") && FUNCIONES.every(([k]) => estado[k] === inicial[k]);
    };
    const filas = FUNCIONES.map(([k, nombre, ayuda]) => {
      const c = h("input", { type: "checkbox", role: "switch" }) as HTMLInputElement;
      c.addEventListener("change", () => { estado[k] = c.checked; pintar(); });
      casillas.set(k, c);
      return h("label", { class: "interruptor" }, c, h("span", {}, h("strong", {}, nombre), h("span", { class: "muted small" }, ayuda)));
    });
    nino.addEventListener("change", () => { ninos = nino.checked; pintar(); });
    guardar.addEventListener("click", () => {
      const op: Record<string, unknown> = { op: "funciones" };
      if (ninos !== (p.publico === "infantil")) op.publico = ninos ? "infantil" : "todos";
      for (const [k] of FUNCIONES) if (estado[k] !== inicial[k]) op[k] = estado[k];
      guardar.disabled = true;
      void app.api.planManual(p.id, [op]).then(alListo)
        .catch((e) => { aviso(mensajeError(e, "No se pudo guardar.")); pintar(); });
    });
    pintar();
    return h("section", { class: "sheet" },
      h("div", { class: "sheet-head" }, h("h2", {}, "Qué lleva tu juego"), h("span", { class: "tag" }, "versión nueva")),
      h("label", { class: "interruptor destacado" }, nino, h("span", {}, h("strong", {}, "Para niños (menores de 13)"),
        h("span", { class: "muted small" }, "Anuncios aptos para menores y las normas de Familias de Google Play."))),
      aviso_ninos, ...filas,
      h("p", { class: "muted small" }, "Se aplica en la próxima versión del juego (Chispa te enseña el cambio antes de hacerlo)."),
      guardar);
  }

  // ------------------------------------------------------------------ giros y mezclas

  // Reglas raras encima del género (y mezclas con otro género). Como mucho dos; los bots prueban
  // el juego con ellos y, si un giro lo estropea, la fábrica lo quita y no cobra.
  /** Convierte una sección en plegable: se ve el título y un resumen, y se abre al tocarla. Así el
   *  taller cabe en una pantalla y lo que no se usa no estorba. */
  function plegable(sec: HTMLElement, resumen: string): HTMLElement {
    const cab = sec.querySelector(":scope > .sheet-head");
    const titulo = cab?.querySelector("h2")?.textContent ?? "";
    const caja = h("details", { class: "sheet plegable" });
    const sum = h("summary", {}, h("h2", {}, titulo), resumen ? h("span", { class: "tag" }, resumen) : "", svg(ICONOS.abajo));
    caja.append(sum, ...Array.from(sec.childNodes).filter((n) => n !== cab));
    return caja;
  }

  function seccionGiros(p: Proyecto, alListo: (prop: Propuesta) => void): HTMLElement {
    const genero = p.genero ?? "plataformas";
    const validos = GIROS.filter((g) => g.generos === "*" || g.generos.includes(genero));
    const elegidos = new Set(p.giros ?? []);
    const guardar = h("button", { class: "btn btn-brass", type: "button", disabled: true }, "Guardar giros") as HTMLButtonElement;
    const aviso2 = h("p", { class: "small muted" });
    const casillas: HTMLInputElement[] = [];
    const pintar = (): void => {
      const igual = validos.every((g) => elegidos.has(g.id) === (p.giros ?? []).includes(g.id));
      guardar.disabled = igual || elegidos.size > 2;
      aviso2.textContent = elegidos.size > 2 ? "Como mucho dos giros a la vez." : "";
      for (const c of casillas) c.disabled = !c.checked && elegidos.size >= 2;
    };
    const filas = validos.map((g) => {
      const c = h("input", { type: "checkbox", role: "switch" }) as HTMLInputElement;
      c.checked = elegidos.has(g.id);
      c.addEventListener("change", () => { if (c.checked) elegidos.add(g.id); else elegidos.delete(g.id); pintar(); });
      casillas.push(c);
      return h("label", { class: "interruptor" + (g.mezcla ? " destacado" : "") }, c,
        h("span", {}, h("strong", {}, g.nombre + (g.mezcla ? " (mezcla)" : "")), h("span", { class: "muted small" }, g.que)));
    });
    guardar.addEventListener("click", () => {
      guardar.disabled = true;
      void app.api.planManual(p.id, [{ op: "giros", giros: validos.filter((g) => elegidos.has(g.id)).map((g) => g.id) }]).then(alListo)
        .catch((e) => { aviso(mensajeError(e, "No se pudieron guardar los giros.")); pintar(); });
    });
    pintar();
    return h("section", { class: "sheet" },
      h("div", { class: "sheet-head" }, h("h2", {}, "Giros y mezclas"), h("span", { class: "tag" }, "hazlo único")),
      h("p", { class: "muted small" }, "Reglas raras que hacen tu juego distinto a todos. Los bots lo prueban con ellas antes de guardar."),
      ...filas, aviso2, guardar);
  }

  // ------------------------------------------------------------------ tu dibujo como protagonista

  /** Imagen reducida a 1024 px como mucho (JPEG; PNG si tiene transparencia no importa: se aplana en blanco). */
  async function reducir(f: File): Promise<Blob> {
    const bmp = await createImageBitmap(f);
    const k = Math.min(1, 1024 / Math.max(bmp.width, bmp.height));
    const c = document.createElement("canvas");
    c.width = Math.round(bmp.width * k);
    c.height = Math.round(bmp.height * k);
    const g = c.getContext("2d")!;
    g.fillStyle = "#ffffff";
    g.fillRect(0, 0, c.width, c.height);
    g.drawImage(bmp, 0, 0, c.width, c.height);
    return await new Promise<Blob>((ok, mal) => c.toBlob((b) => (b ? ok(b) : mal(new Error("canvas"))), "image/jpeg", 0.9));
  }

  // El autor sube su dibujo (o su mascota, o un juguete); la IA lo revisa y Chispa lo convierte en
  // el protagonista con el estilo del juego. Nada de fotos de personas (lo comprueba el servidor).
  function seccionDibujo(p: Proyecto, alListo: (prop: Propuesta) => void): HTMLElement {
    const input = h("input", { type: "file", accept: "image/png,image/jpeg,image/webp", "aria-label": "Elegir imagen" }) as HTMLInputElement;
    const vista = h("img", { class: "dibujo-vista", alt: "Tu imagen", hidden: true }) as HTMLImageElement;
    const usar = h("button", { class: "btn btn-brass", type: "button", disabled: true }, "Usar como protagonista") as HTMLButtonElement;
    const estado = h("p", { class: "status", role: "status" });
    let elegida: File | null = null;
    input.addEventListener("change", () => {
      elegida = input.files?.[0] ?? null;
      estado.className = "status";
      estado.textContent = "";
      if (!elegida) { vista.hidden = true; usar.disabled = true; return; }
      vista.src = URL.createObjectURL(elegida);
      vista.hidden = false;
      usar.disabled = false;
    });
    usar.addEventListener("click", async () => {
      if (!elegida) return;
      usar.disabled = true;
      estado.className = "status";
      estado.textContent = "Chispa está mirando tu imagen...";
      try {
        const r = await app.api.revisarDibujo(p.id, await reducir(elegida));
        if (!r.ok) {
          estado.className = "status err";
          estado.textContent = r.motivo ?? "Esa imagen no vale. Prueba con otra.";
          usar.disabled = false;
          return;
        }
        estado.textContent = "";
        alListo(await app.api.planManual(p.id, [{ op: "redibujar", que: "heroe", descripcion: r.descripcion ?? "", referencia: "dibujo" }]));
      } catch (e) {
        estado.className = "status err";
        estado.textContent = mensajeError(e, "No se pudo usar la imagen.");
      }
      usar.disabled = false;
    });
    return h("section", { class: "sheet" },
      h("div", { class: "sheet-head" }, h("h2", {}, "Tu dibujo como protagonista"), h("span", { class: "tag" }, "nuevo")),
      h("p", { class: "muted small" }, "Haz una foto a un dibujo tuyo, a tu mascota o a un juguete. Chispa lo convierte en el héroe del juego, con su estilo y todas sus animaciones."),
      h("label", { class: "btn btn-line btn-small subir-dibujo" }, "Elegir imagen", input),
      vista, usar, estado,
      h("p", { class: "muted small" }, "No vale con fotos de personas ni con personajes de marcas o series: la imagen se revisa antes de usarla."));
  }

  // ------------------------------------------------------------------ prueba A/B de un nivel

  const HACIA_AB: [string, string][] = [["mas_facil", "Más fácil"], ["mas_dificil", "Más difícil"], ["distinto", "Distinto"]];

  // La mitad de los jugadores juega una versión B del nivel; los datos dicen cuál superan más.
  function seccionAb(p: Proyecto, alListo: (prop: Propuesta) => void): HTMLElement {
    const cuerpo = h("div", { "aria-live": "polite" });
    const sec = h("section", { class: "sheet" },
      h("div", { class: "sheet-head" }, h("h2", {}, "Prueba A/B de un nivel"), h("span", { class: "tag" }, p.prueba_ab ? "en marcha" : "datos reales")), cuerpo);
    const pedir = (op: Record<string, unknown>, b: HTMLButtonElement) => {
      b.disabled = true;
      void app.api.planManual(p.id, [{ op: "prueba_ab", ...op }]).then(alListo)
        .catch((e) => aviso(mensajeError(e, "No se pudo preparar la prueba.")))
        .finally(() => { b.disabled = false; });
    };
    const ab = p.prueba_ab;
    if (!ab) {
      const nivel = h("select", { "aria-label": "Nivel que quieres probar" }, ...p.niveles.map((n, i) => h("option", { value: String(i) }, `${i + 1}. ${n}`))) as HTMLSelectElement;
      const hacia = h("select", { "aria-label": "Cómo será la versión B" }, ...HACIA_AB.map(([v, t]) => h("option", { value: v }, t))) as HTMLSelectElement;
      const empezar = h("button", { class: "btn btn-line btn-small", type: "button" }, "Preparar la prueba") as HTMLButtonElement;
      empezar.addEventListener("click", () => pedir({ indice: Number(nivel.value), hacia: hacia.value }, empezar));
      cuerpo.append(
        h("p", { class: "muted small" }, "¿Dudas si un nivel es demasiado difícil? Chispa hace una versión B y la mitad de los jugadores la juega. Cuando haya datos, te quedas con la que más gente supera."),
        h("div", { class: "form-col ab-form" }, h("label", {}, h("span", { class: "small" }, "Nivel"), nivel), h("label", {}, h("span", { class: "small" }, "Versión B"), hacia)),
        h("div", { class: "fila-botones" }, empezar));
      return sec;
    }
    const nombre = p.niveles[ab.nivel] ?? `Nivel ${ab.nivel + 1}`;
    const como = (HACIA_AB.find(([v]) => v === ab.hacia)?.[1] ?? "Distinta").toLowerCase();
    cuerpo.append(h("p", {}, `Nivel ${ab.nivel + 1} (${nombre}): la de siempre (A) contra una versión ${como} (B).`),
      h("p", { class: "muted small" }, "Leyendo los datos..."));
    void app.api.informeAb(p.id).then((inf) => {
      const v = veredictoAb(inf);
      const barra = (letra: string, x: number | null, n: number) => h("div", { class: "nivel-dato" + (v.estado === letra ? " gana" : "") },
        h("strong", {}, letra === "a" ? "A · la de siempre" : `B · ${como}`),
        h("span", { class: "barra" }, h("i", { style: `width:${Math.round((x ?? 0) * 100)}%` })),
        h("span", { class: "muted small" }, x === null ? "sin datos aún" : `lo supera el ${Math.round(x * 100)} % · ${n} jugadores`));
      const conB = h("button", { class: "btn btn-line btn-small", type: "button" }, "Quedarme con la B") as HTMLButtonElement;
      const conA = h("button", { class: "btn btn-line btn-small", type: "button" }, "Quedarme con la A") as HTMLButtonElement;
      conB.addEventListener("click", () => pedir({ ganadora: "b" }, conB));
      conA.addEventListener("click", () => pedir({ ganadora: "a" }, conA));
      cuerpo.replaceChildren(cuerpo.firstChild as Node,
        h("div", { class: "niveles-datos" }, barra("a", v.a, inf?.grupos.a?.jugadores ?? 0), barra("b", v.b, inf?.grupos.b?.jugadores ?? 0)),
        h("p", { class: v.estado === "a" || v.estado === "b" ? "ab-veredicto" : "muted small" },
          p.play?.estado === "subido" ? v.texto : "La prueba empieza cuando subas esta versión a Google Play."),
        h("div", { class: "fila-botones" }, ...(v.estado === "a" ? [conA, conB] : [conB, conA])));
    }).catch(() => cuerpo.append(h("p", { class: "muted small" }, "No se pudieron leer los datos de la prueba.")));
    return sec;
  }

  // ------------------------------------------------------------------ asesor de lanzamiento

  // Las 3 cosas que más ayudarían al juego ahora, cada una con su botón (ver asesor.ts).
  function seccionAsesor(p: Proyecto, hacer: (a: Accion) => void): HTMLElement {
    const sec = h("section", { class: "sheet asesor", hidden: true, "aria-live": "polite" });
    const leer = <T,>(x: Promise<T>): Promise<T | null> => x.catch(() => null);
    const publicado = p.play?.estado === "subido";
    void Promise.all([
      publicado ? leer(app.api.informe(p.id)) : Promise.resolve(null),
      publicado ? leer(app.api.ingresos(p.id)) : Promise.resolve(null),
      publicado ? leer(app.api.eventos(p.id)) : Promise.resolve(null),
    ]).then(([informe, ing, eventos]) => {
      const ahora = Date.now();
      const consejos = aconsejar({
        genero: p.genero, publico: p.publico, funciones: p.funciones, publicado, anuncios: Boolean(p.admob), niveles: p.niveles,
        pruebaAb: Boolean(p.prueba_ab),
        informe, eventosProgramados: (eventos ?? []).filter((e) => new Date(e.fin).getTime() > ahora).length,
        ingresos: ing ? { jugadores_total: ing.jugadores_total, d1: ing.d1, d7: ing.d7, total_euros: Number(ing.total_euros),
          compras: ing.productos.reduce((n, x) => n + x.ventas, 0) } : null,
      });
      if (!consejos.length) return;
      sec.replaceChildren(h("div", { class: "sheet-head" }, h("h2", {}, "Qué hacer ahora"), h("span", { class: "tag" }, "asesor")),
        ...consejos.map((c) => h("div", { class: "consejo-lanz" },
          h("strong", {}, c.titulo), h("p", { class: "muted small" }, c.texto),
          h("button", { class: "btn btn-line btn-small", type: "button", onclick: () => hacer(c.accion) }, c.boton))));
      sec.hidden = false;
    });
    return sec;
  }

  // ------------------------------------------------------------------ ingresos y jugadores

  const NOMBRES_PRODUCTO: Record<string, string> = {
    monedas_500: "500 monedas", monedas_3000: "3000 monedas", pase_temporada: "Pase premium", sin_anuncios: "Sin anuncios",
    pack_inicio: "Pack de inicio",
  };
  const euros = (n: number): string => n.toLocaleString("es-ES", { style: "currency", currency: "EUR" });

  /** Barras de una sola serie (un valor por día), con su eje y un aviso al pasar por encima. */
  function barras(titulo: string, valores: { dia: string; v: number }[], formato: (n: number) => string): HTMLElement {
    const W = 320, H = 120, PIE = 18, IZQ = 34;
    const max = Math.max(1, ...valores.map((x) => x.v));
    const paso = (W - IZQ) / valores.length;
    const ancho = Math.max(2, paso - 2);
    const y = (v: number): number => (H - PIE) - (v / max) * (H - PIE - 8);
    const marcas = valores.map((x, i) => {
      const alto = (H - PIE) - y(x.v);
      const fecha = new Date(x.dia + "T12:00:00Z").toLocaleDateString("es-ES", { day: "numeric", month: "short" });
      return `<g class="barra"><rect x="${IZQ + i * paso}" y="0" width="${paso}" height="${H - PIE}" fill="transparent"/>`
        + `<path d="M${IZQ + i * paso + 1} ${H - PIE}v${-Math.max(0, alto - 2)}a2 2 0 0 1 2-2h${ancho - 4}a2 2 0 0 1 2 2v${Math.max(0, alto - 2)}z" fill="var(--grafica)"/>`
        + `<title>${fecha}: ${formato(x.v)}</title></g>`;
    }).join("");
    const rejilla = [0, 0.5, 1].map((f) => {
      const v = max * f;
      return `<line x1="${IZQ}" x2="${W}" y1="${y(v)}" y2="${y(v)}" class="rejilla"/><text x="${IZQ - 4}" y="${y(v) + 4}" text-anchor="end" class="eje">${formato(Math.round(v * 100) / 100)}</text>`;
    }).join("");
    const pie = [0, valores.length - 1].map((i) => {
      const f = new Date(valores[i].dia + "T12:00:00Z").toLocaleDateString("es-ES", { day: "numeric", month: "short" });
      return `<text x="${IZQ + i * paso + paso / 2}" y="${H - 4}" text-anchor="${i === 0 ? "start" : "end"}" class="eje">${f}</text>`;
    }).join("");
    const fig = h("figure", { class: "grafica" }, h("figcaption", { class: "small" }, titulo));
    fig.insertAdjacentHTML("beforeend", `<svg viewBox="0 0 ${W} ${H}" role="img" aria-label="${titulo}">${rejilla}${marcas}${pie}</svg>`);
    return fig;
  }

  // Lo que el autor quiere saber de un vistazo: cuánta gente juega, si vuelve y cuánto vende.
  function seccionIngresos(p: Proyecto): HTMLElement {
    const cuerpo = h("div", { "aria-live": "polite" }, h("p", { class: "muted small" }, "Cargando..."));
    const sec = h("section", { class: "sheet" },
      h("div", { class: "sheet-head" }, h("h2", {}, "Ingresos y jugadores"), h("span", { class: "tag" }, "30 días")),
      cuerpo);
    void app.api.ingresos(p.id).then((r) => {
      if (!r.jugadores_total && !r.total_euros) {
        cuerpo.replaceChildren(h("p", { class: "muted small" }, "Cuando la gente juegue (y compre dentro del juego), aquí verás jugadores por día, cuántos vuelven y lo que vendes."));
        return;
      }
      const dato = (valor: string, etiqueta: string) => h("div", { class: "dato" }, h("strong", {}, valor), h("span", { class: "muted small" }, etiqueta));
      const pct = (n: number | null) => (n === null ? "—" : `${n} %`);
      const tabla = h("table", { class: "tabla-ventas" },
        h("thead", {}, h("tr", {}, h("th", {}, "Producto"), h("th", {}, "Ventas"), h("th", {}, "Importe"))),
        h("tbody", {}, ...(r.productos.length ? r.productos.map((x) => h("tr", {},
          h("td", {}, NOMBRES_PRODUCTO[x.producto] ?? x.producto), h("td", {}, String(x.ventas)), h("td", {}, euros(Number(x.euros)))))
          : [h("tr", {}, h("td", { colspan: "3", class: "muted small" }, "Aún no hay ventas dentro del juego."))])));
      cuerpo.replaceChildren(
        h("div", { class: "datos" },
          dato(r.jugadores_total.toLocaleString("es-ES"), "jugadores"),
          dato(pct(r.d1), "vuelven al día siguiente"),
          dato(pct(r.d7), "siguen a los 7 días"),
          dato(euros(Number(r.neto_euros)), "para ti (ventas − 15 % de Google)")),
        barras("Jugadores por día", r.dias.map((d) => ({ dia: d.dia, v: d.jugadores })), (n) => String(Math.round(n))),
        barras("Ventas por día (€)", r.dias.map((d) => ({ dia: d.dia, v: Number(d.euros) })), (n) => euros(n).replace(/,00/, "")),
        tabla,
        h("p", { class: "muted small" }, "Los anuncios los paga AdMob y se ven en su consola. Los jugadores salen de los datos anónimos de partida."));
    }).catch(() => cuerpo.replaceChildren(h("p", { class: "muted small" }, "No se pudieron leer los ingresos.")));
    return sec;
  }

  // ------------------------------------------------------------------ reseñas de Google Play

  // Chispa propone la respuesta en el idioma de quien escribió; el autor la lee, la cambia si
  // quiere y la envía él. Nunca se contesta sola.
  function seccionResenas(p: Proyecto): HTMLElement {
    const cuerpo = h("div", { "aria-live": "polite" });
    const sec = h("section", { class: "sheet" },
      h("div", { class: "sheet-head" }, h("h2", {}, "Reseñas de Google Play"), h("span", { class: "tag" }, "7 días")), cuerpo);
    if (p.play?.estado !== "subido") {
      cuerpo.append(h("p", { class: "muted small" }, "Cuando el juego esté en Google Play, aquí verás lo que escribe la gente y podrás contestar con ayuda de Chispa."));
      return sec;
    }
    const estrellas = (n: number) => "★".repeat(n) + "☆".repeat(5 - n);
    const tarjeta = (r: Resena): HTMLElement => {
      const caja = h("div", { class: "resena" + (r.estrellas <= 2 ? " baja" : "") },
        h("div", { class: "resena-cab" }, h("strong", {}, r.autor), h("span", { class: "estrellas", "aria-label": `${r.estrellas} de 5 estrellas` }, estrellas(r.estrellas)),
          h("span", { class: "muted small" }, hace(r.fecha) + (r.version ? ` · v${r.version}` : ""))),
        h("p", {}, r.texto),
        ...(r.traduccion ? [h("p", { class: "muted small" }, `Traducción: ${r.traduccion}`)] : []));
      if (r.respuesta) {
        caja.append(h("p", { class: "resena-resp" }, h("strong", {}, "Tu respuesta: "), r.respuesta));
        return caja;
      }
      const texto = h("textarea", { rows: "3", maxlength: "350", placeholder: "Escribe tu respuesta o deja que Chispa la proponga", "aria-label": `Respuesta a ${r.autor}` }) as HTMLTextAreaElement;
      const cuenta = h("span", { class: "muted small" }, "0/350");
      const proponer = h("button", { class: "btn btn-line btn-small", type: "button" }, "Que Chispa la proponga") as HTMLButtonElement;
      const enviar = h("button", { class: "btn btn-line btn-small", type: "button", disabled: true }, "Enviar respuesta") as HTMLButtonElement;
      const contar = () => { cuenta.textContent = `${[...texto.value].length}/350`; enviar.disabled = !texto.value.trim(); };
      texto.addEventListener("input", contar);
      proponer.addEventListener("click", () => {
        proponer.disabled = true;
        proponer.textContent = "Pensando...";
        void app.api.borradorResena(p.id, r.id).then((t) => { texto.value = t; contar(); texto.focus(); })
          .catch((e) => aviso(mensajeError(e, "Chispa no ha podido proponer una respuesta.")))
          .finally(() => { proponer.disabled = false; proponer.textContent = "Proponer otra"; });
      });
      enviar.addEventListener("click", () => {
        enviar.disabled = true;
        void app.api.responderResena(p.id, r.id, texto.value).then(() => {
          aviso("Respuesta publicada en Google Play");
          caja.replaceWith(tarjeta({ ...r, respuesta: texto.value.trim(), respondida_en: new Date().toISOString() }));
        }).catch((e) => { aviso(mensajeError(e, "No se pudo enviar la respuesta.")); contar(); });
      });
      caja.append(texto, h("div", { class: "fila-botones" }, proponer, enviar, cuenta));
      return caja;
    };
    cuerpo.append(h("p", { class: "muted small" }, "Leyendo reseñas..."));
    void app.api.resenas(p.id).then((lista) => {
      const sin = lista.filter((r) => !r.respuesta).length;
      cuerpo.replaceChildren(
        h("p", { class: "muted small" }, lista.length
          ? `${lista.length} reseñas con texto${sin ? `, ${sin} sin contestar` : ", todas contestadas"}. Contestar rápido sube la nota: mucha gente la cambia tras una buena respuesta.`
          : "No hay reseñas con texto de los últimos 7 días. Las más antiguas siguen en Play Console."),
        ...lista.map(tarjeta),
        h("p", { class: "muted small" }, "Google Play no permite ofrecer premios a cambio de reseñas o de cambiar la nota: Chispa nunca lo propone."));
    }).catch((e) => cuerpo.replaceChildren(h("p", { class: "muted small" }, mensajeError(e, "No se pudieron leer las reseñas."))));
    return sec;
  }

  // ------------------------------------------------------------------ eventos en directo

  /** Cuándo empieza un evento: ahora, mañana a las 10 o el próximo sábado a las 10. */
  function inicioEvento(cuando: string, ahora = new Date()): Date {
    if (cuando === "ahora") return ahora;
    const d = new Date(ahora);
    d.setHours(10, 0, 0, 0);
    if (cuando === "manana") d.setDate(d.getDate() + 1);
    else d.setDate(d.getDate() + (((6 - d.getDay()) + 7) % 7 || 7));
    return d;
  }

  // El autor programa monedas dobles o un regalo; el juego lo ve al abrirse, sin publicar otra versión.
  function seccionEventos(p: Proyecto): HTMLElement {
    const lista = h("ul", { class: "lista-eventos", "aria-live": "polite" }, h("li", { class: "muted small" }, "Cargando..."));
    const tipo = h("select", { "aria-label": "Tipo de evento" },
      h("option", { value: "monedas_x2" }, "Monedas dobles"), h("option", { value: "regalo" }, "Regalo de monedas")) as HTMLSelectElement;
    const titulo = h("input", { type: "text", maxlength: "40", placeholder: "Título (lo verán los jugadores)", "aria-label": "Título del evento" }) as HTMLInputElement;
    const cuando = h("select", { "aria-label": "Cuándo empieza" },
      h("option", { value: "ahora" }, "Empieza ahora"), h("option", { value: "manana" }, "Mañana 10:00"), h("option", { value: "sabado" }, "Sábado 10:00")) as HTMLSelectElement;
    const dura = h("select", { "aria-label": "Duración" },
      ...[[1, "1 día"], [2, "2 días"], [3, "3 días"], [7, "1 semana"]].map(([n, t]) => h("option", { value: String(n) }, String(t)))) as HTMLSelectElement;
    dura.value = "2";
    const regalo = h("input", { type: "number", min: "1", max: "500", value: "100", "aria-label": "Monedas de regalo", hidden: true }) as HTMLInputElement;
    const ajustar = (): void => {
      regalo.hidden = tipo.value !== "regalo";
      tipo.classList.toggle("ancho", regalo.hidden);
    };
    tipo.addEventListener("change", ajustar);
    ajustar();
    const crear = h("button", { class: "btn", type: "button" }, "Programar evento") as HTMLButtonElement;
    const sec = h("section", { class: "sheet" },
      h("div", { class: "sheet-head" }, h("h2", {}, "Eventos en directo"), h("span", { class: "tag" }, "online")),
      h("p", { class: "muted small" }, "Monedas dobles un fin de semana o un regalo para todos: el juego lo enseña en el título al abrirse, sin publicar otra versión."),
      lista, h("div", { class: "form-evento" }, titulo, tipo, regalo, cuando, dura), crear);
    const cargar = (): void => {
      void app.api.eventos(p.id).then((evs) => {
        if (!evs.length) {
          lista.replaceChildren(h("li", { class: "muted small" }, "Ningún evento todavía."));
          return;
        }
        const ahora = Date.now();
        lista.replaceChildren(...evs.map((e) => {
          const ini = Date.parse(e.inicio);
          const fin = Date.parse(e.fin);
          const estado = fin <= ahora ? "Acabado" : ini <= ahora ? "En marcha" : "Programado";
          const fecha = new Date(ini).toLocaleString("es-ES", { weekday: "short", day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" });
          const que = e.tipo === "regalo" ? `regalo de ${e.regalo} · recogido ${e.cobros} veces` : "monedas dobles";
          const borrar = h("button", { class: "btn btn-line btn-small", type: "button", hidden: fin <= ahora }, ini <= ahora ? "Terminar" : "Borrar") as HTMLButtonElement;
          borrar.addEventListener("click", () => {
            borrar.disabled = true;
            void app.api.borrarEvento(e.id).then(cargar)
              .catch((err) => { borrar.disabled = false; aviso(mensajeError(err, "No se pudo borrar.")); });
          });
          return h("li", { class: "evento" + (fin <= ahora ? " acabado" : "") },
            h("div", {}, h("strong", {}, e.titulo), h("span", { class: "muted small" }, ` · ${estado} · ${fecha} · ${que}`)), borrar);
        }));
      }).catch(() => lista.replaceChildren(h("li", { class: "muted small" }, "No se pudieron leer los eventos.")));
    };
    crear.addEventListener("click", () => {
      const inicio = inicioEvento(cuando.value);
      const fin = new Date(inicio.getTime() + Number(dura.value) * 86400000);
      crear.disabled = true;
      void app.api.crearEvento(p.id, { tipo: tipo.value as "monedas_x2" | "regalo", titulo: titulo.value, inicio, fin, regalo: Number(regalo.value) })
        .then(() => { titulo.value = ""; aviso("Evento programado"); cargar(); })
        .catch((e) => aviso(mensajeError(e, "No se pudo programar.")))
        .finally(() => { crear.disabled = false; });
    });
    cargar();
    return sec;
  }

  // ------------------------------------------------------------------ modo clase

  // El profesor crea una clase con un código; los alumnos lo escriben en el juego (Ajustes → Clase).
  function seccionClase(p: Proyecto): HTMLElement {
    const lista = h("div", { "aria-live": "polite" }, h("p", { class: "muted small" }, "Cargando..."));
    const nombre = h("input", { type: "text", maxlength: "40", placeholder: "Nombre de la clase (ej.: 3º B)", "aria-label": "Nombre de la clase" }) as HTMLInputElement;
    const crear = h("button", { class: "btn", type: "button" }, "Crear clase") as HTMLButtonElement;
    const tarjeta = (c: Clase): HTMLElement => {
      const cerrar = h("button", { class: "btn btn-line btn-small", type: "button" }, "Cerrar clase") as HTMLButtonElement;
      cerrar.addEventListener("click", () => {
        cerrar.disabled = true;
        void app.api.cerrarClase(c.codigo).then(cargar).catch((e) => { cerrar.disabled = false; aviso(mensajeError(e, "No se pudo cerrar.")); });
      });
      // Vaciar para otro trimestre: dos toques (el primero pide confirmación).
      const vaciar = h("button", { class: "btn btn-line btn-small", type: "button", hidden: !c.alumnos.length }, "Vaciar para otro trimestre") as HTMLButtonElement;
      let seguro = false;
      vaciar.addEventListener("click", () => {
        if (!seguro) { seguro = true; vaciar.textContent = "¿Seguro? Se borran sus alumnos. Pulsa otra vez"; return; }
        vaciar.disabled = true;
        void app.api.vaciarClase(c.codigo).then(() => { aviso("Clase vaciada: el código sigue siendo el mismo"); cargar(); })
          .catch((e) => { vaciar.disabled = false; aviso(mensajeError(e, "No se pudo vaciar.")); });
      });
      const notas = h("button", { class: "btn btn-line btn-small", type: "button", hidden: !c.alumnos.length }, "Descargar notas (CSV)") as HTMLButtonElement;
      notas.addEventListener("click", () => {
        const url = URL.createObjectURL(new Blob([csvClase(c)], { type: "text/csv" }));
        void compartir(url, `clase-${c.nombre.replace(/[^\p{L}\p{N}]+/gu, "-")}.csv`, `Notas de ${c.nombre}`).finally(() => URL.revokeObjectURL(url));
      });
      const total = p.niveles?.length ?? 0;
      const filas = c.alumnos.map((a) => {
        const at = atasco(a, total);
        return h("tr", { class: at ? "atascado" : "" }, h("td", {}, a.alias), h("td", {}, String(a.niveles)), h("td", {}, String(a.estrellas)),
          h("td", {}, `${a.minutos} min`), h("td", { class: "small" }, at ? `⚠ ${at}` : (a.nivel_actual ? `Nivel ${a.nivel_actual}` : "—")),
          h("td", { class: "muted small" }, haceCuanto(a.visto)));
      });
      return h("div", { class: "clase" },
        h("div", { class: "sheet-head" }, h("h3", {}, c.nombre), h("span", { class: "codigo-clase", "aria-label": "Código de la clase" }, c.codigo)),
        h("p", { class: "muted small" }, resumenClase(c, p.niveles?.length ?? 0)),
        c.alumnos.length ? h("div", { class: "tabla-desliza" }, h("table", { class: "tabla-clase" },
          h("thead", {}, h("tr", {}, ...["Alumno", "Niveles", "Estrellas", "Tiempo", "Ahora", "Última vez"].map((t) => h("th", {}, t)))), h("tbody", {}, ...filas))) : "",
        h("div", { class: "fila-botones" }, notas, vaciar, cerrar));
    };
    function cargar(): void {
      void app.api.clases(p.id).then((cs) => {
        lista.replaceChildren(...(cs.length ? cs.map(tarjeta) : [h("p", { class: "muted small" }, "Aún no tienes clases.")]));
      }).catch(() => lista.replaceChildren(h("p", { class: "muted small" }, "No se pudieron leer las clases.")));
    }
    crear.addEventListener("click", () => {
      crear.disabled = true;
      void app.api.crearClase(p.id, nombre.value).then((codigo) => { nombre.value = ""; aviso(`Clase creada: código ${codigo}`); cargar(); })
        .catch((e) => aviso(mensajeError(e, "No se pudo crear la clase.")))
        .finally(() => { crear.disabled = false; });
    });
    cargar();
    return h("section", { class: "sheet", "data-seccion": "clase" },
      h("div", { class: "sheet-head" }, h("h2", {}, "Modo clase"), h("span", { class: "tag" }, "profes")),
      h("p", { class: "muted small" }, "Crea una clase y dicta el código. Cada alumno lo escribe en el juego (Ajustes → Clase) con su nombre de pila o un apodo, y aquí ves sus niveles, estrellas y minutos. No se piden correos ni datos personales."),
      h("div", { class: "form-evento" }, nombre), crear, lista);
  }

  // ------------------------------------------------------------------ opiniones privadas

  // El juego pregunta "¿Te está gustando?": con un sí lleva a valorar en Play; con un no, lo que
  // haya que mejorar llega aquí y no a la ficha de la tienda.
  function seccionOpiniones(p: Proyecto, alPlan: (instruccion: string) => void): HTMLElement {
    const cuerpo = h("div", {}, h("p", { class: "muted small" }, "Cargando..."));
    void app.api.opiniones(p.id).then((o) => {
      const total = o.gusta + o.no_gusta;
      if (!total) {
        cuerpo.replaceChildren(h("p", { class: "muted small" }, "Aún nadie ha contestado. El juego pregunta tras unos niveles superados."));
        return;
      }
      const pct = Math.round((100 * o.gusta) / total);
      cuerpo.replaceChildren(
        h("p", {}, h("strong", {}, `${pct} %`), ` de ${total} jugadores dicen que les gusta`),
        o.ultimas.length ? h("ul", { class: "lista-eventos" }, ...o.ultimas.slice(0, 10).map((x) => {
          const arreglar = h("button", { class: "btn btn-line btn-small", type: "button" }, "Arreglarlo");
          arreglar.addEventListener("click", () => alPlan(`Un jugador dice (nivel ${x.nivel}): "${x.texto}". Mejóralo.`));
          return h("li", { class: "evento" }, h("div", {}, h("span", {}, x.texto),
            h("span", { class: "muted small" }, ` · nivel ${x.nivel} · ${new Date(x.fecha).toLocaleDateString("es-ES", { day: "numeric", month: "short" })}`)), arreglar);
        })) : "");
    }).catch(() => cuerpo.replaceChildren(h("p", { class: "muted small" }, "No se pudieron leer las opiniones.")));
    return h("section", { class: "sheet" },
      h("div", { class: "sheet-head" }, h("h2", {}, "Lo que opinan en privado"), h("span", { class: "tag" }, "online")),
      h("p", { class: "muted small" }, "Tras unos niveles, el juego pregunta si les gusta. Quien dice que sí va a valorarlo en Google Play; quien dice que no te cuenta aquí qué mejorar, sin dejar una mala nota en la tienda."),
      cuerpo);
  }

  // ------------------------------------------------------------------ premio real para negocios

  // Un cupón de verdad para quien supera el nivel N: el juego como escaparate de tu negocio.
  function seccionPremio(p: Proyecto): HTMLElement {
    const estado = h("p", { class: "small", "aria-live": "polite" }, "Cargando...");
    const idea = h("select", { "aria-label": "Idea por tipo de negocio" },
      h("option", { value: "" }, "Ideas por tipo de negocio..."),
      ...IDEAS_PREMIO.map((i, n) => h("option", { value: String(n) }, i.negocio))) as HTMLSelectElement;
    const texto = h("input", { type: "text", maxlength: "80", placeholder: "Premio (ej.: café gratis con tu desayuno)", "aria-label": "Premio" }) as HTMLInputElement;
    const codigo = h("input", { type: "text", maxlength: "16", placeholder: "Código (ej.: CAFE)", "aria-label": "Código del premio", autocapitalize: "characters" }) as HTMLInputElement;
    const nivel = h("input", { type: "number", min: "1", max: "50", value: "3", "aria-label": "Se gana al superar el nivel" }) as HTMLInputElement;
    const donde = h("input", { type: "text", maxlength: "80", placeholder: "Dónde canjearlo (nombre y dirección)", "aria-label": "Dónde canjearlo" }) as HTMLInputElement;
    const web = h("input", { type: "url", maxlength: "200", placeholder: "Web o tienda online (https://...), opcional", "aria-label": "Web del negocio" }) as HTMLInputElement;
    const caduca = h("input", { type: "date", "aria-label": "Caduca el (opcional)" }) as HTMLInputElement;
    for (const c of [idea, texto, donde, web]) c.classList.add("ancho");
    idea.addEventListener("change", () => {
      const i = IDEAS_PREMIO[Number(idea.value)];
      if (!i || idea.value === "") return;
      texto.value = i.texto; codigo.value = i.codigo; nivel.value = String(i.nivel);
    });
    const guardar = h("button", { class: "btn", type: "button" }, "Guardar premio") as HTMLButtonElement;
    const quitar = h("button", { class: "btn btn-line", type: "button", hidden: true }, "Quitar premio") as HTMLButtonElement;
    const cartel = h("button", { class: "btn btn-line", type: "button", hidden: true }, "Cartel para la tienda") as HTMLButtonElement;
    // Canjear en la tienda: el dependiente escribe el código del cliente y queda marcado como usado.
    const codCliente = h("input", { type: "text", maxlength: "24", placeholder: "Código del cliente (CAFE-7F3A)", "aria-label": "Código del cliente",
      autocapitalize: "characters", autocomplete: "off", spellcheck: "false" }) as HTMLInputElement;
    const canjear = h("button", { class: "btn btn-brass", type: "button" }, "Canjear") as HTMLButtonElement;
    const veredicto = h("p", { class: "canje", "aria-live": "assertive" });
    const canje = h("div", { class: "canje-caja", hidden: true }, h("h3", {}, "Canjear en la tienda"), h("div", { class: "fila-canje" }, codCliente, canjear), veredicto);
    canjear.addEventListener("click", () => {
      if (!codigoValido(codCliente.value)) { aviso("El código tiene esta forma: CAFE-7F3A."); codCliente.focus(); return; }
      canjear.disabled = true;
      void app.api.canjearPremio(p.id, codCliente.value).then((c) => {
        const t = textoCanje(c);
        veredicto.className = "canje " + (t.ok ? "canje-ok" : "canje-no");
        veredicto.textContent = (t.ok ? "✓ " : "✗ ") + t.texto;
        if (t.ok) codCliente.value = "";
        void app.api.premio(p.id).then(pintar).catch(() => undefined);
      }).catch((e) => aviso(mensajeError(e, "No se pudo comprobar el código.")))
        .finally(() => { canjear.disabled = false; });
    });
    let actual: PremioReal | null = null;
    cartel.addEventListener("click", async () => {
      if (!actual) return;
      cartel.disabled = true;
      try {
        const web = (import.meta.env.VITE_WEB as string | undefined)?.replace(/\/$/, "");
        const tienda = p.play?.estado === "subido" && p.play.paquete ? `https://play.google.com/store/apps/details?id=${p.play.paquete}` : null;
        const enEscaparate = tienda ? null : await app.api.fichaEscaparate(p.id).catch(() => null);
        const url = tienda ?? (enEscaparate && web ? `${web}/jugar.html?j=${p.id}` : null);
        if (!url) {
          aviso("Para el cartel, primero comparte el juego con un enlace (pestaña Compartir) o súbelo a Google Play.");
          return;
        }
        const qr = qrcode(0, "M");
        qr.addData(url);
        qr.make();
        const lienzo = document.createElement("canvas");
        lienzo.width = ANCHO;
        lienzo.height = ALTO;
        const ctx = lienzo.getContext("2d");
        if (!ctx) return;
        dibujarCartel(ctx, { titulo: p.titulo, premio: actual.texto, nivel: actual.tras_nivel, donde: actual.donde, url, qr: modulosQr(qr) });
        const blob = await new Promise<Blob | null>((ok) => lienzo.toBlob(ok, "image/png"));
        if (!blob) return;
        const enlace = URL.createObjectURL(blob);
        await compartir(enlace, "cartel-premio.png", `Juega a «${p.titulo}» y gana: ${actual.texto}`);
        window.setTimeout(() => URL.revokeObjectURL(enlace), 60000);
      } catch (e) {
        aviso(mensajeError(e, "No se pudo hacer el cartel."));
      } finally {
        cartel.disabled = false;
      }
    });
    const pintar = (pr: PremioReal | null): void => {
      actual = pr;
      estado.textContent = resumenPremio(pr);
      quitar.hidden = !pr;
      cartel.hidden = !pr;
      canje.hidden = !pr;
      if (!pr) return;
      texto.value = pr.texto; codigo.value = pr.codigo; nivel.value = String(pr.tras_nivel);
      donde.value = pr.donde; web.value = pr.web; caduca.value = pr.caduca ?? "";
    };
    const leerForm = (): PremioReal => ({ texto: texto.value.trim(), codigo: codigo.value.trim().toUpperCase(), tras_nivel: Number(nivel.value),
      donde: donde.value.trim(), web: web.value.trim(), caduca: caduca.value || null });
    guardar.addEventListener("click", () => {
      const pr = leerForm();
      const mal = validarPremio(pr);
      if (mal) { aviso(mal); return; }
      guardar.disabled = true;
      void app.api.guardarPremio(p.id, pr).then((r) => { pintar(r); aviso("Premio guardado"); })
        .catch((e) => aviso(mensajeError(e, "No se pudo guardar el premio.")))
        .finally(() => { guardar.disabled = false; });
    });
    quitar.addEventListener("click", () => {
      quitar.disabled = true;
      void app.api.guardarPremio(p.id, null).then(() => { pintar(null); aviso("Premio quitado"); })
        .catch((e) => aviso(mensajeError(e, "No se pudo quitar el premio.")))
        .finally(() => { quitar.disabled = false; });
    });
    void app.api.premio(p.id).then(pintar).catch(() => { estado.textContent = "No se pudo leer el premio."; });
    return h("section", { class: "sheet", "data-seccion": "premio" },
      h("div", { class: "sheet-head" }, h("h2", {}, "Premio real para tu negocio"), h("span", { class: "tag" }, "online")),
      h("p", { class: "muted small" }, "Quien supere el nivel que elijas recibe un cupón de tu negocio con su propio código (CAFE-7F3A) para enseñarlo al pagar. Lo cambias cuando quieras, sin publicar otra versión, y aquí ves cuántos lo han ganado."),
      estado, h("div", { class: "form-evento" }, idea, texto, h("label", { class: "muted small" }, "Código", codigo), h("label", { class: "muted small" }, "Se gana al superar el nivel", nivel), donde, web,
        h("label", { class: "muted small" }, "Caduca el (opcional)", caduca)), guardar, quitar, cartel, canje);
  }

  // ------------------------------------------------------------------ publicar en Google Play

  interface AccionesPublicar {
    guardar: (estudio: string, correo: string) => Promise<void>;
    lanzar: (modo: "primer_aab" | "subir", pista: string) => void;
  }

  const PISTAS: Record<string, string> = { internal: "Prueba interna", alpha: "Prueba cerrada", beta: "Prueba abierta", production: "Producción" };

  /** App Store de Apple: datos una vez (equipo y clave de la API) y subida a TestFlight desde un Mac en la nube. */
  function seccionApple(p: Proyecto, subir: () => void): HTMLElement {
    const sec = h("section", { class: "sheet" }, h("div", { class: "sheet-head" }, h("h2", {}, "Publicar en la App Store"),
      p.ios?.estado === "subido" ? h("span", { class: "pill done" }, `build ${p.ios.build ?? ""}`) : h("span", { class: "tag" }, "iPhone y iPad")));
    const cuerpo = h("div", {}, h("p", { class: "muted small" }, "Cargando..."));
    sec.append(cuerpo);
    void app.api.cuentaApple().then((c) => {
      if (c) {
        cuerpo.replaceChildren(
          h("p", { class: "muted small" }, `Equipo ${c.equipo} · clave ${c.clave_id}. Chispa compila el juego en un Mac en la nube, lo firma con tu cuenta y lo sube a App Store Connect.`),
          p.ios?.estado === "subido"
            ? h("p", { class: "small" }, "Está en TestFlight. En App Store Connect: añade la build a una versión, revisa la ficha y pulsa «Enviar a revisión». Las capturas y textos de Apple están en la ficha descargable.")
            : h("p", { class: "small" }, `Antes, una vez: en App Store Connect → Apps → «+» crea la app con el identificador ${p.play?.paquete ?? "de tu juego (el mismo que en Google Play)"}.`),
          h("button", { class: "btn btn-brass", style: "width:100%", onclick: () => subir() }, p.ios?.estado ? "Subir versión nueva a la App Store" : "Subir a la App Store (TestFlight)"));
        return;
      }
      const campo = (ph: string, et: string) => h("input", { type: "text", maxlength: "40", placeholder: ph, "aria-label": et, autocomplete: "off", spellcheck: "false" });
      const equipo = campo("ID de equipo (10 caracteres)", "ID de equipo de Apple");
      const clave = campo("ID de la clave (10 caracteres)", "ID de la clave de la API");
      const emisor = campo("Issuer ID (con guiones)", "Issuer ID");
      const archivo = h("input", { type: "file", accept: ".p8", "aria-label": "Archivo de clave .p8" }) as HTMLInputElement;
      const nombreP8 = h("span", { class: "muted small" }, "Ningún archivo elegido");
      archivo.addEventListener("change", () => { nombreP8.textContent = archivo.files?.[0]?.name ?? "Ningún archivo elegido"; });
      const elegirP8 = h("div", { class: "fila-archivo" }, h("label", { class: "btn btn-line btn-small subir-dibujo" }, "Elegir archivo .p8", archivo), nombreP8);
      const guardar = h("button", { class: "btn btn-brass" }, "Guardar mis datos de Apple");
      guardar.addEventListener("click", async () => {
        const f = archivo.files?.[0];
        if (!f) { aviso("Elige el archivo .p8 que descargaste de App Store Connect."); return; }
        guardar.disabled = true;
        try {
          await app.api.guardarCuentaApple({ equipo: equipo.value, clave_id: clave.value, emisor: emisor.value, p8: await f.text() });
          aviso("Datos de Apple guardados");
          sec.replaceWith(seccionApple(p, subir));
        } catch (e) {
          aviso(mensajeError(e, "No se pudieron guardar tus datos de Apple."));
          guardar.disabled = false;
        }
      });
      cuerpo.replaceChildren(
        h("p", { class: "muted small" }, "Apple cobra 99 $ al año por su programa de desarrolladores. Solo una vez:"),
        h("details", { class: "paso" }, h("summary", {}, h("span", {}, "Cómo conseguir tus datos (10 minutos)")),
          h("p", {}, "1. Date de alta en developer.apple.com (Apple Developer Program). Tu ID de equipo está en Membership."),
          h("p", {}, "2. En appstoreconnect.apple.com → Usuarios y acceso → Integraciones → Claves de la API de App Store Connect: crea una clave con acceso «App Manager»."),
          h("p", {}, "3. Copia su ID de clave y el Issuer ID, y descarga el archivo .p8 (solo se puede descargar una vez)."),
          h("p", {}, "4. Pégalos aquí. La clave se guarda cifrada y nunca vuelve a salir.")),
        h("div", { class: "form-col" }, equipo, clave, emisor, elegirP8, guardar));
    }).catch(() => cuerpo.replaceChildren(h("p", { class: "muted small" }, "No se pudieron leer tus datos de Apple.")));
    return sec;
  }

  /** En el ordenador: paquete HTML5 para subir a itch.io (o a cualquier web). */
  function seccionItch(p: Proyecto): HTMLElement {
    const boton = h("button", { class: "btn", type: "button" }, "Descargar para itch.io") as HTMLButtonElement;
    const estado = h("p", { class: "small", "aria-live": "polite" });
    boton.disabled = !p.files?.web;
    boton.addEventListener("click", () => {
      boton.disabled = true;
      estado.textContent = "Preparando el paquete (unos segundos)...";
      void app.api.paqueteItch(p.id).then((r) => {
        estado.textContent = `Listo: ${r.nombre} (${r.mb} MB).`;
        const a = h("a", { href: r.url, download: r.nombre, rel: "noopener" }) as HTMLAnchorElement;
        document.body.append(a);
        a.click();
        a.remove();
      }).catch((e) => { estado.textContent = ""; aviso(mensajeError(e, "No se pudo preparar el paquete.")); })
        .finally(() => { boton.disabled = !p.files?.web; });
    });
    const pasos = ["Crea una cuenta gratis en itch.io y pulsa «Upload new project».",
      "En «Kind of project» elige HTML y sube el .zip.",
      "Marca «This file will be played in the browser» y elige el tamaño 405 × 720 (o «Mobile friendly»).",
      "Pon el precio que quieras (itch.io deja cobrar o pedir donativos) y publica."];
    return h("section", { class: "sheet" },
      h("div", { class: "sheet-head" }, h("h2", {}, "En el ordenador (itch.io)"), h("span", { class: "tag" }, "PC")),
      h("p", { class: "muted small" }, "Tu juego para jugar en el navegador del ordenador: un .zip listo para subir a itch.io, la tienda de juegos indie, o a tu propia web."),
      !p.files?.web ? h("p", { class: "status err" }, "Este juego aún no tiene versión para el navegador: haz cualquier cambio en el taller.") : "",
      h("ol", { class: "small" }, ...pasos.map((t) => h("li", {}, t))), boton, estado);
  }

  /** Juego regalo: para una persona, con un mensaje secreto dentro y un enlace privado. */
  function seccionRegalo(p: Proyecto): HTMLElement {
    const estado = h("p", { class: "small", "aria-live": "polite" }, "Cargando...");
    const ocasion = h("select", { "aria-label": "Ocasión", class: "ancho" }, h("option", { value: "" }, "Ocasión..."),
      ...OCASIONES.map((o, n) => h("option", { value: String(n) }, o.ocasion))) as HTMLSelectElement;
    const para = h("input", { type: "text", maxlength: "20", placeholder: "Para (ej.: Lucía)", "aria-label": "Para quién" }) as HTMLInputElement;
    const de = h("input", { type: "text", maxlength: "20", placeholder: "De (tu nombre)", "aria-label": "De quién" }) as HTMLInputElement;
    const mensaje = h("textarea", { maxlength: "400", placeholder: "El mensaje secreto (aparece al superar el nivel)", "aria-label": "Mensaje secreto" }) as HTMLTextAreaElement;
    const nivel = h("select", { "aria-label": "Cuándo aparece el mensaje", class: "ancho" }, h("option", { value: "0" }, "Al acabar el último nivel"),
      ...[1, 2, 3, 5, 10].map((n) => h("option", { value: String(n) }, `Al superar el nivel ${n}`))) as HTMLSelectElement;
    ocasion.addEventListener("change", () => { const o = OCASIONES[Number(ocasion.value)]; if (o && ocasion.value !== "") mensaje.value = o.mensaje; });
    const guardar = h("button", { class: "btn", type: "button" }, "Guardar regalo") as HTMLButtonElement;
    const enlace = h("button", { class: "btn btn-brass", type: "button", hidden: true }, "Mandar el enlace privado") as HTMLButtonElement;
    const vista = h("button", { class: "btn btn-line", type: "button" }, "Ver cómo lo verá") as HTMLButtonElement;
    vista.addEventListener("click", () => {
      const r: RegaloJuego = { para: para.value.trim(), de: de.value.trim(), mensaje: mensaje.value.trim(), tras_nivel: Number(nivel.value) };
      const mal = validarRegalo(r);
      if (mal) { aviso(mal); return; }
      abrirVistaRegalo(r, p.titulo, p.niveles?.length ?? 0);
    });
    const quitar = h("button", { class: "btn btn-line btn-small", type: "button", hidden: true }, "Ya no es un regalo") as HTMLButtonElement;
    enlace.disabled = !p.files?.web;
    const pintar = (r: RegaloJuego | null): void => {
      estado.textContent = estadoRegalo(r);
      enlace.hidden = !r; quitar.hidden = !r;
      if (!r) return;
      para.value = r.para; de.value = r.de; mensaje.value = r.mensaje; nivel.value = String(r.tras_nivel);
    };
    guardar.addEventListener("click", () => {
      const r: RegaloJuego = { para: para.value, de: de.value, mensaje: mensaje.value, tras_nivel: Number(nivel.value) };
      const mal = validarRegalo(r);
      if (mal) { aviso(mal); return; }
      guardar.disabled = true;
      void app.api.guardarRegalo(p.id, r).then((x) => { pintar(x); aviso("Regalo guardado"); })
        .catch((e) => aviso(mensajeError(e, "No se pudo guardar el regalo.")))
        .finally(() => { guardar.disabled = false; });
    });
    enlace.addEventListener("click", () => {
      enlace.disabled = true;
      void app.api.enlaceRegalo(p.id).then(async (r) => {
        if (r.url) aviso((await compartirEnlace(r.url, `Un regalo para ${para.value.trim()}`)) === "copiado" ? "Enlace copiado: mándaselo" : "¡Enviado!");
        else aviso("Enlace listo");
      }).catch((e) => aviso(mensajeError(e, "No se pudo crear el enlace.")))
        .finally(() => { enlace.disabled = !p.files?.web; });
    });
    quitar.addEventListener("click", () => {
      quitar.disabled = true;
      void app.api.guardarRegalo(p.id, null).then(() => { pintar(null); aviso("Ya no es un regalo"); })
        .catch((e) => aviso(mensajeError(e, "No se pudo quitar.")))
        .finally(() => { quitar.disabled = false; });
    });
    void app.api.regalo(p.id).then(pintar).catch(() => { estado.textContent = "No se pudo leer el regalo."; });
    return h("section", { class: "sheet", "data-seccion": "regalo" },
      h("div", { class: "sheet-head" }, h("h2", {}, "Juego regalo"), h("span", { class: "tag" }, "privado")),
      h("p", { class: "muted small" }, "Para una persona: al abrirlo verá «Para Lucía, de Dani» y un mensaje secreto al superar el nivel que elijas. El enlace es privado (no sale en el escaparate), sin anuncios, y aquí verás cuándo lo abre y cuándo lee el mensaje."),
      !p.files?.web ? h("p", { class: "status err" }, "Este juego aún no tiene versión para el navegador: haz cualquier cambio en el taller.") : "",
      estado, h("div", { class: "form-evento" }, ocasion, nivel, para, de), mensaje, h("div", { style: "height:10px" }), guardar, vista, enlace, quitar);
  }

  /** Compartir con un enlace: cualquiera lo juega en el navegador y sale en el escaparate. */
  function seccionCompartir(p: Proyecto): HTMLElement {
    const s = h("section", { class: "sheet" }, h("div", { class: "sheet-head" }, h("h2", {}, "Compartir con un enlace")));
    const cuerpo = h("div", {}, h("p", { class: "muted small" }, "..."));
    s.append(cuerpo);
    const autor = h("input", { type: "text", maxlength: "40", placeholder: "Tu nombre o el de tu estudio", "aria-label": "Nombre del autor", autocomplete: "off" });
    void app.api.cuentaPlay().then((c) => { if (c && !autor.value) autor.value = c.estudio; }).catch(() => undefined);

    async function pintar() {
      const ficha = await app.api.fichaEscaparate(p.id).catch(() => null);
      const publicar = h("button", { class: "btn btn-brass" }, ficha ? `Actualizar a la versión ${p.version}` : "Compartir mi juego");
      publicar.disabled = !p.files?.web;
      publicar.addEventListener("click", async () => {
        publicar.disabled = true;
        try {
          const r = await app.api.publicarEscaparate(p.id, autor.value);
          if (r.url) {
            const como = await compartirEnlace(r.url, p.titulo);
            aviso(como === "copiado" ? "Enlace copiado: pégalo donde quieras" : "¡Compartido!");
          } else {
            aviso("Publicado en el escaparate");
          }
          await pintar();
        } catch (e) {
          aviso(mensajeError(e, "No se pudo compartir."));
          publicar.disabled = false;
        }
      });
      if (!ficha) {
        cuerpo.replaceChildren(
          h("p", { class: "muted small" }, "Cualquiera podrá jugarlo en el navegador con un enlace, sin instalar nada, y aparecerá en el escaparate de la comunidad. Otras personas podrán hacer un remix (una copia suya para cambiarla)."),
          !p.files?.web ? h("p", { class: "status err" }, "Este juego aún no tiene versión para el navegador: haz cualquier cambio en el taller.") : "",
          h("p", { class: "muted small" }, "Autor que se mostrará"), autor, h("div", { style: "height:10px" }), publicar);
        return;
      }
      const enlace = (import.meta.env.VITE_WEB as string | undefined)?.replace(/\/$/, "");
      const url = enlace ? `${enlace}/jugar.html?j=${p.id}` : null;
      const otraVez = h("button", { class: "btn btn-line btn-small" }, "Compartir enlace");
      otraVez.disabled = !url;
      otraVez.addEventListener("click", async () => {
        // Si ya existe la página propia del juego (con su imagen y su título para WhatsApp,
        // Instagram o X), se comparte esa; si aún no se ha generado, el enlace directo de siempre.
        if (url) aviso((await compartirEnlace(await enlaceConTarjeta(enlace!, p.id, url), p.titulo)) === "copiado" ? "Enlace copiado" : "¡Compartido!");
      });
      const quitar = h("button", { class: "btn btn-line btn-small" }, "Quitar");
      quitar.addEventListener("click", async () => {
        quitar.disabled = true;
        try {
          await app.api.retirarEscaparate(p.id);
          aviso("Quitado del escaparate");
          await pintar();
        } catch (e) {
          aviso(mensajeError(e, "No se pudo quitar."));
          quitar.disabled = false;
        }
      });
      cuerpo.replaceChildren(
        h("p", {}, `▶ ${ficha.jugadas} partidas · ♥ ${ficha.megusta} · ${ficha.remixes} remix`),
        url ? h("p", { class: "compartir-enlace" }, url) : "",
        url ? codigoQr(url, p.titulo) : "",
        botonReto(app, p.id),
        ficha.version < p.version ? h("p", { class: "muted small" }, `En el escaparate está la versión ${ficha.version}.`) : "",
        h("div", { class: "btn-row" }, otraVez, quitar), h("div", { style: "height:10px" }),
        ficha.version < p.version ? publicar : "");
    }
    void pintar();
    return s;
  }

  /** Código QR del enlace: para enseñarlo en persona (clase, quedada, feria) y que lo jueguen
   *  al momento con la cámara del móvil. */
  function codigoQr(url: string, titulo: string): HTMLElement {
    const qr = qrcode(0, "M");
    qr.addData(url);
    qr.make();
    const caja = h("figure", { class: "qr" });
    caja.innerHTML = qr.createSvgTag({ cellSize: 5, margin: 3, scalable: true });
    caja.querySelector("svg")?.setAttribute("aria-label", `Código QR para jugar a ${titulo}`);
    caja.querySelector("svg")?.setAttribute("role", "img");
    caja.append(h("figcaption", { class: "muted small" }, "Que lo escaneen con la cámara y lo juegan al momento."));
    return caja;
  }

  /** Plan de 7 días para redes: qué grabar y qué texto pegar cada día. */
  function seccionPlanRedes(p: Proyecto): HTMLElement {
    const enlaceWeb = (import.meta.env.VITE_WEB as string | undefined)?.replace(/\/$/, "");
    const tienda = p.play?.estado === "subido" && p.play.paquete ? `https://play.google.com/store/apps/details?id=${p.play.paquete}` : null;
    const plan = planRedes({ titulo: p.titulo, genero: p.genero, generoNombre: GENERO_NOMBRE[p.genero ?? ""],
      giros: (p.giros ?? []).map((g) => GIROS.find((x) => x.id === g)?.nombre ?? g),
      jugar: enlaceWeb ? `${enlaceWeb}/jugar.html?j=${p.id}` : null, tienda, niveles: p.niveles?.length, idioma: idioma() });
    const dias = plan.map((d) => h("details", { class: "paso dia-redes" },
      h("summary", {}, h("span", { class: "tag" }, `Día ${d.dia}`), h("span", {}, d.objetivo)),
      h("p", { class: "muted small" }, `Qué grabar: ${d.idea}`),
      h("p", { class: "texto-redes" }, d.texto),
      h("button", { class: "btn btn-line btn-small", type: "button", onclick: () => void copiarTexto(d.texto) }, "Copiar texto")));
    return plegable(h("section", { class: "sheet" },
      h("div", { class: "sheet-head" }, h("h2", {}, "Plan de 7 días para redes")),
      h("p", { class: "muted small" }, "Una publicación al día durante la primera semana, cada una con un gancho distinto. Es lo que más jugadores trae gratis."),
      ...dias), "gratis");
  }

  /** Anuncios de AdMob del juego: solo van en la versión de tienda y con los ids del usuario. */
  function seccionAnuncios(p: Proyecto): HTMLElement {
    const ids = p.admob ?? null;
    const campo = (ph: string, etiqueta: string, valor: string) => {
      const i = h("input", { type: "text", maxlength: "60", placeholder: ph, "aria-label": etiqueta, autocomplete: "off", spellcheck: "false" });
      i.value = valor;
      return i;
    };
    const appId = campo("ca-app-pub-0000000000000000~0000000000", "ID de app de AdMob", ids?.app_id ?? "");
    const inter = campo("ca-app-pub-0000000000000000/0000000000", "Bloque intersticial", ids?.interstitial ?? "");
    const rew = campo("ca-app-pub-0000000000000000/0000000000", "Bloque bonificado", ids?.rewarded ?? "");
    const ban = campo("ca-app-pub-0000000000000000/0000000000", "Bloque de banner (opcional)", ids?.banner ?? "");
    const ape = campo("ca-app-pub-0000000000000000/0000000000", "Bloque de apertura de app (opcional)", ids?.app_open ?? "");
    // Tipo de monetización: el del género (recomendado) o el que elija el autor.
    const propio = PERFIL_GENERO[p.genero ?? ""] ?? "arcade";
    const sel = h("select", { "aria-label": "Tipo de monetización" },
      h("option", { value: "" }, `Recomendado: ${MONETIZACION[propio]?.nombre ?? propio}`),
      ...Object.values(MONETIZACION).filter((m) => m.perfil !== "infantil").map((m) => h("option", { value: m.perfil }, m.nombre))) as HTMLSelectElement;
    sel.value = ids?.perfil ?? "";
    const resumen = h("div", { class: "form-col" });
    const pintarResumen = () => {
      const m = MONETIZACION[sel.value || propio];
      if (!m) return;
      ban.style.display = m.bloques_admob.includes("Banner") ? "" : "none";
      ape.style.display = m.bloques_admob.includes("Apertura de app") ? "" : "none";
      resumen.replaceChildren(
        h("p", { class: "small" }, h("b", {}, m.nombre + ". "), m.por_que),
        h("p", { class: "muted small" }, `Banner: ${m.banner}. Intersticial: ${m.intersticial}.` + (m.anuncio_al_volver ? " Anuncio al volver a la app." : "")),
        h("p", { class: "muted small" }, `Anuncios con premio: ${m.premios.join(", ")}.`),
        h("p", { class: "muted small" }, m.compras.length ? `Compras que destaca: ${m.compras.join(" · ")}.` : "Sin compras destacadas."),
        h("p", { class: "muted small" }, `Bloques que necesitas en AdMob: ${m.bloques_admob.join(", ")}.`));
    };
    sel.addEventListener("change", pintarResumen);
    pintarResumen();
    const guardar = h("button", { class: "btn btn-brass" }, ids ? "Guardar cambios" : "Activar anuncios");
    guardar.addEventListener("click", async () => {
      guardar.disabled = true;
      try {
        const vacio = !appId.value.trim() && !inter.value.trim() && !rew.value.trim();
        p.admob = await app.api.guardarAdmob(p.id, vacio ? null : { app_id: appId.value, interstitial: inter.value, rewarded: rew.value,
          banner: ban.style.display === "none" ? "" : ban.value, app_open: ape.style.display === "none" ? "" : ape.value, perfil: sel.value });
        aviso(p.admob ? "Anuncios listos: irán en la próxima versión que subas" : "Anuncios quitados");
        estado.replaceChildren(pillAnuncios(p));
      } catch (e) {
        aviso(mensajeError(e, "No se pudieron guardar los anuncios."));
      } finally {
        guardar.disabled = false;
      }
    });
    const estado = h("span", {}, pillAnuncios(p));
    return h("section", { class: "sheet" },
      h("div", { class: "sheet-head" }, h("h2", {}, "Anuncios (AdMob)"), estado),
      h("p", { class: "muted small" }, "El juego ya trae los anuncios bien puestos según su tipo: nunca en mitad de la acción ni en el primer minuto, " +
        "y anuncios con premio que el jugador elige ver. Para cobrar tú, pega los ids de tu cuenta de AdMob."),
      h("div", { class: "sheet-head" }, h("h3", {}, "Cómo gana dinero este juego")),
      sel, resumen,
      h("details", { class: "paso" }, h("summary", {}, h("span", {}, "Cómo conseguir los ids (5 minutos)")),
        h("p", {}, "1. Entra en admob.google.com con tu cuenta de Google y acepta las condiciones."),
        h("p", {}, "2. Apps → Añadir app → Android → «¿Está publicada?»: sí si ya está en Google Play (búscala), si no, no. Copia el ID de app (lleva ~)."),
        h("p", {}, "3. En la app: Bloques de anuncios → Añadir → Intersticial. Copia su id (lleva /). Repite con «Bonificado» y, si arriba te los pide, con «Banner» y «Apertura de la app»."),
        h("p", {}, "4. Pégalos aquí y sube una versión nueva. Los primeros días AdMob puede servir pocos anuncios: es normal.")),
      h("div", { class: "form-col" }, appId, inter, rew, ban, ape, guardar),
      h("p", { class: "muted small" }, "Sin ids, la versión de tienda va sin anuncios (y así se declara en Play Console). Para quitarlos, borra los tres campos y guarda."));
  }

  function pillAnuncios(p: Proyecto): HTMLElement {
    return p.admob ? h("span", { class: "pill done" }, "activos") : h("span", { class: "pill queued" }, "sin anuncios");
  }

  function seccionPublicar(p: Proyecto, cuenta: CuentaPlay | null, correoUsuario: string, acc: AccionesPublicar): HTMLElement {
    const cab = h("div", { class: "sheet-head" }, h("h2", {}, "Publicar en Google Play"), h("span", { class: "tag" }, "gratis"));
    if (!cuenta) {
      const estudio = h("input", { type: "text", maxlength: "40", placeholder: "Ej.: Daniel Studio", "aria-label": "Nombre de estudio" });
      const correo = h("input", { type: "email", maxlength: "120", placeholder: "tu@correo.com", "aria-label": "Correo de contacto" });
      correo.value = correoUsuario;
      const guardar = h("button", { class: "btn btn-brass", style: "width:100%" }, "Guardar y seguir");
      guardar.addEventListener("click", () => {
        guardar.disabled = true;
        void acc.guardar(estudio.value, correo.value).finally(() => { guardar.disabled = false; });
      });
      return h("section", { class: "sheet" }, cab,
        h("p", { class: "muted" }, "Solo una vez: tu nombre de estudio (sale en la tienda y en el nombre del paquete, com.tuestudio.tujuego) y el correo de contacto que verá la gente en Google Play."),
        h("div", { class: "form-col" }, estudio, correo, guardar));
    }
    const estado = p.play?.estado;
    const pub = p.files?.publicar;
    if (!estado || !pub) {
      return h("section", { class: "sheet" }, cab,
        h("p", { class: "muted" }, "Chispa lo prepara todo: el .aab firmado para Android 16, el icono 512, el gráfico 1024×500 y las capturas a la medida de Google, los textos en español e inglés, la política de privacidad y las respuestas de cada formulario de Play Console."),
        h("button", { class: "btn btn-brass", style: "width:100%", onclick: () => acc.lanzar("primer_aab", "internal") }, svg(ICONOS.tienda), "Preparar para Google Play"));
    }
    const clave = (id: string) => `orq-play-${p.id}-${id}`;
    const hecho = (id: string) => { try { return localStorage.getItem(clave(id)) === "1"; } catch { return false; } };
    const pasos = pub.guia.pasos;
    const contador = h("span", { class: "tag" }, "");
    const contar = () => { contador.textContent = `${pasos.filter((x) => hecho(x.id)).length}/${pasos.length} pasos`; };
    const lista = h("div", { class: "pasos" });
    for (const paso of pasos) lista.append(pasoGuia(p, paso, hecho(paso.id), (si) => {
      try { localStorage.setItem(clave(paso.id), si ? "1" : "0"); } catch { /* sin almacenamiento */ }
      contar();
    }));
    contar();
    const pie = h("div", { class: "publicar-pie" });
    if (estado === "primer_aab") {
      pie.append(h("p", { class: "muted small" }, "Cuando hayas creado el juego en Play Console, subido el primer .aab y dado acceso a Orquestador, pulsa aquí: a partir de ahora cada versión se sube sola con textos e imágenes."),
        h("button", { class: "btn btn-brass", style: "width:100%", onclick: () => acc.lanzar("subir", "alpha") }, "Ya está: subir a prueba cerrada"));
    } else {
      const sel = h("select", { "aria-label": "Pista de Google Play" });
      for (const [k, v] of Object.entries(PISTAS)) {
        const o = h("option", { value: k }, v);
        if (k === (p.play?.pista ?? "alpha")) o.selected = true;
        sel.append(o);
      }
      pie.append(
        h("p", {}, h("span", { class: "pill done" }, estado === "borrador" ? "borrador en Play Console" : "en Google Play"),
          ` ${PISTAS[p.play?.pista ?? "alpha"] ?? ""} · versión ${p.play?.version_code ?? ""}`),
        estado === "borrador" ? h("p", { class: "muted small" }, "Google lo tiene como borrador: en Play Console abre la versión y pulsa «Enviar a revisión».") : "",
        h("div", { class: "chat-input" }, sel, h("button", { class: "btn btn-brass btn-small", onclick: () => acc.lanzar("subir", sel.value) }, "Subir versión actual")));
    }
    if (estado !== "primer_aab") pie.append(bloqueAmigos(p, acc));
    pie.append(h("button", { class: "linkish", onclick: () => acc.lanzar("primer_aab", "internal") }, "Volver a preparar el .aab y la guía"));
    return h("section", { class: "sheet" }, h("div", { class: "sheet-head" }, h("h2", {}, "Publicar en Google Play"), contador),
      h("p", { class: "muted small" }, `Paquete ${pub.paquete} · ${pub.guia.aviso}`), lista, pie);
  }

  /** Prueba interna con amigos: hasta 100 personas por correo, sin revisión de Google y en minutos.
   *  No cuenta para los 12 probadores de la prueba cerrada, pero sirve para enseñarlo desde el día 1. */
  function bloqueAmigos(p: Proyecto, acc: AccionesPublicar): HTMLElement {
    const clave = `orq-interna-${p.id}`;
    let guardado = "";
    try { guardado = localStorage.getItem(clave) ?? ""; } catch { /* sin almacenamiento */ }
    const enlace = h("input", { type: "url", maxlength: "200", placeholder: "https://play.google.com/apps/internaltest/...", value: guardado,
      "aria-label": "Enlace de la prueba interna" }) as HTMLInputElement;
    const compartirBtn = h("button", { class: "btn btn-line btn-small", type: "button" }, "Compartir con amigos") as HTMLButtonElement;
    const valido = () => /^https:\/\/play\.google\.com\/apps\/(internaltest|testing)\//.test(enlace.value.trim());
    const refrescar = () => { compartirBtn.disabled = !valido(); };
    enlace.addEventListener("input", () => {
      refrescar();
      if (valido()) { try { localStorage.setItem(clave, enlace.value.trim()); } catch { /* sin almacenamiento */ } }
    });
    compartirBtn.addEventListener("click", async () => {
      const r = await compartirEnlace(enlace.value.trim(), `Prueba «${p.titulo}» antes que nadie`);
      if (r === "copiado") aviso("Enlace copiado: pégalo en WhatsApp o donde quieras");
    });
    refrescar();
    return h("details", { class: "paso" }, h("summary", {}, h("span", {}, "Probar con amigos (prueba interna, sin esperar)")),
      h("p", { class: "small" }, "Hasta 100 personas, sin revisión de Google y disponible en minutos. No cuenta para los 12 probadores de la prueba cerrada, pero sirve para enseñarlo ya."),
      h("p", { class: "small" }, "1. Sube la versión a la prueba interna:"),
      h("button", { class: "btn btn-line btn-small", type: "button", onclick: () => acc.lanzar("subir", "internal") }, "Subir a prueba interna"),
      h("p", { class: "small" }, "2. En Play Console → Probar y publicar → Prueba interna → Probadores: crea una lista con los correos de Google de tus amigos y guarda."),
      h("p", { class: "small" }, "3. Copia ahí mismo el enlace «Unirse en Android» y pégalo aquí:"),
      h("div", { class: "form-col" }, enlace, compartirBtn),
      h("p", { class: "muted small" }, "Cada amigo abre el enlace con su cuenta de Google, acepta ser probador e instala desde Google Play."));
  }

  function pasoGuia(p: Proyecto, paso: PasoGuia, hecho: boolean, marcar: (si: boolean) => void): HTMLElement {
    const check = h("input", { type: "checkbox", "aria-label": `Hecho: ${paso.titulo}` });
    check.checked = hecho;
    const caja = h("details", { class: "paso" + (hecho ? " hecho" : "") },
      h("summary", {}, check, h("span", {}, paso.titulo)));
    check.addEventListener("click", (e) => e.stopPropagation());
    check.addEventListener("change", () => { caja.classList.toggle("hecho", check.checked); marcar(check.checked); });
    caja.append(h("p", {}, paso.texto));
    if (paso.campos) {
      const tabla = h("div", { class: "campos" });
      for (const [k, v] of Object.entries(paso.campos)) {
        tabla.append(h("div", { class: "campo" }, h("span", { class: "muted small" }, k), h("strong", {}, v),
          h("button", { class: "linkish", onclick: () => void copiarTexto(v) }, "Copiar")));
      }
      caja.append(tabla);
    }
    if (paso.datos) {
      for (const d of paso.datos) {
        caja.append(h("div", { class: "campo" }, h("strong", {}, d.tipo),
          h("span", { class: "muted small" }, `${d.compartido ? "Recogido y compartido" : "Recogido, no compartido"} · ${d.fines.join(", ")}${d.nota ? " · " + d.nota : ""}`)));
      }
    }
    if (paso.id === "primer_aab" && p.files?.publicar) {
      caja.append(botonArchivo("btn btn-line", ICONOS.descarga, "Descargar el .aab", p.files.publicar.aab),
        h("p", { class: "muted small" }, `Huella SHA-256 de tu llave de subida: ${p.files.publicar.huella_llave}`));
    }
    if (paso.enlace) caja.append(h("a", { class: "btn btn-line btn-small", href: paso.enlace, target: "_blank", rel: "noopener" }, "Abrir"));
    return caja;
  }

  async function copiarTexto(t: string) {
    try {
      await navigator.clipboard.writeText(t);
      aviso("Texto copiado");
    } catch {
      aviso("No se pudo copiar: mantén pulsado para copiarlo a mano");
    }
  }

  async function compartirVideo(ruta: string, estilo: string, m: Marketing, idioma: "es" | "en") {
    const texto = m.redes[idioma].tiktok;
    let url: string;
    try {
      url = await app.api.url(ruta);
    } catch (e) {
      return aviso(mensajeError(e, "No se pudo abrir el vídeo."));
    }
    const nombre = `${estilo}.mp4`;
    const r = await compartir(url, nombre, texto);
    if (r === "descargado") aviso("Vídeo descargado y texto copiado: súbelo desde la app de la red");
  }

  // ------------------------------------------------------------------ ficha + taller

  // El cartel de la pestaña es para la lista; en la ficha de un juego manda el juego.
  function cartel(ver: boolean): void {
    const c = raiz.previousElementSibling;
    if (c?.classList.contains("cartel-chispa")) (c as HTMLElement).hidden = !ver;
  }

  async function ficha(id: string): Promise<void> {
    parar();
    cartel(false);
    let p: Proyecto;
    let precioVideos = 20;
    let cuenta: CuentaPlay | null = null;
    let correoUsuario = "";
    try {
      [p, precioVideos, cuenta, correoUsuario] = await Promise.all([app.api.proyecto(id), app.api.precioMarketing().catch(() => 20),
        app.api.cuentaPlay().catch(() => null), app.api.usuario().then((u) => u?.email ?? "").catch(() => "")]);
    } catch (e) {
      avisoError(e, "No se pudo abrir el juego.", () => void ficha(id));
      return lista();
    }
    if (!vivo) return;
    const volver = h("button", { class: "btn btn-line", onclick: () => void lista() }, svg(ICONOS.atras), "Mis juegos");
    // Borrador (boceto guardado gratis): se juega con los dibujos provisionales y desde aquí se fabrica
    // el juego completo. Sin taller, APK ni publicación hasta entonces.
    const borrador = p.files as unknown as { borrador?: boolean; preview?: string; idea?: string } | null;
    if (borrador?.borrador) {
      const precio = await app.api.precioJuego().catch(() => 120);
      const fabricarlo = h("button", { class: "btn btn-brass", style: "width:100%" }, "Fabricarlo con su arte, música y APK",
        h("span", { class: "price" }, svg(ICONOS.tuerca), String(precio))) as HTMLButtonElement;
      fabricarlo.disabled = !borrador.preview || !borrador.idea || precio > app.tuercas;
      fabricarlo.addEventListener("click", async () => {
        fabricarlo.disabled = true;
        try {
          const r = await app.api.encargar(borrador.idea!, borrador.preview);
          app.ponerTuercas(r.credits);
          aviso("¡En marcha! Sigue la fabricación en el taller");
          app.ir("taller");
        } catch (e) {
          aviso(mensajeError(e, "No se pudo encargar el juego."));
          fabricarlo.disabled = false;
        }
      });
      const quitarBoceto = h("button", { class: "btn btn-line btn-small" }, "Borrar este boceto") as HTMLButtonElement;
      let seguro = false;
      quitarBoceto.addEventListener("click", async () => {
        if (!seguro) { seguro = true; quitarBoceto.textContent = "Pulsa otra vez para borrarlo"; return; }
        quitarBoceto.disabled = true;
        try {
          await app.api.borrarBoceto(p.id);
          aviso("Boceto borrado");
          void lista();
        } catch (e) {
          aviso(mensajeError(e, "No se pudo borrar el boceto."));
          quitarBoceto.disabled = false;
        }
      });
      raiz.replaceChildren(volver, h("section", { class: "sheet" },
        h("div", { class: "detail-head" }, h("div", {}, h("h2", {}, p.titulo), h("span", { class: "pill" }, "boceto gratis"))),
        h("div", { style: "height:14px" }),
        h("button", { class: "btn btn-line", style: "width:100%", onclick: () => void jugar(p) }, svg(ICONOS.jugar), "Jugar el boceto"),
        h("p", { class: "muted small", style: "margin:12px 0" },
          "Es tu juego con los niveles de verdad y dibujos provisionales. Al fabricarlo, Chispa le dibuja sus personajes y fondos, le pone música y voz, y te deja el APK listo para Google Play."),
        fabricarlo,
        precio > app.tuercas ? h("p", { class: "muted small", style: "margin-top:8px" }, "Te faltan tuercas: consigue más en la pestaña Tuercas.") : "",
        h("div", { style: "height:14px" }), quitarBoceto));
      return;
    }
    const galeria = h("div", { class: "gallery" });
    for (const c of p.files?.capturas ?? []) {
      const img = h("img", { alt: "Captura del juego", loading: "lazy" });
      galeria.append(img);
      void app.api.url(c).then((u) => { img.src = u; }).catch(() => img.remove());
    }
    // Cabecera de la ficha (13 nov): el juego en grande, con su captura de fondo y «Jugar ya» encima.
    const heroe = h("div", { class: "ficha-heroe" },
      h("div", { class: "detail-head" }, icono(p.files?.icono),
        h("div", {}, h("h2", {}, p.titulo), h("span", { class: "pill done" }, `versión ${p.version}`))),
      h("button", { class: "btn btn-brass", style: "width:100%", onclick: () => void jugar(p) }, svg(ICONOS.jugar), "Jugar ya"));
    const fondoHeroe = (p.files?.capturas ?? [])[2] ?? (p.files?.capturas ?? [])[0];
    if (fondoHeroe) void app.api.url(fondoHeroe).then((u) => heroe.style.setProperty("--fondo", `url("${u}")`)).catch(() => undefined);
    else if (p.genero) heroe.style.setProperty("--fondo", `url("generos_arte/${p.genero}.webp")`);
    const cabecera = h("section", { class: "sheet" },
      heroe,
      h("div", { style: "height:14px" }), galeria,
      h("div", { style: "height:10px" }),
      // 1 - Descargas en una rejilla compacta: lo importante (jugar) va solo y grande.
      h("div", { class: "descargas" },
        etiqueta(botonArchivo("btn btn-line", ICONOS.descarga, "APK", p.files?.apk), "Descargar el APK para Android"),
        etiqueta(h("button", { class: "btn btn-line", onclick: () => void verClip(p) }, svg(ICONOS.video), "Clip"), "Clip vertical para TikTok, Shorts y Reels"),
        etiqueta(botonArchivo("btn btn-line", ICONOS.tienda, "Ficha", p.files?.ficha), "Ficha para Google Play (.zip)"),
        etiqueta(botonArchivo("btn btn-line", ICONOS.caja, "Godot", p.files?.proyecto), "Proyecto de Godot (.zip)")));

    // ---- chat
    const chat = h("div", { class: "chat", "aria-live": "polite" });
    for (const v of p.versiones) {
      chat.append(burbuja("yo", v.version === 1 ? `Idea: ${v.prompt}` : v.prompt));
      const linea = h("div", { class: "msg chispa" }, h("span", {}, v.version === 1 ? "Primera versión fabricada." : `Versión ${v.version} lista.`));
      if (v.version < p.version) {
        linea.append(" ", h("button", { class: "linkish", onclick: () => void restaurar(v.version) }, `Volver a esta versión`));
      } else {
        linea.append(" ", h("span", { class: "tag" }, "actual"));
      }
      chat.append(linea);
    }
    const entrada = h("textarea", { rows: "2", maxlength: "400", placeholder: "¿Qué cambiamos? Ej.: haz al gato negro", "aria-label": "Instrucción para Chispa" });
    const enviar = h("button", { class: "btn btn-brass btn-small" }, "Enviar");
    const chips = h("div", { class: "chips desliza", role: "list", "aria-label": "Ideas de cambios" }, ...SUGERENCIAS.map((s) => h("button", { class: "chip", type: "button", onclick: () => { entrada.value = s; entrada.focus(); } }, s)));
    const nota = h("p", { class: "muted small" }, "Chispa te dice qué hará y cuánto cuesta antes de cobrar nada. Volver atrás cuesta 3 tuercas.");
    // 1 - Editor manual: dibujar los niveles casilla a casilla (los bots los prueban al guardar).
    const aMano = h("button", { class: "btn btn-line btn-small", type: "button" }, "✎ Editar niveles a mano");
    aMano.addEventListener("click", () => void abrirEditor(app, p, (prop) => {
      mostrar("taller");
      chat.append(burbuja("chispa", prop.resumen));
      if (prop.plan_id && prop.operaciones.length) chat.append(tarjetaPlan(prop));
      bajar();
    }));
    // 2 - Qué lleva el juego: interruptores que se guardan como un cambio (op "funciones").
    const alPlan = (prop: Propuesta): void => {
      mostrar("taller");
      chat.append(burbuja("chispa", prop.resumen));
      if (prop.plan_id && prop.operaciones.length) chat.append(tarjetaPlan(prop));
      bajar();
    };
    const funciones = seccionFunciones(p, alPlan);
    const taller = h("section", { class: "sheet" },
      h("div", { class: "sheet-head" }, h("h2", {}, "Taller de este juego"), h("span", { class: "tag" }, p.versiones.length === 1 ? "1 versión" : `${p.versiones.length} versiones`)),
      chat, h("div", { class: "chat-input" }, entrada, enviar), chips, h("div", { class: "btn-row" }, aMano), nota);

    const videos = seccionVideos(p, precioVideos, () => void encargarVideos());
    const publicacion = seccionPublicar(p, cuenta, correoUsuario, {
      guardar: async (estudio, correo) => {
        try {
          await app.api.guardarCuentaPlay(estudio, correo);
          aviso("Datos guardados");
          void ficha(p.id);
        } catch (e) {
          aviso(mensajeError(e, "No se pudieron guardar tus datos."));
        }
      },
      lanzar: (modo, pista) => void publicarJuego(modo, pista),
    });
    const jugadores = seccionJugadores(p, (instruccion) => {
      entrada.value = instruccion;
      void pedir();
    });
    const anuncios = seccionAnuncios(p);
    const apple = seccionApple(p, () => void publicarApple());
    // 1 - Contenido generado por la IA: se puede denunciar sin salir de la app (política de Google Play).
    const denuncia = h("div", { class: "wrap-pie" }, botonDenuncia("Reportar contenido inapropiado generado por la IA",
      (m) => app.api.denunciar({ proyecto: p.id }, m)));
    const compartirSec = seccionCompartir(p);
    // 2 - Pestañas: cada tarea en su sitio en vez de una página de cuatro pantallas.
    const paneles: Record<PestanaJuego, HTMLElement> = {
      taller: h("div", { class: "panel-juego", role: "tabpanel" }, taller,
        plegable(seccionGiros(p, alPlan), (p.giros?.length ? p.giros.map((g) => GIROS.find((x) => x.id === g)?.nombre ?? g).join(" + ") : "hazlo único")
          + (typeof p.originalidad === "number" ? `, originalidad ${p.originalidad}%` : "")),
        plegable(seccionDibujo(p, alPlan), ""), plegable(funciones, ""), denuncia),
      publicar: h("div", { class: "panel-juego", role: "tabpanel" }, publicacion, apple, anuncios, seccionGanancias(p, app.api.ingresos(p.id))),
      compartir: h("div", { class: "panel-juego", role: "tabpanel" }, compartirSec, seccionRegalo(p), seccionItch(p), videos, seccionPlanRedes(p)),
      jugadores: h("div", { class: "panel-juego", role: "tabpanel" }, jugadores, seccionAb(p, alPlan), seccionClasificacion(p), ...(p.genero === "aldea" ? [seccionLiga(p)] : []), seccionIngresos(p), seccionOpiniones(p, (instruccion) => { entrada.value = instruccion; void pedir(); mostrar("taller"); }), seccionResenas(p), seccionEventos(p), seccionPremio(p), seccionClase(p), seccionCharla(p)),
    };
    const botones = new Map<PestanaJuego, HTMLButtonElement>();
    const barra = h("div", { class: "pestanas-juego", role: "tablist", "aria-label": "Secciones del juego" });
    for (const [id, nombre] of [["taller", "Taller"], ["publicar", "Publicar"], ["compartir", "Compartir"], ["jugadores", "Jugadores"]] as const) {
      const b = h("button", { type: "button", role: "tab" }, nombre);
      b.addEventListener("click", () => mostrar(id));
      botones.set(id, b);
      barra.append(b);
    }
    function mostrar(id: PestanaJuego) {
      pestanaJuego = id;
      for (const [k, b] of botones) {
        b.setAttribute("aria-selected", String(k === id));
        paneles[k].hidden = k !== id;
      }
    }
    mostrar(pestanaJuego);
    if (seccionPendiente) {
      const s = seccionPendiente;
      seccionPendiente = "";
      window.setTimeout(() => paneles[pestanaJuego].querySelector(`[data-seccion="${s}"]`)?.scrollIntoView({ behavior: "smooth", block: "start" }), 350);
    }
    // 3 - Asesor: arriba del todo, para que lo primero que se vea sea qué hacer.
    const asesor = seccionAsesor(p, (a) => {
      if (a.tipo === "ir") { mostrar(a.pestana); return; }
      if (a.tipo === "arreglar") { entrada.value = a.instruccion; void pedir(); return; }
      void app.api.planManual(p.id, [a.op]).then((prop) => {
        mostrar("taller");
        chat.append(burbuja("chispa", prop.resumen));
        if (prop.plan_id && prop.operaciones.length) chat.append(tarjetaPlan(prop));
        bajar();
      }).catch((e) => aviso(mensajeError(e, "No se pudo preparar el cambio.")));
    });
    const camino = seccionLanzamiento(p, (a) => {
      if (a === "jugar") void jugar(p);
      else if (a === "lanzadera") app.ir("lanzadera");
      else if (a === "preparar") { mostrar("publicar"); void publicarJuego("primer_aab", "internal"); }
      else {
        mostrar("publicar");
        (a === "anuncios" ? anuncios : publicacion).scrollIntoView({ behavior: "smooth", block: "start" });
      }
    });
    // Hasta estar en la prueba cerrada manda el camino a Google Play; después, el asesor (crecer).
    const enCerrada = Boolean(p.play?.estado && p.play.estado !== "primer_aab" && p.play.pista && p.play.pista !== "internal");
    raiz.replaceChildren(volver, cabecera, camino, ...(enCerrada ? [asesor] : []), barra, ...Object.values(paneles));
    window.scrollTo({ top: 0 });

    function bloquear(si: boolean) {
      entrada.disabled = si;
      enviar.disabled = si;
      for (const b of chat.querySelectorAll<HTMLButtonElement>(".linkish")) b.disabled = si;
    }

    function burbuja(quien: "yo" | "chispa", texto: string, clase = "") {
      return h("div", { class: `msg ${quien} ${clase}` }, texto);
    }

    function bajar() {
      if (pestanaJuego !== "taller") mostrar("taller");
      chat.scrollTop = chat.scrollHeight;
      taller.scrollIntoView({ block: "end", behavior: "smooth" });
    }

    async function pedir() {
      const texto = entrada.value.trim();
      if (texto.length < 2) return;
      entrada.value = "";
      chat.append(burbuja("yo", texto));
      const pensando = burbuja("chispa", "Pensando...", "pensando");
      chat.append(pensando);
      bajar();
      bloquear(true);
      let prop: Propuesta;
      try {
        prop = await app.api.proponer(p.id, texto);
      } catch (e) {
        pensando.replaceWith(burbuja("chispa", mensajeError(e, "No he podido pensar el cambio."), "error"));
        bloquear(false);
        return;
      }
      pensando.remove();
      chat.append(burbuja("chispa", prop.resumen));
      if (prop.no_puedo && prop.no_puedo !== prop.resumen) chat.append(burbuja("chispa", prop.no_puedo, "nota"));
      if (prop.pregunta) chat.append(burbuja("chispa", prop.pregunta));
      if (prop.plan_id && prop.operaciones.length) chat.append(tarjetaPlan(prop));
      if (prop.no_puedo && texto.length >= 8) chat.append(await tarjetaPrograma(texto));
      bloquear(false);
      bajar();
    }

    function tarjetaPlan(prop: Propuesta) {
      const falta = prop.coste - app.tuercas;
      const aplicar = h("button", { class: "btn btn-brass btn-small" }, "Aplicar ", h("span", { class: "price" }, svg(ICONOS.tuerca), String(prop.coste)));
      const no = h("button", { class: "btn btn-line btn-small" }, "Mejor no");
      const tarjeta = h("div", { class: "msg plan" },
        h("p", { class: "small muted" }, falta > 0 ? `Te faltan ${falta} tuercas para este cambio.` : "Solo se rehace lo que cambia."),
        h("div", { class: "btn-row" }, no, aplicar));
      aplicar.disabled = falta > 0;
      no.addEventListener("click", () => tarjeta.replaceWith(burbuja("chispa", "Vale, no toco nada.")));
      aplicar.addEventListener("click", async () => {
        aplicar.disabled = true;
        no.disabled = true;
        try {
          const r = await app.api.aplicar(prop.plan_id!);
          app.ponerTuercas(r.credits);
          tarjeta.replaceWith(burbuja("chispa", `¡Manos a la obra! (${prop.coste} tuercas)`));
          seguir(r.job_id);
        } catch (e) {
          tarjeta.replaceWith(burbuja("chispa", mensajeError(e, "No se pudo aplicar."), "error"));
        }
      });
      return tarjeta;
    }

    /** 1 - Lo que el taller no sabe hacer: Chispa lo programa (mod revisado, compilado y jugado por bots). */
    async function tarjetaPrograma(instruccion: string) {
      const precio = await app.api.precioPrograma().catch(() => 30);
      const falta = precio - app.tuercas;
      const si = h("button", { class: "btn btn-brass btn-small" }, "Que Chispa lo programe ", h("span", { class: "price" }, svg(ICONOS.tuerca), String(precio)));
      const no = h("button", { class: "btn btn-line btn-small" }, "Mejor no");
      const tarjeta = h("div", { class: "msg plan" },
        h("p", { class: "small" }, "Puedo programarlo yo: escribo el código, compruebo que es seguro y los bots juegan la nueva versión antes de dártela. Si no sale, te devuelvo las tuercas."),
        falta > 0 ? h("p", { class: "small muted" }, `Te faltan ${falta} tuercas.`) : "",
        h("div", { class: "btn-row" }, no, si));
      si.disabled = falta > 0;
      no.addEventListener("click", () => tarjeta.replaceWith(burbuja("chispa", "Vale, lo dejamos así.")));
      si.addEventListener("click", async () => {
        si.disabled = true;
        no.disabled = true;
        bloquear(true);
        try {
          const r = await app.api.programar(p.id, instruccion);
          app.ponerTuercas(r.credits);
          tarjeta.replaceWith(burbuja("chispa", `¡Me pongo a programar! (${precio} tuercas)`));
          seguir(r.job_id);
        } catch (e) {
          tarjeta.replaceWith(burbuja("chispa", mensajeError(e, "No he podido ponerme a programarlo."), "error"));
          bloquear(false);
        }
      });
      return tarjeta;
    }

    async function restaurar(n: number) {
      bloquear(true);
      chat.append(burbuja("yo", `Volver a la versión ${n}`));
      try {
        const r = await app.api.volver(p.id, n);
        seguir(r.job_id);
      } catch (e) {
        chat.append(burbuja("chispa", mensajeError(e, "No se pudo volver a esa versión."), "error"));
        bloquear(false);
      }
      bajar();
    }

    async function publicarJuego(modo: "primer_aab" | "subir", pista: string) {
      bloquear(true);
      chat.append(burbuja("yo", modo === "subir" ? "Súbelo a Google Play" : "Prepáralo para Google Play"));
      try {
        const r = await app.api.publicar(p.id, modo, pista);
        seguir(r.job_id, modo === "subir" ? "Subido a Google Play" : "Listo: sigue la guía de publicación");
      } catch (e) {
        chat.append(burbuja("chispa", mensajeError(e, "No se pudo preparar la publicación."), "error"));
        bloquear(false);
      }
      bajar();
    }

    async function publicarApple() {
      bloquear(true);
      chat.append(burbuja("yo", "Súbelo a la App Store"));
      try {
        const r = await app.api.publicarIOS(p.id);
        seguir(r.job_id, "En App Store Connect: aparecerá en TestFlight en unos minutos");
      } catch (e) {
        chat.append(burbuja("chispa", mensajeError(e, "No se pudo preparar la subida a Apple."), "error"));
        bloquear(false);
      }
      bajar();
    }

    async function encargarVideos() {
      bloquear(true);
      chat.append(burbuja("yo", "Hazme vídeos para TikTok, Shorts y Reels"));
      try {
        const r = await app.api.marketing(p.id, modoYoutube());
        void app.refrescarTuercas();
        seguir(r.job_id, "Tus 3 vídeos para redes están listos");
      } catch (e) {
        chat.append(burbuja("chispa", mensajeError(e, "No se pudieron encargar los vídeos."), "error"));
        bloquear(false);
      }
      bajar();
    }

    function seguir(jobId: string, listo = "Nueva versión lista") {
      bloquear(true);
      const progreso = burbuja("chispa", "En la cola de la fábrica...", "pensando");
      chat.append(progreso);
      bajar();
      parar();
      let botonAdelanto: HTMLElement | null = null;
      dejarDeSeguir = app.api.seguir(jobId, (t) => {
        const ultimo = t.progress[t.progress.length - 1];
        if (t.status === "running" && ultimo) progreso.textContent = ultimo.mensaje;
        // El cambio ya se puede jugar (los bots lo han probado) aunque el APK y la ficha sigan en marcha.
        const adelanto = t.progress.find((e) => e.adelanto)?.adelanto;
        if (t.status === "running" && adelanto && !botonAdelanto) {
          const jugarYa = h("button", { class: "btn btn-brass btn-small", type: "button" }, svg(ICONOS.jugar), " Jugar el cambio ya");
          jugarYa.addEventListener("click", async () => {
            const motor = app.api.motor();
            try {
              abrirJugador({ motor, pck: motor ? await app.api.url(adelanto) : null, titulo: p.titulo, portada: undefined });
            } catch (e) {
              aviso(mensajeError(e, "No se pudo abrir el cambio. Espera a que termine."));
            }
          });
          botonAdelanto = h("div", { class: "msg chispa" }, jugarYa);
          chat.append(botonAdelanto);
          bajar();
        }
        if (t.status !== "running") botonAdelanto?.remove();
        if (t.status === "done") {
          parar();
          aviso(listo);
          void app.refrescarTuercas();
          void ficha(p.id);
        } else if (t.status === "failed") {
          parar();
          progreso.className = "msg chispa error";
          progreso.textContent = t.refunded ? "Algo se ha roto en la fábrica. Te he devuelto las tuercas." : "Algo se ha roto en la fábrica.";
          void app.refrescarTuercas();
          bloquear(false);
        }
      });
    }

    enviar.addEventListener("click", () => void pedir());
    entrada.addEventListener("keydown", (e) => {
      if (e.key === "Enter" && !e.shiftKey) {
        e.preventDefault();
        void pedir();
      }
    });
    if (p.activo) seguir(p.activo.id);
  }

  void lista();
  return { el: raiz, limpiar: () => { vivo = false; parar(); } };
}
