// Tuercas: saldo, precio, tienda de Google Play, compras y anuncios con premio.

import { ErrorApp } from "../errores";
import { anunciosDisponibles, comprarNativo, comprasPendientes, esNativo, productos as productosNativos, verAnuncioConPremio } from "../nativo";
import type { Conexion } from "./conexion";

export interface ProductoTienda {
  id: string;
  tipo: "tuercas" | "premium";
  tuercas: number;
  /** Precio de Google Play en la moneda del usuario ("" si aún no se puede comprar). */
  precio: string;
}

export interface EstadoTienda {
  productos: ProductoTienda[];
  premium: boolean;
  premiumHasta: string | null;
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
  comprar(productoId: string): Promise<{ tuercas: number; premium: boolean }>;
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
        con.sb.from("store_products").select("product_id,kind,credits").order("credits"),
        con.sb.rpc("mi_tienda"),
      ]);
      const lista = ((ps ?? []) as { product_id: string; kind: "tuercas" | "premium"; credits: number }[]);
      const precios = await productosNativos(lista.map((p) => ({ id: p.product_id, tipo: p.kind })));
      const estado = (t ?? {}) as { premium?: boolean; premium_hasta?: string | null };
      return {
        productos: lista.map((p) => ({ id: p.product_id, tipo: p.kind, tuercas: p.credits,
          precio: precios.find((x) => x.id === p.product_id)?.precio ?? "" })),
        premium: !!estado.premium, premiumHasta: estado.premium_hasta ?? null,
        aviso: esNativo() ? (precios.length ? null : "Google Play no responde ahora mismo. Inténtalo en un rato.")
          : "Las compras se hacen desde la app de Android.",
        anuncios: anunciosDisponibles(),
      };
    },

    async comprar(productoId: string) {
      if (!esNativo()) throw new ErrorApp("Las compras se hacen desde la app de Android.");
      const yo = await con.miId();
      const { data: p } = await con.sb.from("store_products").select("kind").eq("product_id", productoId).maybeSingle();
      if (!p) throw new ErrorApp("Ese producto no existe.");
      let t;
      try {
        t = await comprarNativo(productoId, p.kind === "premium", yo);
      } catch (e) {
        const msg = String((e as Error)?.message ?? e);
        throw new ErrorApp(/cancel/i.test(msg) ? "Compra cancelada." : "Google Play no pudo completar la compra.");
      }
      if (!t.purchaseToken) throw new ErrorApp("Google Play no devolvió la compra. Si se cobró, aparecerá al volver a abrir la app.");
      await verificarCompra(productoId, t.purchaseToken);
      const estado = await api.tienda();
      return { tuercas: await api.tuercas(), premium: estado.premium };
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
