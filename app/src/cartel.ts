// Cartel para el negocio: "Juega y gana" con el premio, el nivel y un QR al juego, listo para
// imprimir en A4 (1240 x 1754 px, 150 ppp) y pegar en el mostrador o el escaparate.

export interface DatosCartel {
  titulo: string;
  premio: string;
  nivel: number;
  donde: string;
  url: string;
  /** Módulos del QR (true = negro), de qrcode-generator. */
  qr: boolean[][];
}

/** Parte un texto en líneas de como mucho `max` letras sin cortar palabras. */
export function partirLineas(texto: string, max: number): string[] {
  const out: string[] = [];
  let linea = "";
  for (const p of texto.split(/\s+/).filter(Boolean)) {
    if (!linea) linea = p;
    else if ((linea + " " + p).length <= max) linea += " " + p;
    else { out.push(linea); linea = p; }
  }
  if (linea) out.push(linea);
  return out;
}

export const ANCHO = 1240;
export const ALTO = 1754;

export function dibujarCartel(c: CanvasRenderingContext2D, d: DatosCartel): void {
  const fondo = "#0f2a4a", laton = "#e8b04b", papel = "#fdf6e3";
  c.fillStyle = fondo;
  c.fillRect(0, 0, ANCHO, ALTO);
  c.fillStyle = laton;
  c.fillRect(60, 60, ANCHO - 120, 14);
  c.fillRect(60, ALTO - 74, ANCHO - 120, 14);
  c.textAlign = "center";
  c.fillStyle = papel;
  c.font = "800 92px system-ui, sans-serif";
  c.fillText("¡JUEGA Y GANA!", ANCHO / 2, 210);
  c.font = "600 54px system-ui, sans-serif";
  c.fillStyle = laton;
  let y = 300;
  for (const l of partirLineas(d.premio, 28)) { c.fillText(l, ANCHO / 2, y); y += 66; }
  c.fillStyle = papel;
  c.font = "400 40px system-ui, sans-serif";
  c.fillText(`Supera el nivel ${d.nivel} de «${d.titulo.slice(0, 30)}»`, ANCHO / 2, y + 30);
  // QR centrado sobre fondo blanco.
  const n = d.qr.length;
  const lado = 760;
  const celda = Math.floor(lado / (n + 8));
  const total = celda * (n + 8);
  const x0 = (ANCHO - total) / 2, y0 = y + 90;
  c.fillStyle = "#ffffff";
  c.fillRect(x0, y0, total, total);
  c.fillStyle = "#000000";
  for (let r = 0; r < n; r++) for (let k = 0; k < n; k++) if (d.qr[r][k]) c.fillRect(x0 + (k + 4) * celda, y0 + (r + 4) * celda, celda, celda);
  y = y0 + total + 80;
  c.fillStyle = papel;
  c.font = "600 44px system-ui, sans-serif";
  c.fillText("Escanéalo con la cámara del móvil", ANCHO / 2, y);
  c.font = "400 36px system-ui, sans-serif";
  y += 64;
  for (const l of partirLineas(d.donde ? `Enseña tu código al pagar · ${d.donde}` : "Enseña tu código al pagar", 46)) {
    c.fillText(l, ANCHO / 2, y);
    y += 48;
  }
}

/** Módulos de un objeto de qrcode-generator. */
export function modulosQr(qr: { getModuleCount(): number; isDark(r: number, c: number): boolean }): boolean[][] {
  const n = qr.getModuleCount();
  return Array.from({ length: n }, (_, r) => Array.from({ length: n }, (_, c) => qr.isDark(r, c)));
}
