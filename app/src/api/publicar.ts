// Publicar: Google Play, App Store, AdMob y los videos para redes (YouTube).

import { ErrorApp } from "../errores";
import type { Conexion } from "./conexion";

/** Texto para publicar en un idioma (lo escribe la IA). */
export interface Publicacion {
  titulo: string;
  texto: string;
  hashtags: string[];
}

/** Vídeos para redes del estudio de marketing: 3 clips y lo que se pega en cada red. */
export interface Marketing {
  videos: { estilo: string; gancho: string; mp4: string; portada: string }[];
  publicacion: { es: Publicacion; en: Publicacion };
  redes: Record<"es" | "en", { tiktok: string; reels: string; shorts_titulo: string; shorts_descripcion: string }>;
  voz: string;
  zip: string;
  /** Tráiler horizontal 16:9 (ficha de Google Play y YouTube). */
  trailer?: string;
  youtube?: { modo: string; videos: { estilo: string; id: string; url: string }[]; error?: string };
}

export type ModoYoutube = "no" | "oculto" | "publico";

/** Un paso de la guía de publicación en Google Play (lo genera la fábrica: fabrica/play/cuestionarios.py). */
export interface PasoGuia {
  id: string;
  titulo: string;
  texto: string;
  enlace?: string;
  campos?: Record<string, string>;
  datos?: { tipo: string; recogido: boolean; compartido: boolean; fines: string[]; nota?: string }[];
}

/** Lo que deja el trabajador al preparar o subir el juego a Google Play. */
export interface Publicar {
  guia: { juego: string; paquete: string; pasos: PasoGuia[]; aviso: string };
  privacidad_url: string;
  paquete: string;
  huella_llave: string;
  version_code: number;
  aab: string;
  resultado?: { version: number; pista: string; borrador: boolean; imagenes: number };
}

/** Estado del juego en Google Play (projects.play). */
export interface EstadoPlay {
  paquete?: string;
  version_code?: number;
  estado?: "primer_aab" | "subido" | "borrador";
  pista?: string;
  huella_llave?: string;
}

export interface CuentaPlay {
  estudio: string;
  correo: string;
  llave_huella: string | null;
}

export interface CuentaApple {
  equipo: string;
  clave_id: string;
  emisor: string;
}

export interface AdmobIds {
  app_id: string;
  interstitial: string;
  rewarded: string;
  /** Opcionales: bloque de banner, de apertura de app y perfil de monetización elegido por el autor. */
  banner?: string;
  app_open?: string;
  perfil?: string;
}

const ERRORES_ADMOB: Record<string, string> = {
  bad_app_id: "El ID de app de AdMob tiene la forma ca-app-pub-0000000000000000~0000000000 (con ~).",
  bad_ad_unit: "Cada bloque de anuncios tiene la forma ca-app-pub-0000000000000000/0000000000 (con /).",
  mixed_accounts: "La app y los bloques tienen que ser de la misma cuenta de AdMob.",
  test_ids: "Esos son los ids de prueba de Google: pega los de tu cuenta de AdMob.",
  project_not_found: "Ese juego no existe.",
  bad_profile: "Ese tipo de monetización no existe.",
};

/** Comprobación en el móvil antes de mandar (el servidor lo vuelve a comprobar). */
export function validarAdmob(ids: AdmobIds): string | null {
  if (!/^ca-app-pub-\d{16}~\d{10}$/.test(ids.app_id.trim())) return ERRORES_ADMOB.bad_app_id;
  if (![ids.interstitial, ids.rewarded].every((u) => /^ca-app-pub-\d{16}\/\d{10}$/.test(u.trim()))) return ERRORES_ADMOB.bad_ad_unit;
  const cuenta = ids.app_id.trim().split("~")[0];
  if ([ids.interstitial, ids.rewarded].some((u) => u.trim().split("/")[0] !== cuenta)) return ERRORES_ADMOB.mixed_accounts;
  if (cuenta === "ca-app-pub-3940256099942544") return ERRORES_ADMOB.test_ids;
  for (const u of [ids.banner ?? "", ids.app_open ?? ""].map((x) => x.trim()).filter((x) => x)) {
    if (!/^ca-app-pub-\d{16}\/\d{10}$/.test(u)) return ERRORES_ADMOB.bad_ad_unit;
    if (u.split("/")[0] !== cuenta) return ERRORES_ADMOB.mixed_accounts;
  }
  return null;
}

