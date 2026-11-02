// Prueba A/B de un nivel: ¿supera más gente la versión B que la de siempre (A)?
// Se compara qué parte de los jugadores de cada grupo supera el nivel, con una prueba de dos
// proporciones (z). Solo se da ganadora con datos suficientes y una diferencia clara (95 %).

import type { InformeAb } from "./api";

export const MIN_POR_GRUPO = 30;

export interface VeredictoAb {
  estado: "pocos" | "empate" | "a" | "b";
  a: number | null;
  b: number | null;
  jugadores: number;
  texto: string;
}

const pc = (x: number) => `${Math.round(x * 100)} %`;

export function veredictoAb(inf: InformeAb | null): VeredictoAb {
  const ga = inf?.grupos.a, gb = inf?.grupos.b;
  const na = ga?.jugadores ?? 0, nb = gb?.jugadores ?? 0;
  const pa = na ? (ga!.superan / na) : null, pb = nb ? (gb!.superan / nb) : null;
  const jugadores = na + nb;
  if (na < MIN_POR_GRUPO || nb < MIN_POR_GRUPO || pa === null || pb === null) {
    const falta = Math.max(0, MIN_POR_GRUPO - na) + Math.max(0, MIN_POR_GRUPO - nb);
    return { estado: "pocos", a: pa, b: pb, jugadores,
      texto: `Aún faltan datos: hacen falta ${MIN_POR_GRUPO} jugadores en cada versión (quedan unos ${falta}).` };
  }
  const p = (ga!.superan + gb!.superan) / jugadores;
  const se = Math.sqrt(p * (1 - p) * (1 / na + 1 / nb));
  const z = se > 0 ? (pb - pa) / se : 0;
  if (Math.abs(z) < 1.96) {
    return { estado: "empate", a: pa, b: pb, jugadores,
      texto: `De momento no hay diferencia clara (A: ${pc(pa)} lo superan, B: ${pc(pb)}). Deja que jueguen más o quédate con la que prefieras.` };
  }
  const gana = z > 0 ? "b" : "a";
  return { estado: gana, a: pa, b: pb, jugadores,
    texto: gana === "b"
      ? `La versión B va mejor: lo supera el ${pc(pb)} frente al ${pc(pa)} de la de siempre.`
      : `La de siempre va mejor: lo supera el ${pc(pa)} frente al ${pc(pb)} de la B.` };
}
