// Cuenta: quién eres, a qué servidor estás conectado, privacidad, salir y borrar la cuenta.

import type { App } from "../main";
import { anunciosDisponibles, mostrarPrivacidadAnuncios, privacidadAnunciosRequerida } from "../nativo";
import { abrir, aviso, h, type VistaHecha } from "../ui";
import { insignias, nivel } from "../creador";
import { mensajeError } from "../errores";
import { idioma, ponerIdioma } from "../idioma";
import { efectosEncendidos, musicaEncendida, ponerEfectos, ponerMusicaActiva } from "../sonido";

function interruptor(nombre: string, ayuda: string, encendido: boolean, cambiar: (v: boolean) => void): HTMLElement {
  const b = h("button", { class: "interruptor", role: "switch", "aria-checked": String(encendido), "aria-label": nombre, "data-mudo": "" });
  b.addEventListener("click", () => {
    const v = b.getAttribute("aria-checked") !== "true";
    b.setAttribute("aria-checked", String(v));
    cambiar(v);
  });
  return h("div", { class: "fila-interruptor" }, h("div", {}, h("strong", {}, nombre), h("p", { class: "muted small", style: "margin:2px 0 0" }, ayuda)), b);
}

/** Web publica (GitHub Pages): privacidad, terminos y borrar la cuenta. */
const WEB = ((import.meta.env.VITE_WEB as string | undefined) ?? "").replace(/\/$/, "");

