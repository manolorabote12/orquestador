const MOTOR = ["index.js", "index.wasm", "index.audio.worklet.js", "index.audio.position.worklet.js"];
function escapar(t) {
  return t.replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]);
}
function htmlItch(titulo) {
  const t = escapar(titulo.slice(0, 60) || "Juego");
  return `<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,user-scalable=no,viewport-fit=cover">
<title>${t}</title>
<style>
html,body{margin:0;height:100%;background:#0b0f1a;overflow:hidden;touch-action:none}
#canvas{position:fixed;inset:0;width:100%;height:100%;outline:none}
#estado{position:fixed;left:0;right:0;bottom:24px;color:#e8f0fa;font:16px system-ui,sans-serif;text-align:center}
</style>
</head>
<body>
<canvas id="canvas" tabindex="0"></canvas>
<p id="estado">Cargando ${t}...</p>
<script src="index.js"><\/script>
<script>
(function () {
  var estado = document.getElementById("estado");
  if (typeof Engine === "undefined" || !Engine.isWebGLAvailable(2)) { estado.textContent = "Tu navegador no puede mostrar este juego (falta WebGL 2)."; return; }
  new Engine({ executable: "index", mainPack: "index.pck", canvasResizePolicy: 2, args: [], ensureCrossOriginIsolationHeaders: false, focusCanvas: true })
    .startGame({ onProgress: function (a, t) { if (t > 0) estado.textContent = "Cargando " + Math.round(100 * a / t) + " %"; } })
    .then(function () { estado.remove(); })
    .catch(function (e) { estado.textContent = String(e && e.message || e); });
})();
<\/script>
</body>
</html>
`;
}
let TABLA = null;
function crc32(d) {
  if (!TABLA) {
    TABLA = new Uint32Array(256);
    for (let n = 0; n < 256; n++) {
      let c2 = n;
      for (let k = 0; k < 8; k++) c2 = c2 & 1 ? 3988292384 ^ c2 >>> 1 : c2 >>> 1;
      TABLA[n] = c2 >>> 0;
    }
  }
  let c = 4294967295;
  for (let i = 0; i < d.length; i++) c = TABLA[(c ^ d[i]) & 255] ^ c >>> 8;
  return (c ^ 4294967295) >>> 0;
}
function zipStore(archivos) {
  const enc = new TextEncoder();
  const locales = [];
  const central = [];
  let off = 0;
  for (const a of archivos) {
    const nombre = enc.encode(a.nombre);
    const crc = crc32(a.datos);
    const h = new DataView(new ArrayBuffer(30));
    h.setUint32(0, 67324752, true);
    h.setUint16(4, 20, true);
    h.setUint16(6, 2048, true);
    h.setUint16(8, 0, true);
    h.setUint16(10, 0, true);
    h.setUint16(12, 33, true);
    h.setUint32(14, crc, true);
    h.setUint32(18, a.datos.length, true);
    h.setUint32(22, a.datos.length, true);
    h.setUint16(26, nombre.length, true);
    h.setUint16(28, 0, true);
    locales.push(new Uint8Array(h.buffer), nombre, a.datos);
    const c = new DataView(new ArrayBuffer(46));
    c.setUint32(0, 33639248, true);
    c.setUint16(4, 20, true);
    c.setUint16(6, 20, true);
    c.setUint16(8, 2048, true);
    c.setUint16(10, 0, true);
    c.setUint16(12, 0, true);
    c.setUint16(14, 33, true);
    c.setUint32(16, crc, true);
    c.setUint32(20, a.datos.length, true);
    c.setUint32(24, a.datos.length, true);
    c.setUint16(28, nombre.length, true);
    c.setUint32(42, off, true);
    central.push(new Uint8Array(c.buffer), nombre);
    off += 30 + nombre.length + a.datos.length;
  }
  const tamCentral = central.reduce((s, x) => s + x.length, 0);
  const fin = new DataView(new ArrayBuffer(22));
  fin.setUint32(0, 101010256, true);
  fin.setUint16(8, archivos.length, true);
  fin.setUint16(10, archivos.length, true);
  fin.setUint32(12, tamCentral, true);
  fin.setUint32(16, off, true);
  const partes = [...locales, ...central, new Uint8Array(fin.buffer)];
  const out = new Uint8Array(partes.reduce((s, x) => s + x.length, 0));
  let p = 0;
  for (const x of partes) {
    out.set(x, p);
    p += x.length;
  }
  return out;
}
function paqueteItch(titulo, motor, pck) {
  for (const n of MOTOR.slice(0, 2)) if (!motor[n]) throw new Error("no_engine");
  const archivos = [{ nombre: "index.html", datos: new TextEncoder().encode(htmlItch(titulo)) }];
  for (const n of MOTOR) if (motor[n]) archivos.push({ nombre: n, datos: motor[n] });
  archivos.push({ nombre: "index.pck", datos: pck });
  return zipStore(archivos);
}
export {
  MOTOR,
  crc32,
  htmlItch,
  paqueteItch,
  zipStore
};
