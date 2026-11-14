// Compras a medida de cada juego: lo que el creador quiera vender (moneda propia, packs con su
// precio, sin anuncios, pase y VIP de suscripcion). Las mismas reglas que fabrica/play/tienda.py y
// que la funcion set_project_tienda del servidor. Van en la version de Google Play (el dinero es
// todo del creador); en la galeria web, de momento, solo se apunta quien quiso comprar.

export type TipoCompra = "monedas" | "sin_anuncios" | "pack" | "pase" | "vip";
export type PeriodoVip = "semana" | "mes" | "anio";

export interface CompraJuego {
  id: string;
  tipo: TipoCompra;
  precio_cent: number;
  nombre?: string;
  cantidad?: number;
  periodo?: PeriodoVip;
  extra_pct?: number;
  diario?: number;
  sin_anuncios?: boolean;
}

export interface TiendaJuego {
  moneda: { nombre: string; icono: string };
  productos: CompraJuego[];
}

export const ICONOS_MONEDA: Record<string, string> = { gem: "Gema", coin: "Moneda", star: "Estrella", heart: "Corazón", trophy: "Trofeo", cube: "Cubo" };
export const TIPOS_COMPRA: Record<TipoCompra, string> = {
  monedas: "Pack de moneda", sin_anuncios: "Sin anuncios", pack: "Pack (moneda + sin anuncios)", pase: "Pase premium", vip: "VIP (suscripción)",
};
export const PERIODOS_VIP: Record<PeriodoVip, string> = { semana: "a la semana", mes: "al mes", anio: "al año" };

/** Tiendas de partida: el creador elige una y la cambia a su gusto. */
export const PLANTILLAS_TIENDA: Record<string, { nombre: string; tienda: TiendaJuego }> = {
  gemas: { nombre: "Gemas (como los juegos de arena)", tienda: { moneda: { nombre: "Gemas", icono: "gem" }, productos: [
    { id: "gemas_80", tipo: "monedas", cantidad: 80, precio_cent: 99 },
    { id: "gemas_500", tipo: "monedas", cantidad: 500, precio_cent: 499, nombre: "500 gemas (+25 %)" },
    { id: "gemas_1200", tipo: "monedas", cantidad: 1200, precio_cent: 999, nombre: "1200 gemas (+50 %)" },
    { id: "sin_anuncios", tipo: "sin_anuncios", precio_cent: 299 },
    { id: "pase", tipo: "pase", precio_cent: 499 },
    { id: "vip_mes", tipo: "vip", precio_cent: 399, periodo: "mes", extra_pct: 50, diario: 20, sin_anuncios: true },
  ] } },
  sencilla: { nombre: "Sencilla: monedas y quitar anuncios", tienda: { moneda: { nombre: "Monedas", icono: "coin" }, productos: [
    { id: "monedas_1000", tipo: "monedas", cantidad: 1000, precio_cent: 99 },
    { id: "monedas_6000", tipo: "monedas", cantidad: 6000, precio_cent: 499 },
    { id: "sin_anuncios", tipo: "sin_anuncios", precio_cent: 199 },
  ] } },
  bienvenida: { nombre: "Con oferta de bienvenida", tienda: { moneda: { nombre: "Perlas", icono: "gem" }, productos: [
    { id: "pack_bienvenida", tipo: "pack", cantidad: 3000, precio_cent: 199, nombre: "Pack de bienvenida" },
    { id: "perlas_500", tipo: "monedas", cantidad: 500, precio_cent: 99 },
    { id: "perlas_3500", tipo: "monedas", cantidad: 3500, precio_cent: 499 },
    { id: "vip_semana", tipo: "vip", precio_cent: 149, periodo: "semana", extra_pct: 100, diario: 50, sin_anuncios: true },
  ] } },
};

