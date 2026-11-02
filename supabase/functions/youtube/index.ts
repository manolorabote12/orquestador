// Conectar el canal de YouTube del usuario para subir sus Shorts y su trailer.
//   POST (con sesion) {}            -> { url }  (la app la abre en el navegador)
//   GET  ?code=..&state=..          -> Google vuelve aqui; se guarda el permiso y se muestra "listo"
// Se despliega SIN verificacion de sesion (Google llama al GET); el POST comprueba la sesion a mano.
// Secretos: GOOGLE_OAUTH_CLIENT_ID, GOOGLE_OAUTH_CLIENT_SECRET (cliente web de Google Cloud).

import { adminClient, CORS, reply, sessionUser } from "../_shared/http.ts";
import { canal, canjear, firmarEstado, urlPermiso, verificarEstado } from "../_shared/youtube.ts";

const pagina = (titulo: string, texto: string) => new Response(
  `<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">` +
  `<title>${titulo}</title><body style="font-family:system-ui;background:#0f2a4a;color:#f4ead5;display:grid;place-items:center;min-height:90vh;text-align:center">` +
  `<main><h1>${titulo}</h1><p>${texto}</p><p>Ya puedes volver a Orquestador.</p></main>`,
  { headers: { "Content-Type": "text/html; charset=utf-8" } });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS });
  const cliente = Deno.env.get("GOOGLE_OAUTH_CLIENT_ID") ?? "";
  const secreto = Deno.env.get("GOOGLE_OAUTH_CLIENT_SECRET") ?? "";
  const clave = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const redireccion = `${(Deno.env.get("SUPABASE_URL") ?? "").replace(/\/$/, "")}/functions/v1/youtube`;
  if (!cliente || !secreto) return reply(503, { error: "youtube_not_configured", message: "La subida a YouTube aún no está configurada." });

  if (req.method === "POST") {
    const user = await sessionUser(req);
    if (!user) return reply(401, { error: "unauthorized", message: "Vuelve a iniciar sesión." });
    return reply(200, { url: urlPermiso(cliente, redireccion, await firmarEstado(clave, user.id)) });
  }
  if (req.method !== "GET") return reply(405, { error: "method_not_allowed" });
  const url = new URL(req.url);
  if (url.searchParams.get("error")) return pagina("No se conectó", "Has cancelado el permiso de YouTube.");
  const usuario = await verificarEstado(clave, url.searchParams.get("state") ?? "");
  const codigo = url.searchParams.get("code") ?? "";
  if (!usuario || !codigo) return pagina("Enlace caducado", "Vuelve a pulsar «Conectar YouTube» en la app.");
  try {
    const t = await canjear(fetch, "https://oauth2.googleapis.com/token", cliente, secreto, redireccion, codigo);
    const c = await canal(fetch, "https://www.googleapis.com", t.access);
    if (!c) return pagina("Sin canal", "Tu cuenta de Google no tiene canal de YouTube. Créalo en youtube.com y vuelve a intentarlo.");
    const { error } = await adminClient().rpc("youtube_guardar", { p_user: usuario, p_refresh: t.refresh, p_canal: c.titulo, p_canal_id: c.id });
    if (error) throw new Error(error.message);
    return pagina("¡YouTube conectado!", `Canal: ${c.titulo.replace(/[<>&"]/g, "")}`);
  } catch (e) {
    console.error("youtube", String(e));
    return pagina("No se pudo conectar", "Google no respondió bien. Inténtalo otra vez en un momento.");
  }
});
