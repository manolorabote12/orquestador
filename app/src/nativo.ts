// Anuncios con premio (AdMob) y compras (Google Play Billing) en la app instalada.
// Nada se concede en el móvil: el premio del anuncio lo da el servidor cuando Google le avisa
// (verificación en servidor, función admob-reward) y cada compra la verifica play-purchase con Google.

import { Capacitor } from "@capacitor/core";
import { AdMob, AdmobConsentStatus } from "@capacitor-community/admob";
import { NativePurchases, PURCHASE_TYPE, type Transaction } from "@capgo/native-purchases";

const BLOQUE_PREMIO = (import.meta.env.VITE_ADMOB_REWARDED as string | undefined) ?? "";
/** Anuncio entre partidas de la galería (bloque intersticial de AdMob de Orquestador). */
const BLOQUE_INTERSTICIAL = (import.meta.env.VITE_ADMOB_INTERSTICIAL as string | undefined) ?? "";

export function esNativo(): boolean {
  return Capacitor.isNativePlatform();
}

// ---------------------------------------------------------------- anuncios con premio

let listos: Promise<boolean> | null = null;

/** 1 - Consentimiento (RGPD) y arranque de AdMob, una sola vez. */
export function iniciarAnuncios(): Promise<boolean> {
  if (!esNativo() || !BLOQUE_PREMIO) return Promise.resolve(false);
  listos ??= (async () => {
    try {
      const info = await AdMob.requestConsentInfo();
      if (info.isConsentFormAvailable && info.status === AdmobConsentStatus.REQUIRED) await AdMob.showConsentForm();
      await AdMob.initialize({ tagForChildDirectedTreatment: false });
      return true;
    } catch {
      return false;
    }
  })();
  return listos;
}

export async function privacidadAnunciosRequerida(): Promise<boolean> {
  if (!(await iniciarAnuncios())) return false;
  try {
    const info = await AdMob.requestConsentInfo();
    return String(info.privacyOptionsRequirementStatus).toUpperCase() === "REQUIRED";
  } catch {
    return false;
  }
}

export async function mostrarPrivacidadAnuncios(): Promise<void> {
  await AdMob.showPrivacyOptionsForm();
}

export function anunciosDisponibles(): boolean {
  return esNativo() && !!BLOQUE_PREMIO;
}

/** 2 - Muestra el anuncio. true si el usuario lo vio entero (las tuercas las suma el servidor). */
export async function verAnuncioConPremio(usuarioId: string): Promise<boolean> {
  if (!(await iniciarAnuncios())) throw new Error("Los anuncios no están disponibles ahora.");
  await AdMob.prepareRewardVideoAd({ adId: BLOQUE_PREMIO, ssv: { userId: usuarioId } });
  const premio = await AdMob.showRewardVideoAd();
  return !!premio && Number(premio.amount) > 0;
}

/** Galería: hay anuncio entre partidas (app instalada con su bloque configurado). */
export function intersticialDisponible(): boolean {
  return esNativo() && !!BLOQUE_INTERSTICIAL;
}

/** Muestra un anuncio entre partidas. true si se llegó a mostrar (cuenta para el reparto). */
export async function mostrarIntersticial(): Promise<boolean> {
  if (!intersticialDisponible() || !(await iniciarAnuncios())) return false;
  try {
    await AdMob.prepareInterstitial({ adId: BLOQUE_INTERSTICIAL });
    await AdMob.showInterstitial();
    return true;
  } catch {
    return false;
  }
}

// ---------------------------------------------------------------- compras

export interface ProductoNativo {
  id: string;
  /** Suscripciones: plan base de Google Play ("mensual", "anual"...). */
  base?: string;
  precio: string;
  titulo: string;
}

