const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
function api(base, paquete) {
  return `${base.replace(/\/$/, "")}/androidpublisher/v3/applications/${encodeURIComponent(paquete)}/purchases`;
}
async function verificarProducto(f, base, token, producto, compra, usuario) {
  const r = await f(
    `${base}/products/${encodeURIComponent(producto)}/tokens/${encodeURIComponent(compra)}`,
    { headers: { Authorization: `Bearer ${token}` } }
  );
  if (r.status === 404 || r.status === 400) return { ok: false, motivo: "no_existe" };
  if (!r.ok) throw new Error(`google_${r.status}`);
  const d = await r.json();
  if (d.purchaseState === 2) return { ok: false, motivo: "pendiente" };
  if (d.purchaseState !== 0) return { ok: false, motivo: "cancelada" };
  if (d.obfuscatedExternalAccountId && UUID.test(d.obfuscatedExternalAccountId) && d.obfuscatedExternalAccountId !== usuario) {
    return { ok: false, motivo: "otro_usuario" };
  }
  return { ok: true, orderId: d.orderId ?? compra.slice(0, 40), pendienteConsumir: d.consumptionState === 0 };
}
async function verificarSuscripcion(f, base, token, producto, compra, ahora = Date.now()) {
  const r = await f(`${base}/subscriptionsv2/tokens/${encodeURIComponent(compra)}`, { headers: { Authorization: `Bearer ${token}` } });
  if (r.status === 404 || r.status === 400) return { ok: false, motivo: "no_existe" };
  if (!r.ok) throw new Error(`google_${r.status}`);
  const d = await r.json();
  const linea = (d.lineItems ?? []).find((l) => l.productId === producto);
  if (!linea) return { ok: false, motivo: "otro_producto" };
  const activos = ["SUBSCRIPTION_STATE_ACTIVE", "SUBSCRIPTION_STATE_IN_GRACE_PERIOD"];
  if (!activos.includes(d.subscriptionState ?? "")) return { ok: false, motivo: "inactiva" };
  if (!linea.expiryTime || Date.parse(linea.expiryTime) < ahora) return { ok: false, motivo: "caducada" };
  return {
    ok: true,
    orderId: d.latestOrderId ?? compra.slice(0, 40),
    expira: linea.expiryTime,
    pendienteReconocer: d.acknowledgementState === "ACKNOWLEDGEMENT_STATE_PENDING"
  };
}
async function cerrar(f, base, token, tipo, producto, compra) {
  const url = tipo === "tuercas" ? `${base}/products/${encodeURIComponent(producto)}/tokens/${encodeURIComponent(compra)}:consume` : `${base}/subscriptions/${encodeURIComponent(producto)}/tokens/${encodeURIComponent(compra)}:acknowledge`;
  const r = await f(url, { method: "POST", headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" }, body: "{}" });
  if (!r.ok && r.status !== 409) throw new Error(`google_close_${r.status}`);
}
const PRODUCTOS_JUEGO = {
  monedas_500: "consumir",
  monedas_3000: "consumir",
  pase_temporada: "consumir",
  sin_anuncios: "reconocer",
  pack_inicio: "reconocer"
};
function validarJuego(b) {
  if (!b || typeof b !== "object") return "bad_json";
  const o = b;
  const juego = String(o.juego ?? ""), sesion = String(o.sesion ?? ""), producto = String(o.producto ?? ""), token = String(o.token ?? "");
  if (!UUID.test(juego)) return "bad_game";
  if (!/^[0-9a-f]{16}$/.test(sesion)) return "bad_session";
  if (!(producto in PRODUCTOS_JUEGO)) return "unknown_product";
  if (token.length < 10 || token.length > 1e3) return "bad_token";
  return { juego, sesion, producto, token };
}
async function cerrarJuego(f, base, token, producto, compra) {
  const accion = PRODUCTOS_JUEGO[producto] === "consumir" ? "consume" : "acknowledge";
  const r = await f(
    `${base}/products/${encodeURIComponent(producto)}/tokens/${encodeURIComponent(compra)}:${accion}`,
    { method: "POST", headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" }, body: "{}" }
  );
  if (!r.ok && r.status !== 409) throw new Error(`google_close_${r.status}`);
}
export {
  PRODUCTOS_JUEGO,
  api,
  cerrar,
  cerrarJuego,
  validarJuego,
  verificarProducto,
  verificarSuscripcion
};
