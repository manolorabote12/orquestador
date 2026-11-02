// Paquete para itch.io: un .zip con el juego para jugar en el navegador (HTML5), listo para subir.
// Peticion (POST, con sesion): { project_id }   Respuesta: { url, nombre, mb }
// Usa el motor web comun (bucket 'motor') y el index.pck de la ultima version del juego.

import { adminClient, CORS, reply, sessionUser } from "../_shared/http.ts";
import { MOTOR, paqueteItch } from "../_shared/itch.ts";

const VERSION_MOTOR = Deno.env.get("ORQ_MOTOR") ?? "godot/4.6.3";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS });
  if (req.method !== "POST") return reply(405, { error: "method_not_allowed" });
  const user = await sessionUser(req);
  if (!user) return reply(401, { error: "unauthorized", message: "Vuelve a iniciar sesión." });
  let b: Record<string, unknown>;
  try { b = await req.json(); } catch { return reply(400, { error: "bad_json" }); }
  const id = typeof b.project_id === "string" && /^[0-9a-f-]{36}$/i.test(b.project_id) ? b.project_id : "";
  if (!id) return reply(400, { error: "bad_project" });
  const admin = adminClient();
  const { data: p } = await admin.from("projects").select("id,title,version,files").eq("id", id).eq("user_id", user.id).maybeSingle();
  if (!p) return reply(404, { error: "project_not_found", message: "Ese juego no existe." });
  const web = (p.files ?? {}).web;
  if (typeof web !== "string" || !web) {
    return reply(409, { error: "no_web_build", message: "Este juego aún no tiene versión para el navegador. Haz cualquier cambio en el taller y vuelve a intentarlo." });
  }
  try {
    const bajar = async (bucket: string, ruta: string) => {
      const { data, error } = await admin.storage.from(bucket).download(ruta);
      if (error || !data) throw new Error(`download ${bucket}/${ruta}`);
      return new Uint8Array(await data.arrayBuffer());
    };
    const motor: Record<string, Uint8Array> = {};
    for (const n of MOTOR) {
      try { motor[n] = await bajar("motor", `${VERSION_MOTOR}/${n}`); } catch { /* los worklets son opcionales */ }
    }
    const zip = paqueteItch(String(p.title ?? "Juego"), motor, await bajar("juegos", web));
    const nombre = `${String(p.title ?? "juego").normalize("NFD").replace(/[^\w]+/g, "-").replace(/^-|-$/g, "").toLowerCase() || "juego"}-v${p.version}-html5.zip`;
    const ruta = `${user.id}/itch/${id}/${nombre}`;
    const { error: e1 } = await admin.storage.from("juegos").upload(ruta, zip, { contentType: "application/zip", upsert: true });
    if (e1) throw new Error(e1.message);
    const { data: firmado, error: e2 } = await admin.storage.from("juegos").createSignedUrl(ruta, 86400, { download: nombre });
    if (e2 || !firmado) throw new Error("sign");
    return reply(200, { url: firmado.signedUrl, nombre, mb: Math.round(zip.length / 1e5) / 10 });
  } catch (e) {
    const m = e instanceof Error ? e.message : String(e);
    if (m.includes("no_engine")) return reply(503, { error: "no_engine", message: "Falta subir el motor web (fabrica/subir_motor.py)." });
    console.error("paquete-itch", m);
    return reply(500, { error: "failed", message: "No se pudo preparar el paquete. Inténtalo más tarde." });
  }
});
