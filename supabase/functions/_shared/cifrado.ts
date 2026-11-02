// Cifrado de secretos de usuarios (clave .p8 de Apple) con AES-256-GCM. La clave sale de
// ORQ_LLAVES_SECRETO (SHA-256). Formato: 12 bytes de IV + texto cifrado con etiqueta.
// Lo descifra fabrica/apple/llave.py (mismo formato) en el Mac de GitHub.

async function clave(secreto: string): Promise<CryptoKey> {
  const h = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(secreto));
  return crypto.subtle.importKey("raw", h, { name: "AES-GCM" }, false, ["encrypt", "decrypt"]);
}

export async function cifrar(texto: string, secreto: string): Promise<Uint8Array> {
  if (secreto.length < 24) throw new Error("secreto_corto");
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const c = new Uint8Array(await crypto.subtle.encrypt({ name: "AES-GCM", iv }, await clave(secreto), new TextEncoder().encode(texto)));
  const out = new Uint8Array(12 + c.length);
  out.set(iv);
  out.set(c, 12);
  return out;
}

export async function descifrar(datos: Uint8Array, secreto: string): Promise<string> {
  const p = await crypto.subtle.decrypt({ name: "AES-GCM", iv: datos.slice(0, 12) }, await clave(secreto), datos.slice(12));
  return new TextDecoder().decode(p);
}

/** Una clave .p8 de App Store Connect: PEM de clave privada EC. */
export function esClaveP8(texto: string): boolean {
  const t = texto.trim();
  return t.startsWith("-----BEGIN PRIVATE KEY-----") && t.endsWith("-----END PRIVATE KEY-----") && t.length < 1000;
}
