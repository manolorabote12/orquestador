// Compras dentro de la app: la app compra en Google Play y manda aqui el purchaseToken.
// Aqui se comprueba con Google que es real y esta pagada, se concede UNA vez (grant_purchase)
// y se consume/reconoce en Google. La app nunca se concede nada a si misma.
//
// Secretos: ORQ_PLAY_TIENDA_CUENTA (JSON de la cuenta de servicio con permiso de "ver datos
// financieros" sobre la app Orquestador; si falta, ORQ_PLAY_CUENTA) y ORQ_APP_PAQUETE.

import { adminClient, CORS, reply, sessionUser } from "../_shared/http.ts";
import { tokenGoogle, type CuentaServicio } from "../_shared/google.ts";
import { api, cerrar, verificarProducto, verificarSuscripcion, type Tipo } from "../_shared/compras.ts";

const MENSAJES: Record<string, string> = {
  no_existe: "Google no reconoce esa compra.",
  pendiente: "El pago está pendiente. Las tuercas llegarán cuando se complete.",
  cancelada: "La compra se canceló.",
  otro_usuario: "Esa compra es de otra cuenta.",
  otro_producto: "Esa compra es de otro producto.",
  inactiva: "La suscripción no está activa.",
  caducada: "La suscripción ha caducado.",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS });
  if (req.method !== "POST") return reply(405, { error: "method_not_allowed" });
  const user = await sessionUser(req);
  if (!user) return reply(401, { error: "unauthorized", message: "Vuelve a iniciar sesión." });
  let body: { product_id?: string; purchase_token?: string };
  try { body = await req.json(); } catch { return reply(400, { error: "bad_json" }); }
  const producto = String(body.product_id ?? "");
  const compra = String(body.purchase_token ?? "");
  if (!/^[a-z0-9_.]{2,100}$/.test(producto) || compra.length < 10 || compra.length > 1000) return reply(400, { error: "bad_input" });

  const admin = adminClient();
  const { data: p } = await admin.from("store_products").select("kind").eq("product_id", producto).eq("active", true).maybeSingle();
  if (!p) return reply(400, { error: "unknown_product", message: "Ese producto no existe." });
  const tipo = p.kind as Tipo;

  const cuentaJson = Deno.env.get("ORQ_PLAY_TIENDA_CUENTA") ?? Deno.env.get("ORQ_PLAY_CUENTA") ?? "";
  const paquete = Deno.env.get("ORQ_APP_PAQUETE") ?? "com.orquestador.app";
  if (!cuentaJson) return reply(503, { error: "store_not_configured", message: "La tienda aún no está configurada." });
  try {
    const base = api(Deno.env.get("ORQ_GOOGLE_API") ?? "https://androidpublisher.googleapis.com", paquete);
    const token = await tokenGoogle(JSON.parse(cuentaJson) as CuentaServicio, "https://www.googleapis.com/auth/androidpublisher");
    const v = tipo === "tuercas"
      ? await verificarProducto(fetch, base, token, producto, compra, user.id)
      : await verificarSuscripcion(fetch, base, token, producto, compra);
    if (!v.ok) return reply(402, { error: v.motivo, message: MENSAJES[v.motivo ?? ""] ?? "No se pudo verificar la compra." });
    const { data, error } = await admin.rpc("grant_purchase", {
      p_user: user.id, p_product: producto, p_token: compra, p_order: v.orderId, p_expires: v.expira ?? null,
    });
    if (error) {
      const refunded = error.message.includes("refunded");
      return reply(refunded ? 409 : 500, { error: "grant_failed", message: refunded ? "Esa compra se reembolsó." : "No se pudo anotar la compra." });
    }
    // Despues de anotarla: si Google no la consume ahora, la app reintenta y grant_purchase no duplica.
    if (v.pendienteConsumir || v.pendienteReconocer) await cerrar(fetch, base, token, tipo, producto, compra);
    return reply(200, data as Record<string, unknown>);
  } catch (e) {
    console.error("play-purchase", String(e));
    return reply(502, { error: "google_unavailable", message: "Google Play no responde. Tu compra está a salvo: vuelve a intentarlo." });
  }
});
