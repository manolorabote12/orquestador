// Tu juego en marcha: informe de jugadores, clasificaciones, liga, ingresos, eventos, A/B, resenas y charla.

import type { FilaInforme } from "../aprendizaje";
import { ErrorApp } from "../errores";
import { mensajePremio, type Canje, type PremioReal } from "../premio";
import { mensajeRegalo, type RegaloJuego } from "../regalo";
import { mensajeClase, type Clase } from "../clase";
import type { Conexion } from "./conexion";

/** Una fila de la clasificación online de un nivel (vista del autor). */
export interface FilaLiga {
  id: number;
  alias: string;
  trofeos: number;
  ayto: number;
  oculta: boolean;
}

/** Un evento en directo del juego (lo programa el autor; el juego lo ve sin publicar otra versión). */
export interface EventoJuego {
  id: number;
  tipo: "monedas_x2" | "regalo";
  titulo: string;
  regalo: number;
  inicio: string;
  fin: string;
  cobros: number;
}

/** Opiniones privadas de los jugadores (las de "no me gusta" llevan qué mejorar). */
export interface Opiniones {
  gusta: number;
  no_gusta: number;
  ultimas: { gusta: boolean; texto: string; nivel: number; version: number; fecha: string }[];
}

/** Una reseña de Google Play (las de los últimos 7 días con texto; Google no da más). */
export interface Resena {
  id: string;
  autor: string;
  estrellas: number;
  texto: string;
  traduccion: string | null;
  idioma: string;
  version: string;
  fecha: string;
  respuesta: string | null;
  respondida_en: string | null;
}

/** Resultados de la prueba A/B (por grupo, en la versión más nueva que la lleva). */
export interface InformeAb {
  nivel: number;
  hacia: string;
  version: number | null;
  grupos: Partial<Record<"a" | "b", { jugadores: number; intentos: number; ganados: number; salidas: number; muertes: number; superan: number }>>;
}

/** Panel de ingresos y jugadores de un juego (últimos días, UTC). */
export interface Ingresos {
  dias: { dia: string; jugadores: number; nuevos: number; partidas: number; compras: number; euros: number }[];
  productos: { producto: string; ventas: number; euros: number }[];
  total_euros: number;
  neto_euros: number;
  d1: number | null;
  d7: number | null;
  jugadores_total: number;
}

export interface EstadoCharla {
  mensajes: number;
  activa: boolean;
  hoy: number;
  precio: number;
  por_paquete: number;
}

export interface FilaMarcador {
  id: number;
  posicion: number;
  alias: string;
  puntos: number;
  oculta: boolean;
}

/** Error del servidor al programar un evento, dicho para el autor. */
export function mensajeEvento(m: string): string {
  if (m.includes("bad_title")) return "Ese título no vale: de 3 a 40 letras y sin palabrotas.";
  if (m.includes("bad_dates")) return "Las fechas no valen: dura de 1 hora a 14 días y empieza en los próximos 60 días.";
  if (m.includes("bad_gift")) return "El regalo va de 1 a 500 monedas.";
  if (m.includes("overlap")) return "Ya hay un evento en esas fechas.";
  if (m.includes("too_many")) return "Ya tienes 5 eventos programados.";
  return "No se pudo programar el evento.";
}

