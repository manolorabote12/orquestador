const COPIAR = ["proyecto", "web", "apk", "icono", "clip", "ficha", "informe"];
const TIPO = { png: "image/png", jpg: "image/jpeg", jpeg: "image/jpeg", json: "application/json" };
function tipoDe(ruta) {
  return TIPO[ruta.split(".").pop()?.toLowerCase() ?? ""] ?? "application/octet-stream";
}
async function publicar(a, proyecto, autor) {
  const f = proyecto.files;
  if (typeof f.web !== "string" || !f.web) throw new Error("no_web_build");
  await a.subir("escaparate", `${proyecto.id}/index.pck`, await a.bajar("juegos", f.web), "application/octet-stream");
  if (typeof f.icono === "string" && f.icono) await a.subir("escaparate", `${proyecto.id}/icono.png`, await a.bajar("juegos", f.icono), "image/png");
  const capturas = Array.isArray(f.capturas) ? f.capturas.filter((x) => typeof x === "string") : [];
  if (capturas.length) await a.subir("escaparate", `${proyecto.id}/portada.png`, await a.bajar("juegos", capturas[0]), "image/png");
  const ficha = {
    titulo: proyecto.title,
    resumen: String(proyecto.spec.resumen ?? ""),
    genero: String(proyecto.spec.genero ?? ""),
    autor: autor.slice(0, 40),
    version: proyecto.version,
    portada: capturas.length > 0,
    icono: typeof f.icono === "string"
  };
  await a.subir("escaparate", `${proyecto.id}/ficha.json`, new TextEncoder().encode(JSON.stringify(ficha)), "application/json");
}
async function retirar(a, id) {
  await a.borrar("escaparate", ["index.pck", "icono.png", "portada.png", "ficha.json"].map((n) => `${id}/${n}`));
}
async function copiarParaRemix(a, files, usuario, carpeta) {
  const base = `${usuario}/${carpeta}`;
  const nombre = (ruta) => ruta.split("/").slice(3).join("/") || ruta.split("/").pop();
  const out = {};
  const copiar = async (ruta) => {
    if (ruta.includes("..")) throw new Error("bad_path");
    const destino = `${base}/${nombre(ruta)}`;
    await a.subir("juegos", destino, await a.bajar("juegos", ruta), tipoDe(ruta));
    return destino;
  };
  for (const k of COPIAR) if (typeof files[k] === "string" && files[k]) out[k] = await copiar(files[k]);
  if (Array.isArray(files.capturas)) {
    out.capturas = [];
    for (const c of files.capturas) if (typeof c === "string") out.capturas.push(await copiar(c));
  }
  if (typeof files.version === "number") out.version = files.version;
  if (!out.proyecto) throw new Error("no_project");
  return out;
}
export {
  copiarParaRemix,
  publicar,
  retirar,
  tipoDe
};
