// Capa de datos de la app, partida por areas (un archivo cada una: tipos, contrato y servidor).
// La interfaz es la misma con el servidor real (Supabase) y en modo demostracion (todo simulado
// en el movil). Las vistas importan de "./api" y no saben cual de los dos estan usando.

import { conectar } from "./conexion";
import { supaCuenta, type ApiCuenta } from "./cuenta";
import { supaComunidad, type ApiComunidad } from "./comunidad";
import { supaJuegos, type ApiJuegos } from "./juegos";
import { supaPublicar, type ApiPublicar } from "./publicar";
import { supaJugadores, type ApiJugadores } from "./jugadores";
import { supaTienda, type ApiTienda } from "./tienda";
import { supaLanzadera, type ApiLanzadera } from "./lanzadera";

export * from "./cuenta";
export * from "./comunidad";
export * from "./juegos";
export * from "./publicar";
export * from "./jugadores";
export * from "./tienda";
export * from "./lanzadera";
export { ErrorApp } from "../errores";

/** Todo lo que la app puede pedir: la suma de las areas. */
export interface Backend extends ApiCuenta, ApiComunidad, ApiJuegos, ApiPublicar, ApiJugadores, ApiTienda, ApiLanzadera {
  readonly demo: boolean;
}

/** Servidor real: una conexion compartida y cada area con su parte. */
function supabase(url: string, anon: string): Backend {
  const con = conectar(url, anon);
  return { demo: false, ...supaCuenta(con), ...supaComunidad(con), ...supaJuegos(con), ...supaPublicar(con), ...supaJugadores(con), ...supaTienda(con), ...supaLanzadera(con) };
}

// ---------------------------------------------------------------- arranque

export async function crearBackend(): Promise<Backend> {
  const url = import.meta.env.VITE_SUPABASE_URL as string | undefined;
  const anon = import.meta.env.VITE_SUPABASE_ANON_KEY as string | undefined;
  if (!import.meta.env.VITE_DEMO && url && anon && !url.includes("TU_REF")) return supabase(url, anon);
  const { Demo } = await import("../demo");
  return new Demo();
}