/** Lo que la app puede pedir en esta area (servidor real o demostracion). */
export interface ApiJugadores {
  /** Cómo lo juega la gente (datos anónimos), por versión y nivel. */
  informe(proyectoId: string): Promise<FilaInforme[]>;
  /** Clasificación online de un nivel del juego (con las filas que el autor ha ocultado). */
  clasificacion(proyectoId: string, nivel: number): Promise<FilaMarcador[]>;
  /** Oculta (o vuelve a mostrar) un apodo de la clasificación. */
  ocultarMarcador(id: number, oculta: boolean): Promise<void>;
  /** Liga de aldeas del juego (solo género aldea), con las aldeas ocultadas. */
  liga(proyectoId: string): Promise<FilaLiga[]>;
  /** Oculta (o vuelve a mostrar) una aldea de la liga. */
  ocultarLiga(id: number, oculta: boolean): Promise<void>;
  /** Jugadores por día, retención y ventas dentro del juego (últimos 30 días). */
  ingresos(proyectoId: string): Promise<Ingresos>;
  /** Eventos en directo del juego (en marcha, próximos y del último mes). */
  eventos(proyectoId: string): Promise<EventoJuego[]>;
  /** Cómo va la prueba A/B (null si no hay ninguna en marcha). */
  informeAb(proyectoId: string): Promise<InformeAb | null>;
  /** Reseñas de Google Play del juego (últimos 7 días). */
  resenas(proyectoId: string): Promise<Resena[]>;
  /** La IA propone una respuesta (no se envía nada). */
  borradorResena(proyectoId: string, resenaId: string): Promise<string>;
  /** Envía a Google Play la respuesta que el autor ha revisado. */
  responderResena(proyectoId: string, resenaId: string, texto: string): Promise<void>;
  /** Programa un evento: monedas dobles o un regalo de monedas para cada jugador. */
  crearEvento(proyectoId: string, e: { tipo: EventoJuego["tipo"]; titulo: string; inicio: Date; fin: Date; regalo: number }): Promise<void>;
  /** Borra un evento (si está en marcha, se acaba ya). */
  borrarEvento(id: number): Promise<void>;
  /** Premio real para negocios (null si no hay), con cuántos jugadores lo han ganado. */
  premio(proyectoId: string): Promise<PremioReal | null>;
  /** Guarda el premio (null lo quita). El juego lo ve al abrirse, sin publicar otra versión. */
  guardarPremio(proyectoId: string, p: PremioReal | null): Promise<PremioReal | null>;
  /** Clases del modo clase con sus alumnos. */
  clases(proyectoId: string): Promise<Clase[]>;
  /** Crea una clase; devuelve el código que se dicta a los alumnos. */
  crearClase(proyectoId: string, nombre: string): Promise<string>;
  /** Vacía la clase para otro trimestre (borra los alumnos y se queda el código). */
  vaciarClase(codigo: string): Promise<void>;
  /** Cierra una clase (borra sus alumnos). */
  cerrarClase(codigo: string): Promise<void>;
  /** Lo que dicen los jugadores en privado al preguntarles si les gusta. */
  opiniones(proyectoId: string): Promise<Opiniones>;
  /** Canjea en la tienda el código personal de un cliente (lo marca como usado). */
  canjearPremio(proyectoId: string, codigo: string): Promise<Canje>;
  /** Juego regalo (null si no lo es), con si ya lo han abierto y leído el mensaje. */
  regalo(proyectoId: string): Promise<RegaloJuego | null>;
  /** Guarda el regalo (null lo quita y borra su enlace privado si no está en el escaparate). */
  guardarRegalo(proyectoId: string, r: RegaloJuego | null): Promise<RegaloJuego | null>;
  /** Enlace privado para mandar el regalo (sube la versión actual). */
  enlaceRegalo(proyectoId: string): Promise<{ url: string | null }>;
  /** Charla en directo con los personajes: mensajes que quedan, uso de hoy y precio del paquete. */
  charlaEstado(proyectoId: string): Promise<EstadoCharla>;
  /** Compra un paquete de mensajes con tuercas (el cobro lo hace el servidor). */
  charlaActivar(proyectoId: string): Promise<{ mensajes: number; tuercas: number }>;
  /** Pausa o reanuda la charla (los mensajes que quedan se guardan). */
  charlaPausar(proyectoId: string, activa: boolean): Promise<void>;
}

