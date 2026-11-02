// Función del servidor: aplica un plan aprobado. Cobra exactamente el coste guardado con el plan
// y deja el cambio en la cola de la fábrica.
//
// Petición (POST, con sesión): { "plan_id": "uuid" }      Respuesta: { job_id, credits, cost }

import { adminClient, CORS, reply, sessionUser } from "../_shared/http.ts";
import { despertarFabrica } from "../_shared/fabrica.ts";

const ERRORS: Record<string, { status: number; message: string }> = {
  plan_not_found:       { status: 404, message: "Ese cambio ya no existe. Pídeselo otra vez a Chispa." },
  plan_used:            { status: 409, message: "Ese cambio ya se aplicó." },
  plan_expired:         { status: 410, message: "La propuesta ha caducado. Pídeselo otra vez a Chispa." },
  plan_empty:           { status: 400, message: "Esa propuesta no cambia nada." },
  project_busy:         { status: 409, message: "Ese juego ya se está fabricando. Espera a que termine." },
  insufficient_credits: { status: 402, message: "No tienes tuercas suficientes para este cambio." },
  rate_limited:         { status: 429, message: "Vas muy rápido. Espera un momento." },
  daily_limit:          { status: 429, message: "Has llegado al límite de cambios de hoy." },
  budget_exceeded:      { status: 503, message: "La fábrica está a tope ahora mismo. Inténtalo más tarde; no se te ha cobrado nada." },
  kind_disabled:        { status: 503, message: "El taller de cambios no está abierto todavía." },
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return reply(405, { error: "method_not_allowed" });
  const user = await sessionUser(req);
  if (!user) return reply(401, { error: "unauthorized", message: "Vuelve a iniciar sesión." });
  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return reply(400, { error: "bad_json" }); }
  const planId = typeof body.plan_id === "string" ? body.plan_id : "";
  const { data, error } = await adminClient().rpc("queue_change", { p_user: user.id, p_plan: planId });
  if (error) {
    const code = Object.keys(ERRORS).find((k) => error.message.includes(k));
    if (code) return reply(ERRORS[code].status, { error: code, message: ERRORS[code].message });
    console.error("queue_change", error.message);
    return reply(500, { error: "queue_failed", message: "No se pudo aplicar el cambio." });
  }
  const row = Array.isArray(data) ? data[0] : data;
  await despertarFabrica("cambio");
  return reply(200, { job_id: row.job_id, credits: row.credits_left, cost: row.cost });
});
