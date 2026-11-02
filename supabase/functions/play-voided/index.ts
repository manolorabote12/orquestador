// Reembolsos y compras anuladas de Google Play: quita lo concedido (revoke_purchase).
// Lo llama el reloj de GitHub cada 6 horas con la clave de servicio; no es para la app.

import { adminClient, reply } from "../_shared/http.ts";
import { tokenGoogle, type CuentaServicio } from "../_shared/google.ts";

Deno.serve(async (req) => {
  const servicio = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!servicio || req.headers.get("Authorization") !== `Bearer ${servicio}`) return reply(401, { error: "unauthorized" });
  const cuentaJson = Deno.env.get("ORQ_PLAY_TIENDA_CUENTA") ?? Deno.env.get("ORQ_PLAY_CUENTA") ?? "";
  if (!cuentaJson) return reply(200, { revisadas: 0, nota: "tienda sin configurar" });
  const paquete = Deno.env.get("ORQ_APP_PAQUETE") ?? "com.orquestador.app";
  const base = (Deno.env.get("ORQ_GOOGLE_API") ?? "https://androidpublisher.googleapis.com").replace(/\/$/, "");
  const token = await tokenGoogle(JSON.parse(cuentaJson) as CuentaServicio, "https://www.googleapis.com/auth/androidpublisher");
  const desde = Date.now() - 7 * 86400e3;
  const admin = adminClient();
  let pagina = "";
  let revisadas = 0;
  let quitadas = 0;
  do {
    const url = `${base}/androidpublisher/v3/applications/${encodeURIComponent(paquete)}/purchases/voidedpurchases` +
      `?startTime=${desde}&type=1&maxResults=1000${pagina ? `&token=${encodeURIComponent(pagina)}` : ""}`;
    const r = await fetch(url, { headers: { Authorization: `Bearer ${token}` } });
    if (!r.ok) return reply(502, { error: `google_${r.status}` });
    const d = await r.json() as { voidedPurchases?: { purchaseToken: string }[]; tokenPagination?: { nextPageToken?: string } };
    for (const v of d.voidedPurchases ?? []) {
      revisadas++;
      const { data } = await admin.rpc("revoke_purchase", { p_token: v.purchaseToken });
      if (data === "revoked") quitadas++;
    }
    pagina = d.tokenPagination?.nextPageToken ?? "";
  } while (pagina);
  return reply(200, { revisadas, quitadas });
});