/** Servidor real (Supabase). */
export function supaJugadores(con: Conexion): ApiJugadores {
  const api: ApiJugadores = {
    async clasificacion(proyectoId: string, nivel: number) {
      const { data, error } = await con.sb.rpc("marcador_autor", { p_project: proyectoId, p_nivel: nivel });
      if (error) throw new ErrorApp("No se pudo leer la clasificación.");
      return (data ?? []) as FilaMarcador[];
    },

    async ocultarMarcador(id: number, oculta: boolean) {
      const { error } = await con.sb.rpc("marcador_ocultar", { p_id: id, p_oculta: oculta });
      if (error) throw new ErrorApp("No se pudo cambiar esa fila de la clasificación.");
    },

    async liga(proyectoId: string) {
      const { data, error } = await con.sb.rpc("liga_autor", { p_project: proyectoId });
      if (error) throw new ErrorApp("No se pudo leer la liga.");
      return (data ?? []) as FilaLiga[];
    },

    async ocultarLiga(id: number, oculta: boolean) {
      const { error } = await con.sb.rpc("liga_ocultar", { p_id: id, p_oculta: oculta });
      if (error) throw new ErrorApp("No se pudo cambiar esa aldea.");
    },

    async ingresos(proyectoId: string) {
      const { data, error } = await con.sb.rpc("juego_ingresos", { p_project: proyectoId, p_dias: 30 });
      if (error) throw new ErrorApp("No se pudieron leer los ingresos.");
      return data as Ingresos;
    },

    async informeAb(proyectoId: string) {
      const { data, error } = await con.sb.rpc("prueba_ab_informe", { p_project: proyectoId });
      if (error) throw new ErrorApp("No se pudieron leer los datos de la prueba.");
      return (data as InformeAb | null) ?? null;
    },

    async resenas(proyectoId: string) {
      const r = await con.invocar<{ resenas: Resena[] }>("play-resenas", { project_id: proyectoId, accion: "listar" }, "No se pudieron leer las reseñas.");
      return r.resenas;
    },

    async borradorResena(proyectoId: string, resenaId: string) {
      const r = await con.invocar<{ texto: string }>("play-resenas", { project_id: proyectoId, accion: "borrador", review_id: resenaId },
        "Chispa no ha podido proponer una respuesta.");
      return r.texto;
    },

    async responderResena(proyectoId: string, resenaId: string, texto: string) {
      await con.invocar<{ ok: boolean }>("play-resenas", { project_id: proyectoId, accion: "responder", review_id: resenaId, texto },
        "No se pudo enviar la respuesta.");
    },

    async eventos(proyectoId: string) {
      const { data, error } = await con.sb.rpc("eventos_autor", { p_project: proyectoId });
      if (error) throw new ErrorApp("No se pudieron leer los eventos.");
      return (data ?? []) as EventoJuego[];
    },

    async crearEvento(proyectoId: string, e: { tipo: EventoJuego["tipo"]; titulo: string; inicio: Date; fin: Date; regalo: number }) {
      const { error } = await con.sb.rpc("evento_crear", { p_project: proyectoId, p_tipo: e.tipo, p_titulo: e.titulo,
        p_inicio: e.inicio.toISOString(), p_fin: e.fin.toISOString(), p_regalo: e.regalo });
      if (error) throw new ErrorApp(mensajeEvento(error.message));
    },

    async borrarEvento(id: number) {
      const { error } = await con.sb.rpc("evento_borrar", { p_id: id });
      if (error) throw new ErrorApp("No se pudo borrar el evento.");
    },

    async premio(proyectoId: string) {
      const { data, error } = await con.sb.rpc("premio_autor", { p_project: proyectoId });
      if (error) throw new ErrorApp("No se pudo leer el premio.");
      return (data ?? null) as PremioReal | null;
    },

    async clases(proyectoId: string) {
      const { data, error } = await con.sb.rpc("clases_autor", { p_project: proyectoId });
      if (error) throw new ErrorApp("No se pudieron leer las clases.");
      return (data ?? []) as Clase[];
    },

    async crearClase(proyectoId: string, nombre: string) {
      const { data, error } = await con.sb.rpc("clase_crear", { p_project: proyectoId, p_nombre: nombre });
      if (error) throw new ErrorApp(mensajeClase(error.message));
      return data as string;
    },

    async vaciarClase(codigo: string) {
      const { error } = await con.sb.rpc("clase_vaciar", { p_codigo: codigo });
      if (error) throw new ErrorApp("No se pudo vaciar la clase.");
    },

    async cerrarClase(codigo: string) {
      const { error } = await con.sb.rpc("clase_cerrar", { p_codigo: codigo });
      if (error) throw new ErrorApp("No se pudo cerrar la clase.");
    },

    async opiniones(proyectoId: string) {
      const { data, error } = await con.sb.rpc("opiniones_autor", { p_project: proyectoId });
      if (error) throw new ErrorApp("No se pudieron leer las opiniones.");
      return (data ?? { gusta: 0, no_gusta: 0, ultimas: [] }) as Opiniones;
    },

    async canjearPremio(proyectoId: string, codigo: string) {
      const { data, error } = await con.sb.rpc("premio_canjear", { p_project: proyectoId, p_codigo: codigo });
      if (error) throw new ErrorApp(error.message.includes("bad_code") ? "El código tiene esta forma: CAFE-7F3A." : "No se pudo comprobar el código.");
      return data as Canje;
    },

    async regalo(proyectoId: string) {
      const { data, error } = await con.sb.rpc("regalo_autor", { p_project: proyectoId });
      if (error) throw new ErrorApp("No se pudo leer el regalo.");
      return (data ?? null) as RegaloJuego | null;
    },

    async guardarRegalo(proyectoId: string, r: RegaloJuego | null) {
      const { data, error } = await con.sb.rpc("regalo_guardar", { p_project: proyectoId, p_para: r?.para ?? "", p_de: r?.de ?? "",
        p_mensaje: r?.mensaje ?? "", p_tras_nivel: r?.tras_nivel ?? 0 });
      if (error) throw new ErrorApp(mensajeRegalo(error.message));
      if (!r) await con.invocar("escaparate", { accion: "regalo_retirar", project_id: proyectoId }, "No se pudo quitar el enlace.");
      return (data ?? null) as RegaloJuego | null;
    },

    enlaceRegalo(proyectoId: string) {
      return con.invocar<{ url: string | null }>("escaparate", { accion: "regalo", project_id: proyectoId }, "No se pudo crear el enlace.");
    },

    async guardarPremio(proyectoId: string, p: PremioReal | null) {
      const { data, error } = await con.sb.rpc("premio_guardar", { p_project: proyectoId, p_texto: p?.texto ?? "",
        p_codigo: p?.codigo ?? "", p_tras_nivel: p?.tras_nivel ?? 1, p_donde: p?.donde ?? "", p_web: p?.web ?? "", p_caduca: p?.caduca || null });
      if (error) throw new ErrorApp(mensajePremio(error.message));
      return (data ?? null) as PremioReal | null;
    },

    async charlaEstado(proyectoId: string) {
      const { data, error } = await con.sb.rpc("charla_estado", { p_project: proyectoId });
      if (error) throw new ErrorApp("No se pudo leer la charla.");
      return data as EstadoCharla;
    },

    async charlaActivar(proyectoId: string) {
      const { data, error } = await con.sb.rpc("charla_activar", { p_project: proyectoId });
      if (error) {
        if (error.message.includes("insufficient_credits")) throw new ErrorApp("No tienes tuercas suficientes.");
        if (error.message.includes("daily_limit")) throw new ErrorApp("Ya has comprado muchos paquetes hoy. Vuelve mañana.");
        throw new ErrorApp("No se pudo activar la charla.");
      }
      return data as { mensajes: number; tuercas: number };
    },

    async charlaPausar(proyectoId: string, activa: boolean) {
      const { error } = await con.sb.rpc("charla_pausar", { p_project: proyectoId, p_activa: activa });
      if (error) throw new ErrorApp("No se pudo cambiar la charla.");
    },

    async informe(proyectoId: string) {
      const { data, error } = await con.sb.rpc("informe_jugadores", { p_project: proyectoId });
      if (error) throw new ErrorApp("No se pudieron leer los datos de los jugadores.");
      return (data ?? []) as FilaInforme[];
    },
  };
  return api;
}
