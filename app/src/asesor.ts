// Asesor de lanzamiento: mira el juego entero (si está publicado, si gana dinero, cuánta gente
// juega, si vuelve, dónde se atasca) y dice las 3 cosas que más le ayudarían AHORA, cada una con
// su botón: un cambio del taller, encender algo de «Qué lleva tu juego» o ir a la sección justa.
// Sin coste ni IA de pago: reglas explicables sobre los datos que ya tiene la app.
// Nunca propone compras, avisos ni nada online a un juego para niños.

import type { FilaInforme } from "./aprendizaje";
import { diagnosticar } from "./aprendizaje";

export type Pestana = "taller" | "publicar" | "compartir" | "jugadores";
export type FuncionAsesor = "tienda" | "pase" | "avisos" | "nube" | "online";

export type Accion =
  | { tipo: "arreglar"; instruccion: string }
  | { tipo: "funcion"; op: { op: "funciones" } & Partial<Record<FuncionAsesor, boolean>> }
  | { tipo: "ir"; pestana: Pestana };

export interface ConsejoLanzamiento {
  id: string;
  /** Más alto = más urgente. */
  peso: number;
  titulo: string;
  texto: string;
  boton: string;
  accion: Accion;
}

export interface DatosAsesor {
  genero?: string;
  publico?: "todos" | "infantil";
  funciones?: Partial<Record<FuncionAsesor, boolean>>;
  publicado: boolean;
  anuncios: boolean;
  niveles: string[];
  informe: FilaInforme[] | null;
  ingresos: { jugadores_total: number; d1: number | null; d7: number | null; total_euros: number; compras: number } | null;
  eventosProgramados: number;
  /** Hay una prueba A/B en marcha. */
  pruebaAb?: boolean;
}

/** Géneros que viven del online (arena en directo, liga de aldeas, clasificaciones). */
const ONLINE_CLAVE = ["arena", "aldea", "carreras", "corredor"];
/** Géneros que piden volver cada día (misiones, temporada). */
const DIARIOS = ["aldea", "clicker", "rpg", "puzle", "cartas", "torres"];

export const MIN_JUGADORES = 30;