/** Lo que la app puede pedir en esta area (servidor real o demostracion). */
export interface ApiPublicar {
  /** Tuercas que cuestan los vídeos para redes (las cobra el servidor). */
  precioMarketing(): Promise<number>;
  /** Encarga los 3 vídeos para redes de la versión actual del juego. */
  marketing(proyectoId: string, youtube?: ModoYoutube): Promise<{ job_id: string; credits: number }>;
  /** Canal de YouTube conectado (para subir los vídeos de marketing). */
  youtubeEstado(): Promise<{ conectado: boolean; canal?: string }>;
  /** URL de Google para dar permiso (se abre en el navegador). */
  youtubeConectar(): Promise<string>;
  youtubeDesconectar(): Promise<void>;
  /** Datos de publicación del usuario (estudio y correo), o null si aún no los ha puesto. */
  cuentaPlay(): Promise<CuentaPlay | null>;
  /** Guarda estudio y correo. Devuelve el correo de la cuenta de servicio de Orquestador. */
  guardarCuentaPlay(estudio: string, correo: string): Promise<{ cuenta_servicio: string }>;
  /** Prepara (primer_aab) o sube (subir) el juego a Google Play. Gratis. */
  publicar(proyectoId: string, modo: "primer_aab" | "subir", pista: string): Promise<{ job_id: string }>;
  /** Datos de Apple (equipo e ids de la clave; la .p8 nunca vuelve a la app). */
  cuentaApple(): Promise<CuentaApple | null>;
  guardarCuentaApple(d: CuentaApple & { p8: string }): Promise<void>;
  /** Compila en un Mac en la nube y sube a App Store Connect (TestFlight). */
  publicarIOS(proyectoId: string): Promise<{ job_id: string }>;
  /** Guarda (o quita, con todo vacío) los ids de AdMob del juego para la versión de tienda. */
  guardarAdmob(proyectoId: string, ids: AdmobIds | null): Promise<AdmobIds | null>;
}

/** Servidor real (Supabase). */
export function supaPublicar(con: Conexion): ApiPublicar {
  const api: ApiPublicar = {
    async cuentaApple() {
      const { data } = await con.sb.from("apple_cuentas").select("equipo,clave_id,emisor").maybeSingle();
      return (data as CuentaApple | null) ?? null;
    },

    async guardarCuentaApple(d: CuentaApple & { p8: string }) {
      await con.invocar<{ ok: boolean }>("apple-setup", { ...d }, "No se pudieron guardar tus datos de Apple.");
    },

    publicarIOS(proyectoId: string) {
      return con.invocar<{ job_id: string }>("publish-ios", { project_id: proyectoId }, "No se pudo preparar la subida a Apple.");
    },

    async guardarAdmob(proyectoId: string, ids: AdmobIds | null) {
      if (ids) {
        const err = validarAdmob(ids);
        if (err) throw new ErrorApp(err);
      }
      const { data, error } = await con.sb.rpc("set_project_admob", { p_project: proyectoId,
        p_app_id: ids?.app_id.trim() ?? "", p_interstitial: ids?.interstitial.trim() ?? "", p_rewarded: ids?.rewarded.trim() ?? "",
        p_banner: ids?.banner?.trim() ?? "", p_app_open: ids?.app_open?.trim() ?? "", p_perfil: ids?.perfil?.trim() ?? "" });
      if (error) {
        const codigo = Object.keys(ERRORES_ADMOB).find((k) => error.message.includes(k));
        throw new ErrorApp(codigo ? ERRORES_ADMOB[codigo] : "No se pudieron guardar los anuncios.");
      }
      return (data as AdmobIds | null) ?? null;
    },

    async precioMarketing() {
      const { data } = await con.sb.from("pricing").select("credits").eq("kind", "game_marketing").maybeSingle();
      return (data?.credits as number | undefined) ?? 20;
    },

    marketing(proyectoId: string, youtube: ModoYoutube = "no") {
      return con.invocar<{ job_id: string; credits: number }>("create-marketing", { project_id: proyectoId, youtube }, "No se pudieron encargar los vídeos.");
    },

    async youtubeEstado() {
      const { data } = await con.sb.rpc("youtube_estado");
      return (data as { conectado: boolean; canal?: string } | null) ?? { conectado: false };
    },

    async youtubeConectar() {
      const r = await con.invocar<{ url: string }>("youtube", {}, "No se pudo conectar con YouTube.");
      return r.url;
    },

    async youtubeDesconectar() {
      await con.sb.rpc("youtube_desconectar");
    },

    async cuentaPlay() {
      const { data } = await con.sb.from("play_cuentas").select("estudio,correo,llave_huella").maybeSingle();
      return (data as CuentaPlay | null) ?? null;
    },

    guardarCuentaPlay(estudio: string, correo: string) {
      return con.invocar<{ cuenta_servicio: string }>("play-setup", { estudio, correo }, "No se pudieron guardar tus datos.");
    },

    publicar(proyectoId: string, modo: "primer_aab" | "subir", pista: string) {
      return con.invocar<{ job_id: string }>("publish-game", { project_id: proyectoId, modo, pista }, "No se pudo preparar la publicación.");
    },
  };
  return api;
}
