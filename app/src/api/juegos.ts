// Mis juegos y el taller: encargos, trabajos en marcha, versiones, cambios con Chispa y archivos.

import { FunctionsHttpError } from "@supabase/supabase-js";
import type { NivelesJuego } from "../editor";
import { ErrorApp } from "../errores";
import type { Conexion } from "./conexion";
import type { AdmobIds, EstadoPlay, Marketing, Publicar } from "./publicar";

export interface Evento {
  paso: string;
  estado: string;
  mensaje: string;
  t?: number;
  titulo?: string;
  /** Paquete web provisional (arte del kit) para jugar mientras se dibuja el definitivo. */
  boceto?: string;
}

export interface Resultado {
  apk?: string;
  /** Paquete web de la versión (index.pck) para jugar dentro de la app. */
  web?: string;
  /** Ficha de Google Play (.zip): icono, gráfico destacado, capturas con mensajes y textos ES/EN. */
  ficha?: string;
  /** Clip vertical de 15 s (MP4 1080x1920) jugado por el bot, para TikTok, Shorts y Reels. */
  clip?: string;
  /** Estudio de marketing: 3 clips con guion, subtítulos y voz en off hechos por IA. */
  marketing?: Marketing;
  /** Publicación en Google Play: .aab, guía, política de privacidad. */
  publicar?: Publicar;
  icono?: string;
  capturas: string[];
  proyecto?: string;
  informe?: string;
  /** Niveles de la versión (mapas, nombres y género) para el editor manual. */
  niveles?: string;
}

export type Estado = "queued" | "running" | "done" | "failed";

export interface Trabajo {
  id: string;
  kind: string;
  project_id: string | null;
  status: Estado;
  created_at: string;
  idea: string;
  progress: Evento[];
  result: Resultado | null;
  error: string | null;
  refunded: boolean;
  titulo: string | null;
}

export interface Version {
  version: number;
  prompt: string;
  created_at: string;
  files: Resultado | null;
}

export interface Proyecto {
  id: string;
  titulo: string;
  version: number;
  files: Resultado | null;
  updated_at: string;
  versiones: Version[];
  /** Cambio o restauración en marcha (si lo hay). */
  activo: Trabajo | null;
  /** Estado en Google Play (null si aún no se ha preparado). */
  play: EstadoPlay | null;
  /** Nombres de los niveles (del diseño). */
  niveles: string[];
  /** Género del juego (del diseño), p. ej. "aldea". */
  genero?: string;
  /** Ids de AdMob del juego (null = se publica sin anuncios). */
  admob?: AdmobIds | null;
  /** Qué lleva el juego publicado (del diseño; lo que falta va encendido). */
  funciones?: Partial<Record<Funcion, boolean>>;
  /** "infantil" = para menores de 13 (sin compras, avisos ni nada online). */
  publico?: "todos" | "infantil";
  /** Giros y mezclas que lleva el juego (fabrica/giros.py). */
  giros?: string[];
  /** Índice de originalidad 0-100 frente a los demás juegos de la fábrica (fabrica/originalidad.py). */
  originalidad?: number | null;
  /** Prueba A/B de un nivel en marcha (la mitad de los jugadores juega la versión B). */
  prueba_ab?: { nivel: number; hacia: "mas_facil" | "mas_dificil" | "distinto" } | null;
  /** Estado en la App Store de Apple. */
  ios?: { bundle?: string; build?: number; estado?: string; subido_en?: number } | null;
}

export type Funcion = "tienda" | "pase" | "avisos" | "nube" | "online";

export interface Propuesta {
  plan_id: string | null;
  resumen: string;
  pregunta: string | null;
  no_puedo: string | null;
  operaciones: string[];
  coste: number;
}

export type Entrada =
  | { tipo: "proyecto"; id: string; titulo: string; version: number; icono?: string; fecha: string; ocupado: boolean;
      /** Para la tarjeta: tipo de juego, giros y una captura vertical (la del juego en marcha). */
      genero?: string; giros?: string[]; portada?: string }
  | { tipo: "encargo"; trabajo: Trabajo };

const COLUMNAS = "id,kind,project_id,status,created_at,detail,progress,result,error,refunded,projects(title)";

