// Reglas del plan de cambio en el servidor (las mismas que fabrica/director/cambios.py).
// Puras: sin red ni Deno, para poder probarlas fuera. La validación de esquema se inyecta.

import { EDITOR, GENEROS, GIROS, PRECIOS_CAMBIO, PROTEGIDOS } from "./cambios-datos.ts";
export { PRECIOS_CAMBIO };

export interface Operacion {
  op: string;
  [k: string]: unknown;
}
export interface Plan {
  resumen: string;
  pregunta?: string;
  no_puedo?: string;
  operaciones: Operacion[];
}
export interface Diseno {
  titulo: string;
  niveles: string[];
  enemigos: { tipo: string; nombre: string; descripcion: string }[];
  [k: string]: unknown;
}

const ARTE_TOTAL = new Set(["estilo", "paleta"]);

/** Tuercas que cuesta aplicar el plan. La IA nunca decide el precio. */
export function costePlan(plan: Plan): number {
  const ops = plan.operaciones.map((o) => o.op);
  if (ops.length === 0) return 0;
  const arteTotal = ops.some((o) => ARTE_TOTAL.has(o));
  let total = PRECIOS_CAMBIO.base;
  plan.operaciones.forEach((op) => {
    const o = op.op;
    if (o === "redibujar" && arteTotal) return;
    if (o === "jefe" && op.activo === false) { total += PRECIOS_CAMBIO.jefe_quitar; return; }
    if (o === "prueba_ab" && (op.ganadora || op.activo === false)) { total += PRECIOS_CAMBIO.prueba_ab_fin; return; }
    total += PRECIOS_CAMBIO[o] ?? 999;
  });
  return total;
}

const REQUISITOS: Record<string, string[]> = {
  textos: [], ajustes: [], redibujar: ["que", "descripcion"], paleta: ["paleta"],
  estilo: ["familia", "descripcion"], anadir_enemigo: ["tipo", "nombre", "descripcion"],
  quitar_enemigo: ["tipo"], anadir_nivel: ["nombre"], quitar_nivel: ["indice"], rehacer_nivel: ["indice"],
  poderes: [], disparo: ["activo"], jefe: ["activo"], musica: ["ambiente"], extras: [],
  genero: ["genero"], vista: ["vista"], historia: [], mapa: ["indice", "mapa"], preguntas: ["preguntas"],
  funciones: [], prueba_ab: [], giros: ["giros"], idiomas: ["idiomas"],
};

/** Giros que valen en un genero (fabrica/giros.py). */
export function girosDe(genero: string): string[] {
  return Object.entries(GIROS).filter(([, g]) => g.generos === "*" || g.generos.includes(genero)).map(([id]) => id);
}

function luminancia(hex: string): number {
  const c = [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16) / 255)
    .map((v) => (v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4)));
  return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
}

/** Reglas rápidas del editor manual (las mismas que generos.problemas_mapa en la fábrica). */
export function problemasMapa(genero: string, mapa: unknown): string[] {
  const e = EDITOR[genero];
  if (!e) return [`los niveles de un juego de tipo ${genero} aun no se pueden editar a mano`];
  if (!Array.isArray(mapa) || !mapa.every((f) => typeof f === "string")) return ["el mapa tiene que ser una lista de filas de texto"];
  const filas = mapa as string[];
  const out: string[] = [];
  if (filas.length < e.filas[0] || filas.length > e.filas[1]) out.push(`el nivel tiene que tener entre ${e.filas[0]} y ${e.filas[1]} filas`);
  const anchos = new Set(filas.map((f) => f.length));
  if (anchos.size !== 1) out.push("todas las filas tienen que medir lo mismo");
  else {
    const w = [...anchos][0];
    if (w < e.ancho[0] || w > e.ancho[1]) out.push(`el nivel tiene que medir entre ${e.ancho[0]} y ${e.ancho[1]} casillas de ancho`);
  }
  const raras = [...new Set(filas.join("").split("").filter((c) => !e.letras.includes(c)))].sort();
  if (raras.length) out.push("casillas que no existen en este tipo de juego: " + raras.join(" "));
  for (const c of e.una) {
    const n = filas.join("").split(c).length - 1;
    if (n !== 1) {
      out.push(c === "P" ? "tiene que haber exactamente un punto de salida del heroe"
        : c === "G" ? "tiene que haber exactamente una meta" : `tiene que haber exactamente un '${c}'`);
    }
  }
  return out;
}

