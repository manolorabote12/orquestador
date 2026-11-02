// Ganchos originales: 3 propuestas de juego (genero + giros + idea) para la idea del usuario.
// Peticion (POST, con sesion): { idea }. Respuesta: { ganchos: [{titulo, genero, giros, idea, por_que, marca}] }
// No cobra tuercas (cupo diario). Solo propone generos y giros que la fabrica sabe hacer y que no
// fallan (giros_estadisticas: lo aprendido por la fabrica).

import { adminClient, CORS, reply, sessionUser } from "../_shared/http.ts";
import { askModel, llmConfigured } from "../_shared/llm.ts";
import { type Fiabilidad, marca, respaldo, sistema, validar } from "../_shared/ganchos.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS });
  if (req.method !== "POST") return reply(405, { error: "method_not_allowed" });
  const user = await sessionUser(req);
  if (!user) return reply(401, { error: "unauthorized" });
  let b: Record<string, unknown>;
  try { b = await req.json(); } catch { return reply(400, { error: "bad_json" }); }
  const idea = typeof b.idea === "string" ? b.idea.trim() : "";
  if (idea.length < 3 || idea.length > 300) return reply(400, { error: "bad_idea", message: "Cuéntame tu idea en pocas palabras (hasta 300 letras)." });
  const admin = adminClient();
  const { data: est } = await admin.rpc("giros_estadisticas");
  const fiab = ((est?.stats ?? []) as Fiabilidad[]);
  if (!llmConfigured()) return reply(200, { ganchos: respaldo(idea).map((g) => ({ ...g, marca: marca(g) })) });
  const { data: id, error } = await admin.rpc("gancho_reservar", { p_user: user.id });
  if (error) return reply(429, { error: "rate_limited", message: "Has pedido muchas propuestas hoy. Sigue mañana o escribe tu idea tal cual." });
  try {
    const r = await askModel(sistema(fiab), `Idea de la persona:\n<idea>\n${idea}\n</idea>`, 900);
    await admin.rpc("gancho_coste", { p_id: id, p_coste: r.costUsd });
    return reply(200, { ganchos: validar(r.text, idea, fiab).map((g) => ({ ...g, marca: marca(g) })) });
  } catch (e) {
    console.error("ganchos", String(e));
    return reply(200, { ganchos: respaldo(idea).map((g) => ({ ...g, marca: marca(g) })) });
  }
});
