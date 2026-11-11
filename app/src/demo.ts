// Modo demostración: sin servidor. Reproduce los pasos reales de la fábrica con sus tiempos
// y termina con un juego de ejemplo fabricado de verdad por la cadena (sus capturas e icono).

import type { PuestoReto, RetoSemana } from "./api";
import type { PerfilCreador } from "./creador";
import type { Opiniones } from "./api";
import type { AdmobIds, EstadoCharla, EventoJuego, Gancho, InformeAb, Invitacion, Resena, FilaLiga, Ingresos, FilaMarcador, JuegoEscaparate, Backend, CuentaApple, EstadoTienda, ModoYoutube, CampanaLz, CuentaPlay, Entrada, MiCampanaLz, PanelLz, PruebaLz, EstadoPlay, Evento, Marketing, Propuesta, Proyecto, Publicar, Resultado, Trabajo } from "./api";
import guiaPlay from "./demo/guia_play.json";
import nivelesDemo from "./demo/niveles.json";
import type { NivelesJuego } from "./editor";
import type { FilaInforme } from "./aprendizaje";
import { ErrorApp, mensajeEvento, mensajeInvitacion, validarAdmob } from "./api";
import { codigoValido, limpiarCodigo, validarPremio, type Canje, type PremioReal } from "./premio";
import { mensajeRegalo, validarRegalo, type RegaloJuego } from "./regalo";
import { mensajeClase, type Clase } from "./clase";
import c1 from "./demo/1_titulo.jpg";
import c2 from "./demo/2_niveles.jpg";
import c3 from "./demo/3_juego.jpg";
import c4 from "./demo/4_juego.jpg";
import c5 from "./demo/5_resultado.jpg";
import icono from "./demo/icono.png";
import mkReto from "./demo/mk_reto.mp4";
import mkCuriosidad from "./demo/mk_curiosidad.mp4";
import mkHumor from "./demo/mk_humor.mp4";
import pReto from "./demo/mk_reto.jpg";
import pCuriosidad from "./demo/mk_curiosidad.jpg";
import pHumor from "./demo/mk_humor.jpg";

const ARCHIVOS: Record<string, string> = {
  "demo/capturas/1_titulo.jpg": c1,
  "demo/capturas/2_niveles.jpg": c2,
  "demo/capturas/3_juego.jpg": c3,
  "demo/capturas/4_juego.jpg": c4,
  "demo/capturas/5_resultado.jpg": c5,
  "demo/icono.png": icono,
  "demo/clip_vertical.mp4": mkReto,
  "demo/marketing/reto.mp4": mkReto,
  "demo/marketing/curiosidad.mp4": mkCuriosidad,
  "demo/marketing/humor.mp4": mkHumor,
  "demo/marketing/reto.jpg": pReto,
  "demo/marketing/curiosidad.jpg": pCuriosidad,
  "demo/marketing/humor.jpg": pHumor,
};

// Lo que devolvió de verdad el estudio de marketing (fabrica/marketing) para el juego de ejemplo.
const TEXTO_ES = "Salta tejados, caza estrellas. Juega con Mishi gratis en Android.";
const TEXTO_EN = "Play as Mishi for free on Android. How far can you get?";
const TAGS_ES = "#plataformas #juegosmoviles #indiegame #gamedev";
const TAGS_EN = "#platformer #indiegame #mobilegame #gamedev";
const MARKETING_DEMO: Marketing = {
  videos: [
    { estilo: "reto", gancho: "¿Llegas al nivel 3?", mp4: "demo/marketing/reto.mp4", portada: "demo/marketing/reto.jpg" },
    { estilo: "curiosidad", gancho: "Mira lo que pasa con Rey Rata", mp4: "demo/marketing/curiosidad.mp4", portada: "demo/marketing/curiosidad.jpg" },
    { estilo: "humor", gancho: "Mishi no tiene un buen día", mp4: "demo/marketing/humor.mp4", portada: "demo/marketing/humor.jpg" },
  ],
  publicacion: {
    es: { titulo: "Bigotes Veloces: ¿llegas al final?", texto: TEXTO_ES, hashtags: TAGS_ES.split(" ") },
    en: { titulo: "Bigotes Veloces: can you beat it?", texto: TEXTO_EN, hashtags: TAGS_EN.split(" ") },
  },
  redes: {
    es: { tiktok: `${TEXTO_ES}\n\n${TAGS_ES}`, reels: `${TEXTO_ES}\n\n${TAGS_ES}`, shorts_titulo: "Bigotes Veloces: ¿llegas al final? #Shorts",
      shorts_descripcion: `${TEXTO_ES}\n\n${TAGS_ES} #Shorts` },
    en: { tiktok: `${TEXTO_EN}\n\n${TAGS_EN}`, reels: `${TEXTO_EN}\n\n${TAGS_EN}`, shorts_titulo: "Bigotes Veloces: can you beat it? #Shorts",
      shorts_descripcion: `${TEXTO_EN}\n\n${TAGS_EN} #Shorts` },
  },
  voz: "simulado",
  zip: "demo/marketing/marketing.zip",
};

const GUION_PREPARAR: [number, Evento][] = [
  [0.5, { paso: "preparar", estado: "inicio", mensaje: "Abriendo tu juego..." }],
  [0.8, { paso: "ficha", estado: "inicio", mensaje: "Preparando icono, gráfico destacado, capturas y textos a la medida de Google..." }],
  [1.6, { paso: "ficha", estado: "ok", mensaje: "Ficha lista y comprobada" }],
  [0.4, { paso: "aab", estado: "inicio", mensaje: "Compilando el .aab firmado para Android 16 (API 36)..." }],
  [2.6, { paso: "aab", estado: "ok", mensaje: "Juego compilado y firmado con tu llave de subida" }],
  [0.6, { paso: "guia", estado: "ok", mensaje: "Guía de Play Console y política de privacidad listas" }],
];

const GUION_SUBIR: [number, Evento][] = [
  [0.5, { paso: "preparar", estado: "inicio", mensaje: "Abriendo tu juego..." }],
  [1.2, { paso: "aab", estado: "ok", mensaje: "Juego compilado y firmado" }],
  [0.4, { paso: "subida_play", estado: "inicio", mensaje: "Subiendo a Google Play..." }],
  [1.6, { paso: "subida_play", estado: "inicio", mensaje: "Poniendo textos, icono, gráfico destacado y capturas..." }],
  [1.2, { paso: "subida_play", estado: "ok", mensaje: "En Google Play" }],
];

const GUION_MARKETING: [number, Evento][] = [
  [0.5, { paso: "preparar", estado: "inicio", mensaje: "Abriendo tu juego..." }],
  [0.8, { paso: "grabar", estado: "inicio", mensaje: "El bot está jugando para grabar los mejores momentos..." }],
  [3.0, { paso: "grabar", estado: "ok", mensaje: "Partida grabada: elijo los 15 s con más acción (el jefe y la victoria)" }],
  [0.4, { paso: "guion", estado: "inicio", mensaje: "Escribiendo 3 guiones: reto, curiosidad y humor..." }],
  [2.2, { paso: "guion", estado: "ok", mensaje: "Guiones listos: ¿Llegas al nivel 3? / Mira lo que pasa con Rey Rata / Mishi no tiene un buen día" }],
  [0.4, { paso: "montaje", estado: "inicio", mensaje: "Montando vídeos: subtítulos, voz en off, música y cartel final..." }],
  [3.4, { paso: "montaje", estado: "ok", mensaje: "3 vídeos listos" }],
  [0.6, { paso: "subida", estado: "ok", mensaje: "Vídeos guardados" }],
];

const GUION: [number, Evento][] = [
  [0.4, { paso: "diseno", estado: "inicio", mensaje: "Pensando tu juego..." }],
  [2.6, { paso: "diseno", estado: "ok", mensaje: "«Bigotes Veloces»: Mishi contra 3 tipos de enemigo", titulo: "Bigotes Veloces" }],
  [0.6, { paso: "proyecto", estado: "ok", mensaje: "Proyecto creado" }],
  [0.5, { paso: "niveles", estado: "inicio", mensaje: "Construyendo 3 niveles..." }],
  [2.2, { paso: "niveles", estado: "ok", mensaje: "Niveles listos (1 rehecho por el analizador)" }],
  [1.2, { paso: "boceto", estado: "ok", mensaje: "¡Ya puedes jugar un boceto mientras dibujo el arte!", boceto: "demo/web/boceto.pck" }],
  [0.4, { paso: "arte", estado: "inicio", mensaje: "Dibujando personajes, objetos y escenario..." }],
  [4.5, { paso: "arte", estado: "ok", mensaje: "Arte listo: 39 imágenes (1 rehecha por el control de calidad)" }],
  [0.5, { paso: "icono", estado: "ok", mensaje: "Icono creado" }],
  [0.4, { paso: "validacion", estado: "inicio", mensaje: "Probando el juego con bots..." }],
  [2.8, { paso: "validacion", estado: "aviso", mensaje: "Rehaciendo niveles que el bot no supera: [3]" }],
  [2.0, { paso: "validacion", estado: "ok", mensaje: "Los bots han superado todos los niveles" }],
  [0.4, { paso: "apk", estado: "inicio", mensaje: "Empaquetando para Android..." }],
  [2.4, { paso: "apk", estado: "ok", mensaje: "APK lista" }],
  [0.4, { paso: "ficha", estado: "inicio", mensaje: "Preparando la ficha para Google Play..." }],
  [1.2, { paso: "ficha", estado: "ok", mensaje: "Ficha de la tienda lista: icono, gráfico destacado, capturas y textos" }],
  [0.4, { paso: "clip", estado: "inicio", mensaje: "Grabando un clip para TikTok, Shorts y Reels..." }],
  [1.4, { paso: "clip", estado: "ok", mensaje: "Clip vertical listo: 15 s jugados por el bot" }],
  [0.4, { paso: "subida", estado: "inicio", mensaje: "Guardando tu juego en la nube..." }],
  [1.0, { paso: "fin", estado: "ok", mensaje: "«Bigotes Veloces» está listo" }],
];

const GUION_CAMBIO: [number, Evento][] = [
  [0.5, { paso: "preparar", estado: "inicio", mensaje: "Abriendo tu juego..." }],
  [1.2, { paso: "arte", estado: "inicio", mensaje: "Rehaciendo solo lo que cambia..." }],
  [3.0, { paso: "arte", estado: "ok", mensaje: "Listo lo nuevo" }],
  [0.4, { paso: "validacion", estado: "inicio", mensaje: "Probando la nueva versión con bots..." }],
  [2.4, { paso: "validacion", estado: "ok", mensaje: "Los bots han superado todos los niveles" }],
  [0.4, { paso: "apk", estado: "inicio", mensaje: "Empaquetando la nueva versión..." }],
  [1.8, { paso: "apk", estado: "ok", mensaje: "APK lista" }],
  [0.6, { paso: "subida", estado: "ok", mensaje: "Juego guardado" }],
];

const GUION_PROGRAMA: [number, Evento][] = [
  [0.5, { paso: "preparar", estado: "inicio", mensaje: "Abriendo tu juego..." }],
  [0.8, { paso: "programar", estado: "inicio", mensaje: "Chispa está programando el cambio..." }],
  [3.2, { paso: "programar", estado: "inicio", mensaje: "Revisando que el código sea seguro y compilándolo..." }],
  [1.6, { paso: "programar", estado: "ok", mensaje: "Programado y probado sin errores" }],
  [0.4, { paso: "validacion", estado: "inicio", mensaje: "Probando la nueva versión con bots..." }],
  [2.4, { paso: "validacion", estado: "ok", mensaje: "Los bots han superado todos los niveles" }],
  [0.6, { paso: "subida", estado: "ok", mensaje: "Juego guardado" }],
];