/** Codigo de producto a partir de un nombre ("500 Gemas" -> "gemas_500"). */
export function codigoCompra(t: CompraJuego, moneda: string): string {
  const limpio = (s: string) => s.toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "").replace(/[^a-z0-9]+/g, "_").replace(/^_+|_+$/g, "");
  const base = t.tipo === "monedas" ? `${limpio(moneda) || "moneda"}_${t.cantidad ?? 0}` : t.tipo === "pack" ? `pack_${t.cantidad ?? 0}`
    : t.tipo === "vip" ? `vip_${t.periodo ?? "mes"}` : t.tipo;
  const id = /^[a-z]/.test(base) ? base : `p_${base}`;
  return id.slice(0, 40).padEnd(3, "x");
}

export function euros(cent: number): string {
  return `${Math.floor(cent / 100)},${String(cent % 100).padStart(2, "0")} €`;
}

/** Errores en palabras del creador (null = vale). */
export function validarTiendaJuego(t: TiendaJuego): string | null {
  const nombre = t.moneda.nombre.trim();
  if (nombre.length < 1 || nombre.length > 20) return "Pon un nombre a tu moneda (de 1 a 20 letras: Gemas, Perlas...).";
  if (!(t.moneda.icono in ICONOS_MONEDA)) return "Elige el dibujo de la moneda.";
  if (t.productos.length < 1 || t.productos.length > 12) return "Pon de 1 a 12 cosas a la venta.";
  const vistos = new Set<string>();
  let vip = 0, pase = 0;
  for (const p of t.productos) {
    if (!/^[a-z][a-z0-9_]{2,39}$/.test(p.id)) return `El código «${p.id}» va en minúsculas y sin espacios (letras, números y _).`;
    if (vistos.has(p.id)) return `Hay dos productos con el código «${p.id}»: cambia uno.`;
    vistos.add(p.id);
    if (!Number.isInteger(p.precio_cent) || p.precio_cent < 10 || p.precio_cent > 9999) return `«${p.nombre || p.id}»: el precio va de 0,10 € a 99,99 €.`;
    if ((p.tipo === "monedas" || p.tipo === "pack") && !(Number.isInteger(p.cantidad) && (p.cantidad ?? 0) >= 1 && (p.cantidad ?? 0) <= 1_000_000)) {
      return `«${p.nombre || p.id}»: la cantidad va de 1 a 1.000.000.`;
    }
    if ((p.nombre ?? "").length > 40) return `«${p.nombre}»: el nombre tiene como mucho 40 letras.`;
    if (p.tipo === "vip") {
      vip++;
      if ((p.extra_pct ?? 0) < 0 || (p.extra_pct ?? 0) > 300 || (p.diario ?? 0) < 0 || (p.diario ?? 0) > 100_000) {
        return "VIP: el extra va de 0 a 300 % y el regalo diario de 0 a 100.000.";
      }
    }
    if (p.tipo === "pase") pase++;
  }
  if (vip > 2) return "Como mucho 2 suscripciones VIP.";
  if (pase > 1) return "Solo un pase premium.";
  return null;
}

const ERRORES_TIENDA: Record<string, string> = {
  bad_currency: "Pon un nombre a tu moneda (de 1 a 20 letras).", bad_icon: "Elige el dibujo de la moneda.",
  bad_products: "Pon de 1 a 12 cosas a la venta.", bad_id: "Hay un código de producto mal escrito o repetido.",
  bad_kind: "Hay un producto de un tipo desconocido.", bad_price: "Los precios van de 0,10 € a 99,99 €.",
  bad_amount: "Las cantidades van de 1 a 1.000.000.", bad_name: "Los nombres tienen como mucho 40 letras.",
  bad_period: "El VIP se cobra por semana, mes o año.", bad_vip: "VIP: extra de 0 a 300 % y regalo de 0 a 100.000.",
  too_many_vip: "Como mucho 2 suscripciones VIP.", too_many_pass: "Solo un pase premium.",
};

export function errorTienda(mensaje: string): string {
  const k = Object.keys(ERRORES_TIENDA).find((c) => mensaje.includes(c));
  return k ? ERRORES_TIENDA[k] : "No se pudo guardar la tienda.";
}
