// Entrada para quien revisa la app en Google Play / App Store: no puede recibir nuestro correo
// con el codigo, asi que en Play Console se le da un correo y un codigo fijos.
// Secreto ORQ_REVISOR = "correo:codigo" (codigo de 6 cifras). Sin el secreto, la funcion no existe.
// Peticion (POST, sin sesion): { email, codigo }   Respuesta: { access_token, refresh_token }

import { createClient } from "npm:@supabase/supabase-js@2";
import { adminClient, CORS, reply } from "../_shared/http.ts";

/** Comparacion en tiempo constante. */
function igual(a: string, b: string): boolean {
  const x = new TextEncoder().encode(a);
  const y = new TextEncoder().encode(b);
  let d = x.length ^ y.length;
  for (let i = 0; i < Math.max(x.length, y.length); i++) d |= (x[i] ?? 0) ^ (y[i] ?? 0);
  return d === 0;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS });
  if (req.method !== "POST") return reply(405, { error: "method_not_allowed" });
  const conf = Deno.env.get("ORQ_REVISOR") ?? "";
  const i = conf.lastIndexOf(":");
  if (i < 3) return reply(404, { error: "not_found" });
  const correo = conf.slice(0, i).trim().toLowerCase();
  const codigo = conf.slice(i + 1).trim();
  let b: Record<string, unknown>;
  try { b = await req.json(); } catch { return reply(400, { error: "bad_json" }); }
  const email = String(b.email ?? "").trim().toLowerCase();
  // 1 - Cualquier otro correo: como un codigo malo normal (no se revela nada).
  if (email !== correo) return reply(401, { error: "bad_code" });
  const admin = adminClient();
  const { data: bloqueado } = await admin.rpc("revisor_bloqueado");
  if (bloqueado) return reply(429, { error: "rate_limited" });
  if (!igual(String(b.codigo ?? "").trim(), codigo)) {
    await admin.rpc("revisor_fallo");
    return reply(401, { error: "bad_code" });
  }
  // 2 - Enlace magico generado en el servidor y canjeado aqui mismo: sesion normal de ese usuario.
  let hash = (await admin.auth.admin.generateLink({ type: "magiclink", email: correo })).data?.properties?.hashed_token;
  if (!hash) {
    // Primera vez: se crea la cuenta y se reintenta.
    await admin.auth.admin.createUser({ email: correo, email_confirm: true });
    hash = (await admin.auth.admin.generateLink({ type: "magiclink", email: correo })).data?.properties?.hashed_token;
    if (!hash) return reply(500, { error: "link_failed" });
  }
  const anon = createClient(Deno.env.get("SUPABASE_URL") ?? "", Deno.env.get("SUPABASE_ANON_KEY") ?? "", { auth: { persistSession: false } });
  const { data: s, error: e2 } = await anon.auth.verifyOtp({ token_hash: hash, type: "magiclink" });
  if (e2 || !s.session) return reply(500, { error: "verify_failed" });
  return reply(200, { access_token: s.session.access_token, refresh_token: s.session.refresh_token });
});
