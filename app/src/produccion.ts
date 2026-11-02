// Camino a producción en Google Play: lo que falta de la prueba cerrada y las respuestas para el
// cuestionario que Google hace al pedir el acceso a producción (Play Console → Panel → «Solicitar
// acceso a producción»). Todo sale de datos reales de la campaña (probadores, check-ins, opiniones
// privadas) y de las versiones del juego: nada inventado, y el autor lo revisa antes de pegarlo.

export interface ProbadorResumen {
  n: number;
  dias: number;
  estado: "activo" | "completado" | "abandonado";
}

export interface CampanaResumen {
  estado: "abierta" | "lista";
  objetivo: number;
  dias: number;
  completados: number;
  activos: number;
  abandonos: number;
  probadores: ProbadorResumen[];
  opiniones: { probador: number; nivel: number; opinion: string }[];
  creada?: string;
  checkins?: number;
  nivel_medio?: number | null;
  nivel_max?: number | null;
}

export interface Proyeccion {
  /** Con los que siguen jugando no se llega al objetivo. */
  riesgo: boolean;
  /** Probadores que faltan (0 si ya hay bastantes jugando o cumplidos). */
  faltan: number;
  /** Días que quedan, como pronto, para tener el objetivo con 14 días. */
  dias_restantes: number;
  /** Fecha (AAAA-MM-DD) estimada para pedir producción, o null si hay riesgo. */
  fecha: string | null;
}

/** Cuándo podrá pedir producción y si está en riesgo (cuentan los activos y los ya cumplidos). */
export function proyeccion(c: CampanaResumen, hoy: Date = new Date()): Proyeccion {
  const vivos = c.probadores.filter((p) => p.estado !== "abandonado")
    .map((p) => (p.estado === "completado" ? c.dias : Math.min(p.dias, c.dias)))
    .sort((a, b) => b - a);
  const faltan = Math.max(0, c.objetivo - vivos.length);
  if (c.estado === "lista") return { riesgo: false, faltan: 0, dias_restantes: 0, fecha: fechaISO(hoy) };
  if (faltan > 0) return { riesgo: true, faltan, dias_restantes: c.dias, fecha: null };
  const peor = vivos[c.objetivo - 1];
  const dias = Math.max(0, c.dias - peor);
  const f = new Date(hoy.getTime() + dias * 86400000);
  return { riesgo: false, faltan: 0, dias_restantes: dias, fecha: fechaISO(f) };
}

function fechaISO(d: Date): string {
  return d.toISOString().slice(0, 10);
}

/** Racha del probador: días seguidos jugados (la Lanzadera los cuenta seguidos: 2 sin jugar = abandono). */
export function textoRacha(dias: number, objetivo: number): string {
  if (dias <= 0) return "Empieza hoy tu racha";
  if (dias >= objetivo) return `Racha completa: ${objetivo} días`;
  const quedan = objetivo - dias;
  return `Racha de ${dias} día${dias === 1 ? "" : "s"} · ${quedan === 1 ? "queda 1" : `quedan ${quedan}`}`;
}

export interface DatosJuego {
  titulo: string;
  /** Nombre del tipo de juego en palabras (p. ej. «plataformas»). */
  tipo: string;
  publico: "todos" | "infantil";
  /** Instrucciones de las versiones hechas desde que empezó la prueba (las más recientes primero). */
  cambios: string[];
}

export interface Respuesta {
  pregunta: string;
  respuesta: string;
}

/** Palabras que más se repiten en las opiniones (sin las vacías): pistas de qué dijeron. */
export function temas(opiniones: string[], max = 4): string[] {
  const vacias = new Set(("el la los las un una unos unas de del al a en y o que es muy mas más pero me mi se lo le les con por para " +
    "no si sí ya hay esta está este esto eso como cuando todo toda nivel juego juegos the and to of it is").split(" "));
  const cuenta = new Map<string, number>();
  for (const o of opiniones) {
    const vistas = new Set<string>();
    for (const w of o.toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "").match(/[a-zñ]{4,}/g) ?? []) {
      if (vacias.has(w) || vistas.has(w)) continue;
      vistas.add(w);
      cuenta.set(w, (cuenta.get(w) ?? 0) + 1);
    }
  }
  return [...cuenta.entries()].filter(([, n]) => n >= 2).sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0])).slice(0, max).map(([w]) => w);
}

