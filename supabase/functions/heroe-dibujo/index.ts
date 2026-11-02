// Revisa la imagen que el autor ha subido para usarla como protagonista de su juego.
// Peticion (POST, con sesion): { project_id }. La imagen ya esta en referencias/<user>/<project>/heroe.png.
// Respuesta: { ok: true, descripcion } o { ok: false, motivo }. Si se aprueba, el taller acepta
// el cambio 'redibujar' con referencia (plan-change lo comprueba aqui, en la tabla referencias).

import { adminClient, CORS, reply, sessionUser } from "../_shared/http.ts";
import { askModelImage, llmConfigured } from "../_shared/llm.ts";
import { decidir, MAX_BYTES, rutaReferencia, SISTEMA_REVISION, tipoImagen } from "../_shared/referencias.ts";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS });
  if (req.method !== "POST") return reply(405, { error: "method_not_allowed" });
  const user = await sessionUser(req);
  if (!user) return reply(401, { error: "unauthorized" });
  let b: Record<string, unknown>;
  try { b = await req.json(); } catch { return reply(400, { error: "bad_json" }); }
  const proyecto = String(b.project_id ?? "");
  if (!UUID.test(proyecto)) return reply(400, { error: "bad_request" });
  if (!llmConfigured()) return reply(503, { error: "ai_unavailable" });
  const admin = adminClient();
  const { error: e1 } = await admin.rpc("referencia_reservar", { p_user: user.id, p_project: proyecto });
  if (e1) {
    const limite = e1.message.includes("rate_limited");
    return reply(limite ? 429 : 404, { error: limite ? "rate_limited" : "project_not_found",
      message: limite ? "Has probado muchas imágenes hoy. Sigue mañana." : "Ese juego no existe." });
  }
  const { data: blob, error: e2 } = await admin.storage.from("referencias").download(rutaReferencia(user.id, proyecto));
  if (e2 || !blob) return reply(404, { error: "no_image", message: "No encuentro la imagen. Súbela otra vez." });
  const bytes = new Uint8Array(await blob.arrayBuffer());
  const tipo = tipoImagen(bytes);
  if (!tipo || bytes.length > MAX_BYTES) {
    await admin.rpc("referencia_resultado", { p_project: proyecto, p_ok: false, p_descripcion: "", p_motivo: "formato", p_coste: 0 });
    return reply(200, { ok: false, motivo: "Usa una imagen PNG, JPG o WEBP de menos de 4 MB." });
  }
  try {
    const r = await askModelImage(SISTEMA_REVISION, "Revisa esta imagen.", bytes, tipo, 300);
    const d = decidir(r.text);
    await admin.rpc("referencia_resultado", { p_project: proyecto, p_ok: d.ok, p_descripcion: d.descripcion, p_motivo: d.motivo, p_coste: r.costUsd });
    return reply(200, d.ok ? { ok: true, descripcion: d.descripcion } : { ok: false, motivo: d.motivo });
  } catch (e) {
    console.error("heroe-dibujo", String(e));
    await admin.rpc("referencia_resultado", { p_project: proyecto, p_ok: false, p_descripcion: "", p_motivo: "error", p_coste: 0 });
    return reply(502, { error: "ai_failed", message: "No se pudo revisar la imagen. Prueba en un rato." });
  }
});
