const SCOPE = "https://www.googleapis.com/auth/youtube.upload https://www.googleapis.com/auth/youtube.readonly";
function b64url(bytes) {
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}
async function hmac(clave, texto) {
  const k = await crypto.subtle.importKey("raw", new TextEncoder().encode(clave), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  return b64url(new Uint8Array(await crypto.subtle.sign("HMAC", k, new TextEncoder().encode(texto))));
}
async function firmarEstado(clave, usuario, ahora = Date.now()) {
  const cuerpo = `${usuario}.${ahora}`;
  return `${cuerpo}.${await hmac(clave, cuerpo)}`;
}
async function verificarEstado(clave, estado, ahora = Date.now()) {
  const partes = estado.split(".");
  if (partes.length !== 3) return null;
  const [usuario, ts, firma] = partes;
  if (!/^[0-9a-f-]{36}$/i.test(usuario) || !/^\d{10,14}$/.test(ts)) return null;
  if (ahora - Number(ts) > 15 * 6e4 || Number(ts) > ahora + 6e4) return null;
  return await hmac(clave, `${usuario}.${ts}`) === firma ? usuario : null;
}
function urlPermiso(clienteId, redireccion, estado) {
  const q = new URLSearchParams({
    client_id: clienteId,
    redirect_uri: redireccion,
    response_type: "code",
    scope: SCOPE,
    access_type: "offline",
    prompt: "consent",
    include_granted_scopes: "true",
    state: estado
  });
  return `https://accounts.google.com/o/oauth2/v2/auth?${q.toString()}`;
}
async function canjear(f, tokenUrl, clienteId, secreto, redireccion, codigo) {
  const r = await f(tokenUrl, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      code: codigo,
      client_id: clienteId,
      client_secret: secreto,
      redirect_uri: redireccion,
      grant_type: "authorization_code"
    }).toString()
  });
  const d = await r.json();
  if (!r.ok || !d.access_token) throw new Error(`google_${d.error ?? r.status}`);
  if (!d.refresh_token) throw new Error("sin_refresh_token");
  return { refresh: d.refresh_token, access: d.access_token };
}
async function canal(f, apiBase, access) {
  const r = await f(`${apiBase}/youtube/v3/channels?part=snippet&mine=true`, { headers: { Authorization: `Bearer ${access}` } });
  if (!r.ok) return null;
  const d = await r.json();
  const c = d.items?.[0];
  return c ? { id: c.id, titulo: c.snippet?.title ?? "" } : null;
}
export {
  SCOPE,
  canal,
  canjear,
  firmarEstado,
  urlPermiso,
  verificarEstado
};
