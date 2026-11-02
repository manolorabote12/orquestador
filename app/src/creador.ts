// Nivel e insignias de creador: lo que has hecho y lo que ha conseguido tu trabajo. Puro (sin
// servidor) para poder probarlo; los datos vienen de perfil_creador().

export interface PerfilCreador {
  juegos: number;
  publicados: number;
  jugadas: number;
  megusta: number;
  remixes: number;
  en_tienda: number;
  podios: number;
  victorias: number;
}

export interface Insignia { id: string; nombre: string; como: string; tiene: boolean }

export const NIVELES: [number, string][] = [[0, "Aprendiz"], [100, "Creador"], [400, "Artesano"], [1500, "Maestro"], [5000, "Leyenda"]];

export function puntos(p: PerfilCreador): number {
  return p.juegos * 10 + p.publicados * 20 + p.jugadas + p.megusta * 5 + p.remixes * 15 + p.en_tienda * 50 + p.podios * 100;
}

/** Nivel actual, el siguiente y cuánto falta (0..1). */
export function nivel(p: PerfilCreador): { nombre: string; siguiente: string | null; faltan: number; progreso: number; puntos: number } {
  const pts = puntos(p);
  let i = 0;
  while (i + 1 < NIVELES.length && pts >= NIVELES[i + 1][0]) i++;
  const sig = NIVELES[i + 1];
  if (!sig) return { nombre: NIVELES[i][1], siguiente: null, faltan: 0, progreso: 1, puntos: pts };
  const base = NIVELES[i][0];
  return { nombre: NIVELES[i][1], siguiente: sig[1], faltan: sig[0] - pts, progreso: (pts - base) / (sig[0] - base), puntos: pts };
}

export function insignias(p: PerfilCreador): Insignia[] {
  return [
    { id: "primer", nombre: "Primer juego", como: "Fabrica tu primer juego", tiene: p.juegos >= 1 },
    { id: "cinco", nombre: "Estudio en marcha", como: "Fabrica 5 juegos", tiene: p.juegos >= 5 },
    { id: "compartido", nombre: "Al mundo", como: "Comparte un juego en el escaparate", tiene: p.publicados >= 1 },
    { id: "cien", nombre: "100 partidas", como: "Que jueguen 100 partidas a tus juegos", tiene: p.jugadas >= 100 },
    { id: "querido", nombre: "Querido", como: "Consigue 25 me gusta", tiene: p.megusta >= 25 },
    { id: "remix", nombre: "Inspirador", como: "Que alguien haga un remix de tu juego", tiene: p.remixes >= 1 },
    { id: "tienda", nombre: "En Google Play", como: "Sube un juego a Google Play", tiene: p.en_tienda >= 1 },
    { id: "podio", nombre: "Podio semanal", como: "Queda entre los 3 primeros de un reto de la semana", tiene: p.podios >= 1 },
    { id: "campeon", nombre: "Campeón", como: "Gana un reto de la semana", tiene: p.victorias >= 1 },
  ];
}