interface FilaTrabajo {
  id: string;
  kind: string;
  project_id: string | null;
  status: Estado;
  created_at: string;
  detail: { idea?: string; instruccion?: string; version?: number } | null;
  progress: Evento[] | null;
  result: Resultado | null;
  error: string | null;
  refunded: boolean;
  projects: { title: string } | { title: string }[] | null;
}

function aTrabajo(f: FilaTrabajo): Trabajo {
  const p = Array.isArray(f.projects) ? f.projects[0] : f.projects;
  const ultimoTitulo = [...(f.progress ?? [])].reverse().find((e) => e.titulo)?.titulo ?? null;
  const d = f.detail ?? {};
  return {
    id: f.id,
    kind: f.kind,
    project_id: f.project_id,
    status: f.status,
    created_at: f.created_at,
    idea: f.kind === "game_marketing" ? "Vídeos para redes" : f.kind === "game_publish" ? "Publicar en Google Play" : (typeof d.idea === "string" ? d.idea.replace(/^\[(plantilla|gancho):[a-z0-9_:,]*\]\s*/, "") : undefined) ?? d.instruccion ?? (d.version ? `Volver a la versión ${d.version}` : ""),
    progress: f.progress ?? [],
    result: f.result ? { ...f.result, capturas: f.result.capturas ?? [] } : null,
    error: f.error,
    refunded: f.refunded,
    titulo: p?.title ?? ultimoTitulo,
  };
}

/** Lo que la app puede pedir en esta area (servidor real o demostracion). */
export interface ApiJuegos {
  /** Encarga el juego; con previaId se fabrica el diseño de esa vista previa (el que el jugador aprobó). */
  encargar(idea: string, previaId?: string): Promise<{ job_id: string; credits: number }>;
  /** Vista previa gratis: la fábrica piensa solo el diseño (un minuto). Se sigue con seguir(job_id). */
  vistaPrevia(idea: string): Promise<{ job_id: string }>;
  trabajos(): Promise<Trabajo[]>;
  /** Avisa de cada cambio del trabajo hasta que termina. Devuelve la función para dejar de seguirlo. */
  seguir(id: string, cb: (t: Trabajo) => void): () => void;
  /** Carpeta pública del motor web de Godot (null si no está configurado). */
  motor(): string | null;
  /** URL temporal (1 hora) para ver o descargar un archivo del juego. */
  url(ruta: string): Promise<string>;
  juegos(): Promise<Entrada[]>;
  proyecto(id: string): Promise<Proyecto>;
  /** Chispa propone un cambio (gratis): resumen, coste y si hay algo que aún no sabe hacer. */
  proponer(proyectoId: string, instruccion: string): Promise<Propuesta>;
  /** Niveles de la versión actual para el editor manual (null si la versión es antigua). */
  nivelesJuego(p: Proyecto): Promise<NivelesJuego | null>;
  /** Propuesta sin IA desde el editor manual: niveles dibujados a mano, textos o historia. */
  planManual(proyectoId: string, operaciones: Record<string, unknown>[]): Promise<Propuesta>;
  /** Aplica la propuesta: cobra exactamente su coste y encola el cambio. */
  aplicar(planId: string): Promise<{ job_id: string; credits: number }>;
  /** Vuelve a una versión anterior (gratis). */
  volver(proyectoId: string, version: number): Promise<{ job_id: string }>;
  /** Lo que cuesta que Chispa programe un cambio nuevo (agente programador). */
  precioPrograma(): Promise<number>;
  /** Chispa programa lo que el taller no sabe hacer: código revisado, compilado y probado por bots. */
  programar(proyectoId: string, instruccion: string): Promise<{ job_id: string; credits: number }>;
  /** Sube tu dibujo (o la foto de tu mascota o juguete) y la IA lo revisa para usarlo de protagonista. */
  revisarDibujo(proyectoId: string, imagen: Blob): Promise<{ ok: boolean; descripcion?: string; motivo?: string }>;
}