// Mismos precios que fabrica/director/precios_cambios.json (el servidor real los calcula él).
const PRECIOS: Record<string, number> = { base: 3, textos: 1, ajustes: 3, redibujar: 12, paleta: 40, estilo: 45,
  anadir_enemigo: 15, quitar_enemigo: 3, anadir_nivel: 6, quitar_nivel: 1, rehacer_nivel: 5,
  poderes: 6, disparo: 4, jefe: 18, jefe_quitar: 2, musica: 5, extras: 6, genero: 10, vista: 3, historia: 4 };

const CLAVE = "orquestador-demo-v2";

interface ProyectoDemo {
  id: string;
  funciones?: Proyecto["funciones"];
  publico?: Proyecto["publico"];
  prueba_ab?: Proyecto["prueba_ab"];
  giros?: string[];
  titulo: string;
  version: number;
  files: Resultado;
  updated_at: string;
  versiones: { version: number; prompt: string; created_at: string; files: Resultado; titulo: string }[];
  play?: EstadoPlay | null;
  admob?: AdmobIds | null;
  ios?: { bundle?: string; build?: number; estado?: string; subido_en?: number } | null;
}

interface Guardado {
  email: string | null;
  tuercas: number;
  trabajos: Trabajo[];
  proyectos: ProyectoDemo[];
  planes: Record<string, { proyecto: string; instruccion: string; coste: number; titulo?: string; mapas?: Record<string, unknown>[] }>;
  niveles?: Record<string, string[][]>;
  cuentaPlay?: CuentaPlay;
  lz?: LzDemo;
  premium?: boolean;
  plan?: "taller" | "pro";
  youtube?: string;
  apple?: CuentaApple;
  escaparate?: Record<string, { autor: string; jugadas: number; desde: string }>;
  megusta?: string[];
  marcadoresOcultos?: number[];
  charla?: Record<string, { mensajes: number; activa: boolean }>;
  eventos?: Record<string, EventoJuego[]>;
  premios?: Record<string, PremioReal>;
  canjes?: Record<string, string>;
  regalos?: Record<string, RegaloJuego>;
  clases?: Record<string, Clase[]>;
  respuestas?: Record<string, Record<string, { texto: string; en: string }>>;
  invitadoCon?: string;
  /** Reto de la semana: el juego presentado. */
  reto?: string;
}

// ---------------------------------------------------------------- Escaparate (demo)

const hace_ = (h: number) => new Date(Date.now() - h * 3600000).toISOString();
const ESCAPARATE_DEMO: JuegoEscaparate[] = [
  { project_id: "esc-1", titulo: "Cohete Pepinillo", genero: "runner", resumen: "Un pepinillo espacial esquiva meteoritos.", autor: "Lucía",
    version: 4, jugadas: 1280, megusta: 211, remixes: 14, publicado_en: hace_(70) },
  { project_id: "esc-2", titulo: "Granja Zombi", genero: "torres", resumen: "Defiende las zanahorias con torres.", autor: "Marcos",
    version: 2, jugadas: 640, megusta: 98, remixes: 6, publicado_en: hace_(30) },
  { project_id: "esc-3", titulo: "Sushi Crush", genero: "puzle", resumen: "Combina 3 piezas de sushi.", autor: "Aiko",
    version: 3, jugadas: 905, megusta: 120, remixes: 9, publicado_en: hace_(52) },
  { project_id: "esc-4", titulo: "Moto Neón", genero: "carreras", resumen: "Carreras nocturnas con turbo.", autor: "Dani",
    version: 1, jugadas: 77, megusta: 12, remixes: 0, publicado_en: hace_(3) },
  { project_id: "esc-5", titulo: "Mago de Bolsillo", genero: "horda", resumen: "Hordas de slimes y hechizos.", autor: "Sara",
    version: 5, jugadas: 2210, megusta: 340, remixes: 31, publicado_en: hace_(150) },
  { project_id: "esc-7", titulo: "Vía Neón", genero: "corredor", resumen: "Esquiva trenes en tres carriles.", autor: "Noa",
    version: 2, jugadas: 510, megusta: 87, remixes: 5, publicado_en: hace_(20) },
  { project_id: "esc-8", titulo: "Invasores de Gominola", genero: "naves", resumen: "Tu nave contra marcianos de colores.", autor: "Leo",
    version: 3, jugadas: 330, megusta: 61, remixes: 3, publicado_en: hace_(9) },
  { project_id: "esc-6", titulo: "Pluma de Papel", genero: "volador", resumen: "Vuela entre columnas de un toque.", autor: "Iker",
    version: 1, jugadas: 15, megusta: 4, remixes: 0, publicado_en: hace_(1) },
];

// ---------------------------------------------------------------- Lanzadera (demo)

interface LzDemo {
  ocultas?: string[];
  dia: number;
  puntos: number;
  pruebas: (Omit<PruebaLz, "hecho_hoy" | "objetivo"> & { ultimo: number | null; unido: number })[];
  propias: { id: string; project_id: string; titulo: string; enlace_grupo: string; abierta: number; cerrada: boolean }[];
}

const OTROS_LZ: Omit<CampanaLz, "created_at">[] = [
  { campana: "lz-1", titulo: "Cohete Pepinillo", nota: "Runner espacial de un toque. ¡Dime si el nivel 3 es justo!", enlace_grupo: "https://groups.google.com/g/cohete-pepinillo", enlace_prueba: "https://play.google.com/apps/testing/com.lucia.cohetepepinillo", probadores: 9, faltan: 3, premium: true },
  { campana: "lz-2", titulo: "Granja Zombi", nota: "Defiende las zanahorias con torres.", enlace_grupo: "https://groups.google.com/g/granja-zombi", enlace_prueba: "https://play.google.com/apps/testing/com.marcos.granjazombi", probadores: 4, faltan: 8, premium: false },
  { campana: "lz-3", titulo: "Sushi Crush", nota: "Puzle de combinar 3 con piezas de sushi.", enlace_grupo: "https://groups.google.com/g/sushi-crush", enlace_prueba: "https://play.google.com/apps/testing/com.aiko.sushicrush", probadores: 11, faltan: 1, premium: false },
  { campana: "lz-4", titulo: "Moto Neón", nota: "Carreras de noche con turbo.", enlace_grupo: "https://groups.google.com/g/moto-neon", enlace_prueba: "https://play.google.com/apps/testing/com.dani.motoneon", probadores: 2, faltan: 10, premium: false },
  { campana: "lz-5", titulo: "Mago de Bolsillo", nota: "Hordas de slimes y hechizos que suben de nivel.", enlace_grupo: "https://groups.google.com/g/mago-bolsillo", enlace_prueba: "https://play.google.com/apps/testing/com.sara.magobolsillo", probadores: 6, faltan: 6, premium: false },
];

const OPINIONES_DEMO = ["Me encanta el personaje, pero el nivel 3 se me hace largo.", "La música engancha. El jefe es muy difícil a la primera.",
  "Va fluido en mi móvil viejo. Echo de menos más niveles.", "Muy bonito. Al principio no entendí que había que saltar sobre los enemigos."];

/** Probadores simulados de una campaña propia: 8 se unen cada día; 1 de cada 4 abandona al tercer día. */
function probadoresDemo(dias: number): MiCampanaLz["probadores"] {
  const out: MiCampanaLz["probadores"] = [];
  for (let k = 0; k < 16; k++) {
    const entra = Math.floor(k / 8);
    if (entra > dias) break;
    const abandona = k % 4 === 3;
    const d = Math.min(14, Math.max(0, dias - entra), abandona ? 2 : 99);
    out.push({ n: k + 1, dias: d, estado: abandona && dias - entra > 3 ? "abandonado" : d >= 14 ? "completado" : "activo" });
  }
  return out;
}

function cargar(): Guardado {
  try {
    const t = localStorage.getItem(CLAVE);
    if (t) return JSON.parse(t) as Guardado;
  } catch {
    /* sin almacenamiento: empezamos de cero */
  }
  return { email: null, tuercas: 120, trabajos: [], proyectos: [], planes: {} };
}

export class Demo implements Backend {
  readonly demo = true;
  private s: Guardado = cargar();
  private oyentes = new Map<string, (t: Trabajo) => void>();
  private enMarcha = new Set<string>();
  private youtubePedido: ModoYoutube = "no";

  private guardar() {
    try {
      localStorage.setItem(CLAVE, JSON.stringify(this.s));
    } catch {
      /* da igual en una demostración */
    }
  }

  async usuario() {
    return this.s.email ? { email: this.s.email } : null;
  }
  async pedirCodigo(email: string) {
    if (!/^\S+@\S+\.\S+$/.test(email)) throw new ErrorApp("Ese correo no parece válido.");
    await espera(500);
  }
  async verificarCodigo(email: string, codigo: string) {
    await espera(400);
    if (!/^\d{6}$/.test(codigo)) throw new ErrorApp("El código tiene 6 cifras (en la demo vale cualquiera).");
    this.s.email = email;
    this.guardar();
  }
  async entrarConGoogle(): Promise<"dentro" | "redirigiendo" | "cancelado"> {
    await espera(600);
    this.s.email = "tu.cuenta@gmail.com";
    this.guardar();
    return "dentro";
  }
  async salir() {
    this.s.email = null;
    this.guardar();
  }
  async escaparate(orden: "top" | "nuevos" | "semana") {
    await espera(350);
    const propios = this.s.proyectos.filter((p) => this.s.escaparate?.[p.id]).map((p) => this.fichaPropia(p));
    const otros = ESCAPARATE_DEMO.filter((j) => !(this.s.lz?.ocultas ?? []).includes(j.project_id))
      .map((j) => ({ ...j, megusta: j.megusta + (this.s.megusta?.includes(j.project_id) ? 1 : 0) }));
    const todo = [...propios, ...otros];
    if (orden === "semana") return todo.sort((a, b) => b.megusta * 10 + Math.sqrt(b.jugadas) * 5 - (a.megusta * 10 + Math.sqrt(a.jugadas) * 5)).slice(0, 20);
    return orden === "nuevos" ? todo.sort((a, b) => b.publicado_en.localeCompare(a.publicado_en))
      : todo.sort((a, b) => b.megusta * 5 + b.jugadas - (a.megusta * 5 + a.jugadas));
  }

  private fichaPropia(p: ProyectoDemo): JuegoEscaparate {
    const e = this.s.escaparate![p.id];
    return { project_id: p.id, titulo: p.titulo, genero: "plataformas", resumen: "", autor: e.autor, version: p.version,
      jugadas: e.jugadas, megusta: 0, remixes: 0, publicado_en: e.desde };
  }

  async fichaEscaparate(proyectoId: string) {
    const p = this.s.proyectos.find((x) => x.id === proyectoId);
    if (p && this.s.escaparate?.[p.id]) return this.fichaPropia(p);
    return ESCAPARATE_DEMO.find((j) => j.project_id === proyectoId) ?? null;
  }

  async publicarEscaparate(proyectoId: string, autor: string) {
    await espera(1200);
    const p = this.s.proyectos.find((x) => x.id === proyectoId);
    if (!p) throw new ErrorApp("Ese juego no existe.");
    this.s.escaparate = { ...(this.s.escaparate ?? {}), [p.id]: { autor: autor.trim().slice(0, 40), jugadas: this.s.escaparate?.[p.id]?.jugadas ?? 0,
      desde: this.s.escaparate?.[p.id]?.desde ?? new Date().toISOString() } };
    this.guardar();
    return { url: `https://orquestador.github.io/jugar.html?j=${p.id}` };
  }

