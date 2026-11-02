// Premio real para negocios: el autor regala un cupón de verdad a quien supera el nivel N
// ("10 % en tu próxima compra"). El juego lo lee del servidor al abrirse; cada jugador recibe
// su propio código (el del negocio + 4 letras) para que la tienda los distinga.

/** El premio tal como lo guarda el autor (y lo devuelve el servidor, con cuántos lo han ganado). */
export interface PremioReal {
  texto: string;
  codigo: string;
  tras_nivel: number;
  donde: string;
  web: string;
  /** AAAA-MM-DD o null (sin caducidad). */
  caduca: string | null;
  ganados?: number;
  canjeados?: number;
}

/** Lo que contesta el servidor al canjear un código en la tienda. */
export interface Canje { estado: "ok" | "ya_usado" | "no_existe"; canjeado_en?: string; ganado_en?: string }

/** Deja el código como lo guarda el servidor: sin espacios y en mayúsculas (CAFE-7F3A). */
export function limpiarCodigo(t: string): string {
  return t.replace(/\s+/g, "").toUpperCase();
}

export function codigoValido(t: string): boolean {
  return /^[A-Z0-9]{3,16}-[0-9A-F]{4}$/.test(limpiarCodigo(t));
}

/** La frase que ve el dependiente. */
export function textoCanje(c: Canje): { ok: boolean; texto: string } {
  if (c.estado === "ok") return { ok: true, texto: "Válido: dale el premio. Ya queda marcado como usado." };
  if (c.estado === "ya_usado") {
    const f = c.canjeado_en ? new Date(c.canjeado_en).toLocaleString("es-ES", { day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" }) : "";
    return { ok: false, texto: `Ya se usó${f ? " el " + f : ""}. No vale otra vez.` };
  }
  return { ok: false, texto: "Ese código no existe en este juego. Revisa que esté bien escrito." };
}

/** Error del servidor al guardar el premio, dicho para el autor. */
export function mensajePremio(m: string): string {
  if (m.includes("bad_text")) return "El premio no vale: de 3 a 80 letras, sin símbolos raros ni palabrotas.";
  if (m.includes("bad_place")) return "La dirección no vale: hasta 80 letras, sin símbolos raros.";
  if (m.includes("bad_code")) return "El código va de 3 a 16 letras o números, sin espacios.";
  if (m.includes("bad_level")) return "El nivel va del 1 al 50.";
  if (m.includes("bad_web")) return "La web tiene que empezar por https://";
  if (m.includes("bad_date")) return "La fecha de caducidad ya ha pasado.";
  return "No se pudo guardar el premio.";
}

/** Las mismas reglas que el servidor (para avisar antes de enviar). Devuelve el error o "". */
export function validarPremio(p: PremioReal, hoy = new Date()): string {
  const texto = p.texto.trim();
  if (texto.length < 3 || texto.length > 80 || /[<>{}\\]/.test(texto)) return mensajePremio("bad_text");
  if (p.donde.trim().length > 80 || /[<>{}\\]/.test(p.donde)) return mensajePremio("bad_place");
  if (!/^[A-Z0-9]{3,16}$/.test(p.codigo.trim().toUpperCase())) return mensajePremio("bad_code");
  if (!Number.isInteger(p.tras_nivel) || p.tras_nivel < 1 || p.tras_nivel > 50) return mensajePremio("bad_level");
  const web = p.web.trim();
  if (web !== "" && !/^https:\/\/[^ <>"]{4,200}$/.test(web)) return mensajePremio("bad_web");
  if (p.caduca && p.caduca < hoy.toISOString().slice(0, 10)) return mensajePremio("bad_date");
  return "";
}

/** Ideas para empezar, por tipo de negocio (el autor elige una y la cambia a su gusto). */
export const IDEAS_PREMIO: { negocio: string; texto: string; codigo: string; nivel: number }[] = [
  { negocio: "Cafetería o panadería", texto: "Café gratis con tu desayuno", codigo: "CAFE", nivel: 3 },
  { negocio: "Tienda", texto: "10 % de descuento en tu próxima compra", codigo: "JUEGO10", nivel: 5 },
  { negocio: "Restaurante", texto: "Postre gratis en tu próxima comida", codigo: "POSTRE", nivel: 5 },
  { negocio: "Peluquería o estética", texto: "5 € de descuento en tu próxima cita", codigo: "CITA5", nivel: 4 },
  { negocio: "Gimnasio o academia", texto: "Una clase de prueba gratis", codigo: "PRUEBA", nivel: 3 },
  { negocio: "Tienda online", texto: "Envío gratis en tu próximo pedido", codigo: "ENVIO", nivel: 5 },
];

/** Cómo se lo cuenta la app al autor. */
export function resumenPremio(p: PremioReal | null): string {
  if (!p) return "Sin premio. Los jugadores no ven nada.";
  const hasta = p.caduca ? ` · hasta el ${p.caduca.split("-").reverse().join("/")}` : "";
  return `Al superar el nivel ${p.tras_nivel}: «${p.texto}» · código ${p.codigo}-XXXX${hasta} · ganado ${p.ganados ?? 0} veces · canjeado ${p.canjeados ?? 0}`;
}
