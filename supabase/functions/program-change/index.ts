// Agente programador: el usuario pide algo que el taller no sabe hacer y Chispa lo programa (mod
// revisado, compilado y jugado por bots). Precio fijo en pricing ('game_mod'): lo cobra el servidor.
// Peticion (POST, con sesion): { project_id, instruccion }   Respuesta: { job_id, credits, cost }

import { adminClient, CORS, reply, sessionUser } from "../_shared/http.ts";
import { despertarFabrica } from "../_shared/fabrica.ts";

const ERRORS: Record<string, { status: number; message: string }> = {
  bad_instruction: { status: 400, message: "Cuéntalo en una frase (entre 8 y 400 caracteres)." },
  project_not_found: { status: 404, message: "Ese juego no existe." },
  project_busy: { status: 409, message: "Ese juego ya se está fabricando. Espera a que termine." },
  insufficient_credits: { status: 402, message: "No tienes tuercas suficientes." },
  daily_limit: { status: 429, message: "Has llegado al límite de cambios programados de hoy." },
  rate_limited: { status: 429, message: "Vas muy rápido. Espera un momento." },
  budget_exceeded: { status: 503, message: "La fábrica está a tope ahora mismo. Inténtalo más tarde." },
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS });
  if (req.method !== "POST") return reply(405, { error: "method_not_allowed" });
  const user = await sessionUser(req);
  if (!user) return reply(401, { error: "unauthorized", message: "Vuelve a iniciar sesión." });
  let b: Record<string, unknown>;
  try { b = await req.json(); } catch { return reply(400, { error: "bad_json" }); }
  const projectId = typeof b.project_id === "string" ? b.project_id : "";
  const instruccion = typeof b.instruccion === "string" ? b.instruccion : "";
  if (!/^[0-9a-f-]{36}$/i.test(projectId)) return reply(400, { error: "bad_project" });
  const { data, error } = await adminClient().rpc("queue_mod", { p_user: user.id, p_project: projectId, p_instruccion: instruccion });
  if (error) {
    const code = Object.keys(ERRORS).find((k) => error.message.includes(k));
    if (code) return reply(ERRORS[code].status, { error: code, message: ERRORS[code].message });
    return reply(500, { error: "queue_failed", message: "No se pudo encargar el cambio." });
  }
  const row = Array.isArray(data) ? data[0] : data;
  await despertarFabrica("mod");
  return reply(200, { job_id: row.job_id, credits: row.credits_left, cost: row.cost });
});