  async paqueteItch(proyectoId: string) {
    await espera(1500);
    const p = this.s.proyectos.find((x) => x.id === proyectoId);
    if (!p) throw new ErrorApp("Ese juego no existe.");
    return { url: "data:application/zip;base64,UEsFBgAAAAAAAAAAAAAAAAAAAAAAAA==", nombre: "juego-demo-html5.zip", mb: 44.6 };
  }

  async retirarEscaparate(proyectoId: string) {
    await espera(500);
    if (this.s.escaparate) delete this.s.escaparate[proyectoId];
    this.guardar();
  }

  async remix(proyectoId: string) {
    await espera(1400);
    const j = ESCAPARATE_DEMO.find((x) => x.project_id === proyectoId);
    if (!j) throw new ErrorApp(this.s.proyectos.some((p) => p.id === proyectoId) ? "Ese juego ya es tuyo: cámbialo en el taller." : "Ese juego ya no está en el escaparate.");
    const files: Resultado = { capturas: Object.keys(ARCHIVOS).filter((k) => k.includes("capturas")), icono: "demo/icono.png",
      web: "demo/web/index.pck", proyecto: "demo/remix_godot.zip" };
    const ahora = new Date().toISOString();
    const p: ProyectoDemo = { id: "p-remix-" + Date.now(), titulo: `${j.titulo} (remix)`, version: j.version, files, updated_at: ahora,
      versiones: [{ version: j.version, prompt: `Remix de «${j.titulo}»`, created_at: ahora, files, titulo: `${j.titulo} (remix)` }] };
    this.s.proyectos.unshift(p);
    this.guardar();
    return { project_id: p.id };
  }

  async meGusta(proyectoId: string) {
    await espera(200);
    const l = new Set(this.s.megusta ?? []);
    if (l.has(proyectoId)) l.delete(proyectoId); else l.add(proyectoId);
    this.s.megusta = [...l];
    this.guardar();
    const base = ESCAPARATE_DEMO.find((j) => j.project_id === proyectoId)?.megusta ?? 0;
    return base + (l.has(proyectoId) ? 1 : 0);
  }

  archivosEscaparate(_j: JuegoEscaparate) {
    return { icono: ARCHIVOS["demo/icono.png"], portada: ARCHIVOS["demo/capturas/3_juego.jpg"], pck: null };
  }

  async jugada(proyectoId: string) {
    const e = this.s.escaparate?.[proyectoId];
    if (e) { e.jugadas += 1; this.guardar(); }
  }

  async denunciar(que: { proyecto?: string; campana?: string }, motivo: string) {
    await espera(400);
    if (!motivo.trim()) throw new ErrorApp("Elige un motivo.");
    if (que.campana && this.s.lz) this.s.lz.ocultas = [...(this.s.lz.ocultas ?? []), que.campana];
    if (que.proyecto && ESCAPARATE_DEMO.some((j) => j.project_id === que.proyecto)) {
      this.lzEstado().ocultas = [...(this.s.lz?.ocultas ?? []), que.proyecto];
    }
    this.guardar();
  }

  async borrarCuenta() {
    await espera(900);
    if (this.s.trabajos.some((t) => t.status === "queued" || t.status === "running")) {
      throw new ErrorApp("Tienes algo fabricándose. Espera a que termine y vuelve a intentarlo.");
    }
    const premium = !!this.s.premium;
    try { localStorage.removeItem(CLAVE); } catch { /* sin almacenamiento */ }
    this.s = { email: null, tuercas: 120, trabajos: [], proyectos: [], planes: {} };
    return { premium_activo: premium };
  }
  async tuercas() {
    return this.s.tuercas;
  }
  async precioJuego() {
    return 80;
  }

  async borrarBoceto(_proyectoId: string): Promise<void> {
    throw new ErrorApp("En la demostración no hay bocetos guardados.");
  }

  async guardarBoceto(_previaId: string): Promise<{ project_id: string }> {
    throw new ErrorApp("En la demostración no se guardan bocetos.");
  }

