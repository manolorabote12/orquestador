// Tuercas: saldo, precio, tienda de Google Play, compras y anuncios con premio.

import { ErrorApp } from "../errores";
import { anunciosDisponibles, comprarNativo, comprasPendientes, esNativo, gestionarSuscripcion, productos as productosNativos, verAnuncioConPremio } from "../nativo";
import type { Conexion } from "./conexion";

export type Periodo = "mensual" | "anual";

export interface ProductoTienda {
  id: string;
  tipo: "tuercas" | "premium" | "plan";
  tuercas: number;
  /** Precio de Google Play en la moneda del usuario ("" si aún no se puede comprar). */
  precio: string;
  /** Planes: "taller" o "pro", tuercas que da cada mes y precio de cada plan base de Google Play. */
  plan?: "taller" | "pro";
  tuercasMes?: number;
  precios?: Partial<Record<Periodo, string>>;
}

export interface EstadoTienda {
  productos: ProductoTienda[];
  premium: boolean;
  premiumHasta: string | null;
  /** Plan mensual activo (o null), hasta cuándo y cuándo llegan las próximas tuercas. */
  plan: "taller" | "pro" | null;
  planHasta: string | null;
  planEntrega: string | null;
  /** Las tuercas del plan se acumulan como mucho N meses; Pro suma este % en cada pack. */
  topeMeses: number;
  bonusPro: number;
  /** Por qué no se puede comprar aquí (navegador, demo...), o null. */
  aviso: string | null;
  anuncios: boolean;
}

/** Lo que la app puede pedir en esta area (servidor real o demostracion). */
export interface ApiTienda {
  tuercas(): Promise<number>;
  precioJuego(): Promise<number>;
  /** Tienda: packs de tuercas y premium, con precios de Google Play. */
  tienda(): Promise<EstadoTienda>;
  /** Compra y espera a que el servidor la verifique con Google. Devuelve el saldo nuevo. */
  comprar(productoId: string, periodo?: Periodo): Promise<{ tuercas: number; premium: boolean }>;
  /** Abre la gestión de suscripciones de Google Play (cambiar o cancelar el plan). */
  gestionarPlan(): Promise<void>;
  /** Cierra compras pagadas que quedaron a medias (sin red, app cerrada). Devuelve cuántas. */
  recuperarCompras(): Promise<number>;
  /** Anuncio con premio: true si el servidor ya ha sumado las tuercas (devuelve el saldo). */
  verAnuncio(): Promise<{ visto: boolean; tuercas: number }>;
}

/** Servidor real (Supabase). */
export function supaTienda(con: Conexion): ApiTienda {
  async function verificarCompra(productoId: string, token: string) {
    return con.invocar<{ credits?: number; premium_hasta?: string }>("play-purchase",
      { product_id: productoId, purchase_token: token }, "No se pudo verificar la compra. Tu compra está a salvo: vuelve a intentarlo.");
  }

  const api: ApiTienda = {
    async tuercas() {
      const { data, error } = await con.sb.from("profiles").select("credits").single();
      if (error) throw new ErrorApp("No se pudo leer tu saldo.");
      return data.credits as number;
    },

    async precioJuego() {
      const { data } = await con.sb.from("pricing").select("credits").eq("kind", "game").maybeSingle();
      return (data?.credits as number | undefined) ?? 60;
    },

    async tienda(): Promise<EstadoTienda> {
      const [{ data: ps }, { data: t }] = await Promise.all([
        con.sb.from("store_products").select("product_id,kind,credits,plan,tuercas_mes").order("credits"),
        con.sb.rpc("mi_tienda"),
      ]);
      const lista = ((ps ?? []) as { product_id: string; kind: ProductoTienda["tipo"]; credits: number; plan: "taller" | "pro" | null; tuercas_mes: number }[]);
      const precios = await productosNativos(lista.map((p) => ({ id: p.product_id, tipo: p.kind })));
      const estado = (t ?? {}) as { premium?: boolean; premium_hasta?: string | null; plan?: "taller" | "pro" | null; plan_hasta?: string | null;
        plan_entrega?: string | null; tope_meses?: number; bonus_pro?: number };
      const precioDe = (id: string, base?: string) => precios.find((x) => x.id === id && (!base || x.base === base))?.precio ?? "";
      return {
        productos: lista.map((p) => ({ id: p.product_id, tipo: p.kind, tuercas: p.credits, precio: precioDe(p.product_id),
          ...(p.kind === "plan" ? { plan: p.plan ?? "taller", tuercasMes: p.tuercas_mes,
            precios: { mensual: precioDe(p.product_id, "mensual"), anual: precioDe(p.product_id, "anual") } } : {}) })),
        premium: !!estado.premium, premiumHasta: estado.premium_hasta ?? null,
        plan: estado.plan ?? null, planHasta: estado.plan_hasta ?? null, planEntrega: estado.plan_entrega ?? null,
        topeMeses: Number(estado.tope_meses ?? 2), bonusPro: Number(estado.bonus_pro ?? 20),
        aviso: esNativo() ? (precios.length ? null : "Google Play no responde ahora mismo. Inténtalo en un rato.")
          : "Las compras se hacen desde la app de Android.",
        anuncios: anunciosDisponibles(),
      };
    },

    async comprar(productoId: string, periodo: Periodo = "mensual") {
      if (!esNativo()) throw new ErrorApp("Las compras se hacen desde la app de Android.");
      const yo = await con.miId();
      const { data: p } = await con.sb.from("store_products").select("kind").eq("product_id", productoId).maybeSingle();
      if (!p) throw new ErrorApp("Ese producto no existe.");
      let t;
      try {
        t = await comprarNativo(productoId, p.kind !== "tuercas", yo, p.kind === "plan" ? periodo : undefined);
      } catch (e) {
        const msg = String((e as Error)?.message ?? e);
        throw new ErrorApp(/cancel/i.test(msg) ? "Compra cancelada." : "Google Play no pudo completar la compra.");
      }
      if (!t.purchaseToken) throw new ErrorApp("Google Play no devolvió la compra. Si se cobró, aparecerá al volver a abrir la app.");
      await verificarCompra(productoId, t.purchaseToken);
      const estado = await api.tienda();
      return { tuercas: await api.tuercas(), premium: estado.premium };
    },

    async gestionarPlan() {
      if (!esNativo()) throw new ErrorApp("Los planes se gestionan desde la app de Android.");
      await gestionarSuscripcion();
    },

    async recuperarCompras() {
      let n = 0;
      for (const c of await comprasPendientes()) {
        try {
          await verificarCompra(c.id, c.token);
          n++;
        } catch {
          /* se reintenta la próxima vez */
        }
      }
      return n;
    },

    async verAnuncio() {
      const antes = await api.tuercas();
      const visto = await verAnuncioConPremio(await con.miId());
      if (!visto) return { visto: false, tuercas: antes };
      // Google avisa al servidor (admob-reward) en unos segundos: se espera a ver el saldo nuevo.
      for (let i = 0; i < 10; i++) {
        await new Promise((r) => setTimeout(r, 1500));
        const ahora = await api.tuercas();
        if (ahora > antes) return { visto: true, tuercas: ahora };
      }
      return { visto: true, tuercas: antes };
    },
  };
  return api;
}
