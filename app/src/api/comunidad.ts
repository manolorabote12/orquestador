// Comunidad: escaparate, me gusta, remix, reto de la semana, ideas de Chispa y denuncias.

import { ErrorApp } from "../errores";
import type { Conexion } from "./conexion";

/** Un gancho original: lo que la fábrica sabe hacer, con su marca para encargarlo. */
export interface Gancho { titulo: string; genero: string; giros: string[]; idea: string; por_que: string; marca: string }

/** Un juego del Escaparate (público: nunca lleva quién es el usuario). */
/** Reto de la semana: un tema y premio para los 3 juegos con más jugadas y me gusta esa semana. */
export interface RetoSemana {
  semana: number;
  tema: string;
  termina: string;
  premios: number[];
  mi_proyecto: string | null;
  participantes: number;
  ganadores_anterior: { titulo: string; autor: string; puesto: number }[];
}

export interface PuestoReto { puesto: number; project_id: string; titulo: string; genero: string; autor: string; version: number; puntos: number }

export interface JuegoEscaparate {
  project_id: string;
  titulo: string;
  genero: string;
  resumen: string;
  autor: string;
  version: number;
  jugadas: number;
  megusta: number;
  remixes: number;
  publicado_en: string;
}

/** Lo que la app puede pedir en esta area (servidor real o demostracion). */
export interface ApiComunidad {
  /** Escaparate de la comunidad ("top" o "nuevos"). */
  escaparate(orden: "top" | "nuevos" | "semana"): Promise<JuegoEscaparate[]>;
  /** 3 propuestas de juego originales (género + giros) para una idea. */
  ganchos(idea: string): Promise<Gancho[]>;
  /** Reto de la semana (tema, premios, si ya participas) y su clasificación. */
  retoSemana(): Promise<RetoSemana>;
  rankingReto(): Promise<PuestoReto[]>;
  /** Presenta uno de tus juegos (ya compartido en el Escaparate) al reto de esta semana. */
  participarReto(proyectoId: string): Promise<void>;
  /** Ficha pública de un juego (null si no está en el escaparate). */
  fichaEscaparate(proyectoId: string): Promise<JuegoEscaparate | null>;
  /** Comparte la versión actual con un enlace público. Devuelve la URL de jugar.html. */
  publicarEscaparate(proyectoId: string, autor: string): Promise<{ url: string | null }>;
  retirarEscaparate(proyectoId: string): Promise<void>;
  /** Paquete HTML5 para itch.io (zip con el juego para el navegador); enlace válido 1 día. */
  paqueteItch(proyectoId: string): Promise<{ url: string; nombre: string; mb: number }>;
  /** Copia un juego del escaparate a "Mis juegos" para cambiarlo en el taller. */
  remix(proyectoId: string): Promise<{ project_id: string }>;
  /** Pone o quita el me gusta. Devuelve el total. */
  meGusta(proyectoId: string): Promise<number>;
  /** URLs públicas de un juego del escaparate (icono, portada y paquete web). */
  archivosEscaparate(j: JuegoEscaparate): { icono: string; portada: string; pck: string | null };
  /** Contar una partida (anónimo). */
  jugada(proyectoId: string): Promise<void>;
  /** Denuncia contenido: un juego propio (lo generado por la IA) o una campaña de la Lanzadera. */
  denunciar(que: { proyecto?: string; campana?: string }, motivo: string): Promise<void>;
}

/** Servidor real (Supabase). */
export function supaComunidad(con: Conexion): ApiComunidad {
  const api: ApiComunidad = {
    async ganchos(idea: string) {
      const r = await con.invocar<{ ganchos: Gancho[] }>("ganchos", { idea }, "Chispa no ha podido proponer ideas ahora.");
      return r.ganchos;
    },

    async retoSemana() {
      const { data, error } = await con.sb.rpc("reto_actual");
      if (error) throw new ErrorApp("No se pudo cargar el reto de la semana.");
      return data as RetoSemana;
    },

    async rankingReto() {
      const { data, error } = await con.sb.rpc("reto_ranking", {});
      if (error) throw new ErrorApp("No se pudo cargar la clasificación del reto.");
      return (data ?? []) as PuestoReto[];
    },

    async participarReto(proyectoId: string) {
      const { error } = await con.sb.rpc("reto_participar", { p_project: proyectoId });
      if (error) throw new ErrorApp(error.message.includes("not_shared") ? "Primero compártelo en el escaparate (pestaña Compartir)." : "No se pudo presentar al reto.");
    },

    async escaparate(orden: "top" | "nuevos" | "semana") {
      const { data, error } = await con.sb.rpc("escaparate_lista", { p_orden: orden });
      if (error) throw new ErrorApp("No se pudo cargar el escaparate.");
      return (data ?? []) as JuegoEscaparate[];
    },

    async fichaEscaparate(proyectoId: string) {
      const { data } = await con.sb.rpc("escaparate_ficha", { p_project: proyectoId });
      return ((data ?? []) as JuegoEscaparate[])[0] ?? null;
    },

    publicarEscaparate(proyectoId: string, autor: string) {
      return con.invocar<{ url: string | null }>("escaparate", { accion: "publicar", project_id: proyectoId, autor }, "No se pudo compartir el juego.");
    },

    paqueteItch(proyectoId: string) {
      return con.invocar<{ url: string; nombre: string; mb: number }>("paquete-itch", { project_id: proyectoId }, "No se pudo preparar el paquete.");
    },

    async retirarEscaparate(proyectoId: string) {
      await con.invocar("escaparate", { accion: "retirar", project_id: proyectoId }, "No se pudo quitar del escaparate.");
    },

    remix(proyectoId: string) {
      return con.invocar<{ project_id: string }>("escaparate", { accion: "remix", project_id: proyectoId }, "No se pudo hacer el remix.");
    },

    async meGusta(proyectoId: string) {
      const { data, error } = await con.sb.rpc("escaparate_megusta", { p_project: proyectoId });
      if (error) throw new ErrorApp("No se pudo guardar el me gusta.");
      return Number(data ?? 0);
    },

    archivosEscaparate(j: JuegoEscaparate) {
      const base = `${(import.meta.env.VITE_SUPABASE_URL as string).replace(/\/$/, "")}/storage/v1/object/public/escaparate/${j.project_id}`;
      return { icono: `${base}/icono.png?v=${j.version}`, portada: `${base}/portada.png?v=${j.version}`, pck: `${base}/index.pck?v=${j.version}` };
    },

    async jugada(proyectoId: string) {
      await con.sb.rpc("escaparate_jugada", { p_project: proyectoId });
    },

    async denunciar(que: { proyecto?: string; campana?: string }, motivo: string) {
      const { error } = await con.sb.rpc("denunciar", { p_project: que.proyecto ?? null, p_campana: que.campana ?? null, p_motivo: motivo });
      if (error) throw new ErrorApp(error.message.includes("rate_limited") ? "Has enviado muchas denuncias hoy." : "No se pudo enviar la denuncia.");
    },
  };
  return api;
}
