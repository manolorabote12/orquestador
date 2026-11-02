// Verificación de recompensas de AdMob en el servidor (Server-Side Verification).
//
// Cuando un usuario termina un anuncio bonificado, los servidores de Google llaman a
// nuestra función con los datos firmados. Comprobamos la firma con las claves públicas
// de Google: si cuadra, el anuncio se vio de verdad y se dan los créditos.
// La app NUNCA puede sumarse créditos por su cuenta.
//
// Documentación: https://developers.google.com/admob/android/ssv

export const GOOGLE_KEYS_URL = "https://www.gstatic.com/admob/reward/verifier-keys.json";

export interface SsvData {
  transactionId: string;
  userId: string;
  adUnit: string;
  timestampMs: number;
}

type KeyFetcher = () => Promise<Map<string, CryptoKey>>;

let cache: { keys: Map<string, CryptoKey>; at: number } | null = null;

export const fetchGoogleKeys: KeyFetcher = async () => {
  if (cache && Date.now() - cache.at < 6 * 3600_000) return cache.keys;
  const res = await fetch(GOOGLE_KEYS_URL, { signal: AbortSignal.timeout(10_000) });
  if (!res.ok) throw new Error("No se pudieron descargar las claves de AdMob: " + res.status);
  const json = await res.json() as { keys: { keyId: number; base64: string }[] };
  const keys = new Map<string, CryptoKey>();
  for (const k of json.keys) keys.set(String(k.keyId), await importSpki(k.base64));
  cache = { keys, at: Date.now() };
  return keys;
};

export async function importSpki(base64: string): Promise<CryptoKey> {
  return await crypto.subtle.importKey(
    "spki", b64ToBytes(base64), { name: "ECDSA", namedCurve: "P-256" }, false, ["verify"],
  );
}

function b64ToBytes(b64: string): Uint8Array<ArrayBuffer> {
  const s = b64.replace(/-/g, "+").replace(/_/g, "/");
  const padded = s + "=".repeat((4 - (s.length % 4)) % 4);
  return Uint8Array.from(atob(padded), (c) => c.charCodeAt(0));
}

// Google firma en DER; WebCrypto espera r||s de 32 bytes cada uno.
export function derToRaw(der: Uint8Array): Uint8Array<ArrayBuffer> {
  if (der[0] !== 0x30) throw new Error("Firma no DER");
  let i = 2;
  if (der[1] & 0x80) i = 2 + (der[1] & 0x7f);
  const readInt = (): Uint8Array => {
    if (der[i] !== 0x02) throw new Error("Firma DER mal formada");
    const len = der[i + 1];
    let v = der.slice(i + 2, i + 2 + len);
    i += 2 + len;
    while (v.length > 32 && v[0] === 0) v = v.slice(1);
    if (v.length > 32) throw new Error("Entero de firma demasiado largo");
    const out = new Uint8Array(32);
    out.set(v, 32 - v.length);
    return out;
  };
  const r = readInt();
  const s = readInt();
  const raw = new Uint8Array(64);
  raw.set(r, 0);
  raw.set(s, 32);
  return raw;
}

// Recibe la URL completa de la llamada de Google. Devuelve los datos si la firma es válida.
export async function verifySsv(url: URL, getKeys: KeyFetcher = fetchGoogleKeys): Promise<SsvData> {
  const query = url.search.startsWith("?") ? url.search.slice(1) : url.search;
  const sigAt = query.indexOf("&signature=");
  if (sigAt < 0) throw new Error("Falta la firma");
  const signedPart = query.slice(0, sigAt);

  const p = url.searchParams;
  const signature = p.get("signature") ?? "";
  const keyId = p.get("key_id") ?? "";
  const transactionId = p.get("transaction_id") ?? "";
  const userId = p.get("user_id") ?? "";
  const adUnit = p.get("ad_unit") ?? "";
  const timestampMs = Number(p.get("timestamp") ?? "0");

  if (!signature || !keyId || !transactionId) throw new Error("Faltan datos en la llamada");

  const keys = await getKeys();
  const key = keys.get(keyId);
  if (!key) throw new Error("Clave desconocida: " + keyId);

  const ok = await crypto.subtle.verify(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    derToRaw(b64ToBytes(signature)),
    new TextEncoder().encode(signedPart),
  );
  if (!ok) throw new Error("Firma no válida");

  return { transactionId, userId, adUnit, timestampMs };
}