/** Vista con la que se dibuja el juego (generos.vista en la fábrica): "3d" o "2d". */
export function vistaDe(diseno: Diseno, genero: string): string {
  const g = GENEROS[genero];
  if (!g || !g.vista_3d) return "2d";
  return String(diseno.vista ?? (g.nace_3d ? "3d" : "2d"));
}

/** Lo que el género no admite (mismo código que regla_genero en fabrica/director/cambios.py). */
export function reglaGenero(genero: string, o: Operacion): string {
  const g = GENEROS[genero] ?? GENEROS.plataformas;
  if (o.op === "jefe" && o.activo === true && !g.jefe) return `un juego de tipo ${genero} no lleva jefe final`;
  if (o.op === "disparo" && !g.disparo) return `en un juego de tipo ${genero} no hay disparo`;
  if (o.op === "poderes" && !g.poderes) return `en un juego de tipo ${genero} no hay poderes`;
  if (o.op === "preguntas" && genero !== "preguntas") return "las preguntas solo existen en los juegos de preguntas";
  if (o.op === "vista" && !g.vista_3d) {
    return "la vista 3D de momento solo existe en " + Object.keys(GENEROS).filter((k) => GENEROS[k].vista_3d).join(", ");
  }
  if (o.op === "extras" && !g.extras) return `en un juego de tipo ${genero} no hay puntos de control ni plataformas moviles`;
  if (o.op === "extras" && o.plataformas_moviles === true && genero !== "plataformas") {
    return `en un juego de tipo ${genero} no hay plataformas moviles (no se puede frenar)`;
  }
  if (o.op === "anadir_enemigo" && (!g.enemigos || g.enemigos_fijos)) return `en un juego de tipo ${genero} no se pueden anadir enemigos`;
  if (o.op === "quitar_enemigo" && g.enemigos_fijos) return `en un juego de tipo ${genero} no se pueden quitar enemigos`;
  return "";
}

