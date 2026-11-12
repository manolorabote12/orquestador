// Jugar ya: abre el juego dentro de la app, sin instalar nada.
// El motor web de Godot (index.js + index.wasm, ~38 MB) es igual para todos los juegos y se
// sirve público desde el bucket "motor" (el navegador lo guarda en caché). Cada versión de cada
// juego solo trae su paquete index.pck (~1 MB) con una URL firmada.
// Todo va dentro de un iframe: al cerrar se libera el motor entero (memoria, audio, WebGL).

import { h } from "./ui";

export interface OpcionesJugador {
  /** Carpeta pública del motor, p. ej. https://x.supabase.co/storage/v1/object/public/motor/godot/4.6.3 */
  motor: string | null;
  /** URL (firmada) del index.pck de la versión. */
  pck: string | null;
  titulo: string;
  /** Imagen de respaldo para el modo demostración. */
  portada?: string;
  /** Galería: botón «Siguiente» para encadenar partidas sin salir (como en los portales de juegos). */
  siguiente?: () => void;
  /** Al cerrar el reproductor (por ejemplo, para un anuncio entre partidas). */
  alCerrar?: () => void;
}

/** Página del iframe. Las URLs van como JSON escapado: nunca se interpretan como HTML. */
export function paginaJuego(motor: string, pck: string): string {
  const datos = JSON.stringify({ motor: motor.replace(/\/+$/, ""), pck }).replace(/</g, "\\u003c");
  return `<!doctype html><html lang="es"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,user-scalable=no">
<style>
html,body{margin:0;height:100%;background:#0b0f1a;overflow:hidden;touch-action:none}
#canvas{display:block;width:100%;height:100%;outline:none}
#carga{position:fixed;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:14px;color:#e8f0fa;font:600 15px system-ui,sans-serif}
#barra{width:min(260px,70vw);height:10px;border-radius:6px;background:#16233a;overflow:hidden}
#barra i{display:block;height:100%;width:0;background:#e8b04b;transition:width .2s}
#error{color:#ff8a7a;max-width:80vw;text-align:center;display:none}
</style></head><body>
<canvas id="canvas" tabindex="0">Tu dispositivo no puede mostrar el juego.</canvas>
<div id="carga"><span id="txt">Cargando el motor...</span><div id="barra"><i></i></div><span id="error"></span></div>
<script>
(function(){
var D=${datos};
var carga=document.getElementById("carga"),txt=document.getElementById("txt"),barra=document.querySelector("#barra i"),err=document.getElementById("error");
function avisar(m){parent.postMessage({orq:"jugador",estado:m},"*");}
function fallo(m){err.style.display="block";err.textContent=m;txt.textContent="No se pudo abrir";avisar("error");}
var s=document.createElement("script");
s.src=D.motor+"/index.js";
s.onerror=function(){fallo("No se pudo descargar el motor del juego. Revisa tu conexión.");};
s.onload=function(){
  if(typeof Engine==="undefined"){fallo("Motor no valido.");return;}
  if(!Engine.isWebGLAvailable(2)){fallo("Tu dispositivo no tiene WebGL 2.");return;}
  var e=new Engine({executable:D.motor+"/index",mainPack:D.pck,canvasResizePolicy:2,args:[],
    ensureCrossOriginIsolationHeaders:false,focusCanvas:true,experimentalVK:false});
  txt.textContent="Cargando tu juego...";
  e.startGame({onProgress:function(a,t){if(t>0)barra.style.width=Math.round(100*a/t)+"%";}})
   .then(function(){carga.style.display="none";avisar("listo");})
   .catch(function(x){fallo(String(x&&x.message||x));});
};
document.head.appendChild(s);
})();
</script></body></html>`;
}

