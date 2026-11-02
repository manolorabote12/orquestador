// Aprender de la gente que juega: de las filas de informe_jugadores (por versión y nivel) a
// consejos concretos que Chispa puede aplicar con el taller ("Rehaz el nivel 3 más fácil").
// Reglas sencillas y explicables; solo se opina con datos suficientes (MIN_INTENTOS por nivel).

export interface FilaInforme {
  version: number;
  nivel: number;
  intentos: number;
  sesiones: number;
  ganados: number;
  salidas: number;
  reintentos: number;
  muertes_medias: number;
  segundos_medios: number;
  estrellas_medias: number | null;
}

export interface NivelVisto {
  nivel: number;
  nombre: string;
  intentos: number;
  jugadores: number;
  victoria: number;
  abandono: number;
  muertes: number;
  segundos: number;
  estrellas: number | null;
  llegan: number | null;
}

export interface Consejo {
  nivel: number | null;
  tipo: "dificil" | "abandono" | "facil" | "embudo" | "general";
  texto: string;
  instruccion: string;
}

export interface Diagnostico {
  version: number | null;
  niveles: NivelVisto[];
  consejos: Consejo[];
  suficiente: boolean;
  jugadores: number;
}

export const MIN_INTENTOS = 15;

const pc = (x: number) => `${Math.round(x * 100)} %`;

export function diagnosticar(filas: FilaInforme[], nombres: string[]): Diagnostico {
  if (!filas.length) return { version: null, niveles: [], consejos: [], suficiente: false, jugadores: 0 };
  const version = Math.max(...filas.map((f) => f.version));
  const deVersion = filas.filter((f) => f.version === version).sort((a, b) => a.nivel - b.nivel);
  const primero = deVersion.find((f) => f.nivel === 0);
  const niveles: NivelVisto[] = deVersion.map((f) => ({
    nivel: f.nivel,
    nombre: nombres[f.nivel] ?? `Nivel ${f.nivel + 1}`,
    intentos: f.intentos,
    jugadores: f.sesiones,
    victoria: f.intentos ? f.ganados / f.intentos : 0,
    abandono: f.intentos ? f.salidas / f.intentos : 0,
    muertes: Number(f.muertes_medias),
    segundos: Number(f.segundos_medios),
    estrellas: f.estrellas_medias === null ? null : Number(f.estrellas_medias),
    llegan: primero && primero.sesiones ? f.sesiones / primero.sesiones : null,
  }));
  const consejos: Consejo[] = [];
  const total = nombres.length || niveles.length;
  for (const n of niveles) {
    if (n.intentos < MIN_INTENTOS) continue;
    const ultimo = n.nivel === total - 1;
    const etiqueta = `el nivel ${n.nivel + 1} (${n.nombre})`;
    if (n.abandono > 0.4 && n.victoria < 0.5) {
      consejos.push({ nivel: n.nivel, tipo: "abandono",
        texto: `En ${etiqueta} se rinde mucha gente: lo deja a medias el ${pc(n.abandono)} y solo lo pasa el ${pc(n.victoria)}.`,
        instruccion: `Rehaz el nivel ${n.nivel + 1} más fácil, que la gente lo abandona` });
    } else if (n.victoria < (ultimo ? 0.25 : 0.35) && n.muertes >= 2) {
      consejos.push({ nivel: n.nivel, tipo: "dificil",
        texto: `${cap(etiqueta)} es demasiado difícil: solo lo pasa el ${pc(n.victoria)} y se muere ${n.muertes.toFixed(1)} veces de media.`,
        instruccion: `Rehaz el nivel ${n.nivel + 1} más fácil` });
    } else if (n.nivel > 0 && !ultimo && n.victoria > 0.95 && n.muertes < 0.2) {
      consejos.push({ nivel: n.nivel, tipo: "facil",
        texto: `${cap(etiqueta)} no supone ningún reto: lo pasa el ${pc(n.victoria)} sin morir casi nunca.`,
        instruccion: `Rehaz el nivel ${n.nivel + 1} más difícil` });
    }
  }
  // Embudo: de un nivel al siguiente se pierde más de la mitad de la gente.
  for (let i = 1; i < niveles.length; i++) {
    const a = niveles[i - 1];
    const b = niveles[i];
    if (a.jugadores >= MIN_INTENTOS && b.nivel === a.nivel + 1 && b.jugadores / a.jugadores < 0.4
      && !consejos.some((c) => c.nivel === a.nivel)) {
      consejos.push({ nivel: a.nivel, tipo: "embudo",
        texto: `Del nivel ${a.nivel + 1} al ${b.nivel + 1} solo sigue el ${pc(b.jugadores / a.jugadores)} de la gente.`,
        instruccion: `Rehaz el nivel ${a.nivel + 1} más fácil` });
    }
  }
  const conDatos = niveles.filter((n) => n.intentos >= MIN_INTENTOS);
  const dificiles = consejos.filter((c) => c.tipo === "dificil" || c.tipo === "abandono").length;
  if (conDatos.length >= 3 && dificiles >= Math.ceil(conDatos.length * 0.6)) {
    consejos.unshift({ nivel: null, tipo: "general", texto: "Casi todos los niveles se le atragantan a la gente.",
      instruccion: "Hazlo más fácil" });
  }
  const orden: Record<Consejo["tipo"], number> = { general: 0, abandono: 1, dificil: 2, embudo: 3, facil: 4 };
  consejos.sort((a, b) => orden[a.tipo] - orden[b.tipo] || (a.nivel ?? -1) - (b.nivel ?? -1));
  const jugadores = primero?.sesiones ?? Math.max(0, ...niveles.map((n) => n.jugadores));
  return { version, niveles, consejos, suficiente: conDatos.length > 0, jugadores };
}

function cap(t: string): string {
  return t.charAt(0).toUpperCase() + t.slice(1);
}
