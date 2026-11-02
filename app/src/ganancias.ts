// Calculadora de ganancias: cuánto podría dar un juego al mes con anuncios (y tienda), a partir
// de las descargas al día, cuánta gente vuelve (D1 y D7), el mercado y el tipo de juego.
// Es una estimación orientativa con medias del sector (eCPM de AdMob por zonas, anuncios por
// sesión según cómo pone los anuncios OrqKit) y siempre se da como horquilla. Sin red ni IA.

export type Mercado = "espana" | "latam" | "tier1" | "mundo";
export type TipoJuego = "corto" | "largo" | "idle";

export interface EntradaGanancias {
  descargasDia: number;
  /** Porcentaje (0-100) que vuelve al día siguiente y a los 7 días. */
  d1: number;
  d7: number;
  mercado: Mercado;
  tipo: TipoJuego;
  infantil?: boolean;
  tienda?: boolean;
  anuncios?: boolean;
}

export interface Horquilla { min: number; med: number; max: number }

export interface Ganancias {
  /** Jugadores al día cuando el juego lleva un mes con esas descargas. */
  jugadoresDia: number;
  intersticialesDia: number;
  bonificadosDia: number;
  anunciosMes: Horquilla;
  tiendaMes: Horquilla;
  totalMes: Horquilla;
  /** Lo que deja cada descarga en sus primeros 30 días (euros). */
  porDescarga: number;
  /** Descargas al día que harían falta para 100 € al mes (estimación media). */
  descargasPara100: number;
}

export const NOMBRE_MERCADO: Record<Mercado, string> = {
  espana: "España y Europa", latam: "Latinoamérica", tier1: "EE. UU., Reino Unido y norte de Europa", mundo: "Todo el mundo",
};

// eCPM medio (euros por 1000 anuncios vistos) de AdMob en juegos casuales.
const ECPM: Record<"inter" | "bonif", Record<Mercado, number>> = {
  inter: { tier1: 9, espana: 5, latam: 1.6, mundo: 3 },
  bonif: { tier1: 14, espana: 8, latam: 2.5, mundo: 5 },
};
// Compras dentro del juego por jugador y día (euros, antes de la comisión de Google).
const IAP_DIA: Record<TipoJuego, number> = { corto: 0.004, largo: 0.012, idle: 0.01 };
const IAP_MERCADO: Record<Mercado, number> = { tier1: 1.6, espana: 1, latam: 0.35, mundo: 0.6 };
// Cómo se juega cada tipo: sesiones al día, minutos por sesión, segundos por nivel y bonificados al día.
const USO: Record<TipoJuego, { sesiones: number; minutos: number; nivel: number; bonif: number }> = {
  corto: { sesiones: 1.6, minutos: 6, nivel: 75, bonif: 0.6 },
  largo: { sesiones: 1.4, minutos: 11, nivel: 180, bonif: 1 },
  idle: { sesiones: 3, minutos: 4, nivel: 300, bonif: 2.5 },
};
// Lo mismo que hace OrqKit (kit/ads.gd): nada el primer minuto, 90 s entre anuncios, 6 por sesión.
const GRACIA = 60, ESPERA = 90, MAX_SESION = 6;
const RELLENO = 0.9;
// No todas las sesiones llegan a la media (mucha gente juega un rato corto): se ve el 70 %.
const VISTO = 0.7;

const IDLE = new Set(["clicker", "minas", "tycoon", "imperio", "ciudad", "reino", "granja", "aldea", "tienda", "tragaperras", "pedidos"]);
const LARGO = new Set(["rpg", "mazmorras", "mazo", "aventura", "supervivencia", "mundo", "royale", "duelo", "arena", "conduccion", "terror", "a_medida"]);

export function tipoDeGenero(genero: string | undefined): TipoJuego {
  const g = genero ?? "";
  return IDLE.has(g) ? "idle" : LARGO.has(g) ? "largo" : "corto";
}

