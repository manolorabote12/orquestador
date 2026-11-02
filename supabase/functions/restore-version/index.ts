// Función del servidor: vuelve a una versión anterior del juego (gratis, con tope diario).
// Se registra como versión nueva: nunca se pierde nada.
//
// Petición (POST, con sesión): { "project_id": "uuid", "version": 2 }   Respuesta: { job_id }

import { adminClient, CORS, reply, sessionUser } from "../_shared/http.ts";
import { despertarFabrica } from "../_shared/fabrica.ts";

const ERRORS: Record<string, { status: number; message: string }> = {
  project_not_found: { status: 404, message: "Ese juego no existe." },
  version_not_found: { status: 404, message: "Esa versión no existe." },
  project_busy:      { status: 409, message: "Ese juego ya se está fabricando. Espera a que termine." },
  rate_limited:      { status: 429, message: "Vas muy rápido. Espera un momento." },
  daily_limit:       { status: 429, message: "Has llegado al límite de vueltas atrás de hoy." },
  budget_exceeded:   { status: 503, message: "La fábrica está a tope ahora mismo. Inténtalo más tarde." },
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return reply(405, { error: "method_not_allowed" });
  const user = await sessionUser(req);
  if (!user) return reply(401, { error: "unauthorized", message: "Vuelve a iniciar sesión." });
  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return reply(400, { error: "bad_json" }); }
  const projectId = typeof body.project_id === "string" ? body.project_id : "";
  const version = Number(body.version);
  if (!Number.isInteger(version) || version < 1) return reply(400, { error: "bad_version", message: "Versión no válida." });
  const { data, error } = await adminClient().rpc("queue_restore", { p_user: user.id, p_project: projectId, p_version: version });
  if (error) {
    const code = Object.keys(ERRORS).find((k) => error.message.includes(k));
    if (code) return reply(ERRORS[code].status, { error: code, message: ERRORS[code].message });
    console.error("queue_restore", error.message);
    return reply(500, { error: "queue_failed", message: "No se pudo volver a esa versión." });
  }
  const row = Array.isArray(data) ? data[0] : data;
  await despertarFabrica("restaurar");
  return reply(200, { job_id: row.job_id });
});
