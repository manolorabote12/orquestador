// Compra dentro de un juego hecho con Orquestador. La llama el juego (clave anon, sin sesion).
// Peticion (POST): { juego (id de telemetria), sesion, producto, token (purchaseToken de Google) }
// 1 - Busca el paquete de Android del juego.  2 - Comprueba con Google que la compra es real y
// esta pagada (cuenta de servicio ORQ_PLAY_CUENTA, que el autor invito a su consola).
// 3 - La anota una vez (juego_compra_anotar) y la consume o reconoce en Google.
// Respuesta: { ok: true, nueva } o { error }. El juego da lo comprado solo con ok.

import { adminClient, CORS, reply } from "../_shared/http.ts";
import { tokenGoogle, type CuentaServicio } from "../_shared/google.ts";
import { api, cerrarJuego, validarJuego, verificarProducto } from "../_shared/compras.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS });
  if (req.method !== "POST") return reply(405, { error: "method_not_allowed" });
  let b: unknown;
  try { b = await req.json(); } catch { return reply(400, { error: "bad_json" }); }
  const pt = validarJuego(b);
  if (typeof pt === "string") return reply(400, { error: pt });
  const admin = adminClient();
  const { data: p } = await admin.from("projects").select("play").eq("telemetria_id", pt.juego).maybeSingle();
  const paquete = String((p?.play as Record<string, unknown> | null)?.paquete ?? "");
  if (!paquete) return reply(404, { error: "unknown_game" });
  const cuentaJson = Deno.env.get("ORQ_PLAY_CUENTA") ?? "";
  if (!cuentaJson) return reply(503, { error: "store_not_configured" });
  try {
    const base = api(Deno.env.get("ORQ_GOOGLE_API") ?? "https://androidpublisher.googleapis.com", paquete);
    const token = await tokenGoogle(JSON.parse(cuentaJson) as CuentaServicio, "https://www.googleapis.com/auth/androidpublisher");
    // Sin id de usuario: los juegos no tienen cuentas (el token de Google ya es unico por compra).
    const v = await verificarProducto(fetch, base, token, pt.producto, pt.token, "");
    if (!v.ok) return reply(402, { error: v.motivo ?? "not_verified" });
    const { data: nueva, error } = await admin.rpc("juego_compra_anotar", {
      p_juego: pt.juego, p_sesion: pt.sesion, p_producto: pt.producto, p_token: pt.token, p_orden: v.orderId ?? null,
    });
    if (error) return reply(500, { error: "grant_failed" });
    await cerrarJuego(fetch, base, token, pt.producto, pt.token);
    return reply(200, { ok: true, nueva: nueva === true });
  } catch (e) {
    console.error("juego-compra", String(e));
    return reply(502, { error: "google_unavailable" });
  }
});
