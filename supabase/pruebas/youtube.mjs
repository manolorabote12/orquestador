// Conexion de YouTube sin Google: estado firmado, URL de permiso y canje del codigo.
import { firmarEstado, verificarEstado, urlPermiso, canjear, canal, SCOPE } from "./.youtube.mjs";
let fallos = 0;
const check = (n, ok, d = "") => { console.log((ok ? "  OK   " : "  FAIL ") + n + (d ? `  (${d})` : "")); if (!ok) fallos++; };
const U = "0b6f3c3e-8c3e-4a51-9d7e-5b9f0e2a1c11";
console.log("== YouTube ==");
const e = await firmarEstado("clave-servidor", U, 1_800_000_000_000);
check("estado autentico -> usuario", (await verificarEstado("clave-servidor", e, 1_800_000_060_000)) === U);
check("estado con otra clave -> rechazado", (await verificarEstado("otra", e, 1_800_000_060_000)) === null);
const trucado = e.replace(U, "11111111-1111-4111-8111-111111111111");
check("estado con otro usuario -> rechazado", (await verificarEstado("clave-servidor", trucado, 1_800_000_060_000)) === null);
check("estado caducado (16 min) -> rechazado", (await verificarEstado("clave-servidor", e, 1_800_000_000_000 + 16 * 60_000)) === null);
const u = new URL(urlPermiso("cliente.apps.googleusercontent.com", "https://x.supabase.co/functions/v1/youtube", e));
check("permiso offline con consentimiento (da refresh token)", u.searchParams.get("access_type") === "offline" && u.searchParams.get("prompt") === "consent");
check("solo los permisos necesarios", u.searchParams.get("scope") === SCOPE && SCOPE.includes("youtube.upload") && !SCOPE.includes("youtube.force-ssl"));
const falso = async (url, o = {}) => {
  if (url.includes("/token")) {
    const b = new URLSearchParams(o.body);
    return new Response(JSON.stringify(b.get("code") === "bueno" ? { access_token: "ya29", refresh_token: "1//rt" } : { access_token: "ya29" }), { status: 200 });
  }
  return new Response(JSON.stringify({ items: [{ id: "UC123", snippet: { title: "Daniel Juegos" } }] }), { status: 200 });
};
const t = await canjear(falso, "https://oauth2.test/token", "c", "s", "r", "bueno");
check("canjea el codigo por un refresh token", t.refresh === "1//rt");
let sinRt = false;
try { await canjear(falso, "https://oauth2.test/token", "c", "s", "r", "malo"); } catch (err) { sinRt = String(err).includes("sin_refresh_token"); }
check("sin refresh token -> error claro", sinRt);
const c = await canal(falso, "https://api.test", "ya29");
check("lee el canal", c?.id === "UC123" && c.titulo === "Daniel Juegos");
console.log(`== ${fallos} fallos ==`);
process.exit(fallos ? 1 : 0);
