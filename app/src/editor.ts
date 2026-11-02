// Editor manual de niveles: lógica pura (sin DOM) para poder probarla.
// Las reglas son las mismas que en la fábrica y el servidor (fabrica/generos.py -> EDITOR):
// aquí sirven para avisar al momento; el servidor las vuelve a comprobar y los bots deciden.

/** Niveles de una versión (fabrica/niveles.json que sube el trabajador). */
export interface NivelesJuego {
  genero: string;
  nombres: string[];
  mapas: string[][];
  enemigos: string[];
  jefe: boolean;
}

export interface Pieza {
  letra: string;
  nombre: string;
  color: string;
  /** Solo puede haber una (salida y meta): al ponerla en otro sitio se mueve. */
  unica?: boolean;
  /** Solo si el juego tiene ese enemigo o el jefe. */
  requiere?: string;
}

const BASE: Pieza[] = [
  { letra: "#", nombre: "Bloque", color: "#5d7fa8" },
  { letra: ".", nombre: "Borrar", color: "transparent" },
  { letra: "C", nombre: "Moneda", color: "#f6cf7a" },
  { letra: "P", nombre: "Salida", color: "#8fe3a5", unica: true },
  { letra: "G", nombre: "Meta", color: "#e8b04b", unica: true },
];
const PLATAFORMAS: Pieza[] = [
  ...BASE,
  { letra: "^", nombre: "Pinchos", color: "#ff6b5b" },
  { letra: "E", nombre: "Enemigo que anda", color: "#d9774a", requiere: "walker" },
  { letra: "K", nombre: "Enemigo con pinchos", color: "#c04a3a", requiere: "spiky" },
  { letra: "F", nombre: "Enemigo que vuela", color: "#b37ad9", requiere: "flyer" },
  { letra: "=", nombre: "Plataforma móvil", color: "#7fb0e0" },
  { letra: "R", nombre: "Punto de control", color: "#9fd8ff" },
  { letra: "H", nombre: "Corazón", color: "#ff8a9a" },
  { letra: "J", nombre: "Doble salto", color: "#6fe0ff" },
  { letra: "M", nombre: "Imán", color: "#ff8a5c" },
  { letra: "V", nombre: "Velocidad", color: "#ffe066" },
  { letra: "I", nombre: "Estrella", color: "#fff2a8" },
  { letra: "B", nombre: "Jefe", color: "#a8323e", requiere: "jefe" },
];

const PIEZAS: Record<string, Pieza[]> = {
  plataformas: PLATAFORMAS,
  runner: PLATAFORMAS.filter((p) => p.letra !== "=" && p.letra !== "B"),
  volador: [...BASE, ...PLATAFORMAS.filter((p) => "RHJMVI".includes(p.letra))],
  rompebloques: [
    { letra: "1", nombre: "Ladrillo (1 golpe)", color: "#7fb0e0" },
    { letra: "2", nombre: "Ladrillo (2 golpes)", color: "#5d7fa8" },
    { letra: "3", nombre: "Ladrillo (3 golpes)", color: "#3e5c84" },
    { letra: "#", nombre: "Acero", color: "#9aa4b2" },
    { letra: "C", nombre: "Ladrillo con moneda", color: "#f6cf7a" },
    { letra: "L", nombre: "Ladrillo de vida", color: "#ff8a9a" },
    { letra: "M", nombre: "Ladrillo multibola", color: "#8fe3a5" },
    { letra: ".", nombre: "Borrar", color: "transparent" },
  ],
};

PIEZAS.cajas = [
  { letra: "#", nombre: "Muro", color: "#5d7fa8" },
  { letra: ".", nombre: "Borrar", color: "transparent" },
  { letra: "B", nombre: "Caja", color: "#b07a3c" },
  { letra: "O", nombre: "Hueco", color: "#e8b04b" },
  { letra: "P", nombre: "Héroe", color: "#8fe3a5", unica: true },
  { letra: "Q", nombre: "Caja en su hueco", color: "#f6cf7a" },
];

PIEZAS.topos = [
  { letra: "o", nombre: "Agujero", color: "#3a2a20" },
  { letra: ".", nombre: "Césped", color: "transparent" },
];

PIEZAS.arena = [
  { letra: "#", nombre: "Muro", color: "#5d7fa8" },
  { letra: ".", nombre: "Borrar", color: "transparent" },
  { letra: "*", nombre: "Arbusto", color: "#3fae49" },
  { letra: "B", nombre: "Caja", color: "#b07a3c" },
  { letra: "R", nombre: "Rival", color: "#ff6b5b" },
  { letra: "P", nombre: "Tú", color: "#8fe3a5", unica: true },
];