/** Errores del plan frente al juego actual (vacío = válido). esquema: validador de JSON Schema. */
export function validarPlan(plan: unknown, diseno: Diseno, esquema: (p: unknown) => string[]): string[] {
  const errores = esquema(plan);
  if (errores.length) return errores;
  const p = plan as Plan;
  const n = diseno.niveles.length;
  const tipos = new Set(diseno.enemigos.map((e) => e.tipo));
  let niveles = n;
  const textos: string[] = [];
  const actual = String(diseno.genero ?? "plataformas");
  const genero = String(p.operaciones.find((o) => o.op === "genero")?.genero ?? actual);
  p.operaciones.forEach((o, i) => {
    if (o.op === "genero" && o.genero === actual) errores.push(`operaciones/${i}: eso ya esta asi en el juego`);
    const motivo = reglaGenero(genero, o);
    if (motivo) errores.push(`operaciones/${i}: ${motivo}`);
    for (const campo of REQUISITOS[o.op] ?? []) {
      if (!(campo in o)) errores.push(`operaciones/${i}: '${o.op}' necesita '${campo}'`);
    }
    const indice = typeof o.indice === "number" ? o.indice : 0;
    if ((o.op === "quitar_nivel" || o.op === "rehacer_nivel") && indice >= n) {
      errores.push(`operaciones/${i}: el juego tiene ${n} niveles (índices 0 a ${n - 1})`);
    }
    if (o.op === "anadir_enemigo" && tipos.has(String(o.tipo))) errores.push(`operaciones/${i}: ya hay un enemigo de tipo ${o.tipo}`);
    if (o.op === "quitar_enemigo" && !tipos.has(String(o.tipo))) errores.push(`operaciones/${i}: no hay enemigo de tipo ${o.tipo}`);
    if (o.op === "redibujar" && String(o.que ?? "").startsWith("enemigo_") && !tipos.has(String(o.que).slice(8))) {
      errores.push(`operaciones/${i}: no hay ${o.que} que redibujar`);
    }
    if (o.op === "poderes" && !((o.activar as unknown[] | undefined)?.length || (o.desactivar as unknown[] | undefined)?.length)) {
      errores.push(`operaciones/${i}: 'poderes' necesita 'activar' o 'desactivar'`);
    }
    if (o.op === "jefe" && o.activo === true && !(o.nombre && o.descripcion)) {
      errores.push(`operaciones/${i}: para poner un jefe hacen falta 'nombre' y 'descripcion'`);
    }
    if (o.op === "jefe" && o.activo === false && !diseno.jefe) errores.push(`operaciones/${i}: el juego no tiene jefe que quitar`);
    if (o.op === "redibujar" && o.que === "jefe" && !diseno.jefe) errores.push(`operaciones/${i}: el juego no tiene jefe`);
    if (o.op === "extras") {
      if (!("puntos_control" in o) && !("plataformas_moviles" in o)) {
        errores.push(`operaciones/${i}: 'extras' necesita 'puntos_control' o 'plataformas_moviles'`);
      }
      const ex = (diseno.extras ?? {}) as Record<string, boolean>;
      const igual = (["puntos_control", "plataformas_moviles"] as const).filter((k) => k in o)
        .every((k) => (ex[k] ?? k === "puntos_control") === o[k]);
      if (igual) errores.push(`operaciones/${i}: eso ya esta asi en el juego`);
    }
    if (o.op === "disparo" && Boolean(diseno.disparo) === Boolean(o.activo)) errores.push(`operaciones/${i}: eso ya esta asi en el juego`);
    if (o.op === "mapa" && "mapa" in o) {
      for (const pr of problemasMapa(genero, o.mapa)) errores.push(`operaciones/${i}: ${pr}`);
      const letras = new Set((Array.isArray(o.mapa) ? (o.mapa as string[]) : []).join("").split(""));
      const faltan = ([["E", "walker"], ["K", "spiky"], ["F", "flyer"]] as const)
        .filter(([c, t]) => letras.has(c) && !tipos.has(t)).map(([, t]) => t);
      if (faltan.length) errores.push(`operaciones/${i}: el juego no tiene enemigos de tipo ${faltan.join(", ")}`);
      if (letras.has("B") && !diseno.jefe) errores.push(`operaciones/${i}: para poner al jefe en un nivel, el juego tiene que tener jefe`);
      if (Number(o.indice ?? 0) >= n) errores.push(`operaciones/${i}: el juego tiene ${n} niveles (indices 0 a ${n - 1})`);
    }
    if (o.op === "mapa" && p.operaciones.some((x) => ["anadir_nivel", "quitar_nivel", "genero"].includes(x.op))) {
      errores.push(`operaciones/${i}: un nivel editado a mano no se puede mezclar con anadir o quitar niveles ni cambiar de genero`);
    }
    if (o.op === "historia" && o.activo === false && !diseno.historia) errores.push(`operaciones/${i}: el juego no tiene historia que quitar`);
    if (o.op === "historia" && o.activo !== false && !o.historia) {
      errores.push(`operaciones/${i}: 'historia' necesita los dialogos nuevos (o activo false para quitarlos)`);
    }
    if (o.op === "historia" && o.historia) {
      for (const n of ((o.historia as { niveles?: { intro?: { texto: string }[]; fin?: { texto: string }[] }[] }).niveles ?? [])) {
        for (const l of [...(n.intro ?? []), ...(n.fin ?? [])]) textos.push(l.texto);
      }
    }
    if (o.op === "vista" && vistaDe(diseno, genero) === o.vista) errores.push(`operaciones/${i}: eso ya esta asi en el juego`);
    if (o.op === "anadir_nivel") niveles++;
    if (o.op === "quitar_nivel") niveles--;
    if (o.op === "paleta" && Array.isArray(o.paleta)) {
      const pal = o.paleta as string[];
      if (luminancia(pal[0]) > 0.12) errores.push(`operaciones/${i}: el primer color (cielo) debe ser oscuro`);
      if (pal.filter((c) => luminancia(c) < 0.1).length < 2) errores.push(`operaciones/${i}: hacen falta 2 colores oscuros`);
      if (!pal.some((c) => luminancia(c) > 0.65)) errores.push(`operaciones/${i}: hace falta un color claro`);
    }
    for (const k of ["titulo", "lema", "heroe_nombre", "nombre", "descripcion"]) {
      if (typeof o[k] === "string") textos.push(o[k] as string);
    }
    if (o.op === "giros") {
      const vale = girosDe(genero);
      const malos = ((o.giros as string[] | undefined) ?? []).filter((g) => !vale.includes(g));
      if (malos.length) errores.push(`operaciones/${i}: en un juego de tipo ${genero} no existe el giro ${malos.join(", ")}`);
    }
    if (o.referencia && (o.op !== "redibujar" || o.que !== "heroe")) {
      errores.push(`operaciones/${i}: la referencia (tu dibujo) solo vale para redibujar al heroe`);
    }
    if (o.op === "prueba_ab") {
      const fin = Boolean(o.ganadora) || o.activo === false;
      if (fin && !diseno.prueba_ab) errores.push(`operaciones/${i}: no hay ninguna prueba A/B en marcha`);
      if (!fin && diseno.prueba_ab) errores.push(`operaciones/${i}: ya hay una prueba A/B en marcha; terminala antes de empezar otra`);
      if (!fin && (typeof o.indice !== "number" || o.indice >= n)) errores.push(`operaciones/${i}: 'prueba_ab' necesita el 'indice' de un nivel (0 a ${n - 1})`);
      if (p.operaciones.some((x) => ["anadir_nivel", "quitar_nivel", "genero"].includes(x.op))) {
        errores.push(`operaciones/${i}: una prueba A/B no se puede mezclar con anadir o quitar niveles ni cambiar de genero`);
      }
    }
    for (const nn of (o.nombres_niveles as { indice: number; nombre: string }[] | undefined) ?? []) {
      if (nn.indice >= n) errores.push(`operaciones/${i}: índice de nivel fuera de rango`);
      textos.push(nn.nombre);
    }
  });
  if (niveles < 3 || niveles > 8) errores.push("el juego debe tener entre 3 y 8 niveles");
  if (genero === "preguntas") {
    const op = p.operaciones.find((o) => o.op === "preguntas");
    const qs = (op?.preguntas ?? diseno.preguntas ?? []) as { pregunta: string; opciones: string[] }[];
    if (qs.length < 3 * niveles) errores.push(`preguntas: hacen falta al menos 3 por nivel (${3 * niveles} para ${niveles} niveles)`);
    for (const q of op ? qs : []) {
      textos.push(q.pregunta, ...q.opciones);
      if (new Set(q.opciones.map((x) => x.trim().toLowerCase())).size !== 4) errores.push("preguntas: las 4 opciones tienen que ser distintas");
    }
  }
  const todo = textos.join(" ").toLowerCase();
  for (const nombre of PROTEGIDOS) {
    if (new RegExp(`\\b${nombre.replace(/[.*+?^${}()|[\]\\-]/g, "\\$&")}\\b`).test(todo)) {
      errores.push(`contenido protegido: '${nombre}'. Crea un equivalente original`);
    }
  }
  return errores;
}