export function aconsejar(d: DatosAsesor): ConsejoLanzamiento[] {
  const ninos = d.publico === "infantil";
  const tiene = (f: FuncionAsesor): boolean => !(ninos && ["tienda", "avisos", "online"].includes(f)) && d.funciones?.[f] !== false;
  const puede = (f: FuncionAsesor): boolean => !ninos || !["tienda", "avisos", "online"].includes(f);
  const out: ConsejoLanzamiento[] = [];
  const add = (c: ConsejoLanzamiento) => out.push(c);
  const jugadores = d.ingresos?.jugadores_total ?? 0;

  // 1 - Antes de publicar: lo que falta para salir bien.
  if (!d.publicado) {
    add({ id: "publicar", peso: 100, titulo: "Publícalo en prueba interna",
      texto: "Sube el juego a Google Play en prueba interna: es gratis, tarda unos minutos y te da el enlace para tus primeros probadores.",
      boton: "Ir a publicar", accion: { tipo: "ir", pestana: "publicar" } });
    if (!d.anuncios) {
      add({ id: "anuncios", peso: 60, titulo: "Activa los anuncios antes de salir",
        texto: "Un juego sin anuncios no gana nada desde el primer día. Con premio por ver un anuncio, el jugador elige y no molesta.",
        boton: "Configurar anuncios", accion: { tipo: "ir", pestana: "publicar" } });
    }
    add({ id: "video", peso: 40, titulo: "Prepara un vídeo corto",
      texto: "Los vídeos de 15 segundos para TikTok, Reels o Shorts son la forma más barata de conseguir los primeros jugadores.",
      boton: "Hacer vídeos", accion: { tipo: "ir", pestana: "compartir" } });
  } else if (jugadores < MIN_JUGADORES) {
    // 2 - Publicado pero sin gente: lo primero es que lo prueben.
    add({ id: "primeros", peso: 90, titulo: "Consigue tus primeros 30 jugadores",
      texto: `Ahora mismo lo han jugado ${jugadores}. Comparte el enlace, súbelo al Escaparate y publica un vídeo: con 30 jugadores ya sabremos qué mejorar.`,
      boton: "Compartir", accion: { tipo: "ir", pestana: "compartir" } });
  }

  // 3 - Niveles: el atasco más grave que vea el diagnóstico.
  if (d.informe?.length) {
    const diag = diagnosticar(d.informe, d.niveles);
    // El diagnóstico ya los da por gravedad; lo «demasiado fácil» solo si no hay nada peor.
    const peor = diag.consejos.find((c) => c.tipo !== "facil") ?? diag.consejos[0];
    if (diag.suficiente && peor) {
      add({ id: "nivel", peso: peor.tipo === "facil" ? 45 : 80, titulo: peor.nivel !== null ? `Arregla el nivel ${peor.nivel + 1}` : "Ajusta los niveles",
        texto: peor.texto, boton: "Que Chispa lo arregle", accion: { tipo: "arreglar", instruccion: peor.instruccion } });
      if (peor.nivel !== null && peor.tipo !== "facil" && !d.pruebaAb && jugadores >= 2 * MIN_JUGADORES) {
        add({ id: "ab", peso: 72, titulo: "¿Más fácil o no? Pruébalo con jugadores",
          texto: `Antes de cambiar el nivel ${peor.nivel + 1} para todos, haz una prueba A/B: la mitad juega una versión más fácil y los datos dicen cuál va mejor.`,
          boton: "Preparar la prueba", accion: { tipo: "ir", pestana: "jugadores" } });
      }
    }
  }

  // 4 - Que vuelvan: retención del día siguiente y de la semana.
  const hayDatos = jugadores >= MIN_JUGADORES;
  if (hayDatos && d.ingresos?.d1 !== null && d.ingresos?.d1 !== undefined && d.ingresos.d1 < 25) {
    if (puede("avisos") && !tiene("avisos")) {
      add({ id: "avisos", peso: 75, titulo: "Recuérdales que vuelvan",
        texto: `Solo vuelve el ${d.ingresos.d1} % al día siguiente. Enciende los avisos: el juego les recuerda su premio diario (una vez al día, nada de spam).`,
        boton: "Encender avisos", accion: { tipo: "funcion", op: { op: "funciones", avisos: true } } });
    } else if (!tiene("pase") && DIARIOS.includes(d.genero ?? "")) {
      add({ id: "pase", peso: 70, titulo: "Dales un motivo para volver",
        texto: `Solo vuelve el ${d.ingresos.d1} % al día siguiente. Las misiones diarias y el pase de temporada son lo que más hace volver en este tipo de juego.`,
        boton: "Encender misiones y pase", accion: { tipo: "funcion", op: { op: "funciones", pase: true } } });
    } else {
      add({ id: "primer_nivel", peso: 65, titulo: "Engancha en el primer minuto",
        texto: `Solo vuelve el ${d.ingresos.d1} % al día siguiente. Suele ser el arranque: un primer nivel más corto y vistoso y un premio al terminarlo.`,
        boton: "Que Chispa lo mejore",
        accion: { tipo: "arreglar", instruccion: "Haz el primer nivel más corto, fácil y vistoso, con un premio de monedas al terminarlo, para enganchar en el primer minuto" } });
    }
  }
  if (hayDatos && d.ingresos?.d7 !== null && d.ingresos?.d7 !== undefined && d.ingresos.d7 < 8 && d.eventosProgramados === 0) {
    add({ id: "evento", peso: 55, titulo: "Programa un evento de fin de semana",
      texto: `A la semana sigue el ${d.ingresos.d7} %. Un fin de semana de monedas dobles o un regalo trae de vuelta a los que se fueron, sin publicar otra versión.`,
      boton: "Programar evento", accion: { tipo: "ir", pestana: "jugadores" } });
  }

  // 5 - Dinero: tienda para quien ya tiene público.
  if (hayDatos && puede("tienda") && !tiene("tienda")) {
    add({ id: "tienda", peso: jugadores >= 100 ? 62 : 35, titulo: "Abre la tienda",
      texto: `Ya tienes ${jugadores} jugadores. Una tienda con monedas, pase premium y «sin anuncios» es lo que más ingresa después de los anuncios.`,
      boton: "Encender tienda", accion: { tipo: "funcion", op: { op: "funciones", tienda: true } } });
  } else if (jugadores >= 150 && tiene("tienda") && (d.ingresos?.compras ?? 0) === 0 && d.eventosProgramados === 0) {
    add({ id: "oferta", peso: 50, titulo: "Nadie ha comprado aún",
      texto: `Con ${jugadores} jugadores y ninguna compra, un evento de monedas dobles enseña lo que vale la tienda. Prueba un fin de semana.`,
      boton: "Programar evento", accion: { tipo: "ir", pestana: "jugadores" } });
  }

  // 6 - Lo que el género pide.
  if (puede("online") && !tiene("online") && ONLINE_CLAVE.includes(d.genero ?? "")) {
    add({ id: "online", peso: d.publicado ? 58 : 30, titulo: "Este juego brilla online",
      texto: "Las partidas contra gente de verdad, la liga y las clasificaciones son lo que hace durar a este tipo de juego.",
      boton: "Encender online", accion: { tipo: "funcion", op: { op: "funciones", online: true } } });
  }
  if (hayDatos && !tiene("nube") && (d.ingresos?.d7 ?? 0) >= 15) {
    add({ id: "nube", peso: 30, titulo: "Que no pierdan su partida",
      texto: "Tienes jugadores fieles. Con el guardado en la nube se llevan su progreso a otro móvil en vez de empezar de cero.",
      boton: "Encender nube", accion: { tipo: "funcion", op: { op: "funciones", nube: true } } });
  }

  return out.sort((a, b) => b.peso - a.peso).slice(0, 3);
}
