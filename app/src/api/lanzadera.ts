// Lanzadera: probadores reales para la prueba cerrada de Google Play.

import { ErrorApp } from "../errores";
import type { Conexion } from "./conexion";
import type { EstadoPlay } from "./publicar";

export interface CampanaLz {
  campana: string;
  titulo: string;
  nota: string;
  enlace_grupo: string;
  enlace_prueba: string;
  probadores: number;
  faltan: number;
  premium: boolean;
  created_at: string;
}

export interface PruebaLz {
  campana: string;
  titulo: string;
  enlace_grupo: string;
  enlace_prueba: string;
  estado: "activo" | "completado" | "abandonado";
  dias: number;
  hecho_hoy: boolean;
  objetivo: number;
}

export interface MiCampanaLz {
  id: string;
  titulo: string;
  estado: "abierta" | "lista";
  enlace_grupo: string;
  enlace_prueba: string;
  project_id: string;
  activos: number;
  completados: number;
  abandonos: number;
  objetivo: number;
  dias: number;
  probadores: { n: number; dias: number; estado: PruebaLz["estado"] }[];
  opiniones: { probador: number; dia: string; nivel: number; opinion: string }[];
  /** Para las respuestas de producción (migración 39): inicio, días jugados y niveles. */
  creada?: string;
  checkins?: number;
  nivel_medio?: number | null;
  nivel_max?: number | null;
}

export interface PanelLz {
  puntos: number;
  premium: boolean;
  probando: number;
  minimo_probando: number;
  visible_si_pruebas: boolean;
  campanas: MiCampanaLz[];
}

/** Mensajes para los errores de la Lanzadera (el servidor devuelve el código). */
export const ERRORES_LZ: Record<string, string> = {
  not_on_play: "Ese juego aún no está en Google Play. Súbelo primero a prueba cerrada desde «Mis juegos».",
  bad_group_link: "El enlace del grupo tiene que ser del tipo https://groups.google.com/g/nombre-del-grupo",
  campaign_exists: "Ese juego ya tiene una campaña abierta.",
  project_not_found: "Ese juego no existe.",
  note_too_long: "La nota es demasiado larga (máximo 300 caracteres).",
  campaign_not_found: "Esa campaña ya no está abierta.",
  own_campaign: "No puedes probar tu propio juego.",
  too_many: "Ya estás probando 10 juegos. Termina alguno antes de unirte a otro.",
  too_many_abandoned: "Has abandonado varias pruebas este mes. Espera unos días para unirte a otra.",
  campaign_full: "Esa campaña ya tiene todos los probadores.",
  already_joined: "Ya estás en esa campaña.",
  not_joined: "No estás en esa campaña.",
  abandoned: "Esta prueba se dio por abandonada (2 días sin jugar).",
  already_today: "Hoy ya has hecho el check-in. ¡Vuelve mañana!",
  bad_level: "Pon el número del nivel al que llegaste.",
  opinion_too_long: "La opinión es demasiado larga (máximo 500 caracteres).",
};

export function errorLz(mensaje: string, porDefecto: string): ErrorApp {
  const codigo = Object.keys(ERRORES_LZ).find((k) => mensaje.includes(k));
  return new ErrorApp(codigo ? ERRORES_LZ[codigo] : porDefecto);
}

/** Lo que la app puede pedir en esta area (servidor real o demostracion). */
export interface ApiLanzadera {
  /** Lanzadera: juegos de otros que buscan probadores. */
  lzLista(): Promise<CampanaLz[]>;
  /** Lanzadera: lo que estoy probando. */
  lzPruebas(): Promise<PruebaLz[]>;
  /** Lanzadera: mis puntos y mis campañas (con opiniones privadas). */
  lzPanel(): Promise<PanelLz>;
  /** Juegos míos que ya están en Google Play (pueden abrir campaña). */
  lzPublicables(): Promise<{ id: string; titulo: string }[]>;
  lzAbrir(proyectoId: string, enlaceGrupo: string, nota: string): Promise<string>;
  lzUnirme(campana: string): Promise<void>;
  lzCheckin(campana: string, nivel: number, opinion: string): Promise<{ dias: number; completado: boolean; puntos: number }>;
  lzCerrar(campana: string): Promise<void>;
}

/** Servidor real (Supabase). */
export function supaLanzadera(con: Conexion): ApiLanzadera {
  async function lz<T>(funcion: string, params: Record<string, unknown>, porDefecto: string): Promise<T> {
    const { data, error } = await con.sb.rpc(funcion, params);
    if (error) throw errorLz(error.message, porDefecto);
    return data as T;
  }

  const api: ApiLanzadera = {
    async lzLista() {
      return (await lz<CampanaLz[] | null>("lz_lista", {}, "No se pudo cargar la Lanzadera.")) ?? [];
    },

    async lzPruebas() {
      return (await lz<PruebaLz[] | null>("lz_mis_pruebas", {}, "No se pudieron cargar tus pruebas.")) ?? [];
    },

    lzPanel() {
      return lz<PanelLz>("lz_mis_campanas", {}, "No se pudieron cargar tus campañas.");
    },

    async lzPublicables() {
      const { data } = await con.sb.from("projects").select("id,title,play").order("updated_at", { ascending: false });
      return ((data ?? []) as { id: string; title: string; play: EstadoPlay | null }[])
        .filter((p) => p.play?.paquete && p.play.estado !== "primer_aab")
        .map((p) => ({ id: p.id, titulo: p.title }));
    },

    lzAbrir(proyectoId: string, enlaceGrupo: string, nota: string) {
      return lz<string>("lz_abrir", { p_project: proyectoId, p_enlace_grupo: enlaceGrupo, p_nota: nota }, "No se pudo abrir la campaña.");
    },

    async lzUnirme(campana: string) {
      await lz<number>("lz_unirme", { p_campana: campana }, "No te pudiste unir.");
    },

    async lzCheckin(campana: string, nivel: number, opinion: string) {
      const filas = await lz<{ dias: number; completado: boolean; puntos: number }[]>("lz_checkin",
        { p_campana: campana, p_nivel: nivel, p_opinion: opinion }, "No se pudo guardar el check-in.");
      return filas[0];
    },

    async lzCerrar(campana: string) {
      await lz<null>("lz_cerrar", { p_campana: campana }, "No se pudo cerrar la campaña.");
    },
  };
  return api;
}