PIEZAS.aldea = [
  { letra: "#", nombre: "Muro", color: "#9aa3ad" },
  { letra: ".", nombre: "Borrar", color: "transparent" },
  { letra: "H", nombre: "Ayuntamiento (3x3)", color: "#e8b04b", unica: true },
  { letra: "C", nombre: "Cañón (2x2)", color: "#3a3a44" },
  { letra: "A", nombre: "Torre arquera (2x2)", color: "#a8743f" },
  { letra: "O", nombre: "Mortero (2x2)", color: "#5a5a66" },
  { letra: "G", nombre: "Oro (2x2)", color: "#e9b949" },
  { letra: "E", nombre: "Elixir (2x2)", color: "#b55cff" },
  { letra: "M", nombre: "Mina (2x2)", color: "#a77a4a" },
  { letra: "K", nombre: "Casa (2x2)", color: "#c0503a" },
];

PIEZAS.laberinto = [
  { letra: "#", nombre: "Roca", color: "#5d7fa8" },
  { letra: ".", nombre: "Borrar", color: "transparent" },
  { letra: "C", nombre: "Moneda", color: "#e8b04b" },
  { letra: "X", nombre: "Pinchos", color: "#ff6b5b" },
  { letra: "L", nombre: "Llave", color: "#f6cf7a" },
  { letra: "D", nombre: "Puerta", color: "#c58b4b" },
  { letra: "P", nombre: "Salida", color: "#8fe3a5", unica: true },
];

PIEZAS.golf = [
  { letra: "#", nombre: "Muro", color: "#5d7fa8" },
  { letra: ".", nombre: "Césped", color: "transparent" },
  { letra: "W", nombre: "Agua", color: "#3d8bd9" },
  { letra: "S", nombre: "Arena", color: "#e6cf8b" },
  { letra: "B", nombre: "Bola", color: "#fbfbf6", unica: true },
  { letra: "H", nombre: "Hoyo", color: "#142016", unica: true },
];

PIEZAS.imperio = [
  { letra: ".", nombre: "Hierba", color: "transparent" },
  { letra: "T", nombre: "Árbol (madera)", color: "#2f6b2a" },
  { letra: "B", nombre: "Bayas (comida)", color: "#d8344a" },
  { letra: "O", nombre: "Oro", color: "#ffd23f" },
  { letra: "~", nombre: "Agua", color: "#3b78c2" },
  { letra: "^", nombre: "Roca", color: "#7d7f86" },
  { letra: "P", nombre: "Tu centro (3x3)", color: "#3f8cff", unica: true },
  { letra: "E", nombre: "Centro rival (3x3)", color: "#e0483e" },
  { letra: "c", nombre: "Cuartel rival (2x2)", color: "#b8403a" },
  { letra: "q", nombre: "Arquería rival (2x2)", color: "#a84a3a" },
  { letra: "l", nombre: "Establo rival (2x2)", color: "#9a503a" },
  { letra: "w", nombre: "Taller rival (2x2)", color: "#8a553a" },
  { letra: "h", nombre: "Casa rival (2x2)", color: "#c9b48a" },
  { letra: "t", nombre: "Torre rival", color: "#a9a39a" },
  { letra: "#", nombre: "Empalizada", color: "#8f7d62" },
];

/** Nombre de cada pieza obligatoria para los avisos. */
function unica(genero: string, c: string): [string, string] {
  if (c === "P" && genero === "imperio") return ["Falta tu centro urbano.", "Solo puede haber un centro urbano tuyo."];
  if (c === "P") return ["Falta la salida del héroe.", "Solo puede haber una salida."];
  if (c === "B") return ["Falta la bola.", "Solo puede haber una bola."];
  if (c === "H" && genero === "golf") return ["Falta el hoyo.", "Solo puede haber un hoyo."];
  if (c === "H") return ["Falta el ayuntamiento.", "Solo puede haber un ayuntamiento."];
  return ["Falta la meta.", "Solo puede haber una meta."];
}

const REGLAS: Record<string, { una: string; filas: [number, number]; ancho: [number, number] }> = {
  laberinto: { una: "P", filas: [7, 15], ancho: [5, 11] },
  golf: { una: "BH", filas: [8, 18], ancho: [5, 11] },
  plataformas: { una: "PG", filas: [8, 24], ancho: [16, 300] },
  runner: { una: "PG", filas: [8, 24], ancho: [16, 300] },
  volador: { una: "PG", filas: [10, 24], ancho: [20, 400] },
  rompebloques: { una: "", filas: [3, 12], ancho: [9, 9] },
  cajas: { una: "P", filas: [5, 12], ancho: [5, 12] },
  topos: { una: "", filas: [2, 4], ancho: [3, 4] },
  arena: { una: "P", filas: [11, 31], ancho: [9, 25] },
  aldea: { una: "H", filas: [14, 24], ancho: [14, 24] },
  imperio: { una: "P", filas: [16, 34], ancho: [14, 28] },
};