  async vistaPrevia(idea: string) {
    if (idea.trim().length < 15) throw new ErrorApp("Describe tu juego con entre 15 y 600 caracteres.");
    const limpia = idea.trim().replace(/^\[[^\]]*\]\s*/, "");
    const t: Trabajo = {
      id: "demo-previa-" + Date.now(), kind: "game_preview", project_id: null, status: "done", created_at: new Date().toISOString(), idea: limpia,
      progress: [], error: null, refunded: false, titulo: null,
      result: { capturas: [], diseno: {
        titulo: "Bigotes Veloces", genero: "plataformas", resumen: `Un juego hecho a partir de tu idea: ${limpia.slice(0, 120)}`,
        heroe: { nombre: "Mishi", descripcion: "una gata ninja rápida y valiente" },
        enemigos: [{ nombre: "Rata Robot" }, { nombre: "Tejarón" }, { nombre: "Chispazo" }], jefe: null, niveles: new Array(3).fill(0),
        estilo: { descripcion: "pixel art nocturno de colores cálidos" },
      } } as unknown as Trabajo["result"],
    };
    this.s.trabajos.unshift(t);
    this.guardar();
    return { job_id: t.id };
  }

  async encargar(idea: string) {
    if (idea.trim().length < 15) throw new ErrorApp("Describe tu juego con entre 15 y 600 caracteres.");
    if (this.s.tuercas < 80) throw new ErrorApp("No tienes tuercas suficientes para un juego completo.");
    this.s.tuercas -= 80;
    const t: Trabajo = {
      id: "demo-" + Date.now(), kind: "game", project_id: null, status: "queued", created_at: new Date().toISOString(), idea: idea.trim().replace(/^\[(plantilla|gancho):[a-z0-9_:,]*\]\s*/, ""),
      progress: [], result: null, error: null, refunded: false, titulo: null,
    };
    this.s.trabajos.unshift(t);
    this.guardar();
    void this.fabricar(t.id);
    return { job_id: t.id, credits: this.s.tuercas };
  }

  private async fabricar(id: string) {
    if (this.enMarcha.has(id)) return;
    this.enMarcha.add(id);
    await espera(900);
    const t = this.s.trabajos.find((x) => x.id === id);
    if (!t) return;
    t.status = "running";
    for (const [seg, ev] of GUION) {
      await espera(seg * 1000);
      t.progress = [...t.progress, { ...ev, t: Date.now() / 1000 }];
      if (ev.titulo) t.titulo = ev.titulo;
      this.avisar(t);
    }
    t.status = "done";
    this.enMarcha.delete(id);
    t.result = {
      capturas: Object.keys(ARCHIVOS).filter((k) => k.includes("capturas")),
      icono: "demo/icono.png",
      apk: "demo/bigotes_veloces.apk",
      web: "demo/web/index.pck",
      ficha: "demo/ficha_google_play.zip",
      clip: "demo/clip_vertical.mp4",
      proyecto: "demo/bigotes_veloces_godot.zip",
    };
    const ahora = new Date().toISOString();
    const p: ProyectoDemo = { id: "p-" + t.id, titulo: t.titulo ?? "Bigotes Veloces", version: 1, files: t.result, updated_at: ahora,
      versiones: [{ version: 1, prompt: t.idea, created_at: ahora, files: t.result, titulo: t.titulo ?? "Bigotes Veloces" }] };
    this.s.proyectos.unshift(p);
    t.project_id = p.id;
    this.guardar();
    this.avisar(t);
  }

  async juegos(): Promise<Entrada[]> {
    const encargos: Entrada[] = this.s.trabajos.filter((t) => t.kind === "game" && !t.project_id)
      .map((t) => ({ tipo: "encargo", trabajo: structuredClone(t) }));
    const proyectos: Entrada[] = this.s.proyectos.map((p) => ({
      tipo: "proyecto", id: p.id, titulo: p.titulo, version: p.version, icono: p.files.icono, fecha: p.updated_at,
      genero: "plataformas", giros: p.giros ?? [], portada: p.files.capturas?.[2] ?? p.files.capturas?.[0],
      ocupado: this.s.trabajos.some((t) => t.project_id === p.id && (t.status === "queued" || t.status === "running")),
    }));
    return [...encargos, ...proyectos];
  }

  async proyecto(id: string): Promise<Proyecto> {
    const p = this.s.proyectos.find((x) => x.id === id);
    if (!p) throw new ErrorApp("Ese juego no existe.");
    const activo = this.s.trabajos.find((t) => t.project_id === id && t.kind !== "game" && (t.status === "queued" || t.status === "running"));
    return { ...structuredClone(p), activo: activo ? structuredClone(activo) : null, play: p.play ? structuredClone(p.play) : null,
      niveles: ["Tejado tranquilo", "Chimeneas", "Noche de luna"], originalidad: 91 };
  }

  async proponer(proyectoId: string, instruccion: string): Promise<Propuesta> {
    await espera(1100);
    const p = this.s.proyectos.find((x) => x.id === proyectoId);
    if (!p) throw new ErrorApp("Ese juego no existe.");
    const prop = planDemo(instruccion);
    if (prop.plan_id) {
      this.s.planes[prop.plan_id] = { proyecto: proyectoId, instruccion, coste: prop.coste, titulo: prop.nuevoTitulo };
      this.guardar();
    }
    const { nuevoTitulo: _ignorado, ...publico } = prop;
    return publico;
  }

  async nivelesJuego(p: Proyecto): Promise<NivelesJuego | null> {
    await espera(250);
    const guardados = this.s.niveles?.[p.id];
    const n = nivelesDemo as NivelesJuego;
    const k = p.niveles.length || n.mapas.length;
    return { ...n, nombres: n.nombres.slice(0, k), mapas: guardados ?? n.mapas.slice(0, k) };
  }

  async planManual(proyectoId: string, operaciones: Record<string, unknown>[]): Promise<Propuesta> {
    await espera(400);
    if (!operaciones.length) throw new ErrorApp("No hay cambios que guardar.");
    const coste = PRECIOS.base + operaciones.reduce((a, o) => a + (o.op === "mapa" ? 2 : o.op === "historia" ? 4 : 1), 0);
    const plan_id = "plan-" + Date.now();
    const niveles = operaciones.filter((o) => o.op === "mapa").map((o) => Number(o.indice) + 1);
    const gir = operaciones.find((o) => o.op === "giros");
    if (gir) {
      const costeG = PRECIOS.base + 3;
      this.s.planes[plan_id] = { proyecto: proyectoId, instruccion: "Giros", coste: costeG, mapas: operaciones };
      this.guardar();
      const lista = (gir.giros as string[]) ?? [];
      return { plan_id, resumen: lista.length ? `Pongo estos giros: ${lista.join(", ")}. Los bots probarán el juego con ellos antes de guardar.` : "Quito los giros: el juego vuelve a ser como antes.",
        pregunta: null, no_puedo: null, operaciones: ["giros"], coste: costeG };
    }
    const dib = operaciones.find((o) => o.op === "redibujar" && o.referencia);
    if (dib) {
      const costeD = PRECIOS.base + 12;
      this.s.planes[plan_id] = { proyecto: proyectoId, instruccion: "Tu dibujo como protagonista", coste: costeD, mapas: [] };
      this.guardar();
      return { plan_id, resumen: "Convierto tu dibujo en el protagonista, con el estilo del juego: lo redibujo en todas sus animaciones y cambio el icono.",
        pregunta: null, no_puedo: null, operaciones: ["redibujar"], coste: costeD };
    }
    const ab = operaciones.find((o) => o.op === "prueba_ab");
    if (ab) {
      const fin = Boolean(ab.ganadora) || ab.activo === false;
      const p = this.s.proyectos.find((x) => x.id === proyectoId);
      if (fin && !p?.prueba_ab) throw new ErrorApp("No hay ninguna prueba A/B en marcha.");
      if (!fin && p?.prueba_ab) throw new ErrorApp("Ya hay una prueba A/B en marcha: termínala antes de empezar otra.");
      const costeAb = PRECIOS.base + (fin ? 1 : 5);
      this.s.planes[plan_id] = { proyecto: proyectoId, instruccion: fin ? "Terminar la prueba A/B" : "Prueba A/B", coste: costeAb, mapas: operaciones };
      this.guardar();
      const hacia = ({ mas_facil: "más fácil", mas_dificil: "más difícil", distinto: "distinta" } as Record<string, string>)[String(ab.hacia)] ?? "distinta";
      const resumen = ab.ganadora === "b" ? "Me quedo con la versión B: pasa a ser el nivel de todos."
        : fin ? "Termino la prueba y se queda el nivel de siempre."
        : `Hago una versión B ${hacia} del nivel ${Number(ab.indice) + 1}. La mitad de los jugadores jugará la B y verás cuál superan más.`;
      return { plan_id, resumen, pregunta: null, no_puedo: null, operaciones: ["prueba_ab"], coste: costeAb };
    }
    const fun = operaciones.find((o) => o.op === "funciones");
    const coste2 = fun ? PRECIOS.base : coste;
    this.s.planes[plan_id] = { proyecto: proyectoId, instruccion: fun ? "Qué lleva el juego" : "Edición a mano", coste: coste2, mapas: operaciones };
    this.guardar();
    if (fun) {
      const cambios = Object.entries(fun).filter(([k]) => k !== "op")
        .map(([k, v]) => k === "publico" ? (v === "infantil" ? "lo dejo apto para niños" : "quito el modo niños") : `${v ? "pongo" : "quito"} ${k}`);
      return { plan_id, resumen: `Versión nueva: ${cambios.join(", ")}. No se redibuja nada.`, pregunta: null, no_puedo: null, operaciones: ["funciones"], coste: coste2 };
    }
    return { plan_id, resumen: `Cambios a mano: ${niveles.map((n) => `nivel ${n}`).join(", ")} dibujado a mano. Los bots probarán tus niveles antes de guardar.`,
      pregunta: null, no_puedo: null, operaciones: operaciones.map((o) => String(o.op)), coste };
  }

  async aplicar(planId: string) {
    const plan = this.s.planes[planId];
    if (!plan) throw new ErrorApp("Esa propuesta ya no existe. Pídesela otra vez a Chispa.");
    if (this.s.tuercas < plan.coste) throw new ErrorApp("No tienes tuercas suficientes para este cambio.");
    if (this.s.trabajos.some((t) => t.project_id === plan.proyecto && (t.status === "queued" || t.status === "running"))) {
      throw new ErrorApp("Ese juego ya se está fabricando. Espera a que termine.");
    }
    delete this.s.planes[planId];
    this.s.tuercas -= plan.coste;
    for (const o of plan.mapas ?? []) {
      if (o.op === "giros") {
        const pr = this.s.proyectos.find((x) => x.id === plan.proyecto);
        if (pr) pr.giros = (o.giros as string[]) ?? [];
        continue;
      }
      if (o.op === "prueba_ab") {
        const pr = this.s.proyectos.find((x) => x.id === plan.proyecto);
        if (pr) pr.prueba_ab = o.ganadora || o.activo === false ? null : { nivel: Number(o.indice), hacia: o.hacia as "mas_facil" };
        continue;
      }
      if (o.op === "funciones") {
        const pr = this.s.proyectos.find((x) => x.id === plan.proyecto);
        if (pr) {
          if (o.publico) pr.publico = o.publico as "todos" | "infantil";
          pr.funciones = { ...(pr.funciones ?? {}) };
          for (const k of ["tienda", "pase", "avisos", "nube", "online"] as const) if (k in o) pr.funciones[k] = Boolean(o[k]);
        }
        continue;
      }
      const actual = (await this.nivelesJuego({ id: plan.proyecto, niveles: [] } as unknown as Proyecto))!.mapas;
      actual[Number(o.indice)] = o.mapa as string[];
      this.s.niveles = { ...(this.s.niveles ?? {}), [plan.proyecto]: actual };
    }
    const t = this.nuevoCambio("game_change", plan.proyecto, plan.instruccion);
    void this.cambiar(t.id, plan.instruccion, plan.titulo);
    return { job_id: t.id, credits: this.s.tuercas };
  }

  async volver(proyectoId: string, version: number) {
    const p = this.s.proyectos.find((x) => x.id === proyectoId);
    if (!p || !p.versiones.some((v) => v.version === version)) throw new ErrorApp("Esa versión no existe.");
    const t = this.nuevoCambio("game_restore", proyectoId, `Volver a la versión ${version}`);
    void this.cambiar(t.id, `Volver a la versión ${version}`, p.versiones.find((v) => v.version === version)?.titulo);
    return { job_id: t.id };
  }

  async precioPrograma() {
    return 30;
  }

  async programar(proyectoId: string, instruccion: string) {
    const p = this.s.proyectos.find((x) => x.id === proyectoId);
    if (!p) throw new ErrorApp("Ese juego no existe.");
    const texto = instruccion.trim();
    if (texto.length < 8 || texto.length > 400) throw new ErrorApp("Cuéntalo en una frase (entre 8 y 400 caracteres).");
    if (this.s.tuercas < 30) throw new ErrorApp("No tienes tuercas suficientes.");
    if (this.s.trabajos.some((t) => t.project_id === proyectoId && (t.status === "queued" || t.status === "running"))) {
      throw new ErrorApp("Ese juego ya se está fabricando. Espera a que termine.");
    }
    this.s.tuercas -= 30;
    const t = this.nuevoCambio("game_mod", proyectoId, texto);
    void this.cambiar(t.id, texto, undefined, GUION_PROGRAMA);
    return { job_id: t.id, credits: this.s.tuercas };
  }

  private nuevoCambio(kind: string, proyecto: string, texto: string): Trabajo {
    const p = this.s.proyectos.find((x) => x.id === proyecto)!;
    const t: Trabajo = { id: "demo-c-" + Date.now(), kind, project_id: proyecto, status: "queued", created_at: new Date().toISOString(),
      idea: texto, progress: [], result: null, error: null, refunded: false, titulo: p.titulo };
    this.s.trabajos.unshift(t);
    this.guardar();
    return t;
  }

  async cuentaPlay(): Promise<CuentaPlay | null> {
    return this.s.cuentaPlay ?? null;
  }

  async guardarCuentaPlay(estudio: string, correo: string) {
    if (estudio.trim().length < 2) throw new ErrorApp("El nombre de estudio tiene que tener al menos 2 caracteres.");
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(correo.trim())) throw new ErrorApp("Ese correo no parece válido.");
    this.s.cuentaPlay = { estudio: estudio.trim(), correo: correo.trim().toLowerCase(), llave_huella: null };
    this.guardar();
    return { cuenta_servicio: "orquestador-publicador@orquestador.iam.gserviceaccount.com" };
  }

  async publicar(proyectoId: string, modo: "primer_aab" | "subir", pista: string) {
    const p = this.s.proyectos.find((x) => x.id === proyectoId);
    if (!p) throw new ErrorApp("Ese juego no existe.");
    if (!this.s.cuentaPlay) throw new ErrorApp("Antes pon tu nombre de estudio y tu correo de contacto.");
    if (modo === "subir" && !p.play?.paquete) throw new ErrorApp("Primero prepara la primera versión y súbela a mano a Play Console.");
    const t = this.nuevoCambio("game_publish", proyectoId, "Publicar en Google Play");
    t.idea = modo === "subir" ? `Subir a Google Play (${pista})` : "Preparar para Google Play";
    void this.hacerPublicar(t.id, modo, pista);
    return { job_id: t.id };
  }

  private async hacerPublicar(id: string, modo: string, pista: string) {
    if (this.enMarcha.has(id)) return;
    this.enMarcha.add(id);
    await espera(600);
    const t = this.s.trabajos.find((x) => x.id === id);
    if (!t) return;
    t.status = "running";
    const guion: [number, Evento][] = modo === "subir" ? GUION_SUBIR : GUION_PREPARAR;
    for (const [seg, ev] of guion) {
      await espera(seg * 1000);
      t.progress = [...t.progress, { ...ev, t: Date.now() / 1000 }];
      this.avisar(t);
    }
    const p = this.s.proyectos.find((x) => x.id === t.project_id)!;
    const cuenta = this.s.cuentaPlay!;
    const limpio = (x: string) => x.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "").replace(/[^a-z0-9]/g, "") || "juego";
    const paquete = p.play?.paquete ?? `com.${limpio(cuenta.estudio)}.${limpio(p.titulo)}`;
    const codigo = Math.max((p.play?.version_code ?? 0) + 1, p.version * 100);
    const guia = JSON.parse(JSON.stringify(guiaPlay).replaceAll("com.miestudio.bigotesveloces", paquete)
      .replaceAll("tu@correo.com", cuenta.correo)) as Publicar["guia"];
    const publicar: Publicar = { guia, privacidad_url: "https://ejemplo.supabase.co/storage/v1/object/public/legal/demo/privacidad.html",
      paquete, huella_llave: "3A:7F:C2:91:5D:0B:E4:18:66:AF:20:9C:41:D7:88:0E:5B:13:C9:72:FA:04:6E:B1:2D:98:A5:37:E0:4C:61:BB",
      version_code: codigo, aab: "demo/play/juego.aab" };
    if (modo === "subir") publicar.resultado = { version: codigo, pista, borrador: false, imagenes: 16 };
    p.play = { ...(p.play ?? {}), paquete, version_code: codigo, huella_llave: publicar.huella_llave,
      estado: modo === "subir" ? "subido" : "primer_aab", ...(modo === "subir" ? { pista } : {}) };
    p.files = { ...p.files, publicar };
    t.status = "done";
    this.enMarcha.delete(id);
    t.result = { capturas: [], publicar };
    t.progress = [...t.progress, { paso: "fin", estado: "ok", mensaje: modo === "subir" ? "Subido a Google Play" : "Listo para Google Play", t: Date.now() / 1000 }];
    this.guardar();
    this.avisar(t);
  }

  async guardarAdmob(proyectoId: string, ids: AdmobIds | null): Promise<AdmobIds | null> {
    await espera(300);
    const p = this.s.proyectos.find((x) => x.id === proyectoId);
    if (!p) throw new ErrorApp("Ese juego no existe.");
    if (ids) {
      const err = validarAdmob(ids);
      if (err) throw new ErrorApp(err);
    }
    p.admob = ids ? { app_id: ids.app_id.trim(), interstitial: ids.interstitial.trim(), rewarded: ids.rewarded.trim(),
      ...(ids.banner?.trim() ? { banner: ids.banner.trim() } : {}), ...(ids.app_open?.trim() ? { app_open: ids.app_open.trim() } : {}),
      ...(ids.perfil?.trim() ? { perfil: ids.perfil.trim() } : {}) } : null;
    this.guardar();
    return p.admob;
  }

  private lzEstado(): LzDemo {
    this.s.lz ??= { dia: 0, puntos: 0, pruebas: [], propias: [] };
    return this.s.lz;
  }

  async lzLista(): Promise<CampanaLz[]> {
    await espera(300);
    const lz = this.lzEstado();
    return OTROS_LZ.filter((c) => !lz.pruebas.some((p) => p.campana === c.campana) && !(lz.ocultas ?? []).includes(c.campana))
      .map((c) => ({ ...c, created_at: new Date(Date.now() - 86400000 * (c.probadores + 1)).toISOString() }));
  }

  async lzPruebas(): Promise<PruebaLz[]> {
    const lz = this.lzEstado();
    return lz.pruebas.map(({ ultimo, unido: _u, ...p }) => ({ ...p, hecho_hoy: ultimo === lz.dia, objetivo: 14 }));
  }

  async lzPanel(): Promise<PanelLz> {
    const lz = this.lzEstado();
    const probando = lz.pruebas.filter((p) => p.estado !== "abandonado").length;
    return {
      puntos: lz.puntos, premium: !!this.s.premium, probando, minimo_probando: 3, visible_si_pruebas: probando >= 3 || !!this.s.premium,
      campanas: lz.propias.filter((c) => !c.cerrada).map((c) => {
        const probadores = probandoVisible(probando) ? probadoresDemo(lz.dia - c.abierta) : [];
        const completados = probadores.filter((p) => p.estado === "completado").length;
        return {
          id: c.id, titulo: c.titulo, estado: completados >= 12 ? "lista" : "abierta", enlace_grupo: c.enlace_grupo,
          enlace_prueba: "https://play.google.com/apps/testing/com.demo.juego", project_id: c.project_id,
          activos: probadores.filter((p) => p.estado === "activo").length, completados,
          abandonos: probadores.filter((p) => p.estado === "abandonado").length, objetivo: 12, dias: 14, probadores,
          creada: new Date(Date.now() - (lz.dia - c.abierta) * 86400000).toISOString(),
          checkins: probadores.reduce((n, p) => n + p.dias, 0), nivel_medio: 4.5, nivel_max: 9,
          opiniones: OPINIONES_DEMO.slice(0, Math.min(OPINIONES_DEMO.length, lz.dia - c.abierta))
            .map((opinion, i) => ({ probador: i + 1, dia: `día ${i + 1}`, nivel: i + 2, opinion })).reverse(),
        };
      }),
    };
  }

  async lzPublicables() {
    return this.s.proyectos.filter((p) => p.play?.paquete && p.play.estado !== "primer_aab").map((p) => ({ id: p.id, titulo: p.titulo }));
  }

  async lzAbrir(proyectoId: string, enlaceGrupo: string, _nota: string): Promise<string> {
    await espera(400);
    const lz = this.lzEstado();
    const p = this.s.proyectos.find((x) => x.id === proyectoId);
    if (!p?.play?.paquete) throw new ErrorApp("Ese juego aún no está en Google Play. Súbelo primero a prueba cerrada desde «Mis juegos».");
    if (!/^https:\/\/groups\.google\.com\/g\/[A-Za-z0-9._-]{3,80}\/?$/.test(enlaceGrupo.trim())) {
      throw new ErrorApp("El enlace del grupo tiene que ser del tipo https://groups.google.com/g/nombre-del-grupo");
    }
    if (lz.propias.some((c) => c.project_id === proyectoId && !c.cerrada)) throw new ErrorApp("Ese juego ya tiene una campaña abierta.");
    const id = "mia-" + Date.now();
    lz.propias.push({ id, project_id: proyectoId, titulo: p.titulo, enlace_grupo: enlaceGrupo.trim(), abierta: lz.dia, cerrada: false });
    this.guardar();
    return id;
  }

  async lzUnirme(campana: string) {
    await espera(300);
    const lz = this.lzEstado();
    const c = OTROS_LZ.find((x) => x.campana === campana);
    if (!c) throw new ErrorApp("Esa campaña ya no está abierta.");
    if (lz.pruebas.filter((p) => p.estado === "activo").length >= 10) throw new ErrorApp("Ya estás probando 10 juegos. Termina alguno antes de unirte a otro.");
    lz.pruebas.push({ campana, titulo: c.titulo, enlace_grupo: c.enlace_grupo, enlace_prueba: c.enlace_prueba, estado: "activo", dias: 0, ultimo: null, unido: lz.dia });
    this.guardar();
  }

  async lzCheckin(campana: string, nivel: number, opinion: string) {
    await espera(300);
    const lz = this.lzEstado();
    const p = lz.pruebas.find((x) => x.campana === campana);
    if (!p) throw new ErrorApp("No estás en esa campaña.");
    if (p.estado === "abandonado") throw new ErrorApp("Esta prueba se dio por abandonada (2 días sin jugar).");
    if (p.ultimo === lz.dia) throw new ErrorApp("Hoy ya has hecho el check-in. ¡Vuelve mañana!");
    if (!Number.isInteger(nivel) || nivel < 1 || nivel > 999) throw new ErrorApp("Pon el número del nivel al que llegaste.");
    if (opinion.length > 500) throw new ErrorApp("La opinión es demasiado larga (máximo 500 caracteres).");
    p.dias += 1;
    p.ultimo = lz.dia;
    let completado = p.estado === "completado";
    if (p.estado === "activo") {
      lz.puntos += 1;
      if (p.dias >= 14) {
        p.estado = "completado";
        lz.puntos += 5;
        completado = true;
      }
    }
    this.guardar();
    return { dias: p.dias, completado, puntos: lz.puntos };
  }

  async lzCerrar(campana: string) {
    const c = this.lzEstado().propias.find((x) => x.id === campana);
    if (!c) throw new ErrorApp("Esa campaña ya no está abierta.");
    c.cerrada = true;
    this.guardar();
  }

  /** Solo en la demostración: pasar al día siguiente para ver cómo avanza todo. */
  async lzSiguienteDia() {
    const lz = this.lzEstado();
    lz.dia += 1;
    for (const p of lz.pruebas) {
      if (p.estado === "activo" && lz.dia - (p.ultimo ?? p.unido) > 2) {
        p.estado = "abandonado";
        lz.puntos -= 5;
      }
    }
    this.guardar();
  }

  /** Demo: datos de jugadores inventados, solo para juegos ya subidos a Google Play. */
  async clasificacion(proyectoId: string, nivel: number): Promise<FilaMarcador[]> {
    await espera(300);
    const p = this.s.proyectos.find((x) => x.id === proyectoId);
    if (!p || p.play?.estado !== "subido") return [];
    const nombres = ["Lucía_09", "ZorroRojo", "Pablete", "Nerea", "MrBigotes", "Iker 2014", "Ana.G", "Tito"];
    const ocultas = this.s.marcadoresOcultos ?? [];
    return nombres.map((alias, i) => {
      const id = (nivel + 1) * 100 + i;
      return { id, posicion: i + 1, alias, puntos: Math.round((4200 - i * 410 - nivel * 150) / 10) * 10, oculta: ocultas.includes(id) };
    });
  }

  async ocultarMarcador(id: number, oculta: boolean) {
    await espera(150);
    const lista = new Set(this.s.marcadoresOcultos ?? []);
    if (oculta) lista.add(id); else lista.delete(id);
    this.s.marcadoresOcultos = [...lista];
    this.guardar();
  }
  /** Demo: liga inventada para juegos de aldea ya subidos. */
  async liga(proyectoId: string): Promise<FilaLiga[]> {
    await espera(250);
    const p = this.s.proyectos.find((x) => x.id === proyectoId);
    if (!p || p.play?.estado !== "subido") return [];
    const ocultas = this.s.marcadoresOcultos ?? [];
    return ["ReyPirata", "Lucía_09", "Clanero", "MrBigotes", "Nerea", "Tito"].map((alias, i) => ({
      id: 900 + i, alias, trofeos: 620 - i * 85, ayto: i < 2 ? 3 : i < 4 ? 2 : 1, oculta: ocultas.includes(900 + i) }));
  }

  async ocultarLiga(id: number, oculta: boolean) {
    await this.ocultarMarcador(id, oculta);
  }

  /** Demo: 30 días inventados (con fin de semana más fuerte) para juegos ya subidos. */
  async ingresos(proyectoId: string): Promise<Ingresos> {
    await espera(250);
    const p = this.s.proyectos.find((x) => x.id === proyectoId);
    const vivo = p?.play?.estado === "subido";
    const hoy = new Date();
    const dias = Array.from({ length: 30 }, (_, i) => {
      const d = new Date(hoy.getTime() - (29 - i) * 86400000);
      const finde = d.getDay() === 0 || d.getDay() === 6;
      const jugadores = vivo ? Math.round((40 + i * 6) * (finde ? 1.35 : 1) + ((i * 37) % 17)) : 0;
      const compras = vivo ? Math.round(jugadores / 45) : 0;
      return { dia: d.toISOString().slice(0, 10), jugadores, nuevos: Math.round(jugadores * 0.4), partidas: jugadores * 6,
        compras, euros: Math.round(compras * 1.9 * 100) / 100 };
    });
    const ventas = dias.reduce((a, d) => a + d.compras, 0);
    const productos = vivo ? [
      { producto: "monedas_500", ventas: Math.round(ventas * 0.6), euros: 0 },
      { producto: "sin_anuncios", ventas: Math.round(ventas * 0.25), euros: 0 },
      { producto: "pase_temporada", ventas: Math.round(ventas * 0.15), euros: 0 },
    ].map((x) => ({ ...x, euros: Math.round(x.ventas * ({ monedas_500: 0.99, sin_anuncios: 2.99, pase_temporada: 3.99 } as Record<string, number>)[x.producto] * 100) / 100 })) : [];
    const total = Math.round(productos.reduce((a, x) => a + x.euros, 0) * 100) / 100;
    return { dias, total_euros: total, neto_euros: Math.round(total * 85) / 100, d1: vivo ? 38 : null, d7: vivo ? 14 : null,
      jugadores_total: vivo ? dias.reduce((a, d) => a + d.nuevos, 0) : 0, productos };
  }

  /** Demo: tres mezclas fijas con el tema de la idea (en el servidor las propone la IA). */
  async ganchos(idea: string): Promise<Gancho[]> {
    await espera(1200);
    const t = idea.trim().slice(0, 80);
    const gs = [
      { titulo: "Laberinto serpiente", genero: "laberinto", giros: ["cola", "contrarreloj"], idea: `${t}: cada paso cierra el camino detrás de ti y el reloj aprieta`,
        por_que: "Un puzle de un minuto que obliga a pensar antes de moverse." },
      { titulo: "Golf de monstruos", genero: "golf", giros: ["monstruos"], idea: `${t}: minigolf en el que derribas monstruos a bolazos para abrir el hoyo`,
        por_que: "Rebotes, combos y la satisfacción de limpiar el campo de un golpe." },
      { titulo: "Linterna y espejo", genero: "plataformas", giros: ["oscuridad", "espejo"], idea: `${t}: saltos a oscuras en un mundo al revés`,
        por_que: "Lo que no ves da tensión y el espejo convierte lo fácil en un reto." },
    ];
    return gs.map((g) => ({ ...g, marca: `[gancho:${g.genero}:${g.giros.join(",")}] ${g.idea}` }));
  }

  /** Demo: un código fijo con dos amigos invitados (uno ya ha fabricado su primer juego). */
  async perfilCreador(): Promise<PerfilCreador> {
    await espera(150);
    const juegos = this.s.proyectos.length;
    const publicados = Object.keys(this.s.escaparate ?? {}).length;
    const jugadas = Object.values(this.s.escaparate ?? {}).reduce((a, e) => a + e.jugadas, 0);
    return { juegos, publicados, jugadas, megusta: publicados ? 3 : 0, remixes: 0, en_tienda: 0, podios: 0, victorias: 0 };
  }

  async retoSemana(): Promise<RetoSemana> {
    await espera(150);
    const fin = new Date();
    fin.setUTCDate(fin.getUTCDate() + ((8 - fin.getUTCDay()) % 7 || 7));
    fin.setUTCHours(0, 0, 0, 0);
    return { semana: 41, tema: "Piratas", termina: fin.toISOString(), premios: [150, 100, 50], mi_proyecto: this.s.reto ?? null,
      participantes: 37 + (this.s.reto ? 1 : 0),
      ganadores_anterior: [{ titulo: "Cohete Pepinillo", autor: "Lucía", puesto: 1 }, { titulo: "Granja Zombi", autor: "Marcos", puesto: 2 }, { titulo: "Sushi Crush", autor: "Aiko", puesto: 3 }] };
  }

  async rankingReto(): Promise<PuestoReto[]> {
    await espera(150);
    const base: PuestoReto[] = [
      { puesto: 1, project_id: "esc-5", titulo: "Mago de Bolsillo", genero: "horda", autor: "Sara", version: 2, puntos: 412 },
      { puesto: 2, project_id: "esc-8", titulo: "Invasores de Gominola", genero: "naves", autor: "Leo", version: 1, puntos: 298 },
      { puesto: 3, project_id: "esc-6", titulo: "Pluma de Papel", genero: "volador", autor: "Iker", version: 1, puntos: 187 },
    ];
    const mio = this.s.reto ? this.s.proyectos.find((p) => p.id === this.s.reto) : undefined;
    if (mio) base.push({ puesto: 4, project_id: mio.id, titulo: mio.titulo, genero: "plataformas", autor: "Tú", version: mio.version, puntos: 12 });
    return base;
  }

  async participarReto(proyectoId: string) {
    await espera(250);
    if (!this.s.escaparate?.[proyectoId]) throw new ErrorApp("Primero compártelo en el escaparate (pestaña Compartir).");
    this.s.reto = proyectoId;
    this.guardar();
  }

  async miInvitacion(): Promise<Invitacion> {
    await espera(200);
    return { codigo: "GATK7M2", invitados: 2, pagados: 1, ganadas: 30, por_amigo: 30, me_invito: Boolean(this.s.invitadoCon) };
  }

  async usarInvitacion(codigo: string) {
    await espera(300);
    const c = codigo.trim().toUpperCase();
    if (this.s.invitadoCon) throw new ErrorApp(mensajeInvitacion("already_invited"));
    if (c === "GATK7M2") throw new ErrorApp(mensajeInvitacion("own_code"));
    if (!/^[A-Z2-9]{7}$/.test(c)) throw new ErrorApp(mensajeInvitacion("bad_code"));
    this.s.invitadoCon = c;
    this.guardar();
  }

  /** Demo: cualquier imagen se da por buena (en el servidor la revisa la IA). */
  async revisarDibujo(_proyectoId: string, imagen: Blob) {
    await espera(900);
    if (imagen.size > 4 * 1024 * 1024) return { ok: false, motivo: "Usa una imagen de menos de 4 MB." };
    return { ok: true, descripcion: "a cheerful hand-drawn character with round shapes and bright crayon colors" };
  }

  /** Demo: una prueba que la B va ganando (si el juego está publicado). */
  async informeAb(proyectoId: string): Promise<InformeAb | null> {
    await espera(250);
    const p = this.s.proyectos.find((x) => x.id === proyectoId);
    if (!p?.prueba_ab) return null;
    if (p.play?.estado !== "subido") return { nivel: p.prueba_ab.nivel, hacia: p.prueba_ab.hacia, version: null, grupos: {} };
    return { nivel: p.prueba_ab.nivel, hacia: p.prueba_ab.hacia, version: p.version, grupos: {
      a: { jugadores: 42, intentos: 97, ganados: 21, salidas: 18, muertes: 2.4, superan: 21 },
      b: { jugadores: 44, intentos: 71, ganados: 33, salidas: 6, muertes: 1.1, superan: 33 } } };
  }

  /** Demo: tres reseñas inventadas (una en inglés y una ya contestada) para juegos ya subidos. */
  async resenas(proyectoId: string): Promise<Resena[]> {
    await espera(300);
    const p = this.s.proyectos.find((x) => x.id === proyectoId);
    if (p?.play?.estado !== "subido") throw new ErrorApp("Publica el juego en Google Play para ver sus reseñas.");
    const hace = (h: number) => new Date(Date.now() - h * 3600000).toISOString();
    const hechas = (this.s.respuestas ?? {})[proyectoId] ?? {};
    const base: Resena[] = [
      { id: "demo-r1", autor: "Lucía M.", estrellas: 4, texto: "Me encanta el gato y la música, pero el nivel 3 es imposible, me he quedado atascada.", traduccion: null,
        idioma: "es", version: "1.0", fecha: hace(5), respuesta: null, respondida_en: null },
      { id: "demo-r2", autor: "Tom", estrellas: 2, texto: "Fun but too many ads after each level", traduccion: "Divertido, pero demasiados anuncios después de cada nivel",
        idioma: "en", version: "1.0", fecha: hace(20), respuesta: null, respondida_en: null },
      { id: "demo-r3", autor: "Jugador", estrellas: 5, texto: "¡Lo juego con mi hijo todas las noches!", traduccion: null,
        idioma: "es", version: "1.0", fecha: hace(60), respuesta: "¡Qué ilusión leer esto! Gracias a los dos por jugar.", respondida_en: hace(50) },
    ];
    return base.map((r) => (hechas[r.id] ? { ...r, respuesta: hechas[r.id].texto, respondida_en: hechas[r.id].en } : r));
  }

  async borradorResena(_proyectoId: string, resenaId: string): Promise<string> {
    await espera(900);
    const borradores: Record<string, string> = {
      "demo-r1": "¡Gracias, Lucía! Nos alegra que te guste el gato. Tienes razón con el nivel 3: lo estamos haciendo más fácil para la próxima versión.",
      "demo-r2": "Thanks for playing, Tom! You're right, we'll show fewer ads between levels in the next update.",
    };
    return borradores[resenaId] ?? "¡Muchas gracias por jugar y por dejarnos tu opinión!";
  }

  async responderResena(proyectoId: string, resenaId: string, texto: string) {
    await espera(400);
    const t = texto.trim();
    if (!t || [...t].length > 350) throw new ErrorApp("La respuesta tiene que tener entre 1 y 350 caracteres.");
    this.s.respuestas = this.s.respuestas ?? {};
    this.s.respuestas[proyectoId] = { ...(this.s.respuestas[proyectoId] ?? {}), [resenaId]: { texto: t, en: new Date().toISOString() } };
    this.guardar();
  }

  /** Demo: los eventos se guardan en el móvil con las mismas reglas que el servidor. */
  async eventos(proyectoId: string): Promise<EventoJuego[]> {
    await espera(150);
    const ahora = Date.now();
    return ((this.s.eventos ?? {})[proyectoId] ?? []).filter((e) => Date.parse(e.fin) > ahora - 30 * 86400000)
      .sort((a, b) => Date.parse(b.inicio) - Date.parse(a.inicio));
  }

  async crearEvento(proyectoId: string, e: { tipo: EventoJuego["tipo"]; titulo: string; inicio: Date; fin: Date; regalo: number }) {
    await espera(200);
    const lista = (this.s.eventos ?? {})[proyectoId] ?? [];
    const dur = e.fin.getTime() - e.inicio.getTime();
    const titulo = e.titulo.trim();
    if (titulo.length < 3 || titulo.length > 40) throw new ErrorApp(mensajeEvento("bad_title"));
    if (dur < 3600000 || dur > 14 * 86400000 || e.inicio.getTime() > Date.now() + 60 * 86400000 || e.fin.getTime() <= Date.now())
      throw new ErrorApp(mensajeEvento("bad_dates"));
    if (e.tipo === "regalo" && (e.regalo < 1 || e.regalo > 500)) throw new ErrorApp(mensajeEvento("bad_gift"));
    if (lista.some((x) => Date.parse(x.inicio) < e.fin.getTime() && Date.parse(x.fin) > e.inicio.getTime())) throw new ErrorApp(mensajeEvento("overlap"));
    if (lista.filter((x) => Date.parse(x.fin) > Date.now()).length >= 5) throw new ErrorApp(mensajeEvento("too_many"));
    const inicio = new Date(Math.max(e.inicio.getTime(), Date.now()));
    lista.push({ id: Date.now(), tipo: e.tipo, titulo, regalo: e.tipo === "regalo" ? e.regalo : 0,
      inicio: inicio.toISOString(), fin: e.fin.toISOString(), cobros: 0 });
    this.s.eventos = { ...(this.s.eventos ?? {}), [proyectoId]: lista };
    this.guardar();
  }

  async borrarEvento(id: number) {
    await espera(150);
    for (const k of Object.keys(this.s.eventos ?? {})) this.s.eventos![k] = this.s.eventos![k].filter((e) => e.id !== id);
    this.guardar();
  }

  /** Demo: una clase nueva trae alumnos de ejemplo para ver cómo queda. */
  async clases(proyectoId: string): Promise<Clase[]> {
    await espera(150);
    return (this.s.clases ?? {})[proyectoId] ?? [];
  }

  async crearClase(proyectoId: string, nombre: string): Promise<string> {
    await espera(250);
    const n = nombre.trim();
    if (!n || n.length > 40) throw new ErrorApp(mensajeClase("bad_name"));
    const lista = (this.s.clases ?? {})[proyectoId] ?? [];
    if (lista.length >= 10) throw new ErrorApp(mensajeClase("too_many"));
    const letras = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    const codigo = Array.from({ length: 6 }, () => letras[Math.floor(Math.random() * letras.length)]).join("");
    const hace = (h: number) => new Date(Date.now() - h * 3600000).toISOString();
    lista.unshift({ codigo, nombre: n, creada: new Date().toISOString(), alumnos: [
      { alias: "Lucia", niveles: 9, estrellas: 24, minutos: 41, visto: hace(1), nivel_actual: 10, intentos: 1 },
      { alias: "Marcos", niveles: 6, estrellas: 15, minutos: 33, visto: hace(2), nivel_actual: 7, intentos: 2 },
      { alias: "Aitana", niveles: 1, estrellas: 3, minutos: 12, visto: hace(26), nivel_actual: 2, intentos: 8 },
    ] });
    this.s.clases = { ...(this.s.clases ?? {}), [proyectoId]: lista };
    this.guardar();
    return codigo;
  }

  async vaciarClase(codigo: string) {
    await espera(150);
    for (const k of Object.keys(this.s.clases ?? {})) for (const c of this.s.clases![k]) if (c.codigo === codigo) c.alumnos = [];
    this.guardar();
  }

  async cerrarClase(codigo: string) {
    await espera(150);
    for (const k of Object.keys(this.s.clases ?? {})) this.s.clases![k] = this.s.clases![k].filter((c) => c.codigo !== codigo);
    this.guardar();
  }

  /** Demo: opiniones de ejemplo (en un juego de verdad las mandan los jugadores). */
  async opiniones(_proyectoId: string): Promise<Opiniones> {
    await espera(150);
    const hace = (h: number) => new Date(Date.now() - h * 3600000).toISOString();
    return { gusta: 37, no_gusta: 6, ultimas: [
      { gusta: false, texto: "El nivel 4 es demasiado difícil, lo he intentado 20 veces", nivel: 4, version: 2, fecha: hace(3) },
      { gusta: false, texto: "Salen muchos anuncios", nivel: 6, version: 2, fecha: hace(26) },
      { gusta: false, texto: "Me gustaría poder cambiar de personaje", nivel: 9, version: 1, fecha: hace(70) },
    ] };
  }

  /** Demo: vale cualquier código con el prefijo del premio; cada uno una sola vez. */
  async canjearPremio(proyectoId: string, codigo: string): Promise<Canje> {
    await espera(300);
    const c = limpiarCodigo(codigo);
    if (!codigoValido(c)) throw new ErrorApp("El código tiene esta forma: CAFE-7F3A.");
    const pr = (this.s.premios ?? {})[proyectoId];
    if (!pr || !c.startsWith(pr.codigo + "-")) return { estado: "no_existe" };
    const canjes = { ...(this.s.canjes ?? {}) };
    if (canjes[`${proyectoId}:${c}`]) return { estado: "ya_usado", canjeado_en: canjes[`${proyectoId}:${c}`] };
    canjes[`${proyectoId}:${c}`] = new Date().toISOString();
    this.s.canjes = canjes;
    this.s.premios = { ...(this.s.premios ?? {}), [proyectoId]: { ...pr, canjeados: (pr.canjeados ?? 0) + 1, ganados: Math.max(pr.ganados ?? 0, (pr.canjeados ?? 0) + 1) } };
    this.guardar();
    return { estado: "ok" };
  }

  /** Demo: el regalo se guarda en el móvil (nadie lo abre de verdad). */
  async regalo(proyectoId: string): Promise<RegaloJuego | null> {
    await espera(120);
    return (this.s.regalos ?? {})[proyectoId] ?? null;
  }

  async guardarRegalo(proyectoId: string, r: RegaloJuego | null): Promise<RegaloJuego | null> {
    await espera(200);
    const todos = { ...(this.s.regalos ?? {}) };
    if (!r || r.para.trim() === "") {
      delete todos[proyectoId];
    } else {
      const mal = validarRegalo(r);
      if (mal) throw new ErrorApp(mal);
      todos[proyectoId] = { para: r.para.trim(), de: r.de.trim(), mensaje: r.mensaje.trim(), tras_nivel: r.tras_nivel, abierto_en: null, leido_en: null };
    }
    this.s.regalos = todos;
    this.guardar();
    return todos[proyectoId] ?? null;
  }

  async enlaceRegalo(proyectoId: string) {
    await espera(900);
    if (!(this.s.regalos ?? {})[proyectoId]) throw new ErrorApp(mensajeRegalo("no_gift"));
    return { url: `https://orquestador.github.io/jugar.html?j=${proyectoId}` };
  }

  /** Demo: el premio se guarda en el móvil con las reglas del servidor (nadie lo gana de verdad). */
  async premio(proyectoId: string): Promise<PremioReal | null> {
    await espera(120);
    return (this.s.premios ?? {})[proyectoId] ?? null;
  }

  async guardarPremio(proyectoId: string, p: PremioReal | null): Promise<PremioReal | null> {
    await espera(200);
    const todos = { ...(this.s.premios ?? {}) };
    if (!p || p.texto.trim() === "") {
      delete todos[proyectoId];
      this.s.premios = todos;
      this.guardar();
      return null;
    }
    const mal = validarPremio(p);
    if (mal) throw new ErrorApp(mal);
    const nuevo: PremioReal = { texto: p.texto.trim(), codigo: p.codigo.trim().toUpperCase(), tras_nivel: p.tras_nivel,
      donde: p.donde.trim(), web: p.web.trim(), caduca: p.caduca || null, ganados: todos[proyectoId]?.ganados ?? 0 };
    todos[proyectoId] = nuevo;
    this.s.premios = todos;
    this.guardar();
    return nuevo;
  }

  /** Demo: la charla se paga con tuercas de verdad (de la demo) y gasta mensajes inventados. */
  async charlaEstado(proyectoId: string): Promise<EstadoCharla> {
    await espera(200);
    const c = (this.s.charla ?? {})[proyectoId] ?? { mensajes: 0, activa: false };
    return { mensajes: c.mensajes, activa: c.activa, hoy: c.activa ? 37 : 0, precio: 40, por_paquete: 500 };
  }

  async charlaActivar(proyectoId: string) {
    await espera(400);
    if (this.s.tuercas < 40) throw new ErrorApp("No tienes tuercas suficientes.");
    this.s.tuercas -= 40;
    const todas = this.s.charla ?? {};
    const c = todas[proyectoId] ?? { mensajes: 0, activa: true };
    todas[proyectoId] = { mensajes: c.mensajes + 500, activa: true };
    this.s.charla = todas;
    this.guardar();
    return { mensajes: todas[proyectoId].mensajes, tuercas: this.s.tuercas };
  }

  async charlaPausar(proyectoId: string, activa: boolean) {
    await espera(150);
    const todas = this.s.charla ?? {};
    if (todas[proyectoId]) todas[proyectoId].activa = activa;
    this.s.charla = todas;
    this.guardar();
  }


  async informe(proyectoId: string): Promise<FilaInforme[]> {
    await espera(500);
    const p = this.s.proyectos.find((x) => x.id === proyectoId);
    if (!p || p.play?.estado !== "subido") return [];
    const n = 3;
    const base = [
      { sesiones: 214, victoria: 0.93, salidas: 0.03, muertes: 0.3, seg: 38 },
      { sesiones: 187, victoria: 0.98, salidas: 0.01, muertes: 0.1, seg: 41 },
      { sesiones: 151, victoria: 0.29, salidas: 0.46, muertes: 3.4, seg: 96 },
      { sesiones: 52, victoria: 0.52, salidas: 0.2, muertes: 2.1, seg: 120 },
    ].slice(0, n);
    return base.map((b, i) => {
      const intentos = Math.round(b.sesiones * (1 + b.muertes / 3));
      return { version: p.version, nivel: i, intentos, sesiones: b.sesiones, ganados: Math.round(intentos * b.victoria),
        salidas: Math.round(intentos * b.salidas), reintentos: 0, muertes_medias: b.muertes, segundos_medios: b.seg,
        estrellas_medias: 2.1 };
    });
  }

  async precioMarketing() {
    return 20;
  }

  async cuentaApple() {
    return this.s.apple ?? null;
  }

  async guardarCuentaApple(d: CuentaApple & { p8: string }) {
    await espera(400);
    if (!/^[A-Z0-9]{10}$/.test(d.equipo.trim().toUpperCase())) throw new ErrorApp("El ID de equipo tiene 10 letras y números (Apple Developer → Membership).");
    if (!/^[A-Z0-9]{10}$/.test(d.clave_id.trim().toUpperCase())) throw new ErrorApp("El ID de la clave tiene 10 letras y números.");
    if (!d.p8.includes("BEGIN PRIVATE KEY")) throw new ErrorApp("El archivo no parece una clave .p8 de App Store Connect.");
    this.s.apple = { equipo: d.equipo.trim().toUpperCase(), clave_id: d.clave_id.trim().toUpperCase(), emisor: d.emisor.trim() };
    this.guardar();
  }

  async publicarIOS(proyectoId: string) {
    const p = this.s.proyectos.find((x) => x.id === proyectoId);
    if (!p) throw new ErrorApp("Ese juego no existe.");
    if (!this.s.apple) throw new ErrorApp("Antes pon tus datos de Apple (equipo y clave de App Store Connect).");
    const t = this.nuevoCambio("game_ios", proyectoId, "App Store");
    void (async () => {
      t.status = "running";
      for (const [s2, m] of [[1.5, "Preparando el juego para iPhone y iPad..."], [2, "Compilando y firmando con tu cuenta de Apple..."], [2, "Subiendo a App Store Connect (TestFlight)..."]] as const) {
        await espera(s2 * 1000);
        t.progress = [...t.progress, { paso: "ios", estado: "inicio", mensaje: m, t: Date.now() / 1000 }];
        this.avisar(t);
      }
      (p as unknown as { ios: unknown }).ios = { bundle: p.play?.paquete ?? "com.demo.juego", build: 1, estado: "subido", subido_en: Date.now() / 1000 };
      t.status = "done";
      t.progress = [...t.progress, { paso: "fin", estado: "ok", mensaje: "En App Store Connect: aparecerá en TestFlight en unos minutos", t: Date.now() / 1000 }];
      this.guardar();
      this.avisar(t);
    })();
    return { job_id: t.id };
  }

  async youtubeEstado() {
    return this.s.youtube ? { conectado: true, canal: this.s.youtube } : { conectado: false };
  }

  async youtubeConectar() {
    // En la demo se conecta al momento (en la app de verdad se abre el permiso de Google).
    this.s.youtube = "Mi canal de juegos";
    this.guardar();
    return "";
  }

  async youtubeDesconectar() {
    delete this.s.youtube;
    this.guardar();
  }

  async marketing(proyectoId: string, youtube: ModoYoutube = "no") {
    this.youtubePedido = youtube;
    const p = this.s.proyectos.find((x) => x.id === proyectoId);
    if (!p) throw new ErrorApp("Ese juego no existe.");
    if (this.s.tuercas < 20) throw new ErrorApp("No tienes tuercas suficientes.");
    this.s.tuercas -= 20;
    const t = this.nuevoCambio("game_marketing", proyectoId, "Vídeos para redes");
    void this.hacerMarketing(t.id);
    return { job_id: t.id, credits: this.s.tuercas };
  }

  private async hacerMarketing(id: string) {
    if (this.enMarcha.has(id)) return;
    this.enMarcha.add(id);
    await espera(600);
    const t = this.s.trabajos.find((x) => x.id === id);
    if (!t) return;
    t.status = "running";
    for (const [seg, ev] of GUION_MARKETING) {
      await espera(seg * 1000);
      t.progress = [...t.progress, { ...ev, t: Date.now() / 1000 }];
      this.avisar(t);
    }
    const p = this.s.proyectos.find((x) => x.id === t.project_id)!;
    const mk = { ...MARKETING_DEMO, ...(this.youtubePedido !== "no" && this.s.youtube ? { youtube: { modo: this.youtubePedido,
      videos: MARKETING_DEMO.videos.map((v, i) => ({ estilo: v.estilo, id: `demo${i}`, url: "https://youtube.com/shorts/demo" })) } } : {}) };
    p.files = { ...p.files, marketing: mk };
    const v = p.versiones.find((x) => x.version === p.version);
    if (v) v.files = p.files;
    t.status = "done";
    this.enMarcha.delete(id);
    t.result = { capturas: [], marketing: mk };
    t.progress = [...t.progress, { paso: "fin", estado: "ok", mensaje: "Tus 3 vídeos para redes están listos", t: Date.now() / 1000 }];
    this.guardar();
    this.avisar(t);
  }

  private async cambiar(id: string, texto: string, titulo?: string, guion: [number, Evento][] = GUION_CAMBIO) {
    if (this.enMarcha.has(id)) return;
    this.enMarcha.add(id);
    await espera(700);
    const t = this.s.trabajos.find((x) => x.id === id);
    if (!t) return;
    t.status = "running";
    for (const [seg, ev] of guion) {
      await espera(seg * 1000);
      t.progress = [...t.progress, { ...ev, t: Date.now() / 1000 }];
      this.avisar(t);
    }
    const p = this.s.proyectos.find((x) => x.id === t.project_id)!;
    p.version += 1;
    if (titulo) p.titulo = titulo;
    p.updated_at = new Date().toISOString();
    p.versiones.push({ version: p.version, prompt: texto, created_at: p.updated_at, files: p.files, titulo: p.titulo });
    t.status = "done";
    this.enMarcha.delete(id);
    t.titulo = p.titulo;
    t.result = p.files;
    t.progress = [...t.progress, { paso: "fin", estado: "ok", mensaje: `Versión ${p.version} lista`, t: Date.now() / 1000 }];
    this.guardar();
    this.avisar(t);
  }

  private avisar(t: Trabajo) {
    this.guardar();
    this.oyentes.get(t.id)?.(structuredClone(t));
  }

  async trabajos() {
    return structuredClone(this.s.trabajos.filter((t) => t.kind !== "game_preview"));
  }

  seguir(id: string, cb: (t: Trabajo) => void) {
    this.oyentes.set(id, cb);
    const t = this.s.trabajos.find((x) => x.id === id);
    if (t) {
      cb(structuredClone(t));
      // Si la página se recargó a mitad, la demo retoma la fabricación.
      if ((t.status === "queued" || t.status === "running") && !this.enMarcha.has(id)) {
        t.progress = [];
        t.status = "queued";
        if (t.kind === "game") void this.fabricar(id);
        else if (t.kind === "game_marketing") void this.hacerMarketing(id);
        else if (t.kind === "game_publish") void this.hacerPublicar(id, t.idea.startsWith("Subir") ? "subir" : "primer_aab", "alpha");
        else void this.cambiar(id, t.idea, undefined, t.kind === "game_mod" ? GUION_PROGRAMA : GUION_CAMBIO);
      }
    }
    return () => this.oyentes.delete(id);
  }

  motor() {
    return null;
  }

  async url(ruta: string) {
    const u = ARCHIVOS[ruta];
    if (!u) throw new ErrorApp("En la demostración no hay archivos para descargar: con el servidor real aquí baja tu APK.");
    return u;
  }

  async verAnuncio() {
    await espera(1200);
    this.s.tuercas += 5;
    this.guardar();
    return { visto: true, tuercas: this.s.tuercas };
  }

  async tienda(): Promise<EstadoTienda> {
    const hasta = this.s.plan ? new Date(Date.now() + 30 * 86400e3).toISOString() : null;
    return {
      productos: [
        { id: "tuercas_300", tipo: "tuercas", tuercas: 300, precio: "2,99 €" },
        { id: "tuercas_1100", tipo: "tuercas", tuercas: 1100, precio: "9,99 €" },
        { id: "tuercas_3600", tipo: "tuercas", tuercas: 3600, precio: "29,99 €" },
        { id: "plan_taller", tipo: "plan", tuercas: 0, precio: "4,99 €", plan: "taller", tuercasMes: 250,
          precios: { mensual: "4,99 €", anual: "49,99 €" } },
        { id: "plan_pro", tipo: "plan", tuercas: 0, precio: "12,99 €", plan: "pro", tuercasMes: 800,
          precios: { mensual: "12,99 €", anual: "129,99 €" } },
      ],
      premium: !!this.s.premium || !!this.s.plan, premiumHasta: hasta,
      plan: this.s.plan ?? null, planHasta: hasta, planEntrega: hasta, topeMeses: 2, bonusPro: 20,
      aviso: "Demostración: las compras son simuladas y no se cobra nada.", anuncios: true,
    };
  }

  async comprar(productoId: string) {
    await espera(900);
    const p = (await this.tienda()).productos.find((x) => x.id === productoId);
    if (!p) throw new ErrorApp("Ese producto no existe.");
    if (p.tipo === "plan") {
      const antes = this.s.plan === "pro" ? 2 : this.s.plan === "taller" ? 1 : 0;
      if ((p.plan === "pro" ? 2 : 1) > antes) this.s.tuercas += Math.max(0, Math.min(p.tuercasMes ?? 0, (p.tuercasMes ?? 0) * 2 - this.s.tuercas));
      this.s.plan = p.plan;
    } else if (p.tipo === "premium") this.s.premium = true;
    else this.s.tuercas += p.tuercas + (this.s.plan === "pro" ? Math.round(p.tuercas * 0.2) : 0);
    this.guardar();
    return { tuercas: this.s.tuercas, premium: !!this.s.premium || !!this.s.plan };
  }

  async gestionarPlan() {
    await espera(400);
    if (this.s.plan) {
      delete this.s.plan;
      this.guardar();
    }
  }

  async recuperarCompras() {
    return 0;
  }
}

