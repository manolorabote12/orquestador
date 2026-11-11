// Tipografias de la marca dentro de la app (sin depender de internet ni de Google Fonts).
import "@fontsource/big-shoulders-stencil-display/latin-700";
import "@fontsource/big-shoulders-stencil-display/latin-800";
import "@fontsource/atkinson-hyperlegible/latin-400";
import "@fontsource/atkinson-hyperlegible/latin-700";
import "@fontsource/ibm-plex-mono/latin-400";
import "@fontsource/ibm-plex-mono/latin-500";
// Orquestador: la app. Taller (fabricar), Mis juegos, Lanzadera (probadores), Tuercas y Cuenta.

import "./styles.css";
import { crearBackend, type Backend } from "./api";
import { ICONOS, aviso, bloqueError, h, svg, type VistaHecha } from "./ui";
import { vistaEntrar } from "./vistas/entrar";
import { activarVibracion, engancharAtras, recordarVista, ultimaVista, vigilarConexion } from "./comodidad";
import { mensajeError, vigilarErrores } from "./errores";
import { iniciarIdioma } from "./idioma";
import { activarSonido, sonar } from "./sonido";

export type Vista = "taller" | "juegos" | "lanzadera" | "tuercas" | "cuenta";

type HacerVista = (app: App, detalle?: string) => VistaHecha;

// Cada pestana se carga la primera vez que se abre (el arranque solo lleva lo imprescindible);
// las demas se adelantan en segundo plano cuando la app ya esta pintada.
const CARGAR: Record<Vista, () => Promise<HacerVista>> = {
  taller: () => import("./vistas/taller").then((m) => m.vistaTaller),
  juegos: () => import("./vistas/juegos").then((m) => m.vistaJuegos),
  lanzadera: () => import("./vistas/lanzadera").then((m) => m.vistaLanzadera),
  tuercas: () => import("./vistas/tuercas").then((m) => m.vistaTuercas),
  cuenta: () => import("./vistas/cuenta").then((m) => m.vistaCuenta),
};
const cargadas = new Map<Vista, Promise<HacerVista>>();

function cargarVista(v: Vista): Promise<HacerVista> {
  let p = cargadas.get(v);
  if (!p) {
    p = CARGAR[v]();
    cargadas.set(v, p);
    // Si falla (p. ej. sin red en la web), la proxima vez se vuelve a intentar.
    p.catch(() => cargadas.delete(v));
  }
  return p;
}

export interface App {
  api: Backend;
  precio: number;
  tuercas: number;
  ponerTuercas(n: number): void;
  refrescarTuercas(): Promise<void>;
  ir(vista: Vista, detalle?: string): void;
  entrar(): Promise<void>;
  salir(): Promise<void>;
}

const PESTANAS: [Vista, string, string][] = [
  ["taller", "Taller", ICONOS.taller],
  ["juegos", "Mis juegos", ICONOS.juegos],
  ["lanzadera", "Lanzadera", ICONOS.cohete],
  ["tuercas", "Tuercas", ICONOS.monedero],
  ["cuenta", "Cuenta", ICONOS.cuenta],
];

// Enlace de invitación (?invita=CODIGO): se guarda y se usa al entrar (una vez).
const CLAVE_INVITA = "orq-invita";
try {
  const c = new URLSearchParams(location.search).get("invita");
  if (c && /^[A-Za-z2-9]{7}$/.test(c)) localStorage.setItem(CLAVE_INVITA, c.toUpperCase());
} catch { /* sin almacenamiento: se puede escribir a mano en Tuercas */ }

// «Haz tu versión» desde la web de un juego (?remix=<id>): se guarda y, al entrar, el juego se copia
// a Mis juegos para cambiarlo en el taller.
const CLAVE_REMIX = "orq-remix";
try {
  const r = new URLSearchParams(location.search).get("remix");
  if (r && /^[0-9a-f-]{36}$/i.test(r)) localStorage.setItem(CLAVE_REMIX, r.toLowerCase());
} catch { /* sin almacenamiento: se hace desde el escaparate */ }

