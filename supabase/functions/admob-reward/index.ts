// Llamada de Google AdMob cuando un usuario termina un anuncio bonificado.
// Se despliega SIN verificación de sesión (la llama Google, no la app):
//   npx supabase functions deploy admob-reward --no-verify-jwt
//
// En la app, al cargar el anuncio, se configura la verificación en servidor con
// user_id = id del usuario en Supabase. En la consola de AdMob, en el bloque de anuncios
// bonificado, se pone como URL de verificación la de esta función.

import { adminClient, reply } from "../_shared/http.ts";
import { verifySsv } from "../_shared/admob-ssv.ts";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
// Opcional: solo aceptar recompensas de tu bloque de anuncios (sin el prefijo ca-app-pub-...).
const ALLOWED_AD_UNIT = Deno.env.get("ADMOB_REWARDED_AD_UNIT") ?? "";
const MAX_AGE_MS = 24 * 3600_000;

Deno.serve(async (req) => {
  if (req.method !== "GET") return reply(405, { error: "method_not_allowed" });
  const url = new URL(req.url);

  // Google comprueba la URL al configurarla con una llamada sin firma: hay que responder 200.
  if (!url.searchParams.has("signature")) return reply(200, { ok: true });

  let data;
  try {
    data = await verifySsv(url);
  } catch (e) {
    console.warn("admob-reward rechazado:", (e as Error).message);
    return reply(400, { error: "invalid_signature" });
  }

  // A partir de aquí la llamada es auténtica. Respondemos 200 aunque no demos premio,
  // para que Google no la reintente sin fin.
  if (ALLOWED_AD_UNIT && !data.adUnit.endsWith(ALLOWED_AD_UNIT)) {
    console.warn("admob-reward: bloque de anuncios ajeno", data.adUnit);
    return reply(200, { result: "ignored_ad_unit" });
  }
  if (!UUID.test(data.userId)) return reply(200, { result: "no_user" });
  if (Math.abs(Date.now() - data.timestampMs) > MAX_AGE_MS) return reply(200, { result: "too_old" });

  const { data: result, error } = await adminClient().rpc("grant_ad_reward", {
    p_user: data.userId, p_tx: data.transactionId, p_ad_unit: data.adUnit,
  });
  if (error) {
    console.error("grant_ad_reward", error.message);
    return reply(500, { error: "grant_failed" });   // Google reintentará
  }
  return reply(200, { result });
});