export function vistaCuenta(app: App): VistaHecha {
  const correo = h("p", {}, "...");
  void app.api.usuario().then((u) => { correo.textContent = u?.email ?? ""; });
  const salir = h("button", { class: "btn btn-line", style: "width:100%", onclick: () => void app.salir() }, "Cerrar sesión");

  // 1 - Privacidad: enlaces legales y, si la ley lo pide (EEE), cambiar el consentimiento de anuncios.
  const privacidad = h("div", { class: "btn-row" });
  if (WEB) {
    privacidad.append(
      h("button", { class: "btn btn-line btn-small", onclick: () => void abrir(`${WEB}/privacidad.html`) }, "Privacidad"),
      h("button", { class: "btn btn-line btn-small", onclick: () => void abrir(`${WEB}/terminos.html`) }, "Términos"));
  }
  if (anunciosDisponibles()) {
    void privacidadAnunciosRequerida().then((si) => {
      if (!si) return;
      privacidad.append(h("button", { class: "btn btn-line btn-small", onclick: () => void mostrarPrivacidadAnuncios().catch(() => aviso("No se pudo abrir.")) },
        "Consentimiento de anuncios"));
    });
  }

  // 2 - Borrar la cuenta (Google Play lo exige dentro de la app). Hay que escribir BORRAR.
  const zona = h("div", {});
  const pedir = h("button", { class: "btn btn-line btn-small peligro", onclick: () => confirmar() }, "Borrar mi cuenta");
  zona.append(pedir);
  function confirmar() {
    const campo = h("input", { type: "text", placeholder: "BORRAR", autocomplete: "off", "aria-label": "Escribe BORRAR para confirmar" });
    const si = h("button", { class: "btn btn-small peligro" }, "Borrar para siempre");
    const no = h("button", { class: "btn btn-line btn-small" }, "Cancelar");
    const estado = h("p", { class: "small", role: "status" });
    si.disabled = true;
    campo.addEventListener("input", () => { si.disabled = campo.value.trim() !== "BORRAR"; });
    no.addEventListener("click", () => zona.replaceChildren(pedir));
    si.addEventListener("click", async () => {
      si.disabled = no.disabled = campo.disabled = true;
      estado.textContent = "Borrando...";
      try {
        const r = await app.api.borrarCuenta();
        aviso(r.premium_activo ? "Cuenta borrada. Cancela la suscripción en Google Play para que no se renueve." : "Cuenta borrada.");
        if (r.premium_activo) void abrir("https://play.google.com/store/account/subscriptions");
        await app.salir();
      } catch (e) {
        estado.textContent = mensajeError(e, "No se pudo borrar la cuenta.");
        estado.className = "small err";
        no.disabled = campo.disabled = false;
        si.disabled = campo.value.trim() !== "BORRAR";
      }
    });
    zona.replaceChildren(
      h("p", { class: "small" }, "Se borran tu cuenta, tus tuercas, tus juegos con todas sus versiones y archivos, tus llaves y el permiso de YouTube. Lo publicado en tu cuenta de Google Play o App Store no se toca. No se puede deshacer."),
      h("p", { class: "muted small" }, "Escribe BORRAR para confirmar"), campo, estado, h("div", { class: "btn-row" }, no, si));
    campo.focus();
  }

  // 3 - Perfil de creador: nivel por lo que haces y lo que consigue tu trabajo, e insignias.
  const perfil = h("section", { class: "sheet creador" }, h("div", { class: "sheet-head" }, h("h2", {}, "Tu perfil de creador")),
    h("p", { class: "muted small" }, "Cargando..."));
  void app.api.perfilCreador().then((p) => {
    const n = nivel(p);
    const ins = insignias(p);
    perfil.replaceChildren(
      h("div", { class: "sheet-head" }, h("h2", {}, "Tu perfil de creador"), h("span", { class: "tag" }, `${n.puntos} pts`)),
      h("p", { class: "creador-nivel" }, n.nombre),
      h("div", { class: "lz-barra", role: "img", "aria-label": n.siguiente ? `Faltan ${n.faltan} puntos para ${n.siguiente}` : "Nivel máximo" },
        h("span", { style: `width:${Math.round(n.progreso * 100)}%` })),
      h("p", { class: "muted small" }, n.siguiente ? `Te faltan ${n.faltan} puntos para ${n.siguiente}. Suman tus juegos, las partidas, los me gusta, los remix y los retos.` : "Has llegado a lo más alto."),
      h("p", { class: "small" }, `${p.juegos} juegos · ${p.jugadas} partidas · ${p.megusta} me gusta`),
      h("div", { class: "insignias", role: "list", "aria-label": "Insignias" },
        ...ins.map((x) => h("div", { class: "insignia" + (x.tiene ? " tiene" : ""), role: "listitem", title: x.como },
          h("strong", {}, x.nombre), h("span", { class: "muted small" }, x.tiene ? "Conseguida" : x.como)))));
  }).catch(() => perfil.remove());

  return {
    el: h("div", { class: "wrap-inner" },
      perfil,
      h("section", { class: "sheet" },
        h("div", { class: "sheet-head" }, h("h2", {}, "Sonido")),
        interruptor("Efectos de sonido", "Toques, tuercas y la fanfarria al terminar un juego", efectosEncendidos(), ponerEfectos),
        interruptor("Música", "Banda sonora de la app: tranquila en los menús y con ritmo mientras se fabrica", musicaEncendida(), ponerMusicaActiva)),
      h("section", { class: "sheet" },
        h("div", { class: "sheet-head" }, h("h2", {}, "Cuenta")),
        h("p", { class: "muted small" }, "Correo"), correo, h("div", { style: "height:12px" }),
        h("p", { class: "muted small" }, "Conexión"),
        h("p", {}, app.api.demo ? "Modo demostración (sin servidor)" : "Servidor de Orquestador"),
        h("div", { style: "height:12px" }),
        // Para saber si el APK instalado es el último (12 nov: se instalaba uno viejo sin saberlo).
        h("p", { class: "muted small" }, "Versión de la app"),
        h("p", {}, `Compilación ${(import.meta.env.VITE_COMPILACION as string | undefined) || "local"}`),
        h("div", { style: "height:12px" }),
        // Idioma de la app (los textos ya traducidos; el resto sigue en español).
        h("p", { class: "muted small" }, "Idioma"),
        h("div", { class: "chips", role: "group", "aria-label": "Idioma de la app" },
          ...([["es", "Español"], ["en", "English"]] as const).map(([id, nombre]) => {
            const b = h("button", { class: "chip", type: "button", "aria-pressed": String(idioma() === id) }, nombre);
            b.addEventListener("click", () => { if (idioma() !== id) { ponerIdioma(id); location.reload(); } });
            return b;
          })),
        h("div", { style: "height:16px" }), salir),
      h("section", { class: "sheet" },
        h("div", { class: "sheet-head" }, h("h2", {}, "Tus juegos son tuyos")),
        h("p", { class: "muted small" },
          "Todo lo que fabricas (código, arte y sonido) se hace con modelos de uso comercial. Descarga el proyecto de Godot cuando quieras y publícalo con tu propia cuenta.")),
      h("section", { class: "sheet" },
        h("div", { class: "sheet-head" }, h("h2", {}, "Privacidad")),
        h("p", { class: "muted small" }, "Tus ideas se procesan con Claude (Anthropic) y el arte, la música y las voces en servidores de RunPod. No vendemos tus datos."),
        privacidad, h("div", { style: "height:16px" }), zona)),
  };
}
