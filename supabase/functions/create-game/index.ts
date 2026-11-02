// Función del servidor: encarga un JUEGO COMPLETO a la fábrica.
//
// Flujo: sesión -> valida la idea -> queue_game (límites, presupuesto y cobro en una
// transacción; el trabajo queda en cola) -> responde al momento con el id del trabajo.
// La fábrica (trabajador en GPU/PC) lo toma, va contando el progreso en jobs.progress y al
// terminar deja el proyecto, el APK y las capturas. La app lee su trabajo para mostrarlo.
//
// Petición (POST, con la sesión del usuario en Authorization):  { "idea": "texto" }
// Respuesta 200: { job_id, credits, cost }

import { GENEROS_ETIQUETA, PLANTILLAS } from "../_shared/cambios-datos.ts";
import { adminClient, CORS, reply, sessionUser } from "../_shared/http.ts";
import { despertarFabrica } from "../_shared/fabrica.ts";

const ERRORS: Record<string, { status: number; message: string }> = {
  bad_idea:             { status: 400, message: "Describe tu juego con entre 15 y 600 caracteres." },
  insufficient_credits: { status: 402, message: "No tienes tuercas suficientes para un juego completo." },
  rate_limited:         { status: 429, message: "Vas muy rápido. Espera un momento." },
  daily_limit:          { status: 429, message: "Has llegado al límite de juegos de hoy. Vuelve mañana." },
  budget_exceeded:      { status: 503, message: "La fábrica está a tope ahora mismo. Inténtalo más tarde; no se te ha cobrado nada." },
  kind_disabled:        { status: 503, message: "La fábrica de juegos todavía no está abierta." },
  unknown_user:         { status: 401, message: "Vuelve a iniciar sesión." },
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return reply(405, { error: "method_not_allowed" });

  const user = await sessionUser(req);
  if (!user) return reply(401, { error: "unauthorized", message: "Vuelve a iniciar sesión." });

  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return reply(400, { error: "bad_json" }); }
  const idea = typeof body.idea === "string" ? body.idea.trim() : "";
  if (idea.length < 15 || idea.length > 600) return reply(400, { error: "bad_idea", message: ERRORS.bad_idea.message });
  // Plantilla de exito: «[plantilla:id] idea». Solo ids conocidos (la fabrica la lee y la fija).
  const marca = /^\[plantilla:([a-z0-9_]{2,40})\]/.exec(idea);
  if (marca && !PLANTILLAS.includes(marca[1])) return reply(400, { error: "bad_idea", message: "Esa plantilla no existe." });
  // Gancho original elegido en la app: «[gancho:genero:giros] idea». La fabrica lo vuelve a validar.
  const gancho = /^\[gancho:([a-z]{2,20}):([a-z_,]{0,60})\]/.exec(idea);
  if (gancho && !(gancho[1] in GENEROS_ETIQUETA)) return reply(400, { error: "bad_idea", message: "Ese tipo de juego no existe." });

  const { data, error } = await adminClient().rpc("queue_game", { p_user: user.id, p_idea: idea });
  if (error) {
    const code = Object.keys(ERRORS).find((k) => error.message.includes(k));
    if (code) return reply(ERRORS[code].status, { error: code, message: ERRORS[code].message });
    console.error("queue_game", error.message);
    return reply(500, { error: "queue_failed", message: "No se pudo encargar el juego." });
  }
  const row = Array.isArray(data) ? data[0] : data;
  await despertarFabrica("juego");
  return reply(200, { job_id: row.job_id, credits: row.credits_left, cost: row.cost });
});
