// Prueba de la verificacion de compras (sin Google): node pruebas/compras.mjs (tras compilar con esbuild).
import { generateKeyPairSync, createVerify } from "node:crypto";
import { firmarJwt, tokenGoogle } from "./.google.mjs";
import { api, cerrar, cerrarJuego, validarJuego, verificarProducto, verificarSuscripcion } from "./.compras.mjs";

let fallos = 0;
const check = (n, ok, d = "") => { console.log((ok ? "  OK   " : "  FAIL ") + n + (d ? `  (${d})` : "")); if (!ok) fallos++; };
const { privateKey, publicKey } = generateKeyPairSync("rsa", { modulusLength: 2048 });
const cuenta = { client_email: "orq@proyecto.iam.gserviceaccount.com", private_key: privateKey.export({ type: "pkcs8", format: "pem" }), token_uri: "https://oauth2.test/token" };

console.log("== Google: cuenta de servicio ==");
const jwt = await firmarJwt(cuenta, "https://www.googleapis.com/auth/androidpublisher", 1_800_000_000);
const [h, p, s] = jwt.split(".");
const ver = createVerify("RSA-SHA256"); ver.update(`${h}.${p}`);
check("JWT RS256 con firma valida", ver.verify(publicKey, Buffer.from(s, "base64url")));
const pay = JSON.parse(Buffer.from(p, "base64url").toString());
check("JWT con emisor, alcance y caducidad de 1 h", pay.iss === cuenta.client_email && pay.exp - pay.iat === 3600 && pay.aud === cuenta.token_uri);

const llamadas = [];
const respuestas = {};
const falso = async (url, opts = {}) => {
  llamadas.push({ url, metodo: opts.method ?? "GET" });
  if (url === cuenta.token_uri) return new Response(JSON.stringify({ access_token: "ya29.prueba" }), { status: 200 });
  const r = Object.entries(respuestas).find(([k]) => url.includes(k));
  if (!r) return new Response("{}", { status: 404 });
  return new Response(JSON.stringify(r[1].cuerpo ?? {}), { status: r[1].status ?? 200 });
};
check("pide el token a Google", (await tokenGoogle(cuenta, "x", falso)) === "ya29.prueba");

console.log("== Packs de tuercas ==");
const base = api("https://android.test", "com.orquestador.app");
const U = "0b6f3c3e-8c3e-4a51-9d7e-5b9f0e2a1c11";
respuestas["/products/tuercas_300/tokens/tok-ok"] = { cuerpo: { purchaseState: 0, consumptionState: 0, orderId: "GPA.1", obfuscatedExternalAccountId: U } };
let v = await verificarProducto(falso, base, "t", "tuercas_300", "tok-ok", U);
check("compra pagada -> valida y pendiente de consumir", v.ok && v.orderId === "GPA.1" && v.pendienteConsumir);
v = await verificarProducto(falso, base, "t", "tuercas_300", "tok-ok", "11111111-1111-4111-8111-111111111111");
check("token de otra cuenta -> rechazado", !v.ok && v.motivo === "otro_usuario");
respuestas["/products/tuercas_300/tokens/tok-pend"] = { cuerpo: { purchaseState: 2 } };
check("pago pendiente -> no se concede aun", (await verificarProducto(falso, base, "t", "tuercas_300", "tok-pend", U)).motivo === "pendiente");
respuestas["/products/tuercas_300/tokens/tok-canc"] = { cuerpo: { purchaseState: 1 } };
check("cancelada -> no", (await verificarProducto(falso, base, "t", "tuercas_300", "tok-canc", U)).motivo === "cancelada");
check("token inventado -> no existe", (await verificarProducto(falso, base, "t", "tuercas_300", "inventado", U)).motivo === "no_existe");
respuestas["/products/tuercas_300/tokens/tok-err"] = { status: 503 };
let lanzo = false;
try { await verificarProducto(falso, base, "t", "tuercas_300", "tok-err", U); } catch { lanzo = true; }
check("Google caido -> error (la app reintenta, nada se pierde)", lanzo);
respuestas[":consume"] = { cuerpo: {} };
await cerrar(falso, base, "t", "tuercas", "tuercas_300", "tok-ok");
check("consume el pack en Google", llamadas.some((l) => l.url.endsWith("/products/tuercas_300/tokens/tok-ok:consume") && l.metodo === "POST"));

console.log("== Premium (suscripcion) ==");
const futuro = new Date(Date.now() + 30 * 86400e3).toISOString();
respuestas["/subscriptionsv2/tokens/sub-ok"] = { cuerpo: { subscriptionState: "SUBSCRIPTION_STATE_ACTIVE", latestOrderId: "GPA.9",
  acknowledgementState: "ACKNOWLEDGEMENT_STATE_PENDING", lineItems: [{ productId: "premium_mensual", expiryTime: futuro }] } };
v = await verificarSuscripcion(falso, base, "t", "premium_mensual", "sub-ok");
check("activa -> valida con caducidad y pendiente de reconocer", v.ok && v.expira === futuro && v.pendienteReconocer);
check("otro producto -> no", (await verificarSuscripcion(falso, base, "t", "otra_cosa", "sub-ok")).motivo === "otro_producto");
respuestas["/subscriptionsv2/tokens/sub-exp"] = { cuerpo: { subscriptionState: "SUBSCRIPTION_STATE_EXPIRED", lineItems: [{ productId: "premium_mensual", expiryTime: "2020-01-01T00:00:00Z" }] } };
check("caducada -> no", !(await verificarSuscripcion(falso, base, "t", "premium_mensual", "sub-exp")).ok);
respuestas[":acknowledge"] = { cuerpo: {} };
await cerrar(falso, base, "t", "premium", "premium_mensual", "sub-ok");
check("reconoce la suscripcion (si no, Google la reembolsa a los 3 dias)", llamadas.some((l) => l.url.endsWith("/subscriptions/premium_mensual/tokens/sub-ok:acknowledge")));
console.log("== Compras dentro de los juegos ==");
const ok = { juego: "0f0e0d0c-0b0a-4908-8706-050403020100", sesion: "aaaaaaaaaaaaaaa1", producto: "monedas_500", token: "tok-1234567890" };
check("peticion valida del juego", typeof validarJuego(ok) === "object");
check("producto que no es del kit -> no", validarJuego({ ...ok, producto: "gemas_9999" }) === "unknown_product");
check("sesion rara -> no", validarJuego({ ...ok, sesion: "x" }) === "bad_session");
check("juego que no es un id -> no", validarJuego({ ...ok, juego: "1 or 1=1" }) === "bad_game");
respuestas[":consume"] = { cuerpo: {} };
await cerrarJuego(falso, base, "t", "monedas_500", "tok-a");
check("las monedas se consumen (se pueden volver a comprar)", llamadas.some((l) => l.url.endsWith("/products/monedas_500/tokens/tok-a:consume")));
await cerrarJuego(falso, base, "t", "sin_anuncios", "tok-b");
check("quitar anuncios se reconoce (es para siempre)", llamadas.some((l) => l.url.endsWith("/products/sin_anuncios/tokens/tok-b:acknowledge")));
console.log(`== ${fallos} fallos ==`);
process.exit(fallos ? 1 : 0);