export async function productos(ids: { id: string; tipo: "tuercas" | "premium" | "plan" }[]): Promise<ProductoNativo[]> {
  if (!esNativo() || !ids.length) return [];
  const out: ProductoNativo[] = [];
  for (const tipo of [PURCHASE_TYPE.INAPP, PURCHASE_TYPE.SUBS]) {
    const grupo = ids.filter((p) => (p.tipo !== "tuercas") === (tipo === PURCHASE_TYPE.SUBS)).map((p) => p.id);
    if (!grupo.length) continue;
    try {
      const { products } = await NativePurchases.getProducts({ productIdentifiers: grupo, productType: tipo });
      for (const p of products) {
        // Android, suscripciones: identifier = plan base y planIdentifier = id de la suscripción.
        if (tipo === PURCHASE_TYPE.SUBS && p.planIdentifier) out.push({ id: p.planIdentifier, base: p.identifier, precio: p.priceString, titulo: p.title });
        else out.push({ id: p.identifier, precio: p.priceString, titulo: p.title });
      }
    } catch {
      /* sin Google Play (o producto aún no creado en Play Console) */
    }
  }
  return out;
}

/** 3 - Compra en Google Play SIN reconocerla: la reconoce el servidor tras verificarla. */
export async function comprarNativo(id: string, suscripcion: boolean, usuarioId: string, planBase?: string): Promise<Transaction> {
  return NativePurchases.purchaseProduct({
    productIdentifier: id,
    // Android: las suscripciones necesitan el plan base ("mensual" o "anual").
    ...(suscripcion && planBase ? { planIdentifier: planBase } : {}),
    productType: suscripcion ? PURCHASE_TYPE.SUBS : PURCHASE_TYPE.INAPP,
    appAccountToken: usuarioId,
    isConsumable: false,
    autoAcknowledgePurchases: false,
  });
}

/** 4 - Compras pagadas que el servidor aún no ha cerrado (sin red al comprar, app cerrada...). */
export async function comprasPendientes(): Promise<{ id: string; token: string }[]> {
  if (!esNativo()) return [];
  const out: { id: string; token: string }[] = [];
  for (const tipo of [PURCHASE_TYPE.INAPP, PURCHASE_TYPE.SUBS]) {
    try {
      const { purchases } = await NativePurchases.getPurchases({ productType: tipo });
      for (const t of purchases) {
        // En Android, "1" = comprada. Las de tuercas sin consumir y las suscripciones sin reconocer.
        if (t.purchaseToken && (t.purchaseState === undefined || t.purchaseState === "1")
          && (tipo === PURCHASE_TYPE.INAPP || t.isAcknowledged === false)) {
          out.push({ id: t.productIdentifier, token: t.purchaseToken });
        }
      }
    } catch {
      /* sin Google Play */
    }
  }
  return out;
}

export async function gestionarSuscripcion(): Promise<void> {
  await NativePurchases.manageSubscriptions();
}

// ---------------------------------------------------------------- entrar con Google

const GOOGLE_WEB = (import.meta.env.VITE_GOOGLE_WEB_CLIENT_ID as string | undefined) ?? "";

/** En el movil hace falta el ID del cliente web de Google (publico) para el selector de cuentas. */
export function googleNativoDisponible(): boolean {
  return esNativo() && !!GOOGLE_WEB;
}

/** Selector de cuentas de Google de Android: devuelve el id_token (firmado por Google, lo
 *  comprueba Supabase) pedido con el nonce ya cifrado. null si la persona lo cancela. */
export async function googleIdToken(nonceCifrado: string): Promise<string | null> {
  const { SocialLogin } = await import("@capgo/capacitor-social-login");
  await SocialLogin.initialize({ google: { webClientId: GOOGLE_WEB } });
  try {
    const r = await SocialLogin.login({ provider: "google", options: { scopes: ["email", "profile"], nonce: nonceCifrado } });
    const res = r.result as { idToken?: string | null };
    return res.idToken ?? null;
  } catch (e) {
    const m = String((e as Error)?.message ?? e).toLowerCase();
    if (m.includes("cancel")) return null;
    throw e;
  }
}
