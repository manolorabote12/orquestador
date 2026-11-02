// Función del servidor: idea (o cambio) -> JSON del juego validado.
//
// Flujo: sesión -> reserva el trabajo (límites, presupuesto y cobro en una transacción) ->
// IA -> validación -> guarda proyecto y versión -> cierra el trabajo con su coste real.
// Si algo falla, el trabajo se cierra como fallido y se devuelven los créditos
// (hasta el tope diario de devoluciones, para que nadie pueda abusar).
//
// Petición (POST, con la sesión del usuario en Authorization):
//   Crear:   { "idea": "texto", "ads": { banner, interstitial, rewarded } }
//   Cambiar: { "project_id": "uuid", "change": "texto", "ads": {...} }

import { adminClient, CORS, reply, sessionUser } from "../_shared/http.ts";
import { failJob, finishJob, reserveJob } from "../_shared/jobs.ts";
import { askModel, LlmError, llmConfigured } from "../_shared/llm.ts";
import { extractJson, validateSpec } from "../_shared/validate.ts";
import { DESIGNER_RULES, EXAMPLE_SPEC } from "../_shared/designer-prompt.ts";

type AdsIn = { banner?: unknown; interstitial?: unknown; rewarded?: unknown };

function adsFromRequest(a: unknown) {
  const ads = (a && typeof a === "object" ? a : {}) as AdsIn;
  return {
    banner: ads.banner !== false,
    interstitial_every_n_games: ads.interstitial === false ? 0 : 3,
    rewarded_revive: ads.rewarded !== false,
  };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return reply(405, { error: "method_not_allowed" });
  if (!llmConfigured()) return reply(500, { error: "server_misconfigured", message: "Falta ANTHROPIC_API_KEY" });

  // 1. Sesión
  const user = await sessionUser(req);
  if (!user) return reply(401, { error: "unauthorized", message: "Vuelve a iniciar sesión." });
  const admin = adminClient();

  // 2. Petición (se valida ANTES de cobrar)
  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return reply(400, { error: "bad_json" }); }

  const idea = typeof body.idea === "string" ? body.idea.trim() : "";
  const change = typeof body.change === "string" ? body.change.trim() : "";
  const projectId = typeof body.project_id === "string" ? body.project_id : "";
  const isEdit = projectId !== "";

  if (!isEdit && (idea.length < 15 || idea.length > 600)) {
    return reply(400, { error: "bad_idea", message: "Describe tu juego con entre 15 y 600 caracteres." });
  }
  if (isEdit && (change.length < 3 || change.length > 200)) {
    return reply(400, { error: "bad_change", message: "Describe el cambio con entre 3 y 200 caracteres." });
  }

  let current: { id: string; spec: unknown; version: number } | null = null;
  if (isEdit) {
    const { data } = await admin
      .from("projects")
      .select("id, spec, version")
      .eq("id", projectId)
      .eq("user_id", user.id)
      .maybeSingle();
    if (!data) return reply(404, { error: "project_not_found", message: "Ese proyecto no existe." });
    current = data;
  }

  // 3. Reserva: límites por minuto y por día, presupuesto global y cobro
  const r = await reserveJob(admin, user.id, isEdit ? "edit" : "design", isEdit ? { project_id: projectId } : undefined);
  if (!r.ok) return reply(r.status, r.body);

  // 4. IA + validación + guardado
  let costUsd = 0;
  try {
    const prompt = isEdit
      ? `JUEGO ACTUAL:\n${JSON.stringify(current!.spec)}\n\nCAMBIO QUE PIDE EL USUARIO:\n${change}\n\n` +
        "Devuelve el objeto JSON COMPLETO del juego aplicando solo ese cambio y manteniendo igual todo lo demás. Solo el JSON."
      : `EJEMPLO DE SALIDA VÁLIDA:\n${JSON.stringify(EXAMPLE_SPEC)}\n\nIDEA DEL USUARIO:\n${idea}\n\n` +
        "Responde solo con el objeto JSON del juego.";

    const ai = await askModel(DESIGNER_RULES, prompt);
    costUsd = ai.costUsd;

    const raw = extractJson(ai.text);
    if (raw && typeof raw === "object" && !Array.isArray(raw)) {
      (raw as Record<string, unknown>).ads = adsFromRequest(body.ads);
    }
    const { spec, msgs } = validateSpec(raw);
    if (!spec) throw new Error("Diseño no válido: " + msgs.map((m) => m.text).join("; "));

    let savedId: string;
    let version: number;
    if (isEdit) {
      version = current!.version + 1;
      const { error } = await admin
        .from("projects")
        .update({ spec, title: spec.meta.title, version, updated_at: new Date().toISOString() })
        .eq("id", current!.id);
      if (error) throw new Error(error.message);
      savedId = current!.id;
    } else {
      version = 1;
      const { data, error } = await admin
        .from("projects")
        .insert({ user_id: user.id, title: spec.meta.title, spec })
        .select("id")
        .single();
      if (error || !data) throw new Error(error?.message ?? "No se pudo guardar el proyecto");
      savedId = data.id;
    }

    await admin.from("project_versions").insert({
      project_id: savedId, version, spec, prompt: isEdit ? change : idea,
    });
    await finishJob(admin, r.jobId, { costUsd, tokensIn: ai.tokensIn, tokensOut: ai.tokensOut });

    return reply(200, {
      project_id: savedId,
      version,
      spec,
      fixes: msgs.filter((m) => m.kind === "fix").map((m) => m.text),
      credits: r.creditsLeft,
    });
  } catch (e) {
    if (e instanceof LlmError) costUsd = e.costUsd;
    const refunded = await failJob(admin, r.jobId, e, { costUsd, refund: true });
    return reply(502, {
      error: "design_failed",
      refunded,
      message: refunded
        ? "La IA no pudo crear el juego. Te hemos devuelto los créditos."
        : "La IA no pudo crear el juego. Hoy ya has usado todas las devoluciones automáticas.",
    });
  }
});
