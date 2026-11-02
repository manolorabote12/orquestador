// Publicar un juego en la App Store: encola el trabajo y despierta al Mac de GitHub Actions
// (.github/workflows/ios.yml), porque Apple solo deja compilar en Mac.
// Secretos: GITHUB_REPO (dueno/repo) y GITHUB_DISPATCH_TOKEN (token con permiso actions:write en ese repo).

import { adminClient, CORS, reply, sessionUser } from "../_shared/http.ts";

const ERRORS: Record<string, { status: number; message: string }> = {
  apple_setup_missing: { status: 409, message: "Antes pon tus datos de Apple (equipo y clave de App Store Connect)." },
  project_not_found: { status: 404, message: "Ese juego no existe." },
  project_busy: { status: 409, message: "Ese juego ya se está fabricando. Espera a que termine." },
  daily_limit: { status: 429, message: "Has llegado al límite de subidas a Apple de hoy." },
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS });
  if (req.method !== "POST") return reply(405, { error: "method_not_allowed" });
  const user = await sessionUser(req);
  if (!user) return reply(401, { error: "unauthorized", message: "Vuelve a iniciar sesión." });
  let b: Record<string, unknown>;
  try { b = await req.json(); } catch { return reply(400, { error: "bad_json" }); }
  const projectId = typeof b.project_id === "string" ? b.project_id : "";
  if (!/^[0-9a-f-]{36}$/i.test(projectId)) return reply(400, { error: "bad_project" });
  const repo = Deno.env.get("GITHUB_REPO") ?? "";
  const token = Deno.env.get("GITHUB_DISPATCH_TOKEN") ?? "";
  if (!repo || !token) return reply(503, { error: "not_configured", message: "La publicación en Apple aún no está configurada." });
  const admin = adminClient();
  const { data, error } = await admin.rpc("queue_ios", { p_user: user.id, p_project: projectId });
  if (error) {
    const code = Object.keys(ERRORS).find((k) => error.message.includes(k));
    if (code) return reply(ERRORS[code].status, { error: code, message: ERRORS[code].message });
    return reply(500, { error: "queue_failed", message: "No se pudo preparar la subida a Apple." });
  }
  const row = Array.isArray(data) ? data[0] : data;
  const r = await fetch(`https://api.github.com/repos/${repo}/actions/workflows/ios.yml/dispatches`, {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, Accept: "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28" },
    body: JSON.stringify({ ref: "main", inputs: { trabajo: row.job_id } }),
  });
  if (!r.ok) {
    console.error("publish-ios dispatch", r.status, (await r.text()).slice(0, 200));
    await admin.rpc("fail_job", { p_job: row.job_id, p_error: "mac_unavailable", p_cost_usd: 0, p_refund: true });
    return reply(502, { error: "mac_unavailable", message: "El Mac en la nube no responde. Inténtalo en un rato." });
  }
  return reply(200, { job_id: row.job_id });
});