/** Fracción de jugadores que siguen el día t (t = 0 el de la descarga), curva potencia por D1 y D7. */
export function retencion(d1: number, d7: number, t: number): number {
  if (t <= 0) return 1;
  const r1 = Math.min(0.95, Math.max(0.01, d1 / 100));
  const r7 = Math.min(r1, Math.max(0.002, d7 / 100));
  const b = Math.log(r1 / r7) / Math.log(7);
  return r1 * Math.pow(t, -b);
}

function redondeo(n: number): number {
  return Math.round(n * 100) / 100;
}

export function estimar(e: EntradaGanancias): Ganancias {
  const descargas = Math.max(0, e.descargasDia);
  let vida = 0;
  for (let t = 0; t < 30; t++) vida += retencion(e.d1, e.d7, t);
  const jugadores = descargas * vida;
  const u = USO[e.tipo];
  const porSesion = Math.max(0, Math.min(MAX_SESION, Math.floor((u.minutos * 60 - GRACIA) / Math.max(ESPERA, u.nivel)) + 1));
  const conAnuncios = e.anuncios !== false;
  const inter = conAnuncios ? u.sesiones * porSesion : 0;
  const bonif = conAnuncios ? u.bonif : 0;
  const ninos = e.infantil ? 0.45 : 1;
  const anuncioDia = (inter * ECPM.inter[e.mercado] + bonif * ECPM.bonif[e.mercado]) / 1000 * RELLENO * VISTO * ninos;
  const anunciosMes = jugadores * anuncioDia * 30;
  const tiendaMes = e.tienda && !e.infantil ? jugadores * IAP_DIA[e.tipo] * IAP_MERCADO[e.mercado] * 30 * 0.85 : 0;
  const med = anunciosMes + tiendaMes;
  const porDescarga = vida * (anuncioDia + (e.tienda && !e.infantil ? IAP_DIA[e.tipo] * IAP_MERCADO[e.mercado] * 0.85 : 0));
  const porDescargaDiaMes = descargas > 0 ? med / descargas : porDescarga * 30;
  return {
    jugadoresDia: Math.round(jugadores),
    intersticialesDia: redondeo(inter),
    bonificadosDia: redondeo(bonif),
    anunciosMes: { min: redondeo(anunciosMes * 0.5), med: redondeo(anunciosMes), max: redondeo(anunciosMes * 1.6) },
    tiendaMes: { min: redondeo(tiendaMes * 0.4), med: redondeo(tiendaMes), max: redondeo(tiendaMes * 2) },
    totalMes: { min: redondeo(anunciosMes * 0.5 + tiendaMes * 0.4), med: redondeo(med), max: redondeo(anunciosMes * 1.6 + tiendaMes * 2) },
    porDescarga: Math.round(porDescarga * 10000) / 10000,
    descargasPara100: porDescargaDiaMes > 0 ? Math.ceil(100 / porDescargaDiaMes) : Infinity,
  };
}

/** Dos o tres frases con lo que más movería la cifra (para mostrar bajo el resultado). */
export function consejosGanancias(e: EntradaGanancias, g: Ganancias): string[] {
  const out: string[] = [];
  if (e.anuncios === false) out.push("Sin anuncios activados el juego no gana nada con la publicidad: actívalos en «Anuncios».");
  if (e.d1 < 25) out.push(`Solo vuelve el ${Math.round(e.d1)} % al día siguiente: mejorar el primer nivel y encender los avisos sube más los ingresos que conseguir descargas.`);
  else if (e.d7 < 8) out.push("Mucha gente lo deja en la primera semana: un evento o un reto semanal hace que vuelvan.");
  if (e.mercado === "latam") out.push("En Latinoamérica los anuncios pagan menos: traducir el juego al inglés abre mercados que pagan de 3 a 5 veces más.");
  if (!e.tienda && !e.infantil && e.anuncios !== false) out.push("Con la tienda (quitar anuncios, monedas) suele sumarse otro 10-40 %.");
  if (Number.isFinite(g.descargasPara100)) out.push(`Para unos 100 € al mes harían falta unas ${g.descargasPara100.toLocaleString("es-ES")} descargas al día.`);
  return out.slice(0, 3);
}
