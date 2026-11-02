// Reseñas de Google Play de un juego del autor (con su sesión).
// Petición (POST): { project_id, accion: "listar" | "borrador" | "responder", review_id?, texto? }
//   listar    -> { resenas: Resena[] }   (Google solo da las de los últimos 7 días con texto)
//   borrador  -> { texto }               (la IA propone; NO se envía nada)
//   responder -> { ok: true }            (el autor envía su texto, ya revisado, a Google)
// Usa la cuenta de servicio ORQ_PLAY_CUENTA, que el autor invitó a su Play Console con el permiso
// «Responder a reseñas». La clave de la IA y la de Google solo viven aquí.

import { adminClient, CORS, reply, sessionUser } from "../_shared/http.ts";
import { tokenGoogle, type CuentaServicio } from "../_shared/google.ts";
import { askModel, llmConfigured } from "../_shared/llm.ts";
import {
  idValido, limpiarBorrador, listarEnGoogle, responderEnGoogle, sistemaBorrador, urlResenas, usuarioBorrador, validarRespuesta,
} from "../_shared/resenas.ts";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS });
  if (req.method !== "POST") return reply(405, { error: "method_not_allowed" });
  const user = await sessionUser(req);
  if (!user) return reply(401, { error: "unauthorized" });
  let b: Record<string, unknown>;
  try { b = await req.json(); } catch { return reply(400, { error: "bad_json" }); }
  const proyecto = String(b.project_id ?? "");
  const accion = String(b.accion ?? "");
  if (!UUID.test(proyecto) || !["listar", "borrador", "responder"].includes(accion)) return reply(400, { error: "bad_request" });

  const admin = adminClient();
  const { data: p } = await admin.from("projects").select("play").eq("id", proyecto).eq("user_id", user.id).maybeSingle();
  if (!p) return reply(404, { error: "project_not_found" });
  const paquete = String((p.play as Record<string, unknown> | null)?.paquete ?? "");
  if (!paquete) return reply(409, { error: "not_published", message: "Publica el juego en Google Play para ver sus reseñas." });
  const cuentaJson = Deno.env.get("ORQ_PLAY_CUENTA") ?? "";
  if (!cuentaJson) return reply(503, { error: "store_not_configured" });

  try {
    const base = urlResenas(Deno.env.get("ORQ_GOOGLE_API") ?? "https://androidpublisher.googleapis.com", paquete);
    const token = await tokenGoogle(JSON.parse(cuentaJson) as CuentaServicio, "https://www.googleapis.com/auth/androidpublisher");
    if (accion === "listar") {
      const r = await listarEnGoogle(fetch, base, token);
      if (!r.ok) return reply(r.status === 403 ? 403 : 502, { error: r.status === 403 ? "no_permission" : "google_unavailable",
        message: r.status === 403 ? "Falta el permiso «Responder a reseñas» para la cuenta de Orquestador en tu Play Console." : undefined });
      return reply(200, { resenas: r.resenas });
    }
    if (!idValido(b.review_id)) return reply(400, { error: "bad_review" });

    if (accion === "borrador") {
      if (!llmConfigured()) return reply(503, { error: "ai_unavailable" });
      const lista = await listarEnGoogle(fetch, base, token);
      const resena = lista.resenas.find((x) => x.id === b.review_id);
      if (!resena) return reply(404, { error: "review_not_found" });
      const { data: cupo, error } = await admin.rpc("resena_borrador_reservar", { p_user: user.id, p_project: proyecto });
      if (error) {
        return reply(error.message.includes("rate_limited") ? 429 : 404,
          { error: error.message.includes("rate_limited") ? "rate_limited" : "project_not_found",
            message: error.message.includes("rate_limited") ? "Has pedido muchas respuestas hoy. Escríbela tú o sigue mañana." : undefined });
      }
      const r = await askModel(sistemaBorrador(String(cupo?.titulo ?? "")), usuarioBorrador(resena), 300);
      await admin.rpc("resena_borrador_coste", { p_id: cupo?.id, p_coste: r.costUsd });
      const texto = limpiarBorrador(r.text);
      if (!texto) return reply(502, { error: "ai_empty" });
      return reply(200, { texto });
    }

    // responder: lo que el autor ha visto y aprobado.
    const texto = validarRespuesta(b.texto);
    if (typeof texto !== "string") return reply(400, { error: texto.error, message: "La respuesta tiene que tener entre 1 y 350 caracteres." });
    const r = await responderEnGoogle(fetch, base, token, b.review_id, texto);
    if (!r.ok) return reply(r.status === 403 ? 403 : 502, { error: r.status === 403 ? "no_permission" : "google_unavailable" });
    await admin.rpc("resena_anotar", { p_user: user.id, p_project: proyecto, p_review: b.review_id, p_texto: texto });
    return reply(200, { ok: true });
  } catch (e) {
    console.error("play-resenas", String(e));
    return reply(502, { error: "google_unavailable" });
  }
});