export function editable(genero: string): boolean {
  return genero in PIEZAS;
}

/** Piezas que se pueden poner en este juego (sin enemigos que no tiene ni jefe si no hay). */
export function piezas(n: Pick<NivelesJuego, "genero" | "enemigos" | "jefe">): Pieza[] {
  return (PIEZAS[n.genero] ?? []).filter((p) => !p.requiere || (p.requiere === "jefe" ? n.jefe : n.enemigos.includes(p.requiere)));
}

/** Pone una pieza. Las únicas (salida, meta) se mueven en vez de duplicarse. Devuelve el mapa nuevo. */
export function pintar(mapa: string[], x: number, y: number, letra: string, genero: string): string[] {
  if (y < 0 || y >= mapa.length || x < 0 || x >= mapa[y].length) return mapa;
  if (mapa[y][x] === letra) return mapa;
  const unicas = REGLAS[genero]?.una ?? "";
  let filas = mapa;
  if (unicas.includes(letra)) filas = filas.map((f) => f.split(letra).join("."));
  return filas.map((f, j) => (j === y ? f.slice(0, x) + letra + f.slice(x + 1) : f));
}

/** Añade o quita columnas al final (los niveles se alargan o se acortan por la derecha). */
export function ancho(mapa: string[], columnas: number): string[] {
  const w = mapa[0]?.length ?? 0;
  if (columnas >= w) {
    const suelo = mapa.length - 1;
    return mapa.map((f, j) => f + (j === suelo ? "#" : ".").repeat(columnas - w));
  }
  return mapa.map((f) => f.slice(0, columnas));
}

/** Avisos al momento (los mismos textos que el servidor). */
export function avisos(n: Pick<NivelesJuego, "genero" | "enemigos" | "jefe">, mapa: string[]): string[] {
  const r = REGLAS[n.genero];
  if (!r) return ["Este tipo de juego aún no se puede editar a mano."];
  const out: string[] = [];
  if (mapa.length < r.filas[0] || mapa.length > r.filas[1]) out.push(`El nivel tiene que tener entre ${r.filas[0]} y ${r.filas[1]} filas.`);
  const w = mapa[0]?.length ?? 0;
  if (mapa.some((f) => f.length !== w)) out.push("Todas las filas tienen que medir lo mismo.");
  else if (w < r.ancho[0] || w > r.ancho[1]) out.push(`El nivel tiene que medir entre ${r.ancho[0]} y ${r.ancho[1]} casillas de ancho.`);
  const validas = new Set(piezas(n).map((p) => p.letra));
  const raras = [...new Set(mapa.join("").split("").filter((c) => !validas.has(c)))];
  if (raras.length) out.push(`Hay casillas que este juego no tiene: ${raras.join(" ")}.`);
  for (const c of r.una) {
    const k = mapa.join("").split(c).length - 1;
    if (k === 0 && !(c === "P" && n.genero === "cajas" && mapa.join("").includes("R"))) out.push(unica(n.genero, c)[0]);
    if (k > 1) out.push(unica(n.genero, c)[1]);
  }
  if (n.genero === "laberinto") {
    const todo = mapa.join("");
    if (!todo.includes("C")) out.push("Pon al menos una moneda.");
    const llaves = todo.split("L").length - 1;
    if (llaves > 1) out.push("Solo puede haber una llave.");
    if (todo.includes("D") && llaves === 0) out.push("Si pones puertas, pon también la llave.");
  }
  if (n.genero === "cajas") {
    const cajas = (mapa.join("").match(/[BQ]/g) ?? []).length;
    const huecos = (mapa.join("").match(/[OQR]/g) ?? []).length;
    if (cajas === 0) out.push("Pon al menos una caja.");
    if (cajas !== huecos) out.push(`Tiene que haber tantos huecos como cajas (${cajas} cajas, ${huecos} huecos).`);
  }
  return out;
}

/** Operaciones del plan manual: solo los niveles que han cambiado. */
export function operaciones(original: string[][], editado: string[][]): { op: "mapa"; indice: number; mapa: string[] }[] {
  return editado.flatMap((m, i) => (m.join("\n") !== (original[i] ?? []).join("\n") ? [{ op: "mapa" as const, indice: i, mapa: m }] : []));
}
