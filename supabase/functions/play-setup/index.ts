// Función del servidor: guarda los datos de publicación del usuario (nombre de estudio y correo
// de contacto). El estudio va en el nombre de paquete de sus juegos: com.<estudio>.<juego>.
//
// Petición (POST, con sesión): { "estudio": "Daniel Studio", "correo": "tu@correo.com" }
// Respuesta: { ok: true, cuenta_servicio: "...@...iam.gserviceaccount.com" }

import { adminClient, CORS, reply, sessionUser } from "../_shared/http.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return reply(405, { error: "method_not_allowed" });
  const user = await sessionUser(req);
  if (!user) return reply(401, { error: "unauthorized", message: "Vuelve a iniciar sesión." });
  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return reply(400, { error: "bad_json" }); }
  const estudio = typeof body.estudio === "string" ? body.estudio.trim() : "";
  const correo = typeof body.correo === "string" ? body.correo.trim() : "";
  if (estudio.length < 2 || estudio.length > 40 || !/[a-zA-Z]/.test(estudio)) {
    return reply(400, { error: "bad_studio", message: "El nombre de estudio tiene que tener entre 2 y 40 caracteres y alguna letra." });
  }
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(correo) || correo.length > 120) {
    return reply(400, { error: "bad_email", message: "Ese correo no parece válido." });
  }
  const { error } = await adminClient().rpc("save_play_account", { p_user: user.id, p_estudio: estudio, p_correo: correo });
  if (error) {
    console.error("save_play_account", error.message);
    return reply(500, { error: "save_failed", message: "No se pudieron guardar tus datos." });
  }
  return reply(200, { ok: true, cuenta_servicio: Deno.env.get("ORQ_PLAY_CUENTA_CORREO") ?? "" });
});