/** En la demo, tu campaña recibe probadores en cuanto tú pruebas 3 juegos (como en el servidor). */
function probandoVisible(probando: number) {
  return probando >= 3;
}

function espera(ms: number) {
  return new Promise<void>((r) => setTimeout(r, ms));
}


// Planificador de la demo: unas pocas palabras clave. En el servidor real lo hace Claude.
const COLORES: Record<string, string> = { negro: "negro", negra: "negro", blanco: "blanco", blanca: "blanco", rojo: "rojo",
  azul: "azul", verde: "verde", morado: "morado", dorado: "dorado", rosa: "rosa", gris: "gris" };

function planDemo(instruccion: string): Propuesta & { nuevoTitulo?: string } {
  const t = instruccion.toLowerCase();
  const ops: string[] = [];
  const frases: string[] = [];
  let nuevoTitulo: string | undefined;
  let noPuedo: string | null = null;
  let quitaJefe = false;
  if (/multijugador|espada|tienda/.test(t)) noPuedo = "Eso todavía no lo sé hacer en el taller; está en camino.";
  const m = instruccion.match(/(?:ll[aá]m|t[ií]tulo|nombre)[^"«]*["«]([^"»]+)["»]/i);
  if (m) { ops.push("textos"); nuevoTitulo = m[1].trim().slice(0, 28); frases.push(`le cambio el nombre a «${nuevoTitulo}»`); }
  const color = t.split(/\W+/).find((w) => w in COLORES);
  if (color && /h[eé]roe|protagonista|personaje|gato|mishi/.test(t)) { ops.push("redibujar"); frases.push(`redibujo al héroe en ${COLORES[color]}`); }
  if (/m[aá]s dif[ií]cil/.test(t) && !/nivel/.test(t)) { ops.push("ajustes"); frases.push("subo la dificultad y rehago los niveles"); }
  else if (/m[aá]s f[aá]cil/.test(t) && !/nivel/.test(t)) { ops.push("ajustes"); frases.push("bajo la dificultad"); }
  if (/(m[aá]s lent|m[aá]s r[aá]pid)/.test(t) && /enemig|volador|pinch/.test(t)) { ops.push("ajustes"); frases.push("cambio la velocidad de los enemigos"); }
  if (/\d+\s*vidas/.test(t)) { ops.push("ajustes"); frases.push("cambio los corazones"); }
  if (/(a[ñn]ade|pon|mete|otro|nuevo).{0,20}nivel/.test(t)) { ops.push("anadir_nivel"); frases.push("añado un nivel nuevo"); }
  if (/(rehaz|cambia|repite).{0,20}nivel/.test(t)) { ops.push("rehacer_nivel"); frases.push("rehago ese nivel"); }
  if (/(a[ñn]ade|pon|mete).{0,30}enemigo/.test(t)) { noPuedo = noPuedo ?? "Tu juego ya tiene los tres tipos de enemigo que sé hacer. Puedo redibujar alguno."; }
  if (/pixel/.test(t)) { ops.push("estilo"); frases.push("paso todo el juego a pixel art"); }
  if (/torres|tower|defensa|defender/.test(t)) {
    ops.push("genero");
    frases.push("lo convierto en tower defense: los enemigos siguen un camino hasta tu base y tú pones torres (rayo, cañón y hielo) para pararlos");
  } else if (/carrera|coches|circuito/.test(t)) {
    ops.push("genero");
    frases.push("lo convierto en carreras: tu coche contra 3 rivales, con tráfico, monedas y turbo");
  } else if (/puzle|puzzle|combina|match|caramelo|joyas/.test(t)) {
    ops.push("genero");
    frases.push("lo convierto en un puzle de combinar 3: tablero, movimientos limitados, especiales y hielo");
  } else if (/horda|oleada|survivor|sobreviv/.test(t)) {
    ops.push("genero");
    frases.push("lo convierto en un juego de hordas visto desde arriba: sobrevives a oleadas, tus armas disparan solas y eliges mejoras al subir de nivel");
  } else if (/vuele|\bvolador\b|arcade|un toque/.test(t)) {
    ops.push("genero");
    frases.push("lo convierto en arcade de un toque: tocas para volar entre columnas (rehago los niveles, sin jefe ni enemigos)");
  } else if (/runner|corra solo|corra sin parar/.test(t)) {
    ops.push("genero");
    frases.push("lo convierto en runner: corre solo y cada vez más rápido, tú solo saltas (rehago los niveles)");
  } else if (/jefe/.test(t)) {
    quitaJefe = /(quita|sin|elimina|fuera).{0,20}jefe/.test(t);
    ops.push("jefe");
    frases.push(quitaJefe ? "quito al jefe final" : "pongo un jefe final en el último nivel (salta y aplasta; hay que pisarle 3 veces)");
  }
  if (/dispar|bola|l[aá]ser|fuego/.test(t)) {
    ops.push("disparo");
    frases.push(/(quita|sin|no).{0,12}dispar/.test(t) ? "quito el disparo" : "le doy disparo al héroe (botón de fuego)");
  }
  if (/historia|di[aá]logos?|que hablen|conversaci/.test(t)) {
    ops.push("historia");
    frases.push(/(quita|sin|elimina|borra).{0,20}(historia|di[aá]logo)/.test(t) ? "quito los diálogos entre niveles"
      : "escribo una historia con diálogos entre niveles (el héroe y los malos hablan con su voz)");
  }
  if (/\b3 ?d\b|tres dimensiones|low ?poly/.test(t)) { ops.push("vista"); frases.push("lo paso a 3D: bloques de verdad, fondo con profundidad y los mismos niveles"); }
  else if (/\b2 ?d\b/.test(t)) { ops.push("vista"); frases.push("lo vuelvo a 2D de toda la vida"); }
  if (/poder|doble salto|im[aá]n|estrella|invencib/.test(t)) { ops.push("poderes"); frases.push("reparto poderes por los niveles"); }
  if (/m[uú]sica|canci[oó]n/.test(t)) { ops.push("musica"); frases.push(/[eé]pic|r[aá]pid|cañer/.test(t) ? "compongo una música más épica" : "compongo música nueva"); }
  if (/punto[s]? de control|checkpoint|plataforma[s]? m[oó]vil/.test(t)) { ops.push("extras"); frases.push("cambio los puntos de control y las plataformas móviles"); }
  if (!ops.length) {
    return { plan_id: null, resumen: noPuedo ?? "No tengo claro qué cambiar.", pregunta: noPuedo ? null : "¿Qué quieres cambiar: un personaje, la dificultad, los niveles o el nombre?",
      no_puedo: noPuedo, operaciones: [], coste: 0 };
  }
  const arteTotal = ops.includes("estilo");
  const coste = PRECIOS.base + ops.reduce((a, o) => a + (o === "redibujar" && arteTotal ? 0 : PRECIOS[o === "jefe" && quitaJefe ? "jefe_quitar" : o]), 0);
  return { plan_id: "plan-" + Date.now(), resumen: `Vale: ${frases.join(", ")}.`, pregunta: null, no_puedo: noPuedo,
    operaciones: ops, coste, nuevoTitulo };
}
