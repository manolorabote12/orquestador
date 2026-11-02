// Modo clase: el profesor crea una clase con un código; los alumnos lo escriben en el juego con su
// nombre de pila o un apodo y aquí se ve cómo va cada uno. Sin correos ni datos personales.

export interface Alumno { alias: string; niveles: number; estrellas: number; minutos: number; visto: string;
  /** Nivel en el que está (1, 2...) y cuántas veces ha perdido en él. */
  nivel_actual?: number; intentos?: number }

/** A partir de cuántos intentos en el mismo nivel se avisa al profe. */
export const ATASCO = 5;

/** "Atascado en el nivel 4 (7 intentos)" o "" si va bien. */
export function atasco(a: Alumno, totalNiveles: number): string {
  const n = a.nivel_actual ?? 0, i = a.intentos ?? 0;
  if (n < 1 || i < ATASCO || (totalNiveles > 0 && a.niveles >= totalNiveles)) return "";
  return `Atascado en el nivel ${n} (${i} intentos)`;
}
export interface Clase { codigo: string; nombre: string; creada: string; alumnos: Alumno[] }

export function mensajeClase(m: string): string {
  if (m.includes("bad_name")) return "Ponle a la clase un nombre de 1 a 40 letras (por ejemplo, 3º B).";
  if (m.includes("too_many")) return "Ya tienes 10 clases en este juego: cierra alguna.";
  return "No se pudo crear la clase.";
}

/** "hace 5 min", "hace 3 h", "hace 2 días". */
export function haceCuanto(iso: string, ahora = new Date()): string {
  const min = Math.max(0, Math.floor((ahora.getTime() - Date.parse(iso)) / 60000));
  if (min < 60) return `hace ${min} min`;
  if (min < 1440) return `hace ${Math.floor(min / 60)} h`;
  return `hace ${Math.floor(min / 1440)} días`;
}

/** Resumen de la clase para el profesor. */
export function resumenClase(c: Clase, totalNiveles: number): string {
  const n = c.alumnos.length;
  if (!n) return "Aún no se ha unido nadie.";
  const media = c.alumnos.reduce((s, a) => s + a.niveles, 0) / n;
  const todo = totalNiveles > 0 ? c.alumnos.filter((a) => a.niveles >= totalNiveles).length : 0;
  const atascados = c.alumnos.filter((a) => atasco(a, totalNiveles)).length;
  return `${n} alumno${n === 1 ? "" : "s"} · media ${media.toFixed(1)} niveles` + (totalNiveles > 0 ? ` · ${todo} lo han terminado` : "")
    + (atascados ? ` · ${atascados} atascado${atascados === 1 ? "" : "s"}` : "");
}

/** La tabla en CSV (para la hoja de notas). */
export function csvClase(c: Clase): string {
  const filas = [["Alumno", "Niveles", "Estrellas", "Minutos", "Nivel actual", "Intentos en él", "Última vez"],
    ...c.alumnos.map((a) => [a.alias, String(a.niveles), String(a.estrellas), String(a.minutos), String(a.nivel_actual ?? ""), String(a.intentos ?? ""), a.visto.slice(0, 10)])];
  return filas.map((f) => f.map((x) => (/[",;\n]/.test(x) ? `"${x.replace(/"/g, '""')}"` : x)).join(";")).join("\n");
}