/** Abre el reproductor a pantalla completa. Devuelve la función para cerrarlo. */
export function abrirJugador(op: OpcionesJugador): () => void {
  const previo = document.activeElement as HTMLElement | null;
  let cerrado = false;
  const cerrar = () => {
    if (cerrado) return;
    cerrado = true;
    window.removeEventListener("message", oir);
    document.removeEventListener("keydown", tecla);
    capa.remove();
    previo?.focus();
    op.alCerrar?.();
  };
  const boton = h("button", { class: "player-close", "aria-label": "Cerrar el juego", onclick: () => cerrar() }, "✕");
  const estado = h("span", { class: "player-state" }, "");
  const sig = op.siguiente
    ? h("button", { class: "player-next", type: "button", onclick: () => { const ir = op.siguiente!; cerrar(); ir(); } }, "Siguiente ▸")
    : null;
  const cabeza = h("div", { class: "player-bar" }, h("strong", {}, op.titulo), estado, sig, boton);
  let cuerpo: HTMLElement;
  if (op.motor && op.pck) {
    const marco = h("iframe", {
      class: "player-frame",
      title: `Jugar a ${op.titulo}`,
      allow: "autoplay; fullscreen; gamepad",
    });
    marco.srcdoc = paginaJuego(op.motor, op.pck);
    marco.addEventListener("load", () => marco.contentWindow?.focus());
    cuerpo = marco;
  } else {
    cuerpo = h("div", { class: "player-demo" },
      op.portada ? h("img", { src: op.portada, alt: "" }) : null,
      h("p", {}, "Aquí se abre tu juego al instante, sin instalar nada."),
      h("p", { class: "muted" }, op.motor
        ? "Esta versión aún no tiene paquete web. El próximo cambio lo creará."
        : "En la demostración no hay motor conectado: con tu servidor se juega de verdad."));
  }
  const capa = h("div", { class: "player", role: "dialog", "aria-modal": "true", "aria-label": `Jugando a ${op.titulo}` }, cabeza, cuerpo);
  function oir(e: MessageEvent) {
    const d = e.data as { orq?: string; estado?: string } | null;
    if (!d || d.orq !== "jugador") return;
    estado.textContent = d.estado === "error" ? "error" : "";
    capa.dataset.estado = d.estado ?? "";
  }
  function tecla(e: KeyboardEvent) {
    if (e.key === "Escape") cerrar();
  }
  window.addEventListener("message", oir);
  document.addEventListener("keydown", tecla);
  document.body.append(capa);
  boton.focus();
  return cerrar;
}

/** Visor del clip vertical para redes: lo reproduce en bucle y deja descargarlo. */
export function abrirClip(url: string, titulo: string, portada?: string): () => void {
  const previo = document.activeElement as HTMLElement | null;
  const cerrar = () => {
    document.removeEventListener("keydown", tecla);
    capa.remove();
    previo?.focus();
  };
  const boton = h("button", { class: "player-close", "aria-label": "Cerrar el clip", onclick: () => cerrar() }, "✕");
  const cabeza = h("div", { class: "player-bar" }, h("strong", {}, `Clip de ${titulo}`), boton);
  const video = h("video", { class: "clip-video", src: url, controls: "", autoplay: "", loop: "", playsinline: "" }) as HTMLVideoElement;
  video.muted = true;
  if (portada) video.poster = portada;
  const nombre = titulo.toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "").replace(/[^a-z0-9]+/g, "_") + "_clip.mp4";
  const pie = h("div", { class: "clip-foot" },
    h("p", { class: "muted small" }, "15 s en vertical 1080×1920. Listo para TikTok, YouTube Shorts e Instagram Reels."),
    h("a", { class: "btn btn-brass", href: url, download: nombre, target: "_blank", rel: "noopener" }, "Descargar el clip"));
  const capa = h("div", { class: "player", role: "dialog", "aria-modal": "true", "aria-label": `Clip de ${titulo}` },
    cabeza, h("div", { class: "clip-stage" }, video), pie);
  function tecla(e: KeyboardEvent) {
    if (e.key === "Escape") cerrar();
  }
  document.addEventListener("keydown", tecla);
  document.body.append(capa);
  boton.focus();
  return cerrar;
}
