// Conexion con Supabase y lo que comparten todas las areas: el cliente, llamar a una funcion
// del servidor (con su mensaje de error para la persona) y saber quien ha entrado.

import { createClient, FunctionsHttpError, type SupabaseClient } from "@supabase/supabase-js";
import { ErrorApp } from "../errores";

export interface Conexion {
  readonly sb: SupabaseClient;
  /** Llama a una funcion del servidor; si falla, ErrorApp con su mensaje (o el de por defecto). */
  invocar<T>(funcion: string, cuerpo: Record<string, unknown>, porDefecto: string): Promise<T>;
  /** Id de quien ha entrado (si no hay sesion, ErrorApp). */
  miId(): Promise<string>;
}

export function conectar(url: string, anon: string): Conexion {
  const sb = createClient(url, anon, { auth: { persistSession: true, autoRefreshToken: true } });

  async function invocar<T>(funcion: string, cuerpo: Record<string, unknown>, porDefecto: string): Promise<T> {
    const { data, error } = await sb.functions.invoke(funcion, { body: cuerpo });
    if (error) {
      let msg = porDefecto;
      if (error instanceof FunctionsHttpError) {
        try {
          msg = ((await error.context.json()) as { message?: string }).message ?? msg;
        } catch {
          /* respuesta sin JSON */
        }
      }
      throw new ErrorApp(msg);
    }
    return data as T;
  }

  async function miId(): Promise<string> {
    const { data } = await sb.auth.getSession();
    const id = data.session?.user.id;
    if (!id) throw new ErrorApp("Vuelve a iniciar sesión.");
    return id;
  }

  return { sb, invocar, miId };
}
