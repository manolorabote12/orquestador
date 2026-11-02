// Conectar el canal de YouTube del usuario (OAuth de Google, permiso youtube.upload). Logica pura:
// estado firmado (para que nadie conecte su canal a la cuenta de otro), URL de permiso y canje del codigo.

export const SCOPE = "https://www.googleapis.com/auth/youtube.upload https://www.googleapis.com/auth/youtube.readonly";

function b64url(bytes: Uint8Array): string {
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function hmac(clave: string, texto: string): Promise<string> {
  const k = await crypto.subtle.importKey("raw", new TextEncoder().encode(clave), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  return b64url(new Uint8Array(await crypto.subtle.sign("HMAC", k, new TextEncoder().encode(texto))));
}

export async function firmarEstado(clave: string, usuario: string, ahora = Date.now()): Promise<string> {
  const cuerpo = `${usuario}.${ahora}`;
  return `${cuerpo}.${await hmac(clave, cuerpo)}`;
}

/** Devuelve el id del usuario si el estado es auténtico y tiene menos de 15 minutos. */
export async function verificarEstado(clave: string, estado: string, ahora = Date.now()): Promise<string | null> {
  const partes = estado.split(".");
  if (partes.length !== 3) return null;
  const [usuario, ts, firma] = partes;
  if (!/^[0-9a-f-]{36}$/i.test(usuario) || !/^\d{10,14}$/.test(ts)) return null;
  if (ahora - Number(ts) > 15 * 60_000 || Number(ts) > ahora + 60_000) return null;
  return (await hmac(clave, `${usuario}.${ts}`)) === firma ? usuario : null;
}

export function urlPermiso(clienteId: string, redireccion: string, estado: string): string {
  const q = new URLSearchParams({
    client_id: clienteId, redirect_uri: redireccion, response_type: "code", scope: SCOPE,
    access_type: "offline", prompt: "consent", include_granted_scopes: "true", state: estado,
  });
  return `https://accounts.google.com/o/oauth2/v2/auth?${q.toString()}`;
}

export async function canjear(f: typeof fetch, tokenUrl: string, clienteId: string, secreto: string, redireccion: string,
  codigo: string): Promise<{ refresh: string; access: string }> {
  const r = await f(tokenUrl, {
    method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ code: codigo, client_id: clienteId, client_secret: secreto, redirect_uri: redireccion,
      grant_type: "authorization_code" }).toString(),
  });
  const d = await r.json() as { refresh_token?: string; access_token?: string; error?: string };
  if (!r.ok || !d.access_token) throw new Error(`google_${d.error ?? r.status}`);
  if (!d.refresh_token) throw new Error("sin_refresh_token");
  return { refresh: d.refresh_token, access: d.access_token };
}

export async function canal(f: typeof fetch, apiBase: string, access: string): Promise<{ id: string; titulo: string } | null> {
  const r = await f(`${apiBase}/youtube/v3/channels?part=snippet&mine=true`, { headers: { Authorization: `Bearer ${access}` } });
  if (!r.ok) return null;
  const d = await r.json() as { items?: { id: string; snippet?: { title?: string } }[] };
  const c = d.items?.[0];
  return c ? { id: c.id, titulo: c.snippet?.title ?? "" } : null;
}
