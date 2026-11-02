// Función del servidor: publica un juego en Google Play (gratis, con tope diario).
//
// Petición (POST, con sesión): { "project_id": "uuid", "modo": "primer_aab" | "subir", "pista": "internal" | "alpha" | "beta" | "production" }
//   primer_aab: el trabajador prepara el .aab firmado, la ficha, la política de privacidad y la guía.
//   subir:      el trabajador lo sube por la API de Google con la cuenta de servicio de Orquestador.
// Respuesta: { job_id }

import { adminClient, CORS, reply, sessionUser } from "../_shared/http.ts";
import { despertarFabrica } from "../_shared/fabrica.ts";

const ERRORS: Record<string, { status: number; message: string }> = {
  play_setup_missing: { status: 409, message: "Antes pon tu nombre de estudio y tu correo de contacto." },
  first_aab_missing:  { status: 409, message: "Primero prepara la primera versión y súbela a mano a Play Console." },
  project_not_found:  { status: 404, message: "Ese juego no existe." },
  project_busy:       { status: 409, message: "Ese juego ya se está fabricando. Espera a que termine." },
  bad_mode:           { status: 400, message: "Modo no válido." },
  bad_track:          { status: 400, message: "Pista no válida." },
  rate_limited:       { status: 429, message: "Vas muy rápido. Espera un momento." },
  daily_limit:        { status: 429, message: "Has llegado al límite de publicaciones de hoy." },
  kind_disabled:      { status: 503, message: "La publicación no está disponible ahora mismo." },
  budget_exceeded:    { status: 503, message: "La fábrica está a tope ahora mismo. Inténtalo más tarde." },
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return reply(405, { error: "method_not_allowed" });
  const user = await sessionUser(req);
  if (!user) return reply(401, { error: "unauthorized", message: "Vuelve a iniciar sesión." });
  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return reply(400, { error: "bad_json" }); }
  const projectId = typeof body.project_id === "string" ? body.project_id : "";
  const modo = body.modo === "subir" ? "subir" : "primer_aab";
  const pista = typeof body.pista === "string" ? body.pista : "alpha";
  if (!/^[0-9a-f-]{36}$/i.test(projectId)) return reply(400, { error: "bad_project", message: "Juego no válido." });
  const { data, error } = await adminClient().rpc("queue_publish", { p_user: user.id, p_project: projectId, p_modo: modo, p_pista: pista });
  if (error) {
    const code = Object.keys(ERRORS).find((k) => error.message.includes(k));
    if (code) return reply(ERRORS[code].status, { error: code, message: ERRORS[code].message });
    console.error("queue_publish", error.message);
    return reply(500, { error: "queue_failed", message: "No se pudo preparar la publicación." });
  }
  const row = Array.isArray(data) ? data[0] : data;
  await despertarFabrica("publicar");
  return reply(200, { job_id: row.job_id });
});