/** Servidor real (Supabase). */
export function supaJuegos(con: Conexion): ApiJuegos {
  const api: ApiJuegos = {
    async encargar(idea: string, previaId?: string) {
      const { data, error } = await con.sb.functions.invoke("create-game", { body: previaId ? { idea, preview_id: previaId } : { idea } });
      if (error) {
        let msg = "No se pudo encargar el juego.";
        if (error instanceof FunctionsHttpError) {
          try {
            msg = ((await error.context.json()) as { message?: string }).message ?? msg;
          } catch {
            /* respuesta sin JSON */
          }
        }
        throw new ErrorApp(msg);
      }
      return data as { job_id: string; credits: number };
    },

    async vistaPrevia(idea: string) {
      const { data, error } = await con.sb.functions.invoke("create-game", { body: { idea, preview: true } });
      if (error) {
        let msg = "No se pudo pedir la vista previa.";
        if (error instanceof FunctionsHttpError) {
          try {
            msg = ((await error.context.json()) as { message?: string }).message ?? msg;
          } catch {
            /* respuesta sin JSON */
          }
        }
        throw new ErrorApp(msg);
      }
      return data as { job_id: string };
    },

    async trabajos() {
      const { data, error } = await con.sb.from("jobs").select(COLUMNAS).eq("kind", "game")
        .order("created_at", { ascending: false }).limit(30);
      if (error) throw new ErrorApp("No se pudieron cargar tus juegos.");
      return (data as unknown as FilaTrabajo[]).map(aTrabajo);
    },

    seguir(id: string, cb: (t: Trabajo) => void) {
      let vivo = true;
      const leer = async () => {
        const { data } = await con.sb.from("jobs").select(COLUMNAS).eq("id", id).maybeSingle();
        if (!vivo || !data) return;
        const t = aTrabajo(data as unknown as FilaTrabajo);
        cb(t);
        if (t.status === "done" || t.status === "failed") parar();
      };
      // Tiempo real si está activado en Supabase; la consulta periódica es la red de seguridad.
      const canal = con.sb.channel("trabajo-" + id)
        .on("postgres_changes", { event: "UPDATE", schema: "public", table: "jobs", filter: `id=eq.${id}` }, () => void leer())
        .subscribe();
      const reloj = window.setInterval(() => void leer(), 4000);
      void leer();
      const parar = () => {
        vivo = false;
        window.clearInterval(reloj);
        void con.sb.removeChannel(canal);
      };
      return parar;
    },

    motor() {
      const m = import.meta.env.VITE_MOTOR_URL as string | undefined;
      return m && !m.includes("TU_REF") ? m : null;
    },

    async url(ruta: string) {
      const { data, error } = await con.sb.storage.from("juegos").createSignedUrl(ruta, 3600);
      if (error || !data) throw new ErrorApp("No se pudo abrir el archivo.");
      return data.signedUrl;
    },

    async juegos(): Promise<Entrada[]> {
      const [{ data: ps, error }, { data: js }] = await Promise.all([
        con.sb.from("projects").select("id,title,version,files,updated_at,genero:spec->>genero,giros:spec->giros").order("updated_at", { ascending: false }).limit(50),
        con.sb.from("jobs").select(COLUMNAS).in("kind", ["game", "game_change", "game_restore", "game_marketing", "game_publish", "game_mod", "game_ios"])
          .in("status", ["queued", "running", "failed"]).order("created_at", { ascending: false }).limit(20),
      ]);
      if (error) throw new ErrorApp("No se pudieron cargar tus juegos.");
      const trabajos = ((js ?? []) as unknown as FilaTrabajo[]).map(aTrabajo);
      const ocupados = new Set(trabajos.filter((t) => t.status !== "failed" && t.project_id).map((t) => t.project_id));
      const encargos: Entrada[] = trabajos.filter((t) => t.kind === "game" && !t.project_id)
        .map((t) => ({ tipo: "encargo", trabajo: t }));
      const proyectos: Entrada[] = ((ps ?? []) as { id: string; title: string; version: number; files: Resultado | null; updated_at: string; genero: string | null; giros: string[] | null }[])
        .map((p) => ({ tipo: "proyecto", id: p.id, titulo: p.title, version: p.version, icono: p.files?.icono, fecha: p.updated_at, ocupado: ocupados.has(p.id),
          genero: p.genero ?? undefined, giros: Array.isArray(p.giros) ? p.giros : [], portada: p.files?.capturas?.[2] ?? p.files?.capturas?.[0] }));
      return [...encargos, ...proyectos];
    },

    async proyecto(id: string): Promise<Proyecto> {
      const [{ data: p, error }, { data: vs }, { data: js }] = await Promise.all([
        con.sb.from("projects").select("id,title,version,files,updated_at,play,admob,ios,spec->niveles,spec->>genero,spec->funciones,spec->>publico,spec->prueba_ab,spec->giros,spec->originalidad").eq("id", id).maybeSingle(),
        con.sb.from("project_versions").select("version,prompt,created_at,files").eq("project_id", id).order("version"),
        con.sb.from("jobs").select(COLUMNAS).eq("project_id", id).in("status", ["queued", "running"]).limit(1),
      ]);
      if (error || !p) throw new ErrorApp("Ese juego no existe.");
      const activo = ((js ?? []) as unknown as FilaTrabajo[]).map(aTrabajo)[0] ?? null;
      return { id: p.id, titulo: p.title, version: p.version, files: p.files, updated_at: p.updated_at,
        versiones: (vs ?? []) as Version[], activo, play: (p.play as EstadoPlay | null) ?? null,
        niveles: Array.isArray((p as { niveles?: unknown }).niveles) ? (p as { niveles: string[] }).niveles : [],
        genero: String((p as { genero?: unknown }).genero ?? "plataformas"),
        admob: ((p as { admob?: AdmobIds | null }).admob) ?? null,
        funciones: ((p as { funciones?: Proyecto["funciones"] }).funciones) ?? {},
        publico: (p as { publico?: string }).publico === "infantil" ? "infantil" : "todos",
        prueba_ab: ((p as { prueba_ab?: Proyecto["prueba_ab"] }).prueba_ab) ?? null,
        giros: Array.isArray((p as { giros?: unknown }).giros) ? (p as { giros: string[] }).giros : [],
        originalidad: typeof (p as { originalidad?: unknown }).originalidad === "number" ? (p as { originalidad: number }).originalidad : null,
        ios: ((p as { ios?: Proyecto["ios"] }).ios) ?? null };
    },

    proponer(proyectoId: string, instruccion: string) {
      return con.invocar<Propuesta>("plan-change", { project_id: proyectoId, instruccion }, "Chispa no ha podido pensar el cambio.");
    },

    async nivelesJuego(p: Proyecto) {
      const ruta = p.files?.niveles;
      if (!ruta) return null;
      const r = await fetch(await api.url(ruta));
      if (!r.ok) throw new ErrorApp("No se pudieron abrir los niveles.");
      return (await r.json()) as NivelesJuego;
    },

    planManual(proyectoId: string, operaciones: Record<string, unknown>[]) {
      return con.invocar<Propuesta>("plan-change", { project_id: proyectoId, operaciones }, "No se pudieron guardar tus cambios.");
    },

    aplicar(planId: string) {
      return con.invocar<{ job_id: string; credits: number }>("apply-change", { plan_id: planId }, "No se pudo aplicar el cambio.");
    },

    volver(proyectoId: string, version: number) {
      return con.invocar<{ job_id: string }>("restore-version", { project_id: proyectoId, version }, "No se pudo volver a esa versión.");
    },

    async precioPrograma() {
      const { data } = await con.sb.from("pricing").select("credits").eq("kind", "game_mod").maybeSingle();
      return (data?.credits as number | undefined) ?? 30;
    },

    programar(proyectoId: string, instruccion: string) {
      return con.invocar<{ job_id: string; credits: number }>("program-change", { project_id: proyectoId, instruccion }, "Chispa no ha podido ponerse a programarlo.");
    },

    async revisarDibujo(proyectoId: string, imagen: Blob) {
      const { data } = await con.sb.auth.getSession();
      const uid = data.session?.user.id;
      if (!uid) throw new ErrorApp("Vuelve a iniciar sesión.");
      const { error } = await con.sb.storage.from("referencias").upload(`${uid}/${proyectoId}/heroe.png`, imagen,
        { upsert: true, contentType: imagen.type || "image/png" });
      if (error) throw new ErrorApp("No se pudo subir la imagen. Usa un PNG o JPG de menos de 4 MB.");
      return con.invocar<{ ok: boolean; descripcion?: string; motivo?: string }>("heroe-dibujo", { project_id: proyectoId },
        "No se pudo revisar la imagen.");
    },
  };
  return api;
}
