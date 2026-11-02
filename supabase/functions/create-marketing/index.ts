// Función del servidor: encarga los vídeos para redes de un juego (3 clips con guion, subtítulos
// y voz en off hechos por IA). Precio fijo en la tabla pricing ('game_marketing'): lo cobra el
// servidor, nunca la app ni la IA.
//
// Petición (POST, con sesión): { "project_id": "uuid" }   Respuesta: { job_id, credits, cost }

import { adminClient, CORS, reply, sessionUser } from "../_shared/http.ts";
import { despertarFabrica } from "../_shared/fabrica.ts";

const ERRORS: Record<string, { status: number; message: string }> = {
  project_not_found:    { status: 404, message: "Ese juego no existe." },
  project_busy:         { status: 409, message: "Ese juego ya se está fabricando. Espera a que termine." },
  insufficient_credits: { status: 402, message: "No tienes tuercas suficientes." },
  rate_limited:         { status: 429, message: "Vas muy rápido. Espera un momento." },
  daily_limit:          { status: 429, message: "Has llegado al límite de vídeos de hoy." },
  kind_disabled:        { status: 503, message: "Los vídeos para redes no están disponibles ahora mismo." },
  budget_exceeded:      { status: 503, message: "La fábrica está a tope ahora mismo. Inténtalo más tarde." },
  youtube_not_connected: { status: 409, message: "Antes conecta tu canal de YouTube." },
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return reply(405, { error: "method_not_allowed" });
  const user = await sessionUser(req);
  if (!user) return reply(401, { error: "unauthorized", message: "Vuelve a iniciar sesión." });
  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return reply(400, { error: "bad_json" }); }
  const projectId = typeof body.project_id === "string" ? body.project_id : "";
  if (!/^[0-9a-f-]{36}$/i.test(projectId)) return reply(400, { error: "bad_project", message: "Juego no válido." });
  const youtube = typeof body.youtube === "string" ? body.youtube : "no";
  if (!["no", "oculto", "publico"].includes(youtube)) return reply(400, { error: "bad_youtube" });
  const { data, error } = await adminClient().rpc("queue_marketing", { p_user: user.id, p_project: projectId, p_youtube: youtube });
  if (error) {
    const code = Object.keys(ERRORS).find((k) => error.message.includes(k));
    if (code) return reply(ERRORS[code].status, { error: code, message: ERRORS[code].message });
    console.error("queue_marketing", error.message);
    return reply(500, { error: "queue_failed", message: "No se pudieron encargar los vídeos." });
  }
  const row = Array.isArray(data) ? data[0] : data;
  await despertarFabrica("marketing");
  return reply(200, { job_id: row.job_id, credits: row.credits_left, cost: row.cost });
});
