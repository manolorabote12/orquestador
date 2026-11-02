// Logica del Escaparate sin dependencias de Deno (se prueba con Node: pruebas/escaparate.mjs).

/** Lo minimo del almacen que hace falta (supabase-js lo cumple con un adaptador). */
export interface Almacen {
  bajar(bucket: string, ruta: string): Promise<Uint8Array>;
  subir(bucket: string, ruta: string, datos: Uint8Array, tipo: string): Promise<void>;
  borrar(bucket: string, rutas: string[]): Promise<void>;
}

/** Archivos de una version que se copian al hacer remix (lo de publicar en tiendas, no). */
const COPIAR = ["proyecto", "web", "apk", "icono", "clip", "ficha", "informe"] as const;

const TIPO: Record<string, string> = { png: "image/png", jpg: "image/jpeg", jpeg: "image/jpeg", json: "application/json" };
export function tipoDe(ruta: string): string {
  return TIPO[ruta.split(".").pop()?.toLowerCase() ?? ""] ?? "application/octet-stream";
}

/** 1 - Publicar: paquete web, icono, portada y ficha al almacen publico 'escaparate/<id>/'. */
export async function publicar(a: Almacen, proyecto: { id: string; title: string; spec: Record<string, unknown>; version: number;
  files: Record<string, unknown> }, autor: string): Promise<void> {
  const f = proyecto.files;
  if (typeof f.web !== "string" || !f.web) throw new Error("no_web_build");
  await a.subir("escaparate", `${proyecto.id}/index.pck`, await a.bajar("juegos", f.web), "application/octet-stream");
  if (typeof f.icono === "string" && f.icono) await a.subir("escaparate", `${proyecto.id}/icono.png`, await a.bajar("juegos", f.icono), "image/png");
  const capturas = Array.isArray(f.capturas) ? f.capturas.filter((x): x is string => typeof x === "string") : [];
  if (capturas.length) await a.subir("escaparate", `${proyecto.id}/portada.png`, await a.bajar("juegos", capturas[0]), "image/png");
  const ficha = { titulo: proyecto.title, resumen: String(proyecto.spec.resumen ?? ""), genero: String(proyecto.spec.genero ?? ""),
    autor: autor.slice(0, 40), version: proyecto.version, portada: capturas.length > 0, icono: typeof f.icono === "string" };
  await a.subir("escaparate", `${proyecto.id}/ficha.json`, new TextEncoder().encode(JSON.stringify(ficha)), "application/json");
}

export async function retirar(a: Almacen, id: string): Promise<void> {
  await a.borrar("escaparate", ["index.pck", "icono.png", "portada.png", "ficha.json"].map((n) => `${id}/${n}`));
}

/** 2 - Remix: copia los archivos del original a la carpeta del usuario. Devuelve el nuevo "files". */
export async function copiarParaRemix(a: Almacen, files: Record<string, unknown>, usuario: string, carpeta: string): Promise<Record<string, unknown>> {
  const base = `${usuario}/${carpeta}`;
  const nombre = (ruta: string) => ruta.split("/").slice(3).join("/") || ruta.split("/").pop()!;
  const out: Record<string, unknown> = {};
  const copiar = async (ruta: string) => {
    if (ruta.includes("..")) throw new Error("bad_path");
    const destino = `${base}/${nombre(ruta)}`;
    await a.subir("juegos", destino, await a.bajar("juegos", ruta), tipoDe(ruta));
    return destino;
  };
  for (const k of COPIAR) if (typeof files[k] === "string" && files[k]) out[k] = await copiar(files[k] as string);
  if (Array.isArray(files.capturas)) {
    out.capturas = [];
    for (const c of files.capturas) if (typeof c === "string") (out.capturas as string[]).push(await copiar(c));
  }
  if (typeof files.version === "number") out.version = files.version;
  if (!out.proyecto) throw new Error("no_project");
  return out;
}
