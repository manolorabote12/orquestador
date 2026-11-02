// Juego regalo: un juego hecho para una persona ("Para Lucía, de Dani") con un mensaje secreto
// que aparece al superar el nivel que elijas, y un enlace privado para mandárselo (no sale en el
// escaparate). El juego regalo no lleva anuncios ni ofertas.

export interface RegaloJuego {
  para: string;
  de: string;
  mensaje: string;
  /** Nivel que hay que superar para ver el mensaje (0 = al acabar el último). */
  tras_nivel: number;
  abierto_en?: string | null;
  leido_en?: string | null;
}

export function mensajeRegalo(m: string): string {
  if (m.includes("bad_name")) return "Los nombres van de 1 a 20 letras, sin símbolos raros.";
  if (m.includes("bad_message")) return "El mensaje va de 1 a 400 letras, sin los símbolos < > { } \\.";
  if (m.includes("bad_level")) return "El nivel va del 0 (al final) al 50.";
  if (m.includes("no_gift")) return "Primero guarda para quién es el regalo y el mensaje.";
  return "No se pudo guardar el regalo.";
}

const RARO = /[<>{}\\]/;

/** Las mismas reglas que el servidor. Devuelve el error o "". */
export function validarRegalo(r: RegaloJuego): string {
  const para = r.para.trim(), de = r.de.trim(), msg = r.mensaje.trim();
  if (!para || !de || para.length > 20 || de.length > 20 || RARO.test(para) || RARO.test(de)) return mensajeRegalo("bad_name");
  if (!msg || msg.length > 400 || RARO.test(msg)) return mensajeRegalo("bad_message");
  if (!Number.isInteger(r.tras_nivel) || r.tras_nivel < 0 || r.tras_nivel > 50) return mensajeRegalo("bad_level");
  return "";
}

/** Ocasiones con un mensaje de ejemplo (se cambia a gusto). */
export const OCASIONES: { ocasion: string; mensaje: string }[] = [
  { ocasion: "Cumpleaños", mensaje: "¡Feliz cumpleaños! Este juego lo he hecho solo para ti. Que cumplas muchos más." },
  { ocasion: "Aniversario", mensaje: "Un año más a tu lado. Gracias por cada día. Te quiero." },
  { ocasion: "San Valentín", mensaje: "Has llegado al final... y yo sigo eligiéndote. ¿Cena el sábado?" },
  { ocasion: "Día de la madre o del padre", mensaje: "Gracias por todo lo que haces. Eres el mejor jugador de esta familia." },
  { ocasion: "Navidad", mensaje: "¡Feliz Navidad! Tu regalo de verdad está escondido debajo del sofá." },
  { ocasion: "Pedir algo especial", mensaje: "¿Quieres ser mi pareja de baile en la boda?" },
];

/** Qué ha pasado con el regalo, para el autor. */
export function estadoRegalo(r: RegaloJuego | null, ahora = new Date()): string {
  if (!r) return "Sin regalo: es un juego normal.";
  const cuando = (iso: string) => {
    const d = new Date(iso);
    const dias = Math.floor((ahora.getTime() - d.getTime()) / 86400000);
    return dias <= 0 ? "hoy" : dias === 1 ? "ayer" : `hace ${dias} días`;
  };
  if (r.leido_en) return `${r.para} ya ha leído tu mensaje (${cuando(r.leido_en)}).`;
  if (r.abierto_en) return `${r.para} abrió el regalo ${cuando(r.abierto_en)}; aún no ha llegado al mensaje.`;
  return `Listo para ${r.para}. Aún no lo ha abierto.`;
}