async function arrancar(): Promise<void> {
  // Ningun fallo se pierde en silencio: lo no previsto se avisa con un texto claro.
  vigilarErrores((texto) => aviso(texto));
  iniciarIdioma();
  activarSonido();
  const raiz = document.getElementById("app")!;
  const api = await crearBackend();
  const contador = h("span", {}, "–");
  const tuercasEl = h("div", { class: "nuts", "aria-label": "Tuercas disponibles" }, svg(ICONOS.tuerca), contador);
  const contenido = h("main", { id: "contenido" });
  const tabs = h("nav", { class: "tabbar", "aria-label": "Principal" });
  const barra = h("header", { class: "topbar" },
    h("div", { class: "logo" }, h("b", {}, "ORQUESTADOR"), h("span", {}, "taller de juegos")),
    tuercasEl);
  const banda = api.demo
    ? h("div", { class: "demo-band" }, "Modo demostración: todo simulado, nada se cobra")
    : null;
  const sinRed = h("div", { class: "offline-band", role: "status", hidden: true }, "Sin conexión: revisa tu red para seguir");
  const wrap = h("div", { class: "wrap" }, sinRed, barra, banda, contenido);
  raiz.replaceChildren(wrap, tabs);

  let actual: Vista = ultimaVista(PESTANAS.map((p) => p[0]), "taller");
  let limpiar: (() => void) | null = null;
  /** Cuenta las veces que se cambia de pestana: si llega tarde una pantalla, no pisa a la nueva. */
  let turno = 0;
  /** Pestanas visitadas (para el boton atras de Android). */
  const historia: Vista[] = [];

  let ruedaTuercas = 0;
  /** La primera cifra (al entrar) se pone sin animación ni sonido. */
  let primeraCifra = false;

  const app: App = {
    api,
    precio: 60,
    tuercas: 0,
    ponerTuercas(n: number) {
      const antes = app.tuercas;
      const subio = n > antes;
      app.tuercas = n;
      // El contador rueda hasta la cifra nueva (como un cuentakilómetros) y suena la tuerca.
      window.clearInterval(ruedaTuercas);
      const quieto = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
      if (n === antes || !primeraCifra || quieto) {
        contador.textContent = String(n);
      } else {
        const pasos = Math.min(18, Math.abs(n - antes));
        let i = 0;
        ruedaTuercas = window.setInterval(() => {
          i++;
          contador.textContent = String(Math.round(antes + ((n - antes) * i) / pasos));
          if (i >= pasos) window.clearInterval(ruedaTuercas);
        }, 28);
        sonar(subio ? "moneda" : "gasto");
      }
      primeraCifra = true;
      if (subio) {
        tuercasEl.classList.remove("bump");
        void tuercasEl.offsetWidth;
        tuercasEl.classList.add("bump");
      }
    },
    async refrescarTuercas() {
      try {
        app.ponerTuercas(await api.tuercas());
      } catch {
        /* se reintenta en la próxima acción */
      }
    },
    ir(vista: Vista, detalle?: string) {
      if (vista !== actual && !tabs.hidden) historia.push(actual);
      if (historia.length > 20) historia.shift();
      actual = vista;
      recordarVista(vista);
      limpiar?.();
      limpiar = null;
      for (const b of tabs.querySelectorAll<HTMLButtonElement>(".tab")) {
        b.classList.toggle("on", b.dataset.vista === vista);
        b.setAttribute("aria-current", b.dataset.vista === vista ? "page" : "false");
      }
      const mio = ++turno;
      // "Cargando" solo si tarda (con la pantalla ya cargada no se ve nada).
      const espera = setTimeout(() => {
        if (mio === turno) contenido.replaceChildren(h("p", { class: "muted", role: "status" }, "Cargando..."));
      }, 150);
      cargarVista(vista).then((hacer) => {
        clearTimeout(espera);
        if (mio !== turno) return;
        const v = hacer(app, detalle);
        limpiar = v.limpiar ?? null;
        contenido.replaceChildren(v.el);
        window.scrollTo({ top: 0 });
      }).catch((e: unknown) => {
        clearTimeout(espera);
        if (mio !== turno) return;
        // El navegador recuerda que esa parte de la app no llego y no la vuelve a pedir: para
        // reintentar se recarga (la app vuelve sola a esta pestana).
        contenido.replaceChildren(h("section", { class: "sheet" },
          bloqueError(e, "No se pudo abrir esta pantalla.", () => location.reload())));
      });
    },
    async entrar() {
      tabs.hidden = false;
      tuercasEl.hidden = false;
      app.precio = await api.precioJuego();
      await app.refrescarTuercas();
      app.ir(actual);
      // Las otras pestanas se adelantan cuando la primera ya esta en pantalla.
      setTimeout(() => { for (const [v] of PESTANAS) void cargarVista(v).catch(() => undefined); }, 1200);
      let invita: string | null = null;
      try { invita = localStorage.getItem(CLAVE_INVITA); localStorage.removeItem(CLAVE_INVITA); } catch { /* nada */ }
      if (invita) {
        void api.usarInvitacion(invita).then(() => aviso("Código de invitación apuntado: con tu primera compra, ganáis tuercas los dos"))
          .catch(() => undefined);
      }
      let remix: string | null = null;
      try { remix = localStorage.getItem(CLAVE_REMIX); localStorage.removeItem(CLAVE_REMIX); } catch { /* nada */ }
      if (remix) {
        void api.remix(remix).then((r) => {
          aviso("Ya tienes tu copia en Mis juegos: cámbiala a tu manera en su taller");
          app.ir("juegos", r.project_id);
        }).catch((e) => aviso(mensajeError(e, "No se pudo copiar ese juego. Búscalo en el escaparate.")));
      }
      // Compras pagadas que quedaron a medias (sin red, app cerrada): se cierran solas.
      void api.recuperarCompras().then((n) => {
        if (n > 0) void app.refrescarTuercas();
      }).catch(() => undefined);
    },
    async salir() {
      limpiar?.();
      limpiar = null;
      await api.salir();
      mostrarEntrada();
    },
  };

  for (const [id, nombre, icono] of PESTANAS) {
    const b = h("button", { class: "tab", "data-vista": id, onclick: () => app.ir(id) }, svg(icono), nombre);
    tabs.append(b);
  }

  function mostrarEntrada() {
    tabs.hidden = true;
    tuercasEl.hidden = true;
    contenido.replaceChildren(vistaEntrar(app).el);
  }

  void vigilarConexion(sinRed);
  void activarVibracion();
  void engancharAtras(() => {
    if (tabs.hidden) return false;
    const antes = historia.pop();
    if (antes) {
      app.ir(antes);
      historia.pop();
      return true;
    }
    if (actual !== "taller") {
      app.ir("taller");
      historia.pop();
      return true;
    }
    return false;
  });

  if (await api.usuario()) await app.entrar();
  else mostrarEntrada();
}

void arrancar();
