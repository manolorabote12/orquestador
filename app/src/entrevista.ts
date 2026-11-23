// Entrevista del juego a medida (23 nov 2026). Antes de crear, Chispa hace unas preguntas cortas; con las
// respuestas, el estudio escribe la «biblia» del juego y la respeta en cada paso. Así el juego sale de TU
// idea y no de una plantilla. Cada pregunta tiene sugerencias de un toque y se puede escribir lo que quieras.
// Las claves coinciden con las que acepta el servidor (supabase/functions/create-game: PREGUNTAS).

import { h } from "./ui";

export interface Pregunta {
  id: string;
  texto: string;
  ayuda: string;
  sugerencias: string[];
  /** Solo se elige una de las sugerencias (no se escribe). */
  cerrada?: boolean;
  opcional?: boolean;
}

export const PREGUNTAS: Pregunta[] = [
  { id: "genero", texto: "¿Qué tipo de juego es?", ayuda: "Puede ser una mezcla: «estrategia con monturas», «runner con historia»...",
    sugerencias: ["Estrategia de reino", "RPG por turnos", "Runner", "Gestión / tycoon", "Puzle", "Aventura con decisiones", "Plataformas", "Supervivencia"] },
  { id: "fantasia", texto: "¿Quién eres y dónde pasa?", ayuda: "El protagonista y el mundo: «una farera en una isla con niebla», «un posadero junto a una mazmorra».",
    sugerencias: ["Una reina en un valle maldito", "Un farero en una isla con niebla", "Una corredora entre dos mundos", "Un posadero junto a una mazmorra"] },
  { id: "mecanica", texto: "¿Qué haces en cada partida?", ayuda: "Lo que se repite y engancha: «de día construyes, de noche defiendes».",
    sugerencias: ["De día construyo, de noche defiendo", "Corro y salto entre mundos", "Mejoro mi negocio y mando a gente a misiones", "Combato por turnos con un equipo"] },
  { id: "unico", texto: "¿Qué lo hace distinto a todo lo que hay?", ayuda: "El gancho que hará que alguien lo enseñe: una mecánica, un mundo, un tono.",
    sugerencias: ["Tus decisiones cambian la historia", "El mundo se refleja en el agua", "Los que mueren quedan en un libro de leyendas", "Cada partida el mapa es distinto"] },
  { id: "estetica", texto: "¿Cómo se ve?", ayuda: "El estilo del arte. Todo lo pinta la IA: personajes, fondos, botones y menús.",
    sugerencias: ["Pintado oscuro y épico", "Cuento ilustrado cálido", "Acuarela suave", "Grabado antiguo", "Pixel art", "Cartoon colorido"] },
  { id: "orientacion", texto: "¿Cómo se coge el móvil?", ayuda: "", cerrada: true, sugerencias: ["Vertical", "Horizontal"] },
  { id: "publico", texto: "¿Para quién es?", ayuda: "", cerrada: true, sugerencias: ["Para todos", "Para niños", "Para mayores de 16"] },
  { id: "referencias", texto: "¿A qué juegos se parece un poco? (opcional)", ayuda: "Solo para inspirarse: nunca se copian nombres ni personajes.",
    sugerencias: ["Kingdom Two Crowns", "Darkest Dungeon", "Alto's Odyssey", "Reigns"], opcional: true },
];

export interface Entrevista {
  el: HTMLElement;
  valores(): Record<string, string>;
  /** Faltan respuestas obligatorias (devuelve la primera pregunta sin contestar, o null). */
  falta(): string | null;
  alCambiar(cb: () => void): void;
}

export function crearEntrevista(): Entrevista {
  const valores: Record<string, string> = { orientacion: "Vertical", publico: "Para todos" };
  let aviso: (() => void) | null = null;
  const lista = h("div", { class: "entrevista" });
  PREGUNTAS.forEach((p, i) => {
    const chips = h("div", { class: "chips desliza", role: "group", "aria-label": p.texto });
    const campo = p.cerrada ? null : h("input", { type: "text", maxlength: "300", placeholder: "Escríbelo a tu manera...", "aria-label": p.texto }) as HTMLInputElement;
    const botones: HTMLButtonElement[] = [];
    for (const sug of p.sugerencias) {
      const b = h("button", { class: "chip", type: "button", "aria-pressed": String(valores[p.id] === sug) }, sug) as HTMLButtonElement;
      b.addEventListener("click", () => {
        valores[p.id] = sug;
        if (campo) campo.value = sug;
        for (const x of botones) x.setAttribute("aria-pressed", String(x === b));
        aviso?.();
      });
      botones.push(b);
      chips.append(b);
    }
    campo?.addEventListener("input", () => {
      valores[p.id] = campo.value.trim();
      for (const x of botones) x.setAttribute("aria-pressed", String(x.textContent === campo.value.trim()));
      aviso?.();
    });
    lista.append(h("div", { class: "pregunta" },
      h("p", { class: "pregunta-texto" }, h("span", { class: "pregunta-num" }, String(i + 1)), p.texto),
      p.ayuda ? h("p", { class: "muted small" }, p.ayuda) : "",
      chips, campo ?? ""));
  });
  return {
    el: lista,
    valores: () => Object.fromEntries(Object.entries(valores).filter(([, v]) => v.trim()).map(([k, v]) => [k, v.trim().slice(0, 300)])),
    falta: () => PREGUNTAS.find((p) => !p.opcional && !(valores[p.id] ?? "").trim())?.texto ?? null,
    alCambiar: (cb) => { aviso = cb; },
  };
}