/** Contexto que lee la IA: el juego actual y la memoria de cambios. */
export function contexto(diseno: Diseno, historial: { version: number; prompt: string }[]): string {
  const resumen = {
    titulo: diseno.titulo, lema: diseno.lema, genero: diseno.genero ?? "plataformas", estilo: diseno.estilo, heroe: diseno.heroe,
    vista: vistaDe(diseno, String(diseno.genero ?? "plataformas")),
    coleccionable: diseno.coleccionable, escenario: diseno.escenario, enemigos: diseno.enemigos,
    sensacion: diseno.sensacion, dificultad: diseno.dificultad,
    poderes: diseno.poderes ?? [], disparo: diseno.disparo ?? false, jefe: diseno.jefe ?? null, extras: diseno.extras ?? {},
    musica: diseno.musica,
    niveles: diseno.niveles.map((nombre, indice) => ({ indice, nombre })),
    historia: diseno.historia ?? null,
    prueba_ab: diseno.prueba_ab ?? null,
  };
  const cambios = historial.slice(-10).map((h) => `v${h.version}: ${h.prompt}`).join("\n") || "(ninguno)";
  return `JUEGO ACTUAL:\n${JSON.stringify(resumen, null, 1)}\n\nCAMBIOS ANTERIORES (memoria del proyecto):\n${cambios}`;
}
