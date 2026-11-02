function b64url(datos) {
  const bytes = typeof datos === "string" ? new TextEncoder().encode(datos) : new Uint8Array(datos);
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}
function pemADer(pem) {
  const limpio = pem.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const bin = atob(limpio);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out.buffer;
}
async function firmarJwt(cuenta, scope, ahora = Math.floor(Date.now() / 1e3)) {
  const cab = b64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const cuerpo = b64url(JSON.stringify({
    iss: cuenta.client_email,
    scope,
    aud: cuenta.token_uri ?? "https://oauth2.googleapis.com/token",
    iat: ahora,
    exp: ahora + 3600
  }));
  const clave = await crypto.subtle.importKey(
    "pkcs8",
    pemADer(cuenta.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const firma = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", clave, new TextEncoder().encode(`${cab}.${cuerpo}`));
  return `${cab}.${cuerpo}.${b64url(firma)}`;
}
async function tokenGoogle(cuenta, scope, f = fetch) {
  const jwt = await firmarJwt(cuenta, scope);
  const r = await f(cuenta.token_uri ?? "https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion: jwt }).toString()
  });
  const d = await r.json();
  if (!r.ok || !d.access_token) throw new Error(`google_auth: ${d.error ?? r.status}`);
  return d.access_token;
}
export {
  firmarJwt,
  tokenGoogle
};
