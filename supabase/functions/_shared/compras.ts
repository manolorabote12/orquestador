// Verificacion de compras de Google Play (Android Publisher v3). Logica pura: recibe fetch y el
// token de acceso, asi se prueba sin Google. La usa la funcion play-purchase.

export type Tipo = "tuercas" | "premium" | "plan";

export interface Verificada {
  ok: boolean;
  motivo?: string;
  orderId?: string;
  expira?: string | null;
  pendienteConsumir?: boolean;
  pendienteReconocer?: boolean;
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function api(base: string, paquete: string): string {
  return `${base.replace(/\/$/, "")}/androidpublisher/v3/applications/${encodeURIComponent(paquete)}/purchases`;
}

/** 1 - Compra unica (packs de tuercas). purchaseState 0 = pagada; 1 = cancelada; 2 = pendiente. */
export async function verificarProducto(f: typeof fetch, base: string, token: string, producto: string, compra: string,
  usuario: string): Promise<Verificada> {
  const r = await f(`${base}/products/${encodeURIComponent(producto)}/tokens/${encodeURIComponent(compra)}`,
    { headers: { Authorization: `Bearer ${token}` } });
  if (r.status === 404 || r.status === 400) return { ok: false, motivo: "no_existe" };
  if (!r.ok) throw new Error(`google_${r.status}`);
  const d = await r.json() as { purchaseState?: number; consumptionState?: number; orderId?: string; obfuscatedExternalAccountId?: string };
  if (d.purchaseState === 2) return { ok: false, motivo: "pendiente" };
  if (d.purchaseState !== 0) return { ok: false, motivo: "cancelada" };
  // Si la app marco la compra con el id del usuario, tiene que coincidir (evita reusar tokens ajenos).
  if (d.obfuscatedExternalAccountId && UUID.test(d.obfuscatedExternalAccountId) && d.obfuscatedExternalAccountId !== usuario) {
    return { ok: false, motivo: "otro_usuario" };
  }
  return { ok: true, orderId: d.orderId ?? compra.slice(0, 40), pendienteConsumir: d.consumptionState === 0 };
}

/** 2 - Suscripcion (premium). Valida estado, producto y caducidad. */
export async function verificarSuscripcion(f: typeof fetch, base: string, token: string, producto: string, compra: string,
  ahora = Date.now()): Promise<Verificada> {
  const r = await f(`${base}/subscriptionsv2/tokens/${encodeURIComponent(compra)}`, { headers: { Authorization: `Bearer ${token}` } });
  if (r.status === 404 || r.status === 400) return { ok: false, motivo: "no_existe" };
  if (!r.ok) throw new Error(`google_${r.status}`);
  const d = await r.json() as { subscriptionState?: string; latestOrderId?: string; acknowledgementState?: string;
    lineItems?: { productId?: string; expiryTime?: string }[] };
  const linea = (d.lineItems ?? []).find((l) => l.productId === producto);
  if (!linea) return { ok: false, motivo: "otro_producto" };
  const activos = ["SUBSCRIPTION_STATE_ACTIVE", "SUBSCRIPTION_STATE_IN_GRACE_PERIOD"];
  if (!activos.includes(d.subscriptionState ?? "")) return { ok: false, motivo: "inactiva" };
  if (!linea.expiryTime || Date.parse(linea.expiryTime) < ahora) return { ok: false, motivo: "caducada" };
  return { ok: true, orderId: d.latestOrderId ?? compra.slice(0, 40), expira: linea.expiryTime,
    pendienteReconocer: d.acknowledgementState === "ACKNOWLEDGEMENT_STATE_PENDING" };
}

/** 3 - Cerrar en Google: consumir (para poder volver a comprar el pack) o reconocer (o se reembolsa a los 3 dias). */
export async function cerrar(f: typeof fetch, base: string, token: string, tipo: Tipo, producto: string, compra: string): Promise<void> {
  const url = tipo === "tuercas"
    ? `${base}/products/${encodeURIComponent(producto)}/tokens/${encodeURIComponent(compra)}:consume`
    : `${base}/subscriptions/${encodeURIComponent(producto)}/tokens/${encodeURIComponent(compra)}:acknowledge`;
  const r = await f(url, { method: "POST", headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" }, body: "{}" });
  if (!r.ok && r.status !== 409) throw new Error(`google_close_${r.status}`);
}

// ------------------------------------------------------------------ compras dentro de los juegos

/** Productos del kit: los de monedas y el pase se consumen; quitar anuncios se compra una vez. */
export const PRODUCTOS_JUEGO: Record<string, Cierre> = {
  monedas_500: "consumir", monedas_3000: "consumir", pase_temporada: "consumir", sin_anuncios: "reconocer",
  pack_inicio: "reconocer",
};

/** Que se hace en Google con cada compra: consumir, reconocer (una vez) o suscripcion (VIP). */
export type Cierre = "consumir" | "reconocer" | "suscripcion";

/** Codigo de producto valido de Google Play (los del kit y los de las compras a medida). */
const SKU = /^[a-z][a-z0-9_]{2,39}$/;

export interface PeticionJuego { juego: string; sesion: string; producto: string; token: string }

/** Valida lo que manda el juego (sin sesion de usuario: clave anon). Devuelve el error o la peticion.
 * Si el producto es del kit o de la tienda del creador lo decide cierreDe con projects.play. */
export function validarJuego(b: unknown): PeticionJuego | string {
  if (!b || typeof b !== "object") return "bad_json";
  const o = b as Record<string, unknown>;
  const juego = String(o.juego ?? ""), sesion = String(o.sesion ?? ""), producto = String(o.producto ?? ""), token = String(o.token ?? "");
  if (!UUID.test(juego)) return "bad_game";
  if (!/^[0-9a-f]{16}$/.test(sesion)) return "bad_session";
  if (!SKU.test(producto)) return "unknown_product";
  if (token.length < 10 || token.length > 1000) return "bad_token";
  return { juego, sesion, producto, token };
}

/** Como se cierra un producto en este juego: el de la tienda del creador (projects.play.productos,
 * lo guarda la publicacion) o el del kit. null = no es de este juego. */
export function cierreDe(play: Record<string, unknown> | null, producto: string): Cierre | null {
  const propios = (play?.productos ?? null) as Record<string, unknown> | null;
  if (propios && typeof propios === "object" && Object.keys(propios).length > 0) {
    const c = propios[producto];
    return c === "consumir" || c === "reconocer" || c === "suscripcion" ? c : null;
  }
  return PRODUCTOS_JUEGO[producto] ?? null;
}

/** Cierra en Google una compra de juego: consumir (se puede volver a comprar), reconocer (una vez)
 * o reconocer la suscripcion. */
export async function cerrarJuego(f: typeof fetch, base: string, token: string, producto: string, compra: string,
  cierre: Cierre = PRODUCTOS_JUEGO[producto] ?? "reconocer"): Promise<void> {
  const url = cierre === "suscripcion"
    ? `${base}/subscriptions/${encodeURIComponent(producto)}/tokens/${encodeURIComponent(compra)}:acknowledge`
    : `${base}/products/${encodeURIComponent(producto)}/tokens/${encodeURIComponent(compra)}:${cierre === "consumir" ? "consume" : "acknowledge"}`;
  const r = await f(url, { method: "POST", headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" }, body: "{}" });
  if (!r.ok && r.status !== 409) throw new Error(`google_close_${r.status}`);
}
