// Buscador del catálogo de tipos de juego del taller: sin tildes ni mayúsculas, por nombre, por lo
// que se hace y por palabras de cada familia (escribir «cartas» encuentra el solitario y las cartas
// locas; «coche», las carreras y el aparcamiento). Sin red.

/** Texto plano para comparar: minúsculas y sin tildes (la ñ se queda). */
export function plano(s: string): string {
  return s.toLowerCase().replace(/ñ/g, "\u0001").normalize("NFD").replace(/[̀-ͯ]/g, "").replace(/\u0001/g, "ñ");
}

/** Palabras extra por familia: lo que la gente escribe y no sale en el nombre. */
export const FAMILIAS: Record<string, string[]> = {
  cartas: ["solitario", "cartas", "cartas_locas", "mazo", "domino"],
  mesa: ["ajedrez", "damas", "reversi", "conecta", "parchis", "domino", "flota", "billar"],
  coches: ["carreras", "karts", "conduccion", "aparcamiento", "autobus", "cruzar"],
  palabras: ["sopa", "palabra", "letras", "ahorcado", "preguntas"],
  niños: ["memoria", "pintar", "topos", "simon", "ahorcado", "burbujas", "buscar"],
  puzle: ["puzle", "rompecabezas", "deslizar", "tuberias", "flechas", "numeros", "sudoku", "nonograma", "bloques", "bloques_colores", "tubos", "tornillos", "hexas", "cajas", "laberinto", "diferencias", "buscar"],
  disparos: ["naves", "horda", "arena", "zombis", "arco", "royale", "torres", "arquero"],
  deportes: ["futbol", "penaltis", "baloncesto", "canasta", "tenis", "golf", "bolos", "billar"],
  relax: ["granja", "pesca", "cocina", "pintar", "tuberias", "buscar", "clicker", "tienda"],
};

export interface Tipo {
  id: string;
  nombre: string;
  que: string;
}

/** ¿Encaja el tipo con lo que se busca? Todas las palabras tienen que estar en algún sitio. */
export function encaja(t: Tipo, consulta: string): boolean {
  const q = plano(consulta).trim();
  if (!q) return true;
  const fams = Object.entries(FAMILIAS).filter(([, ids]) => ids.includes(t.id)).map(([f]) => f);
  const texto = plano([t.nombre, t.que, t.id.replace(/_/g, " "), ...fams].join(" "));
  return q.split(/\s+/).every((p) => texto.includes(p) || (p.length > 3 && p.endsWith("s") && texto.includes(p.slice(0, -1))));
}

/** Los últimos en llegar al catálogo llevan la marca «Nuevo». */
export function nuevos(ids: string[], cuantos = 8): Set<string> {
  return new Set(ids.slice(-cuantos));
}