/** Las respuestas del cuestionario de producción, con los datos de la campaña. */
export function respuestasProduccion(c: CampanaResumen, j: DatosJuego): Respuesta[] {
  const total = c.probadores.length;
  const cumplidos = c.completados;
  const ops = c.opiniones.map((o) => o.opinion.trim()).filter(Boolean);
  const citas = [...ops].sort((a, b) => b.length - a.length).slice(0, 3);
  const tem = temas(ops);
  const cambios = j.cambios.map((x) => x.trim()).filter(Boolean).slice(0, 5);
  const nivelTxt = c.nivel_medio ? ` Llegaron de media al nivel ${String(c.nivel_medio).replace(".", ",")}${c.nivel_max ? ` (el que más, al ${c.nivel_max})` : ""}.` : "";
  const checkTxt = c.checkins ? ` En total registraron ${c.checkins} días de juego.` : "";
  return [
    { pregunta: "¿Cómo has reclutado a los usuarios para la prueba cerrada?",
      respuesta: `Mediante la Lanzadera de Orquestador, una comunidad de creadores de juegos que prueban los juegos de los demás. ` +
        `Cada probador se unió por su cuenta al Grupo de Google de la prueba y se hizo probador desde el enlace de Google Play. ` +
        `Nadie recibió dinero ni recompensas por reseñas.` },
    { pregunta: "¿Ha sido fácil reclutar probadores?",
      respuesta: `Se unieron ${total} probadores; ${cumplidos} completaron los ${c.dias} días` +
        (c.abandonos ? ` y ${c.abandonos} lo dejaron antes, por eso abrimos plazas de reserva.` : ".") },
    { pregunta: "Describe la participación de los probadores durante la prueba cerrada",
      respuesta: `Los probadores jugaron cada día y lo registraron en la app con el nivel al que llegaron y, si querían, una opinión privada.` +
        checkTxt + nivelTxt },
    { pregunta: "Resume los comentarios de los probadores y cómo los recogiste",
      respuesta: ops.length
        ? `Recogimos ${ops.length === 1 ? "una opinión privada" : `${ops.length} opiniones privadas`} dentro de la app (solo las ve el autor).` +
          (tem.length ? ` Lo que más se repitió: ${tem.join(", ")}.` : "") +
          ` Algunas: ${citas.map((x) => `«${x.slice(0, 140)}»`).join(" ")}`
        : "Los probadores registraron su progreso cada día; no dejaron comentarios escritos." },
    { pregunta: "¿A quién va dirigida tu aplicación?",
      respuesta: j.publico === "infantil"
        ? `Es un juego de ${j.tipo} pensado para niños: sin compras, sin avisos y sin funciones en línea, con anuncios aptos para familias.`
        : `Es un juego de ${j.tipo} para cualquier persona que quiera partidas cortas en el móvil.` },
    { pregunta: "¿Cómo aporta valor tu aplicación a los usuarios?",
      respuesta: `«${j.titulo}» ofrece partidas rápidas de ${j.tipo} con niveles que aumentan de dificultad, funciona sin conexión y guarda el progreso.` },
    { pregunta: "¿Qué cambios hiciste en la aplicación gracias a la prueba cerrada?",
      respuesta: cambios.length
        ? `Publicamos ${cambios.length === 1 ? "una versión nueva" : `${cambios.length} versiones nuevas`} durante la prueba: ${cambios.map((x) => x.replace(/\.$/, "")).join("; ")}.`
        : "Revisamos cada opinión y no hizo falta cambiar nada importante: no hubo errores ni bloqueos." },
    { pregunta: "¿Cómo decidiste que la aplicación está lista para producción?",
      respuesta: `${cumplidos} probadores la usaron ${c.dias} días seguidos sin errores que impidieran jugar` +
        (cambios.length ? ", y las mejoras que pidieron ya están en la última versión." : ".") +
        " Además, cada versión la juegan bots automáticos de principio a fin antes de publicarla." },
  ];
}

/** Lo mismo en un solo texto para copiar. */
export function textoRespuestas(rs: Respuesta[]): string {
  return rs.map((r) => `${r.pregunta}\n${r.respuesta}`).join("\n\n");
}
