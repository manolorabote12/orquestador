// Cuenta atrás corta para retos y eventos: "3 d 4 h", "5 h" o "20 min" (nunca negativa).

/** "3 d 4 h" o "5 h" hasta que termine (nunca negativo). */
export function quedan(termina: string, ahora = new Date()): string {
  const ms = Math.max(0, new Date(termina).getTime() - ahora.getTime());
  const d = Math.floor(ms / 86400000);
  const hrs = Math.floor((ms % 86400000) / 3600000);
  if (d > 0) return `${d} d ${hrs} h`;
  const min = Math.floor((ms % 3600000) / 60000);
  return hrs > 0 ? `${hrs} h` : `${min} min`;
}
