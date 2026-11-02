// Ciclo de vida de un trabajo de pago. TODAS las funciones que gastan dinero en
// proveedores (IA, imágenes, música, voces, compilación) siguen este patrón:
//
//   const r = await reserveJob(admin, user.id, "art_set");   // comprueba límites y cobra
//   if (!r.ok) return reply(r.status, r.body);
//   try {
//     ...trabajo...
//     await finishJob(admin, r.jobId, { costUsd, units });      // guarda el coste real
//   } catch (e) {
//     await failJob(admin, r.jobId, e, { costUsd, refund: true }); // devuelve si toca
//   }

import type { SupabaseClient } from "npm:@supabase/supabase-js@2";

export type JobKind =
  | "design" | "edit" | "art_set" | "art_image" | "music_track" | "voice_line" | "build" | "game" | "plan";

export type ReserveResult =
  | { ok: true; jobId: string; creditsLeft: number; cost: number }
  | { ok: false; status: number; body: { error: string; message: string } };

const RESERVE_ERRORS: Record<string, { status: number; message: string }> = {
  insufficient_credits: { status: 402, message: "No tienes créditos suficientes." },
  rate_limited:         { status: 429, message: "Vas muy rápido. Espera un momento." },
  daily_limit:          { status: 429, message: "Has llegado al límite de hoy para esta acción. Vuelve mañana." },
  budget_exceeded:      { status: 503, message: "Hay mucha demanda ahora mismo. Inténtalo más tarde; no se te ha cobrado nada." },
  kind_disabled:        { status: 503, message: "Esta función todavía no está disponible." },
  unknown_kind:         { status: 400, message: "Acción desconocida." },
  unknown_user:         { status: 401, message: "Vuelve a iniciar sesión." },
};

export async function reserveJob(
  admin: SupabaseClient, userId: string, kind: JobKind, detail?: Record<string, unknown>,
): Promise<ReserveResult> {
  const { data, error } = await admin.rpc("reserve_job", {
    p_user: userId, p_kind: kind, p_detail: detail ?? null,
  });

  if (error) {
    const code = Object.keys(RESERVE_ERRORS).find((k) => error.message.includes(k));
    if (code) {
      const e = RESERVE_ERRORS[code];
      return { ok: false, status: e.status, body: { error: code, message: e.message } };
    }
    console.error("reserve_job", error.message);
    return { ok: false, status: 500, body: { error: "reserve_failed", message: "No se pudo iniciar el trabajo." } };
  }

  const row = Array.isArray(data) ? data[0] : data;
  return { ok: true, jobId: row.job_id, creditsLeft: row.credits_left, cost: row.cost };
}

export async function finishJob(
  admin: SupabaseClient, jobId: string,
  m: { costUsd: number; tokensIn?: number; tokensOut?: number; units?: number },
): Promise<void> {
  const { error } = await admin.rpc("finish_job", {
    p_job: jobId, p_cost_usd: m.costUsd,
    p_tokens_in: m.tokensIn ?? null, p_tokens_out: m.tokensOut ?? null, p_units: m.units ?? null,
  });
  if (error) console.error("finish_job", jobId, error.message);
}

// Devuelve true si se devolvieron los créditos al usuario.
export async function failJob(
  admin: SupabaseClient, jobId: string, err: unknown,
  o: { costUsd?: number; refund?: boolean } = {},
): Promise<boolean> {
  const message = err instanceof Error ? err.message : String(err);
  console.error("job failed", jobId, message);
  const { data, error } = await admin.rpc("fail_job", {
    p_job: jobId, p_error: message, p_cost_usd: o.costUsd ?? null, p_refund: o.refund ?? true,
  });
  if (error) {
    console.error("fail_job", jobId, error.message);
    return false;
  }
  return data === true;
}
